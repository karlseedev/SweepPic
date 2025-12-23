// ThumbnailCache.swift
// 디스크 기반 썸네일 캐시
//
// v6 최적화:
// - SHA256 stable key (CryptoKit)
// - modificationDate 포함으로 편집된 사진 자동 무효화
// - 비동기 load + 백그라운드 predecode
// - LRU: 접근 시 touch (수정일 갱신)
// - 구캐시 회수 정책: LRU trim으로 자연 회수

import UIKit
import CryptoKit

// MARK: - ThumbnailCache

/// 디스크 기반 썸네일 캐시
/// - 콜드 런치에서도 첫 화면 즉시 표시 지원
/// - 편집된 사진 자동 무효화 (modificationDate 기반)
/// - LRU 알고리즘으로 용량 관리
public final class ThumbnailCache {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = ThumbnailCache()

    // MARK: - Constants

    /// 최대 캐시 크기 (100MB)
    private let maxCacheSize: Int = 100 * 1024 * 1024

    /// JPEG 압축 품질 (0.8 = 좋은 품질 + 적절한 크기)
    private let jpegQuality: CGFloat = 0.8

    // MARK: - Debug Counters

    #if DEBUG
    /// 캐시 히트 카운터 (앱 시작 후 누적)
    public private(set) static var hitCount: Int = 0
    /// 캐시 미스 카운터 (앱 시작 후 누적)
    public private(set) static var missCount: Int = 0
    /// 카운터 락
    private static let counterLock = NSLock()

