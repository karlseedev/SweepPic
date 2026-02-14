// AnalyticsService+DeleteRestore.swift
// 이벤트 4-1(보관함/앨범 삭제·복구) + 이벤트 4-2(휴지통) 세션 누적 카운터
//
// - DeleteSource(library/album): 진입 경로 동시 추적
// - 참조: docs/db/260212db-Archi.md 섹션 4.5, 5.4

import Foundation
import AppCore

extension AnalyticsService {

    // MARK: - 이벤트 4-1: 보관함/앨범 삭제·복구

    /// 그리드 스와이프 삭제 카운터 증가
    /// - Parameter source: 진입 경로 (library/album)
    func countGridSwipeDelete(source: DeleteSource) {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.deleteRestore.gridSwipeDelete += 1
            switch source {
            case .library: self.counters.deleteRestore.fromLibrary += 1
            case .album:   self.counters.deleteRestore.fromAlbum += 1
            }
            Log.print("[Analytics] gridSwipeDelete +1 (total=\(self.counters.deleteRestore.gridSwipeDelete))")
        }
    }

    /// 그리드 스와이프 복구 카운터 증가
    /// - Parameter source: 진입 경로 (library/album)
    func countGridSwipeRestore(source: DeleteSource) {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.deleteRestore.gridSwipeRestore += 1
            switch source {
            case .library: self.counters.deleteRestore.fromLibrary += 1
            case .album:   self.counters.deleteRestore.fromAlbum += 1
            }
            Log.print("[Analytics] gridSwipeRestore +1 (total=\(self.counters.deleteRestore.gridSwipeRestore))")
        }
    }

    /// 뷰어 스와이프 삭제 카운터 증가
    /// - Parameter source: 진입 경로 (library/album). nil이면 source 추적 생략
    func countViewerSwipeDelete(source: DeleteSource?) {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.deleteRestore.viewerSwipeDelete += 1
            if let source = source {
                switch source {
                case .library: self.counters.deleteRestore.fromLibrary += 1
                case .album:   self.counters.deleteRestore.fromAlbum += 1
                }
            }
            Log.print("[Analytics] viewerSwipeDelete +1 (total=\(self.counters.deleteRestore.viewerSwipeDelete))")
        }
    }

    /// 뷰어 휴지통 버튼 카운터 증가
    /// - Parameter source: 진입 경로 (library/album). nil이면 source 추적 생략
    func countViewerTrashButton(source: DeleteSource?) {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.deleteRestore.viewerTrashButton += 1
            if let source = source {
                switch source {
                case .library: self.counters.deleteRestore.fromLibrary += 1
                case .album:   self.counters.deleteRestore.fromAlbum += 1
                }
            }
            Log.print("[Analytics] viewerTrashButton +1 (total=\(self.counters.deleteRestore.viewerTrashButton))")
        }
    }

    /// 뷰어 복구 버튼 카운터 증가
    /// - Parameter source: 진입 경로 (library/album). nil이면 source 추적 생략
    func countViewerRestoreButton(source: DeleteSource?) {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.deleteRestore.viewerRestoreButton += 1
            if let source = source {
                switch source {
                case .library: self.counters.deleteRestore.fromLibrary += 1
                case .album:   self.counters.deleteRestore.fromAlbum += 1
                }
            }
            Log.print("[Analytics] viewerRestoreButton +1 (total=\(self.counters.deleteRestore.viewerRestoreButton))")
        }
    }

    // MARK: - 이벤트 4-2: 휴지통 뷰어

    /// 휴지통 완전삭제 카운터 증가
    func countTrashPermanentDelete() {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.trashViewer.permanentDelete += 1
            Log.print("[Analytics] trashPermanentDelete +1 (total=\(self.counters.trashViewer.permanentDelete))")
        }
    }

    /// 휴지통 복구 카운터 증가
    func countTrashRestore() {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.trashViewer.restore += 1
            Log.print("[Analytics] trashRestore +1 (total=\(self.counters.trashViewer.restore))")
        }
    }
}
