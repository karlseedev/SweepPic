//
//  S2DebugAnalyzer.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-16.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  S2(over-merge) 원인 분석을 위한 디버그 로그 출력 클래스입니다.
//  결정성 수정 전/후 비교를 위해 GPT 제안 9개 로그를 출력합니다.
//

import Foundation
import Photos
import CoreGraphics

/// S2 원인 분석용 디버그 로그 출력 클래스
final class S2DebugAnalyzer {

    // MARK: - Singleton

    static let shared = S2DebugAnalyzer()
    private init() {}

    // MARK: - Types

    /// 디버그용 슬롯 구조
    private struct DebugSlot {
        var id: Int
        var embedding: [Float]
        var norm: Float
        var center: CGPoint
        var boundingBox: CGRect
    }

    /// 디버그용 후보 구조
    private struct DebugCandidate {
        let faceIdx: Int
        let slotID: Int
        let cost: Float
        let posDistNorm: CGFloat
        let norm: Float
        let center: CGPoint
        let boundingBox: CGRect
        let uiLabel: String
    }

    // MARK: - Configuration

    /// 분석 설정
    struct Config {
        let greyZoneThreshold: Float = 0.45
        let rejectThreshold: Float = 0.637
        let greyZonePosLimit: CGFloat = 0.20
        let minEmbeddingNorm: Float = 7.0
        let lowQualityPosLimit: CGFloat = 0.25
        var lowQualityCostLimit: Float { min(rejectThreshold + 0.15, 1.0) }
        let topKCount: Int = 3
        let topKThreshold: Int = 5  // 슬롯 수 > 5개면 Top-K 적용
        let tieGroupThreshold: Float = 0.001  // GPT 권장: 0.01 → 0.001

        /// 설정값 출력
        func printConfig() {
            print("  [Config] greyZoneThreshold=\(greyZoneThreshold), rejectThreshold=\(rejectThreshold)")
            print("  [Config] greyZonePosLimit=\(greyZonePosLimit), minEmbeddingNorm=\(minEmbeddingNorm)")
            print("  [Config] lowQualityPosLimit=\(lowQualityPosLimit), lowQualityCostLimit=\(String(format: "%.3f", lowQualityCostLimit))")
            print("  [Config] topK=\(topKCount) (when slots > \(topKThreshold)), tieGroupThreshold=\(tieGroupThreshold)")
        }
    }

    // MARK: - Public Methods

