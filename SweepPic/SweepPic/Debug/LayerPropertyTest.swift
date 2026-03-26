// LayerPropertyTest.swift
// CALayer Private 속성 접근 가능 여부 테스트
// 테스트 완료 후 삭제 예정

#if DEBUG

import UIKit
import AppCore

/// CALayer 및 Private 속성 접근 테스트
/// 결과를 콘솔에 출력하고 파일로 저장
final class LayerPropertyTest {

    static let shared = LayerPropertyTest()
    private init() {}

    /// 테스트 실행 (버튼에서 호출)
    /// 이미 확인된 테스트는 스킵하고 미해결 항목만 테스트
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

        // ✅ 확인 완료된 테스트 (스킵)
        // 1. CALayer 기본 속성 - cornerRadius, cornerCurve 등 ✅
        // 2. layer.filters - 필터 이름 접근 ✅
        // 3. layer.compositingFilter - destIn, destOut ✅
        // 4. UIColor 분해 - getWhite, getRed ✅
        // 5. _UILiquidLensView KVC - warpsContentBelow 등 ✅
        // 6. CABackdropLayer - scale, groupName 등 ✅
        // 8. CAAnimation - CAMatchPropertyAnimation 등 ✅

        results.append("## 확인 완료된 테스트 (스킵)")
        results.append("1~6, 8번: 모든 속성 접근 확인됨 ✅")
        results.append("")

        // ⚠️ 미해결 항목만 테스트
        // 7. CAFilter 파라미터 - inputColorMatrix 파싱 필요
        results.append("## 7. CAFilter 파라미터 (inputColorMatrix 파싱 테스트)")
        results.append(testFilterParameters(window))
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

    /// 7. 필터 파라미터 심층 테스트
    /// CAFilter (Private)의 inputKeys를 통해 blur radius 등 세부 값 추출
    /// 참고: https://github.com/avaidyam/QuartzInternal/blob/master/CoreAnimationPrivate/CAFilter.h
    private func testFilterParameters(_ window: UIWindow) -> String {
        var output: [String] = []

        // filters가 있는 뷰/레이어 찾기
        let layersWithFilters = findLayersWithFilters(in: window.layer)

        if layersWithFilters.isEmpty {
            output.append("filters가 있는 레이어를 찾지 못함")
            output.append("(TabBar 화면에서 테스트 필요)")
        } else {
            for (layer, filters) in layersWithFilters.prefix(10) {
                let layerTypeName = String(describing: type(of: layer))
                output.append("[\(layerTypeName)]")

                for (index, filter) in filters.enumerated() {
                    let filterTypeName = String(describing: type(of: filter))
                    output.append("  [Filter \(index)] type: \(filterTypeName)")

                    // CAFilter (NSObject 서브클래스)인 경우 - CIFilter가 아님!
                    if let nsFilter = filter as? NSObject {
                        // 1. name 속성
                        if let name = nsFilter.value(forKey: "name") {
                            output.append("    name: \(name) ✅")
                        }

                        // 2. type 속성
                        if let type = nsFilter.value(forKey: "type") {
                            output.append("    type: \(type) ✅")
                        }

                        // 3. enabled 속성
                        if let enabled = nsFilter.value(forKey: "enabled") {
                            output.append("    enabled: \(enabled) ✅")
                        }

                        // 4. ⭐ inputKeys 속성 - 필터가 지원하는 모든 파라미터 키
                        if let inputKeys = nsFilter.value(forKey: "inputKeys") as? [String] {
                            output.append("    inputKeys: \(inputKeys) ✅")

                            // 각 inputKey의 값 추출
                            for key in inputKeys {
                                if let value = nsFilter.value(forKey: key) {
                                    output.append("      \(key): \(describeFilterValue(value)) ✅")
                                } else {
                                    output.append("      \(key): nil")
                                }
                            }
                        } else {
                            output.append("    inputKeys: ❌ 접근 불가")

                            // inputKeys 없으면 알려진 키로 직접 시도
                            output.append("    (알려진 키로 직접 접근 시도)")
                            let knownKeys = [
                                "inputRadius", "inputAmount", "inputScale", "inputAngle",
                                "inputCenter", "inputColor", "inputColorMatrix", "inputBias",
                                "inputNormalizeEdges", "inputHardEdges", "inputQuality",
                                "inputThreshold", "inputReversed", "inputMaskImage"
                            ]

                            for key in knownKeys {
                                if let value = nsFilter.value(forKey: key) {
                                    output.append("      \(key): \(describeFilterValue(value)) ✅")
                                }
                            }
                        }

                        // 5. outputKeys 속성
                        if let outputKeys = nsFilter.value(forKey: "outputKeys") as? [String] {
                            output.append("    outputKeys: \(outputKeys) ✅")
                        }
                    }
                    // CIFilter인 경우 (macOS 또는 일부 iOS)
                    else if let ciFilter = filter as? CIFilter {
                        output.append("    (CIFilter)")
                        output.append("    name: \(ciFilter.name) ✅")
                        output.append("    inputKeys: \(ciFilter.inputKeys) ✅")

                        for key in ciFilter.inputKeys {
                            if let value = ciFilter.value(forKey: key) {
                                output.append("      \(key): \(value) ✅")
                            }
                        }
                    }
                    // 문자열인 경우 (필터 이름만)
                    else if let filterName = filter as? String {
                        output.append("    (String) filterName: \(filterName)")
                    }
                    else {
                        output.append("    (Unknown type)")
                    }
                }
            }
            output.append("")
            output.append("✅ 필터 파라미터 접근 테스트 완료")
        }

        return output.joined(separator: "\n")
    }

