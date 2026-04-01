//
//  ExitSurveyViewController.swift
//  SweepPic
//
//  구독 해지 사유 설문 (Exit Survey)
//  US11: 해지 감지 후 모달로 표시
//
//  5개 선택지 + 기타(텍스트 입력) 구성
//  제출 시 AnalyticsService.trackCancelReason() 호출
//  닫기 버튼으로 스킵 가능 (강제하지 않음)
//

import UIKit
import AppCore
import OSLog

// MARK: - ExitSurveyViewController

/// 구독 해지 사유 설문 모달
/// - 5개 선택지 버튼 + 기타 텍스트 입력
/// - 제출 시 bm.cancelReason 이벤트 전송
/// - 닫기 버튼으로 스킵 가능
final class ExitSurveyViewController: UIViewController {

    // MARK: - Properties

    /// 선택된 해지 사유
    private var selectedReason: CancelReason?

    /// 선택지 버튼 배열 (선택 상태 관리용)
    private var reasonButtons: [UIButton] = []

    // MARK: - UI Components

    /// 제목 라벨
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "왜 해지하셨나요?"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 부제 라벨
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "더 나은 서비스를 위해 사유를 알려주세요"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 선택지 버튼 스택뷰
    private let buttonsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// 기타 텍스트 입력 필드 (기타 선택 시 표시)
    private let otherTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "사유를 입력해주세요"
        field.borderStyle = .roundedRect
        field.font = .systemFont(ofSize: 15)
        field.isHidden = true
        field.returnKeyType = .done
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    /// 제출 버튼
    private let submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("제출", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
        button.layer.cornerRadius = 12
        button.isEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 닫기 버튼 (스킵)
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }

    // MARK: - Setup

    /// UI 구성
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // 닫기 버튼
        view.addSubview(closeButton)

        // 제목 + 부제
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

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
            buttonsStackView.addArrangedSubview(button)
        }

        view.addSubview(buttonsStackView)

        // 기타 텍스트 필드
        view.addSubview(otherTextField)
        otherTextField.delegate = self

        // 제출 버튼
        view.addSubview(submitButton)

        // 레이아웃
        NSLayoutConstraint.activate([
            // 닫기 버튼
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            // 제목
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // 부제
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // 선택지 스택뷰
            buttonsStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            buttonsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            buttonsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // 기타 텍스트 필드
            otherTextField.topAnchor.constraint(equalTo: buttonsStackView.bottomAnchor, constant: 12),
            otherTextField.leadingAnchor.constraint(equalTo: buttonsStackView.leadingAnchor),
            otherTextField.trailingAnchor.constraint(equalTo: buttonsStackView.trailingAnchor),
            otherTextField.heightAnchor.constraint(equalToConstant: 44),

            // 제출 버튼
            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    /// 액션 연결
    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        // 기타 텍스트 필드 변경 감지 (제출 버튼 활성화 제어)
        otherTextField.addTarget(self, action: #selector(otherTextChanged), for: .editingChanged)
    }

    // MARK: - Button Factory

    /// 선택지 버튼 생성
    /// - Parameters:
    ///   - title: 버튼 텍스트
    ///   - reason: 대응하는 CancelReason
    /// - Returns: 설정된 UIButton
    private func makeReasonButton(title: String, reason: CancelReason) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.contentHorizontalAlignment = .leading
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        button.backgroundColor = .secondarySystemBackground
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1.5
        button.layer.borderColor = UIColor.clear.cgColor
        button.tag = reasonButtons.count // 인덱스로 사용
        button.accessibilityIdentifier = reason.rawValue
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addTarget(self, action: #selector(reasonTapped(_:)), for: .touchUpInside)
        return button
    }

    // MARK: - Actions

    /// 선택지 버튼 탭
    @objc private func reasonTapped(_ sender: UIButton) {
        // 모든 버튼 선택 해제
        for button in reasonButtons {
            button.layer.borderColor = UIColor.clear.cgColor
            button.backgroundColor = .secondarySystemBackground
        }

        // 탭한 버튼 선택
        sender.layer.borderColor = UIColor.systemBlue.cgColor
        sender.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)

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

        // 제출 버튼 활성화 상태 업데이트
        updateSubmitButtonState()
    }

    /// 닫기 버튼 탭 (스킵)
    @objc private func closeTapped() {
        Logger.app.debug("ExitSurvey: 스킵")
        dismiss(animated: true)
    }

    /// 제출 버튼 탭
    @objc private func submitTapped() {
        guard let reason = selectedReason else { return }

        // 기타인 경우 텍스트 포함
        let text = reason == .other ? otherTextField.text : nil

        // [Analytics] bm.cancelReason 이벤트 전송
        AnalyticsService.shared.trackCancelReason(reason: reason, text: text)
        Logger.app.debug("ExitSurvey: 제출 — reason=\(reason.rawValue), text=\(text ?? "nil")")

        dismiss(animated: true)
    }

    /// 기타 텍스트 필드 변경 시 제출 버튼 상태 업데이트
    @objc private func otherTextChanged() {
        updateSubmitButtonState()
    }

    // MARK: - Helpers

    /// 제출 버튼 활성화 상태 업데이트
    /// - 선택지가 선택되어야 활성화
    /// - 기타 선택 시 텍스트가 비어있으면 비활성화
    private func updateSubmitButtonState() {
        guard let reason = selectedReason else {
            submitButton.isEnabled = false
            submitButton.backgroundColor = .systemGray4
            return
        }

        let isEnabled: Bool
        if reason == .other {
            // 기타: 텍스트가 있어야 제출 가능
            isEnabled = !(otherTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        } else {
            isEnabled = true
        }

        submitButton.isEnabled = isEnabled
        submitButton.backgroundColor = isEnabled ? .systemBlue : .systemGray4
    }
}

// MARK: - UITextFieldDelegate

extension ExitSurveyViewController: UITextFieldDelegate {

    /// 리턴 키 → 키보드 닫기
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
