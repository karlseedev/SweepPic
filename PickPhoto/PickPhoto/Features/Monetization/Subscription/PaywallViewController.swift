//
//  PaywallViewController.swift
//  PickPhoto
//
//  페이월 화면 — 구독 가치 제안 + 가격 + 구매 버튼
//
//  구성:
//  - 가치 헤드라인: "쌓인 사진, 한 번에 비우세요" (FR-035)
//  - 무료/Plus 비교표 (FR-035)
//  - 연간 크게 / 월간 보조 (FR-036)
//  - 하단 법적 고지: 자동 갱신, 해지 방법, 약관/처리방침 링크 (FR-037)
//  - 구매 버튼 → SubscriptionStore.purchase()
//  - 복원 버튼 → restorePurchases()
//  - 리딤 코드 버튼 → presentRedemptionSheet (FR-031)
//  - 결제 실패별 안내 (FR-038), Ask to Buy (FR-038)
//

import UIKit
import StoreKit
import AppCore
import OSLog

// MARK: - PaywallViewController

/// 페이월 화면
/// present(.pageSheet) 또는 push로 표시
final class PaywallViewController: UIViewController {

    // MARK: - Properties

    /// 뷰모델
    private let viewModel = PaywallViewModel()

    /// 구매 진행 중 플래그 (중복 탭 방지)
    private var isPurchasing = false

    /// 페이월 진입 경로 (FR-056 분석용)
    var analyticsSource: PaywallSource = .menu

    /// 구독 성공 콜백 (첫 페이월에서 사용)
    var onSubscribed: (() -> Void)?

    /// 구독 없이 닫힘 콜백 (첫 페이월에서 사용)
    var onDismissedWithoutSubscription: (() -> Void)?

    // MARK: - UI Components

