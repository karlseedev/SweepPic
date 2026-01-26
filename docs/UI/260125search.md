# iOS UI 속성 조사 방법 종합 자료

**작성일**: 2026-01-25
**목표**: iOS 26 시스템 UI(Photos 앱 TabBar 등)의 정확한 디자인 속성(크기, 색상, 폰트, alpha, cornerCurve 등)을 추출하여 커스텀 구현에 반영하기 위한 종합 기술 자료

---

## 0. Executive Summary

### 핵심 결론
1. **정적 속성(frame, cornerRadius 등)은 비교적 쉽게 추출 가능** — LLDB, Reveal, Accessibility Inspector 등 다양한 도구 활용
2. **색상/alpha 세부값은 추가 작업 필요** — UIColor 분해 메서드 호출 또는 픽셀 레벨 측정
3. **시스템 앱(Photos 등) 디버깅은 SIP 비활성화 필요** — macOS 시뮬레이터 환경에서만 가능

### 기존 조사 방식의 문제점
`SystemUIInspector`를 사용한 정적 분석에서 다음 속성들이 누락됨:
- `layer.cornerCurve` (circular vs continuous)
- `UILabel.font.pointSize`
- `UIImageView`의 SF Symbol configuration (pointSize)
- 색상의 gray/alpha 분리 값
- 비선택 상태의 `alpha` 값
- Platter 자체의 cornerRadius/cornerCurve

### 미실측 항목 현황

| # | 항목 | 현재 값 | 실측 상태 |
|---|------|---------|----------|
| 4 | capsulePadding | 16pt | 미실측 |
| 8 | tabIconSize (pointSize) | 24pt | 미실측 |
| 11 | 레이블 폰트 크기 | 11pt | 미실측 |
| 12 | 배경 gray | 0.1 | 미실측 |
| 13 | backgroundAlpha | 0.12 | 미실측 |
| 14 | 비선택 아이콘 alpha | 0.65 | 미실측 |
| 15 | Platter cornerCurve | circular (기본) | 미실측 |
| 16 | maxDimAlpha | 0.45 | 미실측 |

---

## 1. 조사 방법 종합 비교 (완전성 순위)

오브젝트의 모든 속성을 빠짐없이 조사할 가능성이 높은 순서:

| 순위 | 방법 | 완전성 | 난이도 | 시스템앱 | 핵심 장점 |
|------|------|--------|--------|---------|----------|
| 1 | **LLDB 직접 명령** | ★★★★★ | ★★★ | ⚠️ SIP | `_ivarDescription`으로 **전체 자동 덤프** |
| 2 | **class-dump** | ★★★★★ | ★★☆ | ✅ | Private 클래스 **모든 속성 목록** 추출 |
| 3 | **Reveal** | ★★★★☆ | ★★☆ | ⚠️ 주입 | 시각적 + 상세 속성 |
| 4 | **Chisel (Facebook)** | ★★★★☆ | ★★☆ | ⚠️ SIP | pviews 계층 + 시각화 |
| 5 | **FLEX** | ★★★☆☆ | ★☆☆ | ❌ | 인앱 실시간 탐색 |
| 6 | **Xcode View Debugger** | ★★★☆☆ | ★☆☆ | ❌ | 통합 환경, 3D 뷰 |
| 7 | **Accessibility Inspector** | ★★☆☆☆ | ★☆☆ | ✅ | SIP 불필요, 시스템앱 OK |
| 8 | **Digital Color Meter** | ★★☆☆☆ | ★☆☆ | ✅ | 픽셀 색상 정확 측정 |
| 9 | **스크린샷 분석** | ★★☆☆☆ | ★★☆ | ✅ | 크기/간격 측정 |

---

## 2. 조사 방법 상세 (완전성 순서)

### 2.1. LLDB 직접 명령 (1위) ★★★★★

#### 완전성 근거
- **전체 자동 덤프 가능**: `_ivarDescription`으로 객체의 **모든 ivar를 한번에** 추출
- **모든 Public/Private 속성 조회 가능**: 객체의 어떤 속성이든 `po`, `p`, `expression` 명령으로 직접 접근
- **메서드 호출 가능**: `getRed:green:blue:alpha:`, `getWhite:alpha:` 등 런타임 메서드 실행
- **KVC 접근 가능**: `value(forKey:)`로 private 속성도 조회
- **레이어 속성 완전 접근**: `cornerCurve`, `shadowOpacity`, `mask` 등 CALayer 모든 속성

#### 제한사항
- 시스템 앱(Photos 등) 디버깅 시 SIP 비활성화 필요
- 숙련도에 따라 시간 소요

