//
//  GridViewController+SimilarPhoto.swift
//  SweepPic
//
//  Created by Claude on 2026/01/05.
//
//  유사 사진 기능 관련 GridViewController Extension
//  - 스크롤 멈춤 시 분석 트리거 (0.3초 디바운싱)
//  - 분석 완료 시 SimilarGroupBadgeView(Glass+Gradient 뱃지) 표시
//  - 스크롤 재개 시 분석 취소 및 뱃지 제거
//  - 셀 뱃지 관리 (T021)
//  - 그룹 무효화 처리 (T022)
//

import UIKit
import AppCore
import OSLog
import Photos

// MARK: - Similar Photo Properties

/// 유사 사진 기능에 필요한 stored properties를 위한 Associated Keys
private enum SimilarPhotoAssociatedKeys {
    /// 분석 디바운스 타이머
    static var debounceWorkItem: UInt8 = 0
    /// 현재 분석 중인 범위
    static var currentAnalysisRange: UInt8 = 0
    /// 분석 완료 옵저버
    static var analysisObserver: UInt8 = 0
    /// 뱃지 뷰 재사용 풀
    static var badgeViewPool: UInt8 = 0
    /// 삭제 옵저버 (그룹 무효화 처리용)
    static var trashObserver: UInt8 = 0
}

// MARK: - GridViewController+SimilarPhoto

extension GridViewController {

    // MARK: - Constants

    /// 유사 사진 관련 상수
    private enum SimilarPhotoConstants {
        /// 스크롤 멈춤 후 분석 시작 전 디바운싱 시간 (초)
        /// 0.15초: 빠른 스크롤 중 미세 멈춤에 트리거되지 않으면서 체감 반응 개선
        static let debounceInterval: TimeInterval = 0.15
    }

    // MARK: - Associated Properties

