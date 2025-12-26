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

    /// 삭제 버튼 크기
    private static let deleteButtonSize: CGFloat = 56

    /// 삭제 버튼 하단 여백
    private static let deleteButtonBottomMargin: CGFloat = 40

    /// 아래 스와이프 닫기 임계값 (화면 높이의 %)
    private static let dismissThreshold: CGFloat = 0.15

    /// 최대 줌 스케일
    private static let maxZoomScale: CGFloat = 4.0

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: ViewerViewControllerDelegate?

    /// 현재 모드 (일반/휴지통)
    private let viewerMode: ViewerMode

    /// Coordinator (네비게이션 및 데이터 관리)
    private let coordinator: ViewerCoordinatorProtocol

    /// 스와이프 삭제 핸들러
    private var swipeDeleteHandler: SwipeDeleteHandler?

    /// 현재 표시 중인 인덱스
    private var currentIndex: Int

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

    /// 삭제 버튼 (일반 모드)
    private lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // 원형 버튼 스타일
        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        button.layer.cornerRadius = Self.deleteButtonSize / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.3

        // 휴지통 아이콘
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let image = UIImage(systemName: "trash.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white

        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 복구 버튼 (휴지통 모드)
    private lazy var restoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        button.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        button.layer.cornerRadius = Self.deleteButtonSize / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.3

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let image = UIImage(systemName: "arrow.uturn.backward", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white

        button.addTarget(self, action: #selector(restoreButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 완전삭제 버튼 (휴지통 모드)
    private lazy var permanentDeleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        button.layer.cornerRadius = Self.deleteButtonSize / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.3

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let image = UIImage(systemName: "trash.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white

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

        // 전체 화면 모달 스타일
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 시스템 모달 전환(animated: true) 대신, present(animated: false) + 가벼운 페이드 인 사용
        if isBeingPresented && !didPerformInitialFadeIn {
            view.alpha = 0
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if isBeingPresented && !didPerformInitialFadeIn {
            didPerformInitialFadeIn = true
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.view.alpha = 1
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

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

        // 모드에 따라 버튼 추가
        setupActionButtons()

        // 닫기 버튼
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 18
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    /// 액션 버튼 설정 (모드에 따라 다름)
    private func setupActionButtons() {
        switch viewerMode {
        case .normal:
            // 삭제 버튼
            view.addSubview(deleteButton)
            NSLayoutConstraint.activate([
                deleteButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                deleteButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.deleteButtonBottomMargin),
                deleteButton.widthAnchor.constraint(equalToConstant: Self.deleteButtonSize),
                deleteButton.heightAnchor.constraint(equalToConstant: Self.deleteButtonSize)
            ])

        case .trash:
            // 복구 버튼 (왼쪽)
            view.addSubview(restoreButton)
            NSLayoutConstraint.activate([
                restoreButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -50),
                restoreButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.deleteButtonBottomMargin),
                restoreButton.widthAnchor.constraint(equalToConstant: Self.deleteButtonSize),
                restoreButton.heightAnchor.constraint(equalToConstant: Self.deleteButtonSize)
            ])

            // 완전삭제 버튼 (오른쪽)
            view.addSubview(permanentDeleteButton)
            NSLayoutConstraint.activate([
                permanentDeleteButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 50),
                permanentDeleteButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.deleteButtonBottomMargin),
                permanentDeleteButton.widthAnchor.constraint(equalToConstant: Self.deleteButtonSize),
                permanentDeleteButton.heightAnchor.constraint(equalToConstant: Self.deleteButtonSize)
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

    /// 초기 사진 표시
    private func displayInitialPhoto() {
        guard let photoVC = createPhotoViewController(at: currentIndex) else { return }

        pageViewController.setViewControllers(
            [photoVC],
            direction: .forward,
            animated: false,
            completion: nil
        )
    }

    // MARK: - Actions

    /// 닫기 버튼 탭
    @objc private func closeButtonTapped() {
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
    }

    /// 복구 버튼 탭 (휴지통 모드)
    @objc private func restoreButtonTapped() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // 복구 요청
        delegate?.viewerDidRequestRestore(assetID: assetID)

        // 다음 사진으로 이동
        moveToNextAfterDelete()
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

        // 새 뷰 컨트롤러 생성 및 표시
        guard let photoVC = createPhotoViewController(at: currentIndex) else {
            dismissWithFadeOut()
            return
        }
        pageViewController.setViewControllers(
            [photoVC],
            direction: direction,
            animated: true,
            completion: nil
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

            // 배경 투명도 조절
            let progress = min(offsetY / view.bounds.height, 1.0)
            backgroundView.alpha = 1.0 - progress * 0.5

            // 페이지 뷰 위치 이동
            pageViewController.view.transform = CGAffineTransform(translationX: 0, y: offsetY)

        case .ended, .cancelled:
            let offsetY = translation.y - dragStartY
            let screenHeight = view.bounds.height
            let threshold = screenHeight * Self.dismissThreshold

            // 임계값을 넘었거나 빠른 속도로 스와이프한 경우 닫기
            if offsetY > threshold || velocity.y > 1000 {
                dismissWithAnimation()
            } else {
                // 원위치로 복귀
                UIView.animate(withDuration: 0.2) {
                    self.backgroundView.alpha = 1.0
                    self.pageViewController.view.transform = .identity
                }
            }

        default:
            break
        }
    }

    /// 애니메이션과 함께 닫기
    private func dismissWithAnimation() {
        guard !isDismissing else { return }
        isDismissing = true

        UIView.animate(withDuration: 0.25, animations: {
            self.backgroundView.alpha = 0
            self.pageViewController.view.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
        }, completion: { _ in
            self.dismiss(animated: false)
        })
    }

    private func dismissWithFadeOut() {
        guard !isDismissing else { return }
        isDismissing = true

        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]) {
            self.view.alpha = 0
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }

    // MARK: - Helpers

    /// 인덱스에 해당하는 PhotoPageViewController 생성
    private func createPhotoViewController(at index: Int) -> PhotoPageViewController? {
        guard let asset = coordinator.asset(at: index) else { return nil }
        return PhotoPageViewController(asset: asset, index: index)
    }
}

// MARK: - UIPageViewControllerDataSource

extension ViewerViewController: UIPageViewControllerDataSource {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let photoVC = viewController as? PhotoPageViewController else { return nil }
        let previousIndex = photoVC.index - 1
        guard previousIndex >= 0 else { return nil }
        return createPhotoViewController(at: previousIndex)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let photoVC = viewController as? PhotoPageViewController else { return nil }
        let nextIndex = photoVC.index + 1
        guard nextIndex < coordinator.totalCount else { return nil }
        return createPhotoViewController(at: nextIndex)
    }
}

// MARK: - UIPageViewControllerDelegate

extension ViewerViewController: UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed,
              let photoVC = pageViewController.viewControllers?.first as? PhotoPageViewController else {
            return
        }
        currentIndex = photoVC.index
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

// MARK: - PhotoPageViewController

/// 개별 사진을 표시하는 페이지 뷰 컨트롤러
/// 더블탭/핀치 줌 지원 (T033)
/// frame 기반 레이아웃 사용 (Auto Layout과 scrollView zoom 충돌 방지)
final class PhotoPageViewController: UIViewController {

    // MARK: - Constants

    /// 최소 줌 스케일
    private static let minZoomScale: CGFloat = 1.0

    /// 최대 줌 스케일
    private static let maxZoomScale: CGFloat = 4.0

    /// 더블탭 줌 스케일
    private static let doubleTapZoomScale: CGFloat = 2.5

    // MARK: - Properties

    /// 표시할 PHAsset
    let asset: PHAsset

    /// 인덱스
    let index: Int

    /// 스크롤 뷰 (핀치 줌용)
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.delegate = self
        sv.minimumZoomScale = Self.minZoomScale
        sv.maximumZoomScale = Self.maxZoomScale
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        // 줌 스케일이 min/max를 넘으며 튀는 현상 방지
        sv.bouncesZoom = false
        return sv
    }()

    /// 이미지 뷰 (frame 기반)
    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    /// 더블탭 제스처
    private lazy var doubleTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        gesture.numberOfTapsRequired = 2
        return gesture
    }()

    /// 이미지 요청 토큰 (v6: Cancellable)
    private var requestCancellable: Cancellable?

    /// 원본 이미지 크기 (aspect fit 계산용)
    private var imageSize: CGSize = .zero

    /// 마지막 요청 targetSize (중복 요청 방지)
    private var lastRequestedTargetSize: CGSize = .zero

    /// P0: 초기 레이아웃 적용 여부 (1회만 zoomScale = 1.0 수행)
    private var hasAppliedInitialLayout = false

    /// P4: 줌 동작 중 보류된 레이아웃 갱신 필요 여부
    private var needsLayoutUpdateAfterZoom = false

    /// 줌 인터랙션 활성화 플래그 (isZooming보다 먼저 true가 됨)
    /// - scrollViewWillBeginZooming에서 true, scrollViewDidEndZooming에서 false
    private var isZoomInteractionActive = false

    /// 디버그 로그 활성화
    private let debugZoom = true

    // MARK: - Initialization

    init(asset: PHAsset, index: Int) {
        self.asset = asset
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds

        // 줌 인터랙션 중에는 레이아웃 갱신을 보류 (줌 완료 후 수행)
        // isZoomInteractionActive는 isZooming보다 먼저 true가 되어 첫 프레임부터 보호
        if isZoomInteractionActive {
            needsLayoutUpdateAfterZoom = true
        } else {
            requestImageForCurrentBoundsIfNeeded()
            updateImageLayout()
        }
    }

    deinit {
        requestCancellable?.cancel()
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        view.backgroundColor = .clear

        // 스크롤 뷰 (frame 기반)
        view.addSubview(scrollView)
        scrollView.frame = view.bounds

        // 이미지 뷰
        scrollView.addSubview(imageView)

        // 더블탭 제스처
        scrollView.addGestureRecognizer(doubleTapGesture)
    }

    /// 이미지 요청
    /// - 첫 모달 진입 시점에는 page 내부 VC의 bounds가 0인 경우가 있어, 0-size 요청이 들어가면
    ///   PhotoKit이 사실상 원본급 이미지를 내려주며 디코딩 비용으로 UI가 잠깐 멈출 수 있음.
    /// - bounds가 확정된 뒤 1회 요청하고, 사이즈가 바뀌면 재요청.
    private func requestImageForCurrentBoundsIfNeeded() {
        let scale = UIScreen.main.scale
        let boundsSize = view.bounds.size
        let containerSize = (boundsSize.width > 0 && boundsSize.height > 0) ? boundsSize : UIScreen.main.bounds.size

        // 최적화: 화면 픽셀 크기면 1:1 매핑으로 충분 (×2 제거)
        let targetSize = CGSize(
            width: ceil(containerSize.width * scale),
            height: ceil(containerSize.height * scale)
        )

        guard targetSize.width > 0, targetSize.height > 0 else { return }
        guard targetSize != lastRequestedTargetSize else { return }
        lastRequestedTargetSize = targetSize

        requestCancellable?.cancel()
        requestCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit
        ) { [weak self] image, isDegraded in
            guard let self = self, let image = image else { return }

            self.imageView.image = image
            self.imageSize = image.size  // 항상 갱신 (High fix)

            // 줌 인터랙션 중에는 레이아웃 업데이트 보류 (줌 완료 후 수행)
            if self.isZoomInteractionActive {
                self.needsLayoutUpdateAfterZoom = true
                return
            }

            if isDegraded {
                // 저해상도: 초기 레이아웃만 적용 (아직 안 잡힌 경우)
                if !self.hasAppliedInitialLayout {
                    self.updateImageLayout()
                }
            } else {
                // 고해상도 확정: 줌 보존하며 레이아웃 업데이트
                self.updateImageLayoutPreservingZoom()
            }
        }
    }

    /// 이미지 레이아웃 업데이트 (frame 기반)
    /// - 초기 1회에만 zoomScale = 1.0 수행 (P0)
    private func updateImageLayout() {
        guard imageSize.width > 0 && imageSize.height > 0 else { return }

        let scrollViewSize = scrollView.bounds.size
        guard scrollViewSize.width > 0 && scrollViewSize.height > 0 else { return }

        // aspect fit 크기 계산
        let widthRatio = scrollViewSize.width / imageSize.width
        let heightRatio = scrollViewSize.height / imageSize.height
        let ratio = min(widthRatio, heightRatio)

        let fitWidth = imageSize.width * ratio
        let fitHeight = imageSize.height * ratio

        // 이미지 뷰 크기 설정
        imageView.frame = CGRect(x: 0, y: 0, width: fitWidth, height: fitHeight)

        // 스크롤 뷰 콘텐츠 크기 설정
        scrollView.contentSize = CGSize(width: fitWidth, height: fitHeight)

        // P0: 초기 1회에만 줌 스케일 리셋
        let preserveOffset = hasAppliedInitialLayout
        if !hasAppliedInitialLayout {
            scrollView.zoomScale = 1.0
        }
        hasAppliedInitialLayout = true
        updateContentInsetForCentering(preserveOffset: preserveOffset)
    }

    /// 이미지 레이아웃 업데이트 (줌 보존 버전)
    /// - 이미지 교체 시 현재 줌 스케일을 유지하면서 레이아웃만 업데이트
    /// - zoomScale 재설정 금지 (줌 중 끊김 방지)
    private func updateImageLayoutPreservingZoom() {
        guard imageSize.width > 0 && imageSize.height > 0 else { return }

        let scrollViewSize = scrollView.bounds.size
        guard scrollViewSize.width > 0 && scrollViewSize.height > 0 else { return }

        // aspect fit 크기 계산
        let widthRatio = scrollViewSize.width / imageSize.width
        let heightRatio = scrollViewSize.height / imageSize.height
        let ratio = min(widthRatio, heightRatio)

        let fitWidth = imageSize.width * ratio
        let fitHeight = imageSize.height * ratio

        // 이미지 뷰 크기 설정
        imageView.frame = CGRect(x: 0, y: 0, width: fitWidth, height: fitHeight)

        // 스크롤 뷰 콘텐츠 크기 설정
        scrollView.contentSize = CGSize(width: fitWidth, height: fitHeight)

        // zoomScale 재설정 제거 - 줌 중 끊김의 주요 원인
        // scrollView.zoomScale = currentZoom

        // 플래그 갱신 (회전 등에서 updateImageLayout 호출 시 리셋 방지)
        let preserveOffset = hasAppliedInitialLayout
        hasAppliedInitialLayout = true
        updateContentInsetForCentering(preserveOffset: preserveOffset)
    }

    /// contentInset으로 중앙 정렬하고, 필요 시 contentOffset 보정
    private func updateContentInsetForCentering(preserveOffset: Bool) {
        let scrollViewSize = scrollView.bounds.size
        let contentSize = imageView.frame.size

        let horizontalInset = max(0, (scrollViewSize.width - contentSize.width) / 2)
        let verticalInset = max(0, (scrollViewSize.height - contentSize.height) / 2)
        let newInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )

        let oldInset = scrollView.contentInset
        guard oldInset != newInset else { return }

        if preserveOffset {
            let offset = scrollView.contentOffset
            let deltaX = newInset.left - oldInset.left
            let deltaY = newInset.top - oldInset.top
            scrollView.contentInset = newInset
            scrollView.contentOffset = CGPoint(x: offset.x - deltaX, y: offset.y - deltaY)
        } else {
            scrollView.contentInset = newInset
            scrollView.contentOffset = CGPoint(x: -newInset.left, y: -newInset.top)
        }
    }

    // MARK: - Double Tap Zoom (T033)

    /// 더블탭 줌 처리
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        // 더블탭 시 보류된 레이아웃 갱신 해제 (edge case 방지)
        needsLayoutUpdateAfterZoom = false

        if scrollView.zoomScale > Self.minZoomScale {
            // 줌 아웃
            scrollView.setZoomScale(Self.minZoomScale, animated: true)
        } else {
            // 줌 인 - 탭한 위치를 중심으로
            let location = gesture.location(in: imageView)
            let zoomRect = CGRect(
                x: location.x - (scrollView.bounds.width / Self.doubleTapZoomScale / 2),
                y: location.y - (scrollView.bounds.height / Self.doubleTapZoomScale / 2),
                width: scrollView.bounds.width / Self.doubleTapZoomScale,
                height: scrollView.bounds.height / Self.doubleTapZoomScale
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
}

// MARK: - UIScrollViewDelegate

extension PhotoPageViewController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    /// 줌 시작 직전 - 플래그 설정 (isZooming보다 먼저 호출됨)
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        if debugZoom { print("[ZOOM] WillBegin - scale=\(String(format: "%.3f", scrollView.zoomScale)), origin=\(imageView.frame.origin)") }
        isZoomInteractionActive = true
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 첫 몇 프레임만 로그
        if debugZoom && scrollView.zoomScale < 1.15 {
            print("[ZOOM] DidZoom - scale=\(String(format: "%.3f", scrollView.zoomScale)), origin=\(imageView.frame.origin)")
        }
        updateContentInsetForCentering(preserveOffset: true)
    }

    /// 줌 완료 시 - 플래그 해제 및 보류된 레이아웃 갱신 수행
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if debugZoom { print("[ZOOM] DidEnd - scale=\(String(format: "%.3f", scale)), origin=\(imageView.frame.origin), needsUpdate=\(needsLayoutUpdateAfterZoom)") }
        isZoomInteractionActive = false

        if needsLayoutUpdateAfterZoom {
            if debugZoom { print("[ZOOM] 보류된 갱신 수행") }
            requestImageForCurrentBoundsIfNeeded()
            updateImageLayoutPreservingZoom()
            needsLayoutUpdateAfterZoom = false
        }
    }
}
