**Findings**

1. High: 계획의 뷰어 수정만으로는 동영상 페이지 `+` 버튼 재등장을 완전히 막지 못합니다. 계획은 [`radiant-dazzling-melody.md#L59-L70`](/Users/karl/.claude/plans/radiant-dazzling-melody.md#L59)에서 `shouldEnableSimilarPhoto`에 비디오 가드를 추가하면 충분하다고 보지만, 실제 코드는 스와이프 후 비활성화 시 [`ViewerViewController+SimilarPhoto.swift#L255-L261`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Viewer/ViewerViewController+SimilarPhoto.swift#L255)에서 오버레이만 숨기고 `currentAnalyzingAssetID`는 유지합니다. 이후 분석 완료 콜백은 현재 페이지가 비디오인지 재확인하지 않고 [`ViewerViewController+SimilarPhoto.swift#L665-L687`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Viewer/ViewerViewController+SimilarPhoto.swift#L665)에서 그대로 `showFaceButtons(for:)`를 호출합니다. 그 함수는 현재 페이지 asset 크기를 다시 읽어 [`ViewerViewController+SimilarPhoto.swift#L575-L603`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Viewer/ViewerViewController+SimilarPhoto.swift#L575) 버튼을 그리므로, “이미지 분석 시작 후 동영상으로 스와이프” race에서는 여전히 비디오 페이지에 버튼이 나타날 수 있습니다. `handleAnalysisComplete()`를 수정하지 않아도 된다는 계획의 판단([`radiant-dazzling-melody.md#L74-L82`](/Users/karl/.claude/plans/radiant-dazzling-melody.md#L74))은 여기서 틀렸습니다.

2. Medium: 검증 계획이 위 race case를 못 잡습니다. 현재 문서는 “뷰어에서 동영상으로 넘김 → +버튼이 안 나타나는지”만 적어 두었는데([`radiant-dazzling-melody.md#L89-L92`](/Users/karl/.claude/plans/radiant-dazzling-melody.md#L89)), 문제는 “이미지에서 분석이 진행 중인 상태로 동영상으로 넘겼을 때 완료 콜백이 뒤늦게 도착하는 경우”입니다. 이 시나리오를 별도 검증 항목으로 넣지 않으면 수정 후에도 수동 테스트를 통과할 수 있습니다.

**Assessment**

계획의 핵심 원인 분석은 맞습니다. [`PhotoLibraryService.swift#L89-L104`](/Users/karl/Project/Photos/iOS/Sources/AppCore/Services/PhotoLibraryService.swift#L89)에서 image+video를 가져오고, [`SimilarityAnalysisQueue.swift#L550-L563`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift#L550)와 [`FaceScanService.swift#L360-L376`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/FaceScan/Service/FaceScanService.swift#L360)는 현재 trash만 제외합니다. 또 [`SimilarityImageLoader.swift#L195-L200`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/Analysis/SimilarityImageLoader.swift#L195)처럼 asset 종류를 가리지 않고 `requestImage`를 쓰므로, 비디오가 분석 입력으로 들어간다는 전제도 타당합니다.

그래서 1, 2번 변경은 필요하고 맞습니다. 다만 목표가 “안전하게 제외”라면 뷰어 쪽은 `shouldEnableSimilarPhoto`만으로 부족합니다. 최소한 다음 중 하나는 계획에 추가하는 편이 맞습니다.
- 비활성화 분기에서 `currentAnalyzingAssetID = nil`까지 정리
- `handleAnalysisComplete()`에서 `current page assetID == currentAnalyzingAssetID`와 `current page mediaType == .image`를 다시 확인
- `showFaceButtons(for:)` 자체에서 현재 페이지가 이미지가 아니면 즉시 중단

추가로, 그리드도 방어적으로 비이미지 셀에는 배지를 그리지 않게 [`GridViewController+SimilarPhoto.swift#L320-L336`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridViewController+SimilarPhoto.swift#L320), [`GridViewController+SimilarPhoto.swift#L430-L444`](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Grid/GridViewController+SimilarPhoto.swift#L430)에서 mediaType 확인을 넣으면 더 견고합니다. 이건 필수는 아니지만 UI 방어선으로는 일관됩니다.

빌드는 이 환경에서 CoreSimulator/DerivedData 권한 문제로 신뢰성 있게 검증하지 못했습니다. 리뷰는 문서와 관련 코드 정적 검토 기준입니다.