# PickPhoto 앱스토어 심사 — 조사 내용 카테고리 분류

> 작성일: 2026-02-12
> 목적: 260211AppStore1.md의 조사 내용을 작업 도메인별로 분류하여 실행 계획의 기반으로 사용
> 원본 조사 문서: [260211AppStore1.md](260211AppStore1.md)

---

## 분류 기준

**왜 "작업 도메인별" 분류인가?**

- 각 도메인 = 독립적 작업 흐름 → 카테고리 단위로 실행 계획을 짤 수 있음
- 같은 도메인 안의 항목들은 서로 연관되어 한 번에 처리 가능
- 다른 도메인은 병렬 진행 가능 (예: A와 E를 동시에)
- 위험도/우선순위는 카테고리 내에서 표기

---

## A. 바이너리 안전성

> **핵심 질문: "빌드를 업로드할 수 있는가?"**
> 이 카테고리가 해결 안 되면 Xcode에서 Archive → Upload 단계에서 ITMS 오류로 차단됨

### A-1. 조사에서 발견된 문제

| # | 항목 | 현재 상태 | 위험도 | 근거 |
|---|------|----------|:------:|------|
| A1 | Private API 사용 | `SystemUIInspector.swift`가 KVC로 시스템 UI 접근. `#if DEBUG` 미래핑으로 릴리즈 빌드에 포함 | **치명** | Guideline 2.5.1 — 즉시 리젝 |
| A2 | Debug 파일 릴리즈 포함 | `LiquidGlassOptimizer.swift`, `AutoScrollTester.swift`, `SystemUIInspector.swift` 3개 파일이 `#if DEBUG` 없이 릴리즈에 포함 | **치명** | Guideline 2.5.1 |
| A3 | PrivacyInfo.xcprivacy 없음 | 프로젝트 전체에 파일 없음 | **차단** | ITMS-91053 오류로 업로드 차단 |
| A4 | SDK Privacy Manifest 없음 | BlurUIKit — 미확인 / LiquidGlassKit — 없음 | **차단** | ITMS-91061 오류 (2025.02.12~ 시행 중) |
| A5 | ITSAppUsesNonExemptEncryption 없음 | Info.plist에 키 없음 | 높음 | 매 제출마다 수동 답변 필요. 누락 시 지연 |
| A6 | 앱 아이콘 없음 | Contents.json만 존재, 실제 이미지 없음 | **차단** | ITMS-90717 — 알파 채널/형식 오류 시 업로드 차단 |
| A7 | 비 Debug 파일의 print문 | `FeatureFlags.swift`, `CleanupSessionStore.swift`, `ViewerViewController+SimilarPhoto.swift` | 중간 | 직접적 리젝 사유는 아니지만 코드 품질 |

### A-2. 필요한 조치 요약

- `#if DEBUG` 래핑 (A1, A2)
- PrivacyInfo.xcprivacy 생성 — Required Reason API: 파일 타임스탬프(`DDA9.1`), UserDefaults(`CA92.1`) (A3)
- SDK별 Privacy Manifest 확인/추가 (A4)
- Info.plist에 `ITSAppUsesNonExemptEncryption = false` 추가 (A5)
- 앱 아이콘 1024x1024 불투명 PNG 제작 (A6)
- print문 → `Log.print()` 또는 `#if DEBUG` 전환 (A7)

### A-3. 관련 참고 정보

- ITMS 오류 코드 대응표 → 원본 Section 16
- Required Reason API 5개 카테고리 상세 → 원본 Section 6-2
- 서드파티 라이브러리 현황 → 원본 Section 11-9

---

## B. 프라이버시 & 법률

> **핵심 질문: "프라이버시 심사를 통과하는가?"**
> 사진 앱은 프라이버시 심사가 특히 엄격함 — 전체 사진 접근 + 얼굴 인식이 있어서 집중 검토 대상

### B-1. 조사에서 발견된 문제

