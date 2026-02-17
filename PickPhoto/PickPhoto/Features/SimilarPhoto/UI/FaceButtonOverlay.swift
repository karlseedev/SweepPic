//
//  FaceButtonOverlay.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  뷰어에서 감지된 얼굴 위에 +버튼을 표시하는 오버레이 뷰입니다.
//  유효 슬롯(2장 이상 감지된 인물)의 얼굴에만 +버튼을 표시합니다.
//
//  +버튼 위치 규칙:
//  - 기본 위치: 얼굴 위 중앙
//  - 겹침 방지: 좌 → 우 → 아래 → 위 순서로 이동 시도
//  - 버튼 간 최소 거리: 버튼 지름 × 1.2
//  - 4회 실패 시 현재 위치 유지
//
//  성능 요구사항:
//  - 캐시 hit 시 100ms 이내 +버튼 표시
//  - 캐시 miss 시 분석 완료 후 0.5초 이내 +버튼 표시
//

import UIKit
import AppCore

/// +버튼 탭 이벤트 델리게이트
protocol FaceButtonOverlayDelegate: AnyObject {
    /// +버튼이 탭되었을 때 호출
    /// - Parameters:
    ///   - overlay: 오버레이 인스턴스
    ///   - personIndex: 탭된 얼굴의 인물 번호
    ///   - face: 탭된 얼굴 정보
    func faceButtonOverlay(_ overlay: FaceButtonOverlay, didTapFaceAtPersonIndex personIndex: Int, face: CachedFace)

    /// 눈 버튼으로 오버레이 표시/숨김이 토글되었을 때 호출
    /// - Parameters:
    ///   - overlay: 오버레이 인스턴스
    ///   - isHidden: true면 오버레이 숨김 상태 (눈 슬래시)
    func faceButtonOverlay(_ overlay: FaceButtonOverlay, didToggleVisibility isHidden: Bool)
}

/// FaceButtonOverlayDelegate 기본 구현
extension FaceButtonOverlayDelegate {
    func faceButtonOverlay(_ overlay: FaceButtonOverlay, didToggleVisibility isHidden: Bool) {}
}

/// 뷰어에서 얼굴 위에 +버튼을 표시하는 오버레이 뷰
///
/// 유사 사진 그룹에 속한 사진을 뷰어에서 볼 때,
/// 감지된 얼굴 위에 +버튼을 표시하여 얼굴 비교 화면으로 진입할 수 있게 합니다.
final class FaceButtonOverlay: UIView {

    // MARK: - Constants

    /// UI 관련 상수
    private enum Constants {
        /// 버튼 크기 (지름) - FaceButton 커스텀 크기
        static let buttonDiameter: CGFloat = 34

        /// 버튼 반지름
        static let buttonRadius: CGFloat = buttonDiameter / 2

        /// 버튼 간 최소 거리 (버튼 지름 × 1.2)
        static let minimumButtonSpacing: CGFloat = buttonDiameter * 1.2

        /// 겹침 방지 이동 거리
        static let collisionOffset: CGFloat = buttonDiameter * 1.2

        /// 최대 겹침 방지 시도 횟수
        static let maxCollisionAttempts: Int = 4

        /// 최대 버튼 개수
        static let maxButtons: Int = 5

        /// 버튼 애니메이션 시간
        static let animationDuration: TimeInterval = 0.2
    }

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: FaceButtonOverlayDelegate?


    /// 햅틱 피드백 생성기 (재사용하여 XPC 연결 유지)
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    /// 현재 표시 중인 +버튼들
    private var faceButtons: [FaceButton] = []

    /// 현재 표시 중인 얼굴 정보
    private var currentFaces: [CachedFace] = []

    /// 현재 사진 assetID (디버그용)
    private var currentAssetID: String = ""

    /// 현재 이미지 크기 (좌표 변환용)
    private var currentImageSize: CGSize = .zero

    /// 토글 상태 (eye/eye.slash)
    private var isOverlayHidden: Bool = false

