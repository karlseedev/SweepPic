# Implementation Plan: BM 수익화 시스템

**Branch**: `003-bm-monetization` | **Date**: 2026-03-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-bm-monetization/spec.md`

## Summary

BM 전략 문서(docs/bm/260227bm-spec.md)에 정의된 2-Tier 모델(무료+광고 / Pro 구독)을 앱에 구현한다.
현재 앱에는 결제/광고 인프라가 전혀 없으므로 신규 구축이 필요하다.

핵심 설계 원칙: **기존 삭제 로직은 변경하지 않고, 앞에 게이트 레이어만 삽입**한다.

---

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: UIKit, PhotoKit, StoreKit 2, Google Mobile Ads SDK 11.x (SPM), AppTrackingTransparency
**Storage**: Keychain (UsageLimit), Documents/JSON (DeletionStats), UserDefaults (GracePeriod, ATT, Review), 인메모리 (SubscriptionState, AdCounters)
**Testing**: XCTest, AdMob 테스트 광고 ID, StoreKit Configuration File (Sandbox)
**Target Platform**: iOS 16+
**Project Type**: Mobile (iOS)
**Performance Goals**: 게이트 판단 <10ms, 구독 상태 확인 <1초, 광고 사전 로드 완료
**Constraints**: 서버리스 (온디바이스 검증), 기존 삭제 흐름 미변경, 파일당 1,000줄 제한
**Scale/Scope**: 신규 파일 ~20개, 기존 파일 수정 ~10개, 3 Phase 순차 구현

---

## Constitution Check

*Constitution 미설정 (빈 템플릿). 게이트 체크 없이 진행.*

---

## Project Structure

### Documentation (this feature)

```text
specs/003-bm-monetization/
├── spec.md              # 기능 명세
├── plan.md              # 이 파일
├── research.md          # Phase 0 리서치 결과
├── data-model.md        # 데이터 모델 정의
├── contracts/           # 내부 프로토콜 정의
│   └── protocols.md     # 핵심 프로토콜 인터페이스
├── checklists/
│   └── requirements.md  # 스펙 품질 체크리스트
└── tasks.md             # 구현 태스크 (별도 생성)
```

### Source Code

```text
Sources/AppCore/
├── Models/
│   ├── UsageLimit.swift           # 일일 한도 모델 (Codable)
│   ├── DeletionStats.swift        # 삭제 통계 모델 (Codable)
│   └── SubscriptionTier.swift     # 구독 티어 enum + SubscriptionState
├── Stores/
│   ├── UsageLimitStore.swift      # 한도 상태 관리 (Keychain 기반)
│   └── DeletionStatsStore.swift   # 삭제 통계 관리 (Documents/JSON)
└── Services/
    └── GracePeriodService.swift   # Grace Period 관리 (UserDefaults)

SweepPic/SweepPic/Features/Monetization/    # 신규 폴더
├── Gate/
│   ├── TrashGateCoordinator.swift     # 게이트 판단 중앙 제어
│   ├── TrashGatePopupViewController.swift  # 게이트 팝업 UI (커스텀 중앙 팝업)
│   └── UsageGaugeView.swift           # 삭제대기함 한도 게이지 바
├── Ad/
│   ├── AdManager.swift                # AdMob 초기화 + 사전 로드 관리
│   ├── RewardedAdPresenter.swift      # 리워드 광고 표시 + 보상 처리
│   ├── InterstitialAdPresenter.swift  # 전면 광고 (짝수 회차)
│   ├── BannerAdViewController.swift   # 배너 광고 (분석 대기 화면)
│   └── ATTPromptViewController.swift  # ATT 프리프롬프트 화면
├── Subscription/
│   ├── SubscriptionStore.swift        # StoreKit 2 구독 상태 관리
│   ├── PaywallViewController.swift    # 페이월 화면
│   └── PaywallViewModel.swift         # 가격 포맷팅, 개인화 메시지
├── Celebration/
│   └── CelebrationViewController.swift # 축하 화면
└── Menu/
    ├── PremiumMenuViewController.swift  # 프리미엄 메뉴 (구독관리/복원/리딤코드)
    ├── CustomerServiceViewController.swift  # 고객센터 메뉴
    ├── FAQViewController.swift          # FAQ 아코디언
    └── BusinessInfoViewController.swift # 사업자 정보
