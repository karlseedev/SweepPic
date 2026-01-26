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

## 4. LLDB 명령어 정리

### 4.1. 전체 덤프 (핵심)

```lldb
# 모든 ivar (상속 포함)
po [view _ivarDescription]

# 모든 property 정의
po [[view class] _propertyDescription]

# 모든 메서드 (getter/setter 포함)
po [view _shortMethodDescription]
```

### 4.2. Swift 컨텍스트에서 사용

```lldb
# Objective-C 언어 지정
expression -l objc -O -- [view _ivarDescription]

# 또는 KVC 사용
po view.value(forKey: "_ivarDescription")
```

### 4.3. ~/.lldbinit 설정

```lldb
# 전체 ivar 덤프 단축
command alias ivars expression -l objc -O -- [%1 _ivarDescription]

# 전체 메서드 덤프 단축
command alias methods expression -l objc -O -- [%1 _shortMethodDescription]
```

---

## 5. class-dump (클래스 구조 파악)

### 5.1. 용도

- **조사 전**: Private 클래스에 어떤 속성이 있는지 **목록** 파악
- **조사 후**: `_ivarDescription` 결과와 비교하여 누락 확인

### 5.2. 사용법

```bash
# 설치
brew install class-dump

# UIKit Private 클래스 헤더 추출
class-dump /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore -H -o ~/Desktop/UIKit-headers

# 특정 클래스만
class-dump -C "_UITabBar.*" /path/to/UIKitCore -H -o ~/Desktop/tabbar-headers
```

### 5.3. 출력 예시 (`_UITabBarPlatterView.h`)

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

## 6. 다른 도구들의 역할

| 도구 | 역할 | LLDB 대비 |
|------|------|----------|
| **Reveal** | 뷰 찾기 편의성 | 시각적 탐색 |
| **Chisel** | 명령어 편의성 | `pviews` 한 줄 |
| **FLEX** | LLDB 없이 탐색 | 인앱 실시간 |
| **Accessibility Inspector** | SIP 없이 탐색 | 간편 접근 |

→ **완전성이 아닌 편의성** 도구

---

## 7. 참고 문서

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
