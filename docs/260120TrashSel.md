# 앨범/휴지통 선택 모드 구현 계획

**작성일**: 2026-01-20
**브랜치**: 001-auto-cleanup
**선행 작업**: BaseGridViewController 리팩토링 완료 (260120refac.md)

## 개요

선택 모드를 Base로 공통화한 후, 앨범(AlbumGridViewController)과 휴지통(TrashAlbumViewController)에 선택 모드를 활성화합니다.

## 설계 결정

1. **"비우기"와 "Select" 버튼**: 두 버튼 동시 표시
   - iOS 26+: `rightBarButtonItems = [selectButton, emptyButton]`
   - iOS 16~25: FloatingTitleBar 수정하여 Right 버튼 2개 지원

2. **드래그 선택**: 모든 화면에서 제공 (Grid/Album/Trash 동일)

3. **선택 모드 파일 구조**: 기능별 분리 (방식 C)
   - Grid/Album 공용: GridSelectMode.swift
   - Trash 전용: TrashSelectMode.swift

## 파일 구조

```
Features/Grid/
├── BaseGridViewController.swift    (프로퍼티 추가)
├── BaseSelectMode.swift            (신규 - 공통 선택 모드 로직)
├── GridSelectMode.swift            (수정 - Grid/Album 공용)
├── TrashSelectMode.swift           (신규 - Trash 전용)
└── ...

Features/Albums/
├── AlbumGridViewController.swift   (선택 모드 코드 없음 - GridSelectMode 사용)
├── TrashAlbumViewController.swift  (선택 모드 코드 없음 - TrashSelectMode 사용)
└── ...

Shared/Components/
├── FloatingTitleBar.swift          (수정 - Right 버튼 2개 지원)
├── FloatingTabBar.swift            (수정 - 휴지통 선택 모드 UI)
└── ...
```

## 각 VC별 선택 모드 차이점

| 항목 | 사진보관함 (Grid) | 앨범 (Album) | 휴지통 (Trash) |
|------|-----------------|--------------|---------------|
| 선택 모드 파일 | GridSelectMode | GridSelectMode | **TrashSelectMode** |
| iOS 26+ 툴바 | [선택개수] [Delete] | [선택개수] [Delete] | **[Restore] [선택개수] [Delete]** |
| iOS 26+ 네비바 | [Select] | [Select] | [Select] [비우기] |
| 플로팅 TabBar | selectModeContainer | selectModeContainer | **trashSelectModeContainer** |
| 플로팅 TitleBar | [Select] | [Select] | [Select] [비우기] |
| Delete 동작 | 휴지통 이동 | 휴지통 이동 | **영구 삭제** |
| Restore 동작 | 없음 | 없음 | **복원** |
| 드래그 선택 | ✅ | ✅ | ✅ |

---

## Phase 0: Base 선택 모드 공통화

### 0.1 BaseGridViewController.swift에 프로퍼티 추가

```swift
// MARK: - Select Mode Properties

var isSelectMode: Bool = false
let selectionManager = SelectionManager()
var selectionCountBarItem: UIBarButtonItem?

// 드래그 선택 관련
var dragSelectGesture: UIPanGestureRecognizer?
var dragSelectStartIndex: Int?
var dragSelectCurrentIndex: Int?
var dragSelectAffectedIndices: Set<Int> = []
var dragSelectIsSelecting: Bool = true
```

### 0.2 BaseSelectMode.swift 생성 (~300줄)

공통 선택 모드 로직:

```swift
// BaseSelectMode.swift
// BaseGridViewController의 Select Mode 공통 기능

import UIKit
import Photos
import AppCore

// MARK: - Select Mode Template Methods

extension BaseGridViewController {

    /// 선택 모드 지원 여부 (서브클래스에서 오버라이드)
    @objc var supportsSelectMode: Bool { false }

    /// iOS 26+ 툴바 버튼 구성 (서브클래스에서 오버라이드)
    @objc func setupSelectionToolbar() -> [UIBarButtonItem] { [] }

    /// 툴바 선택 개수 업데이트 (서브클래스에서 오버라이드)
    @objc func updateSelectionToolbar(count: Int) {}

    /// iOS 26+ Select 종료 후 네비바 복원 (서브클래스에서 오버라이드)
    @objc func restoreNavigationBarAfterSelectMode() {
        if #available(iOS 26.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Select",
                style: .plain,
                target: self,
                action: #selector(selectButtonTapped)
            )
        }
    }
}

// MARK: - Select Mode Enter/Exit

extension BaseGridViewController {

    func enterSelectMode() {
        guard supportsSelectMode else { return }
        guard !isSelectMode else { return }
        isSelectMode = true

        if #available(iOS 26.0, *) {
            enterSelectModeSystemUI()
        } else {
            enterSelectModeFloatingUI()
        }

        dragSelectGesture?.isEnabled = true
        updateSwipeDeleteGestureEnabled()
        collectionView.reloadData()
    }

    func exitSelectMode() {
        guard isSelectMode else { return }
        isSelectMode = false

        if #available(iOS 26.0, *) {
            exitSelectModeSystemUI()
        } else {
            exitSelectModeFloatingUI()
        }

        dragSelectGesture?.isEnabled = false
        updateSwipeDeleteGestureEnabled()
        selectionManager.clearSelection()
        collectionView.reloadData()
    }
}

// MARK: - iOS 26+ System UI

extension BaseGridViewController {

    @available(iOS 26.0, *)
    func enterSelectModeSystemUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelSelectModeTapped)
        )
        tabBarController?.tabBar.isHidden = true
        toolbarItems = setupSelectionToolbar()
        navigationController?.setToolbarHidden(false, animated: true)
    }

    @available(iOS 26.0, *)
    func exitSelectModeSystemUI() {
        navigationController?.setToolbarHidden(true, animated: true)
        tabBarController?.tabBar.isHidden = false
        restoreNavigationBarAfterSelectMode()
    }

    @objc func cancelSelectModeTapped() {
        exitSelectMode()
    }

    @objc func selectButtonTapped() {
        enterSelectMode()
    }
}

// MARK: - iOS 16~25 Floating UI (기본 구현 - Grid/Album용)

extension BaseGridViewController {

    /// 플로팅 UI 선택 모드 진입 (Trash에서 오버라이드)
    func enterSelectModeFloatingUI() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.enterSelectMode { [weak self] in
            self?.exitSelectMode()
        }
        overlay.tabBar.enterSelectMode(animated: true)
    }

    /// 플로팅 UI 선택 모드 종료 (Trash에서 오버라이드)
    func exitSelectModeFloatingUI() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.exitSelectMode()
        overlay.tabBar.exitSelectMode(animated: true)
    }

    /// 플로팅 UI 선택 개수 업데이트 (Trash에서 오버라이드)
    func updateSelectionCountFloatingUI(_ count: Int) {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }
        overlay.tabBar.updateSelectionCount(count)
    }
}

// MARK: - Drag Selection

extension BaseGridViewController {

    func setupDragSelectGesture() {
        guard supportsSelectMode else { return }

        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDragSelect(_:)))
        dragGesture.delegate = self
        dragGesture.isEnabled = false
        collectionView.addGestureRecognizer(dragGesture)
        dragSelectGesture = dragGesture
    }

    @objc func handleDragSelect(_ gesture: UIPanGestureRecognizer) {
        // 드래그 선택 로직 (기존 GridSelectMode.swift에서 이동)
    }
}

// MARK: - SelectionManagerDelegate

extension BaseGridViewController: SelectionManagerDelegate {

    public func selectionManager(_ manager: SelectionManager, didChangeSelection assetIDs: Set<String>) {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard indexPath.item >= paddingCellCount else { continue }
            let assetIndex = indexPath.item - paddingCellCount
            guard let asset = gridDataSource.asset(at: assetIndex) else { continue }

            if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
                cell.isSelectedForDeletion = assetIDs.contains(asset.localIdentifier)
            }
        }
    }

    public func selectionManager(_ manager: SelectionManager, selectionCountDidChange count: Int) {
        if #available(iOS 26.0, *) {
            updateSelectionToolbar(count: count)
        } else {
            updateSelectionCountFloatingUI(count)
        }
    }
}

// MARK: - Setup

extension BaseGridViewController {

    func setupSelectionManagerDelegate() {
        selectionManager.delegate = self
    }
}
```

### 0.3 cellForItemAt에서 선택 상태 복원

```swift
// BaseGridViewController.swift - cellForItemAt 수정

if isSelectMode {
    cell.isSelectedForDeletion = selectionManager.isSelected(asset.localIdentifier)
}
```

---

## Phase 1: GridSelectMode.swift 수정 (Grid/Album 공용)

### 1.1 Grid/Album 공용으로 확장 (~100줄)

