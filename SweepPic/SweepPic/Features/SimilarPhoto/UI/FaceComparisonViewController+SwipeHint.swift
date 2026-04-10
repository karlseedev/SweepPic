//
//  FaceComparisonViewController+SwipeHint.swift
//  SweepPic
//
//  Created by Claude Code on 2026-04-10.
//
//  Edge 화살표 스와이프 힌트
//  - 인물 비교 화면에서 좌우 스와이프로 인물 전환이 가능함을 시각적으로 암시
//  - 화면 좌우 가장자리에 chevron 화살표를 표시
//
//  노출 조건:
//    1. 인물 2명 이상
//    2. viewer 모드: C-3 코치마크 완료 후에만 (온보딩 중 미노출)
//       faceScan 모드: C-3 게이트 없음 (C-3은 viewer에서만 표시되므로)
//    3. 스와이프 경험 없음 → 매 진입마다 노출
//    4. 스와이프 경험 후 → 2회 재진입까지 노출, 이후 미노출
//
//  동작:
//    - 스와이프 완료 (didFinishAnimating) → 페이드아웃 + 경험 기록
//    - 순환 버튼 탭 → 화살표 유지, 상태 변화 없음
//

import UIKit
import ObjectiveC
import OSLog
import AppCore

// MARK: - Associated Object Keys

private var swipeHintLeftKey: UInt8 = 0
private var swipeHintRightKey: UInt8 = 0

// MARK: - UserDefaults Keys

private enum SwipeHintDefaults {
    static let hasEverSwipedKey = "faceComparison_hasEverSwiped"
    static let postSwipeHintCountKey = "faceComparison_postSwipeHintCount"

    static var hasEverSwiped: Bool {
        UserDefaults.standard.bool(forKey: hasEverSwipedKey)
    }

    static var postSwipeHintCount: Int {
        UserDefaults.standard.integer(forKey: postSwipeHintCountKey)
    }

    static func setHasEverSwiped() {
        UserDefaults.standard.set(true, forKey: hasEverSwipedKey)
    }

    static func incrementPostSwipeHintCount() {
        let current = postSwipeHintCount
        UserDefaults.standard.set(current + 1, forKey: postSwipeHintCountKey)
    }
}

// MARK: - Swipe Hint Extension

extension FaceComparisonViewController {

    // MARK: - Associated Properties

