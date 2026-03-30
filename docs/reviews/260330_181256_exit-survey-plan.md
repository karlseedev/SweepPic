**Findings**

1. `status(for:)` 버그 수정은 방향은 맞지만, 지금 계획만으로는 아직 불완전합니다. 현재 코드의 핵심 문제는 product ID가 아니라 “그룹 상태 배열에서 첫 원소를 그냥 반환”하는 구조입니다. `Product.SubscriptionInfo.status(for:)`는 group 기준 상태 배열을 돌려주므로, `transaction`에 대응하는 status를 매칭해야 합니다. 그렇지 않으면 `willAutoRenew`나 결제 문제를 다른 상태에서 읽어 Exit Survey 조건을 잘못 판단할 수 있습니다. 이건 기존 배지 로직에도 이미 영향을 줍니다. [`SubscriptionStore.swift:299`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Monetization/Subscription/SubscriptionStore.swift#L299) [`SubscriptionStore.swift:316`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Monetization/Subscription/SubscriptionStore.swift#L316) Apple SDK 시그니처상 `status(for:)`는 `groupID`를 받고, `Transaction.subscriptionStatus`는 내부적으로 `subscriptionGroupID`와 `originalID`를 매칭합니다. 따라서 수동 배열 순회보다 `await transaction.subscriptionStatus`를 쓰는 쪽이 안전합니다. [`arm64e-apple-ios.swiftinterface:2333`](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.0.sdk/System/Library/Frameworks/StoreKit.framework/Modules/StoreKit.swiftmodule/arm64e-apple-ios.swiftinterface#L2333) [`arm64e-apple-ios.swiftinterface:1490`](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.0.sdk/System/Library/Frameworks/StoreKit.framework/Modules/StoreKit.swiftmodule/arm64e-apple-ios.swiftinterface#L1490)

2. 스펙의 “로컬 + 분석 서비스” 요구가 계획에 빠져 있습니다. 현재 계획상 제출 시 하는 일은 `trackCancelReason()` 호출뿐인데, 그건 분석 전송이지 로컬 기록이 아닙니다. 최소한 `UserDefaults`든 별도 store든 “설문 제출 여부/시점/선택 사유”를 남기는 설계가 있어야 스펙을 충족합니다. 자유입력 텍스트까지 로컬 저장할지는 개인정보 관점에서 별도 결정이 필요합니다. [`spec.md:257`](/Users/karl/Project/Photos/iOS/specs/003-bm-monetization/spec.md#L257) [`AnalyticsService+Monetization.swift:134`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Analytics/AnalyticsService+Monetization.swift#L134)

3. `SceneDelegate`에 바로 붙이면 표시 경쟁과 중복 실행 위험이 있습니다. 이미 `sceneDidBecomeActive`에는 ATT 프롬프트 표시 로직이 있고, `sceneWillEnterForeground`에는 별도의 구독 갱신이 있습니다. Exit Survey를 여기에 추가하면 “포그라운드 진입 refresh”와 “active 시점 survey 판단”이 중복/경합할 수 있고, 다른 모달이 떠 있으면 설문이 조용히 실패할 수 있습니다. 적어도 `pendingCancelCheck` 처리 전용 헬퍼, `isCheckingCancelSurvey` 같은 재진입 방지, `presentedViewController == nil` 체크, 표시 불가 시 다음 active로 defer하는 규칙이 필요합니다. [`SceneDelegate.swift:255`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/App/SceneDelegate.swift#L255) [`SceneDelegate.swift:295`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/App/SceneDelegate.swift#L295) [`SceneDelegate.swift:485`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/App/SceneDelegate.swift#L485)

4. “복귀 후 1회 refresh하고 바로 플래그 초기화”는 미탐 가능성이 있습니다. 현재 `checkAutoRenewStatus`는 조회 실패 시 `true`를 기본값으로 돌려주고, 계획은 첫 복귀 시점의 단발성 비교에 의존합니다. StoreKit 반영 지연이나 조회 실패가 있으면 실제로는 해지했는데 설문이 안 뜨고, 플래그를 지워버리면 영영 놓칩니다. 최소한 “성공적으로 상태를 읽었을 때만 플래그 소거” 또는 짧은 TTL 내 재시도 정책이 필요합니다. 가능하면 pending 상태 동안 `Product.SubscriptionInfo.Status.updates`를 보조로 듣는 것도 방법입니다. [`SubscriptionStore.swift:300`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Monetization/Subscription/SubscriptionStore.swift#L300) [`arm64e-apple-ios.swiftinterface:2356`](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.0.sdk/System/Library/Frameworks/StoreKit.framework/Modules/StoreKit.swiftmodule/arm64e-apple-ios.swiftinterface#L2356)

**Open Questions**

- URL 방식은 Apple 문서상 허용됩니다. 다만 스펙 문구가 “시트”에 가깝다면 `AppStore.showManageSubscriptions(in:)`가 더 맞습니다. 현재 계획은 URL을 쓰므로, 제약사항 4의 “await가 시트 dismissal까지 보장되지 않는다”는 논점이 실제 구현에는 직접 적용되진 않습니다. [`PremiumMenuViewController.swift:120`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Monetization/Menu/PremiumMenuViewController.swift#L120)
- `기타`를 선택했을 때 빈 텍스트 제출을 허용할지 명시가 필요합니다. 보통은 비어 있으면 제출 비활성화가 낫습니다.
- 테스트 계획이 없습니다. 이건 실제 해지 플로우가 자동화 어려운 대신, 적어도 “전/후 상태 비교 로직”, “pending flag 상태기계”, “already canceled 상태에서 재진입 시 no-op” 정도는 단위 테스트로 분리하는 게 좋습니다.

**판정**

계획의 큰 방향은 맞습니다. 다만 그대로 구현하면 목표를 “대체로” 달성할 수는 있어도, 스펙 충족과 정확도 면에서는 아직 부족합니다. 특히 `groupID로 바꾸기만 하면 된다`는 부분은 틀렸고, 로컬 기록 설계와 lifecycle 조정이 추가되어야 합니다.

**Sources**

- Apple: https://developer.apple.com/documentation/storekit/handling-subscriptions-billing
- Apple: https://developer.apple.com/documentation/StoreKit/AppStore/showManageSubscriptions%28in%3A%29?changes=_5