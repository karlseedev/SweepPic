//
//  ATTPromptViewController.swift
//  PickPhoto
//
//  ATT(App Tracking Transparency) 프리프롬프트 화면 (FR-041, FR-042)
//
//  Grace Period 종료 후 첫 앱 실행 시 표시
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
/// Grace Period 종료 후 첫 앱 실행 시 표시 (FR-041)
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
        label.font = .systemFont(ofSize: 24, weight: .bold)
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
        label.font = .systemFont(ofSize: 18, weight: .regular)
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
                .font: UIFont.systemFont(ofSize: 18, weight: .regular),
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

    /// 스택 뷰
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            iconImageView,
            titleLabel,
            descriptionLabel,
            continueButton,
            skipButton
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
            skipButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // 접근성 설정 (FR-057)
        iconImageView.accessibilityLabel = "광고 맞춤 설정 아이콘"
        continueButton.accessibilityLabel = "계속하여 추적 허용 여부 선택"
        skipButton.accessibilityLabel = "건너뛰기"
    }

    // MARK: - Actions

    /// "계속" 버튼 탭 → 시스템 ATT 팝업 호출
    @objc private func continueButtonTapped() {
        Logger.app.debug("ATTPromptVC: '계속' 탭 — 시스템 ATT 팝업 요청")

        // ATT 시스템 팝업 표시
        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            DispatchQueue.main.async {
                Logger.app.debug("ATTPromptVC: ATT 결과 — \(status.rawValue)")

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

    /// dismiss + 결과 콜백
    private func dismissWithResult(_ status: ATTrackingManager.AuthorizationStatus) {
        cardView.deactivateBlur()
        dismiss(animated: true) { [weak self] in
            self?.onDismissed?(status)
        }
    }
}
