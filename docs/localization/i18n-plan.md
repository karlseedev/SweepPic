# SweepPic 다국어 지원(i18n) 계획서

## Context

SweepPic iOS 앱은 현재 한국어 단일 언어만 지원한다. 모든 UI 문자열(~494개 키, 제외 대상 제거 시 ~470키)이 Swift 코드에 하드코딩되어 있고, `NSLocalizedString`이나 `String(localized:)` 사용이 전무하다. 글로벌 출시를 위해 영어를 Base 언어로 전환하고 한국어를 로컬라이제이션 파일로 분리한다.

---

## 1. 현황 분석

### 1.1 하드코딩된 문자열 현황

| 카테고리 | 건수 | 비고 |
|---------|------|------|
| 사용자 대면 UI 텍스트 | ~350 | 페이월, 게이트, 권한, 방식 선택 시트, Alert, Toast, 메뉴 등 |
| 코치마크/온보딩 | ~39 | 8개 코치마크 (A1, A2, C, C3, D, E1E2, E3 + 기본) |
| 접근성 전용 문자열 | ~25 | accessibilityLabel/Hint (UI와 동일한 것은 통합, 전용만 분리) |
| NSAttributedString 내 한글 | ~15 | 주로 CoachMark 키워드 강조 |
| FAQ | ~24 | 12개 Q&A 항목 (2개 삭제, 실제 ~22) |
| 서버 에러 메시지 | ~22 | ReferralService LocalizedError + 서버 에러 코드 매핑 |
| AppCore 에러 메시지 | ~19 | 사용자 노출 에러 + 로그 전용 에러 |
| 주석 | ~200 | 로컬라이제이션 대상 아님 |

**전체 약 494키** (i18n-strings.md 기준, 삭제/ko전용 제외 시 ~470키)

**기능별 분포:**
- **Monetization** (~128키): Gate/Gauge(19) + Paywall(47) + FAQ(24) + 기타(38: 고객센터, 멤버십메뉴, ATT, 축하, 해지설문)
- **CoachMark** (~39키): 8개 코치마크 본문+키워드+버튼
- **AutoCleanup** (~58키): 방식 선택 시트, 진행 뷰, 결과 메시지, 프리뷰, 에러, 판정 모드
- **FaceScan + SimilarPhoto** (~38키): 방식 선택, 진행바, 그룹 셀, 얼굴 비교 화면
- **Referral** (~65키): 초대 설명, 코드 입력, 보상 수령, 공유 메시지, 에러 메시지
- **Grid + Viewer** (~30키): 메뉴 항목, Toast, Alert, 비디오 에러
- **Shared Components** (~15키): EmptyStateView, FloatingTabBar
- **Permissions** (~6키): 권한 요청 2상태 (제한/거부)
- **Albums** (~17키): 타이틀, 빈 상태, 선택 모드 (스마트 앨범 제외 — 2.3절 참조)
- **접근성 전용** (~25키): UI 라벨과 별개인 접근성 전용 문자열
- **서버 에러** (~22키): ReferralService + 서버 에러 코드 매핑
- **AppCore 에러** (~19키): 사용자 노출 에러(로컬라이즈) + 로그 전용 에러(영문 전환)

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
├── Localizable.xcstrings      ← 모든 UI 문자열 (단일 파일, ~470키)
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
"coachMark.a1.message"                       // "Swipe horizontally\non a photo to delete"
"coachMark.a1.keyword"                       // "Swipe horizontally"
"autoCleanup.progress.foundCount %lld"       // "%lld photos found" (복수형)
"a11y.grid.photo %lld %lld"                 // "Photo %lld of %lld"
"error.rateLimited %lld"                     // "Too many requests. Try again in %lld seconds."
```

### 2.3 스마트 앨범 이름 — PhotoKit 위임

`SmartAlbumType.displayTitle`에 하드코딩된 한글("모든 사진", "최근 추가" 등 13개)을 제거하고, `PHAssetCollection.localizedTitle`을 직접 사용한다.

**근거:**
- PhotoKit이 전 세계 언어의 스마트 앨범 이름을 자동 제공 (일본어, 중국어, 스페인어 등 별도 번역 불필요)
- 시스템 사진 앱과 동일한 명칭 보장 (직접 번역 시 불일치 위험)
- 2차 다국어 확장 시 추가 작업 제로

**변경 대상:**

현재 `SmartAlbum.title`은 `type.displayTitle`(하드코딩 한글)을 반환하는 computed property이고, `PHAssetCollection`을 들고 있지 않다. 모델 구조 변경이 필요:

```swift
// Sources/AppCore/Models/AlbumModels.swift
// BEFORE
public struct SmartAlbum {
    public let type: SmartAlbumType
    public var title: String { type.displayTitle }  // ← 하드코딩 한글
}

