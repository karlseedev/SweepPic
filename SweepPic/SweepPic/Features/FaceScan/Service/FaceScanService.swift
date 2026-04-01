//
//  FaceScanService.swift
//  SweepPic
//
//  인물사진 비교정리 — 스캔 엔진
//
//  핵심 전략: 기존 SimilarityAnalysisQueue를 호출하지 않고, 개별 분석기를 직접 사용.
//  기존 코드(SimilarityAnalysisQueue, SimilarityCache) 수정 없음.
//  분석 도구(SimilarityAnalyzer, YuNetFaceDetector, SFaceRecognizer, FaceAligner)만 재사용.
//
//  책임:
//  - PHFetchResult 구성 (method별 predicate, 최신순 정렬)
//  - 삭제대기함 사진 제외
//  - 청크 단위 분석 루프 (chunkSize: 20, overlap: 3)
//  - 그룹 발견 시 즉시 콜백
//  - 종료 조건: 1,000장 OR 30그룹
//  - 취소 지원
//  - 열 상태(thermal) 모니터링
//

import Foundation
import Photos
import Vision
import AppCore
import OSLog

// MARK: - FaceScanService

/// 인물사진 비교정리 스캔 엔진
///
/// 개별 분석기(SimilarityAnalyzer, YuNet, SFace, FaceAligner)를 직접 사용하여
/// 기존 SimilarityAnalysisQueue/Cache와 완전 격리된 분석 파이프라인을 실행합니다.
final class FaceScanService {

    // MARK: - 분석 도구 (Pipeline extension에서 접근하므로 internal)

    /// Feature Print 분석기
    let analyzer = SimilarityAnalyzer()

    /// 얼굴 감지기 (싱글톤 공유 — stateless에 가까움)
    var faceDetector: YuNetFaceDetector? { YuNetFaceDetector.shared }

    /// 얼굴 인식기 (싱글톤 공유 — stateless에 가까움)
    var faceRecognizer: SFaceRecognizer? { SFaceRecognizer.shared }

    /// 얼굴 정렬기 (싱글톤 공유 — stateless)
    let faceAligner = FaceAligner.shared

    /// 이미지 로더 (싱글톤 공유 — 참조 카운팅으로 안전)
    let imageLoader = SimilarityImageLoader.shared

    // MARK: - 결과 저장

    /// 전용 캐시 (외부에서 주입)
    let cache: FaceScanCache

    // MARK: - 취소 (Pipeline extension에서 접근하므로 internal)

    /// 취소 플래그 (thread-safe)
    var isCancelled = false
    let cancelLock = NSLock()

    // MARK: - 세션 저장 키 (UserDefaults)

    private static let lastScanDateKey = "FaceScanSession.lastScanDate"
    private static let lastAssetIDKey = "FaceScanSession.lastAssetID"
    private static let byYearLastScanDateKey = "FaceScanSession.byYear.lastScanDate"
    private static let byYearLastAssetIDKey = "FaceScanSession.byYear.lastAssetID"
    private static let byYearYearKey = "FaceScanSession.byYear.year"
    private static let byYearCanContinueKey = "FaceScanSession.byYear.canContinue"

    // MARK: - Static Session Accessors

    /// 이어서 정리 가능 여부 (fromLatest / continueFromLast 용)
    static var canContinue: Bool {
        return lastScanDate != nil
    }

    /// 마지막 스캔 날짜
    static var lastScanDate: Date? {
        return UserDefaults.standard.object(forKey: lastScanDateKey) as? Date
    }

    /// 연도별 이어서 정리 날짜
    static func lastScanDateByYear(_ year: Int) -> Date? {
        guard let savedYear = UserDefaults.standard.object(forKey: byYearYearKey) as? Int,
              savedYear == year,
              UserDefaults.standard.bool(forKey: byYearCanContinueKey) else {
            return nil
        }
        return UserDefaults.standard.object(forKey: byYearLastScanDateKey) as? Date
    }

