# Gate 2. 제출 차단

> Submit for Review 버튼을 누를 수 없음 (ASC 필수 필드 미입력)
> Gate 1 해결 후 업로드는 됐지만, 필수 정보가 비어있어 심사 요청 불가

---

### 분류 요약

```
2. 제출 차단
   1) 에셋: 스크린샷
   2) 문서: Privacy Policy, 지원 페이지
   3) 포털 입력: 메타데이터, 연령등급, 연락처, Privacy Details, 한국 규정, 수출규정
```

---

## 1) 에셋 — 이미지 파일 제작

### 스크린샷

> 현재 상태: 없음 → 제출 불가

**iPhone (6.9" 또는 6.5" 중 하나 필수):**

| 화면 크기 | 해상도 (세로) | 필수 여부 | 대상 기기 |
|-----------|-------------|:---------:|----------|
| **6.9"** | 1320 x 2868 | 둘 중 하나 | iPhone 17 Pro Max, iPhone 16 Pro Max |
| **6.7"** | 1290 x 2796 | 선택 (6.9" 또는 6.5" 필수) | iPhone 15 Pro Max, 16 Plus |
| **6.5"** | 1284 x 2778 | 둘 중 하나 | iPhone 14 Pro Max |
| 6.3" | 1179 x 2556 | 자동 축소 | iPhone 17 Pro, 15 Pro |
| 6.1" | 1170 x 2532 | 자동 축소 | iPhone 14 |
| 6.3" (Air) | 1218 x 2640 | 자동 축소 | iPhone Air |
| 5.5" | 1242 x 2208 | 자동 축소 | iPhone 8 Plus |

> 2026년 기준: iPhone 17 시리즈, iPhone Air 추가. 6.9" 스크린샷(1320x2868)이 최신 Pro Max에 대응.

**iPad (TARGETED_DEVICE_FAMILY=1,2이므로 iPad도 필수):**

| 화면 크기 | 해상도 (세로) | 대상 기기 |
|-----------|-------------|----------|
| **13"** | 2064 x 2752 | iPad Pro M4/M5, iPad Air 13" |

**공통 사양:**
- 형식: JPEG, PNG
- 수량: 기기당 1~10장
- 미제공 크기는 상위 크기에서 자동 축소
- **실제 앱 사용 화면 표시 필수** (Guideline 2.3.3)

---

## 2) 문서 — 외부 호스팅 웹 문서

### Privacy Policy (프라이버시 정책)

> 현재 상태: 앱 내/외부 모두 없음 → 제출 불가 (Guideline 5.1.1)

**게재 위치 (2곳 모두 필수):**

| 위치 | 설명 |
|------|------|
| App Store Connect | 메타데이터에 URL 입력 |
| 앱 내부 | 사용자가 접근 가능한 곳 (설정 화면 등) |

**호스팅:** 공개 URL 필수 (GitHub Pages, Notion 등 활용 가능)

**Apple 요구 포함 내용:**

| 항목 |
|------|
| 수집 데이터 종류 |
| 수집 방법 |
| 사용 목적 |
| 서드파티 공유 여부 |
| 보관 기간 |
| 삭제 방법 |
| 사용자 권리 |

**한국 개인정보보호법 추가 필수 항목 (2025.04 개정 지침):**

| # | 항목 |
|---|------|
| 1 | 수집하는 개인정보 항목 및 수집 방법 |
| 2 | 개인정보 처리 목적 |
| 3 | 개인정보 보유 및 이용 기간 |
| 4 | 개인정보 제3자 제공 사항 |
| 5 | 정보주체의 권리 (열람/정정/삭제/처리정지) |
| 6 | 개인정보 보호책임자 정보 |
| 7 | 행태정보 수집/이용/제공 및 거부 안내 |
| 8 | 모바일 앱에서 쉽게 확인 가능한 위치에 공개 |

