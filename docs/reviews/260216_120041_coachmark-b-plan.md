검토 결과, 계획의 핵심 방향(트리거 시점/애니메이션 컨셉/기존 A 재사용)은 맞습니다. 다만 현재 문서 그대로 구현하면 라이프사이클 경계에서 오동작 가능성이 있어 보완이 필요합니다.

**Findings (심각도 순)**
1. **High** `0.5초 지연 표시`가 취소되지 않아, 다른 화면 위에 코치마크가 뜰 수 있습니다.  
`/Users/karl/.claude/plans/steady-weaving-alpaca.md:54` 에서 `asyncAfter(0.5)`만 정의되어 있고 취소 전략이 없습니다.  
뷰어는 실제로 fullScreen `present`를 수행합니다 (`Features/Viewer/ViewerViewController+SimilarPhoto.swift:692`, `Features/Viewer/ViewerViewController+SimilarPhoto.swift:700`).  
문서의 재검증 가드는 `view.window != nil` 중심(`...alpaca.md:53`, `...alpaca.md:55`)이라, 뷰어가 가려져도 window가 살아있는 케이스를 막지 못할 수 있습니다.  
`DispatchWorkItem` 저장/취소(`viewWillDisappear`, `deinit`)와 `presentedViewController == nil`/top VC 확인이 필요합니다.

2. **Medium** `dismissCurrent()`를 라이프사이클에서 호출하면 “실제 학습 완료” 없이도 영구 표시 완료 처리됩니다.  
계획은 `viewWillDisappear`에서 dismiss를 강제합니다 (`...alpaca.md:80`, `...alpaca.md:90`).  
현재 dismiss는 항상 `markAsShown()`를 호출합니다 (`Shared/Components/CoachMarkOverlayView.swift:301`, `Shared/Components/CoachMarkOverlayView.swift:308`).  
즉 모달 전환/화면 이탈만으로도 다시 안 뜰 수 있습니다. `dismiss(markAsShown:)` 분리가 필요합니다.

3. **Medium** 버튼 설계가 현재 프로젝트 UI 시스템과 불일치합니다.  
계획은 `UIButton.Configuration.glass()`를 제안합니다 (`...alpaca.md:120`, `...alpaca.md:215`).  
하지만 코드베이스는 이미 `GlassTextButton`/`GlassIconButton`을 표준으로 사용 중입니다 (`Features/Viewer/ViewerViewController.swift:177`, `Shared/Components/GlassTextButton.swift:16`).  
현재 구조에 맞추려면 코치마크 버튼도 `GlassTextButton` 기반이 안전합니다.

4. **Medium** 반복 진입 시 중복 스케줄링 방지가 문서에 없습니다.  
뷰어 `viewDidAppear`는 재호출될 수 있습니다 (`Features/Viewer/ViewerViewController+SimilarPhoto.swift:246` 코멘트).  
계획은 `isShowing`만 체크(`...alpaca.md:50`)하고 “대기 중 작업” 플래그가 없어, 지연 블록이 중첩될 수 있습니다.  
`isViewerCoachMarkScheduled` 또는 단일 `pendingWorkItem` 관리가 필요합니다.

5. **Medium** 회전/안전영역 대응이 빠져 있습니다.  
계획은 텍스트/버튼 위치를 고정 좌표 개념으로 정의합니다 (`...alpaca.md:117`, `...alpaca.md:213`).  
뷰어는 회전 대응 코드를 이미 가집니다 (`Features/Viewer/ViewerViewController.swift:374`).  
코치마크가 회전 중 표시되면 레이아웃 깨짐 위험이 있어, Auto Layout 기반 배치 또는 회전 시 dismiss 정책이 필요합니다.

6. **Low** 파일 구조 기술이 최신 상태와 다릅니다.  
계획은 `ViewerViewController+CoachMark.swift`를 “신규 생성”으로 적었지만 (`...alpaca.md:28`, `...alpaca.md:32`), 파일은 이미 존재합니다 (`Features/Viewer/ViewerViewController+CoachMark.swift:1`).

**추가로 넣으면 좋은 검증 케이스**
1. `0.5초 대기 중` 다른 화면 present 시 코치마크가 뜨지 않는지.  
2. 인터랙티브 back 취소 시 `markAsShown`이 의도대로 처리되는지.  
3. 회전(세로↔가로) 중 코치마크 레이아웃 안정성.

필요하면 이 피드백 기준으로 계획 문서를 바로 수정안 형태로 정리해드리겠습니다.