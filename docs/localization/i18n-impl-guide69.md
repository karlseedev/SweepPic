# SweepPic i18n 구현 가이드 — Phase 6~9

> 이 문서는 Phase 1~5에서 확립된 패턴을 기반으로, Phase 6~9의 i18n 작업을 기계적으로 수행할 수 있도록 작성된 상세 가이드입니다.
> **Phase 1~5는 이미 완료** (커밋 `f6614a0`). 이 가이드는 Phase 6부터 시작합니다.

---

## 0. 사전 준비 — 반드시 읽고 시작

### 0.1 프로젝트 규칙

- **모든 대화는 한글로** (CLAUDE.md)
- **코드 수정 50줄 이상 시 수정 전에 반드시 git 커밋** (CLAUDE.md)
- **파일 1,000줄 초과 금지** (xcstrings는 JSON이므로 예외)
- **주석은 수정하지 않음** — 코드 내 한글 주석은 로컬라이제이션 대상 아님

### 0.2 작업 순서 (매 Phase마다)

```
1. git add -A && git commit -m "checkpoint: Phase N 시작 전 상태"
2. 해당 Phase의 Swift 파일에서 한글 문자열을 String(localized:) 로 교체
3. Localizable.xcstrings에 키 추가 (en + ko)
4. 빌드 확인: xcodebuild -project SweepPic/SweepPic.xcodeproj -scheme SweepPic -destination 'id=60AB1988-BB9D-437A-B1B4-90312F9A5372' build 2>&1 | tail -5
5. git add -A && git commit -m "feat(i18n): Phase N — {대상 기능} ({N}키, {M}파일)"
```

### 0.3 빌드 명령어

```bash
xcodebuild -project SweepPic/SweepPic.xcodeproj \
  -scheme SweepPic \
  -destination 'id=60AB1988-BB9D-437A-B1B4-90312F9A5372' \
  build 2>&1 | tail -5
```

성공 시 `** BUILD SUCCEEDED **` 출력.

---

## 1. 코드 교체 패턴 (Phase 1~5에서 확립)

### 패턴 A: 단순 정적 텍스트

```swift
// BEFORE
titleLabel.text = "무료 삭제 한도 초과"
// AFTER
titleLabel.text = String(localized: "monetization.gate.title")
```

### 패턴 B: 문자열 보간 (Int)

```swift
// BEFORE
label.text = "\(count)장 삭제 완료"
// AFTER
label.text = String(localized: "celebration.sessionCount \(count)")
```

- xcstrings 키에 `%lld` 포함: `"celebration.sessionCount %lld"`
- xcstrings value에 `%lld` 사용

### 패턴 C: 문자열 보간 (String)

```swift
// BEFORE
title = "이어서 정리 (\(dateString) 이전)"
// AFTER
title = String(localized: "faceScan.sheet.continueWithDate \(dateString)")
```

- xcstrings 키에 `%@` 포함: `"faceScan.sheet.continueWithDate %@"`

### 패턴 D: 복합 보간 (여러 매개변수)

```swift
// BEFORE
title = "\(year)년 (이어서: \(dateString) 이전)"
// AFTER
title = String(localized: "faceScan.sheet.yearContinue \(year) \(dateString)")
```

- xcstrings 키: `"faceScan.sheet.yearContinue %lld %@"`
- xcstrings en value: `"%1$lld Continue (before %2$@)"`
- xcstrings ko value: `"%1$lld년 (이어서: %2$@ 이전)"`
- **중요**: 다중 매개변수는 `%1$lld`, `%2$@` 형태로 순서를 명시

### 패턴 E: 날짜 포맷 (locale-aware)

```swift
// BEFORE
formatter.dateFormat = "yyyy년 M월"
// AFTER
formatter.setLocalizedDateFormatFromTemplate("yMMM")
```

- "yyyy년 M월" → `"yMMM"` (en: "Mar 2026", ko: "2026년 3월")
- "M월" → `"MMM"` (en: "Mar", ko: "3월")

### 패턴 F: NSAttributedString 키워드 강조

```swift
// BEFORE
let mainText = "활동 추적을 허용하면\n관련없는 스팸성 광고를 줄여드립니다"
let keyword = "활동 추적을 허용"
// AFTER
let mainText = String(localized: "att.description")
let keyword = String(localized: "att.keyword")
// 강조 로직은 동일하되, keyword fallback 필수:
if let range = mainText.range(of: keyword) {
    attributed.addAttribute(.font, value: boldFont, range: NSRange(range, in: mainText))
}
// range(of:) 실패 시 → 강조 없이 그대로 표시 (크래시 방지)
```

### 패턴 G: computed property로 변경 (필요 시)

```swift
// BEFORE
static let someMessage = "한글 메시지"
// AFTER
static var someMessage: String {
    String(localized: "some.key")
}
```

- `static let`에 `String(localized:)`를 넣으면 앱 시작 시 한 번만 평가됨
- locale 전환이 필요한 경우 `static var` (computed)로 변경

### 패턴 H: 기존 키 재사용

이미 등록된 키는 재사용:
- `"common.cancel"` — "Cancel" / "취소"
- `"common.ok"` — "OK" / "확인"
- `"common.delete"` — "Delete" / "삭제"
- `"common.restore"` — "Restore" / "복구"
- `"common.selectItems"` — "Select Items" / "항목 선택"
- `"common.close"` — "Close" / "닫기"

---

## 2. xcstrings JSON 포맷

### 2.1 기본 엔트리 (단순 텍스트)

```json
"monetization.gate.title" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : { "state" : "translated", "value" : "Free Deletion Limit Reached" }
    },
    "ko" : {
      "stringUnit" : { "state" : "translated", "value" : "무료 삭제 한도 초과" }
    }
  }
}
```

### 2.2 보간 엔트리 (Int 1개)

키 이름에 `%lld` 포함:

```json
"celebration.sessionCount %lld" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : { "state" : "translated", "value" : "%lld Photos Cleaned Up" }
    },
    "ko" : {
      "stringUnit" : { "state" : "translated", "value" : "%lld장 삭제 완료" }
    }
  }
}
```

### 2.3 보간 엔트리 (String 1개)

키 이름에 `%@` 포함:

```json
"faceScan.sheet.continueWithDate %@" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : { "state" : "translated", "value" : "Continue Cleanup (before %@)" }
    },
    "ko" : {
      "stringUnit" : { "state" : "translated", "value" : "이어서 정리 (%@ 이전)" }
    }
  }
}
```

### 2.4 복합 보간 (Int + String)

키에 `%lld %@`, value에 `%1$lld`, `%2$@`:

```json
"faceScan.sheet.yearContinue %lld %@" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : { "state" : "translated", "value" : "%1$lld Continue (before %2$@)" }
    },
    "ko" : {
      "stringUnit" : { "state" : "translated", "value" : "%1$lld년 이어서 (%2$@ 이전)" }
    }
  }
}
```

### 2.5 복합 보간 (Int + Int)

```json
"monetization.gate.adButton %lld %lld" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : { "state" : "translated", "value" : "Watch %1$lld ads to delete all %2$lld photos" }
    },
    "ko" : {
      "stringUnit" : { "state" : "translated", "value" : "광고 %1$lld회 보고 %2$lld장 전체 삭제" }
    }
  }
}
```

