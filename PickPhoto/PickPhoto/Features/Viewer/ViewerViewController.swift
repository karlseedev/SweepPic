// ViewerViewController.swift
// 전체 화면 사진 뷰어
//
// T028: ViewerViewController 생성
// - UIPageViewController로 좌우 스와이프
//
// T031: 아래 스와이프로 닫기 구현
// - 뷰어 닫고 그리드로 복귀
//
// T033: 더블탭/핀치 줌 구현
// - 이미지 확대/축소
//
// T034: 원형 플로팅 삭제 버튼 생성
// - 하단에 항상 표시
//
// T035: 휴지통 사진 뷰어 모드 구현
// - 삭제 버튼 대신 "복구/완전삭제" 옵션 표시

import UIKit
import Photos
import AppCore
import Vision

/// 뷰어 모드
/// 일반 모드 vs 휴지통 모드에 따라 버튼이 다르게 표시됨
enum ViewerMode {
    /// 일반 모드: 삭제 버튼 표시
    case normal

    /// 휴지통 모드: 복구/완전삭제 버튼 표시
    case trash
}

/// 뷰어 델리게이트
/// 삭제/복구/완전삭제 액션을 처리
protocol ViewerViewControllerDelegate: AnyObject {
    /// 사진 삭제 요청 (앱 내 휴지통으로 이동)
    /// - Parameter assetID: 삭제할 사진 ID
    func viewerDidRequestDelete(assetID: String)

    /// 사진 복구 요청 (휴지통에서 복원)
    /// - Parameter assetID: 복구할 사진 ID
    func viewerDidRequestRestore(assetID: String)

    /// 사진 완전삭제 요청 (iOS 휴지통으로 이동)
    /// - Parameter assetID: 완전삭제할 사진 ID
    func viewerDidRequestPermanentDelete(assetID: String)

    /// 뷰어가 닫힐 때 호출
    /// - Parameter currentAssetID: 마지막으로 표시한 사진 ID
    func viewerWillClose(currentAssetID: String?)
}

/// 전체 화면 사진 뷰어
/// UIPageViewController 기반으로 좌우 스와이프 탐색 지원
final class ViewerViewController: UIViewController {

    // MARK: - Constants

    /// 버튼 center에서 safeArea bottom까지의 거리
    /// FloatingTabBar의 capsuleHeight/2와 동일 (56/2 = 28)
    private static let buttonCenterFromBottom: CGFloat = 28

    /// 아래 스와이프 닫기 임계값 (화면 높이의 %)
    private static let dismissThreshold: CGFloat = 0.15

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: ViewerViewControllerDelegate?

    /// 현재 모드 (일반/휴지통)
    /// Extension에서 접근 가능하도록 internal 접근 레벨
    let viewerMode: ViewerMode

    /// Coordinator (네비게이션 및 데이터 관리)
    /// Extension에서 접근 가능하도록 internal 접근 레벨
    let coordinator: ViewerCoordinatorProtocol

    /// 스와이프 삭제 핸들러
    private var swipeDeleteHandler: SwipeDeleteHandler?

    /// 현재 표시 중인 인덱스
    /// iOS 18+ zoom transition의 sourceViewProvider에서 외부 접근 필요
    private(set) var currentIndex: Int

    // MARK: - Debug: PageScroll 분석용

    /// 페이지 스크롤뷰 참조
    private weak var pageScrollView: UIScrollView?

    /// 전환 ID (각 전환을 구분)
    private var transitionId: Int = 0

    /// 전환 중 여부
    private var isTransitioning = false

    /// 마지막 스크롤 로그 시간 (쓰로틀용)
    private var lastPageScrollLogTime: CFTimeInterval = 0

    // MARK: - Phase 2: LOD1 디바운스

    /// LOD1 디바운스 타이머 (150ms)
    private var lod1DebounceTimer: Timer?

    /// LOD1 디바운스 지연 시간
    private static let lod1DebounceDelay: TimeInterval = 0.15

