//
//  ReferralCodeInputViewController.swift
//  SweepPic
//
//  피초대자 코드 입력 화면
//
//  진입 시 check-status API로 현재 상태를 확인하고 3분기 UI를 표시:
//  ┌──────────────────────────────┐
//  │  [none] 코드 붙여넣기 화면    │
//  │  텍스트 입력 → 코드 추출      │
//  │  → match-code → 리딤 URL 열기│
//  ├──────────────────────────────┤
//  │  [matched] 혜택 미적용        │
//  │  "혜택이 아직 적용되지 않았어요"│
//  │  [혜택 받기] → 리딤 URL 열기  │
//  ├──────────────────────────────┤
//  │  [redeemed] 적용 완료         │
//  │  "이미 초대 코드가 적용되어    │
//  │   있습니다."                  │
//  └──────────────────────────────┘
//
//  참조: specs/004-referral-reward/tasks.md T023
//  참조: specs/004-referral-reward/contracts/api-endpoints.md §match-code, §check-status
//

import UIKit
import AppCore
import OSLog

// MARK: - ReferralCodeInputViewController

/// 피초대자 코드 입력 화면
/// 진입 시 check-status로 상태를 확인하고 적절한 UI를 표시한다.
final class ReferralCodeInputViewController: UIViewController {

    // MARK: - State

    /// 화면 표시 상태
    private enum DisplayState {
        /// 초기 로딩 (check-status 호출 중)
        case loading
        /// 코드 입력 화면 (check-status → none)
        case inputReady
        /// 코드 매칭됨, 리딤 미완료 (check-status → matched)
        case matched(redeemURL: URL?)
        /// 이미 적용 완료 (check-status → redeemed)
        case redeemed
        /// 에러 상태
        case error(String)
    }

    // MARK: - Properties

    /// 현재 화면 상태
    private var displayState: DisplayState = .loading {
        didSet { updateUI(for: displayState) }
    }

    /// check-status에서 받은 referral_id (matched 상태일 때)
    private var currentReferralId: String?

    /// 포인트 노란색 (#FFEA00 — ReferralExplainVC와 동일)
    private let highlightYellow = UIColor(red: 1.0, green: 0.918, blue: 0.0, alpha: 1.0)

    // MARK: - UI Components

    /// 배경 블러 (딤드 위에 10% 강도 블러)
    private let backgroundBlurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var blurAnimator: UIViewPropertyAnimator = {
        let animator = UIViewPropertyAnimator(duration: 0, curve: .linear) { [weak self] in
            self?.backgroundBlurView.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        animator.fractionComplete = 0.1
        animator.pausesOnCompletion = true
        return animator
    }()

    /// Glass 팝업 카드
    private lazy var cardView = BlurPopupCardView()

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
        button.accessibilityLabel = "닫기"
        return button
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

    /// 설명 라벨 (상태별 메시지)
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// 코드 입력 텍스트 뷰 (none 상태에서 표시)
    private lazy var codeTextView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        tv.textColor = .white
        tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.autocapitalizationType = .none
        tv.autocorrectionType = .no
        tv.returnKeyType = .done
        tv.delegate = self
        // 플레이스홀더 효과는 텍스트 변경 시 처리
        return tv
    }()

