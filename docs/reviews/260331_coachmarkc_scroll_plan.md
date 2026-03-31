# CoachMark C 스크롤 센터링 수정 계획

## 목표
코치마크 C-1 트리거 시 대상 셀이 화면의 **실제 가시 영역** 기준으로 정확히 수직 중앙에 오도록 스크롤 수정

## 문제 원인
`UICollectionView.scrollToItem(at:at:.centeredVertically)` 가 `contentInset`을 정확히 반영하지 못함.

- `BaseGridViewController.swift:119` — `contentInsetAdjustmentBehavior = .never` (iOS 16~25)
- `GridViewController.swift:271` — `contentInsetAdjustmentBehavior = .automatic` (iOS 26+)
- `GridViewController.swift:582-590` — 수동 contentInset 설정 (top: ~126pt, bottom: ~96pt)

`.centeredVertically`는 collectionView.bounds 기준으로 중앙을 계산하는데, 실제 가시 영역은 contentInset으로 줄어든 영역이므로 약 15pt 위쪽으로 치우침.

## 수정 대상 (2개 파일)

### 1. GridViewController+CoachMarkC.swift:121

**Before:**
```swift
collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
```

**After:**
```swift
if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
    let cellCenterY = attributes.frame.midY
    let insetTop = collectionView.adjustedContentInset.top
    let insetBottom = collectionView.adjustedContentInset.bottom
    let visibleHeight = collectionView.bounds.height - insetTop - insetBottom
    let targetOffsetY = cellCenterY - insetTop - visibleHeight / 2

    let minOffset = -insetTop
    let maxOffset = max(minOffset, collectionView.contentSize.height - collectionView.bounds.height + insetBottom)
    let clampedY = max(minOffset, min(targetOffsetY, maxOffset))

    collectionView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: true)
}
```

### 2. GridViewController+CoachMarkReplay.swift:172

동일 패턴 적용 (scrollToItem → 수동 offset)

## 수학적 검증

UIScrollView 좌표계에서 사용자 가시 영역(content 좌표):
- top = contentOffset.y + adjustedContentInset.top
- bottom = contentOffset.y + bounds.height - adjustedContentInset.bottom
- center = contentOffset.y + adjustedContentInset.top + visibleHeight / 2

셀 중앙을 가시 영역 중앙에 놓으려면:
```
cellCenterY = contentOffset.y + insetTop + visibleHeight / 2
∴ contentOffset.y = cellCenterY - insetTop - visibleHeight / 2
```

## adjustedContentInset 사용 이유

| iOS 버전 | behavior | contentInset.top | adjustedContentInset.top |
|---------|----------|-----------------|------------------------|
| 16~25 | .never | ~126pt (수동) | ~126pt (동일) |
| 26+ | .automatic | 16pt (수동) | 16pt + safeArea (합산) |

iOS 26+에서 `contentInset`만 쓰면 safeArea가 누락되므로, 양쪽 모두 정확한 `adjustedContentInset` 사용.

## maxOffset 안전 가드

콘텐츠가 화면보다 작을 때(사진 수 적을 때):
```swift
// contentSize.height < bounds.height → maxOffset이 음수 가능
let maxOffset = max(minOffset, contentSize.height - bounds.height + insetBottom)
```

## 변경 영향 범위
- 수정 범위: 각 파일 1줄 → ~10줄
- 타이밍(0.4s/0.5s 대기, 재검증 로직 등) 변경 없음
- 다른 scrollToItem 호출(뷰어 복귀 등)은 animated: false이므로 시각적 영향 없어 이번 범위에서 제외
