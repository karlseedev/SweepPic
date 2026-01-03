# 썸네일 고해상도 전환 개선 계획 (통합)

## 문제 정의

- 스크롤 정지 후 50% → 100% 전환이 "티나게" 보임
- 특히 빠른 스크롤에서 문제 발생

---

## 개선 목표

1. **더 부드럽게**: 전환이 눈에 띄지 않게
2. **더 빠르게**: 100% 도착 시간 단축

---

## 구현 계획

### Phase 1: CrossFade + 디바운스 (즉시 효과)

#### 1-1. CrossFade 애니메이션 추가

**파일**: `PhotoCell.swift` - `refreshImageIfNeeded()`

**현재**:
```swift
if let image = image, !isDegraded {
    self.imageView.image = image
}
```

**변경**:
```swift
if let image = image, !isDegraded {
    // R2 전용 CrossFade
    // - window 체크: 화면에 보이는 셀만
    // - image 체크: 기존 이미지가 있을 때만 애니메이션
    if self.imageView.window != nil && self.imageView.image != nil {
        UIView.transition(
            with: self.imageView,
            duration: 0.15,
            options: .transitionCrossDissolve,
            animations: { self.imageView.image = image },
            completion: nil
        )
    } else {
        self.imageView.image = image
    }
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

#### 1-3. refreshImageIfNeeded 반환값 추가

**파일**: `PhotoCell.swift`

**현재**:
```swift
func refreshImageIfNeeded(asset: PHAsset, targetSize: CGSize)
```

**변경**:
```swift
@discardableResult
func refreshImageIfNeeded(asset: PHAsset, targetSize: CGSize) -> Bool {
    // ...
    guard needsHigherRes else { return false }  // 스킵
    // 이미지 요청 로직...
    return true  // 실제 요청함
}
```

**효과**:
- 실제 업그레이드 요청 수 정확히 카운트
- 시그니처는 기존 유지 (파라미터 추가 없음)

---

### Phase 2: 감속 중 preheat (속도 본격 개선)

#### 2-1. 스크롤 상태 변수 추가

**파일**: `GridViewController.swift`

```swift
/// 스크롤 중 peak velocity (Y축, pt/s)
var peakScrollVelocityY: CGFloat = 0

/// scrollViewWillEndDragging의 velocity (Y축, pt/s)
var lastEndVelocityY: CGFloat = 0

/// velocity 계산용 이전 offset/time
private var lastScrollOffset: CGFloat = 0
private var lastVelocityCalcTime: CFTimeInterval = 0

/// 스크롤 시퀀스 (로그 매칭용)
var scrollSeq: Int = 0

/// 마지막 스크롤 종료 시간 (R2 응답 시간 계산용)
var lastScrollEndTime: CFTimeInterval = 0
```

**Note**: 로그에서 velocity는 `max(peakScrollVelocityY, lastEndVelocityY)`를 사용.
`refreshImageIfNeeded()`는 기존 시그니처 유지 (파라미터 추가 없음).

---

#### 2-2. scrollViewWillEndDragging 구현

**파일**: `GridViewController.swift` (UIScrollViewDelegate)

```swift
func scrollViewWillEndDragging(
    _ scrollView: UIScrollView,
    withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
) {
    // velocity 저장 (로그용)
    let systemVelocity = abs(velocity.y)
    lastEndVelocityY = systemVelocity
    peakScrollVelocityY = max(peakScrollVelocityY, systemVelocity)

    // 스크롤 시퀀스 증가
    scrollSeq += 1

    // [Phase 2] 감속 시작 시점에 100% preheat 선행
    // preheatForDeceleration(targetOffset: targetContentOffset.pointee)
}
```

---

#### 2-3. preheatForDeceleration 구현

**파일**: `GridScroll.swift`

```swift
/// 감속 중 preheat 플래그 (중복 호출 방지)
private var isDecelerationPreheatScheduled = false