    /// S2 원인 분석 실행
    /// GPT 제안 9개 로그를 모두 출력합니다.
    /// - Parameter photos: 분석할 사진 배열
    func runAnalysis(with photos: [PHAsset]) async {
        let imageLoader = SimilarityImageLoader.shared
        guard let yunet = YuNetFaceDetector.shared,
              let sface = SFaceRecognizer.shared else {
            print("[S2Debug] Required components not available")
            return
        }
        let aligner = FaceAligner.shared

        let config = Config()
        let sqrt2: CGFloat = sqrt(2.0)

        var activeSlots: [DebugSlot] = []
        var nextSlotID = 1

        // 헤더 출력
        printHeader()
        config.printConfig()

        print("")
        print("═══════════════════════════════════════════════════════════════════")
        print("  Total Photos: \(photos.count)")
        print("═══════════════════════════════════════════════════════════════════")

        for (photoIndex, photo) in photos.enumerated() {
            let shortID = String(photo.localIdentifier.prefix(8))
            print("")
            print("┌─────────────────────────────────────────────────────────────────┐")
            print("│ Photo \(photoIndex + 1)/\(photos.count): \(shortID)")
            print("└─────────────────────────────────────────────────────────────────┘")

            // 이미지 로드
            guard let image = try? await imageLoader.loadImage(for: photo) else {
                print("  [Skip] Failed to load image")
                continue
            }

            // YuNet 감지
            guard let yunetFaces = try? yunet.detect(in: image), !yunetFaces.isEmpty else {
                print("  [Skip] No faces detected")
                continue
            }

            // ═══════════════════════════════════════════════════════════════════
            // LOG 2: 슬롯 스냅샷 (사진 시작 전)
            // ═══════════════════════════════════════════════════════════════════
            printLog2_SlotSnapshot(activeSlots)

            // 얼굴 데이터 수집
            var faceData: [(idx: Int, center: CGPoint, bbox: CGRect, uiLabel: String)] = []
            var faceEmbeddings: [Int: [Float]] = [:]
            var faceNorms: [Int: Float] = [:]

            for (idx, face) in yunetFaces.enumerated() {
                let center = CGPoint(
                    x: face.boundingBox.midX,
                    y: face.boundingBox.midY
                )
                let uiLabel = "\(shortID)_F\(idx)"
                faceData.append((idx: idx, center: center, bbox: face.boundingBox, uiLabel: uiLabel))

                // 임베딩 추출
                if let aligned = try? aligner.align(image: image, landmarks: face.landmarks),
                   let embedding = try? sface.extractEmbedding(from: aligned) {
                    faceEmbeddings[idx] = embedding
                    let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
                    faceNorms[idx] = norm
                }
            }

            // ═══════════════════════════════════════════════════════════════════
            // LOG 1: 얼굴 처리 순서 (원본 + sorted)
            // ═══════════════════════════════════════════════════════════════════
            printLog1_FaceProcessingOrder(faceEmbeddings: faceEmbeddings, faceData: faceData, faceNorms: faceNorms)

            let sortedFaceIndices = faceEmbeddings.keys.sorted()

            // ═══════════════════════════════════════════════════════════════════
            // LOG 3: 후보 리스트 (얼굴별) - Top-K 전/후
            // ═══════════════════════════════════════════════════════════════════
            var allCandidates: [DebugCandidate] = []

            for faceIdx in sortedFaceIndices {
                guard let embedding = faceEmbeddings[faceIdx],
                      let data = faceData.first(where: { $0.idx == faceIdx }) else { continue }
                let faceNorm = faceNorms[faceIdx] ?? 0

                // 모든 슬롯과의 후보 계산 (Top-K 전)
                var allSlotCandidates: [(slotID: Int, cost: Float, posNorm: CGFloat, slotNorm: Float)] = []

                for slot in activeSlots {
                    let similarity = sface.cosineSimilarity(embedding, slot.embedding)
                    let cost = 1.0 - similarity
                    let posDist = hypot(data.center.x - slot.center.x, data.center.y - slot.center.y)
                    let posNorm = min(posDist / sqrt2, 1.0)
                    allSlotCandidates.append((slotID: slot.id, cost: cost, posNorm: posNorm, slotNorm: slot.norm))
                }

                // LOG 3: Top-K 전/후 출력
                printLog3_Candidates(
                    faceIdx: faceIdx,
                    uiLabel: data.uiLabel,
                    faceNorm: faceNorm,
                    allSlotCandidates: allSlotCandidates,
                    activeSlotCount: activeSlots.count,
                    config: config
                )

                // Top-K 필터링
                let isLowQuality = faceNorm < config.minEmbeddingNorm
                let filteredCandidates: [(slotID: Int, cost: Float, posNorm: CGFloat, slotNorm: Float)]

                if activeSlots.count > config.topKThreshold {
                    if isLowQuality {
                        filteredCandidates = Array(allSlotCandidates.sorted { $0.posNorm < $1.posNorm }.prefix(config.topKCount))
                    } else {
                        filteredCandidates = Array(allSlotCandidates.sorted { $0.cost < $1.cost }.prefix(config.topKCount))
                    }
                } else {
                    filteredCandidates = allSlotCandidates
                }

                // allCandidates에 추가
                for item in filteredCandidates {
                    allCandidates.append(DebugCandidate(
                        faceIdx: faceIdx,
                        slotID: item.slotID,
                        cost: item.cost,
                        posDistNorm: item.posNorm,
                        norm: faceNorm,
                        center: data.center,
                        boundingBox: data.bbox,
                        uiLabel: data.uiLabel
                    ))
                }
            }

            // ═══════════════════════════════════════════════════════════════════
            // LOG 4: 전역 정렬 결과
            // ═══════════════════════════════════════════════════════════════════
            allCandidates.sort { $0.cost < $1.cost }
            printLog4_GlobalSortedCandidates(allCandidates)

            // ═══════════════════════════════════════════════════════════════════
            // LOG 5: 동점 그룹 (cost 차이 < 0.001)
            // ═══════════════════════════════════════════════════════════════════
            printLog5_TieGroups(allCandidates, threshold: config.tieGroupThreshold)

            // ═══════════════════════════════════════════════════════════════════
            // LOG 6, 7, 8: 매칭 단계 (HighQ, LowQ, NewSlot)
            // ═══════════════════════════════════════════════════════════════════
            var usedFaces: Set<Int> = []
            var usedSlots: Set<Int> = []
            var matchResults: [(faceIdx: Int, slotID: Int, uiLabel: String)] = []

            // LOG 6: 고품질 매칭
            let highQCandidates = allCandidates.filter { $0.norm >= config.minEmbeddingNorm }
            let lowQCandidates = allCandidates.filter { $0.norm < config.minEmbeddingNorm }

            print("")
            print("  [LOG 6] HighQ Matching Steps:")

            for candidate in highQCandidates {
                guard !usedFaces.contains(candidate.faceIdx) else {
                    print("    [Skip] Face(\(candidate.faceIdx)) already used")
                    continue
                }
                guard !usedSlots.contains(candidate.slotID) else {
                    print("    [Skip] Slot(\(candidate.slotID)) already used for Face(\(candidate.faceIdx))")
                    continue
                }

                if candidate.cost < config.greyZoneThreshold {
                    usedFaces.insert(candidate.faceIdx)
                    usedSlots.insert(candidate.slotID)
                    matchResults.append((candidate.faceIdx, candidate.slotID, candidate.uiLabel))
                    print("    [Confident] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): cost=\(String(format: "%.3f", candidate.cost))")
                } else if candidate.cost < config.rejectThreshold {
                    if candidate.posDistNorm < config.greyZonePosLimit {
                        usedFaces.insert(candidate.faceIdx)
                        usedSlots.insert(candidate.slotID)
                        matchResults.append((candidate.faceIdx, candidate.slotID, candidate.uiLabel))
                        print("    [GreyZone] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): cost=\(String(format: "%.3f", candidate.cost)), posNorm=\(String(format: "%.2f", candidate.posDistNorm))")
                    } else {
                        print("    [GreyReject] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): cost=\(String(format: "%.3f", candidate.cost)), posNorm=\(String(format: "%.2f", candidate.posDistNorm)) (pos >= \(config.greyZonePosLimit))")
                    }
                } else {
                    print("    [Reject] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): cost=\(String(format: "%.3f", candidate.cost)) (>= threshold \(config.rejectThreshold))")
                }
            }

            // LOG 7: LowQ 매칭
            var lowQByFace: [Int: [DebugCandidate]] = [:]
            for c in lowQCandidates {
                guard !usedFaces.contains(c.faceIdx) else { continue }
                lowQByFace[c.faceIdx, default: []].append(c)
            }

            print("")
            print("  [LOG 7] LowQ Candidates (sorted by position):")

            if lowQByFace.isEmpty {
                print("    (no lowQ candidates)")
            }

            for faceIdx in lowQByFace.keys.sorted() {
                guard let candidates = lowQByFace[faceIdx] else { continue }
                let sortedByPos = candidates
                    .filter { !usedSlots.contains($0.slotID) }
                    .sorted { $0.posDistNorm < $1.posDistNorm }

                if let data = faceData.first(where: { $0.idx == faceIdx }) {
                    print("    Face(\(faceIdx)) - \(data.uiLabel):")
                }

                // 전체 리스트 출력 (GPT 권장)
                for (rank, c) in sortedByPos.enumerated() {
                    print("      [\(rank)] Slot(\(c.slotID)): posNorm=\(String(format: "%.3f", c.posDistNorm)), cost=\(String(format: "%.3f", c.cost))")
                }

                if let best = sortedByPos.first {
                    if best.posDistNorm <= config.lowQualityPosLimit && best.cost < config.lowQualityCostLimit {
                        usedFaces.insert(faceIdx)
                        usedSlots.insert(best.slotID)
                        matchResults.append((faceIdx, best.slotID, best.uiLabel))
                        print("    [LowQMatch] Face(\(faceIdx)) -> Slot(\(best.slotID))")
                    } else {
                        print("    [LowQReject] Face(\(faceIdx)): posNorm=\(String(format: "%.3f", best.posDistNorm)) (limit=\(config.lowQualityPosLimit)) or cost=\(String(format: "%.3f", best.cost)) (limit=\(String(format: "%.3f", config.lowQualityCostLimit)))")
                    }
                }
            }

            // LOG 8: NewSlot 생성
            print("")
            print("  [LOG 8] NewSlot Creation:")

            var newSlotCreated = false
            for faceIdx in sortedFaceIndices {
                guard !usedFaces.contains(faceIdx) else { continue }
                guard let embedding = faceEmbeddings[faceIdx],
                      let data = faceData.first(where: { $0.idx == faceIdx }) else { continue }

                let norm = faceNorms[faceIdx] ?? 0

                if norm < config.minEmbeddingNorm {
                    print("    [LowQuality] Face(\(faceIdx)): norm=\(String(format: "%.2f", norm)) < \(config.minEmbeddingNorm), skip new slot")
                    continue
                }

                // 기존 슬롯과의 최소 cost
                var minCost: Float = Float.infinity
                var minCostSlotID: Int = -1
                for slot in activeSlots {
                    let cost = 1.0 - sface.cosineSimilarity(embedding, slot.embedding)
                    if cost < minCost {
                        minCost = cost
                        minCostSlotID = slot.id
                    }
                }

                let newSlot = DebugSlot(
                    id: nextSlotID,
                    embedding: embedding,
                    norm: norm,
                    center: data.center,
                    boundingBox: data.bbox
                )
                activeSlots.append(newSlot)
                usedFaces.insert(faceIdx)
                matchResults.append((faceIdx, nextSlotID, data.uiLabel))
                newSlotCreated = true

                if minCostSlotID > 0 {
                    print("    [NewSlot] Face(\(faceIdx)) -> Slot(\(nextSlotID)): norm=\(String(format: "%.2f", norm)), minCost=\(String(format: "%.3f", minCost)) to Slot(\(minCostSlotID)) (threshold=\(config.rejectThreshold))")
                } else {
                    print("    [NewSlot] Face(\(faceIdx)) -> Slot(\(nextSlotID)): Bootstrap")
                }
                nextSlotID += 1
            }

            if !newSlotCreated {
                print("    (no new slots created)")
            }

            // ═══════════════════════════════════════════════════════════════════
            // LOG 9: 종결 로그 (uiLabel -> slotID)
            // ═══════════════════════════════════════════════════════════════════
            printLog9_FinalMapping(matchResults, faceData: faceData)

            // 슬롯 위치 갱신 (Keep Best 로직)
            for result in matchResults {
                if let embedding = faceEmbeddings[result.faceIdx],
                   let norm = faceNorms[result.faceIdx],
                   let data = faceData.first(where: { $0.idx == result.faceIdx }),
                   let slotIdx = activeSlots.firstIndex(where: { $0.id == result.slotID }) {
                    activeSlots[slotIdx].center = data.center
                    activeSlots[slotIdx].boundingBox = data.bbox
                    if norm > activeSlots[slotIdx].norm {
                        activeSlots[slotIdx].embedding = embedding
                        activeSlots[slotIdx].norm = norm
                    }
                }
            }
        }

        // 최종 요약
        printFinalSummary(activeSlots)
    }

