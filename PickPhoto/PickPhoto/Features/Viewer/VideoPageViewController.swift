// VideoPageViewController.swift
// 개별 동영상을 표시하는 페이지 뷰 컨트롤러
//
// AVPlayerViewController 기반 동영상 재생
// - 자동 재생 (음소거로 시작)
// - 핀치 줌: Aspect Fit ↔ Aspect Fill 토글 (iOS 16+ 기본 지원)
// - iCloud 다운로드 자동 처리

import UIKit
import Photos
import AVKit
import AppCore

// MARK: - VideoPageViewController

/// 개별 동영상을 표시하는 페이지 뷰 컨트롤러
/// AVPlayerViewController 기반 인라인 재생 지원
final class VideoPageViewController: UIViewController {

    // MARK: - Properties

    /// 표시할 PHAsset
    let asset: PHAsset

    /// 인덱스 (페이지 전환 추적용)
    let index: Int

    /// AVPlayerViewController (child VC로 embed)
    private var playerViewController: AVPlayerViewController?

    /// AVPlayer 인스턴스
    private var player: AVPlayer?

    /// 비디오 요청 취소 토큰
    private var requestCancellable: Cancellable?

    /// 자동 재생 활성화 여부
    /// - viewDidAppear에서 true일 때만 자동 재생 시작
    private var shouldAutoPlay = true

    /// 로딩 인디케이터
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    /// 에러 표시 레이블
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

    /// 디버그 로그 활성화
    private let debugVideo = true

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
        requestVideo()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // 자동 재생 시작 (음소거)
        if shouldAutoPlay {
            play(muted: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 페이지 전환 시 정지
        pause()
    }

    deinit {
        // 리소스 정리
        requestCancellable?.cancel()
        player?.pause()
        player = nil

        if debugVideo {
            print("[Video] deinit - index: \(index)")
        }
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        view.backgroundColor = .black

        // 로딩 인디케이터
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // 에러 레이블
        view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }

    /// AVPlayerViewController embed
    private func setupPlayerViewController(with playerItem: AVPlayerItem) {
        // AVPlayer 생성
        let player = AVPlayer(playerItem: playerItem)
        self.player = player

        // 기본 음소거로 시작 (기본 사진 앱 동작)
        player.isMuted = true

        // AVPlayerViewController 생성
        let playerVC = AVPlayerViewController()
        playerVC.player = player

        // 인라인 재생 설정 (전체화면 전환 비활성화)
        playerVC.entersFullScreenWhenPlaybackBegins = false
        playerVC.exitsFullScreenWhenPlaybackEnds = false

        // iOS 16+: 줌 지원 (Aspect Fit ↔ Aspect Fill 토글)
        // AVPlayerViewController 기본 제공 기능

        // Child VC로 추가
        addChild(playerVC)
        view.addSubview(playerVC.view)

        // 오토레이아웃 설정 (회전/세이프에어리어 대응)
        playerVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        playerVC.didMove(toParent: self)
        playerViewController = playerVC

        // 로딩 인디케이터 숨김
        loadingIndicator.stopAnimating()

        if debugVideo {
            print("[Video] Player setup complete - index: \(index)")
        }
    }

    // MARK: - Video Request

    /// 비디오 요청
    private func requestVideo() {
        loadingIndicator.startAnimating()
        errorLabel.isHidden = true

        if debugVideo {
            print("[Video] Requesting video - index: \(index), asset: \(asset.localIdentifier.prefix(8))...")
        }

        // VideoPipeline을 통해 AVPlayerItem 요청
        requestCancellable = VideoPipeline.shared.requestPlayerItem(
            for: asset,
            progressHandler: { [weak self] progress in
                // iCloud 다운로드 진행률 (필요시 UI 표시)
                if self?.debugVideo == true {
                    print("[Video] Download progress: \(Int(progress * 100))%")
                }
            },
            completion: { [weak self] playerItem, info in
                guard let self = self else { return }

                // 에러 처리
                if let error = VideoPipeline.error(from: info) {
                    self.showError(error.localizedDescription)
                    return
                }

                // 취소된 경우
                if VideoPipeline.isCancelled(from: info) {
                    if self.debugVideo {
                        print("[Video] Request cancelled")
                    }
                    return
                }

                // playerItem이 없는 경우
                guard let playerItem = playerItem else {
                    self.showError("동영상을 로드할 수 없습니다")
                    return
                }

                // AVPlayerViewController 설정
                self.setupPlayerViewController(with: playerItem)

                // viewDidAppear가 이미 호출된 경우 자동 재생
                if self.isViewLoaded && self.view.window != nil && self.shouldAutoPlay {
                    self.play(muted: true)
                }
            }
        )
    }

    /// 에러 표시
    private func showError(_ message: String) {
        loadingIndicator.stopAnimating()
        errorLabel.text = message
        errorLabel.isHidden = false

        if debugVideo {
            print("[Video] Error: \(message)")
        }
    }

    // MARK: - Playback Control

    /// 재생 시작
    /// - Parameter muted: 음소거 여부 (기본: true)
    func play(muted: Bool = true) {
        guard let player = player else { return }

        player.isMuted = muted
        player.play()

        if debugVideo {
            print("[Video] Play - muted: \(muted), index: \(index)")
        }
    }

    /// 재생 일시정지
    func pause() {
        player?.pause()

        if debugVideo {
            print("[Video] Pause - index: \(index)")
        }
    }

    /// 재생 정지 및 처음으로 이동
    func stop() {
        player?.pause()
        player?.seek(to: .zero)

        if debugVideo {
            print("[Video] Stop - index: \(index)")
        }
    }

    /// 자동 재생 비활성화
    /// - 페이지 전환 시 이전 페이지의 자동 재생 방지
    func disableAutoPlay() {
        shouldAutoPlay = false
    }
}
