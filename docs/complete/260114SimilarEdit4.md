# YuNet + SFace 얼굴 인식 시스템 통합 계획

> **상세 구현 스펙**: [260114SimilarEdit4-1.md](./260114SimilarEdit4-1.md)

## 롤백 포인트

| 시점 | 커밋 | 설명 |
|------|------|------|
| **Phase 0 완료** | `8549fee` | 성능 측정 다회 통계 기능 추가 |
| **Phase 1 완료** | `081e1e3` | YuNet + SFace Core ML 모델 추가 |
| **YuNet+SFace 전체 롤백** | `8549fee` | Phase 0까지만 유지, 모델 제거 |

```bash
# 전체 롤백 (Phase 0까지)
git reset --hard 8549fee

# Phase 1까지 롤백 (모델만 유지)
git reset --hard 081e1e3
```

---

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

### 임계값 결정 근거
| 기준 | 값 | 비고 |
|------|-----|------|
| PoC 분리 경계 | 0.45 | 4명 테스트, 표본 적음 |
| **LFW 벤치마크** | **0.363** | 13,233쌍 테스트, 공식 권장 |
| 초기 구현 값 | 0.363 | LFW 기반, 실제 데이터로 튜닝 예정 |

> ⚠️ LFW는 정면 얼굴 벤치마크. 실제 앱 데이터(다양한 각도/조명)와 다를 수 있어 **Phase 4에서 재튜닝 필수**.

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
| Vision + SFace | 랜드마크 영향 확인 | YuNet+SFace 검증 후 |

**문제 발생 시 원인 분리:**
- YuNet+SFace만 잘 나오고 Vision+SFace가 깨지면 → 랜드마크/정렬 문제
- 둘 다 깨지면 → SFace 전처리/임계값 문제

---

## 모델 스펙

### YuNet (얼굴 감지)
| 항목 | 값 |
|------|-----|
| 파일 | YuNet.mlpackage (Core ML) |
| 입력 크기 | **320×320 고정** |
| 입력 형식 | **BGR**, 0-255, NCHW |
| 출력 | 얼굴 바운딩 박스 + 5-point 랜드마크 |
| 크기 | ~200KB |

### SFace (얼굴 인식)
| 항목 | 값 |
|------|-----|
| 파일 | SFace.mlpackage (Core ML) |
| 입력 크기 | 112×112 |
| 입력 형식 | **RGB**, 0-255, NCHW |
| 출력 | [1, 128] (128차원 임베딩) |
| 크기 | ~18MB |

### 전처리 스펙 (확정)
| 모델 | 채널 순서 | Mean | Std | 범위 |
|------|----------|------|-----|------|
| **YuNet** | BGR | 0 | 1 | 0-255 |
| **SFace** | RGB | 0 | 1 | 0-255 |

### 5-Point Alignment 템플릿 (ArcFace 표준, 112×112)
```
right_eye:   (38.2946, 51.6963)
left_eye:    (73.5318, 51.5014)
nose:        (56.0252, 71.7366)
right_mouth: (41.5493, 92.3655)
left_mouth:  (70.7299, 92.2041)
```

> **상세 스펙**: [260114SimilarEdit4-1.md](./260114SimilarEdit4-1.md) 참조

---

## Phase 0: 기준선 측정 ✅

### 0.1 성능 측정 코드 추가 (완료)

