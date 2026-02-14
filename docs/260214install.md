# 최초 설치 시 로딩 화면 개선

> 작성일: 2026-02-14
> 상태: 조사 완료 → 구현 대기

## 문제

- 앱 빌드 후 설치 시 **검은/흰 빈 화면이 약 10초** 표시됨
- 사용자 입장에서 앱이 멈춘 건지 로딩 중인지 알 수 없음 → **이탈 위험**
- 현재 `LaunchScreen.storyboard`는 순수 배경색만 있고, 로고/인디케이터 없음

## 조사 결과

### 1. LaunchScreen vs Extended Splash Screen

| 구분 | LaunchScreen.storyboard | Extended Splash (SplashViewController) |
|------|------------------------|---------------------------------------|
| 관리 주체 | iOS 시스템 | 앱 코드 |
| 표시 시점 | 앱 프로세스 로딩 중 (~1초) | 앱 실행 후, 초기화 완료까지 |
| 제약 | 정적 이미지/레이아웃만, 코드/애니메이션 불가 | 자유로움 |
| HIG 규칙 | 로고/텍스트 금지 (브랜딩 용도 아님) | Loading 가이드라인 적용 |

### 2. 유명 앱들의 처리 방식

| 앱 | 전략 |
|----|------|
| Apple Photos | 그리드 UI 즉시 표시, 인덱싱은 백그라운드에서 수일~수주 진행 |
| Google Photos | 메인 그리드 즉시 표시, 동기화는 백그라운드 |
| Spotify | 스켈레톤 UI로 구조 먼저 표시, 데이터 점진적 로딩 |
| Twitter/X | 로고 마스크 확대 애니메이션 → 메인 화면 reveal |

**공통 원칙**: 완전한 로딩을 기다리지 않고 UI 구조를 먼저 표시, 무거운 작업은 백그라운드

### 3. Apple HIG 가이드라인

**LaunchScreen (시스템 런치 스크린):**
- 앱이 빠르다는 인식을 주기 위한 플레이스홀더
- 로고/광고/텍스트 넣지 말 것 (첫 화면의 고정 요소인 경우만 예외)
- 이상적인 런치 스크린은 사용자에게 사실상 보이지 않는 것

**Loading (로딩 인디케이터):**
- 1초 이상 → 스피너 표시 필요
- 10초 이상 → 진행률(%) 프로그레스 바 사용
- 프로그레스 바는 절대 멈추면 안 됨

→ **현재 10초 빈 화면 = HIG 위반. 로딩 인디케이터를 보여주는 것이 HIG 준수.**

### 4. 현재 앱 초기화 흐름 (10초 소요 원인)

```
1. LaunchScreen 표시 (시스템)
2. AppDelegate.didFinishLaunchingWithOptions
   - ImagePipeline 초기화, AnalyticsService 초기화
3. SceneDelegate.scene(:willConnectTo:)
   - UIWindow 생성, 권한 체크, configureRootViewController()
4. TabBarController → GridViewController 생성
5. GridViewController.viewDidLayoutSubviews → startInitialDisplay()
   - dataSourceDriver.reloadData() ← PhotoKit 쿼리 (병목 의심)
   - 프리로드 대기 (100ms 타임아웃)
6. finishInitialDisplay() → collectionView fade-in
```

주요 병목: **PhotoKit 쿼리 + 썸네일 프리로드** 구간

---

## 해결 방안

### 2단계 구조: LaunchScreen + SplashViewController

```
[LaunchScreen.storyboard]         ← 시스템이 자동 표시 (~1초, 정적)
  배경색만 (HIG 준수)
        ↓ (동일한 배경색으로 이음새 없이 전환)
[SplashViewController]            ← 코드로 제어 (초기화 완료까지)
  로고 + 로딩 애니메이션
        ↓ (초기화 완료 시 페이드아웃)
[메인 화면 (GridViewController)]
```

