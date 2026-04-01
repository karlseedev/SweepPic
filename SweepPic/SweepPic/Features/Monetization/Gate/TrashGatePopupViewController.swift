//
//  TrashGatePopupViewController.swift
//  SweepPic
//
//  게이트 팝업 UI — present(.overFullScreen) + animator 블러
//  UIViewPropertyAnimator로 블러 강도를 조절하여 뒤 콘텐츠 투과
//
//  버튼 구성 (반투명 흰색 배경, 44pt 통일):
//  - 광고 버튼: "광고 N회 보고 X장 전체 삭제" (Ready/Loading/Failed 3상태, 흰색 텍스트)
//  - Pro 버튼: "Pro로 무제한" (흰색 텍스트)
//  - 닫기 버튼 (회색 텍스트)
//
//  오프라인 시: 광고/구독 비활성 + "인터넷 연결 필요" (FR-055)
//  리워드 소진 시: 골든 모먼트 (Pro 전환 유도, FR-014)
//

import UIKit
import AppCore
import Network
import OSLog

// MARK: - AdButtonState

/// 광고 버튼 3상태 (FR-018)
enum AdButtonState {
    case ready      // 광고 준비됨 — 활성
    case loading    // 광고 로딩 중 — 스피너
    case failed     // 광고 실패 — 비활성 + 안내
}

// MARK: - TrashGatePopupViewController

/// 게이트 블러 팝업 — present(.overFullScreen)
/// UIViewPropertyAnimator로 블러 강도 조절 (뒤 콘텐츠 투과)
final class TrashGatePopupViewController: UIViewController {

    // MARK: - Callbacks

    /// 광고 시청 선택 시
    var onAdWatch: (() -> Void)?
    /// Pro 업그레이드 선택 시
    var onProUpgrade: (() -> Void)?
    /// 닫기 선택 시
    var onDismiss: (() -> Void)?

    // MARK: - Data

    /// 삭제 대상 수
    private let trashCount: Int
    /// 남은 기본 무료 삭제 수
    private let remainingFreeDeletes: Int
    /// 필요한 광고 수 (-1이면 광고로도 부족)
    private let adsNeeded: Int
    /// 남은 리워드 가능 횟수
    private let remainingRewards: Int

    // MARK: - State

    /// 네트워크 연결 모니터
    private let networkMonitor = NWPathMonitor()
    /// 현재 온라인 상태
    private var isOnline = true

    // MARK: - UI Components

