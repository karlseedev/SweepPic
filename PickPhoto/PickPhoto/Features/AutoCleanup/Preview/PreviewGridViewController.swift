//
//  PreviewGridViewController.swift
//  SweepPic
//
//  Created by Claude on 2026-02-12.
//
//  미리보기 그리드 메인 VC
//  - BaseGridViewController 상속 안 함 (PhotoCell + BannerCell 혼합 + 배열 기반)
//  - CompositionalLayout: 사진 섹션(3열) + 배너 섹션(전체 너비)
//  - 단계적 확장: "기준 낮춰서 더 보기" → 새 섹션 삽입 + 자동 스크롤
//  - 하단 고정 버튼: "탐색된 N장 삭제대기함으로 이동" / "N점 사진 N장 제외하기" / "N점 사진 N장 더 보기"
//

import UIKit
import Photos
import AppCore
import BlurUIKit
import OSLog

// MARK: - PreviewGridViewControllerDelegate

/// 미리보기 그리드 delegate
protocol PreviewGridViewControllerDelegate: AnyObject {
    /// 정리 확인 — assetIDs를 삭제대기함으로 이동
    func previewGridVC(_ vc: PreviewGridViewController, didConfirmCleanup assetIDs: [String])
}

// MARK: - SectionType

/// 섹션 타입 (사진 그리드 또는 배너)
private enum SectionType {
    case photos([PreviewCandidate])
    case banner(scoreRange: String, count: Int)  // 품질지수 구간 + 개수
}

// MARK: - PreviewGridViewController

/// 미리보기 그리드 메인 VC
///
/// 분석 결과를 3열 그리드로 표시하며, 단계적 확장을 지원합니다.
/// PhotoCell은 기존 것을 재사용하고, BannerCell은 신규.
final class PreviewGridViewController: UIViewController {

    // MARK: - Properties

    /// 분석 결과 (제외 시 새 인스턴스로 재할당)
    private var previewResult: PreviewResult

    /// 현재 표시 단계
    private var currentStage: PreviewStage = .light

    /// 뷰어에서 제외된 assetID (viewWillAppear에서 일괄 반영)
    private var excludedAssetIDs: Set<String> = []

    /// delegate
    weak var delegate: PreviewGridViewControllerDelegate?

    // MARK: - Analytics Tracking (이벤트 7-2)

    /// 분석 소요 시간 (GridVC+Cleanup에서 설정)
    var analysisDuration: TimeInterval = 0

    /// "더 보기" 탭 횟수
    private var analyticsExpandCount: Int = 0

    /// 뷰어 열람 횟수
    private var analyticsViewerOpenCount: Int = 0

    /// 뷰어에서 제외한 횟수 (excludedAssetIDs는 applyExclusions 후 초기화되므로 별도 카운터)
    private var analyticsExcludeCount: Int = 0

    /// "제외하기" (단계 축소) 탭 횟수
    private var analyticsCollapseCount: Int = 0

    /// 최대 도달 단계 (expand 시에만 갱신, collapse해도 유지)
    private var analyticsMaxStage: PreviewStage = .light

    /// 최종 행동이 기록되었는지 (중복 전송 방지)
    private var analyticsEventSent: Bool = false

    /// 흐름 완료 콜백 (이벤트 7-1: 기존 정리 퍼널 추적용)
    /// - Parameter: 실제 이동된 사진 수 (닫기면 0)
    var onFlowComplete: ((Int) -> Void)?

    // MARK: - Header (iOS 18 커스텀 헤더)

    /// iOS 18 커스텀 헤더 뷰 (FloatingOverlay 대체)
    private var customHeaderView: UIView?

    /// iOS 18 커스텀 헤더 타이틀 라벨
    private var headerTitleLabel: UILabel?

    /// iOS 18 커스텀 헤더 그라데이션 딤 레이어
    private var headerGradientLayer: CAGradientLayer?

    /// 하단 뷰 높이 제약 (safe area 변경 시 업데이트)
    private var bottomViewHeightConstraint: NSLayoutConstraint?

    // MARK: - UI Elements

