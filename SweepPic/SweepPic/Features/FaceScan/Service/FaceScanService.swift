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
    /// 배치 FP 생성 + IncrementalGroupBuilder 증분 그루핑 방식.
    /// formGroups()의 코어 로직(IncrementalGroupBuilder)을 공유하여
    /// Grid(경로 A)와 동일한 그루핑 알고리즘을 사용합니다.
    ///
    /// 이전 구조(청크 루프 + analyzeChunk + overlap + excludeAssets)에서 변경됨:
    /// - IncrementalGroupBuilder가 배치 간 상태를 유지하므로 경계에서 그룹이 잘리지 않음
    /// - overlap/excludeAssets 불필요 (연속 스캔)
    /// - 그룹이 확정되는 즉시 onGroupFound 콜백 (점진적 표시)
    ///
    /// 종료 조건: maxScanCount(1,000장) OR maxGroupCount(30그룹)
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
        let trashedIDs = TrashStore.shared.trashedAssetIDs

        // 2. 이어서 정리: 시작 인덱스 결정
        let startIndex = findStartIndex(method: method, fetchResult: fetchResult)

        // 3. 배치 FP + IncrementalGroupBuilder 증분 그루핑
        var currentIndex = startIndex
        var totalScanned = 0
        var totalGroupsFound = 0
        var lastAssetDate: Date?
        var lastAssetID: String?

        // 증분 그루핑 빌더 (formGroups 코어 공유)
        let builder = IncrementalGroupBuilder(
            analyzer: matchingEngine.analyzer,
            threshold: SimilarityConstants.similarityThreshold
        )

        // PHAsset 배치 간 누적 (processCompletedGroup에서 재조회 방지)
        var assetMap: [String: PHAsset] = [:]

        // FP 생성은 배치 단위, 그루핑은 연속
        let batchSize = FaceScanConstants.chunkSize  // 기존 20장 유지

        while currentIndex < fetchResult.count {
            // 취소 체크
            if cancelled { throw CancellationError() }

            // 종료 조건
            if totalGroupsFound >= FaceScanConstants.maxGroupCount { break }
            if totalScanned >= FaceScanConstants.maxScanCount { break }

            // 배치 범위 계산 (overlap 불필요 — 연속 스캔)
            let batchEnd = min(fetchResult.count - 1, currentIndex + batchSize - 1)

            // 배치 내 사진 추출 (삭제대기함 제외)
            var batchPhotos: [PHAsset] = []
            for i in currentIndex...batchEnd {
                let asset = fetchResult.object(at: i)
                if !trashedIDs.contains(asset.localIdentifier) {
                    batchPhotos.append(asset)
                }
            }

            // PHAsset 누적 (그룹 멤버가 이전 배치에서 올 수 있음)
            for photo in batchPhotos {
                assetMap[photo.localIdentifier] = photo
            }

            // FP 생성 (PersonMatchingEngine — 기존과 동일)
            let (featurePrints, _) = await matchingEngine.generateFeaturePrints(for: batchPhotos)

            guard !cancelled else { throw CancellationError() }

            // FP를 하나씩 builder에 feed
            let batchIDs = batchPhotos.map { $0.localIdentifier }

            for i in 0..<batchIDs.count {
                if let completedGroupIDs = builder.feed(fp: featurePrints[i], id: batchIDs[i]) {
                    // 그룹 확정 → 얼굴 감지 + 캐시 저장 + UI 표시
                    // hasAnyFace 게이트 없음 — 경로 A와 동일하게 모든 그룹을 YuNet/SFace로 처리
                    let group = await processCompletedGroup(
                        groupAssetIDs: completedGroupIDs,
                        assetMap: assetMap
                    )
                    if let group = group {
                        totalGroupsFound += 1
                        await MainActor.run { onGroupFound(group) }
                        if totalGroupsFound >= FaceScanConstants.maxGroupCount { break }
                    }
                }
            }

            // 진행 상황 업데이트
            let newScanned = batchEnd - currentIndex + 1
            totalScanned += newScanned
            currentIndex = batchEnd + 1

            // 마지막 사진 정보 기록 (세션 저장용)
            if let lastPhoto = batchPhotos.last {
                lastAssetDate = lastPhoto.creationDate
                lastAssetID = lastPhoto.localIdentifier
            }

            // 진행률 콜백 (메인 스레드)
            let progress = FaceScanProgress.updated(
                scannedCount: totalScanned,
                groupCount: totalGroupsFound,
                currentDate: lastAssetDate ?? Date()
            )
            await MainActor.run { onProgress(progress) }

            // 열 상태 확인 — 과열 시 잠시 대기
            if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        // 4. 마지막 미확정 그룹 처리 (maxGroupCount 미도달 시에만)
        if totalGroupsFound < FaceScanConstants.maxGroupCount,
           let lastGroupIDs = builder.flush() {
            let group = await processCompletedGroup(
                groupAssetIDs: lastGroupIDs,
                assetMap: assetMap
            )
            if let group = group {
                totalGroupsFound += 1
                await MainActor.run { onGroupFound(group) }
            }
        }

        // 5. 세션 저장 (분석 완료 시에만)
        if let date = lastAssetDate, let assetID = lastAssetID {
            saveSession(method: method, lastDate: date, lastAssetID: assetID)
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
    /// production analyze()와 동일한 배치 FP + IncrementalGroupBuilder 방식.
    /// saveSession/UserDefaults 갱신 없음.
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
        var allGroups: [FaceScanGroup] = []
        var analyzedAssetIDs: [String] = []
        var analyzedAssetIDSet = Set<String>()
        var terminationReason: FaceScanDebugTerminationReason = .naturalEnd

        // 증분 그루핑 빌더 (production analyze와 동일)
        let builder = IncrementalGroupBuilder(
            analyzer: matchingEngine.analyzer,
            threshold: SimilarityConstants.similarityThreshold
        )
        var assetMap: [String: PHAsset] = [:]
        let batchSize = FaceScanConstants.chunkSize

        while currentIndex <= safeRange.upperBound {
            if cancelled { terminationReason = .cancelled; break }
            if totalGroupsFound >= FaceScanConstants.maxGroupCount { terminationReason = .maxGroupCount; break }

            // 배치 범위 계산
            let batchEnd = min(safeRange.upperBound, currentIndex + batchSize - 1)

            // 배치 내 사진 추출 (삭제대기함 제외)
            var batchPhotos: [PHAsset] = []
            for i in currentIndex...batchEnd {
                let asset = fetchResult.object(at: i)
                if !trashedIDs.contains(asset.localIdentifier) {
                    batchPhotos.append(asset)
                }
            }

            // PHAsset 누적 + 투입 사진 ID 누적
            for photo in batchPhotos {
                let id = photo.localIdentifier
                assetMap[id] = photo
                if !analyzedAssetIDSet.contains(id) {
                    analyzedAssetIDSet.insert(id)
                    analyzedAssetIDs.append(id)
                }
            }

            // FP 생성
            let (featurePrints, _) = await matchingEngine.generateFeaturePrints(for: batchPhotos)
            guard !cancelled else { terminationReason = .cancelled; break }

            // FP를 하나씩 builder에 feed
            let batchIDs = batchPhotos.map { $0.localIdentifier }
            for i in 0..<batchIDs.count {
                if let completedGroupIDs = builder.feed(fp: featurePrints[i], id: batchIDs[i]) {
                    let group = await processCompletedGroup(
                        groupAssetIDs: completedGroupIDs,
                        assetMap: assetMap
                    )
                    if let group = group {
                        totalGroupsFound += 1
                        allGroups.append(group)
                        if totalGroupsFound >= FaceScanConstants.maxGroupCount {
                            terminationReason = .maxGroupCount
                            break
                        }
                    }
                }
            }

            // 진행 카운트 갱신
            let newScanned = batchEnd - currentIndex + 1
            totalScanned += newScanned
            currentIndex = batchEnd + 1
        }

        // 마지막 미확정 그룹 처리
        if totalGroupsFound < FaceScanConstants.maxGroupCount,
           let lastGroupIDs = builder.flush() {
            let group = await processCompletedGroup(
                groupAssetIDs: lastGroupIDs,
                assetMap: assetMap
            )
            if let group = group {
                allGroups.append(group)
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
