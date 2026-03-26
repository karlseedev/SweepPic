//
//  QualitySignalTests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-01-22.
//
//  QualitySignal 모델 테스트
//  - SignalType 테스트
//  - SignalKind 테스트
//  - QualitySignal 생성 및 프로퍼티 테스트
//  - 배열 확장 테스트
//

import XCTest
@testable import SweepPic

final class QualitySignalTests: XCTestCase {

    // MARK: - SignalType Tests

    func testSignalTypeEquality() {
        // Given
        let strong1 = SignalType.strong
        let strong2 = SignalType.strong
        let weak1 = SignalType.weak(weight: 2)
        let weak2 = SignalType.weak(weight: 2)
        let weak3 = SignalType.weak(weight: 1)

        // Then
        XCTAssertEqual(strong1, strong2)
        XCTAssertEqual(weak1, weak2)
        XCTAssertNotEqual(weak1, weak3)
        XCTAssertNotEqual(strong1, weak1)
    }

    func testSignalTypeWeight() {
        // Given
        let strong = SignalType.strong
        let conditional = SignalType.conditional
        let weak = SignalType.weak(weight: 2)

        // Then
        XCTAssertEqual(strong.weight, 0)
        XCTAssertEqual(conditional.weight, 0)
        XCTAssertEqual(weak.weight, 2)
    }

    // MARK: - SignalKind Tests

    func testSignalKindStrongTypes() {
        // Given
        let strongKinds: [SignalKind] = [.extremeDark, .extremeBright, .severeBlur, .lowAesthetics]

        // Then
        for kind in strongKinds {
            XCTAssertEqual(kind.signalType, .strong, "\(kind) should be Strong")
            XCTAssertTrue(kind.isUsedInPrecision, "\(kind) should be used in Precision")
        }
    }

    func testSignalKindConditionalTypes() {
        // Given
        let conditionalKinds: [SignalKind] = [.pocketShot, .extremeMonochrome, .lensBlocked]

        // Then
        for kind in conditionalKinds {
            XCTAssertEqual(kind.signalType, .conditional, "\(kind) should be Conditional")
            XCTAssertFalse(kind.isUsedInPrecision, "\(kind) should NOT be used in Precision")
        }
    }

    func testSignalKindWeakTypes() {
        // Given
        let weakKinds: [SignalKind] = [.generalBlur, .generalExposure, .lowColorVariety, .lowResolution]

        // Then
        for kind in weakKinds {
            if case .weak = kind.signalType {
                // OK
            } else {
                XCTFail("\(kind) should be Weak")
            }
            XCTAssertFalse(kind.isUsedInPrecision, "\(kind) should NOT be used in Precision")
        }
    }

    func testGeneralBlurWeight() {
        // Given
        let kind = SignalKind.generalBlur

        // When
        let signalType = kind.signalType

        // Then
        if case .weak(let weight) = signalType {
            XCTAssertEqual(weight, CleanupConstants.generalBlurWeight)  // 2
        } else {
            XCTFail("generalBlur should be Weak")
        }
    }

    func testOtherWeakSignalWeight() {
        // Given
        let otherWeakKinds: [SignalKind] = [.generalExposure, .lowColorVariety, .lowResolution]

        // Then
        for kind in otherWeakKinds {
            if case .weak(let weight) = kind.signalType {
                XCTAssertEqual(weight, CleanupConstants.otherWeakWeight, "\(kind) should have weight 1")
            } else {
                XCTFail("\(kind) should be Weak")
            }
        }
    }

    // MARK: - QualitySignal Tests

    func testQualitySignalInitialization() {
        // Given
        let kind = SignalKind.extremeDark
        let measuredValue = 0.05
        let threshold = 0.10

        // When
        let signal = QualitySignal(kind: kind, measuredValue: measuredValue, threshold: threshold)

        // Then
        XCTAssertEqual(signal.kind, .extremeDark)
        XCTAssertEqual(signal.type, .strong)
        XCTAssertEqual(signal.measuredValue, 0.05)
        XCTAssertEqual(signal.threshold, 0.10)
    }

