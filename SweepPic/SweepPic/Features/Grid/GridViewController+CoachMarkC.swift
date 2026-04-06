//
//  GridViewController+CoachMarkC.swift
//  SweepPic
//
//  Created by Claude Code on 2026-02-17.
//
//  코치마크 C-1: 유사사진 뱃지 셀 하이라이트
//  - showBadge(on:count:) 호출 시 triggerCoachMarkCIfNeeded(for:) 진입
//  - 1초 딜레이 후 재검증 → 코치마크 표시
//  - [확인] + 탭 모션 후 자동으로 뷰어 네비게이션
//  - 중복 방지: hasTriggeredC1 associated object 플래그
//
//  트리거: showBadge → triggerCoachMarkCIfNeeded → 1초 딜레이 → showSimilarBadgeCoachMark
//  네비게이션: navigateToViewerForCoachMark → collectionView(_:didSelectItemAt:) 직접 호출

import UIKit
import ObjectiveC
import AppCore
import OSLog

// MARK: - Associated Keys

/// C-1 extension stored property를 위한 키
private enum CoachMarkCAssociatedKeys {
    static var hasTriggeredC1: UInt8 = 0
}

// MARK: - Coach Mark C-1: Similar Photo Badge

extension GridViewController {

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

    // MARK: - ═══════════════════════════════════════════
    // MARK: Phase 1: C 사전 분석
    // MARK: - ═══════════════════════════════════════════

    // MARK: - UserDefaults Keys (C 사전분석)

    /// C 사전분석 완료 여부
    private static let cPreScanIsCompleteKey = "CoachMarkCPreScan.isComplete"
    /// C 사전분석에서 발견된 대표 assetID (nil이면 0건)
    private static let cPreScanFoundAssetIDKey = "CoachMarkCPreScan.foundAssetID"

    /// C 사전분석 완료 + 0건 여부 (D 트리거 조건용)
    static var cPreScanCompleteWithNoGroups: Bool {
        let isComplete = UserDefaults.standard.bool(forKey: cPreScanIsCompleteKey)
        let foundID = UserDefaults.standard.string(forKey: cPreScanFoundAssetIDKey)
        return isComplete && foundID == nil
    }

    /// C 사전분석 결과 assetID (있으면 유사사진 그룹 발견됨)
    private static var cPreScanFoundAssetID: String? {
        UserDefaults.standard.string(forKey: cPreScanFoundAssetIDKey)
    }

    /// C 사전분석 완료 여부
    private static var cPreScanIsComplete: Bool {
        UserDefaults.standard.bool(forKey: cPreScanIsCompleteKey)
    }

    // MARK: - C 사전분석 실행

