# Data Model: BM 수익화 시스템

**Branch**: `003-bm-monetization` | **Date**: 2026-03-03

---

## 엔터티

### UsageLimit (Keychain 저장 — 앱 삭제에도 유지)

일일 삭제 한도 및 광고 시청 상태를 추적한다.

```
UsageLimit: Codable, Sendable
├── dailyDeleteCount: Int          // 오늘 삭제한 장수 (기본 한도 내)
├── dailyRewardCount: Int          // 오늘 리워드 광고 시청 횟수 (최대 2)
├── lastResetDate: String          // 마지막 리셋 날짜 (yyyy-MM-dd, 서버 시간 기준)
├── lastServerDate: String?        // 마지막 확인된 서버 날짜 (시계 조작 감지용)
├── lifetimeFreeGrantUsed: Bool    // 생애 최초 no-fill 무료 +10장 사용 여부
└── hasUsedGracePeriod: Bool      // Grace Period 사용 여부 (재설치 악용 방지, FR-051a)
```

**상수**:
- `dailyFreeLimit = 10` (A/B 테스트 대비 변경 가능)
- `rewardBonusPerAd = 10`
- `maxDailyRewards = 2`
- `maxDailyTotal = dailyFreeLimit + (rewardBonusPerAd × maxDailyRewards)` = 30

**계산 프로퍼티**:
- `remainingFreeDeletes`: max(0, dailyFreeLimit - dailyDeleteCount)
- `remainingRewards`: max(0, maxDailyRewards - dailyRewardCount)
- `totalDailyCapacity`: dailyFreeLimit + (dailyRewardCount × rewardBonusPerAd)
- `canDeleteWithinLimit(count:)`: count ≤ remainingFreeDeletes + (remainingRewards × rewardBonusPerAd)
- `adsNeeded(for count:)`: 한도 초과분을 커버하기 위한 광고 횟수

**상태 전이**:
```
[리셋 상태] ──삭제──→ [부분 소진] ──삭제──→ [기본 한도 소진]
                                                │
                                          광고 시청 ×1
                                                │
                                         [+10장 확장] ──삭제──→ [확장 소진]
                                                │
                                          광고 시청 ×2
                                                │
                                         [+20장 확장] ──삭제──→ [일일 최대 도달]
                                                │
                                            자정 리셋
                                                │
                                         [리셋 상태]로 복귀
```

---

### GracePeriodState (UserDefaults 저장)

설치 후 3일간 무제한 체험 기간을 관리한다.

```
GracePeriodState
├── installDate: Date              // 앱 최초 실행일 (UserDefaults, 1회 기록)
└── (계산) isActive: Bool          // Date() < installDate + 3일
    (계산) remainingDays: Int      // max(0, 3 - 경과일수)
    (계산) currentDay: Int         // 0, 1, 2, 3+ (배너 단계 결정용)
```

**참고**: 앱 삭제/재설치 시 installDate(UserDefaults)가 초기화되지만, UsageLimit의 hasUsedGracePeriod(Keychain)가 유지되므로 같은 기기에서 Grace Period 재악용 방지됨 (FR-051a). 새 기기 설치 시에는 Keychain이 비어있으므로 Grace Period 정상 부여.

---

### SubscriptionState (인메모리 + StoreKit 2 캐시)

구독 상태를 앱 실행 중 추적한다.

```
SubscriptionState: Sendable
├── tier: SubscriptionTier         // .free | .pro
├── isActive: Bool                 // Pro 구독 활성 여부
├── autoRenewEnabled: Bool         // 자동 갱신 활성 여부
├── hasPaymentIssue: Bool          // 결제 문제 (갱신 실패)
├── expirationDate: Date?          // 만료 예정일
└── originalPurchaseDate: Date?    // 최초 구매일

enum SubscriptionTier: String, Codable
├── free
└── pro
```

**상태 전이**:
```
[Free] ──구매──→ [Pro Active]
  ↑                    │
  │              환불/만료/미갱신
  │                    │
  └────────────────────┘

[Pro Active] ──갱신 실패──→ [Pro (결제 문제)] ──16일 유예──→ [Free]
                                     │
                                결제 수단 갱신
                                     │
                              [Pro Active]로 복귀
```

