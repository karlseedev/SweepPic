//
//  GridScroll.swift
//  PickPhoto
//
//  Created by Claude on 2025-12-31.
//  Description: GridViewController의 스크롤 최적화 및 초기 표시 기능 분리
//               - Scroll Optimization (T025)
//               - Initial Display (B+A 조합 v2)
//               - Initial Preheat (v6)
//

import UIKit
import Photos
import AppCore

// MARK: - Initial Display Start

extension GridViewController {

    /// 초기 표시 시작 (viewDidLayoutSubviews에서 호출)
    func startInitialDisplay() {
        #if DEBUG
        let startMs = (CACurrentMediaTime() - loadStartTime) * 1000
        FileLogger.log("[InitialDisplay] 시작: +\(String(format: "%.1f", startMs))ms, cellSize=\(Int(currentCellSize.width))x\(Int(currentCellSize.height))pt")
        #endif

        // 1) 노출 게이트 - collectionView 숨김
        collectionView.alpha = 0

        // 2) 데이터 로드 (PHFetchResult만 가져옴, UI는 아직 안 그림)
        dataSourceDriver.reloadData { [weak self] in
            guard let self = self else { return }

            // 빈 상태 업데이트
            self.updateEmptyState()

            let count = self.dataSourceDriver.count
            guard count > 0 else {
                // 사진 없음 → 바로 완료
                self.finishInitialDisplay(reason: "empty")
                return
            }

            #if DEBUG
            let dataMs = (CACurrentMediaTime() - self.loadStartTime) * 1000
            FileLogger.log("[InitialDisplay] 데이터 로드 완료: +\(String(format: "%.1f", dataMs))ms, \(count)장")
            #endif

            // 3) 타임아웃 설정 (100ms)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.initialDisplayTimeout) { [weak self] in
                self?.finishInitialDisplay(reason: "timeout")
            }

            // 4) 프리로드 시작 (디스크 → 메모리)
            // 프리로드 완료 시 finishInitialDisplay 호출
            self.startInitialPreload()
        }
    }
}

// MARK: - Scroll Optimization (T025)

extension GridViewController {

    /// 스크롤 시작
    func scrollDidBegin() {
        guard !isScrolling else { return }
        isScrolling = true

        // 스크롤 종료 타이머 취소
        scrollEndTimer?.invalidate()

        // [B) HitchMonitor] 스크롤 시작 시 모니터링 시작
        currentScrollStartTime = CACurrentMediaTime()
        hitchMonitor.start()

        // 첫 스크롤 시작 시간 기록
        if !hasCompletedFirstScroll && firstScrollStartTime == 0 {
            firstScrollStartTime = currentScrollStartTime
            FileLogger.log("[Scroll] First scroll 시작: +\(String(format: "%.1f", (currentScrollStartTime - loadStartTime) * 1000))ms")
        }

        // [SimilarPhoto] 스크롤 시작 시 분석 취소 및 테두리 제거 (T023)
        similarPhotoScrollDidBegin()
    }

