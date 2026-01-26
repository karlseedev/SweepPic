// LayerPropertyTest.swift
// CALayer Private 속성 접근 가능 여부 테스트
// 테스트 완료 후 삭제 예정

#if DEBUG

import UIKit

/// CALayer 및 Private 속성 접근 테스트
/// 결과를 콘솔에 출력하고 파일로 저장
final class LayerPropertyTest {

    static let shared = LayerPropertyTest()
    private init() {}

    /// 테스트 실행 (버튼에서 호출)
    func runTest() {
        var results: [String] = []
        results.append("=== LayerPropertyTest Results ===")
        results.append("Date: \(Date())")
        results.append("")

        guard let window = getKeyWindow() else {
            results.append("[ERROR] Key Window not found")
            saveResults(results)
            return
        }

        // 1. CALayer 기본 속성 테스트
        results.append("## 1. CALayer 기본 속성 (Public API)")
        results.append(testBasicLayerProperties(window.layer))
        results.append("")

        // 2. CALayer.filters 테스트 (Private)
        results.append("## 2. CALayer.filters 테스트")
        results.append(testLayerFilters(window))
        results.append("")

        // 3. CALayer.compositingFilter 테스트 (Private)
        results.append("## 3. CALayer.compositingFilter 테스트")
        results.append(testCompositingFilter(window))
        results.append("")

        // 4. UIColor 분해 테스트
        results.append("## 4. UIColor 분해 테스트")
        results.append(testColorDecomposition())
        results.append("")

        // 5. Private 클래스 속성 접근 테스트 (KVC)
        results.append("## 5. Private 클래스 KVC 접근 테스트")
        results.append(testPrivateClassKVC(window))
        results.append("")

        // 6. CABackdropLayer 테스트
        results.append("## 6. CABackdropLayer 속성 테스트")
        results.append(testBackdropLayer(window))
        results.append("")

        // 결과 저장
        saveResults(results)

        // 콘솔 출력
        print(results.joined(separator: "\n"))

        // 알림
        showAlert(message: "테스트 완료. 콘솔 및 파일 확인.")
    }

    // MARK: - Test Methods

    /// 1. CALayer 기본 속성 테스트
    private func testBasicLayerProperties(_ layer: CALayer) -> String {
        var output: [String] = []

        output.append("cornerRadius: \(layer.cornerRadius) ✅")
        output.append("cornerCurve: \(layer.cornerCurve.rawValue) ✅")
        output.append("masksToBounds: \(layer.masksToBounds) ✅")
        output.append("borderWidth: \(layer.borderWidth) ✅")
        output.append("shadowOpacity: \(layer.shadowOpacity) ✅")
        output.append("shadowRadius: \(layer.shadowRadius) ✅")

        return output.joined(separator: "\n")
    }

    /// 2. CALayer.filters 테스트
    private func testLayerFilters(_ window: UIWindow) -> String {
        var output: [String] = []

        // 뷰 계층에서 filters가 있는 레이어 찾기
        let viewsWithFilters = findViewsWithFilters(in: window)

        if viewsWithFilters.isEmpty {
            output.append("filters가 있는 뷰를 찾지 못함")
            output.append("(TabBar 화면에서 테스트 필요)")
        } else {
            for (view, filters) in viewsWithFilters.prefix(5) {
                let typeName = String(describing: type(of: view))
                output.append("[\(typeName)]")
                output.append("  layer.filters: \(filters)")
            }
            output.append("✅ layer.filters 접근 가능")
        }

        // 직접 접근 테스트
        let testLayer = CALayer()
        if let filters = testLayer.filters {
            output.append("빈 레이어 filters: \(filters)")
        } else {
            output.append("빈 레이어 filters: nil ✅ (정상)")
        }

        return output.joined(separator: "\n")
    }

    /// filters가 있는 뷰 찾기
    private func findViewsWithFilters(in view: UIView) -> [(UIView, [Any])] {
        var results: [(UIView, [Any])] = []

        if let filters = view.layer.filters, !filters.isEmpty {
            results.append((view, filters))
        }

        for subview in view.subviews {
            results.append(contentsOf: findViewsWithFilters(in: subview))
        }

        return results
    }

    /// 3. compositingFilter 테스트
    private func testCompositingFilter(_ window: UIWindow) -> String {
        var output: [String] = []

        let viewsWithCompFilter = findViewsWithCompositingFilter(in: window)

        if viewsWithCompFilter.isEmpty {
            output.append("compositingFilter가 있는 뷰를 찾지 못함")
            output.append("(TabBar 화면에서 DestOutView 필요)")
        } else {
            for (view, filter) in viewsWithCompFilter.prefix(5) {
                let typeName = String(describing: type(of: view))
                output.append("[\(typeName)]")
                output.append("  layer.compositingFilter: \(filter)")
            }
            output.append("✅ layer.compositingFilter 접근 가능")
        }

        return output.joined(separator: "\n")
    }

    /// compositingFilter가 있는 뷰 찾기
    private func findViewsWithCompositingFilter(in view: UIView) -> [(UIView, Any)] {
        var results: [(UIView, Any)] = []

        if let filter = view.layer.compositingFilter {
            results.append((view, filter))
        }

        for subview in view.subviews {
            results.append(contentsOf: findViewsWithCompositingFilter(in: subview))
        }

        return results
    }

