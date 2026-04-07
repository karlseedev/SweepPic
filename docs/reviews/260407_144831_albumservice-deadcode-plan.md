주인님, 계획은 핵심 목표를 달성하기에 대체로 충분합니다. 실제 검색 기준으로 `fetchUserAlbums()`, `fetchSmartAlbums()`, `fetchSmartAlbum(type:)`는 앱/테스트 호출부 없이 [AlbumService.swift](/Users/karl/Project/Photos/iOS/Sources/AppCore/Services/AlbumService.swift):19 안의 프로토콜 선언, 구현부, 내부 연쇄 호출에만 남아 있습니다. `AlbumServiceProtocol` conformer도 [AlbumService.swift](/Users/karl/Project/Photos/iOS/Sources/AppCore/Services/AlbumService.swift):57 하나뿐이라 제거 자체는 안전해 보입니다.

다만 계획서에는 몇 가지 보완이 필요합니다.

1. 제거 대상에서 [AlbumService.swift](/Users/karl/Project/Photos/iOS/Sources/AppCore/Services/AlbumService.swift):5 주석이 빠졌습니다. 파일 상단 주석에 `fetchUserAlbums`, `fetchSmartAlbums`가 남아 있어서 계획대로만 수정하면 계획서의 검증 커맨드인 `grep ... Sources/ SweepPic/`가 실패합니다. 상단 T048 주석도 현재 활성 API 기준으로 갱신해야 합니다.

2. 검증은 `swift build`만으로는 부족합니다. 이 repo는 `Package.swift`의 `AppCore` 패키지와 별도로 [SweepPic.xcodeproj](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic.xcodeproj/xcshareddata/xcschemes/SweepPic.xcscheme)가 있고, 앱 호출부는 [AlbumsViewController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Albums/AlbumsViewController.swift):370, [AlbumsViewController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Albums/AlbumsViewController.swift):400, [AlbumsViewController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Albums/AlbumsViewController.swift):572, [AlbumsViewController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/Albums/AlbumsViewController.swift):592 쪽입니다. 따라서 `swift build`에 더해 `xcodebuild -project SweepPic/SweepPic.xcodeproj -scheme SweepPic -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` 같은 앱 타깃 빌드 검증을 추가하는 게 맞습니다.

3. 검색 검증 커맨드는 `grep`보다 `rg`로 정확히 쓰는 편이 안전합니다. 예: `rg -n "fetchSmartAlbums\\s*\\(|fetchUserAlbums\\s*\\(|fetchSmartAlbum\\s*\\(" Sources/AppCore SweepPic/SweepPic Tests/AppCoreTests SweepPic/SweepPicTests SweepPic/SweepPicUITests specs/001-pickphoto-mvp/contracts`. 단, `docs/`와 `specs/001-pickphoto-mvp/tasks.md`에는 역사적 문서 참조가 남아 있으므로 전체 repo 무참조를 목표로 할지, 코드/계약 무참조만 목표로 할지 계획에 명시해야 합니다.

4. 수정 순서는 문제 없습니다. 프로토콜 선언 제거 후 구현 제거는 중간 상태에서도 구현체의 “추가 메서드”가 남는 형태라 컴파일 리스크가 낮고, `fetchSmartAlbum(type:)`는 `fetchSmartAlbums()` 제거 후 제거하는 순서가 맞습니다.

5. Step 1 커밋은 `git status` 확인을 먼저 넣는 것이 좋습니다. 현재 작업트리에 `?? docs/reviews/260407_144137_coachmark-d1-plan.md`가 있어서 “현재 상태 보존 커밋”이 unrelated 파일을 같이 담을 수 있습니다. 계획에 “unrelated 변경은 커밋에 포함하지 않기”를 명시하는 편이 안전합니다.

참고로 제가 `swift build`와 `xcodebuild -list`를 직접 시도했지만, 현재 샌드박스가 `/Users/karl/.cache`, `~/Library/Developer/Xcode/DerivedData`, SwiftPM 캐시 접근을 막아서 검증 완료까지는 못 했습니다. 실패 원인은 코드 문제가 아니라 실행 환경 권한 문제로 보입니다.