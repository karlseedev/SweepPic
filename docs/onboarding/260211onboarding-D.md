# 코치마크 D — 저품질 자동 정리 안내

> 작성일: 2026-02-17
> 최종 업데이트: 2026-02-25

## 구현 상태: ✅ 완료

---

## 변경 이력

### 2026-02-25: 최적화 + UI 개선 + 트리거 2 제거

**PreScanner 성능 최적화:**
- 스크롤 중 pause/resume 연동 (GridScroll.swift 3곳)
- 스캔 완료 후 pause/resume 호출 무시 (노이즈 로그 방지)
- 스캔 미완료 시 완료 대기 콜백 지원 (onComplete)

**UI 개선:**
- 포커싱 모션 추가: 큰 pill에서 정리 버튼 모양으로 축소 (0.9초) → 0.5초 대기 → 카드 페이드인
- 타이틀 변경: "저품질 사진 발견" (24pt light)
- 본문: "저품질 사진을 AI가 자동" 볼드+노란색(#FFEA00) 강조
- 본문 투명도 제거 (0.7 → 1.0), E-3도 동일 적용

**트리거 2 (수동) 제거:**
- 정리 버튼 탭 시 D 가로채기 삭제 — 정리 시트와 문구 중복으로 불필요
- `dHasHighlight` 프로퍼티, 텍스트 분기, confirm 시퀀스 분기 제거
- `highlightButton` 파라미터 제거, D는 트리거 1(자동)만 존재

**재시도 로직 개선:**
- 다른 코치마크/스크롤 중 재시도 간격 에스컬레이션: 0.5초 × 10회 → 3초 (무한 폴링 방지)

**디버그 지원:**
- `CoachMarkType.resetShown()` 유틸리티 (DEBUG only)
- `CoachMarkDPreScanner.debugReset()` — 스캔 결과 + D 표시 기록 리셋
- SceneDelegate에 `debugReset()` 호출 (주석 처리 상태, 필요시 해제)
- D 타이머 가드 로그: A/E-1 미완료 시 스킵 이유 표시
- A 스크롤 추적 가드 로그 추가

---

## 현재 플로우

```
앱 실행 → 즉시 사전 스캔 시작 (백그라운드)
  │         └── 최근 사진부터 순차 스캔 (3장 확보까지 계속)
  │         └── 스크롤 중 자동 일시정지, 스크롤 종료 시 재개
  │
  ├── 사용자 스크롤 → A 코치마크
  ├── 사용자 첫 삭제 → E-1 시스템 피드백
  │
  ├── A 완료 + E-1 완료 + 그리드 3초 체류
  │     └── 스캔 미완료면 스캔 완료 대기 (onComplete 콜백)
  │
  └── D 표시
        ├── 포커싱 모션: 큰 pill → 정리 버튼 pill로 축소 (0.9초)
        ├── 0.5초 대기 → 카드 페이드인
        ├── "저품질 사진 발견" + 썸네일 3장 + 설명
        ├── [확인] → 탭 모션 on 정리 버튼 → dismiss
        └── showCleanupMethodSheet() 직접 호출
```

---

## 파일 구조

### 핵심 파일 (3개)

| 파일 | 역할 |
|------|------|
| `Features/AutoCleanup/CoachMarkDPreScanner.swift` | 사전 스캔 (T2 파이프라인, pause/resume, 3장 확보) |
| `Features/Grid/GridViewController+CoachMarkD.swift` | D 트리거 로직 (타이머, 가드, 재시도 에스컬레이션) |
| `Shared/Components/CoachMarkOverlayView+CoachMarkD.swift` | D 오버레이 (포커싱 모션, 썸네일, 카드, 탭 모션) |

### 수정 파일

| 파일 | 수정 내용 |
|------|-----------|
| `CoachMarkOverlayView.swift` | `.autoCleanup` case, `updateDimPath()` D pill 구멍, `resetShown()` 디버그 |
| `CoachMarkOverlayView+E3.swift` | 본문 투명도 100%로 변경 |
| `GridViewController.swift` | viewDidAppear에 D 타이머/스캔 시작 호출 |
| `GridViewController+Cleanup.swift` | `showCleanupMethodSheet()` internal 변경 (트리거 2 코드 제거됨) |
| `Features/Grid/GridScroll.swift` | PreScanner pause/resume 연동 (3곳) |
| `App/SceneDelegate.swift` | debugReset() 호출 (주석 처리 상태) |

---

## 문구

| 항목 | 내용 |
|------|------|
| **타이틀** | 저품질 사진 발견 (24pt light, white) |
| **본문** | 흔들리거나 초점이 맞지 않은\n**저품질 사진을 AI가 자동**으로 찾아주는\n정리 기능을 사용해보세요 |
| **강조** | "저품질 사진을 AI가 자동" → bold + #FFEA00 |
| **버튼** | [확인] (흰색 pill, 120x44) |

---

## 트리거 조건

```
D 미표시 (UserDefaults)
  + A 완료 (gridSwipeDelete.hasBeenShown)
  + E-1 완료 (firstDeleteGuide.hasBeenShown)
  + 그리드 3초 체류 (Timer)
  + 스캔 결과 1장 이상
  + 다른 코치마크 미표시 (isShowing, 재시도 에스컬레이션)
  + 스크롤 중 아님 (isScrolling, 재시도)
  + VoiceOver 비활성
  + view.window, topViewController, presentedViewController, !isSelectMode
```

스캔 0건이면 D는 표시되지 않음 (별도 문구 없음).

---

## 검증 체크리스트

1. ✅ A 완료 + E-1 완료 + 그리드 3초 체류 → D 표시
2. ✅ A 미완료 → D 안 뜸 (로그: "타이머 스킵: A 미완료")
3. ✅ E-1 미완료 → D 안 뜸 (로그: "타이머 스킵: E-1 미완료")
4. ✅ 포커싱 모션 → 카드 페이드인 → [확인] → 탭 모션 → 정리 시트
5. ✅ 스캔 0건 → D 안 뜸
6. ✅ 스크롤 중 PreScanner 일시정지, 스크롤 종료 시 재개
7. ✅ 다른 코치마크 표시 중 → 재시도 (0.5초 × 10 → 3초)
8. ✅ D 표시 중 모든 터치 차단
9. ✅ D 완료 후 정리 버튼 탭 → 정상 정리 플로우
10. ✅ 앱 재실행 시 D 안 나타남 (UserDefaults)
