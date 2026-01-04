# 썸네일 고해상도 전환 개선 계획

## 문제 정의

- 스크롤 정지 후 50% → 100% 전환이 "티나게" 보임
- 특히 빠른 스크롤에서 문제 발생

---

## 개선 목표

1. **더 부드럽게**: 전환이 눈에 띄지 않게
2. **더 빠르게**: 100% 도착 시간 단축

---

## 구현 계획

### 1단계: CrossFade + 디바운스 (즉시 효과)

#### 1-1. CrossFade 애니메이션 추가

**파일**: `PhotoCell.swift` (line 1071)

**현재**:
```swift
if let image = image, !isDegraded {
    self.imageView.image = image
}
```

**변경**:
```swift
if let image = image, !isDegraded {
    UIView.transition(
        with: self.imageView,
        duration: 0.15,
        options: .transitionCrossDissolve,
        animations: { self.imageView.image = image },
        completion: nil
    )
}
```

**효과**: 50% → 100% 전환이 부드럽게 페이드

---

#### 1-2. 디바운스 축소

**파일**: `GridScroll.swift` (line 88)

**현재**:
```swift
Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false)
```

**변경**:
```swift
Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false)
```

**효과**: 정지 후 R2 시작까지 50ms 단축

---

### 2단계: 감속 중 preheat (속도 본격 개선)

#### 2-1. scrollViewWillEndDragging 구현

**파일**: `GridScroll.swift`

```swift
extension GridViewController: UIScrollViewDelegate {

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        // 감속 시작 시점에 100% preheat 선행
        preheatForDeceleration(targetOffset: targetContentOffset.pointee)
    }
}
```

---

#### 2-2. preheatForDeceleration 구현

**파일**: `GridScroll.swift`

```swift
/// 감속 중 100% preheat 선행
/// - 정지 예상 위치 기준으로 visible 셀 예측
/// - 해당 범위의 asset들을 100% 크기로 preheat
private func preheatForDeceleration(targetOffset: CGPoint) {
    let fullSize = thumbnailSize(forScrolling: false)  // 100%

    // targetOffset 기준 visible 영역 계산
    let targetRect = CGRect(
        origin: targetOffset,
        size: collectionView.bounds.size
    )

    // 해당 영역의 layoutAttributes 가져오기
    guard let layoutAttributes = collectionView.collectionViewLayout
        .layoutAttributesForElements(in: targetRect) else { return }

    // padding 적용하여 asset indexPaths 변환
    let padding = paddingCellCount
    let assetIndexPaths = layoutAttributes.compactMap { attr -> IndexPath? in
        guard attr.indexPath.item >= padding else { return nil }
        return IndexPath(item: attr.indexPath.item - padding, section: 0)
    }

    // PHAsset 배열 가져오기
    let assets = assetIndexPaths.compactMap { dataSourceDriver.asset(at: $0) }
    guard !assets.isEmpty else { return }

    #if DEBUG
    if FileLogger.logThumbEnabled {
        FileLogger.log("[Preheat:Decel] \(assets.count)개 에셋 preheat, targetSize=\(Int(fullSize.width))px")
    }
    #endif

    // 백그라운드에서 preheat
    DispatchQueue.global(qos: .userInitiated).async {
        ImagePipeline.shared.preheatAssets(assets, targetSize: fullSize)
    }
}
```

**효과**: 정지 시점에 이미 100% 캐시가 준비되어 즉시 전환

---

## 로그 측정 계획

### 테스트 시나리오

| 시나리오 | 속도 | 측정 방법 |
|----------|------|----------|
| **A. 느린 스크롤** | ~1000pt/s | 천천히 스와이프 후 정지 |
| **B. 빠른 스크롤** | ~3000pt/s+ | 빠르게 플릭 후 정지 |

---

### 추가할 로그

#### GridScroll.swift - scrollDidEnd()

```swift
// 스크롤 종료 시 velocity 기록
let velocity = lastScrollVelocity  // 추가 필요
FileLogger.log("[R2:Timing] velocity=\(Int(velocity))pt/s, 디바운스=50ms")
```

