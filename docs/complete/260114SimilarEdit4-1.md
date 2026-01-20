# YuNet 구현 세부 계획

> 참조: [OpenCV face_detect.cpp](https://github.com/opencv/opencv/blob/master/modules/objdetect/src/face_detect.cpp)

## 전처리 (Preprocessing)

> 출처: [libfacedetection.train/configs/yunet_n.py](https://github.com/ShiqiYu/libfacedetection.train/blob/master/configs/yunet_n.py)

### 입력 형식 (확정)
| 항목 | 값 | 비고 |
|------|-----|------|
| **컬러 순서** | **BGR** | `to_rgb=False` (학습 config) |
| **Mean** | [0, 0, 0] | 정규화 없음 |
| **Std** | [1, 1, 1] | 정규화 없음 |
| **입력 범위** | 0-255 | Float32, 그대로 사용 |
| **채널 순서** | NCHW | (batch, channel, height, width) |

### 입력 크기 정책 (확정)
- **고정 크기**: 320×320
- 구현 단순화 및 일관성을 위해 고정 크기 사용
- 320은 YuNet 기본 학습 크기이며 얼굴 감지에 충분한 해상도

### 좌표계 변환 (중요!)

YuNet 출력은 **320×320 기준 픽셀 좌표**이므로, 원본 이미지 좌표로 변환 필요:

```swift
// 리사이즈 시 비율 계산
let scaleX = Float(originalWidth) / 320.0
let scaleY = Float(originalHeight) / 320.0

// 원본 좌표로 복원 (bbox)
let originalX1 = x1 * scaleX
let originalY1 = y1 * scaleY
let originalW = w * scaleX
let originalH = h * scaleY

// 원본 좌표로 복원 (landmark)
let originalLmX = lmX * scaleX
let originalLmY = lmY * scaleY
```

> **주의**: 단순 리사이즈(aspect ratio 무시)를 사용하므로,
> 원본 이미지 비율이 1:1이 아니면 약간의 왜곡 발생.
> 얼굴 감지에는 큰 영향 없음.

### iOS에서 BGR 변환 필수!
```swift
// iOS 이미지는 RGB → YuNet은 BGR 기대
// 따라서 R/B 채널 스왑 필요!

func rgbToBgr(_ image: CGImage) -> MLMultiArray {
    let width = 320
    let height = 320
    let input = try! MLMultiArray(shape: [1, 3, height, width] as [NSNumber], dataType: .float32)

    // 이미지 리사이즈 후 픽셀 접근
    for y in 0..<height {
        for x in 0..<width {
            let pixel = getPixel(image, x, y)  // RGB 순서
            // BGR 순서로 저장 (R↔B 스왑)
            input[[0, 0, y, x] as [NSNumber]] = NSNumber(value: pixel.b)  // B
            input[[0, 1, y, x] as [NSNumber]] = NSNumber(value: pixel.g)  // G
            input[[0, 2, y, x] as [NSNumber]] = NSNumber(value: pixel.r)  // R
        }
    }
    return input
}
```

## 모델 출력 구조

### 출력 구조 (12개, 입력 320x320 기준)

| stride | cls | obj | bbox | kps | feature map |
|--------|-----|-----|------|-----|-------------|
| 8 | [1600, 1] | [1600, 1] | [1600, 4] | [1600, 10] | 40x40 |
| 16 | [400, 1] | [400, 1] | [400, 4] | [400, 10] | 20x20 |
| 32 | [100, 1] | [100, 1] | [100, 4] | [100, 10] | 10x10 |

**Feature Map 계산:**
- stride 8: 320/8 = 40, 40×40 = 1600
- stride 16: 320/16 = 20, 20×20 = 400
- stride 32: 320/32 = 10, 10×10 = 100

### Core ML 출력 매핑 (확인 완료)

| Core ML | 원본 | shape | 인덱싱 | 설명 |
|---------|------|-------|--------|------|
| var_762 | cls_8 | [1600,1] | `cls[idx]` | stride 8 classification |
| var_779 | cls_16 | [400,1] | `cls[idx]` | stride 16 classification |
| var_796 | cls_32 | [100,1] | `cls[idx]` | stride 32 classification |
| var_813 | obj_8 | [1600,1] | `obj[idx]` | stride 8 objectness |
| var_830 | obj_16 | [400,1] | `obj[idx]` | stride 16 objectness |
| var_847 | obj_32 | [100,1] | `obj[idx]` | stride 32 objectness |
| var_863 | bbox_8 | [1600,4] | `bbox[idx*4+k]` | stride 8 bbox (dx,dy,dw,dh) |
| var_879 | bbox_16 | [400,4] | `bbox[idx*4+k]` | stride 16 bbox |
| var_895 | bbox_32 | [100,4] | `bbox[idx*4+k]` | stride 32 bbox |
| var_911 | kps_8 | [1600,10] | `kps[idx*10+k]` | stride 8 landmarks (5점x2) |
| var_927 | kps_16 | [400,10] | `kps[idx*10+k]` | stride 16 landmarks |
| var_943 | kps_32 | [100,10] | `kps[idx*10+k]` | stride 32 landmarks |

### 출력 인덱싱 규칙 (확정)

```swift
// Core ML MLMultiArray는 flatten된 1D 배열로 접근
// shape [N, C]인 경우: array[row * C + col]

// cls/obj: shape [N, 1] → 단순 1D 인덱싱
let clsValue = clsArray[idx]  // idx = 0..<N

// bbox: shape [N, 4] → row-major 인덱싱
let dx = bboxArray[idx * 4 + 0]
let dy = bboxArray[idx * 4 + 1]
let dw = bboxArray[idx * 4 + 2]
let dh = bboxArray[idx * 4 + 3]

// kps: shape [N, 10] → row-major 인덱싱
for i in 0..<5 {
    let x = kpsArray[idx * 10 + i * 2]
    let y = kpsArray[idx * 10 + i * 2 + 1]
}
```

**Feature Map 크기 (입력 320x320 기준):**
- stride 8: 40x40 = 1600
- stride 16: 20x20 = 400
- stride 32: 10x10 = 100

## 구현 단계

### 1. Grid Cell 인덱싱 (Prior/Anchor 대체)

> **중요**: YuNet은 SSD/RetinaFace 스타일의 anchor box를 사용하지 않음.
> 대신 feature map의 grid cell 좌표(col, row)와 stride를 직접 사용하여 디코딩.

```swift
// YuNet은 anchor가 아닌 grid cell 기반 디코딩
// 각 feature map 위치 (col, row)에서 stride를 scale factor로 사용

struct GridCell {
    let col: Int       // feature map x 좌표 (0..<feature_w)
    let row: Int       // feature map y 좌표 (0..<feature_h)
    let stride: Int    // 8, 16, 또는 32
}

// 파라미터
let strides = [8, 16, 32]
let inputSize = (320, 320)  // (width, height)
```

Feature map 크기 계산:
- stride 8: 40x40 = 1600
- stride 16: 20x20 = 400
- stride 32: 10x10 = 100

Grid Cell 생성:
```swift
// OpenCV 구현 기준: row-major 순서
for stride in strides {
    let featureW = inputW / stride
    let featureH = inputH / stride
    for row in 0..<featureH {
        for col in 0..<featureW {
            // 각 cell은 (col, row, stride)로 식별
            gridCells.append(GridCell(col: col, row: row, stride: stride))
        }
    }
}
```

### 2. 출력 디코딩

> **좌표계**: 모든 출력은 **픽셀 좌표** (normalized가 아님)

#### Score 계산 (확정)

> **확인 완료**: ONNX 모델 출력에 sigmoid가 이미 포함됨 → 후처리에서 clamp만 수행

```swift
// cls: classification score (모델 내부에서 sigmoid 적용됨, 0~1 범위)
// obj: objectness score (모델 내부에서 sigmoid 적용됨, 0~1 범위)
//
// 출처: OpenCV face_detect.cpp - sigmoid 적용 없이 clamp만 수행
// cls_score = MIN(cls_score, 1.f); cls_score = MAX(cls_score, 0.f);

// Core ML 출력 shape: [N, 1] → 1D 배열처럼 접근
let clsScore = min(max(cls[idx], 0), 1)  // clamp to [0, 1]
let objScore = min(max(obj[idx], 0), 1)  // clamp to [0, 1]
let score = sqrt(clsScore * objScore)
```

> **주의**: sigmoid를 추가로 적용하면 안 됨! 모델 출력이 이미 0~1 범위.

#### BBox 디코딩 (OpenCV 구현 기준)
```swift
// OpenCV face_detect.cpp 기준 디코딩
// variance 사용하지 않음! stride를 직접 scale factor로 사용

// bbox output: [dx, dy, dw, dh] (offset과 log-scale 크기)
let col = gridCell.col
let row = gridCell.row
let stride = Float(gridCell.stride)

// center 좌표 (픽셀 단위)
let cx = (Float(col) + bbox[0]) * stride
let cy = (Float(row) + bbox[1]) * stride

// 크기 (픽셀 단위)
let w = exp(bbox[2]) * stride
let h = exp(bbox[3]) * stride

// center -> corner (x1, y1, x2, y2)
let x1 = cx - w / 2
let y1 = cy - h / 2
let x2 = cx + w / 2
let y2 = cy + h / 2
```

> **중요**: 기존 문서의 variance [0.1, 0.2]는 RetinaFace/SSD 스타일이며,
> YuNet은 이를 사용하지 않음. stride를 직접 곱함.

#### Landmark 디코딩 (OpenCV 구현 기준)
```swift
// kps output: [re_x, re_y, le_x, le_y, n_x, n_y, rm_x, rm_y, lm_x, lm_y]
// 순서 (OpenCV 기준): right_eye, left_eye, nose, right_mouth, left_mouth
//
// OpenCV face_detect.cpp line ~300:
// face.at<float>(0, 4+2*n) = (kps_v[idx*10+2*n] + c) * stride

for i in 0..<5 {
    let lm_x = (kps[i*2] + Float(col)) * stride     // 픽셀 좌표
    let lm_y = (kps[i*2+1] + Float(row)) * stride   // 픽셀 좌표
    landmarks[i] = CGPoint(x: CGFloat(lm_x), y: CGFloat(lm_y))
}
```

> **Landmark 순서 검증**: OpenCV 출력 형식 [x, y, w, h, confidence,
> re_x, re_y, le_x, le_y, n_x, n_y, rm_x, rm_y, lm_x, lm_y]

### 3. NMS (Non-Maximum Suppression)

> **좌표계**: 픽셀 좌표 기준으로 IoU 계산

```swift
func nms(boxes: [Detection], threshold: Float) -> [Detection] {
    // 1. Score 기준 정렬
    let sorted = boxes.sorted { $0.score > $1.score }

    var kept: [Detection] = []
    var suppressed = Set<Int>()

    for i in 0..<sorted.count {
        if suppressed.contains(i) { continue }
        kept.append(sorted[i])

        for j in (i+1)..<sorted.count {
            if suppressed.contains(j) { continue }
            // bbox는 픽셀 좌표 (x1, y1, x2, y2)
            let iou = computeIoU(sorted[i].bbox, sorted[j].bbox)
            if iou > threshold {
                suppressed.insert(j)
            }
        }
    }
    return kept
}

// IoU 계산 (픽셀 좌표 기준)
func computeIoU(_ a: CGRect, _ b: CGRect) -> Float {
    let intersection = a.intersection(b)
    if intersection.isNull { return 0 }

    let intersectionArea = intersection.width * intersection.height
    let unionArea = a.width * a.height + b.width * b.height - intersectionArea

    return Float(intersectionArea / unionArea)
}
```

### 4. Top-K 처리

> **Top-K 기준**: NMS 이후 score 순 상위 K개 반환

```swift
// 파라미터 설정
let nmsThreshold: Float = 0.3     // OpenCV 기본값
let scoreThreshold: Float = 0.6   // OpenCV 기본값
let topK: Int = SimilarityConstants.maxFacesPerPhoto  // 현재 5

// topK 근거:
// - SimilarityConstants.swift:113 → maxFacesPerPhoto = 5
// - 기존 FaceDetector.swift:95 에서도 동일 상수 사용
// - 일반 사진에서 얼굴 5개 이상은 드묾
// - 메모리/성능 최적화를 위해 제한

// 참고: OpenCV 기본값은 topK=5000, keepTopK=750 (대규모 이미지용)

// NMS 후 상위 K개만 반환
let filtered = nms(detections, threshold: nmsThreshold)
let result = Array(filtered.prefix(topK))
```

### 5. 전체 파이프라인

```swift
// Core ML 출력 이름 매핑 (stride별)
let outputNames: [Int: (cls: String, obj: String, bbox: String, kps: String)] = [
    8:  ("var_762", "var_813", "var_863", "var_911"),
    16: ("var_779", "var_830", "var_879", "var_927"),
    32: ("var_796", "var_847", "var_895", "var_943")
]

func detect(image: CGImage) -> [FaceDetection] {
    let inputW = 320
    let inputH = 320

    // 1. 전처리 (리사이즈 + RGB→BGR 변환 + 0-255 범위)
    let input = preprocessBGR(image, width: inputW, height: inputH)

    // 2. Core ML 추론
    let outputs = try! model.prediction(from: input)

    // 3. Grid cell 기반 디코딩
    var detections: [Detection] = []

    for stride in [8, 16, 32] {
        let featureW = inputW / stride
        let featureH = inputH / stride
        let names = outputNames[stride]!

        // Core ML 출력 가져오기 (MLMultiArray)
        let cls = outputs.featureValue(for: names.cls)!.multiArrayValue!
        let obj = outputs.featureValue(for: names.obj)!.multiArrayValue!
        let bbox = outputs.featureValue(for: names.bbox)!.multiArrayValue!
        let kps = outputs.featureValue(for: names.kps)!.multiArrayValue!

        var idx = 0
        for row in 0..<featureH {
            for col in 0..<featureW {
                // Score 계산 (sigmoid 이미 적용됨, clamp만 수행)
                let clsScore = min(max(cls[idx].floatValue, 0), 1)
                let objScore = min(max(obj[idx].floatValue, 0), 1)
                let score = sqrt(clsScore * objScore)

                if score < scoreThreshold {
                    idx += 1
                    continue
                }

                // BBox 디코딩 (픽셀 좌표, row-major 인덱싱)
                let strideF = Float(stride)
                let cx = (Float(col) + bbox[idx * 4 + 0].floatValue) * strideF
                let cy = (Float(row) + bbox[idx * 4 + 1].floatValue) * strideF
                let w = exp(bbox[idx * 4 + 2].floatValue) * strideF
                let h = exp(bbox[idx * 4 + 3].floatValue) * strideF

                let box = CGRect(
                    x: CGFloat(cx - w/2),
                    y: CGFloat(cy - h/2),
                    width: CGFloat(w),
                    height: CGFloat(h)
                )

                // Landmark 디코딩 (픽셀 좌표, row-major 인덱싱)
                var landmarks: [CGPoint] = []
                for i in 0..<5 {
                    let lmX = (kps[idx * 10 + i * 2].floatValue + Float(col)) * strideF
                    let lmY = (kps[idx * 10 + i * 2 + 1].floatValue + Float(row)) * strideF
                    landmarks.append(CGPoint(x: CGFloat(lmX), y: CGFloat(lmY)))
                }

                detections.append(Detection(
                    bbox: box,
                    landmarks: landmarks,
                    score: score
                ))

                idx += 1
            }
        }
    }

    // 4. NMS
    let filtered = nms(detections, threshold: nmsThreshold)

    // 5. Top-K (score 순 상위 K개)
    return Array(filtered.prefix(topK))
}
```

### 6. 에러 및 엣지 케이스 처리

```swift
// 0개 검출 시 처리
func detect(image: CGImage) throws -> [FaceDetection] {
    // ... 위 파이프라인 ...

    let result = Array(filtered.prefix(topK))

    // 빈 결과도 정상 반환 (에러 아님)
    // 호출자가 빈 배열을 적절히 처리해야 함
    return result  // 0개일 수 있음
}

// 호출 예시
let faces = try yunetDetector.detect(image: image)
if faces.isEmpty {
    // 얼굴 없음 → 해당 사진은 유사도 분석에서 제외
    // 캐시에는 빈 결과로 저장 (재분석 방지)
    return CachedResult(faces: [], analyzed: true)
}

// 모델 로드 실패 시
// init에서 fatalError 대신 throws 사용 권장
init() throws {
    guard let model = try? YuNet(configuration: MLModelConfiguration())
    else {
        throw YuNetError.modelLoadFailed
    }
    self.model = model
}

enum YuNetError: Error {
    case modelLoadFailed
    case preprocessingFailed
    case invalidImageFormat
}
```

## 파일 구조

```
Features/SimilarPhoto/Analysis/
├── FaceDetector.swift              # 기존 Vision 기반 (유지)
├── YuNet/                          # YuNet 관련 파일 (1000줄 제한으로 분리)
│   ├── YuNetTypes.swift            # 타입 정의 (Detection, Error, Config, OutputNames)
│   ├── YuNetPreprocessor.swift     # 전처리 (RGB→BGR, 리사이즈, NCHW)
│   ├── YuNetDecoder.swift          # 디코딩 (Grid cell, BBox, Landmark)
│   └── YuNetFaceDetector.swift     # 메인 클래스 (NMS, 파이프라인, 좌표 변환)
├── FaceAligner.swift               # 새로 추가 (Similarity Transform)
└── SFaceRecognizer.swift           # 새로 추가 (임베딩 추출)
```

## 구현 체크리스트

### Phase 2.1: YuNetFaceDetector
- [x] Core ML 출력 이름 매핑 확인 (var_762~var_943)
- [x] 전처리 스펙 확정 (BGR, 0-255, 정규화 없음)
- [x] Sigmoid 확정 (모델 내장, clamp만 수행)
- [x] 인덱싱 규칙 확정 (row-major, 1D flatten)
- [x] 전처리 구현 (RGB→BGR 변환, 리사이즈, NCHW) → `YuNetPreprocessor.swift`
- [x] Grid cell 인덱싱 (stride 8/16/32) → `YuNetDecoder.swift`
- [x] Score 계산 (sqrt(cls*obj), clamp) → `YuNetDecoder.swift`
- [x] BBox 디코딩 (stride 직접 곱셈) → `YuNetDecoder.swift`
- [x] Landmark 디코딩 (5-point, 픽셀 좌표) → `YuNetDecoder.swift`
- [x] **좌표계 변환** (320×320 → 원본 이미지 좌표) → `YuNetDecoder.swift`
- [x] NMS 구현 (픽셀 좌표 기준 IoU) → `YuNetFaceDetector.swift`
- [x] Top-K 처리 (NMS 후 score 순, topK=`SimilarityConstants.maxFacesPerPhoto`)
- [x] 0개 검출/에러 처리 (빈 배열 반환, 에러 enum) → `YuNetTypes.swift`
- [x] 전체 파이프라인 통합 → `YuNetFaceDetector.swift`
- [x] **Core ML 출력 범위 검증** (cls/obj 0~1 확인 완료, sigmoid 내장 확인)
- [x] 단위 테스트 (YuNetDebugTest로 검증 완료)

### Phase 2.2: FaceAligner
- [x] 5-point alignment 템플릿 좌표 정의 (ArcFace 표준)
- [x] Similarity Transform 계산 (SVD 기반 Procrustes) → `FaceAligner.swift`
- [x] Core Graphics warpAffine 구현 (CGContext + CGAffineTransform)
- [x] 112x112 크롭 출력

### Phase 2.3: SFaceRecognizer
- [x] 전처리 스펙 확정 (RGB, mean=0, scale=1, 0-255 범위)
- [x] Core ML 모델 로드 (SFace.mlpackage) → `SFaceRecognizer.swift`
- [x] 전처리 구현 (112x112 RGB MLMultiArray)
- [x] 임베딩 추출 (128-dim)
- [x] 코사인 유사도 계산 (Accelerate vDSP)
- [x] 임계값 기반 동일인 판정 (cosine >= 0.363, 튜닝 필요)
- [ ] (선택) Int8 모델 변환 및 성능 비교

---

## FaceAligner 상세 스펙

> 참조: [OpenCV face_recognize.cpp](https://github.com/opencv/opencv/blob/4.x/modules/objdetect/src/face_recognize.cpp),
> [InsightFace face_align.py](https://github.com/deepinsight/insightface/blob/master/python-package/insightface/utils/face_align.py)

### ArcFace 5-Point Landmark 템플릿 (112x112)

```swift
// 표준 ArcFace alignment 좌표 (112x112 기준)
// 순서: right_eye, left_eye, nose, right_mouth, left_mouth
let arcFaceTemplate: [[Float]] = [
    [38.2946, 51.6963],   // right eye
    [73.5318, 51.5014],   // left eye
    [56.0252, 71.7366],   // nose tip
    [41.5493, 92.3655],   // right mouth corner
    [70.7299, 92.2041]    // left mouth corner
]
```

> **주의**: 눈과 입 좌표의 y값이 정확히 같지 않음.
> 좌우 대칭이 아니므로 미러링 시 주의 필요.

### Similarity Transform 계산 (Procrustes Analysis)

```swift
// OpenCV 구현: SVD 기반 최적 변환 계산
// 입력: src (검출된 5-point), dst (템플릿 5-point)
// 출력: 2x3 affine matrix

func estimateSimilarityTransform(src: [[Float]], dst: [[Float]]) -> CGAffineTransform {
    // 1. 중심점 계산
    let srcMean = mean(src)
    let dstMean = mean(dst)

    // 2. 중심 이동 (mean-centered)
    let srcCentered = src.map { [$0[0] - srcMean.x, $0[1] - srcMean.y] }
    let dstCentered = dst.map { [$0[0] - dstMean.x, $0[1] - dstMean.y] }

    // 3. 공분산 행렬 계산
    let H = matmul(transpose(srcCentered), dstCentered)

    // 4. SVD 분해
    let (U, S, Vt) = svd(H)

    // 5. 회전 행렬 계산 (반사 보정 포함)
    var R = matmul(Vt.T, U.T)
    if determinant(R) < 0 {
        Vt[1] = -Vt[1]
        R = matmul(Vt.T, U.T)
    }

    // 6. 스케일 계산
    let scale = trace(matmul(R, H)) / variance(srcCentered)

    // 7. 이동 계산
    let t = dstMean - scale * matmul(R, srcMean)

    // 8. 2x3 affine matrix 반환
    return CGAffineTransform(
        a: scale * R[0][0], b: scale * R[0][1],
        c: scale * R[1][0], d: scale * R[1][1],
        tx: t.x, ty: t.y
    )
}
```

### iOS Core Graphics로 warpAffine 구현

```swift
func alignFace(image: CGImage, landmarks: [CGPoint]) -> CGImage? {
    let outputSize = CGSize(width: 112, height: 112)

    // 1. 소스 랜드마크를 Float 배열로 변환
    let srcPoints = landmarks.map { [Float($0.x), Float($0.y)] }

    // 2. Similarity Transform 계산
    let transform = estimateSimilarityTransform(src: srcPoints, dst: arcFaceTemplate)

    // 3. Core Graphics context 생성
    guard let context = CGContext(
        data: nil,
        width: 112,
        height: 112,
        bitsPerComponent: 8,
        bytesPerRow: 112 * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // 4. Affine transform 적용 및 이미지 그리기
    context.concatenate(transform)
    context.draw(image, in: CGRect(origin: .zero, size: CGSize(
        width: CGFloat(image.width),
        height: CGFloat(image.height)
    )))

    return context.makeImage()
}
```

---

## SFaceRecognizer 상세 스펙

> 참조: [OpenCV FaceRecognizerSF](https://docs.opencv.org/4.x/da/d09/classcv_1_1FaceRecognizerSF.html),
> [MobileFaceNet 논문](https://arxiv.org/abs/1804.07573)

### 모델 정보

| 항목 | 값 |
|------|-----|
| 아키텍처 | MobileFaceNet |
| 학습 손실 | SFace Loss |
| 입력 크기 | 112 × 112 × 3 |
| 출력 크기 | 128-dim embedding |
| 파라미터 수 | ~1M |

### 모델 크기 및 양자화 옵션

| 모델 | 파일 크기 | 정확도 (LFW) | 비고 |
|------|----------|-------------|------|
| **face_recognition_sface_2021dec.onnx** | 37 MB | 99.60% | FP32, 현재 사용 |
| face_recognition_sface_2021dec_int8.onnx | ~10 MB | 99.32% | INT8 양자화 |

> **Int8 모델 고려사항**:
> - 크기: 37MB → ~10MB (약 70% 감소)
> - 정확도: 99.60% → 99.32% (0.28% 하락)
> - 속도: INT8이 더 빠를 수 있음 (ANE 최적화 시)
>
> PoC에서는 FP32 사용, 앱 크기 최적화 시 INT8 검토

### 전처리 스펙 (확정)

> 출처: [OpenCV face_recognize.cpp](https://github.com/opencv/opencv/blob/4.x/modules/objdetect/src/face_recognize.cpp) blobFromImage 호출

```cpp
// OpenCV C++ 구현 (face_recognize.cpp)
Mat inputBlob = dnn::blobFromImage(_aligned_img, 1, Size(112, 112),
                                   Scalar(0, 0, 0), true, false);
//                                  scale  size      mean    swapRB crop
```

| 항목 | OpenCV SFace | MobileFaceNet 논문 | 비고 |
|------|--------------|-------------------|------|
| **채널 순서** | **RGB** | RGB | swapRB=true |
| **Mean** | (0, 0, 0) | 127.5 | OpenCV는 0 사용 |
| **Std/Scale** | 1.0 | 128 | OpenCV는 1 사용 |
| **입력 크기** | 112×112 | 112×112 | 동일 |
| **입력 범위** | 0-255 | [-1, 1] | OpenCV는 정규화 없음 |

```swift
// iOS 구현 (OpenCV SFace 방식)
struct SFacePreprocessing {
    static let inputSize = (112, 112)
    static let colorFormat = "RGB"  // BGR 아님! iOS 기본 RGB 그대로 사용
    static let mean: Float = 0      // OpenCV SFace는 mean=0
    static let scale: Float = 1.0   // 정규화 없음, 0-255 그대로

    // iOS 이미지는 RGB이므로 변환 불필요
    // 0-255 범위 그대로 사용
}
```

> **주의**: MobileFaceNet 논문의 전처리(mean=127.5, std=128)와 다름!
> OpenCV SFace ONNX 모델은 0-255 RGB 입력을 그대로 사용.
>
> **확정**: ONNX→CoreML 변환 시 전처리 레이어 추가 없음.
> iOS에서는 RGB 0-255 그대로 입력.

### 임베딩 추출

```swift
func extractEmbedding(alignedFace: CGImage) -> [Float] {
    // 1. 전처리 (112x112, RGB, 0-255 범위 그대로)
    let input = preprocess(alignedFace)  // RGB, 0-255, mean=0, scale=1

    // 2. Core ML 추론
    let output = sfaceModel.predict(input)

    // 3. 128-dim embedding 반환
    return output.embedding  // [Float] of length 128
}
```

### 유사도 계산 및 임계값

```swift
// 두 가지 거리 측정 방식
enum DistanceType {
    case cosine     // 코사인 유사도 (높을수록 유사)
    case normL2     // L2 거리 (낮을수록 유사)
}

// 코사인 유사도 계산
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    let dotProduct = zip(a, b).map(*).reduce(0, +)
    let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
    let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
    return dotProduct / (normA * normB)
}

// L2 거리 계산
func l2Distance(_ a: [Float], _ b: [Float]) -> Float {
    let diff = zip(a, b).map { $0 - $1 }
    return sqrt(diff.map { $0 * $0 }.reduce(0, +))
}
```

### 동일인 판정 임계값 (데이터셋별)

| Dataset | Accuracy | L2 Threshold | Cosine Threshold |
|---------|----------|--------------|------------------|
| **LFW** | **99.60%** | **≤ 1.128** | **≥ 0.363** |
| CALFW | 93.95% | ≤ 1.149 | ≥ 0.340 |
| CPLFW | 91.05% | ≤ 1.204 | ≥ 0.275 |
| AgeDB-30 | 94.90% | ≤ 1.202 | ≥ 0.277 |
| CFP-FP | 94.80% | ≤ 1.253 | ≥ 0.212 |

> **권장**: LFW 기준 cosine ≥ 0.363 사용
> 더 엄격하게 하려면 0.4~0.5로 상향 조정
>
> **⚠️ 실제 앱 데이터 주의**:
> - LFW는 정면 얼굴 위주의 벤치마크 데이터셋
> - 실제 사용자 사진은 조명, 각도, 표정 다양성이 더 큼
> - 초기값 0.363으로 시작 후 실제 데이터로 튜닝 필요
> - False Positive(다른 사람을 같다고 판정)가 문제면 임계값 상향
> - False Negative(같은 사람을 다르다고 판정)가 문제면 임계값 하향

### 동일인 판정 함수

```swift
func isSamePerson(
    embedding1: [Float],
    embedding2: [Float],
    threshold: Float = 0.363
) -> (isSame: Bool, score: Float) {
    let score = cosineSimilarity(embedding1, embedding2)
    return (score >= threshold, score)
}
```

---

## 성능 벤치마크 (참고)

### YuNet (Intel i7-12700K)
| 입력 크기 | 추론 시간 |
|-----------|-----------|
| 160×120 | 0.42 ms |
| 320×240 | 0.89 ms |
| 320×320 | 1.6 ms |
| 640×480 | 2.98 ms |

### SFace (Intel i5 MacBook Pro 2019)
- 추론 시간: ~10 ms/face
- 처리량: ~100 FPS

> **iOS 예상**: Core ML + ANE 가속으로 더 빠를 수 있음.
> 실제 벤치마크 필요.

---

## iOS 구현 고려사항

### 1. Core ML 모델 입출력 확인
```swift
// Netron으로 모델 구조 확인 권장
// - 입력 이름, shape, 데이터 타입
// - 출력 이름, shape
// - sigmoid/softmax가 모델에 포함되어 있는지
```

### 2. MLMultiArray vs CVPixelBuffer
```swift
// YuNet: MLMultiArray (NCHW, BGR)
// SFace: MLMultiArray (NCHW, RGB)

// YuNet용 MLMultiArray 생성 (BGR 순서!)
let yunetInput = try MLMultiArray(shape: [1, 3, 320, 320], dataType: .float32)
for y in 0..<320 {
    for x in 0..<320 {
        let pixel = getPixel(image, x, y)  // iOS는 RGB
        yunetInput[[0, 0, y, x] as [NSNumber]] = NSNumber(value: pixel.b)  // B
        yunetInput[[0, 1, y, x] as [NSNumber]] = NSNumber(value: pixel.g)  // G
        yunetInput[[0, 2, y, x] as [NSNumber]] = NSNumber(value: pixel.r)  // R
    }
}

// SFace용 MLMultiArray 생성 (RGB 순서)
let sfaceInput = try MLMultiArray(shape: [1, 3, 112, 112], dataType: .float32)
for y in 0..<112 {
    for x in 0..<112 {
        let pixel = getPixel(alignedFace, x, y)
        sfaceInput[[0, 0, y, x] as [NSNumber]] = NSNumber(value: pixel.r)  // R
        sfaceInput[[0, 1, y, x] as [NSNumber]] = NSNumber(value: pixel.g)  // G
        sfaceInput[[0, 2, y, x] as [NSNumber]] = NSNumber(value: pixel.b)  // B
    }
}
```

### 3. Accelerate 프레임워크 활용
```swift
import Accelerate

// vDSP로 벡터 연산 최적화
func cosineSimilarityAccelerated(_ a: [Float], _ b: [Float]) -> Float {
    var dotProduct: Float = 0
    var normA: Float = 0
    var normB: Float = 0

    vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
    vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
    vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

    return dotProduct / (sqrt(normA) * sqrt(normB))
}
```

### 4. CoreMLHelpers 라이브러리
- [CoreMLHelpers](https://github.com/hollance/CoreMLHelpers) - MLMultiArray ↔ 이미지 변환 유틸리티

---

## 참고 자료

### YuNet 관련
- **[OpenCV face_detect.cpp](https://github.com/opencv/opencv/blob/master/modules/objdetect/src/face_detect.cpp)** - 공식 C++ 구현 (디코딩 로직)
- [OpenCV Zoo YuNet](https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet) - 모델 및 Python wrapper
- [libfacedetection.train](https://github.com/ShiqiYu/libfacedetection.train) - 학습 코드
- [YuNet ONNX I/O Discussion](https://github.com/opencv/opencv_zoo/issues/192) - ONNX 입출력 처리 논의
- [YuNet 논문](https://link.springer.com/article/10.1007/s11633-023-1423-y) - 아키텍처 상세

### FaceAligner 관련
- **[OpenCV face_recognize.cpp](https://github.com/opencv/opencv/blob/4.x/modules/objdetect/src/face_recognize.cpp)** - alignCrop 구현
- [InsightFace face_align.py](https://github.com/deepinsight/insightface/blob/master/python-package/insightface/utils/face_align.py) - Python 구현
- [Face Alignment PyImageSearch](https://pyimagesearch.com/2017/05/22/face-alignment-with-opencv-and-python/) - 튜토리얼

### SFace 관련
- **[OpenCV FaceRecognizerSF](https://docs.opencv.org/4.x/da/d09/classcv_1_1FaceRecognizerSF.html)** - API 문서
- [MobileFaceNet 논문](https://arxiv.org/abs/1804.07573) - 아키텍처 상세
- [OpenCV DNN Face Tutorial](https://docs.opencv.org/4.x/d0/dd4/tutorial_dnn_face.html) - 전체 파이프라인 튜토리얼

### iOS/Core ML 관련
- [CoreMLHelpers](https://github.com/hollance/CoreMLHelpers) - MLMultiArray 유틸리티
- [machinethink - MLMultiArray](https://machinethink.net/blog/coreml-image-mlmultiarray/) - 이미지 변환 가이드
- [CGAffineTransform](https://developer.apple.com/documentation/coregraphics/cgaffinetransform) - Apple 문서

### 기타
- [Bounding Box Encoding/Decoding](https://leimao.github.io/blog/Bounding-Box-Encoding-Decoding/) - variance 설명 (YuNet은 미사용)
- [SFace 성능 분석](https://trungtranthanh.medium.com/sface-the-fastest-also-powerful-deep-learning-face-recognition-model-in-the-world-8c56e7d489bc) - 벤치마크
