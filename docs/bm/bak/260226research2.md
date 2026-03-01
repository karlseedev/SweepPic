# 5. StoreKit 2 결제 실패 처리 및 구독 SDK 비교

---

## 1. StoreKit 2 결제 실패 시나리오 및 처리 방법

### 1.1 PurchaseResult 3가지 케이스

StoreKit 2에서는 `Product.purchase()` 호출 시 `Product.PurchaseResult`가 반환되며, 3가지 케이스가 있습니다.

```swift
@MainActor
func purchase(_ product: Product) async throws {
    let result = try await product.purchase()
    
    switch result {
    case .success(let verificationResult):
        // 검증 결과 처리
        switch verificationResult {
        case .verified(let transaction):
            // 정상 거래 — 콘텐츠 제공 후 finish 호출
            await deliverContent(for: transaction)
            await transaction.finish()
            
        case .unverified(let transaction, let error):
            // 검증 실패 — 탈옥 기기 또는 변조 의심
            // 사용자에게 알리거나 서버 측 재검증 시도
            Log.print("[Purchase] Unverified transaction: \(error)")
            // 보수적 접근: 콘텐츠 제공하지 않음
        }
        
    case .userCancelled:
        // 사용자가 취소 — 에러 메시지를 보여주지 않는 것이 베스트 프랙티스
        // 단순히 이전 UI 상태로 복원
        break
        
    case .pending:
        // Ask to Buy (자녀 보호) 또는 SCA(Strong Customer Auth) 대기
        // Transaction.updates에서 추후 결과 수신
        showPendingMessage()
    
    @unknown default:
        break
    }
}
```

### 1.2 주요 에러 타입별 처리

| 에러 | 원인 | 처리 방법 |
|------|------|----------|
| `Product.PurchaseError.productUnavailable` | 제품이 해당 스토어에서 미판매 | 제품 목록 새로고침, UI에서 제품 숨김 |
| `Product.PurchaseError.purchaseNotAllowed` | 기기 설정에서 구매 비활성화 | "설정 > 화면 시간 확인" 안내 |
| `Product.PurchaseError.invalidQuantity` | 수량 오류 (소비형) | 수량 > 0 보장 |
| `StoreKitError.notAvailableInStorefront` | 지역 제한 | 해당 제품 숨김 또는 이용 불가 메시지 |
| `StoreKitError.networkError` | 네트워크 문제 | 재시도 UI 제공 |
| `StoreKitError.systemError` | iOS 시스템 오류 | 재시도 안내, 로그 기록 |
| `StoreKitError.notEntitled` | 자격 없음 | 구독 상태 재확인 |

### 1.3 에러 처리 패턴

```swift
func purchase(_ product: Product) async {
    do {
        let result = try await product.purchase()
        handlePurchaseResult(result)
    } catch Product.PurchaseError.productUnavailable {
        showAlert("해당 상품은 현재 이용할 수 없습니다.")
    } catch Product.PurchaseError.purchaseNotAllowed {
        showAlert("구매가 허용되지 않았습니다. 기기 설정을 확인해주세요.")
    } catch StoreKitError.notAvailableInStorefront {
        showAlert("현재 지역에서는 이용할 수 없는 상품입니다.")
    } catch StoreKitError.networkError(_) {
        showRetryAlert("네트워크 연결을 확인하고 다시 시도해주세요.")
    } catch {
        // 알 수 없는 에러 — 로그 기록 후 일반 메시지
        Log.print("[Purchase] Unknown error: \(error)")
        showAlert("구매 처리 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.")
    }
}
```

---

## 2. Billing Grace Period (결제 유예 기간)

### 2.1 작동 방식

- 구독 자동 갱신이 **결제 수단 문제**로 실패할 때, Apple이 결제를 재시도하는 동안 사용자가 계속 프리미엄 기능을 사용할 수 있는 기간
- Grace Period 동안 결제가 성공하면 **유료 서비스 일수 및 개발자 수익에 중단이 없음**
- Grace Period 종료 후에도 Apple은 최대 **60일간** Billing Retry를 계속함

### 2.2 설정 방법

**App Store Connect에서 설정:**
1. Apps > 앱 선택 > Subscriptions (사이드바)
2. "Set Up Billing Grace Period" 클릭
3. 기간 선택: **3일, 16일, 28일** (주간 구독은 최대 6일)
4. 적용 범위: 모든 갱신 / 유료->유료 갱신만
5. 환경: Sandbox만 / 프로덕션+Sandbox

### 2.3 코드에서 Grace Period 상태 감지

```swift
func checkSubscriptionStatus() async {
    guard let statuses = try? await Product.SubscriptionInfo
        .status(for: "your_subscription_group_id") else { return }
    
    for status in statuses {
        guard case .verified(let renewalInfo) = status.renewalInfo,
              case .verified(let transaction) = status.transaction else {
            continue
        }
        
        switch status.state {
        case .subscribed:
            // 정상 구독 중
            grantAccess()
            
        case .inGracePeriod:
            // Grace Period 중 — 접근 유지하되 결제 수단 업데이트 안내
            grantAccess()
            showPaymentUpdateBanner()
            
        case .inBillingRetryPeriod:
            // Grace Period 끝남, Billing Retry 중
            // 접근 차단이 일반적이나 정책에 따라 결정
            revokeAccess()
            showSubscriptionExpiredMessage()
            
        case .expired:
            revokeAccess()
            
        case .revoked:
            revokeAccess()
            
        default:
            break
        }
    }
}
```

### 2.4 실제 영향

- Apple 공식 통계: Billing Grace Period 활성화 앱에서 **약 8,000만 건의 비자발적 이탈 구독이 복구됨**
- Grace Period 활성화 시 **15~20% 더 많은 구독 복구** 가능
- **비자발적 이탈(involuntary churn)은 전체 구독 결제 시도의 최대 20%** 차지
- **반드시 활성화해야 하는 기능** -- 무료이며, 개발자에게 손해가 없음

---

## 3. 결제 상태 폴링/재시도 전략

### 3.1 Pending 상태 처리

```swift
// Pending 상태는 직접 폴링하지 않음
// Transaction.updates 스트림을 통해 비동기 수신
class SubscriptionManager {
    private var updateListenerTask: Task<Void, Error>?
    
    func startListening() {
        updateListenerTask = Task.detached {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await self.handleVerifiedTransaction(transaction)
                    await transaction.finish()
                case .unverified(_, let error):
                    Log.print("[Transaction] Unverified update: \(error)")
                }
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
}
```

### 3.2 앱 시작 시 상태 동기화

```swift
// 앱 시작 시 3가지 작업을 수행
func onAppLaunch() async {
    // 1. Transaction.updates 리스닝 시작
    startListening()
    
    // 2. 미완료 트랜잭션 처리
    for await result in Transaction.unfinished {
        if case .verified(let transaction) = result {
            await handleVerifiedTransaction(transaction)
            await transaction.finish()
        }
    }
    
    // 3. 현재 구독 상태 확인
    await updateSubscriptionStatus()
}
```

### 3.3 네트워크 에러 시 재시도