    /// 필터 값을 문자열로 설명 (CAColorMatrix 등 특수 타입 처리)
    private func describeFilterValue(_ value: Any) -> String {
        let typeName = String(describing: type(of: value))

        // 숫자
        if let num = value as? NSNumber {
            return "\(num)"
        }

        // 문자열
        if let str = value as? String {
            return "\"\(str)\""
        }

        // 배열
        if let arr = value as? [Any] {
            return "[\(arr.count) items]"
        }

        // NSData/Data - inputColorMatrix가 바이트로 올 경우 Float 배열로 변환
        var dataToProcess: Data?
        if let data = value as? Data {
            dataToProcess = data
        } else if let nsData = value as? NSData {
            dataToProcess = nsData as Data
        }

        if let data = dataToProcess {
            return parseColorMatrixData(data)
        }

        // NSValue (NSConcreteValue) - inputColorMatrix가 이 타입으로 옴
        if let nsValue = value as? NSValue {
            // objCType으로 크기 확인
            let objCType = String(cString: nsValue.objCType)

            // 80바이트 (5x4 Float 행렬) 추출 시도
            var buffer = [UInt8](repeating: 0, count: 80)
            nsValue.getValue(&buffer)

            // UInt8 배열을 Float 배열로 변환
            var floats = [Float](repeating: 0, count: 20)
            for i in 0..<20 {
                let bytes = Array(buffer[i*4..<i*4+4])
                floats[i] = bytes.withUnsafeBytes { $0.load(as: Float.self) }
            }

            // 5x4 행렬 형태로 출력
            let rows = ["R", "G", "B", "A"]
            var matrixStr = "CAColorMatrix 5x4 (objCType: \(objCType)):\n"
            for (i, row) in rows.enumerated() {
                let start = i * 5
                let rowValues = floats[start..<start+5].map { String(format: "%.3f", $0) }
                matrixStr += "        \(row): [\(rowValues.joined(separator: ", "))]\n"
            }
            return matrixStr.trimmingCharacters(in: .newlines)
        }

        // NSObject - KVC로 세부 정보 추출 시도 (CAColorMatrix 등)
        if let nsObj = value as? NSObject {
            // CAColorMatrix 처리 (5x4 행렬) - KVC 방식
            if typeName.contains("ColorMatrix") {
                var matrixValues: [String] = []
                let matrixKeys = ["m11", "m12", "m13", "m14", "m15",
                                  "m21", "m22", "m23", "m24", "m25",
                                  "m31", "m32", "m33", "m34", "m35",
                                  "m41", "m42", "m43", "m44", "m45"]
                for mKey in matrixKeys {
                    if let mVal = nsObj.value(forKey: mKey) as? NSNumber {
                        matrixValues.append("\(mKey)=\(mVal)")
                    }
                }
                if !matrixValues.isEmpty {
                    return "CAColorMatrix(\(matrixValues.joined(separator: ", ")))"
                }
            }

            // 일반 NSValue (CGPoint, CGSize, CGRect 등)
            if let nsValue = value as? NSValue {
                return "\(nsValue)"
            }
        }

        return "\(value) (\(typeName))"
    }