    /// 페이지 뷰 컨트롤러
    private lazy var pageViewController: UIPageViewController = {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 10]
        )
        pvc.dataSource = self
        pvc.delegate = self
        return pvc
    }()

    /// 삭제 버튼 (일반 모드 - Liquid Glass 아이콘 버튼)
    /// iOS 26 스펙: 38×38, iconSize 28 (medium 44×44 사용)
    private lazy var deleteButton: GlassIconButton = {
        // iOS 26 시스템 .trash와 동일하게 outline 스타일 사용
        let button = GlassIconButton(icon: "trash", size: .medium, tintColor: .systemRed)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 복구 버튼 (휴지통 모드 - Liquid Glass 텍스트 버튼)
    /// iOS 26 스펙: 텍스트 "복구", tintColor #30D158 (녹색)
    private lazy var restoreButton: GlassTextButton = {
        let button = GlassTextButton(title: "복구", style: .plain, tintColor: .systemGreen)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(restoreButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 완전삭제 버튼 (휴지통 모드 - Liquid Glass 텍스트 버튼)
    /// iOS 26 스펙: 텍스트 "삭제", tintColor #FF4245 (빨간색)
    private lazy var permanentDeleteButton: GlassTextButton = {
        let button = GlassTextButton(title: "삭제", style: .plain, tintColor: .systemRed)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(permanentDeleteButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 닫기 제스처를 위한 배경 뷰
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 아래 스와이프 닫기 팬 제스처
    private lazy var dismissPanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        gesture.delegate = self
        return gesture
    }()

    /// 닫기 애니메이션 중 여부
    private var isDismissing = false

    /// 드래그 시작 위치
    private var dragStartY: CGFloat = 0

    /// 최초 표시 페이드 인 적용 여부 (시스템 전환 대신 사용)
    private var didPerformInitialFadeIn: Bool = false


    /// iOS 18+ zoom transition 사용 시 커스텀 페이드 애니메이션 비활성화 플래그
    /// preferredTransition = .zoom 설정 시 true로 설정해야 이중 애니메이션 방지
    var disableCustomFadeAnimation: Bool = false

    // MARK: - iOS 26+ System UI Properties

    /// iOS 26+ 시스템 UI 사용 여부
    private var useSystemUI: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    /// iOS 26+ 시스템 UI 설정 완료 여부 (중복 설정 방지)
    private var didSetupSystemUI: Bool = false

    /// iOS 26+ 툴바 삭제 버튼 참조
    private var toolbarDeleteItem: UIBarButtonItem?

    /// iOS 26+ 툴바 복구 버튼 참조
    private var toolbarRestoreItem: UIBarButtonItem?

    /// iOS 26+ 툴바 완전삭제 버튼 참조
    private var toolbarPermanentDeleteItem: UIBarButtonItem?

    /// iOS 26+ 네비게이션 바 눈 아이콘 버튼 참조 (유사 사진 토글)
    private var navBarEyeItem: UIBarButtonItem?

    #if DEBUG
    /// 디버그 분석 버튼 (휴지통 모드에서만 표시)
    private lazy var debugAnalyzeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("분석", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(debugAnalyzeButtonTapped), for: .touchUpInside)
        return button
    }()
    #endif

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - coordinator: 뷰어 코디네이터
    ///   - startIndex: 시작 인덱스
    ///   - mode: 뷰어 모드 (기본: 일반)
    init(coordinator: ViewerCoordinatorProtocol, startIndex: Int, mode: ViewerMode = .normal) {
        self.coordinator = coordinator
        self.currentIndex = startIndex
        self.viewerMode = mode
        super.init(nibName: nil, bundle: nil)

        // iOS 16~25: hidesBottomBarWhenPushed 사용 안 함 (자동 복원 차단)
        // iOS 26+: 시스템 UX 유지
        if #available(iOS 26.0, *) {
            hidesBottomBarWhenPushed = true
        }
        // else: 기본값 false 유지 (iOS 16~25에서 자동 복원 문제 방지)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        setupSwipeDeleteHandler()
        displayInitialPhoto()

        // T026: 유사 사진 기능 설정
        setupSimilarPhotoFeature()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // FloatingOverlay 가시성은 TabBarController의 UINavigationControllerDelegate가 관리
        // (BarsVisibilityControlling 프로토콜 기반)

        // iOS 26+: navigationController 존재 확인 후 시스템 UI 설정
        if #available(iOS 26.0, *) {
            setupSystemUIIfNeeded()
        }

        // 초기 버튼 상태 설정 (현재 사진의 휴지통 상태에 따라)
        // iOS 26에서는 setupSystemUIIfNeeded() 이후에 호출해야 함
        updateToolbarForCurrentPhoto()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if isBeingPresented && !didPerformInitialFadeIn {
            didPerformInitialFadeIn = true
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.view.alpha = 1
            }
        }

        // T026: 유사 사진 오버레이 표시
        showSimilarPhotoOverlay()
    }

    // MARK: - Rotation

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in
            // 회전 중: FaceButtonOverlay 즉시 숨김 (위치 오류 방지)
            self?.faceButtonOverlay?.hideButtonsImmediately()
        }, completion: { [weak self] _ in
            // 회전 완료: FaceButtonOverlay 재표시
            self?.refreshFaceButtonsAfterRotation()
        })
    }

    /// 회전 후 +버튼 위치 갱신
    /// - Note: shouldEnableSimilarPhoto는 Extension의 private 프로퍼티이므로
    ///         faceButtonOverlay 존재 여부로 기능 활성화 판단
    private func refreshFaceButtonsAfterRotation() {
        // faceButtonOverlay가 nil이면 SimilarPhoto 기능 비활성화 상태
        faceButtonOverlay?.layoutButtons(for: view.bounds)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // FloatingOverlay 가시성은 TabBarController의 UINavigationControllerDelegate가 관리
        // (BarsVisibilityControlling 프로토콜 기반 - pop 시 자동으로 다음 VC 정책 적용)

        // 툴바 숨김은 TabBarController의 applyBarsVisibilityPolicy에서 처리
        // (다음 VC의 prefersToolbarHidden 정책에 따라 자동 적용)

        // 현재 표시 중인 사진 ID 전달
        let currentAssetID = coordinator.assetID(at: currentIndex)
        delegate?.viewerWillClose(currentAssetID: currentAssetID)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        // 배경
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 페이지 뷰 컨트롤러 추가
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        pageViewController.didMove(toParent: self)

        // iOS 16~25: 커스텀 버튼 추가
        // iOS 26+: viewWillAppear에서 시스템 UI 설정 (navigationController 필요)
        if !useSystemUI {
            setupActionButtons()
            setupBackButton()
        }

        #if DEBUG
        // 휴지통 모드에서 디버그 분석 버튼 추가
        if viewerMode == .trash {
            setupDebugAnalyzeButton()
        }
        #endif
    }

    #if DEBUG
    /// 디버그 분석 버튼 설정 (상단 오른쪽)
    private func setupDebugAnalyzeButton() {
        view.addSubview(debugAnalyzeButton)
        NSLayoutConstraint.activate([
            debugAnalyzeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            debugAnalyzeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            debugAnalyzeButton.widthAnchor.constraint(equalToConstant: 60),
            debugAnalyzeButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    /// 디버그 분석 버튼 탭 - 현재 이미지 재분석
    @objc private func debugAnalyzeButtonTapped() {
        guard let asset = coordinator.asset(at: currentIndex) else {
            Log.print("[Debug] asset을 찾을 수 없음")
            return
        }

        Log.print("[Debug] ========== 재분석 시작 ==========")
        Log.print("[Debug] assetID: \(asset.localIdentifier)")
        Log.print("[Debug] mediaType: \(asset.mediaType == .image ? "image" : "video")")
        Log.print("[Debug] pixelSize: \(asset.pixelWidth) x \(asset.pixelHeight)")

        Task {
            let analyzer = QualityAnalyzer.shared
            let result = await analyzer.analyze(asset)

            await MainActor.run {
                Log.print("[Debug] ========== 분석 결과 ==========")
                Log.print("[Debug] verdict: \(result.verdict)")
                Log.print("[Debug] signals: \(result.signals.map { $0.kind.rawValue })")
                Log.print("[Debug] analysisTime: \(String(format: "%.1f", result.analysisTimeMs))ms")
                Log.print("[Debug] method: \(result.analysisMethod.rawValue)")

                if result.safeGuardApplied, let reason = result.safeGuardReason {
                    Log.print("[Debug] safeGuard: \(reason.rawValue)")
                }

                // 추가 상세 정보 (노출 분석 결과)
                self.debugPrintExposureMetrics(for: asset)

                Log.print("[Debug] ====================================")
            }
        }
    }

    /// 디버그: 노출 분석 상세 정보 출력
    private func debugPrintExposureMetrics(for asset: PHAsset) {
        Task {
            do {
                let imageLoader = CleanupImageLoader.shared
                let image = try await imageLoader.loadImage(for: asset)

                let exposureAnalyzer = ExposureAnalyzer.shared
                let metrics = try exposureAnalyzer.analyze(image)

                let hasExtremeExposure = metrics.luminance < CleanupConstants.extremeDarkLuminance ||
                                          metrics.luminance > CleanupConstants.extremeBrightLuminance

                await MainActor.run {
                    Log.print("[Debug] -- 노출 분석 상세 --")
                    Log.print("[Debug] 휘도: \(String(format: "%.3f", metrics.luminance))")
                    Log.print("[Debug] RGB Std: \(String(format: "%.2f", metrics.rgbStd))")
                    Log.print("[Debug] hasExtremeExposure: \(hasExtremeExposure)")
                    Log.print("[Debug] 중앙휘도: \(String(format: "%.3f", metrics.centerLuminance))")
                    Log.print("[Debug] 모서리휘도: \(String(format: "%.3f", metrics.cornerLuminance))")
                }

                // 텍스트 감지 테스트 (hasExtremeExposure 여부와 관계없이 실행)
                await debugPrintTextDetection(image: image)

            } catch {
                await MainActor.run {
                    Log.print("[Debug] 노출 분석 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 디버그: Vision 텍스트 감지 테스트
    private func debugPrintTextDetection(image: CGImage) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    Log.print("[Debug] -- 텍스트 감지 실패: \(error.localizedDescription)")
                    continuation.resume()
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    Log.print("[Debug] -- 텍스트 감지: 결과 없음")
                    continuation.resume()
                    return
                }

                let textBlockCount = observations.count
                let isTextScreenshot = textBlockCount >= CleanupConstants.textBlockCountThreshold

                Log.print("[Debug] -- 텍스트 감지 --")
                Log.print("[Debug] 텍스트 블록 수: \(textBlockCount)")
                Log.print("[Debug] 임계값: \(CleanupConstants.textBlockCountThreshold)")
                Log.print("[Debug] isTextScreenshot: \(isTextScreenshot)")

                // 감지된 텍스트 샘플 출력 (최대 5개)
                if textBlockCount > 0 {
                    Log.print("[Debug] 텍스트 샘플:")
                    for (index, observation) in observations.prefix(5).enumerated() {
                        if let candidate = observation.topCandidates(1).first {
                            Log.print("[Debug]   \(index + 1). \"\(candidate.string.prefix(30))...\"")
                        }
                    }
                }

                continuation.resume()
            }

            request.recognitionLevel = CleanupConstants.textRecognitionUseFastMode ? .fast : .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                Log.print("[Debug] -- Vision 요청 실패: \(error.localizedDescription)")
                continuation.resume()
            }
        }
    }
    #endif

    /// iOS 16~25 전용 뒤로가기 버튼 설정
    /// Push 전환 방식이지만 네비바는 숨긴 상태로 유지하고 커스텀 버튼 사용
    /// iOS 26 스펙: 44×44, iconSize 22pt (GlassIconButton과 동일)
    private func setupBackButton() {
        // GlassIconButton 사용 (iOS 26 NavBar 아이콘 버튼과 동일 스펙)
        let backButton = GlassIconButton(icon: "chevron.backward", size: .medium, tintColor: .white)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16)
        ])
    }

    /// 액션 버튼 설정 (모드에 따라 다름)
    /// 버튼 위치: FloatingTabBar의 Delete 버튼과 동일 (safeArea bottom에서 28pt 위에 center)
    private func setupActionButtons() {
        switch viewerMode {
        case .normal:
            // 삭제 버튼 (중앙)
            view.addSubview(deleteButton)
            NSLayoutConstraint.activate([
                deleteButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                deleteButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])

            // 복구 버튼 (중앙 - 삭제 버튼과 같은 위치, 휴지통 사진일 때 표시)
            view.addSubview(restoreButton)
            NSLayoutConstraint.activate([
                restoreButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                restoreButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])

            // 초기 상태: 삭제 버튼만 표시, 복구 버튼은 숨김
            restoreButton.isHidden = true

        case .trash:
            // 복구 버튼 (왼쪽 끝) - iOS 26 스펙: 양쪽 끝 배치
            view.addSubview(restoreButton)
            NSLayoutConstraint.activate([
                restoreButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
                restoreButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])

            // 완전삭제 버튼 (오른쪽 끝) - iOS 26 스펙: 양쪽 끝 배치
            view.addSubview(permanentDeleteButton)
            NSLayoutConstraint.activate([
                permanentDeleteButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
                permanentDeleteButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])
        }
    }

    /// 제스처 설정
    private func setupGestures() {
        // 아래 스와이프로 닫기
        view.addGestureRecognizer(dismissPanGesture)
    }

    /// 스와이프 삭제 핸들러 설정
    private func setupSwipeDeleteHandler() {
        // 일반 모드에서만 위 스와이프 삭제 가능
        guard viewerMode == .normal else { return }

        swipeDeleteHandler = SwipeDeleteHandler { [weak self] in
            self?.handleSwipeDelete()
        }

        if let handler = swipeDeleteHandler {
            view.addGestureRecognizer(handler.panGesture)
        }
    }

    /// 초기 미디어 표시 (사진/동영상)
    private func displayInitialPhoto() {
        guard let pageVC = createPageViewController(at: currentIndex) else { return }

        pageViewController.setViewControllers(
            [pageVC],
            direction: .forward,
            animated: false,
            completion: nil
        )

        // 초기 페이지가 VideoPageViewController면 비디오 요청 트리거
        if let videoVC = pageVC as? VideoPageViewController {
            videoVC.requestVideoIfNeeded()
        }

        // Phase 2: LOD1 원본 이미지 요청 스케줄링
        // (setViewControllers는 delegate를 호출하지 않으므로 수동 호출)
        scheduleLOD1Request()
    }

    // MARK: - Actions

    /// 뒤로가기 버튼 탭
    @objc private func backButtonTapped() {
        dismissWithFadeOut()
    }

    /// 삭제 버튼 탭 (일반 모드)
    @objc private func deleteButtonTapped() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // 삭제 요청
        delegate?.viewerDidRequestDelete(assetID: assetID)

        // 다음 사진으로 이동 (이전 사진 우선 규칙)
        moveToNextAfterDelete()

        // 이동 후 버튼 상태 업데이트 (다음 사진이 휴지통일 수 있음)
        updateToolbarForCurrentPhoto()
    }

    /// 복구 버튼 탭
    /// - .trash 모드: 다음 사진으로 이동 (목록에서 사라짐)
    /// - .normal 모드: 제자리 유지, 테두리 제거 + 버튼 교체
    @objc private func restoreButtonTapped() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // 복구 요청
        delegate?.viewerDidRequestRestore(assetID: assetID)

        if viewerMode == .trash {
            // .trash 모드: 다음 사진으로 이동 (목록에서 사라짐)
            moveToNextAfterDelete()
        } else {
            // .normal 모드: 제자리에서 UI만 업데이트
            updateCurrentPageTrashedState(isTrashed: false)
            updateToolbarForCurrentPhoto()
        }
    }

    /// 완전삭제 버튼 탭 (휴지통 모드)
    /// 주의: permanentDelete는 비동기 작업이므로 moveToNextAfterDelete()를 여기서 호출하지 않음
    /// 삭제 완료 후 delegate에서 handleDeleteComplete()를 호출해야 함
    @objc private func permanentDeleteButtonTapped() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // 완전삭제 요청 (비동기 - iOS 시스템 팝업 대기)
        // 삭제 완료 후 delegate에서 handleDeleteComplete() 호출 필요
        delegate?.viewerDidRequestPermanentDelete(assetID: assetID)

        // 비동기 작업이므로 여기서 moveToNextAfterDelete() 호출하지 않음
        // TrashAlbumViewController에서 삭제 완료 후 handleDeleteComplete() 호출
    }

    /// 삭제 완료 후 호출 (외부에서 호출)
    /// permanentDelete가 비동기이므로 삭제 완료 후 이 메서드를 호출해야 함
    func handleDeleteComplete() {
        moveToNextAfterDelete()
    }

    // MARK: - Swipe Delete

    /// 위 스와이프 삭제 처리 (T030)
    private func handleSwipeDelete() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // 삭제 요청
        delegate?.viewerDidRequestDelete(assetID: assetID)

        // 다음 사진으로 이동
        moveToNextAfterDelete()

        // 이동 후 버튼 상태 업데이트 (다음 사진이 휴지통일 수 있음)
        updateToolbarForCurrentPhoto()
    }

    /// 삭제 후 다음 사진으로 이동
    /// "이전 사진 우선" 규칙 적용 (FR-013)
    private func moveToNextAfterDelete() {
        // 다음 인덱스를 먼저 계산 (갱신 전 totalCount 기준)
        let nextIndex = coordinator.nextIndexAfterDelete(currentIndex: currentIndex)

        // filteredIndices 갱신 (삭제/복구 반영)
        coordinator.refreshFilteredIndices()

        let newTotalCount = coordinator.totalCount

        // 모든 사진이 삭제되면 닫기
        if newTotalCount == 0 {
            dismissWithFadeOut()
            return
        }

        // 범위 확인
        guard nextIndex >= 0 && nextIndex < newTotalCount else {
            dismissWithFadeOut()
            return
        }

        // 이동 방향 결정: 이전 사진으로 갔으면 reverse, 다음으로 갔으면 forward
        // (currentIndex 업데이트 전에 비교해야 함)
        let direction: UIPageViewController.NavigationDirection = (nextIndex < currentIndex) ? .reverse : .forward

        currentIndex = nextIndex

        // 새 뷰 컨트롤러 생성 및 표시 (사진/동영상)
        guard let pageVC = createPageViewController(at: currentIndex) else {
            dismissWithFadeOut()
            return
        }
        pageViewController.setViewControllers(
            [pageVC],
            direction: direction,
            animated: true,
            completion: { [weak self] _ in
                // 삭제 후 이동 시에도 유사 사진 오버레이 업데이트
                // (setViewControllers는 pageViewController delegate를 호출하지 않으므로 수동 호출)
                self?.updateSimilarPhotoOverlay()

                // Phase 2: LOD1 원본 이미지 요청 스케줄링
                self?.scheduleLOD1Request()
            }
        )
    }

    // MARK: - Dismiss Pan Gesture (T031)

    /// 아래 스와이프로 닫기 처리
    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .began:
            dragStartY = translation.y

        case .changed:
            // 아래로만 드래그 가능
            let offsetY = max(0, translation.y - dragStartY)
            let progress = min(offsetY / view.bounds.height, 1.0)

            if #available(iOS 26.0, *) {
                // iOS 26: 배경 투명도만 조절 (transform 생략으로 dismiss 충돌 방지)
                backgroundView.alpha = 1.0 - progress * 0.5
            } else {
                // iOS 16~25: 기존 드래그 애니메이션
                backgroundView.alpha = 1.0 - progress * 0.5
                pageViewController.view.transform = CGAffineTransform(translationX: 0, y: offsetY)
            }

        case .ended, .cancelled:
            let offsetY = translation.y - dragStartY
            let screenHeight = view.bounds.height
            let threshold = screenHeight * Self.dismissThreshold

            // 임계값을 넘었거나 빠른 속도로 스와이프한 경우 닫기
            if offsetY > threshold || velocity.y > 1000 {
                dismissWithAnimation()
            } else {
                // 원위치로 복귀
                if #available(iOS 26.0, *) {
                    // iOS 26: 배경 투명도만 복귀 (transform 미사용)
                    UIView.animate(withDuration: 0.2) {
                        self.backgroundView.alpha = 1.0
                    }
                } else {
                    // iOS 16~25: 배경 + transform 복귀
                    UIView.animate(withDuration: 0.2) {
                        self.backgroundView.alpha = 1.0
                        self.pageViewController.view.transform = .identity
                    }
                }
            }

        default:
            break
        }
    }

    /// 애니메이션과 함께 닫기 (Push → Pop)
    private func dismissWithAnimation() {
        guard !isDismissing else { return }
        isDismissing = true

        if #available(iOS 26.0, *) {
            // iOS 26: 페이드 아웃 후 pop
            UIView.animate(withDuration: 0.15) {
                self.backgroundView.alpha = 0
            } completion: { _ in
                self.navigationController?.popViewController(animated: false)
            }
        } else {
            // iOS 16~25: 기존 커스텀 애니메이션 후 pop
            UIView.animate(withDuration: 0.25, animations: {
                self.backgroundView.alpha = 0
                self.pageViewController.view.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            }, completion: { _ in
                self.navigationController?.popViewController(animated: false)
            })
        }
    }

    /// 페이드 아웃으로 닫기 (Push → Pop)
    private func dismissWithFadeOut() {
        guard !isDismissing else { return }
        isDismissing = true

        if disableCustomFadeAnimation {
            // iOS 18+: preferredTransition이 줌 아웃 처리
            navigationController?.popViewController(animated: true)
        } else {
            // iOS 16~17: 기존 페이드 아웃 후 pop
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]) {
                self.view.alpha = 0
            } completion: { _ in
                self.navigationController?.popViewController(animated: false)
            }
        }
    }

    // MARK: - iOS 26+ System UI Setup

    /// iOS 26+ 시스템 UI 설정 (1회만 실행)
    @available(iOS 26.0, *)
    private func setupSystemUIIfNeeded() {
        guard !didSetupSystemUI else { return }
        guard navigationController != nil else { return }

        didSetupSystemUI = true

        setupSystemNavigationBar()
        setupSystemToolbar()
    }

    /// iOS 26+ 시스템 네비게이션 바 설정
    @available(iOS 26.0, *)
    private func setupSystemNavigationBar() {
        // Push 방식이므로 leftBarButtonItem 설정 없이 시스템 백버튼 자동 사용
        // 투명 배경 (사진 위에 Liquid Glass 효과)
        navigationController?.navigationBar.isTranslucent = true

        // 눈 아이콘 버튼 생성 (유사 사진 토글용)
        let eyeItem = UIBarButtonItem(
            image: UIImage(systemName: "eye.fill"),
            primaryAction: UIAction { [weak self] _ in
                self?.navBarEyeButtonTapped()
            }
        )
        eyeItem.tintColor = .white
        navBarEyeItem = eyeItem
        // +버튼 표시 시 rightBarButtonItem으로 설정됨
    }

    /// iOS 26+ 네비게이션 바 눈 아이콘 탭 핸들러
    private func navBarEyeButtonTapped() {
        faceButtonOverlay?.toggleOverlay()
        updateNavBarEyeIcon()
    }

    /// iOS 26+ 네비게이션 바 눈 아이콘 업데이트
    private func updateNavBarEyeIcon() {
        guard #available(iOS 26.0, *) else { return }
        let iconName = faceButtonOverlay?.isCurrentlyHidden == true ? "eye.slash.fill" : "eye.fill"
        navBarEyeItem?.image = UIImage(systemName: iconName)
    }

    /// iOS 26+ 네비게이션 바 눈 아이콘 표시/숨김
    func showNavBarEyeButton(_ show: Bool) {
        guard #available(iOS 26.0, *) else { return }
        navigationItem.rightBarButtonItem = show ? navBarEyeItem : nil
    }

    /// iOS 26+ 시스템 툴바 설정
    @available(iOS 26.0, *)
    private func setupSystemToolbar() {
        navigationController?.setToolbarHidden(false, animated: false)
        navigationController?.toolbar.isTranslucent = true

        switch viewerMode {
        case .normal:
            setupNormalModeToolbar()
        case .trash:
            setupTrashModeToolbar()
        }
    }

    /// iOS 26+ 일반 모드 툴바 (삭제 버튼)
    @available(iOS 26.0, *)
    private func setupNormalModeToolbar() {
        let flexSpace = UIBarButtonItem(systemItem: .flexibleSpace)

        let deleteItem = UIBarButtonItem(
            systemItem: .trash,
            primaryAction: UIAction { [weak self] _ in
                self?.deleteButtonTapped()
            }
        )
        deleteItem.tintColor = .systemRed
        toolbarDeleteItem = deleteItem

        toolbarItems = [flexSpace, deleteItem, flexSpace]
    }

    /// iOS 26+ 휴지통 모드 툴바 (복구 + 완전삭제)
    @available(iOS 26.0, *)
    private func setupTrashModeToolbar() {
        let flexSpace = UIBarButtonItem(systemItem: .flexibleSpace)

        // 복구 버튼
        let restoreItem = UIBarButtonItem(
            title: "복구",
            primaryAction: UIAction { [weak self] _ in
                self?.restoreButtonTapped()
            }
        )
        restoreItem.tintColor = .systemGreen
        toolbarRestoreItem = restoreItem

        // 완전삭제 버튼
        let permanentDeleteItem = UIBarButtonItem(
            title: "삭제",
            primaryAction: UIAction { [weak self] _ in
                self?.permanentDeleteButtonTapped()
            }
        )
        permanentDeleteItem.tintColor = .systemRed
        toolbarPermanentDeleteItem = permanentDeleteItem

        toolbarItems = [restoreItem, flexSpace, permanentDeleteItem]
    }

    /// iOS 26+ 툴바 동적 교체 (현재 사진의 휴지통 상태에 따라)
    @available(iOS 26.0, *)
    private func updateToolbarItemsForCurrentPhoto() {
        // .normal 모드에서만 동적 교체 필요
        guard viewerMode == .normal else { return }

        // nil guard: setupSystemUIIfNeeded() 이전 호출 방지
        guard toolbarDeleteItem != nil else { return }

        let isTrashed = coordinator.isTrashed(at: currentIndex)
        let flexSpace = UIBarButtonItem(systemItem: .flexibleSpace)

        if isTrashed {
            // 휴지통 사진: 복구 버튼만 (중앙 배치)
            let restoreItem = UIBarButtonItem(
                title: "복구",
                primaryAction: UIAction { [weak self] _ in
                    self?.restoreButtonTapped()
                }
            )
            restoreItem.tintColor = .systemGreen
            toolbarItems = [flexSpace, restoreItem, flexSpace]
        } else {
            // 일반 사진: 삭제 버튼만 (중앙 배치)
            toolbarItems = [flexSpace, toolbarDeleteItem!, flexSpace]
        }
    }

    // MARK: - Toolbar State Management

    /// 현재 사진의 휴지통 상태에 따라 버튼/툴바 업데이트
    /// - 호출 시점: viewWillAppear, 스와이프 탐색 후, 삭제/복구 후
    private func updateToolbarForCurrentPhoto() {
        // .normal 모드에서만 동적 교체 필요
        guard viewerMode == .normal else { return }

        let isTrashed = coordinator.isTrashed(at: currentIndex)

        // iOS 16~25: 커스텀 버튼 토글
        if !useSystemUI {
            deleteButton.isHidden = isTrashed
            restoreButton.isHidden = !isTrashed
        }

        // iOS 26+: 시스템 툴바 교체
        if #available(iOS 26.0, *) {
            updateToolbarItemsForCurrentPhoto()
        }
    }

    /// 현재 페이지의 휴지통 테두리 즉시 업데이트
    /// - Parameter isTrashed: 휴지통 상태 여부
    private func updateCurrentPageTrashedState(isTrashed: Bool) {
        guard let currentVC = pageViewController.viewControllers?.first else { return }

        if let photoVC = currentVC as? PhotoPageViewController {
            photoVC.updateTrashedState(isTrashed: isTrashed)
        } else if let videoVC = currentVC as? VideoPageViewController {
            videoVC.updateTrashedState(isTrashed: isTrashed)
        }
    }

    /// 뷰어 닫기 (Push → Pop, iOS 버전별 경로 통일)
    private func dismissViewer() {
        if #available(iOS 26.0, *) {
            // iOS 26+: 시스템 pop
            navigationController?.popViewController(animated: true)
        } else {
            // iOS 16~25: 기존 페이드 아웃
            dismissWithFadeOut()
        }
    }

    // MARK: - Helpers

    /// 인덱스에 해당하는 페이지 뷰 컨트롤러 생성 (미디어 타입에 따라 분기)
    /// - Parameter index: 표시할 인덱스
    /// - Returns: PhotoPageViewController 또는 VideoPageViewController
    private func createPageViewController(at index: Int) -> UIViewController? {
        guard let asset = coordinator.asset(at: index) else { return nil }

        // 보관함(.normal)에서만 배경색 변경, 휴지통 탭에서는 검은색 유지
        let showTrashedBackground = (viewerMode == .normal) && coordinator.isTrashed(at: index)

        switch asset.mediaType {
        case .video:
            // 동영상: VideoPageViewController
            return VideoPageViewController(asset: asset, index: index, showTrashedBackground: showTrashedBackground)
        default:
            // 사진/기타: PhotoPageViewController
            return PhotoPageViewController(asset: asset, index: index, showTrashedBackground: showTrashedBackground)
        }
    }

    /// 뷰 컨트롤러에서 인덱스 추출 (Photo/Video 공통)
    private func index(from viewController: UIViewController) -> Int? {
        if let photoVC = viewController as? PhotoPageViewController {
            return photoVC.index
        } else if let videoVC = viewController as? VideoPageViewController {
            return videoVC.index
        }
        return nil
    }
}

