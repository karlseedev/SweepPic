# PIClear 비즈니스 인프라

> 작성일: 2026-02-27
> 관련 문서: `260227bm-spec.md` (BM 명세), `260227bm-spec-edit.md` (수정 항목 원본)
> 각 항목의 상태: ✅ 확정 | 📝 리서치 완료(반영 대기) | ⬜ 미작성

앱 출시 전 준비해야 하는 법적/행정 인프라를 정리한 문서.
코드 구현이 아닌, 비코드 준비물에 해당한다.

---

## 목차

| # | 항목 | 상태 |
|---|------|------|
| E1 | 개인정보 처리방침 | ✅ 확정 |
| E2 | 이용약관 | ✅ 확정 |
| E3 | 지원 URL / 웹페이지 | ✅ 확정 |
| E4 | 사업자 등록 + 통신판매업 신고 | ✅ 확정 |
| E5 | W-8BEN 세금 양식 | ✅ 확정 |
| E6 | 한국 사업자정보 앱 내 표시 | ✅ 확정 |
| E28 | DPIA 문서 작성 (얼굴 인식) | ⬜ 미작성 |
| — | IAP 상품 리뷰 제출 | ✅ 확정 |
| — | EU DSA Trader 상태 선언 | ✅ 확정 |

---

## 웹 호스팅 구조 (E1 + E2 + E3 통합)

```
karlseedev.github.io/pickphoto/
├── index.html    ← Support URL (E3)
├── privacy.html  ← Privacy Policy URL (E1)
└── terms.html    ← Terms of Use (E2)
```

---

## E1. 개인정보 처리방침 ✅

> 우선순위: 즉시 필요 (출시 전 필수)

**현황**: 앱은 개인정보를 직접 수집하지 않음. 사진 데이터·얼굴 감지 모두 기기 내 처리, 서버 전송 없음. 단, 제3자 SDK(AdMob)가 ATT 허용 시 IDFA를 수집하므로 처리방침 작성이 필요함.

**작성이 필요한 이유**:

| 요구처 | 요구 사항 |
|--------|----------|
| Apple | App Store Connect 제출 시 Privacy Policy URL 필수 + 앱 내 접근 가능 |
| Google AdMob | AdMob 사용 앱은 처리방침 필수 + 추적 고지 + 옵트아웃 링크 |
| 한국 개인정보보호법 | AdMob의 IDFA 수집이 "제3자 제공"에 해당 가능 → 작성 권장 |

**필수 섹션** (7개, 1~2페이지 분량):

| # | 섹션 | 핵심 내용 |
|---|------|----------|
| 1 | 개요 | 앱명, 개발자 정보 |
| 2 | 앱이 직접 수집하는 개인정보 | **"수집하지 않음"** — 사진 기기 내 처리, 얼굴 감지 기기 내, 결제는 Apple StoreKit 관리 |
| 3 | 제3자 서비스 | AdMob (수집 항목·옵트아웃), TelemetryDeck (익명), Supabase (익명) |
| 4 | 보유 및 파기 | 직접 보유 안 함, 제3자는 각 서비스 정책 따름 |
| 5 | 정보주체의 권리 | ATT 거부 방법, Google 광고 설정 링크 |
| 6 | 보호책임자 | 이름, 이메일 |
| 7 | 변경 고지 | 변경 시 앱 내/웹 공지 |

**제3자 SDK별 기재 사항**:

| SDK | 수집 항목 | 식별 가능 | 처리방침 링크 |
|-----|----------|----------|-------------|
| AdMob | IP, IDFA(ATT 허용 시), 광고 상호작용, 성능 데이터 | ATT 허용 시만 | policies.google.com/privacy |
| TelemetryDeck | 익명 식별자, 앱 이벤트, 기기 메타데이터 (IP 미수집) | 아니오 | telemetrydeck.com/privacy |
| Supabase | 익명 이벤트 로그 (이름·이메일·IDFA 미포함) | 아니오 | supabase.com/privacy |

**호스팅**: GitHub Pages (`karlseedev.github.io/pickphoto/privacy`)
**참고**: TelemetryDeck은 공식 처리방침 스니펫을 제공함 (telemetrydeck.com/privacy-policy-snippet)

---

