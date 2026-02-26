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
// T035: 삭제대기함 사진 뷰어 모드 구현
// - 삭제 버튼 대신 "복구/완전삭제" 옵션 표시

import UIKit
import Photos
import AppCore
import OSLog
import Vision

/// 뷰어 모드
/// 모드에 따라 하단 버튼이 다르게 표시됨
enum ViewerMode {
    /// 일반 모드: 삭제 버튼 표시
    case normal

    /// 삭제대기함 모드: 복구/완전삭제 버튼 표시
    case trash

    /// 정리 미리보기 모드: 제외 버튼 표시 (스와이프 삭제 없음)
    case cleanup
}

/// 뷰어 델리게이트
/// 삭제/복구/완전삭제/제외 액션을 처리
protocol ViewerViewControllerDelegate: AnyObject {
    /// 사진 삭제 요청 (앱 내 삭제대기함으로 이동)
    /// - Parameter assetID: 삭제할 사진 ID
    func viewerDidRequestDelete(assetID: String)

    /// 사진 복구 요청 (삭제대기함에서 복원)
    /// - Parameter assetID: 복구할 사진 ID
    func viewerDidRequestRestore(assetID: String)

    /// 사진 완전삭제 요청 (iOS 삭제대기함으로 이동)
    /// - Parameter assetID: 완전삭제할 사진 ID
    func viewerDidRequestPermanentDelete(assetID: String)

    /// 뷰어가 닫힐 때 호출
    /// - Parameter currentAssetID: 마지막으로 표시한 사진 ID
    func viewerWillClose(currentAssetID: String?)

    /// 정리 미리보기에서 사진 제외 요청
    /// - Parameter assetID: 제외할 사진 ID
    func viewerDidRequestExclude(assetID: String)

    /// 뷰어가 완전히 닫힌 후 호출 (dismiss/pop 애니메이션 완료 후)
    /// iOS 16~25 Modal (shouldRemovePresentersView=false) 경로에서
    /// presenting VC의 viewWillAppear/viewDidAppear가 호출되지 않는 문제를 보완
    func viewerDidClose()
}

/// ViewerViewControllerDelegate 기본 구현
/// 기존 Grid/Album/Trash 3곳에서 viewerDidRequestExclude를 구현하지 않아도 컴파일 안전
extension ViewerViewControllerDelegate {
    func viewerDidRequestExclude(assetID: String) {}
    func viewerDidClose() {}
}

/// 전체 화면 사진 뷰어
/// UIPageViewController 기반으로 좌우 스와이프 탐색 지원
final class ViewerViewController: UIViewController {

    // MARK: - Constants

    /// 버튼 center에서 safeArea bottom까지의 거리
    /// FloatingTabBar의 capsuleHeight/2와 동일 (56/2 = 28)
    private static let buttonCenterFromBottom: CGFloat = 28

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: ViewerViewControllerDelegate?

    /// 현재 모드 (일반/삭제대기함)
    /// Extension에서 접근 가능하도록 internal 접근 레벨
    let viewerMode: ViewerMode

    /// Coordinator (네비게이션 및 데이터 관리)
    /// Extension에서 접근 가능하도록 internal 접근 레벨
    let coordinator: ViewerCoordinatorProtocol

    /// 스와이프 삭제 핸들러
    private var swipeDeleteHandler: SwipeDeleteHandler?

    /// 현재 뷰어의 ScreenSource (analytics용)
    /// - .cleanup 모드는 카운트 제외 → nil 반환
    private var analyticsScreenSource: ScreenSource? {
        switch viewerMode {
        case .trash:   return .trash
        case .normal:
            switch coordinator.deleteSource {
            case .library: return .library
            case .album:   return .album
            case nil:      return .library  // 기본값 (안전 장치)
            }
        case .cleanup: return nil
        }
    }

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

    // MARK: - Debug: 성능 분석용

    #if DEBUG
    /// HitchMonitor (페이지 스와이프 성능 측정)
    private let hitchMonitor = HitchMonitor()

    /// 스와이프 시작 시간
    private var swipeStartTime: CFTimeInterval = 0