    /// C 사전분석 시작 (viewDidAppear에서 호출)
    /// FaceScanService를 사용하여 유사사진 1그룹을 백그라운드에서 찾음
    func startCoachMarkCPreScanIfNeeded() {
        // C 이미 표시됨 → 불필요
        guard !CoachMarkType.similarPhoto.hasBeenShown else { return }

        // A, E-1 미완료 → 아직 C 차례 아님
        guard CoachMarkType.gridSwipeDelete.hasBeenShown,
              CoachMarkType.firstDeleteGuide.hasBeenShown else { return }

        // 이전 분석 완료 → 재분석 불필요
        guard !Self.cPreScanIsComplete else { return }

        // fetchResult 필요
        guard let fetchResult = dataSourceDriver.fetchResult else { return }

        // 이미 실행 중이면 스킵
        guard cPreScanService == nil else { return }

        Logger.coachMark.debug("C 사전분석 시작")

        // FaceScanService 인스턴스 생성 (격리 캐시)
        let cache = FaceScanCache()
        let service = FaceScanService(cache: cache)
        service.skipSessionSave = true  // 사용자 세션 오염 방지
        cPreScanService = service

        Task(priority: .utility) { [weak self] in
            do {
                try await service.analyze(
                    method: .fromLatest,
                    fetchResult: fetchResult,
                    onGroupFound: { [weak self] group in
                        // 메인 스레드 — 1그룹 발견 즉시 처리
                        guard let self else { return }
                        let assetID = group.memberAssetIDs.first ?? ""

                        Logger.coachMark.debug("C 사전분석: 그룹 발견 (\(group.memberAssetIDs.count)장), 대표=\(assetID)")

                        // SimilarityCache.shared에 그룹 반영 (뱃지 표시용)
                        Task {
                            await SimilarityCache.shared.addGroupIfValid(
                                members: group.memberAssetIDs,
                                validSlots: group.validPersonIndices,
                                photoFaces: [:]
                            )

                            // FaceScanCache에서 얼굴 데이터도 복사 (FaceComparisonVC용)
                            for memberID in group.memberAssetIDs {
                                let faces = await cache.getFaces(for: memberID)
                                await SimilarityCache.shared.setFaces(faces, for: memberID)
                            }

                            // UserDefaults 저장
                            await MainActor.run {
                                UserDefaults.standard.set(true, forKey: Self.cPreScanIsCompleteKey)
                                UserDefaults.standard.set(assetID, forKey: Self.cPreScanFoundAssetIDKey)

                                // 뱃지 갱신
                                self.updateVisibleCellBorders()

                                // 로딩 대기 중이면 알림
                                self.onCPreScanStateChanged?()
                            }
                        }

                        // 1그룹 발견 → 나머지 분석 취소
                        service.cancel()
                    },
                    onProgress: { _ in
                        // 진행률은 무시 (UI 표시 불필요)
                    }
                )

                // 자연 종료 (0건 완료)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if Self.cPreScanFoundAssetID == nil {
                        // 0건 완료 마킹
                        UserDefaults.standard.set(true, forKey: Self.cPreScanIsCompleteKey)
                        Logger.coachMark.debug("C 사전분석 완료: 0건")
                    }
                    self.onCPreScanStateChanged?()
                    self.cPreScanService = nil
                }
            } catch is CancellationError {
                // cancel()에 의한 정상 종료 (1그룹 발견 후)
                await MainActor.run { [weak self] in
                    self?.cPreScanService = nil
                    Logger.coachMark.debug("C 사전분석: 1그룹 발견 후 정상 취소")
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.cPreScanService = nil
                    Logger.coachMark.error("C 사전분석 오류: \(error)")
                }
            }
        }
    }

    /// C 사전분석 FaceScanService 참조 (실행 중 관리용)
    private var cPreScanService: FaceScanService? {
        get { objc_getAssociatedObject(self, &CoachMarkCPreScanKeys.service) as? FaceScanService }
        set { objc_setAssociatedObject(self, &CoachMarkCPreScanKeys.service, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// C 사전분석 상태 변경 콜백 (로딩 대기 중 그룹 발견/완료 감지용)
    var onCPreScanStateChanged: (() -> Void)? {
        get { objc_getAssociatedObject(self, &CoachMarkCPreScanKeys.stateChanged) as? (() -> Void) }
        set { objc_setAssociatedObject(self, &CoachMarkCPreScanKeys.stateChanged, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }

    // MARK: - ═══════════════════════════════════════════
    // MARK: Phase 2: 간편정리 버튼 C 인터셉트
    // MARK: - ═══════════════════════════════════════════

    /// C 인터셉트 활성화 (viewDidAppear에서 호출)
    func enableCCleanupButtonIntercept() {
        // C 이미 표시됨 → 인터셉트 불필요
        guard !CoachMarkType.similarPhoto.hasBeenShown else { return }

        // A, E-1 완료 후에만
        guard CoachMarkType.gridSwipeDelete.hasBeenShown,
              CoachMarkType.firstDeleteGuide.hasBeenShown else { return }

        if #available(iOS 26.0, *) {
            // iOS 26+: items[1](간편정리)에 primaryAction 설정
            guard let items = navigationItem.rightBarButtonItems, items.count >= 2 else { return }
            items[1].primaryAction = UIAction { [weak self] _ in
                self?.handleCleanupInterceptForC()
            }
            Logger.coachMark.debug("C 인터셉트 활성화 (iOS 26+)")
        } else {
            // iOS 16~25: FloatingTitleBar cleanupButtonInterceptor 설정
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay else { return }
            overlay.titleBar.cleanupButtonInterceptor = { [weak self] in
                self?.handleCleanupInterceptForC()
                return true  // 메뉴 차단
            }
            Logger.coachMark.debug("C 인터셉트 활성화 (iOS 16~25)")
        }
    }

    /// C 인터셉트 비활성화
    func disableCCleanupButtonIntercept() {
        if #available(iOS 26.0, *) {
            guard let items = navigationItem.rightBarButtonItems, items.count >= 2 else { return }
            items[1].primaryAction = nil
        } else {
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay else { return }
            overlay.titleBar.cleanupButtonInterceptor = nil
        }
        Logger.coachMark.debug("C 인터셉트 비활성화")
    }

    /// 간편정리 버튼 C 인터셉트 핸들러
    /// 사전분석 상태에 따라 분기
    private func handleCleanupInterceptForC() {
        // C 이미 표시됨 → 정상 진행
        guard !CoachMarkType.similarPhoto.hasBeenShown else {
            disableCCleanupButtonIntercept()
            cleanupButtonTapped()
            return
        }

        if let foundAssetID = Self.cPreScanFoundAssetID {
            // 유사사진 있음 → 뱃지 셀로 스크롤 후 C 시작
            Logger.coachMark.debug("C 인터셉트: 유사사진 발견, 스크롤 시작 assetID=\(foundAssetID)")
            scrollToBadgeCellAndTriggerC(assetID: foundAssetID)
        } else if Self.cPreScanIsComplete {
            // 0건 완료 → 정상 메뉴 진행
            Logger.coachMark.debug("C 인터셉트: 사전분석 0건, 정상 진행")
            disableCCleanupButtonIntercept()
            cleanupButtonTapped()
        } else {
            // 분석 중 → 로딩 표시 (5초 타임아웃)
            Logger.coachMark.debug("C 인터셉트: 분석 중, 로딩 시작")
            showCPreScanLoading()
        }
    }

    // MARK: - 자동 스크롤 + C 트리거 (버그 #1 대응)

    /// 뱃지 셀로 스크롤 후 C-1을 직접 표시
    /// triggerCoachMarkCIfNeeded 대신 showSimilarBadgeCoachMark를 직접 호출하여
    /// 비동기 updateVisibleCellBorders 타이밍 문제를 회피
    private func scrollToBadgeCellAndTriggerC(assetID: String) {
        // assetID → indexPath 해석
        guard let found = dataSourceDriver.indexPath(for: assetID) else {
            Logger.coachMark.error("C 자동스크롤: assetID 미발견 — 정상 메뉴 진행")
            disableCCleanupButtonIntercept()
            cleanupButtonTapped()
            return
        }

        // padding 보정
        let indexPath = IndexPath(item: found.item + paddingCellCount, section: found.section)

        // 스크롤
        scrollToCenteredItem(at: indexPath, animated: true)

        // 0.6초 대기 후 C-1 직접 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }

            // 셀 확인
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? PhotoCell else {
                Logger.coachMark.error("C 자동스크롤: 셀 없음 — 정상 메뉴 진행")
                self.disableCCleanupButtonIntercept()
                self.cleanupButtonTapped()
                return
            }

            // 다른 코치마크 표시 중이면 스킵
            guard !CoachMarkManager.shared.isShowing else { return }

            // 뱃지 수동 표시 (showBadge가 아직 호출 안 됐을 수 있음)
            self.showBadge(on: cell)

            // 중복 방지 플래그 설정
            self.hasTriggeredC1 = true

            // C-1 직접 표시 (triggerCoachMarkCIfNeeded 우회)
            self.showSimilarBadgeCoachMark(cell: cell, assetID: assetID)
        }
    }

    // MARK: - 로딩 표시 (분석 중 대기)

    /// "비슷한 사진을 찾고 있어요" 로딩 표시
    /// 5초 타임아웃 또는 그룹 발견 시 자동 해제
    private func showCPreScanLoading() {
        // 로딩 뷰 생성 (간단한 UIActivityIndicator + 텍스트)
        guard let window = view.window else { return }

        let loadingView = UIView(frame: window.bounds)
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        loadingView.tag = 99877  // 식별용

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()

        let label = UILabel()
        label.text = "비슷한 사진을 찾고 있어요"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)

        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(label)
        loadingView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),
        ])

        window.addSubview(loadingView)

        // 5초 타임아웃
        let timeoutWork = DispatchWorkItem { [weak self] in
            self?.dismissCPreScanLoading()
            Logger.coachMark.debug("C 로딩: 타임아웃 — 정상 메뉴 진행")
            self?.disableCCleanupButtonIntercept()
            self?.cleanupButtonTapped()
        }
        cPreScanLoadingTimeout = timeoutWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: timeoutWork)

        // 그룹 발견/완료 콜백
        onCPreScanStateChanged = { [weak self] in
            guard let self else { return }
            self.cPreScanLoadingTimeout?.cancel()
            self.cPreScanLoadingTimeout = nil
            self.dismissCPreScanLoading()

            if let foundAssetID = Self.cPreScanFoundAssetID {
                // 유사사진 발견 → 스크롤 후 C 시작
                self.scrollToBadgeCellAndTriggerC(assetID: foundAssetID)
            } else {
                // 0건 완료 → 정상 메뉴 진행
                self.disableCCleanupButtonIntercept()
                self.cleanupButtonTapped()
            }
            self.onCPreScanStateChanged = nil
        }
    }

    /// 로딩 뷰 제거
    private func dismissCPreScanLoading() {
        view.window?.viewWithTag(99877)?.removeFromSuperview()
    }

    /// 로딩 타임아웃 WorkItem (취소용)
    private var cPreScanLoadingTimeout: DispatchWorkItem? {
        get { objc_getAssociatedObject(self, &CoachMarkCPreScanKeys.loadingTimeout) as? DispatchWorkItem }
        set { objc_setAssociatedObject(self, &CoachMarkCPreScanKeys.loadingTimeout, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - ═══════════════════════════════════════════
    // MARK: Phase 3: 간편정리 버튼 하이라이트
    // MARK: - ═══════════════════════════════════════════

    /// 그리드 복귀 시 간편정리 하이라이트 표시 (viewerDidClose/transitionCoordinator에서 호출)
    func showCleanupHighlightIfPending() {
        guard CoachMarkManager.shared.pendingCleanupHighlight else { return }

        // 플래그 리셋
        CoachMarkManager.shared.isAutoPopForC = false
        CoachMarkManager.shared.pendingCleanupHighlight = false

        // 0.3초 딜레이 (전환 애니메이션 완료 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showCleanupButtonHighlight()
        }
    }

    /// 간편정리 버튼 하이라이트 코치마크 표시
    private func showCleanupButtonHighlight() {
        guard let window = view.window else { return }
        guard let cleanupFrame = getCleanupButtonFrame(in: window) else {
            Logger.coachMark.error("C 하이라이트: 간편정리 버튼 프레임 없음")
            return
        }

        Logger.coachMark.debug("C 하이라이트: 간편정리 버튼 표시")

        CoachMarkOverlayView.showCleanupGuide(
            highlightFrame: cleanupFrame,
            in: window,
            onConfirm: { [weak self] in
                guard let self else { return }
                // 인터셉트 해제
                self.disableCCleanupButtonIntercept()
                // D 사전 스캔 시작 (D 표시는 나중에)
                self.startCoachMarkDPreScanIfNeeded()
            }
        )
    }

    // MARK: - Debug Reset

    #if DEBUG
    /// C 사전분석 리셋 (테스트용)
    func debugResetCPreScan() {
        UserDefaults.standard.removeObject(forKey: Self.cPreScanIsCompleteKey)
        UserDefaults.standard.removeObject(forKey: Self.cPreScanFoundAssetIDKey)
        cPreScanService?.cancel()
        cPreScanService = nil
        Logger.coachMark.debug("C 사전분석 리셋 완료")
    }
    #endif
}

// MARK: - Associated Keys (C 사전분석)

private enum CoachMarkCPreScanKeys {
    static var service: UInt8 = 0
    static var stateChanged: UInt8 = 0
    static var loadingTimeout: UInt8 = 0
}
