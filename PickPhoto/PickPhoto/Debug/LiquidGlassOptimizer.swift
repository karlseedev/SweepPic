//
//  LiquidGlassOptimizer.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-29.
//
//  Description:
//  LiquidGlassKit 성능 최적화 유틸리티
//  스크롤 중 LiquidGlass(MTKView)를 UIBlurEffect로 대체하여 성능 개선
//
//  사용법:
//  - viewDidAppear() → LiquidGlassOptimizer.preload(in: view.window)
//  - scrollDidBegin() → LiquidGlassOptimizer.optimize(in: view)
//  - scrollDidEnd() → LiquidGlassOptimizer.restore(in: view)
//

import UIKit
import MetalKit
import AppCore
// C-5: import LiquidGlassKit removed — LiquidGlassSettings no longer needed

/// LiquidGlassKit 성능 최적화 모드
enum LiquidGlassOptimizeMode {
    case normal         // 최적화 없음 (baseline)
    case paused         // isPaused = true (Test B: 병목 1+2+3 중지, 배경 프리즈)
    case blurReplacement // UIBlurEffect로 대체 (Test C: 자연스러운 블러)
}

/// LiquidGlassKit 성능 최적화 유틸리티
enum LiquidGlassOptimizer {

    // MARK: - Configuration

    /// 현재 최적화 모드 (테스트용)
    /// - normal: 최적화 없음
    /// - paused: 스크롤 중 isPaused (배경 프리즈)
    /// - blurReplacement: 스크롤 중 UIBlurEffect 대체 (자연스러운 블러)
    static var mode: LiquidGlassOptimizeMode = .normal

    /// 최적화 활성화 여부
    static var isEnabled: Bool = true

    /// 블러 강도 (0.0~1.0, UIViewPropertyAnimator.fractionComplete로 제어)
    /// alpha 대신 사용 — UIVisualEffectView alpha < 1.0이면 블러 렌더링 깨짐 (Apple 제한)
    static var blurIntensity: CGFloat = 0.1

    /// 전환 애니메이션 시간 (초)
    private static let transitionDuration: TimeInterval = 0.1

    // MARK: - Preloaded Storage

    /// 사전 생성된 블러 오버레이 저장
    /// key: MTKView의 ObjectIdentifier
    /// value: (blurView, mtkView weak reference, originalAlpha)
    private static var preloadedOverlays: [ObjectIdentifier: PreloadedOverlay] = [:]

    /// Preloaded overlay 정보
    private struct PreloadedOverlay {
        let blurView: UIVisualEffectView
        let blurAnimator: UIViewPropertyAnimator  // 블러 강도 제어용 (fractionComplete)
        weak var mtkView: MTKView?
        var originalAlpha: CGFloat
    }

    // MARK: - Public Methods

    /// 블러 뷰 사전 생성 (viewDidAppear에서 호출)
    /// - Note: 새로운 MTKView만 추가 (incremental preload)
    /// - Parameter rootView: 탐색 시작 뷰 (보통 window)
    static func preload(in rootView: UIView?) {
        guard isEnabled else { return }
        guard let rootView = rootView else { return }

        // C-5 fix: 해제된 MTKView의 고아 엔트리 정리
        // ObjectIdentifier 충돌 방지 (메모리 재사용 시 새 MTKView가 블러 오버레이를 못 받는 버그)
        cleanupOrphanedOverlays()

        // blur 뷰 생성: blurReplacement 또는 normal 모드 (C-5)
        guard mode == .blurReplacement || mode == .normal else { return }

        let mtkViews = findAllMTKViews(in: rootView)
        var newCount = 0

        for mtkView in mtkViews {
            let identifier = ObjectIdentifier(mtkView)

            // 이미 있으면 프레임만 동기화
            if let existing = preloadedOverlays[identifier] {
                existing.blurView.frame = mtkView.frame
                continue
            }

            // 부모 뷰 확인
            guard let superview = mtkView.superview else { continue }

            // SelectionPill 내부 MTKView는 블러 제외 (자체 배경색 사용)
            if isInsideSelectionPill(mtkView) { continue }

            // 블러 뷰 생성 (animator로 강도 제어)
            let (blurView, blurAnimator) = createBlurView(matching: mtkView)

            // C-5 상시: 블러 뷰를 MTKView 바로 아래에 삽입 (즉시 보임)
            // alpha는 항상 1.0 유지 (Apple 제한), 강도는 animator.fractionComplete로 제어
            superview.insertSubview(blurView, belowSubview: mtkView)

            preloadedOverlays[identifier] = PreloadedOverlay(
                blurView: blurView,
                blurAnimator: blurAnimator,
                mtkView: mtkView,
                originalAlpha: mtkView.alpha
            )
            newCount += 1

            // DEBUG: 각 MTKView 프레임 로그
            Log.print("[LiquidGlass] NEW overlay: frame=\(mtkView.frame), superview=\(type(of: superview)), sv.frame=\(superview.frame)")
        }

        Log.print("[LiquidGlass] Blur preload: new=\(newCount), total=\(preloadedOverlays.count), found=\(mtkViews.count)")
    }