    /// 마지막 줌 정보 (토글 시 위치 복원용)
    /// zoomScale, contentOffset, imageViewFrame 저장
    private var lastZoomInfo: (zoomScale: CGFloat, contentOffset: CGPoint, imageViewFrame: CGRect)?

    /// 토글 버튼 - GlassCircleButton (Liquid Glass 스타일)
    /// iOS 16~25 전용: 뷰어 우상단에 eye/eye.slash 아이콘 토글
    /// 뒤로가기 버튼과 동일 크기 (44×44)
    private lazy var toggleButton: GlassCircleButton = {
        let button = GlassCircleButton(icon: "eye.fill", size: .medium, tintColor: .white)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(toggleButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 사진 번호 라벨 (유사 그룹 내 순서 표시)
    /// "3 / 8" 형식으로 현재 사진의 그룹 내 위치를 표시합니다.
    private lazy var photoNumberLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    /// UI 초기 설정
    private func setupUI() {
        // 오버레이는 터치 이벤트를 통과시킴 (버튼 영역만 터치 가능)
        isUserInteractionEnabled = true
        backgroundColor = .clear

        // iOS 26+: 네비게이션 바에 토글 버튼을 배치하므로 자체 버튼 생성 안 함
        if #available(iOS 26.0, *) {
            // 토글 버튼 생성하지 않음
        } else {
            // iOS 16~25: 토글 버튼 추가 (화면 우측 상단, 뒤로가기 버튼과 같은 높이/여백)
            let _ = toggleButton  // lazy 초기화 트리거 (GlassCircleButton 생성)
            addSubview(toggleButton)
            NSLayoutConstraint.activate([
                toggleButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
                toggleButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16)
            ])

            // 토글 버튼은 초기에는 숨김 (버튼이 있을 때만 표시)
            toggleButton.isHidden = true
        }

        // 사진 번호 라벨 추가 — 중앙 타이틀 바로 아래에 배치
        // 타이틀 centerY = safeArea+38, 폰트 17pt → bottom ≈ safeArea+48
        // photoNumberLabel top = safeArea+52 (타이틀과 4pt 간격)
        addSubview(photoNumberLabel)
        NSLayoutConstraint.activate([
            photoNumberLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 52),
            photoNumberLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            photoNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            photoNumberLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    // MARK: - Public Methods

    /// 현재 오버레이 숨김 상태 (iOS 26 네비게이션 바 아이콘 동기화용)
    var isCurrentlyHidden: Bool {
        return isOverlayHidden
    }

    /// 버튼이 현재 표시 중인지 여부 (viewDidAppear 중복 호출 방지용)
    var hasVisibleButtons: Bool {
        return !faceButtons.isEmpty
    }

    /// 첫 번째 표시 중인 + 버튼의 얼굴 정보 (코치마크 C-2 자동 탭용)
    var firstVisibleFace: CachedFace? {
        faceButtons.first?.face
    }

    /// 첫 번째 표시 중인 + 버튼의 윈도우 좌표 프레임 (코치마크 C-2 하이라이트용)
    func firstButtonFrameInWindow() -> CGRect? {
        guard let button = faceButtons.first else { return nil }
        return convert(button.frame, to: nil)
    }

    /// 외부에서 토글 기능 호출 (iOS 26 네비게이션 바 버튼용)
    func toggleOverlay() {
        toggleButtonTapped()
    }

    /// 사진 번호를 표시합니다.
    /// - Parameters:
    ///   - number: 그룹 내 순서 (1-based)
    ///   - total: 그룹 총 멤버 수
    func showPhotoNumber(_ number: Int, total: Int) {
        let regular = UIFont.systemFont(ofSize: 14, weight: .regular)
        let bold = UIFont.systemFont(ofSize: 14, weight: .bold)
        let white: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]

        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: "Pic ", attributes: white.merging([.font: regular]) { _, b in b }))
        attr.append(NSAttributedString(string: "\(number)", attributes: white.merging([.font: bold, .kern: 2.0 as CGFloat]) { _, b in b }))
        attr.append(NSAttributedString(string: "/", attributes: white.merging([.font: regular, .kern: 2.0 as CGFloat]) { _, b in b }))
        attr.append(NSAttributedString(string: "\(total)", attributes: white.merging([.font: bold]) { _, b in b }))