    // MARK: - Init

    init(cache: FaceScanCache) {
        self.cache = cache
    }

    // MARK: - Cancel

    /// 분석 취소
    func cancel() {
        cancelLock.lock()
        isCancelled = true
        cancelLock.unlock()
    }

    /// 취소 여부 확인 (thread-safe, Pipeline extension에서도 접근)
    var cancelled: Bool {
        cancelLock.lock()
        defer { cancelLock.unlock() }
        return isCancelled
    }

    // MARK: - Analyze (메인 진입점)

    /// 인물사진 비교정리 분석 실행
    ///
    /// 청크 단위로 사진을 분석하여 유사 인물 그룹을 발견하고 콜백으로 전달합니다.
    /// 종료 조건: 1,000장 검색 OR 30그룹 발견 (먼저 도달 시)
    ///
    /// - Parameters:
    ///   - method: 스캔 방식 (fromLatest, continueFromLast, byYear)
    ///   - onGroupFound: 그룹 발견 시 콜백 (메인 스레드)
    ///   - onProgress: 진행 상황 콜백 (메인 스레드)
    /// - Throws: CancellationError (취소 시)
    func analyze(
        method: FaceScanMethod,
        onGroupFound: @escaping (FaceScanGroup) -> Void,
        onProgress: @escaping (FaceScanProgress) -> Void
    ) async throws {
        // 1. PHFetchResult 구성
        let fetchResult = buildFetchResult(method: method)
        let trashedIDs = TrashStore.shared.trashedAssetIDs

        // 2. 이어서 정리: 시작 인덱스 결정
        let startIndex = findStartIndex(method: method, fetchResult: fetchResult)

        // 3. 청크 단위 분석 루프
        var currentIndex = startIndex
        var totalScanned = 0
        var totalGroupsFound = 0
        var lastAssetDate: Date?
        var lastAssetID: String?

        let totalToScan = min(fetchResult.count - startIndex, FaceScanConstants.maxScanCount)

        while currentIndex < fetchResult.count {
            // 취소 체크
            if cancelled { throw CancellationError() }

            // 종료 조건 체크
            if totalScanned >= FaceScanConstants.maxScanCount { break }
            if totalGroupsFound >= FaceScanConstants.maxGroupCount { break }

            // 청크 범위 계산 (overlap 포함)
            let chunkStart = max(0, currentIndex - FaceScanConstants.chunkOverlap)
            let chunkEnd = min(fetchResult.count - 1, currentIndex + FaceScanConstants.chunkSize - 1)

            // 청크 내 사진 추출 (삭제대기함 제외)
            var photos: [PHAsset] = []
            for i in chunkStart...chunkEnd {
                let asset = fetchResult.object(at: i)
                if !trashedIDs.contains(asset.localIdentifier) {
                    photos.append(asset)
                }
            }

            // 최소 3장 미만이면 다음 청크로
            guard photos.count >= SimilarityConstants.minGroupSize else {
                currentIndex = chunkEnd + 1
                totalScanned += (chunkEnd - currentIndex + 1)
                continue
            }

            // 청크 분석 실행
            let groups = await analyzeChunk(photos: photos)

            // 그룹 발견 처리
            for group in groups {
                totalGroupsFound += 1

                // FaceScanCache에 저장 + 콜백
                await MainActor.run {
                    onGroupFound(group)
                }

                // 종료 조건 재체크
                if totalGroupsFound >= FaceScanConstants.maxGroupCount { break }
            }

            // 진행 상황 업데이트
            let newScanned = chunkEnd - currentIndex + 1
            totalScanned += newScanned
            currentIndex = chunkEnd + 1

            // 마지막 사진 정보 기록 (세션 저장용)
            if let lastPhoto = photos.last {
                lastAssetDate = lastPhoto.creationDate
                lastAssetID = lastPhoto.localIdentifier
            }

            // 진행률 콜백 (메인 스레드)
            let progress = FaceScanProgress.updated(
                scannedCount: totalScanned,
                groupCount: totalGroupsFound,
                currentDate: lastAssetDate ?? Date()
            )
            await MainActor.run {
                onProgress(progress)
            }

            // 열 상태 확인 — 과열 시 잠시 대기
            if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
                try await Task.sleep(nanoseconds: 500_000_000)  // 0.5초 대기
            }
        }

