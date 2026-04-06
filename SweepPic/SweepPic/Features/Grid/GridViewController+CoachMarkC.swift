//
//  GridViewController+CoachMarkC.swift
//  SweepPic
//
//  Created by Claude Code on 2026-02-17.
//
//  코치마크 C: 유사사진 비교정리 온보딩
//
//  [사전 분석]
//  - 앱 시작 시 FaceScanService로 백그라운드 분석 (최신순, 1그룹 발견 즉시 중단)
//  - 발견한 그룹을 SimilarityCache.shared에 반영 (뱃지 표시 + C-1 동작에 필요)
//  - 결과를 UserDefaults에 저장 (앱 재시작 시 재분석 방지)
//
//  [C-1 트리거]
//  - showBadge(on:count:) 호출 시 triggerCoachMarkCIfNeeded(for:) 진입
//  - 1초 딜레이 후 재검증 → 코치마크 표시
//  - [확인] + 탭 모션 후 자동으로 뷰어 네비게이션
//  - 중복 방지: hasTriggeredC1 associated object 플래그
//
//  트리거: showBadge → triggerCoachMarkCIfNeeded → 1초 딜레이 → showSimilarBadgeCoachMark
//  네비게이션: navigateToViewerForCoachMark → collectionView(_:didSelectItemAt:) 직접 호출

import UIKit
import Photos
import ObjectiveC
import AppCore
import OSLog

// MARK: - Associated Keys

/// C-1 extension stored property를 위한 키
private enum CoachMarkCAssociatedKeys {
    static var hasTriggeredC1: UInt8 = 0
}

/// C 사전 분석 associated object 키
private enum CoachMarkCPreScanAssociatedKeys {
    static var service: UInt8 = 0
    static var cache: UInt8 = 0
    static var onStateChanged: UInt8 = 0
    static var loadingView: UInt8 = 0
    static var loadingTimeout: UInt8 = 0
}

/// C 사전 분석 UserDefaults 키
private enum CoachMarkCPreScanDefaults {
    /// 사전 분석 완료 여부
    static let isComplete = "CoachMarkCPreScan.isComplete"
    /// 발견된 대표 assetID (nil이면 유사사진 없음)
    static let foundAssetID = "CoachMarkCPreScan.foundAssetID"
}

// MARK: - Coach Mark C: Pre-Scan + C-1 Trigger

extension GridViewController {

    // MARK: - C Pre-Scan: Associated Properties

