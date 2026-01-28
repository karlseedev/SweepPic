// SystemUIInspector3.swift
// iOS 26 시스템 UI 속성을 JSON으로 완전 덤프하는 디버그 유틸리티
// 목적: TabBar, NavigationBar 등을 100% 동일하게 재현하기 위한 속성 추출
// 사용 후 삭제 예정
//
// 출력 파일:
// - {timestamp}_{component}_filters.json    : 필터만 (경로 + 파라미터)
// - {timestamp}_{component}_animations.json : 애니메이션만
// - {timestamp}_{component}_structure.json  : 계층 요약 (깊이 3)
// - {timestamp}_{component}_full_N.json     : 전체 데이터 (2000줄씩 분할)

#if DEBUG

import UIKit
import AppCore

// MARK: - 기본 구조체

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
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat
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

// MARK: - 필터/애니메이션 추출용 구조체

/// 필터 엔트리 (경로 포함)
struct FilterEntry: Codable {
    let path: String           // 예: "UITabBar > _UITabBarPlatterView > layer > sublayers[0]"
    let filterName: String     // 예: "colorMatrix"
    let filterType: String
    let enabled: Bool
    let parameters: [String: String]
    let respondingKeys: [String]?  // 응답하는 키 목록 (디버그용)
}

/// 애니메이션 엔트리 (경로 포함)
struct AnimationEntry: Codable {
    let path: String
    let key: String
    let className: String
    let duration: CGFloat
    let keyPath: String?
}

/// 필터 파일 결과
struct FiltersResult: Codable {
    let meta: ComponentMeta
    let filters: [FilterEntry]
}

/// 애니메이션 파일 결과
struct AnimationsResult: Codable {
    let meta: ComponentMeta
    let animations: [AnimationEntry]
}

// MARK: - 구조 요약용 구조체 (간소화)

/// 뷰 요약 (structure용)
struct ViewSummary: Codable {
    let className: String
    let frame: FrameInfo
    let layerClass: String
    let hasFilters: Bool
    let hasAnimations: Bool
    let childCount: Int
    let children: [ViewSummary]?  // 깊이 제한
}

/// 구조 파일 결과
struct StructureResult: Codable {
    let meta: ComponentMeta
    let views: [ViewSummary]
}

// MARK: - 전체 데이터용 구조체 (기본값 생략)

/// 뷰 정보 (전체, 기본값 생략)
struct ViewInfo: Codable {
    let cls: String              // className 축약
    let frame: FrameInfo
    let alpha: CGFloat?          // 1.0이면 생략
    let hidden: Bool?            // false면 생략
    let clips: Bool?             // false면 생략
    let bgColor: ColorInfo?
    let layer: LayerInfo
    let pvt: [String: String]?   // privateProperties 축약
    let sub: [ViewInfo]?         // children -> sub 축약
}

/// 레이어 정보 (전체, 기본값 생략)
final class LayerInfo: Codable {
    let cls: String              // className 축약
    let name: String?

    // Geometry (기본값 아닌 것만)
    let frame: FrameInfo
    let zPos: CGFloat?           // 0이면 생략
    let anchor: PointInfo?       // (0.5, 0.5)면 생략
    let anchorZ: CGFloat?        // 0이면 생략
    let scale: CGFloat?          // contentsScale, 기본값이면 생략

    // Transform (identity 아닐 때만)
    let transform: [CGFloat]?    // 16개 값, identity면 생략
    let subTransform: [CGFloat]? // sublayerTransform

    // Visual (기본값 아닌 것만)
    let hidden: Bool?
    let opacity: Float?          // 1.0이면 생략
    let groupOpacity: Bool?      // true면 생략

    // Corner (기본값 아닌 것만)
    let cornerRadius: CGFloat?   // 0이면 생략
    let cornerCurve: String?     // circular면 생략
    let maskedCorners: [String]? // 전부면 생략

    // Border/Background (기본값 아닌 것만)
    let borderW: CGFloat?        // 0이면 생략
    let borderColor: ColorInfo?
    let bgColor: ColorInfo?

    // Shadow (기본값 아닌 것만)
    let shadowColor: ColorInfo?
    let shadowOpacity: Float?    // 0이면 생략
    let shadowRadius: CGFloat?   // 3이면 생략 (기본값)
    let shadowOffset: SizeInfo?  // (0,-3)이면 생략

    // Filters (핵심!)
    let filters: [FilterInfo]?
    let bgFilters: [FilterInfo]?
    let compFilter: String?      // compositingFilter

    // Mask & Sublayers
    let mask: LayerInfo?
    let sublayers: [LayerInfo]?

    // Animations
    let anims: [AnimInfo]?

    // Private
    let backdrop: BackdropInfo?
    let portal: PortalInfo?      // CAPortalLayer 전용
    let sdf: SDFInfo?            // CASDFLayer 전용
    let shadowAll: ShadowAllInfo?  // innerShadowView용 전체 shadow 정보
    let pvt: [String: String]?

    // 추가 속성 (기본값 아닌 것만)
    let masksToBounds: Bool?     // false면 생략
    let hasContents: Bool?       // nil이면 생략, 있으면 true
    let contentsGravity: String? // resize면 생략
    let contentsScale: CGFloat?  // 화면 스케일이면 생략

