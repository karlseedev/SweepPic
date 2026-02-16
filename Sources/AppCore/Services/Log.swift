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
        "Video": false,              // 비디오 재생 로그 (VideoPageViewController)
        "Photo": false,              // 사진 표시 로그 (PhotoPageViewController)
        "Zoom": false,               // 줌 동작 (기존 debugZoom)
        "Overlay": false,            // 오버레이 (기존 debugOverlayEnabled)
        "Viewer": false,             // 뷰어 일반 (기존 debugViewer)
        "VideoControls": false,      // 비디오 컨트롤 (기존 debugControls)
        "FaceButton": false,         // 얼굴 버튼 위치 (기존 debugButtonPosition)
        "ViewerPerf": false,         // 뷰어 성능 측정
        "Viewer:Hitch": true,        // 뷰어 스와이프 히치 측정
        "Viewer:Hitch:Abs": true,    // 뷰어 히치 절대값 로그
        "Viewer:Swipe": true,        // 뷰어 스와이프 로그
        "Viewer:Scroll": true,       // 뷰어 스크롤 델리게이트 로그

        // =============================================
        // Grid 관련
        // =============================================
        "GridViewController": false,
        "GridVC.sourceViewProvider": false,
        "BaseGridViewController": false,
        "AlbumGridViewController": false,
        "TrashAlbumViewController": false,
        "TrashAlbumViewController.Timing": false,
        "TrashAlbumVC.sourceViewProvider": false,
        "GridDataSource": false,
        "GridDataSourceDriver": false,
        "GridSelectMode": false,
        "BaseSelectMode": false,
        "TrashSelectMode": false,
        "SelectionManager": false,
        "GridGestures": false,
        "GridScroll": false,
        "GridStats": true,           // 그리드 통계 (grayShown, mismatch)
        "PinchZoom": false,

        // =============================================
        // Navigation / UI
        // =============================================
        "TabBarController": false,
        "FloatingTabBar": false,
        "FloatingTitleBar": false,
        "FloatingOverlayContainer": false,
        "PermissionVC": false,
        "AlbumsViewController": true,       // 앨범 탭 깜빡임 디버깅 (ON)
        "ZoomTransition": true,          // 커스텀 줌 트랜지션 (현재 작업 중)
        "ZoomAnimator": true,            // 줌 애니메이터 (현재 작업 중)
        "Zoom Timing": true,             // 그리드→뷰어 줌 전환 단계별 타이밍
        "Viewer Timing": true,           // 뷰어 열림 전체 라이프사이클 타이밍

        // =============================================
        // SimilarPhoto 분석
        // =============================================
        "SimilarPhoto": true,             // Task 취소 테스트 중 (ON)
        "SimilarityAnalysisQueue": false,
        "SimilarityAnalyzer": false,
        "FaceComparisonViewController": false,
        "PersonPageViewController": false,
        "ViewerViewController+SimilarPhoto": false,
        "GridViewController+SimilarPhoto": false,

        // =============================================
        // 얼굴 인식 (YuNet / Vision)
        // =============================================
        "YuNet": false,
        "YuNetDebugTest": false,
        "YuNetFaceDetector": false,
        "SFace": false,
        "FaceMatching": false,
        "VisionFallback": false,
        "NewSlot": false,

        // =============================================
        // AutoCleanup 기능
        // =============================================
        "QualityAnalyzer": true,     // 현재 작업 중 (ON)
        "CleanupLag": true,          // 정리버튼 랙 진단 (ON)
        "CleanupService": true,      // 현재 작업 중 (ON)
        "CleanupSessionStore": true, // 현재 작업 중 (ON)
        "AutoCleanup": false,
        "VideoFrameExtractor": false,
        "TextDetect": true,          // Vision 텍스트 감지 디버그 (ON)
        "QA-TextDetect": true,       // QualityAnalyzer 텍스트 감지 디버그 (ON)
        "CompareAnalysis": true,     // 통합 로직 테스트 (ON)
        "CompareCategoryStore": true,// 카테고리 저장소 (ON)
        "ModeComparison": true,      // 3모드 비교 테스트 (ON)

        // =============================================
        // ImagePipeline / 썸네일
        // =============================================
        "ImagePipeline": false,
        "Pipeline": false,
        "ThumbnailCache": false,
        "MemoryCache": false,
        "DiskSave": false,
        "Thumb:Req": false,
        "Thumb:Res": false,
        "Preload": false,

        // =============================================
        // 앱 상태 / 초기화
        // =============================================
        "LaunchArgs": false,
        "Env": false,
        "Config": false,
        "TrashStore": false,
        "AppStateStore": false,
        "Timing": false,
        "InitialDisplay": false,
        "Initial Load": false,

        // =============================================
        // 서비스
        // =============================================
        "PhotoLibraryService": false,
        "VideoPipeline": false,
        "AlbumService": false,

        // =============================================
        // Performance / Scroll 측정
        // =============================================
        "Hitch": true,               // 스크롤 히치 측정 (HitchMonitor)
        "Scroll": true,              // 스크롤 시작/종료 로그
        "Performance": true,         // 성능 모니터 (PerformanceMonitor)
        "LiquidGlass": true,         // LiquidGlass 최적화 로그
        "LayerDump": false,          // 레이어 덤프 (render hitch 분석)
        "ABTest": true,              // Render A/B 테스트

        // =============================================
        // Analytics
        // =============================================
        "Analytics": true,               // TelemetryDeck SDK 초기화/전송 로그

        // =============================================
        // Debug / 기타
        // =============================================
        "Permission": false,
        "Trash": false,
        "Album": false,
        "Error": false,
        "SystemUIInspector": false,
        "SystemUIInspector2": false,
        "SystemUIInspector3": false,
        "ButtonInspector": true,
        "LayerPropertyTest": false,
        "Debug": true,                   // 분석 버튼 로그
        "AestheticsOnly": true,          // AestheticsScore 단독 테스터 로그
    ]

    // ========================================
    // MARK: - 전역 설정
    // ========================================

    /// 전체 로그 ON/OFF (false면 모든 로그 비활성화)
    public static var isEnabled = true

    /// 카테고리 없는 로그 출력 여부
    /// - true: [Category] 형식이 아닌 로그도 출력
    /// - false: 카테고리가 없는 로그는 무시
    public static var showUncategorized = false

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
        } else if !showUncategorized {
            // 카테고리가 없는 로그는 showUncategorized가 true일 때만 출력
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
    // MARK: - 유틸리티 함수
    // ========================================

    /// 특정 카테고리 활성화
    /// - Parameter category: 활성화할 카테고리
    public static func enable(_ category: String) {
        categories[category] = true
    }

    /// 특정 카테고리 비활성화
    /// - Parameter category: 비활성화할 카테고리
    public static func disable(_ category: String) {
        categories[category] = false
    }

    /// 모든 카테고리 비활성화
    public static func disableAll() {
        for key in categories.keys {
            categories[key] = false
        }
    }

    /// 모든 카테고리 활성화
    public static func enableAll() {
        for key in categories.keys {
            categories[key] = true
        }
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
