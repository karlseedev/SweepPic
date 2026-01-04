// GridViewController+SimilarPhoto.swift
// 유사 사진 테두리 표시 Extension
//
// T021: GridViewController+SimilarPhoto.swift Extension 생성
// - 스크롤 멈춤 감지 + 0.3초 디바운싱 + 분석 범위 결정 (화면 ±7장)
//
// T022: SimilarityAnalyzer 호출 및 결과 처리
// - 유사 사진 셀에 BorderAnimationLayer 적용
//
// T023: 스크롤 재개 시 분석 취소 + 테두리 제거
//
// T024: 테두리 있는 사진 탭 시 뷰어 이동 처리
//
// T025: VoiceOver/선택 모드/휴지통 화면 + FeatureFlags 체크

import UIKit
import Photos

// MARK: - Similar Photo Border Display

extension GridViewController {

    // MARK: - Constants

    /// 스크롤 멈춤 후 분석 시작 디바운싱 (0.3초)
    private static let similarPhotoDebounceInterval: TimeInterval = 0.3

    /// 분석 범위 (화면 기준 앞뒤 7장)
    private static let analysisRangePhotos: Int = 7

    // MARK: - Associated Object Keys

    private enum AssociatedKeys {
        static var similarPhotoDebounceTimer = "similarPhotoDebounceTimer"
        static var currentSimilarGroups = "currentSimilarGroups"
        static var analysisRangeIndices = "analysisRangeIndices"
    }

