# SweepPic App Review Notes (심사자 메모)

> App Store Connect → App Review Information → Notes 에 입력

---

## 한글 원본

```
[전체 사진 라이브러리 접근이 필요한 이유]
1. 사진 정리: 사용자의 전체 사진 라이브러리를 정리하는 것이 핵심 목적입니다.
   PHPicker는 개별 사진 선택만 가능하여 라이브러리 전체 정리에 부적합합니다.
2. 유사 사진 감지: 유사도 분석을 위해 라이브러리의 모든 사진을 비교해야 합니다.
3. 그리드 브라우징: 네이티브 사진 앱처럼 전체 라이브러리를 스크롤하며 탐색합니다.

[기본 사진 앱과의 차별점]
- 스와이프 삭제: 그리드에서 썸네일을 스와이프하면 바로 삭제. 확인 팝업 없이 빠르게 정리, 실수로 지워도 복구 가능
- 얼굴 크롭 비교: 유사 사진에서 동일 인물의 얼굴을 자동 크롭·확대하여 나란히 비교. 썸네일이 아닌 확대된 얼굴로 표정 차이까지 확인
- AI 자동 정리: 흔들린/어두운/밝은 사진을 AI가 자동 감지. 3단계 범위 조절, 즐겨찾기·인물 사진은 자동 보호
- 삭제대기함: 삭제 → 삭제대기함 보관 → 비우기 → iOS 휴지통 30일 복구. 2단계 안전장치

[얼굴 인식 — 기기 내 처리]
- Apple Vision Framework 사용, 100% 기기 내 처리
- 얼굴 데이터는 외부 전송, 저장, 추적/광고에 사용하지 않음

[테스트 안내]
- 앱 실행 후 사진 라이브러리 접근 권한을 허용해 주세요.
- 무료 기능: 그리드 브라우징, 유사사진 분석, 자동정리, 삭제대기함 이동은 무제한 무료입니다.
- 일일 영구 삭제 한도: 무료 10장. 신규 설치 후 3일간은 무제한(Grace Period).
- 게이트 테스트: 삭제대기함에 11장 이상 담긴 상태에서 "비우기" 탭 → 게이트 시트 표시.
- 리워드 광고 테스트: 게이트 시트 → "광고 보고 삭제" 탭 → 광고 시청 → 삭제 실행.
- 구독 테스트: Sandbox 환경에서 SweepPic Plus 구매 가능 (별도 데모 계정 불필요).
- 구매 복원: 설정 > 구매 복원 탭으로 이전 구독 활성화 확인 가능.
- 광고: Google AdMob (배너/리워드/전면). Plus 구독 시 광고 제거.
- 모든 사진 분석(얼굴 인식, 유사사진, 품질 분석)은 기기 내에서만 수행됩니다.
```

---

## 영문 (App Store Connect 입력용)

```
[Why Full Photo Library Access is Required]
1. PHOTO ORGANIZATION: The core purpose is to help users sort their
   ENTIRE photo library. PHPicker only allows selecting individual
   photos, which defeats the purpose of library-wide organization.
2. SIMILAR PHOTO DETECTION: Similarity analysis needs to compare ALL
   photos in the library to find duplicates and similar groups.
3. GRID BROWSING: We provide a native-like grid where users scroll
   through their complete library, just like the built-in Photos app.

[How SweepPic Differs from Built-in Photos App]
- Swipe-to-delete: Swipe a thumbnail in the grid to instantly delete.
  No confirmation popup, fast cleanup. Accidentally deleted? Restore anytime.
- Face crop comparison: Automatically crops and enlarges faces from
  similar photos for side-by-side comparison. Compare facial expressions
  with enlarged faces, not tiny thumbnails.
- AI auto-cleanup: Automatically detects blurry/dark/bright photos.
  3-level sensitivity control. Favorites and portraits are auto-protected.
- Staging trash: Delete → staging trash → empty → iOS trash (30 days).
  Two-step safety net.

[Face Detection — On-Device Only]
- Uses Apple Vision Framework, 100% on-device processing
- No face data is transmitted, stored externally, or used for
  tracking/advertising/data mining
- Compliant with Guideline 5.1.2(vi)

[Testing Instructions]
- Grant full photo library access when prompted.
- Free features: Grid browsing, similar photo analysis, auto-cleanup,
  and moving to staging trash are unlimited and free.
- Daily permanent deletion limit: 10 (free). Unlimited for 3 days
  after fresh install (Grace Period).
- Gate test: Add 11+ photos to staging trash, tap "Empty" → gate sheet appears.
- Rewarded ad test: Gate sheet → "Watch ad to delete" → watch ad → deletion executes.
- Subscription test: SweepPic Plus available in Sandbox (no demo account needed).
- Restore purchases: Settings > Restore Purchases to verify prior subscription.
- Ads: Google AdMob (banner/rewarded/interstitial). Removed with Plus subscription.
- All photo analysis (face detection, similar photos, quality analysis)
  is performed entirely on-device.
```

---

## 참고

- 출처: `docs/bm/260227bm-spec.md` §14.6, `docs/appstore/260212AppStore-Gate3.md`
- 데모 계정: 불필요 (사진 라이브러리 권한만 허용하면 됨)
