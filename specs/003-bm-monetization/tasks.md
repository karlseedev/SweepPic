# Tasks: BM 수익화 시스템

**Input**: Design documents from `/specs/003-bm-monetization/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/protocols.md

**Tests**: 미포함 (별도 요청 시 추가)

**Organization**: User Story 단위로 구성. 각 Story는 독립적으로 구현/테스트 가능.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 실행 가능 (다른 파일, 의존성 없음)
- **[Story]**: 해당 User Story (US1~US10)
- 파일 경로는 프로젝트 루트(`iOS/`) 기준

---

## Phase 1: Setup (프로젝트 설정)

**Purpose**: SPM 의존성, Info.plist, StoreKit 설정 등 프로젝트 기반 구성

- [x] T001 Google Mobile Ads SDK SPM 의존성 추가 — PickPhoto.xcodeproj > Package Dependencies에 `https://github.com/googleads/swift-package-manager-google-mobile-ads` (11.x Up to Next Major) 추가
- [x] T002 [P] Info.plist에 AdMob/ATT 항목 추가 — `PickPhoto/PickPhoto/Info.plist`에 GADApplicationIdentifier(테스트용 `ca-app-pub-3940256099942544~1458002511`), NSUserTrackingUsageDescription, SKAdNetworkItems 추가
- [x] T003 [P] StoreKit Configuration File 생성 — `PickPhoto/PickPhotoProducts.storekit` 파일 생성, 상품: `plus_monthly` ($2.99/월 Auto-Renewable), `plus_yearly` ($19.99/년 Auto-Renewable). Scheme > Run > Options에서 선택
- [x] T004 [P] FeatureFlags에 BM 플래그 추가 — `PickPhoto/PickPhoto/Shared/FeatureFlags.swift`에 `isGateEnabled`, `isAdEnabled`, `isSubscriptionEnabled` static computed property 추가 (기존 패턴: `isSimilarPhotoEnabled`)
- [x] T005 [P] Monetization 폴더 구조 생성 — `PickPhoto/PickPhoto/Features/Monetization/` 하위에 `Gate/`, `Ad/`, `Subscription/`, `Celebration/`, `Menu/` 빈 폴더 생성

**Checkpoint**: 프로젝트 빌드 성공, AdMob SDK import 가능, StoreKit sandbox 동작 확인

---

## Phase 2: Foundational (핵심 인프라)

**Purpose**: 모든 User Story가 의존하는 핵심 모델/스토어. 이 Phase 완료 전 US 구현 불가

**⚠️ CRITICAL**: US 구현은 이 Phase 완료 후에만 시작

