//
//  CompareAnalysisTester.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-28.
//
//  통합 로직 테스터 (DEBUG 전용)
//
//  새 통합 로직:
//  - 경로1: 기존 로직 기반
//    - Strong 신호 → 동의 없이 저품질 확정
//    - Weak/Conditional 신호 → AestheticsScore < 0.2 동의 시 저품질
//  - 경로2: AestheticsScore 기반
//    - AestheticsScore < 0.0 AND isUtility == false → 저품질
//
//  배지 분류:
//  - ⚪ 회색 (both): 경로1 + 경로2 둘 다 해당
//  - 🔵 파랑 (path1Only): 경로1만 해당
//  - 🟡 노랑 (path2Only): 경로2만 해당
//

#if DEBUG
import Foundation
import Photos
import AppCore

// MARK: - CompareCategory

/// 비교 분석 카테고리
/// 어떤 경로에서 저품질로 판정되었는지 분류
enum CompareCategory: String, Codable {
    /// 경로1 + 경로2 둘 다 (⚪ 회색)
    case both
    /// 경로1만 해당 (🔵 파랑) - 기존 로직 기반
    case path1Only
    /// 경로2만 해당 (🟡 노랑) - AestheticsScore 기반
    case path2Only
}

// MARK: - CompareAnalysisResult

/// 비교 분석 테스트 결과
@available(iOS 18.0, *)
struct CompareAnalysisResult {
    /// 총 검색된 사진 수
    let totalScanned: Int
    /// 경로1 + 경로2 둘 다 (⚪)
    let bothCount: Int
    /// 경로1만 (🔵)
    let path1OnlyCount: Int
    /// 경로2만 (🟡)
    let path2OnlyCount: Int
    /// 총 휴지통 이동 수
    var totalTrashed: Int {
        bothCount + path1OnlyCount + path2OnlyCount
    }
}

// MARK: - CompareCategoryStore

/// 비교 카테고리 저장소 (DEBUG 전용)
/// UserDefaults에 assetID → category 매핑 저장
@available(iOS 18.0, *)
final class CompareCategoryStore {

    static let shared = CompareCategoryStore()

    private let storageKey = "CompareAnalysis.Categories"

    /// 카테고리 정보 (assetID → category)
    private(set) var categories: [String: CompareCategory] = [:]

    private init() {
        load()
    }

    /// 카테고리 설정
    func setCategory(_ category: CompareCategory, for assetID: String) {
        categories[assetID] = category
    }

    /// 카테고리 조회
    func category(for assetID: String) -> CompareCategory? {
        return categories[assetID]
    }

    /// 저장
    func save() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: storageKey)
            Log.print("[CompareCategoryStore] 저장: \(categories.count)개")
        }
    }

    /// 로드
    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: CompareCategory].self, from: data) {
            categories = decoded
            Log.print("[CompareCategoryStore] 로드: \(categories.count)개")
        }
    }

    /// 초기화
    func clear() {
        categories.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        Log.print("[CompareCategoryStore] 초기화됨")
    }
}

// MARK: - CompareAnalysisTester

/// 통합 로직 테스터
///
/// 경로1 (기존 로직 기반) + 경로2 (AestheticsScore 기반) 테스트
@available(iOS 18.0, *)
final class CompareAnalysisTester {

    // MARK: - Singleton

    static let shared = CompareAnalysisTester()

    // MARK: - Constants

    /// 경로1: 동의용 임계값 (Weak/Conditional 신호에만 적용)
    private let path1AgreeThreshold: Float = 0.2

    /// 경로2: 임계값 (AestheticsScore 기반)
    private let path2Threshold: Float = 0.0

    /// 최대 검색 수
    private let maxScanCount: Int = 2000

    // MARK: - Dependencies

    /// 기존 품질 분석기
    private let qualityAnalyzer = QualityAnalyzer.shared

    /// AestheticsScore 분석기
    private let aestheticsAnalyzer = AestheticsAnalyzer.shared

    /// 이미지 로더
    private let imageLoader = CleanupImageLoader.shared

    /// 휴지통 스토어
    private let trashStore: TrashStoreProtocol = TrashStore.shared

    /// 카테고리 스토어
    private let categoryStore = CompareCategoryStore.shared

    // MARK: - State

    /// 진행 중 여부
    private(set) var isRunning = false

    // MARK: - Test Execution