// MARK: - UIPageViewControllerDataSource

extension ViewerViewController: UIPageViewControllerDataSource {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentIndex = index(from: viewController) else { return nil }
        let previousIndex = currentIndex - 1
        guard previousIndex >= 0 else { return nil }
        return createPageViewController(at: previousIndex)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentIndex = index(from: viewController) else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < coordinator.totalCount else { return nil }
        return createPageViewController(at: nextIndex)
    }
}

// MARK: - Debug: PageScroll 분석

extension ViewerViewController {

    /// 페이지 스크롤뷰에 로거 연결
    private func attachPageScrollLoggerIfNeeded() {
        guard pageScrollView == nil else { return }
        if let sv = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            pageScrollView = sv
            sv.panGestureRecognizer.addTarget(self, action: #selector(handlePageScrollPan(_:)))
            Log.debug("Viewer", "[PageScroll] attach - frame=\(sv.frame), contentSize=\(sv.contentSize)")
        }
    }

    /// 페이지 스크롤 진행률 로깅
    @objc private func handlePageScrollPan(_ gesture: UIPanGestureRecognizer) {
        guard Log.categories["Viewer"] == true, let sv = pageScrollView else { return }
        guard isTransitioning else { return }

        let now = CACurrentMediaTime()
        if now - lastPageScrollLogTime < 0.05 { return } // 50ms 쓰로틀
        lastPageScrollLogTime = now

        let w = sv.bounds.width
        let offsetX = sv.contentOffset.x
        let progress = w > 0 ? (offsetX - w) / w : 0
        Log.debug("Viewer", "[PageScroll] tid=\(transitionId) state=\(gesture.state.rawValue) offsetX=\(String(format: "%.1f", offsetX)) progress=\(String(format: "%.2f", progress))")
    }
}

