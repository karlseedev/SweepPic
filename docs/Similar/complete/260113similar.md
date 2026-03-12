# 버그 분석: 그리드 테두리 있는 사진 → 뷰어 +버튼 미표시

**Date**: 2026-01-13
**Issue**: 그리드에서 테두리가 표시된 사진을 클릭해 뷰어로 진입했으나, +버튼이 표시되지 않음

---

## 1. 문제 현상

- 그리드에서 유사 사진 그룹에 속해 **테두리가 표시된** 사진 클릭
- 뷰어로 진입 후 **+버튼이 표시되지 않음**
- 사용자 기대: 테두리 있는 사진 → 뷰어에서 +버튼 표시

---

## 2. 관련 문서

### 2.1 Spec 요구사항

| FR | 내용 |
|----|------|
| FR-007 | 유사 사진 그룹에 속한 셀에 테두리 애니메이션 표시 |
| FR-011 | 유사 사진 그룹에 속한 사진 진입 시 **유효 슬롯 얼굴**에 +버튼 자동 표시 |
| FR-012 | 그리드에서 분석된 결과를 캐시로 재사용하며 뷰어에서 재분석하지 않음 |

### 2.2 Edge Cases (spec.md:91, 93)

- "사진에 얼굴이 없을 때: +버튼이 표시되지 않음"
- "인물 슬롯에 2장 미만일 때: 해당 인물의 +버튼 미표시"

### 2.3 prd9algorithm.md 핵심 로직 (§3.7, 565-598행)

```swift
// 유효 슬롯에 해당하는 얼굴이 있는 사진만 유효
let validAssets = assetsWithFaces.filter { entry in
    entry.faces.contains { validSlots.contains($0.personIndex) }
}
let validAssetIDs = Set(validAssets.map { $0.asset.localIdentifier })

if validAssets.count >= 3 && !validSlots.isEmpty {
    // 그룹에 포함
    for entry in validAssets {
        cache.setState(.analyzed(inGroup: true, groupID: groupID), for: ...)
    }
}

// 탈락한 사진 상태 업데이트 (얼굴 없음, 유효 슬롯 미충족 등)
let excludedAssetIDs = allAssetIDs.subtracting(validAssetIDs)
for assetID in excludedAssetIDs {
    cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
}
```

---

## 3. 원인 분석

### 3.1 인과관계 구조

```
[핵심 원인]
그룹 멤버 필터링 누락
→ 유효 슬롯 얼굴이 없는 사진도 그룹에 포함됨
→ inGroup: true로 설정
→ 그리드에서 테두리 표시
→ 뷰어에서 +버튼 없음 (validFaces가 비어있으므로)

        ↑ (기여 요인)

[기여 요인 - 추후 개선]
assignPersonIndicesForGroup의 0.15 임계값
→ 사람이 조금만 움직여도 위치 매칭 실패
→ CachedFace에 저장되지 않음 (continue)
→ photoFacesMap[assetID]가 빈 배열 또는 nil
```

### 3.2 기여 요인: 위치 매칭 과도하게 엄격 (0.15 임계값) - 추후 개선

**현재 구현** (`SimilarityAnalysisQueue.swift:362-384`):

```swift
private func assignPersonIndicesForGroup(...) -> [String: [CachedFace]] {
    // 첫 번째 사진의 얼굴 위치를 기준 슬롯으로 설정
    var referenceSlots: [(index: Int, center: CGPoint)] = []

    for assetID in assetIDs {
        for face in faces {
            // 가장 가까운 기준 슬롯 찾기
            for slot in referenceSlots {
                let distance = hypot(faceCenter.x - slot.center.x, faceCenter.y - slot.center.y)
                if distance < bestDistance && distance < positionThreshold {  // 0.15
                    bestSlot = slot.index
                }
            }

            // 매칭되는 슬롯이 없으면 이 얼굴은 스킵
            guard let personIndex = bestSlot else { continue }  // ← 문제: 얼굴 데이터 버림

            cachedFaces.append(CachedFace(...))
        }
    }
}
```

**문제점:**
- 연속 촬영에서 사람이 조금만 움직여도 (0.15 이상) 얼굴이 "없는 것"으로 처리됨
- 멀쩡한 얼굴 데이터가 CachedFace에 저장되지 않음
- 결과적으로 유효 슬롯 얼굴이 없는 것으로 판단됨

### 3.3 핵심 원인: 그룹 멤버 필터링 누락

**현재 구현** (`SimilarityAnalysisQueue.swift:222-228`):

```swift
// T014.7: 캐시 저장 요청 (T010 호출)
if let groupID = await cache.addGroupIfValid(
    members: groupAssetIDs,  // ← 문제: 전체 그룹 멤버 전달
    validSlots: validSlots,
    photoFaces: photoFacesMap
) {
    validGroupIDs.append(groupID)
}
```

