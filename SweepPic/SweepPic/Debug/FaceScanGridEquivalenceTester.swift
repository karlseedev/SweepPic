//
//  FaceScanGridEquivalenceTester.swift
//  SweepPic
//
//  FaceScan ↔ Grid 동등성 검증 하네스 (Stage 1 + Stage 2)
//
//  Stage 1 (Engine Equivalence):
//    같은 입력 범위에서 Grid 엔진(formGroupsForRange)과 FaceScan 엔진(analyzeChunk)의
//    알고리즘 결과를 자동 비교합니다. 반복 실행 가능하며 개발 중 주 사용 도구입니다.
//
//  Stage 2 (Live Grid Verification):
//    사용자가 실제 Grid에서 본 최종 상태(SimilarityCache.shared snapshot)와
//    FaceScan 결과를 비교합니다. 수동 확인이며 출시 전 최종 승인용입니다.
//
//  핵심 원칙:
//  - production 로직을 바꾸지 않는다 (formGroupsForRange 그대로 호출)
//  - 캐시 오염 없음 (새 인스턴스 주입으로 격리)
//  - 부수효과 억제 (#if DEBUG + self !== .shared 가드)
//  - 비교 단위: Set(memberAssetIDs) — 완전 일치만 통과
//

#if DEBUG

import Foundation
import Photos
import OSLog
import AppCore

// MARK: - 비교 타입

/// 정규화된 그룹 비교 단위
/// memberAssetIDs를 정렬하여 순서 무관 비교를 수행합니다.
struct GroupSignature: Hashable, Codable {
    /// 정렬된 멤버 assetID 배열
    let members: [String]

    /// memberAssetIDs 배열에서 GroupSignature를 생성합니다.
    init(members: [String]) {
        self.members = members.sorted()
    }
}

/// Engine Equivalence 판정 결과
enum EngineEquivalenceStatus: String, Codable {
    /// Grid와 FaceScan 결과 완전 일치
    case pass
    /// maxGroupCount 내 일치, 상한 초과 미검증
    case partial
    /// 알고리즘 또는 입력 처리 차이
    case fail
}

/// Stage 1: Engine Equivalence 비교 리포트
struct EngineEquivalenceReport: Codable {
    /// 리포트 생성 시각
    let timestamp: Date
    /// FaceScanMethod 설명
    let methodDescription: String
    /// PHFetchResult 전체 사진 수
    let fetchResultCount: Int
    /// 요청된 범위
    let requestedRange: String
    /// 보정된 범위 (nil이면 빈 결과)
    let clampedRange: String?
    /// Grid oracle이 분석한 사진 ID
    let gridAnalyzedAssetIDs: [String]
    /// FaceScan이 분석한 사진 ID
    let faceScanAnalyzedAssetIDs: [String]
    /// Grid oracle 그룹 (정규화)
    let gridGroups: [GroupSignature]
    /// FaceScan 그룹 (정규화)
    let faceScanGroups: [GroupSignature]
    /// Grid에만 있는 그룹
    let gridOnly: [GroupSignature]
    /// FaceScan에만 있는 그룹
    let faceScanOnly: [GroupSignature]
    /// 양쪽 모두에 있는 그룹
    let common: [GroupSignature]
    /// FaceScan 종료 사유
    let faceScanTerminationReason: String
    /// 판정 결과
    let status: EngineEquivalenceStatus
}

/// Stage 2: Live Grid ↔ FaceScan 비교 리포트
struct LiveEquivalenceReport: Codable {
    /// Live Grid snapshot 그룹
    let liveGridGroups: [GroupSignature]
    /// FaceScan 그룹
    let faceScanGroups: [GroupSignature]
    /// Grid에만 있는 그룹 (FaceScan이 놓친 것 → 문제)
    let gridOnly: [GroupSignature]
    /// FaceScan에만 있는 그룹 (Grid 미스크롤 영역 → 정상)
    let faceScanOnly: [GroupSignature]
    /// 양쪽 모두에 있는 그룹
    let common: [GroupSignature]
    /// 비교 시각
    let timestamp: Date
}

