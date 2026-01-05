//
//  AnalysisLoadingIndicator.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  뷰어에서 유사 사진 분석 중임을 표시하는 로딩 인디케이터입니다.
//  분석 상태가 notAnalyzed → analyzing일 때 표시되고,
//  분석 완료 시 자동으로 숨겨집니다.
//

import UIKit

/// 유사 사진 분석 중 로딩 인디케이터
///
/// 뷰어에서 캐시 miss 시 분석 중임을 사용자에게 표시합니다.
/// 분석 완료 후 자동으로 페이드아웃됩니다.
final class AnalysisLoadingIndicator: UIView {

    // MARK: - Constants

    private enum Constants {
        /// 인디케이터 크기
        static let indicatorSize: CGFloat = 40

        /// 배경 모서리 반경
        static let cornerRadius: CGFloat = 12

        /// 배경 패딩
        static let padding: CGFloat = 16

        /// 페이드 애니메이션 시간
        static let fadeDuration: TimeInterval = 0.2

        /// 레이블 상단 여백
        static let labelTopMargin: CGFloat = 8

        /// 폰트 크기
        static let fontSize: CGFloat = 12
    }

    // MARK: - Subviews

    /// 로딩 스피너
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    /// 로딩 레이블
    private lazy var loadingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "분석 중..."
        label.textColor = .white
        label.font = .systemFont(ofSize: Constants.fontSize, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    /// 배경 뷰 (블러 효과)
    private lazy var backgroundView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = Constants.cornerRadius
        view.clipsToBounds = true
        return view
    }()

    // MARK: - State

    /// 표시 중 여부
    private(set) var isShowing: Bool = false

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // 기본 설정
        isUserInteractionEnabled = false
        alpha = 0

        // 배경 뷰 추가
        addSubview(backgroundView)

        // 스피너와 레이블을 contentView에 추가
        backgroundView.contentView.addSubview(activityIndicator)
        backgroundView.contentView.addSubview(loadingLabel)

        // 레이아웃 설정
        NSLayoutConstraint.activate([
            // 배경 뷰: 부모 중앙
            backgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),

            // 스피너: 배경 뷰 상단 중앙
            activityIndicator.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor, constant: Constants.padding),
            activityIndicator.centerXAnchor.constraint(equalTo: backgroundView.contentView.centerXAnchor),
            activityIndicator.widthAnchor.constraint(equalToConstant: Constants.indicatorSize),
            activityIndicator.heightAnchor.constraint(equalToConstant: Constants.indicatorSize),

            // 레이블: 스피너 아래
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: Constants.labelTopMargin),
            loadingLabel.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor, constant: Constants.padding),
            loadingLabel.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor, constant: -Constants.padding),
            loadingLabel.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor, constant: -Constants.padding)
        ])

        // 접근성
        isAccessibilityElement = true
        accessibilityLabel = "유사 사진 분석 중"
    }

    // MARK: - Public Methods

    /// 인디케이터 표시
    func show() {
        guard !isShowing else { return }
        isShowing = true

        // 스피너 시작
        activityIndicator.startAnimating()

        // 페이드인
        UIView.animate(withDuration: Constants.fadeDuration) {
            self.alpha = 1
        }
    }

    /// 인디케이터 숨기기
    func hide() {
        guard isShowing else { return }
        isShowing = false

        // 페이드아웃
        UIView.animate(withDuration: Constants.fadeDuration) {
            self.alpha = 0
        } completion: { _ in
            self.activityIndicator.stopAnimating()
        }
    }

    /// 레이블 텍스트 변경
    /// - Parameter text: 새 텍스트
    func setLabelText(_ text: String) {
        loadingLabel.text = text
    }
}
