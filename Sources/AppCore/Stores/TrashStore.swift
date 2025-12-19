// TrashStore.swift
// 앱 내 휴지통 상태 관리 스토어
//
// T013: TrashStoreProtocol 및 TrashStore 생성
// - trashedAssetIDs
// - moveToTrash
// - restore
// - permanentlyDelete
// - emptyTrash
// - 파일 기반 저장

import Foundation
import Photos

// MARK: - TrashStoreProtocol (T013)

/// 휴지통 스토어 프로토콜
/// 앱 내 휴지통 상태 관리를 추상화
public protocol TrashStoreProtocol: AnyObject {

    /// 휴지통에 있는 사진 ID 집합
    var trashedAssetIDs: Set<String> { get }

    /// 휴지통에 있는 사진 수
    var trashedCount: Int { get }

    /// 특정 사진이 휴지통에 있는지 확인
    /// - Parameter assetID: 확인할 사진 ID
    /// - Returns: 휴지통에 있으면 true
    func isTrashed(_ assetID: String) -> Bool

    /// 사진을 휴지통으로 이동
    /// - Parameter assetIDs: 이동할 사진 ID 배열
    func moveToTrash(assetIDs: [String])

    /// 사진을 휴지통에서 복구
    /// - Parameter assetIDs: 복구할 사진 ID 배열
    func restore(assetIDs: [String])

    /// 사진을 완전히 삭제 (iOS 휴지통으로 이동)
    /// - Parameter assetIDs: 삭제할 사진 ID 배열
    /// - Throws: PhotoKit 삭제 실패 시 에러
    func permanentlyDelete(assetIDs: [String]) async throws

    /// 휴지통 비우기 (모든 사진을 iOS 휴지통으로 이동)
    /// - Throws: PhotoKit 삭제 실패 시 에러
    func emptyTrash() async throws

    /// 상태 변경 시 호출될 콜백 등록
    /// - Parameter handler: 변경 발생 시 호출될 클로저
    func onStateChange(_ handler: @escaping (Set<String>) -> Void)
}

// MARK: - TrashStore (T013)

/// 파일 기반 휴지통 스토어 구현체
/// Documents 디렉토리에 TrashState.json으로 저장
public final class TrashStore: TrashStoreProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = TrashStore()

    // MARK: - Private Properties

    /// 현재 휴지통 상태
    private var state: TrashState

    /// 상태 변경 핸들러
    private var changeHandler: ((Set<String>) -> Void)?

    /// 파일 저장 경로
    private var trashStateURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TrashState.json")
    }

    /// 저장 동기화를 위한 큐
    private let saveQueue = DispatchQueue(label: "com.pickphoto.trashstore.save")

    // MARK: - Initialization

    /// 비공개 초기화 (싱글톤)
    private init() {
        self.state = TrashState()
        loadState()
    }

    // MARK: - TrashStoreProtocol

    /// 휴지통에 있는 사진 ID 집합
    public var trashedAssetIDs: Set<String> {
        state.trashedAssetIDs
    }

    /// 휴지통에 있는 사진 수
    public var trashedCount: Int {
        state.trashedCount
    }

    /// 특정 사진이 휴지통에 있는지 확인
    public func isTrashed(_ assetID: String) -> Bool {
        state.isTrashed(assetID)
    }

    /// 사진을 휴지통으로 이동
    /// FR-022: 상태 변경 행동마다 즉시 저장
    public func moveToTrash(assetIDs: [String]) {
        guard !assetIDs.isEmpty else { return }

        for assetID in assetIDs {
            state.moveToTrash(assetID)
        }

        // 즉시 저장
        saveState()

        // 변경 알림
        notifyChange()

        print("[TrashStore] Moved to trash: \(assetIDs.count) items")
    }

    /// 사진을 휴지통에서 복구
    /// FR-022: 상태 변경 행동마다 즉시 저장
    public func restore(assetIDs: [String]) {
        guard !assetIDs.isEmpty else { return }

        for assetID in assetIDs {
            state.restore(assetID)
        }

        // 즉시 저장
        saveState()

        // 변경 알림
        notifyChange()

        print("[TrashStore] Restored: \(assetIDs.count) items")
    }

    /// 사진을 완전히 삭제 (iOS 휴지통으로 이동)
    /// iOS 시스템 팝업이 표시됨
    public func permanentlyDelete(assetIDs: [String]) async throws {
        guard !assetIDs.isEmpty else { return }

        // PHAsset 가져오기
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIDs,
            options: nil
        )

        guard fetchResult.count > 0 else {
            // 이미 삭제된 경우, 상태에서만 제거
            for assetID in assetIDs {
                state.permanentlyDelete(assetID)
            }
            saveState()
            notifyChange()
            return
        }

        // PhotoKit으로 삭제 요청 (시스템 팝업 표시)
        try await PHPhotoLibrary.shared().performChanges {
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }

        // 성공 시 상태에서 제거
        for assetID in assetIDs {
            state.permanentlyDelete(assetID)
        }

        // 저장
        saveState()

        // 변경 알림
        notifyChange()

        print("[TrashStore] Permanently deleted: \(assetIDs.count) items")
    }

    /// 휴지통 비우기
    /// iOS 시스템 팝업이 표시됨
    public func emptyTrash() async throws {
        let assetIDs = Array(state.trashedAssetIDs)
        guard !assetIDs.isEmpty else { return }

        try await permanentlyDelete(assetIDs: assetIDs)
    }

    /// 상태 변경 콜백 등록
    public func onStateChange(_ handler: @escaping (Set<String>) -> Void) {
        self.changeHandler = handler
    }

    // MARK: - T060: 외부 삭제 처리

    /// PhotoKit에 존재하지 않는 ID 정리
    /// PHAsset이 외부에서 삭제된 경우 TrashState에서 자동 제거
    /// - Parameter validAssetIDs: 현재 PhotoKit에 존재하는 ID 집합
    public func removeInvalidAssets(validAssetIDs: Set<String>) {
        let beforeCount = state.trashedCount
        state.removeInvalidAssets(validAssetIDs: validAssetIDs)
        let afterCount = state.trashedCount

        if beforeCount != afterCount {
            saveState()
            notifyChange()
            print("[TrashStore] Removed \(beforeCount - afterCount) invalid assets")
        }
    }

    // MARK: - Private Methods

    /// 상태 저장 (파일)
    private func saveState() {
        saveQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(self.state)
                try data.write(to: self.trashStateURL, options: .atomic)
                print("[TrashStore] State saved (\(self.state.trashedCount) items)")
            } catch {
                print("[TrashStore] Failed to save state: \(error)")
            }
        }
    }

    /// 상태 로드 (파일)
    private func loadState() {
        guard FileManager.default.fileExists(atPath: trashStateURL.path) else {
            print("[TrashStore] No saved state found, using empty state")
            return
        }

        do {
            let data = try Data(contentsOf: trashStateURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            state = try decoder.decode(TrashState.self, from: data)
            print("[TrashStore] State loaded (\(state.trashedCount) items)")
        } catch {
            print("[TrashStore] Failed to load state: \(error)")
            state = TrashState()
        }
    }

    /// 변경 알림
    private func notifyChange() {
        let currentIDs = state.trashedAssetIDs
        DispatchQueue.main.async { [weak self] in
            self?.changeHandler?(currentIDs)
        }
    }
}