**문제점:**
- `groupAssetIDs`는 **이미지 유사도 기준**으로 그룹화된 모든 사진
- prd9algorithm.md의 "유효 슬롯 얼굴이 있는 사진만 그룹에 포함" 로직이 누락됨

**예시:**
```
groupAssetIDs = [A, B, C, D, E] (이미지 유사도 기준)
validSlots = {1} (인물 1만 유효)

얼굴 감지 결과:
- A: 인물 1 감지 ✓
- B: 인물 1 감지 ✓
- C: 인물 1 감지 ✓
- D: 얼굴 없음 ✗ (또는 위치 매칭 실패로 CachedFace 없음)
- E: 인물 2만 감지 (유효 슬롯 아님) ✗

현재 동작:
→ addGroupIfValid(members: [A,B,C,D,E], ...)
→ A,B,C,D,E 모두 inGroup: true로 설정
→ 그리드에서 A,B,C,D,E 모두 테두리 표시
→ D, E 클릭 시 +버튼 없음
```

---

## 4. 수정 계획

### 4.1 수정 범위

| 구분 | 문제 | 수정 내용 | 적용 여부 |
|------|------|-----------|-----------|
| **핵심 수정** | 그룹 멤버 필터링 누락 | validMembers로 필터링 | ✅ 적용 |
| 추후 개선 | 0.15 임계값 | 매칭 실패 시 새 슬롯 생성 | ⏸️ 보류 (Phase 7+) |

> **결정 근거**: 핵심 수정만으로 "테두리 있는 사진 = +버튼 표시되는 사진" 일관성이 보장됩니다.
> 0.15 임계값 수정은 인물 번호 혼란 등 부작용 위험이 있어 추후 검토합니다.

### 4.2 참고: 위치 매칭 유연화 (보류 - Phase 7+)

**수정 위치**: `SimilarityAnalysisQueue.swift` - `assignPersonIndicesForGroup`

**수정 전:**
```swift
// 매칭되는 슬롯이 없으면 이 얼굴은 스킵
guard let personIndex = bestSlot else { continue }
```

**수정 후:**
```swift
let personIndex: Int
if let matchedSlot = bestSlot {
    // 기존 슬롯에 매칭
    personIndex = matchedSlot
} else {
    // 매칭 실패 시 새 슬롯 생성 (얼굴 데이터 보존)
    let newIndex = referenceSlots.count + 1
    referenceSlots.append((index: newIndex, center: faceCenter))
    personIndex = newIndex
}

cachedFaces.append(CachedFace(
    boundingBox: face.boundingBox,
    personIndex: personIndex,
    isValidSlot: false  // 나중에 갱신
))
```

### 4.3 핵심 수정: 그룹 멤버 필터링

**수정 위치**: `SimilarityAnalysisQueue.swift` - `formGroupsForRange`

**수정 코드:**
```swift
for groupAssetIDs in rawGroups {
    // ... 얼굴 감지 및 personIndex 할당 (기존 코드 유지) ...
    // ... validSlots 계산 (기존 코드 유지) ...

    // ========== 추가할 코드 ==========
    // 유효 슬롯에 해당하는 얼굴이 있는 사진만 그룹에 포함
    let validMembers = groupAssetIDs.filter { assetID in
        guard let faces = photoFacesMap[assetID] else { return false }
        return faces.contains { validSlots.contains($0.personIndex) }
    }

    // 그룹 내 탈락 사진 상태 업데이트 (prd9algorithm.md 595-598행)
    let excludedFromGroup = Set(groupAssetIDs).subtracting(validMembers)
    for assetID in excludedFromGroup {
        await cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
        if let faces = photoFacesMap[assetID] {
            await cache.setFaces(faces, for: assetID)
        }
    }
    // ================================

    // T014.7: 캐시 저장 요청
    if let groupID = await cache.addGroupIfValid(
        members: validMembers,  // ← 수정: validMembers 전달
        validSlots: validSlots,
        photoFaces: photoFacesMap
    ) {
        validGroupIDs.append(groupID)
    }
}
```

### 4.4 수정 후 동작

**예시 (동일 케이스):**
```
groupAssetIDs = [A, B, C, D, E]
validSlots = {1}

핵심 수정 적용 후:
1. validMembers 필터링: [A, B, C] (유효 슬롯 얼굴 있음)
2. excludedFromGroup = [D, E]
3. D, E → inGroup: false 설정 (테두리 미표시)
4. addGroupIfValid(members: [A,B,C], ...) 호출
5. A, B, C → inGroup: true 설정 (테두리 표시)

결과:
- 그리드: A, B, C만 테두리 표시
- 뷰어: A, B, C 진입 시 +버튼 표시
- D, E는 테두리 없음, +버튼도 없음 (일관성 유지)
```

---

## 5. 케이스별 검증

