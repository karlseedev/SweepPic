// PhotoCell.swift
// 사진 그리드 셀
//
// T021: PhotoCell 생성
// - 이미지 표시
// - 딤드 오버레이 50% opacity (FR-008)
// - 재사용 로직: 이전 요청 취소 + 토큰 검증
//
// T027: 삭제대기함 사진 딤드 표시 구현
// - isTrashed 체크 → 50% 검정 오버레이

import UIKit
import Photos
import AppCore

/// 사진 그리드 셀
/// 썸네일 표시 및 딤드 오버레이 지원
final class PhotoCell: UICollectionViewCell {

    // MARK: - Constants

    /// 재사용 식별자
    static let reuseIdentifier = "PhotoCell"

    /// 딤드 오버레이 투명도 (FR-008: 50% dark red opacity)
    private static let dimmedOverlayAlpha: CGFloat = 0.60

    /// 스와이프 오버레이 기본 색상 (Maroon #800000)
    private static let defaultOverlayColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)

    /// 스와이프 오버레이 복구 색상 (다크 그린)
    private static let restoreOverlayColor = UIColor(red: 0.0, green: 0.35, blue: 0.15, alpha: 1)

    // MARK: - Debug Timing (static)

    /// [DEBUG] requestImage 호출 횟수
    static var requestImageCount: Int = 0
    /// [DEBUG] requestImage 호출 누적 시간
    static var requestImageTotalTime: Double = 0

    /// [DEBUG] imageApply 호출 횟수
    static var imageApplyCount: Int = 0
    /// [DEBUG] imageApply 누적 시간
    static var imageApplyTotalTime: Double = 0

    /// [--log-thumb] configure 호출 횟수 (샘플링 로그용)
    static var configureCallCount: Int = 0
    /// [--log-thumb] pipeline 응답 횟수 (샘플링 로그용)
    static var pipelineResponseCount: Int = 0

    // MARK: - Mismatch Statistics (스크롤 중 버려진 작업 추적)

    /// 통계 락
    private static let mismatchLock = NSLock()

    /// 디스크 캐시 콜백이 버려진 횟수 (cacheLoadID mismatch)
    private static var diskCacheMismatchCount: Int = 0

    /// Pipeline 콜백이 버려진 횟수 (assetID mismatch)
    private static var pipelineMismatchCount: Int = 0

    // MARK: - Disk Save Deduplication (세션 내 중복 저장 방지)

    /// 저장 완료된 캐시 키 Set (동기 디스크 I/O 없이 중복 체크)
    /// - 키 형식: "assetID_modTimestamp_width_height"
    /// - 앱 재실행 시 초기화됨 (세션 내 중복 억제만)
    private static var savedCacheKeys: Set<String> = []
    private static let savedCacheKeysLock = NSLock()

    /// 캐시 키 생성 (ThumbnailCache.cachePath와 동일한 로직)
    private static func makeCacheKey(assetID: String, modDate: Date?, size: CGSize) -> String {
        let modString = modDate.map { String($0.timeIntervalSince1970) } ?? "nil"
        return "\(assetID)_\(modString)_\(Int(size.width))_\(Int(size.height))"
    }

    /// 캐시 키가 이미 저장되었는지 확인 (락 없이 호출 금지)
    private static func hasSaved(key: String) -> Bool {
        return savedCacheKeys.contains(key)
    }

    /// 캐시 키를 저장됨으로 표시
    private static func markSaved(key: String) {
        savedCacheKeys.insert(key)
    }

    /// 통계 리셋
    static func resetMismatchStats() {
        mismatchLock.withLock {
            diskCacheMismatchCount = 0
            pipelineMismatchCount = 0
        }
    }

    /// 통계 로그 출력
    static func logMismatchStats(label: String = "PhotoCell") {
        mismatchLock.lock()
        _ = diskCacheMismatchCount
        _ = pipelineMismatchCount
        mismatchLock.unlock()

        // 통계는 수집만 하고 로그 출력하지 않음
    }

    // MARK: - Gray Cell Statistics (회색 셀 측정)

    /// 회색 셀 통계 락
    private static let grayCellLock = NSLock()

    /// 회색 셀 표시 횟수 (configure 시 imageView.image == nil)
    private static var grayShownCount: Int = 0

    /// 회색 셀 해소 횟수 (이미지가 세팅됨)
    private static var grayResolvedCount: Int = 0

    /// 회색 셀 통계 리셋
    static func resetGrayCellStats() {
        grayCellLock.withLock {
            grayShownCount = 0
            grayResolvedCount = 0
        }
    }

    /// 회색 셀 통계 조회
    static func getGrayCellStats() -> (shown: Int, resolved: Int) {
        grayCellLock.lock()
        let shown = grayShownCount
        let resolved = grayResolvedCount
        grayCellLock.unlock()
        return (shown, resolved)
    }

    /// 회색 셀 표시 카운트 증가 (디버그 통계 전용)
    static func incrementGrayShown() {
        grayCellLock.withLock {
            grayShownCount += 1
        }
    }

    /// 현재 이미지가 nil인지 확인 (willDisplay에서 회색 셀 체크용)
    var isShowingGray: Bool {
        return imageView.image == nil
    }

    /// 사용자가 회색 셀을 본 것으로 표시 (willDisplay에서 세팅)
    /// - 카운트는 이미지 도착 또는 prepareForReuse 시 수행
    var wasShownAsGray = false

    /// 회색 셀 표시 시작 시각 (willDisplay에서 기록)
    /// - 인지 임계값(50ms) 초과 시에만 "사용자가 인지한 회색"으로 카운트
    /// - 근거: Del Cul et al.(2007) 역방향 마스킹 의식 접근 분기점 = 50ms
    var grayStartTime: CFTimeInterval = 0

    /// 회색 셀 인지 임계값 (50ms)
    /// - 120Hz: 6프레임, 60Hz: 3프레임
    /// - 이 시간 이내에 이미지가 도착하면 사용자는 회색을 의식적으로 인지하지 못함
    private static let grayPerceptibleThreshold: CFTimeInterval = 0.050

    // MARK: - iOS 18+ Zoom Transition Support

    /// 실제 이미지가 로드되었는지 확인 (placeholder가 아닌 경우)
    /// iOS 18+ zoom transition에서 sourceViewProvider가 품질 체크에 사용
    var hasLoadedImage: Bool {
        return imageView.image != nil
    }

    /// 썸네일 이미지 뷰 접근자 (읽기 전용)
    /// iOS 18+ zoom transition의 sourceViewProvider에서 줌 시작점으로 사용
    var thumbnailImageView: UIImageView {
        return imageView
    }

    /// 회색 셀 해소 카운트 증가 (내부용)
    private static func incrementGrayResolved() {
        grayCellLock.withLock {
            grayResolvedCount += 1
        }
    }

    /// 회색 셀 통계 로그 출력
    static func logGrayCellStats(label: String = "PhotoCell") {
        // 통계는 수집만 하고 로그 출력하지 않음
    }

    // MARK: - UI Components

    /// 썸네일 이미지 뷰
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray6
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    /// 딤드 오버레이 뷰 (삭제대기함 사진용) - 마룬 50%
    private let dimmedOverlayView: UIView = {
        let view = UIView()
        // Maroon (#800000)
        view.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        view.alpha = 0
        view.isHidden = true
        // translatesAutoresizingMaskIntoConstraints = true (기본값)
        // frame 기반 레이아웃 — CABackdropLayer가 position/bounds 변경을 추적하도록
        return view
    }()

    /// 선택 체크마크 뷰 (T039에서 사용)
    private let selectionCheckmarkView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemBlue
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        // iOS 사진 앱 스타일 체크마크 (SF Symbol)
        iv.image = UIImage(systemName: "checkmark.circle.fill")
        return iv
    }()

    /// 비디오 duration 배지 (T067에서 사용)
    private let videoDurationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.textAlignment = .right
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 비디오 재생 아이콘 (T067에서 사용)
    private let videoIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "play.fill")
        return iv
    }()

    /// 비디오 그라데이션 배경 (하단)
    private let videoGradientView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 그라데이션 레이어 (비디오 배지용)
    private var gradientLayer: CAGradientLayer?

    /// 삭제대기함 아이콘 (우측 상단, 삭제대기함 상태일 때 표시)
    private let trashIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "xmark.bin")
        return iv
    }()

    // MARK: - E-1 아이콘 애니메이션용

    /// 삭제대기함 아이콘의 window 좌표 frame (E-1 아이콘 이동 애니메이션용)
    /// trashIconView가 숨겨져 있거나 window가 없으면 nil 반환
    func trashIconFrameInWindow() -> CGRect? {
        guard !trashIconView.isHidden, let window = window else { return nil }
        return trashIconView.convert(trashIconView.bounds, to: window)
    }

    /// T073: iCloud 전용 사진 아이콘 (우측 상단 구름 아이콘)
    private let iCloudIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "icloud.and.arrow.down")
        // 그림자 효과 (가독성 향상)
        iv.layer.shadowColor = UIColor.black.cgColor
        iv.layer.shadowOffset = CGSize(width: 0, height: 1)
        iv.layer.shadowRadius = 2
        iv.layer.shadowOpacity = 0.5
        return iv
    }()

    // MARK: - Properties

    /// 현재 이미지 요청 토큰 (레거시 API용)
    private var currentRequestToken: RequestToken?

    /// 현재 이미지 요청 (새 API - Cancellable)
    private var currentCancellable: Cancellable?

    /// 비동기 캐시 로드 ID (캐시 로드 취소/검증용)
    private var currentCacheLoadID: UUID?

    /// 현재 표시 중인 에셋 ID
    private(set) var currentAssetID: String?

    /// 현재 로드된 썸네일 크기 (핀치줌 후 고해상도 재요청 판단용)
    private var currentTargetSize: CGSize = .zero

    /// 삭제대기함 상태
    private(set) var isTrashed: Bool = false

    /// 선택 상태 (T039에서 사용)
    var isSelectedForDeletion: Bool = false {
        didSet {
            updateSelectionUI()
        }
    }

    /// 터치 다운/업 시 즉시 축소 피드백 (시스템이 자동 설정)
    override var isHighlighted: Bool {
        didSet {
            updateTransform()
        }
    }

    // MARK: - PRD7: Swipe Delete Animation Properties

    /// 스와이프 오버레이 스타일 (삭제: 마룬, 복구: 녹색)
    enum SwipeOverlayStyle {
        case delete   // Maroon (기존)
        case restore  // Green (삭제대기함 복구용)
    }

    /// 현재 스와이프 오버레이 스타일
    var swipeOverlayStyle: SwipeOverlayStyle = .delete

    /// 스와이프 방향
    enum SwipeDirection {
        case left
        case right
    }

    /// 셀별 애니메이션 잠금 (PRD7: 연속 토글 방지)
    /// 애니메이션 중인 셀에는 추가 제스처를 무시
    var isAnimating: Bool = false

    /// 재사용 세대 카운터 (stale animation completion 방지)
    /// prepareForReuse마다 +1되어 이전 세대의 animation completion을 무효화
    private var reuseGeneration: UInt = 0

    /// 딤드 마스크 레이어 (커튼 효과용)
    /// 스와이프 진행도에 따라 빨간 딤드가 채워지거나 걷히는 효과
    private var dimmedMaskLayer: CAShapeLayer?

    /// 현재 스와이프 진행도 (0.0 ~ 1.0)
    private var currentSwipeProgress: CGFloat = 0

    /// 현재 스와이프 방향
    private var currentSwipeDirection: SwipeDirection = .right

    /// 스와이프 오버레이 색상 설정 (삭제: 마룬, 복구: 녹색)
    /// 스와이프 시작 시 호출하여 오버레이 색상을 전환
    func prepareSwipeOverlay(style: SwipeOverlayStyle) {
        swipeOverlayStyle = style
        dimmedOverlayView.backgroundColor = (style == .restore)
            ? Self.restoreOverlayColor
            : Self.defaultOverlayColor
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Lifecycle

    override func prepareForReuse() {
        super.prepareForReuse()

        // 회색 셀: 이미지 안 온 채 사라진 경우 → 무조건 카운트
        // - 마스킹 자극(이미지)이 없으므로 50ms 임계값 미적용
        // - 셀이 화면에서 사라질 때까지 회색이었으면 사용자가 인지한 것
        if wasShownAsGray {
            wasShownAsGray = false
            Self.incrementGrayShown()
            AnalyticsService.shared.countGrayShown()
        }

        // 이전 요청 취소 (오표시 방지)
        cancelCurrentRequest()

        // 새 API 요청 취소
        currentCancellable?.cancel()
        currentCancellable = nil

        // 캐시 로드 ID 초기화 (비동기 캐시 결과 무시)
        currentCacheLoadID = nil

        // 상태 초기화
        imageView.image = nil
        currentAssetID = nil
        isTrashed = false
        isSelectedForDeletion = false

        // UI 초기화
        dimmedOverlayView.frame = contentView.bounds
        dimmedOverlayView.isHidden = true
        dimmedOverlayView.alpha = 0
        dimmedOverlayView.backgroundColor = Self.defaultOverlayColor  // 녹색 잔존 방지
        swipeOverlayStyle = .delete

        // 스와이프 애니메이션 상태 초기화 (stale completion handler 방지)
        isAnimating = false
        reuseGeneration += 1
        dimmedMaskLayer?.removeFromSuperlayer()
        dimmedMaskLayer = nil
        dimmedOverlayView.layer.mask = nil

        trashIconView.isHidden = true
        selectionCheckmarkView.isHidden = true
        videoDurationLabel.isHidden = true
        videoIconView.isHidden = true
        videoGradientView.isHidden = true
        iCloudIconView.isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // 그라데이션 레이어 크기 업데이트
        gradientLayer?.frame = videoGradientView.bounds

        // 딤드 오버레이 frame 동기화 (스와이프 커튼 중이 아닐 때만)
        if dimmedMaskLayer == nil {
            dimmedOverlayView.frame = contentView.bounds
        }
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        // 이미지 뷰
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // 딤드 오버레이 (frame 기반 — Auto Layout 제거, CABackdropLayer 호환)
        contentView.addSubview(dimmedOverlayView)

        // 비디오 그라데이션 배경
        contentView.addSubview(videoGradientView)
        NSLayoutConstraint.activate([
            videoGradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            videoGradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            videoGradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            videoGradientView.heightAnchor.constraint(equalToConstant: 24)
        ])

        // 그라데이션 레이어 설정
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.5).cgColor
        ]
        gradient.locations = [0.0, 1.0]
        videoGradientView.layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient

        // 비디오 아이콘
        contentView.addSubview(videoIconView)
        NSLayoutConstraint.activate([
            videoIconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            videoIconView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            videoIconView.widthAnchor.constraint(equalToConstant: 12),
            videoIconView.heightAnchor.constraint(equalToConstant: 12)
        ])

        // 비디오 duration 라벨
        contentView.addSubview(videoDurationLabel)
        NSLayoutConstraint.activate([
            videoDurationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            videoDurationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])

        // 선택 체크마크
        contentView.addSubview(selectionCheckmarkView)
        NSLayoutConstraint.activate([
            selectionCheckmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            selectionCheckmarkView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            selectionCheckmarkView.widthAnchor.constraint(equalToConstant: 24),
            selectionCheckmarkView.heightAnchor.constraint(equalToConstant: 24)
        ])

        // 삭제대기함 아이콘 (우측 상단)
        contentView.addSubview(trashIconView)
        NSLayoutConstraint.activate([
            trashIconView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            trashIconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            trashIconView.widthAnchor.constraint(equalToConstant: 25),
            trashIconView.heightAnchor.constraint(equalToConstant: 25)
        ])

        // T073: iCloud 전용 사진 아이콘 (우측 상단)
        contentView.addSubview(iCloudIconView)
        NSLayoutConstraint.activate([
            iCloudIconView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            iCloudIconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            iCloudIconView.widthAnchor.constraint(equalToConstant: 16),
            iCloudIconView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    // MARK: - Configuration

    /// 빈 셀로 설정 (T027-2: 맨 위 행 빈 셀)
    /// 배경색과 동일하게 투명 처리
    func configureAsEmpty() {
        cancelCurrentRequest()
        currentAssetID = nil
        imageView.image = nil
        imageView.backgroundColor = .clear
        dimmedOverlayView.isHidden = true
        trashIconView.isHidden = true
        selectionCheckmarkView.isHidden = true
        videoDurationLabel.isHidden = true
        videoIconView.isHidden = true
        iCloudIconView.isHidden = true
    }

    /// 셀 설정 (PHAsset 직접 전달 - v6 최적화)
    /// - 디스크 캐시 우선 확인 → 캐시 미스 시 ImagePipeline 요청
    /// - targetSize는 point 단위 (내부에서 픽셀로 변환)
    /// - Parameters:
    ///   - asset: 표시할 PHAsset
    ///   - isTrashed: 삭제대기함 상태
    ///   - targetSize: 썸네일 목표 크기 (point 단위)
    ///   - isFullSizeRequest: 100% 크기 요청 여부 (디스크 캐시 저장 조건)
    func configure(
        asset: PHAsset,
        isTrashed: Bool,
        targetSize: CGSize,
        isFullSizeRequest: Bool = true
    ) {
        let assetID = asset.localIdentifier
        let modDate = asset.modificationDate

        // 동일한 에셋이면 무시
        guard currentAssetID != assetID else { return }

        // 이전 요청 취소
        cancelCurrentRequest()
        currentCancellable?.cancel()
        currentCancellable = nil
        currentCacheLoadID = nil

        // 새 에셋 ID 및 크기 설정
        currentAssetID = assetID
        currentTargetSize = targetSize
        self.isTrashed = isTrashed

        // 빈 셀에서 복원 시 배경색 복구
        imageView.backgroundColor = .systemGray6

        // 딤드 오버레이 업데이트 (T027)
        updateDimmedOverlay()

        // 미디어 타입 변환
        let mediaType: MediaType
        switch asset.mediaType {
        case .video:
            mediaType = .video
        case .image:
            if asset.mediaSubtypes.contains(.photoLive) {
                mediaType = .livePhoto
            } else {
                mediaType = .photo
            }
        default:
            mediaType = .photo
        }

        // 비디오 배지 업데이트 (T067)
        let duration: TimeInterval? = mediaType == .video ? asset.duration : nil
        updateVideoBadge(mediaType: mediaType, duration: duration)

        // T073: iCloud 전용 사진 아이콘 업데이트
        updateiCloudBadge(asset: asset)

        // targetSize는 이미 픽셀 단위 (thumbnailSize()가 pt × scale 반환)
        // 여기서 다시 scale을 곱하면 이중 곱셈 버그 발생
        let pixelSize = targetSize

        // B+A v2: 0) 메모리 캐시에서 동기 로드 (즉시 반환)
        // - 프리로드된 이미지가 있으면 셀 생성과 동시에 이미지 할당
        if let memoryImage = MemoryThumbnailCache.shared.get(assetID: assetID, pixelSize: pixelSize) {
            let wasNil = imageView.image == nil
            imageView.image = memoryImage
            if wasNil { Self.incrementGrayResolved() }  // nil → non-nil 전환 시에만

            return // 메모리 캐시 히트 → 완료
        }

        // [설계 정책] 스크롤 중 디스크 캐시 스킵
        // - 디스크 캐시는 "초기 프리로드 전용" (GridViewController.startInitialPreload에서만 사용)
        // - 스크롤 중에는 메모리 → Pipeline 직접 연결 (디스크 I/O 지연으로 인한 회색 썸네일 방지)
        // - 근거: 2025-12-22 테스트, skipDiskCache=true → 회색 거의 사라짐 (test/251222test-v7-diskoff.md)
        // - Pipeline의 degraded first-paint가 디스크 로드보다 빠름
        //
        // 메모리 캐시 미스 시 바로 ImagePipeline 요청
        requestFromPipeline(asset: asset, pixelSize: pixelSize, modDate: modDate, isFullSizeRequest: isFullSizeRequest)

        // [Dead Code] 디스크 캐시 로드 경로 - 비활성화됨
        // 필요 시 위 requestFromPipeline 호출을 제거하고 #if false를 #if true로 변경
        #if false
        // 캐시 로드 ID 생성 (비동기 캐시 결과 검증용)
        let loadID = UUID()
        currentCacheLoadID = loadID

        // 1) 디스크 캐시에서 비동기 로드 (백그라운드 predecode)
        ThumbnailCache.shared.load(
            assetID: assetID,
            modificationDate: modDate,
            size: pixelSize
        ) { [weak self] cachedImage in
            // 메인 스레드에서 호출됨
            guard let self = self else { return }

            // 셀 재사용 또는 캐시 로드 ID 변경 체크
            guard self.currentAssetID == assetID,
                  self.currentCacheLoadID == loadID else {
                // [Stats] 디스크 캐시 콜백 버려짐 (스크롤 중 헛일)
                Self.mismatchLock.withLock { Self.diskCacheMismatchCount += 1 }
                return
            }

            if let cachedImage = cachedImage {
                // 캐시 히트 → 이미지 표시 후 종료
                self.imageView.image = cachedImage
                return
            }

            // 2) 캐시 미스 → ImagePipeline 요청
            self.requestFromPipeline(asset: asset, pixelSize: pixelSize, modDate: modDate, isFullSizeRequest: true)
        }
        #endif
    }

    /// ImagePipeline에서 이미지 요청 (캐시 미스 시 호출)
    /// - isFullSizeRequest: 100% 크기 요청 시 true (디스크 캐시 저장 조건)
    private func requestFromPipeline(asset: PHAsset, pixelSize: CGSize, modDate: Date?, isFullSizeRequest: Bool) {
        let assetID = asset.localIdentifier

        currentCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: pixelSize,
            contentMode: .aspectFill
        ) { [weak self] image, isDegraded in
            guard let self = self else { return }

            // 셀 재사용 체크
            guard self.currentAssetID == assetID else {
                // [Stats] Pipeline 콜백 버려짐 (스크롤 중 헛일)
                Self.mismatchLock.withLock { Self.pipelineMismatchCount += 1 }
                return
            }

            if let image = image {
                // 이미지 표시
                let wasNil = self.imageView.image == nil
                self.imageView.image = image
                if wasNil {
                    Self.incrementGrayResolved()
                    // 사용자가 회색을 본 뒤 이미지 도착 → 인지 임계값 초과 시 카운트
                    if self.wasShownAsGray {
                        self.wasShownAsGray = false
                        let elapsed = CACurrentMediaTime() - self.grayStartTime
                        if elapsed > Self.grayPerceptibleThreshold {
                            Self.incrementGrayShown()
                            AnalyticsService.shared.countGrayShown()
                        }
                    }
                }

                // degraded가 아닌 최종 이미지만 캐시에 저장
                // [Phase 1] 디스크 캐시 저장 조건:
                // 1. isDegraded=false (최종 이미지)
                // 2. isFullSizeRequest=true (스크롤 중 50%는 저장 안 함 - 정책 일치)
                // 3. 중복 저장 방지 (메모리 Set - 동기 디스크 I/O 없음)
                if !isDegraded && isFullSizeRequest {
                    let cacheKey = Self.makeCacheKey(assetID: assetID, modDate: modDate, size: pixelSize)

                    // 세션 내 중복 저장 방지 (메모리 Set 기반)
                    Self.savedCacheKeysLock.lock()
                    let alreadySaved = Self.hasSaved(key: cacheKey)
                    if !alreadySaved {
                        Self.markSaved(key: cacheKey)
                    }
                    Self.savedCacheKeysLock.unlock()

                    if !alreadySaved {
                        ThumbnailCache.shared.save(
                            image: image,
                            assetID: assetID,
                            modificationDate: modDate,
                            size: pixelSize
                        )
                    }
                }
            }
        }
    }

    /// 셀 설정 (assetID 기반 - 레거시 호환)
    /// - Note: 새 코드는 PHAsset 기반 configure(asset:...) 사용 권장
    /// - Parameters:
    ///   - assetID: 표시할 에셋 ID
    ///   - isTrashed: 삭제대기함 상태
    ///   - mediaType: 미디어 타입
    ///   - duration: 비디오 duration (초, 비디오인 경우만)
    ///   - targetSize: 썸네일 목표 크기
    func configure(
        assetID: String,
        isTrashed: Bool,
        mediaType: MediaType = .photo,
        duration: TimeInterval? = nil,
        targetSize: CGSize
    ) {
        // 동일한 에셋이면 무시
        guard currentAssetID != assetID else { return }

        // 이전 요청 취소
        cancelCurrentRequest()

        // 새 에셋 ID 및 크기 설정
        currentAssetID = assetID
        currentTargetSize = targetSize
        self.isTrashed = isTrashed

        // 딤드 오버레이 업데이트 (T027)
        updateDimmedOverlay()

        // 비디오 배지 업데이트 (T067)
        updateVideoBadge(mediaType: mediaType, duration: duration)

        // 이미지 요청 (레거시 API 사용)
        currentRequestToken = ImagePipeline.shared.requestImage(
            for: assetID,
            targetSize: targetSize,
            contentMode: .aspectFill
        ) { [weak self] image, token in
            guard let self = self else { return }

            // 토큰 검증 (오표시 방지)
            // 요청 후 셀이 재사용되었을 수 있으므로 assetID 확인
            guard self.currentAssetID == token.assetID,
                  !token.isCancelled else {
                return
            }

            // 이미지 설정
            let wasNil = self.imageView.image == nil
            self.imageView.image = image
            if wasNil {
                Self.incrementGrayResolved()
                if self.wasShownAsGray {
                    self.wasShownAsGray = false
                    let elapsed = CACurrentMediaTime() - self.grayStartTime
                    if elapsed > Self.grayPerceptibleThreshold {
                        Self.incrementGrayShown()
                        AnalyticsService.shared.countGrayShown()
                    }
                }
            }
        }
    }

    /// 삭제대기함 상태 업데이트
    /// - Parameter isTrashed: 새 삭제대기함 상태
    func updateTrashState(_ isTrashed: Bool) {
        self.isTrashed = isTrashed
        updateDimmedOverlay()
    }

    // MARK: - Private Methods

    /// 현재 요청 취소
    private func cancelCurrentRequest() {
        if let token = currentRequestToken {
            ImagePipeline.shared.cancelRequest(token)
            currentRequestToken = nil
        }
    }

    private func updateDimmedOverlay() {
        if isTrashed {
            dimmedOverlayView.isHidden = false
            dimmedOverlayView.alpha = Self.dimmedOverlayAlpha
            trashIconView.isHidden = false
        } else {
            dimmedOverlayView.isHidden = true
            dimmedOverlayView.alpha = 0
            trashIconView.isHidden = true
        }
    }

    /// 선택 UI 업데이트 (T039)
    private func updateSelectionUI() {
        selectionCheckmarkView.isHidden = !isSelectedForDeletion
        updateTransform()
    }

    /// 축소 transform 업데이트 (터치 하이라이트 또는 선택 시 0.95배 축소)
    /// - isHighlighted: 터치 다운 즉시 true, 떼면 false (시스템 관리)
    /// - isSelectedForDeletion: 선택 모드에서 선택된 셀 (앱 관리)
    /// - 둘 중 하나라도 true면 축소 유지
    private func updateTransform() {
        let shouldShrink = isHighlighted || isSelectedForDeletion
        UIView.animate(withDuration: 0.1) {
            self.transform = shouldShrink
                ? CGAffineTransform(scaleX: 0.95, y: 0.95)
                : .identity
        }
    }

    /// 비디오 배지 업데이트 (T067)
    private func updateVideoBadge(mediaType: MediaType, duration: TimeInterval?) {
        let isVideo = mediaType == .video

        videoGradientView.isHidden = !isVideo
        videoIconView.isHidden = !isVideo
        videoDurationLabel.isHidden = !isVideo

        if isVideo, let duration = duration {
            videoDurationLabel.text = formatDuration(duration)
        }
    }

    /// duration 포맷팅
    /// - Parameter duration: 초 단위 duration
    /// - Returns: "m:ss" 또는 "h:mm:ss" 형식 문자열
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// T073: iCloud 전용 사진 배지 업데이트
    /// sourceType이 .typeCloudShared 또는 .typeiTunesSynced가 아니면서
    /// 로컬에 원본이 없는 경우 iCloud 아이콘 표시
    /// - Parameter asset: 확인할 PHAsset
    private func updateiCloudBadge(asset: PHAsset) {
        // PHAsset의 sourceType으로 iCloud 전용 여부 확인
        // sourceType은 옵션 세트이므로 로컬 소스가 없는지 확인
        // .typeUserLibrary가 없으면 iCloud에만 있는 것으로 간주
        let isLocallyAvailable = asset.sourceType.contains(.typeUserLibrary)
        let isiCloudOnly = !isLocallyAvailable

        iCloudIconView.isHidden = !isiCloudOnly
    }
}

