//
//  CleanupConstants.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  저품질 사진 자동 정리 기능에서 사용하는 상수 정의
//  - 종료 조건: 최대 찾기 수 50장, 최대 검색 수 1,000장
//  - 성능: 배치 크기 100장, 동시 분석 4개
//  - 임계값: 휘도, Laplacian, RGB Std, 얼굴 품질 등
//  - iOS 버전별 분기: AestheticsScore vs Metal 파이프라인
//

import CoreGraphics

/// 정리 관련 상수
///
/// 모든 상수는 설계 문서(docs/autodel/260120AutoDel.md, research.md) 기반.
/// 임계값은 "설계값"으로 정의되어 있으며, 실제 테스트를 통해 검증/조정 필요.
enum CleanupConstants {

    // MARK: - 종료 조건

    /// 최대 찾기 수
    /// - 50장을 찾으면 탐색 즉시 중단
    static let maxFoundCount = 50

    /// 최대 검색 수
    /// - 1,000장을 검색하면 탐색 종료
    static let maxScanCount = 1000

    // MARK: - 성능

    /// 배치 크기
    /// - 한 번에 로드할 PHAsset 수
    static let batchSize = 100

    /// 동시 분석 수
    /// - TaskGroup 동시성 제한
    static let concurrentAnalysis = 4

    /// 노출 분석 다운샘플 크기
    /// - 64×64 픽셀로 다운샘플하여 휘도/RGB Std 분석
    static let exposureAnalysisSize = CGSize(width: 64, height: 64)

    /// 블러 분석 다운샘플 크기
    /// - 256×256 픽셀로 다운샘플하여 Laplacian Variance 분석
    static let blurAnalysisSize = CGSize(width: 256, height: 256)

    /// 분석 타임아웃 (초)
    /// - 개별 사진 분석이 이 시간을 초과하면 SKIP 처리
    static let analysisTimeout: TimeInterval = 5.0

    // MARK: - 임계값 (Precision 모드)

    /// 극단 어두움 휘도 임계값
    /// - 휘도 < 0.10 → Strong 신호 (즉시 저품질)
    /// - 근거: GitHub Gist 0.133 기준의 엄격 버전
    static let extremeDarkLuminance: Double = 0.10

    /// 극단 밝음 휘도 임계값
    /// - 휘도 > 0.90 → Strong 신호 (즉시 저품질)
    /// - 근거: GitHub Gist
    static let extremeBrightLuminance: Double = 0.90

    /// 심각 블러 Laplacian 임계값
    /// - Laplacian Variance < 50 → Strong 신호 (Safe Guard 체크 필요)
    /// - 근거: PyImageSearch 100의 50% (설계값)
    static let severeBlurLaplacian: Double = 50

    /// 일반 블러 Laplacian 임계값
    /// - Laplacian Variance < 100 → Weak 신호 (Recall 모드)
    /// - 근거: PyImageSearch
    static let generalBlurLaplacian: Double = 100

    /// 극단 단색 RGB 표준편차 임계값
    /// - RGB Std < 10 → Conditional 신호 (Recall 모드, 휘도 조건 충족 시)
    static let extremeMonochromeRgbStd: Double = 10

    /// 낮은 색상 다양성 RGB 표준편차 임계값
    /// - RGB Std < 15 → Weak 신호 (Recall 모드)
    static let lowColorVarietyRgbStd: Double = 15

    /// 일반 어두움 휘도 임계값 (Recall 모드)
    /// - 휘도 < 0.15 → Weak 신호
    static let generalDarkLuminance: Double = 0.15

    /// 일반 밝음 휘도 임계값 (Recall 모드)
    /// - 휘도 > 0.85 → Weak 신호
    static let generalBrightLuminance: Double = 0.85

    /// 얼굴 품질 임계값
    /// - Face Quality >= 0.4 → 블러 판정 무효화 (Safe Guard)
    /// - 주의: Apple은 상대 비교 권장, 본 기능은 절대 임계값 사용 (테스트 검증 필요)
    static let faceQualityThreshold: Float = 0.4

    /// 비네팅 임계값 (주머니 샷)
    /// - 비네팅 < 0.05 → 주머니 샷 복합 조건의 일부
    /// - 비네팅 = (모서리 평균 휘도 - 중앙 휘도) / 중앙 휘도
    static let pocketShotVignetting: Double = 0.05

    /// 렌즈 가림 비율 임계값
    /// - 모서리 휘도 < 중앙 휘도 × 0.4 → Conditional 신호 (Recall 모드)
    static let lensBlockedRatio: Double = 0.4

    /// 저해상도 기준 (픽셀 수)
    /// - < 1,000,000 픽셀 (1MP) → Weak 신호
    static let lowResolutionPixelCount = 1_000_000

