#if DEBUG
import Foundation
import AppCore
import OSLog

/// Analytics Test A용 테스트 이벤트/카운터 주입기
/// - Launch argument `--analytics-test-inject`가 있을 때만 동작
final class AnalyticsTestInjector {

    static let launchArgument = "--analytics-test-inject"

    /// Launch argument 확인
    static var shouldRun: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// SceneDelegate.showMainInterface()에서 호출
    static func runIfNeeded() {
        guard shouldRun else { return }

        Logger.appDebug.debug("테스트 주입 모드 감지")

        // SDK 초기화 + UI 안정화 대기 후 실행
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            injectAndFlush()
        }
    }

    private static func injectAndFlush() {
        let service = AnalyticsService.shared

        // 1) 즉시 전송 이벤트 (4건 직접 발사 + app.launched 1건 자동)
        triggerImmediateEvents(service)

        // 2) 세션 카운터 주입 (barrier write)
        service.queue.async(flags: .barrier) {
            injectSessionCounters(&service.counters)
            Logger.appDebug.debug("세션 카운터 주입 완료")

            // 3) 메인 스레드에서 flush (barrier 외부)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                service.handleSessionEnd()
                Logger.appDebug.debug("flush 실행 완료")
            }
        }
    }

    private static func triggerImmediateEvents(_ service: AnalyticsService) {
        // app.launched는 sceneWillEnterForeground에서 자동 발사

        // Supabase 제외 대상 (음성 테스트용)
        service.trackPermissionResult(result: .fullAccess, timing: .settingsChange)

        service.trackSimilarGroupClosed(totalCount: 12, deletedCount: 5)

        service.trackCleanupCompleted(data: CleanupEventData(
            reachedStage: .cleanupDone,
            trashWarningShown: true,
            method: .fromLatest,
            result: .completed,
            foundCount: 23,
            durationSec: 45.3,
            cancelProgress: nil,
            resultAction: nil
        ))

        service.trackPreviewCleanupCompleted(data: PreviewCleanupEventData(
            reachedStage: .finalAction,
            foundCount: 15,
            durationSec: 28.7,
            maxStageReached: .standard,
            expandCount: 4,
            collapseCount: 1,
            excludeCount: 2,
            viewerOpenCount: 3,
            finalAction: .moveToTrash,
            movedCount: 11
        ))

        Logger.appDebug.debug("즉시 전송 이벤트 4건 발사")
    }

    private static func injectSessionCounters(_ counters: inout SessionCounters) {
        counters.photoViewing = .init(total: 17, fromLibrary: 10, fromAlbum: 5, fromTrash: 2)

        counters.deleteRestore = .init(
            gridSwipeDelete: 9,
            gridSwipeRestore: 3,
            viewerSwipeDelete: 7,
            viewerTrashButton: 4,
            viewerRestoreButton: 2,
            fromLibrary: 14,
            fromAlbum: 11
        )

        counters.trashViewer = .init(permanentDelete: 6, restore: 8)

        counters.similarAnalysis = .init(
            completedCount: 3,
            cancelledCount: 1,
            totalGroups: 11,
            totalDuration: 14.1 // avg = 14.1 / 3 = 4.7
        )

        counters.errors = [
            "photoLoad.gridThumbnail": 5,
            "face.detection": 2,
            "cleanup.trashMove": 1,
        ]

        // Supabase 제외 대상이지만 flush 경로 검증용으로 주입
        counters.gridPerformance = .init(grayShown: 42)
    }
}
#endif