**그리드 (SimilarityAnalysisQueue.swift):**
```
========== PERFORMANCE METRICS (Vision) [#N] ==========
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

**다회 측정 통계 (3회 이상 시 자동 출력):**
```
╔══════════════════════════════════════════════════════╗
║       PERFORMANCE STATISTICS (Vision) - N runs       ║
╠══════════════════════════════════════════════════════╣
║  Avg Photos: XX, Avg Faces: XX
║  FP Generation Time: avg/min/max/stdDev
║  Face Detect+Match Time: avg/min/max/stdDev
║  Total Time: avg/min/max/stdDev
║  Memory Delta: avg/min/max
╚══════════════════════════════════════════════════════╝
```

**뷰어 (ViewerViewController+SimilarPhoto.swift):**
```
[ViewerPerf] Cache HIT - Button shown in XXms
[ViewerPerf] Cache MISS - Analysis completed in XXms
[ViewerPerf] +Button → ComparisonGroup in XXms
```

**뷰어 다회 측정 통계 (3회 이상 시 자동 출력):**
```
╔══════════════════════════════════════════════════════╗
║     VIEWER PERFORMANCE (Vision) - N views            ║
╠══════════════════════════════════════════════════════╣
║  Cache Hit: N, Cache Miss: N
║  Button Show (Cache Hit): avg/min/max
║  Button Show (Cache Miss, incl. analysis): avg/min/max
║  +Button → Comparison Screen: avg/min/max
╚══════════════════════════════════════════════════════╝
```

### 0.2 기준선 수집 (완료)

#### 그리드 성능 - Vision 기준선 (5회 측정 평균)

**테스트 조건:** 평균 33장, 21.8얼굴

| 지표 (Vision) | 평균 | 범위 | 단위당 |
|---------------|------|------|--------|
| 전체 이미지 FP 생성 | 201.58ms | 167~268ms | **6.1ms/photo** |
| 얼굴 감지+FP 비교 | 493.21ms | 168~691ms | **22.6ms/face** |
| 총 시간 | 696.36ms | 438~864ms | 21.1ms/photo |
| 메모리 델타 | +6.4MB | -6.9~+50.2MB | - |
| Thermal | nominal | - | - |

> **YuNet+SFace 지표 변환:**
> - "FP 생성" → "YuNet 감지 + SFace 임베딩"
> - "얼굴 감지+FP 비교" → "임베딩 코사인 비교"

#### 뷰어 성능 (12회 측정 평균)

| 지표 | 평균 | 범위 |
|------|------|------|
| 캐시 Hit → 버튼 표시 | **11.27ms** | 4.29~22.17ms |
| +버튼 → 비교화면 | **2.06ms** | 1.56~2.58ms |
| 캐시 Hit 비율 | 100% | 12/12 |

### 0.3 YuNet+SFace 허용 범위 (Vision 대비 1.5x 기준)

| 지표 | Vision 기준선 | YuNet+SFace 허용 상한 |
|------|--------------|---------------------|
| photo당 감지+임베딩 | 6.1ms | **<9.2ms** |
| face당 매칭 | 22.6ms | **<34ms** |
| 뷰어 캐시 Hit 버튼 | 11.3ms | **<17ms** |
| 뷰어 +버튼 클릭 | 2.1ms | **<3.2ms** |
| 메모리 증가 | - | **+200MB 이내** |

---

## Phase 1: 모델 변환 및 추가 ✅

### 1.1 ONNX → Core ML 변환 (완료)

ONNX → PyTorch → Core ML 파이프라인 사용 (coremltools 7.2)

```python
# /tmp/convert_models.py 로 변환 완료
# ONNX 직접 변환 실패 → onnx2torch로 PyTorch 변환 후 Core ML 변환
```

### 1.2 프로젝트 구조 (완료)

```
PickPhoto/PickPhoto/
├── MLModels/
│   ├── YuNet.mlpackage      # 얼굴 감지 (~200KB)
│   └── SFace.mlpackage      # 얼굴 인식 (~18MB)
```

> 커밋: `081e1e3` - feat(002-similar-photo): YuNet + SFace Core ML 모델 추가

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
// 변경 전 (Vision FP 거리 기준 - 낮을수록 유사)
static var greyZoneThreshold: Float { return 0.35 }
static var personMatchThreshold: Float { return 0.65 }

// 변경 후 (SFace 코사인 유사도 기준 - 높을수록 유사)
// 임계값 근거: LFW 벤치마크 0.363 (13,233쌍 테스트, 공식 권장)
// PoC에서 0.45로도 분리 가능했으나, 표본이 적어 LFW 기준 채택

static var personMatchThreshold: Float { return 0.363 }  // 유사도 >= 0.363 → 동일인
// Grey Zone은 Phase 4에서 실제 데이터 기반으로 조정 예정
```

