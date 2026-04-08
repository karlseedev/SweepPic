//
//  FAQViewController.swift
//  SweepPic
//
//  자주 묻는 질문 (FAQ) 화면 (FR-046, T049)
//
//  인앱 정적 아코디언 리스트, 오프라인 지원
//  콘텐츠: docs/bm/260227Marketing.md §7 FAQ 테이블 (3카테고리 12항목)
//
//  구성:
//  - 3개 섹션: 사진/기능, 구독/결제, 개인정보/보안
//  - 각 항목 탭 → 답변 펼침/접기 (아코디언)
//  - 오프라인 완전 지원 (하드코딩 데이터)
//

import UIKit
import AppCore
import OSLog

// MARK: - FAQ Data Model

/// FAQ 항목
private struct FAQItem {
    let question: String
    let answer: String
    var isExpanded: Bool = false
}

/// FAQ 섹션
private struct FAQSection {
    let title: String
    var items: [FAQItem]
}

// MARK: - FAQViewController

/// FAQ 아코디언 리스트 화면
final class FAQViewController: UIViewController, BarsVisibilityControlling {

    /// FloatingOverlay 숨김 (iOS 16~25)
    var prefersFloatingOverlayHidden: Bool? { true }

    // MARK: - Data

    /// FAQ 데이터 (하드코딩 — FR-046, 오프라인 지원)
    /// 출처: docs/bm/260227Marketing.md §7
    private var sections: [FAQSection] = [
        FAQSection(title: String(localized: "monetization.faq.section.photos"), items: [
            FAQItem(
                question: String(localized: "monetization.faq.q1"),
                answer: String(localized: "monetization.faq.a1")
            ),
            FAQItem(
                question: String(localized: "monetization.faq.q2"),
                answer: String(localized: "monetization.faq.a2")
            ),
            FAQItem(
                question: String(localized: "monetization.faq.q3"),
                answer: String(localized: "monetization.faq.a3")
            ),
            FAQItem(
                question: String(localized: "monetization.faq.q4"),
                answer: String(localized: "monetization.faq.a4")
            ),
            FAQItem(
                question: String(localized: "monetization.faq.q5"),
                answer: String(localized: "monetization.faq.a5")
            ),
        ]),
        FAQSection(title: String(localized: "monetization.faq.section.billing"), items: [
            FAQItem(
                question: String(localized: "monetization.faq.q6"),
                answer: String(localized: "monetization.faq.a6")
            ),
            FAQItem(
                question: String(localized: "monetization.faq.q7"),
                answer: String(localized: "monetization.faq.a7")
            ),
            FAQItem(
                question: String(localized: "monetization.faq.q8"),
                answer: String(localized: "monetization.faq.a8")
            ),
            FAQItem(
                question: String(localized: "monetization.faq.q9"),
                answer: String(localized: "monetization.faq.a9")
            ),
            FAQItem(
                question: String(localized: "monetization.faq.q10"),
                answer: String(localized: "monetization.faq.a10 \(UsageLimit.dailyFreeLimit) \(UsageLimit.maxDailyTotal)")
            ),
        ]),
        FAQSection(title: String(localized: "monetization.faq.section.privacy"), items: [
            FAQItem(
                question: String(localized: "monetization.faq.q11"),
                answer: String(localized: "monetization.faq.a11")
            ),
        ]),
    ]

    // MARK: - UI Components

    /// 테이블 뷰
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(FAQCell.self, forCellReuseIdentifier: FAQCell.reuseID)
        tv.estimatedRowHeight = 60
        tv.rowHeight = UITableView.automaticDimension
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return tv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "monetization.faq.title")
        view.backgroundColor = .systemGroupedBackground
        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // iOS 16~25: 시스템 네비바 표시 (뒤로가기 버튼)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // iOS 16~25: 시스템 네비바 다시 숨김
        if #unavailable(iOS 26.0) {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }

    // MARK: - Setup

    private func setupTableView() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

// MARK: - UITableViewDataSource

extension FAQViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: FAQCell.reuseID, for: indexPath
        ) as? FAQCell else {
            return UITableViewCell()
        }
        let item = sections[indexPath.section].items[indexPath.row]
        cell.configure(question: item.question, answer: item.answer, isExpanded: item.isExpanded)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FAQViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // 아코디언 토글
        sections[indexPath.section].items[indexPath.row].isExpanded.toggle()

        // 셀 애니메이션 업데이트
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

// MARK: - FAQCell

/// FAQ 아코디언 셀
/// 질문 + 펼침/접기 답변
private final class FAQCell: UITableViewCell {

    static let reuseID = "FAQCell"

    // MARK: - UI

    /// 질문 라벨
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 답변 라벨 (펼침 시 표시)
    private let answerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 펼침/접기 아이콘
    private let chevronImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: "chevron.down", withConfiguration: config))
        iv.tintColor = .tertiaryLabel
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        return iv
    }()

    /// 스택 뷰
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        selectionStyle = .none

        // 질문 행: 질문 라벨 + 셰브론
        let questionRow = UIStackView(arrangedSubviews: [questionLabel, chevronImageView])
        questionRow.axis = .horizontal
        questionRow.spacing = 8
        questionRow.alignment = .center

        contentStackView.addArrangedSubview(questionRow)
        contentStackView.addArrangedSubview(answerLabel)

        contentView.addSubview(contentStackView)
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            chevronImageView.widthAnchor.constraint(equalToConstant: 16),
        ])
    }

    // MARK: - Configure

    /// 셀 구성
    func configure(question: String, answer: String, isExpanded: Bool) {
        questionLabel.text = question
        answerLabel.text = answer
        answerLabel.isHidden = !isExpanded

        // 셰브론 회전 애니메이션
        let angle: CGFloat = isExpanded ? .pi : 0
        chevronImageView.transform = CGAffineTransform(rotationAngle: angle)

        // 접근성
        accessibilityLabel = question
        accessibilityHint = isExpanded
            ? String(localized: "a11y.faq.collapseHint")
            : String(localized: "a11y.faq.expandHint")
    }
}
