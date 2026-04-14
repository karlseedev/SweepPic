//
//  FaceScanSession.swift
//  SweepPic
//
//  인물사진 비교정리 — 세션 데이터 (이어서 정리용)
//  - 분석 완료 시에만 저장
//  - 그룹 데이터는 저장하지 않음 (위치만 저장)
//  - UserDefaults에 경량 저장
//

import Foundation

/// 인물사진 비교정리 세션 데이터
///
/// "이어서 정리" 기능을 위해 마지막 스캔 위치를 기록합니다.
/// 분석 완료 시에만 저장되며, 분석 중 닫기 시에는 저장하지 않습니다.
struct FaceScanSession: Codable {

    /// 마지막 스캔 사진의 촬영 날짜
    let lastAssetDate: Date

    /// 마지막 스캔 사진의 localIdentifier (동일 날짜 내 정밀 위치)
    let lastAssetID: String

    /// 총 스캔 장수
    let scannedCount: Int

    /// 세션 저장 시각
    let savedAt: Date
}
