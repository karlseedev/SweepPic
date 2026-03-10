# BM 수익화 Analytics 데이터 수집 총괄 계획

## Context

BM 수익화(specs/003-bm-monetization) 구현 중. Supabase를 **Claude의 메인 분석 데이터셋**으로 사용한다. Claude가 직접 Supabase를 쿼리하여 데이터 분석을 수행하므로, Claude가 분석해야 할 모든 데이터는 Supabase에 있어야 한다. ASC/AdMob은 Claude가 접근 불가하므로 보조 역할.

**핵심 제약:** Device ID(IDFV)는 App Store Privacy Label "Identifiers" 선언을 피하기 위해 추가하지 않는다. 경쟁 앱(Slidebox, CleanMyPhone)도 미선언.

**현재 상태:** BM 이벤트 코드는 이미 구현 완료(AnalyticsService+Monetization.swift, 삽입 지점 12곳). 단, RLS 미등록으로 Supabase에서 전부 403 드롭 중. subscription_tier 미전송, subscription.cancelReason 미구현.

**이번 계획 범위:** BM 8종 정상 수집 + cancelReason 인프라 준비 (enum/메서드만 추가, 호출 삽입은 Exit Survey UI 구현 시).

---

## 1. 데이터 수집 아키텍처

### 1.1 역할 분담

| 소스 | 역할 | Claude 접근 | 비용 |
|------|------|------------|------|
| **Supabase** | **메인** — 앱 내부 행동 전체 (기존 + BM) | **직접 쿼리 가능** | 무료 (500MB) |
| **TelemetryDeck** | 백업 — 전 이벤트 이중 수집 | 제한적 | 무료~99유로 |
| **App Store Connect** | 보조 — 유저 단위 리텐션, 벤치마크 (device_id 필요한 분석) | 접근 불가 | 무료 |
| **AdMob Dashboard** | 보조 — 광고 수익 eCPM, fill rate | 접근 불가 | 무료 |

### 1.2 Supabase가 담당하는 분석 (Claude 분석용)

**기존 11종 (앱 사용 패턴):**
- 앱 실행, 권한, 사진 열람, 삭제/복구, 삭제대기함, 유사 분석, 오류, 정리, 그리드 성능

**BM 신규 9종 (수익화 행동):**
- 게이트 퍼널: 노출 → 선택(광고/구독/닫기) 분포
- 광고 시청 패턴 (리워드 + 전면)
- 페이월 진입 경로별 노출 빈도
- 구독 완료 (상품별)
- 해지 사유 (Exit Survey)
- 삭제 장수 패턴 (tier별 세그먼트)
- Grace Period 종료 시점
- ATT 동의율

### 1.3 ASC/AdMob만 제공하는 것 (Claude 분석 불가, 사람이 확인)

- Day 1/7/28 유저 단위 리텐션 (device_id 필요)
- 유저 단위 전환 퍼널 (device_id 필요)
- 광고 eCPM, fill rate, 국가별 수익
- 동종 앱 벤치마크

---

## 2. Supabase 변경사항

### 2.1 subscription_tier 컬럼 추가

```sql
ALTER TABLE events ADD COLUMN IF NOT EXISTS subscription_tier TEXT;
CREATE INDEX IF NOT EXISTS idx_events_tier ON events(subscription_tier);
```

- 기존 행: NULL (BM 이전 데이터)
- 새 이벤트: `free` 또는 `plus`
- `Prefer: missing=default` 헤더 → 미전송 시 NULL (호환성 유지)
- ⚠️ 앱 시작 직후 초기 이벤트(app.launched 등)는 SubscriptionStore.refreshSubscriptionStatus() 완료 전이라 `free`로 기록될 수 있음. BM 이벤트는 사용자 인터랙션 이후 발생하므로 영향 없음.

### 2.2 RLS 화이트리스트 확장 (11종 → 20종)

```sql
DROP POLICY IF EXISTS "anon_insert" ON events;
CREATE POLICY "anon_insert" ON events FOR INSERT TO anon
    WITH CHECK (
        event_name IN (
            -- 기존 11종
            'app.launched',
            'permission.result',
            'session.photoViewing',
            'session.deleteRestore',
            'session.trashViewer',
            'session.similarAnalysis',
            'session.errors',
            'similar.groupClosed',
            'cleanup.completed',
            'cleanup.previewCompleted',
            'session.gridPerformance',
            -- BM 9종 (코드 이벤트명 기준)
            'bm.gateShown',
            'bm.gateSelection',
            'bm.adWatched',
            'bm.paywallShown',
            'bm.subscriptionCompleted',
            'bm.deletionCompleted',
            'bm.gracePeriodEnded',
            'bm.attResult',
            'bm.cancelReason'
        )
    );
```

### 2.3 BM 이벤트 상세 (9종)

