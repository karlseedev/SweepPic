# 유사사진 분석 성능 개선: 그룹별 즉시 알림 + Metal 경량화

> **미진행**: Metal 경량화(별도 문서)로 충분히 빨라져서 본 문서의 계획은 진행하지 않음.

## 개요

타이밍 조절(restore 지연)이 아닌 근본적 접근으로, 2단계 순서대로 진행.
- **1단계: 그룹별 즉시 알림** — 체감 2.5초 → ~0.8초
- **2단계: Metal 경량화** — 1단계 완료 후 별도 계획

이 플랜은 **1단계(그룹별 즉시 알림)**만 다룸.

---

## 핵심 아이디어

현재 모든 그룹의 Face Detection 완료 후 한 번에 알림하는 구조를,
**각 그룹의 `addGroupIfValid()` 성공 직후 즉시 부분 알림**으로 변경.

```
현재:  FP → 그룹 → [그룹1 Face] → [그룹2 Face] → [그룹3 Face] → 알림 → 테두리 전체 (2.5초)
변경:  FP → 그룹 → [그룹1 Face → 알림1 → 테두리1]         (~0.8초, 첫 그룹)
                   [그룹2 Face → 알림2 → 테두리2]         (~1.2초)
                   [그룹3 Face → 알림3 → 테두리3]         (~1.8초)
                   → 최종 알림 (기존 유지)
```

**거짓 양성 0%**: addGroupIfValid() 성공(유효 슬롯 확인 완료)한 확정 그룹만 표시.
기존 캐시 구조(SimilarityAnalysisState, SimilarityCache) 완전 유지.
`preliminaryGroupAssetIDs` 같은 임시 데이터 불필요.

---

## 수정 파일 및 변경 내용

### 1. SimilarityAnalysisQueue.swift — Notification.Name 추가 (L36)

```swift
/// 개별 그룹 분석 완료 알림 (부분 알림)
/// addGroupIfValid() 성공 직후 즉시 발송됩니다.
static let similarPhotoGroupReady = Notification.Name("similarPhotoGroupReady")
```

### 2. SimilarityAnalysisQueue.swift — postGroupReady() 메서드 추가

`postAnalysisComplete()` (L1211) 근처에 추가:

```swift
/// 개별 그룹 분석 완료 알림 발송
/// Face Detection + Match가 완료되어 addGroupIfValid()에 성공한 그룹에 대해 즉시 호출.
private func postGroupReady(groupID: String, memberAssetIDs: [String]) {
    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: .similarPhotoGroupReady,
            object: nil,
            userInfo: [
                "groupID": groupID,
                "memberAssetIDs": memberAssetIDs
            ]
        )
    }
}
```

### 3. SimilarityAnalysisQueue.swift — formGroupsForRange() 내 부분 알림 삽입

**L365-371 (addGroupIfValid 호출 후)에 추가:**

```swift
if let groupID = await cache.addGroupIfValid(
    members: validMembers,
    validSlots: validSlots,
    photoFaces: photoFacesMap
) {
    validGroupIDs.append(groupID)
    // [신규] 그룹 확정 즉시 부분 알림 → 해당 그룹 테두리 바로 표시
    postGroupReady(groupID: groupID, memberAssetIDs: validMembers)
}
```

기존 `postAnalysisComplete()` (L437)는 **그대로 유지** (최종 알림으로 전체 상태 정리용).

### 4. GridViewController+SimilarPhoto.swift — 옵저버 추가

**SimilarPhotoAssociatedKeys (L32)에 키 추가:**
```swift
static var groupReadyObserver: UInt8 = 0
```

**Associated property 추가 (L77 근처):**
```swift
private var groupReadyObserver: NSObjectProtocol? {
    get { ... }
    set { ... }
}
```

**setupSimilarPhotoObserver() (L97 뒤)에 구독 추가:**
```swift
groupReadyObserver = NotificationCenter.default.addObserver(
    forName: .similarPhotoGroupReady,
    object: nil,
    queue: .main
) { [weak self] notification in
    self?.handleGroupReady(notification)
}
```

