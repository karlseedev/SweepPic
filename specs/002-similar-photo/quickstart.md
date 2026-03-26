# Quickstart: 유사 사진 정리 기능

**Date**: 2026-01-02
**Branch**: `002-similar-photo`

---

## 개발 환경 요구사항

| 항목 | 버전 |
|------|------|
| Xcode | 15.0+ |
| Swift | 5.9+ |
| iOS Target | 16.0+ |
| macOS (개발) | Ventura 13.0+ |

---

## 빌드 및 실행

### 1. 프로젝트 열기

```bash
cd /Users/karl/Project/Photos/iOS
open SweepPic/SweepPic.xcodeproj
```

### 2. 시뮬레이터/기기 선택

- **권장**: iPhone 15 Pro (ProMotion 테스트)
- **대안**: iPhone 14 이상 (iOS 16+)

### 3. 빌드 및 실행

```bash
xcodebuild -project SweepPic/SweepPic.xcodeproj \
  -scheme SweepPic \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## 테스트

### 단위 테스트

```bash
swift test --filter AppCoreTests
```

### UI 테스트

```bash
xcodebuild test \
  -project SweepPic/SweepPic.xcodeproj \
  -scheme SweepPic \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## 핵심 컴포넌트 위치

### 신규 생성 파일

| 파일 | 경로 | 역할 |
|------|------|------|
| SimilarityAnalyzer | `Features/SimilarPhoto/Analysis/` | Vision 유사도 분석 |
| FaceDetector | `Features/SimilarPhoto/Analysis/` | Vision 얼굴 감지 |
| SimilarityCache | `Features/SimilarPhoto/Analysis/` | 분석 결과 캐시 |
| BorderAnimationLayer | `Features/SimilarPhoto/UI/` | 테두리 애니메이션 |
| FaceButtonOverlay | `Features/SimilarPhoto/UI/` | +버튼 오버레이 |
| FaceComparisonViewController | `Features/SimilarPhoto/UI/` | 얼굴 비교 화면 |
| SimilarPhotoGroup | `Features/SimilarPhoto/Models/` | 그룹 모델 |
| CachedFace | `Features/SimilarPhoto/Models/` | 얼굴 캐시 모델 |

### 기존 수정 파일

| 파일 | 경로 | 변경 내용 |
|------|------|----------|
| GridViewController | `Features/Grid/` | 테두리 표시 통합 |
| ViewerViewController | `Features/Viewer/` | +버튼 오버레이 통합 |
| TrashStore | `Stores/` | 삭제 후 그룹 무효화 |

---

## 기능 테스트 체크리스트

### 그리드 테두리

- [ ] 스크롤 멈춤 후 0.3초 대기 → 테두리 표시
- [ ] 스크롤 재개 시 → 테두리 사라짐
- [ ] 테두리 탭 → 뷰어 이동

### 뷰어 +버튼

- [ ] 유사 사진 진입 시 +버튼 자동 표시
- [ ] eye 아이콘 탭 → +버튼 숨김
- [ ] 스와이프 후 복귀 → +버튼 재표시

### 얼굴 비교 화면

- [ ] 2열 그리드 표시
- [ ] 헤더 "인물 N (M장)" 표시
- [ ] 순환 버튼 → 다음 인물
- [ ] Delete → 휴지통 이동 + 그리드 복귀

---

## 주요 API 사용법

### Vision 유사도 분석

```swift
let request = VNGenerateImageFeaturePrintRequest()
let handler = VNImageRequestHandler(cgImage: image, options: [:])
try handler.perform([request])

if let result = request.results?.first as? VNFeaturePrintObservation {
    var distance: Float = 0
    try result.computeDistance(&distance, to: otherFeaturePrint)
    // distance <= 10.0 이면 유사
}
```

### Vision 얼굴 감지

```swift
let request = VNDetectFaceRectanglesRequest()
let handler = VNImageRequestHandler(cgImage: image, options: [:])
try handler.perform([request])

for face in request.results ?? [] {
    let boundingBox = face.boundingBox
    // Vision 좌표 (0~1, 원점 좌하단)
}
```

### 좌표 변환 (Vision → UIKit)

```swift
func convertToUIKit(
    boundingBox: CGRect,
    imageSize: CGSize,
    viewerFrame: CGRect
) -> CGRect {
    let scale = min(viewerFrame.width / imageSize.width,
                    viewerFrame.height / imageSize.height)
    let offsetX = (viewerFrame.width - imageSize.width * scale) / 2
    let offsetY = (viewerFrame.height - imageSize.height * scale) / 2

    return CGRect(
        x: boundingBox.origin.x * imageSize.width * scale + offsetX,
        y: (1 - boundingBox.maxY) * imageSize.height * scale + offsetY,
        width: boundingBox.width * imageSize.width * scale,
        height: boundingBox.height * imageSize.height * scale
    )
}
```

---

## 성능 목표

| 항목 | 목표 |
|------|------|
| 테두리 표시 | 스크롤 멈춤 후 1초 이내 |
| +버튼 표시 (캐시 hit) | 즉시 |
| +버튼 표시 (캐시 miss) | 0.5초 이내 |
| 그리드 스크롤 | 60fps / 120fps (ProMotion) |
| 동시 분석 | 최대 5개 |
| 캐시 크기 | 최대 500장 |

---

## 디버깅 팁

### 분석 상태 확인

```swift
// SimilarityCache에서 상태 로깅
func logState(for assetID: String) {
    let state = cache.getState(for: assetID)
    print("Asset \(assetID): \(state)")
}
```

### 테두리 애니메이션 확인

- Xcode > Debug > View Debugging > Rendering > Color Blended Layers

### 메모리 사용량 모니터링

- Xcode > Debug Navigator > Memory
- 캐시 eviction이 제대로 동작하는지 확인

---

## 참고 문서

- [spec.md](./spec.md) - 기능 명세
- [plan.md](./plan.md) - 구현 계획
- [research.md](./research.md) - 기술 리서치
- [data-model.md](./data-model.md) - 데이터 모델
- [prd9.md](../../docs/prd9.md) - PRD 원본
- [prd9algorithm.md](../../docs/prd9algorithm.md) - 알고리즘 상세
