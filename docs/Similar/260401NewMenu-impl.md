# 인물사진 비교정리 — 구현 계획

## Context

설계 문서 `docs/similar/260401NewMenu-logic.md`에 확정된 "인물사진 비교정리" 기능을 구현한다.
기존 간편정리 메뉴의 disabled 항목을 활성화하고, 최신 사진부터 인물사진 그룹을 자동 탐색하여 비교·정리하는 기능이다.

---

## Phase 1: 기반 모델 + 상수 변경

### 1-1. maxComparisonGroupSize 변경 (8→12)

**파일:** `SweepPic/Features/SimilarPhoto/Models/SimilarityConstants.swift:136`
```
nonisolated static let maxComparisonGroupSize: Int = 8  →  12
```

### 1-2. FaceScanMethod.swift (신규)

**위치:** `SweepPic/Features/FaceScan/Models/FaceScanMethod.swift`

CleanupMethod 패턴 참조 (`Features/AutoCleanup/Models/CleanupMethod.swift`)
```
enum FaceScanMethod: Codable, Equatable {
    case fromLatest
    case continueFromLast
    case byYear(year: Int, continueFrom: Date? = nil)
}
```
- displayTitle, description 등 UI 지원 computed property 포함

### 1-3. FaceScanProgress.swift (신규)

**위치:** `SweepPic/Features/FaceScan/Models/FaceScanProgress.swift`

CleanupProgress 패턴 참조 (`Features/AutoCleanup/Models/CleanupProgress.swift`)
```
struct FaceScanProgress {
    let scannedCount: Int
    let groupCount: Int
    let currentDate: Date
    let progress: Float
    let maxScanCount: Int      // 1,000
    let maxGroupCount: Int     // 30
}
```

### 1-4. FaceScanSession.swift (신규)

**위치:** `SweepPic/Features/FaceScan/Models/FaceScanSession.swift`
```
struct FaceScanSession: Codable {
    let lastAssetDate: Date
    let lastAssetID: String
    let scannedCount: Int
    let savedAt: Date
}
```

### 1-5. FaceScanGroup.swift (신규)

**위치:** `SweepPic/Features/FaceScan/Models/FaceScanGroup.swift`

FaceScanListVC가 보유하는 그룹 데이터 모델:
```
struct FaceScanGroup {
    let groupID: String
    let memberAssetIDs: [String]    // 원본 멤버 목록 (캐시 무효화와 무관)
    let validPersonIndices: Set<Int>
}
```

### 1-6. FaceScanConstants.swift (신규)

**위치:** `SweepPic/Features/FaceScan/Models/FaceScanConstants.swift`
```
enum FaceScanConstants {
    static let maxScanCount: Int = 1_000
    static let maxGroupCount: Int = 30
    static let chunkSize: Int = 20
    static let chunkOverlap: Int = 3
}
```

---

## Phase 2: 메뉴 연결 + 방식 선택 시트

### 2-1. 메뉴명 변경 + 활성화

**파일:** `SweepPic/Features/Grid/GridViewController+Cleanup.swift`

iOS 26+ (`setupSystemCleanupButton`, 라인 48-56):
```
변경 전: UIAction(title: "유사사진정리", attributes: .disabled) { _ in }
변경 후: UIAction(title: "인물사진 비교정리", image: ...) { [weak self] _ in self?.faceScanButtonTapped() }
```
```
변경 전: UIAction(title: "저품질자동정리", ...)
변경 후: UIAction(title: "저품질사진 자동정리", ...)
```

iOS 16~25 (`setupFloatingCleanupButton`, 라인 96-104): 동일 변경

### 2-2. GridViewController+FaceScan.swift (신규)

**위치:** `SweepPic/Features/FaceScan/GridViewController+FaceScan.swift`

GridViewController extension:
- `faceScanButtonTapped()` — 방식 선택 시트 표시
- `showFaceScanMethodSheet()` — FaceScanMethodSheet 생성/표시
- `FaceScanMethodSheetDelegate` 구현 — 선택된 method로 FaceScanListVC push