    // MARK: - Private Methods - Log Printers

    private func printHeader() {
        print("")
        print("╔══════════════════════════════════════════════════════════════════╗")
        print("║           S2 CAUSE ANALYSIS - 9 Debug Logs                       ║")
        print("║           (GPT Recommendations Applied)                          ║")
        print("╚══════════════════════════════════════════════════════════════════╝")
    }

    private func printLog2_SlotSnapshot(_ slots: [DebugSlot]) {
        print("")
        print("  [LOG 2] Slot Snapshot (before this photo):")
        if slots.isEmpty {
            print("    (empty - first photo)")
        } else {
            for slot in slots {
                print("    Slot(\(slot.id)): center=(\(String(format: "%.3f", slot.center.x)), \(String(format: "%.3f", slot.center.y))), norm=\(String(format: "%.2f", slot.norm)), bbox=(\(String(format: "%.3f", slot.boundingBox.origin.x)), \(String(format: "%.3f", slot.boundingBox.origin.y)), \(String(format: "%.3f", slot.boundingBox.width))×\(String(format: "%.3f", slot.boundingBox.height)))")
            }
        }
    }

    private func printLog1_FaceProcessingOrder(
        faceEmbeddings: [Int: [Float]],
        faceData: [(idx: Int, center: CGPoint, bbox: CGRect, uiLabel: String)],
        faceNorms: [Int: Float]
    ) {
        print("")
        print("  [LOG 1] Face Processing Order:")

        // 원본 순서 (Dictionary 순회 순서) - 롤백 상태 비교용
        let originalOrder = Array(faceEmbeddings.keys)
        print("    [Original Dict Order]: \(originalOrder)")

        // sorted 순서 (결정성 버전)
        let sortedOrder = faceEmbeddings.keys.sorted()
        print("    [Sorted Order]: \(sortedOrder)")

        // 상세 정보
        for faceIdx in sortedOrder {
            if let data = faceData.first(where: { $0.idx == faceIdx }) {
                let norm = faceNorms[faceIdx] ?? 0
                print("    faceIdx=\(faceIdx), uiLabel=\(data.uiLabel), center=(\(String(format: "%.3f", data.center.x)), \(String(format: "%.3f", data.center.y))), bbox=(\(String(format: "%.3f", data.bbox.width))×\(String(format: "%.3f", data.bbox.height))), norm=\(String(format: "%.2f", norm))")
            }
        }
    }