```

### 기존 파일 수정 목록

| 파일 | 수정 내용 | Phase |
|------|-----------|-------|
| `FeatureFlags.swift` | BM 플래그 추가 (`isGateEnabled`, `isAdEnabled`, `isSubscriptionEnabled`) | 1 |
| `TrashAlbumViewController.swift` | performEmptyTrash() 게이트 래핑 + 게이지 뷰 추가 + 축하 화면 연결 | 1,2 |
| `TrashAlbumViewController+Gate.swift` | 게이트 관련 Extension 분리 (786줄 방지) | 1 |
| `TrashSelectMode.swift` | trashDeleteSelectedTapped() 게이트 래핑 | 1 |
| `GridViewController+Cleanup.swift` | ellipsis 메뉴 재구성 (프리미엄 ▸ / 고객센터 ▸ 서브메뉴) | 2 |
| `AppDelegate.swift` | AdManager.shared.configure() + SubscriptionStore.shared.configure() | 1,2 |
| `SceneDelegate.swift` | 포그라운드 진입 시 한도 리셋 체크 + ATT 프롬프트 체크 | 1,2 |
| `TrashStore.swift` | emptyTrash() 완료 시 DeletionStats 갱신 콜백 추가 | 2 |

**Structure Decision**: 기존 프로젝트의 Features/ 폴더 패턴을 따라 `Features/Monetization/` 하위에 기능별 서브폴더로 구성. AppCore에는 UI 없는 비즈니스 로직만 배치 (UIKit import 금지).

---

## 게이트 삽입 지점 전수 조사

게이트가 필요한 모든 영구 삭제 호출 지점:

| # | 파일 | 메서드 | 라인 | 호출 체인 |
|---|------|--------|------|-----------|
| 1 | TrashAlbumViewController.swift | `performEmptyTrash()` | 593 | 비우기 버튼 → emptyTrashButtonTapped() → performEmptyTrash() |
| 2 | TrashAlbumViewController.swift | (체인) | — | FloatingTabBar → TabBarController → emptyTrash() → performEmptyTrash() ✅ 1번으로 커버 |
| 3 | TrashSelectMode.swift | `trashDeleteSelectedTapped()` | 173 | 선택 모드 삭제 버튼 |

### 게이트 삽입 패턴

```swift
// 변경 전:
private func performEmptyTrash() {
    Task { try await trashStore.emptyTrash() }
}

// 변경 후:
private func performEmptyTrash() {
    TrashGateCoordinator.shared.evaluateAndPresent(
        from: self,
        trashCount: trashStore.trashedCount
    ) { [weak self] in
        // 게이트 통과 (무료 한도 내 / 광고 시청 / Pro) → 기존 로직 실행
        Task { try await self?.trashStore.emptyTrash() }
    }
}
```

> **이중 확인**: 게이트 통과 후에도 `PHPhotoLibrary.performChanges`가 iOS 시스템 팝업("Delete N Photos?")을 표시함.
> 게이트 = "광고/구독 선택", 시스템 팝업 = "최종 삭제 확인"으로 목적이 다르므로 의도된 동작.

---

## 게이트 판단 흐름

```
삭제 시도 → TrashGateCoordinator.evaluateAndPresent()
  ├─ Pro 구독자? → 바로 실행 (콜백 즉시 호출)
  ├─ Grace Period 중? → 바로 실행
  ├─ 삭제 대상 ≤ 남은 기본 한도? → 바로 실행 + recordDelete()
  └─ 한도 초과 → 게이트 팝업 표시
       ├─ 광고로 해결 가능 (필요 광고 수 ≤ 남은 리워드)?
       │    → [광고 N회 보고 X장 전체 삭제] 버튼 활성
       │    → [Pro로 무제한] 버튼
       │    → [닫기] 버튼
       ├─ 광고로도 부족?
       │    → [Pro로 무제한] 버튼 (메인)
       │    → 광고 옵션 비활성 + "오늘 광고 횟수를 모두 사용했습니다"
       │    → [닫기] 버튼
       └─ 오프라인?
            → 광고/구독 버튼 비활성
            → "인터넷 연결이 필요합니다" 안내
            → [닫기] 버튼만 활성