    /// C 사전 분석 FaceScanService (분석 진행 중 보관 + 취소용)
    private var cPreScanService: FaceScanService? {
        get { objc_getAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.service) as? FaceScanService }
        set { objc_setAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.service, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// C 사전 분석 FaceScanCache (faces 조회용 — SimilarityCache.shared 브리지에 필요)
    private var cPreScanCache: FaceScanCache? {
        get { objc_getAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.cache) as? FaceScanCache }
        set { objc_setAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.cache, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - C Pre-Scan: State (UserDefaults)

    /// C 사전 분석 완료 여부 (앱 재시작 시에도 유지)
    static var cPreScanIsComplete: Bool {
        UserDefaults.standard.bool(forKey: CoachMarkCPreScanDefaults.isComplete)
    }

    /// C 사전 분석에서 발견한 대표 assetID (nil이면 유사사진 없음)
    static var cPreScanFoundAssetID: String? {
        UserDefaults.standard.string(forKey: CoachMarkCPreScanDefaults.foundAssetID)
    }

    /// C 사전 분석 완료 + 유사사진 0건 여부 (Phase 4: D 언블록 조건)
    static var cPreScanCompleteWithNoGroups: Bool {
        cPreScanIsComplete && cPreScanFoundAssetID == nil
    }

    // MARK: - C Pre-Scan: Start

    /// C 사전 분석 시작 (앱 시작 시 viewDidAppear에서 호출)
    ///
    /// FaceScanService를 활용하여 최신 사진부터 유사사진 1그룹을 찾는다.
    /// 1그룹 발견 즉시 cancel()로 조기 종료하고, SimilarityCache.shared에 반영한다.
    /// 결과는 UserDefaults에 저장하여 앱 재시작 시 재분석을 방지한다.
    func startCoachMarkCPreScanIfNeeded() {
        // C 이미 완료 → skip
        guard !CoachMarkType.similarPhoto.hasBeenShown else { return }

        // 사전 분석 이미 완료 → skip
        guard !Self.cPreScanIsComplete else { return }

        // 이미 진행 중 → skip
        guard cPreScanService == nil else { return }

        // fetchResult 필요 (초기 로딩 전이면 다음 viewDidAppear에서 재시도)
        guard let fetchResult = dataSourceDriver.fetchResult else { return }

        Logger.coachMark.debug("C 사전분석: 시작")

        let cache = FaceScanCache()
        let service = FaceScanService(cache: cache)
        self.cPreScanCache = cache
        self.cPreScanService = service

        Task.detached(priority: .utility) { [weak self] in
            do {
                try await service.analyze(
                    method: .fromLatest,
                    fetchResult: fetchResult,
                    onGroupFound: { [weak self] group in
                        // 메인 스레드에서 호출됨 (FaceScanService 보장)
                        guard let self else { return }

                        // 1그룹 발견 즉시 취소 (조기 종료)
                        service.cancel()

                        let representativeID = group.memberAssetIDs.first ?? ""
                        Logger.coachMark.debug("C 사전분석: 1그룹 발견 (\(group.memberAssetIDs.count)장) — 브리지 시작")

                        // FaceScanCache → SimilarityCache.shared 브리지 (비동기)
                        Task { [weak self] in
                            // 멤버별 얼굴 데이터 조회
                            var photoFaces: [String: [CachedFace]] = [:]
                            for assetID in group.memberAssetIDs {
                                let faces = await cache.getFaces(for: assetID)
                                photoFaces[assetID] = faces
                            }

                            // SimilarityCache.shared에 그룹 반영 (뱃지 표시에 필요)
                            await SimilarityCache.shared.addGroupIfValid(
                                members: group.memberAssetIDs,
                                validSlots: group.validPersonIndices,
                                photoFaces: photoFaces
                            )

                            // UserDefaults 저장 (SimilarityCache 반영 완료 후에만)
                            await MainActor.run { [weak self] in
                                UserDefaults.standard.set(true, forKey: CoachMarkCPreScanDefaults.isComplete)
                                UserDefaults.standard.set(representativeID, forKey: CoachMarkCPreScanDefaults.foundAssetID)
                                Logger.coachMark.debug("C 사전분석: 브리지 완료 — assetID=\(representativeID)")

                                // 보이는 셀 뱃지 업데이트
                                self?.updateVisibleCellBorders()

                                // 로딩 UI 대기 중이면 알림 (Phase 2)
                                self?.onCPreScanStateChanged?()
                                self?.onCPreScanStateChanged = nil
                            }
                        }
                    },
                    onProgress: { _ in }  // 진행률 무시 (UI 불필요)
                )

                // analyze() 자연 완료 — cancel() 호출 여부로 분기
                await MainActor.run { [weak self] in
                    if !service.cancelled {
                        // cancel() 미호출 = 유사사진 0건 → 여기서 UserDefaults 처리
                        UserDefaults.standard.set(true, forKey: CoachMarkCPreScanDefaults.isComplete)
                        Logger.coachMark.debug("C 사전분석: 완료 (유사사진 없음)")

                        // 로딩 UI 대기 중이면 알림 (Phase 2)
                        self?.onCPreScanStateChanged?()
                        self?.onCPreScanStateChanged = nil
                    }
                    // cancel() 호출됨 = 1그룹 발견 → bridge Task가 UserDefaults 처리
                    self?.cPreScanService = nil
                }
            } catch is CancellationError {
                // 성공적 조기 종료 (1그룹 발견 후 cancel → CancellationError)
                // bridge Task가 UserDefaults 처리를 담당
                await MainActor.run { [weak self] in
                    self?.cPreScanService = nil
                    Logger.coachMark.debug("C 사전분석: 조기 종료 (CancellationError)")
                }
            } catch {
                // 예상치 못한 에러
                await MainActor.run { [weak self] in
                    self?.cPreScanService = nil
                    Logger.coachMark.error("C 사전분석 실패: \(error)")
                }
            }
        }
    }

    // MARK: - C Pre-Scan: Debug Reset

    #if DEBUG
    /// 디버그: C 사전 분석 상태 초기화
    static func debugResetCPreScan() {
        UserDefaults.standard.removeObject(forKey: CoachMarkCPreScanDefaults.isComplete)
        UserDefaults.standard.removeObject(forKey: CoachMarkCPreScanDefaults.foundAssetID)
        Logger.coachMark.debug("C 사전분석: 디버그 리셋")
    }
    #endif

    // MARK: - Associated Property

    /// C-1 트리거 완료 플래그 (중복 방지)
    /// showBadge는 visible 셀 전체에 대해 반복 호출되므로,
    /// 첫 호출에서 true로 설정하여 이후 호출을 스킵
    /// 리셋: dismiss/타임아웃/재검증 실패 시 false
    var hasTriggeredC1: Bool {
        get {
            (objc_getAssociatedObject(self, &CoachMarkCAssociatedKeys.hasTriggeredC1) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &CoachMarkCAssociatedKeys.hasTriggeredC1,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Trigger

    /// 뱃지 표시 시 C-1 코치마크 트리거 시도
    /// showBadge(on:count:) 마지막에서 호출됨
    /// - Parameter cell: 뱃지가 표시된 PhotoCell
    func triggerCoachMarkCIfNeeded(for cell: PhotoCell) {
        // 이미 표시된 적 있으면 스킵
        guard !CoachMarkType.similarPhoto.hasBeenShown else { return }

        // A(그리드 스와이프) 완료 후에만 C 표시
        guard CoachMarkType.gridSwipeDelete.hasBeenShown else { return }

        // E-1(첫 삭제 안내) 완료 후에만 C 표시
        guard CoachMarkType.firstDeleteGuide.hasBeenShown else { return }

        // 현재 다른 코치마크 표시 중이면 스킵
        guard !CoachMarkManager.shared.isShowing else { return }

        // 이미 C-1 트리거됨 (중복 방지)
        guard !hasTriggeredC1 else { return }

        // Select 모드면 스킵 (didSelectItemAt의 isSelectMode 가드 통과 보장)
        guard !isSelectMode else { return }

        // VoiceOver 활성 시 스킵
        guard !UIAccessibility.isVoiceOverRunning else { return }

        // 화면이 활성 상태인지
        guard let window = view.window else { return }

        // 그리드가 최상위 화면인지 (뷰어가 push/present된 상태면 스킵)
        guard navigationController?.topViewController === self,
              presentedViewController == nil else { return }

        // 초기 로딩 완료 후에만
        guard hasFinishedInitialDisplay else { return }

        // 가시 영역 사전 검증: 상하 12.5% 마진 제외한 중앙 75% 영역에 셀이 완전히 들어와야 함
        // 락(hasTriggeredC1) 잡기 전에 체크 → zone 밖 셀은 락을 잡지 않아 다른 셀에 기회를 줌
        guard let cellFrame = cell.superview?.convert(cell.frame, to: window) else { return }
        let screenHeight = window.bounds.height
        let topMargin = screenHeight * 0.125
        let bottomMargin = screenHeight * 0.875
        guard cellFrame.minY >= topMargin && cellFrame.maxY <= bottomMargin else { return }

        // 중복 트리거 방지 — zone 안 첫 뱃지에서만 동작
        hasTriggeredC1 = true

        // 셀의 indexPath + assetID 캡처
        guard let indexPath = collectionView.indexPath(for: cell) else {
            hasTriggeredC1 = false
            return
        }

        // assetID 캡처 (PHChange 안전성 확보)
        let actualIndex = indexPath.item - paddingCellCount
        guard actualIndex >= 0,
              let assetID = dataSourceDriver.assetID(at: IndexPath(item: actualIndex, section: 0)) else {
            hasTriggeredC1 = false
            return
        }

        // 즉시 터치 차단: 투명 뷰로 window 전체를 덮어 스크롤/탭 등 모든 입력 차단
        // 뱃지 등장 → C-1 발동 사이에 사용자가 다른 조작을 할 수 없도록 보장
        // UIView의 기본 hitTest가 터치를 가로채므로 하위 뷰에 이벤트 전달 안 됨
        let blocker = UIView(frame: window.bounds)
        window.addSubview(blocker)

        // 셀을 실제 가시 영역 기준 중앙으로 스크롤
        scrollToCenteredItem(at: indexPath, animated: true)

        // 스크롤 애니메이션 완료 대기 후 코치마크 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self, weak cell, weak blocker] in
            // 터치 차단 해제 (코치마크 오버레이가 대신 차단)
            blocker?.removeFromSuperview()

            guard let self, let cell else {
                self?.hasTriggeredC1 = false
                self?.retriggerForVisibleBadges()
                return
            }

            // 재검증: 셀이 여전히 visible한지
            guard self.collectionView.visibleCells.contains(cell) else {
                self.hasTriggeredC1 = false
                self.retriggerForVisibleBadges()
                return
            }

            // 재검증: 뱃지가 여전히 표시 중인지
            let hasBadge = cell.contentView.subviews.contains(where: { $0 is SimilarGroupBadgeView })
            guard hasBadge else {
                self.hasTriggeredC1 = false
                self.retriggerForVisibleBadges()
                return
            }

            // 재검증: 다른 코치마크가 안 뜨고 있는지
            guard !CoachMarkManager.shared.isShowing else {
                self.hasTriggeredC1 = false
                return
            }

            // 재검증: 그리드가 최상위 화면인지
            guard self.navigationController?.topViewController === self,
                  self.presentedViewController == nil else {
                self.hasTriggeredC1 = false
                return
            }

            self.showSimilarBadgeCoachMark(cell: cell, assetID: assetID)
        }
    }

    // MARK: - Show

    /// C-1 코치마크 표시 (재생 기능에서도 직접 호출)
    /// - Parameters:
    ///   - cell: 뱃지가 표시된 셀
    ///   - assetID: 해당 셀의 assetID (PHChange 안전성용)
    func showSimilarBadgeCoachMark(cell: PhotoCell, assetID: String) {
        // 윈도우 + 셀 프레임 → 윈도우 좌표 변환
        guard let window = view.window,
              let cellFrame = cell.superview?.convert(cell.frame, to: window) else {
            hasTriggeredC1 = false
            return
        }

        // C-1 표시 + onConfirm 콜백 설정
        CoachMarkOverlayView.showSimilarBadge(
            highlightFrame: cellFrame,
            in: window,
            onConfirm: { [weak self] in
                guard let self else { return }

                // C-1 → C-2 전환 중 보호 활성화
                CoachMarkManager.shared.isWaitingForC2 = true
                Logger.coachMark.debug("C1 onConfirm — isWaitingForC2=true, overlay=\(CoachMarkManager.shared.currentOverlay != nil)")

                // C-1 → C-2 안전 타임아웃 (확인 버튼 탭 시점부터 10초)
                // 뷰어 전환(~0.5초) + 버튼 대기(최대 5초) + 여유를 포함한 안전장치
                // C-2 전환 성공 시 ViewerViewController+CoachMarkC에서 cancel하여 무효화
                let timeoutWork = DispatchWorkItem { [weak self] in
                    guard CoachMarkManager.shared.isWaitingForC2 else { return }
                    CoachMarkManager.shared.resetC2State()
                    CoachMarkManager.shared.currentOverlay?.dismiss()
                    self?.hasTriggeredC1 = false
                }
                CoachMarkManager.shared.safetyTimeoutWork = timeoutWork
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: timeoutWork)

                // assetID로 indexPath 재해석 (PHChange 안전성)
                // confirm 시점에 fetchResult가 바뀌었을 수 있으므로 assetID → indexPath 재검색
                let resolvedIndexPath: IndexPath
                if let found = self.dataSourceDriver.indexPath(for: assetID) {
                    // padding 보정 (dataSourceDriver는 padding 미포함 indexPath 반환)
                    resolvedIndexPath = IndexPath(item: found.item + self.paddingCellCount, section: found.section)
                } else {
                    // assetID를 못 찾으면 3초 타임아웃이 처리 (여기서는 원래 셀 위치 사용)
                    if let currentIP = self.collectionView.indexPath(for: cell) {
                        resolvedIndexPath = currentIP
                    } else {
                        // 셀도 없으면 실패 → 타임아웃이 정리
                        return
                    }
                }

                // 자동 네비게이션 → 뷰어
                self.navigateToViewerForCoachMark(at: resolvedIndexPath)
            }
        )
    }

    // MARK: - Retrigger

    /// hasTriggeredC1 리셋 후 visible 뱃지 셀 재스캔
    /// 타이밍 문제 해결: Badge A가 락을 잡고 1초 타이머 진행 중에 Badge B가 등장하면,
    /// Badge B의 showBadge 호출은 이미 완료되어 재호출되지 않음.
    /// Badge A 재검증 실패 → hasTriggeredC1 = false 리셋 시,
    /// 현재 visible한 뱃지 셀 중 zone 안에 있는 첫 셀로 재트리거 시도
    private func retriggerForVisibleBadges() {
        // hasTriggeredC1이 이미 true면 중복 방지 (다른 경로에서 이미 트리거됨)
        guard !hasTriggeredC1 else { return }

        // 현재 visible한 셀 중 SimilarGroupBadgeView가 있는 셀 수집
        for cell in collectionView.visibleCells {
            guard let photoCell = cell as? PhotoCell else { continue }
            let hasBadge = photoCell.contentView.subviews.contains(where: { $0 is SimilarGroupBadgeView })
            guard hasBadge else { continue }

            // triggerCoachMarkCIfNeeded에서 zone 검증 + 모든 가드를 다시 수행하므로
            // 여기서는 뱃지가 있는 셀만 넘겨주면 됨
            triggerCoachMarkCIfNeeded(for: photoCell)

            // hasTriggeredC1이 true로 설정되면 (트리거 성공) 더 이상 스캔 불필요
            if hasTriggeredC1 { break }
        }
    }

    // MARK: - Navigate

    /// C-1 자동 네비게이션: 뷰어로 이동
    /// collectionView(_:didSelectItemAt:) 직접 호출
    /// 안전성 확인 완료:
    /// - isSelectMode: C-1 가드에서 !isSelectMode 체크 → false 보장
    /// - padding: collectionView.indexPath(for:)로 얻은 값은 padding 포함 → 통과
    /// - fetchResult: 뱃지가 표시되려면 분석 완료 필수 → non-nil 보장
    private func navigateToViewerForCoachMark(at indexPath: IndexPath) {
        collectionView(collectionView, didSelectItemAt: indexPath)
    }

    // MARK: - C Intercept: Associated Properties (Phase 2)

    /// 사전 분석 상태 변경 콜백 (로딩 UI에서 그룹 발견/완료 감지용)
    /// bridge Task 완료 또는 0건 완료 시 호출됨
    var onCPreScanStateChanged: (() -> Void)? {
        get { objc_getAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.onStateChanged) as? (() -> Void) }
        set { objc_setAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.onStateChanged, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 로딩 UI 뷰 (5초 타임아웃 대기 중)
    private var cPreScanLoadingView: UIView? {
        get { objc_getAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.loadingView) as? UIView }
        set { objc_setAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.loadingView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 로딩 타임아웃 DispatchWorkItem (취소 가능)
    private var cPreScanLoadingTimeout: DispatchWorkItem? {
        get { objc_getAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.loadingTimeout) as? DispatchWorkItem }
        set { objc_setAssociatedObject(self, &CoachMarkCPreScanAssociatedKeys.loadingTimeout, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - C Intercept: Enable / Disable

    /// C 간편정리 버튼 인터셉트 활성화
    /// E-1 완료 + C 미완료 시 viewDidAppear에서 호출
    func enableCCleanupButtonIntercept() {
        // 조건 체크: E-1 완료 + C 미완료
        guard CoachMarkType.firstDeleteGuide.hasBeenShown,
              !CoachMarkType.similarPhoto.hasBeenShown else { return }

        if #available(iOS 26.0, *) {
            // iOS 26+: 간편정리 버튼(items[1])에만 primaryAction 설정
            // items[0]=전체메뉴는 통과
            guard let items = navigationItem.rightBarButtonItems, items.count >= 2 else { return }
            items[1].primaryAction = UIAction { [weak self] _ in
                self?.handleCleanupInterceptForC()
            }
        } else {
            // iOS 16~25: FloatingTitleBar의 cleanupButtonInterceptor 설정
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay else { return }
            overlay.titleBar.cleanupButtonInterceptor = { [weak self] in
                guard let self else { return false }
                self.handleCleanupInterceptForC()
                return true
            }
        }

        Logger.coachMark.debug("C 인터셉트: 활성화")
    }

    /// C 간편정리 버튼 인터셉트 해제
    func disableCCleanupButtonIntercept() {
        if #available(iOS 26.0, *) {
            // iOS 26+: 간편정리 버튼의 primaryAction 제거
            guard let items = navigationItem.rightBarButtonItems, items.count >= 2 else { return }
            items[1].primaryAction = nil
        } else {
            // iOS 16~25: FloatingTitleBar의 cleanupButtonInterceptor 제거
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay else { return }
            overlay.titleBar.cleanupButtonInterceptor = nil
        }

        Logger.coachMark.debug("C 인터셉트: 해제")
    }

    // MARK: - C Intercept: Handler

    /// 간편정리 버튼 인터셉트 처리 — 사전 분석 상태에 따라 분기
    private func handleCleanupInterceptForC() {
        // Case 1: 사전 분석 완료 + 유사사진 있음 → 뱃지 셀로 스크롤 + C 시작
        if let foundID = Self.cPreScanFoundAssetID {
            Logger.coachMark.debug("C 인터셉트: 유사사진 있음 → 자동 스크롤")
            scrollToBadgeCellAndTriggerC(assetID: foundID)
            return
        }

        // Case 2: 사전 분석 완료 + 0건 → 메뉴 정상 진행
        if Self.cPreScanIsComplete {
            Logger.coachMark.debug("C 인터셉트: 유사사진 없음 → 메뉴 정상 진행")
            disableCCleanupButtonIntercept()
            cleanupButtonTapped()
            return
        }

        // Case 3: 분석 진행 중 → 로딩 표시 (5초 타임아웃)
        Logger.coachMark.debug("C 인터셉트: 분석 중 → 로딩 표시")
        showCPreScanLoading()
    }

    // MARK: - C Intercept: Auto Scroll + C-1 Trigger

    /// 사전 분석으로 발견한 뱃지 셀로 자동 스크롤 후 C-1 트리거
    /// - Parameter assetID: 대표 assetID (사전 분석에서 발견)
    private func scrollToBadgeCellAndTriggerC(assetID: String) {
        // assetID → indexPath 조회
        guard let dataIndexPath = dataSourceDriver.indexPath(for: assetID) else {
            // assetID를 못 찾으면 (삭제됨 등) 메뉴 정상 진행
            Logger.coachMark.debug("C 자동스크롤: assetID 못 찾음 → 메뉴 정상 진행")
            disableCCleanupButtonIntercept()
            cleanupButtonTapped()
            return
        }

        // padding 보정
        let indexPath = IndexPath(item: dataIndexPath.item + paddingCellCount, section: dataIndexPath.section)

        // 셀을 중앙으로 스크롤
        scrollToCenteredItem(at: indexPath, animated: true)

        // 스크롤 완료 후 C-1 직접 표시
        // triggerCoachMarkCIfNeeded는 뱃지 재검증(비동기 타이밍 문제)이 있으므로
        // 자동 스크롤 경로에서는 showSimilarBadgeCoachMark를 직접 호출
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }

            guard let cell = self.collectionView.cellForItem(at: indexPath) as? PhotoCell else {
                Logger.coachMark.debug("C 자동스크롤: 셀 없음 → 메뉴 정상 진행")
                self.disableCCleanupButtonIntercept()
                self.cleanupButtonTapped()
                return
            }

            // 뱃지 강제 표시 (시각적 일관성)
            self.showBadge(on: cell)

            // C-1 중복 방지 플래그
            self.hasTriggeredC1 = true

            // C-1 코치마크 직접 표시 (뱃지 재검증 우회)
            self.showSimilarBadgeCoachMark(cell: cell, assetID: assetID)
        }
    }

    // MARK: - C Intercept: Loading UI

    /// "비슷한 사진을 찾고 있어요" 로딩 UI 표시 (5초 타임아웃)
    private func showCPreScanLoading() {
        guard let window = view.window else { return }

        // 이미 로딩 중이면 무시
        guard cPreScanLoadingView == nil else { return }

        // 반투명 배경
        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.alpha = 0

        // 중앙 컨테이너 (흰색 둥근 카드)
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(container)

        // ActivityIndicator
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)

        // 안내 텍스트
        let label = UILabel()
        label.text = "비슷한 사진을 찾고 있어요"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),

            spinner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
        ])