### 2-3. FaceScanMethodSheet.swift (신규)

**위치:** `SweepPic/Features/FaceScan/UI/FaceScanMethodSheet.swift`

CleanupMethodSheet 패턴 참조 (`Features/AutoCleanup/UI/CleanupMethodSheet.swift`)
- UIAlertController(.alert) 사용
- 타이틀: "인물사진 비교정리"
- 메시지: "비슷한 사진에서 같은 인물을\n찾아 얼굴을 비교합니다.\n마음에 들지 않는 사진을\n골라 정리할 수 있어요."
- 액션: 최신사진부터 / 이어서 정리 (조건부 활성) / 연도별 / 취소
- delegate: `FaceScanMethodSheetDelegate`

---

## Phase 3: 전용 캐시 + 스캔 서비스

### 3-1. FaceScanCache.swift (신규)

**위치:** `SweepPic/Features/FaceScan/Service/FaceScanCache.swift`

기존 `SimilarityCacheProtocol`을 준수하는 **FaceScan 전용 경량 캐시**.
기존 `SimilarityCache.shared`와 완전 격리 — 기존 그리드/뷰어 분석에 영향 제로.

```swift
actor FaceScanCache: SimilarityCacheProtocol {
    // 저장소
    private var groups: [String: SimilarThumbnailGroup] = [:]
    private var faces: [String: [CachedFace]] = [:]
    private var validSlots: [String: Set<Int>] = [:]

    // FaceComparisonVC가 사용하는 메서드 구현
    func getFaces(for assetID: String) -> [CachedFace]
    func getGroupMembers(groupID: String) -> [String]
    func getGroupValidPersonIndices(for groupID: String) -> Set<Int>
    func removeMemberFromGroup(_ assetID: String, groupID: String) -> Bool

    // FaceScanService가 분석 결과를 저장하는 메서드
    func addGroup(_ group: SimilarThumbnailGroup, validSlots: Set<Int>, photoFaces: [String: [CachedFace]])

    // SimilarityCacheProtocol의 나머지 메서드는 빈 구현
}
```

**생명주기:** FaceScanListVC가 소유 → 화면 닫히면 자연스럽게 해제

### 3-2. FaceScanService.swift (신규, 핵심)

**위치:** `SweepPic/Features/FaceScan/Service/FaceScanService.swift`

**핵심 전략: 기존 SimilarityAnalysisQueue를 호출하지 않고, 개별 분석기를 직접 사용**

기존 코드(SimilarityAnalysisQueue, SimilarityCache) **수정 없음**.
분석 도구(SimilarityAnalyzer, YuNetFaceDetector, SFaceRecognizer, FaceAligner)만 재사용.

```swift
class FaceScanService {
    // 분석 도구 (독립 인스턴스)
    private let analyzer = SimilarityAnalyzer()
    private let faceDetector = YuNetFaceDetector()
    private let faceRecognizer = SFaceRecognizer()
    private let faceAligner = FaceAligner()
    private let imageLoader = SimilarityImageLoader.shared  // 공유 (참조 카운팅)

    // 결과 저장소 (외부에서 주입)
    private let cache: FaceScanCache

    // 취소
    private var isCancelled = false
    private let lock = NSLock()

    func cancel() { ... }
}
```

**책임:**
- PHFetchResult 구성 (method별 predicate, 최신순 정렬)
- **삭제대기함 사진 제외** (TrashStore.shared.trashedAssetIDs 필터, 기존 fetchPhotos 패턴)
- 청크 단위 분석 루프 (chunkSize: 20, overlap: 3)
- 종료 조건: 1,000장 OR 30그룹 (먼저 도달 시)
- 진행률 콜백
- 취소 지원 (NSLock + isCancelled 체크)
- **열 상태(thermal) 모니터링** — ProcessInfo.thermalState 감지, 과열 시 동시성 축소 (기존 패턴)

