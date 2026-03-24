# LOD0 제거 계획

## 배경

### 현재 이미지 로딩 흐름 (뷰어 진입 시)
```
1. initialImage (그리드 썸네일 370×492) — 즉시
2. LOD0 degraded (90×120) — 매번 skip (의미 없음)
3. LOD0 non-degraded (1126×1500) — 중간 단계
4. LOD1 full (3024×4032) — 최종
```

### 제거 근거

**로그 분석 (iOS 18, 실기기 8회 측정):**

| 진입 | LOD0 non-deg | LOD1 full | 선착 | 차이 |
|------|-------------|-----------|------|------|
| 1차 | +352ms | +385ms | LOD0 | 33ms |
| 2차 | +510ms | +540ms | LOD0 | 30ms |
| 3차 | +771ms | +801ms | LOD0 | 30ms |
| 4차 | +438ms | +408ms | **LOD1** | 30ms 역전 |
| 5차 | +386ms | +358ms | **LOD1** | 28ms 역전 |
| 6차 | +303ms | +582ms | LOD0 | 279ms |
| 7차 | +590ms | +623ms | LOD0 | 33ms |
| 8차 | +373ms | +676ms | LOD0 | 303ms |

- **체감 가치 있는 경우**: 2/8 (25%) — 280~300ms 선착
- **무의미한 경우**: 4/8 (50%) — 30ms 차이, 체감 불가
- **해로운 경우**: 2/8 (25%) — 역전 발생, LOD1 이후 저해상도로 덮어씀
- **degraded**: 8/8 (100%) skip — 완전 무의미
- **debugSkipLOD0=true 실기기 체감 테스트**: 차이 느끼지 못함

### 제거 시 기대 효과
- 코드 단순화 (LOD0 요청/콜백/프로퍼티 제거)
- 역전 문제(LOD0이 LOD1을 덮어쓰는 현상) 근본 해소
- PHImageManager 요청 1개 감소 → 시스템 부하 감소
- LOD1도 pause 보호 대상이 됨 (현재는 LOD0만 보호, LOD1은 무보호)
- 흐름 단순화: `initialImage → (pause + 150ms 디바운스) → LOD1 → (resume)`

---

## 제거 대상 코드

### Phase 1: LOD0 메서드 및 호출 제거

| 파일 | 줄 | 내용 | 작업 |
|------|-----|------|------|
| PhotoPageViewController.swift | L371-432 | `debugSkipLOD0` 플래그 + `requestLOD0Image()` 메서드 전체 | 제거 |
| PhotoPageViewController.swift | L169 | `viewDidLoad()`에서 `requestLOD0Image()` 호출 | 제거 |
| PhotoPageViewController.swift | L183 | `viewDidLayoutSubviews()`에서 fallback 호출 | 제거 |
| PhotoPageViewController.swift | L385-386, 402, 415 | LOD0 내부의 pause/resume 호출 3곳 | 제거 (Phase 3에서 이전) |

### Phase 2: 죽은 코드 및 LOD0 전용 프로퍼티 정리

| 파일 | 줄 | 내용 | 작업 | 근거 |
|------|-----|------|------|------|
| PhotoPageViewController.swift | L96-97 | `requestCancellable` | 제거 | LOD0과 `requestImageForCurrentBoundsIfNeeded()`에서만 사용 |
| PhotoPageViewController.swift | L449-492 | `requestImageForCurrentBoundsIfNeeded()` | 제거 | 호출부 없는 죽은 코드 |
| PhotoPageViewController.swift | L112 | `lastRequestedTargetSize` | 제거 | `requestImageForCurrentBoundsIfNeeded()` 전용 |
| PhotoPageViewController.swift | L202 | `deinit`의 `requestCancellable?.cancel()` | 제거 | requestCancellable 제거에 따름 |

`imageRequestStartTime` (L105-106)은 LOD1 콜백(L509)에서도 사용 중이므로 **유지**.
단, LOD0 제거 후 시간 측정 기준점이 사라지므로 **Phase 3에서 `requestFullSizeImage()` 시작에 설정 추가**.

### Phase 3: pause/resume을 ViewerViewController 레벨로 이전

#### 배경: viewDidLoad에서 pause할 수 없는 이유

UIPageViewController는 인접 페이지를 미리 생성하므로, `PhotoPageViewController.viewDidLoad()`에서
pause하면 인접 페이지(좌/우)도 pause를 호출합니다 (count: 3).
그런데 LOD1은 현재 페이지에만 요청되므로 인접 페이지의 resume이 호출되지 않아 **분석이 영구 멈춥니다**.

현재(LOD0)에서는 인접 페이지도 `requestLOD0Image()`를 호출하고 콜백에서 resume하므로 균형이 맞았습니다.

#### 추가 발견: 현재도 LOD1은 보호되지 않음

