// VideoPageViewController.swift
// 개별 동영상을 표시하는 페이지 뷰 컨트롤러
//
// AVPlayer + AVPlayerLayer 기반 동영상 재생
// - 포스터 먼저 표시 → isReadyForDisplay 후 전환 (검은 화면 방지)
// - UIScrollView 기반 핀치줌/더블탭 줌
// - ViewerViewController가 요청 트리거 (인접 페이지 다운로드 방지)

import UIKit
import Photos
import AVFoundation
import AppCore

// MARK: - VideoPageViewController

/// 개별 동영상을 표시하는 페이지 뷰 컨트롤러
/// AVPlayer + AVPlayerLayer 기반, UIScrollView로 핀치줌 지원
final class VideoPageViewController: UIViewController {

    // MARK: - Constants

    /// 더블탭 줌 스케일
    private static let doubleTapZoomScale: CGFloat = 2.5

    /// 삭제대기함 사진용 마룬 배경색 (#621C1C)
    private static let maroonBackgroundColor = UIColor(red: 0.384, green: 0.110, blue: 0.110, alpha: 1)

    // MARK: - Properties

    /// 표시할 PHAsset
    let asset: PHAsset

    /// 인덱스 (페이지 전환 추적용)
    let index: Int

    /// 줌을 위한 UIScrollView
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.delegate = self
        sv.minimumZoomScale = 1.0
        sv.maximumZoomScale = 4.0  // 초기값, 비디오 로드 후 동적 계산
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.bouncesZoom = true
        return sv
    }()

    /// PlayerLayerView (layerClass = AVPlayerLayer)
    private lazy var playerLayerView: PlayerLayerView = {
        let view = PlayerLayerView()
        return view
    }()

    /// AVPlayer 인스턴스
    private var player: AVPlayer?

    /// KVO 관찰자 - isReadyForDisplay
    private var readyForDisplayObserver: NSKeyValueObservation?

    /// KVO 관찰자 - AVPlayerItem.status
    private var statusObserver: NSKeyValueObservation?

    /// 썸네일 요청 취소 토큰
    private var thumbnailRequestCancellable: Cancellable?

    /// 비디오 요청 취소 토큰
    private var videoRequestCancellable: Cancellable?

    /// 비디오 표시 크기 (preferredTransform 적용된 크기)
    private var videoDisplaySize: CGSize = .zero

    /// 줌 상태 플래그 (레이아웃 업데이트 방지)
    private var isZoomInteractionActive = false

    /// 자동 재생 플래그
    private var shouldAutoPlay = true

    /// 비디오 요청 완료 여부 (중복 요청 방지)
    private var hasRequestedVideo = false

    /// 첫 프레임 표시 완료 여부 (KVO 중복 호출 방지)
    private var hasShownFirstFrame = false

    /// 에러 레이블
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()


    /// 비디오 컨트롤 오버레이
    private lazy var controlsOverlay: VideoControlsOverlay = {
        let overlay = VideoControlsOverlay()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.delegate = self
        return overlay
    }()

    /// 더블탭 제스처 (싱글탭과 충돌 방지용으로 참조 필요)
    private lazy var doubleTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        gesture.numberOfTapsRequired = 2
        return gesture
    }()

    // MARK: - Trashed Background (삭제대기함 사진 표시)

    /// 삭제대기함 배경 표시 여부 (보관함/앨범 뷰어에서만 true)
    /// - 삭제대기함 사진은 상하단 레터박스 영역이 마룬색으로 표시됨
    private var showTrashedBackground: Bool = false

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - asset: 표시할 PHAsset
    ///   - index: 인덱스
    ///   - showTrashedBackground: 삭제대기함 배경 표시 여부 (기본값 false)
    init(asset: PHAsset, index: Int, showTrashedBackground: Bool = false) {
        self.asset = asset
        self.index = index
        self.showTrashedBackground = showTrashedBackground
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSession()
        setupUI()
        setupGestures()
        loadPoster()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // 줌 중에는 레이아웃 업데이트 보류
        guard !isZoomInteractionActive else { return }

        // ⚠️ 순서 중요: 먼저 oldSize 저장 → 그 다음 frame 업데이트
        let oldSize = scrollView.frame.size
        let newSize = view.bounds.size
        scrollView.frame = view.bounds

        // 회전 감지: bounds 크기가 변경되고 비디오 사이즈가 있으면 레이아웃 재계산
        if oldSize != newSize && oldSize != .zero && videoDisplaySize != .zero {
            recalculateLayoutForRotation()
        } else {
            updateVideoLayout()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pause()
        cancelVideoRequest()
    }

    deinit {
        cleanupPlayer()
        thumbnailRequestCancellable?.cancel()
        videoRequestCancellable?.cancel()

    }

    // MARK: - Audio Session

    /// 오디오 세션 설정
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)

        } catch {
        }
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        // 삭제대기함 사진이면 마룬 배경, 아니면 검은색 배경
        view.backgroundColor = showTrashedBackground ? Self.maroonBackgroundColor : .black

        // ScrollView 추가
        view.addSubview(scrollView)

        // PlayerLayerView 추가 (scrollView 내부)
        scrollView.addSubview(playerLayerView)

        // 에러 레이블 (scrollView 위)
        view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])

        // 컨트롤 오버레이 (scrollView 위)
        view.addSubview(controlsOverlay)
        NSLayoutConstraint.activate([
            controlsOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            controlsOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Public API (Trashed State)

    /// 삭제대기함 상태 업데이트 (복구 시 배경색 즉시 변경)
    /// - Parameter isTrashed: 삭제대기함 상태 여부
    func updateTrashedState(isTrashed: Bool) {
        showTrashedBackground = isTrashed

        // 배경색 애니메이션 변경
        UIView.animate(withDuration: 0.2) {
            self.view.backgroundColor = isTrashed ? Self.maroonBackgroundColor : .black
        }
    }

    /// 제스처 설정
    private func setupGestures() {
        // 더블탭 → 줌 토글
        scrollView.addGestureRecognizer(doubleTapGesture)

        // 싱글탭 → 컨트롤 토글
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)  // 더블탭 우선
        view.addGestureRecognizer(singleTapGesture)

        // Note: UIScrollView의 내장 panGestureRecognizer.delegate는 변경 불가
        // 제스처 충돌 방지는 scrollViewDidScroll에서 처리
    }

    /// 싱글탭 제스처 처리 - 컨트롤 토글
    @objc private func handleSingleTap() {
        controlsOverlay.toggle()
    }

    // MARK: - Poster Loading

    /// 포스터 이미지 로드
    private func loadPoster() {
        // bounds가 아직 설정되지 않은 경우 기본 크기 사용
        let screenSize = UIScreen.main.bounds.size
        let width = view.bounds.width > 0 ? view.bounds.width : screenSize.width
        let height = view.bounds.height > 0 ? view.bounds.height : screenSize.height

        let targetSize = CGSize(
            width: width * UIScreen.main.scale,
            height: height * UIScreen.main.scale
        )

        thumbnailRequestCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit
        ) { [weak self] image, isDegraded in
            guard let self = self, let image = image else { return }

            self.playerLayerView.setPoster(image)
        }
    }

    // MARK: - Video Request (ViewerViewController가 호출)

    /// 비디오 요청 (ViewerViewController가 호출)
    /// - 인접 페이지가 아닌 현재 페이지에서만 호출됨을 보장
    func requestVideoIfNeeded() {
        // 이미 첫 프레임이 표시됐으면 재요청 불필요 (취소 후 재진입 시)
        guard !hasShownFirstFrame else {
            // 플레이어가 있으면 재생 재개
            if player != nil {
                player?.play()
            }
            return
        }

        guard !hasRequestedVideo else { return }

        hasRequestedVideo = true
        playerLayerView.loadingIndicator.startAnimating()
        errorLabel.isHidden = true

        videoRequestCancellable = VideoPipeline.shared.requestPlayerItem(
            for: asset,
            progressHandler: { progress in
            },
            completion: { [weak self] playerItem, info in
                guard let self = self else { return }

                // 취소된 경우
                if VideoPipeline.isCancelled(from: info) {
                    self.hasRequestedVideo = false
                    return
                }

                // 에러 처리
                if let error = VideoPipeline.error(from: info) {
                    self.hasRequestedVideo = false
                    // [Analytics] 동영상 로드 실패
                    AnalyticsService.shared.countError(.viewerOriginal as AnalyticsError.PhotoLoad)
                    self.showError(error.localizedDescription)
                    return
                }

                guard let playerItem = playerItem else {
                    self.hasRequestedVideo = false
                    self.showError("동영상을 로드할 수 없습니다")
                    return
                }

                self.setupPlayer(with: playerItem)
            }
        )
    }

    /// 비디오 요청 취소 (페이지 이탈 시)
    private func cancelVideoRequest() {
        videoRequestCancellable?.cancel()
        videoRequestCancellable = nil
        hasRequestedVideo = false

        // 로딩 인디케이터 중지 (이전에 누락됨!)
        playerLayerView.loadingIndicator.stopAnimating()

    }

    // MARK: - Player Setup

    /// AVPlayer 설정
    private func setupPlayer(with playerItem: AVPlayerItem) {
        let player = AVPlayer(playerItem: playerItem)
        self.player = player

        // 기본 음소거로 시작
        player.isMuted = true

        // PlayerLayerView에 플레이어 연결
        playerLayerView.player = player

        // KVO 설정
        setupKVO()

        // 비디오 표시 크기 가져오기
        fetchVideoDisplaySize(from: playerItem)

        // 컨트롤 오버레이 연결
        controlsOverlay.configure(with: player)
        controlsOverlay.updateMuteState(isMuted: true)

    }

    // MARK: - KVO

    /// KVO 설정
    private func setupKVO() {
        // AVPlayerLayer.isReadyForDisplay 관찰
        readyForDisplayObserver = playerLayerView.playerLayer.observe(
            \.isReadyForDisplay,
            options: [.initial, .new]
        ) { [weak self] layer, _ in
            guard let self = self else { return }

            guard layer.isReadyForDisplay else { return }

            DispatchQueue.main.async {
                self.onReadyForDisplay()
            }
        }

        // AVPlayerItem.status 관찰 (에러 처리용)
        statusObserver = player?.currentItem?.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] item, _ in
            guard let self = self else { return }

            if item.status == .failed {
                // [Analytics] 동영상 재생 실패
                AnalyticsService.shared.countError(.viewerOriginal as AnalyticsError.PhotoLoad)
                DispatchQueue.main.async {
                    self.showError(item.error?.localizedDescription ?? "재생 실패")
                }
            }
        }
    }

    /// 첫 프레임 표시 준비 완료
    private func onReadyForDisplay() {
        // 중복 호출 방지
        guard !hasShownFirstFrame else { return }
        hasShownFirstFrame = true

        // 포스터 fade-out
        playerLayerView.hidePoster(animated: true)
        playerLayerView.loadingIndicator.stopAnimating()

        // 자동 재생
        if shouldAutoPlay {
            player?.play()
            controlsOverlay.updatePlayPauseState(isPlaying: true)
        }

    }

    /// KVO 해제
    private func removeKVO() {
        readyForDisplayObserver?.invalidate()
        readyForDisplayObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
    }

    // MARK: - Video Display Size

    /// 비디오 표시 크기 가져오기 (preferredTransform 적용)
    private func fetchVideoDisplaySize(from playerItem: AVPlayerItem) {
        Task {
            guard let track = try? await playerItem.asset.loadTracks(withMediaType: .video).first else {
                return
            }

            let naturalSize = try? await track.load(.naturalSize)
            let transform = try? await track.load(.preferredTransform)

            guard let size = naturalSize else { return }

            await MainActor.run {
                if let transform = transform {
                    let transformedSize = size.applying(transform)
                    self.videoDisplaySize = CGSize(
                        width: abs(transformedSize.width),
                        height: abs(transformedSize.height)
                    )
                } else {
                    self.videoDisplaySize = size
                }

                self.scrollView.maximumZoomScale = self.calculateMaxZoomScale()
                self.updateVideoLayout()

            }
        }
    }

    /// 최대 줌 스케일 계산
    private func calculateMaxZoomScale() -> CGFloat {
        let containerSize = scrollView.bounds.size
        guard videoDisplaySize.width > 0, videoDisplaySize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return 4.0
        }

        let fitRatio = min(containerSize.width / videoDisplaySize.width,
                           containerSize.height / videoDisplaySize.height)
        let screenScale = UIScreen.main.scale
        let calculatedScale = screenScale / fitRatio

        return max(4.0, min(calculatedScale, 50.0))
    }

    // MARK: - Layout

    /// 비디오 레이아웃 업데이트
    private func updateVideoLayout() {
        guard videoDisplaySize.width > 0, videoDisplaySize.height > 0 else {
            // 비디오 사이즈 없으면 전체 화면
            playerLayerView.frame = scrollView.bounds
            scrollView.contentSize = scrollView.bounds.size
            return
        }

        let scrollViewSize = scrollView.bounds.size
        guard scrollViewSize.width > 0, scrollViewSize.height > 0 else { return }

        // aspect fit 크기 계산
        let widthRatio = scrollViewSize.width / videoDisplaySize.width
        let heightRatio = scrollViewSize.height / videoDisplaySize.height
        let ratio = min(widthRatio, heightRatio)

        let fitWidth = videoDisplaySize.width * ratio
        let fitHeight = videoDisplaySize.height * ratio

        playerLayerView.frame = CGRect(x: 0, y: 0, width: fitWidth, height: fitHeight)
        scrollView.contentSize = CGSize(width: fitWidth, height: fitHeight)

        updateContentInsetForCentering()
    }

    /// 컨텐츠 중앙 정렬을 위한 inset 업데이트
    private func updateContentInsetForCentering() {
        let scrollViewSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize

        let horizontalInset = max(0, (scrollViewSize.width - contentSize.width) / 2)
        let verticalInset = max(0, (scrollViewSize.height - contentSize.height) / 2)

        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    /// 회전 후 레이아웃 재계산 (줌 스케일 리셋)
    private func recalculateLayoutForRotation() {
        guard videoDisplaySize.width > 0, videoDisplaySize.height > 0 else { return }

        let containerSize = view.bounds.size
        let videoRatio = videoDisplaySize.width / videoDisplaySize.height
        let containerRatio = containerSize.width / containerSize.height

        let fitSize: CGSize
        if videoRatio > containerRatio {
            // 가로가 더 넓은 비디오 → width에 맞춤
            fitSize = CGSize(width: containerSize.width,
                            height: containerSize.width / videoRatio)
        } else {
            // 세로가 더 긴 비디오 → height에 맞춤
            fitSize = CGSize(width: containerSize.height * videoRatio,
                            height: containerSize.height)
        }

        // 레이아웃 업데이트
        playerLayerView.frame = CGRect(origin: .zero, size: fitSize)
        scrollView.contentSize = fitSize

        // 중앙 정렬
        let hInset = max(0, (containerSize.width - fitSize.width) / 2)
        let vInset = max(0, (containerSize.height - fitSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: vInset, left: hInset,
                                               bottom: vInset, right: hInset)

        // 회전 시 줌 리셋 (1x로 복귀)
        scrollView.zoomScale = 1.0
        scrollView.contentOffset = CGPoint(x: -hInset, y: -vInset)

        // maxZoomScale 재계산
        scrollView.maximumZoomScale = calculateMaxZoomScale()

    }

    // MARK: - Double Tap Zoom

    /// 더블탭 제스처 처리
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let location = gesture.location(in: playerLayerView)
            let zoomRect = CGRect(
                x: location.x - (scrollView.bounds.width / Self.doubleTapZoomScale / 2),
                y: location.y - (scrollView.bounds.height / Self.doubleTapZoomScale / 2),
                width: scrollView.bounds.width / Self.doubleTapZoomScale,
                height: scrollView.bounds.height / Self.doubleTapZoomScale
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }

    // MARK: - Error Handling

    /// 에러 표시
    private func showError(_ message: String) {
        playerLayerView.loadingIndicator.stopAnimating()
        errorLabel.text = message
        errorLabel.isHidden = false

    }

    // MARK: - Cleanup

    /// 플레이어 정리
    private func cleanupPlayer() {
        removeKVO()
        controlsOverlay.cleanup()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerLayerView.player = nil
        player = nil
        hasShownFirstFrame = false
    }

    // MARK: - Public API

    /// 줌 상태 확인
    var isZoomed: Bool {
        scrollView.zoomScale > 1.0
    }

    /// 재생 시작
    func play(muted: Bool = true) {
        guard let player = player else { return }

        player.isMuted = muted
        player.play()
        controlsOverlay.updatePlayPauseState(isPlaying: true)
        controlsOverlay.updateMuteState(isMuted: muted)

    }

    /// 재생 일시정지
    func pause() {
        player?.pause()
        controlsOverlay.updatePlayPauseState(isPlaying: false)

    }

    /// 재생 정지 및 처음으로 이동
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        controlsOverlay.updatePlayPauseState(isPlaying: false)

    }

    /// 자동 재생 비활성화
    func disableAutoPlay() {
        shouldAutoPlay = false
    }
}

