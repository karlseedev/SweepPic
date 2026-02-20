//
//  AestheticsOnlyTester.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-28.
//
//  AestheticsScore 단독 판정 테스터 (DEBUG 전용)
//
//  목적:
//  - 기존 로직(Laplacian, 노출 등)을 무시하고
//  - AestheticsScore만으로 저품질 사진 판정 테스트
//
//  사용법:
//  - 정리 버튼 → "[DEBUG] AestheticsScore 단독" 선택
//  - 4000장 검색 후 저품질 사진 삭제대기함 이동
//
//  임계값:
//  - AestheticsScore < 0.2 → 저품질
//  - 정상 사진 최소: 0.230 (테스트 데이터 기준)
//  - 저품질 사진 최소: 0.177 (테스트 데이터 기준)
//

#if DEBUG
import Foundation
import Photos
import AppCore

// MARK: - AestheticsOnlyResult

/// AestheticsScore 단독 판정 테스트 결과
@available(iOS 18.0, *)
struct AestheticsOnlyResult {
    /// 총 검색된 사진 수
    let totalScanned: Int
    /// 저품질로 판정된 사진 수
    let lowQualityCount: Int
    /// 저품질 사진 ID 목록
    let lowQualityAssetIDs: [String]
}

// MARK: - AestheticsOnlyTester

/// AestheticsScore 단독 판정 테스터
///
/// 기존 로직(Laplacian, 노출 등)을 무시하고
/// AestheticsScore만으로 저품질 판정
@available(iOS 18.0, *)
final class AestheticsOnlyTester {

    // MARK: - Singleton

    static let shared = AestheticsOnlyTester()

    // MARK: - Constants

    /// 저품질 임계값 (score < threshold → 저품질)
    /// 테스트 데이터 기준:
    /// - 정상 사진 최소: 0.230
    /// - 저품질 사진 최소: 0.177
    private let lowQualityThreshold: Float = 0.2

    /// 최대 검색 수
    private let maxScanCount: Int = 4000

    // MARK: - Dependencies

    /// AestheticsScore 분석기
    private let aestheticsAnalyzer = AestheticsAnalyzer.shared

    /// 이미지 로더
    private let imageLoader = CleanupImageLoader.shared

    /// 삭제대기함 스토어
    private let trashStore: TrashStoreProtocol = TrashStore.shared

    // MARK: - State

    /// 진행 중 여부
    private(set) var isRunning = false

    /// 마지막 검색 날짜 (이어서 테스트용)
    private(set) var lastAssetDate: Date?

    // MARK: - Session (UserDefaults)

    /// 마지막 검색 날짜 저장 키
    private let lastAssetDateKey = "AestheticsOnly.lastAssetDate"

    // MARK: - Initialization

    init() {
        // UserDefaults에서 마지막 검색 날짜 복원
        lastAssetDate = UserDefaults.standard.object(forKey: lastAssetDateKey) as? Date
    }

    // MARK: - Session Management

    /// 세션 초기화 (처음부터 다시 시작)
    func clearSession() {
        lastAssetDate = nil
        UserDefaults.standard.removeObject(forKey: lastAssetDateKey)
        Log.print("[AestheticsOnly] 세션 초기화됨")
    }

    /// 세션 저장
    private func saveSession() {
        if let date = lastAssetDate {
            UserDefaults.standard.set(date, forKey: lastAssetDateKey)
            Log.print("[AestheticsOnly] 세션 저장: \(date)")
        }
    }

    /// 이어서 테스트 가능 여부
    var canContinue: Bool {
        return lastAssetDate != nil
    }

    // MARK: - Test Execution

