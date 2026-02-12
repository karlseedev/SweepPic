# Gate 4. 품질 개선

> 심사 통과와 무관하지만 앱 퀄리티를 높이는 항목
> Gate 1~3이 모두 해결된 후 여유가 있을 때 진행

---

### 분류 요약

```
4. 품질 개선
   1) 코드/설정: print문 정리, VoiceOver, Dynamic Type, Localization
   2) 에셋: LaunchScreen 브랜딩
```

---

## 1) 코드/설정 — 프로젝트 파일 변경

### print문 정리

> 직접적 리젝 사유는 아니지만 코드 품질 및 정보 노출 우려

| 파일 | 설명 |
|------|------|
| `FeatureFlags.swift` | print문 잔존 |
| `CleanupSessionStore.swift` | print문 잔존 |
| `ViewerViewController+SimilarPhoto.swift` | print문 잔존 |

**조치:**
- `Log.print()` (앱 내 로그 시스템)으로 전환
- 또는 `#if DEBUG` 래핑으로 릴리즈에서 제외

### VoiceOver 전체 UI 확대

> 현재 상태: 일부 UI만 적용 (PhotoCell, FloatingTabBar 등)

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| VoiceOver 지원 | 모든 텍스트 VoiceOver로 읽기 가능, 중요 항목에 레이블 제공 | 강력 권장 |
| 대체 텍스트 | 의미 있는 이미지/아이콘에 대체 텍스트 | 강력 권장 |
| 터치 타겟 | 최소 44x44 포인트 | 권장 |

**조치:**
- 모든 UI 컴포넌트에 `accessibilityLabel` 추가
- 의미 있는 이미지에 `accessibilityHint` 추가
- 터치 타겟 44x44pt 이상 확인

### Dynamic Type

> 현재 상태: **미지원**

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| Dynamic Type | 사용자 설정에 따라 텍스트 크기 조절 | 강력 권장 |
| 색상 대비 | 최소 4.5:1 대비 비율 | 강력 권장 |

**조치:**
- `UIFontMetrics` 도입
- 고정 폰트 크기 → Dynamic Type 대응 크기로 변경

### Localization 파일 분리

> 현재 상태: 한글 하드코딩, .strings 파일 없음

**조치:**
- 한/영 .strings 파일 분리
- 하드코딩된 한글 문자열을 `NSLocalizedString` 으로 전환

### 접근성 Nutrition Labels (참고)

> App Store Connect의 Accessibility Nutrition Labels는 **현재 선택사항(voluntary)**.
> Apple은 향후 필수로 전환 예정임을 명시. 정확한 필수화 시점은 미발표.
> **주의: "지원함"으로 체크할 경우, 해당 기능이 실제로 구현되어 있어야 함. 허위 체크 시 리젝 가능.**

---

## 2) 에셋 — 이미지 파일 제작

### LaunchScreen 브랜딩

> 현재 상태: 빈 흰색 화면 (LaunchScreen.storyboard는 존재)

**조치:**
- 앱 로고 추가 (중앙 배치)
- 브랜드 컬러 적용

> 리젝 사유는 아니지만, 첫인상 향상에 효과적

---

## 참고 문서

| 문서 | URL |
|------|-----|
| Accessibility Nutrition Labels | https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/ |
| 앱 아이콘 가이드 (HIG) | https://developer.apple.com/design/human-interface-guidelines/app-icons |
| Launch Screen 설정 | https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen |
