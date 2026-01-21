# Research: 저품질 사진 자동 정리

**Feature**: 001-auto-cleanup
**Date**: 2026-01-21
**Status**: Complete

---

## 1. Laplacian Variance (블러 감지)

### Decision
- 심각 블러: Laplacian Variance < 50
- 일반 블러: Laplacian Variance < 100

### Rationale
- PyImageSearch 권장값 100을 기준으로 심각 블러 판정을 위해 50% 적용
- 오탐지 최소화(Precision 모드)를 위해 엄격한 임계값 사용
- 데이터셋 의존적이므로 테스트를 통한 튜닝 필요

### Alternatives Considered
- 고정 100 사용: 일반 블러도 저품질로 판정되어 오탐 위험
- 동적 임계값: 구현 복잡도 증가, 1차에서는 고정값 사용

### Implementation
```swift
import MetalPerformanceShaders

// MPSImageLaplacian + MPSImageStatisticsMeanAndVariance
// 256×256 다운샘플링 후 분석
// iPhone 8 기준 3~9ms 성능
```

### References
- [PyImageSearch - Blur detection with OpenCV](https://pyimagesearch.com/2015/09/07/blur-detection-with-opencv/)

---

## 2. 휘도 (노출 분석)

### Decision
- 극단 어두움: 휘도 < 0.10
- 극단 밝음: 휘도 > 0.90

### Rationale
- GitHub Gist 기준 (34/255 ≈ 0.133, 227/255 ≈ 0.890)보다 엄격한 값 적용
- Precision 모드에서 야경, 실루엣 등 의도적 노출 보호
- ITU-R BT.601 표준 공식 사용: Y = 0.299R + 0.587G + 0.114B

### Alternatives Considered
- 0.15/0.85 (완화): Recall 모드용으로 예약
- 히스토그램 분석: 구현 복잡도 대비 효과 불명확

### Implementation
```swift
// 64×64 다운샘플링으로 충분
// 픽셀별 휘도 계산 후 평균
func calculateMeanLuminance(cgImage: CGImage) -> Double {
    // Y = 0.299R + 0.587G + 0.114B
    // 반환값: 0.0 ~ 1.0
}
```

### References
- [GitHub Gist - Determine if UIImage is dark or light](https://gist.github.com/adamcichy/2d00c7a54009b4a9751ba513749c485e)

---

## 3. RGB 표준편차 (색상 분석)

### Decision
- 극단 단색: RGB Std < 10
- 낮은 색상 다양성: RGB Std < 15

### Rationale
- 주머니 샷, 렌즈 가림 등 단색 이미지 감지
- 설계값으로 테스트 검증 필요
- 문서/메모 사진 오탐 주의

### Alternatives Considered
- HSV 색상 분석: 추가 변환 비용, 효과 불명확
- 색상 히스토그램: 구현 복잡도 증가

### Implementation
```swift
// 64×64 다운샘플링
// 전체 픽셀의 R, G, B 채널별 표준편차 평균
```

---

## 4. AestheticsScore (iOS 18+)

### Decision
- Precision 모드: overallScore < -0.3
- Recall 모드: overallScore < 0
- isUtility == true → 스크린샷/문서 취급 (별도 카테고리)

### Rationale
- Apple WWDC24에서 소개된 새 API
- overallScore 범위: -1 ~ 1 (높을수록 미적으로 우수)
- Apple은 공식 임계값을 권장하지 않음 - 용도별 설정 필요
- -0.3과 0은 설계값, 테스트 필요

### Alternatives Considered
- 임계값 0만 사용: Precision/Recall 구분 불가
- API 미사용: iOS 18의 향상된 판별 능력 활용 불가

### Implementation
```swift
import Vision

@available(iOS 18.0, *)
func analyzeWithAesthetics(image: CIImage) async throws -> Float {
    let request = CalculateImageAestheticsScoresRequest()
    let observation = try await request.perform(on: image)
    return observation.overallScore
}
```

### Limitations
- 시뮬레이터 미지원 → Metal fallback 필수
- iOS 18.0+ 전용

### References
- [Apple WWDC24 - Discover Swift enhancements in Vision framework](https://developer.apple.com/videos/play/wwdc2024/10163/)

---

## 5. Face Quality (Safe Guard)

### Decision
- Face Quality >= 0.4 → 블러 판정 무효화

### Rationale
- 선명한 얼굴이 있는 사진은 의도적 촬영으로 보호
- **주의**: Apple 권고는 "같은 피사체 간 상대 비교"용
- 본 기능은 최소 품질 판정 목적으로 절대 임계값 사용
- 0.4는 설계값, 테스트 필수

### Alternatives Considered
- 얼굴 감지 여부만 확인: Quality 고려 없이 모든 얼굴 보호 → 과보호
- 0.5 이상: 더 엄격하지만 오탐 증가 가능

### Implementation
```swift
import Vision

func detectFaceQuality(cgImage: CGImage) throws -> Float? {
    let request = VNDetectFaceCaptureQualityRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try handler.perform([request])
    return request.results?.first?.faceCaptureQuality
}
```

### References
- [Apple - Selecting a selfie based on capture quality](https://developer.apple.com/documentation/Vision/selecting-a-selfie-based-on-capture-quality)

---

## 6. 비네팅 (주머니 샷)

### Decision
- 비네팅 < 0.05 (모서리와 중앙 차이 거의 없음) + 다른 조건 충족 시 주머니 샷

### Rationale
- 주머니 샷: 휘도 < 0.15 AND RGB Std < 15 AND Laplacian < 50 AND 비네팅 < 0.05
- 비네팅 = 1 - (모서리 평균 휘도 / 중앙 평균 휘도)
- 설계값, 테스트 필요

### Implementation
```swift
// 3×3 그리드 분할
// 중앙: (1,1), 모서리: (0,0), (0,2), (2,0), (2,2)
// 중앙 휘도 < 0.01인 경우 → 0.0 반환 (극단 어두움으로 이미 판정됨)
```

---

## 7. iCloud 썸네일 전략

### Decision
- `networkAccessAllowed = false` 설정
- 로컬 캐시 썸네일만 사용 (~342×256)
- 캐시 없으면 SKIP

### Rationale
- 원본 다운로드 시 네트워크/시간/배터리 비용 과다
- 썸네일로도 노출/블러 분석 충분
- "Optimize Storage" 모드에서도 로컬 캐시 존재

### Validation Required
- 64×64 썸네일 vs 원본: 노출 분석 결과 일치 확인
- 256×256 썸네일 vs 원본: 블러 분석 결과 일치 확인

### Implementation
```swift
let options = PHImageRequestOptions()
options.isNetworkAccessAllowed = false
options.deliveryMode = .opportunistic

// 요청 크기보다 작은 이미지 반환 시 → 로컬 캐시
// error가 발생하면 → iCloud 전용, SKIP
```

---

## 8. 특수 미디어 처리

### Decision

| 유형 | 처리 |
|-----|------|
| Live Photo | 정지 이미지만 분석 |
| Burst | 대표 사진만 분석 (PHFetchResult 기본 동작) |
| RAW+JPEG | JPEG로 분석, 삭제 시 함께 삭제 |
| 비디오 (로컬) | 프레임 3개 추출, 중앙값 판정 |
| 비디오 (iCloud) | SKIP |
| 비디오 (10분 초과) | SKIP |

### Rationale
- Live Photo: 사용자는 "사진"으로 인식
- Burst: 그룹 관리 복잡도 회피
- 비디오: 프레임 추출은 로컬 파일 필요, 긴 비디오는 분석 비용 과다

### Implementation (비디오)
```swift
import AVFoundation

func extractFrames(from asset: PHAsset) async throws -> [CGImage] {
    // AVAssetImageGenerator 사용
    // 0%, 50%, 100% 시점에서 프레임 추출
    // 3개 중 2개 이상 저품질이면 LOW_QUALITY
}
```

---

## 9. 성능 최적화

### Decision
- 배치 크기: 100장
- 동시 분석: 4개
- 다운샘플 (노출): 64×64
- 다운샘플 (블러): 256×256

### Rationale
- 1,000장 30초 목표 → 장당 30ms
- Metal GPU 활용으로 블러 분석 3~9ms
- 노출 분석 64×64로 1ms 미만

### Benchmarks Needed
- iPhone 8 (최소 지원 기기) 성능 측정
- 배치 크기/동시성 튜닝

---

## 10. iOS 버전별 파이프라인

### Decision

**iOS 18+:**
```
Stage 1 (Metadata) → AestheticsScore → Safe Guard → 최종 판정
                          ↓ (실패)
                     Stage 2-4 Fallback
```

**iOS 16-17:**
```
Stage 1 (Metadata) → Stage 2 (Exposure) → Stage 3 (Blur) → Stage 4 (SafeGuard + Composite)
```

### Rationale
- iOS 18 AestheticsScore가 더 정확할 것으로 기대
- 시뮬레이터 미지원으로 fallback 필수
- Safe Guard는 모든 경로에서 적용

---

## Summary: 설계값 목록 (테스트 검증 필요)

| 파라미터 | 값 | 상태 |
|---------|---|:----:|
| Laplacian (심각) | < 50 | 설계값 |
| Laplacian (일반) | < 100 | 설계값 |
| 휘도 (어두움) | < 0.10 | 설계값 |
| 휘도 (밝음) | > 0.90 | 설계값 |
| RGB Std (단색) | < 10 | 설계값 |
| RGB Std (색상 다양성) | < 15 | 설계값 |
| Face Quality | >= 0.4 | 설계값 |
| AestheticsScore (Precision) | < -0.3 | 설계값 |
| AestheticsScore (Recall) | < 0 | 설계값 |
| 비네팅 | < 0.05 | 설계값 |

모든 설계값은 테스트 데이터셋으로 검증 후 조정 가능하게 구현해야 함.