/// 감속 중 100% preheat 선행
private func preheatForDeceleration(targetOffset: CGPoint) {
    // 중복 호출 방지
    guard !isDecelerationPreheatScheduled else { return }
    isDecelerationPreheatScheduled = true

    let fullSize = thumbnailSize(forScrolling: false)  // 100%

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

    // ⚠️ Debug 빌드에서만 로그 출력 (Release 미연결테스트에서는 안 보임)
    #if DEBUG
    if FileLogger.logThumbEnabled {
        FileLogger.log("[Preheat:Decel] seq=\(scrollSeq), \(assets.count)개 에셋, targetSize=\(Int(fullSize.width))px")
    }
    #endif

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
```

**효과**: 정지 시점에 이미 100% 캐시가 준비되어 즉시 전환

---

## 로그 수집 계획

### 속도 분류 기준 (2026-01-03 실측 반영)

| 분류 | 조건 | 용도 |
|------|------|------|
| **Slow** | velocity < 10000 pt/s | 짧은 스크롤 |
| **Fast** | velocity > 10000 pt/s | 긴 스크롤 (개선 대상) |

> **Note**: 실측 결과 일반 스크롤도 7000~28000 pt/s 범위. 기존 기준(1500/5000)은 너무 낮음.

---

### 로그 형식

#### Phase 1 로그

```
[R2:Timing] seq=5, velocity=3200pt/s, 디바운스=50ms
[R2] seq=5, visible=24, upgraded=18
[R2:Response] seq=5, sinceEnd=145ms, CrossFade=true
[Thumb:Check] seq=5, t=0.2s, velocity=3200, underSized=10/24
[Thumb:Check] seq=5, t=0.6s, velocity=3200, underSized=2/24
```

#### Phase 2 로그 (추가)

```
[Preheat:Decel] seq=5, 24개 에셋, targetSize=384px
[R2:Response] seq=5, sinceEnd=35ms, CrossFade=true
```

**Note**: `cacheHit` 판단은 현재 구현에 없으므로 로그에서 제외.
Phase 2 적용 후 `sinceEnd` 시간이 단축되면 캐시 히트로 간주.

---

### 로그 구현 코드

#### GridScroll.swift - scrollDidEnd()

```swift
// 디바운스 블록 내
let scrollEndTime = CACurrentMediaTime()
let currentSeq = scrollSeq

FileLogger.log("[R2:Timing] seq=\(currentSeq), velocity=\(Int(lastScrollVelocityY))pt/s, 디바운스=50ms")

var upgradedCount = 0
let visibleCount = collectionView.visibleCells.count

for cell in collectionView.visibleCells {
    // ...
    if photoCell.refreshImageIfNeeded(asset: asset, targetSize: fullSize) {
        upgradedCount += 1
    }
}

FileLogger.log("[R2] seq=\(currentSeq), visible=\(visibleCount), upgraded=\(upgradedCount)")
```

#### GridScroll.swift - Thumb:Check 2회

```swift
// 0.2초 후 첫 번째 체크
DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
    self?.logVisibleCellResolution(seq: currentSeq, timing: "0.2s")
}