**각 청크 분석 파이프라인 (formGroupsForRange 참조, 자체 구현):**

```
1. 이미지 로딩 + Feature Print 생성 (병렬)
   - SimilarityImageLoader.shared로 480px 이미지 로딩
   - VNGenerateImageFeaturePrintRequest 실행
   - VNDetectFaceRectanglesRequest로 얼굴 유무 확인
   → [VNFeaturePrintObservation?], [Bool] (hasFaces)

2. 그룹 형성
   - analyzer.formGroups(featurePrints:photoIDs:threshold:)
   → [[String]] (rawGroups, 최소 3장)

3. 얼굴 감지 + 인물 매칭 (그룹별)
   - SimilarityImageLoader로 960px 이미지 로딩
   - YuNetFaceDetector.detect() → [YuNetDetection]
   - FaceAligner.align() → 112×112 정렬 이미지
   - SFaceRecognizer.extractEmbedding() → [Float] 128차원
   - 코사인 유사도 기반 인물 슬롯 할당 (threshold: 0.363)
   → [String: [CachedFace]] (photoFacesMap)

4. 유효 슬롯 계산
   - personIndex가 2장 이상에서 나타나는 것만 유효
   - 유효 슬롯 얼굴이 있는 사진만 그룹 멤버로 인정
   → Set<Int> (validSlots), [String] (validMembers)

5. FaceScanCache에 결과 저장
   - cache.addGroup(group, validSlots, photoFaces)
   → FaceComparisonVC가 캐시에서 얼굴 데이터 조회 가능

6. onGroupFound 콜백
   - FaceScanGroup(groupID, memberAssetIDs, validPersonIndices) 전달
   → FaceScanListVC에 그룹 추가
```

**재사용하는 개별 분석기 (독립 인스턴스, 기존 코드 수정 없음):**
| 분석기 | 파일 | 사용 메서드 |
|--------|------|-----------|
| SimilarityAnalyzer | Analysis/SimilarityAnalyzer.swift | formGroups() |
| YuNetFaceDetector | Analysis/YuNet/YuNetFaceDetector.swift | detect() |
| SFaceRecognizer | Analysis/SFaceRecognizer.swift | extractEmbedding(), cosineSimilarity() |
| FaceAligner | Analysis/FaceAligner.swift | align() |
| SimilarityImageLoader | Analysis/SimilarityImageLoader.swift | .shared (공유, 참조 카운팅) |

**이어서 정리 fetch 조건:**
```swift
// continueFromLast일 때:
// creationDate <= lastDate인 사진 중, lastAssetID 이후부터 시작
// PHFetchOptions.predicate + fetchResult 순회 시 lastAssetID 위치 탐색
```

**세션 저장:**
- UserDefaults 패턴 (CleanupPreviewService 참조)
- 키: `FaceScanSession.lastScanDate`, `FaceScanSession.lastAssetID`
- 연도별: `FaceScanSession.byYear.*`
- static canContinue / lastScanDate 프로퍼티
- **분석 완료 시에만 저장** (취소 시 저장 안 함)

---

## Phase 4: 그룹 목록 UI

### 4-1. FaceScanListViewController.swift (신규, 핵심)

**위치:** `SweepPic/Features/FaceScan/UI/FaceScanListViewController.swift`

**스타일:** PreviewGridViewController 패턴 참조
- `view.backgroundColor = .systemBackground`
- `hidesBottomBarWhenPushed = true`
- iOS 26: 시스템 네비바 (`title = "인물사진 비교정리"`)
- iOS 16~25: 커스텀 헤더 (FloatingTitleBar 패턴 — 36pt light 타이틀, progressive blur)

**레이아웃 구조:**
```
┌─ 네비바 / 커스텀 헤더 ─────────────────┐
├─ FaceScanProgressBar (상단 고정, 48pt) ─┤
├─ UITableView (그룹 셀 목록) ────────────┤
│  또는 빈 상태 라벨 (중앙)               │
└─────────────────────────────────────────┘
```

