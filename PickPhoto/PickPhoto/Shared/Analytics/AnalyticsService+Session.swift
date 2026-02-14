// AnalyticsService+Session.swift
// 세션 관리: SessionCounters 구조체 + handleSessionEnd + flushCounters
//
// - 세션 = foreground→background 1회 사이클
// - 세션 종료 시 누적 카운터를 시그널로 변환 → 전송 → 리셋
// - 참조: docs/db/260212db-Archi.md 섹션 4.1~4.4

import Foundation
import TelemetryDeck
import AppCore

// MARK: - SessionCounters

/// 세션 동안 누적되는 모든 카운터
/// - 세션 종료 시 시그널로 변환 후 초기값으로 리셋
struct SessionCounters {

    // ── 이벤트 3: 사진 열람 ──
    struct PhotoViewing {
        var total: Int = 0          // 전체 열람 수
        var fromLibrary: Int = 0    // 보관함에서 열람
        var fromAlbum: Int = 0      // 앨범에서 열람
        var fromTrash: Int = 0      // 휴지통에서 열람

        var isZero: Bool { total == 0 }
    }

    // ── 이벤트 4-1: 보관함/앨범 삭제·복구 ──
    struct DeleteRestore {
        var gridSwipeDelete: Int = 0     // 그리드 스와이프 삭제
        var gridSwipeRestore: Int = 0    // 그리드 스와이프 복구
        var viewerSwipeDelete: Int = 0   // 뷰어 스와이프 삭제
        var viewerTrashButton: Int = 0   // 뷰어 휴지통 버튼
        var viewerRestoreButton: Int = 0 // 뷰어 복구 버튼
        var fromLibrary: Int = 0         // 보관함 경유 합계
        var fromAlbum: Int = 0           // 앨범 경유 합계

        var isZero: Bool {
            gridSwipeDelete == 0 && gridSwipeRestore == 0
            && viewerSwipeDelete == 0 && viewerTrashButton == 0
            && viewerRestoreButton == 0
        }
    }

    // ── 이벤트 4-2: 휴지통 뷰어 행동 ──
    struct TrashViewer {
        var permanentDelete: Int = 0   // 완전삭제
        var restore: Int = 0           // 보관함 복귀

        var isZero: Bool { permanentDelete == 0 && restore == 0 }
    }

    // ── 이벤트 5-1: 유사 사진 분석 ──
    struct SimilarAnalysis {
        var completedCount: Int = 0        // 분석 완료 횟수
        var cancelledCount: Int = 0        // 분석 취소 횟수
        var totalGroups: Int = 0           // 발견된 총 그룹 수 (완료 건의 합산)
        var totalDuration: TimeInterval = 0 // 총 소요시간 (완료 건의 합산, 평균 계산용)

        var isZero: Bool { completedCount == 0 && cancelledCount == 0 }

        /// 평균 소요시간 (초) — completedCount가 0이면 0
        var averageDuration: TimeInterval {
            completedCount > 0 ? totalDuration / Double(completedCount) : 0
        }
    }

    // ── 이벤트 6: 앱 오류 ──
    /// 키: "category.item" (예: "photoLoad.gridThumbnail")
    /// 값: 발생 횟수
    var errors: [String: Int] = [:]

    // ── 그룹 인스턴스 ──
    var photoViewing = PhotoViewing()
    var deleteRestore = DeleteRestore()
    var trashViewer = TrashViewer()
    var similarAnalysis = SimilarAnalysis()
}

// MARK: - Session Management

extension AnalyticsService {