    /// 컬렉션뷰
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        cv.backgroundColor = .systemBackground
        cv.dataSource = self
        cv.delegate = self
        cv.prefetchDataSource = self
        cv.contentInsetAdjustmentBehavior = .never  // 수동 inset 관리 (시스템 자동 inset 이중 적용 방지)
        cv.translatesAutoresizingMaskIntoConstraints = false

        // 셀 등록
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        cv.register(PreviewBannerCell.self, forCellWithReuseIdentifier: PreviewBannerCell.reuseIdentifier)

        return cv
    }()

    /// 하단 고정 버튼 영역
    private let bottomView = PreviewBottomView()

    // MARK: - Constants

    /// 셀 간격
    private let cellSpacing: CGFloat = 2.0

    /// 열 수
    private let columns: CGFloat = 3

    /// 배너 높이
    private let bannerHeight: CGFloat = 44

    // MARK: - Initialization

    init(previewResult: PreviewResult) {
        self.previewResult = previewResult
        super.init(nibName: nil, bundle: nil)

        // 탭바 숨김 (push 시 하단 탭 제거)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateHeader()
        updateBottomView()

        // [DEBUG] 롱프레스로 분석 상세 팝업 표시
        #if DEBUG
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleDebugLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        collectionView.addGestureRecognizer(longPress)
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 뷰어에서 돌아올 때 제외된 사진 반영
        if !excludedAssetIDs.isEmpty {
            applyExclusions()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // 컬렉션뷰: 전체 화면 (헤더/하단 뷰 뒤에 깔림)
        view.addSubview(collectionView)

        // 헤더 설정 (iOS 26: 시스템 네비바, iOS 18: 블러 오버레이 헤더)
        // ⚠️ 컬렉션뷰 뒤에 addSubview되어야 오버레이가 위에 표시됨
        setupHeader()

        // 하단 버튼 영역
        bottomView.delegate = self
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomView)

        NSLayoutConstraint.activate([
            // 컬렉션뷰: 전체 화면 (헤더 아래로 콘텐츠 스크롤)
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 하단 뷰: 하단 고정
            bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 하단 뷰 높이: contentHeight + safe area bottom (초기값, viewSafeAreaInsetsDidChange에서 업데이트)
        let initialBottom = max(view.safeAreaInsets.bottom, 20)
        let heightConstraint = bottomView.heightAnchor.constraint(equalToConstant: PreviewBottomView.contentHeight + initialBottom)
        heightConstraint.isActive = true
        bottomViewHeightConstraint = heightConstraint

        // 컬렉션뷰 inset (상단 헤더 + 하단 버튼 가려지지 않도록)
        updateCollectionViewInsets()
    }

    // MARK: - Header Setup

    /// 헤더 설정 (iOS 버전별 분기)
    private func setupHeader() {
        if #available(iOS 26.0, *) {
            setupSystemNavHeader()
        } else {
            setupCustomHeader()
        }
    }

    /// iOS 26: 시스템 네비게이션 바에 X 버튼 설정
    @available(iOS 26.0, *)
    private func setupSystemNavHeader() {
        // 뒤로가기 버튼 숨기고 X 버튼으로 대체
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
    }

    /// iOS 18: FloatingTitleBar와 동일한 블러+딤 오버레이 헤더
    /// - VariableBlurView (progressive blur, 상→하 페이드아웃)
    /// - CAGradientLayer (딤, 상→하 5단계 페이드)
    /// - 컬렉션뷰 위에 오버레이되어 콘텐츠가 아래로 스크롤됨
    private func setupCustomHeader() {
        // FloatingTitleBar 상수와 동일
        let contentHeight: CGFloat = 44
        let gradientExtension: CGFloat = 35
        let maxDimAlpha: CGFloat = LiquidGlassStyle.maxDimAlpha

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        // 배경 투명 (블러+딤이 처리)
        header.backgroundColor = .clear
        view.addSubview(header)

        // Progressive blur (BlurUIKit) — FloatingTitleBar와 동일
        let progressiveBlurView = VariableBlurView()
        progressiveBlurView.translatesAutoresizingMaskIntoConstraints = false
        progressiveBlurView.direction = .down
        progressiveBlurView.maximumBlurRadius = 1.5
        progressiveBlurView.dimmingTintColor = UIColor.black
        progressiveBlurView.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.45, darkModeAlpha: 0.3)
        header.addSubview(progressiveBlurView)

        // 그라데이션 딤 레이어 — FloatingTitleBar와 동일
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

        // X 버튼 (GlassIconButton — 앱 전체 통일 스타일)
        let closeButton = GlassIconButton(icon: "xmark", size: .medium, tintColor: .white)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        header.addSubview(closeButton)

        // 타이틀 라벨 (흰색 — 딤 배경 위에 표시)
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            // 헤더: safe area + contentHeight + gradientExtension (FloatingTitleBar와 동일)
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: contentHeight + gradientExtension
            ),

            // Progressive blur: 전체 + 8pt 넘침 (FloatingTitleBar와 동일)
            progressiveBlurView.topAnchor.constraint(equalTo: header.topAnchor),
            progressiveBlurView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            progressiveBlurView.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            progressiveBlurView.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),

            // X 버튼: 좌측, safe area 기준 (콘텐츠 영역 중앙)
            // GlassIconButton .medium = 44×44 (intrinsicContentSize로 크기 자동 결정)
            closeButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 8),
            closeButton.centerYAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 29  // FloatingTitleBar와 동일한 centerY
            ),

            // 타이틀: 중앙, X 버튼과 같은 세로 위치
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
        ])

        self.customHeaderView = header
        self.headerTitleLabel = titleLabel
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCollectionViewInsets()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 그라데이션 딤 레이어 프레임 업데이트 (FloatingTitleBar와 동일 패턴)
        if let header = customHeaderView {
            headerGradientLayer?.frame = header.bounds
        }
    }

    /// 컬렉션뷰 inset 업데이트 (상단 헤더 + 하단 버튼 영역)
    private func updateCollectionViewInsets() {
        // 상단: iOS 18 커스텀 헤더 높이, iOS 26은 safe area + 네비바 높이
        let topInset: CGFloat
        if let header = customHeaderView {
            // iOS 18: 커스텀 헤더 높이 (블러+딤 오버레이)
            topInset = header.frame.height > 0 ? header.frame.height : (view.safeAreaInsets.top + 52)
        } else {
            // iOS 26: contentInsetAdjustmentBehavior = .never이므로 safe area 수동 적용
            topInset = view.safeAreaInsets.top
        }

        // 하단: 버튼 영역 높이 + safe area bottom 반영
        let safeBottom = max(view.safeAreaInsets.bottom, 20)
        bottomViewHeightConstraint?.constant = PreviewBottomView.contentHeight + safeBottom
        let bottomInset = PreviewBottomView.contentHeight + safeBottom

        collectionView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
        collectionView.verticalScrollIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
    }

    // MARK: - Layout

    /// CompositionalLayout 생성
    private func createLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self else { return nil }

            let sectionType = self.sectionType(for: sectionIndex)

            switch sectionType {
            case .photos:
                return self.photosSection(environment: environment)
            case .banner:
                return self.bannerSection()
            }
        }
    }

    /// 사진 섹션 레이아웃 (3열 정사각형)
    private func photosSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let totalSpacing = cellSpacing * (columns - 1)
        let availableWidth = environment.container.effectiveContentSize.width
        let cellWidth = floor((availableWidth - totalSpacing) / columns)
        let fraction = cellWidth / availableWidth

        // 아이템
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(fraction),
            heightDimension: .fractionalWidth(fraction)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // 그룹 (가로 3개)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(fraction)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.interItemSpacing = .fixed(cellSpacing)

        // 섹션
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        return section
    }

    /// 배너 섹션 레이아웃 (전체 너비 1행)
    private func bannerSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(bannerHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(bannerHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        return section
    }

    // MARK: - Section Mapping

    /// 섹션 수 (currentStage에 따라 동적)
    /// light: 사진만 (배너 없음), standard/deep: 배너+사진 쌍으로 구성
    private var numberOfSections: Int {
        switch currentStage {
        case .light:
            return 1  // 사진만 (배너 없음)
        case .standard:
            return 4  // 배너, 사진, 배너, 사진
        case .deep:
            return 6  // 배너, 사진, 배너, 사진, 배너, 사진
        }
    }

    /// 섹션 인덱스에 대한 섹션 타입
    ///
    /// light: 0=사진
    /// standard/deep: 0=배너(5등급), 1=light사진, 2=배너(4등급), 3=standard사진,
    ///                4=배너(3등급), 5=deep사진
    private func sectionType(for sectionIndex: Int) -> SectionType {
        // light 단계: 배너 없이 사진만
        if currentStage == .light {
            return .photos(previewResult.lightCandidates)
        }

        // standard/deep: 배너 포함 전체 매핑
        switch sectionIndex {
        case 0:
            return .banner(scoreRange: "5등급", count: previewResult.lightCount)
        case 1:
            return .photos(previewResult.lightCandidates)
        case 2:
            return .banner(scoreRange: "4등급", count: previewResult.standardCount)
        case 3:
            return .photos(previewResult.standardCandidates)
        case 4:
            return .banner(scoreRange: "3등급", count: previewResult.deepCount)
        case 5:
            return .photos(previewResult.deepCandidates)
        default:
            return .photos([])
        }
    }

    /// 섹션의 후보 배열 반환 (사진 섹션인 경우)
    private func candidates(for sectionIndex: Int) -> [PreviewCandidate]? {
        switch sectionType(for: sectionIndex) {
        case .photos(let candidates):
            return candidates
        case .banner:
            return nil
        }
    }

    // MARK: - Thumbnail

    /// 썸네일 크기 계산
    private func thumbnailSize() -> CGSize {
        let scale = UIScreen.main.scale
        let totalSpacing = cellSpacing * (columns - 1)
        let cellWidth = floor((collectionView.bounds.width - totalSpacing) / columns)
        return CGSize(width: cellWidth * scale, height: cellWidth * scale)
    }

    // MARK: - Header & Bottom Update

    /// 헤더 제목 업데이트
    /// - light: "품질 5등급 사진 N장"
    /// - standard: "품질 4등급 이하 사진 N장"
    /// - deep: "품질 3등급 이하 사진 N장"
    private func updateHeader() {
        let count = previewResult.count(upToStage: currentStage)

        // 단계별 등급 (숫자가 높을수록 저품질: 5등급=최저, 3등급=보통이하)
        let titleText: String
        switch currentStage {
        case .light:    titleText = "품질 5등급 사진 \(count)장"
        case .standard: titleText = "품질 4등급 이하 사진 \(count)장"
        case .deep:     titleText = "품질 3등급 이하 사진 \(count)장"
        }

        // iOS 26: 시스템 네비바 타이틀
        title = titleText
        // iOS 18: 커스텀 헤더 라벨
        headerTitleLabel?.text = titleText
    }

    /// 하단 버튼 영역 업데이트
    private func updateBottomView() {
        let totalCount = previewResult.count(upToStage: currentStage)

        // 확장 가능 여부: 다음 단계가 있고 + 추가분이 있고 + iOS 18 이상
        let canExpand: Bool
        if currentStage >= .deep {
            canExpand = false
        } else if currentStage == .light && previewResult.standardCount == 0 {
            canExpand = false
        } else if currentStage == .standard && previewResult.deepCount == 0 {
            canExpand = false
        } else {
            // iOS 16~17에서는 path2가 없어서 standard/deep이 빈 배열 → 확장 불가
            if #available(iOS 18.0, *) {
                canExpand = true
            } else {
                canExpand = false
            }
        }

        bottomView.configure(
            currentStage: currentStage,
            totalCount: totalCount,
            standardCount: previewResult.standardCount,
            deepCount: previewResult.deepCount,
            canExpand: canExpand
        )
    }

    // MARK: - Close Action

    /// X 버튼 탭 — 실수 방지 확인 Alert
    @objc private func closeTapped() {
        let alert = UIAlertController(
            title: "분석 결과를 닫으시겠습니까?",
            message: "현재 화면을 닫으면 분석 결과가 사라집니다.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "닫기", style: .destructive) { [weak self] _ in
            // [Analytics] 이벤트 7-2: 닫기
            self?.sendPreviewAnalyticsEvent(finalAction: .close, movedCount: 0)
            self?.navigationController?.popViewController(animated: true)
        })

        present(alert, animated: true)
    }

    // MARK: - Viewer

    /// 현재 표시 중인 모든 사진 (뷰어용 flat 배열)
    private func allVisibleAssets() -> [PHAsset] {
        var assets: [PHAsset] = []
        assets.append(contentsOf: previewResult.lightCandidates.map(\.asset))
        if currentStage >= .standard {
            assets.append(contentsOf: previewResult.standardCandidates.map(\.asset))
        }
        if currentStage >= .deep {
            assets.append(contentsOf: previewResult.deepCandidates.map(\.asset))
        }
        return assets
    }

    // MARK: - Cleanup Actions

    /// 정리 확인 Alert 표시
    private func showCleanupConfirmation(assetIDs: [String]) {
        // 현재 단계에 따른 등급 텍스트
        let gradeText: String
        switch currentStage {
        case .light:    gradeText = "품질 5등급"
        case .standard: gradeText = "품질 4등급 이하"
        case .deep:     gradeText = "품질 3등급 이하"
        }

        let alert = UIAlertController(
            title: "\(gradeText) 사진 \(assetIDs.count)장을\n삭제대기함으로 이동할까요?",
            message: nil,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "이동하기", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            // [Analytics] 이벤트 7-2: 삭제대기함 이동
            self.sendPreviewAnalyticsEvent(finalAction: .moveToTrash, movedCount: assetIDs.count)
            self.delegate?.previewGridVC(self, didConfirmCleanup: assetIDs)
            self.navigationController?.popViewController(animated: true)
        })

        present(alert, animated: true)
    }

    // MARK: - Analytics Helper (이벤트 7-2)

    /// 미리보기 정리 분석 이벤트 전송
    /// - Parameters:
    ///   - finalAction: 최종 행동 (삭제대기함 이동 or 닫기)
    ///   - movedCount: 삭제대기함 이동 수
    func sendPreviewAnalyticsEvent(finalAction: PreviewFinalAction, movedCount: Int) {
        guard !analyticsEventSent else { return }
        analyticsEventSent = true

        // analyticsMaxStage → PreviewMaxStage 변환 (최대 도달 단계)
        let maxStage: PreviewMaxStage
        switch analyticsMaxStage {
        case .light:    maxStage = .light
        case .standard: maxStage = .standard
        case .deep:     maxStage = .deep
        }

        let data = PreviewCleanupEventData(
            reachedStage: .finalAction,
            foundCount: previewResult.totalCount,
            durationSec: analysisDuration,
            maxStageReached: maxStage,
            expandCount: analyticsExpandCount,
            collapseCount: analyticsCollapseCount,
            excludeCount: analyticsExcludeCount,
            viewerOpenCount: analyticsViewerOpenCount,
            finalAction: finalAction,
            movedCount: movedCount
        )

        AnalyticsService.shared.trackPreviewCleanupCompleted(data: data)

        // [Analytics] 이벤트 7-1: 기존 정리 퍼널 추적 콜백
        onFlowComplete?(movedCount)
    }
}

