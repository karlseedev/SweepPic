# PRD 8 알고리즘 상세: 유사 사진 분류 및 동일 인물 매칭

**버전**: 1.1
**작성일**: 2025-12-31
**관련 문서**: [PRD 8](./prd8.md), [Spec](../specs/001-similar-photo/spec.md)

> **참조 안내**: 이 문서는 prd8.md의 **알고리즘 구현 상세**를 다룹니다.
> 비즈니스 규칙(그룹 정의, 인물 번호 부여 규칙, 얼굴 크기 필터 등)은 **prd8.md 참조**.
> - 그룹 유형 정의: prd8.md §2.1.6
> - 인물 번호 부여 순서: prd8.md §2.4.4
> - 얼굴 크기 필터 (5%): prd8.md §2.4.2

---

## 1. 개요

이 문서는 유사 사진 정리 기능의 핵심 알고리즘을 상세히 정의합니다:
1. **유사 사진 분류**: 연속 촬영된 비슷한 사진들을 그룹으로 묶기
2. **동일 인물 매칭**: 그룹 내에서 "인물 1"이 항상 같은 사람이 되도록 매칭
3. **자동 검증**: 매칭이 올바른지 확인하는 방법

---

## 2. 기술 스택

### Vision Framework API

| 용도 | API | 반환값 |
|------|-----|--------|
| 이미지 유사도 | `VNGenerateImageFeaturePrintRequest` | `VNFeaturePrintObservation` |
| 얼굴 위치 | `VNDetectFaceRectanglesRequest` | `VNFaceObservation` (boundingBox) |
| 얼굴 특징점 | `VNDetectFaceLandmarksRequest` | `VNFaceObservation` (landmarks) |

### 중요 사실

**Vision Framework는 "얼굴 인식(Face Recognition)"을 직접 제공하지 않습니다.**

- `VNDetectFaceRectanglesRequest`: 얼굴이 **어디에** 있는지만 알려줌
- `VNGenerateImageFeaturePrintRequest`: **이미지 전체**의 유사도만 비교
- "누구인지"를 알려면 → **얼굴 크롭 후 Feature Print 비교** 필요

---

## 3. 유사 사진 분류 알고리즘

### 3.1 목표

연속 촬영된 비슷한 사진들을 하나의 그룹으로 묶기

### 3.2 입력/출력

```
입력: 사진 리스트 (시간순 정렬됨, 앞뒤 7장 범위)
출력: 유사 사진 그룹들 (각 그룹 최소 3장)
```

### 3.3 알고리즘 흐름

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: 각 사진의 Feature Print 생성                        │
│                                                              │
│  사진 1   사진 2   사진 3   사진 4   사진 5   사진 6   사진 7  │
│    ↓        ↓        ↓        ↓        ↓        ↓        ↓   │
│  [FP-1]  [FP-2]  [FP-3]  [FP-4]  [FP-5]  [FP-6]  [FP-7]    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Step 2: 인접 사진끼리 거리 계산                              │
│                                                              │
│  1↔2: 3.2  2↔3: 4.1  3↔4: 2.8  4↔5: 15.2  5↔6: 3.5  6↔7: 4.0│
│    ✓        ✓        ✓        ✗         ✓        ✓         │
│  (10 이하)                  (10 초과)                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Step 3: 거리 10.0 기준으로 그룹 분리                         │
│                                                              │
│  결과: [그룹 A: 1,2,3,4]  [그룹 B: 5,6,7]                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Step 4: 얼굴 필터링                                         │
│                                                              │
│  그룹 A (4장) → 얼굴 있는 사진: 4장 → 유효 (3장 이상)         │
│  그룹 B (3장) → 얼굴 있는 사진: 2장 → 무효 (3장 미만)         │
│                                                              │
│  최종 결과: [그룹 A: 1,2,3,4]                                │
└─────────────────────────────────────────────────────────────┘
```

### 3.4 거리 임계값 (이미지 전체 비교)

| 거리 | 의미 | 처리 |
|------|------|------|
| 0 | 완전 동일 | 같은 그룹 |
| 0~5 | 거의 동일 (연속 촬영) | 같은 그룹 |
| 5~10 | 유사함 | 같은 그룹 |
| 10~15 | 어느 정도 비슷 | **그룹 분리** |
| 15+ | 다른 사진 | 다른 그룹 |

**임계값: 10.0** (PRD 기준, 추후 조정 가능)

### 3.5 구현 코드

```swift
// Step 1: Feature Print 생성
func generateFeaturePrint(for asset: PHAsset) async throws -> VNFeaturePrintObservation {
    let image = await loadImage(asset, targetSize: CGSize(width: 480, height: 480))
    let request = VNGenerateImageFeaturePrintRequest()
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])

    guard let result = request.results?.first as? VNFeaturePrintObservation else {
        throw SimilarityError.featurePrintGenerationFailed
    }
    return result
}