```
현재 흐름:
viewDidLoad → requestLOD0Image() → pause
LOD0 non-degraded (+85ms) → resume       ← 여기서 분석 재개
(150ms 디바운스)
LOD1 요청 → LOD1 도착 (+196ms)           ← 이 구간은 분석과 경쟁 중!
```

새 방식은 LOD1 구간도 보호하므로 **현재보다 개선**됩니다.

#### 방침: scheduleLOD1Request()에서 pause → LOD1 콜백에서 resume

**pause 위치**: `ViewerViewController.scheduleLOD1Request()` (디바운스 시작 시)
**resume 위치**: `PhotoPageViewController.requestFullSizeImage()` 콜백 + 안전장치

구체적 변경:

**ViewerViewController.swift — `scheduleLOD1Request()`:**
```swift
func scheduleLOD1Request() {
    lod1DebounceTimer?.invalidate()
    // LOD1 디바운스 시작 시 분석 양보 (LOD1 로딩 완료까지 보호)
    SimilarityAnalysisQueue.shared.pauseImageLoading()
    lod1DebounceTimer = Timer.scheduledTimer(withTimeInterval: Self.lod1DebounceDelay, repeats: false) { [weak self] _ in
        guard let self = self else { return }
        if let photoVC = self.pageViewController.viewControllers?.first as? PhotoPageViewController {
            photoVC.requestHighQualityImage()
        } else {
            // 동영상 페이지 등 사진이 아닌 경우 → 즉시 resume (영구 pause 방지)
            SimilarityAnalysisQueue.shared.resumeImageLoading()
        }
    }
}
```

**ViewerViewController.swift — `willTransitionTo`:**
```swift
func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
    lod1DebounceTimer?.invalidate()
    lod1DebounceTimer = nil
    // 이전 scheduleLOD1Request의 pause 해제 (타이머 취소로 resume 경로가 사라지므로)
    SimilarityAnalysisQueue.shared.resumeImageLoading()
    // ... 기존 코드
}
```

**PhotoPageViewController.swift — `requestFullSizeImage()`:**
```swift
private func requestFullSizeImage() {
    fullSizeRequestCancellable?.cancel()
    // LOD1 시간 측정 기준점
    imageRequestStartTime = CFAbsoluteTimeGetCurrent()
    Logger.viewer.debug("[LOD1-full] 요청 시작 targetSize=MAX")
    fullSizeRequestCancellable = ImagePipeline.shared.requestImage(
        for: asset,
        targetSize: PHImageManagerMaximumSize,
        contentMode: .aspectFit,
        quality: .high
    ) { [weak self] image, isDegraded in
        guard let self = self, let image = image else {
            // 실패 시에도 분석 재개 (영구 pause 방지)
            SimilarityAnalysisQueue.shared.resumeImageLoading()
            return
        }
        // ... 기존 로그/이미지 교체 코드 ...
        guard !isDegraded else { return }
        self.hasLoadedFullSize = true
        self.imageView.image = image
        // LOD1 완료 → 분석 재개
        SimilarityAnalysisQueue.shared.resumeImageLoading()
    }
}
```

**PhotoPageViewController.swift — `deinit`:**
```swift
deinit {
    // requestCancellable 제거됨 (Phase 2)
    // 뷰어 종료 시 분석 재개 (영구 pause 방지 안전장치)
    SimilarityAnalysisQueue.shared.resumeImageLoading()
}
```

#### 엣지 케이스 검증

| 시나리오 | pause | resume | 결과 |
|---------|-------|--------|------|
| 최초 진입 | scheduleLOD1Request → pause(1) | LOD1 콜백 → resume(0) | ✓ |
| 스와이프 완료 | willTransitionTo → resume(0) → scheduleLOD1Request → pause(1) | LOD1 콜백 → resume(0) | ✓ |
| 빠른 스와이프 | scheduleLOD1Request → pause(1) → willTransitionTo → resume(0) → scheduleLOD1Request → pause(1) | LOD1 콜백 → resume(0) | ✓ |
| 스와이프 취소 | willTransitionTo → resume(0 clamp) | — | ✓ (안전장치) |
| 동영상 페이지 | scheduleLOD1Request → pause(1) | 타이머 else절 → resume(0) | ✓ |
| LOD1 실패 | scheduleLOD1Request → pause(1) | 콜백 guard → resume(0) | ✓ |
| 뷰어 닫기 | — | deinit → resume(0 clamp) | ✓ (안전장치) |
| 그리드 스크롤과 중복 | 그리드 pause(1) + scheduleLOD1Request pause(2) | LOD1 resume(1) → 스크롤 종료 resume(0) | ✓ (참조 카운팅) |

### Phase 4: LOD1 디바운스 유지 확인

- 디바운스(150ms) **유지** — 전환 애니메이션 중 디코딩 부하 방지 + 빠른 스와이프 시 불필요한 요청 방지
- 최초 진입 시 `ViewerViewController+Setup.swift:286`에서 `scheduleLOD1Request()` 호출 → LOD0 제거와 무관하게 정상 동작

