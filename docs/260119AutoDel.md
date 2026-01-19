# 자동 정리 기능: 저품질 사진 판별 기획서 (v3)

**작성일**: 2026-01-19
**목적**: '정리' 버튼 클릭 시 저품질 사진 50장을 찾아 휴지통으로 이동하는 기능의 판별 로직 기획
**변경 이력**: v2(260114) → v3(260119) 보완 반영

---

## 0. 기능 개요

### 기능 흐름 (a → b → c)

| 단계 | 동작 | 상세 |
|:---:|------|------|
| **a** | 사용자가 '정리' 버튼 클릭 | 화면 상단 버튼 |
| **b** | 저품질 사진 탐색 | 현재 스크롤 위치 기준 과거 방향으로 스캔 |
| **c** | 50장 휴지통 이동 | 검토 후 TrashStore로 일괄 이동 |

### 핵심 목표

1. **저품질 사진의 정량적 정의** - 오탐지 최소화
2. **판별 로직 및 기능** - 고성능, 사용자 친화적

---

## 1. 저품질 사진의 정량적 정의

사용자의 소중한 추억을 보호하기 위해 **'확실한 기술적 실패'**만을 저품질로 규정한다.

### A. 판정 원칙

| 원칙 | 설명 | 적용 모드 |
|-----|------|:--------:|
| **강한 실패 신호 (Strong)** | 단일 항목만으로 즉시 저품질 확정 | 모든 모드 |
| **조건부 실패 신호 (Conditional)** | 기술적 실패지만 오탐 위험 있음 | Recall 모드만 |
| **약한 실패 신호 (Weak)** | 2개 이상 조합 시 저품질 확정 | Recall 모드만 |
| **스크린샷** | 기술적 실패 아님 → 별도 카테고리로 분리 | - |

### B. 정량적 기준

| 구분 | 항목 | 상세 기준 (Threshold) | 근거 |
|:---:|------|----------------------|------|
| **Strong** | 극단 노출 (어두움) | 평균 휘도 < 0.10 (25/255) | GitHub Gist |
| | 극단 노출 (밝음) | 평균 휘도 > 0.90 (230/255) | GitHub Gist |
| | 심각 블러 | Laplacian Variance < 50 | PyImageSearch 기준의 50% |
| **Conditional** | 주머니 샷 | 휘도<0.10 AND RGB Std<15 AND Lap<50 AND 비네팅<0.05 | 복합 조건 |
| | 극단 단색 | RGB Std<10 AND (휘도<0.15 OR >0.85) | 단색 + 노출 복합 |
| | 렌즈 가림 | 모서리 휘도 < 중앙 휘도 × 0.4 OR 모서리 휘도 < 0.15 | 3×3 그리드 분석 |
| **Weak** | 일반 블러 | Laplacian Variance < 100 | PyImageSearch 권장 |
| | 일반 노출 (평균) | 휘도 < 0.15 또는 > 0.85 | 완화된 기준 |
| | 일반 노출 (분포) | 어두운 픽셀(0~50) ≥ 40% OR 밝은 픽셀(200~255) ≥ 65% | 클리핑 비율 |
| | 낮은 색상 다양성 | RGB Std < 15 | 단조로운 이미지 |
| | 저해상도 | < 1MP (1,000,000 픽셀) | VGA 이하 |

### C. 안전장치 (Safe Guard)

저품질 판정 시에도 아래 조건 충족 시 **정상 사진으로 복구**.

| 적용 시점 | 조건 | PHAsset 속성 | Stage | 효과 |
|----------|------|-------------|:-----:|------|
| **조기 필터** | 즐겨찾기 | `isFavorite == true` | 1 | 전체 분석 건너뜀 |
| | 편집됨 | `hasAdjustments == true` | 1 | 전체 분석 건너뜀 |
| **후처리 필터** | 심도 효과 | `mediaSubtypes.contains(.photoDepthEffect)` | 4 | 블러 판정만 무효화 |
| | 선명한 얼굴 | `VNFaceCaptureQuality >= 0.4` | 4 | 블러 판정만 무효화 |

### D. 스크린샷 처리 정책

