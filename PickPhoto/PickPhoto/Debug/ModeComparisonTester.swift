//
//  ModeComparisonTester.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-30.
//
//  3모드 비교 테스터 (DEBUG 전용)
//
//  3모드 (완화/기본/강화)를 동시에 평가하여 딱지로 구별하는 테스트.
//  모든 모드는 OR 로직이며, 경로2의 AestheticsScore 임계값만 다름:
//
//  - 완화 (Light):    경로1 OR 경로2(< -0.3)  ← 경로2 엄격
//  - 기본 (Standard): 경로1 OR 경로2(< 0.0)
//  - 강화 (Deep):     경로1 OR 경로2(< 0.2)   ← 경로2 완화
//
//  계층: light ⊂ standard ⊂ deep
//
//  배지 분류:
//  - ⚪ 회색 (allModes):   3모드 전부 잡음 (light == true)
//  - 🔵 파랑 (standardUp): 기본+강화만 잡음 (light == false, standard == true)
//  - 🟡 노랑 (deepOnly):   강화만 잡음 (standard == false, deep == true)
//

#if DEBUG
import Foundation
import Photos
import Vision
import AppCore

// MARK: - ModeCategory

/// 3모드 비교 카테고리
/// 어느 모드에서 저품질로 판정되었는지 분류
enum ModeCategory: String, Codable {
    /// 3모드 전부 잡음 (⚪ 회색)
    case allModes
    /// 기본+강화만 잡음 (🔵 파랑)
    case standardUp
    /// 강화만 잡음 (🟡 노랑)
    case deepOnly
}

// MARK: - ModeComparisonResult

/// 3모드 비교 테스트 결과
@available(iOS 18.0, *)
struct ModeComparisonResult {
    /// 총 검색된 사진 수
    let totalScanned: Int
    /// 3모드 전부 (⚪)
    let allModesCount: Int
    /// 기본+강화 (🔵)
    let standardUpCount: Int
    /// 강화만 (🟡)
    let deepOnlyCount: Int
    /// 휴지통 이동된 assetID 목록
    let trashedAssetIDs: [String]
    /// 총 휴지통 이동 수
    var totalTrashed: Int {
        allModesCount + standardUpCount + deepOnlyCount
    }
}

// MARK: - ModeCategoryStore

/// 3모드 카테고리 저장소 (DEBUG 전용)
/// UserDefaults에 assetID → category 매핑 저장
@available(iOS 18.0, *)
final class ModeCategoryStore {

    static let shared = ModeCategoryStore()

    private let storageKey = "ModeComparison.Categories"

    /// 카테고리 정보 (assetID → category)
    private(set) var categories: [String: ModeCategory] = [:]

    private init() {
        load()
    }

    /// 카테고리 설정
    func setCategory(_ category: ModeCategory, for assetID: String) {
        categories[assetID] = category
    }

    /// 카테고리 조회
    func category(for assetID: String) -> ModeCategory? {
        return categories[assetID]
    }

    /// 저장
    func save() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: storageKey)
            Log.print("[ModeComparison] 카테고리 저장: \(categories.count)개")
        }
    }

    /// 로드
    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: ModeCategory].self, from: data) {
            categories = decoded
            Log.print("[ModeComparison] 카테고리 로드: \(categories.count)개")
        }
    }

    /// 초기화
    func clear() {
        categories.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        Log.print("[ModeComparison] 카테고리 초기화됨")
    }
}

// MARK: - ModeComparisonTester

/// 3모드 비교 테스터
///
/// 완화/기본/강화 모드를 동시에 평가하여 딱지로 구별합니다.
/// 모든 모드는 경로1 OR 경로2이며, 경로2의 AestheticsScore 임계값만 다릅니다.
@available(iOS 18.0, *)
final class ModeComparisonTester {

    // MARK: - Singleton

    static let shared = ModeComparisonTester()

    // MARK: - Constants

    /// 경로1: 동의용 임계값 (Weak/Conditional 신호에만 적용)
    private let path1AgreeThreshold: Float = 0.2

    /// 경로2 임계값 - 완화 (엄격)
    private let path2LightThreshold: Float = -0.3

    /// 경로2 임계값 - 기본
    private let path2StandardThreshold: Float = 0.0

    /// 경로2 임계값 - 강화 (완화)
    private let path2DeepThreshold: Float = 0.2

    /// 최대 검색 수
    private let maxScanCount: Int = 3000

