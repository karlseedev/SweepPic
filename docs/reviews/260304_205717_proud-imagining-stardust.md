**리뷰 결과 (핵심 이슈 우선)**

- `[높음]` 새 파일 분리 방식과 접근 제어가 충돌합니다. 계획은 `snapshotView/maroonView/arrowView`를 Step 2 전환에서 직접 다루는데, 현재 이 멤버들은 `private`라 다른 파일 extension에서 접근 불가입니다.  
  참고: [proud-imagining-stardust.md:153](/Users/karl/.claude/plans/proud-imagining-stardust.md:153), [proud-imagining-stardust.md:166](/Users/karl/.claude/plans/proud-imagining-stardust.md:166), [proud-imagining-stardust.md:280](/Users/karl/.claude/plans/proud-imagining-stardust.md:280), [CoachMarkOverlayView.swift:211](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView.swift:211), [CoachMarkOverlayView.swift:214](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView.swift:214), [CoachMarkOverlayView.swift:287](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView.swift:287)

- `[중간]` `animateHighlightExpansion()` 설계는 방향은 맞지만, 시작 path를 model layer에 먼저 반영하는 단계가 빠져 있습니다. 현재 C/D 구현은 `dimLayer.path = startPath`를 먼저 세팅하고 애니메이션을 붙입니다. 이게 없으면 특정 타이밍에서 점프가 날 수 있습니다.  
  참고: [proud-imagining-stardust.md:240](/Users/karl/.claude/plans/proud-imagining-stardust.md:240), [CoachMarkOverlayView+CoachMarkC.swift:452](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+CoachMarkC.swift:452), [CoachMarkOverlayView+CoachMarkD.swift:336](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+CoachMarkD.swift:336)

- `[중간]` “`show()` 페이드인(0.3s) 전에 버튼 텍스트가 항상 적용된다”는 보장은 약합니다. 현재 계획 코드는 9셀 스냅샷 캡처 후에 `aCurrentStep`/버튼 텍스트를 설정하므로, 메인 스레드 부하 시 순간적으로 `"확인"`이 보일 여지가 있습니다.  
  참고: [proud-imagining-stardust.md:88](/Users/karl/.claude/plans/proud-imagining-stardust.md:88), [proud-imagining-stardust.md:94](/Users/karl/.claude/plans/proud-imagining-stardust.md:94), [proud-imagining-stardust.md:106](/Users/karl/.claude/plans/proud-imagining-stardust.md:106)

- `[중간]` Edge case 범위가 충분하지 않습니다. 문서는 5열 호환을 강조하지만, 실제 앱은 1/3/5열을 지원합니다. 1열에서는 “가로 3셀” 데모 자체가 성립하지 않으므로 명시적 폴백 가드가 필요합니다.  
  참고: [proud-imagining-stardust.md:312](/Users/karl/.claude/plans/proud-imagining-stardust.md:312), [GridColumnCount.swift:12](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridColumnCount.swift:12)

- `[중간]` 소형 기기 대응이 “9셀 rect가 safeArea 안”으로만 정의되어 있는데, 실제 잘림은 메시지/버튼에서 더 자주 발생합니다(현재 레이아웃은 `highlightFrame.maxY` 기준 고정 오프셋). 버튼 하단 안전영역 검증이 추가되어야 합니다.  
  참고: [proud-imagining-stardust.md:43](/Users/karl/.claude/plans/proud-imagining-stardust.md:43), [CoachMarkOverlayView.swift:439](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView.swift:439), [CoachMarkOverlayView.swift:449](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView.swift:449)

- `[낮음]` Associated Object 패턴 자체는 이 코드베이스에서 이미 광범위하게 사용 중이라 선택은 적절합니다. 다만 키 선언 방식(고유 주소), 정책(`RETAIN_NONATOMIC`/클로저는 `COPY_NONATOMIC`)을 계획서에 명시해두면 구현 오차를 줄일 수 있습니다.  
  참고: [CoachMarkOverlayView+CoachMarkC3.swift:22](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+CoachMarkC3.swift:22), [CoachMarkOverlayView+CoachMarkC3.swift:41](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/CoachMarkOverlayView+CoachMarkC3.swift:41)

**질문하신 5개 포인트 요약**

1. UIKit 타이밍/시퀀싱: 큰 흐름은 일관적이지만, 전환 직전 기존 애니메이션 정지/초기화 명세가 약합니다.  
2. `CABasicAnimation` path 확장/수축: 기술적으로 가능하고 현재 C/D 패턴과도 일치. 다만 시작 path 동기화 보강이 필요.  
3. Associated Object: 적절함(현 프로젝트 컨벤션과 일치).  
4. Replay Variant/A-1 호환성: 분기 순서(`onConfirm` 우선) 아이디어는 맞고 호환성 방향도 맞음.  
5. Edge case: 문서 기준으로는 아직 부족(1열, 버튼 잘림, 런타임 Reduce Motion 변경 대응).

**결론**
현재 계획은 “구현 방향”은 좋지만, 그대로는 컴파일/동작 리스크가 남아 있어 “목표 달성에 충분”하다고 보기 어렵습니다. 위 1~5 항목을 계획서에 먼저 반영하면 안정적으로 구현 가능합니다.

참고 자료:
- Apple `objc_setAssociatedObject` 문서: https://developer.apple.com/documentation/objectivec/1418956-objc_setassociatedobject  
- Apple Reduce Motion 변경 알림 문서: https://developer.apple.com/documentation/uikit/uiaccessibility/reducemotionstatusdidchangenotification