- [x] T006 [P] UsageLimit 모델 생성 — `Sources/AppCore/Models/UsageLimit.swift`. Codable/Sendable 구조체: dailyDeleteCount(Int), dailyRewardCount(Int), lastResetDate(String), lastServerDate(String?), lifetimeFreeGrantUsed(Bool). 상수: dailyFreeLimit=10, rewardBonusPerAd=10, maxDailyRewards=2. 계산 프로퍼티: remainingFreeDeletes, remainingRewards, canDeleteWithinLimit(count:), adsNeeded(for:). data-model.md 참조
- [x] T007 [P] KeychainHelper 유틸리티 생성 — `Sources/AppCore/Services/KeychainHelper.swift`. kSecClassGenericPassword 기반 CRUD. Service=`com.karl.PickPhoto.usageLimit`. save(key:data:), load(key:)->Data?, delete(key:), setBool(key:value:), getBool(key:)->Bool?. kSecAttrAccessibleAfterFirstUnlock 사용. research.md §R3 참조
- [x] T008 UsageLimitStore 생성 — `Sources/AppCore/Stores/UsageLimitStore.swift`. 싱글톤, KeychainHelper 기반. 인메모리 캐시 + Keychain 영속화. UsageLimitStoreProtocol 준수 (contracts/protocols.md). recordDelete(count:), recordReward(), recordLifetimeFreeGrant(), resetIfNewDay(serverDate:). Keychain 읽기 실패 시 한도 내 간주 (FR-051c). T006, T007 완료 후
- [x] T009 [P] GracePeriodService 생성 — `Sources/AppCore/Services/GracePeriodService.swift`. 싱글톤, UserDefaults 기반. GracePeriodServiceProtocol 준수. installDate 1회 기록, isActive(3일 판단), remainingDays, currentDay(0~3+). Keychain hasUsedGracePeriod 체크 — true면 Grace Period 미부여 (FR-051a). 새 기기는 정상 부여 (iCloud Keychain 미동기화)
- [x] T010 AdManager 기본 구조 생성 — `PickPhoto/PickPhoto/Features/Monetization/Ad/AdManager.swift`. 싱글톤, AdManagerProtocol 준수. configure() — GADMobileAds 초기화. shouldShowAds() — Plus/Grace 체크. preloadRewardedAd(), isRewardedAdReady. 테스트 광고 ID 상수 (research.md §R2). T001 완료 후
- [x] T011 AppDelegate에 AdManager.configure() 호출 추가 — `PickPhoto/PickPhoto/App/AppDelegate.swift`의 didFinishLaunching에 AdManager.shared.configure() 추가. T010 완료 후
- [x] T012 SceneDelegate에 한도 리셋 체크 추가 — `PickPhoto/PickPhoto/App/SceneDelegate.swift`의 sceneWillEnterForeground에서 UsageLimitStore.shared.resetIfNewDay(serverDate:) 호출. 서버 시간 확인 실패 시 로컬 시간 폴백 (FR-052). T008 완료 후
- [x] T012a [P] 자정 리셋 알림 등록 — `PickPhoto/PickPhoto/App/SceneDelegate.swift`에서 `NSCalendar.calendarDayChangedNotification` 옵저버 등록. 앱이 포그라운드에서 자정을 넘길 때 UsageLimitStore.resetIfNewDay() 호출 + 게이지 UI 갱신 (FR-005 이중 체크의 두 번째 메커니즘). T008 완료 후

**Checkpoint**: UsageLimitStore 단독 테스트 — recordDelete → remainingFreeDeletes 감소 확인, 날짜 변경 → 리셋 확인, 앱 재시작 시 Keychain에서 복원 확인

---

## Phase 3: User Story 1 — 일일 삭제 한도 & 게이트 팝업 (Priority: P1) 🎯 MVP

**Goal**: 무료 사용자가 한도 초과 시 게이트 팝업을 보고, 한도 내에서는 게이트 없이 삭제

**Independent Test**: 삭제대기함 11장 → "비우기" → 게이트 팝업 표시/닫기. 8장 → 게이트 없이 바로 삭제

### Implementation

- [x] T013 [US1] TrashGateCoordinator 생성 — `PickPhoto/PickPhoto/Features/Monetization/Gate/TrashGateCoordinator.swift`. 싱글톤, TrashGateCoordinatorProtocol 준수. evaluateAndPresent(from:trashCount:onApproved:). 판단 흐름: Plus? → 바로실행 / Grace Period? → 바로실행 / ≤남은한도? → 바로실행+recordDelete / 초과? → 팝업 표시. 필요 광고 수 N = ceil((trashCount - remainingFreeDeletes) / 10). plan.md 게이트 판단 흐름 참조
- [x] T014 [US1] TrashGatePopupViewController 생성 — `PickPhoto/PickPhoto/Features/Monetization/Gate/TrashGatePopupViewController.swift`. 커스텀 중앙 팝업: modalPresentationStyle=.overFullScreen, crossDissolve. 반투명 배경 + 중앙 라운드 카드. 안내 텍스트("삭제대기함을 비우려면 / N장 · 한도 M장 남음") + 광고 버튼(Ready/Loading/Failed 3상태) + Plus 버튼 + 닫기 버튼. 광고 소진 시 "Plus만 가능" 분기. 오프라인 시 광고/구독 비활성 + "인터넷 연결 필요" (FR-055). plan.md 게이트 팝업 UI 레이아웃 참조
- [x] T015 [P] [US1] UsageGaugeView 생성 — `PickPhoto/PickPhoto/Features/Monetization/Gate/UsageGaugeView.swift`. 프로그레스 바 + "N/M장 남음" 텍스트. 탭 시 상세 팝업 (한도 상태 + 광고 잔여 + "광고 보기" 버튼). Plus/Grace Period 시 미표시. accessibilityLabel 설정 (FR-057)
- [x] T016 [US1] TrashAlbumViewController+Gate.swift Extension 생성 — `PickPhoto/PickPhoto/Features/Albums/TrashAlbumViewController+Gate.swift`. 게이지 뷰 setup/update, Grace Period 배너 placeholder (US3에서 구현), 게이트 호출 헬퍼. 기존 TrashAlbumVC 786줄 방지를 위한 Extension 분리
- [x] T017 [US1] 게이트 삽입 #1 — `PickPhoto/PickPhoto/Features/Albums/TrashAlbumViewController.swift:593` performEmptyTrash()를 TrashGateCoordinator.evaluateAndPresent()로 래핑. plan.md 게이트 삽입 패턴 참조
- [x] T018 [US1] 게이트 삽입 #2 — `PickPhoto/PickPhoto/Features/Albums/TrashSelectMode.swift:173` trashDeleteSelectedTapped()를 게이트 래핑
- ~~T019~~ 삭제 — 삭제대기함에서만 발생하는 작업이므로 GridViewController 게이트 불필요
- ~~T020~~ 삭제 — 삭제대기함에서만 발생하는 작업이므로 AlbumGridViewController 게이트 불필요

