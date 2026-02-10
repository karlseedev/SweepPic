# 그리드 스크롤 성능 분석 (2026-02-10)

## 1. 요청

120Hz ProMotion 디스플레이(iPhone 13 Pro)에서 **느린 스크롤 시 "드드득" 끊기는 현상** 원인 파악.
빠른 스크롤에서는 체감되지 않고, 느린 스크롤에서만 발생.

## 2. 현재 문제

### 증상
- 120Hz 화면인데 60Hz처럼 끊기는 느낌
- 느린 스크롤에서 특히 체감됨

### 원인 구조 (xctrace로 확인)
- **Render hitch** (GPU 합성 단계에서 프레임 deadline 초과)
- Commit hitch (메인 스레드)는 경미 — 최대 3.63ms로 8.33ms 예산 이내
- **레이어 총 수에 비례해서 렌더 시간이 증가하는 구조**
  - render count 47 → 평균 7.23ms (예산 8.33ms에 여유 1.1ms)
  - render count 81 → 23ms (예산 초과)

### 핵심 수치 (xctrace, 15초 측정)
| 항목 | 값 |
|------|-----|
| 총 render hitch | 107건 |
| 평균 render 시간 | 7.23ms |
| 120Hz 프레임 예산 | 8.33ms |
| 여유 | 1.1ms |
| 8.33ms 초과 (체감 끊김) | 27건 |
| 최악 hitch | 23.07ms (render count 81) |

## 3. 최종 결론

### 범인: FloatingUI (BACKDROP, METAL, shadow, blur)

FloatingUI 54개 레이어(전체의 37%)가 **hitch의 82%를 차지**.
레이어당 비용은 균일하지 않으며, CA expensive 속성(BACKDROP, METAL, shadow, blur)이 집중된 FloatingUI가 압도적으로 비쌈.

### A/B 테스트 결과 (HitchMonitor, 느린 스크롤)

| 지표 | Baseline (147 layers) | FloatingUI OFF (93 layers) | 변화 |
|------|----------------------|---------------------------|------|
| Hitch rate (avg 3회) | 29.3 ms/s [Critical] | 5.3 ms/s [Warning] | **-82%** |
| Dropped frames (avg) | 10 | 1.7 | **-83%** |
| 최악 (L1 First) | 55.8 ms/s, 19 dropped | 7.6 ms/s, 3 dropped | **-86%** |

### Baseline 개별 측정값
```
[Hitch] L2 Steady: hitch: 12.3 ms/s [Critical], dropped: 4, longest: 2 (16.7ms)
[Hitch] L2 Steady: hitch: 19.7 ms/s [Critical], dropped: 7, longest: 1 (8.3ms)
[Hitch] L1 First:  hitch: 55.8 ms/s [Critical], dropped: 19, longest: 3 (25.0ms)
```

### FloatingUI OFF 개별 측정값
```
[Hitch] L2 Steady [FloatingUI OFF]: hitch: 2.8 ms/s [Good], dropped: 1, longest: 1 (8.3ms)
[Hitch] L2 Steady [FloatingUI OFF]: hitch: 5.5 ms/s [Warning], dropped: 1, longest: 1 (8.3ms)
[Hitch] L1 First  [FloatingUI OFF]: hitch: 7.6 ms/s [Warning], dropped: 3, longest: 2 (16.7ms)
```

### 해석

- **셀 영역 94레이어**: 단순 이미지 (`!opaque`만) → 가벼움
- **FloatingUI 54레이어**: BACKDROP×5, METAL×3, shadow×5, BLUR_EFFECT×1, filters×1, roundedClip×4 → 개당 비용 압도적
- LiquidGlassOptimizer의 기존 최적화(C-1~C-3)는 Metal 렌더링만 최적화 → **CA 합성 비용(BACKDROP, blur, shadow)은 미처리**

## 4. CA 합성 참여 레이어 (코드 추정 vs 실측)

### 코드 기준 추정 (~30개)

#### PhotoCell (일반 사진: 셀당 2개)
- contentView, imageView
- dimmedOverlayView → isHidden=true (합성 제외)
- videoGradientView → isHidden=true (합성 제외)
- 기타 배지류 → isHidden=true (합성 제외)

#### PhotoCell (비디오 셀: 셀당 5개)
- contentView, imageView, videoGradientView + CAGradientLayer, videoIconView, videoDurationLabel

#### FloatingTitleBar (~6개)
- VariableBlurView, CAGradientLayer, contentContainer, titleLabel(shadow), subtitleLabel(shadow), selectButton(GlassTextButton)

