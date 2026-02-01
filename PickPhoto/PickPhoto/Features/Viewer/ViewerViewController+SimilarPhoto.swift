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
import AppCore
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
        // 성능 측정 관련
        static var buttonShowStartTime: UInt8 = 0
        static var viewerPerformanceStats: UInt8 = 0
    }

    // MARK: - Viewer Performance Statistics

    /// 뷰어 성능 측정 데이터 (다회 측정용)
    private final class ViewerPerformanceStats {
        var cacheHitCount: Int = 0
        var cacheMissCount: Int = 0
        var buttonShowTimes: [Double] = []      // 캐시 hit → 버튼 표시 시간 (ms)
        var analysisWaitTimes: [Double] = []    // 캐시 miss → 버튼 표시 시간 (ms)
        var comparisonGroupTimes: [Double] = [] // +버튼 클릭 → 비교화면 표시 시간 (ms)

        /// 통계 계산 헬퍼
        private func stats(_ values: [Double]) -> (avg: Double, min: Double, max: Double) {
            guard !values.isEmpty else { return (0, 0, 0) }
            let avg = values.reduce(0, +) / Double(values.count)
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 0
            return (avg, minVal, maxVal)
        }

        /// 통계 리포트 출력
        func printReport() {
            let totalMeasurements = cacheHitCount + cacheMissCount
            guard totalMeasurements > 0 else { return }

            // 성능 로그 비활성화
            // print("""
            // ╔══════════════════════════════════════════════════════╗
            // ║     VIEWER PERFORMANCE (Vision) - \(totalMeasurements) views           ║
            // ╠══════════════════════════════════════════════════════╣
            // ║  Cache Hit: \(cacheHitCount), Cache Miss: \(cacheMissCount)
            // ╠══════════════════════════════════════════════════════╣
            // ║  Button Show (Cache Hit):
            // ║    avg: \(String(format: "%.2f", btn.avg))ms, min: \(String(format: "%.2f", btn.min))ms, max: \(String(format: "%.2f", btn.max))ms
            // ╠══════════════════════════════════════════════════════╣
            // ║  Button Show (Cache Miss, incl. analysis):
            // ║    avg: \(String(format: "%.2f", wait.avg))ms, min: \(String(format: "%.2f", wait.min))ms, max: \(String(format: "%.2f", wait.max))ms
            // ╠══════════════════════════════════════════════════════╣
            // ║  +Button → Comparison Screen:
            // ║    avg: \(String(format: "%.2f", cmp.avg))ms, min: \(String(format: "%.2f", cmp.min))ms, max: \(String(format: "%.2f", cmp.max))ms
            // ╚══════════════════════════════════════════════════════╝
            // """)
        }
    }

    /// 뷰어 성능 통계 (싱글톤 패턴 - 앱 전체 누적)
    private static var sharedViewerStats = ViewerPerformanceStats()

    /// 버튼 표시 시작 시간 (캐시 체크 시작 시점)
    private var buttonShowStartTime: CFAbsoluteTime {
        get {
            (objc_getAssociatedObject(self, &AssociatedKeys.buttonShowStartTime) as? CFAbsoluteTime) ?? 0
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.buttonShowStartTime, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Associated Properties

    /// +버튼 오버레이 (internal: iOS 26에서 본체의 eye 버튼이 접근 필요)
    var faceButtonOverlay: FaceButtonOverlay? {
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

        // [Timing] 세부 단계 측정
        let s0 = CACurrentMediaTime()

        // UI 컴포넌트 생성
        setupFaceButtonOverlay()
        let s1 = CACurrentMediaTime()

        setupLoadingIndicator()
        let s2 = CACurrentMediaTime()

        // 분석 완료 알림 구독
        setupAnalysisObserver()

        // 줌 알림 구독
        setupZoomObserver()
        let s3 = CACurrentMediaTime()

        Log.print("[Viewer Timing]   setupSimilarPhoto 내부 — faceButtonOverlay: \(String(format: "%.1f", (s1 - s0) * 1000))ms, loadingIndicator: \(String(format: "%.1f", (s2 - s1) * 1000))ms, observers: \(String(format: "%.1f", (s3 - s2) * 1000))ms")
    }

    /// 뷰어가 표시될 때 호출
    /// viewDidAppear에서 호출
    func showSimilarPhotoOverlay() {
        guard shouldEnableSimilarPhoto else { return }

        // 이미 버튼이 표시되어 있으면 건너뜀 (modal dismiss 후 viewDidAppear 재호출 시 깜빡거림 방지)
        if faceButtonOverlay?.hasVisibleButtons == true {
            return
        }

        checkAndShowFaceButtons()
    }

    /// 스와이프로 다른 사진 이동 완료 시 호출
    /// pageViewController(_:didFinishAnimating:) 에서 호출
    ///
    /// - Parameter resetZoom: true면 줌 상태 초기화 (스와이프 시), false면 줌 상태 유지 (얼굴 그리드 복귀 시)
    func updateSimilarPhotoOverlay(resetZoom: Bool = true) {
        guard shouldEnableSimilarPhoto else { return }

        if resetZoom {
            // 스와이프: 오버레이 상태 완전 리셋
            faceButtonOverlay?.resetState()
        } else {
            // 얼굴 그리드 복귀: 버튼만 제거하고 줌/토글 상태 유지
            faceButtonOverlay?.clearButtonsOnly()
        }

        // 새 사진에 대해 체크 (showFaceButtons에서 줌 상태 자동 인식)
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
        let fb0 = CACurrentMediaTime()
        let overlay = FaceButtonOverlay()
        let fb1 = CACurrentMediaTime()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.delegate = self
        view.addSubview(overlay)
        let fb2 = CACurrentMediaTime()

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let fb3 = CACurrentMediaTime()

        faceButtonOverlay = overlay
        Log.print("[Viewer Timing]     setupFaceButtonOverlay — FaceButtonOverlay(): \(String(format: "%.1f", (fb1-fb0)*1000))ms, addSubview: \(String(format: "%.1f", (fb2-fb1)*1000))ms, constraints: \(String(format: "%.1f", (fb3-fb2)*1000))ms")
    }

    /// 로딩 인디케이터 설정
    private func setupLoadingIndicator() {
        let li0 = CACurrentMediaTime()
        let indicator = AnalysisLoadingIndicator()
        let li1 = CACurrentMediaTime()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)
        let li2 = CACurrentMediaTime()

        NSLayoutConstraint.activate([
            indicator.topAnchor.constraint(equalTo: view.topAnchor),
            indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            indicator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            indicator.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let li3 = CACurrentMediaTime()

        analysisLoadingIndicator = indicator
        Log.print("[Viewer Timing]     setupLoadingIndicator — AnalysisLoadingIndicator(): \(String(format: "%.1f", (li1-li0)*1000))ms, addSubview: \(String(format: "%.1f", (li2-li1)*1000))ms, constraints: \(String(format: "%.1f", (li3-li2)*1000))ms")
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

        // 성능 측정: 시작 시간 기록
        buttonShowStartTime = CFAbsoluteTimeGetCurrent()

        // 캐시 상태 확인 (비동기)
        Task { @MainActor in
            let state = await SimilarityCache.shared.getState(for: assetID)

            switch state {
            case .analyzed(true, _):
                // 캐시 hit (그룹에 속함) → 즉시 +버튼 표시
                await showFaceButtons(for: assetID, isCacheHit: true)

            case .analyzed(false, _):
                // 분석 완료되었지만 그룹에 속하지 않음 → 버튼 미표시
                faceButtonOverlay?.hideButtons()
                showNavBarEyeButton(false)

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
    /// - Parameters:
    ///   - assetID: 사진 ID
    ///   - isCacheHit: 캐시 hit 여부 (성능 측정용)
    private func showFaceButtons(for assetID: String, isCacheHit: Bool = false) async {
        // 유효 슬롯 얼굴 가져오기
        let validFaces = await SimilarityCache.shared.getValidSlotFaces(for: assetID)

        guard !validFaces.isEmpty else {
            faceButtonOverlay?.hideButtons()
            showNavBarEyeButton(false)
            return
        }

        // 현재 사진 크기 가져오기
        guard let asset = coordinator.asset(at: currentIndex) else { return }
        let imageSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)

        // 버튼 표시 (줌 상태 확인)
        // VC의 lastZoomInfo에 줌 정보가 있으면 줌 기반 위치로 표시
        if let zoomInfo = lastZoomInfo,
           let zoomScale = zoomInfo["zoomScale"] as? CGFloat,
           let contentOffset = zoomInfo["contentOffset"] as? CGPoint,
           let imageViewFrame = zoomInfo["imageViewFrame"] as? CGRect,
           zoomScale > 1.0 {
            // 줌 상태: 먼저 기본 정보 설정 후 줌 기반 위치로 표시
            faceButtonOverlay?.showButtons(
                for: validFaces,
                imageSize: imageSize,
                viewerFrame: view.bounds,
                assetID: assetID
            )
            faceButtonOverlay?.showButtonsWithZoom(
                zoomScale: zoomScale,
                contentOffset: contentOffset,
                imageViewFrame: imageViewFrame
            )
        } else {
            // 1x 스케일: 기본 위치로 표시
            faceButtonOverlay?.showButtons(
                for: validFaces,
                imageSize: imageSize,
                viewerFrame: view.bounds,
                assetID: assetID
            )
        }

        // 성능 측정: 버튼 표시 완료 시간 기록
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - buttonShowStartTime) * 1000
        if isCacheHit {
            Self.sharedViewerStats.cacheHitCount += 1
            Self.sharedViewerStats.buttonShowTimes.append(elapsedMs)
            Log.print("[ViewerPerf] Cache HIT - Button shown in \(String(format: "%.2f", elapsedMs))ms")
        }

        // 3회 이상 측정되면 통계 출력
        let total = Self.sharedViewerStats.cacheHitCount + Self.sharedViewerStats.cacheMissCount
        if total >= 3 && total % 3 == 0 {
            Self.sharedViewerStats.printReport()
        }

        // iOS 26: 네비게이션 바 eye 버튼 표시
        showNavBarEyeButton(true)
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

        // 성능 측정: 캐시 miss (분석 포함) 시간 기록
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - buttonShowStartTime) * 1000
        Self.sharedViewerStats.cacheMissCount += 1
        Self.sharedViewerStats.analysisWaitTimes.append(elapsedMs)
        Log.print("[ViewerPerf] Cache MISS - Analysis completed in \(String(format: "%.2f", elapsedMs))ms")

        // +버튼 표시 시도 (isCacheHit: false → 성능 통계에 중복 기록 안 함)
        Task { @MainActor in
            await showFaceButtons(for: currentAssetID, isCacheHit: false)

            // 3회 이상 측정되면 통계 출력
            let total = Self.sharedViewerStats.cacheHitCount + Self.sharedViewerStats.cacheMissCount
            if total >= 3 && total % 3 == 0 {
                Self.sharedViewerStats.printReport()
            }
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

        // 성능 측정: +버튼 클릭 시간 기록
        let tapStartTime = CFAbsoluteTimeGetCurrent()

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

            // 성능 측정: 비교 그룹 생성 완료 시간 기록
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - tapStartTime) * 1000
            Self.sharedViewerStats.comparisonGroupTimes.append(elapsedMs)
            Log.print("[ViewerPerf] +Button → ComparisonGroup in \(String(format: "%.2f", elapsedMs))ms")

            // FaceComparisonViewController 표시 (Phase 5에서 구현)
            showFaceComparisonViewController(with: comparisonGroup)
        }
    }

    /// 얼굴 비교 화면 표시
    /// - iOS 26+: UINavigationController로 감싸서 Liquid Glass 네비게이션바 사용
    /// - iOS 16~25: 커스텀 타이틀바 사용, 직접 present
    private func showFaceComparisonViewController(with comparisonGroup: ComparisonGroup) {
        Log.print("[ViewerViewController+SimilarPhoto] FaceComparisonViewController 표시")
        print("  - sourceGroupID: \(comparisonGroup.sourceGroupID)")
        print("  - personIndex: \(comparisonGroup.personIndex)")
        print("  - selectedAssetIDs: \(comparisonGroup.selectedAssetIDs.count)장")

        // FaceComparisonViewController 생성
        let faceComparisonVC = FaceComparisonViewController(
            comparisonGroup: comparisonGroup
        )
        faceComparisonVC.delegate = self

        if #available(iOS 26.0, *) {
            // iOS 26+: UINavigationController로 감싸서 Liquid Glass 네비게이션바 사용
            let navController = UINavigationController(rootViewController: faceComparisonVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        } else {
            // iOS 16~25: 커스텀 타이틀바 사용, 직접 present
            faceComparisonVC.modalPresentationStyle = .fullScreen
            present(faceComparisonVC, animated: true)
        }
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
        Log.print("[ViewerViewController+SimilarPhoto] Deleted \(deletedAssetIDs.count) photos from face comparison")
        Log.print("[ViewerViewController+SimilarPhoto] Dismissing FaceComparison and viewer")

        // FaceComparisonViewController 닫기 (modal)
        viewController.dismiss(animated: false) { [weak self] in
            // ViewerViewController도 modal이므로 dismiss로 그리드 복귀
            self?.dismiss(animated: true)
        }
    }

    /// 화면 닫기 시 호출 (Cancel 버튼)
    func faceComparisonViewControllerDidClose(_ viewController: FaceComparisonViewController) {
        Log.print("[ViewerViewController+SimilarPhoto] Face comparison closed")

        // Cancel로 닫을 때는 버튼을 건드리지 않음
        // - 버튼이 이미 표시되어 있고, modal dismiss 후 그대로 보임
        // - updateSimilarPhotoOverlay() 호출 시 clearButtonsOnly()로 버튼 제거 → 깜빡거림 발생
    }
}

