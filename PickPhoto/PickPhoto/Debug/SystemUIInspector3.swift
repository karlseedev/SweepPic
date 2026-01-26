// SystemUIInspector3.swift
// iOS 26 시스템 UI 속성을 JSON으로 완전 덤프하는 디버그 유틸리티
// 목적: TabBar, NavigationBar 등을 100% 동일하게 재현하기 위한 속성 추출
// 사용 후 삭제 예정

#if DEBUG

import UIKit

// MARK: - JSON 출력용 구조체

/// 뷰 정보
struct ViewInfo: Codable {
    let className: String
    let address: String
    let frame: FrameInfo
    let bounds: FrameInfo
    let alpha: CGFloat
    let isHidden: Bool
    let clipsToBounds: Bool
    let backgroundColor: ColorInfo?
    let layer: LayerInfo
    let privateProperties: [String: String]?
    let children: [ViewInfo]
}

/// 프레임 정보
struct FrameInfo: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
}

/// 색상 정보
struct ColorInfo: Codable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
    let description: String
}

/// Point 정보
struct PointInfo: Codable {
    let x: CGFloat
    let y: CGFloat
}

/// Size 정보
struct SizeInfo: Codable {
    let width: CGFloat
    let height: CGFloat
}

/// Transform 정보 (CATransform3D)
struct TransformInfo: Codable {
    let m11: CGFloat
    let m12: CGFloat
    let m13: CGFloat
    let m14: CGFloat
    let m21: CGFloat
    let m22: CGFloat
    let m23: CGFloat
    let m24: CGFloat
    let m31: CGFloat
    let m32: CGFloat
    let m33: CGFloat
    let m34: CGFloat
    let m41: CGFloat
    let m42: CGFloat
    let m43: CGFloat
    let m44: CGFloat
    let isIdentity: Bool
}

/// 레이어 정보 (CALayer 전체 속성)
/// class로 선언 - 재귀 구조 (sublayers, mask) 때문
final class LayerInfo: Codable {
    // 기본 정보
    let className: String
    let name: String?

    // Geometry
    let frame: FrameInfo
    let bounds: FrameInfo
    let position: PointInfo
    let zPosition: CGFloat
    let anchorPoint: PointInfo
    let anchorPointZ: CGFloat
    let contentsScale: CGFloat

    // Transform
    let transform: TransformInfo
    let sublayerTransform: TransformInfo

    // Visual
    let isHidden: Bool
    let isDoubleSided: Bool
    let isGeometryFlipped: Bool
    let masksToBounds: Bool
    let isOpaque: Bool
    let opacity: Float
    let allowsGroupOpacity: Bool

    // Corner
    let cornerRadius: CGFloat
    let cornerCurve: String
    let maskedCorners: [String]

    // Border
    let borderWidth: CGFloat
    let borderColor: ColorInfo?
    let backgroundColor: ColorInfo?

    // Shadow
    let shadowColor: ColorInfo?
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let shadowOffset: SizeInfo

    // Contents
    let contentsGravity: String
    let contentsRect: FrameInfo
    let contentsCenter: FrameInfo
    let minificationFilter: String
    let magnificationFilter: String

    // Filters (핵심!)
    let filters: [FilterInfo]?
    let backgroundFilters: [FilterInfo]?
    let compositingFilter: String?

    // Mask
    let mask: LayerInfo?

    // Sublayers (재귀)
    let sublayers: [LayerInfo]?

    // Animations
    let animations: [AnimationInfo]?

    // Private 속성
    let backdropProperties: BackdropInfo?
    let privateProperties: [String: String]?

