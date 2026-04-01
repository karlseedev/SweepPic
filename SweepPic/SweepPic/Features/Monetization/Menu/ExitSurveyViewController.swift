//
//  ExitSurveyViewController.swift
//  SweepPic
//
//  구독 해지 사유 설문 (Exit Survey)
//  US11: 해지 감지 후 모달로 표시
//
//  UI 구성:
//  - 반투명 블러 배경 (ATT/Gate/Celebration 동일 패턴)
//  - BlurPopupCardView 중앙 카드
//  - 5개 선택지 + 기타 텍스트 입력
//  - 제출/건너뛰기 버튼
//  제출 시 AnalyticsService.trackCancelReason() 호출
//

import UIKit
import AppCore
import OSLog

// MARK: - ExitSurveyViewController

/// 구독 해지 사유 설문 모달
/// - overFullScreen + crossDissolve (앱 공통 팝업 패턴)
/// - BlurPopupCardView + Dark Blur 배경
/// - 제출 시 bm.cancelReason 이벤트 전송
final class ExitSurveyViewController: UIViewController {

    // MARK: - Properties

    /// 선택된 해지 사유
    private var selectedReason: CancelReason?

    /// 선택지 버튼 배열 (선택 상태 관리용)
    private var reasonButtons: [UIButton] = []

    // MARK: - UI Components

    /// 블러 배경
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 카드 컨테이너 (Glass 팝업 카드)
    private lazy var cardView = BlurPopupCardView()

    /// 제목 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "왜 해지하셨나요?"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 부제 라벨
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "더 나은 서비스를 위해 알려주세요"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 선택지 버튼 스택뷰
    private lazy var reasonStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// 기타 텍스트 입력 필드 (기타 선택 시 표시)
    private lazy var otherTextField: UITextField = {
        let field = UITextField()
        field.attributedPlaceholder = NSAttributedString(
            string: "사유를 입력해주세요",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.3)]
        )
        field.font = .systemFont(ofSize: 15)
        field.textColor = .white
        field.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        field.layer.cornerRadius = 10
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.leftViewMode = .always
        field.isHidden = true
        field.returnKeyType = .done
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    /// 제출 버튼 — 반투명 흰색 배경 (앱 공통 팝업 스타일)
    private lazy var submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("제출", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.3), for: .disabled)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 건너뛰기 버튼 — 반투명 흰색 배경 + 회색 텍스트 (ATT 패턴)
    private lazy var skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("건너뛰기", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 메인 스택뷰
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
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

        // 선택지 버튼 생성
        let reasons: [(CancelReason, String)] = [
            (.price, "가격이 부담돼요"),
            (.enoughFree, "무료로도 충분해요"),
            (.done, "사진 정리를 다 했어요"),
            (.competitor, "다른 앱을 사용해요"),
            (.other, "기타")
        ]

        for (reason, title) in reasons {
            let button = makeReasonButton(title: title, reason: reason)
            reasonButtons.append(button)
            reasonStackView.addArrangedSubview(button)
        }

        // 스택뷰 구성
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(reasonStackView)
        stackView.addArrangedSubview(otherTextField)
        stackView.addArrangedSubview(submitButton)
        stackView.addArrangedSubview(skipButton)

        // 간격 조정
        stackView.setCustomSpacing(8, after: titleLabel)
        stackView.setCustomSpacing(20, after: subtitleLabel)
        stackView.setCustomSpacing(8, after: reasonStackView)
        stackView.setCustomSpacing(20, after: otherTextField)
        stackView.setCustomSpacing(8, after: submitButton)

        // 카드 뷰
        view.addSubview(cardView)
        cardView.activateBlur()
        cardView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            // 카드 - 화면 중앙, 좌우 여백 24
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),

            // 스택뷰 — 카드 내부
            stackView.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 28),
            stackView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -24),

            // 버튼 높이
            submitButton.heightAnchor.constraint(equalToConstant: 50),
            skipButton.heightAnchor.constraint(equalToConstant: 50),

            // 기타 텍스트 필드 높이
            otherTextField.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupActions() {
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        otherTextField.addTarget(self, action: #selector(otherTextChanged), for: .editingChanged)
        otherTextField.delegate = self
    }

    // MARK: - Button Factory

    /// 선택지 버튼 생성 — 반투명 흰색 배경 (앱 공통 스타일)
    private func makeReasonButton(title: String, reason: CancelReason) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        button.contentHorizontalAlignment = .leading
        button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1.5
        button.layer.borderColor = UIColor.clear.cgColor
        button.clipsToBounds = true
        button.tag = reasonButtons.count
        button.accessibilityIdentifier = reason.rawValue
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true

        // 좌측 패딩
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        config.title = title
        config.baseForegroundColor = .white
        button.configuration = config

        button.addTarget(self, action: #selector(reasonTapped(_:)), for: .touchUpInside)
        return button
    }

    // MARK: - Actions

    /// 선택지 버튼 탭
    @objc private func reasonTapped(_ sender: UIButton) {
        // 모든 버튼 선택 해제
        for button in reasonButtons {
            button.layer.borderColor = UIColor.clear.cgColor
            button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        }

        // 탭한 버튼 선택
        sender.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        sender.backgroundColor = UIColor.white.withAlphaComponent(0.15)

        // CancelReason 매핑
        let allReasons: [CancelReason] = [.price, .enoughFree, .done, .competitor, .other]
        guard sender.tag < allReasons.count else { return }
        selectedReason = allReasons[sender.tag]

        // 기타 선택 시 텍스트 필드 표시
        let isOther = selectedReason == .other
        otherTextField.isHidden = !isOther

        if !isOther {
            otherTextField.text = ""
            otherTextField.resignFirstResponder()
        } else {
            otherTextField.becomeFirstResponder()
        }

        updateSubmitButtonState()
    }

    /// 건너뛰기 버튼 탭
    @objc private func skipTapped() {
        Logger.app.debug("ExitSurvey: 스킵")
        dismiss(animated: true)
    }

    /// 제출 버튼 탭
    @objc private func submitTapped() {
        guard let reason = selectedReason else { return }

        let text = reason == .other ? otherTextField.text : nil

        // [Analytics] bm.cancelReason 이벤트 전송
        AnalyticsService.shared.trackCancelReason(reason: reason, text: text)
        Logger.app.debug("ExitSurvey: 제출 — reason=\(reason.rawValue), text=\(text ?? "nil")")

        dismiss(animated: true)
    }

    /// 기타 텍스트 필드 변경
    @objc private func otherTextChanged() {
        updateSubmitButtonState()
    }

    // MARK: - Helpers

    /// 제출 버튼 활성화 상태 업데이트
    private func updateSubmitButtonState() {
        guard let reason = selectedReason else {
            submitButton.isEnabled = false
            submitButton.alpha = 0.4
            return
        }

        let isEnabled: Bool
        if reason == .other {
            isEnabled = !(otherTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        } else {
            isEnabled = true
        }

        submitButton.isEnabled = isEnabled
        submitButton.alpha = isEnabled ? 1.0 : 0.4
    }
}

// MARK: - UITextFieldDelegate

extension ExitSurveyViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    /// 200자 제한
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 200
    }
}
