//
//  ViewerViewController+SimilarPhoto.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  ViewerViewController의 유사 사진 기능 Extension입니다.
//  뷰어에서 유사 사진에 +버튼을 표시하고, 얼굴 비교 화면으로 이동합니다.
//
//  주요 기능:
//  - 캐시 hit 시 100ms 이내 +버튼 표시
//  - 캐시 miss 시 분석 후 0.5초 이내 +버튼 표시
//  - +버튼 탭 시 FaceComparisonViewController로 이동
//
//  비활성화 조건:
//  - FeatureFlag 비활성화
//  - VoiceOver 활성화
//  - 선택 모드
//  - 휴지통 모드
//

import UIKit
import Photos

// MARK: - ViewerViewController+SimilarPhoto

extension ViewerViewController {

    // MARK: - Associated Keys

    /// Associated 객체 키 정의
    private enum AssociatedKeys {
        static var faceButtonOverlay: UInt8 = 0
        static var loadingIndicator: UInt8 = 0
        static var analysisObserver: UInt8 = 0
        static var isSimilarPhotoSetup: UInt8 = 0
        static var currentAnalyzingAssetID: UInt8 = 0
        // Zoom 관련
        static var zoomObserver: UInt8 = 0
        static var zoomEndObserver: UInt8 = 0
        static var zoomDebounceTimer: UInt8 = 0
        static var lastZoomInfo: UInt8 = 0
        // Scroll (패닝) 관련
        static var scrollObserver: UInt8 = 0
        static var scrollEndObserver: UInt8 = 0
    }

    // MARK: - Associated Properties

