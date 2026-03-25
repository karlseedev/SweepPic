# Gate 4. 품질 개선

> 심사 통과와 무관하지만 앱 퀄리티를 높이는 항목
> Gate 1~3이 모두 해결된 후 여유가 있을 때 진행

---

### 분류 요약

```
4. 품질 개선
   1) 코드/설정: print문 정리, Dynamic Type, Localization
   2) 에셋: LaunchScreen 브랜딩
```

---

## 1) 코드/설정 — 프로젝트 파일 변경

### print문 정리

> 직접적 리젝 사유는 아니지만 코드 품질 및 정보 노출 우려

| 파일 | 상태 | 비고 |
|------|:----:|------|
| `FeatureFlags.swift` | **해결됨** ✅ | `#if DEBUG` 블록 내부 (88~100줄) → 릴리즈 미포함 |
| `CleanupSessionStore.swift` | **해결됨** ✅ | bare print문 없음 |
| `ViewerViewController+SimilarPhoto.swift` | **해결됨** ✅ | 주석 처리됨 (79줄) |

> 잔여: `LiquidGlassKit/ZeroCopyBridge.swift`에 에러 로깅용 bare print 2건. 외부 패키지(fork)이므로 우선순위 낮음.

### Dynamic Type

> VoiceOver, 스와이프 대체 액션, Reduce Motion, EU EAA는 리젝 가능성이 있어 [Gate 3](260212AppStore-Gate3.md)으로 이동됨
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

### iOS 26 Liquid Glass 대응 일정 (참고)

> SweepPic 커스텀 UI의 Liquid Glass 대응이 필요합니다

| 시기 | 요구사항 |
|------|---------|
| **2026년 4월 28일** | App Store 제출 시 **Xcode 26 (iOS 26 SDK) 필수** |
| 자동 적용 | UINavigationBar, UITabBar → Liquid Glass 자동 |
| ~~수동 대응 필요~~ | ~~FloatingTabBar → glassEffect 적용~~ → **불필요** (iOS 26+에서 FloatingTabBar 미사용, 시스템 UITabBar로 전환 — `TabBarController.swift:46`) |
| 옵트아웃 | 현재 가능, Xcode 27 이후 제거 예정 |

> 출처: MenuResearch §12-17,18 — iOS 26 Liquid Glass 대응

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