| 항목 | 정책 |
|-----|------|
| **판별** | `mediaSubtypes.contains(.photoScreenshot)` |
| **처리** | 저품질 로직에서 **제외 (Pass)** |
| **향후** | 별도 "스크린샷 정리" 카테고리로 관리 예정 |

---

## 2. 판별 모드 (Precision vs Recall)

사용자 선택 또는 설정에 따라 모드 전환 가능.

### Precision 모드 (기본값)

| 항목 | 값 |
|-----|---|
| **목적** | 오탐지 최소화 (소중한 사진 보호) |
| **판정** | Strong 신호만 사용 |
| **Conditional** | 사용 안함 |
| **Weak 조합** | 사용 안함 |
| **임계값** | 엄격 (휘도<0.10, Lap<50) |

**Conditional 제외 사유 (오탐 위험)**:

| 제외 항목 | 제외 사유 |
|----------|----------|
| 렌즈 가림 | 비네팅/예술 사진 오탐 가능성 |
| 극단 단색 | 문서/메모 사진 오탐 가능성 |
| 주머니샷 복합 | 야경/실루엣 사진 오탐 가능성 |

### Recall 모드 (공격적)

| 항목 | 값 |
|-----|---|
| **목적** | 커버리지 최대화 (더 많은 저품질 탐지) |
| **판정** | Strong + Conditional + Weak 조합 사용 |
| **Conditional** | 단일 항목으로 저품질 확정 |
| **Weak 조합** | 2개 이상 충족 시 저품질 (모든 조합 동등, 특정 조합 제외 없음) |
| **임계값** | 완화 (휘도<0.15, Lap<100) |

### 모드별 신호 활성화 요약

| 구분 | 항목 | Precision | Recall |
|:---:|------|:---------:|:------:|
| Strong | 극단 노출, 심각 블러 | O | O |
| Conditional | 렌즈 가림, 주머니 샷, 극단 단색 | X | O |
| Weak | 일반 블러, 일반 노출, 저해상도 등 | X | 2+조합 |

---

## 3. 판별 파이프라인 (4단계)

비용이 낮은 검사를 먼저 수행하여 성능 최적화.

```
┌─────────────────────────────────────────────────────────────┐
│  Stage 1: MetadataFilter                    [비용: 최저]    │
│  ─────────────────────────────────────────────────────────  │
│  입력: PHAsset                                              │
│  처리:                                                      │
│    • isFavorite → SKIP (정상) [Safe Guard 조기 필터]        │
│    • hasAdjustments → SKIP (정상) [Safe Guard 조기 필터]    │
│    • isScreenshot → SEPARATE (별도 카테고리)                 │
│  출력: Stage 2로 전달 또는 SKIP                              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Stage 2: ExposureAnalyzer                  [비용: 중간]    │
│  ─────────────────────────────────────────────────────────  │
│  입력: PHAsset + 64×64 CGImage                              │
│  계산:                                                      │
│    • 평균 휘도 (Y = 0.299R + 0.587G + 0.114B)               │
│    • RGB 표준편차                                           │
│    • 모서리 vs 중앙 휘도 비교 (3×3 그리드)                   │
│  판정:                                                      │
│    • 극단 노출 → LOW_QUALITY (Strong - 모든 모드)           │
│    • 극단 단색 → LOW_QUALITY (Conditional - Recall만)       │
│    • 렌즈 가림 → LOW_QUALITY (Conditional - Recall만)       │
│    • 주머니 샷 → LOW_QUALITY (Conditional - Recall만)       │
│  출력: Stage 3로 전달 또는 LOW_QUALITY                       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Stage 3: BlurAnalyzer                      [비용: 최고]    │
│  ─────────────────────────────────────────────────────────  │
│  입력: PHAsset + 256×256 CGImage                            │
│  계산:                                                      │
│    • Laplacian Variance (Metal GPU 가속)                    │
│  판정:                                                      │
│    • Lap < 50 → LOW_QUALITY (Strong - 심각 블러)            │
│    • Lap < 100 → WEAK_SIGNAL (Recall 모드용)                │
│  출력: Stage 4로 전달                                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Stage 4: SafeGuardFilter               [최종 예외 처리]    │
│  ─────────────────────────────────────────────────────────  │
│  입력: 저품질 후보 + 판정 사유                               │
│  처리:                                                      │
│    • 블러 판정인 경우: [Safe Guard 후처리 필터]              │
│      - depthEffect 확인 → SKIP                              │
│      - FaceQuality >= 0.4 확인 → SKIP                       │
│    • 노출/단색/렌즈가림 판정인 경우:                         │
│      - 후처리 Safe Guard 해당 없음 (그대로 LOW_QUALITY)      │
│  출력: 최종 LOW_QUALITY 확정 또는 SKIP                       │
└─────────────────────────────────────────────────────────────┘
```