```swift
// GridSelectMode.swift
// Grid/Album 공용 선택 모드

import UIKit
import Photos
import AppCore

// MARK: - Grid/Album Select Mode Support

extension GridViewController {
    override var supportsSelectMode: Bool { true }
}

extension AlbumGridViewController {
    override var supportsSelectMode: Bool { true }
}

// MARK: - Grid/Album 공용 툴바 (BaseGridViewController extension)

extension BaseGridViewController {

    /// Grid/Album 공용 툴바: [flex] [선택개수] [flex] [Delete]
    /// GridViewController, AlbumGridViewController에서 사용
    func setupGridAlbumSelectionToolbar() -> [UIBarButtonItem] {
        let countLabel = UILabel()
        countLabel.text = "항목 선택"
        countLabel.font = .systemFont(ofSize: 17)
        let countItem = UIBarButtonItem(customView: countLabel)
        selectionCountBarItem = countItem

        let deleteItem = UIBarButtonItem(
            title: "Delete",
            style: .plain,
            target: self,
            action: #selector(gridAlbumDeleteSelectedTapped)
        )
        deleteItem.tintColor = .systemRed

        return [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            countItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            deleteItem
        ]
    }

    func updateGridAlbumSelectionToolbar(count: Int) {
        if let countItem = selectionCountBarItem,
           let label = countItem.customView as? UILabel {
            label.text = count > 0 ? "\(count)개 항목 선택됨" : "항목 선택"
            label.sizeToFit()
        }
        toolbarItems?.last?.isEnabled = count > 0
    }

    /// Grid/Album 공용 삭제 (휴지통으로 이동)
    @objc func gridAlbumDeleteSelectedTapped() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else { return }

        trashStore.moveToTrash(assetIDs: Array(selectedAssetIDs))
        selectionManager.clearSelection()
        exitSelectMode()
    }
}

// MARK: - GridViewController Overrides

extension GridViewController {

    override func setupSelectionToolbar() -> [UIBarButtonItem] {
        setupGridAlbumSelectionToolbar()
    }

    override func updateSelectionToolbar(count: Int) {
        updateGridAlbumSelectionToolbar(count: count)
    }
}

// MARK: - AlbumGridViewController Overrides

extension AlbumGridViewController {

    override func setupSelectionToolbar() -> [UIBarButtonItem] {
        setupGridAlbumSelectionToolbar()
    }

    override func updateSelectionToolbar(count: Int) {
        updateGridAlbumSelectionToolbar(count: count)
    }
}
```

### 1.2 iOS 26+ Select 버튼 설정

Grid는 TabBarController에서 설정, Album은 viewWillAppear에서 설정:

```swift
// AlbumGridViewController.swift - viewWillAppear에 추가
if #available(iOS 26.0, *) {
    navigationItem.rightBarButtonItem = UIBarButtonItem(
        title: "Select",
        style: .plain,
        target: self,
        action: #selector(selectButtonTapped)
    )
}
```

### 1.3 iOS 16~25 플로팅 UI Select 버튼

```swift
// AlbumGridViewController - configureFloatingOverlayForAlbum() 수정
// 기존: overlay.titleBar.isSelectButtonHidden = true
// 변경:
overlay.titleBar.setRightButton(title: "Select", backgroundColor: .systemBlue) { [weak self] in
    self?.enterSelectMode()
}
```

---

## Phase 2: TrashSelectMode.swift 생성 (Trash 전용)

### 2.1 Trash 전용 선택 모드 (~200줄)

