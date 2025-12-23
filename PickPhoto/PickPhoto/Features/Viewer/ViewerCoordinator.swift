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

    /// 사진 fetch 결과
    private let fetchResult: PHFetchResult<PHAsset>

    /// 휴지통 스토어
    private let trashStore: TrashStoreProtocol

    /// 뷰어 모드 (일반/휴지통)
    private let viewerMode: ViewerMode

    /// 필터링된 원본 인덱스 배열
    /// - normal 모드: 휴지통에 없는 사진의 인덱스
    /// - trash 모드: 휴지통에 있는 사진의 인덱스
    private var filteredIndices: [Int] = []

    /// 에셋 ID → 필터링된 인덱스 캐시
    private var indexCache: [String: Int] = [:]

    // MARK: - ViewerCoordinatorProtocol

    /// 전체 사진 수 (필터링된 개수)
    var totalCount: Int {
        filteredIndices.count
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
        self.fetchResult = fetchResult
        self.trashStore = trashStore
        self.viewerMode = viewerMode

        // 모드에 따라 인덱스 필터링
        buildFilteredIndices()
    }

    // MARK: - ViewerCoordinatorProtocol Implementation

    /// 인덱스에 해당하는 PHAsset 반환 (필터링된 인덱스 기준)
    func asset(at index: Int) -> PHAsset? {
        guard index >= 0 && index < filteredIndices.count else { return nil }
        let originalIndex = filteredIndices[index]
        return fetchResult.object(at: originalIndex)
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
            if cachedIndex < filteredIndices.count,
               let asset = asset(at: cachedIndex),
               asset.localIdentifier == assetID {
                return cachedIndex
            }
        }

        // 순차 검색
        for i in 0..<filteredIndices.count {
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
        return filteredIndices.firstIndex(of: originalIndex)
    }

    /// 삭제/복구 후 필터링 인덱스 갱신
    func refreshFilteredIndices() {
        buildFilteredIndices()
        indexCache.removeAll()
    }

    // MARK: - Private Methods

    /// 모드에 따라 필터링된 인덱스 배열 생성
    private func buildFilteredIndices() {
        // [Timing] 시작
        let startTime = CACurrentMediaTime()
        print("[ViewerCoordinator] buildFilteredIndices() 시작")

        filteredIndices.removeAll()

        for i in 0..<fetchResult.count {
            let asset = fetchResult.object(at: i)
            let isTrashed = trashStore.isTrashed(asset.localIdentifier)

            switch viewerMode {
            case .normal:
                // 일반 모드: 휴지통에 없는 사진만
                if !isTrashed {
                    filteredIndices.append(i)
                }
            case .trash:
                // 휴지통 모드: 휴지통에 있는 사진만
                if isTrashed {
                    filteredIndices.append(i)
                }
            }
        }

        // [Timing] 완료
        let elapsed = (CACurrentMediaTime() - startTime) * 1000
        print("[ViewerCoordinator] buildFilteredIndices() 완료: \(String(format: "%.1f", elapsed))ms, Mode: \(viewerMode), Count: \(filteredIndices.count)/\(fetchResult.count)")
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