### 파이프라인 요약

| Stage | 이름 | 입력 | 비용 | 판정 항목 |
|:-----:|------|------|:----:|----------|
| 1 | MetadataFilter | PHAsset | 최저 | 즐겨찾기, 편집됨, 스크린샷 (Safe Guard 조기) |
| 2 | ExposureAnalyzer | 64×64 이미지 | 중간 | 노출(Strong), 단색/렌즈가림(Conditional) |
| 3 | BlurAnalyzer | 256×256 이미지 | 최고 | 블러 |
| 4 | SafeGuardFilter | 후보 | 조건부 | 심도 효과, 얼굴 품질 (Safe Guard 후처리) |

---

## 4. 탐색 및 실행 로직

### A. 스캔 전략

| 항목 | 값 | 설명 |
|-----|---|------|
| **시작점** | `anchorIndex` | 현재 화면 최상단 사진의 인덱스 |
| **방향** | 과거 (역순) | 오래된 사진일수록 정리 필요성 높음, 최근 사진은 사용자 판단 전 |
| **종료 조건** | 50장 도달 | 저품질 후보 50장 수집 시 즉시 중단 |
| **최대 스캔** | 제한 없음 | 라이브러리 끝까지 (또는 50장 도달) |

### B. 성능 제약

| 항목 | 값 | 근거 |
|-----|---|------|
| **배치 크기** | 100장 | 메모리 점유 vs fetch 오버헤드 균형 |
| **동시 분석** | 4개 | CPU 코어 수 기준 (TaskGroup) |
| **다운샘플 (노출)** | 64×64 | 휘도/색상 계산에 충분 |
| **다운샘플 (블러)** | 256×256 | Laplacian 정확도 확보 |
| **이미지 옵션** | `.fastFormat`, `.fast` | PHImageRequestOptions |
| **iCloud** | 제외 | `isNetworkAccessAllowed = false` |
| **비디오 분석 타임아웃** | 5초 | 긴 영상 대비 |
| **비디오 길이 제한** | 10분 초과 시 SKIP | 대용량 영상 제외 |
| **비디오 동시 처리** | 2개 | 메모리 부담 완화 |

### C. 메모리 관리

| 상황 | 대응 |
|-----|------|
| **정상** | 배치 100장, 동시 4개 |
| **메모리 경고** | 배치 50장으로 축소, 동시 2개 |
| **임시 객체** | `autoreleasepool` 적용 |
| **PHAsset 참조** | `localIdentifier`로 간접 참조 |

### D. 에러 처리

| 에러 | 대응 | UX 메시지 |
|-----|------|----------|
| 이미지 로드 실패 | 해당 사진 SKIP, 다음 진행 | - |
| Vision 분석 실패 | Safe Guard 미적용, 후보 유지 | - |
| 메모리 부족 | 스캔 중단, 현재까지 결과 반환 | "분석이 중단되었습니다. N장을 찾았습니다." |
| 완전 실패 | 빈 결과 | "분석에 실패했습니다. 다시 시도해주세요." |

### E. 미디어 타입별 처리

| 미디어 타입 | 분석 방법 | 비고 |
|------------|----------|------|
| **사진** | 원본 이미지 다운샘플링 후 분석 | 기본 흐름 |
| **라이브포토** | 키 프레임(대표 이미지) 분석 | 비디오 부분 무시 |
| **비디오** | 대표 프레임 3개 추출 (시작/중간/끝) 후 분석 | 중앙값 기준 판정 |

