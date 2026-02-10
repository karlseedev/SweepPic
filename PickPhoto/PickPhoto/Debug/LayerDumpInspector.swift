//
//  LayerDumpInspector.swift
//  PickPhoto
//
//  Description: 스크롤 중 CA 합성에 참여하는 레이어를 덤프하고
//               expensive 속성을 태깅하는 디버그 유틸리티.
//               render hitch 원인 분석용 (docs/260210gridPerfor1.md 참고)
//

#if DEBUG

import UIKit
import AppCore

/// 화면에 보이는 모든 CALayer를 재귀 탐색하여
/// 합성 비용에 영향을 주는 속성(shadow, blur, !opaque 등)을 태깅하고 출력한다.
///
/// 사용법:
///   - 스크롤 시작 시 자동 덤프 (GridScroll.swift에서 호출)
///   - `LayerDumpInspector.reset()` 으로 재덤프 가능
///   - 결과는 콘솔 로그 + Documents/layer_dump.txt 에 저장
enum LayerDumpInspector {

    // MARK: - State

    /// 이미 덤프했는지 여부 (스크롤당 1회만 실행)
    private(set) static var hasDumped = false

    /// 덤프 초기화 (다음 스크롤에서 다시 덤프하려면 호출)
    /// 앱에서 reset() 호출 후 다시 스크롤하면 재덤프됨
    static func reset() {
        hasDumped = false
        Log.print("[LayerDump] Reset — 다음 스크롤에서 재덤프됩니다")
    }

    // MARK: - Public

    /// 현재 화면의 모든 visible 레이어를 덤프한다.
    /// - Parameter rootView: 탐색 시작점 (nil이면 keyWindow 사용)
    static func dumpVisibleLayers(from rootView: UIView?) {
        guard !hasDumped else { return }
        hasDumped = true

        // keyWindow 확보
        guard let window = rootView ?? findKeyWindow() else {
            Log.print("[LayerDump] Key Window not found")
            return
        }

        var lines: [String] = []
        var totalCount = 0       // 전체 레이어 수 (hidden 포함)
        var visibleCount = 0     // 합성에 참여하는 레이어 수
        var flagCounts: [String: Int] = [:]  // expensive 속성별 카운트

        // 재귀적으로 레이어 트리를 탐색
        walkLayer(window.layer, depth: 0,
                  lines: &lines,
                  totalCount: &totalCount,
                  visibleCount: &visibleCount,
                  flagCounts: &flagCounts)

        // === 콘솔 출력 ===
        Log.print("[LayerDump] ========== Visible Layer Tree ==========")
        Log.print("[LayerDump] Total layers: \(totalCount), Visible (합성 참여): \(visibleCount)")

        // expensive 속성 요약 (많은 순)
        if !flagCounts.isEmpty {
            let summary = flagCounts
                .sorted { $0.value > $1.value }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            Log.print("[LayerDump] Expensive 속성 요약: \(summary)")
        }

        Log.print("[LayerDump] ------------------------------------------")

        // 트리 출력
        for line in lines {
            Log.print("[LayerDump] \(line)")
        }

        Log.print("[LayerDump] ==========================================")

        // 파일로 저장
        saveToFile(lines: lines,
                   totalCount: totalCount,
                   visibleCount: visibleCount,
                   flagCounts: flagCounts)
    }

    // MARK: - Layer Tree Walk

    /// 레이어 하나를 검사하고 서브레이어를 재귀 탐색
    private static func walkLayer(
        _ layer: CALayer,
        depth: Int,
        lines: inout [String],
        totalCount: inout Int,
        visibleCount: inout Int,
        flagCounts: inout [String: Int]
    ) {
        totalCount += 1

        // 합성에 참여하지 않는 레이어는 스킵
        // - isHidden = true → CA가 완전히 건너뜀
        // - opacity = 0 → 마찬가지
        // - bounds가 0 → 그릴 것이 없음
        let isVisible = !layer.isHidden
            && layer.opacity > 0
            && layer.bounds.width > 0
            && layer.bounds.height > 0

        if isVisible {
            visibleCount += 1

            // expensive 속성 수집
            let flags = collectExpensiveFlags(layer: layer)

            // 플래그 카운팅 (괄호 앞 키만 사용)
            for flag in flags {
                let key = flag.components(separatedBy: "(").first
                    ?? flag.components(separatedBy: "=").first
                    ?? flag
                flagCounts[key, default: 0] += 1
            }

            // 클래스 이름
            let layerClass = String(describing: type(of: layer))
            let viewClass: String
            if let view = layer.delegate as? UIView {
                viewClass = String(describing: type(of: view))
            } else {
                viewClass = "-"
            }

            // 크기
            let size = "\(Int(layer.bounds.width))×\(Int(layer.bounds.height))"

            // 출력 포맷
            let indent = String(repeating: "  ", count: depth)
            let flagStr = flags.isEmpty ? "" : " [" + flags.joined(separator: ", ") + "]"
            lines.append("\(indent)\(visibleCount). \(viewClass)/\(layerClass) \(size)\(flagStr)")
        }

        // 서브레이어 탐색
        // CA 합성 규칙: 부모가 hidden/invisible이면 모든 자식도 합성에서 제외됨
        // 따라서 visible한 레이어의 서브레이어만 탐색
        if isVisible, let sublayers = layer.sublayers {
            for sub in sublayers {
                walkLayer(sub, depth: depth + 1,
                          lines: &lines,
                          totalCount: &totalCount,
                          visibleCount: &visibleCount,
                          flagCounts: &flagCounts)
            }
        }
    }