    /// 통합 로직 테스트 실행
    ///
    /// 경로1과 경로2를 각각 계산하고 결과를 비교하여 카테고리별로 분류합니다.
    ///
    /// - Parameter onProgress: 진행 콜백 (scanned, both, path1Only, path2Only)
    /// - Returns: 테스트 결과
    func runTest(
        onProgress: ((Int, Int, Int, Int) -> Void)? = nil
    ) async -> CompareAnalysisResult {
        guard !isRunning else {
            Log.print("[CompareAnalysis] 이미 실행 중")
            return CompareAnalysisResult(totalScanned: 0, bothCount: 0, path1OnlyCount: 0, path2OnlyCount: 0)
        }

        isRunning = true
        defer { isRunning = false }

        // 카테고리 스토어 초기화
        categoryStore.clear()

        Log.print("[CompareAnalysis] 테스트 시작")
        Log.print("[CompareAnalysis] - 경로1 동의 임계값: \(path1AgreeThreshold)")
        Log.print("[CompareAnalysis] - 경로2 임계값: \(path2Threshold)")
        Log.print("[CompareAnalysis] - 최대 검색 수: \(maxScanCount)")

        var totalScanned = 0
        var bothCount = 0
        var path1OnlyCount = 0
        var path2OnlyCount = 0
        var trashedAssetIDs: [String] = []

        // 사진 가져오기
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        let assetCount = min(fetchResult.count, maxScanCount)

        Log.print("[CompareAnalysis] 총 \(fetchResult.count)장 중 \(assetCount)장 검색 예정")

        // 배치 처리 (20장씩)
        let batchSize = 20
        var currentIndex = 0

        while currentIndex < assetCount {
            let endIndex = min(currentIndex + batchSize, assetCount)
            var batchAssets: [PHAsset] = []

            for i in currentIndex..<endIndex {
                batchAssets.append(fetchResult.object(at: i))
            }

            // 배치 처리
            for asset in batchAssets {
                totalScanned += 1

                // 1. 기존 로직 실행
                let oldResult = await qualityAnalyzer.analyze(asset)

                // 2. AestheticsScore 분석
                var aestheticsMetrics: AestheticsMetrics?
                if let image = try? await imageLoader.loadImage(for: asset) {
                    aestheticsMetrics = try? await aestheticsAnalyzer.analyze(image)
                }

                // 3. 경로1 판정 (기존 로직 기반)
                let path1Result = evaluatePath1(
                    oldResult: oldResult,
                    aestheticsMetrics: aestheticsMetrics
                )

                // 4. 경로2 판정 (AestheticsScore 기반)
                let path2Result = evaluatePath2(aestheticsMetrics: aestheticsMetrics)

                // 5. 분류
                let category: CompareCategory?
                if path1Result && path2Result {
                    category = .both
                    bothCount += 1
                } else if path1Result {
                    category = .path1Only
                    path1OnlyCount += 1
                } else if path2Result {
                    category = .path2Only
                    path2OnlyCount += 1
                } else {
                    category = nil  // 둘 다 정상 → 휴지통 안 감
                }

                // 6. 휴지통 이동 + 카테고리 저장
                if let cat = category {
                    let assetID = asset.localIdentifier
                    trashedAssetIDs.append(assetID)
                    categoryStore.setCategory(cat, for: assetID)

                    let scoreStr = aestheticsMetrics.map { String(format: "%.3f", $0.overallScore) } ?? "N/A"
                    Log.print("[CompareAnalysis] \(cat.rawValue): score=\(scoreStr), \(assetID.prefix(8))...")
                }

                // 진행 콜백
                onProgress?(totalScanned, bothCount, path1OnlyCount, path2OnlyCount)
            }

            currentIndex = endIndex
            await Task.yield()
        }

        // 카테고리 저장
        categoryStore.save()

        // 휴지통 이동
        if !trashedAssetIDs.isEmpty {
            Log.print("[CompareAnalysis] \(trashedAssetIDs.count)장 휴지통 이동")
            trashStore.moveToTrash(assetIDs: trashedAssetIDs)
        }

        let result = CompareAnalysisResult(
            totalScanned: totalScanned,
            bothCount: bothCount,
            path1OnlyCount: path1OnlyCount,
            path2OnlyCount: path2OnlyCount
        )

        Log.print("[CompareAnalysis] 완료:")
        Log.print("[CompareAnalysis] - 검색: \(totalScanned)장")
        Log.print("[CompareAnalysis] - ⚪ 둘다(both): \(bothCount)장")
        Log.print("[CompareAnalysis] - 🔵 경로1(path1): \(path1OnlyCount)장")
        Log.print("[CompareAnalysis] - 🟡 경로2(path2): \(path2OnlyCount)장")

        return result
    }

    // MARK: - Path Evaluation

    /// 경로1 판정: 기존 로직 기반
    ///
    /// - Strong 신호 → 동의 없이 저품질 확정
    /// - Weak/Conditional 신호 → AestheticsScore < 0.2 동의 시 저품질
    private func evaluatePath1(
        oldResult: QualityResult,
        aestheticsMetrics: AestheticsMetrics?
    ) -> Bool {
        // 기존 로직이 정상이면 경로1 해당 안 함
        guard oldResult.verdict.isLowQuality else {
            return false
        }

        // Strong 신호 확인 (동의 없이 통과)
        if oldResult.signals.hasStrongSignal {
            Log.print("[CompareAnalysis] 경로1: Strong 신호로 확정")
            return true
        }

        // Weak/Conditional 신호는 AestheticsScore 동의 필요
        guard let metrics = aestheticsMetrics else {
            // AestheticsScore 없으면 기존 판정 유지
            return true
        }

        if metrics.overallScore < path1AgreeThreshold {
            // AestheticsScore 동의 → 저품질
            Log.print("[CompareAnalysis] 경로1: AestheticsScore 동의 (score=\(String(format: "%.3f", metrics.overallScore)))")
            return true
        } else {
            // AestheticsScore 동의 안 함 → 제외
            Log.print("[CompareAnalysis] 경로1: AestheticsScore 동의 안 함 (score=\(String(format: "%.3f", metrics.overallScore))) → 제외")
            return false
        }
    }

    /// 경로2 판정: AestheticsScore 기반
    ///
    /// - AestheticsScore < 0.0 AND isUtility == false → 저품질
    private func evaluatePath2(aestheticsMetrics: AestheticsMetrics?) -> Bool {
        guard let metrics = aestheticsMetrics else {
            return false
        }

        // 유틸리티 이미지(스크린샷 등)는 제외
        if metrics.isUtility {
            return false
        }

        // AestheticsScore < 0.0 → 저품질
        if metrics.overallScore < path2Threshold {
            Log.print("[CompareAnalysis] 경로2: AestheticsScore 기반 감지 (score=\(String(format: "%.3f", metrics.overallScore)))")
            return true
        }

        return false
    }
}
#endif
