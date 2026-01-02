// PhotoPageViewController.swift
// 개별 사진을 표시하는 페이지 뷰 컨트롤러
//
// T033: 더블탭/핀치 줌 구현
// - 이미지 확대/축소

import UIKit
import Photos
import AppCore

// MARK: - PhotoPageViewController

/// 개별 사진을 표시하는 페이지 뷰 컨트롤러
/// 더블탭/핀치 줌 지원 (T033)
/// frame 기반 레이아웃 사용 (Auto Layout과 scrollView zoom 충돌 방지)
final class PhotoPageViewController: UIViewController {

    // MARK: - Constants

    /// 최소 줌 스케일
    private static let minZoomScale: CGFloat = 1.0

    /// 이미지 크기 알 수 없을 때 기본 최대 줌 스케일
    private static let fallbackMaxZoomScale: CGFloat = 4.0

    /// 최대 줌 스케일 상한 (메모리 보호)
    /// - 기본 사진 앱 수준의 확대를 위해 충분히 높게 설정
    private static let maxZoomScaleLimit: CGFloat = 50.0

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
        sv.maximumZoomScale = Self.fallbackMaxZoomScale
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

    /// 원본 이미지 요청 토큰
    private var fullSizeRequestCancellable: Cancellable?

    /// 원본 이미지 로드 완료 여부
    private var hasLoadedFullSize = false

    /// 이미지 요청 시작 시간 (디버그용)
    private var imageRequestStartTime: CFAbsoluteTime = 0

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

    /// 사진 로딩 디버그 로그 활성화
    private let debugPhoto = true

    /// 초기 레이아웃 정보 로그 여부 (로그 스팸 방지)
    private var hasLoggedInitialLayoutInfo = false

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

        // LOD0: viewDidLoad에서 즉시 포스터 로드 (전환 시작 전에 이미지 준비)
        // bounds가 0일 수 있으므로 UIScreen.main.bounds를 fallback으로 사용
        requestPosterImage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds

        if debugPhoto {
            print("[Photo] 📐 viewDidLayoutSubviews - index: \(index), bounds: \(view.bounds.size)")
            if !hasLoggedInitialLayoutInfo {
                hasLoggedInitialLayoutInfo = true
                print("[Photo] 🎨 backgroundColor - index: \(index), color: \(String(describing: view.backgroundColor))")
            }
        }

