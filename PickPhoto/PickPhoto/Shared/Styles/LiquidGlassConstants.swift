// LiquidGlassConstants.swift
// iOS 26 Liquid Glass 스타일 실측 상수
//
// iOS 26 TabBar 실측값 기반으로 iOS 16~25에서 동일한 외관 구현
// - Platter: 62pt 높이, max(274pt, 화면×68.2%) 너비
// - SelectionPill: 94×54pt, Spring 애니메이션
// - TabButton: 94×54pt, -8pt 겹침 배치

import UIKit

/// iOS 26 Liquid Glass 실측 상수
/// TabBar, NavBar, Button 등 공용으로 사용
enum LiquidGlassConstants {

    // MARK: - Platter (배경 컨테이너)

    enum Platter {
        /// 높이 (고정값)
        static let height: CGFloat = 62

        /// 코너 반경 (높이의 절반)
        static let cornerRadius: CGFloat = 31

        /// 내부 패딩 (좌우, 상하)
        static let padding: CGFloat = 4

        /// 화면 너비 대비 비율 (iOS 26 실측: 68.2%)
        static let ratioToScreen: CGFloat = 0.682

        /// 컨텐츠 기반 최소 너비 계산
        /// = padding×2 + button×3 + spacing×2
        /// = 4×2 + 94×3 - 8×2 = 274pt
        static var contentWidth: CGFloat {
            padding * 2 + TabButton.width * 3 + TabButton.spacing * 2
        }

        /// 실제 적용 너비: max(컨텐츠, 화면×68.2%)
        /// - Parameter screenWidth: 화면 너비
        /// - Returns: 계산된 Platter 너비
        static func calculatedWidth(screenWidth: CGFloat) -> CGFloat {
            max(contentWidth, screenWidth * ratioToScreen)
        }
    }

    // MARK: - SelectionPill (선택 표시)

    enum SelectionPill {
        /// 너비 (TabButton과 동일)
        static let width: CGFloat = 94

        /// 높이 (Platter 높이 - 패딩×2)
        static let height: CGFloat = 54

        /// 코너 반경 (높이의 절반)
        static let cornerRadius: CGFloat = 27
    }

    // MARK: - TabButton (개별 탭 버튼)

    enum TabButton {
        /// 버튼 너비 (고정값)
        static let width: CGFloat = 94

        /// 버튼 높이 (SelectionPill과 동일)
        static let height: CGFloat = 54

        /// 버튼 간 겹침 (음수 = 겹침)
        static let spacing: CGFloat = -8

        /// 아이콘 SF Symbol point size
        static let iconPointSize: CGFloat = 28

        /// 아이콘 상단 오프셋 (버튼 상단 기준)
        static let iconTopOffset: CGFloat = 9

        /// 레이블 상단 오프셋 (버튼 상단 기준)
        static let labelTopOffset: CGFloat = 35

        /// 레이블 높이
        static let labelHeight: CGFloat = 12

        /// 레이블 폰트 크기
        static let labelFontSize: CGFloat = 10
    }

    // MARK: - Background (배경 색상)

    enum Background {
        /// Platter 배경 gray 값 (iOS 26 실측)
        static let gray: CGFloat = 0.11

        /// Platter 배경 alpha 값 (iOS 26 실측: 0.73)
        /// LiquidGlassStyle.backgroundAlpha(0.12)와 별도 관리
        static let alpha: CGFloat = 0.73
    }

    // MARK: - Blur (블러 설정)

    enum Blur {
        /// Platter 블러 스타일 (투명한 블러 + overlay 조합)
        static let platterStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark

        /// Platter overlay alpha (iOS 26 실측: gray 0.11 위에 0.73)
        static let platterOverlayAlpha: CGFloat = 0.73

        /// Selection Pill 블러 스타일 (더 선명한 블러)
        static let pillStyle: UIBlurEffect.Style = .systemThinMaterialDark
    }

    // MARK: - Animation (애니메이션)

    enum Animation {
        /// 애니메이션 지속 시간
        static let duration: TimeInterval = 0.35

        /// Spring 애니메이션 damping ratio
        static let dampingRatio: CGFloat = 0.8

        /// Spring 애니메이션 초기 속도
        static let initialVelocity: CGFloat = 0
    }

    // MARK: - zPosition (레이어 순서)

    enum ZPosition {
        /// Platter 배경 (최하단)
        static let platterBackground: CGFloat = -2

        /// 일반 컨텐츠
        static let content: CGFloat = 0

        /// 탭 버튼
        static let tabButton: CGFloat = 1

        /// Selection Pill (최상단)
        static let selectionPill: CGFloat = 10
    }
}