### 2.6 파일 구조

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "키1" : { ... },
    "키2" : { ... },
    ...
    "마지막키" : { ... }    ← 마지막 엔트리 뒤에 쉼표 없음
  },
  "version" : "1.0"
}
```

**주의사항:**
- 마지막 엔트리 뒤에는 쉼표(`,`) 없음
- 기존 마지막 엔트리에 쉼표를 추가한 뒤 새 엔트리 삽입
- `extractionState`는 항상 `"manual"`
- `state`는 항상 `"translated"`
- 키 이름 중복 불가 — 추가 전에 기존 키 확인 필수

### 2.7 새 키 삽입 위치

현재 파일 끝부분:
```json
    "마지막기존키" : { ... }
  },                          ← 이 줄의 `},` 직전에서
  "version" : "1.0"
}
```

새 키를 추가할 때:
```json
    "마지막기존키" : { ... },   ← 쉼표 추가
    "새키1" : { ... },
    "새키2" : { ... }           ← 마지막은 쉼표 없음
  },
  "version" : "1.0"
}
```

---

## 3. 키 네이밍 컨벤션

`{feature}.{screen}.{element}.{variant}`

| 접두사 | 대상 기능 |
|--------|----------|
| `faceScan.sheet.*` | FaceScanMethodSheet |
| `faceScan.list.*` | FaceScanListViewController |
| `faceScan.progress.*` | FaceScanProgressBar |
| `faceScan.group.*` | FaceScanGroupCell |
| `faceScan.method.*` | FaceScanMethod (displayTitle) |
| `faceComparison.*` | FaceComparisonViewController |
| `monetization.gate.*` | TrashGatePopupViewController |
| `monetization.gauge.*` | UsageGaugeView |
| `monetization.paywall.*` | PaywallViewController |
| `monetization.paywall.vm.*` | PaywallViewModel |
| `monetization.paywall.tab.*` | PaywallPlanTabView |
| `monetization.faq.*` | FAQViewController |
| `monetization.support.*` | CustomerServiceViewController |
| `monetization.menu.*` | PremiumMenuViewController |
| `monetization.att.*` | ATTPromptViewController |
| `monetization.celebration.*` | CelebrationViewController |
| `monetization.exitSurvey.*` | ExitSurveyViewController |

---

## 4. iOS 26 분기 주의사항 ⚠️

이 프로젝트는 iOS 16~25 (FloatingOverlay 커스텀 UI)와 iOS 26+ (시스템 네비게이션 바)가 분리되어 있습니다.

**같은 한글 문자열이 양쪽 코드 경로에 하드코딩**되어 있을 수 있으므로:

1. 문자열 교체 전에 반드시 `grep -rn "해당한글" SweepPic/SweepPic/` 으로 동일 문자열이 다른 파일에도 있는지 확인
2. `@available(iOS 26.0, *)` 블록 내부도 반드시 확인
3. `#available(iOS 26)` / `#unavailable(iOS 26)` 블록 양쪽 모두 확인

**Phase 6 해당 파일:**
- `FaceScanListViewController.swift` — `@available(iOS 26)` 블록에 "다음 분석" 버튼
- `FaceComparisonViewController.swift` — `@available(iOS 26)` 블록에 타이틀

---

## 5. Phase 6 — FaceScan + SimilarPhoto (~38키)

### 5.1 대상 파일

| 파일 | 경로 (SweepPic/SweepPic/ 기준) |
|------|------|
| FaceScanMethodSheet.swift | Features/FaceScan/UI/ |
| FaceScanListViewController.swift | Features/FaceScan/UI/ |
| FaceScanProgressBar.swift | Features/FaceScan/UI/ |
| FaceScanGroupCell.swift | Features/FaceScan/UI/ |
| FaceScanMethod.swift | Features/FaceScan/Models/ |
| FaceComparisonViewController.swift | Features/SimilarPhoto/UI/ |

### 5.2 문자열 매핑 테이블

> 출처: i18n-strings.md §11, §12

#### FaceScanMethodSheet.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `faceScan.sheet.title` | 인물사진 비교정리 | Compare & Clean Portraits | A |
| `faceScan.sheet.message` | 비슷한 사진에서 같은 인물을\n찾아 얼굴을 비교합니다.\n마음에 들지 않는 사진을\n골라 정리할 수 있어요. | Finds the same person across similar photos\nand compares their faces.\nChoose the ones you don't like\nand clean them up. | A |
| `faceScan.sheet.fromLatest` | 최신사진부터 정리 | Clean Up from Latest | A |
| `faceScan.sheet.continueWithDate %@` | 이어서 정리 (%@ 이전) | Continue Cleanup (before %@) | C |
| `faceScan.sheet.continue` | 이어서 정리 | Continue Cleanup | A |
| `faceScan.sheet.byYear` | 연도별 정리 | Clean Up by Year | A |
| `faceScan.sheet.loading` | 사진별 연도 목록 확인 중 | Checking photo years... | A |
| `faceScan.sheet.yearSelection.title` | 연도 선택 | Select Year | A |
| `faceScan.sheet.yearSelection.message` | 정리할 연도를 선택하세요. | Choose a year to clean up. | A |
| `faceScan.sheet.yearContinue %lld %@` | %1$lld년 (이어서: %2$@ 이전) | %1$lld Continue (before %2$@) | D |
| `faceScan.sheet.yearLabel %lld` | %lld년 | %lld | B |
| *(재사용)* `common.cancel` | 취소 | Cancel | H |

**추가 작업:** `formatDate()` 메서드의 `"yyyy년 M월"` → `setLocalizedDateFormatFromTemplate("yMMM")` (패턴 E)

#### FaceScanListViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `faceScan.list.title` | 인물사진 비교정리 | Compare & Clean Portraits | A |
| `faceScan.list.nextScan` | 다음 분석 | Next Scan | A |
| `faceScan.list.scanning` | 분석 중 | Scanning... | A |
| `faceScan.list.noResults` | 비교할 인물사진 그룹을\n찾지 못했습니다 | No face comparison groups found | A |
| `faceScan.list.closeAlert.title` | 분석이 진행 중입니다 | Scan in Progress | A |
| `faceScan.list.closeAlert.message` | 현재까지의 분석결과는 초기화됩니다 | Current results will be lost | A |
| `faceScan.list.closeAlert.leave` | 나가기 | Leave | A |
| *(재사용)* `common.cancel` | 취소 | Cancel | H |

**⚠️ iOS 26 분기:** "다음 분석" 버튼이 시스템 네비바와 커스텀 헤더 양쪽에 존재할 수 있음 — grep 확인 필수

#### FaceScanProgressBar.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `faceScan.progress.scanning` | 분석 중 | Scanning | A |
| `faceScan.progress.complete` | 분석 완료 | Scan Complete | A |
| `faceScan.progress.completeWithGroups %lld %lld` | · %1$lld그룹 발견(%2$lld장 분석 결과) | · %1$lld groups found (%2$lld photos scanned) | D |
| `faceScan.progress.completeNoGroups %lld` | · 발견된 그룹 없음(%lld장 분석 결과) | · No groups found (%lld photos scanned) | B |
| `faceScan.progress.progressText %lld %lld %lld` | %1$lld그룹 발견 · %2$lld / %3$lld장 검색 | %1$lld groups found · %2$lld / %3$lld scanned | D(3개) |
| `faceScan.progress.completionWithGroups %lld` | 분석 완료 · %lld그룹 발견 | Scan Complete · %lld groups found | B |
| `faceScan.progress.completionNoGroups` | 분석 완료 · 발견된 그룹 없음 | Scan Complete · No groups found | A |

#### FaceScanGroupCell.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `faceScan.group.cleanedUp` | 정리 완료 | Cleaned Up | A |

#### FaceScanMethod.swift (displayTitle)

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `faceScan.method.yearTitle %lld` | %lld년 사진 정리 | %lld Photo Cleanup | B |

**참고:** i18n-strings.md #318에서 이 키는 FaceScanProgressBar 섹션에 있지만, 실제로는 FaceScanMethod.swift의 displayTitle 속성일 수 있음 — 코드 확인 후 올바른 파일에서 수정할 것

#### FaceComparisonViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `faceComparison.title %lld` | 인물사진 비교정리 - 인물 %lld | Face Compare - Person %lld | B |
| `faceComparison.selectFirst` | 사진을 먼저 선택하세요 | Please select photos first | A |
| `faceComparison.applyAlert` | 변경사항을 적용하시겠습니까? | Apply changes? | A |
| `faceComparison.apply` | 적용 | Apply | A |
| *(재사용)* `common.cancel` | 취소 | Cancel | H |
| *(재사용)* `common.selectItems` | 항목 선택 | Select Items | H |
| *(재사용)* `common.selectedCount %lld` | %lld개 선택됨 | %lld Selected | H |
| *(재사용)* `common.delete` | 삭제 | Delete | H |
| *(재사용)* `common.ok` | 확인 | OK | H |

**⚠️ iOS 26 분기:** 타이틀 "인물사진 비교정리 - 인물 N"이 시스템 네비바와 커스텀 헤더 양쪽에 존재할 수 있음

---

## 6. Phase 7 — Monetization Gate/Gauge (~19키)

### 6.1 대상 파일

| 파일 | 경로 (SweepPic/SweepPic/ 기준) |
|------|------|
| TrashGatePopupViewController.swift | Features/Monetization/Gate/ |
| TrashGateCoordinator.swift | Features/Monetization/Gate/ |
| UsageGaugeView.swift | Features/Monetization/Gate/ |

### 6.2 문자열 매핑 테이블

#### TrashGatePopupViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.gate.title` | 무료 삭제 한도 초과 | Free Deletion Limit Reached | A |
| `monetization.gate.info %lld %lld` | 삭제할 사진 %1$lld장 · 무료 삭제 가능 %2$lld장 | %1$lld photos to delete · %2$lld free deletions left | D |
| `monetization.gate.adButton %lld %lld` | 광고 %1$lld회 보고 %2$lld장 전체 삭제 | Watch %1$lld ads to delete all %2$lld photos | D |
| `monetization.gate.proButton` | Pro 멤버십으로 무제한 삭제 | Go Unlimited with Pro | A |
| *(재사용)* `common.close` | 닫기 | Close | H |
| `monetization.gate.adLimitReached` | 오늘 광고 횟수를 모두 사용했습니다 | You've used all ad watches for today | A |
| `monetization.gate.offline` | 인터넷 연결이 필요합니다 | Internet connection required | A |
| `monetization.gate.adLoadFailed` | 광고를 불러올 수 없습니다 | Unable to load ad | A |
| `monetization.gate.referralPromo` | 초대 한 번마다 나도 친구도\nPro 멤버십 14일 무료 제공! | Invite a friend — you both get\n14 days of Pro free! | A |
| `monetization.gate.inviteButton` | 친구 초대하기 | Invite Friends | A |
| `monetization.gate.referralNote` | 이미 Pro멤버십 이용 중이어도 14일 무료 연장 | Already Pro? Get 14 extra days free! | A |
| `monetization.gate.networkError` | 네트워크 상태를 확인하고 다시 시도해주세요. | Please check your network connection and try again. | A |
| `monetization.gate.retry` | 다시 시도 | Try Again | A |

#### TrashGateCoordinator.swift

> 이 파일에 하드코딩된 한글이 있는지 코드에서 확인 필요.
> 없으면 수정 불필요.

#### UsageGaugeView.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.gauge.title` | 무료 삭제 한도 | Free Deletion Limit | A |
| `monetization.gauge.remaining %lld %lld` | %1$lld/%2$lld장 남음 | %1$lld/%2$lld remaining | D |
| `monetization.gauge.watchAd` | 광고 보고 +10장 추가 | Watch Ad for 10 More | A |
| `monetization.gauge.proButton` | Pro 멤버십으로 무제한 삭제 | Go Unlimited with Pro | A |
| `monetization.gauge.adsLeft %lld` | 광고 시청 가능: %lld회 (회당 +10장) | %lld ad watches left (10 photos each) | B |
| `monetization.gauge.noAdsLeft` | 오늘 광고 시청 횟수를 모두 사용했습니다 | You've used all ad watches for today | A |

---

## 7. Phase 8 — Monetization Paywall (~47키)

### 7.1 대상 파일

| 파일 | 경로 (SweepPic/SweepPic/ 기준) |
|------|------|
| PaywallViewController.swift | Features/Monetization/Subscription/ |
| PaywallViewModel.swift | Features/Monetization/Subscription/ |
| PaywallPlanTabView.swift | Features/Monetization/Subscription/ |

### 7.2 문자열 매핑 테이블

#### PaywallViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.paywall.headline` | 무료 체험하고\n한 번에 비우세요 | Start Free Trial\nand Clean Up All at Once | A |
| `monetization.paywall.subheadline` | Pro 멤버십으로 삭제 한도 없이, 광고 없이 | No limits, no ads with Pro | A |
| `monetization.paywall.purchaseButton` | 무료 체험 시작하기 | Start Free Trial | A |
| `monetization.paywall.restoreButton` | 멤버십 복원 | Restore Purchases | A |
| `monetization.paywall.redeemButton` | 리딤 코드 | Redeem Code | A |
| `monetization.paywall.securedByApple` | Apple로 보호됨 | Secured by Apple | A (NSAttributedString 내부) |
| `monetization.paywall.terms` | 약관 | Terms | A |
| `monetization.paywall.proHeader.title` | 무료체험 | Free Trial | A |
| `monetization.paywall.proHeader.badge` | (Pro) | (Pro) | A (한국어는 기존 크기, 그 외 로컬라이즈는 작은 폰트) |
| `monetization.paywall.freeHeader` | 일반 | Free | A |
| `monetization.paywall.restored.title` | 복원 완료 | Restored | A |
| `monetization.paywall.restored.message` | Pro멤버십이 복원되었습니다. | Your purchase has been restored. | A |
| `monetization.paywall.restoreResult.title` | 복원 결과 | Restore Result | A |
| `monetization.paywall.restoreResult.notFound` | 복원할 멤버십이 없습니다. | No purchases to restore. | A |
| `monetization.paywall.askToBuy.title` | 승인 대기 | Awaiting Approval | A |
| `monetization.paywall.askToBuy.message` | 구매 요청이 전송되었습니다.\n보호자의 승인 후 활성화됩니다. | Your purchase request has been sent.\nIt will be activated after approval. | A |
| `monetization.paywall.networkError` | 네트워크 연결을 확인해주세요. | Please check your network connection. | A |
| `monetization.paywall.purchaseError` | 결제를 완료할 수 없습니다.\n다시 시도해주세요. | Unable to complete the purchase.\nPlease try again. | A |
| `monetization.paywall.purchaseFailed` | 결제 실패 | Payment Failed | A |
| `monetization.paywall.loadFailed` | 상품 정보를 불러올 수 없습니다 | Unable to load product info | A |
| *(재사용)* `common.ok` | 확인 | OK | H |
| `monetization.paywall.termsSheet.title` | 이용 약관 | Terms of Use | A |
| `monetization.paywall.restoreFailed` | 복원 실패 | Restore Failed | A |
| `monetization.paywall.cancelAnytime` | - 언제든 취소 가능 | Cancel anytime | A |
| `monetization.paywall.termsSheet.body` | (이용약관 본문 — 긴 텍스트) | (Terms body — long text) | A |

**이용약관 본문 (ko):**
```
무료 체험 기간이 끝나면 선택한 요금제로 자동 구독이 시작됩니다. 구독은 확인 시 Apple ID 계정으로 청구됩니다. 구독은 현재 기간 종료 최소 24시간 전에 해지하지 않으면 자동으로 갱신됩니다. 갱신 비용은 현재 기간 종료 24시간 이내에 청구됩니다. 구독은 구매 후 설정 > Apple ID > 구독에서 관리하고 해지할 수 있습니다. 이용약관 및 개인정보처리방침이 적용됩니다.
```

**이용약관 본문 (en):**
```
Your subscription will automatically begin at the selected plan rate when the free trial ends. Payment will be charged to your Apple ID account upon confirmation. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Renewal will be charged within 24 hours before the end of the current period. You can manage and cancel subscriptions in Settings > [Your Name] > Subscriptions after purchase. Terms of Use and Privacy Policy apply.
```

