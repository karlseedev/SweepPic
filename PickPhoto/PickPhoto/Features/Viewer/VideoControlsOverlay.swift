// VideoControlsOverlay.swift
// 비디오 플레이어 컨트롤 오버레이 UI
//
// Phase 10: VideoControlsOverlay 생성 (2차 구현)
// - 재생/일시정지 버튼 (좌측)
// - 음소거 버튼 (우측)
// - 타임라인 슬라이더 (비디오 영역 하단)
// - 재생 중 3초 후 자동 숨김
// - 탭으로 컨트롤 표시/숨김 토글

import UIKit
import AVFoundation

// MARK: - VideoControlsOverlayDelegate

/// VideoControlsOverlay 델리게이트
/// 재생/일시정지 상태 변경 시 호출
protocol VideoControlsOverlayDelegate: AnyObject {
    /// 재생 요청
    func controlsDidRequestPlay()

    /// 일시정지 요청
    func controlsDidRequestPause()

    /// 시킹 요청
    /// - Parameter time: 이동할 시간
    func controlsDidRequestSeek(to time: CMTime)

    /// 음소거 토글 요청
    /// - Parameter muted: 음소거 여부
    func controlsDidRequestMute(_ muted: Bool)
}

// MARK: - VideoControlsOverlay

/// 비디오 플레이어 컨트롤 오버레이 UI
/// - 재생/일시정지, 음소거, 타임라인 슬라이더
/// - 재생 중 3초 후 자동 숨김
/// - 화면 탭으로 표시/숨김 토글
final class VideoControlsOverlay: UIView {

    // MARK: - Constants

    /// 버튼 크기
    private static let buttonSize: CGFloat = 22

    /// 타임라인 높이
    private static let timelineHeight: CGFloat = 4

    /// 좌우 여백
    private static let horizontalPadding: CGFloat = 16

    /// 하단 여백 (Safe Area 위)
    private static let bottomPadding: CGFloat = 56

    /// 버튼과 타임라인 간격
    private static let buttonTimelineSpacing: CGFloat = 8

    /// 자동 숨김 지연 시간
    private static let autoHideDelay: TimeInterval = 3.0

    /// 페이드 애니메이션 시간
    private static let fadeAnimationDuration: TimeInterval = 0.25

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: VideoControlsOverlayDelegate?

    /// 플레이어 참조 (약한 참조)
    private weak var player: AVPlayer?

    /// 타임 옵저버 토큰
    private var timeObserver: Any?

    /// 자동 숨김 타이머
    private var hideTimer: Timer?

    /// 컨트롤 표시 여부
    private(set) var isVisible: Bool = true

    /// 슬라이더 드래그 중 여부
    private var isSliderDragging: Bool = false

    /// 스크러빙 전 재생 상태 (드래그 종료 후 복원용)
    private var wasPlayingBeforeScrubbing: Bool = false

    /// 재생 중 여부 (UI 업데이트용)
    private var isPlaying: Bool = false

    /// 음소거 여부 (UI 업데이트용)
    private var isMuted: Bool = true


    // MARK: - UI Components

