# 그리드 스크롤 성능 분석 (2026-02-10)

## 1. 요청

120Hz ProMotion 디스플레이(iPhone 13 Pro)에서 **느린 스크롤 시 "드드득" 끊기는 현상** 원인 파악.
빠른 스크롤에서는 체감되지 않고, 느린 스크롤에서만 발생.

## 2. 현재 문제

### 증상
- 120Hz 화면인데 60Hz처럼 끊기는 느낌
- 느린 스크롤에서 특히 체감됨

### 원인 구조 (확인됨)
- **Render hitch** (GPU 합성 단계에서 프레임 deadline 초과)
- Commit hitch (메인 스레드)는 경미 — 최대 3.63ms로 8.33ms 예산 이내
- **레이어 총 수에 비례해서 렌더 시간이 증가하는 구조**
  - render count 47 → 평균 7.23ms (예산 8.33ms에 여유 1.1ms)
  - render count 81 → 23ms (예산 초과)
- 특정 레이어 하나가 범인이 아니라, **레이어가 47개 쌓인 총합이 무거운 것**
- 47개 × 약 0.15ms/레이어 = 7.23ms → 8.33ms에 아슬아슬

### 핵심 수치 (15초 측정)
| 항목 | 값 |
|------|-----|
| 총 render hitch | 107건 |
| 평균 render 시간 | 7.23ms |
| 120Hz 프레임 예산 | 8.33ms |
| 여유 | 1.1ms |
| 8.33ms 초과 (체감 끊김) | 27건 |
| 최악 hitch | 23.07ms (render count 81) |

## 3. 조사 방법과 내용

### 3-1. xctrace CLI로 Instruments 프로파일링

```bash
xctrace record --template "Animation Hitches" \
  --device "00008110-00041DDC212A801E" \
  --attach "PickPhoto" --time-limit 15s \
  --output /tmp/hitch_trace.trace
```

- 실기기(iPhone 13 Pro, iOS 18.6)에서 15초간 프로파일링
- `xctrace export --xpath`로 XML 변환 후 분석

### 3-2. 분석한 데이터 테이블

| 테이블 | 알 수 있었던 것 |
|--------|--------------|
| hitches-summary | hitch 107건, severity 분포, 시간대별 패턴 |
| hitches-commit-interval | commit hitch 29건, 전부 Low severity (메인 스레드는 문제 아님) |
| hitches-render-interval | render hitch 107건, render count와 duration 상관관계 |
| metal-gpu-intervals | Metal(LiquidGlass) GPU 비용 2.5%, CA 합성 97.5% |
| metal-command-buffer-completed | command buffer 완료 간격 |
| time-profile | CPU 시간 분포 (메인 스레드 / 워커 스레드) |
| display-compositor-interval | "layer must be opaque" 메시지 확인 |
| metal-object-label | 시스템 내부 라벨만 존재, 뷰 이름 매핑 불가 |

### 3-3. 확인된 것

1. **hitch 유형**: render hitch가 주된 문제 (commit hitch 아님)
2. **Metal 셰이더**: GPU 비용의 2.5%만 차지 → LiquidGlassKit Metal 렌더링은 범인 아님
3. **render count와 비용의 비례 관계**: 레이어 수가 늘면 렌더 시간도 비례 증가
4. **120Hz 환경의 근본적 타이트함**: 예산 8.33ms에서 여유 1.1ms

### 3-4. 확인하지 못한 것

- **어떤 레이어가 얼마나 비싼지**: xctrace export에서 Surface ID → 뷰 이름 매핑 불가
- **불필요하게 돌고 있는 레이어가 있는지**: 코드에서 30개로 추정했지만 실측 47개, 차이 17개의 출처 미확인

### 3-5. 분석 과정의 실수

- "CA 합성이 원인"이라는 결론은 "화면을 그리는 게 원인"과 같은 수준으로, 원인 특정이 아니었음
- Metal이 범인이 아니라고 해놓고 다시 MTKView를 비싼 레이어로 추측하는 등 일관성 부족
- xctrace export의 한계를 파악하지 못하고 계속 데이터를 뒤진 것은 비효율적이었음

## 4. 현재 상태의 CA 합성 참여 레이어 (코드 기준)

### PhotoCell (일반 사진: 셀당 2개)
- contentView, imageView
- dimmedOverlayView → isHidden=true (합성 제외)
- videoGradientView → isHidden=true (합성 제외)
- 기타 배지류 → isHidden=true (합성 제외)

### PhotoCell (비디오 셀: 셀당 5개)
- contentView, imageView, videoGradientView + CAGradientLayer, videoIconView, videoDurationLabel

### FloatingTitleBar (~6개)
- VariableBlurView, CAGradientLayer, contentContainer, titleLabel(shadow), subtitleLabel(shadow), selectButton(GlassTextButton)

### LiquidGlassTabBar (~8개)
- CAGradientLayer, shadowContainer, platter, selectionPill, tabButton × 3, + 내부 서브레이어

### 시스템/컨테이너 (~4개)
- UIWindow, collectionView, FloatingOverlayContainer, 상태바 등

### 추정 합계: ~30개 (실측 47개와 17개 차이)
- 차이의 출처: GlassTextButton/LiquidGlassPlatter/SelectionPill 내부 서브레이어, 또는 확인하지 못한 뷰

## 5. 앞으로 해야 할 방향

### 핵심 전략: 레이어 수를 줄인다

특정 범인이 없으므로, **전체 레이어 수를 줄이는 것**이 해법.
render count를 47 → 30 이하로 줄이면 렌더 시간이 ~4.6ms로 떨어져 충분한 여유 확보.

### 구체적 단계

#### 1단계: 실측 레이어 수 확인
- 런타임에서 실제 뷰/레이어 계층을 덤프해서 47개의 정체를 확인
- 추정 30개와 실측 47개의 차이 17개가 어디서 오는지 파악
- 불필요하게 존재하는 레이어 발견 시 즉시 제거

#### 2단계: 불필요한 레이어 제거
- 비디오/iCloud가 아닌 일반 사진 셀에서 배지 뷰를 lazy 생성으로 전환
- GlassTextButton, SelectionPill 등 서브 컴포넌트 내부의 숨겨진 레이어 정리
- shadow 속성 사용 뷰 점검 (shadow는 별도 compositing layer 생성)

#### 3단계: 스크롤 중 레이어 경량화
- 스크롤 중 FloatingUI의 일부 레이어를 비활성화하는 방안 검토
- 이미 LiquidGlassOptimizer가 하려는 것과 동일한 방향

#### 검증
- 각 단계 후 동일한 xctrace 프로파일링으로 render count / hitch 수 비교
- render count 감소 → 렌더 시간 감소 → hitch 감소 확인

## 6. 참고 파일

- trace 파일: `/tmp/hitch_trace.trace`
- export된 XML: `/tmp/hitch_*.xml`
- HitchMonitor: `Sources/AppCore/Services/HitchMonitor.swift`
- LiquidGlassOptimizer: `PickPhoto/PickPhoto/Debug/LiquidGlassOptimizer.swift`
- PhotoCell: `PickPhoto/PickPhoto/Features/Grid/PhotoCell.swift`
- FloatingTitleBar: `PickPhoto/PickPhoto/Shared/Components/FloatingTitleBar.swift`
- LiquidGlassTabBar: `PickPhoto/PickPhoto/Shared/Components/LiquidGlassTabBar.swift`
