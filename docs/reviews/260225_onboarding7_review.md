`docs/onboarding/260211onboarding-7.md` 기준으로 보면 목표(메뉴에서 코치마크 즉시 재생) 자체는 달성 가능하지만, 현재 계획만으로는 그대로 구현 시 실패/침묵/오작동 가능성이 꽤 있습니다. 특히 C, E-1+E-2는 설계 보강이 필요합니다.

**주요 발견사항 (중요도 순)**
1. `[치명적]` E-1+E-2 재생 흐름이 현재 설계대로는 막힙니다. 문서의 A 변형 오버레이가 살아있는 상태에서 E 시퀀스를 시작하려고 하면 `showDeleteSystemGuideIfNeeded`가 `CoachMarkManager.shared.isShowing` 가드에 걸려 스킵됩니다. `docs/onboarding/260211onboarding-7.md:105`, `docs/onboarding/260211onboarding-7.md:111`, `SweepPic/SweepPic/Features/Grid/BaseGridViewController.swift:1053`, `SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView.swift:71`

2. `[치명적]` 메뉴 액션 구현 경로가 계획에 빠져 있습니다. 현재 “설명 다시 보기” 메뉴 생성 함수는 `static`이라 인스턴스 메서드(재생 함수) 호출을 캡처할 수 없습니다. 문서의 수정 대상에 이 시그니처 변경(또는 인스턴스 menu builder 추가)이 없습니다. `docs/onboarding/260211onboarding-7.md:145`, `docs/onboarding/260211onboarding-7.md:150`, `SweepPic/SweepPic/Features/Grid/GridViewController+Cleanup.swift:64`, `SweepPic/SweepPic/Features/Grid/GridViewController+Cleanup.swift:103`, `SweepPic/SweepPic/Features/Grid/GridViewController+Cleanup.swift:435`

3. `[높음]` “플래그 리셋” 방식은 실패 시 온보딩 상태를 오염시킬 수 있습니다. 재생이 실제 표시 전에 실패하면 `hasBeenShown=false` 상태가 남아 이후 자연 온보딩이 다시 뜨는 부작용이 생깁니다. (A/B/C/D/E 모두 동일 패턴) `docs/onboarding/260211onboarding-7.md:28`, `docs/onboarding/260211onboarding-7.md:43`, `docs/onboarding/260211onboarding-7.md:60`, `docs/onboarding/260211onboarding-7.md:84`, `docs/onboarding/260211onboarding-7.md:103`, `docs/onboarding/260211onboarding-7.md:127`, `SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView.swift:40`, `SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView.swift:46`

4. `[높음]` E-1+E-2는 실제 삭제 대상 선정/실패 처리 조건이 부족합니다. 중앙 셀이 이미 삭제대기함 상태일 수 있고(복원 방향이 될 수 있음), 삭제 실패 시 후속 E 시퀀스/오버레이 정리가 문서에 없습니다. `docs/onboarding/260211onboarding-7.md:104`, `docs/onboarding/260211onboarding-7.md:110`, `SweepPic/SweepPic/Features/Grid/BaseGridViewController.swift:910`, `SweepPic/SweepPic/Features/Grid/BaseGridViewController.swift:912`

5. `[높음]` C 재생 계획의 캐시 탐색/자동탐색 설계가 현재 코드와 맞물리는 방식이 부족합니다. `SimilarityCache`는 actor라 `await`/`Task`가 필요하고, 제안된 `findAnyGroupMember()`는 “최신 사진부터”가 아니라 딕셔너리 순회라 결과가 비결정적입니다. `docs/onboarding/260211onboarding-7.md:61`, `docs/onboarding/260211onboarding-7.md:68`, `docs/onboarding/260211onboarding-7.md:155`, `SweepPic/SweepPic/Features/SimilarPhoto/Analysis/SimilarityCache.swift:55`, `SweepPic/SweepPic/Features/SimilarPhoto/Analysis/SimilarityCache.swift:65`

6. `[높음]` C 재생의 “셀로 스크롤 → 뱃지 표시 → C-1 자동 트리거” 보장이 빠져 있습니다. 실제 뱃지 표시 함수 `showBadge(on:)`는 `private`이고, `showSimilarBadgeCoachMark`만 공개해도 “뱃지가 보이는 상태”를 보장하지 못합니다. `docs/onboarding/260211onboarding-7.md:64`, `docs/onboarding/260211onboarding-7.md:147`, `SweepPic/SweepPic/Features/Grid/GridViewController+CoachMarkC.swift:174`, `SweepPic/SweepPic/Features/Grid/GridViewController+SimilarPhoto.swift:320`

7. `[중간]` A/E 재생 구현에 필요한 `findCenterCell()` 접근 제어 변경이 문서에 빠져 있습니다. E-1+E-2 흐름에서 직접 호출하려면 현재 `private`라 새 파일에서 호출 불가입니다. `docs/onboarding/260211onboarding-7.md:104`, `docs/onboarding/260211onboarding-7.md:146`, `SweepPic/SweepPic/Features/Grid/GridViewController+CoachMark.swift:149`

