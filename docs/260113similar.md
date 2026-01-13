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
[근본 원인]
assignPersonIndicesForGroup의 0.15 임계값
→ 사람이 조금만 움직여도 위치 매칭 실패
→ CachedFace에 저장되지 않음 (continue)
→ photoFacesMap[assetID] = [] (빈 배열)

        ↓

[결과적 원인]
빈 CachedFace를 가진 사진도 그룹 멤버로 포함됨
→ inGroup: true로 설정
→ 그리드에서 테두리 표시
→ 뷰어에서 +버튼 없음 (validFaces가 비어있으므로)
```

### 3.2 근본 원인: 위치 매칭 과도하게 엄격 (0.15 임계값)

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

### 3.3 결과적 원인: 그룹 멤버 필터링 누락

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

### 4.1 수정 우선순위

| 순서 | 문제 | 수정 내용 | 이유 |
|------|------|-----------|------|
| **1** | 0.15 임계값 | 매칭 실패 시 새 슬롯 생성 | 근본 원인 - 얼굴 데이터가 버려지는 문제 |
| **2** | 그룹 멤버 필터링 | validMembers로 필터링 | 구조적 보완 - 여전히 얼굴 없는 사진 존재 가능 |

### 4.2 수정 1: 위치 매칭 유연화 (근본 원인)

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

### 4.3 수정 2: 그룹 멤버 필터링 (결과적 원인)

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
수정 1 적용 후:
- D: 위치 매칭 실패해도 새 슬롯(인물 3)으로 CachedFace 저장
- 하지만 인물 3은 1장뿐이므로 유효 슬롯 아님

수정 2 적용 후:
- validMembers = [A, B, C] (유효 슬롯 얼굴 있음)
- excludedFromGroup = [D, E]
- D, E → inGroup: false 설정 (테두리 미표시)
- A, B, C → inGroup: true 설정 (테두리 표시)

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
| 2 | validMembers 2장 | excludedFromGroup → inGroup:false, validMembers → addGroupIfValid 내부에서 inGroup:false |
| 3 | validSlots 비어있음 | 모두 excludedFromGroup → inGroup:false |
| 4 | 모든 사진이 유효 | excludedFromGroup 없음, 모두 그룹에 포함 |
| 5 | 사람이 많이 움직인 연속 촬영 | 수정 1로 새 슬롯 생성, 유효 슬롯 판정은 정상 동작 |

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
- `SimilarityAnalysisQueue.swift` (1개 파일, 2곳 수정)

### 7.2 영향받는 기능
- 그리드 테두리 표시 (유효 슬롯 얼굴 있는 사진만 표시됨)
- 뷰어 +버튼 표시 (테두리 있는 사진은 항상 +버튼 표시됨)
- 연속 촬영 시 위치 변화 대응 (새 슬롯 생성으로 얼굴 데이터 보존)

### 7.3 기대 효과
- **일관성 보장**: 테두리 있는 사진 = +버튼 표시되는 사진
- **사용자 경험 개선**: 테두리 클릭 시 항상 +버튼이 있어 얼굴 비교 가능
- **연속 촬영 대응**: 사람이 움직여도 얼굴 데이터 유지

---

## 8. 수정 2만 필요한 이유 (수정 1은 보류)

### 8.1 현재 상황 재분석

수정 1(위치 매칭 유연화)의 문제점:
- 새 슬롯을 생성하면 인물 번호가 사진마다 달라질 수 있음
- 예: A사진의 인물1, B사진의 인물2가 실제로는 같은 사람
- 이는 얼굴 비교 화면에서 혼란을 야기할 수 있음

### 8.2 수정 2만으로 충분한 이유

현재 문제의 핵심:
- 테두리가 있는데 +버튼이 없는 불일치
- 수정 2로 유효 슬롯 얼굴이 없는 사진을 그룹에서 제외하면 해결됨

위치 매칭 실패한 사진:
- CachedFace가 비어있음
- 수정 2에서 validMembers 필터링 시 제외됨
- 테두리 미표시 → 뷰어에서 +버튼 없어도 일관성 유지

### 8.3 최종 결론

**수정 2만 적용**하고, 수정 1은 추후 검토 (Phase 7+)

---

## 9. 참고 문서

- `specs/002-similar-photo/spec.md` - FR-007, FR-011, FR-012
- `docs/prd9algorithm.md` - §3.7 filterGroupsWithEligibleFaces
- `specs/002-similar-photo/tasks.md` - T037, T039 (Phase 7 Edge Cases)
- `docs/llm/4.md` - 초기 분석 (구조적 원인)
- `docs/llm/5.md` - 보완 분석
- `docs/llm/6.md` - 근본 원인 분석 (위치 매칭)
