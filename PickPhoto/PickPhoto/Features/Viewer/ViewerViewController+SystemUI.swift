// ViewerViewController+SystemUI.swift
// iOS 26+ 시스템 UI (네비게이션 바, 툴바) 설정
//
// ViewerViewController에서 분리된 extension
// iOS 26+ 시스템 네비바/툴바 관련 메서드 모음

import UIKit

// MARK: - iOS 26+ System UI Setup

extension ViewerViewController {

    /// iOS 26+ 시스템 UI 설정 (1회만 실행)
    @available(iOS 26.0, *)
    func setupSystemUIIfNeeded() {
        guard !didSetupSystemUI else { return }
        guard navigationController != nil else { return }

        didSetupSystemUI = true

        setupSystemNavigationBar()
        setupSystemToolbar()
    }

    /// iOS 26+ 시스템 네비게이션 바 설정
    @available(iOS 26.0, *)
    func setupSystemNavigationBar() {
        // Push 방식이므로 leftBarButtonItem 설정 없이 시스템 백버튼 자동 사용
        // 투명 배경 (사진 위에 Liquid Glass 효과)
        navigationController?.navigationBar.isTranslucent = true

        // 눈 아이콘 버튼 생성 (유사 사진 토글용)
        let eyeItem = UIBarButtonItem(
            image: UIImage(systemName: "eye.fill"),
            primaryAction: UIAction { [weak self] _ in
                self?.navBarEyeButtonTapped()
            }
        )
        eyeItem.tintColor = .white
        navBarEyeItem = eyeItem
        // +버튼 표시 시 rightBarButtonItem + title 설정됨 (showNavBarEyeButton에서)
    }

    /// iOS 26+ 네비게이션 바 눈 아이콘 탭 핸들러
    /// 타이틀 토글은 toggleOverlay → 델리게이트 didToggleVisibility에서 처리
    func navBarEyeButtonTapped() {
        faceButtonOverlay?.toggleOverlay()
        updateNavBarEyeIcon()
    }

    /// iOS 26+ 네비게이션 바 눈 아이콘 업데이트
    func updateNavBarEyeIcon() {
        guard #available(iOS 26.0, *) else { return }
        let iconName = faceButtonOverlay?.isCurrentlyHidden == true ? "eye.slash.fill" : "eye.fill"
        navBarEyeItem?.image = UIImage(systemName: iconName)
    }

    /// 눈 아이콘 + 커스텀 타이틀 표시/숨김
    /// +버튼이 표시/숨겨질 때 호출되어 타이틀도 함께 연동
    func showNavBarEyeButton(_ show: Bool) {
        // iOS 26: 네비바 눈 아이콘 + titleView 자체를 nil/복원
        // alpha만 0으로 하면 시스템 바 토글 애니메이션에서 titleView가 잠깐 보이는 문제 발생
        if #available(iOS 26.0, *) {
            navigationItem.rightBarButtonItem = show ? navBarEyeItem : nil
            navigationItem.titleView = show ? similarPhotoTitleLabel : nil
        }

        // 커스텀 타이틀 라벨 (iOS 16~25 + iOS 26 공통)
        UIView.animate(withDuration: 0.2) {
            self.similarPhotoTitleLabel?.alpha = show ? 1 : 0
        }
    }

    /// iOS 26+ 시스템 툴바 설정
    @available(iOS 26.0, *)
    func setupSystemToolbar() {
        navigationController?.setToolbarHidden(false, animated: false)
        navigationController?.toolbar.isTranslucent = true

        switch viewerMode {
        case .normal:
            setupNormalModeToolbar()
        case .trash:
            setupTrashModeToolbar()
        case .cleanup:
            setupCleanupModeToolbar()
        }
    }

    /// iOS 26+ 일반 모드 툴바 (이전 사진 + 삭제하기)
    @available(iOS 26.0, *)
    func setupNormalModeToolbar() {
        let flexSpace = UIBarButtonItem(systemItem: .flexibleSpace)

        let previousItem = UIBarButtonItem(
            title: "이전 사진",
            primaryAction: UIAction { [weak self] _ in
                self?.previousPhotoButtonTapped()
            }
        )
        // tintColor 미지정 → Liquid Glass가 배경에 따라 자동 색상 적응
        toolbarPreviousItem = previousItem

        let deleteItem = UIBarButtonItem(
            title: "삭제하기",
            primaryAction: UIAction { [weak self] _ in
                self?.deleteButtonTapped()
            }
        )
        deleteItem.tintColor = .systemRed
        toolbarDeleteItem = deleteItem

        toolbarItems = [previousItem, flexSpace, deleteItem]
        updatePreviousNavigationState()
    }

    /// iOS 26+ 삭제대기함 모드 툴바 (복구 + 최종 삭제)
    @available(iOS 26.0, *)
    func setupTrashModeToolbar() {
        let flexSpace = UIBarButtonItem(systemItem: .flexibleSpace)

        // 복구 버튼
        let restoreItem = UIBarButtonItem(
            title: "복구하기",
            primaryAction: UIAction { [weak self] _ in
                self?.restoreButtonTapped()
            }
        )
        restoreItem.tintColor = .systemGreen
        toolbarRestoreItem = restoreItem

        // 최종 삭제 버튼
        let permanentDeleteItem = UIBarButtonItem(
            title: "최종 삭제",
            primaryAction: UIAction { [weak self] _ in
                self?.permanentDeleteButtonTapped()
            }
        )
        permanentDeleteItem.tintColor = .systemRed
        toolbarPermanentDeleteItem = permanentDeleteItem

        toolbarItems = [restoreItem, flexSpace, permanentDeleteItem]
    }

    /// iOS 26+ 정리 미리보기 모드 툴바 (제외 버튼)
    @available(iOS 26.0, *)
    func setupCleanupModeToolbar() {
        let flexSpace = UIBarButtonItem(systemItem: .flexibleSpace)

        let excludeItem = UIBarButtonItem(
            title: "제외",
            primaryAction: UIAction { [weak self] _ in
                self?.excludeButtonTapped()
            }
        )
        excludeItem.tintColor = .white

        toolbarItems = [flexSpace, excludeItem, flexSpace]
    }

    /// iOS 26+ 툴바 동적 교체 (현재 사진의 삭제대기함 상태에 따라)
    @available(iOS 26.0, *)
    func updateToolbarItemsForCurrentPhoto() {
        // .normal 모드에서만 동적 교체 필요
        guard viewerMode == .normal else { return }

        // nil guard: setupSystemUIIfNeeded() 이전 호출 방지
        guard let toolbarDeleteItem, let toolbarPreviousItem else { return }

        let isTrashed = coordinator.isTrashed(at: currentIndex)
        let flexSpace = UIBarButtonItem(systemItem: .flexibleSpace)

        if isTrashed {
            // 삭제대기함 사진: 이전 사진 + 복구
            let restoreItem = UIBarButtonItem(
                title: "복구하기",
                primaryAction: UIAction { [weak self] _ in
                    self?.restoreButtonTapped()
                }
            )
            restoreItem.tintColor = .systemGreen
            toolbarItems = [toolbarPreviousItem, flexSpace, restoreItem]
        } else {
            // 일반 사진: 이전 사진 + 삭제하기
            toolbarItems = [toolbarPreviousItem, flexSpace, toolbarDeleteItem]
        }
    }
}