### SplashViewController 구현 포인트

**화면 구성:**
- 배경: 다크 (#000 또는 앱 테마색)
- 중앙: 앱 로고 이미지 (주인님이 제작 예정)
- 로고 아래: 로딩 인디케이터

**로고 표시 방식 고려사항:**

| 항목 | 권장값 | 비고 |
|------|--------|------|
| 로고 크기 | 화면 너비의 25~35% | 너무 크면 압도적, 너무 작으면 안 보임 |
| 로고 위치 | 수직 중앙에서 약간 위 | 아래에 인디케이터 공간 확보 |
| 로고 포맷 | PDF (벡터) 또는 @2x/@3x PNG | Assets.xcassets에 추가 |
| 다크/라이트 | 어두운 배경 기준으로 디자인 | 앱이 다크모드 강제이므로 |

**애니메이션 옵션:**

| 옵션 | 방식 | 느낌 | 작업량 |
|------|------|------|--------|
| A. 스피너 | 로고 아래 `UIActivityIndicatorView` | 심플, iOS 기본 | 최소 |
| B. 펄스 로고 | 로고 alpha가 부드럽게 반복 (0.6↔1.0) | 세련됨, 앱이 살아있는 느낌 | 소 |
| C. 프로그레스 바 | 로고 아래 얇은 진행 바 | 진행 상황 명확 | 중 |

**추천: B (펄스 로고)**
- 스피너: 10초 동안 돌면 오히려 불안감
- 프로그레스 바: PhotoKit fetch 진행률 산출 어려움
- 펄스: "로딩 중"이라는 인식을 자연스럽게 주면서 10초도 부담 없음

### 구현 흐름 (SceneDelegate 수정)

```swift
// 현재: 즉시 메인 화면 표시
func scene(_:willConnectTo:options:) {
    configureRootViewController()  // → TabBarController 또는 PermissionVC
}

// 변경: SplashViewController를 먼저 표시
func scene(_:willConnectTo:options:) {
    let splash = SplashViewController()
    window.rootViewController = splash

    // 백그라운드에서 초기화 수행
    splash.onReady = { [weak self] in
        self?.configureRootViewController()  // 완료 시 메인 화면 전환
    }
}
```

### 필요한 파일

| 파일 | 역할 |
|------|------|
| `SplashViewController.swift` | 로고 + 로딩 애니메이션 화면 (신규) |
| `LaunchScreen.storyboard` | 배경색을 다크로 변경 (수정) |
| `Assets.xcassets/Logo.imageset/` | 로고 이미지 에셋 (신규, 주인님 제작) |
| `SceneDelegate.swift` | 초기화 흐름 변경 (수정) |

---

## 로고 이미지 준비 가이드

주인님이 로고를 제작할 때 참고할 사항:

### 권장 사양

| 항목 | 권장 |
|------|------|
| 포맷 | PDF (벡터, 해상도 무관) 또는 PNG (@1x/@2x/@3x) |
| PNG 크기 | @1x: 120×120, @2x: 240×240, @3x: 360×360 |
| 배경 | 투명 (다크 배경 위에 표시) |
| 색상 | 밝은 색 또는 흰색 계열 (다크 배경 대비) |
| 여백 | 로고 주변 충분한 여백 포함 |

### Assets.xcassets 등록

```
Assets.xcassets/
  └── Logo.imageset/
      ├── Contents.json
      ├── logo@2x.png
      └── logo@3x.png
```

---

## TODO

- [ ] 로고 이미지 제작 (주인님)
- [ ] Assets.xcassets에 Logo.imageset 추가
- [ ] LaunchScreen.storyboard 배경색 다크로 변경
- [ ] SplashViewController 구현 (로고 + 펄스 애니메이션)
- [ ] SceneDelegate 초기화 흐름 변경
- [ ] 초기화 작업을 백그라운드로 분리 (성능 최적화)
