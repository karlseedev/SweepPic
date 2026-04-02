//
//  PersonMatchingEngine.swift
//  SweepPic
//
//  인물 매칭 엔진 — Feature Print 생성 및 인물 번호 할당의 단일 소스
//
//  SimilarityAnalysisQueue와 FaceScanService가 동일한 분석 로직을 사용하기 위해
//  핵심 알고리즘을 독립 클래스로 추출한 것입니다.
//
//  포함 메서드:
//  - generateFeaturePrints(): Feature Print 병렬 생성 + 얼굴 유무 확인
//  - assignPersonIndicesForGroup(): 7단계 인물 매칭 알고리즘
//
//  주의: 이 파일의 로직은 SimilarityAnalysisQueue 원본에서 그대로 추출한 것입니다.
//        리팩토링/개선 없이 원본과 동일하게 유지해야 합니다.
//

import Foundation
import Photos
import Vision
import UIKit
import AppCore
import OSLog

/// 인물 매칭 엔진 — Feature Print 생성 및 인물 번호 할당의 단일 소스
///
/// SimilarityAnalysisQueue와 FaceScanService가 동일한 분석 로직을 사용하기 위해
/// 핵심 알고리즘을 독립 클래스로 추출한 것입니다.
final class PersonMatchingEngine {

    // MARK: - Dependencies

    /// 이미지 로더 (생성자 주입)
    private let imageLoader: SimilarityImageLoader

    /// 유사도 분석기 (internal — formGroups() 호출용)
    let analyzer: SimilarityAnalyzer

    // MARK: - Internal Types

    /// 동적 인물 슬롯 (기준 임베딩 + 메타데이터)
    ///
    /// Keep Best 정책: 더 높은 norm의 임베딩으로 갱신
    /// 위치 갱신 정책: 매칭 시 최근 위치로 갱신 (저품질 경로 정확도 향상)
    private struct PersonSlot {
        let id: Int                // 슬롯 ID (1-based)
        var embedding: [Float]     // 128차원 SFace 임베딩
        var norm: Float            // 임베딩 norm (품질 지표)
        var center: CGPoint        // 최근 매칭 위치 (갱신됨)
        var boundingBox: CGRect    // 최근 매칭 바운딩박스 (갱신됨)
    }

    /// 임베딩 품질 임계값 (norm 기준)
    /// norm < 7인 얼굴은 저품질로 판정하여 신규 슬롯 생성 금지
    private let minEmbeddingNorm: Float = 7.0

    /// 매칭 후보 (전역 정렬용)
    private struct MatchCandidate {
        let faceIdx: Int
        let slotID: Int
        let cost: Float           // Dist_fp
        let posDistNorm: CGFloat  // Dist_pos / √2
        let boundingBox: CGRect
        let center: CGPoint       // 얼굴 중심 (슬롯 위치 갱신용)
        let embedding: [Float]    // Keep Best용 임베딩
        let norm: Float           // 얼굴 임베딩 품질
        let slotNorm: Float       // 슬롯 임베딩 품질 (고품질 확장 판정용)
    }

    // MARK: - Init

    /// 인물 매칭 엔진을 초기화합니다.
    ///
    /// - Parameters:
    ///   - imageLoader: 이미지 로더 (기본값: 공유 인스턴스)
    ///   - analyzer: 유사도 분석기 (기본값: 공유 인스턴스)
    init(imageLoader: SimilarityImageLoader = .shared,
         analyzer: SimilarityAnalyzer = .shared) {
        self.imageLoader = imageLoader
        self.analyzer = analyzer
    }

    /// 과열 상태 판단 (ProcessInfo 직접 확인 — 외부 상태 의존 제거)
    private var isThermalThrottled: Bool {
        ProcessInfo.processInfo.thermalState.rawValue >=
            ProcessInfo.ThermalState.serious.rawValue
    }

    // MARK: - Public Methods