**Checkpoint**: 2개 삽입 지점(비우기, 선택삭제)에서 한도 초과 시 게이트 팝업 표시. 10장 이하 → 게이트 없이 삭제. "닫기" → dismiss. 게이지 바 표시 + 탭 상세 팝업

---

## Phase 4: User Story 2 — 리워드 광고로 한도 확장 (Priority: P1)

**Goal**: 게이트에서 광고 시청 → 한도 +10장 → 삭제 실행

**Independent Test**: 게이트 팝업 → "광고 보고 삭제" → 테스트 광고 재생 → 삭제 실행

### Implementation

- [x] T021 [US2] RewardedAdPresenter 생성 — `PickPhoto/PickPhoto/Features/Monetization/Ad/RewardedAdPresenter.swift`. GADRewardedAd 래핑. showAd(from:completion:(Bool)->Void). 시청 완료=true, 취소/에러=false. 사전 로드 + 시청 완료 후 즉시 다음 로드 (FR-019). 지수 백오프 재시도 2→4→8초 (FR-020)
- [x] T022 [US2] TrashGatePopupVC에 광고 흐름 연동 — `TrashGatePopupViewController.swift` 수정. "광고 N회 보고 X장 삭제" 버튼 탭 → 팝업 dismiss → RewardedAdPresenter.showAd → 완료 시 삭제 콜백. 광고 버튼 3단계 상태 (Ready/Loading/Failed) (FR-018). 시스템 팝업 취소 시 리워드 미차감 (FR-013). no-fill: 스피너 10초 → 재시도/취소 팝업
- [x] T023 [US2] 생애 최초 no-fill 무료 +10장 처리 — `TrashGateCoordinator.swift` 또는 `RewardedAdPresenter.swift`에서 lifetimeFreeGrantUsed 체크. 최초 no-fill 시 usageLimitStore.recordLifetimeFreeGrant() 호출 (FR-021)
- [x] T024 [US2] 골든 모먼트 UI — `TrashGatePopupViewController.swift`에서 리워드 2회 소진 시 Plus 전환 유도 강조 UI (FR-014). 광고 옵션 비활성 + "오늘 광고 횟수를 모두 사용했습니다" 안내

**Checkpoint**: 테스트 광고 ID로 시청 → 한도 +10 → 삭제 실행. 시스템 팝업 취소 → 리워드 미차감. 2회 소진 → 골든 모먼트 표시

---

## Phase 5: User Story 3 — Grace Period (Priority: P1)

**Goal**: 신규 사용자 3일간 무제한 체험 + 단계별 배너로 전환 유도

**Independent Test**: 앱 설치 직후 → 게이트/광고 없이 무제한 삭제. Day 4 → 게이지 전환

### Implementation

