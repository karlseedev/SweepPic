# LiquidGlassKit 적용 계획

**작성일**: 2026-01-27
**버전**: v1
**관련 문서**: [260127LiquidKit-Research.md](./260127LiquidKit-Research.md)

---

## 1. 목표

### 1.1. 핵심 목표

iOS 26 Liquid Glass 효과를 iOS 16-25에서도 동일하게 구현하여 **시각적 통일성** 확보.

### 1.2. 세부 목표

| 목표 | 설명 |
|------|------|
| 굴절 효과 | 스크롤 시 탭바 테두리에서 배경이 왜곡되는 유리 효과 |
| 색수차 | 가장자리 프리즘 색 분리 |
| 탭 이동 애니메이션 | squash/stretch 가속도 기반 애니메이션 |
| 버튼 인터랙션 | 누르면 확장 + 굴절 효과 + 햅틱 |
| iOS 26 자동 전환 | iOS 26+에서는 네이티브 API 사용 |

---

## 2. 현재 상태

### 2.1. 기존 구현 파일

| 파일 | 역할 | 상태 |
|------|------|------|
| `LiquidGlassPlatter.swift` | 탭바 배경 블러 | UIVisualEffectView 기반 |
| `LiquidGlassShadowContainer` | 그림자 컨테이너 | Platter 내부 |
| `LiquidGlassSelectionPill.swift` | 선택 표시 pill | UIVisualEffectView 기반 |
| `LiquidGlassTabButton.swift` | 탭 버튼 | 아이콘 + 라벨 |
| `LiquidGlassTabBar.swift` | 탭바 전체 | 비즈니스 로직 |
| `LiquidGlassStyle.swift` | 스타일 헬퍼 | 테두리, 그림자 등 |
| `LiquidGlassConstants.swift` | 상수 정의 | 크기, 애니메이션 |
| `GlassButton.swift` | 일반 버튼 | 블러 + 틴트 |

### 2.2. 문제점

- ❌ 굴절 효과 없음 (단순 블러)
- ❌ 색수차 없음
- ❌ squash/stretch 애니메이션 없음
- ❌ 버튼 누르면 작아짐 (iOS 26은 커짐)
- ❌ 햅틱 피드백 없음

---

## 3. 구현 계획

### Phase 1: LiquidGlassKit 설치

**작업 내용:**
1. SPM으로 LiquidGlassKit 추가
2. 빌드 확인
3. 기본 import 테스트

**변경 파일:**
- `Package.swift` 또는 Xcode Project

**예상 코드:**
```swift
dependencies: [
    .package(url: "https://github.com/DnV1eX/LiquidGlassKit.git", from: "1.0.0")
]
```

---

### Phase 2: LiquidGlassPlatter 교체

**목표:** 탭바 배경에 굴절 효과 적용

**변경 전:**
```swift
// LiquidGlassPlatter.swift
private lazy var backgroundBlur: UIVisualEffectView = {
    let effect = UIBlurEffect(style: .systemUltraThinMaterial)
    let view = UIVisualEffectView(effect: effect)
    return view
}()
```

**변경 후:**
```swift
import LiquidGlassKit

// LiquidGlassView(.regular) 사용
private lazy var liquidGlassView: LiquidGlassView = {
    let view = LiquidGlassView(.regular)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
}()
```

**삭제 대상:**
- `LiquidGlassShadowContainer` 클래스 (LiquidGlassView에 ShadowView 내장)
- `backgroundBlur` 관련 코드
- `highlightLayer` 관련 코드 (LiquidGlassView가 처리)

**유지:**
- 코너 설정
- 레이아웃 제약조건

---

### Phase 3: LiquidGlassSelectionPill 교체

**목표:** Selection Pill에 굴절 효과 + squash/stretch 애니메이션

