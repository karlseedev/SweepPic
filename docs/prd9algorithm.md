# PRD 9 알고리즘 상세: 유사 사진 분류 및 동일 인물 매칭

**버전**: 1.3
**작성일**: 2026-01-02
**관련 문서**: [PRD 9](./prd9.md), [Spec](../specs/002-similar-photo/spec.md)

> **문서 역할 (How)**: 이 문서는 **어떻게** 구현할지를 정의합니다.
> - 알고리즘 흐름, 구현 코드, 자료구조, 성능 고려사항
> - 비즈니스 규칙(What/Why)은 [prd9.md](./prd9.md) 참조
>
> **비즈니스 규칙 참조:**
> - 그룹 유형 정의: prd9.md §2.1.6
> - 인물 번호 부여 순서: prd9.md §2.4.4
> - 얼굴 크기 필터 (5%): prd9.md §2.4.2
> - 검증 임계값/경고 UI: prd9.md §2.7

> **prd8algorithm 대비 주요 변경점:**
> - CachedFace 구조 도입 (boundingBox + personIndex + isValidSlot)
> - 뷰어 얼굴 분석 제거 → 캐시 참조
> - 좌표 변환 함수 추가 (Vision → UIKit)

---

## 1. 개요

이 문서는 유사 사진 정리 기능의 핵심 알고리즘을 상세히 정의합니다:
1. **유사 사진 분류**: 연속 촬영된 비슷한 사진들을 유사사진썸네일그룹으로 묶기
2. **동일 인물 매칭**: 유사사진정리그룹 내에서 "인물 1"이 항상 같은 사람이 되도록 매칭
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

> **그룹 유형**: prd9.md §2.1.6에 두 가지 그룹이 정의됨
> - **유사사진썸네일그룹**: 그리드 테두리/뷰어 +버튼 표시용 (여러 유사사진썸네일그룹 가능)
> - **유사사진정리그룹**: 얼굴 비교 화면용 (최대 8장)
>
> 이 섹션의 알고리즘은 **유사사진썸네일그룹** 생성에 사용됨.
> 유사사진정리그룹 선택 알고리즘은 prd9.md §2.1.6 참조.

### 3.1 목표

분석 범위 내 사진들을 **유사사진썸네일그룹**들로 분류 (여러 유사사진썸네일그룹 가능)

### 3.2 입력/출력

```
입력: 분석 범위의 사진 리스트 (시간순 정렬)
  - 그리드: 화면에 보이는 사진 + 앞뒤 7장 확장
  - (뷰어에서는 그리드 분석 결과 재사용, 재분석 없음)
출력: 유사사진썸네일그룹들 + CachedFace 캐시
  - 각 그룹 조건: 5% 이상 유효 얼굴 사진 3장 이상 + 유효 인물 슬롯 1개 이상
  - 여러 유사사진썸네일그룹 가능
  - 각 사진별 CachedFace 배열 캐싱
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
│  Step 3: 인접 사진 간 Feature Print 거리 10.0 기준 유사사진썸네일그룹 분리  │
│                                                              │
│  결과: [유사사진썸네일그룹 A: 1,2,3,4]  [유사사진썸네일그룹 B: 5,6,7] │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Step 4: 5% 이상 유효 얼굴 필터링 + 인물 슬롯 검증 + 캐싱     │
│                                                              │
│  유사사진썸네일그룹 A (4장) → 5% 이상 유효 얼굴 4장, 인물1 슬롯 3장 → 유효 │
│  유사사진썸네일그룹 B (3장) → 5% 이상 유효 얼굴 3장, 유효 슬롯 없음 → 무효 │
│                                                              │
│  각 사진별 CachedFace 배열 저장                               │
│                                                              │
│  최종 결과: [유사사진썸네일그룹 A: 1,2,3,4]                    │
└─────────────────────────────────────────────────────────────┘
```

### 3.4 인접 사진 간 Feature Print 거리 임계값

| 거리 | 의미 | 처리 |
|------|------|------|
| 0 | 완전 동일 | 같은 유사사진썸네일그룹 |
| 0~5 | 거의 동일 (연속 촬영) | 같은 유사사진썸네일그룹 |
| 5~10 | 유사함 | 같은 유사사진썸네일그룹 |
| 10~15 | 어느 정도 비슷 | **유사사진썸네일그룹 분리** |
| 15+ | 다른 사진 | 다른 유사사진썸네일그룹 |

**임계값: 10.0** (PRD 기준, 추후 조정 가능)