```swift
func purchaseWithRetry(_ product: Product, maxRetries: Int = 2) async {
    var attempts = 0
    while attempts <= maxRetries {
        do {
            let result = try await product.purchase()
            handlePurchaseResult(result)
            return
        } catch StoreKitError.networkError(_) {
            attempts += 1
            if attempts <= maxRetries {
                // 지수 백오프
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts))) * 1_000_000_000)
            } else {
                showAlert("네트워크 연결을 확인해주세요.")
            }
        } catch {
            showAlert("구매 처리 중 문제가 발생했습니다.")
            return
        }
    }
}
```

---

## 4. StoreKit 2 vs RevenueCat 비교

### 4.1 기능 비교표

| 항목 | StoreKit 2 (네이티브) | RevenueCat |
|------|----------------------|------------|
| **초기 비용** | 무료 | 무료 (MTR $2,500 미만) |
| **구현 난이도** | 중~상 (약 80시간 소요) | 하~중 (빠른 통합) |
| **서버 필요** | 선택적 (클라이언트만으로 가능) | 불필요 (RevenueCat 서버 사용) |
| **크로스 플랫폼** | iOS/macOS만 | iOS, Android, Web, Flutter, RN |
| **대시보드/분석** | App Store Connect 기본 제공 | 상세 분석, 코호트, A/B 테스트 |
| **페이월 테스트** | 직접 구현 | Remote Config으로 서버 측 변경 |
| **결제 복구** | 직접 구현 | 자동 처리 |
| **영수증 검증** | 클라이언트 측 자동 (JWS) | 서버 측 자동 |
| **Family Sharing** | 직접 구현 | SDK에서 지원 |
| **Offer 관리** | App Store Connect | 대시보드에서 관리 |
| **의존성** | 없음 (Apple 프레임워크) | 서드파티 SDK 의존 |
| **iOS 최소 버전** | iOS 15+ | iOS 13+ (SK1 폴백) |

### 4.2 아키텍처 차이

```
[StoreKit 2 네이티브]
앱 → StoreKit 2 API → App Store 서버
                    ↗ (선택) 자체 서버 → App Store Server API

[RevenueCat]
앱 → RevenueCat SDK → RevenueCat 서버 → App Store 서버
                       ↓
                  대시보드/분석/웹훅
```

---

## 5. RevenueCat이 비용 대비 가치 있는 경우

### 5.1 RevenueCat 가격 구조

| 구간 | 비용 |
|------|------|
| MTR < $2,500/월 | **무료** (핵심 기능 전체 이용) |
| MTR >= $2,500/월 | **MTR의 1%** (예: MTR $10,000 → $100/월) |
| Pro 플랜 | 별도 협의 (고급 분석, 전담 지원) |

### 5.2 RevenueCat 추천 상황

**RevenueCat이 적합한 경우:**
- Android 앱도 있거나 계획 중인 경우
- 페이월 A/B 테스트가 필요한 경우
- 구독 분석/코호트 분석이 중요한 경우
- 서버 인프라가 없는 소규모 팀
- 빠른 출시가 우선인 경우

**네이티브 StoreKit 2가 적합한 경우:**
- **iOS 전용, 단일 상품 구독 앱** (PIClear 같은 경우)
- 서드파티 의존성을 최소화하고 싶은 경우
- App Store Connect의 기본 분석으로 충분한 경우
- 개발자가 StoreKit에 대한 이해가 있는 경우
- 장기적으로 외부 서비스 비용을 줄이고 싶은 경우

### 5.3 PIClear에 대한 구체적 권장

**네이티브 StoreKit 2를 권장합니다.** 이유:

1. **iOS 전용 앱** -- 크로스 플랫폼 지원 불필요
2. **단일 상품 구독** -- 복잡한 오퍼링 관리 불필요
3. **비용 절감** -- MTR $2,500 넘어가면 매월 비용 발생
4. **의존성 최소화** -- Apple 프레임워크만 사용하여 장기 안정성 확보
5. **StoreKit 2의 충분한 성숙도** -- iOS 15+부터 지원, 현재 매우 안정적
6. **서버 불필요** -- 클라이언트 측 JWS 검증으로 충분

---

## 6. 구독 복원 및 Family Sharing 처리

### 6.1 구독 복원

StoreKit 2에서는 `Transaction.currentEntitlements`가 자동으로 현재 Apple ID의 활성 구독을 반환하므로, 기존 StoreKit 1의 수동 복원이 사실상 불필요합니다.

```swift
// 프로액티브 복원 — 앱 시작 시 자동 확인
func updateSubscriptionStatus() async {
    var hasActiveSubscription = false
    
    for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result {
            if transaction.productID == "com.pickphoto.premium" {
                // 구독 만료 여부 확인
                if let expirationDate = transaction.expirationDate,
                   expirationDate > Date() {
                    hasActiveSubscription = true
                }
            }
        }
    }
    
    await MainActor.run {
        self.isPremium = hasActiveSubscription
    }
}

// "구매 복원" 버튼 — App Review 가이드라인 준수용
// Apple은 여전히 복원 버튼 제공을 권장
func restorePurchases() async {
    try? await AppStore.sync()
    await updateSubscriptionStatus()
}
```

### 6.2 Family Sharing 처리

```swift
func checkFamilySharing() async {
    guard let statuses = try? await Product.SubscriptionInfo
        .status(for: "premium_group") else { return }
    
    // Family Sharing 시 여러 status가 반환될 수 있음
    for status in statuses {
        guard case .verified(let transaction) = status.transaction else {
            continue
        }
        
        // ownershipType으로 개인 구매 vs 가족 공유 구분
        if transaction.ownershipType == .familyShared {
            Log.print("[Subscription] Family shared subscription detected")
        } else if transaction.ownershipType == .purchased {
            Log.print("[Subscription] Personally purchased subscription")
        }
        
        // 가족 공유든 개인 구매든 접근 권한 부여
        if status.state == .subscribed || status.state == .inGracePeriod {
            grantAccess()
            return
        }
    }
}
```

**Family Sharing 주의 사항:**
- App Store Connect에서 구독 상품에 Family Sharing을 활성화해야 함
- 가족 구성원이 각각 독립적으로 구독 상태를 가질 수 있음
- `status` 배열에 여러 항목이 올 수 있으므로 **첫 번째만 확인하면 안 됨**
- `appTransactionID`가 가족 구성원별로 고유하여 추적에 활용 가능

---

## 7. Transaction Listener 베스트 프랙티스

### 7.1 완전한 구현 패턴

```swift
@MainActor
final class StoreManager: ObservableObject {
    @Published var isPremium = false
    @Published var purchaseState: PurchaseState = .idle
    
    private var updateListenerTask: Task<Void, Error>?
    
    enum PurchaseState {
        case idle, purchasing, pending, completed, failed(String)
    }
    
    init() {
        // 앱 시작 시 즉시 리스닝 시작 — 절대 늦추지 말 것
        updateListenerTask = listenForTransactions()
        
        Task {
            await updateSubscriptionStatus()
        }
    }
    
    // Detached Task로 실행 — MainActor 밖에서 실행
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Transaction.updates는 무한 AsyncSequence
            // 앱 시작 시 미완료 트랜잭션도 즉시 수신
            for await result in Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(
        _ result: VerificationResult<Transaction>
    ) async {
        switch result {
        case .verified(let transaction):
            Log.print("[StoreManager] Verified transaction: \(transaction.productID)")
            
            // 콘텐츠 전달
            await deliverContent(for: transaction)
            
            // 반드시 finish 호출 — 안 하면 계속 재전달됨
            await transaction.finish()
            
            // UI 상태 업데이트
            await updateSubscriptionStatus()
            
        case .unverified(let transaction, let error):
            Log.print("[StoreManager] Unverified: \(error.localizedDescription)")
            // 보안 정책에 따라 처리
            // 절대 콘텐츠를 제공하지 않음
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
}
```

