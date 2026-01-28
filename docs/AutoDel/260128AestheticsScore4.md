# AestheticsScore 통합 로직 설계

## 배경

### 테스트 결과 요약

비교 분석 테스트 (CompareAnalysisTester)를 통해 기존 로직과 AestheticsScore를 비교 분석했습니다.

| 배지 | 의미 | 테스트 결과 |
|-----|------|------------|
| ⚪ 회색 (both) | 둘 다 저품질 | 중복 감지 |
| 🔵 파랑 (path1) | 경로1로 잡힘 | 기존 로직 기반 |
| 🟡 노랑 (path2) | 경로2로 잡힘 | AestheticsScore 기반 |

### 발견된 특성

**기존 로직 (QualityAnalyzer)**
- 강점: 블러(Laplacian), 노출 등 기술적 결함 감지
- 약점: 미적으로 낮은 품질 사진 놓침

**AestheticsScore**
- 강점: 미적 품질 평가 (기존이 놓친 저품질 감지)
- 약점:
  - 블러 사진 일부 놓침
  - 스크린샷을 저품질로 오판 (False Positive)
  - 정상 사진을 저품질로 오판 (임계값 0.2에서)

### 결론

두 로직은 **상호 보완적**. 단순 OR은 False Positive 문제가 있어 서로의 약점을 필터링하는 조합 로직 필요.

---

## 새 로직 설계

### 핵심 아이디어

서로의 약점을 보완하는 필터로 사용

```
최종 저품질 = 경로1 + 경로2
```

---

### 경로1: 기존 로직 기반

```
기존 로직이 저품질이라고 판정
        ↓
    ┌─────────────────────────────────┐
    │ Strong 신호? (severeBlur 등)    │
    │         ↓                       │
    │   YES → 동의 없이 저품질 확정   │
    │   NO  → AestheticsScore 동의 확인│
    └─────────────────────────────────┘
        ↓ (Strong 아닌 경우)
AestheticsScore도 "이건 별로야"라고 동의
        ↓
    → 저품질 확정
```

**효과**: 기존 로직의 오탐을 AestheticsScore로 걸러냄 (단, Strong 신호는 보호)

**Strong 신호 (동의 없이 통과)**:
- `severeBlur`: 심한 블러
- `extremeOverexposure`: 극단 과노출
- `extremeUnderexposure`: 극단 과어두움

**동의 임계값** (Weak/Conditional 신호만 적용): 0.2
- AestheticsScore < 0.2 → 동의
- AestheticsScore >= 0.2 → 동의 안 함 → 제외

**근거**: 테스트에서 파란 딱지(onlyOld)의 `severeBlur` 사진은 실제 저품질이었으나 AestheticsScore가 놓침. Strong 신호는 보호 필요.

---

### 경로2: AestheticsScore 기반

```
AestheticsScore가 저품질이라고 판정
        ↓
스크린샷/유틸리티 이미지가 아님
        ↓
    → 저품질 확정
```

**효과**: AestheticsScore의 오탐(스크린샷 등)을 isUtility로 걸러냄

**경로2 임계값**: 0.0
- AestheticsScore < 0.0 → 저품질 (확실한 저품질만)
- AestheticsScore >= 0.0 → 정상

**스크린샷 감지**: isUtility 플래그 사용
- Apple Vision 모델 기반
- 스크린샷, 문서, 영수증, QR 코드 등 감지

---

### iOS 버전 분기

| iOS 버전 | 경로1 | 경로2 |
|---------|-------|-------|
| iOS 18+ | 기존 + AestheticsScore 동의 | AestheticsScore + isUtility |
| iOS 16~17 | 기존 로직만 (동의 검증 없이) | 사용 불가 |

---

## 결정 사항 요약

| 항목 | 결정 값 | 근거 |
|-----|--------|------|
| 동의용 임계값 (경로1) | 0.2 | 테스트에서 적절한 필터링 확인 |
| 경로2 임계값 | 0.0 | False Positive 최소화, 확실한 저품질만 |
| 스크린샷 감지 | isUtility 플래그 | Apple 모델 기반, 추가 비용 없음 |
| iOS 16~17 | 기존 로직만 | 점유율 감소, 유지보수 부담 최소화 |

