//
//  CleanupMethodSheet.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-23.
//
//  정리 방식 선택 시트 (Alert 형태)
//  - 최신사진부터 정리
//  - 이어서 정리 (이전 이력 있을 때만 활성화)
//  - 연도별 정리
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

    /// 이전 세션 (이어서 정리용)
    private let lastSession: CleanupSession?

    /// 사용 가능한 연도 목록
    private var availableYears: [Int] = []

    // MARK: - Initialization

    /// 시트 초기화
    /// - Parameter lastSession: 이전 세션 (nil이면 "이어서 정리" 비활성화)
    init(lastSession: CleanupSession?) {
        self.lastSession = lastSession
    }

    // MARK: - Presentation

    /// 시트 표시
    /// - Parameter viewController: 표시할 ViewController
    func present(from viewController: UIViewController) {
        // self를 강참조하여 Task 완료까지 유지
        // (로컬 변수로 생성된 sheet가 Task 완료 전에 해제되는 것을 방지)
        let strongSelf = self

        // 연도 목록 가져오기 (백그라운드에서)
        Task {
            strongSelf.availableYears = await strongSelf.fetchAvailableYears()

            await MainActor.run {
                strongSelf.showMainActionSheet(from: viewController)
            }
        }
    }

    // MARK: - Private Methods

    /// 메인 ActionSheet 표시
    private func showMainActionSheet(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "정리 방식 선택",
            message: "어떤 방식으로 정리할까요?",
            preferredStyle: .actionSheet
        )

        // 최신사진부터 정리
        // Note: [self] 강참조 - ActionSheet가 닫힐 때까지 sheet 인스턴스 유지 필요
        alert.addAction(UIAlertAction(
            title: "최신사진부터 정리",
            style: .default
        ) { [self] _ in
            self.delegate?.cleanupMethodSheet(self, didSelect: .fromLatest)
        })

        // 이어서 정리 (이전 이력이 있을 때만)
        if let session = lastSession {
            let dateString = formatDate(session.lastAssetDate)
            let title = "이어서 정리 (\(dateString)부터)"

            alert.addAction(UIAlertAction(
                title: title,
                style: .default
            ) { [self] _ in
                self.delegate?.cleanupMethodSheet(self, didSelect: .continueFromLast)
            })
        }

        // 연도별 정리
        if !availableYears.isEmpty {
            alert.addAction(UIAlertAction(
                title: "연도별 정리",
                style: .default
            ) { [self] _ in
                self.showYearSelectionSheet(from: viewController)
            })
        }

        // 취소
        alert.addAction(UIAlertAction(
            title: "취소",
            style: .cancel
        ) { [self] _ in
            self.delegate?.cleanupMethodSheetDidCancel(self)
        })

        // iPad 지원
        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        viewController.present(alert, animated: true)
    }

    /// 연도 선택 ActionSheet 표시
    private func showYearSelectionSheet(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "연도 선택",
            message: "정리할 연도를 선택하세요",
            preferredStyle: .actionSheet
        )

        // 최신 연도부터 표시
        for year in availableYears {
            alert.addAction(UIAlertAction(
                title: "\(year)년",
                style: .default
            ) { [self] _ in
                self.delegate?.cleanupMethodSheet(self, didSelect: .byYear(year: year))
            })
        }

        // 뒤로가기
        alert.addAction(UIAlertAction(
            title: "뒤로",
            style: .cancel
        ) { [self] _ in
            self.showMainActionSheet(from: viewController)
        })

        // iPad 지원
        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        viewController.present(alert, animated: true)
    }

    /// 사진이 있는 연도 목록 가져오기
    private func fetchAvailableYears() async -> [Int] {
        return await withCheckedContinuation { continuation in
            var years = Set<Int>()

            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            // 최근 사진 1000장에서 연도 추출 (성능 고려)
            let fetchResult = PHAsset.fetchAssets(with: options)
            let count = min(fetchResult.count, 1000)

            fetchResult.enumerateObjects(
                at: IndexSet(integersIn: 0..<count),
                options: []
            ) { asset, _, _ in
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

    /// 날짜 포맷팅
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }
}