        window.addSubview(overlay)
        cPreScanLoadingView = overlay

        // 페이드인
        UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }

        // 사전 분석 상태 변경 콜백 등��
        onCPreScanStateChanged = { [weak self] in
            guard let self else { return }
            self.dismissCPreScanLoading()

            if let foundID = Self.cPreScanFoundAssetID {
                // 그룹 발견 → 자동 스크롤 + C 시작
                self.scrollToBadgeCellAndTriggerC(assetID: foundID)
            } else {
                // 0건 → 메뉴 정상 진행
                self.disableCCleanupButtonIntercept()
                self.cleanupButtonTapped()
            }
        }

        // 5초 타임아웃
        let timeout = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Logger.coachMark.debug("C 로딩: 5초 타임아웃 → 메뉴 정상 진행")
            self.onCPreScanStateChanged = nil
            self.dismissCPreScanLoading()
            self.cleanupButtonTapped()
        }
        cPreScanLoadingTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: timeout)
    }

    /// 로딩 UI 해제
    private func dismissCPreScanLoading() {
        // 타임아웃 취소
        cPreScanLoadingTimeout?.cancel()
        cPreScanLoadingTimeout = nil

        // 페이드아웃 + 제거
        if let overlay = cPreScanLoadingView {
            UIView.animate(withDuration: 0.2, animations: {
                overlay.alpha = 0
            }, completion: { _ in
                overlay.removeFromSuperview()
            })
            cPreScanLoadingView = nil
        }
    }

    // MARK: - C Cleanup Highlight (Phase 3)

    /// 그리드 복귀 후 간편정리 하이라이트 대기 체크
    /// iOS 26+: transition completion에서, iOS 16~25: viewerDidClose()에서 호출
    func showCleanupHighlightIfPending() {
        guard CoachMarkManager.shared.pendingCleanupHighlight else { return }
        CoachMarkManager.shared.pendingCleanupHighlight = false
        CoachMarkManager.shared.isAutoPopForC = false

        // 약간의 딜레이 후 하이라이트 표시 (화면 전환 안정화)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showCleanupButtonHighlight()
        }
    }

    /// 간편정리 버튼 하이라이트 오버레이 표시
    /// "간편정리 메뉴에서 더욱 편리하게 자동 탐색이 가능해요"
    private func showCleanupButtonHighlight() {
        guard let window = view.window else { return }

        let cleanupFrame = getCleanupButtonFrame(in: window)

        CoachMarkOverlayView.showCleanupGuide(
            highlightFrame: cleanupFrame,
            in: window,
            onConfirm: { [weak self] in
                // C 인터셉트 해제
                self?.disableCCleanupButtonIntercept()

                // C 완료 → D 사전 스캔 시작 + D 트리거 체크
                self?.startCoachMarkDPreScanIfNeeded()
                self?.startCoachMarkDTimerIfNeeded()
            }
        )
    }
}