### 3.5 분석 상태 모델 및 캐시 구조

그리드와 뷰어 간 분석 결과 공유를 위한 상태 모델:

```swift
/// 캐시에 저장되는 얼굴 정보
struct CachedFace {
    let boundingBox: CGRect   // Vision 정규화 좌표 (0~1, 원점 좌하단)
    let personIndex: Int      // 위치 기반 인물 번호 (1, 2, 3...)
    let isValidSlot: Bool     // 유효 인물 슬롯 여부 (그룹 내 2장 이상)
}

/// 사진별 분석 상태
enum SimilarityAnalysisState {
    case notAnalyzed                              // 분석 범위 밖이었음
    case analyzing                                // 분석 진행 중
    case analyzed(inGroup: Bool, groupID: String?) // 분석 완료
}

/// 분석 결과 캐시
class SimilarityCache {
    // asset ID → 분석 상태
    private var states: [String: SimilarityAnalysisState] = [:]

    // group ID → 멤버 asset ID 목록 (그룹 전체 멤버 저장)
    private var groups: [String: [String]] = [:]

    // asset ID → CachedFace 배열 (뷰어에서 +버튼 표시에 사용)
    private var assetFaces: [String: [CachedFace]] = [:]

    // groupID → 유효 인물 슬롯 (2장 이상)
    private var groupValidPersonIndices: [String: Set<Int>] = [:]

    // 분석 완료 콜백 (뷰어에서 구독)
    private var completionHandlers: [String: [(SimilarityAnalysisState) -> Void]] = [:]

    // MARK: - State Management

    func getState(for assetID: String) -> SimilarityAnalysisState {
        return states[assetID] ?? .notAnalyzed
    }

    func setState(_ state: SimilarityAnalysisState, for assetID: String) {
        states[assetID] = state

        // 분석 완료 시 구독자에게 알림
        if case .analyzed = state {
            completionHandlers[assetID]?.forEach { $0(state) }
            completionHandlers[assetID] = nil
        }
    }

    // MARK: - Group Management

    func getGroupMembers(groupID: String) -> [String] {
        return groups[groupID] ?? []
    }

    func setGroupMembers(_ members: [String], for groupID: String) {
        groups[groupID] = members
    }

    func removeFromGroup(assetID: String, groupID: String) {
        groups[groupID]?.removeAll { $0 == assetID }
    }

    func invalidateGroup(groupID: String) {
        // 그룹 멤버들의 상태를 false로 변경
        for assetID in groups[groupID] ?? [] {
            states[assetID] = .analyzed(inGroup: false, groupID: nil)
            assetFaces.removeValue(forKey: assetID)
        }
        groups.removeValue(forKey: groupID)
        groupValidPersonIndices.removeValue(forKey: groupID)
    }

    // MARK: - Face Cache (신규)

    func setFaces(_ faces: [CachedFace], for assetID: String) {
        assetFaces[assetID] = faces
    }

    func getFaces(for assetID: String) -> [CachedFace] {
        return assetFaces[assetID] ?? []
    }

    /// 유효 슬롯(isValidSlot=true)인 얼굴만 반환 (뷰어 +버튼 표시용)
    func getValidSlotFaces(for assetID: String) -> [CachedFace] {
        return assetFaces[assetID]?.filter { $0.isValidSlot } ?? []
    }

    // MARK: - Valid Person Indices

    func setGroupValidPersonIndices(_ indices: Set<Int>, for groupID: String) {
        groupValidPersonIndices[groupID] = indices
    }

    func getGroupValidPersonIndices(for groupID: String) -> Set<Int> {
        return groupValidPersonIndices[groupID] ?? []
    }

    // MARK: - Observation

    func observeCompletion(for assetID: String, handler: @escaping (SimilarityAnalysisState) -> Void) {
        // 이미 분석 완료된 경우 즉시 콜백
        if case .analyzed = states[assetID] {
            handler(states[assetID]!)
            return
        }

        // 진행 중이면 콜백 등록
        if completionHandlers[assetID] == nil {
            completionHandlers[assetID] = []
        }
        completionHandlers[assetID]?.append(handler)
    }

    // MARK: - Eviction (LRU)

    private var accessOrder: [String] = []  // LRU 추적용
    private let maxCacheSize = 500

    func touchAsset(_ assetID: String) {
        accessOrder.removeAll { $0 == assetID }
        accessOrder.append(assetID)
    }

    func evictIfNeeded() {
        while accessOrder.count > maxCacheSize {
            guard let oldestAssetID = accessOrder.first else { break }
            evictAsset(oldestAssetID)
        }
    }

    private func evictAsset(_ assetID: String) {
        accessOrder.removeAll { $0 == assetID }

        // 영향받는 그룹 확인
        if case .analyzed(_, let groupID) = states[assetID], let gid = groupID {
            removeFromGroup(assetID: assetID, groupID: gid)

            let remainingMembers = getGroupMembers(groupID: gid)
            if remainingMembers.count < 3 {
                invalidateGroup(groupID: gid)
            } else {
                recalculateValidPersonIndices(for: gid)
            }
        }

        // 캐시 정리 + 상태를 notAnalyzed로 전환
        assetFaces.removeValue(forKey: assetID)
        states[assetID] = .notAnalyzed
    }

    func recalculateValidPersonIndices(for groupID: String) {
        let members = getGroupMembers(groupID: groupID)
        var slotCounts: [Int: Int] = [:]

        for assetID in members {
            for face in getFaces(for: assetID) {
                slotCounts[face.personIndex, default: 0] += 1
            }
        }

        let validSlots = Set(slotCounts.filter { $0.value >= 2 }.map { $0.key })
        setGroupValidPersonIndices(validSlots, for: groupID)

        // CachedFace의 isValidSlot 플래그 갱신
        for assetID in members {
            let updatedFaces = getFaces(for: assetID).map { face in
                CachedFace(
                    boundingBox: face.boundingBox,
                    personIndex: face.personIndex,
                    isValidSlot: validSlots.contains(face.personIndex)
                )
            }
            setFaces(updatedFaces, for: assetID)
        }
    }

    // MARK: - 재분석 시 기존 그룹 정리

    func prepareForReanalysis(assetIDs: Set<String>) {
        var affectedGroups: Set<String> = []

        for assetID in assetIDs {
            if case .analyzed(_, let groupID) = getState(for: assetID),
               let gid = groupID {
                affectedGroups.insert(gid)
                removeFromGroup(assetID: assetID, groupID: gid)
            }
            states[assetID] = .analyzing
            assetFaces.removeValue(forKey: assetID)
        }

        // 영향받은 그룹 검증
        for groupID in affectedGroups {
            let members = getGroupMembers(groupID: groupID)
            if members.count < 3 {
                invalidateGroup(groupID: groupID)
            } else {
                recalculateValidPersonIndices(for: groupID)
            }
        }
    }
}
```

