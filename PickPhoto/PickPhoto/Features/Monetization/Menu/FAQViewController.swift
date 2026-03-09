//
//  FAQViewController.swift
//  PickPhoto
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
final class FAQViewController: UIViewController {

    // MARK: - Data

    /// FAQ 데이터 (하드코딩 — FR-046, 오프라인 지원)
    /// 출처: docs/bm/260227Marketing.md §7
    private var sections: [FAQSection] = [
        FAQSection(title: "사진/기능", items: [
            FAQItem(
                question: "삭제한 사진을 복구할 수 있나요?",
                answer: "삭제대기함에 있는 사진은 언제든 복구할 수 있습니다. 삭제대기함을 비운 후에는 최근 삭제된 항목(iOS 기본 사진 앱)에서 30일 이내에 복구 가능합니다."
            ),
            FAQItem(
                question: "사진이 서버로 전송되나요?",
                answer: "아니요. 모든 사진 처리(유사 사진 분석, 얼굴 감지 포함)는 기기 내에서만 이루어집니다. 사진 데이터는 외부 서버로 전송되지 않습니다."
            ),
            FAQItem(
                question: "지원하는 iOS 버전은?",
                answer: "iOS 16 이상을 지원합니다."
            ),
            FAQItem(
                question: "유사 사진 분석이 정확하지 않아요",
                answer: "유사 사진 분석은 AI 기반이라 일부 오분류가 있을 수 있습니다. 삭제 전 반드시 확인하시고, 실수로 삭제해도 삭제대기함에서 복구할 수 있습니다."
            ),
            FAQItem(
                question: "자동 정리는 어떤 기준으로 사진을 선택하나요?",
                answer: "유사 사진 그룹에서 화질, 초점, 구도 등을 분석하여 가장 좋은 사진을 남기고 나머지를 삭제대기함으로 이동합니다. 바로 삭제되지 않으니 안심하세요."
            ),
        ]),
        FAQSection(title: "구독/결제", items: [
            FAQItem(
                question: "무료로 사용할 수 있나요?",
                answer: "네. 사진 정리(스와이프 삭제, 유사 사진 분석, 자동 정리, 복구)는 모두 무료입니다. 삭제대기함 비우기에만 일일 한도(10장)가 있으며, 광고를 보면 추가 삭제가 가능합니다."
            ),
            FAQItem(
                question: "구독했는데 프리미엄이 활성화되지 않아요",
                answer: "전체 메뉴 > 프리미엄 > \"구독 복원\"을 탭해주세요. 네트워크 연결 상태를 확인하고, 구독에 사용한 Apple ID로 로그인되어 있는지 확인해주세요."
            ),
            FAQItem(
                question: "구독을 해지하고 싶어요",
                answer: "설정 > [내 이름] > 구독 > PIClear Plus > 구독 취소를 탭하세요. 앱을 삭제해도 구독은 자동으로 해지되지 않으니 반드시 위 경로에서 취소해주세요."
            ),
            FAQItem(
                question: "환불받을 수 있나요?",
                answer: "환불은 Apple을 통해 처리됩니다. reportaproblem.apple.com에서 신청해주세요."
            ),
            FAQItem(
                question: "삭제 한도가 뭔가요?",
                answer: "무료 사용자는 하루 10장까지 삭제대기함 비우기가 가능합니다. 광고를 보면 하루 최대 30장까지 늘릴 수 있고, Plus 구독 시 무제한입니다. 한도는 매일 자정에 초기화됩니다."
            ),
        ]),
        FAQSection(title: "개인정보/보안", items: [
            FAQItem(
                question: "얼굴 인식 데이터는 어떻게 처리되나요?",
                answer: "얼굴 감지는 기기의 Vision 프레임워크를 사용하며, 기기 내에서만 처리됩니다. 얼굴 데이터는 서버에 전송되거나 저장되지 않습니다."
            ),
            FAQItem(
                question: "광고 추적을 끄고 싶어요",
                answer: "설정 > 개인정보 보호 및 보안 > 추적에서 PIClear의 추적 권한을 끌 수 있습니다. 추적을 끄면 맞춤형 광고 대신 일반 광고가 표시되며, 앱 기능에는 영향이 없습니다."
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
        title = "자주 묻는 질문"
        view.backgroundColor = .systemGroupedBackground
        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // iOS 16~25: FloatingTitleBar 뒤로가기 버튼만 추가
        if #unavailable(iOS 26.0) {
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay else { return }
            overlay.titleBar.setShowsBackButton(true) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // iOS 16~25: 뒤로가기 버튼 제거
        if #unavailable(iOS 26.0) {
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay else { return }
            overlay.titleBar.setShowsBackButton(false)
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
        accessibilityHint = isExpanded ? "탭하면 답변을 접습니다" : "탭하면 답변을 펼칩니다"
    }
}
