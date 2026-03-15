// ViewerViewController+Setup.swift
// UI 초기 설정 (배경, 페이지VC, 그라데이션, 버튼, 제스처)
//
// ViewerViewController에서 분리된 extension
// viewDidLoad에서 호출하는 setupUI() 및 관련 설정 메서드 모음

import UIKit

// MARK: - Setup

extension ViewerViewController {

    /// UI 설정
    func setupUI() {
        // 배경
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 페이지 뷰 컨트롤러 추가
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        pageViewController.didMove(toParent: self)

        // 상단 그라데이션 + 타이틀 (normal 모드)
        // iOS 16~25: 딤드 + 타이틀, iOS 26: titleView로 타이틀만
        // pageVC 위, 버튼/오버레이 아래에 삽입
        if viewerMode == .normal {
            if !useSystemUI {
                setupTopGradientAndTitle()  // 딤드 + 타이틀
            } else {
                setupSimilarPhotoTitleLabel()  // iOS 26: navigationItem.titleView
            }
        }

        // iOS 16~25: 커스텀 버튼 추가
        // iOS 26+: viewWillAppear에서 시스템 UI 설정 (navigationController 필요)
        if !useSystemUI {
            setupActionButtons()
            setupBackButton()
        }

        // 얼굴 감지 디버그 버튼 (DEBUG 빌드만)
        #if DEBUG
        setupFaceDebugButton()
        #endif

    }


    /// 상단 그라데이션 딤드 + "유사사진정리 가능" 타이틀 설정
    /// .normal 모드 && !useSystemUI 조건에서만 호출
    /// z-order: pageVC 위, backButton/faceButtonOverlay 아래
    func setupTopGradientAndTitle() {
        // --- 그라데이션 딤드 뷰 ---
        let gradientContainer = UIView()
        gradientContainer.translatesAutoresizingMaskIntoConstraints = false
        gradientContainer.isUserInteractionEnabled = false
        view.addSubview(gradientContainer)

        // 그라데이션 레이어: 뷰어 전용 (0.90)
        let gradientLayer = CAGradientLayer()
        let dimAlpha: CGFloat = 0.90
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(dimAlpha).cgColor,
            UIColor.black.withAlphaComponent(dimAlpha * 0.7).cgColor,
            UIColor.black.withAlphaComponent(dimAlpha * 0.3).cgColor,
            UIColor.black.withAlphaComponent(dimAlpha * 0.1).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0, 0.25, 0.5, 0.75, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientContainer.layer.addSublayer(gradientLayer)

        // 그라데이션 영역: view.top ~ safeArea top + 90pt
        NSLayoutConstraint.activate([
            gradientContainer.topAnchor.constraint(equalTo: view.topAnchor),
            gradientContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 90)
        ])

        topGradientView = gradientContainer
        topGradientLayer = gradientLayer

