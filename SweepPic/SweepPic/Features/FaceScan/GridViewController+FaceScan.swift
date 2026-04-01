//
//  GridViewController+FaceScan.swift
//  SweepPic
//
//  인물사진 비교정리 — GridViewController 메뉴 연결
//  간편정리 메뉴에서 "인물사진 비교정리" 탭 시 방식 선택 시트 표시
//  선택된 방식으로 FaceScanListViewController push
//

import UIKit
import AppCore
import OSLog

// MARK: - FaceScan Menu Actions

extension GridViewController {

    /// 인물사진 비교정리 메뉴 탭 핸들러
    @objc func faceScanButtonTapped() {
        showFaceScanMethodSheet()
    }

    /// 방식 선택 시트 표시
    private func showFaceScanMethodSheet() {
        let sheet = FaceScanMethodSheet()
        sheet.delegate = self
        sheet.present(from: self)
    }
}

// MARK: - FaceScanMethodSheetDelegate

extension GridViewController: FaceScanMethodSheetDelegate {

    func faceScanMethodSheet(_ sheet: FaceScanMethodSheet, didSelect method: FaceScanMethod) {
        Logger.app.debug("GridVC+FaceScan: 방식 선택 — \(method.description)")

        // FaceScanListVC push
        let listVC = FaceScanListViewController(method: method)
        navigationController?.pushViewController(listVC, animated: true)
    }

    func faceScanMethodSheetDidCancel(_ sheet: FaceScanMethodSheet) {
        Logger.app.debug("GridVC+FaceScan: 방식 선택 취소")
    }
}
