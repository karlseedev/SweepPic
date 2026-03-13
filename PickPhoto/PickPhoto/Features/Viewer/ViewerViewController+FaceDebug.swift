// ViewerViewController+FaceDebug.swift
// 얼굴 감지 디버그 기능
//
// 현재 보고 있는 사진에 대해 다양한 해상도로
// Vision 얼굴 감지 + YuNet/SFace 인물 매칭을 수행하고
// 결과를 비교하여 감지/매칭 실패 원인을 파악합니다.
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

    /// 디버그 버튼 탭: ActionSheet로 모드 선택
    @objc private func faceDebugButtonTapped() {
        let sheet = UIAlertController(title: "FaceDebug", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "해상도별 분석 (기존)", style: .default) { [weak self] _ in
            self?.runResolutionDebug()
        })
        sheet.addAction(UIAlertAction(title: "640 vs 960 비교", style: .default) { [weak self] _ in
            self?.runYuNetCompare()
        })
        sheet.addAction(UIAlertAction(title: "인물 매칭 디버그", style: .default) { [weak self] _ in
            self?.runPersonMatchDebug()
        })
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(sheet, animated: true)
    }

    /// 해상도별 분석 (기존 FD 기능)
    private func runResolutionDebug() {
        guard let asset = coordinator.asset(at: currentIndex) else {
            Logger.similarPhoto.error("[FaceDebug] asset을 가져올 수 없음")
            return
        }

        let shortID = String(asset.localIdentifier.prefix(8))
        let originalSize = "\(asset.pixelWidth)×\(asset.pixelHeight)"
        Logger.similarPhoto.notice("[FaceDebug] ═══ 시작: \(shortID) 원본: \(originalSize) ═══")

        showFaceDebugToast("분석 중...")

        Task {
            // 테스트할 해상도 목록 (긴 변 기준)
            let testSizes: [(label: String, maxSize: CGFloat?)] = [
                ("480px", 480),
                ("1080px", 1080),
                ("1600px", 1600),
                ("2200px", 2200),
                ("원본", nil)
            ]

            var summaryLines: [String] = []

            for (label, maxSize) in testSizes {
                Logger.similarPhoto.notice("[FaceDebug] ── \(label) ──")

                // 이미지 로드
                let cgImage: CGImage
                do {
                    if let maxSize = maxSize {
                        cgImage = try await SimilarityImageLoader.shared.loadImage(for: asset, maxSize: maxSize)
                    } else {
                        cgImage = try await loadOriginalImage(for: asset)
                    }
                } catch {
                    Logger.similarPhoto.error("[FaceDebug] \(label): 이미지 로드 실패 - \(error.localizedDescription)")
                    summaryLines.append("\(label): 로드 실패")
                    continue
                }

                let actualSize = CGSize(width: cgImage.width, height: cgImage.height)
                let sizeStr = "\(cgImage.width)×\(cgImage.height)"

                // === Vision 얼굴 감지 ===
                let visionCount: Int
                do {
                    let request = VNDetectFaceRectanglesRequest()
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])
                    let faces = request.results ?? []
                    visionCount = faces.count

                    Logger.similarPhoto.notice("[FaceDebug] \(label) Vision: \(visionCount)개 (\(sizeStr))")
                    for (i, face) in faces.enumerated() {
                        let box = face.boundingBox
                        let wPx = Int(box.width * actualSize.width)
                        let hPx = Int(box.height * actualSize.height)
                        Logger.similarPhoto.debug(
                            "[FaceDebug]   vision[\(i)]: \(wPx)×\(hPx)px (w=\(String(format: "%.3f", box.width)) h=\(String(format: "%.3f", box.height)))"
                        )
                    }
                } catch {
                    Logger.similarPhoto.error("[FaceDebug] \(label) Vision 실패: \(error.localizedDescription)")
                    visionCount = -1
                }

                // === YuNet + SFace 분석 ===
                let yunetCount: Int
                let sfaceCount: Int

                if let yunet = YuNetFaceDetector.shared,
                   let sface = SFaceRecognizer.shared {
                    do {
                        let detections = try yunet.detect(in: cgImage)
                        yunetCount = detections.count

                        // 각 얼굴에 대해 SFace 임베딩 추출
                        var embeddingCount = 0
                        var norms: [Float] = []

                        for (i, detection) in detections.enumerated() {
                            // FaceAligner로 정렬
                            guard let aligned = try? FaceAligner.shared.align(
                                image: cgImage,
                                landmarks: detection.landmarks
                            ) else {
                                Logger.similarPhoto.debug("[FaceDebug]   yunet[\(i)]: align 실패")
                                continue
                            }

                            // SFace 임베딩 추출
                            do {
                                let embedding = try sface.extractEmbedding(from: aligned)
                                let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
                                norms.append(norm)
                                embeddingCount += 1

                                // 얼굴 크기 (픽셀)
                                let box = detection.boundingBox
                                Logger.similarPhoto.debug(
                                    "[FaceDebug]   yunet[\(i)]: \(Int(box.width))×\(Int(box.height))px norm=\(String(format: "%.2f", norm))"
                                )
                            } catch {
                                Logger.similarPhoto.debug("[FaceDebug]   yunet[\(i)]: embedding 실패")
                            }
                        }

                        sfaceCount = embeddingCount
                        let normStr = norms.map { String(format: "%.1f", $0) }.joined(separator: ", ")
                        Logger.similarPhoto.notice(
                            "[FaceDebug] \(label) YuNet: \(yunetCount)개, SFace: \(sfaceCount)개 norms=[\(normStr)]"
                        )
                    } catch {
                        Logger.similarPhoto.error("[FaceDebug] \(label) YuNet 실패: \(error.localizedDescription)")
                        yunetCount = -1
                        sfaceCount = -1
                    }
                } else {
                    Logger.similarPhoto.error("[FaceDebug] \(label) YuNet/SFace 모델 없음")
                    yunetCount = -1
                    sfaceCount = -1
                }

                // 요약 라인
                let vStr = visionCount >= 0 ? "\(visionCount)" : "X"
                let yStr = yunetCount >= 0 ? "\(yunetCount)" : "X"
                let sStr = sfaceCount >= 0 ? "\(sfaceCount)" : "X"
                summaryLines.append("\(label) (\(sizeStr)): V=\(vStr) Y=\(yStr) S=\(sStr)")
            }

            Logger.similarPhoto.notice("[FaceDebug] ═══ 완료 ═══")

            // UI 결과 표시
            await MainActor.run {
                let message = summaryLines.joined(separator: "\n")
                showFaceDebugAlert(title: "V=Vision Y=YuNet S=SFace", message: message)
            }
        }
    }

    // MARK: - YuNet 960(stretch) vs 1088(letterbox) 비교

    /// 960×960(stretch) vs 1088×1088(letterbox) YuNet 모델 비교
    /// 같은 이미지(2200px)로 두 모델을 순차 실행하여 속도/감지수/norm 비교
    private func runYuNetCompare() {
        guard let asset = coordinator.asset(at: currentIndex) else { return }

        let shortID = String(asset.localIdentifier.prefix(8))
        Logger.similarPhoto.notice("[FaceDebug] ═══ 640 vs 960 비교 시작: \(shortID) ═══")
        showFaceDebugToast("640 vs 960 비교 중...")

        Task {
            // 2200px 이미지 로드 (인물 매칭 파이프라인과 동일)
            let cgImage: CGImage
            do {
                cgImage = try await SimilarityImageLoader.shared.loadImage(
                    for: asset,
                    maxSize: SimilarityConstants.personMatchImageMaxSize
                )
            } catch {
                Logger.similarPhoto.error("[FaceDebug] 이미지 로드 실패: \(error.localizedDescription)")
                return
            }

            let sizeStr = "\(cgImage.width)×\(cgImage.height)"
            Logger.similarPhoto.notice("[FaceDebug] 이미지: \(sizeStr)")

            // 비교할 모델 설정: (라벨, 모델명, 입력크기)
            let models: [(label: String, modelName: String, inputSize: Int)] = [
                ("640 letterbox", "YuNet640", 640),
                ("960 letterbox", "YuNet960", 960)
            ]

            var summaryLines: [String] = []
            let sface = SFaceRecognizer.shared

            for (label, modelName, inputSize) in models {
                Logger.similarPhoto.notice("[FaceDebug] ── \(label) ──")

                // 모델 로드
                let detector: YuNetFaceDetector
                do {
                    detector = try YuNetFaceDetector(
                        modelName: modelName,
                        inputSize: inputSize
                    )
                } catch {
                    Logger.similarPhoto.error("[FaceDebug] \(label) 모델 로드 실패: \(error.localizedDescription)")
                    summaryLines.append("\(label): 모델 로드 실패")
                    continue
                }

                // 워밍업 1회
                _ = try? detector.detect(in: cgImage)

                // 본측정 3회 median
                var times: [Double] = []
                var lastDetections: [YuNetDetection] = []

                for _ in 0..<3 {
                    let start = CFAbsoluteTimeGetCurrent()
                    let detections = try? detector.detect(in: cgImage)
                    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                    times.append(elapsed)
                    if let d = detections { lastDetections = d }
                }

                // median 시간
                times.sort()
                let medianTime = times[1]

                // SFace 임베딩 + norm
                var norms: [Float] = []
                if let sface = sface {
                    for detection in lastDetections {
                        guard let aligned = try? FaceAligner.shared.align(
                            image: cgImage,
                            landmarks: detection.landmarks
                        ) else { continue }

                        if let embedding = try? sface.extractEmbedding(from: aligned) {
                            let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
                            norms.append(norm)
                        }
                    }
                }

                let normStr = norms.map { String(format: "%.1f", $0) }.joined(separator: ", ")
                let normAbove7 = norms.filter { $0 >= 7.0 }.count

                let timeStr = String(format: "%.0f", medianTime)
                Logger.similarPhoto.notice(
                    "[FaceDebug] \(label): \(timeStr)ms, \(lastDetections.count)개, norms=[\(normStr)], ≥7.0: \(normAbove7)개"
                )

                summaryLines.append(
                    "\(label)\n" +
                    "  시간: \(String(format: "%.0f", medianTime))ms\n" +
                    "  감지: \(lastDetections.count)개\n" +
                    "  norms: [\(normStr)]\n" +
                    "  norm≥7.0: \(normAbove7)개"
                )
            }

            Logger.similarPhoto.notice("[FaceDebug] ═══ 비교 완료 ═══")

            await MainActor.run {
                let message = summaryLines.joined(separator: "\n\n")
                showFaceDebugAlert(title: "960s vs 1088lb (\(sizeStr))", message: message)
            }
        }
    }

    // MARK: - 인물 매칭 디버그

    /// 현재 사진의 인물 매칭 상태를 분석하여 표시
    /// 캐시 무효화 → 재분석 → 결과를 얼럿으로 표시
    private func runPersonMatchDebug() {
        guard let asset = coordinator.asset(at: currentIndex) else { return }

        let assetID = asset.localIdentifier
        let shortID = String(assetID.prefix(8))
        Logger.similarPhoto.notice("[PersonMatchDebug] ═══ 시작: \(shortID) ═══")
        showFaceDebugToast("인물 매칭 분석 중...")

        Task {
            // 1. 캐시 무효화하여 재분석 강제
            await SimilarityCache.shared.setState(.notAnalyzed, for: assetID)

            // 2. 현재 사진 기준 ±7장 범위로 재분석 트리거
            let ext = SimilarityConstants.analysisRangeExtension
            let totalCount = coordinator.totalCount
            let lower = max(0, currentIndex - ext)
            let upper = min(totalCount - 1, currentIndex + ext)
            let range = lower...upper

            guard let fetchResult = coordinator.fetchResult else { return }

            _ = await SimilarityAnalysisQueue.shared.formGroupsForRange(
                range,
                source: .viewer,
                fetchResult: fetchResult
            )

            // 3. 재분석 완료 후 캐시에서 결과 읽기
            let allFaces = await SimilarityCache.shared.getFaces(for: assetID)
            let validFaces = allFaces.filter { $0.isValidSlot }

            // 4. YuNet으로 현재 사진 독립 감지 (캐시와 비교용)
            var yunetCount = 0
            var norms: [Float] = []

            if let cgImage = try? await SimilarityImageLoader.shared.loadImage(
                for: asset,
                maxSize: SimilarityConstants.personMatchImageMaxSize
            ),
               let yunet = YuNetFaceDetector.shared,
               let sface = SFaceRecognizer.shared {
                let detections = try? yunet.detect(in: cgImage)
                yunetCount = detections?.count ?? 0

                for detection in detections ?? [] {
                    guard let aligned = try? FaceAligner.shared.align(
                        image: cgImage,
                        landmarks: detection.landmarks
                    ) else {
                        norms.append(0)
                        continue
                    }
                    if let embedding = try? sface.extractEmbedding(from: aligned) {
                        let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
                        norms.append(norm)
                    } else {
                        norms.append(0)
                    }
                }
            }

            // 5. 결과 구성
            let normStr = norms.map { String(format: "%.1f", $0) }.joined(separator: ", ")

            var lines: [String] = []
            lines.append("YuNet 감지: \(yunetCount)개")
            lines.append("norms: [\(normStr)]")
            lines.append("")
            lines.append("캐시 매칭: \(allFaces.count)개")
            lines.append("유효(+버튼): \(validFaces.count)개")

            // 각 매칭된 얼굴 상세
            if !allFaces.isEmpty {
                lines.append("")
                for face in allFaces.sorted(by: { $0.personIndex < $1.personIndex }) {
                    let costStr = face.sfaceCost.map { String(format: "%.3f", $0) } ?? "-"
                    let validStr = face.isValidSlot ? "✓" : "✗"
                    lines.append("slot\(face.personIndex) cost=\(costStr) valid=\(validStr)")
                }
            }

            // 미매칭 분석
            let unmatchedCount = yunetCount - allFaces.count
            if unmatchedCount > 0 {
                lines.append("")
                lines.append("미매칭: \(unmatchedCount)개 (콘솔 로그 확인)")
            }

            let logMsg = lines.joined(separator: " | ")
            Logger.similarPhoto.notice("[PersonMatchDebug] \(shortID): \(logMsg)")
            Logger.similarPhoto.notice("[PersonMatchDebug] ═══ 완료 ═══")

            await MainActor.run {
                let message = lines.joined(separator: "\n")
                showFaceDebugAlert(title: "인물매칭 \(shortID)", message: message)
            }
        }
    }

    // MARK: - Original Image Loader

    /// 원본 크기 이미지 로드
    private func loadOriginalImage(for asset: PHAsset) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
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
        label.tag = 9999

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            label.heightAnchor.constraint(equalToConstant: 36)
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            label.removeFromSuperview()
        }
    }

    /// 결과 알림 표시
    private func showFaceDebugAlert(title: String, message: String) {
        view.viewWithTag(9999)?.removeFromSuperview()

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

#endif
