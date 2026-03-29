//
//  ReferralService.swift
//  AppCore
//
//  초대 리워드 프로그램 API 클라이언트 — 기반 구조
//  Supabase Edge Functions(referral-api)와 통신하는 서비스 레이어
//
//  - URLSession async/await 기반
//  - HTTP 상태별 에러 분기 (200/429/500/timeout, FR-042)
//  - 엔드포인트 메서드는 각 User Story Phase에서 추가
//
//  참조: specs/004-referral-reward/contracts/protocols.md §ReferralServiceProtocol
//  참조: specs/004-referral-reward/contracts/api-endpoints.md
//

import Foundation
import OSLog

// MARK: - ReferralServiceError

/// API 호출 시 발생할 수 있는 에러 (FR-042, FR-043)
public enum ReferralServiceError: Error, Sendable {
    /// 서버 응답의 error 필드
    case serverError(String)
    /// Rate limit 초과 (HTTP 429) — retryAfter: 재시도까지 대기 시간(초)
    case rateLimited(retryAfter: Int)
    /// 서버 에러 (HTTP 500+)
    case serverUnavailable
    /// 네트워크 타임아웃
    case timeout
    /// 네트워크 연결 불가
    case noConnection
    /// 응답 디코딩 실패
    case decodingFailed
    /// 알 수 없는 HTTP 상태
    case unexpectedStatus(Int)
}

// MARK: - ReferralServiceError + LocalizedError

extension ReferralServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .rateLimited(let retryAfter):
            return "요청이 너무 많습니다. \(retryAfter)초 후 다시 시도해주세요."
        case .serverUnavailable:
            return "서버에 일시적인 문제가 있습니다. 잠시 후 다시 시도해주세요."
        case .timeout:
            return "네트워크 응답 시간이 초과되었습니다."
        case .noConnection:
            return "네트워크 연결을 확인해주세요."
        case .decodingFailed:
            return "서버 응답을 처리할 수 없습니다."
        case .unexpectedStatus(let code):
            return "예상치 못한 서버 응답입니다. (코드: \(code))"
        }
    }
}

// MARK: - ReferralService

/// Supabase Edge Functions(referral-api) 통신 서비스
/// 기반 구조: URL 설정, 공통 HTTP 요청 로직, 에러 처리
/// 각 엔드포인트 메서드는 Phase 3~8에서 추가됨
public final class ReferralService {

    // MARK: - Singleton

    public static let shared = ReferralService()

    // MARK: - Constants

    /// 요청 타임아웃 (초)
    private static let requestTimeout: TimeInterval = 15

    // MARK: - Properties

    /// Supabase 프로젝트 URL (예: "https://xxx.supabase.co")
    private var baseURL: String?

    /// Supabase anon key (Edge Functions 호출 시 Authorization 헤더)
    private var anonKey: String?

    /// URLSession (타임아웃 설정 포함)
    private let session: URLSession

    /// 초기화 완료 여부
    private var isConfigured = false

    // MARK: - Initialization