---

## 현재 로직 vs 새 로직

### 현재 QualityAnalyzer 파이프라인

```
1. 메타데이터 필터링 (MetadataFilter)
   └─ 스크린샷, iCloud Only, 긴 동영상 등 SKIP

2. 유틸리티 이미지 체크
   └─ 휘도 극단 + RGB 표준편차 낮음 → SKIP

3. 텍스트 스크린샷 체크 (극단 노출일 때만)
   └─ 텍스트 블록 >= 5 → SKIP

4. 흰 배경 이미지 체크
   └─ 극단 밝음 + 모서리 순백색 → SKIP

5. 노출 분석 (ExposureAnalyzer)
   └─ 과노출, 과어두움 신호 생성

6. 블러 분석 (BlurAnalyzer)
   └─ 심한 블러, 일반 블러 신호 생성

7. Safe Guard 체크
   └─ 메타데이터 + 얼굴 품질 → 블러 신호 무효화

8. 최종 판정
   └─ Precision: Strong 신호 → 저품질
   └─ Recall: Strong OR Conditional OR Weak 합산
```

### 새 로직 (iOS 18+)

```
[기존 파이프라인 1~8 동일]
        ↓
    기존 판정 결과
        ↓
┌───────────────────────────────────────┐
│         AestheticsScore 통합          │
├───────────────────────────────────────┤
│                                       │
│  경로1: 기존 저품질 + 동의 필터       │
│  ┌─────────────────────────────────┐  │
│  │ 기존 verdict == lowQuality      │  │
│  │         ↓                       │  │
│  │ Strong 신호? ──YES──→ 저품질    │  │
│  │         │NO                     │  │
│  │         ↓                       │  │
│  │ AestheticsScore < 0.2 (동의)?   │  │
│  │    YES → 저품질 / NO → 제외     │  │
│  └─────────────────────────────────┘  │
│                                       │
│  경로2: AestheticsScore 기반          │
│  ┌─────────────────────────────────┐  │
│  │ AestheticsScore < 0.0           │  │
│  │         AND                     │  │
│  │ isUtility == false              │  │
│  │         ↓                       │  │
│  │     저품질 확정                 │  │
│  └─────────────────────────────────┘  │
│                                       │
│  최종 = 경로1 OR 경로2                │
└───────────────────────────────────────┘
```

---

## 구현 계획

### Phase 1: 상수 추가

**파일**: `CleanupConstants.swift`

```swift
// MARK: - AestheticsScore 통합

/// AestheticsScore 통합 활성화 여부
static let aestheticsIntegrationEnabled: Bool = true

/// 경로1: 동의용 임계값 (Weak/Conditional 신호에만 적용)
static let aestheticsAgreeThreshold: Float = 0.2

/// 경로2: 임계값 (AestheticsScore 기반 + 스크린샷 필터)
static let aestheticsPath2Threshold: Float = 0.0
```

### Phase 2: QualityAnalyzer 수정

**파일**: `QualityAnalyzer.swift`

1. AestheticsAnalyzer 의존성 추가
2. `analyze()` 함수에 AestheticsScore 통합 로직 추가
3. iOS 버전 분기 처리

**수정 위치**: `makeVerdict()` 함수 또는 새 함수 추가