**상태 전이:**
```
notAnalyzed ──→ analyzing ──→ analyzed(inGroup: Bool)
(범위 밖)       (분석 중)       (완료)

- 그리드 스크롤 멈춤 → 범위 내 사진들 analyzing으로 전환
- 분석 완료 → analyzed로 전환 (CachedFace 저장, 유효 인물 슬롯 계산)
- 뷰어에서 notAnalyzed 사진 접근 → 그리드에 분석 요청 → analyzing
- 뷰어에서 analyzed 사진 접근 → 캐시에서 CachedFace 조회 → 즉시 +버튼 표시
```

**뷰어 분석 요청 시 범위 처리:**
```
1. 범위 내 notAnalyzed 사진만 대상
   - 기존 analyzed 사진은 유지 (재분석 없음)
   - notAnalyzed만 analyzing으로 전환

2. 분석 완료 후 그룹 재계산
   - 기존 그룹에 새 멤버 편입 가능
   - 유효 인물 슬롯 재계산
   - CachedFace.isValidSlot 갱신

3. evictIfNeeded() 호출 (500장 초과 시 LRU eviction)
```

**재분석 시 캐시 갱신 규칙 (그리드 스크롤 재분석):**
```
1. prepareForReanalysis(assetIDs:) 호출
   - 범위 내 사진의 기존 그룹에서 제거
   - 영향받은 그룹 3장 미만 → invalidateGroup()
   - 3장 이상 → recalculateValidPersonIndices()
   - 기존 CachedFace 삭제
   - 상태 → analyzing

2. 분석 수행 후 새 그룹 생성
   - groups에 멤버 목록 저장
   - CachedFace 저장
   - 상태 → analyzed

3. evictIfNeeded() 호출 (500장 초과 시 LRU eviction)
```

### 3.6 좌표 변환 및 윈도우 크기 함수

**예상 뷰어 크기 취득 (5% 기준 계산용):**

