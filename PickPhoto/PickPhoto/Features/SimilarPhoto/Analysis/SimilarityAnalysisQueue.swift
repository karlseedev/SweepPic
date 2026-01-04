// SimilarityAnalysisQueue.swift
// 분석 큐 및 동시성 관리
//
// T009: SimilarityAnalysisQueue 생성
// - FIFO 큐, 동시 5개 (과열 시 2개), 취소 처리
//
// T014: 백그라운드 전환 시 분석 취소
//
// T064: 분석 타임아웃 3초 구현

import Foundation
import UIKit

/// 유사도 분석 큐
/// 분석 요청을 FIFO 순서로 처리하고 동시 실행 수 제한
final class SimilarityAnalysisQueue {

    // MARK: - Constants

    /// 정상 상태 동시 분석 수
    static let normalConcurrency = 5

    /// 과열 상태 동시 분석 수
    static let thermalConcurrency = 2

    /// 분석 타임아웃 (초)
    static let analysisTimeout: TimeInterval = 3.0

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = SimilarityAnalysisQueue()

    // MARK: - Properties

    /// 대기 중인 요청 큐 (FIFO)
    private var pendingRequests: [AnalysisRequest] = []

    /// 진행 중인 요청 (assetID -> AnalysisRequest)
    private var activeRequests: [String: AnalysisRequest] = [:]

    /// 타임아웃 타이머 (assetID -> Timer)
    private var timeoutTimers: [String: Timer] = [:]

    /// 큐 접근 동기화용 락
    private let queueLock = NSLock()