// AFTER
public struct SmartAlbum {
    public let type: SmartAlbumType
    public let title: String  // ← stored property (localizedTitle 저장)
    
    public init(id: String, type: SmartAlbumType, title: String, ...) { ... }
}

// Sources/AppCore/Services/AlbumService.swift — SmartAlbum 생성 시 localizedTitle 전달
SmartAlbum(
    id: collection.localIdentifier,
    type: albumType,
    title: collection.localizedTitle ?? albumType.rawValue,  // ← PhotoKit 자동 번역
    assetCount: assetCount,
    keyAssetIdentifier: keyAssetID
)
```

`SmartAlbumType.displayTitle`은 삭제하거나 deprecated 처리.

**AppCore 내 나머지 한글도 A안 기준으로 통일** (AppCore는 문자열 반환 안 함, 앱 UI에서 로컬라이제이션):
- `AlbumSection.headerTitle` → 앱 UI에서 `String(localized:)`로 제공 (모델에서 제거)
- `TrashAlbum.title = "삭제대기함"` → 앱 UI에서 `String(localized:)`로 제공 (모델에서 기본값 제거)
- `AlbumService`의 `"제목 없음"` fallback → 앱 UI에서 `String(localized: "albums.untitled")`로 제공

→ i18n-strings.md #436-447 (스마트 앨범 이름 12개)는 **로컬라이제이션 대상에서 제외**. #448-450 (섹션 헤더, fallback)은 유지.

### 2.4 에러 문자열 분류 기준

에러 메시지는 사용자 노출 여부에 따라 처리 방식을 구분한다.

**사용자 노출 에러 → 로컬라이제이션 대상:**
| 에러 타입 | 노출 경로 |
|----------|----------|
| `CleanupError` | `showCleanupError()` → UIAlertController |
| `CleanupImageLoadError` | CleanupError로 래핑 → UIAlert |
| `VideoFrameExtractError` | CleanupError로 래핑 → UIAlert |
| `PromotionalOfferService.OfferError` | ClaimState → UI 상태 표시 |
| `ReferralService` 에러 | UILabel, Toast 등 |
| 비디오 플레이어 에러 | VideoPageViewController → UILabel |

**로그 전용 에러 → 영문 전환 (로컬라이제이션 제외):**
| 에러 타입 | 용도 |
|----------|------|
| `TrashStoreError` | 햅틱 피드백만, UI 미노출 |
| `AnalysisError` | 분석 엔진 내부 Logger |
| `SFaceError`, `YuNetError` | ML 모델 에러 Logger |
| `FaceAlignerError`, `FaceCropError` | 얼굴 처리 내부 Logger |
| `SimilarityImageLoadError` | 분석 엔진 내부 처리 |

로그 전용 에러는 `String(localized:)` 대신 영문+국문 2줄 병기로 변경한다. 영어 로그가 Crashlytics/디버깅에 유용하고, 국문 로그는 한국어 사용자 디버깅에 유용하다.

```swift
// 예시
Logger.cleanup.error("Product load failed: StoreKit Configuration check required")
Logger.cleanup.error("상품 로드 실패 — StoreKit Configuration 확인 필요")
```

### 2.5 제외 대상

| 대상 | 이유 |
|------|------|
| Debug/ 폴더 전체 | 개발 전용, 릴리즈 미포함 |
| BusinessInfoViewController | 전자상거래법 제10조, ko locale 전용 |
| 주석 내 한글 | 코드 주석은 로컬라이제이션 대상 아님 |
| 스마트 앨범 이름 12개 | PHAssetCollection.localizedTitle 위임 (2.3절) |
| 로그 전용 에러 | 영문+국문 병기, String Catalog 미등록 (2.4절) |
| 테스트 코드 한글 기대값 | 3.10절에서 별도 처리 |

### 2.6 서버 응답 문자열 처리

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

에러 코드 매핑 (12개):
| 서버 코드 | 영어 | 한국어 |
|----------|------|--------|
| `server_error` | A server error occurred. | 서버 오류가 발생했습니다. |
| `code_creation_failed` | Failed to create code. Please try again later. | 코드 생성에 실패했습니다. 잠시 후 다시 시도해주세요. |
| `referral_not_found` | Referral record not found. | 해당 초대 기록을 찾을 수 없습니다. |
| `reward_expired` | Reward has expired. | 보상 수령 기간이 만료되었습니다. |
| `invalid_referral_code` | Invalid referral code. | 유효하지 않은 초대 코드입니다. |
| `self_referral` | You cannot use your own code. | 본인의 초대 코드는 사용할 수 없습니다. |
| `already_referred` | A referral code has already been applied. | 이미 초대 코드가 적용되어 있습니다. |
| `invalid_request` | Invalid request. | 잘못된 요청입니다. |
| `reward_not_found` | Reward not found. | 해당 보상을 찾을 수 없습니다. |
| `signing_failed` | Signing failed. Please try again later. | 서명 생성에 실패했습니다. 잠시 후 다시 시도해주세요. |
| `temporary_error` | A temporary error occurred. Please try again tomorrow. | 현재 일시적으로 오류가 발생했습니다. 다음날 다시 시도해주세요. |
| `reward_not_pending` | Reward is not in pending state. | 보상이 수령 대기 상태가 아닙니다. |

---

## 3. 1차: 로컬라이제이션 구조 전환 (영어 Base + 한국어)

### 3.1 Xcode 프로젝트 설정

1. `Localizable.xcstrings` 생성 (File > New > String Catalog)
2. Korean(ko) 언어 추가
3. `InfoPlist.xcstrings` 생성 + ko 번역 이전
4. Info.plist의 `NSUserTrackingUsageDescription` 영어로 변경
5. 기존 `ko.lproj/InfoPlist.strings` 삭제

### 3.2 문자열 추출 (12 Phase)

> i18n-strings.md 섹션 번호 기준. 전체 ~484키 (제외 대상 제거 후, D-1 14키 포함).

| Phase | 대상 | strings.md 섹션 | 키 수 | 확립하는 패턴 |
|-------|------|----------------|------|-------------|
| **1** | Permissions | §1 | ~6 | 기본 패턴 (파일럿) |
| **2** | EmptyState + Albums + Shared Components | §2, §4 | ~32 | 컴포넌트 패턴, 스마트앨범 localizedTitle 전환 |
| **3** | Grid + Viewer | §3, §13 | ~30 | 메뉴, Toast, Alert, 비디오 에러 |
| **4** | CoachMark | §5 | ~53 | NSAttributedString + 키워드 강조 + fallback (D-1 14키 포함) |
| **5** | AutoCleanup | §10 | ~58 | 복수형, 날짜 포맷팅, 복합 보간, 에러 메시지 |
| **6** | FaceScan + SimilarPhoto | §11, §12 | ~38 | Phase 5 패턴 반복 적용 |
| **7** | Monetization (Gate/Gauge) | §6 | ~19 | 동적 값 삽입 + 접근성 |
| **8** | Monetization (Paywall) | §7 | ~47 | 대량 텍스트, 법적 고지, 비교표 |
| **9** | Monetization (FAQ/기타) | §8, §9 | ~61 | FAQ 대량 Q&A, 메뉴, ATT, 축하, 해지설문 |
| **10** | Referral + 공유 메시지 | §14 | ~65 | 서버 에러 코드 전환 병행, 공유 메시지 |
| **11** | 접근성 전용 + 사용자 노출 에러 (앱 타겟) | §16, §17 일부 | ~35 | 접근성 전용, 앱 호출측 에러 매핑 (A안) |
| **12** | 서버 에러 (ReferralService + 서버 코드) + 로그 전용 에러 영문 전환 | §15, §17 일부, 서버 코드 | ~32 | 서버 배포 동기화, 로그 에러 영문화 |

**각 Phase 절차:**
1. 해당 기능의 한글 문자열 식별 (주석 제외)
2. 키 이름 결정 → `Localizable.xcstrings`에 추가 + 영어 Base 작성
3. ko 컬럼에 기존 한글 이전
4. Swift 코드에서 `String(localized:)` 교체
5. 빌드 + 영어/한국어 전환 테스트
6. 커밋

#### Phase별 대상 파일

> 경로는 `SweepPic/SweepPic/` 기준. AppCore는 `Sources/AppCore/` 기준.
>
> ⚠️ **iOS 버전 분기 주의**: 이 프로젝트는 iOS 16~25(FloatingOverlay 커스텀 UI)와 iOS 26+(시스템 네비게이션 바)가 분리되어 있다. 같은 UI 문자열이 양쪽 코드 경로에 하드코딩되어 있는 경우가 많으므로, **문자열 교체 시 반드시 grep으로 동일 한글이 다른 파일에 있는지 확인**할 것.
>
> 특히 주의할 파일 쌍:
> - `TabBarController.swift` ↔ `FloatingTabBar.swift` / `LiquidGlassTabBar.swift` / `FloatingOverlayContainer.swift`
> - `*ViewController.swift`의 `setupSystemNavigationBar()` ↔ `configureFloatingOverlay*()`
> - `GridSelectMode.swift` / `TrashSelectMode.swift` ↔ `FloatingTabBar` / `LiquidGlassTabBar`의 Select 모드

**Phase 1 — Permissions** (~6키)
```
Features/Permissions/PermissionViewController.swift
```

**Phase 2 — EmptyState + Albums + Shared Components** (~39키)
```
Shared/Components/EmptyStateView.swift
Shared/Navigation/TabBarController.swift
Shared/Components/FloatingTabBar.swift             ← 탭 타이틀 + Select 모드 (iOS 16~25)
Shared/Components/LiquidGlassTabBar.swift          ← 탭 타이틀 + Select 모드 (iOS 26)
Shared/Components/FloatingOverlayContainer.swift   ← 오버레이 타이틀 (iOS 16~25)
Shared/Components/FloatingTitleBar.swift            ← 기본 타이틀 (iOS 16~25)
Features/Grid/GridViewController.swift             ← navigationTitle + emptyState + overlay
Features/Albums/AlbumsViewController.swift         ← attributedText + overlay + emptyState
Features/Albums/AlbumGridViewController.swift
Features/Albums/TrashAlbumViewController.swift
[AppCore] Models/AlbumModels.swift                 ← SmartAlbumType.displayTitle → localizedTitle 전환
[AppCore] Services/AlbumService.swift              ← fallback "제목 없음" 교체
```

**Phase 3 — Grid + Viewer** (~30키)
```
Features/Grid/GridViewController+Cleanup.swift       ← 메뉴, Alert, Toast 집중
Features/Grid/GridViewController+CoachMarkReplay.swift
Features/Viewer/ViewerViewController.swift
Features/Viewer/VideoPageViewController.swift
⚠️ iOS 26 분기: GridViewController+Cleanup.swift에 @available(iOS 26.0, *) 블록이 6개 있음
   — 시스템 UIMenu 내 "간편정리", "인물사진 비교정리", "저품질사진 자동정리", "사진 선택 모드" 등
   — FloatingOverlay 경로에도 동일 메뉴 문자열이 별도 존재하므로 양쪽 모두 수정 필요
