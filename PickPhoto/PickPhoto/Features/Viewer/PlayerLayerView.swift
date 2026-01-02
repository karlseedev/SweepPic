// PlayerLayerView.swift
// AVPlayerLayer를 layerClass로 사용하는 뷰
//
// Phase 1: PlayerLayerView 생성
// - layerClass override로 AVPlayerLayer 자동 동기화
// - 포스터 이미지 오버레이 내장
// - 로딩 인디케이터 내장

import UIKit
import AVFoundation

/// AVPlayerLayer를 layerClass로 사용하는 뷰
/// - 레이어 프레임이 view.bounds와 자동 동기화
/// - 포스터 이미지 오버레이 내장
/// - 로딩 인디케이터 내장
final class PlayerLayerView: UIView {

    // MARK: - Layer Class

    /// AVPlayerLayer를 기본 레이어로 사용
    /// - CATransaction 불필요, 프레임 자동 동기화
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    /// 타입 캐스팅된 AVPlayerLayer 접근자
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    /// AVPlayer 접근자 (playerLayer.player의 래퍼)
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    // MARK: - Poster Image

    /// 포스터 이미지 뷰
    /// - 비디오 로딩 중 표시
    /// - isReadyForDisplay 후 fade-out
    private(set) lazy var posterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = .clear
        return iv
    }()

    // MARK: - Loading Indicator

    /// 로딩 인디케이터
    /// - iCloud 다운로드 등 비디오 로딩 중 표시
    private(set) lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    /// UI 초기 설정
    private func setupUI() {
        backgroundColor = .black

        // AVPlayerLayer 기본 설정
        playerLayer.videoGravity = .resizeAspect

        // 포스터 이미지 뷰 추가
        addSubview(posterImageView)

        // 로딩 인디케이터 추가
        addSubview(loadingIndicator)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // 포스터 이미지: 전체 bounds
        posterImageView.frame = bounds

        // 로딩 인디케이터: 중앙
        loadingIndicator.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Poster API

    /// 포스터 이미지 설정
    /// - Parameter image: 표시할 이미지 (nil이면 숨김)
    func setPoster(_ image: UIImage?) {
        posterImageView.image = image
        posterImageView.alpha = 1
    }

    /// 포스터 이미지 숨김 (fade-out)
    /// - Parameter animated: 애니메이션 여부
    func hidePoster(animated: Bool = true) {
        let duration = animated ? 0.2 : 0
        UIView.animate(withDuration: duration) {
            self.posterImageView.alpha = 0
        }
    }

    /// 포스터 이미지 표시
    func showPoster() {
        posterImageView.alpha = 1
    }

    // MARK: - Reset

    /// 뷰 상태 리셋
    /// - 포스터 표시, 플레이어 해제
    func reset() {
        player = nil
        posterImageView.alpha = 1
        posterImageView.image = nil
        loadingIndicator.stopAnimating()
    }
}
