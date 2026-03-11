// SupabaseProvider.swift
// Supabase PostgREST에 이벤트를 전송하는 경량 HTTP 클라이언트
//
// - 외부 의존성 0 (supabase-swift SDK 미사용, URLSession만 사용)
// - 오프라인 큐: Application Support/analytics/supabase_pending.json (최대 200건)
// - 선별적 재시도: 네트워크 에러/429/5xx만 큐 저장, 4xx는 드롭
// - 배치 전송 지원 (flushCounters → sendEventBatch에서 사용)
// - 참조: docs/db/260303supabase-impl.md

import UIKit
import AppCore
import OSLog

/// Supabase PostgREST에 이벤트를 전송하는 경량 HTTP 클라이언트
/// - URLSession 기반 (외부 의존성 0)
/// - 오프라인 큐: 전송 실패 시 파일에 저장, 포그라운드 진입 시 재전송
/// - 선별적 재시도: 네트워크 에러/429/5xx만 큐 저장 (4xx 클라이언트 오류는 드롭)
final class SupabaseProvider {

    // MARK: - EventPayload

    /// 전송 단위 — 이벤트 1건의 데이터
    struct EventPayload {
        let eventName: String
        let params: [String: String]
        let photoBucket: String
    }

    // MARK: - Properties

    /// PostgREST 엔드포인트 URL ({baseURL}/rest/v1/events)
    private let endpointURL: URL

    /// Supabase anon key (API 게이트웨이 + RLS 평가용)
    private let anonKey: String

    /// 디바이스 모델 (예: "iPhone16,1") — 한번 캐싱
    private let deviceModel: String

    /// OS 버전 (예: "18.3")
    private let osVersion: String

    /// 앱 버전 (예: "1.0.0")
    private let appVersion: String

    /// IDFV (identifierForVendor) — 앱 시작 시 1회 캐싱
    /// - 유저 단위 퍼널 분석용 (게이트→구독 전환율, DAU 등)
    /// - nil 케이스: 기기 잠금 해제 전 백그라운드 실행 시 → "unknown"
    private let deviceID: String

    // MARK: - Offline Queue Properties

    /// 파일 I/O 직렬화용 시리얼 큐 (race condition 방지)
    private let fileQueue = DispatchQueue(label: "com.pickphoto.supabase.pending")

    /// 보류 이벤트 저장 파일 (Application Support/analytics/supabase_pending.json)
    /// - Caches가 아닌 Application Support 사용 (OS 디스크 부족 시 삭제 방지)
    /// - isExcludedFromBackup = true (iCloud 백업 제외)
    private let pendingFileURL: URL

    /// 보류 큐 최대 크기 (오래된 항목부터 버림)
    private let maxPendingCount = 200

    /// 구독 tier 제공 클로저 (lazy 평가 — makeBody 시점에 호출)
    /// - "free" 또는 "plus" 반환
    /// - nil이면 기본값 "free"
    private let subscriptionTierProvider: (() -> String)?

    // MARK: - Init