**빈 상태 라벨:**
- 폰트: 17pt, .regular
- 색상: .secondaryLabel
- 정렬: 중앙
- 텍스트: "분석 중" / "비교할 인물사진 그룹을 찾지 못했습니다"

**데이터 관리:**
```swift
// 발견된 그룹 (콜백으로 추가)
private var groups: [FaceScanGroup] = []

// 그룹별 삭제 상태 (메모리에만 유지)
private var deletedAssetsByGroup: [String: Set<String>] = [:]

// 전용 캐시 (FaceComparisonVC에 주입)
private let faceScanCache = FaceScanCache()

// 스캔 서비스
private var scanService: FaceScanService?

// 분석 완료 여부
private var isAnalysisComplete: Bool = false

// 현재 열려있는 그룹 ID (delegate 콜백에서 사용)
private var presentedGroupID: String?
```

**lifecycle:**
```
viewDidLoad:
  - UI 구성 (tableView, progressBar, emptyLabel)
  - FaceScanService 시작 (cache: faceScanCache)
  - onGroupFound → groups.append + tableView insertRows (with animation)
  - onProgress → progressBar 업데이트
  - onComplete → isAnalysisComplete = true, progressBar fade out

viewWillAppear:
  - 비교 화면에서 돌아온 경우 dim 상태 갱신 (tableView.reloadData)

뒤로가기(pop) — willMove(toParent: nil):
  - isAnalysisComplete == false → scanService.cancel() + 데이터 버림
  - isAnalysisComplete == true → 세션은 이미 저장됨
```

**그룹 탭 → 비교 화면:**
```swift
func tableView(_, didSelectRowAt indexPath: IndexPath) {
    let group = groups[indexPath.row]
    presentedGroupID = group.groupID  // delegate에서 참조

    let comparisonGroup = ComparisonGroup(
        sourceGroupID: group.groupID,
        selectedAssetIDs: Array(group.memberAssetIDs.prefix(12)),
        personIndex: group.validPersonIndices.sorted().first ?? 1
    )
    let initialSelected = deletedAssetsByGroup[group.groupID] ?? []

    let vc = FaceComparisonViewController(
        comparisonGroup: comparisonGroup,
        mode: .faceScan(initialSelected: initialSelected),
        cache: faceScanCache  // ← 전용 캐시 주입
    )
    vc.delegate = self

    // present (fullScreen modal) — iOS 버전별 분기 (기존 뷰어 패턴)
    if #available(iOS 26.0, *) {
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    } else {
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
}
```

### 4-2. FaceScanGroupCell.swift (신규)

**위치:** `SweepPic/Features/FaceScan/UI/FaceScanGroupCell.swift`

UITableViewCell:

**레이아웃 스펙:**
| 속성 | 값 | 참조 |
|------|-----|------|
| 셀 높이 | 96pt | 썸네일 80pt + 상 8pt + 하 8pt |
| 썸네일 크기 | 80×80pt 정사각형 | |
| 썸네일 간격 | 4pt | 그리드 셀 간격 2pt보다 넓게 (독립 그룹 느낌) |
| 좌측 패딩 | 16pt | 앱 표준 margin (20pt에서 조정) |
| 우측 | 패딩 없음 (clipsToBounds로 잘림) | |
| 셀 배경 | .systemBackground | 앱 표준 |
| 구분선 | 셀 사이 1px 구분선 (.separator) | 앱 표준 패턴 |

**썸네일 스타일:** (PhotoCell 패턴)
| 속성 | 값 |
|------|-----|
| contentMode | .scaleAspectFill |
| backgroundColor | .systemGray6 (플레이스홀더) |
| clipsToBounds | true |
| cornerRadius | 0 (사각) |

**썸네일 로딩:** PHCachingImageManager, 80px 타겟 사이즈