    init(className: String, name: String?, frame: FrameInfo, bounds: FrameInfo,
         position: PointInfo, zPosition: CGFloat, anchorPoint: PointInfo, anchorPointZ: CGFloat,
         contentsScale: CGFloat, transform: TransformInfo, sublayerTransform: TransformInfo,
         isHidden: Bool, isDoubleSided: Bool, isGeometryFlipped: Bool, masksToBounds: Bool,
         isOpaque: Bool, opacity: Float, allowsGroupOpacity: Bool, cornerRadius: CGFloat,
         cornerCurve: String, maskedCorners: [String], borderWidth: CGFloat, borderColor: ColorInfo?,
         backgroundColor: ColorInfo?, shadowColor: ColorInfo?, shadowOpacity: Float,
         shadowRadius: CGFloat, shadowOffset: SizeInfo, contentsGravity: String,
         contentsRect: FrameInfo, contentsCenter: FrameInfo, minificationFilter: String,
         magnificationFilter: String, filters: [FilterInfo]?, backgroundFilters: [FilterInfo]?,
         compositingFilter: String?, mask: LayerInfo?, sublayers: [LayerInfo]?,
         animations: [AnimationInfo]?, backdropProperties: BackdropInfo?,
         privateProperties: [String: String]?) {
        self.className = className
        self.name = name
        self.frame = frame
        self.bounds = bounds
        self.position = position
        self.zPosition = zPosition
        self.anchorPoint = anchorPoint
        self.anchorPointZ = anchorPointZ
        self.contentsScale = contentsScale
        self.transform = transform
        self.sublayerTransform = sublayerTransform
        self.isHidden = isHidden
        self.isDoubleSided = isDoubleSided
        self.isGeometryFlipped = isGeometryFlipped
        self.masksToBounds = masksToBounds
        self.isOpaque = isOpaque
        self.opacity = opacity
        self.allowsGroupOpacity = allowsGroupOpacity
        self.cornerRadius = cornerRadius
        self.cornerCurve = cornerCurve
        self.maskedCorners = maskedCorners
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.backgroundColor = backgroundColor
        self.shadowColor = shadowColor
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.contentsGravity = contentsGravity
        self.contentsRect = contentsRect
        self.contentsCenter = contentsCenter
        self.minificationFilter = minificationFilter
        self.magnificationFilter = magnificationFilter
        self.filters = filters
        self.backgroundFilters = backgroundFilters
        self.compositingFilter = compositingFilter
        self.mask = mask
        self.sublayers = sublayers
        self.animations = animations
        self.backdropProperties = backdropProperties
        self.privateProperties = privateProperties
    }
}

/// 필터 정보
struct FilterInfo: Codable {
    let name: String
    let type: String
    let enabled: Bool
    let parameters: [String: String]
}

/// CABackdropLayer 정보
struct BackdropInfo: Codable {
    let scale: CGFloat?
    let groupName: String?
    let captureOnly: Bool?
    let usesGlobalGroupNamespace: Bool?
}

/// Animation 정보
struct AnimationInfo: Codable {
    let key: String
    let className: String
    let duration: CGFloat
    let speed: Float
    let repeatCount: Float
    let autoreverses: Bool
    let fillMode: String
    let timingFunction: String?
    let keyPath: String?
}

/// 전체 덤프 결과 (내부용)
struct UIInspectorResult {
    let captureDate: String
    let iOSVersion: String
    let screenName: String
    let tabBars: [ViewInfo]
    let navigationBars: [ViewInfo]
    let toolbars: [ViewInfo]
    let floatingButtons: [ViewInfo]
}

/// 컴포넌트별 메타데이터
struct ComponentMeta: Codable {
    let captureDate: String
    let iOSVersion: String
    let screenName: String
}

/// 컴포넌트별 저장 결과
struct ComponentResult: Codable {
    let meta: ComponentMeta
    let views: [ViewInfo]
}

// MARK: - SystemUIInspector3

/// 시스템 UI JSON 덤프 인스펙터
final class SystemUIInspector3 {

    static let shared = SystemUIInspector3()
    private init() {}

    // MARK: - Properties

    private var debugButton: UIButton?
    private var inspectionCount = 0

    /// Private 클래스에서 추출할 속성 키
    private let liquidLensKeys = ["warpsContentBelow", "liftedContentMode", "hasCustomRestingBackground"]

    /// CAFilter에서 추출할 파라미터 키
    private let filterParamKeys = [
        "inputRadius", "inputAmount", "inputScale", "inputAngle",
        "inputNormalizeEdges", "inputHardEdges", "inputQuality",
        "inputThreshold", "inputReversed", "inputColorMatrix"
    ]

    // MARK: - Public API

