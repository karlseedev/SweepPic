# AlbumService 데드 코드 제거 + supportedTypes 통합 리팩토링

## Context

AlbumService에 2단계 로딩 최적화(`fetchAlbumMetadataSync` + `fetchAllAlbumsAsync`)가 도입된 후,
기존의 `fetchSmartAlbums()`, `fetchUserAlbums()`, `fetchSmartAlbum(type:)` 3개 메서드가
호출처 없이 남아있다. 프로토콜에도 그대로 남아 있어 불필요한 코드가 ~95줄 존재한다.
추가로 `supportedTypes` 배열이 2곳에 동일하게 복붙되어 있어 동기화 실수 위험이 있다.

기존 리팩토링 분석 문서(`docs/260219refac.md:48`)에서도 이미 미호출로 식별된 항목이다.

## 수정 대상 파일

1. `Sources/AppCore/Services/AlbumService.swift` — 데드 코드 제거 + supportedTypes 통합
2. `specs/001-pickphoto-mvp/contracts/services.swift` — 상단 경고 주석 1줄 추가 (코드 수정 없음)

## 수정 순서

### Step 1: 커밋 (현재 상태 보존)
- CLAUDE.md 규칙: 50줄 이상 수정 전 커밋 필수
- 관련 없는 파일은 커밋에 포함하지 않음 (git status 확인 후 AlbumService 관련만)

### Step 2: AlbumServiceProtocol에서 데드 메서드 선언 제거
- `fetchUserAlbums()` 선언 제거 (L17-19)
- `fetchSmartAlbums()` 선언 제거 (L21-23)

### Step 3: AlbumService에서 데드 메서드 구현 제거
- `fetchUserAlbums()` 구현 제거 (L68-115)
- `fetchSmartAlbums()` 구현 제거 (L117-146)
- `fetchSmartAlbum(type:)` private 헬퍼 제거 (L414-465)

### Step 4: 파일 상단 T048 주석 갱신
- L4-7의 주석에서 `fetchUserAlbums`, `fetchSmartAlbums` 제거
- 현재 활성 API 기준으로 갱신 (`fetchAlbumMetadataSync`, `fetchAllAlbumsAsync`, `fetchPhotosInAlbum`, `fetchPhotosInSmartAlbum`)

### Step 5: supportedTypes 배열 통합
- `fetchAlbumMetadataSync()` 내 로컬 배열 (L217-221) 제거
- `fetchAllAlbumsAsync()` 내 로컬 배열 (L298-302) 제거
- 클래스 상단에 `private static let supportedTypes` 정의 추가
- 두 메서드에서 `Self.supportedTypes`으로 참조

### Step 6: 스펙 계약 파일 경고 주석 추가
- `specs/001-pickphoto-mvp/contracts/services.swift` 상단에 "실제 코드와 괴리가 있으니 참고용으로만 볼 것" 경고 한 줄 추가
- 코드 내용은 수정하지 않음

### Step 7: 빌드 검증
- `swift build` — AppCore 패키지 컴파일 확인
- `xcodebuild -project SweepPic/SweepPic.xcodeproj -scheme SweepPic -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` — 앱 타깃 빌드 확인

### Step 8: 잔존 참조 검증
- `Sources/`, `SweepPic/`, `specs/contracts/` 범위에서 `fetchSmartAlbums`, `fetchUserAlbums` grep
- `docs/`, `specs/tasks.md` 등 역사적 문서의 참조는 무시 (수정 대상 아님)

### Step 9: 커밋

## 건드리지 않는 것

- `fetchPhotosInAlbum()`, `fetchPhotosInSmartAlbum()`: 활성 사용 중
- `fetchAlbumMetadataSync()`, `fetchAllAlbumsAsync()`: 활성 사용 중
- `phAssetCollectionSubtype(for:)`: 활성 메서드들이 사용 중
- 스펙 계약 파일 내 코드 내용 (경고 주석만 추가)
- `docs/`, `specs/tasks.md` 등 역사적 문서
