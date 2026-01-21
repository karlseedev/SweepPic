// ContinuousGridLayout.swift
// 연속 열 수(virtualColumns) 기반 커스텀 그리드 레이아웃
//
// 핀치줌/회전 시 점진적인 레이아웃 변화를 위한 커스텀 UICollectionViewLayout
// - virtualColumns: CGFloat로 연속적인 열 수 관리 (예: 3.0 → 2.4 → 1.0)
// - effectiveColumns: ceil(virtualColumns)로 안정적인 셀 배치
// - 셀 개별 이동 애니메이션 없이 invalidateLayout()만으로 부드러운 전환
//
// 참조: docs/260121zoom3.md

import UIKit

/// 연속 열 수 기반 커스텀 그리드 레이아웃
/// 핀치줌 시 virtualColumns가 실수로 변하면서 셀 크기가 연속적으로 변화
final class ContinuousGridLayout: UICollectionViewLayout {

    // MARK: - Constants

    /// 셀 간격 (FR-001: 2pt)
    static let cellSpacing: CGFloat = 2

    /// virtualColumns 최소값 (1열보다 살짝 작게 허용)
    static let minVirtualColumns: CGFloat = 0.8

    /// virtualColumns 최대값 (5열보다 살짝 크게 허용)
    static let maxVirtualColumns: CGFloat = 5.2

    // MARK: - Properties

    /// 연속 열 수 (실수)
    /// 핀치 진행도에 따라 3.0 → 2.4 → 1.0 등으로 연속 변화
    var virtualColumns: CGFloat = 3.0 {
        didSet {
            // 범위 제한
            virtualColumns = min(max(virtualColumns, Self.minVirtualColumns), Self.maxVirtualColumns)

            // effectiveColumns 업데이트 (히스테리시스 적용)
            let newEffective = stabilizedEffectiveColumns(virtualColumns, current: _effectiveColumns)
            if newEffective != _effectiveColumns {
                _effectiveColumns = newEffective
            }
        }
    }

    /// 유효 열 수 (정수) - 셀 배치에 사용
    /// ceil(virtualColumns)에서 히스테리시스 적용
    private var _effectiveColumns: Int = 3

    /// effectiveColumns 읽기 전용 접근자
    var effectiveColumns: Int { _effectiveColumns }

    /// 패딩 셀 개수 (맨 위 행이 꽉 차도록)
    /// 외부에서 설정 (BaseGridViewController에서 계산)
    var paddingCellCount: Int = 0

    /// 명시적 컨테이너 너비 (회전 시 사용)
    /// nil이면 collectionView.bounds.width 사용
    var explicitWidth: CGFloat?

    // MARK: - Layout Cache

    /// 레이아웃 속성 캐시
    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []

    /// 캐시된 contentSize
    private var cachedContentSize: CGSize = .zero

    /// 캐시 유효 여부
    private var isCacheValid: Bool = false

    // MARK: - Computed Properties

    /// 실제 사용할 컨테이너 너비
    private var containerWidth: CGFloat {
        explicitWidth ?? collectionView?.bounds.width ?? 0
    }

    /// 현재 아이템 크기 계산
    var itemSize: CGSize {
        let spacing = Self.cellSpacing
        let totalSpacing = spacing * (virtualColumns - 1)
        let availableWidth = containerWidth - totalSpacing
        let width = max(1, availableWidth / virtualColumns)
        return CGSize(width: width, height: width)
    }

    // MARK: - Layout Overrides

