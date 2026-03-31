//
//  UsageGaugeView.swift
//  SweepPic
//
//  일일 삭제 한도 게이지 바 + "N/M장 남음" 텍스트
//  삭제대기함 상단에 표시
//
//  탭 시 상세 팝업 (한도 상태 + 광고 잔여 + "광고 보기" 버튼)
//  Pro 시 미표시
//  accessibilityLabel 설정 (FR-057)
//

import UIKit
import AppCore
import LiquidGlassKit
import OSLog

// MARK: - UsageGaugeView

/// 일일 삭제 한도 프로그레스 게이지
final class UsageGaugeView: UIView {

    // MARK: - Callbacks

    /// 게이지 탭 시 콜백
    var onTap: (() -> Void)?

    // MARK: - UI Components

    /// Glass 효과 배경 (iOS 18~25: LiquidGlassKit Metal, iOS 26+: 네이티브 UIGlassEffect)
    private lazy var glassView: AnyVisualEffectView = {
        let effect = LiquidGlassEffect(style: .regular, isNative: true)
        effect.tintColor = UIColor(white: 0.5, alpha: 0.2)
        let view = VisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()

    /// 프로그레스 바 배경
    private let trackView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 프로그레스 바 채움
    private let fillView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 타이틀 라벨: "오늘 삭제한도"
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "무료 삭제 한도"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 남은 장수 라벨: "N/M장 남음"
    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .white
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

    // MARK: - Lifecycle

    /// iOS 18~25: LiquidGlassOptimizer preload (Metal 렌더링 초기화)
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if #available(iOS 26.0, *) { return }
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                LiquidGlassOptimizer.preload(in: self)
            }
        }
    }

    // MARK: - UI Setup

    /// 레이아웃 구성
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        // 그림자 (Glass 깊이감)
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 2)

        // 딤 배경 (Glass 뷰 아래)
        let dimLayer = UIView()
        dimLayer.backgroundColor = UIColor(white: 0.1, alpha: 0.5)
        dimLayer.layer.cornerRadius = 12
        dimLayer.layer.cornerCurve = .continuous
        dimLayer.clipsToBounds = true
        dimLayer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimLayer)
        NSLayoutConstraint.activate([
            dimLayer.topAnchor.constraint(equalTo: topAnchor),
            dimLayer.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimLayer.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimLayer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Glass 효과 배경 (딤 위)
        addSubview(glassView)

        // 콘텐츠는 glassView.contentView에 추가
        let cardContent = glassView.contentView
        cardContent.addSubview(trackView)
        trackView.addSubview(fillView)
        cardContent.addSubview(titleLabel)
        cardContent.addSubview(countLabel)

        // Glass 뷰: 전체 영역 채움
        NSLayoutConstraint.activate([
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 카드 내부 패딩
        let hPadding: CGFloat = 12
        let vPaddingTop: CGFloat = 12
        let vPadding: CGFloat = 10

        // 프로그레스 트랙 레이아웃
        NSLayoutConstraint.activate([
            trackView.topAnchor.constraint(equalTo: cardContent.topAnchor, constant: vPaddingTop),
            trackView.leadingAnchor.constraint(equalTo: cardContent.leadingAnchor, constant: hPadding),
            trackView.trailingAnchor.constraint(equalTo: cardContent.trailingAnchor, constant: -hPadding),
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

        // 타이틀 라벨 (좌측 하단)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: cardContent.leadingAnchor, constant: hPadding),
            titleLabel.bottomAnchor.constraint(equalTo: cardContent.bottomAnchor, constant: -vPadding)
        ])

        // 카운트 라벨 (우측 하단)
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            countLabel.trailingAnchor.constraint(equalTo: cardContent.trailingAnchor, constant: -hPadding),
            countLabel.bottomAnchor.constraint(equalTo: cardContent.bottomAnchor, constant: -vPadding)
        ])

        // 전체 높이 = vPaddingTop(12) + 트랙(8) + 간격(4) + 라벨(~19) + vPadding(10) ≈ 52
        heightAnchor.constraint(equalToConstant: 52).isActive = true
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

        // 게이지 색상: 흰색
        fillView.backgroundColor = .white

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
/// 게이트 팝업과 동일한 디자인 포맷 (BlurPopupCardView + 반투명 버튼 + 흰색 텍스트)
final class UsageGaugeDetailPopup: UIViewController {

    // MARK: - Callbacks

    /// "광고 보기" 탭 시
    var onWatchAd: (() -> Void)?

    /// "Plus로 무제한" 탭 시
    var onProUpgrade: (() -> Void)?

    // MARK: - UI

    /// 블러 팝업 카드 (게이트와 동일)
    private let cardView = BlurPopupCardView()

    /// 제목 라벨 — 흰색 텍스트
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "오늘의 삭제 한도"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 한도 정보 라벨 — 반투명 흰색
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 광고 보기 버튼 — 반투명 흰색 배경 + 흰색 텍스트
    private let watchAdButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("광고 보고 +10장 추가", for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Pro 구독 버튼 — 반투명 흰색 배경 + 흰색 텍스트
    private let proButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Pro로 무제한", for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 닫기 버튼 — 반투명 흰색 배경 + 회색 텍스트
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("닫기", for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Referral Promo (T033, US4)

    /// 초대 프로모 하단 배경 — 카드 하단을 가로로 잘라 색상 차별화
    private let referralPromoBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 초대 프로모 안내 라벨
    private let referralPromoLabel: UILabel = {
        let label = UILabel()
        label.text = "초대 한 번마다 나도 친구도\n14일 프리미엄 무료 제공!"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 초대하기 버튼 — 다른 버튼과 동일 높이 50pt
    private let referralButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitle("친구 초대하기", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 초대 부가 문구
    private let referralSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "이미 구독 중이어도 14일 무료 연장"
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.4)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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

    /// 배경 블러 (딤드 위에 20% 강도 블러)
    private let backgroundBlurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 블러 강도 제어용 애니메이터 (fractionComplete로 0.0~1.0 조절)
    private lazy var blurAnimator: UIViewPropertyAnimator = {
        let animator = UIViewPropertyAnimator(duration: 0, curve: .linear) { [weak self] in
            self?.backgroundBlurView.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        animator.fractionComplete = 0.1
        animator.pausesOnCompletion = true
        return animator
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        setupUI()
        _ = blurAnimator // 블러 20% 적용
        cardView.activateBlur()
        configureContent()
    }

    // MARK: - Setup

    private func setupUI() {
        // 배경 블러 — 딤드 위에 연한 블러 추가
        view.addSubview(backgroundBlurView)
        NSLayoutConstraint.activate([
            backgroundBlurView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 블러 카드 — 게이트와 동일 레이아웃
        view.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        // T033: 카드 하단 배경 — contentView에 먼저 삽입
        cardView.contentView.addSubview(referralPromoBackground)

        // 카드 내부 스택뷰 — contentView에 추가 (블러 위)
        let stack = UIStackView(arrangedSubviews: [
            titleLabel, statusLabel, watchAdButton, proButton, closeButton,
            referralPromoLabel, referralButton, referralSubtitleLabel
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        // 버튼 영역 전 여유 간격
        stack.setCustomSpacing(28, after: statusLabel)
        stack.setCustomSpacing(10, after: watchAdButton)
        stack.setCustomSpacing(10, after: proButton)

        cardView.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 36),
            stack.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -32),
            watchAdButton.heightAnchor.constraint(equalToConstant: 50),
            proButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // T033: 닫기 버튼과 초대 프로모 간격
        stack.setCustomSpacing(34, after: closeButton)
        stack.setCustomSpacing(8, after: referralPromoLabel)
        stack.setCustomSpacing(4, after: referralButton)

        referralButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        // T033: 배경 뷰 — 프로모 라벨 위에서 카드 하단 끝까지
        NSLayoutConstraint.activate([
            referralPromoBackground.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor),
            referralPromoBackground.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor),
            referralPromoBackground.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor),
            referralPromoBackground.topAnchor.constraint(equalTo: referralPromoLabel.topAnchor, constant: -16)
        ])

        // 액션
        watchAdButton.addTarget(self, action: #selector(watchAdTapped), for: .touchUpInside)
        proButton.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        // T033: 초대 프로모 버튼 액션
        referralButton.addTarget(self, action: #selector(referralTapped), for: .touchUpInside)

        // 배경 탭 → 닫기
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        view.addGestureRecognizer(dimTap)
    }

    /// 현재 한도 정보로 콘텐츠 구성
    private func configureContent() {
        let remaining = UsageLimitStore.shared.remainingFreeDeletes
        let total = UsageLimitStore.shared.totalDailyCapacity
        let rewardsLeft = UsageLimitStore.shared.remainingRewards

        var text = "\(remaining)/\(total)장 남음"
        if rewardsLeft > 0 {
            text += "\n광고 시청 가능: \(rewardsLeft)회 (회당 +10장)"
        } else {
            text += "\n오늘 광고 시청 횟수를 모두 사용했습니다"
            watchAdButton.isHidden = true
        }
        statusLabel.text = text

        // 접근성 (FR-057)
        statusLabel.accessibilityLabel = text
        watchAdButton.accessibilityLabel = "광고를 보고 삭제 한도 10장 추가"
        proButton.accessibilityLabel = "Pro 구독으로 삭제 한도 무제한"
        closeButton.accessibilityLabel = "닫기"
        closeButton.accessibilityHint = "한도 상세 팝업을 닫습니다"
        // T033: 초대 프로모 접근성
        referralPromoLabel.accessibilityLabel = "초대 한 번마다 나도 친구도 14일 프리미엄 무료 제공"
        referralButton.accessibilityLabel = "친구 초대하기"
        referralButton.accessibilityHint = "초대 설명 화면으로 이동합니다"
        referralSubtitleLabel.accessibilityLabel = "이미 구독 중이어도 14일 무료 연장"
    }

    @objc private func watchAdTapped() {
        blurAnimator.stopAnimation(true)
        dismiss(animated: true) { [weak self] in
            self?.onWatchAd?()
        }
    }

    @objc private func plusTapped() {
        blurAnimator.stopAnimation(true)
        dismiss(animated: true) { [weak self] in
            self?.onProUpgrade?()
        }
    }

    @objc private func closeTapped() {
        blurAnimator.stopAnimation(true)
        dismiss(animated: true)
    }

    /// T033: 초대 프로모 버튼 탭 → ReferralExplainViewController 모달
    @objc private func referralTapped() {
        Logger.app.debug("UsageGaugeDetailPopup: 초대 프로모 버튼 탭")
        blurAnimator.stopAnimation(true)
        let presenter = presentingViewController
        dismiss(animated: true) {
            guard let presenter = presenter else { return }
            let referralVC = ReferralExplainViewController()
            presenter.present(referralVC, animated: true)
        }
    }
}
