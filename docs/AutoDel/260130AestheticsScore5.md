# AestheticsScore 통합 테스트 결과 및 3모드 설계

## 배경

`260128AestheticsScore4.md`의 통합 로직 설계를 기반으로 CompareAnalysisTester에서 대규모 테스트를 수행했습니다.
이 문서는 테스트 과정에서 발견된 이슈, 수정 사항, 그리고 3모드 체계 재설계 방향을 정리합니다.

---

## 1. 통합 테스트 (CompareAnalysisTester)

### 테스트 방식

경로1(기존 로직) + 경로2(AestheticsScore)를 병렬 실행하여 결과를 카테고리별로 분류:

| 배지 | 의미 | 판정 기준 |
|-----|------|----------|
| ⚪ 회색 (both) | 둘 다 저품질 | 경로1 AND 경로2 |
| 🔵 파랑 (path1Only) | 경로1만 저품질 | 경로1 O, 경로2 X |
| 🟡 노랑 (path2Only) | 경로2만 저품질 | 경로1 X, 경로2 O |

### 테스트 결과 요약

- 3,000장 단위로 반복 테스트 수행
- 경로1과 경로2가 **상호 보완적**으로 작동하는 것 확인
- 🔵 파랑: 경로1이 잡고 경로2가 놓친 저품질 (블러, 노출 등)
- 🟡 노랑: 경로2가 잡고 경로1이 놓친 저품질 (미적 품질 낮음)

### "이어서 테스트" 기능 추가

대규모 테스트를 위해 세션 저장 기능 구현:

- UserDefaults에 마지막 테스트 위치(날짜) 저장
- "이어서 테스트" 버튼으로 이전 위치부터 계속
- 누적 검색/휴지통 수 추적

---

## 2. 발견된 이슈 및 수정

### 2-1. Vision Continuation 크래시

**증상**: 테스트 중 앱 강제 종료

```
SWIFT TASK CONTINUATION MISUSE: detectTextScreenshot(_:)
tried to resume its continuation more than once
```

**원인**: `VNImageRequestHandler.perform()`이 특정 조건에서 completion handler 호출 **AND** throw를 동시에 수행.
`withCheckedContinuation`의 continuation이 두 번 resume되어 크래시.

**수정**: `hasResumed` 플래그로 중복 resume 방지

```swift
private func detectTextScreenshot(_ image: CGImage) async -> Bool {
    return await withCheckedContinuation { continuation in
        var hasResumed = false

        let request = VNRecognizeTextRequest { request, error in
            guard !hasResumed else { return }
            hasResumed = true
            // ... resume
        }

        do {
            try handler.perform([request])
        } catch {
            guard !hasResumed else { return }
            hasResumed = true
            continuation.resume(returning: false)
        }
    }
}
```

**적용 파일**:
- `CompareAnalysisTester.swift`
- `QualityAnalyzer.swift`

### 2-2. 블로그 저장 이미지 오탐

**증상**: 블로그 저장 이미지 (약 900×8000px) 500장 이상이 저품질로 검출

**원인**:
- 이미지 로딩이 "짧은 변 360px" 기준
- 세로로 긴 이미지 (900×8000) → 360×3200px로 로드
- 큰 이미지에서 텍스트가 검출되어 저품질 판정

**수정**: 극단적 비율 이미지 제외 (경로1, 경로2 모두)

```swift
private let extremeAspectRatioThreshold: CGFloat = 5.0

// 극단적 비율 체크 (블로그 저장 이미지 등 제외)
let aspectRatio = CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
let isExtremeRatio = aspectRatio > extremeAspectRatioThreshold
                  || aspectRatio < (1.0 / extremeAspectRatioThreshold)
if isExtremeRatio {
    continue  // 분석 스킵
}
```

---

## 3. 3모드 체계 재설계

### 기존 모드 구조 (260120AutoDel.md 기준)

| 모드 | 이름 | 신호 | 상태 |
|-----|------|------|------|
| Precision | 신중한 정리 | Strong만 | ✅ 1차 출시 |
| Recall | 적극적 정리 | Strong + Conditional + Weak | 🔧 추후 |

