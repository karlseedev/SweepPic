// GridColumnCount.swift
// 그리드 열 수 열거형
//
// Phase 1: BaseGridViewController 리팩토링 기반 작업
// - 세 가지 그리드에서 공통으로 사용하는 ColumnCount enum 추출
// - GridViewController, AlbumGridViewController, TrashAlbumViewController 공용

import Foundation

/// 그리드 열 수 (1/3/5)
/// 핀치 줌으로 전환 가능
enum GridColumnCount: Int, CaseIterable {
    case one = 1
    case three = 3
    case five = 5

    /// 다음 확대 열 수 (1 → 1, 3 → 1, 5 → 3)
    var zoomIn: GridColumnCount {
        switch self {
        case .one: return .one
        case .three: return .one
        case .five: return .three
        }
    }

    /// 다음 축소 열 수 (1 → 3, 3 → 5, 5 → 5)
    var zoomOut: GridColumnCount {
        switch self {
        case .one: return .three
        case .three: return .five
        case .five: return .five
        }
    }
}
