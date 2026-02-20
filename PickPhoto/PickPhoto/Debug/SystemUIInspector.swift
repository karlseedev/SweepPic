// SystemUIInspector.swift
// iOS 26 시스템 UI (네비바, 탭바)의 레이어 속성을 덤프하는 디버그 유틸리티
// 사용 후 삭제 예정

import UIKit
import AppCore
import ObjectiveC

/// 시스템 UI 레이어 속성 인스펙터
/// - 뷰 계층 순회
/// - CALayer 속성 덤프 (backgroundColor, opacity, cornerRadius, border, shadow)
/// - UIVisualEffectView effect 정보
/// - Private API 접근 시도 (KVC)
final class SystemUIInspector {

    static let shared = SystemUIInspector()
    private init() {}

    /// 플로팅 디버그 버튼
    private var debugButton: UIButton?
    private var inspectionCount = 0

    /// 인스펙션 결과를 저장할 문자열
    private var output = ""

    /// 들여쓰기 레벨
    private var indentLevel = 0

    // MARK: - Public API

    /// 플로팅 디버그 버튼 표시 (화면 중앙)
    func showDebugButton() {
        guard debugButton == nil else { return }
        guard let window = getKeyWindow() else { return }

        let button = UIButton(type: .system)
        button.setTitle("🔍 Inspect UI", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 4)

        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(debugButtonTapped), for: .touchUpInside)