        // 4. 세션 저장 (분석 완료 시에만)
        if let date = lastAssetDate, let assetID = lastAssetID {
            saveSession(method: method, lastDate: date, lastAssetID: assetID)
        }
    }

    // MARK: - PHFetchResult 구성

    /// method에 따라 PHFetchResult를 구성합니다.
    private func buildFetchResult(method: FaceScanMethod) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        // 최신순 정렬
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        switch method {
        case .fromLatest:
            // 전체 이미지 (최신순)
            options.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.image.rawValue
            )

        case .continueFromLast:
            // 마지막 스캔 날짜 이전 (최신순)
            if let lastDate = Self.lastScanDate {
                options.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    lastDate as NSDate
                )
            } else {
                options.predicate = NSPredicate(
                    format: "mediaType == %d",
                    PHAssetMediaType.image.rawValue
                )
            }

        case .byYear(let year, let continueFrom):
            let calendar = Calendar.current
            let startOfYear = calendar.date(from: DateComponents(year: year))!
            let endOfYear = calendar.date(from: DateComponents(year: year + 1))!

            if let fromDate = continueFrom {
                options.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@ AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    startOfYear as NSDate,
                    endOfYear as NSDate,
                    fromDate as NSDate
                )
            } else {
                options.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    startOfYear as NSDate,
                    endOfYear as NSDate
                )
            }
        }

        return PHAsset.fetchAssets(with: options)
    }

    /// 이어서 정리: lastAssetID를 찾아서 시작 인덱스 결정
    private func findStartIndex(method: FaceScanMethod, fetchResult: PHFetchResult<PHAsset>) -> Int {
        switch method {
        case .continueFromLast:
            // lastAssetID 이후부터 시작
            guard let lastID = UserDefaults.standard.string(forKey: Self.lastAssetIDKey) else {
                return 0
            }
            // fetchResult에서 lastAssetID의 위치를 찾음
            for i in 0..<fetchResult.count {
                if fetchResult.object(at: i).localIdentifier == lastID {
                    return i + 1  // 다음 사진부터
                }
            }
            return 0  // 못 찾으면 처음부터

        case .byYear(_, let continueFrom):
            if continueFrom != nil {
                guard let lastID = UserDefaults.standard.string(forKey: Self.byYearLastAssetIDKey) else {
                    return 0
                }
                for i in 0..<fetchResult.count {
                    if fetchResult.object(at: i).localIdentifier == lastID {
                        return i + 1
                    }
                }
            }
            return 0

        default:
            return 0
        }
    }

    // MARK: - 세션 저장

    /// 분석 완료 시 세션 저장
    private func saveSession(method: FaceScanMethod, lastDate: Date, lastAssetID: String) {
        switch method {
        case .fromLatest, .continueFromLast:
            UserDefaults.standard.set(lastDate, forKey: Self.lastScanDateKey)
            UserDefaults.standard.set(lastAssetID, forKey: Self.lastAssetIDKey)

        case .byYear(let year, _):
            UserDefaults.standard.set(lastDate, forKey: Self.byYearLastScanDateKey)
            UserDefaults.standard.set(lastAssetID, forKey: Self.byYearLastAssetIDKey)
            UserDefaults.standard.set(year, forKey: Self.byYearYearKey)
            UserDefaults.standard.set(true, forKey: Self.byYearCanContinueKey)
        }

        Logger.similarPhoto.debug("FaceScanService: 세션 저장 — \(method.description)")
    }
}
