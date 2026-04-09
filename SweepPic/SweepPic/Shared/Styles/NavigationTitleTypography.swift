// NavigationTitleTypography.swift
// 네비게이션 타이틀/서브타이틀 공통 타이포그래피
//
// - 앱 로컬라이제이션 언어별 자간 분기
// - 메인 탭 타이틀, 상세 타이틀, 서브타이틀 공통 관리

import UIKit

enum NavigationTextStyle {
    case largeTitle
    case detailTitle
    case subtitle
}

private enum NavigationSubtitleScript {
    case cjk
    case latinNumeric
}

private enum NavigationLanguageBucket {
    case korean
    case japanese
    case chinese
    case english
    case other
}

struct NavigationTitleTypography {

    static func attributedText(_ text: String, style: NavigationTextStyle) -> NSAttributedString {
        switch style {
        case .subtitle:
            return subtitleAttributedText(text)
        case .largeTitle, .detailTitle:
            return NSAttributedString(string: text, attributes: attributes(for: style))
        }
    }

    static func attributes(for style: NavigationTextStyle) -> [NSAttributedString.Key: Any] {
        switch style {
        case .largeTitle:
            return [
                .font: UIFont.systemFont(ofSize: 36, weight: .light),
                .kern: largeTitleKern
            ]
        case .detailTitle:
            return [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold)
            ]
        case .subtitle:
            return [
                .font: UIFont.systemFont(ofSize: 14, weight: .black),
                .kern: subtitleKern
            ]
        }
    }

    private static var largeTitleKern: CGFloat {
        switch currentLanguageBucket {
        case .korean:
            return -1.0
        case .japanese, .chinese:
            return -0.8
        case .english, .other:
            return 0.0
        }
    }

    private static var subtitleKern: CGFloat {
        0.0
    }

    private static func subtitleAttributedText(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var currentBucket: NavigationSubtitleScript?
        var currentRun = ""

        for character in text {
            let bucket = subtitleScript(for: character, previous: currentBucket)

            if bucket != currentBucket, !currentRun.isEmpty, let currentBucket {
                result.append(NSAttributedString(
                    string: currentRun,
                    attributes: subtitleAttributes(for: currentBucket)
                ))
                currentRun.removeAll(keepingCapacity: true)
            }

            currentRun.append(character)
            currentBucket = bucket
        }

        if !currentRun.isEmpty, let currentBucket {
            result.append(NSAttributedString(
                string: currentRun,
                attributes: subtitleAttributes(for: currentBucket)
            ))
        }

        return result
    }

    private static func subtitleAttributes(for script: NavigationSubtitleScript) -> [NSAttributedString.Key: Any] {
        [
            .font: subtitleFont(for: script),
            .kern: subtitleKern
        ]
    }

    private static func subtitleFont(for script: NavigationSubtitleScript) -> UIFont {
        switch script {
        case .cjk:
            return UIFont.systemFont(ofSize: 14, weight: .black)
        case .latinNumeric:
            return UIFont.systemFont(ofSize: 14, weight: .heavy)
        }
    }

    private static func subtitleScript(
        for character: Character,
        previous: NavigationSubtitleScript?
    ) -> NavigationSubtitleScript {
        for scalar in character.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) || CharacterSet.letters.contains(scalar) {
                if isCJKScalar(scalar) {
                    return .cjk
                }
                return .latinNumeric
            }
        }

        return previous ?? defaultSubtitleScript
    }

    private static var defaultSubtitleScript: NavigationSubtitleScript {
        switch currentLanguageBucket {
        case .korean, .japanese, .chinese:
            return .cjk
        case .english, .other:
            return .latinNumeric
        }
    }

    private static func isCJKScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x1100...0x11FF,     // Hangul Jamo
             0x3130...0x318F,     // Hangul Compatibility Jamo
             0xAC00...0xD7AF,     // Hangul Syllables
             0x3040...0x309F,     // Hiragana
             0x30A0...0x30FF,     // Katakana
             0x4E00...0x9FFF,     // CJK Unified Ideographs
             0x3400...0x4DBF,     // CJK Extension A
             0xF900...0xFAFF:     // CJK Compatibility Ideographs
            return true
        default:
            return false
        }
    }

    private static var currentLanguageBucket: NavigationLanguageBucket {
        let languageCode = Bundle.main.preferredLocalizations.first?
            .split(separator: "-")
            .first?
            .lowercased() ?? "en"

        switch languageCode {
        case "ko":
            return .korean
        case "ja":
            return .japanese
        case "zh":
            return .chinese
        case "en":
            return .english
        default:
            return .other
        }
    }
}