**removeSimilarPhotoObserver() (L143 앞)에 해제 추가**

### 5. GridViewController+SimilarPhoto.swift — 부분 알림 핸들러

```swift
/// 개별 그룹 분석 완료 핸들러
/// addGroupIfValid() 성공 직후 호출됨. 해당 그룹 멤버 셀에만 테두리 즉시 표시.
/// 이 시점에서 SimilarityCache에는 이미 analyzed(inGroup: true, groupID) 상태가 설정됨.
private func handleGroupReady(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let memberAssetIDs = userInfo["memberAssetIDs"] as? [String] else { return }

    Log.print("[SimilarPhoto] Group ready - \(memberAssetIDs.count) members")

    let memberSet = Set(memberAssetIDs)
    let visibleIndexPaths = collectionView.indexPathsForVisibleItems
    let padding = paddingCellCount

    for indexPath in visibleIndexPaths {
        let actualIndex = indexPath.item - padding
        guard actualIndex >= 0 else { continue }
        let actualIndexPath = IndexPath(item: actualIndex, section: 0)
        guard let assetID = dataSourceDriver.assetID(at: actualIndexPath) else { continue }
        guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else { continue }

        if memberSet.contains(assetID) {
            showBorder(on: cell)
        }
    }
}
```

### 6. 기존 코드 — 변경 없음

- **updateVisibleCellBorders()**: 변경 없음. 기존 `analyzed(inGroup: true)` 체크로 동작.
  handleGroupReady에서 이미 테두리를 표시하고, 최종 알림에서 updateVisibleCellBorders()가
  다시 호출되면 캐시 상태 기반으로 동일하게 유지.
- **configureSimilarPhotoBorder()**: 변경 없음. 캐시에 이미 상태가 설정되어 있으므로 정상 동작.
- **SimilarityCache.swift**: 변경 없음.
- **SimilarityAnalysisState.swift**: 변경 없음.

---

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 스크롤 재개 (취소) | `handleSimilarPhotoScrollStart()`가 `hideAllBorders()` + `cancel()` 호출. 부분 알림이 발송되었어도 테두리 전체 제거. 취소된 이후의 postGroupReady는 메인 스레드에서 처리되지만, 이미 cancel 되었으므로 showBorder의 `isScrolling` 가드에서 차단됨. |
| rawGroups 비어있음 | L283-289 조기 종료. 부분 알림 없음. |
| addGroupIfValid 실패 | groupID가 nil → 부분 알림 미발송. 해당 그룹 멤버는 analyzed(false)로 설정됨. |
| 동시 분석 요청 | 이전 분석 취소 → 새 분석 시작. 부분 알림은 유효 그룹에만 발송되므로 충돌 없음. |
| Viewer | `similarPhotoAnalysisComplete`만 구독. 변경 불필요. |
| 부분 알림 후 최종 알림 | `updateVisibleCellBorders()`가 캐시 기반으로 재확인. 이미 표시된 테두리는 유지, 미표시 셀은 여전히 미표시. 중복 showBorder 호출은 기존 레이어 체크로 안전. |

## 수정하지 않는 파일

- `SimilarityCache.swift` — 캐시 구조 변경 없음
- `SimilarityAnalysisState.swift` — 상태 열거형 변경 없음
- `ViewerViewController+SimilarPhoto.swift` — 뷰어는 정식 알림만 사용
- `GridScroll.swift` — restore 타이밍 변경 없음
- `BorderAnimationLayer.swift` — 테두리 애니메이션 변경 없음

## 검증

1. 빌드 성공 확인
2. `performanceLoggingEnabled = true`로 동일 3개 화면 테스트
3. 확인 사항:
   - 첫 유효 그룹 완료 시점(~0.8초)에 해당 그룹 테두리 표시
   - 이후 그룹들이 순차적으로 테두리 추가
   - 최종 알림 후 전체 상태 정상
   - 거짓 양성 테두리 없음 (addGroupIfValid 성공한 것만)
   - 스크롤 재개 시 테두리 정상 숨김
   - 뷰어 얼굴 줌 아이콘 정상 동작
