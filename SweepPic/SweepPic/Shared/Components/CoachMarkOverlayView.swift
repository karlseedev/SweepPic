//
//  CoachMarkOverlayView.swift
//  SweepPic
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
import AppCore
import OSLog

// MARK: - CoachMarkType

/// 코치마크 종류
enum CoachMarkType: String {
    case gridSwipeDelete = "coachMark_gridSwipe"       // A: 목록에서 밀어서 삭제
    case viewerSwipeDelete = "coachMark_viewerSwipe"   // B: 뷰어에서 밀어서 삭제
    case similarPhoto = "coachMark_similarPhoto"       // C: 유사사진·얼굴 비교 (C-1 + C-2 통합 플래그)
    case autoCleanup = "coachMark_autoCleanup"              // D: 저품질 자동 정리 안내
    case firstDeleteGuide = "coachMark_firstDeleteGuide"  // E-1+E-2: 삭제 시스템 안내 (통합 시퀀스)
    case firstEmpty = "coachMark_firstEmpty"               // E-3: 첫 비우기 완료 안내
    case faceComparisonGuide = "coachMark_faceComparisonGuide"  // C-3: 얼굴 비교 화면 선택 안내
    case autoCleanupPreview = "coachMark_autoCleanupPreview"   // D-1: 자동정리 미리보기 안내

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

    /// 코치마크 표시 기록 리셋 (재생 기능에서 사용)
    func resetShown() {
        UserDefaults.standard.removeObject(forKey: shownKey)
        Logger.coachMark.debug("reset: \(self.rawValue)")
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

    // MARK: - C 전용 상태

    /// C-1 완료 후 C-2 대기 중 (true 동안 dismissCurrent() 차단)
    var isWaitingForC2: Bool = false

    /// C-2 확인 후 실행할 콜백 (얼굴 비교 화면 진입)
    var c2OnConfirm: (() -> Void)?

    /// C-1 → C-2 안전 타임아웃 WorkItem (C-2 전환 성공 시 cancel)
    var safetyTimeoutWork: DispatchWorkItem?

    // MARK: - E 전용 상태

    /// E-1+E-2 시퀀스 진행 중 (true 동안 dismissCurrent() 차단)
    /// Step 1 [확인] → 탭 전환 → Step 2/3 표시 동안 뷰 전환으로 인한 dismiss 방지
    var isDeleteGuideSequenceActive: Bool = false

    /// C-3 Step 1→2 전환 중 (true 동안 dismissCurrent() 차단)
    var isC3TransitionActive: Bool = false

    // MARK: - A-1 전용 상태

    /// A-1 스와이프 실습 모드 활성 중 (true 동안 dismissCurrent() 차단)
    var isA1Active: Bool = false

    /// A Step 1→2 전환 중 (true 동안 dismissCurrent() 차단)
    var isA2TransitionActive: Bool = false

    // MARK: - D-1 전용 상태

    /// D-1 4단계 시퀀스 전환 중 (true 동안 dismissCurrent() 차단)
    var isD1SequenceActive: Bool = false

    // MARK: - C 자동 pop + 간편정리 하이라이트 상태

    /// C-3 완료 후 자동 pop 진행 중 (true 동안 B 표시 차단, 뷰어 자동 pop)
    var isAutoPopForC: Bool = false

    /// 자동 pop 완료 후 간편정리 하이라이트 표시 대기 중
    var pendingCleanupHighlight: Bool = false

    // MARK: - D 표시 조건

    /// C 완료 후 그리드를 떠났다 돌아올 때 D 표시 (viewWillDisappear에서 설정)
    var pendingDAfterCComplete: Bool = false

    /// 현재 코치마크 dismiss
    /// ⚠️ C-1 → C-2 전환 중, E-1+E-2 시퀀스 진행 중, C-3 전환 중, A-1 진행 중에는 dismiss 차단 (오버레이 보호)
    func dismissCurrent() {
        if isA1Active {
            Logger.coachMark.debug("dismissCurrent BLOCKED — isA1Active=true")
            return
        }
        if isWaitingForC2 {
            Logger.coachMark.debug("dismissCurrent BLOCKED — isWaitingForC2=true, overlay=\(self.currentOverlay != nil)")
            return
        }
        if isDeleteGuideSequenceActive {
            Logger.coachMark.debug("dismissCurrent BLOCKED — isDeleteGuideSequenceActive=true")
            return
        }
        if isC3TransitionActive {
            Logger.coachMark.debug("dismissCurrent BLOCKED — isC3TransitionActive=true")
            return
        }
        if isA2TransitionActive {
            Logger.coachMark.debug("dismissCurrent BLOCKED — isA2TransitionActive=true")
            return
        }
        if isD1SequenceActive {
            Logger.coachMark.debug("dismissCurrent BLOCKED — isD1SequenceActive=true")
            return
        }
        Logger.coachMark.debug("dismissCurrent — overlay=\(self.currentOverlay != nil)")
        currentOverlay?.dismiss()
    }

    /// C 상태 완전 리셋 (모든 실패/완료 경로에서 호출)
    func resetC2State() {
        isWaitingForC2 = false
        c2OnConfirm = nil
        safetyTimeoutWork?.cancel()
        safetyTimeoutWork = nil
    }
}

// MARK: - CoachMarkOverlayView

/// 코치마크 오버레이 뷰
/// 딤 배경 + 하이라이트 구멍 + 셀 스냅샷 + 손가락 애니메이션 + 텍스트 + 확인 버튼
final class CoachMarkOverlayView: UIView {