    /// 스와이프 카운터 (L1/L2 구분)
    private var swipeCount: Int = 0
    #endif

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
        // 아이콘을 기본 medium(22pt)의 80%인 17.6pt로 축소
        let button = GlassIconButton(icon: "trash", size: .medium, tintColor: .systemRed, iconPointSize: 17.6)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "viewer_delete"
        return button
    }()

    /// 복구 버튼 (삭제대기함 모드 - Liquid Glass 텍스트 버튼)
    /// iOS 26 스펙: 텍스트 "복구", tintColor #30D158 (녹색)
    private lazy var restoreButton: GlassTextButton = {
        let button = GlassTextButton(title: "복구", style: .plain, tintColor: .systemGreen)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(restoreButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "viewer_restore"
        return button
    }()

    /// 완전삭제 버튼 (삭제대기함 모드 - Liquid Glass 텍스트 버튼)
    /// iOS 26 스펙: 텍스트 "삭제", tintColor #FF4245 (빨간색)
    private lazy var permanentDeleteButton: GlassTextButton = {
        let button = GlassTextButton(title: "삭제", style: .plain, tintColor: .systemRed)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(permanentDeleteButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "viewer_permanent_delete"
        return button
    }()

    /// 제외 버튼 (정리 미리보기 모드 - Liquid Glass 텍스트 버튼)
    /// 정리 후보에서 개별 사진을 제외하는 버튼
    private lazy var excludeButton: GlassTextButton = {
        let button = GlassTextButton(title: "제외", style: .plain, tintColor: .white)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(excludeButtonTapped), for: .touchUpInside)
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

    /// 뷰어 닫힘 확정 플래그 (viewWillDisappear에서 설정, viewDidDisappear에서 사용)
    /// Apple SDK 권장: isBeingDismissed/isMovingFromParent 판별은 viewWillDisappear에서 수행
    private var isClosing = false

    /// Interactive dismiss 중 활성 IC 참조
    /// ⚠️ popViewController 후 navigationController가 nil이 되어
    ///   isPushed/tabBarController 경로로 IC에 접근 불가능하므로 직접 저장
    private weak var activeInteractionController: ZoomDismissalInteractionController?

    /// Interactive dismiss 중 활성 TabBarController 참조 (cleanup용)
    private weak var activeTabBarController: TabBarController?

    /// 최초 표시 페이드 인 적용 여부 (시스템 전환 대신 사용)
    private var didPerformInitialFadeIn: Bool = false


    /// Navigation Push로 열렸는지 여부 (iOS 26+)
    /// Push: navigationController != nil, presentingViewController == nil
    /// Modal: presentingViewController != nil
    private var isPushed: Bool {
        return navigationController != nil && presentingViewController == nil
    }

    /// 줌 트랜지션 컨트롤러 (그리드에서 설정, Modal 방식에서만 사용)
    /// ⚠️ strong 참조: transitioningDelegate가 weak이므로 여기서 유지
    var zoomTransitionController: ZoomTransitionController?

    /// [Timing] 그리드에서 탭한 시점 (CACurrentMediaTime 기준)
    /// GridViewController.didSelectItemAt에서 설정
    var openStartTime: CFTimeInterval = 0

    // MARK: - iOS 26+ System UI Properties

    /// iOS 26+ 시스템 UI 사용 여부
    /// Modal에서는 navigationController가 nil이므로 항상 커스텀 버튼 사용
    private var useSystemUI: Bool {
        if #available(iOS 26.0, *) {
            return navigationController != nil
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

    // MARK: - 상단 그라데이션 + 타이틀 (유사사진 안내)

    /// 상단 그라데이션 딤드 뷰 (iOS 16~25 + iOS 26 Modal, .normal 모드 전용)
    /// 눈 버튼 토글과 무관하게 항상 표시
    private var topGradientView: UIView?

    /// 상단 그라데이션 레이어 (layoutSubviews에서 frame 갱신 필요)
    private var topGradientLayer: CAGradientLayer?

    /// "유사사진정리 가능" 타이틀 라벨
    /// 눈 버튼 토글 시 숨김/표시
    var similarPhotoTitleLabel: UILabel?

    /// iOS 16~25 커스텀 뒤로가기 버튼 참조 (코치마크 z-order용)
    private weak var backButtonView: UIView?

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

        // Modal 커스텀 전환 설정
        modalPresentationStyle = .custom
        modalPresentationCapturesStatusBarAppearance = true

        // iOS 26+ Navigation Push 시 탭바 숨김
        hidesBottomBarWhenPushed = true
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
        setupSimilarPhotoFeature()

        // [LiquidGlass 최적화] 페이지 스크롤뷰 델리게이트 설정
        setupPageScrollViewDelegate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Modal에서는 NavigationControllerDelegate.willShow가 호출 안 됨
        // → FloatingOverlay를 수동으로 숨김
        findTabBarController()?.floatingOverlay?.isHidden = true

        // iOS 26+: navigationController 존재 확인 후 시스템 UI 설정
        if #available(iOS 26.0, *) {
            setupSystemUIIfNeeded()
        }

        // 초기 버튼 상태 설정 (현재 사진의 삭제대기함 상태에 따라)
        // iOS 26에서는 setupSystemUIIfNeeded() 이후에 호출해야 함
        updateToolbarForCurrentPhoto()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if openStartTime > 0 {
            openStartTime = 0

            // [Analytics] 이벤트 3: 최초 진입 시 사진 열람 카운트
            if let source = analyticsScreenSource {
                AnalyticsService.shared.countPhotoViewed(from: source)
            }
        }

        if isBeingPresented && !didPerformInitialFadeIn {
            didPerformInitialFadeIn = true
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.view.alpha = 1
            }
        }

        // T026: 유사 사진 오버레이 표시
        showSimilarPhotoOverlay()

        // [LiquidGlass 최적화] 블러 뷰 사전 생성 + idle pause
        LiquidGlassOptimizer.preload(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)

        // 코치마크 B: 뷰어 스와이프 삭제 안내
        showViewerSwipeDeleteCoachMarkIfNeeded()

        // 코치마크 C-2: + 버튼 하이라이트 (C-1에서 자동 네비게이션 후)
        triggerCoachMarkC2IfNeeded()
    }

    // MARK: - Rotation

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in
            // 회전 중: FaceButtonOverlay + 타이틀 즉시 숨김 (위치 오류 방지)
            self?.faceButtonOverlay?.hideButtonsImmediately()
            self?.similarPhotoTitleLabel?.alpha = 0
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

        // 코치마크 dismiss — guard 앞에 배치 (모달 등 모든 disappear에서 동작)
        CoachMarkManager.shared.dismissCurrent()

        // dismiss/pop 시에만 FloatingOverlay 복원 (interactive 취소 시 중복 방지)
        // Modal: isBeingDismissed, Navigation Pop: isMovingFromParent
        guard isBeingDismissed || isMovingFromParent else { return }

        // 닫힘 확정 플래그 설정 (viewDidDisappear에서 viewerDidClose 호출에 사용)
        isClosing = true

        // Modal에서는 수동으로 FloatingOverlay 복원
        findTabBarController()?.floatingOverlay?.isHidden = false

        // 현재 표시 중인 사진 ID 전달
        let currentAssetID = coordinator.assetID(at: currentIndex)
        delegate?.viewerWillClose(currentAssetID: currentAssetID)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // viewWillDisappear에서 설정한 플래그로 판별
        // (Apple SDK 권장: isBeingDismissed/isMovingFromParent는 viewWillDisappear에서 체크)
        guard isClosing else { return }
        isClosing = false

        // dismiss/pop 애니메이션 완료 후 delegate에 알림
        // iOS 16~25 Modal (shouldRemovePresentersView=false) 경로에서
        // presenting VC의 viewWillAppear/viewDidAppear가 호출되지 않으므로
        // 이 콜백으로 applyPendingViewerReturn() 트리거
        delegate?.viewerDidClose()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 그라데이션 레이어 frame 갱신 (Auto Layout 적용 후)
        topGradientLayer?.frame = topGradientView?.bounds ?? .zero
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

        // 상단 그라데이션 + 타이틀 (normal 모드)
        // iOS 16~25: 딤드 + 타이틀, iOS 26: titleView로 타이틀만
        // pageVC 위, 버튼/오버레이 아래에 삽입
        if viewerMode == .normal {
            if !useSystemUI {
                setupTopGradientAndTitle()  // 딤드 + 타이틀
            } else {
                setupSimilarPhotoTitleLabel()  // iOS 26: navigationItem.titleView
            }
        }

        // iOS 16~25: 커스텀 버튼 추가
        // iOS 26+: viewWillAppear에서 시스템 UI 설정 (navigationController 필요)
        if !useSystemUI {
            setupActionButtons()
            setupBackButton()
        }

    }


    /// 상단 그라데이션 딤드 + "유사사진정리 가능" 타이틀 설정
    /// .normal 모드 && !useSystemUI 조건에서만 호출
    /// z-order: pageVC 위, backButton/faceButtonOverlay 아래
    private func setupTopGradientAndTitle() {
        // --- 그라데이션 딤드 뷰 ---
        let gradientContainer = UIView()
        gradientContainer.translatesAutoresizingMaskIntoConstraints = false
        gradientContainer.isUserInteractionEnabled = false
        view.addSubview(gradientContainer)

        // 그라데이션 레이어: 뷰어 전용 (0.90)
        let gradientLayer = CAGradientLayer()
        let dimAlpha: CGFloat = 0.90
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(dimAlpha).cgColor,
            UIColor.black.withAlphaComponent(dimAlpha * 0.7).cgColor,
            UIColor.black.withAlphaComponent(dimAlpha * 0.3).cgColor,
            UIColor.black.withAlphaComponent(dimAlpha * 0.1).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0, 0.25, 0.5, 0.75, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientContainer.layer.addSublayer(gradientLayer)

        // 그라데이션 영역: view.top ~ safeArea top + 90pt
        NSLayoutConstraint.activate([
            gradientContainer.topAnchor.constraint(equalTo: view.topAnchor),
            gradientContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 90)
        ])

        topGradientView = gradientContainer
        topGradientLayer = gradientLayer

        // 딤드 위에 타이틀 라벨 추가
        setupSimilarPhotoTitleLabel()
    }

    /// "유사사진정리 가능" 커스텀 타이틀 라벨 설정
    /// iOS 16~25: setupTopGradientAndTitle()에서 딤드와 함께 호출 → view.addSubview
    /// iOS 26: navigationItem.titleView에 설정 → 네비바 버튼과 자동 수평 정렬
    private func setupSimilarPhotoTitleLabel() {
        let titleLabel = UILabel()
        // "유사사진정리"(레귤러/흰색) + " 가능"(볼드/밝은 노란색)
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(
            string: "유사사진정리 ",
            attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .regular), .foregroundColor: UIColor.white]
        ))
        attr.append(NSAttributedString(
            string: "가능",
            attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .heavy), .foregroundColor: UIColor(red: 1.0, green: 234.0/255.0, blue: 0, alpha: 1.0)]
        ))
        titleLabel.attributedText = attr
        titleLabel.textAlignment = .center

        if useSystemUI {
            // iOS 26: navigationItem.titleView → 네비바 내부에서 버튼과 자동 정렬
            titleLabel.sizeToFit()
            titleLabel.alpha = 0
            navigationItem.titleView = titleLabel
        } else {
            // iOS 16~25: view에 직접 추가 + Auto Layout
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.isUserInteractionEnabled = false
            view.addSubview(titleLabel)

            // centerY = safeArea + 29 (backButton centerY와 수평 정렬)
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 29)
            ])

            titleLabel.alpha = 0
        }

        similarPhotoTitleLabel = titleLabel
    }

    /// iOS 16~25 전용 뒤로가기 버튼 설정
    /// Push 전환 방식이지만 네비바는 숨긴 상태로 유지하고 커스텀 버튼 사용
    /// iOS 26 스펙: 44×44, iconSize 22pt (GlassIconButton과 동일)
    private func setupBackButton() {
        // GlassIconButton 사용 (iOS 26 NavBar 아이콘 버튼과 동일 스펙)
        let backButton = GlassIconButton(icon: "chevron.backward", size: .medium, tintColor: .white)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.accessibilityIdentifier = "viewer_back"

        view.addSubview(backButton)
        backButtonView = backButton
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 7),
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

            // 복구 버튼 (중앙 - 삭제 버튼과 같은 위치, 삭제대기함 사진일 때 표시)
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

        case .cleanup:
            // 제외 버튼 (중앙 — deleteButton과 동일 위치)
            view.addSubview(excludeButton)
            NSLayoutConstraint.activate([
                excludeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                excludeButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
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
            // transform 대상을 pageViewController.view로 지정 (사진만 이동, UI 버튼 제자리)
            handler.transformTarget = pageViewController.view
            // 이미 삭제대기함인 사진이면 삭제 불가 → 바운스백
            handler.canDelete = { [weak self] in
                guard let self else { return false }
                return !self.coordinator.isTrashed(at: self.currentIndex)
            }
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

    // MARK: - Coach Mark Helpers

    /// 코치마크 B 표시 후 뒤로가기/삭제 버튼을 오버레이 위에 보이게 하되 터치 차단
    /// bringToFront + isUserInteractionEnabled = false → 보이지만 터치 불가
    /// iOS 26+: 시스템 네비바/툴바는 view 밖이므로 자연스럽게 보임
    func showControlButtonsAboveCoachMark() {
        // 오버레이 위로 올리기
        if let back = backButtonView {
            view.bringSubviewToFront(back)
            back.isUserInteractionEnabled = false
        }
        if deleteButton.superview == view {
            view.bringSubviewToFront(deleteButton)
            deleteButton.isUserInteractionEnabled = false
        }
        if restoreButton.superview == view {
            view.bringSubviewToFront(restoreButton)
            restoreButton.isUserInteractionEnabled = false
        }

        // 코치마크 dismiss 시 터치 복원
        CoachMarkManager.shared.currentOverlay?.onDismiss = { [weak self] in
            self?.backButtonView?.isUserInteractionEnabled = true
            self?.deleteButton.isUserInteractionEnabled = true
            self?.restoreButton.isUserInteractionEnabled = true
        }
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

        // [Analytics] 이벤트 4-1: 뷰어 삭제 버튼
        AnalyticsService.shared.countViewerTrashButton(source: coordinator.deleteSource)

        // 삭제 요청
        delegate?.viewerDidRequestDelete(assetID: assetID)

        // 다음 사진으로 이동 (이전 사진 우선 규칙)
        moveToNextAfterDelete()

        // 이동 후 버튼 상태 업데이트 (다음 사진이 삭제대기함일 수 있음)
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

        // [Analytics] 이벤트 4-1: 뷰어 복구 버튼
        AnalyticsService.shared.countViewerRestoreButton(source: coordinator.deleteSource)

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

    /// 완전삭제 버튼 탭 (삭제대기함 모드)
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

    // MARK: - Exclude (Cleanup Mode)

    /// 제외 버튼 탭 (정리 미리보기 모드)
    /// 실행 순서: removeAsset → moveToNextAfterDelete (인덱스 정합성 필수)
    @objc private func excludeButtonTapped() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // 1. delegate에 제외 알림 (PreviewGridVC가 excludedAssetIDs에 기록)
        delegate?.viewerDidRequestExclude(assetID: assetID)

        // 2. 코디네이터에서 에셋 제거 (removeAsset 후 assets.count가 줄어듬)
        //    moveToNextAfterDelete()가 nextIndexAfterDelete()로 삭제 후 count 기준 계산하므로
        //    반드시 제거가 먼저 완료되어야 함
        (coordinator as? PreviewViewerCoordinator)?.removeAsset(id: assetID)

        // 3. 다음 사진으로 이동 (기존 메서드 재사용 — 모든 사진 제외 시 자동 닫힘)
        moveToNextAfterDelete()
    }

    // MARK: - Swipe Delete

    /// 위 스와이프 삭제 처리 (T030)
    private func handleSwipeDelete() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // [Analytics] 이벤트 4-1: 뷰어 스와이프 삭제
        AnalyticsService.shared.countViewerSwipeDelete(source: coordinator.deleteSource)

        // 삭제 요청
        delegate?.viewerDidRequestDelete(assetID: assetID)

        // 다음 사진으로 이동
        moveToNextAfterDelete()

        // 이동 후 버튼 상태 업데이트 (다음 사진이 삭제대기함일 수 있음)
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

    /// 아래 스와이프로 닫기 처리 (Interactive Dismiss)
    /// iOS 26+ (isPushed): Navigation Pop 경로
    /// iOS 16~25: Modal Dismiss 경로 (기존)
    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            guard !isDismissing else { return }
            isDismissing = true

            // [LiquidGlass 최적화] dismiss 드래그 시작 → MTKView pause
            LiquidGlassOptimizer.cancelIdleTimer()
            LiquidGlassOptimizer.optimize(in: view.window)

            if isPushed {
                // === iOS 26+ Navigation Pop 경로 ===
                guard let tbc = tabBarController as? TabBarController else {
                    navigationController?.popViewController(animated: true)
                    return
                }
                let ic = ZoomDismissalInteractionController()
                ic.sourceProvider = tbc.zoomSourceProvider
                ic.destinationProvider = tbc.zoomDestinationProvider
                ic.transitionMode = .navigation
                ic.onTransitionFinished = { [weak self, weak tbc] completed in
                    // IC 참조 정리
                    self?.activeInteractionController = nil
                    self?.activeTabBarController = nil
                    if !completed {
                        self?.isDismissing = false
                        tbc?.zoomInteractionController = nil  // retain cycle 방지
                        LiquidGlassOptimizer.restore(in: self?.view.window)
                        LiquidGlassOptimizer.enterIdle(in: self?.view.window)
                    }
                    // 완료 시: didShow → cleanupZoomTransition() 자동 호출
                }
                tbc.zoomInteractionController = ic
                tbc.isInteractivelyPopping = true

                // ⚠️ popViewController 후 navigationController가 nil이 되어
                //   isPushed/tabBarController 접근 불가 → IC/TBC 참조를 미리 저장
                self.activeInteractionController = ic
                self.activeTabBarController = tbc

                navigationController?.popViewController(animated: true)
            } else {
                // === iOS 16~25 Modal Dismiss 경로 (기존 코드) ===
                guard let tc = zoomTransitionController else {
                    dismissWithFadeOut()
                    return
                }
                let ic = ZoomDismissalInteractionController()
                ic.sourceProvider = tc.sourceProvider
                ic.destinationProvider = tc.destinationProvider
                ic.onTransitionFinished = { [weak self] completed in
                    // IC 참조 정리
                    self?.activeInteractionController = nil
                    if !completed {
                        self?.isDismissing = false
                        LiquidGlassOptimizer.restore(in: self?.view.window)
                        LiquidGlassOptimizer.enterIdle(in: self?.view.window)
                    }
                }
                tc.interactionController = ic
                tc.isInteractivelyDismissing = true

                // Modal 경로도 동일하게 IC 참조 저장 (일관성)
                self.activeInteractionController = ic

                dismiss(animated: true)
            }

        case .changed:
            // ⚠️ isPushed/tabBarController 대신 저장된 IC 참조 사용
            //   popViewController 후 navigationController가 nil이 되어 isPushed가 false 반환하므로
            activeInteractionController?.didPanWith(gestureRecognizer: gesture)

        case .ended, .cancelled:
            // ⚠️ 저장된 IC 참조로 제스처 전달
            activeInteractionController?.didPanWith(gestureRecognizer: gesture)
            // TabBarController의 isInteractivelyPopping 정리
            activeTabBarController?.isInteractivelyPopping = false
            // Modal 경로: isInteractivelyDismissing 정리
            zoomTransitionController?.isInteractivelyDismissing = false

        default:
            break
        }
    }

    /// 애니메이션과 함께 닫기 (Modal dismiss 또는 Navigation pop)
    private func dismissWithAnimation() {
        guard !isDismissing else { return }
        isDismissing = true

        if isPushed {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    /// 페이드 아웃으로 닫기 (Modal dismiss 또는 Navigation pop)
    private func dismissWithFadeOut() {
        guard !isDismissing else { return }
        isDismissing = true

        if isPushed {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
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
        // +버튼 표시 시 rightBarButtonItem + title 설정됨 (showNavBarEyeButton에서)
    }

    /// iOS 26+ 네비게이션 바 눈 아이콘 탭 핸들러
    /// 타이틀 토글은 toggleOverlay → 델리게이트 didToggleVisibility에서 처리
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

    /// 눈 아이콘 + 커스텀 타이틀 표시/숨김
    /// +버튼이 표시/숨겨질 때 호출되어 타이틀도 함께 연동
    func showNavBarEyeButton(_ show: Bool) {
        // iOS 26: 네비바 눈 아이콘 (타이틀은 커스텀 라벨로 통일)
        if #available(iOS 26.0, *) {
            navigationItem.rightBarButtonItem = show ? navBarEyeItem : nil
        }

        // 커스텀 타이틀 라벨 (iOS 16~25 + iOS 26 공통)
        UIView.animate(withDuration: 0.2) {
            self.similarPhotoTitleLabel?.alpha = show ? 1 : 0
        }
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
        case .cleanup:
            setupCleanupModeToolbar()
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

    /// iOS 26+ 삭제대기함 모드 툴바 (복구 + 완전삭제)
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

    /// iOS 26+ 정리 미리보기 모드 툴바 (제외 버튼)
    @available(iOS 26.0, *)
    private func setupCleanupModeToolbar() {
        let flexSpace = UIBarButtonItem(systemItem: .flexibleSpace)

        let excludeItem = UIBarButtonItem(
            title: "제외",
            primaryAction: UIAction { [weak self] _ in
                self?.excludeButtonTapped()
            }
        )
        excludeItem.tintColor = .white

        toolbarItems = [flexSpace, excludeItem, flexSpace]
    }

    /// iOS 26+ 툴바 동적 교체 (현재 사진의 삭제대기함 상태에 따라)
    @available(iOS 26.0, *)
    private func updateToolbarItemsForCurrentPhoto() {
        // .normal 모드에서만 동적 교체 필요
        guard viewerMode == .normal else { return }

        // nil guard: setupSystemUIIfNeeded() 이전 호출 방지
        guard toolbarDeleteItem != nil else { return }

        let isTrashed = coordinator.isTrashed(at: currentIndex)
        let flexSpace = UIBarButtonItem(systemItem: .flexibleSpace)

        if isTrashed {
            // 삭제대기함 사진: 복구 버튼만 (중앙 배치)
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

    /// 현재 사진의 삭제대기함 상태에 따라 버튼/툴바 업데이트
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

    /// 현재 페이지의 삭제대기함 테두리 즉시 업데이트
    /// - Parameter isTrashed: 삭제대기함 상태 여부
    private func updateCurrentPageTrashedState(isTrashed: Bool) {
        guard let currentVC = pageViewController.viewControllers?.first else { return }

        if let photoVC = currentVC as? PhotoPageViewController {
            photoVC.updateTrashedState(isTrashed: isTrashed)
        } else if let videoVC = currentVC as? VideoPageViewController {
            videoVC.updateTrashedState(isTrashed: isTrashed)
        }
    }

    /// 뷰어 닫기 (Modal dismiss)
    private func dismissViewer() {
        dismissWithFadeOut()
    }

    // MARK: - Snapshot (Coach Mark B)

    /// 사진 이미지뷰 스냅샷 + 프레임 (코치마크용)
    /// 검은 여백 없이 사진 영역만 캡처 (pageViewController가 private이므로 우회)
    /// - Returns: (스냅샷 뷰, 윈도우 좌표 프레임) 또는 nil
    func capturePhotoSnapshot() -> (snapshot: UIView, frame: CGRect)? {
        guard let imageView = currentPageImageView,
              let snapshot = imageView.snapshotView(afterScreenUpdates: false),
              let window = view.window else { return nil }
        let frameInWindow = imageView.convert(imageView.bounds, to: window)
        return (snapshot, frameInWindow)
    }

    // MARK: - Helpers

    /// 인덱스에 해당하는 페이지 뷰 컨트롤러 생성 (미디어 타입에 따라 분기)
    /// - Parameter index: 표시할 인덱스
    /// - Returns: PhotoPageViewController 또는 VideoPageViewController
    private func createPageViewController(at index: Int) -> UIViewController? {
        guard let asset = coordinator.asset(at: index) else { return nil }

        // 보관함(.normal)에서만 배경색 변경, 삭제대기함 탭에서는 검은색 유지
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

// MARK: - Helpers (TabBarController 접근)

extension ViewerViewController {

    /// Modal에서 presenting VC 체인을 통해 TabBarController 찾기
    /// self.tabBarController는 Modal에서 nil이므로 presentingViewController 체인 탐색
    func findTabBarController() -> TabBarController? {
        // 1. 직접 접근 (Navigation에 속한 경우)
        if let tbc = tabBarController as? TabBarController { return tbc }
        // 2. presenting VC 체인 탐색 (Modal인 경우)
        var vc = presentingViewController
        while let current = vc {
            if let tbc = current as? TabBarController { return tbc }
            if let nav = current as? UINavigationController,
               let tbc = nav.tabBarController as? TabBarController { return tbc }
            vc = current.presentingViewController
        }
        return nil
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
        }
    }

    /// 페이지 스크롤 진행률 로깅
    @objc private func handlePageScrollPan(_ gesture: UIPanGestureRecognizer) {
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

        // [Debug] 성능 측정 시작 (optimize는 scrollViewWillBeginDragging에서 호출)
        #if DEBUG
        swipeStartTime = CACurrentMediaTime()
        hitchMonitor.start()
        #endif

    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        isTransitioning = false

        // [Debug] 성능 측정 종료 (restore는 scrollViewDidEndDecelerating에서 호출)
        #if DEBUG
        let hitchResult = hitchMonitor.stop()

        // 스와이프 카운터 증가 (completed 여부 관계없이 측정)
        swipeCount += 1
        let swipeType = swipeCount == 1 ? "L1 First" : "L2 Steady"
        let swipeDuration = (CACurrentMediaTime() - swipeStartTime) * 1000

        // 성능 로그 출력
        Logger.viewer.debug("Hitch \(swipeType): \(hitchResult.formatted())")
        Logger.viewer.debug("Hitch:Abs totalHitchMs=\(String(format: "%.1f", hitchResult.totalHitchTimeMs)), duration=\(String(format: "%.3f", hitchResult.durationSeconds))s")
        Logger.viewer.debug("Swipe completed=\(completed), duration=\(String(format: "%.1f", swipeDuration))ms")
        #endif

        guard completed else { return }

        // 현재 표시 중인 VC에서 인덱스 추출
        guard let currentVC = pageViewController.viewControllers?.first,
              let newIndex = index(from: currentVC) else {
            return
        }

        // 인덱스 업데이트
        currentIndex = newIndex

        // [Analytics] 이벤트 3: 페이지 전환 시 사진 열람 카운트
        if let source = analyticsScreenSource {
            AnalyticsService.shared.countPhotoViewed(from: source)
        }

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

        // 스와이프 탐색 후 버튼 상태 업데이트 (다음 사진이 삭제대기함일 수 있음)
        updateToolbarForCurrentPhoto()

        // 코치마크 B: 동영상 → 이미지 스와이프 시 트리거
        showViewerSwipeDeleteCoachMarkIfNeeded()
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
        guard velocity.y > 0 && abs(velocity.y) > abs(velocity.x) else { return false }

        // 줌 상태 체크: 확대 중이면 dismiss 안 함 (스크롤 동작으로 처리)
        guard let zoomable = pageViewController.viewControllers?.first as? ZoomableImageProviding else {
            return true
        }
        guard zoomable.zoomScale <= 1.01 else { return false }
        return zoomable.isAtTopEdge
    }
}

// MARK: - BarsVisibilityControlling

extension ViewerViewController: BarsVisibilityControlling {
    /// Viewer에서는 floatingOverlay 숨김 (전체화면 뷰어이므로)
    var prefersFloatingOverlayHidden: Bool? { true }

    /// 모든 뷰어 모드에서 탭바 숨김
    /// iOS 26에서 기본값이 "표시"이므로 명시적으로 숨겨야 함
    var prefersSystemTabBarHidden: Bool? { true }

    /// iOS 26: 시스템 툴바 표시 (삭제/복구/제외 버튼)
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

    /// 현재 표시 중인 원본 인덱스 (ZoomTransitionSourceProviding에서 셀 찾기용)
    /// - Note: ViewerViewController.currentIndex는 filteredIndex이므로
    ///         coordinator를 통해 originalIndex로 변환
    var currentOriginalIndex: Int {
        coordinator.originalIndex(from: currentIndex) ?? currentIndex
    }

    /// 줌 애니메이션 대상 뷰 (현재 페이지의 이미지 뷰)
    var zoomDestinationView: UIView? {
        currentPageImageView
    }

    /// 줌 애니메이션 목적지 프레임 (window 좌표계)
    /// - Note: imageView.frame 대신 asset 비율로 계산하여 레이아웃 완료 전에도 정확한 프레임 반환
    var zoomDestinationFrame: CGRect? {
        // 현재 asset의 크기로 aspect fit 프레임 계산
        guard let asset = coordinator.asset(at: currentIndex) else { return nil }

        let assetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        let containerSize = view.bounds.size

        // aspect fit 계산
        let aspectFitFrame = calculateAspectFitFrame(
            assetSize: assetSize,
            containerSize: containerSize
        )

        // window 좌표계로 변환
        return view.convert(aspectFitFrame, to: nil)
    }

    /// aspect fit 프레임 계산
    /// - Parameters:
    ///   - assetSize: 미디어 원본 크기
    ///   - containerSize: 컨테이너 크기
    /// - Returns: 컨테이너 중앙에 aspect fit으로 배치된 프레임
    private func calculateAspectFitFrame(assetSize: CGSize, containerSize: CGSize) -> CGRect {
        guard assetSize.width > 0 && assetSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let widthRatio = containerSize.width / assetSize.width
        let heightRatio = containerSize.height / assetSize.height
        let ratio = min(widthRatio, heightRatio)

        let fitWidth = assetSize.width * ratio
        let fitHeight = assetSize.height * ratio

        let x = (containerSize.width - fitWidth) / 2
        let y = (containerSize.height - fitHeight) / 2

        return CGRect(x: x, y: y, width: fitWidth, height: fitHeight)
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

// MARK: - LiquidGlass 최적화 (UIScrollViewDelegate)

extension ViewerViewController: UIScrollViewDelegate {

    /// UIPageViewController 내부 스크롤뷰의 delegate 설정
    /// - Note: 더 빠른 시점(터치 직후)에 LiquidGlass 최적화 적용
    func setupPageScrollViewDelegate() {
        // UIPageViewController 내부의 UIScrollView 찾기
        guard let scrollView = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else {
            Logger.viewer.error("Scroll UIScrollView를 찾을 수 없음")
            return
        }

        scrollView.delegate = self
        Logger.viewer.debug("Scroll UIScrollView delegate 설정 완료")
    }

    // MARK: - UIScrollViewDelegate

    /// 드래그 시작 (터치 직후) - 최적화 시작 + 버튼 숨김
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        LiquidGlassOptimizer.cancelIdleTimer()
        LiquidGlassOptimizer.optimize(in: view.window)

        // +버튼 + 타이틀 즉시 숨김 (스와이프 시 제자리에 남는 문제 방지)
        faceButtonOverlay?.hideButtonsImmediately()
        similarPhotoTitleLabel?.alpha = 0

        Logger.viewer.debug("Scroll willBeginDragging - optimize 시작")
    }

    /// 감속 완료 - 최적화 해제 + 버튼 복원
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        LiquidGlassOptimizer.restore(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)

        // 스와이프 취소 시 +버튼 복원 (didFinishAnimating completed=false면 복원 안 됨)
        restoreFaceButtonsIfNeeded()

        Logger.viewer.debug("Scroll didEndDecelerating - restore 완료")
    }

    /// 드래그 종료 (감속 없이 멈춤) - 최적화 해제 + 버튼 복원
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // 감속이 없으면 여기서 restore (감속 있으면 didEndDecelerating에서 처리)
        if !decelerate {
            LiquidGlassOptimizer.restore(in: view.window)
            LiquidGlassOptimizer.enterIdle(in: view.window)

            // 스와이프 취소 시 +버튼 복원
            restoreFaceButtonsIfNeeded()

            Logger.viewer.debug("Scroll didEndDragging(willDecelerate=false) - restore 완료")
        }
    }

    /// 스와이프 취소 시 +버튼 복원
    /// 전환 완료(completed=true) 시에는 updateSimilarPhotoOverlay()에서 처리되므로
    /// 여기서는 전환 중이 아닐 때(취소됨)만 복원
    private func restoreFaceButtonsIfNeeded() {
        guard !isTransitioning else { return }
        // 현재 사진에 대해 +버튼 재표시
        updateSimilarPhotoOverlay(resetZoom: false)
    }
}