// MARK: - Accessibility

extension PhotoCell {

    /// 접근성 설정 업데이트
    func updateAccessibility(index: Int, total: Int, isTrashed: Bool) {
        isAccessibilityElement = true
        accessibilityLabel = "사진 \(index + 1) / \(total)"

        if isTrashed {
            accessibilityLabel? += ", 삭제대기함에 있음"
        }

        accessibilityTraits = [.image]

        if isSelectedForDeletion {
            accessibilityTraits.insert(.selected)
        }
    }
}

// MARK: - PRD7: Swipe Delete Animation

extension PhotoCell {

    /// 스와이프 진행도에 따른 딤드 업데이트
    /// - Parameters:
    ///   - progress: 스와이프 진행도 (0.0 ~ 1.0)
    ///   - direction: 스와이프 방향
    ///   - isTrashed: 현재 삭제대기함 상태 (삭제/복원 방향 결정)
    func setDimmedProgress(_ progress: CGFloat, direction: SwipeDirection, isTrashed: Bool) {
        currentSwipeProgress = max(0, min(1, progress))
        currentSwipeDirection = direction

        // 딤드 오버레이 표시
        dimmedOverlayView.isHidden = false
        dimmedOverlayView.alpha = Self.dimmedOverlayAlpha

        // frame 기반 커튼 업데이트 (mask 대신 — CABackdropLayer 호환)
        updateDimmedMask(progress: currentSwipeProgress, direction: direction, isTrashed: isTrashed)
    }

