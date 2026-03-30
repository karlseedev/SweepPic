//
//  ATTPromptViewController.swift
//  SweepPic
//
//  ATT(App Tracking Transparency) 프리프롬프트 화면 (FR-041, FR-042)
//
//  설치 후 2시간 경과 + Pro 미구독 시 표시
//  - "계속" → 시스템 ATT 팝업 호출 → dismiss
//  - "건너뛰기" → skipCount 증가 → dismiss
//  - 총 2회 기회 (skipCount < 2), 이후 영구 미표시
//
//  UI 구성:
//  - 반투명 블러 배경
//  - 중앙 카드: 아이콘 + 제목 + 설명 + 계속/건너뛰기 버튼
//

import UIKit
import AppTrackingTransparency
import AppCore
import OSLog

// MARK: - ATTPromptViewController

/// ATT 프리프롬프트 전체 화면
/// 설치 후 2시간 경과 + Pro 미구독 시 표시 (FR-041)
final class ATTPromptViewController: UIViewController {

    // MARK: - Callbacks

    /// dismiss 완료 시 호출 (ATT 결과 전달)
    var onDismissed: ((ATTrackingManager.AuthorizationStatus) -> Void)?

    // MARK: - UI Components

    /// 블러 배경
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 카드 컨테이너 (블러 팝업 카드)
    private lazy var cardView = BlurPopupCardView()

    /// 아이콘 이미지 (손 아이콘)
    private lazy var iconImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        let image = UIImage(systemName: "target", withConfiguration: config)
        let iv = UIImageView(image: image)
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    /// 제목 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "광고 맞춤 설정"
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// 설명 라벨 (FR-042)
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "활동 추적을 허용하면\n관련없는 스팸성 광고를 줄여드립니다"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0

        // 행간 + 키워드 노란색 강조 (#FFEA00, 온보딩 동일)
        let highlightYellow = UIColor(red: 1.0, green: 0.918, blue: 0.0, alpha: 1.0)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .center

