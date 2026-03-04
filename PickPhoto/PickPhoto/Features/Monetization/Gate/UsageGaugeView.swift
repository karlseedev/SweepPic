//
//  UsageGaugeView.swift
//  PickPhoto
//
//  일일 삭제 한도 게이지 바 + "N/M장 남음" 텍스트
//  삭제대기함 상단에 표시
//
//  탭 시 상세 팝업 (한도 상태 + 광고 잔여 + "광고 보기" 버튼)
//  Plus/Grace Period 시 미표시
//  accessibilityLabel 설정 (FR-057)
//

import UIKit
import AppCore
import OSLog

// MARK: - UsageGaugeView

/// 일일 삭제 한도 프로그레스 게이지
final class UsageGaugeView: UIView {

    // MARK: - Callbacks

    /// 게이지 탭 시 콜백
    var onTap: (() -> Void)?

    // MARK: - UI Components

    /// 흰색 둥근 배경 카드
    private let backgroundCard: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.95)
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 1)
        view.layer.shadowRadius = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 프로그레스 바 배경
    private let trackView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 프로그레스 바 채움
    private let fillView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 남은 장수 라벨: "N/M장 남음"
    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 프로그레스 채움 너비 제약조건
    private var fillWidthConstraint: NSLayoutConstraint?

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

    /// 레이아웃 구성
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        // 배경 카드
        addSubview(backgroundCard)

        // 프로그레스 트랙 (카드 내부)
        backgroundCard.addSubview(trackView)
        trackView.addSubview(fillView)

        // 라벨 (카드 내부)
        backgroundCard.addSubview(countLabel)

        // 배경 카드: 전체 영역 채움
        NSLayoutConstraint.activate([
            backgroundCard.topAnchor.constraint(equalTo: topAnchor),
            backgroundCard.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundCard.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundCard.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 카드 내부 패딩
        let hPadding: CGFloat = 12
        let vPadding: CGFloat = 10

        // 프로그레스 트랙 레이아웃
        NSLayoutConstraint.activate([
            trackView.topAnchor.constraint(equalTo: backgroundCard.topAnchor, constant: vPadding),
            trackView.leadingAnchor.constraint(equalTo: backgroundCard.leadingAnchor, constant: hPadding),
            trackView.trailingAnchor.constraint(equalTo: backgroundCard.trailingAnchor, constant: -hPadding),
            trackView.heightAnchor.constraint(equalToConstant: 8)
        ])

        // 채움 뷰 레이아웃 (너비는 update에서 설정)
        let widthConstraint = fillView.widthAnchor.constraint(equalToConstant: 0)
        fillWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            fillView.topAnchor.constraint(equalTo: trackView.topAnchor),
            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            widthConstraint
        ])

        // 라벨 레이아웃
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            countLabel.trailingAnchor.constraint(equalTo: backgroundCard.trailingAnchor, constant: -hPadding),
            countLabel.bottomAnchor.constraint(equalTo: backgroundCard.bottomAnchor, constant: -vPadding)
        ])

        // 전체 높이 = vPadding(10) + 트랙(8) + 간격(4) + 라벨(~15) + vPadding(10) ≈ 47
        heightAnchor.constraint(equalToConstant: 47).isActive = true
    }

    /// 탭 제스처 설정
    private func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - Update

    /// 게이지 업데이트
    /// - Parameters:
    ///   - remaining: 남은 무료 삭제 수
    ///   - total: 총 한도 (기본 + 리워드 보너스 포함)
    func update(remaining: Int, total: Int) {
        // 비율 계산 (0~1)
        let fraction = total > 0 ? CGFloat(remaining) / CGFloat(total) : 0

        // 색상 결정: 많이 남음(파랑) → 적음(주황) → 거의 없음(빨강)
        if fraction > 0.5 {
            fillView.backgroundColor = .systemBlue
        } else if fraction > 0.2 {
            fillView.backgroundColor = .systemOrange
        } else {
            fillView.backgroundColor = .systemRed
        }

        // 라벨 업데이트
        countLabel.text = "\(remaining)/\(total)장 남음"

        // 프로그레스 바 업데이트 (layoutIfNeeded 후 트랙 너비 기반)
        setNeedsLayout()
        layoutIfNeeded()

        let trackWidth = trackView.bounds.width
        fillWidthConstraint?.constant = trackWidth * fraction

        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }

        // 접근성 업데이트 (FR-057)
        accessibilityLabel = "삭제 한도 게이지, \(total)장 중 \(remaining)장 남음"
        accessibilityHint = "탭하면 한도 상세 정보를 볼 수 있습니다"
        isAccessibilityElement = true
    }
}

// MARK: - UsageGaugeDetailPopup

/// 게이지 탭 시 표시되는 상세 팝업
/// 한도 상태 + 광고 잔여 + "광고 보기" 버튼
final class UsageGaugeDetailPopup: UIViewController {

    // MARK: - Callbacks

    /// "광고 보기" 탭 시
    var onWatchAd: (() -> Void)?

    // MARK: - UI

    /// 반투명 배경
    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 카드
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 한도 정보 라벨
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 광고 보기 버튼
    private let watchAdButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("광고 보고 +10장 추가", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 닫기 버튼
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("닫기", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureContent()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 48)
        ])

        let stack = UIStackView(arrangedSubviews: [statusLabel, watchAdButton, closeButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            watchAdButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // 액션
        watchAdButton.addTarget(self, action: #selector(watchAdTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let dimTap = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        dimView.addGestureRecognizer(dimTap)
    }

    /// 현재 한도 정보로 콘텐츠 구성
    private func configureContent() {
        let remaining = UsageLimitStore.shared.remainingFreeDeletes
        let total = UsageLimitStore.shared.totalDailyCapacity
        let rewardsLeft = UsageLimitStore.shared.remainingRewards

        var text = "오늘 삭제 한도: \(remaining)/\(total)장"
        if rewardsLeft > 0 {
            text += "\n광고 시청 가능: \(rewardsLeft)회 (회당 +10장)"
        } else {
            text += "\n오늘 광고 시청 횟수를 모두 사용했습니다"
            watchAdButton.isHidden = true
        }
        statusLabel.text = text

        // 접근성
        statusLabel.accessibilityLabel = text
        watchAdButton.accessibilityLabel = "광고를 보고 삭제 한도 10장 추가"
    }

    @objc private func watchAdTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onWatchAd?()
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