- [x] T025 [US3] Grace Period 배너 UI 구현 — `TrashAlbumViewController+Gate.swift`에 배너 뷰 추가. 게이지 위치에 "무료 체험 중 — N일 남음" + "체험 종료 후 일일 무료 삭제 한도가 적용됩니다" 배너 표시. 모든 Day 동일 UI (CTA 없음). 배너 탭 → 페이월 (FR-025, 페이월은 US4에서 구현 — 탭 핸들러만 준비)
- [x] T026 [US3] Day 4 전환 로직 — `TrashAlbumViewController+Gate.swift`에서 Grace Period 만료 시 배너 → 게이지 전환. 게이지 첫 표시 시 1회 툴팁 "오늘의 무료 삭제 한도예요. 탭해서 자세히 볼 수 있어요" (Edge Case: 카운터 게이지 첫 표시)
- [x] T027 [US3] TrashGateCoordinator Grace Period 바이패스 확인 — T013에서 이미 Grace Period 체크 포함. 실제 통합 테스트: Grace Period 중 게이트/광고 미표시 확인. Grace Period 중 구독 시 즉시 종료 → Plus 전환 (Edge Case)

**Checkpoint**: 설치 직후 무제한 삭제. 배너 모든 Day 동일 UI 확인. Day 4 게이지 + 툴팁

---

## Phase 6: User Story 4 — Plus 구독 & 페이월 (Priority: P2)

**Goal**: 페이월에서 구독 구매 → Plus 활성화 → 모든 제한 해제

**Independent Test**: 페이월 → Sandbox 구독 → Plus 활성화 → 게이트 스킵 + 광고 미표시

### Implementation

- [x] T028 [P] [US4] SubscriptionTier 모델 생성 — `Sources/AppCore/Models/SubscriptionTier.swift`. SubscriptionTier enum(.free/.plus) + SubscriptionState 구조체(tier, isActive, autoRenewEnabled, hasPaymentIssue, expirationDate, originalPurchaseDate). data-model.md 참조
- [x] T029 [US4] SubscriptionStore 생성 — `PickPhoto/PickPhoto/Features/Monetization/Subscription/SubscriptionStore.swift`. 싱글톤, SubscriptionStoreProtocol 준수. StoreKit 2: Product.products(for:), Product.purchase(), Transaction.currentEntitlements, Transaction.updates AsyncSequence. 앱 시작 시 구독 확인 (FR-028). 실시간 변경 감지 (FR-029). 환불 → Plus 즉시 해제 (FR-033). 오프라인: expirationDate 기반 (FR-053). 구독 완료 시 GracePeriodService.shared.endGracePeriod() 호출하여 Grace Period 즉시 종료 (Edge Case). T028 완료 후
- [x] T030 [US4] PaywallViewModel 생성 — `PickPhoto/PickPhoto/Features/Monetization/Subscription/PaywallViewModel.swift`. 가격 포맷팅 (NumberFormatter, locale 반영). 연간 메인 + 월간 보조 가격 표시. 취소선 정가 계산. 무료/Plus 비교표 데이터
- [x] T031 [US4] PaywallViewController 생성 — `PickPhoto/PickPhoto/Features/Monetization/Subscription/PaywallViewController.swift`. 가치 헤드라인 "쌓인 사진, 한 번에 비우세요" + 비교표 (FR-035). 연간 크게 / 월간 보조 (FR-036). 하단 법적 고지: 자동 갱신, 해지 방법, 약관/처리방침 링크 — 스크롤 없이 보이는 영역 (FR-037). 구매 버튼 → SubscriptionStore.purchase(). 복원 버튼 → restorePurchases(). 리딤 코드 버튼 → presentRedemptionSheet (FR-031). 결제 실패별 안내 (FR-038). Ask to Buy (FR-038)
- [x] T032 [US4] TrashGateCoordinator 구독 연동 — `TrashGateCoordinator.swift` 수정. SubscriptionStore.shared.isPlusUser 체크 추가 (이미 T013에서 구조 준비됨). Plus → 게이트 즉시 스킵
- [x] T033 [US4] AdManager 구독 연동 — `AdManager.swift` 수정. shouldShowAds()에 SubscriptionStore.isPlusUser 반영. Plus → 모든 광고 미표시 (FR-027)
- [x] T034 [US4] AppDelegate에 SubscriptionStore.configure() 추가 — `AppDelegate.swift` 수정. didFinishLaunching에 SubscriptionStore.shared.configure() 추가
- [x] T035 [US4] 갱신 실패 뱃지 표시 — SubscriptionStore.hasPaymentIssue 감지 시 ellipsis 메뉴 아이콘에 ⚠️ 뱃지 (FR-034). `GridViewController+Cleanup.swift` 또는 관련 메뉴 버튼 수정

