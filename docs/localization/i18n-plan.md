# SweepPic 다국어 지원(i18n) 계획서

## Context

SweepPic iOS 앱은 현재 한국어 단일 언어만 지원한다. 모든 UI 문자열(~250개 키)이 Swift 코드에 하드코딩되어 있고, `NSLocalizedString`이나 `String(localized:)` 사용이 전무하다. 글로벌 출시를 위해 영어를 Base 언어로 전환하고 한국어를 로컬라이제이션 파일로 분리한다.

---

## 1. 현황 분석

### 1.1 하드코딩된 문자열 현황

| 카테고리 | 건수 | 비고 |
|---------|------|------|
| 사용자 대면 UI 텍스트 | ~80 | 페이월, 게이트, 권한, 방식 선택 시트 등 |
| 코치마크/온보딩 | ~25 | 8개 코치마크 (A1, A2, C, C3, D, E1E2, E3 + 기본) |
| 접근성 문자열 | ~60 | accessibilityLabel/Hint |
| NSAttributedString 내 한글 | ~15 | 주로 CoachMark 키워드 강조 |
| FAQ | ~24 | 12개 Q&A 항목 |
| 서버 에러 메시지 | ~7 | ReferralService LocalizedError |
| 주석 | ~200 | 로컬라이제이션 대상 아님 |

**기능별 분포 (사용자 대면 기준):**
- **Monetization** (~80키): 페이월, 게이트팝업, FAQ 12항목, 사용량 게이지, 축하화면, ATT
- **CoachMark** (~25키): 8개 코치마크 본문+키워드
- **AutoCleanup** (~20키): 진행 상황, 방식 선택 시트
- **FaceScan** (~15키): 방식 선택, 진행바, 빈 상태
- **Referral** (~25키): 초대 설명, 코드 입력, 공유 메시지
- **Permissions** (~8키): 권한 요청 3상태
- **Albums** (~5키): 타이틀, 빈 상태
- **Grid** (~3키): PhotoCell 접근성

### 1.2 기존 로컬라이제이션 설정

- `developmentRegion = en`, `knownRegions = (en, Base, ko)` — 이미 설정됨
- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` — 설정됨
- `ko.lproj/InfoPlist.strings` — NSPhotoLibraryUsageDescription, NSUserTrackingUsageDescription 한글 번역 존재
- **Info.plist 혼재 문제**: NSUserTrackingUsageDescription이 Info.plist에 한글로 하드코딩 (Base 값이 한글)
- **StoreKit**: SweepPicProducts.storekit에 ko/en_US 이미 완료
- **Storyboard**: 텍스트 없음 (모든 UI가 코드 기반)

---

## 2. 기술 전략

### 2.1 String Catalog (.xcstrings) 사용

`.strings` 대신 **String Catalog** 선택.

근거:
- 프로젝트가 이미 `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` 설정
- 복수형 처리가 UI 내장 (별도 `.stringsdict` 불필요)
- `String(localized:)` 사용 시 빌드 시 자동 키 수집
- 번역 누락을 Xcode가 자동 감지

**파일 구조:**
```
SweepPic/SweepPic/
├── Localizable.xcstrings      ← 모든 UI 문자열 (단일 파일, ~250키)
├── InfoPlist.xcstrings         ← Info.plist 키 전용
└── ko.lproj/
    └── InfoPlist.strings       ← 삭제 (xcstrings로 대체)