#### PaywallViewModel.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.paywall.vm.loading` | 로딩 중... | Loading... | A |
| `monetization.paywall.vm.monthlyRate %@` | 월 %@ | %@/month | C |
| `monetization.paywall.vm.yearlyPrice %@` | %@/연 | %@/year | C |
| `monetization.paywall.vm.monthlyPrice %@` | %@/월 | %@/month | C |
| `monetization.paywall.vm.trialDays %lld` | %lld일 무료체험 | %lld-day free trial | B |
| `monetization.paywall.vm.trialMonths %lld` | %lld개월 무료체험 | %lld-month free trial | B |
| `monetization.paywall.vm.trialYears %lld` | %lld년 무료체험 | %lld-year free trial | B |
| `monetization.paywall.vm.featureDailyDeletes` | 일일 삭제 | Daily Deletes | A |
| `monetization.paywall.vm.free10` | 10장 | 10 photos | A |
| `monetization.paywall.vm.unlimited` | 무제한 | Unlimited | A |
| `monetization.paywall.vm.featureAds` | 광고 | Ads | A |
| `monetization.paywall.vm.adsShown` | 있음 | Shown | A |
| `monetization.paywall.vm.adsNone` | 없음 | None | A |
| `monetization.paywall.vm.featureFaceCompare` | 인물사진 비교정리 | Face Comparison | A |
| `monetization.paywall.vm.withAds` | 광고포함 | With Ads | A |
| `monetization.paywall.vm.adFree` | 광고없음 | Ad-Free | A |
| `monetization.paywall.vm.featureFaceZoom` | 얼굴 인식 확대 | Face Zoom | A |
| `monetization.paywall.vm.productError` | 상품 정보를 불러올 수 없습니다. 네트워크 연결을 확인해주세요. | Unable to load product info. Please check your network connection. | A |

#### PaywallPlanTabView.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.paywall.tab.monthly` | 월간 | Monthly | A |
| `monetization.paywall.tab.yearly` | 연간 | Yearly | A |
| `monetization.paywall.tab.popular` | 인기 | Most Popular | A |

---

## 8. Phase 9 — Monetization FAQ/기타 (~61키)

### 8.1 대상 파일

| 파일 | 경로 (SweepPic/SweepPic/ 기준) |
|------|------|
| FAQViewController.swift | Features/Monetization/Menu/ |
| CustomerServiceViewController.swift | Features/Monetization/Menu/ |
| PremiumMenuViewController.swift | Features/Monetization/Menu/ |
| ExitSurveyViewController.swift | Features/Monetization/Menu/ |
| ATTPromptViewController.swift | Features/Monetization/Ad/ |
| CelebrationViewController.swift | Features/Monetization/Celebration/ |

> **BusinessInfoViewController.swift** — ko locale 전용, 로컬라이제이션 **제외** (수정하지 않음)

### 8.2 문자열 매핑 테이블

#### FAQViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.faq.title` | 자주 묻는 질문 | FAQ | A |
| `monetization.faq.section.photos` | 사진/기능 | Photos & Features | A |
| `monetization.faq.section.billing` | 멤버십/결제 | Membership & Billing | A |
| `monetization.faq.section.privacy` | 개인정보/보안 | Privacy & Security | A |
| `monetization.faq.q1` | 삭제한 사진을 복구할 수 있나요? | Can I recover deleted photos? | A |
| `monetization.faq.a1` | 삭제대기함에 있는 사진은 언제든 복구할 수 있습니다. 삭제대기함을 비운 후에는 최근 삭제된 항목(iOS 기본 사진 앱)에서 30일 이내에 복구 가능합니다. | Photos in Trash can be restored anytime. After emptying Trash, you can recover them within 30 days from "Recently Deleted" in the Photos app. | A |
| `monetization.faq.q2` | 내 사진이 외부 서버로 전송 또는 유출되나요? | Are my photos sent to or leaked to external servers? | A |
| `monetization.faq.a2` | 아니요. 모든 사진 처리(유사 사진 분석, 얼굴 감지 포함)는 기기 내에서만 이루어집니다. 사진 데이터는 외부 서버로 전송되지 않습니다. | No. All photo processing (including similarity analysis and face detection) happens entirely on your device. No photo data is sent to external servers. | A |
| `monetization.faq.q3` | 지원하는 iOS 버전은? | What iOS versions are supported? | A |
| `monetization.faq.a3` | iOS 16 이상을 지원합니다. | Requires iOS 16 or later. | A |
| `monetization.faq.q4` | 인물사진 비교정리가 정확하지 않아요 | Compare & Clean Portraits isn't accurate | A |
| `monetization.faq.a4` | 인물사진 비교정리는 사진의 화질, 얼굴 각도, 얼굴 위치 등에 따라 일부 오분류가 있을 수 있습니다. 삭제 전 반드시 확인하시고, 실수로 삭제해도 삭제대기함에서 복구할 수 있습니다. | Compare & Clean Portraits may occasionally misclassify due to photo quality, face angle, or face position. Always review before deleting. Accidentally deleted photos can be restored from Trash. | A |
| `monetization.faq.q5` | 자동 정리는 어떤 기준으로 사진을 선택하나요? | How does Auto Cleanup select photos? | A |
| `monetization.faq.a5` | 유사 사진 그룹에서 화질, 초점, 구도 등을 분석하여 가장 좋은 사진을 남기고 나머지를 삭제대기함으로 이동합니다. 바로 삭제되지 않으니 안심하세요. | It analyzes quality, focus, and composition in similar photo groups, keeps the best one, and moves the rest to Trash. Don't worry — nothing is permanently deleted. | A |
| `monetization.faq.q6` | 무료로 사용할 수 있나요? | Can I use it for free? | A |
| `monetization.faq.a6` | 네. 사진 정리(스와이프 삭제, 유사 사진 분석, 자동 정리, 복구)는 모두 무료입니다. 삭제대기함 비우기에만 일일 한도(10장)가 있으며, 광고를 보면 추가 삭제가 가능합니다. | Yes. Photo organizing (swipe delete, similarity analysis, auto cleanup, restore) is entirely free. Only emptying Trash has a daily limit (10 photos), and you can watch ads for more. | A |
| `monetization.faq.q7` | 멤버십 가입했는데 멤버십이 활성화되지 않아요 | I subscribed but my membership isn't active | A |
| `monetization.faq.a7` | 전체 메뉴 > 멤버십 > "멤버십 복원"을 탭해주세요. 네트워크 연결 상태를 확인하고, 결제에 사용한 Apple ID로 로그인되어 있는지 확인해주세요. | Go to Menu > Membership > "Restore Purchases". Check your network connection and make sure you're signed in with the Apple ID used for the purchase. | A |
| `monetization.faq.q8` | 멤버십을 해지하고 싶어요 | I want to cancel my membership | A |
| `monetization.faq.a8` | 설정 > [내 이름] > 구독 > SweepPic Pro > 구독 취소를 탭하세요. 앱을 삭제해도 자동으로 해지되지 않으니 반드시 위 경로에서 취소해주세요. | Go to Settings > [Your Name] > Subscriptions > SweepPic Pro > Cancel. Deleting the app does not cancel your subscription, so please use the path above. | A |
| `monetization.faq.q9` | 환불받을 수 있나요? | Can I get a refund? | A |
| `monetization.faq.a9` | 환불은 Apple을 통해 처리됩니다. reportaproblem.apple.com에서 신청해주세요. | Refunds are handled by Apple. Please visit reportaproblem.apple.com. | A |
| `monetization.faq.q10` | 삭제 한도가 뭔가요? | What is the deletion limit? | A |
| `monetization.faq.a10 %lld %lld` | 무료 사용자는 하루 %1$lld장까지 삭제대기함 비우기가 가능합니다. 광고를 보면 하루 최대 %2$lld장까지 늘릴 수 있고, Pro멤버십 가입 시 무제한입니다. 한도는 매일 자정에 초기화됩니다. | Free users can empty up to %1$lld photos from Trash per day. Watching ads increases this to %2$lld/day. Pro members have no limit. The limit resets daily at midnight. | D |
| `monetization.faq.q11` | 얼굴 인식 데이터는 어떻게 처리되나요? | How is face recognition data handled? | A |
| `monetization.faq.a11` | 얼굴 감지는 기기의 Vision 프레임워크를 사용하며, 기기 내에서만 처리됩니다. 얼굴 데이터는 서버에 전송되거나 저장되지 않습니다. | Face detection uses the device's Vision framework and is processed entirely on-device. No face data is sent to or stored on any server. | A |

