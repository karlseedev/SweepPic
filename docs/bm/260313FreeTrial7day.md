# Grace Period → Apple Free Trial 7일 전환 계획

> 작성일: 2026-03-13
> 근거: [260312research-sales.md](260312research-sales.md) §13 결론
> 상태: 구현 예정

---

## Context

리서치 결론에 따라, 현재 **앱 자체 Grace Period 3일** 모델을 **Apple Free Trial 7일(Opt-out)** 모델로 전환합니다.

- Grace Period 3일은 전환율 최저 구간 (4일 이하 = 26.8~31.2%)
- Day 0 전환 창 미활용 (Day 4+에야 게이트 도달)
- Apple Free Trial 7일이 구현 단순성, 업계 검증, 전환율 측면에서 유리

## 사용자 경험 흐름 변경

**현재:**
```
설치 → 3일 무제한 사용 → Day 4부터 삭제 한도 10/일 + 게이트 팝업
```

**변경 후:**
```
설치 → 첫 삭제대기함 비우기 시도 → 페이월 표시 (7일 무료 체험 강조)
  ├─ 구독 시작 → 7일 무료 체험 (Plus), 이후 자동 과금
  └─ 건너뛰기 → 일일 10장 무료 삭제 + 광고로 최대 30장
```

### 상세 비교

| | 현재 (Grace Period) | 변경 후 (Apple Free Trial) |
|---|------|--------|
| 첫 3일 | 무제한 무료 사용 | 한도 적용 (10장/일) |
| 페이월 첫 노출 | Day 4+ (한도 초과 시) | **첫 삭제 시도 시** (Day 0 가능) |
| 무료 체험 | 앱이 자체 관리 (3일) | **Apple이 관리 (7일)** |
| 체험 중 과금 | 없음 (만료 후 한도만) | **7일 후 자동 과금** (구독 시작한 경우) |
| 체험 안 한 무료 사용자 | Day 4+부터 한도 | **Day 0부터 한도** |
| 삭제대기함 배너 | "무료 체험 중 — N일 남음" | 게이지만 표시 |
| 광고 | Grace Period 중 미표시 | **설치 직후부터 표시** (무료 사용자) |
| ATT 프롬프트 | Grace Period 만료 후 | **설치 후 2시간 경과 후** (무료 사용자만) |

---

## 구현 계획

### Phase 1: GracePeriodService 킬스위치

**파일:** `Sources/AppCore/Services/GracePeriodService.swift`

`isActive`의 첫 줄에 `return false` 추가. 나머지 코드는 A/B 테스트 복원용으로 유지.

### Phase 2: TrashGateCoordinator — 첫 페이월 + Grace Period 분기 제거

**파일:** `PickPhoto/PickPhoto/Features/Monetization/Gate/TrashGateCoordinator.swift`

- Grace Period 분기 제거
- 첫 페이월 분기 추가 (Plus 체크 바로 뒤, 1회만 표시)
  - `hasSeenFirstPaywall` — UserDefaults 기반 플래그
  - 구독 완료 → 바로 삭제 실행
  - 건너뛰기 → 게이트 평가 계속 (한도 체크 → 게이트 팝업)
- 기존 한도 체크 + 게이트 팝업 로직을 `continueGateEvaluation()` 메서드로 추출

### Phase 3: PaywallViewController 콜백 지원

**파일:** `PickPhoto/PickPhoto/Features/Monetization/Subscription/PaywallViewController.swift`

- `onSubscribed` / `onDismissedWithoutSubscription` 콜백 프로퍼티 추가
- `closeTapped()` — dismiss 완료 후 `onDismissedWithoutSubscription` 호출
- `handlePurchaseResult(.success)` — dismiss 완료 후 `onSubscribed` 호출
- `restoreTapped()` 복원 성공 시 — `onSubscribed` 호출
- Swipe-to-Dismiss 대응: `UIAdaptivePresentationControllerDelegate.presentationControllerDidDismiss` 구현

### Phase 4: PaywallSource에 .firstPaywall 추가

**파일:** `PickPhoto/PickPhoto/Shared/Analytics/AnalyticsService+Monetization.swift`

`PaywallSource` enum에 `.firstPaywall = "first_paywall"` 케이스 추가.

### Phase 5: Grace Period 참조 정리

| 파일 | 변경 내용 |
|------|----------|
| `AdManager.swift` | `shouldShowAds()`에서 Grace Period 조건 제거 |
| `ATTStateManager.swift` | Grace Period 조건을 **설치 후 2시간 경과 + !isPlusUser** 조건으로 교체 |
| `SceneDelegate.swift` | `trackGracePeriodEndedOnce()` 호출 제거, Grace Period Analytics extension 주석 처리 |
| `SubscriptionStore.swift` | 구매 완료 후 `endGracePeriod()` 호출 제거 |
| `TrashAlbumViewController+Gate.swift` | Grace Period 배너 분기 제거 → 항상 게이지 표시, `checkGracePeriodTransition()` 비활성화 |
| `TrashAlbumViewController.swift` | `viewWillAppear`에서 `checkGracePeriodTransition()` 호출 제거 |

### Phase 6: PaywallViewModel — eligibility 체크 + 문구 수정

**파일:** `PickPhoto/PickPhoto/Features/Monetization/Subscription/PaywallViewModel.swift`

- **Intro Offer eligibility 체크**: `isEligibleForIntroOffer`로 자격 확인, 미자격자에게는 체험 텍스트 숨김
- **월간 Free Trial 텍스트**: `monthlyFreeTrialText` 프로퍼티 추가
- **법적 고지 수정**: "무료 체험 기간이 끝나면 선택한 요금제로 자동 구독이 시작됩니다" 추가
- **페이월 헤드라인/서브헤드라인, FAQ**: 추후 별도 수정 (이번 구현 범위 외)

### Phase 7: App Store Connect 설정 (코드 외)

- `plus_yearly` 상품: 7일 Free Trial Introductory Offer 설정
- `plus_monthly` 상품: 7일 Free Trial Introductory Offer 설정

---

## 수정 파일 요약

| 파일 | 핵심 |
|------|------|
| `GracePeriodService.swift` | `isActive` → `return false` |
| `TrashGateCoordinator.swift` | 첫 페이월 분기 추가, Grace Period 분기 제거 |
| `PaywallViewController.swift` | onSubscribed/onDismissed 콜백 + swipe-to-dismiss 대응 |
| `PaywallViewModel.swift` | eligibility 체크 + 월간 freeTrialText + 법적 고지 |
| `AnalyticsService+Monetization.swift` | PaywallSource.firstPaywall 추가 |
| `AdManager.swift` | Grace Period 조건 제거 |
| `ATTStateManager.swift` | 설치 후 2시간 + !isPlusUser 조건으로 교체 |
| `SceneDelegate.swift` | Grace Period analytics 제거 |
| `SubscriptionStore.swift` | endGracePeriod 호출 제거 |
| `TrashAlbumViewController+Gate.swift` | 배너 분기 제거, 게이지만 표시 |
| `TrashAlbumViewController.swift` | checkGracePeriodTransition 호출 제거 |

---

## 검증 방법

1. **빌드 확인**: xcodebuild 빌드 성공
2. **첫 삭제 흐름**: 삭제대기함 → 비우기/선택삭제/뷰어삭제 → 페이월 표시 확인
3. **페이월 닫기 후 게이트**: 한도 내 → 삭제 실행, 초과 → 게이트 팝업
4. **Grace Period 배너 미표시**: 삭제대기함에 배너 없고 게이지만 표시
5. **ATT 프롬프트**: 설치 2시간 후 + 무료 사용자만 표시
6. **광고**: 설치 직후부터 무료 사용자에게 표시
7. **eligibility**: 재구독자에게 "무료 체험" 텍스트 미표시 확인
