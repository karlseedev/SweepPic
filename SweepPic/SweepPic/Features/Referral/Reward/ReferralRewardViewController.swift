//
//  ReferralRewardViewController.swift
//  SweepPic
//
//  초대자 보상 수령 화면 (Phase 5, T029)
//
//  콜드 스타트 팝업 또는 메뉴 진입 시 모달로 표시:
//  ┌──────────────────────────────────┐
//  │  [보상 있음]                      │
//  │  "초대 보상 도착!"                │
//  │  "초대한 사람이 SweepPic에 가입했어요!"│
//  │  "14일 무료 혜택을 받으세요"       │
//  │  수령 가능: N건                   │
//  │  [보상 받기]                      │
//  │  [닫기]                          │
//  ├──────────────────────────────────┤
//  │  [보상 없음]                      │
//  │  "수령 가능한 보상이 없습니다"      │
//  │  [친구 초대하기]                   │
//  │  [닫기]                          │
//  ├──────────────────────────────────┤
//  │  [수령 완료]                      │
//  │  "14일 무료 혜택이 적용되었습니다!" │
//  │  → 다음 보상 자동 표시             │
//  └──────────────────────────────────┘
//
//  참조: specs/004-referral-reward/spec.md §User Story 3
//  참조: specs/004-referral-reward/spec.md FR-040
//

import UIKit
import AppCore
import OSLog

// MARK: - ReferralRewardViewController

/// 초대자 보상 수령 화면 (모달)
/// 콜드 스타트 팝업과 메뉴 진입 모두 동일 화면 사용
final class ReferralRewardViewController: UIViewController {

    // MARK: - State

    /// 화면 표시 상태
    private enum DisplayState {
        /// 로딩 중 (get-pending-rewards 호출)
        case loading
        /// 보상 있음 (수령 대기)
        case hasRewards(count: Int)
        /// 보상 없음
        case noRewards
        /// 수령 중 (서버 통신 / StoreKit 구매)
        case claiming
        /// 수령 성공
        case claimed
        /// 에러 (재시도 가능)
        case error(String)
    }

    // MARK: - Properties

    /// 현재 화면 상태
    private var displayState: DisplayState = .loading {
        didSet { updateUI(for: displayState) }
    }

    /// 대기 중인 보상 목록
    private var pendingRewards: [PendingRewardResponse] = []

    /// 현재 수령 중인 보상 인덱스
    private var currentRewardIndex = 0

    /// 보상 수령 매니저
    private let claimManager = ReferralRewardClaimManager()

    /// 포인트 노란색 (#FFEA00)
    private let highlightYellow = UIColor(red: 1.0, green: 0.918, blue: 0.0, alpha: 1.0)

    // MARK: - UI Components

    /// Glass 팝업 카드
    private lazy var cardView = BlurPopupCardView()

