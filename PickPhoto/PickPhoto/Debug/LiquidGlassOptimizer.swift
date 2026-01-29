//
//  LiquidGlassOptimizer.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-29.
//
//  Description:
//  LiquidGlassKit 성능 최적화 유틸리티
//  스크롤 중 MTKView의 isPaused를 제어하여 성능 개선
//
//  사용법:
//  - scrollDidBegin() → LiquidGlassOptimizer.pauseAllMTKViews(in: view)
//  - scrollDidEnd() → LiquidGlassOptimizer.resumeAllMTKViews(in: view)
//

#if DEBUG
import UIKit
import MetalKit
import AppCore

/// LiquidGlassKit 성능 최적화 모드
enum LiquidGlassOptimizeMode {
    case normal      // 최적화 없음 (baseline)
    case paused      // isPaused = true (Test B: 병목 1+2+3 중지)
    // case noCapture // autoCapture = false (Test A: 라이브러리 수정 필요)
}

/// LiquidGlassKit 성능 최적화 유틸리티
enum LiquidGlassOptimizer {

    // MARK: - Configuration

    /// 현재 최적화 모드 (테스트용)
    /// normal: 최적화 없음, paused: 스크롤 중 isPaused
    static var mode: LiquidGlassOptimizeMode = .paused

    /// 최적화 활성화 여부
    static var isEnabled: Bool = true

    // MARK: - Public Methods

    /// 뷰 계층의 모든 MTKView를 일시정지
    /// - Parameter rootView: 탐색 시작 뷰 (보통 window 또는 viewController.view)
    static func pauseAllMTKViews(in rootView: UIView?) {
        guard isEnabled, mode == .paused else { return }
        guard let rootView = rootView else { return }

        let mtkViews = findAllMTKViews(in: rootView)
        for mtkView in mtkViews {
            mtkView.isPaused = true
        }

        Log.debug("Performance", "MTKView paused: \(mtkViews.count)개")
    }

    /// 뷰 계층의 모든 MTKView를 재개
    /// - Parameter rootView: 탐색 시작 뷰
    static func resumeAllMTKViews(in rootView: UIView?) {
        guard isEnabled, mode == .paused else { return }
        guard let rootView = rootView else { return }

        let mtkViews = findAllMTKViews(in: rootView)
        for mtkView in mtkViews {
            mtkView.isPaused = false
        }

        Log.debug("Performance", "MTKView resumed: \(mtkViews.count)개")
    }

    // MARK: - Private Methods

    /// 뷰 계층에서 모든 MTKView 찾기 (재귀 탐색)
    /// - Parameter view: 탐색 시작 뷰
    /// - Returns: MTKView 배열
    private static func findAllMTKViews(in view: UIView) -> [MTKView] {
        var result: [MTKView] = []

        // 현재 뷰가 MTKView인지 확인
        if let mtkView = view as? MTKView {
            result.append(mtkView)
        }

        // 서브뷰 재귀 탐색
        for subview in view.subviews {
            result.append(contentsOf: findAllMTKViews(in: subview))
        }

        return result
    }
}
#endif