    /// Info.plist에서 읽은 URL/Key로 초기화
    /// - Parameters:
    ///   - baseURL: Supabase 프로젝트 URL (예: "https://xxx.supabase.co")
    ///   - anonKey: Supabase anon key (JWT 기반 클라이언트용)
    ///   - subscriptionTierProvider: 구독 tier 반환 클로저 (nil이면 "free")
    /// - Returns: URL이 잘못되면 nil 반환
    init?(baseURL: String, anonKey: String,
          subscriptionTierProvider: (() -> String)? = nil) {
        guard let url = URL(string: baseURL + "/rest/v1/events") else { return nil }
        self.endpointURL = url
        self.anonKey = anonKey
        self.subscriptionTierProvider = subscriptionTierProvider
        self.deviceModel = Self.resolveDeviceModel()
        self.osVersion = UIDevice.current.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

        // Application Support/analytics/ 디렉토리에 큐 파일 생성
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("analytics", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var fileURL = dir.appendingPathComponent("supabase_pending.json")
        // iCloud 백업에서 제외
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? fileURL.setResourceValues(values)
        self.pendingFileURL = fileURL
    }

    // MARK: - Public API

    /// 단건 즉시 전송 (trackAppLaunched, trackSimilarGroupClosed 등)
    /// - Parameters:
    ///   - eventName: 이벤트명 (예: "app.launched")
    ///   - params: 이벤트 파라미터
    ///   - photoBucket: 사진 규모 구간 (예: "1K-5K")
    func send(eventName: String, params: [String: String], photoBucket: String) {
        // 단건: JSON 객체 (배열 아님)
        let body: [String: Any] = makeBody(eventName: eventName, params: params, photoBucket: photoBucket)

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return
        }

        var request = makeRequest()
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                Logger.analytics.debug("Supabase send \(eventName) → HTTP \(http.statusCode)")
            } else {
                if let error = error {
                    Logger.analytics.error("Supabase send \(eventName) error: \(error.localizedDescription)")
                } else if let http = response as? HTTPURLResponse {
                    Logger.analytics.error("Supabase send \(eventName) → HTTP \(http.statusCode)")
                }
                // 재시도 가능한 실패만 큐에 저장 (4xx 클라이언트 오류는 드롭)
                if self?.shouldRetry(response: response, error: error) == true {
                    self?.enqueueForRetry([body])
                }
            }
        }.resume()
    }

    /// 배치 전송 (flushCounters → sendEventBatch에서 호출)
    /// - PostgREST bulk INSERT: POST /rest/v1/events + JSON 배열
    /// - Parameters:
    ///   - events: 전송할 이벤트 배열
    ///   - completion: URLSession 응답 후 호출 (beginBackgroundTask 종료용)
    func sendBatch(events: [EventPayload], completion: (() -> Void)? = nil) {
        guard !events.isEmpty else {
            completion?()
            return
        }

        // 배치: JSON 배열 — 모든 객체의 키 셋 동일
        let bodyArray: [[String: Any]] = events.map {
            makeBody(eventName: $0.eventName, params: $0.params, photoBucket: $0.photoBucket)
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: bodyArray) else {
            completion?()
            return
        }

        var request = makeRequest()
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                Logger.analytics.debug("Supabase batch \(events.count) events → HTTP \(http.statusCode)")
            } else {
                if let error = error {
                    Logger.analytics.error("Supabase batch error: \(error.localizedDescription)")
                } else if let http = response as? HTTPURLResponse {
                    Logger.analytics.error("Supabase batch \(events.count) events → HTTP \(http.statusCode)")
                }
                // 재시도 가능한 실패만 큐에 저장 (4xx 클라이언트 오류는 드롭)
                if self?.shouldRetry(response: response, error: error) == true {
                    self?.enqueueForRetry(bodyArray)
                }
            }
            completion?()  // background task 종료는 성공/실패 모두 보장
        }.resume()
    }

    // MARK: - Offline Queue

    /// HTTP 상태 코드 기반 재시도 판단
    /// - 네트워크 에러(error != nil), 429, 5xx → 재시도 대상
    /// - 4xx(400/401/403/404) → 영구 실패, 재시도 불가 (RLS/스키마 오류)
    private func shouldRetry(response: URLResponse?, error: Error?) -> Bool {
        if error != nil { return true }  // 네트워크 에러/타임아웃
        guard let http = response as? HTTPURLResponse else { return true }
        if (200...299).contains(http.statusCode) { return false }  // 성공
        if http.statusCode == 429 { return true }  // Rate limit
        if http.statusCode >= 500 { return true }  // 서버 오류
        return false  // 4xx → 클라이언트 오류, 재시도 무의미
    }

    /// 실패한 이벤트를 파일에 저장 (atomic write)
    /// - fileQueue 시리얼로 직렬화하여 race condition 방지
    /// - maxPendingCount 초과 시 오래된 항목부터 버림
    private func enqueueForRetry(_ bodies: [[String: Any]]) {
        fileQueue.async {
            var queue = self.loadPendingQueue()
            queue.append(contentsOf: bodies)
            if queue.count > self.maxPendingCount {
                queue = Array(queue.suffix(self.maxPendingCount))
            }
            self.savePendingQueue(queue)
            Logger.analytics.debug("Supabase 큐 저장: +\(bodies.count)건, 전체 \(queue.count)건")
        }
    }

    /// 파일에서 보류 큐 로드
    /// - fileQueue 내에서만 호출 (직렬화 보장)
    private func loadPendingQueue() -> [[String: Any]] {
        guard let data = try? Data(contentsOf: pendingFileURL),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array
    }

    /// 큐를 파일에 atomic 저장
    /// - fileQueue 내에서만 호출 (직렬화 보장)
    private func savePendingQueue(_ queue: [[String: Any]]) {
        if queue.isEmpty {
            try? FileManager.default.removeItem(at: pendingFileURL)
            return
        }
        guard let data = try? JSONSerialization.data(withJSONObject: queue) else { return }
        try? data.write(to: pendingFileURL, options: .atomic)
    }

    /// 보류 중인 이벤트 재전송 (포그라운드 진입 시 호출)
    /// - 원자적 dequeue: 로드한 스냅샷만 전송, 성공 시 해당 항목만 제거
    /// - flush 중 새로 enqueue된 이벤트는 보존됨
    func flushPendingQueue() {
        fileQueue.async {
            let snapshot = self.loadPendingQueue()
            guard !snapshot.isEmpty else { return }
            let snapshotCount = snapshot.count
            Logger.analytics.debug("Supabase 큐 flush 시작: \(snapshotCount)건")

            // HTTP 전송 (동기 대기 — fileQueue 시리얼이므로 안전)
            guard let jsonData = try? JSONSerialization.data(withJSONObject: snapshot) else { return }
            var request = self.makeRequest()
            request.httpBody = jsonData

            let semaphore = DispatchSemaphore(value: 0)
            var success = false

            URLSession.shared.dataTask(with: request) { _, response, error in
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    success = true
                }
                semaphore.signal()
            }.resume()

            semaphore.wait()

            if success {
                // 전송 성공 → 전송한 항목만 제거 (flush 중 새로 추가된 항목은 보존)
                var current = self.loadPendingQueue()
                if current.count >= snapshotCount {
                    current.removeFirst(snapshotCount)
                } else {
                    current.removeAll()
                }
                self.savePendingQueue(current)
                Logger.analytics.debug("Supabase 큐 flush 성공: \(snapshotCount)건 전송, 잔여 \(current.count)건")
            } else {
                Logger.analytics.debug("Supabase 큐 flush 실패: \(snapshotCount)건 유지")
            }
        }
    }

    // MARK: - Private Helpers

    /// 공통 URLRequest 생성 (헤더 포함)
    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // API 게이트웨이 통과용
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        // PostgREST RLS 평가용 (같은 키)
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        // 응답에 삽입된 행 미반환 + 누락된 NOT NULL DEFAULT 컬럼에 DB 기본값 적용
        // missing=default: 구버전 클라이언트가 is_test 미전송 시에도 DEFAULT true 적용
        request.setValue("return=minimal, missing=default", forHTTPHeaderField: "Prefer")
        return request
    }

    /// 이벤트 1건의 JSON body 딕셔너리 생성
    /// - 9개 키: event_name, params, device_model, os_version, app_version, photo_bucket,
    ///           subscription_tier, device_id, is_test
    /// - id(IDENTITY)와 created_at(DEFAULT now())은 전송하지 않음
    /// - is_test: 컴파일 타임 #if DEBUG로 결정 (Swift Bool → JSON true/false → Postgres BOOLEAN)
    private func makeBody(eventName: String, params: [String: String], photoBucket: String) -> [String: Any] {
        var body: [String: Any] = [
            "event_name": eventName,
            "params": params,
            "device_model": deviceModel,
            "os_version": osVersion,
            "app_version": appVersion,
            "photo_bucket": photoBucket,
            "subscription_tier": subscriptionTierProvider?() ?? "free",
            "device_id": deviceID,
        ]
        #if DEBUG
        body["is_test"] = true
        #else
        body["is_test"] = false
        #endif
        return body
    }

    /// 디바이스 모델 식별자 조회 (예: "iPhone16,1")
    /// - sysctlbyname으로 하드웨어 모델 가져옴
    /// - 시뮬레이터에서는 "x86_64" 또는 "arm64" 반환
    private static func resolveDeviceModel() -> String {
        var size: Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

}