#### LiquidGlassTabBar (~8개)
- CAGradientLayer, shadowContainer, platter, selectionPill, tabButton × 3, + 내부 서브레이어

#### 시스템/컨테이너 (~4개)
- UIWindow, collectionView, FloatingOverlayContainer, 상태바 등

### 실측 (LayerDumpInspector): 147개

코드 추정 30개와 실측 147개의 차이는 각 컴포넌트 내부의 서브레이어(LiquidGlassEffectView, BackdropView, SelectionPill 등)와 시스템 컨테이너 레이어 때문. 상세 분포는 섹션 5의 Phase 2 참조.

## 5. 조사 과정

### Phase 1: xctrace 프로파일링

```bash
xctrace record --template "Animation Hitches" \
  --device "00008110-00041DDC212A801E" \
  --attach "PickPhoto" --time-limit 15s \
  --output /tmp/hitch_trace.trace
```

- 실기기(iPhone 13 Pro, iOS 18.6)에서 15초간 프로파일링
- `xctrace export --xpath`로 XML 변환 후 분석

#### 분석한 데이터 테이블

| 테이블 | 알 수 있었던 것 |
|--------|--------------|
| hitches-summary | hitch 107건, severity 분포, 시간대별 패턴 |
| hitches-commit-interval | commit hitch 29건, 전부 Low severity (메인 스레드는 문제 아님) |
| hitches-render-interval | render hitch 107건, render count와 duration 상관관계 |
| metal-gpu-intervals | Metal(LiquidGlass) GPU 비용 2.5%, CA 합성 97.5% |
| time-profile | CPU 시간 분포 |

#### xctrace에서 확인된 것
1. **hitch 유형**: render hitch가 주된 문제 (commit hitch 아님)
2. **Metal 셰이더**: GPU 비용의 2.5%만 차지 → LiquidGlassKit Metal 렌더링은 범인 아님
3. **render count와 비용의 비례 관계**: 레이어 수가 늘면 렌더 시간도 비례 증가
4. **120Hz 환경의 근본적 타이트함**: 예산 8.33ms에서 여유 1.1ms

#### xctrace의 한계
- Surface ID → 뷰 이름 매핑 불가 → **어떤 레이어가 비싼지 특정 불가**
- "CA 합성이 원인"이라는 결론은 "화면을 그리는 게 원인"과 같은 수준

### Phase 2: LayerDumpInspector (런타임 레이어 덤프)

xctrace의 한계를 우회하기 위해 **런타임에서 직접 레이어 트리를 덤프**하는 디버그 도구 구현.

#### 구현
- `LayerDumpInspector.swift`: 윈도우의 모든 visible 레이어를 재귀 탐색
- 각 레이어에 expensive 속성 태깅: `!opaque`, `shadow`, `BACKDROP`, `METAL`, `BLUR_EFFECT`, `roundedClip`, `GRADIENT`, `filters`, `MASK`
- 스크롤 시작 0.5초 후 자동 덤프 (한 번만 실행)
- 결과: 콘솔 로그 + Documents/layer_dump.txt

#### Inspector 버그 수정
초기 구현에서 **hidden된 부모의 자식을 visible로 카운트**하는 버그 발견.
CA 합성 규칙: 부모가 hidden이면 모든 자식도 합성에서 제외됨.
수정 전 243개 → 수정 후 **147개** (정확한 수치).

#### 정확한 레이어 분포 (147개)

| 영역 | 레이어 | 비율 | expensive 속성 |
|------|--------|------|---------------|
| 시스템 컨테이너 | 11 | 7% | rounded(r=47), !opaque |
| 포토 셀 20개 × 3 | 60 | 41% | !opaque |
| 비디오 셀 5개 × ~6.8 | 34 | 23% | !opaque, GRADIENT |
| 스크롤 인디케이터 | 2 | 1% | rounded |
| FloatingTitleBar | 21 | 14% | BACKDROP×2, METAL×2, shadow×2, BLUR_EFFECT, filters |
| LiquidGlassTabBar | 22 | 15% | BACKDROP×3, METAL×1, shadow×3, roundedClip×2 |

### Phase 3: A/B 테스트 (컴포넌트 토글)

레이어 덤프로 "무엇이 있는지"는 파악했지만 "얼마나 비싼지"는 모름.
**컴포넌트 토글 A/B 테스트**로 실제 비용을 측정.

#### 구현
- `RenderABTest.swift`: 스크롤 시작 시 테스트 조건 적용, 종료 시 복원
- HitchMonitor 로그에 테스트명 자동 태깅
- 테스트 케이스: baseline / floatingUIHidden / cellsOpaque / shadowPathFix