    /// 스크롤 종료
    func scrollDidEnd() {
        // [Phase 1] 디바운스 50ms (100ms → 50ms)
        // - 스크롤 정지 후 R2 업그레이드 시작을 50ms 앞당김
        scrollEndTimer?.invalidate()
        scrollEndTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.isScrolling = false

            // [B) HitchMonitor] 스크롤 종료 시 결과 로그
            let hitchResult = self.hitchMonitor.stop()
            self.logScrollQuality(result: hitchResult)

            // [C) First Scroll 완료 마킹]
            // - 통계는 logScrollQuality()에서 [L1 First] 라벨로 이미 출력됨
            // - 여기서는 완료 시점과 duration만 기록
            if !self.hasCompletedFirstScroll {
                self.hasCompletedFirstScroll = true
                let scrollDuration = (CACurrentMediaTime() - self.firstScrollStartTime) * 1000
                FileLogger.log("[Scroll] First scroll 완료: \(String(format: "%.1f", scrollDuration))ms 동안 스크롤")
            }

            // [preheat 최적화] 스크롤 정지 후 1회 preheat
            // - 스크롤 중에는 OFF (hitch 방지)
            // - 정지 후에만 visible + 1화면 범위 캐싱
            self.preheatAfterScrollStop()

            // [R2 로그] 스크롤 종료 시간 및 시퀀스 저장
            self.lastScrollEndTime = CACurrentMediaTime()
            let currentSeq = self.scrollSeq
            // 스크롤 중 peak velocity 사용 (손가락으로 멈추든 플릭으로 멈추든 측정됨)
            let velocity = Int(max(self.peakScrollVelocityY, self.lastEndVelocityY))

            // [R2:Timing] 로그
            if FileLogger.logThumbEnabled {
                FileLogger.log("[R2:Timing] seq=\(currentSeq), velocity=\(velocity)pt/s, 디바운스=50ms")
            }

            // [R2] 스크롤 정지 후 visible 셀 고해상도 업그레이드
            // - 스크롤 중 50% 크기로 요청된 셀을 100% 크기로 재요청
            // - Gate2 spike test에서 검증된 R2 정지 복구 패턴
            // - .opportunistic은 같은 targetSize 내에서만 저→고 자동 업그레이드
            // - 다른 targetSize(50%→100%)로의 업그레이드는 명시적 재요청 필요
            self.upgradeVisibleCellsToHighQuality(scrollSeq: currentSeq, scrollEndTime: self.lastScrollEndTime)

            // [--log-thumb] 스크롤 종료 후 visible 셀 해상도 검사 (2회: 0.2s, 0.6s)
            if FileLogger.logThumbEnabled {
                // 0.2초 후 첫 번째 체크
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.logVisibleCellResolution(seq: currentSeq, timing: "0.2s", velocity: velocity)
                }
                // 0.6초 후 두 번째 체크 (수렴 확인)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.logVisibleCellResolution(seq: currentSeq, timing: "0.6s", velocity: velocity)
                }
            }

            // [SimilarPhoto] 스크롤 종료 시 유사 사진 분석 트리거 (T021)
            self.similarPhotoScrollDidEnd()
        }
    }

    /// [R2] visible 셀을 고해상도로 업그레이드
    /// - 스크롤 중 50% 크기로 요청된 셀을 100% 크기로 재요청
    /// - Gate2 spike test R2 정지 복구 패턴 구현
    /// - Parameters:
    ///   - scrollSeq: 스크롤 시퀀스 (로그 매칭용)
    ///   - scrollEndTime: 스크롤 종료 시간 (응답 시간 계산용)
    private func upgradeVisibleCellsToHighQuality(scrollSeq: Int, scrollEndTime: CFTimeInterval) {
        let fullSize = thumbnailSize(forScrolling: false)  // 100% 크기
        let visibleCells = collectionView.visibleCells
        let padding = paddingCellCount

        var visibleCount = 0
        var upgradedCount = 0

        for cell in visibleCells {
            guard let photoCell = cell as? PhotoCell,
                  let indexPath = collectionView.indexPath(for: cell) else { continue }

            // padding 셀은 스킵
            guard indexPath.item >= padding else { continue }

            visibleCount += 1

            // asset 가져오기
            let assetIndex = IndexPath(item: indexPath.item - padding, section: indexPath.section)
            guard let asset = dataSourceDriver.asset(at: assetIndex) else { continue }

            // 고해상도로 재요청 (내부에서 크기 비교하여 필요 시에만 요청)
            // TODO: Phase 1에서 scrollEndTime/scrollSeq 파라미터 추가
            if photoCell.refreshImageIfNeeded(asset: asset, targetSize: fullSize) {
                upgradedCount += 1
            }
        }

        if FileLogger.logThumbEnabled {
            FileLogger.log("[R2] seq=\(scrollSeq), visible=\(visibleCount), upgraded=\(upgradedCount)")
        }
    }

    /// [--log-thumb] visible 셀의 실제 이미지 해상도 vs 기대 해상도 로그
    /// - Parameters:
    ///   - seq: 스크롤 시퀀스 번호 (로그 매칭용)
    ///   - timing: 체크 시점 문자열 (예: "0.2s", "0.6s")
    ///   - velocity: 스크롤 종료 시 velocity (pt/s)
    private func logVisibleCellResolution(seq: Int, timing: String, velocity: Int) {
        guard FileLogger.logThumbEnabled else { return }

        let expectedSize = thumbnailSize(forScrolling: false)  // 스크롤 정지 상태의 기대 크기
        let visibleCells = collectionView.visibleCells.compactMap { $0 as? PhotoCell }

        var underSizedCount = 0
        var matchCount = 0
        var totalCount = 0

        for cell in visibleCells {
            guard let image = cell.thumbnailImageView.image else { continue }
            totalCount += 1

            let imgPx = image.size.width * image.scale
            let expectedPx = expectedSize.width

            // 이미지가 기대 크기의 90% 미만이면 undersized
            if imgPx < expectedPx * 0.9 {
                underSizedCount += 1
            } else {
                matchCount += 1
            }
        }

        // 로그 형식: [Thumb:Check] seq=5, t=0.2s, velocity=3200, underSized=10/24
        FileLogger.log("[Thumb:Check] seq=\(seq), t=\(timing), velocity=\(velocity), underSized=\(underSizedCount)/\(totalCount)")
    }

    // MARK: - Phase 2: 감속 중 preheat

    /// [Phase 2] 감속 중 100% preheat 선행
    /// - 스크롤이 감속하는 동안 목표 위치의 셀들을 미리 100% 캐싱
    /// - 스크롤 정지 시점에 이미 캐시가 준비되어 즉시 전환
    /// - Parameter targetOffset: scrollViewWillEndDragging의 targetContentOffset
    func preheatForDeceleration(targetOffset: CGPoint) {
        // 중복 호출 방지
        guard !isDecelerationPreheatScheduled else { return }
        isDecelerationPreheatScheduled = true

        // [버그 수정] thumbnailSize(forScrolling: false)는 isScrolling 체크로 50% 반환
        // 여기서는 강제로 100% 크기 계산 (스크롤 중에도 100% preheat 필요)
        let scale = UIScreen.main.scale
        let fullSize = CGSize(
            width: currentCellSize.width * scale,
            height: currentCellSize.height * scale
        )

        // targetOffset 기준 visible 영역 계산
        let targetRect = CGRect(
            origin: targetOffset,
            size: collectionView.bounds.size
        )

        // 해당 영역의 layoutAttributes 가져오기
        guard let layoutAttributes = collectionView.collectionViewLayout
            .layoutAttributesForElements(in: targetRect) else {
            isDecelerationPreheatScheduled = false
            return
        }

        // padding 적용하여 asset indexPaths 변환
        let padding = paddingCellCount
        let assetIndexPaths = layoutAttributes.compactMap { attr -> IndexPath? in
            guard attr.indexPath.item >= padding else { return nil }
            return IndexPath(item: attr.indexPath.item - padding, section: 0)
        }

        // PHAsset 배열 가져오기
        let assets = assetIndexPaths.compactMap { dataSourceDriver.asset(at: $0) }
        guard !assets.isEmpty else {
            isDecelerationPreheatScheduled = false
            return
        }

        // [Phase 2 로그]
        if FileLogger.logThumbEnabled {
            FileLogger.log("[Preheat:Decel] seq=\(scrollSeq), \(assets.count)개 에셋, targetSize=\(Int(fullSize.width))px")
        }

        // 백그라운드에서 preheat
        DispatchQueue.global(qos: .userInitiated).async {
            ImagePipeline.shared.preheatAssets(assets, targetSize: fullSize)
        }

        // 타이머 기반 플래그 리셋 (0.3초 후)
        // preheat가 오래 걸려도 다음 스크롤에서 스킵되지 않도록
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isDecelerationPreheatScheduled = false
        }
    }

    /// 스크롤 정지 후 preheat (1회)
    /// - visible + 1화면 범위만 캐싱
    /// - 백그라운드에서 실행하여 메인 스레드 부하 최소화
    private func preheatAfterScrollStop() {
        // 현재 visible indexPaths
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else { return }

        // padding 오프셋 적용하여 실제 asset indexPaths 변환
        let padding = paddingCellCount
        let assetIndexPaths = visibleIndexPaths.compactMap { indexPath -> IndexPath? in
            guard indexPath.item >= padding else { return nil }
            return IndexPath(item: indexPath.item - padding, section: indexPath.section)
        }

        // +1 화면 반경 (약 21개 셀 = 7행 × 3열)
        let extendedIndexPaths = extendIndexPaths(assetIndexPaths, by: 21)

        // PHAsset 배열 가져오기
        let assets = extendedIndexPaths.compactMap { dataSourceDriver.asset(at: $0) }
        guard !assets.isEmpty else { return }

        // 정확한 pixelSize (pt × scale)
        let scale = UIScreen.main.scale
        let targetSize = CGSize(
            width: currentCellSize.width * scale,
            height: currentCellSize.height * scale
        )

        // 백그라운드에서 preheat (메인 스레드 부하 방지)
        DispatchQueue.global(qos: .userInitiated).async {
            ImagePipeline.shared.preheatAssets(assets, targetSize: targetSize)
        }
    }

    /// 스크롤 품질 로그 (HitchMonitor 결과)
    /// - Parameter result: HitchResult
    private func logScrollQuality(result: HitchResult) {
        // 스크롤 유형 결정
        // - 첫 스크롤이 아직 완료되지 않았으면 "L1 First"
        // - 완료되었으면 "L2 Steady"
        let scrollType = hasCompletedFirstScroll ? "L2 Steady" : "L1 First"

        FileLogger.log("[Hitch] \(scrollType): \(result.formatted())")

        // [Cache Stats] 구간별 캐시 통계 출력
        MemoryThumbnailCache.shared.logStats(label: scrollType)
        PhotoCell.logMismatchStats(label: scrollType)
        PhotoCell.logGrayCellStats(label: scrollType)

        // [Pipeline Stats] 구간별 파이프라인 통계 출력 (L2에서도 확인 가능하도록)
        ImagePipeline.shared.logStats(label: scrollType)

        // 통계 리셋 (다음 구간을 위해)
        MemoryThumbnailCache.shared.resetStats()
        PhotoCell.resetMismatchStats()
        PhotoCell.resetGrayCellStats()
        ImagePipeline.shared.resetStats()
    }
}

