# App Store 제출 체크리스트

---

## Gate 1: 빌드 업로드 전

- [ ] 앱 아이콘 (1024x1024)
- [ ] 번들 ID 변경 (com.karl.SweepPic)
- [x] Info.plist 키 확인 (NSPhotoLibraryUsageDescription, GADApplicationIdentifier 등)
- [x] ITSAppUsesNonExemptEncryption = false
- [x] maxAdContentRating = .general (AdManager.swift)

## Gate 2: App Store Connect 입력

### 문서 준비 완료 (가이드 보고 입력만 하면 됨)

- [ ] 메타데이터 입력 (이름/부제/설명/키워드) → `Metadata.md`
- [ ] 연령 등급 설문 → `AgeRating.md`
- [ ] App Privacy Details 설문 → `AppPrivacy.md`
- [ ] 심사 메모 (Review Notes) → `ReviewNotes.md`
- [ ] 가격/배포/콘텐츠 권리 설정 → `PriceDistribution.md`
- [ ] 수출 규정 응답 → "No"

### 이미 호스팅 완료

- [x] Privacy Policy → privacy.html (GitHub Pages)
- [x] 이용약관 → terms.html (GitHub Pages)
- [x] 지원 페이지 → index.html (GitHub Pages)

### 별도 작업 필요

- [ ] 스크린샷 (iPhone 6.9" + iPad 13") — 앱 완성 후
- [ ] 심사 연락처 입력 (이름/이메일/전화번호)
- [ ] 한국 컴플라이언스 (이메일 + BRN) → 사업자등록 후 → `KoreaCompliance.md`
- [ ] 인앱 구독 상품 등록 (pro_monthly, pro_yearly)

## Gate 3: 심사 리젝 방지

### 코드/설정

- [x] #if DEBUG 래핑 (SystemUIInspector, AutoScrollTester)
- [x] NSPhotoLibraryUsageDescription 한글 Localization (ko.lproj)
- [x] Limited Access / 거부 / 0장 상태 UI 처리
- [x] VoiceOver — 뷰어 삭제 버튼 + 선택 모드로 대체 경로 확보
- [ ] VoiceOver — accessibilityCustomActions (출시 후 개선)
- [ ] Reduce Motion 대응 (출시 후 개선)

### Review Notes 보강

- [x] 전체 사진 접근 사유 (영문) → `ReviewNotes.md`
- [x] Guideline 4.2 차별화 방어 → `ReviewNotes.md`

### 검증

- [ ] 빌드 업로드 (Xcode → Archive → Upload)
- [ ] 빌드 선택 + 제출
- [ ] 수출 규정 최종 확인

## Gate 4: 출시 전

- [ ] 사업자등록 완료
- [ ] 통신판매업 신고 완료
- [ ] 앱 내 사업자정보 표시 구현
- [ ] AdMob 실제 광고 Unit ID 교체
- [ ] App Store 다운로드 링크 업데이트 (index.html 의 placeholder ID)
- [ ] W-8BEN 제출 (글로벌 확장 시)