        // 딤드 위에 타이틀 라벨 추가
        setupSimilarPhotoTitleLabel()
    }

    /// "유사사진정리 가능" 커스텀 타이틀 라벨 설정
    /// iOS 16~25: setupTopGradientAndTitle()에서 딤드와 함께 호출 → view.addSubview
    /// iOS 26: navigationItem.titleView에 설정 → 네비바 버튼과 자동 수평 정렬
    func setupSimilarPhotoTitleLabel() {
        let titleLabel = UILabel()
        // "유사사진정리"(레귤러/흰색) + " 가능"(볼드/밝은 노란색)
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(
            string: "유사사진정리 ",
            attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .regular), .foregroundColor: UIColor.white]
        ))
        attr.append(NSAttributedString(
            string: "가능",
            attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .heavy), .foregroundColor: UIColor(red: 1.0, green: 234.0/255.0, blue: 0, alpha: 1.0)]
        ))
        titleLabel.attributedText = attr
        titleLabel.textAlignment = .center

        if useSystemUI {
            // iOS 26: showNavBarEyeButton(true) 시에만 navigationItem.titleView에 할당
            // Setup 시점에 할당하면 push 전환 애니메이션이 alpha를 1로 만들어 잠깐 보이는 문제 발생
            titleLabel.sizeToFit()
            titleLabel.alpha = 0
        } else {
            // iOS 16~25: view에 직접 추가 + Auto Layout
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.isUserInteractionEnabled = false
            view.addSubview(titleLabel)

            // centerY = safeArea + 29 (backButton centerY와 수평 정렬)
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 29)
            ])

            titleLabel.alpha = 0
        }

        similarPhotoTitleLabel = titleLabel
    }

    /// iOS 16~25 전용 뒤로가기 버튼 설정
    /// Push 전환 방식이지만 네비바는 숨긴 상태로 유지하고 커스텀 버튼 사용
    /// iOS 26 스펙: 44×44, iconSize 22pt (GlassIconButton과 동일)
    func setupBackButton() {
        // GlassIconButton 사용 (iOS 26 NavBar 아이콘 버튼과 동일 스펙)
        let backButton = GlassIconButton(icon: "chevron.backward", size: .medium, tintColor: .white)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.accessibilityIdentifier = "viewer_back"

        view.addSubview(backButton)
        backButtonView = backButton
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 7),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16)
        ])
    }

    /// 액션 버튼 설정 (모드에 따라 다름)
    /// 버튼 위치: safeArea bottom에서 28pt 위
    func setupActionButtons() {
        switch viewerMode {
        case .normal:
            // 이전 사진 버튼 (좌측)
            view.addSubview(previousPhotoButton)
            NSLayoutConstraint.activate([
                previousPhotoButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
                previousPhotoButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])

            // 삭제하기 버튼 (우측)
            view.addSubview(deleteButton)
            NSLayoutConstraint.activate([
                deleteButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
                deleteButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])

            // 복구 버튼 (우측 - 삭제 버튼과 같은 위치, 삭제대기함 사진일 때 표시)
            view.addSubview(restoreButton)
            NSLayoutConstraint.activate([
                restoreButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
                restoreButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])

            // 초기 상태: 삭제 버튼만 표시, 복구 버튼은 숨김
            restoreButton.isHidden = true
            updatePreviousNavigationState()

        case .trash:
            // 복구 버튼 (왼쪽 끝) - iOS 26 스펙: 양쪽 끝 배치
            view.addSubview(restoreButton)
            NSLayoutConstraint.activate([
                restoreButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
                restoreButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])

            // 최종 삭제 버튼 (오른쪽 끝) - iOS 26 스펙: 양쪽 끝 배치
            view.addSubview(permanentDeleteButton)
            NSLayoutConstraint.activate([
                permanentDeleteButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
                permanentDeleteButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])

        case .cleanup:
            // 제외 버튼 (중앙 — deleteButton과 동일 위치)
            view.addSubview(excludeButton)
            NSLayoutConstraint.activate([
                excludeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                excludeButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Self.buttonCenterFromBottom)
            ])
        }
    }

    /// 제스처 설정
    func setupGestures() {
        // 아래 스와이프로 닫기
        view.addGestureRecognizer(dismissPanGesture)
    }

    /// 스와이프 삭제 핸들러 설정
    func setupSwipeDeleteHandler() {
        // 일반 모드에서만 위 스와이프 삭제 가능
        guard viewerMode == .normal else { return }

        swipeDeleteHandler = SwipeDeleteHandler { [weak self] in
            self?.handleSwipeDelete()
        }

        if let handler = swipeDeleteHandler {
            // transform 대상을 pageViewController.view로 지정 (사진만 이동, UI 버튼 제자리)
            handler.transformTarget = pageViewController.view
            // 이미 삭제대기함인 사진이면 삭제 불가 → 바운스백
            handler.canDelete = { [weak self] in
                guard let self else { return false }
                return !self.coordinator.isTrashed(at: self.currentIndex)
            }
            view.addGestureRecognizer(handler.panGesture)
        }
    }

    /// 초기 미디어 표시 (사진/동영상)
    func displayInitialPhoto() {
        guard let pageVC = createPageViewController(at: currentIndex) else { return }

        // 첫 페이지에 그리드 셀 썸네일 전달 (전환 공백 방지)
        if let photoVC = pageVC as? PhotoPageViewController {
            photoVC.initialImage = initialImage
            initialImage = nil  // 1회용 — 메모리 해제
        }

        pageViewController.setViewControllers(
            [pageVC],
            direction: .forward,
            animated: false,
            completion: nil
        )

        // 초기 페이지가 VideoPageViewController면 비디오 요청 트리거
        if let videoVC = pageVC as? VideoPageViewController {
            videoVC.requestVideoIfNeeded()
        }

        // Phase 2: LOD1 원본 이미지 요청 스케줄링
        // (setViewControllers는 delegate를 호출하지 않으므로 수동 호출)
        scheduleLOD1Request()
    }
}
