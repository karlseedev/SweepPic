//
//  CleanupService.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-23.
//
//  정리 서비스 구현
//  - 저품질 사진 탐색 및 삭제대기함 이동
//  - 비동기 스캔 및 취소 지원
//  - 배치 처리 (100장 단위)
//  - 동시성 제어 (4개)
//  - T093: 배치별 성능 측정 (DEBUG)
//  - T094: autoreleasepool 적용 (배치 추출)
//

import Foundation
import Photos
import AppCore

// MARK: - CleanupService

/// 정리 서비스 구현체
///
/// 저품질 사진 자동 정리 기능을 제공합니다.
/// - 최신 사진부터 순차적으로 스캔
/// - 배치 처리로 성능 최적화
/// - 취소 시 아무것도 이동하지 않음
final class CleanupService: CleanupServiceProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = CleanupService()

    // MARK: - Dependencies

    /// 세션 저장소
    private let sessionStore: CleanupSessionStoreProtocol

    /// 품질 분석기
    private let qualityAnalyzer: QualityAnalyzer

    /// 삭제대기함 저장소
    private let trashStore: TrashStoreProtocol

    // MARK: - State

    /// 현재 진행 중인 세션
    private(set) var currentSession: CleanupSession?

    /// 이전 세션 (이어서 정리용)
    var lastSession: CleanupSession? {
        sessionStore.currentSession
    }

    /// 정리 진행 중 여부
    var isRunning: Bool {
        currentSession?.status == .scanning
    }

    /// 취소 플래그 (Thread-safe)
    private var isCancelled: Bool = false

    /// 일시정지 플래그 (Thread-safe)
    private var isPaused: Bool = false

    /// 동시성 제어를 위한 락
    private let lock = NSLock()

    /// 발견된 저품질 사진 ID 임시 저장 (취소 시 사용하지 않음)
    private var foundAssetIDs: [String] = []

    /// 시작 시간 (소요 시간 계산용)
    private var startTime: Date?

    /// 현재 세션 ID
    private var sessionID: UUID = UUID()

    // MARK: - Initialization

    /// 서비스 초기화
    /// - Parameters:
    ///   - sessionStore: 세션 저장소
    ///   - qualityAnalyzer: 품질 분석기
    ///   - trashStore: 삭제대기함 저장소
    init(
        sessionStore: CleanupSessionStoreProtocol = CleanupSessionStore.shared,
        qualityAnalyzer: QualityAnalyzer = .shared,
        trashStore: TrashStoreProtocol = TrashStore.shared
    ) {
        self.sessionStore = sessionStore
        self.qualityAnalyzer = qualityAnalyzer
        self.trashStore = trashStore
    }

    // MARK: - 삭제대기함 상태 확인

    /// 삭제대기함이 비어있는지 확인
    func isTrashEmpty() -> Bool {
        return trashStore.trashedCount == 0
    }

    // MARK: - 정리 실행

    /// 정리 시작
    ///
    /// - Important: 취소 시 아무것도 삭제대기함으로 이동하지 않음
    func startCleanup(
        method: CleanupMethod,
        mode: JudgmentMode,
        progressHandler: @escaping (CleanupProgress) -> Void
    ) async throws -> CleanupResult {

        // 1. 전제조건 검증
        try validatePreConditions()

        // 2. 세션 초기화
        sessionID = UUID()
        let session = createSession(method: method, mode: mode)
        currentSession = session
        foundAssetIDs = []
        startTime = Date()

        // 취소/일시정지 플래그 초기화
        lock.withLock {
            isCancelled = false
            isPaused = false
        }

        // 분석기 모드 설정
        qualityAnalyzer.setMode(mode)

        // 3. 스캔 시작
        do {
            let result = try await performScan(
                session: session,
                method: method,
                progressHandler: progressHandler
            )
            return result
        } catch {
            // 에러 발생 시 세션 정리
            currentSession = nil
            // [Analytics] 정리 시작 실패
            AnalyticsService.shared.countError(.startFail as AnalyticsError.Cleanup)
            throw error
        }
    }

    /// 정리 취소
    func cancelCleanup() {
        lock.withLock {
            isCancelled = true
        }

        // 임시 데이터 정리 (취소 시 삭제대기함으로 이동하지 않음)
        foundAssetIDs = []

        // 세션 상태 업데이트
        if var session = currentSession {
            session.status = .cancelled
            currentSession = session
        }

    }

    /// 정리 일시정지
    func pauseCleanup() {
        lock.withLock {
            isPaused = true
        }

        if var session = currentSession {
            session.status = .paused
            currentSession = session
        }

    }

    /// 정리 재개
    func resumeCleanup() {
        lock.withLock {
            isPaused = false
        }

        if var session = currentSession {
            session.status = .scanning
            currentSession = session
        }

    }

    // MARK: - Private Methods

    /// 전제조건 검증
    private func validatePreConditions() throws {
        // 이미 실행 중인지 확인
        if isRunning {
            throw CleanupError.alreadyRunning
        }

        // 삭제대기함 비어있는지 확인
        if !isTrashEmpty() {
            throw CleanupError.trashNotEmpty
        }

        // 사진 라이브러리 권한 확인
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw CleanupError.noPhotoAccess
        }
    }

    /// 세션 생성
    private func createSession(method: CleanupMethod, mode: JudgmentMode) -> CleanupSession {
        var session = CleanupSession(method: method, mode: mode, startDate: Date())
        session.status = .scanning
        return session
    }

    /// 스캔 수행
    private func performScan(
        session: CleanupSession,
        method: CleanupMethod,
        progressHandler: @escaping (CleanupProgress) -> Void
    ) async throws -> CleanupResult {

        // PHFetchResult 가져오기
        let fetchResult = createFetchResult(for: method)
        let totalCount = fetchResult.count

        #if DEBUG
        CleanupDebug.logScanStart(method: method, mode: session.mode, totalCount: totalCount)
        #endif

        guard totalCount > 0 else {
            // 사진이 없는 경우
            let result = CleanupResult.noneFound(
                sessionID: sessionID,
                scannedCount: 0,
                totalTimeSeconds: calculateElapsedTime(),
                endReason: .endOfRange
            )
            await cleanupSession(result: result)
            return result
        }

        var scannedCount = 0
        var currentDate = Date()

        // 50장 제한 도달 시 마지막 저품질 사진의 날짜 (이어서 정리용)
        // nil이면 배치 마지막 asset의 날짜 사용
        var lastLowQualityDate: Date?

        // 배치 단위로 처리
        let batchSize = CleanupConstants.batchSize
        var batchStartIndex = 0
        let maxFoundCount = CleanupConstants.maxFoundCount

        while batchStartIndex < totalCount {
            // 이미 50장을 찾았으면 더 이상 배치 분석하지 않음
            if foundAssetIDs.count >= maxFoundCount {
                break
            }

            // 취소 체크
            if shouldCancel() {
                let result = CleanupResult.cancelled(
                    sessionID: sessionID,
                    scannedCount: scannedCount,
                    foundCount: foundAssetIDs.count,
                    totalTimeSeconds: calculateElapsedTime()
                )
                await cleanupSession(result: result)
                return result
            }

            // 일시정지 대기
            while isPausedSafe() {
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1초 대기
                if shouldCancel() { break }
            }

            // 배치 추출 (T094: autoreleasepool으로 PHAsset 열거 시 메모리 관리)
            let batchEndIndex = min(batchStartIndex + batchSize, totalCount)
            let batchAssets: [PHAsset] = autoreleasepool {
                var assets: [PHAsset] = []
                assets.reserveCapacity(batchEndIndex - batchStartIndex)
                fetchResult.enumerateObjects(
                    at: IndexSet(integersIn: batchStartIndex..<batchEndIndex),
                    options: []
                ) { asset, _, _ in
                    assets.append(asset)
                }
                return assets
            }

            // 배치 분석 (T093: 성능 측정)
            let batchStartTime = CFAbsoluteTimeGetCurrent()

            let results = await qualityAnalyzer.analyzeBatch(
                batchAssets,
                maxConcurrent: CleanupConstants.concurrentAnalysis
            )

            #if DEBUG
            let batchElapsed = CFAbsoluteTimeGetCurrent() - batchStartTime
            CleanupDebug.logBatchStats(results, batchIndex: batchStartIndex / batchSize, elapsed: batchElapsed)
            #endif

            // 저품질 사진 수집 및 SKIP 통계
            // - 결과는 원본 순서 보장됨 (analyzeBatch에서 정렬)
            // - 50장 제한 체크하여 초과분은 추가하지 않음
            var batchFoundCount = 0
            var skipStats: [String: Int] = [:]  // SKIP 이유별 카운트
            var analyzedCount = 0

            for result in results {
                if result.verdict.isLowQuality {
                    // 50장 제한 체크
                    if foundAssetIDs.count < maxFoundCount {
                        foundAssetIDs.append(result.assetID)
                        batchFoundCount += 1

                        // 50번째 도달 시 해당 사진의 날짜 기록 (이어서 정리용)
                        // 이 날짜 이전부터 다음 정리가 시작되어야 버려진 사진도 다시 탐색됨
                        if foundAssetIDs.count == maxFoundCount {
                            lastLowQualityDate = result.creationDate
                        }
                    }
                    // 50장 이후는 추가하지 않음 (다음 이어서 정리에서 다시 탐색)
                }

                // SKIP 통계 수집
                if case .skipped(let reason) = result.verdict {
                    skipStats[reason.rawValue, default: 0] += 1
                } else {
                    analyzedCount += 1
                }
            }

            scannedCount += batchAssets.count

            // 현재 탐색 시점 업데이트
            // - 50장 도달 전: 배치 마지막 asset의 날짜
            // - 50장 도달 후: lastLowQualityDate 사용 (이어서 정리 시 버려진 사진도 다시 탐색)
            if lastLowQualityDate == nil {
                if let lastAsset = batchAssets.last, let creationDate = lastAsset.creationDate {
                    currentDate = creationDate
                }
            } else {
                // 50장 도달 시 마지막 저품질 사진의 날짜 사용
                currentDate = lastLowQualityDate ?? currentDate
            }

            // 진행 상황 콜백 (메인 스레드)
            let scanRatio = Float(scannedCount) / Float(CleanupConstants.maxScanCount)
            let foundRatio = Float(foundAssetIDs.count) / Float(CleanupConstants.maxFoundCount)
            let progress = CleanupProgress(
                scannedCount: scannedCount,
                foundCount: foundAssetIDs.count,
                currentDate: currentDate,
                progress: min(max(scanRatio, foundRatio), 1.0),
                maxFoundCount: CleanupConstants.maxFoundCount,
                maxScanCount: CleanupConstants.maxScanCount
            )
            await MainActor.run {
                progressHandler(progress)
            }

            // 종료 조건 체크
            if let endReason = checkEndCondition(
                scannedCount: scannedCount,
                foundCount: foundAssetIDs.count,
                totalCount: totalCount,
                currentIndex: batchEndIndex
            ) {
                // 정상 종료: 삭제대기함으로 이동
                moveToTrash(assetIDs: foundAssetIDs)

                let result: CleanupResult
                if foundAssetIDs.isEmpty {
                    result = CleanupResult.noneFound(
                        sessionID: sessionID,
                        scannedCount: scannedCount,
                        totalTimeSeconds: calculateElapsedTime(),
                        endReason: endReason
                    )
                } else {
                    result = CleanupResult.completed(
                        sessionID: sessionID,
                        scannedCount: scannedCount,
                        foundCount: foundAssetIDs.count,
                        trashedAssetIDs: foundAssetIDs,
                        totalTimeSeconds: calculateElapsedTime(),
                        endReason: endReason
                    )
                }

                await cleanupSession(result: result, lastScannedDate: currentDate)
                return result
            }

            batchStartIndex = batchEndIndex
        }

        // 범위 끝까지 스캔 완료
        moveToTrash(assetIDs: foundAssetIDs)

        let result: CleanupResult
        if foundAssetIDs.isEmpty {
            result = CleanupResult.noneFound(
                sessionID: sessionID,
                scannedCount: scannedCount,
                totalTimeSeconds: calculateElapsedTime(),
                endReason: .endOfRange
            )
        } else {
            result = CleanupResult.completed(
                sessionID: sessionID,
                scannedCount: scannedCount,
                foundCount: foundAssetIDs.count,
                trashedAssetIDs: foundAssetIDs,
                totalTimeSeconds: calculateElapsedTime(),
                endReason: .endOfRange
            )
        }

        await cleanupSession(result: result, lastScannedDate: currentDate)
        return result
    }

    /// PHFetchResult 생성
    private func createFetchResult(for method: CleanupMethod) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()

        // 생성일 기준 최신 → 오래된 순 정렬
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // 이미지 + 비디오
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        switch method {
        case .fromLatest:
            // 전체 사진 (최신부터)
            return PHAsset.fetchAssets(with: options)

        case .continueFromLast:
            // 이전 세션의 마지막 탐색 날짜부터
            if let lastSession = sessionStore.currentSession,
               let lastDate = lastSession.lastAssetDate {
                options.predicate = NSPredicate(
                    format: "(mediaType == %d OR mediaType == %d) AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    PHAssetMediaType.video.rawValue,
                    lastDate as NSDate
                )
            }
            return PHAsset.fetchAssets(with: options)

        case .byYear(let year, let continueFrom):
            // 특정 연도만
            let startOfYear = Calendar.current.date(from: DateComponents(year: year))!
            let endOfYear = Calendar.current.date(from: DateComponents(year: year + 1))!

            if let fromDate = continueFrom {
                // 이어서: 해당 연도 + fromDate 이전
                options.predicate = NSPredicate(
                    format: "(mediaType == %d OR mediaType == %d) AND creationDate >= %@ AND creationDate < %@ AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    PHAssetMediaType.video.rawValue,
                    startOfYear as NSDate,
                    endOfYear as NSDate,
                    fromDate as NSDate
                )
            } else {
                // 새로 시작: 해당 연도 전체
                options.predicate = NSPredicate(
                    format: "(mediaType == %d OR mediaType == %d) AND creationDate >= %@ AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    PHAssetMediaType.video.rawValue,
                    startOfYear as NSDate,
                    endOfYear as NSDate
                )
            }
            return PHAsset.fetchAssets(with: options)
        }
    }

    /// 종료 조건 체크
    private func checkEndCondition(
        scannedCount: Int,
        foundCount: Int,
        totalCount: Int,
        currentIndex: Int
    ) -> EndReason? {

        // 50장 발견
        if foundCount >= CleanupConstants.maxFoundCount {
            return .maxFound
        }

        // 2000장 검색
        if scannedCount >= CleanupConstants.maxScanCount {
            return .maxScanned
        }

        // 범위 끝
        if currentIndex >= totalCount {
            return .endOfRange
        }

        return nil
    }

    /// 삭제대기함으로 이동
    ///
    /// TrashStore 연동 방식 (T074 문서화):
    /// - 사용 API: `TrashStore.moveToTrash(assetIDs:)` (동기, 배열 기반)
    /// - 저장 위치: Documents/TrashState.json (파일 기반, 앱 재시작 후 유지)
    /// - 실패 처리: 부분 실패 시 건너뛰기 (롤백 없음, CHK040 결정사항)
    /// - 복구 방법: `TrashStore.restore(assetIDs:)` 호출로 복구 가능
    ///   - 삭제대기함 UI에서 개별 또는 일괄 복구
    ///   - 복구 시 trashedAssetIDs에서 제거, GridViewController 자동 갱신
    /// - 최종 삭제: `TrashStore.permanentlyDelete(assetIDs:)` 또는 `emptyTrash()`
    ///   - 시스템 PHPhotoLibrary.performChanges 팝업 표시 후 삭제
    private func moveToTrash(assetIDs: [String]) {
        guard !assetIDs.isEmpty else { return }

        trashStore.moveToTrash(assetIDs: assetIDs)
    }

    /// 세션 정리
    private func cleanupSession(result: CleanupResult, lastScannedDate: Date? = nil) async {
        #if DEBUG
        CleanupDebug.logScanEnd(
            scannedCount: result.scannedCount,
            foundCount: result.foundCount,
            elapsed: result.totalTimeSeconds,
            endReason: result.endReason
        )
        #endif
        // 취소가 아닌 경우에만 세션 저장 (이어서 정리용)
        // - maxFound, maxScanned: 이어서 정리 가능
        // - endOfRange: 이어서 정리 불가 (범위 끝 도달)
        // - userCancelled: 저장하지 않음
        if result.endReason != .userCancelled,
           let lastDate = lastScannedDate {
            var session = currentSession ?? CleanupSession(method: .fromLatest, mode: .precision)
            session.status = .completed
            session.lastAssetDate = lastDate
            session.scannedCount = result.scannedCount
            session.foundCount = result.foundCount
            session.endReason = result.endReason  // 종료 사유 저장
            sessionStore.save(session)
        }

        // 현재 세션 정리
        currentSession = nil
        foundAssetIDs = []
        startTime = nil
    }

    /// 경과 시간 계산
    private func calculateElapsedTime() -> Double {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// 취소 여부 확인 (Thread-safe)
    private func shouldCancel() -> Bool {
        lock.withLock { isCancelled }
    }

    /// 일시정지 여부 확인 (Thread-safe)
    private func isPausedSafe() -> Bool {
        lock.withLock { isPaused }
    }
}

// MARK: - NSLock Extension

private extension NSLock {
    /// 락을 획득하고 클로저를 실행한 뒤 락을 해제
    func withLock<T>(_ closure: () -> T) -> T {
        lock()
        defer { unlock() }
        return closure()
    }
}