    /// 디바운스 작업 항목
    private var debounceWorkItem: DispatchWorkItem? {
        get { objc_getAssociatedObject(self, &SimilarPhotoAssociatedKeys.debounceWorkItem) as? DispatchWorkItem }
        set { objc_setAssociatedObject(self, &SimilarPhotoAssociatedKeys.debounceWorkItem, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 현재 분석 중인 범위
    private var currentAnalysisRange: ClosedRange<Int>? {
        get { objc_getAssociatedObject(self, &SimilarPhotoAssociatedKeys.currentAnalysisRange) as? ClosedRange<Int> }
        set { objc_setAssociatedObject(self, &SimilarPhotoAssociatedKeys.currentAnalysisRange, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 분석 완료 옵저버
    private var analysisObserver: NSObjectProtocol? {
        get { objc_getAssociatedObject(self, &SimilarPhotoAssociatedKeys.analysisObserver) as? NSObjectProtocol }
        set { objc_setAssociatedObject(self, &SimilarPhotoAssociatedKeys.analysisObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 뱃지 뷰 재사용 풀
    private var badgeViewPool: [SimilarGroupBadgeView] {
        get { (objc_getAssociatedObject(self, &SimilarPhotoAssociatedKeys.badgeViewPool) as? [SimilarGroupBadgeView]) ?? [] }
        set { objc_setAssociatedObject(self, &SimilarPhotoAssociatedKeys.badgeViewPool, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 삭제 옵저버 (그룹 무효화 처리용)
    private var trashObserver: NSObjectProtocol? {
        get { objc_getAssociatedObject(self, &SimilarPhotoAssociatedKeys.trashObserver) as? NSObjectProtocol }
        set { objc_setAssociatedObject(self, &SimilarPhotoAssociatedKeys.trashObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Setup (T019)

    /// 유사 사진 기능 옵저버 설정
    /// - GridViewController.viewDidLoad()에서 호출
    func setupSimilarPhotoObserver() {
        // Feature Flag 체크
        guard FeatureFlags.isSimilarPhotoEnabled else {
            Logger.similarPhoto.debug("Feature disabled")
            return
        }

        // 분석 완료 알림 구독
        analysisObserver = NotificationCenter.default.addObserver(
            forName: .similarPhotoAnalysisComplete,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAnalysisComplete(notification)
        }

        // 삭제/복구 시 테두리 상태 즉시 갱신
        // TrashStore 변경 알림을 구독하여 뱃지 표시/숨김을 실시간 반영
        trashObserver = NotificationCenter.default.addObserver(
            forName: .trashStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateVisibleCellBorders()
        }

        Logger.similarPhoto.debug("Observer setup complete")

        // 첫 화면 로드 시 분석 시작 (데이터 로드 완료 대기)
        triggerInitialAnalysis()
    }

    /// 첫 화면 로드 시 분석 트리거
    /// - fetchResult 로드 완료 후 분석 시작
    private func triggerInitialAnalysis() {
        // 0.5초 후 분석 시작 (fetchResult 로드 및 collectionView 레이아웃 완료 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // 스크롤 중이 아니고, 기능 활성화 상태인지 확인
            guard self.shouldEnableSimilarPhoto() else { return }
            guard !self.isScrolling else { return }

            Logger.similarPhoto.debug("Triggering initial analysis")
            self.startAnalysis()
        }
    }

    /// 옵저버 해제
    /// - GridViewController.deinit에서 호출 권장
    func removeSimilarPhotoObserver() {
        if let observer = analysisObserver {
            NotificationCenter.default.removeObserver(observer)
            analysisObserver = nil
        }
        if let observer = trashObserver {
            NotificationCenter.default.removeObserver(observer)
            trashObserver = nil
        }
    }

    // MARK: - Scroll Event Handling (T019)

    /// 스크롤 시작 시 호출
    /// - 진행 중인 분석 취소
    /// - 테두리 애니메이션 숨김
    func handleSimilarPhotoScrollStart() {
        // Feature Flag 및 비활성화 조건 체크
        guard shouldEnableSimilarPhoto() else { return }

        // 디바운스 작업 취소
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        // 분석 이미지 로딩 일시정지 (PHImageManager 경합 방지)
        // - 스크롤 중 썸네일 로딩과 분석 이미지 로딩이 photosd 디코더 큐에서 경합
        // - pause로 새 분석 이미지 요청을 차단하여 스크롤 성능 보호
        SimilarityAnalysisQueue.shared.pauseImageLoading()

        // 분석 취소 (grid 소스만)
        SimilarityAnalysisQueue.shared.cancel(source: .grid)

        // 현재 분석 범위 초기화
        currentAnalysisRange = nil

        // 모든 뱃지 숨김 (스크롤 중에는 뱃지 미표시)
        hideAllBadges()
    }

    /// 스크롤 종료 시 호출
    /// - 0.3초 디바운싱 후 분석 시작
    func handleSimilarPhotoScrollEnd() {
        // Feature Flag 및 비활성화 조건 체크
        guard shouldEnableSimilarPhoto() else { return }

        // 기존 디바운스 작업 취소
        debounceWorkItem?.cancel()

        // 새 디바운스 작업 생성
        let workItem = DispatchWorkItem { [weak self] in
            self?.startAnalysis()
        }
        debounceWorkItem = workItem

        // 0.3초 후 분석 시작
        DispatchQueue.main.asyncAfter(
            deadline: .now() + SimilarPhotoConstants.debounceInterval,
            execute: workItem
        )
    }

    // MARK: - Analysis (T019)

    /// 분석 시작
    /// - 화면에 보이는 셀 범위 + 앞뒤 7장 확장
    private func startAnalysis() {
        guard let fetchResult = dataSourceDriver.fetchResult else {
            Logger.similarPhoto.debug("No fetch result available")
            return
        }

        // 분석 범위 계산
        let range = calculateAnalysisRange()
        guard let analysisRange = range else {
            Logger.similarPhoto.debug("Invalid analysis range")
            return
        }

        // 현재 분석 범위 저장
        currentAnalysisRange = analysisRange

        Logger.similarPhoto.debug("Starting analysis for range: \(String(describing: analysisRange))")

        // 분석 요청 (비동기) - Task 등록으로 스크롤 시 취소 가능
        let taskID = UUID()
        let task = Task {
            defer { SimilarityAnalysisQueue.shared.unregisterTask(id: taskID) }
            let groupIDs = await SimilarityAnalysisQueue.shared.formGroupsForRange(
                analysisRange,
                source: .grid,
                fetchResult: fetchResult
            )
            Logger.similarPhoto.debug("Analysis complete, found \(groupIDs.count) groups")
        }
        SimilarityAnalysisQueue.shared.registerTask(task, id: taskID, source: .grid)
    }

    /// 분석 범위 계산
    /// - 화면에 온전히 보이는 셀의 인덱스 범위 + 앞뒤 7장 확장
    /// - 셀 프레임이 collectionView bounds에 완전히 포함되는 셀만 대상
    /// - Returns: 분석 범위 (ClosedRange<Int>) 또는 nil
    private func calculateAnalysisRange() -> ClosedRange<Int>? {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems

        guard !visibleIndexPaths.isEmpty else { return nil }

        // 화면 영역 (collectionView bounds 전체)
        let screenRect = CGRect(
            x: 0,
            y: collectionView.contentOffset.y,
            width: collectionView.bounds.width,
            height: collectionView.bounds.height
        )

        // 셀 프레임이 화면에 온전히 포함되는 셀만 필터링
        let padding = paddingCellCount
        let fullyVisibleIndices = visibleIndexPaths.compactMap { indexPath -> Int? in
            guard let attrs = collectionView.layoutAttributesForItem(at: indexPath) else { return nil }
            guard screenRect.contains(attrs.frame) else { return nil }
            let idx = indexPath.item - padding
            return idx >= 0 ? idx : nil
        }

        guard let minIndex = fullyVisibleIndices.min(),
              let maxIndex = fullyVisibleIndices.max() else {
            return nil
        }

        // 앞뒤 7장 확장
        let extension_count = SimilarityConstants.analysisRangeExtension
        let totalCount = dataSourceDriver.count

        let lowerBound = max(0, minIndex - extension_count)
        let upperBound = min(totalCount - 1, maxIndex + extension_count)

        guard lowerBound <= upperBound else { return nil }

        let visibleCount = fullyVisibleIndices.count
        let analysisCount = upperBound - lowerBound + 1
        Logger.similarPhoto.debug("AnalysisRange: visible=\(minIndex)~\(maxIndex) (\(visibleCount)장), analysis=\(lowerBound)~\(upperBound) (\(analysisCount)장, ±\(extension_count))")

        return lowerBound...upperBound
    }

    // MARK: - Analysis Complete Handler (T019)

    /// 분석 완료 알림 처리
    /// - SimilarityCache가 이미 업데이트된 상태이므로 UI만 갱신
    /// - Parameter notification: 분석 완료 알림
    private func handleAnalysisComplete(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let groupIDs = userInfo["groupIDs"] as? [String],
              let analyzedAssetIDs = userInfo["analyzedAssetIDs"] as? [String] else {
            return
        }

        Logger.similarPhoto.debug("Received analysis complete - groups: \(groupIDs.count), assets: \(analyzedAssetIDs.count)")

        // SimilarityCache가 Single Source of Truth이므로 UI만 갱신
        updateVisibleCellBorders()
    }

    // MARK: - Badge Management (T021)

    /// 보이는 셀들의 뱃지 상태 업데이트
    /// - SimilarityCache를 Single Source of Truth로 사용하여 뱃지 표시 여부 결정
    func updateVisibleCellBorders() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        let padding = paddingCellCount

        // 보이는 셀들의 assetID와 cell 쌍 수집
        var cellsToUpdate: [(assetID: String, cell: PhotoCell)] = []

        for indexPath in visibleIndexPaths {
            // padding 셀 제외
            let actualIndex = indexPath.item - padding
            guard actualIndex >= 0 else { continue }

            let actualIndexPath = IndexPath(item: actualIndex, section: 0)
            guard let assetID = dataSourceDriver.assetID(at: actualIndexPath) else { continue }
            guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else { continue }

            cellsToUpdate.append((assetID: assetID, cell: cell))
        }

        // SimilarityCache에서 각 셀의 그룹 상태 조회 후 뱃지 업데이트
        Task {
            for (assetID, cell) in cellsToUpdate {
                let state = await SimilarityCache.shared.getState(for: assetID)

                // 그룹에 속한 경우: 뱃지 표시 (trashed 사진은 제외)
                if case .analyzed(true, _) = state, !self.trashStore.isTrashed(assetID) {
                    await MainActor.run {
                        self.showBadge(on: cell)
                    }
                } else {
                    await MainActor.run {
                        self.hideBadge(on: cell)
                    }
                }
            }
        }
    }

    /// 셀에 코너 삼각형 뱃지 표시
    /// - 흰색 테두리 + 우상단 삼각형 (등호 아이콘)
    /// - Parameter cell: 뱃지를 표시할 PhotoCell (재생 기능에서도 호출)
    func showBadge(on cell: PhotoCell) {
        // 스크롤 중이면 뱃지 표시하지 않음 (방어 코드)
        guard !isScrolling else { return }

        // 기존 뱃지 찾기 (subviews에서)
        if let existing = cell.contentView.subviews.first(where: { $0 is SimilarGroupBadgeView }) as? SimilarGroupBadgeView {
            existing.show()
            // 코치마크 C-1 트리거 시도 (기존 뱃지에서도 재트리거 필요 — 뷰어에서 복귀 시)
            triggerCoachMarkCIfNeeded(for: cell)
            return
        }

        // 새 뱃지 생성 또는 풀에서 가져오기
        let badge: SimilarGroupBadgeView
        if var pool = badgeViewPool as [SimilarGroupBadgeView]?, !pool.isEmpty {
            badge = pool.removeFirst()
            badgeViewPool = pool
        } else {
            badge = SimilarGroupBadgeView()
        }

        // 셀 전체를 덮도록 설정 (테두리 + 삼각형 함께 표현)
        badge.frame = cell.contentView.bounds
        badge.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // imageView 바로 위, dimmedOverlayView 아래에 삽입
        // → 빨간색 딤드가 뱃지를 자연히 덮음
        cell.contentView.insertSubview(badge, at: 1)
        badge.show()

        // 코치마크 C-1 트리거 시도 (첫 뱃지에서만 동작)
        triggerCoachMarkCIfNeeded(for: cell)
    }

    /// 셀에서 뱃지 제거
    /// - Parameter cell: 뱃지를 제거할 PhotoCell
    private func hideBadge(on cell: PhotoCell) {
        guard let badge = cell.contentView.subviews.first(where: { $0 is SimilarGroupBadgeView }) as? SimilarGroupBadgeView else {
            return
        }

        badge.stopAndHide()
        badge.removeFromSuperview()

        // 풀에 반환
        var pool = badgeViewPool
        if pool.count < 20 { // 최대 20개까지 풀링
            pool.append(badge)
            badgeViewPool = pool
        }
    }

    /// 모든 뱃지 숨김
    private func hideAllBadges() {
        for cell in collectionView.visibleCells {
            guard let photoCell = cell as? PhotoCell else { continue }
            hideBadge(on: photoCell)
        }
    }

    /// 셀이 화면에 나타날 때 뱃지 추가/갱신
    /// - SimilarityCache를 Single Source of Truth로 사용하여 뱃지 표시 여부 결정
    /// - Parameters:
    ///   - cell: 표시될 셀
    ///   - indexPath: 셀의 인덱스 경로
    func configureSimilarPhotoBorder(for cell: PhotoCell, at indexPath: IndexPath) {
        // Feature Flag 체크
        guard shouldEnableSimilarPhoto() else { return }

        // 스크롤 중이면 뱃지 미표시
        guard !isScrolling else {
            hideBadge(on: cell)
            return
        }

        // padding 셀 제외
        let actualIndex = indexPath.item - paddingCellCount
        guard actualIndex >= 0 else {
            hideBadge(on: cell)
            return
        }

        let actualIndexPath = IndexPath(item: actualIndex, section: 0)
        guard let assetID = dataSourceDriver.assetID(at: actualIndexPath) else {
            hideBadge(on: cell)
            return
        }

        // SimilarityCache에서 그룹 상태 조회 후 뱃지 업데이트
        Task {
            let state = await SimilarityCache.shared.getState(for: assetID)

            // 그룹에 속한 경우: 뱃지 표시
            if case .analyzed(true, _) = state {
                await MainActor.run {
                    self.showBadge(on: cell)
                }
            } else {
                await MainActor.run {
                    self.hideBadge(on: cell)
                }
            }
        }
    }

    /// 셀이 화면에서 사라질 때 뱃지 제거
    /// - Parameter cell: 사라지는 셀
    func removeSimilarPhotoBorder(from cell: PhotoCell) {
        hideBadge(on: cell)
    }

    // MARK: - Group Invalidation (T022)

    /// 삭제로 인한 그룹 무효화 처리
    /// - SimilarityCache를 Single Source of Truth로 사용
    /// - 캐시에서 멤버 제거 후 UI 갱신
    /// - 삭제 후 즉시 재분석하지 않고 다음 스크롤 멈춤 시 자동 재분석
    func handleSimilarPhotoAssetDeleted(assetID: String) {
        // 해당 assetID가 속한 그룹 확인 및 무효화 처리
        Task {
            let state = await SimilarityCache.shared.getState(for: assetID)

            if case .analyzed(true, let groupID?) = state {
                // 그룹에서 멤버 제거 (3장 미만 시 자동 무효화됨)
                await SimilarityCache.shared.removeMemberFromGroup(assetID, groupID: groupID)
            }

            // SimilarityCache가 Single Source of Truth이므로 UI만 갱신
            await MainActor.run {
                self.updateVisibleCellBorders()
            }
        }
    }

    // MARK: - Private Helpers

    /// 유사 사진 기능 활성화 여부 확인
    /// - Returns: 기능 활성화 여부
    private func shouldEnableSimilarPhoto() -> Bool {
        // Feature Flag 체크
        guard FeatureFlags.isSimilarPhotoEnabled else { return false }

        // VoiceOver 활성화 시 비활성화
        guard !UIAccessibility.isVoiceOverRunning else { return false }

        // 선택 모드 시 비활성화
        guard !isSelectMode else { return false }

        // 선행 온보딩(A, E-1) 미완료 시 비활성화
        // C 온보딩이 자연스럽게 유사사진 기능을 안내하도록 순서 보장
        guard CoachMarkType.gridSwipeDelete.hasBeenShown else { return false }
        guard CoachMarkType.firstDeleteGuide.hasBeenShown else { return false }

        return true
    }
}