// MARK: - UICollectionViewDataSource

extension PreviewGridViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return numberOfSections
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sectionType(for: section) {
        case .photos(let candidates):
            return candidates.count
        case .banner:
            return 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sectionType(for: indexPath.section) {
        case .photos(let candidates):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PhotoCell.reuseIdentifier,
                for: indexPath
            ) as! PhotoCell

            let candidate = candidates[indexPath.item]
            cell.configure(
                asset: candidate.asset,
                isTrashed: false,
                targetSize: thumbnailSize()
            )

            // [DEBUG] 셀 위에 assetID 앞 6자 + 신호 요약 표시
            // TODO: 스크린샷 촬영 후 복원할 것
            // #if DEBUG
            // configureDebugOverlay(on: cell, candidate: candidate)
            // #endif

            return cell

        case .banner(let scoreRange, let count):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PreviewBannerCell.reuseIdentifier,
                for: indexPath
            ) as! PreviewBannerCell

            cell.configure(scoreRange: scoreRange, count: count)
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegate

extension PreviewGridViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        // 배너 셀은 무시
        guard case .photos(let candidates) = sectionType(for: indexPath.section),
              indexPath.item < candidates.count else { return }

        // 탭한 사진의 flat 배열 내 인덱스 계산
        let allAssets = allVisibleAssets()
        let tappedAssetID = candidates[indexPath.item].assetID
        guard let viewerIndex = allAssets.firstIndex(where: { $0.localIdentifier == tappedAssetID }) else { return }

        // [Analytics] 이벤트 7-2: 뷰어 열람 카운트
        analyticsViewerOpenCount += 1

        // 뷰어 push (미리보기 전용 코디네이터, 정리 모드)
        let coordinator = PreviewViewerCoordinator(assets: allAssets)
        let viewerVC = ViewerViewController(coordinator: coordinator, startIndex: viewerIndex, mode: .cleanup)
        viewerVC.delegate = self
        navigationController?.pushViewController(viewerVC, animated: true)
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension PreviewGridViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assetIDs = indexPaths.compactMap { ip -> String? in
            guard let candidates = candidates(for: ip.section),
                  ip.item < candidates.count else { return nil }
            return candidates[ip.item].assetID
        }

        guard !assetIDs.isEmpty else { return }
        ImagePipeline.shared.preheat(assetIDs: assetIDs, targetSize: thumbnailSize())
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assetIDs = indexPaths.compactMap { ip -> String? in
            guard let candidates = candidates(for: ip.section),
                  ip.item < candidates.count else { return nil }
            return candidates[ip.item].assetID
        }

        guard !assetIDs.isEmpty else { return }
        ImagePipeline.shared.stopPreheating(assetIDs: assetIDs)
    }
}

