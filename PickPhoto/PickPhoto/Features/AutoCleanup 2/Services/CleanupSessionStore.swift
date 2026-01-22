//
//  CleanupSessionStore.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  정리 세션 저장소 구현
//  - 파일 기반 JSON 저장/로드
//  - Documents/CleanupSession.json에 저장
//  - "이어서 정리" 기능 지원
//

import Foundation

/// 정리 세션 저장소
///
/// 정리 세션을 파일로 저장하고 로드하는 구현체.
/// 싱글톤 패턴으로 앱 전체에서 하나의 인스턴스 공유.
final class CleanupSessionStore: CleanupSessionStoreProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = CleanupSessionStore()

    // MARK: - Properties

    /// 메모리 캐시된 세션
    /// - 파일 I/O 최소화를 위해 메모리에 캐시
    private var cachedSession: CleanupSession?

    /// 캐시 로드 여부
    private var isCacheLoaded = false

    /// 세션 파일 경로
    private let sessionFilePath: URL

    /// JSON 인코더
    private let encoder: JSONEncoder

    /// JSON 디코더
    private let decoder: JSONDecoder

    /// 동시성 제어를 위한 큐
    private let queue = DispatchQueue(label: "com.pickphoto.cleanupsessionstore", qos: .utility)

    // MARK: - Initialization

    /// 기본 초기화 (Documents 디렉토리 사용)
    private init() {
        // Documents 디렉토리에 세션 파일 저장
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.sessionFilePath = documentsPath.appendingPathComponent(CleanupConstants.sessionFileName)

        // JSON 인코더/디코더 설정
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        // 초기 로드
        loadFromFile()
    }

    /// 테스트용 초기화 (커스텀 경로)
    init(filePath: URL) {
        self.sessionFilePath = filePath

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        loadFromFile()
    }

    // MARK: - CleanupSessionStoreProtocol

    /// 현재 저장된 세션
    var currentSession: CleanupSession? {
        return queue.sync { cachedSession }
    }

    /// 이어서 정리 가능 여부
    /// - 이전 세션이 존재하고 완료 상태일 때 true
    var canContinue: Bool {
        guard let session = currentSession else { return false }
        // 완료된 세션만 이어서 정리 가능
        // 취소된 세션은 이어서 정리 불가 (처음부터 다시)
        return session.status == .completed && session.lastAssetDate != nil
    }

    /// 세션 저장
    /// - Parameter session: 저장할 세션
    func save(_ session: CleanupSession) {
        queue.async { [weak self] in
            self?.cachedSession = session
            self?.saveToFile(session)
        }
    }

    /// 세션 로드
    /// - Returns: 저장된 세션 (없으면 nil)
    func load() -> CleanupSession? {
        return currentSession
    }

    /// 세션 삭제
    func clear() {
        queue.async { [weak self] in
            self?.cachedSession = nil
            self?.deleteFile()
        }
    }

    /// 세션 부분 업데이트
    func update(
        lastAssetDate: Date?,
        lastAssetID: String?,
        scannedCount: Int,
        foundCount: Int
    ) {
        queue.async { [weak self] in
            guard var session = self?.cachedSession else { return }

            session.updateProgress(
                scannedCount: scannedCount,
                foundCount: foundCount,
                lastAssetDate: lastAssetDate,
                lastAssetID: lastAssetID
            )

            self?.cachedSession = session
            // 부분 업데이트는 파일에 저장하지 않음 (메모리만)
            // 정상 종료 시에만 파일 저장
        }
    }

    // MARK: - Private Methods

    /// 파일에서 세션 로드
    private func loadFromFile() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isCacheLoaded else { return }

            do {
                guard FileManager.default.fileExists(atPath: self.sessionFilePath.path) else {
                    self.isCacheLoaded = true
                    return
                }

                let data = try Data(contentsOf: self.sessionFilePath)
                let session = try self.decoder.decode(CleanupSession.self, from: data)
                self.cachedSession = session
                self.isCacheLoaded = true

                #if DEBUG
                print("[CleanupSessionStore] Loaded session: \(session.id.uuidString.prefix(8))")
                #endif
            } catch {
                #if DEBUG
                print("[CleanupSessionStore] Failed to load session: \(error.localizedDescription)")
                #endif
                self.isCacheLoaded = true
            }
        }
    }

    /// 파일에 세션 저장
    private func saveToFile(_ session: CleanupSession) {
        do {
            let data = try encoder.encode(session)
            try data.write(to: sessionFilePath, options: .atomic)

            #if DEBUG
            print("[CleanupSessionStore] Saved session: \(session.id.uuidString.prefix(8))")
            #endif
        } catch {
            #if DEBUG
            print("[CleanupSessionStore] Failed to save session: \(error.localizedDescription)")
            #endif
        }
    }

    /// 세션 파일 삭제
    private func deleteFile() {
        do {
            if FileManager.default.fileExists(atPath: sessionFilePath.path) {
                try FileManager.default.removeItem(at: sessionFilePath)

                #if DEBUG
                print("[CleanupSessionStore] Deleted session file")
                #endif
            }
        } catch {
            #if DEBUG
            print("[CleanupSessionStore] Failed to delete session file: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Convenience Methods

extension CleanupSessionStore {

    /// 이전 세션 정보 요약 (UI 표시용)
    /// - Returns: "2024년 5월부터 계속" 형식의 문자열
    func previousSessionDescription() -> String? {
        guard let session = currentSession,
              let lastDate = session.lastAssetDate else {
            return nil
        }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: lastDate)
        let month = calendar.component(.month, from: lastDate)

        return "\(year)년 \(month)월부터 계속"
    }

    /// 이전 세션의 마지막 탐색 날짜
    var lastSessionDate: Date? {
        return currentSession?.lastAssetDate
    }

    /// 이전 세션의 찾은 사진 수
    var lastFoundCount: Int {
        return currentSession?.foundCount ?? 0
    }

    /// 이전 세션의 검색한 사진 수
    var lastScannedCount: Int {
        return currentSession?.scannedCount ?? 0
    }
}

// MARK: - Debug

#if DEBUG
extension CleanupSessionStore {

    /// 디버그용: 현재 세션 출력
    func debugPrintSession() {
        if let session = currentSession {
            print(session.description)
        } else {
            print("[CleanupSessionStore] No session stored")
        }
    }

    /// 디버그용: 테스트 세션 생성 및 저장
    func debugSaveTestSession() {
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        session.updateProgress(
            scannedCount: 500,
            foundCount: 25,
            lastAssetDate: Date().addingTimeInterval(-86400 * 30),  // 30일 전
            lastAssetID: "test-asset-id"
        )
        session.complete()
        save(session)
    }
}
#endif