    private func printLog3_Candidates(
        faceIdx: Int,
        uiLabel: String,
        faceNorm: Float,
        allSlotCandidates: [(slotID: Int, cost: Float, posNorm: CGFloat, slotNorm: Float)],
        activeSlotCount: Int,
        config: Config
    ) {
        print("")
        print("  [LOG 3] Candidates for Face(\(faceIdx)) - \(uiLabel) (norm=\(String(format: "%.2f", faceNorm))):")

        if allSlotCandidates.isEmpty {
            print("    (no slots yet)")
            return
        }

        // Top-K 전 (전체)
        print("    [Before Top-K] (\(allSlotCandidates.count) candidates):")
        for c in allSlotCandidates {
            print("      -> Slot(\(c.slotID)): cost=\(String(format: "%.3f", c.cost)), posNorm=\(String(format: "%.3f", c.posNorm)), slotNorm=\(String(format: "%.2f", c.slotNorm))")
        }

        // Top-K 적용 여부
        if activeSlotCount > config.topKThreshold {
            let isLowQuality = faceNorm < config.minEmbeddingNorm
            let sortedCandidates: [(slotID: Int, cost: Float, posNorm: CGFloat, slotNorm: Float)]
            let sortBy: String

            if isLowQuality {
                sortedCandidates = allSlotCandidates.sorted { $0.posNorm < $1.posNorm }
                sortBy = "posNorm (LowQ)"
            } else {
                sortedCandidates = allSlotCandidates.sorted { $0.cost < $1.cost }
                sortBy = "cost (HighQ)"
            }

            let topK = Array(sortedCandidates.prefix(config.topKCount))
            print("    [After Top-K] (sorted by \(sortBy), top \(config.topKCount)):")
            for c in topK {
                print("      -> Slot(\(c.slotID)): cost=\(String(format: "%.3f", c.cost)), posNorm=\(String(format: "%.3f", c.posNorm))")
            }
        } else {
            print("    [After Top-K] (slots <= \(config.topKThreshold), no filtering)")
        }
    }