// MARK: - FaceScanGridEquivalenceTester

/// FaceScan ↔ Grid 동등성 검증 하네스
///
/// Stage 1: 격리 인스턴스에서 Grid formGroupsForRange()와 FaceScan analyzeChunk()를
/// 같은 범위에서 실행하여 알고리즘 결과를 비교합니다.
///
/// Stage 2: SimilarityCache.shared의 live snapshot과 FaceScan 결과를 비교합니다.
final class FaceScanGridEquivalenceTester {

    // MARK: - Stage 1: Engine Equivalence

    /// Grid oracle과 FaceScan을 같은 범위에서 실행하고 결과를 비교합니다.
    ///
    /// - Parameters:
    ///   - method: FaceScan 스캔 방식
    ///   - range: 분석할 인덱스 범위 (nil이면 전체 범위)
    /// - Returns: EngineEquivalenceReport (PASS/PARTIAL/FAIL)
    func runEngineEquivalence(
        method: FaceScanMethod,
        range: ClosedRange<Int>? = nil
    ) async throws -> EngineEquivalenceReport {
        Logger.similarPhoto.notice("[Engine Equivalence] 시작: method=\(method.description)")

        // Step 1. fetchResult 생성 (Grid와 동일한 ascending fetchResult 사용)
        let faceScanService = FaceScanService(cache: FaceScanCache())
        let fetchResult = PhotoLibraryService.shared.fetchAllPhotos()

        Logger.similarPhoto.notice("[Engine Equivalence] fetchResult: \(fetchResult.count)장")

        // Step 2. 범위 보정
        guard fetchResult.count > 0 else {
            Logger.similarPhoto.notice("[Engine Equivalence] fetchResult 비어있음 → 빈 리포트 반환")
            return makeEmptyReport(method: method, range: range)
        }

        let maxRange = 0...(fetchResult.count - 1)
        let clampedRange = range.map { $0.clamped(to: maxRange) } ?? maxRange
        guard clampedRange.lowerBound <= clampedRange.upperBound else {
            return makeEmptyReport(method: method, range: range)
        }

        Logger.similarPhoto.notice("[Engine Equivalence] 범위: \(clampedRange.lowerBound)...\(clampedRange.upperBound)")

        // Step 3. Grid oracle 실행 (격리 인스턴스)
        // 새 SimilarityCache → 새 SimilarityAnalysisQueue → formGroupsForRange() 직접 호출
        // self !== .shared 가드에 의해 analytics/notification 억제됨
        let gridCache = SimilarityCache()
        let gridQueue = SimilarityAnalysisQueue(cache: gridCache)
        let gridResult = await gridQueue.debugGroupsForRange(clampedRange, fetchResult: fetchResult)

        Logger.similarPhoto.notice("[Engine Equivalence] Grid oracle: \(gridResult.groups.count)개 그룹, \(gridResult.analyzedAssetIDs.count)장 분석")

        // Step 4. FaceScan 실행 (decomposed pipeline — production analyze와 동일 경로)
        // production FaceScan은 FP 생성 → formGroups → 그룹별 얼굴 감지 방식.
        // analyzeDebugRange가 이 경로를 그대로 실행하므로 production 코드를 직접 검증합니다.
        let fsScanCache = FaceScanCache()
        let fsScanService = FaceScanService(cache: fsScanCache)
        let fsResult = await fsScanService.analyzeDebugRange(
            fetchResult: fetchResult,
            range: clampedRange
        )

        Logger.similarPhoto.notice("[Engine Equivalence] FaceScan: \(fsResult.groups.count)개 그룹, \(fsResult.analyzedAssetIDs.count)장 분석, 종료:\(fsResult.terminationReason.rawValue)")

        // Step 5. 입력 동등성 사전 검증
        let gridInputIDs = Set(gridResult.analyzedAssetIDs)
        let fsInputIDs = Set(fsResult.analyzedAssetIDs)
        let inputDiff = gridInputIDs.symmetricDifference(fsInputIDs)
        if !inputDiff.isEmpty {
            Logger.similarPhoto.warning("[Engine Equivalence] ⚠️ 입력 불일치: \(inputDiff.count)장 차이 (Grid에만: \(gridInputIDs.subtracting(fsInputIDs).count), FaceScan에만: \(fsInputIDs.subtracting(gridInputIDs).count))")
        }

        // Step 6. 정규화 + diff
        let gridSigs = Set(gridResult.groups.map { GroupSignature(members: $0) })
        let fsSigs = Set(fsResult.groups.map { GroupSignature(members: $0.memberAssetIDs) })
        let common = gridSigs.intersection(fsSigs)
        let gridOnly = gridSigs.subtracting(fsSigs)
        let faceScanOnly = fsSigs.subtracting(gridSigs)

        // PASS/PARTIAL/FAIL 판정
        // PARTIAL: FaceScan이 maxGroupCount에 도달하여 일부 그룹만 검증된 경우
        let status: EngineEquivalenceStatus
        if gridOnly.isEmpty && faceScanOnly.isEmpty {
            status = .pass
        } else if fsResult.terminationReason == FaceScanService.FaceScanDebugTerminationReason.maxGroupCount
                    && !gridOnly.isEmpty && faceScanOnly.isEmpty {
            // FaceScan이 그룹 상한 도달로 조기 종료 → 미검증 그룹 존재는 정상
            status = .partial
        } else {
            status = .fail
        }

        // Step 7. 로그 출력
        let statusEmoji = status == .pass ? "✅" : (status == .partial ? "⚠️" : "❌")
        Logger.similarPhoto.notice("""
        [Engine Equivalence] \(statusEmoji) \(status.rawValue.uppercased())
          범위: \(clampedRange.lowerBound)...\(clampedRange.upperBound) (fetchResult: \(fetchResult.count)장)
          입력: Grid \(gridResult.analyzedAssetIDs.count)장, FaceScan \(fsResult.analyzedAssetIDs.count)장
          그룹: Grid \(gridSigs.count)개, FaceScan \(fsSigs.count)개
          일치: \(common.count)개, Grid에만: \(gridOnly.count)개, FaceScan에만: \(faceScanOnly.count)개
          FaceScan 종료: \(fsResult.terminationReason.rawValue)
        """)

        // 리포트 생성
        let report = EngineEquivalenceReport(
            timestamp: Date(),
            methodDescription: method.description,
            fetchResultCount: fetchResult.count,
            requestedRange: range.map { "\($0.lowerBound)...\($0.upperBound)" } ?? "전체",
            clampedRange: "\(clampedRange.lowerBound)...\(clampedRange.upperBound)",
            gridAnalyzedAssetIDs: gridResult.analyzedAssetIDs,
            faceScanAnalyzedAssetIDs: fsResult.analyzedAssetIDs,
            gridGroups: Array(gridSigs),
            faceScanGroups: Array(fsSigs),
            gridOnly: Array(gridOnly),
            faceScanOnly: Array(faceScanOnly),
            common: Array(common),
            faceScanTerminationReason: fsResult.terminationReason.rawValue,
            status: status
        )

        // JSON 저장
        saveReportToJSON(report)

        return report
    }

