//
//  RenderABTest.swift
//  PickPhoto
//
//  Description: Render hitch 원인 분석용 A/B 테스트
//               스크롤 시작 시 테스트 조건을 적용하고,
//               HitchMonitor 결과와 함께 어떤 조건인지 로그한다.
//               docs/260210gridPerfor1.md 참고
//
//  사용법:
//    1) RenderABTest.activeTest를 변경 (코드 또는 lldb)
//    2) 스크롤 → [Hitch] 로그에 테스트명이 함께 출력
//    3) .baseline으로 돌려서 대조군 측정
//    4) 결과 비교
//

#if DEBUG

import UIKit
import AppCore
import OSLog

/// Render hitch A/B 테스트 도구
/// 각 테스트 케이스는 스크롤 시작 시 적용, 종료 시 복원
enum RenderABTest {

    // MARK: - Test Cases

    /// 테스트 조건 정의
    enum TestCase: String, CaseIterable {
        /// 아무것도 변경하지 않은 기준선
        case baseline = "BASELINE"

        /// FloatingOverlayContainer 전체 숨김
        /// → 효과형 부담 (BACKDROP×5, METAL×3, shadow×5) 측정
        case floatingUIHidden = "FloatingUI OFF"

        /// 셀 UIImageView.isOpaque = true
        /// → !opaque 블렌딩 비용 측정
        case cellsOpaque = "Cells isOpaque=true"

        /// shadow(path=false) 항목에 shadowPath 추가
        /// → offscreen shadow 렌더 비용 측정
        case shadowPathFix = "Shadow path=true"

        // --- FloatingUI 내부 분해 테스트 ---

        /// FloatingUI 내 LiquidGlass 효과만 OFF
        /// → LiquidGlassEffectView 숨김 (METAL×3, BACKDROP×4 제거)
        /// → SelectionPill BackdropView도 숨김
        case glassEffectOff = "Glass OFF"

        /// FloatingUI 내 VariableBlurView만 OFF
        /// → 상단 블러 제거 (BACKDROP, BLUR_EFFECT, filters)
        case variableBlurOff = "VariableBlur OFF"

        /// FloatingUI 내 shadow만 OFF
        /// → shadowOpacity = 0 (FloatingOverlayContainer 범위만)
        case floatingShadowOff = "FloatingShadow OFF"
    }

    // MARK: - State

    /// 현재 활성화된 테스트 (코드 또는 lldb에서 변경)
    /// `expr RenderABTest.activeTest = .floatingUIHidden`
    static var activeTest: TestCase = .glassEffectOff

    /// 복원용 상태 저장
    private static var savedStates: [String: Any] = [:]

    /// 현재 테스트명 (로그용)
    static var activeTestName: String {
        return activeTest.rawValue
    }

    // MARK: - Apply / Restore

    /// 스크롤 시작 시 호출 — 테스트 조건 적용
    static func applyTest(in window: UIView?) {
        guard activeTest != .baseline else { return }
        guard let window = window else { return }

        Logger.performance.debug("적용: \(activeTest.rawValue)")

        switch activeTest {
        case .baseline:
            break

        case .floatingUIHidden:
            applyFloatingUIHidden(in: window)

        case .cellsOpaque:
            applyCellsOpaque(in: window)

        case .shadowPathFix:
            applyShadowPathFix(in: window)

        case .glassEffectOff:
            applyGlassEffectOff(in: window)

        case .variableBlurOff:
            applyVariableBlurOff(in: window)

        case .floatingShadowOff:
            applyFloatingShadowOff(in: window)
        }
    }

    /// 스크롤 종료 시 호출 — 테스트 조건 복원
    static func restoreTest(in window: UIView?) {
        guard activeTest != .baseline else { return }
        guard let window = window else { return }

        Logger.performance.debug("복원: \(activeTest.rawValue)")

        switch activeTest {
        case .baseline:
            break

        case .floatingUIHidden:
            restoreFloatingUIHidden(in: window)

        case .cellsOpaque:
            restoreCellsOpaque(in: window)

        case .shadowPathFix:
            restoreShadowPathFix(in: window)

        case .glassEffectOff:
            restoreGlassEffectOff(in: window)

        case .variableBlurOff:
            restoreVariableBlurOff(in: window)

        case .floatingShadowOff:
            restoreFloatingShadowOff(in: window)
        }

        savedStates.removeAll()
    }