    /// 테스트 실행
    ///
    /// AestheticsScore만으로 저품질 사진을 판정하고 삭제대기함으로 이동합니다.
    ///
    /// - Parameters:
    ///   - continueFrom: 이어서 테스트할 날짜 (nil이면 최신부터)
    ///   - onProgress: 진행 콜백 (scanned, lowQuality)
    /// - Returns: 테스트 결과
    func runTest(
        continueFrom: Date? = nil,
        onProgress: ((Int, Int) -> Void)? = nil
    ) async -> AestheticsOnlyResult {
        // 이미 실행 중이면 빈 결과 반환
        guard !isRunning else {
            Log.print("[AestheticsOnly] 이미 실행 중")
            return AestheticsOnlyResult(totalScanned: 0, lowQualityCount: 0, lowQualityAssetIDs: [])
        }

        isRunning = true
        defer { isRunning = false }

        // 시작 날짜 결정
        let startDate = continueFrom ?? lastAssetDate
        if startDate == nil {
            // 처음부터 시작하는 경우 세션 초기화
            clearSession()
        }

        Log.print("[AestheticsOnly] 테스트 시작 - threshold=\(lowQualityThreshold), maxScan=\(maxScanCount)")
        if let date = startDate {
            Log.print("[AestheticsOnly] 이어서 시작: \(date)")
        }

        var totalScanned = 0
        var lowQualityAssetIDs: [String] = []

        // 사진 가져오기 옵션 설정
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // 시작 날짜가 있으면 해당 날짜 이전 사진만 가져오기
        if let fromDate = startDate {
            fetchOptions.predicate = NSPredicate(
                format: "mediaType == %d AND creationDate < %@",
                PHAssetMediaType.image.rawValue,
                fromDate as NSDate
            )
        } else {
            fetchOptions.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.image.rawValue
            )
        }

        // 사진 가져오기
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        let assetCount = min(fetchResult.count, maxScanCount)

        Log.print("[AestheticsOnly] 총 \(fetchResult.count)장 중 \(assetCount)장 검색 예정")

        // 배치 처리 (20장씩)
        let batchSize = 20
        var currentIndex = 0

        while currentIndex < assetCount {
            let endIndex = min(currentIndex + batchSize, assetCount)
            var batchAssets: [PHAsset] = []

            // 배치 에셋 수집
            for i in currentIndex..<endIndex {
                batchAssets.append(fetchResult.object(at: i))
            }

            // 배치 처리
            for asset in batchAssets {
                totalScanned += 1

                // AestheticsScore 분석
                guard let image = try? await imageLoader.loadImage(for: asset),
                      let metrics = try? await aestheticsAnalyzer.analyze(image) else {
                    // 이미지 로드 또는 분석 실패 시 스킵
                    continue
                }

                // isUtility는 스킵 (스크린샷, 문서 등)
                if metrics.isUtility {
                    continue
                }

                // AestheticsScore < threshold → 저품질
                if metrics.overallScore < lowQualityThreshold {
                    lowQualityAssetIDs.append(asset.localIdentifier)
                    Log.print("[AestheticsOnly] 저품질 발견: score=\(String(format: "%.3f", metrics.overallScore))")
                }

                // 진행 콜백
                onProgress?(totalScanned, lowQualityAssetIDs.count)
            }

            // 마지막 사진 날짜 저장 (이어서 테스트용)
            if let lastAsset = batchAssets.last {
                lastAssetDate = lastAsset.creationDate
            }

            currentIndex = endIndex

            // 다른 작업에 양보
            await Task.yield()
        }

        // 세션 저장
        saveSession()

        // 저품질 사진 삭제대기함 이동
        if !lowQualityAssetIDs.isEmpty {
            Log.print("[AestheticsOnly] \(lowQualityAssetIDs.count)장 삭제대기함 이동")
            trashStore.moveToTrash(assetIDs: lowQualityAssetIDs)
        }

        // 결과 생성
        let result = AestheticsOnlyResult(
            totalScanned: totalScanned,
            lowQualityCount: lowQualityAssetIDs.count,
            lowQualityAssetIDs: lowQualityAssetIDs
        )

        Log.print("[AestheticsOnly] 테스트 완료: \(totalScanned)장 검색, \(lowQualityAssetIDs.count)장 저품질")

        return result
    }
}
#endif