## E2. 이용약관 ✅

> 우선순위: 즉시 필요 (출시 전 필수)

**현황**: 이용약관 없음. 구독 앱은 Apple 가이드라인 3.1.2에서 Terms of Use 링크를 필수로 요구함. 누락 시 리젝.

**링크 배치 (3곳 모두 필수)**:

| 위치 | 설명 |
|------|------|
| App Store 앱 설명 하단 | Terms URL 포함 |
| 앱 내부 (페이월 + 설정) | 탭 가능한 링크 |
| App Store Connect | License Agreement 등록 |

**분량**: A4 1~2페이지 (500~1,500단어)

**필수 섹션**:

| # | 섹션 | 핵심 내용 |
|---|------|----------|
| 1 | 서비스 개요 | 앱이 뭘 하는지, 기기 내 처리 명시 |
| 2 | 이용 조건/라이선스 | 사용 범위와 제한 |
| 3 | 구독 및 결제 | 자동갱신, 가격, 취소 방법 (설정 > Apple ID > 구독), 24시간 전 취소 |
| 4 | 환불 정책 | Apple 통해 처리 (reportaproblem.apple.com) |
| 5 | 광고 | AdMob 사용 고지, 개인정보 처리방침 참조 |
| 6 | 면책 조항 | 사진 삭제에 대한 책임 제한, "AS IS" 제공 |
| 7 | 약관 변경 고지 | 최소 7일 전 고지 (한국 약관규제법) |
| 8 | 준거법 | 대한민국 법률 적용 |
| 9 | 연락처 | 개발자 이메일 |

**개인정보 처리방침과는 별도 문서** — 한국법상 포괄 동의 금지 원칙
**호스팅**: GitHub Pages (`karlseedev.github.io/pickphoto/terms`)

---

## E3. 지원 URL / 웹페이지 ✅

> 우선순위: 즉시 필요 (출시 전 필수)

**현황**: 지원 웹페이지 없음. Apple App Store Connect 제출 시 Support URL 필수.

**Apple 필수 제출 URL**:

| URL 필드 | 필수 여부 | 용도 |
|---------|---------|------|
| Support URL | 필수 | 사용자 문의/지원 |
| Privacy Policy URL | 필수 | 개인정보 처리방침 (E1) |
| Marketing URL | 선택 | 앱 소개 (나중에 추가 가능) |

**Support URL 최소 요건** (누락 시 리젝):
- HTTPS 웹페이지 (소셜 미디어 프로필 불가, App Store 리다이렉트 불가)
- 앱 이름/아이콘 포함
- 연락처 (이메일) 최소 1개
- 모바일 반응형, 2초 이내 로드

**지원 페이지 필수 섹션**:

| # | 섹션 | 내용 |
|---|------|------|
| 1 | 앱 소개 | 앱 이름, 아이콘, 한줄 설명 |
| 2 | 연락처 | 이메일 (mailto 링크) |
| 3 | 구독 안내 | 취소 방법 (설정 > Apple ID > 구독), 앱 삭제해도 구독 미취소 안내, 환불은 reportaproblem.apple.com |
| 4 | FAQ | 3~5개 (사진 복구, 서버 미전송, 지원 iOS 버전 등) |
| 5 | 하단 링크 | 개인정보 처리방침(E1), 이용약관(E2) |

**한국법 대응**: App Store Connect에 사업자 정보를 입력하면 앱 페이지에 자동 노출되므로, 지원 페이지에는 이메일 정도면 충분

---

## E4. 사업자 등록 + 통신판매업 신고 ✅

> 우선순위: 즉시 필요 (출시 전 필수)

**현황**: 미등록 상태. 인앱 구독 + AdMob 수익이 있으므로 둘 다 필수.

### 필수 항목

| 항목 | 필수 여부 | 이유 |
|------|----------|------|
| 사업자등록 | **필수** | 수익 발생 시 의무. 2024.12부터 App Store에 사업자등록번호 표시 의무화 |
| 통신판매업 신고 | **필수** | 인앱 자동갱신 구독 = 전자상거래 해당 |
| 구매안전서비스 비적용 확인서 | **필수** | 디지털 상품이라 에스크로 비적용. 이 서류 누락 시 신고 반려 |

### 절차