**dim 상태:**
| 속성 | 값 |
|------|-----|
| 썸네일 영역 alpha | 0.3 |
| "정리 완료" 라벨 | 14pt .medium, .white, 셀 중앙 |
| "정리 완료" 배경 | 없음 (dim된 썸네일 위에 직접 표시) |
| 체크마크 | SF Symbol `checkmark.circle.fill`, .systemBlue, 라벨 좌측 |

### 4-3. FaceScanProgressBar.swift (신규)

**위치:** `SweepPic/Features/FaceScan/UI/FaceScanProgressBar.swift`

UIView (tableView 상단에 고정):

**레이아웃 스펙:**
| 속성 | 값 | 참조 |
|------|-----|------|
| 전체 높이 | 48pt | |
| 좌우 패딩 | 20pt | 앱 표준 |
| 상 패딩 | 8pt | |
| 하 패딩 | 8pt | |
| 프로그레스 바 높이 | UIProgressView 기본 (4pt) | |

**프로그레스 바 스타일:** (CleanupProgressView 패턴)
| 속성 | 값 |
|------|-----|
| tintColor | .systemBlue |
| trackTintColor | .systemGray5 |

**라벨 스타일:**
| 속성 | 값 |
|------|-----|
| 폰트 | 13pt, .regular |
| 색상 | .secondaryLabel |
| 정렬 | .center |
| 진행 중 | "N그룹 발견 · N / 1,000장 검색" |
| 완료 | "분석 완료 · N그룹 발견" |
| 0그룹 완료 | "분석 완료 · 발견된 그룹 없음" |

**fade out:** 완료 후 2초 대기 → UIView.animate(duration: 0.5) alpha → 0 → removeFromSuperview

---

## Phase 5: FaceComparisonVC 분기

### 5-1. 모드 enum 추가

**파일:** `SweepPic/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`

```swift
enum FaceComparisonMode {
    case viewer                                    // 기존 뷰어 동작
    case faceScan(initialSelected: Set<String>)    // FaceScan 재진입
}
```

### 5-2. init 확장

```swift
init(
    comparisonGroup: ComparisonGroup,
    mode: FaceComparisonMode = .viewer,    // 추가
    trashStore: TrashStoreProtocol = TrashStore.shared,
    cache: any SimilarityCacheProtocol = SimilarityCache.shared
)
```

- `.faceScan(initialSelected:)` 모드일 때 selectedAssetIDs를 초기값으로 설정
- viewDidLoad에서 초기 선택 상태 반영

### 5-3. deleteButtonTapped() 분기

```swift
@objc private func deleteButtonTapped() {
    switch mode {
    case .viewer:
        // 기존 로직 그대로

    case .faceScan(let initialSelected):
        let currentSelected = selectedAssetIDs
        let toDelete = currentSelected.subtracting(initialSelected)
        let toRestore = initialSelected.subtracting(currentSelected)

        // 새로 삭제
        if !toDelete.isEmpty {
            trashStore.moveToTrash(assetIDs: Array(toDelete))
        }
        // 복원 (방어: 실제 trash에 있는지 확인)
        if !toRestore.isEmpty {
            let actuallyTrashed = toRestore.filter { trashStore.isTrashed($0) }
            if !actuallyTrashed.isEmpty {
                trashStore.restore(assetIDs: Array(actuallyTrashed))
            }
        }

        delegate?.faceComparisonViewController(self, didApplyChanges: currentSelected)
    }
}
```

### 5-4. cancelButtonTapped() 분기

