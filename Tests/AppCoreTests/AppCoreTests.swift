// AppCoreTests.swift
// AppCore 패키지의 단위 테스트

import XCTest
@testable import AppCore

/// AppCore 기본 테스트
final class AppCoreTests: XCTestCase {

    /// 버전 정보가 올바르게 설정되어 있는지 확인
    func testVersion() {
        XCTAssertEqual(AppCore.version, "1.0.0")
        XCTAssertEqual(AppCore.minimumIOSVersion, "16.0")
    }
}
