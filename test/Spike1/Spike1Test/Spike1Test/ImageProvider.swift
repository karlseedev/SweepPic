import UIKit
import Photos

// MARK: - ImageProvider Protocol

/// Image result with degraded flag
struct ImageResult {
    let image: UIImage?
    let isDegraded: Bool  // true = low-quality preview, false = final image
}

/// Abstraction for image loading - allows Mock vs PhotoKit switching
protocol ImageProvider {
    var count: Int { get }

    func loadLibrary(completion: @escaping (Int, Double) -> Void)  // (count, fetchTimeMs)
    func identifier(at index: Int) -> String
    func requestImage(
        at index: Int,
        targetSize: CGSize,
        completion: @escaping (ImageResult) -> Void
    ) -> Cancellable?

    // Preheat (optional)
    func startCaching(indexes: [Int], targetSize: CGSize)
    func stopCaching(indexes: [Int], targetSize: CGSize)
    func stopCachingAll()
}

/// Cancellable request token
protocol Cancellable {
    func cancel()
}

// MARK: - MockImageProvider

/// Mock provider that generates random color images with simulated decode delay
final class MockImageProvider: ImageProvider {

    private(set) var count: Int = 0
    private var identifiers: [String] = []

    // Simulated decode delay (ms)
    var simulatedDecodeDelayMs: Double = 2.0

    func loadLibrary(completion: @escaping (Int, Double) -> Void) {
        // Default 50k for stress test
        loadLibrary(count: 50_000, completion: completion)
    }

    func loadLibrary(count: Int, completion: @escaping (Int, Double) -> Void) {
        let start = CACurrentMediaTime()

        self.count = count
        self.identifiers = (0..<count).map { "mock_\($0)" }

        let elapsed = (CACurrentMediaTime() - start) * 1000
        completion(count, elapsed)
    }

    func identifier(at index: Int) -> String {
        guard index >= 0 && index < identifiers.count else { return "" }
        return identifiers[index]
    }

    func requestImage(
        at index: Int,
        targetSize: CGSize,
        completion: @escaping (ImageResult) -> Void
    ) -> Cancellable? {
        guard index >= 0 && index < count else {
            completion(ImageResult(image: nil, isDegraded: false))
            return nil
        }

        let request = MockImageRequest()

        // Simulate async image decode with delay
        let delaySeconds = simulatedDecodeDelayMs / 1000.0
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delaySeconds) {
            guard !request.isCancelled else { return }

            // Generate deterministic color based on index
            let image = Self.generateImage(for: index, size: targetSize)

            DispatchQueue.main.async {
                guard !request.isCancelled else { return }
                completion(ImageResult(image: image, isDegraded: false))  // Mock always returns final
            }
        }

        return request
    }

    func startCaching(indexes: [Int], targetSize: CGSize) {
        // No-op for mock (could add prefetch simulation if needed)
    }

    func stopCaching(indexes: [Int], targetSize: CGSize) {
        // No-op for mock
    }

    func stopCachingAll() {
        // No-op for mock
    }

    // MARK: - Image Generation

    private static func generateImage(for index: Int, size: CGSize) -> UIImage {
        let hue = CGFloat(index % 360) / 360.0
        let color = UIColor(hue: hue, saturation: 0.6, brightness: 0.9, alpha: 1.0)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw index number
            let text = "\(index)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: min(size.width, size.height) * 0.3, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - MockImageRequest

private final class MockImageRequest: Cancellable {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

// MARK: - PhotoKitImageProvider

/// Real PhotoKit provider using PHCachingImageManager
final class PhotoKitImageProvider: ImageProvider {

    private var fetchResult: PHFetchResult<PHAsset>?
    private let imageManager = PHCachingImageManager()

    /// Delivery mode for thumbnail loading (A/B test option)
    /// - opportunistic: multiple callbacks (degraded + final), better UX but more UI churn
    /// - fastFormat: single callback, faster but lower quality
    var useFastFormat: Bool = false

    var count: Int {
        fetchResult?.count ?? 0
    }

    func loadLibrary(completion: @escaping (Int, Double) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.fetchPhotos(completion: completion)
                default:
                    completion(0, 0)
                }
            }
        }
    }

    private func fetchPhotos(completion: @escaping (Int, Double) -> Void) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let start = CACurrentMediaTime()
        // Fetch all assets (photo + video + livePhoto) - no mediaType filter
        fetchResult = PHAsset.fetchAssets(with: options)
        let elapsed = (CACurrentMediaTime() - start) * 1000

        completion(fetchResult?.count ?? 0, elapsed)
    }

    func identifier(at index: Int) -> String {
        guard let fetchResult = fetchResult, index >= 0 && index < fetchResult.count else {
            return ""
        }
        return fetchResult.object(at: index).localIdentifier
    }

    func requestImage(
        at index: Int,
        targetSize: CGSize,
        completion: @escaping (ImageResult) -> Void
    ) -> Cancellable? {
        guard let fetchResult = fetchResult, index >= 0 && index < fetchResult.count else {
            completion(ImageResult(image: nil, isDegraded: false))
            return nil
        }

        let asset = fetchResult.object(at: index)

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = useFastFormat ? .fastFormat : .opportunistic
        options.resizeMode = .fast

        let requestID = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            // Check if this is degraded (low-quality preview) or final image
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            completion(ImageResult(image: image, isDegraded: isDegraded))
        }

        return PhotoKitImageRequest(requestID: requestID, imageManager: imageManager)
    }

    func startCaching(indexes: [Int], targetSize: CGSize) {
        guard let fetchResult = fetchResult else { return }

        let assets = indexes.compactMap { index -> PHAsset? in
            guard index >= 0 && index < fetchResult.count else { return nil }
            return fetchResult.object(at: index)
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    func stopCaching(indexes: [Int], targetSize: CGSize) {
        guard let fetchResult = fetchResult else { return }

        let assets = indexes.compactMap { index -> PHAsset? in
            guard index >= 0 && index < fetchResult.count else { return nil }
            return fetchResult.object(at: index)
        }

        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopCachingAll() {
        imageManager.stopCachingImagesForAllAssets()
    }
}

// MARK: - PhotoKitImageRequest

private final class PhotoKitImageRequest: Cancellable {
    private let requestID: PHImageRequestID
    private weak var imageManager: PHCachingImageManager?

    init(requestID: PHImageRequestID, imageManager: PHCachingImageManager) {
        self.requestID = requestID
        self.imageManager = imageManager
    }

    func cancel() {
        imageManager?.cancelImageRequest(requestID)
    }
}