```swift
@objc private func cancelButtonTapped() {
    switch mode {
    case .viewer:
        // 기존 로직 그대로

    case .faceScan(let initialSelected):
        let hasChanges = selectedAssetIDs != initialSelected
        if hasChanges {
            // 팝업: "변경사항을 적용하시겠습니까?"
            showChangesAlert(initialSelected: initialSelected)
        } else {
            dismiss(animated: true) { [weak self] in
                self?.delegate?.faceComparisonViewControllerDidClose(self!)
            }
        }
    }
}

private func showChangesAlert(initialSelected: Set<String>) {
    let alert = UIAlertController(
        title: nil,
        message: "변경사항을 적용하시겠습니까?",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "적용", style: .default) { [weak self] _ in
        self?.applyDiffAndDismiss(initialSelected: initialSelected)
    })
    alert.addAction(UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
        self?.dismiss(animated: true) { ... didClose }
    })
    present(alert, animated: true)
}
```

### 5-5. FaceComparisonDelegate 확장

```swift
protocol FaceComparisonDelegate: AnyObject {
    // 기존
    func faceComparisonViewController(_:, didDeletePhotos:)
    func faceComparisonViewControllerDidClose(_:)
    // 추가 (FaceScan 모드용)
    func faceComparisonViewController(_:, didApplyChanges finalSelectedAssetIDs: Set<String>)
}

// 기본 구현 (기존 코드 깨지지 않도록)
extension FaceComparisonDelegate {
    func faceComparisonViewController(_:, didApplyChanges:) {}
}
```

### 5-6. FaceScanListVC의 delegate 구현

FaceScan 모드에서는 첫 진입이든 재진입이든 항상 `didApplyChanges`가 호출됨.
(첫 진입: initialSelected = [] → diff = 선택한 것 전부 새 삭제)
`didDeletePhotos`는 기존 뷰어(.viewer 모드)에서만 호출됨.

```swift
extension FaceScanListViewController: FaceComparisonDelegate {
    func faceComparisonViewController(_, didApplyChanges finalSelected: Set<String>) {
        guard let groupID = presentedGroupID else { return }
        // 최종 선택 상태로 교체 + dim 갱신
        deletedAssetsByGroup[groupID] = finalSelected
        presentedGroupID = nil
        dismiss(animated: true) { [weak self] in
            self?.tableView.reloadData()  // dim 상태 반영
        }
    }

    func faceComparisonViewControllerDidClose(_ vc: FaceComparisonViewController) {
        presentedGroupID = nil
        // 아무것도 안 하고 닫음 (변경사항 없이 뒤로가기)
    }

    // 기존 뷰어용 — FaceScan에서는 호출되지 않음
    func faceComparisonViewController(_, didDeletePhotos: [String]) {}
}
```

---

## Phase 6: 세션 저장 + 이어서 정리

### 6-1. FaceScanService 내 세션 저장

CleanupPreviewService 패턴 참조:
```swift
// UserDefaults 키
private static let lastScanDateKey = "FaceScanSession.lastScanDate"
private static let lastAssetIDKey = "FaceScanSession.lastAssetID"
private static let byYearLastScanDateKey = "FaceScanSession.byYear.lastScanDate"
private static let byYearLastAssetIDKey = "FaceScanSession.byYear.lastAssetID"
private static let byYearYearKey = "FaceScanSession.byYear.year"
private static let byYearCanContinueKey = "FaceScanSession.byYear.canContinue"

// static 접근
static var canContinue: Bool { lastScanDate != nil }
static var lastScanDate: Date? { UserDefaults... }

// 연도별
static func canContinueByYear(_ year: Int) -> Bool { ... }
static func lastScanDateByYear(_ year: Int) -> Date? { ... }
```

### 6-2. FaceScanMethodSheet에서 canContinue 연동

- `FaceScanService.canContinue` == true → "이어서 정리" 활성화
- `FaceScanService.lastScanDate` → 날짜 표시

---

## Phase 7: 통합 테스트 + 정리

### 7-1. 빈 상태 UI 최종 확인
- 분석 중 + 0그룹: "분석 중" 텍스트
- 분석 완료 + 0그룹: "비교할 인물사진 그룹을 찾지 못했습니다"

### 7-2. dim 상태 갱신 로직
- 비교 화면에서 돌아온 후 viewWillAppear에서 dim 갱신
- deletedAssetsByGroup이 빈 Set → dim 해제
- deletedAssetsByGroup이 비어있지 않음 → dim 유지