    /// 컨트롤 컨테이너 (버튼 + 타임라인)
    private lazy var controlsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 재생/일시정지 버튼 (좌측)
    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // SF Symbol 설정
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let image = UIImage(systemName: "play.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white

        // 그림자 효과
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 2
        button.layer.shadowOpacity = 0.5

        button.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 음소거 버튼 (우측)
    private lazy var muteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // SF Symbol 설정 (기본: 음소거)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let image = UIImage(systemName: "speaker.slash.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white

        // 그림자 효과
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 2
        button.layer.shadowOpacity = 0.5

        button.addTarget(self, action: #selector(muteButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 타임라인 슬라이더
    private lazy var timelineSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false

        // 스타일 설정
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)

        // 썸 이미지 (작은 원)
        let thumbSize: CGFloat = 12
        let thumbImage = createThumbImage(size: thumbSize, color: .white)
        slider.setThumbImage(thumbImage, for: .normal)
        slider.setThumbImage(thumbImage, for: .highlighted)

        // 이벤트
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchDown), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside])

        return slider
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cleanup()
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        // 터치 이벤트 전달을 위해 배경 투명
        backgroundColor = .clear

        // 컨트롤 컨테이너 추가
        addSubview(controlsContainer)

        // 버튼 추가
        controlsContainer.addSubview(playPauseButton)
        controlsContainer.addSubview(muteButton)
        controlsContainer.addSubview(timelineSlider)

        // 레이아웃 설정
        setupConstraints()
    }

    /// 제약조건 설정
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 컨트롤 컨테이너: 하단 Safe Area 위
            controlsContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            controlsContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            controlsContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -Self.bottomPadding),

            // 타임라인 슬라이더: 컨테이너 하단
            timelineSlider.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            timelineSlider.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            timelineSlider.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor),
            timelineSlider.heightAnchor.constraint(equalToConstant: Self.buttonSize), // 터치 영역 확보

            // 재생/일시정지 버튼: 슬라이더 위, 좌측
            playPauseButton.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            playPauseButton.bottomAnchor.constraint(equalTo: timelineSlider.topAnchor, constant: -Self.buttonTimelineSpacing),
            playPauseButton.widthAnchor.constraint(equalToConstant: Self.buttonSize),
            playPauseButton.heightAnchor.constraint(equalToConstant: Self.buttonSize),
            playPauseButton.topAnchor.constraint(equalTo: controlsContainer.topAnchor),

            // 음소거 버튼: 슬라이더 위, 우측
            muteButton.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            muteButton.bottomAnchor.constraint(equalTo: timelineSlider.topAnchor, constant: -Self.buttonTimelineSpacing),
            muteButton.widthAnchor.constraint(equalToConstant: Self.buttonSize),
            muteButton.heightAnchor.constraint(equalToConstant: Self.buttonSize),
        ])
    }

    /// 슬라이더 썸 이미지 생성
    private func createThumbImage(size: CGFloat, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            color.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
        }
    }

    // MARK: - Public API

    /// 플레이어 연결
    /// - Parameter player: AVPlayer 인스턴스
    func configure(with player: AVPlayer) {
        self.player = player

        // 초기 상태 업데이트
        updatePlayPauseButton(isPlaying: player.timeControlStatus == .playing)
        updateMuteButton(isMuted: player.isMuted)

        // 타임 옵저버 설정
        setupTimeObserver()

        // 총 시간 설정
        updateDuration()

        Log.debug("VideoControls", "configured with player")
    }

    /// 재생 상태 업데이트
    /// - Parameter isPlaying: 재생 중 여부
    func updatePlayPauseState(isPlaying: Bool) {
        self.isPlaying = isPlaying
        updatePlayPauseButton(isPlaying: isPlaying)

        // 재생 시작 시 자동 숨김 타이머 시작
        if isPlaying {
            startAutoHideTimer()
        } else {
            cancelAutoHideTimer()
        }
    }

    /// 음소거 상태 업데이트
    /// - Parameter isMuted: 음소거 여부
    func updateMuteState(isMuted: Bool) {
        self.isMuted = isMuted
        updateMuteButton(isMuted: isMuted)
    }

    /// 컨트롤 표시
    /// - Parameter animated: 애니메이션 여부
    func show(animated: Bool = true) {
        guard !isVisible else { return }
        isVisible = true

        Log.debug("VideoControls", "show")

        let duration = animated ? Self.fadeAnimationDuration : 0
        UIView.animate(withDuration: duration) {
            self.controlsContainer.alpha = 1
        }

        // 재생 중이면 자동 숨김 타이머 시작
        if isPlaying {
            startAutoHideTimer()
        }
    }

    /// 컨트롤 숨김
    /// - Parameter animated: 애니메이션 여부
    func hide(animated: Bool = true) {
        guard isVisible else { return }
        isVisible = false

        Log.debug("VideoControls", "hide")

        cancelAutoHideTimer()

        let duration = animated ? Self.fadeAnimationDuration : 0
        UIView.animate(withDuration: duration) {
            self.controlsContainer.alpha = 0
        }
    }

    /// 컨트롤 표시/숨김 토글
    func toggle() {
        if isVisible {
            hide(animated: true)
        } else {
            show(animated: true)
        }
    }

    /// 정리
    func cleanup() {
        cancelAutoHideTimer()
        removeTimeObserver()
        player = nil

        Log.debug("VideoControls", "cleanup")
    }

    // MARK: - Time Observer

    /// 타임 옵저버 설정
    private func setupTimeObserver() {
        guard let player = player else { return }

        // 기존 옵저버 제거
        removeTimeObserver()

        // 0.5초 간격으로 진행률 업데이트
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self,
                  !self.isSliderDragging else { return }

            let seconds = CMTimeGetSeconds(time)
            self.timelineSlider.value = Float(seconds)
        }

        Log.debug("VideoControls", "timeObserver setup")
    }

    /// 타임 옵저버 제거
    private func removeTimeObserver() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil

            Log.debug("VideoControls", "timeObserver removed")
        }
    }

    /// 총 시간 설정
    private func updateDuration() {
        guard let player = player,
              let duration = player.currentItem?.duration,
              duration.isNumeric else {
            // duration이 아직 로드되지 않은 경우 옵저버 설정
            setupDurationObserver()
            return
        }

        let durationSeconds = CMTimeGetSeconds(duration)
        timelineSlider.minimumValue = 0
        timelineSlider.maximumValue = Float(durationSeconds)

        Log.debug("VideoControls", "duration set: \(durationSeconds)s")
    }

    /// Duration 로드 완료 옵저버 설정
    private func setupDurationObserver() {
        guard let asset = player?.currentItem?.asset else { return }

        // duration이 로드되면 업데이트 (iOS 16+ async/await)
        Task { [weak self] in
            do {
                _ = try await asset.load(.duration)
                await MainActor.run {
                    self?.updateDuration()
                }
            } catch {
                // duration 로드 실패는 치명적이지 않으므로 무시
            }
        }
    }

    // MARK: - Auto Hide Timer

    /// 자동 숨김 타이머 시작
    private func startAutoHideTimer() {
        cancelAutoHideTimer()

        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.autoHideDelay, repeats: false) { [weak self] _ in
            guard let self = self,
                  self.isPlaying,
                  !self.isSliderDragging else { return }

            self.hide(animated: true)
        }

        Log.debug("VideoControls", "autoHideTimer started")
    }

    /// 자동 숨김 타이머 취소
    private func cancelAutoHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    // MARK: - UI Updates

    /// 재생/일시정지 버튼 업데이트
    private func updatePlayPauseButton(isPlaying: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        let image = UIImage(systemName: imageName, withConfiguration: config)
        playPauseButton.setImage(image, for: .normal)
    }

    /// 음소거 버튼 업데이트
    private func updateMuteButton(isMuted: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let imageName = isMuted ? "speaker.slash.fill" : "speaker.fill"
        let image = UIImage(systemName: imageName, withConfiguration: config)
        muteButton.setImage(image, for: .normal)
    }

    // MARK: - Actions

    /// 재생/일시정지 버튼 탭
    @objc private func playPauseButtonTapped() {
        if isPlaying {
            delegate?.controlsDidRequestPause()
        } else {
            delegate?.controlsDidRequestPlay()
        }

        // 자동 숨김 타이머 리셋
        if isPlaying {
            startAutoHideTimer()
        }
    }

    /// 음소거 버튼 탭
    @objc private func muteButtonTapped() {
        let newMutedState = !isMuted
        delegate?.controlsDidRequestMute(newMutedState)

        // 자동 숨김 타이머 리셋
        startAutoHideTimer()
    }

    /// 슬라이더 값 변경 (드래그 중 실시간 스크러빙)
    @objc private func sliderValueChanged(_ slider: UISlider) {
        let seconds = Double(slider.value)
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        delegate?.controlsDidRequestSeek(to: time)
    }

    /// 슬라이더 터치 시작
    @objc private func sliderTouchDown() {
        isSliderDragging = true
        cancelAutoHideTimer()

        // 스크러빙 시작 시 재생 상태 저장 후 일시정지
        wasPlayingBeforeScrubbing = isPlaying
        if isPlaying {
            delegate?.controlsDidRequestPause()
        }

        Log.debug("VideoControls", "slider drag started, wasPlaying: \(wasPlayingBeforeScrubbing)")
    }

    /// 슬라이더 터치 종료
    @objc private func sliderTouchUp() {
        isSliderDragging = false

        // 최종 위치로 seek
        let seconds = Double(timelineSlider.value)
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        delegate?.controlsDidRequestSeek(to: time)

        // 스크러빙 전 재생 중이었으면 재생 재개
        if wasPlayingBeforeScrubbing {
            delegate?.controlsDidRequestPlay()
            startAutoHideTimer()
        }

        Log.debug("VideoControls", "slider drag ended, seek to: \(seconds)s, resumePlay: \(wasPlayingBeforeScrubbing)")
    }

    // MARK: - Hit Test

    /// 터치 이벤트 처리
    /// - 컨트롤 영역만 터치 처리, 나머지는 통과
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 컨트롤 컨테이너 영역 확인
        let containerPoint = convert(point, to: controlsContainer)

        // 버튼 또는 슬라이더에 해당하면 처리
        if playPauseButton.frame.contains(containerPoint) {
            return playPauseButton
        }
        if muteButton.frame.contains(containerPoint) {
            return muteButton
        }
        if timelineSlider.frame.contains(containerPoint) {
            return timelineSlider
        }

        // 그 외 영역은 터치 통과 (nil 반환)
        return nil
    }
}
