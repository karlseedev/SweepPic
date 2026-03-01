# Gate 3. 심사 차단

> 심사원이 Guideline 위반으로 리젝함
> Gate 1~2를 통과해서 심사에 들어갔지만, 사람/자동 스캔이 문제를 발견

---

### 분류 요약

```
3. 심사 차단
   1) 코드/설정: #if DEBUG 래핑, Limited Access UI, Usage Description 한글, 접근성(VoiceOver/Reduce Motion)
   2) 포털 입력: Review Notes (접근 정당화 + 4.2 차별화)
   3) 검증: 크래시 테스트, 권한 테스트, 빈 상태 테스트
```

---

## 1) 코드/설정 — 프로젝트 파일 변경

### `#if DEBUG` 래핑 — Private API / Debug 코드

> **위험도: 치명** — Guideline 2.5.1 (비공개 API 사용 금지) 위반 시 즉시 리젝

**현재 문제:**

| 파일 | 문제 | 위험도 |
|------|------|:------:|
| `SystemUIInspector.swift` | KVC로 시스템 UI 접근 (Private API). `#if DEBUG` 미래핑으로 릴리즈 빌드에 포함 | **치명** |
| `AutoScrollTester.swift` | 디버그 전용 자동 스크롤 테스터. `#if DEBUG` 미래핑 | **치명** |
| `LiquidGlassOptimizer.swift` | 디버그 전용 코드 포함. `#if DEBUG` 미래핑 | **치명** |

**조치:**
- 파일 전체를 `#if DEBUG` ... `#endif`로 래핑
- 또는 빌드 타겟에서 릴리즈 빌드 시 해당 파일 제외

**관련 Guideline:**

| 번호 | 제목 | 내용 |
|------|------|------|
| 2.5.1 | 공개 API만 사용 | 비공개(private) API 사용 금지. Apple 자동 스캔으로 탐지 가능 |
| 2.5.2 | 자체 완결 번들 | 외부 코드 다운로드 금지 |

### Limited Photo Access UI

> **위험도: 높음** — Guideline 2.1 (App Completeness) 위반 가능

**배경 — 데이터 최소화 원칙 (Guideline 5.1.1(iii)):**

Apple은 "가능하면 PHPicker를 사용하라"고 명시. 전체 사진 접근을 요구하는 앱은 그 이유를 설득해야 함.

| 접근 방식 | 설명 | 심사 부담 |
|----------|------|:---------:|
| PHPicker | 사용자가 선택한 사진만 접근. 추가 권한 불필요 | 낮음 |
| Limited Access | `.limited` 상태. 사용자가 선택한 사진만 노출 | 중간 |
| Full Access | `.authorized` 상태. 전체 라이브러리 접근 | **높음 — 사유 필요** |

**현재 문제:**
- iOS 14+ `.limited` 상태에서 빈 화면/크래시 발생 시 Guideline 2.1 위반
- `.denied` / `.restricted` 상태에서의 동작 미확인

**조치:**
- `.limited` 상태에서 선택된 사진만 표시 + 전체 접근 업그레이드 안내 UI
- `.denied` / `.restricted` 상태에서 적절한 안내 화면 + 설정 이동 버튼
- 사진 0장 상태에서 빈 상태 뷰 표시

### NSPhotoLibraryUsageDescription 한글 Localization

> **위험도: 높음** — 한국 사용자 대상 앱인데 영어 권한 요청 문구 시 부자연스러움 + 리젝 가능

| 항목 | 현재 | 조치 |
|------|------|------|
| NSPhotoLibraryUsageDescription | 영어만 존재 | 한글 Localization 파일 추가 |

**권한 문구 리젝/통과 예시:**

```
❌ "앱 사용에 사진 접근이 필요합니다." — 리젝
❌ "Photo access needed." — 리젝

✅ "사진 라이브러리의 사진을 탐색하고, 스와이프 제스처로 빠르게 정리하기 위해
    접근합니다. 사진 데이터는 기기 내에서만 처리됩니다."
```

> 출처: MenuResearch §6 — 권한 문구 예시

