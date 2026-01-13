# Velocity 기반 가변 품질 구현 계획

## 문제 분석

### 현재 상황
- 스크롤 중 192px (50%) 요청
- 스크롤 정지 후 리로드 없음
- 192px 이미지가 그대로 유지 → 뭉개져 보임

### 이전 시도 (실패)
- `.fastFormat` 사용 → 90px (23%) 반환 → 더 뭉개짐
- 기본 사진 앱보다 훨씬 저품질

### 핵심 인사이트
- 기본 사진 앱: `.opportunistic`으로 저품질→고품질 자동 교체 + preheat로 미리 캐싱
- `.fastFormat`은 visible 셀에서 사용하면 안 됨
- 느린 스크롤은 hitch 0.0ms, 빠른 스크롤에서 hitch 발생

---

## 구현 계획

### Phase 1: 기반 인프라

**1.1 ImagePipeline.swift**
- `ImageQuality.scrolling` 추가
- `scrollingOptions` (.fastFormat) 추가

```swift
public enum ImageQuality {
    case fast       // .opportunistic + .fast (기본값)
    case scrolling  // .fastFormat + .fast (빠른 스크롤 중)
    case high       // .highQualityFormat + .exact (뷰어용)
}
```

**1.2 GridViewController.swift**
- `lastScrollVelocity: CGFloat` 추가
- `isHighVelocityScrolling: Bool` 상태 추가
- 상수 정의:

```swift
static let velocityEnterThreshold: CGFloat = 3000  // .scrolling 진입
static let velocityExitThreshold: CGFloat = 2000   // .fast 복귀 (히스테리시스)
```

---

### Phase 2: Velocity 추적

**2.1 GridScroll.swift**
- `scrollViewWillEndDragging(_:velocity:)` 오버라이드
- `scrollViewDidScroll`에서 velocity 계산 (이전 offset 기반)
- velocity 상태 업데이트:

```swift
if velocity > enterThreshold {
    isHighVelocityScrolling = true
} else if velocity < exitThreshold {
    isHighVelocityScrolling = false
    scheduleUpgrade()  // 디바운스 150ms
}
```

---

### Phase 3: Quality 적용

**3.1 GridViewController.swift**
- `currentThumbnailQuality() -> ImageQuality` 추가:

```swift
func currentThumbnailQuality() -> ImageQuality {
    return isHighVelocityScrolling ? .scrolling : .fast
}
```

- `cellForItemAt`에서 `quality: currentThumbnailQuality()` 전달

**3.2 PhotoCell.swift**
- `configure(quality:)` 파라미터 추가
- `lastRequestQuality`, `needsHighQualityUpgrade` 추가

---

### Phase 4: 고품질 업그레이드

**4.1 GridScroll.swift**
- `upgradeVisibleCellsToHighQuality()` 추가
- velocity exit 후 150ms 디바운스로 호출
- `needsHighQualityUpgrade == true`인 셀만 재요청

---

### Phase 5: 로그 업데이트

**5.1 기존 로그 수정**
- `[Thumb:Req]`에 quality 표시
- `[Thumb:Upgrade]` 로그 추가
- velocity 상태 로그 추가 (옵션)

---

## 예상 동작 흐름

```
1. 느린 스크롤 시작
   → velocity < 3000
   → quality = .fast
   → 384px 선명 이미지

2. 빠른 플릭
   → velocity > 3000
   → isHighVelocityScrolling = true
   → quality = .scrolling
   → 저품질 빠른 응답 (성능 방어)

3. 속도 감소
   → velocity < 2000
   → isHighVelocityScrolling = false
   → 150ms 디바운스
   → upgradeVisibleCellsToHighQuality()
   → 384px 선명 이미지로 교체
```

---

## 기대 효과

| 상황 | 이전 | 이후 |
|------|------|------|
| 느린 스크롤 | 192px (뭉개짐) | 384px (선명) |
| 빠른 플릭 | 192px (뭉개짐) | 저품질 (성능 방어) |
| 스크롤 정지 | 192px 유지 | 384px 업그레이드 |

---

## 참고

- Apple Photos 앱: `.opportunistic` + preheat 조합
- WWDC 2018: Image and Graphics Best Practices
- PHCachingImageManager `startCachingImages` 활용 권장
