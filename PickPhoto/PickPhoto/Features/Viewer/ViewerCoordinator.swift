// ViewerCoordinator.swift
// 뷰어 네비게이션 로직 및 데이터 관리
//
// T029: ViewerCoordinator 생성
// - 네비게이션 로직
// - "이전 사진 우선" 규칙 구현 (FR-013)
//
// T032: 줌 전환 애니메이션 구현
// - 그리드 ↔ 뷰어 전환 애니메이션

import UIKit
import Photos
import AppCore

// MARK: - ViewerCoordinatorProtocol

/// 뷰어 코디네이터 프로토콜
/// 뷰어에 필요한 데이터 및 네비게이션 로직 제공
protocol ViewerCoordinatorProtocol: AnyObject {

    /// 전체 사진 수
    var totalCount: Int { get }

    /// 사진 fetch 결과 (유사 사진 분석용)
    var fetchResult: PHFetchResult<PHAsset>? { get }

    /// 인덱스에 해당하는 PHAsset 반환
    /// - Parameter index: 인덱스
    /// - Returns: PHAsset 또는 nil
    func asset(at index: Int) -> PHAsset?

    /// 인덱스에 해당하는 에셋 ID 반환
    /// - Parameter index: 인덱스
    /// - Returns: 에셋 ID 또는 nil
    func assetID(at index: Int) -> String?

    /// 에셋 ID에 해당하는 인덱스 반환
    /// - Parameter assetID: 에셋 ID
    /// - Returns: 인덱스 또는 nil
    func index(for assetID: String) -> Int?

    /// 삭제 후 다음 인덱스 계산
    /// "이전 사진 우선" 규칙 적용 (FR-013)
    /// - Parameter currentIndex: 현재 인덱스
    /// - Returns: 다음 표시할 인덱스
    func nextIndexAfterDelete(currentIndex: Int) -> Int

    /// 특정 사진이 휴지통에 있는지 확인
    /// - Parameter index: 인덱스
    /// - Returns: 휴지통에 있으면 true
    func isTrashed(at index: Int) -> Bool

    /// 삭제/복구 후 필터링 인덱스 갱신
    func refreshFilteredIndices()
}

// MARK: - ViewerCoordinator

/// 뷰어 코디네이터 구현체
/// PHFetchResult 기반으로 데이터 제공 및 네비게이션 로직 관리
/// 뷰어 모드에 따라 일반 사진만 또는 휴지통 사진만 필터링하여 표시
final class ViewerCoordinator: ViewerCoordinatorProtocol {

    // MARK: - Properties

    /// 사진 fetch 결과 (내부 저장용, non-optional)
    private let _fetchResult: PHFetchResult<PHAsset>

    /// 사진 fetch 결과 (프로토콜 요구사항, 유사 사진 분석용으로 외부 접근 허용)
    var fetchResult: PHFetchResult<PHAsset>? { _fetchResult }

    /// 휴지통 스토어
    private let trashStore: TrashStoreProtocol

    /// 뷰어 모드 (일반/휴지통)
    private let viewerMode: ViewerMode

    /// 필터링 인덱스 매핑
    /// - 핵심 목표: 전체 fetchResult를 O(n)으로 스캔하지 않고(라이브러리 큰 경우 1초+ 히치),
    ///   trashedAssetIDs(보통 소수)만 기반으로 매핑을 구성
    private enum IndexMapping {
        /// normal 모드 + trashedIDs 비었음: 0..<count를 따로 만들지 않고 identity로 처리
        case identity(totalOriginal: Int)
        /// normal 모드 + 일부 제외: 원본 인덱스에서 제외할 인덱스만 보관(정렬됨)
        case normal(totalOriginal: Int, excludedOriginalIndices: [Int])
        /// trash 모드: 포함할 원본 인덱스만 보관(정렬됨)
        case trash(originalIndices: [Int])
    }

    private var indexMapping: IndexMapping = .identity(totalOriginal: 0)

    /// 에셋 ID → 필터링된 인덱스 캐시
    private var indexCache: [String: Int] = [:]