| # | 이벤트명 (코드) | params | 전송 시점 | 구현 상태 |
|---|----------------|--------|----------|----------|
| 12 | `bm.gateShown` | `trashCount`, `remainingLimit` | 게이트 팝업 표시 시 | ✅ 구현됨 |
| 13 | `bm.gateSelection` | `choice` (ad/plus/dismiss) | 게이트에서 버튼 탭 | ✅ 구현됨 |
| 14 | `bm.adWatched` | `type` (rewarded/interstitial) | 광고 시청 완료 | ✅ 구현됨 |
| 15 | `bm.paywallShown` | `source` (gate/menu/banner/gauge) | 페이월 화면 표시 | ✅ 구현됨 |
| 16 | `bm.subscriptionCompleted` | `productID` | 구독 구매 완료 | ✅ 구현됨 |
| 17 | `bm.deletionCompleted` | `count` | 삭제대기함 비우기 성공 | ✅ 구현됨 |
| 18 | `bm.gracePeriodEnded` | (없음) | Grace Period 만료 후 첫 세션 | ✅ 구현됨 |
| 19 | `bm.attResult` | `authorized` | ATT 프리프롬프트 결과 | ✅ 구현됨 |
| 20 | `bm.cancelReason` | `reason`, `text?` | 해지 Exit Survey 제출 | ❌ 미구현 |

### 2.4 기존 코드의 Enum 값 (변경 없음)

```swift
enum GateChoice: String { case ad, plus, dismiss }
enum AdType: String { case rewarded, interstitial }
enum PaywallSource: String { case gate, menu, banner, gauge }
```

### 2.5 RPC 함수 추가

```sql
-- 게이트 퍼널 일별 요약
CREATE OR REPLACE FUNCTION gate_funnel_summary(p_days INT DEFAULT 30)
RETURNS TABLE(day DATE, event_name TEXT, choice TEXT, cnt BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT created_at::date AS day, event_name,
           params->>'choice' AS choice, count(*) AS cnt
    FROM events
    WHERE event_name IN ('bm.gateShown', 'bm.gateSelection')
      AND created_at >= now() - (p_days || ' days')::interval
      AND is_test = false
    GROUP BY day, event_name, choice
    ORDER BY day DESC, event_name, cnt DESC;
$$;

-- tier별 이벤트 요약
CREATE OR REPLACE FUNCTION tier_summary(p_days INT DEFAULT 30)
RETURNS TABLE(tier TEXT, event_name TEXT, cnt BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(subscription_tier, 'unknown') AS tier,
           event_name, count(*) AS cnt
    FROM events
    WHERE created_at >= now() - (p_days || ' days')::interval
      AND is_test = false
    GROUP BY tier, event_name
    ORDER BY tier, cnt DESC;
$$;
```

---

## 3. 코드 변경사항 (추가 구현만)

기존 구현(AnalyticsService+Monetization.swift 8메서드, 삽입 지점 12곳)은 유지. 부족한 부분만 추가.

### 3.1 subscription_tier 전송 추가

**파일:** `SupabaseProvider.swift`

init에 클로저 주입:
```swift
private let subscriptionTierProvider: (() -> String)?

init?(baseURL: String, anonKey: String,
      subscriptionTierProvider: (() -> String)? = nil) {
    // ... 기존 코드 ...
    self.subscriptionTierProvider = subscriptionTierProvider
}
```

makeBody()에 추가:
```swift
body["subscription_tier"] = subscriptionTierProvider?() ?? "free"
```

**파일:** `AnalyticsService.swift`

configureSupabase()에서 주입:
```swift
supabaseProvider = SupabaseProvider(
    baseURL: url, anonKey: key,
    subscriptionTierProvider: { SubscriptionStore.shared.isPlusUser ? "plus" : "free" }
)
```

### 3.2 bm.cancelReason 이벤트 추가 (유일한 미구현)

**파일:** `AnalyticsService+Monetization.swift`에 메서드 추가

```swift
/// 구독 해지 사유 (Exit Survey)
func trackCancelReason(reason: CancelReason, text: String? = nil) {
    guard !shouldSkip() else { return }
    var params: [String: String] = ["reason": reason.rawValue]
    if let text = text, !text.isEmpty {
        params["text"] = String(text.prefix(200))
    }
    sendEvent("bm.cancelReason", parameters: params)
}
```

**파일:** `AnalyticsService+Monetization.swift`에 enum 추가

```swift
enum CancelReason: String {
    case price       = "price"        // 가격이 부담돼요
    case enoughFree  = "enough_free"  // 삭제 한도가 충분해요
    case done        = "done"         // 사진 정리를 다 했어요
    case competitor  = "competitor"   // 다른 앱을 사용해요
    case other       = "other"        // 기타
}
```

삽입 지점: Exit Survey UI (Phase 10 메뉴에서 향후 구현)

### 3.3 기존 코드 확인 — 변경 불필요