    /// +버튼 오버레이
    private var faceButtonOverlay: FaceButtonOverlay? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.faceButtonOverlay) as? FaceButtonOverlay
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.faceButtonOverlay, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 분석 중 로딩 인디케이터
    private var analysisLoadingIndicator: AnalysisLoadingIndicator? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.loadingIndicator) as? AnalysisLoadingIndicator
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.loadingIndicator, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 분석 완료 알림 옵저버
    private var analysisObserver: NSObjectProtocol? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.analysisObserver) as? NSObjectProtocol
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.analysisObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 유사 사진 기능 설정 여부
    private var isSimilarPhotoSetup: Bool {
        get {
            (objc_getAssociatedObject(self, &AssociatedKeys.isSimilarPhotoSetup) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isSimilarPhotoSetup, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 현재 분석 중인 사진 ID
    private var currentAnalyzingAssetID: String? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.currentAnalyzingAssetID) as? String
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.currentAnalyzingAssetID, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 줌 변경 알림 옵저버
    private var zoomObserver: NSObjectProtocol? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.zoomObserver) as? NSObjectProtocol
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.zoomObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 줌 완료 알림 옵저버
    private var zoomEndObserver: NSObjectProtocol? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.zoomEndObserver) as? NSObjectProtocol
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.zoomEndObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 줌 디바운스 타이머
    private var zoomDebounceTimer: Timer? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.zoomDebounceTimer) as? Timer
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.zoomDebounceTimer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 마지막 줌 정보 (버튼 위치 재계산용)
    private var lastZoomInfo: [String: Any]? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.lastZoomInfo) as? [String: Any]
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.lastZoomInfo, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 스크롤(패닝) 알림 옵저버
    private var scrollObserver: NSObjectProtocol? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.scrollObserver) as? NSObjectProtocol
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.scrollObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 스크롤(패닝) 완료 알림 옵저버
    private var scrollEndObserver: NSObjectProtocol? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.scrollEndObserver) as? NSObjectProtocol
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.scrollEndObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Public Methods (ViewerViewController에서 호출)

    /// 유사 사진 기능 설정
    /// viewDidLoad에서 호출
    func setupSimilarPhotoFeature() {
        // 이미 설정되었으면 무시
        guard !isSimilarPhotoSetup else { return }
        isSimilarPhotoSetup = true

        // 비활성화 조건 확인
        guard shouldEnableSimilarPhoto else { return }

        // UI 컴포넌트 생성
        setupFaceButtonOverlay()
        setupLoadingIndicator()

        // 분석 완료 알림 구독
        setupAnalysisObserver()

        // 줌 알림 구독
        setupZoomObserver()
    }

    /// 뷰어가 표시될 때 호출
    /// viewDidAppear에서 호출
    func showSimilarPhotoOverlay() {
        guard shouldEnableSimilarPhoto else { return }
        checkAndShowFaceButtons()
    }

    /// 스와이프로 다른 사진 이동 완료 시 호출
    /// pageViewController(_:didFinishAnimating:) 에서 호출
    func updateSimilarPhotoOverlay() {
        guard shouldEnableSimilarPhoto else { return }

        // 오버레이 상태 리셋
        faceButtonOverlay?.resetState()

        // 새 사진에 대해 체크
        checkAndShowFaceButtons()
    }

    /// 유사 사진 기능 정리
    /// deinit 또는 dismiss 시 호출
    func cleanupSimilarPhotoFeature() {
        // 옵저버 제거
        if let observer = analysisObserver {
            NotificationCenter.default.removeObserver(observer)
            analysisObserver = nil
        }

        // 줌 옵저버 제거
        if let observer = zoomObserver {
            NotificationCenter.default.removeObserver(observer)
            zoomObserver = nil
        }
        if let observer = zoomEndObserver {
            NotificationCenter.default.removeObserver(observer)
            zoomEndObserver = nil
        }

        // 스크롤 옵저버 제거
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
            scrollObserver = nil
        }
        if let observer = scrollEndObserver {
            NotificationCenter.default.removeObserver(observer)
            scrollEndObserver = nil
        }

        // 타이머 정리
        zoomDebounceTimer?.invalidate()
        zoomDebounceTimer = nil

        // UI 제거
        faceButtonOverlay?.removeFromSuperview()
        faceButtonOverlay = nil

        analysisLoadingIndicator?.removeFromSuperview()
        analysisLoadingIndicator = nil
    }

    // MARK: - Private Methods - Setup

    /// +버튼 오버레이 설정
    private func setupFaceButtonOverlay() {
        let overlay = FaceButtonOverlay()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.delegate = self
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        faceButtonOverlay = overlay
    }

    /// 로딩 인디케이터 설정
    private func setupLoadingIndicator() {
        let indicator = AnalysisLoadingIndicator()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        NSLayoutConstraint.activate([
            indicator.topAnchor.constraint(equalTo: view.topAnchor),
            indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            indicator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            indicator.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        analysisLoadingIndicator = indicator
    }

    /// 분석 완료 알림 옵저버 설정
    private func setupAnalysisObserver() {
        analysisObserver = NotificationCenter.default.addObserver(
            forName: .similarPhotoAnalysisComplete,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAnalysisComplete(notification)
        }
    }

    /// 줌 알림 옵저버 설정
    private func setupZoomObserver() {
        // 줌 중 → 버튼 숨김
        zoomObserver = NotificationCenter.default.addObserver(
            forName: .photoDidZoom,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleZoom(notification)
        }

        // 줌 완료 → 디바운스 후 버튼 재표시
        zoomEndObserver = NotificationCenter.default.addObserver(
            forName: .photoDidEndZoom,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleZoomEnd(notification)
        }

        // 스크롤(패닝) 중 → 버튼 숨김 (줌과 동일하게 처리)
        scrollObserver = NotificationCenter.default.addObserver(
            forName: .photoDidScroll,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleZoom(notification)  // 줌 핸들러 재사용
        }

        // 스크롤(패닝) 완료 → 디바운스 후 버튼 재표시
        scrollEndObserver = NotificationCenter.default.addObserver(
            forName: .photoDidEndScroll,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleZoomEnd(notification)  // 줌 핸들러 재사용
        }
    }

    // MARK: - Private Methods - Zoom Handling

    /// 줌 중 처리 - 버튼 즉시 숨김
    private func handleZoom(_ notification: Notification) {
        // 타이머 취소 (연속 줌 시 재표시 방지)
        zoomDebounceTimer?.invalidate()
        zoomDebounceTimer = nil

        // 줌 정보 저장
        lastZoomInfo = notification.userInfo as? [String: Any]

        // 버튼 숨김 (애니메이션 없이 즉시)
        faceButtonOverlay?.hideButtonsImmediately()
    }

    /// 줌 완료 처리 - 디바운스 후 버튼 재표시
    private func handleZoomEnd(_ notification: Notification) {
        // 줌 정보 저장
        lastZoomInfo = notification.userInfo as? [String: Any]

        // 디바운스 타이머 (0.3초 후 버튼 재표시)
        zoomDebounceTimer?.invalidate()
        zoomDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.showButtonsAfterZoom()
        }
    }

    /// 줌 완료 후 버튼 재표시
    private func showButtonsAfterZoom() {
        guard let zoomInfo = lastZoomInfo,
              let zoomScale = zoomInfo["zoomScale"] as? CGFloat,
              let contentOffset = zoomInfo["contentOffset"] as? CGPoint,
              let imageViewFrame = zoomInfo["imageViewFrame"] as? CGRect else {
            return
        }

        // 버튼 재표시 (줌 상태 기반 위치 계산)
        faceButtonOverlay?.showButtonsWithZoom(
            zoomScale: zoomScale,
            contentOffset: contentOffset,
            imageViewFrame: imageViewFrame
        )
    }

    // MARK: - Private Methods - Feature Check

    /// 유사 사진 기능 활성화 여부
    private var shouldEnableSimilarPhoto: Bool {
        // Feature Flag 확인
        guard FeatureFlags.isSimilarPhotoEnabled else { return false }

        // VoiceOver 확인
        guard !UIAccessibility.isVoiceOverRunning else { return false }

        // 휴지통 모드 확인 (FR-037: 휴지통 화면에서는 유사사진정리 기능 비활성화)
        guard viewerMode != .trash else { return false }

        // 휴지통 사진 확인 (보관함/앨범에서 휴지통 사진을 .normal 모드로 열어도 비활성화)
        guard !coordinator.isTrashed(at: currentIndex) else { return false }

        return true
    }

    // MARK: - Private Methods - Cache Check & Button Display

    /// 현재 사진의 캐시 상태를 확인하고 +버튼 표시
    private func checkAndShowFaceButtons() {
        guard let assetID = coordinator.assetID(at: currentIndex),
              let asset = coordinator.asset(at: currentIndex) else {
            return
        }

        // 캐시 상태 확인 (비동기)
        Task { @MainActor in
            let state = await SimilarityCache.shared.getState(for: assetID)

            switch state {
            case .analyzed(true, _):
                // 캐시 hit (그룹에 속함) → 즉시 +버튼 표시
                await showFaceButtons(for: assetID)

            case .analyzed(false, _):
                // 분석 완료되었지만 그룹에 속하지 않음 → 버튼 미표시
                faceButtonOverlay?.hideButtons()

            case .notAnalyzed:
                // 캐시 miss → 분석 시작
                currentAnalyzingAssetID = assetID
                analysisLoadingIndicator?.show()
                await requestAnalysis(for: asset)

            case .analyzing:
                // 이미 분석 중 → 대기
                currentAnalyzingAssetID = assetID
                analysisLoadingIndicator?.show()
            }
        }
    }

    /// +버튼 표시
    private func showFaceButtons(for assetID: String) async {
        // 유효 슬롯 얼굴 가져오기
        let validFaces = await SimilarityCache.shared.getValidSlotFaces(for: assetID)

        guard !validFaces.isEmpty else {
            faceButtonOverlay?.hideButtons()
            return
        }

        // 현재 사진 크기 가져오기
        guard let asset = coordinator.asset(at: currentIndex) else { return }
        let imageSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)

        // 디버그: 실제 레이아웃 정보 출력
        let safeInsets = view.safeAreaInsets
        let overlayBounds = faceButtonOverlay?.bounds ?? .zero
        print("[FaceButton] DEBUG - view.bounds=\(view.bounds), safeAreaInsets=\(safeInsets), overlayBounds=\(overlayBounds)")

        // 버튼 표시
        faceButtonOverlay?.showButtons(
            for: validFaces,
            imageSize: imageSize,
            viewerFrame: view.bounds,
            assetID: assetID
        )
    }

    // MARK: - Private Methods - Analysis

    /// 분석 요청
    private func requestAnalysis(for asset: PHAsset) async {
        // 분석 범위 계산
        let range = calculateViewerAnalysisRange(currentIndex: currentIndex)

        // 분석 요청 (viewer 소스는 취소 불가)
        guard let fetchResult = coordinator.fetchResult else { return }

        _ = await SimilarityAnalysisQueue.shared.formGroupsForRange(
            range,
            source: .viewer,
            fetchResult: fetchResult
        )
    }

    /// 뷰어용 분석 범위 계산
    ///
    /// 현재 사진 기준 ±7장
    private func calculateViewerAnalysisRange(currentIndex: Int) -> ClosedRange<Int> {
        let extension_ = SimilarityConstants.analysisRangeExtension
        let totalCount = coordinator.totalCount

        let lowerBound = max(0, currentIndex - extension_)
        let upperBound = min(totalCount - 1, currentIndex + extension_)

        return lowerBound...upperBound
    }

    // MARK: - Private Methods - Analysis Complete Handler

    /// 분석 완료 처리
    private func handleAnalysisComplete(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let analyzedAssetIDs = userInfo["analyzedAssetIDs"] as? [String] else {
            return
        }

        // 현재 분석 중인 사진이 완료되었는지 확인
        guard let currentAssetID = currentAnalyzingAssetID,
              analyzedAssetIDs.contains(currentAssetID) else {
            return
        }

        // 로딩 인디케이터 숨김
        analysisLoadingIndicator?.hide()
        currentAnalyzingAssetID = nil

        // +버튼 표시 시도
        Task { @MainActor in
            await showFaceButtons(for: currentAssetID)
        }
    }
}