    /// 현재 동시 분석 제한
    private var currentConcurrency: Int {
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .serious, .critical:
            return Self.thermalConcurrency
        default:
            return Self.normalConcurrency
        }
    }

    /// 분석 완료 콜백 (assetID -> callbacks)
    private var completionHandlers: [String: [(SimilarityAnalysisState) -> Void]] = [:]

    /// 분석 실행자 (외부에서 주입)
    var analyzeHandler: ((AnalysisRequest, @escaping (SimilarityAnalysisState) -> Void) -> Void)?

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    // MARK: - Setup

    /// 옵저버 설정
    private func setupObservers() {
        // 과열 상태 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )

        // 백그라운드 전환 감지 (T014)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // 포그라운드 복귀 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    // MARK: - Public Methods

    /// 분석 요청 추가
    /// - Parameters:
    ///   - request: 분석 요청
    ///   - completion: 완료 콜백
    func enqueue(request: AnalysisRequest, completion: @escaping (SimilarityAnalysisState) -> Void) {
        queueLock.lock()
        defer { queueLock.unlock() }

        // 이미 진행 중이면 콜백만 추가
        if activeRequests[request.assetID] != nil {
            addCompletionHandler(for: request.assetID, handler: completion)
            return
        }

        // 이미 대기 중이면 콜백만 추가
        if pendingRequests.contains(where: { $0.assetID == request.assetID }) {
            addCompletionHandler(for: request.assetID, handler: completion)
            return
        }

        // 콜백 등록
        addCompletionHandler(for: request.assetID, handler: completion)

        // 큐에 추가
        pendingRequests.append(request)

        // 처리 시도
        processNextIfNeeded()
    }

    /// 배치 분석 요청 추가
    /// - Parameters:
    ///   - requests: 분석 요청 배열
    ///   - completion: 개별 완료 콜백 (assetID, 상태)
    func enqueueBatch(
        requests: [AnalysisRequest],
        completion: @escaping (String, SimilarityAnalysisState) -> Void
    ) {
        for request in requests {
            enqueue(request: request) { state in
                completion(request.assetID, state)
            }
        }
    }

    /// 그리드 소스 요청 취소 (스크롤 재개 시)
    func cancelGridRequests() {
        queueLock.lock()
        defer { queueLock.unlock() }

        // 대기 중인 grid 요청 제거
        pendingRequests.removeAll { $0.source == .grid }

        // 진행 중인 grid 요청 취소 표시
        for (assetID, var request) in activeRequests {
            if request.source == .grid {
                request.cancel()
                activeRequests[assetID] = request
            }
        }
    }

    /// 특정 에셋 분석 취소
    func cancelRequest(for assetID: String) {
        queueLock.lock()
        defer { queueLock.unlock() }

        // 대기 큐에서 제거
        pendingRequests.removeAll { $0.assetID == assetID }

        // 진행 중인 요청 취소
        if var request = activeRequests[assetID], request.isCancellable {
            request.cancel()
            activeRequests[assetID] = request
        }

        // 타임아웃 타이머 정리
        timeoutTimers[assetID]?.invalidate()
        timeoutTimers.removeValue(forKey: assetID)
    }

    /// 모든 요청 취소
    func cancelAllRequests() {
        queueLock.lock()
        defer { queueLock.unlock() }

        pendingRequests.removeAll()
        activeRequests.removeAll()
        completionHandlers.removeAll()

        // 모든 타이머 정리
        for timer in timeoutTimers.values {
            timer.invalidate()
        }
        timeoutTimers.removeAll()
    }

    /// 큐 상태 정보 (디버그용)
    var debugStatus: String {
        queueLock.lock()
        defer { queueLock.unlock() }

        return "[Queue] pending=\(pendingRequests.count), active=\(activeRequests.count), concurrency=\(currentConcurrency)"
    }

    // MARK: - Private Methods

    /// 다음 요청 처리
    private func processNextIfNeeded() {
        // 이미 락 상태에서 호출됨
        while activeRequests.count < currentConcurrency,
              let request = pendingRequests.first {
            pendingRequests.removeFirst()

            // 취소된 요청은 스킵
            if request.isCancelled {
                notifyCompletion(for: request.assetID, state: .notAnalyzed)
                continue
            }

            // 활성 요청에 추가
            activeRequests[request.assetID] = request

            // 타임아웃 타이머 시작 (T064)
            startTimeoutTimer(for: request)

            // 분석 실행 (락 해제 후)
            let assetID = request.assetID
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.executeAnalysis(request: request)
            }
        }
    }

    /// 분석 실행
    private func executeAnalysis(request: AnalysisRequest) {
        guard let handler = analyzeHandler else {
            finishRequest(assetID: request.assetID, state: .notAnalyzed)
            return
        }

        handler(request) { [weak self] state in
            self?.finishRequest(assetID: request.assetID, state: state)
        }
    }

    /// 요청 완료 처리
    private func finishRequest(assetID: String, state: SimilarityAnalysisState) {
        queueLock.lock()

        // 활성 요청에서 제거
        activeRequests.removeValue(forKey: assetID)

        // 타임아웃 타이머 정리
        timeoutTimers[assetID]?.invalidate()
        timeoutTimers.removeValue(forKey: assetID)

        queueLock.unlock()

        // 콜백 호출
        notifyCompletion(for: assetID, state: state)

        // 다음 요청 처리
        queueLock.lock()
        processNextIfNeeded()
        queueLock.unlock()
    }

    /// 타임아웃 타이머 시작
    private func startTimeoutTimer(for request: AnalysisRequest) {
        let timer = Timer.scheduledTimer(withTimeInterval: Self.analysisTimeout, repeats: false) { [weak self] _ in
            self?.handleTimeout(assetID: request.assetID)
        }
        timeoutTimers[request.assetID] = timer
    }

    /// 타임아웃 처리
    private func handleTimeout(assetID: String) {
        print("[SimilarityAnalysisQueue] Timeout for asset: \(assetID.prefix(8))...")
        finishRequest(assetID: assetID, state: .notAnalyzed)
    }

    /// 콜백 핸들러 추가
    private func addCompletionHandler(for assetID: String, handler: @escaping (SimilarityAnalysisState) -> Void) {
        if completionHandlers[assetID] == nil {
            completionHandlers[assetID] = []
        }
        completionHandlers[assetID]?.append(handler)
    }

    /// 완료 알림
    private func notifyCompletion(for assetID: String, state: SimilarityAnalysisState) {
        queueLock.lock()
        let handlers = completionHandlers.removeValue(forKey: assetID) ?? []
        queueLock.unlock()

        DispatchQueue.main.async {
            for handler in handlers {
                handler(state)
            }
        }
    }

    // MARK: - Observers

    /// 과열 상태 변경 처리
    @objc private func thermalStateDidChange() {
        let state = ProcessInfo.processInfo.thermalState
        print("[SimilarityAnalysisQueue] Thermal state changed: \(state.rawValue), concurrency: \(currentConcurrency)")
    }

    /// 백그라운드 전환 처리 (T014)
    @objc private func appDidEnterBackground() {
        print("[SimilarityAnalysisQueue] App entered background - cancelling all requests")
        cancelAllRequests()
    }

    /// 포그라운드 복귀 처리
    @objc private func appWillEnterForeground() {
        print("[SimilarityAnalysisQueue] App will enter foreground")
        // 재분석은 수행하지 않음 (스크롤 멈춤 시 자동 트리거)
    }
}
