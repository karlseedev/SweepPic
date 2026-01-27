// SystemUIInspector2.swift
// iOS 시스템 UI의 모든 속성을 _ivarDescription으로 완전 덤프하는 디버그 유틸리티
// 사용 후 삭제 예정

#if DEBUG

import UIKit
import AppCore

/// 시스템 UI 완전 덤프 인스펙터
/// - _ivarDescription을 사용하여 상속 포함 모든 ivar 덤프
/// - LLDB `po [view _ivarDescription]`과 100% 동일한 결과
/// - 파일 2개 저장: 필터링된 파일 + 전체 파일
final class SystemUIInspector2 {

    static let shared = SystemUIInspector2()
    private init() {}

    // MARK: - Properties

    /// 플로팅 디버그 버튼
    private var debugButton: UIButton?

    /// 인스펙션 카운터
    private var inspectionCount = 0

    /// 조사 대상 클래스 패턴
    private let targetClassPatterns = [
        "UITabBar",
        "UINavigationBar",
        "UIToolbar",
        "_UITabBarPlatterView",
        "_UITabBarItemView",
        "_UINavigationBarBackground",
        "_UIBarBackground",
        "PlatterView",
        "GlassView",
        "LiquidGlass",
        "UICollectionView"
    ]

    // MARK: - 필터링 키워드

    /// UI 시각적 속성 포함 키워드
    private let includeKeywords = [
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
        // 효과/필터
        "blur", "Blur", "filter", "Filter", "effect", "Effect",
        "gradient", "Gradient", "glass", "Glass", "liquid", "Liquid",
        // 경로/마스크
        "path", "Path", "mask", "Mask", "clip", "Clip",
        // 텍스트/폰트
        "font", "Font", "text", "Text", "title", "Title", "label", "Label",
        // 이미지/아이콘
        "image", "Image", "icon", "Icon",
        // 버튼/선택
        "button", "Button", "selected", "Selected", "highlight", "Highlight",
        // 배경
        "background", "Background", "backdrop", "Backdrop",
        // 레이어
        "layer", "Layer",
        // 스타일/외관
        "style", "Style", "appearance", "Appearance",
        // 콘텐츠/레이아웃
        "content", "Content", "spacing", "Spacing"
    ]

    /// 제외 키워드 (내부 관리용)
    private let excludeKeywords = [
        "_viewFlags", "_traitChange", "_gestureRecognizer", "_gestureInfo",
        "_constraint", "Constraint", "_autolayout", "_autoresize",
        "_cache", "Cache", "_cached",
        "_observation", "_notification", "_registry",
        "_storage", "Storage",
        "_delegate", "_responder", "_firstResponder",
        "_window", "_superview", "_subview",
        "retainCount", "zone", "isa",
        "_internal", "_private", "_impl",
        "_accessibility", "Accessibility",
        "_trait", "Trait",
        "_semantic", "Semantic",
        "_rawLayoutMargins", "_inferredLayoutMargins",
        "_safeAreaInsets", "_minimumSafeAreaInsets",
        "_boundsWidthVariable", "_boundsHeightVariable",
        "_tintAdjustmentDimmingCount"
    ]

    // MARK: - Public API

    /// 플로팅 디버그 버튼 표시 (화면 중앙)
    func showDebugButton() {
        guard debugButton == nil else { return }
        guard let window = getKeyWindow() else { return }

        let button = UIButton(type: .system)
        button.setTitle("🔬 Full Dump", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.backgroundColor = UIColor.systemPurple
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
        Log.print("[SystemUIInspector2] 디버그 버튼 표시됨 - _ivarDescription 완전 덤프")
    }

    /// 디버그 버튼 숨기기
    func hideDebugButton() {
        debugButton?.removeFromSuperview()
        debugButton = nil
    }

    // MARK: - Button Action

    @objc private func debugButtonTapped() {
        inspectionCount += 1

        // 버튼 피드백
        debugButton?.setTitle("덤프 중...", for: .normal)
        debugButton?.isEnabled = false

        // 약간의 딜레이 후 인스펙션 (UI 갱신 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.performFullDump()

            // 버튼 복원
            self.debugButton?.setTitle("🔬 Full Dump", for: .normal)
            self.debugButton?.isEnabled = true
        }
    }