    // MARK: - Constants

    /// 딤 배경 알파
    private static let dimAlpha: CGFloat = 0.8

    /// 손가락 아이콘 크기
    private static let fingerSize: CGFloat = 48

    /// Maroon 딤드 색상 (PhotoCell과 동일, A2 extension에서 접근 필요)
    static let maroonColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)

    /// Maroon 딤드 알파 (PhotoCell.dimmedOverlayAlpha와 동일, A2 extension에서 접근 필요)
    static let maroonAlpha: CGFloat = 0.60

    /// 스와이프 거리 비율 (셀 너비의 100%)
    private static let swipeRatio: CGFloat = 1.0

    /// 확인 버튼 높이
    private static let buttonHeight: CGFloat = 44

    /// 확인 버튼 좌우 패딩
    private static let buttonHorizontalPadding: CGFloat = 32

    // MARK: 공용 폰트 상수 (A/B/C/D/E 전체 공용)

    /// 본문 기본 폰트 (18pt regular)
    static let bodyFont = UIFont.systemFont(ofSize: 18, weight: .regular)

    /// 본문 강조 폰트 (18pt bold, 키워드 하이라이트용)
    static let bodyBoldFont = UIFont.systemFont(ofSize: 18, weight: .bold)

    /// 강조 노란색 (#FFEA00, 키워드 하이라이트용)
    static let highlightYellow = UIColor(red: 1.0, green: 0.918, blue: 0.0, alpha: 1.0)

    // MARK: B (뷰어) 전용 상수

    /// B: 손가락 이동 거리 (pt)
    private static let viewerFingerMoveDistance: CGFloat = 300

    /// B: 최대 반복 횟수 (NNGroup 권장: 과다 반복 시 사용자 무시)
    private static let maxVerticalLoopCount: Int = 3

    // MARK: - Properties

    /// 코치마크 타입 (dismiss 시 markAsShown에 사용)
    var coachMarkType: CoachMarkType = .gridSwipeDelete

    /// 애니메이션 중단 플래그
    var shouldStopAnimation = false

    /// 하이라이트 영역 (윈도우 좌표)
    var highlightFrame: CGRect = .zero

    /// A-1 스와이프 실습 모드 (하이라이트 영역 터치 통과)
    var isA1SwipeMode: Bool = false

    /// dismiss 완료 시 호출되는 콜백 (외부 리소스 정리용)
    var onDismiss: (() -> Void)?

    /// C 전용: [확인] + 탭 모션 후 실행할 콜백
    var onConfirm: (() -> Void)?

    /// 스와이프 이동 거리
    private var swipeDistance: CGFloat = 0

    /// B: 애니메이션 루프 카운트 (3회 후 정지)
    private var loopCount: Int = 0

    // MARK: - Subviews

    /// 딤 배경 레이어 (evenOdd로 하이라이트 구멍)
    let dimLayer = CAShapeLayer()

    /// 셀 스냅샷 뷰 (A2 extension에서 접근 필요)
    var snapshotView: UIView?

    /// Maroon 딤드 뷰 (스냅샷 위에 배치, A2 extension에서 접근 필요)
    let maroonView: UIView = {
        let view = UIView()
        view.backgroundColor = maroonColor
        view.alpha = maroonAlpha
        return view
    }()

    /// 손가락 아이콘 뷰 (C 확장에서 탭 모션 사용)
    let fingerView: UIImageView = {
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

    /// 안내 텍스트 라벨 (C 확장에서 텍스트 교체/페이드 사용)
    let messageLabel: UILabel = {
        let label = UILabel()
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 8  // 2줄↔3줄 사이 추가 간격
        // \u{2028} = 같은 단락 내 줄바꿈, \n = 단락 구분 (paragraphSpacing 적용)
        let fullText = String(localized: "coachMark.a.body")
        let keywords = [
            String(localized: "coachMark.a.keyword.delete"),
            String(localized: "coachMark.a.keyword.restore"),
            String(localized: "coachMark.a.keyword.trash"),
        ]
        let attr = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: CoachMarkOverlayView.bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
        )
        // 키워드 볼드 + 노란색 강조 (fallback: range 미발견 시 무시)
        for keyword in keywords {
            if let range = fullText.range(of: keyword) {
                attr.addAttributes([.font: CoachMarkOverlayView.bodyBoldFont, .foregroundColor: CoachMarkOverlayView.highlightYellow], range: NSRange(range, in: fullText))
            }
        }
        label.attributedText = attr
        label.numberOfLines = 0
        return label
    }()

