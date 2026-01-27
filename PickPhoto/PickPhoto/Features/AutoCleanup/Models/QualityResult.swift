//
//  QualityResult.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  개별 사진 품질 분석 결과 정의
//  - QualityVerdict: 최종 판정 (lowQuality/acceptable/skipped)
//  - SkipReason: 분석 건너뜀 사유
//  - SafeGuardReason: Safe Guard 적용 사유
//  - AnalysisMethod: 분석 방법 (AestheticsScore vs Metal)
//  - QualityResult: 분석 결과 데이터
//

import Foundation

// MARK: - QualityVerdict

/// 품질 판정 결과
///
/// 개별 사진에 대한 최종 품질 판정.
enum QualityVerdict: Equatable {

    /// 저품질
    /// - 휴지통 이동 대상
    /// - Strong 신호 감지 또는 Weak 합산 >= 3
    case lowQuality

    /// 정상
    /// - 휴지통 이동하지 않음
    /// - 저품질 신호 없음 또는 Safe Guard 적용
    case acceptable

    /// 분석 건너뜀
    /// - 다양한 사유로 분석 수행하지 않음
    /// - associated value: 건너뜀 사유
    case skipped(reason: SkipReason)

    /// 저품질 또는 acceptable인지 확인 (skipped 제외)
    var isAnalyzed: Bool {
        if case .skipped = self {
            return false
        }
        return true
    }

    /// 저품질인지 확인
    var isLowQuality: Bool {
        return self == .lowQuality
    }
}

// MARK: - SkipReason

/// 분석 건너뜀 사유
///
/// 사진 분석을 수행하지 않은 이유.
/// Stage 1 메타데이터 필터 또는 기타 제외 조건.
enum SkipReason: String, Codable, CaseIterable {

    /// 즐겨찾기
    /// - Safe Guard 조기 필터
    case favorite

    /// 편집됨
    /// - Safe Guard 조기 필터
    case edited

    /// 숨김
    /// - Safe Guard 조기 필터
    case hidden

    /// 공유 앨범
    /// - Safe Guard 조기 필터
    /// - 판별: sourceType == .typeCloudShared
    case sharedAlbum

    /// 스크린샷
    /// - 1차 범위 외 (별도 기능으로 추후 개발)
    /// - 판별: mediaSubtypes.contains(.photoScreenshot)
    case screenshot

    /// iCloud 전용
    /// - 로컬 캐시 썸네일 없음
    /// - networkAccessAllowed = false로 요청 시 이미지 없음
    case iCloudOnly

    /// 분석 실패
    /// - Vision/Metal API 에러
    /// - 원칙: 판단 불가 시 삭제 금지 (SKIP)
    case analysisError

    /// 5초 초과 비디오
    /// - 5초 초과 비디오는 의도적 촬영으로 간주하여 분석 제외
    /// - duration > 5초
    case longVideo

    /// isUtility (iOS 18+)
    /// - AestheticsScore의 isUtility == true
    /// - 스크린샷과 동일 취급
    case utilityImage

    /// 텍스트 스크린샷
    /// - Vision 텍스트 감지로 텍스트가 많이 검출된 이미지
    /// - 블로그 캡쳐, 문서 스크린샷 등
    case textScreenshot

    /// 흰 배경 이미지
    /// - 모서리가 순백색(>0.99)이고 중앙보다 밝은 패턴
    /// - 일러스트, 문서, 상품 사진 등
    case whiteBackground
}

// MARK: - SafeGuardReason

/// Safe Guard 적용 사유
///
/// 블러 판정이 무효화된 이유.
/// Stage 4 Safe Guard에서 적용.
enum SafeGuardReason: String, Codable, CaseIterable {

    /// 심도 효과
    /// - Portrait 모드 등 의도적 배경 흐림
    /// - 판별: PHAsset에 depthData 존재
    case depthEffect

    /// 선명한 얼굴
    /// - 얼굴 품질 >= 0.4
    /// - 판별: VNDetectFaceCaptureQualityRequest
    case clearFace
}

// MARK: - AnalysisMethod

/// 분석 방법
///
/// 품질 분석에 사용된 파이프라인.
enum AnalysisMethod: String, Codable, CaseIterable {

    /// iOS 18+ AestheticsScore
    /// - CalculateImageAestheticsScoresRequest 사용
    case aestheticsScore

    /// Metal 파이프라인
    /// - iOS 16-17 기본 파이프라인
    /// - Luminance + Laplacian Variance
    case metalPipeline

