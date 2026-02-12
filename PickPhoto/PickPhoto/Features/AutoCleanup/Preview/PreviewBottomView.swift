//
//  PreviewBottomView.swift
//  PickPhoto
//
//  Created by Claude on 2026-02-12.
//
//  하단 고정 버튼 영역
//  - primaryButton: "N장 정리하기" (filled, tinted)
//  - excludeButton: "빼고 M장만 정리" (text, 2단계부터)
//  - expandButton: "기준 낮춰서 더 보기 →" (text, 3단계 미만)
//

import UIKit

// MARK: - PreviewBottomViewDelegate

/// 하단 버튼 영역 delegate
protocol PreviewBottomViewDelegate: AnyObject {
    /// "N장 정리하기" 탭
    func previewBottomViewDidTapCleanup(_ view: PreviewBottomView)
    /// "빼고 M장만 정리" 탭
    func previewBottomViewDidTapExclude(_ view: PreviewBottomView)
    /// "기준 낮춰서 더 보기" 탭
    func previewBottomViewDidTapExpand(_ view: PreviewBottomView)
}

// MARK: - PreviewBottomView

/// 미리보기 그리드 하단 고정 버튼 영역
///
/// 현재 단계에 따라 버튼 구성이 변합니다:
/// - 1단계: "N장 정리하기" + "기준 낮춰서 더 보기"
/// - 2~3단계: "N장 정리하기" + "빼고 M장만 정리" + "기준 낮춰서 더 보기"
/// - 3단계: expandButton 숨김
final class PreviewBottomView: UIView {

    // MARK: - Properties

    weak var delegate: PreviewBottomViewDelegate?

    /// 뷰 전체 높이 (safe area 포함하지 않은 콘텐츠 높이)
    static let contentHeight: CGFloat = 140

    // MARK: - UI Elements

    /// 메인 정리 버튼 ("N장 정리하기")
    private let primaryButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .large
        config.buttonSize = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 제외 버튼 ("빼고 M장만 정리")
    private let excludeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.buttonSize = .medium
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 확장 버튼 ("기준 낮춰서 더 보기 →")
    private let expandButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.buttonSize = .medium
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 버튼 스택
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .systemBackground

        // 상단 구분선
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        addSubview(stackView)
        stackView.addArrangedSubview(primaryButton)
        stackView.addArrangedSubview(excludeButton)
        stackView.addArrangedSubview(expandButton)

        NSLayoutConstraint.activate([
            // 구분선
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            // 스택뷰
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            // 메인 버튼 전체 너비
            primaryButton.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            primaryButton.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
        ])

        // 액션 연결
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        excludeButton.addTarget(self, action: #selector(excludeTapped), for: .touchUpInside)
        expandButton.addTarget(self, action: #selector(expandTapped), for: .touchUpInside)
    }

    // MARK: - Configuration

    /// 하단 뷰 구성
    ///
    /// - Parameters:
    ///   - currentStage: 현재 표시 단계
    ///   - totalCount: 현재 단계까지의 총 개수
    ///   - previousStageCount: 이전 단계까지의 개수 (1단계면 nil)
    ///   - canExpand: 더 확장 가능한지 (3단계면 false)
    func configure(
        currentStage: PreviewStage,
        totalCount: Int,
        previousStageCount: Int?,
        canExpand: Bool
    ) {
        // 메인 버튼: "N장 정리하기"
        primaryButton.configuration?.title = "\(totalCount)장 정리하기"

        // 제외 버튼: "빼고 M장만 정리" (2단계부터)
        if let prevCount = previousStageCount, currentStage > .light {
            excludeButton.configuration?.title = "빼고 \(prevCount)장만 정리"
            excludeButton.isHidden = false
        } else {
            excludeButton.isHidden = true
        }

        // 확장 버튼: "기준 낮춰서 더 보기 →"
        if canExpand {
            expandButton.configuration?.title = "기준 낮춰서 더 보기 →"
            expandButton.isHidden = false
        } else {
            expandButton.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func primaryTapped() {
        delegate?.previewBottomViewDidTapCleanup(self)
    }

    @objc private func excludeTapped() {
        delegate?.previewBottomViewDidTapExclude(self)
    }

    @objc private func expandTapped() {
        delegate?.previewBottomViewDidTapExpand(self)
    }
}
