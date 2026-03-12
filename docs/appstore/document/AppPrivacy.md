# SweepPic App Privacy Details 설문 답변 가이드

> App Store Connect → App Privacy 에서 그대로 입력하면 됩니다

---

## 1단계: 데이터 수집 여부

| 질문 | 답변 |
|------|------|
| Do you or your third-party partners collect data from this app? | **Yes** |

**수집 주체:**

| SDK / 서비스 | 역할 | 수집 데이터 |
|-------------|------|-----------|
| Google AdMob (v11.x) | 광고 표시 | 기기 ID(IDFA), 대략적 위치(IP), 광고 상호작용 |
| TelemetryDeck (v2.11) | 익명 분석 | 사용 이벤트, IDFV(이중 해싱) |
| Supabase (자체 서버) | 자체 분석 | 사용 이벤트, IDFV, 기기 정보 |
| StoreKit 2 (Apple) | 인앱 구매 | 구매/구독 내역 |

---

## 2단계: 수집하는 데이터 유형 선택

### 수집하는 항목 (체크)

| 카테고리 | 데이터 유형 | 선택 |
|---------|-----------|:----:|
| Location | **Coarse Location** (대략적 위치) | ✅ |
| Identifiers | **Device ID** (기기 ID) | ✅ |
| Purchases | **Purchase History** (구매 내역) | ✅ |
| Usage Data | **Product Interaction** (제품 상호작용) | ✅ |
| Usage Data | **Advertising Data** (광고 데이터) | ✅ |
| Diagnostics | **Other Diagnostic Data** (기타 진단) | ✅ |

### 수집하지 않는 항목

| 카테고리 | 이유 |
|---------|------|
| Contact Info | 계정 시스템 없음 |
| Health & Fitness | 해당 없음 |
| Financial Info | 결제는 Apple이 처리 |
| Precise Location | GPS 사용 안 함 |
| Sensitive Info | 해당 없음 |
| Contacts | 연락처 접근 안 함 |
| **Photos or Videos** | **사진은 기기 내에서만 처리, 외부 전송 없음** |
| **Face Data** | **얼굴 인식은 기기 내 Vision Framework, 외부 전송 없음** |
| Browsing History | 웹 브라우저 없음 |
| Search History | 검색 기능 없음 |
| User ID | 계정/로그인 없음 |
| Crash Data | Crashlytics 미사용 |
| Performance Data | 성능 모니터링 SDK 미사용 |

---

## 3단계: 각 데이터 유형별 상세 답변

### ① Coarse Location (대략적 위치)

| 질문 | 답변 |
|------|------|
| 수집 주체 | Google AdMob (IP 기반 위치 추론) |
| 용도 | **Third-Party Advertising** |
| Linked to User's Identity? | **No** |
| Used for Tracking? | **No** |

### ② Device ID (기기 ID)

| 질문 | 답변 |
|------|------|
| 수집 주체 | AdMob (IDFA), TelemetryDeck (IDFV 해싱), Supabase (IDFV) |
| 용도 | **Third-Party Advertising** + **Analytics** |
| Linked to User's Identity? | **No** |
| Used for Tracking? | **Yes** (IDFA, ATT 허용 시) |

### ③ Purchase History (구매 내역)

| 질문 | 답변 |
|------|------|
| 수집 주체 | StoreKit 2 (Apple) |
| 용도 | **App Functionality** (구독 상태 확인) |
| Linked to User's Identity? | **No** |
| Used for Tracking? | **No** |

### ④ Product Interaction (제품 상호작용)

| 질문 | 답변 |
|------|------|
| 수집 주체 | TelemetryDeck, Supabase, AdMob |
| 용도 | **Analytics** + **Third-Party Advertising** |
| Linked to User's Identity? | **No** |
| Used for Tracking? | **No** |

> 수집 이벤트: 게이트 노출, 광고 시청, 삭제 횟수, 구독 전환 등
> 모두 익명 — IDFV 기반, 이름/이메일 연결 없음

### ⑤ Advertising Data (광고 데이터)

| 질문 | 답변 |
|------|------|
| 수집 주체 | Google AdMob |
| 용도 | **Third-Party Advertising** |
| Linked to User's Identity? | **No** |
| Used for Tracking? | **No** |

> 광고 노출 수, 클릭 수 등 AdMob이 자체 수집

### ⑥ Other Diagnostic Data (기타 진단 데이터)

| 질문 | 답변 |
|------|------|
| 수집 주체 | Supabase |
| 용도 | **Analytics** |
| Linked to User's Identity? | **No** |
| Used for Tracking? | **No** |

> 기기 모델(iPhone16,1), OS 버전, 앱 버전, 사진 규모 구간

---

## 최종 영양 라벨 (Nutrition Label) 예상 결과

### "Data Used to Track You"
- Device ID

> ATT 팝업에서 "허용" 시에만 추적 (IDFA). 거부 시 추적 데이터 없음

### "Data Not Linked to You"
- Coarse Location
- Purchase History
- Product Interaction
- Advertising Data
- Other Diagnostic Data

> 모든 분석 데이터는 익명 수집 (계정 없음, IDFV 기반)

### "Data Not Collected"
- Photos or Videos
- Face Data
- Contact Info
- 기타 미수집 항목 전체

---

## 참고사항

- **ATT 거부 시**: AdMob은 contextual 광고만 표시, IDFA 미수집 → Tracking 데이터 없음
- **Plus 구독자**: 광고 미표시, AdMob SDK 비활성 → 광고 관련 데이터 수집 감소
- **Grace Period 중**: 광고 미표시 (첫 3일)
- **옵트아웃**: TelemetryDeck 분석 옵트아웃 지원 (UserDefaults)
- **데이터 보관**: Supabase 365일 후 자동 파기 (pg_cron)

---

## 출처

- `docs/bm/260227bm-spec.md` §14.3, §14.4
- `docs/appstore/document/Privacy.md` (개인정보 처리방침)
- 실제 코드: `AnalyticsService.swift`, `SupabaseProvider.swift`, `AdManager.swift`, `ATTStateManager.swift`