    /// 스크롤 시작 시 최적화 적용
    /// - Parameter rootView: 탐색 시작 뷰 (보통 window)
    static func optimize(in rootView: UIView?) {
        guard isEnabled else { return }
        guard let rootView = rootView else { return }

        switch mode {
        case .normal:
            // idle에서 pause된 MTKView를 resume (LiquidGlass 렌더링 재개)
            resumeAllMTKViews(in: rootView)

        case .paused:
            pauseAllMTKViews(in: rootView)

        case .blurReplacement:
            // 새로운 MTKView가 있으면 추가 (incremental)
            preload(in: rootView)
            showBlurOverlays()
        }
    }

    /// 스크롤 종료 시 최적화 해제
    /// - Parameter rootView: 탐색 시작 뷰
    static func restore(in rootView: UIView?) {
        guard isEnabled else { return }
        guard let rootView = rootView else { return }

        switch mode {
        case .normal:
            break  // C-5 상시: enterIdle()이 pause 담당

        case .paused:
            resumeAllMTKViews(in: rootView)

        case .blurReplacement:
            hideBlurOverlays()
        }
    }

    /// Preload된 블러 뷰 정리 (뷰 컨트롤러 해제 시)
    static func cleanup() {
        for (_, overlay) in preloadedOverlays {
            overlay.blurView.removeFromSuperview()
        }
        preloadedOverlays.removeAll()
        Log.print("[LiquidGlass] Blur cleanup 완료")
    }

    // MARK: - Test B: Pause Mode

    private static func pauseAllMTKViews(in rootView: UIView) {
        let mtkViews = findAllMTKViews(in: rootView)
        for mtkView in mtkViews {
            mtkView.isPaused = true
        }
        Log.print("[LiquidGlass] MTKView paused: \(mtkViews.count)개")
    }

    private static func resumeAllMTKViews(in rootView: UIView) {
        let mtkViews = findAllMTKViews(in: rootView)
        for mtkView in mtkViews {
            mtkView.isPaused = false
        }
        Log.print("[LiquidGlass] MTKView resumed: \(mtkViews.count)개")
    }

    // MARK: - Test C: Blur Replacement Mode (Preloaded)

    /// 사전 생성된 블러 오버레이 보이기 (스크롤 시작)
    /// 방안 D: 즉시 isPaused + 단일 애니메이션
    private static func showBlurOverlays() {
        // 0단계: mtkView가 nil인 orphaned 항목 정리
        cleanupOrphanedOverlays()

        var count = 0
        var blurViewsToAnimate: [UIVisualEffectView] = []

        // 1단계: 모든 MTKView 즉시 정지 (렌더링 즉시 중단)
        for (_, overlay) in preloadedOverlays {
            guard let mtkView = overlay.mtkView else { continue }

            // 이미 보이는 상태면 스킵
            guard overlay.blurView.alpha == 0 else { continue }

            // 프레임 동기화
            overlay.blurView.frame = mtkView.frame

            // 즉시 isPaused 설정 (렌더링 즉시 중단)
            mtkView.isPaused = true
            mtkView.alpha = 0

            blurViewsToAnimate.append(overlay.blurView)
            count += 1
        }

        // 2단계: 블러 뷰만 단일 애니메이션으로 fade in
        // alpha는 항상 1.0 유지, 강도는 이미 animator.fractionComplete로 설정됨
        if !blurViewsToAnimate.isEmpty {
            UIView.animate(withDuration: transitionDuration) {
                for blurView in blurViewsToAnimate {
                    blurView.alpha = 1.0
                }
            }
        }

        Log.print("[LiquidGlass] Blur show: \(count)개")
    }

