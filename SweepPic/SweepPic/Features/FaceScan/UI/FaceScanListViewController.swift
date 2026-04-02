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
import BlurUIKit
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

    // MARK: - Header (iOS 16~25 커스텀 헤더)

    /// iOS 16~25 커스텀 헤더 뷰 (FloatingOverlay 대체)
    private var customHeaderView: UIView?

    /// 그라데이션 딤 레이어 (헤더용)
    private var headerGradientLayer: CAGradientLayer?

    /// 커스텀 헤더 높이 (safe area 상단 + 44 + 35)
    private var customHeaderHeight: CGFloat {
        let contentHeight: CGFloat = 44
        let gradientExtension: CGFloat = 35
        return view.safeAreaInsets.top + contentHeight + gradientExtension
    }

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
        tv.contentInsetAdjustmentBehavior = .never  // 수동 inset 관리 (PreviewGridVC 패턴)
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

    deinit {
        scanTask?.cancel()
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

        // iOS 26: 시스템 네비바 표시 (뒤로가기 + 타이틀)
        if #available(iOS 26.0, *) {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }

        // 비교 화면에서 돌아온 경우 dim 상태 갱신
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // iOS 16~25: 시스템 네비바 다시 숨김 (FloatingOverlay 복원)
        if #unavailable(iOS 26.0) {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
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
        // 1. 테이블뷰: 전체 화면 edge-to-edge (PreviewGridVC 패턴)
        //    헤더/진행바는 오버레이, contentInset으로 콘텐츠 영역 확보
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 2. 헤더 오버레이 (iOS 16~25 커스텀 / iOS 26 시스템)
        setupHeader()

        // 3. 진행바 오버레이 (화면 하단)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressBar)
        NSLayoutConstraint.activate([
            progressBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: FaceScanProgressBar.barHeight),
        ])

        // 4. 빈 상태 라벨 (중앙)
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])

        // 5. Z-order: 테이블뷰(뒤) → 헤더 → 진행바 → 빈 라벨(앞)
        if let header = customHeaderView {
            view.bringSubviewToFront(header)
        }
        view.bringSubviewToFront(progressBar)
        view.bringSubviewToFront(emptyLabel)

        // 6. 초기 contentInset 설정
        updateTableViewInsets()
    }

    // MARK: - Header

    /// 헤더 구성 (iOS 버전별 분기)
    private func setupHeader() {
        if #available(iOS 26.0, *) {
            // iOS 26: 시스템 네비바 사용 — title은 viewDidLoad에서 설정됨
            // 뒤로가기 버튼은 시스템이 자동 생성
        } else {
            // iOS 16~25: 커스텀 헤더 (PreviewGridVC 패턴)
            setupCustomHeader()
        }
    }

    /// iOS 16~25: 커스텀 헤더 (FloatingTitleBar 스타일)
    /// progressive blur + 딤 + 뒤로가기 버튼 + 타이틀
    private func setupCustomHeader() {
        let contentHeight: CGFloat = 44
        let gradientExtension: CGFloat = 35
        let maxDimAlpha: CGFloat = LiquidGlassStyle.maxDimAlpha

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.backgroundColor = .clear
        view.addSubview(header)

        // Progressive blur (BlurUIKit)
        let blurView = VariableBlurView()
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.direction = .down
        blurView.maximumBlurRadius = 1.5
        blurView.dimmingTintColor = UIColor.black
        blurView.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.45, darkModeAlpha: 0.3)
        header.addSubview(blurView)

        // 그라데이션 딤
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(maxDimAlpha).cgColor,
            UIColor.black.withAlphaComponent(maxDimAlpha * 0.7).cgColor,
            UIColor.black.withAlphaComponent(maxDimAlpha * 0.3).cgColor,
            UIColor.black.withAlphaComponent(maxDimAlpha * 0.1).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0, 0.25, 0.5, 0.75, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        header.layer.addSublayer(gradientLayer)
        self.headerGradientLayer = gradientLayer

        // 뒤로가기 버튼 (GlassIconButton)
        let backButton = GlassIconButton(icon: "chevron.left", size: .medium, tintColor: .white)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        header.addSubview(backButton)

        // 타이틀 라벨
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.text = "인물사진 비교정리"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            // 헤더
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: contentHeight + gradientExtension
            ),

            // blur
            blurView.topAnchor.constraint(equalTo: header.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),

            // 뒤로가기 버튼
            backButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 29
            ),

            // 타이틀
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
        ])

        self.customHeaderView = header
    }

    /// 뒤로가기 버튼 탭 (iOS 16~25)
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 그라데이션 딤 프레임 업데이트
        if let header = customHeaderView {
            headerGradientLayer?.frame = header.bounds
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewInsets()
    }

    // MARK: - Content Inset

    /// 테이블뷰 contentInset 업데이트 (헤더 + 진행바 영역)
    ///
    /// PreviewGridVC 패턴: contentInsetAdjustmentBehavior = .never + 수동 inset 관리
    /// 진행바 fade out 시 inset 축소 → 테이블 콘텐츠가 자연스럽게 올라감
    private func updateTableViewInsets() {
        // 상단: 헤더 높이
        var topInset: CGFloat
        if customHeaderView != nil {
            // iOS 16~25: safe area + 헤더 콘텐츠 (44pt)
            topInset = view.safeAreaInsets.top + 44
        } else {
            // iOS 26: safe area (시스템 네비바 포함)
            topInset = view.safeAreaInsets.top
        }

        // 하단: safe area bottom + 진행바 높이 (보이는 경우)
        var bottomInset = view.safeAreaInsets.bottom
        if !progressBar.isHidden {
            bottomInset += FaceScanProgressBar.barHeight
        }

        tableView.contentInset = UIEdgeInsets(
            top: topInset, left: 0, bottom: bottomInset, right: 0
        )
        tableView.verticalScrollIndicatorInsets = UIEdgeInsets(
            top: topInset, left: 0, bottom: bottomInset, right: 0
        )
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

        // 진행바 완료 문구 표시
        progressBar.showCompletion(groupCount: groups.count)

        // 0그룹일 때 안내 메시지
        if groups.isEmpty {
            emptyLabel.text = "비교할 인물사진 그룹을\n찾지 못했습니다"
            emptyLabel.isHidden = false
        }

        Logger.similarPhoto.debug("FaceScanListVC: 분석 완료 — \(self.groups.count)그룹 발견")

        // 진행바 fade out + contentInset 동시 애니메이션
        // 진행바가 사라지면서 테이블 콘텐츠가 자연스럽게 올라감
        DispatchQueue.main.asyncAfter(deadline: .now() + FaceScanConstants.progressBarFadeDelay) {
            [weak self] in
            guard let self = self else { return }
            UIView.animate(
                withDuration: FaceScanConstants.progressBarFadeDuration,
                animations: {
                    self.progressBar.alpha = 0
                    // contentInset 동시 갱신 — 부드러운 전환
                    var inset = self.tableView.contentInset
                    inset.bottom -= FaceScanProgressBar.barHeight
                    self.tableView.contentInset = inset
                    self.tableView.verticalScrollIndicatorInsets.bottom = inset.bottom
                },
                completion: { _ in
                    self.progressBar.isHidden = true
                }
            )
        }
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
