# Research: BM 수익화 시스템

**Branch**: `003-bm-monetization` | **Date**: 2026-03-03

---

## R1: StoreKit 2 구독 관리 패턴

**Decision**: StoreKit 2 네이티브 사용 (서버리스, RevenueCat 미사용)

**Rationale**:
- iOS 16+ 타겟이므로 StoreKit 2 전면 사용 가능
- 단일 상품(Plus 월간/연간)이라 SDK 래퍼 불필요
- 서버 없이 온디바이스 검증 가능 (AppTransaction, Transaction.currentEntitlements)
- RevenueCat 수수료(월 $0~$2,500 구간 무료, 이후 1%) 절감

**핵심 API**:
- `Product.products(for:)` — 상품 목록 로드
- `Product.purchase()` — 구매 실행
- `Transaction.currentEntitlements` — 활성 구독 확인
- `Transaction.updates` — 실시간 상태 변경 감지 (AsyncSequence)
- `AppStore.sync()` — 구매 복원
- `SKPaymentQueue.presentCodeRedemptionSheet()` — 리딤 코드 (iOS 16+)

**구독 상태 확인 흐름**:
1. 앱 시작 → `Transaction.currentEntitlements` 순회
2. `Transaction.updates` AsyncSequence 리스닝 시작 (앱 실행 중 상태 변경 감지)
3. 환불/만료 → entitlement 사라짐 → Free tier 복귀

**Alternatives Considered**:
- RevenueCat: 다중 플랫폼/복잡한 상품이면 유리하나, 단일 iOS 앱 + 1상품이라 과도
- 자체 서버 검증: 서버리스 원칙에 위배

---

## R2: Google Mobile Ads (AdMob) 통합

**Decision**: AdMob 단일 네트워크로 시작 (미디에이션 없음)

**Rationale**:
- 출시 초기 fill rate 확인 후 미디에이션 추가 결정
- SPM 지원: `https://github.com/googleads/swift-package-manager-google-mobile-ads` (11.x)

**광고 유형별 구현**:

| 유형 | 클래스 | 사전 로드 | 표시 시점 |
|------|--------|-----------|-----------|
| 리워드 | GADRewardedAd | 앱 시작 + 시청 완료 후 즉시 | 게이트 시트 → "광고 보고 삭제" |
| 전면 | GADInterstitialAd | 완료 이벤트 전 | 유사사진/자동정리 짝수 회차 |
| 배너 | GADBannerView | 화면 진입 시 | 사진 분석 대기 화면 하단 |

**no-fill 처리**:
- 로드 실패 → 지수 백오프 재시도 (2→4→8초)
- 버튼 상태: Ready → Loading(스피너) → Failed
- 생애 최초 no-fill → 1회 무료 +10장 (UserDefaults 플래그)

**테스트 광고 ID** (개발용):
- Rewarded: `ca-app-pub-3940256099942544/1712485313`
- Interstitial: `ca-app-pub-3940256099942544/4411468910`
- Banner: `ca-app-pub-3940256099942544/2435281174`

**Info.plist 필수 항목**:
- `GADApplicationIdentifier`: AdMob 앱 ID
- `NSUserTrackingUsageDescription`: ATT 용도 설명
- `SKAdNetworkItems`: 광고 어트리뷰션 (AdMob 제공 목록)

**Alternatives Considered**:
- AppLovin MAX 미디에이션: 출시 초기에는 불필요한 복잡성
- Unity Ads: iOS 네이티브 앱에는 AdMob이 생태계 적합

---

## R3: Keychain 기반 악용 방지

**Decision**: UsageLimit 데이터를 Keychain에 저장 (앱 삭제/재설치 후에도 유지)

**Rationale**:
- FR-051: "앱 삭제/재설치에도 유지되는 보안 저장소"
- Keychain은 앱 삭제 시에도 데이터 유지 (kSecAttrAccessibleAfterFirstUnlock)
- Documents/JSON은 앱 삭제 시 함께 삭제됨

**구현 접근**:
- `kSecClassGenericPassword` 사용
- Service: `com.karl.SweepPic.usageLimit`
- Account: `dailyUsage`
- JSON 인코딩된 UsageLimit 구조체를 Data로 저장
- 읽기/쓰기 시 메인 스레드 블로킹 최소화 (Keychain 접근은 동기적이나 매우 빠름)

**인메모리 캐시**:
- 앱 시작 시 Keychain → 인메모리 로드 (1회)
- 변경 시 인메모리 갱신 + Keychain 쓰기 (비동기 불필요, <1ms)
- 한도 체크는 항상 인메모리에서 (성능)

**Alternatives Considered**:
- UserDefaults: 앱 삭제 시 함께 삭제됨 → 악용 방지 불가
- Documents/JSON: 동일 문제
- 서버 기반: 서버리스 원칙 위배

---

## R4: 파일 크기 계산 (확보 용량)

**Decision**: PHAssetResource.assetResources(for:)로 실제 파일 크기 합산, 백그라운드 스레드에서 실행