        window.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: window.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 150),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])

        self.debugButton = button
    }

    /// 디버그 버튼 숨기기
    func hideDebugButton() {
        debugButton?.removeFromSuperview()
        debugButton = nil
    }

    @objc private func debugButtonTapped() {
        inspectionCount += 1

        // 버튼 피드백
        debugButton?.setTitle("검사 중...", for: .normal)
        debugButton?.isEnabled = false

        // 약간의 딜레이 후 인스펙션 (UI 갱신 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.inspectAndSave(suffix: "_\(self.inspectionCount)")

            // 버튼 복원
            self.debugButton?.setTitle("🔍 Inspect UI", for: .normal)
            self.debugButton?.isEnabled = true
        }
    }

    /// 시스템 UI 전체 인스펙션 실행 및 파일 저장
    func inspectAndSave(suffix: String = "") {
        output = ""
        indentLevel = 0

        appendLine("=" .replaceRepeating(60))
        appendLine("iOS System UI Inspector")
        appendLine("Date: \(Date())")
        appendLine("iOS Version: \(UIDevice.current.systemVersion)")
        appendLine("=" .replaceRepeating(60))
        appendLine("")

        // Key Window 찾기
        guard let window = getKeyWindow() else {
            appendLine("❌ Key Window를 찾을 수 없습니다.")
            saveToFile(suffix: suffix)
            return
        }

        appendLine("Window: \(type(of: window)), frame: \(window.frame)")
        appendLine("")

        // 1. UINavigationBar 찾기 및 인스펙션
        appendLine("=" .replaceRepeating(60))
        appendLine("📍 UINavigationBar 인스펙션")
        appendLine("=" .replaceRepeating(60))
        let navBars = findViews(ofType: UINavigationBar.self, in: window)
        if navBars.isEmpty {
            appendLine("UINavigationBar를 찾을 수 없습니다.")
        } else {
            for (index, navBar) in navBars.enumerated() {
                appendLine("\n--- NavigationBar #\(index + 1) ---")
                inspectView(navBar)
            }
        }

        appendLine("")

        // 2. UITabBar 찾기 및 인스펙션
        appendLine("=" .replaceRepeating(60))
        appendLine("📍 UITabBar 인스펙션")
        appendLine("=" .replaceRepeating(60))
        let tabBars = findViews(ofType: UITabBar.self, in: window)
        if tabBars.isEmpty {
            appendLine("UITabBar를 찾을 수 없습니다.")
        } else {
            for (index, tabBar) in tabBars.enumerated() {
                appendLine("\n--- TabBar #\(index + 1) ---")
                inspectView(tabBar)
            }
        }

        appendLine("")

        // 3. UIToolbar 찾기 및 인스펙션
        appendLine("=" .replaceRepeating(60))
        appendLine("📍 UIToolbar 인스펙션")
        appendLine("=" .replaceRepeating(60))
        let toolbars = findViews(ofType: UIToolbar.self, in: window)
        if toolbars.isEmpty {
            appendLine("UIToolbar를 찾을 수 없습니다.")
        } else {
            for (index, toolbar) in toolbars.enumerated() {
                appendLine("\n--- Toolbar #\(index + 1) ---")
                inspectView(toolbar)
            }
        }

        appendLine("")

        // 4. 플로팅 버튼 (PlatterView) 찾기 - NavigationBar/TabBar 외부
        appendLine("=" .replaceRepeating(60))
        appendLine("📍 플로팅 버튼 인스펙션 (PlatterView - 바/툴바 외부)")
        appendLine("=" .replaceRepeating(60))
        let floatingButtons = findFloatingPlatterViews(in: window, excludingBars: navBars + tabBars + toolbars)
        if floatingButtons.isEmpty {
            appendLine("NavigationBar/TabBar/Toolbar 외부에 PlatterView를 찾을 수 없습니다.")
        } else {
            appendLine("총 \(floatingButtons.count)개 발견")
            for (index, platterView) in floatingButtons.enumerated() {
                appendLine("\n--- 플로팅 버튼 #\(index + 1) ---")
                appendLine("위치: \(platterView.convert(platterView.bounds, to: window))")
                inspectView(platterView)
            }
        }

        appendLine("")

        // 5. 화면 하단 영역 - UIPlatformGlassInteractionView (플로팅 버튼 컨테이너) 찾기
        appendLine("=" .replaceRepeating(60))
        appendLine("📍 플로팅 Glass 버튼 스캔 (UIPlatformGlassInteractionView)")
        appendLine("=" .replaceRepeating(60))
        let glassButtons = findGlassInteractionViews(in: window, excludingBars: navBars + tabBars + toolbars)
        if glassButtons.isEmpty {
            appendLine("UIPlatformGlassInteractionView를 찾을 수 없습니다.")
        } else {
            appendLine("총 \(glassButtons.count)개 발견")
            for (index, view) in glassButtons.enumerated() {
                appendLine("\n--- Glass 버튼 #\(index + 1) ---")
                appendLine("전역 위치: \(view.convert(view.bounds, to: window))")
                inspectView(view, maxDepth: 6)
            }
        }

        appendLine("")

        // 6. UIVisualEffectView 찾기 및 인스펙션
        appendLine("=" .replaceRepeating(60))
        appendLine("📍 UIVisualEffectView 인스펙션 (상위 10개)")
        appendLine("=" .replaceRepeating(60))
        let effectViews = findViews(ofType: UIVisualEffectView.self, in: window)
        if effectViews.isEmpty {
            appendLine("UIVisualEffectView를 찾을 수 없습니다.")
        } else {
            appendLine("총 \(effectViews.count)개 발견, 상위 10개만 출력")
            for (index, effectView) in effectViews.prefix(10).enumerated() {
                appendLine("\n--- VisualEffectView #\(index + 1) ---")
                inspectVisualEffectView(effectView)
            }
        }

        // 파일 저장
        saveToFile(suffix: suffix)
    }

    // MARK: - View Finding

    /// Key Window 가져오기
    private func getKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }

    /// 특정 타입의 뷰 찾기 (재귀)
    private func findViews<T: UIView>(ofType type: T.Type, in view: UIView) -> [T] {
        var results: [T] = []

        if let matched = view as? T {
            results.append(matched)
        }

        for subview in view.subviews {
            results.append(contentsOf: findViews(ofType: type, in: subview))
        }

        return results
    }

    /// NavigationBar/TabBar/Toolbar 외부에 있는 PlatterView 찾기
    private func findFloatingPlatterViews(in window: UIWindow, excludingBars bars: [UIView]) -> [UIView] {
        var results: [UIView] = []

        // PlatterView 클래스명 패턴
        let platterPatterns = ["PlatterView", "Platter"]

        func searchRecursively(_ view: UIView) {
            let typeName = String(describing: type(of: view))

            // Bar 내부는 제외
            for bar in bars {
                if view.isDescendant(of: bar) {
                    return
                }
            }

            // PlatterView 패턴 매칭
            for pattern in platterPatterns {
                if typeName.contains(pattern) {
                    results.append(view)
                    return // 하위는 탐색하지 않음 (PlatterView 내부는 별도로 인스펙션됨)
                }
            }

            // 하위 뷰 탐색
            for subview in view.subviews {
                searchRecursively(subview)
            }
        }

        searchRecursively(window)
        return results
    }

    /// UIPlatformGlassInteractionView 찾기 (iOS 26 플로팅 버튼 컨테이너)
    private func findGlassInteractionViews(in window: UIWindow, excludingBars bars: [UIView]) -> [UIView] {
        var results: [UIView] = []

        func searchRecursively(_ view: UIView) {
            let typeName = String(describing: type(of: view))

            // Bar 내부는 제외
            for bar in bars {
                if view.isDescendant(of: bar) {
                    return
                }
            }

            // UIPlatformGlassInteractionView 찾기
            if typeName.contains("PlatformGlassInteractionView") {
                results.append(view)
                return // 하위는 탐색하지 않음 (이미 인스펙션에서 재귀 처리)
            }

            // 하위 뷰 탐색
            for subview in view.subviews {
                searchRecursively(subview)
            }
        }

        searchRecursively(window)
        return results
    }

    // MARK: - View Inspection

    /// 뷰와 하위 뷰 전체 인스펙션
    private func inspectView(_ view: UIView, maxDepth: Int = 8) {
        inspectViewRecursive(view, depth: 0, maxDepth: maxDepth)
    }

    private func inspectViewRecursive(_ view: UIView, depth: Int, maxDepth: Int) {
        guard depth <= maxDepth else {
            appendLine("\(indent(depth))... (max depth reached)")
            return
        }

        let typeName = String(describing: type(of: view))
        let isPrivateView = typeName.hasPrefix("_") ||
                           typeName.contains("Glass") ||
                           typeName.contains("Liquid") ||
                           typeName.contains("Platter") ||
                           typeName.contains("Selection") ||
                           typeName.contains("Portal")

        appendLine("\(indent(depth))[\(typeName)]\(isPrivateView ? " [PRIVATE]" : "")")
        appendLine("\(indent(depth))  frame: \(view.frame)")
        appendLine("\(indent(depth))  bounds: \(view.bounds)")
        appendLine("\(indent(depth))  alpha: \(view.alpha)")
        appendLine("\(indent(depth))  isHidden: \(view.isHidden)")

        // CALayer 속성 덤프
        inspectLayer(view.layer, depth: depth)

        // Private 뷰 상세 덤프 (Runtime Introspection)
        if isPrivateView {
            appendLine("\(indent(depth))  [Private Properties (Runtime)]:")
            let ivars = dumpAllIvars(of: view, prefix: "\(indent(depth))    ")
            for ivar in ivars.prefix(30) {  // 최대 30개
                appendLine(ivar)
            }
            if ivars.count > 30 {
                appendLine("\(indent(depth))    ... and \(ivars.count - 30) more")
            }

            // ClearGlassView 등에서 innerShadowView 자동 덤프
            if typeName.contains("Glass") || typeName.contains("Liquid") {
                let innerShadowInfo = dumpInnerShadowView(from: view, indent: "\(indent(depth))  ")
                for line in innerShadowInfo {
                    appendLine(line)
                }
            }
        }

        // UIVisualEffectView 특별 처리
        if let effectView = view as? UIVisualEffectView {
            inspectVisualEffectViewDetails(effectView, depth: depth)
        }

        // 하위 뷰 순회
        if !view.subviews.isEmpty {
            appendLine("\(indent(depth))  subviews: \(view.subviews.count)개")
            for subview in view.subviews {
                inspectViewRecursive(subview, depth: depth + 1, maxDepth: maxDepth)
            }
        }
    }

    // MARK: - Layer Inspection

    /// CALayer 속성 덤프
    private func inspectLayer(_ layer: CALayer, depth: Int) {
        let ind = indent(depth) + "  "

        // 레이어 타입
        let layerType = String(describing: type(of: layer))
        if layerType != "CALayer" {
            appendLine("\(ind)layer type: \(layerType)")
        }

        // 배경색
        if let bgColor = layer.backgroundColor {
            appendLine("\(ind)backgroundColor: \(colorDescription(bgColor))")
        }

        // 투명도
        if layer.opacity != 1.0 {
            appendLine("\(ind)opacity: \(layer.opacity)")
        }

        // 코너
        if layer.cornerRadius > 0 {
            appendLine("\(ind)cornerRadius: \(layer.cornerRadius)")
            appendLine("\(ind)cornerCurve: \(layer.cornerCurve.rawValue)")
            appendLine("\(ind)masksToBounds: \(layer.masksToBounds)")
        }

        // 테두리
        if layer.borderWidth > 0 {
            appendLine("\(ind)borderWidth: \(layer.borderWidth)")
            if let borderColor = layer.borderColor {
                appendLine("\(ind)borderColor: \(colorDescription(borderColor))")
            }
        }

        // 그림자
        if layer.shadowOpacity > 0 {
            appendLine("\(ind)shadowOpacity: \(layer.shadowOpacity)")
            appendLine("\(ind)shadowRadius: \(layer.shadowRadius)")
            appendLine("\(ind)shadowOffset: \(layer.shadowOffset)")
            if let shadowColor = layer.shadowColor {
                appendLine("\(ind)shadowColor: \(colorDescription(shadowColor))")
            }
        }

        // 필터 (iOS에서는 대부분 무시되지만 확인)
        if let filters = layer.filters, !filters.isEmpty {
            appendLine("\(ind)filters: \(filters)")
        }

        if let compositingFilter = layer.compositingFilter {
            appendLine("\(ind)compositingFilter: \(compositingFilter)")
        }

        // sublayers 정보 (직접 순회하지 않고 개수만)
        if let sublayers = layer.sublayers, !sublayers.isEmpty {
            appendLine("\(ind)sublayers: \(sublayers.count)개")

            // CAGradientLayer 등 특수 레이어 상세 정보
            for (index, sublayer) in sublayers.enumerated() {
                inspectSpecialLayer(sublayer, index: index, depth: depth)
            }
        }
    }

    /// 특수 레이어 (CAGradientLayer 등) 상세 인스펙션
    private func inspectSpecialLayer(_ layer: CALayer, index: Int, depth: Int) {
        let ind = indent(depth) + "    "
        let layerType = String(describing: type(of: layer))

        // CAGradientLayer
        if let gradientLayer = layer as? CAGradientLayer {
            appendLine("\(ind)[\(index)] CAGradientLayer:")
            appendLine("\(ind)  frame: \(gradientLayer.frame)")
            appendLine("\(ind)  colors: \(gradientLayer.colors?.count ?? 0)개")
            if let colors = gradientLayer.colors as? [CGColor] {
                for (i, color) in colors.enumerated() {
                    appendLine("\(ind)    [\(i)] \(colorDescription(color))")
                }
            }
            appendLine("\(ind)  startPoint: \(gradientLayer.startPoint)")
            appendLine("\(ind)  endPoint: \(gradientLayer.endPoint)")
            if let locations = gradientLayer.locations {
                appendLine("\(ind)  locations: \(locations)")
            }
            appendLine("\(ind)  type: \(gradientLayer.type.rawValue)")
        }
        // CAShapeLayer
        else if let shapeLayer = layer as? CAShapeLayer {
            appendLine("\(ind)[\(index)] CAShapeLayer:")
            appendLine("\(ind)  frame: \(shapeLayer.frame)")
            if let fillColor = shapeLayer.fillColor {
                appendLine("\(ind)  fillColor: \(colorDescription(fillColor))")
            }
            if let strokeColor = shapeLayer.strokeColor {
                appendLine("\(ind)  strokeColor: \(colorDescription(strokeColor))")
            }
            appendLine("\(ind)  lineWidth: \(shapeLayer.lineWidth)")
        }
        // Private 레이어 (CASDFLayer, CAPortalLayer, _UIMultiLayer 등)
        else if layerType.contains("SDF") || layerType.contains("Portal") ||
                layerType.hasPrefix("_") || layerType.contains("Multi") {
            appendLine("\(ind)[\(index)] \(layerType) [PRIVATE - Full Dump]:")
            appendLine("\(ind)  frame: \(layer.frame)")
            appendLine("\(ind)  bounds: \(layer.bounds)")
            appendLine("\(ind)  opacity: \(layer.opacity)")

            // Runtime introspection으로 모든 속성 덤프
            let privateProps = dumpPrivateLayer(layer, indent: ind)
            for prop in privateProps {
                appendLine(prop)
            }
        }
        // 기타 특수 레이어
        else if layerType != "CALayer" {
            appendLine("\(ind)[\(index)] \(layerType): frame=\(layer.frame)")

            // 기본 속성만 간단히
            if layer.opacity != 1.0 {
                appendLine("\(ind)  opacity: \(layer.opacity)")
            }
            if let bgColor = layer.backgroundColor {
                appendLine("\(ind)  backgroundColor: \(colorDescription(bgColor))")
            }
        }
    }

    // MARK: - UIVisualEffectView Inspection

    /// UIVisualEffectView 전체 인스펙션
    private func inspectVisualEffectView(_ effectView: UIVisualEffectView) {
        appendLine("frame: \(effectView.frame)")
        appendLine("effect: \(String(describing: effectView.effect))")

        if let blurEffect = effectView.effect as? UIBlurEffect {
            appendLine("effect type: UIBlurEffect")
            appendLine("effect description: \(blurEffect)")

            // Private API로 blur style 접근 시도
            tryAccessPrivateProperties(of: blurEffect, prefix: "blurEffect")
        }

        // 레이어 속성
        appendLine("\n[Layer Properties]")
        inspectLayer(effectView.layer, depth: 0)

        // Private 속성 접근 시도
        appendLine("\n[Private Properties (KVC)]")
        tryAccessPrivateProperties(of: effectView, prefix: "effectView")

        // 하위 뷰 구조
        appendLine("\n[Subview Hierarchy]")
        inspectViewRecursive(effectView, depth: 0, maxDepth: 3)
    }

    /// UIVisualEffectView 상세 정보 (재귀 순회 중)
    private func inspectVisualEffectViewDetails(_ effectView: UIVisualEffectView, depth: Int) {
        let ind = indent(depth) + "  "

        appendLine("\(ind)[UIVisualEffectView Details]")
        appendLine("\(ind)  effect: \(String(describing: effectView.effect))")

        if let blurEffect = effectView.effect as? UIBlurEffect {
            appendLine("\(ind)  blurEffect: \(blurEffect)")
        }
    }

    /// Private 속성 접근 시도 (KVC)
    private func tryAccessPrivateProperties(of object: AnyObject, prefix: String) {
        let keysToTry = [
            "blurRadius",
            "_blurRadius",
            "saturationDelta",
            "_saturationDelta",
            "tintColor",
            "_tintColor",
            "tintAlpha",
            "_tintAlpha",
            "scale",
            "_scale",
            "filterType",
            "_filterType",
            "backdropLayer",
            "_backdropLayer",
            "colorTint",
            "colorTintAlpha"
        ]

        guard let nsObject = object as? NSObject else { return }

        for key in keysToTry {
            // Objective-C 브릿지로 안전하게 KVC 접근
            if let value = ObjCExceptionCatcher.safeValue(forKey: key, on: nsObject) {
                appendLine("  \(prefix).\(key) = \(value)")
            }
        }
    }

    // MARK: - Helpers

    /// 들여쓰기 문자열
    private func indent(_ level: Int) -> String {
        return String(repeating: "  ", count: level)
    }

    /// CGColor를 읽기 쉬운 문자열로 변환
    private func colorDescription(_ cgColor: CGColor) -> String {
        guard let components = cgColor.components else {
            return "unknown"
        }

        // colorSpace는 현재 사용하지 않음 (필요시 활성화)
        _ = cgColor.colorSpace?.name as String? ?? "unknown"

        if components.count == 2 {
            // Grayscale + Alpha
            let white = components[0]
            let alpha = components[1]
            return String(format: "gray(%.2f, alpha: %.2f)", white, alpha)
        } else if components.count >= 4 {
            // RGBA
            let r = components[0]
            let g = components[1]
            let b = components[2]
            let a = components[3]
            return String(format: "rgba(%.2f, %.2f, %.2f, %.2f)", r, g, b, a)
        } else {
            return "components: \(components)"
        }
    }

    /// 출력 추가
    private func appendLine(_ text: String) {
        output += text + "\n"
    }

    // MARK: - File Saving

    /// Documents 폴더에 파일 저장
    private func saveToFile(suffix: String = "") {
        let fileName = "system_ui_inspection\(suffix).txt"

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Documents 디렉토리를 찾을 수 없습니다.")
            return
        }

        let fileURL = documentsURL.appendingPathComponent(fileName)

        do {
            try output.write(to: fileURL, atomically: true, encoding: .utf8)
            print("")
            print("╔══════════════════════════════════════════════════════════════╗")
            print("║  📁 System UI Inspection 완료                                  ║")
            print("╚══════════════════════════════════════════════════════════════╝")
            print("")
            print("📄 파일 저장됨:")
            print(fileURL.path)
            print("")
            print("위 경로를 복사해서 Claude에게 전달하세요.")
            print("")
        } catch {
            print("❌ 파일 저장 실패: \(error)")
            // 콘솔에 직접 출력
            print("\n--- 콘솔 출력 ---\n")
            print(output)
        }
    }
}