| 파일 | 상태 | 비고 |
|------|------|------|
| `AnalyticsService+Monetization.swift` | 유지 | 8메서드 + 3 enum 그대로 |
| `TrashGateCoordinator.swift` | 유지 | trackGateShown/Selection 삽입됨 |
| `RewardedAdPresenter.swift` | 유지 | trackAdWatched(.rewarded) 삽입됨 |
| `InterstitialAdPresenter.swift` | 유지 | trackAdWatched(.interstitial) 삽입됨 |
| `PaywallViewController.swift` | 유지 | trackPaywallShown 삽입됨 |
| `SubscriptionStore.swift` | 유지 | trackSubscriptionCompleted 삽입됨. ⚠️ status(for:)에 productID 대신 groupID를 넘겨야 하는 기존 버그 있음 (별도 수정) |
| `TrashAlbumViewController.swift` | 유지 | trackDeletionCompleted 삽입됨 |
| `TrashSelectMode.swift` | 유지 | trackDeletionCompleted 삽입됨 |
| `SceneDelegate.swift` | 유지 | trackGracePeriodEnded 삽입됨 |
| `ATTPromptViewController.swift` | 유지 | trackATTResult 삽입됨 |

---

## 4. 영구보존 문서 업데이트

### 260225db-Archi.md

| 섹션 | 변경 |
|------|------|
| §2.5 SupabaseProvider | subscriptionTierProvider 클로저 주입, makeBody 필드 8개로 확장 |
| §4.1 시그널 이름 총괄표 | BM 9종 추가 (#12~20) |
| §4.2 공통 Enum | GateChoice, AdType, PaywallSource, CancelReason 추가 |
| §4.3 즉시 전송형 이벤트 | BM 9종 메서드 코드 |
| §5.1 테이블 스키마 | subscription_tier TEXT 컬럼 + 인덱스 |
| §5.2 RLS 정책 | 20종 화이트리스트 |
| §5.3 RPC 함수 | gate_funnel_summary, tier_summary 추가 |
| §6.1 파일 배치도 | +Monetization.swift 역할 설명 |
| §6.2 각 파일 책임 | +Monetization.swift 행 (~130줄, 9메서드) |

### 260225db-Spec.md

| 섹션 | 변경 |
|------|------|
| §1.2 설계 원칙 | Supabase = Claude 메인 분석 데이터셋 명시 |
| §2.3 Supabase 비용 | 볼륨 재추정 (세션당 10~13건, BM 포함) |
| §3.1 총괄표 | BM 9종 행 추가 (#12~20) |
| §3.4 이벤트 상세 | §3.4.9 BM 수익화 신규 섹션 (9개 이벤트 상세) |
| §3.5 전송 여부 | BM 9종 모두 Supabase O / TD O |
| §4.1 메타데이터 | subscription_tier (free/plus) 추가 |
| §5 변경 이력 | BM 9종 + subscription_tier 기재 |

### 260225db-API.md

| 섹션 | 변경 |
|------|------|
| §3.1 필터 예시 | subscription_tier=eq.free, event_name=eq.bm.gateShown 추가 |
| §3.2 스크립트 | BM 이벤트 조회 예시 |
| §3.5 사용 예시 | BM 분석 시나리오 (게이트 퍼널, tier별 삭제, 구독 전환) |
| §4 Claude 워크플로우 | BM 분석 시나리오 추가 |
| §5.2 Supabase 메모 | subscription_tier 설명, 용량 재추정 |

---

## 5. 실행 순서

### Phase A: Supabase 서버 (선행)
1. ALTER TABLE: subscription_tier 컬럼 + 인덱스
2. DROP/CREATE POLICY: RLS 20종
3. RPC 함수 2개
4. 검증: curl로 bm.gateShown INSERT 테스트 → 201

### Phase B: 코드 추가 구현
1. SupabaseProvider: init에 tierProvider 추가 + makeBody()에 subscription_tier (~10줄)
2. AnalyticsService: configureSupabase()에서 tierProvider 주입 (~3줄)
3. +Monetization.swift: CancelReason enum + trackCancelReason() 추가 (~20줄)
4. 빌드 확인

### Phase C: 영구보존 문서 업데이트
1. Archi.md, Spec.md, API.md 전면 업데이트

### Phase D: 통합 테스트
1. 실기기 빌드 + 배포
2. 기존 11종 이벤트 정상 전송 확인 (회귀 테스트)
3. BM 9종 이벤트 전송 확인:
   - 게이트 트리거 → bm.gateShown, bm.gateSelection 도착
   - 리워드 광고 → bm.adWatched(type=rewarded) 도착
   - 페이월 → bm.paywallShown 도착
   - 구독 → bm.subscriptionCompleted 도착
   - 삭제 → bm.deletionCompleted 도착
4. subscription_tier 확인: free/plus 정상 기록
5. 오프라인 큐: 비행기 모드에서 이벤트 발생 → 복구 후 전송

---

## 6. 파일 변경 요약

| 파일 | 변경 | 규모 |
|------|------|------|
| `SupabaseProvider.swift` | init에 tierProvider 추가 + makeBody()에 1줄 | ~10줄 |
| `AnalyticsService.swift` | configureSupabase()에서 tierProvider 주입 | ~3줄 |
| `AnalyticsService+Monetization.swift` | CancelReason enum + trackCancelReason() 추가 | ~20줄 |
| Supabase Dashboard | SQL 5문 (ALTER + INDEX + POLICY + RPC×2) | — |
| 영구보존 문서 3개 | 전면 업데이트 | ~200줄 |
| **총 코드 변경** | | **~33줄** |