// Step 2: 인접 사진 거리 계산
func calculateAdjacentDistances(featurePrints: [VNFeaturePrintObservation]) throws -> [Float] {
    var distances: [Float] = []
    for i in 0..<(featurePrints.count - 1) {
        var distance: Float = 0
        try featurePrints[i].computeDistance(&distance, to: featurePrints[i + 1])
        distances.append(distance)
    }
    return distances
}

// Step 3: 그룹핑
func groupSimilarPhotos(
    assets: [PHAsset],
    distances: [Float],
    threshold: Float = 10.0
) -> [[PHAsset]] {
    var groups: [[PHAsset]] = []
    var currentGroup: [PHAsset] = [assets[0]]

    for i in 0..<distances.count {
        if distances[i] <= threshold {
            // 유사함 → 같은 그룹에 추가
            currentGroup.append(assets[i + 1])
        } else {
            // 다름 → 새 그룹 시작
            if currentGroup.count >= 3 {
                groups.append(currentGroup)
            }
            currentGroup = [assets[i + 1]]
        }
    }

    // 마지막 그룹 처리
    if currentGroup.count >= 3 {
        groups.append(currentGroup)
    }

    return groups
}

// Step 4: 얼굴 필터링
func filterGroupsWithFaces(groups: [[PHAsset]]) async -> [[PHAsset]] {
    var filteredGroups: [[PHAsset]] = []

    for group in groups {
        var assetsWithFaces: [PHAsset] = []
        for asset in group {
            if await hasFace(asset) {
                assetsWithFaces.append(asset)
            }
        }
        if assetsWithFaces.count >= 3 {
            filteredGroups.append(assetsWithFaces)
        }
    }

    return filteredGroups
}
```

---

## 4. 동일 인물 매칭 알고리즘

### 4.1 목표

유사 사진 그룹 내에서 "인물 1"이 항상 같은 사람이 되도록 매칭

### 4.2 방식 비교

| 방식 | 정확도 | 속도 | 복잡도 |
|------|--------|------|--------|
| 위치 기반 (MVP) | ~90% | 빠름 | 낮음 |
| Feature Print 기반 | ~98% | 느림 | 중간 |
| 하이브리드 (권장) | ~98% | 중간 | 중간 |

### 4.3 위치 기반 매칭 (1차)

#### 원리
연속 촬영 시 사람들의 위치가 거의 변하지 않는다는 가정

#### 알고리즘

```
┌─────────────────────────────────────────────────────────────┐
│  기준 사진 (현재 뷰어에서 보고 있는 사진)                     │
│                                                              │
│  ┌─────┐ ┌─────┐ ┌─────┐                                    │
│  │ 👤  │ │ 👤  │ │ 👤  │                                    │
│  │x=100│ │x=300│ │x=500│                                    │
│  └─────┘ └─────┘ └─────┘                                    │
│     ↓        ↓        ↓                                      │
│  x좌표 순 정렬 → 인물 1, 인물 2, 인물 3                       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  다른 사진들도 동일하게 x좌표 순 정렬                         │
│                                                              │
│  사진 A: [인물1] [인물2] [인물3]                             │
│  사진 B: [인물1] [인물2] [인물3]                             │
│  사진 C: [인물1] [인물2] [인물3]                             │
│                                                              │
│  → 같은 순서 위치 = 같은 인물로 가정                         │
└─────────────────────────────────────────────────────────────┘
```

#### 구현 코드

> **주의**: 이 함수는 prd8.md §2.4.4의 전체 규칙 중 **위치 기반 정렬** 부분만 담당합니다.
> 전체 흐름(5% 크기 필터 → 크기순 상위 5개 → 위치순 재정렬)은 prd8.md §2.4.4 참조.

```swift
struct DetectedFace {
    let observation: VNFaceObservation
    let boundingBox: CGRect
    var personIndex: Int = 0
}