    /// Fallback
    /// - iOS 18+에서 AestheticsScore 실패 후 Metal 사용
    case fallback
}

// MARK: - QualityResult

/// 사진 품질 분석 결과
///
/// 개별 사진에 대한 분석 결과 데이터.
/// 디버깅/로깅을 위해 상세 정보 포함.
struct QualityResult: Equatable {

    /// 사진 ID (PHAsset.localIdentifier)
    let assetID: String

    /// 사진 생성일 (이어서 정리용)
    /// - 50장 제한 도달 시 마지막 사진의 날짜를 저장하기 위해 필요
    let creationDate: Date?

    /// 최종 판정
    let verdict: QualityVerdict

    /// 감지된 신호 목록
    /// - 저품질 판정에 기여한 신호들
    let signals: [QualitySignal]

    /// Safe Guard 적용 여부
    /// - true: 블러 판정이 무효화됨
    let safeGuardApplied: Bool

    /// Safe Guard 사유
    /// - safeGuardApplied == true인 경우에만 값 존재
    let safeGuardReason: SafeGuardReason?

    /// 분석 소요 시간 (밀리초)
    let analysisTimeMs: Double

    /// 분석 방법
    let analysisMethod: AnalysisMethod

    // MARK: - Convenience Initializers

    /// 저품질 결과 생성
    static func lowQuality(
        assetID: String,
        creationDate: Date?,
        signals: [QualitySignal],
        analysisTimeMs: Double,
        method: AnalysisMethod
    ) -> QualityResult {
        return QualityResult(
            assetID: assetID,
            creationDate: creationDate,
            verdict: .lowQuality,
            signals: signals,
            safeGuardApplied: false,
            safeGuardReason: nil,
            analysisTimeMs: analysisTimeMs,
            analysisMethod: method
        )
    }

    /// 정상 결과 생성
    static func acceptable(
        assetID: String,
        creationDate: Date?,
        signals: [QualitySignal] = [],
        analysisTimeMs: Double,
        method: AnalysisMethod
    ) -> QualityResult {
        return QualityResult(
            assetID: assetID,
            creationDate: creationDate,
            verdict: .acceptable,
            signals: signals,
            safeGuardApplied: false,
            safeGuardReason: nil,
            analysisTimeMs: analysisTimeMs,
            analysisMethod: method
        )
    }

    /// Safe Guard 적용 결과 생성
    static func safeGuarded(
        assetID: String,
        creationDate: Date?,
        signals: [QualitySignal],
        reason: SafeGuardReason,
        analysisTimeMs: Double,
        method: AnalysisMethod
    ) -> QualityResult {
        return QualityResult(
            assetID: assetID,
            creationDate: creationDate,
            verdict: .acceptable,
            signals: signals,
            safeGuardApplied: true,
            safeGuardReason: reason,
            analysisTimeMs: analysisTimeMs,
            analysisMethod: method
        )
    }

    /// 건너뜀 결과 생성
    static func skipped(
        assetID: String,
        creationDate: Date?,
        reason: SkipReason
    ) -> QualityResult {
        return QualityResult(
            assetID: assetID,
            creationDate: creationDate,
            verdict: .skipped(reason: reason),
            signals: [],
            safeGuardApplied: false,
            safeGuardReason: nil,
            analysisTimeMs: 0,
            analysisMethod: .metalPipeline  // 분석 안 함
        )
    }
}

// MARK: - CustomStringConvertible

extension QualityResult: CustomStringConvertible {

    /// 디버그/로깅용 문자열 표현
    var description: String {
        let verdictStr: String
        switch verdict {
        case .lowQuality:
            verdictStr = "LOW_QUALITY"
        case .acceptable:
            verdictStr = safeGuardApplied ? "ACCEPTABLE (SafeGuard)" : "ACCEPTABLE"
        case .skipped(let reason):
            verdictStr = "SKIPPED (\(reason.rawValue))"
        }

        var parts = ["[\(verdictStr)]", "Asset: \(assetID.prefix(8))..."]

        if !signals.isEmpty {
            let signalKinds = signals.map { $0.kind.rawValue }.joined(separator: ", ")
            parts.append("Signals: [\(signalKinds)]")
        }

        if safeGuardApplied, let reason = safeGuardReason {
            parts.append("SafeGuard: \(reason.rawValue)")
        }

        parts.append("Time: \(String(format: "%.1f", analysisTimeMs))ms")
        parts.append("Method: \(analysisMethod.rawValue)")

        return parts.joined(separator: " | ")
    }
}