> ⚠️ **임계값 튜닝 필수**: LFW는 정면 얼굴 벤치마크. 실제 앱 데이터(다양한 각도/조명)에서 Phase 4 검증 후 조정.

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
- [ ] **임계값 재튜닝** (LFW 0.363 → 실제 앱 데이터 기반 조정)

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
- [x] 성능 측정 코드 추가 (그리드)
- [x] 다회 측정 통계 기능 추가 (3회 이상 시 avg/min/max/stdDev 자동 출력)
- [x] 뷰어 성능 측정 코드 추가 (캐시 hit/miss, +버튼 클릭)
- [x] 기준선 측정 및 기록 (35장, 25얼굴: 684ms)

### Phase 1: 모델 ✅
- [x] YuNet ONNX → Core ML 변환 (081e1e3)
- [x] SFace ONNX → Core ML 변환 (float32) (081e1e3)
- [x] 모델 프로젝트에 추가 (PickPhoto/MLModels/)
- [ ] (선택) SFace int8 변환 및 성능 비교

### Phase 2: 구현 ✅
> 상세 스펙: [260114SimilarEdit4-1.md](./260114SimilarEdit4-1.md)

- [x] YuNetFaceDetector 구현
  - [x] Core ML 출력 매핑 확인 (var_762~var_943)
  - [x] 전처리 스펙 확정 (BGR, 320×320)
  - [x] 디코딩 로직 확정 (stride 곱셈, sigmoid 내장)
  - [x] Swift 구현 (YuNet/ 디렉토리 4개 파일)
- [x] FaceAligner 구현
  - [x] ArcFace 5-point 템플릿 확정
  - [x] Similarity Transform 구현 (SVD 기반 Procrustes)
- [x] SFaceRecognizer 구현
  - [x] 전처리 스펙 확정 (RGB, 0-255)
  - [x] Swift 구현 (128-dim 임베딩, 코사인 유사도)
- [x] 파이프라인 테스트 통과 (YuNetDebugTest)

### Phase 3: 통합 ✅
- [x] SimilarityAnalysisQueue 수정
  - [x] PersonSlot: featurePrint → embedding
  - [x] YuNet으로 얼굴 감지 (landmark 포함)
  - [x] FaceAligner + SFace로 임베딩 생성
  - [x] 코사인 유사도 → 거리 변환 (cost = 1 - similarity)
- [x] SimilarityConstants 임계값 조정
  - [x] personMatchThreshold: 0.637 (유사도 0.363)
  - [x] greyZoneThreshold: 0.45 (유사도 0.55)

### Phase 4: 검증
- [ ] 단위 테스트
- [ ] 정확도 테스트
- [ ] 성능 테스트
- [ ] 커밋 및 PR

---

## Phase 5: SFace 임베딩 품질 분석 및 개선 (진행중)

### 5.1 문제 발견 - 슬롯 폭발 현상

같은 사람인데 personIndex가 1~10까지 생성됨. sfaceCost가 같은 사람인데 0.45~0.65로 높게 나옴.

| 위치 | Photo 1 | Photo 2 | Photo 3 | Photo 4 | Photo 5 |
|------|---------|---------|---------|---------|---------|
| 왼쪽 (x≈0.33) | **1** | **6** | **6** | **9** | **10** |
| 중앙 (x≈0.49) | **2** | 2 (0.26) | - | **6** (0.29) | 2 (0.35) |
| 오른쪽 (x≈0.71) | **4** | **5** | 5 (0.66) | **7** | 7 (0.16) |

### 5.2 Self-Consistency 테스트 추가

같은 이미지를 2번 임베딩하면 similarity ≈ 1.0이어야 함.

**테스트 결과 (문제 사진, CPU-only):**
| Face | norm | 1px shift | 2px shift | 결과 |
|------|------|-----------|-----------|------|
| [0] | **3.3** | 0.877 ✗ | 0.774 ✗ | **FAIL** |
| [1] | 9.7 | 0.976 ✓ | 0.901 ✓ | PASS |
| [2] | 9.3 | 0.959 ✓ | 0.922 ✓ | PASS |
| [3] | 10.3 | 0.956 ✓ | 0.900 ✓ | PASS |

