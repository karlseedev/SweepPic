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

    /// 딤드 오버레이 투명도 (FR-008: 65% opacity)
    private static let dimmedOverlayAlpha: CGFloat = 0.65

    // MARK: - Debug Timing (static)

    /// [DEBUG] requestImage 호출 횟수
    static var requestImageCount: Int = 0
    /// [DEBUG] requestImage 호출 누적 시간
    static var requestImageTotalTime: Double = 0

    /// [DEBUG] imageApply 호출 횟수
    static var imageApplyCount: Int = 0
    /// [DEBUG] imageApply 누적 시간
    static var imageApplyTotalTime: Double = 0

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

    /// 딤드 오버레이 뷰 (휴지통 사진용)
    private let dimmedOverlayView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
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

    // MARK: - Properties

    /// 현재 이미지 요청 토큰
    private var currentRequestToken: RequestToken?

    /// 현재 표시 중인 에셋 ID
    private(set) var currentAssetID: String?

    /// 휴지통 상태
    private(set) var isTrashed: Bool = false

    /// 선택 상태 (T039에서 사용)
    var isSelectedForDeletion: Bool = false {
        didSet {
            updateSelectionUI()
        }
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

        // 이전 요청 취소 (오표시 방지)
        cancelCurrentRequest()

        // 상태 초기화
        imageView.image = nil
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
    }

    /// 셀 설정 (PHAsset 직접 전달 - 성능 최적화)
    /// - Parameters:
    ///   - asset: 표시할 PHAsset
    ///   - isTrashed: 휴지통 상태
    ///   - targetSize: 썸네일 목표 크기
    func configure(
        asset: PHAsset,
        isTrashed: Bool,
        targetSize: CGSize
    ) {
        let assetID = asset.localIdentifier

        // 동일한 에셋이면 무시
        guard currentAssetID != assetID else { return }

        // 이전 요청 취소
        cancelCurrentRequest()

        // 새 에셋 ID 설정
        currentAssetID = assetID
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

        // [DEBUG] A) requestImage 호출 전후 시간 측정
        let reqStart = CACurrentMediaTime()

        // 이미지 요청 (PHAsset 직접 전달 - 성능 최적화)
        currentRequestToken = ImagePipeline.shared.requestImage(
            for: asset,
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

            // [DEBUG] B) 이미지 적용 시간 측정
            let applyStart = CACurrentMediaTime()

            // 이미지 설정
            self.imageView.image = image

            let applyEnd = CACurrentMediaTime()
            let applyMs = (applyEnd - applyStart) * 1000

            // 누적 카운트 (static으로 공유)
            PhotoCell.imageApplyCount += 1
            PhotoCell.imageApplyTotalTime += applyMs

            // 매 10번째에 로그
            if PhotoCell.imageApplyCount % 10 == 0 {
                print("[Timing] imageApply 누적: \(PhotoCell.imageApplyCount)회, 총 \(String(format: "%.1f", PhotoCell.imageApplyTotalTime))ms, 평균 \(String(format: "%.2f", PhotoCell.imageApplyTotalTime / Double(PhotoCell.imageApplyCount)))ms")
            }
        }

        // [DEBUG] A) requestImage 호출 완료 시점
        let reqEnd = CACurrentMediaTime()
        let reqMs = (reqEnd - reqStart) * 1000

        // 누적 카운트
        PhotoCell.requestImageCount += 1
        PhotoCell.requestImageTotalTime += reqMs

        // 매 10번째에 로그
        if PhotoCell.requestImageCount % 10 == 0 {
            print("[Timing] requestImage 호출 누적: \(PhotoCell.requestImageCount)회, 총 \(String(format: "%.1f", PhotoCell.requestImageTotalTime))ms, 평균 \(String(format: "%.2f", PhotoCell.requestImageTotalTime / Double(PhotoCell.requestImageCount)))ms")
        }
    }

    /// 셀 설정 (assetID 기반 - 레거시 호환)
    /// - Parameters:
    ///   - assetID: 표시할 에셋 ID
    ///   - isTrashed: 휴지통 상태
    ///   - mediaType: 미디어 타입
    ///   - duration: 비디오 duration (초, 비디오인 경우만)
    ///   - targetSize: 썸네일 목표 크기
    ///   - imagePipeline: 이미지 파이프라인
    func configure(
        assetID: String,
        isTrashed: Bool,
        mediaType: MediaType = .photo,
        duration: TimeInterval? = nil,
        targetSize: CGSize,
        imagePipeline: ImagePipelineProtocol = ImagePipeline.shared
    ) {
        // 동일한 에셋이면 무시
        guard currentAssetID != assetID else { return }

        // 이전 요청 취소
        cancelCurrentRequest()

        // 새 에셋 ID 설정
        currentAssetID = assetID
        self.isTrashed = isTrashed

        // 딤드 오버레이 업데이트 (T027)
        updateDimmedOverlay()

        // 비디오 배지 업데이트 (T067)
        updateVideoBadge(mediaType: mediaType, duration: duration)

        // 이미지 요청
        currentRequestToken = imagePipeline.requestImage(
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
            self.imageView.image = image
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

    /// 딤드 오버레이 업데이트 (T027)
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