**Checkpoint**: Sandbox 구독 구매 → Plus 활성화 → 게이트 스킵 + 광고 미표시. 복원 성공. 리딤 코드 입력. 환불 → Free 복귀

---

## Phase 7: User Story 5 — 전면 광고 & 배너 광고 (Priority: P2)

**Goal**: 정리 완료 시 전면 광고, 분석 대기 시 배너 광고로 추가 수익

**Independent Test**: 유사사진 삭제 완료 2회차 → 전면 광고. 분석 시작 → 배너 확인

### Implementation

- [x] T036 [P] [US5] InterstitialAdPresenter 생성 — `PickPhoto/PickPhoto/Features/Monetization/Ad/InterstitialAdPresenter.swift`. GADInterstitialAd 래핑. showAd(from:completion:). 사전 로드 + 표시 완료 후 즉시 다음 로드. 스킵 가능 (FR-016). 테스트 광고 ID (research.md §R2)
- [x] T037 [P] [US5] BannerAdViewController 생성 — `PickPhoto/PickPhoto/Features/Monetization/Ad/BannerAdViewController.swift`. GADBannerView 래핑. 사진 분석 대기 화면 하단에 삽입 가능한 컨테이너 뷰컨 (FR-017)
- [x] T038 [US5] 전면 광고 트리거 연동 — AdCounters(인메모리) 구현 + 유사사진 삭제 완료 / 자동정리 완료 짝수 회차에만 표시 (FR-015). 각 트리거별 독립 카운터. 관련 파일: `GridViewController+SimilarPhoto.swift`, `GridViewController+Cleanup.swift` 수정
- [x] T039 [US5] 배너 광고 삽입 — 사진 분석 대기 화면(유사사진 분석 중 표시 화면) 하단에 BannerAdViewController embed. Plus/Grace Period 시 미표시

**Checkpoint**: 유사사진 2회차 → 전면 광고. 홀수 회차 → 미표시. 분석 대기 → 배너 표시. Plus → 모두 미표시

---

## Phase 8: User Story 6 — ATT 동의 흐름 (Priority: P2)

**Goal**: Grace Period 후 첫 실행 시 프리프롬프트 → 시스템 ATT 팝업

**Independent Test**: Grace Period 만료 후 앱 실행 → 프리프롬프트 → 시스템 팝업 순서

### Implementation

- [x] T040 [US6] ATTPromptViewController 생성 — `PickPhoto/PickPhoto/Features/Monetization/Ad/ATTPromptViewController.swift`. 전체 화면 프리프롬프트. 문구: "허용하시면 관련 없는 광고가 줄어듭니다. 데이터는 외부에 판매하지 않습니다." (FR-042). "계속" → ATTrackingManager.requestTrackingAuthorization() 호출 → dismiss. "건너뛰기" → skipCount 증가 → dismiss
- [x] T041 [US6] ATTState 관리 + SceneDelegate 연동 — UserDefaults에 ATTState(skipCount, hasShownPrompt) 저장. `SceneDelegate.swift` sceneDidBecomeActive에서: Grace Period 만료 + ATT .notDetermined + skipCount < 2 → ATTPromptVC present (FR-041). data-model.md ATTState 참조

**Checkpoint**: Grace Period 만료 후 첫 실행 → 프리프롬프트. "계속" → 시스템 팝업. "건너뛰기" → 다음 실행 재표시 → 2차 건너뛰기 → 영구 미표시

---

## Phase 9: User Story 7 — 축하 화면 (Priority: P2)

**Goal**: 비우기 성공 후 삭제 통계/확보 용량 축하 화면

**Independent Test**: 삭제대기함 비우기 완료 → 축하 화면 → 통계 정확성

### Implementation