```swift
// TrashSelectMode.swift
// Trash 전용 선택 모드 (Restore + 영구 Delete)

import UIKit
import Photos
import AppCore

// MARK: - Trash Select Mode Support

extension TrashAlbumViewController {

    override var supportsSelectMode: Bool { true }

    // MARK: - iOS 26+ 툴바: [Restore] [flex] [선택개수] [flex] [Delete]

    override func setupSelectionToolbar() -> [UIBarButtonItem] {
        let restoreItem = UIBarButtonItem(
            title: "Restore",
            style: .plain,
            target: self,
            action: #selector(trashRestoreSelectedTapped)
        )

        let countLabel = UILabel()
        countLabel.text = "항목 선택"
        countLabel.font = .systemFont(ofSize: 17)
        let countItem = UIBarButtonItem(customView: countLabel)
        selectionCountBarItem = countItem

        let deleteItem = UIBarButtonItem(
            title: "Delete",
            style: .plain,
            target: self,
            action: #selector(trashDeleteSelectedTapped)
        )
        deleteItem.tintColor = .systemRed

        return [
            restoreItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            countItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            deleteItem
        ]
    }

    override func updateSelectionToolbar(count: Int) {
        if let countItem = selectionCountBarItem,
           let label = countItem.customView as? UILabel {
            label.text = count > 0 ? "\(count)개 항목 선택됨" : "항목 선택"
            label.sizeToFit()
        }
        if let items = toolbarItems {
            items.first?.isEnabled = count > 0  // Restore
            items.last?.isEnabled = count > 0   // Delete
        }
    }

    // MARK: - iOS 26+ 네비바 복원 (Select + 비우기)

    override func restoreNavigationBarAfterSelectMode() {
        if #available(iOS 26.0, *) {
            let selectButton = UIBarButtonItem(
                title: "Select",
                style: .plain,
                target: self,
                action: #selector(selectButtonTapped)
            )

            let emptyButton = UIBarButtonItem(
                title: "비우기",
                style: .plain,
                target: self,
                action: #selector(emptyTrashTapped)
            )
            emptyButton.tintColor = .systemRed
            emptyButton.isEnabled = !_trashDataSource.assets.isEmpty

            navigationItem.rightBarButtonItems = [emptyButton, selectButton]
        }
    }

    // MARK: - iOS 16~25 플로팅 UI (Trash 전용 오버라이드)

    override func enterSelectModeFloatingUI() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.enterSelectMode { [weak self] in
            self?.exitSelectMode()
        }
        // Trash 전용: trashSelectModeContainer 사용
        overlay.tabBar.enterTrashSelectMode(animated: true)
    }

    override func exitSelectModeFloatingUI() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.exitSelectMode()
        overlay.tabBar.exitTrashSelectMode(animated: true)
        configureFloatingOverlayForTrash()
    }

    override func updateSelectionCountFloatingUI(_ count: Int) {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }
        overlay.tabBar.updateTrashSelectionCount(count)
    }

    // MARK: - Actions

    /// 복원 (Trash 전용)
    @objc func trashRestoreSelectedTapped() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else { return }

        trashStore.restore(assetIDs: Array(selectedAssetIDs))
        selectionManager.clearSelection()
        exitSelectMode()
    }

    /// 영구 삭제 (Trash 전용)
    @objc func trashDeleteSelectedTapped() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else { return }

        Task {
            do {
                try await trashStore.permanentlyDelete(assetIDs: Array(selectedAssetIDs))
                await MainActor.run {
                    selectionManager.clearSelection()
                    exitSelectMode()
                }
            } catch {
                print("[TrashSelectMode] Failed to delete: \(error)")
            }
        }
    }
}

// MARK: - FloatingTabBarDelegate (Trash 전용)

extension TrashAlbumViewController: FloatingTabBarDelegate {

    func floatingTabBarDidTapRestore(_ tabBar: FloatingTabBar) {
        trashRestoreSelectedTapped()
    }

    func floatingTabBarDidTapTrashDelete(_ tabBar: FloatingTabBar) {
        trashDeleteSelectedTapped()
    }
}
```

### 2.2 iOS 26+ 초기 네비바 설정

```swift
// TrashAlbumViewController.swift - setupSystemNavigationBar() 수정
@available(iOS 26.0, *)
private func setupSystemNavigationBar() {
    let selectButton = UIBarButtonItem(
        title: "Select",
        style: .plain,
        target: self,
        action: #selector(selectButtonTapped)
    )

    let emptyButton = UIBarButtonItem(
        title: "비우기",
        style: .plain,
        target: self,
        action: #selector(emptyTrashTapped)
    )
    emptyButton.tintColor = .systemRed
    emptyButton.isEnabled = !_trashDataSource.assets.isEmpty

    // [Select] [비우기] 동시 표시
    navigationItem.rightBarButtonItems = [emptyButton, selectButton]
}
```

---

## Phase 3: FloatingTitleBar 두 버튼 지원 (~50줄)

### 3.1 휴지통용 두 버튼 설정

```swift
// FloatingTitleBar.swift

private lazy var secondaryRightButton: UIButton = { ... }()
private var secondaryRightButtonAction: (() -> Void)?

/// 두 버튼 동시 설정 (휴지통용: Select + 비우기)
func setRightButtons(
    primary: (title: String, color: UIColor, action: () -> Void),
    secondary: (title: String, color: UIColor, action: () -> Void)
) { ... }

func hideSecondaryRightButton() { ... }
```

