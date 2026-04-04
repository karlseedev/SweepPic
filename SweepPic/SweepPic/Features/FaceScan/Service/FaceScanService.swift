//
//  FaceScanService.swift
//  SweepPic
//
//  인물사진 비교정리 — 스캔 엔진
//
//  핵심 전략: formGroupsForRange()의 내부 로직을 단계별로 분해하여 직접 실행.
//  기존 코드(SimilarityAnalysisQueue, SimilarityCache) 수정 없음.
//  분석 도구(PersonMatchingEngine, SimilarityAnalyzer)만 재사용.
//
//  Decomposed Pipeline:
//  1. 전체 FP 생성 (matchingEngine.generateFeaturePrints)
//  2. 전체 FP로 그루핑 1회 (analyzer.formGroups)
//  3. 그룹별 얼굴 감지 + 즉시 콜백 (점진적 표시)
//
//  이전 방식(격리 formGroupsForRange 단일 호출)과의 차이:
//  - formGroupsForRange는 모든 그룹 처리 후 한꺼번에 반환
//  - decomposed pipeline은 그룹별 얼굴 감지 완료 즉시 콜백 (점진적 표시)
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

    /// 인물사진 비교정리 분석 실행 (배치 FP + 점진적 그루핑)
    ///
    /// FP를 배치(100장)로 생성하면서, 매 배치마다 축적된 전체 FP로 formGroups를 호출.
    /// 확정된 그룹(마지막 제외)은 즉시 얼굴 감지 + 콜백하여 점진적으로 표시합니다.
    ///
    /// EQ 동등성 보장:
    /// - formGroups는 순수 함수이며 매번 축적된 전체 FP로 호출
    /// - 최종 배치 후 formGroups 결과 = 전체 FP 1회 호출 결과 (수학적 동일)
    /// - 얼굴 감지: 동일 matchingEngine.assignPersonIndicesForGroup (그룹별 독립)
    /// - 검증 게이트: addGroupIfValid와 동일 (minGroupSize + minValidSlots)
    ///
    /// 종료 조건: maxScanCount(1,000장) 범위 제한 OR maxGroupCount(30그룹)
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
        await MainActor.run {
            onProgress(FaceScanProgress.updated(scannedCount: 0, groupCount: 0, currentDate: Date()))
        }

        // ── 사진 추출 (삭제대기함 제외) ──
        let photos = fetchPhotosInRange(analysisRange, fetchResult: fetchResult)
        guard photos.count >= SimilarityConstants.minGroupSize else { return }

        // ── 배치 FP + 점진적 그루핑 루프 ──
        let batchSize = 20
        let totalPhotos = photos.count
        var accumulatedFPs: [VNFeaturePrintObservation?] = []
        var accumulatedIDs: [String] = []
        var processedGroupCount = 0  // formGroups 결과 중 이미 얼굴감지 처리한 그룹 수
        var totalGroupsFound = 0

        var batchStart = 0
        while batchStart < totalPhotos {
            // 취소 체크
            if cancelled { throw CancellationError() }

            // maxGroupCount 제한
            if totalGroupsFound >= FaceScanConstants.maxGroupCount { break }

            // 배치 범위
            let batchEnd = min(batchStart + batchSize, totalPhotos)
            let batchPhotos = Array(photos[batchStart..<batchEnd])
            let isLastBatch = (batchEnd >= totalPhotos)

            // 배치 FP 생성
            let (batchFPs, _) = await matchingEngine.generateFeaturePrints(for: batchPhotos)

            if cancelled { throw CancellationError() }

            // FP + ID 축적
            accumulatedFPs.append(contentsOf: batchFPs)
            accumulatedIDs.append(contentsOf: batchPhotos.map { $0.localIdentifier })

            // 축적된 전체 FP로 formGroups 호출 (순수 함수, ~1ms)
            let currentGroups = matchingEngine.analyzer.formGroups(
                featurePrints: accumulatedFPs,
                photoIDs: accumulatedIDs,
                threshold: SimilarityConstants.similarityThreshold
            )

            // 확정 그룹 결정: 마지막 그룹은 다음 배치와 이어질 수 있으므로 보류
            // 단, 마지막 배치면 모든 그룹이 확정
            let sealedCount = isLastBatch ? currentGroups.count : max(currentGroups.count - 1, 0)

            // 새로 확정된 그룹만 처리 (이전에 처리한 그룹은 스킵)
            for groupIndex in processedGroupCount..<sealedCount {
                if cancelled { throw CancellationError() }
                if totalGroupsFound >= FaceScanConstants.maxGroupCount { break }

                let groupAssetIDs = currentGroups[groupIndex]

                // 얼굴 감지 + 검증 + 캐시 저장
                if let scanGroup = await processGroupForFaceScan(
                    groupAssetIDs: groupAssetIDs,
                    allPhotos: photos
                ) {
                    totalGroupsFound += 1
                    // 그룹 표시 + 진행률을 동시에 업데이트 (화면과 게이지바 동기화)
                    let groupProgress = FaceScanProgress.updated(
                        scannedCount: batchEnd,
                        groupCount: totalGroupsFound,
                        currentDate: Date()
                    )
                    await MainActor.run {
                        onGroupFound(scanGroup)
                        onProgress(groupProgress)
                    }
                }
            }
            processedGroupCount = sealedCount

            // 배치 완료 진행률 (그룹 없는 배치에서도 scannedCount 업데이트)
            let batchProgress = FaceScanProgress.updated(
                scannedCount: batchEnd,
                groupCount: totalGroupsFound,
                currentDate: Date()
            )
            await MainActor.run { onProgress(batchProgress) }

            batchStart = batchEnd
        }

        // 5. 세션 저장
        let lastAsset = fetchResult.object(at: endIndex)
        if let lastDate = lastAsset.creationDate {
            saveSession(method: method, lastDate: lastDate, lastAssetID: lastAsset.localIdentifier)
        }
    }

    // MARK: - Group Processing (공용)

    /// 단일 그룹에 대해 얼굴 감지 + 검증 + 캐시 저장을 수행합니다.
    ///
    /// formGroupsForRange:373-430 로직과 동일한 검증 파이프라인.
    /// analyze()와 analyzeDebugRange()에서 공용으로 사용합니다.
    ///
    /// - Parameters:
    ///   - groupAssetIDs: 그룹의 assetID 배열 (formGroups 결과)
    ///   - allPhotos: 전체 사진 배열 (PHAsset 조회용)
    /// - Returns: FaceScanGroup 또는 nil (검증 실패 시)
    private func processGroupForFaceScan(
        groupAssetIDs: [String],
        allPhotos: [PHAsset]
    ) async -> FaceScanGroup? {
        // 그룹 내 사진 추출
        let groupPhotos = allPhotos.filter { groupAssetIDs.contains($0.localIdentifier) }

        // 인물 매칭 실행 (YuNet 960 + SFace — formGroupsForRange와 동일)
        let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
            assetIDs: groupAssetIDs,
            photos: groupPhotos
        )

        // 유효 슬롯 계산: personIndex별 사진 수 >= minPhotosPerSlot
        var slotPhotoCount: [Int: Set<String>] = [:]
        for (assetID, faces) in photoFacesMap {
            for face in faces {
                slotPhotoCount[face.personIndex, default: []].insert(assetID)
            }
        }

        let validSlots = Set(slotPhotoCount.filter {
            $0.value.count >= SimilarityConstants.minPhotosPerSlot
        }.keys)

        // addGroupIfValid Gate 2: 유효 슬롯 최소 개수 (SimilarityCache:239)
        guard validSlots.count >= SimilarityConstants.minValidSlots else { return nil }

        // 유효 슬롯 얼굴 보유 사진만 멤버 인정 (formGroupsForRange:405-408)
        let validMembers = groupAssetIDs.filter { assetID in
            guard let faces = photoFacesMap[assetID] else { return false }
            return faces.contains { validSlots.contains($0.personIndex) }
        }

        // addGroupIfValid Gate 1: 최소 그룹 크기 (SimilarityCache:228)
        guard validMembers.count >= SimilarityConstants.minGroupSize else { return nil }

        // FaceScanCache에 얼굴 데이터 저장 (FaceComparisonVC 조회용)
        for (assetID, faces) in photoFacesMap {
            await cache.setFaces(faces, for: assetID)
        }

        // FaceScanCache에 그룹 저장
        let group = SimilarThumbnailGroup(memberAssetIDs: validMembers)
        await cache.addGroup(group, validSlots: validSlots, photoFaces: [:])

        return FaceScanGroup(
            groupID: group.groupID,
            memberAssetIDs: validMembers,
            validPersonIndices: validSlots
        )
    }

    // MARK: - Photo Fetching

    /// 범위 내 사진을 가져옵니다 (삭제대기함 제외).
    ///
    /// SimilarityAnalysisQueue.fetchPhotos(in:fetchResult:)와 동일한 로직입니다.
    /// 삭제대기함에 있는 사진은 분석 대상에서 제외합니다.
    ///
    /// - Parameters:
    ///   - range: 인덱스 범위
    ///   - fetchResult: 사진 fetch 결과
    /// - Returns: PHAsset 배열 (삭제대기함 사진 제외)
    private func fetchPhotosInRange(
        _ range: ClosedRange<Int>,
        fetchResult: PHFetchResult<PHAsset>
    ) -> [PHAsset] {
        let trashedIDs = TrashStore.shared.trashedAssetIDs
        var photos: [PHAsset] = []
        let clampedRange = max(0, range.lowerBound)...min(fetchResult.count - 1, range.upperBound)

        for i in clampedRange {
            let asset = fetchResult.object(at: i)
            // 삭제대기함에 있는 사진은 분석 대상에서 제외
            if !trashedIDs.contains(asset.localIdentifier) {
                photos.append(asset)
            }
        }

        return photos
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
    /// production analyze()와 동일한 배치 FP + 점진적 그루핑 방식.
    /// saveSession/UserDefaults 갱신 없음. EQ 테스트에서는 그룹 제한 없음.
    ///
    /// - Parameters:
    ///   - fetchResult: 분석 대상 PHFetchResult
    ///   - range: 분석할 인덱스 범위
    /// - Returns: FaceScanDebugResult (그룹, 투입 사진 ID, 종료 사유)
    func analyzeDebugRange(
        fetchResult: PHFetchResult<PHAsset>,
        range: ClosedRange<Int>
    ) async -> FaceScanDebugResult {
        // 사진 추출
        let photos = fetchPhotosInRange(range, fetchResult: fetchResult)
        guard photos.count >= SimilarityConstants.minGroupSize else {
            return FaceScanDebugResult(
                groups: [],
                analyzedAssetIDs: photos.map { $0.localIdentifier },
                terminationReason: .naturalEnd
            )
        }

        let assetIDs = photos.map { $0.localIdentifier }
        var allGroups: [FaceScanGroup] = []
        var processedGroupCount = 0

        // 배치 FP + 점진적 그루핑 (production analyze와 동일 구조)
        let batchSize = 20
        var accumulatedFPs: [VNFeaturePrintObservation?] = []
        var accumulatedIDs: [String] = []

        var batchStart = 0
        while batchStart < photos.count {
            guard !cancelled else {
                return FaceScanDebugResult(groups: allGroups, analyzedAssetIDs: assetIDs, terminationReason: .cancelled)
            }

            let batchEnd = min(batchStart + batchSize, photos.count)
            let batchPhotos = Array(photos[batchStart..<batchEnd])
            let isLastBatch = (batchEnd >= photos.count)

            // 배치 FP 생성
            let (batchFPs, _) = await matchingEngine.generateFeaturePrints(for: batchPhotos)

            guard !cancelled else {
                return FaceScanDebugResult(groups: allGroups, analyzedAssetIDs: assetIDs, terminationReason: .cancelled)
            }

            // FP + ID 축적
            accumulatedFPs.append(contentsOf: batchFPs)
            accumulatedIDs.append(contentsOf: batchPhotos.map { $0.localIdentifier })

            // 축적된 전체 FP로 formGroups 호출
            let currentGroups = matchingEngine.analyzer.formGroups(
                featurePrints: accumulatedFPs,
                photoIDs: accumulatedIDs,
                threshold: SimilarityConstants.similarityThreshold
            )

            // 확정 그룹 처리 (EQ 테스트: 그룹 제한 없음)
            let sealedCount = isLastBatch ? currentGroups.count : max(currentGroups.count - 1, 0)

            for groupIndex in processedGroupCount..<sealedCount {
                guard !cancelled else {
                    return FaceScanDebugResult(groups: allGroups, analyzedAssetIDs: assetIDs, terminationReason: .cancelled)
                }

                let groupAssetIDs = currentGroups[groupIndex]

                if let scanGroup = await processGroupForFaceScan(
                    groupAssetIDs: groupAssetIDs,
                    allPhotos: photos
                ) {
                    allGroups.append(scanGroup)
                }
            }
            processedGroupCount = sealedCount

            batchStart = batchEnd
        }

        return FaceScanDebugResult(
            groups: allGroups,
            analyzedAssetIDs: assetIDs,
            terminationReason: .naturalEnd
        )
    }
    #endif
}
