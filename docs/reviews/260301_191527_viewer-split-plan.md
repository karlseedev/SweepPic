1. **[High] 접근 제어 변경 목록에 컴파일 블로커가 누락되어 있습니다.**  
계획은 아래 메서드를 `private 유지`로 두고 있는데, 실제로는 분리될 Setup/Actions 파일에서 호출됩니다.  
- 계획의 `private 유지`: [cozy-dancing-badger.md:182](/Users/karl/.claude/plans/cozy-dancing-badger.md:182), [183](/Users/karl/.claude/plans/cozy-dancing-badger.md:183), [184](/Users/karl/.claude/plans/cozy-dancing-badger.md:184), [186](/Users/karl/.claude/plans/cozy-dancing-badger.md:186)  
- 실제 호출 근거:  
  - `displayInitialPhoto()`가 `createPageViewController`, `scheduleLOD1Request` 호출: [ViewerViewController.swift:703](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:703), [719](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:719)  
  - Actions가 `updateCurrentPageTrashedState`, `updateToolbarForCurrentPhoto`, `createPageViewController` 호출: [803](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:803), [804](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:804), [885](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:885), [971](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:971), [989](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:989)

2. **[High] `currentIndex`와 상수 접근 제어도 누락되었습니다.**  
- `currentIndex`는 `private(set)`이라 분리된 Actions 파일에서 대입 불가합니다: 선언 [ViewerViewController.swift:117](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:117), 대입 [884](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:884), [968](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:968), [991](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:991)  
- `buttonCenterFromBottom`는 `private static`인데 Setup 분리 후 참조됩니다: 선언 [82](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:82), 사용 [628](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:628), [635](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:635), [642](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:642), [654](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:654), [661](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:661), [669](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:669)

3. **[High] Phase 순서가 “단계별 빌드 성공”을 보장하지 못합니다.**  
Phase 2에서 SystemUI를 먼저 분리하면서 Actions 메서드 접근 제어를 아직 바꾸지 않는데, SystemUI는 이미 Actions를 호출합니다.  
- 계획 단계: [cozy-dancing-badger.md:238](/Users/karl/.claude/plans/cozy-dancing-badger.md:238)-[243](/Users/karl/.claude/plans/cozy-dancing-badger.md:243)  
- SystemUI 내 Actions 호출 근거: [ViewerViewController.swift:1254](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:1254), [1263](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:1263), [1282](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:1282), [1292](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:1292), [1309](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:1309), [1270](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:1270)  
Phase 3도 동일하게 Setup에서 Actions를 참조합니다([608](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:608), [686](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift:686)).

4. **[Medium] 호출 관계도에 누락이 있어 의존성 검토 정확도가 떨어집니다.**  
현재 관계도([cozy-dancing-badger.md:219](/Users/karl/.claude/plans/cozy-dancing-badger.md:219)-[227](/Users/karl/.claude/plans/cozy-dancing-badger.md:227))에 아래 엣지가 빠져 있습니다.  
- Setup → `handleSwipeDelete`  
- Setup → `createPageViewController`, `scheduleLOD1Request`  
- SystemUI → `previousPhotoButtonTapped`, `deleteButtonTapped`, `restoreButtonTapped`, `permanentDeleteButtonTapped`, `excludeButtonTapped`  
순환 의존(무한 재귀형)은 현재 기준으로 보이지 않았고, 주 이슈는 “누락된 의존성 표기”입니다.

검토 요약(요청하신 5항목):
1. 분할 기준/그룹핑: 책임 분리는 전반적으로 타당합니다.  
2. `private→internal` 목록: **누락 있음**(위 1, 2번).  
3. `@objc` 셀렉터 크로스파일: **원칙적으로 안전**. 단, 대상 메서드가 `private`이면 실패하므로 분리 시 `internal @objc` 유지가 필요합니다.  
4. Phase 순서: **현재 계획대로는 단계별 빌드 보장 불가**.  
5. 순환/누락 의존성: 순환은 뚜렷하지 않으나 **의존성 누락 다수**.

권장 수정 한 줄: “파일 이동 전에 공통 선행 단계로 접근제어를 한 번에 정리(특히 `currentIndex` setter, `buttonCenterFromBottom`, `createPageViewController`, `scheduleLOD1Request`, `updateToolbarForCurrentPhoto`, `updateCurrentPageTrashedState`, Actions 타겟 메서드들)한 뒤 Phase 분리”가 안전합니다.