# YuNet 960×960 모델 교체 계획

## Context

### 문제
유사사진 분석에서 얼굴 4개가 감지되는데 +버튼이 1개만 표시됨.
- 원인: SFace 임베딩 norm이 낮아(3.5~4.6) `minEmbeddingNorm=7.0` 임계값을 통과 못함
- 근본 원인: YuNet이 **모든 이미지를 320×320으로 강제 리사이즈** → 작은 얼굴(6-8%)이 ~20px로 축소 → 랜드마크 불안정 → FaceAligner 크롭 품질 저하 → SFace norm 낮음
- 960×960 적용 시: 같은 얼굴이 ~60px로 표현 → 안정적 랜드마크 → 더 높은 norm 기대

### 목표
1. YuNet 입력 크기를 320×320 → 960×960으로 변경하여 인물 매칭 안정성 향상
2. 변경 전/후 성능(속도+정확도) 비교를 디버그 버튼으로 실기기 확인

---

## Phase 1: ONNX 모델 다운로드 및 CoreML 변환

### 1-1. YuNet ONNX 모델 다운로드
```bash
curl -L -o /tmp/yunet_2023mar.onnx \
  "https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx"
```

### 1-2. 변환 환경 사전 점검
```bash
# protobuf 버전 고정 (coremltools 호환)
pip3 install protobuf==3.20.0
# onnx2torch 설치 (직접 변환 실패 시 대비)
pip3 install onnx2torch
```

⚠️ **이력 참고**: 기존 YuNet 변환 시 ONNX 직접 변환 실패 → onnx2torch 경유 이력 있음
(260114SimilarEdit4.md:234)

### 1-3. ONNX 모델 구조 검증 (변환 전 필수)
Reshape/Flatten 연산 존재 여부 확인. 있으면 960×960 변환 실패 가능.

```python
import onnx
model = onnx.load("/tmp/yunet_2023mar.onnx")
for node in model.graph.node:
    if node.op_type in ('Reshape', 'Flatten', 'View'):
        print(f"⚠️ {node.op_type}: {node.input} → {node.output}")
```

### 1-4. CoreML 변환 (320 + 960 두 개 모두)
```python
import coremltools as ct

# 320×320 (기존과 동일 — 비교용 기준 모델)
m320 = ct.convert("/tmp/yunet_2023mar.onnx",
    inputs=[ct.TensorType(shape=(1, 3, 320, 320), name="input")],
    minimum_deployment_target=ct.target.iOS16)
m320.save("/tmp/YuNet320.mlpackage")

# 960×960 (새 모델)
m960 = ct.convert("/tmp/yunet_2023mar.onnx",
    inputs=[ct.TensorType(shape=(1, 3, 960, 960), name="input")],
    minimum_deployment_target=ct.target.iOS16)
m960.save("/tmp/YuNet960.mlpackage")

# 각 모델의 출력 이름 확인 (YuNetOutputNames 업데이트에 필수)
for label, m in [("320", m320), ("960", m960)]:
    print(f"\n=== {label} ===")
    for out in m.output_description:
        print(f"  {out.name}: {out.type}")
```

### 1-5. 변환 실패 시 Plan B
1. **onnx2torch 경유**: ONNX → PyTorch → CoreML (기존 변환 성공 이력 있음)
   ```python
   from onnx2torch import convert
   torch_model = convert("/tmp/yunet_2023mar.onnx")
   # traced → coremltools로 변환
   ```
2. onnxruntime으로 960 추론 먼저 테스트
3. ONNX 그래프 수정 후 재변환
4. 안 되면 640×640으로 축소

---

## Phase 2: 모델 파일 배치

### 두 모델 모두 프로젝트에 추가
```
PickPhoto/PickPhoto/MLModels/
├── YuNet.mlpackage/       ← 기존 320×320 (변경 없음, 비교 기준용)
└── YuNet960.mlpackage/    ← 새 960×960
```

- 기존 `YuNet.mlpackage`는 그대로 유지 (비교 기준)
- `YuNet960.mlpackage`를 추가
- Xcode가 자동으로 `YuNet960` Swift 클래스 생성

---

## Phase 3: 코드 수정

### 3-1. YuNetFaceDetector — 모델명/입력크기 파라미터화
현재: `self.model = try YuNet(configuration: config).model` (하드코딩)

변경: `init`에 `modelName`, `inputSize` 파라미터 추가
```swift
init(modelName: String = "YuNet",
     inputSize: Int = YuNetConfig.inputWidth,
     ...) throws {
    // Bundle에서 modelName으로 모델 로드
    guard let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else { ... }
    self.model = try MLModel(contentsOf: url, configuration: config)
    self.preprocessor = YuNetPreprocessor(inputSize: inputSize)
    self.decoder = YuNetDecoder(inputSize: inputSize)
}
```

- `shared` 싱글톤은 기존대로 320 사용 (기존 로직 영향 없음)
- DEBUG에서만 960 인스턴스 별도 생성