### Phase 5: 주석 및 로그 정리

| 파일 | 내용 | 작업 |
|------|------|------|
| SimilarityAnalysisQueue.swift L169 | `// MARK: - Image Loading Pause/Resume (뷰어 LOD0 리소스 경쟁 방지)` | "LOD0" → "LOD1" 또는 "뷰어" |
| SimilarityAnalysisQueue.swift L172 | `/// 뷰어 LOD0 요청 시 호출하여...` | "LOD0" → "LOD1" |
| SimilarityAnalysisQueue.swift L178 | `/// LOD0 non-degraded 도착 또는 뷰어 종료 시 호출합니다.` | "LOD0 non-degraded" → "LOD1" |
| SimilarityImageLoader.swift L96 | `/// 뷰어 LOD0, 스크롤 등 여러 소스에서...` | "LOD0" → "LOD1" |
| SimilarityImageLoader.swift L134 | `/// 뷰어 LOD0, 스크롤 등 여러 소스에서 호출 가능` | "LOD0" → "LOD1" |
| PhotoPageViewController.swift L161 | `// Phase 1: 즉시 레이아웃 + LOD0 요청` | 주석 수정 |
| PhotoPageViewController.swift L166 | `[LOD0] initialImage 세팅` | 로그 태그 변경 |
| PhotoPageViewController.swift L280 | `// MARK: - Phase 1: Early Layout & LOD0` | "& LOD0" 제거 |
| 260316Preload.md L21 | "LOD0 도착 시 resume" | "LOD1 도착 시 resume" |
| 260316Preload.md L113 | 검증 항목 4번 "뷰어 LOD0" | 삭제 |

---

## 제거 후 최종 흐름

```
1. initialImage (그리드 썸네일 370×492) — 즉시 표시

2. ViewerViewController.scheduleLOD1Request()
   ├─ pauseImageLoading()          ← 분석 양보
   └─ 150ms 디바운스 타이머 시작

3. (150ms 대기)

4. requestHighQualityImage() → requestFullSizeImage()
   ├─ imageRequestStartTime 설정   ← 시간 측정 기준점
   └─ PHImageManagerMaximumSize 요청

5. LOD1 full (3024×4032) — 최종 이미지 교체
   └─ resumeImageLoading()         ← 분석 재개
```

---

## 관련 문서

- `260316Preload.md`: pause/resume 설명 업데이트 필요 (Phase 5에 포함)

---

## 체크리스트

- [x] Phase 1: `requestLOD0Image()` 및 호출부 제거
- [x] Phase 2: 죽은 코드(`requestImageForCurrentBoundsIfNeeded`) 및 LOD0 전용 프로퍼티 제거
- [x] Phase 3: pause/resume을 ViewerViewController(`scheduleLOD1Request`/`willTransitionTo`)로 이전
- [x] Phase 3: `requestFullSizeImage()`에 `imageRequestStartTime` 설정 + resume 추가
- [x] Phase 3: `scheduleLOD1Request()` 타이머 콜백에 동영상 페이지 else resume 추가
- [x] Phase 4: LOD1 디바운스 유지 확인
- [x] Phase 5: 주석/로그 태그 정리 (LOD0 → LOD1)
- [x] Phase 5: `260316Preload.md` 업데이트
- [x] 빌드 확인
- [x] 실기기 테스트 (뷰어 진입 → 이미지 표시 정상, 분석 pause/resume 정상)

---

## 구현 결과 (2026-03-24)

### 계획 대비 추가 변경

LOD0 제거 후 인접 페이지가 검은 화면으로 표시되는 문제가 발생하여,
기존 LOD0의 "프리페치" 역할을 개선된 형태로 대체함:

| 항목 | 기존 LOD0 | 새 requestScreenSizeImage |
|------|----------|--------------------------|
| quality | `.fast` (degraded 2단계 콜백) | `.high` (1단계 콜백) |
| targetSize | 화면 크기 (1126×1500) | 화면 크기 (동일) |
| pause/resume | LOD0 내부에서 직접 관리 | ViewerViewController 레벨에서 관리 |
| 역전 문제 | LOD1보다 늦게 도착 시 덮어씀 | hasLoadedFullSize 플래그로 방지 |
| cancellable | requestCancellable (공유) | screenSizeRequestCancellable (독립) |
| deinit cancel | requestCancellable만 cancel | screen + fullSize 모두 cancel |

### 최종 흐름

```
1. initialImage (그리드 썸네일 370×492) — 즉시 표시
2. requestScreenSizeImage() — 화면 크기 이미지 프리페치 (.high, 1단계)
3. ViewerViewController.scheduleLOD1Request()
   ├─ pauseImageLoading()
   └─ 150ms 디바운스 타이머 시작
4. requestFullSizeImage() — 원본 (3024×4032)
   └─ resumeImageLoading()
```