```

**Phase 4 — CoachMark** (~39키)
```
Shared/Components/CoachMarkOverlayView.swift          ← 기본 코치마크
Shared/Components/CoachMarkOverlayView+CoachMarkA1.swift
Shared/Components/CoachMarkOverlayView+CoachMarkA2.swift
Shared/Components/CoachMarkOverlayView+CoachMarkC.swift
Shared/Components/CoachMarkOverlayView+CoachMarkC3.swift
Shared/Components/CoachMarkOverlayView+CoachMarkD.swift
Shared/Components/CoachMarkOverlayView+CoachMarkD1.swift    ← D-1: 자동정리 미리보기 4단계 안내 (14키)
Features/AutoCleanup/Preview/PreviewGridViewController+CoachMarkD1.swift  ← D-1 트리거 (문자열 없음, 참고용)
Shared/Components/CoachMarkOverlayView+E1E2.swift
Shared/Components/CoachMarkOverlayView+E3.swift
※ 동시에 80pt 하드코딩 → 동적 높이 변경 (3.9절)
※ keyword fallback 코드 추가 (패턴 4)
```

**Phase 5 — AutoCleanup** (~58키)
```
Features/AutoCleanup/UI/CleanupMethodSheet.swift      ← 복합 보간 (패턴 6)
Features/AutoCleanup/UI/CleanupProgressView.swift     ← 날짜 포맷 변경
Features/AutoCleanup/CleanupConstants.swift            ← 결과 메시지, 복합 보간
Features/AutoCleanup/Models/CleanupError.swift         ← 사용자 노출 에러
Features/AutoCleanup/Models/JudgmentMode.swift
Features/AutoCleanup/Preview/PreviewGridViewController.swift
Features/AutoCleanup/Preview/PreviewBottomView.swift
Features/AutoCleanup/Preview/PreviewBannerCell.swift
SweepPicTests/AutoCleanup/E2E/CleanupE2ETests.swift   ← 테스트 기대값 영어 전환
⚠️ iOS 26 분기: PreviewGridViewController.swift에 시스템 네비바 vs 커스텀 헤더 분기 있음
```

**Phase 6 — FaceScan + SimilarPhoto** (~38키)
```
Features/FaceScan/UI/FaceScanMethodSheet.swift         ← 날짜 포맷 + 복합 보간
Features/FaceScan/UI/FaceScanListViewController.swift
Features/FaceScan/UI/FaceScanProgressBar.swift
Features/FaceScan/UI/FaceScanGroupCell.swift
Features/FaceScan/Models/FaceScanMethod.swift          ← displayTitle 복합 보간
Features/SimilarPhoto/UI/FaceComparisonViewController.swift
⚠️ iOS 26 분기:
   — FaceScanListViewController: @available(iOS 26) 블록에 "다음 분석" 버튼 (시스템 네비바 우측)
   — FaceComparisonViewController: @available(iOS 26) 블록에 "인물사진 비교정리 - 인물 N" 타이틀
   — 양쪽 모두 커스텀 헤더(FloatingTitleBar) 경로에도 동일 문자열이 있으므로 함께 수정
