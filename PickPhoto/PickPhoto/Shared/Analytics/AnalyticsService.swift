// AnalyticsService.swift
// TelemetryDeck 분석 서비스 본체
//
// - 싱글톤 패턴
// - SDK 초기화 (configure)
// - 사진 규모 구간 캐싱 (defaultParameters)
// - 옵트아웃 guard
// - 누적 카운터 + concurrent queue 보호
// - 참조: docs/db/260212db-Archi.md 섹션 3.5, 4.2, 4.3, 5.6

import Foundation
import Photos
import TelemetryDeck
import AppCore

// MARK: - AnalyticsServiceProtocol

/// 앱 전체에서 호출하는 분석 서비스 인터페이스
/// - PickPhoto 모듈 내부 프로토콜 (internal)
/// - ScreenSource, DeleteSource 등 내부 enum을 참조하므로 public 불필요
protocol AnalyticsServiceProtocol: AnyObject {

    // ══════════════════════════════════════
    // 즉시 전송형
    // ══════════════════════════════════════
    func trackAppLaunched()
    func trackPermissionResult(result: PermissionResultType, timing: PermissionTiming)

    // ══════════════════════════════════════
    // 세션 누적형 — 카운터 증가만 (전송은 세션 종료 시)
    // ══════════════════════════════════════

    // 이벤트 3: 사진 열람
    func countPhotoViewed(from source: ScreenSource)

    // 이벤트 4-1: 보관함/앨범 삭제·복구
    func countGridSwipeDelete(source: DeleteSource)
    func countGridSwipeRestore(source: DeleteSource)
    func countViewerSwipeDelete(source: DeleteSource?)
    func countViewerTrashButton(source: DeleteSource?)
    func countViewerRestoreButton(source: DeleteSource?)

    // 이벤트 4-2: 삭제대기함 뷰어
    func countTrashPermanentDelete()
    func countTrashRestore()

    // 이벤트 5-1: 유사 분석
    func countSimilarAnalysisCompleted(groups: Int, duration: TimeInterval)
    func countSimilarAnalysisCancelled()

    // 이벤트 6: 오류 (카테고리별 오버로드)
    func countError(_ error: AnalyticsError.PhotoLoad)
    func countError(_ error: AnalyticsError.Face)
    func countError(_ error: AnalyticsError.Cleanup)
    func countError(_ error: AnalyticsError.Video)
    func countError(_ error: AnalyticsError.Storage)

    // 이벤트 8: 그리드 성능
    func countGrayShown()

    // ══════════════════════════════════════
    // 그룹별 즉시 전송
    // ══════════════════════════════════════
    func trackSimilarGroupClosed(totalCount: Int, deletedCount: Int)

    // ══════════════════════════════════════
    // 정리 기능 — 종료 시 1건
    // ══════════════════════════════════════
    func trackCleanupCompleted(data: CleanupEventData)
    func trackPreviewCleanupCompleted(data: PreviewCleanupEventData)

    // ══════════════════════════════════════
    // 라이프사이클
    // ══════════════════════════════════════
    func handleSessionEnd()
}

// MARK: - AnalyticsService

/// TelemetryDeck 분석 서비스 싱글톤
/// - configure()로 SDK 초기화
/// - countXxx()로 세션 카운터 누적
/// - handleSessionEnd()로 세션 요약 전송
final class AnalyticsService: AnalyticsServiceProtocol {

    // MARK: - Singleton

    static let shared = AnalyticsService()
    private init() {}

    // MARK: - Constants

    /// 옵트아웃 UserDefaults 키
    private static let optOutKey = "analytics_opt_out"

    // MARK: - Properties

    /// 누적 카운터 보호용 concurrent queue
    /// - 읽기: queue.sync { ... }       (동시 허용)
    /// - 쓰기: queue.async(flags: .barrier) { ... } (독점)
    let queue = DispatchQueue(label: "com.pickphoto.analytics", attributes: .concurrent)

    /// 현재 세션의 누적 카운터 (queue 보호 하에 접근)
    var counters = SessionCounters()

    /// 사진 규모 구간 캐싱 값 (포그라운드 진입 시 갱신)
    nonisolated(unsafe) private var photoLibraryBucket: String = "unknown"

    /// SDK 초기화 여부
    private var isConfigured = false

    /// Supabase 이벤트 전송 프로바이더 (credentials 없으면 nil → 비활성)
    private var supabaseProvider: SupabaseProvider?

    /// Supabase에 보내지 않을 이벤트 목록 (비용 절감)
    /// - permission.result: 극소량, TD에서 충분
    /// - session.gridPerformance: 카운트만, 드릴다운 가치 낮음
    private static let supabaseExcluded: Set<String> = [
        "permission.result",
        "session.gridPerformance",
    ]

    /// 백그라운드 플러시 완료 콜백 (SceneDelegate의 endBackgroundTask용)
    var onFlushComplete: (() -> Void)?

    // MARK: - Opt-out

    /// 옵트아웃 여부 확인
    /// - UserDefaults에서 매번 조회 (설정 즉시 반영)
    var isOptedOut: Bool {
        UserDefaults.standard.bool(forKey: Self.optOutKey)
    }

    /// 옵트아웃 설정/해제
    /// - Parameter optOut: true면 수집 중단
    static func setOptOut(_ optOut: Bool) {
        UserDefaults.standard.set(optOut, forKey: optOutKey)
    }

