// ButtonInspector.swift
// 버튼 크기/모양 실측 전용 Inspector
// GlassButton, UIButton 등 버튼 클래스만 찾아서 덤프
// 사용 후 삭제 예정

#if DEBUG

import UIKit
import AppCore

/// 버튼 정보 구조체
struct ButtonInfo: Codable {
    let className: String
    let path: String
    let frame: ButtonFrame
    let cornerRadius: CGFloat
    let cornerCurve: String
    let hasGlassEffect: Bool
    let iconSize: CGFloat?  // SF Symbol 크기 (추정)

    // 모양 정보
    let backgroundColor: String?
    let tintColor: String?
    let alpha: CGFloat
    let borderWidth: CGFloat
    let borderColor: String?
    let shadowRadius: CGFloat
    let shadowOpacity: Float
    let shadowOffset: ButtonOffset?
    let fontSize: CGFloat?  // 텍스트 버튼용
}

struct ButtonOffset: Codable {
    let width: CGFloat
    let height: CGFloat
}

struct ButtonFrame: Codable {
    let width: CGFloat
    let height: CGFloat
}

struct ButtonDumpResult: Codable {
    let date: String
    let iOS: String
    let screen: String
    let buttons: [ButtonInfo]
}

/// 버튼 실측 전용 Inspector
final class ButtonInspector {

    static let shared = ButtonInspector()
    private init() {}

    private var debugButton: UIButton?

    // MARK: - Public API