    /// 분석 대상 비디오 최대 길이 (초)
    /// - 5초 이하: 프레임 3개 추출하여 분석
    /// - 5초 초과: SKIP (의도적 촬영으로 간주)
    /// - 근거: 주머니샷 등 실수 촬영은 짧은 영상에서만 발생
    static let maxAnalyzableVideoDuration: Double = 5.0

    // MARK: - iOS 18+ AestheticsScore

    /// AestheticsScore Precision 모드 임계값
    /// - overallScore < -0.3 → 저품질
    /// - 주의: Apple 공식 권장 아닌 설계값 (테스트 검증 필요)
    static let aestheticsPrecisionThreshold: Float = -0.3

    /// AestheticsScore Recall 모드 임계값
    /// - overallScore < 0 → 저품질
    static let aestheticsRecallThreshold: Float = 0.0

    // MARK: - Weak 가중치 (Recall 모드)

    /// 일반 블러 가중치
    /// - Laplacian < 100 → 2점
    static let generalBlurWeight = 2

    /// 기타 Weak 신호 가중치
    /// - 일반 노출, 낮은 색상 다양성, 저해상도 → 각 1점
    static let otherWeakWeight = 1

    /// Weak 합산 임계값
    /// - 가중치 합산 >= 3 → 저품질
    static let weakSumThreshold = 3

    // MARK: - 파일 경로

    /// 세션 저장 파일명
    static let sessionFileName = "CleanupSession.json"

    // MARK: - UI 메시지

    /// 휴지통 비어있지 않음 메시지
    static let trashNotEmptyMessage = "휴지통을 먼저 비워주세요"

    /// 결과 메시지 생성
    ///
    /// EndReason과 발견 수, 정리 방식에 따라 적절한 메시지 반환
    ///
    /// - Parameters:
    ///   - endReason: 종료 사유
    ///   - foundCount: 발견된 저품질 사진 수
    ///   - method: 정리 방식 (연도별인 경우 연도 표시용)
    /// - Returns: 사용자에게 표시할 결과 메시지
    static func resultMessage(
        endReason: EndReason,
        foundCount: Int,
        method: CleanupMethod
    ) -> String {
        switch (endReason, foundCount) {
        // 1. 50장 발견
        case (.maxFound, _):
            return "50장의 정리할 사진을 찾았습니다.\n더 찾으려면 '이어서 정리'를 사용하세요."

        // 2. 1,000장 검색 + N장 발견
        case (.maxScanned, let n) where n > 0:
            return "1,000장을 검색하여 \(n)장을 찾았습니다.\n더 찾으려면 '이어서 정리'를 사용하세요."

        // 3. 1,000장 검색 + 0장 발견
        case (.maxScanned, 0):
            return "1,000장을 검색했지만 정리할 사진이 없습니다.\n더 검색하려면 '이어서 정리'를 사용하세요."

        // 4, 5. 범위 끝 + N장 발견
        case (.endOfRange, let n) where n > 0:
            if case .byYear(let year, _) = method {
                return "\(year)년의 마지막 사진까지 검색하여 \(n)장을 찾았습니다."
            } else {
                return "보관함의 마지막 사진까지 검색하여 \(n)장을 찾았습니다."
            }

        // 6, 7. 범위 끝 + 0장 발견
        case (.endOfRange, 0):
            if case .byYear(let year, _) = method {
                return "\(year)년의 마지막 사진까지 검색했지만 정리할 사진이 없습니다."
            } else {
                return "보관함의 마지막 사진까지 검색했지만 정리할 사진이 없습니다."
            }

        // 취소 (메시지 없음)
        case (.userCancelled, _):
            return ""

        default:
            return ""
        }
    }
}

// MARK: - Debug 확장

#if DEBUG
extension CleanupConstants {

    /// 디버그 모드에서 임계값 오버라이드 활성화
    /// - UserDefaults에서 "debug.cleanup.enabled" 키로 확인
    static var isDebugOverrideEnabled: Bool {
        UserDefaults.standard.bool(forKey: "debug.cleanup.enabled")
    }

    /// 디버그 모드에서 극단 어두움 임계값 오버라이드
    static var debugExtremeDarkLuminance: Double {
        let value = UserDefaults.standard.double(forKey: "debug.cleanup.darkLuminance")
        return value > 0 ? value : extremeDarkLuminance
    }

    /// 디버그 모드에서 심각 블러 임계값 오버라이드
    static var debugSevereBlurLaplacian: Double {
        let value = UserDefaults.standard.double(forKey: "debug.cleanup.blurLaplacian")
        return value > 0 ? value : severeBlurLaplacian
    }
}
#endif