// MARK: - FaceButtonOverlayDelegate

extension ViewerViewController: FaceButtonOverlayDelegate {

    /// +버튼 탭 처리
    func faceButtonOverlay(
        _ overlay: FaceButtonOverlay,
        didTapFaceAtPersonIndex personIndex: Int,
        face: CachedFace
    ) {
        // T027 구현: 얼굴 비교 화면으로 이동

        Task { @MainActor in
            guard let assetID = coordinator.assetID(at: currentIndex) else { return }

            // 현재 사진의 그룹 정보 가져오기
            let state = await SimilarityCache.shared.getState(for: assetID)

            guard case .analyzed(true, let groupID?) = state,
                  let group = await SimilarityCache.shared.getGroup(groupID: groupID) else {
                return
            }

            // ComparisonGroup 생성
            let comparisonGroup = ComparisonGroup.create(
                from: group,
                currentAssetID: assetID,
                personIndex: personIndex
            )

            // 비교 그룹이 비어있으면 무시
            guard !comparisonGroup.isEmpty else { return }

            // FaceComparisonViewController 표시 (Phase 5에서 구현)
            showFaceComparisonViewController(with: comparisonGroup)
        }
    }

    /// 얼굴 비교 화면 표시
    private func showFaceComparisonViewController(with comparisonGroup: ComparisonGroup) {
        print("[ViewerViewController+SimilarPhoto] FaceComparisonViewController 표시")
        print("  - sourceGroupID: \(comparisonGroup.sourceGroupID)")
        print("  - personIndex: \(comparisonGroup.personIndex)")
        print("  - selectedAssetIDs: \(comparisonGroup.selectedAssetIDs.count)장")

        // FaceComparisonViewController 생성 및 표시
        let faceComparisonVC = FaceComparisonViewController(
            comparisonGroup: comparisonGroup,
            fetchResult: coordinator.fetchResult
        )
        faceComparisonVC.delegate = self
        present(faceComparisonVC, animated: true)
    }
}

// MARK: - FaceComparisonDelegate

extension ViewerViewController: FaceComparisonDelegate {

    /// 사진 삭제 완료 시 호출
    /// FaceComparisonViewController를 닫고 그리드로 복귀
    func faceComparisonViewController(
        _ viewController: FaceComparisonViewController,
        didDeletePhotos deletedAssetIDs: [String]
    ) {
        print("[ViewerViewController+SimilarPhoto] Deleted \(deletedAssetIDs.count) photos from face comparison")
        print("[ViewerViewController+SimilarPhoto] Dismissing FaceComparison and popping to grid")

        // FaceComparisonViewController 닫기 (modal)
        viewController.dismiss(animated: false) { [weak self] in
            // ViewerViewController는 push되었으므로 pop으로 그리드 복귀
            self?.navigationController?.popViewController(animated: true)
        }
    }

    /// 화면 닫기 시 호출 (Cancel 버튼)
    func faceComparisonViewControllerDidClose(_ viewController: FaceComparisonViewController) {
        print("[ViewerViewController+SimilarPhoto] Face comparison closed")

        // +버튼 오버레이 갱신
        updateSimilarPhotoOverlay()
    }
}

