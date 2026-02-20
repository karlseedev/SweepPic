// Log.swift
// 중앙 집중 로그 관리 시스템
//
// 사용법:
//   - 카테고리별 로그 ON/OFF: Log.categories["Video"] = true
//   - 전체 로그 ON/OFF: Log.isEnabled = false
//   - 기존 print 대체: Log.print("[Video] 재생 시작")
//   - 카테고리 직접 지정: Log.debug("Zoom", "scale: \(scale)")

import Foundation

/// 중앙 집중 로그 관리 시스템
/// - Log.swift 한 파일에서 모든 로그 ON/OFF 관리
/// - 기존 print()는 Log.print()로 치환하여 출력 필터링
public enum Log {

    // ========================================
    // MARK: - 카테고리별 ON/OFF (여기서 한눈에 관리)
    // ========================================

    /// 카테고리별 로그 활성화 상태
    /// - 키: 카테고리 이름 (예: "Video", "Photo")
    /// - 값: true면 출력, false면 무시
    public static var categories: [String: Bool] = [
        // =============================================
        // App 라이프사이클
        // =============================================
        "AppDelegate": true,
        "SceneDelegate": true,

        // =============================================
        // Viewer 관련
        // =============================================
        "Viewer:Hitch": true,        // 뷰어 스와이프 히치 측정
        "Viewer:Hitch:Abs": true,    // 뷰어 히치 절대값 로그
        "Viewer:Swipe": true,        // 뷰어 스와이프 로그
        "Viewer:Scroll": true,       // 뷰어 스크롤 델리게이트 로그

        // =============================================
        // Navigation / UI
        // =============================================
        "AlbumsViewController": true,    // 앨범 탭 깜빡임 디버깅
        "ZoomTransition": true,          // 커스텀 줌 트랜지션
        "Zoom Timing": true,             // 그리드→뷰어 줌 전환 단계별 타이밍

        // =============================================
        // SimilarPhoto 분석
        // =============================================
        "SimilarPhoto": true,            // Task 취소 테스트 중

        // =============================================
        // AutoCleanup 기능
        // =============================================
        "QualityAnalyzer": true,         // 품질 분석기
        "CleanupLag": true,              // 정리버튼 랙 진단
        "CleanupService": true,          // 정리 서비스
        "CleanupSessionStore": true,     // 정리 세션 저장소
        "PreScanBM": true,               // 코치마크 D 사전 스캔 벤치마크
        "TextDetect": true,              // Vision 텍스트 감지 디버그
        "QA-TextDetect": true,           // QualityAnalyzer 텍스트 감지 디버그
        "CompareAnalysis": true,         // 통합 로직 테스트
        "CompareCategoryStore": true,    // 카테고리 저장소
        "ModeComparison": true,          // 3모드 비교 테스트

        // =============================================
        // Performance / Scroll 측정
        // =============================================
        "Hitch": true,               // 스크롤 히치 측정 (HitchMonitor)
        "Scroll": true,              // 스크롤 시작/종료 로그
        "Performance": true,         // 성능 모니터 (PerformanceMonitor)
        "LiquidGlass": true,         // LiquidGlass 최적화 로그
        "ABTest": true,              // Render A/B 테스트

        // =============================================
        // Analytics
        // =============================================
        "Analytics": true,               // TelemetryDeck SDK 초기화/전송 로그

        // =============================================
        // 코치마크 (Onboarding)
        // =============================================
        "CoachMarkC1": true,             // 코치마크 C-1 (유사사진 뱃지)
        "CoachMarkC2": true,             // 코치마크 C-2 (뷰어 + 버튼)
        "CoachMarkManager": true,        // 코치마크 매니저 (dismiss 보호)

        // =============================================
        // Debug / 기타
        // =============================================
        "ButtonInspector": true,
        "Debug": true,                   // 분석 버튼 로그
        "AestheticsOnly": true,          // AestheticsScore 단독 테스터 로그
    ]

    // ========================================
    // MARK: - 전역 설정
    // ========================================

    /// 전체 로그 ON/OFF (false면 모든 로그 비활성화)
    public static var isEnabled = true

    // ========================================
    // MARK: - 로그 출력 함수
    // ========================================

    /// 메시지에서 카테고리를 추출하여 필터링 후 출력
    /// - Parameter message: "[Category] 메시지" 형식의 로그 메시지
    ///
    /// 사용 예:
    /// ```swift
    /// Log.print("[Video] 재생 시작")
    /// Log.print("[Zoom] scale: \(scale)")
    /// ```
    public static func print(_ message: String) {
        guard isEnabled else { return }

        // [Category] 형식에서 카테고리 추출
        if let category = extractCategory(from: message) {
            // 카테고리가 등록되어 있고 true인 경우에만 출력
            guard categories[category] == true else { return }
        } else {
            // 카테고리가 없는 로그는 무시
            return
        }

        Swift.print(message)
    }

    /// 카테고리를 직접 지정하여 출력 (debugXXX 플래그 대체용)
    /// - Parameters:
    ///   - category: 로그 카테고리 (예: "Zoom", "Video")
    ///   - message: 출력할 메시지
    ///
    /// 사용 예:
    /// ```swift
    /// // 기존 코드:
    /// // if debugZoom { print("[Zoom] scale: \(scale)") }
    ///
    /// // 변경 후:
    /// Log.debug("Zoom", "scale: \(scale)")
    /// ```
    public static func debug(_ category: String, _ message: String) {
        guard isEnabled else { return }
        guard categories[category] == true else { return }
        Swift.print("[\(category)] \(message)")
    }


    // ========================================
    // MARK: - Private
    // ========================================

    /// 메시지에서 "[Category]" 형식의 카테고리 추출
    /// - Parameter message: 로그 메시지
    /// - Returns: 카테고리 문자열 (없으면 nil)
    private static func extractCategory(from message: String) -> String? {
        // "[Category] ..." 형식에서 Category 추출
        guard message.hasPrefix("["),
              let endIndex = message.firstIndex(of: "]") else {
            return nil
        }

        let start = message.index(after: message.startIndex)
        return String(message[start..<endIndex])
    }
}