### 7-3. 진행바 fade out
- 분석 완료 → "분석 완료 · N그룹 발견" → 2~3초 후 UIView.animate fadeOut

### 7-4. 뒤로가기(pop) 인터셉트
- UINavigationControllerDelegate 또는 willMove(toParent:) 오버라이드
- 분석 중 → Task.cancel()
- 분석 완료 → 세션 이미 저장됨, 추가 작업 없음

---

## 수정 대상 기존 파일 목록

| 파일 | 변경 내용 |
|------|----------|
| `SimilarPhoto/Models/SimilarityConstants.swift` | maxComparisonGroupSize 8→12 |
| `SimilarPhoto/UI/FaceComparisonViewController.swift` | mode enum, init 확장, delete/cancel 분기 |
| `Grid/GridViewController+Cleanup.swift` | 메뉴명 변경 + 활성화 |

**수정하지 않는 기존 파일 (완전 격리):**
- `SimilarityAnalysisQueue.swift` — 수정 없음
- `SimilarityCache.swift` — 수정 없음
- `AnalysisRequest.swift` — 수정 없음 (.faceScan 불필요, 전용 서비스 사용)

## 신규 파일 목록

| 파일 | 역할 |
|------|------|
| `FaceScan/Models/FaceScanMethod.swift` | 스캔 방식 enum |
| `FaceScan/Models/FaceScanProgress.swift` | 진행 상황 모델 |
| `FaceScan/Models/FaceScanSession.swift` | 세션 데이터 (Codable) |
| `FaceScan/Models/FaceScanGroup.swift` | 그룹 데이터 모델 |
| `FaceScan/Models/FaceScanConstants.swift` | 상수 정의 |
| `FaceScan/Service/FaceScanCache.swift` | 전용 캐시 (SimilarityCacheProtocol) |
| `FaceScan/Service/FaceScanService.swift` | 스캔 엔진 |
| `FaceScan/UI/FaceScanMethodSheet.swift` | 방식 선택 시트 |
| `FaceScan/UI/FaceScanListViewController.swift` | 그룹 목록 화면 |
| `FaceScan/UI/FaceScanGroupCell.swift` | 그룹 셀 |
| `FaceScan/UI/FaceScanProgressBar.swift` | 미니 진행바 |
| `FaceScan/GridViewController+FaceScan.swift` | 메뉴 연결 |

## 검증 방법

1. **빌드 확인**: `xcodebuild -project SweepPic/SweepPic.xcodeproj -scheme SweepPic -destination 'platform=iOS Simulator,name=iPhone 17'`
2. **메뉴 동작**: 간편정리 > 인물사진 비교정리 탭 → 방식 선택 시트 표시
3. **분석 흐름**: 최신사진부터 → 빈 목록 진입 → 그룹 하나씩 추가 → 진행바 업데이트
4. **비교 화면**: 그룹 탭 → FaceComparisonVC present → 삭제 → dismiss → dim 처리
5. **재진입**: dim 그룹 탭 → 선택 상태 유지 → 수정 → 삭제(diff) 또는 뒤로가기(팝업)
6. **이어서 정리**: 분석 완료 후 닫기 → 다시 메뉴 → 이어서 정리 활성화
7. **12장 제한**: 뷰어에서 +버튼 → 비교 화면 최대 12장 표시

---

## Phase 8: UI 레이아웃 수정 (구현 후 발견된 문제)

### 근본 원인: 레이아웃 구조가 PreviewGridVC 패턴과 다름

```
현재 (잘못됨):
  [헤더] ← 고정
  [진행바] ← 고정 (48pt) — fade out 해도 공간 남음
  [테이블뷰] ← 진행바 아래부터

변경 (PreviewGridVC 패턴):
  [테이블뷰] ← view 전체 (edge-to-edge, top=view.top)
  [헤더] ← 오버레이 (view 위에)
  [진행바] ← 오버레이 (헤더 아래)
  → contentInset.top = 헤더 + 진행바
  → 진행바 fade out 시 contentInset 줄임 → 테이블 자연스럽게 올라감
```

