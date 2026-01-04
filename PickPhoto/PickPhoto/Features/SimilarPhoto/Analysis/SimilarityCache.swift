// SimilarityCache.swift
// 분석 결과 캐시 관리
//
// T012: SimilarityCache 생성
// - LRU 500장, 상태 관리, 완료 콜백
//
// T013: 메모리 경고 시 캐시 50% LRU 제거
//
// T015: PHPhotoLibraryChangeObserver 연동 - 캐시 무효화
//
// T048: 그룹 멤버 3장 미만 시 그룹 무효화

import Foundation
import UIKit
import Photos

/// 유사도 분석 결과 캐시
/// 분석 상태, 얼굴 정보, 그룹 정보를 메모리에 캐싱
final class SimilarityCache {

    // MARK: - Constants

    /// 최대 캐시 크기 (사진 수)
    static let maxCacheSize = 500

    /// 메모리 경고 시 제거 비율
    static let memoryWarningEvictionRatio = 0.5

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = SimilarityCache()

    // MARK: - Properties

    /// 사진별 분석 상태
    private var states: [String: SimilarityAnalysisState] = [:]

    /// 그룹 관리 (groupID -> SimilarThumbnailGroup)
    private var groups: [String: SimilarThumbnailGroup] = [:]

    /// 사진별 얼굴 캐시 (assetID -> [CachedFace])
    private var assetFaces: [String: [CachedFace]] = [:]

    /// LRU 추적 (최근 접근 순서, 뒤가 최신)
    private var accessOrder: [String] = []

    /// 분석 완료 콜백
    private var completionHandlers: [String: [(SimilarityAnalysisState) -> Void]] = [:]

    /// 캐시 접근 동기화용 락
    private let cacheLock = NSLock()

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    // MARK: - Setup

    /// 옵저버 설정
    private func setupObservers() {
        // 메모리 경고 감지 (T013)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - State Management

    /// 분석 상태 조회
    /// - Parameter assetID: 사진 ID
    /// - Returns: 분석 상태 (없으면 .notAnalyzed)
    func getState(for assetID: String) -> SimilarityAnalysisState {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        updateAccessOrder(for: assetID)
        return states[assetID] ?? .notAnalyzed
    }

    /// 분석 상태 설정
    /// - Parameters:
    ///   - state: 새 상태
    ///   - assetID: 사진 ID
    func setState(_ state: SimilarityAnalysisState, for assetID: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        states[assetID] = state
        updateAccessOrder(for: assetID)

        // 캐시 크기 확인
        evictIfNeeded()

        // 완료 콜백 호출 (분석 완료 시)
        if state.isAnalyzed {
            let handlers = completionHandlers.removeValue(forKey: assetID) ?? []
            cacheLock.unlock()
            for handler in handlers {
                handler(state)
            }
            cacheLock.lock()
        }
    }

    /// 분석 완료 콜백 등록
    /// - Parameters:
    ///   - assetID: 사진 ID
    ///   - handler: 완료 시 호출될 핸들러
    func onAnalysisComplete(for assetID: String, handler: @escaping (SimilarityAnalysisState) -> Void) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        // 이미 분석 완료 상태면 즉시 호출
        if let state = states[assetID], state.isAnalyzed {
            cacheLock.unlock()
            handler(state)
            cacheLock.lock()
            return
        }

        // 콜백 등록
        if completionHandlers[assetID] == nil {
            completionHandlers[assetID] = []
        }
        completionHandlers[assetID]?.append(handler)
    }

    // MARK: - Face Cache

    /// 얼굴 정보 저장
    func setFaces(_ faces: [CachedFace], for assetID: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        assetFaces[assetID] = faces
        updateAccessOrder(for: assetID)
    }

