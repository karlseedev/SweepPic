# Gate 3. 심사 차단

> 심사원이 Guideline 위반으로 리젝함
> Gate 1~2를 통과해서 심사에 들어갔지만, 사람/자동 스캔이 문제를 발견

---

### 분류 요약

```
3. 심사 차단
   1) 코드/설정: #if DEBUG 래핑, Limited Access UI, Usage Description 한글
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

**얼굴 데이터 사용 제한 (Guideline 5.1.2(vi)):**

> Photo APIs, 카메라, ARKit 등으로 수집한 얼굴 매핑/데이터는 마케팅, 광고, 데이터마이닝에 사용 금지.

| 항목 | PickPhoto 해당 여부 |
|------|:-----------------:|
| Vision Framework 얼굴 인식 사용 | **O** |
| 얼굴 데이터 외부 전송 | X (온디바이스 전용) |
| 마케팅/광고 활용 | X |
| 데이터마이닝 활용 | X |

> PickPhoto는 얼굴 인식 결과를 뷰어에서 자동 줌에만 사용하고, 기기 밖으로 전송하지 않으므로 **준수 상태**. Privacy Policy + Review Notes에 명시 필요.

---

## 2) 포털 입력 — App Store Connect에서 입력

### Review Notes 작성

> **위험도: 높음** — 사진 접근 사유, Vision 설명 없이 제출하면 리젝 가능성 높음

**PickPhoto Review Notes 템플릿:**

```
[App Overview]
PickPhoto is a photo gallery app focused on fast photo organization.
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
- Swipe up on any photo in the viewer to delete (undo available)
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

### Guideline 4.2 방어 — "네이티브 앱이랑 뭐가 달라?"

> 사진 앱 리젝 유형 1위: "기본 사진 앱과 차별화 부족" (Guideline 4.1 / 4.2)

**차별화 근거:**

| 차별화 기능 | 네이티브 사진 앱 | PickPhoto |
|------------|:---------------:|:---------:|
| 스와이프 삭제 | X | **O** — 위로 스와이프로 빠른 삭제 |
| Undo 기반 안전장치 | X (삭제 확인 다이얼로그) | **O** — 확인 없이 삭제 + 실시간 Undo |
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
| 5 | **스와이프 삭제** → Undo → 복구 | 정상 동작, 데이터 무결성 |
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
