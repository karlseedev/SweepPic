# AestheticsScore 도입 계획

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
- 부드러운 텍스처를 블러로 오판하지 않을 가능성 높음

---

## 적용 방식: 방안 B (최종 판정 전 재확인)

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

### 코드 위치
`QualityAnalyzer.swift` - `makeVerdict()` 함수 내부

```swift
// 최종 판정 전
if isLowQuality {
    if #available(iOS 18.0, *) {
        let aesthetics = try? await AestheticsAnalyzer.shared.analyze(image)
        if let score = aesthetics?.overallScore, score > 0 {
            // 구제 → acceptable
            return QualityResult.acceptable(...)
        }
    }
}
```

### 특징
- **구제 전용**: 저품질 → 살리기 (역방향은 없음)
- **iOS 18+ 전용**: iOS 17 이하는 기존 로직 유지
- **조건부 호출**: lowQuality 판정 시에만 호출 (성능 최적화)

---

## 테스트 방법: 비교 모드

### 목적
도입 전후 차이를 실제로 확인

### 방식
1. 비교 분석 실행 (기존 로직 + AestheticsScore 로직)
2. **구제된 사진만** 휴지통에 이동
3. 휴지통에서 뷰어로 확인
4. 진짜 구제해도 되는 사진인지 판단

### 흐름

```
비교 모드 실행
    │
    ├── 기존: 47장 lowQuality
    ├── 방안B: 38장 lowQuality
    │
    └── 차이 9장 (구제 대상) → 휴지통에 이동

휴지통에서:
    - 구제된 9장만 있음
    - 뷰어로 하나씩 확인
    - 확인 후 복구
```

### 뷰어 디버그 정보

```
[Debug] 기존 판정: severeBlur
[Debug] AestheticsScore: 0.31
[Debug] → 구제 대상
```

---

## 구현 계획

### 파일 구조

```
SweepPic/
├── Debug/
│   └── AestheticsComparisonTester.swift  # 신규 (DEBUG 전용)
│
├── Features/AutoCleanup/
│   └── Analysis/
│       ├── AestheticsAnalyzer.swift      # 기존 (수정 없음)
│       └── QualityAnalyzer.swift         # 수정 (방안B 적용 후)
```

### 단계별 구현

#### Phase 1: 비교 테스터 구현 (현재)

**목표**: 도입 전후 비교 확인

**파일**: `Debug/AestheticsComparisonTester.swift`

```swift
#if DEBUG
final class AestheticsComparisonTester {

    /// 비교 분석 실행
    /// - 기존 로직 + AestheticsScore 로직 병렬 실행
    /// - 구제된 사진만 휴지통 이동
    func runComparison() async -> ComparisonResult

    /// 비교 결과
    struct ComparisonResult {
        let totalScanned: Int           // 검색한 사진 수
        let originalLowQuality: Int     // 기존 로직 저품질 수
        let newLowQuality: Int          // 방안B 저품질 수
        let rescuedAssets: [PHAsset]    // 구제된 사진들
    }
}
#endif
```

**호출 방법**:
- 그리드 자동 정리 버튼 길게 누르기 → 비교 모드
- 또는 디버그 메뉴 추가

#### Phase 2: 본 적용 (테스트 후)

**목표**: 실제 파이프라인에 AestheticsScore 적용

**파일**: `QualityAnalyzer.swift`

```swift
private func makeVerdict(...) -> QualityResult {
    // ... 기존 판정 로직 ...

    if isLowQuality {
        // iOS 18+ AestheticsScore 구제
        if #available(iOS 18.0, *) {
            if let rescued = await tryRescueWithAesthetics(image) {
                return rescued
            }
        }
    }

    // 기존 결과 반환
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

## 롤백 계획

### 롤백 포인트
커밋: `58b6112` (Phase 1 시작 전)

### 롤백 방법
```bash
git reset --hard 58b6112
```

### Phase 1 완료 후
- 비교 테스트 결과 검토
- 문제 없으면 Phase 2 진행
- 문제 있으면 롤백 또는 임계값 조정

---

## 참고

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

### 관련 상수 (CleanupConstants.swift)

```swift
// AestheticsScore 임계값
static let aestheticsPrecisionThreshold: Float = -0.3
static let aestheticsRecallThreshold: Float = 0.0
```
