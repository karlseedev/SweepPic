//
//  LiquidGlassSettings.swift
//  LiquidGlassKit
//
//  Description:
//  LiquidGlassKit 전역 렌더링 설정.
//  앱에서 import LiquidGlassKit 후 직접 접근하여 렌더링 파라미터를 동적 제어.
//

/// LiquidGlassKit 전역 렌더링 설정
/// - captureInterval: 배경 캡처 주기 (1=매 프레임, 3=3프레임마다 1회)
public enum LiquidGlassSettings {

    /// 배경 캡처 주기.
    /// 1이면 매 프레임 캡처 (기본값, 최고 품질).
    /// N이면 N프레임마다 1회 캡처 — 나머지 프레임은 이전 텍스처 재사용.
    /// 스크롤 중 3으로 설정하면 CPU captureBackground() 비용 66% 절감.
    /// draw()와 Optimizer 모두 메인 스레드에서 접근 — nonisolated(unsafe)로 안전
    public nonisolated(unsafe) static var captureInterval: Int = 1

    /// C-5: Freeze background capture.
    /// When true, captureBackground() is skipped and a transparent fallback texture is used.
    /// The shader renders only SDF shape + tint + boundary AA over the UIVisualEffectView below.
    /// Accessed from main thread only — nonisolated(unsafe) safe.
    public nonisolated(unsafe) static var freezeCapture: Bool = true
}
