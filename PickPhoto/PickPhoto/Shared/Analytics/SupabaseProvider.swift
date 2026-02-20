// SupabaseProvider.swift
// Supabase PostgREST에 이벤트를 전송하는 경량 HTTP 클라이언트
//
// - 외부 의존성 0 (supabase-swift SDK 미사용, URLSession만 사용)
// - 오프라인 큐 없음 (TD가 주 데이터, 유실 허용)
// - 배치 전송 지원 (flushCounters → sendEventBatch에서 사용)
// - 참조: docs/db/260217db-hybrid.md Phase 2

import UIKit
import AppCore

/// Supabase PostgREST에 이벤트를 전송하는 경량 HTTP 클라이언트
/// - URLSession 기반 (외부 의존성 0)
/// - 오프라인 큐 없음 (TD가 주 데이터, 유실 허용)
/// - 재시도 없음
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

    // MARK: - Init

    /// Info.plist에서 읽은 URL/Key로 초기화
    /// - Parameters:
    ///   - baseURL: Supabase 프로젝트 URL (예: "https://xxx.supabase.co")
    ///   - anonKey: Supabase anon key (JWT 기반 클라이언트용)
    /// - Returns: URL이 잘못되면 nil 반환
    init?(baseURL: String, anonKey: String) {
        guard let url = URL(string: baseURL + "/rest/v1/events") else { return nil }
        self.endpointURL = url
        self.anonKey = anonKey
        self.deviceModel = Self.resolveDeviceModel()
        self.osVersion = UIDevice.current.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
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
            #if DEBUG
 Error: JSON 직렬화 실패 (send \(eventName))")
            #endif
            return
        }

        var request = makeRequest()
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { _, response, error in
            #if DEBUG
            Self.logResponse(eventName: eventName, count: 1, response: response, error: error)
            #endif
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
            #if DEBUG
 Error: JSON 직렬화 실패 (batch \(events.count)건)")
            #endif
            completion?()
            return
        }

        var request = makeRequest()
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { _, response, error in
            #if DEBUG
            Self.logResponse(eventName: "batch", count: events.count, response: response, error: error)
            #endif
            completion?()
        }.resume()
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
        // 응답에 삽입된 행 미반환 (트래픽 절감)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        return request
    }

    /// 이벤트 1건의 JSON body 딕셔너리 생성
    /// - 6개 키: event_name, params, device_model, os_version, app_version, photo_bucket
    /// - id(IDENTITY)와 created_at(DEFAULT now())은 전송하지 않음
    private func makeBody(eventName: String, params: [String: String], photoBucket: String) -> [String: Any] {
        return [
            "event_name": eventName,
            "params": params,
            "device_model": deviceModel,
            "os_version": osVersion,
            "app_version": appVersion,
            "photo_bucket": photoBucket,
        ]
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

    /// 디버그 응답 로깅
    #if DEBUG
    private static func logResponse(eventName: String, count: Int, response: URLResponse?, error: Error?) {
        if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
     OK \(eventName) \(count) events (HTTP \(httpResponse.statusCode))")
            } else {
     Error \(eventName): HTTP \(httpResponse.statusCode)")
            }
        } else if let error = error {
 Error \(eventName): \(error.localizedDescription)")
        }
    }
    #endif
}
