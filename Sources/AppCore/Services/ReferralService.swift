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

// MARK: - API Response Wrapper

/// Supabase Edge Function 공통 응답 래퍼
/// 형식: { "success": true, "data": {...} } 또는 { "success": false, "error": "..." }
private struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
}

/// 응답 바디가 없는 엔드포인트용 래퍼 (report-redemption 등)
private struct APIResponseBase: Decodable {
    let success: Bool
    let error: String?
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

        // Info.plist에서 Supabase 설정 자동 로드
        // xcconfig → Info.plist → Bundle.main으로 전달되는 값을 읽음
        if let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
           !url.isEmpty, !key.isEmpty {
            self.baseURL = url
            self.anonKey = key
            self.isConfigured = true
            Logger.referral.debug("ReferralService: 자동 설정 완료 — URL: \(url.prefix(30))...")
        }
    }

    // MARK: - Configuration

    /// Supabase URL과 anon key 수동 설정 (자동 로드 실패 시 폴백)
    /// - Parameters:
    ///   - url: Supabase 프로젝트 URL
    ///   - anonKey: Supabase anon key
    public func configure(url: String, anonKey: String) {
        self.baseURL = url
        self.anonKey = anonKey
        self.isConfigured = true
        Logger.referral.debug("ReferralService: 수동 설정 완료 — URL: \(url.prefix(30))...")
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

        // 응답 디코딩 — API 래퍼 { "success": bool, "data": T?, "error": string? }
        let decoder = JSONDecoder()
        do {
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)

            // success: false → 비즈니스 에러 (API 레벨)
            if !apiResponse.success {
                let message = apiResponse.error ?? "알 수 없는 에러입니다."
                Logger.referral.error("ReferralService: 비즈니스 에러 — /\(endpoint): \(message)")
                throw ReferralServiceError.serverError(message)
            }

            // data 필드 추출
            guard let result = apiResponse.data else {
                Logger.referral.error("ReferralService: 응답에 data 필드 없음 — /\(endpoint)")
                throw ReferralServiceError.decodingFailed
            }
            return result
        } catch let error as ReferralServiceError {
            throw error
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
            // API 래퍼 확인: success: false → 비즈니스 에러
            if let apiResponse = try? JSONDecoder().decode(APIResponseBase.self, from: data),
               !apiResponse.success {
                let message = apiResponse.error ?? "알 수 없는 에러입니다."
                Logger.referral.error("ReferralService: 비즈니스 에러 — /\(endpoint): \(message)")
                throw ReferralServiceError.serverError(message)
            }
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

    // MARK: - Public API: User Story 1 (초대 링크 생성)

    /// 초대 코드를 생성하거나 기존 코드를 조회한다 (create-link)
    /// 초대자의 user_id로 고유 초대 코드를 생성하고, 공유 URL을 반환한다.
    /// 이미 코드가 있으면 기존 코드를 반환.
    ///
    /// - Parameter userId: Keychain 기반 영구 사용자 ID
    /// - Returns: ReferralLink (초대 코드 + 공유 URL)
    /// - Throws: ReferralServiceError
    public func createOrGetLink(userId: String) async throws -> ReferralLink {
        return try await post(
            endpoint: "create-link",
            body: ["user_id": userId]
        )
    }

    // MARK: - Public API: User Story 2 (피초대자 혜택 적용)

    /// 피초대자가 초대 코드를 매칭하고 Offer Code를 할당받는다 (match-code)
    ///
    /// 서버에서 5가지 상태 중 하나를 반환:
    /// - matched: 코드 매칭 성공 + Offer Code 할당
    /// - already_redeemed: 이미 다른 초대 코드를 사용한 사용자
    /// - self_referral: 본인의 초대 코드 사용 시도
    /// - invalid_code: 유효하지 않은 초대 코드
    /// - no_codes_available: Offer Code 풀 소진
    ///
    /// - Parameters:
    ///   - userId: 피초대자 Keychain UUID
    ///   - referralCode: 초대 코드 (x0{6chars}9j 형식)
    ///   - subscriptionStatus: 피초대자 구독 상태 (none/monthly/yearly/expired_monthly/expired_yearly)
    /// - Returns: ReferralMatchResult (상태 + 리딤 URL)
    /// - Throws: ReferralServiceError
    public func matchCode(
        userId: String,
        referralCode: String,
        subscriptionStatus: String
    ) async throws -> ReferralMatchResult {
        return try await post(
            endpoint: "match-code",
            body: [
                "user_id": userId,
                "referral_code": referralCode,
                "subscription_status": subscriptionStatus
            ]
        )
    }

    /// 피초대자의 초대 코드 적용 상태를 확인한다 (check-status)
    ///
    /// 3가지 분기:
    /// - none: 아직 초대 코드를 사용하지 않음 → 코드 입력 화면 표시
    /// - matched: 코드 매칭됨, 리딤 미완료 → "혜택이 아직 적용되지 않았어요" + [혜택 받기]
    /// - redeemed: 이미 적용됨 → "이미 초대 코드가 적용되어 있습니다"
    ///
    /// - Parameter userId: 피초대자 Keychain UUID
    /// - Returns: ReferralMatchResult (상태 + 리딤 URL)
    /// - Throws: ReferralServiceError
    public func checkStatus(userId: String) async throws -> ReferralMatchResult {
        return try await post(
            endpoint: "check-status",
            body: ["user_id": userId]
        )
    }

    /// 피초대자가 Offer Code 리딤 완료를 서버에 보고한다 (report-redemption)
    ///
    /// 서버 동작:
    /// - referrals 상태 → redeemed
    /// - offer_codes 상태 → used
    /// - pending_rewards INSERT (초대자 보상 대기)
    ///
    /// - Parameters:
    ///   - userId: 피초대자 Keychain UUID
    ///   - referralId: referrals 테이블 ID (match-code 응답에서 받은 값)
    /// - Throws: ReferralServiceError
    /// 보상 수령을 확정한다 (confirm-claim)
    ///
    /// claim-reward에서 claimed 상태로 변경된 보상을 completed로 확정.
    /// 클라이언트에서 StoreKit Transaction 감지 후 호출.
    ///
    /// - Parameters:
    ///   - userId: 초대자 Keychain UUID
    ///   - rewardId: pending_rewards 테이블 ID
    ///   - transactionId: StoreKit Transaction ID (고객 문의 대응용, 선택)
    /// - Throws: ReferralServiceError
    public func confirmClaim(
        userId: String,
        rewardId: String,
        transactionId: UInt64? = nil
    ) async throws {
        var body: [String: Any] = [
            "user_id": userId,
            "reward_id": rewardId
        ]
        if let txId = transactionId {
            body["transaction_id"] = String(txId)
        }
        try await postVoid(endpoint: "confirm-claim", body: body)
    }

    public func reportRedemption(userId: String, referralId: String) async throws {
        try await postVoid(
            endpoint: "report-redemption",
            body: [
                "user_id": userId,
                "referral_id": referralId
            ]
        )
    }

    // MARK: - Public API: User Story 3 (초대자 보상 수령)

    /// 초대자의 대기 중인 보상 목록을 조회한다 (get-pending-rewards)
    ///
    /// 만료 보상은 서버에서 자동으로 expired 처리되어 결과에 포함되지 않는다.
    ///
    /// - Parameter userId: 초대자 Keychain UUID
    /// - Returns: PendingRewardsListResponse (rewards 배열)
    /// - Throws: ReferralServiceError
    public func getPendingRewards(userId: String) async throws -> PendingRewardsListResponse {
        return try await post(
            endpoint: "get-pending-rewards",
            body: ["user_id": userId]
        )
    }

    /// 초대자가 보상을 수령한다 (claim-reward)
    ///
    /// 서버에서 subscription_status를 기반으로 보상 방식을 결정:
    /// - monthly/expired_monthly → Promotional Offer (referral_extend_monthly)
    /// - yearly/expired_yearly → Promotional Offer (referral_extend_yearly)
    /// - none → Offer Code (referral_reward_01)
    ///
    /// - Parameters:
    ///   - userId: 초대자 Keychain UUID
    ///   - rewardId: pending_rewards 테이블 ID
    ///   - subscriptionStatus: 구독 상태 (none/monthly/yearly/expired_monthly/expired_yearly)
    ///   - productId: StoreKit 상품 ID (pro_monthly/pro_yearly)
    /// - Returns: RewardClaimResponse (reward_type + signature 또는 redeem_url)
    /// - Throws: ReferralServiceError
    public func claimReward(
        userId: String,
        rewardId: String,
        subscriptionStatus: String,
        productId: String
    ) async throws -> RewardClaimResponse {
        return try await post(
            endpoint: "claim-reward",
            body: [
                "user_id": userId,
                "reward_id": rewardId,
                "subscription_status": subscriptionStatus,
                "product_id": productId
            ]
        )
    }
}