#### GridScroll.swift - upgradeVisibleCellsToHighQuality()

```swift
let startTime = CACurrentMediaTime()
// ... 업그레이드 로직 ...
let duration = (CACurrentMediaTime() - startTime) * 1000
FileLogger.log("[R2] \(upgradedCount)개 셀, duration=\(String(format: "%.1f", duration))ms")
```

#### PhotoCell.swift - refreshImageIfNeeded() 콜백

```swift
let requestStartTime = CACurrentMediaTime()  // 요청 시작 시 저장

// 콜백 내:
let responseTime = (CACurrentMediaTime() - requestStartTime) * 1000
FileLogger.log("[R2:Response] \(String(format: "%.1f", responseTime))ms, CrossFade=applied")
```

#### GridScroll.swift - preheatForDeceleration() (2단계)

```swift
FileLogger.log("[Preheat:Decel] \(assets.count)개 에셋, targetSize=\(Int(fullSize.width))px")
```

---

### 로그 출력 형식

```
[R2:Timing] velocity=3200pt/s, 디바운스=50ms
[R2] 24개 셀, duration=2.3ms
[R2:Response] 145.2ms, CrossFade=applied
[Thumb:Check] velocity=3200, underSized=18/24, match=6/24
```

---

## 예상 개선 효과

### 시나리오 A: 느린 스크롤 (~1000pt/s)

| 단계 | underSized | R2 응답시간 | 체감 |
|------|-----------|------------|------|
| 현재 | 0~5 | - | 괜찮음 |
| 1단계 | 0~5 | - | 동일 |
| 2단계 | 0~5 | - | 동일 |

**→ 느린 스크롤은 이미 문제 없음**

---

### 시나리오 B: 빠른 스크롤 (~3000pt/s+)

| 단계 | underSized | R2 응답시간 | CrossFade | 체감 |
|------|-----------|------------|-----------|------|
| **현재** | 15~24 | ~150ms | ❌ | 티남 |
| **1단계** | 15~24 | ~150ms | ✅ | 부드러움 |
| **2단계** | 5~10 | ~30ms | ✅ | 빠르고 부드러움 |

**→ 빠른 스크롤이 개선 대상, 2단계에서 본격 개선**

---

## 핵심 측정 지표 (빠른 스크롤 기준)

| 지표 | 현재 | 1단계 목표 | 2단계 목표 |
|------|------|-----------|-----------|
| 디바운스 | 100ms | **50ms** | 50ms |
| R2 응답시간 (평균) | ~150ms | ~150ms | **<50ms** |
| underSized 초기값 | 15~24 | 15~24 | **<10** |
| Preheat 캐시 히트율 | 0% | 0% | **>70%** |
| CrossFade 적용 | ❌ | ✅ | ✅ |

---

## 구현 순서

| 순서 | 작업 | 파일 | 예상 시간 |
|------|------|------|----------|
| 1 | CrossFade 추가 | PhotoCell.swift | 2분 |
| 2 | 디바운스 축소 | GridScroll.swift | 1분 |
| 3 | 로그 추가 (velocity, timing) | GridScroll.swift | 5분 |
| 4 | 빌드 & 테스트 (느린/빠른 스크롤) | - | 10분 |
| 5 | 1단계 커밋 | - | 1분 |
| 6 | scrollViewWillEndDragging 구현 | GridScroll.swift | 5분 |
| 7 | preheatForDeceleration 구현 | GridScroll.swift | 10분 |
| 8 | 빌드 & 테스트 (느린/빠른 스크롤) | - | 10분 |
| 9 | 2단계 커밋 | - | 1분 |

---

## 참고

- Gate2 spike test: R1+R2 복구 로직 (test/gate2-pipeline-test.md)
- 현재 R2 구현: GridScroll.swift (line 126-157)
- 현재 preheat: preheatAfterScrollStop() (line 163-193)