    /// Feature Print를 병렬 생성하고 얼굴 유무를 확인합니다.
    ///
    /// AsyncSemaphore로 동시성을 제한하고 (정상: 5개, 과열: 2개),
    /// withThrowingTaskGroup으로 병렬 처리합니다.
    ///
    /// - Parameter photos: 분석할 PHAsset 배열
    /// - Returns: (featurePrints: FP 배열, hasFaces: 얼굴 유무 배열)
    func generateFeaturePrints(for photos: [PHAsset]) async -> (featurePrints: [VNFeaturePrintObservation?], hasFaces: [Bool]) {
        let currentLimit = isThermalThrottled
            ? SimilarityConstants.maxConcurrentAnalysisThermal
            : SimilarityConstants.maxConcurrentAnalysis

        let semaphore = AsyncSemaphore(value: currentLimit)

        // withThrowingTaskGroup 사용: child task에서 CancellationError throw 가능
        // 외부 시그니처는 non-throws 유지 (CancellationError를 내부에서 흡수)
        do {
            return try await withThrowingTaskGroup(of: (Int, VNFeaturePrintObservation?, Bool).self) { group in
                for (index, photo) in photos.enumerated() {
                    group.addTask {
                        // child task 내부에서도 취소 체크
                        try Task.checkCancellation()

                        await semaphore.wait()
                        defer { semaphore.signal() }

                        // 세마포어 획득 후 재확인
                        try Task.checkCancellation()

                        do {
                            let image = try await self.imageLoader.loadImage(for: photo)
                            // 배치 처리: FeaturePrint + 얼굴 유무를 같은 핸들러에서 실행
                            let (fp, hasFace) = try await self.analyzer.generateFeaturePrintWithFaceCheck(for: image)
                            return (index, fp, hasFace)
                        } catch is CancellationError {
                            throw CancellationError()  // 상위로 전파
                        } catch SimilarityImageLoadError.cancelled {
                            throw CancellationError()  // 취소를 CancellationError로 변환
                        } catch {
                            // 다른 에러만 nil/false로 처리
                            return (index, nil, false)
                        }
                    }
                }

                // 결과 수집
                var fpResults = [VNFeaturePrintObservation?](repeating: nil, count: photos.count)
                var faceResults = [Bool](repeating: false, count: photos.count)
                for try await (index, fp, hasFace) in group {
                    // 취소 감지 시 나머지 작업 취소
                    if Task.isCancelled {
                        group.cancelAll()
                        break
                    }
                    fpResults[index] = fp
                    faceResults[index] = hasFace
                }
                return (fpResults, faceResults)
            }
        } catch is CancellationError {
            // 취소 시 부분 결과 전부 버리고 빈 배열 반환 (캐시 오염 방지)
            Logger.similarPhoto.debug("generateFeaturePrints cancelled - returning empty")
            return ([], [])
        } catch {
            Logger.similarPhoto.error("generateFeaturePrints error: \(error)")
            return ([], [])
        }
    }

