//
//  CompareAnalysisTester.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-28.
//
//  기존 로직 vs AestheticsScore 비교 분석 테스터 (DEBUG 전용)
//
//  목적:
//  - 기존 로직(Laplacian, 노출 등)과 AestheticsScore를 동시에 실행
//  - 각 로직이 잡아낸 저품질 사진을 분류하여 비교
//  - "기존 로직이 놓친 저품질을 AestheticsScore가 잡아내는가?" 검증
//
//  분류:
//  - 🟣 both: 둘 다 저품질 판정
//  - 🔵 onlyOld: 기존 로직만 저품질 판정
//  - 🟡 onlyNew: AestheticsScore만 저품질 판정 ← 핵심 (기존이 놓친 것)
//

#if DEBUG
import Foundation
import Photos
import AppCore

// MARK: - CompareCategory

/// 비교 분석 카테고리
/// 어떤 로직에서 저품질로 판정되었는지 분류
enum CompareCategory: String, Codable {
    /// 둘 다 저품질 (🟣 보라)
    case both
    /// 기존 로직만 저품질 (🔵 파랑)
    case onlyOld
    /// AestheticsScore만 저품질 (🟡 노랑) - 핵심: 기존이 놓친 것
    case onlyNew
}

// MARK: - CompareAnalysisResult

/// 비교 분석 테스트 결과
@available(iOS 18.0, *)
struct CompareAnalysisResult {
    /// 총 검색된 사진 수
    let totalScanned: Int
    /// 둘 다 저품질 (🟣)
    let bothCount: Int
    /// 기존만 저품질 (🔵)
    let onlyOldCount: Int
    /// AestheticsScore만 저품질 (🟡)
    let onlyNewCount: Int
    /// 총 휴지통 이동 수
    var totalTrashed: Int {
        bothCount + onlyOldCount + onlyNewCount
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

/// 기존 로직 vs AestheticsScore 비교 분석 테스터
@available(iOS 18.0, *)
final class CompareAnalysisTester {

    // MARK: - Singleton

    static let shared = CompareAnalysisTester()

    // MARK: - Constants

    /// AestheticsScore 저품질 임계값
    private let aestheticsThreshold: Float = 0.2

    /// 최대 검색 수
    private let maxScanCount: Int = 4000

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

    /// 비교 분석 테스트 실행
    ///
    /// 각 사진에 대해 기존 로직과 AestheticsScore를 모두 실행하고
    /// 결과를 비교하여 카테고리별로 분류합니다.
    ///
    /// - Parameter onProgress: 진행 콜백 (scanned, both, onlyOld, onlyNew)
    /// - Returns: 테스트 결과
    func runTest(
        onProgress: ((Int, Int, Int, Int) -> Void)? = nil
    ) async -> CompareAnalysisResult {
        guard !isRunning else {
            Log.print("[CompareAnalysis] 이미 실행 중")
            return CompareAnalysisResult(totalScanned: 0, bothCount: 0, onlyOldCount: 0, onlyNewCount: 0)
        }

        isRunning = true
        defer { isRunning = false }

        // 카테고리 스토어 초기화
        categoryStore.clear()

        Log.print("[CompareAnalysis] 테스트 시작 - maxScan=\(maxScanCount), aestheticsThreshold=\(aestheticsThreshold)")

        var totalScanned = 0
        var bothCount = 0
        var onlyOldCount = 0
        var onlyNewCount = 0
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
                let isOldLowQuality = oldResult.verdict.isLowQuality

                // 2. AestheticsScore 실행
                var isNewLowQuality = false
                if let image = try? await imageLoader.loadImage(for: asset),
                   let metrics = try? await aestheticsAnalyzer.analyze(image) {
                    // isUtility는 스킵 (스크린샷 등)
                    if !metrics.isUtility && metrics.overallScore < aestheticsThreshold {
                        isNewLowQuality = true
                    }
                }

                // 3. 분류
                let category: CompareCategory?
                if isOldLowQuality && isNewLowQuality {
                    category = .both
                    bothCount += 1
                } else if isOldLowQuality {
                    category = .onlyOld
                    onlyOldCount += 1
                } else if isNewLowQuality {
                    category = .onlyNew
                    onlyNewCount += 1
                } else {
                    category = nil  // 둘 다 정상 → 휴지통 안 감
                }

                // 4. 휴지통 이동 + 카테고리 저장
                if let cat = category {
                    let assetID = asset.localIdentifier
                    trashedAssetIDs.append(assetID)
                    categoryStore.setCategory(cat, for: assetID)

                    Log.print("[CompareAnalysis] \(cat.rawValue): \(assetID.prefix(8))...")
                }

                // 진행 콜백
                onProgress?(totalScanned, bothCount, onlyOldCount, onlyNewCount)
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
            onlyOldCount: onlyOldCount,
            onlyNewCount: onlyNewCount
        )

        Log.print("[CompareAnalysis] 완료: 검색=\(totalScanned), 둘다=\(bothCount), 기존만=\(onlyOldCount), 신규만=\(onlyNewCount)")

        return result
    }
}
#endif
