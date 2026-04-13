//
//  PreviewBottomView.swift
//  SweepPic
//
//  Created by Claude on 2026-02-12.
//
//  하단 고정 버튼 영역 (GlassTextButton 스타일)
//  - primaryButton: "탐색된 N장 삭제대기함으로 이동" (Glass, 전체 너비)
//  - collapseButton: "31~40점 사진\nN장 덜 보기" (Glass pill, 2줄, 가로 배치)
//  - expandButton: "31~40점 사진\nN장 더 보기 →" (Glass pill, 2줄, 가로 배치)
//

import UIKit
import LiquidGlassKit

// MARK: - PreviewBottomViewDelegate

/// 하단 버튼 영역 delegate
protocol PreviewBottomViewDelegate: AnyObject {
    /// "N장 정리하기" 탭
    func previewBottomViewDidTapCleanup(_ view: PreviewBottomView)
    /// "N점 사진 N장 제외하기" 탭 (단계 축소)
    func previewBottomViewDidTapCollapse(_ view: PreviewBottomView)
    /// "N점 사진 N장 더 보기" 탭 (단계 확장)
    func previewBottomViewDidTapExpand(_ view: PreviewBottomView)
}

// MARK: - PreviewBottomView

/// 미리보기 그리드 하단 고정 버튼 영역
///
/// GlassTextButton 스타일로 통일. 현재 단계에 따라 버튼 구성이 변합니다:
/// - 1단계(light): primaryButton + expandButton
/// - 2단계(standard): primaryButton + collapseButton + expandButton (가로)
/// - 3단계(deep): primaryButton + collapseButton (expandButton 숨김)
final class PreviewBottomView: UIView {

    // MARK: - Properties

    weak var delegate: PreviewBottomViewDelegate?

    /// 뷰 전체 높이 (safe area 포함하지 않은 콘텐츠 높이)
    static let contentHeight: CGFloat = 110

    // MARK: - UI Elements

    /// 미리보기 전용 Glass 배경색 (중간회색 15% — iOS 26 현재 화면 전용)
    private static let previewGlassTint = UIColor(white: 0.5, alpha: 0.15)

