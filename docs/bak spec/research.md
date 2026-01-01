# Research: 유사 사진 정리 기능

**Date**: 2025-12-31
**Feature**: 001-similar-photo

---

## 1. Vision Framework - 이미지 유사도 비교

### Decision
`VNGenerateImageFeaturePrintRequest`를 사용하여 이미지의 Feature Print를 생성하고, `computeDistance` 메서드로 유클리드 거리 계산

### Rationale
- iOS 11+에서 기본 제공되는 공식 API
- 신경망 기반 고차원 벡터로 의미론적 유사도 계산 가능
- 조명, 회전, 크기 변화 등에 강건함
- 별도 ML 모델 없이 구현 가능

### Implementation Pattern

```swift
import Vision

func generateFeaturePrint(for cgImage: CGImage) async throws -> VNFeaturePrintObservation {
    let request = VNGenerateImageFeaturePrintRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])

    guard let result = request.results?.first as? VNFeaturePrintObservation else {
        throw SimilarityError.featurePrintGenerationFailed
    }
    return result
}

func calculateDistance(_ print1: VNFeaturePrintObservation,
                       _ print2: VNFeaturePrintObservation) throws -> Float {
    var distance = Float(0)
    try print1.computeDistance(&distance, to: print2)
    return distance  // 0.0 = 동일, 10.0 이하 = 유사 (PRD 기준)
}
```

### Alternatives Considered
- **pHash (Perceptual Hash)**: 더 빠르지만 의미론적 유사도 낮음. Phase 7 최적화 시 고려
- **Core ML 커스텀 모델**: 오버엔지니어링, MVP에 불필요

---

## 2. Vision Framework - 얼굴 감지

### Decision
`VNDetectFaceRectanglesRequest`를 사용하여 얼굴 영역 감지

### Rationale
- iOS 11+에서 기본 제공
- boundingBox로 얼굴 위치/크기 정보 제공
- 신뢰도(confidence) 값으로 필터링 가능

### Implementation Pattern

```swift
import Vision

func detectFaces(in cgImage: CGImage) async throws -> [VNFaceObservation] {
    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])
    return request.results ?? []
}

// Vision 좌표 (왼쪽 아래 원점) → UIView 좌표 (왼쪽 위 원점) 변환
func convertBoundingBox(_ box: CGRect, to viewBounds: CGRect) -> CGRect {
    return CGRect(
        x: box.origin.x * viewBounds.width,
        y: (1 - box.maxY) * viewBounds.height,
        width: box.width * viewBounds.width,
        height: box.height * viewBounds.height
    )
}
```

### Key Considerations
- **좌표 변환 필수**: Vision은 왼쪽 아래 원점, UIKit은 왼쪽 위 원점
- **화면 너비 5% 필터**: `boundingBox.width * viewWidth >= viewWidth * 0.05`
- **최대 5개 제한**: 크기순 정렬 후 상위 5개 선택

### Alternatives Considered
- **VNDetectFaceLandmarksRequest**: 더 상세한 얼굴 특징점 제공하지만 MVP에 불필요

---

## 3. 성능 최적화 전략

### Decision
백그라운드 QoS에서 비동기 처리, 동시성 제한(5개), 이미지 다운스케일링

### Rationale
- 그리드 스크롤 네이티브 주사율 유지를 위해 메인 스레드 블로킹 방지
- 메모리 폭발 방지를 위한 동시 작업 수 제한
- 분석용 이미지는 중간 해상도로 충분

### Implementation Pattern

```swift
// 동시성 제한된 배치 처리
func analyzeImages(_ assets: [PHAsset], maxConcurrent: Int = 5) async -> [SimilarGroup] {
    await withTaskGroup(of: AnalysisResult?.self) { group in
        var pending = 0
        var results: [AnalysisResult] = []

        for asset in assets {
            if pending >= maxConcurrent {
                if let result = await group.next() {
                    results.append(result)
                    pending -= 1
                }
            }

            pending += 1
            group.addTask(priority: .background) {
                await self.analyzeSingleAsset(asset)
            }
        }

        for await result in group {
            if let r = result { results.append(r) }
        }

        return self.groupByDistance(results)
    }
}

// 분석용 이미지 축소
func requestAnalysisImage(for asset: PHAsset) -> CGImage? {
    let options = PHImageRequestOptions()
    options.deliveryMode = .fastFormat
    options.resizeMode = .fast

    let targetSize = CGSize(width: 480, height: 480)  // 분석용 중간 해상도
    // PHCachingImageManager 사용
}
```

### Alternatives Considered
- **캐싱**: MVP에서는 제외, Phase 7에서 성능 이슈 발생 시 추가
- **사전 분석 (Prefetching)**: MVP에서는 실시간 분석만, 추후 최적화

---

## 4. 테두리 애니메이션 구현

### Decision
`CAShapeLayer` + `CAKeyframeAnimation`으로 빛이 테두리를 회전하는 효과 구현