```

### 2.2 문자열 키 네이밍 컨벤션

**규칙:** `{feature}.{screen}.{element}.{variant}`

```swift
// 예시
"monetization.gate.title"                    // "Free Deletion Limit Exceeded"
"monetization.gate.adButton %lld %lld"       // "Watch %lld ads to delete all %lld photos"
"monetization.paywall.purchaseButton"        // "Start Free Trial"
"coachMark.a1.message"                       // "Swipe the cell horizontally\nto delete it"
"coachMark.a1.keyword"                       // "Swipe the cell horizontally"
"autoCleanup.progress.foundCount %lld"       // "%lld photos found" (복수형)
"a11y.grid.photo %lld %lld"                 // "Photo %lld of %lld"
"error.rateLimited %lld"                     // "Too many requests. Try again in %lld seconds."
```

### 2.3 서버 응답 문자열 처리

**방식:** 서버는 에러 코드만, 클라이언트가 번역 (A 방식 확정)

**서버 변경 (referral-api/index.ts 등):**
```typescript
// BEFORE: return errorResponse("서버 오류가 발생했습니다.", 500);
// AFTER:  return errorResponse("server_error", 500);
```

**클라이언트 변경 (ReferralService.swift):**
```swift
case .serverError(let code):
    // 새 형식(영문 코드) → 매핑 테이블에서 조회
    // 구 형식(한글) → 하위 호환으로 그대로 표시
    return code.allSatisfy({ $0.isASCII }) && code.contains("_")
        ? Self.localizedMessage(for: code)
        : code
