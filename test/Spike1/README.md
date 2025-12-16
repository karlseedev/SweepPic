# Spike 1: DiffableDataSource Benchmark

## 목적

DiffableDataSource가 10k/50k 규모에서 8.3ms(120Hz) 프레임 예산을 지키는지 검증

## 검증 시나리오

1. **Initial Load**: 스냅샷 생성 + apply
2. **Batch Delete (100)**: 100개 일괄 삭제
3. **Consecutive Delete (20x)**: 1개씩 20회 연속 삭제
4. **Delete while scroll**: 스크롤 중 삭제

## 실행 방법

### 1. Xcode에서 새 프로젝트 생성

1. Xcode → File → New → Project
2. iOS → App 선택
3. Product Name: `Spike1Test`
4. Interface: **Storyboard** (나중에 제거)
5. Language: Swift
6. 저장 위치: 이 폴더 (`test/Spike1/`)

### 2. 기존 파일 교체

1. 생성된 `ViewController.swift` 삭제
2. 생성된 `Main.storyboard` 삭제
3. 이 폴더의 Swift 파일들을 프로젝트에 추가:
   - `Spike1ViewController.swift`
   - `AppDelegate.swift` (기존 것 교체)
   - `SceneDelegate.swift` (기존 것 교체)

### 3. Info.plist 설정

프로젝트의 Info.plist에서 `Main storyboard file base name` 항목 삭제
(또는 이 폴더의 Info.plist 내용으로 교체)

### 4. 실행

1. 실제 기기 또는 시뮬레이터에서 실행
2. 상단 `10k` 또는 `50k` 버튼 탭
3. 하단에 결과 표시 (콘솔에도 출력)

## 판정 기준

| 결과 | 의미 |
|------|------|
| ✅ PASS | 8.3ms 이하, 기본안 유지 |
| ⚠️ OVER | 8.3ms 초과, Plan B 검토 필요 |

## 예상 결과

- 10k: 대부분 PASS 예상
- 50k: Initial Load는 OVER 가능, 삭제는 PASS 예상

Initial Load가 OVER여도 앱 시작 시 1회만 발생하므로 허용 가능.
삭제 시나리오가 PASS면 기본안(DiffableDataSource) 채택.
