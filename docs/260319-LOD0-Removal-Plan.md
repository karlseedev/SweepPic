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
- 흐름 단순화: `initialImage → (pause) → LOD1 → (resume)`

---

## 제거 대상 코드

### Phase 1: LOD0 메서드 및 호출 제거

| 파일 | 줄 | 내용 | 작업 |
|------|-----|------|------|
| PhotoPageViewController.swift | L375-432 | `debugSkipLOD0` 플래그 + `requestLOD0Image()` 메서드 전체 | 제거 |
| PhotoPageViewController.swift | L169 | `viewDidLoad()`에서 `requestLOD0Image()` 호출 | 제거 |
| PhotoPageViewController.swift | L183 | `viewDidLayoutSubviews()`에서 fallback 호출 | 제거 |

### Phase 2: 죽은 코드 및 LOD0 전용 프로퍼티 정리

| 파일 | 줄 | 내용 | 작업 | 근거 |
|------|-----|------|------|------|
| PhotoPageViewController.swift | L96-97 | `requestCancellable` | 제거 | LOD0과 `requestImageForCurrentBoundsIfNeeded()`에서만 사용 |
| PhotoPageViewController.swift | L449-492 | `requestImageForCurrentBoundsIfNeeded()` | 제거 | 호출부 없는 죽은 코드 |
| PhotoPageViewController.swift | L112 | `lastRequestedTargetSize` | 제거 | `requestImageForCurrentBoundsIfNeeded()` 전용 |
| PhotoPageViewController.swift | L202 | `deinit`의 `requestCancellable?.cancel()` | 제거 | requestCancellable 제거에 따름 |

`imageRequestStartTime` (L105-106)은 LOD1 콜백(L509)에서도 사용 중이므로 **유지**.
단, LOD0 제거 후 시간 측정 기준점이 사라지므로 **Phase 3에서 LOD1 요청 시 설정 추가**.

### Phase 3: pause/resume 로직 이전 (선택 A 확정)

**방침**: 뷰어 진입 즉시 pause → LOD1 도착 시 resume (현재 LOD0과 동일한 보호 범위)

구체적 변경:

| 위치 | 현재 | 변경 후 |
|------|------|---------|
| `viewDidLoad()` | `requestLOD0Image()` 내부에서 pause | `viewDidLoad()`에서 직접 `pauseImageLoading()` 호출 |
| `requestFullSizeImage()` 시작 | 없음 | `imageRequestStartTime = CFAbsoluteTimeGetCurrent()` 추가 |
| `requestFullSizeImage()` 콜백 (성공) | 없음 | `resumeImageLoading()` 추가 |
| `requestFullSizeImage()` 콜백 (실패) | 없음 | `resumeImageLoading()` 추가 (영구 pause 방지) |
| `deinit` | `resumeImageLoading()` | **유지** (안전장치) |

변경 후 흐름:
```
viewDidLoad()
  ├─ applyInitialLayout()
  ├─ initialImage 세팅 (placeholder)
  ├─ pauseImageLoading()          ← 즉시 분석 양보
  └─ (LOD0 호출 제거)

ViewerViewController.scheduleLOD1Request()  (150ms 디바운스)
  └─ requestHighQualityImage()
       └─ requestFullSizeImage()
            ├─ imageRequestStartTime 설정   ← 시간 측정 기준점
            └─ 콜백: resumeImageLoading()   ← 분석 재개
```

### Phase 4: LOD1 디바운스 유지 확인

- 디바운스(150ms) **유지** — 전환 애니메이션 중 디코딩 부하 방지 + 빠른 스와이프 시 불필요한 요청 방지
- 최초 진입 시 `ViewerViewController+Setup.swift:286`에서 `scheduleLOD1Request()` 호출 → LOD0 제거와 무관하게 정상 동작

---

## 제거 후 최종 흐름

```
1. initialImage (그리드 썸네일 370×492) — 즉시 표시
2. pauseImageLoading() — 분석 양보
3. (150ms 디바운스 대기)
4. LOD1 full (3024×4032) — 최종 이미지 교체 + resumeImageLoading()
```

---

## 관련 문서

- `260316Preload.md`: 프리로드 문서의 "LOD0 도착 시 resume" → "LOD1 도착 시 resume"으로 업데이트 필요
- 검증 항목 4번 "뷰어 LOD0가 빠르게 도착하는지" → 삭제

---

## 체크리스트

- [ ] Phase 1: `requestLOD0Image()` 및 호출부 제거
- [ ] Phase 2: 죽은 코드(`requestImageForCurrentBoundsIfNeeded`) 및 LOD0 전용 프로퍼티 제거
- [ ] Phase 3: pause/resume을 viewDidLoad/LOD1 콜백으로 이전, `imageRequestStartTime` 설정 추가
- [ ] Phase 4: LOD1 디바운스 유지 확인
- [ ] 로그 태그 정리: `[LOD0]` → 제거, initialImage 로그는 태그 변경
- [ ] 빌드 확인
- [ ] 실기기 테스트 (뷰어 진입 → 이미지 표시 정상, 분석 pause/resume 정상)
- [ ] `260316Preload.md` pause/resume 설명 업데이트