// MARK: - String Extension

private extension String {
    func replaceRepeating(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// MARK: - Runtime Introspection Extension

extension SystemUIInspector {

    /// 객체의 모든 인스턴스 변수(ivar) 덤프
    func dumpAllIvars(of object: AnyObject, prefix: String = "") -> [String] {
        var results: [String] = []
        var currentClass: AnyClass? = type(of: object)

        // 클래스 계층 순회 (부모 클래스 포함)
        while let cls = currentClass {
            let className = String(describing: cls)

            // NSObject에서 멈춤
            if className == "NSObject" { break }

            var count: UInt32 = 0
            if let ivars = class_copyIvarList(cls, &count) {
                for i in 0..<Int(count) {
                    let ivar = ivars[i]

                    // 이름 가져오기
                    guard let namePtr = ivar_getName(ivar) else { continue }
                    let name = String(cString: namePtr)

                    // UI 관련 ivar만 필터링
                    if !isUIRelatedIvar(name: name) {
                        continue
                    }

                    // 타입 인코딩
                    let typeEncoding: String
                    if let typePtr = ivar_getTypeEncoding(ivar) {
                        typeEncoding = String(cString: typePtr)
                    } else {
                        typeEncoding = "?"
                    }

                    // 값 가져오기 (안전하게)
                    let valueStr = getIvarValueSafely(object: object, ivar: ivar, typeEncoding: typeEncoding)

                    results.append("\(prefix)\(name) (\(typeEncoding)) = \(valueStr)")
                }
                free(ivars)
            }

            currentClass = class_getSuperclass(cls)
        }

        return results
    }

    /// 객체의 모든 프로퍼티 덤프
    func dumpAllProperties(of object: AnyObject, prefix: String = "") -> [String] {
        var results: [String] = []
        var currentClass: AnyClass? = type(of: object)

        while let cls = currentClass {
            let className = String(describing: cls)
            if className == "NSObject" { break }

            var count: UInt32 = 0
            if let properties = class_copyPropertyList(cls, &count) {
                for i in 0..<Int(count) {
                    let property = properties[i]
                    let name = String(cString: property_getName(property))

                    // 속성값 가져오기 (KVC)
                    let valueStr = getPropertyValueSafely(object: object, name: name)

                    results.append("\(prefix)\(name) = \(valueStr)")
                }
                free(properties)
            }

            currentClass = class_getSuperclass(cls)
        }

        return results
    }

    /// ivar 값을 안전하게 가져오기
    private func getIvarValueSafely(object: AnyObject, ivar: Ivar, typeEncoding: String) -> String {
        // 객체 타입인 경우 object_getIvar 사용 (@ 로 시작)
        if typeEncoding.hasPrefix("@") {
            if let value = object_getIvar(object, ivar) as AnyObject? {
                return describeValue(value)
            } else {
                return "nil"
            }
        }

        // 기본 타입은 KVC로 안전하게 시도
        guard let namePtr = ivar_getName(ivar) else { return "?" }
        let name = String(cString: namePtr)

        // Objective-C 브릿지로 안전하게 KVC 접근
        guard let nsObject = object as? NSObject else {
            return "<not-nsobject>"
        }

        if let value = ObjCExceptionCatcher.safeValue(forKey: name, on: nsObject) {
            return "\(value)"
        }

        return "<primitive:\(typeEncoding)>"
    }

    /// 프로퍼티 값을 안전하게 가져오기 (KVC with Objective-C exception handling)
    private func getPropertyValueSafely(object: AnyObject, name: String) -> String {
        // 알려진 위험한 키는 스킵
        let dangerousKeys = ["description", "debugDescription", "hash", "superclass",
                             "class", "self", "zone", "isa", "retain", "release",
                             "autorelease", "retainCount", "copy", "mutableCopy"]
        if dangerousKeys.contains(name) {
            return "<skipped>"
        }

        // Objective-C 브릿지로 안전하게 KVC 접근
        guard let nsObject = object as? NSObject else {
            return "<not-nsobject>"
        }

        if let value = ObjCExceptionCatcher.safeValue(forKey: name, on: nsObject) {
            return describeValue(value as AnyObject)
        }

        return "<unavailable>"
    }

    /// UI 관련 ivar인지 확인 (필터링용)
    private func isUIRelatedIvar(name: String) -> Bool {
        // 포함할 키워드 (UI 시각적 속성)
        let includeKeywords = [
            // 크기/위치
            "frame", "bounds", "size", "width", "height", "origin", "position", "center",
            "inset", "Inset", "margin", "Margin", "padding", "Padding",
            "offset", "Offset", "anchor", "Anchor", "zPosition",
            // 색상
            "color", "Color", "tint", "Tint",
            // 투명도/가시성
            "alpha", "opacity", "hidden", "Hidden", "visible", "Visible",
            // 모서리/테두리
            "corner", "Corner", "radius", "Radius", "border", "Border", "round", "Round",
            // 그림자
            "shadow", "Shadow",
            // 효과/필터/합성
            "blur", "Blur", "filter", "Filter", "effect", "Effect",
            "gradient", "Gradient", "glass", "Glass", "liquid", "Liquid",
            "compositing", "Compositing", "blend", "Blend", "mode", "Mode",
            // 경로/마스크/클리핑
            "path", "Path", "mask", "Mask", "clip", "Clip",
            // 획/채우기
            "stroke", "Stroke", "fill", "Fill",
            // 텍스트/폰트
            "font", "Font", "text", "Text", "title", "Title", "label", "Label",
            // 이미지/아이콘
            "image", "Image", "icon", "Icon",
            // 버튼/컨트롤
            "button", "Button", "control", "Control", "selected", "Selected",
            "highlight", "Highlight", "pressed", "Pressed",
            // 배경
            "background", "Background", "backdrop", "Backdrop",
            // 레이어
            "layer", "Layer", "sublayer", "Sublayer",
            // 선택/포커스
            "selection", "Selection", "focus", "Focus",
            // 애니메이션
            "animation", "Animation", "transform", "Transform", "scale", "Scale",
            // 스타일/외관/설정
            "style", "Style", "appearance", "Appearance", "configuration", "Configuration",
            // 콘텐츠/레이아웃
            "content", "Content", "spacing", "Spacing", "alignment", "Alignment",
            "axis", "Axis", "distribution", "Distribution"
        ]

        // 제외할 키워드 (내부 관리용)
        let excludeKeywords = [
            "_viewFlags", "_traitChange", "_gestureRecognizer", "_gestureInfo",
            "_constraint", "Constraint", "_autolayout", "_autoresize",
            "_cache", "Cache", "_cached",
            "_observation", "_notification", "_registry",
            "_storage", "Storage",
            "_delegate", // delegate는 제외
            "_responder", "_firstResponder",
            "_window", "_superview",
            "_subview", // subviews 정보는 별도로 출력
            "retainCount", "zone", "isa",
            "_internal", "_private", "_impl",
            "_accessibility", "Accessibility",
            "_trait", "Trait",
            "_semantic", "Semantic",
            // 레이아웃 마진/가이드 (불필요한 상세 정보)
            "_rawLayoutMargins", "_inferredLayoutMargins",
            "_safeAreaInsets", "_minimumSafeAreaInsets", "_clippedSafeAreaCornerInsets",
            "_boundsWidthVariable", "_boundsHeightVariable",
            "_tintAdjustmentDimmingCount", "_countOfFocusedAncestorTrackingViewsInSubtree",
            "__isEffectivelyHidden", "_layoutMarginsGuide", "_readableContentGuide",
            "_swiftAnimationInfo", "_layerRetained"
        ]

        // 제외 키워드에 해당하면 false
        for keyword in excludeKeywords {
            if name.contains(keyword) {
                return false
            }
        }

        // 포함 키워드에 해당하면 true
        for keyword in includeKeywords {
            if name.contains(keyword) {
                return true
            }
        }

        // 그 외에는 false (기본적으로 제외)
        return false
    }

    /// 값을 문자열로 설명
    private func describeValue(_ value: AnyObject) -> String {
        let typeName = String(describing: type(of: value))

        // 숫자 타입
        if let num = value as? NSNumber {
            return "\(num) (\(typeName))"
        }

        // 문자열
        if let str = value as? String {
            return "\"\(str)\""
        }

        // 색상 (CGColor는 CFType이므로 CFGetTypeID로 체크)
        if CFGetTypeID(value) == CGColor.typeID {
            let color = value as! CGColor
            return colorDescription(color)
        }

        if let color = value as? UIColor {
            return colorDescription(color.cgColor)
        }

        // 배열
        if let arr = value as? [Any] {
            if arr.isEmpty {
                return "[] (empty)"
            }
            let itemTypes = arr.prefix(3).map { String(describing: type(of: $0)) }
            return "[\(arr.count) items: \(itemTypes.joined(separator: ", "))...]"
        }

        // CALayer
        if let layer = value as? CALayer {
            return "<\(typeName): frame=\(layer.frame)>"
        }

        // 일반 객체
        return "<\(typeName)>"
    }

    /// 특수 레이어 상세 덤프 (CASDFLayer, CAPortalLayer 등)
    func dumpPrivateLayer(_ layer: CALayer, indent: String) -> [String] {
        var results: [String] = []
        let typeName = String(describing: type(of: layer))

        results.append("\(indent)[\(typeName)] Private Properties:")

        // 모든 ivar 덤프
        let ivars = dumpAllIvars(of: layer, prefix: "\(indent)  ")
        results.append(contentsOf: ivars)

        // filters 상세 정보 (CAFilter 파라미터 포함)
        if let filters = layer.filters, !filters.isEmpty {
            results.append("\(indent)  [Filters Detail]:")
            for (i, filter) in filters.enumerated() {
                results.append("\(indent)    [\(i)] \(type(of: filter))")
                if let ciFilter = filter as? CIFilter {
                    results.append("\(indent)      name: \(ciFilter.name)")
                    for key in ciFilter.inputKeys {
                        if let value = ciFilter.value(forKey: key) {
                            results.append("\(indent)      \(key): \(value)")
                        }
                    }
                } else if let nsFilter = filter as? NSObject {
                    // CAFilter 파라미터 추출 (Private API)
                    let filterParams = dumpCAFilterParams(nsFilter, indent: "\(indent)      ")
                    results.append(contentsOf: filterParams)
                }
            }
        }

        // sublayers 재귀 덤프 (1단계만)
        if let sublayers = layer.sublayers {
            for (i, sublayer) in sublayers.enumerated() {
                let subTypeName = String(describing: type(of: sublayer))
                results.append("\(indent)  sublayer[\(i)]: \(subTypeName), frame=\(sublayer.frame)")

                // UICABackdropLayer 특수 속성 추출
                let backdropProps = dumpBackdropLayerProps(sublayer, indent: "\(indent)    ")
                results.append(contentsOf: backdropProps)
            }
        }

        return results
    }

    // MARK: - CAFilter 파라미터 추출

    /// CAFilter의 모든 파라미터 추출
    func dumpCAFilterParams(_ filter: NSObject, indent: String) -> [String] {
        var results: [String] = []

        // CAFilter 주요 파라미터 키 목록
        let filterKeys = [
            // 공통
            "type", "name", "enabled", "cachesInputImage",
            // Gaussian Blur
            "inputRadius", "inputNormalizeEdges", "inputHardEdges", "inputQuality",
            // Alpha Threshold
            "inputThreshold",
            // Color Matrix
            "inputColorMatrix", "inputBias", "inputAmount",
            // Vibrant
            "inputReversed", "inputMaskImage",
            // Variable Blur
            "inputMaskImage", "inputNormalizedMaskImage",
            // General
            "inputColor", "inputScale", "inputCenter", "inputAngle",
            // Compositing
            "compositingFilter"
        ]

        for key in filterKeys {
            if let value = ObjCExceptionCatcher.safeValue(forKey: key, on: filter) {
                let valueStr = describeFilterValue(value as AnyObject, key: key)
                results.append("\(indent)\(key) = \(valueStr)")
            }
        }

        return results
    }

    /// 필터 값을 문자열로 설명
    private func describeFilterValue(_ value: AnyObject, key: String) -> String {
        let typeName = String(describing: type(of: value))

        // CAColorMatrix 처리
        if typeName.contains("ColorMatrix") || key.contains("ColorMatrix") {
            // CAColorMatrix의 값들을 추출 시도
            if let nsObj = value as? NSObject {
                var matrixStr = "CAColorMatrix("
                let matrixKeys = ["m11", "m12", "m13", "m14", "m15",
                                  "m21", "m22", "m23", "m24", "m25",
                                  "m31", "m32", "m33", "m34", "m35",
                                  "m41", "m42", "m43", "m44", "m45"]
                var values: [String] = []
                for mKey in matrixKeys {
                    if let mVal = ObjCExceptionCatcher.safeValue(forKey: mKey, on: nsObj) {
                        values.append("\(mKey)=\(mVal)")
                    }
                }
                if !values.isEmpty {
                    matrixStr += values.joined(separator: ", ")
                }
                matrixStr += ")"
                return matrixStr
            }
        }

        // 숫자
        if let num = value as? NSNumber {
            return "\(num) (\(typeName))"
        }

        // 불리언 (NSNumber 서브타입)
        if typeName.contains("Boolean") || typeName.contains("Bool") {
            return "\(value)"
        }

        // CGColor
        if CFGetTypeID(value) == CGColor.typeID {
            return colorDescription(value as! CGColor)
        }

        // 배열
        if let arr = value as? [Any] {
            return "[\(arr.count) items]"
        }

        return "\(value) (\(typeName))"
    }

    // MARK: - UICABackdropLayer 속성 추출

    /// UICABackdropLayer 특수 속성 추출
    func dumpBackdropLayerProps(_ layer: CALayer, indent: String) -> [String] {
        var results: [String] = []
        let typeName = String(describing: type(of: layer))

        // Backdrop 레이어인 경우에만 처리
        guard typeName.contains("Backdrop") || typeName.contains("backdrop") else {
            return results
        }

        results.append("\(indent)[Backdrop Layer Properties]:")

        // UICABackdropLayer / CABackdropLayer 주요 속성
        let backdropKeys = [
            "blurRadius", "_blurRadius",
            "saturationDelta", "_saturationDelta",
            "saturationDeltaFactor",
            "scale", "_scale",
            "usesGlobalGroupNamespace",
            "windowServerAware",
            "captureOnly",
            "allowsInPlaceFiltering",
            "reducesCaptureBitDepth",
            "ignoresScreenClip",
            "groupName", "_groupName",
            "zoom", "zoomLevel"
        ]

        let nsLayer = layer as NSObject

        for key in backdropKeys {
            if let value = ObjCExceptionCatcher.safeValue(forKey: key, on: nsLayer) {
                results.append("\(indent)  \(key) = \(value)")
            }
        }

        return results
    }

    // MARK: - innerShadowView 전용 덤프

    /// innerShadowView 찾아서 상세 덤프
    func dumpInnerShadowView(from view: UIView, indent: String) -> [String] {
        var results: [String] = []

        let nsView = view as NSObject

        // innerShadowView 접근 시도
        if let innerShadow = ObjCExceptionCatcher.safeValue(forKey: "innerShadowView", on: nsView) as? UIView {
            results.append("\(indent)[innerShadowView Found]:")
            results.append("\(indent)  class: \(type(of: innerShadow))")
            results.append("\(indent)  frame: \(innerShadow.frame)")
            results.append("\(indent)  alpha: \(innerShadow.alpha)")
            results.append("\(indent)  backgroundColor: \(innerShadow.backgroundColor?.description ?? "nil")")

            // 레이어 속성
            let layer = innerShadow.layer
            results.append("\(indent)  layer.cornerRadius: \(layer.cornerRadius)")
            results.append("\(indent)  layer.shadowOpacity: \(layer.shadowOpacity)")
            results.append("\(indent)  layer.shadowRadius: \(layer.shadowRadius)")
            results.append("\(indent)  layer.shadowOffset: \(layer.shadowOffset)")
            if let shadowColor = layer.shadowColor {
                results.append("\(indent)  layer.shadowColor: \(colorDescription(shadowColor))")
            }
            if let bgColor = layer.backgroundColor {
                results.append("\(indent)  layer.backgroundColor: \(colorDescription(bgColor))")
            }

            // sublayers
            if let sublayers = layer.sublayers {
                results.append("\(indent)  sublayers: \(sublayers.count)개")
                for (i, sub) in sublayers.enumerated() {
                    let subType = String(describing: type(of: sub))
                    results.append("\(indent)    [\(i)] \(subType), frame=\(sub.frame)")
                    if let bgColor = sub.backgroundColor {
                        results.append("\(indent)        backgroundColor: \(colorDescription(bgColor))")
                    }
                    if sub.shadowOpacity > 0 {
                        results.append("\(indent)        shadowOpacity: \(sub.shadowOpacity)")
                        results.append("\(indent)        shadowRadius: \(sub.shadowRadius)")
                        results.append("\(indent)        shadowOffset: \(sub.shadowOffset)")
                    }
                }
            }

            // Private ivars
            let ivars = dumpAllIvars(of: innerShadow, prefix: "\(indent)  ")
            if !ivars.isEmpty {
                results.append("\(indent)  [Private ivars]:")
                results.append(contentsOf: ivars.prefix(20))
            }
        }

        return results
    }
}