```swift
// iOS 18+ AestheticsScore 통합
@available(iOS 18.0, *)
private func integrateAesthetics(
    oldVerdict: QualityVerdict,
    signals: [QualitySignal],
    image: CGImage
) async -> (isLowQuality: Bool, aestheticsApplied: Bool) {

    // 비활성화 시 기존 판정 유지
    guard CleanupConstants.aestheticsIntegrationEnabled else {
        return (oldVerdict.isLowQuality, false)
    }

    // AestheticsScore 분석
    guard let metrics = try? await aestheticsAnalyzer.analyze(image) else {
        // 분석 실패 시 기존 판정 유지
        return (oldVerdict.isLowQuality, false)
    }

    // 경로1: 기존 저품질 판정
    if oldVerdict.isLowQuality {
        // Strong 신호는 동의 없이 통과 (블러, 극단 노출)
        if signals.hasStrongSignal {
            return (true, true)
        }

        // Weak/Conditional 신호는 AestheticsScore 동의 필요
        if metrics.overallScore < CleanupConstants.aestheticsAgreeThreshold {
            // AestheticsScore 동의 → 저품질 확정
            return (true, true)
        } else {
            // AestheticsScore 동의 안 함 → 제외
            return (false, true)
        }
    }

    // 경로2: AestheticsScore 기반 + 스크린샷 필터
    if metrics.overallScore < CleanupConstants.aestheticsPath2Threshold {
        if !metrics.isUtility {
            // 스크린샷 아님 → 저품질 확정
            return (true, true)
        }
        // 스크린샷 → 제외
    }

    // 둘 다 해당 안 함 → 정상
    return (false, true)
}
```

### Phase 3: QualityResult 수정

**파일**: `QualityResult.swift`

AestheticsScore 관련 정보 추가 (디버깅용)

```swift
/// AestheticsScore 적용 여부
let aestheticsApplied: Bool

/// AestheticsScore 값 (디버깅용)
let aestheticsScore: Float?

/// 적용된 경로 (디버깅용)
enum AestheticsPath {
    case none           // 적용 안 됨
    case path1Strong    // 경로1: Strong 신호 (동의 없이 통과)
    case path1Agreed    // 경로1: Weak/Conditional + 동의
    case path1Rejected  // 경로1: Weak/Conditional + 동의 안 함 (제외)
    case path2Detected  // 경로2: AestheticsScore 기반 감지
    case path2Utility   // 경로2: 유틸리티로 제외
}
```

### Phase 4: 테스트

1. 기존 비교 분석 테스트 결과와 비교
2. 노란 딱지(onlyNew) 감소 확인 (0.0 임계값)
3. 파란 딱지(onlyOld) 중 정상 사진 제외 확인
4. 스크린샷 보호 확인

---

## 파일 수정 목록

| 파일 | 수정 내용 |
|-----|----------|
| `CleanupConstants.swift` | 새 임계값 상수 추가 |
| `QualityAnalyzer.swift` | AestheticsScore 통합 로직 |
| `QualityResult.swift` | AestheticsScore 정보 필드 추가 |

---

## 테스트 계획

### 1단계: 단위 테스트

- AestheticsAnalyzer 모킹
- 경로1, 경로2 각각 테스트
- iOS 버전 분기 테스트

### 2단계: 통합 테스트

- 실제 사진으로 테스트
- 비교 분석 테스트 (CompareAnalysisTester) 재실행
- 결과 비교:
  - 회색 딱지: 둘 다 해당 (경로1 + 경로2)
  - 파란 딱지: 경로1만 해당 (기존 로직 기반)
  - 노란 딱지: 경로2만 해당 (AestheticsScore 기반)

### 3단계: 사용자 검증

- 휴지통 결과 직접 확인
- False Positive/Negative 비율 확인
- 필요시 임계값 조정

---

## 롤백 계획

문제 발생 시 명시적 플래그로 비활성화:

```swift
// CleanupConstants.swift

/// AestheticsScore 통합 활성화 여부
/// false로 설정하면 기존 로직만 사용 (iOS 18+에서도)
static let aestheticsIntegrationEnabled: Bool = true
```

**사용 방법**:
- `aestheticsIntegrationEnabled = false` → 기존 로직만 사용
- `aestheticsIntegrationEnabled = true` → 새 로직 (경로1 + 경로2)

---

## 참고 문서

- `260127AestheticsScore3.md`: AestheticsScore 단독 테스트
- `CompareAnalysisTester.swift`: 비교 분석 테스트 코드
- `AestheticsAnalyzer.swift`: AestheticsScore 분석기