    /// 배경 블러 (딤드 위에 10% 강도 블러)
    private let backgroundBlurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 블러 강도 제어용 애니메이터
    private lazy var blurAnimator: UIViewPropertyAnimator = {
        let animator = UIViewPropertyAnimator(duration: 0, curve: .linear) { [weak self] in
            self?.backgroundBlurView.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        animator.fractionComplete = 0.1
        animator.pausesOnCompletion = true
        return animator
    }()

    /// 블러 팝업 카드 (재사용 컴포넌트)
    private let cardView = BlurPopupCardView()

    /// 제목 라벨 — 흰색 텍스트
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "무료 삭제 한도 초과"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 안내 라벨 (장수 + 한도 정보) — 반투명 흰색
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 광고 버튼 — 반투명 흰색 배경 + 흰색 텍스트
    private let adButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 광고 버튼 내부 스피너 (Loading 상태용)
    private let adSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    /// Pro 버튼 — 반투명 흰색 배경 + 흰색 텍스트
    private let proButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitle("Pro 멤버십으로 무제한 삭제", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 닫기 버튼 — 반투명 흰색 배경 + 회색 텍스트
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitle("닫기", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 골든 모먼트 안내 라벨 (리워드 소진 시, FR-014)
    private let goldenMomentLabel: UILabel = {
        let label = UILabel()
        label.text = "오늘 광고 횟수를 모두 사용했습니다"
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemOrange
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 오프라인 안내 라벨 (FR-055)
    private let offlineLabel: UILabel = {
        let label = UILabel()
        label.text = "인터넷 연결이 필요합니다"
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .systemRed
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Referral Promo (T032, US4)

    /// 초대 프로모 하단 배경 — 카드 하단을 가로로 잘라 색상 차별화
    /// cardView.contentView에 삽입하여 카드의 clipsToBounds로 하단 모서리 자동 처리
    private let referralPromoBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 초대 프로모 안내 라벨
    private let referralPromoLabel: UILabel = {
        let label = UILabel()
        label.text = "초대 한 번마다 나도 친구도\nPro 멤버십 14일 무료 제공!"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 초대하기 버튼 — 다른 버튼과 동일 높이 50pt, cornerRadius 25
    private let referralButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        button.setTitle("친구 초대하기", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 초대 부가 문구: "이미 Pro멤버십 이용 중이어도 14일 무료 연장"
    private let referralSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "이미 Pro멤버십 이용 중이어도 14일 무료 연장"
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.4)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Init

    init(trashCount: Int, remainingFreeDeletes: Int, adsNeeded: Int, remainingRewards: Int) {
        self.trashCount = trashCount
        self.remainingFreeDeletes = remainingFreeDeletes
        self.adsNeeded = adsNeeded
        self.remainingRewards = remainingRewards
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        setupUI()
        _ = blurAnimator // 블러 10% 적용
        setupBlurAnimator()
        setupActions()
        setupAccessibility()
        configureContent()
        startNetworkMonitoring()
    }

    /// 블러 효과 활성화
    private func setupBlurAnimator() {
        cardView.activateBlur()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - UI Setup

    /// UI 레이아웃 구성 — 딤 + 블러 카드 + Glass 버튼
    private func setupUI() {
        // 배경 블러
        view.addSubview(backgroundBlurView)
        NSLayoutConstraint.activate([
            backgroundBlurView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 블러 카드 — 화면 - 48pt 너비
        view.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        // T032: 카드 하단 배경 — contentView에 먼저 삽입 (스택뷰 뒤에 깔림)
        cardView.contentView.addSubview(referralPromoBackground)

        // 카드 내부 스택뷰 — contentView에 추가 (블러 위)
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel, infoLabel,
            goldenMomentLabel, offlineLabel,
            adButton, proButton, closeButton,
            referralPromoLabel, referralButton, referralSubtitleLabel
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // 버튼 영역 전 여유 간격
        stackView.setCustomSpacing(28, after: offlineLabel)
        stackView.setCustomSpacing(12, after: adButton)
        stackView.setCustomSpacing(10, after: proButton)

        cardView.contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 36),
            stackView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 28),
            stackView.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -28),
            stackView.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -32)
        ])

        // 버튼 높이
        NSLayoutConstraint.activate([
            adButton.heightAnchor.constraint(equalToConstant: 50),
            proButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // T032: 닫기 버튼과 초대 프로모 간격 (배경 색상 변경 시작점 여유 15pt 포함)
        stackView.setCustomSpacing(34, after: closeButton)
        stackView.setCustomSpacing(8, after: referralPromoLabel)
        stackView.setCustomSpacing(4, after: referralButton)

        // 버튼 높이 (다른 버튼과 동일)
        referralButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        // T032: 배경 뷰 — 프로모 라벨 위에서 카드 하단 끝까지 채움
        // cardView의 clipsToBounds가 하단 둥근 모서리 자동 처리
        NSLayoutConstraint.activate([
            referralPromoBackground.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor),
            referralPromoBackground.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor),
            referralPromoBackground.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor),
            referralPromoBackground.topAnchor.constraint(equalTo: referralPromoLabel.topAnchor, constant: -16)
        ])

        // 광고 버튼 내부 스피너
        adButton.addSubview(adSpinner)
        NSLayoutConstraint.activate([
            adSpinner.centerXAnchor.constraint(equalTo: adButton.centerXAnchor),
            adSpinner.centerYAnchor.constraint(equalTo: adButton.centerYAnchor)
        ])
    }

    // MARK: - Actions

    /// 버튼 액션 연결
    private func setupActions() {
        adButton.addTarget(self, action: #selector(adButtonTapped), for: .touchUpInside)
        proButton.addTarget(self, action: #selector(proButtonTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        // T032: 초대 프로모 버튼 액션
        referralButton.addTarget(self, action: #selector(referralButtonTapped), for: .touchUpInside)

        // 배경 탭 → 닫기
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(closeButtonTapped))
        view.addGestureRecognizer(dimTap)
    }

    @objc private func adButtonTapped() {
        Logger.app.debug("TrashGatePopup: 광고 버튼 탭")
        blurAnimator.stopAnimation(true)
        dismiss(animated: true) { [weak self] in
            self?.onAdWatch?()
        }
    }

    @objc private func proButtonTapped() {
        Logger.app.debug("TrashGatePopup: Pro 버튼 탭")
        blurAnimator.stopAnimation(true)
        dismiss(animated: true) { [weak self] in
            self?.onProUpgrade?()
        }
    }

    @objc private func closeButtonTapped() {
        Logger.app.debug("TrashGatePopup: 닫기 버튼 탭")
        blurAnimator.stopAnimation(true)
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    /// T032: 초대 프로모 버튼 탭 → ReferralExplainViewController 모달
    @objc private func referralButtonTapped() {
        Logger.app.debug("TrashGatePopup: 초대 프로모 버튼 탭")
        blurAnimator.stopAnimation(true)
        let presenter = presentingViewController
        dismiss(animated: true) {
            guard let presenter = presenter else { return }
            let referralVC = ReferralExplainViewController()
            presenter.present(referralVC, animated: true)
        }
    }

    // MARK: - Content Configuration

    /// 데이터 기반 콘텐츠 구성
    private func configureContent() {
        infoLabel.text = "삭제할 사진 \(trashCount)장 · 무료 삭제 가능 \(remainingFreeDeletes)장"

        let isRewardExhausted = remainingRewards <= 0

        if isRewardExhausted {
            // 리워드 4회 소진 → 골든 모먼트 (FR-014, T024)
            configureGoldenMoment()
        } else if adsNeeded > 0 {
            let adText = "광고 \(adsNeeded)회 보고 \(trashCount)장 전체 삭제"
            adButton.setTitle(adText, for: .normal)
            // AdManager 로드 상태에 따라 버튼 초기 상태 결정
            if AdManager.shared.isRewardedAdReady {
                updateAdButtonState(.ready)
            } else {
                // 광고 미로드 → Loading 상태 + 사전 로드 시작
                updateAdButtonState(.loading)
                AdManager.shared.preloadRewardedAd()
                pollAdReadyState(adText: adText)
            }
        } else {
            adButton.isHidden = true
        }
    }

    /// 골든 모먼트 UI 구성 (FR-014)
    private func configureGoldenMoment() {
        adButton.isHidden = true
        goldenMomentLabel.isHidden = false
        Logger.app.debug("TrashGatePopup: 골든 모먼트 — 리워드 소진, Pro 전환 유도")
    }

    // MARK: - Ad Button State

    /// 광고 버튼 상태 업데이트 (Ready/Loading/Failed)
    func updateAdButtonState(_ state: AdButtonState) {
        switch state {
        case .ready:
            adButton.isEnabled = true
            adButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
            adSpinner.stopAnimating()

        case .loading:
            adButton.isEnabled = false
            adButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
            adButton.setTitle("", for: .normal)
            adSpinner.startAnimating()

        case .failed:
            adButton.isEnabled = false
            adButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
            adButton.setTitle("광고를 불러올 수 없습니다", for: .normal)
            adSpinner.stopAnimating()
        }
    }

    // MARK: - Ad Ready Polling

    /// 광고 로드 완료 폴링 (0.5초 간격, 최대 10초)
    /// 팝업이 표시된 상태에서 광고가 로드될 때까지 대기
    private var adPollCount = 0
    private static let maxAdPollCount = 20 // 0.5초 × 20 = 10초

    /// 광고 로드 완료 대기 폴링
    private func pollAdReadyState(adText: String) {
        adPollCount = 0
        doPollAdReady(adText: adText)
    }

    /// 실제 폴링 실행 (재귀)
    private func doPollAdReady(adText: String) {
        guard adPollCount < Self.maxAdPollCount else {
            // 10초 대기 초과 → Failed 상태
            updateAdButtonState(.failed)
            Logger.app.debug("TrashGatePopup: 광고 로드 대기 타임아웃 (10초)")
            return
        }

        adPollCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if AdManager.shared.isRewardedAdReady {
                // 로드 완료 → Ready 상태
                self.adButton.setTitle(adText, for: .normal)
                self.updateAdButtonState(.ready)
                Logger.app.debug("TrashGatePopup: 광고 로드 완료 — Ready 전환")
            } else {
                // 계속 대기
                self.doPollAdReady(adText: adText)
            }
        }
    }

    // MARK: - Network Monitoring (FR-055)

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? true
                self?.isOnline = (path.status == .satisfied)
                if wasOnline != self?.isOnline {
                    self?.updateOfflineState()
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))

        // 초기 네트워크 상태 즉시 반영 (race condition 방지)
        isOnline = (networkMonitor.currentPath.status == .satisfied)
        updateOfflineState()
    }

    /// 오프라인 상태 UI 업데이트 (FR-055)
    private func updateOfflineState() {
        if isOnline {
            offlineLabel.isHidden = true
            adButton.isEnabled = true
            adButton.alpha = 1.0
            proButton.isEnabled = true
            proButton.alpha = 1.0
            configureContent()
        } else {
            offlineLabel.isHidden = false
            adButton.isEnabled = false
            adButton.alpha = 0.35
            proButton.isEnabled = false
            proButton.alpha = 0.35
        }
    }

    // MARK: - Accessibility (FR-057)

    private func setupAccessibility() {
        cardView.accessibilityLabel = "삭제대기함 비우기 안내"
        cardView.isAccessibilityElement = false
        cardView.accessibilityElements = [
            titleLabel, infoLabel, goldenMomentLabel,
            offlineLabel, adButton, proButton, closeButton,
            referralPromoLabel, referralButton, referralSubtitleLabel
        ]
        titleLabel.accessibilityTraits = .header
        infoLabel.accessibilityLabel = "삭제할 사진 \(trashCount)장, 무료 삭제 가능 \(remainingFreeDeletes)장"
        adButton.accessibilityLabel = "광고를 보고 사진 삭제하기"
        adButton.accessibilityHint = "광고를 시청한 후 사진을 삭제합니다"
        proButton.accessibilityLabel = "Pro멤버십으로 무제한 삭제"
        proButton.accessibilityHint = "Pro멤버십 안내 화면으로 이동합니다"
        closeButton.accessibilityLabel = "닫기"
        closeButton.accessibilityHint = "팝업을 닫습니다"
        goldenMomentLabel.accessibilityLabel = "오늘 광고 횟수를 모두 사용했습니다"
        offlineLabel.accessibilityLabel = "인터넷 연결이 필요합니다"
        // T032: 초대 프로모 접근성
        referralPromoLabel.accessibilityLabel = "초대 한 번마다 나도 친구도 Pro 멤버십 14일 무료 제공"
        referralButton.accessibilityLabel = "친구 초대하기"
        referralButton.accessibilityHint = "초대 설명 화면으로 이동합니다"
        referralSubtitleLabel.accessibilityLabel = "이미 Pro멤버십 이용 중이어도 14일 무료 연장"
    }
}
