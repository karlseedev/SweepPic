**Findings**

1. High: `[confirm-claim](/Users/karl/.claude/plans/reflective-gathering-pascal.md#L29)` 설계만으로는 “실제 리딤/구매 확인 후만 완료 처리”를 강하게 보장하지 못합니다. 현재 문서는 `[user_id, reward_id]`만 보내서 완료 처리하는 구조인데, 그 앞단 확인도 `[currentEntitlements 스캔](/Users/karl/.claude/plans/reflective-gathering-pascal.md#L98)` 결과 하나에 의존합니다. 이러면 신뢰 경계가 클라이언트에 그대로 남습니다. 최소한 `transactionId`, `originalTransactionId`, `productId`, `offerId`, `purchaseDate`를 함께 보내고 서버에 저장해야 합니다. 강하게 하려면 App Store Server API/JWS 검증까지 가야 합니다.

2. High: `[포그라운드 복귀 후 2초 대기 + currentEntitlements 1회 스캔](/Users/karl/.claude/plans/reflective-gathering-pascal.md#L88)`은 Apple 권장 패턴과 맞지 않습니다. Apple은 Offer Code의 App Store/redeem URL 흐름을 “external transaction”으로 설명하고, 앱 런치 시 transaction observer 초기화를 권장합니다. 즉 “2초 안에 반영된다”는 보장이 없습니다. 이 계획은 `취소는 잡고, 늦게 반영되는 성공은 놓칠` 수 있습니다.

3. High: `[claimed 상태 재호출 시 이미 할당된 데이터 반환](/Users/karl/.claude/plans/reflective-gathering-pascal.md#L27)`은 Promotional Offer에는 그대로 적용하면 안 됩니다. Apple은 promotional signature의 `nonce`를 거래 고유성/재전송 방지용으로 설명하고, `timestamp`는 24시간 이내만 유효하다고 설명합니다. 따라서 `기존 서명 재사용`은 안전한 재시도 전략이 아닙니다. 이 부분은 Offer Code와 Promotional을 분리해서 적어야 합니다.

4. Medium: `claimed`를 도입하면 만료 처리도 같이 바꿔야 하는데 그 항목이 빠져 있습니다. 현재 서버는 `[pending만 expired 처리](/Users/karl/Project/Photos/iOS/supabase/functions/referral-api/index.ts#L651)`합니다. 계획대로면 `claimed` 보상은 영원히 남을 수 있습니다. `get-pending-rewards`와 `confirm-claim` 모두 `claimed` 만료를 고려해야 합니다.

5. Medium: Offer Code 재시도 경로에 `코드 만료 후 재할당` 로직이 없습니다. 문서는 `[claimed면 기존 코드 반환](/Users/karl/.claude/plans/reflective-gathering-pascal.md#L27)`으로 끝나는데, 현재 피초대자 흐름은 이미 `[할당된 코드가 만료되면 새 코드 재할당](/Users/karl/Project/Photos/iOS/supabase/functions/referral-api/index.ts#L459)`을 합니다. 초대자 보상도 같은 처리가 필요합니다.

6. Medium: `[앱 크래시/종료](/Users/karl/.claude/plans/reflective-gathering-pascal.md#L131)`와 `[confirm-claim 네트워크 실패](/Users/karl/.claude/plans/reflective-gathering-pascal.md#L132)` 복구 시나리오가 실제로는 비어 있습니다. `rewardId`는 `[waitingForReturn(rewardId)](/Users/karl/.claude/plans/reflective-gathering-pascal.md#L73)` 메모리 상태에만 있고, 다음 실행 시 어떤 거래가 어떤 `reward_id`를 만족했는지 복원하는 설계가 없습니다. 특히 Promotional은 성공 후 앱이 죽으면 재확인할 키가 없습니다. `appAccountToken` 같은 상관관계 키를 써야 합니다.

7. Medium: 현재 계획의 `OfferRedemptionService` 접두사 수정은 타당합니다. 지금 구현은 `[referral_](/Users/karl/Project/Photos/iOS/Sources/AppCore/Services/OfferRedemptionService.swift#L37)`라서 초대자 보상 `referral_reward_01`도 잡아버릴 수 있고, 문서의 `[referral_invited_](/Users/karl/.claude/plans/reflective-gathering-pascal.md#L64)` 변경은 맞는 수정입니다.

**StoreKit 검증**

- `Transaction.currentEntitlements` 타이밍:
  Apple은 `currentEntitlement`가 “immediate status”를 빠르게 얻는 방법이라고 설명하지만, Offer Code 외부 리딤 후 `N초 내 반영` 같은 SLA는 찾지 못했습니다. 반대로 Apple은 외부 Offer Code 리딤은 앱 런치 시 observer를 초기화해 놓으라고 권장합니다. 제 판단은 `2초 1회 스캔`은 근거가 약합니다.

- Offer Code 리딤 후 반영 시점:
  Apple 문서/영상 기준으로 `presentCodeRedemptionSheet`는 앱 foreground 내 흐름이고, App Store/redeem URL은 external transaction입니다. 후자는 “customer launches your app” 시점에 앱이 fulfill해야 한다고 설명합니다. 즉 즉시 반영을 가정하지 말고, 런치 시 observer + 재동기화가 기준입니다.

- Promotional Offer 서명 재사용:
  Apple이 “재사용 가능”이라고 명시한 자료는 찾지 못했습니다. 오히려 `nonce`는 replay 방지, `timestamp`는 24시간 제한으로 설명합니다. 제 결론은 `서명은 시도마다 새로 발급`이 안전한 설계입니다. 이건 문서에서 직접 금지문을 찾았다기보다 Apple 설명으로부터의 합리적 추론입니다.

**결론**

계획의 방향 자체는 맞습니다. 특히 `claim-reward`와 `confirm-claim` 분리, `referral_invited_` 접두사 분리는 유효합니다. 다만 지금 문서만으로는 목표를 완전히 달성하기에 부족합니다. 핵심 보완점은 `launch-time reconciliation`, `claimed 만료 처리`, `Offer Code 만료 후 재할당`, `transaction metadata/appAccountToken 기반 confirm`입니다. 이 네 가지를 넣어야 실제 운영에서 덜 흔들립니다.

검증에 사용한 Apple 자료:
- https://developer.apple.com/videos/play/tech-talks/10868/
- https://developer.apple.com/videos/play/tech-talks/10887/
- https://developer.apple.com/videos/play/wwdc2019/305/
- https://developer.apple.com/documentation/storekit/product/purchase(options:)
- https://developer.apple.com/documentation/storekit/product/purchaseoption

원하면 다음 단계로 이 계획을 바로 실행 가능한 수정안 형태로 다시 써드리겠습니다.