### 수정 대상 파일: 3개

**FaceScanListViewController.swift** — 대폭 수정
**FaceScanProgressBar.swift** — 일부 수정
**FaceScanGroupCell.swift** — 사소한 수정

### 수정 항목 상세 (12개)

#### FaceScanListViewController.swift

**#1. 테이블뷰 edge-to-edge 변경**
- 현재: `tableView.top = progressBar.bottom`
- 변경: `tableView.top = view.top`, `bottom = view.bottom` (PreviewGridVC:217-220)
- `contentInsetAdjustmentBehavior = .never` 추가

**#2. 미사용 변수 `progressTopAnchor` 제거** (:162-169)
- 선언만 하고 사용 안 함

**#3. 진행바를 오버레이로 변경**
- 현재: auto layout으로 고정 (테이블뷰 위)
- 변경: view 위에 오버레이 (테이블뷰 위에 떠있는 구조)
- top = 커스텀 헤더 아래 (iOS 16~25) / safeArea.top (iOS 26)

**#4. contentInset 동적 관리 추가**
- `updateTableViewInsets()` 메서드 추가
- top = 헤더높이 + 진행바높이 (진행 중) → 헤더높이만 (진행 완료 후)
- bottom = safeAreaInsets.bottom
- `viewSafeAreaInsetsDidChange()`에서 호출

**#5. 진행바 fade out 시 contentInset 갱신**
- fade out 애니메이션과 함께 contentInset.top 줄임
- 테이블이 자연스럽게 올라감

**#6. 진행바 높이 constraint 참조 보유**
- `progressBarHeightConstraint` 프로퍼티 추가
- fade out 시 height를 0으로 애니메이션 (또는 isHidden + inset 갱신)

**#7. deinit 추가 — Task 취소**
```swift
deinit {
    scanTask?.cancel()
}
```

**#8. emptyLabel topAnchor 제약 추가**
- `emptyLabel.top >= progressBar.bottom + 20` (겹침 방지)

**#9. iOS 26 setupHeader 명시화**
- 빈 주석 → `navigationItem.hidesBackButton = false` 명시

**#10. 헤더/진행바를 테이블뷰 뒤에 addSubview 후 bringToFront**
- PreviewGridVC 패턴: collectionView → setupHeader → bringToFront

#### FaceScanProgressBar.swift

**#11. removeFromSuperview 제거**
- 현재: fade out 완료 시 `removeFromSuperview()` 호출
- 변경: `isHidden = true`만 (constraint 유지)
- 부모(FaceScanListVC)에서 contentInset 갱신 담당

#### FaceScanGroupCell.swift

**#12. 확인 완료 — 사소한 수정 없음**
- 재사용 안전장치 ✅
- dim 처리 ✅
- 썸네일 로딩 ✅

### iOS 16~25 vs 26 분기 확인

| 항목 | iOS 16~25 | iOS 26 | 상태 |
|------|-----------|--------|------|
| 네비바 | 숨김 유지 (TabBarController:192) | 시스템 표시 | ✅ |
| FloatingOverlay | prefersFloatingOverlayHidden=true | 없음 | ✅ |
| 헤더 | 커스텀 (blur+딤+backButton+타이틀) | 시스템 네비바 | ✅ |
| 뒤로가기 | 커스텀 backButton | 시스템 자동 | ✅ |
| contentInset.top | 헤더높이(safeArea+44+35) + 진행바(48) | safeArea.top + 진행바(48) | ✅ |
| FaceComparisonVC present | 직접 present | NavController 감싸기 | ✅ |
| 스와이프 백 | 네비바 숨김→비활성 가능 (PreviewGridVC도 동일) | 정상 | ✅ 허용 |
