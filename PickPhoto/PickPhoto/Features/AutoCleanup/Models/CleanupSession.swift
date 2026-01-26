//
//  CleanupSession.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  정리 세션 상태 정의
//  - 세션 식별 및 생성 정보
//  - 탐색 위치 추적 (이어서 정리용)
//  - 정리 방식 및 모드
//  - 진행 상황 (검색 수, 찾은 수, 이동한 사진 목록)
//  - 세션 상태 (idle/scanning/paused/completed/cancelled)
//
//  파일 기반 저장으로 앱 재시작 후에도 "이어서 정리" 지원
//  저장 위치: Documents/CleanupSession.json
//

import Foundation

/// 정리 세션 상태
///
/// 정리 작업의 전체 상태를 관리하는 모델.
/// Codable을 준수하여 JSON으로 파일 저장/로드 가능.
/// Sendable을 준수하여 Swift 6 concurrency에서 안전하게 사용 가능.
struct CleanupSession: Equatable, Sendable {

    // MARK: - 식별자

    /// 세션 ID
    /// - 각 정리 세션의 고유 식별자
    let id: UUID

    /// 세션 생성 시간
    let createdAt: Date

    // MARK: - 탐색 위치

    /// 시작점
    /// - 최신사진부터: 가장 최근 사진의 creationDate
    /// - 이어서 정리: 이전 세션의 lastAssetDate
    /// - 연도별: 해당 연도 12월 31일 23:59:59
    let startDate: Date

    /// 마지막 탐색 사진의 creationDate
    /// - "이어서 정리"의 시작점으로 사용
    /// - 탐색 중 업데이트됨
    var lastAssetDate: Date?

    /// 마지막 탐색 사진의 localIdentifier
    /// - 같은 날짜 내 정확한 위치 추적용
    /// - 같은 creationDate를 가진 여러 사진 중 마지막 처리한 사진
    var lastAssetID: String?

    // MARK: - 정리 방식

    /// 정리 방식
    /// - fromLatest: 최신사진부터
    /// - continueFromLast: 이어서 정리
    /// - byYear: 연도별 정리
    let method: CleanupMethod

    /// 판별 모드
    /// - precision: 신중한 정리 (Strong 신호만)
    /// - recall: 적극적 정리 (1차에서는 미사용)
    let mode: JudgmentMode

    // MARK: - 진행 상황

    /// 검색한 사진 수
    /// - 최대 1,000장
    var scannedCount: Int

    /// 찾은 저품질 사진 수
    /// - 최대 50장
    var foundCount: Int

    /// 휴지통으로 이동한 사진 ID 목록
    /// - PHAsset.localIdentifier 배열
    var trashedAssetIDs: [String]

    // MARK: - 상태

    /// 세션 상태
    var status: SessionStatus

    /// 종료 사유
    /// - nil: 아직 종료되지 않음
    /// - maxFound: 50장 도달 (이어서 정리 가능)
    /// - maxScanned: 1000장 검색 (이어서 정리 가능)
    /// - endOfRange: 범위 끝 도달 (이어서 정리 불가)
    /// - userCancelled: 사용자 취소
    var endReason: EndReason?

    /// 마지막 업데이트 시간
    var updatedAt: Date

    // MARK: - Initializer

    /// 새 세션 생성
    /// - Parameters:
    ///   - method: 정리 방식
    ///   - mode: 판별 모드 (기본: precision)
    ///   - startDate: 시작 날짜 (기본: 현재)
    init(
        method: CleanupMethod,
        mode: JudgmentMode = .precision,
        startDate: Date = Date()
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.startDate = startDate
        self.lastAssetDate = nil
        self.lastAssetID = nil
        self.method = method
        self.mode = mode
        self.scannedCount = 0
        self.foundCount = 0
        self.trashedAssetIDs = []
        self.status = .idle
        self.endReason = nil
        self.updatedAt = Date()
    }

