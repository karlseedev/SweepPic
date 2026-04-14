# 페이월 Mode A/B 분기 구현 계획

## Context
페이월 화면의 모든 텍스트가 "무료 체험" 중심으로 작성되어 있어, 체험 불가 사용자(재구독자 등)에게도 동일한 문구가 노출됨.
`isEligibleForIntroOffer` 기반으로 페이지 전체 모드를 분기하여, 체험 가능(A) / 구독 중심(B) 두 가지 UX를 제공.

## 모드 기준
- **Mode A (체험 가능)**: `isEligibleForIntroOffer == true` (기본값)
- **Mode B (체험 불가)**: `isEligibleForIntroOffer == false` (비동기 체크 후 전환)

---

## 검토에서 발견한 문제점 3가지

### 문제 1: `proHeader` 라벨에 참조가 없음
비교표의 `proHeader`는 `createComparisonRow()` 내부 로컬 변수로 생성됨. 
`setupComparisonTable()` 이후 텍스트를 바꿀 수 없음.
→ **해결**: `private var proHeaderLabel: UILabel?` 프로퍼티 추가, `createComparisonRow(isHeader: true)` 시 할당

### 문제 2: Mode B 체험 라벨에서 `freeTrialAndPrice()` 사용 불가
`freeTrialAndPrice()`는 `introductoryOffer`가 있어야만 값을 반환함.
Mode B에서는 trial 정보 없이 **가격만** 필요한데, intro offer가 없는 상품이면 nil 반환.
→ **해결**: `updateTrialLabel()` Mode B 분기에서 `freeTrialAndPrice()` 대신 `viewModel.yearlyPriceText`/`monthlyPriceText` 직접 사용

### 문제 3: `cancelAnytime` 키에 `"- "` 접두사가 포함됨
기존 키: `"- 언제든 취소 가능"` / `"- Cancel anytime"`
Mode B에서는 대시 없이 `"언제든 취소 가능"` 필요.
코드에서 문자열 자르기는 취약함.
→ **해결**: Mode B용 신규 키 `cancelAnytime.plain` 추가 (대시 없는 버전)

---

## 텍스트 전체 목록 및 변경 여부

### 변경되는 텍스트 (Mode B용 신규 키 추가) — 총 5개

| # | 기존 키 (Mode A) | Mode A 값 (ko / en) | 신규 키 (Mode B) | Mode B 값 (ko / en) |
|---|---|---|---|---|
| 1 | `headline` | "무료 체험하고\n한 번에 비우세요" / "Start Free Trial and\nClean Up All at Once" | `headline.subscribe` | "Pro로 업그레이드하고\n한 번에 비우세요" / "Upgrade to Pro and\nClean Up All at Once" |
| 2 | `proHeader` | "무료체험(Pro)" / "Free Trial\n(Pro)" | `proHeader.subscribe` | "Pro" / "Pro" |
| 3 | `purchaseButton` | "무료 체험 시작하기" / "Start Free Trial" | `purchaseButton.subscribe` | "구독하기" / "Subscribe Now" |
| 4 | `termsSheet.body` | "무료 체험 기간이 끝나면..." / "Your subscription will automatically begin..." | `termsSheet.body.subscribe` | 체험 언급 제거 버전 |
| 5 | `cancelAnytime` | "- 언제든 취소 가능" / "- Cancel anytime" | `cancelAnytime.plain` | "언제든 취소 가능" / "Cancel anytime" |

### 변경 없는 텍스트 (기존 키 그대로 사용)

