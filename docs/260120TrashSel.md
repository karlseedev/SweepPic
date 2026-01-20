# 앨범/휴지통 선택 모드 구현 계획

**작성일**: 2026-01-20
**브랜치**: 001-auto-cleanup
**선행 작업**: BaseGridViewController 리팩토링 완료 (260120refac.md)

## 개요

BaseGridViewController 리팩토링 완료 후, 앨범(AlbumGridViewController)과 휴지통(TrashAlbumViewController)에 선택 모드를 활성화합니다.

리팩토링으로 선택 모드 기본 구조가 BaseGridViewController에 포함되므로, 각 VC에서는 템플릿 메서드만 오버라이드하면 됩니다.

## 선행 조건

리팩토링 완료 후 Base에서 제공되는 선택 모드 기능:
- `isSelectMode`, `selectionManager` 프로퍼티
- `enterSelectMode()`, `exitSelectMode()` 메서드
- 드래그 선택, 자동 스크롤
- iOS 버전별 UI 분기 (iOS 26+ 시스템 UI / iOS 16~25 플로팅 UI)
- `SelectionManagerDelegate` 구현

Base에서 제공되는 템플릿 메서드 (서브클래스 오버라이드):
- `supportsSelectMode: Bool` - 선택 모드 지원 여부
- `setupSelectionToolbar() -> [UIBarButtonItem]` - iOS 26+ 툴바 버튼 구성
- `updateSelectionToolbar(count: Int)` - 선택 개수 변경 시 툴바 업데이트
- `enterSelectModeFloatingUI()` - 플로팅 UI 선택 모드 진입 (오버라이드 가능)
- `exitSelectModeFloatingUI()` - 플로팅 UI 선택 모드 종료 (오버라이드 가능)

## 각 VC별 선택 모드 차이점

| 항목 | 사진보관함 (Grid) | 앨범 (Album) | 휴지통 (Trash) |
|------|-----------------|--------------|---------------|
| supportsSelectMode | true (기존) | true (신규) | true (신규) |
| iOS 26+ 툴바 | [선택개수] [Delete] | [선택개수] [Delete] | [Restore] [선택개수] [Delete] |
| 플로팅 TabBar UI | selectModeContainer | selectModeContainer (재사용) | **trashSelectModeContainer** (신규) |
| Delete 동작 | 휴지통 이동 | 휴지통 이동 | **완전 삭제** (iOS 팝업) |
| Restore 동작 | 없음 | 없음 | **휴지통에서 복구** |

---

## Phase 1: 앨범 선택 모드 활성화 (~60줄)

### 1.1 AlbumGridViewController 수정 - 기본 설정

```swift
// MARK: - Select Mode Support

override var supportsSelectMode: Bool { true }

override func setupSelectionToolbar() -> [UIBarButtonItem] {
    // iOS 26+ 툴바: [flex] [선택개수] [flex] [Delete]
    let countLabel = UILabel()
    countLabel.text = "항목 선택"
    countLabel.font = .systemFont(ofSize: 17)
    let countItem = UIBarButtonItem(customView: countLabel)
    selectionCountBarItem = countItem

    let deleteItem = UIBarButtonItem(
        title: "Delete",
        style: .plain,
        target: self,
        action: #selector(deleteSelectedPhotosTapped)
    )
    deleteItem.tintColor = .systemRed

    return [
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
    toolbarItems?.last?.isEnabled = count > 0
}

@objc private func deleteSelectedPhotosTapped() {
    let selectedAssetIDs = selectionManager.selectedAssetIDs
    guard !selectedAssetIDs.isEmpty else { return }

    trashStore.moveToTrash(assetIDs: Array(selectedAssetIDs))
    selectionManager.clearSelection()
    exitSelectMode()
}
```

### 1.2 iOS 26+ 시스템 UI - Select 버튼 추가

```swift
// setupSystemNavigationBar() 또는 viewDidLoad에서
@available(iOS 26.0, *)
private func setupSelectButton() {
    let selectButton = UIBarButtonItem(
        title: "Select",
        style: .plain,
        target: self,
        action: #selector(selectButtonTapped)
    )
    // 기존 rightBarButtonItem이 있다면 배열로, 없다면 단독 설정
    navigationItem.rightBarButtonItem = selectButton
}

@objc private func selectButtonTapped() {
    enterSelectMode()
}
```

### 1.3 iOS 16~25 플로팅 UI - Select 버튼 추가