    // MARK: - Full Dump

    /// 전체 덤프 실행 (파일 2개 저장)
    private func performFullDump() {
        guard let window = getKeyWindow() else {
            Log.print("[SystemUIInspector2] Key Window를 찾을 수 없습니다.")
            return
        }

        // 헤더 생성
        let header = makeHeader()

        // 뷰 계층 문자열
        let hierarchySection = makeHierarchySection(window: window)

        // 대상 뷰 찾기
        let targetViews = findTargetViews(in: window)

        // 전체 덤프 (Full)
        let fullDumpSection = makeFullDumpSection(targetViews: targetViews)

        // 필터링 덤프 (Filtered)
        let filteredDumpSection = makeFilteredDumpSection(targetViews: targetViews)

        // 파일 1: 필터링된 파일 (주로 볼 파일)
        let filteredContent = header + hierarchySection + filteredDumpSection
        let filteredFileName = saveToFile(content: filteredContent, suffix: "filtered")

        // 파일 2: 전체 파일 (누락 대비)
        let fullContent = header + hierarchySection + fullDumpSection
        let fullFileName = saveToFile(content: fullContent, suffix: "full")

        // 알림 표시
        showSaveAlert(filteredFileName: filteredFileName, fullFileName: fullFileName)
    }

    // MARK: - Content Generation

    /// 헤더 생성
    private func makeHeader() -> String {
        var output = ""
        output += String(repeating: "=", count: 80) + "\n"
        output += "iOS System UI Dump (_ivarDescription)\n"
        output += "Date: \(Date())\n"
        output += "iOS Version: \(UIDevice.current.systemVersion)\n"
        output += String(repeating: "=", count: 80) + "\n\n"
        return output
    }

    /// 뷰 계층 섹션 생성
    private func makeHierarchySection(window: UIWindow) -> String {
        var output = ""
        output += "## 1. View Hierarchy (recursiveDescription)\n"
        output += String(repeating: "-", count: 60) + "\n"
        if let hierarchy = getRecursiveDescription(of: window) {
            output += hierarchy + "\n\n"
        }
        return output
    }

    /// 전체 덤프 섹션 생성 (필터링 없음)
    private func makeFullDumpSection(targetViews: [UIView]) -> String {
        var output = ""
        output += "## 2. Target Views _ivarDescription (FULL - 전체)\n"
        output += String(repeating: "-", count: 60) + "\n\n"

        if targetViews.isEmpty {
            output += "대상 뷰를 찾을 수 없습니다.\n"
        } else {
            output += "총 \(targetViews.count)개 대상 뷰 발견\n\n"

            for (index, view) in targetViews.enumerated() {
                let typeName = String(describing: type(of: view))
                output += String(repeating: "=", count: 60) + "\n"
                output += "### [\(index + 1)] \(typeName)\n"
                output += "Address: \(Unmanaged.passUnretained(view).toOpaque())\n"
                output += "Frame: \(view.frame)\n"
                output += String(repeating: "-", count: 40) + "\n"

                if let ivarDesc = getIvarDescription(of: view) {
                    output += ivarDesc + "\n"
                } else {
                    output += "[ERROR] _ivarDescription 호출 실패\n"
                }

                output += "\n"
            }
        }

        return output
    }

    /// 필터링 덤프 섹션 생성 (UI 관련만)
    private func makeFilteredDumpSection(targetViews: [UIView]) -> String {
        var output = ""
        output += "## 2. Target Views _ivarDescription (FILTERED - UI 관련만)\n"
        output += String(repeating: "-", count: 60) + "\n\n"

        if targetViews.isEmpty {
            output += "대상 뷰를 찾을 수 없습니다.\n"
        } else {
            output += "총 \(targetViews.count)개 대상 뷰 발견\n\n"

            for (index, view) in targetViews.enumerated() {
                let typeName = String(describing: type(of: view))
                output += String(repeating: "=", count: 60) + "\n"
                output += "### [\(index + 1)] \(typeName)\n"
                output += "Address: \(Unmanaged.passUnretained(view).toOpaque())\n"
                output += "Frame: \(view.frame)\n"
                output += String(repeating: "-", count: 40) + "\n"

                if let ivarDesc = getIvarDescription(of: view) {
                    let filteredDesc = filterIvarDescription(ivarDesc)
                    output += filteredDesc + "\n"
                } else {
                    output += "[ERROR] _ivarDescription 호출 실패\n"
                }

                output += "\n"
            }
        }

        return output
    }

