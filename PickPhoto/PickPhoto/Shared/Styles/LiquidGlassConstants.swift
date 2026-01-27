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

        /// 아이콘 SF Symbol point size (28 → 22로 축소)
        static let iconPointSize: CGFloat = 22

        /// 아이콘 상단 오프셋 (버튼 상단 기준)
        static let iconTopOffset: CGFloat = 8

        /// 레이블 상단 오프셋 (버튼 상단 기준)
        static let labelTopOffset: CGFloat = 35

        /// 레이블 높이
        static let labelHeight: CGFloat = 12

        /// 레이블 폰트 크기
        static let labelFontSize: CGFloat = 10
    }

    // MARK: - Blur / Animation
    // ⚠️ LiquidGlassKit 적용으로 삭제됨
    // - Blur: LiquidGlassEffectView가 내부적으로 처리
    // - Animation: LiquidLensView.setLifted()가 Spring 애니메이션 자동 적용

    // MARK: - zPosition (레이어 순서)

    enum ZPosition {
        /// Platter 배경 (최하단)
        static let platterBackground: CGFloat = -2

        /// Selection Pill (버튼 뒤, 배경 역할)
        /// 참고: iOS 26 실측값은 zPos=10이나, 뷰 계층 구조가 다르므로 버튼(1)보다 낮게 설정
        static let selectionPill: CGFloat = 0

        /// 탭 버튼 (Selection Pill 위)
        static let tabButton: CGFloat = 1

        /// 일반 컨텐츠
        static let content: CGFloat = 2
    }
}
