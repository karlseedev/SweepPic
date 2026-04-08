//
//  FaceScanMethod.swift
//  SweepPic
//
//  인물사진 비교정리 — 스캔 방식 정의
//  - fromLatest: 최신 사진부터 스캔
//  - continueFromLast: 이전 스캔 위치부터 계속
//  - byYear: 특정 연도의 사진만 스캔
//
//  CleanupMethod 패턴 참조
//

import Foundation

/// 인물사진 비교정리 스캔 방식
///
/// 사용자가 방식 선택 시트에서 선택하는 세 가지 스캔 방식.
/// Codable을 준수하여 세션 저장/로드 시 JSON으로 직렬화 가능.
enum FaceScanMethod: Codable, Equatable {

    /// 최신 사진부터 스캔
    /// - 시작점: 가장 최근 사진
    /// - 범위: 종료 조건(1,000장 검색 또는 30그룹 발견)까지
    case fromLatest

    /// 이어서 스캔
    /// - 시작점: 마지막 스캔 위치 (FaceScanSession.lastAssetDate + lastAssetID)
    /// - 범위: 종료 조건까지
    /// - 전제조건: 이전 완료된 스캔 세션이 있어야 활성화
    case continueFromLast

    /// 연도별 스캔
    /// - 시작점: 해당 연도 12월 31일 (또는 continueFrom 날짜)
    /// - 범위: 해당 연도만
    /// - associated value:
    ///   - year: 선택한 연도 (예: 2024)
    ///   - continueFrom: 이어서 스캔 시 시작점 (nil이면 연도 전체)
    case byYear(year: Int, continueFrom: Date? = nil)

    // MARK: - Codable

    /// JSON 인코딩/디코딩을 위한 키
    private enum CodingKeys: String, CodingKey {
        case method
        case year
        case continueFrom
    }

    /// JSON 인코딩 시 method 값
    private enum MethodValue: String, Codable {
        case fromLatest
        case continueFromLast
        case byYear
    }

    /// JSON 디코딩
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let method = try container.decode(MethodValue.self, forKey: .method)

        switch method {
        case .fromLatest:
            self = .fromLatest
        case .continueFromLast:
            self = .continueFromLast
        case .byYear:
            let year = try container.decode(Int.self, forKey: .year)
            let continueFrom = try container.decodeIfPresent(Date.self, forKey: .continueFrom)
            self = .byYear(year: year, continueFrom: continueFrom)
        }
    }

    /// JSON 인코딩
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .fromLatest:
            try container.encode(MethodValue.fromLatest, forKey: .method)
        case .continueFromLast:
            try container.encode(MethodValue.continueFromLast, forKey: .method)
        case .byYear(let year, let continueFrom):
            try container.encode(MethodValue.byYear, forKey: .method)
            try container.encode(year, forKey: .year)
            try container.encodeIfPresent(continueFrom, forKey: .continueFrom)
        }
    }
}

// MARK: - CustomStringConvertible

extension FaceScanMethod: CustomStringConvertible {

    /// 디버그/로깅용 문자열 표현
    var description: String {
        switch self {
        case .fromLatest:
            return "최신사진부터 스캔"
        case .continueFromLast:
            return "이어서 스캔"
        case .byYear(let year, _):
            return "\(year)년 사진 스캔"
        }
    }
}

// MARK: - UI 지원

extension FaceScanMethod {

    /// UI에 표시할 제목
    var displayTitle: String {
        switch self {
        case .fromLatest:
            return String(localized: "faceScan.sheet.fromLatest")
        case .continueFromLast:
            return String(localized: "faceScan.sheet.continue")
        case .byYear(let year, _):
            return String(localized: "faceScan.method.yearTitle \(String(year))")
        }
    }

    /// 연도별 스캔인 경우 연도 반환, 아니면 nil
    var year: Int? {
        if case .byYear(let year, _) = self {
            return year
        }
        return nil
    }
}