8. `[중간]` D/E-3는 정적 오버레이 API를 직접 호출하는 계획인데, 정상 경로의 호출자 가드(`isShowing`, topVC, presentedVC 등)를 우회합니다. 특히 D는 기존 `showCoachMarkD()`가 재시도/가드 로직을 이미 갖고 있습니다. `docs/onboarding/260211onboarding-7.md:86`, `docs/onboarding/260211onboarding-7.md:128`, `SweepPic/SweepPic/Features/Grid/GridViewController+CoachMarkD.swift:113`, `SweepPic/SweepPic/Features/Grid/GridViewController+CoachMarkD.swift:125`, `SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+CoachMarkD.swift:50`, `SweepPic/SweepPic/Features/Albums/TrashAlbumViewController.swift:563`, `SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+E3.swift:35`

9. `[중간]` B 재생 계획의 “push”는 플랫폼별 실제 동작과 다릅니다(iOS 26+ push, 그 외 present). 또한 뷰어 진입 후 B 표시 가드 실패(`capturePhotoSnapshot`, modal, stale C2 wait state 등) 시 복구 UX가 문서에 없습니다. `docs/onboarding/260211onboarding-7.md:45`, `SweepPic/SweepPic/Features/Grid/GridViewController.swift:814`, `SweepPic/SweepPic/Features/Viewer/ViewerViewController+CoachMark.swift:20`

10. `[낮음]` 문서의 “UIMenu에 설명 다시 보기 항목 추가”는 현재 코드 상태와 불일치합니다. 항목 텍스트는 이미 존재하고 액션 바인딩이 비어 있는 상태입니다. `docs/onboarding/260211onboarding-7.md:145`, `SweepPic/SweepPic/Features/Grid/GridViewController+Cleanup.swift:435`

**코치마크별 즉시 재생 Edge Case 체크 (문서 보강 필요)**
1. `A`
사진 0장 외에도 `view.window == nil`, 다른 코치마크 표시 중, VoiceOver, visible cell 없음, snapshot 실패를 실패 케이스로 정의해야 합니다. `SweepPic/SweepPic/Features/Grid/GridViewController+CoachMark.swift:113`

2. `B`
보이는 셀이 모두 비디오/삭제대기함 상태인 경우 target 선정 규칙이 필요합니다. 재생 시작 전 `CoachMarkManager.shared.resetC2State()` 같은 stale C 상태 정리도 넣는 게 안전합니다. `SweepPic/SweepPic/Features/Viewer/ViewerViewController+CoachMark.swift:25`

3. `C`
캐시 miss 시 “전체 라이브러리 자동탐색”은 취소 조건(화면 이탈/스크롤 시작/메뉴 재탭), 타임아웃, 진행 표시 dismiss 보장을 명시해야 합니다. C-2 타임아웃/face button 미출현 시 replay 실패 피드백도 필요합니다. `SweepPic/SweepPic/Features/Viewer/ViewerViewController+CoachMarkC.swift:58`

4. `D`
정리 버튼 프레임 획득 실패 시 실제 동작은 “포커싱 없음 + 전체 딤”으로 바뀝니다. 문서에 fallback UI를 명시해야 합니다. `SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+CoachMarkD.swift:46`, `SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+CoachMarkD.swift:83`

5. `E-1+E-2`
실제 삭제를 자동으로 수행하므로 대상이 이미 trashed인지 검사하고, 실패 시 토스트/롤백/오버레이 해제를 정의해야 합니다. 또 재생 후 탭이 삭제대기함으로 전환된다는 점(원래 화면 복귀 여부)을 계획에 포함해야 합니다. `SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+E1E2.swift:475`

6. `E-3`
직접 재생 시에도 `isShowing`, `window`, top 화면 조건을 사전 체크해야 중첩 오버레이를 막을 수 있습니다. 현재 정적 API 자체에는 `isShowing` 가드가 없습니다. `SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+E3.swift:35`

**계획 보완 제안 (실행 가능하게 만들기 위한 최소 수정)**
1. 메뉴 생성 함수를 인스턴스 메서드로 바꾸거나 `makeCoachMarkReplayMenu(for:)`로 변경해서 `self`를 `weak` 캡처.
2. “플래그 리셋” 대신 `forceReplay` 경로(가드 bypass) 추가를 우선 검토.
3. E-1+E-2는 “A 변형 오버레이”와 E 오버레이를 분리하지 말고 하나의 전용 replay 시퀀스로 설계하거나, 명시적 handoff(overlay dismiss 후 삭제/콜백 후 E 시작) 절차 추가.
4. C는 v1에서 “캐시 hit만 지원”으로 범위를 줄이거나, fallback 탐색을 별도 티켓으로 분리.
5. D/E-3는 정적 오버레이 직접 호출 대신 기존 호출 경로의 가드/재시도 로직 재사용.
6. 검증 항목에 실패 케이스(대상 없음, 화면 전환 중, overlay 중복, 삭제 실패, C 타임아웃)를 추가.

웹 검색은 하지 않았습니다. 이번 검토는 현재 저장소 코드만으로 충분히 판단 가능했습니다.