### 새 모드 구조 (3모드)

3모드 모두 **합집합(OR)** 로직이며, **경로2의 AestheticsScore 임계값만 다름**:

| 모드 | 이름 | 로직 | 경로2 임계값 | 컨셉 |
|-----|------|------|------------|------|
| **완화** (Light) | 신중한 정리 | 경로1 **OR** 경로2 | < **-0.3** | 확실한 저품질만 |
| **기본** (Standard) | 일반 정리 | 경로1 **OR** 경로2 | < **0.0** | 테스트 검증된 기본값 |
| **강화** (Deep) | 적극적 정리 | 경로1 **OR** 경로2 | < **0.2** | 더 적극적으로 잡음 |

**계층**: light ⊂ standard ⊂ deep (임계값만 다르므로 자동 보장)

### 각 모드 상세

#### 완화 (Light) - AestheticsScore < -0.3

- 경로1 OR 경로2(-0.3)
- 경로2가 매우 엄격 → 확실한 저품질만 경로2에서 추가 감지
- 경로1(기존 로직)은 모든 모드에서 동일하게 작동

#### 기본 (Standard) - AestheticsScore < 0.0

- 경로1 OR 경로2(0.0)
- 테스트에서 검증된 현재 통합 로직
- 경로1: 기존 로직 + Strong 신호 보호 + 동의 필터 (임계값 0.2)
- 경로2: AestheticsScore < 0.0 + isUtility 필터

#### 강화 (Deep) - AestheticsScore < 0.2

- 경로1 OR 경로2(0.2)
- 경로2 임계값 완화로 더 많은 사진 포착
- 경로1 동의 임계값(0.2)과 동일한 수준

### iOS 버전별 동작

| iOS 버전 | 완화 | 기본 | 강화 |
|---------|------|------|------|
| iOS 18+ | 경로1 OR 경로2(-0.3) | 경로1 OR 경로2(0.0) | 경로1 OR 경로2(0.2) |
| iOS 16~17 | 경로1만 | 경로1만 | 경로1만 |

> iOS 16~17에서는 AestheticsScore 미지원으로 3모드 차이 없음

---

## 4. 3모드 테스트 구현 계획

### 결정 사항

| 항목 | 결정 값 | 근거 |
|-----|--------|------|
| 강화 경로2 임계값 | **0.2** | 경로1 동의 임계값과 동일, 적극적 테스트 |
| 기본 경로2 임계값 | 0.0 | 기존 통합 테스트 검증값 |
| 경로1 동의 임계값 | 0.2 | 기존과 동일 (변경 없음) |

### 계층 구조 검증

```
완화 ⊂ 기본 ⊂ 강화

완화(Light):    경로1 OR 경로2(-0.3)  ← 경로2 엄격
기본(Standard): 경로1 OR 경로2(0.0)
강화(Deep):     경로1 OR 경로2(0.2)   ← 경로2 완화
```

- 3모드 모두 OR 로직, 경로2 임계값만 다름
- path2(-0.3) ⊂ path2(0.0) ⊂ path2(0.2) → light ⊂ standard ⊂ deep ✓

### 딱지 분류

| 딱지 | 의미 | 조건 |
|-----|------|------|
| ⚪ 회색 | 3모드 전부 잡음 | light == true |
| 🔵 파랑 | 기본+강화만 | light == false, standard == true |
| 🟡 노랑 | 강화만 | standard == false, deep == true |

**휴지통**: deep == true인 모든 사진 이동, 딱지로 구분

### 핵심 로직 (각 사진마다)