// 0.6초 후 두 번째 체크 (수렴 확인)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
    self?.logVisibleCellResolution(seq: currentSeq, timing: "0.6s")
}
```

#### PhotoCell.swift - R2:Response

```swift
// refreshImageIfNeeded 콜백 내
let sinceEnd = (CACurrentMediaTime() - scrollEndTime) * 1000
FileLogger.log("[R2:Response] seq=\(seq), sinceEnd=\(Int(sinceEnd))ms, CrossFade=\(appliedCrossFade)")
```

---

### 측정 방식

| 항목 | 값 |
|------|-----|
| 반복 횟수 | Slow/Fast 각 **5회** |
| 기기 | 동일 기기 고정 |
| 열 수 | 3열 고정 |
| Phase별 | 로그 분리 저장 |

---

## 예상 개선 효과 (2026-01-03 실측 반영)

### Slow 스크롤 (velocity < 10000 pt/s)

| 단계 | underSized @0.2s | underSized @0.6s | 체감 |
|------|-----------------|-----------------|------|
| **Baseline (실측)** | 50~67% (12~14개) | **0** | 괜찮음 |
| Phase 1 | 40~60% | 0 | CrossFade로 부드럽게 |
| Phase 2 | 20~40% | 0 | 더 빠르게 |

**→ Slow는 이미 @0.6s에서 완료. CrossFade로 체감 개선**

---

### Fast 스크롤 (velocity > 10000 pt/s)

| 단계 | underSized @0.2s | underSized @0.6s | CrossFade | 체감 |
|------|-----------------|-----------------|-----------|------|
| **Baseline (실측)** | 14~79% (3~19개) | **0** | ❌ | 전환이 티남 |
| **Phase 1 (예상)** | 10~70% | 0 | ✅ | 부드러움 |
| **Phase 2 (예상)** | **5~30%** | 0 | ✅ | 빠르고 부드러움 |

**→ @0.6s는 이미 0. Phase 1은 시각적 개선, Phase 2는 @0.2s 개선**

---

## 핵심 측정 지표 (Fast 기준)

| 지표 | Baseline (실측) | Phase 1 목표 | Phase 2 목표 |
|------|----------------|-------------|-------------|
| 디바운스 | 100ms | **50ms** | 50ms |
| underSized @0.2s | 14~79% | 10~70% | **5~30%** |
| underSized @0.6s | **0** ✅ | 0 | 0 |
| CrossFade 적용 | ❌ | ✅ | ✅ |

> **핵심 인사이트**: 기존 예상(@0.6s에서 5~10개 남음)과 달리, 실측에서는 이미 @0.6s=0 달성.
> Phase 1/2의 목표는 **@0.2s 시점의 underSized 감소**와 **CrossFade로 시각적 부드러움**.

---

## 구현 순서

| 순서 | 작업 | 파일 | 예상 시간 |
|------|------|------|----------|
| 1 | velocity/scrollSeq 변수 추가 | GridViewController.swift | 2분 |
| 2 | CrossFade 추가 (조건 포함) | PhotoCell.swift | 3분 |
| 3 | refreshImageIfNeeded Bool 반환 | PhotoCell.swift | 2분 |
| 4 | 디바운스 축소 + 로그 추가 | GridScroll.swift | 5분 |
| 5 | Thumb:Check 2회 구현 | GridScroll.swift | 3분 |
| 6 | 빌드 & 테스트 (Slow/Fast 각 5회) | - | 15분 |
| 7 | **Phase 1 커밋** | - | 1분 |
| 8 | scrollViewWillEndDragging 구현 | GridScroll.swift | 5분 |
| 9 | preheatForDeceleration 구현 | GridScroll.swift | 10분 |
| 10 | 빌드 & 테스트 (Slow/Fast 각 5회) | - | 15분 |
| 11 | **Phase 2 커밋** | - | 1분 |

---

## 참고

- Gate2 spike test: R1+R2 복구 로직 (`test/gate2-pipeline-test.md`)
- 현재 R2 구현: `GridScroll.swift` (line 126-157)
- 현재 preheat: `preheatAfterScrollStop()` (line 163-193)
- 속도 분류 기준: 실측 반영 (<10000, >10000)

---

## 피드백 반영 내역

| 피드백 | 수정 내용 |
|--------|----------|
| scrollSeq/scrollEndTime 스코프 | `lastScrollEndTime` 변수 추가 |
| velocity 단위 | `*1000` 제거 (UIScrollView velocity는 이미 pt/s) |
| cacheHit 로그 | 제거 (판단 로직 없음, sinceEnd 시간으로 간접 판단) |
| preheat 플래그 리셋 | 타이머 기반 해제 (0.3초 후) 추가 |
| 변수명 불일치 (GPT 피드백) | `lastScrollVelocityY` → `peakScrollVelocityY` + `lastEndVelocityY` |
| 파일 위치 불일치 (GPT 피드백) | `scrollViewWillEndDragging` 파일: GridScroll → GridViewController |
| 시그니처 불일치 (GPT 피드백) | `refreshImageIfNeeded` 파라미터 추가 제거 (기존 유지) |
| 속도 분류 기준 (GPT 피드백) | <1500/>5000 → <10000/>10000 (실측 반영) |
| Preheat:Decel 로그 (GPT 피드백) | Debug에서만 출력됨 명시 |
