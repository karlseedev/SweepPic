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

    // MARK: - Debug: 배치 진단용 타깃 그룹

    #if DEBUG
    /// 배치 진단 시 추적할 타깃 그룹의 멤버 assetID 집합.
    /// runGroupDiagnostic()에서 설정, analyze() 배치 루프에서 읽음.
    /// nil이면 배치 로그 미출력 (성능 영향 없음).
    static var debugTargetGroupSignature: Set<String>? = nil
    #endif

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

    /// 인물사진 비교정리 분석 실행 (단계 분해 파이프라인)
    ///
    /// Grid fetchResult를 받아, Grid 엔진의 각 단계를 동일하게 실행하되,
    /// 단계 사이에 진행률을 보고합니다.
    ///
    /// 파이프라인 구조:
    ///   Phase A: FP 배치 생성 (20장씩, 진행률 보고)
    ///   Phase B: formGroups 단일 호출 (전체 FP, 배치 축적 아님)
    ///   Phase C: 그룹별 얼굴 감지 + addGroupIfValid (격리 SimilarityCache) + 브리지
    ///
    /// Grid 동등성 보장:
    /// - 같은 fetchResult (Grid에서 주입)
    /// - 같은 generateFeaturePrints (같은 matchingEngine)
    /// - 같은 formGroups (전체 FP 1회 호출)
    /// - 같은 assignPersonIndicesForGroup (같은 matchingEngine)
    /// - 같은 validSlots/validMembers 계산
    /// - 같은 addGroupIfValid + mergeOverlappingGroups (격리 SimilarityCache)
    ///
    /// - Parameters:
    ///   - method: 스캔 방식 (fromLatest, continueFromLast, byYear)
    ///   - fetchResult: Grid에서 주입한 PHFetchResult (ascending, image+video)
    ///   - onGroupFound: 그룹 발견 시 콜백 (메인 스레드)
    ///   - onProgress: 진행 상황 콜백 (메인 스레드)
    /// - Throws: CancellationError (취소 시)
    func analyze(
        method: FaceScanMethod,
        fetchResult: PHFetchResult<PHAsset>,
        onGroupFound: @escaping (FaceScanGroup) -> Void,
        onProgress: @escaping (FaceScanProgress) -> Void
    ) async throws {
        // 1. 분석 범위 결정 (ascending index space)
        guard let analysisRange = resolveAnalysisRange(
            method: method, fetchResult: fetchResult
        ) else {
            Logger.similarPhoto.debug("FaceScanService: 분석 범위 없음 — 종료")
            return
        }

        Logger.similarPhoto.debug("FaceScanService: 분석 범위 \(analysisRange.lowerBound)...\(analysisRange.upperBound) (\(analysisRange.count)장, fetchResult \(fetchResult.count)장 중)")

        // 취소 체크
        if cancelled { throw CancellationError() }

        // 진행률 콜백: 시작
        await MainActor.run {
            onProgress(FaceScanProgress.updated(scannedCount: 0, groupCount: 0, currentDate: Date()))
        }

        // ── 사진 추출 (삭제대기함 제외) ──
        let photos = fetchPhotosInRange(analysisRange, fetchResult: fetchResult)
        guard photos.count >= SimilarityConstants.minGroupSize else { return }

        // ═══════════════════════════════════════════════════
        // Phase A: FP 배치 생성 (진행률 보고)
        // ═══════════════════════════════════════════════════
        let batchSize = 20
        var allFPs: [VNFeaturePrintObservation?] = []

        for batchStart in stride(from: 0, to: photos.count, by: batchSize) {
            if cancelled { throw CancellationError() }

            let batchEnd = min(batchStart + batchSize, photos.count)
            let batchPhotos = Array(photos[batchStart..<batchEnd])
            let (batchFPs, _) = await matchingEngine.generateFeaturePrints(for: batchPhotos)
            allFPs.append(contentsOf: batchFPs)

            // FP 배치마다 진행률 보고 (게이지 업데이트)
            let progress = FaceScanProgress.updated(
                scannedCount: batchEnd,
                groupCount: 0,
                currentDate: Date()
            )
            await MainActor.run { onProgress(progress) }
        }

        if cancelled { throw CancellationError() }

        // ═══════════════════════════════════════════════════
        // Phase B: 그룹 형성 (단일 호출 — 배치 축적 아님)
        // ═══════════════════════════════════════════════════
        let allIDs = photos.map(\.localIdentifier)
        let rawGroups = matchingEngine.analyzer.formGroups(
            featurePrints: allFPs,
            photoIDs: allIDs,
            threshold: SimilarityConstants.similarityThreshold
        )

        if cancelled { throw CancellationError() }

        // ═══════════════════════════════════════════════════
        // Phase C: 그룹별 얼굴 감지 + 검증 + 브리지 (진행률 보고)
        // 격리 SimilarityCache에서 addGroupIfValid 호출 → merge 동작 동일
        // rawGroups 역순 소비: 최신 사진 그룹부터 즉시 전달
        // (formGroups 비겹침 보장 → 소비 순서 무관)
        // ═══════════════════════════════════════════════════
        let isolatedCache = SimilarityCache()
        var totalGroupsFound = 0

        for groupAssetIDs in rawGroups.reversed() {
            if cancelled { throw CancellationError() }

            let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }

            // 얼굴 감지 + 인물 매칭 (formGroupsForRange:384와 동일)
            let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
                assetIDs: groupAssetIDs,
                photos: groupPhotos
            )

            // validSlots 계산 (formGroupsForRange:392-401과 동일)
            var slotPhotoCount: [Int: Set<String>] = [:]
            for (assetID, faces) in photoFacesMap {
                for face in faces {
                    slotPhotoCount[face.personIndex, default: []].insert(assetID)
                }
            }
            let validSlots = Set(slotPhotoCount.filter {
                $0.value.count >= SimilarityConstants.minPhotosPerSlot
            }.keys)

            // validMembers 필터 (formGroupsForRange:405-408과 동일)
            let validMembers = groupAssetIDs.filter { assetID in
                guard let faces = photoFacesMap[assetID] else { return false }
                return faces.contains { validSlots.contains($0.personIndex) }
            }

            // addGroupIfValid (mergeOverlappingGroups 포함 — Grid와 동일)
            if let groupID = await isolatedCache.addGroupIfValid(
                members: validMembers,
                validSlots: validSlots,
                photoFaces: photoFacesMap
            ) {
                // ── FaceScanCache로 브리지 ──
                let members = await isolatedCache.getGroupMembers(groupID: groupID)
                let mergedSlots = await isolatedCache.getGroupValidPersonIndices(for: groupID)

                // 멤버별 얼굴 데이터 복사 (FaceComparisonVC 조회용)
                for assetID in members {
                    let faces = await isolatedCache.getFaces(for: assetID)
                    await cache.setFaces(faces, for: assetID)
                }

                // FaceScanCache에 그룹 저장
                let group = SimilarThumbnailGroup(groupID: groupID, memberAssetIDs: members)
                await cache.addGroup(group, validSlots: mergedSlots, photoFaces: [:])

                totalGroupsFound += 1

                // maxGroupCount는 UI 전달 상한 (엔진 미제한)
                if totalGroupsFound <= FaceScanConstants.maxGroupCount {
                    let scanGroup = FaceScanGroup(
                        groupID: groupID,
                        memberAssetIDs: members,
                        validPersonIndices: mergedSlots
                    )
                    let progress = FaceScanProgress.updated(
                        scannedCount: photos.count,
                        groupCount: totalGroupsFound,
                        currentDate: Date()
                    )
                    await MainActor.run {
                        onGroupFound(scanGroup)
                        onProgress(progress)
                    }
                }
            }
        }

        // ── 세션 저장 (ascending 기준: lowerBound = 가장 오래된 쪽) ──
        // 다음 continue는 이보다 더 오래된 쪽으로 확장
        let boundaryAsset = fetchResult.object(at: analysisRange.lowerBound)
        if let lastDate = boundaryAsset.creationDate {
            saveSession(method: method, lastDate: lastDate, lastAssetID: boundaryAsset.localIdentifier)
        }

        Logger.similarPhoto.debug("FaceScanService: 분석 완료 — \(totalGroupsFound)그룹 발견 (전체 \(rawGroups.count)그룹 중)")
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

    // MARK: - 분석 범위 결정

    /// method에 따라 ascending fetchResult 위의 분석 범위를 계산합니다.
    ///
    /// Grid fetchResult는 ascending (오래된 → 최신) 정렬입니다.
    /// 따라서 "최신 1000장"은 fetchResult의 **끝** 쪽에 위치합니다.
    ///
    /// - Parameters:
    ///   - method: 스캔 방식
    ///   - fetchResult: Grid에서 주입한 ascending fetchResult
    /// - Returns: 분석 대상 인덱스 범위 (nil이면 분석할 사진 없음)
    private func resolveAnalysisRange(
        method: FaceScanMethod,
        fetchResult: PHFetchResult<PHAsset>
    ) -> ClosedRange<Int>? {
        guard fetchResult.count > 0 else { return nil }

        switch method {
        case .fromLatest:
            // ascending: 최신 = 마지막 → 끝에서 maxScanCount만큼
            let upper = fetchResult.count - 1
            let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
            return lower...upper

        case .continueFromLast:
            // 이전 스캔의 경계(lowerBound) asset을 찾아서 그 바로 앞까지
            guard let lastID = UserDefaults.standard.string(forKey: Self.lastAssetIDKey) else {
                // 세션 없으면 fromLatest와 동일
                let upper = fetchResult.count - 1
                let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
                return lower...upper
            }

            // fetchResult에서 lastAssetID 위치 찾기
            var boundaryIndex: Int? = nil
            for i in 0..<fetchResult.count {
                if fetchResult.object(at: i).localIdentifier == lastID {
                    boundaryIndex = i
                    break
                }
            }

            guard let boundary = boundaryIndex else {
                // 못 찾으면 fromLatest로 폴백
                let upper = fetchResult.count - 1
                let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
                return lower...upper
            }

            // 경계 바로 앞까지가 이번 범위의 upper
            let upper = boundary - 1
            guard upper >= 0 else { return nil }  // 더 이상 분석할 사진 없음

            let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
            return lower...upper

        case .byYear(let year, let continueFrom):
            // 해당 연도의 index 범위 찾기 (ascending이므로 순차 탐색)
            let calendar = Calendar.current
            var yearLower: Int? = nil
            var yearUpper: Int? = nil

            for i in 0..<fetchResult.count {
                let asset = fetchResult.object(at: i)
                guard let date = asset.creationDate else { continue }
                let assetYear = calendar.component(.year, from: date)
                if assetYear == year {
                    if yearLower == nil { yearLower = i }
                    yearUpper = i
                } else if assetYear > year && yearLower != nil {
                    // ascending이므로 year를 넘어서면 중단
                    break
                }
            }

            guard let yLower = yearLower, let yUpper = yearUpper else {
                return nil  // 해당 연도 사진 없음
            }

            var effectiveUpper = yUpper

            // continueFrom이 있으면 이전 경계 asset 앞까지만
            if continueFrom != nil {
                if let lastID = UserDefaults.standard.string(forKey: Self.byYearLastAssetIDKey) {
                    for i in yLower...yUpper {
                        if fetchResult.object(at: i).localIdentifier == lastID {
                            effectiveUpper = i - 1
                            break
                        }
                    }
                }
            }

            guard effectiveUpper >= yLower else { return nil }

            // 연도 범위 내 최신 maxScanCount장
            let lower = max(yLower, effectiveUpper - FaceScanConstants.maxScanCount + 1)
            return lower...effectiveUpper
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

    /// 명시적 범위로 FaceScan 분석을 실행합니다 (검증 하네스용).
    ///
    /// production analyze()와 동일한 단계 분해 파이프라인 (Phase A → B → C).
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

        // Phase A: FP 배치 생성
        let batchSize = 20
        var allFPs: [VNFeaturePrintObservation?] = []

        for batchStart in stride(from: 0, to: photos.count, by: batchSize) {
            guard !cancelled else {
                return FaceScanDebugResult(groups: [], analyzedAssetIDs: assetIDs, terminationReason: .cancelled)
            }
            let batchEnd = min(batchStart + batchSize, photos.count)
            let batchPhotos = Array(photos[batchStart..<batchEnd])
            let (batchFPs, _) = await matchingEngine.generateFeaturePrints(for: batchPhotos)
            allFPs.append(contentsOf: batchFPs)
        }

        guard !cancelled else {
            return FaceScanDebugResult(groups: [], analyzedAssetIDs: assetIDs, terminationReason: .cancelled)
        }

        // Phase B: formGroups 단일 호출
        let rawGroups = matchingEngine.analyzer.formGroups(
            featurePrints: allFPs,
            photoIDs: assetIDs,
            threshold: SimilarityConstants.similarityThreshold
        )

        // Phase C: 그룹별 처리 (격리 SimilarityCache)
        let isolatedCache = SimilarityCache()
        var allGroups: [FaceScanGroup] = []

        for groupAssetIDs in rawGroups {
            guard !cancelled else {
                return FaceScanDebugResult(groups: allGroups, analyzedAssetIDs: assetIDs, terminationReason: .cancelled)
            }

            let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }
            let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
                assetIDs: groupAssetIDs,
                photos: groupPhotos
            )

            var slotPhotoCount: [Int: Set<String>] = [:]
            for (assetID, faces) in photoFacesMap {
                for face in faces {
                    slotPhotoCount[face.personIndex, default: []].insert(assetID)
                }
            }
            let validSlots = Set(slotPhotoCount.filter {
                $0.value.count >= SimilarityConstants.minPhotosPerSlot
            }.keys)

            let validMembers = groupAssetIDs.filter { assetID in
                guard let faces = photoFacesMap[assetID] else { return false }
                return faces.contains { validSlots.contains($0.personIndex) }
            }

            if let groupID = await isolatedCache.addGroupIfValid(
                members: validMembers,
                validSlots: validSlots,
                photoFaces: photoFacesMap
            ) {
                let members = await isolatedCache.getGroupMembers(groupID: groupID)
                let mergedSlots = await isolatedCache.getGroupValidPersonIndices(for: groupID)

                allGroups.append(FaceScanGroup(
                    groupID: groupID,
                    memberAssetIDs: members,
                    validPersonIndices: mergedSlots
                ))
            }
        }

        return FaceScanDebugResult(
            groups: allGroups,
            analyzedAssetIDs: assetIDs,
            terminationReason: .naturalEnd
        )
    }
    #endif
}