    /// 코드 입력 플레이스홀더 라벨 (텍스트뷰 위에 표시)
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "초대 메시지를 붙여넣으세요"
        label.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.3)
        label.isUserInteractionEnabled = false
        return label
    }()

    /// 클립보드에서 붙여넣기 버튼 (actionButton과 동일 스타일, 흰색 90%)
    private lazy var pasteButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        button.setTitle("붙여넣기", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(pasteButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 메인 액션 버튼 (적용하기 / 혜택 받기)
    private lazy var actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 로딩 인디케이터
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    /// 에러 메시지 라벨
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.systemRed.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    /// 상태 아이콘 (matched/redeemed 상태에서 표시)
    private lazy var statusIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    /// 메인 스택 뷰
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkCurrentStatus()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        _ = blurAnimator

        // 배경 탭 → 닫기
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
        view.addGestureRecognizer(tapGesture)

        // 배경 블러
        view.addSubview(backgroundBlurView)
        NSLayoutConstraint.activate([
            backgroundBlurView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 카드 뷰
        view.addSubview(cardView)
        cardView.activateBlur()
        cardView.contentView.addSubview(stackView)

        // 스택 구성 — 닫기 버튼은 스택 하단 (TrashGatePopup 패턴)
        stackView.addArrangedSubview(statusIconView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(codeTextView)
        stackView.addArrangedSubview(errorLabel)
        stackView.addArrangedSubview(pasteButton)
        stackView.addArrangedSubview(actionButton)
        stackView.addArrangedSubview(closeButton)

        // 텍스트뷰 위에 플레이스홀더
        codeTextView.addSubview(placeholderLabel)

        // 로딩 인디케이터 — 카드 중앙
        cardView.contentView.addSubview(loadingIndicator)

        // 간격 조정
        stackView.setCustomSpacing(8, after: statusIconView)
        stackView.setCustomSpacing(16, after: descriptionLabel)
        stackView.setCustomSpacing(30, after: codeTextView)
        stackView.setCustomSpacing(4, after: errorLabel)
        stackView.setCustomSpacing(16, after: errorLabel)

        NSLayoutConstraint.activate([
            // 카드 — 화면 중앙, 좌우 24pt (TrashGatePopup 패턴)
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // 스택 뷰 — 상단 36pt (TrashGatePopup 동일)
            stackView.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 36),
            stackView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -24),

            // 텍스트뷰
            codeTextView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            codeTextView.heightAnchor.constraint(equalToConstant: 100),

            // 플레이스홀더
            placeholderLabel.topAnchor.constraint(equalTo: codeTextView.topAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: codeTextView.leadingAnchor, constant: 17),

            // 붙여넣기 버튼
            pasteButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            pasteButton.heightAnchor.constraint(equalToConstant: 50),

            // 액션 버튼
            actionButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 50),

            // 닫기 버튼
            closeButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 50),

            // 상태 아이콘
            statusIconView.widthAnchor.constraint(equalToConstant: 48),
            statusIconView.heightAnchor.constraint(equalToConstant: 48),

            // 로딩 인디케이터
            loadingIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])

        // 초기 상태: 입력 화면 바로 표시 (check-status는 백그라운드에서 확인)
        displayState = .inputReady
    }

    // MARK: - State Management

    /// 상태에 따라 UI 업데이트
    private func updateUI(for state: DisplayState) {
        // 모든 요소 초기화
        statusIconView.isHidden = true
        codeTextView.isHidden = true
        pasteButton.isHidden = true
        errorLabel.isHidden = true
        actionButton.isHidden = true
        loadingIndicator.stopAnimating()

        switch state {
        case .loading:
            titleLabel.text = ""
            descriptionLabel.text = ""
            loadingIndicator.startAnimating()

        case .inputReady:
            titleLabel.text = "초대 코드 입력"
            descriptionLabel.text = "받은 초대 메시지 전체를 붙여넣으면\n자동으로 코드가 입력됩니다"
            codeTextView.isHidden = false
            pasteButton.isHidden = false
            actionButton.isHidden = false
            actionButton.setTitle("적용하기", for: .normal)
            actionButton.isEnabled = true
            actionButton.alpha = 1.0

        case .matched(let redeemURL):
            // 상태 아이콘 — 경고
            let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
            statusIconView.image = UIImage(systemName: "exclamationmark.circle", withConfiguration: config)
            statusIconView.tintColor = highlightYellow
            statusIconView.isHidden = false

            titleLabel.text = "혜택이 아직 적용되지 않았어요"
            descriptionLabel.text = "아래 버튼을 눌러\n14일 프리미엄 혜택을 받으세요"
            actionButton.isHidden = false
            actionButton.setTitle("혜택 받기", for: .normal)
            actionButton.isEnabled = redeemURL != nil
            actionButton.alpha = redeemURL != nil ? 1.0 : 0.5

        case .redeemed:
            // 상태 아이콘 — 체크
            let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
            statusIconView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
            statusIconView.tintColor = .systemGreen
            statusIconView.isHidden = false

            titleLabel.text = "초대 코드 적용 완료"
            descriptionLabel.text = "이미 초대 코드가 적용되어 있습니다."

        case .error(let message):
            titleLabel.text = "오류"
            descriptionLabel.text = ""
            errorLabel.text = message
            errorLabel.isHidden = false
            actionButton.isHidden = false
            actionButton.setTitle("다시 시도", for: .normal)
            actionButton.isEnabled = true
            actionButton.alpha = 1.0
        }
    }

    // MARK: - API: check-status

    /// 백그라운드에서 check-status API로 현재 상태를 확인한다.
    /// 기본 입력 화면을 먼저 표시하고, matched/redeemed일 때만 화면을 전환한다.
    private func checkCurrentStatus() {
        let userId = ReferralStore.shared.userId

        Task { @MainActor in
            do {
                let result = try await ReferralService.shared.checkStatus(userId: userId)

                switch result.status {
                case .none:
                    displayState = .inputReady

                case .matched:
                    // matched 상태의 리딤 URL 저장
                    if let referralId = result.referralId {
                        currentReferralId = referralId
                        OfferRedemptionService.shared.currentReferralId = referralId
                    }
                    displayState = .matched(redeemURL: result.redeemURL)

                case .redeemed, .rewarded:
                    displayState = .redeemed

                default:
                    // 예상치 못한 상태
                    displayState = .inputReady
                }

            } catch {
                // check-status 실패 시 입력 화면 유지 (이미 표시 중)
                Logger.referral.error("ReferralCodeInput: check-status 실패 — \(error)")
            }
        }
    }

    // MARK: - API: match-code

    /// 추출된 코드로 match-code API를 호출한다.
    private func matchCode(_ referralCode: String) {
        let userId = ReferralStore.shared.userId

        // 구독 상태 가져오기 (SubscriptionStore에서)
        let subscriptionStatus = getSubscriptionStatus()

        // 로딩 상태
        actionButton.isEnabled = false
        actionButton.alpha = 0.5
        errorLabel.isHidden = true

        Task { @MainActor in
            do {
                let result = try await ReferralService.shared.matchCode(
                    userId: userId,
                    referralCode: referralCode,
                    subscriptionStatus: subscriptionStatus
                )

                // 상태별 분기
                switch result.status {
                case .matched:
                    // 성공 — 리딤 URL 열기
                    currentReferralId = result.referralId
                    OfferRedemptionService.shared.currentReferralId = result.referralId

                    if let redeemURL = result.redeemURL {
                        Logger.referral.debug("ReferralCodeInput: 매칭 성공 → 리딤 URL 열기")
                        OfferRedemptionService.shared.openRedeemURL(redeemURL)

                        // Transaction 감지 시작
                        OfferRedemptionService.shared.startObservingRedemptions { [weak self] offerName in
                            Logger.referral.debug("ReferralCodeInput: 리딤 감지 — \(offerName)")
                            self?.displayState = .redeemed
                        }

                        // 리딤 URL을 연 후 matched 상태로 전환
                        displayState = .matched(redeemURL: redeemURL)
                    } else {
                        displayState = .matched(redeemURL: nil)
                    }

                case .selfReferral:
                    showError("본인의 초대 코드는 사용할 수 없습니다.")

                case .alreadyRedeemed:
                    displayState = .redeemed

                case .invalidCode:
                    showError("유효하지 않은 초대 코드입니다.")

                case .noCodesAvailable:
                    showError("현재 일시적으로 오류가 발생했습니다.\n다음날 다시 시도해주세요.")

                default:
                    showError("알 수 없는 응답입니다.")
                }

            } catch let error as ReferralServiceError {
                Logger.referral.error("ReferralCodeInput: match-code 실패 — \(error.localizedDescription)")
                showError(error.localizedDescription ?? "서버에 연결할 수 없습니다.")
            } catch {
                Logger.referral.error("ReferralCodeInput: match-code 실패 — \(error)")
                showError("서버에 연결할 수 없습니다.")
            }
        }
    }

    /// 에러 메시지를 표시하고 버튼을 재활성화한다.
    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        actionButton.isEnabled = true
        actionButton.alpha = 1.0
    }

    // MARK: - Subscription Status

    /// 현재 구독 상태를 서버 API용 문자열로 반환한다.
    /// 피초대자 대부분은 비구독자(none)이므로, 간소화된 분기를 사용한다.
    /// 월간/연간 정확한 구분은 Phase 5(SubscriptionStore 확장)에서 추가.
    private func getSubscriptionStatus() -> String {
        let store = SubscriptionStore.shared

        // 비구독자
        guard store.isProUser else {
            return "none"
        }

        // 활성 Pro 구독자 — 기본 monthly (Phase 5에서 정확한 구분 추가)
        return "monthly"
    }

    // MARK: - Actions

    /// 닫기 버튼 탭
    @objc private func closeTapped() {
        blurAnimator.stopAnimation(true)
        dismiss(animated: true)
    }

    /// 배경 탭 → 닫기 (카드 바깥 영역)
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !cardView.frame.contains(location) {
            blurAnimator.stopAnimation(true)
            dismiss(animated: true)
        }
    }

    /// 붙여넣기 버튼 탭
    @objc private func pasteButtonTapped() {
        guard let clipboardText = UIPasteboard.general.string else {
            showError("클립보드가 비어있습니다.")
            return
        }
        codeTextView.text = clipboardText
        placeholderLabel.isHidden = true
        errorLabel.isHidden = true
    }

    /// 액션 버튼 탭 — 상태에 따라 다른 동작
    @objc private func actionButtonTapped() {
        switch displayState {
        case .inputReady:
            // 코드 입력 → 추출 → match-code
            handleCodeInput()

        case .matched(let redeemURL):
            // 리딤 URL 열기
            if let url = redeemURL {
                OfferRedemptionService.shared.openRedeemURL(url)
            }

        case .error:
            // 다시 시도 → check-status 재호출
            checkCurrentStatus()

        default:
            break
        }
    }

    /// 코드 입력 텍스트에서 초대 코드를 추출하고 매칭한다.
    private func handleCodeInput() {
        let text = codeTextView.text ?? ""
        guard !text.isEmpty else {
            showError("초대 메시지를 붙여넣어 주세요.")
            return
        }

        // 정규식으로 코드 추출 (FR-006)
        guard let code = ReferralCodeParser.extractCode(from: text) else {
            showError("초대 코드를 찾을 수 없습니다.\n올바른 초대 메시지를 붙여넣어 주세요.")
            return
        }

        Logger.referral.debug("ReferralCodeInput: 코드 추출 성공 — \(code)")
        matchCode(code)
    }
}

// MARK: - UITextViewDelegate

extension ReferralCodeInputViewController: UITextViewDelegate {
    /// 텍스트 변경 시 플레이스홀더 show/hide
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        errorLabel.isHidden = true
    }

    /// 키보드 done 키 → 키보드 닫기
    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}