// MARK: - BarsVisibilityControlling

extension PreviewGridViewController: BarsVisibilityControlling {
    /// iOS 18: FloatingOverlay 숨김 (자체 네비바 사용)
    var prefersFloatingOverlayHidden: Bool? { true }

    /// iOS 26: 시스템 탭바 숨김
    var prefersSystemTabBarHidden: Bool? { true }
}

// MARK: - PreviewBottomViewDelegate

extension PreviewGridViewController: PreviewBottomViewDelegate {

    func previewBottomViewDidTapCleanup(_ view: PreviewBottomView) {
        // 현재 단계까지의 모든 assetIDs
        let assetIDs = previewResult.assetIDs(upToStage: currentStage)
        showCleanupConfirmation(assetIDs: assetIDs)
    }

    func previewBottomViewDidTapCollapse(_ view: PreviewBottomView) {
        // [Analytics] 이벤트 7-2: "제외하기" (단계 축소) 카운트
        analyticsCollapseCount += 1

        // 단계 축소 (expand의 역동작)
        // .standard → .light: 섹션 [0, 2, 3] 삭제 (light배너 + standard배너 + standard사진)
        // .deep → .standard: 섹션 [4, 5] 삭제 (deep배너 + deep사진)
        let previousStage: PreviewStage
        let sectionsToDelete: IndexSet
        switch currentStage {
        case .standard:
            previousStage = .light
            sectionsToDelete = IndexSet([0, 2, 3])  // light배너도 함께 제거
        case .deep:
            previousStage = .standard
            sectionsToDelete = IndexSet([4, 5])
        default:
            return
        }

        // 1. currentStage 변경 (numberOfSections 먼저 업데이트되도록)
        currentStage = previousStage

        // 2. 섹션 삭제 애니메이션
        collectionView.performBatchUpdates {
            collectionView.deleteSections(sectionsToDelete)
        }

        // 3. 하단 버튼 + 헤더 업데이트
        updateBottomView()
        updateHeader()
    }