- [x] T042 [P] [US7] DeletionStats 모델 생성 — `Sources/AppCore/Models/DeletionStats.swift`. Codable/Sendable: totalDeletedCount(Int), totalFreedBytes(Int64), lastUpdated(Date). CelebrationResult 구조체도 동일 파일에 포함: sessionDeletedCount, sessionFreedBytes, totalDeletedCount, totalFreedBytes
- [x] T043 [US7] DeletionStatsStore 생성 — `Sources/AppCore/Stores/DeletionStatsStore.swift`. 싱글톤, DeletionStatsStoreProtocol 준수. Documents/DeletionStats.json 영구 저장 (TrashStore 패턴: JSONEncoder, iso8601, atomic write, serial queue). addStats(deletedCount:freedBytes:). 파일 손상 시 0 초기화 (FR-040a)
- [x] T044 [US7] 파일 크기 계산 유틸리티 — `Sources/AppCore/Services/FileSizeCalculator.swift`. PHAssetResource.assetResources(for:)로 각 asset의 fileSize 합산. 백그라운드 큐에서 실행 (research.md §R4). 실패 시 0 반환
- [x] T045 [US7] CelebrationViewController 생성 — `PickPhoto/PickPhoto/Features/Monetization/Celebration/CelebrationViewController.swift`. "N장 삭제 완료!" (이번) + "총 M장 삭제" (누적) + "X.XGB 확보" (누적). 용량 단위 자동 변환 (KB/MB/GB). "확인" → dismiss (FR-039)
- [x] T046 [US7] 축하 화면 체인 연결 — `TrashAlbumViewController.swift` 또는 `TrashAlbumViewController+Gate.swift` 수정. emptyTrash 성공 후 → FileSizeCalculator로 용량 계산 → DeletionStatsStore.addStats → CelebrationResult 생성 → CelebrationVC present. `TrashStore.swift`에 완료 콜백 추가 (FR-040, FR-040b)

**Checkpoint**: 비우기 성공 → 축하 화면 표시. 이번/누적 통계 정확. 앱 재시작 후 누적 유지

---

## Phase 10: User Story 8 — 전체 메뉴 & 고객센터 (Priority: P2)

**Goal**: ellipsis 메뉴에 프리미엄/고객센터 서브메뉴 추가

**Independent Test**: 전체 메뉴 → 각 하위 항목 탭 → 해당 화면 표시

### Implementation

- [x] T047 [P] [US8] PremiumMenuViewController 생성 — `PickPhoto/PickPhoto/Features/Monetization/Menu/PremiumMenuViewController.swift`. "구독 관리" (무료→페이월, Plus→시스템 구독관리), "구독 복원" (이미 Plus→토스트), "리딤 코드" (FR-043, FR-044). SubscriptionStore 연동
- [x] T048 [P] [US8] CustomerServiceViewController 생성 — `PickPhoto/PickPhoto/Features/Monetization/Menu/CustomerServiceViewController.swift`. "피드백 보내기", "자주 묻는 질문", "이용약관", "개인정보처리방침", "사업자 정보" 메뉴 리스트
- [x] T049 [P] [US8] FAQViewController 생성 — `PickPhoto/PickPhoto/Features/Monetization/Menu/FAQViewController.swift`. 인앱 정적 아코디언 리스트, 오프라인 지원 (FR-046)
- [x] T050 [P] [US8] BusinessInfoViewController 생성 — `PickPhoto/PickPhoto/Features/Monetization/Menu/BusinessInfoViewController.swift`. 상호/대표자/등록번호/연락처 정적 표시 (FR-048, 전자상거래법 제10조)
- [x] T051 [US8] 피드백 이메일 구현 — `CustomerServiceViewController.swift`에서 "피드백 보내기" 탭 → MFMailComposeViewController (받는 사람/제목/기기 정보 프리셋). 미지원 기기 → mailto: URL 폴백 (FR-045, Edge Case)
- [x] T052 [US8] 이용약관/개인정보처리방침 인앱 브라우저 — `CustomerServiceViewController.swift`에서 SFSafariViewController로 웹 링크 (FR-047)
- [x] T053 [US8] ellipsis 메뉴 재구성 — `PickPhoto/PickPhoto/Features/Grid/GridViewController+Cleanup.swift` 수정. 기존 6개 메뉴 항목을 "프리미엄 ▸" / "고객센터 ▸" 서브메뉴로 재구성 (FR-043). UIMenu 하위 UIMenu 사용