// MARK: - Initial Display (B+A 조합 v2)

extension GridViewController {

    /// 단일 완료 경로 - 모든 초기 표시 로직이 여기로 수렴
    /// 순서: reloadData → layoutIfNeeded → scrollToBottom → layoutIfNeeded → reveal
    /// - Parameter reason: 완료 이유 (preload complete, timeout 등)
    func finishInitialDisplay(reason: String) {
        // 중복 호출 방지 (단일 상태)
        guard !hasFinishedInitialDisplay else { return }
        hasFinishedInitialDisplay = true

        // [Timing] E0: finishInitialDisplay 시작
        let e0Time = CACurrentMediaTime()
        let e0Ms = (e0Time - loadStartTime) * 1000
        FileLogger.log("[Timing] E0) finishInitialDisplay 시작: +\(String(format: "%.1f", e0Ms))ms (reason: \(reason), preloaded: \(preloadCompletedCount)/\(preloadTargetCount))")

        // 1) 셀 표시 허용 → reloadData에서 실제 count 반환
        shouldShowItems = true

        // 2) UI 그리기 (프리로드된 메모리 캐시에서 히트)
        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        // [Timing] E1: reloadData + layoutIfNeeded 완료
        let e1Time = CACurrentMediaTime()
        let e0ToE1Ms = (e1Time - e0Time) * 1000
        FileLogger.log("[Timing] E1) reloadData+layout 완료: +\(String(format: "%.1f", (e1Time - loadStartTime) * 1000))ms (E0→E1: \(String(format: "%.1f", e0ToE1Ms))ms)")

        // 3) 맨 아래로 스크롤 (FR-003: 최신 사진)
        scrollToBottomIfNeeded()

        // 4) 바닥 셀 구성 강제
        collectionView.layoutIfNeeded()

        // [Timing] E2: scrollToItem + layoutIfNeeded 완료
        let e2Time = CACurrentMediaTime()
        let e1ToE2Ms = (e2Time - e1Time) * 1000
        FileLogger.log("[Timing] E2) scrollToItem+layout 완료: +\(String(format: "%.1f", (e2Time - loadStartTime) * 1000))ms (E1→E2: \(String(format: "%.1f", e1ToE2Ms))ms)")

        // 5) reveal (fade-in)
        UIView.animate(withDuration: 0.15) {
            self.collectionView.alpha = 1
        }

        // [Timing] 완료 시점 요약
        let totalMs = (e2Time - loadStartTime) * 1000
        FileLogger.log("[Timing] === 초기 로딩 완료: +\(String(format: "%.1f", totalMs))ms (E0→E1: \(String(format: "%.1f", e0ToE1Ms))ms, E1→E2: \(String(format: "%.1f", e1ToE2Ms))ms) ===")

        // [DEBUG] 최종 통계 출력
        FileLogger.log("[Timing] 최종 통계: cellForItemAt \(cellForItemAtCount)회, 총 \(String(format: "%.1f", cellForItemAtTotalTime))ms, 평균 \(String(format: "%.2f", cellForItemAtCount > 0 ? cellForItemAtTotalTime / Double(cellForItemAtCount) : 0))ms")

        // [Pipeline] 파이프라인 통계 출력
        ImagePipeline.shared.logStats(label: "Initial Load")

        // [Cache Stats] 초기 로드 캐시 통계 출력
        MemoryThumbnailCache.shared.logStats(label: "Initial Load")
        PhotoCell.logMismatchStats(label: "Initial Load")
        PhotoCell.logGrayCellStats(label: "Initial Load")

        // 통계 리셋 (스크롤 구간용으로 리셋)
        MemoryThumbnailCache.shared.resetStats()
        PhotoCell.resetGrayCellStats()
        PhotoCell.resetMismatchStats()
    }

