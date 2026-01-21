# Quickstart: 저품질 사진 자동 정리

**Feature**: 001-auto-cleanup
**Date**: 2026-01-21

---

## 개요

이 문서는 자동 정리 기능의 빠른 이해와 개발 시작을 위한 가이드입니다.

---

## 1. 핵심 흐름

```
[정리 버튼 탭]
      │
      ▼
[휴지통 비었는지 확인] ──(안 비었음)──▶ "휴지통을 먼저 비워주세요"
      │
      │ (비었음)
      ▼
[정리 방식 선택 시트]
      │
      ├─ 최신사진부터 정리
      ├─ 이어서 정리
      └─ 연도별 정리 > (연도 선택)
            │
            ▼
      [탐색 시작]
            │
            ├──▶ 배치(100장) 로드
            │         │
            │         ▼
            │    [품질 분석] ──(저품질)──▶ 휴지통 이동
            │         │
            │    [종료 조건 체크]
            │         │
            │         ├─ 50장 찾음? → 종료
            │         ├─ 1,000장 검색? → 종료
            │         └─ 범위 끝? → 종료
            │         │
            └─────────┘
                  │
                  ▼
         [결과 알림 표시]
```

---

## 2. 품질 분석 파이프라인

### iOS 18+

```swift
// 1. 메타데이터 필터
if asset.isFavorite || asset.hasAdjustments || asset.isHidden {
    return .skipped
}

// 2. AestheticsScore 분석
let score = try await AestheticsAnalyzer.analyze(image)
if score.overallScore < -0.3 {  // Precision 모드
    // 3. Safe Guard 체크
    if !SafeGuard.shouldProtect(asset) {
        return .lowQuality
    }
}
```

### iOS 16-17

```swift
// Stage 1: 메타데이터 필터
if asset.shouldSkipForCleanup {
    return .skipped
}

// Stage 2: 노출 분석 (64×64)
let exposure = ExposureAnalyzer.analyze(thumbnail64)
if exposure.meanLuminance < 0.10 {
    return .lowQuality  // 극단 어두움 - 조기 종료
}

// Stage 3: 블러 분석 (256×256)
let blur = try await BlurAnalyzer.analyze(thumbnail256)
if blur.laplacianVariance < 50 {
    // Stage 4: Safe Guard 체크
    if !SafeGuard.shouldProtect(asset) {
        return .lowQuality  // 심각 블러
    }
}

return .acceptable
```

---

## 3. 핵심 클래스

### CleanupService

정리 실행의 중심 서비스.

```swift
class CleanupService: CleanupServiceProtocol {

    func startCleanup(
        method: CleanupMethod,
        mode: JudgmentMode,
        progressHandler: @escaping (CleanupProgress) -> Void,
        completion: @escaping (Result<CleanupResult, CleanupError>) -> Void
    ) {
        // 1. 휴지통 확인
        guard trashStore.trashedCount == 0 else {
            completion(.failure(.trashNotEmpty))
            return
        }

        // 2. 세션 생성
        let session = CleanupSession(method: method, mode: mode)
        sessionStore.save(session)

        // 3. 탐색 시작
        Task {
            await scanAndAnalyze(
                session: session,
                progressHandler: progressHandler,
                completion: completion
            )
        }
    }
}
```

### QualityAnalyzer

품질 분석 코디네이터.

```swift
class QualityAnalyzer: QualityAnalyzerProtocol {

    func analyze(asset: PHAsset, mode: JudgmentMode) async throws -> QualityResult {

        // iOS 버전별 분기
        if #available(iOS 18.0, *) {
            if let result = await analyzeWithAesthetics(asset, mode) {
                return result
            }
            // fallback to Metal pipeline
        }

        return try await analyzeWithMetal(asset, mode)
    }
}
```

---

## 4. UI 컴포넌트

### 정리 버튼 배치

```swift
// GridViewController.swift
// 그리드 화면 상단, 셀렉트 버튼 왼쪽

private lazy var cleanupButton: CleanupButton = {
    let button = CleanupButton()
    button.addTarget(self, action: #selector(cleanupButtonTapped), for: .touchUpInside)
    return button
}()

@objc private func cleanupButtonTapped() {
    // 휴지통 확인 → 방식 선택 시트 표시
    if trashStore.trashedCount > 0 {
        showTrashNotEmptyAlert()
    } else {
        showCleanupMethodSheet()
    }
}
```

### 진행 화면

```
┌─────────────────────────────────┐
│  2026년 5월부터 탐색 중...       │
│  ████████░░░░░░░░  23/50        │
│                      [취소]     │
└─────────────────────────────────┘
```