    /// 디바운스 타이머 (associated object)
    private var similarPhotoDebounceTimer: Timer? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.similarPhotoDebounceTimer) as? Timer
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.similarPhotoDebounceTimer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 현재 표시 중인 유사 사진 그룹들 (associated object)
    private var currentSimilarGroups: [SimilarThumbnailGroup]? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.currentSimilarGroups) as? [SimilarThumbnailGroup]
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.currentSimilarGroups, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 현재 분석 범위 인덱스들 (associated object)
    private var analysisRangeIndices: [Int]? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.analysisRangeIndices) as? [Int]
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.analysisRangeIndices, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Public Methods

    /// 스크롤 멈춤 시 유사 사진 분석 시작
    /// - GridScroll.swift의 scrollDidEnd()에서 호출
    func triggerSimilarPhotoAnalysis() {
        // T025: Feature Flag 및 접근성 체크
        guard shouldEnableSimilarPhoto() else {
            return
        }

        // 기존 타이머 취소
        similarPhotoDebounceTimer?.invalidate()

        // 0.3초 디바운싱 후 분석 시작
        similarPhotoDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: Self.similarPhotoDebounceInterval,
            repeats: false
        ) { [weak self] _ in
            self?.performSimilarPhotoAnalysis()
        }
    }

    /// 스크롤 재개 시 유사 사진 분석 취소 및 테두리 제거
    /// - GridScroll.swift의 scrollDidBegin()에서 호출
    func cancelSimilarPhotoAnalysis() {
        // 타이머 취소
        similarPhotoDebounceTimer?.invalidate()
        similarPhotoDebounceTimer = nil

        // 분석 큐에서 grid 소스 요청 취소
        SimilarityAnalysisQueue.shared.cancelGridRequests()

        // 테두리 제거
        removeSimilarPhotoBorders()

        // 그룹 정보 초기화
        currentSimilarGroups = nil
        analysisRangeIndices = nil
    }

    /// 유사 사진 테두리 표시 여부 확인
    /// - Parameter assetID: 사진 ID
    /// - Returns: 테두리 표시 여부
    func hasSimilarPhotoBorder(assetID: String) -> Bool {
        guard let groups = currentSimilarGroups else { return false }
        return groups.contains { $0.contains(assetID) }
    }

    /// 유사 사진 그룹 가져오기
    /// - Parameter assetID: 사진 ID
    /// - Returns: 속한 그룹 (없으면 nil)
    func getSimilarPhotoGroup(for assetID: String) -> SimilarThumbnailGroup? {
        guard let groups = currentSimilarGroups else { return nil }
        return groups.first { $0.contains(assetID) }
    }

    // MARK: - Private Methods

    /// 유사 사진 기능 활성화 여부 확인 (T025)
    private func shouldEnableSimilarPhoto() -> Bool {
        // 1. Feature Flag 체크
        guard FeatureFlags.isSimilarPhotoEnabled else {
            return false
        }

        // 2. VoiceOver 활성화 시 비활성화 (FeatureFlags에서 이미 체크하지만 명시적으로)
        guard !UIAccessibility.isVoiceOverRunning else {
            return false
        }

        // 3. 선택 모드에서는 비활성화
        guard !isSelectMode else {
            return false
        }

        // 4. 휴지통 화면에서는 비활성화
        // (GridViewController는 All Photos 전용이므로 별도 체크 불필요)

        return true
    }

    /// 유사 사진 분석 실행
    private func performSimilarPhotoAnalysis() {
        // 분석 범위 결정 (화면 ±7장)
        let rangeIndices = calculateAnalysisRange()
        guard !rangeIndices.isEmpty else { return }

        // 분석 범위 저장
        analysisRangeIndices = rangeIndices

        // 에셋 및 이미지 로딩
        let assets = rangeIndices.compactMap { index -> PHAsset? in
            let indexPath = IndexPath(item: index, section: 0)
            return dataSourceDriver.asset(at: indexPath)
        }

        guard assets.count >= 3 else {
            // 최소 3장 이상이어야 그룹 형성 가능
            return
        }

        // 에셋 ID 배열
        let assetIDs = assets.map { $0.localIdentifier }

        // 이미지 로딩 및 분석
        loadImagesForAnalysis(assets: assets, assetIDs: assetIDs, rangeIndices: rangeIndices)
    }

    /// 분석 범위 계산 (화면 ±7장)
    /// - Returns: 분석 대상 인덱스 배열
    private func calculateAnalysisRange() -> [Int] {
        // 현재 visible indexPaths
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems.sorted { $0.item < $1.item }
        guard !visibleIndexPaths.isEmpty else { return [] }

        // padding 오프셋
        let padding = paddingCellCount

        // visible 범위 (asset 기준)
        let visibleAssetIndices = visibleIndexPaths.compactMap { indexPath -> Int? in
            guard indexPath.item >= padding else { return nil }
            return indexPath.item - padding
        }

        guard let minVisible = visibleAssetIndices.min(),
              let maxVisible = visibleAssetIndices.max() else {
            return []
        }

        // 앞뒤 7장 확장
        let totalCount = dataSourceDriver.count
        let rangeStart = max(0, minVisible - Self.analysisRangePhotos)
        let rangeEnd = min(totalCount - 1, maxVisible + Self.analysisRangePhotos)

        return Array(rangeStart...rangeEnd)
    }

    /// 분석용 이미지 로딩
    private func loadImagesForAnalysis(assets: [PHAsset], assetIDs: [String], rangeIndices: [Int]) {
        let imageLoader = SimilarityImageLoader.shared

        // 배치 로딩 (assetID -> CGImage 딕셔너리 반환)
        imageLoader.loadBatchForAnalysis(assets: assets) { [weak self] imageDict in
            guard let self = self else { return }

            // 로딩 실패한 이미지 필터링
            var validPairs: [(index: Int, assetID: String, image: CGImage)] = []
            for (rangeIndex, assetID) in zip(rangeIndices, assetIDs) {
                if let image = imageDict[assetID] {
                    validPairs.append((rangeIndex, assetID, image))
                }
            }

            guard validPairs.count >= 3 else { return }

            // 분석 실행
            self.analyzeImages(pairs: validPairs)
        }
    }

    /// 이미지 분석 실행
    private func analyzeImages(pairs: [(index: Int, assetID: String, image: CGImage)]) {
        let images = pairs.map { $0.image }
        let assetIDs = pairs.map { $0.assetID }
        // indices는 현재 사용하지 않지만 향후 확장을 위해 유지
        // let indices = pairs.map { $0.index }

        // SimilarityAnalyzer로 그룹 분석
        let analyzer = SimilarityAnalyzer.shared
        let groupIndices = analyzer.analyzeGroupSimilarity(images: images, assetIDs: assetIDs)

        guard !groupIndices.isEmpty else {
            // 유사 그룹 없음
            removeSimilarPhotoBorders()
            currentSimilarGroups = nil
            return
        }

        // SimilarThumbnailGroup 생성
        let groups = groupIndices.map { indexGroup -> SimilarThumbnailGroup in
            let memberIDs = indexGroup.map { assetIDs[$0] }
            return SimilarThumbnailGroup(memberAssetIDs: memberIDs)
        }

        // 그룹 정보 저장
        currentSimilarGroups = groups

        // 캐시에 그룹 등록
        for group in groups {
            SimilarityCache.shared.addGroup(group)
        }

        // UI 업데이트 (메인 스레드)
        DispatchQueue.main.async { [weak self] in
            self?.updateSimilarPhotoBorders(groups: groups, assetIDs: assetIDs)
        }
    }

    /// 유사 사진 테두리 업데이트
    private func updateSimilarPhotoBorders(groups: [SimilarThumbnailGroup], assetIDs: [String]) {
        let padding = paddingCellCount

        // 유사 사진 ID 집합
        let similarAssetIDs = Set(groups.flatMap { $0.memberAssetIDs })

        // visible 셀에 테두리 적용
        for cell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell),
                  indexPath.item >= padding else {
                continue
            }

            let assetIndex = indexPath.item - padding
            let assetIndexPath = IndexPath(item: assetIndex, section: 0)

            guard let asset = dataSourceDriver.asset(at: assetIndexPath) else {
                continue
            }

            if similarAssetIDs.contains(asset.localIdentifier) {
                // 테두리 추가
                BorderAnimationLayer.addToCell(cell, animated: true)
            } else {
                // 테두리 제거
                BorderAnimationLayer.removeBorderLayer(from: cell)
            }
        }
    }

    /// 모든 유사 사진 테두리 제거
    private func removeSimilarPhotoBorders() {
        for cell in collectionView.visibleCells {
            BorderAnimationLayer.removeBorderLayer(from: cell)
        }
    }

    // MARK: - Cell Display Integration

    /// 셀 표시 시 유사 사진 테두리 적용
    /// - Parameters:
    ///   - cell: 표시할 셀
    ///   - asset: 사진 에셋
    /// - Note: PhotoCell의 configure 후 또는 cellForItemAt에서 호출
    func applySimilarPhotoBorderIfNeeded(to cell: UICollectionViewCell, asset: PHAsset) {
        guard shouldEnableSimilarPhoto() else {
            BorderAnimationLayer.removeBorderLayer(from: cell)
            return
        }

        if hasSimilarPhotoBorder(assetID: asset.localIdentifier) {
            BorderAnimationLayer.addToCell(cell, animated: true)
        } else {
            BorderAnimationLayer.removeBorderLayer(from: cell)
        }
    }

    /// 셀 재사용 시 테두리 정리
    /// - Parameter cell: 재사용될 셀
    /// - Note: PhotoCell의 prepareForReuse에서 호출
    func cleanupSimilarPhotoBorder(from cell: UICollectionViewCell) {
        BorderAnimationLayer.removeBorderLayer(from: cell)
    }
}

