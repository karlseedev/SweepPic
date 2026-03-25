//
//  CleanupSessionStoreProtocol.swift
//  SweepPic
//
//  Created by Claude on 2026-01-22.
//
//  정리 세션 저장소 프로토콜 정의
//  - 세션 저장/로드/삭제
//  - "이어서 정리" 기능 지원
//

import Foundation

/// 정리 세션 저장소 프로토콜
///
/// 정리 세션을 파일로 저장하고 로드하는 인터페이스.
/// "이어서 정리" 기능을 위해 마지막 세션 정보를 유지.
/// fromLatest/continueFromLast 세션과 byYear 세션을 분리 저장.
protocol CleanupSessionStoreProtocol {

    /// 현재 저장된 세션 (하위 호환용, latestSession 우선 반환)
    /// - 저장된 세션이 없으면 nil
    var currentSession: CleanupSession? { get }

    /// 최신사진부터/이어서 정리 세션
    var latestSession: CleanupSession? { get }

    /// 연도별 정리 세션
    var byYearSession: CleanupSession? { get }

    /// 이어서 정리 가능 여부
    /// - 이전 세션이 존재하고 완료 상태일 때 true
    var canContinue: Bool { get }

    /// 세션 저장
    /// - Parameter session: 저장할 세션
    /// - 정상 종료 시에만 저장 (앱 종료 시 소실됨)
    func save(_ session: CleanupSession)

    /// 세션 로드
    /// - Returns: 저장된 세션 (없으면 nil)
    func load() -> CleanupSession?

    /// 세션 삭제
    /// - 저장된 세션 파일 삭제
    func clear()

    /// 세션 부분 업데이트
    /// - Parameters:
    ///   - lastAssetDate: 마지막 탐색 날짜
    ///   - lastAssetID: 마지막 탐색 사진 ID
    ///   - scannedCount: 검색 수
    ///   - foundCount: 찾은 수
    /// - 진행 중 업데이트용 (전체 세션 저장보다 가벼움)
    func update(
        lastAssetDate: Date?,
        lastAssetID: String?,
        scannedCount: Int,
        foundCount: Int
    )
}