```swift
/// 현재 윈도우 크기 취득 (iPad 분할 모드 반영)
/// - 그리드 분석 시점에 호출하여 5% 기준 계산에 사용
/// - 회전/분할 모드 변경 시 재분석 없음 (MVP, 약간의 오차 허용)
func getExpectedViewerSize() -> CGSize {
    // 1순위: 현재 윈도우 크기 (분할 모드 반영)
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first {
        return window.bounds.size
    }
    // fallback: 스크린 크기
    return UIScreen.main.bounds.size
}
```

**Vision 좌표 → 뷰어 좌표 변환:**

```swift
/// Vision 정규화 좌표 (0~1, 원점 좌하단) → UIKit 좌표 (원점 좌상단)
/// - boundingBox: Vision에서 반환한 정규화 좌표
/// - imageSize: 원본 이미지 크기
/// - viewerFrame: 뷰어에서 이미지가 표시되는 영역 (Aspect Fit 적용 후)
func convertToViewerCoordinates(
    boundingBox: CGRect,
    imageSize: CGSize,
    viewerFrame: CGRect
) -> CGRect {
    // Aspect Fit 스케일 계산
    let scale = min(viewerFrame.width / imageSize.width,
                    viewerFrame.height / imageSize.height)

    // 중앙 정렬 오프셋
    let offsetX = (viewerFrame.width - imageSize.width * scale) / 2
    let offsetY = (viewerFrame.height - imageSize.height * scale) / 2

    // Vision 좌표 → UIKit 좌표 변환
    // Vision: origin.y가 아래에서 시작
    // UIKit: origin.y가 위에서 시작
    return CGRect(
        x: boundingBox.origin.x * imageSize.width * scale + offsetX,
        y: (1 - boundingBox.maxY) * imageSize.height * scale + offsetY,  // Y축 반전
        width: boundingBox.width * imageSize.width * scale,
        height: boundingBox.height * imageSize.height * scale
    )
}

/// + 버튼 중심 위치 계산 (얼굴 위 중앙)
func calculateButtonCenter(
    for cachedFace: CachedFace,
    imageSize: CGSize,
    viewerFrame: CGRect,
    buttonSize: CGFloat
) -> CGPoint {
    let faceRect = convertToViewerCoordinates(
        boundingBox: cachedFace.boundingBox,
        imageSize: imageSize,
        viewerFrame: viewerFrame
    )

    // 얼굴 위 중앙에 버튼 배치
    return CGPoint(
        x: faceRect.midX,
        y: faceRect.minY - buttonSize / 2 - 8  // 얼굴 위 8pt 여백
    )
}
```

### 3.7 구현 코드

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

// Step 3: 유사사진썸네일그룹 생성
func groupSimilarPhotos(
    assets: [PHAsset],
    distances: [Float],
    threshold: Float = 10.0
) -> [[PHAsset]] {
    var groups: [[PHAsset]] = []
    var currentGroup: [PHAsset] = [assets[0]]

    for i in 0..<distances.count {
        if distances[i] <= threshold {
            // 유사함 → 같은 유사사진썸네일그룹에 추가
            currentGroup.append(assets[i + 1])
        } else {
            // 다름 → 새 유사사진썸네일그룹 시작
            if currentGroup.count >= 3 {
                groups.append(currentGroup)
            }
            currentGroup = [assets[i + 1]]
        }
    }

    // 마지막 유사사진썸네일그룹 처리
    if currentGroup.count >= 3 {
        groups.append(currentGroup)
    }

    return groups
}

// Step 4: 5% 이상 유효 얼굴 필터링 + 인물 슬롯 검증 + CachedFace 캐싱
// viewerSize = getExpectedViewerSize() (iPad 분할 모드 반영)
func isEligibleFace(boundingBox: CGRect, imageSize: CGSize, viewerSize: CGSize) -> Bool {
    let scale = min(viewerSize.width / imageSize.width, viewerSize.height / imageSize.height)
    let faceWidthOnScreen = boundingBox.width * imageSize.width * scale
    return faceWidthOnScreen >= viewerSize.width * 0.05
}

/// 얼굴 감지 → 5% 이상 유효 얼굴 필터 → 크기순 상위 5개 → 위치순 인물 번호 부여
func detectEligibleFaces(in asset: PHAsset, viewerSize: CGSize) async throws -> [DetectedFace] {
    let faces = try await detectFaces(in: asset) // VNDetectFaceRectanglesRequest
    let imageSize = await loadImageSize(asset)

    // 5% 이상 유효 얼굴만 필터링
    let eligibleFaces = faces.filter {
        isEligibleFace(boundingBox: $0.boundingBox, imageSize: imageSize, viewerSize: viewerSize)
    }

    let topFiveBySize = eligibleFaces.sorted {
        max($0.boundingBox.width, $0.boundingBox.height) >
        max($1.boundingBox.width, $1.boundingBox.height)
    }.prefix(5)

    return assignPersonIndicesByPosition(faces: Array(topFiveBySize))
}

