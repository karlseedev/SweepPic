// ToastView.swift
// 토스트 메시지 컴포넌트
//
// PRD7: 그리드 즉시 삭제/복원
// - TrashStore 저장 실패 시 에러 메시지 표시
// - 하단에 2초간 표시 후 자동 사라짐

import UIKit

/// 토스트 메시지 뷰
/// 하단에 메시지를 표시하고 자동으로 사라짐
final class ToastView: UIView {

    // MARK: - Constants

    /// 토스트 표시 시간 (초)
    private static let displayDuration: TimeInterval = 2.0

    /// 페이드 애니메이션 시간 (초)
    private static let fadeDuration: TimeInterval = 0.25

    /// 하단 여백
    private static let bottomMargin: CGFloat = 100

    /// 좌우 여백
    private static let horizontalPadding: CGFloat = 20

    /// 내부 여백
    private static let contentPadding: CGFloat = 16

    /// 코너 반경
    private static let cornerRadius: CGFloat = 12

    // MARK: - UI Components

    /// 메시지 라벨
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // 배경 스타일
        backgroundColor = UIColor.black.withAlphaComponent(0.85)
        layer.cornerRadius = Self.cornerRadius

        // 그림자
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.3

        // 메시지 라벨
        addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: Self.contentPadding),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.contentPadding),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.contentPadding),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.contentPadding)
        ])
    }

    // MARK: - Public Methods

    /// 토스트 메시지 표시
    /// - Parameters:
    ///   - message: 표시할 메시지
    ///   - window: 토스트를 표시할 윈도우 (nil이면 keyWindow 사용)
    static func show(_ message: String, in window: UIWindow? = nil) {
        guard let targetWindow = window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            return
        }

        // 토스트 뷰 생성
        let toast = ToastView()
        toast.messageLabel.text = message
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.alpha = 0

        // 윈도우에 추가
        targetWindow.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: targetWindow.centerXAnchor),
            toast.bottomAnchor.constraint(
                equalTo: targetWindow.safeAreaLayoutGuide.bottomAnchor,
                constant: -bottomMargin
            ),
            toast.leadingAnchor.constraint(
                greaterThanOrEqualTo: targetWindow.leadingAnchor,
                constant: horizontalPadding
            ),
            toast.trailingAnchor.constraint(
                lessThanOrEqualTo: targetWindow.trailingAnchor,
                constant: -horizontalPadding
            )
        ])

        // 페이드 인
        UIView.animate(withDuration: fadeDuration) {
            toast.alpha = 1
        }

        // 자동 사라짐
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
            UIView.animate(withDuration: fadeDuration, animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}