/// 위치 기반 인물 번호 부여 (prd8.md §2.4.4의 Step 3~4)
/// - 사전 조건: 이미 5% 필터 및 크기순 상위 5개 선택이 완료된 faces
func assignPersonIndicesByPosition(faces: [DetectedFace]) -> [DetectedFace] {
    // Step 3: 위치순 재정렬 (좌→우, 위→아래)
    let sorted = faces.sorted { face1, face2 in
        if abs(face1.boundingBox.origin.x - face2.boundingBox.origin.x) > 0.05 {
            return face1.boundingBox.origin.x < face2.boundingBox.origin.x
        }
        return face1.boundingBox.origin.y > face2.boundingBox.origin.y
    }

    // Step 4: 인물 번호 부여
    return sorted.enumerated().map { index, face in
        var newFace = face
        newFace.personIndex = index + 1
        return newFace
    }
}
```

#### 한계
- 사람들이 위치를 바꾸면 틀림
- 일부 사진에서 얼굴이 가려지면 순서가 밀림

### 4.4 Feature Print 기반 검증 (2차)

#### 원리
얼굴 크롭 이미지의 Feature Print를 비교하여 같은 인물인지 확인

#### 거리 임계값 (얼굴 크롭 비교)

| 거리 | 의미 | 신뢰도 |
|------|------|--------|
| 0~0.6 | 같은 인물 확실 | 높음 (High) |
| 0.6~1.0 | 같은 인물 가능성 높음 | 중간 (Medium) |
| 1.0+ | 다른 인물 가능성 | 낮음 (Low) |

**참고**: 이미지 전체 비교(10.0)와 얼굴 크롭 비교(1.0)의 임계값이 다름

#### 알고리즘

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: 기준 사진에서 얼굴 크롭 및 Feature Print 생성        │
│                                                              │
│  기준 사진 A:                                                │
│  ┌─────┐ ┌─────┐ ┌─────┐                                    │
│  │ 👤  │ │ 👤  │ │ 👤  │                                    │
│  │FP-1 │ │FP-2 │ │FP-3 │  ← 각 얼굴 크롭 후 Feature Print    │
│  └─────┘ └─────┘ └─────┘                                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Step 2: 다른 사진에서 각 인물과 가장 유사한 얼굴 찾기        │
│                                                              │
│  사진 B의 얼굴들: [FP-a] [FP-b] [FP-c]                       │
│                                                              │
│  인물 1 (FP-1) 매칭:                                         │
│  - FP-1 ↔ FP-a: 0.3 ✓ (최소)                                │
│  - FP-1 ↔ FP-b: 0.8                                         │
│  - FP-1 ↔ FP-c: 1.2                                         │
│  → 인물 1 = FP-a                                            │
│                                                              │
│  인물 2 (FP-2) 매칭:                                         │
│  - FP-2 ↔ FP-b: 0.2 ✓ (최소, FP-a 제외)                     │
│  - FP-2 ↔ FP-c: 1.1                                         │
│  → 인물 2 = FP-b                                            │
│                                                              │
│  인물 3 (FP-3) 매칭:                                         │
│  - FP-3 ↔ FP-c: 0.4 ✓ (남은 것)                             │
│  → 인물 3 = FP-c                                            │
└─────────────────────────────────────────────────────────────┘
```

#### 구현 코드

