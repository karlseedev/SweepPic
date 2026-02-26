// AnalyticsUITest.swift
//
// Analytics Test B: 실기기 XCUITest E2E 검증
//
// 목적: 실제 UI 동작 → Analytics 카운터 증가 → 세션 종료(flush) → Supabase 전송
//       전체 E2E 경로를 실기기(iPhone 13 Pro)에서 검증
//
// 사전 조건 (docs/db/260226testB.md 섹션 2 참조):
//   - 일반 사진 15장 + 같은 인물 셀카 5장 (셀카를 마지막에 저장)
//   - 앱 사진 권한: 설정 → PickPhoto → 사진 → "모든 사진"
//   - 코치마크 완료 상태
//   - USB 연결 + 개발자 모드 활성화
//
// 실행:
//   scripts/analytics/run-test-b.sh
//   또는 Xcode에서 직접 실행

import XCTest

final class AnalyticsUITest: XCTestCase {

    private var app: XCUIApplication!

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // 권한 다이얼로그 자동 허용 (앱 최초 실행 시)
        addUIInterruptionMonitor(withDescription: "Photos Permission") { alert in
            for label in ["모든 사진에 대한 접근 허용", "Allow Full Access", "허용", "Allow"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        // 완전삭제 시 iOS 시스템 확인 다이얼로그 자동 허용
        // PHPhotoLibrary.performChanges → "N장의 사진을 삭제하도록 허용하겠습니까?" 팝업
        addUIInterruptionMonitor(withDescription: "Photo Deletion") { alert in
            for label in ["삭제", "Delete"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        app.launch()

        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 10), "그리드 로드 실패")
        // app.tap() 제거: 권한이 설정에서 이미 허용된 상태이므로 팝업이 없음
        // app.tap()이 있으면 그리드 셀을 탭해 카운터가 오염될 수 있음
    }

    // MARK: - Main Test

    func testAnalyticsCounters() throws {
        // Phase 1: 유사 사진 먼저 실행 (이후 Phase의 삭제로 유사 그룹이 깨지는 것 방지)
        phase1_similarPhoto()

        // Phase 2: 사진 열람 (photoViewing 카운터)
        phase2_photoViewing()

        // Phase 3: 뷰어 삭제 (viewerTrashButton, viewerSwipeDelete)
        phase3_viewerDelete()

        // Phase 4: 그리드 스와이프 삭제 (gridSwipeDelete)
        phase4_gridSwipeDelete()

        // Phase 5: 삭제대기함 (trashViewer.permanentDelete, trashViewer.restore)
        phase5_trashViewer()

        // Phase 6: Home → background → flushCounters() → Supabase 배치 전송
        XCUIDevice.shared.press(.home)
        // flush 완료 대기 (verify 스크립트는 별도 polling으로 확인)
        Thread.sleep(forTimeInterval: 3)
    }

    // MARK: - Phase 1: 유사 사진 (similar.groupClosed)

    /// 기대값: similar.groupClosed(totalCount=5, deletedCount=2) — 즉시 전송
    /// 사진 세팅: 인물 셀카 5장이 그리드 셀 0~4에 위치
    private func phase1_similarPhoto() {
        let collection = app.collectionViews.firstMatch

        // Step 1: 유사 사진 셀 탭 → 뷰어
        // photoViewing: total +1, fromLibrary +1
        collection.cells.element(boundBy: 0).tap()

        // Step 2: +버튼 대기 (Vision 분석 완료 후 표시) → 탭
        let faceButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '비교'")
        ).firstMatch
        XCTAssertTrue(faceButton.waitForExistence(timeout: 10), "+버튼 미표시 (Vision 분석 완료 대기)")
        faceButton.tap()

        // Step 3: 비교 화면에서 셀 2개 선택
        // - 초기 상태: 5장 전부 미선택
        // - 셀 탭 → 체크마크 + 파란 오버레이 표시 (선택 토글)
        // - 주의: 비교 화면이 modal로 뷰어 위에 올라오므로 collectionViews 순서 확인 필요
        //   (firstMatch가 메인 그리드를 잡을 경우 lastMatch로 변경)
        let comparisonGrid = app.collectionViews.firstMatch
        XCTAssertTrue(comparisonGrid.waitForExistence(timeout: 5), "비교 화면 로드 실패")
        Thread.sleep(forTimeInterval: 0.5)  // 렌더링 대기
        comparisonGrid.cells.element(boundBy: 0).tap()  // 셀 0 선택 → 체크마크
        Thread.sleep(forTimeInterval: 0.3)
        comparisonGrid.cells.element(boundBy: 1).tap()  // 셀 1 선택 → 체크마크
        Thread.sleep(forTimeInterval: 0.3)

        // Step 4: 삭제 버튼 탭 → similar.groupClosed 즉시 전송 + 비교화면/뷰어 dismiss
        let deleteBtn = app.buttons["comparison_delete"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 3), "비교 화면 삭제 버튼 없음")
        deleteBtn.tap()

