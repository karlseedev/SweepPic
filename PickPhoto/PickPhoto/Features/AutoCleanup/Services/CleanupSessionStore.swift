//
//  CleanupSessionStore.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  정리 세션 저장소 구현
//  - 파일 기반 JSON 저장/로드
//  - fromLatest/continueFromLast 세션과 byYear 세션 분리 저장
//  - "이어서 정리" 기능 지원
//

import Foundation
import AppCore

/// 정리 세션 저장소
///
/// 정리 세션을 파일로 저장하고 로드하는 구현체.
/// 싱글톤 패턴으로 앱 전체에서 하나의 인스턴스 공유.
/// fromLatest/continueFromLast 세션과 byYear 세션을 분리 저장.
final class CleanupSessionStore: CleanupSessionStoreProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = CleanupSessionStore()

    // MARK: - Properties

    /// 메모리 캐시된 최신사진부터 세션
    private var cachedLatestSession: CleanupSession?

    /// 메모리 캐시된 연도별 세션
    private var cachedByYearSession: CleanupSession?

    /// 캐시 로드 여부
    private var isCacheLoaded = false

    /// 최신사진부터 세션 파일 경로
    private let latestSessionFilePath: URL

    /// 연도별 세션 파일 경로
    private let byYearSessionFilePath: URL

    /// JSON 인코더
    private let encoder: JSONEncoder

    /// JSON 디코더
    private let decoder: JSONDecoder

    /// 동시성 제어를 위한 큐
    private let queue = DispatchQueue(label: "com.pickphoto.cleanupsessionstore", qos: .utility)

    /// 테스트용 인스턴스 여부 (동기 모드)
    private let isTestInstance: Bool

    // MARK: - Deinitialization

    deinit {
        // 비동기 작업 완료 대기 (테스트 인스턴스가 아닐 때만)
        // 테스트 인스턴스는 동기 모드이므로 대기 불필요
        if !isTestInstance {
            queue.sync { }  // 모든 대기 중인 작업 완료
        }
    }

    // MARK: - Initialization

    /// 기본 초기화 (Documents 디렉토리 사용)
    private init() {
        self.isTestInstance = false

        // Documents 디렉토리에 세션 파일 저장
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.latestSessionFilePath = documentsPath.appendingPathComponent("CleanupSessionLatest.json")
        self.byYearSessionFilePath = documentsPath.appendingPathComponent("CleanupSessionByYear.json")

        // JSON 인코더/디코더 설정
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        // 초기 로드
        loadFromFiles()
    }

    /// 테스트용 초기화 (커스텀 경로)
    /// - 테스트에서는 동기 모드를 사용하여 메모리 안정성 보장
    init(filePath: URL) {
        self.isTestInstance = true
        // 테스트용: 단일 파일 경로를 latest로 사용
        self.latestSessionFilePath = filePath
        self.byYearSessionFilePath = filePath.deletingLastPathComponent()
            .appendingPathComponent("TestCleanupSessionByYear.json")

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        // 테스트용: 동기적으로 로드 (비동기 해제 충돌 방지)
        loadFromFilesSync()
    }

    /// 동기적 파일 로드 (테스트용)
    private func loadFromFilesSync() {
        guard !isCacheLoaded else { return }

        // Latest 세션 로드
        if FileManager.default.fileExists(atPath: latestSessionFilePath.path) {
            do {
                let data = try Data(contentsOf: latestSessionFilePath)
                cachedLatestSession = try decoder.decode(CleanupSession.self, from: data)
                #if DEBUG
                Log.print("[CleanupSessionStore] Loaded latest session (sync)")
                #endif
            } catch {
                #if DEBUG
                Log.print("[CleanupSessionStore] Failed to load latest session: \(error.localizedDescription)")
                #endif
            }
        }

        // ByYear 세션 로드
        if FileManager.default.fileExists(atPath: byYearSessionFilePath.path) {
            do {
                let data = try Data(contentsOf: byYearSessionFilePath)
                cachedByYearSession = try decoder.decode(CleanupSession.self, from: data)
                #if DEBUG
                Log.print("[CleanupSessionStore] Loaded byYear session (sync)")
                #endif
            } catch {
                #if DEBUG
                Log.print("[CleanupSessionStore] Failed to load byYear session: \(error.localizedDescription)")
                #endif
            }
        }

        isCacheLoaded = true
    }

    // MARK: - CleanupSessionStoreProtocol

    /// 현재 저장된 세션 (하위 호환용, latestSession 우선 반환)
    var currentSession: CleanupSession? {
        return queue.sync { cachedLatestSession ?? cachedByYearSession }
    }

    /// 최신사진부터/이어서 정리 세션
    var latestSession: CleanupSession? {
        return queue.sync { cachedLatestSession }
    }

    /// 연도별 정리 세션
    var byYearSession: CleanupSession? {
        return queue.sync { cachedByYearSession }
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
    /// - method에 따라 자동으로 분리 저장
    func save(_ session: CleanupSession) {
        if isTestInstance {
            // 테스트용: 동기 저장
            saveSessionByMethod(session)
        } else {
            queue.async { [weak self] in
                self?.saveSessionByMethod(session)
            }
        }
    }

    /// method에 따라 세션 분리 저장
    private func saveSessionByMethod(_ session: CleanupSession) {
        switch session.method {
        case .fromLatest, .continueFromLast:
            cachedLatestSession = session
            saveToFile(session, path: latestSessionFilePath)
            #if DEBUG
            Log.print("[CleanupSessionStore] Saved latest session: \(session.id.uuidString.prefix(8))")
            #endif

        case .byYear:
            cachedByYearSession = session
            saveToFile(session, path: byYearSessionFilePath)
            #if DEBUG
            Log.print("[CleanupSessionStore] Saved byYear session: \(session.id.uuidString.prefix(8))")
            #endif
        }
    }

    /// 세션 로드
    /// - Returns: 저장된 세션 (없으면 nil)
    func load() -> CleanupSession? {
        return currentSession
    }

    /// 세션 삭제 (모든 세션)
    func clear() {
        if isTestInstance {
            // 테스트용: 동기 삭제
            cachedLatestSession = nil
            cachedByYearSession = nil
            deleteFile(path: latestSessionFilePath)
            deleteFile(path: byYearSessionFilePath)
        } else {
            queue.async { [weak self] in
                self?.cachedLatestSession = nil
                self?.cachedByYearSession = nil
                self?.deleteFile(path: self?.latestSessionFilePath)
                self?.deleteFile(path: self?.byYearSessionFilePath)
            }
        }
    }

    /// 세션 부분 업데이트 (현재 진행 중인 세션)
    /// - 테스트 호환성을 위해 latestSession 업데이트
    func update(
        lastAssetDate: Date?,
        lastAssetID: String?,
        scannedCount: Int,
        foundCount: Int
    ) {
        let updateBlock = { [weak self] in
            // latestSession 업데이트 (기존 동작 호환)
            guard var session = self?.cachedLatestSession else { return }

            session.updateProgress(
                scannedCount: scannedCount,
                foundCount: foundCount,
                lastAssetDate: lastAssetDate,
                lastAssetID: lastAssetID
            )

            self?.cachedLatestSession = session
            // 부분 업데이트는 파일에 저장하지 않음 (메모리만)
        }

        if isTestInstance {
            updateBlock()
        } else {
            queue.async(execute: updateBlock)
        }
    }

    // MARK: - Private Methods

    /// 파일에서 세션 로드
    private func loadFromFiles() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isCacheLoaded else { return }

            let localDecoder = JSONDecoder()
            localDecoder.dateDecodingStrategy = .iso8601

            // Latest 세션 로드
            if FileManager.default.fileExists(atPath: self.latestSessionFilePath.path) {
                do {
                    let data = try Data(contentsOf: self.latestSessionFilePath)
                    self.cachedLatestSession = try localDecoder.decode(CleanupSession.self, from: data)
                    #if DEBUG
                    Log.print("[CleanupSessionStore] Loaded latest session")
                    #endif
                } catch {
                    #if DEBUG
                    Log.print("[CleanupSessionStore] Failed to load latest session: \(error.localizedDescription)")
                    #endif
                }
            }

            // ByYear 세션 로드
            if FileManager.default.fileExists(atPath: self.byYearSessionFilePath.path) {
                do {
                    let data = try Data(contentsOf: self.byYearSessionFilePath)
                    self.cachedByYearSession = try localDecoder.decode(CleanupSession.self, from: data)
                    #if DEBUG
                    Log.print("[CleanupSessionStore] Loaded byYear session")
                    #endif
                } catch {
                    #if DEBUG
                    Log.print("[CleanupSessionStore] Failed to load byYear session: \(error.localizedDescription)")
                    #endif
                }
            }

            self.isCacheLoaded = true
        }
    }

    /// 파일에 세션 저장
    private func saveToFile(_ session: CleanupSession, path: URL) {
        do {
            let data = try encoder.encode(session)
            try data.write(to: path, options: .atomic)
        } catch {
            #if DEBUG
            Log.print("[CleanupSessionStore] Failed to save session: \(error.localizedDescription)")
            #endif
        }
    }

    /// 세션 파일 삭제
    private func deleteFile(path: URL?) {
        guard let path = path else { return }
        do {
            if FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.removeItem(at: path)
                #if DEBUG
                Log.print("[CleanupSessionStore] Deleted session file: \(path.lastPathComponent)")
                #endif
            }
        } catch {
            #if DEBUG
            Log.print("[CleanupSessionStore] Failed to delete session file: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Convenience Methods

extension CleanupSessionStore {

    /// 이전 세션 정보 요약 (UI 표시용)
    /// - Returns: "2024년 5월부터 계속" 형식의 문자열
    func previousSessionDescription() -> String? {
        guard let session = latestSession,
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
        return latestSession?.lastAssetDate
    }

    /// 이전 세션의 찾은 사진 수
    var lastFoundCount: Int {
        return latestSession?.foundCount ?? 0
    }

    /// 이전 세션의 검색한 사진 수
    var lastScannedCount: Int {
        return latestSession?.scannedCount ?? 0
    }
}

// MARK: - Debug

#if DEBUG
extension CleanupSessionStore {

    /// 디버그용: 현재 세션 출력
    func debugPrintSession() {
        Log.print("[CleanupSessionStore] --- Sessions ---")
        if let latest = latestSession {
            print("Latest: \(latest.description)")
        } else {
            print("Latest: nil")
        }
        if let byYear = byYearSession {
            print("ByYear: \(byYear.description)")
        } else {
            print("ByYear: nil")
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