    func previewBottomViewDidTapExpand(_ view: PreviewBottomView) {
        guard let nextStage = currentStage.next else { return }

        // [Analytics] 이벤트 7-2: "더 보기" 카운트 + 최대 도달 단계 갱신
        analyticsExpandCount += 1
        if nextStage.rawValue > analyticsMaxStage.rawValue {
            analyticsMaxStage = nextStage
        }

        // 1. currentStage 변경 (numberOfSections 먼저 업데이트되도록)
        currentStage = nextStage

        // 2. 새 섹션 삽입
        collectionView.performBatchUpdates {
            let newSections: IndexSet
            switch nextStage {
            case .standard:
                newSections = IndexSet([0, 2, 3])  // light배너 + standard배너 + standard사진
            case .deep:
                newSections = IndexSet([4, 5])      // deep배너 + deep사진
            default:
                return
            }
            collectionView.insertSections(newSections)
        } completion: { [weak self] _ in
            guard let self else { return }

            // 3. 삽입 애니메이션 완료 후 배너 위치로 스크롤
            let bannerSection: Int
            switch nextStage {
            case .standard:
                bannerSection = 2
            case .deep:
                bannerSection = 4
            default:
                return
            }

            self.collectionView.scrollToItem(
                at: IndexPath(item: 0, section: bannerSection),
                at: .top,
                animated: true
            )
        }

        // 4. 하단 버튼 + 헤더 업데이트
        updateBottomView()
        updateHeader()
    }