```

**Phase 7 — Monetization (Gate/Gauge)** (~19키)
```
Features/Monetization/Gate/TrashGatePopupViewController.swift
Features/Monetization/Gate/TrashGateCoordinator.swift
Features/Monetization/Gate/UsageGaugeView.swift
```

**Phase 8 — Monetization (Paywall)** (~47키)
```
Features/Monetization/Subscription/PaywallViewController.swift
Features/Monetization/Subscription/PaywallViewModel.swift
Features/Monetization/Subscription/PaywallPlanTabView.swift
```

**Phase 9 — Monetization (FAQ/기타)** (~61키)
```
Features/Monetization/Menu/FAQViewController.swift
Features/Monetization/Menu/CustomerServiceViewController.swift
Features/Monetization/Menu/PremiumMenuViewController.swift
Features/Monetization/Menu/ExitSurveyViewController.swift
Features/Monetization/Ad/ATTPromptViewController.swift
Features/Monetization/Celebration/CelebrationViewController.swift
※ BusinessInfoViewController.swift — ko locale 전용, 로컬라이제이션 제외
```

**Phase 10 — Referral + 공유 메시지** (~65키)
```
Features/Referral/Menu/ReferralMenuViewController.swift
Features/Referral/Share/ReferralExplainViewController.swift
Features/Referral/Share/ReferralShareManager.swift     ← 공유 메시지 (보내는 사람 기기 locale 기준)
Features/Referral/CodeInput/ReferralCodeInputViewController.swift
Features/Referral/Reward/ReferralRewardViewController.swift
Features/Referral/Reward/ReferralRewardClaimManager.swift
```

**Phase 11 — 접근성 전용 + 사용자 노출 에러 매핑** (~35키)
```
# 접근성 전용 (이미 Phase 3-10에서 터치한 파일 재방문)
Features/Grid/PhotoCell.swift
Features/SimilarPhoto/UI/FaceButtonOverlay.swift
Features/Monetization/Gate/UsageGaugeView.swift         ← Phase 7에서 UI 처리, 여기서 a11y 추가
Features/Monetization/Gate/TrashGatePopupViewController.swift
Features/Monetization/Subscription/PaywallViewController.swift
Features/Monetization/Ad/ATTPromptViewController.swift
Features/Monetization/Celebration/CelebrationViewController.swift
Features/Monetization/Menu/FAQViewController.swift