/// 5% 이상 유효 얼굴 3장 이상 + 유효 인물 슬롯 1개 이상인 그룹만 유지
/// cache: 분석 결과 저장용 캐시 (CachedFace 배열, 유효 슬롯)
func filterGroupsWithEligibleFaces(
    groups: [[PHAsset]],
    viewerSize: CGSize,
    cache: SimilarityCache
) async throws -> [[PHAsset]] {
    var filteredGroups: [[PHAsset]] = []

    for group in groups {
        let groupID = UUID().uuidString
        var assetsWithFaces: [(asset: PHAsset, faces: [DetectedFace])] = []

        // 그룹 내 모든 사진 ID 추적 (탈락 사진 상태 업데이트용)
        let allAssetIDs = Set(group.map { $0.localIdentifier })

        for asset in group {
            let faces = try await detectEligibleFaces(in: asset, viewerSize: viewerSize)
            if !faces.isEmpty {
                assetsWithFaces.append((asset: asset, faces: faces))
            }
        }

        // 인물 슬롯별 사진 수 집계
        var slotCounts: [Int: Int] = [:]
        for entry in assetsWithFaces {
            for face in entry.faces {
                slotCounts[face.personIndex, default: 0] += 1
            }
        }

        // 유효 슬롯: 2장 이상
        let validSlots = Set(slotCounts.filter { $0.value >= 2 }.map { $0.key })

        // 유효 슬롯에 해당하는 얼굴이 있는 사진만 유효
        let validAssets = assetsWithFaces.filter { entry in
            entry.faces.contains { validSlots.contains($0.personIndex) }
        }
        let validAssetIDs = Set(validAssets.map { $0.asset.localIdentifier })

        if validAssets.count >= 3 && !validSlots.isEmpty {
            filteredGroups.append(validAssets.map(\.asset))

            // 캐시에 그룹별 유효 인물 슬롯 저장
            cache.setGroupValidPersonIndices(validSlots, for: groupID)

            // 캐시에 그룹 멤버 저장 + CachedFace 저장
            let memberIDs = validAssets.map { $0.asset.localIdentifier }
            cache.setGroupMembers(memberIDs, for: groupID)

            for entry in validAssets {
                // CachedFace 배열 생성 (isValidSlot 플래그 설정)
                let cachedFaces = entry.faces.map { face in
                    CachedFace(
                        boundingBox: face.boundingBox,
                        personIndex: face.personIndex,
                        isValidSlot: validSlots.contains(face.personIndex)
                    )
                }
                cache.setFaces(cachedFaces, for: entry.asset.localIdentifier)
                cache.setState(.analyzed(inGroup: true, groupID: groupID), for: entry.asset.localIdentifier)
            }
        }

        // 탈락한 사진 상태 업데이트 (얼굴 없음, 유효 슬롯 미충족 등)
        let excludedAssetIDs = allAssetIDs.subtracting(validAssetIDs)
        for assetID in excludedAssetIDs {
            cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
        }
    }

    return filteredGroups
}
```

### 3.8 유사사진정리그룹 선택 알고리즘

유사사진썸네일그룹에서 최대 8장을 선택하여 유사사진정리그룹 생성:

```swift
/// 유사사진정리그룹 선택 (최대 8장, 현재 사진 중심)
/// - thumbnailGroup: 유사사진썸네일그룹 (시간순 정렬)
/// - currentIndex: 현재 사진의 그룹 내 인덱스
/// - maxCount: 최대 선택 개수 (기본 8)
/// - Returns: 선택된 사진들 (원래 순서 유지)
func selectComparisonGroup(
    from thumbnailGroup: [PHAsset],
    currentIndex: Int,
    maxCount: Int = 8
) -> [PHAsset] {
    guard !thumbnailGroup.isEmpty else { return [] }
    guard currentIndex >= 0 && currentIndex < thumbnailGroup.count else { return [] }

    // 8장 이하면 전체 반환
    if thumbnailGroup.count <= maxCount {
        return thumbnailGroup
    }

    // Step 1: 거리순으로 인덱스 선택 (동일 거리면 앞쪽 우선)
    var selectedIndices: [Int] = [currentIndex]
    var front = currentIndex - 1
    var back = currentIndex + 1

    while selectedIndices.count < maxCount {
        // 앞쪽 먼저 (동일 거리면 앞쪽 우선)
        if front >= 0 {
            selectedIndices.append(front)
            front -= 1
        }

        // 뒤쪽
        if selectedIndices.count < maxCount && back < thumbnailGroup.count {
            selectedIndices.append(back)
            back += 1
        }

        // 더 이상 선택할 사진이 없으면 종료
        if front < 0 && back >= thumbnailGroup.count {
            break
        }
    }

    // Step 2: 원래 순서로 정렬 (시간순 유지)
    let sortedIndices = selectedIndices.sorted()

    // Step 3: 해당 인덱스의 사진들 반환
    return sortedIndices.map { thumbnailGroup[$0] }
}
```

**사용 예시:**
```swift
// 유사사진썸네일그룹 12장, 현재 사진이 5번째(인덱스 4)
let thumbnailGroup = [photo1, photo2, ..., photo12]
let currentIndex = 4  // 5번째 사진

