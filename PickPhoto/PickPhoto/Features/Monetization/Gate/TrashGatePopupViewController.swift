//
//  TrashGatePopupViewController.swift
//  PickPhoto
//
//  게이트 팝업 UI — present(.overFullScreen) + animator 블러
//  UIViewPropertyAnimator로 블러 강도를 조절하여 뒤 콘텐츠 투과
//
//  버튼 구성:
//  - 광고 버튼: "광고 N회 보고 X장 전체 삭제" (Ready/Loading/Failed 3상태)
//  - Plus 버튼: "Plus로 무제한"
//  - 닫기 버튼
//
//  오프라인 시: 광고/구독 비활성 + "인터넷 연결 필요" (FR-055)
//  리워드 소진 시: 골든 모먼트 (Plus 전환 유도, FR-014)
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
    /// Plus 업그레이드 선택 시
    var onPlusUpgrade: (() -> Void)?
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

    /// 반투명 딤 배경
    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 카드 뒤 어두운 배경 (카드 영역에만 딤)
    private let cardDimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 반투명 블러 카드 — effect는 animator로 부분 적용
    private let cardView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: nil)  // 초기엔 effect 없음
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 블러 강도 제어용 animator (fractionComplete로 0~1 조절)
    private var blurAnimator: UIViewPropertyAnimator?

    /// 제목 라벨 — 흰색 텍스트
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "삭제대기함을 비우려면"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 안내 라벨 (장수 + 한도 정보) — 반투명 흰색
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 광고 버튼 — 흰색 알약형
    private let adButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 26  // 52pt / 2 = 알약형
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 광고 버튼 내부 스피너 (Loading 상태용)
    private let adSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .darkGray
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    /// Plus 버튼 — 흰색 알약형
    private let plusButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.setTitleColor(.black, for: .normal)
        button.setTitle("Plus로 무제한", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 26  // 52pt / 2 = 알약형
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 닫기 버튼 — 흰색 알약형 (통일 스타일, 소형)
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.setTitle("닫기", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.layer.cornerRadius = 22  // 44pt / 2 = 알약형
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
        view.backgroundColor = .clear

        setupUI()
        setupBlurAnimator()
        setupActions()
        setupAccessibility()
        configureContent()
        startNetworkMonitoring()
    }

    /// 블러 강도 animator 설정
    /// fractionComplete로 블러 정도 조절 (0.0 = 투명, 1.0 = 완전 불투명)
    private func setupBlurAnimator() {
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
            self.cardView.effect = UIBlurEffect(style: LiquidGlassStyle.blurStyle)
        }
        animator.fractionComplete = 0.5  // 50% 블러 — 뒤가 비치면서 블러 효과
        animator.pausesOnCompletion = true
        blurAnimator = animator
    }

    deinit {
        blurAnimator?.stopAnimation(true)
        blurAnimator?.finishAnimation(at: .current)
        networkMonitor.cancel()
    }

    // MARK: - UI Setup

    /// UI 레이아웃 구성 — 딤 + 블러 카드 + 흰색 알약 버튼
    private func setupUI() {
        // 딤 배경 (전체 화면)
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 카드 영역 딤 (블러 뒤에 깔림)
        view.addSubview(cardDimView)

        // 블러 카드 — 화면 - 48pt 너비 (딤 위에)
        view.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardDimView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardDimView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardDimView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardDimView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            cardView.topAnchor.constraint(equalTo: cardDimView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: cardDimView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: cardDimView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: cardDimView.bottomAnchor)
        ])

        // 카드 내부 스택뷰 — contentView에 추가 (블러 위)
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel, infoLabel,
            goldenMomentLabel, offlineLabel,
            adButton, plusButton, closeButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // 버튼 영역 전 여유 간격
        stackView.setCustomSpacing(28, after: offlineLabel)
        stackView.setCustomSpacing(12, after: adButton)
        stackView.setCustomSpacing(10, after: plusButton)

        cardView.contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 36),
            stackView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 28),
            stackView.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -28),
            stackView.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -32)
        ])

        // 버튼 높이 — 액션 버튼 52pt, 닫기 44pt
        NSLayoutConstraint.activate([
            adButton.heightAnchor.constraint(equalToConstant: 52),
            plusButton.heightAnchor.constraint(equalToConstant: 52),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
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
        plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        // 딤 배경 탭 → 닫기
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(closeButtonTapped))
        dimView.addGestureRecognizer(dimTap)
    }

    @objc private func adButtonTapped() {
        Logger.app.debug("TrashGatePopup: 광고 버튼 탭")
        dismiss(animated: true) { [weak self] in
            self?.onAdWatch?()
        }
    }

    @objc private func plusButtonTapped() {
        Logger.app.debug("TrashGatePopup: Plus 버튼 탭")
        dismiss(animated: true) { [weak self] in
            self?.onPlusUpgrade?()
        }
    }

    @objc private func closeButtonTapped() {
        Logger.app.debug("TrashGatePopup: 닫기 버튼 탭")
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    // MARK: - Content Configuration

    /// 데이터 기반 콘텐츠 구성
    private func configureContent() {
        infoLabel.text = "\(trashCount)장 · 무료 삭제 한도 \(remainingFreeDeletes)장 남음"

        let isRewardExhausted = remainingRewards <= 0

        if isRewardExhausted {
            configureGoldenMoment()
        } else if adsNeeded > 0 {
            let adText = "광고 \(adsNeeded)회 보고 \(trashCount)장 전체 삭제"
            adButton.setTitle(adText, for: .normal)
            updateAdButtonState(.ready)
        } else {
            adButton.isHidden = true
        }
    }

    /// 골든 모먼트 UI 구성 (FR-014)
    private func configureGoldenMoment() {
        adButton.isHidden = true
        goldenMomentLabel.isHidden = false
        plusButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        Logger.app.debug("TrashGatePopup: 골든 모먼트 — 리워드 소진, Plus 전환 유도")
    }

    // MARK: - Ad Button State

    /// 광고 버튼 상태 업데이트 (Ready/Loading/Failed)
    func updateAdButtonState(_ state: AdButtonState) {
        switch state {
        case .ready:
            adButton.isEnabled = true
            adButton.backgroundColor = .white
            adButton.setTitleColor(.black, for: .normal)
            adSpinner.stopAnimating()

        case .loading:
            adButton.isEnabled = false
            adButton.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            adButton.setTitle("", for: .normal)
            adSpinner.startAnimating()

        case .failed:
            adButton.isEnabled = false
            adButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            adButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
            adButton.setTitle("광고를 불러올 수 없습니다", for: .normal)
            adSpinner.stopAnimating()
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
    }

    /// 오프라인 상태 UI 업데이트 (FR-055)
    private func updateOfflineState() {
        if isOnline {
            offlineLabel.isHidden = true
            adButton.isEnabled = true
            plusButton.isEnabled = true
            configureContent()
        } else {
            offlineLabel.isHidden = false
            adButton.isEnabled = false
            adButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            adButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
            plusButton.isEnabled = false
            plusButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            plusButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        }
    }

    // MARK: - Accessibility (FR-057)

    private func setupAccessibility() {
        cardView.accessibilityLabel = "삭제대기함 비우기 안내"
        cardView.isAccessibilityElement = false
        cardView.accessibilityElements = [
            titleLabel, infoLabel, goldenMomentLabel,
            offlineLabel, adButton, plusButton, closeButton
        ]
        titleLabel.accessibilityTraits = .header
        infoLabel.accessibilityLabel = "\(trashCount)장 삭제 대상, 무료 삭제 한도 \(remainingFreeDeletes)장 남음"
        adButton.accessibilityLabel = "광고를 보고 사진 삭제하기"
        adButton.accessibilityHint = "광고를 시청한 후 사진을 삭제합니다"
        plusButton.accessibilityLabel = "Plus 구독으로 무제한 삭제"
        plusButton.accessibilityHint = "Plus 구독 안내 화면으로 이동합니다"
        closeButton.accessibilityLabel = "닫기"
        closeButton.accessibilityHint = "팝업을 닫습니다"
        goldenMomentLabel.accessibilityLabel = "오늘 광고 횟수를 모두 사용했습니다"
        offlineLabel.accessibilityLabel = "인터넷 연결이 필요합니다"
    }
}