    /// 이어서 정리용 세션 생성
    /// - Parameters:
    ///   - previousSession: 이전 세션 (마지막 탐색 위치 참조)
    ///   - mode: 판별 모드
    init(continuingFrom previousSession: CleanupSession, mode: JudgmentMode = .precision) {
        self.id = UUID()
        self.createdAt = Date()
        // 이전 세션의 마지막 탐색 위치부터 시작
        self.startDate = previousSession.lastAssetDate ?? previousSession.startDate
        self.lastAssetDate = nil
        self.lastAssetID = nil
        self.method = .continueFromLast
        self.mode = mode
        self.scannedCount = 0
        self.foundCount = 0
        self.trashedAssetIDs = []
        self.status = .idle
        self.endReason = nil
        self.updatedAt = Date()
    }

    /// 연도별 정리용 세션 생성
    /// - Parameters:
    ///   - year: 정리할 연도
    ///   - mode: 판별 모드
    init(year: Int, mode: JudgmentMode = .precision) {
        self.id = UUID()
        self.createdAt = Date()
        // 해당 연도 12월 31일 23:59:59부터 시작 (최신 → 오래된 순)
        self.startDate = CleanupSession.endOfYear(year)
        self.lastAssetDate = nil
        self.lastAssetID = nil
        self.method = .byYear(year: year)
        self.mode = mode
        self.scannedCount = 0
        self.foundCount = 0
        self.trashedAssetIDs = []
        self.status = .idle
        self.endReason = nil
        self.updatedAt = Date()
    }
}

// MARK: - 상태 업데이트

extension CleanupSession {

    /// 검색 시작
    mutating func startScanning() {
        guard status.canTransition(to: .scanning) else { return }
        status = .scanning
        updatedAt = Date()
    }

    /// 일시정지 (백그라운드 전환)
    mutating func pause() {
        guard status.canTransition(to: .paused) else { return }
        status = .paused
        updatedAt = Date()
    }

    /// 재개 (포그라운드 복귀)
    mutating func resume() {
        guard status.canTransition(to: .scanning) else { return }
        status = .scanning
        updatedAt = Date()
    }

    /// 완료
    mutating func complete() {
        guard status.canTransition(to: .completed) else { return }
        status = .completed
        updatedAt = Date()
    }

    /// 취소
    mutating func cancel() {
        guard status.canTransition(to: .cancelled) else { return }
        status = .cancelled
        // 취소 시 이동한 사진 목록 초기화 (아무것도 이동하지 않음)
        trashedAssetIDs = []
        updatedAt = Date()
    }

    /// 진행 상황 업데이트
    /// - Parameters:
    ///   - scannedCount: 검색한 사진 수
    ///   - foundCount: 찾은 저품질 사진 수
    ///   - lastAssetDate: 마지막 탐색 사진의 날짜
    ///   - lastAssetID: 마지막 탐색 사진의 ID
    mutating func updateProgress(
        scannedCount: Int,
        foundCount: Int,
        lastAssetDate: Date?,
        lastAssetID: String?
    ) {
        self.scannedCount = scannedCount
        self.foundCount = foundCount
        self.lastAssetDate = lastAssetDate
        self.lastAssetID = lastAssetID
        self.updatedAt = Date()
    }

    /// 휴지통 이동 기록
    /// - Parameter assetID: 이동한 사진 ID
    mutating func recordTrashed(assetID: String) {
        trashedAssetIDs.append(assetID)
        foundCount = trashedAssetIDs.count
        updatedAt = Date()
    }

    /// 여러 사진 휴지통 이동 기록
    /// - Parameter assetIDs: 이동한 사진 ID 배열
    mutating func recordTrashed(assetIDs: [String]) {
        trashedAssetIDs.append(contentsOf: assetIDs)
        foundCount = trashedAssetIDs.count
        updatedAt = Date()
    }
}

// MARK: - Validation

extension CleanupSession {

    /// 종료 조건 확인
    var shouldTerminate: Bool {
        return hasReachedMaxFound || hasReachedMaxScanned
    }

    /// 최대 찾기 수 도달 여부
    var hasReachedMaxFound: Bool {
        return foundCount >= CleanupConstants.maxFoundCount
    }

    /// 최대 검색 수 도달 여부
    var hasReachedMaxScanned: Bool {
        return scannedCount >= CleanupConstants.maxScanCount
    }

    /// 연도별 정리인 경우 해당 연도
    var targetYear: Int? {
        if case .byYear(let year) = method {
            return year
        }
        return nil
    }

