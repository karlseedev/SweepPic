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
    /// init에서 imageLoader를 주입받아 생성 (사전분석 시 전용 로더 사용 가능)
    let matchingEngine: PersonMatchingEngine

    // MARK: - 결과 저장

    /// 전용 캐시 (외부에서 주입)
    let cache: FaceScanCache

    // MARK: - 취소 (Pipeline extension에서 접근하므로 internal)

    /// 취소 플래그 (thread-safe)
    var isCancelled = false
    let cancelLock = NSLock()

    // MARK: - C 사전분석용 옵션

    /// true이면 분석 완료 시 세션을 UserDefaults에 저장하지 않음
    /// C 온보딩 사전분석에서 사용 — 사용자의 "이어서 정리" 세션 오염 방지
    var skipSessionSave: Bool = false

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

    /// - Parameters:
    ///   - cache: 전용 캐시
    ///   - imageLoader: 이미지 로더 (기본값: .shared, 사전분석 시 전용 인스턴스 주입으로 스크롤 독립 동작)
    init(cache: FaceScanCache, imageLoader: SimilarityImageLoader = .shared) {
        self.cache = cache
        self.matchingEngine = PersonMatchingEngine(imageLoader: imageLoader)
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

        // 진행률 콜백: 시작 (Phase A — "분석 준비 중", 게이지 0%)
        await MainActor.run {
            onProgress(FaceScanProgress.initial())
        }

        // ── 사진 추출 (삭제대기함 제외) ──
        let photos = fetchPhotosInRange(analysisRange, fetchResult: fetchResult)
        guard photos.count >= SimilarityConstants.minGroupSize else {
            // 분석 대상 부족 → actualPhotosCount 보정 후 종료
            // (initial()의 totalPhotoCount=0이 남으면 showCompletion에서 부정확한 수치 표시)
            let finalProgress = FaceScanProgress.updated(
                scannedCount: photos.count,
                groupCount: 0,
                currentDate: Date(),
                actualPhotosCount: photos.count,
                state: .analyzing
            )
            await MainActor.run { onProgress(finalProgress) }
            return
        }

        // 사용자에게 표시할 사진 수 (overlap 제외 — overlap은 경계 그룹 보호용 내부 구현)
        let displayPhotoCount = min(photos.count, FaceScanConstants.maxScanCount)

        // ═══════════════════════════════════════════════════
        // Phase A: FP 배치 생성 ("분석 준비 중" + 게이지 0%→100%)
        // Phase A 완료 후 Phase C에서 게이지가 0%로 리셋됨
        // ═══════════════════════════════════════════════════
        let batchSize = 20
        var allFPs: [VNFeaturePrintObservation?] = []

        for batchStart in stride(from: 0, to: photos.count, by: batchSize) {
            if cancelled { throw CancellationError() }

            let batchEnd = min(batchStart + batchSize, photos.count)
            let batchPhotos = Array(photos[batchStart..<batchEnd])
            let (batchFPs, _) = await matchingEngine.generateFeaturePrints(for: batchPhotos)
            allFPs.append(contentsOf: batchFPs)

            // Phase A 진행률 보고 ("분석 준비 중" + FP 생성 비율 게이지)
            let phaseAProgress = FaceScanProgress.updated(
                scannedCount: batchEnd,
                groupCount: 0,
                currentDate: Date(),
                actualPhotosCount: displayPhotoCount,
                state: .preparing
            )
            await MainActor.run { onProgress(phaseAProgress) }
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
        //
        // 진행률: 매 rawGroup 처리 완료 시 onProgress 호출 (유효 여부 무관)
        // scannedCount = processedRawGroupCount / rawGroups.count × photos.count (체감 환산��)
        // ═══════════════════════════════════════════════════
        let isolatedCache = SimilarityCache()
        var totalGroupsFound = 0
        var processedRawGroupCount = 0
        var sessionBoundaryAssetID: String? = nil   // maxGroupCount 도달 시 세션 경계
        var sessionBoundaryDate: Date? = nil

        for groupAssetIDs in rawGroups.reversed() {
            if cancelled { throw CancellationError() }
            processedRawGroupCount += 1

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
            var shouldBreak = false

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

                // UI 전달 — onGroupFound만 (onProgress는 아래에서 매 rawGroup마다)
                if totalGroupsFound <= FaceScanConstants.maxGroupCount {
                    let scanGroup = FaceScanGroup(
                        groupID: groupID,
                        memberAssetIDs: members,
                        validPersonIndices: mergedSlots
                    )
                    await MainActor.run { onGroupFound(scanGroup) }
                }

                // maxGroupCount 도달 → 세션 경계 기록
                // 남은 그룹은 "다음 분석"에서 다시 발견됨
                if totalGroupsFound >= FaceScanConstants.maxGroupCount {
                    // groupAssetIDs는 ascending 순서 (formGroups 보장)
                    // first = 이 그룹의 가장 오래된 멤버 → 다음 분석이 여기부터 시작
                    if let oldestID = groupAssetIDs.first,
                       let oldestPhoto = photos.first(where: { $0.localIdentifier == oldestID }) {
                        sessionBoundaryAssetID = oldestID
                        sessionBoundaryDate = oldestPhoto.creationDate
                    }
                    shouldBreak = true
                }
            }

            // 매 rawGroup 처리 완료 시 진행률 갱신 (유효 여부 무관)
            // scannedSoFar: rawGroup 처리 비율을 ���진 수로 환산 (체감용)
            let scannedSoFar = min(
                Int(Float(processedRawGroupCount) / Float(max(rawGroups.count, 1)) * Float(photos.count)),
                displayPhotoCount
            )
            let progress = FaceScanProgress.updated(
                scannedCount: scannedSoFar,
                groupCount: totalGroupsFound,
                currentDate: Date(),
                actualPhotosCount: displayPhotoCount,
                state: .analyzing
            )
            await MainActor.run { onProgress(progress) }

            if shouldBreak { break }
        }

        // Phase C 완료 후 최종 진행률 보정
        // maxGroupCount 미도달 자연 종료 시, scannedCount를 정확한 photos.count로 보정
        // (정수 ���눗셈 오차 보정 + rawGroups 비어��는 경우 처���)
        if sessionBoundaryAssetID == nil {
            let finalProgress = FaceScanProgress.updated(
                scannedCount: displayPhotoCount,
                groupCount: totalGroupsFound,
                currentDate: Date(),
                actualPhotosCount: displayPhotoCount,
                state: .analyzing
            )
            await MainActor.run { onProgress(finalProgress) }
        }

        // ── 세션 저장 ──
        if let boundaryID = sessionBoundaryAssetID, let boundaryDate = sessionBoundaryDate {
            // maxGroupCount 도달: 마지막 표시 그룹의 가장 오래된 멤버 기준
            // → "다음 분석"이 이 그룹 앞부터 시작하여 미표시 그룹 포함
            saveSession(method: method, lastDate: boundaryDate, lastAssetID: boundaryID)
        } else {
            // 범위 전체 처리 완료: lowerBound 기준
            let boundaryAsset = fetchResult.object(at: analysisRange.lowerBound)
            if let lastDate = boundaryAsset.creationDate {
                saveSession(method: method, lastDate: lastDate, lastAssetID: boundaryAsset.localIdentifier)
            }
        }

        Logger.similarPhoto.debug("FaceScanService: 분석 완료 — \(totalGroupsFound)그룹 발견 (전체 \(rawGroups.count)그룹 중)")
    }

    // MARK: - 사전분석 (온보딩 C 전용 경량 탐색)

    /// 유효한 그룹 1개를 빠르게 찾는 경량 분석 메서드 (온보딩 C 사전분석용)
    ///
    /// 기존 `analyze()`와 달리 Phase A(전체 FP 수집)를 별도 단계로 분리하지 않고,
    /// FP를 20장씩 누적하면서 100장마다 formGroups + 얼굴감지를 실행합니다.
    /// 유효한 그룹 1개가 발견되면 즉시 반환하여 불필요한 분석을 방지합니다.
    ///
    /// Grid 동등성은 보장하지 않습니다 (경계 그룹 잘림 허용).
    /// 스크롤 독립 동작을 위해 전용 SimilarityImageLoader를 init에 주입하여 사용하세요.
    ///
    /// - Parameter fetchResult: Grid에서 주입한 PHFetchResult (ascending, image+video)
    /// - Returns: 유효한 FaceScanGroup (발견 시), nil (미발견 시)
    /// - Throws: CancellationError (취소 시)
    func analyzeForFirstGroup(
        fetchResult: PHFetchResult<PHAsset>
    ) async throws -> FaceScanGroup? {
        guard fetchResult.count > 0 else { return nil }

        // ── 범위 결정: 최신 preScanMaxCount장 확보 (overlap 불필요) ──
        let upper = fetchResult.count - 1
        let lower = findPhotoBasedLower(
            upper: upper, lowerLimit: 0,
            maxCount: FaceScanConstants.preScanMaxCount, overlap: 0,
            fetchResult: fetchResult
        )

        // 사진 추출 (삭제대기함 및 동영상 제외, ascending 유지 — 정규 분석과 동일한 순서)
        let photos = fetchPhotosInRange(lower...upper, fetchResult: fetchResult)
        guard photos.count >= SimilarityConstants.minGroupSize else {
            Logger.similarPhoto.debug("analyzeForFirstGroup: 분석 대상 부족 (\(photos.count)장) — 종료")
            return nil
        }

        Logger.similarPhoto.debug("analyzeForFirstGroup: 시작 (\(photos.count)장)")

        // ── FP 생성: 최신부터 (끝에서부터), 체크포인트에서는 ascending 순서로 formGroups ──
        //
        // 탐색 순서: 최신부터 (UX — 빠른 첫 결과)
        // formGroups/assignPersonIndices 순서: 과거→최신 (정규 분석과 동일 — 정확성)
        // 그룹 검사 순서: 최신 그룹부터 (정규 분석의 rawGroups.reversed()와 동일)
        //
        // FP 배열은 최신부터 채워지므로, 체크포인트에서 ascending 정렬 후 formGroups에 전달.
        let batchSize = 20
        let groupingInterval = FaceScanConstants.preScanGroupingInterval
        // fpEntries: (photoIndex, fp) 쌍 — 체크포인트에서 photoIndex 기준 정렬용
        var fpEntries: [(index: Int, fp: VNFeaturePrintObservation?)] = []
        var checkedAssetIDs: Set<String> = []  // 이미 얼굴감지 완료한 assetID
        let isolatedCache = SimilarityCache()

        // 최신부터 FP 생성 (끝에서부터 역순 탐색)
        let reversedIndices = stride(from: photos.count - 1, through: 0, by: -batchSize)
        for batchLast in reversedIndices {
            // 취소 체크
            if cancelled { throw CancellationError() }

            // 배치 범위: [batchFirst...batchLast] (ascending 범위)
            let batchFirst = max(batchLast - batchSize + 1, 0)
            let batchPhotos = Array(photos[batchFirst...batchLast])
            let (batchFPs, _) = await matchingEngine.generateFeaturePrints(for: batchPhotos)

            // (index, fp) 쌍으로 저장
            for (offset, fp) in batchFPs.enumerated() {
                fpEntries.append((index: batchFirst + offset, fp: fp))
            }

            // 그루핑 체크포인트: groupingInterval(100장)마다 또는 마지막 배치
            let isCheckpoint = fpEntries.count >= groupingInterval
                && fpEntries.count % groupingInterval < batchSize
            let isLastBatch = batchFirst == 0

            guard isCheckpoint || isLastBatch else { continue }

            // 취소 체크
            if cancelled { throw CancellationError() }

            // ── 체크포인트: ascending 순서로 정렬 후 formGroups (정규 분석과 동일) ──
            let sorted = fpEntries.sorted { $0.index < $1.index }
            let sortedFPs = sorted.map(\.fp)
            let sortedIDs = sorted.map { photos[$0.index].localIdentifier }

            let rawGroups = matchingEngine.analyzer.formGroups(
                featurePrints: sortedFPs,
                photoIDs: sortedIDs,
                threshold: SimilarityConstants.similarityThreshold
            )

            Logger.similarPhoto.debug("analyzeForFirstGroup: 체크포인트 \(fpEntries.count)장, \(rawGroups.count)그룹 발견")

            // 최신 그룹부터 검사 (정규 분석의 rawGroups.reversed()와 동일)
            for groupAssetIDs in rawGroups.reversed() {
                if cancelled { throw CancellationError() }

                // 이미 체크한 멤버만으로 구성된 그룹은 스킵
                let newMembers = groupAssetIDs.filter { !checkedAssetIDs.contains($0) }
                guard !newMembers.isEmpty else { continue }

                // 얼굴감지 + 인물 매칭 (ascending 순서 — 정규 분석과 동일)
                let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }
                let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
                    assetIDs: groupAssetIDs,
                    photos: groupPhotos
                )

                // validSlots 계산
                var slotPhotoCount: [Int: Set<String>] = [:]
                for (assetID, faces) in photoFacesMap {
                    for face in faces {
                        slotPhotoCount[face.personIndex, default: []].insert(assetID)
                    }
                }
                let validSlots = Set(slotPhotoCount.filter {
                    $0.value.count >= SimilarityConstants.minPhotosPerSlot
                }.keys)

                // validMembers 필터
                let validMembers = groupAssetIDs.filter { assetID in
                    guard let faces = photoFacesMap[assetID] else { return false }
                    return faces.contains { validSlots.contains($0.personIndex) }
                }

                // 처리한 assetID 기록 (다음 체크포인트에서 스킵용)
                checkedAssetIDs.formUnion(groupAssetIDs)

                // 유효 슬롯 없으면 스킵
                guard !validSlots.isEmpty,
                      validMembers.count >= SimilarityConstants.minGroupSize else { continue }

                // ── 유효 그룹 발견! isolatedCache 경로로 isValidSlot 반영 ──
                if let groupID = await isolatedCache.addGroupIfValid(
                    members: validMembers,
                    validSlots: validSlots,
                    photoFaces: photoFacesMap
                ) {
                    let members = await isolatedCache.getGroupMembers(groupID: groupID)
                    let mergedSlots = await isolatedCache.getGroupValidPersonIndices(for: groupID)

                    // FaceScanCache에 얼굴 데이터 저장 (isValidSlot 반영됨)
                    for assetID in members {
                        let faces = await isolatedCache.getFaces(for: assetID)
                        await cache.setFaces(faces, for: assetID)
                    }

                    // FaceScanCache에 그룹 저장
                    let group = SimilarThumbnailGroup(groupID: groupID, memberAssetIDs: members)
                    await cache.addGroup(group, validSlots: mergedSlots, photoFaces: [:])

                    Logger.similarPhoto.debug("analyzeForFirstGroup: 유효 그룹 발견 — \(members.count)장, \(fpEntries.count)/\(photos.count)장 검색 시점")

                    return FaceScanGroup(
                        groupID: groupID,
                        memberAssetIDs: members,
                        validPersonIndices: mergedSlots
                    )
                }
            }
        }

        Logger.similarPhoto.debug("analyzeForFirstGroup: \(photos.count)장 검색 완료 — 유효 그룹 없음")
        return nil
    }

    // MARK: - Photo Fetching

    /// 범위 내 사진을 가져옵니다 (삭제대기함 및 동영상 제외).
    ///
    /// SimilarityAnalysisQueue.fetchPhotos(in:fetchResult:)와 동일한 로직입니다.
    /// 삭제대기함 사진 및 동영상은 분석 대상에서 제외합니다.
    ///
    /// - Parameters:
    ///   - range: 인덱스 범위
    ///   - fetchResult: 사진 fetch 결과
    /// - Returns: PHAsset 배열 (삭제대기함 사진 및 동영상 제외)
    private func fetchPhotosInRange(
        _ range: ClosedRange<Int>,
        fetchResult: PHFetchResult<PHAsset>
    ) -> [PHAsset] {
        let trashedIDs = TrashStore.shared.trashedAssetIDs
        var photos: [PHAsset] = []
        let clampedRange = max(0, range.lowerBound)...min(fetchResult.count - 1, range.upperBound)

        for i in clampedRange {
            let asset = fetchResult.object(at: i)
            // 삭제대기함 사진 및 동영상은 분석 대상에서 제외
            if !trashedIDs.contains(asset.localIdentifier)
                && asset.mediaType == .image {
                photos.append(asset)
            }
        }

        return photos
    }

    // MARK: - 분석 범위 결정

    /// upper에서 하방으로 이미지(비동영상, 비삭제대기함)를 세면서
    /// maxCount장 + overlap장을 포함하는 범위의 lower를 찾습니다.
    ///
    /// 동영상/삭제대기함 에셋을 건너뛰므로 반환 범위의 에셋 수 > maxCount일 수 있습니다.
    /// overlap: 경계에서 그룹이 잘리는 것을 방지하기 위해 추가로 포함하는 사진 수.
    ///
    /// - Parameters:
    ///   - upper: 범위 상한 (fetchResult 인덱스)
    ///   - lowerLimit: 하방 탐색 한계 (0 또는 연도 범위 시작점)
    ///   - maxCount: 확보할 이미지 수 (FaceScanConstants.maxScanCount)
    ///   - overlap: 경계 overlap 사진 수 (FaceScanConstants.chunkOverlap)
    ///   - fetchResult: Grid에서 주입한 ascending fetchResult
    /// - Returns: lower 인덱스 (lowerLimit 이상)
    private func findPhotoBasedLower(
        upper: Int,
        lowerLimit: Int,
        maxCount: Int,
        overlap: Int,
        fetchResult: PHFetchResult<PHAsset>
    ) -> Int {
        let trashedIDs = TrashStore.shared.trashedAssetIDs
        let targetCount = maxCount + overlap
        var photoCount = 0

        for i in stride(from: upper, through: lowerLimit, by: -1) {
            let asset = fetchResult.object(at: i)
            if asset.mediaType == .image && !trashedIDs.contains(asset.localIdentifier) {
                photoCount += 1
                if photoCount >= targetCount {
                    return i
                }
            }
        }
        // 사진이 targetCount 미만이면 가능한 전체 범위
        return lowerLimit
    }

    /// method에 따라 ascending fetchResult 위의 분석 범위를 계산합니다.
    ///
    /// Grid fetchResult는 ascending (오래된 → 최신) 정렬입니다.
    /// 따라서 "최신 1000장"은 fetchResult의 **끝** 쪽에 위치합니다.
    ///
    /// 범위 결정 시 동영상/삭제대기함을 건너뛰고 **이미지 기준** maxScanCount장을 확보합니다.
    /// 추가로 chunkOverlap만큼 여유를 두어 경계에서 그룹이 잘리는 것을 방지합니다.
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

        let maxPhotos = FaceScanConstants.maxScanCount
        let overlap = FaceScanConstants.chunkOverlap

        switch method {
        case .fromLatest:
            // ascending: 최신 = 마지막 → 끝에서 이미지 maxScanCount+overlap장 확보
            let upper = fetchResult.count - 1
            let lower = findPhotoBasedLower(
                upper: upper, lowerLimit: 0,
                maxCount: maxPhotos, overlap: overlap,
                fetchResult: fetchResult
            )
            return lower...upper

        case .continueFromLast:
            // 이전 스캔의 경계(lowerBound) asset을 찾아서 그 바로 앞까지
            guard let lastID = UserDefaults.standard.string(forKey: Self.lastAssetIDKey) else {
                // 세션 없으면 fromLatest와 동일
                let upper = fetchResult.count - 1
                let lower = findPhotoBasedLower(
                    upper: upper, lowerLimit: 0,
                    maxCount: maxPhotos, overlap: overlap,
                    fetchResult: fetchResult
                )
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
                let lower = findPhotoBasedLower(
                    upper: upper, lowerLimit: 0,
                    maxCount: maxPhotos, overlap: overlap,
                    fetchResult: fetchResult
                )
                return lower...upper
            }

            // 경계 바로 앞까지가 이번 범위의 upper
            let upper = boundary - 1
            guard upper >= 0 else { return nil }  // 더 이상 분석할 사진 없음

            let lower = findPhotoBasedLower(
                upper: upper, lowerLimit: 0,
                maxCount: maxPhotos, overlap: overlap,
                fetchResult: fetchResult
            )
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

            // 연도 범위 내 최신 이미지 maxScanCount+overlap장 확보
            let lower = findPhotoBasedLower(
                upper: effectiveUpper, lowerLimit: yLower,
                maxCount: maxPhotos, overlap: overlap,
                fetchResult: fetchResult
            )
            return lower...effectiveUpper
        }
    }

    // MARK: - 세션 저장

    /// 분석 완료 시 세션 저장 (skipSessionSave=true이면 저장 생략)
    private func saveSession(method: FaceScanMethod, lastDate: Date, lastAssetID: String) {
        guard !skipSessionSave else {
            Logger.similarPhoto.debug("FaceScanService: 세션 저장 생략 (skipSessionSave=true)")
            return
        }
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