    /// 사전 생성된 블러 오버레이 숨기기 (스크롤 종료)
    /// MTKView를 숨긴 채 렌더링 재개 → 새 프레임 준비 후 크로스페이드
    private static func hideBlurOverlays() {
        var count = 0
        var viewsToAnimate: [(mtkView: MTKView, blurView: UIVisualEffectView, originalAlpha: CGFloat)] = []

        // 1단계: 모든 MTKView 렌더링 재개 (alpha 0 유지 → 보이지 않음)
        // showBlurOverlays()에서 mtkView.alpha = 0으로 설정됨, 그대로 유지
        for (_, overlay) in preloadedOverlays {
            guard let mtkView = overlay.mtkView else { continue }

            // 이미 숨긴 상태면 스킵
            guard overlay.blurView.alpha > 0 else { continue }

            // isPaused 해제 (새 프레임 렌더링 시작, alpha 0이므로 보이지 않음)
            mtkView.isPaused = false

            viewsToAnimate.append((mtkView, overlay.blurView, overlay.originalAlpha))
            count += 1
        }

        // 2단계: 새 프레임 렌더링 대기 후 크로스페이드
        // drawHierarchy() + blur + Metal shader 파이프라인 소요 시간 고려
        // MTKView fade in + blur fade out 동시 진행으로 옛 배경 노출 방지
        if !viewsToAnimate.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UIView.animate(withDuration: transitionDuration) {
                    for item in viewsToAnimate {
                        item.mtkView.alpha = item.originalAlpha
                        item.blurView.alpha = 0
                    }
                }
            }
        }

        Log.print("[LiquidGlass] Blur hide: \(count)개")
    }

    // C-5: showBlurOverlaysForC5/hideBlurOverlaysForC5 removed — blur is always visible.

    // MARK: - Helper Methods

    /// mtkView가 nil인 orphaned 항목 정리
    /// - Viewer 닫힘 등으로 MTKView가 dealloc되면 weak reference가 nil이 됨
    /// - 해당 blurView도 제거하고 딕셔너리에서 삭제
    private static func cleanupOrphanedOverlays() {
        var orphanedKeys: [ObjectIdentifier] = []

        for (identifier, overlay) in preloadedOverlays {
            if overlay.mtkView == nil {
                // blurView가 아직 superview에 있으면 제거
                overlay.blurView.removeFromSuperview()
                orphanedKeys.append(identifier)
            }
        }

        for key in orphanedKeys {
            preloadedOverlays.removeValue(forKey: key)
        }

        if !orphanedKeys.isEmpty {
            Log.print("[LiquidGlass] Orphaned cleanup: \(orphanedKeys.count)개 제거 (남은: \(preloadedOverlays.count)개)")
        }
    }

    /// MTKView와 동일한 모양의 블러 뷰 생성
    /// UIViewPropertyAnimator로 블러 강도 제어 (alpha 대신 — Apple 제한 우회)
    private static func createBlurView(matching mtkView: MTKView) -> (UIVisualEffectView, UIViewPropertyAnimator) {
        // effect: nil로 시작 → animator가 블러 강도를 fractionComplete로 제어
        let blurView = UIVisualEffectView(effect: nil)

        blurView.frame = mtkView.frame
        blurView.layer.cornerRadius = mtkView.layer.cornerRadius
        blurView.layer.cornerCurve = mtkView.layer.cornerCurve
        blurView.clipsToBounds = true

        // 부모 뷰의 cornerRadius 확인
        if blurView.layer.cornerRadius == 0, let parent = mtkView.superview {
            blurView.layer.cornerRadius = parent.layer.cornerRadius
            blurView.layer.cornerCurve = parent.layer.cornerCurve
        }

        // C-5: tint 오버레이 (현재 0% — 블러 확인 후 조정)
        let tintOverlay = UIView()
        tintOverlay.backgroundColor = UIColor(white: 0.25, alpha: 0.2)
        tintOverlay.frame = blurView.bounds
        tintOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.addSubview(tintOverlay)

        // UIViewPropertyAnimator로 블러 강도 제어
        // alpha를 건드리지 않으므로 블러 렌더링이 정상 작동
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
            blurView.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        animator.fractionComplete = blurIntensity
        animator.pausesOnCompletion = true

        return (blurView, animator)
    }

    /// MTKView가 SelectionPill 내부에 있는지 확인
    private static func isInsideSelectionPill(_ view: UIView) -> Bool {
        var current: UIView? = view.superview
        while let parent = current {
            if parent is LiquidGlassSelectionPill { return true }
            current = parent.superview
        }
        return false
    }

    /// 뷰 계층에서 모든 MTKView 찾기 (재귀 탐색)
    /// Phase 1.1 등 외부에서도 사용 가능하도록 internal 접근 수준
    static func findAllMTKViews(in view: UIView) -> [MTKView] {
        var result: [MTKView] = []

        if let mtkView = view as? MTKView {
            result.append(mtkView)
        }

        for subview in view.subviews {
            result.append(contentsOf: findAllMTKViews(in: subview))
        }

        return result
    }

    // MARK: - Phase 4: Idle Pause

    /// idle pause 딜레이 (restore 완료 대기)
    /// restore()의 0.15s delay + transitionDuration 0.1s + 렌더링 여유 = 0.4s
    private static let idleDelay: TimeInterval = 0.4

    /// idle 타이머 (중복 방지)
    private static var idleTimer: DispatchWorkItem?

    /// 정지 상태 진입 (스크롤/인터랙션 종료 시 호출)
    /// idleDelay 후 모든 MTKView를 pause하여 GPU 사용량 0으로 만듦
    /// - Parameter rootView: 탐색 시작 뷰 (보통 window)
    static func enterIdle(in rootView: UIView?) {
        guard isEnabled else { return }

        // 기존 타이머 취소 (중복 방지)
        idleTimer?.cancel()

        let workItem = DispatchWorkItem {
            guard let rootView = rootView else { return }
            for mtkView in findAllMTKViews(in: rootView) {
                mtkView.isPaused = true
            }
            logMTKViewStatus(in: rootView, label: "Idle")
        }
        idleTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + idleDelay, execute: workItem)
    }

    /// idle 타이머 취소 (스크롤/인터랙션 시작 시 호출)
    /// MTKView resume은 Optimizer.restore()가 담당하므로 여기서는 타이머만 취소
    static func cancelIdleTimer() {
        idleTimer?.cancel()
        idleTimer = nil
    }

    // MARK: - MTKView Pause/Resume 유틸리티

    /// 특정 뷰 내부의 모든 MTKView isPaused 일괄 설정
    /// Phase 1.1, Phase 2 등에서 개별 컴포넌트의 MTKView 관리에 사용
    static func setMTKViewsPaused(_ paused: Bool, in view: UIView) {
        for mtkView in findAllMTKViews(in: view) {
            mtkView.isPaused = paused
        }
    }

    /// 진단: 전체 MTKView 상태 로그
    /// 각 Phase 적용 전후에 호출하여 active/paused 수치 변화 확인
    static func logMTKViewStatus(in rootView: UIView?, label: String) {
        guard let rootView = rootView else { return }
        let all = findAllMTKViews(in: rootView)
        let active = all.filter { !$0.isPaused }.count
        let paused = all.count - active
        Log.print("[LiquidGlass] Status(\(label)): active=\(active), paused=\(paused), total=\(all.count)")
    }

    // MARK: - Legacy API (호환성)

    static func pauseAllMTKViews(in rootView: UIView?) {
        guard let rootView = rootView else { return }
        pauseAllMTKViews(in: rootView)
    }

    static func resumeAllMTKViews(in rootView: UIView?) {
        guard let rootView = rootView else { return }
        resumeAllMTKViews(in: rootView)
    }
}