| # | 항목 | 현재 상태 | 위험도 | 근거 |
|---|------|----------|:------:|------|
| B1 | Privacy Policy 없음 | 앱 내/외부 모두 없음 | **차단** | Guideline 5.1.1 — 제출 시 URL 필수 |
| B2 | NSPhotoLibraryUsageDescription 한글 없음 | 영어만 존재 | 높음 | 한국 사용자 대상 시 한글 필수 |
| B3 | 전체 사진 접근 정당화 미비 | Review Notes에 사유 미기재 | 높음 | Guideline 5.1.1(iii) — "가능하면 PHPicker 사용" 명시 |
| B4 | 얼굴 데이터 사용 미명시 | Vision Framework 사용 중이나 Privacy Policy에 미기재 | 높음 | Guideline 5.1.2(vi) — 얼굴 데이터 마케팅/광고 사용 금지 |
| B5 | App Privacy Details 미작성 | App Store Connect 설문 미응답 | **차단** | 제출 시 필수 응답 |
| B6 | 한국 개인정보 처리방침 없음 | 2025.04 개정 지침 미준수 | 높음 | 한국 개인정보보호법 |

### B-2. 필요한 조치 요약

- Privacy Policy 작성 (한국법 8개 필수 항목 + Apple 요구사항) (B1, B6)
- Privacy Policy URL 호스팅 (GitHub Pages 등) (B1)
- 앱 내 Privacy Policy 링크 추가 (B1)
- NSPhotoLibraryUsageDescription 한글 Localization (B2)
- 전체 사진 접근 사유 정리 → Review Notes + Privacy Policy에 반영 (B3)
- 얼굴 데이터 온디바이스 전용 명시 → Privacy Policy에 반영 (B4)
- App Privacy Details 설문 응답 — "Data Not Collected" 선택 가능 (B5)

### B-3. 핵심 판단: "Data Not Collected" 전략

PickPhoto는 온디바이스 전용 앱이므로 Apple 기준 "Data Not Collected" 선택 가능:
- 데이터가 기기를 떠나지 않음 ✓
- 서버 전송 없음 ✓
- 제3자 공유 없음 ✓
- 분석/광고 SDK 없음 ✓
- 사용자 추적 없음 ✓

→ 가장 깔끔한 프라이버시 라벨. 단, Privacy Policy URL은 여전히 필수.

### B-4. 관련 참고 정보

- Privacy Manifest 파일 구조 → 원본 Section 6-1
- 데이터 최소화 원칙 상세 → 원본 Section 6-3
- 얼굴 데이터 제한 상세 → 원본 Section 6-4
- App Privacy Details 응답 가이드 → 원본 Section 14
- 한국 개인정보 처리방침 8개 필수 항목 → 원본 Section 8-4

---

## C. 앱 완성도

> **핵심 질문: "크래시 없이 모든 상황에서 동작하는가?"**
> 2024년 리젝 1위가 Performance (크래시, 미완성 기능). 사진 앱은 권한 상태가 다양해서 특히 주의 필요.

### C-1. 조사에서 발견된 문제

| # | 항목 | 현재 상태 | 위험도 | 근거 |
|---|------|----------|:------:|------|
| C1 | Limited Photo Access 미처리 | iOS 14+ `.limited` 상태에서 빈 화면/크래시 가능성 미확인 | 높음 | Guideline 2.1 — 앱 완성도 |
| C2 | 권한 거부 시 처리 | `.denied` / `.restricted` 상태에서의 동작 미확인 | 높음 | Guideline 2.1 |
| C3 | 사진 0장 빈 상태 | 사진 없는 라이브러리에서의 동작 미확인 | 중간 | Guideline 2.1 |
| C4 | 전체 흐름 크래시 안정성 | 체계적 테스트 미수행 | 높음 | Performance 리젝이 전체 1위 (1.2M건) |

### C-2. 필요한 조치 요약

- `.limited` 상태에서 정상 동작 확인 + 전체 접근 업그레이드 안내 UI (C1)
- `.denied` / `.restricted` 상태에서 적절한 안내 화면 (C2)
- 사진 0장 상태에서 빈 상태 뷰 표시 (C3)
- 주요 시나리오별 크래시 테스트 (C4)

### C-3. 테스트 시나리오 목록

