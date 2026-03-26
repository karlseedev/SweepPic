//
//  YearLoadingAlertTester.swift
//  SweepPic
//
//  Created by Claude on 2026-01-26.
//
//  연도 목록 로딩 Alert UI 테스트용
//  디버그 빌드에서만 사용
//

#if DEBUG
import UIKit

/// 연도 목록 로딩 Alert 테스터
///
/// 로딩 Alert UI를 미리 확인하기 위한 디버그 도구
final class YearLoadingAlertTester {

    /// 로딩 Alert 표시 (테스트용)
    /// - Parameters:
    ///   - viewController: 표시할 ViewController
    ///   - duration: 표시 시간 (초), nil이면 수동으로 닫아야 함
    static func showLoadingAlert(
        from viewController: UIViewController,
        duration: TimeInterval? = 3.0
    ) {
        let alert = UIAlertController(
            title: nil,
            message: "사진별 연도 목록 확인 중",
            preferredStyle: .alert
        )

        // ActivityIndicator 추가
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()

        alert.view.addSubview(indicator)

        NSLayoutConstraint.activate([
            indicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor),
            indicator.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
            alert.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        viewController.present(alert, animated: true)

        // 지정된 시간 후 자동으로 닫기
        if let duration = duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                alert.dismiss(animated: true)
            }
        }
    }

    /// 로딩 Alert을 표시하고 완료 후 콜백 실행
    /// - Parameters:
    ///   - viewController: 표시할 ViewController
    ///   - task: 백그라운드 작업
    ///   - completion: 완료 후 실행할 콜백
    static func showLoadingAlert<T>(
        from viewController: UIViewController,
        task: @escaping () async -> T,
        completion: @escaping (T) -> Void
    ) {
        let alert = UIAlertController(
            title: nil,
            message: "사진별 연도 목록 확인 중",
            preferredStyle: .alert
        )

        // ActivityIndicator 추가
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()

        alert.view.addSubview(indicator)

        NSLayoutConstraint.activate([
            indicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor),
            indicator.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
            alert.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        viewController.present(alert, animated: true)

        // 백그라운드 작업 실행
        Task {
            let result = await task()

            await MainActor.run {
                alert.dismiss(animated: true) {
                    completion(result)
                }
            }
        }
    }
}

// MARK: - UIViewController Extension

extension UIViewController {

    /// 연도 로딩 Alert 테스트 (디버그용)
    /// - 3초 후 자동으로 닫힘
    func debugShowYearLoadingAlert() {
        YearLoadingAlertTester.showLoadingAlert(from: self, duration: 3.0)
    }
}
#endif
