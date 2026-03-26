**주요 이슈 (심각도 순)**
1. `High` 무료체험 노출 로직이 “개인별 자격(eligibility)”을 고려하지 않습니다.  
[계획서: Phase 7](/Users/karl/.claude/plans/goofy-spinning-porcupine.md:223), [PaywallViewModel.freeTrialText](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Monetization/Subscription/PaywallViewModel.swift:98) 기준으로는 상품에 `introductoryOffer`가 있으면 누구에게나 “무료체험” 문구가 보일 수 있습니다.  
Apple 문서상 Intro Offer는 “신규 구독자 대상”이며, 구독 그룹당 1회 제한입니다. 기존/이탈 유저 마이그레이션에서 오해 소지가 큽니다.

2. `High` ATT 2시간 조건이 `GracePeriod.installDate`에 의존하는 설계는 취약합니다.  
[계획서: ATT 변경안](/Users/karl/.claude/plans/goofy-spinning-porcupine.md:173), [GracePeriodService.installDate 기록 위치](/Users/karl/Project/Photos/iOS/Sources/AppCore/Services/GracePeriodService.swift:119) 기준으로, GracePeriod 참조를 더 줄이면 installDate가 안정적으로 세팅되지 않을 수 있습니다.  
또 [SceneDelegate](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/App/SceneDelegate.swift:295)에서 구독 상태 갱신은 비동기라, ATT 체크 시점에 `isPlusUser`가 아직 `false`일 레이스도 있습니다(1회성 권한 UX에서 리스크 큼).

3. `High` Paywall 콜백 설계에 “중복 호출 방지”가 빠져 있습니다.  
[계획서: close + presentationControllerDidDismiss 동시 도입](/Users/karl/.claude/plans/goofy-spinning-porcupine.md:101) 구조는 동일 dismissal에 대해 `onDismissedWithoutSubscription`가 2번 호출될 가능성이 있습니다(환경별 동작 차이 포함).  
반드시 outcome을 `once`로 보내는 가드(`didSendOutcome`)가 필요합니다.

4. `Medium` Grace Period 참조 정리는 “완전”하지 않습니다.  
실행 코드 기준으로 [ReviewService](/Users/karl/Project/Photos/iOS/Sources/AppCore/Services/ReviewService.swift:200), [GracePeriodBanner 관련 코드](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Albums/TrashAlbumViewController+Gate.swift:117), [SceneDelegate Grace analytics](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/App/SceneDelegate.swift:474) 등 잔존점이 있습니다.  
계획서의 Phase 5만으로는 기능 제거/비활성화는 가능하지만 “참조 정리 완료”라고 보긴 어렵습니다.

5. `Medium` 기존 사용자 마이그레이션 정책이 명시되어 있지 않습니다.  
[첫 페이월 1회 강제 노출](/Users/karl/.claude/plans/goofy-spinning-porcupine.md:63)은 기존 free 사용자 전체에도 적용됩니다. 의도라면 문제 없지만, 의도가 아니라면 릴리즈 기준 버전/설치일 기반 예외 처리 정의가 필요합니다.

**요청한 5개 항목 답변**
1. TrashGateCoordinator 첫 페이월 로직: 방향은 맞습니다(Plus 체크 직후, 한도 체크 전). 다만 `hasSeenFirstPaywall` 세팅 시점/중복 진입 방지/기존 유저 정책이 보강돼야 안전합니다.  
2. PaywallViewController 콜백 누락: 있습니다. 특히 dismissal 중복 콜백 방지, delegate 연결 시점 안정화, 콜백 1회 보장이 필요합니다.  
3. Grace Period 참조 정리 완전성: 현재 계획만으로는 불완전합니다(잔존 런타임 참조 다수).  
4. ATT 2시간 변경 적절성: “정책 위반”은 아니지만(추론), 현재 설계는 데이터 소스/레이스 리스크가 큽니다. 고정 2시간보다 “첫 광고 직전/첫 게이트 이후” 이벤트 기반이 실무적으로 더 안전합니다(추론).  
5. 기존 사용자 마이그레이션: Intro Offer 자격/기존 free 노출 정책/기존 구독 이력자 처리(프로모션 오퍼) 관점에서 보완 필요합니다.

**참고한 외부 자료**
- Apple App Store Connect: Intro offer 설정/자격(신규 구독자, 그룹당 1회)  
https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions
- Apple 지원 문서: 무료 체험은 보통 사용자/그룹 기준 제한  
https://support.apple.com/en-ng/guide/iphone/iph4e3e7324f/ios
- Apple App Store Subscriptions 개요  
https://developer.apple.com/app-store/subscriptions/
- Apple App Store Connect: 기존/이탈 구독자 대상은 Promotional Offer 사용  
https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-promotional-offers-for-auto-renewable-subscriptions
- Apple ATT API 문서 (`requestTrackingAuthorization`)  
https://developer.apple.com/documentation/apptrackingtransparency/attrackingmanager/requesttrackingauthorization(completionhandler:)