        let fullText = label.text ?? ""
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ]
        )
        // "활동 추적을 허용" 노란색 강조
        if let range1 = fullText.range(of: "활동 추적을 허용") {
            attributed.addAttribute(.foregroundColor, value: highlightYellow, range: NSRange(range1, in: fullText))
        }
        label.attributedText = attributed

        return label
    }()

    /// "계속" 버튼 — 반투명 흰색 배경 (기존 팝업 스타일 통일)
    private lazy var continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitle("계속", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        return button
    }()

    /// "건너뛰기" 버튼 — 반투명 흰색 배경 + 회색 텍스트
    private lazy var skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitle("건너뛰기", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Referral Promo (US4)

    /// 초대 프로모 하단 배경 — 카드 하단을 가로로 잘라 색상 차별화
    private lazy var referralPromoBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 초대 프로모 안내 라벨
    private lazy var referralPromoLabel: UILabel = {
        let label = UILabel()
        label.text = "초대 한 번마다 나도 친구도\n14일 프리미엄 무료 제공!"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 초대하기 버튼 — 다른 버튼과 동일 스타일
    private lazy var referralButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitle("친구 초대하기", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(referralButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 초대 부가 문구
    private lazy var referralSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "이미 구독 중이어도 14일 무료 연장"
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.4)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 스택 뷰
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            iconImageView,
            titleLabel,
            descriptionLabel,
            continueButton,
            skipButton,
            referralPromoLabel,
            referralButton,
            referralSubtitleLabel
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // 모달 설정
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve

        view.backgroundColor = .clear

        // 블러 배경
        view.addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 카드 뷰
        view.addSubview(cardView)
        cardView.activateBlur()
        // 하단 배경 먼저 삽입 (스택뷰 뒤에 깔림)
        cardView.contentView.addSubview(referralPromoBackground)
        cardView.contentView.addSubview(stackView)

        // 아이콘 — 설명 사이 간격 조정
        stackView.setCustomSpacing(12, after: iconImageView)
        stackView.setCustomSpacing(8, after: titleLabel)
        // 설명 — 버튼 사이 간격 넓힘
        stackView.setCustomSpacing(24, after: descriptionLabel)
        // 계속 — 건너뛰기 사이 간격 좁힘
        stackView.setCustomSpacing(8, after: continueButton)

        NSLayoutConstraint.activate([
            // 카드 - 화면 중앙
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 300),

            // 스택 뷰 — 카드 내부
            stackView.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 28),
            stackView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -24),

            // 버튼 크기 — 스택 전체 너비, 높이 50 (기존 팝업 통일)
            continueButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            skipButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            skipButton.heightAnchor.constraint(equalToConstant: 50),

            // 초대 버튼 크기
            referralButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            referralButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // 건너뛰기 버튼과 초대 프로모 간격 (배경 시작점 18pt 여유 포함)
        stackView.setCustomSpacing(34, after: skipButton)
        stackView.setCustomSpacing(8, after: referralPromoLabel)
        stackView.setCustomSpacing(4, after: referralButton)

        // 배경 뷰 — 프로모 라벨 위에서 카드 하단 끝까지
        NSLayoutConstraint.activate([
            referralPromoBackground.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor),
            referralPromoBackground.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor),
            referralPromoBackground.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor),
            referralPromoBackground.topAnchor.constraint(equalTo: referralPromoLabel.topAnchor, constant: -16)
        ])

        // 접근성 설정 (FR-057)
        iconImageView.accessibilityLabel = "광고 맞춤 설정 아이콘"
        continueButton.accessibilityLabel = "계속하여 추적 허용 여부 선택"
        skipButton.accessibilityLabel = "건너뛰기"
        referralPromoLabel.accessibilityLabel = "초대 한 번마다 나도 친구도 14일 프리미엄 무료 제공"
        referralButton.accessibilityLabel = "친구 초대하기"
        referralButton.accessibilityHint = "초대 설명 화면으로 이동합니다"
    }

    // MARK: - Actions

    /// "계속" 버튼 탭 → 시스템 ATT 팝업 호출
    @objc private func continueButtonTapped() {
        Logger.app.debug("ATTPromptVC: '계속' 탭 — 시스템 ATT 팝업 요청")

        // ATT 시스템 팝업 표시
        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            DispatchQueue.main.async {
                Logger.app.debug("ATTPromptVC: ATT 결과 — \(status.rawValue)")

                // [BM] T057: ATT 결과 이벤트 (FR-056)
                AnalyticsService.shared.trackATTResult(authorized: status == .authorized)

                // hasShownPrompt = true (시스템 팝업까지 표시 완료)
                ATTStateManager.shared.markPromptShown()

                self?.dismissWithResult(status)
            }
        }
    }

    /// "건너뛰기" 버튼 탭 → skipCount 증가
    @objc private func skipButtonTapped() {
        Logger.app.debug("ATTPromptVC: '건너뛰기' 탭")

        // skipCount 증가
        ATTStateManager.shared.incrementSkipCount()

        // 시스템 팝업 미호출 — .notDetermined 상태 유지
        dismissWithResult(.notDetermined)
    }

    /// 초대 프로모 버튼 탭 → ReferralExplainViewController 모달
    @objc private func referralButtonTapped() {
        Logger.app.debug("ATTPromptVC: 초대 프로모 버튼 탭")
        let presenter = presentingViewController
        cardView.deactivateBlur()
        dismiss(animated: true) {
            guard let presenter = presenter else { return }
            let referralVC = ReferralExplainViewController()
            presenter.present(referralVC, animated: true)
        }
    }

    /// dismiss + 결과 콜백
    private func dismissWithResult(_ status: ATTrackingManager.AuthorizationStatus) {
        cardView.deactivateBlur()
        dismiss(animated: true) { [weak self] in
            self?.onDismissed?(status)
        }
    }
}
