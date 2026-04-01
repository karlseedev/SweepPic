// BaseGridViewController+PinchZoom.swift
// 핀치줌 관련 코드 분리
//
// 현재 상태: 비활성화 (isPinchZoomEnabled = false)
// 활성화 방법: isPinchZoomEnabled = true로 변경
// TODO: docs/todo/260121zoom5.md, 260121zoom5-impl.md 기반으로 재구현 예정
//
// 이 파일에 포함된 기능:
// - 핀치줌 상수 (임계값, 쿨다운)
// - 핀치줌 제스처 설정
// - 핀치줌 제스처 핸들러
// - 줌 수행 로직

import UIKit
import AppCore

// MARK: - Pinch Zoom Extension

extension BaseGridViewController {

    // MARK: - 활성화 플래그

    /// 핀치줌 활성화 여부
    /// - false: 핀치줌 비활성화 (현재 - zoom5 재구현 전까지)
    /// - true: 핀치줌 활성화
    static let isPinchZoomEnabled = false

    // MARK: - 상수

    /// 핀치 줌 확대 임계값 (scale > 1.15 → 확대)
    static let pinchZoomInThreshold: CGFloat = 1.15

    /// 핀치 줌 축소 임계값 (scale < 0.85 → 축소)
    static let pinchZoomOutThreshold: CGFloat = 0.85

    /// 핀치 줌 쿨다운 (중복 트리거 방지)
    static let pinchCooldown: TimeInterval = 0.2

    // MARK: - 제스처 설정

    /// 핀치줌 제스처 설정
    /// - setupGestures()에서 호출됨
    /// - isPinchZoomEnabled가 false면 제스처를 등록하지 않음
    func setupPinchZoomGesture() {
        // 비활성화 상태면 제스처 등록 안함
        guard Self.isPinchZoomEnabled else {
            return
        }

        let pinchGesture = UIPinchGestureRecognizer(
            target: self,
            action: #selector(handlePinchGesture(_:))
        )
        collectionView.addGestureRecognizer(pinchGesture)
    }

    // MARK: - 제스처 핸들러

    /// 핀치 줌 제스처 처리
    /// - began: 앵커 에셋 ID 저장
    /// - changed: 임계값 체크 후 줌 수행
    /// - ended/cancelled: 앵커 초기화
    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        // A-1 활성 중이면 핀치 줌 차단
        if CoachMarkManager.shared.isA1Active { return }

        switch gesture.state {
        case .began:
            // 앵커 에셋 ID 저장 (padding 보정)
            let location = gesture.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: location) {
                pinchAnchorAssetID = assetIDForCollectionIndexPath(indexPath)
            }

        case .changed:
            // 쿨다운 체크
            if let lastTime = lastPinchZoomTime,
               Date().timeIntervalSince(lastTime) < Self.pinchCooldown {
                return
            }

            // 임계값 체크
            let scale = gesture.scale
            var newColumnCount: GridColumnCount?

            if scale > Self.pinchZoomInThreshold {
                // 확대 (열 수 감소)
                newColumnCount = currentGridColumnCount.zoomIn
            } else if scale < Self.pinchZoomOutThreshold {
                // 축소 (열 수 증가)
                newColumnCount = currentGridColumnCount.zoomOut
            }

            // 열 수가 변경되면 레이아웃 업데이트
            if let newCount = newColumnCount, newCount != currentGridColumnCount {
                performZoom(to: newCount)
                gesture.scale = 1.0  // 스케일 리셋
            }

        case .ended, .cancelled:
            pinchAnchorAssetID = nil

        default:
            break
        }
    }

    // MARK: - 줌 수행

    /// 줌 수행
    /// - Parameter columns: 새 열 수
    /// - 앵커 셀 기준으로 스크롤 위치 유지하며 열 수 변경
    func performZoom(to columns: GridColumnCount) {
        // 쿨다운 시간 기록
        lastPinchZoomTime = Date()

        // 1. 앵커 assetID 저장 (현재 padding 기준, column 변경 전)
        let anchorAssetID: String? = {
            if let id = pinchAnchorAssetID { return id }
            // 앵커가 없으면 화면 중앙 셀 사용
            let centerPoint = CGPoint(
                x: collectionView.bounds.midX,
                y: collectionView.bounds.midY + collectionView.contentOffset.y
            )
            if let centerIndexPath = collectionView.indexPathForItem(at: centerPoint) {
                return assetIDForCollectionIndexPath(centerIndexPath)
            }
            return nil
        }()

        // 2. 열 수 업데이트 (paddingCellCount도 변경됨)
        currentGridColumnCount = columns
        updateCellSize()

        // 3. 새 padding 기준으로 anchorIndexPath 계산
        let anchorIndexPath = anchorAssetID.flatMap { collectionIndexPath(for: $0) }

        // 레이아웃 애니메이션
        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let self = self else { return }

            // 새 레이아웃 적용
            self.collectionView.setCollectionViewLayout(
                self.createLayout(columns: columns),
                animated: false
            )

            // 앵커 위치로 스크롤 (drift 0px 목표)
            if let indexPath = anchorIndexPath {
                self.collectionView.scrollToItem(
                    at: indexPath,
                    at: .centeredVertically,
                    animated: false
                )
            }
        } completion: { [weak self] _ in
            // 줌 애니메이션 완료 후 추가 처리 (서브클래스 확장 지점)
            self?.didPerformZoom(to: columns)
        }

    }
}
