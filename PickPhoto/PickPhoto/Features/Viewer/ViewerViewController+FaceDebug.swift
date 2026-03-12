// ViewerViewController+FaceDebug.swift
// 얼굴 감지 디버그 기능
//
// 현재 보고 있는 사진에 대해 다양한 해상도로 Vision 얼굴 감지를 수행하고
// 결과를 비교하여 감지 실패 원인을 파악합니다.
//
// DEBUG 빌드에서만 활성화됩니다.

#if DEBUG

import UIKit
import Photos
import Vision
import OSLog
import AppCore

extension ViewerViewController {

    // MARK: - Debug Button Setup

    /// 얼굴 감지 디버그 버튼 생성 및 배치
    /// - setupUI() 이후에 호출
    func setupFaceDebugButton() {
        let button = UIButton(type: .system)
        button.setTitle("FD", for: .normal)
        button.setTitleColor(.yellow, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(faceDebugButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "viewer_face_debug"

        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),
            button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60)
        ])
    }

    // MARK: - Debug Action

    /// 디버그 버튼 탭: 현재 사진에 대해 다양한 해상도로 얼굴 감지 수행
    @objc private func faceDebugButtonTapped() {
        guard let asset = coordinator.asset(at: currentIndex) else {
            Logger.similarPhoto.error("[FaceDebug] asset을 가져올 수 없음")
            return
        }

        let shortID = String(asset.localIdentifier.prefix(8))
        let originalSize = "\(asset.pixelWidth)×\(asset.pixelHeight)"
        Logger.similarPhoto.notice("[FaceDebug] ═══ 시작: \(shortID) 원본: \(originalSize) ═══")

        // 알림으로 시작 표시
        showFaceDebugToast("분석 중...")

        Task {
            // 테스트할 해상도 목록 (긴 변 기준)
            let testSizes: [(label: String, maxSize: CGFloat?)] = [
                ("480px", 480),
                ("1080px", 1080),
                ("1600px", 1600),
                ("2200px", 2200),
                ("원본", nil)  // nil = 원본 크기
            ]

            var results: [(String, Int, CGSize)] = []  // (label, faceCount, actualSize)

            for (label, maxSize) in testSizes {
                do {
                    let (faceCount, actualSize, faces) = try await detectFacesAtSize(
                        asset: asset,
                        maxSize: maxSize
                    )
                    results.append((label, faceCount, actualSize))

                    // 각 해상도별 결과 로그
                    Logger.similarPhoto.notice(
                        "[FaceDebug] \(label): \(faceCount)개 감지 (실제 \(Int(actualSize.width))×\(Int(actualSize.height)))"
                    )

                    // 감지된 얼굴 상세 로그
                    for (i, face) in faces.enumerated() {
                        let box = face.boundingBox
                        let widthPx = Int(box.width * actualSize.width)
                        let heightPx = Int(box.height * actualSize.height)
                        Logger.similarPhoto.debug(
                            "[FaceDebug]   face[\(i)]: \(widthPx)×\(heightPx)px (정규화: w=\(String(format: "%.3f", box.width)) h=\(String(format: "%.3f", box.height)))"
                        )
                    }
                } catch {
                    results.append((label, -1, .zero))
                    Logger.similarPhoto.error("[FaceDebug] \(label): 실패 - \(error.localizedDescription)")
                }
            }

            Logger.similarPhoto.notice("[FaceDebug] ═══ 완료 ═══")

            // UI 결과 표시
            await MainActor.run {
                let summary = results.map { (label, count, size) in
                    if count >= 0 {
                        return "\(label): \(count)개 (\(Int(size.width))×\(Int(size.height)))"
                    } else {
                        return "\(label): 실패"
                    }
                }.joined(separator: "\n")

                showFaceDebugAlert(title: "얼굴 감지 결과", message: summary)
            }
        }
    }

    // MARK: - Detection at Specific Size

    /// 지정된 해상도로 얼굴 감지 수행
    ///
    /// - Parameters:
    ///   - asset: 대상 PHAsset
    ///   - maxSize: 긴 변 기준 최대 크기 (nil이면 원본)
    /// - Returns: (감지 수, 실제 이미지 크기, 감지된 얼굴 배열)
    private func detectFacesAtSize(
        asset: PHAsset,
        maxSize: CGFloat?
    ) async throws -> (Int, CGSize, [VNFaceObservation]) {
        // 이미지 로드
        let cgImage: CGImage
        if let maxSize = maxSize {
            cgImage = try await SimilarityImageLoader.shared.loadImage(for: asset, maxSize: maxSize)
        } else {
            // 원본 크기: 별도 옵션으로 요청
            cgImage = try await loadOriginalImage(for: asset)
        }

        let actualSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Vision 얼굴 감지
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let faces = request.results ?? []
        return (faces.count, actualSize, faces)
    }

    /// 원본 크기 이미지 로드
    private func loadOriginalImage(for asset: PHAsset) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none  // 리사이즈 없음 = 원본
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,  // 원본 크기
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // degraded 스킵
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let uiImage = image, let cgImage = uiImage.cgImage else {
                    continuation.resume(throwing: FaceDetectionError.imageLoadFailed("원본 이미지 nil"))
                    return
                }

                continuation.resume(returning: cgImage)
            }
        }
    }

    // MARK: - UI Helpers

    /// 간단한 토스트 표시
    private func showFaceDebugToast(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 9999  // 식별용

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            label.heightAnchor.constraint(equalToConstant: 36)
        ])

        // 3초 후 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            label.removeFromSuperview()
        }
    }

    /// 결과 알림 표시
    private func showFaceDebugAlert(title: String, message: String) {
        // 토스트 제거
        view.viewWithTag(9999)?.removeFromSuperview()

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

#endif
