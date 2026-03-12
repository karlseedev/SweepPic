# 자동 정리 기능: 저품질 사진 판별 기획서 (v2)

**작성일**: 2026-01-14
**목적**: '정리' 버튼 클릭 시 저품질 사진 50장을 찾아 휴지통으로 이동하는 기능의 판별 로직 기획

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

| 원칙 | 설명 |
|-----|------|
| **강한 실패 신호 (Strong)** | 단일 항목만으로 즉시 저품질 확정 |
| **약한 실패 신호 (Weak)** | 2개 이상 조합 시 저품질 확정 (Recall 모드 전용) |
| **스크린샷** | 기술적 실패 아님 → 별도 카테고리로 분리 |

### B. 정량적 기준

| 구분 | 항목 | 상세 기준 (Threshold) | 근거 |
|:---:|------|----------------------|------|
| **Strong** | 극단 노출 (어두움) | 평균 휘도 < 0.10 (25/255) | GitHub Gist |
| | 극단 노출 (밝음) | 평균 휘도 > 0.90 (230/255) | GitHub Gist |
| | 심각 블러 | Laplacian Variance < 50 | PyImageSearch 기준의 50% |
| | 주머니 샷 | 휘도<0.10 AND RGB Std<15 AND Lap<50 AND 비네팅<0.05 | 복합 조건 |
| | 극단 단색 | RGB Std<10 AND (휘도<0.15 OR >0.85) | 단색 + 노출 복합 |
| | 렌즈 가림 | 모서리 휘도 < 중앙 휘도 × 0.4 OR 모서리 휘도 < 0.15 | 3×3 그리드 분석 |
| **Weak** | 일반 블러 | Laplacian Variance < 100 | PyImageSearch 권장 |
| | 일반 노출 (평균) | 휘도 < 0.15 또는 > 0.85 | 완화된 기준 |
| | 일반 노출 (분포) | 어두운 픽셀(0~50) ≥ 40% OR 밝은 픽셀(200~255) ≥ 65% | 클리핑 비율 |
| | 낮은 색상 다양성 | RGB Std < 15 | 단조로운 이미지 |
| | 저해상도 | < 1MP (1,000,000 픽셀) | VGA 이하 |

### C. 안전장치 (Safe Guard)

저품질 판정 시에도 아래 조건 충족 시 **정상 사진으로 복구**.

| 적용 범위 | 조건 | PHAsset 속성 |
|----------|------|-------------|
| **전체 무효** | 즐겨찾기 | `isFavorite == true` |
| | 편집됨 | `hasAdjustments == true` |
| **블러만 무효** | 심도 효과 | `mediaSubtypes.contains(.photoDepthEffect)` |
| | 선명한 얼굴 | `VNFaceCaptureQuality >= 0.4` |

**적용 위치**: Stage 4 (판정 직전 최종 필터)

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
| **Weak 조합** | 사용 안함 |
| **임계값** | 엄격 (휘도<0.10, Lap<50) |

**의도적으로 제외한 항목 (오탐 위험)**:

| 제외 항목 | 제외 사유 |
|----------|----------|
| 렌즈 가림 | 비네팅/예술 사진 오탐 가능성 |
| 단색/무의미 | 문서/메모 사진 오탐 가능성 |
| 저해상도 | 오래된 추억 사진 오탐 가능성 |
| 주머니샷 복합 | 야경/실루엣 사진 오탐 가능성 |

### Recall 모드 (공격적)

| 항목 | 값 |
|-----|---|
| **목적** | 커버리지 최대화 (더 많은 저품질 탐지) |
| **판정** | Strong + Weak 조합 사용 |
| **Weak 조합** | 2개 이상 충족 시 저품질 |
| **임계값** | 완화 (휘도<0.15, Lap<100) |

---

## 3. 판별 파이프라인 (4단계)

비용이 낮은 검사를 먼저 수행하여 성능 최적화.