        // LOD 파이프라인: 이미지 요청은 viewDidLoad(LOD0), didFinishAnimating(LOD1)에서 수행
        // viewDidLayoutSubviews에서는 레이아웃만 업데이트 (전환 중 요청 방지)
        if isZoomInteractionActive {
            needsLayoutUpdateAfterZoom = true
        } else {
            updateImageLayout()
        }
    }

    deinit {
        requestCancellable?.cancel()
    }

    // MARK: - Zoom Scale

    /// 이미지 해상도 기반 최대 줌 스케일 계산
    /// - 원본 픽셀을 화면 포인트에 1:1로 볼 수 있는 배율 반환 (기본 사진 앱과 동일)
    /// - Retina 3x 디스플레이에서는 원본 1픽셀 = 화면 9픽셀로 표시
    /// - 최소 fallbackMaxZoomScale(4배), 최대 maxZoomScaleLimit(50배) 보장
    private func calculateMaxZoomScale(for imageSize: CGSize) -> CGFloat {
        let containerSize = scrollView.bounds.size
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return Self.fallbackMaxZoomScale
        }

        // aspect fit 시 축소 비율 계산
        let fitRatio = min(containerSize.width / imageSize.width,
                           containerSize.height / imageSize.height)

        // 기본 사진 앱처럼 원본 픽셀을 화면 포인트에 1:1로 매핑
        // screenScale을 곱해서 Retina 디스플레이에서도 충분히 확대 가능하게 함
        // 예: 4032x3024 이미지, 393pt 화면, 3x 디스플레이
        //     fitRatio ≈ 0.097, screenScale = 3.0
        //     → 3.0/0.097 ≈ 30.9배까지 확대 가능
        let screenScale = UIScreen.main.scale
        let calculatedScale = screenScale / fitRatio

        // 최소 4배, 최대 50배로 클램프
        return max(Self.fallbackMaxZoomScale, min(calculatedScale, Self.maxZoomScaleLimit))
    }

    /// 현재 이미지 크기에 맞게 최대 줌 스케일 업데이트
    private func updateMaxZoomScale() {
        let newMaxScale = calculateMaxZoomScale(for: imageSize)
        scrollView.maximumZoomScale = newMaxScale

        if debugZoom {
            print("[Zoom] maxScale=\(String(format: "%.1f", newMaxScale))x (image=\(Int(imageSize.width))×\(Int(imageSize.height)))")
        }
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        // LOD 파이프라인: 검정 배경으로 인접 페이지 레이아웃 변경 비침 방지
        view.backgroundColor = .black

        // 스크롤 뷰 (frame 기반)
        view.addSubview(scrollView)
        scrollView.frame = view.bounds

        // 이미지 뷰
        scrollView.addSubview(imageView)

        // 더블탭 제스처
        scrollView.addGestureRecognizer(doubleTapGesture)
    }

    // MARK: - LOD Pipeline

    /// LOD0: 포스터 이미지 요청 (viewDidLoad에서 호출)
    /// - .fast 품질로 즉시 표시 (degraded 허용)
    /// - bounds가 0일 수 있으므로 UIScreen.main.bounds를 fallback으로 사용
    private func requestPosterImage() {
        let scale = UIScreen.main.scale
        let boundsSize = view.bounds.size
        let containerSize = (boundsSize.width > 0 && boundsSize.height > 0) ? boundsSize : UIScreen.main.bounds.size

        // 물리 픽셀 크기로 요청 (레티나 디스플레이 선명도 보장)
        let targetSize = CGSize(
            width: ceil(containerSize.width * scale),
            height: ceil(containerSize.height * scale)
        )

        guard targetSize.width > 0, targetSize.height > 0 else { return }

        // 시간 측정 시작
        imageRequestStartTime = CFAbsoluteTimeGetCurrent()

        if debugPhoto {
            print("[Photo] 🚀 LOD0 포스터 요청 - index: \(index), targetSize: \(targetSize)")
        }

        requestCancellable?.cancel()
        requestCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            quality: .fast  // LOD0: 즉시 표시 (opportunistic, degraded 허용)
        ) { [weak self] image, isDegraded in
            guard let self = self, let image = image else { return }

            let elapsed = (CFAbsoluteTimeGetCurrent() - self.imageRequestStartTime) * 1000

            if self.debugPhoto {
                print("[Photo] 🖼️ LOD0 완료 - index: \(self.index), \(Int(elapsed))ms, size=\(image.size), degraded=\(isDegraded)")
            }

            self.imageView.image = image
            self.imageSize = image.size

            // 줌 인터랙션 중에는 레이아웃 업데이트 보류
            if self.isZoomInteractionActive {
                self.needsLayoutUpdateAfterZoom = true
            } else {
                self.updateImageLayout()
            }

            // LOD0에서는 원본 요청하지 않음 (Phase 2: LOD1, Phase 3: LOD2에서 처리)
        }
    }

    /// LOD1: 고품질 이미지 요청 (didFinishAnimating 후 호출)
    /// - .high 품질로 선명한 이미지 로드
    /// - 현재 페이지만 요청 (인접 페이지는 요청하지 않음)
    func requestHighQualityImage() {
        let scale = UIScreen.main.scale
        let boundsSize = view.bounds.size
        let containerSize = (boundsSize.width > 0 && boundsSize.height > 0) ? boundsSize : UIScreen.main.bounds.size

        let targetSize = CGSize(
            width: ceil(containerSize.width * scale),
            height: ceil(containerSize.height * scale)
        )

        guard targetSize.width > 0, targetSize.height > 0 else { return }

        if debugPhoto {
            print("[Photo] 🔷 LOD1 고품질 요청 - index: \(index), targetSize: \(targetSize)")
        }

        requestCancellable?.cancel()
        requestCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            quality: .high  // LOD1: 고품질
        ) { [weak self] image, isDegraded in
            guard let self = self, let image = image else { return }

            if self.debugPhoto {
                print("[Photo] 🔷 LOD1 완료 - index: \(self.index), size=\(image.size), degraded=\(isDegraded)")
            }

            self.imageView.image = image
            self.imageSize = image.size

            if self.isZoomInteractionActive {
                self.needsLayoutUpdateAfterZoom = true
            } else {
                self.updateImageLayoutPreservingZoom()
            }
        }
    }

    /// 고품질 이미지 요청 취소 (전환 시작 시 호출)
    func cancelHighQualityImageRequests() {
        fullSizeRequestCancellable?.cancel()
        fullSizeRequestCancellable = nil

        if debugPhoto {
            print("[Photo] ❌ 고품질 요청 취소 - index: \(index)")
        }
    }

    /// 원본 이미지 요청 (줌용)
    private func requestFullSizeImage() {
        if debugPhoto {
            let now = CACurrentMediaTime()
            print("[Viewer] 2️⃣ 원본 요청 시작 - index: \(index), t=\(String(format: "%.3f", now))")
        }
        fullSizeRequestCancellable?.cancel()
        fullSizeRequestCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            quality: .high  // 원본 고품질
        ) { [weak self] image, isDegraded in
            guard let self = self, let image = image, !isDegraded else { return }

            // 2차 로딩 시간 측정
            let elapsed = (CFAbsoluteTimeGetCurrent() - self.imageRequestStartTime) * 1000
            let now = CACurrentMediaTime()
            print("[Viewer] 2️⃣ 원본: \(Int(elapsed))ms, size=\(image.size), t=\(String(format: "%.3f", now))")

            self.hasLoadedFullSize = true
            self.imageView.image = image
            self.imageSize = image.size

            // 줌 인터랙션 중이면 보류
            if self.isZoomInteractionActive {
                self.needsLayoutUpdateAfterZoom = true
            } else {
                if self.debugPhoto {
                    print("[Photo] 📏 updateImageLayoutPreservingZoom 호출 - index: \(self.index)")
                }
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

        let oldFrame = imageView.frame

        // 이미지 뷰 크기 설정
        imageView.frame = CGRect(x: 0, y: 0, width: fitWidth, height: fitHeight)

        // 스크롤 뷰 콘텐츠 크기 설정
        scrollView.contentSize = CGSize(width: fitWidth, height: fitHeight)

        if debugPhoto && oldFrame != imageView.frame {
            print("[Photo] 📦 frame 변경 - index: \(index), old: \(oldFrame), new: \(imageView.frame)")
            let emptyVertical = max(0, scrollViewSize.height - fitHeight)
            print("[Photo] 🧱 emptyVertical - index: \(index), empty=\(String(format: "%.1f", emptyVertical))")
        }

        // P0: 초기 1회에만 줌 스케일 리셋
        let preserveOffset = hasAppliedInitialLayout
        if !hasAppliedInitialLayout {
            scrollView.zoomScale = 1.0
        }
        hasAppliedInitialLayout = true

        // 이미지 해상도에 맞게 최대 줌 스케일 업데이트
        updateMaxZoomScale()

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

        // 원본 이미지 로드 시 해상도에 맞게 최대 줌 스케일 업데이트
        updateMaxZoomScale()

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

        if debugPhoto {
            print("[Photo] 🧭 contentInset - index: \(index), inset=\(newInset), offset=\(scrollView.contentOffset)")
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

    /// 줌 시작 직전 - 플래그 설정 및 LOD2 요청 (isZooming보다 먼저 호출됨)
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        if debugZoom { print("[ZOOM] WillBegin - scale=\(String(format: "%.3f", scrollView.zoomScale)), origin=\(imageView.frame.origin)") }
        isZoomInteractionActive = true

        // LOD2: 줌 시작 시 원본 이미지 요청 (아직 로드하지 않은 경우에만)
        // 줌 시작 시점에 요청하여 확대 시 선명도 보장
        if !hasLoadedFullSize {
            requestFullSizeImage()
        }
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
            // LOD 파이프라인: 줌 완료 후에는 레이아웃만 업데이트 (이미지 재요청 불필요)
            updateImageLayoutPreservingZoom()
            needsLayoutUpdateAfterZoom = false
        }
    }
}
