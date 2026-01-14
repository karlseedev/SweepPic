// PhotoPageViewController.swift
// 개별 사진을 표시하는 페이지 뷰 컨트롤러
//
// T033: 더블탭/핀치 줌 구현
// - 이미지 확대/축소

import UIKit
import Photos
import AppCore

// MARK: - Zoom & Scroll Notifications

extension Notification.Name {
    /// 사진 줌 변경 시 (줌 중)
    /// userInfo: ["zoomScale": CGFloat, "contentOffset": CGPoint, "imageSize": CGSize, "viewFrame": CGRect]
    static let photoDidZoom = Notification.Name("photoDidZoom")

    /// 사진 줌 완료 시
    /// userInfo: ["zoomScale": CGFloat, "contentOffset": CGPoint, "imageSize": CGSize, "viewFrame": CGRect]
    static let photoDidEndZoom = Notification.Name("photoDidEndZoom")

    /// 확대 상태에서 스크롤(패닝) 시
    /// userInfo: ["zoomScale": CGFloat, "contentOffset": CGPoint, "imageSize": CGSize, "viewFrame": CGRect]
    static let photoDidScroll = Notification.Name("photoDidScroll")

    /// 확대 상태에서 스크롤(패닝) 완료 시
    /// userInfo: ["zoomScale": CGFloat, "contentOffset": CGPoint, "imageSize": CGSize, "viewFrame": CGRect]
    static let photoDidEndScroll = Notification.Name("photoDidEndScroll")
}

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

    /// 휴지통 사진용 마룬 배경색 (#621C1C)
    private static let maroonBackgroundColor = UIColor(red: 0.384, green: 0.110, blue: 0.110, alpha: 1)

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

    // MARK: - Debug UI

    /// 디버그 모드 활성화 (assetID 표시)
    private let debugOverlayEnabled = true

    /// assetID 디버그 라벨 (우측 하단)
    private lazy var debugAssetLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Trashed Background (휴지통 사진 표시)

    /// 휴지통 배경 표시 여부 (보관함/앨범 뷰어에서만 true)
    /// - 휴지통 사진은 상하단 레터박스 영역이 마룬색으로 표시됨
    private var showTrashedBackground: Bool = false

    // MARK: - Initialization

    /// 페이지 생성 시점 (타임라인 비교용)
    private var createdAt: CFTimeInterval = 0

    /// 초기화
    /// - Parameters:
    ///   - asset: 표시할 PHAsset
    ///   - index: 인덱스
    ///   - showTrashedBackground: 휴지통 배경 표시 여부 (기본값 false)
    init(asset: PHAsset, index: Int, showTrashedBackground: Bool = false) {
        self.asset = asset
        self.index = index
        self.showTrashedBackground = showTrashedBackground
        super.init(nibName: nil, bundle: nil)
        createdAt = CACurrentMediaTime()
        print("[Photo] 🆕 init - index: \(index), showTrashedBackground: \(showTrashedBackground), t=\(String(format: "%.3f", createdAt))")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        if debugPhoto {
            let now = CACurrentMediaTime()
            print("[Photo] 📦 viewDidLoad - index: \(index), t=\(String(format: "%.3f", now)), since init: \(String(format: "%.1f", (now - createdAt) * 1000))ms")
        }

        // Phase 1: 즉시 레이아웃 + LOD0 요청
        applyInitialLayout()
        requestLOD0Image()
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

        // Phase 1: 초기 레이아웃이 아직 안 됐으면 적용 (fallback)
        if !hasAppliedInitialLayout {
            applyInitialLayout()
            requestLOD0Image()
        }

        // 줌 중에는 레이아웃 변경 보류
        if isZoomInteractionActive {
            needsLayoutUpdateAfterZoom = true
            return
        }

        // 이미 레이아웃 적용됨 → 레이아웃 변경 없음 (이미지만 교체됨)
        // requestImageForCurrentBoundsIfNeeded() 제거 - LOD0에서 이미 요청됨
    }

    deinit {
        requestCancellable?.cancel()
    }

    // MARK: - Debug: 상태 스냅샷

    /// 현재 상태 스냅샷 로깅 (전환 분석용)
    func debugSnapshot(tag: String, transitionId: Int) {
        let hasImage = imageView.image != nil
        let imgSize = imageView.image?.size ?? .zero
        print("[Photo] 📸 \(tag) tid=\(transitionId) idx=\(index) hasImage=\(hasImage) imgSize=\(imgSize) frame=\(imageView.frame) bounds=\(view.bounds.size)")
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
        // 휴지통 사진이면 마룬 배경, 아니면 검은색 배경
        view.backgroundColor = showTrashedBackground ? Self.maroonBackgroundColor : .black

        // 스크롤 뷰 (frame 기반)
        view.addSubview(scrollView)
        scrollView.frame = view.bounds

        // 이미지 뷰
        scrollView.addSubview(imageView)

        // 더블탭 제스처
        scrollView.addGestureRecognizer(doubleTapGesture)

        // 디버그 라벨 (우측 하단에 assetID 앞 8자리 표시)
        if debugOverlayEnabled {
            view.addSubview(debugAssetLabel)
            let assetIDPrefix = String(asset.localIdentifier.prefix(8))
            debugAssetLabel.text = " \(assetIDPrefix) "

            NSLayoutConstraint.activate([
                debugAssetLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
                debugAssetLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
            ])
        }
    }

    // MARK: - Public API (Trashed State)

    /// 휴지통 상태 업데이트 (복구 시 배경색 즉시 변경)
    /// - Parameter isTrashed: 휴지통 상태 여부
    func updateTrashedState(isTrashed: Bool) {
        showTrashedBackground = isTrashed

        // 배경색 애니메이션 변경
        UIView.animate(withDuration: 0.2) {
            self.view.backgroundColor = isTrashed ? Self.maroonBackgroundColor : .black
        }
    }

    // MARK: - Phase 1: Early Layout & LOD0

    /// PHAsset 비율 기반 레이아웃 (1회만 실행)
    /// - willTransition 시점에 frame이 확정되어 있어야 검은 영역 방지
    private func applyInitialLayout() {
        guard !hasAppliedInitialLayout else { return }

        let assetWidth = CGFloat(asset.pixelWidth)
        let assetHeight = CGFloat(asset.pixelHeight)
        guard assetWidth > 0, assetHeight > 0 else { return }

        // bounds가 0일 수 있으므로 UIScreen.main.bounds fallback
        let containerSize = view.bounds.size.width > 0
            ? view.bounds.size
            : UIScreen.main.bounds.size

        // aspect fit 계산
        let assetRatio = assetWidth / assetHeight
        let containerRatio = containerSize.width / containerSize.height

        let fitSize: CGSize
        if assetRatio > containerRatio {
            // 가로가 더 넓은 이미지 → width에 맞춤
            fitSize = CGSize(width: containerSize.width,
                            height: containerSize.width / assetRatio)
        } else {
            // 세로가 더 긴 이미지 → height에 맞춤
            fitSize = CGSize(width: containerSize.height * assetRatio,
                            height: containerSize.height)
        }

        // frame 확정
        imageView.frame = CGRect(origin: .zero, size: fitSize)
        scrollView.contentSize = fitSize

        // 중앙 정렬
        let hInset = max(0, (containerSize.width - fitSize.width) / 2)
        let vInset = max(0, (containerSize.height - fitSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: vInset, left: hInset,
                                               bottom: vInset, right: hInset)
        scrollView.contentOffset = CGPoint(x: -hInset, y: -vInset)

        // PHAsset 해상도로 maxZoomScale 미리 계산
        imageSize = CGSize(width: assetWidth, height: assetHeight)
        updateMaxZoomScale()

        hasAppliedInitialLayout = true

        if debugPhoto {
            print("[Photo] 🎯 applyInitialLayout - index: \(index), asset=\(Int(assetWidth))×\(Int(assetHeight)), fit=\(fitSize), vInset=\(vInset), containerSize=\(containerSize)")
        }
    }

    /// LOD0 즉시 요청 (.fast, opportunistic → degraded 먼저 표시)
    private func requestLOD0Image() {
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: screenSize.width * scale,
                               height: screenSize.height * scale)

        guard targetSize.width > 0, targetSize.height > 0 else { return }

        // 시간 측정 시작
        imageRequestStartTime = CFAbsoluteTimeGetCurrent()
        hasLoadedFullSize = false

        if debugPhoto {
            let now = CACurrentMediaTime()
            print("[Photo] 🚀 LOD0 요청 - index: \(index), t=\(String(format: "%.3f", now)), targetSize=\(targetSize)")
        }

        requestCancellable?.cancel()
        requestCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            quality: .fast  // opportunistic → degraded 먼저 표시
        ) { [weak self] image, isDegraded in
            guard let self = self, let image = image else { return }

            let elapsed = (CFAbsoluteTimeGetCurrent() - self.imageRequestStartTime) * 1000

            if self.debugPhoto {
                let now = CACurrentMediaTime()
                print("[Photo] ✅ LOD0 완료 - index: \(self.index), \(Int(elapsed))ms, degraded=\(isDegraded), since init: \(String(format: "%.0f", (now - self.createdAt) * 1000))ms")
            }

            // 이미지만 교체 (레이아웃 변경 없음!)
            self.imageView.image = image
            // imageSize는 applyInitialLayout에서 PHAsset 기반으로 이미 설정됨
            // → 여기서 덮어쓰지 않음 (maxZoomScale 보존)

            // Phase 2: LOD1은 ViewerViewController에서 디바운스 후 호출
            // (전환 중 디코딩 부하 방지)
        }
    }

    /// LOD1 원본 이미지 요청 (외부 호출용)
    /// - ViewerViewController에서 didFinishAnimating + 150ms 후 호출
    func requestHighQualityImage() {
        guard !hasLoadedFullSize else {
            if debugPhoto {
                print("[Photo] ⏭️ LOD1 스킵 (이미 로드됨) - index: \(index)")
            }
            return
        }
        requestFullSizeImage()
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
        guard targetSize != lastRequestedTargetSize else {
            if debugPhoto {
                print("[Photo] ⏭️ 중복 요청 스킵 - index: \(index)")
            }
            return
        }
        lastRequestedTargetSize = targetSize

        // 시간 측정 시작
        imageRequestStartTime = CFAbsoluteTimeGetCurrent()
        hasLoadedFullSize = false

        if debugPhoto {
            let now = CACurrentMediaTime()
            print("[Photo] 🚀 이미지 요청 - index: \(index), t=\(String(format: "%.3f", now)), since init: \(String(format: "%.0f", (now - createdAt) * 1000))ms")
        }

        requestCancellable?.cancel()
        requestCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            quality: .high  // 뷰어용 고품질
        ) { [weak self] image, isDegraded in
            guard let self = self, let image = image else { return }

            // 1차 로딩 시간 측정
            let elapsed = (CFAbsoluteTimeGetCurrent() - self.imageRequestStartTime) * 1000

            if self.debugPhoto {
                let now = CACurrentMediaTime()
                print("[Photo] ✅ 이미지 완료 - index: \(self.index), t=\(String(format: "%.3f", now)), \(Int(elapsed))ms, since init: \(String(format: "%.0f", (now - self.createdAt) * 1000))ms")
            }

            self.imageView.image = image
            self.imageSize = image.size

            // 줌 인터랙션 중에는 레이아웃 업데이트 보류
            if self.isZoomInteractionActive {
                self.needsLayoutUpdateAfterZoom = true
                if self.debugPhoto {
                    print("[Photo] ⏸️ 레이아웃 보류 (줌 중) - index: \(self.index)")
                }
            } else {
                if self.debugPhoto {
                    print("[Photo] 📏 updateImageLayout 호출 - index: \(self.index)")
                }
                self.updateImageLayout()
            }

            // 원본 이미지 요청 (2차)
            if !self.hasLoadedFullSize {
                self.requestFullSizeImage()
            }
        }
    }

    /// 원본 이미지 요청 (LOD1 - 줌용 고해상도)
    /// - Phase 1: 이미지만 교체, 레이아웃 변경 없음
    private func requestFullSizeImage() {
        if debugPhoto {
            let now = CACurrentMediaTime()
            print("[Photo] 🔍 LOD1 원본 요청 - index: \(index), t=\(String(format: "%.3f", now))")
        }
        fullSizeRequestCancellable?.cancel()
        fullSizeRequestCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            quality: .high  // 원본 고품질
        ) { [weak self] image, isDegraded in
            guard let self = self, let image = image, !isDegraded else { return }

            let elapsed = (CFAbsoluteTimeGetCurrent() - self.imageRequestStartTime) * 1000

            if self.debugPhoto {
                print("[Photo] ✅ LOD1 완료 - index: \(self.index), \(Int(elapsed))ms, size=\(image.size)")
            }

            self.hasLoadedFullSize = true

            // 이미지만 교체 (레이아웃 변경 없음!)
            self.imageView.image = image
            // imageSize는 applyInitialLayout에서 PHAsset 기반으로 설정됨
            // → 여기서 덮어쓰지 않음 (레이아웃 안정성 보장)
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

        // 줌 변경 알림 (FaceButtonOverlay 숨김용)
        NotificationCenter.default.post(
            name: .photoDidZoom,
            object: self,
            userInfo: makeZoomUserInfo()
        )
    }

    /// 줌 완료 시 - 플래그 해제
    /// Phase 1: 레이아웃은 applyInitialLayout에서 1회 확정, 이후 변경 없음
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if debugZoom { print("[ZOOM] DidEnd - scale=\(String(format: "%.3f", scale)), origin=\(imageView.frame.origin)") }
        isZoomInteractionActive = false
        needsLayoutUpdateAfterZoom = false

        // 줌 완료 알림 (FaceButtonOverlay 재표시용)
        NotificationCenter.default.post(
            name: .photoDidEndZoom,
            object: self,
            userInfo: makeZoomUserInfo()
        )
    }

    /// 줌 알림용 userInfo 생성
    private func makeZoomUserInfo() -> [String: Any] {
        return [
            "zoomScale": scrollView.zoomScale,
            "contentOffset": scrollView.contentOffset,
            "imageSize": imageSize,
            "viewFrame": view.frame,
            "imageViewFrame": imageView.frame
        ]
    }

    // MARK: - Scroll (Panning) in Zoomed State

    /// 스크롤 중 (확대 상태에서 패닝)
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 줌 중이거나 1x 스케일이면 무시 (줌은 별도 처리)
        guard !scrollView.isZooming && scrollView.zoomScale > 1.0 else { return }

        // 스크롤 알림 (FaceButtonOverlay 숨김용)
        NotificationCenter.default.post(
            name: .photoDidScroll,
            object: self,
            userInfo: makeZoomUserInfo()
        )
    }

    /// 드래그 종료 시
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // 감속 없이 바로 멈추면 여기서 재표시
        guard scrollView.zoomScale > 1.0 && !decelerate else { return }

        NotificationCenter.default.post(
            name: .photoDidEndScroll,
            object: self,
            userInfo: makeZoomUserInfo()
        )
    }

    /// 감속 완료 시 (스크롤 완전히 멈춤)
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.zoomScale > 1.0 else { return }

        NotificationCenter.default.post(
            name: .photoDidEndScroll,
            object: self,
            userInfo: makeZoomUserInfo()
        )
    }
}
