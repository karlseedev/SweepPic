# AestheticsScore 구제 로직 구현

## 배경

### 현재 문제
자연풍경 사진이 `severeBlur`로 오탐되는 문제 발생

```
[Debug] verdict: lowQuality
[Debug] signals: ["severeBlur"]
[Debug] 휘도: 0.548
[Debug] RGB Std: 39.69
→ 선명한 풍경 사진인데 저품질로 판정됨
```

### 원인
- Laplacian 블러 감지는 "엣지가 적으면 블러"로 판단
- 자연풍경은 부드러운 그라데이션이 많아 엣지가 적음
- SafeGuard가 얼굴 기반이라 풍경 사진은 보호 못함

### 테스트 결과 (2026-01-28)
- AestheticsScore 구제 로직으로 문제 해결 확인
- 자연풍경 사진이 severeBlur로 오탐되어도 AestheticsScore > 0이면 구제됨

---

## 해결 방안: AestheticsScore (iOS 18+)

### AestheticsScore란?
Apple Vision Framework가 iOS 18에서 도입한 이미지 품질 평가 API

| 항목 | 설명 |
|------|------|
| `overallScore` | -1.0 ~ 1.0 미적 점수 (높을수록 좋은 사진) |
| `isUtility` | 스크린샷/문서 등 유틸리티 이미지 자동 감지 |

### 장점
- Apple ML 기반 종합 품질 평가
- 블러, 노출, 구도 등 종합적 판단
- 부드러운 텍스처를 블러로 오판하지 않음

---

## 적용 방식: 최종 판정 전 재확인

### 프로세스

```
기존 로직 실행
    │
    ▼
lowQuality 판정 예정?
    │
    ├── No → acceptable (그대로 통과)
    │
    └── Yes → AestheticsScore 체크 (iOS 18+)
                │
                ├── score > 0 → acceptable (구제)
                │
                └── score ≤ 0 → lowQuality (유지)
```

### 특징
- **구제 전용**: 저품질 → 살리기 (역방향은 없음)
- **iOS 18+ 전용**: iOS 17 이하는 기존 로직 유지
- **조건부 호출**: lowQuality 판정 시에만 호출 (성능 최적화)

---

## 구현

### 파일 구조

```
SweepPic/Features/AutoCleanup/Analysis/
├── AestheticsAnalyzer.swift   # 기존 (수정 없음)
└── QualityAnalyzer.swift      # 수정 (구제 로직 추가)
```

### QualityAnalyzer.swift 수정

#### 1. analyze() 메서드에 구제 로직 추가

```swift
// 최종 판정
let analysisTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
let analysisMethod: AnalysisMethod = blurAnalyzer.isAvailable ? .metalPipeline : .fallback

// iOS 18+ AestheticsScore 구제 시도
// lowQuality 판정인 경우에만 AestheticsScore를 체크하여 성능 최적화
if #available(iOS 18.0, *) {
    let result = makeVerdict(
        assetID: assetID,
        creationDate: creationDate,
        signals: signals,
        safeGuardResult: safeGuardResult,
        analysisTimeMs: analysisTimeMs,
        method: analysisMethod
    )

    // lowQuality 판정인 경우 AestheticsScore로 구제 시도
    if result.verdict.isLowQuality {
        if let rescued = await tryRescueWithAesthetics(
            image: image,
            assetID: assetID,
            creationDate: creationDate,
            signals: signals,
            analysisTimeMs: analysisTimeMs,
            method: analysisMethod
        ) {
            return rescued
        }
    }

    return result
}

return makeVerdict(...)
```

#### 2. tryRescueWithAesthetics() 메서드 추가

```swift
/// iOS 18+ AestheticsScore로 구제 시도
///
/// 기존 로직에서 lowQuality 판정이 난 경우, AestheticsScore를 체크하여
/// 실제로는 괜찮은 사진인지 재확인합니다.
///
/// 구제 조건:
/// - AestheticsScore.overallScore > 0 (aestheticsRecallThreshold)
/// - isUtility == false (스크린샷 등은 구제 안함)
@available(iOS 18.0, *)
private func tryRescueWithAesthetics(
    image: CGImage,
    assetID: String,
    creationDate: Date?,
    signals: [QualitySignal],
    analysisTimeMs: Double,
    method: AnalysisMethod
) async -> QualityResult? {
    // AestheticsScore 분석
    guard let metrics = try? await AestheticsAnalyzer.shared.analyze(image) else {
        return nil
    }

    // isUtility면 구제 안함 (스크린샷, 문서 등)
    if metrics.isUtility {
        return nil
    }

    // score > threshold면 구제
    let threshold = CleanupConstants.aestheticsRecallThreshold
    if metrics.overallScore > threshold {
        #if DEBUG
        let signalNames = signals.map { $0.kind.rawValue }.joined(separator: ", ")
        Log.print("[QualityAnalyzer] AestheticsScore 구제: score=\(String(format: "%.3f", metrics.overallScore)) > \(threshold), signals=[\(signalNames)]")
        #endif

        return QualityResult.acceptable(
            assetID: assetID,
            creationDate: creationDate,
            signals: signals,  // 원래 신호 유지 (디버깅용)
            analysisTimeMs: analysisTimeMs,
            method: method
        )
    }

    return nil
}
```

---

## 성능 영향

| 항목 | 값 |
|------|-----|
| 현재 분석 시간 | 약 80~120ms/장 |
| AestheticsScore | 약 50~150ms/장 |
| 호출 대상 | lowQuality 판정 사진만 |

**예시**: 1000장 중 50장이 lowQuality 예정
→ 추가 시간: 50장 × 100ms = **약 5초**

**결론**: 전체 시간에 큰 영향 없음

---

## 관련 파일

### AestheticsAnalyzer.swift (기존 구현)

```swift
@available(iOS 18.0, *)
final class AestheticsAnalyzer {
    static let shared = AestheticsAnalyzer()

    func analyze(_ image: CGImage) async throws -> AestheticsMetrics
    // overallScore: Float (-1.0 ~ 1.0)
    // isUtility: Bool
}
```

### CleanupConstants.swift (관련 상수)

```swift
// AestheticsScore 임계값
static let aestheticsPrecisionThreshold: Float = -0.3
static let aestheticsRecallThreshold: Float = 0.0  // 구제 시 사용
```
