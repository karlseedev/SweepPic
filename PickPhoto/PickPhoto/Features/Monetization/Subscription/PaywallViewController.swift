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
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 가치 헤드라인 (FR-035)
    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.text = "쌓인 사진,\n한 번에 비우세요"
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

    /// 연간 구매 버튼 (메인)
    private let yearlyButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 무료 체험 안내 라벨
    private let freeTrialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 월간 구매 버튼 (보조)
    private let monthlyButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemGray5
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.layer.cornerRadius = 25
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

    /// 법적 고지 라벨 (FR-037)
    private let legalLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupUI()
        setupActions()
        setupAccessibility()
        loadContent()

        // [BM] T057: 페이월 노출 이벤트 (FR-056)
        AnalyticsService.shared.trackPaywallShown(source: analyticsSource)
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

        // 무료 체험 라벨
        contentStack.addArrangedSubview(freeTrialLabel)

        // 연간 버튼
        contentStack.addArrangedSubview(yearlyButton)
        yearlyButton.heightAnchor.constraint(equalToConstant: 54).isActive = true

        // 월간 버튼
        contentStack.addArrangedSubview(monthlyButton)
        monthlyButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        contentStack.setCustomSpacing(8, after: yearlyButton)

        // 복원/리딤 스택
        restoreRedeemStack.addArrangedSubview(restoreButton)
        restoreRedeemStack.addArrangedSubview(redeemButton)
        contentStack.addArrangedSubview(restoreRedeemStack)
        contentStack.setCustomSpacing(12, after: monthlyButton)

        // 법적 고지
        contentStack.addArrangedSubview(legalLabel)
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
        let headerRow = createComparisonRow(feature: "", freeValue: "무료", plusValue: "Plus", isHeader: true)
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
        freeLabel.textColor = isHeader ? .secondaryLabel : .tertiaryLabel
        freeLabel.textAlignment = .center

        let plusLabel = UILabel()
        plusLabel.text = plusValue
        plusLabel.font = isHeader ? .systemFont(ofSize: 13, weight: .bold) : .systemFont(ofSize: 14, weight: .semibold)
        plusLabel.textColor = isHeader ? .systemBlue : .systemBlue
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
        yearlyButton.addTarget(self, action: #selector(yearlyTapped), for: .touchUpInside)
        monthlyButton.addTarget(self, action: #selector(monthlyTapped), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        redeemButton.addTarget(self, action: #selector(redeemTapped), for: .touchUpInside)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func yearlyTapped() {
        guard !isPurchasing else { return }
        isPurchasing = true
        setButtonsEnabled(false)

        Task {
            do {
                let result = try await viewModel.purchaseYearly()
                handlePurchaseResult(result)
            } catch {
                handlePurchaseError(error)
            }
            isPurchasing = false
            setButtonsEnabled(true)
        }
    }

    @objc private func monthlyTapped() {
        guard !isPurchasing else { return }
        isPurchasing = true
        setButtonsEnabled(false)

        Task {
            do {
                let result = try await viewModel.purchaseMonthly()
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
                        self?.dismiss(animated: true)
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
            dismiss(animated: true)
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

        updateLegalText()
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
        // 연간 버튼 (메인)
        var yearlyTitle = viewModel.yearlyPriceText
        if let savings = viewModel.yearlySavingsPercent {
            yearlyTitle += "  \(savings) 할인"
        }
        yearlyButton.setTitle(yearlyTitle, for: .normal)

        // 월간 버튼 (보조)
        monthlyButton.setTitle(viewModel.monthlyPriceText, for: .normal)

        // 무료 체험 라벨
        if let trialText = viewModel.freeTrialText {
            freeTrialLabel.text = trialText
            freeTrialLabel.isHidden = false
        }

        // 접근성: 가격 정보 반영 (FR-057)
        yearlyButton.accessibilityLabel = "연간 구독, \(yearlyTitle)"
        monthlyButton.accessibilityLabel = "월간 구독, \(viewModel.monthlyPriceText)"
    }

    /// 법적 고지 텍스트 업데이트 (FR-037)
    private func updateLegalText() {
        legalLabel.text = """
        구독은 확인 시 Apple ID 계정으로 청구됩니다. \
        구독은 현재 기간 종료 최소 24시간 전에 해지하지 않으면 자동으로 갱신됩니다. \
        갱신 비용은 현재 기간 종료 24시간 이내에 청구됩니다. \
        구독은 구매 후 설정 > Apple ID > 구독에서 관리하고 해지할 수 있습니다. \
        이용약관 및 개인정보처리방침이 적용됩니다.
        """
    }

    // MARK: - Helpers

    /// 버튼 활성/비활성 토글
    private func setButtonsEnabled(_ enabled: Bool) {
        yearlyButton.isEnabled = enabled
        monthlyButton.isEnabled = enabled
        restoreButton.isEnabled = enabled
        yearlyButton.alpha = enabled ? 1.0 : 0.5
        monthlyButton.alpha = enabled ? 1.0 : 0.5
    }

    /// 상품 로드 실패 시 에러 안내 (StoreKit Configuration 미설정 등)
    private func showProductLoadError() {
        yearlyButton.setTitle("상품 정보를 불러올 수 없습니다", for: .normal)
        yearlyButton.isEnabled = false
        yearlyButton.alpha = 0.5
        monthlyButton.isHidden = true
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
        yearlyButton.accessibilityLabel = "연간 구독 구매"
        monthlyButton.accessibilityLabel = "월간 구독 구매"
        restoreButton.accessibilityLabel = "구독 복원"
        restoreButton.accessibilityHint = "이전에 구매한 구독을 복원합니다"
        redeemButton.accessibilityLabel = "리딤 코드 입력"
        redeemButton.accessibilityHint = "프로모션 코드를 입력합니다"
    }
}
