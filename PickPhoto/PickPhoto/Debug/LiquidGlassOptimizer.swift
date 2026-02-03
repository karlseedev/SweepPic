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

    /// 블러 뷰 alpha 값 (스크롤 중)
    static var blurAlpha: CGFloat = 0.2

    /// MTKView fps 제한 (Phase 3)
    /// 기본값 30: 120fps 기기에서 75% GPU 감소, 60fps 기기에서 50% 감소
    /// Glass 효과는 배경 굴절이므로 높은 fps 불필요
    static var preferredFPS: Int = 30

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

        // Phase 3: FPS 제한은 mode에 무관하게 항상 적용
        let mtkViews = findAllMTKViews(in: rootView)
        for mtkView in mtkViews {
            mtkView.preferredFramesPerSecond = preferredFPS
        }
        Log.print("[LiquidGlass] FPS limit: \(preferredFPS)fps → \(mtkViews.count)개 MTKView")

        // blur 뷰 생성은 blurReplacement 모드에서만
        guard mode == .blurReplacement else { return }

        var newCount = 0

        for mtkView in mtkViews {
            let identifier = ObjectIdentifier(mtkView)

            // 이미 있으면 스킵
            guard preloadedOverlays[identifier] == nil else { continue }

            // 부모 뷰 확인
            guard let superview = mtkView.superview else { continue }

            // 블러 뷰 생성
            let blurView = createBlurView(matching: mtkView)

            // 블러 뷰를 MTKView 바로 아래에 삽입 (숨긴 상태)
            blurView.alpha = 0
            superview.insertSubview(blurView, belowSubview: mtkView)

            preloadedOverlays[identifier] = PreloadedOverlay(
                blurView: blurView,
                mtkView: mtkView,
                originalAlpha: mtkView.alpha
            )
            newCount += 1
        }

        if newCount > 0 {
            Log.print("[LiquidGlass] Blur preload: +\(newCount)개 (총 \(preloadedOverlays.count)개)")
        }
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
            break  // enterIdle()이 pause 담당

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
        if !blurViewsToAnimate.isEmpty {
            UIView.animate(withDuration: transitionDuration) {
                for blurView in blurViewsToAnimate {
                    blurView.alpha = blurAlpha
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
    /// LiquidGlass 원본과 최대한 유사하게 tintColor 오버레이 포함
    private static func createBlurView(matching mtkView: MTKView) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)

        blurView.frame = mtkView.frame
        blurView.layer.cornerRadius = mtkView.layer.cornerRadius
        blurView.layer.cornerCurve = mtkView.layer.cornerCurve
        blurView.clipsToBounds = true

        // 부모 뷰의 cornerRadius 확인
        if blurView.layer.cornerRadius == 0, let parent = mtkView.superview {
            blurView.layer.cornerRadius = parent.layer.cornerRadius
            blurView.layer.cornerCurve = parent.layer.cornerCurve
        }

        // LiquidGlass tintColor와 동일한 회색 오버레이 추가
        // GlassIconButton: UIColor(white: 0.5, alpha: 0.2)
        let tintOverlay = UIView()
        tintOverlay.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
        tintOverlay.frame = blurView.bounds
        tintOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.addSubview(tintOverlay)

        // LiquidGlass 스타일 테두리 (흰색 1px, alpha 0.7)
        blurView.layer.borderWidth = 2.0 / UIScreen.main.scale
        blurView.layer.borderColor = UIColor(white: 1.0, alpha: 0.8).cgColor

        return blurView
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

    // MARK: - Phase 3: FPS 제한

    /// 모든 MTKView에 fps 제한 적용 (Phase 3)
    /// preload()를 거치지 않는 시점에서도 독립적으로 호출 가능
    /// - Parameter rootView: 탐색 시작 뷰 (보통 window)
    static func applyFPSLimit(in rootView: UIView?) {
        guard let rootView = rootView else { return }
        let mtkViews = findAllMTKViews(in: rootView)
        for mtkView in mtkViews {
            mtkView.preferredFramesPerSecond = preferredFPS
        }
        Log.print("[LiquidGlass] FPS limit applied: \(preferredFPS)fps to \(mtkViews.count)개 MTKView")
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