    // MARK: - ViewerCoordinatorProtocol

    /// 전체 사진 수 (필터링된 개수)
    var totalCount: Int {
        switch indexMapping {
        case .identity(let totalOriginal):
            return totalOriginal
        case .normal(let totalOriginal, let excluded):
            return max(0, totalOriginal - excluded.count)
        case .trash(let originalIndices):
            return originalIndices.count
        }
    }

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - fetchResult: 사진 fetch 결과
    ///   - trashStore: 휴지통 스토어 (기본값: 공유 인스턴스)
    ///   - viewerMode: 뷰어 모드 (기본값: .normal)
    init(
        fetchResult: PHFetchResult<PHAsset>,
        trashStore: TrashStoreProtocol = TrashStore.shared,
        viewerMode: ViewerMode = .normal
    ) {
        self._fetchResult = fetchResult
        self.trashStore = trashStore
        self.viewerMode = viewerMode

        // 모드에 따라 인덱스 필터링
        rebuildIndexMapping()
    }

    // MARK: - ViewerCoordinatorProtocol Implementation

    /// 인덱스에 해당하는 PHAsset 반환 (필터링된 인덱스 기준)
    func asset(at index: Int) -> PHAsset? {
        guard let originalIndex = originalIndex(forFilteredIndex: index) else { return nil }
        return _fetchResult.object(at: originalIndex)
    }

    /// 인덱스에 해당하는 에셋 ID 반환 (필터링된 인덱스 기준)
    func assetID(at index: Int) -> String? {
        return asset(at: index)?.localIdentifier
    }

    /// 에셋 ID에 해당하는 인덱스 반환 (필터링된 인덱스 기준)
    func index(for assetID: String) -> Int? {
        // 캐시 확인
        if let cachedIndex = indexCache[assetID] {
            // 캐시 유효성 검증
            if cachedIndex < totalCount,
               let asset = asset(at: cachedIndex),
               asset.localIdentifier == assetID {
                return cachedIndex
            }
        }

        // 순차 검색
        for i in 0..<totalCount {
            if let asset = asset(at: i),
               asset.localIdentifier == assetID {
                indexCache[assetID] = i
                return i
            }
        }

        return nil
    }

    /// 삭제 후 다음 인덱스 계산
    /// "이전 사진 우선" 규칙 (FR-013):
    /// - 이전 사진이 있으면 이전 사진으로 이동
    /// - 첫 번째 사진이었으면 다음 사진으로 이동
    /// - 마지막 사진이었으면 뷰어 닫기 (인덱스 -1 반환)
    func nextIndexAfterDelete(currentIndex: Int) -> Int {
        let newTotal = totalCount - 1  // 삭제 후 예상 개수

        // 모든 사진이 삭제되면 -1 반환
        if newTotal <= 0 {
            return -1
        }

        // 이전 사진 우선: 현재 인덱스가 0보다 크면 이전 인덱스로
        if currentIndex > 0 {
            return currentIndex - 1
        }

        // 첫 번째 사진이었으면 현재 인덱스 유지 (다음 사진이 당겨옴)
        // 단, 범위 초과 방지
        return min(currentIndex, newTotal - 1)
    }

    /// 특정 사진이 휴지통에 있는지 확인
    func isTrashed(at index: Int) -> Bool {
        guard let assetID = assetID(at: index) else { return false }
        return trashStore.isTrashed(assetID)
    }

    // MARK: - Index Conversion

    /// 원본 PHFetchResult 인덱스를 필터링된 인덱스로 변환
    /// - Parameter originalIndex: 원본 인덱스
    /// - Returns: 필터링된 인덱스 또는 nil
    func filteredIndex(from originalIndex: Int) -> Int? {
        guard originalIndex >= 0 && originalIndex < _fetchResult.count else { return nil }

        switch indexMapping {
        case .identity:
            return originalIndex

        case .trash(let originals):
            let i = Self.lowerBound(originals, originalIndex)
            return (i < originals.count && originals[i] == originalIndex) ? i : nil

        case .normal(let totalOriginal, let excluded):
            guard totalOriginal == _fetchResult.count else { return nil }
            if Self.containsSorted(excluded, originalIndex) { return nil }
            let excludedBefore = Self.lowerBound(excluded, originalIndex)
            return originalIndex - excludedBefore
        }
    }

