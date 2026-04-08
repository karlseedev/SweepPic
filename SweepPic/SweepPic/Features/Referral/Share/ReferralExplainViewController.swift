//
//  ReferralExplainViewController.swift
//  SweepPic
//
//  초대 설명 화면 — "친구에게 초대하고 함께 프리미엄 받기!"
//
//  와이어프레임 (docs/bm/260316Reward.md §Phase 1):
//  ┌──────────────────────────────┐
//  │  친구에게 초대하고            │
//  │  함께 프리미엄 받기!          │
//  ├───────────────────────────────┤
//  │  👤 나  — 초대 1회마다 14일   │
//  │  👥 친구 — 14일 프리미엄 무료  │
//  ├───────────────────────────────┤
//  │  [초대하기]                   │
//  │  이미 구독 중이어도 14일 연장  │
//  └──────────────────────────────┘
//
//  상태: 로딩 / 에러 / 성공 (FR-038)
//  Push 프리프롬프트: 공유 완료 후 1회 표시 (T015, FR-025)
//
//  참조: specs/004-referral-reward/contracts/protocols.md
//  참조: docs/bm/260316Reward.md §Phase 1
//

import UIKit
import AppCore
import OSLog
import UserNotifications

// MARK: - ReferralExplainViewController

/// 초대 설명 + 공유 화면
/// [초대하기] 탭 → 코드 생성/조회 → 공유 시트 → Push 프리프롬프트
final class ReferralExplainViewController: UIViewController {

    // MARK: - State

    /// 화면 상태 (로딩/에러/준비)
    private enum ViewState {
        case ready
        case loading
        case error(String)
    }

    // MARK: - Properties

    /// 현재 상태
    private var viewState: ViewState = .ready {
        didSet { updateUI(for: viewState) }
    }

    /// 공유 매니저 (T014)
    private let shareManager = ReferralShareManager()

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
        button.setTitle(String(localized: "common.close"), for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        button.accessibilityLabel = String(localized: "common.close")
        return button
    }()

    /// 포인트 노란색 (#FFEA00 — PaywallVC, ATTPromptVC와 동일)
    private let highlightYellow = UIColor(red: 1.0, green: 0.918, blue: 0.0, alpha: 1.0)