```

에러 코드 매핑:
| 서버 코드 | 영어 | 한국어 |
|----------|------|--------|
| `server_error` | Something went wrong. Please try again. | 서버 오류가 발생했습니다. |
| `code_creation_failed` | Failed to create code. Please try again. | 코드 생성에 실패했습니다. |
| `referral_not_found` | Referral record not found. | 해당 초대 기록을 찾을 수 없습니다. |
| `reward_expired` | Reward has expired. | 보상 수령 기간이 만료되었습니다. |
| `invalid_referral_code` | Invalid referral code. | 유효하지 않은 초대 코드입니다. |
| `self_referral` | You cannot use your own code. | 본인의 초대 코드는 사용할 수 없습니다. |
| `already_referred` | A referral code has already been applied. | 이미 초대 코드가 적용되어 있습니다. |

---

## 3. 1차: 로컬라이제이션 구조 전환 (영어 Base + 한국어)

### 3.1 Xcode 프로젝트 설정

1. `Localizable.xcstrings` 생성 (File > New > String Catalog)
2. Korean(ko) 언어 추가
3. `InfoPlist.xcstrings` 생성 + ko 번역 이전
4. Info.plist의 `NSUserTrackingUsageDescription` 영어로 변경
5. 기존 `ko.lproj/InfoPlist.strings` 삭제

### 3.2 문자열 추출 (10 Phase)

| Phase | 대상 | 키 수 | 확립하는 패턴 |
|-------|------|------|-------------|
| **1** | Permissions | ~8 | 기본 패턴 (파일럿) |
| **2** | EmptyState + Albums | ~8 | 컴포넌트 패턴 |
| **3** | AutoCleanup | ~20 | 복수형, 날짜 포맷팅 |
| **4** | FaceScan | ~15 | Phase 3 패턴 반복 적용 |
| **5** | CoachMark | ~25 | NSAttributedString + 키워드 강조 |
| **6** | Monetization (Gate/Gauge) | ~25 | 동적 값 삽입 + 접근성 |
| **7** | Monetization (Paywall/FAQ/ATT/Celebration) | ~55 | 대량 텍스트 |
| **8** | Referral | ~25 | 서버 에러 코드 전환 병행 |
| **9** | Grid 접근성 + 전역 접근성 | ~60 | 접근성 전용 |
| **10** | 서버 에러 (ReferralService) | ~7 | 서버 배포 동기화 |

**각 Phase 절차:**
1. 해당 기능의 한글 문자열 식별 (주석 제외)
2. 키 이름 결정 → `Localizable.xcstrings`에 추가 + 영어 Base 작성
3. ko 컬럼에 기존 한글 이전
4. Swift 코드에서 `String(localized:)` 교체
5. 빌드 + 영어/한국어 전환 테스트
6. 커밋

### 3.3 코드 교체 패턴

**패턴 1: 단순 정적 텍스트**
```swift
// BEFORE
titleLabel.text = "무료 삭제 한도 초과"
// AFTER
titleLabel.text = String(localized: "monetization.gate.title")
```

**패턴 2: 문자열 보간**
```swift
// BEFORE
label.text = "삭제할 사진 \(trashCount)장"
// AFTER
label.text = String(localized: "monetization.gate.info \(trashCount)")
```

**패턴 3: 접근성**
```swift
// BEFORE
accessibilityLabel = "사진 \(index + 1) / \(total)"
// AFTER
accessibilityLabel = String(localized: "a11y.grid.photo \(index + 1) \(total)")
```

**패턴 4: NSAttributedString (키워드 강조)**
```swift
// BEFORE
let mainText = "셀을 가로로 스와이프해서\n삭제해 보세요"
let keyword = "가로로 스와이프"
// AFTER
let mainText = String(localized: "coachMark.a1.message")
let keyword = String(localized: "coachMark.a1.keyword")
// 나머지 NSMutableAttributedString 로직은 동일 (range(of:) 기반)
```
> 번역 가이드에 "keyword는 반드시 message에 포함된 부분 문자열이어야 함" 명시 필수

**패턴 5: UIButton**
```swift
// BEFORE
button.setTitle("무료 체험 시작하기", for: .normal)
// AFTER
button.setTitle(String(localized: "monetization.paywall.purchaseButton"), for: .normal)
```

### 3.4 한국어 번역 파일

별도 파일 생성 불필요. `Localizable.xcstrings`의 ko 컬럼에 기존 하드코딩된 한글을 그대로 이전. 번역 작업이 아닌 마이그레이션.

### 3.5 복수형, 날짜/숫자 포맷팅

**복수형 (String Catalog Plural Variations):**

```
Key: "autoCleanup.progress.foundCount %lld"
en:  one → "%lld photo found"  /  other → "%lld photos found"
ko:  other → "%lld장 발견"
```

주요 복수형 패턴: N장(photos), N그룹(groups), N회(times), N일/개월/년(days/months/years), N초(seconds)

**날짜 포맷팅:**
```swift
// BEFORE
formatter.dateFormat = "yyyy년 M월"
// AFTER
formatter.setLocalizedDateFormatFromTemplate("yMMMM")
// 한국어: "2025년 3월" / 영어: "March 2025"
```

변경 대상:
- `CleanupProgressView.swift` — "y년 M월" → `"yMMMM"`
- `CleanupMethodSheet.swift` — "M월" → `"MMM"`
- `FaceScanMethodSheet.swift` — 날짜 포맷

**숫자/가격:** NumberFormatter는 이미 locale 자동 반영. 가격 뒤 단위만 로컬라이즈:
```swift
// BEFORE: "\(product.displayPrice)/년"
// AFTER: String(localized: "monetization.paywall.pricePerYear \(product.displayPrice)")
// en: "%@/yr" / ko: "%@/년"
```

### 3.6 특수 영역

- **StoreKit**: 이미 ko/en_US 완료 → 추가 작업 없음
- **Info.plist**: NSUserTrackingUsageDescription 영어로 변경 + InfoPlist.xcstrings로 마이그레이션
- **CFBundleDisplayName**: "SweepPic"은 언어 무관 브랜드명 → 변경 불필요
- **Push 알림**: 클라이언트에 문자열 없음 (서버 발송). 1차 스코프 외, 2차에서 사용자 locale 전달로 대응
- **앱스토어 메타데이터**: App Store Connect에서 별도 관리. 영어 설명/스크린샷 추가 (코드 변경 없음)

### 3.7 법적 문서

- **이용약관/개인정보처리방침**: 외부 URL 링크 (`sweeppic.app/terms`, `/privacy`). 웹 서버에서 URL 경로 분기 (`/en/terms`, `/ko/terms`) 또는 `Accept-Language` 기반 처리. 앱에서는 locale 기반 URL 교체.
- **FAQ**: 12개 Q&A를 String Catalog에 등록 (`monetization.faq.q1` ~ `q12`, `a1` ~ `a12`). 영어 FAQ 새로 작성 필요.
- **사업자 정보**: 현재 TODO 상태. 구현 시 바로 로컬라이제이션 적용.

### 3.8 UI/레이아웃 대응

영어 텍스트가 한국어보다 30-50% 더 길 수 있음. 주요 위험 영역:

1. **버튼**: `adjustsFontSizeToFitWidth = true`, `minimumScaleFactor = 0.8` 추가
2. **코치마크**: `messageLabel.frame` 높이가 80pt로 하드코딩 → `sizeThatFits` 기반 동적 높이로 변경
3. **게이트 팝업**: UIStackView + Auto Layout이므로 자동 대응, iPhone SE에서 검증 필요
4. **비교표**: "인물사진 비교정리"(8자) vs "Face Comparison Cleanup"(24자) — 고정 열 비율에서 검증

### 3.9 테스트 및 검증

1. **빌드**: 각 Phase에서 en/ko 빌드 성공 확인
2. **시뮬레이터 전환**: Settings > Language를 English/한국어로 전환, 모든 화면 확인
3. **Pseudolanguage**: Scheme > Options > "Double-Length Pseudolanguage"로 레이아웃 극한 테스트
4. **String Catalog 완전성**: ko 번역률 100%, 경고 없음
5. **VoiceOver**: 영어/한국어 접근성 레이블 확인
6. **복수형**: 0/1/2+ 케이스에서 영어 문구 확인
7. **날짜**: 영어 "March 2025", 한국어 "2025년 3월" 형식 확인
8. **서버 에러**: 구 형식(한글)/신 형식(코드) 하위 호환 확인

---

## 4. 2차: 다국어 확장

### 4.1 대상 언어 선정
App Store Analytics 기반 우선순위: 일본어(ja) > 중국어 간체(zh-Hans) > 스페인어(es) > 독일어(de)/프랑스어(fr)

### 4.2 번역 워크플로우
Xcode Export Localizations (XLIFF) → 번역 플랫폼(Crowdin/Lokalise) 또는 전문 에이전시 → Import → 네이티브 스피커 QA

번역 가이드 필수 포함 사항:
- keyword는 message의 부분 문자열이어야 함
- 각 언어별 CLDR 복수형 카테고리
- 버튼 텍스트 글자 수 제한 (한국어 대비 1.5배 이내)

### 4.3 RTL 대응
1차(영어/한국어)는 모두 LTR → 불필요. 2차에서 아랍어/히브리어 포함 시:
- `left/right` → `leading/trailing` 전환 (현재 대부분 leading/trailing 사용 중)
- `textAlignment = .left` → `.natural`
- 코치마크 `CGRect` frame 기반 레이아웃은 RTL 미러링 별도 처리 필요

---

## 별첨: 전체 문자열 매핑 테이블

별도 문서 참조: [i18n-strings.md](i18n-strings.md)

---

## 핵심 파일

| 파일 | 역할 |
|------|------|
| `Features/Monetization/Gate/TrashGatePopupViewController.swift` | 가장 많은 UI 문자열 집중, 로컬라이제이션 패턴 기준점 |
| `Shared/Components/CoachMarkOverlayView+CoachMarkA1.swift` | NSAttributedString + 키워드 강조 패턴 확립 |
| `Sources/AppCore/Services/ReferralService.swift` | 서버 에러 코드 매핑 전환 중심 |
| `Features/AutoCleanup/UI/CleanupProgressView.swift` | 복수형 + 날짜 포맷 + AttributedString 복합 패턴 |
| `Features/Monetization/Menu/FAQViewController.swift` | 대량 정적 텍스트 (12 Q&A) |
| `supabase/functions/referral-api/index.ts` | 서버 에러 코드 전환 대상 |
| `SweepPic/Info.plist` | NSUserTrackingUsageDescription 영어 전환 |
| `SweepPic/ko.lproj/InfoPlist.strings` | xcstrings 마이그레이션 후 삭제 |
