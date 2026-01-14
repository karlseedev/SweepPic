# YuNet + SFace 얼굴 인식 시스템 통합 계획

## 배경

### 현재 문제
Vision Framework Feature Print는 범용 이미지 비교용으로 얼굴 인식에 최적화되지 않음.
- 동일인 fpDistance: 0.32~0.43
- 타인 fpDistance: 0.41~0.59
- **겹침 발생** → 위치가 비슷하면 다른 사람도 같은 사람으로 오판

### PoC 결과
MobileFaceNet 기반 SFace 모델 테스트 (4명, 2장):
- 동일인 유사도: **0.465~0.727**
- 타인 유사도: **0.138~0.439**
- **PoC 범위 내 분리 확인** → 임계값 0.45로 구분 가능
- ⚠️ 표본이 적어 일반화는 추가 검증 필요

---

## 시스템 설계

### 현재 (Vision 기반)
```
Vision VNDetectFaceRectanglesRequest → 바운딩 박스
Vision VNGenerateImageFeaturePrintRequest → Feature Print
→ computeDistance() → 비교
```

### 변경 (YuNet + SFace)
```
YuNet → 얼굴 감지 + 5-point 랜드마크
→ alignCrop() → 112x112 정렬된 얼굴
→ SFace → 128차원 임베딩
→ cosineSimilarity() → 비교
```

### 변경 이유
- YuNet + SFace는 **PoC에서 검증된 조합** (OpenCV 제공, 함께 테스트됨)
- 5-point alignment가 SFace 정확도에 필수
- 검증된 조합으로 시작 → 디버깅 용이

---

## 성능 판단 기준

### 지표 (기존 Vision 대비 상대 기준)

| 지표 | 성능 부족 기준 |
|------|--------------|
| 처리 시간 (p95) | **1.5x 이상** 느림 |
| 메모리 피크 | **+200MB 이상** 증가 |
| Thermal 상태 | serious/critical 진입 |

### 원인 분리 매트릭스

| 조합 | 목적 | 비고 |
|------|------|------|
| Vision + VisionFP | 기존 기준선 | 성능/정확도 비교 기준 |
| **YuNet + SFace** | 목표 품질 | 먼저 구현 |
| Vision + SFace | 랜드마크 영향 확인 | 나중에 최적화 시도 |

**문제 발생 시 원인 분리:**
- YuNet+SFace만 잘 나오고 Vision+SFace가 깨지면 → 랜드마크/정렬 문제
- 둘 다 깨지면 → SFace 전처리/임계값 문제

---

## 모델 스펙

### YuNet (얼굴 감지)
| 항목 | 값 |
|------|-----|
| 파일 | face_detection_yunet_2023mar.onnx |
| 입력 | 가변 크기 (이미지 크기에 맞춤) |
| 출력 | 얼굴 바운딩 박스 + 5-point 랜드마크 |
| 크기 | 227KB |

### SFace (얼굴 인식)
| 항목 | 값 |
|------|-----|
| 파일 | face_recognition_sface_2021dec.onnx |
| 입력 | [1, 3, 112, 112] (N, C, H, W) |
| 출력 | [1, 128] (128차원 임베딩) |
| 크기 | 37MB |
| int8 버전 | face_recognition_sface_2021dec_int8.onnx (용량 감소) |

### 전처리 스펙 (확인 필요)
- [ ] 입력 색상 형식: BGR vs RGB
- [ ] 정규화: mean, std 값
- [ ] 정렬 템플릿: 5-point 기준 좌표

---

## Phase 0: 기준선 측정 ✅

### 0.1 성능 측정 코드 추가 (완료)
`SimilarityAnalysisQueue.swift`에 성능 로그 추가:
```
========== PERFORMANCE METRICS (Vision) ==========
Photos: N, Faces: N, Groups: N
--------------------------------------------------
FP Generation Time: XXXms (XXms/photo)
Face Detect+Match Time: XXXms (XXms/face)
Total Time: XXXms
--------------------------------------------------
Memory Start: XXX MB
Memory End: XXX MB
Memory Delta: +XX MB
Thermal State: nominal/fair/serious/critical
==================================================
```

### 0.2 기준선 수집 (완료)

**테스트 조건:** 35장, 25얼굴, 3그룹

| 지표 | 값 | 단위당 |
|------|-----|--------|
| FP 생성 | 150.20ms | **4.3ms/photo** |
| 얼굴 감지+매칭 | 532.82ms | **21.3ms/face** |
| 총 시간 | 684.00ms | 19.5ms/photo |
| 메모리 델타 | -7.1MB | (GC 발생) |
| Thermal | nominal | - |