    /// 극단적 비율 임계값 (세로/가로 또는 가로/세로 > 이 값이면 제외)
    /// 블로그 저장 이미지 등 세로로 매우 긴 이미지 제외용
    private let extremeAspectRatioThreshold: CGFloat = 5.0

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
    private let categoryStore = ModeCategoryStore.shared

    // MARK: - Session Storage Keys

    private let lastTestDateKey = "ModeComparison.LastTestDate"
    private let totalScannedKey = "ModeComparison.TotalScanned"
    private let totalTrashedKey = "ModeComparison.TotalTrashed"

    // MARK: - State

    /// 진행 중 여부
    private(set) var isRunning = false

    /// 마지막 테스트 날짜
    var lastTestDate: Date? {
        return UserDefaults.standard.object(forKey: lastTestDateKey) as? Date
    }

    /// 이어서 테스트 가능 여부
    var canContinue: Bool {
        return lastTestDate != nil
    }

    /// 누적 검색 수
    var totalScannedCount: Int {
        return UserDefaults.standard.integer(forKey: totalScannedKey)
    }

    /// 누적 휴지통 수
    var totalTrashedCount: Int {
        return UserDefaults.standard.integer(forKey: totalTrashedKey)
    }

    // MARK: - Session Management

    /// 세션 저장
    private func saveSession(lastDate: Date, scanned: Int, trashed: Int) {
        UserDefaults.standard.set(lastDate, forKey: lastTestDateKey)
        UserDefaults.standard.set(totalScannedCount + scanned, forKey: totalScannedKey)
        UserDefaults.standard.set(totalTrashedCount + trashed, forKey: totalTrashedKey)
        Log.print("[ModeComparison] 세션 저장: \(formatDate(lastDate)) 이전까지, 누적 검색 \(totalScannedCount + scanned)장")
    }

    /// 세션 초기화
    func clearSession() {
        UserDefaults.standard.removeObject(forKey: lastTestDateKey)
        UserDefaults.standard.removeObject(forKey: totalScannedKey)
        UserDefaults.standard.removeObject(forKey: totalTrashedKey)
        categoryStore.clear()
        Log.print("[ModeComparison] 세션 초기화됨")
    }

