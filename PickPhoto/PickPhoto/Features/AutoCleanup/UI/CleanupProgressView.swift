//
//  CleanupProgressView.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-23.
//
//  탐색 진행 UI
//  - 진행바
//  - 찾은 수 표시 ("N장 발견")
//  - 현재 탐색 시점 표시
//  - 취소 버튼
//

import UIKit

// MARK: - CleanupProgressViewDelegate

/// 진행 뷰 델리게이트
protocol CleanupProgressViewDelegate: AnyObject {
    /// 취소 버튼 탭
    func cleanupProgressViewDidTapCancel(_ view: CleanupProgressView)
}

// MARK: - CleanupProgressView

/// 탐색 진행 뷰
///
/// 정리 진행 상황을 표시하는 반투명 오버레이 뷰입니다.
final class CleanupProgressView: UIView {

    // MARK: - UI Components

    /// 컨테이너 뷰 (블러 배경)
    private lazy var containerView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemMaterial)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()

    /// 제목 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "사진 정리 중"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    /// 진행바
    private lazy var progressBar: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.tintColor = .systemBlue
        progress.trackTintColor = .systemGray5
        progress.progress = 0
        return progress
    }()

    /// 찾은 수 라벨
    private lazy var foundCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0장 발견"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    /// 탐색 시점 라벨
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = ""
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    /// 취소 버튼 - GlassTextButton (Liquid Glass 스타일)
    private lazy var cancelButton: GlassTextButton = {
        let button = GlassTextButton(title: "취소", style: .plain, tintColor: .systemRed)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 스택 뷰
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            progressBar,
            foundCountLabel,
            dateLabel,
            cancelButton
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        return stack
    }()

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: CleanupProgressViewDelegate?

    /// 정리 방식 (날짜 표시 형식 결정)
    private var method: CleanupMethod?

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
        backgroundColor = UIColor.black.withAlphaComponent(0.4)

        addSubview(containerView)
        containerView.contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            // 컨테이너 - 화면 중앙
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 280),

            // 스택 뷰
            stackView.topAnchor.constraint(equalTo: containerView.contentView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: containerView.contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: containerView.contentView.bottomAnchor, constant: -20),

            // 진행바 너비
            progressBar.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }

    // MARK: - Public Methods

    /// 정리 방식 설정
    /// - Parameter method: 정리 방식 (날짜 표시 형식에 영향)
    func configure(method: CleanupMethod) {
        self.method = method

        switch method {
        case .fromLatest:
            titleLabel.text = "최신 사진부터 정리 중"
        case .continueFromLast:
            titleLabel.text = "이어서 정리 중"
        case .byYear(let year, _):
            titleLabel.text = "\(year)년 사진 정리 중"
        }
    }

    /// 진행 상황 업데이트
    /// - Parameter progress: 진행 상황
    func update(with progress: CleanupProgress) {
        // 진행바
        progressBar.setProgress(progress.progress, animated: true)

        // 찾은 수
        foundCountLabel.text = "\(progress.foundCount)장 발견"

        // 탐색 시점 (모든 모드에서 동일한 형식)
        let dateString = formatDate(progress.currentDate)
        dateLabel.text = dateString.isEmpty ? "" : "\(dateString) 사진 확인 중..."
    }

    /// 뷰 표시 (애니메이션)
    func show(in parentView: UIView) {
        alpha = 0
        parentView.addSubview(self)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parentView.topAnchor),
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])

        UIView.animate(withDuration: 0.25) {
            self.alpha = 1
        }
    }

    /// 뷰 숨김 (애니메이션)
    /// - Parameter completion: 완료 콜백
    func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    // MARK: - Private Methods

    /// 날짜 포맷팅 (모든 모드에서 "yyyy년 M월" 형식 통일)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }

    // MARK: - Actions

    @objc private func cancelButtonTapped() {
        delegate?.cleanupProgressViewDidTapCancel(self)
    }
}
