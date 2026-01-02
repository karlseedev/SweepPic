// FileLogger.swift
// 디버그 로그를 파일에 저장하는 유틸리티
//
// 사용법:
// - FileLogger.log("메시지")
// - 로그는 Documents/launch_log.txt에 저장됨
// - Xcode → Devices and Simulators → Download Container로 확인

import Foundation

/// 파일 기반 로거 (디버그용)
/// - 앱 시작 시 로그를 파일에 저장
/// - Console.app 없이 로그 확인 가능
public final class FileLogger {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = FileLogger()

    // MARK: - Launch Arguments (디버그 플래그)

    /// --log-thumb: 썸네일 해상도 디버그 로그 활성화
    public static let logThumbEnabled: Bool = CommandLine.arguments.contains("--log-thumb")

    // MARK: - Properties

    /// 로그 파일 URL
    private let logFileURL: URL

    /// 파일 핸들
    private var fileHandle: FileHandle?

    /// 시작 시간 (상대 시간 계산용)
    private let startTime: CFAbsoluteTime

    /// 동기화 큐
    private let queue = DispatchQueue(label: "com.pickphoto.filelogger")

    // MARK: - Initialization

    private init() {
        startTime = CFAbsoluteTimeGetCurrent()

        // Documents 디렉토리에 로그 파일 생성
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFileURL = docs.appendingPathComponent("launch_log.txt")

        // 기존 파일 삭제 (새 세션)
        try? FileManager.default.removeItem(at: logFileURL)

        // 새 파일 생성
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)

        // 파일 핸들 열기
        fileHandle = try? FileHandle(forWritingTo: logFileURL)

        // 헤더 작성
        let header = """
        === PickPhoto Launch Log ===
        Date: \(formattedDate())
        Device: \(deviceInfo())
        ============================

        """
        write(header)
    }

    deinit {
        try? fileHandle?.close()
    }

    // MARK: - Public API

    /// 로그 기록 (static 메서드)
    /// - Parameter message: 로그 메시지
    public static func log(_ message: String) {
        shared.logInternal(message)
    }

    /// 로그 파일 경로 반환
    public static var logFilePath: String {
        shared.logFileURL.path
    }

    // MARK: - Private

    private func logInternal(_ message: String) {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let timestamp = String(format: "+%.1fms", elapsed)
        let line = "[\(timestamp)] \(message)\n"

        // 콘솔에도 출력
        print(message)

        // 파일에 저장
        queue.async { [weak self] in
            self?.write(line)
        }
    }

    private func write(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        fileHandle?.write(data)
    }

    private func deviceInfo() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        return machine
    }

    /// 로컬 시간대로 포맷된 날짜 문자열
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current  // 로컬 시간대
        return formatter.string(from: Date())
    }
}