### 0.3 YuNet+SFace 허용 범위 (1.5x 기준)

| 지표 | 기준선 | 허용 상한 |
|------|--------|----------|
| photo당 처리 | 4.3ms | **<6.5ms** |
| face당 처리 | 21.3ms | **<32ms** |
| 메모리 증가 | - | **+200MB 이내** |

---

## Phase 1: 모델 변환 및 추가

### 1.1 ONNX → Core ML 변환

```python
import coremltools as ct

# YuNet 변환
yunet_mlmodel = ct.convert(
    "face_detection_yunet_2023mar.onnx",
    convert_to="mlprogram",
    minimum_deployment_target=ct.target.iOS16
)
yunet_mlmodel.save("YuNet.mlpackage")

# SFace 변환 (float32)
sface_mlmodel = ct.convert(
    "face_recognition_sface_2021dec.onnx",
    convert_to="mlprogram",
    minimum_deployment_target=ct.target.iOS16
)
sface_mlmodel.save("SFace.mlpackage")

# SFace 변환 (int8 - 용량/속도 비교용)
sface_int8_mlmodel = ct.convert(
    "face_recognition_sface_2021dec_int8.onnx",
    convert_to="mlprogram",
    minimum_deployment_target=ct.target.iOS16
)
sface_int8_mlmodel.save("SFace_int8.mlpackage")
```

### 1.2 프로젝트 구조

```
PickPhoto/
├── Resources/
│   └── MLModels/
│       ├── YuNet.mlpackage      # 얼굴 감지 (227KB)
│       ├── SFace.mlpackage      # 얼굴 인식 (37MB)
│       └── SFace_int8.mlpackage # 얼굴 인식 int8 (비교용)
```

---

## Phase 2: 새 클래스 구현

### 2.1 파일 구조

```
PickPhoto/Features/SimilarPhoto/Analysis/
├── FaceDetector.swift           # 기존 Vision 기반 (보관, fallback)
├── YuNetFaceDetector.swift      # 새로 추가
├── SFaceRecognizer.swift        # 새로 추가
├── FaceAligner.swift            # 새로 추가 (5-point alignment)
└── SimilarityAnalyzer.swift     # 기존 → 수정
```

### 2.2 YuNetFaceDetector

```swift
/// YuNet 기반 얼굴 감지기
final class YuNetFaceDetector {

    static let shared = YuNetFaceDetector()

    /// 이미지에서 얼굴 감지
    /// - Returns: 얼굴 바운딩 박스 + 5-point 랜드마크 배열
    func detectFaces(in image: CGImage) throws -> [DetectedFaceWithLandmarks]
}

struct DetectedFaceWithLandmarks {
    let boundingBox: CGRect
    let landmarks: FaceLandmarks5  // 왼눈, 오른눈, 코, 왼입꼬리, 오른입꼬리
    let confidence: Float
}

struct FaceLandmarks5 {
    let leftEye: CGPoint
    let rightEye: CGPoint
    let nose: CGPoint
    let leftMouth: CGPoint
    let rightMouth: CGPoint
}
```

### 2.3 FaceAligner

```swift
/// 5-point 랜드마크 기반 얼굴 정렬
final class FaceAligner {

    /// 얼굴 이미지를 112x112로 정렬 및 크롭
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - landmarks: 5-point 랜드마크
    /// - Returns: 정렬된 112x112 얼굴 이미지
    func alignCrop(image: CGImage, landmarks: FaceLandmarks5) -> CGImage
}
```

### 2.4 SFaceRecognizer

```swift
/// SFace 기반 얼굴 인식기
final class SFaceRecognizer {

    static let shared = SFaceRecognizer()

    /// 정렬된 얼굴 이미지에서 임베딩 추출
    /// - Parameter alignedFace: 112x112 정렬된 얼굴 이미지
    /// - Returns: 128차원 임베딩 벡터
    func extractEmbedding(from alignedFace: CGImage) throws -> [Float]

    /// 두 임베딩의 코사인 유사도 계산
    /// - Returns: 0~1 사이 값 (1에 가까울수록 동일인)
    func cosineSimilarity(_ embedding1: [Float], _ embedding2: [Float]) -> Float
}
```

---

## Phase 3: 기존 코드 수정

### 3.1 SimilarityAnalysisQueue.swift

#### PersonSlot 구조체 변경