        photoNumberLabel.attributedText = attr
        // 라벨 표시는 +버튼 표시 시 함께 처리 (showButtons 내부)
    }

    /// 사진 번호를 숨기고 초기화합니다.
    func hidePhotoNumber() {
        photoNumberLabel.isHidden = true
        photoNumberLabel.attributedText = nil
    }

    /// 얼굴에 +버튼을 표시합니다.
    ///
    /// - Parameters:
    ///   - faces: 표시할 얼굴 정보 (유효 슬롯만 전달해야 함)
    ///   - imageSize: 원본 이미지 크기
    ///   - viewerFrame: 뷰어 프레임 (이미지가 표시되는 영역)
    ///   - assetID: 사진 ID (디버그용)
    func showButtons(for faces: [CachedFace], imageSize: CGSize, viewerFrame: CGRect, assetID: String = "") {
        // 햅틱 엔진 사전 준비 (탭 시 지연 최소화)
        feedbackGenerator.prepare()

        // 기존 버튼 제거
        removeAllButtons()

        // 상태 저장
        currentFaces = faces
        currentImageSize = imageSize
        currentAssetID = assetID

        // 유효 슬롯 얼굴만 필터링 & 크기순 상위 5개
        let validFaces = faces.filter { $0.isValidSlot }.topBySize(Constants.maxButtons)

        guard !validFaces.isEmpty else {
            toggleButton.isHidden = true
            return
        }

        // 이미 숨김 상태면 버튼 생성하지 않음
        if isOverlayHidden {
            toggleButton.isHidden = false
            return
        }

        // 버튼 위치 계산 및 생성
        var placedPositions: [CGPoint] = []

        let assetPrefix = String(assetID.prefix(8))
        Log.debug("FaceButton", "showButtons - assetID=\(assetPrefix), imageSize=\(imageSize), viewerFrame=\(viewerFrame)")

        for face in validFaces {
            // 기본 위치 계산 (얼굴 위 중앙)
            let position = face.buttonPosition(
                imageSize: imageSize,
                viewerFrame: viewerFrame,
                buttonRadius: Constants.buttonRadius
            )

            // 겹침 방지 로직 임시 비활성화 (버튼이 얼굴에서 너무 멀리 이동하는 문제)
            // TODO: 추후 이동 거리를 줄이거나 다른 방식으로 개선 필요

            let bb = face.boundingBox
            Log.debug("FaceButton", "Person(\(face.personIndex)): boundingBox=(x:\(String(format: "%.3f", bb.origin.x)), y:\(String(format: "%.3f", bb.origin.y)), w:\(String(format: "%.3f", bb.width)), h:\(String(format: "%.3f", bb.height))) -> pos=(\(String(format: "%.1f", position.x)), \(String(format: "%.1f", position.y)))")

            placedPositions.append(position)

            // 버튼 생성
            let button = createFaceButton(for: face, at: position)
            faceButtons.append(button)
            addSubview(button)
        }

        // 토글 버튼 표시 및 맨 앞으로
        toggleButton.isHidden = false
        bringSubviewToFront(toggleButton)

        // 페이드인 애니메이션 (+버튼 + 사진 번호 라벨)
        for button in faceButtons {
            button.alpha = 0
        }
        photoNumberLabel.alpha = 0
        photoNumberLabel.isHidden = (photoNumberLabel.text == nil)
        UIView.animate(withDuration: Constants.animationDuration) {
            for button in self.faceButtons {
                button.alpha = 1
            }
            if self.photoNumberLabel.text != nil {
                self.photoNumberLabel.alpha = 1
            }
        }
    }

    /// 모든 +버튼을 제거합니다.
    func hideButtons() {
        UIView.animate(withDuration: Constants.animationDuration, animations: {
            for button in self.faceButtons {
                button.alpha = 0
            }
            self.photoNumberLabel.alpha = 0
        }, completion: { _ in
            self.removeAllButtons()
            self.photoNumberLabel.isHidden = true
        })
    }

    /// 모든 +버튼을 즉시 숨깁니다 (애니메이션 없음).
    /// 줌 시작 시 호출
    func hideButtonsImmediately() {
        for button in faceButtons {
            button.alpha = 0
        }
        photoNumberLabel.alpha = 0
    }

    /// 줌 상태 기반으로 +버튼을 재표시합니다.
    ///
    /// - Parameters:
    ///   - zoomScale: 현재 줌 스케일
    ///   - contentOffset: 스크롤뷰 오프셋
    ///   - imageViewFrame: 확대된 이미지뷰 프레임
    func showButtonsWithZoom(zoomScale: CGFloat, contentOffset: CGPoint, imageViewFrame: CGRect) {
        // 줌 정보 항상 저장 (토글 시 사용)
        lastZoomInfo = (zoomScale, contentOffset, imageViewFrame)

        // 숨김 상태면 무시
        guard !isOverlayHidden else { return }

        // 현재 얼굴 정보가 없으면 무시
        guard !currentFaces.isEmpty else { return }

        // 유효 슬롯 얼굴만 필터링 & 크기순 상위 5개
        let validFaces = currentFaces.filter { $0.isValidSlot }.topBySize(Constants.maxButtons)
        guard !validFaces.isEmpty else { return }

        // 기존 버튼 위치만 업데이트 (버튼 개수가 같으면 재사용)
        var placedPositions: [CGPoint] = []

        for (index, face) in validFaces.enumerated() {
            // 줌 상태 기반 위치 계산
            var position = calculateZoomedPosition(
                for: face,
                zoomScale: zoomScale,
                contentOffset: contentOffset,
                imageViewFrame: imageViewFrame
            )

            // 겹침 방지 조정
            position = adjustForCollision(
                position: position,
                placedPositions: placedPositions,
                viewerFrame: bounds
            )

            placedPositions.append(position)

            // 기존 버튼 재사용 또는 새로 생성
            if index < faceButtons.count {
                let button = faceButtons[index]
                button.frame = CGRect(
                    x: position.x - Constants.buttonRadius,
                    y: position.y - Constants.buttonRadius,
                    width: Constants.buttonDiameter,
                    height: Constants.buttonDiameter
                )
            }
        }

        // 페이드인 애니메이션 (+버튼 + 사진 번호 라벨)
        photoNumberLabel.isHidden = (photoNumberLabel.text == nil)
        UIView.animate(withDuration: Constants.animationDuration) {
            for button in self.faceButtons {
                button.alpha = 1
            }
            if self.photoNumberLabel.text != nil {
                self.photoNumberLabel.alpha = 1
            }
        }
    }

    /// 줌 상태 기반 버튼 위치 계산
    ///
    /// - Parameters:
    ///   - face: 얼굴 정보
    ///   - zoomScale: 현재 줌 스케일
    ///   - contentOffset: 스크롤뷰 오프셋
    ///   - imageViewFrame: 확대된 이미지뷰 프레임
    /// - Returns: 화면상의 버튼 위치
    private func calculateZoomedPosition(
        for face: CachedFace,
        zoomScale: CGFloat,
        contentOffset: CGPoint,
        imageViewFrame: CGRect
    ) -> CGPoint {
        // 얼굴의 정규화 좌표 (Vision 좌표계)
        let boundingBox = face.boundingBox

        // imageViewFrame 기준으로 얼굴 위치 계산 (확대된 상태)
        // Vision 좌표를 UIKit 좌표로 변환
        let x = boundingBox.origin.x * imageViewFrame.width + imageViewFrame.origin.x
        let y = (1 - boundingBox.origin.y - boundingBox.height) * imageViewFrame.height + imageViewFrame.origin.y

        // 버튼 위치 = 얼굴 위 중앙 - contentOffset (스크롤 보정)
        let buttonX = x + (boundingBox.width * imageViewFrame.width) / 2 - contentOffset.x
        let buttonY = y - Constants.buttonRadius - contentOffset.y

        return CGPoint(x: buttonX, y: buttonY)
    }

    /// 레이아웃 업데이트 (화면 회전 시)
    ///
    /// - Parameter viewerFrame: 새 뷰어 프레임
    func layoutButtons(for viewerFrame: CGRect) {
        guard !currentFaces.isEmpty && !isOverlayHidden else { return }

        // 버튼 위치 재계산
        showButtons(for: currentFaces, imageSize: currentImageSize, viewerFrame: viewerFrame)
    }

    /// 오버레이 상태 초기화 (다른 사진으로 스와이프 시)
    func resetState() {
        isOverlayHidden = false
        lastZoomInfo = nil  // 줌 정보 초기화
        updateToggleIcon()
        removeAllButtons()
        toggleButton.isHidden = true
        hidePhotoNumber()
    }

    /// 버튼만 제거하고 줌/토글 상태는 유지 (얼굴 그리드에서 복귀 시)
    /// resetState()와 달리 isOverlayHidden, lastZoomInfo를 유지합니다.
    func clearButtonsOnly() {
        removeAllButtons()
        // 토글 버튼은 버튼이 다시 표시될 때 함께 표시됨
    }

    // MARK: - Private Methods

    /// 모든 버튼 제거
    private func removeAllButtons() {
        for button in faceButtons {
            button.removeFromSuperview()
        }
        faceButtons.removeAll()
    }

    /// +버튼 생성
    private func createFaceButton(for face: CachedFace, at position: CGPoint) -> FaceButton {
        let button = FaceButton(face: face)
        button.frame = CGRect(
            x: position.x - Constants.buttonRadius,
            y: position.y - Constants.buttonRadius,
            width: Constants.buttonDiameter,
            height: Constants.buttonDiameter
        )
        button.addTarget(self, action: #selector(faceButtonTapped(_:)), for: .touchUpInside)
        return button
    }

    /// 겹침 방지 위치 조정
    ///
    /// - Parameters:
    ///   - position: 원래 위치
    ///   - placedPositions: 이미 배치된 버튼 위치들
    ///   - viewerFrame: 뷰어 프레임 (경계 체크용)
    /// - Returns: 조정된 위치
    private func adjustForCollision(
        position: CGPoint,
        placedPositions: [CGPoint],
        viewerFrame: CGRect
    ) -> CGPoint {
        let adjustedPosition = position

        // 겹침 확인
        func hasCollision(_ pos: CGPoint) -> Bool {
            for placed in placedPositions {
                let distance = hypot(pos.x - placed.x, pos.y - placed.y)
                if distance < Constants.minimumButtonSpacing {
                    return true
                }
            }
            return false
        }

        // 경계 내 확인
        func isInBounds(_ pos: CGPoint) -> Bool {
            let buttonFrame = CGRect(
                x: pos.x - Constants.buttonRadius,
                y: pos.y - Constants.buttonRadius,
                width: Constants.buttonDiameter,
                height: Constants.buttonDiameter
            )
            return viewerFrame.contains(buttonFrame)
        }

        // 겹침이 없으면 그대로 반환
        if !hasCollision(adjustedPosition) && isInBounds(adjustedPosition) {
            return adjustedPosition
        }

        // 이동 방향: 좌 → 우 → 아래 → 위
        let offsets: [CGPoint] = [
            CGPoint(x: -Constants.collisionOffset, y: 0),  // 좌
            CGPoint(x: Constants.collisionOffset, y: 0),   // 우
            CGPoint(x: 0, y: Constants.collisionOffset),   // 아래
            CGPoint(x: 0, y: -Constants.collisionOffset)   // 위
        ]

        for offset in offsets {
            let newPosition = CGPoint(
                x: position.x + offset.x,
                y: position.y + offset.y
            )
            if !hasCollision(newPosition) && isInBounds(newPosition) {
                return newPosition
            }
        }

        // 모든 방향 실패 시 원래 위치 반환
        return position
    }

    /// 토글 아이콘 업데이트
    /// GlassCircleButton의 setIcon 메서드 사용
    private func updateToggleIcon() {
        let iconName = isOverlayHidden ? "eye.slash.fill" : "eye.fill"
        toggleButton.setIcon(iconName, animated: true)
    }

    // MARK: - Actions

    /// +버튼 탭 핸들러
    @objc private func faceButtonTapped(_ sender: FaceButton) {
        // 햅틱 피드백 (인스턴스 generator 재사용 — XPC 연결 유지)
        feedbackGenerator.impactOccurred()

        // 델리게이트 호출
        delegate?.faceButtonOverlay(self, didTapFaceAtPersonIndex: sender.face.personIndex, face: sender.face)
    }

    /// 토글 버튼 탭 핸들러
    @objc private func toggleButtonTapped() {
        isOverlayHidden.toggle()
        updateToggleIcon()

        if isOverlayHidden {
            // 버튼 + 라벨 숨기기 (페이드아웃)
            UIView.animate(withDuration: Constants.animationDuration) {
                for button in self.faceButtons {
                    button.alpha = 0
                }
                self.photoNumberLabel.alpha = 0
            }
        } else {
            // 버튼 다시 표시 (기존 얼굴로)
            if !currentFaces.isEmpty {
                // 줌 상태가 있으면 줌 기반 위치로 표시
                if let zoomInfo = lastZoomInfo, zoomInfo.zoomScale > 1.0 {
                    showButtonsWithZoom(
                        zoomScale: zoomInfo.zoomScale,
                        contentOffset: zoomInfo.contentOffset,
                        imageViewFrame: zoomInfo.imageViewFrame
                    )
                } else {
                    // 1x 스케일이면 기본 위치로 표시
                    showButtons(for: currentFaces, imageSize: currentImageSize, viewerFrame: bounds)
                }
            }
        }

        // 델리게이트에 토글 상태 알림 (타이틀 숨김/표시 연동)
        delegate?.faceButtonOverlay(self, didToggleVisibility: isOverlayHidden)
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 토글 버튼 터치 확인
        let togglePoint = convert(point, to: toggleButton)
        if toggleButton.bounds.contains(togglePoint) && !toggleButton.isHidden {
            return toggleButton
        }

        // +버튼 터치 확인
        for button in faceButtons {
            let buttonPoint = convert(point, to: button)
            if button.bounds.contains(buttonPoint) && button.alpha > 0 {
                return button
            }
        }

        // 다른 영역은 터치 통과
        return nil
    }
}

// MARK: - FaceButton

/// 얼굴 위에 표시되는 + 버튼 (GlassCircleButton 상속)
/// 탭 시 해당 얼굴의 비교 화면으로 이동
/// - Liquid Glass 스타일 적용
/// - Dual state 애니메이션 (GlassCircleButton 기본 동작)
/// - 햅틱 피드백 (GlassCircleButton 기본 동작)
/// - 크기: 32×32 (.mini), 아이콘: 18pt .semibold
final class FaceButton: GlassCircleButton {

    // MARK: - Properties

    /// 연관된 얼굴 정보
    let face: CachedFace

    // MARK: - Initialization

    init(face: CachedFace) {
        self.face = face
        super.init(icon: "plus", size: .mini, tintColor: .white)
        backgroundAlpha = 0.7
        setupAccessibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupAccessibility() {
        isAccessibilityElement = true
        accessibilityLabel = "인물 \(face.personIndex) 비교"
        accessibilityHint = "탭하여 이 인물의 사진들을 비교합니다"
    }
}