    // MARK: - Expensive Flags

    /// 레이어의 expensive 속성을 검사하여 플래그 배열을 반환
    private static func collectExpensiveFlags(layer: CALayer) -> [String] {
        var flags: [String] = []

        // 1. 불투명 여부 — !opaque 레이어는 알파 블렌딩 필요
        if !layer.isOpaque {
            flags.append("!opaque")
        }

        // 2. 반투명 — 별도 offscreen 합성 가능
        if layer.opacity < 1 && layer.opacity > 0 {
            flags.append("alpha=\(String(format: "%.2f", layer.opacity))")
        }

        // 3. 그림자 — 별도 렌더 패스 (shadowPath 없으면 더 비쌈)
        if layer.shadowOpacity > 0 {
            let hasPath = layer.shadowPath != nil
            flags.append("shadow(o=\(String(format: "%.1f", layer.shadowOpacity)),r=\(Int(layer.shadowRadius)),path=\(hasPath))")
        }

        // 4. 라운드 코너 + 클리핑 — offscreen 렌더 유발 가능
        if layer.cornerRadius > 0 {
            if layer.masksToBounds {
                flags.append("roundedClip(r=\(Int(layer.cornerRadius)))")
            } else {
                flags.append("rounded(r=\(Int(layer.cornerRadius)))")
            }
        }

        // 5. shouldRasterize — 래스터 캐시 비용
        if layer.shouldRasterize {
            flags.append("rasterize")
        }

        // 6. mask 레이어 — offscreen 렌더 필수
        if layer.mask != nil {
            flags.append("MASK")
        }

        // 7. 레이어 타입별 비용
        if layer is CAGradientLayer {
            flags.append("GRADIENT")
        }
        if layer is CAMetalLayer {
            flags.append("METAL")
        }
        if String(describing: type(of: layer)).contains("CABackdropLayer") {
            flags.append("BACKDROP")
        }

        // 8. UIView 타입 기반 비용 체크
        if let view = layer.delegate as? UIView {
            let viewType = String(describing: type(of: view))

            // UIVisualEffectView 또는 Blur 계열
            if view is UIVisualEffectView {
                flags.append("BLUR_EFFECT")
            } else if viewType.contains("Blur") || viewType.contains("VariableBlur") {
                flags.append("BLUR")
            }
        }

        // 9. Private 속성: filters (가우시안 블러 등)
        if let filters = layer.value(forKey: "filters") as? [Any], !filters.isEmpty {
            flags.append("filters(\(filters.count))")
        }

        // 10. Private 속성: compositingFilter
        if layer.value(forKey: "compositingFilter") != nil {
            flags.append("compositingFilter")
        }

        return flags
    }

    // MARK: - Helpers

    /// keyWindow 찾기
    private static func findKeyWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    /// 결과를 Documents 폴더에 파일로 저장
    private static func saveToFile(
        lines: [String],
        totalCount: Int,
        visibleCount: Int,
        flagCounts: [String: Int]
    ) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let file = docs.appendingPathComponent("layer_dump.txt")

        var content = "=== Layer Dump ===\n"
        content += "Date: \(Date())\n"
        content += "Total layers: \(totalCount), Visible: \(visibleCount)\n\n"

        // expensive 요약
        let summary = flagCounts
            .sorted { $0.value > $1.value }
            .map { "  \($0.key): \($0.value)" }
            .joined(separator: "\n")
        content += "Expensive 속성 요약:\n\(summary)\n\n"

        // 트리
        content += "Layer Tree:\n"
        content += lines.joined(separator: "\n")
        content += "\n"

        try? content.write(to: file, atomically: true, encoding: .utf8)
        Log.print("[LayerDump] 파일 저장: \(file.path)")
    }
}

#endif