    /// 세션 종료 처리
    /// - sceneDidEnterBackground에서 호출
    /// - barrier sync로 스냅샷 + 리셋 원자적 수행 후 플러시
    func handleSessionEnd() {
        guard !shouldSkip() else {
            Log.print("[Analytics] handleSessionEnd 스킵 (shouldSkip=true)")
            return
        }

        // 데드락 방지: queue 자체에서 호출되지 않는지 확인
        dispatchPrecondition(condition: .notOnQueue(queue))

        // barrier sync: 진행 중인 모든 barrier write 완료 대기 → 스냅샷 + 리셋
        let snapshot = queue.sync(flags: .barrier) { () -> SessionCounters in
            let current = self.counters
            self.counters = SessionCounters()  // 리셋
            return current
        }
        Log.print("[Analytics] 세션 종료 — 플러시 시작 (views=\(snapshot.photoViewing.total), deletes=\(snapshot.deleteRestore.gridSwipeDelete))")
        flushCounters(snapshot)
    }

    /// 세션 카운터 스냅샷을 시그널로 변환하여 전송
    /// - 각 그룹별로 isZero 확인 → 0이면 해당 시그널 스킵
    private func flushCounters(_ c: SessionCounters) {
        var sentCount = 0

        // ── 이벤트 3: 사진 열람 ──
        if !c.photoViewing.isZero {
            TelemetryDeck.signal("session.photoViewing", parameters: [
                "total":       String(c.photoViewing.total),
                "fromLibrary": String(c.photoViewing.fromLibrary),
                "fromAlbum":   String(c.photoViewing.fromAlbum),
                "fromTrash":   String(c.photoViewing.fromTrash),
            ])
            sentCount += 1
        }

        // ── 이벤트 4-1: 보관함/앨범 삭제·복구 ──
        if !c.deleteRestore.isZero {
            Log.print("[Analytics] flush deleteRestore → gridDel=\(c.deleteRestore.gridSwipeDelete) gridRes=\(c.deleteRestore.gridSwipeRestore) viewerDel=\(c.deleteRestore.viewerSwipeDelete) viewerTrash=\(c.deleteRestore.viewerTrashButton) viewerRes=\(c.deleteRestore.viewerRestoreButton)")
            TelemetryDeck.signal("session.deleteRestore", parameters: [
                "gridSwipeDelete":     String(c.deleteRestore.gridSwipeDelete),
                "gridSwipeRestore":    String(c.deleteRestore.gridSwipeRestore),
                "viewerSwipeDelete":   String(c.deleteRestore.viewerSwipeDelete),
                "viewerTrashButton":   String(c.deleteRestore.viewerTrashButton),
                "viewerRestoreButton": String(c.deleteRestore.viewerRestoreButton),
                "fromLibrary":         String(c.deleteRestore.fromLibrary),
                "fromAlbum":           String(c.deleteRestore.fromAlbum),
            ])
            sentCount += 1
        }

        // ── 이벤트 4-2: 휴지통 뷰어 행동 ──
        if !c.trashViewer.isZero {
            TelemetryDeck.signal("session.trashViewer", parameters: [
                "permanentDelete": String(c.trashViewer.permanentDelete),
                "restore":         String(c.trashViewer.restore),
            ])
            sentCount += 1
        }

        // ── 이벤트 5-1: 유사 사진 분석 ──
        if !c.similarAnalysis.isZero {
            TelemetryDeck.signal("session.similarAnalysis", parameters: [
                "completedCount":  String(c.similarAnalysis.completedCount),
                "cancelledCount":  String(c.similarAnalysis.cancelledCount),
                "totalGroups":     String(c.similarAnalysis.totalGroups),
                "avgDurationSec":  String(format: "%.1f", c.similarAnalysis.averageDuration),
            ])
            sentCount += 1
        }

        // ── 이벤트 6: 앱 오류 (비어있으면 스킵) ──
        if !c.errors.isEmpty {
            // 0이 아닌 항목만 파라미터에 포함
            let params = c.errors.compactMapValues { $0 > 0 ? String($0) : nil }
            if !params.isEmpty {
                TelemetryDeck.signal("session.errors", parameters: params)
                sentCount += 1
            }
        }

        Log.print("[Analytics] 플러시 완료 — \(sentCount)건 시그널 전송")
    }
}