    /// 이어서 정리 가능 여부
    /// - 50장 도달 또는 1000장 검색 도달 시에만 이어서 정리 가능
    /// - 범위 끝 도달 또는 사용자 취소 시에는 이어서 정리 불가
    var canContinue: Bool {
        guard let reason = endReason else { return false }
        return reason == .maxFound || reason == .maxScanned
    }

    /// fromLatest 방식의 이어서 정리 가능 여부
    /// - method가 fromLatest 또는 continueFromLast이고 이어서 정리 가능한 경우
    var canContinueFromLatest: Bool {
        switch method {
        case .fromLatest, .continueFromLast:
            return canContinue
        case .byYear:
            return false
        }
    }

    /// 연도별 이어서 정리 가능 여부
    /// - method가 byYear이고 이어서 정리 가능한 경우
    var canContinueByYear: Bool {
        guard case .byYear = method else { return false }
        return canContinue
    }

    /// 유효한 세션인지 확인
    var isValid: Bool {
        // 기본 제약 조건 확인
        guard scannedCount <= CleanupConstants.maxScanCount else { return false }
        guard foundCount <= CleanupConstants.maxFoundCount else { return false }
        guard trashedAssetIDs.count == foundCount else { return false }
        if let lastDate = lastAssetDate {
            guard lastDate <= startDate else { return false }
        }
        return true
    }
}

// MARK: - Helper Methods

extension CleanupSession {

    /// 연도의 마지막 날짜 (12월 31일 23:59:59)
    static func endOfYear(_ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 12
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59

        let calendar = Calendar.current
        return calendar.date(from: components) ?? Date()
    }

    /// 연도의 첫 날짜 (1월 1일 00:00:00)
    static func startOfYear(_ year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0

        let calendar = Calendar.current
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - CustomStringConvertible

extension CleanupSession: CustomStringConvertible {

    /// 디버그/로깅용 문자열 표현
    var description: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        return """
        [CleanupSession]
        - ID: \(id.uuidString.prefix(8))...
        - Method: \(method)
        - Mode: \(mode)
        - Status: \(status)
        - Scanned: \(scannedCount)/\(CleanupConstants.maxScanCount)
        - Found: \(foundCount)/\(CleanupConstants.maxFoundCount)
        - Trashed: \(trashedAssetIDs.count)
        - Start: \(dateFormatter.string(from: startDate))
        - Last: \(lastAssetDate.map { dateFormatter.string(from: $0) } ?? "N/A")
        """
    }
}

// MARK: - Codable (Swift 6 호환)

/// Swift 6 concurrency 격리 문제 해결을 위해 명시적 nonisolated Codable 구현
/// DispatchQueue.async 등 nonisolated context에서 안전하게 decode/encode 가능
extension CleanupSession: Codable {

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, startDate, lastAssetDate, lastAssetID
        case method, mode, scannedCount, foundCount, trashedAssetIDs
        case status, endReason, updatedAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startDate = try container.decode(Date.self, forKey: .startDate)
        lastAssetDate = try container.decodeIfPresent(Date.self, forKey: .lastAssetDate)
        lastAssetID = try container.decodeIfPresent(String.self, forKey: .lastAssetID)
        method = try container.decode(CleanupMethod.self, forKey: .method)
        mode = try container.decode(JudgmentMode.self, forKey: .mode)
        scannedCount = try container.decode(Int.self, forKey: .scannedCount)
        foundCount = try container.decode(Int.self, forKey: .foundCount)
        trashedAssetIDs = try container.decode([String].self, forKey: .trashedAssetIDs)
        status = try container.decode(SessionStatus.self, forKey: .status)
        endReason = try container.decodeIfPresent(EndReason.self, forKey: .endReason)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(lastAssetDate, forKey: .lastAssetDate)
        try container.encodeIfPresent(lastAssetID, forKey: .lastAssetID)
        try container.encode(method, forKey: .method)
        try container.encode(mode, forKey: .mode)
        try container.encode(scannedCount, forKey: .scannedCount)
        try container.encode(foundCount, forKey: .foundCount)
        try container.encode(trashedAssetIDs, forKey: .trashedAssetIDs)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(endReason, forKey: .endReason)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
