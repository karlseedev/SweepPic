//
//  GridAnalysisSessionRecorder.swift
//  SweepPic
//
//  Stage 2: Live Grid 분석 세션 기록기
//
//  Grid에서 formGroupsForRange()가 호출될 때마다 기록하고,
//  사용자가 수동으로 snapshot을 캡처하여 live 상태를 추출합니다.
//
//  shared 인스턴스에서만 기록합니다 (격리 인스턴스 기록 제외).
//
//  사용 흐름:
//  1. Grid에서 스크롤 → formGroupsForRange 호출 → 자동 기록
//  2. 스크롤 멈춤 → 분석 완료 대기
//  3. DEBUG 액션: captureSnapshot() → live 상태 추출
//  4. 저장된 snapshot을 수동 검증 자료로 사용
//

#if DEBUG

import Foundation
import OSLog
import AppCore

// MARK: - 데이터 타입

/// 정규화된 그룹 비교 단위.
/// memberAssetIDs를 정렬하여 순서 무관 비교를 수행합니다.
struct GroupSignature: Hashable, Codable {
    /// 정렬된 멤버 assetID 배열
    let members: [String]

    /// memberAssetIDs 배열에서 GroupSignature를 생성합니다.
    init(members: [String]) {
        self.members = members.sorted()
    }
}

/// Live Grid 최종 snapshot
///
/// SimilarityCache.shared의 현재 유효 그룹을 캡처합니다.
/// preliminary 상태 제외, isValid인 그룹만 포함합니다.
struct LiveGridFinalSnapshot: Codable {
    /// 최종 확정 그룹 (정규화된 GroupSignature)
    let groups: [GroupSignature]
    /// 캡처 시각
    let capturedAt: Date
}

/// Live Grid 분석 요청 기록
///
/// formGroupsForRange() 호출 시 기록되는 개별 요청 정보입니다.
struct LiveGridRequestRecord: Codable {
    /// 요청 식별자
    let requestID: String
    /// 요청 소스 (grid / viewer)
    let source: String
    /// 분석 범위 문자열 ("lowerBound...upperBound")
    let range: String
    /// 요청 시각
    let timestamp: Date
    /// 결과 ("completed" / "cancelled" / "pending")
    var outcome: String
    /// 완료 시 생성된 그룹 ID (완료일 때만 채워짐)
    var groupIDs: [String]?
}

/// Live Grid 세션 기록 전체
///
/// 하나의 세션 동안 기록된 모든 요청 + 최종 snapshot
struct LiveGridSessionRecord: Codable {
    /// 기록된 요청 배열
    let requests: [LiveGridRequestRecord]
    /// 최종 snapshot
    let finalSnapshot: LiveGridFinalSnapshot
}

// MARK: - GridAnalysisSessionRecorder

/// Grid 분석 세션 기록기
///
/// SimilarityAnalysisQueue.shared에서 formGroupsForRange()가 호출될 때
/// 자동으로 기록하고, 사용자가 수동으로 snapshot을 캡처할 수 있습니다.
final class GridAnalysisSessionRecorder {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = GridAnalysisSessionRecorder()

    // MARK: - State

    /// 기록된 요청 배열
    private var requests: [LiveGridRequestRecord] = []

    /// 동기화 큐
    private let lock = NSLock()

    // MARK: - Request Recording

    /// formGroupsForRange() 호출 시 기록합니다.
    ///
    /// SimilarityAnalysisQueue.shared에서만 호출되어야 합니다.
    ///
    /// - Parameters:
    ///   - id: 요청 식별자
    ///   - source: 요청 소스 (grid / viewer)
    ///   - range: 분석 범위
    func recordRequest(id: String, source: String, range: ClosedRange<Int>) {
        let record = LiveGridRequestRecord(
            requestID: id,
            source: source,
            range: "\(range.lowerBound)...\(range.upperBound)",
            timestamp: Date(),
            outcome: "pending",
            groupIDs: nil
        )
        lock.lock()
        requests.append(record)
        lock.unlock()

        Logger.similarPhoto.debug("[GridRecorder] 요청 기록: \(id), source=\(source), range=\(range.lowerBound)...\(range.upperBound)")
    }

    /// formGroupsForRange() 완료 시 기록합니다.
    ///
    /// - Parameters:
    ///   - id: 요청 식별자
    ///   - groupIDs: 생성된 그룹 ID 배열
    func recordCompletion(id: String, groupIDs: [String]) {
        lock.lock()
        if let index = requests.lastIndex(where: { $0.requestID == id }) {
            requests[index].outcome = "completed"
            requests[index].groupIDs = groupIDs
        }
        lock.unlock()

        Logger.similarPhoto.debug("[GridRecorder] 완료 기록: \(id), groups=\(groupIDs.count)")
    }

    /// cancel(source:) 호출 시 기록합니다.
    ///
    /// 해당 source의 미완료(pending) 요청을 찾아 cancelled로 마킹합니다.
    ///
    /// - Parameter source: 취소할 소스 (rawValue)
    func recordCancellation(source: String) {
        lock.lock()
        for i in requests.indices {
            if requests[i].source == source && requests[i].outcome == "pending" {
                requests[i].outcome = "cancelled"
            }
        }
        lock.unlock()

        Logger.similarPhoto.debug("[GridRecorder] 취소 기록: source=\(source)")
    }

    // MARK: - Snapshot

    /// 현재 SimilarityCache.shared의 최종 그룹 상태를 캡처합니다.
    ///
    /// 반드시 다음 조건에서 호출해야 합니다:
    /// - 스크롤이 멈춰 있고
    /// - 진행 중인 analysis가 없고
    /// - UI가 최종 배지 상태를 반영한 뒤
    ///
    /// - Returns: LiveGridFinalSnapshot
    func captureSnapshot() async -> LiveGridFinalSnapshot {
        let allGroups = await SimilarityCache.shared.debugAllGroups()
        let signatures = allGroups.map {
            GroupSignature(members: $0.memberAssetIDs)
        }
        let snapshot = LiveGridFinalSnapshot(groups: signatures, capturedAt: Date())

        Logger.similarPhoto.notice("[GridRecorder] Snapshot 캡처: \(signatures.count)개 그룹")

        return snapshot
    }

    // MARK: - Session Save

    /// 전체 세션 기록 + snapshot을 JSON으로 저장합니다.
    ///
    /// captureSnapshot() 호출 후 saveSession()을 호출하여
    /// 완전한 세션 기록을 저장합니다.
    func saveSession() async {
        let snapshot = await captureSnapshot()

        lock.lock()
        let recordsCopy = requests
        lock.unlock()

        let session = LiveGridSessionRecord(
            requests: recordsCopy,
            finalSnapshot: snapshot
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(session) else {
            Logger.similarPhoto.error("[GridRecorder] JSON 인코딩 실패")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())

        let timestampPath = "/tmp/grid-session-\(timestamp).json"
        let latestPath = "/tmp/grid-session-latest.json"

        do {
            try data.write(to: URL(fileURLWithPath: timestampPath))
            try data.write(to: URL(fileURLWithPath: latestPath))
            Logger.similarPhoto.notice("[GridRecorder] 세션 저장: \(timestampPath)")
        } catch {
            Logger.similarPhoto.error("[GridRecorder] 세션 저장 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - Reset

    /// 기록을 초기화합니다 (새 세션 시작용).
    func reset() {
        lock.lock()
        requests.removeAll()
        lock.unlock()

        Logger.similarPhoto.debug("[GridRecorder] 기록 초기화")
    }
}

#endif