    /// 플로팅 디버그 버튼 표시
    func showDebugButton() {
        guard debugButton == nil else { return }
        guard let window = getKeyWindow() else { return }

        let button = UIButton(type: .system)
        button.setTitle("JSON Dump", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 20
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 8
        button.layer.shadowOffset = CGSize(width: 0, height: 2)

        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(debugButtonTapped), for: .touchUpInside)

        window.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            button.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 100),
            button.widthAnchor.constraint(equalToConstant: 120),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])

        self.debugButton = button
        print("[SystemUIInspector3] 디버그 버튼 표시됨 - JSON 덤프")
    }

    /// 디버그 버튼 숨기기
    func hideDebugButton() {
        debugButton?.removeFromSuperview()
        debugButton = nil
    }

    // MARK: - Button Action

    @objc private func debugButtonTapped() {
        inspectionCount += 1

        debugButton?.setTitle("덤프 중...", for: .normal)
        debugButton?.isEnabled = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.performJSONDump()
            self?.debugButton?.setTitle("JSON Dump", for: .normal)
            self?.debugButton?.isEnabled = true
        }
    }

    // MARK: - JSON Dump

    /// JSON 덤프 실행
    private func performJSONDump() {
        guard let window = getKeyWindow() else {
            print("[SystemUIInspector3] Key Window를 찾을 수 없습니다.")
            return
        }

        // 시스템 UI 찾기
        let tabBars = findViews(ofType: UITabBar.self, in: window).map { inspectView($0) }
        let navBars = findViews(ofType: UINavigationBar.self, in: window).map { inspectView($0) }
        let toolbars = findViews(ofType: UIToolbar.self, in: window).map { inspectView($0) }
        let floatingButtons = findFloatingButtons(in: window).map { inspectView($0) }

        // 결과 생성
        let result = UIInspectorResult(
            captureDate: ISO8601DateFormatter().string(from: Date()),
            iOSVersion: UIDevice.current.systemVersion,
            screenName: getCurrentScreenName(),
            tabBars: tabBars,
            navigationBars: navBars,
            toolbars: toolbars,
            floatingButtons: floatingButtons
        )

        // JSON 저장
        saveToJSON(result)
    }

    // MARK: - Sanitize Helpers

    /// NaN, Infinity 값을 안전하게 처리
    private func sanitize(_ value: CGFloat) -> CGFloat {
        if value.isNaN || value.isInfinite { return 0 }
        return value
    }

    /// Float 버전
    private func sanitize(_ value: Float) -> Float {
        if value.isNaN || value.isInfinite { return 0 }
        return value
    }

    /// CGRect -> FrameInfo (sanitized)
    private func sanitizeFrame(_ rect: CGRect) -> FrameInfo {
        return FrameInfo(CGRect(
            x: sanitize(rect.origin.x),
            y: sanitize(rect.origin.y),
            width: sanitize(rect.width),
            height: sanitize(rect.height)
        ))
    }

    // MARK: - View Inspection

    /// 뷰 속성 추출
    private func inspectView(_ view: UIView, maxDepth: Int = 10, currentDepth: Int = 0) -> ViewInfo {
        let typeName = String(describing: type(of: view))

        // 자식 뷰 (깊이 제한)
        var children: [ViewInfo] = []
        if currentDepth < maxDepth {
            children = view.subviews.map { inspectView($0, maxDepth: maxDepth, currentDepth: currentDepth + 1) }
        }

        // Private 속성 추출
        var privateProps: [String: String]? = nil
        if isPrivateView(typeName) {
            privateProps = extractPrivateViewProperties(view, typeName: typeName)
        }

        return ViewInfo(
            className: typeName,
            address: String(format: "%p", Unmanaged.passUnretained(view).toOpaque().hashValue),
            frame: sanitizeFrame(view.frame),
            bounds: sanitizeFrame(view.bounds),
            alpha: sanitize(view.alpha),
            isHidden: view.isHidden,
            clipsToBounds: view.clipsToBounds,
            backgroundColor: extractColor(view.backgroundColor),
            layer: inspectLayer(view.layer),
            privateProperties: privateProps,
            children: children
        )
    }

    /// 레이어 속성 추출 (전체)
    private func inspectLayer(_ layer: CALayer, maxDepth: Int = 10, currentDepth: Int = 0) -> LayerInfo {
        let typeName = String(describing: type(of: layer))

        // filters 추출
        var filters: [FilterInfo]? = nil
        if let layerFilters = layer.filters, !layerFilters.isEmpty {
            filters = layerFilters.compactMap { extractFilterInfo($0) }
        }

        // backgroundFilters 추출
        var backgroundFilters: [FilterInfo]? = nil
        if let bgFilters = layer.backgroundFilters, !bgFilters.isEmpty {
            backgroundFilters = bgFilters.compactMap { extractFilterInfo($0) }
        }

        // compositingFilter 추출
        var compositingFilter: String? = nil
        if let compFilter = layer.compositingFilter {
            compositingFilter = String(describing: compFilter)
        }

        // mask 레이어 추출 (재귀, 깊이 제한)
        var maskLayer: LayerInfo? = nil
        if let mask = layer.mask, currentDepth < maxDepth {
            maskLayer = inspectLayer(mask, maxDepth: maxDepth, currentDepth: currentDepth + 1)
        }

        // sublayers 추출 (재귀, 깊이 제한)
        var sublayersInfo: [LayerInfo]? = nil
        if let sublayers = layer.sublayers, !sublayers.isEmpty, currentDepth < maxDepth {
            sublayersInfo = sublayers.map { inspectLayer($0, maxDepth: maxDepth, currentDepth: currentDepth + 1) }
        }

        // animations 추출
        var animations: [AnimationInfo]? = nil
        if let animKeys = layer.animationKeys(), !animKeys.isEmpty {
            animations = animKeys.compactMap { key in
                guard let anim = layer.animation(forKey: key) else { return nil }
                return extractAnimationInfo(key: key, animation: anim)
            }
        }

        // CABackdropLayer 등 Private 속성
        var backdropProps: BackdropInfo? = nil
        var privateProps: [String: String]? = nil
        if typeName.contains("Backdrop") {
            backdropProps = extractBackdropProperties(layer)
        }
        privateProps = extractPrivateLayerProperties(layer, typeName: typeName)

        // maskedCorners 추출
        var maskedCornersArray: [String] = []
        if layer.maskedCorners.contains(.layerMinXMinYCorner) { maskedCornersArray.append("topLeft") }
        if layer.maskedCorners.contains(.layerMaxXMinYCorner) { maskedCornersArray.append("topRight") }
        if layer.maskedCorners.contains(.layerMinXMaxYCorner) { maskedCornersArray.append("bottomLeft") }
        if layer.maskedCorners.contains(.layerMaxXMaxYCorner) { maskedCornersArray.append("bottomRight") }

        return LayerInfo(
            className: typeName,
            name: layer.name,

            // Geometry
            frame: sanitizeFrame(layer.frame),
            bounds: sanitizeFrame(layer.bounds),
            position: PointInfo(x: sanitize(layer.position.x), y: sanitize(layer.position.y)),
            zPosition: sanitize(layer.zPosition),
            anchorPoint: PointInfo(x: sanitize(layer.anchorPoint.x), y: sanitize(layer.anchorPoint.y)),
            anchorPointZ: sanitize(layer.anchorPointZ),
            contentsScale: sanitize(layer.contentsScale),

            // Transform
            transform: extractTransform(layer.transform),
            sublayerTransform: extractTransform(layer.sublayerTransform),

            // Visual
            isHidden: layer.isHidden,
            isDoubleSided: layer.isDoubleSided,
            isGeometryFlipped: layer.isGeometryFlipped,
            masksToBounds: layer.masksToBounds,
            isOpaque: layer.isOpaque,
            opacity: sanitize(layer.opacity),
            allowsGroupOpacity: layer.allowsGroupOpacity,

            // Corner
            cornerRadius: sanitize(layer.cornerRadius),
            cornerCurve: layer.cornerCurve.rawValue,
            maskedCorners: maskedCornersArray,

            // Border
            borderWidth: sanitize(layer.borderWidth),
            borderColor: layer.borderColor.flatMap { extractCGColor($0) },
            backgroundColor: layer.backgroundColor.flatMap { extractCGColor($0) },

            // Shadow
            shadowColor: layer.shadowColor.flatMap { extractCGColor($0) },
            shadowOpacity: sanitize(layer.shadowOpacity),
            shadowRadius: sanitize(layer.shadowRadius),
            shadowOffset: SizeInfo(width: sanitize(layer.shadowOffset.width), height: sanitize(layer.shadowOffset.height)),

            // Contents
            contentsGravity: layer.contentsGravity.rawValue,
            contentsRect: sanitizeFrame(CGRect(origin: CGPoint(x: layer.contentsRect.origin.x, y: layer.contentsRect.origin.y),
                                                size: CGSize(width: layer.contentsRect.width, height: layer.contentsRect.height))),
            contentsCenter: sanitizeFrame(CGRect(origin: CGPoint(x: layer.contentsCenter.origin.x, y: layer.contentsCenter.origin.y),
                                                  size: CGSize(width: layer.contentsCenter.width, height: layer.contentsCenter.height))),
            minificationFilter: layer.minificationFilter.rawValue,
            magnificationFilter: layer.magnificationFilter.rawValue,

            // Filters
            filters: filters,
            backgroundFilters: backgroundFilters,
            compositingFilter: compositingFilter,

            // Mask
            mask: maskLayer,

            // Sublayers
            sublayers: sublayersInfo,

            // Animations
            animations: animations,

            // Private
            backdropProperties: backdropProps,
            privateProperties: privateProps
        )
    }

    /// CATransform3D 추출
    private func extractTransform(_ t: CATransform3D) -> TransformInfo {
        return TransformInfo(
            m11: sanitize(t.m11), m12: sanitize(t.m12), m13: sanitize(t.m13), m14: sanitize(t.m14),
            m21: sanitize(t.m21), m22: sanitize(t.m22), m23: sanitize(t.m23), m24: sanitize(t.m24),
            m31: sanitize(t.m31), m32: sanitize(t.m32), m33: sanitize(t.m33), m34: sanitize(t.m34),
            m41: sanitize(t.m41), m42: sanitize(t.m42), m43: sanitize(t.m43), m44: sanitize(t.m44),
            isIdentity: CATransform3DIsIdentity(t)
        )
    }

    /// CAAnimation 정보 추출
    private func extractAnimationInfo(key: String, animation: CAAnimation) -> AnimationInfo {
        let typeName = String(describing: type(of: animation))

        var keyPath: String? = nil
        if let propAnim = animation as? CAPropertyAnimation {
            keyPath = propAnim.keyPath
        }

        var timingFuncName: String? = nil
        if let tf = animation.timingFunction {
            timingFuncName = String(describing: tf)
        }

        return AnimationInfo(
            key: key,
            className: typeName,
            duration: sanitize(animation.duration),
            speed: sanitize(animation.speed),
            repeatCount: sanitize(animation.repeatCount),
            autoreverses: animation.autoreverses,
            fillMode: animation.fillMode.rawValue,
            timingFunction: timingFuncName,
            keyPath: keyPath
        )
    }

    /// Private 레이어 속성 추출 (알려진 키들)
    private func extractPrivateLayerProperties(_ layer: CALayer, typeName: String) -> [String: String]? {
        var props: [String: String] = [:]
        let nsLayer = layer as NSObject

        // 알려진 Private 속성들 시도
        let privateKeys = [
            "allowsGroupBlending",
            "continuousCorners",
            "disableUpdateMask",
            "inheritsTintFromSuperlayer",
            "preloadsCache",
            "rasterizationPrefersDisplayCompositing",
            "wantsExtendedDynamicRangeContent"
        ]

        for key in privateKeys {
            if let value = nsLayer.value(forKey: key) {
                props[key] = String(describing: value)
            }
        }

        return props.isEmpty ? nil : props
    }

    // MARK: - Color Extraction

    /// UIColor 추출
    private func extractColor(_ color: UIColor?) -> ColorInfo? {
        guard let color = color else { return nil }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        return ColorInfo(
            red: sanitize(r),
            green: sanitize(g),
            blue: sanitize(b),
            alpha: sanitize(a),
            description: color.description
        )
    }

    /// CGColor 추출
    private func extractCGColor(_ cgColor: CGColor) -> ColorInfo? {
        guard let components = cgColor.components else { return nil }

        if components.count >= 4 {
            return ColorInfo(
                red: sanitize(components[0]),
                green: sanitize(components[1]),
                blue: sanitize(components[2]),
                alpha: sanitize(components[3]),
                description: "rgba"
            )
        } else if components.count >= 2 {
            return ColorInfo(
                red: sanitize(components[0]),
                green: sanitize(components[0]),
                blue: sanitize(components[0]),
                alpha: sanitize(components[1]),
                description: "gray"
            )
        }
        return nil
    }

    // MARK: - Filter Extraction

    /// CAFilter 정보 추출
    private func extractFilterInfo(_ filter: Any) -> FilterInfo? {
        guard let nsFilter = filter as? NSObject else { return nil }

        let name = (nsFilter.value(forKey: "name") as? String) ?? "unknown"
        let type = (nsFilter.value(forKey: "type") as? String) ?? "unknown"
        let enabled = (nsFilter.value(forKey: "enabled") as? Bool) ?? true

        // 파라미터 추출
        var params: [String: String] = [:]
        for key in filterParamKeys {
            if let value = nsFilter.value(forKey: key) {
                if key == "inputColorMatrix", let nsValue = value as? NSValue {
                    params[key] = parseColorMatrix(nsValue)
                } else {
                    params[key] = String(describing: value)
                }
            }
        }

        return FilterInfo(name: name, type: type, enabled: enabled, parameters: params)
    }

    /// CAColorMatrix 파싱
    private func parseColorMatrix(_ nsValue: NSValue) -> String {
        var buffer = [UInt8](repeating: 0, count: 80)
        nsValue.getValue(&buffer)

        var floats = [Float](repeating: 0, count: 20)
        for i in 0..<20 {
            let bytes = Array(buffer[i*4..<i*4+4])
            floats[i] = bytes.withUnsafeBytes { $0.load(as: Float.self) }
        }

        // 5x4 행렬을 문자열로
        let rows = ["R", "G", "B", "A"]
        var result = "{"
        for (i, row) in rows.enumerated() {
            let start = i * 5
            let rowValues = floats[start..<start+5].map { String(format: "%.3f", $0) }
            result += "\"\(row)\":[\(rowValues.joined(separator: ","))]"
            if i < 3 { result += "," }
        }
        result += "}"
        return result
    }

    // MARK: - Private Properties Extraction

    /// Private 뷰 여부 확인
    private func isPrivateView(_ typeName: String) -> Bool {
        return typeName.hasPrefix("_") ||
               typeName.contains("Glass") ||
               typeName.contains("Liquid") ||
               typeName.contains("Platter") ||
               typeName.contains("Backdrop") ||
               typeName.contains("Portal")
    }

    /// Private 뷰 속성 추출
    private func extractPrivateViewProperties(_ view: UIView, typeName: String) -> [String: String] {
        var props: [String: String] = [:]

        // _UILiquidLensView
        if typeName.contains("LiquidLens") {
            for key in liquidLensKeys {
                if let value = view.value(forKey: key) {
                    props[key] = String(describing: value)
                }
            }
        }

        return props
    }

    /// CABackdropLayer 속성 추출
    private func extractBackdropProperties(_ layer: CALayer) -> BackdropInfo {
        let nsLayer = layer as NSObject

        var scale: CGFloat? = nil
        if let rawScale = nsLayer.value(forKey: "scale") as? CGFloat {
            scale = sanitize(rawScale)
        }

        return BackdropInfo(
            scale: scale,
            groupName: nsLayer.value(forKey: "groupName") as? String,
            captureOnly: nsLayer.value(forKey: "captureOnly") as? Bool,
            usesGlobalGroupNamespace: nsLayer.value(forKey: "usesGlobalGroupNamespace") as? Bool
        )
    }

    // MARK: - View Finding

    /// Key Window 가져오기
    private func getKeyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    /// 특정 타입의 뷰 찾기
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

    /// 플로팅 버튼 찾기 (TabBar/NavBar 외부의 PlatterView)
    private func findFloatingButtons(in window: UIWindow) -> [UIView] {
        var results: [UIView] = []
        let bars = findViews(ofType: UITabBar.self, in: window) as [UIView] +
                   findViews(ofType: UINavigationBar.self, in: window) as [UIView] +
                   findViews(ofType: UIToolbar.self, in: window) as [UIView]

        func searchRecursively(_ view: UIView) {
            let typeName = String(describing: type(of: view))

            // Bar 내부는 제외
            for bar in bars {
                if view.isDescendant(of: bar) { return }
            }

            // PlatterView 또는 GlassInteractionView
            if typeName.contains("Platter") || typeName.contains("GlassInteraction") {
                results.append(view)
                return
            }

            for subview in view.subviews {
                searchRecursively(subview)
            }
        }

        searchRecursively(window)
        return results
    }

    /// 현재 화면 이름 추출
    private func getCurrentScreenName() -> String {
        guard let window = getKeyWindow(),
              let rootVC = window.rootViewController else {
            return "Unknown"
        }

        // TabBarController인 경우
        if let tabVC = rootVC as? UITabBarController,
           let selectedVC = tabVC.selectedViewController {
            return String(describing: type(of: selectedVC))
        }

        // NavigationController인 경우
        if let navVC = rootVC as? UINavigationController,
           let topVC = navVC.topViewController {
            return String(describing: type(of: topVC))
        }

        return String(describing: type(of: rootVC))
    }

    // MARK: - File Saving

    /// JSON 파일 저장 (컴포넌트별 4개 파일)
    private func saveToJSON(_ result: UIInspectorResult) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[SystemUIInspector3] Documents 폴더를 찾을 수 없습니다.")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        // 공통 메타데이터
        let meta = ComponentMeta(
            captureDate: result.captureDate,
            iOSVersion: result.iOSVersion,
            screenName: result.screenName
        )

        var savedFiles: [(name: String, size: Int)] = []

        do {
            // 1. TabBar
            if !result.tabBars.isEmpty {
                let tabBarResult = ComponentResult(meta: meta, views: result.tabBars)
                let fileName = "\(timestamp)_tabbar.json"
                let data = try encoder.encode(tabBarResult)
                try data.write(to: documentsPath.appendingPathComponent(fileName))
                savedFiles.append((fileName, data.count))
            }

            // 2. NavigationBar
            if !result.navigationBars.isEmpty {
                let navBarResult = ComponentResult(meta: meta, views: result.navigationBars)
                let fileName = "\(timestamp)_navbar.json"
                let data = try encoder.encode(navBarResult)
                try data.write(to: documentsPath.appendingPathComponent(fileName))
                savedFiles.append((fileName, data.count))
            }

            // 3. Toolbar
            if !result.toolbars.isEmpty {
                let toolbarResult = ComponentResult(meta: meta, views: result.toolbars)
                let fileName = "\(timestamp)_toolbar.json"
                let data = try encoder.encode(toolbarResult)
                try data.write(to: documentsPath.appendingPathComponent(fileName))
                savedFiles.append((fileName, data.count))
            }

            // 4. FloatingButtons
            if !result.floatingButtons.isEmpty {
                let floatingResult = ComponentResult(meta: meta, views: result.floatingButtons)
                let fileName = "\(timestamp)_floating.json"
                let data = try encoder.encode(floatingResult)
                try data.write(to: documentsPath.appendingPathComponent(fileName))
                savedFiles.append((fileName, data.count))
            }

            // 로그 출력
            print("")
            print("==================================================")
            print("  SystemUIInspector3 JSON 덤프 완료")
            print("==================================================")
            print("")
            print("경로: \(documentsPath.path)")
            print("")
            for file in savedFiles {
                print("  \(file.name) (\(file.size / 1024)KB)")
            }
            print("")

            // 알림
            showSaveAlert(files: savedFiles.map { $0.name })

        } catch {
            print("[SystemUIInspector3] JSON 저장 실패: \(error)")
        }
    }

    /// 저장 완료 알림
    private func showSaveAlert(files: [String]) {
        guard let window = getKeyWindow(),
              let rootVC = window.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let fileList = files.joined(separator: "\n")
        let alert = UIAlertController(
            title: "JSON 덤프 완료 (\(files.count)개)",
            message: "\(fileList)\n\n시뮬레이터 Documents 폴더에 저장됨",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "확인", style: .default))
        topVC.present(alert, animated: true)
    }
}

#endif