---

## Phase 4: FloatingTabBar 휴지통 선택 모드 UI (~100줄)

### 4.1 trashSelectModeContainer

```swift
// FloatingTabBar.swift

// [Restore]  [선택개수]  [Delete]
//    좌측       중앙       우측

private lazy var trashSelectModeContainer: UIView = { ... }()
private lazy var restoreButton: UIButton = { ... }()        // 좌측
private lazy var trashSelectionCountLabel: UILabel = { ... }()  // 중앙
private lazy var trashDeleteButton: UIButton = { ... }()    // 우측

func enterTrashSelectMode(animated: Bool = true)
func exitTrashSelectMode(animated: Bool = true)
func updateTrashSelectionCount(_ count: Int)
```

### 4.2 델리게이트 프로토콜 추가

```swift
protocol FloatingTabBarDelegate: AnyObject {
    // 기존...
    func floatingTabBarDidTapRestore(_ tabBar: FloatingTabBar)
    func floatingTabBarDidTapTrashDelete(_ tabBar: FloatingTabBar)
}
```

---

## 수정 대상 파일 요약

| 파일 | 작업 내용 | 예상 줄 수 |
|------|----------|-----------|
| **BaseSelectMode.swift** (신규) | 공통 선택 모드 로직 | ~300줄 |
| BaseGridViewController.swift | 프로퍼티 추가, cellForItemAt 수정 | ~30줄 추가 |
| **GridSelectMode.swift** (수정) | Grid/Album 공용으로 확장 | ~100줄 (기존 480줄 → 100줄) |
| **TrashSelectMode.swift** (신규) | Trash 전용 선택 모드 | ~200줄 |
| GridViewController.swift | 프로퍼티 제거 (Base로 이동) | ~10줄 감소 |
| AlbumGridViewController.swift | Select 버튼 설정만 | ~10줄 추가 |
| TrashAlbumViewController.swift | 네비바 설정만, delegate 연결 | ~20줄 추가 |
| FloatingTitleBar.swift | 두 버튼 지원 | ~50줄 추가 |
| FloatingTabBar.swift | trashSelectModeContainer | ~100줄 추가 |

---

## Git 커밋 계획

1. Phase 0: `refactor(select-mode): Base 선택 모드 공통화`
2. Phase 1: `feat(select-mode): Grid/Album 선택 모드 통합`
3. Phase 2: `feat(trash): Trash 전용 선택 모드 구현`
4. Phase 3: `feat(floating-ui): FloatingTitleBar 두 버튼 지원`
5. Phase 4: `feat(floating-ui): 휴지통 선택 모드 플로팅 UI`

---

## 검증 체크리스트

### Phase 0 완료 후
- [ ] 빌드 성공
- [ ] 기존 Grid 선택 모드 동작 유지

### Phase 1 완료 후
- [ ] Grid 선택 모드 정상 동작
- [ ] Album iOS 26+: Select 버튼 표시
- [ ] Album iOS 16~25: Select 버튼 표시 (FloatingTitleBar)
- [ ] Album 선택 → Delete → 휴지통 이동
- [ ] Album 드래그 선택

### Phase 2 완료 후
- [ ] Trash iOS 26+: [Select] [비우기] 두 버튼 표시
- [ ] Trash iOS 26+ 선택 모드: [Restore] [선택개수] [Delete] 툴바
- [ ] Trash iOS 26+: Select 종료 후 [Select] [비우기] 복원
- [ ] Trash 드래그 선택
- [ ] Restore 버튼 → 복원
- [ ] Delete 버튼 → 영구 삭제 (iOS 팝업)

### Phase 3 완료 후
- [ ] FloatingTitleBar 두 버튼 동시 표시
- [ ] Trash iOS 16~25: [Select] [비우기] 표시

### Phase 4 완료 후
- [ ] trashSelectModeContainer: [Restore] [선택개수] [Delete]
- [ ] Restore 버튼 → delegate → 복원
- [ ] Delete 버튼 → delegate → 영구 삭제
- [ ] 버튼 비활성화 (선택 0개일 때)

### 회귀 테스트
- [ ] 스크롤 후 선택 상태 유지
- [ ] 빈 앨범/휴지통일 때 Select 버튼 처리
- [ ] 선택 모드에서 스와이프 삭제 비활성화
