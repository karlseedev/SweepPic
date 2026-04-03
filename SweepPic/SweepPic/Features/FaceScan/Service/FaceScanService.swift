//
//  FaceScanService.swift
//  SweepPic
//
//  인물사진 비교정리 — 스캔 엔진
//
//  핵심 전략: 기존 SimilarityAnalysisQueue를 호출하지 않고, 개별 분석기를 직접 사용.
//  기존 코드(SimilarityAnalysisQueue, SimilarityCache) 수정 없음.
//  분석 도구(SimilarityAnalyzer, YuNetFaceDetector, SFaceRecognizer, FaceAligner)만 재사용.
//
//  책임:
//  - PHFetchResult 구성 (method별 predicate, 최신순 정렬)
//  - 삭제대기함 사진 제외
//  - 청크 단위 분석 루프 (chunkSize: 20, overlap: 3)
//  - 그룹 발견 시 즉시 콜백
//  - 종료 조건: 1,000장 OR 30그룹
//  - 취소 지원
//  - 열 상태(thermal) 모니터링
//

import Foundation
import Photos
import Vision
import AppCore
import OSLog

// MARK: - FaceScanService

/// 인물사진 비교정리 스캔 엔진
///
/// 개별 분석기(SimilarityAnalyzer, YuNet, SFace, FaceAligner)를 직접 사용하여
/// 기존 SimilarityAnalysisQueue/Cache와 완전 격리된 분석 파이프라인을 실행합니다.
final class FaceScanService {

    // MARK: - 분석 도구

    /// 인물 매칭 엔진 (generateFeaturePrints + assignPersonIndicesForGroup)
    /// SimilarityAnalysisQueue와 동일한 분석 로직을 사용합니다.
    let matchingEngine = PersonMatchingEngine()

    // MARK: - 결과 저장

    /// 전용 캐시 (외부에서 주입)
    let cache: FaceScanCache

    // MARK: - 취소 (Pipeline extension에서 접근하므로 internal)

    /// 취소 플래그 (thread-safe)
    var isCancelled = false
    let cancelLock = NSLock()

    // MARK: - 세션 저장 키 (UserDefaults)

    private static let lastScanDateKey = "FaceScanSession.lastScanDate"
    private static let lastAssetIDKey = "FaceScanSession.lastAssetID"
    private static let byYearLastScanDateKey = "FaceScanSession.byYear.lastScanDate"
    private static let byYearLastAssetIDKey = "FaceScanSession.byYear.lastAssetID"
    private static let byYearYearKey = "FaceScanSession.byYear.year"
    private static let byYearCanContinueKey = "FaceScanSession.byYear.canContinue"

    // MARK: - Static Session Accessors

    /// 이어서 정리 가능 여부 (fromLatest / continueFromLast 용)
    static var canContinue: Bool {
        return lastScanDate != nil
    }

    /// 마지막 스캔 날짜
    static var lastScanDate: Date? {
        return UserDefaults.standard.object(forKey: lastScanDateKey) as? Date
    }

    /// 연도별 이어서 정리 날짜
    static func lastScanDateByYear(_ year: Int) -> Date? {
        guard let savedYear = UserDefaults.standard.object(forKey: byYearYearKey) as? Int,
              savedYear == year,
              UserDefaults.standard.bool(forKey: byYearCanContinueKey) else {
            return nil
        }
        return UserDefaults.standard.object(forKey: byYearLastScanDateKey) as? Date
    }

    // MARK: - Init

    init(cache: FaceScanCache) {
        self.cache = cache
    }

    // MARK: - Cancel

    /// 분석 취소
    func cancel() {
        cancelLock.lock()
        isCancelled = true
        cancelLock.unlock()
    }

    /// 취소 여부 확인 (thread-safe, Pipeline extension에서도 접근)
    var cancelled: Bool {
        cancelLock.lock()
        defer { cancelLock.unlock() }
        return isCancelled
    }

    // MARK: - Analyze (메인 진입점)