    /// 딤드 애니메이션 확정 (스와이프 성공)
    /// - Parameters:
    ///   - toTrashed: 최종 삭제대기함 상태
    ///   - completion: 완료 콜백
    func confirmDimmedAnimation(toTrashed: Bool, completion: @escaping () -> Void) {
        let gen = self.reuseGeneration

        // 나머지 영역 빠르게 채움/걷힘
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) { [weak self] in
            guard let self = self else { return }
            // 셀이 재사용되었으면 UI 변경 건너뜀
            guard self.reuseGeneration == gen else { return }

            if toTrashed {
                // 삭제 확정: 전체 딤드 (frame을 전체로 확장 + mask 제거)
                self.dimmedOverlayView.frame = self.contentView.bounds
                self.dimmedMaskLayer?.removeFromSuperlayer()
                self.dimmedMaskLayer = nil
                self.dimmedOverlayView.alpha = Self.dimmedOverlayAlpha
                // 유사사진 뱃지 즉시 숨김 (삭제된 셀에 테두리 잔류 방지)
                (self.contentView.subviews.first { $0 is SimilarGroupBadgeView } as? SimilarGroupBadgeView)?.stopAndHide()
            } else {
                // 복원 확정: 딤드 제거
                self.dimmedOverlayView.alpha = 0
                // 유사사진 뱃지 복원 (삭제 시 숨겼던 뱃지 다시 표시)
                (self.contentView.subviews.first { $0 is SimilarGroupBadgeView } as? SimilarGroupBadgeView)?.show()
            }
        } completion: { [weak self] _ in
            guard let self = self else { return }
            // 셀이 재사용되었으면 completion만 호출하고 스킵
            guard self.reuseGeneration == gen else { completion(); return }

            // 마스크 레이어 정리
            self.dimmedMaskLayer?.removeFromSuperlayer()
            self.dimmedMaskLayer = nil

            // 최종 상태 설정
            self.isTrashed = toTrashed
            self.dimmedOverlayView.isHidden = !toTrashed
            self.dimmedOverlayView.alpha = toTrashed ? Self.dimmedOverlayAlpha : 0
            // 복구 모드에서는 trashIcon 표시 안 함
            self.trashIconView.isHidden = self.swipeOverlayStyle == .restore ? true : !toTrashed

            // 오버레이 색상 리셋 (다음 스와이프를 위해)
            // 복구 모드에서는 셀이 곧 제거되므로 리셋 불필요 (마룬색 깜빡임 방지)
            if self.swipeOverlayStyle != .restore {
                self.dimmedOverlayView.backgroundColor = Self.defaultOverlayColor
                self.swipeOverlayStyle = .delete
            }

            completion()
        }
    }

    /// 딤드 애니메이션 취소 (스와이프 취소)
    /// - Parameter completion: 완료 콜백
    func cancelDimmedAnimation(completion: @escaping () -> Void) {
        let gen = self.reuseGeneration

        // 원래 상태로 복귀 (spring animation)
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: []
        ) { [weak self] in
            guard let self = self else { return }
            // 셀이 재사용되었으면 UI 변경 건너뜀
            guard self.reuseGeneration == gen else { return }

            if self.isTrashed {
                // 원래 삭제 상태: 전체 딤드로 복귀 (frame 확장 + alpha 복원)
                self.dimmedOverlayView.frame = self.contentView.bounds
                self.dimmedMaskLayer?.removeFromSuperlayer()
                self.dimmedMaskLayer = nil
                self.dimmedOverlayView.alpha = Self.dimmedOverlayAlpha
            } else {
                // 원래 정상 상태: 커튼이 걷히는 방향으로 frame 축소
                let bounds = self.contentView.bounds
                let zeroRect: CGRect
                switch self.currentSwipeDirection {
                case .right:
                    // 오른쪽 스와이프였으면 → 왼쪽으로 걷힘 (x=0, width→0)
                    zeroRect = CGRect(x: 0, y: 0, width: 0, height: bounds.height)
                case .left:
                    // 왼쪽 스와이프였으면 → 오른쪽으로 걷힘 (x=width, width→0)
                    zeroRect = CGRect(x: bounds.width, y: 0, width: 0, height: bounds.height)
                }
                self.dimmedOverlayView.frame = zeroRect
            }
        } completion: { [weak self] _ in
            guard let self = self else { return }
            // 셀이 재사용되었으면 completion만 호출하고 스킵
            guard self.reuseGeneration == gen else { completion(); return }

            // 마스크 레이어 정리
            self.dimmedMaskLayer?.removeFromSuperlayer()
            self.dimmedMaskLayer = nil

            // 원래 상태로 복원
            self.dimmedOverlayView.isHidden = !self.isTrashed
            self.dimmedOverlayView.alpha = self.isTrashed ? Self.dimmedOverlayAlpha : 0
            self.trashIconView.isHidden = !self.isTrashed

            // 오버레이 색상 리셋 (다음 스와이프를 위해)
            self.dimmedOverlayView.backgroundColor = Self.defaultOverlayColor
            self.swipeOverlayStyle = .delete

            completion()
        }
    }

    // MARK: - 다중 스와이프 삭제용 딤드

    /// 전체 딤드 즉시 적용 (마스크 없이, 다중 선택용)
    /// - 기존 dimmedOverlayView를 마스크 없이 표시
    /// - 기존 마스크가 있으면 제거
    /// - Parameter isTrashed: 현재 삭제대기함 상태 (예약, 현재 미사용)
    func setFullDimmed(isTrashed: Bool) {
        // 마스크 완전 제거 (커튼 효과 → 전체 딤드 전환)
        dimmedMaskLayer?.removeFromSuperlayer()
        dimmedMaskLayer = nil
        dimmedOverlayView.layer.mask = nil

        // frame 복원 (커튼 상태에서 전체로) + 전체 딤드 표시
        dimmedOverlayView.frame = contentView.bounds
        dimmedOverlayView.isHidden = false
        dimmedOverlayView.alpha = Self.dimmedOverlayAlpha
    }

    /// 딤드 즉시 해제 (다중 선택 범위 이탈 시)
    /// 원래 상태(isTrashed 기반)로 즉시 복귀
    func clearDimmed() {
        // 마스크 완전 제거 (잔여 아티팩트 방지)
        dimmedMaskLayer?.removeFromSuperlayer()
        dimmedMaskLayer = nil
        dimmedOverlayView.layer.mask = nil

        // frame 복원 + 원래 상태로 복귀
        dimmedOverlayView.frame = contentView.bounds
        dimmedOverlayView.isHidden = !isTrashed
        dimmedOverlayView.alpha = isTrashed ? Self.dimmedOverlayAlpha : 0
        trashIconView.isHidden = !isTrashed
    }

    /// 현재 딤드 오버레이가 활성 상태인지 확인 (reconciliation용)
    /// stale animation completion이 딤드를 덮어썼는지 판단
    var isDimmedActive: Bool {
        return !dimmedOverlayView.isHidden && dimmedOverlayView.alpha > 0.01
    }

    /// 복원 미리보기 (다중 스와이프 복원용)
    /// isTrashed 상태와 무관하게 빨간 딤드를 제거하여 "복원될 모습" 표시
    /// - Note: isTrashed 프로퍼티는 변경하지 않음 (취소 시 원래 상태로 복귀 가능)
    /// - Note: isHidden = false 유지 — cancel 시 alpha 애니메이션으로 복귀하기 위함
    func setRestoredPreview() {
        dimmedMaskLayer?.removeFromSuperlayer()
        dimmedMaskLayer = nil
        dimmedOverlayView.layer.mask = nil

        // frame 복원 + 복원 미리보기
        dimmedOverlayView.frame = contentView.bounds
        dimmedOverlayView.isHidden = false  // cancel 시 alpha 애니메이션 가능하게
        dimmedOverlayView.alpha = 0
        trashIconView.isHidden = true
    }

    // MARK: - 다중 모드 진입 전환 애니메이션

    /// 커튼을 현재 위치에서 대상 상태(100%)까지 부드럽게 전환
    /// 다중 모드 진입 시 앵커 셀의 커튼 점프를 방지
    ///
    /// - 삭제 모드 (isTrashed=false): 빨간색이 남은 영역을 부드럽게 채움
    /// - 복원 모드 (isTrashed=true): 빨간색이 남은 영역에서 부드럽게 걷힘
    ///
    /// - Parameters:
    ///   - direction: 스와이프 방향
    ///   - isTrashed: 셀의 현재 삭제대기함 상태 (마스크 방향 결정)
    func animateCurtainToTarget(direction: SwipeDirection, isTrashed: Bool) {
        let gen = self.reuseGeneration
        let bounds = contentView.bounds
        let width = bounds.width
        let height = bounds.height

        // 타겟 frame 계산 (updateDimmedMask의 progress=1.0과 동일)
        let targetFrame: CGRect
        if isTrashed {
            // 복원: overlay를 밀어냄 (width → 0)
            switch direction {
            case .right:
                targetFrame = CGRect(x: width, y: 0, width: 0, height: height)
            case .left:
                targetFrame = CGRect(x: 0, y: 0, width: 0, height: height)
            }
        } else {
            // 삭제: overlay를 전체로 확장
            targetFrame = bounds
        }

        // frame 애니메이션 (0.12초, mask path 애니메이션 대체)
        UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseOut) { [weak self] in
            guard let self = self else { return }
            guard self.reuseGeneration == gen else { return }
            self.dimmedOverlayView.frame = targetFrame
        } completion: { [weak self] _ in
            guard let self = self else { return }
            guard self.reuseGeneration == gen else { return }

            if isTrashed {
                // 복원 완료: 딤드 제거
                self.dimmedOverlayView.frame = self.contentView.bounds
                self.dimmedOverlayView.isHidden = false
                self.dimmedOverlayView.alpha = 0
                self.trashIconView.isHidden = true
            }
        }
    }

    // MARK: - Private Animation Helpers

    /// 딤드 마스크 레이어 초기화
    private func setupDimmedMaskLayer() {
        let mask = CAShapeLayer()
        mask.fillColor = UIColor.black.cgColor
        dimmedOverlayView.layer.mask = mask
        dimmedMaskLayer = mask
    }

    /// 딤드 마스크 업데이트 (스와이프 진행도에 따라)
    /// - Parameters:
    ///   - progress: 진행도 (0.0 ~ 1.0)
    ///   - direction: 스와이프 방향
    ///   - isTrashed: 현재 삭제대기함 상태
    private func updateDimmedMask(progress: CGFloat, direction: SwipeDirection, isTrashed: Bool) {
        // contentView.bounds 기준 (dimmedOverlayView.bounds는 frame 변경 시 같이 바뀌므로 부적합)
        let bounds = contentView.bounds
        let width = bounds.width
        let height = bounds.height

        // 스와이프 거리 계산
        let swipeWidth = width * progress

        let rect: CGRect
        if isTrashed {
            // 복원 중: 손가락이 빨간 딤드를 밀어냄
            // 딤드가 손가락 방향으로 밀려나는 느낌
            switch direction {
            case .right:
                // 오른쪽 스와이프 → 딤드가 오른쪽으로 밀려남 (왼쪽부터 사라짐)
                rect = CGRect(x: swipeWidth, y: 0, width: width - swipeWidth, height: height)
            case .left:
                // 왼쪽 스와이프 → 딤드가 왼쪽으로 밀려남 (오른쪽부터 사라짐)
                rect = CGRect(x: 0, y: 0, width: width - swipeWidth, height: height)
            }
        } else {
            // 삭제 중: 손가락 뒤에서 빨간 딤드가 따라옴
            switch direction {
            case .right:
                // 오른쪽 스와이프 → 딤드가 왼쪽에서 채워짐
                rect = CGRect(x: 0, y: 0, width: swipeWidth, height: height)
            case .left:
                // 왼쪽 스와이프 → 딤드가 오른쪽에서 채워짐
                rect = CGRect(x: width - swipeWidth, y: 0, width: swipeWidth, height: height)
            }
        }

        // frame 직접 변경 (position+bounds → CABackdropLayer가 dirty region 추적)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dimmedOverlayView.frame = rect
        CATransaction.commit()
    }

    // MARK: - 고해상도 재요청 (R2 업그레이드)

    /// 고해상도 업그레이드가 필요한 경우 이미지 재요청
    /// - 핀치줌으로 셀이 커졌을 때
    /// - 스크롤 정지 후 R2 업그레이드 시
    /// - Parameters:
    ///   - asset: 대상 에셋
    ///   - targetSize: 목표 크기
    /// - Returns: 실제로 업그레이드 요청을 했으면 true, 스킵했으면 false
    /// - Note: 같은 assetID여도 targetSize가 커지면 재요청
    @discardableResult
    func refreshImageIfNeeded(asset: PHAsset, targetSize: CGSize) -> Bool {
        let assetID = asset.localIdentifier

        // 다른 에셋이면 configure 호출 (일반적인 경우 아님)
        guard currentAssetID == assetID else {
            configure(
                asset: asset,
                isTrashed: isTrashed,
                targetSize: targetSize
            )
            return true  // configure 호출함
        }

        // targetSize가 커졌을 때만 재요청 (축소 시에는 기존 이미지 사용)
        let needsHigherRes = targetSize.width > currentTargetSize.width ||
                             targetSize.height > currentTargetSize.height
        guard needsHigherRes else { return false }  // 이미 충분한 해상도

        // 크기 업데이트
        currentTargetSize = targetSize

        // 고해상도 이미지 요청 (ImagePipeline 사용)
        currentCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill
        ) { [weak self] image, isDegraded in
            guard let self = self else { return }

            // 셀이 재사용되었으면 무시
            guard self.currentAssetID == assetID else { return }

            // [R2] 고해상도 업그레이드 시에는 final만 적용
            // - degraded를 적용하면 기존 이미지(50%)보다 품질이 떨어질 수 있음
            // - final만 적용하면 50% → 100%로 부드럽게 전환
            // [Phase 1] CrossFade: 50% → 100% 전환이 눈에 띄지 않도록
            if let image = image, !isDegraded {
                // 이미 이미지가 있고, 화면에 보이는 경우에만 CrossFade
                if self.imageView.image != nil && self.imageView.window != nil {
                    UIView.transition(
                        with: self.imageView,
                        duration: 0.15,
                        options: .transitionCrossDissolve,
                        animations: {
                            self.imageView.image = image
                        },
                        completion: nil
                    )
                } else {
                    self.imageView.image = image
                }
            }
            // degraded 무시, 실패 시 기존 이미지 유지
        }
        return true  // 업그레이드 요청함
    }
}