    /// 히트율 계산 (0.0 ~ 1.0)
    public static var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }

    /// 카운터 리셋 (테스트용)
    public static func resetCounters() {
        counterLock.withLock {
            hitCount = 0
            missCount = 0
        }
    }
    #endif

    // MARK: - Private Properties

    /// 캐시 디렉토리 URL
    private let cacheDirectory: URL

    /// 파일 I/O 전용 큐 (백그라운드)
    private let ioQueue = DispatchQueue(label: "com.pickphoto.thumbnailcache.io", qos: .utility)

    /// 화면 스케일 (캐시 키에 포함)
    private let scale: CGFloat

    // MARK: - Initialization

    /// 비공개 초기화 (싱글톤)
    private init() {
        // 캐시 디렉토리 설정
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appendingPathComponent("Thumbnails", isDirectory: true)

        // 스케일 저장 (메인 스레드에서만 접근 가능)
        scale = UIScreen.main.scale

        // 디렉토리 생성
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        #if DEBUG
        FileLogger.log("[ThumbnailCache] Cache directory: \(cacheDirectory.path)")
        #endif
    }

    // MARK: - Public API

    /// 비동기 로드 + predecode (백그라운드에서 실행, 메인 hitch 방지)
    /// - Parameters:
    ///   - assetID: 에셋 ID (localIdentifier)
    ///   - modificationDate: 에셋 수정일 (nil이면 캐시 무효화 불가)
    ///   - size: 목표 크기 (픽셀 단위)
    ///   - completion: 완료 콜백 (메인 스레드에서 호출, nil이면 캐시 미스)
    public func load(
        assetID: String,
        modificationDate: Date?,
        size: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        ioQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let path = self.cachePath(assetID: assetID, modDate: modificationDate, size: size)

            // 파일 존재 확인
            guard FileManager.default.fileExists(atPath: path.path),
                  let image = UIImage(contentsOfFile: path.path) else {
                // 캐시 미스
                #if DEBUG
                Self.counterLock.withLock { Self.missCount += 1 }
                let total = Self.hitCount + Self.missCount
                if total <= 50 {
                    FileLogger.log("[ThumbnailCache] MISS #\(total): \(assetID.prefix(8))...")
                }
                if total == 50 {
                    FileLogger.log("[ThumbnailCache] === 첫 50셀 히트율: \(String(format: "%.1f", Self.hitRate * 100))% (hit=\(Self.hitCount), miss=\(Self.missCount)) ===")
                }
                #endif
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // 캐시 히트 (스크롤 중 로그 비활성화 - hitch 방지)
            // 원복: git checkout a5414d4 -- Sources/AppCore/Services/ThumbnailCache.swift
            #if false  // DEBUG 로그 임시 비활성화
            Self.counterLock.withLock { Self.hitCount += 1 }
            let total = Self.hitCount + Self.missCount
            if total <= 50 {
                FileLogger.log("[ThumbnailCache] HIT #\(total): \(assetID.prefix(8))...")
            }
            if total == 50 {
                FileLogger.log("[ThumbnailCache] === 첫 50셀 히트율: \(String(format: "%.1f", Self.hitRate * 100))% (hit=\(Self.hitCount), miss=\(Self.missCount)) ===")
            }
            #endif

            // LRU: 접근 시 수정일 갱신 (touch)
            // - 가장 최근에 접근한 파일이 가장 나중에 삭제됨
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: path.path
            )

            // predecode (백그라운드에서)
            // - 메인 스레드에서 이미지 렌더링 시 hitch 방지
            let decodedImage: UIImage?
            if #available(iOS 15.0, *) {
                // iOS 15+: 최적화된 predecode API
                decodedImage = image.preparingForDisplay()
            } else {
                // iOS 14 이하: CGImage 접근으로 강제 디코딩
                _ = image.cgImage
                decodedImage = image
            }

            DispatchQueue.main.async {
                completion(decodedImage)
            }
        }
    }

    /// 비동기 저장
    /// - degraded 이미지는 저장하지 않음 (호출자가 판단)
    /// - Parameters:
    ///   - image: 저장할 이미지
    ///   - assetID: 에셋 ID
    ///   - modificationDate: 에셋 수정일
    ///   - size: 이미지 크기 (픽셀 단위)
    public func save(
        image: UIImage,
        assetID: String,
        modificationDate: Date?,
        size: CGSize
    ) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let path = self.cachePath(assetID: assetID, modDate: modificationDate, size: size)

            // JPEG 압축 후 저장
            if let data = image.jpegData(compressionQuality: self.jpegQuality) {
                do {
                    try data.write(to: path)
                    #if DEBUG
                    let sizeKB = data.count / 1024
                    if sizeKB > 100 {
                        FileLogger.log("[ThumbnailCache] Saved large file: \(sizeKB)KB")
                    }
                    #endif
                } catch {
                    #if DEBUG
                    FileLogger.log("[ThumbnailCache] Save failed: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    /// 캐시 존재 여부 확인 (동기 - 빠른 파일 체크만)
    /// - 중복 저장 방지용
    /// - Parameters:
    ///   - assetID: 에셋 ID
    ///   - modificationDate: 에셋 수정일
    ///   - size: 이미지 크기
    /// - Returns: 캐시 파일 존재 여부
    public func exists(assetID: String, modificationDate: Date?, size: CGSize) -> Bool {
        let path = cachePath(assetID: assetID, modDate: modificationDate, size: size)
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// 특정 에셋의 캐시 삭제
    /// - Note: 해시 기반 파일명이라 assetID로 직접 매칭 불가
    /// - 현재는 LRU trim에 의존하여 자연 회수됨
    /// - PHPhotoLibraryChangeObserver 기반 즉시 삭제는 향후 최적화
    public func invalidate(assetIDs: [String]) {
        // TODO: 필요 시 구현
        // 현재 정책: modificationDate 기반 자동 무효화 + LRU 자연 회수
    }

    /// 주기적 트림 (앱 시작 시 또는 백그라운드에서 호출)
    /// - 용량이 maxCacheSize 초과 시 가장 오래된 파일부터 삭제
    public func trimIfNeeded() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            self.performLRUTrim()
        }
    }

    /// 전체 캐시 삭제
    public func clearAll() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: self.cacheDirectory,
                    includingPropertiesForKeys: nil
                )

                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }

                #if DEBUG
                FileLogger.log("[ThumbnailCache] Cleared all cache: \(files.count) files")
                #endif
            } catch {
                #if DEBUG
                FileLogger.log("[ThumbnailCache] Clear failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Private Methods

    /// Stable key 기반 캐시 경로 생성
    /// - SHA256(assetID + modDate + width + height + scale)
    /// - modificationDate 포함으로 편집된 사진 자동 무효화
    private func cachePath(assetID: String, modDate: Date?, size: CGSize) -> URL {
        // modificationDate를 문자열로 변환 (nil이면 "nil")
        let modString = modDate.map { String($0.timeIntervalSince1970) } ?? "nil"

        // 캐시 키 생성 (assetID + modDate + size + scale)
        let key = "\(assetID)_\(modString)_\(Int(size.width))_\(Int(size.height))_\(Int(scale))"

        // SHA256 해시 (CryptoKit)
        let hash = sha256(key)

        return cacheDirectory.appendingPathComponent("\(hash).jpg")
    }

    /// SHA256 해시 계산 (CryptoKit)
    /// - 전체 64자 사용 (충돌 방지)
    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        // 전체 해시 사용 (64자)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// LRU 트림 수행
    /// - 수정일 기준 정렬 (접근 시 touch되므로 실제 LRU)
    /// - 가장 오래된 파일부터 삭제하여 용량 제한 유지
    private func performLRUTrim() {
        // 캐시 디렉토리 내 파일 목록 조회
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }

        var totalSize: Int = 0
        var fileInfos: [(url: URL, date: Date, size: Int)] = []

        // 파일 정보 수집
        for file in files {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let date = values.contentModificationDate,
                  let size = values.fileSize else { continue }
            totalSize += size
            fileInfos.append((file, date, size))
        }

        // 용량 초과 시만 트림
        guard totalSize > maxCacheSize else {
            #if DEBUG
            let usedMB = totalSize / (1024 * 1024)
            let maxMB = maxCacheSize / (1024 * 1024)
            FileLogger.log("[ThumbnailCache] Cache size OK: \(usedMB)MB / \(maxMB)MB (\(files.count) files)")
            #endif
            return
        }

        #if DEBUG
        let beforeMB = totalSize / (1024 * 1024)
        #endif

        // 오래된 순 정렬 (가장 오래 접근 안 한 것부터)
        fileInfos.sort { $0.date < $1.date }

        var deletedCount = 0

        // 용량 제한 이하가 될 때까지 삭제
        for info in fileInfos {
            guard totalSize > maxCacheSize else { break }
            do {
                try FileManager.default.removeItem(at: info.url)
                totalSize -= info.size
                deletedCount += 1
            } catch {
                // 삭제 실패 시 무시하고 계속
            }
        }

        #if DEBUG
        let afterMB = totalSize / (1024 * 1024)
        FileLogger.log("[ThumbnailCache] Trimmed: \(beforeMB)MB → \(afterMB)MB, deleted \(deletedCount) files")
        #endif
    }
}