**비디오 분석 상세**:
- `AVAssetImageGenerator`로 프레임 추출
- 시작(0%), 중간(50%), 끝(100%) 지점
- 3개 프레임 중 **중앙값 품질 기준**으로 판정 (과탐지 방지)

### F. 연속 촬영(Burst) 처리 (선택적)

- 동일 시간대(±1초) 연속 사진은 그룹으로 묶음
- 그룹 내에서 가장 품질이 낮은 1장만 후보로 선정
- 유사 사진이 50장을 독점하는 것 방지

---

## 5. UX 흐름

### 5.0 iCloud 안내 (스캔 전)

로컬 사진 비율이 낮을 경우 (예: < 30%):
```
┌─────────────────────────────────────┐
│  대부분의 사진이 iCloud에 있습니다    │
│  로컬에 저장된 사진만 분석됩니다      │
│                                     │
│  [확인]        [iCloud 사진 다운로드] │
└─────────────────────────────────────┘
```

**후보군 선택적 다운로드** (선택적 구현):
- 메타데이터로 1차 필터링 후
- 후보군에 대해서만 iCloud 다운로드 수행

### 5.1 스캔 피드백

```
┌─────────────────────────────────┐
│  저품질 사진 찾는 중...         │
│  ████████░░░░░░░░  23/50        │
│                      [취소]     │
└─────────────────────────────────┘
```

- 진행률 표시: `n/50` (50장 이상 예상 시) 또는 `분석 중... (n장 발견)`
- 취소 버튼 제공

### 5.2 검토 단계 (Review)

```
┌─────────────────────────────────┐
│  50장의 저품질 사진을 찾았습니다  │
├─────────────────────────────────┤
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐       │
│  │ ✓ │ │ ✓ │ │   │ │ ✓ │ ...   │
│  └───┘ └───┘ └───┘ └───┘       │
│  선택 해제한 사진은 유지됩니다    │
├─────────────────────────────────┤
│  [취소]              [삭제 (47)]│
└─────────────────────────────────┘
```

- 후보 사진 그리드 표시
- 개별 사진 선택 해제 (Keep) 가능
- 삭제 버튼에 최종 개수 표시

### 5.3 일괄 삭제

- `TrashStore`를 통해 단일 트랜잭션으로 이동
- 시스템 사진 앱 휴지통이 아닌 **앱 내 휴지통**

### 5.4 사후 처리

```
┌─────────────────────────────────┐
│  47장이 휴지통으로 이동되었습니다 │
│                        [실행취소]│
└─────────────────────────────────┘
```

- 토스트 메시지 (3초)
- Undo 버튼 제공

### 5.5 엣지 케이스 UX

| 상황 | 동작 | UX 메시지 |
|-----|------|----------|
| 50장 이상 | 50장에서 중단 | "50장의 저품질 사진을 찾았습니다" |
| 1~49장 | 전체 스캔 후 종료 | "N장의 저품질 사진을 찾았습니다" |
| 0장 | 전체 스캔 후 종료 | "저품질 사진을 찾지 못했습니다" |

### 5.6 앱 내 휴지통 정책

| 항목 | 정책 | 근거 |
|-----|------|------|
| 보관 기간 | 30일 | 시스템 휴지통과 동일 |
| 자동 삭제 | 30일 후 영구 삭제 | - |
| Undo 범위 | 세션 내 (앱 종료 전) | 메모리 기반 |
| 용량 안내 | "시스템 앨범에서 삭제해야 실제 용량 확보" | 사용자 혼란 방지 |

---

## 6. 기술 구현 참조

### 6.1 iOS 버전별 전략

| iOS 버전 | 전략 |
|---------|------|
| **iOS 18+** | `CalculateImageAestheticsScoresRequest` 우선 사용 |
| **iOS 16-17** | Metal Laplacian + Luminance Fallback |

**iOS 18+ 상세 전략**:
```
1. AestheticsScore 분석 시도
2. 성공 시:
   - overallScore < 0 → LOW_QUALITY (기존 파이프라인 대체)
   - isUtility == true → UTILITY 카테고리 (스크린샷과 동일 취급)
3. 실패 시 (시뮬레이터 등):
   - 기존 4단계 파이프라인으로 Fallback
```