    /// 맨 아래로 스크롤 (FR-003)
    private func scrollToBottomIfNeeded() {
        let totalCount = dataSourceDriver.count
        guard totalCount > 0 else { return }

        // padding 적용된 마지막 인덱스
        let lastIndex = totalCount - 1 + paddingCellCount
        let lastIndexPath = IndexPath(item: lastIndex, section: 0)

        collectionView.scrollToItem(
            at: lastIndexPath,
            at: .bottom,
            animated: false
        )
    }

    /// 프리로드 범위 계산 (visible 기반)
    /// - Returns: (시작 인덱스, 개수)
    private func calculatePreloadRange() -> (startIndex: Int, count: Int) {
        let totalCount = dataSourceDriver.count
        guard totalCount > 0 else { return (0, 0) }

        // 현재 레이아웃 기준 visible 계산
        let cellHeight = currentCellSize.height + Self.cellSpacing
        guard cellHeight > 0 else { return (0, min(12, totalCount)) }

        // Note: visibleRows, columns는 동적 계산용으로 예약됨 (현재 12개 고정)
        // let visibleRows = Int(ceil(collectionView.bounds.height / cellHeight))
        // let columns = currentColumnCount.rawValue

        // 1 screen 분량 (12개 고정)
        // 105ms에 11개 완료 실적 기준, 12개면 timeout 전에 preload complete 가능
        let targetCount = min(12, totalCount)

        // 도착 위치 = 맨 아래 (최신 사진)
        let startIndex = max(0, totalCount - targetCount)
        let actualCount = totalCount - startIndex

        return (startIndex, actualCount)
    }