    // MARK: - Filtering

    /// _ivarDescription 결과 필터링
    private func filterIvarDescription(_ description: String) -> String {
        let lines = description.components(separatedBy: "\n")
        var filteredLines: [String] = []

        for line in lines {
            // 클래스 헤더 라인은 유지 (예: "in UIView:")
            if line.contains(":") && line.trimmingCharacters(in: .whitespaces).hasPrefix("in ") {
                filteredLines.append(line)
                continue
            }

            // 객체 헤더 라인은 유지 (예: "<UIView: 0x123>:")
            if line.hasPrefix("<") && line.contains(":") {
                filteredLines.append(line)
                continue
            }

            // 제외 키워드 체크
            var shouldExclude = false
            for keyword in excludeKeywords {
                if line.contains(keyword) {
                    shouldExclude = true
                    break
                }
            }
            if shouldExclude { continue }

            // 포함 키워드 체크
            var shouldInclude = false
            for keyword in includeKeywords {
                if line.contains(keyword) {
                    shouldInclude = true
                    break
                }
            }

            if shouldInclude {
                filteredLines.append(line)
            }
        }

        return filteredLines.joined(separator: "\n")
    }

    // MARK: - _ivarDescription

    /// _ivarDescription 호출 (LLDB와 동일)
    private func getIvarDescription(of object: AnyObject) -> String? {
        let selector = Selector(("_ivarDescription"))

        guard object.responds(to: selector) else {
            return nil
        }

        guard let result = object.perform(selector) else {
            return nil
        }

        return result.takeUnretainedValue() as? String
    }

    /// recursiveDescription 호출
    private func getRecursiveDescription(of view: UIView) -> String? {
        let selector = Selector(("recursiveDescription"))

        guard view.responds(to: selector) else {
            return nil
        }

        guard let result = view.perform(selector) else {
            return nil
        }

        return result.takeUnretainedValue() as? String
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

    /// 대상 뷰 찾기 (재귀)
    private func findTargetViews(in view: UIView) -> [UIView] {
        var results: [UIView] = []

        let typeName = String(describing: type(of: view))

        // 대상 클래스 패턴 매칭
        for pattern in targetClassPatterns {
            if typeName.contains(pattern) {
                results.append(view)
                break
            }
        }

        // 하위 뷰 탐색
        for subview in view.subviews {
            results.append(contentsOf: findTargetViews(in: subview))
        }

        return results
    }

    // MARK: - File Saving

    /// 파일 저장
    @discardableResult
    private func saveToFile(content: String, suffix: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let fileName = "ui_dump_\(timestamp)_\(inspectionCount)_\(suffix).txt"

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Log.print("[SystemUIInspector2] Documents 폴더를 찾을 수 없습니다.")
            return fileName
        }

        let filePath = documentsPath.appendingPathComponent(fileName)

        do {
            try content.write(to: filePath, atomically: true, encoding: .utf8)
            Log.print("[SystemUIInspector2] 저장 완료: \(filePath.path)")
        } catch {
            Log.print("[SystemUIInspector2] 저장 실패: \(error)")
        }

        return fileName
    }

    /// 저장 완료 알림
    private func showSaveAlert(filteredFileName: String, fullFileName: String) {
        guard let window = getKeyWindow(),
              let rootVC = window.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let message = """
        📁 필터링 파일 (UI 관련만):
        \(filteredFileName)

        📁 전체 파일 (누락 대비):
        \(fullFileName)

        터미널에서 Documents 폴더 열기:
        open $(xcrun simctl get_app_container booted com.pickphoto.app data)/Documents/
        """

        let alert = UIAlertController(
            title: "덤프 완료 (2개 파일)",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "확인", style: .default))

        topVC.present(alert, animated: true)
    }
}

#endif