let comparisonGroup = selectComparisonGroup(
    from: thumbnailGroup,
    currentIndex: currentIndex
)
// 결과: [photo1, photo2, photo3, photo4, photo5, photo6, photo7, photo8]
// (인덱스 0~7, 즉 1~8번째 사진)
```

---

## 4. 동일 인물 매칭 알고리즘

### 4.1 목표

유사사진정리그룹 내에서 "인물 1"이 항상 같은 사람이 되도록 매칭

### 4.2 방식 선택

**Feature Print 기반 매칭 사용**

| 방식 | 정확도 | 속도 | 채택 |
|------|--------|------|------|
| 위치 기반 | ~90% | 즉시 | ❌ 부정확 |
| **Feature Print 기반** | ~98% | ~0.5초 | ✅ **채택** |

**선택 이유:**
- 위치 기반은 빠르지만 사람들이 위치를 바꾸면 틀림
- Feature Print는 0.5초 로딩이 있지만 정확함
- +버튼 탭 시점에서 사용자는 로딩을 수용 가능
- 틀린 결과를 보여주고 경고하는 것보다, 처음부터 정확하게 보여주는 게 나은 UX

### 4.3 인물 번호 부여 (위치 기반)

> **참고**: 인물 번호는 위치 기반으로 부여하지만, 실제 인물 매칭은 Feature Print로 수행합니다.

얼굴 위치(좌→우, 위→아래)로 인물 번호를 부여합니다.
이 번호는 +버튼 표시 순서와 "인물 N" 라벨에 사용됩니다.

**Vision Framework 좌표계:**
- 정규화 좌표: 0.0 ~ 1.0
- 원점: **좌하단** (화면 좌표계와 반대)

**정렬 규칙:**
- X 정렬: `origin.x` 오름차순 (왼쪽 → 오른쪽)
- Y 정렬 (tie-break): `origin.y` 내림차순 (위쪽 → 아래쪽)
- Tie-break 임계값: X 차이가 **0.05 이하**일 때 Y 정렬 적용

```swift
/// 위치 기반 인물 번호 부여
func assignPersonIndicesByPosition(faces: [DetectedFace]) -> [DetectedFace] {
    let sorted = faces.sorted { face1, face2 in
        if abs(face1.boundingBox.origin.x - face2.boundingBox.origin.x) > 0.05 {
            return face1.boundingBox.origin.x < face2.boundingBox.origin.x
        }
        return face1.boundingBox.origin.y > face2.boundingBox.origin.y
    }
    return sorted.enumerated().map { index, face in
        var newFace = face
        newFace.personIndex = index + 1
        return newFace
    }
}
```

### 4.4 Feature Print 기반 인물 매칭

+버튼 탭 시 기준 얼굴과 다른 사진의 얼굴을 Feature Print로 비교합니다.

#### 거리 임계값

| 거리 | 판정 | 처리 |
|------|------|------|
| < 1.0 | 동일 인물 | 비교 그리드에 포함 |
| >= 1.0 | 다른 인물 | **비교 그리드에서 제외** |

#### 알고리즘 흐름

```
┌─────────────────────────────────────────────────────────────┐
│  +버튼 탭 (인물 N 선택)                                       │
│         ↓                                                    │
│  로딩 스피너 표시                                             │
│         ↓                                                    │
│  기준 얼굴 크롭 → Feature Print 생성                          │
│         ↓                                                    │
│  유사사진정리그룹 내 각 사진:                                  │
│    - 동일 위치(personIndex=N) 얼굴 크롭                       │
│    - Feature Print 생성 및 거리 계산                         │
│    - 거리 < 1.0 → 포함                                       │
│    - 거리 >= 1.0 → 제외                                      │
│         ↓                                                    │
│  같은 인물만 비교 그리드에 표시 (~0.5초)                       │
└─────────────────────────────────────────────────────────────┘
```

#### 구현 코드

```swift
struct FaceMatchResult {
    let asset: PHAsset
    let personIndex: Int
    let distance: Float
    let isMatch: Bool  // distance < 1.0
}