    /// 첫 화면 프리로드 시작 (디스크 → 메모리)
    private func startInitialPreload() {
        // 방어: currentCellSize가 0이면 다음 런루프에서 재시도
        guard currentCellSize != .zero else {
            #if DEBUG
            FileLogger.log("[Preload] currentCellSize==0, 다음 런루프에서 재시도")
            #endif
            DispatchQueue.main.async { [weak self] in
                self?.startInitialPreload()
            }
            return
        }

        let (startIndex, count) = calculatePreloadRange()
        guard count > 0 else {
            finishInitialDisplay(reason: "empty")
            return
        }

        preloadTargetCount = count
        preloadCompletedCount = 0

        // pixelSize는 thumbnailSize()와 동일하게 계산 (pt × scale)
        // PhotoCell에서도 동일한 값을 사용해야 메모리 캐시 히트
        let pixelSize = thumbnailSize()

        #if DEBUG
        // 검증 로그: 프리로드에서 사용하는 pixelSize
        FileLogger.log("[Preload] 시작: index \(startIndex)~\(startIndex + count - 1) (\(count)개), pixelSize=\(Int(pixelSize.width))x\(Int(pixelSize.height))px")
        #endif

        // 각 에셋에 대해 디스크 캐시 → 메모리 캐시 로드
        for i in 0..<count {
            let indexPath = IndexPath(item: startIndex + i, section: 0)
            guard let asset = dataSourceDriver.asset(at: indexPath) else {
                onPreloadCompleted()
                continue
            }

            let assetID = asset.localIdentifier

            // 이미 메모리에 있으면 스킵
            if MemoryThumbnailCache.shared.get(assetID: assetID, pixelSize: pixelSize) != nil {
                onPreloadCompleted()
                continue
            }

            // 디스크 캐시에서 비동기 로드
            ThumbnailCache.shared.load(
                assetID: assetID,
                modificationDate: asset.modificationDate,
                size: pixelSize
            ) { [weak self] image in
                // 메모리 캐시에 저장
                if let image = image {
                    FileLogger.log("[Preload] DISK HIT: \(assetID.prefix(8))...")
                    MemoryThumbnailCache.shared.set(image: image, assetID: assetID, pixelSize: pixelSize)
                } else {
                    FileLogger.log("[Preload] DISK MISS: \(assetID.prefix(8))...")
                }
                self?.onPreloadCompleted()
            }
        }
    }