**참고:** FAQ a10에서 `{dailyFreeLimit}`과 `{maxDailyTotal}`은 코드에서 실제 변수명 확인 필요. Int 보간이면 `%lld`.

#### CustomerServiceViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.support.title` | 고객센터 | Support | A |
| `monetization.support.email` | 이메일 문의하기 | Contact Us | A |
| `monetization.support.emailSubject` | [SweepPic] 문의하기 | [SweepPic] Support Request | A |
| `monetization.support.faq` | 자주 묻는 질문 | FAQ | A |
| `monetization.support.terms` | 이용약관 | Terms of Use | A |
| `monetization.support.privacy` | 개인정보처리방침 | Privacy Policy | A |
| `monetization.support.appVersion` | 앱 버전: | App Version: | A |
| `monetization.support.device` | 기기: | Device: | A |
| `monetization.support.deviceName` | 기기명: | Device Name: | A |
| `monetization.support.supportId` | 지원 ID: | Support ID: | A |

**참고:** "사업자 정보"(#193)는 ko locale 전용 → 메뉴 숨김 처리 필요 (i18n과 별도로 locale 분기 코드 필요할 수 있음)

#### PremiumMenuViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.menu.title` | 멤버십 | Membership | A |
| `monetization.menu.manage` | 멤버십 관리 | Manage Membership | A |
| `monetization.menu.restore` | 멤버십 복원 | Restore Purchases | A |
| `monetization.menu.redeem` | 리딤 코드 | Redeem Code | A |
| `monetization.menu.alreadyPro` | 이미 멤버십 이용 중입니다 | You already have a membership | A |
| `monetization.menu.restored` | 멤버십이 복원되었습니다 | Purchase has been restored | A |
| `monetization.menu.notFound` | 복원할 멤버십이 없습니다 | No purchases to restore | A |
| `monetization.menu.restoreFailed` | 복원 실패: 네트워크를 확인해주세요 | Restore failed: Please check your network connection | A |

#### ATTPromptViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.att.title` | 광고 맞춤 설정 | Ad Personalization | A |
| `monetization.att.description` | 활동 추적을 허용하면\n관련없는 스팸성 광고를 줄여드립니다 | Allow tracking to see\nfewer irrelevant ads | A |
| `monetization.att.keyword` | 활동 추적을 허용 | Allow tracking | A (keyword 강조용) |
| `monetization.att.continue` | 계속 | Continue | A |
| `monetization.att.skip` | 건너뛰기 | Skip | A |

**참고:** description + keyword는 패턴 F (NSAttributedString 키워드 강조) 적용. keyword fallback 코드 필수.

#### CelebrationViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| *(재사용)* `common.ok` | 확인 | OK | H |
| `monetization.celebration.sessionCount %lld` | %lld장 삭제 완료 | %lld Photos Cleaned Up | B |
| `monetization.celebration.totalCount %lld` | SweepPic에서 총 %lld장 삭제 | %lld photos cleaned up with SweepPic | B |
| `monetization.celebration.freed %@` | %@ 확보 | %@ freed | C |

#### ExitSurveyViewController.swift

| 키 | 한국어 | 영어 | 패턴 |
|---|---|---|---|
| `monetization.exitSurvey.title` | 왜 해지하셨나요? | Why did you cancel? | A |
| `monetization.exitSurvey.subtitle` | 더 나은 서비스를 위해 사유를 알려주세요 | Help us improve by sharing your reason | A |
| `monetization.exitSurvey.tooExpensive` | 가격이 부담돼요 | It's too expensive | A |
| `monetization.exitSurvey.freeEnough` | 무료로도 충분해요 | The free plan is enough | A |
| `monetization.exitSurvey.doneOrganizing` | 사진 정리를 다 했어요 | I've finished organizing my photos | A |
| `monetization.exitSurvey.usingOther` | 다른 앱을 사용해요 | I'm using a different app | A |
| `monetization.exitSurvey.other` | 기타 | Other | A |
| `monetization.exitSurvey.placeholder` | 사유를 입력해주세요 | Please enter your reason | A |
| `monetization.exitSurvey.submit` | 제출 | Submit | A |

---

## 9. 체크리스트 (매 Phase 완료 후)

- [ ] 모든 한글 문자열이 `String(localized:)` 로 교체되었는가?
- [ ] 주석 내 한글은 건드리지 않았는가?
- [ ] xcstrings에 추가한 키에 오타가 없는가?
- [ ] xcstrings JSON 문법 오류 없는가? (쉼표, 괄호 등)
- [ ] 보간 변수 타입이 올바른가? (Int → `%lld`, String → `%@`)
- [ ] 다중 매개변수 순서가 `%1$`, `%2$` 등으로 명시되어 있는가?
- [ ] 기존 키를 재사용할 수 있는 곳에서 재사용했는가?
- [ ] iOS 26 분기 양쪽 코드 경로 모두 확인했는가?
- [ ] grep으로 동일 한글이 다른 파일에 남아있지 않은지 확인했는가?
- [ ] 날짜 포맷이 `setLocalizedDateFormatFromTemplate`로 변경되었는가?
- [ ] NSAttributedString 키워드 강조에 fallback이 있는가?
- [ ] 빌드가 성공하는가?

---

## 10. 자주 실수하는 것 (반드시 읽기)

1. **xcstrings 마지막 쉼표**: 마지막 엔트리 뒤에 쉼표를 넣으면 JSON 파싱 에러 → 빌드 실패
2. **키 이름의 보간 형식**: Swift 코드에서 `String(localized: "key \(intVar)")` 이면 xcstrings 키는 `"key %lld"` (Int), `"key %@"` (String)
3. **`%lld` vs `%d`**: Swift의 `String(localized:)`는 Int에 `%lld` 사용 (`%d` 아님)
4. **다중 보간 순서**: `String(localized: "key \(a) \(b)")` → 키 `"key %lld %@"` → value에서 `%1$lld`, `%2$@`로 순서 명시
5. **iOS 26 분기 누락**: 한쪽 코드 경로만 수정하고 다른 쪽을 놓치면 런타임에 한글이 그대로 노출
6. **`static let` vs `static var`**: 로컬라이즈된 문자열을 반환하는 상수는 `static var` (computed)로 변경해야 locale 전환 시 반영
7. **기존 키 중복 생성**: `common.cancel`, `common.ok` 등은 이미 xcstrings에 존재 — 중복 추가하면 JSON 오류
8. **줄바꿈 이스케이프**: xcstrings JSON value 안에서 줄바꿈은 `\n`으로 이스케이프
9. **빈 문자열**: `""` 빈 값을 xcstrings에 넣지 말 것
10. **BusinessInfoViewController**: ko locale 전용 → 이 파일은 **절대 수정하지 말 것**

---

## 11. 코드 조사 보충 — 에이전트 검증 결과 (줄번호 포함)

> i18n-strings.md에 없거나 다르게 존재하는 문자열을 실제 코드에서 발견한 내용을 정리합니다.

### 11.1 Phase 6 보충

#### FaceScanListViewController.swift — 추가 발견

| 줄번호 | 한글 문자열 | 비고 |
|--------|-----------|------|
| 121 | 분석 중 | emptyLabel 초기 텍스트 (i18n-strings.md #305와 동일) |
| 148 | 인물사진 비교정리 | viewDidLoad navigation title |
| **262** | **다음 분석** | **⚠️ iOS 26 네비바 우측 버튼** |
| **321** | **인물사진 비교정리** | **⚠️ iOS 16~25 커스텀 헤더 타이틀** |
| **327** | **다음 분석** | **⚠️ iOS 16~25 커스텀 헤더 우측 버튼** |
| **377** | **인물비교정리를 종료하시겠습니까?** | **⚠️ i18n-strings.md에 없음 — 분석 완료 후 닫기 alert** |
| 389 | 분석이 진행 중입니다 | 분석 중 닫기 alert 제목 |
| 390 | 현재까지의 분석결과는 초기화됩니다 | 분석 중 닫기 alert 메시지 |
| 381, 393 | 나가기 | alert destructive 버튼 (2곳) |
| 384, 396 | 취소 | alert cancel 버튼 (2곳) |
| 429 | 분석 중 | 다음 분석 탭 후 emptyLabel |
| 579 | 비교할 인물사진 그룹을\n찾지 못했습니다 | 결과 없음 emptyLabel |

**누락 키 추가 필요:**
```
faceScan.list.closeComplete.title = "인물비교정리를 종료하시겠습니까?" / "Close Face Comparison?"
faceScan.list.closeComplete.leave = "나가기" / "Leave"
```
(분석 완료 후 닫기 alert — 분석 중 닫기 alert과 별도)

#### FaceScanProgressBar.swift — 추가 발견

| 줄번호 | 한글 문자열 | 비고 |
|--------|-----------|------|
| **107** | **분석 준비 중** | **i18n-strings.md에 없음 — Phase A preparing 상태** |
| 117 | 분석 중 | Phase C analyzing 상태 |
| **139** | **분석 준비 중** | **reset() 메서드 초기화 텍스트** |
| 158 | 분석 완료 | showCompletion() |
| 154 | · {N}그룹 발견({M}장 분석 결과) | showCompletion() (groupCount > 0) |
| 155 | · 발견된 그룹 없음({M}장 분석 결과) | showCompletion() (groupCount == 0) |

**누락 키 추가 필요:**
```
faceScan.progress.preparing = "분석 준비 중" / "Preparing..."
```

#### FaceScanMethod.swift — `description` vs `displayTitle` 구분

| 줄번호 | 한글 문자열 | 프로퍼티 | 처리 방식 |
|--------|-----------|---------|---------|
| 98 | 최신사진부터 스캔 | `description` (CustomStringConvertible) | **로그 전용 → 영문 직접 교체** (String Catalog 미등록) |
| 100 | 이어서 스캔 | `description` | **로그 전용 → 영문 직접 교체** |
| 102 | {N}년 사진 스캔 | `description` | **로그 전용 → 영문 직접 교체** |
| 115 | 최신사진부터 정리 | `displayTitle` | **UI 노출 → String(localized:)** |
| 117 | 이어서 정리 | `displayTitle` | **UI 노출 → String(localized:)** |
| 119 | {N}년 사진 정리 | `displayTitle` | **UI 노출 → String(localized:)** |

**displayTitle 키 추가 필요:**
```
faceScan.method.fromLatest = "최신사진부터 정리" / "Clean Up from Latest"
faceScan.method.continue = "이어서 정리" / "Continue Cleanup"
faceScan.method.yearTitle %lld = "%lld년 사진 정리" / "%lld Photo Cleanup"
```

**description은 영문으로 직접 교체:**
```swift
// BEFORE: case .fromLatest: return "최신사진부터 스캔"
// AFTER:  case .fromLatest: return "Scan from Latest"
```

#### FaceComparisonViewController.swift — iOS 26 분기 상세

| 줄번호 | 한글 문자열 | 코드 경로 |
|--------|-----------|---------|
| **512** | 인물사진 비교정리 - 인물 {N} | **iOS 16~25 커스텀 헤더 (updateTitleBar)** |
| **524** | 인물사진 비교정리 - 인물{N} | **iOS 26+ 시스템 네비바 (updateNavigationTitle)** |

**주의:** 두 문자열이 미세하게 다를 수 있음 (공백 차이 등) — 동일한 키를 사용하되 양쪽 모두 교체 확인

---

### 11.2 Phase 7 보충

#### TrashGateCoordinator.swift — 한글 문자열 존재 확인

| 줄번호 | 한글 문자열 | 컨텍스트 |
|--------|-----------|---------|
| 341 | 광고를 불러올 수 없습니다 | 광고 로드 실패 alert 제목 |
| 342 | 네트워크 상태를 확인하고 다시 시도해주세요. | alert 메시지 |
| 347 | 다시 시도 | alert 재시도 액션 |
| 359 | 취소 | alert 취소 액션 (→ common.cancel 재사용) |

**가이드 본문의 "한글이 있는지 코드에서 확인 필요" → 확인 완료, 4개 존재**

#### UsageGaugeView.swift — UsageGaugeDetailPopup 내부 클래스 포함

UsageGaugeView.swift 안에 `UsageGaugeDetailPopup` 내부 클래스가 존재하며 추가 문자열이 있음:

| 줄번호 | 한글 문자열 | 컨텍스트 |
|--------|-----------|---------|
| 264 | 무료 삭제 한도 | 팝업 제목 (titleLabel) — gauge title과 동일 키 재사용 가능 |
| 286 | 광고 보고 +10장 추가 | 광고 버튼 |
| 299 | Pro 멤버십으로 무제한 삭제 | Pro 버튼 |
| 312 | 닫기 | 팝업 닫기 버튼 (→ common.close 재사용) |
| 335 | 초대 한 번마다 나도 친구도\nPro 멤버십 14일 무료 제공! | referral 프로모 라벨 |
| 348 | 친구 초대하기 | 초대 버튼 |
| 360 | 이미 Pro멤버십 이용 중이어도 14일 무료 연장 | 부가 문구 |

**Referral 프로모 문자열은 TrashGatePopupViewController와 동일** — 같은 키 재사용 권장:
- `monetization.gate.referralPromo`
- `monetization.gate.inviteButton`
- `monetization.gate.referralNote`

---

### 11.3 Phase 8 보충

#### PaywallViewController.swift — 접근성 문자열 (Phase 11 범위)

> ⚠️ 아래 접근성 문자열은 **Phase 11에서 처리**. Phase 8에서는 건드리지 않음.

| 줄번호 | 한글 | 용도 |
|--------|-----|------|
| 397 | "\(feature), 무료: \(freeValue), Pro: \(proValue)" | 비교표 행 accessibilityLabel |
| 537 | 삭제대기함 비우기 안내 | cardView accessibilityLabel |
| 740 | 닫기 | closeButton accessibilityLabel |
| 741 | 페이월 화면을 닫습니다 | closeButton accessibilityHint |
| 742 | 멤버십 플랜 선택 | planTab accessibilityLabel |
| 743 | 무료 체험 시작하기 | purchaseButton accessibilityLabel |
| 744 | 멤버십 복원 | restoreButton accessibilityLabel |
| 745 | 이전에 구매한 멤버십을 복원합니다 | restoreButton accessibilityHint |
| 746 | 리딤 코드 입력 | redeemButton accessibilityLabel |
| 747 | 프로모션 코드를 입력합니다 | redeemButton accessibilityHint |

#### PaywallViewController.swift — 로그 메시지 (제외)

| 줄번호 | 문자열 | 처리 |
|--------|-------|------|
| 725 | "상품 로드 실패 — StoreKit Configuration 확인 필요" | **로그 전용 → 영문 직접 교체** (Phase 12 또는 Phase 8에서 함께 처리) |

#### PaywallViewModel.swift — 가격 포맷 세부 줄번호

| 줄번호 | 한글 | 영어 |
|--------|-----|------|
| 66, 72 | 로딩 중... | Loading... |
| 86 | 월 \(formatted) | \(formatted)/month |
| 129 | - 언제든 취소 가능 | Cancel anytime |
| 136, 139 | \(N)일 무료체험 | \(N)-day free trial |
| 141 | \(N)개월 무료체험 | \(N)-month free trial |
| 143 | \(N)년 무료체험 | \(N)-year free trial |

---

### 11.4 Phase 9 보충

#### FAQViewController.swift — 접근성 문자열 (Phase 11 범위)

| 줄번호 | 한글 | 용도 |
|--------|-----|------|
| 294 | 탭하면 답변을 접습니다 | FAQ 셀 accessibilityHint (expanded) |
| 294 | 탭하면 답변을 펼칩니다 | FAQ 셀 accessibilityHint (collapsed) |

#### FAQViewController.swift — 보간 변수 세부

FAQ a10 (줄 89)의 보간 변수:
```swift
"...하루 \(UsageLimit.dailyFreeLimit)장까지... 최대 \(UsageLimit.maxDailyTotal)장까지..."
```
→ 키: `monetization.faq.a10 %lld %lld`

#### CustomerServiceViewController.swift — 이메일 본문 포맷

줄 166의 디바이스 정보 문자열은 **한 덩어리**로 구성:
```swift
"앱 버전: \(appVersion) (\(buildNumber))\niOS: \(osVersion)\n기기: \(model)\n기기명: \(name)\n지원 ID: \(userId)"
```

**처리 방안 2가지:**
- A) 전체를 하나의 키로: `monetization.support.deviceInfo %@ %@ %@ %@ %@ %@` — 복잡
- **B) 라벨별 개별 키** (권장): 가이드 본문의 `monetization.support.appVersion`, `.device`, `.deviceName`, `.supportId` 키를 사용하여 Swift 코드에서 조합