    // MARK: - Test 1: FloatingUI Hidden

    /// FloatingOverlayContainer를 숨겨서 효과형 레이어 43개 제거
    private static func applyFloatingUIHidden(in window: UIView) {
        if let container = findView(ofType: "FloatingOverlayContainer", in: window) {
            savedStates["floatingHidden"] = container.isHidden
            container.isHidden = true
        }
    }

    private static func restoreFloatingUIHidden(in window: UIView) {
        if let container = findView(ofType: "FloatingOverlayContainer", in: window) {
            let wasHidden = savedStates["floatingHidden"] as? Bool ?? false
            container.isHidden = wasHidden
        }
    }

    // MARK: - Test 2: Cells isOpaque

    /// 모든 PhotoCell의 UIImageView를 opaque로 설정
    /// → !opaque 블렌딩 제거, 배경색 white 설정
    private static func applyCellsOpaque(in window: UIView) {
        let imageViews = findCellImageViews(in: window)
        // 첫 번째 imageView의 상태만 저장 (전부 동일하다고 가정)
        if let first = imageViews.first {
            savedStates["wasOpaque"] = first.isOpaque
            savedStates["bgColor"] = first.backgroundColor
        }
        for iv in imageViews {
            iv.isOpaque = true
            iv.backgroundColor = .black  // 셀 배경 = 검정 (이미지가 채우므로 보이지 않음)
        }
        Logger.performance.debug("Cells isOpaque 적용: \(imageViews.count)개 imageView")
    }

    private static func restoreCellsOpaque(in window: UIView) {
        let imageViews = findCellImageViews(in: window)
        let wasOpaque = savedStates["wasOpaque"] as? Bool ?? false
        let bgColor = savedStates["bgColor"] as? UIColor
        for iv in imageViews {
            iv.isOpaque = wasOpaque
            iv.backgroundColor = bgColor
        }
    }

    // MARK: - Test 3: Shadow Path Fix

    /// shadow(path=false)인 레이어에 shadowPath를 자동 생성
    /// → offscreen shadow 렌더 제거
    private static func applyShadowPathFix(in window: UIView) {
        var fixedCount = 0
        applyToAllLayers(in: window.layer) { layer in
            if layer.shadowOpacity > 0 && layer.shadowPath == nil {
                // bounds 기반 shadowPath 생성
                let path = UIBezierPath(
                    roundedRect: layer.bounds,
                    cornerRadius: layer.cornerRadius
                )
                layer.shadowPath = path.cgPath
                fixedCount += 1
            }
        }
        savedStates["shadowFixCount"] = fixedCount
        Logger.performance.debug("Shadow path 적용: \(fixedCount)개 레이어")
    }

    private static func restoreShadowPathFix(in window: UIView) {
        applyToAllLayers(in: window.layer) { layer in
            if layer.shadowOpacity > 0 && layer.shadowPath != nil {
                layer.shadowPath = nil
            }
        }
    }

    // MARK: - Test 4: Glass Effect OFF (FloatingUI 내부 분해)

    /// LiquidGlass 효과 뷰만 숨김 (METAL + BACKDROP 제거)
    /// FloatingUI 구조는 유지, glass 렌더링만 비활성화
    private static func applyGlassEffectOff(in window: UIView) {
        guard let container = findView(ofType: "FloatingOverlayContainer", in: window) else { return }

        // LiquidGlassEffectView: GlassTextButton, LiquidGlassPlatter 내부
        // BackdropView: SelectionPill 내부에도 독립적으로 존재
        var hiddenViews: [UIView] = []

        findViews(matching: { viewName in
            viewName == "LiquidGlassEffectView" || viewName == "BackdropView"
        }, in: container, results: &hiddenViews)

        savedStates["glassHiddenViews"] = hiddenViews.map { ($0, $0.isHidden) }

        for view in hiddenViews {
            view.isHidden = true
        }
        Logger.performance.debug("Glass effect OFF: \(hiddenViews.count)개 뷰 숨김")
    }