# 사용자 노출 에러 → errorDescription 제거, 앱 호출측에서 로컬라이제이션 (A안)
# ※ CleanupImageLoadError, VideoFrameExtractError는 앱 타겟 파일 (AppCore 아님)
Features/AutoCleanup/Analysis/CleanupImageLoader.swift  ← errorDescription 제거
Features/AutoCleanup/Analysis/VideoFrameExtractor.swift  ← errorDescription 제거
[AppCore] Services/PromotionalOfferService.swift        ← errorDescription 제거
Features/AutoCleanup/Analysis/QualityAnalyzer.swift     ← 에러 표시 매핑 함수 추가
Features/Referral/Reward/ReferralRewardClaimManager.swift ← 에러 표시 매핑 함수 추가
```

**Phase 12 — 서버 에러 + 로그 전용 에러 영문 전환** (~32키)

⚠️ **배포 순서 (서버↔클라이언트 동기화):**
1. 클라이언트: 에러 코드 매핑 포함 버전 **먼저 출시** (구 한글 메시지도 하위 호환 유지)
2. 서버: 앱 업데이트 비율이 충분해지면 (또는 앱 최소 버전 강제 업데이트 후) 에러 코드 응답으로 전환
3. 또는 서버에서 `X-App-Version` 헤더 기반으로 한글/코드를 분기 응답

구 앱이 새 서버의 코드 문자열(`server_error` 등)을 그대로 노출하는 것을 방지하기 위해, **반드시 클라이언트 선출시**.

```
# 서버 에러 코드 매핑 (A안: AppCore는 typed error만, 앱에서 로컬라이즈)
[AppCore] Services/ReferralService.swift               ← errorDescription 제거, typed error만 반환
Features/Referral/CodeInput/ReferralCodeInputViewController.swift  ← 에러 표시 시 String(localized:) 매핑
Features/Referral/Reward/ReferralRewardViewController.swift        ← 에러 표시 시 String(localized:) 매핑
Features/Referral/Share/ReferralExplainViewController.swift        ← 에러 표시 시 String(localized:) 매핑
[Server] supabase/functions/referral-api/index.ts      ← 한글 → 에러 코드 전환 (클라이언트 선출시 후)