### 3-2. YuNetPreprocessor — inputSize 파라미터화
현재: `YuNetConfig.inputWidth` 참조 (전역 상수)

변경: `init(inputSize:)` 추가, 기본값은 `YuNetConfig.inputWidth`
```swift
private let inputWidth: Int
private let inputHeight: Int

init(inputSize: Int = YuNetConfig.inputWidth) {
    self.inputWidth = inputSize
    self.inputHeight = inputSize
}
```

### 3-3. YuNetDecoder — inputSize 파라미터화
동일 패턴:
```swift
init(inputSize: Int = YuNetConfig.inputWidth) {
    self.inputWidth = inputSize
    self.inputHeight = inputSize
}
```

### 3-4. YuNetTypes.swift — 출력 이름 확인
같은 ONNX 모델을 입력 크기만 바꿔 변환하면 그래프 구조가 동일하므로
**출력 이름(var_762 등)이 동일할 가능성이 높음** (FCN 구조).

- **변환 후 우선 확인**: 320/960 출력 이름이 같으면 기존 코드 변경 불필요
- **다를 경우만**: YuNetDecoder에 outputNames를 init 파라미터로 주입하여 모델별 분기

### 3-5. FaceDebug 비교 기능 추가
**파일**: `ViewerViewController+FaceDebug.swift`

기존 FD 버튼에 **320 vs 960 비교 모드** 추가:
```
[FaceDebug] ═══ 320 vs 960 비교 ═══
[FaceDebug] ── 320×320 ──
[FaceDebug]   시간: 12ms
[FaceDebug]   감지: 4개
[FaceDebug]   norms: [9.4, 2.4, 6.8, 5.2]
[FaceDebug] ── 960×960 ──
[FaceDebug]   시간: 85ms
[FaceDebug]   감지: 4개
[FaceDebug]   norms: [8.5, 7.8, 7.1, 6.9]
[FaceDebug] ═══ 완료 ═══
```

구현 방식:
1. 두 개의 YuNetFaceDetector 인스턴스 생성 (320, 960)
2. 같은 이미지(2200px)로 각각 감지 실행
3. 시간 측정: 워밍업 1회 + 본측정 3회 median (`CFAbsoluteTimeGetCurrent()`)
4. 각 감지 결과로 SFace 임베딩 추출 + norm 비교
5. Alert에 결과 표시

### 3-6. 자동 대응 (변경 불필요)
- `FaceAligner.swift` — 무관 (112×112 고정 출력)

---

## Phase 4: 프로덕션 전환 (비교 결과 확인 후)

960 모델이 효과적임이 확인되면:
1. `YuNetConfig.inputWidth/Height` → 960으로 변경
2. `shared` 싱글톤이 960 모델 사용하도록 변경
3. 320 모델 제거 (선택)

**이 단계는 Phase 3의 비교 결과를 보고 진행 여부 판단**

---

## Phase 5: 검증

### 5-1. 빌드 테스트
```bash
xcodebuild -project PickPhoto/PickPhoto.xcodeproj -scheme PickPhoto -configuration Debug
```

### 5-2. 실기기 FaceDebug 비교 테스트
- +버튼 1개였던 사진들에서 FD 버튼으로 320 vs 960 비교
- **확인 포인트**:
  - 속도 차이 (320 대비 960이 몇 배 느린지)
  - norm 개선 폭 (7.0 이상이 몇 개 늘어나는지)
  - 감지 개수 변화

### 5-3. norm 개선 불충분 시
- `minEmbeddingNorm` 7.0 → 5.0 완화 검토 (별도 판단)

---

## 리스크 & 대비

| 리스크 | 확률 | 대비 |
|--------|------|------|
| Reshape/Flatten으로 변환 실패 | 낮음 | Plan B: onnxruntime 테스트 → 640 축소 |
| 출력 이름 변경 | 확실 | 변환 후 inspect → YuNetOutputNames 업데이트 |
| norm 개선 불충분 | 중간 | minEmbeddingNorm 5.0 완화 병행 |
| 추론 속도 과다 | 낮음 | 실측 후 판단, 필요 시 640 축소 |

## 주요 파일 경로

| 파일 | 변경 | 내용 |
|------|------|------|
| `MLModels/YuNet.mlpackage` | 유지 | 320 기준 모델 |
| `MLModels/YuNet960.mlpackage` | **추가** | 960 새 모델 |
| `YuNet/YuNetTypes.swift` | **수정** | 960 출력 이름 추가 |
| `YuNet/YuNetFaceDetector.swift` | **수정** | modelName/inputSize 파라미터 |
| `YuNet/YuNetPreprocessor.swift` | **수정** | inputSize 파라미터 |
| `YuNet/YuNetDecoder.swift` | **수정** | inputSize 파라미터 |
| `Viewer/ViewerViewController+FaceDebug.swift` | **수정** | 320 vs 960 비교 기능 |