    func testQualitySignalDescription() {
        // Given
        let signal = QualitySignal(kind: .extremeDark, measuredValue: 0.05, threshold: 0.10)

        // When
        let description = signal.description

        // Then
        XCTAssertTrue(description.contains("Strong"))
        XCTAssertTrue(description.contains("extremeDark"))
        XCTAssertTrue(description.contains("0.050"))
        XCTAssertTrue(description.contains("0.100"))
    }

    // MARK: - Array Extension Tests

    func testHasStrongSignal() {
        // Given
        let signalsWithStrong: [QualitySignal] = [
            QualitySignal(kind: .extremeDark, measuredValue: 0.05, threshold: 0.10),
            QualitySignal(kind: .generalExposure, measuredValue: 0.12, threshold: 0.15)
        ]
        let signalsWithoutStrong: [QualitySignal] = [
            QualitySignal(kind: .generalExposure, measuredValue: 0.12, threshold: 0.15),
            QualitySignal(kind: .lowColorVariety, measuredValue: 12.0, threshold: 15.0)
        ]

        // Then
        XCTAssertTrue(signalsWithStrong.hasStrongSignal)
        XCTAssertFalse(signalsWithoutStrong.hasStrongSignal)
    }

    func testHasConditionalSignal() {
        // Given
        let signalsWithConditional: [QualitySignal] = [
            QualitySignal(kind: .pocketShot, measuredValue: 0.0, threshold: 0.0)
        ]
        let signalsWithoutConditional: [QualitySignal] = [
            QualitySignal(kind: .extremeDark, measuredValue: 0.05, threshold: 0.10)
        ]

        // Then
        XCTAssertTrue(signalsWithConditional.hasConditionalSignal)
        XCTAssertFalse(signalsWithoutConditional.hasConditionalSignal)
    }

    func testWeakWeightSum() {
        // Given
        let signals: [QualitySignal] = [
            QualitySignal(kind: .generalBlur, measuredValue: 80.0, threshold: 100.0),      // 2점
            QualitySignal(kind: .generalExposure, measuredValue: 0.12, threshold: 0.15),   // 1점
            QualitySignal(kind: .lowColorVariety, measuredValue: 12.0, threshold: 15.0)    // 1점
        ]

        // When
        let sum = signals.weakWeightSum

        // Then
        XCTAssertEqual(sum, 4)  // 2 + 1 + 1
    }

    func testHasEnoughWeakSignals() {
        // Given
        let enoughSignals: [QualitySignal] = [
            QualitySignal(kind: .generalBlur, measuredValue: 80.0, threshold: 100.0),      // 2점
            QualitySignal(kind: .generalExposure, measuredValue: 0.12, threshold: 0.15)    // 1점
        ]  // 합계 3점

        let notEnoughSignals: [QualitySignal] = [
            QualitySignal(kind: .generalExposure, measuredValue: 0.12, threshold: 0.15),   // 1점
            QualitySignal(kind: .lowColorVariety, measuredValue: 12.0, threshold: 15.0)    // 1점
        ]  // 합계 2점

        // Then
        XCTAssertTrue(enoughSignals.hasEnoughWeakSignals)
        XCTAssertFalse(notEnoughSignals.hasEnoughWeakSignals)
    }

    func testEmptyArrayHasNoSignals() {
        // Given
        let emptySignals: [QualitySignal] = []

        // Then
        XCTAssertFalse(emptySignals.hasStrongSignal)
        XCTAssertFalse(emptySignals.hasConditionalSignal)
        XCTAssertEqual(emptySignals.weakWeightSum, 0)
        XCTAssertFalse(emptySignals.hasEnoughWeakSignals)
    }

    // MARK: - Mixed Signals Tests

    func testMixedSignalsWeightSum() {
        // Given - Strong + Weak 혼합
        let signals: [QualitySignal] = [
            QualitySignal(kind: .extremeDark, measuredValue: 0.05, threshold: 0.10),       // Strong (0점)
            QualitySignal(kind: .generalBlur, measuredValue: 80.0, threshold: 100.0),      // Weak (2점)
            QualitySignal(kind: .generalExposure, measuredValue: 0.12, threshold: 0.15)    // Weak (1점)
        ]

        // When
        let sum = signals.weakWeightSum

        // Then
        XCTAssertEqual(sum, 3)  // Strong은 포함 안 됨
    }
}
