# Quickstart: BM 수익화 시스템

**Branch**: `003-bm-monetization` | **Date**: 2026-03-03

---

## 개발 환경 설정

### 1. SPM 의존성 추가

Xcode > SweepPic.xcodeproj > Package Dependencies:

```
Google Mobile Ads SDK:
  URL: https://github.com/googleads/swift-package-manager-google-mobile-ads
  Version: 11.x (Up to Next Major)
```

### 2. Info.plist 항목 추가

```xml
<!-- AdMob App ID (테스트용) -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>

<!-- ATT 용도 설명 -->
<key>NSUserTrackingUsageDescription</key>
<string>허용하시면 관련 없는 광고가 줄어듭니다. 데이터는 외부에 판매하지 않습니다.</string>

<!-- SKAdNetwork Items (AdMob) -->
<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
  <!-- 추가 항목은 AdMob 문서 참조 -->
</array>
```

### 3. StoreKit Configuration File

Xcode > File > New > StoreKit Configuration File:
- `SweepPicProducts.storekit` 생성
- 상품 추가:
  - `plus_monthly` (Auto-Renewable, $2.99/월)
  - `plus_yearly` (Auto-Renewable, $19.99/년)

Scheme > Run > Options > StoreKit Configuration: `SweepPicProducts.storekit` 선택

---

## 빠른 검증

### 게이트 단독 테스트

Phase 1 완료 후:

1. 시뮬레이터에서 사진 10장 이상 삭제대기함에 이동
2. "비우기" 탭 → 게이트 팝업 확인
3. "닫기" → 팝업 dismiss 확인
4. FeatureFlags.isGateEnabled = false 시 → 게이트 없이 바로 삭제

### 리워드 광고 테스트

1. AdMob 테스트 광고 ID 사용 (자동 설정됨)
2. 게이트 팝업 → "광고 보고 삭제" → 테스트 광고 재생
3. 광고 완료 → iOS 시스템 팝업 → "삭제" → 완료

### 구독 테스트

Phase 2 완료 후:

1. StoreKit Configuration File로 sandbox 구매
2. 페이월 → "연간 구독" → 결제 성공
3. 삭제대기함 → 게이트 없이 바로 삭제 확인
4. 게이지 미표시 확인

---

## 핵심 파일 진입점

| 시작점 | 파일 | 설명 |
|--------|------|------|
| 게이트 진입 | `TrashGateCoordinator.swift` | 모든 삭제가 이 코디네이터를 거침 |
| 광고 관리 | `AdManager.swift` | 앱 시작 시 configure(), 사전 로드 |
| 구독 관리 | `SubscriptionStore.swift` | StoreKit 2 Transaction 리스닝 |
| 한도 관리 | `UsageLimitStore.swift` | Keychain 기반, 일일 리셋 |
| Grace Period | `GracePeriodService.swift` | 설치일 기반 3일 판단 |

---

## 디버그 팁

```swift
// 한도 강제 리셋 (디버그용)
UsageLimitStore.shared.debugReset()

// Grace Period 강제 만료 (디버그용)
GracePeriodService.shared.debugExpire()

// 구독 상태 확인
print(SubscriptionStore.shared.state)

// 광고 로드 상태 확인
print(AdManager.shared.isRewardedAdReady)
```
