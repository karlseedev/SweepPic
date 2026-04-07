//
//  CleanupMethodSheet.swift
//  SweepPic
//
//  Created by Claude on 2026-01-23.
//
//  정리 방식 선택 시트 (Alert 형태)
//  - 최신사진부터 정리
//  - 이어서 정리 (최신사진부터 정리 후 50장/2000장 제한 도달 시에만 활성화)
//  - 연도별 정리 (해당 연도 이어서 정리 버튼은 연도 선택 화면에서 표시)
//

import UIKit
import Photos

// MARK: - CleanupMethodSheetDelegate

/// 정리 방식 선택 델리게이트
protocol CleanupMethodSheetDelegate: AnyObject {
    /// 정리 방식 선택됨
    /// - Parameters:
    ///   - sheet: 시트
    ///   - method: 선택된 정리 방식
    func cleanupMethodSheet(_ sheet: CleanupMethodSheet, didSelect method: CleanupMethod)

    /// 취소됨
    func cleanupMethodSheetDidCancel(_ sheet: CleanupMethodSheet)
}

// MARK: - CleanupMethodSheet

/// 정리 방식 선택 시트
///
/// Alert 형태로 정리 방식을 선택합니다.
final class CleanupMethodSheet {

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: CleanupMethodSheetDelegate?

    /// 사용 가능한 연도 목록
    private var availableYears: [Int] = []

    // MARK: - Presentation

    /// 시트 표시
    /// - Parameter viewController: 표시할 ViewController
    func present(from viewController: UIViewController) {
        // 메인 ActionSheet 바로 표시 (연도 목록은 "연도별 정리" 선택 시 로드)
        showMainActionSheet(from: viewController)
    }

    // MARK: - Private Methods

    /// 메인 ActionSheet 표시
    private func showMainActionSheet(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: String(localized: "autoCleanup.sheet.title"),
            message: String(localized: "autoCleanup.sheet.message"),
            preferredStyle: .alert
        )

        // 최신사진부터 정리
        // Note: [self] 강참조 - ActionSheet가 닫힐 때까지 sheet 인스턴스 유지 필요
        alert.addAction(UIAlertAction(
            title: String(localized: "autoCleanup.sheet.fromLatest"),
            style: .default
        ) { [self] _ in
            self.delegate?.cleanupMethodSheet(self, didSelect: .fromLatest)
        })

        // 이어서 정리 (미리보기 세션 기준으로 활성화)
        let continueAction: UIAlertAction
        if CleanupPreviewService.canContinue, let lastDate = CleanupPreviewService.lastScanDate {
            let dateString = formatDate(lastDate)
            continueAction = UIAlertAction(
                title: String(localized: "autoCleanup.sheet.continueWithDate \(dateString)"),
                style: .default
            ) { [self] _ in
                self.delegate?.cleanupMethodSheet(self, didSelect: .continueFromLast)
            }
        } else {
            continueAction = UIAlertAction(
                title: String(localized: "autoCleanup.sheet.continue"),
                style: .default,
                handler: nil
            )
            continueAction.isEnabled = false
        }
        alert.addAction(continueAction)

        // 연도별 정리 (선택 시 연도 목록 로드)
        alert.addAction(UIAlertAction(
            title: String(localized: "autoCleanup.sheet.byYear"),
            style: .default
        ) { [self] _ in
            self.loadYearsAndShowSelection(from: viewController)
        })

        // 취소
        alert.addAction(UIAlertAction(
            title: String(localized: "common.cancel"),
            style: .cancel
        ) { [self] _ in
            self.delegate?.cleanupMethodSheetDidCancel(self)
        })

        viewController.present(alert, animated: true)
    }

    /// 연도 목록 로드 후 연도 선택 시트 표시
    /// - 로딩 Alert 표시하며 전체 사진에서 연도 목록 추출
    private func loadYearsAndShowSelection(from viewController: UIViewController) {
        // 로딩 Alert 생성
        let loadingAlert = UIAlertController(
            title: nil,
            message: String(localized: "autoCleanup.sheet.loading"),
            preferredStyle: .alert
        )

        // ActivityIndicator 추가
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()

        loadingAlert.view.addSubview(indicator)

        NSLayoutConstraint.activate([
            indicator.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
            indicator.leadingAnchor.constraint(equalTo: loadingAlert.view.leadingAnchor, constant: 20),
            loadingAlert.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        // 로딩 Alert 표시
        viewController.present(loadingAlert, animated: true)

        // self 강참조로 Task 완료까지 유지
        let strongSelf = self

        // 백그라운드에서 연도 목록 로드
        Task {
            strongSelf.availableYears = await strongSelf.fetchAvailableYears()

            await MainActor.run {
                // 로딩 Alert 닫고 연도 선택 시트 표시
                loadingAlert.dismiss(animated: true) {
                    strongSelf.showYearSelectionSheet(from: viewController)
                }
            }
        }
    }

    /// 연도 선택 ActionSheet 표시
    private func showYearSelectionSheet(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: String(localized: "autoCleanup.sheet.yearSelection.title"),
            message: String(localized: "autoCleanup.sheet.yearSelection.message"),
            preferredStyle: .alert
        )

        // 연도별 이어서 정리 버튼 (조건 충족 시 최상단에 표시)
        // - CleanupPreviewService의 byYear 세션이 이어서 정리 가능할 때
        // - 50장 도달 또는 2000장 검색 도달인 경우
        if CleanupPreviewService.canContinueByYear,
           let targetYear = CleanupPreviewService.lastByYearYear,
           let continueFrom = CleanupPreviewService.lastByYearScanDate {
            let monthString = formatMonth(continueFrom)
            alert.addAction(UIAlertAction(
                title: String(localized: "autoCleanup.sheet.yearContinue \(targetYear) \(monthString)"),
                style: .default
            ) { [self] _ in
                // 해당 연도에서 이어서 정리 (continueFrom으로 시작점 전달)
                self.delegate?.cleanupMethodSheet(self, didSelect: .byYear(year: targetYear, continueFrom: continueFrom))
            })
        }

        // 최신 연도부터 표시
        for year in availableYears {
            alert.addAction(UIAlertAction(
                title: String(localized: "autoCleanup.sheet.yearLabel \(year)"),
                style: .default
            ) { [self] _ in
                self.delegate?.cleanupMethodSheet(self, didSelect: .byYear(year: year))
            })
        }

        // 뒤로가기
        alert.addAction(UIAlertAction(
            title: String(localized: "autoCleanup.sheet.back"),
            style: .cancel
        ) { [self] _ in
            self.showMainActionSheet(from: viewController)
        })

        viewController.present(alert, animated: true)
    }

    /// 사진이 있는 연도 목록 가져오기
    /// - 전체 사진에서 연도 추출 (로딩 Alert과 함께 사용)
    private func fetchAvailableYears() async -> [Int] {
        return await withCheckedContinuation { continuation in
            var years = Set<Int>()

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            // 전체 사진에서 연도 추출
            let fetchResult = PHAsset.fetchAssets(with: options)

            fetchResult.enumerateObjects { asset, _, _ in
                if let date = asset.creationDate {
                    let year = Calendar.current.component(.year, from: date)
                    years.insert(year)
                }
            }

            // 최신 연도부터 정렬
            let sortedYears = years.sorted(by: >)
            continuation.resume(returning: sortedYears)
        }
    }

    /// 날짜 포맷팅 (연도 포함, locale-aware)
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter.string(from: date)
    }

    /// 월만 포맷팅 (연도별 이어서용, locale-aware)
    private func formatMonth(_ date: Date?) -> String {
        guard let date = date else { return "" }

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }
}