```
1. 사진 접근 권한: 허용 → 전체 기능 동작
2. 사진 접근 권한: 제한 (.limited) → 선택된 사진만 표시 + 안내
3. 사진 접근 권한: 거부 → 안내 화면 + 설정 이동
4. 사진 0장 → 빈 상태 뷰
5. 스와이프 삭제 → Undo → 복구
6. 유사 사진 분석 → 결과 표시
7. 얼굴 인식 → 자동 줌
8. 그리드 ↔ 뷰어 전환
9. 앱 백그라운드 → 포그라운드 복귀
10. 메모리 부족 시나리오
```

---

## D. 심사 설득

> **핵심 질문: "심사원이 이 앱을 승인할 이유가 충분한가?"**
> 사진 앱 리젝 유형 1위가 "네이티브 앱 복제" (Guideline 4.1/4.2). 차별화를 적극 어필해야 함.

### D-1. 조사에서 발견된 문제

| # | 항목 | 현재 상태 | 위험도 | 근거 |
|---|------|----------|:------:|------|
| D1 | Review Notes 없음 | 미작성 | 높음 | 사진 접근 사유, Vision 설명 없이 제출하면 리젝 가능성 높음 |
| D2 | Guideline 4.2 방어 미준비 | "기본 사진 앱과 차별화 부족" 리젝에 대한 방어 논거 없음 | 높음 | 사진 앱 리젝 유형 1위 |
| D3 | 전체 사진 접근 정당화 | PHPicker 대신 전체 접근을 요구하는 이유를 심사원에게 설득해야 함 | 높음 | Guideline 5.1.1(iii) |

### D-2. 필요한 조치 요약

- Review Notes 작성 (전체 사진 접근 사유 3가지, Vision 온디바이스, 테스트 안내) (D1, D3)
- 앱 설명/키워드에서 "사진 정리 생산성 도구"로 포지셔닝 (D2)
- 스크린샷에서 차별화 기능(스와이프 삭제, 유사 사진) 시각적으로 강조 (D2)

### D-3. 차별화 논거

| PickPhoto 고유 기능 | 네이티브 사진 앱 | 경쟁 앱 사례 |
|-------------------|:--------------:|------------|
| 스와이프 삭제 (위로 밀어서 삭제) | X | Slidebox (4.8점, 수년간 운영) |
| Undo 기반 안전장치 (확인 다이얼로그 없음) | X | - |
| Vision 기반 유사 사진 그룹화 | 중복만 감지 | Gemini Photos (4.7점) |
| 자동 얼굴 확대 | X | - |

→ 스와이프 정리 + 유사 사진이 충분한 차별화 근거 (Slidebox/Gemini 선례)

### D-4. 관련 참고 정보

- Review Notes 템플릿 → 원본 Section 13-1
- Guideline 4.2 방어 전략 상세 → 원본 Section 15
- 사진 앱 리젝 유형 TOP 5 → 원본 Section 12-1

---

## E. 스토어 프레젠테이션

> **핵심 질문: "App Store Connect에 올릴 모든 자산이 준비됐는가?"**
> 아이콘, 스크린샷, 메타데이터 등 스토어에 보이는 모든 것

### E-1. 조사에서 발견된 문제

| # | 항목 | 현재 상태 | 위험도 | 근거 |
|---|------|----------|:------:|------|
| E1 | 앱 아이콘 | **없음** | **차단** | 1024x1024 불투명 PNG 필수 |
| E2 | 스크린샷 | **없음** | **차단** | iPhone 6.9" + iPad 13" 각 최소 1장 |
| E3 | 앱 이름/부제목 | 미정 | **차단** | 30자 제한 |
| E4 | 앱 설명 | 미작성 | **차단** | 4,000자, 순수 텍스트 |
| E5 | 키워드 | 미정 | **차단** | 100바이트, 쉼표 구분 |
| E6 | 지원 URL | 없음 | **차단** | 실제 연락처 포함 필수 |
| E7 | 카테고리 | 미선택 | **차단** | Photo & Video 권장 |
| E8 | LaunchScreen | 빈 흰색 화면 | 권장 | 앱 로고 추가 권장 (리젝 사유는 아님) |

### E-2. 필요한 조치 요약

- 앱 아이콘 디자인 (1024x1024, 불투명 PNG, sRGB/P3) (E1)
- 스크린샷 촬영 — iPhone 6.9" (1320x2868) + iPad 13" (2064x2752) (E2)
- 메타데이터 결정 — 이름, 부제목, 설명, 키워드 (E3~E5)
- 지원 URL 준비 (GitHub Pages 등) (E6)
- 카테고리 선택: Photo & Video (E7)
- LaunchScreen 브랜딩 (E8)