    /// 상태 아이콘 (🎉 또는 체크마크)
    private lazy var statusIconView: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 48)
        label.textAlignment = .center
        return label
    }()

    /// 제목 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// 설명 라벨
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// 보상 건수 라벨
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = highlightYellow
        label.textAlignment = .center
        return label
    }()

    /// 메인 액션 버튼 (보상 받기 / 친구 초대하기)
    private lazy var actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 로딩 스피너 (액션 버튼 내부)
    private lazy var buttonSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .black
        spinner.hidesWhenStopped = true
        return spinner
    }()

    /// 닫기 버튼 — 스택 하단 텍스트 버튼 (TrashGatePopup 패턴)
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitle("닫기", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()

    /// 에러 라벨
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.systemRed.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    /// 메인 스택 뷰
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            statusIconView,
            titleLabel,
            descriptionLabel,
            countLabel,
            errorLabel,
            actionButton,
            closeButton
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()

    // MARK: - Initialization

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// App Store에서 돌아오기 대기 중 여부
    private var isWaitingForReturn = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupClaimManager()
        setupForegroundObserver()
        loadPendingRewards()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        // 딤 배경 (TrashGatePopup 패턴)
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        // 배경 탭으로 닫기
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)

        // Glass 카드
        view.addSubview(cardView)
        cardView.activateBlur()
        cardView.contentView.addSubview(stackView)

        // 간격 조정
        stackView.setCustomSpacing(8, after: statusIconView)
        stackView.setCustomSpacing(8, after: titleLabel)
        stackView.setCustomSpacing(16, after: descriptionLabel)
        stackView.setCustomSpacing(20, after: countLabel)
        stackView.setCustomSpacing(8, after: errorLabel)
        stackView.setCustomSpacing(8, after: actionButton)

        // 버튼에 스피너 추가
        actionButton.addSubview(buttonSpinner)

        NSLayoutConstraint.activate([
            // 카드 — 화면 좌우 24pt, 세로 중앙
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // 스택 뷰 — 카드 내부 (상단 36pt, 좌우 24pt, 하단 24pt)
            stackView.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 36),
            stackView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -24),

            // 버튼 크기 — 스택 전체 너비, 높이 50
            actionButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 50),

            // 스피너 — 버튼 중앙
            buttonSpinner.centerXAnchor.constraint(equalTo: actionButton.centerXAnchor),
            buttonSpinner.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
        ])
    }

    /// ClaimManager 상태 변경 콜백 등록
    private func setupClaimManager() {
        claimManager.onStateChange = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .idle:
                // 사용자 취소 등으로 idle 복귀
                let count = self.pendingRewards.count - self.currentRewardIndex
                self.displayState = .hasRewards(count: count)

            case .loading:
                self.displayState = .claiming

            case .success:
                // Promotional Offer 경로 — 앱 내에서 즉시 완료
                self.displayState = .claimed

            case .waitingForReturn:
                // Offer Code 경로 — App Store로 전환됨
                // 스피너 상태 유지, 포그라운드 복귀 시 성공 화면 표시
                self.isWaitingForReturn = true

            case .failed(let message):
                self.displayState = .error(message)
            }
        }
    }

    /// 포그라운드 복귀 감지 옵저버 등록
    private func setupForegroundObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForegroundReturn),
            name: UIScene.willEnterForegroundNotification,
            object: nil
        )
    }

    /// App Store에서 돌아왔을 때 성공 화면 표시
    @objc private func handleForegroundReturn() {
        guard isWaitingForReturn else { return }
        isWaitingForReturn = false
        displayState = .claimed
    }

    // MARK: - Data Loading

    /// 대기 중인 보상 목록을 서버에서 조회
    private func loadPendingRewards() {
        displayState = .loading

        Task {
            let userId = ReferralStore.shared.userId
            do {
                let response = try await ReferralService.shared.getPendingRewards(userId: userId)
                self.pendingRewards = response.rewards
                self.currentRewardIndex = 0

                if response.rewards.isEmpty {
                    self.displayState = .noRewards
                } else {
                    self.displayState = .hasRewards(count: response.rewards.count)
                }

                Logger.referral.debug(
                    "ReferralRewardVC: 보상 \(response.rewards.count)건 로드"
                )
            } catch {
                self.displayState = .error(
                    "보상 정보를 불러올 수 없습니다.\n잠시 후 다시 시도해주세요."
                )
                Logger.referral.error(
                    "ReferralRewardVC: 보상 조회 실패 — \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - UI Update

    /// 상태에 따른 UI 업데이트
    private func updateUI(for state: DisplayState) {
        // 공통: 상태 초기화
        errorLabel.isHidden = true
        buttonSpinner.stopAnimating()
        actionButton.isEnabled = true
        actionButton.setTitle("", for: .normal)
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)

        switch state {
        case .loading:
            statusIconView.text = ""
            titleLabel.text = "불러오는 중..."
            descriptionLabel.text = ""
            countLabel.text = ""
            actionButton.isHidden = true
            closeButton.isHidden = false

        case .hasRewards(let count):
            statusIconView.text = "🎉"
            statusIconView.isHidden = false
            titleLabel.text = "초대 보상 도착!"
            descriptionLabel.text = "초대한 사람이 SweepPic에 가입했어요!\n14일 무료 혜택을 받으세요"
            countLabel.text = "수령 가능한 보상: \(count)건"
            countLabel.isHidden = false
            actionButton.isHidden = false
            actionButton.setTitle("보상 받기", for: .normal)
            actionButton.backgroundColor = .white
            actionButton.setTitleColor(.black, for: .normal)
            closeButton.isHidden = false

        case .noRewards:
            statusIconView.text = "📭"
            titleLabel.text = "수령 가능한 보상이 없습니다"
            descriptionLabel.text = "친구를 초대하고 프리미엄 혜택을 받으세요!"
            countLabel.isHidden = true
            actionButton.isHidden = false
            actionButton.setTitle("친구 초대하기", for: .normal)
            actionButton.backgroundColor = .white
            actionButton.setTitleColor(.black, for: .normal)
            closeButton.isHidden = false

        case .claiming:
            // 버튼을 스피너로 전환
            actionButton.setTitle("", for: .normal)
            actionButton.isEnabled = false
            buttonSpinner.startAnimating()

        case .claimed:
            statusIconView.text = ""
            statusIconView.isHidden = true
            titleLabel.text = "14일 무료 혜택이\n적용되었습니다!"
            titleLabel.font = .systemFont(ofSize: 22, weight: .regular)
            descriptionLabel.text = ""
            countLabel.isHidden = true
            actionButton.isHidden = false
            actionButton.setTitle("확인", for: .normal)
            actionButton.backgroundColor = .white
            actionButton.setTitleColor(.black, for: .normal)
            closeButton.isHidden = true

        case .error(let message):
            errorLabel.text = message
            errorLabel.isHidden = false
            actionButton.isHidden = false
            actionButton.setTitle("다시 시도", for: .normal)
            actionButton.backgroundColor = .white
            actionButton.setTitleColor(.black, for: .normal)
        }
    }

    // MARK: - Actions

    /// 메인 액션 버튼 탭
    @objc private func actionButtonTapped() {
        switch displayState {
        case .claimed:
            // [확인] 탭 → 다음 보상 진행
            proceedToNextReward()

        case .hasRewards:
            // 현재 보상 수령
            guard currentRewardIndex < pendingRewards.count else { return }
            let reward = pendingRewards[currentRewardIndex]
            Task {
                await claimManager.claimReward(rewardId: reward.id)
            }

        case .noRewards:
            // 친구 초대하기 → ReferralExplainVC
            cardView.deactivateBlur()
            dismiss(animated: true) {
                // 최상위 VC에서 ReferralExplainVC 표시
                guard let topVC = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow })?
                    .rootViewController else { return }

                let explainVC = ReferralExplainViewController()
                let presenter = topVC.presentedViewController ?? topVC
                presenter.present(explainVC, animated: true)
            }

        case .error:
            // 재시도 — 현재 보상 수령 또는 목록 리로드
            if pendingRewards.isEmpty {
                loadPendingRewards()
            } else if currentRewardIndex < pendingRewards.count {
                let reward = pendingRewards[currentRewardIndex]
                Task {
                    await claimManager.claimReward(rewardId: reward.id)
                }
            }

        default:
            break
        }
    }

    /// 닫기 버튼 / 배경 탭
    @objc private func closeTapped() {
        cardView.deactivateBlur()
        dismiss(animated: true)
    }

    // MARK: - Sequential Reward Processing

    /// 현재 보상 수령 후 다음 보상으로 진행
    private func proceedToNextReward() {
        currentRewardIndex += 1

        let remaining = pendingRewards.count - currentRewardIndex
        if remaining > 0 {
            // 다음 보상 표시
            displayState = .hasRewards(count: remaining)
        } else {
            // 모든 보상 수령 완료 → dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.closeTapped()
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ReferralRewardViewController: UIGestureRecognizerDelegate {

    /// 카드 영역 외부만 탭 제스처 인식 (카드 내부 탭은 무시)
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        let location = touch.location(in: view)
        return !cardView.frame.contains(location)
    }
}