    /// 제목 라벨: "친구 초대하고\n함께 무료 혜택 받기" — "함께 무료 혜택 받기" 부분 노란색
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        let fullText = String(localized: "referral.explain.title")
        let keyword = String(localized: "referral.explain.titleKeyword")
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        )
        // "함께 무료 혜택 받기" 부분 포인트 노란색 적용
        if let range = fullText.range(of: keyword) {
            attributed.addAttribute(.foregroundColor, value: highlightYellow, range: NSRange(range, in: fullText))
        }
        label.attributedText = attributed
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// 나 보상 설명 행
    private lazy var myRewardRow: UIView = {
        return makeRewardRow(
            icon: "person.fill",
            title: String(localized: "referral.explain.inviterTitle"),
            detail: String(localized: "referral.explain.inviterDetail")
        )
    }()

    /// 친구 보상 설명 행
    private lazy var friendRewardRow: UIView = {
        return makeRewardRow(
            icon: "person.2.fill",
            title: String(localized: "referral.explain.friendTitle"),
            detail: String(localized: "referral.explain.friendDetail")
        )
    }()

    /// [초대하기] 버튼
    private lazy var inviteButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.setTitle(String(localized: "referral.explain.inviteButton"), for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(inviteButtonTapped), for: .touchUpInside)
        button.accessibilityLabel = String(localized: "referral.explain.inviteButton")
        button.accessibilityHint = String(localized: "a11y.celebration.referralHint")
        return button
    }()

    /// 로딩 인디케이터 (버튼 위에 표시)
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    /// 부가 문구: "이미 Pro멤버십 이용 중이어도 14일 무료 연장"
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "referral.explain.proNote")
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.5)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    /// 에러 메시지 라벨 (에러 상태에서만 표시)
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

    /// 메인 스택 뷰
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            myRewardRow,
            friendRewardRow,
            errorLabel,
            inviteButton,
            subtitleLabel,
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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        _ = blurAnimator

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

        // 로딩 인디케이터를 버튼 위에 추가
        inviteButton.addSubview(loadingIndicator)

        // 간격 조정
        stackView.setCustomSpacing(20, after: titleLabel)
        stackView.setCustomSpacing(8, after: myRewardRow)
        stackView.setCustomSpacing(20, after: friendRewardRow)
        stackView.setCustomSpacing(4, after: errorLabel)
        stackView.setCustomSpacing(8, after: inviteButton)

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

            // 버튼 크기
            inviteButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            inviteButton.heightAnchor.constraint(equalToConstant: 50),

            // 닫기 버튼
            closeButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 50),

            // 보상 행 너비
            myRewardRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            friendRewardRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            subtitleLabel.widthAnchor.constraint(lessThanOrEqualTo: stackView.widthAnchor),

            // 로딩 인디케이터 — 버튼 중앙
            loadingIndicator.centerXAnchor.constraint(equalTo: inviteButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: inviteButton.centerYAnchor)
        ])
    }

    /// 보상 설명 행 생성 (아이콘 + 제목 + 설명)
    /// - Parameters:
    ///   - icon: SF Symbol 이름
    ///   - title: 행 제목 ("나", "친구")
    ///   - detail: 보상 설명 텍스트
    /// - Returns: 구성된 UIView
    private func makeRewardRow(icon: String, title: String, detail: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // 아이콘
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: config)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        // 제목
        let titleLbl = UILabel()
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = .white

        // 설명
        let detailLbl = UILabel()
        detailLbl.translatesAutoresizingMaskIntoConstraints = false
        detailLbl.text = detail
        detailLbl.font = .systemFont(ofSize: 14, weight: .regular)
        detailLbl.textColor = UIColor.white.withAlphaComponent(0.7)
        detailLbl.numberOfLines = 0

        container.addSubview(iconView)
        container.addSubview(titleLbl)
        container.addSubview(detailLbl)

        NSLayoutConstraint.activate([
            // 아이콘
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            // 제목
            titleLbl.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLbl.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),

            // 설명
            detailLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            detailLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 2),
            detailLbl.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8),
            detailLbl.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),

            // 컨테이너 높이
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        return container
    }

    // MARK: - State Management

    /// 상태에 따라 UI 업데이트
    private func updateUI(for state: ViewState) {
        switch state {
        case .ready:
            // 버튼 활성화, 에러 숨기기
            inviteButton.isEnabled = true
            inviteButton.alpha = 1.0
            inviteButton.setTitle(String(localized: "referral.explain.inviteButton"), for: .normal)
            loadingIndicator.stopAnimating()
            errorLabel.isHidden = true

        case .loading:
            // 버튼 비활성화 + 로딩 표시
            inviteButton.isEnabled = false
            inviteButton.alpha = 0.6
            inviteButton.setTitle("", for: .normal)
            loadingIndicator.startAnimating()
            errorLabel.isHidden = true

        case .error(let message):
            // 에러 메시지 표시 + 다시 시도 버튼
            inviteButton.isEnabled = true
            inviteButton.alpha = 1.0
            inviteButton.setTitle(String(localized: "referral.explain.retry"), for: .normal)
            loadingIndicator.stopAnimating()
            errorLabel.text = message
            errorLabel.isHidden = false
        }
    }

    // MARK: - Actions

    /// 닫기 버튼 탭
    @objc private func closeTapped() {
        blurAnimator.stopAnimation(true)
        dismiss(animated: true)
    }

    /// [초대하기] 버튼 탭 → 코드 생성 → 공유 시트
    @objc private func inviteButtonTapped() {
        viewState = .loading

        Task {
            do {
                // 1. 초대 코드 생성 또는 조회
                let userId = ReferralStore.shared.userId
                let link = try await ReferralService.shared.createOrGetLink(userId: userId)
                Logger.referral.debug("ReferralExplain: 초대 링크 — \(link.referralCode)")

                // [Analytics] T048: 링크 생성 이벤트
                AnalyticsService.shared.trackReferralLinkCreated()

                await MainActor.run {
                    viewState = .ready
                }

                // 2. 공유 시트 표시 (메인 스레드)
                await MainActor.run {
                    shareManager.presentShareSheet(
                        from: self,
                        link: link
                    ) { [weak self] completed in
                        // 3. 공유 완료 시 Push 프리프롬프트 (T015)
                        if completed {
                            self?.handleShareCompleted()
                        }
                        // completed=false (취소) → 아무 동작 없음
                    }
                }

            } catch let error as ReferralServiceError {
                let message = error.localizedDisplayMessage
                Logger.referral.error("ReferralExplain: 에러 — \(message)")
                await MainActor.run {
                    viewState = .error(message)
                }
            } catch {
                Logger.referral.error("ReferralExplain: 에러 — \(error.localizedDescription)")
                await MainActor.run {
                    viewState = .error(String(localized: "referral.explain.unexpectedError"))
                }
            }
        }
    }

    // MARK: - Push Pre-prompt (T015, FR-025)

    /// 공유 완료 후 Push 프리프롬프트 처리
    /// - hasAskedPushPermission 체크 → 1회만 표시
    /// - .notDetermined → 시스템 Push 권한 요청
    /// - .denied → 설정으로 이동 안내
    /// - .authorized → 미표시
    private func handleShareCompleted() {
        // 이미 물어본 적 있으면 스킵
        guard !ReferralStore.shared.hasAskedPushPermission else {
            Logger.referral.debug("ReferralExplain: Push 프리프롬프트 — 이미 표시한 적 있음")
            return
        }

        // Push 권한 상태 확인 후 분기
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            await MainActor.run {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    // 이미 허용됨 → 프리프롬프트 불필요
                    Logger.referral.debug("ReferralExplain: Push 이미 허용됨")
                    return

                case .notDetermined:
                    // 아직 안 물어봄 → 프리프롬프트 → 시스템 팝업
                    showPushPrePrompt(isDenied: false)

                case .denied:
                    // 이전에 거부 → 설정으로 이동 안내
                    showPushPrePrompt(isDenied: true)

                @unknown default:
                    break
                }
            }
        }
    }

    /// Push 프리프롬프트 알림 표시
    /// - Parameter isDenied: true이면 이전에 거부한 상태 (설정으로 이동 안내 필요)
    private func showPushPrePrompt(isDenied: Bool) {
        let denialCount = ReferralStore.shared.pushDenialCount
        // 0: 첫 번째 프리프롬프트, 1: 재확인 프리프롬프트
        let isRetry = denialCount >= 1

        let title = isRetry
            ? String(localized: "referral.explain.push.title")
            : String(localized: "referral.explain.push.message")
        let message = String(localized: "referral.explain.push.detail")

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        // [알림 받기] 액션
        // count는 여기서 올리지 않음 — 시스템 팝업 결과에 따라 처리
        alert.addAction(UIAlertAction(title: String(localized: "referral.explain.push.enable"), style: .default) { [weak self] _ in
            if isDenied {
                // 이전에 시스템에서 거부 → 알림 꺼짐 안내 + 설정으로 이동
                // 설정으로 이동 안내까지 했으면 더 이상 표시 안 함
                ReferralStore.shared.pushDenialCount = 2
                self?.showDeniedAlert()
            } else {
                // .notDetermined → 시스템 Push 권한 요청
                // 허용/거부 결과는 requestSystemPushPermission에서 처리
                self?.requestSystemPushPermission()
            }
        })

        // [닫기] 액션 — 거부 횟수 증가
        let closeTitle = String(localized: "common.close")
        alert.addAction(UIAlertAction(title: closeTitle, style: .cancel) { _ in
            ReferralStore.shared.pushDenialCount = denialCount + 1
            Logger.referral.debug("ReferralExplain: Push 프리프롬프트 거부 (\(denialCount + 1)회)")
        })

        present(alert, animated: true)
    }

    /// 시스템 Push 권한 요청 (notDetermined 상태)
    private func requestSystemPushPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    // 허용됨 → 원격 알림 등록 + 더 이상 프리프롬프트 표시 안 함
                    ReferralStore.shared.pushDenialCount = 2
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    Logger.referral.debug("ReferralExplain: Push 권한 허용됨")
                } else {
                    // 시스템 팝업에서 거부 → 거부 횟수 증가 (다음 공유 시 재확인)
                    ReferralStore.shared.pushDenialCount += 1
                    Logger.referral.debug("ReferralExplain: Push 시스템 거부 (\(ReferralStore.shared.pushDenialCount)회)")
                }
            } catch {
                Logger.referral.error("ReferralExplain: Push 권한 요청 실패 — \(error.localizedDescription)")
            }
        }
    }

    /// 알림 꺼짐 안내 팝업 (denied 상태에서 "알림 받기" 탭 시)
    private func showDeniedAlert() {
        let alert = UIAlertController(
            title: String(localized: "referral.explain.push.offTitle"),
            message: String(localized: "referral.explain.push.offMessage"),
            preferredStyle: .alert
        )

        // [설정으로 이동] → 앱 설정 페이지
        alert.addAction(UIAlertAction(title: String(localized: "referral.explain.push.settings"), style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })

        // [나중에]
        alert.addAction(UIAlertAction(title: String(localized: "referral.explain.push.later"), style: .cancel))

        present(alert, animated: true)
    }
}