    private func printLog4_GlobalSortedCandidates(_ candidates: [DebugCandidate]) {
        print("")
        print("  [LOG 4] Global Sorted Candidates (by cost):")
        if candidates.isEmpty {
            print("    (no candidates)")
            return
        }
        for (rank, c) in candidates.enumerated() {
            print("    rank=\(rank), faceIdx=\(c.faceIdx), slotID=\(c.slotID), cost=\(String(format: "%.3f", c.cost)), posNorm=\(String(format: "%.3f", c.posDistNorm)), norm=\(String(format: "%.2f", c.norm)), uiLabel=\(c.uiLabel)")
        }
    }

    private func printLog5_TieGroups(_ candidates: [DebugCandidate], threshold: Float) {
        print("")
        print("  [LOG 5] Tie Groups (cost diff < \(threshold)):")

        var tieGroups: [[DebugCandidate]] = []
        var currentGroup: [DebugCandidate] = []

        for candidate in candidates {
            if currentGroup.isEmpty {
                currentGroup.append(candidate)
            } else if abs(candidate.cost - currentGroup[0].cost) < threshold {
                currentGroup.append(candidate)
            } else {
                if currentGroup.count > 1 {
                    tieGroups.append(currentGroup)
                }
                currentGroup = [candidate]
            }
        }
        if currentGroup.count > 1 {
            tieGroups.append(currentGroup)
        }

        if tieGroups.isEmpty {
            print("    (no tie groups)")
        } else {
            for (groupIdx, group) in tieGroups.enumerated() {
                print("    TieGroup \(groupIdx + 1) (cost ≈ \(String(format: "%.4f", group[0].cost))):")
                for c in group {
                    print("      faceIdx=\(c.faceIdx), slotID=\(c.slotID), uiLabel=\(c.uiLabel), cost=\(String(format: "%.4f", c.cost))")
                }
            }
        }
    }