// MARK: - UIPageViewControllerDelegate

extension ViewerViewController: UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        // 스크롤 로거 연결
        attachPageScrollLoggerIfNeeded()
        transitionId += 1
        isTransitioning = true

        // Phase 2: LOD1 디바운스 타이머 취소 (빠른 스와이프 시 LOD1 스킵)
        lod1DebounceTimer?.invalidate()
        lod1DebounceTimer = nil

        guard Log.categories["Viewer"] == true else { return }
        let now = CACurrentMediaTime()
        let pendingIndex = pendingViewControllers.first.flatMap { index(from: $0) }
        Log.debug("Viewer", "➡️ willTransition - tid=\(transitionId), from: \(currentIndex), to: \(pendingIndex.map(String.init) ?? "nil"), t=\(String(format: "%.3f", now))")

        // 현재/다음 페이지 스냅샷
        if let current = pageViewController.viewControllers?.first as? PhotoPageViewController {
            current.debugSnapshot(tag: "current@will", transitionId: transitionId)
        }
        if let pending = pendingViewControllers.first as? PhotoPageViewController {
            pending.debugSnapshot(tag: "pending@will", transitionId: transitionId)
            let tid = transitionId
            DispatchQueue.main.async {
                pending.debugSnapshot(tag: "pending@nextRunLoop", transitionId: tid)
            }
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        isTransitioning = false

        // 전환 완료 시에만 처리
        if Log.categories["Viewer"] == true {
            let now = CACurrentMediaTime()
            let prevIndex = previousViewControllers.first.flatMap { index(from: $0) }
            let nextIndex = pageViewController.viewControllers?.first.flatMap { index(from: $0) }
            Log.debug("Viewer", "✅ didFinishAnimating - tid=\(transitionId), completed=\(completed), prev=\(prevIndex.map(String.init) ?? "nil"), next=\(nextIndex.map(String.init) ?? "nil"), t=\(String(format: "%.3f", now))")

            // 현재 페이지 스냅샷
            if let current = pageViewController.viewControllers?.first as? PhotoPageViewController {
                current.debugSnapshot(tag: "current@finish", transitionId: transitionId)
            }
        }

        guard completed else { return }

        // 현재 표시 중인 VC에서 인덱스 추출
        guard let currentVC = pageViewController.viewControllers?.first,
              let newIndex = index(from: currentVC) else {
            return
        }

        // 인덱스 업데이트
        currentIndex = newIndex

        // 이전 페이지가 VideoPageViewController면 정지
        // (스와이프 취소 시에는 completed=false이므로 여기까지 오지 않음)
        for previousVC in previousViewControllers {
            if let videoVC = previousVC as? VideoPageViewController {
                videoVC.pause()
            }
        }

        // 현재 페이지가 VideoPageViewController면 비디오 요청 트리거
        // (인접 페이지 다운로드 방지를 위해 전환 완료 시점에 요청)
        if let videoVC = currentVC as? VideoPageViewController {
            videoVC.requestVideoIfNeeded()
        }

        // Phase 2: LOD1 디바운스 (150ms 후 원본 요청)
        scheduleLOD1Request()

        // T026: 유사 사진 오버레이 업데이트 (스와이프로 다른 사진 이동 시)
        updateSimilarPhotoOverlay()

        // 스와이프 탐색 후 버튼 상태 업데이트 (다음 사진이 휴지통일 수 있음)
        updateToolbarForCurrentPhoto()
    }

    /// LOD1 요청 스케줄링 (150ms 디바운스)
    /// - 빠른 스와이프 시 LOD1 요청 스킵
    /// - 정지 상태에서만 원본 이미지 로드
    private func scheduleLOD1Request() {
        lod1DebounceTimer?.invalidate()
        lod1DebounceTimer = Timer.scheduledTimer(withTimeInterval: Self.lod1DebounceDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // 현재 페이지가 PhotoPageViewController면 LOD1 요청
            if let photoVC = self.pageViewController.viewControllers?.first as? PhotoPageViewController {
                Log.debug("Viewer", "🔍 LOD1 디바운스 완료 - index: \(photoVC.index)")
                photoVC.requestHighQualityImage()
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ViewerViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 스와이프 삭제와 다른 제스처가 동시에 인식되지 않도록
        if let swipeHandler = swipeDeleteHandler,
           gestureRecognizer == swipeHandler.panGesture || otherGestureRecognizer == swipeHandler.panGesture {
            return false
        }

        // 아래 스와이프 닫기와 다른 제스처가 동시에 인식되지 않도록
        // (UIPageViewController의 좌우 스와이프와 충돌 방지)
        if gestureRecognizer == dismissPanGesture || otherGestureRecognizer == dismissPanGesture {
            return false
        }

        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == dismissPanGesture else { return true }

        // 아래 방향 스와이프만 허용
        let velocity = dismissPanGesture.velocity(in: view)
        return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
    }
}

// MARK: - BarsVisibilityControlling

extension ViewerViewController: BarsVisibilityControlling {
    /// Viewer에서는 floatingOverlay 숨김 (전체화면 뷰어이므로)
    var prefersFloatingOverlayHidden: Bool? { true }

    /// iOS 26: 시스템 툴바 표시 (삭제/복구 버튼)
    /// iOS 16~25: 기본 정책 (커스텀 버튼 사용하므로 시스템 툴바 불필요)
    var prefersToolbarHidden: Bool? {
        if #available(iOS 26.0, *) {
            return false  // iOS 26: 툴바 표시
        }
        return nil  // iOS 16~25: 기본 정책 (숨김)
    }
}

// MARK: - ZoomTransitionDestinationProviding (커스텀 줌 트랜지션)

extension ViewerViewController: ZoomTransitionDestinationProviding {

    /// 줌 애니메이션 대상 뷰 (현재 페이지의 이미지 뷰)
    var zoomDestinationView: UIView? {
        currentPageImageView
    }

    /// 줌 애니메이션 목적지 프레임 (window 좌표계)
    var zoomDestinationFrame: CGRect? {
        guard let imageView = currentPageImageView else { return nil }
        // window 좌표계로 변환 (to: nil)
        return imageView.superview?.convert(imageView.frame, to: nil)
    }

    /// 현재 페이지의 이미지 뷰 (Photo/Video 공통)
    private var currentPageImageView: UIView? {
        guard let currentVC = pageViewController.viewControllers?.first else { return nil }

        // PhotoPageViewController
        if let photoPage = currentVC as? PhotoPageViewController {
            return photoPage.zoomableImageView
        }

        // VideoPageViewController (포스터 이미지 사용)
        if let videoPage = currentVC as? VideoPageViewController {
            return videoPage.zoomableImageView
        }

        return nil
    }
}