/// Feature Print 기반 인물 매칭
/// - referenceFace: 기준 사진의 선택된 얼굴
/// - targetPhotos: 비교 대상 사진들
/// - personIndex: 선택된 인물 번호
/// - Returns: 같은 인물로 판정된 사진만 반환
func matchPersonWithFeaturePrint(
    referenceFace: CroppedFace,
    targetPhotos: [PHAsset],
    personIndex: Int,
    cache: SimilarityCache
) async throws -> [FaceMatchResult] {

    var results: [FaceMatchResult] = []

    for photo in targetPhotos {
        // 캐시에서 해당 인물 번호의 얼굴 조회
        let faces = cache.getFaces(for: photo.localIdentifier)
        guard let targetFace = faces.first(where: { $0.personIndex == personIndex }) else {
            // 해당 인물 없음 → 제외
            continue
        }

        // 얼굴 크롭 및 Feature Print 생성
        let targetCropped = try await cropFace(from: photo, boundingBox: targetFace.boundingBox)
        let targetFeaturePrint = try await generateFeaturePrint(for: targetCropped)

        // 거리 계산
        var distance: Float = 0
        try referenceFace.featurePrint.computeDistance(&distance, to: targetFeaturePrint)

        let isMatch = distance < 1.0

        if isMatch {
            results.append(FaceMatchResult(
                asset: photo,
                personIndex: personIndex,
                distance: distance,
                isMatch: true
            ))
        }
        // 거리 >= 1.0인 사진은 결과에 포함하지 않음 (자동 제외)
    }

    return results
}
```

---

## 5. 인물 판정 결과 처리

### 5.1 판정 기준

| 거리 | 판정 | 처리 |
|------|------|------|
| < 1.0 | 동일 인물 | 비교 그리드에 포함 |
| >= 1.0 | 다른 인물 | 비교 그리드에서 **자동 제외** |

### 5.2 제외된 사진 처리

- 다른 인물로 판정된 사진은 비교 그리드에 표시하지 않음
- 별도 경고 UI 없음 (사용자가 보면 바로 알 수 있으므로)
- 헤더의 "인물 N (M장)"에서 M은 실제 표시되는 사진 수

### 5.3 예시

```
유사사진정리그룹: 8장
인물 2 선택 후 Feature Print 비교:
- 사진 1: 거리 0.3 → 포함
- 사진 2: 거리 0.5 → 포함
- 사진 3: 거리 0.4 → 포함
- 사진 4: 거리 1.2 → 제외 (다른 인물)
- 사진 5: 거리 0.6 → 포함
- 사진 6: 거리 0.8 → 포함
- 사진 7: 미검출 → 제외
- 사진 8: 거리 0.4 → 포함

결과: "인물 2 (6장)" 표시, 6장만 비교 그리드에 표시
```

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
    let expandedRect = faceRect.insetBy(dx: -padding, dy: -padding)

    // 정사각형으로 조정
    let size = max(expandedRect.width, expandedRect.height)
    let centerX = expandedRect.midX
    let centerY = expandedRect.midY

    var squareRect = CGRect(
        x: centerX - size / 2,
        y: centerY - size / 2,
        width: size,
        height: size
    )

    // 이미지 경계 밖이면 → 정사각형 유지하며 축소 (옵션 C)
    let imageBounds = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
    if !imageBounds.contains(squareRect) {
        // 중심 고정, 경계 내 최대 정사각형 크기 계산
        let maxSize = min(
            min(centerX, imageWidth - centerX) * 2,
            min(centerY, imageHeight - centerY) * 2,
            size  // 원래 크기를 초과하지 않음
        )
        squareRect = CGRect(
            x: centerX - maxSize / 2,
            y: centerY - maxSize / 2,
            width: maxSize,
            height: maxSize
        )
    }

    return image.cropping(to: squareRect)
}
```

### 6.2 크롭 규칙 요약

