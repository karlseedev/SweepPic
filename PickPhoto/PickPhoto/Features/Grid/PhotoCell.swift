// PhotoCell.swift
// 사진 그리드 셀
//
// T021: PhotoCell 생성
// - 이미지 표시
// - 딤드 오버레이 50% opacity (FR-008)
// - 재사용 로직: 이전 요청 취소 + 토큰 검증
//
// T027: 휴지통 사진 딤드 표시 구현
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

    // MARK: - Debug Timing (static)

    /// [DEBUG] requestImage 호출 횟수
    static var requestImageCount: Int = 0
    /// [DEBUG] requestImage 호출 누적 시간
    static var requestImageTotalTime: Double = 0

    /// [DEBUG] imageApply 호출 횟수
    static var imageApplyCount: Int = 0
    /// [DEBUG] imageApply 누적 시간
    static var imageApplyTotalTime: Double = 0

    #if DEBUG
    /// 첫 번째 이미지 할당 여부 (T_firstThumbnailVisible 측정용)
    private static var hasLoggedFirstThumbnail = false
    /// 이미지 할당 카운터 (visible count 측정용)
    private static var imageApplyCounter: Int = 0
    /// 캐시 히트로 할당된 카운터
    private static var cacheHitApplyCounter: Int = 0
    /// 카운터 락
    private static let applyLock = NSLock()

    /// 카운터 리셋 (앱 시작 시 호출)
    static func resetApplyCounters() {
        applyLock.withLock {
            hasLoggedFirstThumbnail = false
            imageApplyCounter = 0
            cacheHitApplyCounter = 0
        }
    }
    #endif

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
        let diskMismatch = diskCacheMismatchCount
        let pipelineMismatch = pipelineMismatchCount
        mismatchLock.unlock()

        FileLogger.log("[\(label)] diskCacheMismatch: \(diskMismatch), pipelineMismatch: \(pipelineMismatch)")
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

    /// 회색 셀 표시 카운트 증가 (willDisplay에서 호출)
    static func incrementGrayShown() {
        grayCellLock.withLock {
            grayShownCount += 1
        }
    }

    /// 현재 이미지가 nil인지 확인 (willDisplay에서 회색 셀 체크용)
    var isShowingGray: Bool {
        return imageView.image == nil
    }

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
        let stats = getGrayCellStats()
        let pending = stats.shown - stats.resolved
        FileLogger.log("[\(label)] grayShown: \(stats.shown), grayResolved: \(stats.resolved), pending: \(pending)")
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

    /// 딤드 오버레이 뷰 (휴지통 사진용) - 마룬 50%
    private let dimmedOverlayView: UIView = {
        let view = UIView()
        // Maroon (#800000)
        view.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        view.alpha = 0
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
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

    /// 휴지통 상태
    private(set) var isTrashed: Bool = false

    /// 선택 상태 (T039에서 사용)
    var isSelectedForDeletion: Bool = false {
        didSet {
            updateSelectionUI()
        }
    }

    // MARK: - PRD7: Swipe Delete Animation Properties

    /// 스와이프 방향
    enum SwipeDirection {
        case left
        case right
    }

    /// 셀별 애니메이션 잠금 (PRD7: 연속 토글 방지)
    /// 애니메이션 중인 셀에는 추가 제스처를 무시
    var isAnimating: Bool = false

    /// 딤드 마스크 레이어 (커튼 효과용)
    /// 스와이프 진행도에 따라 빨간 딤드가 채워지거나 걷히는 효과
    private var dimmedMaskLayer: CAShapeLayer?

    /// 현재 스와이프 진행도 (0.0 ~ 1.0)
    private var currentSwipeProgress: CGFloat = 0

    /// 현재 스와이프 방향
    private var currentSwipeDirection: SwipeDirection = .right

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

        // 이전 요청 취소 (오표시 방지)
        cancelCurrentRequest()

        // 새 API 요청 취소
        currentCancellable?.cancel()
        currentCancellable = nil

        // 캐시 로드 ID 초기화 (비동기 캐시 결과 무시)
        currentCacheLoadID = nil

        // 상태 초기화
        imageView.image = nil
        // 회색 셀 카운트는 willDisplay에서 측정 (화면에 실제 노출될 때만)
        currentAssetID = nil
        isTrashed = false
        isSelectedForDeletion = false

        // UI 초기화
        dimmedOverlayView.isHidden = true
        dimmedOverlayView.alpha = 0
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

        // 딤드 오버레이
        contentView.addSubview(dimmedOverlayView)
        NSLayoutConstraint.activate([
            dimmedOverlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            dimmedOverlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dimmedOverlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dimmedOverlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

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
    ///   - isTrashed: 휴지통 상태
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

        // 스크롤 중 로그 비활성화 - hitch 방지
        // 원복: git checkout a5414d4 -- PickPhoto/PickPhoto/Features/Grid/PhotoCell.swift
        #if false  // DEBUG 로그 임시 비활성화
        // 검증 로그: PhotoCell에서 조회하는 pixelSize (1회만)
        if Self.imageApplyCounter == 0 {
            FileLogger.log("[PhotoCell] 메모리 캐시 조회 pixelSize: \(Int(pixelSize.width))x\(Int(pixelSize.height))px")
        }
        #endif

        // B+A v2: 0) 메모리 캐시에서 동기 로드 (즉시 반환)
        // - 프리로드된 이미지가 있으면 셀 생성과 동시에 이미지 할당
        if let memoryImage = MemoryThumbnailCache.shared.get(assetID: assetID, pixelSize: pixelSize) {
            let wasNil = imageView.image == nil
            imageView.image = memoryImage
            if wasNil { Self.incrementGrayResolved() }  // nil → non-nil 전환 시에만

            #if false  // DEBUG 로그 임시 비활성화
            Self.applyLock.withLock {
                Self.imageApplyCounter += 1
                Self.cacheHitApplyCounter += 1

                // 첫 번째 이미지 할당 시 T_firstThumbnailVisible 로그
                if !Self.hasLoggedFirstThumbnail {
                    Self.hasLoggedFirstThumbnail = true
                    FileLogger.log("[PhotoCell] T_firstThumbnailVisible: 첫 이미지 할당 (메모리 캐시 히트)")
                }
            }
            #endif
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
                if wasNil { Self.incrementGrayResolved() }  // nil → non-nil 전환 시에만

                #if false  // DEBUG 로그 임시 비활성화
                Self.applyLock.withLock {
                    Self.imageApplyCounter += 1
                    // Pipeline에서 받은 건 캐시 미스
                    let count = Self.imageApplyCounter

                    // 첫 번째 이미지 할당 시 T_firstThumbnailVisible 로그
                    if !Self.hasLoggedFirstThumbnail {
                        Self.hasLoggedFirstThumbnail = true
                        FileLogger.log("[PhotoCell] T_firstThumbnailVisible: 첫 이미지 할당 (Pipeline, isDegraded=\(isDegraded))")
                    }

                    // 20개마다 visible/hit 비율 로그
                    if count == 20 || count == 50 {
                        let hitRate = Double(Self.cacheHitApplyCounter) / Double(count) * 100
                        FileLogger.log("[PhotoCell] 이미지 할당 #\(count): 캐시 히트율 \(String(format: "%.1f", hitRate))% (\(Self.cacheHitApplyCounter)/\(count))")
                    }
                }
                #endif

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
                        #if DEBUG
                        FileLogger.log("[DiskSave] \(assetID.prefix(8))... final saved")
                        #endif
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
    ///   - isTrashed: 휴지통 상태
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
            if wasNil { Self.incrementGrayResolved() }  // nil → non-nil 전환 시에만
        }
    }

    /// 휴지통 상태 업데이트
    /// - Parameter isTrashed: 새 휴지통 상태
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
        } else {
            dimmedOverlayView.isHidden = true
            dimmedOverlayView.alpha = 0
        }
    }

    /// 선택 UI 업데이트 (T039)
    private func updateSelectionUI() {
        selectionCheckmarkView.isHidden = !isSelectedForDeletion

        // 선택 시 살짝 축소 효과 (iOS 사진 앱 스타일)
        UIView.animate(withDuration: 0.15) {
            self.transform = self.isSelectedForDeletion
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
            accessibilityLabel? += ", 휴지통에 있음"
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
    ///   - isTrashed: 현재 휴지통 상태 (삭제/복원 방향 결정)
    func setDimmedProgress(_ progress: CGFloat, direction: SwipeDirection, isTrashed: Bool) {
        currentSwipeProgress = max(0, min(1, progress))
        currentSwipeDirection = direction

        // 마스크 레이어 초기화 (최초 호출 시)
        if dimmedMaskLayer == nil {
            setupDimmedMaskLayer()
        }

        // 딤드 오버레이 표시
        dimmedOverlayView.isHidden = false
        dimmedOverlayView.alpha = Self.dimmedOverlayAlpha

        // 마스크 업데이트
        updateDimmedMask(progress: currentSwipeProgress, direction: direction, isTrashed: isTrashed)
    }

    /// 딤드 애니메이션 확정 (스와이프 성공)
    /// - Parameters:
    ///   - toTrashed: 최종 휴지통 상태
    ///   - completion: 완료 콜백
    func confirmDimmedAnimation(toTrashed: Bool, completion: @escaping () -> Void) {
        // 나머지 영역 빠르게 채움/걷힘
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) { [weak self] in
            guard let self = self else { return }

            if toTrashed {
                // 삭제 확정: 전체 딤드
                self.dimmedMaskLayer?.removeFromSuperlayer()
                self.dimmedMaskLayer = nil
                self.dimmedOverlayView.alpha = Self.dimmedOverlayAlpha
            } else {
                // 복원 확정: 딤드 제거
                self.dimmedOverlayView.alpha = 0
            }
        } completion: { [weak self] _ in
            guard let self = self else { return }

            // 마스크 레이어 정리
            self.dimmedMaskLayer?.removeFromSuperlayer()
            self.dimmedMaskLayer = nil

            // 최종 상태 설정
            self.isTrashed = toTrashed
            self.dimmedOverlayView.isHidden = !toTrashed
            self.dimmedOverlayView.alpha = toTrashed ? Self.dimmedOverlayAlpha : 0

            completion()
        }
    }

    /// 딤드 애니메이션 취소 (스와이프 취소)
    /// - Parameter completion: 완료 콜백
    func cancelDimmedAnimation(completion: @escaping () -> Void) {
        // 원래 상태로 복귀 (spring animation)
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: []
        ) { [weak self] in
            guard let self = self else { return }

            if self.isTrashed {
                // 원래 삭제 상태: 전체 딤드로 복귀
                self.dimmedMaskLayer?.removeFromSuperlayer()
                self.dimmedMaskLayer = nil
                self.dimmedOverlayView.alpha = Self.dimmedOverlayAlpha
            } else {
                // 원래 정상 상태: 딤드 제거
                self.dimmedOverlayView.alpha = 0
            }
        } completion: { [weak self] _ in
            guard let self = self else { return }

            // 마스크 레이어 정리
            self.dimmedMaskLayer?.removeFromSuperlayer()
            self.dimmedMaskLayer = nil

            // 원래 상태로 복원
            self.dimmedOverlayView.isHidden = !self.isTrashed
            self.dimmedOverlayView.alpha = self.isTrashed ? Self.dimmedOverlayAlpha : 0

            completion()
        }
    }

    /// 투 핑거 탭용 페이드 애니메이션
    /// - Parameters:
    ///   - toTrashed: 최종 휴지통 상태
    ///   - completion: 완료 콜백
    func fadeDimmed(toTrashed: Bool, completion: (() -> Void)? = nil) {
        dimmedOverlayView.isHidden = false

        UIView.animate(withDuration: 0.15) { [weak self] in
            guard let self = self else { return }
            self.dimmedOverlayView.alpha = toTrashed ? Self.dimmedOverlayAlpha : 0
        } completion: { [weak self] _ in
            guard let self = self else { return }

            self.isTrashed = toTrashed
            if !toTrashed {
                self.dimmedOverlayView.isHidden = true
            }

            completion?()
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
    ///   - isTrashed: 현재 휴지통 상태
    private func updateDimmedMask(progress: CGFloat, direction: SwipeDirection, isTrashed: Bool) {
        guard let mask = dimmedMaskLayer else { return }

        let bounds = dimmedOverlayView.bounds
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

        // 마스크 적용 (애니메이션 없이 즉시)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.path = UIBezierPath(rect: rect).cgPath
        CATransaction.commit()
    }

    // MARK: - Pinch Zoom 후 고해상도 재요청

    /// 핀치줌으로 셀이 커졌을 때 고해상도 썸네일 재요청
    /// - Parameters:
    ///   - asset: PHAsset
    ///   - targetSize: 새로운 타겟 크기
    /// - Note: 같은 assetID여도 targetSize가 커지면 재요청
    func refreshImageIfNeeded(asset: PHAsset, targetSize: CGSize) {
        let assetID = asset.localIdentifier

        // 다른 에셋이면 configure 호출 (일반적인 경우 아님)
        guard currentAssetID == assetID else {
            configure(
                asset: asset,
                isTrashed: isTrashed,
                targetSize: targetSize
            )
            return
        }

        // targetSize가 커졌을 때만 재요청 (축소 시에는 기존 이미지 사용)
        let needsHigherRes = targetSize.width > currentTargetSize.width ||
                             targetSize.height > currentTargetSize.height
        guard needsHigherRes else { return }

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

            if let image = image {
                self.imageView.image = image
            }
            // 실패 시 기존 이미지 유지
        }
    }
}