// MARK: - Scroll Delegate Integration

extension GridViewController {

    /// 스크롤 시작 시 호출 (GridScroll.swift와 연동)
    func similarPhotoScrollDidBegin() {
        cancelSimilarPhotoAnalysis()
    }

    /// 스크롤 종료 시 호출 (GridScroll.swift와 연동)
    func similarPhotoScrollDidEnd() {
        triggerSimilarPhotoAnalysis()
    }
}

// MARK: - T024: 테두리 있는 사진 탭 처리

extension GridViewController {

    /// 유사 사진 셀 탭 시 뷰어로 이동
    /// - Parameter indexPath: 탭된 셀의 indexPath
    /// - Returns: 뷰어 이동 처리 여부
    func handleSimilarPhotoTap(at indexPath: IndexPath) -> Bool {
        let padding = paddingCellCount
        guard indexPath.item >= padding else { return false }

        let assetIndex = indexPath.item - padding
        let assetIndexPath = IndexPath(item: assetIndex, section: 0)

        guard let asset = dataSourceDriver.asset(at: assetIndexPath) else {
            return false
        }

        // 유사 사진 그룹에 속한 경우
        if hasSimilarPhotoBorder(assetID: asset.localIdentifier) {
            // 그룹 정보를 뷰어에 전달하여 +버튼 즉시 표시 가능하도록
            if let group = getSimilarPhotoGroup(for: asset.localIdentifier) {
                // 캐시에 그룹 정보 저장 (뷰어에서 조회)
                SimilarityCache.shared.addGroup(group)
            }

            // 기본 탭 동작 (뷰어 이동)은 GridSelectMode에서 처리
            // 여기서는 추가 설정만 수행
            return false // false 반환하여 기본 처리 계속
        }

        return false
    }
}

// MARK: - Debug

#if DEBUG
extension GridViewController {

    /// 유사 사진 분석 상태 디버그 출력
    func debugSimilarPhotoStatus() {
        print("[SimilarPhoto] Feature enabled: \(FeatureFlags.isSimilarPhotoEnabled)")
        print("[SimilarPhoto] Should enable: \(shouldEnableSimilarPhoto())")
        print("[SimilarPhoto] Current groups: \(currentSimilarGroups?.count ?? 0)")

        if let groups = currentSimilarGroups {
            for (index, group) in groups.enumerated() {
                print("[SimilarPhoto] Group \(index): \(group.memberCount) photos")
            }
        }

        print("[SimilarPhoto] Cache status: \(SimilarityCache.shared.debugStatus)")
        print("[SimilarPhoto] Queue status: \(SimilarityAnalysisQueue.shared.debugStatus)")
    }
}
#endif