> 얼굴 데이터 사용 제한 (Guideline 5.1.2(vi)), 온디바이스 처리 전략, 고지 문구 예시 → [Gate 2 Privacy Policy 섹션](260212AppStore-Gate2.md#2-문서--외부-호스팅-웹-문서) 참조

### 접근성 — VoiceOver / Reduce Motion

> **위험도: 높음** — 핵심 기능(스와이프 삭제)에 접근성 대안이 없으면 Guideline 2.1 (App Completeness) 위반 가능
> EU EAA (2025.6 시행)로 법적 의무화 추세

**현재 상태:** VoiceOver 일부 UI만 적용 (PhotoCell, FloatingTabBar 등), Reduce Motion 미대응

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| VoiceOver 지원 | 모든 텍스트 VoiceOver로 읽기 가능, 중요 항목에 레이블 제공 | 강력 권장 |
| **스와이프 대체 액션** | **`accessibilityCustomActions`로 삭제 대안 제공 — 핵심 제스처의 접근성 대안 필수** | **필수** |
| 대체 텍스트 | 의미 있는 이미지/아이콘에 대체 텍스트 | 강력 권장 |
| 터치 타겟 | 최소 44x44 포인트 | 권장 |
| **Reduce Motion** | `isReduceMotionEnabled` 시 애니메이션 → crossfade 대체 | 강력 권장 |

> **중요**: PIClear는 스와이프 삭제가 핵심 인터랙션이므로, VoiceOver 사용자를 위한 대체 삭제 액션(`accessibilityCustomActions`)이 반드시 필요합니다. 이 없이는 핵심 기능을 사용할 수 없어 접근성 심사에서 문제가 될 수 있습니다.

**조치:**
- 모든 UI 컴포넌트에 `accessibilityLabel` 추가
- 의미 있는 이미지에 `accessibilityHint` 추가
- 터치 타겟 44x44pt 이상 확인
- **스와이프 삭제에 대한 `accessibilityCustomActions` 구현**
- 뷰어 삭제 모션(위로 올라감 + 슬라이드인) → Reduce Motion 시 crossfade 대체
- 그리드 ↔ 뷰어 줌 전환 → Reduce Motion 시 crossDissolve 대체
- `UIAccessibility.reduceMotionStatusDidChangeNotification` 구독하여 런타임 전환 지원

**EU European Accessibility Act (EAA):**

| 항목 | 내용 |
|------|------|
| 시행일 | 2025.06.28 |
| 적용 범위 | EU/EEA에서 다운로드 가능한 모든 앱 |
| 핵심 요구 | WCAG 2.1 AA 수준 준수 (VoiceOver, Dynamic Type, 색상 대비, 키보드/스위치 대안, Reduce Motion) |
| 위반 시 | 각국 시장 감시 기관이 제재 가능 (벌금, 앱 퇴출) |
| PIClear 영향 | 한국만 배포 시 직접 적용 안 됨. 향후 글로벌 배포 시 필수 |

> 현재 한국 배포 전용이므로 즉시 의무는 아니지만, Apple이 접근성을 점점 강화하는 추세이므로 선제 대응 권장.

---

## 2) 포털 입력 — App Store Connect에서 입력

### Review Notes 작성

> **위험도: 높음** — 사진 접근 사유, Vision 설명 없이 제출하면 리젝 가능성 높음

**PIClear Review Notes 템플릿:**

```
[App Overview]
PIClear is a photo gallery app focused on fast photo organization.
Users can quickly sort their photo library using swipe-to-delete and
similar photo detection features.

[Why Full Photo Library Access is Required]
1. PHOTO ORGANIZATION: The core purpose is to help users efficiently
   sort and organize their ENTIRE photo library. PHPicker only allows
   selecting individual photos, which defeats the purpose of library-
   wide organization.
2. SIMILAR PHOTO DETECTION: Our similarity analysis needs to compare
   ALL photos in the library to find duplicates and similar groups.
   This is impossible with limited or picker-based access.
3. GRID BROWSING: We provide a native-like grid browsing experience
   where users can scroll through their complete library, just like
   the built-in Photos app.

[Face Detection — On-Device Only]
- Vision Framework is used for face detection (auto-zoom feature)
- ALL processing is done 100% on-device
- No face data is ever transmitted, stored externally, or used for
  tracking/advertising/data mining
- Compliant with Guideline 5.1.2(vi)

[Privacy]
- No user data is collected or transmitted
- No analytics, tracking, or advertising SDKs
- All photo processing happens on-device only
- Privacy Policy: [URL]

[Testing Instructions]
- Grant full photo library access when prompted
- For similar photo feature: requires 50+ photos for meaningful results
- Swipe up on any photo in the viewer to delete (restore from trash available)
- Tap the similar photo button to see grouped similar photos

[Device Tested]
- iPhone 15 Pro / iOS 17.x
- iPhone 17 Pro / iOS 26.x
```

**핵심 작성 요령:**

| 항목 | 요령 |
|------|------|
| 전체 사진 접근 사유 | 구체적 이유 3가지를 번호 매겨 설명. "전체 라이브러리 정리가 핵심 목적"이 가장 강한 논거 |
| Vision 온디바이스 | "100% on-device", "no data transmitted" 를 반복 강조 |
| 테스트 조건 | 최소 사진 수(유사 사진 기능 50장+), 스와이프 방향 등 심사원이 기능을 빠르게 체험할 수 있게 안내 |
| 차별화 기능 | 스와이프 삭제, 유사 사진 분석 등 네이티브 앱에 없는 기능 나열 |

### PIClear 특화: AutoCleanup AI 의사결정 고지

> 2025년 한국 개인정보보호법 개정에 따라 자동화된 의사결정에 대한 고지 의무 추가

AutoCleanup 기능이 AI 기반 자동 정리를 수행하는 경우:
- 사용자에게 자동화된 의사결정이 이루어지고 있음을 고지해야 함
- 처리방침 및 앱 내 UI에서 "AI가 삭제를 제안하며, 최종 결정은 사용자가 합니다" 등의 문구 필요
- Review Notes에도 자동화 범위와 사용자 통제권을 명시하는 것이 안전

> 출처: MenuResearch §12-19 — AutoCleanup AI 의사결정 고지

---

### Guideline 4.2 방어 — "네이티브 앱이랑 뭐가 달라?"

> 사진 앱 리젝 유형 1위: "기본 사진 앱과 차별화 부족" (Guideline 4.1 / 4.2)

**차별화 근거:**

| 차별화 기능 | 네이티브 사진 앱 | PIClear |
|------------|:---------------:|:---------:|
| 스와이프 삭제 | X | **O** — 위로 스와이프로 빠른 삭제 |
| 휴지통 복구 기반 안전장치 | X (삭제 확인 다이얼로그) | **O** — 확인 없이 삭제 + 즉시 복구 가능 |
| 유사 사진 그룹화 | X (iOS 16+은 중복 감지만) | **O** — Vision 기반 유사도 분석 |
| 자동 얼굴 확대 | X | **O** — 뷰어에서 얼굴 자동 인식/줌 |
| 사진 정리 생산성 | 범용 뷰어 | **정리 특화** — 빠른 분류에 최적화 |

**경쟁 앱 선례 (심사 통과 사례):**

| 앱 | 평점 | 차별화 | 심사 통과 |
|-----|------|--------|:--------:|
| Slidebox | 4.8 | 스와이프 정리 | O — 수년간 운영 |
| Gemini Photos | 4.7 | AI 중복 감지 | O |
| Cleanup | 4.6 | 스마트 정리 | O |

> 스와이프 기반 사진 정리만으로도 충분한 차별화 근거 (Slidebox 사례)

**ASC 포지셔닝:**

| 항목 | 권장값 |
|------|-------|
| Primary Category | **Photo & Video** |
| 앱 설명 키워드 | "사진 정리", "스와이프 삭제", "유사 사진 분석" |
| 포지셔닝 | "사진 정리 생산성 도구" (범용 갤러리가 아닌 정리 특화) |

---

## 3) 검증 — 실기기/시뮬레이터 테스트

### 테스트 시나리오

> 2024년 리젝 1위: Performance (크래시, 미완성 기능) — 1.2M건

**필수 테스트 시나리오:**

| # | 시나리오 | 확인 포인트 |
|---|---------|-----------|
| 1 | 사진 접근 권한: **허용** | 전체 기능 정상 동작 |
| 2 | 사진 접근 권한: **제한 (.limited)** | 선택된 사진만 표시 + 업그레이드 안내 |
| 3 | 사진 접근 권한: **거부** | 안내 화면 + 설정 이동 버튼 |
| 4 | 사진 **0장** | 빈 상태 뷰 (크래시 없음) |
| 5 | **스와이프 삭제** → 휴지통 → 복구 | 정상 동작, 데이터 무결성 |
| 6 | **유사 사진 분석** | 결과 표시 (50장+ 필요) |
| 7 | **얼굴 인식** → 자동 줌 | 정상 동작 |
| 8 | 그리드 ↔ 뷰어 전환 | 자연스러운 전환, 크래시 없음 |
| 9 | 앱 **백그라운드** → 포그라운드 복귀 | 상태 복원, 크래시 없음 |
| 10 | **메모리 부족** 시나리오 | 우아한 처리, 크래시 없음 |

### 리젝 방지 체크리스트 (Gate 3 항목만)

- [ ] 디버그 코드가 릴리즈 빌드에서 제외되었는가?
- [ ] 모든 기능이 완전히 동작하는가? (빈 화면, 플레이스홀더 없음)
- [ ] 사진 접근 거부/제한 시 정상 처리되는가?
- [ ] 크래시 없이 모든 주요 흐름이 완료되는가?
- [ ] Review Notes에 사진 접근 사유가 명시되어 있는가?
- [ ] 스와이프 삭제에 VoiceOver 대체 액션(`accessibilityCustomActions`)이 구현되었는가?
- [ ] Reduce Motion 활성화 시 애니메이션이 crossfade로 대체되는가?

> Gate 1/2 항목(Privacy Manifest, 앱 아이콘, 스크린샷, 프라이버시 정책 URL, 연령 등급 등)은 해당 Gate 문서에서 확인

---

## 사진 앱 리젝 사례 분석 (참고)

### 사진 앱 특화 리젝 유형 TOP 5

| 순위 | 리젝 유형 | Guideline | 빈도 |
|:----:|----------|:---------:|:----:|
| 1 | 네이티브 사진 앱 복제 | 4.1 / 4.2 | 매우 높음 |
| 2 | 전체 사진 접근 미설명 | 5.1.1(iii) | 높음 |
| 3 | 프라이버시 정책 미흡 | 5.1.1 | 높음 |
| 4 | 빈 상태 처리 | 2.1 | 중간 |
| 5 | Private API 사용 | 2.5.1 | 중간 |

### 리젝 통계 (2024년 기준)

| 항목 | 수치 |
|------|------|
| 총 심사 건수 | 7.7M건 |
| 리젝 건수 | 1.9M건 (약 25%) |
| Performance 리젝 | 1.2M건 (1위) |
| 리젝 후 수정 통과 | 295K건 |
| 첫 제출 통과율 | 약 75% |

### 심사 프로세스

| 유형 | 기간 |
|------|------|
| 일반 심사 | 90%가 24시간 이내 |
| 신규 앱 첫 제출 | 24~72시간 |
| Expedited Review | 치명적 버그/보안 문제 시만 승인 |

**리젝 시 대응:**

| 단계 | 행동 |
|------|------|
| 1 | App Store Connect > Resolution Center에서 상세 사유 확인 |
| 2 | 구체적 Guideline 번호와 설명 확인 |
| 3 | 코드/메타데이터 수정 |
| 4 | Resolution Center에서 답변 + 새 빌드 업로드 |
| 5 | 부당 시 App Review Board에 항소 가능 |

---

## 참고 문서

| 문서 | URL |
|------|-----|
| App Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| 제출 가이드 | https://developer.apple.com/app-store/submitting/ |
| Upcoming Requirements | https://developer.apple.com/news/upcoming-requirements/ |
