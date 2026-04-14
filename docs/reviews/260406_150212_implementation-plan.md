검토 결과, 이 계획은 그대로 구현하면 충돌 가능성이 있습니다. 핵심 흐름은 가능하지만, 인터셉트와 자동 pop 쪽은 설계를 조금 바꿔야 안전합니다.

**주요 이슈**

1. iOS 16~25의 C 인터셉트 설계가 서로 모순됩니다.  
   `cleanupButtonTapped()` 상단 체크는 “저품질사진 자동정리” 메뉴 액션을 고른 뒤에야 실행되므로, “간편정리 버튼 탭 시 메뉴 차단” 요구를 만족하지 못합니다. 반대로 현재 `rightButtonInterceptor`를 확장하면 `FloatingTitleBar`가 간편정리 버튼과 전체메뉴 버튼 둘 다 같은 인터셉터로 보내기 때문에 전체메뉴까지 막힙니다. 따라서 “FloatingTitleBar 수정 불필요”는 맞지 않습니다. 버튼 종류를 전달하는 인터셉터로 바꾸거나, 간편정리 버튼 전용 인터셉터를 따로 둬야 합니다.  
   관련 코드: [GridViewController+Cleanup.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridViewController+Cleanup.swift):95, [TabBarController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Navigation/TabBarController.swift):177, [FloatingTitleBar.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Components/FloatingTitleBar.swift):398

2. iOS 26+의 `primaryAction` 인터셉트는 가능하지만, A-1과 복원 로직을 중앙화해야 합니다.  
   현재 A-1은 모든 `rightBarButtonItems`의 `primaryAction`을 덮고, 해제 시 전부 `nil`로 되돌립니다. C가 `items[1]`만 덮더라도 독립적인 `enable/disable` 방식이면 A-1 해제나 `setupCleanupButton()` 재호출 때 C 인터셉트가 날아갈 수 있습니다. `A-1 > C > 원래 메뉴` 우선순위를 가진 단일 reconciliation 함수로 `primaryAction` 상태를 매번 재계산하는 방식이 안전합니다. Apple 문서상 `UIBarButtonItem`은 `primaryAction`과 `menu`를 함께 갖는 생성자를 제공하므로 API 형태 자체는 문제 없습니다.  
   관련 코드: [GridViewController+Cleanup.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridViewController+Cleanup.swift):44, [GridViewController+Cleanup.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridViewController+Cleanup.swift):79, [GridViewController+CoachMarkA1.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridViewController+CoachMarkA1.swift):146  
   참고: https://developer.apple.com/documentation/uikit/uibarbuttonitem/

3. `onGroupFound`에서 `FaceScanService.cancel()` 하는 것은 캐시 정합성 측면에서는 대체로 안전하지만, “빠른 사전 분석”으로 보기엔 비용이 큽니다.  
   `FaceScanService`는 전체 분석 범위의 feature print를 먼저 만들고 그룹을 형성한 뒤에야 그룹별 콜백을 호출합니다. 첫 그룹 콜백 시점에는 이미 `FaceScanCache`에 얼굴/그룹 브리지가 끝난 뒤라 그 데이터를 읽는 것은 안전합니다. 다만 `cancel()`은 다음 루프 체크에서 `CancellationError`를 던지게 하므로, 사전 분석 Task는 이 에러를 “성공적 조기 종료”로 처리해야 합니다. 또 세션 저장 로직은 실행되지 않을 수 있으니 C 사전분석용 UserDefaults는 별도로 완료 처리해야 합니다.  
   관련 코드: [FaceScanService.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/FaceScan/Service/FaceScanService.swift):190, [FaceScanService.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/FaceScan/Service/FaceScanService.swift):215, [FaceScanService.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/FaceScan/Service/FaceScanService.swift):270, [FaceScanService.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/FaceScan/Service/FaceScanService.swift):279, [FaceScanService.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/FaceScan/Service/FaceScanService.swift):298

4. `isAutoPopForC` 자동 pop은 양쪽 경로에서 구현 가능하지만, 실행 위치와 1회 소비 처리가 중요합니다.  
   iOS 26+는 Grid에서 Viewer를 push하고, iOS 16~25는 modal present하므로 `isPushed` 분기는 현재 코드 구조와 맞습니다. 하지만 `Viewer.viewDidAppear`에서 B 표시가 먼저 실행되므로 자동 pop 체크는 B/C-2 트리거보다 앞에 두거나 B guard를 반드시 추가해야 합니다. 또한 pop/dismiss 전에 `pendingCleanupHighlight = true`를 세팅하고, `isDismissing` 같은 재진입 가드가 필요합니다. iOS 26+ pop은 Grid의 transition coordinator completion에서 복귀 처리를 하므로 하이라이트도 단순 `viewDidAppear` 즉시보다 복귀 처리 이후에 띄우는 편이 안전합니다.  
   관련 코드: [ViewerViewController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Viewer/ViewerViewController.swift):266, [ViewerViewController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Viewer/ViewerViewController.swift):412, [ViewerViewController+CoachMark.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Viewer/ViewerViewController+CoachMark.swift):20, [ViewerViewController+Actions.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Viewer/ViewerViewController+Actions.swift):443, [GridViewController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridViewController.swift):333

5. `FaceScanCache → SimilarityCache.shared.addGroupIfValid()` 경로는 타이밍 문제를 만들 수 있으니 완료 순서를 명확히 해야 합니다.  
   `onGroupFound`는 동기 콜백이라 `FaceScanCache` 조회와 `SimilarityCache.shared.addGroupIfValid()` 호출은 별도 `Task`가 필요합니다. 이때 `cache`를 강하게 캡처하고, shared cache 반영이 끝난 뒤에 `isComplete/foundAssetID` 저장, 배지 업데이트, 자동 스크롤을 해야 합니다. 그렇지 않으면 스크롤한 셀에 아직 `SimilarGroupBadgeView`가 없어 C 재검증에서 실패할 수 있습니다. 또한 FaceScan의 `groupID`와 shared cache의 `groupID`는 다르므로, 이후 뷰어/비교 화면은 shared cache가 반환한 그룹 상태를 기준으로 가야 합니다.  
   관련 코드: [FaceScanCache.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/FaceScan/Service/FaceScanCache.swift):37, [SimilarityCache.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/Analysis/SimilarityCache.swift):226, [GridViewController+SimilarPhoto.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridViewController+SimilarPhoto.swift):321, [GridViewController+SimilarPhoto.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridViewController+SimilarPhoto.swift):342

**권장 수정**

- iOS 16~25: `FloatingTitleBar`에 간편정리 버튼 전용 인터셉터를 추가하고, 전체메뉴는 통과시키세요.
- iOS 26+: A-1/C 인터셉트를 각각 enable/disable하지 말고, `syncNavigationButtonInterceptors()` 같은 단일 함수에서 우선순위로 `primaryAction`을 재설정하세요.
- FaceScan 사전 분석: `CancellationError`를 성공 조기 종료로 처리하고, shared cache 반영 완료 후에만 C pre-scan 완료 상태를 저장하세요.
- C-3 완료: overlay dismiss와 FaceComparison dismiss를 연결하는 `onComplete` 콜백이 필요합니다. iOS 26+에서는 `FaceComparisonViewController`가 `UINavigationController`로 감싸져 present되므로 `self.navigationController?.dismiss(...) ?? self.dismiss(...)` 형태가 더 안전합니다.
- Grid 복귀 하이라이트: iOS 26+는 navigation pop transition completion 이후, iOS 16~25는 `viewerDidClose()` 이후로 맞추는 게 안전합니다.