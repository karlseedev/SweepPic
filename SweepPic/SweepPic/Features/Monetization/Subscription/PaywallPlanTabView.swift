//
//  PaywallPlanTabView.swift
//  SweepPic
//
//  페이월 월간/연간 캡슐형 탭 컨트롤
//
//  구조:
//  ┌──────────────────────────────────┐  ← 배경: 캡슐형 (systemGray5)
//  │  ┌──────────┐                    │
//  │  │  월간    │    연간            │  ← 활성 탭: 캡슐형 (white)
//  │  └──────────┘                    │
//  └──────────────────────────────────┘
//
//  UIControl 기반으로 .valueChanged 이벤트 발생
//

import UIKit

// MARK: - PaywallPlanTabView

/// 캡슐 배경 안에 캡슐 인디케이터가 슬라이딩하는 월간/연간 탭
final class PaywallPlanTabView: UIControl {

    // MARK: - Properties

    /// 탭 항목 라벨 텍스트
    private let items = ["월간", "연간"]

    /// 현재 선택된 인덱스 (0: 월간, 1: 연간)
    var selectedSegmentIndex: Int = 0 {
        didSet {
            guard oldValue != selectedSegmentIndex else { return }
            updateSelection(animated: true)
            sendActions(for: .valueChanged)
        }
    }

    // MARK: - UI Components

    /// 배경 캡슐 (systemGray5)
    private let backgroundCapsule: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 활성 탭 인디케이터 캡슐 (white)
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        // 그림자 (미세)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 1)
        view.layer.shadowRadius = 2
        view.layer.masksToBounds = false
        return view
    }()

    /// 탭 라벨들
    private var tabLabels: [UILabel] = []

    /// 연간 탭 "인기" 배지
    private let popularBadge: UILabel = {
        let label = UILabel()
        label.text = "인기"
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .black
        label.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 인디케이터 leading 제약 (애니메이션용)
    private var indicatorLeading: NSLayoutConstraint?
    /// 인디케이터 너비 제약
    private var indicatorWidth: NSLayoutConstraint?

    /// 인디케이터 내부 인셋 (배경과의 간격)
    private let indicatorInset: CGFloat = 4

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // 배경 캡슐
        addSubview(backgroundCapsule)
        NSLayoutConstraint.activate([
            backgroundCapsule.topAnchor.constraint(equalTo: topAnchor),
            backgroundCapsule.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundCapsule.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundCapsule.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 인디케이터 캡슐 (배경 위에)
        backgroundCapsule.addSubview(indicatorView)
        let leading = indicatorView.leadingAnchor.constraint(
            equalTo: backgroundCapsule.leadingAnchor, constant: indicatorInset
        )
        let width = indicatorView.widthAnchor.constraint(equalToConstant: 0) // layoutSubviews에서 계산
        NSLayoutConstraint.activate([
            leading,
            indicatorView.topAnchor.constraint(equalTo: backgroundCapsule.topAnchor, constant: indicatorInset),
            indicatorView.bottomAnchor.constraint(equalTo: backgroundCapsule.bottomAnchor, constant: -indicatorInset),
            width
        ])
        indicatorLeading = leading
        indicatorWidth = width

        // 탭 라벨 생성
        let labelStack = UIStackView()
        labelStack.axis = .horizontal
        labelStack.distribution = .fillEqually
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        for title in items {
            let label = UILabel()
            label.text = title
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            tabLabels.append(label)
            labelStack.addArrangedSubview(label)
        }

        // 라벨 스택 (인디케이터 위에)
        backgroundCapsule.addSubview(labelStack)
        NSLayoutConstraint.activate([
            labelStack.topAnchor.constraint(equalTo: backgroundCapsule.topAnchor),
            labelStack.leadingAnchor.constraint(equalTo: backgroundCapsule.leadingAnchor),
            labelStack.trailingAnchor.constraint(equalTo: backgroundCapsule.trailingAnchor),
            labelStack.bottomAnchor.constraint(equalTo: backgroundCapsule.bottomAnchor)
        ])

        // "인기" 배지 (연간 탭 우상단)
        addSubview(popularBadge)
        NSLayoutConstraint.activate([
            popularBadge.centerYAnchor.constraint(equalTo: backgroundCapsule.topAnchor),
            popularBadge.trailingAnchor.constraint(equalTo: backgroundCapsule.trailingAnchor, constant: -4),
            popularBadge.widthAnchor.constraint(equalToConstant: 32),
            popularBadge.heightAnchor.constraint(equalToConstant: 16)
        ])

        // 탭 제스처
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        // 초기 선택 상태 (애니메이션 없이)
        updateLabelStyles()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let height = bounds.height
        // 배경 캡슐: 좌우 완전 둥근
        backgroundCapsule.layer.cornerRadius = height / 2

        // 인디케이터 캡슐: 내부 높이 기준 완전 둥근
        let indicatorHeight = height - indicatorInset * 2
        indicatorView.layer.cornerRadius = indicatorHeight / 2

        // 인디케이터 너비 = (전체 폭 - 인셋 × 2) / 항목 수
        let totalWidth = bounds.width
        let segmentWidth = (totalWidth - indicatorInset * 2) / CGFloat(items.count)
        indicatorWidth?.constant = segmentWidth

        // 인디케이터 위치 업데이트 (애니메이션 없이)
        indicatorLeading?.constant = indicatorInset + segmentWidth * CGFloat(selectedSegmentIndex)
    }

    // MARK: - Selection

    /// 선택 상태 업데이트 (인디케이터 이동 + 라벨 스타일)
    private func updateSelection(animated: Bool) {
        let totalWidth = bounds.width
        let segmentWidth = (totalWidth - indicatorInset * 2) / CGFloat(items.count)
        let newLeading = indicatorInset + segmentWidth * CGFloat(selectedSegmentIndex)

        indicatorLeading?.constant = newLeading

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.layoutIfNeeded()
            }
        }

        updateLabelStyles()
    }

    /// 라벨 폰트/색상 업데이트
    private func updateLabelStyles() {
        for (index, label) in tabLabels.enumerated() {
            let isSelected = index == selectedSegmentIndex
            label.font = isSelected
                ? .systemFont(ofSize: 15, weight: .semibold)
                : .systemFont(ofSize: 15, weight: .medium)
            label.textColor = isSelected ? .white : .secondaryLabel
        }
    }

    // MARK: - Touch Handling

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isEnabled else { return }
        let location = gesture.location(in: self)
        let segmentWidth = bounds.width / CGFloat(items.count)
        let tappedIndex = Int(location.x / segmentWidth)
        let clampedIndex = max(0, min(tappedIndex, items.count - 1))

        if clampedIndex != selectedSegmentIndex {
            selectedSegmentIndex = clampedIndex
        }
    }
}