```swift
// 1. 기존 로직 + AestheticsScore 분석 (1회씩)
let oldResult = await qualityAnalyzer.analyze(asset)
let metrics = try? await aestheticsAnalyzer.analyze(image)

// 2. 경로1 판정 (기존과 동일)
let path1Result = evaluatePath1(oldResult: oldResult, aestheticsMetrics: metrics)

// 3. 텍스트 스크린샷 감지 (1회만, 결과 재사용)
let isTextScreenshot = (image != nil) ? await detectTextScreenshot(image!) : false

// 4. 경로2 판정 (임계값만 다르게 3회, 동기 함수)
let path2Light = evaluatePath2(metrics: metrics, isTextScreenshot: isTextScreenshot,
                                threshold: -0.3)  // 완화 (엄격)
let path2Std   = evaluatePath2(metrics: metrics, isTextScreenshot: isTextScreenshot,
                                threshold: 0.0)   // 기본
let path2Deep  = evaluatePath2(metrics: metrics, isTextScreenshot: isTextScreenshot,
                                threshold: 0.2)   // 강화 (완화)

// 5. 3모드 계산 (모두 OR, 경로2 임계값만 다름)
let light    = path1Result || path2Light   // OR (경로2 엄격)
let standard = path1Result || path2Std     // OR (경로2 기본)
let deep     = path1Result || path2Deep    // OR (경로2 완화)

// 6. 카테고리 분류
if light       → .allModes   (⚪)
elif standard  → .standardUp (🔵)
elif deep      → .deepOnly   (🟡)
else           → nil (정상)
```

### evaluatePath2 리팩토링

threshold를 파라미터로 받아 동기 함수로 변환 (detectTextScreenshot은 외부에서 1회만 호출):

```swift
private func evaluatePath2(
    metrics: AestheticsMetrics?,
    isTextScreenshot: Bool,
    threshold: Float
) -> Bool {
    guard let metrics = metrics else { return false }
    if metrics.isUtility { return false }
    guard metrics.overallScore < threshold else { return false }
    if isTextScreenshot { return false }
    return true
}
```

### 파일 변경 목록

| 파일 | 변경 | 내용 |
|-----|------|------|
| `Debug/ModeComparisonTester.swift` | **새 파일** | ModeCategory, ModeComparisonResult, ModeCategoryStore, ModeComparisonTester |
| `CleanupMethodSheet.swift` | 수정 | delegate에 `cleanupMethodSheetDidSelectModeTest` 추가, DEBUG 버튼 2개 추가 |
| `GridViewController+Cleanup.swift` | 수정 | `startModeComparisonTest`, `showModeComparisonResult` 추가 |
| `Log.swift` | 수정 | "ModeComparison" 카테고리 추가 |

### iOS 버전별 동작

| iOS 버전 | 완화 | 기본 | 강화 |
|---------|------|------|------|
| iOS 18+ | 경로1 AND 경로2(0.0) | 경로1 OR 경로2(0.0) | 경로1 OR 경로2(0.2) |
| iOS 16~17 | 경로1만 | 경로1만 | 경로1만 |

> iOS 16~17에서는 AestheticsScore 미지원으로 3모드 차이 없음

---

## 5. TODO

- [ ] 3모드 테스트 구현 (ModeComparisonTester)
- [ ] 3모드 테스트로 임계값 검증
- [ ] JudgmentMode enum 재설계 (2모드 → 3모드)
- [ ] CleanupMethodSheet에 모드 선택 UI 추가
- [ ] 실제 CleanupService에 통합 로직 반영

---

## 6. 수정된 파일 목록 (이전 작업)

| 파일 | 수정 내용 |
|-----|----------|
| `CompareAnalysisTester.swift` | 이어서 테스트, 크래시 수정, 극단 비율 제외 |
| `QualityAnalyzer.swift` | continuation 크래시 수정 |
| `CleanupMethodSheet.swift` | 이어서 테스트 버튼 추가 |
| `GridViewController+Cleanup.swift` | 이어서 테스트 실행/결과 표시 |
| `Log.swift` | TextDetect, CompareAnalysis 등 로그 카테고리 추가 |
| `LiquidGlassOptimizer.swift` | 특수 따옴표 빌드 에러 수정 |

---

## 참고 문서

- `260128AestheticsScore4.md`: 통합 로직 설계 (이전 단계)
- `260127AestheticsScore3.md`: AestheticsScore 단독 테스트
- `CompareAnalysisTester.swift`: 비교 분석 테스트 코드
- `AestheticsAnalyzer.swift`: AestheticsScore 분석기
