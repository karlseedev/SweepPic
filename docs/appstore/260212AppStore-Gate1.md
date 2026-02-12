# PickPhoto 앱스토어 심사 — 분류 체계

> 작성일: 2026-02-12
> 분류 기준: 심사 관문(Gate) × 작업 유형
> 원본 조사 문서: [260211AppStore1.md](260211AppStore1.md)

---

## 분류 체계

**1차 분류 (대분류)**: 심사 관문 — "이것 없으면 어디서 막히는가?"
**2차 분류 (소분류)**: 작업 유형 — "주요 결과물이 무엇인가?"

---

### 1. 업로드 차단 — 바이너리가 Apple 서버에 올라가지 않음 (ITMS 자동 검증)

1) **코드/설정** — 프로젝트 파일 변경
   - PrivacyInfo.xcprivacy 생성 (Required Reason API: 파일 타임스탬프 `DDA9.1`, UserDefaults `CA92.1`)
   - SDK Privacy Manifest 확인/추가 (BlurUIKit, LiquidGlassKit)
   - ITSAppUsesNonExemptEncryption = false (Info.plist)

2) **에셋** — 이미지 파일 제작
   - 앱 아이콘 1024x1024 불투명 PNG (sRGB/P3, 알파 채널 없음)

### 2. 제출 차단 — Submit for Review 버튼을 누를 수 없음 (ASC 필수 필드)

1) **에셋** — 이미지 파일 제작
   - 스크린샷: iPhone 6.9" (1320x2868) + iPad 13" (2064x2752) 각 1~10장

2) **문서** — 외부 호스팅 웹 문서
   - Privacy Policy 작성 (Apple 요구 + 한국 개인정보보호법 8개 필수 항목)
   - Privacy Policy URL 호스팅 (GitHub Pages 등)
   - 지원 페이지 (Support URL)

3) **포털 입력** — App Store Connect에서 입력
   - 앱 메타데이터 (이름, 부제목, 설명, 키워드, 카테고리, 저작권)
   - 연령 등급 설문 응답 (**긴급** — 2026.01.31 마감 이미 경과)
   - 심사 연락처 (이름/이메일/전화번호)
   - App Privacy Details 설문 ("Data Not Collected" 선택 가능)
   - 한국 컴플라이언스 정보 (이메일, BRN)
   - 수출 규정 응답

### 3. 심사 차단 — 심사원이 리젝함 (Guideline 위반)

1) **코드/설정** — 프로젝트 파일 변경
   - `#if DEBUG` 래핑: SystemUIInspector.swift (Private API/KVC), AutoScrollTester.swift, LiquidGlassOptimizer.swift
   - print문 정리: FeatureFlags.swift, CleanupSessionStore.swift, ViewerViewController+SimilarPhoto.swift
   - Limited Photo Access UI (.limited 상태에서 정상 동작 + 업그레이드 안내)
   - NSPhotoLibraryUsageDescription 한글 Localization

2) **포털 입력** — App Store Connect에서 입력
   - Review Notes 작성 (전체 사진 접근 정당화 3가지 사유, Vision 온디바이스 명시, 테스트 안내, 4.2 차별화)

3) **검증** — 실기기/시뮬레이터 테스트
   - 크래시 안정성 (전체 흐름)
   - 권한 상태별 동작 (허용 / 제한 / 거부)
   - 빈 상태 처리 (사진 0장)

### 4. 품질 개선 — 통과와 무관하지만 앱 퀄리티 향상

1) **코드/설정** — 프로젝트 파일 변경
   - VoiceOver 전체 UI 확대
   - Dynamic Type (UIFontMetrics)
   - Localization 파일 분리 (한/영 .strings)

2) **에셋** — 이미지 파일 제작
   - LaunchScreen 브랜딩 (앱 로고 추가)

---
