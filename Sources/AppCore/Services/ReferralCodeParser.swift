//
//  ReferralCodeParser.swift
//  AppCore
//
//  초대 코드 정규식 추출 유틸리티
//  텍스트(메시지 전체, 일부, 코드만)에서 초대 코드를 추출한다.
//
//  코드 형식: x0{영숫자 6자리}9j (예: x0k7m2x99j)
//  정규식: x0([a-zA-Z0-9]{6})9j
//
//  참조: specs/004-referral-reward/contracts/protocols.md §ReferralCodeParserProtocol
//  참조: specs/004-referral-reward/spec.md FR-006
//

import Foundation
import OSLog

// MARK: - ReferralCodeParser

/// 초대 코드 추출 유틸리티
/// 텍스트에서 x0{6자리}9j 형식의 초대 코드를 찾아 반환한다.
public enum ReferralCodeParser {

    // MARK: - Constants

    /// 초대 코드 정규식 패턴 — x0 + 영숫자 6자리 + 9j
    private static let pattern = "x0[a-zA-Z0-9]{6}9j"

    /// 컴파일된 정규식 (재사용)
    private static let regex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: pattern, options: [])
    }()

    // MARK: - Public API

    /// 텍스트에서 초대 코드를 추출한다.
    ///
    /// 메시지 전체, URL, 코드만 입력 등 다양한 형태를 지원한다.
    /// 다수 매칭 시 첫 번째 코드를 사용한다 (FR-006).
    ///
    /// - Parameter text: 초대 코드가 포함된 텍스트
    /// - Returns: 추출된 초대 코드, 없으면 nil
    ///
    /// 사용 예시:
    /// ```swift
    /// // 코드만
    /// ReferralCodeParser.extractCode(from: "x0k7m2x99j") // → "x0k7m2x99j"
    ///
    /// // 메시지에서 추출
    /// ReferralCodeParser.extractCode(from: "초대코드: x0k7m2x99j 를 입력해주세요") // → "x0k7m2x99j"
    ///
    /// // URL에서 추출
    /// ReferralCodeParser.extractCode(from: "https://sweeppic.link/r/x0k7m2x99j") // → "x0k7m2x99j"
    ///
    /// // 매칭 실패
    /// ReferralCodeParser.extractCode(from: "안녕하세요") // → nil
    /// ```
    public static func extractCode(from text: String) -> String? {
        guard let regex = regex else {
            Logger.referral.error("ReferralCodeParser: 정규식 컴파일 실패")
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        // 매칭 없음
        guard let firstMatch = matches.first else {
            return nil
        }

        // 첫 번째 매칭 결과 추출
        guard let matchRange = Range(firstMatch.range, in: text) else {
            return nil
        }

        let code = String(text[matchRange])

        // 다수 매칭 시 로그 (FR-006: 첫 번째 코드 사용)
        if matches.count > 1 {
            Logger.referral.debug(
                "ReferralCodeParser: 다수 매칭 \(matches.count)개 — 첫 번째 코드 사용: \(code)"
            )
        }

        return code
    }

    /// 텍스트에 초대 코드가 포함되어 있는지 확인한다.
    ///
    /// - Parameter text: 검사할 텍스트
    /// - Returns: 초대 코드 포함 여부
    public static func containsCode(in text: String) -> Bool {
        return extractCode(from: text) != nil
    }
}