    /// 메인 정리 버튼 — Glass 스타일, 전체 너비
    private let primaryButton: GlassTextButton = {
        let button = GlassTextButton(
            title: "",
            style: .plain,
            tintColor: .white,
            glassTintColor: PreviewBottomView.previewGlassTint
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 축소 버튼 — Glass pill, 가로 배치 (1개일 때 1줄, 2개일 때 2줄)
    private let collapseButton: GlassTextButton = {
        let button = GlassTextButton(
            title: "",
            style: .plain,
            tintColor: .white,
            multiline: true,
            fontSize: 16,
            glassTintColor: PreviewBottomView.previewGlassTint
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 확장 버튼 — Glass pill, 가로 배치 (1개일 때 1줄, 2개일 때 2줄)
    private let expandButton: GlassTextButton = {
        let button = GlassTextButton(
            title: "",
            style: .plain,
            tintColor: .white,
            multiline: true,
            fontSize: 16,
            glassTintColor: PreviewBottomView.previewGlassTint
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 하단 보조 버튼 가로 스택 (collapse + expand)
    private let secondaryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .fill
        stack.distribution = .fillEqually
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
        // 93% 진한 그레이 배경 — 상단 썸네일(검정)과 구분
        backgroundColor = UIColor(white: 0.09, alpha: 1.0)

        // 상단 구분선
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        // 메인 버튼
        addSubview(primaryButton)

        // 보조 버튼 가로 스택
        secondaryStack.addArrangedSubview(collapseButton)
        secondaryStack.addArrangedSubview(expandButton)
        addSubview(secondaryStack)

        NSLayoutConstraint.activate([
            // 구분선
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            // 메인 버튼: 상단 12pt, 좌우 20pt, 높이 44pt
            primaryButton.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            primaryButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            primaryButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            primaryButton.heightAnchor.constraint(equalToConstant: 44),

            // 보조 스택: 메인 버튼 아래 8pt, 좌우 20pt, 높이 48pt 고정
            secondaryStack.topAnchor.constraint(equalTo: primaryButton.bottomAnchor, constant: 8),
            secondaryStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            secondaryStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            secondaryStack.heightAnchor.constraint(equalToConstant: 48),
        ])

        // 액션 연결
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        collapseButton.addTarget(self, action: #selector(collapseTapped), for: .touchUpInside)
        expandButton.addTarget(self, action: #selector(expandTapped), for: .touchUpInside)

        // iOS 18 이하: Glass 셰이더가 어두운 배경(0.07)에서 투명 → 대체 배경 제공
        if #unavailable(iOS 26) {
            let legacyBg = UIColor(white: 0.25, alpha: 0.3)
            primaryButton.setGlassBackground(legacyBg)
            collapseButton.setGlassBackground(legacyBg)
            expandButton.setGlassBackground(legacyBg)
        }
    }

    // MARK: - Configuration

    /// 하단 뷰 구성
    ///
    /// - Parameters:
    ///   - currentStage: 현재 표시 단계
    ///   - totalCount: 현재 단계까지의 총 개수
    ///   - standardCount: standard 단계 추가분 개수 (약간 낮은 품질)
    ///   - canExpand: 더 확장 가능한지 (standard이면 false)
    func configure(
        currentStage: PreviewStage,
        totalCount: Int,
        standardCount: Int,
        canExpand: Bool
    ) {
        // 메인 버튼: "N장 삭제대기함 이동"
        let primaryTitle: String
        switch currentStage {
        case .light:    primaryTitle = String(localized: "preview.bottom.primary.light \(totalCount)")
        case .standard: primaryTitle = String(localized: "preview.bottom.primary.standard \(totalCount)")
        }
        primaryButton.setButtonTitle(primaryTitle)

        // 보조 버튼 visibility 결정
        let showCollapse = currentStage > .light
        let showExpand = canExpand

        collapseButton.isHidden = !showCollapse
        expandButton.isHidden = !showExpand

        // 둘 다 보이면 2줄, 하나만 보이면 1줄
        let useTwoLines = showCollapse && showExpand

        // 축소 버튼 (standard 단계에서만)
        if showCollapse {
            let separator = useTwoLines ? "\n" : " "
            let collapseTitle: String
            switch currentStage {
            case .standard:
                collapseTitle = String(localized: "preview.bottom.collapse.standard \(separator) \(standardCount)")
            default:
                collapseTitle = ""
            }
            collapseButton.setButtonTitle(collapseTitle)
        }

        // 확장 버튼 (light 단계에서만)
        if showExpand {
            let separator = useTwoLines ? "\n" : " "
            let expandTitle: String
            switch currentStage {
            case .light:
                expandTitle = String(localized: "preview.bottom.expand.standard \(separator) \(standardCount)")
            default:
                expandTitle = ""
            }
            expandButton.setButtonTitle(expandTitle)
        }

        // 둘 다 숨김이면 보조 스택도 숨김 (1단계에서 expand 불가 시)
        secondaryStack.isHidden = !showCollapse && !showExpand

        // 레이아웃 확정 후 블러 오버레이 frame 동기화 (버튼 크기 변경 시 필수)
        layoutIfNeeded()
        LiquidGlassOptimizer.preload(in: self)
    }

    // MARK: - Actions

    @objc private func primaryTapped() {
        delegate?.previewBottomViewDidTapCleanup(self)
    }

    @objc private func collapseTapped() {
        delegate?.previewBottomViewDidTapCollapse(self)
    }

    @objc private func expandTapped() {
        delegate?.previewBottomViewDidTapExpand(self)
    }

    // MARK: - CoachMark D-1 Support

    /// D-1 Step 2: secondaryStack 프레임 (윈도우 좌표)
    /// secondaryStack이 숨겨져 있으면 nil 반환
    func secondaryStackFrameInWindow() -> CGRect? {
        guard let window = window else { return nil }
        guard !secondaryStack.isHidden else { return nil }
        return secondaryStack.convert(secondaryStack.bounds, to: window)
    }

    /// D-1 Step 4: primaryButton 프레임 (윈도우 좌표)
    func primaryButtonFrameInWindow() -> CGRect? {
        guard let window = window else { return nil }
        return primaryButton.convert(primaryButton.bounds, to: window)
    }

    /// D-1 Step 2: expand 버튼 표시 여부
    var isExpandButtonVisible: Bool {
        !expandButton.isHidden
    }
}