### 6.2 iOS 18 AestheticsScore API

```swift
import Vision

func analyzeWithAesthetics(image: UIImage) async throws -> Bool {
    guard let ciimage = CIImage(image: image) else { return false }
    let request = CalculateImageAestheticsScoresRequest()
    let observation = try await request.perform(on: ciimage)

    // overallScore < 0 → 저품질
    // isUtility == true → 스크린샷/문서 (별도 처리)
    return observation.overallScore < 0
}
```

**제한사항**: 시뮬레이터 미지원

### 6.3 Metal Laplacian Blur Detection

```swift
import Metal
import MetalPerformanceShaders

class BlurDetector {
    let device: MTLDevice
    let laplacian: MPSImageLaplacian
    let meanAndVariance: MPSImageStatisticsMeanAndVariance

    func detectBlur(texture: MTLTexture) -> Float {
        // 1. Laplacian 필터 적용
        // 2. Mean & Variance 계산
        // 3. Variance 반환 (낮을수록 흐림)
        return variance  // < 100 → 블러
    }
}
```

**성능**: iPhone 8 기준 1000×600 이미지에서 **3~9ms**

### 6.4 휘도 계산

```swift
func calculateMeanLuminance(cgImage: CGImage) -> Double {
    // ITU-R BT.601: Y = 0.299R + 0.587G + 0.114B
    // 반환값: 0.0 ~ 1.0 (0~255를 정규화)
}
```

### 6.5 얼굴 품질 검증

```swift
import Vision

func detectFaceQuality(cgImage: CGImage) throws -> Float? {
    let request = VNDetectFaceCaptureQualityRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try handler.perform([request])
    return request.results?.first?.faceCaptureQuality
    // >= 0.4 → 선명한 얼굴
}
```

### 6.6 비네팅 계산

```swift
func calculateVignetting(cgImage: CGImage) -> Double {
    // 비네팅 = 1 - (모서리 평균 휘도 / 중앙 평균 휘도)
    //
    // 3×3 그리드 기준:
    // - 중앙: (1,1) 셀
    // - 모서리: (0,0), (0,2), (2,0), (2,2) 셀의 평균
    //
    // 결과: 0.0 (비네팅 없음) ~ 1.0 (완전 어두운 모서리)
    // 주머니 샷 기준: < 0.05 (모서리와 중앙 차이 거의 없음)
}
```

---

## 7. 임계값 근거 요약

| 파라미터 | 값 | 출처 |
|---------|---|------|
| Laplacian Variance (심각) | < 50 | PyImageSearch 100의 50% |
| Laplacian Variance (일반) | < 100 | PyImageSearch 권장 |
| 평균 휘도 (어두움) | < 0.10 | GitHub Gist (34/255 기반) |
| 평균 휘도 (밝음) | > 0.90 | GitHub Gist (227/255 기반) |
| RGB 표준편차 (단색) | < 10 | 경험적 |
| Face Quality | >= 0.4 | Apple Vision 기준 |
| Aesthetics Score | < 0 | Apple WWDC24 |
| 비네팅 (주머니 샷) | < 0.05 | 경험적 |

---

## 8. 검증 계획 (선택적)

### 8.1 테스트 데이터셋
- 수동 레이블링된 샘플 (저품질/정상/엣지케이스)
- 야경, 실루엣, 의도적 블러, 빈티지 필터 등 포함
- iOS 18 시뮬레이터 미지원 대비 Mock 데이터 준비

### 8.2 목표 지표

| 모드 | Precision | Recall |
|-----|:---------:|:------:|
| Precision | >= 95% | >= 60% |
| Recall | >= 80% | >= 85% |

### 8.3 사용자 피드백
- "Keep" 선택 비율 모니터링 (오탐 지표)
- Undo 비율 모니터링

---

## 참고 문서

- [Apple - Vision Framework](https://developer.apple.com/documentation/vision)
- [Apple - Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
- [PyImageSearch - Blur detection with OpenCV](https://pyimagesearch.com/2015/09/07/blur-detection-with-opencv/)