#### CustomerServiceViewController.swift — 이메일 제목

```swift
// 이메일 제목: "[SweepPic] 문의하기"
// → key: monetization.support.emailSubject = "[SweepPic] 문의하기" / "[SweepPic] Support Request"
```

실제 코드에서 이메일 제목이 별도 줄에 있는지 확인 필요 (에이전트가 줄번호를 명시하지 않음).

#### CelebrationViewController.swift — referral 프로모 문자열

| 줄번호 | 한글 | 비고 |
|--------|-----|------|
| 126 | 초대 한 번마다 나도 친구도\nPro 멤버십 14일 무료 제공! | referralLabel — TrashGatePopup과 동일 키 재사용 |
| 137 | 이미 Pro멤버십 이용 중이어도 14일 무료 연장 | referralSubtitleLabel — TrashGatePopup과 동일 키 재사용 |
| 149, 156 | 친구 초대하기 | referralButton — TrashGatePopup과 동일 키 재사용 |

**→ 아래 키를 TrashGatePopup/UsageGauge/Celebration 3곳에서 재사용:**
- `monetization.gate.referralPromo`
- `monetization.gate.inviteButton`
- `monetization.gate.referralNote`

#### CelebrationViewController.swift — 접근성 문자열 (Phase 11 범위)

| 줄번호 | 한글 | 용도 |
|--------|-----|------|
| 157 | 초대 설명 화면으로 이동합니다 | referralButton accessibilityHint |
| 265 | 확인 | confirmButton accessibilityLabel |
| 266 | 축하 화면을 닫습니다 | confirmButton accessibilityHint |
| 285-287 | (sessionLabel, totalDeletedRow, totalFreedRow의 accessibilityLabel) | UI 라벨과 동일 값 — UI 키 재사용 |

