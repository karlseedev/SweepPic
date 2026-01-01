# PRD 9 알고리즘 상세: 유사 사진 분류 및 동일 인물 매칭

**버전**: 1.1
**작성일**: 2026-01-01
**관련 문서**: [PRD 9](./prd9.md), [Spec](../specs/001-similar-photo/spec.md)

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

**재분석 시 캐시 갱신 규칙:**
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

#### 좌표계 명시

**Vision Framework 좌표계:**
- 정규화 좌표: 0.0 ~ 1.0
- 원점: **좌하단** (화면 좌표계와 반대)
- origin.x: 0(왼쪽) → 1(오른쪽)
- origin.y: 0(아래) → 1(위)

**정렬 규칙:**
- X 정렬: `origin.x` 오름차순 (왼쪽 → 오른쪽)
- Y 정렬 (tie-break): `origin.y` 내림차순 (위쪽 → 아래쪽)
- Tie-break 임계값: X 차이가 **0.05 이하**일 때 Y 정렬 적용

**시뮬레이션 (2열 구도):**
```
화면 표시:        Vision 좌표:
[A] [B]          A(x=0.2, y=0.7)  B(x=0.7, y=0.7)
[C] [D]          C(x=0.2, y=0.3)  D(x=0.7, y=0.3)

정렬 결과: A → C → B → D
(왼쪽 열 위→아래, 오른쪽 열 위→아래)
```

#### 구현 코드

> **주의**: 이 함수는 prd9.md §2.4.4의 전체 규칙 중 **위치 기반 정렬** 부분만 담당합니다.
> 전체 흐름(5% 크기 필터 → 크기순 상위 5개 → 위치순 재정렬)은 prd9.md §2.4.4 참조.

```swift
struct DetectedFace {
    let observation: VNFaceObservation
    let boundingBox: CGRect  // Vision 정규화 좌표 (원점 좌하단)
    var personIndex: Int = 0
}

/// 위치 기반 인물 번호 부여 (prd9.md §2.4.4의 Step 3~4)
/// - 사전 조건: 이미 5% 필터 및 크기순 상위 5개 선택이 완료된 faces
/// - 좌표계: Vision 정규화 좌표 (0~1, 원점 좌하단)
func assignPersonIndicesByPosition(faces: [DetectedFace]) -> [DetectedFace] {
    // Step 3: 위치순 재정렬 (좌→우, 위→아래)
    let sorted = faces.sorted { face1, face2 in
        // X 차이가 0.05 초과면 X 기준 정렬
        if abs(face1.boundingBox.origin.x - face2.boundingBox.origin.x) > 0.05 {
            return face1.boundingBox.origin.x < face2.boundingBox.origin.x  // 왼쪽 먼저
        }
        // X가 거의 같으면 Y 기준 (Vision 좌표계에서 y가 클수록 위)
        return face1.boundingBox.origin.y > face2.boundingBox.origin.y  // 위쪽 먼저
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

**임계값 정의:** prd9.md §2.7.2 참조
- 구현 시 `MatchConfidence` enum으로 분류 (아래 코드 참조)

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
│  유사사진썸네일그룹 사진 진입 (뷰어)                          │
│         ↓                                                    │
│  캐시에서 CachedFace 조회                                     │
│         ↓                                                    │
│  isValidSlot=true인 얼굴에 +버튼 자동 표시                    │
│         ↓                                                    │
│  + 버튼 탭 (인물 N 선택)                                      │
│         ↓                                                    │
│  유사사진정리그룹 생성 (최대 8장, 인덱스 거리순)                │
│         ↓                                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Phase 1: 위치 기반 매칭 (캐시 참조)                  │    │
│  │   - 각 사진의 CachedFace에서 해당 personIndex 얼굴   │    │
│  │   - 캐시된 boundingBox로 얼굴 크롭                   │    │
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

**검증 타이밍:** prd9.md §2.7.5 참조

### 5.4 경고 UI

**경고 UI 스펙:** prd9.md §2.7.3 (전체 경고), §2.7.4 (개별 배지) 참조

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