**변경 전:**
```swift
// LiquidGlassSelectionPill.swift
private lazy var pillBlur: UIVisualEffectView = {
    let effect = UIBlurEffect(style: .light)
    let view = UIVisualEffectView(effect: effect)
    return view
}()

func moveTo(button: UIView, animated: Bool) {
    // 단순 위치 이동
    UIView.animate(...) {
        self.leadingConstraint?.constant = newLeading
    }
}
```

**변경 후:**
```swift
import LiquidGlassKit

// LiquidLensView 사용
final class LiquidGlassSelectionPill: UIView {
    private lazy var lensView: LiquidLensView = {
        let view = LiquidLensView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    func moveTo(button: UIView, animated: Bool) {
        // lifted 상태로 전환 (굴절 효과 활성화)
        lensView.setLifted(true, animated: animated, alongsideAnimations: {
            self.leadingConstraint?.constant = newLeading
            self.superview?.layoutIfNeeded()
        }, completion: { _ in
            // 이동 완료 후 resting 상태로
            self.lensView.setLifted(false, animated: true,
                                    alongsideAnimations: nil,
                                    completion: nil)
        })
    }
}
```

**핵심 변경:**
- `UIVisualEffectView` → `LiquidLensView`
- 탭 전환 시 `setLifted(true)` → 이동 → `setLifted(false)`
- 가속도 기반 squash/stretch 자동 적용

---

### Phase 4: GlassButton 개선

**목표:** 버튼 누르면 확장 + 굴절 효과 + 햅틱

**변경 전:**
```swift
// GlassButton.swift
override var isHighlighted: Bool {
    didSet { animateInteraction(isPressed: isHighlighted) }
}

private func animateInteraction(isPressed: Bool) {
    let scale: CGFloat = isPressed ? 0.96 : 1.0  // 작아짐
    UIView.animate(...) {
        self.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}
```

**변경 후:**
```swift
import LiquidGlassKit

final class GlassButton: UIButton {

    // Dual state views
    private let contractedView = UIView()  // resting: 블러 배경
    private lazy var expandedView = LiquidGlassView(.thumb())  // pressed: 굴절 효과

    // Haptic
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    // State
    private var isExpanded = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        expandButton(animated: true)
        feedbackGenerator.impactOccurred()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        contractButton(animated: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        contractButton(animated: true)
    }

    private func expandButton(animated: Bool) {
        guard !isExpanded else { return }
        isExpanded = true

        // LiquidGlassSwitch 패턴 적용
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0
        ) {
            self.contractedView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            self.contractedView.alpha = 0
            self.expandedView.transform = .identity
            self.expandedView.alpha = 1
        }
    }

    private func contractButton(animated: Bool) {
        guard isExpanded else { return }
        isExpanded = false

        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0
        ) {
            self.expandedView.transform = CGAffineTransform(scaleX: 0.87, y: 0.87)
            self.expandedView.alpha = 0
            self.contractedView.transform = .identity
            self.contractedView.alpha = 1
        }
    }
}
```

**핵심 변경:**
- Dual state: contracted (resting) ↔ expanded (pressed)
- 누르면 **커지면서** 굴절 효과
- Spring 애니메이션 (damping: 0.6-0.7)
- 햅틱 피드백 추가

---

### Phase 5: 정리 및 최적화

**삭제할 파일/코드:**

| 대상 | 이유 |
|------|------|
| `LiquidGlassStyle.swift` 대부분 | LiquidGlassKit이 처리 |
| `LiquidGlassShadowContainer` | LiquidGlassView에 내장 |
| `backgroundBlur` 관련 | LiquidGlassView로 대체 |
| `highlightLayer` 관련 | LiquidGlassView가 처리 |

**유지할 파일/코드:**

| 대상 | 이유 |
|------|------|
| `LiquidGlassConstants.swift` | 크기/레이아웃 상수 (일부) |
| `LiquidGlassTabButton.swift` | 아이콘/라벨 로직 |
| `LiquidGlassTabBar.swift` | 비즈니스 로직 |

**Constants 정리:**