    // MARK: - Stage 2: Live Grid Verification

    /// Live Grid snapshot과 FaceScan 결과를 비교합니다.
    ///
    /// - Parameters:
    ///   - liveSnapshot: GridAnalysisSessionRecorder에서 캡처한 live snapshot
    ///   - faceScanGroups: FaceScan 결과 그룹 (GroupSignature 배열)
    /// - Returns: LiveEquivalenceReport
    func runLiveEquivalence(
        liveSnapshot: LiveGridFinalSnapshot,
        faceScanGroups: [GroupSignature]
    ) -> LiveEquivalenceReport {
        let liveGridSigs = Set(liveSnapshot.groups)
        let fsSigs = Set(faceScanGroups)
        let common = liveGridSigs.intersection(fsSigs)
        let gridOnly = liveGridSigs.subtracting(fsSigs)
        let faceScanOnly = fsSigs.subtracting(liveGridSigs)

        // gridOnly가 있으면 FaceScan이 Grid가 찾은 그룹을 놓친 것 → 문제
        // faceScanOnly는 Grid 미스크롤 영역의 그룹 → 정상
        let statusEmoji = gridOnly.isEmpty ? "✅" : "❌"
        Logger.similarPhoto.notice("""
        [Live Equivalence] \(statusEmoji) gridOnly=\(gridOnly.count)
          Live Grid: \(liveGridSigs.count)개, FaceScan: \(fsSigs.count)개
          일치: \(common.count)개, Grid에만: \(gridOnly.count)개, FaceScan에만: \(faceScanOnly.count)개
        """)

        let report = LiveEquivalenceReport(
            liveGridGroups: Array(liveGridSigs),
            faceScanGroups: Array(fsSigs),
            gridOnly: Array(gridOnly),
            faceScanOnly: Array(faceScanOnly),
            common: Array(common),
            timestamp: Date()
        )

        // JSON 저장
        saveLiveReportToJSON(report)

        return report
    }

    // MARK: - Private Helpers

    /// 빈 리포트 생성 (fetchResult 비어있거나 범위 무효)
    private func makeEmptyReport(method: FaceScanMethod, range: ClosedRange<Int>?) -> EngineEquivalenceReport {
        return EngineEquivalenceReport(
            timestamp: Date(),
            methodDescription: method.description,
            fetchResultCount: 0,
            requestedRange: range.map { "\($0.lowerBound)...\($0.upperBound)" } ?? "전체",
            clampedRange: nil,
            gridAnalyzedAssetIDs: [],
            faceScanAnalyzedAssetIDs: [],
            gridGroups: [],
            faceScanGroups: [],
            gridOnly: [],
            faceScanOnly: [],
            common: [],
            faceScanTerminationReason: FaceScanService.FaceScanDebugTerminationReason.naturalEnd.rawValue,
            status: .pass
        )
    }

    /// Engine Equivalence 리포트를 JSON으로 저장합니다.
    private func saveReportToJSON(_ report: EngineEquivalenceReport) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(report) else {
            Logger.similarPhoto.error("[Engine Equivalence] JSON 인코딩 실패")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())

        let timestampPath = "/tmp/facescan-engine-equivalence-\(timestamp).json"
        let latestPath = "/tmp/facescan-engine-equivalence-latest.json"

        do {
            try data.write(to: URL(fileURLWithPath: timestampPath))
            try data.write(to: URL(fileURLWithPath: latestPath))
            Logger.similarPhoto.notice("[Engine Equivalence] JSON 저장: \(timestampPath)")
        } catch {
            Logger.similarPhoto.error("[Engine Equivalence] JSON 저장 실패: \(error.localizedDescription)")
        }
    }

    /// Live Equivalence 리포트를 JSON으로 저장합니다.
    private func saveLiveReportToJSON(_ report: LiveEquivalenceReport) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(report) else {
            Logger.similarPhoto.error("[Live Equivalence] JSON 인코딩 실패")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())

        let timestampPath = "/tmp/facescan-live-equivalence-\(timestamp).json"
        let latestPath = "/tmp/facescan-live-equivalence-latest.json"

        do {
            try data.write(to: URL(fileURLWithPath: timestampPath))
            try data.write(to: URL(fileURLWithPath: latestPath))
            Logger.similarPhoto.notice("[Live Equivalence] JSON 저장: \(timestampPath)")
        } catch {
            Logger.similarPhoto.error("[Live Equivalence] JSON 저장 실패: \(error.localizedDescription)")
        }
    }
}

#endif