    private func printLog9_FinalMapping(
        _ results: [(faceIdx: Int, slotID: Int, uiLabel: String)],
        faceData: [(idx: Int, center: CGPoint, bbox: CGRect, uiLabel: String)]
    ) {
        print("")
        print("  [LOG 9] Final Mapping (uiLabel -> slotID):")
        for result in results {
            if let data = faceData.first(where: { $0.idx == result.faceIdx }) {
                print("    \(result.uiLabel) -> Slot(\(result.slotID)) | center=(\(String(format: "%.3f", data.center.x)), \(String(format: "%.3f", data.center.y))), bbox=(\(String(format: "%.3f", data.bbox.width))×\(String(format: "%.3f", data.bbox.height)))")
            } else {
                print("    \(result.uiLabel) -> Slot(\(result.slotID))")
            }
        }
    }

    private func printFinalSummary(_ slots: [DebugSlot]) {
        print("")
        print("═══════════════════════════════════════════════════════════════════")
        print("  FINAL SUMMARY")
        print("═══════════════════════════════════════════════════════════════════")
        print("  Total Slots: \(slots.count)")
        for slot in slots {
            print("    Slot(\(slot.id)): norm=\(String(format: "%.2f", slot.norm)), center=(\(String(format: "%.3f", slot.center.x)), \(String(format: "%.3f", slot.center.y)))")
        }
    }
}
