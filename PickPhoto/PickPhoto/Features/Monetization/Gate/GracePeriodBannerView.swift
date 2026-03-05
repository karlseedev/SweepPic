//
//  GracePeriodBannerView.swift
//  PickPhoto
//
//  Grace Period 중 삭제대기함 상단에 표시되는 안내 배너
//  게이지 위치에 대체 표시됨
//
//  단계별 UI (FR-024):
//  - Day 0~1: 정보만 ("무료 체험 중 — N일 남음")
//  - Day 2: 텍스트 링크 ("Plus로 계속 무제한 사용 →")
//  - Day 3: CTA 버튼 ([Plus로 무제한 계속하기])
//
//  배너 탭 → 페이월 (FR-025, 페이월은 US4에서 구현 — 탭 핸들러만 준비)
//

import UIKit
import AppCore
import OSLog

// MARK: - GracePeriodBannerView

/// Grace Period 안내 배너
/// 삭제대기함 상단, 게이지 자리에 표시
final class GracePeriodBannerView: UIView {

    // MARK: - Callbacks

    /// 배너 또는 CTA 탭 시 콜백 (페이월 이동용)
    var onTapPaywall: (() -> Void)?

    // MARK: - UI Components

    /// 흰색 둥근 배경 카드 (UsageGaugeView와 동일 스타일)
    private let backgroundCard: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 1)
        view.layer.shadowRadius = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 메인 텍스트 라벨: "무료 체험 중 — N일 남음"
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Day 2 텍스트 링크: "Plus로 계속 무제한 사용 →"
    private let linkLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemBlue
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Day 3 CTA 버튼: [Plus로 무제한 계속하기]
    private let ctaButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Plus로 무제한 계속하기", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.layer.cornerRadius = 8
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 전체 콘텐츠 스택 (타이틀 + 링크 + CTA)
    /// UIStackView는 hidden된 arrangedSubview의 공간을 자동 제거
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// CTA 높이 제약 (hidden 시에도 intrinsic 유지를 위해 명시)
    private var ctaHeightConstraint: NSLayoutConstraint?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGesture()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(backgroundCard)

        // 배경 카드: 전체 영역 채움
        NSLayoutConstraint.activate([
            backgroundCard.topAnchor.constraint(equalTo: topAnchor),
            backgroundCard.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundCard.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundCard.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 콘텐츠 스택에 모든 요소 추가
        // UIStackView는 hidden된 arrangedSubview의 공간을 자동 제거하므로
        // Day 0~1에서 linkLabel/ctaButton이 hidden이면 자동으로 컴팩트해짐
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(linkLabel)
        contentStack.addArrangedSubview(ctaButton)

        backgroundCard.addSubview(contentStack)

        let hPadding: CGFloat = 14
        let vPadding: CGFloat = 12

        // CTA 높이 제약
        let heightConstraint = ctaButton.heightAnchor.constraint(equalToConstant: 36)
        ctaHeightConstraint = heightConstraint

        // 콘텐츠 스택 레이아웃 → 카드 크기 결정
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: backgroundCard.topAnchor, constant: vPadding),
            contentStack.leadingAnchor.constraint(equalTo: backgroundCard.leadingAnchor, constant: hPadding),
            contentStack.trailingAnchor.constraint(equalTo: backgroundCard.trailingAnchor, constant: -hPadding),
            contentStack.bottomAnchor.constraint(equalTo: backgroundCard.bottomAnchor, constant: -vPadding),
            heightConstraint
        ])

        ctaButton.addTarget(self, action: #selector(ctaTapped), for: .touchUpInside)
    }

    /// 탭 제스처 설정 (배너 전체 탭 → 페이월)
    private func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(bannerTapped))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    // MARK: - Configuration

    /// Grace Period 현재 상태로 배너 구성
    func configure() {
        let currentDay = GracePeriodService.shared.currentDay
        let remaining = GracePeriodService.shared.remainingDays

        // 메인 타이틀
        titleLabel.text = "무료 체험 중 — \(remaining)일 남음"

        // 단계별 UI 분기 (FR-024)
        switch currentDay {
        case 0, 1:
            // Day 0~1: 정보만 표시 (링크/CTA 숨김 → 스택이 자동 공간 제거)
            linkLabel.isHidden = true
            ctaButton.isHidden = true

        case 2:
            // Day 2: 텍스트 링크 추가
            linkLabel.text = "Plus로 계속 무제한 사용 →"
            linkLabel.isHidden = false
            ctaButton.isHidden = true

        default:
            // Day 3 (마지막 날): CTA 버튼으로 격상
            linkLabel.isHidden = true
            ctaButton.isHidden = false
        }

        // 접근성 (FR-057)
        isAccessibilityElement = true
        accessibilityLabel = "무료 체험 중, \(remaining)일 남음"
        if currentDay >= 2 {
            accessibilityHint = "탭하면 Plus 구독 화면으로 이동합니다"
        }

        Logger.app.debug("GracePeriodBanner: Day \(currentDay), 남은 \(remaining)일")
    }

    // MARK: - Actions

    @objc private func bannerTapped() {
        onTapPaywall?()
    }

    @objc private func ctaTapped() {
        onTapPaywall?()
    }
}