**PickPhoto 특이사항:**
- 온디바이스 전용 앱 → 외부 데이터 전송 없음
- Vision Framework 얼굴 인식 결과도 기기 밖으로 전송하지 않음
- Privacy Policy에 "얼굴 데이터는 온디바이스에서만 처리되며, 마케팅/광고/데이터마이닝에 사용하지 않음" 명시 필요 (Guideline 5.1.2(vi))

**얼굴 인식 고지 문구 예시 (처리방침 포함):**

```
"얼굴 인식 기술은 사진 내 얼굴을 자동으로 감지하고 확대하는 데 사용됩니다.
 감지된 얼굴 데이터는 기기 내에서만 처리되며, 저장되거나 외부로 전송되지 않습니다."
```

> 출처: MenuResearch §8-5 — 얼굴 인식 고지 문구

### 지원 페이지 (Support URL)

> 현재 상태: 없음 → 제출 불가

| 항목 | 요구사항 |
|------|---------|
| URL | 공개 접근 가능한 페이지 |
| 내용 | **실제 연락처 포함 필수** (이메일 등) |
| 용도 | 사용자 지원 + Guideline 1.5 (Developer Information) 충족 |

> Privacy Policy와 같은 사이트에 호스팅 가능 (예: GitHub Pages)

---

## 3) 포털 입력 — App Store Connect에서 입력

### 앱 메타데이터

> 현재 상태: 미설정 → 제출 불가

**앱 정보 (App Information):**

| 항목 | 필수 | 현지화 | 제한 | 비고 |
|------|:----:|:------:|------|------|
| **Name (앱 이름)** | O | O | 30자 | - |
| **Bundle ID** | O | - | 변경 불가 | com.karl.PickPhoto (설정 완료) |
| **SKU** | O | - | 변경 불가 | - |
| **Primary Language** | O | - | - | 한국어 |
| **Primary Category** | O | - | - | **Photo & Video** 권장 |
| **Content Rights** | O | - | - | 제3자 콘텐츠 사용 여부 |
| Subtitle (부제목) | - | O | 30자 | - |

**플랫폼 버전 정보:**

| 항목 | 필수 | 현지화 | 제한 |
|------|:----:|:------:|------|
| **Description** | O | O | 4,000자, 순수 텍스트 |
| **Keywords** | O | O | 100바이트, 쉼표 구분 |
| **Support URL** | O | O | 실제 연락처 포함 필수 |
| **Copyright** | O | - | "2026 회사명" 형식 |
| **Version Number** | O | - | 1.0 (설정 완료) |
| Promotional Text | - | O | 170자, 심사 없이 수정 가능 |

### 연령 등급 설문

> **긴급: 2026.01.31 마감 이미 경과 — 미응답 시 업데이트 제출 차단**

**설문 카테고리:**

| # | 카테고리 | 항목 예시 |
|---|---------|----------|
| 1 | 인앱 컨트롤 | 보호자 통제, 연령 확인 |
| 2 | 기능 | 웹 접근, UGC, 메시징, 광고 |
| 3 | 성숙한 주제 | 비속어, 공포, 약물 |
| 4 | 의료/웰니스 | 의료 정보, 건강 주제 |
| 5 | 성적 표현/누드 | 암시적 주제, 성적 콘텐츠 |
| 6 | 폭력 | 만화/사실적 폭력, 무기 |
| 7 | 확률 기반 활동 | 도박, 루트박스 |

**결과 등급:** 4+ / 9+ / 13+ / 16+ / 18+
**한국 전용:** 전체이용가 / 12+ / 15+ / 19+

> PickPhoto는 사진 정리 앱이므로 대부분 "없음"으로 응답 → **4+ (전체이용가)** 예상

### 심사 연락처 (App Review Information)

> 현재 상태: 미설정 → 제출 불가

| 항목 | 필수 |
|------|:----:|
| **이름** | O |
| **이메일** | O |
| **전화번호** | O |

### App Privacy Details 설문

> 현재 상태: 미작성 → 제출 불가

**PickPhoto 응답 전략:**