---

### DeletionStats (Documents/JSON 저장 — TrashStore 패턴)

누적 삭제 통계를 영구 저장한다.

```
DeletionStats: Codable, Sendable
├── totalDeletedCount: Int         // 누적 삭제 장수
├── totalFreedBytes: Int64         // 누적 확보 용량 (bytes)
└── lastUpdated: Date              // 마지막 갱신 시각
```

**저장 경로**: `Documents/DeletionStats.json`
**저장 패턴**: TrashStore 동일 (JSONEncoder, iso8601, atomic write, serial queue)

---

### CelebrationResult (인메모리 — 축하 화면 전달용)

```
CelebrationResult
├── sessionDeletedCount: Int       // 이번 삭제 장수
├── sessionFreedBytes: Int64       // 이번 확보 용량
├── totalDeletedCount: Int         // 누적 삭제 장수 (DeletionStats에서)
└── totalFreedBytes: Int64         // 누적 확보 용량 (DeletionStats에서)
```

---

### ReviewTracker (UserDefaults 저장)

리뷰 요청 조건을 추적한다.

```
ReviewTracker
├── sessionCount: Int              // 누적 세션 수
├── totalTrashMoveCount: Int       // 누적 삭제대기함 이동 수
├── lastRequestDate: Date?         // 마지막 리뷰 요청일
├── lastRequestedVersion: String?  // 마지막 요청한 앱 버전
└── (계산) canRequest: Bool        // 5개 조건 + 금지 타이밍 체크
```

**5개 조건** (모두 충족 시):
1. 설치 후 3일 경과
2. 3세션 이상
3. 30장 이상 삭제대기함 이동
4. 현재 버전에서 미요청
5. 마지막 요청 후 90일 경과

**금지 타이밍**: 광고 직후, 결제 직후, 에러 세션, 게이트 직후

---

### ATTState (UserDefaults 저장)

ATT 프리프롬프트 표시 상태를 추적한다.

```
ATTState
├── skipCount: Int                 // 건너뛰기 횟수 (0, 1, 2)
├── hasShownPrompt: Bool           // 프리프롬프트 표시 완료 여부
└── (계산) shouldShowPrompt: Bool  // skipCount < 2 && !hasShownPrompt && Grace 만료 && ATT == .notDetermined
```

---

### AdCounters (인메모리 — 세션 단위)

전면 광고 표시 회차를 트리거별로 독립 추적한다.

```
AdCounters
├── similarPhotoCompletionCount: Int    // 유사사진 삭제 완료 횟수
├── autoCleanupCompletionCount: Int     // 자동정리 완료 횟수
└── (계산) shouldShowInterstitial(for trigger:) -> Bool  // 짝수 회차 판단
```

---

## 엔터티 관계도

```
UsageLimit ←── TrashGateCoordinator ──→ SubscriptionState
    │                 │
    │                 ├──→ GracePeriodState
    │                 │
    │                 └──→ AdManager (리워드 로드 상태)
    │
    └── Keychain 영속화

DeletionStats ←── TrashStore.emptyTrash() 완료 시 갱신
    │
    └──→ CelebrationResult 생성 → CelebrationViewController

ReviewTracker ←── 트리거 이벤트 발생 시 평가
    │
    └──→ SKStoreReviewController.requestReview()

ATTState ←── SceneDelegate.sceneDidBecomeActive 시 평가
    │
    └──→ ATTPromptViewController → ATTrackingManager
```

---

## 저장소별 분류

| 저장소 | 엔터티 | 이유 |
|--------|--------|------|
| **Keychain** | UsageLimit | 앱 삭제에도 유지 (악용 방지) |
| **Documents/JSON** | DeletionStats | 단순 누적 통계, TrashStore 패턴 |
| **UserDefaults** | GracePeriodState, ReviewTracker, ATTState | 단순 플래그/카운터 |
| **인메모리** | SubscriptionState, CelebrationResult, AdCounters | StoreKit 2 실시간 / 세션 단위 |
