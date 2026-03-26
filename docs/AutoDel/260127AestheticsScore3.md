# AestheticsScore 단독 판정 테스트

## 배경

### 기존 로직의 한계
- Laplacian 블러 감지가 정상/저품질 구분을 잘 못함
- 정상 사진 Laplacian: 12.3 ~ 128.3
- 저품질 사진 Laplacian: 26.5 ~ 49.7
- 겹치는 구간이 너무 넓음

### 가설
AestheticsScore 단독으로 저품질 판정하면 더 나을 수 있음

### 테스트 데이터 (260128debugLog1.md 기준)
| 유형 | 개수 | AestheticsScore 범위 |
|------|------|----------------------|
| 정상 | 20장 | 0.230 ~ 0.723 |
| 저품질 | 8장 | 0.177 ~ 0.381 |

---

## 테스트 방식

### 판정 로직
```
AestheticsScore < X → 저품질
AestheticsScore >= X → 정상
```

### 임계값 후보
| 임계값 | 저품질 잡음 | 정상 놓침 |
|--------|------------|----------|
| 0.18 | 1/8장 | 0/20장 |
| 0.20 | 2/8장 | 0/20장 |
| 0.23 | 3/8장 | 1/20장 |

### 테스트 임계값: 0.2
- 정상 사진 최소: 0.230
- 저품질 사진 최소: 0.177
- 안전 마진 확보

---

## 구현 계획

### 파일 구조
```
SweepPic/Debug/
└── AestheticsOnlyTester.swift   # 신규 (DEBUG 전용)
```

### AestheticsOnlyTester.swift

```swift
#if DEBUG
import Foundation
import Photos
import AppCore

/// AestheticsScore 단독 판정 테스트 결과
@available(iOS 18.0, *)
struct AestheticsOnlyResult {
    let totalScanned: Int
    let lowQualityCount: Int
    let lowQualityAssetIDs: [String]
}

/// AestheticsScore 단독 판정 테스터
///
/// 기존 로직(Laplacian, 노출 등)을 무시하고
/// AestheticsScore만으로 저품질 판정
@available(iOS 18.0, *)
final class AestheticsOnlyTester {

    static let shared = AestheticsOnlyTester()

    /// 저품질 임계값 (score < threshold → 저품질)
    private let lowQualityThreshold: Float = 0.2

    /// 최대 검색 수
    private let maxScanCount: Int = 4000

    /// AestheticsScore 분석기
    private let aestheticsAnalyzer = AestheticsAnalyzer.shared

    /// 이미지 로더
    private let imageLoader = CleanupImageLoader.shared

    /// 휴지통 스토어
    private let trashStore: TrashStoreProtocol = TrashStore.shared

    /// 진행 중 여부
    private(set) var isRunning = false

    /// 마지막 검색 날짜 (이어서 테스트용)
    private(set) var lastAssetDate: Date?

    // MARK: - Session (UserDefaults)

    private let lastAssetDateKey = "AestheticsOnly.lastAssetDate"

    init() {
        lastAssetDate = UserDefaults.standard.object(forKey: lastAssetDateKey) as? Date
    }

    func clearSession() {
        lastAssetDate = nil
        UserDefaults.standard.removeObject(forKey: lastAssetDateKey)
    }

    private func saveSession() {
        if let date = lastAssetDate {
            UserDefaults.standard.set(date, forKey: lastAssetDateKey)
        }
    }

    var canContinue: Bool {
        return lastAssetDate != nil
    }

    // MARK: - Test

    /// 테스트 실행
    /// - Parameters:
    ///   - continueFrom: 이어서 테스트할 날짜 (nil이면 최신부터)
    ///   - onProgress: 진행 콜백 (scanned, lowQuality)
    /// - Returns: 테스트 결과
    func runTest(
        continueFrom: Date? = nil,
        onProgress: ((Int, Int) -> Void)? = nil
    ) async -> AestheticsOnlyResult {
        guard !isRunning else {
            return AestheticsOnlyResult(totalScanned: 0, lowQualityCount: 0, lowQualityAssetIDs: [])
        }

        isRunning = true
        defer { isRunning = false }

        let startDate = continueFrom ?? lastAssetDate
        if startDate == nil {
            clearSession()
        }

        var totalScanned = 0
        var lowQualityAssetIDs: [String] = []

        // 사진 가져오기
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        if let fromDate = startDate {
            fetchOptions.predicate = NSPredicate(
                format: "mediaType == %d AND creationDate < %@",
                PHAssetMediaType.image.rawValue,
                fromDate as NSDate
            )
        } else {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        let assetCount = min(fetchResult.count, maxScanCount)

        Log.print("[AestheticsOnly] 총 \(fetchResult.count)장 중 \(assetCount)장 검색 예정")

        // 배치 처리
        let batchSize = 20
        var currentIndex = 0

        while currentIndex < assetCount {
            let endIndex = min(currentIndex + batchSize, assetCount)
            var batchAssets: [PHAsset] = []

            for i in currentIndex..<endIndex {
                batchAssets.append(fetchResult.object(at: i))
            }

            for asset in batchAssets {
                totalScanned += 1

                // AestheticsScore 분석
                guard let image = try? await imageLoader.loadImage(for: asset),
                      let metrics = try? await aestheticsAnalyzer.analyze(image) else {
                    continue
                }

                // isUtility는 스킵 (스크린샷 등)
                if metrics.isUtility {
                    continue
                }

                // AestheticsScore < threshold → 저품질
                if metrics.overallScore < lowQualityThreshold {
                    lowQualityAssetIDs.append(asset.localIdentifier)
                    Log.print("[AestheticsOnly] 저품질: score=\(String(format: "%.3f", metrics.overallScore))")
                }

                onProgress?(totalScanned, lowQualityAssetIDs.count)
            }

            // 마지막 사진 날짜 저장
            if let lastAsset = batchAssets.last {
                lastAssetDate = lastAsset.creationDate
            }

            currentIndex = endIndex
            await Task.yield()
        }

        saveSession()

        // 저품질 사진 휴지통 이동
        if !lowQualityAssetIDs.isEmpty {
            Log.print("[AestheticsOnly] \(lowQualityAssetIDs.count)장 휴지통 이동")
            trashStore.moveToTrash(assetIDs: lowQualityAssetIDs)
        }

        let result = AestheticsOnlyResult(
            totalScanned: totalScanned,
            lowQualityCount: lowQualityAssetIDs.count,
            lowQualityAssetIDs: lowQualityAssetIDs
        )

        Log.print("[AestheticsOnly] 완료: \(totalScanned)장 검색, \(lowQualityAssetIDs.count)장 저품질")

        return result
    }
}
#endif
```

