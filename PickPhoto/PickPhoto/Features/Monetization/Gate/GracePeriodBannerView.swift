//
//  GracePeriodBannerView.swift
//  PickPhoto
//
//  Grace Period 중 삭제대기함 상단에 표시되는 안내 배너
//  게이지 위치에 대체 표시됨
//
//  모든 Day에서 동일한 UI: "무료 체험 중 — N일 남음" (FR-024)
//
//  배너 탭 → 체험 종료 후 안내 팝업 (GracePeriodDetailPopup)
//

import UIKit
import AppCore
import LiquidGlassKit
import OSLog

// MARK: - GracePeriodBannerView

/// Grace Period 안내 배너
/// 삭제대기함 상단, 게이지 자리에 표시
final class GracePeriodBannerView: UIView {

    // MARK: - Callbacks

    /// 배너 탭 시 콜백 (상세 팝업 표시용)
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

    /// 메인 텍스트 라벨: "무료 체험 중 — N일 남음"
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 설명 라벨: "체험 종료 후 일일 무료 삭제 한도가 적용됩니다"
    private let descLabel: UILabel = {
        let label = UILabel()
        label.text = "체험 종료 후 일일 무료 삭제 한도가 적용됩니다"
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

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

        // Glass 뷰: 전체 영역 채움
        NSLayoutConstraint.activate([
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 콘텐츠는 glassView.contentView에 추가
        let cardContent = glassView.contentView
        cardContent.addSubview(titleLabel)
        cardContent.addSubview(descLabel)

        let hPadding: CGFloat = 14
        let vPadding: CGFloat = 12

        // 타이틀 + 설명 라벨 레이아웃 → 카드 크기 결정
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardContent.topAnchor, constant: vPadding),
            titleLabel.leadingAnchor.constraint(equalTo: cardContent.leadingAnchor, constant: hPadding),
            titleLabel.trailingAnchor.constraint(equalTo: cardContent.trailingAnchor, constant: -hPadding),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: cardContent.leadingAnchor, constant: hPadding),
            descLabel.trailingAnchor.constraint(equalTo: cardContent.trailingAnchor, constant: -hPadding),
            descLabel.bottomAnchor.constraint(equalTo: cardContent.bottomAnchor, constant: -vPadding)
        ])
    }

    /// 탭 제스처 설정 (배너 전체 탭 → 상세 팝업)
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

        // 접근성 (FR-057)
        isAccessibilityElement = true
        accessibilityLabel = "무료 체험 중, \(remaining)일 남음"
        accessibilityHint = "탭하면 체험 종료 후 안내를 볼 수 있습니다"

        Logger.app.debug("GracePeriodBanner: Day \(currentDay), 남은 \(remaining)일")
    }

    // MARK: - Actions

    @objc private func bannerTapped() {
        onTap?()
    }
}

// MARK: - GracePeriodDetailPopup

/// Grace Period 배너 탭 시 표시되는 상세 팝업
/// UsageGaugeDetailPopup과 동일한 디자인 (BlurPopupCardView + 반투명 버튼 + 흰색 텍스트)
final class GracePeriodDetailPopup: UIViewController {

    // MARK: - UI

    /// 딤 배경 (터치 차단용, 투명)
    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 블러 팝업 카드
    private let cardView = BlurPopupCardView()

    /// 제목 라벨: "무료 체험 중(N일 남음)"
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 한도 안내 라벨: "무료 체험이 끝나면\n최대 30장의 무료 삭제 한도가 적용됩니다"
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Plus 안내 라벨: "Plus 구독으로 제한없이 정리가 가능해요"
    private let plusLabel: UILabel = {
        let label = UILabel()
        label.text = "Plus 구독으로 제한없이 정리가 가능해요"
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 닫기 버튼 — 반투명 흰색 배경 + 회색 텍스트
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("닫기", for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
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
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        setupUI()
        cardView.activateBlur()
        configureContent()
    }

    // MARK: - Setup

    private func setupUI() {
        // 딤 배경 (전체 화면)
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 블러 카드 — 중앙 배치
        view.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        // 카드 내부 스택뷰
        let stack = UIStackView(arrangedSubviews: [titleLabel, statusLabel, plusLabel, closeButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        // 버튼 영역 전 여유 간격
        stack.setCustomSpacing(28, after: plusLabel)

        cardView.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 36),
            stack.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -32),
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // 액션
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let dimTap = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        dimView.addGestureRecognizer(dimTap)
    }

    /// 현재 Grace Period 상태로 콘텐츠 구성
    private func configureContent() {
        let remaining = GracePeriodService.shared.remainingDays

        // 제목
        titleLabel.text = "무료 체험 중(\(remaining)일 남음)"

        // 한도 안내 (최대 = 기본 한도 + 리워드 보너스 전량)
        let maxDaily = UsageLimit.maxDailyTotal
        statusLabel.text = "무료 체험이 끝나면 일 최대 \(maxDaily)장의\n무료 삭제 한도가 적용됩니다"

        // 접근성
        titleLabel.accessibilityLabel = "무료 체험 중, \(remaining)일 남음"
        statusLabel.accessibilityLabel = statusLabel.text
        plusLabel.accessibilityLabel = plusLabel.text
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
