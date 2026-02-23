//
//  CoachMarkOverlayView+CoachMarkD.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-23.
//
//  코치마크 D: 저품질 자동 정리 안내
//  - 트리거 1 (자동): A 완료 + E-1 완료 + 그리드 3초 체류 → 정리 버튼 하이라이트 + 썸네일
//  - 트리거 2 (수동): D 미완료 + 정리 버튼 탭 → 하이라이트 없음 + 썸네일
//  - 레이아웃: 딤 배경 + (선택적)버튼 구멍 + 타이틀 + 썸네일 3장 + 설명 + [확인]
//  - [확인] → 탭 모션 (트리거 1) 또는 즉시 dismiss (트리거 2) → 정리 시트
//

import UIKit
import Photos
import ObjectiveC
import AppCore

// MARK: - Associated Object Keys (D 전용)

private var dCardViewKey: UInt8 = 0
private var dThumbnailViewsKey: UInt8 = 0
private var dHasHighlightKey: UInt8 = 0

// MARK: - Coach Mark D: Auto Cleanup Guide

extension CoachMarkOverlayView {

    // MARK: - Stored Properties (Associated Objects)

    /// D 전용 카드 뷰 참조
    private var dCardView: UIView? {
        get { objc_getAssociatedObject(self, &dCardViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &dCardViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// D 전용 썸네일 뷰 배열
    private var dThumbnailViews: [UIImageView]? {
        get { objc_getAssociatedObject(self, &dThumbnailViewsKey) as? [UIImageView] }
        set { objc_setAssociatedObject(self, &dThumbnailViewsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// D: 정리 버튼 하이라이트 여부 (트리거 1: true, 트리거 2: false)
    /// 탭 모션 여부 결정에 사용
    private var dHasHighlight: Bool {
        get { objc_getAssociatedObject(self, &dHasHighlightKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &dHasHighlightKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Show

    /// D: 저품질 자동 정리 안내 표시
    /// - Parameters:
    ///   - highlightFrame: 정리 버튼 프레임 (트리거 1: 버튼 위치, 트리거 2: nil → 전체 딤)
    ///   - scanResult: 사전 스캔 결과 (nil이면 텍스트 폴백)
    ///   - window: 표시할 윈도우
    ///   - onConfirm: [확인] + dismiss 후 실행할 콜백 (showCleanupMethodSheet)
    static func showAutoCleanup(
        highlightFrame: CGRect?,
        scanResult: CoachMarkDPreScanner.Result?,
        in window: UIWindow,
        onConfirm: @escaping () -> Void
    ) {
        // VoiceOver 가드
        guard !UIAccessibility.isVoiceOverRunning else { return }

        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .autoCleanup
        overlay.highlightFrame = highlightFrame ?? .zero
        overlay.dHasHighlight = (highlightFrame != nil)
        overlay.onConfirm = onConfirm
        overlay.alpha = 0

        // 딤 배경 (버튼 구멍 포함 또는 전체 딤)
        overlay.updateDimPath()
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // 카드 구성 (썸네일 + 텍스트 + 확인 버튼)
        let assets = scanResult?.lowQualityAssets ?? []
        overlay.buildAutoCleanupCard(assets: assets, hasHighlight: highlightFrame != nil)

        // 페이드인
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
    }

    // MARK: - Build Card

    /// D 카드 구성: 타이틀 + 썸네일 그리드 + 설명 + [확인]
    /// - Parameters:
    ///   - assets: 저품질 asset 배열 (최대 3개)
    ///   - hasHighlight: 정리 버튼 하이라이트 여부 (트리거에 따라 문구 변경)
    private func buildAutoCleanupCard(assets: [PHAsset], hasHighlight: Bool) {
        let card = UIView()
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        // 시스템 팝업 스타일 blur 배경
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.frame = card.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.addSubview(blur)
        addSubview(card)
        dCardView = card

        // --- 타이틀 ---
        let titleLabel = UILabel()
        titleLabel.text = "보관함에서 저품질 사진이 발견됐어요"
        titleLabel.textColor = .white
        titleLabel.font = Self.bodyFont
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        // --- 썸네일 컨테이너 ---
        let thumbContainer = UIView()
        thumbContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(thumbContainer)

        // 썸네일 크기 계산: (화면너비 - 48(카드마진) - 40(내부패딩) - 16(간격)) / 3
        let screenWidth = bounds.width
        let thumbSize = (screenWidth - 48 - 40 - 16) / 3

        // 썸네일 뷰 생성
        var thumbnailViews: [UIImageView] = []
        let count = min(assets.count, 3)

        for _ in 0..<count {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 8
            iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            iv.translatesAutoresizingMaskIntoConstraints = false
            thumbContainer.addSubview(iv)
            thumbnailViews.append(iv)

            // 크기 제약
            NSLayoutConstraint.activate([
                iv.widthAnchor.constraint(equalToConstant: thumbSize),
                iv.heightAnchor.constraint(equalToConstant: thumbSize),
                iv.topAnchor.constraint(equalTo: thumbContainer.topAnchor),
                iv.bottomAnchor.constraint(equalTo: thumbContainer.bottomAnchor),
            ])
        }

        // 썸네일 수평 배치 (중앙 정렬, 간격 8pt)
        if count == 1 {
            thumbnailViews[0].centerXAnchor.constraint(equalTo: thumbContainer.centerXAnchor).isActive = true
        } else if count == 2 {
            thumbnailViews[0].trailingAnchor.constraint(equalTo: thumbContainer.centerXAnchor, constant: -4).isActive = true
            thumbnailViews[1].leadingAnchor.constraint(equalTo: thumbContainer.centerXAnchor, constant: 4).isActive = true
        } else if count == 3 {
            thumbnailViews[1].centerXAnchor.constraint(equalTo: thumbContainer.centerXAnchor).isActive = true
            thumbnailViews[0].trailingAnchor.constraint(equalTo: thumbnailViews[1].leadingAnchor, constant: -8).isActive = true
            thumbnailViews[2].leadingAnchor.constraint(equalTo: thumbnailViews[1].trailingAnchor, constant: 8).isActive = true
        }

        dThumbnailViews = thumbnailViews

        // 썸네일 이미지 로딩
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: thumbSize * scale, height: thumbSize * scale)
        for (i, asset) in assets.prefix(3).enumerated() {
            let imageView = thumbnailViews[i]
            _ = ImagePipeline.shared.requestImage(
                for: asset,
                targetSize: pixelSize,
                contentMode: .aspectFill,
                quality: .fast
            ) { image, _ in
                imageView.image = image
            }
        }

        // --- 설명 ---
        let descLabel = UILabel()
        // 트리거 1: "~사용해보세요" / 트리거 2: "~기능입니다"
        let descText = hasHighlight
            ? "흔들리거나 초점이 맞지 않은\n사진들을 AI가 자동으로 찾아주는\n정리 기능을 사용해보세요"
            : "흔들리거나 초점이 맞지 않은\n사진들을 AI가 자동으로 찾아주는\n정리 기능입니다"
        descLabel.text = descText
        descLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        descLabel.font = Self.bodyFont
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(descLabel)

        // --- 확인 버튼 ---
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = true
        confirmButton.alpha = 1
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(confirmButton)

        // --- 레이아웃 ---
        // 썸네일 유무에 따라 분기
        let hasThumbnails = count > 0

        // 카드 외부 제약
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -48),
        ])

        // 카드 내부 제약
        NSLayoutConstraint.activate([
            // 타이틀
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])

        if hasThumbnails {
            // 썸네일 있음: 타이틀 → 썸네일 → 설명 → 확인
            NSLayoutConstraint.activate([
                thumbContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
                thumbContainer.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                thumbContainer.heightAnchor.constraint(equalToConstant: thumbSize),

                descLabel.topAnchor.constraint(equalTo: thumbContainer.bottomAnchor, constant: 16),
                descLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                descLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            ])
        } else {
            // 썸네일 없음: 타이틀 바로 아래 설명
            NSLayoutConstraint.activate([
                descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
                descLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                descLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            ])
        }

        // 확인 버튼
        NSLayoutConstraint.activate([
            confirmButton.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 20),
            confirmButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            confirmButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Confirm Sequence

    /// D 전용: [확인] 탭 후 시퀀스
    /// 트리거 1 (자동): 카드 페이드아웃 → 탭 모션 on 정리 버튼 → dismiss → onConfirm
    /// 트리거 2 (수동): 카드 페이드아웃 → dismiss → onConfirm (탭 모션 없음)
    func startD_ConfirmSequence() {
        // 1. 카드 + 확인 버튼 페이드아웃 (0.2초)
        UIView.animate(withDuration: 0.2, animations: {
            self.dCardView?.alpha = 0
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }

            if self.dHasHighlight && self.highlightFrame != .zero {
                // 트리거 1: 정리 버튼 위치에 탭 모션
                let targetCenter = CGPoint(
                    x: self.highlightFrame.midX,
                    y: self.highlightFrame.midY
                )
                self.performDTapMotion(at: targetCenter) { [weak self] in
                    self?.finishDSequence()
                }
            } else {
                // 트리거 2: 탭 모션 없이 바로 완료
                self.finishDSequence()
            }
        }
    }

    /// D 시퀀스 최종 완료: dismiss + onConfirm
    private func finishDSequence() {
        let confirmAction = onConfirm
        dismiss()
        // dismiss 완료 후 정리 시트 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            confirmAction?()
        }
    }

    /// D 전용 탭 모션 (C의 performCTapMotion과 동일한 패턴)
    /// 정리 버튼 위치에서 손가락 등장 → 누르기 → 떼기
    private func performDTapMotion(at targetCenter: CGPoint, completion: @escaping () -> Void) {
        // Reduce Motion 시 탭 모션 생략
        if UIAccessibility.isReduceMotionEnabled {
            completion()
            return
        }

        // 손가락 아이콘 배치 (C의 오프셋과 동일)
        let fingerWidth = fingerView.bounds.width
        let fingerHeight = fingerView.bounds.height
        let initialCenter = CGPoint(
            x: targetCenter.x + fingerWidth * 0.08,
            y: targetCenter.y + fingerHeight * 0.4
        )

        fingerView.sizeToFit()
        fingerView.center = initialCenter
        fingerView.alpha = 0
        fingerView.transform = .identity
        fingerView.layer.shadowRadius = 6
        fingerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        fingerView.layer.shadowOpacity = 0.3
        addSubview(fingerView)

        // Phase 1: 등장 (0.15초)
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                self.fingerView.alpha = 1
            }
        ) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { completion(); return }

            // Phase 2: 누르기 (0.12초, spring)
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0,
                options: [],
                animations: {
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
                    self.fingerView.center.y = initialCenter.y + 2.5
                    self.fingerView.layer.shadowRadius = 2
                    self.fingerView.layer.shadowOffset = CGSize(width: 0, height: 1)
                    self.fingerView.layer.shadowOpacity = 0.15
                }
            ) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else { completion(); return }

                // Phase 3: 떼기 (0.2초, spring 반동)
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0.05,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 2.0,
                    options: [],
                    animations: {
                        self.fingerView.transform = .identity
                        self.fingerView.center = initialCenter
                        self.fingerView.alpha = 0
                        self.fingerView.layer.shadowRadius = 6
                        self.fingerView.layer.shadowOffset = CGSize(width: 0, height: 2)
                        self.fingerView.layer.shadowOpacity = 0.3
                    }
                ) { _ in
                    completion()
                }
            }
        }
    }

    // MARK: - Cleanup (D 전용)

    /// D 전용 리소스 정리 (dismiss 시 호출)
    func cleanupAutoCleanup() {
        guard coachMarkType == .autoCleanup else { return }

        dCardView?.removeFromSuperview()
        dCardView = nil
        dThumbnailViews = nil
    }
}