    init(cls: String, name: String?, frame: FrameInfo, zPos: CGFloat?, anchor: PointInfo?,
         anchorZ: CGFloat?, scale: CGFloat?, transform: [CGFloat]?, subTransform: [CGFloat]?,
         hidden: Bool?, opacity: Float?, groupOpacity: Bool?, cornerRadius: CGFloat?,
         cornerCurve: String?, maskedCorners: [String]?, borderW: CGFloat?, borderColor: ColorInfo?,
         bgColor: ColorInfo?, shadowColor: ColorInfo?, shadowOpacity: Float?, shadowRadius: CGFloat?,
         shadowOffset: SizeInfo?, filters: [FilterInfo]?, bgFilters: [FilterInfo]?, compFilter: String?,
         mask: LayerInfo?, sublayers: [LayerInfo]?, anims: [AnimInfo]?, backdrop: BackdropInfo?,
         portal: PortalInfo?, sdf: SDFInfo?, shadowAll: ShadowAllInfo?, pvt: [String: String]?,
         masksToBounds: Bool?, hasContents: Bool?, contentsGravity: String?, contentsScale: CGFloat?) {
        self.cls = cls; self.name = name; self.frame = frame; self.zPos = zPos
        self.anchor = anchor; self.anchorZ = anchorZ; self.scale = scale
        self.transform = transform; self.subTransform = subTransform
        self.hidden = hidden; self.opacity = opacity; self.groupOpacity = groupOpacity
        self.cornerRadius = cornerRadius; self.cornerCurve = cornerCurve; self.maskedCorners = maskedCorners
        self.borderW = borderW; self.borderColor = borderColor; self.bgColor = bgColor
        self.shadowColor = shadowColor; self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius; self.shadowOffset = shadowOffset
        self.filters = filters; self.bgFilters = bgFilters; self.compFilter = compFilter
        self.mask = mask; self.sublayers = sublayers; self.anims = anims
        self.backdrop = backdrop; self.portal = portal; self.sdf = sdf; self.shadowAll = shadowAll; self.pvt = pvt
        self.masksToBounds = masksToBounds; self.hasContents = hasContents
        self.contentsGravity = contentsGravity; self.contentsScale = contentsScale
    }
}

/// 필터 정보
struct FilterInfo: Codable {
    let name: String
    let type: String
    let params: [String: String]?  // parameters 축약
    let respondingKeys: [String]?  // 응답하는 키 목록 (디버그용)
}

/// 애니메이션 정보
struct AnimInfo: Codable {
    let key: String
    let cls: String
    let dur: CGFloat           // duration 축약
    let keyPath: String?
}

/// CABackdropLayer 정보
struct BackdropInfo: Codable {
    let scale: CGFloat?
    let groupName: String?
    let captureOnly: Bool?
    // 추가 속성
    let blurRadius: CGFloat?
    let saturation: CGFloat?
    let zoom: CGFloat?
}

/// CAPortalLayer 정보
struct PortalInfo: Codable {
    let sourceLayerClass: String?
    let sourceLayerName: String?      // sourceLayer.name
    let sourceLayerFrame: FrameInfo?  // sourceLayer.frame
    let hidesSourceLayer: Bool?
    let matchesOpacity: Bool?
    let matchesPosition: Bool?
    let matchesTransform: Bool?
}

/// innerShadowView용 전체 shadow 정보 (기본값 포함)
struct ShadowAllInfo: Codable {
    let shadowColor: ColorInfo?
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let shadowOffset: SizeInfo
    let shadowPath: String?  // 타입만 기록
}

/// CASDFLayer 정보
struct SDFInfo: Codable {
    let shape: String?
    let fillColor: ColorInfo?
    let strokeColor: ColorInfo?
    let strokeWidth: CGFloat?
    // 추가 속성
    let sdfPath: String?       // path 데이터
    let cornerRadius: CGFloat?
    let fillRule: String?
    let respondingKeys: [String]?  // responds(to:)가 true인 키들
    let keyValues: [String: String]?  // 실제 값이 있는 키-값 쌍
}

/// 메타데이터
struct ComponentMeta: Codable {
    let date: String
    let iOS: String
    let screen: String
}

/// 전체 데이터 파일 결과
struct FullDataResult: Codable {
    let meta: ComponentMeta
    let part: Int
    let totalParts: Int
    let views: [ViewInfo]
}

// MARK: - SystemUIInspector3

final class SystemUIInspector3 {

    static let shared = SystemUIInspector3()
    private init() {}

    // MARK: - Properties

    private var debugButton: UIButton?
    private var inspectionCount = 0

    private let filterParamKeys = [
        // 기본 파라미터
        "inputRadius", "inputAmount", "inputScale", "inputAngle",
        "inputNormalizeEdges", "inputHardEdges", "inputQuality",
        "inputThreshold", "inputReversed", "inputColorMatrix",
        // 추가 파라미터 (displacementMap, opacityPair 등)
        "inputImage", "inputScaleX", "inputScaleY", "inputCenter",
        "inputOpacity", "inputOpacity0", "inputOpacity1",
        "inputSaturation", "inputBrightness", "inputContrast",
        "inputMaskImage", "inputDisplacementImage",
        // opacityPair 추정 키
        "opacity", "opacity0", "opacity1", "inputOpacityPair",
        "firstOpacity", "secondOpacity", "fromOpacity", "toOpacity",
        // displacementMap 추정 키
        "displacementScale", "inputDisplacementScale", "mapScale",
        "inputXScale", "inputYScale", "inputOffset", "inputWarp",
        // variableBlur 추정 키
        "inputMask", "inputGradientImage", "inputMaskImage",
        // 일반적인 키
        "enabled", "cachesInputImage", "value", "values"
    ]