    /// 스크롤뷰 (전체 콘텐츠)
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    /// 콘텐츠 스택뷰
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// 닫기 버튼 (우상단 X)
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.3)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 가치 헤드라인 (FR-035)
    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.text = "무료 체험하고\n한 번에 비우세요"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 서브헤드라인
    private let subheadlineLabel: UILabel = {
        let label = UILabel()
        label.text = "Plus로 삭제 한도 없이, 광고 없이"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 비교표 컨테이너
    private let comparisonContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 월간/연간 커스텀 캡슐 탭
    private let planTabView = PaywallPlanTabView()

    /// 무료 체험 + 가격 안내 라벨
    /// 예: "7일 무료 체험(언제든 취소 가능) ($19.99/연)"
    private let freeTrialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 구매 버튼 (무료 체험 시작하기)
    private let purchaseButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.setTitleColor(.black, for: .normal)
        button.setTitle("무료 체험 시작하기", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 복원/리딤 가로 스택
    private let restoreRedeemStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// 복원 버튼
    private let restoreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("구독 복원", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 리딤 코드 버튼
    private let redeemButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("리딤 코드", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// "Apple로 보호됨 약관" 라벨 (FR-037)
    /// "약관" 부분에 밑줄 + 탭 시 하단 시트로 법적 고지 표시
    private let appleProtectedLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false

        // "Apple로 보호됨 " (일반) + "약관" (밑줄)
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(
            string: "Apple로 보호됨\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.white
            ]
        ))
        text.append(NSAttributedString(
            string: "약관",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        ))
        label.attributedText = text

        return label
    }()

    /// 로딩 스피너 (구매 진행 중)
    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    // MARK: - Lifecycle

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 구매 버튼 완전 캡슐형 (높이/2)
        purchaseButton.layer.cornerRadius = purchaseButton.bounds.height / 2
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupUI()
        setupActions()
        setupAccessibility()
        loadContent()

        // Swipe-to-Dismiss 대응: pageSheet 모달에서 스와이프로 닫을 때 콜백 호출
        presentationController?.delegate = self

        // [BM] T057: 페이월 노출 이벤트 (FR-056)
        AnalyticsService.shared.trackPaywallShown(source: analyticsSource)

        // 구매 버튼 미세 펄스 애니메이션 시작
        startPurchaseButtonPulse()
    }

    // MARK: - Button Pulse Animation

    /// 구매 버튼 스케일 펄스 (1.0 ↔ 1.06)
    private func startPurchaseButtonPulse() {
        // viewDidAppear 이후 레이아웃 확정 후 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            UIView.animate(
                withDuration: 1.0,
                delay: 0,
                options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut],
                animations: {
                    self?.purchaseButton.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                }
            )
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        // 닫기 버튼
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        // 스크롤뷰
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 콘텐츠 스택
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48)
        ])

        // 헤드라인 영역
        contentStack.addArrangedSubview(headlineLabel)
        contentStack.addArrangedSubview(subheadlineLabel)
        contentStack.setCustomSpacing(8, after: headlineLabel)

        // 비교표
        contentStack.addArrangedSubview(comparisonContainer)
        setupComparisonTable()

        // 월간/연간 탭 — 가로 50%, 높이 1.5배(48pt), 중앙 정렬
        let segmentWrapper = UIView()
        segmentWrapper.translatesAutoresizingMaskIntoConstraints = false
        segmentWrapper.addSubview(planTabView)
        NSLayoutConstraint.activate([
            planTabView.centerXAnchor.constraint(equalTo: segmentWrapper.centerXAnchor),
            planTabView.topAnchor.constraint(equalTo: segmentWrapper.topAnchor),
            planTabView.bottomAnchor.constraint(equalTo: segmentWrapper.bottomAnchor),
            planTabView.widthAnchor.constraint(equalTo: segmentWrapper.widthAnchor, multiplier: 0.5),
            planTabView.heightAnchor.constraint(equalToConstant: 48)
        ])
        contentStack.addArrangedSubview(segmentWrapper)

        // 무료 체험 + 가격 라벨 (탭 아래 18pt 간격 = 8 spacing + 10 추가)
        contentStack.addArrangedSubview(freeTrialLabel)
        contentStack.setCustomSpacing(28, after: segmentWrapper)

        // 구매 버튼
        contentStack.addArrangedSubview(purchaseButton)
        purchaseButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        contentStack.setCustomSpacing(13, after: freeTrialLabel)

        // 복원/리딤 스택
        restoreRedeemStack.addArrangedSubview(restoreButton)
        restoreRedeemStack.addArrangedSubview(redeemButton)
        contentStack.addArrangedSubview(restoreRedeemStack)
        contentStack.setCustomSpacing(17, after: purchaseButton)

        // Apple로 보호됨 + 약관 (탭 가능)
        contentStack.addArrangedSubview(appleProtectedLabel)
        contentStack.setCustomSpacing(8, after: restoreRedeemStack)

        // 스피너 (중앙)
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    /// 비교표 구성 (FR-035)
    private func setupComparisonTable() {
        let tableStack = UIStackView()
        tableStack.axis = .vertical
        tableStack.spacing = 0
        tableStack.translatesAutoresizingMaskIntoConstraints = false

        // 헤더 행
        let headerRow = createComparisonRow(feature: "", freeValue: "일반", plusValue: "무료체험(Plus)", isHeader: true)
        tableStack.addArrangedSubview(headerRow)

        // 데이터 행
        for row in viewModel.comparisonRows {
            let rowView = createComparisonRow(
                feature: row.feature,
                freeValue: row.freeValue,
                plusValue: row.plusValue,
                isHeader: false
            )
            tableStack.addArrangedSubview(rowView)
        }

        comparisonContainer.addSubview(tableStack)
        NSLayoutConstraint.activate([
            tableStack.topAnchor.constraint(equalTo: comparisonContainer.topAnchor, constant: 16),
            tableStack.leadingAnchor.constraint(equalTo: comparisonContainer.leadingAnchor, constant: 16),
            tableStack.trailingAnchor.constraint(equalTo: comparisonContainer.trailingAnchor, constant: -16),
            tableStack.bottomAnchor.constraint(equalTo: comparisonContainer.bottomAnchor, constant: -16)
        ])
    }

    /// 비교표 행 생성
    private func createComparisonRow(feature: String, freeValue: String, plusValue: String, isHeader: Bool) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.distribution = .fillEqually
        container.alignment = .center

        let featureLabel = UILabel()
        featureLabel.text = feature
        featureLabel.font = isHeader ? .systemFont(ofSize: 13, weight: .semibold) : .systemFont(ofSize: 14, weight: .regular)
        featureLabel.textColor = isHeader ? .secondaryLabel : .label

        let freeLabel = UILabel()
        freeLabel.text = freeValue
        freeLabel.font = isHeader ? .systemFont(ofSize: 13, weight: .semibold) : .systemFont(ofSize: 14, weight: .regular)
        freeLabel.textColor = .white
        freeLabel.textAlignment = .center

        // 온보딩 포인트컬러 (#FFEA00)
        let highlightYellow = UIColor(red: 1.0, green: 0.918, blue: 0.0, alpha: 1.0)

        let plusLabel = UILabel()
        plusLabel.text = plusValue
        plusLabel.font = isHeader ? .systemFont(ofSize: 16, weight: .bold) : .systemFont(ofSize: 17, weight: .semibold)
        plusLabel.textColor = highlightYellow
        plusLabel.textAlignment = .center

        container.addArrangedSubview(featureLabel)
        container.addArrangedSubview(freeLabel)
        container.addArrangedSubview(plusLabel)

        // 행 높이
        container.heightAnchor.constraint(equalToConstant: isHeader ? 30 : 36).isActive = true

        // 접근성: 행 단위로 읽히도록 설정 (FR-057)
        if !isHeader && !feature.isEmpty {
            container.isAccessibilityElement = true
            container.accessibilityLabel = "\(feature), 무료: \(freeValue), Plus: \(plusValue)"
        }

        // 구분선 (헤더 아래)
        if isHeader {
            let separator = UIView()
            separator.backgroundColor = .separator
            separator.translatesAutoresizingMaskIntoConstraints = false

            let wrapper = UIStackView(arrangedSubviews: [container, separator])
            wrapper.axis = .vertical
            wrapper.spacing = 8
            separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            return wrapper
        }

        return container
    }

    // MARK: - Actions

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        purchaseButton.addTarget(self, action: #selector(purchaseTapped), for: .touchUpInside)
        planTabView.addTarget(self, action: #selector(planTabViewChanged), for: .valueChanged)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        redeemButton.addTarget(self, action: #selector(redeemTapped), for: .touchUpInside)

        // 약관 라벨 탭 제스처
        let termsTap = UITapGestureRecognizer(target: self, action: #selector(termsTapped))
        appleProtectedLabel.addGestureRecognizer(termsTap)
    }

    @objc private func closeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onDismissedWithoutSubscription?()
        }
    }

    /// 현재 선택된 플랜이 연간인지 여부
    private var isYearlySelected: Bool {
        planTabView.selectedSegmentIndex == 1
    }

    /// 탭 변경 시 무료 체험 라벨 업데이트
    @objc private func planTabViewChanged() {
        updateTrialLabel()
    }

    /// 구매 버튼 탭 — 선택된 플랜에 따라 구매 진행
    @objc private func purchaseTapped() {
        guard !isPurchasing else { return }
        isPurchasing = true
        setButtonsEnabled(false)

        Task {
            do {
                let result = isYearlySelected
                    ? try await viewModel.purchaseYearly()
                    : try await viewModel.purchaseMonthly()
                handlePurchaseResult(result)
            } catch {
                handlePurchaseError(error)
            }
            isPurchasing = false
            setButtonsEnabled(true)
        }
    }

    @objc private func restoreTapped() {
        guard !isPurchasing else { return }
        isPurchasing = true
        spinner.startAnimating()

        Task {
            do {
                let restored = try await viewModel.restorePurchases()
                spinner.stopAnimating()
                if restored {
                    showAlert(title: "복원 완료", message: "Plus 구독이 복원되었습니다.") { [weak self] in
                        self?.dismiss(animated: true) {
                            self?.onSubscribed?()
                        }
                    }
                } else {
                    showAlert(title: "복원 결과", message: "복원할 구독이 없습니다.")
                }
            } catch {
                spinner.stopAnimating()
                showAlert(title: "복원 실패", message: error.localizedDescription)
            }
            isPurchasing = false
        }
    }

    @objc private func redeemTapped() {
        SubscriptionStore.shared.presentRedemptionSheet(from: self)
    }

    // MARK: - Purchase Result Handling

    /// 구매 결과 처리
    private func handlePurchaseResult(_ result: Product.PurchaseResult) {
        switch result {
        case .success:
            Logger.app.debug("PaywallVC: 구매 성공")
            dismiss(animated: true) { [weak self] in
                self?.onSubscribed?()
            }
        case .userCancelled:
            Logger.app.debug("PaywallVC: 사용자 취소")
        case .pending:
            // Ask to Buy (FR-038)
            showAlert(title: "승인 대기", message: "구매 요청이 전송되었습니다.\n보호자의 승인 후 활성화됩니다.")
        @unknown default:
            break
        }
    }

    /// 구매 에러 처리 (FR-038)
    private func handlePurchaseError(_ error: Error) {
        Logger.app.error("PaywallVC: 구매 에러 — \(error.localizedDescription)")

        let message: String
        if let storeError = error as? StoreKitError {
            switch storeError {
            case .networkError:
                message = "네트워크 연결을 확인해주세요."
            case .userCancelled:
                return // 취소는 무시
            default:
                message = "결제를 완료할 수 없습니다.\n다시 시도해주세요."
            }
        } else {
            message = error.localizedDescription
        }

        showAlert(title: "결제 실패", message: message)
    }

    // MARK: - Content Loading

    /// 상품 로드 + UI 업데이트
    private func loadContent() {
        viewModel.loadProducts()

        if viewModel.isLoaded {
            updatePriceUI()
        } else {
            // 상품 미로드 → 알림 대기 + 직접 로드 시도
            spinner.startAnimating()
            setButtonsEnabled(false)

            // SubscriptionStore 상품 로드 완료 알림 구독
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleProductsLoaded),
                name: SubscriptionStore.productsDidLoadNotification, object: nil
            )

            // SubscriptionStore가 아직 상품을 로드하지 않았으면 직접 요청
            if !SubscriptionStore.shared.hasProducts {
                Task {
                    let products = try? await Product.products(for: SubscriptionProductID.all)
                    await MainActor.run { [weak self] in
                        guard let self = self, !self.viewModel.isLoaded else { return }
                        self.spinner.stopAnimating()
                        if let products = products, !products.isEmpty {
                            self.viewModel.setProducts(products)
                            self.updatePriceUI()
                            self.setButtonsEnabled(true)
                        } else {
                            // 상품 로드 완전 실패 — 에러 안내
                            self.showProductLoadError()
                        }
                    }
                }
            }
        }

    }

    /// SubscriptionStore 상품 로드 완료 알림 핸들러
    @objc private func handleProductsLoaded() {
        NotificationCenter.default.removeObserver(
            self, name: SubscriptionStore.productsDidLoadNotification, object: nil
        )
        viewModel.loadProducts()
        spinner.stopAnimating()
        updatePriceUI()
        setButtonsEnabled(true)
    }

    /// 가격 UI 업데이트
    private func updatePriceUI() {
        // 무료 체험 + 가격 라벨 업데이트
        updateTrialLabel()
    }

    /// 선택된 탭에 따라 무료 체험 + 가격 라벨 업데이트
    /// "7일 무료체험" 노란색 / " - 언제든 취소 가능" 흰색 / "(가격)" 흰50%
    private func updateTrialLabel() {
        guard let info = viewModel.freeTrialAndPrice(isYearly: isYearlySelected) else {
            freeTrialLabel.isHidden = true
            return
        }

        // 온보딩 포인트컬러 (#FFEA00)
        let highlightYellow = UIColor(red: 1.0, green: 0.918, blue: 0.0, alpha: 1.0)

        let attributed = NSMutableAttributedString()

        // "7일 무료체험": 17pt, semibold, 포인트 노란색
        attributed.append(NSAttributedString(
            string: info.trialDays,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: highlightYellow
            ]
        ))

        // " - 언제든 취소 가능": 17pt, semibold, 흰색
        attributed.append(NSAttributedString(
            string: info.cancelNote + " ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
        ))

        // "(가격)": 13pt, medium, 흰색 50%
        attributed.append(NSAttributedString(
            string: info.price,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.5)
            ]
        ))

        freeTrialLabel.attributedText = attributed
        freeTrialLabel.isHidden = false
    }

    /// 약관 탭 → 하단 시트로 법적 고지 표시 (FR-037)
    @objc private func termsTapped() {
        let legalText = """
        무료 체험 기간이 끝나면 선택한 요금제로 자동 구독이 시작됩니다. \
        구독은 확인 시 Apple ID 계정으로 청구됩니다. \
        구독은 현재 기간 종료 최소 24시간 전에 해지하지 않으면 자동으로 갱신됩니다. \
        갱신 비용은 현재 기간 종료 24시간 이내에 청구됩니다. \
        구독은 구매 후 설정 > Apple ID > 구독에서 관리하고 해지할 수 있습니다. \
        이용약관 및 개인정보처리방침이 적용됩니다.
        """

        let sheet = UIViewController()
        sheet.view.backgroundColor = .systemBackground

        // 드래그 핸들 바
        let handle = UIView()
        handle.backgroundColor = .systemGray3
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        sheet.view.addSubview(handle)

        // 제목
        let titleLabel = UILabel()
        titleLabel.text = "이용 약관"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        sheet.view.addSubview(titleLabel)

        // 본문
        let bodyLabel = UILabel()
        bodyLabel.text = legalText
        bodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        sheet.view.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: sheet.view.topAnchor, constant: 8),
            handle.centerXAnchor.constraint(equalTo: sheet.view.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 36),
            handle.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: sheet.view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: sheet.view.trailingAnchor, constant: -20),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: sheet.view.leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: sheet.view.trailingAnchor, constant: -20),
        ])

        // 콘텐츠 높이 계산 후 딱 맞는 커스텀 detent 적용
        // viewDidLayoutSubviews 전이므로 수동 계산
        let sheetWidth = view.bounds.width - 40  // 좌우 20pt 패딩
        let bodySize = bodyLabel.sizeThatFits(CGSize(width: sheetWidth, height: .greatestFiniteMagnitude))
        // 핸들(8+5) + 간격(16) + 제목(~22) + 간격(12) + 본문 + 하단 여백(24)
        let totalHeight: CGFloat = 8 + 5 + 16 + 22 + 12 + bodySize.height + 24

        if let sheetPresentation = sheet.sheetPresentationController {
            let customDetent = UISheetPresentationController.Detent.custom { _ in
                return totalHeight
            }
            sheetPresentation.detents = [customDetent]
        }

        present(sheet, animated: true)
    }

    // MARK: - Helpers

    /// 버튼 활성/비활성 토글
    private func setButtonsEnabled(_ enabled: Bool) {
        purchaseButton.isEnabled = enabled
        restoreButton.isEnabled = enabled
        planTabView.isEnabled = enabled
        purchaseButton.alpha = enabled ? 1.0 : 0.5
    }

    /// 상품 로드 실패 시 에러 안내 (StoreKit Configuration 미설정 등)
    private func showProductLoadError() {
        purchaseButton.setTitle("상품 정보를 불러올 수 없습니다", for: .normal)
        purchaseButton.isEnabled = false
        purchaseButton.alpha = 0.5
        planTabView.isEnabled = false
        Logger.app.error("PaywallVC: 상품 로드 실패 — StoreKit Configuration 확인 필요")
    }

    /// 알림 표시
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }

    // MARK: - Accessibility

    private func setupAccessibility() {
        closeButton.accessibilityLabel = "닫기"
        closeButton.accessibilityHint = "페이월 화면을 닫습니다"
        planTabView.accessibilityLabel = "구독 플랜 선택"
        purchaseButton.accessibilityLabel = "무료 체험 시작하기"
        restoreButton.accessibilityLabel = "구독 복원"
        restoreButton.accessibilityHint = "이전에 구매한 구독을 복원합니다"
        redeemButton.accessibilityLabel = "리딤 코드 입력"
        redeemButton.accessibilityHint = "프로모션 코드를 입력합니다"
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension PaywallViewController: UIAdaptivePresentationControllerDelegate {

    /// 스와이프로 모달이 닫힌 경우 (closeTapped 미호출)
    /// 구독 없이 닫힌 것으로 처리
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismissedWithoutSubscription?()
    }
}