# 로그 전용 에러 — 한글을 영어로 직접 교체 (String Catalog 미등록)
[AppCore] Stores/TrashStore.swift                      ← errorDescription 영문 전환
Features/AutoCleanup/Analysis/QualityAnalyzer.swift    ← AnalysisError 영문 전환
Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift
Features/SimilarPhoto/Analysis/SFaceRecognizer.swift
Features/SimilarPhoto/Analysis/YuNetTypes.swift        ← YuNetError 영문 전환
Features/SimilarPhoto/Analysis/FaceAligner.swift
Features/SimilarPhoto/Analysis/FaceCropper.swift
Features/SimilarPhoto/Analysis/SimilarityImageLoader.swift
```

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

> **⚠️ keyword fallback 필수**: `range(of:)`가 nil을 반환할 때(번역 오류 등) 크래시 없이 강조 없는 일반 텍스트로 표시:
> ```swift
> if let range = mainText.range(of: keyword) {
>     attributed.addAttribute(.font, value: boldFont, range: NSRange(range, in: mainText))
> }
> // range(of:) 실패 시 강조 없이 그대로 표시 — 번역 QA에서 검출
> ```

**패턴 5: UIButton**
```swift
// BEFORE
button.setTitle("무료 체험 시작하기", for: .normal)
// AFTER
button.setTitle(String(localized: "monetization.paywall.purchaseButton"), for: .normal)
```

**패턴 6: 복합 보간 (날짜+텍스트 연결)**

문자열 연결/보간으로 문장을 구성하는 경우, 언어별 어순 차이가 발생한다. 전체 문장을 하나의 키로 만들어야 한다.

```swift
// ❌ BEFORE — 어순이 한국어에 고정
"\(targetYear)년 이어서 (\(monthString) 이전)"