```

---

## 리워드 광고 → 삭제 실행 흐름

```
게이트 팝업 → "광고 N회 보고 삭제" 탭
  → 팝업 dismiss
  → RewardedAdPresenter.showAd(from:)
  → [광고 재생 완료]
  → usageLimitStore.recordReward()
  → 필요한 광고 횟수만큼 반복 (1~2회)
  → 모든 광고 완료 → 삭제 콜백 실행
  → trashStore.emptyTrash()
  → [iOS 시스템 팝업]
  → 사용자 "삭제" 확인
  → [삭제 성공]
  → usageLimitStore.recordDelete(count:)
  → deletionStatsStore.addStats(count:, bytes:)
  → CelebrationViewController 표시
```

> **시스템 팝업 취소 시**: 리워드 횟수 미차감, 한도 미증가 (FR-013)

---

## Phase 1: 게이트 + 리워드 광고 (P1)

P1 기능: US-1(게이트), US-2(리워드), US-3(Grace Period)

### 신규 파일

| 경로 | 역할 | 레이어 |
|------|------|--------|
| `Sources/AppCore/Models/UsageLimit.swift` | 일일 한도 Codable 모델 | AppCore |
| `Sources/AppCore/Stores/UsageLimitStore.swift` | Keychain 기반 한도 관리 | AppCore |
| `Sources/AppCore/Services/GracePeriodService.swift` | Grace Period 관리 | AppCore |
| `Features/Monetization/Gate/TrashGateCoordinator.swift` | 게이트 판단 중앙 제어 | SweepPic |
| `Features/Monetization/Gate/TrashGatePopupViewController.swift` | 게이트 커스텀 팝업 UI | SweepPic |
| `Features/Monetization/Gate/UsageGaugeView.swift` | 삭제대기함 한도 게이지 | SweepPic |
| `Features/Monetization/Ad/AdManager.swift` | AdMob 초기화 + 사전 로드 | SweepPic |
| `Features/Monetization/Ad/RewardedAdPresenter.swift` | 리워드 광고 표시 + 보상 | SweepPic |

### 기존 파일 수정

| 파일 | 수정 내용 |
|------|-----------|
| `FeatureFlags.swift` | `isGateEnabled`, `isAdEnabled` 플래그 추가 |
| `TrashAlbumViewController.swift` | performEmptyTrash() 게이트 래핑 |
| `TrashAlbumViewController+Gate.swift` (신규 Extension) | 게이지 뷰 설정, Grace Period 배너, 게이트 관련 메서드 |
| `TrashSelectMode.swift` | trashDeleteSelectedTapped() 게이트 래핑 |
| `AppDelegate.swift` | AdManager.shared.configure() 호출 추가 |
| `SceneDelegate.swift` | 포그라운드 진입 시 일일 한도 리셋 체크 |

### 의존성 추가

```
SPM: https://github.com/googleads/swift-package-manager-google-mobile-ads (11.x)
Info.plist: GADApplicationIdentifier, SKAdNetworkItems
```

### Phase 1 내부 구현 순서

1. **UsageLimit + UsageLimitStore** (AppCore) — 독립, 선행 필수
2. **GracePeriodService** (AppCore) — 독립
3. **FeatureFlags 확장** — 1번과 병행
4. **AdManager + RewardedAdPresenter** — SPM 의존성 추가 후
5. **TrashGateCoordinator + TrashGatePopupViewController** — 1, 4번 완료 후
6. **UsageGaugeView** — 5번과 병행 가능
7. **기존 파일 게이트 삽입** — 5번 완료 후
8. **AppDelegate/SceneDelegate 수정** — 4번 완료 후

---

## Phase 2: 구독 + 페이월 + 메뉴 + 축하 + ATT (P2)

P2 기능: US-4(구독), US-5(전면/배너), US-6(ATT), US-7(축하), US-8(메뉴)

### 신규 파일

| 경로 | 역할 | 레이어 |
|------|------|--------|
| `Sources/AppCore/Models/SubscriptionTier.swift` | 구독 티어 모델 | AppCore |
| `Sources/AppCore/Models/DeletionStats.swift` | 삭제 통계 모델 | AppCore |
| `Sources/AppCore/Stores/DeletionStatsStore.swift` | 삭제 통계 관리 | AppCore |
| `Features/Monetization/Subscription/SubscriptionStore.swift` | StoreKit 2 구독 상태 | SweepPic |
| `Features/Monetization/Subscription/PaywallViewController.swift` | 페이월 화면 | SweepPic |
| `Features/Monetization/Subscription/PaywallViewModel.swift` | 가격 포맷팅 | SweepPic |
| `Features/Monetization/Ad/InterstitialAdPresenter.swift` | 전면 광고 | SweepPic |
| `Features/Monetization/Ad/BannerAdViewController.swift` | 배너 광고 | SweepPic |
| `Features/Monetization/Ad/ATTPromptViewController.swift` | ATT 프리프롬프트 | SweepPic |
| `Features/Monetization/Celebration/CelebrationViewController.swift` | 축하 화면 | SweepPic |
| `Features/Monetization/Menu/PremiumMenuViewController.swift` | 프리미엄 서브메뉴 | SweepPic |
| `Features/Monetization/Menu/CustomerServiceViewController.swift` | 고객센터 | SweepPic |
| `Features/Monetization/Menu/FAQViewController.swift` | FAQ 아코디언 | SweepPic |
| `Features/Monetization/Menu/BusinessInfoViewController.swift` | 사업자 정보 | SweepPic |

### 기존 파일 수정

| 파일 | 수정 내용 |
|------|-----------|
| `FeatureFlags.swift` | `isSubscriptionEnabled` 플래그 추가 |
| `TrashGateCoordinator.swift` | SubscriptionStore.isProUser 연동 (Pro면 게이트 스킵) |
| `AdManager.swift` | shouldShowAds()에 구독 상태 반영 |
| `TrashAlbumViewController.swift` | 비우기 성공 후 축하 화면 체인 |
| `TrashStore.swift` | emptyTrash() 완료 시 DeletionStats 갱신 콜백 |
| `GridViewController+Cleanup.swift` | ellipsis 메뉴 재구성 (프리미엄 ▸ / 고객센터 ▸) |
| `AppDelegate.swift` | SubscriptionStore.shared.configure() 추가 |
| `SceneDelegate.swift` | ATT 프롬프트 체크 추가 (sceneDidBecomeActive) |

### Phase 2 내부 구현 순서

1. **SubscriptionTier + SubscriptionStore** — 독립, StoreKit 2 연동
2. **PaywallViewController + ViewModel** — 1번 완료 후
3. **DeletionStats + DeletionStatsStore** — 독립
4. **CelebrationViewController** — 3번 완료 후
5. **TrashGateCoordinator 구독 연동** — 1번 완료 후
6. **InterstitialAdPresenter + BannerAdViewController** — AdManager 이미 있음
7. **ATTPromptViewController** — 독립
8. **메뉴 화면들** (Premium, CustomerService, FAQ, BusinessInfo) — 독립
9. **GridViewController+Cleanup.swift 메뉴 재구성** — 8번 완료 후
10. **기존 파일 수정** (TrashStore 콜백, SceneDelegate ATT 등) — 해당 기능 완료 후

---

## Phase 3: 리뷰 + 분석 + 마무리 (P3)

P3 기능: US-9(리뷰), US-10(분석)

### 신규 파일

| 경로 | 역할 |
|------|------|
| `Sources/AppCore/Services/ReviewService.swift` | 리뷰 요청 조건 평가 |
| `SweepPic/Shared/Analytics/MonetizationAnalytics.swift` | BM 이벤트 로깅 |

### 기존 파일 수정

| 파일 | 수정 내용 |
|------|-----------|
| `TrashGateCoordinator.swift` | 게이트 노출/선택 이벤트 로깅 |
| `AdManager.swift` | 광고 노출/완료 이벤트 로깅 |
| `SubscriptionStore.swift` | 구독 완료 이벤트 로깅 |
| `SceneDelegate.swift` | 세션 시작 시 리뷰 조건 평가 |

---

## 게이지 위치 (삭제대기함)

서브타이틀("N개의 항목") **아래에** 별도 게이지 바를 추가한다.

```
┌─────────────────────────────────┐
│ 삭제대기함           [선택][비우기]│  ← 타이틀 + 버튼
│ 128개의 항목                     │  ← 서브타이틀 (기존 유지)
├─────────────────────────────────┤
│ ████████░░░  5/10장 남음         │  ← 게이지 바 (신규, 탭 가능)
├─────────────────────────────────┤
│ ┌──┐ ┌──┐ ┌──┐                  │
│ │  │ │  │ │  │ (grid)           │
│ └──┘ └──┘ └──┘                  │
└─────────────────────────────────┘
```

- Grace Period 중: 게이지 대신 안내 배너 ("무료 체험 중 — N일 남음")
- Pro 구독자: 게이지 미표시
- Day 4 전환 시: 게이지 첫 표시 + 1회 툴팁
- 게이지 탭: 상세 팝업 (한도 상태 + 광고 잔여 + "광고 보기" 버튼)

---

## 게이트 팝업 UI

기존 앱의 가운데 팝업 패턴과 동일한 커스텀 구현.

```
┌─────────────────────────────────┐
│          (dim background)        │
│                                  │
│    ┌────────────────────────┐    │
│    │                        │    │
│    │  삭제대기함을 비우려면   │    │
│    │  128장 · 한도 5장 남음  │    │
│    │                        │    │
│    │  ┌──────────────────┐  │    │
│    │  │ 🎬 광고 2회 보고  │  │    │  ← Ready/Loading/Failed 상태
│    │  │  128장 전체 삭제  │  │    │
│    │  └──────────────────┘  │    │
│    │                        │    │
│    │  ┌──────────────────┐  │    │
│    │  │ ⭐ Pro로 무제한  │  │    │
│    │  └──────────────────┘  │    │
│    │                        │    │
│    │       [ 닫기 ]         │    │
│    └────────────────────────┘    │
│                                  │
└─────────────────────────────────┘
```

- `modalPresentationStyle = .overFullScreen` + `modalTransitionStyle = .crossDissolve`
- 반투명 배경 + 중앙 라운드 카드
- 광고 버튼 3단계 상태: Ready (활성) / Loading (스피너) / Failed (비활성)
- 리워드 2회 소진 시: 골든 모먼트 (Pro 전환 유도 강조)

---

## 주요 설계 결정 요약

| 항목 | 결정 | 근거 |
|------|------|------|
| 구독 SDK | StoreKit 2 네이티브 | 단일 상품, 서버리스, 비용 절감 |
| 광고 SDK | AdMob 단일 | 출시 후 fill rate 확인 후 미디에이션 추가 |
| 한도 저장 | Keychain | 앱 삭제에도 유지 (악용 방지) |
| 통계 저장 | Documents/JSON | TrashStore 패턴 일관성 |
| 시간 기준 | Supabase 서버 시간 | 시계 조작 방지, 기존 인프라 활용 |
| ATT 시점 | Grace Period 후 첫 앱 실행 | 게이트 스트레스와 분리 |
| 게이트 UI | 커스텀 중앙 팝업 | 기존 앱 UX 패턴과 통일 |
| 게이지 위치 | 서브타이틀 아래 별도 바 | 기존 정보 유지 + 새 정보 추가 |
| 메뉴 구조 | 기존 ellipsis 메뉴에 서브메뉴 추가 | 탭 수 변경 없이 확장 |
| 비우기 방식 | 항상 전체 비우기 | 부분 삭제 없음 (스펙 확정) |

---

## 검증 방법

1. **게이트 전수 테스트**: 2개 삽입 지점(비우기, 선택삭제) 각각에서 한도 초과 시 게이트 팝업 표시
2. **10장 이하 무료 비우기**: 10장 → 게이트 없이 iOS 시스템 팝업만 → 삭제 완료
3. **11장 이상 게이트**: 18장 → 게이트 팝업 → "광고 1회 보고 18장 전체 삭제" → 삭제 완료
4. **광고 불가 상태**: 30장, 리워드 0회 남음 → "Pro만 가능" 표시
5. **리워드 연동**: AdMob 테스트 광고 ID → 시청 완료 → 한도 +10 → 삭제 해방
6. **시스템 팝업 취소**: 광고 시청 후 iOS 팝업 취소 → 리워드 미차감, 한도 미변경
7. **일일 한도 리셋**: 삭제 후 날짜 변경 → 한도 초기화
8. **Grace Period**: 설치 직후 3일간 → 게이트/광고 미표시, 게이지 대신 배너
9. **Grace Period 배너**: 모든 Day 동일 UI — "무료 체험 중 — N일 남음" + 설명 텍스트 (CTA 없음)
10. **구독 구매**: StoreKit Sandbox → Pro 활성화 → 모든 게이트 스킵 + 광고 미표시
11. **구독 환불**: sandbox 환불 → Pro 해제 → Free tier 복귀 (조용히)
12. **갱신 실패**: 뱃지 표시 → 결제 수단 확인 유도
13. **ATT**: Grace Period 만료 후 첫 앱 실행 → 프리프롬프트 → 시스템 팝업
14. **ATT 건너뛰기**: 1차 건너뛰기 → 다음 실행 재표시 → 2차 건너뛰기 → 영구 미표시
15. **축하 화면**: 비우기 성공 → 삭제 장수 + 확보 용량 + 누적 통계
16. **메뉴**: ellipsis → 프리미엄 ▸ (구독관리/복원/리딤) + 고객센터 ▸ (피드백/FAQ/약관/처리방침/사업자정보)
17. **리뷰**: 조건 충족 + 트리거 → 리뷰 팝업, 금지 타이밍에서는 미표시
18. **오프라인**: 한도 내 삭제 정상, 한도 초과 시 광고/구독 비활성

---

## 주의사항

- **TrashAlbumVC 786줄** → 게이트/게이지 로직은 `TrashAlbumViewController+Gate.swift` Extension으로 분리
- **AppCore에 UIKit 불가** → 광고/UI 코드는 반드시 SweepPic 앱 레이어에
- **50줄 이상 수정 전 커밋** (CLAUDE.md 규칙)
- **1,000줄 제한** — 파일별 분할 유지
- **iOS 16~25/26+ 분기** — 게이지/배너가 FloatingUI와 시스템 네비바 양쪽에서 올바르게 표시되는지 확인
- **이중 확인 UX** — 게이트 팝업 + iOS 시스템 팝업은 목적이 다르므로 의도된 동작
- **광고 표시 체인** — 게이트 팝업 dismiss → 광고 present. presenting VC 관리 주의