```swift
// configureFloatingOverlayForAlbum() 수정
overlay.titleBar.setRightButton(title: "Select", backgroundColor: .systemBlue) { [weak self] in
    self?.enterSelectMode()
}
```

> **참고**: 앨범은 기존 Grid와 동일한 `selectModeContainer` (Delete 버튼만)를 사용하므로, Base의 `enterSelectModeFloatingUI()`를 그대로 사용.

---

## Phase 2: 휴지통 선택 모드 활성화 (~120줄)

### 2.1 TrashAlbumViewController 수정 - 기본 설정

```swift
// MARK: - Select Mode Support

override var supportsSelectMode: Bool { true }

override func setupSelectionToolbar() -> [UIBarButtonItem] {
    // iOS 26+ 툴바: [Restore] [flex] [선택개수] [flex] [Delete]
    let restoreItem = UIBarButtonItem(
        title: "Restore",
        style: .plain,
        target: self,
        action: #selector(restoreSelectedPhotosTapped)
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
        action: #selector(deleteSelectedPhotosTapped)
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

    // Restore/Delete 버튼 활성화
    if let items = toolbarItems {
        items.first?.isEnabled = count > 0  // Restore
        items.last?.isEnabled = count > 0   // Delete
    }
}

@objc private func restoreSelectedPhotosTapped() {
    let selectedAssetIDs = selectionManager.selectedAssetIDs
    guard !selectedAssetIDs.isEmpty else { return }

    trashStore.restore(assetIDs: Array(selectedAssetIDs))
    selectionManager.clearSelection()
    exitSelectMode()
}

@objc private func deleteSelectedPhotosTapped() {
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
            print("[TrashAlbumViewController] Failed to delete: \(error)")
        }
    }
}
```

### 2.2 iOS 26+ 시스템 UI - Select 버튼 추가

```swift
// setupSystemNavigationBar() 수정
let selectButton = UIBarButtonItem(
    title: "Select",
    style: .plain,
    target: self,
    action: #selector(selectButtonTapped)
)

// 기존 emptyButton과 함께 배열로 설정
navigationItem.rightBarButtonItems = [emptyButton, selectButton]

@objc private func selectButtonTapped() {
    enterSelectMode()
}
```

### 2.3 iOS 16~25 플로팅 UI - 휴지통 전용 처리

휴지통은 Restore 버튼이 추가로 필요하므로 **Base의 플로팅 UI 메서드를 오버라이드**:

```swift
// MARK: - Floating UI Override (휴지통 전용)

override func enterSelectModeFloatingUI() {
    guard let tabBarController = tabBarController as? TabBarController,
          let overlay = tabBarController.floatingOverlay else { return }

    overlay.titleBar.enterSelectMode { [weak self] in
        self?.exitSelectMode()
    }
    // 휴지통 전용 UI 사용
    overlay.tabBar.enterTrashSelectMode(animated: true)
}

override func exitSelectModeFloatingUI() {
    guard let tabBarController = tabBarController as? TabBarController,
          let overlay = tabBarController.floatingOverlay else { return }

    overlay.titleBar.exitSelectMode()
    overlay.tabBar.exitTrashSelectMode(animated: true)
    configureFloatingOverlayForTrash()  // 원래 상태로 복원
}

// SelectionManagerDelegate에서 호출
override func updateSelectionCountFloatingUI(_ count: Int) {
    guard let tabBarController = tabBarController as? TabBarController,
          let overlay = tabBarController.floatingOverlay else { return }
    overlay.tabBar.updateTrashSelectionCount(count)
}
```

### 2.4 configureFloatingOverlayForTrash() 수정

```swift
// Select 버튼 추가 (사진이 있을 때만)
if !trashedAssets.isEmpty {
    overlay.titleBar.setRightButton(title: "Select", backgroundColor: .systemBlue) { [weak self] in
        self?.enterSelectMode()
    }
} else {
    overlay.titleBar.hideRightButton()
}
```

### 2.5 FloatingTabBarDelegate 구현

```swift
// MARK: - FloatingTabBarDelegate

extension TrashAlbumViewController: FloatingTabBarDelegate {
    // 기존 델리게이트 메서드들...

    func floatingTabBarDidTapRestore(_ tabBar: FloatingTabBar) {
        restoreSelectedPhotosTapped()
    }

    func floatingTabBarDidTapTrashDelete(_ tabBar: FloatingTabBar) {
        deleteSelectedPhotosTapped()
    }
}
```

