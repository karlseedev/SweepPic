// TrashStore.swift
// 앱 내 삭제대기함 상태 관리 스토어
//
// T013: TrashStoreProtocol 및 TrashStore 생성
// - trashedAssetIDs
// - moveToTrash
// - restore
// - permanentlyDelete
// - emptyTrash
// - 파일 기반 저장
//
// PRD7: 그리드 즉시 삭제/복원
// - completion handler API 추가 (실패 시 롤백 지원)

import Foundation
import Photos

// MARK: - TrashStoreError (PRD7)

/// TrashStore 에러 타입
/// completion handler API에서 실패 시 반환
public enum TrashStoreError: Error, LocalizedError {
    /// 디스크 공간 부족
    case diskSpaceFull
    /// 파일 시스템 오류
    case fileSystemError(Error)
    /// JSON 인코딩 실패
    case encodingFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .diskSpaceFull:
            return "Not enough disk space"  // 디스크 공간이 부족합니다
        case .fileSystemError(let error):
            return "Failed to save file: \(error.localizedDescription)"  // 파일 저장 실패
        case .encodingFailed(let error):
            return "Data encoding failed: \(error.localizedDescription)"  // 데이터 인코딩 실패
        }
    }
}

// MARK: - TrashStore Notification

extension Notification.Name {
    /// 삭제대기함 상태 변경 알림
    /// userInfo에 "trashedCount" (Int) 포함
    public static let trashStoreDidChange = Notification.Name("trashStoreDidChange")
}

// MARK: - TrashStoreProtocol (T013)

/// 삭제대기함 스토어 프로토콜
/// 앱 내 삭제대기함 상태 관리를 추상화
public protocol TrashStoreProtocol: AnyObject {

    /// 삭제대기함에 있는 사진 ID 집합
    var trashedAssetIDs: Set<String> { get }

    /// 삭제대기함에 있는 사진 수
    var trashedCount: Int { get }

    /// 특정 사진이 삭제대기함에 있는지 확인
    /// - Parameter assetID: 확인할 사진 ID
    /// - Returns: 삭제대기함에 있으면 true
    func isTrashed(_ assetID: String) -> Bool

    /// 사진을 삭제대기함으로 이동
    /// - Parameter assetIDs: 이동할 사진 ID 배열
    func moveToTrash(assetIDs: [String])

    /// 사진을 삭제대기함에서 복구
    /// - Parameter assetIDs: 복구할 사진 ID 배열
    func restore(assetIDs: [String])

    // MARK: - PRD7: Completion Handler API

    /// 사진을 삭제대기함으로 이동 (completion handler 버전)
    /// 제스처 기반 삭제에서 실패 시 롤백을 위해 사용
    /// - Parameters:
    ///   - assetID: 이동할 사진 ID
    ///   - completion: 완료 콜백 (메인 스레드에서 호출)
    func moveToTrash(_ assetID: String, completion: @escaping (Result<Void, TrashStoreError>) -> Void)

    /// 사진을 삭제대기함에서 복구 (completion handler 버전)
    /// 제스처 기반 복원에서 실패 시 롤백을 위해 사용
    /// - Parameters:
    ///   - assetID: 복구할 사진 ID
    ///   - completion: 완료 콜백 (메인 스레드에서 호출)
    func restore(_ assetID: String, completion: @escaping (Result<Void, TrashStoreError>) -> Void)

    /// 사진을 완전히 삭제 (iOS 삭제대기함으로 이동)
    /// - Parameter assetIDs: 삭제할 사진 ID 배열
    /// - Throws: PhotoKit 삭제 실패 시 에러
    func permanentlyDelete(assetIDs: [String]) async throws

    /// 삭제대기함 비우기 (모든 사진을 iOS 삭제대기함으로 이동)
    /// - Throws: PhotoKit 삭제 실패 시 에러
    func emptyTrash() async throws

    /// 상태 변경 시 호출될 콜백 등록
    /// - Parameter handler: 변경 발생 시 호출될 클로저
    func onStateChange(_ handler: @escaping (Set<String>) -> Void)
}

// MARK: - TrashStore (T013)