    /// 프리로드 완료 콜백
    private func onPreloadCompleted() {
        preloadCompletedCount += 1

        // 목표 도달 시 finish
        if preloadCompletedCount >= preloadTargetCount {
            finishInitialDisplay(reason: "preload complete")
        }
    }
}

// MARK: - Initial Preheat (v6)

extension GridViewController {

    /// 첫 화면 프리히트 (viewDidAppear 이후 호출 - visible 보장)
    /// - visible indexPaths가 확실히 채워진 시점에 호출
    /// - +1 화면 반경까지 프리히트
    func preheatInitialScreen() {
        guard !hasPreheatedInitialScreen else { return }
        hasPreheatedInitialScreen = true

        // 정확한 pixelSize (pt × scale)
        let scale = UIScreen.main.scale
        let targetSize = CGSize(
            width: currentCellSize.width * scale,
            height: currentCellSize.height * scale
        )

        // viewDidAppear 이후이므로 visible indexPaths 확실히 존재
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else {
            // 만약을 위한 fallback
            hasPreheatedInitialScreen = false
            print("[GridViewController] preheatInitialScreen: visible empty, will retry")
            return
        }

        // padding 오프셋 적용하여 실제 asset indexPaths 변환
        let padding = paddingCellCount
        let assetIndexPaths = visibleIndexPaths.compactMap { indexPath -> IndexPath? in
            guard indexPath.item >= padding else { return nil }
            return IndexPath(item: indexPath.item - padding, section: indexPath.section)
        }

        // +1 화면 반경 (약 21개 셀 = 7행 × 3열)
        let extendedIndexPaths = extendIndexPaths(assetIndexPaths, by: 21)

        // PHAsset 배열 가져오기
        let assets = extendedIndexPaths.compactMap { dataSourceDriver.asset(at: $0) }
        guard !assets.isEmpty else {
            print("[GridViewController] preheatInitialScreen: no assets to preheat")
            return
        }

        // 백그라운드에서 프리히트 (v6: 메인 스레드 블로킹 방지)
        DispatchQueue.global(qos: .userInitiated).async {
            ImagePipeline.shared.preheatAssets(assets, targetSize: targetSize)
        }

        print("[GridViewController] preheatInitialScreen: \(assets.count) assets")
    }

    /// IndexPath 배열을 확장 (앞뒤로 지정 개수만큼)
    func extendIndexPaths(_ indexPaths: [IndexPath], by count: Int) -> [IndexPath] {
        guard !indexPaths.isEmpty else { return [] }

        let sortedItems = indexPaths.map { $0.item }.sorted()
        guard let minItem = sortedItems.first,
              let maxItem = sortedItems.last else { return indexPaths }

        // 확장 범위 계산
        let extendedMin = max(0, minItem - count)
        let extendedMax = min(dataSourceDriver.count - 1, maxItem + count)

        guard extendedMin <= extendedMax else { return indexPaths }

        return (extendedMin...extendedMax).map { IndexPath(item: $0, section: 0) }
    }
}
