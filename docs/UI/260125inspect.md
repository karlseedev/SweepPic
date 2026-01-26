# iOS UI 속성 완전 조사 방법

**작성일**: 2026-01-25
**목표**: iOS 시스템 UI의 **모든 속성을 빠짐없이** 추출하는 핵심 방법

---

## 1. 핵심 결론

**LLDB `_ivarDescription` 하나로 모든 속성 조사 가능**

| 명령 | 용도 | 완전성 |
|------|------|--------|
| `po [view _ivarDescription]` | 모든 ivar 덤프 (상속 포함) | ★★★★★ |
| `po [view _shortMethodDescription]` | computed property 확인 | 보조 |
| `class-dump` | 클래스 구조 미리 파악 | 보조 |

---

## 2. `_ivarDescription` 검증 결과

### 2.1. 포함되는 것

| 항목 | 포함 여부 | 출력 예시 |
|------|----------|----------|
| 현재 클래스 ivar | ✅ | `_cornerRadius (double): 31` |
| 부모 클래스 ivar | ✅ | `in UIView: _layer (CALayer): ...` |
| Private ivar | ✅ | `_selectionIndicatorView (UIView): ...` |
| 타입 정보 | ✅ | `(double)`, `(UIView*)` |
| 현재 값 | ✅ | 실제 런타임 값 |

### 2.2. 출력 예시

```
<_UITabBarPlatterView: 0x123456>:
  in _UITabBarPlatterView:
    _backgroundView (UIView*): <UIView: 0x789>
    _contentView (UIView*): <UIView: 0xabc>
    _cornerRadius (double): 31
    _selectionIndicatorView (UIView*): <UIView: 0xdef>
  in UIView:
    _layer (CALayer*): <CALayer: 0x111>
    _backgroundColor (UIColor*): UIExtendedGrayColorSpace 0.1 0.12
    _alpha (double): 1.0
  in UIResponder:
    ...
  in NSObject:
    isa (Class): _UITabBarPlatterView
```

→ **상속 계층 전체의 모든 ivar가 자동으로 나열됨**

### 2.3. 유일한 예외

| 예외 | 설명 |
|------|------|
| backing ivar 없는 computed property | getter만 있고 저장소 없음 |

**하지만**: UIKit Private 클래스들은 대부분 backing ivar가 있음 (값 저장 필요)

**확인 방법**: `_shortMethodDescription`으로 getter/setter 목록 확인

---

## 3. 조사 워크플로우

### 3.1. 준비 단계

```bash
# 1. SIP 비활성화 (시스템 앱 조사 시)
# 복구 모드에서: csrutil disable

# 2. class-dump로 Private 클래스 구조 파악 (선택)
brew install class-dump
class-dump /path/to/UIKitCore -H -o ~/Desktop/UIKit-headers
```

### 3.2. 조사 단계

```bash
# 1. Photos 앱 실행
xcrun simctl launch booted com.apple.mobileslideshow

# 2. LLDB attach
lldb
(lldb) process attach --name MobileSlideShow --waitfor
```

```lldb
# 3. 전체 뷰 계층에서 원하는 뷰 찾기
po [[UIWindow keyWindow] recursiveDescription]

# 4. 해당 뷰의 모든 속성 덤프
po [(UIView *)0x주소 _ivarDescription]

# 5. (선택) computed property 확인
po [(UIView *)0x주소 _shortMethodDescription]
```

### 3.3. 특정 속성 상세 조회

`_ivarDescription`에서 값이 "Value not representable"로 나오거나 더 상세히 보고 싶을 때:

```lldb
# UIColor 분해
expression -l objc -O -- @import UIKit; CGFloat w,a; [[(UIView *)0x주소 backgroundColor] getWhite:&w alpha:&a]; NSLog(@"White:%.3f Alpha:%.3f", w, a)

# CALayer 속성
po [(UIView *)0x주소 layer].cornerCurve
po [(UIView *)0x주소 layer].shadowOpacity
```

---