    /// 인물사진 비교정리 분석 실행
    ///
    /// 격리 SimilarityAnalysisQueue 인스턴스에서 formGroupsForRange()를 호출하여
    /// Grid와 동일한 알고리즘으로 유사 인물 그룹을 발견합니다.
    /// 종료 조건: maxScanCount(1,000장) 범위 제한 OR maxGroupCount(30그룹)
    ///
    /// 이전 구조(청크 루프 + analyzeChunk)에서 변경됨:
    /// - 청크 경계에서 그룹이 잘리는 문제 해결
    /// - Grid formGroupsForRange()를 그대로 호출하므로 Grid 알고리즘 변경 시 자동 반영
    /// - 격리 인스턴스 사용으로 SimilarityCache.shared 오염 없음
    /// - self !== .shared 가드로 analytics/notification 부수효과 억제
    ///
    /// - Parameters:
    ///   - method: 스캔 방식 (fromLatest, continueFromLast, byYear)
    ///   - onGroupFound: 그룹 발견 시 콜백 (메인 스레드)
    ///   - onProgress: 진행 상황 콜백 (메인 스레드)
    /// - Throws: CancellationError (취소 시)
    func analyze(
        method: FaceScanMethod,
        onGroupFound: @escaping (FaceScanGroup) -> Void,
        onProgress: @escaping (FaceScanProgress) -> Void
    ) async throws {
        // 1. PHFetchResult 구성
        let fetchResult = buildFetchResult(method: method)

        // 2. 이어서 정리: 시작 인덱스 결정
        let startIndex = findStartIndex(method: method, fetchResult: fetchResult)

        guard startIndex < fetchResult.count else { return }

        // 3. 분석 범위 결정 (maxScanCount로 제한)
        let endIndex = min(startIndex + FaceScanConstants.maxScanCount - 1, fetchResult.count - 1)
        let analysisRange = startIndex...endIndex

        // 취소 체크
        if cancelled { throw CancellationError() }

        // 진행률 콜백: 시작
        let initialProgress = FaceScanProgress.updated(
            scannedCount: 0, groupCount: 0, currentDate: Date()
        )
        await MainActor.run { onProgress(initialProgress) }

        // 4. 격리 인스턴스에서 formGroupsForRange() 호출
        // 격리 SimilarityCache → 격리 SimilarityAnalysisQueue
        // self !== .shared 가드에 의해 analytics/notification 자동 억제
        let isolatedCache = SimilarityCache()
        let isolatedQueue = SimilarityAnalysisQueue(cache: isolatedCache)
        let groupIDs = await isolatedQueue.formGroupsForRange(
            analysisRange, source: .grid, fetchResult: fetchResult
        )

        // 취소 체크
        if cancelled { throw CancellationError() }

        // 5. 격리 캐시에서 결과 추출 → FaceScanGroup 변환 + 콜백
        var totalGroupsFound = 0

        for groupID in groupIDs {
            // 취소 체크
            if cancelled { throw CancellationError() }

            // maxGroupCount 제한
            if totalGroupsFound >= FaceScanConstants.maxGroupCount { break }

            let members = await isolatedCache.getGroupMembers(groupID: groupID)
            guard members.count >= SimilarityConstants.minGroupSize else { continue }

            let validSlots = await isolatedCache.getGroupValidPersonIndices(for: groupID)

            // FaceScanCache에 얼굴 데이터 복사 (FaceComparisonVC 조회용)
            for assetID in members {
                let faces = await isolatedCache.getFaces(for: assetID)
                if !faces.isEmpty {
                    await cache.setFaces(faces, for: assetID)
                }
            }

            // FaceScanCache에 그룹 저장
            let group = SimilarThumbnailGroup(memberAssetIDs: members)
            await cache.addGroup(group, validSlots: validSlots, photoFaces: [:])

            // FaceScanGroup 생성 + 콜백
            let scanGroup = FaceScanGroup(
                groupID: group.groupID,
                memberAssetIDs: members,
                validPersonIndices: validSlots
            )
            totalGroupsFound += 1

            await MainActor.run { onGroupFound(scanGroup) }

            // 진행률 콜백
            let progress = FaceScanProgress.updated(
                scannedCount: endIndex - startIndex + 1,
                groupCount: totalGroupsFound,
                currentDate: Date()
            )
            await MainActor.run { onProgress(progress) }
        }

        // 6. 세션 저장
        // 마지막 분석 사진의 날짜/ID 기록
        let lastAsset = fetchResult.object(at: endIndex)
        if let lastDate = lastAsset.creationDate {
            saveSession(method: method, lastDate: lastDate, lastAssetID: lastAsset.localIdentifier)
        }
    }

