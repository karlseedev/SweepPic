# 260410 Release Build Bugs Refactoring Plan

## 목적

`Release` 빌드에서 깨지는 debug/release 경계 문제를 정리한다.

목표:
- debug 기능 소스는 유지한다.
- `Release` 바이너리에는 debug 구현이 포함되지 않게 한다.
- 메인 ViewController 본문에서 debug 타입 직접 참조를 제거한다.
- 대규모 리팩토링 없이, 동작 보존 범위에서 구조만 정리한다.

이 작업은 기능 추가가 아니라 `debug/release` 경계 정리를 위한 소규모 리팩토링으로 본다.

## 현재 확인된 이슈

### 1. GridViewController

파일:
- `SweepPic/SweepPic/Features/Grid/GridViewController.swift`
- `SweepPic/SweepPic/Debug/AutoScrollTester.swift`

문제:
- `AutoScrollTester`와 `setupAutoScrollGesture()`는 debug 전용 구현인데,
  `GridViewController.swift` 본문이 `Release`에서도 직접 참조하고 있다.
- observer selector 핸들러 `handleAutoScrollDidBegin()` /
  `handleAutoScrollDidEnd()`도 함께 고려해야 한다.

핵심 지점:
- `additionalSetup()`의 gesture 조건부 설치
- `setupAdditionalGestures()`의 gesture 설치
- `viewDidAppear()`의 launch argument 기반 시작
- `setupObservers()`의 begin/end notification 등록
- `handleAutoScrollDidBegin()`
- `handleAutoScrollDidEnd()`

### 2. FaceComparisonViewController

파일:
- `SweepPic/SweepPic/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- `SweepPic/SweepPic/Features/SimilarPhoto/Debug/FaceComparisonDebug.swift`
- `SweepPic/SweepPic/Features/SimilarPhoto/Analysis/YuNet/YuNetDebugTest.swift`

문제:
- `YuNetDebugTest`, `FaceComparisonDebugHelper`는 debug 전용 구현인데,
  `FaceComparisonViewController.swift` 본문이 직접 참조하고 있다.
- 현재 검색 결과 기준으로는 debug 버튼 생성 코드는 보이지 않고,
  `debugButtonTapped()` / `extendedTestButtonTapped()` 액션만 메인 파일에 남아 있다.
- 이 메서드들은 `private` 프로퍼티들에 의존하므로, 별도 파일 분리는 접근제어 충돌을 일으킨다.

관련 `private` 상태 예시:
- `comparisonGroup`
- `validPersonIndices`
- `currentPersonArrayIndex`
- `currentPersonIndex`
- `photoFaces`
- `selectedAssetIDs`

## 리팩토링 원칙

1. 메인 ViewController 본문은 production 책임만 가진다.
2. debug 타입 직접 참조는 debug 경계 안으로 밀어 넣는다.
3. `#if DEBUG`를 여러 군데 흩뿌리지 않고, 가능한 한 한곳에 모은다.
4. 접근제어를 불필요하게 넓히지 않는다.
5. 라이프사이클 흐름이나 실제 동작 순서는 바꾸지 않는다.

## 적용 계획

### A. Grid는 별도 파일 분리

이유:
- 실제 debug 진입점이 존재한다.
- `scrollDidBegin()` / `scrollDidEnd()`는 다른 파일 extension에서 접근 가능하다.
- 메인 파일에서 debug 심볼을 완전히 제거하는 것이 가능하다.

메인 파일에 남길 중립 메서드:
- `configureAutoScrollDebugFeatures()`
- `installAutoScrollDebugGesture()`
- `startAutoScrollDebugIfNeeded()`
- `registerAutoScrollDebugObservers()`

debug 파일로 옮길 메서드 총 6개:
- `configureAutoScrollDebugFeatures()`
- `installAutoScrollDebugGesture()`
- `startAutoScrollDebugIfNeeded()`
- `registerAutoScrollDebugObservers()`
- `handleAutoScrollDidBegin()`
- `handleAutoScrollDidEnd()`

예상 파일:
- `SweepPic/SweepPic/Features/Grid/GridViewController+AutoScrollDebug.swift`
- `SweepPic/SweepPic/Features/Grid/GridViewController+AutoScrollDebugRelease.swift`

구조:
- debug 파일:
  - `#if DEBUG`
  - `AutoScrollTester`
  - `setupAutoScrollGesture()`
  - notification 이름
  - selector 핸들러 2개 사용
- release 파일:
  - `#if !DEBUG`
  - 진입 메서드 4개만 no-op
  - selector 핸들러 stub는 만들지 않음

주의:
- `registerAutoScrollDebugObservers()`가 selector를 참조하므로
  `handleAutoScrollDidBegin()` / `handleAutoScrollDidEnd()`도 같이 이동해야 한다.

### B. FaceComparison은 같은 파일 하단 `#if DEBUG` 격리

이유:
- 현재는 실제 debug 버튼 생성 코드가 보이지 않는다.
- debug 액션 메서드만 메인 파일에 남아 있다.
- 별도 파일로 분리하면 `private` 프로퍼티 접근이 막힌다.
- 접근제어를 `internal`로 넓히는 것은 현재 목적 대비 과하다.

적용 방식:
- `FaceComparisonViewController` 메인 클래스 본문에서
  `debugButtonTapped()` / `extendedTestButtonTapped()`를 제거한다.
- 같은 파일 맨 하단에 단일 `#if DEBUG` extension 블록을 둔다.
- 그 블록 안에 두 액션 메서드를 옮긴다.

유지하는 원칙:
- `comparisonGroup`, `validPersonIndices`, `currentPersonIndex`,
  `photoFaces`, `selectedAssetIDs` 등 `private` 상태는 그대로 둔다.
- debug 타입 직접 참조는 production 본문이 아니라
  같은 파일의 debug 전용 영역 안에만 남긴다.

향후 규칙:
- 나중에 debug 버튼/메뉴 UI를 다시 붙일 경우에도
  생성 코드와 액션 코드를 같은 파일의 `#if DEBUG` 영역 안에 둔다.
- `private` 완화를 전제로 한 별도 파일 분리는 하지 않는다.

## 구현 순서

1. `GridViewController.swift`에서 `AutoScrollTester` 직접 참조를
   중립 메서드 호출로 바꾼다.
2. Grid debug/release 분리 파일을 추가한다.
3. `FaceComparisonViewController.swift` 메인 본문에서
   debug 액션 메서드를 제거한다.
4. 같은 파일 하단에 단일 `#if DEBUG` extension 블록으로 옮긴다.
5. `Release` 빌드를 다시 실행한다.
6. 다음 `Release` 전용 오류가 있으면 같은 패턴으로 추가 정리한다.

## 검증 기준

완료 조건:
- `Release` 빌드가 통과한다.
- debug 기능 소스는 유지된다.
- 메인 production 본문에서 아래 타입 직접 참조가 사라진다.
  - `AutoScrollTester`
  - `YuNetDebugTest`
  - `FaceComparisonDebugHelper`

추가 확인:
- Grid의 auto scroll debug 기능은 `DEBUG`에서 기존과 동일하게 동작해야 한다.
- FaceComparison의 debug 액션은 같은 파일의 debug 영역 안에만 남아야 한다.

## 비목표

이번 작업에서 하지 않을 것:
- `AutoScrollTester` 자체를 production 타입으로 승격
- `FaceComparisonViewController`의 대규모 분해
- 라이프사이클 순서 변경
- 접근제어를 광범위하게 `internal`로 완화
- build setting 자체를 바꿔 `DEBUG` 코드를 `Release`에 포함시키는 우회