```swift
struct FaceMatch {
    let personIndex: Int
    let faceObservation: VNFaceObservation
    let featurePrint: VNFeaturePrintObservation
    let distance: Float
    let confidence: MatchConfidence
}

enum MatchConfidence {
    case high    // 거리 < 0.6
    case medium  // 0.6 <= 거리 < 1.0
    case low     // 거리 >= 1.0
}

func matchFacesWithFeaturePrint(
    referenceFaces: [CroppedFace],  // 기준 사진의 얼굴들 (이미 인물 번호 부여됨)
    targetFaces: [CroppedFace]       // 비교 사진의 얼굴들
) throws -> [FaceMatch] {

    var matches: [FaceMatch] = []
    var usedTargetIndices: Set<Int> = []

    // 각 기준 얼굴에 대해
    for refFace in referenceFaces {
        var bestMatch: (index: Int, distance: Float)? = nil

        // 모든 타겟 얼굴과 거리 계산
        for (targetIndex, targetFace) in targetFaces.enumerated() {
            // 이미 매칭된 얼굴은 스킵
            if usedTargetIndices.contains(targetIndex) { continue }

            var distance: Float = 0
            try refFace.featurePrint.computeDistance(&distance, to: targetFace.featurePrint)

            if bestMatch == nil || distance < bestMatch!.distance {
                bestMatch = (targetIndex, distance)
            }
        }

        // 가장 가까운 얼굴을 해당 인물로 매칭
        if let match = bestMatch {
            usedTargetIndices.insert(match.index)

            let confidence: MatchConfidence
            switch match.distance {
            case ..<0.6: confidence = .high
            case 0.6..<1.0: confidence = .medium
            default: confidence = .low
            }

            matches.append(FaceMatch(
                personIndex: refFace.personIndex,
                faceObservation: targetFaces[match.index].observation,
                featurePrint: targetFaces[match.index].featurePrint,
                distance: match.distance,
                confidence: confidence
            ))
        }
    }

    return matches
}
```

### 4.5 하이브리드 방식 (권장)

#### 전략
```
1차: 위치 기반 매칭 (빠른 초기 매칭)
2차: Feature Print 검증 (정확도 확인)
3차: 신뢰도 낮으면 사용자 경고
```

#### 전체 흐름

```
┌─────────────────────────────────────────────────────────────┐
│  유사사진정리버튼 탭                                          │
│         ↓                                                    │
│  유사사진정리그룹 생성 (최대 8장, 인덱스 거리순)                │
│         ↓                                                    │
│  + 버튼 탭 (인물 N 선택)                                      │
│         ↓                                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Phase 1: 위치 기반 매칭                              │    │
│  │   - 기준 사진: 현재 보고 있는 사진                   │    │
│  │   - 모든 사진에서 얼굴 감지                          │    │
│  │   - x좌표 순 정렬 → 인물 번호 부여                  │    │
│  │   - 결과: 각 사진의 "인물 N" 얼굴 위치 결정          │    │
│  └─────────────────────────────────────────────────────┘    │
│         ↓                                                    │
│  얼굴 비교 화면 표시 (즉시)                                   │
│         ↓                                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Phase 2: Feature Print 검증 (백그라운드)             │    │
│  │   - 선택된 인물의 모든 얼굴 크롭                     │    │
│  │   - 기준 얼굴 vs 각 사진 얼굴 Feature Print 거리     │    │
│  │   - 거리 > 1.0인 쌍이 있으면 경고 플래그 설정        │    │
│  └─────────────────────────────────────────────────────┘    │
│         ↓                                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Phase 3: 경고 표시 (필요시)                          │    │
│  │   ⚠️ "일부 사진에서 다른 인물이 포함되었을 수 있음"  │    │
│  │   - 해당 사진에 경고 배지 표시                       │    │
│  │   - 사용자가 확인 후 진행 가능                       │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. 자동 검증 방법

### 5.1 검증 목표

위치 기반 매칭이 올바른지 자동으로 확인

### 5.2 검증 알고리즘

```swift
struct ValidationResult {
    let isValid: Bool
    let overallConfidence: MatchConfidence
    let mismatchedPhotos: [PHAsset]  // 신뢰도 낮은 사진들
    let details: [PhotoValidation]
}

struct PhotoValidation {
    let asset: PHAsset
    let personIndex: Int
    let distance: Float
    let confidence: MatchConfidence
}