    private init() {
        // 타임아웃 설정
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.requestTimeout
        config.timeoutIntervalForResource = Self.requestTimeout * 2
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    /// Supabase URL과 anon key 설정
    /// SceneDelegate에서 앱 시작 시 호출
    /// - Parameters:
    ///   - url: Supabase 프로젝트 URL
    ///   - anonKey: Supabase anon key
    public func configure(url: String, anonKey: String) {
        self.baseURL = url
        self.anonKey = anonKey
        self.isConfigured = true
        Logger.referral.debug("ReferralService: 설정 완료 — URL: \(url.prefix(30))...")
    }

    // MARK: - Internal: HTTP Request

    /// Edge Function 엔드포인트에 POST 요청을 보내고 응답을 디코딩
    /// - Parameters:
    ///   - endpoint: 엔드포인트 경로 (예: "create-link")
    ///   - body: 요청 바디 딕셔너리 (JSON 직렬화됨)
    /// - Returns: 디코딩된 응답 데이터
    /// - Throws: ReferralServiceError
    func post<T: Decodable>(
        endpoint: String,
        body: [String: Any]
    ) async throws -> T {
        // 설정 확인
        guard let baseURL = baseURL, let anonKey = anonKey else {
            Logger.referral.error("ReferralService: 미설정 상태에서 API 호출 시도")
            throw ReferralServiceError.serverError("서비스가 초기화되지 않았습니다.")
        }

        // URL 구성: {baseURL}/functions/v1/referral-api/{endpoint}
        guard let url = URL(string: "\(baseURL)/functions/v1/referral-api/\(endpoint)") else {
            throw ReferralServiceError.serverError("잘못된 URL입니다.")
        }

        // 요청 생성
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        Logger.referral.debug("ReferralService: POST /\(endpoint)")

        // 네트워크 요청 실행
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            // URLError 분기: 타임아웃 vs 연결 불가
            switch error.code {
            case .timedOut:
                Logger.referral.error("ReferralService: 타임아웃 — /\(endpoint)")
                throw ReferralServiceError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                Logger.referral.error("ReferralService: 오프라인 — /\(endpoint)")
                throw ReferralServiceError.noConnection
            default:
                Logger.referral.error("ReferralService: 네트워크 에러 — \(error.localizedDescription)")
                throw ReferralServiceError.noConnection
            }
        }

        // HTTP 상태 코드 분기 (FR-043)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReferralServiceError.serverError("잘못된 응답입니다.")
        }

        let statusCode = httpResponse.statusCode
        Logger.referral.debug("ReferralService: /\(endpoint) → \(statusCode)")

        switch statusCode {
        case 200:
            // 성공: 응답 디코딩
            break

        case 429:
            // Rate limit 초과
            let retryAfter = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            Logger.referral.error("ReferralService: Rate limit — /\(endpoint), retry after \(retryAfter)s")
            throw ReferralServiceError.rateLimited(retryAfter: retryAfter)

        case 500...599:
            // 서버 에러
            Logger.referral.error("ReferralService: 서버 에러 \(statusCode) — /\(endpoint)")
            throw ReferralServiceError.serverUnavailable

        default:
            // 기타 상태 코드 — 응답 바디에서 에러 메시지 추출 시도
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorResponse["error"] as? String {
                throw ReferralServiceError.serverError(errorMessage)
            }
            throw ReferralServiceError.unexpectedStatus(statusCode)
        }

        // 응답 디코딩
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Logger.referral.error("ReferralService: 디코딩 실패 — /\(endpoint): \(error)")
            throw ReferralServiceError.decodingFailed
        }
    }

    /// Edge Function 엔드포인트에 POST 요청 (응답 바디 무시)
    /// report-redemption 등 성공 여부만 확인하는 엔드포인트용
    /// - Parameters:
    ///   - endpoint: 엔드포인트 경로
    ///   - body: 요청 바디 딕셔너리
    /// - Throws: ReferralServiceError
    func postVoid(
        endpoint: String,
        body: [String: Any]
    ) async throws {
        // 설정 확인
        guard let baseURL = baseURL, let anonKey = anonKey else {
            Logger.referral.error("ReferralService: 미설정 상태에서 API 호출 시도")
            throw ReferralServiceError.serverError("서비스가 초기화되지 않았습니다.")
        }

        // URL 구성
        guard let url = URL(string: "\(baseURL)/functions/v1/referral-api/\(endpoint)") else {
            throw ReferralServiceError.serverError("잘못된 URL입니다.")
        }

        // 요청 생성
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        Logger.referral.debug("ReferralService: POST /\(endpoint) (void)")

        // 네트워크 요청 실행
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw ReferralServiceError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw ReferralServiceError.noConnection
            default:
                throw ReferralServiceError.noConnection
            }
        }

        // HTTP 상태 코드 분기
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReferralServiceError.serverError("잘못된 응답입니다.")
        }

        let statusCode = httpResponse.statusCode

        switch statusCode {
        case 200:
            Logger.referral.debug("ReferralService: /\(endpoint) → 성공")
            return

        case 429:
            let retryAfter = Int(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            throw ReferralServiceError.rateLimited(retryAfter: retryAfter)

        case 500...599:
            throw ReferralServiceError.serverUnavailable

        default:
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorResponse["error"] as? String {
                throw ReferralServiceError.serverError(errorMessage)
            }
            throw ReferralServiceError.unexpectedStatus(statusCode)
        }
    }
}