    /// 그룹 단위로 일관된 인물 번호를 부여합니다.
    ///
    /// YuNet 960으로 얼굴 감지 + SFace 임베딩 생성 후,
    /// 전역 후보 정렬 기반 근사 매칭 알고리즘을 사용합니다.
    /// - 동적 인물 풀: 첫 사진에서 부팅, 이후 신규 인물 등록
    /// - Grey Zone 전략: 확신/모호/거절 구간으로 나누어 위치 조건 적용
    /// - 캐시 미저장 정책: FP 실패 또는 매칭 실패 얼굴은 CachedFace에 저장하지 않음
    ///
    /// - Parameters:
    ///   - assetIDs: 그룹 멤버 순서 (분석 순서)
    ///   - photos: PHAsset 배열 (이미지 로딩용)
    /// - Returns: 일관된 personIndex가 부여된 CachedFace 맵
    func assignPersonIndicesForGroup(
        assetIDs: [String],
        photos: [PHAsset]
    ) async -> [String: [CachedFace]] {

        // assetID → PHAsset 매핑
        let photoMap = Dictionary(uniqueKeysWithValues: photos.map { ($0.localIdentifier, $0) })

        // 결과 저장
        var result: [String: [CachedFace]] = [:]

        // 동적 인물 풀 (사진 처리하며 성장)
        var activeSlots: [PersonSlot] = []
        var nextSlotID: Int = 1

        // 상수
        let greyZoneThreshold = SimilarityConstants.greyZoneThreshold
        let rejectThreshold = SimilarityConstants.personMatchThreshold
        let greyZonePosLimit = SimilarityConstants.greyZonePositionLimit
        let maxSlots = SimilarityConstants.maxPersonSlots
        let sqrt2: CGFloat = sqrt(2.0)

        // 고품질 확장: 양쪽 norm 모두 높으면 거절 임계값 완화
        let highQualityNormLimit: Float = 8.0       // 양쪽 norm ≥ 8.0이면 고품질 쌍
        let extendedRejectThreshold: Float = 0.75   // 고품질 쌍의 완화된 거절 임계값

        // 성능 측정 변수
        let perfGroupStart = CFAbsoluteTimeGetCurrent()
        var perfLoadTotal: Double = 0
        var perfYunetTotal: Double = 0
        var perfSfaceTotal: Double = 0
        var perfMatchTotal: Double = 0
        var perfFaceCount: Int = 0
        var prevLoadEndTime: CFAbsoluteTime = perfGroupStart  // idle gap 측정용

        // 각 사진 처리
        for assetID in assetIDs {
            // 취소 체크: 사진 처리 루프
            guard !Task.isCancelled else {
                Logger.similarPhoto.debug("Cancelled during person assignment - skipping cache/notification")
                return result
            }

            let shortID = String(assetID.prefix(8))

            // 사진 메타데이터 (로그용)
            let photo = photoMap[assetID]
            let photoMeta = photo.map { "\($0.pixelWidth)x\($0.pixelHeight)" } ?? "?"

            // === Step 0: 이미지 로드 (async 그대로) ===
            let perfLoadStart = CFAbsoluteTimeGetCurrent()
            let perfGapMs = (perfLoadStart - prevLoadEndTime) * 1000
            var cgImage: CGImage? = nil
            var degradedMs: Double? = nil
            if let photo = photo {
                if let result = try? await imageLoader.loadImageWithDiag(
                    for: photo,
                    maxSize: SimilarityConstants.personMatchImageMaxSize
                ) {
                    cgImage = result.cgImage
                    degradedMs = result.degradedMs
                }
            }
            let perfLoadMs = (CFAbsoluteTimeGetCurrent() - perfLoadStart) * 1000
            perfLoadTotal += perfLoadMs
            prevLoadEndTime = CFAbsoluteTimeGetCurrent()



            // === Step 1: YuNet + SFace 추론을 전용 inference queue에서 순수 동기 실행 ===
            // DispatchQueue.global에서 async/await 없이 동기 코드만 실행하여
            // 스레드 전환 없이 확실하게 백그라운드에서 추론합니다.
            let inferenceResult: (
                faceEmbeddings: [Int: [Float]],
                faceData: [Int: (center: CGPoint, boundingBox: CGRect)],
                yunetMs: Double,
                sfaceMs: Double,
                faceCount: Int
            ) = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    // 모델/이미지 확인
                    guard let image = cgImage,
                          let yunet = YuNetFaceDetector.shared,
                          let sface = SFaceRecognizer.shared else {
                        continuation.resume(returning: (
                            faceEmbeddings: [:], faceData: [:], yunetMs: 0, sfaceMs: 0, faceCount: 0
                        ))
                        return
                    }

                    // YuNet 얼굴 감지 (순수 동기)

                    let perfYunetStart = CFAbsoluteTimeGetCurrent()
                    let yunetDetections: [YuNetDetection]
                    do {
                        yunetDetections = try yunet.detect(in: image)
                    } catch {
                        let perfYunetMs = (CFAbsoluteTimeGetCurrent() - perfYunetStart) * 1000
                        continuation.resume(returning: (
                            faceEmbeddings: [:], faceData: [:], yunetMs: perfYunetMs, sfaceMs: 0, faceCount: 0
                        ))
                        return
                    }
                    let perfYunetMs = (CFAbsoluteTimeGetCurrent() - perfYunetStart) * 1000


                    // SFace 임베딩 추출 (순수 동기)
                    var faceEmbeddings: [Int: [Float]] = [:]
                    var faceData: [Int: (center: CGPoint, boundingBox: CGRect)] = [:]

                    let perfSfaceStart = CFAbsoluteTimeGetCurrent()
                    for (faceIdx, detection) in yunetDetections.enumerated() {
                        let imageWidth = CGFloat(image.width)
                        let imageHeight = CGFloat(image.height)
                        let normalizedBox = CGRect(
                            x: detection.boundingBox.origin.x / imageWidth,
                            y: 1.0 - (detection.boundingBox.origin.y + detection.boundingBox.size.height) / imageHeight,
                            width: detection.boundingBox.size.width / imageWidth,
                            height: detection.boundingBox.size.height / imageHeight
                        )
                        let center = CGPoint(x: normalizedBox.midX, y: normalizedBox.midY)
                        faceData[faceIdx] = (center: center, boundingBox: normalizedBox)

                        guard let alignedFace = try? FaceAligner.shared.align(
                            image: image,
                            landmarks: detection.landmarks
                        ) else { continue }


                        do {
                            let embedding = try sface.extractEmbedding(from: alignedFace)
                            faceEmbeddings[faceIdx] = embedding
                        } catch {
                            AnalyticsService.shared.countError(.embedding as AnalyticsError.Face)
                            continue
                        }
                    }
                    let perfSfaceMs = (CFAbsoluteTimeGetCurrent() - perfSfaceStart) * 1000

                    continuation.resume(returning: (
                        faceEmbeddings: faceEmbeddings, faceData: faceData,
                        yunetMs: perfYunetMs, sfaceMs: perfSfaceMs, faceCount: faceEmbeddings.count
                    ))
                }
            }