**결론:**
- **[0] 얼굴만 문제** - norm 3.3, 정렬 검증도 실패
- **Core ML 변환 문제 아님** - 파이프라인 자체는 정상
- **저품질 얼굴(norm < 7)이 슬롯 폭발 유발**

### 5.3 CPU-only vs ANE/GPU 테스트

| 테스트 | ANE/GPU (.all) | CPU-only | ONNX 원본 |
|--------|----------------|----------|-----------|
| 1px shift | 0.877 | **0.986** | 0.933 |
| 2px shift | 0.776 | **0.955** | 0.912 |

- 이미지에 따라 다름 (저품질 얼굴에서만 문제)
- 고품질 얼굴은 ANE/GPU에서도 정상

### 5.4 구현된 개선사항

#### Keep Best 정책
```swift
/// 매칭된 얼굴의 norm이 슬롯보다 높으면 슬롯 임베딩 갱신
func updateSlotIfBetter(slotID: Int, embedding: [Float], norm: Float) {
    if norm > activeSlots[idx].norm {
        activeSlots[idx].embedding = embedding
        activeSlots[idx].norm = norm
    }
}
```

#### 저품질 필터
- `minEmbeddingNorm: Float = 7.0`
- norm < 7인 얼굴은 **신규 슬롯 생성 금지**
- 부팅 시에는 저품질 포함 (모든 인물이 슬롯 보유)
- 기존 슬롯 매칭은 허용

#### 로그 출력
```
[LowQuality] Face(0): norm=3.23 < 7.0, skip new slot
[KeepBest] Slot(4): norm 7.25 -> 8.44
[NewSlot] Face(2) -> Slot(1): Bootstrap, norm=6.09 [LowQ]
```

### 5.5 현재 한계

저품질 슬롯의 임베딩이 불안정해서 매칭이 잘 안 됨:
```
[GreyReject] Face(1) -> Slot(3): Cost=0.501, PosNorm=0.12
```
- 해당 인물이 +표시 안 됨 (인식률 개선 아닌 차단)

### 5.6 커밋

```
ff0dbdc feat(002-similar-photo): Keep Best + 저품질 필터 및 Self-Consistency 테스트 추가
```

---

## Phase 6: 조건부 1차 파이프라인 (계획)

### 6.1 배경

Vision + SFace 조합으로 인식률 향상:
- SFace 1차는 "고품질"일 때만 유리
- Vision 1차는 언제나 안전 (위치 기반)

### 6.2 구조

```
┌─────────────────────────────────────┐
│           얼굴 품질 체크             │
│   norm ≥ 7 && bbox 충분?            │
└───────────┬─────────────┬───────────┘
            │             │
           YES           NO
            ▼             ▼
    ┌───────────┐   ┌───────────┐
    │ SFace 1차 │   │ Vision 1차│
    │ (임베딩)   │   │ (위치기반) │
    └─────┬─────┘   └─────┬─────┘
          │               │
          ▼               ▼
    ┌─────────────────────────────┐
    │    결과 애매? (경계값 근처)    │
    │    → 반대 모델로 2차 검증     │
    └─────────────────────────────┘
```

### 6.3 장점
- **고품질**: SFace 정확도 활용
- **저품질**: Vision 안정성 확보
- **애매한 케이스**: 교차 검증으로 오탐 방지

### 6.4 구현 계획
1. Vision 위치 기반 매칭 로직 추가
2. 조건부 스위칭: norm ≥ 7 && bbox 충분 → SFace, 그 외 → Vision
3. 2차 보정: 애매한 경우 반대 모델로 재검증

---

## 참고 자료

- [OpenCV Zoo - YuNet](https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet)
- [OpenCV Zoo - SFace](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface)
- [SFace Paper](https://arxiv.org/abs/2205.12010)
- [Core ML Tools](https://apple.github.io/coremltools/docs-guides/source/convert-pytorch.html)