**Checkpoint**: 전체 메뉴 → 프리미엄 ▸ (3항목) / 고객센터 ▸ (5항목) 각각 정상 동작

---

## Phase 11: User Story 9 — 리뷰 요청 (Priority: P3)

**Goal**: 만족 가능성 높은 시점에 App Store 리뷰 팝업

**Independent Test**: 조건 충족 + 트리거 이벤트 → 리뷰 팝업. 금지 타이밍 → 미표시

### Implementation

- [x] T054 [US9] ReviewService 생성 — `Sources/AppCore/Services/ReviewService.swift`. ReviewServiceProtocol 준수. ReviewTracker(UserDefaults): sessionCount, totalTrashMoveCount, lastRequestDate, lastRequestedVersion. recordSession(), recordTrashMove(count:). evaluateAndRequestIfNeeded(from:isProhibitedTiming:) — 5개 조건 체크 (FR-049) + 금지 타이밍 (FR-050). SKStoreReviewController.requestReview(in:). data-model.md ReviewTracker 참조
- [x] T055 [US9] ReviewService 트리거 연동 — `SceneDelegate.swift`에 recordSession() 추가. 삭제대기함 이동 시 recordTrashMove(). 삭제 완료/자동정리 완료 등 트리거 이벤트에서 evaluateAndRequestIfNeeded() 호출. isProhibitedTiming: 광고 직후, 결제 직후, 에러 세션, 게이트 직후 플래그 관리

**Checkpoint**: 조건 충족 + 비금지 타이밍 → 리뷰 팝업. 금지 타이밍에서 미표시. 90일 쿨다운 동작

---

## Phase 12: User Story 10 — 분석 이벤트 로깅 (Priority: P3)

**Goal**: 핵심 KPI 측정을 위한 비즈니스 이벤트 기록

**Independent Test**: 각 이벤트 발생 시 로그 기록 확인

### Implementation

- [x] T056 [US10] MonetizationAnalytics 생성 — `PickPhoto/PickPhoto/Shared/Analytics/MonetizationAnalytics.swift`. 이벤트 정의: gateShown(trashCount:remainingLimit:), gateSelection(choice:), adWatched(type:), paywallShown(source:), subscriptionCompleted(tier:), deletionCompleted(count:), gracePeriodEnded, attResult(authorized:). 기존 AnalyticsService 패턴 활용 (FR-056)
- [x] T057 [US10] 이벤트 삽입 — 각 BM 컴포넌트에 MonetizationAnalytics 호출 추가. TrashGateCoordinator(게이트 노출/선택), RewardedAdPresenter/InterstitialAdPresenter(광고), SubscriptionStore(구독), PaywallViewController(페이월), ATTPromptViewController(ATT), SceneDelegate(Grace Period 종료 첫 세션)

**Checkpoint**: 각 이벤트 트리거 시 로그 출력 확인 (Logger로 검증)

---

## Phase 13: Polish & Cross-Cutting Concerns

**Purpose**: 전체 기능 점검, 접근성, 엣지 케이스 마무리

