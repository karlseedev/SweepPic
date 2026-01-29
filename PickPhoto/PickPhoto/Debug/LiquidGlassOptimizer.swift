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

#if DEBUG
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
    static var mode: LiquidGlassOptimizeMode = .blurReplacement

    /// 최적화 활성화 여부
    static var isEnabled: Bool = true

    /// 블러 뷰 alpha 값 (스크롤 중)
    static var blurAlpha: CGFloat = 0.2

    /// 전환 애니메이션 시간 (초)
    private static let transitionDuration: TimeInterval = 0.1

    // MARK: - Preloaded Storage

    /// 사전 생성된 블러 오버레이 저장
    /// key: MTKView의 ObjectIdentifier
    /// value: (blurView, mtkView weak reference, originalAlpha)
    private static var preloadedOverlays: [ObjectIdentifier: PreloadedOverlay] = [:]

    /// Preload 완료 여부
    private static var isPreloaded: Bool = false

    /// Preloaded overlay 정보
    private struct PreloadedOverlay {
        let blurView: UIVisualEffectView
        weak var mtkView: MTKView?
        var originalAlpha: CGFloat
    }

    // MARK: - Public Methods

    /// 블러 뷰 사전 생성 (viewDidAppear에서 한 번만 호출)
    /// - Parameter rootView: 탐색 시작 뷰 (보통 window)
    static func preload(in rootView: UIView?) {
        guard isEnabled, mode == .blurReplacement else { return }
        guard let rootView = rootView else { return }
        guard !isPreloaded else {
            Log.print("[LiquidGlass] Blur preload: 이미 완료됨")
            return
        }

        let mtkViews = findAllMTKViews(in: rootView)

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

            // 저장
            preloadedOverlays[identifier] = PreloadedOverlay(
                blurView: blurView,
                mtkView: mtkView,
                originalAlpha: mtkView.alpha
            )
        }

        isPreloaded = true
        Log.print("[LiquidGlass] Blur preload 완료: \(mtkViews.count)개")
    }

    /// 스크롤 시작 시 최적화 적용
    /// - Parameter rootView: 탐색 시작 뷰 (보통 window)
    static func optimize(in rootView: UIView?) {
        guard isEnabled else { return }
        guard let rootView = rootView else { return }

        switch mode {
        case .normal:
            break

        case .paused:
            pauseAllMTKViews(in: rootView)

        case .blurReplacement:
            // Preload 안 됐으면 먼저 preload
            if !isPreloaded {
                preload(in: rootView)
            }
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
            break

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
        isPreloaded = false
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
    /// 방안 E: 애니메이션 완전 제거
    private static func showBlurOverlays() {
        var count = 0

        for (_, overlay) in preloadedOverlays {
            guard let mtkView = overlay.mtkView else { continue }

            // 이미 보이는 상태면 스킵
            guard overlay.blurView.alpha == 0 else { continue }

            // 프레임 동기화
            overlay.blurView.frame = mtkView.frame

            // 즉시 전환 (애니메이션 없음)
            mtkView.isPaused = true
            mtkView.alpha = 0
            overlay.blurView.alpha = blurAlpha

            count += 1
        }

        Log.print("[LiquidGlass] Blur show: \(count)개")
    }

    /// 사전 생성된 블러 오버레이 숨기기 (스크롤 종료)
    /// 방안 E: 애니메이션 완전 제거
    private static func hideBlurOverlays() {
        var count = 0

        for (_, overlay) in preloadedOverlays {
            guard let mtkView = overlay.mtkView else { continue }

            // 이미 숨긴 상태면 스킵
            guard overlay.blurView.alpha > 0 else { continue }

            // 즉시 전환 (애니메이션 없음)
            mtkView.isPaused = false
            mtkView.alpha = overlay.originalAlpha
            overlay.blurView.alpha = 0

            count += 1
        }

        Log.print("[LiquidGlass] Blur hide: \(count)개")
    }

    // MARK: - Helper Methods

    /// MTKView와 동일한 모양의 블러 뷰 생성
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

        return blurView
    }

    /// 뷰 계층에서 모든 MTKView 찾기 (재귀 탐색)
    private static func findAllMTKViews(in view: UIView) -> [MTKView] {
        var result: [MTKView] = []

        if let mtkView = view as? MTKView {
            result.append(mtkView)
        }

        for subview in view.subviews {
            result.append(contentsOf: findAllMTKViews(in: subview))
        }

        return result
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
#endif
