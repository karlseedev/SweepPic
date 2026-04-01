//
//  FaceScanListViewController.swift
//  SweepPic
//
//  인물사진 비교정리 — 그룹 목록 화면
//
//  방식 선택 후 즉시 push되어 빈 상태로 진입.
//  분석이 진행되면서 그룹이 하나씩 추가됨 (스크롤 늘어남).
//  상단: 미니 진행바 (FaceScanProgressBar)
//  중앙: 빈 상태 라벨 / 그룹 목록
//  그룹 탭 → FaceComparisonVC (present modal)
//  dim 그룹 재진입 가능 (선택 수정)
//

import UIKit
import Photos
import AppCore
import OSLog

// MARK: - FaceScanListViewController

/// 인물사진 비교정리 그룹 목록 화면
final class FaceScanListViewController: UIViewController, BarsVisibilityControlling {

    // MARK: - BarsVisibilityControlling

    /// iOS 16~25: FloatingOverlay 숨김 (사진보관함 타이틀 + 버튼 제거)
    var prefersFloatingOverlayHidden: Bool? { true }

    // MARK: - Properties

    /// 스캔 방식
    private let method: FaceScanMethod

    /// 전용 캐시 (FaceComparisonVC에 주입)
    private let faceScanCache = FaceScanCache()

    /// 스캔 서비스
    private var scanService: FaceScanService?

    /// 스캔 Task (취소용)
    private var scanTask: Task<Void, Never>?

    /// 발견된 그룹 (콜백으로 추가)
    private var groups: [FaceScanGroup] = []

    /// 그룹별 삭제 상태 (메모리에만 유지)
    /// key: groupID, value: 삭제된 assetID 집합
    private var deletedAssetsByGroup: [String: Set<String>] = [:]

    /// 분석 완료 여부
    private var isAnalysisComplete: Bool = false

    /// 현재 열려있는 그룹 ID (delegate 콜백에서 사용)
    private var presentedGroupID: String?

    // MARK: - UI Components