### Rationale
- Core Animation은 GPU 가속으로 성능 우수
- strokeStart/strokeEnd 애니메이션으로 "빛 회전" 효과 가능
- 셀 재사용 시 레이어 제거/추가로 메모리 효율적

### Implementation Pattern

```swift
class SimilarBorderLayer: CAShapeLayer {
    private var gradientLayer: CAGradientLayer?
    private var animation: CAKeyframeAnimation?

    func configure(for bounds: CGRect) {
        path = UIBezierPath(rect: bounds.insetBy(dx: 2, dy: 2)).cgPath
        strokeColor = UIColor.white.cgColor
        fillColor = UIColor.clear.cgColor
        lineWidth = 3

        // strokeEnd 애니메이션으로 빛 회전 효과
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = 0.0
        anim.toValue = 1.0
        anim.duration = 1.5
        anim.repeatCount = .infinity
        add(anim, forKey: "lightRotation")
    }

    func stopAnimation() {
        removeAllAnimations()
    }
}

// PhotoCell에서 사용
extension PhotoCell {
    func showSimilarBorder() {
        if similarBorderLayer == nil {
            similarBorderLayer = SimilarBorderLayer()
            layer.addSublayer(similarBorderLayer!)
        }
        similarBorderLayer?.configure(for: bounds)
    }

    func hideSimilarBorder() {
        similarBorderLayer?.stopAnimation()
        similarBorderLayer?.removeFromSuperlayer()
        similarBorderLayer = nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hideSimilarBorder()
    }
}
```

### Key Considerations
- **prepareForReuse에서 제거**: 셀 재사용 시 애니메이션 누적 방지
- **didEndDisplaying에서 제거**: 화면 밖 셀 애니메이션 제거
- **모션 감소 설정**: `UIAccessibility.isReduceMotionEnabled` 체크 후 정적 테두리로 대체

---

## 5. iOS 버전별 UI 분기

### Decision
iOS 26+는 시스템 네비바/툴바 사용, iOS 16~25는 기존 FloatingUI 사용

### Rationale
- iOS 26+ Liquid Glass 디자인 자동 적용
- 기존 FloatingUI 컴포넌트 재사용으로 일관된 UX

### Implementation Pattern

```swift
if #available(iOS 26.0, *) {
    // 시스템 네비바/툴바 사용
    navigationItem.rightBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "square.stack.3d.up"),
        style: .plain,
        target: self,
        action: #selector(similarPhotoButtonTapped)
    )
} else {
    // 커스텀 FloatingTitleBar 사용
    floatingTitleBar.addButton(
        icon: UIImage(systemName: "square.stack.3d.up"),
        position: .right,
        action: { [weak self] in self?.similarPhotoButtonTapped() }
    )
}
```

---

## 6. 얼굴 크롭 규칙

### Decision
bounding box 기준 30% 여백 추가, 정사각형 비율, 수평 유지

### Rationale
- 30% 여백으로 얼굴 주변 컨텍스트 포함
- 정사각형 비율로 2열 그리드에 일관된 표시
- MVP에서는 얼굴 각도 무시 (추후 개선)

### Implementation Pattern

```swift
func cropFaceRegion(from image: CGImage, faceBox: CGRect) -> CGImage? {
    let imageWidth = CGFloat(image.width)
    let imageHeight = CGFloat(image.height)

    // Vision 좌표 → 이미지 좌표
    let faceRect = CGRect(
        x: faceBox.origin.x * imageWidth,
        y: (1 - faceBox.maxY) * imageHeight,
        width: faceBox.width * imageWidth,
        height: faceBox.height * imageHeight
    )

    // 30% 여백 추가
    let padding = max(faceRect.width, faceRect.height) * 0.3
    var expandedRect = faceRect.insetBy(dx: -padding, dy: -padding)

    // 정사각형으로 조정
    let size = max(expandedRect.width, expandedRect.height)
    expandedRect = CGRect(
        x: expandedRect.midX - size / 2,
        y: expandedRect.midY - size / 2,
        width: size,
        height: size
    )

    // 이미지 경계 클램핑
    expandedRect = expandedRect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

    return image.cropping(to: expandedRect)
}
```

---

## Summary

| 영역 | 결정 | 근거 |
|------|------|------|
| 유사도 비교 | VNGenerateImageFeaturePrintRequest | 공식 API, 의미론적 유사도 |
| 얼굴 감지 | VNDetectFaceRectanglesRequest | 공식 API, boundingBox 제공 |
| 성능 | 백그라운드 비동기 + 동시성 제한 | 네이티브 주사율 유지, 메모리 관리 |
| 테두리 애니메이션 | CAShapeLayer + strokeEnd 애니메이션 | GPU 가속, 셀 재사용 호환 |
| UI 분기 | iOS 26+ 시스템 UI / iOS 16~25 FloatingUI | Liquid Glass 자동 적용 |
| 얼굴 크롭 | 30% 여백, 정사각형, 수평 유지 | PRD 요구사항 |
