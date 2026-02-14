//
//  CoachMarkOverlayView.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-14.
//
//  코치마크 오버레이 뷰 + 전역 매니저
//  - 딤 배경 + 하이라이트 구멍 (CAShapeLayer evenOdd)
//  - 셀 스냅샷 + Maroon 딤드 애니메이션
//  - 손가락 아이콘 제스처 시연
//  - 텍스트 + 확인 버튼
//  - Reduce Motion 대응 (정적 표시)
//
//  사용법:
//    CoachMarkOverlayView.show(
//        type: .gridSwipeDelete,
//        highlightFrame: cellFrameInWindow,
//        snapshot: cellSnapshot,
//        in: window
//    )

import UIKit

// MARK: - CoachMarkType

/// 코치마크 종류 (향후 B/C/D 추가)
enum CoachMarkType: String {
    case gridSwipeDelete = "coachMark_gridSwipe"

    /// UserDefaults 키
    var shownKey: String { rawValue }

    /// 이미 표시된 적 있는지
    var hasBeenShown: Bool {
        UserDefaults.standard.bool(forKey: shownKey)
    }

    /// 표시 완료로 마킹
    func markAsShown() {
        UserDefaults.standard.set(true, forKey: shownKey)
    }
}

// MARK: - CoachMarkManager

/// 코치마크 전역 관리 싱글톤
/// 한 번에 하나의 코치마크만 표시되도록 관리
final class CoachMarkManager {
    static let shared = CoachMarkManager()
    private init() {}

    /// 현재 표시 중인 오버레이 (weak — 오버레이가 제거되면 자동 nil)
    weak var currentOverlay: CoachMarkOverlayView?

    /// 현재 코치마크가 표시 중인지
    var isShowing: Bool {
        currentOverlay != nil
    }

    /// 현재 코치마크 dismiss (내부에서 markAsShown 자동 호출)
    func dismissCurrent() {
        currentOverlay?.dismiss()
    }
}

// MARK: - CoachMarkOverlayView

/// 코치마크 오버레이 뷰
/// 딤 배경 + 하이라이트 구멍 + 셀 스냅샷 + 손가락 애니메이션 + 텍스트 + 확인 버튼
final class CoachMarkOverlayView: UIView {

    // MARK: - Constants

    /// 딤 배경 알파
    private static let dimAlpha: CGFloat = 0.6

    /// 손가락 아이콘 크기
    private static let fingerSize: CGFloat = 48