// ✅ AFTER — 전체 문장을 키로 등록, placeholder로 값 삽입
String(localized: "cleanup.method.continueByYear \(targetYear) \(monthString)")
// en: "Continue from \(targetYear) (\(monthString) and earlier)"
// ko: "\(targetYear)년 이어서 (\(monthString) 이전)"
```

변경 대상 파일:
- `CleanupMethodSheet.swift` — 이어서 정리 버튼, 연도별 버튼
- `FaceScanMethodSheet.swift` — 동일 패턴
- `CleanupConstants.swift` — 결과 메시지
- `FaceScanMethod.swift` — displayTitle

### 3.4 한국어 번역 파일 (별도 단계 없음)

별도 파일 생성 불필요. `Localizable.xcstrings`의 ko 컬럼에 기존 하드코딩된 한글을 그대로 이전. 번역 작업이 아닌 마이그레이션.

### 3.5 복수형, 날짜/숫자 포맷팅 (Phase 5에서 확립, 이후 반복 적용)

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
- **스마트 앨범 이름**: PHAssetCollection.localizedTitle 위임 (2.3절 참조)
- **사업자 정보**: ko locale 전용, 로컬라이제이션 제외 (locale 분기로 메뉴 숨김)
- **Debug 폴더**: CompareAnalysisTester, ModeComparisonTester 등 개발 전용 파일. 날짜 포맷("yyyy년 M월") 포함하나 로컬라이제이션 대상 아님
- **AppCore 에러 (로그 전용)**: TrashStoreError, AnalysisError, SFaceError 등 사용자 미노출 에러는 한글을 영어로 직접 교체 (String Catalog 미등록)
- **랜딩 페이지**: referral 랜딩 OG 메타/본문(i18n-strings.md #485-487)은 서버측 i18n으로 처리 (Accept-Language 또는 URL 경로 분기). 앱 코드 변경 없음

### 3.7 AppCore 패키지 Bundle 전략 (A안 확정)

AppCore는 SPM 패키지이므로 앱의 `Localizable.xcstrings`에 직접 접근할 수 없다. **xcstrings를 앱 1곳에서 통합 관리**하기 위해 A안을 채택한다.

**구현:**
1. AppCore의 사용자 노출 에러에서 `errorDescription` 제거 (`LocalizedError` → `Error`)
2. 앱 호출측(`showCleanupError` 등)에서 에러 케이스별 `String(localized:)` 매핑

```swift
// AppCore — 에러 코드만 정의 (errorDescription 삭제)
enum CleanupImageLoadError: Error {
    case loadFailed(reason: String)
    case timeout
    case invalidFormat
}