#### ATTPromptViewController.swift — 접근성 문자열 (Phase 11 범위)

| 줄번호 | 한글 | 용도 |
|--------|-----|------|
| 205 | 광고 맞춤 설정 아이콘 | iconImageView accessibilityLabel |
| 206 | 계속하여 추적 허용 여부 선택 | continueButton accessibilityLabel |
| 207 | 건너뛰기 | skipButton accessibilityLabel |

---

### 11.5 Referral 프로모 문자열 재사용 정리

아래 3개 문자열은 **3개 파일**에서 동일하게 사용됨 (키 1개씩만 등록, 3곳에서 재사용):

| 키 | 사용 파일 |
|---|---------|
| `monetization.gate.referralPromo` | TrashGatePopupViewController, UsageGaugeView(팝업), CelebrationViewController |
| `monetization.gate.inviteButton` | 위와 동일 3곳 |
| `monetization.gate.referralNote` | 위와 동일 3곳 |

---

### 11.6 접근성 문자열 처리 원칙

Phase 7-9 파일에서 발견된 접근성 문자열(accessibilityLabel, accessibilityHint)은 **Phase 11 범위**입니다.

**Phase 7-9에서는 건드리지 않음.** Phase 11에서 일괄 처리 예정.

단, **UI 라벨과 동일한 접근성 라벨**은 UI 키를 재사용하므로 Phase 11에서 자동으로 해결됩니다.

---

## 12. Phase 10 — Referral + 공유 메시지 (~65키)

### 12.1 대상 파일

| 파일 | 경로 (SweepPic/SweepPic/ 기준) |
|------|------|
| ReferralMenuViewController.swift | Features/Referral/Menu/ |
| ReferralExplainViewController.swift | Features/Referral/Share/ |
| ReferralShareManager.swift | Features/Referral/Share/ |
| ReferralCodeInputViewController.swift | Features/Referral/CodeInput/ |
| ReferralRewardViewController.swift | Features/Referral/Reward/ |
| ReferralRewardClaimManager.swift | Features/Referral/Reward/ |

### 12.2 핵심 규칙

- **공유 메시지**: 보내는 사람 기기 locale 기준 → `String(localized:)` 사용 (패턴 A)
- **Referral 프로모 문자열** (3곳 재사용): Phase 7에서 등록한 `monetization.gate.referralPromo/inviteButton/referralNote` 키 재사용. CelebrationViewController에도 있으므로 이 3키를 그대로 참조
- **에러 메시지**: ReferralCodeInput/RewardVC에서 서버 에러를 표시하는 부분은 Phase 12에서 처리하므로, **Phase 10에서는 UI 문자열만 교체**. 서버 에러 관련 한글(`"서버에 연결할 수 없습니다"` 등)은 건드리지 않음

### 12.3 문자열 매핑 — i18n-strings.md §14 참조

> 전체 매핑은 i18n-strings.md §14 (Referral) 참조. 아래는 키 접두사만 정리.

| 접두사 | 파일 | 대략 키 수 |
|--------|------|---------|
| `referral.menu.*` | ReferralMenuViewController | 4키 |
| `referral.explain.*` | ReferralExplainViewController | ~20키 (Push 프리프롬프트 포함) |
| `referral.codeInput.*` | ReferralCodeInputViewController | ~20키 |
| `referral.reward.*` | ReferralRewardViewController | ~12키 |
| `referral.share.*` | ReferralShareManager | ~2키 (제목 + 본문) |

### 12.4 공유 메시지 (ReferralShareManager) 특수 처리

공유 본문은 긴 멀티라인 텍스트. xcstrings에 하나의 키로 등록:

```swift
// BEFORE
let body = "편리한 사진 정리 앱 SweepPic을 추천합니다!\n..."
// AFTER
let body = String(localized: "referral.share.body \(referralCode) \(shareURL)")
```

xcstrings 키: `"referral.share.body %@ %@"`
- en value에 `%1$@` (referralCode), `%2$@` (shareURL)
- ko value에도 동일 위치에 `%1$@`, `%2$@`
- **영문/한글 본문은 i18n-strings.md #402 참조** (이미 전문 작성됨)

### 12.5 Phase 10에서 건드리지 않는 것

- 서버 에러 메시지 표시 로직 (Phase 12)
- 접근성 문자열 (Phase 11)
- ReferralRewardClaimManager의 에러 매핑 함수 (Phase 11)

---

## 13. Phase 11 — 접근성 전용 + 사용자 노출 에러 매핑 (~35키)