| 질문 | PickPhoto 답변 | 근거 |
|------|---------------|------|
| "Do you or your third-party partners collect data from this app?" | **No** | 모든 처리가 온디바이스. 외부 전송 없음 |
| Photos/Videos 데이터 수집? | (위에서 No 선택 시 이 질문 표시 안됨) | - |
| 추적(Tracking)? | **No** | ATT/IDFA 미사용, 광고 없음 |

**App Privacy Nutrition Label 선언 항목 (PickPhoto 기준):**

| 데이터 타입 | 수집 여부 | 추적 여부 | 비고 |
|-----------|---------|---------|------|
| Photos or Videos | NO (처리만) | NO | 외부 전송 없음 |
| Precise Location (사진 GPS) | 조건부 | NO | PHAsset.location 사용 시 |
| Usage Data | YES | NO | 분석용 |
| Crash Data | YES | NO | 진단용 |
| Face Data | NO (기기 내) | NO | 외부 전송 없음 |

> 출처: MenuResearch §6 — App Privacy Nutrition Label

**"Data Not Collected" 선택 조건 — 모두 충족:**

| 조건 | PickPhoto 충족 |
|------|:-------------:|
| 데이터가 기기를 떠나지 않음 | O |
| 서버로 전송하지 않음 | O |
| 제3자와 공유하지 않음 | O |
| 분석/광고 SDK 미사용 | O |
| 사용자 추적 안 함 | O |

> **결론**: "Data Not Collected" 선택 가능 → 가장 깔끔한 프라이버시 라벨

**주의사항:**
- Privacy Policy URL은 "Data Not Collected"와 무관하게 **항상 필수**
- 향후 분석 SDK(Firebase 등) 추가 시 응답 변경 필수
- 허위 응답 적발 시 리젝 + 개발자 계정 경고

**전체 데이터 타입 참고 (15개 카테고리):**

| # | 카테고리 | 데이터 타입 |
|---|---------|-----------|
| 1 | 연락처 정보 | 이름, 이메일, 전화번호, 실제 주소, 기타 |
| 2 | 건강 및 피트니스 | 건강, 피트니스 |
| 3 | 금융 정보 | 결제, 신용, 기타 금융 |
| 4 | 위치 | 정밀 위치, 대략적 위치 |
| 5 | 민감 정보 | 민감 정보 |
| 6 | 연락처 | 연락처 |
| 7 | **사용자 콘텐츠** | 이메일/문자, **사진/동영상**, 오디오, 게임플레이, 고객 지원, 기타 |
| 8 | 검색 기록 | 브라우징, 검색 |
| 9 | 식별자 | 사용자 ID, 기기 ID |
| 10 | 구매 | 구매 기록 |
| 11 | 사용 데이터 | 제품 상호작용, 광고, 기타 |
| 12 | 진단 | 크래시, 성능, 기타 |
| 13 | 주변 환경 | 환경 스캐닝 |
| 14 | 신체 | 손, 머리 |
| 15 | 기타 | 기타 데이터 |

### 한국 컴플라이언스 정보

> 현재 상태: 미입력 → 한국 앱스토어 표시 차단 가능

**입력 경로:**
```
App Store Connect > 앱 선택 > General > App Information >
  "Compliance Information" 또는 "Korean Law" 섹션
  → 이메일, 사업자등록번호(BRN) 입력
```

| 항목 | 개인 (Individual) | 조직 (Organization) |
|------|:-----------------:|:-------------------:|
| 이메일 | **필수** | **필수** |
| 전화번호 | - | **필수** |
| 사업자등록번호 (BRN) | **필수** | **필수** |
| 회사명 | - | **필수** |

> **한국 컴플라이언스**: 한국 기반 계정은 Individual/Organization 모두 전자상거래소비자보호법에 따른 식별 정보 제공 대상.

**추가 한국 규정:**
- **공정위 다크패턴 규제** (2025년 강화): 기만적/조작적 UI 패턴 금지. 위반 시 500만원 과태료
- 통신판매업 신고: 현재 PickPhoto는 무료 앱이므로 해당 없음. 향후 유료화 시 확인 필요
- **자동화된 의사결정 고지** (2025년 개정): AutoCleanup AI 기능 등 자동화된 의사결정이 있을 경우 사용자에게 고지 필요
- **생체정보 처리 명시** (제23조): 얼굴 인식 기기 내 처리 기술에 대한 명시 필요