### E-3. 스크린샷 규격 정리

| 필수 | 해상도 | 대상 기기 |
|:----:|--------|----------|
| **O** | 1320 x 2868 (iPhone 6.9") | iPhone 17 Pro Max |
| **O** | 2064 x 2752 (iPad 13") | iPad Pro M4/M5 |
| 자동 축소 | 나머지 크기 | 상위 크기에서 자동 대응 |

---

## F. 규정 준수

> **핵심 질문: "Apple과 한국 법률 규정을 모두 충족하는가?"**
> 포털에서 입력/응답하는 규정 관련 항목들

### F-1. 조사에서 발견된 문제

| # | 항목 | 현재 상태 | 위험도 | 근거 |
|---|------|----------|:------:|------|
| F1 | 연령 등급 설문 | 미응답. **2026.01.31 마감 이미 경과** | **긴급** | 미응답 시 업데이트 제출 차단 |
| F2 | 한국 컴플라이언스 정보 | 미입력 (이메일, BRN) | 높음 | 미입력 시 한국 앱스토어 표시 차단 가능 |
| F3 | 심사 연락처 | 미설정 | **차단** | 이름/이메일/전화번호 필수 |
| F4 | 저작권 표시 | 미설정 | **차단** | "2026 회사명" 형식 |
| F5 | 수출 규정 응답 | Info.plist에 미설정 | 높음 | ITSAppUsesNonExemptEncryption = false |

### F-2. 필요한 조치 요약

- App Store Connect에서 연령 등급 새 양식 즉시 응답 (F1) — **가장 긴급**
- 한국 컴플라이언스: 이메일 + BRN 입력 (F2)
  - 경로: App Store Connect > 앱 > General > App Information > Compliance Information
- 심사 연락처 입력 (F3)
- 저작권 표시 설정 (F4)
- 수출 규정 — Info.plist에서 처리 (A5와 동일, A 카테고리와 겹침) (F5)

---

## 카테고리 간 의존성

```
A. 바이너리 안전성 ──┐
                     ├──→ 빌드 & 업로드 가능
B. 프라이버시 & 법률 ─┤
                     │
C. 앱 완성도 ────────┤
                     ├──→ 심사 제출 가능
D. 심사 설득 ────────┤
                     │
E. 스토어 프레젠테이션┤
                     │
F. 규정 준수 ────────┘
```

**의존 관계:**
- A → 업로드 전제조건 (A가 안 되면 나머지 의미 없음)
- B의 Privacy Policy URL → E의 메타데이터에서 참조
- D의 Review Notes → B의 전체 사진 접근 정당화 내용 활용
- E의 앱 아이콘 → A의 아이콘 형식 요구사항과 겹침 (디자인은 E, 기술 요건은 A)

**병렬 가능한 조합:**
- A(코드) + E(디자인) + F(포털) → 동시 진행 가능
- B(정책 문서) + C(테스트) → 동시 진행 가능
- D(심사 설득)는 B와 E 완료 후 최종 정리

---

## 참고 지식 (카테고리 횡단)

아래 내용은 별도 카테고리가 아니라, 위 A~F를 실행할 때 참조하는 배경 지식:

| 참고 항목 | 활용 시점 | 원본 위치 |
|----------|----------|----------|
| 사진 앱 리젝 유형 TOP 5 | D(심사 설득) 작성 시 | Section 12-1 |
| 리젝 통계 (2024) | 전체 우선순위 판단 시 | Section 12-3 |
| ITMS 오류 코드 대응표 | A(바이너리) 업로드 오류 시 | Section 16 |
| 심사 프로세스 가이드 | 제출 후 리젝 대응 시 | Section 17 |
| Review Notes 템플릿 | D(심사 설득) 작성 시 | Section 13-1 |
| App Privacy Details 응답 가이드 | B(프라이버시) 설문 시 | Section 14 |
| Guideline 4.2 방어 전략 | D(심사 설득) 리젝 방어 시 | Section 15 |
| 경쟁 앱 사례 | D(심사 설득) 차별화 시 | Section 15-2 |