---

## Phase 3: FloatingTabBar 휴지통 선택 모드 UI (~100줄)

### 3.1 추가할 UI 컴포넌트

```swift
// MARK: - Trash Select Mode UI

/// 휴지통 선택 모드 컨테이너 (Restore + 선택개수 + Delete)
private lazy var trashSelectModeContainer: UIView = {
    let view = UIView()
    view.backgroundColor = .clear
    view.isHidden = true
    return view
}()

/// Restore 버튼
private lazy var restoreButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Restore", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
    button.addTarget(self, action: #selector(restoreButtonTapped), for: .touchUpInside)
    return button
}()

/// 휴지통 선택개수 라벨
private lazy var trashSelectionCountLabel: UILabel = {
    let label = UILabel()
    label.text = "항목 선택"
    label.font = .systemFont(ofSize: 15)
    label.textColor = .secondaryLabel
    label.textAlignment = .center
    return label
}()

/// 휴지통 Delete 버튼 (완전 삭제)
private lazy var trashDeleteButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("Delete", for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
    button.tintColor = .systemRed
    button.addTarget(self, action: #selector(trashDeleteButtonTapped), for: .touchUpInside)
    return button
}()
```

### 3.2 setupUI()에 레이아웃 추가

```swift
// trashSelectModeContainer 추가
addSubview(trashSelectModeContainer)
trashSelectModeContainer.addSubview(restoreButton)
trashSelectModeContainer.addSubview(trashSelectionCountLabel)
trashSelectModeContainer.addSubview(trashDeleteButton)

// Auto Layout 설정
trashSelectModeContainer.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    trashSelectModeContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
    trashSelectModeContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
    trashSelectModeContainer.topAnchor.constraint(equalTo: topAnchor),
    trashSelectModeContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
])

// 버튼/라벨 레이아웃 (수평 배치)
// [Restore] --- [선택개수] --- [Delete]
```

### 3.3 추가할 메서드

```swift
// MARK: - Trash Select Mode Methods

func enterTrashSelectMode(animated: Bool = true) {
    capsuleContainer.isHidden = true
    selectModeContainer.isHidden = true
    trashSelectModeContainer.isHidden = false
    updateTrashSelectionCount(0)
}

func exitTrashSelectMode(animated: Bool = true) {
    trashSelectModeContainer.isHidden = true
    capsuleContainer.isHidden = false
}

func updateTrashSelectionCount(_ count: Int) {
    trashSelectionCountLabel.text = count > 0 ? "\(count)개 선택됨" : "항목 선택"
    restoreButton.isEnabled = count > 0
    trashDeleteButton.isEnabled = count > 0
}

@objc private func restoreButtonTapped() {
    delegate?.floatingTabBarDidTapRestore(self)
}

@objc private func trashDeleteButtonTapped() {
    delegate?.floatingTabBarDidTapTrashDelete(self)
}
```

### 3.4 델리게이트 프로토콜 추가

```swift
protocol FloatingTabBarDelegate: AnyObject {
    // 기존 메서드들...
    func floatingTabBarDidTapDelete(_ tabBar: FloatingTabBar)

    // 휴지통 전용 (신규)
    func floatingTabBarDidTapRestore(_ tabBar: FloatingTabBar)
    func floatingTabBarDidTapTrashDelete(_ tabBar: FloatingTabBar)
}

// 기본 구현 (옵셔널 처리)
extension FloatingTabBarDelegate {
    func floatingTabBarDidTapRestore(_ tabBar: FloatingTabBar) {}
    func floatingTabBarDidTapTrashDelete(_ tabBar: FloatingTabBar) {}
}
```

---

## Phase 4: Base 수정 사항 확인

리팩토링 문서(260120refac.md)에서 Base에 정의된 플로팅 UI 메서드가 오버라이드 가능해야 함:

```swift
// BaseGridViewController.swift

/// 플로팅 UI 선택 모드 진입 (서브클래스에서 오버라이드 가능)
func enterSelectModeFloatingUI() {
    guard let tabBarController = tabBarController as? TabBarController,
          let overlay = tabBarController.floatingOverlay else { return }

    overlay.titleBar.enterSelectMode { [weak self] in
        self?.exitSelectMode()
    }
    overlay.tabBar.enterSelectMode(animated: true)
}

/// 플로팅 UI 선택 모드 종료 (서브클래스에서 오버라이드 가능)
func exitSelectModeFloatingUI() {
    guard let tabBarController = tabBarController as? TabBarController,
          let overlay = tabBarController.floatingOverlay else { return }

    overlay.titleBar.exitSelectMode()
    overlay.tabBar.exitSelectMode(animated: true)
}

/// 플로팅 UI 선택 개수 업데이트 (서브클래스에서 오버라이드 가능)
func updateSelectionCountFloatingUI(_ count: Int) {
    guard let tabBarController = tabBarController as? TabBarController,
          let overlay = tabBarController.floatingOverlay else { return }
    overlay.tabBar.updateSelectionCount(count)
}
```

> **중요**: 리팩토링 문서(260120refac.md)에 위 메서드들이 오버라이드 가능하도록 명시되어 있는지 확인 필요. 없다면 리팩토링 문서도 업데이트 필요.

---

## 수정 대상 파일 요약

| 파일 | 작업 내용 | 예상 줄 수 |
|------|----------|-----------|
| AlbumGridViewController.swift | supportsSelectMode, 툴바, Select 버튼 (iOS 26+/플로팅) | ~60줄 추가 |
| TrashAlbumViewController.swift | supportsSelectMode, 툴바, Select 버튼, 플로팅 UI 오버라이드, 델리게이트 | ~120줄 추가 |
| FloatingTabBar.swift | trashSelectModeContainer UI, 메서드, 델리게이트 | ~100줄 추가 |
| BaseGridViewController.swift | 플로팅 UI 메서드 오버라이드 가능 확인 | (리팩토링에서 처리) |
| **합계** | | **~280줄** |

---

## 검증 계획

### 빌드 테스트
```bash
xcodebuild -project PickPhoto/PickPhoto.xcodeproj -scheme PickPhoto -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### 기능 테스트 체크리스트

**앨범 선택 모드 (iOS 26+):**
- [ ] Select 버튼 표시 (네비게이션 바)
- [ ] Select 버튼으로 선택 모드 진입
- [ ] 시스템 툴바에 [선택개수] [Delete] 표시
- [ ] 셀 탭으로 선택/해제
- [ ] 드래그로 연속 선택
- [ ] Delete 버튼으로 휴지통 이동
- [ ] Cancel 버튼으로 선택 모드 종료

**앨범 선택 모드 (iOS 16~25 플로팅 UI):**
- [ ] Select 버튼 표시 (FloatingTitleBar)
- [ ] selectModeContainer 표시 (기존 Grid와 동일)
- [ ] Delete 버튼 동작

**휴지통 선택 모드 (iOS 26+):**
- [ ] Select 버튼 표시 (비우기 버튼 옆)
- [ ] 시스템 툴바에 [Restore] [선택개수] [Delete] 표시
- [ ] Restore 버튼으로 복구
- [ ] Delete 버튼으로 완전 삭제 (iOS 시스템 팝업)

**휴지통 선택 모드 (iOS 16~25 플로팅 UI):**
- [ ] Select 버튼 표시 (FloatingTitleBar)
- [ ] trashSelectModeContainer 표시 ([Restore] [선택개수] [Delete])
- [ ] Restore 버튼 → 델리게이트 → 복구 동작
- [ ] Delete 버튼 → 델리게이트 → 완전 삭제 동작

**공통:**
- [ ] 빈 앨범/휴지통일 때 Select 버튼 숨김/비활성화
- [ ] 선택 개수 0일 때 Restore/Delete 버튼 비활성화

---

## Git 커밋 계획

1. Phase 1 완료: `feat(album): 앨범 선택 모드 활성화`
2. Phase 2 완료: `feat(trash): 휴지통 선택 모드 활성화`
3. Phase 3 완료: `feat(floating-ui): 휴지통 선택 모드 플로팅 UI 추가`

---

## 참고: 리팩토링 문서 업데이트 필요 사항

260120refac.md에 다음 내용 추가 필요:

1. **Base 플로팅 UI 메서드 오버라이드 가능 명시**:
   - `enterSelectModeFloatingUI()`
   - `exitSelectModeFloatingUI()`
   - `updateSelectionCountFloatingUI(_ count: Int)`

2. **GridSelectMode.swift 변경 시 위 메서드들 분리**:
   - 현재 GridSelectMode.swift에 있는 플로팅 UI 로직을 Base 메서드로 분리
   - 서브클래스에서 오버라이드 가능하도록 구조화
