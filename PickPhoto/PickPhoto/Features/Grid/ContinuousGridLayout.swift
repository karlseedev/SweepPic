// ContinuousGridLayout.swift
// virtualColumns 기반 연속 그리드 레이아웃
//
// 핀치줌 시 부드러운 열 수 전환을 위한 커스텀 레이아웃
// - virtualColumns: CGFloat (1.0 ~ 5.0 범위의 연속값)
// - effectiveColumns: Int (실제 렌더링에 사용, ceil(virtualColumns))
// - frozenItemCount: 핀치 중 고정된 아이템 수 (numberOfItems 캐시 문제 방지)

import UIKit

/// virtualColumns 기반 연속 그리드 레이아웃
/// 핀치줌 시 부드러운 셀 크기 전환 지원
class ContinuousGridLayout: UICollectionViewLayout {

    // MARK: - Constants

    /// 셀 간격 (FR-001: 2pt)
    static let spacing: CGFloat = 2

    // MARK: - Properties

    /// 가상 열 수 (연속값, 1.0 ~ 5.0)
    /// - 핀치 중: 실수값으로 부드럽게 변화
    /// - 스냅 완료: 정수값 (1, 3, 5)
    var virtualColumns: CGFloat = 3.0 {
        didSet {
            // 값 변경 시 레이아웃 무효화는 외부에서 명시적으로 호출
            // invalidateLayout()을 여기서 호출하면 매 프레임 중복 호출됨
        }
    }

    /// 패딩 셀 개수 (상단 빈 셀)
    /// - 핀치 중에는 frozenPaddingCellCount와 동일하게 고정
    /// - 스냅 완료 후에만 업데이트
    var paddingCellCount: Int = 0

    /// 핀치 시작 시 고정된 아이템 수
    /// - collectionView.numberOfItems(inSection:)는 캐시값을 반환하므로
    /// - 핀치 중에는 이 값을 사용하여 레이아웃 계산
    /// - 0이면 collectionView에서 직접 조회
    var frozenItemCount: Int = 0

    // MARK: - Cached Properties

    /// 캐시된 레이아웃 속성 배열
    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []

    /// 캐시된 contentSize
    private var cachedContentSize: CGSize = .zero

    /// 현재 effectiveColumns (히스테리시스 적용)
    private var currentEffectiveColumns: Int = 3

    // MARK: - Computed Properties

    /// 실제 렌더링에 사용하는 열 수 (정수)
    /// - 히스테리시스 적용으로 깜빡임 방지
    var effectiveColumns: Int {
        return currentEffectiveColumns
    }

    /// 현재 아이템 수
    /// - frozenItemCount가 설정되어 있으면 해당 값 사용
    /// - 아니면 collectionView에서 조회
    private var itemCount: Int {
        if frozenItemCount > 0 {
            return frozenItemCount
        }
        return collectionView?.numberOfItems(inSection: 0) ?? 0
    }

    // MARK: - Layout Preparation

    override func prepare() {
        super.prepare()

        guard let collectionView = collectionView else {
            cachedAttributes = []
            cachedContentSize = .zero
            return
        }

        // effectiveColumns 히스테리시스 적용
        currentEffectiveColumns = stabilizedEffectiveColumns(virtualColumns, current: currentEffectiveColumns)

        // 레이아웃 계산
        let bounds = collectionView.bounds
        let spacing = Self.spacing

        // 셀 크기 계산 (virtualColumns 기반)
        let totalSpacing = spacing * (virtualColumns - 1)
        let itemWidth = (bounds.width - totalSpacing) / virtualColumns
        let itemHeight = itemWidth

        // 행/열 매핑은 effectiveColumns 사용
        let columns = currentEffectiveColumns
        let count = itemCount

        // 캐시 초기화
        cachedAttributes = []
        cachedAttributes.reserveCapacity(count)

        // 각 아이템의 레이아웃 속성 계산
        for index in 0..<count {
            let row = index / columns
            let col = index % columns

            let x = CGFloat(col) * (itemWidth + spacing)
            let y = CGFloat(row) * (itemHeight + spacing)

            let indexPath = IndexPath(item: index, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = CGRect(x: x, y: y, width: itemWidth, height: itemHeight)

            cachedAttributes.append(attributes)
        }

        // contentSize 계산
        let rowCount = count > 0 ? Int(ceil(Double(count) / Double(columns))) : 0
        let contentHeight = CGFloat(rowCount) * itemHeight + CGFloat(max(0, rowCount - 1)) * spacing
        cachedContentSize = CGSize(width: bounds.width, height: contentHeight)
    }

    // MARK: - Layout Attributes

    override var collectionViewContentSize: CGSize {
        return cachedContentSize
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // 가시 영역 최적화: rect와 겹치는 속성만 반환
        return cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < cachedAttributes.count else { return nil }
        return cachedAttributes[indexPath.item]
    }

    // MARK: - Invalidation

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // 너비 변경 시에만 무효화 (스크롤은 무시)
        guard let collectionView = collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }

    // MARK: - Histresis

    /// effectiveColumns 히스테리시스 적용
    /// - virtualColumns가 임계값(±0.2)을 넘어야 변경
    /// - 경계에서 깜빡임 방지
    private func stabilizedEffectiveColumns(_ virtualColumns: CGFloat, current: Int) -> Int {
        let hysteresis: CGFloat = 0.2
        let downThreshold = CGFloat(current) - (1.0 - hysteresis)  // current - 0.8
        let upThreshold = CGFloat(current) + (1.0 - hysteresis)    // current + 0.8

        if virtualColumns <= downThreshold {
            return max(1, current - 1)
        }
        if virtualColumns >= upThreshold {
            return min(5, current + 1)
        }
        return current
    }

    // MARK: - Snap to Valid Threshold

    /// virtualColumns를 유효한 기준점(1, 3, 5)으로 스냅
    func snapToColumns(_ columns: GridColumnCount) {
        virtualColumns = CGFloat(columns.rawValue)
        currentEffectiveColumns = columns.rawValue
    }

    // MARK: - Utility

    /// 현재 셀 크기 계산
    func currentCellSize() -> CGSize {
        guard let collectionView = collectionView else { return .zero }

        let spacing = Self.spacing
        let totalSpacing = spacing * (virtualColumns - 1)
        let itemWidth = (collectionView.bounds.width - totalSpacing) / virtualColumns

        return CGSize(width: itemWidth, height: itemWidth)
    }

    /// 주어진 열 수에 대한 셀 크기 계산
    func cellSize(for columns: GridColumnCount) -> CGSize {
        guard let collectionView = collectionView else { return .zero }

        let spacing = Self.spacing
        let columnCount = CGFloat(columns.rawValue)
        let totalSpacing = spacing * (columnCount - 1)
        let itemWidth = (collectionView.bounds.width - totalSpacing) / columnCount

        return CGSize(width: itemWidth, height: itemWidth)
    }

    /// rect 영역 내의 indexPath 배열 반환 (prefetch용)
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        return cachedAttributes
            .filter { $0.frame.intersects(rect) }
            .map { $0.indexPath }
    }
}