## 4. 앱 내 디버그 버튼 방식 (권장)

LLDB 직접 사용 없이, 앱 내에서 버튼으로 속성 덤프를 수행하는 방법.

### 4.1. 장점

| 항목 | LLDB 직접 | 앱 내 버튼 |
|------|----------|-----------|
| SIP 비활성화 | 시스템 앱 시 필요 | **불필요** |
| LLDB 숙련도 | 필요 | **불필요** |
| 여러 화면 조사 | 매번 주소 찾기 | **버튼만 누르면 됨** |
| 결과 저장 | 수동 복사 | **자동 파일 저장** |

### 4.2. 원리

`_ivarDescription`은 Objective-C 런타임 메서드라서 앱 코드에서도 호출 가능:

```swift
// perform(Selector)로 private 메서드 호출 - LLDB와 100% 동일
let selector = Selector(("_ivarDescription"))
let desc = view.perform(selector)?.takeUnretainedValue() as? String
```

> **주의**: `value(forKey:)`는 KVC 규칙을 따르므로 동작이 다를 수 있음. `perform(Selector)` 사용 권장.

### 4.3. 구현 파일

#### 신규 생성 파일 (권장)

| 파일 | 용도 |
|------|------|
| `PickPhoto/PickPhoto/Debug/SystemUIInspector2.swift` | `_ivarDescription` 기반 완전 덤프 |

#### 기존 파일 (참고용, 불완전)

| 파일 | 용도 | 비고 |
|------|------|------|
| `PickPhoto/PickPhoto/Debug/SystemUIInspector.swift` | CALayer 속성 수동 덤프 | `_ivarDescription` 미사용, 속성 누락 가능 |

> **주의**: 기존 `SystemUIInspector.swift`는 `class_copyIvarList` + 수동 필터링 방식이라 속성 누락 발생.
> 새로 만든 `SystemUIInspector2.swift`는 `_ivarDescription`으로 상속 포함 모든 ivar 자동 덤프.

### 4.4. 활성화 방법

**SceneDelegate.swift**의 `showMainInterface()` 함수 끝에 추가:

```swift
// PickPhoto/PickPhoto/App/SceneDelegate.swift - showMainInterface() 함수 내

// UI 속성 조사용 디버그 버튼 (260125inspect.md 참고)
#if DEBUG
SystemUIInspector2.shared.showDebugButton()
#endif
```

### 4.5. 사용 방법

1. **디버그 빌드**로 앱 실행 (iOS 26 시뮬레이터)
2. 조사할 화면으로 이동 (그리드, 뷰어, 유사사진 등)
3. 화면 가운데 **🔬 Full Dump 버튼** 탭
4. 덤프 완료 알림 확인
5. 저장된 파일 확인

### 4.6. 저장 파일 위치

```bash
# 시뮬레이터 Documents 폴더
open $(xcrun simctl get_app_container booted com.pickphoto.app data)/Documents/

# 또는 앱 내 Files 앱에서 확인 가능
```

저장 파일 (2개):
- `ui_dump_[타임스탬프]_[번호]_filtered.txt` - UI 관련 속성만 (주로 볼 파일)
- `ui_dump_[타임스탬프]_[번호]_full.txt` - 전체 ivar (누락 대비)

### 4.7. 조사 대상 뷰

자동으로 다음 클래스명 패턴을 포함하는 뷰를 찾아 덤프:

| 패턴 | 매칭 예시 |
|------|----------|
| `UITabBar` | UITabBar |
| `UINavigationBar` | UINavigationBar |
| `UIToolbar` | UIToolbar |
| `_UITabBarPlatterView` | _UITabBarPlatterView |
| `_UITabBarItemView` | _UITabBarItemView |
| `_UINavigationBarBackground` | _UINavigationBarBackground |
| `_UIBarBackground` | _UIBarBackground |
| `PlatterView` | _UITabBarPlatterView 등 |
| `GlassView` | _UIClearGlassView 등 |
| `LiquidGlass` | _UILiquidGlassView 등 |
| `UICollectionView` | UICollectionView |

