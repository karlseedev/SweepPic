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
import GoogleMobileAds
import AppCore
import OSLog

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

    /// 컨테이너 뷰 (블러 팝업 카드)
    private lazy var containerView = BlurPopupCardView()

    /// 제목 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 19, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
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

    /// 찾은 수 라벨 ("23 / 50장 발견")
    private lazy var foundCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.attributedText = makeFoundCountText(found: 0, max: CleanupConstants.maxFoundCount)
        label.textAlignment = .center
        return label
    }()

    /// 검색 진행률 라벨 ("850 / 2,000장 검색")
    private lazy var scannedCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        let maxFormatted = NumberFormatter.localizedString(
            from: NSNumber(value: CleanupConstants.maxScanCount), number: .decimal
        )
        label.text = "0 / \(maxFormatted)장 검색"
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    /// 탐색 시점 라벨
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "준비 중..."
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
            scannedCountLabel,
            dateLabel,
            cancelButton
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        return stack
    }()

    // MARK: - Banner Ad

    /// 배너 광고 뷰 (분석 대기 화면 하단에 표시, FR-017)
    private var bannerView: GADBannerView?

    /// 배너 높이 제약조건 (로드 성공 시 확장)
    private var bannerHeightConstraint: NSLayoutConstraint?

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
        backgroundColor = UIColor.black.withAlphaComponent(0.5)

        addSubview(containerView)
        containerView.contentView.addSubview(stackView)

        // scannedCountLabel — dateLabel 사이 간격을 좁힘 (연관 정보)
        stackView.setCustomSpacing(4, after: scannedCountLabel)

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

    // MARK: - Banner Ad Setup

    /// 배너 광고 설정 (Plus/Grace 시 미표시)
    /// rootViewController 필요 → show(in:) 시점에 호출
    private func setupBannerAd(rootViewController: UIViewController?) {
        Logger.app.debug("CleanupProgressView: setupBannerAd 호출 — shouldShowAds=\(AdManager.shared.shouldShowAds()), rootVC=\(String(describing: rootViewController)), SDK초기화=\(AdManager.shared.isConfigured)")
        guard AdManager.shared.shouldShowAds() else {
            Logger.app.debug("CleanupProgressView: shouldShowAds=false → 배너 미생성")
            return
        }
        guard let rootVC = rootViewController else {
            Logger.app.debug("CleanupProgressView: rootVC=nil → 배너 미생성")
            return
        }

        let banner = GADBannerView()
        banner.adUnitID = AdManager.bannerAdUnitID
        banner.rootViewController = rootVC
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false

        addSubview(banner)

        // 초기 높이 0 (로드 성공 시 확장)
        let height = banner.heightAnchor.constraint(equalToConstant: 0)
        bannerHeightConstraint = height

        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: trailingAnchor),
            banner.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),
            height
        ])

        self.bannerView = banner

        // 표준 배너 크기 사용 (320×50) — 레이아웃 전이라 Adaptive 사이즈 계산 불가
        banner.adSize = GADAdSizeBanner
        bannerHeightConstraint?.constant = GADAdSizeBanner.size.height

        banner.load(GADRequest())

        Logger.app.debug("CleanupProgressView: 배너 광고 로드 요청 (size=320×50, rootVC=\(String(describing: rootVC)))")
    }

    /// 배너 광고 제거
    private func removeBannerAd() {
        bannerView?.removeFromSuperview()
        bannerView = nil
        bannerHeightConstraint = nil
    }

    // MARK: - Public Methods

    /// 정리 방식 설정
    /// - Parameter method: 정리 방식 (날짜 표시 형식에 영향)
    func configure(method: CleanupMethod) {
        self.method = method

        let mainTitle = "저품질 사진 탐색 중"
        let subTitle: String

        switch method {
        case .fromLatest:
            subTitle = "최신 사진부터"
        case .continueFromLast:
            subTitle = "이어서 탐색"
        case .byYear(let year, _):
            subTitle = "\(year)년"
        }

        let mainAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 19, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let subAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]

        let fullTitle = NSMutableAttributedString(string: mainTitle, attributes: mainAttributes)
        fullTitle.append(NSAttributedString(string: "\n(\(subTitle))", attributes: subAttributes))

        // 행간 및 정렬 설정
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .center
        fullTitle.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: fullTitle.length))

        titleLabel.attributedText = fullTitle
    }

    /// 진행 상황 업데이트
    /// - Parameter progress: 진행 상황
    func update(with progress: CleanupProgress) {
        // 진행바
        progressBar.setProgress(progress.progress, animated: true)

        // 찾은 수 ("23 / 50장 발견") — "/" 는 regular 굵기
        foundCountLabel.attributedText = makeFoundCountText(
            found: progress.foundCount,
            max: progress.maxFoundCount
        )

        // 검색 진행률 ("850 / 2,000장 검색")
        let scannedFormatted = NumberFormatter.localizedString(
            from: NSNumber(value: progress.scannedCount), number: .decimal
        )
        let maxScanFormatted = NumberFormatter.localizedString(
            from: NSNumber(value: progress.maxScanCount), number: .decimal
        )
        scannedCountLabel.text = "\(scannedFormatted) / \(maxScanFormatted)장 검색"

        // 탐색 시점 (모든 모드에서 동일한 형식)
        let dateString = formatDate(progress.currentDate)
        dateLabel.text = dateString.isEmpty ? "" : "\(dateString) 사진 확인 중..."
    }

    /// 뷰 표시 (애니메이션)
    /// - Parameters:
    ///   - parentView: 부모 뷰
    ///   - viewController: 배너 광고의 rootViewController (GADBannerView에 필요)
    func show(in parentView: UIView, viewController: UIViewController? = nil) {
        alpha = 0
        containerView.activateBlur()
        parentView.addSubview(self)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parentView.topAnchor),
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])

        // [BM] 배너 광고 표시 (분석 대기 중, FR-017)
        setupBannerAd(rootViewController: viewController)

        UIView.animate(withDuration: 0.25) {
            self.alpha = 1
        }
    }

    /// 뷰 숨김 (애니메이션)
    /// - Parameter completion: 완료 콜백
    func hide(completion: (() -> Void)? = nil) {
        // [BM] 배너 광고 제거
        removeBannerAd()

        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
        }) { _ in
            self.containerView.deactivateBlur()
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

    /// "23 / 50장 발견" AttributedString 생성
    /// - "23"과 "50장 발견"은 28pt bold, "/"는 28pt regular
    private func makeFoundCountText(found: Int, max: Int) -> NSAttributedString {
        let bold: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let regular: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .regular),
            .foregroundColor: UIColor.label,
            .baselineOffset: 2
        ]

        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "\(found) ", attributes: bold))
        result.append(NSAttributedString(string: "/ ", attributes: regular))
        result.append(NSAttributedString(string: "\(max)장 발견", attributes: bold))
        return result
    }

    // MARK: - Actions

    @objc private func cancelButtonTapped() {
        delegate?.cleanupProgressViewDidTapCancel(self)
    }
}

// MARK: - GADBannerViewDelegate

extension CleanupProgressView: GADBannerViewDelegate {

    /// 배너 광고 로드 성공
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        Logger.app.debug("CleanupProgressView: 배너 광고 로드 성공")
    }

    /// 배너 광고 로드 실패 → 높이 0 유지 (숨김)
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        bannerHeightConstraint?.constant = 0
        Logger.app.error("CleanupProgressView: 배너 광고 로드 실패 — \(error.localizedDescription)")
    }
}
