# iOS 26 시스템 모션 분석 종합 자료

**작성일**: 2026-01-23
**통합 문서**: `docs/llm/1.md`, `docs/llm/2.md`, `docs/llm/3.md` 병합
**목표**: iOS 26 시스템 UI(Photos 앱 등)에서 사용되는 애니메이션의 물리적 파라미터(Damping, Stiffness, Mass, Duration 등)를 추출하여 커스텀 구현에 반영하기 위한 종합 기술 자료.

---

## 0. Executive Summary

### 핵심 결론
1. **iOS 26 시스템 모션을 앱 내에서 "완벽히" 추출하는 것은 불가능** — 렌더 서버(backboardd)에서 out-of-process로 처리되기 때문
2. **앱 프로세스 내 애니메이션은 부분적으로 캡처 가능** — `CALayer.addAnimation` 스위즐링 또는 지연 캡처 방식
3. **현실적 대안**: Apple 공식 기본값 사용 + 시각적 비교로 미세 조정

### 권장 접근법
**"지연 캡처(Delayed Capture)"** 방식을 우선 적용 — 안전하고 구현이 간단하며, Public API만 사용

### 즉시 사용 가능한 기본값

| 용도 | 파라미터 | 값 |
|------|---------|-----|
| SwiftUI 바운스 | `.bouncy` | duration: 0.5s |
| UIKit 스프링 | `response` | 0.55 |
| UIKit 스프링 | `dampingFraction` | 0.825 |
| CASpringAnimation | `mass` | 1.0 |
| CASpringAnimation | `stiffness` | 170 |
| CASpringAnimation | `damping` | 15 |

---

## 1. 개요 및 목표

iOS 시스템 UI의 "쫀득한" 느낌은 `CASpringAnimation` 또는 `UIViewPropertyAnimator`의 정교한 물리 상수 설정에서 나옵니다. 이를 똑같이 구현하려면 단순한 관측이 아닌, 실제 실행 중인 애니메이션 객체의 내부 값을 추출해야 합니다.

### 목표
- iOS 26 Liquid Glass 시스템 UI의 모션/애니메이션 파라미터를 런타임에서 추출
- 근본적 한계 파악 및 현실적 대안 정리
- 커스텀 구현(FloatingTabBar, FloatingTitleBar 등)에 반영

---

## 2. 현재 도구 상태

### SystemUIInspector 현황
- **위치**: `PickPhoto/PickPhoto/Debug/SystemUIInspector.swift`
- **기능**: 뷰/레이어 **정적 속성 덤프**만 수행
- **한계**: `animationKeys()`, `presentationLayer()`, `CAAnimation` 캡처 같은 **모션 수집 로직이 없음**

### 현재 도구로 가능한 것
- `UIWindow`부터 시작하여 모든 하위 뷰/레이어 순회
- 속성 덤프: `frame`, `color`, `cornerRadius`, `backgroundColor` 등
- 정적인 레이아웃 구조와 스타일(색상, 블러 등) 파악

### 현재 도구로 불가능한 것
- **애니메이션 정보 획득 불가**: 애니메이션은 "과정"이므로 정적 스냅샷에는 최종 상태(`model layer`)나 현재 보이는 상태(`presentation layer`)의 값만 남음
- "어떻게 움직이는지"(물리 상수)는 캡처되지 않음

---

## 3. iOS 렌더링 아키텍처 (핵심)

### 3.1. 렌더 서버 (backboardd)

iOS 6부터 도입된 `backboardd`는 SpringBoard에서 분리된 시스템 데몬으로, 다음을 담당합니다:

- **이벤트 처리**: 모든 터치 이벤트를 먼저 수신하여 앱에 전달
- **화면 합성**: 모든 활성 CAContext의 렌더링 출력을 합성
- **애니메이션 물리 계산**: CATransaction 커밋 후 모든 애니메이션 단계 처리