    func showDebugButton() {
        guard debugButton == nil else { return }
        guard let window = getKeyWindow() else { return }

        let button = UIButton(type: .system)
        button.setTitle("Button Dump", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.backgroundColor = .systemOrange
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
            button.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 150),
            button.widthAnchor.constraint(equalToConstant: 130),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])

        self.debugButton = button
        Log.print("[ButtonInspector] 디버그 버튼 표시됨")
    }

    func hideDebugButton() {
        debugButton?.removeFromSuperview()
        debugButton = nil
    }

    // MARK: - Button Action

    @objc private func debugButtonTapped() {
        Log.print("[ButtonInspector] 버튼 탭됨")
        debugButton?.setTitle("덤프 중...", for: .normal)
        debugButton?.isEnabled = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.performButtonDump()
            self?.debugButton?.setTitle("Button Dump", for: .normal)
            self?.debugButton?.isEnabled = true
        }
    }

    // MARK: - Dump

    private func performButtonDump() {
        Log.print("[ButtonInspector] performButtonDump 시작")

        guard let window = getKeyWindow() else {
            Log.print("[ButtonInspector] Key Window를 찾을 수 없습니다.")
            return
        }

        var buttons: [ButtonInfo] = []

        // 전체 뷰 계층에서 버튼 찾기
        findButtons(in: window, path: "window", buttons: &buttons)

        Log.print("[ButtonInspector] 발견된 버튼 수: \(buttons.count)")

        // 결과 저장
        let result = ButtonDumpResult(
            date: ISO8601DateFormatter().string(from: Date()),
            iOS: UIDevice.current.systemVersion,
            screen: getCurrentScreenName(),
            buttons: buttons
        )

        saveResult(result)
    }

    /// 뷰 계층에서 버튼 찾기
    private func findButtons(in view: UIView, path: String, buttons: inout [ButtonInfo]) {
        let className = String(describing: type(of: view))
        let currentPath = "\(path) > \(className)"

        // 버튼 클래스 체크
        // UIButton, GlassButton, GlassIconButton, _UIButtonBarButton 등
        let isButton = view is UIButton ||
                       className.contains("Button") ||
                       className.contains("Glass")

        if isButton {
            let info = extractButtonInfo(view: view, className: className, path: currentPath)
            buttons.append(info)
        }

        // 자식 뷰 탐색
        for (i, subview) in view.subviews.enumerated() {
            // 디버그 버튼은 제외
            if subview === debugButton { continue }
            findButtons(in: subview, path: "\(currentPath)[\(i)]", buttons: &buttons)
        }
    }

    /// 버튼 정보 추출
    private func extractButtonInfo(view: UIView, className: String, path: String) -> ButtonInfo {
        let layer = view.layer

        // Glass 효과 체크 (filters 또는 backgroundFilters에 glassBackground가 있는지)
        let hasGlass = checkGlassEffect(layer: layer)

        // 아이콘 크기 추정 (UIImageView 찾기)
        var iconSize: CGFloat? = nil
        if let imageView = findImageView(in: view) {
            iconSize = max(imageView.bounds.width, imageView.bounds.height)
        }

        // cornerRadius가 NaN이면 0으로 대체 (JSON 인코딩 에러 방지)
        let cornerRadius = layer.cornerRadius.isNaN ? 0 : layer.cornerRadius

        // 색상 정보 추출
        let bgColor = colorToHex(view.backgroundColor)
        let tint = colorToHex(view.tintColor)
        let border = colorToHex(UIColor(cgColor: layer.borderColor ?? UIColor.clear.cgColor))

        // 그림자 정보 (NaN 체크)
        let shadowRad = layer.shadowRadius.isNaN ? 0 : layer.shadowRadius
        let shadowOp = layer.shadowOpacity.isNaN ? 0 : layer.shadowOpacity
        let shadowOff = ButtonOffset(
            width: layer.shadowOffset.width.isNaN ? 0 : layer.shadowOffset.width,
            height: layer.shadowOffset.height.isNaN ? 0 : layer.shadowOffset.height
        )

        // 폰트 크기 (UIButton인 경우)
        var fontSize: CGFloat? = nil
        if let button = view as? UIButton, let font = button.titleLabel?.font {
            fontSize = font.pointSize
        }

        return ButtonInfo(
            className: className,
            path: path,
            frame: ButtonFrame(width: view.bounds.width, height: view.bounds.height),
            cornerRadius: cornerRadius,
            cornerCurve: layer.cornerCurve.rawValue,
            hasGlassEffect: hasGlass,
            iconSize: iconSize,
            backgroundColor: bgColor,
            tintColor: tint,
            alpha: view.alpha,
            borderWidth: layer.borderWidth,
            borderColor: border,
            shadowRadius: shadowRad,
            shadowOpacity: shadowOp,
            shadowOffset: shadowOff,
            fontSize: fontSize
        )
    }

    /// UIColor를 Hex 문자열로 변환
    private func colorToHex(_ color: UIColor?) -> String? {
        guard let color = color else { return nil }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }

        // 투명이면 nil 반환
        if a == 0 { return nil }

        return String(format: "#%02X%02X%02X (%.0f%%)",
                      Int(r * 255), Int(g * 255), Int(b * 255), a * 100)
    }

    /// Glass 효과 체크 (재귀적으로 sublayers도 확인)
    private func checkGlassEffect(layer: CALayer) -> Bool {
        // filters 체크
        if let filters = layer.filters {
            for filter in filters {
                if let nsFilter = filter as? NSObject,
                   let name = nsFilter.value(forKey: "name") as? String,
                   name.contains("glass") || name.contains("Glass") {
                    return true
                }
            }
        }

        // backgroundFilters 체크
        if let bgFilters = layer.backgroundFilters {
            for filter in bgFilters {
                if let nsFilter = filter as? NSObject,
                   let name = nsFilter.value(forKey: "name") as? String,
                   name.contains("glass") || name.contains("Glass") {
                    return true
                }
            }
        }

        // sublayers 체크
        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                if checkGlassEffect(layer: sublayer) {
                    return true
                }
            }
        }

        return false
    }

    /// UIImageView 찾기 (아이콘 크기 추정용)
    private func findImageView(in view: UIView) -> UIImageView? {
        for subview in view.subviews {
            if let imageView = subview as? UIImageView {
                return imageView
            }
            if let found = findImageView(in: subview) {
                return found
            }
        }
        return nil
    }

    // MARK: - Save

    private func saveResult(_ result: ButtonDumpResult) {
        Log.print("[ButtonInspector] saveResult 시작")

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Log.print("[ButtonInspector] Documents 경로를 찾을 수 없습니다")
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let fileName = "\(timestamp)_buttons.json"

        Log.print("[ButtonInspector] 파일명: \(fileName)")

        do {
            let data = try encoder.encode(result)
            Log.print("[ButtonInspector] 인코딩 성공, 크기: \(data.count) bytes")

            let fileURL = documentsPath.appendingPathComponent(fileName)
            try data.write(to: fileURL)

            Log.print("[ButtonInspector] 파일 저장 완료: \(fileURL.path)")

            showAlert(fileName: fileName, buttonCount: result.buttons.count, path: documentsPath.path)
        } catch {
            Log.print("[ButtonInspector] 저장 실패: \(error)")
        }
    }

    // MARK: - Helpers

    private func getKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private func getCurrentScreenName() -> String {
        guard let window = getKeyWindow(), let rootVC = window.rootViewController else { return "Unknown" }

        var currentVC: UIViewController? = rootVC
        while let presented = currentVC?.presentedViewController {
            currentVC = presented
        }

        if let tabVC = currentVC as? UITabBarController, let selectedVC = tabVC.selectedViewController {
            currentVC = selectedVC
        }
        if let navVC = currentVC as? UINavigationController, let topVC = navVC.topViewController {
            currentVC = topVC
        }

        return String(describing: type(of: currentVC!))
    }

    private func showAlert(fileName: String, buttonCount: Int, path: String) {
        guard let window = getKeyWindow(), let rootVC = window.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }

        let message = "파일: \(fileName)\n버튼 수: \(buttonCount)개\n경로: \(path)"
        let alert = UIAlertController(title: "버튼 덤프 완료", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        topVC.present(alert, animated: true)
    }
}

#endif
