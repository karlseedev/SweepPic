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

    /// 인물사진 비교정리 분석 실행 (Decomposed Pipeline)
    ///
    /// formGroupsForRange()의 내부 로직을 단계별로 분해하여 직접 실행합니다.
    /// 전체 FP 생성 → formGroups 1회 호출 → 그룹별 얼굴 감지 + 즉시 콜백.
    ///
    /// Grid(formGroupsForRange)와 동일한 알고리즘을 각 단계에서 직접 호출하므로
    /// 그루핑 결과가 동일하면서도 그룹별 점진적 표시가 가능합니다.
    ///
    /// EQ 동등성 보장:
    /// - FP 생성: 동일 matchingEngine.generateFeaturePrints (PersonMatchingEngine 무상태)
    /// - 그루핑: 동일 analyzer.formGroups (순수 함수, 전체 FP 1회 호출)
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
        let initialProgress = FaceScanProgress.updated(
            scannedCount: 0, groupCount: 0, currentDate: Date()
        )
        await MainActor.run { onProgress(initialProgress) }

        // ── Step 1: 사진 추출 (삭제대기함 제외) ──
        // SimilarityAnalysisQueue.fetchPhotos(:fetchResult:) 동일 로직
        let photos = fetchPhotosInRange(analysisRange, fetchResult: fetchResult)
        guard photos.count >= SimilarityConstants.minGroupSize else { return }
        let assetIDs = photos.map { $0.localIdentifier }

        // ── Step 2: 전체 FP 생성 (PersonMatchingEngine) ──
        // Grid formGroupsForRange와 동일: 전체 사진에 대해 1회 호출
        let (featurePrints, _) = await matchingEngine.generateFeaturePrints(for: photos)

        // 취소 체크
        if cancelled { throw CancellationError() }

        // ── Step 3: 전체 FP로 그루핑 1회 (SimilarityAnalyzer.formGroups) ──
        // 전체 FP를 한 번에 전달하므로 경계 잘림 문제 없음
        let rawGroups = matchingEngine.analyzer.formGroups(
            featurePrints: featurePrints,
            photoIDs: assetIDs,
            threshold: SimilarityConstants.similarityThreshold
        )

        guard !rawGroups.isEmpty else { return }

        // ── Step 4: 그룹별 얼굴 감지 + 즉시 콜백 (점진적 표시) ──
        // formGroupsForRange:373-430 로직과 동일한 검증 파이프라인
        var totalGroupsFound = 0
        let totalPhotosInRange = endIndex - startIndex + 1
        let totalRawGroups = max(rawGroups.count, 1)
        var processedGroupIndex = 0

        for (groupIndex, groupAssetIDs) in rawGroups.enumerated() {
            // 취소 체크
            if cancelled { throw CancellationError() }

            // maxGroupCount 제한
            if totalGroupsFound >= FaceScanConstants.maxGroupCount { break }

            // 그룹 내 사진 추출 (photos 배열에서 직접 필터 — assetMap 불필요)
            let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }

            // 인물 매칭 실행 (YuNet 960 + SFace — formGroupsForRange와 동일 알고리즘)
            let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
                assetIDs: groupAssetIDs,
                photos: groupPhotos
            )

            // 유효 슬롯 계산: 같은 personIndex가 2장 이상의 사진에서 나타나야 함
            // (formGroupsForRange:392-401 동일 로직)
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
            if validSlots.count >= SimilarityConstants.minValidSlots {
                // 유효 슬롯 얼굴이 있는 사진만 그룹 멤버로 인정 (formGroupsForRange:405-408)
                let validMembers = groupAssetIDs.filter { assetID in
                    guard let faces = photoFacesMap[assetID] else { return false }
                    return faces.contains { validSlots.contains($0.personIndex) }
                }

                // addGroupIfValid Gate 1: 최소 그룹 크기 (SimilarityCache:228)
                if validMembers.count >= SimilarityConstants.minGroupSize {
                    // FaceScanCache에 얼굴 데이터 저장 (FaceComparisonVC 조회용)
                    for (assetID, faces) in photoFacesMap {
                        await cache.setFaces(faces, for: assetID)
                    }

                    // FaceScanCache에 그룹 저장
                    let group = SimilarThumbnailGroup(memberAssetIDs: validMembers)
                    await cache.addGroup(group, validSlots: validSlots, photoFaces: [:])

                    // FaceScanGroup 생성 + 즉시 콜백 (점진적 표시!)
                    let scanGroup = FaceScanGroup(
                        groupID: group.groupID,
                        memberAssetIDs: validMembers,
                        validPersonIndices: validSlots
                    )
                    totalGroupsFound += 1

                    await MainActor.run { onGroupFound(scanGroup) }
                }
            }

            // 진행률 콜백: 유효 여부와 무관하게 rawGroup 처리 진행률 보고
            // (그룹 처리가 실제 시간 소요 구간이므로 이 시점에서 점진적 증가)
            let scannedSoFar = Int(Float(totalPhotosInRange) * Float(groupIndex + 1) / Float(totalRawGroups))
            let progress = FaceScanProgress.updated(
                scannedCount: scannedSoFar,
                groupCount: totalGroupsFound,
                currentDate: Date()
            )
            await MainActor.run { onProgress(progress) }
        }

        // 5. 세션 저장
        // 마지막 분석 사진의 날짜/ID 기록
        let lastAsset = fetchResult.object(at: endIndex)
        if let lastDate = lastAsset.creationDate {
            saveSession(method: method, lastDate: lastDate, lastAssetID: lastAsset.localIdentifier)
        }
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
    /// production analyze()와 동일한 decomposed pipeline 방식:
    /// 전체 FP 생성 → formGroups 1회 → 그룹별 얼굴 감지
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
        // 범위 보정 + 사진 추출
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
        var totalGroupsFound = 0

        // 취소 체크
        guard !cancelled else {
            return FaceScanDebugResult(groups: [], analyzedAssetIDs: assetIDs, terminationReason: .cancelled)
        }

        // Step 1: 전체 FP 생성
        let (featurePrints, _) = await matchingEngine.generateFeaturePrints(for: photos)

        guard !cancelled else {
            return FaceScanDebugResult(groups: [], analyzedAssetIDs: assetIDs, terminationReason: .cancelled)
        }

        // Step 2: 전체 FP로 그루핑 1회
        let rawGroups = matchingEngine.analyzer.formGroups(
            featurePrints: featurePrints,
            photoIDs: assetIDs,
            threshold: SimilarityConstants.similarityThreshold
        )

        // Step 3: 그룹별 얼굴 감지 + 검증 (production analyze와 동일 로직)
        // EQ 테스트에서는 그룹 제한 없이 전체 비교 (Grid oracle도 제한 없음)
        for groupAssetIDs in rawGroups {
            guard !cancelled else {
                return FaceScanDebugResult(groups: allGroups, analyzedAssetIDs: assetIDs, terminationReason: .cancelled)
            }

            // 그룹 내 사진 추출
            let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }

            // 인물 매칭 실행
            let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
                assetIDs: groupAssetIDs,
                photos: groupPhotos
            )

            // 유효 슬롯 계산
            var slotPhotoCount: [Int: Set<String>] = [:]
            for (assetID, faces) in photoFacesMap {
                for face in faces {
                    slotPhotoCount[face.personIndex, default: []].insert(assetID)
                }
            }

            let validSlots = Set(slotPhotoCount.filter {
                $0.value.count >= SimilarityConstants.minPhotosPerSlot
            }.keys)

            // 검증 게이트 (addGroupIfValid 동일)
            guard validSlots.count >= SimilarityConstants.minValidSlots else { continue }

            let validMembers = groupAssetIDs.filter { assetID in
                guard let faces = photoFacesMap[assetID] else { return false }
                return faces.contains { validSlots.contains($0.personIndex) }
            }

            guard validMembers.count >= SimilarityConstants.minGroupSize else { continue }

            // 캐시 저장
            for (assetID, faces) in photoFacesMap {
                await cache.setFaces(faces, for: assetID)
            }

            let group = SimilarThumbnailGroup(memberAssetIDs: validMembers)
            await cache.addGroup(group, validSlots: validSlots, photoFaces: [:])

            let scanGroup = FaceScanGroup(
                groupID: group.groupID,
                memberAssetIDs: validMembers,
                validPersonIndices: validSlots
            )
            totalGroupsFound += 1
            allGroups.append(scanGroup)
        }

        return FaceScanDebugResult(
            groups: allGroups,
            analyzedAssetIDs: assetIDs,
            terminationReason: .naturalEnd
        )
    }
    #endif
}