    /// Maroon 딤드 색상 (PhotoCell과 동일)
    private static let maroonColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)

    /// Maroon 딤드 알파 (PhotoCell.dimmedOverlayAlpha와 동일)
    private static let maroonAlpha: CGFloat = 0.60

    /// 스와이프 거리 비율 (셀 너비의 55%)
    private static let swipeRatio: CGFloat = 0.55

    /// 확인 버튼 높이
    private static let buttonHeight: CGFloat = 44

    /// 확인 버튼 좌우 패딩
    private static let buttonHorizontalPadding: CGFloat = 32

    // MARK: - Properties

    /// 코치마크 타입 (dismiss 시 markAsShown에 사용)
    private var coachMarkType: CoachMarkType = .gridSwipeDelete

    /// 애니메이션 중단 플래그
    private var shouldStopAnimation = false

    /// 하이라이트 영역 (윈도우 좌표)
    private var highlightFrame: CGRect = .zero

    /// 스와이프 이동 거리
    private var swipeDistance: CGFloat = 0

    // MARK: - Subviews

    /// 딤 배경 레이어 (evenOdd로 하이라이트 구멍)
    private let dimLayer = CAShapeLayer()

    /// 셀 스냅샷 뷰
    private var snapshotView: UIView?

    /// Maroon 딤드 뷰 (스냅샷 위에 배치)
    private let maroonView: UIView = {
        let view = UIView()
        view.backgroundColor = maroonColor
        view.alpha = maroonAlpha
        return view
    }()

    /// 손가락 아이콘 뷰
    private let fingerView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: fingerSize, weight: .regular)
        let image = UIImage(systemName: "hand.point.up.fill", withConfiguration: config)
        let iv = UIImageView(image: image)
        iv.tintColor = .white
        // 그림자
        iv.layer.shadowColor = UIColor.black.cgColor
        iv.layer.shadowOffset = CGSize(width: 0, height: 2)
        iv.layer.shadowRadius = 6
        iv.layer.shadowOpacity = 0.3
        return iv
    }()

    /// 안내 텍스트 라벨
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.text = "사진을 밀어서 바로 정리하세요\n다시 밀면 복원돼요"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// 확인 버튼
    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("확인", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = buttonHeight / 2
        button.clipsToBounds = true
        return button
    }()

    /// Reduce Motion 시 방향 화살표
    private let arrowView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        let image = UIImage(systemName: "arrow.right", withConfiguration: config)
        let iv = UIImageView(image: image)
        iv.tintColor = .white
        iv.alpha = 0
        return iv
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        // 딤 배경 레이어
        dimLayer.fillColor = UIColor.black.withAlphaComponent(Self.dimAlpha).cgColor
        dimLayer.fillRule = .evenOdd
        layer.addSublayer(dimLayer)

        // 확인 버튼 액션
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
    }

    // MARK: - Layout

    /// 딤 레이어에 하이라이트 구멍 업데이트
    private func updateDimPath() {
        let fullPath = UIBezierPath(rect: bounds)
        // 하이라이트 영역은 투명 (셀 크기 + 약간의 여유)
        let holePath = UIBezierPath(rect: highlightFrame)
        fullPath.append(holePath)
        dimLayer.path = fullPath.cgPath
    }

    // MARK: - Show

    /// 코치마크 표시
    /// - Parameters:
    ///   - type: 코치마크 타입
    ///   - highlightFrame: 하이라이트 영역 (윈도우 좌표)
    ///   - snapshot: 셀 스냅샷 뷰
    ///   - window: 표시할 윈도우
    static func show(
        type: CoachMarkType,
        highlightFrame: CGRect,
        snapshot: UIView,
        in window: UIWindow
    ) {
        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = type
        overlay.highlightFrame = highlightFrame
        overlay.swipeDistance = highlightFrame.width * swipeRatio
        overlay.alpha = 0

        // 윈도우에 추가
        window.addSubview(overlay)

        // 매니저에 등록
        CoachMarkManager.shared.currentOverlay = overlay

        // 딤 배경 구멍 업데이트
        overlay.updateDimPath()

        // 스냅샷 배치 (하이라이트 위치에)
        snapshot.frame = highlightFrame
        snapshot.clipsToBounds = true
        overlay.addSubview(snapshot)
        overlay.snapshotView = snapshot

        // Maroon 딤드 (스냅샷 위에 배치, 초기 width 0)
        overlay.maroonView.frame = CGRect(
            x: 0, y: 0,
            width: 0,
            height: highlightFrame.height
        )
        snapshot.addSubview(overlay.maroonView)

        // 손가락 아이콘 배치
        overlay.fingerView.sizeToFit()
        overlay.fingerView.center = CGPoint(
            x: highlightFrame.midX + highlightFrame.width * 0.1,
            y: highlightFrame.midY
        )
        overlay.fingerView.alpha = 0
        overlay.fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        overlay.addSubview(overlay.fingerView)

        // 화살표 아이콘 (Reduce Motion용)
        overlay.arrowView.center = CGPoint(
            x: highlightFrame.midX,
            y: highlightFrame.midY
        )
        overlay.addSubview(overlay.arrowView)

        // 텍스트 라벨
        overlay.messageLabel.frame = CGRect(
            x: 20,
            y: highlightFrame.maxY + 24,
            width: overlay.bounds.width - 40,
            height: 60
        )
        overlay.addSubview(overlay.messageLabel)

        // 확인 버튼
        let buttonWidth: CGFloat = 120
        overlay.confirmButton.frame = CGRect(
            x: (overlay.bounds.width - buttonWidth) / 2,
            y: overlay.messageLabel.frame.maxY + 16,
            width: buttonWidth,
            height: buttonHeight
        )
        overlay.addSubview(overlay.confirmButton)

        // 페이드인
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        } completion: { _ in
            // 애니메이션 시작 (Reduce Motion 분기)
            if UIAccessibility.isReduceMotionEnabled {
                overlay.showStaticGuide()
            } else {
                overlay.startGestureLoop()
            }
        }
    }

    // MARK: - Dismiss

    /// 코치마크 dismiss (markAsShown 자동 호출)
    func dismiss() {
        guard superview != nil else { return }
        shouldStopAnimation = true
        fingerView.layer.removeAllAnimations()
        maroonView.layer.removeAllAnimations()

        // 표시 완료 마킹
        coachMarkType.markAsShown()

        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }

    // MARK: - Hit Test

    /// 확인 버튼만 터치 받고, 나머지는 아래로 통과
    /// (사용자가 스와이프 시도 가능하도록)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 확인 버튼 영역이면 버튼에 전달
        let buttonPoint = confirmButton.convert(point, from: self)
        if confirmButton.bounds.contains(buttonPoint) {
            return confirmButton
        }
        // 나머지는 아래로 통과
        return nil
    }

    // MARK: - Actions

    @objc private func confirmTapped() {
        dismiss()
    }

    // MARK: - Static Guide (Reduce Motion)

    /// 애니메이션 없이 정적 안내 표시
    private func showStaticGuide() {
        // Maroon 딤드를 55% 채운 정적 상태로
        maroonView.frame.size.width = swipeDistance

        // 손가락 아이콘을 셀 오른쪽에 정지 상태로 배치
        fingerView.center = CGPoint(
            x: highlightFrame.minX + swipeDistance,
            y: highlightFrame.midY
        )
        fingerView.alpha = 1
        fingerView.transform = .identity

        // 화살표로 방향 표시
        arrowView.center = CGPoint(
            x: highlightFrame.midX,
            y: highlightFrame.maxY - 12
        )
        arrowView.alpha = 0.8
    }

    // MARK: - Gesture Animation Loop

    /// 제스처 시연 애니메이션 시작 (5단계 completion 체인, 무한 반복)
    private func startGestureLoop() {
        guard !shouldStopAnimation else { return }

        // Stage 1: Touch Down — 등장 (0.3초, easeOut)
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                self.fingerView.alpha = 1.0
                self.fingerView.transform = .identity
                self.fingerView.layer.shadowOpacity = 0.3
                self.fingerView.layer.shadowRadius = 8
            }
        ) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }

            // Stage 2: Press — 누르기 (0.2초, spring)
            UIView.animate(
                withDuration: 0.2,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0,
                options: [],
                animations: {
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                    self.fingerView.layer.shadowRadius = 4
                    self.fingerView.layer.shadowOpacity = 0.2
                }
            ) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else { return }

                // Stage 3: Drag — 스와이프 (0.6초, custom cubic-bezier)
                let timing = UICubicTimingParameters(
                    controlPoint1: CGPoint(x: 0.4, y: 0.0),
                    controlPoint2: CGPoint(x: 0.2, y: 1.0)
                )
                let dragAnimator = UIViewPropertyAnimator(
                    duration: 0.6,
                    timingParameters: timing
                )
                dragAnimator.addAnimations {
                    self.fingerView.center.x += self.swipeDistance
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                        .rotated(by: .pi / 24)
                    self.maroonView.frame.size.width = self.swipeDistance
                }
                dragAnimator.addCompletion { [weak self] _ in
                    guard let self, !self.shouldStopAnimation else { return }

                    // Stage 4: Release — 떼기 (0.35초)
                    // 손가락 페이드아웃 (0.2초)
                    UIView.animate(
                        withDuration: 0.2,
                        delay: 0,
                        options: .curveEaseIn,
                        animations: {
                            self.fingerView.alpha = 0
                            self.fingerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                            self.fingerView.center.y -= 10
                        }
                    ) { _ in }

                    // Maroon 딤드 페이드아웃 (0.15초, 0.2초 delay)
                    UIView.animate(
                        withDuration: 0.15,
                        delay: 0.2,
                        options: .curveEaseOut,
                        animations: {
                            self.maroonView.alpha = 0
                        }
                    ) { [weak self] _ in
                        guard let self, !self.shouldStopAnimation else { return }

                        // Stage 5: Pause — 대기 (1.4초) → 리셋 → 재시작
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                            guard let self, !self.shouldStopAnimation else { return }
                            self.resetPositions()
                            self.startGestureLoop()
                        }
                    }
                }
                dragAnimator.startAnimation()
            }
        }
    }

    /// 모든 뷰를 초기 상태로 리셋
    private func resetPositions() {
        // 손가락 위치/상태 리셋
        fingerView.center = CGPoint(
            x: highlightFrame.midX + highlightFrame.width * 0.1,
            y: highlightFrame.midY
        )
        fingerView.alpha = 0
        fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        fingerView.layer.shadowOpacity = 0
        fingerView.layer.shadowRadius = 4

        // Maroon 딤드 리셋
        maroonView.frame.size.width = 0
        maroonView.alpha = Self.maroonAlpha
    }
}