    // MARK: - Exclude Support

    /// 뷰어에서 제외된 사진들을 그리드에 반영
    /// viewWillAppear에서 호출 (뷰어 pop 후)
    private func applyExclusions() {
        // previewResult에서 제외된 에셋 필터링
        previewResult = previewResult.excluding(excludedAssetIDs)

        // 적용 완료 — 제외 목록 초기화
        excludedAssetIDs.removeAll()

        // UI 갱신
        collectionView.reloadData()
        updateBottomView()
        updateHeader()
    }
}

// MARK: - ViewerViewControllerDelegate

extension PreviewGridViewController: ViewerViewControllerDelegate {

    func viewerDidRequestExclude(assetID: String) {
        // 뷰어가 제외를 요청하면 ID 기록 (viewWillAppear에서 일괄 반영)
        excludedAssetIDs.insert(assetID)
        // [Analytics] 제외 카운트 누적 (excludedAssetIDs는 applyExclusions에서 초기화되므로)
        analyticsExcludeCount += 1
    }

    func viewerDidRequestDelete(assetID: String) {}
    func viewerDidRequestRestore(assetID: String) {}
    func viewerDidRequestPermanentDelete(assetID: String) {}
    func viewerWillClose(currentAssetID: String?, originalIndex: Int?) {}
}

