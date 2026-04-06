// AnalyticsUITest.swift
//
// Analytics Test B: 실기기 XCUITest E2E 검증
//
// 목적: 실제 UI 동작 → Analytics 카운터 증가 → 세션 종료(flush) → Supabase 전송
//       전체 E2E 경로를 실기기(iPhone 13 Pro)에서 검증
//
// 사전 조건 (docs/db/260226testB.md 섹션 2 참조):
//   - 일반 사진 15장 + 같은 인물 셀카 5장 (셀카를 마지막에 저장)
//   - 앱 사진 권한: 설정 → SweepPic → 사진 → "모든 사진"
//   - 코치마크 완료 상태
//   - USB 연결 + 개발자 모드 활성화
//
// 실행 (개별 Phase):
//   xcodebuild test ... -only-testing:SweepPicUITests/AnalyticsUITest/testPhase1_similarPhoto
//   xcodebuild test ... -only-testing:SweepPicUITests/AnalyticsUITest/testPhase2_photoViewing
//   xcodebuild test ... -only-testing:SweepPicUITests/AnalyticsUITest/testPhase3_viewerDelete
//   xcodebuild test ... -only-testing:SweepPicUITests/AnalyticsUITest/testPhase4_gridSwipeDelete
//   xcodebuild test ... -only-testing:SweepPicUITests/AnalyticsUITest/testPhase5_trashViewer
//   xcodebuild test ... -only-testing:SweepPicUITests/AnalyticsUITest/testPhase6_albumViewing
//
// 실행 (전체):
//   scripts/analytics/run-test-b.sh

import XCTest

final class AnalyticsUITest: XCTestCase {

    private var app: XCUIApplication!

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // XCUITest 실행 시 앱이 재설치되어 UserDefaults 초기화 → 코치마크 재표시 방지
        app.launchArguments = ["--skip-coachmarks"]

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

        // "photo_grid" identifier로 정확히 사진 그리드만 탐색
        let collection = app.collectionViews["photo_grid"]
        XCTAssertTrue(collection.waitForExistence(timeout: 10), "그리드 로드 실패")