### 13.1 대상 파일

**접근성 (이미 터치한 파일 재방문):**

| 파일 | 접근성 한글 수 |
|------|-------------|
| PhotoCell.swift | 2키 |
| FaceButtonOverlay.swift | 2키 |
| PaywallViewController.swift | ~8키 |
| CelebrationViewController.swift | ~4키 |
| ATTPromptViewController.swift | ~3키 |
| FAQViewController.swift | 2키 |

**에러 매핑 (errorDescription 제거 + 앱측 매핑):**

| 파일 | 작업 |
|------|------|
| CleanupImageLoader.swift | `errorDescription` 제거 |
| VideoFrameExtractor.swift | `errorDescription` 제거 |
| [AppCore] PromotionalOfferService.swift | `errorDescription` 제거 |
| QualityAnalyzer.swift | 에러 표시 매핑 함수 추가 |
| ReferralRewardClaimManager.swift | 에러 표시 매핑 함수 추가 |

### 13.2 접근성 키 매핑 — i18n-strings.md §16 참조

> 전체 매핑은 i18n-strings.md §16 참조. 키 접두사: `a11y.*`

Phase 7에서 이미 접근성을 처리한 파일(TrashGatePopup, UsageGaugeView)은 **스킵**.

### 13.3 에러 매핑 패턴 (A안)

```swift
// BEFORE — AppCore 에러에 errorDescription 있음
enum CleanupImageLoadError: LocalizedError {
    case loadFailed(reason: String)
    var errorDescription: String? { "이미지 로딩 실패: \(reason)" }
}

// AFTER — errorDescription 제거
enum CleanupImageLoadError: Error {
    case loadFailed(reason: String)
    // errorDescription 삭제
}

// 앱측 — 표시 시점에 로컬라이제이션
func localizedMessage(for error: CleanupImageLoadError) -> String {
    switch error {
    case .loadFailed(let reason):
        return String(localized: "error.imageLoadFailed \(reason)")
    case .timeout:
        return String(localized: "error.imageLoadTimeout")
    case .invalidFormat:
        return String(localized: "error.invalidImageFormat")
    }
}
```

에러 타입별 매핑은 i18n-strings.md §17 참조.

---

## 14. Phase 12 — 서버 에러 코드 매핑 + 로그 영문 병기 (~32키)

### 14.1 서버 에러 코드 매핑 (클라이언트)

**대상 파일:**

| 파일 | 작업 |
|------|------|
| [AppCore] ReferralService.swift | `errorDescription` 제거, typed error만 반환 |
| ReferralCodeInputViewController.swift | 에러 표시 시 `String(localized:)` 매핑 |
| ReferralRewardViewController.swift | 에러 표시 시 매핑 |
| ReferralExplainViewController.swift | 에러 표시 시 매핑 |

**하위 호환 패턴** (구 서버 한글 + 신 서버 영문 코드 양쪽 지원):

```swift
// ReferralService에서 서버 에러 메시지를 반환할 때
case .serverError(let code):
    // 새 형식(영문 코드) → 매핑 테이블에서 조회
    // 구 형식(한글) → 그대로 표시 (하위 호환)
    return code.allSatisfy({ $0.isASCII }) && code.contains("_")
        ? Self.localizedMessage(for: code)
        : code
```

**에러 코드 → 로컬라이즈 매핑 (12개):**

| 서버 코드 | xcstrings 키 | en | ko |
|----------|-------------|----|----|
| `server_error` | `error.server.serverError` | A server error occurred. | 서버 오류가 발생했습니다. |
| `code_creation_failed` | `error.server.codeCreationFailed` | Failed to create code. Please try again later. | 코드 생성에 실패했습니다. 잠시 후 다시 시도해주세요. |
| `referral_not_found` | `error.server.referralNotFound` | Referral record not found. | 해당 초대 기록을 찾을 수 없습니다. |
| `reward_expired` | `error.server.rewardExpired` | Reward has expired. | 보상 수령 기간이 만료되었습니다. |
| `invalid_referral_code` | `error.server.invalidReferralCode` | Invalid referral code. | 유효하지 않은 초대 코드입니다. |
| `self_referral` | `error.server.selfReferral` | You cannot use your own code. | 본인의 초대 코드는 사용할 수 없습니다. |
| `already_referred` | `error.server.alreadyReferred` | A referral code has already been applied. | 이미 초대 코드가 적용되어 있습니다. |
| `invalid_request` | `error.server.invalidRequest` | Invalid request. | 잘못된 요청입니다. |
| `reward_not_found` | `error.server.rewardNotFound` | Reward not found. | 해당 보상을 찾을 수 없습니다. |
| `signing_failed` | `error.server.signingFailed` | Signing failed. Please try again later. | 서명 생성에 실패했습니다. 잠시 후 다시 시도해주세요. |
| `temporary_error` | `error.server.temporaryError` | A temporary error occurred. Please try again tomorrow. | 현재 일시적으로 오류가 발생했습니다. 다음날 다시 시도해주세요. |
| `reward_not_pending` | `error.server.rewardNotPending` | Reward is not in pending state. | 보상이 수령 대기 상태가 아닙니다. |

### 14.2 로그 전용 에러 — 영문+국문 병기

**대상 파일:**

| 파일 | 에러 타입 |
|------|---------|
| [AppCore] TrashStore.swift | TrashStoreError |
| QualityAnalyzer.swift | AnalysisError |
| SimilarityAnalyzer.swift | (내부 로그) |
| SFaceRecognizer.swift | SFaceError |
| YuNetTypes.swift | YuNetError |
| FaceAligner.swift | FaceAlignerError |
| FaceCropper.swift | FaceCropError |
| SimilarityImageLoader.swift | SimilarityImageLoadError |

**처리 방식**: `errorDescription`의 한글을 영문+국문 2줄로 변경. **String Catalog 미등록**.

```swift
// BEFORE
var errorDescription: String? { "디스크 공간이 부족합니다" }

// AFTER
var errorDescription: String? {
    "Not enough disk space"
    // 디스크 공간이 부족합니다
}
```

> ⚠️ 위 코드에서 두 번째 줄 `// 디스크 공간이 부족합니다`는 주석입니다. Swift에서 computed property의 마지막 표현식만 반환되므로 영문만 반환되고 한글은 주석으로 남습니다.

**수정**: 위 패턴은 잘못됨. 로그 병기는 Logger 호출 시점에서 수행:

```swift
// errorDescription는 영문만
var errorDescription: String? { "Not enough disk space" }

// Logger 호출 시 2줄 병기
Logger.app.error("Not enough disk space")
Logger.app.error("디스크 공간이 부족합니다")
```

단, `errorDescription`이 Logger가 아닌 `error.localizedDescription`으로 로깅되는 경우가 많으므로, 실제 로깅 코드를 확인하여 적절히 처리할 것.

**간단한 대안**: `errorDescription`을 영문으로 변경하고, 한글은 주석으로 남기기.

```swift
var errorDescription: String? {
    switch self {
    case .diskSpaceFull:
        return "Not enough disk space"  // 디스크 공간이 부족합니다
    case .fileSystemError(let error):
        return "Failed to save file: \(error)"  // 파일 저장 실패
    }
}
```

### 14.3 서버 수정 (TypeScript) — 클라이언트 선출시 후 진행

**대상 파일:** `supabase/functions/referral-api/index.ts`

**작업:** `errorResponse()` 호출의 한글 메시지를 영문 에러 코드로 교체

```typescript
// BEFORE
return errorResponse("서버 오류가 발생했습니다.", 500);
// AFTER
return errorResponse("server_error", 500);
```

12개 문자열 치환 — 매핑은 §14.1 테이블 참조.

**⚠️ 배포 순서**: 클라이언트(§14.1 하위 호환 포함) 선출시 후 서버 수정. 구 앱이 영문 코드를 그대로 노출하는 것을 방지.