    /// 날짜 포맷
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }

    // MARK: - Test Execution

    /// 3모드 비교 테스트 실행
    ///
    /// 완화/기본/강화 모드를 동시에 평가하여 카테고리별로 분류합니다.
    ///
    /// - Parameters:
    ///   - continueFromLast: true면 이어서 테스트 (마지막 날짜 이전부터)
    ///   - onProgress: 진행 콜백 (scanned, allModes, standardUp, deepOnly)
    /// - Returns: 테스트 결과
    func runTest(
        continueFromLast: Bool = false,
        onProgress: ((Int, Int, Int, Int) -> Void)? = nil
    ) async -> ModeComparisonResult {
        guard !isRunning else {
            Log.print("[ModeComparison] 이미 실행 중")
            return ModeComparisonResult(
                totalScanned: 0, allModesCount: 0,
                standardUpCount: 0, deepOnlyCount: 0,
                trashedAssetIDs: []
            )
        }

        isRunning = true
        defer { isRunning = false }

        // 처음부터 시작이면 세션 초기화
        if !continueFromLast {
            clearSession()
        }

        let continueDate = continueFromLast ? lastTestDate : nil

        if let date = continueDate {
            Log.print("[ModeComparison] 이어서 테스트 시작 (\(formatDate(date)) 이전부터)")
        } else {
            Log.print("[ModeComparison] 테스트 시작 (처음부터)")
        }
        Log.print("[ModeComparison] - 경로1 동의 임계값: \(path1AgreeThreshold)")
        Log.print("[ModeComparison] - 경로2 완화: \(path2LightThreshold), 기본: \(path2StandardThreshold), 강화: \(path2DeepThreshold)")
        Log.print("[ModeComparison] - 최대 검색 수: \(maxScanCount)")

        var totalScanned = 0
        var allModesCount = 0
        var standardUpCount = 0
        var deepOnlyCount = 0
        var trashedAssetIDs: [String] = []
        var lastAssetDate: Date?

        // 사진 가져오기
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // 이어서 테스트: 마지막 날짜 이전 사진만
        if let continueDate = continueDate {
            fetchOptions.predicate = NSPredicate(
                format: "mediaType == %d AND creationDate < %@",
                PHAssetMediaType.image.rawValue,
                continueDate as NSDate
            )
        } else {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        let assetCount = min(fetchResult.count, maxScanCount)

        Log.print("[ModeComparison] 총 \(fetchResult.count)장 중 \(assetCount)장 검색 예정")

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

                // 마지막 asset 날짜 기록 (이어서 테스트용)
                if let date = asset.creationDate {
                    lastAssetDate = date
                }

                // 0. 극단적 비율 체크 (블로그 저장 이미지 등 제외)
                let aspectRatio = CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
                let isExtremeRatio = aspectRatio > extremeAspectRatioThreshold || aspectRatio < (1.0 / extremeAspectRatioThreshold)
                if isExtremeRatio {
                    Log.print("[ModeComparison] 극단적 비율 제외: \(asset.pixelWidth)×\(asset.pixelHeight) (ratio=\(String(format: "%.1f", aspectRatio)))")
                    onProgress?(totalScanned, allModesCount, standardUpCount, deepOnlyCount)
                    continue
                }

                // 1. 기존 로직 실행
                let oldResult = await qualityAnalyzer.analyze(asset)

                // 2. AestheticsScore 분석
                var aestheticsMetrics: AestheticsMetrics?
                var loadedImage: CGImage?
                if let image = try? await imageLoader.loadImage(for: asset) {
                    loadedImage = image
                    aestheticsMetrics = try? await aestheticsAnalyzer.analyze(image)
                }

                // 3. 경로1 판정 (모든 모드 공통)
                let path1Result = evaluatePath1(
                    oldResult: oldResult,
                    aestheticsMetrics: aestheticsMetrics
                )

                // 4. 텍스트 스크린샷 감지 (1회만, 결과 재사용)
                let isTextScreenshot: Bool
                if let image = loadedImage {
                    isTextScreenshot = await detectTextScreenshot(image)
                } else {
                    isTextScreenshot = false
                }

                // 5. 경로2 판정 (임계값만 다르게 3회, 동기 함수)
                let path2Light = evaluatePath2(
                    metrics: aestheticsMetrics,
                    isTextScreenshot: isTextScreenshot,
                    threshold: path2LightThreshold
                )
                let path2Std = evaluatePath2(
                    metrics: aestheticsMetrics,
                    isTextScreenshot: isTextScreenshot,
                    threshold: path2StandardThreshold
                )
                let path2Deep = evaluatePath2(
                    metrics: aestheticsMetrics,
                    isTextScreenshot: isTextScreenshot,
                    threshold: path2DeepThreshold
                )

                // 6. 3모드 계산 (모두 OR, 경로2 임계값만 다름)
                let light    = path1Result || path2Light
                let standard = path1Result || path2Std
                let deep     = path1Result || path2Deep

                // 7. 카테고리 분류
                let category: ModeCategory?
                if light {
                    category = .allModes      // ⚪ 3모드 전부
                    allModesCount += 1
                } else if standard {
                    category = .standardUp    // 🔵 기본+강화
                    standardUpCount += 1
                } else if deep {
                    category = .deepOnly      // 🟡 강화만
                    deepOnlyCount += 1
                } else {
                    category = nil            // 3모드 모두 정상 → 휴지통 안 감
                }

                // 8. 휴지통 이동 + 카테고리 저장
                if let cat = category {
                    let assetID = asset.localIdentifier
                    trashedAssetIDs.append(assetID)
                    categoryStore.setCategory(cat, for: assetID)

                    let scoreStr = aestheticsMetrics.map { String(format: "%.3f", $0.overallScore) } ?? "N/A"
                    Log.print("[ModeComparison] \(cat.rawValue): score=\(scoreStr), \(assetID.prefix(8))...")
                }

                // 진행 콜백
                onProgress?(totalScanned, allModesCount, standardUpCount, deepOnlyCount)
            }

            currentIndex = endIndex
            await Task.yield()
        }

        // 카테고리 저장
        categoryStore.save()

        // 세션 저장 (마지막 날짜 기록)
        if let lastDate = lastAssetDate {
            saveSession(lastDate: lastDate, scanned: totalScanned, trashed: trashedAssetIDs.count)
        }

        // 휴지통 이동
        if !trashedAssetIDs.isEmpty {
            Log.print("[ModeComparison] \(trashedAssetIDs.count)장 휴지통 이동")
            trashStore.moveToTrash(assetIDs: trashedAssetIDs)
        }

        let result = ModeComparisonResult(
            totalScanned: totalScanned,
            allModesCount: allModesCount,
            standardUpCount: standardUpCount,
            deepOnlyCount: deepOnlyCount,
            trashedAssetIDs: trashedAssetIDs
        )

        Log.print("[ModeComparison] 완료:")
        Log.print("[ModeComparison] - 검색: \(totalScanned)장")
        Log.print("[ModeComparison] - ⚪ 전체(allModes): \(allModesCount)장")
        Log.print("[ModeComparison] - 🔵 기본↑(standardUp): \(standardUpCount)장")
        Log.print("[ModeComparison] - 🟡 강화만(deepOnly): \(deepOnlyCount)장")

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
            Log.print("[ModeComparison] 경로1: Strong 신호로 확정")
            return true
        }

        // Weak/Conditional 신호는 AestheticsScore 동의 필요
        guard let metrics = aestheticsMetrics else {
            // AestheticsScore 없으면 기존 판정 유지
            return true
        }

        if metrics.overallScore < path1AgreeThreshold {
            // AestheticsScore 동의 → 저품질
            Log.print("[ModeComparison] 경로1: AestheticsScore 동의 (score=\(String(format: "%.3f", metrics.overallScore)))")
            return true
        } else {
            // AestheticsScore 동의 안 함 → 제외
            Log.print("[ModeComparison] 경로1: AestheticsScore 동의 안 함 (score=\(String(format: "%.3f", metrics.overallScore))) → 제외")
            return false
        }
    }

    /// 경로2 판정: AestheticsScore 기반 (동기 함수)
    ///
    /// threshold만 다르게 호출하여 3모드 차이를 구현합니다.
    /// detectTextScreenshot은 외부에서 1회만 호출하고 결과를 전달받습니다.
    ///
    /// - Parameters:
    ///   - metrics: AestheticsScore 분석 결과
    ///   - isTextScreenshot: 텍스트 스크린샷 여부 (외부에서 계산)
    ///   - threshold: AestheticsScore 임계값
    /// - Returns: 저품질 여부
    private func evaluatePath2(
        metrics: AestheticsMetrics?,
        isTextScreenshot: Bool,
        threshold: Float
    ) -> Bool {
        guard let metrics = metrics else {
            return false
        }

        // 유틸리티 이미지(스크린샷 등)는 제외
        if metrics.isUtility {
            return false
        }

        // AestheticsScore 임계값 체크
        guard metrics.overallScore < threshold else {
            return false
        }

        // 텍스트 스크린샷은 제외
        if isTextScreenshot {
            return false
        }

        return true
    }

    /// 텍스트 스크린샷 감지 (Vision 프레임워크)
    ///
    /// - Parameter image: 분석할 이미지
    /// - Returns: 텍스트 블록 >= 5개이면 true (스크린샷)
    private func detectTextScreenshot(_ image: CGImage) async -> Bool {
        return await withCheckedContinuation { continuation in
            // continuation 중복 resume 방지
            var hasResumed = false

            let request = VNRecognizeTextRequest { request, error in
                Log.print("[TextDetect] completion 진입, hasResumed=\(hasResumed), error=\(error != nil)")
                guard !hasResumed else {
                    Log.print("[TextDetect] ⚠️ 중복 resume 방지됨 (completion)")
                    return
                }
                hasResumed = true

                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    Log.print("[TextDetect] completion에서 resume (에러/nil)")
                    continuation.resume(returning: false)
                    return
                }

                let textBlockCount = observations.count
                let isTextScreenshot = textBlockCount >= CleanupConstants.textBlockCountThreshold

                if isTextScreenshot {
                    Log.print("[ModeComparison] 텍스트 감지: \(textBlockCount)개 블록 → 스크린샷")
                }

                Log.print("[TextDetect] completion에서 resume (성공)")
                continuation.resume(returning: isTextScreenshot)
            }

            request.recognitionLevel = .fast
            request.recognitionLanguages = ["ko-KR", "en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                Log.print("[TextDetect] perform 시작")
                try handler.perform([request])
                Log.print("[TextDetect] perform 종료 (정상)")
            } catch {
                Log.print("[TextDetect] perform 종료 (throw), hasResumed=\(hasResumed)")
                guard !hasResumed else {
                    Log.print("[TextDetect] ⚠️ 중복 resume 방지됨 (catch)")
                    return
                }
                hasResumed = true
                Log.print("[TextDetect] catch에서 resume")
                continuation.resume(returning: false)
            }
        }
    }
}
#endif
