# FirstLoading1: 앱 시작 → 첫 화면 표시 성능 분석

> **날짜**: 2026-02-17
> **상태**: 분석 완료
> **증상**: Xcode Cmd+R 후 앱 실행 → 첫 화면 표시까지 10초 이상 (iOS 26에서 더 느림)
> **결론**: LLDB 디버거가 원인. 앱 코드 자체는 495ms (정상)

---

## 1. 측정 환경

- Xcode, Debug 빌드
- iOS 26 베타

## 2. 측정 방법

### 추가한 코드

| 파일 | 변경 내용 |
|------|----------|
| `Log.swift` | `"Launch": true` 카테고리 추가 (앱 상태/초기화 섹션) |
| `AppDelegate.swift` | `recordLaunchTimestamps()` — sysctl로 프로세스 fork 시각 + didFinishLaunching 시각을 static에 저장 |
| `GridScroll.swift` | `finishInitialDisplay()`에서 한 줄 합산 로그 출력 |

### 측정 원리

```
[프로세스 fork] ──A──→ [didFinishLaunching] ──B──→ [finishInitialDisplay]
                                                     (collectionView.alpha = 1)

A = LLDB attach + dyld 로딩 + pre-main (sysctl p_starttime 기반)
B = 앱 코드 구간 (SceneDelegate → TabBar → GridVC → 데이터 로드 → 프리로드 → 화면 표시)
```

### 로그 형식

```
[Launch] 총 {A+B}ms | LLDB+dyld: {A}ms | 앱→화면: {B}ms
```

## 3. 측정 결과

### 3-1. Cmd+R (디버거 O)

```
[Launch] 총 13977ms | LLDB+dyld: 6032ms | 앱→화면: 7945ms
```

### 3-2. Cmd+Ctrl+R (빌드 스킵, 디버거 O)

```
[Launch] 총 13425ms | LLDB+dyld: 5405ms | 앱→화면: 8019ms
```

### 3-3. Debug executable 해제 (디버거 X, Debug 빌드)

Scheme → Run → Info → Debug executable 체크 해제

**iOS 25:**
```
[Launch] 총 495ms | LLDB+dyld: 195ms | 앱→화면: 300ms
```

**iOS 26:**
```
[Launch] 총 866ms | LLDB+dyld: 317ms | 앱→화면: 549ms
```

### 전체 비교

| 구간 | 디버거 O (iOS 25) | 디버거 X (iOS 25) | 디버거 X (iOS 26) |
|------|-----------------|-----------------|-----------------|
| LLDB+dyld | 6,032ms | **195ms** | **317ms** |
| 앱→화면 | 7,945ms | **300ms** | **549ms** |
| **총** | **13,977ms** | **495ms** | **866ms** |

- iOS 26은 iOS 25 대비 약 1.75배 느림 (베타 OS 미최적화)
- 양쪽 다 1초 미만 → 정상

## 4. 결론

### 앱 코드: 정상 (495ms)

- 프로세스 fork → 첫 화면 표시: **0.5초**
- didFinishLaunching까지 195ms, 앱 코드 구간 300ms
- 최적화 불필요

### LLDB 디버거가 전체 원인

1. **Attach 오버헤드 (~5.8초)**: 프로세스에 디버거를 연결하는 시간
2. **실행 속도 저하 (26배)**: LLDB가 연결된 상태에서 앱 코드 실행이 300ms → 8,000ms로 느려짐
   - 브레이크포인트 인터셉트 오버헤드
   - 심볼 해석 및 메모리 감시
   - iOS 26 베타 + 새 Swift 런타임 interop 비용

### iOS 26 vs iOS 25 (디버거 X 비교)

- iOS 26이 약 1.75배 느림 (495ms → 866ms)
- 베타 OS = 시스템 라이브러리 미최적화
- 양쪽 다 1초 미만이므로 실사용에 문제 없음

## 5. 대응 방안

| 방법 | 설정 | 효과 |
|------|------|------|
| **Debug executable 해제** | Scheme → Run → Debug executable OFF | 14초 → 0.5초 (디버거 불가) |
| **브레이크포인트 전체 비활성화** | Cmd+Y | 디버거 연결 상태에서 부분 개선 |
| **Release 빌드** | Build Configuration: Release | 컴파일러 최적화 추가 적용 |

> **권장**: 일상적 UI 작업 시 Debug executable 해제, 디버깅 필요 시에만 체크