    private static func restoreGlassEffectOff(in window: UIView) {
        guard let pairs = savedStates["glassHiddenViews"] as? [(UIView, Bool)] else { return }
        for (view, wasHidden) in pairs {
            view.isHidden = wasHidden
        }
    }

    // MARK: - Test 5: VariableBlur OFF (FloatingUI 내부 분해)

    /// VariableBlurView만 숨김 (상단 프로그레시브 블러)
    private static func applyVariableBlurOff(in window: UIView) {
        guard let container = findView(ofType: "FloatingOverlayContainer", in: window) else { return }

        var blurViews: [UIView] = []
        findViews(matching: { $0 == "VariableBlurView" }, in: container, results: &blurViews)

        savedStates["blurHiddenViews"] = blurViews.map { ($0, $0.isHidden) }

        for view in blurViews {
            view.isHidden = true
        }
        Logger.performance.debug("VariableBlur OFF: \(blurViews.count)개 뷰 숨김")
    }

    private static func restoreVariableBlurOff(in window: UIView) {
        guard let pairs = savedStates["blurHiddenViews"] as? [(UIView, Bool)] else { return }
        for (view, wasHidden) in pairs {
            view.isHidden = wasHidden
        }
    }

    // MARK: - Test 6: Floating Shadow OFF (FloatingUI 내부 분해)

    /// FloatingOverlayContainer 내의 모든 shadow 제거
    private static func applyFloatingShadowOff(in window: UIView) {
        guard let container = findView(ofType: "FloatingOverlayContainer", in: window) else { return }

        var shadowLayers: [(CALayer, Float)] = []
        applyToAllLayers(in: container.layer) { layer in
            if layer.shadowOpacity > 0 {
                shadowLayers.append((layer, layer.shadowOpacity))
                layer.shadowOpacity = 0
            }
        }
        savedStates["shadowLayers"] = shadowLayers
        Logger.performance.debug("Floating shadow OFF: \(shadowLayers.count)개 레이어")
    }

    private static func restoreFloatingShadowOff(in window: UIView) {
        guard let pairs = savedStates["shadowLayers"] as? [(CALayer, Float)] else { return }
        for (layer, opacity) in pairs {
            layer.shadowOpacity = opacity
        }
    }

    // MARK: - Helpers

    /// 조건에 맞는 뷰를 재귀적으로 찾기 (타입명 매칭)
    private static func findViews(matching predicate: (String) -> Bool, in view: UIView, results: inout [UIView]) {
        let name = String(describing: type(of: view))
        if predicate(name) {
            results.append(view)
        }
        for sub in view.subviews {
            findViews(matching: predicate, in: sub, results: &results)
        }
    }


    /// 이름으로 뷰 찾기 (타입 이름 매칭)
    private static func findView(ofType typeName: String, in view: UIView) -> UIView? {
        let name = String(describing: type(of: view))
        if name == typeName { return view }
        for sub in view.subviews {
            if let found = findView(ofType: typeName, in: sub) {
                return found
            }
        }
        return nil
    }

    /// 모든 PhotoCell 내부의 imageView 찾기
    private static func findCellImageViews(in window: UIView) -> [UIImageView] {
        var results: [UIImageView] = []
        // UICollectionView 찾기
        if let collectionView = findCollectionView(in: window) {
            for cell in collectionView.visibleCells {
                // PhotoCell의 contentView 안 첫 번째 UIImageView
                if let imageView = cell.contentView.subviews.first(where: { $0 is UIImageView }) as? UIImageView {
                    results.append(imageView)
                }
            }
        }
        return results
    }

    /// UICollectionView 찾기
    private static func findCollectionView(in view: UIView) -> UICollectionView? {
        if let cv = view as? UICollectionView { return cv }
        for sub in view.subviews {
            if let found = findCollectionView(in: sub) { return found }
        }
        return nil
    }

    /// 모든 레이어에 대해 클로저 실행 (재귀)
    private static func applyToAllLayers(in layer: CALayer, action: (CALayer) -> Void) {
        action(layer)
        layer.sublayers?.forEach { applyToAllLayers(in: $0, action: action) }
    }
}

#endif