    /// 삭제/복구 후 필터링 인덱스 갱신
    func refreshFilteredIndices() {
        rebuildIndexMapping()
        indexCache.removeAll()
    }

    // MARK: - Private Methods

    /// 모드에 따라 인덱스 매핑 구성
    /// - 단일 패스 최적화: PhotoKit 반복 호출 제거, fetchResult 1회 순회
    /// - trashedIDs.contains()는 Set이므로 O(1)
    private func rebuildIndexMapping() {
        let startTime = CACurrentMediaTime()

        let trashedIDs = trashStore.trashedAssetIDs
        let totalOriginal = _fetchResult.count

        // [최적화] .normal 모드에서는 휴지통 사진도 표시 (그리드와 일관성)
        // O(n) 스캔 스킵 - identity 매핑으로 모든 사진 포함
        if viewerMode == .normal {
            indexMapping = .identity(totalOriginal: totalOriginal)
            logRebuildComplete(startTime, totalOriginal, trashedIDs.count)
            return
        }

        // 이하 .trash 모드 전용 로직

        // 휴지통 비어있으면 빠른 경로
        if trashedIDs.isEmpty {
            indexMapping = .trash(originalIndices: [])
            logRebuildComplete(startTime, totalOriginal, trashedIDs.count)
            return
        }

        // ✅ 단일 패스: fetchResult 1회 순회, PhotoKit 추가 호출 없음
        var matchedIndices: [Int] = []
        matchedIndices.reserveCapacity(trashedIDs.count)

        _fetchResult.enumerateObjects { asset, index, _ in
            if trashedIDs.contains(asset.localIdentifier) {
                matchedIndices.append(index)
            }
        }

        // 전부 휴지통이면 identity, 일부만이면 trash 인덱스
        if matchedIndices.count == totalOriginal {
            indexMapping = .identity(totalOriginal: totalOriginal)
        } else {
            indexMapping = .trash(originalIndices: matchedIndices)
        }

        logRebuildComplete(startTime, totalOriginal, trashedIDs.count)
    }

    /// rebuildIndexMapping 완료 로그
    private func logRebuildComplete(_ startTime: CFAbsoluteTime, _ totalOriginal: Int, _ trashedCount: Int) {
        let elapsed = (CACurrentMediaTime() - startTime) * 1000
        print("[ViewerCoordinator] rebuildIndexMapping() 완료: \(String(format: "%.1f", elapsed))ms, Mode: \(viewerMode), totalOriginal: \(totalOriginal), trashedIDs: \(trashedCount)")
    }

    // MARK: - iOS 18+ Zoom Transition Support

    /// 필터링된 인덱스를 원본 인덱스로 변환 (public 접근용)
    /// iOS 18+ zoom transition의 sourceViewProvider에서 외부 접근 필요
    func originalIndex(from filteredIndex: Int) -> Int? {
        return originalIndex(forFilteredIndex: filteredIndex)
    }

    /// 필터링된 인덱스를 원본 인덱스로 변환
    private func originalIndex(forFilteredIndex filteredIndex: Int) -> Int? {
        guard filteredIndex >= 0 else { return nil }

        switch indexMapping {
        case .identity(let totalOriginal):
            guard filteredIndex < totalOriginal else { return nil }
            return filteredIndex

        case .trash(let originals):
            guard filteredIndex < originals.count else { return nil }
            return originals[filteredIndex]

        case .normal(let totalOriginal, let excluded):
            let totalFiltered = max(0, totalOriginal - excluded.count)
            guard filteredIndex < totalFiltered else { return nil }

            // 제외 인덱스만큼 원본 인덱스를 앞으로 이동 (excluded가 보통 소수라 O(m)로 충분)
            var original = filteredIndex
            for ex in excluded {
                if ex <= original {
                    original += 1
                } else {
                    break
                }
            }
            guard original >= 0 && original < totalOriginal else { return nil }
            return original
        }
    }