    /// 얼굴 정보 조회
    func getFaces(for assetID: String) -> [CachedFace]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        updateAccessOrder(for: assetID)
        return assetFaces[assetID]
    }

    /// 유효 슬롯 얼굴만 조회 (+ 버튼 표시 대상)
    func getValidSlotFaces(for assetID: String) -> [CachedFace] {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        updateAccessOrder(for: assetID)
        return assetFaces[assetID]?.filter { $0.isValidSlot } ?? []
    }

    // MARK: - Group Management

    /// 그룹 추가
    func addGroup(_ group: SimilarThumbnailGroup) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        groups[group.id] = group

        // 멤버 사진의 상태 업데이트
        for assetID in group.memberAssetIDs {
            states[assetID] = .analyzed(inGroup: true, groupID: group.id)
            updateAccessOrder(for: assetID)
        }
    }

    /// 그룹 조회
    func getGroup(by groupID: String) -> SimilarThumbnailGroup? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return groups[groupID]
    }

    /// 사진이 속한 그룹 조회
    func getGroup(for assetID: String) -> SimilarThumbnailGroup? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let state = states[assetID],
              let groupID = state.groupID else {
            return nil
        }

        return groups[groupID]
    }

    /// 그룹에서 멤버 제거 및 무효화 확인 (T048)
    /// - Parameters:
    ///   - assetID: 제거할 사진 ID
    ///   - groupID: 그룹 ID
    /// - Returns: 그룹이 무효화되었는지 여부
    @discardableResult
    func removeMemberFromGroup(assetID: String, groupID: String) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard var group = groups[groupID] else { return false }

        // 멤버 제거
        group.removeMember(assetID)
        states[assetID] = .analyzed(inGroup: false, groupID: nil)

        // 3장 미만 시 그룹 무효화
        if group.memberCount < 3 {
            invalidateGroupUnsafe(group)
            return true
        }

        groups[groupID] = group
        return false
    }

    /// 그룹 무효화 (락 없이)
    private func invalidateGroupUnsafe(_ group: SimilarThumbnailGroup) {
        // 모든 멤버의 상태 업데이트
        for assetID in group.memberAssetIDs {
            states[assetID] = .analyzed(inGroup: false, groupID: nil)
        }

        // 그룹 제거
        groups.removeValue(forKey: group.id)
    }

    /// 그룹 무효화
    func invalidateGroup(groupID: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let group = groups[groupID] else { return }
        invalidateGroupUnsafe(group)
    }

    // MARK: - Cache Eviction

    /// LRU 접근 순서 업데이트
    private func updateAccessOrder(for assetID: String) {
        if let index = accessOrder.firstIndex(of: assetID) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(assetID)
    }

    /// 캐시 크기 확인 및 eviction
    private func evictIfNeeded() {
        while accessOrder.count > Self.maxCacheSize {
            guard let oldestID = accessOrder.first else { break }

            // 분석 중인 사진은 eviction 대상에서 제외
            if let state = states[oldestID], state.isAnalyzing {
                // 대신 두 번째로 오래된 것 제거
                if accessOrder.count > 1 {
                    accessOrder.removeFirst()
                    accessOrder.insert(oldestID, at: 0)
                    continue
                }
                break
            }

            evictAsset(oldestID)
        }
    }

    /// 특정 사진 캐시 제거
    private func evictAsset(_ assetID: String) {
        accessOrder.removeAll { $0 == assetID }
        states.removeValue(forKey: assetID)
        assetFaces.removeValue(forKey: assetID)
        completionHandlers.removeValue(forKey: assetID)

        // 그룹에서도 제거
        for (_, group) in groups {
            if group.contains(assetID) {
                // 그룹 무효화 체크는 removeMemberFromGroup에서 처리
            }
        }
    }

    /// 메모리 경고 시 LRU 50% 제거 (T013)
    @objc private func didReceiveMemoryWarning() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        let targetCount = Int(Double(accessOrder.count) * Self.memoryWarningEvictionRatio)
        var evicted = 0

        while accessOrder.count > 0 && evicted < targetCount {
            guard let oldestID = accessOrder.first else { break }

            // 분석 중인 것은 스킵
            if let state = states[oldestID], state.isAnalyzing {
                accessOrder.removeFirst()
                accessOrder.append(oldestID) // 뒤로 이동
                continue
            }

            evictAsset(oldestID)
            evicted += 1
        }

        print("[SimilarityCache] Memory warning: evicted \(evicted) items, remaining: \(accessOrder.count)")
    }

    // MARK: - Library Change (T015)

    /// PHPhotoLibrary 변경 시 캐시 무효화
    /// - Parameter changedAssetIDs: 변경된 사진 ID 배열
    func invalidateOnLibraryChange(changedAssetIDs: [String]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        for assetID in changedAssetIDs {
            // 해당 사진 캐시 제거
            evictAsset(assetID)

            // 그룹에서도 제거 및 무효화 확인
            for (groupID, group) in groups {
                if group.contains(assetID) {
                    var mutableGroup = group
                    mutableGroup.removeMember(assetID)

                    if mutableGroup.memberCount < 3 {
                        invalidateGroupUnsafe(mutableGroup)
                    } else {
                        groups[groupID] = mutableGroup
                    }
                }
            }
        }

        print("[SimilarityCache] Invalidated \(changedAssetIDs.count) items on library change")
    }

    // MARK: - Debug

    /// 캐시 상태 정보 (디버그용)
    var debugStatus: String {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        let analyzing = states.values.filter { $0.isAnalyzing }.count
        let inGroup = states.values.filter { $0.isInGroup }.count

        return "[Cache] total=\(accessOrder.count), analyzing=\(analyzing), inGroup=\(inGroup), groups=\(groups.count)"
    }

    /// 캐시 전체 정리
    func clearAll() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        states.removeAll()
        groups.removeAll()
        assetFaces.removeAll()
        accessOrder.removeAll()
        completionHandlers.removeAll()

        print("[SimilarityCache] Cleared all cache")
    }
}