    private let maxLinesPerFile = 2000

    // MARK: - Public API

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
        Log.print("[SystemUIInspector3] 디버그 버튼 표시됨")
    }

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

    private func performJSONDump() {
        guard let window = getKeyWindow() else {
            Log.print("[SystemUIInspector3] Key Window를 찾을 수 없습니다.")
            return
        }

        let meta = ComponentMeta(
            date: ISO8601DateFormatter().string(from: Date()),
            iOS: UIDevice.current.systemVersion,
            screen: getCurrentScreenName()
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        var savedFiles: [String] = []

        // TabBar
        let tabBars = findViews(ofType: UITabBar.self, in: window)
        if !tabBars.isEmpty {
            let files = saveComponent(views: tabBars, name: "tabbar", timestamp: timestamp, meta: meta)
            savedFiles.append(contentsOf: files)
        }

        // NavigationBar
        let navBars = findViews(ofType: UINavigationBar.self, in: window)
        if !navBars.isEmpty {
            let files = saveComponent(views: navBars, name: "navbar", timestamp: timestamp, meta: meta)
            savedFiles.append(contentsOf: files)
        }

        // Toolbar
        let toolbars = findViews(ofType: UIToolbar.self, in: window)
        if !toolbars.isEmpty {
            let files = saveComponent(views: toolbars, name: "toolbar", timestamp: timestamp, meta: meta)
            savedFiles.append(contentsOf: files)
        }

        // 전체 뷰 계층 (rootViewController.view)
        // 커스텀 뷰(GlassButton 등)의 iOS 26 스타일 실측용
        if let rootVC = window.rootViewController {
            let rootView = rootVC.view!
            let files = saveComponent(views: [rootView], name: "allviews", timestamp: timestamp, meta: meta)
            savedFiles.append(contentsOf: files)
        }

        // 로그
        print("")
        print("==================================================")
        print("  SystemUIInspector3 JSON 덤프 완료")
        print("==================================================")
        for file in savedFiles {
            print("  \(file)")
        }
        print("")

        showSaveAlert(files: savedFiles)
    }

    // MARK: - Component 저장

    private func saveComponent(views: [UIView], name: String, timestamp: String, meta: ComponentMeta) -> [String] {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }

        var savedFiles: [String] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // 1. Filters 추출 및 저장
        var allFilters: [FilterEntry] = []
        for view in views {
            extractFilters(from: view, path: name, filters: &allFilters)
        }
        if !allFilters.isEmpty {
            let result = FiltersResult(meta: meta, filters: allFilters)
            if let data = try? encoder.encode(result) {
                let fileName = "\(timestamp)_\(name)_filters.json"
                try? data.write(to: documentsPath.appendingPathComponent(fileName))
                savedFiles.append("\(fileName) (\(data.count/1024)KB, \(allFilters.count) filters)")
            }
        }

        // 2. Animations 추출 및 저장
        var allAnims: [AnimationEntry] = []
        for view in views {
            extractAnimations(from: view, path: name, animations: &allAnims)
        }
        if !allAnims.isEmpty {
            let result = AnimationsResult(meta: meta, animations: allAnims)
            if let data = try? encoder.encode(result) {
                let fileName = "\(timestamp)_\(name)_animations.json"
                try? data.write(to: documentsPath.appendingPathComponent(fileName))
                savedFiles.append("\(fileName) (\(data.count/1024)KB, \(allAnims.count) anims)")
            }
        }

        // 3. Structure 저장 (깊이 3)
        let summaries = views.map { createViewSummary($0, maxDepth: 3, currentDepth: 0) }
        let structResult = StructureResult(meta: meta, views: summaries)
        if let data = try? encoder.encode(structResult) {
            let fileName = "\(timestamp)_\(name)_structure.json"
            try? data.write(to: documentsPath.appendingPathComponent(fileName))
            savedFiles.append("\(fileName) (\(data.count/1024)KB)")
        }

        // 4. Full 데이터 저장 (분할)
        let fullViews = views.map { inspectView($0) }
        let fullResult = FullDataResult(meta: meta, part: 1, totalParts: 1, views: fullViews)
        if let data = try? encoder.encode(fullResult) {
            let lines = data.count / 50  // 대략적인 줄 수 추정
            let parts = max(1, (lines / maxLinesPerFile) + 1)

            if parts == 1 {
                let fileName = "\(timestamp)_\(name)_full.json"
                try? data.write(to: documentsPath.appendingPathComponent(fileName))
                savedFiles.append("\(fileName) (\(data.count/1024)KB)")
            } else {
                // 분할 저장 (단순 분할 - 뷰 단위)
                let viewsPerPart = max(1, fullViews.count / parts)
                for i in 0..<parts {
                    let start = i * viewsPerPart
                    let end = min(start + viewsPerPart, fullViews.count)
                    if start >= fullViews.count { break }

                    let partViews = Array(fullViews[start..<end])
                    let partResult = FullDataResult(meta: meta, part: i + 1, totalParts: parts, views: partViews)
                    if let partData = try? encoder.encode(partResult) {
                        let fileName = "\(timestamp)_\(name)_full_\(i + 1).json"
                        try? partData.write(to: documentsPath.appendingPathComponent(fileName))
                        savedFiles.append("\(fileName) (\(partData.count/1024)KB)")
                    }
                }
            }
        }

        return savedFiles
    }

    // MARK: - Filters 추출

    private func extractFilters(from view: UIView, path: String, filters: inout [FilterEntry]) {
        let viewPath = "\(path) > \(type(of: view))"
        extractLayerFilters(from: view.layer, path: "\(viewPath).layer", filters: &filters)

        for (i, subview) in view.subviews.enumerated() {
            extractFilters(from: subview, path: "\(viewPath)[\(i)]", filters: &filters)
        }
    }

    private func extractLayerFilters(from layer: CALayer, path: String, filters: inout [FilterEntry]) {
        // filters
        if let layerFilters = layer.filters {
            for filter in layerFilters {
                if let entry = createFilterEntry(filter, path: path) {
                    filters.append(entry)
                }
            }
        }

        // backgroundFilters
        if let bgFilters = layer.backgroundFilters {
            for filter in bgFilters {
                if let entry = createFilterEntry(filter, path: "\(path).bgFilter") {
                    filters.append(entry)
                }
            }
        }

        // compositingFilter
        if let compFilter = layer.compositingFilter {
            let entry = FilterEntry(
                path: path,
                filterName: String(describing: compFilter),
                filterType: "compositingFilter",
                enabled: true,
                parameters: [:],
                respondingKeys: nil
            )
            filters.append(entry)
        }

        // mask
        if let mask = layer.mask {
            extractLayerFilters(from: mask, path: "\(path).mask", filters: &filters)
        }

        // sublayers
        if let sublayers = layer.sublayers {
            for (i, sublayer) in sublayers.enumerated() {
                extractLayerFilters(from: sublayer, path: "\(path).sub[\(i)]", filters: &filters)
            }
        }
    }

    private func createFilterEntry(_ filter: Any, path: String) -> FilterEntry? {
        guard let nsFilter = filter as? NSObject else { return nil }
        let name = (nsFilter.value(forKey: "name") as? String) ?? "unknown"
        let type = (nsFilter.value(forKey: "type") as? String) ?? "unknown"
        let enabled = (nsFilter.value(forKey: "enabled") as? Bool) ?? true

        var params: [String: String] = [:]
        var responding: [String] = []

        for key in filterParamKeys {
            let selector = NSSelectorFromString(key)
            if nsFilter.responds(to: selector) {
                responding.append(key)
                if let value = nsFilter.value(forKey: key) {
                    if key == "inputColorMatrix", let nsValue = value as? NSValue {
                        params[key] = parseColorMatrix(nsValue)
                    } else {
                        params[key] = String(describing: value)
                    }
                }
            }
        }

        // 파라미터 없는 필터는 응답 키 기록
        let respKeys: [String]? = (name == "opacityPair" || name == "displacementMap" || params.isEmpty)
            ? (responding.isEmpty ? nil : responding) : nil

        return FilterEntry(path: path, filterName: name, filterType: type,
                          enabled: enabled, parameters: params, respondingKeys: respKeys)
    }

    // MARK: - Animations 추출

    private func extractAnimations(from view: UIView, path: String, animations: inout [AnimationEntry]) {
        let viewPath = "\(path) > \(type(of: view))"
        extractLayerAnimations(from: view.layer, path: "\(viewPath).layer", animations: &animations)

        for (i, subview) in view.subviews.enumerated() {
            extractAnimations(from: subview, path: "\(viewPath)[\(i)]", animations: &animations)
        }
    }

    private func extractLayerAnimations(from layer: CALayer, path: String, animations: inout [AnimationEntry]) {
        if let keys = layer.animationKeys() {
            for key in keys {
                if let anim = layer.animation(forKey: key) {
                    let entry = AnimationEntry(
                        path: path,
                        key: key,
                        className: String(describing: type(of: anim)),
                        duration: sanitize(anim.duration),
                        keyPath: (anim as? CAPropertyAnimation)?.keyPath
                    )
                    animations.append(entry)
                }
            }
        }

        if let mask = layer.mask {
            extractLayerAnimations(from: mask, path: "\(path).mask", animations: &animations)
        }

        if let sublayers = layer.sublayers {
            for (i, sublayer) in sublayers.enumerated() {
                extractLayerAnimations(from: sublayer, path: "\(path).sub[\(i)]", animations: &animations)
            }
        }
    }

    // MARK: - Structure 생성

    private func createViewSummary(_ view: UIView, maxDepth: Int, currentDepth: Int) -> ViewSummary {
        let hasFilters = (view.layer.filters?.isEmpty == false) ||
                         (view.layer.backgroundFilters?.isEmpty == false) ||
                         (view.layer.compositingFilter != nil)
        let hasAnims = view.layer.animationKeys()?.isEmpty == false

        var children: [ViewSummary]? = nil
        if currentDepth < maxDepth && !view.subviews.isEmpty {
            children = view.subviews.map { createViewSummary($0, maxDepth: maxDepth, currentDepth: currentDepth + 1) }
        }

        return ViewSummary(
            className: String(describing: type(of: view)),
            frame: sanitizeFrame(view.frame),
            layerClass: String(describing: type(of: view.layer)),
            hasFilters: hasFilters,
            hasAnimations: hasAnims,
            childCount: view.subviews.count,
            children: children
        )
    }

    // MARK: - Full View Inspection (기본값 생략)

    private func inspectView(_ view: UIView, maxDepth: Int = 15, currentDepth: Int = 0) -> ViewInfo {
        let typeName = String(describing: type(of: view))

        var children: [ViewInfo]? = nil
        if currentDepth < maxDepth && !view.subviews.isEmpty {
            children = view.subviews.map { inspectView($0, maxDepth: maxDepth, currentDepth: currentDepth + 1) }
        }

        var privateProps: [String: String]? = nil
        if typeName.hasPrefix("_") || typeName.contains("Liquid") || typeName.contains("Glass") {
            privateProps = extractPrivateViewProperties(view)
        }

        return ViewInfo(
            cls: typeName,
            frame: sanitizeFrame(view.frame),
            alpha: view.alpha < 0.999 ? sanitize(view.alpha) : nil,
            hidden: view.isHidden ? true : nil,
            clips: view.clipsToBounds ? true : nil,
            bgColor: extractColor(view.backgroundColor),
            layer: inspectLayer(view.layer),
            pvt: privateProps,
            sub: children
        )
    }

    private func inspectLayer(_ layer: CALayer, maxDepth: Int = 15, currentDepth: Int = 0) -> LayerInfo {
        let typeName = String(describing: type(of: layer))

        // Filters
        var filters: [FilterInfo]? = nil
        if let lf = layer.filters, !lf.isEmpty {
            filters = lf.compactMap { extractFilterInfo($0) }
        }

        var bgFilters: [FilterInfo]? = nil
        if let bf = layer.backgroundFilters, !bf.isEmpty {
            bgFilters = bf.compactMap { extractFilterInfo($0) }
        }

        var compFilter: String? = nil
        if let cf = layer.compositingFilter {
            compFilter = String(describing: cf)
        }

        // Mask
        var maskLayer: LayerInfo? = nil
        if let m = layer.mask, currentDepth < maxDepth {
            maskLayer = inspectLayer(m, maxDepth: maxDepth, currentDepth: currentDepth + 1)
        }

        // Sublayers
        var sublayersInfo: [LayerInfo]? = nil
        if let sl = layer.sublayers, !sl.isEmpty, currentDepth < maxDepth {
            sublayersInfo = sl.map { inspectLayer($0, maxDepth: maxDepth, currentDepth: currentDepth + 1) }
        }

        // Animations
        var anims: [AnimInfo]? = nil
        if let keys = layer.animationKeys(), !keys.isEmpty {
            anims = keys.compactMap { key in
                guard let a = layer.animation(forKey: key) else { return nil }
                return AnimInfo(
                    key: key,
                    cls: String(describing: type(of: a)),
                    dur: sanitize(a.duration),
                    keyPath: (a as? CAPropertyAnimation)?.keyPath
                )
            }
        }

        // Backdrop
        var backdrop: BackdropInfo? = nil
        if typeName.contains("Backdrop") {
            backdrop = extractBackdropProperties(layer)
        }

        // Private
        var pvt: [String: String]? = nil
        let privateProps = extractPrivateLayerProperties(layer)
        if !privateProps.isEmpty { pvt = privateProps }

        // Transform (identity 아닐 때만)
        var transform: [CGFloat]? = nil
        if !CATransform3DIsIdentity(layer.transform) {
            let t = layer.transform
            transform = [t.m11, t.m12, t.m13, t.m14, t.m21, t.m22, t.m23, t.m24,
                        t.m31, t.m32, t.m33, t.m34, t.m41, t.m42, t.m43, t.m44].map { sanitize($0) }
        }

        var subTransform: [CGFloat]? = nil
        if !CATransform3DIsIdentity(layer.sublayerTransform) {
            let t = layer.sublayerTransform
            subTransform = [t.m11, t.m12, t.m13, t.m14, t.m21, t.m22, t.m23, t.m24,
                           t.m31, t.m32, t.m33, t.m34, t.m41, t.m42, t.m43, t.m44].map { sanitize($0) }
        }

        // Anchor (기본값 아닐 때만)
        var anchor: PointInfo? = nil
        if abs(layer.anchorPoint.x - 0.5) > 0.001 || abs(layer.anchorPoint.y - 0.5) > 0.001 {
            anchor = PointInfo(x: sanitize(layer.anchorPoint.x), y: sanitize(layer.anchorPoint.y))
        }

        // MaskedCorners (전부 아닐 때만)
        var maskedCorners: [String]? = nil
        let allCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        if layer.maskedCorners != allCorners {
            var corners: [String] = []
            if layer.maskedCorners.contains(.layerMinXMinYCorner) { corners.append("TL") }
            if layer.maskedCorners.contains(.layerMaxXMinYCorner) { corners.append("TR") }
            if layer.maskedCorners.contains(.layerMinXMaxYCorner) { corners.append("BL") }
            if layer.maskedCorners.contains(.layerMaxXMaxYCorner) { corners.append("BR") }
            maskedCorners = corners.isEmpty ? nil : corners
        }

        // Shadow offset (기본값 아닐 때만)
        var shadowOffset: SizeInfo? = nil
        if abs(layer.shadowOffset.width) > 0.001 || abs(layer.shadowOffset.height + 3) > 0.001 {
            shadowOffset = SizeInfo(width: sanitize(layer.shadowOffset.width), height: sanitize(layer.shadowOffset.height))
        }

        // Portal info (CAPortalLayer 전용)
        var portalInfo: PortalInfo? = nil
        if typeName.contains("Portal") {
            let ns = layer as NSObject
            portalInfo = extractPortalInfo(ns)
        }

        // SDF info (CASDFLayer 전용)
        var sdfInfo: SDFInfo? = nil
        if typeName.contains("SDF") {
            let ns = layer as NSObject
            sdfInfo = extractSDFInfo(ns)
        }

        // innerShadowView 전용 - 모든 shadow 속성 강제 수집 (기본값 포함)
        var shadowAllInfo: ShadowAllInfo? = nil
        if let name = layer.name, name.contains("innerShadow") {
            var shadowColorInfo: ColorInfo? = nil
            if let sc = layer.shadowColor {
                shadowColorInfo = extractCGColor(sc)
            }
            shadowAllInfo = ShadowAllInfo(
                shadowColor: shadowColorInfo,
                shadowOpacity: layer.shadowOpacity,
                shadowRadius: layer.shadowRadius,
                shadowOffset: SizeInfo(width: sanitize(layer.shadowOffset.width),
                                       height: sanitize(layer.shadowOffset.height)),
                shadowPath: layer.shadowPath != nil ? "[\(type(of: layer.shadowPath!))]" : nil
            )
        }

        // 추가 속성
        let hasCont = layer.contents != nil
        let gravity = layer.contentsGravity.rawValue
        let screenScale = UIScreen.main.scale

        return LayerInfo(
            cls: typeName,
            name: layer.name,
            frame: sanitizeFrame(layer.frame),
            zPos: layer.zPosition != 0 ? sanitize(layer.zPosition) : nil,
            anchor: anchor,
            anchorZ: layer.anchorPointZ != 0 ? sanitize(layer.anchorPointZ) : nil,
            scale: nil,  // 보통 화면 스케일과 같으므로 생략
            transform: transform,
            subTransform: subTransform,
            hidden: layer.isHidden ? true : nil,
            opacity: layer.opacity < 0.999 ? sanitize(layer.opacity) : nil,
            groupOpacity: layer.allowsGroupOpacity ? nil : false,  // 기본 true
            cornerRadius: layer.cornerRadius > 0 ? sanitize(layer.cornerRadius) : nil,
            cornerCurve: layer.cornerCurve != .circular ? layer.cornerCurve.rawValue : nil,
            maskedCorners: maskedCorners,
            borderW: layer.borderWidth > 0 ? sanitize(layer.borderWidth) : nil,
            borderColor: layer.borderColor.flatMap { extractCGColor($0) },
            bgColor: layer.backgroundColor.flatMap { extractCGColor($0) },
            shadowColor: layer.shadowOpacity > 0 ? layer.shadowColor.flatMap { extractCGColor($0) } : nil,
            shadowOpacity: layer.shadowOpacity > 0 ? sanitize(layer.shadowOpacity) : nil,
            shadowRadius: (layer.shadowOpacity > 0 && abs(layer.shadowRadius - 3) > 0.001) ? sanitize(layer.shadowRadius) : nil,
            shadowOffset: layer.shadowOpacity > 0 ? shadowOffset : nil,
            filters: filters,
            bgFilters: bgFilters,
            compFilter: compFilter,
            mask: maskLayer,
            sublayers: sublayersInfo,
            anims: anims,
            backdrop: backdrop,
            portal: portalInfo,
            sdf: sdfInfo,
            shadowAll: shadowAllInfo,
            pvt: pvt,
            masksToBounds: layer.masksToBounds ? true : nil,
            hasContents: hasCont ? true : nil,
            contentsGravity: gravity != "resize" ? gravity : nil,
            contentsScale: abs(layer.contentsScale - screenScale) > 0.01 ? sanitize(layer.contentsScale) : nil
        )
    }

    // MARK: - Helpers

    private func sanitize(_ value: CGFloat) -> CGFloat {
        if value.isNaN || value.isInfinite { return 0 }
        return value
    }

    private func sanitize(_ value: Float) -> Float {
        if value.isNaN || value.isInfinite { return 0 }
        return value
    }

    private func sanitizeFrame(_ rect: CGRect) -> FrameInfo {
        return FrameInfo(CGRect(
            x: sanitize(rect.origin.x), y: sanitize(rect.origin.y),
            width: sanitize(rect.width), height: sanitize(rect.height)
        ))
    }

    private func extractColor(_ color: UIColor?) -> ColorInfo? {
        guard let color = color else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        if a < 0.001 { return nil }  // 완전 투명이면 생략
        return ColorInfo(r: sanitize(r), g: sanitize(g), b: sanitize(b), a: sanitize(a))
    }

    private func extractCGColor(_ cgColor: CGColor) -> ColorInfo? {
        guard let components = cgColor.components, components.count >= 2 else { return nil }
        if components.count >= 4 {
            if components[3] < 0.001 { return nil }
            return ColorInfo(r: sanitize(components[0]), g: sanitize(components[1]),
                           b: sanitize(components[2]), a: sanitize(components[3]))
        } else {
            if components[1] < 0.001 { return nil }
            return ColorInfo(r: sanitize(components[0]), g: sanitize(components[0]),
                           b: sanitize(components[0]), a: sanitize(components[1]))
        }
    }

    private func extractFilterInfo(_ filter: Any) -> FilterInfo? {
        guard let nsFilter = filter as? NSObject else { return nil }
        let name = (nsFilter.value(forKey: "name") as? String) ?? "unknown"
        let type = (nsFilter.value(forKey: "type") as? String) ?? "unknown"

        var params: [String: String]? = nil
        var p: [String: String] = [:]
        var responding: [String] = []

        for key in filterParamKeys {
            // responds(to:) 체크 - KVC 가능 키 확인
            let selector = NSSelectorFromString(key)
            if nsFilter.responds(to: selector) {
                responding.append(key)
                if let value = nsFilter.value(forKey: key) {
                    if key == "inputColorMatrix", let nsValue = value as? NSValue {
                        p[key] = parseColorMatrix(nsValue)
                    } else {
                        p[key] = String(describing: value)
                    }
                }
            }
        }
        if !p.isEmpty { params = p }

        // opacityPair, displacementMap 등 파라미터 없는 필터는 응답 키 기록
        let respKeys: [String]? = (name == "opacityPair" || name == "displacementMap" || params == nil)
            ? (responding.isEmpty ? nil : responding) : nil

        return FilterInfo(name: name, type: type, params: params, respondingKeys: respKeys)
    }

    private func parseColorMatrix(_ nsValue: NSValue) -> String {
        var buffer = [UInt8](repeating: 0, count: 80)
        nsValue.getValue(&buffer)
        var floats = [Float](repeating: 0, count: 20)
        for i in 0..<20 {
            let bytes = Array(buffer[i*4..<i*4+4])
            floats[i] = bytes.withUnsafeBytes { $0.load(as: Float.self) }
        }
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

    private func extractPrivateViewProperties(_ view: UIView) -> [String: String]? {
        var props: [String: String] = [:]
        let className = NSStringFromClass(type(of: view))

        // _UILiquidLensView 전용 키들 - 해당 클래스에서만 접근
        if className.contains("LiquidLens") {
            let liquidLensKeys = ["warpsContentBelow", "liftedContentMode", "hasCustomRestingBackground"]
            for key in liquidLensKeys {
                let selector = NSSelectorFromString(key)
                if (view as NSObject).responds(to: selector),
                   let value = view.value(forKey: key) {
                    props[key] = String(describing: value)
                }
            }
        }

        return props.isEmpty ? nil : props
    }

    private func extractPrivateLayerProperties(_ layer: CALayer) -> [String: String] {
        var props: [String: String] = [:]
        let keys = ["allowsGroupBlending", "continuousCorners"]
        let ns = layer as NSObject
        for key in keys {
            let selector = NSSelectorFromString(key)
            if ns.responds(to: selector),
               let value = ns.value(forKey: key) {
                props[key] = String(describing: value)
            }
        }
        return props
    }

    private func extractBackdropProperties(_ layer: CALayer) -> BackdropInfo {
        let ns = layer as NSObject

        // responds(to:) 체크 후 안전하게 접근
        let scale: CGFloat? = ns.responds(to: NSSelectorFromString("scale"))
            ? ns.value(forKey: "scale") as? CGFloat : nil
        let groupName: String? = ns.responds(to: NSSelectorFromString("groupName"))
            ? ns.value(forKey: "groupName") as? String : nil
        let captureOnly: Bool? = ns.responds(to: NSSelectorFromString("captureOnly"))
            ? ns.value(forKey: "captureOnly") as? Bool : nil

        // 추가 속성
        let blurRadius: CGFloat? = ns.responds(to: NSSelectorFromString("blurRadius"))
            ? ns.value(forKey: "blurRadius") as? CGFloat : nil
        let saturation: CGFloat? = ns.responds(to: NSSelectorFromString("saturationAmount"))
            ? ns.value(forKey: "saturationAmount") as? CGFloat : nil
        let zoom: CGFloat? = ns.responds(to: NSSelectorFromString("zoom"))
            ? ns.value(forKey: "zoom") as? CGFloat : nil

        return BackdropInfo(scale: scale, groupName: groupName, captureOnly: captureOnly,
                           blurRadius: blurRadius, saturation: saturation, zoom: zoom)
    }

    private func extractPortalInfo(_ ns: NSObject) -> PortalInfo? {
        // sourceLayer 정보
        var sourceClass: String? = nil
        var sourceName: String? = nil
        var sourceFrame: FrameInfo? = nil

        if ns.responds(to: NSSelectorFromString("sourceLayer")),
           let source = ns.value(forKey: "sourceLayer") {
            sourceClass = String(describing: type(of: source))

            // sourceLayer가 CALayer이면 name과 frame도 수집
            if let sourceLayer = source as? CALayer {
                sourceName = sourceLayer.name
                sourceFrame = sanitizeFrame(sourceLayer.frame)
            }
        }

        let hides = ns.responds(to: NSSelectorFromString("hidesSourceLayer"))
            ? ns.value(forKey: "hidesSourceLayer") as? Bool : nil
        let matchOp = ns.responds(to: NSSelectorFromString("matchesOpacity"))
            ? ns.value(forKey: "matchesOpacity") as? Bool : nil
        let matchPos = ns.responds(to: NSSelectorFromString("matchesPosition"))
            ? ns.value(forKey: "matchesPosition") as? Bool : nil
        let matchTr = ns.responds(to: NSSelectorFromString("matchesTransform"))
            ? ns.value(forKey: "matchesTransform") as? Bool : nil

        // 아무 것도 없으면 nil
        if sourceClass == nil && hides == nil && matchOp == nil && matchPos == nil && matchTr == nil {
            return nil
        }

        return PortalInfo(sourceLayerClass: sourceClass, sourceLayerName: sourceName,
                         sourceLayerFrame: sourceFrame, hidesSourceLayer: hides,
                         matchesOpacity: matchOp, matchesPosition: matchPos, matchesTransform: matchTr)
    }

    private func extractSDFInfo(_ ns: NSObject) -> SDFInfo? {
        // 시도할 키 목록 (CASDFLayer, CASDFElementLayer)
        // CAShapeLayer 계열 키 + SDF 추정 키 + Private 추정 키
        let sdfKeys = [
            // CAShapeLayer 표준 키
            "path", "fillColor", "strokeColor", "strokeWidth", "fillRule",
            "strokeStart", "strokeEnd", "lineCap", "lineJoin", "miterLimit",
            "lineDashPhase", "lineDashPattern",
            // SDF 추정 키
            "sdfData", "distanceField", "signedDistanceField", "sdf",
            "resolution", "spread", "padding", "smoothing",
            // 형태 관련 추정 키
            "shape", "shapeType", "elementType", "contour", "outline",
            "geometry", "sdfPath", "shapePath", "bezierPath",
            // Private 추정 키
            "_path", "_fillColor", "_strokeColor", "_shape",
            "cornerContents", "corners", "elements", "elementLayers",
            // 추가 시도 키
            "bounds", "contents", "contentsRect", "contentsCenter"
        ]

        var respondingKeys: [String] = []
        var keyValues: [String: String] = [:]

        for key in sdfKeys {
            let selector = NSSelectorFromString(key)
            if ns.responds(to: selector) {
                respondingKeys.append(key)
                // 값도 수집 시도
                if let value = ns.value(forKey: key) {
                    if key == "fillColor" || key == "strokeColor" || key == "_fillColor" || key == "_strokeColor" {
                        // CGColor 타입 체크 (CFTypeID 비교)
                        if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                            let cgColor = unsafeBitCast(value, to: CGColor.self)
                            if let colorInfo = extractCGColor(cgColor) {
                                keyValues[key] = "rgba(\(colorInfo.r), \(colorInfo.g), \(colorInfo.b), \(colorInfo.a))"
                            }
                        }
                    } else if key == "path" || key == "_path" || key == "shapePath" || key == "bezierPath" {
                        // CGPath는 description이 길 수 있으므로 타입만 기록
                        keyValues[key] = "[\(type(of: value))]"
                    } else {
                        keyValues[key] = String(describing: value)
                    }
                }
            }
        }

        // 기본 속성 추출
        let shape = ns.responds(to: NSSelectorFromString("shape"))
            ? ns.value(forKey: "shape") as? String : nil
        let sdfPath = ns.responds(to: NSSelectorFromString("path"))
            ? "[\(type(of: ns.value(forKey: "path") ?? "nil"))]" : nil

        var fillColor: ColorInfo? = nil
        if ns.responds(to: NSSelectorFromString("fillColor")),
           let value = ns.value(forKey: "fillColor") {
            if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                fillColor = extractCGColor(unsafeBitCast(value, to: CGColor.self))
            }
        }

        var strokeColor: ColorInfo? = nil
        if ns.responds(to: NSSelectorFromString("strokeColor")),
           let value = ns.value(forKey: "strokeColor") {
            if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                strokeColor = extractCGColor(unsafeBitCast(value, to: CGColor.self))
            }
        }

        let strokeWidth = ns.responds(to: NSSelectorFromString("strokeWidth"))
            ? ns.value(forKey: "strokeWidth") as? CGFloat : nil
        let cornerRadius = ns.responds(to: NSSelectorFromString("cornerRadius"))
            ? ns.value(forKey: "cornerRadius") as? CGFloat : nil
        let fillRule = ns.responds(to: NSSelectorFromString("fillRule"))
            ? ns.value(forKey: "fillRule") as? String : nil

        // SDF 레이어이면 항상 반환 (정보가 없어도 키 목록 포함)
        return SDFInfo(shape: shape, fillColor: fillColor, strokeColor: strokeColor,
                      strokeWidth: strokeWidth, sdfPath: sdfPath, cornerRadius: cornerRadius,
                      fillRule: fillRule,
                      respondingKeys: respondingKeys.isEmpty ? nil : respondingKeys,
                      keyValues: keyValues.isEmpty ? nil : keyValues)
    }

    private func getKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private func findViews<T: UIView>(ofType type: T.Type, in view: UIView) -> [T] {
        var results: [T] = []
        if let matched = view as? T { results.append(matched) }
        for subview in view.subviews {
            results.append(contentsOf: findViews(ofType: type, in: subview))
        }
        return results
    }

    private func getCurrentScreenName() -> String {
        guard let window = getKeyWindow(), let rootVC = window.rootViewController else { return "Unknown" }
        if let tabVC = rootVC as? UITabBarController, let selectedVC = tabVC.selectedViewController {
            return String(describing: type(of: selectedVC))
        }
        if let navVC = rootVC as? UINavigationController, let topVC = navVC.topViewController {
            return String(describing: type(of: topVC))
        }
        return String(describing: type(of: rootVC))
    }

    private func showSaveAlert(files: [String]) {
        guard let window = getKeyWindow(), let rootVC = window.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }

        let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        let fileList = files.prefix(5).joined(separator: "\n") + (files.count > 5 ? "\n..." : "")
        let message = "경로: \(docsPath)\n\n\(fileList)"

        let alert = UIAlertController(title: "덤프 완료 (\(files.count)개)", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        topVC.present(alert, animated: true)

        // 콘솔에도 경로 출력
        print("Documents 경로: \(docsPath)")
    }
}

#endif