    override func prepare() {
        super.prepare()

        guard !isCacheValid else { return }
        guard let collectionView = collectionView else { return }

        cachedAttributes.removeAll()

        let itemCount = collectionView.numberOfItems(inSection: 0)
        guard itemCount > 0 else {
            cachedContentSize = .zero
            isCacheValid = true
            return
        }

        let spacing = Self.cellSpacing
        let size = itemSize
        let columns = _effectiveColumns

        // 모든 아이템의 속성 계산
        for index in 0..<itemCount {
            let indexPath = IndexPath(item: index, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)

            let row = index / columns
            let col = index % columns

            let x = CGFloat(col) * (size.width + spacing)
            let y = CGFloat(row) * (size.height + spacing)

            attributes.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            cachedAttributes.append(attributes)
        }

        // contentSize 계산
        let rowCount = (itemCount + columns - 1) / columns
        let contentHeight = CGFloat(rowCount) * size.height + CGFloat(max(0, rowCount - 1)) * spacing
        cachedContentSize = CGSize(width: containerWidth, height: contentHeight)

        isCacheValid = true
    }

    override var collectionViewContentSize: CGSize {
        return cachedContentSize
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // 가시 영역과 겹치는 속성만 반환
        return cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < cachedAttributes.count else { return nil }
        return cachedAttributes[indexPath.item]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // 너비가 변경되면 무효화 (회전 등)
        guard let collectionView = collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }

    override func invalidateLayout() {
        super.invalidateLayout()
        isCacheValid = false
    }

    // MARK: - Histresis (안정화)

    /// effectiveColumns 전환 시 히스테리시스 적용
    /// 정수 경계에서 잦은 전환 방지
    /// - Parameters:
    ///   - virtual: 현재 virtualColumns
    ///   - current: 현재 effectiveColumns
    /// - Returns: 새 effectiveColumns (1~5 범위)
    private func stabilizedEffectiveColumns(_ virtual: CGFloat, current: Int) -> Int {
        let hysteresis: CGFloat = 0.2
        let downThreshold = CGFloat(current) - (1.0 - hysteresis)  // current - 0.8
        let upThreshold = CGFloat(current) + (1.0 - hysteresis)    // current + 0.8

        if virtual <= downThreshold {
            return max(1, current - 1)
        }
        if virtual >= upThreshold {
            return min(5, current + 1)
        }
        return current
    }

    // MARK: - Public Methods

    /// virtualColumns를 특정 값으로 즉시 설정 (스냅 완료 시)
    /// - Parameter columns: 목표 GridColumnCount
    func snapToColumns(_ columns: GridColumnCount) {
        virtualColumns = CGFloat(columns.rawValue)
        _effectiveColumns = columns.rawValue
        invalidateLayout()
    }

    /// 현재 virtualColumns에서 가장 가까운 유효 기준점 반환
    /// - Returns: 1, 3, 5 중 하나
    func nearestValidThreshold() -> GridColumnCount {
        let thresholds: [Int] = [1, 3, 5]
        let nearest = thresholds.min(by: { abs($0 - Int(virtualColumns.rounded())) < abs($1 - Int(virtualColumns.rounded())) }) ?? 3
        return GridColumnCount(rawValue: nearest) ?? .three
    }

    /// effectiveColumns를 유효 기준점(1, 3, 5)으로 변환
    /// - Parameter columns: effectiveColumns (1~5)
    /// - Returns: GridColumnCount
    func snapToValidThreshold(_ columns: Int) -> GridColumnCount {
        if columns <= 2 { return .one }
        if columns <= 4 { return .three }
        return .five
    }

    /// 특정 indexPath의 셀 중심 좌표 반환 (앵커 보정용)
    /// - Parameter indexPath: 대상 indexPath
    /// - Returns: 셀 중심 좌표 (content 좌표계)
    func centerForItem(at indexPath: IndexPath) -> CGPoint? {
        guard indexPath.item < cachedAttributes.count else { return nil }
        return cachedAttributes[indexPath.item].center
    }

    /// rect 영역 내의 indexPath 배열 반환 (prefetch용)
    /// - Parameter rect: 대상 영역
    /// - Returns: 해당 영역의 indexPath 배열
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        return cachedAttributes
            .filter { $0.frame.intersects(rect) }
            .map { $0.indexPath }
    }
}