    /// 좌측 화살표 힌트 뷰
    private var swipeHintLeft: UIImageView? {
        get { objc_getAssociatedObject(self, &swipeHintLeftKey) as? UIImageView }
        set { objc_setAssociatedObject(self, &swipeHintLeftKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 우측 화살표 힌트 뷰
    private var swipeHintRight: UIImageView? {
        get { objc_getAssociatedObject(self, &swipeHintRightKey) as? UIImageView }
        set { objc_setAssociatedObject(self, &swipeHintRightKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Public Methods

    /// 스와이프 힌트 화살표 표시 (조건 충족 시)
    /// setupInitialPageIfReady()에서 호출됩니다.
    func showSwipeHintIfNeeded() {
        // ⚠️ 임시 초기화 (테스트 후 제거)
        UserDefaults.standard.removeObject(forKey: SwipeHintDefaults.hasEverSwipedKey)
        UserDefaults.standard.removeObject(forKey: SwipeHintDefaults.postSwipeHintCountKey)

        // ⚠️ 임시 로그 (테스트 후 제거)
        Logger.app.debug("[SwipeHint] showSwipeHintIfNeeded 호출됨, swipeHintLeft=\(self.swipeHintLeft == nil ? "nil" : "exists"), personCount=\(self.validPersonIndices.count), isFaceScan=\(self.mode.isFaceScan), hasEverSwiped=\(SwipeHintDefaults.hasEverSwiped), postCount=\(SwipeHintDefaults.postSwipeHintCount)")

        // 멱등성: 이미 표시 중이면 중복 생성하지 않음
        guard swipeHintLeft == nil else {
            Logger.app.debug("[SwipeHint] ❌ 이미 표시 중 → return")
            return
        }

        // 조건 1: 인물 2명 이상
        guard validPersonIndices.count > 1 else {
            Logger.app.debug("[SwipeHint] ❌ 인물 1명 → return")
            return
        }

        // 조건 2: viewer 모드에서는 C-3 코치마크 완료 후에만
        // (faceScan 모드에서는 C-3 게이트 없음)
        if !mode.isFaceScan {
            guard CoachMarkType.faceComparisonGuide.hasBeenShown else {
                Logger.app.debug("[SwipeHint] ❌ C-3 미완료 (viewer) → return")
                return
            }
        }

        // 조건 3-4: 스와이프 경험 기반 판단
        let hasEverSwiped = SwipeHintDefaults.hasEverSwiped
        if hasEverSwiped {
            // 스와이프 경험 후: 2회까지만 노출
            guard SwipeHintDefaults.postSwipeHintCount < 2 else {
                Logger.app.debug("[SwipeHint] ❌ 노출 횟수 소진 → return")
                return
            }
            // count++는 실제 힌트 표시 직후 1회만
            SwipeHintDefaults.incrementPostSwipeHintCount()
        }
        // hasEverSwiped == false: 무조건 노출 (count 무시)

        Logger.app.debug("[SwipeHint] ✅ 화살표 표시")

        // 화살표 생성 및 표시
        let left = makeHintArrow(systemName: "chevron.left.circle.fill")
        let right = makeHintArrow(systemName: "chevron.right.circle.fill")

        view.addSubview(left)
        view.addSubview(right)

        NSLayoutConstraint.activate([
            // 좌측: 가장자리에서 8pt, safeArea 세로 중앙
            left.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            left.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),

            // 우측: 가장자리에서 8pt, safeArea 세로 중앙
            right.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            right.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])

        swipeHintLeft = left
        swipeHintRight = right

        // 펄스 애니메이션 (Reduce Motion 시 정적 표시)
        if !UIAccessibility.isReduceMotionEnabled {
            startPulseAnimation(for: left)
            startPulseAnimation(for: right)
        }
    }

    /// 스와이프 힌트 화살표 숨기기
    /// - Parameter animated: 페이드아웃 애니메이션 여부
    func hideSwipeHint(animated: Bool) {
        guard let left = swipeHintLeft, let right = swipeHintRight else { return }

        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                left.alpha = 0
                right.alpha = 0
            }, completion: { _ in
                left.removeFromSuperview()
                right.removeFromSuperview()
            })
        } else {
            left.removeFromSuperview()
            right.removeFromSuperview()
        }

        swipeHintLeft = nil
        swipeHintRight = nil
    }

    /// 스와이프 경험 기록 + 힌트 숨기기
    /// didFinishAnimating(completed==true)에서 호출됩니다.
    func markSwipeExperienced() {
        // 스와이프 경험 저장 (최초 1회만 의미 있음)
        if !SwipeHintDefaults.hasEverSwiped {
            SwipeHintDefaults.setHasEverSwiped()
        }

        // 화살표 페���드아웃
        hideSwipeHint(animated: true)
    }

    // MARK: - Private Helpers

    /// 힌트 화살표 UIImageView 생성
    private func makeHintArrow(systemName: String) -> UIImageView {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        let image = UIImage(systemName: systemName, withConfiguration: config)

        let imageView = UIImageView(image: image)
        imageView.tintColor = UIColor.white.withAlphaComponent(0.9)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        return imageView
    }

    /// 펄스 애니메이션 시작 (alpha 0.9 ↔ 0.5 반복)
    private func startPulseAnimation(for view: UIView) {
        view.alpha = 0.9
        UIView.animate(
            withDuration: 1.2,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut],
            animations: {
                view.alpha = 0.5
            }
        )
    }
}
