//
//  BannerAdViewController.swift
//  PickPhoto
//
//  배너 광고 컨테이너 뷰컨트롤러
//  사진 분석 대기 화면(CleanupProgressView) 하단에 삽입 가능
//
//  역할:
//  - GADBannerView 래핑 (Adaptive Banner)
//  - Plus 시 자동 미표시
//  - 부모 뷰에 embed하여 사용
//  - 광고 로드 실패 시 높이 0으로 숨김 (FR-017)
//

import UIKit
import GoogleMobileAds
import AppCore
import OSLog

// MARK: - BannerAdViewController

/// 배너 광고 컨테이너 뷰컨트롤러
/// embed(in:containerView:) 또는 addBanner(to:) 방식으로 부모 뷰에 삽입
final class BannerAdViewController: UIViewController {

    // MARK: - Properties

    /// 배너 광고 뷰
    private var bannerView: GADBannerView?

    /// 배너 높이 제약조건 (로드 실패 시 0으로 설정)
    private var heightConstraint: NSLayoutConstraint?

    /// 광고 로드 완료 여부
    private(set) var isAdLoaded = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        // Plus 구독자 시 배너 미표시
        guard AdManager.shared.shouldShowAds() else {
            Logger.app.debug("BannerAdViewController: 광고 미표시 조건 (Plus)")
            return
        }

        setupBannerView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadBannerAd()
    }

    // MARK: - Setup

    /// 배너 뷰 초기화 및 레이아웃 설정
    private func setupBannerView() {
        let banner = GADBannerView()
        banner.adUnitID = AdManager.bannerAdUnitID
        banner.rootViewController = self
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(banner)

        // 초기 높이 0 (로드 성공 시 확장)
        let height = banner.heightAnchor.constraint(equalToConstant: 0)
        self.heightConstraint = height

        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height
        ])

        self.bannerView = banner
    }

    // MARK: - Load

    /// 배너 광고 로드 (Adaptive Banner 크기 사용)
    private func loadBannerAd() {
        guard let banner = bannerView else { return }

        // Adaptive Banner: 화면 너비에 맞는 최적 크기 계산
        let viewWidth = view.frame.inset(by: view.safeAreaInsets).width
        guard viewWidth > 0 else { return }

        banner.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
        banner.load(GADRequest())

        Logger.app.debug("BannerAdViewController: 배너 광고 로드 요청 (width=\(viewWidth))")
    }

    // MARK: - Embed Helper

    /// 부모 뷰컨트롤러에 배너 광고를 embed (Child VC 패턴)
    /// - Parameters:
    ///   - parent: 부모 ViewController
    ///   - containerView: 배너가 삽입될 컨테이너 뷰
    func embed(in parent: UIViewController, containerView: UIView) {
        // Plus/Grace 체크 — 불필요하면 embed 자체 스킵
        guard AdManager.shared.shouldShowAds() else { return }

        parent.addChild(self)
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: containerView.topAnchor),
            view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        didMove(toParent: parent)
    }

    /// 배너 광고 제거 (Child VC 패턴)
    func removeBanner() {
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()

        bannerView?.removeFromSuperview()
        bannerView = nil
        isAdLoaded = false
    }
}

// MARK: - GADBannerViewDelegate

extension BannerAdViewController: GADBannerViewDelegate {

    /// 배너 광고 로드 성공 → 높이 확장 (애니메이션)
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        isAdLoaded = true

        // [BM] 배너 광고 노출 이벤트 (FR-056, §11)
        AnalyticsService.shared.trackAdWatched(type: .banner, source: "analysis")

        // Adaptive Banner 높이로 확장
        let adHeight = bannerView.adSize.size.height
        heightConstraint?.constant = adHeight

        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }

        Logger.app.debug("BannerAdViewController: 배너 광고 로드 성공 (height=\(adHeight))")
    }

    /// 배너 광고 로드 실패 → 높이 0 유지 (숨김)
    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        isAdLoaded = false
        heightConstraint?.constant = 0

        Logger.app.error("BannerAdViewController: 배너 광고 로드 실패 — \(error.localizedDescription)")
    }
}