    /// 확인 버튼 (C 확장에서 enable/disable/페이드 사용)
    let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(String(localized: "common.ok"), for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .white
        button.layer.cornerRadius = buttonHeight / 2
        button.clipsToBounds = true
        return button
    }()

    /// A 전용: 스냅샷 위 타이틀 라벨 (pill 테두리)
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = String(localized: "coachMark.a.title")
        label.textColor = .white
        label.font = .systemFont(ofSize: 24, weight: .light)
        label.textAlignment = .center
        // pill shape 흰색 테두리
        label.layer.borderColor = UIColor.white.cgColor
        label.layer.borderWidth = 1
        return label
    }()

    /// Reduce Motion 시 방향 화살표 (A2 extension에서 접근 필요)
    let arrowView: UIImageView = {
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

    /// 딤 레이어 경로 업데이트
    /// A/C: evenOdd로 하이라이트 구멍 / B/E: 구멍 없음 또는 동적 구멍
    func updateDimPath() {
        let fullPath = UIBezierPath(rect: bounds)
        // A, C: 하이라이트 영역은 투명 (셀/버튼 크기 + 약간의 여유)
        if coachMarkType == .gridSwipeDelete || coachMarkType == .similarPhoto || coachMarkType == .faceComparisonGuide {
            // A, C: 셀 크기 그대로, 각진 모서리 (margin 0, radius 0)
            let holePath = UIBezierPath(rect: highlightFrame)
            fullPath.append(holePath)
        }
        // D-1: 자동정리 미리보기 안내 (Step별 shape 분기)
        if coachMarkType == .autoCleanupPreview && highlightFrame != .zero {
            if d1CurrentStep == 3 {
                // Step 3: 직사각형 (margin 0, C-1/A 패턴 — 셀 정확 크기)
                let holePath = UIBezierPath(roundedRect: highlightFrame, cornerRadius: 0)
                fullPath.append(holePath)
            } else if d1CurrentStep == 1 {
                // Step 1: pill shape (margin 8pt — 헤더 타이틀)
                let margin: CGFloat = 8
                let holeRect = highlightFrame.insetBy(dx: -margin, dy: -margin)
                let radius = holeRect.height / 2
                let holePath = UIBezierPath(roundedRect: holeRect, cornerRadius: radius)
                fullPath.append(holePath)
            } else {
                // Step 2,4: pill shape (margin 0 — 버튼에 딱 맞게)
                let radius = highlightFrame.height / 2
                let holePath = UIBezierPath(roundedRect: highlightFrame, cornerRadius: radius)
                fullPath.append(holePath)
            }
        }
        // D: 정리 버튼 하이라이트 (pill shape, margin 8pt)
        // highlightFrame이 .zero가 아닐 때만 (트리거 1: 자동, 트리거 2는 구멍 없음)
        if coachMarkType == .autoCleanup && highlightFrame != .zero {
            let margin: CGFloat = 8
            let holeRect = highlightFrame.insetBy(dx: -margin, dy: -margin)
            // pill shape: cornerRadius = 높이의 절반
            let radius: CGFloat = holeRect.height / 2
            let holePath = UIBezierPath(roundedRect: holeRect, cornerRadius: radius)
            fullPath.append(holePath)
        }
        // E-1+E-2: 하이라이트 (highlightFrame이 .zero가 아닐 때만)
        // Step 1: 삭제대기함 탭 포커스 (60% 크기), Step 3: 비우기 버튼 (원래 크기)
        if coachMarkType == .firstDeleteGuide && highlightFrame != .zero {
            let margin: CGFloat = 6
            let holeRect = highlightFrame.insetBy(dx: -margin, dy: -margin)
            // Step 1 탭 포커스는 60% 크기, Step 3 비우기 버튼은 원래 크기
            let scale: CGFloat = (systemFeedbackCurrentStep == 1) ? 0.6 : 1.0
            let diameter = max(holeRect.width, holeRect.height) * scale
            let circleRect = CGRect(
                x: holeRect.midX - diameter / 2,
                y: holeRect.midY - diameter / 2,
                width: diameter,
                height: diameter
            )
            let holePath = UIBezierPath(ovalIn: circleRect)
            fullPath.append(holePath)
        }
        // B, E-3: 구멍 없음 (dim 전체 영역)
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

        // 손가락 아이콘 배치 (빨간딤드 우측 끝과 x 일치)
        overlay.fingerView.sizeToFit()
        overlay.fingerView.center = CGPoint(
            x: highlightFrame.minX,
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

        // 타이틀 라벨 (스냅샷 위, pill 테두리)
        overlay.titleLabel.sizeToFit()
        let titlePadding = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        let titleSize = overlay.titleLabel.bounds.size
        let titleWidth = titleSize.width + titlePadding.left + titlePadding.right
        let titleHeight = titleSize.height + titlePadding.top + titlePadding.bottom
        overlay.titleLabel.frame = CGRect(
            x: (overlay.bounds.width - titleWidth) / 2,
            y: highlightFrame.minY - 40 - titleHeight,
            width: titleWidth,
            height: titleHeight
        )
        overlay.titleLabel.layer.cornerRadius = titleHeight / 2
        overlay.titleLabel.clipsToBounds = true
        overlay.addSubview(overlay.titleLabel)

        // 텍스트 라벨 (동적 높이 — 언어별 텍스트 길이 대응)
        let labelWidth = overlay.bounds.width - 40
        let labelSize = overlay.messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude))
        overlay.messageLabel.frame = CGRect(
            x: 20,
            y: highlightFrame.maxY + 24,
            width: labelWidth,
            height: ceil(labelSize.height)
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

    // MARK: - Show A Variant (Replay: 1회 스와이프 → 자동 완료)

    /// E-1+E-2 재생용 A 변형 오버레이
    /// 기존 A와 동일한 셀 하이라이트 + 스와이프 모션이지만:
    /// - 스와이프 1회만 (복원 없음)
    /// - 확인 버튼 없음
    /// - 다른 텍스트
    /// - 모션 완료 시 자동 dismiss + onComplete 콜백
    /// - Parameters:
    ///   - highlightFrame: 셀 프레임 (윈도우 좌표)
    ///   - snapshot: 셀 스냅샷
    ///   - window: 표시할 윈도우
    ///   - onComplete: 모션 완료 + dismiss 후 콜백 (삭제 실행용)
    static func showReplaySwipeVariant(
        highlightFrame: CGRect,
        snapshot: UIView,
        in window: UIWindow,
        onComplete: @escaping () -> Void
    ) {
        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .gridSwipeDelete
        overlay.highlightFrame = highlightFrame
        overlay.swipeDistance = highlightFrame.width * swipeRatio
        overlay.alpha = 0

        // 윈도우에 추가
        window.addSubview(overlay)

        // 매니저에 등록
        CoachMarkManager.shared.currentOverlay = overlay

        // 딤 배경 구멍 업데이트
        overlay.updateDimPath()

        // 스냅샷 배치
        snapshot.frame = highlightFrame
        snapshot.clipsToBounds = true
        overlay.addSubview(snapshot)
        overlay.snapshotView = snapshot

        // Maroon 딤드 (초기 width 0)
        overlay.maroonView.frame = CGRect(
            x: 0, y: 0,
            width: 0,
            height: highlightFrame.height
        )
        snapshot.addSubview(overlay.maroonView)

        // 손가락 아이콘
        overlay.fingerView.sizeToFit()
        overlay.fingerView.center = CGPoint(
            x: highlightFrame.minX,
            y: highlightFrame.midY
        )
        overlay.fingerView.alpha = 0
        overlay.fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        overlay.addSubview(overlay.fingerView)

        // 페이드인 → 1회 스와이프 → 팝업 카드 표시 → 확인 탭 시 dismiss
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        } completion: { _ in
            if UIAccessibility.isReduceMotionEnabled {
                // Reduce Motion: 바로 팝업 카드 표시
                overlay.buildReplayVariantCard(onComplete: onComplete)
            } else {
                overlay.performSingleDeleteSwipe(onComplete: onComplete)
            }
        }
    }

    /// A 변형: 1회 삭제 스와이프만 수행 (복원 없음)
    /// 모션 완료 후 자동 dismiss + onComplete 콜백
    private func performSingleDeleteSwipe(onComplete: @escaping () -> Void) {
        guard !shouldStopAnimation else { return }

        // 1) Touch Down
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

            // 2) Press
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

                // 3) Drag → 오른쪽 (1회만)
                let timing = UICubicTimingParameters(
                    controlPoint1: CGPoint(x: 0.4, y: 0.0),
                    controlPoint2: CGPoint(x: 0.2, y: 1.0)
                )
                let animator = UIViewPropertyAnimator(duration: 0.3, timingParameters: timing)
                animator.addAnimations {
                    self.fingerView.center.x += self.swipeDistance
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                        .rotated(by: .pi / 24)
                    self.maroonView.frame.size.width = self.swipeDistance
                }
                animator.addCompletion { [weak self] _ in
                    guard let self, !self.shouldStopAnimation else { return }

                    // 4) Release
                    UIView.animate(
                        withDuration: 0.2,
                        delay: 0,
                        options: .curveEaseIn,
                        animations: {
                            self.fingerView.alpha = 0
                            self.fingerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                            self.fingerView.center.y -= 10
                        }
                    ) { [weak self] _ in
                        // 1회 완료 → 0.3초 텀 → 팝업 카드 표시
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self?.buildReplayVariantCard(onComplete: onComplete)
                        }
                    }
                }
                animator.startAnimation()
            }
        }
    }

    /// A 변형: 스와이프 완료 후 안내 팝업 카드 표시
    /// blur 배경 카드 + 텍스트 + [확인] 버튼, 확인 탭 시 dismiss → onComplete
    private func buildReplayVariantCard(onComplete: @escaping () -> Void) {
        // 카드 컨테이너 (blur 배경)
        let card = UIView()
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.alpha = 0

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.frame = card.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.addSubview(blur)
        addSubview(card)

        // 안내 텍스트 ("삭제대기함" 볼드+노란색 강조)
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        let text = String(localized: "coachMark.a.variant.body")
        let keyword = String(localized: "coachMark.a.variant.keyword")
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: Self.bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }(),
            ]
        )
        // 키워드 볼드 + 노란색 강조 (fallback: range 미발견 시 무시)
        if let range = text.range(of: keyword) {
            let nsRange = NSRange(range, in: text)
            attributed.addAttributes([
                .font: Self.bodyBoldFont,
                .foregroundColor: Self.highlightYellow,
            ], range: nsRange)
        }
        label.attributedText = attributed
        card.addSubview(label)

        // [확인] 버튼
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = true
        confirmButton.alpha = 1
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(confirmButton)

        // 확인 탭 → dismiss → onComplete (삭제 + E 시퀀스)
        onConfirm = { [weak self] in
            self?.dismissReplayVariant(onComplete: onComplete)
        }

        // 레이아웃 (하이라이트 셀 아래)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.topAnchor.constraint(equalTo: topAnchor, constant: highlightFrame.maxY + 24),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -48),

            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            confirmButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            confirmButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: Self.buttonHeight),
            confirmButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])

        // 카드 페이드인
        UIView.animate(withDuration: 0.25) {
            card.alpha = 1
        }
    }

    /// A 변형 dismiss + onComplete 콜백
    private func dismissReplayVariant(onComplete: @escaping () -> Void) {
        shouldStopAnimation = true
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
        }) { _ in
            CoachMarkManager.shared.currentOverlay = nil
            self.removeFromSuperview()
            onComplete()
        }
    }

    // MARK: - Show B (Viewer Swipe Delete)

    /// 코치마크 B: 뷰어에서 밀어서 삭제 표시
    /// - 검정 배경 + 살짝 딤, 스냅샷+손가락 애니메이션 유지
    /// - 텍스트+확인 버튼은 E 스타일 blur 카드 팝업 (중앙 아래 배치)
    /// - containerView에 추가하여 뷰어의 상하단 버튼이 위에 보이도록 함
    /// - Parameters:
    ///   - photoSnapshot: 사진 이미지뷰 스냅샷 (검은 여백 제외)
    ///   - photoFrame: 사진 영역 프레임 (containerView 좌표)
    ///   - containerView: 오버레이를 추가할 뷰 (뷰어의 view)
    static func showViewerSwipeDelete(
        photoSnapshot: UIView,
        photoFrame: CGRect,
        in containerView: UIView
    ) {
        let overlay = CoachMarkOverlayView(frame: containerView.bounds)
        overlay.coachMarkType = .viewerSwipeDelete

        // 즉시 터치 차단 (0.01 = hitTest 통과 최소값, 시각적으로 투명)
        overlay.alpha = 0.01

        // 솔리드 검정 배경 (스냅샷 이동 시 원본 이미지 차단)
        overlay.backgroundColor = .black
        // B는 dimLayer 사용 안 함 (sublayer는 subview 아래 렌더링되어 보이지 않음)
        overlay.dimLayer.fillColor = UIColor.clear.cgColor

        // containerView에 추가 (뷰어 버튼들 아래)
        containerView.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // 스냅샷 배치 (사진 영역만, 검은 여백 제외)
        photoSnapshot.frame = photoFrame
        overlay.addSubview(photoSnapshot)
        overlay.snapshotView = photoSnapshot

        // 딤 오버레이 (스냅샷 위에 반투명 검정, E-1과 동일한 0.3)
        let dimOverlay = UIView(frame: overlay.bounds)
        dimOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dimOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimOverlay.isUserInteractionEnabled = false
        overlay.addSubview(dimOverlay)

        // 손가락 아이콘 배치 (화면 중앙 약간 아래)
        let bounds = containerView.bounds
        overlay.fingerView.sizeToFit()
        overlay.fingerView.center = CGPoint(
            x: bounds.midX,
            y: bounds.midY + 50
        )
        overlay.fingerView.alpha = 0
        overlay.fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        overlay.addSubview(overlay.fingerView)

        // 화살표 아이콘 (Reduce Motion용 — B는 arrow.up)
        let upConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        overlay.arrowView.image = UIImage(systemName: "arrow.up", withConfiguration: upConfig)
        overlay.arrowView.center = CGPoint(
            x: bounds.midX,
            y: bounds.midY + 80
        )
        overlay.addSubview(overlay.arrowView)

        // E 스타일 카드 팝업 (blur 배경 + 텍스트 + 확인 버튼)
        overlay.buildViewerSwipeCard()

        // 0.5초 후 페이드인 + 애니메이션 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak overlay] in
            guard let overlay, !overlay.shouldStopAnimation else { return }

            UIView.animate(withDuration: 0.3) {
                overlay.alpha = 1
            } completion: { _ in
                guard !overlay.shouldStopAnimation else { return }
                if UIAccessibility.isReduceMotionEnabled {
                    overlay.showStaticVerticalGuide()
                } else {
                    overlay.startVerticalGestureLoop()
                }
            }
        }
    }

    // MARK: - B: Build Card (E 스타일 팝업)

    /// B 카드 구성: 안내 텍스트 + [확인] (E 스타일 blur 카드, 중앙 아래 배치)
    private func buildViewerSwipeCard() {
        // 카드 컨테이너 (시스템 팝업 스타일 blur 배경)
        let card = UIView()
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.frame = card.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.addSubview(blur)
        addSubview(card)

        // 안내 텍스트 ("삭제대기함" 볼드+노란색 강조)
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        let text = String(localized: "coachMark.b.body")
        let keyword = String(localized: "coachMark.b.keyword")
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: Self.bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }(),
            ]
        )
        // 키워드 볼드 + 노란색 강조 (fallback: range 미발견 시 무시)
        if let range = text.range(of: keyword) {
            let nsRange = NSRange(range, in: text)
            attributed.addAttributes([
                .font: Self.bodyBoldFont,
                .foregroundColor: Self.highlightYellow,
            ], range: nsRange)
        }
        label.attributedText = attributed
        card.addSubview(label)

        // [확인] 버튼
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = true
        confirmButton.alpha = 1
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(confirmButton)

        // 카드 레이아웃 (중앙보다 아래)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 160),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -48),

            // 내부 패딩
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            // 버튼
            confirmButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            confirmButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: Self.buttonHeight),
            confirmButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Dismiss

    /// 코치마크 dismiss
    /// - A/B/E: markAsShown 자동 호출
    /// - C: markAsShown 호출하지 않음 (present 성공 후 별도 호출)
    func dismiss() {
        guard superview != nil else { return }
        shouldStopAnimation = true
        fingerView.layer.removeAllAnimations()
        maroonView.layer.removeAllAnimations()
        snapshotView?.layer.removeAllAnimations()  // B: 진행 중 스냅샷 애니메이션 중단

        // C 타입은 markAsShown을 별도 관리 (present 성공 후 호출)
        // C-3은 dismiss 시 자동 markAsShown (화면 전환 없음)
        // D-1은 Step 4 [확인] 완료 시에만 markAsShown (중간 이탈 시 다음에 다시 표시)
        if coachMarkType != .similarPhoto && coachMarkType != .autoCleanupPreview {
            coachMarkType.markAsShown()
        }

        // C 상태 리셋
        CoachMarkManager.shared.resetC2State()

        // A-1: 스와이프 실습 모드 정리
        cleanupA1()

        // A-2: 멀티스와이프 데모 정리
        cleanupA2()
        CoachMarkManager.shared.isA2TransitionActive = false

        // D, D-1, E-1+E-2, E-3, C-3: 시퀀스 전용 리소스 정리
        cleanupAutoCleanup()
        cleanupD1()
        CoachMarkManager.shared.isD1SequenceActive = false
        cleanupDeleteGuide()
        cleanupFirstEmpty()
        cleanupFaceComparisonGuide()

        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.onDismiss?()
            self.onDismiss = nil
            // B: 풀스크린 스냅샷 메모리 즉시 해제
            self.snapshotView?.removeFromSuperview()
            self.snapshotView = nil
            self.removeFromSuperview()
        }
    }

    // MARK: - Hit Test

    /// 확인 버튼만 터치 받고, 나머지는 모두 차단
    /// (스크롤, 스와이프, 탭 등 모든 상호작용 방지)
    /// A-1: 하이라이트 영역은 터치 통과 (스와이프 허용)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // A-1: 하이라이트 영역은 터치 통과 → 아래 그리드 셀로 전달 (스와이프 가능)
        if isA1SwipeMode && highlightFrame.contains(point) {
            return nil
        }
        // 확인 버튼 영역이면 버튼에 전달 (A-1에서는 버튼 미표시 → 도달 안 함)
        let buttonPoint = confirmButton.convert(point, from: self)
        if confirmButton.bounds.contains(buttonPoint) && confirmButton.alpha > 0 {
            return confirmButton
        }
        // 나머지 터치는 오버레이가 흡수 (아래로 통과 안 함)
        return self
    }

    // MARK: - Actions

    @objc func confirmTapped() {
        switch coachMarkType {
        case .gridSwipeDelete:
            // A: onConfirm이 있으면 재생 변형 (팝업 카드) → onConfirm 호출
            if let action = onConfirm {
                action()
            } else if aCurrentStep == 1 {
                // Step 1 → Step 2 전환 (멀티스와이프 데모)
                confirmButton.isEnabled = false
                transitionToA2()
            } else if aCurrentStep == 2 {
                // Step 2 "확인" → dismiss
                dismiss()
            }
        case .viewerSwipeDelete:
            // B: 즉시 dismiss + markAsShown
            dismiss()
        case .similarPhoto:
            // C: 재진입 방지 (0.8초+ 비동기 시퀀스 — 연타 시 이중 push/present 위험)
            confirmButton.isEnabled = false
            // C 전용 시퀀스 (CoachMarkOverlayView+CoachMarkC.swift)
            startC_ConfirmSequence()
        case .autoCleanup:
            // D: 재진입 방지 → 탭 모션 (트리거 1) 또는 즉시 dismiss (트리거 2) → onConfirm
            confirmButton.isEnabled = false
            startD_ConfirmSequence()
        case .firstDeleteGuide:
            // E-1+E-2: Step 1 [확인] → 손가락 탭 모션 → 탭 전환 + 순차 텍스트, Step 3 [확인] → dismiss
            if systemFeedbackCurrentStep == 1 {
                confirmButton.isEnabled = false
                performTabTapMotionThenTransition()
            } else {
                dismiss()
            }
        case .firstEmpty:
            // E-3: 즉시 dismiss
            dismiss()
        case .faceComparisonGuide:
            // C-3: 재진입 방지 → Step 1/2 시퀀스 관리
            confirmButton.isEnabled = false
            startC3ConfirmSequence()
        case .autoCleanupPreview:
            // D-1: 재진입 방지 → 4단계 시퀀스 관리
            confirmButton.isEnabled = false
            handleD1ConfirmTapped()
        }
    }

    // MARK: - Static Guide (Reduce Motion)

    /// 애니메이션 없이 정적 안내 표시
    private func showStaticGuide() {
        // Maroon 딤드를 55% 채운 정적 상태로
        maroonView.frame.size.width = swipeDistance

        // 손가락 아이콘을 빨간딤드 우측 끝에 정지 상태로 배치
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

    /// 제스처 시연 애니메이션 루프 (삭제 → 텀 → 복원 → 텀 → 반복)
    private func startGestureLoop() {
        guard !shouldStopAnimation else { return }
        performDeleteSwipe()
    }

    // MARK: - Delete Swipe (→ 오른쪽)

    /// 삭제 스와이프 시연: 터치다운 → 누르기 → 드래그(→) → 릴리즈
    private func performDeleteSwipe() {
        guard !shouldStopAnimation else { return }

        // 1) Touch Down — 손가락 등장 (0.3초)
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

            // 2) Press — 누르기 (0.2초, spring)
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

                // 3) Drag → 오른쪽 (0.3초, cubic-bezier)
                let timing = UICubicTimingParameters(
                    controlPoint1: CGPoint(x: 0.4, y: 0.0),
                    controlPoint2: CGPoint(x: 0.2, y: 1.0)
                )
                let animator = UIViewPropertyAnimator(duration: 0.3, timingParameters: timing)
                animator.addAnimations {
                    self.fingerView.center.x += self.swipeDistance
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                        .rotated(by: .pi / 24)
                    self.maroonView.frame.size.width = self.swipeDistance
                }
                animator.addCompletion { [weak self] _ in
                    guard let self, !self.shouldStopAnimation else { return }

                    // 4) Release — 손가락만 페이드아웃 (maroon은 유지)
                    UIView.animate(
                        withDuration: 0.2,
                        delay: 0,
                        options: .curveEaseIn,
                        animations: {
                            self.fingerView.alpha = 0
                            self.fingerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                            self.fingerView.center.y -= 10
                        }
                    ) { [weak self] _ in
                        guard let self, !self.shouldStopAnimation else { return }

                        // 텀 (0.5초) → 복원 스와이프
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.performRestoreSwipe()
                        }
                    }
                }
                animator.startAnimation()
            }
        }
    }

    // MARK: - Restore Swipe (← 왼쪽)

    /// 복원 스와이프 시연: 손가락 오른쪽에서 등장 → 누르기 → 드래그(←) → 릴리즈
    private func performRestoreSwipe() {
        guard !shouldStopAnimation else { return }

        // 손가락을 오른쪽 끝(삭제 완료 위치)에 배치
        fingerView.center = CGPoint(
            x: highlightFrame.minX + swipeDistance,
            y: highlightFrame.midY
        )
        fingerView.alpha = 0
        fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        fingerView.layer.shadowOpacity = 0

        // 1) Touch Down — 손가락 등장 (0.3초)
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

            // 2) Press — 누르기 (0.2초, spring)
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

                // 3) Drag ← 왼쪽 (0.3초, cubic-bezier) — maroon 축소
                let timing = UICubicTimingParameters(
                    controlPoint1: CGPoint(x: 0.4, y: 0.0),
                    controlPoint2: CGPoint(x: 0.2, y: 1.0)
                )
                let animator = UIViewPropertyAnimator(duration: 0.3, timingParameters: timing)
                animator.addAnimations {
                    self.fingerView.center.x -= self.swipeDistance
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                        .rotated(by: -.pi / 24)
                    self.maroonView.frame.size.width = 0
                }
                animator.addCompletion { [weak self] _ in
                    guard let self, !self.shouldStopAnimation else { return }

                    // 4) Release — 손가락 페이드아웃
                    UIView.animate(
                        withDuration: 0.2,
                        delay: 0,
                        options: .curveEaseIn,
                        animations: {
                            self.fingerView.alpha = 0
                            self.fingerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                            self.fingerView.center.y -= 10
                        }
                    ) { [weak self] _ in
                        guard let self, !self.shouldStopAnimation else { return }

                        // 텀 (0.5초) → 리셋 → 다시 삭제 스와이프부터 반복
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            guard let self, !self.shouldStopAnimation else { return }
                            self.resetPositions()
                            self.startGestureLoop()
                        }
                    }
                }
                animator.startAnimation()
            }
        }
    }

    // MARK: - B: Vertical Gesture Animation Loop

    /// B: 수직 제스처 시연 루프 (3회 후 정지)
    private func startVerticalGestureLoop() {
        guard !shouldStopAnimation else { return }
        guard loopCount < Self.maxVerticalLoopCount else { return }
        loopCount += 1
        performUpSwipe()
    }

    /// B: 위로 스와이프 시연 (Touch Down → Press → Drag ↑ → Release)
    private func performUpSwipe() {
        guard !shouldStopAnimation else { return }

        // 안전 규칙: 스냅샷 로컬 변수로 캡처 (옵셔널 체이닝 사용 금지)
        guard let snapshot = snapshotView else { return }

        // 1) Touch Down — 손가락 등장 (0.3초)
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                self.fingerView.alpha = 1.0
                self.fingerView.transform = .identity
            }
        ) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }

            // 2) Press — 누르기 (0.35초, spring, "여기를 누르는구나" 인지 시간)
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0,
                options: [],
                animations: {
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                }
            ) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else { return }

                // 3) Drag ↑ — 끝까지 하나의 연속 모션 + 후반부 알파 페이드
                // 손가락과 스냅샷 이동 거리를 동일하게 (속도 일치)
                let moveDistance = Self.viewerFingerMoveDistance
                UIView.animateKeyframes(
                    withDuration: 0.7,
                    delay: 0,
                    options: [.calculationModeCubic],
                    animations: {
                        // 전체 구간: 손가락 + 스냅샷 동일 거리로 이동 (속도 일치)
                        UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1.0) {
                            self.fingerView.center.y -= moveDistance
                            self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                            snapshot.transform = CGAffineTransform(translationX: 0, y: -moveDistance)
                        }
                        // 후반 45%: 스냅샷 알파 페이드 (이동 중간부터 부드럽게 사라짐)
                        UIView.addKeyframe(withRelativeStartTime: 0.55, relativeDuration: 0.45) {
                            snapshot.alpha = 0
                        }
                    }
                ) { [weak self] _ in
                    guard let self, !self.shouldStopAnimation else { return }

                    // 4) Release — 손가락만 페이드아웃
                    UIView.animate(
                        withDuration: 0.2,
                        delay: 0,
                        options: .curveEaseIn,
                        animations: {
                            self.fingerView.alpha = 0
                            self.fingerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                            self.fingerView.center.y += 10  // 떼기 반동
                        }
                    ) { [weak self] _ in
                        guard let self, !self.shouldStopAnimation else { return }

                        // 텀 (0.8초) → 리셋
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                            self?.resetVerticalPositions()
                        }
                    }
                }
            }
        }
    }

    /// B: 스냅샷+손가락 원위치 리셋 (삭제 후 다음 사진 나타나는 효과)
    private func resetVerticalPositions() {
        guard !shouldStopAnimation else { return }
        guard let snapshot = snapshotView else { return }

        // 즉시 리셋: 스냅샷 원위치 + alpha 0 (투명 상태에서 시작)
        snapshot.transform = .identity
        snapshot.alpha = 0

        // 손가락 초기 위치로 복귀
        fingerView.center = CGPoint(
            x: bounds.midX,
            y: bounds.midY + 50
        )
        fingerView.alpha = 0
        fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)

        // 페이드인 (0.3초) — 다음 사진이 나타나는 효과
        // 0.3초로 짧아 dim(70%)과 합쳐져 원본 겹침이 거의 보이지 않음
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                snapshot.alpha = 1.0
            }
        ) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }

            // 텀 (0.8초) → 다음 루프 (3회째 완료 후 스냅샷 원위치에서 정지)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.startVerticalGestureLoop()
            }
        }
    }

    /// B: Reduce Motion 정적 안내
    private func showStaticVerticalGuide() {
        guard let snapshot = snapshotView else { return }

        // 스냅샷 위로 150pt 이동 상태
        snapshot.transform = CGAffineTransform(translationX: 0, y: -150)

        // 손가락 정지 상태
        fingerView.center = CGPoint(
            x: bounds.midX,
            y: bounds.midY - 50
        )
        fingerView.alpha = 1
        fingerView.transform = .identity

        // arrow.up 화살표 방향 표시
        arrowView.center = CGPoint(
            x: bounds.midX,
            y: bounds.midY + 80
        )
        arrowView.alpha = 0.8
    }

    // MARK: - A: Reset Positions

    /// 모든 뷰를 초기 상태로 리셋
    private func resetPositions() {
        // 손가락 위치/상태 리셋 (빨간딤드 우측 끝과 x 일치)
        fingerView.center = CGPoint(
            x: highlightFrame.minX,
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