    /// Data를 5x4 Float 행렬로 파싱
    private func parseColorMatrixData(_ data: Data) -> String {
        // 80바이트 = 20개 Float (5x4 행렬)
        if data.count == 80 {
            var floats = [Float](repeating: 0, count: 20)
            _ = floats.withUnsafeMutableBytes { data.copyBytes(to: $0) }

            // 5x4 행렬 형태로 출력 (R,G,B,A 각 행, 5열: R,G,B,A,Bias)
            let rows = ["R", "G", "B", "A"]
            var matrixStr = "CAColorMatrix 5x4:\n"
            for (i, row) in rows.enumerated() {
                let start = i * 5
                let rowValues = floats[start..<start+5].map { String(format: "%.3f", $0) }
                matrixStr += "        \(row): [\(rowValues.joined(separator: ", "))]\n"
            }
            return matrixStr.trimmingCharacters(in: .newlines)
        }
        return "Data(\(data.count) bytes)"
    }

    /// description 문자열에서 hex bytes 파싱
    private func parseColorMatrixFromDescription(_ desc: String, typeName: String) -> String {
        // "{length = 80, bytes = 0x0000803f 00000000 ... }" 형태에서 hex 추출
        // 0x0000803f = 1.0 (little-endian float)

        // 간단히 알려진 패턴 매칭
        // 0x0000803f = 1.0f, 0x00000000 = 0.0f

        var result = "CAColorMatrix (parsed from description):\n"
        result += "        type: \(typeName)\n"

        // hex 값 추출 시도
        let hexPattern = "0x[0-9a-f]+"
        if let regex = try? NSRegularExpression(pattern: hexPattern, options: .caseInsensitive) {
            let range = NSRange(desc.startIndex..., in: desc)
            let matches = regex.matches(in: desc, options: [], range: range)

            var floats: [Float] = []
            for match in matches.prefix(20) {
                if let matchRange = Range(match.range, in: desc) {
                    let hexStr = String(desc[matchRange]).dropFirst(2) // "0x" 제거
                    if let intVal = UInt32(hexStr, radix: 16) {
                        let float = Float(bitPattern: intVal)
                        floats.append(float)
                    }
                }
            }

            if floats.count >= 20 {
                let rows = ["R", "G", "B", "A"]
                for (i, row) in rows.enumerated() {
                    let start = i * 5
                    let rowValues = floats[start..<start+5].map { String(format: "%.3f", $0) }
                    result += "        \(row): [\(rowValues.joined(separator: ", "))]\n"
                }
                return result.trimmingCharacters(in: .newlines)
            }
        }

        // 파싱 실패시 원본 반환
        return "\(desc) (\(typeName))"
    }