// MARK: - Debug Quality Overlay

#if DEBUG
extension PreviewGridViewController {

    /// 디버그 오버레이 태그 (재사용 시 중복 방지)
    private static let debugOverlayTag = 9999

    /// 롱프레스 제스처 핸들러 — 해당 셀의 분석 상세 팝업 표시
    @objc func handleDebugLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point),
              case .photos(let candidates) = sectionType(for: indexPath.section),
              indexPath.item < candidates.count else { return }

        let candidate = candidates[indexPath.item]
        showDebugAnalysisDetail(for: candidate)
    }

    /// 셀 위에 assetID + 신호 요약 오버레이 표시
    func configureDebugOverlay(on cell: UICollectionViewCell, candidate: PreviewCandidate) {
        // 기존 오버레이 제거 (셀 재사용 대응)
        cell.contentView.viewWithTag(Self.debugOverlayTag)?.removeFromSuperview()

        // assetID 앞 6자
        let idPrefix = String(candidate.assetID.prefix(6))

        // 신호 요약 (signals가 있으면 종류 나열, 없으면 score 표시)
        var infoLines = [idPrefix]

        if let result = candidate.qualityResult, !result.signals.isEmpty {
            // 신호 종류 나열 (축약)
            let signalNames = result.signals.map { shortName(for: $0.kind) }
            infoLines.append(signalNames.joined(separator: " "))
        }

        if let score = candidate.score {
            infoLines.append("S:\(String(format: "%.2f", score))")
        }

        // 라벨 생성
        let label = UILabel()
        label.tag = Self.debugOverlayTag
        label.text = infoLines.joined(separator: "\n")
        label.font = .systemFont(ofSize: 8, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 0
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false

        cell.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -2),
            label.trailingAnchor.constraint(lessThanOrEqualTo: cell.contentView.trailingAnchor, constant: -2),
        ])
    }

    /// 특정 사진의 분석 상세를 알림으로 표시 + 콘솔 로그 출력
    func showDebugAnalysisDetail(for candidate: PreviewCandidate) {
        var message = "Asset ID:\n\(candidate.assetID)\n"
        message += "\nStage: \(candidate.stage)"

        if let score = candidate.score {
            message += "\nAestheticsScore: \(String(format: "%.3f", score))"
        }

        if let result = candidate.qualityResult {
            message += "\nVerdict: \(result.verdict)"
            message += "\nMethod: \(result.analysisMethod.rawValue)"
            message += "\nTime: \(String(format: "%.1f", result.analysisTimeMs))ms"

            if !result.signals.isEmpty {
                message += "\n\n--- Signals ---"
                for signal in result.signals {
                    message += "\n[\(shortName(for: signal.kind))]"
                    message += " val:\(String(format: "%.3f", signal.measuredValue))"
                    message += " thr:\(String(format: "%.3f", signal.threshold))"
                }
            }

            // SafeGuard 정보 (path1: QualityResult에서)
            message += "\n\n--- SafeGuard(path1) ---"
            if result.safeGuardApplied, let reason = result.safeGuardReason {
                message += "\nResult: APPLIED (\(reason.rawValue))"
            } else {
                message += "\nResult: NOT APPLIED"
            }
            message += "\nFaceCount: \(result.safeGuardFaceCount)"
            if let quality = result.safeGuardMaxFaceQuality {
                message += "\nFaceQuality: \(String(format: "%.3f", quality)) (threshold: 0.400)"
            } else {
                message += "\nFaceQuality: N/A (미체크)"
            }
        } else {
            message += "\n(QualityResult 없음)"
        }

        // SafeGuard 디버그 정보 (path2: CleanupPreviewService에서)
        if let sg = candidate.safeGuardDebug {
            message += "\n\n--- SafeGuard(path2) ---"
            message += "\nPortrait: \(sg.isPortrait ? "YES" : "NO")"
            message += "\nFaceCount: \(sg.faceCount)"
            if let quality = sg.maxFaceQuality {
                message += "\nFaceQuality: \(String(format: "%.3f", quality)) (threshold: 0.400)"
            } else {
                message += "\nFaceQuality: N/A"
            }
            message += "\nResult: \(sg.applied ? "APPLIED (\(sg.reason?.rawValue ?? ""))" : "NOT APPLIED")"
        }

        // 콘솔 로그로 상세 정보 출력
        Logger.cleanup.notice("=== 디버그 분석 상세 ===\n\(message)")

        let alert = UIAlertController(title: "분석 상세", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel))
        // 클립보드 복사 버튼
        alert.addAction(UIAlertAction(title: "복사", style: .default) { _ in
            UIPasteboard.general.string = message
        })
        present(alert, animated: true)
    }

    /// SignalKind → 축약 이름 (셀 오버레이용)
    private func shortName(for kind: SignalKind) -> String {
        switch kind {
        case .extremeDark:      return "ExDk"
        case .extremeBright:    return "ExBr"
        case .severeBlur:       return "SvBl"
        case .tooShortVideo:    return "ShVd"
        case .pocketShot:       return "Pckt"
        case .extremeMonochrome: return "Mono"
        case .lensBlocked:      return "Lens"
        case .generalBlur:      return "Blur"
        case .generalExposure:  return "Expo"
        case .lowColorVariety:  return "LClr"
        case .lowResolution:    return "LRes"
        case .lowAesthetics:    return "LAes"
        }
    }
}
#endif