    // MARK: - Small Helpers

    private static func lowerBound(_ a: [Int], _ x: Int) -> Int {
        var l = 0
        var r = a.count
        while l < r {
            let m = (l + r) / 2
            if a[m] < x {
                l = m + 1
            } else {
                r = m
            }
        }
        return l
    }

    private static func containsSorted(_ a: [Int], _ x: Int) -> Bool {
        let i = lowerBound(a, x)
        return i < a.count && a[i] == x
    }

    private static func dedupSorted(_ a: [Int]) -> [Int] {
        guard !a.isEmpty else { return [] }
        var out: [Int] = []
        out.reserveCapacity(a.count)
        var last = a[0]
        out.append(last)
        for v in a.dropFirst() {
            if v != last {
                out.append(v)
                last = v
            }
        }
        return out
    }
}

// MARK: - ViewerTransitionAnimator (T032)

/// 줌 전환 애니메이터
/// 그리드 셀에서 뷰어로 자연스럽게 확대되는 애니메이션
final class ViewerTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    // MARK: - Properties

    /// 전환 방향
    enum Direction {
        case present  // 그리드 → 뷰어
        case dismiss  // 뷰어 → 그리드
    }

    /// 전환 방향
    private let direction: Direction

    /// 시작 프레임 (그리드 셀 위치)
    private let originFrame: CGRect

    /// 애니메이션 duration (Core Animation 기본값)
    private let duration: TimeInterval = 0.25

    // MARK: - Initialization

    init(direction: Direction, originFrame: CGRect) {
        self.direction = direction
        self.originFrame = originFrame
        super.init()
    }

    // MARK: - UIViewControllerAnimatedTransitioning

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        switch direction {
        case .present:
            animatePresent(using: transitionContext)
        case .dismiss:
            animateDismiss(using: transitionContext)
        }
    }

    // MARK: - Present Animation

    /// 그리드 → 뷰어 전환 애니메이션
    private func animatePresent(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to),
              let toVC = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toVC)

        // 뷰어 뷰 설정
        toView.frame = finalFrame
        toView.alpha = 0
        containerView.addSubview(toView)

        // 스냅샷 생성 (시작 프레임에서)
        let snapshotView = UIView(frame: originFrame)
        snapshotView.backgroundColor = .black
        snapshotView.layer.cornerRadius = 4
        snapshotView.clipsToBounds = true
        containerView.addSubview(snapshotView)

        // 애니메이션
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
            snapshotView.frame = finalFrame
            snapshotView.layer.cornerRadius = 0
            toView.alpha = 1
        } completion: { _ in
            snapshotView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }

    // MARK: - Dismiss Animation

    /// 뷰어 → 그리드 전환 애니메이션
    private func animateDismiss(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView

        // 스냅샷 생성
        let snapshotView = fromView.snapshotView(afterScreenUpdates: false) ?? UIView()
        snapshotView.frame = fromView.frame
        containerView.addSubview(snapshotView)

        fromView.isHidden = true

        // 애니메이션
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
            snapshotView.frame = self.originFrame
            snapshotView.layer.cornerRadius = 4
            snapshotView.alpha = 0.5
        } completion: { _ in
            snapshotView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

// MARK: - ViewerTransitioningDelegate

/// 뷰어 전환 델리게이트
/// 그리드 ↔ 뷰어 줌 전환 애니메이션 관리
final class ViewerTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {

    // MARK: - Properties

    /// 시작/종료 프레임 (그리드 셀 위치)
    var originFrame: CGRect = .zero

    // MARK: - UIViewControllerTransitioningDelegate

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ViewerTransitionAnimator(direction: .present, originFrame: originFrame)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ViewerTransitionAnimator(direction: .dismiss, originFrame: originFrame)
    }
}
