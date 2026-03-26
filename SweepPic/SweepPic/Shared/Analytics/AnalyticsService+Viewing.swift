// AnalyticsService+Viewing.swift
// 이벤트 3(사진 열람) 세션 누적 카운터
//
// - 참조: docs/db/260212db-Archi.md 섹션 5.4, 4.2

import Foundation
import AppCore
import OSLog

extension AnalyticsService {

    // MARK: - 이벤트 3: 사진 열람

    /// 사진 열람 카운터 증가
    /// - Parameter source: 진입 화면 (library/album/trash)
    /// - 호출 지점: ViewerViewController.viewDidAppear (최초), didFinishAnimating (페이지 전환)
    func countPhotoViewed(from source: ScreenSource) {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.photoViewing.total += 1
            switch source {
            case .library: self.counters.photoViewing.fromLibrary += 1
            case .album:   self.counters.photoViewing.fromAlbum += 1
            case .trash:   self.counters.photoViewing.fromTrash += 1
            }
            Logger.analytics.debug("photoViewed +1 (total=\(self.counters.photoViewing.total), source=\(String(describing: source)))")
        }
    }
}
