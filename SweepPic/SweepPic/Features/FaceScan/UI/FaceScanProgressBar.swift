//
//  FaceScanProgressBar.swift
//  SweepPic
//
//  인물사진 비교정리 — 미니 진행바
//  그룹 목록 화면 상단에 고정되어 스캔 진행 상황을 표시합니다.
//
//  스타일: CleanupProgressView 패턴 참조 (경량화)
//  - 프로그레스 바: .systemBlue / .systemGray5
//  - 라벨: 13pt regular, .secondaryLabel
//  - 완료 시 fade out
//

import UIKit

// MARK: - FaceScanProgressBar

/// 인물사진 비교정리 미니 진행바
///
/// 상단에 고정되어 "N그룹 발견 · N / 1,000장 검색" 형식으로 진행 상황을 표시합니다.
/// 분석 완료 시 "분석 완료 · N그룹 발견"으로 변경 후 2~3초 뒤 fade out.
final class FaceScanProgressBar: UIView {

    // MARK: - Constants

    /// 전체 높이
    static let barHeight: CGFloat = 48

    // MARK: - UI Components

    /// 프로그레스 바
    private lazy var progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.tintColor = .systemBlue
        pv.trackTintColor = .systemGray5
        pv.progress = 0
        return pv
    }()

    /// 진행 상황 라벨
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "0그룹 발견 · 0 / 1,000장 검색"
        return label
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        // 오버레이 시 테이블 콘텐츠가 비치지 않도록 배경색 설정
        backgroundColor = .systemBackground

        // 프로그레스 바
        addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])

        // 라벨
        addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
        ])
    }

    // MARK: - Update

    /// 진행 상황 업데이트
    func update(with progress: FaceScanProgress) {
        progressView.setProgress(progress.progress, animated: true)
        statusLabel.text = progress.progressText
    }

    /// 분석 완료 처리 — 완료 문구 표시 (fade out은 부모 VC가 contentInset과 동시 처리)
    func showCompletion(groupCount: Int) {
        // 프로그레스 바 완료
        progressView.setProgress(1.0, animated: true)

        // 완료 문구
        if groupCount > 0 {
            statusLabel.text = "분석 완료 · \(groupCount)그룹 발견"
        } else {
            statusLabel.text = "분석 완료 · 발견된 그룹 없음"
        }
    }
}
