//
//  FaceScanMethodSheet.swift
//  SweepPic
//
//  인물사진 비교정리 — 방식 선택 시트
//  - 최신사진부터 정리
//  - 이어서 정리 (이전 완료 세션이 있을 때만 활성)
//  - 연도별 정리
//
//  CleanupMethodSheet 패턴 참조
//

import UIKit
import Photos

// MARK: - FaceScanMethodSheetDelegate

/// 스캔 방식 선택 델리게이트
protocol FaceScanMethodSheetDelegate: AnyObject {
    /// 스캔 방식 선택됨
    func faceScanMethodSheet(_ sheet: FaceScanMethodSheet, didSelect method: FaceScanMethod)
    /// 취소됨
    func faceScanMethodSheetDidCancel(_ sheet: FaceScanMethodSheet)
}

// MARK: - FaceScanMethodSheet

/// 인물사진 비교정리 방식 선택 시트
///
/// Alert 형태로 스캔 방식을 선택합니다.
final class FaceScanMethodSheet {

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: FaceScanMethodSheetDelegate?

    /// 사용 가능한 연도 목록
    private var availableYears: [Int] = []

    // MARK: - Presentation

    /// 시트 표시
    func present(from viewController: UIViewController) {
        showMainAlert(from: viewController)
    }

    // MARK: - Private Methods

    /// 메인 Alert 표시
    private func showMainAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: String(localized: "faceScan.sheet.title"),
            message: String(localized: "faceScan.sheet.message"),
            preferredStyle: .alert
        )

        // 최신사진부터 정리
        alert.addAction(UIAlertAction(
            title: String(localized: "faceScan.sheet.fromLatest"),
            style: .default
        ) { [self] _ in
            self.delegate?.faceScanMethodSheet(self, didSelect: .fromLatest)
        })

        // 이어서 정리 (이전 완료 세션 기준으로 활성화)
        let continueAction: UIAlertAction
        if FaceScanService.canContinue, let lastDate = FaceScanService.lastScanDate {
            let dateString = formatDate(lastDate)
            continueAction = UIAlertAction(
                title: String(localized: "faceScan.sheet.continueWithDate \(dateString)"),
                style: .default
            ) { [self] _ in
                self.delegate?.faceScanMethodSheet(self, didSelect: .continueFromLast)
            }
        } else {
            continueAction = UIAlertAction(
                title: String(localized: "faceScan.sheet.continue"),
                style: .default,
                handler: nil
            )
            continueAction.isEnabled = false
        }
        alert.addAction(continueAction)

        // 연도별 정리
        alert.addAction(UIAlertAction(
            title: String(localized: "faceScan.sheet.byYear"),
            style: .default
        ) { [self] _ in
            self.loadYearsAndShowSelection(from: viewController)
        })

        // 취소
        alert.addAction(UIAlertAction(title: String(localized: "common.cancel"), style: .cancel) { [self] _ in
            self.delegate?.faceScanMethodSheetDidCancel(self)
        })

        viewController.present(alert, animated: true)
    }

    /// 연도 선택 화면 표시
    /// - 로딩 Alert 표시하며 전체 사진에서 연도 목록 추출
    /// - CleanupMethodSheet 패턴: strongSelf + 로딩 Alert dismiss completion 내 present
    private func loadYearsAndShowSelection(from viewController: UIViewController) {
        // 로딩 Alert 생성
        let loadingAlert = UIAlertController(
            title: nil,
            message: String(localized: "faceScan.sheet.loading"),
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
        // Note: [self] 강참조 — 비동기 작업 완료 시까지 sheet 인스턴스 유지 필요
        let strongSelf = self

        // 백그라운드에서 연도 목록 로드
        Task {
            let years = await withCheckedContinuation { continuation in
                continuation.resume(returning: strongSelf.fetchAvailableYears())
            }
            strongSelf.availableYears = years

            await MainActor.run {
                // 로딩 Alert 닫고 연도 선택 시트 표시
                loadingAlert.dismiss(animated: true) {
                    strongSelf.showYearSelectionAlert(from: viewController)
                }
            }
        }
    }

    /// 연도 선택 Alert
    private func showYearSelectionAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: String(localized: "faceScan.sheet.yearSelection.title"),
            message: String(localized: "faceScan.sheet.yearSelection.message"),
            preferredStyle: .actionSheet
        )

        // 연도별 이어서 정리 버튼 (조건 충족 시 최상단에 별도 표시)
        if FaceScanService.canContinueByYear,
           let targetYear = FaceScanService.lastByYearYear,
           let continueFrom = FaceScanService.lastByYearScanDate {
            let dateString = formatDate(continueFrom)
            alert.addAction(UIAlertAction(
                title: String(localized: "faceScan.sheet.yearContinue \(String(targetYear)) \(dateString)"),
                style: .default
            ) { [self] _ in
                self.delegate?.faceScanMethodSheet(
                    self,
                    didSelect: .byYear(year: targetYear, continueFrom: continueFrom)
                )
            })
        }

        // 최신 ��도부터 표시
        for year in availableYears {
            alert.addAction(UIAlertAction(
                title: String(localized: "faceScan.sheet.yearLabel \(String(year))"),
                style: .default
            ) { [self] _ in
                self.delegate?.faceScanMethodSheet(
                    self,
                    didSelect: .byYear(year: year)
                )
            })
        }

        alert.addAction(UIAlertAction(title: String(localized: "common.cancel"), style: .cancel) { [self] _ in
            self.delegate?.faceScanMethodSheetDidCancel(self)
        })

        viewController.present(alert, animated: true)
    }

    /// 사용 가능한 연도 목록 추출 (PHAsset creationDate 기반)
    private func fetchAvailableYears() -> [Int] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var years = Set<Int>()
        let calendar = Calendar.current

        result.enumerateObjects { asset, _, _ in
            if let date = asset.creationDate {
                years.insert(calendar.component(.year, from: date))
            }
        }

        return years.sorted(by: >)  // 최신 연도 먼저
    }

    /// 날짜 포맷팅 ("2026년 3월" 형식)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }
}