        // 그리드를 맨 위로 스크롤 (스크롤 위치 복원 대비)
        collection.swipeDown(velocity: .fast)
        Thread.sleep(forTimeInterval: 0.3)
    }

    // MARK: - Helper

    /// 그리드에서 첫 번째 hittable 셀 반환
    /// 패딩 셀은 화면 위 밖(y < 0)에 위치해 isHittable = false → 건너뜀
    private func firstHittableCell(in collection: XCUIElement) -> XCUIElement? {
        let count = collection.cells.count
        for i in 0..<min(count, 8) {
            let c = collection.cells.element(boundBy: i)
            if c.isHittable { return c }
        }
        return nil
    }

    /// 그리드에서 마지막 hittable 셀 반환 (최신 사진 = 하단)
    private func lastHittableCell(in collection: XCUIElement) -> XCUIElement? {
        let count = collection.cells.count
        guard count > 0 else { return nil }
        for i in stride(from: count - 1, through: max(0, count - 8), by: -1) {
            let c = collection.cells.element(boundBy: i)
            if c.isHittable { return c }
        }
        return nil
    }

    /// 세션 종료: Home → background → flushCounters() → Supabase 전송 트리거
    private func endSession() {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
    }

    // MARK: - 진단 테스트

    /// 셀 탭 단독 진단: cells 개수, frame, 탭 후 뷰어 전환 여부만 확인
    func testCellTapDiag() throws {
        let collection = app.collectionViews["photo_grid"]

        // 1. cells 개수
        let cellCount = collection.cells.count
        print("📊 cells.count = \(cellCount)")
        XCTAssertGreaterThan(cellCount, 0, "셀 0개 — 그리드 인식 실패")

        // 2. firstMatch 정보
        let first = collection.cells.firstMatch
        XCTAssertTrue(first.exists, "firstMatch 없음")
        print("📐 firstCell frame = \(first.frame)")
        print("📐 firstCell isHittable = \(first.isHittable)")
        print("📐 firstCell identifier = \(first.identifier)")

        // 3. 모든 셀 frame 출력 (최대 5개)
        let limit = min(cellCount, 5)
        for i in 0..<limit {
            let c = collection.cells.element(boundBy: i)
            print("   cell[\(i)] frame=\(c.frame) hittable=\(c.isHittable) id=\(c.identifier)")
        }

        // 4. hittable인 첫 번째 셀 탭
        guard let cell = firstHittableCell(in: collection) else {
            XCTFail("hittable 셀 없음 — 그리드 탭 불가"); return
        }
        print("🖱️ cell.tap() 실행 frame=\(cell.frame)")
        cell.tap()

        // 5. 뷰어 확인 — viewer_back / viewer_delete 둘 다 체크
        let backBtn = app.buttons["viewer_back"]
        let deleteBtn = app.buttons["viewer_delete"]
        let viewerOpened = deleteBtn.waitForExistence(timeout: 5)
        print("🔍 viewer_back exists = \(backBtn.exists)")
        print("🔍 viewer_delete exists = \(deleteBtn.exists)")
        print("🔍 app.buttons count = \(app.buttons.count)")
        for i in 0..<min(app.buttons.count, 20) {
            let b = app.buttons.element(boundBy: i)
            print("   button[\(i)] id=\(b.identifier) label=\(b.label) exists=\(b.exists)")
        }
        XCTAssertTrue(backBtn.exists || viewerOpened, "뷰어 미열림 (back:\(backBtn.exists) delete:\(deleteBtn.exists))")
    }

    // MARK: - Phase 1: 유사 사진 (similar.groupClosed)

    /// 기대값: similar.groupClosed(totalCount=5, deletedCount=2) — 즉시 전송
    /// 셀카 5장이 그리드 최하단(최신)에 위치
    func testPhase1_similarPhoto() throws {
        let collection = app.collectionViews["photo_grid"]

        // 그리드 맨 아래로 스크롤 (최신 셀카가 하단에 위치)
        for _ in 0..<10 {
            collection.swipeUp(velocity: .fast)
        }
        Thread.sleep(forTimeInterval: 0.5)

        // 하단의 마지막 hittable 셀 탭 → 뷰어 (셀카 사진)
        guard let cell1 = lastHittableCell(in: collection) else { XCTFail("hittable 셀 없음"); return }
        cell1.tap()

        // +버튼 대기 (Vision 분석 완료 후 표시) → 탭
        let faceButton = app.buttons["face_comparison_button"]
        XCTAssertTrue(faceButton.waitForExistence(timeout: 60), "+버튼 미표시 (Vision 분석 완료 대기)")
        faceButton.tap()

        // 비교 화면에서 셀 2개 선택
        let comparisonGrid = app.collectionViews.firstMatch
        XCTAssertTrue(comparisonGrid.waitForExistence(timeout: 5), "비교 화면 로드 실패")
        Thread.sleep(forTimeInterval: 0.3)
        comparisonGrid.cells.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.2)
        comparisonGrid.cells.element(boundBy: 1).tap()
        Thread.sleep(forTimeInterval: 0.2)

        // 삭제 버튼 탭
        let deleteBtn = app.buttons["comparison_delete"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 3), "비교 화면 삭제 버튼 없음")
        deleteBtn.tap()

        // 그리드 복귀 확인
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "그리드 복귀 실패")

        // 세션 종료 → flush
        endSession()
    }

    // MARK: - Phase 2: 사진 열람 (photoViewing)

    /// 기대값: session.photoViewing — total=6, fromLibrary=6
    func testPhase2_photoViewing() throws {
        let collection = app.collectionViews["photo_grid"]

        // 첫 번째 hittable 셀 탭 → 뷰어 열기
        guard let cell = firstHittableCell(in: collection) else { XCTFail("hittable 셀 없음"); return }
        cell.tap()
        XCTAssertTrue(app.buttons["viewer_delete"].waitForExistence(timeout: 5), "뷰어 열림 실패")

        // 왼쪽 스와이프 5회 (페이지 전환 → countPhotoViewed 호출)
        for _ in 0..<5 {
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 뒤로 버튼 → 그리드 복귀
        app.buttons["viewer_back"].tap()
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "그리드 복귀 실패")

        // 세션 종료 → flush
        endSession()
    }

    // MARK: - Phase 3: 뷰어 삭제 (viewerTrashButton, viewerSwipeDelete)

    /// 기대값: session.deleteRestore — viewerTrashButton=3, viewerSwipeDelete=2, fromLibrary=5
    func testPhase3_viewerDelete() throws {
        let collection = app.collectionViews["photo_grid"]

        // 첫 번째 hittable 셀 탭 → 뷰어
        guard let cell = firstHittableCell(in: collection) else { XCTFail("hittable 셀 없음"); return }
        cell.tap()
        XCTAssertTrue(app.buttons["viewer_delete"].waitForExistence(timeout: 5), "뷰어 열림 실패")

        // 삭제 버튼 3회
        let deleteButton = app.buttons["viewer_delete"]
        var deleted = 0
        var attempts = 0
        while deleted < 3 && attempts < 8 {
            attempts += 1
            if deleteButton.waitForExistence(timeout: 1) {
                deleteButton.tap()
                deleted += 1
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                app.swipeLeft()
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
        XCTAssertEqual(deleted, 3, "삭제 버튼 탭 \(deleted)/3 회 완료")

        // 위로 스와이프 2회 (viewerSwipeDelete)
        for _ in 0..<2 {
            app.swipeUp(velocity: .fast)
            Thread.sleep(forTimeInterval: 0.5)
        }

        // 뒤로 버튼 → 그리드 복귀
        app.buttons["viewer_back"].tap()
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "그리드 복귀 실패")

        // 세션 종료 → flush
        endSession()
    }

    // MARK: - Phase 4: 목록 스와이프 삭제 (gridSwipeDelete)

    /// 기대값: session.deleteRestore — gridSwipeDelete=4, fromLibrary=4
    func testPhase4_gridSwipeDelete() throws {
        let collection = app.collectionViews["photo_grid"]

        // 첫 번째 hittable 셀 수평 스와이프 4회
        for i in 0..<4 {
            guard let cell = firstHittableCell(in: collection) else {
                XCTFail("셀 \(i) hittable 없음"); return
            }
            let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            let end   = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 1500, thenHoldForDuration: 0)
            Thread.sleep(forTimeInterval: 0.5)
        }

        // 세션 종료 → flush
        endSession()
    }

    // MARK: - Phase 5: 삭제대기함 (trashViewer)

    /// 기대값: session.trashViewer — permanentDelete=2, restore=3
    ///         session.deleteRestore — viewerRestoreButton=3
    /// 사전 조건: 삭제대기함에 사진 5장 이상 필요 (Phase 3+4 실행 후)
    func testPhase5_trashViewer() throws {
        // 삭제대기함 탭바 탭
        let trashTab = app.buttons["삭제대기함"]
        XCTAssertTrue(trashTab.waitForExistence(timeout: 5), "삭제대기함 탭 찾기 실패")
        trashTab.tap()

        let collection = app.collectionViews["photo_grid"]
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "삭제대기함 그리드 로드 실패")

        // 첫 번째 hittable 셀 탭 → 삭제대기함 뷰어 열기
        guard let trashCell = firstHittableCell(in: collection) else { XCTFail("hittable 셀 없음"); return }
        trashCell.tap()
        XCTAssertTrue(app.buttons["viewer_permanent_delete"].waitForExistence(timeout: 5), "삭제대기함 뷰어 열림 실패")
        let permanentDeleteBtn = app.buttons["viewer_permanent_delete"]

        // 완전삭제 2회 (각 탭 후 iOS 시스템 다이얼로그 자동 허용)
        for _ in 0..<2 {
            XCTAssertTrue(permanentDeleteBtn.waitForExistence(timeout: 3), "완전삭제 버튼 없음")
            permanentDeleteBtn.tap()
            // 시스템 다이얼로그 처리 + 비동기 삭제 완료 대기
            Thread.sleep(forTimeInterval: 1.5)
        }

        // 복구 3회
        let restoreBtn = app.buttons["viewer_restore"]
        for _ in 0..<3 {
            XCTAssertTrue(restoreBtn.waitForExistence(timeout: 3), "복구 버튼 없음")
            restoreBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // 뒤로 버튼 → 그리드 복귀
        let backButton = app.buttons["viewer_back"]
        if backButton.waitForExistence(timeout: 3) { backButton.tap() }

        // 세션 종료 → flush
        endSession()
    }

    // MARK: - Phase 6: 앨범 열람 (fromAlbum)

    /// 기대값: session.photoViewing — total=3, fromAlbum=3
    ///         session.deleteRestore — gridSwipeDelete=1, fromAlbum=1
    ///
    /// 앨범 탭 → 앨범 상세 그리드 → 뷰어 열기/스와이프 → 목록 스와이프 삭제
    /// AlbumGridViewController 경유 시 deleteSource=.album → fromAlbum 카운터 증가 확인
    ///
    /// 사전 조건: 앨범에 사진 4장 이상 필요 (스와이프 3회 + 삭제 1회)
    func testPhase6_albumViewing() throws {
        // 1. 앨범 탭 탭
        let albumTab = app.buttons["앨범"]
        XCTAssertTrue(albumTab.waitForExistence(timeout: 5), "앨범 탭 찾기 실패")
        albumTab.tap()

        // 2. 앨범 목록 로드 대기 → 첫 번째 앨범 셀 탭
        let albumList = app.collectionViews["album_list"]
        XCTAssertTrue(albumList.waitForExistence(timeout: 5), "앨범 목록 로드 실패")
        Thread.sleep(forTimeInterval: 0.5)

        guard let albumCell = firstHittableCell(in: albumList) else {
            XCTFail("앨범 목록에서 hittable 셀 없음"); return
        }
        albumCell.tap()

        // 3. 앨범 상세 그리드 로드 대기
        let albumGrid = app.collectionViews["photo_grid"]
        XCTAssertTrue(albumGrid.waitForExistence(timeout: 5), "앨범 상세 그리드 로드 실패")
        Thread.sleep(forTimeInterval: 0.5)

        // 4. 셀 탭 → 뷰어 열기 (countPhotoViewed from:.album → fromAlbum +1)
        // 패딩 셀 건너뛰기: 3열 그리드에서 패딩은 최대 2개 → index 3부터 실제 사진 셀
        let photoCell = albumGrid.cells.element(boundBy: 3)
        XCTAssertTrue(photoCell.waitForExistence(timeout: 3), "앨범 그리드 사진 셀 없음")
        photoCell.tap()
        XCTAssertTrue(app.buttons["viewer_delete"].waitForExistence(timeout: 5), "앨범 뷰어 열림 실패")

        // 5. 왼쪽 스와이프 2회 (페이지 전환 → countPhotoViewed from:.album → fromAlbum +2)
        for _ in 0..<2 {
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 6. 뒤로 버튼 → 앨범 그리드 복귀
        app.buttons["viewer_back"].tap()
        XCTAssertTrue(albumGrid.waitForExistence(timeout: 5), "앨범 그리드 복귀 실패")
        Thread.sleep(forTimeInterval: 0.3)

        // 7. 목록 스와이프 삭제 1회 (countGridSwipeDelete source:.album → fromAlbum +1)
        // 패딩 셀 건너뛰기
        let swipeCell = albumGrid.cells.element(boundBy: 3)
        let start = swipeCell.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        let end   = swipeCell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 1500, thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 0.5)

        // 8. 보관함 탭으로 복귀 (다음 Phase 대비)
        let photosTab = app.buttons["보관함"]
        if photosTab.waitForExistence(timeout: 3) { photosTab.tap() }
        Thread.sleep(forTimeInterval: 0.3)

        // 세션 종료 → flush
        endSession()
    }

    // MARK: - 전체 테스트 (All Phases)

    /// 모든 Phase를 순서대로 실행 (단일 세션)
    func testAllPhases() throws {
        // Phase 1: 유사 사진
        phase1_similarPhoto()

        // Phase 2: 사진 열람
        phase2_photoViewing()

        // Phase 3: 뷰어 삭제
        phase3_viewerDelete()

        // Phase 4: 목록 스와이프 삭제
        phase4_gridSwipeDelete()

        // Phase 5: 삭제대기함
        phase5_trashViewer()

        // Phase 6: 앨범 열람
        phase6_albumViewing()

        // 세션 종료 → flush
        endSession()
    }

    // MARK: - Private Phase Implementations (전체 테스트용)

    private func phase1_similarPhoto() {
        let collection = app.collectionViews["photo_grid"]

        // 그리드 맨 아래로 스크롤 (최신 셀카가 하단에 위치)
        for _ in 0..<10 {
            collection.swipeUp(velocity: .fast)
        }
        Thread.sleep(forTimeInterval: 0.5)

        // 하단의 마지막 hittable 셀 탭 → 뷰어 (셀카 사진)
        guard let cell1 = lastHittableCell(in: collection) else { XCTFail("hittable 셀 없음"); return }
        cell1.tap()

        // +버튼 대기 (Vision 분석 완료 후 표시) → 탭
        let faceButton = app.buttons["face_comparison_button"]
        XCTAssertTrue(faceButton.waitForExistence(timeout: 60), "+버튼 미표시 (Vision 분석 완료 대기)")
        faceButton.tap()

        // 비교 화면에서 셀 2개 선택
        let comparisonGrid = app.collectionViews.firstMatch
        XCTAssertTrue(comparisonGrid.waitForExistence(timeout: 5), "비교 화면 로드 실패")
        Thread.sleep(forTimeInterval: 0.3)
        comparisonGrid.cells.element(boundBy: 0).tap()
        Thread.sleep(forTimeInterval: 0.2)
        comparisonGrid.cells.element(boundBy: 1).tap()
        Thread.sleep(forTimeInterval: 0.2)

        // 삭제 버튼 탭
        let deleteBtn = app.buttons["comparison_delete"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 3), "비교 화면 삭제 버튼 없음")
        deleteBtn.tap()

        // 그리드 복귀 확인 + 맨 위로 스크롤 (Phase 2~5 준비)
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "그리드 복귀 실패")
        for _ in 0..<10 {
            collection.swipeDown(velocity: .fast)
        }
        Thread.sleep(forTimeInterval: 0.3)
    }

    private func phase2_photoViewing() {
        let collection = app.collectionViews["photo_grid"]

        guard let cell = firstHittableCell(in: collection) else { XCTFail("hittable 셀 없음"); return }
        cell.tap()
        XCTAssertTrue(app.buttons["viewer_delete"].waitForExistence(timeout: 5), "뷰어 열림 실패")

        for _ in 0..<5 {
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 0.3)
        }

        app.buttons["viewer_back"].tap()
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "그리드 복귀 실패")
    }

    private func phase3_viewerDelete() {
        let collection = app.collectionViews["photo_grid"]

        guard let cell = firstHittableCell(in: collection) else { XCTFail("hittable 셀 없음"); return }
        cell.tap()
        XCTAssertTrue(app.buttons["viewer_delete"].waitForExistence(timeout: 5), "뷰어 열림 실패")

        let deleteButton = app.buttons["viewer_delete"]
        var deleted = 0
        var attempts = 0
        while deleted < 3 && attempts < 8 {
            attempts += 1
            if deleteButton.waitForExistence(timeout: 1) {
                deleteButton.tap()
                deleted += 1
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                app.swipeLeft()
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
        XCTAssertEqual(deleted, 3, "삭제 버튼 탭 \(deleted)/3 회 완료")

        for _ in 0..<2 {
            app.swipeUp(velocity: .fast)
            Thread.sleep(forTimeInterval: 0.5)
        }

        app.buttons["viewer_back"].tap()
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "그리드 복귀 실패")
    }

    private func phase4_gridSwipeDelete() {
        let collection = app.collectionViews["photo_grid"]

        for i in 0..<4 {
            guard let cell = firstHittableCell(in: collection) else {
                XCTFail("셀 \(i) hittable 없음"); return
            }
            let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            let end   = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 1500, thenHoldForDuration: 0)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func phase5_trashViewer() {
        let trashTab = app.buttons["삭제대기함"]
        XCTAssertTrue(trashTab.waitForExistence(timeout: 5), "삭제대기함 탭 찾기 실패")
        trashTab.tap()

        let collection = app.collectionViews["photo_grid"]
        XCTAssertTrue(collection.waitForExistence(timeout: 5), "삭제대기함 그리드 로드 실패")

        guard let trashCell = firstHittableCell(in: collection) else { XCTFail("hittable 셀 없음"); return }
        trashCell.tap()
        XCTAssertTrue(app.buttons["viewer_permanent_delete"].waitForExistence(timeout: 5), "삭제대기함 뷰어 열림 실패")
        let permanentDeleteBtn = app.buttons["viewer_permanent_delete"]

        for _ in 0..<2 {
            XCTAssertTrue(permanentDeleteBtn.waitForExistence(timeout: 3), "완전삭제 버튼 없음")
            permanentDeleteBtn.tap()
            Thread.sleep(forTimeInterval: 1.5)
        }

        let restoreBtn = app.buttons["viewer_restore"]
        for _ in 0..<3 {
            XCTAssertTrue(restoreBtn.waitForExistence(timeout: 3), "복구 버튼 없음")
            restoreBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        let backButton = app.buttons["viewer_back"]
        if backButton.waitForExistence(timeout: 3) { backButton.tap() }
    }

    private func phase6_albumViewing() {
        // 1. 앨범 탭 탭
        let albumTab = app.buttons["앨범"]
        XCTAssertTrue(albumTab.waitForExistence(timeout: 5), "앨범 탭 찾기 실패")
        albumTab.tap()

        // 2. 앨범 목록 로드 대기 → 첫 번째 앨범 셀 탭
        let albumList = app.collectionViews["album_list"]
        XCTAssertTrue(albumList.waitForExistence(timeout: 5), "앨범 목록 로드 실패")
        Thread.sleep(forTimeInterval: 0.5)

        guard let albumCell = firstHittableCell(in: albumList) else {
            XCTFail("앨범 목록에서 hittable 셀 없음"); return
        }
        albumCell.tap()

        // 3. 앨범 상세 그리드 로드 대기
        let albumGrid = app.collectionViews["photo_grid"]
        XCTAssertTrue(albumGrid.waitForExistence(timeout: 5), "앨범 상세 그리드 로드 실패")
        Thread.sleep(forTimeInterval: 0.5)

        // 4. 셀 탭 → 뷰어 열기 (fromAlbum +1)
        // 패딩 셀 건너뛰기: 3열 그리드에서 패딩은 최대 2개 → index 3부터 실제 사진 셀
        let photoCell = albumGrid.cells.element(boundBy: 3)
        XCTAssertTrue(photoCell.waitForExistence(timeout: 3), "앨범 그리드 사진 셀 없음")
        photoCell.tap()
        XCTAssertTrue(app.buttons["viewer_delete"].waitForExistence(timeout: 5), "앨범 뷰어 열림 실패")

        // 5. 왼쪽 스와이프 2회 (fromAlbum +2)
        for _ in 0..<2 {
            app.swipeLeft()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 6. 뒤로 → 앨범 그리드 복귀
        app.buttons["viewer_back"].tap()
        XCTAssertTrue(albumGrid.waitForExistence(timeout: 5), "앨범 그리드 복귀 실패")
        Thread.sleep(forTimeInterval: 0.3)

        // 7. 목록 스와이프 삭제 1회 (deleteRestore.fromAlbum +1)
        // 패딩 셀 건너뛰기
        let swipeCell = albumGrid.cells.element(boundBy: 3)
        let start = swipeCell.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        let end   = swipeCell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: 1500, thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 0.5)

        // 8. 보관함 탭으로 복귀
        let photosTab = app.buttons["보관함"]
        if photosTab.waitForExistence(timeout: 3) { photosTab.tap() }
        Thread.sleep(forTimeInterval: 0.3)
    }
}