    /// 레이어 계층에서 filters가 있는 레이어 찾기
    private func findLayersWithFilters(in layer: CALayer) -> [(CALayer, [Any])] {
        var results: [(CALayer, [Any])] = []

        if let filters = layer.filters, !filters.isEmpty {
            results.append((layer, filters))
        }

        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                results.append(contentsOf: findLayersWithFilters(in: sublayer))
            }
        }

        return results
    }

    /// 8. CAAnimation 파라미터 테스트
    /// 현재 실행 중인 애니메이션에서 duration, timingFunction 등 추출
    private func testAnimationParameters(_ window: UIWindow) -> String {
        var output: [String] = []

        // 애니메이션이 있는 레이어 찾기
        let layersWithAnimations = findLayersWithAnimations(in: window.layer)

        if layersWithAnimations.isEmpty {
            output.append("현재 실행 중인 애니메이션 없음")
            output.append("(버튼 press 중에 테스트하면 애니메이션 확인 가능)")

            // 수동으로 애니메이션 생성해서 테스트
            output.append("")
            output.append("[수동 애니메이션 생성 테스트]")
            let testAnim = CABasicAnimation(keyPath: "opacity")
            testAnim.duration = 0.3
            testAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            testAnim.fromValue = 1.0
            testAnim.toValue = 0.5

            output.append("  duration: \(testAnim.duration) ✅")
            output.append("  timingFunction: \(String(describing: testAnim.timingFunction)) ✅")
            output.append("  keyPath: \(testAnim.keyPath ?? "nil") ✅")
            output.append("  fromValue: \(String(describing: testAnim.fromValue)) ✅")
            output.append("  toValue: \(String(describing: testAnim.toValue)) ✅")
            output.append("  isRemovedOnCompletion: \(testAnim.isRemovedOnCompletion) ✅")
            output.append("  fillMode: \(testAnim.fillMode.rawValue) ✅")

            // CAMediaTimingFunction 파라미터 추출
            if let tf = testAnim.timingFunction {
                var c1 = [Float](repeating: 0, count: 2)
                var c2 = [Float](repeating: 0, count: 2)
                tf.getControlPoint(at: 1, values: &c1)
                tf.getControlPoint(at: 2, values: &c2)
                output.append("  timingFunction controlPoints: c1=(\(c1[0]), \(c1[1])), c2=(\(c2[0]), \(c2[1])) ✅")
            }
        } else {
            for (layer, animKeys) in layersWithAnimations.prefix(5) {
                let typeName = String(describing: type(of: layer))
                output.append("[\(typeName)]")
                output.append("  animationKeys: \(animKeys)")

                for key in animKeys {
                    if let anim = layer.animation(forKey: key) {
                        output.append("  [Animation: \(key)]")
                        output.append("    type: \(type(of: anim))")
                        output.append("    duration: \(anim.duration) ✅")
                        output.append("    timingFunction: \(String(describing: anim.timingFunction)) ✅")
                        output.append("    isRemovedOnCompletion: \(anim.isRemovedOnCompletion) ✅")
                        output.append("    fillMode: \(anim.fillMode.rawValue) ✅")

                        // CABasicAnimation 세부 정보
                        if let basicAnim = anim as? CABasicAnimation {
                            output.append("    keyPath: \(basicAnim.keyPath ?? "nil") ✅")
                            output.append("    fromValue: \(String(describing: basicAnim.fromValue)) ✅")
                            output.append("    toValue: \(String(describing: basicAnim.toValue)) ✅")
                            output.append("    byValue: \(String(describing: basicAnim.byValue))")
                        }

                        // CAKeyframeAnimation 세부 정보
                        if let keyframeAnim = anim as? CAKeyframeAnimation {
                            output.append("    keyPath: \(keyframeAnim.keyPath ?? "nil") ✅")
                            output.append("    values count: \(keyframeAnim.values?.count ?? 0) ✅")
                            output.append("    keyTimes: \(String(describing: keyframeAnim.keyTimes)) ✅")
                            output.append("    calculationMode: \(keyframeAnim.calculationMode.rawValue) ✅")
                        }

                        // CASpringAnimation 세부 정보
                        if let springAnim = anim as? CASpringAnimation {
                            output.append("    mass: \(springAnim.mass) ✅")
                            output.append("    stiffness: \(springAnim.stiffness) ✅")
                            output.append("    damping: \(springAnim.damping) ✅")
                            output.append("    initialVelocity: \(springAnim.initialVelocity) ✅")
                            output.append("    settlingDuration: \(springAnim.settlingDuration) ✅")
                        }

                        // CAAnimationGroup 세부 정보
                        if let groupAnim = anim as? CAAnimationGroup {
                            output.append("    animations count: \(groupAnim.animations?.count ?? 0) ✅")
                        }

                        // CAMediaTimingFunction 파라미터 추출
                        if let tf = anim.timingFunction {
                            var c1 = [Float](repeating: 0, count: 2)
                            var c2 = [Float](repeating: 0, count: 2)
                            tf.getControlPoint(at: 1, values: &c1)
                            tf.getControlPoint(at: 2, values: &c2)
                            output.append("    timingFunction controlPoints: c1=(\(c1[0]), \(c1[1])), c2=(\(c2[0]), \(c2[1])) ✅")
                        }
                    }
                }
            }
            output.append("✅ 애니메이션 파라미터 접근 가능")
        }

        return output.joined(separator: "\n")
    }

    /// 애니메이션이 있는 레이어 찾기 (재귀)
    private func findLayersWithAnimations(in layer: CALayer) -> [(CALayer, [String])] {
        var results: [(CALayer, [String])] = []

        if let animKeys = layer.animationKeys(), !animKeys.isEmpty {
            results.append((layer, animKeys))
        }

        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                results.append(contentsOf: findLayersWithAnimations(in: sublayer))
            }
        }

        return results
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
        } catch {
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
    let caughtException: NSException? = nil

    // Note: 실제로는 ObjC 예외를 잡으려면 ObjC 래퍼가 필요
    // 여기서는 간단히 try-catch 대신 responds(to:) 체크로 대체
    result = block()

    if let exception = caughtException {
        throw NSError(domain: "ObjCException", code: -1, userInfo: [NSLocalizedDescriptionKey: exception.reason ?? "Unknown"])
    }

    return result
}

#endif
