//
//  AsyncSemaphore.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  Swift Concurrency 환경에서 동시성을 제한하기 위한 세마포어입니다.
//  Actor 기반으로 thread-safe하게 구현되어 있습니다.
//
//  Usage:
//  let semaphore = AsyncSemaphore(value: 5)  // 동시에 5개까지 허용
//  await semaphore.wait()  // 슬롯 획득 대기
//  defer { semaphore.signal() }  // 작업 완료 후 슬롯 반환
//  // ... 작업 수행
//

import Foundation

/// Swift Concurrency 환경에서 동시성을 제한하기 위한 세마포어
///
/// 전통적인 DispatchSemaphore는 async 컨텍스트에서 사용하면
/// 데드락이 발생할 수 있어서, continuation 기반으로 재구현했습니다.
///
/// - Note: Actor 기반이므로 thread-safe합니다.
actor AsyncSemaphore {

    // MARK: - Properties

    /// 현재 사용 가능한 슬롯 수
    private var count: Int

    /// 슬롯을 대기 중인 continuation 큐
    /// - FIFO 순서로 처리됨
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    // MARK: - Initialization

    /// 세마포어를 초기화합니다.
    ///
    /// - Parameter value: 초기 동시 실행 가능 수
    ///   - 양수: 해당 수만큼 동시 실행 가능
    ///   - 0: 모든 wait() 호출이 대기 상태로 시작
    ///
    /// - Precondition: value >= 0
    init(value: Int) {
        precondition(value >= 0, "Semaphore value must be non-negative")
        self.count = value
    }

    // MARK: - Public Methods

    /// 슬롯을 획득할 때까지 대기합니다.
    ///
    /// 사용 가능한 슬롯이 있으면 즉시 반환되고,
    /// 없으면 슬롯이 반환될 때까지 suspend됩니다.
    ///
    /// - Important: 반드시 작업 완료 후 `signal()`을 호출해야 합니다.
    ///   `defer`를 사용하면 예외 상황에서도 안전합니다.
    ///
    /// ```swift
    /// await semaphore.wait()
    /// defer { semaphore.signal() }
    /// // 작업 수행
    /// ```
    func wait() async {
        // 슬롯이 있으면 즉시 획득
        if count > 0 {
            count -= 1
            return
        }

        // 슬롯이 없으면 대기 큐에 추가하고 suspend
        await withCheckedContinuation { continuation in
            waitQueue.append(continuation)
        }
    }

    /// 슬롯을 반환합니다.
    ///
    /// 대기 중인 작업이 있으면 해당 작업을 재개하고,
    /// 없으면 사용 가능한 슬롯 수를 증가시킵니다.
    ///
    /// - Note: wait() 호출 횟수와 signal() 호출 횟수가 일치해야 합니다.
    nonisolated func signal() {
        Task {
            await self.signalInternal()
        }
    }

    /// 현재 사용 가능한 슬롯 수를 반환합니다.
    /// - Note: 테스트 및 디버깅 용도
    var availableCount: Int {
        count
    }

    /// 현재 대기 중인 작업 수를 반환합니다.
    /// - Note: 테스트 및 디버깅 용도
    var waitingCount: Int {
        waitQueue.count
    }

    // MARK: - Private Methods

    /// 슬롯 반환 내부 구현
    private func signalInternal() {
        // 대기 중인 작업이 있으면 재개
        if let continuation = waitQueue.first {
            waitQueue.removeFirst()
            continuation.resume()
        } else {
            // 대기 중인 작업이 없으면 카운트 증가
            count += 1
        }
    }
}

// MARK: - Convenience Extensions

extension AsyncSemaphore {
    /// 슬롯을 획득하고 클로저를 실행한 후 자동으로 반환합니다.
    ///
    /// - Parameter operation: 슬롯을 획득한 상태에서 실행할 작업
    /// - Returns: 작업의 반환값
    /// - Throws: 작업에서 발생한 에러
    ///
    /// ```swift
    /// let result = try await semaphore.withPermit {
    ///     return try await someAsyncOperation()
    /// }
    /// ```
    func withPermit<T>(_ operation: () async throws -> T) async rethrows -> T {
        await wait()
        defer { signal() }
        return try await operation()
    }

    /// 슬롯을 획득하고 non-throwing 클로저를 실행한 후 자동으로 반환합니다.
    ///
    /// - Parameter operation: 슬롯을 획득한 상태에서 실행할 작업
    /// - Returns: 작업의 반환값
    func withPermit<T>(_ operation: () async -> T) async -> T {
        await wait()
        defer { signal() }
        return await operation()
    }
}