**GDPR 필수 항목 (EU 출시 시):**

| 항목 | 필수 여부 |
|------|----------|
| 처리 목적 및 법적 근거 | 필수 |
| 동의 기반 분석 데이터 수집 | 필수 |
| 동의 철회(옵트아웃) | 필수 |
| 데이터 접근/삭제 요청 수단 | 필수 |

> 출처: MenuResearch §8-3 — GDPR 요구사항

### 수출 규정 응답 + ITSAppUsesNonExemptEncryption

> Info.plist에 키 미설정 → 제출 과정에서 매번 수동 답변 필요
> ASC 제출 시에도 수출 규정 질문에 답해야 함

| 항목 | 요구사항 |
|------|---------|
| Info.plist 키 | `ITSAppUsesNonExemptEncryption = false` 추가 (코드/설정 작업) |
| HTTPS/URLSession 사용 | OS 내장 암호화 → 면제 |
| 독점 암호화 알고리즘 | 미사용 → 면제 |
| ASC 응답 | "No" (비면제 암호화 미사용) |

### 가격 및 배포

> 현재 상태: 미설정 → 제출 불가

| 항목 | 필수 | 비고 |
|------|:----:|------|
| **Availability (배포 국가)** | O | 한국 선택 |
| **Price (가격)** | O | 무료 |
| **Tax Category** | O | App Store Connect에서 선택 |

### 콘텐츠 권리 (Content Rights)

| 항목 | 설명 |
|------|------|
| 제3자 콘텐츠 사용 여부 | PickPhoto는 사용자 사진만 표시 → "Does not contain, show, or access third-party content" |

---

## Gate 2 체크리스트

### 제출 차단 체크

- [ ] 스크린샷이 실제 앱 화면으로 준비되었는가? (iPhone 6.9" + iPad 13")
- [ ] Privacy Policy 문서가 작성되어 공개 URL에 호스팅되었는가?
- [ ] Privacy Policy URL이 접근 가능한가?
- [ ] 지원 페이지(Support URL)가 준비되었는가?
- [ ] 앱 메타데이터가 모두 입력되었는가? (이름, 설명, 키워드, 카테고리, 저작권)
- [ ] 연령 등급 설문이 완료되었는가?
- [ ] 심사 연락처가 입력되었는가? (이름/이메일/전화번호)
- [ ] App Privacy Details 설문이 응답되었는가?
- [ ] 한국 컴플라이언스 정보가 입력되었는가? (이메일, BRN)
- [ ] 가격 및 배포 (Availability, Price, Tax Category)가 설정되었는가?
- [ ] ITSAppUsesNonExemptEncryption이 Info.plist에 추가되었는가?
- [ ] 수출 규정 응답이 완료되었는가?

### 한국법 필수 체크 (개인정보보호법)

- [ ] 개인정보 처리방침 앱 내 공개 (제30조)
- [ ] 분석 데이터 옵트아웃 토글 (제37조)
- [ ] 제3자 제공 명시 — TelemetryDeck, Supabase (제30조)
- [ ] 보호책임자 연락처 기재 (제30조)
- [ ] 얼굴 인식 기기 내 처리 명시 (제23조)

> 출처: MenuResearch §12 — 법적 필수 체크리스트

---

## 참고 문서

| 문서 | URL |
|------|-----|
| 필수 속성 목록 | https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties |
| 스크린샷 사양 | https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications |
| App Privacy Details | https://developer.apple.com/app-store/app-privacy-details/ |
| 연령 등급 | https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions |
| 한국 규정 정보 | https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-korea-compliance-information/ |
| 한국 개인정보 처리방침 지침 (2025.04) | https://www.privacy.go.kr/front/bbs/bbsView.do?bbsNo=BBSMSTR_000000000049&bbscttNo=20806 |
