# Quickstart: 유사 사진 정리 기능

**Date**: 2025-12-31
**Feature**: 001-similar-photo

---

## Prerequisites

- Xcode 15+ (Swift 5.9+)
- iOS 16+ Simulator 또는 실제 기기
- 사진 라이브러리 접근 권한 (앱 최초 실행 시 승인)
- 테스트용 연속 촬영 사진 (얼굴 포함, 3장 이상)

---

## Quick Setup

### 1. 프로젝트 열기

```bash
cd /Users/karl/Project/Photos/iOS
open PickPhoto/PickPhoto.xcodeproj
```

### 2. 빌드 및 실행

```bash
# 시뮬레이터에서 빌드
xcodebuild -project PickPhoto/PickPhoto.xcodeproj \
           -scheme PickPhoto \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build

# 또는 Xcode에서 Cmd+R
```

### 3. AppCore 패키지 테스트

```bash
# AppCore 단위 테스트 실행
swift test --filter AppCoreTests
```

---

## Key Files to Modify

### AppCore (비즈니스 로직)

| 파일 | 역할 | 우선순위 |
|------|------|----------|
| `Sources/AppCore/Models/SimilarGroup.swift` | 유사 그룹 모델 | Phase 1 |
| `Sources/AppCore/Models/FaceRegion.swift` | 얼굴 영역 모델 | Phase 4 |
| `Sources/AppCore/Services/SimilarityService.swift` | Vision 유사도 분석 | Phase 1 |
| `Sources/AppCore/Services/FaceDetectionService.swift` | Vision 얼굴 감지 | Phase 4 |
| `Sources/AppCore/Stores/SimilarPhotoStore.swift` | 상태 관리 | Phase 2 |

### PickPhoto (UI)

| 파일 | 역할 | 우선순위 |
|------|------|----------|
| `Features/Grid/SimilarBorderLayer.swift` | 테두리 애니메이션 | Phase 2 |
| `Features/Grid/PhotoCell.swift` | 셀 테두리 표시 | Phase 2 |
| `Features/Grid/GridViewController.swift` | 스크롤 감지/분석 트리거 | Phase 2 |
| `Features/Viewer/ViewerViewController.swift` | 유사사진정리버튼 | Phase 3 |
| `Features/Viewer/FacePlusButtonOverlay.swift` | + 버튼 오버레이 | Phase 4 |
| `Features/FaceComparison/FaceComparisonViewController.swift` | 얼굴 비교 화면 | Phase 5 |

---

## Development Workflow

### Phase 순서

```
Phase 1: 유사도 분석 기반 구축
    │
    ▼
Phase 2: 그리드 트리거 (테두리 애니메이션)
    │
    ▼
Phase 3: 뷰어 트리거 (유사사진정리버튼)
    │
    ▼
Phase 4: 얼굴 분석 및 + 버튼
    │
    ▼
Phase 5: 얼굴 비교 화면
    │
    ▼
Phase 6: 삭제 및 통합
    │
    ▼
Phase 7 (선택): 최적화 (캐싱, pHash)
```

### 각 Phase 완료 기준

| Phase | 완료 기준 |
|-------|----------|
| 1 | SimilarityService 단위 테스트 통과, 거리 10.0 기준 그룹핑 동작 |
| 2 | 그리드에서 스크롤 멈춤 시 테두리 표시, 네이티브 주사율 유지 |
| 3 | 뷰어에서 조건 충족 시 버튼 표시, 스와이프 시 재평가 |
| 4 | + 버튼 5개 이하 표시, 5% 이상 얼굴만, 겹침 처리 |
| 5 | 2열 그리드 표시, 인물 순환, 선택/해제 동작 |
| 6 | Delete 시 휴지통 이동, 뷰어 복귀, 휴지통 복구 동작 |

---

## Testing Guide

### 수동 테스트 시나리오

1. **그리드 테두리 테스트**
   - 연속 촬영 얼굴 사진 5장 준비
   - 그리드에서 해당 사진들이 보이도록 스크롤
   - 0.3초 후 테두리 애니메이션 확인
   - 다시 스크롤하면 테두리 해제 확인

2. **뷰어 버튼 테스트**
   - 테두리 표시된 사진 탭하여 뷰어 진입
   - 우측 상단 유사사진정리버튼 확인
   - 다른 사진으로 스와이프 후 버튼 상태 확인

3. **얼굴 비교 테스트**
   - 유사사진정리버튼 탭
   - 얼굴 위 + 버튼 확인
   - + 버튼 탭하여 비교 화면 진입
   - 사진 선택 → Delete → 뷰어 복귀 확인

### 성능 테스트

```swift
// 5만 장 라이브러리에서 테스트
// 1. 그리드 스크롤 FPS 측정 (네이티브 주사율 유지)
// 2. 테두리 표시 시간 측정 (1초 이내)
// 3. + 버튼 표시 시간 측정 (0.5초 이내)
```

---

## Common Issues

### 1. Vision 분석이 느림

**해결**: 분석용 이미지 해상도 확인 (480px 권장)

```swift
let targetSize = CGSize(width: 480, height: 480)
```

### 2. 테두리 애니메이션 끊김

**해결**: 메인 스레드에서 레이어 추가, 백그라운드에서 분석

```swift
DispatchQueue.main.async {
    cell.showSimilarBorder()
}
```

### 3. 얼굴 좌표가 맞지 않음

**해결**: Vision 좌표계 → UIKit 좌표계 변환 확인

```swift
// Vision: 왼쪽 아래 원점 (0,0)
// UIKit: 왼쪽 위 원점 (0,0)
y = (1 - boundingBox.maxY) * height
```

### 4. 메모리 경고

**해결**: 동시 분석 수 제한 (5개), 셀 재사용 시 레이어 정리

```swift
override func prepareForReuse() {
    super.prepareForReuse()
    hideSimilarBorder()
}
```

---

## API Reference

### SimilarityService

```swift
/// 이미지 유사도 분석 서비스
class SimilarityService {
    /// 주어진 범위 내에서 유사 그룹 찾기
    func findSimilarGroups(
        assets: [PHAsset],
        threshold: Float = 10.0
    ) async -> [SimilarGroup]

    /// 두 이미지 간 거리 계산
    func calculateDistance(
        asset1: PHAsset,
        asset2: PHAsset
    ) async throws -> Float
}
```

### FaceDetectionService

```swift
/// 얼굴 감지 서비스
class FaceDetectionService {
    /// 이미지에서 얼굴 감지
    func detectFaces(
        in asset: PHAsset,
        minSizeRatio: CGFloat = 0.05,
        maxCount: Int = 5
    ) async throws -> [FaceRegion]

    /// 얼굴 크롭 이미지 생성
    func cropFace(
        from asset: PHAsset,
        region: FaceRegion,
        padding: CGFloat = 0.3
    ) async throws -> UIImage
}
```

### SimilarPhotoStore

```swift
/// 유사 사진 상태 관리 스토어
class SimilarPhotoStore: ObservableObject {
    @Published var state: SimilarPhotoState

    /// 화면 범위 분석 (그리드용)
    func analyzeVisibleRange(indices: Range<Int>) async

    /// 현재 사진 분석 (뷰어용)
    func analyzeCurrentPhoto(index: Int) async

    /// 테두리 표시 여부 확인
    func shouldShowBorder(for assetIdentifier: String) -> Bool

    /// 유사사진정리버튼 표시 여부
    func shouldShowSimilarButton() -> Bool
}
```