**규칙 정의:** prd9.md §2.5.4 참조
- 위 코드의 `cropFaceRegion` 함수가 규칙을 구현

---

## 7. 성능 고려사항

### 7.1 처리 시간 목표

| 작업 | 목표 | 비고 |
|------|------|------|
| 이미지 Feature Print 생성 | 50ms 이하 | 480x480 해상도 |
| 얼굴 감지 | 30ms 이하 | VNDetectFaceRectanglesRequest |
| 얼굴 크롭 Feature Print | 30ms 이하 | 크롭된 이미지 |
| 거리 계산 | 1ms 이하 | computeDistance |
| 캐시 조회 | 1ms 이하 | CachedFace 반환 |

### 7.2 동시 처리 제한

| 컨텍스트 | 동시 분석 수 | 이유 |
|----------|-------------|------|
| 그리드 (유사사진썸네일그룹 분석) | 5개 | 메모리 관리, 스크롤 성능 |
| 뷰어 (+버튼 표시) | 0개 (캐시 참조) | 그리드 분석 결과 재사용 |
| 얼굴 비교 검증 | 백그라운드 | UX 블로킹 방지 |

### 7.3 캐싱 전략

**기본 캐싱 (MVP):**
- CachedFace 배열 (boundingBox, personIndex, isValidSlot)
- 분석 상태 (notAnalyzed/analyzing/analyzed)
- 그룹 멤버 목록
- 유효 인물 슬롯

**성능 이슈 발생 시 (Phase 7):**
- 이미지 Feature Print 캐싱
- 얼굴 크롭 Feature Print 캐싱
- 백그라운드 사전 분석

---

## 8. 테스트 케이스

### 8.1 유사 사진 분류 테스트

| ID | 시나리오 | 예상 결과 |
|----|----------|----------|
| ALG-001 | 연속 촬영 5장 (인접 사진 간 Feature Print 거리 모두 < 10) | 1개 유사사진썸네일그룹 (5장), CachedFace 캐싱 |
| ALG-002 | 연속 촬영 5장 중 1장 풍경 (얼굴 없음) | 1개 유사사진썸네일그룹 (4장, 얼굴 필터 후) |
| ALG-003 | 3장 연속 유사 + 3↔4 거리 > 10 + 2장 연속 유사 | 유사사진썸네일그룹 없음 (각각 3장 미만) |
| ALG-004 | 4장 연속 유사 + 4↔5 거리 > 10 + 4장 연속 유사 | 2개 유사사진썸네일그룹 ([1,2,3,4], [5,6,7,8]) |

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

### 8.4 캐시 테스트 (신규)

| ID | 시나리오 | 예상 결과 |
|----|----------|----------|
| ALG-013 | 뷰어 진입 (캐시 hit) | CachedFace 조회, +버튼 즉시 표시 |
| ALG-014 | 뷰어 진입 (캐시 miss) | 분석 요청, 완료 후 +버튼 표시 |
| ALG-015 | 좌표 변환 (Vision → UIKit) | 올바른 화면 좌표 반환 |
| ALG-016 | 삭제 후 그룹 무효화 | 캐시 정리, +버튼 미표시 |

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

---

## 11. 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0 | 2026-01-01 | prd8algorithm 기반 신규 작성: CachedFace 구조 도입, 뷰어 얼굴 분석 제거(캐시 참조), 좌표 변환 함수 추가, 캐시 테스트 케이스 추가 |
| 1.1 | 2026-01-01 | 로직 보완: SimilarityCache에 LRU eviction 로직 추가(evictIfNeeded, recalculateValidPersonIndices), prepareForReanalysis() 추가(재분석 시 old group 정리), getExpectedViewerSize() 추가(iPad 분할 모드 반영) |
| 1.2 | 2026-01-01 | 구현 명세 보완: §3.5 뷰어 분석 요청 시 범위 처리 명확화(notAnalyzed만 분석), §6.1 얼굴 크롭 코드 수정(정사각형 유지, 경계 내 최대 크기로 축소) |
| 1.3 | 2026-01-02 | 인물 매칭 방식 변경: 하이브리드(위치 기반 + 백그라운드 검증) → Feature Print 기반 직접 매칭. §4.2 방식 선택 재작성, §4.3 위치 기반 → 인물 번호 부여로 축소, §4.4 Feature Print 기반 인물 매칭으로 재작성, §4.5 하이브리드 방식 삭제, §5 자동 검증 → 인물 판정 결과 처리로 단순화 |