/// 파일 기반 삭제대기함 스토어 구현체
/// Documents 디렉토리에 TrashState.json으로 저장
public final class TrashStore: TrashStoreProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = TrashStore()

    // MARK: - Private Properties

    /// 현재 삭제대기함 상태
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

    /// 삭제대기함에 있는 사진 ID 집합
    public var trashedAssetIDs: Set<String> {
        state.trashedAssetIDs
    }

    /// 삭제대기함에 있는 사진 수
    public var trashedCount: Int {
        state.trashedCount
    }

    /// 특정 사진이 삭제대기함에 있는지 확인
    public func isTrashed(_ assetID: String) -> Bool {
        state.isTrashed(assetID)
    }

    /// 사진을 삭제대기함으로 이동
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

        // [BM] T055: 리뷰 요청 조건 추적 — 삭제대기함 이동 기록
        ReviewService.shared.recordTrashMove(count: assetIDs.count)
    }

    /// 사진을 삭제대기함에서 복구
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
    }

    // MARK: - PRD7: Completion Handler API

    /// 사진을 삭제대기함으로 이동 (completion handler 버전)
    /// 제스처 기반 삭제에서 실패 시 롤백을 위해 사용
    /// - Parameters:
    ///   - assetID: 이동할 사진 ID
    ///   - completion: 완료 콜백 (메인 스레드에서 호출)
    public func moveToTrash(_ assetID: String, completion: @escaping (Result<Void, TrashStoreError>) -> Void) {
        // 상태 업데이트
        state.moveToTrash(assetID)

        // 저장 (에러 반환 가능)
        saveStateWithCompletion { [weak self] result in
            switch result {
            case .success:
                self?.notifyChange()
                // [BM] T055: 리뷰 요청 조건 추적 — 삭제대기함 이동 기록
                ReviewService.shared.recordTrashMove(count: 1)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            case .failure(let error):
                // 롤백: 상태 복원
                self?.state.restore(assetID)
                // [Analytics] 삭제대기함 이동 실패
                Analytics.reporter?.reportError(key: "cleanup.trashMove")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 사진을 삭제대기함에서 복구 (completion handler 버전)
    /// 제스처 기반 복원에서 실패 시 롤백을 위해 사용
    /// - Parameters:
    ///   - assetID: 복구할 사진 ID
    ///   - completion: 완료 콜백 (메인 스레드에서 호출)
    public func restore(_ assetID: String, completion: @escaping (Result<Void, TrashStoreError>) -> Void) {
        // 상태 업데이트
        state.restore(assetID)

        // 저장 (에러 반환 가능)
        saveStateWithCompletion { [weak self] result in
            switch result {
            case .success:
                self?.notifyChange()
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            case .failure(let error):
                // 롤백: 상태 복원
                self?.state.moveToTrash(assetID)
                // [Analytics] 복구 실패
                Analytics.reporter?.reportError(key: "cleanup.trashMove")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 사진을 완전히 삭제 (iOS 삭제대기함으로 이동)
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
    }

    /// 삭제대기함 비우기
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
            } catch {
                // [Analytics] 상태 저장 실패
                Analytics.reporter?.reportError(key: "storage.trashData")
            }
        }
    }

    /// 상태 저장 (completion handler 버전)
    /// PRD7: 제스처 삭제/복원에서 실패 시 롤백을 위해 에러 반환
    private func saveStateWithCompletion(completion: @escaping (Result<Void, TrashStoreError>) -> Void) {
        saveQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                // 디스크 공간 체크 (대략적인 체크)
                let fileManager = FileManager.default
                if let attributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
                   let freeSpace = attributes[.systemFreeSize] as? Int64,
                   freeSpace < 10_000_000 { // 10MB 미만이면 공간 부족으로 판단
                    // [Analytics] 디스크 공간 부족
                    Analytics.reporter?.reportError(key: "storage.diskSpace")
                    completion(.failure(.diskSpaceFull))
                    return
                }

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(self.state)
                try data.write(to: self.trashStateURL, options: .atomic)
                completion(.success(()))
            } catch let error as EncodingError {
                // [Analytics] 인코딩 실패
                Analytics.reporter?.reportError(key: "storage.trashData")
                completion(.failure(.encodingFailed(error)))
            } catch {
                // [Analytics] 파일 시스템 오류
                Analytics.reporter?.reportError(key: "storage.trashData")
                completion(.failure(.fileSystemError(error)))
            }
        }
    }

    /// 상태 로드 (파일)
    private func loadState() {
        guard FileManager.default.fileExists(atPath: trashStateURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: trashStateURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            state = try decoder.decode(TrashState.self, from: data)
        } catch {
            // [Analytics] 상태 로드 실패
            Analytics.reporter?.reportError(key: "storage.trashData")
            state = TrashState()
        }
    }

    /// 변경 알림
    private func notifyChange() {
        let currentIDs = state.trashedAssetIDs
        let count = currentIDs.count
        DispatchQueue.main.async { [weak self] in
            self?.changeHandler?(currentIDs)
            // NotificationCenter로도 발송 (다중 관찰자 지원)
            NotificationCenter.default.post(
                name: .trashStoreDidChange,
                object: nil,
                userInfo: ["trashedCount": count]
            )
        }
    }
}