```
┌─────────────────────────────────────────────────────────────┐
│  Stage 1: MetadataFilter                    [비용: 최저]    │
│  ─────────────────────────────────────────────────────────  │
│  입력: PHAsset                                              │
│  처리:                                                      │
│    • isFavorite → SKIP (정상)                               │
│    • hasAdjustments → SKIP (정상)                           │
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
│    • 극단 노출 → LOW_QUALITY (Strong)                       │
│    • 극단 단색 → LOW_QUALITY (Strong)                       │
│    • 렌즈 가림 → LOW_QUALITY (Strong)                       │
│    • 주머니 샷 → LOW_QUALITY (Strong)                       │
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
│    • 블러 판정인 경우:                                       │
│      - depthEffect 확인 → SKIP                              │
│      - FaceQuality >= 0.4 확인 → SKIP                       │
│    • 노출 판정인 경우:                                       │
│      - Safe Guard 적용 안함 (이미 Stage 1에서 처리)          │
│  출력: 최종 LOW_QUALITY 확정 또는 SKIP                       │
└─────────────────────────────────────────────────────────────┘
```

### 파이프라인 요약

| Stage | 이름 | 입력 | 비용 | 판정 항목 |
|:-----:|------|------|:----:|----------|
| 1 | MetadataFilter | PHAsset | 최저 | 즐겨찾기, 편집됨, 스크린샷 |
| 2 | ExposureAnalyzer | 64×64 이미지 | 중간 | 노출, 단색, 렌즈 가림 |
| 3 | BlurAnalyzer | 256×256 이미지 | 최고 | 블러 |
| 4 | SafeGuardFilter | 후보 | 조건부 | 심도 효과, 얼굴 품질 |

---

## 4. 탐색 및 실행 로직

### A. 스캔 전략

| 항목 | 값 | 설명 |
|-----|---|------|
| **시작점** | `anchorIndex` | 현재 화면 최상단 사진의 인덱스 |
| **방향** | 과거 (역순) | 인덱스 감소 방향으로 탐색 |
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

### C. 메모리 관리

| 상황 | 대응 |
|-----|------|
| **정상** | 배치 100장, 동시 4개 |
| **메모리 경고** | 배치 50장으로 축소, 동시 2개 |
| **임시 객체** | `autoreleasepool` 적용 |
| **PHAsset 참조** | `localIdentifier`로 간접 참조 |

### D. 에러 처리

| 에러 | 대응 |
|-----|------|
| 이미지 로드 실패 | 해당 사진 SKIP, 다음 진행 |
| Vision 분석 실패 | Safe Guard 미적용, 후보 유지 |
| 메모리 부족 | 스캔 중단, 현재까지 결과 반환 |

### E. 미디어 타입별 처리

| 미디어 타입 | 분석 방법 | 비고 |
|------------|----------|------|
| **사진** | 원본 이미지 다운샘플링 후 분석 | 기본 흐름 |
| **라이브포토** | 키 프레임(대표 이미지) 분석 | 비디오 부분 무시 |
| **비디오** | 대표 프레임 3개 추출 (시작/중간/끝) 후 분석 | 최악 프레임 기준 판정 |

**비디오 분석 상세**:
- `AVAssetImageGenerator`로 프레임 추출
- 시작(0%), 중간(50%), 끝(100%) 지점
- 3개 프레임 중 **최저 품질 기준**으로 판정 (보수적)

---

## 5. UX 흐름

### 5.1 스캔 피드백

```
┌─────────────────────────────────┐
│  저품질 사진 찾는 중...         │
│  ████████░░░░░░░░  23/50        │
│                      [취소]     │
└─────────────────────────────────┘
```

- 진행률 표시: `n/50`
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
- 삭제 완료 안내

---

## 6. 기술 구현 참조

### 6.1 iOS 버전별 전략

| iOS 버전 | 전략 |
|---------|------|
| **iOS 18+** | `CalculateImageAestheticsScoresRequest` 우선 사용 |
| **iOS 16-17** | Metal Laplacian + Luminance Fallback |

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

---

## 참고 문서

- [Apple - Vision Framework](https://developer.apple.com/documentation/vision)
- [Apple - Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
- [PyImageSearch - Blur detection with OpenCV](https://pyimagesearch.com/2015/09/07/blur-detection-with-opencv/)
