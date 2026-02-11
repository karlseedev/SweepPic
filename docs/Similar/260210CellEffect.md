# 유사사진 그룹 셀 효과 비교 테스트 (2026-02-10)

## 배경

현재 유사사진 그룹핑 시 썸네일 테두리에 흰색 그라데이션 빛이 도는 shimmer border 방식 사용 중.
촌스럽다는 피드백으로 대안 8가지를 쇼케이스로 구현하여 비교 테스트.

## 쇼케이스 파일

- `PickPhoto/Features/SimilarPhoto/UI/EffectShowcaseViewController.swift`
- 진입점: `SceneDelegate.swift` `#if DEBUG` 블록 주석 해제로 활성화

## 8가지 효과 비교

### 셀 0: 현재 (Shimmer) — 기존 방식
- `BorderAnimationLayer` 사용
- 흰색 그라데이션 빛이 사각형 테두리를 따라 1.5초 주기로 회전
- **평가**: 촌스러움, 교체 대상

### 셀 1: Stacked Cards — 겹친 카드
- 셀 뒤에 CALayer 2장 (오프셋 + 회전 ±2~3도)
- 우측 상단 `+3` 뱃지
- 애니메이션 없이 정적으로 "여러 장" 직관 전달

### 셀 2: Shadow Pulse — 그림자 맥동
- contentView에 systemBlue 그림자
- shadowOpacity 0.3~0.7, shadowRadius 4~10 반복 (1.5초)
- 은은하고 자연스러운 효과

### 셀 3: Corner Dots — 코너 도트
- 좌하단 5pt 파란 원형 뷰 3개
- 순차 fade-in + breathing 애니메이션
- 미니멀, 정보 전달력 높음

### 셀 4: Glass+Gradient — 블러 뱃지 + 색상 변화 (방법 1) :star:
- UIVisualEffectView (systemUltraThinMaterialDark) 블러 뱃지
- `contentView.backgroundColor`를 4색 순환 (보라→핑크→파랑→오렌지, 1.5초 간격)
- 블러가 색상 변화를 은은하게 감싸줌
- **주인님 선호: 가장 마음에 듦**

### 셀 5: Gradient Badge — 그라데이션 직접 배경 (방법 2)
- CAGradientLayer를 뱃지 배경 자체로 사용
- 4색 키프레임 순환 (4초), 블러 없이 선명
- 셀 4 대비 더 눈에 띄지만 덜 세련됨

### 셀 6: Scale + Badge — 크기 확대 + 뱃지
- 셀 4% 확대 (스프링 애니메이션)
- 우측 상단 18pt 원형 뱃지 (systemBlue)
- 그리드 레이아웃과 겹칠 수 있는 단점

### 셀 7: Intelligence Glow — Apple Intelligence 스타일
- CAShapeLayer 4개 겹침 (lineWidth 2~8, blur 0~12)
- 보라/핑크/파랑/오렌지 4색 순환
- 가장 화려하지만 성능 부담 큼

## 결론

**셀 4 (Glass+Gradient)** 채택 방향.
블러 뱃지 + 배경색 순환 방식이 세련되고 성능 부담 적음.

---

## 구현 계획: Shimmer Border → Glass+Gradient Badge 교체

### 수정 파일

| 파일 | 변경 |
|------|------|
| `Features/SimilarPhoto/UI/SimilarGroupBadgeView.swift` | **신규** — 뱃지 UIView |
| `Features/Grid/GridViewController+SimilarPhoto.swift` | BorderAnimationLayer → SimilarGroupBadgeView 교체 |
| `Features/SimilarPhoto/UI/BorderAnimationLayer.swift` | 변경 없음 (삭제 안 함, 쇼케이스에서 참조) |

### 주의사항