            // 워커 결과를 로컬 변수로 풀기
            var faceEmbeddings = inferenceResult.faceEmbeddings
            var faceData = inferenceResult.faceData
            let perfYunetMs = inferenceResult.yunetMs
            let perfSfaceMs = inferenceResult.sfaceMs

            perfYunetTotal += perfYunetMs
            perfSfaceTotal += perfSfaceMs
            perfFaceCount += inferenceResult.faceCount

            // 이미지/모델 로드 실패 시 빈 결과 (워커에서 nil 반환)
            if cgImage == nil {
                result[assetID] = []
                continue
            }

            // 매칭 단계에서 cosineSimilarity 사용을 위해 sface 참조
            guard let sface = SFaceRecognizer.shared else {
                result[assetID] = []
                continue
            }

            // per-photo 성능 로그 (프리로드 비교용, 진단 정보 포함)
            let degStr = degradedMs.map { String(format: "deg:%.0fms", $0) } ?? "deg:none"
            let perfLog = "photo \(shortID): Load:\(String(format: "%.0f", perfLoadMs))ms(\(degStr) gap:\(String(format: "%.0f", perfGapMs))ms) YuNet:\(String(format: "%.0f", perfYunetMs))ms SFace:\(String(format: "%.0f", perfSfaceMs))ms faces:\(faceData.count) (\(photoMeta))"
            // Logger.similarPhoto.debug("[Perf] \(perfLog)")  // 분석완료로 비활성화

            // Load 500ms 이상: SLOW 태그로 중복 출력 (검색 편의)
            if perfLoadMs >= 500 {
                Logger.similarPhoto.warning("[SLOW] \(perfLog)")
            }

            let perfMatchStart = CFAbsoluteTimeGetCurrent()

            // === Step 2: 부팅 (ActiveSlots 비어있을 때) ===
            // 부팅 시에는 저품질 포함 모든 얼굴로 슬롯 생성 (모든 인물이 슬롯 보유)
            if activeSlots.isEmpty {
                // 위치 정렬된 순서로 슬롯 생성 (YuNet 결과 기반)
                let sortedIndices = faceData.keys.sorted { idx1, idx2 in
                    guard let data1 = faceData[idx1], let data2 = faceData[idx2] else { return false }
                    let xDiff = abs(data1.boundingBox.origin.x - data2.boundingBox.origin.x)
                    if xDiff > 0.05 {
                        return data1.boundingBox.origin.x < data2.boundingBox.origin.x
                    } else {
                        return data1.boundingBox.origin.y > data2.boundingBox.origin.y
                    }
                }

                for faceIdx in sortedIndices {
                    guard activeSlots.count < maxSlots else { break }
                    guard let embedding = faceEmbeddings[faceIdx] else { continue }
                    guard let data = faceData[faceIdx] else { continue }

                    // norm 계산
                    let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })

                    let slot = PersonSlot(
                        id: nextSlotID,
                        embedding: embedding,
                        norm: norm,
                        center: data.center,
                        boundingBox: data.boundingBox
                    )
                    activeSlots.append(slot)
                    nextSlotID += 1
                }

                // 부팅 결과 저장
                var cachedFaces: [CachedFace] = []
                for slot in activeSlots {
                    cachedFaces.append(CachedFace(
                        boundingBox: slot.boundingBox,
                        personIndex: slot.id,
                        isValidSlot: false
                    ))
                }
                result[assetID] = cachedFaces
                continue
            }

            // === Step 3: 비용 산출 (코사인 유사도 → 거리 변환) ===
            var allCandidates: [MatchCandidate] = []

            // 각 얼굴의 norm 미리 계산 (결정성 보장: 키 정렬)
            var faceNorms: [Int: Float] = [:]
            for faceIdx in faceEmbeddings.keys.sorted() {
                guard let embedding = faceEmbeddings[faceIdx] else { continue }
                faceNorms[faceIdx] = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
            }

            for faceIdx in faceEmbeddings.keys.sorted() {
                guard let faceEmbedding = faceEmbeddings[faceIdx],
                      let data = faceData[faceIdx] else { continue }
                let faceNorm = faceNorms[faceIdx] ?? 0

                // 모든 슬롯과 비용 계산 (코사인 유사도를 거리로 변환: cost = 1 - similarity)
                var slotCosts: [(slot: PersonSlot, cost: Float, posDist: CGFloat)] = []

                for slot in activeSlots {
                    let similarity = sface.cosineSimilarity(faceEmbedding, slot.embedding)
                    let cost = 1.0 - similarity  // 유사도를 거리로 변환 (낮을수록 동일인)
                    let posDist = hypot(data.center.x - slot.center.x, data.center.y - slot.center.y)
                    slotCosts.append((slot: slot, cost: cost, posDist: posDist))
                }

                // Top-K 필터링: 슬롯 수 > 5개면 상위 3개만 (근사 최적화)
                // 고품질: cost 기준, 저품질: 위치 기준 (GPT 리뷰 반영)
                let candidates: ArraySlice<(slot: PersonSlot, cost: Float, posDist: CGFloat)>
                let isLowQuality = faceNorm < minEmbeddingNorm

                if activeSlots.count > 5 {
                    if isLowQuality {
                        // 저품질: 위치 기준 Top-K (가장 가까운 슬롯이 후보에 포함되도록)
                        candidates = slotCosts.sorted { $0.posDist < $1.posDist }.prefix(3)
                    } else {
                        // 고품질: cost 기준 Top-K
                        candidates = slotCosts.sorted { $0.cost < $1.cost }.prefix(3)
                    }
                } else {
                    candidates = slotCosts[...]
                }

                for item in candidates {
                    let posDistNorm = min(item.posDist / sqrt2, 1.0)
                    allCandidates.append(MatchCandidate(
                        faceIdx: faceIdx,
                        slotID: item.slot.id,
                        cost: item.cost,
                        posDistNorm: posDistNorm,
                        boundingBox: data.boundingBox,
                        center: data.center,
                        embedding: faceEmbedding,
                        norm: faceNorm,
                        slotNorm: item.slot.norm
                    ))
                }
            }

            // === Step 4: 전역 정렬 (Cost 오름차순, tie-breaker: faceIdx, slotID) ===
            // 결정성 보장: cost 동일 시 faceIdx → slotID 순으로 정렬
            allCandidates.sort {
                if $0.cost != $1.cost { return $0.cost < $1.cost }
                if $0.faceIdx != $1.faceIdx { return $0.faceIdx < $1.faceIdx }
                return $0.slotID < $1.slotID
            }

            // === Step 5: 조건부 매칭 (고품질: SFace 우선, 저품질: 위치 우선) ===
            var usedFaces: Set<Int> = []
            var usedSlots: Set<Int> = []
            var cachedFaces: [CachedFace] = []

            /// Keep Best: 매칭된 얼굴의 norm이 슬롯보다 높으면 슬롯 임베딩 갱신
            /// 위치 갱신: 모든 매칭에서 슬롯 위치를 최근 얼굴 위치로 갱신
            func updateSlotIfBetter(slotID: Int, embedding: [Float], norm: Float, center: CGPoint, boundingBox: CGRect) {
                if let idx = activeSlots.firstIndex(where: { $0.id == slotID }) {
                    // 위치 갱신 (항상 적용 - 저품질 경로 정확도 향상)
                    activeSlots[idx].center = center
                    activeSlots[idx].boundingBox = boundingBox

                    // Keep Best: norm이 더 높으면 임베딩도 갱신
                    if norm > activeSlots[idx].norm {
                        activeSlots[idx].embedding = embedding
                        activeSlots[idx].norm = norm
                    }
                }
            }

            // 저품질 위치 매칭용 상수
            let lowQualityPosLimit: CGFloat = 0.25  // 저품질은 위치 조건 완화 (25%)
            let lowQualityCostLimit: Float = min(rejectThreshold + 0.15, 1.0)  // cost 상한선 (1.0 초과 방지)

            // Step 5A: 고품질 얼굴 매칭 (SFace 우선)
            let highQualityCandidates = allCandidates.filter { $0.norm >= minEmbeddingNorm }
            let lowQualityCandidates = allCandidates.filter { $0.norm < minEmbeddingNorm }

            for candidate in highQualityCandidates {
                guard !usedFaces.contains(candidate.faceIdx) else { continue }
                guard !usedSlots.contains(candidate.slotID) else { continue }

                let cost = candidate.cost
                let posNorm = candidate.posDistNorm

                // 구간 판정
                if cost < greyZoneThreshold {
                    // 확신 구간: 즉시 매칭
                    usedFaces.insert(candidate.faceIdx)
                    usedSlots.insert(candidate.slotID)
                    cachedFaces.append(CachedFace(
                        boundingBox: candidate.boundingBox,
                        personIndex: candidate.slotID,
                        isValidSlot: false,
                        sfaceCost: cost
                    ))

                    // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ 확신: face[\(candidate.faceIdx)]→slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) norm=\(String(format: "%.1f", candidate.norm))")

                    // Keep Best + 위치 갱신
                    updateSlotIfBetter(slotID: candidate.slotID, embedding: candidate.embedding, norm: candidate.norm, center: candidate.center, boundingBox: candidate.boundingBox)

                } else if cost < rejectThreshold {
                    // 모호 구간: 위치 조건 확인
                    if posNorm < greyZonePosLimit {
                        usedFaces.insert(candidate.faceIdx)
                        usedSlots.insert(candidate.slotID)
                        cachedFaces.append(CachedFace(
                            boundingBox: candidate.boundingBox,
                            personIndex: candidate.slotID,
                            isValidSlot: false,
                            sfaceCost: cost
                        ))

                        // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ Grey: face[\(candidate.faceIdx)]→slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm)) norm=\(String(format: "%.1f", candidate.norm))")

                        // Keep Best + 위치 갱신
                        updateSlotIfBetter(slotID: candidate.slotID, embedding: candidate.embedding, norm: candidate.norm, center: candidate.center, boundingBox: candidate.boundingBox)
                    } else {
                        // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ Grey거부: face[\(candidate.faceIdx)]↛slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm))≥\(String(format: "%.2f", greyZonePosLimit)) norm=\(String(format: "%.1f", candidate.norm))")
                    }
                } else {
                    // 고품질 확장: 양쪽 norm ≥ 8.0이면 거절 임계값을 0.75로 완화
                    // (고개 돌림 등 각도 차이로 cost가 높아도 같은 인물일 가능성)
                    let bothHighQuality = candidate.norm >= highQualityNormLimit && candidate.slotNorm >= highQualityNormLimit
                    if bothHighQuality && cost < extendedRejectThreshold {
                        // 고품질 확장 Grey Zone: 위치 조건 확인
                        if posNorm < greyZonePosLimit {
                            usedFaces.insert(candidate.faceIdx)
                            usedSlots.insert(candidate.slotID)
                            cachedFaces.append(CachedFace(
                                boundingBox: candidate.boundingBox,
                                personIndex: candidate.slotID,
                                isValidSlot: false,
                                sfaceCost: cost
                            ))

                            // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ 확장Grey: face[\(candidate.faceIdx)]→slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm)) norm=\(String(format: "%.1f", candidate.norm)) slotNorm=\(String(format: "%.1f", candidate.slotNorm))")

                            updateSlotIfBetter(slotID: candidate.slotID, embedding: candidate.embedding, norm: candidate.norm, center: candidate.center, boundingBox: candidate.boundingBox)
                        } else {
                            // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ 확장Grey거부: face[\(candidate.faceIdx)]↛slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm))≥\(String(format: "%.2f", greyZonePosLimit)) norm=\(String(format: "%.1f", candidate.norm)) slotNorm=\(String(format: "%.1f", candidate.slotNorm))")
                        }
                    } else {
                        // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ 거절: face[\(candidate.faceIdx)]↛slot\(candidate.slotID) cost=\(String(format: "%.3f", cost))≥\(String(format: "%.3f", rejectThreshold)) norm=\(String(format: "%.1f", candidate.norm)) slotNorm=\(String(format: "%.1f", candidate.slotNorm))")
                    }
                }
            }

            // Step 5B: 저품질 얼굴 매칭 (위치 우선 + SFace 교차검증)
            // 혼합 점수 계산 함수 (6-1: posNorm 포화 대응)
            // w1=0.7 (cost 가중치), w2=0.3 (posNorm 가중치)
            // posNorm이 1.0으로 포화되는 경우가 많으므로 cost 가중치를 높임
            func mixedScore(cost: Float, posNorm: CGFloat) -> CGFloat {
                let w1: CGFloat = 0.7  // cost 가중치 (권장: 0.7~0.8)
                let w2: CGFloat = 0.3  // posNorm 가중치
                return w1 * CGFloat(cost) + w2 * posNorm
            }

            // 저품질 얼굴별로 그룹화하여 가장 가까운 슬롯에 매칭 시도
            var lowQualityByFace: [Int: [MatchCandidate]] = [:]
            for candidate in lowQualityCandidates {
                guard !usedFaces.contains(candidate.faceIdx) else { continue }
                lowQualityByFace[candidate.faceIdx, default: []].append(candidate)
            }

            // 결정성 보장 + 매칭 품질: mixedScore가 낮은 face부터 처리 (6-1)
            // mixedScore = 0.7*cost + 0.3*posNorm (posNorm 포화 시 cost로 변별)
            let sortedFaceIds = lowQualityByFace.keys.sorted { faceA, faceB in
                let bestA = lowQualityByFace[faceA]?
                    .filter { !usedSlots.contains($0.slotID) }
                    .min(by: { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm)
                             < mixedScore(cost: $1.cost, posNorm: $1.posDistNorm) })
                let bestB = lowQualityByFace[faceB]?
                    .filter { !usedSlots.contains($0.slotID) }
                    .min(by: { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm)
                             < mixedScore(cost: $1.cost, posNorm: $1.posDistNorm) })
                // mixedScore로 비교, 같으면 faceIdx로 tie-break (결정성)
                let scoreA = bestA.map { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm) } ?? 1.0
                let scoreB = bestB.map { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm) } ?? 1.0
                if scoreA != scoreB { return scoreA < scoreB }
                return faceA < faceB
            }

            for faceIdx in sortedFaceIds {
                guard let candidates = lowQualityByFace[faceIdx],
                      !usedFaces.contains(faceIdx) else { continue }

                // 위치 기준으로 정렬 (가장 가까운 슬롯 우선)
                let sortedByPos = candidates
                    .filter { !usedSlots.contains($0.slotID) }
                    .sorted { $0.posDistNorm < $1.posDistNorm }

                guard let bestByPos = sortedByPos.first else { continue }

                let cost = bestByPos.cost
                let posNorm = bestByPos.posDistNorm

                // 교차 검증: 위치가 가깝고(25%) SFace cost가 상한선(0.80) 이하면 매칭
                if posNorm <= lowQualityPosLimit && cost < lowQualityCostLimit {
                    usedFaces.insert(faceIdx)
                    usedSlots.insert(bestByPos.slotID)
                    cachedFaces.append(CachedFace(
                        boundingBox: bestByPos.boundingBox,
                        personIndex: bestByPos.slotID,
                        isValidSlot: false,
                        sfaceCost: cost
                    ))

                    // Logger.similarPhoto.debug("[PersonMatch] \(shortID) LQ 매칭: face[\(faceIdx)]→slot\(bestByPos.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm)) norm=\(String(format: "%.1f", bestByPos.norm))")

                    // 위치만 갱신 (저품질 임베딩으로 슬롯 임베딩 갱신 X, norm 0 전달)
                    updateSlotIfBetter(slotID: bestByPos.slotID, embedding: [], norm: 0, center: bestByPos.center, boundingBox: bestByPos.boundingBox)
                } else {
                    // Logger.similarPhoto.debug("[PersonMatch] \(shortID) LQ 거부: face[\(faceIdx)]↛slot\(bestByPos.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm)) norm=\(String(format: "%.1f", bestByPos.norm)) (limit: pos≤\(String(format: "%.2f", lowQualityPosLimit)) cost<\(String(format: "%.2f", lowQualityCostLimit)))")
                }
            }

            // === Step 6: 신규 슬롯 등록 (저품질 필터 적용) ===
            // 결정성 보장: faceIdx 정렬 순서로 처리
            for faceIdx in faceEmbeddings.keys.sorted() {
                guard let embedding = faceEmbeddings[faceIdx],
                      !usedFaces.contains(faceIdx) else { continue }
                guard activeSlots.count < maxSlots else {
                    continue
                }
                guard let data = faceData[faceIdx] else { continue }

                // norm 계산
                let norm = faceNorms[faceIdx] ?? sqrt(embedding.reduce(0) { $0 + $1 * $1 })

                // 저품질 얼굴은 신규 슬롯 생성 금지
                if norm < minEmbeddingNorm {
                    // Logger.similarPhoto.debug("[PersonMatch] \(shortID) 슬롯거부: face[\(faceIdx)] norm=\(String(format: "%.1f", norm))<\(String(format: "%.1f", self.minEmbeddingNorm))")
                    continue
                }

                // 신규 슬롯 생성
                let slot = PersonSlot(
                    id: nextSlotID,
                    embedding: embedding,
                    norm: norm,
                    center: data.center,
                    boundingBox: data.boundingBox
                )
                activeSlots.append(slot)

                usedFaces.insert(faceIdx)
                cachedFaces.append(CachedFace(
                    boundingBox: data.boundingBox,
                    personIndex: nextSlotID,
                    isValidSlot: false
                ))

                nextSlotID += 1
            }

            // === Step 7: Vision Fallback 얼굴 위치 기반 매칭 ===
            // 임베딩 없는 얼굴 (Vision fallback)은 위치만으로 기존 슬롯과 매칭 시도
            // 조건: posNorm < 0.10 (매우 엄격), 신규 슬롯 생성 안 함
            let visionFallbackPosLimit: CGFloat = 0.10

            // 결정성 보장: faceIdx 정렬 순서로 처리
            for faceIdx in faceData.keys.sorted() {
                guard let data = faceData[faceIdx] else { continue }
                // 이미 매칭된 얼굴 스킵
                guard !usedFaces.contains(faceIdx) else { continue }
                // 임베딩 있는 얼굴 스킵 (이미 위에서 처리됨)
                guard faceEmbeddings[faceIdx] == nil else { continue }

                // 가장 가까운 슬롯 찾기
                var bestSlot: (id: Int, posNorm: CGFloat)? = nil
                for slot in activeSlots {
                    guard !usedSlots.contains(slot.id) else { continue }

                    let dx = data.center.x - slot.center.x
                    let dy = data.center.y - slot.center.y
                    let posNorm = sqrt(dx * dx + dy * dy) / sqrt2

                    if posNorm < visionFallbackPosLimit {
                        if bestSlot == nil || posNorm < bestSlot!.posNorm {
                            bestSlot = (id: slot.id, posNorm: posNorm)
                        }
                    }
                }

                // 매칭 성공
                if let match = bestSlot {
                    usedFaces.insert(faceIdx)
                    usedSlots.insert(match.id)
                    cachedFaces.append(CachedFace(
                        boundingBox: data.boundingBox,
                        personIndex: match.id,
                        isValidSlot: false
                    ))
                    // 위치만 갱신 (임베딩 없으므로 norm=0)
                    updateSlotIfBetter(slotID: match.id, embedding: [], norm: 0, center: data.center, boundingBox: data.boundingBox)
                }
            }

            // === 사진별 매칭 요약 로그 ===
            let totalFaces = faceData.count
            let matchedCount = usedFaces.count
            let unmatchedFaces = faceData.keys.sorted().filter { !usedFaces.contains($0) }
            if !unmatchedFaces.isEmpty {
                let unmatchedInfo = unmatchedFaces.map { idx -> String in
                    let norm = faceNorms[idx] ?? 0
                    return "face[\(idx)](norm=\(String(format: "%.1f", norm)))"
                }.joined(separator: ", ")
                _ = unmatchedInfo  // 주석 처리된 디버그 로그에서 사용 — 로그 복원 시 제거
                // Logger.similarPhoto.debug("[PersonMatch] \(shortID): \(totalFaces)개 감지, \(matchedCount)개 매칭, 미매칭: \(unmatchedInfo)")
            }
            _ = (totalFaces, matchedCount)  // 주석 처리된 디버그 로그에서 사용 — 로그 복원 시 제거

            perfMatchTotal += (CFAbsoluteTimeGetCurrent() - perfMatchStart) * 1000

            result[assetID] = cachedFaces
        }

        // 성능 측정 요약 로그 (얼굴이 있는 그룹만 유의미)
        let perfGroupTotal = (CFAbsoluteTimeGetCurrent() - perfGroupStart) * 1000
        if perfFaceCount > 0 {
            Logger.similarPhoto.debug("[Perf] assignPerson: \(assetIDs.count)장, \(perfFaceCount)faces — Load:\(String(format: "%.0f", perfLoadTotal))ms YuNet:\(String(format: "%.0f", perfYunetTotal))ms SFace:\(String(format: "%.0f", perfSfaceTotal))ms Match:\(String(format: "%.0f", perfMatchTotal))ms Total:\(String(format: "%.0f", perfGroupTotal))ms")
        }

        return result
    }
}