    // MARK: - Configure

    /// SDK 초기화
    /// - Parameter appID: TelemetryDeck App ID
    /// - Note: AppDelegate.didFinishLaunchingWithOptions에서 1회 호출
    func configure(appID: String) {
        // 옵트아웃 상태도 SDK에 전달
        let config = TelemetryDeck.Config(appID: appID)
        config.defaultSignalPrefix = "PickPhoto."

        // 사진 규모 구간을 defaultParameters로 자동 첨부
        config.defaultParameters = { [weak self] in
            guard let self = self else { return [:] }
            let bucket = self.queue.sync { self.photoLibraryBucket }
            return ["photoLibraryBucket": bucket]
        }

        TelemetryDeck.initialize(config: config)
        isConfigured = true
        configureSupabase()
        Log.print("[Analytics] SDK 초기화 완료 (appID: \(appID.prefix(8))...)")
    }

    // MARK: - Photo Library Bucket

    /// 사진 규모 구간 갱신
    /// - 포그라운드 진입 시마다 호출
    /// - PHAsset.fetchAssets를 호출하므로 메인 스레드에서 호출 권장
    func refreshPhotoLibraryBucket() {
        let fetchResult = PHAsset.fetchAssets(with: nil)
        let count = fetchResult.count
        let bucket = Self.bucketString(for: count)
        queue.async(flags: .barrier) { self.photoLibraryBucket = bucket }
    }

    /// 사진 수 → 규모 구간 문자열 변환
    /// - 대시보드에서 구간별 분석에 사용
    static func bucketString(for count: Int) -> String {
        switch count {
        case 0:             return "0"
        case 1...100:       return "1-100"
        case 101...500:     return "101-500"
        case 501...1000:    return "501-1K"
        case 1001...5000:   return "1K-5K"
        case 5001...10000:  return "5K-10K"
        case 10001...50000: return "10K-50K"
        case 50001...100000: return "50K-100K"
        default:            return "100K+"
        }
    }

    // MARK: - Guard Helper

    /// 옵트아웃 또는 미초기화 시 true 반환 (조기 리턴용)
    /// - 모든 count/track 메서드 진입부에서 사용
    func shouldSkip() -> Bool {
        if isOptedOut { return true }
        if !isConfigured {
            #if DEBUG
            assertionFailure("[Analytics] configure() 호출 전에 이벤트 전송 시도")
            #endif
            return true
        }
        return false
    }

    // MARK: - Supabase Configuration

    /// Supabase 프로바이더 초기화
    /// - Info.plist에서 SUPABASE_URL, SUPABASE_ANON_KEY 읽기
    /// - 키가 없으면 (xcconfig 미설정) 비활성 → TD만 동작
    private func configureSupabase() {
        let rawURL = Bundle.main.infoDictionary?["SUPABASE_URL"]
        let rawKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"]
        Log.print("[Supabase] configureSupabase — URL: \(rawURL ?? "nil"), Key: \(rawKey == nil ? "nil" : "exists")")

        guard let url = rawURL as? String,
              let key = rawKey as? String,
              !url.isEmpty, !key.isEmpty else {
            Log.print("[Supabase] credentials 없음 — 비활성")
            return
        }
        supabaseProvider = SupabaseProvider(baseURL: url, anonKey: key)
        Log.print("[Supabase] 초기화 완료 (url: \(url.prefix(30))...)")
    }

    // MARK: - Dual Send Helpers

    /// TD + Supabase 이중 전송 (즉시 전송형 이벤트용)
    /// - TelemetryDeck: 항상 전송 (SDK가 "PickPhoto." prefix 자동 추가)
    /// - Supabase: supabaseExcluded에 없을 때만 전송
    func sendEvent(_ name: String, parameters: [String: String] = [:]) {
        TelemetryDeck.signal(name, parameters: parameters)

        guard !Self.supabaseExcluded.contains(name) else { return }
        let bucket = queue.sync { photoLibraryBucket }
        supabaseProvider?.send(
            eventName: name,
            params: parameters,
            photoBucket: bucket
        )
    }

    /// TD 개별 전송 + Supabase 배치 전송 (flushCounters용)
    /// - TD: 이벤트 개별 signal (기존 동작 유지)
    /// - Supabase: 제외 필터링 후 남은 이벤트를 1회 배치 POST
    func sendEventBatch(_ events: [(name: String, parameters: [String: String])]) {
        // 1) TD 개별 전송
        for event in events {
            TelemetryDeck.signal(event.name, parameters: event.parameters)
        }

        // 2) Supabase 배치 전송 (제외 목록 필터링)
        let bucket = queue.sync { photoLibraryBucket }
        let payloads = events
            .filter { !Self.supabaseExcluded.contains($0.name) }
            .map { SupabaseProvider.EventPayload(
                eventName: $0.name,
                params: $0.parameters,
                photoBucket: bucket
            )}

        // supabaseProvider가 nil(xcconfig 미설정)이면 즉시 완료 콜백
        if let provider = supabaseProvider, !payloads.isEmpty {
            provider.sendBatch(events: payloads) { [weak self] in
                self?.onFlushComplete?()
                self?.onFlushComplete = nil
            }
        } else {
            // provider nil 또는 Supabase 대상 이벤트 없음 → 즉시 완료
            onFlushComplete?()
            onFlushComplete = nil
        }
    }
}