func validatePersonMatching(
    referencePhoto: PHAsset,
    referenceFaces: [CroppedFace],
    groupPhotos: [PHAsset],
    personIndex: Int
) async throws -> ValidationResult {

    guard personIndex <= referenceFaces.count else {
        throw ValidationError.invalidPersonIndex
    }

    let referenceFace = referenceFaces[personIndex - 1]
    var details: [PhotoValidation] = []
    var mismatchedPhotos: [PHAsset] = []

    for photo in groupPhotos where photo != referencePhoto {
        // 해당 사진에서 얼굴 감지 및 위치 기반 매칭
        let faces = try await detectAndCropFaces(in: photo)
        let sortedFaces = assignPersonIndicesByPosition(faces)

        // 해당 인물 번호의 얼굴 찾기
        guard let targetFace = sortedFaces.first(where: { $0.personIndex == personIndex }) else {
            // 인물 미검출 → 비교에서 제외
            continue
        }

        // Feature Print 거리 계산
        var distance: Float = 0
        try referenceFace.featurePrint.computeDistance(&distance, to: targetFace.featurePrint)

        let confidence: MatchConfidence
        switch distance {
        case ..<0.6: confidence = .high
        case 0.6..<1.0: confidence = .medium
        default: confidence = .low
        }

        details.append(PhotoValidation(
            asset: photo,
            personIndex: personIndex,
            distance: distance,
            confidence: confidence
        ))

        if confidence == .low {
            mismatchedPhotos.append(photo)
        }
    }

    // 전체 신뢰도 계산
    let overallConfidence: MatchConfidence
    if mismatchedPhotos.isEmpty {
        let avgDistance = details.map(\.distance).reduce(0, +) / Float(details.count)
        overallConfidence = avgDistance < 0.6 ? .high : .medium
    } else {
        overallConfidence = .low
    }

    return ValidationResult(
        isValid: mismatchedPhotos.isEmpty,
        overallConfidence: overallConfidence,
        mismatchedPhotos: mismatchedPhotos,
        details: details
    )
}
```

### 5.3 검증 시점

| 시점 | 방식 | 설명 |
|------|------|------|
| + 버튼 탭 시 | 동기 | 위치 기반 매칭 즉시 수행 |
| 얼굴 비교 화면 진입 후 | 비동기 | Feature Print 검증 백그라운드 수행 |
| 검증 완료 시 | UI 업데이트 | 경고 필요시 배지/알림 표시 |

### 5.4 경고 UI

#### 전체 경고 (헤더)
```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️ 인물 매칭 확인 필요                                      │
│                                                              │
│  일부 사진에서 다른 사람이 포함되었을 수 있습니다.            │
│  아래 표시된 사진을 확인해주세요.                             │
│                                                              │
│  [확인]                                                      │
└─────────────────────────────────────────────────────────────┘
```

#### 개별 사진 경고 (셀)
```
┌──────────────┐
│   얼굴 크롭   │
│              │
│         ⚠️  │ ← 우측 하단 경고 배지
└──────────────┘
```

### 5.5 검증 결과 활용

| 신뢰도 | 처리 |
|--------|------|
| 높음 (High) | 정상 표시, 경고 없음 |
| 중간 (Medium) | 정상 표시, 경고 없음 (임계값 근접 알림 옵션) |
| 낮음 (Low) | 경고 배지 표시, 사용자 확인 요청 |

---

## 6. 얼굴 크롭 규칙

### 6.1 크롭 영역 계산

```swift
func cropFaceRegion(from image: CGImage, boundingBox: CGRect) -> CGImage? {
    let imageWidth = CGFloat(image.width)
    let imageHeight = CGFloat(image.height)

    // Vision 좌표 → 이미지 좌표 변환
    let faceRect = CGRect(
        x: boundingBox.origin.x * imageWidth,
        y: (1 - boundingBox.maxY) * imageHeight,  // Y축 반전
        width: boundingBox.width * imageWidth,
        height: boundingBox.height * imageHeight
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
    expandedRect = expandedRect.intersection(
        CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
    )

    return image.cropping(to: expandedRect)
}
```

### 6.2 크롭 규칙 요약

| 항목 | 값 |
|------|-----|
| 여백 | bounding box 크기의 30% |
| 비율 | 정사각형 (1:1) |
| 회전 | 수평 유지 (MVP) |
| 경계 처리 | 이미지 범위 내로 클램핑 |

---

## 7. 성능 고려사항

### 7.1 처리 시간 목표

| 작업 | 목표 | 비고 |
|------|------|------|
| 이미지 Feature Print 생성 | 50ms 이하 | 480x480 해상도 |
| 얼굴 감지 | 30ms 이하 | VNDetectFaceRectanglesRequest |
| 얼굴 크롭 Feature Print | 30ms 이하 | 크롭된 이미지 |
| 거리 계산 | 1ms 이하 | computeDistance |

### 7.2 동시 처리 제한

| 컨텍스트 | 동시 분석 수 | 이유 |
|----------|-------------|------|
| 그리드 | 5개 | 메모리 관리, 스크롤 성능 |
| 뷰어 | 3개 | 빠른 응답 필요 |
| 얼굴 비교 검증 | 백그라운드 | UX 블로킹 방지 |

### 7.3 캐싱 전략 (Phase 7)

MVP에서는 캐싱 없이 실시간 분석. 성능 이슈 발생 시:
- 이미지 Feature Print 캐싱
- 얼굴 감지 결과 캐싱
- 얼굴 크롭 Feature Print 캐싱

---

## 8. 테스트 케이스

### 8.1 유사 사진 분류 테스트

| ID | 시나리오 | 예상 결과 |
|----|----------|----------|
| ALG-001 | 연속 촬영 5장 (거리 < 10) | 1개 그룹 (5장) |
| ALG-002 | 연속 촬영 5장 중 1장 풍경 | 1개 그룹 (4장) |
| ALG-003 | 유사 3장 + 다른 3장 (거리 > 10) | 그룹 없음 (3장 미만) |
| ALG-004 | 현재 사진 기준, 앞뒤 7장 중 유사 4장 + 다른 4장 | 1개 그룹 (현재 사진 포함 유사 4장) |

> **ALG-004 참고**: 현재 사진 기준 분석이므로, 현재 사진과 거리 10.0 이하인 사진들만 그룹에 포함됨.

### 8.2 동일 인물 매칭 테스트

| ID | 시나리오 | 예상 결과 |
|----|----------|----------|
| ALG-005 | 3명, 위치 동일 | 매칭 성공, 높은 신뢰도 |
| ALG-006 | 3명, 2명 위치 교환 | 위치 기반 실패, Feature Print 검증 경고 |
| ALG-007 | 5명 중 1명 일부 사진에서 가려짐 | 해당 인물 비교에서 제외 |
| ALG-008 | 동일 인물 다른 표정 | 거리 0.3~0.6, 매칭 성공 |

### 8.3 검증 테스트

| ID | 시나리오 | 예상 결과 |
|----|----------|----------|
| ALG-009 | 모든 매칭 거리 < 0.6 | 신뢰도 높음, 경고 없음 |
| ALG-010 | 일부 매칭 거리 0.6~1.0 | 신뢰도 중간, 경고 없음 |
| ALG-011 | 1개 매칭 거리 > 1.0 | 신뢰도 낮음, 해당 사진 경고 |
| ALG-012 | 다수 매칭 거리 > 1.0 | 신뢰도 낮음, 전체 경고 |

---

## 9. 향후 개선 방향

### Phase 7+ 개선 사항

1. **Feature Print 기반 1차 매칭**
   - 위치 기반 대신 Feature Print 기반 매칭을 1차로 사용
   - 정확도 향상, 처리 시간 증가

2. **얼굴 랜드마크 활용**
   - 76개 특징점으로 더 정밀한 얼굴 비교
   - 표정 분석 가능

3. **클러스터링 알고리즘**
   - Apple Photos 방식의 2단계 클러스터링 적용
   - Greedy → HAC 순차 적용

4. **상체 임베딩 추가**
   - 얼굴이 가려진 경우 옷으로 매칭
   - 같은 시간대 사진에서만 유효

---

## 10. 참고 자료

- [Apple Developer - VNGenerateImageFeaturePrintRequest](https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequest)
- [Apple ML Research - Recognizing People in Photos](https://machinelearning.apple.com/research/recognizing-people-photos)
- [Fritz.ai - Image Similarity using Vision](https://fritz.ai/compute-image-similarity-using-computer-vision-in-ios/)
- [Apple WWDC 2019 - Image Similarity](https://developer.apple.com/la/videos/play/wwdc2019/222/)
- [Apple WWDC 2021 - Vision Updates](https://developer.apple.com/videos/play/wwdc2021/10040/)