```swift
class CleanupProgressView: UIView {
    let titleLabel: UILabel       // "2026년 5월부터 탐색 중..."
    let progressBar: UIProgressView
    let countLabel: UILabel       // "23/50"
    let cancelButton: UIButton
}
```

---

## 5. 파일 구조

```
PickPhoto/PickPhoto/Features/AutoCleanup/
├── Models/
│   ├── CleanupSession.swift       # 세션 상태
│   ├── QualitySignal.swift        # 품질 신호
│   └── CleanupResult.swift        # 결과
├── Analysis/
│   ├── QualityAnalyzer.swift      # 코디네이터
│   ├── ExposureAnalyzer.swift     # 노출 분석
│   ├── BlurAnalyzer.swift         # 블러 분석 (Metal)
│   ├── AestheticsAnalyzer.swift   # iOS 18+ API
│   └── SafeGuard.swift            # 안전장치
├── Services/
│   ├── CleanupService.swift       # 메인 서비스
│   └── CleanupSessionStore.swift  # 세션 저장
└── UI/
    ├── CleanupButton.swift
    ├── CleanupMethodSheet.swift
    ├── CleanupProgressView.swift
    └── CleanupResultAlert.swift
```

---

## 6. 테스트 시작점

### Unit Test 예시

```swift
// ExposureAnalyzerTests.swift
func testExtremeDarkImage() {
    let analyzer = ExposureAnalyzer()
    let darkImage = createTestImage(luminance: 0.05)

    let result = analyzer.analyze(image: darkImage, mode: .precision)

    XCTAssertEqual(result.meanLuminance, 0.05, accuracy: 0.01)
    XCTAssertTrue(result.shouldTerminateEarly)
    XCTAssertEqual(result.signals.first?.kind, .extremeDark)
}
```

### Integration Test 예시

```swift
// CleanupServiceTests.swift
func testCleanupFromLatest() async {
    let service = CleanupService(
        trashStore: MockTrashStore(),
        sessionStore: MockSessionStore()
    )

    let expectation = expectation(description: "cleanup complete")

    service.startCleanup(
        method: .fromLatest,
        mode: .precision,
        progressHandler: { _ in },
        completion: { result in
            switch result {
            case .success(let cleanupResult):
                XCTAssertLessThanOrEqual(cleanupResult.foundCount, 50)
            case .failure:
                XCTFail("Cleanup should succeed")
            }
            expectation.fulfill()
        }
    )

    await fulfillment(of: [expectation], timeout: 60)
}
```

---

## 7. 개발 순서 권장

1. **Models 먼저**: CleanupSession, QualitySignal 정의
2. **Store 구현**: CleanupSessionStore (파일 저장/로드)
3. **개별 Analyzer**: Exposure → Blur → SafeGuard → Aesthetics
4. **QualityAnalyzer**: 코디네이터로 통합
5. **CleanupService**: 탐색 로직 구현
6. **UI**: 버튼 → 시트 → 진행 화면 → 결과 알림

---

## 8. 디버깅 팁

### 로그 활성화

```swift
// CleanupDebug.swift
#if DEBUG
static func logAnalysis(_ result: QualityResult) {
    print("[Cleanup] Asset: \(result.assetID.prefix(8))")
    print("[Cleanup] Verdict: \(result.verdict)")
    print("[Cleanup] Signals: \(result.signals.map { $0.kind.rawValue })")
    print("[Cleanup] Time: \(result.analysisTimeMs)ms")
}
#endif
```

### 임계값 오버라이드 (테스트용)

```swift
// UserDefaults로 임계값 오버라이드 가능하게 설계
extension CleanupConstants {
    static var extremeDarkLuminance: Double {
        UserDefaults.standard.double(forKey: "debug.cleanup.darkLuminance").nonZero ?? 0.10
    }
}
```

---

## 9. 주의사항

1. **iCloud 사진**: `networkAccessAllowed = false` 필수
2. **AestheticsScore 시뮬레이터**: 미지원, 실기기 테스트 필요
3. **Face Quality**: Apple 권고와 다르게 절대 임계값 사용 - 오탐 주의
4. **백그라운드**: 30초 제약, 일시정지/재개 구현 필수
5. **메모리**: 배치 처리로 메모리 관리, autoreleasepool 사용

---

## 10. 관련 문서

- [spec.md](./spec.md) - 기능 명세
- [plan.md](./plan.md) - 구현 계획
- [research.md](./research.md) - 기술 연구
- [data-model.md](./data-model.md) - 데이터 모델
- [contracts/cleanup-service.md](./contracts/cleanup-service.md) - API 계약
- [docs/autodel/260120AutoDel.md](../../docs/autodel/260120AutoDel.md) - 원본 기획서