// SweepPic 앱 — 표시 시점에 로컬라이제이션
func showCleanupError(_ error: CleanupError) {
    let message: String
    switch error {
    case .analysisFailed(let underlying):
        message = localizedMessage(for: underlying) // String(localized:) 사용
    // ...
    }
}
```

대상 에러 타입: `CleanupImageLoadError`, `VideoFrameExtractError`, `PromotionalOfferService.OfferError`
→ Phase 11에서 처리

### 3.8 법적 문서

- **이용약관/개인정보처리방침**: 외부 URL 링크 (`sweeppic.app/terms`, `/privacy`). 웹 서버에서 URL 경로 분기 (`/en/terms`, `/ko/terms`) 또는 `Accept-Language` 기반 처리. 앱에서는 locale 기반 URL 교체.
- **FAQ**: 12개 Q&A를 String Catalog에 등록 (`monetization.faq.q1` ~ `q12`, `a1` ~ `a12`). 영어 FAQ 새로 작성 필요.
- **사업자 정보**: 현재 TODO 상태. 구현 시 바로 로컬라이제이션 적용.

### 3.9 UI/레이아웃 대응

영어 텍스트가 한국어보다 30-50% 더 길 수 있음. 주요 위험 영역:

1. **버튼**: `adjustsFontSizeToFitWidth = true`, `minimumScaleFactor = 0.8` 추가
2. **코치마크**: `messageLabel.frame` 높이가 80pt로 하드코딩 → `sizeThatFits` 기반 동적 높이로 변경
   - 영향 파일 4개: `CoachMarkOverlayView.swift:463`, `+CoachMarkA1.swift:96`, `+CoachMarkA2.swift:216`, `+CoachMarkC.swift:80`
3. **게이트 팝업**: UIStackView + Auto Layout이므로 자동 대응, iPhone SE에서 검증 필요
4. **비교표**: "인물사진 비교정리"(8자) vs "Face Comparison Cleanup"(24자) — 고정 열 비율에서 검증
5. **textAlignment**: `.left`/`.right` → `.natural`로 변경 (RTL 미래 대비)
   - `PhotoCell.swift:225` (durationLabel)
   - `ViewerViewController.swift:157` (debugLabel — debug 전용이므로 선택적)

### 3.10 테스트 코드 마이그레이션

Base 언어가 영어로 전환되면 테스트 코드의 한글 기대값이 깨진다.

**대상:**
- `CleanupE2ETests.swift` — 한글 결과 메시지 기대값
- 기타 UI 문자열을 직접 비교하는 테스트

**처리:**
- 문자열 비교 테스트는 로컬라이제이션 키 기반으로 전환하거나, 영어 기대값으로 교체
- Phase 5(AutoCleanup) 진행 시 관련 테스트도 함께 수정

### 3.11 테스트 및 검증

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
| `Shared/Components/CoachMarkOverlayView+CoachMarkA1.swift` | NSAttributedString + 키워드 강조 + fallback 패턴 확립 |
| `Sources/AppCore/Services/ReferralService.swift` | 서버 에러 코드 매핑 전환 중심 |
| `Sources/AppCore/Models/AlbumModels.swift` | 스마트 앨범 localizedTitle 전환, 섹션 헤더 로컬라이제이션 |
| `Features/AutoCleanup/UI/CleanupProgressView.swift` | 복수형 + 날짜 포맷 + AttributedString 복합 패턴 |
| `Features/AutoCleanup/UI/CleanupMethodSheet.swift` | 복합 보간 패턴 (패턴 6) 대표 파일 |
| `Features/Monetization/Menu/FAQViewController.swift` | 대량 정적 텍스트 (12 Q&A) |
| `Features/Grid/GridViewController+Cleanup.swift` | 메뉴/Alert/Toast 문자열 집중 |
| `Features/Referral/Share/ReferralShareManager.swift` | 공유 메시지 로컬라이제이션 |
| `supabase/functions/referral-api/index.ts` | 서버 에러 코드 전환 대상 |
| `SweepPic/Info.plist` | NSUserTrackingUsageDescription 영어 전환 |
| `SweepPic/ko.lproj/InfoPlist.strings` | xcstrings 마이그레이션 후 삭제 |