| 케이스 | 상황 | 결과 |
|--------|------|------|
| 1 | validMembers 3장 이상 | 그룹 생성, excludedFromGroup은 inGroup:false |
| 2 | validMembers 2장 | excludedFromGroup → inGroup:false, validMembers → **addGroupIfValid 내부에서 inGroup:false** |
| 3 | validSlots 비어있음 | validMembers 비어있음 → **addGroupIfValid 내부에서 inGroup:false** |
| 4 | 모든 사진이 유효 | excludedFromGroup 없음, 모두 그룹에 포함 |
| 5 | 사람이 많이 움직인 연속 촬영 | 위치 매칭 실패 시 빈 CachedFace → validMembers에서 제외 → 일관성 유지 |

### 5.1 addGroupIfValid 내부 안전장치

`SimilarityCache.addGroupIfValid`는 조건 미충족 시 **내부에서 members를 정리**합니다:

```swift
// SimilarityCache.swift:197-206
guard members.count >= SimilarityConstants.minGroupSize else {
    // 조건 미충족 → 멤버들 analyzed(inGroup: false) 설정
    for assetID in members {
        setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
        // ... 얼굴 데이터도 저장
    }
    return nil
}
```

따라서 **호출자(SimilarityAnalysisQueue)에서 별도 정리가 필요 없습니다.**
테두리 잔류 위험 없음이 보장됩니다.

---

## 6. prd9algorithm.md 로직 대조

| prd9algorithm.md (§3.7) | 수정 후 구현 | 일치 |
|-------------------------|-------------|------|
| `validAssets = assetsWithFaces.filter { ... }` | `validMembers = groupAssetIDs.filter { ... }` | ✓ |
| `excludedAssetIDs = allAssetIDs.subtracting(validAssetIDs)` | `excludedFromGroup = Set(groupAssetIDs).subtracting(validMembers)` | ✓ |
| `cache.setState(.analyzed(inGroup: false, ...), for: excludedAssetID)` | 동일 | ✓ |
| `cache.setGroupMembers(validAssets.map(...), for: groupID)` | `addGroupIfValid(members: validMembers, ...)` | ✓ |

---

## 7. 영향 범위

### 7.1 수정 파일
- `SimilarityAnalysisQueue.swift` (1개 파일, 1곳 수정)

### 7.2 영향받는 기능
- 그리드 테두리 표시 (유효 슬롯 얼굴 있는 사진만 표시됨)
- 뷰어 +버튼 표시 (테두리 있는 사진은 항상 +버튼 표시됨)

### 7.3 기대 효과
- **일관성 보장**: 테두리 있는 사진 = +버튼 표시되는 사진
- **사용자 경험 개선**: 테두리 클릭 시 항상 +버튼이 있어 얼굴 비교 가능

---

## 8. 관련 이슈 현황 (docs/llm/6.md 참조)

docs/llm/6.md에서 식별된 4개 이슈 중 현재 문서는 "이슈 3: 뷰어에서 +버튼 미표시"에 집중합니다.
다른 이슈들의 현재 상태는 아래와 같습니다.

| 이슈 | 설명 | 상태 | 비고 |
|------|------|------|------|
| 이슈 1 | iOS 26 그룹핑 실패 (Vision Revision) | ❌ 수정 필요 | `SimilarityAnalyzer.swift:92` revision 미지정 |
| 이슈 2 | 휴지통 사진 분석 시도 | ✅ 수정 완료 | `viewerMode != .trash` 체크 존재 (385번 줄) |
| 이슈 3 | 뷰어에서 +버튼 미표시 | ❌ 수정 필요 | **본 문서의 주제** |
| 이슈 4 | FaceComparison UI 문제 | ✅ 수정 완료 | `safeAreaLayoutGuide` 적용 완료 |

### 이슈 1 수정 방안 (Vision Revision)

**수정 위치**: `SimilarityAnalyzer.swift` - `generateFeaturePrint` 메서드

**현재 코드:**
```swift
let request = VNGenerateImageFeaturePrintRequest()
```

**수정 코드:**
```swift
let request = VNGenerateImageFeaturePrintRequest()
// iOS 버전별 Revision 명시적 지정 (iOS 26 호환성)
if #available(iOS 17.0, *) {
    request.revision = VNGenerateImageFeaturePrintRequestRevision2
} else {
    request.revision = VNGenerateImageFeaturePrintRequestRevision1
}
```

**이유:**
- iOS 버전에 따라 기본 revision이 달라짐
- iOS 26의 기본 revision이 기존 임계값(0.5)과 호환되지 않는 거리 스케일을 가질 수 있음
- 명시적 지정으로 일관된 동작 보장

---

## 9. 참고 문서

- `specs/002-similar-photo/spec.md` - FR-007, FR-011, FR-012
- `docs/prd9algorithm.md` - §3.7 filterGroupsWithEligibleFaces
- `specs/002-similar-photo/tasks.md` - T037, T039 (Phase 7 Edge Cases)
- `docs/llm/4.md` - 초기 분석 (구조적 원인)
- `docs/llm/5.md` - 보완 분석
- `docs/llm/6.md` - 근본 원인 분석 (위치 매칭)
