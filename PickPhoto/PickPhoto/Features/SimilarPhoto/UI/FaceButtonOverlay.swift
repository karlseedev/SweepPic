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

/// +버튼 탭 이벤트 델리게이트
protocol FaceButtonOverlayDelegate: AnyObject {
    /// +버튼이 탭되었을 때 호출
    /// - Parameters:
    ///   - overlay: 오버레이 인스턴스
    ///   - personIndex: 탭된 얼굴의 인물 번호
    ///   - face: 탭된 얼굴 정보
    func faceButtonOverlay(_ overlay: FaceButtonOverlay, didTapFaceAtPersonIndex personIndex: Int, face: CachedFace)
}

/// 뷰어에서 얼굴 위에 +버튼을 표시하는 오버레이 뷰
///
/// 유사 사진 그룹에 속한 사진을 뷰어에서 볼 때,
/// 감지된 얼굴 위에 +버튼을 표시하여 얼굴 비교 화면으로 진입할 수 있게 합니다.
final class FaceButtonOverlay: UIView {

    // MARK: - Constants

    /// UI 관련 상수
    private enum Constants {
        /// 버튼 크기 (지름)
        static let buttonDiameter: CGFloat = 44

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

    /// 디버그 로그 활성화 (+버튼 좌표 계산 정보)
    private let debugButtonPosition = true

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

    /// 토글 버튼
    private lazy var toggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        // SF Symbol 설정
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "eye.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white

        // 배경 스타일
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 18

        // 탭 핸들러
        button.addTarget(self, action: #selector(toggleButtonTapped), for: .touchUpInside)

        return button
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

        // 토글 버튼 추가 (화면 우측 상단, 뒤로가기 버튼과 같은 높이) - T034
        addSubview(toggleButton)
        NSLayoutConstraint.activate([
            toggleButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            toggleButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            toggleButton.widthAnchor.constraint(equalToConstant: 36),
            toggleButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        // 토글 버튼은 초기에는 숨김 (버튼이 있을 때만 표시)
        toggleButton.isHidden = true
    }

    // MARK: - Public Methods

    /// 얼굴에 +버튼을 표시합니다.
    ///
    /// - Parameters:
    ///   - faces: 표시할 얼굴 정보 (유효 슬롯만 전달해야 함)
    ///   - imageSize: 원본 이미지 크기
    ///   - viewerFrame: 뷰어 프레임 (이미지가 표시되는 영역)
    ///   - assetID: 사진 ID (디버그용)
    func showButtons(for faces: [CachedFace], imageSize: CGSize, viewerFrame: CGRect, assetID: String = "") {
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

        if debugButtonPosition {
            let assetPrefix = String(assetID.prefix(8))
            print("[FaceButton] showButtons - assetID=\(assetPrefix), imageSize=\(imageSize), viewerFrame=\(viewerFrame)")
        }

        for face in validFaces {
            // 기본 위치 계산 (얼굴 위 중앙)
            var position = face.buttonPosition(
                imageSize: imageSize,
                viewerFrame: viewerFrame,
                buttonRadius: Constants.buttonRadius
            )

            let originalPosition = position

            // 겹침 방지 조정
            position = adjustForCollision(
                position: position,
                placedPositions: placedPositions,
                viewerFrame: viewerFrame
            )

            if debugButtonPosition {
                let bb = face.boundingBox
                let wasAdjusted = position != originalPosition
                var logMsg = "[FaceButton] Person(\(face.personIndex)): boundingBox=(x:\(String(format: "%.3f", bb.origin.x)), y:\(String(format: "%.3f", bb.origin.y)), w:\(String(format: "%.3f", bb.width)), h:\(String(format: "%.3f", bb.height)))"
                logMsg += " -> original=(\(String(format: "%.1f", originalPosition.x)), \(String(format: "%.1f", originalPosition.y)))"
                if wasAdjusted {
                    logMsg += " -> ADJUSTED=(\(String(format: "%.1f", position.x)), \(String(format: "%.1f", position.y)))"
                    logMsg += " [delta: x=\(String(format: "%.1f", position.x - originalPosition.x)), y=\(String(format: "%.1f", position.y - originalPosition.y))]"
                }
                print(logMsg)
            }

            placedPositions.append(position)

            // 버튼 생성
            let button = createFaceButton(for: face, at: position)
            faceButtons.append(button)
            addSubview(button)
        }

        // 토글 버튼 표시 및 맨 앞으로
        toggleButton.isHidden = false
        bringSubviewToFront(toggleButton)

        // 페이드인 애니메이션
        for button in faceButtons {
            button.alpha = 0
        }
        UIView.animate(withDuration: Constants.animationDuration) {
            for button in self.faceButtons {
                button.alpha = 1
            }
        }
    }

    /// 모든 +버튼을 제거합니다.
    func hideButtons() {
        UIView.animate(withDuration: Constants.animationDuration, animations: {
            for button in self.faceButtons {
                button.alpha = 0
            }
        }, completion: { _ in
            self.removeAllButtons()
        })
    }

    /// 모든 +버튼을 즉시 숨깁니다 (애니메이션 없음).
    /// 줌 시작 시 호출
    func hideButtonsImmediately() {
        for button in faceButtons {
            button.alpha = 0
        }
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

        // 페이드인 애니메이션
        UIView.animate(withDuration: Constants.animationDuration) {
            for button in self.faceButtons {
                button.alpha = 1
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
    private func updateToggleIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let iconName = isOverlayHidden ? "eye.slash.fill" : "eye.fill"
        let image = UIImage(systemName: iconName, withConfiguration: config)
        toggleButton.setImage(image, for: .normal)
    }

    // MARK: - Actions

    /// +버튼 탭 핸들러
    @objc private func faceButtonTapped(_ sender: FaceButton) {
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // 델리게이트 호출
        delegate?.faceButtonOverlay(self, didTapFaceAtPersonIndex: sender.face.personIndex, face: sender.face)
    }

    /// 토글 버튼 탭 핸들러
    @objc private func toggleButtonTapped() {
        isOverlayHidden.toggle()
        updateToggleIcon()

        if isOverlayHidden {
            // 버튼 숨기기 (페이드아웃)
            UIView.animate(withDuration: Constants.animationDuration) {
                for button in self.faceButtons {
                    button.alpha = 0
                }
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

/// 얼굴 위에 표시되는 + 버튼
/// 탭 시 해당 얼굴의 비교 화면으로 이동
final class FaceButton: UIButton {

    // MARK: - Properties

    /// 연관된 얼굴 정보
    let face: CachedFace

    // MARK: - Initialization

    init(face: CachedFace) {
        self.face = face
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        // SF Symbol + 아이콘
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let image = UIImage(systemName: "plus.circle.fill", withConfiguration: config)
        setImage(image, for: .normal)

        // 스타일
        tintColor = .white
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        layer.cornerRadius = 22

        // 그림자
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.3

        // 접근성
        isAccessibilityElement = true
        accessibilityLabel = "인물 \(face.personIndex) 비교"
        accessibilityHint = "탭하여 이 인물의 사진들을 비교합니다"
    }

    // MARK: - Touch Feedback

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.9, y: 0.9)
                    : .identity
                self.alpha = self.isHighlighted ? 0.7 : 1.0
            }
        }
    }
}