```swift
// 변경 전
private struct PersonSlot {
    let id: Int
    let featurePrint: VNFeaturePrintObservation
    let center: CGPoint
    let boundingBox: CGRect
}

// 변경 후
private struct PersonSlot {
    let id: Int
    let embedding: [Float]  // 128차원 SFace 임베딩
    let center: CGPoint
    let boundingBox: CGRect
}
```

#### 얼굴 감지 변경

```swift
// 변경 전
let faces = try await faceDetector.detectFaces(in: photo, viewerSize: viewerSize)

// 변경 후
let image = try await imageLoader.loadImage(for: photo)
let facesWithLandmarks = try yunetDetector.detectFaces(in: image)
```

#### 임베딩 추출 변경

```swift
// 변경 전
guard let fp = try? await analyzer.generateFeaturePrint(for: cropped) else { continue }

// 변경 후
let alignedFace = faceAligner.alignCrop(image: image, landmarks: face.landmarks)
guard let embedding = try? sfaceRecognizer.extractEmbedding(from: alignedFace) else { continue }
```

#### 거리 계산 변경

```swift
// 변경 전
guard let cost = try? analyzer.computeDistance(faceFP, slot.featurePrint) else { continue }

// 변경 후
let similarity = sfaceRecognizer.cosineSimilarity(faceEmbedding, slot.embedding)
let cost = 1.0 - similarity  // 유사도를 거리로 변환 (낮을수록 동일인)
```

### 3.2 SimilarityConstants.swift

```swift
// 변경 전 (Vision FP 거리 기준)
static var greyZoneThreshold: Float { return 0.35 }
static var personMatchThreshold: Float { return 0.65 }

// 변경 후 (SFace 거리 = 1 - 유사도 기준)
// 동일인 유사도: 0.46~0.73 → 거리: 0.27~0.54
// 타인 유사도: 0.14~0.44 → 거리: 0.56~0.86
static var greyZoneThreshold: Float { return 0.50 }      // 거리 0.50 미만 = 확신
static var personMatchThreshold: Float { return 0.60 }   // 거리 0.60 이상 = 거절
```

### 3.3 CachedFace 구조체 (필요시)

```swift
// 기존 유지, 추가 필드 고려
struct CachedFace {
    let boundingBox: CGRect
    let personIndex: Int
    let isValidSlot: Bool
    let embedding: [Float]?  // 선택적: 캐싱용
}
```

---

## Phase 4: 테스트 및 검증

### 4.1 단위 테스트
- [ ] YuNetFaceDetector 얼굴 감지 테스트
- [ ] FaceAligner 정렬 테스트
- [ ] SFaceRecognizer 임베딩 추출 테스트
- [ ] 코사인 유사도 계산 테스트

### 4.2 정확도 테스트
- [ ] 기존 문제 케이스 (위치 비슷한 다른 사람) 테스트
- [ ] 다양한 조명/각도 이미지로 테스트
- [ ] 동일인/타인 분리 확인
- [ ] 임계값 재튜닝

### 4.3 성능 테스트 (기준선 대비)
- [ ] 처리 시간 비교 (1.5x 이내)
- [ ] 메모리 사용량 비교 (+200MB 이내)
- [ ] Thermal 상태 확인
- [ ] float32 vs int8 모델 비교

---

## 롤백 계획

- 기존 Vision 기반 코드는 삭제하지 않고 별도 보관
- FaceDetector.swift 유지 (fallback용)
- 문제 발생 시 의존성 전환으로 즉시 롤백 가능

---

## 작업 체크리스트

### Phase 0: 기준선
- [x] 성능 측정 코드 추가
- [x] 기준선 측정 및 기록 (35장, 25얼굴: 684ms)

### Phase 1: 모델
- [ ] YuNet ONNX → Core ML 변환
- [ ] SFace ONNX → Core ML 변환 (float32 + int8)
- [ ] 모델 프로젝트에 추가

### Phase 2: 구현
- [ ] YuNetFaceDetector 구현
- [ ] FaceAligner 구현
- [ ] SFaceRecognizer 구현

### Phase 3: 통합
- [ ] SimilarityAnalysisQueue 수정
- [ ] SimilarityConstants 임계값 조정

### Phase 4: 검증
- [ ] 단위 테스트
- [ ] 정확도 테스트
- [ ] 성능 테스트
- [ ] 커밋 및 PR

---

## 참고 자료

- [OpenCV Zoo - YuNet](https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet)
- [OpenCV Zoo - SFace](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface)
- [SFace Paper](https://arxiv.org/abs/2205.12010)
- [Core ML Tools](https://apple.github.io/coremltools/docs-guides/source/convert-pytorch.html)