### 7.2 핵심 원칙

1. **앱 시작 즉시 리스닝 시작** -- `AppDelegate` 또는 `@main` App의 `init`에서
2. **Detached Task 사용** -- `Transaction.updates`는 무한 시퀀스이므로
3. **Task 참조 보관** -- 필요 시 cancel 가능하도록
4. **항상 `transaction.finish()` 호출** -- 미호출 시 다음 앱 시작에 재전달
5. **`Transaction.updates` vs `Transaction.unfinished` 구분**
   - `updates`: 런타임 중 새 트랜잭션 + 앱 시작 시 미완료 1회 전달
   - `unfinished`: 항상 미완료 트랜잭션 전체 반환 (명시적 확인용)

---

## 8. 서버 측 영수증 검증 — StoreKit 2에서 필요한가?

### 8.1 결론: 단일 상품 구독 앱에서는 불필요

StoreKit 2는 **클라이언트 측 JWS(JSON Web Signature) 검증**이 내장되어 있어, StoreKit 1처럼 서버에 영수증을 보내 검증할 필요가 없습니다.

| 방식 | StoreKit 1 | StoreKit 2 |
|------|-----------|-----------|
| 영수증 형식 | 암호화된 바이너리 blob | JWS (JSON Web Signature) |
| 검증 방법 | 서버 → Apple `verifyReceipt` API | 클라이언트에서 자동 검증 |
| 서버 필요 | 사실상 필수 | 선택적 |
| Apple API | `verifyReceipt` (deprecated) | App Store Server API v2 |

### 8.2 서버가 필요한 경우

```
서버 측 검증이 필요한 경우:
- 웹 서비스와 구독 상태를 공유해야 할 때
- 사용자별 서버 측 기능 잠금/해제가 필요할 때
- 구독 이벤트에 대한 웹훅 처리가 필요할 때
- 크로스 플랫폼(Android+iOS) 구독 통합이 필요할 때

서버 없이 충분한 경우 (PIClear 해당):
- iOS 전용 앱
- 클라이언트에서만 프리미엄 기능 제어
- 단순한 구독 모델
```

### 8.3 서버가 필요 없을 때의 구독 확인

```swift
// 서버 없이 클라이언트에서만 구독 확인
func verifySubscription() async -> Bool {
    // Transaction.currentEntitlements — Apple이 서명한 JWS를 자동 검증
    for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result,
           transaction.productID == "com.pickphoto.premium" {
            // .verified는 Apple의 서명이 유효함을 의미
            // 추가 서버 검증 불필요
            return true
        }
    }
    return false
}
```

---

## 9. StoreKit 2 트랜잭션 실패율 (실제 데이터)

### 9.1 알려진 통계

정확한 공식 실패율은 Apple이 공개하지 않지만, 간접적으로 파악 가능한 데이터:

| 지표 | 수치 | 출처 |
|------|------|------|
| 비자발적 이탈 (involuntary churn) | **전체 구독 결제 시도의 최대 20%** | [Apple Developer Documentation](https://developer.apple.com/documentation/storekit/reducing-involuntary-subscriber-churn) |
| Grace Period로 복구된 구독 | **약 8,000만 건** (누적) | [Apple App Store Connect](https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions/) |
| Grace Period 유무 복구율 차이 | **15~20% 더 높은 복구율** | [Adapty Blog](https://adapty.io/blog/how-to-handle-apple-billing-grace-period/) |
| Billing Retry 기간 | **최대 60일** | Apple 공식 |
| Grace Period 복구 유료 서비스 일수 | **3억일 이상** (누적) | [Apple Tech Talk](https://developer.apple.com/videos/play/tech-talks/111386/) |

### 9.2 2026년 1월 이슈

2026년 1월 28일 이후, iOS 17+ 기기에서 StoreKit 관련 "Unable to Complete Request" 에러가 급증하는 이슈가 보고되었습니다. 이는 국가별로 영향도가 다르며, Apple 서버 측 문제로 추정됩니다.

### 9.3 주요 실패 원인 분류

```
결제 실패 원인 (빈도순 추정):
1. 결제 수단 만료/잔액 부족    — 가장 흔함 (involuntary churn의 주원인)
2. 사용자 취소                 — 의도적 행위, 에러 아님
3. 네트워크 에러              — 일시적, 재시도로 해결
4. Ask to Buy 대기            — 가족 공유 환경에서 발생
5. 지역/스토어프론트 제한      — 상품 설정 문제
6. 시스템 에러                — Apple 서버 이슈
7. 검증 실패                  — 탈옥 기기 등 극소수
```

---

## 10. 사진 편집 앱에서의 StoreKit 2 구독 패턴

### 10.1 일반적인 사진 앱 구독 아키텍처

```swift
// 사진 편집/관리 앱의 전형적인 구독 매니저
@MainActor
final class PhotoAppSubscriptionManager: ObservableObject {
    static let shared = PhotoAppSubscriptionManager()
    
    // 구독 상품 ID
    private let premiumMonthlyID = "com.pickphoto.premium.monthly"
    private let premiumYearlyID = "com.pickphoto.premium.yearly"
    
    @Published var isPremium = false
    @Published var products: [Product] = []
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    
    enum SubscriptionStatus {
        case notSubscribed
        case subscribed(expiresAt: Date)
        case inGracePeriod(expiresAt: Date)
        case expired
    }
    
    private var updateTask: Task<Void, Error>?
    
    init() {
        updateTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateStatus() }
    }
    
    // MARK: - 상품 로딩
    
    func loadProducts() async {
        do {
            let productIDs = [premiumMonthlyID, premiumYearlyID]
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            Log.print("[Store] Failed to load products: \(error)")
        }
    }
    
    // MARK: - 구매
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await updateStatus()
                    return true
                }
                return false
                
            case .userCancelled:
                return false
                
            case .pending:
                // Ask to Buy — UI에 "보호자 승인 대기 중" 표시
                return false
                
            @unknown default:
                return false
            }
        } catch {
            Log.print("[Store] Purchase error: \(error)")
            return false
        }
    }
    
    // MARK: - 상태 확인
    
    func updateStatus() async {
        var foundActive = false
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if [premiumMonthlyID, premiumYearlyID].contains(transaction.productID) {
                if let expDate = transaction.expirationDate, expDate > Date() {
                    foundActive = true
                    
                    // Grace Period 확인
                    if let statuses = try? await Product.SubscriptionInfo
                        .status(for: "premium_group") {
                        for status in statuses {
                            if status.state == .inGracePeriod {
                                subscriptionStatus = .inGracePeriod(expiresAt: expDate)
                                break
                            }
                        }
                    }
                    
                    if case .inGracePeriod = subscriptionStatus {
                        // 이미 설정됨
                    } else {
                        subscriptionStatus = .subscribed(expiresAt: expDate)
                    }
                }
            }
        }
        
        if !foundActive {
            subscriptionStatus = .notSubscribed
        }
        
        isPremium = foundActive
    }
    
    // MARK: - 트랜잭션 리스너
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.updateStatus()
                }
            }
        }
    }
    
    // MARK: - 복원
    
    func restore() async {
        try? await AppStore.sync()
        await updateStatus()
    }
    
    deinit {
        updateTask?.cancel()
    }
}
```

### 10.2 프리미엄 기능 게이팅 패턴

```swift
// 사진 앱에서 프리미엄 기능 제한하는 일반적 패턴
extension BaseGridViewController {
    
    /// 프리미엄 기능 접근 가능 여부 확인
    var canAccessPremiumFeature: Bool {
        return PhotoAppSubscriptionManager.shared.isPremium
    }
    
    /// 프리미엄 기능 시도 시 호출
    func attemptPremiumAction(_ action: @escaping () -> Void) {
        if canAccessPremiumFeature {
            action()
        } else {
            showPaywall()
        }
    }
    
    /// Grace Period 배너 표시
    func showGracePeriodBannerIfNeeded() {
        let manager = PhotoAppSubscriptionManager.shared
        if case .inGracePeriod = manager.subscriptionStatus {
            // 상단에 "결제 수단 업데이트 필요" 배너 표시
            showPaymentUpdateBanner()
        }
    }
}
```

### 10.3 StoreKit Configuration 파일 설정 (테스트용)

Xcode에서 `PIClear.storekit` 파일을 생성하여 로컬 테스트:

```
Subscription Group: "PIClear Premium"
├── Level 1: com.pickphoto.premium.yearly  ($29.99/year)
└── Level 2: com.pickphoto.premium.monthly ($4.99/month)

테스트 시나리오:
- Fail Transactions 활성화 → 결제 실패 처리 테스트
- Ask to Buy 활성화 → Pending 상태 테스트  
- Interrupted Purchases → 중단된 구매 테스트
- Billing Grace Period 활성화 → Grace Period 흐름 테스트
```

---

## 종합 권장사항 (PIClear 기준)

| 항목 | 권장 |
|------|------|
| **결제 프레임워크** | **네이티브 StoreKit 2** (iOS 전용, 단일 구독, 의존성 최소화) |
| **서버 측 검증** | **불필요** (클라이언트 JWS 검증으로 충분) |
| **Billing Grace Period** | **반드시 활성화** (16일 권장, 무료, 복구율 15~20% 향상) |
| **Transaction Listener** | **앱 시작 즉시** Task.detached로 시작 |
| **Family Sharing** | 단일 상품이면 활성화 고려 (사용자층 확대) |
| **복원 버튼** | **필수 제공** (App Review 가이드라인) |
| **에러 처리** | 사용자 취소 시 메시지 없음, 네트워크 에러만 재시도 |
| **테스트** | StoreKit Configuration 파일 + Sandbox 계정 병행 |

---

## Sources

- [Apple StoreKit 2 Developer Documentation](https://developer.apple.com/storekit/)
- [Apple - Reducing Involuntary Subscriber Churn](https://developer.apple.com/documentation/storekit/reducing-involuntary-subscriber-churn)
- [Apple - Enable Billing Grace Period](https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions/)
- [Apple - Handling Subscriptions Billing](https://developer.apple.com/documentation/storekit/handling-subscriptions-billing)
- [Apple - Supporting Family Sharing in Your App](https://developer.apple.com/documentation/storekit/supporting-family-sharing-in-your-app)
- [Apple - Testing Failing Subscription Renewals](https://developer.apple.com/documentation/storekit/testing-failing-subscription-renewals-and-in-app-purchases)
- [Apple - Transaction.updates](https://developer.apple.com/documentation/storekit/transaction/updates)
- [Apple - Implement Proactive In-App Purchase Restore (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/110404/)
- [Apple - Improve Subscriber Retention (Tech Talk)](https://developer.apple.com/videos/play/tech-talks/111386/)
- [Apple - What's New in StoreKit (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/241/)
- [RevenueCat - StoreKit With and Without RevenueCat](https://www.revenuecat.com/blog/engineering/implementing-storekit/)
- [RevenueCat - StoreKit 2 Overview](https://www.revenuecat.com/blog/engineering/storekit-2-overview/)
- [RevenueCat - iOS Subscription Grace Periods](https://www.revenuecat.com/blog/engineering/ios-subscription-grace-periods/)
- [RevenueCat - Pricing & Plans](https://www.revenuecat.com/pricing/)
- [RevenueCat Pricing Analysis (MetaCTO)](https://www.metacto.com/blogs/the-real-cost-of-revenuecat-what-app-publishers-need-to-know)
- [Adapty - How to Handle Apple Billing Grace Period](https://adapty.io/blog/how-to-handle-apple-billing-grace-period/)
- [Adapty - SKErrorDomain Error Codes](https://adapty.io/blog/ios-skerrordomain-error-codes/)
- [Qonversion - StoreKit Errors Guide](https://qonversion.io/blog/handling-storekit-errors/)
- [Qonversion - Receipt Validation in StoreKit 1 vs 2](https://qonversion.io/blog/storekit1-storeki2-receipt-validation/)
- [Swift with Majid - Mastering StoreKit 2](https://swiftwithmajid.com/2023/08/01/mastering-storekit2/)
- [CreateWithSwift - Implementing Subscriptions with StoreKit 2](https://www.createwithswift.com/implementing-subscriptions-in-app-purchases-with-storekit-2/)
- [WWDC by Sundell - Working with In-App Purchases in StoreKit 2](https://wwdcbysundell.com/2021/working-with-in-app-purchases-in-storekit2/)

---

# 6. 자정 리셋 메커니즘 — 일일 사용 제한 리셋

## 1. 일일 제한 리셋 방식 -- 로컬 자정 vs UTC

### 로컬 자정 방식 (대부분의 소비자 앱)

대부분의 사용자 대면 앱은 **사용자의 로컬 자정**을 기준으로 리셋합니다. 사용자가 "오늘"이라고 느끼는 시간대와 앱의 "오늘"이 일치해야 자연스러운 경험을 제공하기 때문입니다.

```swift
// iOS에서 로컬 자정 기반 날짜 비교
let calendar = Calendar.current
let now = Date()

// Calendar.current는 기기의 현재 타임존을 자동으로 반영
let startOfToday = calendar.startOfDay(for: now)

if let lastResetDate = UserDefaults.standard.object(forKey: "lastResetDate") as? Date {
    if !calendar.isDate(lastResetDate, inSameDayAs: now) {
        // 새로운 날 -> 리셋 수행
        resetDailyCounter()
        UserDefaults.standard.set(now, forKey: "lastResetDate")
    }
}
```

### UTC 방식 (서버 기반 시스템)

멀티플레이어 게임이나 글로벌 이벤트 동기화가 필요한 앱은 **UTC 자정**을 기준으로 합니다. 모든 사용자에게 동일한 리셋 시점을 보장하지만, 각 사용자의 체감 리셋 시간이 다릅니다 (한국의 경우 오전 9시에 리셋).

```swift
// UTC 기준 날짜 비교
var utcCalendar = Calendar.current
utcCalendar.timeZone = TimeZone(identifier: "UTC")!

let utcStartOfToday = utcCalendar.startOfDay(for: Date())
```

### 하이브리드 방식

일부 앱은 사용자가 계정을 생성할 때의 타임존을 서버에 저장하고, 서버에서 해당 타임존의 자정을 계산하여 리셋합니다. **Duolingo**가 이 방식을 사용합니다.

---

## 2. 엣지 케이스: 타임존 변경, 여행, DST 전환

### 타임존 변경 (여행)

**Duolingo의 접근법:**
- 모바일 앱에서 활동하면 디바이스의 현재 타임존으로 **자동 업데이트**됨
- 웹에서는 타임존 변경이 불가능하여, 계정 생성 시점의 타임존이 계속 유지됨
- 동쪽으로 여행하면 하루가 짧아져 스트릭이 끊길 위험이 있음 (예: 미국에서 한국으로 이동 시)

**권장 대응 패턴:**

```swift
struct DailyLimitManager {
    /// 타임존 변경 감지 및 안전 장치
    func checkDayTransitionSafely() {
        let currentTimezone = TimeZone.current
        let savedTimezoneId = UserDefaults.standard.string(forKey: "lastTimezone") ?? ""
        
        if currentTimezone.identifier != savedTimezoneId {
            // 타임존이 변경됨 - 유예 기간 로직 적용
            handleTimezoneChange(from: savedTimezoneId, to: currentTimezone.identifier)
        }
        
        UserDefaults.standard.set(currentTimezone.identifier, forKey: "lastTimezone")
    }
    
    /// 타임존 변경 시 유예 기간을 두어 사용자 불이익 방지
    private func handleTimezoneChange(from oldTz: String, to newTz: String) {
        // 방법 1: 타임존 변경 후 첫 액세스에서는 리셋하지 않음
        // 방법 2: 이전 타임존과 현재 타임존 모두에서 "같은 날"인지 확인
        let oldTimeZone = TimeZone(identifier: oldTz)
        let newTimeZone = TimeZone(identifier: newTz)
        
        // 두 타임존 중 하나라도 "오늘"이면 카운터 유지
        var oldCalendar = Calendar.current
        oldCalendar.timeZone = oldTimeZone ?? .current
        
        var newCalendar = Calendar.current
        newCalendar.timeZone = newTimeZone ?? .current
        
        let now = Date()
        let lastDate = UserDefaults.standard.object(forKey: "lastResetDate") as? Date ?? Date.distantPast
        
        let isSameDayInOld = oldCalendar.isDate(lastDate, inSameDayAs: now)
        let isSameDayInNew = newCalendar.isDate(lastDate, inSameDayAs: now)
        
        if !isSameDayInOld && !isSameDayInNew {
            // 두 타임존 모두에서 다른 날 -> 리셋
            resetDailyCounter()
        }
        // 하나라도 같은 날이면 유지 (유예 기간)
    }
}
```

### DST (서머타임) 전환

DST 전환 시 하루가 23시간 또는 25시간이 될 수 있습니다.

**핵심 원칙:** 절대 `TimeInterval` (초 단위)로 24시간을 비교하지 않아야 합니다.

```swift
// [나쁜 예] 24시간 기반 비교 - DST에서 오류 발생
let twentyFourHours: TimeInterval = 86400
if Date().timeIntervalSince(lastDate) >= twentyFourHours {
    resetDailyCounter()  // Spring Forward 시 23시간만 지나도 리셋 안 됨
}

// [좋은 예] Calendar API 기반 비교 - DST 자동 처리
let calendar = Calendar.current
if !calendar.isDate(lastDate, inSameDayAs: Date()) {
    resetDailyCounter()  // Calendar가 DST를 자동으로 처리
}
```

**Calendar.isDate(_:inSameDayAs:)** 는 DST를 올바르게 처리합니다. 이 메서드는 시간 단위가 아닌 **달력 날짜** 단위로 비교하기 때문입니다.

---

## 3. 새로운 날 시작 감지 방법

### 방법 A: Foreground 진입 시 확인 (가장 일반적)

```swift
// UIKit 방식
class AppDelegate: UIResponder, UIApplicationDelegate {
    func applicationWillEnterForeground(_ application: UIApplication) {
        DailyLimitManager.shared.checkAndResetIfNewDay()
    }
}

// SceneDelegate 방식 (iOS 13+)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func sceneWillEnterForeground(_ scene: UIScene) {
        DailyLimitManager.shared.checkAndResetIfNewDay()
    }
}

// SwiftUI 방식
struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        MainView()
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    DailyLimitManager.shared.checkAndResetIfNewDay()
                }
            }
    }
}
```

### 방법 B: 자정 타이머

앱이 Foreground에 있는 동안 자정에 자동 리셋하는 타이머를 설정합니다.

```swift
class MidnightResetTimer {
    private var timer: Timer?
    
    func scheduleMidnightReset() {
        timer?.invalidate()
        
        let calendar = Calendar.current
        guard let midnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return }
        
        let timeInterval = midnight.timeIntervalSinceNow
        
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            DailyLimitManager.shared.resetDailyCounter()
            // 다음 자정 타이머 재설정
            self?.scheduleMidnightReset()
        }
    }
    
    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}
```

### 방법 C: Significant Time Change Notification

iOS 시스템이 자정, 타임존 변경, DST 전환 등의 유의미한 시간 변경을 알려줍니다.

```swift
// 시스템에서 자정, 타임존 변경, DST 전환 시 알림 전송
NotificationCenter.default.addObserver(
    self,
    selector: #selector(significantTimeChange),
    name: UIApplication.significantTimeChangeNotification,
    object: nil
)

@objc func significantTimeChange() {
    // 자정 전환, 타임존 변경, DST 전환 시 호출
    DailyLimitManager.shared.checkAndResetIfNewDay()
}
```

### 방법 D: Background App Refresh

```swift
// BGTaskScheduler를 사용한 백그라운드 리셋
func scheduleBackgroundReset() {
    let request = BGAppRefreshTaskRequest(identifier: "com.app.dailyReset")
    request.earliestBeginDate = nextMidnight()
    try? BGTaskScheduler.shared.submit(request)
}
```

> 단, Background App Refresh는 iOS에 의해 실행 시점이 보장되지 않으므로 보조 수단으로만 사용해야 합니다.

---

## 4. "이중 체크(Double Reset)" 로직

가장 견고한 패턴은 **두 시점 모두에서 체크**하는 것입니다.

```swift
/// 일일 제한 관리자 - 이중 체크 패턴
final class DailyLimitManager {
    static let shared = DailyLimitManager()
    
    private let defaults = UserDefaults.standard
    private let lastResetKey = "dailyLimit_lastResetDate"
    private let counterKey = "dailyLimit_counter"
    private let maxDailyLimit = 5
    
    // ============================================
    // 체크 포인트 1: Foreground 진입 시
    // ============================================
    func checkAndResetIfNewDay() {
        if isNewDay() {
            performReset()
        }
    }
    
    // ============================================
    // 체크 포인트 2: 제한 카운터 사용 시점
    // ============================================
    func canPerformAction() -> Bool {
        // 액션 수행 시점에도 날짜 확인 (이중 체크)
        if isNewDay() {
            performReset()
        }
        
        let currentCount = defaults.integer(forKey: counterKey)
        return currentCount < maxDailyLimit
    }
    
    func consumeAction() {
        // 소비 시점에서도 한번 더 확인
        if isNewDay() {
            performReset()
        }
        
        let currentCount = defaults.integer(forKey: counterKey)
        defaults.set(currentCount + 1, forKey: counterKey)
    }
    
    // ============================================
    // 핵심 날짜 비교 로직
    // ============================================
    private func isNewDay() -> Bool {
        guard let lastReset = defaults.object(forKey: lastResetKey) as? Date else {
            return true  // 최초 실행 시 리셋 필요
        }
        return !Calendar.current.isDate(lastReset, inSameDayAs: Date())
    }
    
    private func performReset() {
        defaults.set(0, forKey: counterKey)
        defaults.set(Date(), forKey: lastResetKey)
    }
}
```

**이중 체크가 필요한 이유:**

1. **Foreground 체크만 하는 경우:** 앱이 Foreground에 있는 상태에서 자정을 넘기면 리셋이 안 됨
2. **사용 시점 체크만 하는 경우:** 리셋 전 UI가 이전 날의 상태를 보여줌 (UI 깜빡임)
3. **두 시점 모두 체크:** Foreground 진입 시 UI를 즉시 갱신하고, 사용 시점에서 마지막 안전망 역할

---

## 5. 실제 앱 사례 분석

### Duolingo (언어 학습)

- **리셋 기준:** 사용자 로컬 자정 (디바이스 타임존 기반)
- **타임존 추적:** 계정 생성 시 초기 타임존 설정, 모바일 앱 사용 시 디바이스 타임존으로 자동 업데이트
- **보호 장치:** Streak Freeze (잼으로 구매, 하루 미수행 시 스트릭 유지)
- **문제점:** 웹에서는 타임존 변경 불가, 일부 타임존 오프셋 처리 오류 존재
- **핵심 로직:** `마지막 학습 시간 < 오늘 자정(00:00)` 이면 새로운 날로 판정

### Apple Screen Time (iOS 시스템)

- **리셋 기준:** 기기 로컬 자정 고정 (변경 불가)
- **알려진 버그:** 자정에 카운터가 리셋되지 않아 아침부터 앱이 차단되는 경우 보고됨
- **교훈:** 시스템 레벨에서도 자정 리셋은 완벽하지 않을 수 있음

### 모바일 게임 일일 보상 시스템 (Nakama/Heroic Labs 패턴)

- **서버 기반:** `lastClaimUnix` 타임스탬프를 서버 스토리지에 저장
- **이중 RPC:** `canClaimDailyReward` (자격 확인) + `claimDailyReward` (실제 지급)
- **원자적 검증:** 서버 사이드에서 자격 확인 후 월렛 업데이트, 클라이언트 조작 불가

### Wordle / 데일리 챌린지 앱

- **서버 기반 UTC 자정:** 전 세계 동일한 퍼즐을 동일 시점에 제공
- **날짜 = 퍼즐 ID:** 각 날짜에 고유한 퍼즐 번호가 매핑되어 리셋과 콘텐츠가 연동

---

## 6. 리셋이 실행되지 않는 경우 (앱이 백그라운드에 있을 때)

**문제 시나리오:** 사용자가 앱을 백그라운드에 두고 다음 날까지 열지 않는 경우

**대응 전략:**

```swift
/// 방어적 리셋 패턴 - 모든 진입점에서 체크
final class RobustDailyResetManager {
    
    // 1. 앱 Foreground 진입
    func onForeground() {
        checkAndReset()
    }
    
    // 2. 주요 화면 viewDidAppear
    func onScreenAppear() {
        checkAndReset()
    }
    
    // 3. 리소스 접근 시점 (제한 체크)
    func onResourceAccess() -> Bool {
        checkAndReset()
        return currentCount < limit
    }
    
    // 4. significantTimeChangeNotification 수신 시
    func onSignificantTimeChange() {
        checkAndReset()
    }
    
    // 5. Background App Refresh (보조)
    func onBackgroundRefresh() {
        checkAndReset()
        // 로컬 알림으로 "오늘의 무료 사용이 리셋되었습니다" 전송 가능
    }
    
    private func checkAndReset() {
        guard isNewDay() else { return }
        performReset()
        NotificationCenter.default.post(name: .dailyLimitDidReset, object: nil)
    }
}
```

**핵심:** "리셋이 정해진 시간에 실행되어야 한다"는 사고 대신, **"리소스에 접근할 때 필요하면 리셋한다"** 는 지연 평가(lazy evaluation) 사고가 중요합니다. 사용자가 앱을 열지 않으면 리셋할 필요도 없기 때문입니다.

---

## 7. 서버 사이드 vs 클라이언트 사이드 리셋

| 항목 | 서버 사이드 | 클라이언트 사이드 |
|------|-----------|----------------|
| **시계 조작 방지** | 완벽히 방지 가능 | 취약 (디바이스 시간 변경 가능) |
| **오프라인 동작** | 불가 (네트워크 필수) | 가능 |
| **일관성** | 모든 디바이스에서 동일 | 디바이스별 차이 가능 |
| **구현 복잡도** | 높음 (서버 인프라 필요) | 낮음 |
| **레이턴시** | 네트워크 지연 존재 | 즉시 |
| **비용** | 서버 운영 비용 | 없음 |
| **적합 케이스** | 과금/보상 관련 기능, 경쟁 요소 | 사용성 향상 기능, 개인 카운터 |

**실무 권장:** 하이브리드 접근법

```swift
/// 하이브리드 리셋 관리자
class HybridDailyResetManager {
    
    /// 서버에서 "진짜 오늘"을 받아오되, 실패 시 로컬 시간 사용
    func checkNewDay(completion: @escaping (Bool) -> Void) {
        // 1차: 서버 시간 확인 시도
        fetchServerTime { [weak self] serverTime in
            if let serverTime = serverTime {
                let isNew = self?.isNewDay(referenceTime: serverTime) ?? false
                completion(isNew)
            } else {
                // 2차: 네트워크 실패 시 로컬 시간으로 폴백
                let isNew = self?.isNewDay(referenceTime: Date()) ?? false
                completion(isNew)
            }
        }
    }
    
    private func fetchServerTime(completion: @escaping (Date?) -> Void) {
        // NTP 또는 자체 서버 API 호출
        // TrueTime.swift 또는 Kronos 라이브러리 활용 가능
    }
}
```

---

## 8. 시계 조작(Clock Manipulation) 방지

### 방법 1: NTP 라이브러리 활용

iOS에서는 다음 라이브러리를 통해 디바이스 시계와 무관한 실제 시간을 얻을 수 있습니다:

- **[TrueTime.swift](https://github.com/instacart/TrueTime.swift):** Instacart에서 만든 NTP 클라이언트. 디바이스 시계 변경에 영향을 받지 않는 시간을 제공
- **[Kronos](https://github.com/MobileNativeFoundation/Kronos):** Mobile Native Foundation의 NTP 라이브러리. 서브초 정밀도 지원, 단조 시계(monotonic clock) 사용
- **[swift-ntp](https://github.com/apple/swift-ntp):** Apple 공식 Swift NTP 라이브러리 (Swift NIO 기반)

```swift
import Kronos

// 앱 시작 시 동기화
Clock.sync()

// 이후 어디서든 실제 시간 조회
if let trueNow = Clock.now {
    // trueNow는 디바이스 시계와 무관한 실제 시간
    let isNew = !Calendar.current.isDate(lastResetDate, inSameDayAs: trueNow)
}
```

### 방법 2: 단조 시계(Monotonic Clock) 기반 탐지

```swift
/// 시계 조작 탐지기
class ClockManipulationDetector {
    
    private var lastSystemUptime: TimeInterval  // 부팅 후 경과 시간 (조작 불가)
    private var lastWallClockDate: Date         // 벽시계 시간 (조작 가능)
    
    init() {
        self.lastSystemUptime = ProcessInfo.processInfo.systemUptime
        self.lastWallClockDate = Date()
    }
    
    /// 시계 조작 여부 탐지
    func detectClockManipulation() -> Bool {
        let currentUptime = ProcessInfo.processInfo.systemUptime
        let currentDate = Date()
        
        // 실제 경과 시간 (단조 시계 기반, 조작 불가)
        let uptimeDelta = currentUptime - lastSystemUptime
        
        // 벽시계 경과 시간 (사용자가 조작 가능)
        let wallClockDelta = currentDate.timeIntervalSince(lastWallClockDate)
        
        // 두 경과 시간의 차이가 비정상적으로 크면 조작 의심
        // (허용 오차: 60초 - 네트워크 시간 동기화 고려)
        let discrepancy = abs(wallClockDelta - uptimeDelta)
        
        // 갱신
        lastSystemUptime = currentUptime
        lastWallClockDate = currentDate
        
        return discrepancy > 60  // 60초 이상 차이나면 조작 의심
    }
}
```

### 방법 3: 서버 타임스탬프 검증

```swift
/// "시간이 뒤로 갔는지" 체크
func isTimeGoingBackward(lastSavedDate: Date) -> Bool {
    // 저장된 마지막 날짜보다 현재 시간이 과거이면 조작
    return Date() < lastSavedDate
}
```

### 방법 4: 다단계 방어 (실무 권장)

```swift
struct AntiCheatDailyReset {
    func shouldReset() -> ResetDecision {
        // 1단계: 시계가 뒤로 갔는지 확인
        if isTimeGoingBackward() {
            return .denied(reason: .clockManipulationDetected)
        }
        
        // 2단계: NTP 시간 사용 가능하면 NTP 기준
        if let ntpTime = Clock.now {
            return isNewDay(reference: ntpTime) ? .reset : .noReset
        }
        
        // 3단계: 네트워크 불가 시 로컬 시간 사용 (제한적 신뢰)
        return isNewDay(reference: Date()) ? .reset : .noReset
    }
}
```

---

## 9. UserDefaults / Keychain 저장 모범 사례

### UserDefaults: 일반적인 일일 카운터

```swift
/// UserDefaults 기반 일일 카운터 (탬퍼 방지 불필요한 경우)
struct DailyCounter {
    private enum Keys {
        static let count = "daily_counter_count"
        static let date = "daily_counter_date"
        // 키 이름은 enum으로 관리하여 오타 방지
    }
    
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    var count: Int {
        get {
            // 날짜 확인 후 반환
            resetIfNeeded()
            return defaults.integer(forKey: Keys.count)
        }
        set {
            defaults.set(newValue, forKey: Keys.count)
            defaults.set(Date(), forKey: Keys.date)
        }
    }
    
    private func resetIfNeeded() {
        guard let lastDate = defaults.object(forKey: Keys.date) as? Date else {
            // 최초 실행 - 초기화
            defaults.set(0, forKey: Keys.count)
            defaults.set(Date(), forKey: Keys.date)
            return
        }
        
        if !Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
            defaults.set(0, forKey: Keys.count)
            defaults.set(Date(), forKey: Keys.date)
        }
    }
}
```

### Keychain: 탬퍼 방지가 필요한 경우

```swift
import Security

/// Keychain 기반 일일 카운터 (과금/보상 관련)
struct SecureDailyCounter {
    private let service = "com.app.dailyCounter"
    
    /// Keychain에 카운터 + 날짜를 함께 저장
    struct CounterData: Codable {
        var count: Int
        var date: Date
        var integrityHash: String  // 무결성 검증용 해시
    }
    
    func save(_ data: CounterData) {
        // 무결성 해시 생성
        var dataWithHash = data
        dataWithHash.integrityHash = computeHash(count: data.count, date: data.date)
        
        guard let encoded = try? JSONEncoder().encode(dataWithHash) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            // "ThisDeviceOnly" -> 백업에 포함되지 않아 복원으로 조작 불가
        ]
        
        SecItemDelete(query as CFDictionary)  // 기존 항목 삭제
        
        var addQuery = query
        addQuery[kSecValueData as String] = encoded
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    func load() -> CounterData? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        guard let data = result as? Data,
              let decoded = try? JSONDecoder().decode(CounterData.self, from: data) else {
            return nil
        }
        
        // 무결성 검증
        let expectedHash = computeHash(count: decoded.count, date: decoded.date)
        guard decoded.integrityHash == expectedHash else {
            // 데이터가 조작됨 - 리셋
            return nil
        }
        
        return decoded
    }
    
    private func computeHash(count: Int, date: Date) -> String {
        // 앱 번들 ID + 비밀 솔트를 포함한 HMAC 해시
        let input = "\(count)_\(date.timeIntervalSince1970)_\(Bundle.main.bundleIdentifier ?? "")"
        // 실제 구현에서는 CryptoKit의 HMAC 사용
        return input.data(using: .utf8)?.base64EncodedString() ?? ""
    }
}
```

### 선택 기준 정리

| 시나리오 | 저장소 | 이유 |
|---------|-------|------|
| 일일 무료 기능 사용 횟수 (비과금) | UserDefaults | 조작해도 큰 피해 없음, 간단 |
| 일일 보상/과금 관련 카운터 | Keychain + 서버 | 탬퍼 방지 필수 |
| 스트릭/연속 기록 | UserDefaults + 서버 검증 | 로컬 빠른 접근 + 서버 진실 소스 |
| 일일 광고 시청 제한 | Keychain | 광고 수익과 직결 |

---

## 10. 게임 일일 에너지 시스템 처리 방식

### 기본 에너지 시스템 아키텍처

```swift
/// 게임 에너지 시스템 - 서버 시간 기반
struct EnergySystem {
    let maxEnergy: Int = 5
    let rechargeIntervalSeconds: TimeInterval = 1800  // 30분당 1 에너지
    
    var currentEnergy: Int
    var lastUpdateTimestamp: Date  // 서버 기준 타임스탬프
    
    /// 현재 에너지 계산 (서버 시간 기반)
    mutating func calculateCurrentEnergy(serverTime: Date) -> Int {
        guard currentEnergy < maxEnergy else {
            return maxEnergy  // 이미 만충이면 계산 불필요
        }
        
        let elapsed = serverTime.timeIntervalSince(lastUpdateTimestamp)
        let rechargedUnits = Int(elapsed / rechargeIntervalSeconds)
        
        let newEnergy = min(currentEnergy + rechargedUnits, maxEnergy)
        
        if rechargedUnits > 0 {
            // 소수점 이하 시간은 보존 (다음 계산에 반영)
            let consumedTime = TimeInterval(rechargedUnits) * rechargeIntervalSeconds
            lastUpdateTimestamp = lastUpdateTimestamp.addingTimeInterval(consumedTime)
            currentEnergy = newEnergy
        }
        
        return newEnergy
    }
    
    /// 에너지 소비 (서버에서 검증)
    mutating func consumeEnergy(amount: Int, serverTime: Date) -> Bool {
        let available = calculateCurrentEnergy(serverTime: serverTime)
        guard available >= amount else { return false }
        
        // 만충 상태에서 소비 시 타임스탬프 갱신
        if currentEnergy == maxEnergy {
            lastUpdateTimestamp = serverTime
        }
        
        currentEnergy -= amount
        return true
    }
}
```

### 일일 에너지 리필 (자정 리셋)

```swift
/// 일일 무료 에너지 리필 시스템
struct DailyEnergyRefill {
    
    /// 서버 측 로직 (의사 코드)
    func claimDailyRefill(
        userId: String,
        serverTime: Date,
        lastClaimTime: Date?
    ) -> RefillResult {
        
        // UTC 기준 날짜 비교 (글로벌 게임)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        
        if let lastClaim = lastClaimTime {
            if utcCalendar.isDate(lastClaim, inSameDayAs: serverTime) {
                return .alreadyClaimed
            }
        }
        
        // 리필 지급
        return .success(energyGranted: 5)
    }
}
```

### LootLocker 패턴 (치트 방지 에너지 시스템)

LootLocker가 권장하는 핵심 원칙:

1. **서버 시간이 유일한 진실 소스:** 디바이스 시간을 절대 신뢰하지 않음
2. **포커스 복귀 시 서버 재동기화:** 앱이 백그라운드에서 복귀할 때 반드시 서버 시간을 다시 가져옴
3. **만충 시 추적 중단:** 에너지가 최대치에 도달하면 타이머를 멈추고, 소비 시점에 서버 시간 기준으로 재시작
4. **서버에서 차감:** 에너지 차감은 반드시 서버 API를 통해 수행하여 클라이언트 조작 방지

---

## 종합 권장 패턴: iOS 앱 일일 제한 시스템

```swift
/// 프로덕션 레벨 일일 제한 관리자
final class ProductionDailyLimitManager {
    static let shared = ProductionDailyLimitManager()
    
    // MARK: - Configuration
    private let maxDailyActions = 5
    private let counterKey = "pdlm_counter"
    private let dateKey = "pdlm_lastReset"
    private let timezoneKey = "pdlm_timezone"
    
    // MARK: - Lifecycle Hooks (모두 연결해야 함)
    
    /// 1. AppDelegate / SceneDelegate에서 호출
    func onAppWillEnterForeground() {
        checkAndResetIfNewDay()
    }
    
    /// 2. significantTimeChangeNotification에서 호출
    func onSignificantTimeChange() {
        checkAndResetIfNewDay()
    }
    
    /// 3. 자정 타이머 (앱이 Foreground일 때)
    func onMidnightTimer() {
        checkAndResetIfNewDay()
    }
    
    // MARK: - Public API
    
    /// 액션 가능 여부 확인 (이중 체크 포함)
    func canPerformAction() -> Bool {
        checkAndResetIfNewDay()
        return currentCount < maxDailyActions
    }
    
    /// 남은 횟수
    var remainingActions: Int {
        checkAndResetIfNewDay()
        return max(0, maxDailyActions - currentCount)
    }
    
    /// 액션 소비
    func consumeAction() -> Bool {
        guard canPerformAction() else { return false }
        currentCount += 1
        return true
    }
    
    // MARK: - Private
    
    private var currentCount: Int {
        get { UserDefaults.standard.integer(forKey: counterKey) }
        set { UserDefaults.standard.set(newValue, forKey: counterKey) }
    }
    
    private func checkAndResetIfNewDay() {
        guard let lastReset = UserDefaults.standard.object(forKey: dateKey) as? Date else {
            performReset()
            return
        }
        
        // Calendar.current.isDate는 DST, 타임존을 자동 처리
        if !Calendar.current.isDate(lastReset, inSameDayAs: Date()) {
            performReset()
        }
    }
    
    private func performReset() {
        currentCount = 0
        UserDefaults.standard.set(Date(), forKey: dateKey)
        UserDefaults.standard.set(TimeZone.current.identifier, forKey: timezoneKey)
        
        // UI 갱신 알림
        NotificationCenter.default.post(name: .dailyLimitDidReset, object: nil)
    }
}

extension Notification.Name {
    static let dailyLimitDidReset = Notification.Name("dailyLimitDidReset")
}
```

---

## 핵심 요약

| 항목 | 권장 사항 |
|------|----------|
| 날짜 비교 | `Calendar.current.isDate(_:inSameDayAs:)` 사용 (DST 안전) |
| 절대 하지 말 것 | `TimeInterval` 86400초로 24시간 비교 |
| 리셋 체크 시점 | Foreground 진입 + 리소스 접근 시점 (이중 체크) |
| 보조 수단 | `significantTimeChangeNotification` + 자정 타이머 |
| 타임존 변경 | 이전/현재 타임존 모두에서 날짜 비교 (유예 기간) |
| 시계 조작 방지 (가벼운) | NTP 라이브러리 (Kronos, TrueTime) |
| 시계 조작 방지 (엄격한) | 서버 사이드 검증 필수 |
| 저장소 (비과금) | UserDefaults |
| 저장소 (과금/보상) | Keychain + 서버 검증 |
| 에너지 시스템 | 서버 타임스탬프 기반, 포커스 복귀 시 재동기화 |

---

Sources:
- [Duolingo 타임존 보호 가이드](https://support.duolingo.com/hc/en-us/articles/4403172029325-How-do-I-protect-my-streak-while-traveling-to-another-time-zone-)
- [Duolingo 스트릭 Wiki](https://duolingo.fandom.com/wiki/Streak)
- [Swift 일일 스트릭 시스템 구현 (Luke Roberts)](https://blog.lukeroberts.co/posts/streak-system/)
- [일일 스트릭 시스템 실무 가이드 (Tiger Abrodi)](https://tigerabrodi.blog/implementing-a-daily-streak-system-a-practical-guide)
- [치트 방지 에너지 시스템 (LootLocker)](https://lootlocker.com/guides/how-to-create-an-energy-system-that-can-t-easily-be-cheated)
- [일일 보상 시스템 (Heroic Labs / Nakama)](https://heroiclabs.com/docs/nakama/guides/concepts/daily-rewards/)
- [TrueTime.swift NTP 라이브러리](https://github.com/instacart/TrueTime.swift)
- [Kronos NTP 라이브러리](https://github.com/MobileNativeFoundation/Kronos)
- [Apple swift-ntp](https://github.com/apple/swift-ntp)
- [iOS startOfDay 문서](https://developer.apple.com/documentation/foundation/calendar/2293783-startofday)
- [iOS ScenePhase 문서](https://developer.apple.com/documentation/swiftui/scenephase)
- [Apple Screen Time 리셋 이슈](https://discussions.apple.com/thread/254045462)
- [스트릭 시스템 UX 설계 (Smashing Magazine)](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/)
- [UserDefaults vs Keychain 비교](https://medium.com/@muradwajed/userdefaults-vs-a0655dd949a2)
- [시간 기반 치트 방지 (Unity Forums)](https://forum.unity.com/threads/time-cheating-prevention-in-offline-mode-ios-android.256735/)

---

이하 내용은 260226research3.md 에서 계속