    // MARK: - PHFetchResult 구성

    /// method에 따라 PHFetchResult를 구성합니다.
    private func buildFetchResult(method: FaceScanMethod) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        // 최신순 정렬
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        switch method {
        case .fromLatest:
            // 전체 이미지 (최신순)
            options.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.image.rawValue
            )

        case .continueFromLast:
            // 마지막 스캔 날짜 이전 (최신순)
            if let lastDate = Self.lastScanDate {
                options.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    lastDate as NSDate
                )
            } else {
                options.predicate = NSPredicate(
                    format: "mediaType == %d",
                    PHAssetMediaType.image.rawValue
                )
            }

        case .byYear(let year, let continueFrom):
            let calendar = Calendar.current
            let startOfYear = calendar.date(from: DateComponents(year: year))!
            let endOfYear = calendar.date(from: DateComponents(year: year + 1))!

            if let fromDate = continueFrom {
                options.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@ AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    startOfYear as NSDate,
                    endOfYear as NSDate,
                    fromDate as NSDate
                )
            } else {
                options.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    startOfYear as NSDate,
                    endOfYear as NSDate
                )
            }
        }

        return PHAsset.fetchAssets(with: options)
    }

    /// 이어서 정리: lastAssetID를 찾아서 시작 인덱스 결정
    private func findStartIndex(method: FaceScanMethod, fetchResult: PHFetchResult<PHAsset>) -> Int {
        switch method {
        case .continueFromLast:
            // lastAssetID 이후부터 시작
            guard let lastID = UserDefaults.standard.string(forKey: Self.lastAssetIDKey) else {
                return 0
            }
            // fetchResult에서 lastAssetID의 위치를 찾음
            for i in 0..<fetchResult.count {
                if fetchResult.object(at: i).localIdentifier == lastID {
                    return i + 1  // 다음 사진부터
                }
            }
            return 0  // 못 찾으면 처음부터

        case .byYear(_, let continueFrom):
            if continueFrom != nil {
                guard let lastID = UserDefaults.standard.string(forKey: Self.byYearLastAssetIDKey) else {
                    return 0
                }
                for i in 0..<fetchResult.count {
                    if fetchResult.object(at: i).localIdentifier == lastID {
                        return i + 1
                    }
                }
            }
            return 0

        default:
            return 0
        }
    }

    // MARK: - 세션 저장

    /// 분석 완료 시 세션 저장
    private func saveSession(method: FaceScanMethod, lastDate: Date, lastAssetID: String) {
        switch method {
        case .fromLatest, .continueFromLast:
            UserDefaults.standard.set(lastDate, forKey: Self.lastScanDateKey)
            UserDefaults.standard.set(lastAssetID, forKey: Self.lastAssetIDKey)

        case .byYear(let year, _):
            UserDefaults.standard.set(lastDate, forKey: Self.byYearLastScanDateKey)
            UserDefaults.standard.set(lastAssetID, forKey: Self.byYearLastAssetIDKey)
            UserDefaults.standard.set(year, forKey: Self.byYearYearKey)
            UserDefaults.standard.set(true, forKey: Self.byYearCanContinueKey)
        }

        Logger.similarPhoto.debug("FaceScanService: 세션 저장 — \(method.description)")
    }

    // MARK: - Debug Helpers

    #if DEBUG

    /// FaceScan 디버그 결과 (검증 하네스용)
    struct FaceScanDebugResult {
        /// 발견된 그룹 배열
        let groups: [FaceScanGroup]
        /// 분석에 투입된 사진 ID (중복 제거, 순서 보존)
        let analyzedAssetIDs: [String]
        /// 종료 사유
        let terminationReason: FaceScanDebugTerminationReason
    }

    /// FaceScan 디버그 종료 사유
    enum FaceScanDebugTerminationReason: String, Codable {
        /// 범위 끝까지 자연 종료
        case naturalEnd
        /// maxScanCount(1,000장) 도달
        case maxScanCount
        /// maxGroupCount(30그룹) 도달
        case maxGroupCount
        /// 취소됨
        case cancelled
    }

    /// private buildFetchResult를 debug 용도로 노출합니다.
    /// 격리 인스턴스에서 호출하여 Grid oracle과 같은 PHFetchResult를 공유합니다.
    func debugBuildFetchResult(method: FaceScanMethod) -> PHFetchResult<PHAsset> {
        return buildFetchResult(method: method)
    }

    /// 명시적 범위로 FaceScan 분석을 실행합니다 (검증 하네스용).
    ///
    /// production analyze()의 청크 루프를 범위 제한 버전으로 재현합니다.
    /// 내부에서 기존 analyzeChunk(photos:excludeAssets:)를 그대로 호출합니다.
    ///
    /// 반드시 유지: chunkSize=20, chunkOverlap=3, excludeAssets, hasAnyFace,
    /// Step 2.5/5.5, maxScanCount/maxGroupCount, 삭제대기함 제외
    /// 반드시 금지: saveSession(), UserDefaults 갱신
    ///
    /// - Parameters:
    ///   - fetchResult: 분석 대상 PHFetchResult
    ///   - range: 분석할 인덱스 범위
    /// - Returns: FaceScanDebugResult (그룹, 투입 사진 ID, 종료 사유)
    func analyzeDebugRange(
        fetchResult: PHFetchResult<PHAsset>,
        range: ClosedRange<Int>
    ) async -> FaceScanDebugResult {
        let trashedIDs = TrashStore.shared.trashedAssetIDs

        // 범위 보정
        let safeRange = max(0, range.lowerBound)...min(fetchResult.count - 1, range.upperBound)

        var currentIndex = safeRange.lowerBound
        var totalScanned = 0
        var totalGroupsFound = 0
        var discoveredAssetIDs = Set<String>()
        var allGroups: [FaceScanGroup] = []
        var analyzedAssetIDs: [String] = []       // 순서 보존, 중복 제거
        var analyzedAssetIDSet = Set<String>()     // 빠른 중복 체크용
        var terminationReason: FaceScanDebugTerminationReason = .naturalEnd

        while currentIndex <= safeRange.upperBound {
            // 취소 체크
            if cancelled {
                terminationReason = .cancelled
                break
            }

            // 종료 조건 체크
            if totalScanned >= FaceScanConstants.maxScanCount {
                terminationReason = .maxScanCount
                break
            }
            if totalGroupsFound >= FaceScanConstants.maxGroupCount {
                terminationReason = .maxGroupCount
                break
            }

            // 청크 범위 계산 (overlap 포함, safeRange 내로 클램프)
            let chunkStart = max(safeRange.lowerBound, currentIndex - FaceScanConstants.chunkOverlap)
            let chunkEnd = min(safeRange.upperBound, currentIndex + FaceScanConstants.chunkSize - 1)

            // 청크 내 사진 추출 (삭제대기함 제외)
            var photos: [PHAsset] = []
            for i in chunkStart...chunkEnd {
                let asset = fetchResult.object(at: i)
                if !trashedIDs.contains(asset.localIdentifier) {
                    photos.append(asset)
                }
            }

            // 투입 사진 ID 누적 (중복 제거, 순서 보존)
            for photo in photos {
                let id = photo.localIdentifier
                if !analyzedAssetIDSet.contains(id) {
                    analyzedAssetIDSet.insert(id)
                    analyzedAssetIDs.append(id)
                }
            }

            // 최소 3장 미만이면 다음 청크로
            guard photos.count >= SimilarityConstants.minGroupSize else {
                let skipped = chunkEnd - currentIndex + 1
                currentIndex = chunkEnd + 1
                totalScanned += skipped
                continue
            }

            // 청크 분석 실행 (production analyzeChunk 그대로 호출)
            let groups = await analyzeChunk(photos: photos, excludeAssets: discoveredAssetIDs)

            // 그룹 발견 처리
            for group in groups {
                discoveredAssetIDs.formUnion(group.memberAssetIDs)
                totalGroupsFound += 1
                allGroups.append(group)

                if totalGroupsFound >= FaceScanConstants.maxGroupCount {
                    terminationReason = .maxGroupCount
                    break
                }
            }

            // 진행 카운트 갱신
            let newScanned = chunkEnd - currentIndex + 1
            totalScanned += newScanned
            currentIndex = chunkEnd + 1

            // 열 상태 확인 — 과열 시 잠시 대기
            if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        return FaceScanDebugResult(
            groups: allGroups,
            analyzedAssetIDs: analyzedAssetIDs,
            terminationReason: terminationReason
        )
    }
    #endif
}
