//
//  CelebrationViewController.swift
//  SweepPic
//
//  삭제 완료 축하 화면 (FR-039)
//
//  삭제대기함 비우기 성공 후 표시:
//  - "N장 삭제 완료!" (이번 세션)
//  - "총 M장 삭제" (누적)
//  - "X.XGB 확보" (누적)
//  - "확인" 버튼 → dismiss
//
//  UI 구성:
//  - 반투명 블러 배경
//  - 중앙 카드: 축하 아이콘 + 이번 삭제 + 누적 통계 + 확인 버튼
//

import UIKit
import AppCore
import OSLog

// MARK: - CelebrationViewController

/// 삭제 완료 축하 화면 (FR-039)
/// 비우기 성공 후 이번/누적 통계를 표시
final class CelebrationViewController: UIViewController {

    // MARK: - Properties

    /// 축하 결과 데이터
    private let result: CelebrationResult

    // MARK: - UI Components

    /// 블러 배경
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 카드 컨테이너 (블러 팝업 카드)
    private lazy var cardView = BlurPopupCardView()

    /// 이번 삭제 라벨 ("N장 삭제 완료!") — 제목 스타일 (게이트 팝업 기준)
    private lazy var sessionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// 누적 통계 스택 (총 삭제 + 확보 용량)
    private lazy var statsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            totalDeletedRow,
            totalFreedRow
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    /// "SweepPic에서 총 M장 삭제" 행 — 안내 스타일
    private lazy var totalDeletedRow: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        return label
    }()

    /// "X.XGB 확보" 행 — 안내 스타일
    private lazy var totalFreedRow: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        return label
    }()

    /// "확인" 버튼 — 반투명 흰색 배경 (기존 팝업 스타일 통일)
    private lazy var confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitle("확인", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Referral Promo (T034, US4)

    /// 초대 프로모 하단 배경 — 카드 하단을 가로로 잘라 색상 차별화
    private lazy var referralPromoBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// "친구에게도 알려주세요" 라벨
    private lazy var referralLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "친구에게도 알려주세요"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.textAlignment = .center
        return label
    }()

    /// 초대 버튼 — 다른 버튼과 동일 높이 50pt, cornerRadius 25
    private lazy var referralButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.setTitle("친구 초대하기", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(referralButtonTapped), for: .touchUpInside)
        button.accessibilityLabel = "친구 초대하기"
        button.accessibilityHint = "초대 설명 화면으로 이동합니다"
        return button
    }()

    /// 메인 스택 뷰
    private lazy var stackView: UIStackView = {
        // T034: 확인 버튼 아래에 초대 프로모 추가
        let stack = UIStackView(arrangedSubviews: [
            sessionLabel,
            statsStackView,
            confirmButton,
            referralLabel,
            referralButton
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        return stack
    }()

    // MARK: - Initialization

    /// 축하 화면 생성
    /// - Parameter result: 축하 결과 데이터 (이번/누적 통계)
    init(result: CelebrationResult) {
        self.result = result
        super.init(nibName: nil, bundle: nil)

        // 모달 설정
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureData()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .clear

        // 블러 배경
        view.addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 카드 뷰
        view.addSubview(cardView)
        cardView.activateBlur()
        // T034: 하단 배경 먼저 삽입 (스택뷰 뒤에 깔림)
        cardView.contentView.addSubview(referralPromoBackground)
        cardView.contentView.addSubview(stackView)

        // 간격 조정
        stackView.setCustomSpacing(20, after: sessionLabel)
        stackView.setCustomSpacing(24, after: statsStackView)

        NSLayoutConstraint.activate([
            // 카드 - 화면 중앙
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 300),

            // 스택 뷰 — 카드 내부
            stackView.topAnchor.constraint(equalTo: cardView.contentView.topAnchor, constant: 28),
            stackView.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor, constant: -24),

            // 버튼 크기 — 스택 전체 너비, 높이 50 (기존 팝업 통일)
            confirmButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 50),

            // T034: 초대 버튼 크기
            referralButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            referralButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // T034: 확인 버튼과 초대 프로모 간격
        stackView.setCustomSpacing(16, after: confirmButton)
        stackView.setCustomSpacing(8, after: referralLabel)

        // T034: 배경 뷰 — 프로모 라벨 위에서 카드 하단 끝까지
        NSLayoutConstraint.activate([
            referralPromoBackground.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor),
            referralPromoBackground.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor),
            referralPromoBackground.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor),
            referralPromoBackground.topAnchor.constraint(equalTo: referralLabel.topAnchor, constant: -16)
        ])

        // 접근성 설정 (FR-057)
        confirmButton.accessibilityLabel = "확인"
        confirmButton.accessibilityHint = "축하 화면을 닫습니다"
    }

    /// 데이터 표시
    private func configureData() {
        // 이번 삭제: "N장 삭제 완료!"
        sessionLabel.text = "\(result.sessionDeletedCount)장 삭제 완료"

        // 누적 삭제: "총 M장 삭제"
        let totalFormatted = NumberFormatter.localizedString(
            from: NSNumber(value: result.totalDeletedCount), number: .decimal
        )
        totalDeletedRow.text = "SweepPic에서 총 \(totalFormatted)장 삭제"

        // 누적 확보 용량: "X.XGB 확보"
        let freedFormatted = FileSizeCalculator.formatBytes(result.totalFreedBytes)
        totalFreedRow.text = "\(freedFormatted) 확보"

        // 접근성: 통계 라벨에 명시적 설명 (FR-057)
        sessionLabel.accessibilityLabel = "\(result.sessionDeletedCount)장 삭제 완료"
        totalDeletedRow.accessibilityLabel = "SweepPic에서 총 \(totalFormatted)장 삭제"
        totalFreedRow.accessibilityLabel = "\(freedFormatted) 확보"

        Logger.app.debug("CelebrationVC: 이번 \(self.result.sessionDeletedCount)장, 누적 \(self.result.totalDeletedCount)장, 누적 \(self.result.totalFreedBytes)bytes")
    }

    // MARK: - Actions

    /// "확인" 버튼 탭 → dismiss
    @objc private func confirmButtonTapped() {
        cardView.deactivateBlur()
        dismiss(animated: true)
    }

    /// T034: 초대 버튼 탭 → ReferralExplainViewController 모달
    @objc private func referralButtonTapped() {
        Logger.app.debug("CelebrationVC: 초대 버튼 탭")
        let presenter = presentingViewController
        cardView.deactivateBlur()
        dismiss(animated: true) {
            guard let presenter = presenter else { return }
            let referralVC = ReferralExplainViewController()
            presenter.present(referralVC, animated: true)
        }
    }
}