    /// 테이블뷰 (그룹 셀 목록)
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = .systemBackground
        tv.dataSource = self
        tv.delegate = self
        tv.separatorStyle = .singleLine
        tv.separatorColor = .separator
        tv.register(FaceScanGroupCell.self, forCellReuseIdentifier: FaceScanGroupCell.reuseIdentifier)
        tv.rowHeight = FaceScanGroupCell.cellHeight
        return tv
    }()

    /// 미니 진행바
    private let progressBar = FaceScanProgressBar()

    /// 빈 상태 라벨 ("분석 중" / "비교할 인물사진 그룹을 찾지 못했습니다")
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "분석 중"
        return label
    }()

    // MARK: - Init

    init(method: FaceScanMethod) {
        self.method = method
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "인물사진 비교정리"

        setupUI()
        startAnalysis()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 비교 화면에서 돌아온 경우 dim 상태 갱신
        tableView.reloadData()
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)

        // 뒤로가기(pop) 감지
        if parent == nil {
            if !isAnalysisComplete {
                // 분석 중 닫기 → 분석 취소 + 데이터 버림
                scanService?.cancel()
                scanTask?.cancel()
                Logger.similarPhoto.debug("FaceScanListVC: 분석 중 닫기 — 취소 + 데이터 버림")
            } else {
                // 분석 완료 후 닫기 → 세션은 이미 저장됨
                Logger.similarPhoto.debug("FaceScanListVC: 분석 완료 후 닫기 — 세션 저장 완료")
            }
        }
    }

    // MARK: - Setup

    private func setupUI() {
        // 진행바 (상단)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBar)
        NSLayoutConstraint.activate([
            progressBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: FaceScanProgressBar.barHeight),
        ])

        // 테이블뷰
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: progressBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 빈 상태 라벨 (중앙)
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    // MARK: - Analysis

    /// 스캔 시작
    private func startAnalysis() {
        let service = FaceScanService(cache: faceScanCache)
        self.scanService = service

        scanTask = Task { [weak self] in
            do {
                try await service.analyze(
                    method: self?.method ?? .fromLatest,
                    onGroupFound: { [weak self] group in
                        self?.handleGroupFound(group)
                    },
                    onProgress: { [weak self] progress in
                        self?.handleProgress(progress)
                    }
                )

                // 분석 완료
                await MainActor.run { [weak self] in
                    self?.handleAnalysisComplete()
                }
            } catch is CancellationError {
                Logger.similarPhoto.debug("FaceScanListVC: 분석 취소됨")
            } catch {
                Logger.similarPhoto.error("FaceScanListVC: 분석 실패 — \(error.localizedDescription)")
                await MainActor.run { [weak self] in
                    self?.handleAnalysisComplete()
                }
            }
        }
    }

    /// 그룹 발견 처리 (메인 스레드에서 호출됨)
    @MainActor
    private func handleGroupFound(_ group: FaceScanGroup) {
        groups.append(group)

        // 빈 상태 라벨 숨김
        emptyLabel.isHidden = true

        // 테이블뷰에 행 삽입 (애니메이션)
        let indexPath = IndexPath(row: groups.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
    }

    /// 진행 상황 처리 (메인 스레드에서 호출됨)
    @MainActor
    private func handleProgress(_ progress: FaceScanProgress) {
        progressBar.update(with: progress)
    }

    /// 분석 완료 처리
    @MainActor
    private func handleAnalysisComplete() {
        isAnalysisComplete = true

        // 진행바 완료 처리
        progressBar.showCompletion(groupCount: groups.count)

        // 0그룹일 때 안내 메시지
        if groups.isEmpty {
            emptyLabel.text = "비교할 인물사진 그룹을\n찾지 못했습니다"
            emptyLabel.isHidden = false
        }

        Logger.similarPhoto.debug("FaceScanListVC: 분석 완료 — \(self.groups.count)그룹 발견")
    }

    // MARK: - Group Selection

    /// 그룹 탭 → FaceComparisonVC 표시
    private func presentComparison(for group: FaceScanGroup) {
        presentedGroupID = group.groupID

        // ComparisonGroup 생성 (자체 그룹 데이터에서, 첫 번째 사진 기준)
        let comparisonGroup = ComparisonGroup(
            sourceGroupID: group.groupID,
            selectedAssetIDs: Array(group.memberAssetIDs.prefix(
                SimilarityConstants.maxComparisonGroupSize
            )),
            personIndex: group.validPersonIndices.sorted().first ?? 1
        )

        // 초기 선택 상태 = 삭제된 assetID 집합
        let initialSelected = deletedAssetsByGroup[group.groupID] ?? []

        // FaceComparisonVC 생성 (전용 캐시 주입)
        let vc = FaceComparisonViewController(
            comparisonGroup: comparisonGroup,
            mode: .faceScan(initialSelected: initialSelected),
            cache: faceScanCache
        )
        vc.delegate = self

        // present (fullScreen modal) — iOS 버전별 분기
        if #available(iOS 26.0, *) {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }

    // MARK: - dim 상태 판단

    /// 그룹의 dim 여부 판단
    private func isGroupDimmed(_ groupID: String) -> Bool {
        guard let deleted = deletedAssetsByGroup[groupID] else { return false }
        return !deleted.isEmpty
    }
}

// MARK: - UITableViewDataSource

extension FaceScanListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: FaceScanGroupCell.reuseIdentifier,
            for: indexPath
        ) as? FaceScanGroupCell else {
            return UITableViewCell()
        }

        let group = groups[indexPath.row]
        let isDimmed = isGroupDimmed(group.groupID)
        cell.configure(with: group, isDimmed: isDimmed)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension FaceScanListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let group = groups[indexPath.row]
        presentComparison(for: group)
    }
}

// MARK: - FaceComparisonDelegate

extension FaceScanListViewController: FaceComparisonDelegate {

    /// FaceScan 모드: diff 적용 완료
    /// 첫 진입이든 재진입이든 항상 이 메서드가 호출됨
    func faceComparisonViewController(
        _ viewController: FaceComparisonViewController,
        didApplyChanges finalSelectedAssetIDs: Set<String>
    ) {
        guard let groupID = presentedGroupID else { return }

        // 최종 선택 상태로 교체
        deletedAssetsByGroup[groupID] = finalSelectedAssetIDs
        presentedGroupID = nil

        // dismiss 후 목록 갱신
        dismiss(animated: true) { [weak self] in
            self?.tableView.reloadData()
        }
    }

    /// 비교 화면 닫기 (변경사항 없이)
    func faceComparisonViewControllerDidClose(_ viewController: FaceComparisonViewController) {
        presentedGroupID = nil
    }

    /// 기존 뷰어용 — FaceScan에서는 호출되지 않음
    func faceComparisonViewController(
        _ viewController: FaceComparisonViewController,
        didDeletePhotos deletedAssetIDs: [String]
    ) {
        // FaceScan 모드에서는 사용하지 않음
    }
}