        // Step 5: 그리드 복귀 확인
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "그리드 복귀 실패")
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: - Phase 2: 사진 열람 (photoViewing)

    /// 기대값: total +6 (뷰어 열기 1 + 스와이프 5), fromLibrary +6
    private func phase2_photoViewing() {
        let collection = app.collectionViews.firstMatch

        // Step 6: 셀 탭 → 뷰어 열기
        collection.cells.element(boundBy: 0).tap()
        let deleteButton = app.buttons["viewer_delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "뷰어 열림 실패")

        // Step 7-11: 왼쪽 스와이프 5회 (페이지 전환 → countPhotoViewed 호출)
        for _ in 0..<5 {
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Step 12: 뒤로 버튼 → 그리드 복귀
        app.buttons["viewer_back"].tap()
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "그리드 복귀 실패")
    }

    // MARK: - Phase 3: 뷰어 삭제 (viewerTrashButton, viewerSwipeDelete)

    /// 기대값: viewerTrashButton=3, viewerSwipeDelete=2, fromLibrary +5
    /// 주의: moveToNextAfterDelete → setViewControllers(animated:true) → didFinishAnimating 미호출
    ///       → 자동 전환 시 countPhotoViewed 미호출 (뷰어 열기 1회만 카운트)
    private func phase3_viewerDelete() {
        let collection = app.collectionViews.firstMatch

        // Step 13: 셀 탭 → 뷰어
        collection.cells.element(boundBy: 0).tap()
        let deleteButton = app.buttons["viewer_delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "뷰어 열림 실패")

        // Step 14-16: 삭제 버튼 3회 (각 탭 후 자동으로 다음 사진으로 전환)
        for _ in 0..<3 {
            XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "삭제 버튼 없음")
            deleteButton.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }

        // Step 17-18: 위로 스와이프 2회 (SwipeDeleteHandler 임계값: -800pt/s 또는 화면 높이 20%)
        for _ in 0..<2 {
            app.swipeUp(velocity: .fast)
            Thread.sleep(forTimeInterval: 0.8)
        }

        // Step 19: 뒤로 버튼 → 그리드 복귀
        app.buttons["viewer_back"].tap()
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "그리드 복귀 실패")
    }

    // MARK: - Phase 4: 그리드 스와이프 삭제 (gridSwipeDelete)

    /// 기대값: gridSwipeDelete=4, fromLibrary +4
    /// 임계값: 셀 너비의 50% 또는 800pt/s (UIPanGestureRecognizer)
    private func phase4_gridSwipeDelete() {
        let collection = app.collectionViews.firstMatch

        // Step 20-23: 셀 수평 스와이프 4회 (항상 boundBy: 0 — 삭제 후 다음 셀이 0번으로 이동)
        for i in 0..<4 {
            let cell = collection.cells.element(boundBy: 0)
            guard cell.waitForExistence(timeout: 3) else {
                XCTFail("셀 \(i) 접근 실패"); return
            }
            // 오른쪽(80%)에서 왼쪽(10%)으로 빠른 드래그
            let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            let end   = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 1500, thenHoldForDuration: 0)
            Thread.sleep(forTimeInterval: 1.0)  // 삭제 애니메이션 완료 대기
        }
    }

    // MARK: - Phase 5: 삭제대기함 (trashViewer)

    /// 기대값: trashViewer.permanentDelete=2, trashViewer.restore=3
    ///         deleteRestore.viewerRestoreButton=3
    /// 삭제대기함 내 사진: P1(2장) + P3(5장) + P4(4장) = 11장
    private func phase5_trashViewer() {
        // Step 24: 삭제대기함 탭바 탭
        let trashTab = app.buttons["삭제대기함"]
        XCTAssertTrue(trashTab.waitForExistence(timeout: 5), "삭제대기함 탭 찾기 실패")
        trashTab.tap()

        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "삭제대기함 그리드 로드 실패")

        // Step 25: 셀 탭 → 삭제대기함 뷰어 열기
        collection.cells.element(boundBy: 0).tap()
        let permanentDeleteBtn = app.buttons["viewer_permanent_delete"]
        XCTAssertTrue(permanentDeleteBtn.waitForExistence(timeout: 5), "삭제대기함 뷰어 열림 실패")

        // Step 26-27: 완전삭제 2회 (각 탭 후 iOS 시스템 다이얼로그 자동 허용)
        for _ in 0..<2 {
            XCTAssertTrue(permanentDeleteBtn.waitForExistence(timeout: 3), "완전삭제 버튼 없음")
            permanentDeleteBtn.tap()
            // 시스템 다이얼로그 처리 및 비동기 삭제 완료 대기
            Thread.sleep(forTimeInterval: 2.0)
        }

        // Step 28-30: 복구 3회
        let restoreBtn = app.buttons["viewer_restore"]
        for _ in 0..<3 {
            XCTAssertTrue(restoreBtn.waitForExistence(timeout: 3), "복구 버튼 없음")
            restoreBtn.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }

        // Step 31: 뒤로 버튼 → 그리드 복귀
        let backButton = app.buttons["viewer_back"]
        if backButton.waitForExistence(timeout: 3) { backButton.tap() }
    }
}
