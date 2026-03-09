//
//  FileSizeCalculator.swift
//  AppCore
//
//  PHAsset 파일 크기 계산 유틸리티 (research.md §R4)
//
//  PHAssetResource.assetResources(for:)로 각 asset의 fileSize 합산
//  백그라운드 큐에서 실행, 실패 시 0 반환
//

import Foundation
import Photos
import OSLog

// MARK: - FileSizeCalculator

/// PHAsset 파일 크기 계산 유틸리티
public final class FileSizeCalculator {

    // MARK: - Singleton

    public static let shared = FileSizeCalculator()

    // MARK: - Private

    /// 백그라운드 큐 (파일 크기 계산은 메인 스레드 블로킹 방지)
    private let calculationQueue = DispatchQueue(
        label: "com.pickphoto.fileSizeCalculator",
        qos: .utility
    )

    private init() {}

    // MARK: - Public Methods

    /// PHAsset 배열의 총 파일 크기 계산 (비동기)
    /// - Parameters:
    ///   - assets: 크기를 계산할 PHAsset 배열
    ///   - completion: 총 바이트 수 (메인 스레드에서 호출)
    public func calculateTotalSize(
        for assets: [PHAsset],
        completion: @escaping (Int64) -> Void
    ) {
        calculationQueue.async {
            var totalBytes: Int64 = 0

            for asset in assets {
                let resources = PHAssetResource.assetResources(for: asset)

                // 각 리소스의 fileSize 합산
                // 보통 첫 번째 리소스가 원본 파일
                for resource in resources {
                    let size = resource.value(forKey: "fileSize") as? Int64 ?? 0
                    totalBytes += size
                    // 원본 리소스만 사용 (중복 방지: adjustedPhoto 등 제외)
                    break
                }
            }

            Logger.app.debug("FileSizeCalculator: \(assets.count)개 asset → \(totalBytes) bytes")

            DispatchQueue.main.async {
                completion(totalBytes)
            }
        }
    }

    /// PHAsset ID 배열로부터 총 파일 크기 계산 (비동기)
    /// - Parameters:
    ///   - assetIDs: PHAsset 로컬 식별자 배열
    ///   - completion: 총 바이트 수 (메인 스레드에서 호출)
    public func calculateTotalSize(
        forAssetIDs assetIDs: [String],
        completion: @escaping (Int64) -> Void
    ) {
        calculationQueue.async {
            // PHAsset fetch
            let fetchResult = PHAsset.fetchAssets(
                withLocalIdentifiers: assetIDs,
                options: nil
            )

            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }

            // 재귀 호출이 아닌 직접 계산 (이미 백그라운드 큐)
            var totalBytes: Int64 = 0

            for asset in assets {
                let resources = PHAssetResource.assetResources(for: asset)
                for resource in resources {
                    let size = resource.value(forKey: "fileSize") as? Int64 ?? 0
                    totalBytes += size
                    break
                }
            }

            Logger.app.debug("FileSizeCalculator: \(assetIDs.count)개 ID → \(totalBytes) bytes")

            DispatchQueue.main.async {
                completion(totalBytes)
            }
        }
    }

    // MARK: - Formatting

    /// 바이트를 읽기 쉬운 단위로 변환 (KB/MB/GB)
    /// - Parameter bytes: 바이트 수
    /// - Returns: "1.2GB", "350MB", "12KB" 등
    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}
