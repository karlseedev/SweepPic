//
//  LiquidGlassSettings.swift
//  LiquidGlassKit
//
//  Description:
//  LiquidGlassKit 전역 렌더링 설정.
//  C-5: 배경 캡처 제거됨 — captureInterval, freezeCapture 모두 불필요.
//

/// LiquidGlassKit 전역 렌더링 설정
/// C-5: 배경 캡처 완전 제거. 현재 설정 항목 없음.
/// 향후 필요 시 새 설정을 여기에 추가.
public enum LiquidGlassSettings {
    // C-5: captureInterval, freezeCapture removed.
    // Background capture is permanently disabled.
    // UIVisualEffectView provides blur behind MTKView.
}