// MARK: - UIScrollViewDelegate

extension VideoPageViewController: UIScrollViewDelegate {

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return playerLayerView
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        isZoomInteractionActive = true
        // 줌 시작 시 컨트롤 숨김
        controlsOverlay.hide(animated: true)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateContentInsetForCentering()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        isZoomInteractionActive = false
    }
}

// MARK: - UIGestureRecognizerDelegate

extension VideoPageViewController: UIGestureRecognizerDelegate {

    // Note: UIScrollView의 내장 panGestureRecognizer.delegate는 변경 불가
    // 페이지 스와이프 충돌은 UIPageViewController가 자동 처리
    // (zoomScale=1일 때 scrollView가 스크롤할 내용이 없으므로 페이지 스와이프로 전달됨)
}

// MARK: - VideoControlsOverlayDelegate

extension VideoPageViewController: VideoControlsOverlayDelegate {

    /// 재생 요청
    func controlsDidRequestPlay() {
        guard let player = player else { return }

        player.play()
        controlsOverlay.updatePlayPauseState(isPlaying: true)

    }

    /// 일시정지 요청
    func controlsDidRequestPause() {
        guard let player = player else { return }

        player.pause()
        controlsOverlay.updatePlayPauseState(isPlaying: false)

    }

    /// 시킹 요청
    func controlsDidRequestSeek(to time: CMTime) {
        guard let player = player else { return }

        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)

    }

    /// 음소거 토글 요청
    func controlsDidRequestMute(_ muted: Bool) {
        guard let player = player else { return }

        player.isMuted = muted
        controlsOverlay.updateMuteState(isMuted: muted)

    }
}

// MARK: - ZoomableImageProviding (커스텀 줌 트랜지션)

extension VideoPageViewController: ZoomableImageProviding {

    /// 줌 애니메이션 대상 이미지 뷰 (포스터 이미지)
    /// - 비디오는 AVPlayerLayer를 사용하므로 포스터 이미지를 대상으로 함
    var zoomableImageView: UIImageView? { playerLayerView.posterImageView }

    /// 현재 줌 스케일 (1.0 = 기본)
    var zoomScale: CGFloat { scrollView.zoomScale }

    /// 스크롤이 상단 가장자리인지 (dismiss 허용 판단용)
    var isAtTopEdge: Bool {
        scrollView.contentOffset.y <= -scrollView.contentInset.top + 1
    }
}