**Rationale**:
- PHAsset에는 파일 크기 프로퍼티 없음
- PHAssetResource의 `value(forKey: "fileSize")` 또는 `fileSize` (private but widely used)
- 메인 스레드 블로킹 이슈 → 반드시 백그라운드에서 실행

**구현 접근**:
1. 삭제 실행 직전 (performEmptyTrash 시점), 삭제 대상 PHAsset 목록 확보
2. 백그라운드 큐에서 각 PHAsset의 PHAssetResource 조회 → fileSize 합산
3. 합산 결과를 CelebrationResult에 포함
4. 삭제 완료 후 DeletionStats에 누적 반영

**fileSize 접근 방법**:
```swift
let resources = PHAssetResource.assetResources(for: asset)
let size = resources.first.flatMap {
    $0.value(forKey: "fileSize") as? Int64
} ?? 0
```

**성능 고려**:
- 100장 기준 ~0.5초 (백그라운드)
- 게이트 시트 표시 중 또는 광고 시청 중에 병렬 계산 가능
- 계산 실패 시 0으로 처리 (축하 화면에서 용량 미표시)

**Alternatives Considered**:
- 평균 파일 크기 추정: 부정확, 사용자 신뢰 저하
- ImageIO로 직접 읽기: PHAssetResource보다 느리고 복잡

---

## R5: 서버 시간 기반 한도 리셋

**Decision**: 기존 Supabase 연결을 활용하여 서버 시간 확인

**Rationale**:
- FR-052: "기기 시계 조작으로 우회할 수 없어야 한다"
- Supabase가 이미 통합되어 있으므로 별도 NTP 불필요
- HTTP 응답 헤더의 `Date` 필드로 서버 시간 확인

**구현 접근**:
1. 온라인 시: Supabase API 응답의 `Date` 헤더 파싱 → 서버 날짜 기준 리셋 판단
2. 오프라인 시: 로컬 시간 기준 리셋 (조작 가능하나, 온라인 복귀 시 교정)
3. 마지막 확인된 서버 날짜를 Keychain에 캐싱 → 시계 되돌리기 감지

**교정 흐름**:
- 앱 포그라운드 → 서버 시간 확인 → 로컬 날짜와 비교
- 서버 날짜 > 마지막 리셋 날짜 → 리셋 허용
- 서버 날짜 ≤ 마지막 리셋 날짜 → 리셋 거부 (이미 리셋됨)
- 오프라인 + 로컬 날짜 < 마지막 서버 날짜 → 리셋 거부 (시계 되돌리기 감지)

**Alternatives Considered**:
- NTP (worldtimeapi.org 등): 추가 의존성, Supabase로 충분
- Apple NTP: 직접 접근 불가
- 서버 없이 로컬만: 시계 조작에 취약

---

## R6: ATT 프리프롬프트 구현

**Decision**: 전체 화면 커스텀 프리프롬프트 → ATTrackingManager.requestTrackingAuthorization

**Rationale**:
- 프리프롬프트로 옵트인율 ~50% 목표 (시스템 팝업만 시 ~25%)
- Grace Period 종료 후 첫 앱 실행 시 표시 (게이트와 분리)

**표시 시점 결정 흐름** (SceneDelegate에서):
1. `sceneDidBecomeActive` → GracePeriodService.isExpired 확인
2. 만료됨 + ATT 미결정(`ATTrackingManager.trackingAuthorizationStatus == .notDetermined`) + 프리프롬프트 미표시
3. → ATTPromptViewController를 모달로 present

**재시도 로직**:
- 1차 건너뛰기 → `attSkipCount = 1` (UserDefaults)
- 다음 앱 실행 시 1회 재표시
- 2차 건너뛰기 → `attSkipCount = 2` → 영구 미표시

**Alternatives Considered**:
- 게이트 진입 시 표시: 부정적 경험 중첩 (주인님과 합의하여 분리)
- 첫 실행 시 표시: 맥락 없음, Grace Period 중 광고 없어서 의미 없음

---

## R7: 커스텀 게이트 팝업 구현

**Decision**: 커스텀 중앙 팝업 (기존 앱 패턴과 동일)

**Rationale**:
- 앱 내 기존 팝업이 가운데 뜨는 커스텀 방식으로 통일되어 있음
- UISheetPresentationController 바텀시트는 기존 앱 UX와 이질적
- 게이트가 수익 전환 핵심 UI라서 디자인 자유도 필요

**구현 접근**:
- UIViewController를 모달로 present (modalPresentationStyle = .overFullScreen, .crossDissolve)
- 반투명 배경(dim) + 중앙 카드 형태
- 카드 내: 안내 텍스트 + 버튼 목록 (광고 보기 / Plus / 닫기)
- 기존 CoachMarkOverlayView 또는 alert 커스텀 패턴 참고

**Alternatives Considered**:
- UISheetPresentationController: 기존 앱 UX와 불일치
- UIAlertController: 커스텀 레이아웃 한계
