//
//  BusinessInfoViewController.swift
//  PickPhoto
//
//  사업자 정보 화면 (FR-048, T050)
//
//  전자상거래법 제10조에 따른 사업자 정보 표시:
//  - 상호 (사업자명)
//  - 대표자명
//  - 사업자등록번호
//  - 연락처 (이메일)
//
//  ⚠️ 초기 구현은 더미 데이터, 출시 전 실제 값으로 교체 (FR-048)
//

import UIKit
import AppCore
import OSLog

// MARK: - BusinessInfoViewController

/// 사업자 정보 화면
/// push로 표시
final class BusinessInfoViewController: UIViewController, BarsVisibilityControlling {

    /// FloatingOverlay 숨김 (iOS 16~25)
    var prefersFloatingOverlayHidden: Bool? { true }

    // MARK: - Data

    /// 사업자 정보 항목 (출시 전 실제 값으로 교체)
    private let infoItems: [(title: String, value: String)] = [
        ("상호", "TODO: 상호명 입력"),
        ("대표자", "TODO: 대표자명 입력"),
        ("사업자등록번호", "TODO: 000-00-00000"),
        ("연락처", "support@piclear.app"),
    ]

    // MARK: - UI Components

    /// 테이블 뷰
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.isScrollEnabled = false
        return tv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "사업자 정보"
        view.backgroundColor = .systemGroupedBackground
        setupTableView()
        Logger.app.debug("BusinessInfoVC: 사업자 정보 화면 표시")
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

extension BusinessInfoViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        infoItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        let item = infoItems[indexPath.row]
        cell.textLabel?.text = item.title
        cell.textLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        cell.textLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.text = item.value
        cell.detailTextLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        cell.detailTextLabel?.textColor = .label
        cell.selectionStyle = .none

        // 접근성
        cell.accessibilityLabel = "\(item.title): \(item.value)"

        return cell
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "전자상거래 등에서의 소비자보호에 관한 법률 제10조에 따른 사업자 정보입니다."
    }
}