### 4.8. 주의사항

- **#if DEBUG** 전용 - 릴리스 빌드에서 자동 제외
- Private API 사용 - App Store 제출 시 문제 없음 (디버그 전용이므로)
- 기존 `SystemUIInspector.swift`는 삭제하지 않음 (이전 조사 결과 참고용)

---

## 5. LLDB 명령어 정리

### 5.1. 전체 덤프 (핵심)

```lldb
# 모든 ivar (상속 포함)
po [view _ivarDescription]

# 모든 property 정의
po [[view class] _propertyDescription]

# 모든 메서드 (getter/setter 포함)
po [view _shortMethodDescription]
```

### 5.2. Swift 컨텍스트에서 사용

```lldb
# Objective-C 언어 지정
expression -l objc -O -- [view _ivarDescription]

# 또는 KVC 사용
po view.value(forKey: "_ivarDescription")
```

### 5.3. ~/.lldbinit 설정

```lldb
# 전체 ivar 덤프 단축
command alias ivars expression -l objc -O -- [%1 _ivarDescription]

# 전체 메서드 덤프 단축
command alias methods expression -l objc -O -- [%1 _shortMethodDescription]
```

---

## 6. class-dump (클래스 구조 파악)

### 6.1. 용도

- **조사 전**: Private 클래스에 어떤 속성이 있는지 **목록** 파악
- **조사 후**: `_ivarDescription` 결과와 비교하여 누락 확인

### 6.2. 사용법

```bash
# 설치
brew install class-dump

# UIKit Private 클래스 헤더 추출
class-dump /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore -H -o ~/Desktop/UIKit-headers

# 특정 클래스만
class-dump -C "_UITabBar.*" /path/to/UIKitCore -H -o ~/Desktop/tabbar-headers
```

### 6.3. 출력 예시 (`_UITabBarPlatterView.h`)

```objc
@interface _UITabBarPlatterView : UIView {
    UIView *_backgroundView;
    UIView *_contentView;
    UIView *_selectionIndicatorView;
    double _cornerRadius;
    // ... 모든 ivar
}

@property (nonatomic) double cornerRadius;
@property (nonatomic, retain) UIView *selectionIndicatorView;
// ... 모든 property

- (void)setCornerRadius:(double)arg1;
- (double)cornerRadius;
// ... 모든 메서드
@end
```

---

## 7. 다른 도구들의 역할

| 도구 | 역할 | LLDB 대비 |
|------|------|----------|
| **Reveal** | 뷰 찾기 편의성 | 시각적 탐색 |
| **Chisel** | 명령어 편의성 | `pviews` 한 줄 |
| **FLEX** | LLDB 없이 탐색 | 인앱 실시간 |
| **Accessibility Inspector** | SIP 없이 탐색 | 간편 접근 |

→ **완전성이 아닌 편의성** 도구

---

## 8. 참고 문서

### Private 디버깅 메서드
- [Apple Forums - Debugging all properties](https://developer.apple.com/forums/thread/121628)
- [mr-v.github.io - LLDB debugging with private APIs](https://mr-v.github.io/lldb-debugging-views-with-private-apis-in-swift)
- [objc.io - Dancing in the Debugger](https://www.objc.io/issues/19-debugging/lldb-debugging/)

### LLDB 스크립트
- [DerekSelander/LLDB](https://github.com/DerekSelander/LLDB)
- [chenhuimao/HMLLDB](https://github.com/chenhuimao/HMLLDB)

### class-dump
- [GitHub - nygard/class-dump](https://github.com/nygard/class-dump)
- [GitHub - limneos/classdump-dyld](https://github.com/limneos/classdump-dyld)

### Runtime API
- [Apple - class_copyIvarList](https://developer.apple.com/documentation/objectivec/1418910-class_copyivarlist)
- [ko9.org - Inspecting Objective-C Properties](https://ko9.org/posts/inspecting-objective-c-properties/)