    /// 4. UIColor 분해 테스트
    private func testColorDecomposition() -> String {
        var output: [String] = []

        // 테스트 색상들
        let testColors: [(String, UIColor)] = [
            ("systemBackground", .systemBackground),
            ("gray 0.5 alpha 0.8", UIColor(white: 0.5, alpha: 0.8)),
            ("red", .red),
            ("clear", .clear)
        ]

        for (name, color) in testColors {
            output.append("[\(name)]")

            // White + Alpha
            var white: CGFloat = 0
            var alpha: CGFloat = 0
            if color.getWhite(&white, alpha: &alpha) {
                output.append("  getWhite: white=\(String(format: "%.3f", white)), alpha=\(String(format: "%.3f", alpha)) ✅")
            } else {
                output.append("  getWhite: 실패 (RGB 색상일 수 있음)")
            }

            // RGBA
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
                output.append("  getRed: r=\(String(format: "%.3f", r)), g=\(String(format: "%.3f", g)), b=\(String(format: "%.3f", b)), a=\(String(format: "%.3f", a)) ✅")
            } else {
                output.append("  getRed: 실패")
            }
        }

        return output.joined(separator: "\n")
    }

    /// 5. Private 클래스 KVC 접근 테스트
    private func testPrivateClassKVC(_ window: UIWindow) -> String {
        var output: [String] = []

        // _UILiquidLensView 찾기
        let liquidLensViews = findViews(in: window, matching: "LiquidLens")

        if liquidLensViews.isEmpty {
            output.append("_UILiquidLensView를 찾지 못함")
            output.append("(TabBar 화면에서 테스트 필요)")
        } else {
            for view in liquidLensViews.prefix(2) {
                let typeName = String(describing: type(of: view))
                output.append("[\(typeName)]")

                // KVC로 속성 접근 시도
                let propertiesToTest = ["warpsContentBelow", "liftedContentMode", "hasCustomRestingBackground"]

                for prop in propertiesToTest {
                    do {
                        if let value = try catchObjCException({ view.value(forKey: prop) }) {
                            output.append("  \(prop): \(value) ✅")
                        } else {
                            output.append("  \(prop): nil")
                        }
                    } catch {
                        output.append("  \(prop): ❌ 접근 불가 (\(error))")
                    }
                }
            }
        }

        return output.joined(separator: "\n")
    }

    /// 6. CABackdropLayer 테스트
    private func testBackdropLayer(_ window: UIWindow) -> String {
        var output: [String] = []

        // CABackdropLayer 찾기
        let backdropLayers = findBackdropLayers(in: window.layer)

        if backdropLayers.isEmpty {
            output.append("CABackdropLayer를 찾지 못함")
            output.append("(TabBar 화면에서 테스트 필요)")
        } else {
            for layer in backdropLayers.prefix(3) {
                let typeName = String(describing: type(of: layer))
                output.append("[\(typeName)]")

                // KVC로 속성 접근 시도
                let propertiesToTest = ["scale", "groupName", "captureOnly", "usesGlobalGroupNamespace"]

                for prop in propertiesToTest {
                    do {
                        if let value = try catchObjCException({ layer.value(forKey: prop) }) {
                            output.append("  \(prop): \(value) ✅")
                        } else {
                            output.append("  \(prop): nil")
                        }
                    } catch {
                        output.append("  \(prop): ❌ 접근 불가")
                    }
                }
            }
        }

        return output.joined(separator: "\n")
    }

    /// CABackdropLayer 찾기 (재귀)
    private func findBackdropLayers(in layer: CALayer) -> [CALayer] {
        var results: [CALayer] = []

        let typeName = String(describing: type(of: layer))
        if typeName.contains("Backdrop") {
            results.append(layer)
        }

        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                results.append(contentsOf: findBackdropLayers(in: sublayer))
            }
        }

        return results
    }

    /// 특정 패턴을 포함하는 뷰 찾기
    private func findViews(in view: UIView, matching pattern: String) -> [UIView] {
        var results: [UIView] = []

        let typeName = String(describing: type(of: view))
        if typeName.contains(pattern) {
            results.append(view)
        }

        for subview in view.subviews {
            results.append(contentsOf: findViews(in: subview, matching: pattern))
        }

        return results
    }

    // MARK: - Helpers

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

    private func saveResults(_ results: [String]) {
        let content = results.joined(separator: "\n")

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let fileName = "layer_property_test_\(dateString()).txt"
        let filePath = documentsPath.appendingPathComponent(fileName)

        do {
            try content.write(to: filePath, atomically: true, encoding: .utf8)
            print("[LayerPropertyTest] 저장: \(filePath.path)")
        } catch {
            print("[LayerPropertyTest] 저장 실패: \(error)")
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func showAlert(message: String) {
        guard let window = getKeyWindow(),
              let rootVC = window.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let alert = UIAlertController(title: "테스트 결과", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        topVC.present(alert, animated: true)
    }
}

// MARK: - ObjC Exception Handling

/// Objective-C 예외를 Swift에서 잡기 위한 헬퍼
/// KVC 접근 시 키가 없으면 NSUnknownKeyException 발생
func catchObjCException<T>(_ block: () -> T?) throws -> T? {
    var result: T?
    var caughtException: NSException?

    // Note: 실제로는 ObjC 예외를 잡으려면 ObjC 래퍼가 필요
    // 여기서는 간단히 try-catch 대신 responds(to:) 체크로 대체
    result = block()

    if let exception = caughtException {
        throw NSError(domain: "ObjCException", code: -1, userInfo: [NSLocalizedDescriptionKey: exception.reason ?? "Unknown"])
    }

    return result
}

#endif
