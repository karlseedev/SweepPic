//
//  TrashGatePopupViewController.swift
//  PickPhoto
//
//  게이트 팝업 UI — 커스텀 중앙 팝업
//  반투명 배경 + 중앙 라운드 카드
//  modalPresentationStyle = .overFullScreen, crossDissolve
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

/// 게이트 커스텀 중앙 팝업
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

    /// 반투명 배경
    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 중앙 카드 컨테이너
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 제목 라벨
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "삭제대기함을 비우려면"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 안내 라벨 (장수 · 한도 정보)
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 광고 버튼
    private let adButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
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

    /// Plus 버튼
    private let plusButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemOrange
        button.setTitleColor(.white, for: .normal)
        button.setTitle("Plus로 무제한", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 닫기 버튼
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("닫기", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
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

    /// 게이트 팝업 생성
    /// - Parameters:
    ///   - trashCount: 삭제 대상 수
    ///   - remainingFreeDeletes: 남은 무료 삭제 수
    ///   - adsNeeded: 필요한 광고 수
    ///   - remainingRewards: 남은 리워드 가능 횟수
    init(trashCount: Int, remainingFreeDeletes: Int, adsNeeded: Int, remainingRewards: Int) {
        self.trashCount = trashCount
        self.remainingFreeDeletes = remainingFreeDeletes
        self.adsNeeded = adsNeeded
        self.remainingRewards = remainingRewards
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupAccessibility()
        configureContent()
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - UI Setup

    /// UI 레이아웃 구성 — 반투명 배경 + 중앙 카드
    private func setupUI() {
        // 반투명 배경 (탭으로 닫기)
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 중앙 카드
        view.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 320)
        ])

        // 카드 내부 스택뷰
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel, infoLabel,
            goldenMomentLabel, offlineLabel,
            adButton, plusButton, closeButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // 광고/Plus/닫기 버튼 전 간격 확보
        stackView.setCustomSpacing(20, after: offlineLabel)
        stackView.setCustomSpacing(8, after: adButton)
        stackView.setCustomSpacing(4, after: plusButton)

        cardView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])

        // 버튼 높이 고정
        NSLayoutConstraint.activate([
            adButton.heightAnchor.constraint(equalToConstant: 52),
            plusButton.heightAnchor.constraint(equalToConstant: 52)
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

        // 반투명 배경 탭 → 닫기
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(closeButtonTapped))
        dimView.addGestureRecognizer(dimTap)
    }

    /// 광고 버튼 탭 — dismiss 후 onAdWatch 콜백 호출
    @objc private func adButtonTapped() {
        Logger.app.debug("TrashGatePopup: 광고 버튼 탭")
        dismiss(animated: true) { [weak self] in
            self?.onAdWatch?()
        }
    }

    /// Plus 버튼 탭 — dismiss 후 onPlusUpgrade 콜백 호출
    @objc private func plusButtonTapped() {
        Logger.app.debug("TrashGatePopup: Plus 버튼 탭")
        dismiss(animated: true) { [weak self] in
            self?.onPlusUpgrade?()
        }
    }

    /// 닫기 버튼 탭 — dismiss 후 onDismiss 콜백 호출
    @objc private func closeButtonTapped() {
        Logger.app.debug("TrashGatePopup: 닫기 버튼 탭")
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    // MARK: - Content Configuration

    /// 데이터 기반 콘텐츠 구성
    private func configureContent() {
        // 안내 텍스트: "N장 · 무료 삭제 한도 M장 남음"
        infoLabel.text = "\(trashCount)장 · 무료 삭제 한도 \(remainingFreeDeletes)장 남음"

        // 광고 버튼 텍스트 결정
        let isRewardExhausted = remainingRewards <= 0

        if isRewardExhausted {
            // 골든 모먼트 (FR-014): 리워드 소진 — Plus 전환 유도
            configureGoldenMoment()
        } else if adsNeeded > 0 {
            // 광고로 해결 가능
            let adText = "광고 \(adsNeeded)회 보고 \(trashCount)장 전체 삭제"
            adButton.setTitle(adText, for: .normal)
            updateAdButtonState(.ready)
        } else {
            // adsNeeded == 0 — 한도 내 (보통 여기 오지 않음)
            adButton.isHidden = true
        }
    }

    /// 골든 모먼트 UI 구성 (FR-014)
    /// 리워드 2회 소진 시 Plus 전환 유도 강조
    private func configureGoldenMoment() {
        // 광고 버튼 비활성화
        adButton.isHidden = true

        // 골든 모먼트 라벨 표시
        goldenMomentLabel.isHidden = false

        // Plus 버튼 강조 (크기/색상 강화)
        plusButton.backgroundColor = .systemOrange
        plusButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)

        Logger.app.debug("TrashGatePopup: 골든 모먼트 — 리워드 소진, Plus 전환 유도")
    }

    // MARK: - Ad Button State

    /// 광고 버튼 상태 업데이트 (Ready/Loading/Failed)
    func updateAdButtonState(_ state: AdButtonState) {
        switch state {
        case .ready:
            adButton.isEnabled = true
            adButton.backgroundColor = .systemBlue
            adSpinner.stopAnimating()
            // 타이틀은 configureContent에서 설정됨

        case .loading:
            adButton.isEnabled = false
            adButton.backgroundColor = .systemBlue.withAlphaComponent(0.6)
            adButton.setTitle("", for: .normal)
            adSpinner.startAnimating()

        case .failed:
            adButton.isEnabled = false
            adButton.backgroundColor = .systemGray3
            adButton.setTitle("광고를 불러올 수 없습니다", for: .normal)
            adSpinner.stopAnimating()
        }
    }

    // MARK: - Network Monitoring (FR-055)

    /// 네트워크 연결 상태 모니터링
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? true
                self?.isOnline = (path.status == .satisfied)
                // 상태 변경 시에만 UI 업데이트
                if wasOnline != self?.isOnline {
                    self?.updateOfflineState()
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))

        // 초기 상태는 online 가정 (모니터 콜백이 곧 실제 상태 전달)
    }

    /// 오프라인 상태 UI 업데이트 (FR-055)
    private func updateOfflineState() {
        if isOnline {
            // 온라인 복귀
            offlineLabel.isHidden = true
            adButton.isEnabled = true
            plusButton.isEnabled = true
            configureContent() // 버튼 상태 재구성
        } else {
            // 오프라인
            offlineLabel.isHidden = false
            adButton.isEnabled = false
            adButton.backgroundColor = .systemGray3
            plusButton.isEnabled = false
            plusButton.backgroundColor = .systemGray4
        }
    }

    // MARK: - Accessibility (FR-057)

    /// 접근성 설정
    private func setupAccessibility() {
        // 카드뷰 접근성
        cardView.accessibilityLabel = "삭제대기함 비우기 안내"
        cardView.isAccessibilityElement = false
        cardView.accessibilityElements = [
            titleLabel, infoLabel, goldenMomentLabel,
            offlineLabel, adButton, plusButton, closeButton
        ]

        // 제목
        titleLabel.accessibilityTraits = .header

        // 안내 라벨
        infoLabel.accessibilityLabel = "\(trashCount)장 삭제 대상, 무료 삭제 한도 \(remainingFreeDeletes)장 남음"

        // 광고 버튼
        adButton.accessibilityLabel = "광고를 보고 사진 삭제하기"
        adButton.accessibilityHint = "광고를 시청한 후 사진을 삭제합니다"

        // Plus 버튼
        plusButton.accessibilityLabel = "Plus 구독으로 무제한 삭제"
        plusButton.accessibilityHint = "Plus 구독 안내 화면으로 이동합니다"

        // 닫기 버튼
        closeButton.accessibilityLabel = "닫기"
        closeButton.accessibilityHint = "팝업을 닫습니다"

        // 골든 모먼트
        goldenMomentLabel.accessibilityLabel = "오늘 광고 횟수를 모두 사용했습니다"

        // 오프라인
        offlineLabel.accessibilityLabel = "인터넷 연결이 필요합니다"
    }
}
