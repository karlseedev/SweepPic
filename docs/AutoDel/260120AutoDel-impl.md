# 자동 정리 기능: 기술 구현 참조

**관련 문서**: [260120AutoDel.md](./260120AutoDel.md) (핵심 기획서)

---

## 1. iOS 버전별 전략

| iOS 버전 | 전략 |
|---------|------|
| **iOS 18+** | `CalculateImageAestheticsScoresRequest` 우선 사용 |
| **iOS 16-17** | Metal Laplacian + Luminance Fallback |

**iOS 18+ 상세 전략**:
```
0. Stage 1 (MetadataFilter) 선행 적용 ← 필수!
   - isFavorite, hasAdjustments, isHidden, 공유앨범 → SKIP
   - isScreenshot → SEPARATE

1. AestheticsScore 분석 시도
2. 성공 시:
   - Precision 모드: overallScore < -0.3 → LOW_QUALITY
   - Recall 모드: overallScore < 0 → LOW_QUALITY
   - isUtility == true → UTILITY 카테고리 (스크린샷과 동일 취급)
3. 실패 시 (시뮬레이터 등):
   - 기존 Stage 2~4 파이프라인으로 Fallback
```

> **중요**: AestheticsScore 사용 시에도 Stage 1 Safe Guard(즐겨찾기/편집됨)는 반드시 선행 적용됩니다.

---

## 2. iOS 18 AestheticsScore API

**모드별 임계값:**

| 모드 | 임계값 | 근거 |
|:---:|:------:|------|
| **Precision** | overallScore < **-0.3** | 설계값 (확실한 저품질만 선별, 테스트 검증 필요) |
| **Recall** | overallScore < **0** | 설계값 (Apple 문서상 0 미만은 낮은 품질) |

> **임계값 선정 근거**:
> - API 출처: Apple WWDC24 `CalculateImageAestheticsScoresRequest`
> - `overallScore` 범위: -1 ~ 1 (높을수록 미적으로 우수)
> - **Apple은 공식 임계값을 권장하지 않음** - "개발자가 용도에 맞게 설정"
> - -0.3과 0은 설계값이며, 테스트를 통해 조정 필요

```swift
import Vision

func analyzeWithAesthetics(image: UIImage, mode: JudgmentMode) async throws -> Bool {
    guard let ciimage = CIImage(image: image) else { return false }
    let request = CalculateImageAestheticsScoresRequest()
    let observation = try await request.perform(on: ciimage)

    // 모드별 임계값 적용 (설계값 - 테스트 검증 필요)
    let threshold: Float = (mode == .precision) ? -0.3 : 0.0

    // isUtility == true → 스크린샷/문서 (별도 처리)
    return observation.overallScore < threshold
}
```

**제한사항**: 시뮬레이터 미지원

---

## 3. Metal Laplacian Blur Detection

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

---

## 4. 휘도 계산

```swift
func calculateMeanLuminance(cgImage: CGImage) -> Double {
    // ITU-R BT.601: Y = 0.299R + 0.587G + 0.114B
    // 반환값: 0.0 ~ 1.0 (0~255를 정규화)
}
```

---

## 5. 얼굴 품질 검증

```swift
import Vision

func detectFaceQuality(cgImage: CGImage) throws -> Float? {
    let request = VNDetectFaceCaptureQualityRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try handler.perform([request])
    return request.results?.first?.faceCaptureQuality
    // >= 0.4 → 선명한 얼굴로 판정 (블러 Safe Guard)
    //
    // ※ Apple 권고: faceCaptureQuality는 같은 피사체 간 상대 비교용
    // ※ 본 기능: 최소 품질 판정 목적으로 절대 임계값 사용 (용도 다름)
    // ※ 0.4는 설계값이며, 테스트를 통해 적절성 검증 필요
}
```

---

## 6. 비네팅 계산

```swift
func calculateVignetting(cgImage: CGImage) -> Double {
    // 비네팅 = 1 - (모서리 평균 휘도 / 중앙 평균 휘도)
    //
    // 3×3 그리드 기준:
    // - 중앙: (1,1) 셀
    // - 모서리: (0,0), (0,2), (2,0), (2,2) 셀의 평균
    //
    // 결과: 0.0 (비네팅 없음) ~ 1.0 (완전 어두운 모서리)
    // 주머니 샷 기준: < 0.05 (모서리와 중앙 차이 거의 없음) - 설계값
    //
    // ⚠️ 예외 처리: 중앙 휘도 < 0.01인 경우 (완전 흑)
    //    - Division by zero 방지
    //    - 비네팅 계산 불가 → 0.0 반환 (비네팅 없음 취급)
    //    - 이 경우 극단 노출(어두움)로 이미 LOW_QUALITY 판정됨
}
```

---

## 7. 임계값 근거 상세

| 파라미터 | 값 | 출처 | 비고 |
|---------|---|------|------|
| Laplacian Variance (심각) | < 50 | 설계값 | PyImageSearch 100 기준 심각 블러용 50% 적용 |
| Laplacian Variance (일반) | < 100 | [PyImageSearch](https://pyimagesearch.com/2015/09/07/blur-detection-with-opencv/) | 데이터셋별 튜닝 필요 |
| 평균 휘도 (어두움) | < 0.10 | 설계값 | GitHub Gist 0.133 기준 Precision용 엄격값 |
| 평균 휘도 (밝음) | > 0.90 | [GitHub Gist](https://gist.github.com/adamcichy/2d00c7a54009b4a9751ba513749c485e) | 227/255 ≈ 0.890 |
| RGB 표준편차 (단색) | < 10 | 설계값 | 테스트 검증 필요 |
| RGB 표준편차 (색상 다양성) | < 15 | 설계값 | 테스트 검증 필요 |
| Face Quality | >= 0.4 | 설계값 | Apple 권고(상대비교)와 용도 다름, 테스트 검증 필요 |
| Aesthetics Score (Precision) | < -0.3 | 설계값 | API: [Apple WWDC24](https://developer.apple.com/videos/play/wwdc2024/10163/) |
| Aesthetics Score (Recall) | < 0 | 설계값 | API: Apple WWDC24, 0 미만=낮은 품질 |
| 비네팅 (주머니 샷) | < 0.05 | 설계값 | 테스트 검증 필요 |

---

## 참고 문서

### Apple 공식
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
- [CalculateImageAestheticsScoresRequest](https://developer.apple.com/documentation/vision/calculateimageaestheticsscoresrequest)
- [VNDetectFaceCaptureQualityRequest](https://developer.apple.com/documentation/vision/vndetectfacecapturequalityrequest)
- [Selecting a selfie based on capture quality](https://developer.apple.com/documentation/Vision/selecting-a-selfie-based-on-capture-quality)

### WWDC
- [WWDC21 - Detect people, faces, and poses using Vision](https://developer.apple.com/videos/play/wwdc2021/10040/)
- [WWDC24 - Discover Swift enhancements in Vision framework](https://developer.apple.com/videos/play/wwdc2024/10163/)

### 외부 참고
- [PyImageSearch - Blur detection with OpenCV](https://pyimagesearch.com/2015/09/07/blur-detection-with-opencv/)
- [GitHub Gist - Determine if UIImage is dark or light](https://gist.github.com/adamcichy/2d00c7a54009b4a9751ba513749c485e)