- [x] T058 [P] 접근성 일괄 점검 — 모든 신규 BM UI에 accessibilityLabel 설정 확인 (FR-057). VoiceOver 활성화 시 게이트 팝업/게이지/배너/페이월 적절한 동작
- [x] T059 [P] 오프라인 시나리오 검증 — 오프라인 + 한도 내 삭제 정상 (FR-054). 오프라인 + 한도 초과 → 광고/구독 비활성 (FR-055). 오프라인 + 구독자 → expirationDate 기반 정상 동작 (FR-053)
- [x] T060 [P] 엣지 케이스 핸들링 확인 — Keychain 접근 실패 폴백 (FR-051c). DeletionStats 파일 손상 → 0 초기화 (FR-040a). 오프라인 시계 조작 → 온라인 복귀 시 재계산 (FR-052a). Grace Period 재설치 방지 (FR-051a)
- [x] T061 quickstart.md 검증 실행 — specs/003-bm-monetization/quickstart.md의 빠른 검증 시나리오 모두 수행
- [x] T062 코드 정리 — 모든 신규 파일 1,000줄 미만 확인. 미사용 import 제거. 주석 검토. FeatureFlags로 완전 비활성화 가능 확인

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 의존성 없음 — 즉시 시작
- **Phase 2 (Foundational)**: Phase 1 완료 후 — **모든 US 차단**
- **Phase 3~5 (US1~US3, P1)**: Phase 2 완료 후 순차 실행 (US1 → US2 → US3, 의존 관계)
- **Phase 6~10 (US4~US8, P2)**: Phase 5 완료 후. US4~US8 내에서는 대부분 독립적이나, US4(구독)가 US5~US8의 구독 연동에 필요
- **Phase 11~12 (US9~US10, P3)**: Phase 10 완료 후. US9, US10은 독립적
- **Phase 13 (Polish)**: 모든 US 완료 후

### User Story Dependencies

```
Setup → Foundational → US1(게이트) → US2(리워드) → US3(Grace Period)
                                                          │
                                                          ▼
                           US4(구독) → US5(전면/배너) ──→ US8(메뉴)
                              │            │
                              ▼            ▼
                           US6(ATT)    US7(축하)
                                                          │
                                                          ▼
                                          US9(리뷰) ──→ US10(분석) → Polish
```

- **US1 → US2**: 게이트 팝업이 있어야 광고 버튼 연동 가능
- **US1 → US3**: 게이지/배너 위치가 같아서 US1 기반 필요
- **US4 독립**: Phase 2 완료 후 바로 시작 가능하나, US1~3 이후가 자연스러움
- **US5~US8**: US4(구독 상태) 연동 필요하나, 순서는 유연
- **US9, US10**: 다른 US에 로깅/트리거 삽입이므로 해당 US 완료 후

### Within Each User Story

- 모델 → 스토어 → 코디네이터/서비스 → UI → 기존 파일 수정
- 50줄 이상 수정 전 커밋 (CLAUDE.md 규칙)

### Parallel Opportunities

Phase 2 내:
```
T006(UsageLimit 모델) ∥ T007(KeychainHelper) ∥ T009(GracePeriodService)
```

Phase 6 내:
```
T028(SubscriptionTier) ∥ T036(InterstitialAd) ∥ T037(BannerAd)
```

Phase 10 내:
```
T047(PremiumMenu) ∥ T048(CustomerService) ∥ T049(FAQ) ∥ T050(BusinessInfo)
```

---

## Implementation Strategy

### MVP First (US1~US3)

1. Phase 1: Setup
2. Phase 2: Foundational (CRITICAL)
3. Phase 3: US1 게이트 — **STOP & VALIDATE**: 한도 초과 게이트 동작 확인
4. Phase 4: US2 리워드 — **STOP & VALIDATE**: 광고 → 삭제 흐름 확인
5. Phase 5: US3 Grace Period — **STOP & VALIDATE**: 3일 무제한 + 배너 전환

### Incremental Delivery

1. US1~3 완료 → 게이트+광고+Grace Period MVP
2. US4 추가 → 구독/페이월 가능
3. US5~8 추가 → 전면/배너/ATT/축하/메뉴 완성
4. US9~10 추가 → 리뷰/분석
5. Polish → 출시 준비 완료

---

## Summary

| 항목 | 수치 |
|------|------|
| 총 태스크 | 62개 |
| Phase 1 (Setup) | 5개 |
| Phase 2 (Foundational) | 7개 |
| US1 (게이트) | 8개 |
| US2 (리워드) | 4개 |
| US3 (Grace Period) | 3개 |
| US4 (구독) | 8개 |
| US5 (전면/배너) | 4개 |
| US6 (ATT) | 2개 |
| US7 (축하) | 5개 |
| US8 (메뉴) | 7개 |
| US9 (리뷰) | 2개 |
| US10 (분석) | 2개 |
| Polish | 5개 |
| 병렬 가능 태스크 | 23개 ([P] 마커) |
| MVP 범위 | US1~US3 (22개 태스크) |