> "The Render Server (backboardd on iOS, WindowServer on macOS) is responsible for taking the rendered output of all active CAContexts and compositing them together into the final image that is sent to the display hardware."
> — [iOS Rendering Docs](https://github.com/EthanArbuckle/ios-rendering-docs)

### 3.2. 애니메이션 처리 흐름

```
┌─────────────────────────────────────────────────────────────────────┐
│                         앱 프로세스                                  │
├─────────────────────────────────────────────────────────────────────┤
│  1. CALayer 트리 구성                                                │
│  2. CAAnimation 생성 (여기서만 캡처 가능)                             │
│  3. CATransaction 커밋 ──────────────────────────────────────────────┼──┐
│                                                                     │  │
│  ※ 이 시점 이후 앱은 애니메이션 제어 불가                              │  │
└─────────────────────────────────────────────────────────────────────┘  │
                                                                         │
┌─────────────────────────────────────────────────────────────────────┐  │
│                     렌더 서버 (backboardd)                           │  │
├─────────────────────────────────────────────────────────────────────┤  │
│  4. 레이어 트리 수신 ◀──────────────────────────────────────────────────┘
│  5. 애니메이션 물리 계산 (mass, stiffness, damping 적용)              │
│  6. 프레임별 렌더링                                                   │
│  7. VSync 대기 후 디스플레이 전송                                     │
└─────────────────────────────────────────────────────────────────────┘
```

> "When a UIKit animation is created, it is itself a CATransaction that is sent to the render server. Then all subsequent steps in the animation, as well as the physics calculations occur on the backend regardless of what's going on in your app's threads."
> — [WWDC 2014 Session 419](https://asciiwwdc.com/2014/sessions/419)

### 3.3. CARemoteLayer 아키텍처

앱과 렌더 서버 간 통신은 `CARemoteLayerClient`와 `CARemoteLayerServer`를 통해 이루어집니다. `contextID`를 통해 레이어 트리를 참조하며, 이 과정은 앱에서 직접 접근할 수 없습니다.

### 3.4. 핵심 제약
- **다른 앱(Photos)**의 시스템 UI 모션은 샌드박스 때문에 직접 캡처 불가
- 따라서 **우리 앱 내에서 동일한 UI를 만들고** 분석하는 방식이 현실적
- 디버그 전용 기능으로만 구현해야 안전

---

## 4. 캡처 가능 범위

### 4.1. 가능한 것 vs 불가능한 것

| 구분 | 캡처 가능 | 이유 |
|------|----------|------|
| 앱 내 `UIView.animate` 호출 | ✅ | 앱 프로세스에서 CAAnimation 생성 |
| 앱 내 `UITabBar` / `UINavigationBar` | ⚠️ 부분적 | 일부는 앱, 일부는 시스템에서 처리 |
| Liquid Glass 굴절/렌즈 효과 | ❌ | `CABackdropLayer`, 렌더 서버 처리 |
| `GlassEffectContainer` morphing | ❌ | 시스템 레벨에서 처리 |
| 앱 전환 애니메이션 | ❌ | SpringBoard/FrontBoard 처리 |
| `_UILiquidLensView` 내부 효과 | ❌ | Private 클래스, 렌더 서버 처리 |

### 4.2. iOS 26 Liquid Glass Private 클래스

iOS 26 Liquid Glass에서 사용되는 주요 Private 클래스:

| 클래스 | 역할 |
|--------|------|
| `_UILiquidLensView` | Liquid Glass 루트 뷰 |
| `ClearGlassView` | 유리 효과 렌더링 |
| `CABackdropLayer` | 배경 캡처 및 블러 |
| `CASDFLayer` | SDF 기반 형태/Rim Light |
| `CAFilter` | 색상 매트릭스, 블러 등 필터 |

이들의 내부 애니메이션은 앱 프로세스에서 접근 불가능합니다.

---

## 5. 분석 방법 종합 비교

### 5.1. 정적 분석 (현재 SystemUIInspector)

**원리**: `UIWindow`부터 시작하여 모든 하위 뷰/레이어를 순회하며 속성(`frame`, `color`, `cornerRadius` 등)을 덤프

| 장점 | 단점 |
|------|------|
| 안전함 | 애니메이션 정보 획득 불가 |
| 정적 레이아웃/스타일 파악에 탁월 | "어떻게 움직이는지" 알 수 없음 |

**활용**: 레이아웃 구조 파악, 색상/크기 등 정적 속성 수집

---

### 5.2. 실시간 폴링 (CADisplayLink + presentationLayer)

**원리**: `CADisplayLink`를 사용하여 매 프레임마다 관심 있는 레이어의 `animationKeys()`를 확인하고, 애니메이션이 감지되면 정보를 추출. `presentationLayer()` 값을 샘플링해 모션 곡선 재구성(피팅).

| 장점 | 단점 |
|------|------|
| 애니메이션 시작/끝 실시간 포착 | 매 프레임 검사로 성능 부담 |
| 스위즐링 없이 안전하게 동작 | 1프레임 내 종료되는 애니메이션 놓칠 수 있음 |
| 실제 화면 값으로 곡선 추정 가능 | 스프링 파라미터는 역추정이므로 오차 발생 |

**활용**: 스위즐링이 부담스러울 때 안전한 대안

---

### 5.3. 지연 캡처 (Delayed Capture) ★권장

**원리**: "3초 후 캡처" 버튼을 누른 뒤, 사용자가 UI 동작(탭 전환 등)을 수행. 3초 뒤 도구가 모든 레이어의 `layer.animation(forKey:)`를 조회하여 현재 실행 중인(Active) 애니메이션 객체를 가져옴.

| 장점 | 단점 |
|------|------|
| 안전함 (시스템 변조 없음) | 타이밍 놓치면 애니메이션 이미 종료 |
| Public API만 사용 | 짧은 애니메이션에 취약 |
| 실제 렌더링 중인 CASpringAnimation 직접 열람 가능 | |
| 구현 용이 (Swift로 깔끔하게 구현) | |

**활용**: 가장 먼저 시도해볼 방식. `SystemUIInspector`에 "3초 타이머" 기능 추가로 구현 가능.

---

### 5.4. CALayer.addAnimation 스위즐링

**원리**: `CALayer.add(_:forKey:)` 메서드를 런타임에 교체하여 애니메이션 등록 시점 캡처

```swift
extension CALayer {
    @objc func swizzled_add(_ anim: CAAnimation, forKey key: String?) {
        if let spring = anim as? CASpringAnimation {
            print("mass: \(spring.mass)")
            print("stiffness: \(spring.stiffness)")
            print("damping: \(spring.damping)")
            print("initialVelocity: \(spring.initialVelocity)")
            print("settlingDuration: \(spring.settlingDuration)")
        }
        swizzled_add(anim, forKey: key)
    }
}
```

| 장점 | 단점 |
|------|------|
| 애니메이션 등록 순간 100% 포착 | 런타임 조작으로 충돌 위험 |
| 타이밍 무관 (아무리 짧아도 잡음) | Objective-C 런타임 API 필요 |
| 스프링 파라미터 정확히 추출 | 디버그 전용 (배포 불가) |

**한계**:
- ✅ 앱 프로세스 내 애니메이션만 캡처 가능
- ❌ 시스템 컴포넌트가 내부적으로 생성하는 애니메이션 일부 누락
- ❌ 렌더 서버에서 처리되는 효과는 캡처 불가

**활용**: 지연 캡처가 타이밍 문제로 데이터를 놓칠 때 차선책

---

### 5.5. UIViewPropertyAnimator / UISpringTimingParameters 캡처

**원리**: `UIViewPropertyAnimator` 생성 시점에 `timingParameters`를 읽어서 스프링 파라미터 확보

| 장점 | 단점 |
|------|------|
| UIKit 스프링 애니메이션 파라미터 공식 API로 확인 | 시스템 UI 내부 animator는 외부 접근 불가 |
| 비교적 안전 | 생성 시점 후킹 필요할 수 있음 |

**활용**: 자체 앱 내에서 생성한 UIViewPropertyAnimator 분석 시

---

### 5.6. CAAnimationDelegate 활용

**원리**: 애니메이션 시작/종료 타이밍을 기록해서 기간과 시퀀스를 추적

| 장점 | 단점 |
|------|------|
| 생명주기(시작/종료) 파악에 유용 | 실제 스프링 파라미터는 얻기 어려움 |
| 모션 타이밍 분석에 보조적 역할 | 스위즐링/지연캡처와 결합 필요 |

**활용**: 애니메이션 시퀀스 분석, 타이밍 측정 보조

---

### 5.7. 환경변수 디버깅 (시뮬레이터)

Xcode Scheme > Run > Arguments > Environment Variables에서 설정:

| 환경변수 | 효과 |
|---------|------|
| `CA_PRINT_TREE=1` | 매 프레임 렌더 트리 출력 |
| `CA_LOG_IMPLICIT_TRANSACTIONS=1` | 암시적 트랜잭션 로그 |
| `CA_COLOR_FLUSH=1` | 업데이트 영역 노란색 표시 |
| `CA_COLOR_OPAQUE=1` | 블렌딩 영역 빨간색 표시 |
| `CA_COLOR_COPY=1` | CoreAnimation이 복사한 이미지에 시안 오버레이 |
| `CA_COLOR_NO_WAIT=1` | color-flush 후 10ms 대기 안함 |

| 장점 | 단점 |
|------|------|
| 트리 구조 확인 가능 | 애니메이션 파라미터 값 자체는 출력 안됨 |
| 렌더링 디버깅에 유용 | |

**참고**: [QuartzCore Debug Flags](https://github.com/avaidyam/QuartzInternal/blob/master/CoreAnimationPrivate/CADebug.h)

---

### 5.8. LLDB Symbolic Breakpoint

Xcode에서 Symbolic Breakpoint 설정:

```
Symbol: -[CALayer addAnimation:forKey:]
Action (Debugger Command):
  po $arg3
  po [$arg3 duration]
  po [$arg3 timingFunction]
```

`CASpringAnimation`인 경우:
```
po [$arg3 mass]
po [$arg3 stiffness]
po [$arg3 damping]
po [$arg3 initialVelocity]
po [$arg3 settlingDuration]
```

| 장점 | 단점 |
|------|------|
| 코드 수정 없이 디버깅 가능 | 디버거 연결 필요 |
| 모든 애니메이션 추가 시점 캡처 | 실행 속도 저하 |

**참고**: [LLDB Debugging - objc.io](https://www.objc.io/issues/19-debugging/lldb-debugging/)

---

### 5.9. DTrace (시뮬레이터 전용)

```bash
# SIP 비활성화 필요
sudo dtrace -n 'objc$target:CALayer:-addAnimation*:entry {
    printf("Animation added: %s\n", copyinstr(arg2));
}' -p <PID>
```

| 장점 | 단점 |
|------|------|
| 시뮬레이터에서 강력한 추적 | 실제 iOS 기기 불가 |
| 시스템 전체 함수 호출 추적 | SIP 비활성화 필요 |

**참고**: [DTrace - objc.io](https://www.objc.io/issues/19-debugging/dtrace/)

---

### 5.10. Jailbreak + Theos (가장 강력)

탈옥된 기기에서 SpringBoard/backboardd 직접 후킹:

```objc
// Tweak.x
%hook CASpringAnimation

- (void)setDamping:(double)damping {
    NSLog(@"[AnimCapture] damping: %f", damping);
    NSLog(@"[AnimCapture] mass: %f, stiffness: %f", self.mass, self.stiffness);
    %orig;
}

- (void)setStiffness:(double)stiffness {
    NSLog(@"[AnimCapture] stiffness: %f", stiffness);
    %orig;
}

%end
```

| 장점 | 단점 |
|------|------|
| 시스템 레벨 애니메이션 완전 캡처 | 탈옥(Jailbreak) 필요 |
| SpringBoard/backboardd 직접 후킹 | App Store 앱 불가 |

**참고**: [Theos Tweak Development](https://medium.com/@bancarel.paul/jailbreak-create-your-first-ios-tweak-version-67e8159c53f5)

---

### 5.11. Frida (탈옥 또는 디버그 빌드)

```javascript
// frida -U -n SpringBoard -l hook.js
var CASpringAnimation = ObjC.classes.CASpringAnimation;

Interceptor.attach(CASpringAnimation['- setDamping:'].implementation, {
    onEnter: function(args) {
        var self = new ObjC.Object(args[0]);
        console.log('=== CASpringAnimation ===');
        console.log('damping:', args[2]);
        console.log('mass:', self.mass());
        console.log('stiffness:', self.stiffness());
        console.log('initialVelocity:', self.initialVelocity());
    }
});
```

| 장점 | 단점 |
|------|------|
| 강력한 런타임 후킹 | SpringBoard 후킹은 탈옥 필요 |
| JavaScript로 스크립트 작성 | |
| 앱 프로세스는 디버그 빌드에서 가능 | |

**참고**: [Frida for iOS](https://fadeevab.com/quick-start-with-frida-to-reverse-engineer-any-ios-application/)

---

### 5.12. 시각적 분석 + 역산

화면 녹화 후 프레임별 분석으로 스프링 파라미터 역산:

1. 120fps(또는 240fps)로 화면 녹화
2. 프레임별 오브젝트 위치 측정
3. 스프링 운동 방정식에 대입하여 파라미터 추정

```
x(t) = A * e^(-ζωt) * cos(ωd*t + φ)

여기서:
- ζ (zeta) = damping ratio
- ω = sqrt(stiffness / mass)
- ωd = ω * sqrt(1 - ζ²)
```

| 장점 | 단점 |
|------|------|
| 어떤 환경에서든 적용 가능 | 정확도가 측정 정밀도에 의존 |
| 탈옥/디버그 빌드 불필요 | 복잡한 계산 필요 |

---

### 5.13. 방법 비교 요약표

| 방법 | 안전성 | 정확도 | 구현 난이도 | 제약사항 |
|------|--------|--------|------------|----------|
| 정적 분석 | ★★★ | - | 쉬움 | 모션 캡처 불가 |
| CADisplayLink 폴링 | ★★★ | ★★ | 중간 | 역추정 오차 |
| **지연 캡처 ★권장** | ★★★ | ★★★ | 쉬움 | 타이밍 의존 |
| 스위즐링 | ★★ | ★★★ | 중간 | 디버그 전용 |
| UIViewPropertyAnimator | ★★★ | ★★ | 쉬움 | 자체 animator만 |
| CAAnimationDelegate | ★★★ | ★ | 쉬움 | 보조 역할 |
| 환경변수 | ★★★ | ★ | 쉬움 | 파라미터 미출력 |
| LLDB Breakpoint | ★★★ | ★★★ | 쉬움 | 디버거 필요 |
| DTrace | ★★ | ★★★ | 중간 | 시뮬레이터만 |
| Theos | ★ | ★★★★ | 어려움 | 탈옥 필요 |
| Frida | ★★ | ★★★★ | 중간 | 탈옥/디버그 |
| 시각적 역산 | ★★★ | ★★ | 어려움 | 수작업 필요 |

---

## 6. iOS 시스템 기본 애니메이션 값

Apple 공식 문서 및 리버스 엔지니어링으로 알려진 기본값:

### 6.1. SwiftUI Animation Presets (iOS 17+)

| Preset | Duration | extraBounce | 특성 |
|--------|----------|-------------|------|
| `.smooth` | 0.5s | 0.0 | 바운스 없음 |
| `.snappy` | 0.5s | 0.0 | 약간의 바운스 |
| `.bouncy` | 0.5s | 0.0 | 큰 바운스 |

**커스텀 사용 예시**:
```swift
// 바운스 조절
.bouncy(duration: 0.4, extraBounce: 0.2)  // 적은 바운스
.bouncy(duration: 1.0, extraBounce: 0.6)  // 많은 바운스
```

**참고**: [Animation.bouncy - Apple Developer](https://developer.apple.com/documentation/swiftui/animation/bouncy(duration:extrabounce:))

### 6.2. UIKit Spring Animation 기본값

| 파라미터 | 기본값 | 설명 |
|---------|--------|------|
| `response` | 0.55 | 응답 시간 |
| `dampingFraction` | 0.825 | 감쇠 비율 |
| `blendDuration` | 0.0 | 블렌드 지속시간 |

### 6.3. CASpringAnimation 권장 시작값

| 파라미터 | 권장값 | 설명 |
|---------|--------|------|
| `mass` | 1.0 | 질량 |
| `stiffness` | 170 | 강성 (스프링 강도) |
| `damping` | 15 | 감쇠 (낮을수록 바운스) |
| `initialVelocity` | 0.0 | 초기 속도 |

**변형 예시**:
- 높은 바운스: `damping: 5, stiffness: 170`
- 빠른 응답: `stiffness: 300, damping: 20`

**참고**: [SwiftUI Spring Animations - GitHub](https://github.com/GetStream/swiftui-spring-animations)

### 6.4. iOS 26 Liquid Glass 모션 (알려진 값)

| 용도 | Animation | 비고 |
|------|-----------|------|
| GlassEffect morphing | `.bouncy` | GlassEffectContainer 내부 |
| Tab 전환 | Spring (시스템 기본) | UITabBar 내부 |
| Selection Pill 이동 | Spring | 커스텀 구현 시 참고 |

---

## 7. Private Core Animation API

### 7.1. QuartzInternal Repository

Core Animation Private API 헤더 파일 모음:

- **저장소**: [avaidyam/QuartzInternal](https://github.com/avaidyam/QuartzInternal)
- **주요 파일**:
  - [CADebug.h](https://github.com/avaidyam/QuartzInternal/blob/master/CoreAnimationPrivate/CADebug.h) - 디버그 플래그
  - [CAFilter.h](https://github.com/avaidyam/QuartzInternal/blob/master/CoreAnimationPrivate/CAFilter.h) - 필터 타입
  - [CAImageQueue.h](https://github.com/avaidyam/QuartzInternal/blob/master/CoreAnimationPrivate/CAImageQueue.h) - 이미지 큐

### 7.2. CAFilter 타입 (50+ 종류)

**색상 필터**: `ColorMatrix`, `ColorHueRotate`, `ColorSaturate`, `ColorBrightness`, `ColorContrast`, `ColorInvert`, `LuminanceToAlpha`, `ColorMonochrome`, `ColorAdd`, `ColorSubtract`

**블렌드 모드**: `Multiply`, `Screen`, `Overlay`, `SoftLight`, `HardLight`, `ColorDodge`, `ColorBurn`, `Darken`, `Lighten`, `Difference`, `Exclusion`, `Subtract`, `Divide`, `LinearBurn`, `LinearDodge`, `LinearLight`, `PinLight`

**특수 효과**: `GaussianBlur`, `VibrantDark`, `VibrantLight`, `PageCurl`, `Bias`, `DistanceField`, `LanczosResize`

**합성 모드**: `Clear`, `Copy`, `SourceOver`, `SourceIn`, `SourceOut`, `SourceAtop`, `Dest`, `DestOver`, `DestIn`, `DestOut`, `DestAtop`, `Xor`, `PlusL`, `PlusD`

### 7.3. iOS Runtime Headers

Objective-C 런타임에서 추출한 iOS 프레임워크 헤더:

- **저장소**: [nst/iOS-Runtime-Headers](https://github.com/nst/iOS-Runtime-Headers)
- **CASpringAnimation**: [CASpringAnimation.h](https://github.com/nst/iOS-Runtime-Headers/blob/master/Frameworks/QuartzCore.framework/CASpringAnimation.h)
- **CAPropertyAnimation**: [CAPropertyAnimation.h](https://github.com/nst/iOS-Runtime-Headers/blob/master/Frameworks/QuartzCore.framework/CAPropertyAnimation.h)

---

## 8. 참조 자료 링크

### 8.1. Apple 공식 문서

- [CASpringAnimation](https://developer.apple.com/documentation/quartzcore/caspringanimation)
- [UISpringTimingParameters](https://developer.apple.com/documentation/uikit/uispringtimingparameters)
- [UIViewPropertyAnimator](https://developer.apple.com/documentation/uikit/uiviewpropertyanimator)
- [CADisplayLink](https://developer.apple.com/documentation/quartzcore/cadisplaylink)
- [CAAnimationDelegate](https://developer.apple.com/documentation/quartzcore/caanimationdelegate)
- [CALayer.animationKeys](https://developer.apple.com/documentation/quartzcore/calayer/1410817-animationkeys)
- [CALayer.presentation](https://developer.apple.com/documentation/quartzcore/calayer/1410842-presentation)
- [Animation.bouncy](https://developer.apple.com/documentation/swiftui/animation/bouncy(duration:extrabounce:))
- [GlassEffectTransition](https://developer.apple.com/documentation/swiftui/glasseffecttransition)

### 8.2. WWDC 세션

- [WWDC 2014 Session 419 - Advanced Graphics and Animations for iOS Apps](https://asciiwwdc.com/2014/sessions/419)
- [WWDC 2024 - Enhance your UI animations and transitions](https://developer.apple.com/videos/play/wwdc2024/10145/)
- [WWDC 2025 - Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/)

### 8.3. iOS 렌더링 아키텍처

- [EthanArbuckle/ios-rendering-docs](https://github.com/EthanArbuckle/ios-rendering-docs) - iOS 렌더링 내부 문서
- [backboardd - The iPhone Wiki](https://www.theiphonewiki.com/wiki/Backboardd)
- [iOS Rendering the UI - Luke Parham](http://www.lukeparham.com/blog/2016/5/25/ios-rendering-the-ui)
- [Rendering performance of iOS apps - Medium](https://dmytro-anokhin.medium.com/rendering-performance-of-ios-apps-4d09a9228930)

### 8.4. Core Animation 내부

- [The Secret Life of Core Animation](https://avaidyam.github.io/2018/02/22/SecretLife_CoreAnimation.html)
- [DIY: Core Animation](https://avaidyam.github.io/2019/02/19/DIY-Core-Animation.html)
- [View-Layer Synergy - objc.io](https://www.objc.io/issues/12-animations/view-layer-synergy/)
- [Animating Custom Layer Properties - objc.io](https://www.objc.io/issues/12-animations/animating-custom-layer-properties/)

### 8.5. 디버깅 도구

- [DTrace - objc.io](https://www.objc.io/issues/19-debugging/dtrace/)
- [LLDB Debugging - objc.io](https://www.objc.io/issues/19-debugging/lldb-debugging/)
- [Chisel - Facebook LLDB Plugin](https://github.com/facebook/chisel)
- [FLEX - Flipboard Explorer](https://github.com/FLEXTool/FLEX)
- [DCIntrospect](https://github.com/domesticcatsoftware/DCIntrospect)

### 8.6. 리버스 엔지니어링

- [Frida for iOS](https://fadeevab.com/quick-start-with-frida-to-reverse-engineer-any-ios-application/)
- [frida-ios-hook](https://github.com/noobpk/frida-ios-hook)
- [frida-snippets](https://github.com/iddoeldor/frida-snippets)
- [Theos Tweak Development](https://medium.com/@bancarel.paul/jailbreak-create-your-first-ios-tweak-version-67e8159c53f5)
- [iOS Reverse Engineering - Apriorit](https://www.apriorit.com/dev-blog/how-to-reverse-engineer-an-ios-app)

### 8.7. iOS 26 Liquid Glass

- [LiquidGlassReference - GitHub](https://github.com/conorluddy/LiquidGlassReference)
- [iOS 26 Motion Design Guide - Medium](https://medium.com/@foks.wang/ios-26-motion-design-guide-key-principles-and-practical-tips-for-transition-animations-74def2edbf7c)
- [Adopting Liquid Glass - JuniperPhoton](https://juniperphoton.substack.com/p/adopting-liquid-glass-experiences)
- [Grow on iOS 26 - FatBobMan](https://fatbobman.com/en/posts/grow-on-ios26/)
- [iOS 26 Liquid Glass Comprehensive Reference - Medium](https://medium.com/@madebyluddy/overview-37b3685227aa)
- [Understanding GlassEffectContainer - DEV](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)
- [Liquid Glass morphing - GitHub Issue](https://github.com/onmyway133/blog/issues/997)

### 8.8. 스프링 애니메이션 참조

- [SwiftUI Spring Animations - GitHub](https://github.com/GetStream/swiftui-spring-animations)
- [iOS Animations: Layer Springs - Kodeco](https://www.kodeco.com/books/ios-animations-by-tutorials/v6.0/chapters/13-layer-springs)
- [JNWSpringAnimation - GitHub](https://github.com/jwilling/JNWSpringAnimation)
- [The Meaning, Maths, and Physics of SwiftUI Spring Animation - Medium](https://medium.com/@amosgyamfi/the-meaning-maths-and-physics-of-swiftui-spring-animation-amos-gyamfis-manifesto-0044755da208)
- [NSHipster: Method Swizzling](https://nshipster.com/method-swizzling/)

### 8.9. Private API / Runtime Headers

- [avaidyam/QuartzInternal](https://github.com/avaidyam/QuartzInternal) - Core Animation Private API
- [nst/iOS-Runtime-Headers](https://github.com/nst/iOS-Runtime-Headers) - iOS Runtime Headers
- [QuartzCore.framework - iPhone Dev Wiki](https://iphonedev.wiki/index.php/QuartzCore.framework)

### 8.10. 접근 실패 링크 (404/리다이렉트)

조사 과정에서 확인된 접근 불가 링크 (재조사 방지용):

- Core Animation Guide (AnimBasics): https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/AnimBasics/AnimBasics.html
- Core Animation Guide (AdvancedAnimation): https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/AdvancedAnimation/AdvancedAnimation.html
- Oleb.net presentation-layers (404): https://oleb.net/blog/2012/11/presentation-layers/

---

## 9. 결론 및 권장 접근법

### 9.1. 현실적으로 가능한 것

1. **앱 프로세스 내 애니메이션 캡처**: `CALayer.addAnimation` 스위즐링 또는 지연 캡처로 앱 내에서 생성되는 애니메이션 파라미터 추출
2. **Apple 공식 기본값 사용**: `.bouncy`, `.spring()` 등 공식 문서화된 값 활용
3. **시각적 분석**: 화면 녹화 후 프레임별 분석으로 역산

### 9.2. 완벽한 추출이 필요한 경우

- **탈옥 기기 + Theos/Frida**: 시스템 프로세스(SpringBoard, backboardd) 후킹
- **WWDC 세션 및 HIG 참조**: Apple이 공식적으로 제공하는 디자인 가이드라인

### 9.3. 최종 권장안

iOS 26 Liquid Glass 커스텀 구현 시:

| 우선순위 | 방법 | 설명 |
|---------|------|------|
| 1차 | Apple 공식 기본값 | `.bouncy`, `.spring()` 기본값 사용 |
| 2차 | 지연 캡처 | `SystemUIInspector`에 타이머 기능 추가 |
| 3차 | 스위즐링 | 지연 캡처로 부족할 때 |
| 4차 | 시각적 비교 | 미세 조정 |
| 참고 | Theos | 탈옥 기기 있으면 정확한 값 추출 |

### 9.4. 핵심 메시지

> **렌더 서버에서 처리되는 시스템 레벨 효과(굴절, 렌즈, morphing)는 근본적으로 앱에서 완벽히 캡처할 수 없습니다.**
> 공식 API(`UIGlassEffect`, `GlassEffectContainer`)를 사용하면 시스템이 자동으로 올바른 모션을 적용합니다.

---

## 10. 다음 단계 제안

### 10.1. SystemUIInspector 확장

`SystemUIInspector`에 **모션 캡처 모드** 추가:

1. **지연 캡처 모드**: "3초 후 캡처" 버튼 → 타이머 후 `animationKeys()` 스캔
2. **스위즐링 모드 (선택적)**: 디버그 빌드에서만 활성화

### 10.2. 덤프 포맷 정의 (JSON)

```json
{
  "captureTime": "2026-01-23T10:30:00Z",
  "captureMode": "delayed",
  "animations": [
    {
      "layerPath": "UIWindow > UIView > UITabBar > _UITabBarButton",
      "animationKey": "position",
      "animationType": "CASpringAnimation",
      "parameters": {
        "duration": 0.5,
        "mass": 1.0,
        "stiffness": 170,
        "damping": 15,
        "initialVelocity": 0,
        "settlingDuration": 0.8
      }
    }
  ]
}
```

### 10.3. 구현 우선순위

| 순서 | 작업 | 난이도 |
|------|------|--------|
| 1 | 지연 캡처 모드 추가 | 쉬움 |
| 2 | JSON 덤프 포맷 구현 | 쉬움 |
| 3 | 스위즐링 모드 추가 (선택) | 중간 |
| 4 | 결과 파일 저장 및 비교 도구 | 중간 |