```
1. 사업자등록 (홈택스, 즉일~1일)
   - 업종코드: 722000 (소프트웨어 개발) + 525101 (통신판매업)
   - 자택 사업장이면 임대차계약서 불필요
   - 비용: 무료
     ↓
2. 통신판매업 신고 (정부24, 3~6일)
   - 필요 서류: 사업자등록증 사본 + 구매안전서비스 비적용 확인서
   - 취급품목: "모바일 애플리케이션"
   - 비용: 등록면허세 약 40,500원 (매년 1월 갱신)
   - 팁: 12월에 신고하면 1월에 면허세 또 내야 함 → 연초 신고 권장
     ↓
3. App Store Connect 사업자 정보 입력
   - 비즈니스 > 계약 > 대한민국 법률 준수
   - 사업자등록번호, 연락처 이메일
```

### 미등록 시 리스크

| 항목 | 리스크 |
|------|--------|
| 사업자등록 미등록 | 매출의 1% 가산세, 매입세액 불공제 |
| 통신판매업 미신고 | 영업정지 15일+, 최고 500만 원 벌금 |

### 참고 링크

- [앱 개발자 통신판매업 신고 - idlebread](https://idlebread.com/%EC%95%B1-%EA%B0%9C%EB%B0%9C%EC%9E%90-%ED%86%B5%EC%8B%A0%ED%8C%90%EB%A7%A4%EC%97%85-%EC%8B%A0%EA%B3%A0%ED%95%98%EA%B8%B0/)
- [App Store 사업자등록번호 표시 - 와니스튜디오](https://waneestudio.com/1164/)

---

## E5. W-8BEN 세금 양식 ✅

> 우선순위: 미국/일본 스토어프론트에 출시할 경우 필수
> 근거: 미제출 시 미국 판매분 30% 원천징수

**적용 범위**: 한국만 출시하면 불필요. 미국 스토어프론트에서 매출이 발생하는 순간 필요.

| 국가 | 원천징수율 | 면제 방법 | 면제 후 |
|------|----------|----------|--------|
| 미국 | 30% | W-8BEN 제출 (한미 조약 Article 12) | **0%** |
| 일본 | 20% | 별도 우편 제출 (한일 조약) | **0%** |
| 그 외 대부분 | - | Apple이 대리 처리 또는 원천징수 없음 | 별도 조치 불필요 |

### 최단 경로 (당일 완료 가능)

EIN 없이 진행 가능:
```
ASC > Business > Tax Forms > W-8BEN 온라인 작성
- Line 5 (U.S. TIN): 공란
- Line 6a (Foreign TIN): 주민등록번호
- Tax Treaty: Article 12, 0% on royalties
→ 해당 월 또는 다음 달 정산부터 반영
```

### EIN이 필요한 경우 (주민번호 노출 회피)

| 방법 | 소요 시간 | 비용 |
|------|----------|------|
| IRS 전화 (001-1-267-941-1099) | 즉시 발급 | 국제전화비 3~5만원 |
| IRS 팩스 (304-707-9471) | ~4영업일 | 온라인 팩스 서비스 활용 가능 |
| 온라인 | **불가** (해외 거주자) | - |

### W-8BEN 작성 핵심

| 항목 | 기입 |
|------|------|
| Line 1 (Name) | 여권 영문명 (ASC 계정과 일치해야 함) |
| Line 2 (Country) | Republic of Korea |
| Line 6a (Foreign TIN) | 주민등록번호 (EIN 있으면 Line 5에 EIN) |
| Line 8 (DOB) | **MM-DD-YYYY** (미국식 날짜 주의) |
| Line 9 (Resident of) | Republic of Korea |
| Line 10 (Treaty) | Article 12, 0% on royalties |

**유효기간**: 서명일로부터 3년째 해 12/31까지. 이후 갱신 필요.

### 일본 면제 (별도)

- ASC에서 Japan Tax Forms → PDF 자동 생성 → **프린트 → 자필 서명 → 우편 발송**
- 전자서명/복사본/팩스 불가 (원본만 접수)
- 주소: Apple Inc., MS 198-2RA, 12545 Riata Vista Circle, Austin, TX 78727, USA
- 처리: 최대 90일

### 주의사항

- 이름은 여권 영문명, ASC 계정명과 **반드시 일치**
- 개인은 **W-8BEN** (W-8BEN-E는 법인용 — 혼동 주의)
- Tax Treaty 조항 미기재 시 30% 원천징수 그대로 적용
- 만료 시 자동으로 30% 원천징수 복원 → 갱신 잊지 말 것

### 참고 링크

- [개인개발자 소득세 면제 받기](https://cliearl.github.io/posts/ios/apple-appstore-tax-related/) — EIN~W-8BEN~일본 면제 전 과정 상세
- [W-8BEN-E 작성 + EIN 팩스 발급](https://jamesbbun.blogspot.com/2021/01/w-8ben-e-ein.html) — 팩스 신청 경험
- [앱스토어 개인개발자 세금관련](https://www.silphion.net/2853) — 미국/일본 원천징수 구조
- [W-8BEN 작성법 항목별 가이드](https://namsieon.com/6438)
- [W-8BEN 양식 작성법 2025](https://www.thewordcracker.com/blog/%EB%AF%B8%EA%B5%AD-%EC%84%B8%EA%B8%88-%EC%8B%A0%EA%B3%A0-w-8ben-%EC%96%91%EC%8B%9D-%EC%9E%91%EC%84%B1%EB%B2%95/)
- [해외 플랫폼 W-8BEN 작성 방법](https://simplep.net/how-to-write-a-w-8ben/)
- [Apple Developer - Provide Tax Information](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/)
- [IRS - Form SS-4 (EIN 신청)](https://www.irs.gov/pub/irs-pdf/fss4.pdf)

---

## E6. 한국 사업자정보 앱 내 표시 ✅

> 우선순위: 즉시 필요 (출시 전 필수)
> 근거: 전자상거래법 제10조 — 사이버몰(=인앱 결제가 있는 앱)에 사업자 정보 표시 의무

**ASC 입력만으로는 부족**: App Store Connect에 사업자 정보를 입력하면 앱 페이지에 자동 노출되지만, 이는 Apple 플랫폼 차원의 조치일 뿐, 개발자 본인의 사이버몰(=앱) 내 표시 의무를 대체하지 않음.

**구현 방법**: Phase 2 설정 화면(SettingsViewController)에 "사업자 정보" 섹션 추가

**표시 항목** (전자상거래법 제10조 + 시행규칙 제7조):

| 항목 | 예시 |
|------|------|
| 상호 | OOO |
| 대표자 | OOO |
| 사업자등록번호 | 000-00-00000 |
| 통신판매업 신고번호 | 제0000-서울OO-0000호 |
| 주소 | 서울시 OO구 OO로 00 |
| 전화 | 000-0000-0000 |
| 이메일 | support@example.com |

**모바일 완화 규정**: 한 화면에 다 못 넣어도 확인할 수 있는 링크(E3 지원 페이지 연결)만 있으면 충족.

**위반 시 과태료**: 1차 100만원, 2차 200만원, 3차 500만원 (마이리얼트립 2026.1 과태료 50만원 부과 사례 있음)

### 참고 링크

- [전자상거래법 - 국가법령정보센터](https://www.law.go.kr/lsInfoP.do?lsId=009318)
- [마이리얼트립 과태료 부과 - 한국경제](https://www.hankyung.com/article/202601064354g)
- [Apple ASC Korea Compliance](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-korea-compliance-information/)
- [인터넷쇼핑몰 사업자 표시 의무 - 생활법령정보](https://easylaw.go.kr/CSP/CnpClsMain.laf?popMenu=ov&csmSeq=25&ccfNo=3&cciNo=1&cnpClsNo=1)

---

## E7. 얼굴 인식 별도 동의 메커니즘 — 스킵

> 검토 결과: **불필요**

- PIClear는 얼굴 **감지(detection)**만 수행, **식별(identification)** 안 함
- 기기 내 처리, 서버 전송 없음, 감지 결과 미저장
- GDPR: 식별 목적이 아니면 생체 데이터 규제 대상 아님 (Recital 51)
- 한국 개인정보보호법: 민감정보(생체인식 특징정보) 해당 안 될 가능성 높음
- **대응**: 개인정보 처리방침(E1)에 얼굴 감지 기능 존재 + 기기 내 처리 사실을 투명성 차원에서 명시 (반영 완료)

---

## E28. DPIA 문서 작성 (얼굴 인식) ⬜

> 우선순위: 낮음 (성장 단계)
> 근거: GDPR — 얼굴 인식은 "대규모 생체 데이터 처리"에 해당 가능

TODO: 리서치 후 반영

---

## IAP 상품 리뷰 제출 ✅

> 우선순위: 즉시 필요 (출시 전 필수)

- App Store Connect에서 IAP 상품(월간/연간 구독) 등록 시, **앱 심사와 별도로 IAP 상품도 리뷰 제출 필요**
- 첫 제출 시 **페이월 화면 스크린샷** 첨부 필수 (사용자가 구매 전 보는 화면)
- IAP 상품이 "Ready to Submit" 상태여야 앱 제출 시 함께 심사됨
- 가격 변경/설명 수정 시에도 재리뷰 필요

---

## EU DSA Trader 상태 선언 ✅

> 우선순위: EU 스토어프론트 출시 시 필수
> 근거: EU Digital Services Act (DSA) — 유료 앱 또는 IAP가 있는 앱은 Trader 등록 의무

**무엇인가**: EU는 2024년부터 App Store에서 유료 콘텐츠를 판매하는 개발자를 "Trader"로 분류. Trader는 사업자 정보를 공개해야 하며, 미등록 시 EU App Store에서 앱이 **제거**됨.

**등록 절차**:
1. App Store Connect > 비즈니스 > EU DSA 준수 정보
2. Trader 상태 선택 ("I am a trader")
3. 사업자 정보 입력: 상호, 주소, 등록번호, 연락처
4. 저장 → EU 앱 페이지에 사업자 정보 자동 노출

**대상 판단**:

| 조건 | Trader 여부 |
|------|-----------|
| 무료 앱 + 광고 없음 + IAP 없음 | 해당 없음 |
| 무료 앱 + AdMob 광고 | 해당 가능성 있음 (수익 활동) |
| **IAP 구독 있음 (PIClear 해당)** | **Trader 필수** |

**PIClear 대응**: 한국에서 먼저 출시하더라도, 글로벌(EU 포함) 확장 시 반드시 Trader 등록 선행. 사업자등록(E4) 완료 후 동일 정보로 입력 가능.

**참고**: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/

---

## 세금 관련 (E4 리서치에서 확인된 사항)

E4 리서치 과정에서 확인된 세금 관련 내용을 별도 정리.

### 부가가치세

- Apple이 **대리 납부하지 않음** → 직접 신고/납부 (연 2회: 1월, 7월)
- 매출 = **플랫폼 수수료 차감 전** 소비자 결제 총액
- 해외 매출은 영세율(0%) 적용
- 2025.2부터 Apple이 수수료에 대한 매입 전자세금계산서 발급 → 매입세액 공제 가능

### 종합소득세

- 연 1회 (5월), 사업소득 - 필요경비 = 과세 소득
- 필요경비: Apple 수수료, Developer 연회비, 장비, 서버 비용 등

### W-8BEN (E5 선행 정보)

- 미국 판매분 30% 원천징수 → 한미 이중과세방지협약으로 **0% 면제 가능**
- 절차: EIN 발급 (IRS 팩스/전화) → App Store Connect에서 W-8BEN 온라인 제출
- 일본도 20% 원천징수 있으나 한일 협약으로 면제 가능 (우편 신청, 처리 ~90일)

### 참고 링크

- [앱스토어 개발자 세금 가이드 - I_Jemin](https://ijemin.com/blog/%EC%95%B1%EC%8A%A4%ED%86%A0%EC%96%B4-%EA%B0%9C%EB%B0%9C%EC%9E%90-%EC%84%B8%EA%B8%88-%EA%B0%80%EC%9D%B4%EB%93%9C-%EB%B6%80%EA%B0%80%EC%84%B8-1/)
- [개인개발자 소득세 면제 받기](https://cliearl.github.io/posts/ios/apple-appstore-tax-related/)
- [앱 수익 세금 신고 - Creative Partners](https://blog.creativepartners.co.kr/69dc8cae-465b-4d87-ac37-121160d5d978)