#### 결과
→ 섹션 2 참조. FloatingUI가 hitch의 82%를 차지함 확정.

## 6. 분석 과정의 실수와 교훈

### 실수
1. xctrace 데이터로 "CA 합성이 원인"이라는 비구체적 결론 도출
2. Metal이 범인이 아니라고 해놓고 MTKView를 비싼 레이어로 추측 (일관성 부족)
3. LayerDumpInspector에서 hidden 부모의 자식을 visible로 카운트 → 243개 오탐
4. 오탐 데이터로 "버그 4개 발견" 선언 (시스템 탭바 안 숨김, gradient 안 숨김 등 → 전부 정상이었음)
5. "레이어당 비용 균일" 가설을 검증 없이 결론으로 채택

### 교훈
1. **상관관계 ≠ 인과관계**: "레이어 많으면 느리다"는 "누가 비싸다"를 알려주지 않음
2. **디버그 도구도 검증이 필요**: inspector 자체의 버그로 잘못된 결론 도출 가능
3. **A/B 테스트가 가장 확실한 방법**: 끄고 켜서 측정하면 논쟁 없이 결론 나옴
4. **"균일 분포" 가정은 위험**: 실측으로 FloatingUI 37%가 hitch 82%를 차지함 확인

## 7. 다음 단계

### 핵심 과제: 스크롤 중 FloatingUI CA 합성 비용 줄이기

현재 LiquidGlassOptimizer는 Metal 렌더링만 최적화.
실제 비용의 주범인 **BACKDROP, blur, shadow, roundedClip**은 미처리.

### 미확인 사항: FloatingUI 내부 분해

FloatingUI 전체 82%라는 것은 확인됐지만, 내부에서 뭐가 비싼지는 아직 미확인.

| 요소 | LiquidGlass? | expensive 속성 |
|------|-------------|---------------|
| LiquidGlassView × 3 (CAMetalLayer) | O | METAL |
| BackdropView × 4 (glass 효과) | O | BACKDROP |
| SelectionPill BackdropView | O | BACKDROP |
| VariableBlurView (상단 블러) | **X** | BACKDROP, BLUR_EFFECT, filters |
| shadow × 5 (labels, icons) | **X** | offscreen render 가능 |
| CAGradientLayer × 2 | **X** | GRADIENT |
| 나머지 컨테이너/라벨 ~28개 | **X** | !opaque 정도 |

→ LiquidGlass 직접 기여분(METAL×3 + BACKDROP×4)과 비LiquidGlass 기여분(VariableBlur, shadow 등) 분리 필요.

### 추가 A/B 테스트 후보
1. **glass 효과만 OFF** (METAL+BACKDROP 7개 제거, 나머지 유지)
2. **VariableBlur만 OFF** (blur+backdrop+filters 3개 제거)
3. **shadow만 OFF** (5개 제거)

### 방안 (내부 분해 후 결정)
1. **스크롤 중 glass 효과 비활성화**: BACKDROP/blur → 단색 반투명 배경으로 교체
2. **스크롤 중 shadow 제거**: shadowOpacity = 0
3. **스크롤 중 FloatingUI fade out**: 전체를 숨기는 UX 타협
4. 위 중 하나를 LiquidGlassOptimizer에 C-4로 추가

### 검증
- A/B 테스트 동일 방법으로 적용 전/후 비교
- 목표: Baseline Critical → Warning/Good 수준

## 8. 참고 파일

### 디버그 도구
- LayerDumpInspector: `PickPhoto/PickPhoto/Debug/LayerDumpInspector.swift`
- RenderABTest: `PickPhoto/PickPhoto/Debug/RenderABTest.swift`
- HitchMonitor: `Sources/AppCore/Services/HitchMonitor.swift`

### 분석 대상 코드
- LiquidGlassOptimizer: `PickPhoto/PickPhoto/Debug/LiquidGlassOptimizer.swift`
- PhotoCell: `PickPhoto/PickPhoto/Features/Grid/PhotoCell.swift`
- FloatingTitleBar: `PickPhoto/PickPhoto/Shared/Components/FloatingTitleBar.swift`
- LiquidGlassTabBar: `PickPhoto/PickPhoto/Shared/Components/LiquidGlassTabBar.swift`
- GridScroll: `PickPhoto/PickPhoto/Features/Grid/GridScroll.swift`

### Instruments 데이터
- trace 파일: `/tmp/hitch_trace.trace`
- export된 XML: `/tmp/hitch_*.xml`