1. **재귀 애니메이션 메모리 릭 방지**: `loopBackgroundColor` 재귀 호출 시 `removeFromSuperview()` 후에도 completion이 호출됨 → `isAnimating` 플래그 + `weak self` 이중 안전장치
2. **SimilarityCache는 actor**: `getGroupMembers(groupID:)`에 `await` 필수. 기존 `Task { }` 블록 내에서 멤버 수 조회
3. **showBadge에 count 파라미터 추가**: `.analyzed(true, let groupID?)` → groupID로 멤버 수 조회 → `showBadge(on:cell, count:)` 호출
4. **접근성 (모션 감소)**: `isReduceMotionEnabled` 시 색상 순환 중지, 정적 보라색 배경 유지

### Phase 1: SimilarGroupBadgeView 생성

```swift
final class SimilarGroupBadgeView: UIView {
    // self (UIView, 36x22pt, cornerRadius 6, clipsToBounds)
    // └── blurView (UIVisualEffectView, systemUltraThinMaterialDark)
    //     └── contentView
    //         ├── backgroundColor: 4색 순환 (보라→핑크→파랑→오렌지)
    //         └── label ("⊞ N")

    private var isAnimating = false  // 재귀 중단용 플래그

    func show(count: Int)           // fade-in + 색상 순환 시작
    func stopAndHide()              // isAnimating=false + 숨김
    func updateCount(_ count: Int)  // 라벨만 업데이트
}
```

색상 순환: `UIView.animate` 재귀, `isAnimating` 플래그로 중단 제어
모션 감소: `show(count:)`에서 체크, 정적 보라색 설정

### Phase 2: GridViewController+SimilarPhoto.swift 수정

- Associated Property: `borderLayerPool: [BorderAnimationLayer]` → `badgeViewPool: [SimilarGroupBadgeView]`
- `showBorder(on:)` → `showBadge(on:cell, count:)`: sublayers 탐색 → subviews 탐색
- `hideBorder(on:)` → `hideBadge(on:)`: removeFromSuperlayer → removeFromSuperview
- `hideAllBorders()` → `hideAllBadges()`
- `updateVisibleCellBorders`, `configureSimilarPhotoBorder`: groupID에서 멤버 수 조회 후 전달

### 검증

- [x] xcodebuild 빌드 성공
- [ ] 유사사진 그룹핑 시 뱃지 정상 표시
- [ ] 스크롤 시 뱃지 숨김 → 멈추면 0.3초 후 재표시
- [ ] 모션 감소 설정 시 정적 배경색
- [ ] 셀 재사용 시 뱃지 정리 (풀에 반환) 정상 동작

---

## 구현 완료 (2026-02-10)

### 생성된 파일
- `Features/SimilarPhoto/UI/SimilarGroupBadgeView.swift` — Glass+Gradient 뱃지 뷰

### 수정된 파일
- `Features/Grid/GridViewController+SimilarPhoto.swift` — BorderAnimationLayer → SimilarGroupBadgeView 전면 교체

### 최종 사양

| 항목 | 값 |
|------|-----|
| 뱃지 크기 | 36x22pt, cornerRadius 6 |
| 뱃지 위치 | 셀 우측 상단 (margin 4pt) |
| 블러 효과 | systemUltraThinMaterialDark |
| 라벨 | "⊞\u{2009}N" (thin space로 간격 축소) |
| 색상 순환 | 무지개 7색: 빨→주→노→초→파→남→보 → 빨 반복 |
| 전환 속도 | 0.75초/색상 (curveLinear, 부드러운 전환) |
| 풀링 | 최대 20개 재사용 |
| 접근성 | 모션 감소 시 정적 빨간색 배경 |
| 메모리 안전 | isAnimating 플래그 + weak self 이중 안전장치 |

### 튜닝 이력
1. 초기: Intelligence Glow 4색 (보라/핑크/파랑/오렌지), 1.5초, curveEaseInOut
2. 간격 축소: 아이콘-숫자 사이 thin space 적용 (70%)
3. 빨주노연두초연두노주 8색으로 변경, 속도 2배 (0.75초)
4. 초록 제거 → 빨주노연두노주 6색
5. 무지개 7색 (빨주노초파남보)으로 최종 확정
6. curveEaseInOut → curveLinear로 부드러운 전환