---

## UI 연동

### CleanupMethodSheet.swift 수정 (DEBUG)

```swift
#if DEBUG
// iOS 18+ AestheticsScore 단독 테스트 (DEBUG 전용)
if #available(iOS 18.0, *) {
    alert.addAction(UIAlertAction(
        title: "[DEBUG] AestheticsScore 단독",
        style: .default
    ) { [self] _ in
        self.delegate?.cleanupMethodSheet(self, didSelectAestheticsOnlyMode: .fromLatest)
    })
}
#endif
```

### CleanupMethodSheetDelegate 추가

```swift
/// AestheticsScore 단독 모드 선택됨 (DEBUG 전용)
func cleanupMethodSheet(_ sheet: CleanupMethodSheet, didSelectAestheticsOnlyMode method: CleanupMethod)
```

### GridViewController+Cleanup.swift 수정 (DEBUG)

```swift
#if DEBUG
@available(iOS 18.0, *)
func startAestheticsOnlyTest(with method: CleanupMethod) {
    let tester = AestheticsOnlyTester.shared

    let continueFrom: Date?
    switch method {
    case .continueFromLast:
        continueFrom = tester.lastAssetDate
    case .fromLatest:
        tester.clearSession()
        continueFrom = nil
    default:
        continueFrom = nil
    }

    // 진행 알림 표시
    let progressAlert = UIAlertController(
        title: "AestheticsScore 단독 테스트",
        message: "검색: 0장\n저품질: 0장",
        preferredStyle: .alert
    )
    present(progressAlert, animated: true)

    Task {
        let result = await tester.runTest(continueFrom: continueFrom) { scanned, lowQuality in
            Task { @MainActor in
                progressAlert.message = "검색: \(scanned)장\n저품질: \(lowQuality)장"
            }
        }

        await MainActor.run {
            progressAlert.dismiss(animated: true) { [weak self] in
                self?.showAestheticsOnlyResult(result)
            }
        }
    }
}

@available(iOS 18.0, *)
private func showAestheticsOnlyResult(_ result: AestheticsOnlyResult) {
    let message = "\(result.totalScanned)장 검색\n저품질: \(result.lowQualityCount)장"

    let alert = UIAlertController(
        title: "테스트 완료",
        message: message,
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "확인", style: .default))

    if result.lowQualityCount > 0 {
        alert.addAction(UIAlertAction(title: "휴지통 보기", style: .default) { [weak self] _ in
            self?.navigateToTrash()
        })
    }

    present(alert, animated: true)
}
#endif
```

---

## 테스트 순서

1. 앱 빌드 (DEBUG 모드)
2. 정리 버튼 → "[DEBUG] AestheticsScore 단독" 선택
3. 4000장 검색 후 저품질 사진 휴지통 이동
4. 휴지통에서 결과 확인
   - 정말 저품질인가?
   - 정상 사진이 잘못 잡혔는가?

---

## 예상 결과

임계값 0.2 기준:
- 저품질 8장 중 2장 잡음 (0.177, 0.179)
- 정상 20장 중 0장 놓침

기존 로직 대비:
- 더 적게 잡지만 더 정확할 수 있음
- 실제 테스트로 검증 필요