#### 참고 문서
- [Hacking with Swift - recursiveDescription](https://www.hackingwithswift.com/articles/101/how-to-debug-your-view-hierarchy-using-recursivedescription)
- [objc.io - Dancing in the Debugger](https://www.objc.io/issues/19-debugging/lldb-debugging/)
- [Medium - Inspecting Visual Elements with LLDB](https://medium.com/swlh/inspecting-and-changing-visual-elements-with-lldb-and-view-debugger-8b582258217b)
- [Medium - UI Debugging with LLDB](https://medium.com/better-programming/how-to-take-ui-debugging-to-the-next-level-with-lldb-e9f43f60d6e9)
- [tanaschita - Understanding LLDB print commands](https://tanaschita.com/20220711-understanding-lldb-print-commands-for-ios-debugging-with-xcode/)
- [WWDC 2024 - Run, Break, Inspect: LLDB](https://developer.apple.com/videos/play/wwdc2024/10198/)
- [WWDC 2018 - Advanced Debugging with Xcode and LLDB](https://developer.apple.com/videos/play/wwdc2018/412/)

#### 기본 명령어

```lldb
# 전체 뷰 계층 출력
po [[UIWindow keyWindow] recursiveDescription]

# 뷰 컨트롤러 계층 (Private API)
po [[[UIWindow keyWindow] rootViewController] _printHierarchy]

# Auto Layout 트레이스 (Private API)
po [[UIWindow keyWindow] _autolayoutTrace]
```

#### Swift 프레임에서 Objective-C 구문 사용

```lldb
# 방법 1: 언어 지정
expr -l objc++ -O -- [[UIWindow keyWindow] recursiveDescription]

# 방법 2: KVC 사용
po yourView.value(forKey: "recursiveDescription")!
```

#### 개별 속성 조회 명령어

```lldb
# === CALayer 속성 ===
po view.layer.cornerRadius
po view.layer.cornerCurve           # .circular 또는 .continuous
po view.layer.shadowColor
po view.layer.shadowOpacity
po view.layer.shadowRadius
po view.layer.shadowOffset
po view.layer.masksToBounds
po view.layer.mask
po view.layer.borderWidth
po view.layer.borderColor

# === UIView 속성 ===
po view.alpha
po view.isHidden
po view.backgroundColor
po view.tintColor
po view.frame
po view.bounds

# === UIColor 분해 ===
# Objective-C 스타일
expression -l objc -O -- @import UIKit; CGFloat r,g,b,a; [[view backgroundColor] getRed:&r green:&g blue:&b alpha:&a]; NSLog(@"R:%.2f G:%.2f B:%.2f A:%.2f", r, g, b, a)

# Gray + Alpha 분해
expression -l objc -O -- @import UIKit; CGFloat w,a; [[view backgroundColor] getWhite:&w alpha:&a]; NSLog(@"White:%.2f Alpha:%.2f", w, a)

# === UIFont 속성 ===
po label.font
po label.font.pointSize
po label.font.fontName
po button.titleLabel.font.pointSize

# === SF Symbol 설정 ===
po imageView.image
po imageView.image.symbolConfiguration

# === alpha 값 ===
po view.alpha
po imageView.alpha
po button.alpha
```

#### 전체 덤프 명령어 (모든 속성 자동 추출) ★핵심

개별 속성을 하나씩 조회하는 대신, **객체의 모든 속성을 한번에 덤프**:

```lldb
# 객체의 모든 ivar (instance variable) 덤프
po [view _ivarDescription]

# 클래스의 모든 property 덤프
po [[view class] _propertyDescription]

# 클래스의 모든 메서드 덤프
po [view _shortMethodDescription]

# 클래스 구조 상세 (ivar offset 포함)
language objc class-table dump _UITabBarPlatterView -v
```

**출력 예시 (`_ivarDescription`):**
```
<_UITabBarPlatterView: 0x123456>:
  _backgroundView (UIView): <UIView: 0x789>
  _contentView (UIView): <UIView: 0xabc>
  _cornerRadius (double): 31
  _selectionIndicatorView (UIView): <UIView: 0xdef>
  ...모든 ivar가 자동으로 나열됨...
```

**참고 문서:**
- [Apple Forums - Debugging all properties](https://developer.apple.com/forums/thread/121628)
- [DerekSelander/LLDB](https://github.com/DerekSelander/LLDB)

#### LLDB 확장 스크립트 (DerekSelander/LLDB)

더 강력한 덤프 기능을 위한 스크립트 모음:

```bash
# 설치
git clone https://github.com/DerekSelander/LLDB.git ~/LLDB
echo "command script import ~/LLDB/lldb_commands/dslldb.py" >> ~/.lldbinit
```

```lldb
# 인스턴스의 모든 ivar 값 덤프 (상속 포함)
ivars <view_address>

# 클래스 구조 상세 덤프 (class-dump 스타일)
dclass -i _UITabBarPlatterView

# 더 상세한 정보
dclass -I _UITabBarPlatterView
```

---

#### ~/.lldbinit 설정 (자주 쓰는 명령 단축)

```lldb
# 뷰 계층 출력 단축
command alias pviews expr -l objc++ -O -- [[UIWindow keyWindow] recursiveDescription]

# VC 계층 출력 단축
command alias pvcs expr -l objc++ -O -- [[[UIWindow keyWindow] rootViewController] _printHierarchy]

# 전체 ivar 덤프 단축
command alias ivardump expr -l objc -O -- [%1 _ivarDescription]

# 전체 property 덤프 단축
command alias propdump expr -l objc -O -- [[%1 class] _propertyDescription]
```

---

### 2.2. Reveal (2위) ★★★★☆

#### 완전성 근거
- **시각적 3D 뷰 계층**: 뷰 간 관계 직관적 파악
- **상세 속성 패널**: frame, bounds, layer 속성, constraints 모두 표시
- **실시간 편집**: 속성 값 즉시 수정하여 결과 확인
- **제약조건 시각화**: Auto Layout 문제 진단

#### 제한사항
- 유료 앱 ($59.99)
- 시스템 앱은 dylib 주입 필요 (탈옥 또는 LLDB 주입)

#### 참고 문서
- [Reveal App 공식](https://revealapp.com/)
- [Kodeco - Reveal Tutorial](https://www.kodeco.com/1863-reveal-tutorial-live-view-debugging)
- [Cocoacasts - View Debugging with Reveal](https://cocoacasts.com/view-debugging-with-reveal)
- [Cocoacasts - Debugging Applications with Reveal](https://cocoacasts.com/debugging-applications-with-reveal)
- [Zdziarski - Injecting Reveal with MobileSubstrate](https://www.zdziarski.com/blog/?p=2361)
- [GitHub - Reveal3Loader](https://github.com/divyeshmakwana96/Reveal3Loader)

#### LLDB를 통한 Reveal 주입

```lldb
# Reveal 라이브러리 로드 및 서버 시작
expr (Class)NSClassFromString(@"IBARevealLoader") == nil ? (void *)dlopen("/Applications/Reveal.app/Contents/SharedSupport/iOS-Libraries/libReveal.dylib", 0x2) : ((void*)0); [(NSNotificationCenter*)[NSNotificationCenter defaultCenter] postNotificationName:@"IBARevealRequestStart" object:nil];
```

#### ~/.lldbinit에 매크로 추가

```lldb
command alias reveal_load expr (Class)NSClassFromString(@"IBARevealLoader") == nil ? (void *)dlopen("/Applications/Reveal.app/Contents/SharedSupport/iOS-Libraries/libReveal.dylib", 0x2) : ((void*)0)
command alias reveal_start expr [(NSNotificationCenter*)[NSNotificationCenter defaultCenter] postNotificationName:@"IBARevealRequestStart" object:nil]
```

---

### 2.3. Chisel - Facebook LLDB 확장 (3위) ★★★★☆

#### 완전성 근거
- **pviews 명령**: recursiveDescription보다 가독성 좋은 출력
- **border 명령**: 뷰 위치 시각적 확인
- **visualize 명령**: 뷰를 이미지로 Mac Preview에서 열기
- **LLDB와 완전 통합**: 추가 속성 조회와 조합 가능

#### 제한사항
- 설치 필요 (brew install chisel)
- LLDB 환경에서만 동작

#### 참고 문서
- [GitHub - facebook/chisel](https://github.com/facebook/chisel)
- [Chisel Wiki](https://github.com/facebook/chisel/wiki)
- [Chisel README](https://github.com/facebook/chisel/blob/main/README.md)
- [Kapeli - LLDB Chisel Commands Cheat Sheet](https://kapeli.com/cheat_sheets/LLDB_Chisel_Commands.docset/Contents/Resources/Documents/index)
- [Minsone - Debugging with Xcode, LLDB and Chisel](https://minsone.github.io/ios/mac/xcode-lldb-debugging-with-xcode-lldb-and-chisel)
- [Rool Productions - Chisel on Steroids](https://roolproductions.com/chisel-your-debugger-on-steroids/)

#### 설치

```bash
# Homebrew로 설치
brew install chisel

# ~/.lldbinit에 추가
command script import /opt/homebrew/opt/chisel/libexec/fbchisellldb.py
```

#### 주요 명령어

```lldb
# 뷰 계층 출력
pviews

# 특정 뷰부터 상위만
pviews --up <view>

# 깊이 제한
pviews --depth 3

# 뷰 컨트롤러 계층
pvc

# 뷰에 테두리 추가 (시각화)
border <view> --color red --width 2

# 재귀적으로 하위 뷰에도 테두리
border <view> --color blue --width 1 --depth 3

# 테두리 제거
unborder <view>

# 뷰를 Preview.app에서 열기
visualize <view>

# Ambiguous Layout 뷰에 테두리
alamborder

# Ambiguous Layout 테두리 제거
alamunborder

# 특정 클래스 인스턴스 찾기
fvc UINavigationController

# 응답자 체인 출력
presponder <view>
```

---

### 2.4. FLEX (4위) ★★★☆☆

#### 완전성 근거
- **인앱 실시간 탐색**: LLDB 연결 없이 동작
- **힙 스캔**: 메모리의 모든 객체 탐색 가능
- **속성 편집**: 실시간으로 값 변경 및 확인
- **파일 시스템/DB 탐색**: 앱 데이터 확인

#### 제한사항
- **자체 앱에만 통합 가능** — 시스템 앱 분석 불가
- Private 속성 일부 누락 가능

#### 참고 문서
- [GitHub - FLEXTool/FLEX](https://github.com/FLEXTool/FLEX)
- [Flipboard - Introducing FLEX](https://about.flipboard.com/engineering/flex/)
- [iosexample - FLEX](https://iosexample.com/an-in-app-debugging-and-exploration-tool-for-ios/)
- [onejailbreak - FLEXall](https://onejailbreak.com/blog/flexall-ios/)
- [Dmytro Anokhin - Developer Tools for UI Debugging](https://dmytro-anokhin.medium.com/overview-of-developer-tools-for-ui-debugging-122e4995f972)

#### 통합 방법

```swift
// Package.swift 또는 CocoaPods
// pod 'FLEX', :configurations => ['Debug']

#if DEBUG
import FLEX

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions...) -> Bool {
        // 상태바 길게 누르면 FLEX 활성화
        FLEXManager.shared.showExplorer()
        return true
    }
}
#endif
```

#### 주요 기능
- **Select 모드**: 화면 탭하여 뷰 선택
- **Views 탭**: 뷰 계층 트리 탐색
- **Menu 탭**: 앱 정보, 파일 시스템, 네트워크 로그
- **속성 편집**: 선택한 객체의 속성 실시간 수정

---

### 2.5. Xcode View Debugger (5위) ★★★☆☆

#### 완전성 근거
- **통합 환경**: 별도 도구 설치 불필요
- **3D 뷰 계층**: 시각적으로 뷰 간 관계 파악
- **Object Inspector**: 선택한 뷰의 속성 표시
- **Size Inspector**: frame, bounds, constraints 확인

#### 제한사항
- **자체 앱만 분석 가능**
- 일부 layer 속성(cornerCurve 등) 표시 안됨
- LLDB만큼 상세하지 않음

#### 참고 문서
- [dasdom.dev - View Debugger in Xcode](https://dasdom.dev/the-view-debugger-in-xcode/)
- [Kodeco - View Debugging in Xcode 6](https://www.kodeco.com/1879-view-debugging-in-xcode-6)
- [Stable Kernel - Xcode 6's View Debugger](https://stablekernel.com/xcode-6s-view-debugger/)
- [Apple - Auto Layout Debugging](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/AutolayoutPG/DebuggingTricksandTips.html)

#### 사용법
1. 앱 실행 중 Debug > View Debugging > Capture View Hierarchy
2. 또는 Debug Bar의 View Hierarchy 버튼 클릭
3. 3D 뷰에서 레이어 분리하여 탐색
4. 우측 Inspector에서 속성 확인

---

### 2.6. Accessibility Inspector (6위) ★★☆☆☆

#### 완전성 근거
- **시스템 앱 포함 모든 앱 분석 가능**
- **SIP 비활성화 불필요**
- **뷰 계층 탐색 지원** (⌃⌘ + 화살표)
- **frame 정보 제공**

#### 제한사항
- 접근성 속성 중심 (layer 속성은 제공 안함)
- cornerRadius, alpha, font 등 세부 속성 부족

#### 참고 문서
- [Apple - Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility-inspector)
- [Apple - Inspecting Accessibility of Screens](https://developer.apple.com/documentation/accessibility/inspecting-the-accessibility-of-screens)
- [Medium - Accessibility Inspector Deep Dive](https://medium.com/@crissyjoshua/ios-simulator-accessibility-inspector-a-deep-dive-6b6f9fa5fe18)
- [Medium - 3 Tools for Accessible iOS Apps](https://medium.com/@lauriemarceau/3-tools-to-help-you-develop-accessible-ios-apps-15fe9545b588)
- [Deque - Intro to Accessibility Inspector](https://www.deque.com/blog/intro-accessibility-inspector-tool-ios-native-apps/)
- [BrowserStack - Accessibility Inspector for iOS](https://www.browserstack.com/guide/accessibility-inspector-ios)

#### 실행 방법
```
Xcode > Open Developer Tool > Accessibility Inspector
```

#### 주요 기능
- **Target Selector**: Mac, Simulator, 연결된 기기 선택
- **Inspection Pointer**: 화면 요소 가리키면 정보 표시
- **계층 탐색**: ⌃⌘ + 화살표로 부모/자식/형제 이동
- **Audit**: 접근성 문제 자동 검사

#### 표시되는 정보
- Label, Traits, Hint, Identifier, Value
- Frame (CGRect 형식)
- 접근성 계층 구조

---

### 2.7. Digital Color Meter (7위) ★★☆☆☆

#### 완전성 근거
- **픽셀 레벨 정확도**: 화면에 보이는 실제 색상 측정
- **시스템 앱 포함 모든 화면 측정 가능**
- **SIP 불필요**

#### 제한사항
- **alpha 값 직접 측정 불가** — 배경과 합성된 결과만 보임
- 색상 정보만 제공 (크기, 폰트 등 불가)

#### 참고 문서
- [Apple Support - Digital Color Meter Guide](https://support.apple.com/guide/digital-color-meter/welcome/mac)
- [iDownloadBlog - Find RGB or Hex value](https://www.idownloadblog.com/2016/05/23/find-rgb-hexadecimal-value-mac/)
- [How-To Geek - Find Color Value on Mac](https://www.howtogeek.com/228506/how-to-find-the-color-value-for-anything-on-your-macs-screen/)
- [Ask Dave Taylor - Identify RGB Color](https://www.askdavetaylor.com/how-to-identify-rgb-color-on-screen-with-digital-color-meter/)
- [La De Du - Pick Screen Colors](https://ladedu.com/how-to-identify-the-color-of-any-pixel-on-screen-with-macos/)
- [Alvin Alexander - DigitalColor Meter](https://alvinalexander.com/blog/post/mac-os-x/digitalcolor-meter-utility/)
- [XDA - How to use Digital Color Meter](https://www.xda-developers.com/how-use-digital-color-meter-macos/)

#### 실행 방법
```
응용 프로그램 > 유틸리티 > Digital Color Meter
```

#### 사용법
1. 드롭다운에서 색상 공간 선택 (Display in sRGB 권장)
2. View > Display Values > Decimal 또는 Hexadecimal
3. 마우스 포인터를 측정할 픽셀 위에 놓기
4. ⌘L: 현재 위치 잠금
5. ⇧⌘C: Hex 값 클립보드에 복사
6. ⌥⌘C: 색상 스와치를 이미지로 복사

#### Aperture Size 설정
- 가장 작게 설정하면 단일 픽셀 측정
- 크게 설정하면 영역 평균값

#### alpha 값 역산 방법
```
# 흰색 배경(255,255,255)에서 측정한 RGB = (r1, g1, b1)
# 검정 배경(0,0,0)에서 측정한 RGB = (r2, g2, b2)
# alpha = r2 / r1 (R 채널 기준, 단색일 경우)

# 또는 Gray 색상의 경우:
# measured_gray = original_gray * alpha + background_gray * (1 - alpha)
```

---

### 2.8. 스크린샷 기반 분석 (8위) ★★☆☆☆

#### 완전성 근거
- **픽셀 단위 크기 측정 가능**
- **시스템 앱 포함 모든 화면 분석 가능**
- **증거 자료로 보존 가능**

#### 제한사항
- 수동 측정 필요
- 속성값(alpha, cornerRadius 등) 직접 확인 불가
- scale factor 고려 필요

#### 도구
- **Preview.app**: Tools > Show Inspector (⌘I) + 선택 도구
- **Pixelmator / Photoshop**: 정밀 측정
- **Figma / Sketch**: 디자인 비교

#### 픽셀 밀도 변환
```
실제 pt 값 = 측정 픽셀 / scale factor

Scale factors:
- @1x: 1 (구형 기기)
- @2x: 2 (iPhone 8, SE 등)
- @3x: 3 (iPhone 12 Pro 이상)
```

---

### 2.9. class-dump (Private 클래스 헤더 추출) ★★★★☆

#### 완전성 근거
- **Private 클래스의 모든 속성/메서드 목록 추출**: `_UITabBarPlatterView`, `_UIBarBackground` 등
- **오프라인 분석 가능**: 헤더 파일로 추출하여 편하게 탐색
- **UIKit 전체 Private API 파악 가능**

#### 제한사항
- **정적 분석**: 런타임 값은 확인 불가 (구조만 파악)
- 시뮬레이터/Xcode SDK 기준 (실제 기기와 다를 수 있음)

#### 참고 문서
- [GitHub - nygard/class-dump](https://github.com/nygard/class-dump)
- [GitHub - limneos/classdump-dyld](https://github.com/limneos/classdump-dyld)
- [Enharmonic - iOS Reverse Engineering Tutorial](http://www.enharmonichq.com/tutorial-ios-reverse-engineering-class-dump-hopper-dissasembler/)
- [dsdump - Building a class-dump](https://derekselander.github.io/dsdump/)

#### 설치

```bash
brew install class-dump
```

#### 사용법

```bash
# UIKit에서 모든 Private 클래스 헤더 추출
class-dump /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore -H -o ~/Desktop/UIKit-headers

# 특정 클래스만 추출
class-dump -C "_UITabBar.*" /path/to/UIKitCore -H -o ~/Desktop/tabbar-headers

# 결과 확인
ls ~/Desktop/UIKit-headers | grep -i tabbar
# _UITabBarPlatterView.h
# _UITabBarButton.h
# _UIBarBackground.h
# ...
```

#### 출력 예시 (`_UITabBarPlatterView.h`)

```objc
@interface _UITabBarPlatterView : UIView
{
    UIView *_backgroundView;
    UIView *_contentView;
    UIView *_selectionIndicatorView;
    double _cornerRadius;
    // ... 모든 ivar 나열
}

@property (nonatomic) double cornerRadius;
@property (nonatomic, retain) UIView *selectionIndicatorView;
// ... 모든 property 나열

- (void)setCornerRadius:(double)arg1;
- (double)cornerRadius;
// ... 모든 메서드 나열
@end
```

→ **이 헤더를 보고 LLDB에서 어떤 속성을 조회할지 파악 가능**

---

## 3. 시스템 앱 디버깅 방법

### 3.1. SIP 비활성화

시스템 앱(Photos, Settings 등)에 LLDB attach하려면 SIP 비활성화 필요.

#### 참고 문서
- [Attaching debugger to system apps](https://supersonicbyte.com/blog/attaching-debugger-to-system-apps/)
- [Debug any simulator app view hierarchy](https://blog.hansen.ee/2021/04/18/Debug-any-simulator-app-view-hiearchy/)
- [Medium - Attach debugger whenever you want](https://medium.com/better-programming/attach-a-debugger-to-your-ios-app-whenever-you-want-feca0c4f336b)
- [Testableapple - Debugging third party iOS apps](https://testableapple.com/debugging-third-party-ios-apps-with-lldb/)

#### 비활성화 방법
```bash
# 1. Mac 재시작하여 복구 모드 진입
#    - Intel Mac: ⌘R 누른 채 부팅
#    - Apple Silicon: 전원 버튼 길게 누르기 > Options

# 2. 터미널 열기 (Utilities > Terminal)

# 3. SIP 비활성화
csrutil disable

# 4. 재시작

# 5. 디버깅 완료 후 다시 활성화 (보안상 권장)
csrutil enable
```

### 3.2. 시스템 앱 Attach

```bash
# 1. 시뮬레이터 부팅
xcrun simctl boot <device-id>

# 2. Photos 앱 실행
xcrun simctl launch booted com.apple.mobileslideshow

# 3. PID 확인
ps aux | grep -i photos

# 4. LLDB attach (터미널)
lldb
(lldb) process attach -p <PID>

# 또는 Xcode에서
# Debug > Attach to Process by PID or Name > PID 입력
```

### 3.3. 앱이 실행되기 전에 Attach

```bash
# LLDB에서 대기
(lldb) process attach --name MobileSlideShow --waitfor

# 다른 터미널에서 앱 실행
xcrun simctl launch booted com.apple.mobileslideshow
```

---

## 4. xcrun simctl 활용

### 참고 문서
- [SwiftLee - Simulator Directories Access](https://www.avanderlee.com/xcode/simulator-directories-access/)
- [SimPholders 공식](https://simpholders.com/)
- [Medium - Find app data path](https://medium.com/@liwp.stephen/find-app-data-path-for-ios-simulator-6bba3d2fbab6)
- [GitHub - pholders](https://github.com/rodrigo-lima/pholders)

### 명령어

```bash
# 부팅된 시뮬레이터의 앱 목록
xcrun simctl listapps booted

# 특정 앱 번들 경로
xcrun simctl get_app_container booted com.apple.mobileslideshow

# 앱 데이터 경로
xcrun simctl get_app_container booted com.apple.mobileslideshow data

# 앱 실행
xcrun simctl launch booted com.apple.mobileslideshow

# 앱 종료
xcrun simctl terminate booted com.apple.mobileslideshow
```

---

## 5. UIColor 분해 방법

### 참고 문서
- [Hacking with Swift - Read RGBA Components](https://www.hackingwithswift.com/example-code/uicolor/how-to-read-the-red-green-blue-and-alpha-color-components-from-a-uicolor)
- [Apple - getRed:green:blue:alpha:](https://developer.apple.com/documentation/uikit/uicolor/getred(_:green:blue:alpha:))
- [Apple - getWhite:alpha:](https://developer.apple.com/documentation/uikit/uicolor/getwhite(_:alpha:)?language=objc)
- [GitHub Gist - Swift UIColor Components](https://gist.github.com/StefanJager/73e87f400479b6c13f1e)

### LLDB에서 색상 분해

```lldb
# RGBA 분해
expression -l objc -O -- @import UIKit; CGFloat r,g,b,a; [[(UIView *)0x주소 backgroundColor] getRed:&r green:&g blue:&b alpha:&a]; NSLog(@"R:%.3f G:%.3f B:%.3f A:%.3f", r, g, b, a)

# Gray + Alpha 분해 (회색 계열)
expression -l objc -O -- @import UIKit; CGFloat w,a; [[(UIView *)0x주소 backgroundColor] getWhite:&w alpha:&a]; NSLog(@"White:%.3f Alpha:%.3f", w, a)

# CGColor 컴포넌트 직접 접근
po [(UIView *)0x주소 backgroundColor].CGColor
expression -l objc -O -- CGColorGetComponents([[(UIView *)0x주소 backgroundColor] CGColor])
```

### Swift Extension (디버그용)

```swift
extension UIColor {
    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    var whiteAlpha: (white: CGFloat, alpha: CGFloat) {
        var w: CGFloat = 0, a: CGFloat = 0
        getWhite(&w, alpha: &a)
        return (w, a)
    }
}
```

---

## 6. CALayer cornerCurve 조사

### 참고 문서
- [Apple - CALayerCornerCurve](https://developer.apple.com/documentation/quartzcore/calayercornercurve)
- [Medium - Continuous Rounded Corners with UIKit](https://medium.com/fueled-engineering/continuous-rounded-corners-with-uikit-b575d50ab232)
- [Kyle Hughes - How To Use Continuous Corners](https://kylehugh.es/documents/how-to-use-continuous-corners/)
- [GitHub Gist - Simple UIView continuous corners](https://gist.github.com/PimCoumans/7365b2d700433fa25d434edbba948f3b)

### LLDB 조회

```lldb
# cornerCurve 확인
po [(CALayer *)view.layer cornerCurve]

# 가능한 값:
# - kCACornerCurveCircular (기본값)
# - kCACornerCurveContinuous (Apple 스타일)

# 직접 확인
expression -l objc -O -- [(CALayer *)[(UIView *)0x주소 layer] cornerCurve]
```

### 값 해석
- `.circular` (기본): 정확한 원호
- `.continuous`: Apple의 "squircle" 스타일, iOS 기본 UI에서 사용

---

## 7. SF Symbol Configuration 조사

### 참고 문서
- [Apple - SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
- [Apple - SF Symbols App](https://developer.apple.com/sf-symbols/)
- [Hacking with Swift - Complete Guide to SF Symbols](https://www.hackingwithswift.com/articles/237/complete-guide-to-sf-symbols)
- [Apple - init(pointSize:weight:scale:)](https://developer.apple.com/documentation/appkit/nsimage/symbolconfiguration-swift.class/init(pointsize:weight:scale:))
- [Sarunw - SF Symbols Guide](https://sarunw.com/posts/sf-symbols-1/)
- [tanaschita - SF Symbols Guide](https://tanaschita.com/ios-sf-symbols/)

### LLDB 조회

```lldb
# UIImageView의 이미지에서 symbol configuration 확인
po imageView.image
po imageView.image.symbolConfiguration

# 상세 정보
expression -l objc -O -- [[imageView image] symbolConfiguration]
```

### Configuration 속성
- `pointSize`: 심볼의 포인트 크기
- `weight`: ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
- `scale`: small, medium, large

---

## 8. Private API 참고

### 참고 문서
- [mr-v.github.io - LLDB debugging with private APIs](https://mr-v.github.io/lldb-debugging-views-with-private-apis-in-swift)
- [Medium - Auto Layout Debugging in Swift](https://medium.com/ios-os-x-development/auto-layout-debugging-in-swift-93bcd21a4abf)
- [GitHub - UIViewController-RecursiveDescription](https://github.com/jrturton/UIViewController-RecursiveDescription)
- [ndersson.me - Printing ViewController Hierarchy](https://ndersson.me/post/print_view_controller_hierarchy/)

### 주요 Private 메서드

| 메서드 | 클래스 | 용도 |
|--------|--------|------|
| `recursiveDescription` | UIView | 뷰 계층 텍스트 출력 |
| `_printHierarchy` | UIViewController | VC 계층 텍스트 출력 |
| `_autolayoutTrace` | UIView | Auto Layout 문제 진단 |
| `_recursiveAutolayoutTraceAtLevel:` | UIView | 특정 뷰 기준 AL 트레이스 |

---

## 9. 미실측 항목별 권장 조사 방법

| # | 항목 | 1순위 방법 | LLDB 명령 예시 | 비고 |
|---|------|-----------|---------------|------|
| 4 | capsulePadding | LLDB | `po platterView.frame.origin.y` | TabBar 높이와 비교 계산 |
| 8 | tabIconSize | LLDB | `po tabButton.imageView.image.symbolConfiguration` | SF Symbol config |
| 11 | 레이블 폰트 크기 | LLDB | `po tabButton.titleLabel.font.pointSize` | |
| 12 | 배경 gray | LLDB + getWhite | 위 6번 참조 | |
| 13 | backgroundAlpha | LLDB + getWhite | 위 6번 참조 | |
| 14 | 비선택 아이콘 alpha | LLDB | `po unselectedTabButton.imageView.alpha` | |
| 15 | Platter cornerCurve | LLDB | `po platterView.layer.cornerCurve` | |
| 16 | maxDimAlpha | 스크린샷 + 역산 | - | 그라데이션 상단 측정 |

---

## 10. 추가 참고 자료

### iOS 리버스 엔지니어링 일반
- [The Apple Wiki - Reverse Engineering Tools](https://theapplewiki.com/wiki/Dev:Reverse_Engineering_Tools)
- [iPhone Dev Wiki - Reverse Engineering Tools](https://iphonedev.wiki/Reverse_Engineering_Tools)
- [GitHub - iOS-Reverse-Engineering](https://github.com/GhidraEnjoyr/iOS-Reverse-Engineering)
- [GitHub - iOSAppReverseEngineering](https://github.com/iosre/iOSAppReverseEngineering)
- [GitHub - awesome-reverse-engineering](https://github.com/alphaSeclab/awesome-reverse-engineering)
- [Corellium - iOS Reverse Engineering](https://www.corellium.com/blog/ios-mobile-reverse-engineering)
- [Corellium - Reverse Engineering Tools iOS](https://www.corellium.com/blog/reverse-engineering-tools-ios)
- [OffensiveCon 2025 - Practical iOS Reverse Engineering](https://www.offensivecon.org/trainings/2025/practical-ios-reverse-engineering.html)

### 디버깅 도구
- [BrowserStack - 20 Best iOS Debugging Tools](https://www.browserstack.com/guide/ios-debugging-tools)
- [GitHub - iOS-Hierarchy-Viewer](https://github.com/damian-kolakowski/iOS-Hierarchy-Viewer)
- [Simon Støvring - Running View Debugger While Interacting](https://simonbs.dev/posts/running-xcodes-view-debugger-while-interacting-with-the-simulator/)

### CALayer 속성
- [Apple - Layer Style Properties](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/LayerStyleProperties/LayerStyleProperties.html)
- [Apple - CALayer](https://developer.apple.com/documentation/quartzcore/calayer)
- [Advanced Swift - Corner Radius, Shadows, Borders](https://www.advancedswift.com/corners-borders-shadows/)

### UIKit 디버깅
- [ComponentKit - Debugging](https://componentkit.org/docs/debugging/)
- [Kodeco - SwiftUI Debugging](https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/5-debugging-swiftui-code-with-xcode-s-debugger)

---

## 11. 권장 조사 순서

### 시스템 앱(Photos) 분석 시

1. **Accessibility Inspector** — SIP 없이 빠른 뷰 구조 파악
2. **SIP 비활성화** — 상세 분석 준비
3. **LLDB Attach** — Photos 앱에 attach
4. **Chisel pviews** — 전체 계층 덤프
5. **개별 LLDB 명령** — cornerCurve, alpha, font 등 상세 조회
6. **Digital Color Meter** — 색상 값 검증
7. **스크린샷 분석** — 크기/간격 최종 검증

### 자체 앱 분석 시

1. **Xcode View Debugger** — 빠른 시각적 확인
2. **FLEX 통합** — 실시간 탐색
3. **LLDB** — 상세 속성 조회
4. **Reveal** — 복잡한 계층 분석 시

---

## 12. 다음 단계

### SystemUIInspector 확장 제안

기존 `SystemUIInspector`에 다음 속성 덤프 추가:

```swift
// 추가할 속성들
struct ExtendedLayerInfo {
    let cornerCurve: CALayerCornerCurve
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let masksToBounds: Bool
}

struct ExtendedColorInfo {
    let white: CGFloat
    let alpha: CGFloat
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}

struct ExtendedFontInfo {
    let pointSize: CGFloat
    let fontName: String
    let weight: UIFont.Weight?
}

struct ExtendedViewInfo {
    let alpha: CGFloat
    let isHidden: Bool
    let layer: ExtendedLayerInfo
    let backgroundColor: ExtendedColorInfo?
    let font: ExtendedFontInfo? // UILabel, UIButton용
}
```

### JSON 덤프 포맷

```json
{
  "captureTime": "2026-01-25T10:30:00Z",
  "viewPath": "UIWindow > UITabBar > _UITabBarPlatterView",
  "properties": {
    "frame": {"x": 64, "y": 0, "width": 274, "height": 62},
    "alpha": 1.0,
    "layer": {
      "cornerRadius": 31,
      "cornerCurve": "continuous",
      "shadowOpacity": 0.25,
      "shadowRadius": 16
    },
    "backgroundColor": {
      "white": 0.11,
      "alpha": 0.73
    }
  }
}
```