```swift
// 유지할 상수
enum LiquidGlassConstants {
    enum Platter {
        static let height: CGFloat = 62
        static let cornerRadius: CGFloat = 31
        // ...
    }

    enum TabButton {
        static let width: CGFloat = 94
        static let height: CGFloat = 54
        // ...
    }

    // 삭제: Blur, Animation (LiquidGlassKit이 처리)
}
```

---

## 4. 파일별 변경 요약

| 파일 | 작업 | Phase |
|------|------|-------|
| `Package.swift` / Xcode | SPM 추가 | 1 |
| `LiquidGlassPlatter.swift` | LiquidGlassView로 교체 | 2 |
| `LiquidGlassSelectionPill.swift` | LiquidLensView로 교체 | 3 |
| `GlassButton.swift` | Dual state + 햅틱 추가 | 4 |
| `LiquidGlassStyle.swift` | 대부분 삭제 | 5 |
| `LiquidGlassConstants.swift` | Blur/Animation 삭제 | 5 |
| `LiquidGlassTabButton.swift` | 변경 없음 | - |
| `LiquidGlassTabBar.swift` | import 추가만 | 2 |

---

## 5. 테스트 계획

### 5.1. 기능 테스트

| 테스트 항목 | 확인 내용 |
|------------|----------|
| 탭바 배경 굴절 | 스크롤 시 배경 왜곡 확인 |
| Selection Pill 이동 | squash/stretch 애니메이션 확인 |
| 버튼 인터랙션 | 확장/축소 + 굴절 + 햅틱 확인 |
| iOS 버전 분기 | iOS 26 네이티브, iOS 16-25 커스텀 |

### 5.2. 성능 테스트

| 테스트 항목 | 기준 |
|------------|------|
| 스크롤 FPS | 60fps 유지 (ProMotion: 120fps) |
| 메모리 사용량 | 기존 대비 +10% 이내 |
| 배터리 소모 | Metal GPU 사용량 모니터링 |

### 5.3. 호환성 테스트

| 기기/OS | 테스트 |
|---------|--------|
| iPhone 17 (iOS 26) | 네이티브 API 동작 확인 |
| iPhone 15 (iOS 18) | LiquidGlassKit 동작 확인 |
| iPhone 13 (iOS 16) | 최소 지원 버전 확인 |

---

## 6. 리스크 및 대응

### 6.1. 성능 리스크

| 리스크 | 대응 |
|--------|------|
| Metal 렌더링 부하 | `autoCapture = false` 설정, 수동 캡처 |
| CPU 부하 (iOS 26.2+) | `captureRootView()` 최적화 |
| 메모리 증가 | ZeroCopyBridge 활용 확인 |

### 6.2. 호환성 리스크

| 리스크 | 대응 |
|--------|------|
| iOS 13-15 미지원 | 최소 지원 iOS 16 유지 (문제 없음) |
| App Store 리젝 | Public API 옵션 사용 (iOS 26.2+) |

### 6.3. 구현 리스크

| 리스크 | 대응 |
|--------|------|
| LiquidGlassKit 버그 | GitHub Issue 확인, 필요시 Fork |
| 커스텀 요구사항 충돌 | LiquidGlassKit 파라미터 조정 |

---

## 7. 일정 (예상)

| Phase | 작업 | 예상 |
|-------|------|------|
| 1 | LiquidGlassKit 설치 | - |
| 2 | Platter 교체 | - |
| 3 | SelectionPill 교체 | - |
| 4 | GlassButton 개선 | - |
| 5 | 정리 및 최적화 | - |
| - | 테스트 및 버그 수정 | - |

---

## 8. 롤백 계획

각 Phase 시작 전 Git 커밋 필수.

```bash
# Phase 시작 전
git add . && git commit -m "chore: before Phase N - LiquidGlassKit 적용"

# 문제 발생 시 롤백
git revert HEAD
```

---

## 변경 이력

| 날짜 | 변경 내용 |
|------|-----------|
| 2026-01-27 | 초안 작성 |