| 키 | 값 (ko) | 비고 |
|---|---|---|
| `subheadline` | "Pro 멤버십으로 삭제 한도 없이, 광고 없이" | 양쪽 공통 |
| `freeHeader` | "일반" | 비교표 |
| `tab.monthly` / `tab.yearly` / `tab.popular` | "월간" / "연간" / "인기" | 탭 |
| `securedByApple` | "Apple로 보호됨" | 하단 |
| `terms` | "약관" | 하단 링크 |
| `termsSheet.title` | "이용 약관" | 시트 제목 |
| `restoreButton` | "멤버십 복원" | 복원 |
| `redeemButton` | "리딤 코드" | 리딤 |
| `loadFailed` | "상품 정보를 불러올 수 없습니다" | 에러 |
| `networkError` | "네트워크 연결을 확인해주세요." | 에러 |
| `purchaseError` | "결제를 완료할 수 없습니다..." | 에러 |
| `purchaseFailed` | "결제 실패" | 에러 |
| `askToBuy.title` / `.message` | "승인 대기" / "구매 요청이 전송..." | Ask to Buy |
| `restored.title` / `.message` | "복원 완료" / "Pro멤버십이 복원..." | 복원 성공 |
| `restoreFailed` | "복원 실패" | 복원 실패 |
| `restoreResult.title` / `.notFound` | "복원 결과" / "복원할 멤버십이 없습니다." | 복원 |
| `vm.*` (비교표, 가격 등 전체) | 전체 유지 | 데이터 |

---

## 수정 파일 및 상세

### 1. `Localizable.xcstrings`
5개 신규 키 추가 (ko + en):
- `monetization.paywall.headline.subscribe`
- `monetization.paywall.proHeader.subscribe`
- `monetization.paywall.purchaseButton.subscribe`
- `monetization.paywall.termsSheet.body.subscribe`
- `monetization.paywall.cancelAnytime.plain`

### 2. `PaywallViewController.swift`

#### 2-1. proHeader 라벨 참조 추가
```swift
private var proHeaderLabel: UILabel?
```
`createComparisonRow(isHeader: true)` 내부에서 `self.proHeaderLabel = proLabel` 할당

#### 2-2. `applyMode()` 메서드 신규
`onEligibilityChecked` 콜백과 `updatePriceUI()`에서 호출.
eligibility에 따라 4개 요소 일괄 업데이트:
- `headlineLabel.text` → Mode A / Mode B 키 분기
- `proHeaderLabel?.text` → Mode A / Mode B 키 분기
- `purchaseButton.setTitle()` → Mode A / Mode B 키 분기
- `updateTrialLabel()` 호출 (내부에서 모드 분기)
- (`termsSheet.body`는 `termsTapped()` 시점에 분기 — 별도 프로퍼티 불필요)

#### 2-3. `updateTrialLabel()` 내부 분기
```
Mode A: trialDays(노란색) + cancelNote(흰색) + price(흰색50%) — 기존 로직
Mode B: cancelAnytime.plain(흰색) + " " + price(흰색50%) — 가격은 viewModel에서 직접 조회
```
Mode B는 `freeTrialAndPrice()` 사용하지 않고, `viewModel.yearlyPriceText`/`monthlyPriceText` 직접 사용

#### 2-4. `termsTapped()` 분기
```swift
let legalText = viewModel.isEligibleForIntroOffer
    ? String(localized: "monetization.paywall.termsSheet.body")
    : String(localized: "monetization.paywall.termsSheet.body.subscribe")
```

### 3. `PaywallViewModel.swift`
- 변경 없음 (기존 `isEligibleForIntroOffer` + `onEligibilityChecked` 그대로 활용)
- `yearlyPriceText` / `monthlyPriceText`는 이미 public 접근 가능

---

## 구현 순서
1. `Localizable.xcstrings`에 5개 Mode B 키 추가 (ko + en)
2. `PaywallViewController`에 `proHeaderLabel` 프로퍼티 추가 + `createComparisonRow`에서 할당
3. `applyMode()` 메서드 추가
4. `onEligibilityChecked` 콜백 + `updatePriceUI()`에서 `applyMode()` 호출
5. `updateTrialLabel()` 내부 Mode A/B 분기
6. `termsTapped()` 본문 분기
7. 빌드 확인

## 검증
- 시뮬레이터에서 StoreKit Configuration 사용
- 새 샌드박스 계정(eligible) → Mode A 확인: 체험 텍스트, 버튼, 헤드라인, proHeader 모두 체험 모드
- 기존 샌드박스 계정(not eligible) → Mode B 확인: 구독 모드 텍스트로 전환
- 월간/연간 탭 반복 클릭 → 체험 라벨 안정적 표시
- 약관 시트 → 모드별 다른 본문 노출 확인
