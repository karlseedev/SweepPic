# PickPhoto Tech Spec (초안)

## 0. 문서 목적

본 문서는 `docs/prd3.md`의 요구사항을 구현하기 위한 기술 설계/구현 계획 문서입니다. PRD에 포함하지 않는 구현 디테일(파일 구조, 클래스 설계, 코드 스니펫, 계측 방법)을 여기에서 관리합니다.

---

## 1. 핵심 기술 선택

### 1.1 UI: UIKit 중심

- 그리드/스크롤 성능 경로는 `UICollectionView`를 기본으로 합니다.
- SwiftUI는 탭 셸/설정/상태 화면 등 비핵심에서 하이브리드로만 사용합니다.

선택 근거:
- 셀 재사용/프리패치/취소 제어(`UICollectionViewDataSourcePrefetching`)의 정밀도가 Photos급 체감에 유리합니다.
- 대용량(5만장)에서 스크롤 hitch를 줄이기 위한 캐싱/취소/코얼레싱 정책을 UI 계층에서 강제하기 쉽습니다.

### 1.2 Photo 접근/변경 감지: PhotoKit

- `Photos`(PhotoKit): `PHAsset`, `PHFetchResult`, `PHPhotoLibraryChangeObserver`
- 이미지 요청/캐싱: `PHCachingImageManager`
- 네트워크: 기본 정책 `isNetworkAccessAllowed = false` (MVP)

---

## 2. 모듈 경계(구현 관점)

PRD의 경계를 코드 구조로 매핑합니다.

- `LibraryStore`
  - 권한/Fetch/Change observation
  - `PHFetchResult<PHAsset>`를 “배열로 풀어헤치지 않고” 랜덤 액세스의 소스로 유지
- `TimelineIndex` (MVP: All-only)
  - MVP에서는 “섹션/버킷”은 최소화(단일 섹션)하고, 핀치 앵커 유지에 필요한 `assetID ↔ indexPath`만 보장
  - v2~v3에서 Days/Months/Years 버킷 확장
- `AlbumIndex`
  - 사용자 앨범/스마트 앨범 목록과 각 앨범의 fetch 결과 관리
- `ImagePipeline`
  - 요청/취소/코얼레싱/캐시/프리히트(preheat) 정책의 단일 구현
- `GridController`
  - `UICollectionView` 구성, 프리패치 연결, 멀티선택/선택 상태 유지
- `ViewerCoordinator`
  - 뷰어 내비게이션(이전/다음), 위 스와이프 삭제, 삭제 후 “이전 사진” 우선 이동

---

## 3. 데이터 소스 전략(대용량 5만장)

### 3.1 원칙

- `PHAsset.localIdentifier`를 유일 식별자로 사용합니다.
- 아이템 목록을 `[PHAsset]`로 전량 물질화하지 않습니다.
- UI 업데이트(삭제/변경)는 가능한 “부분 업데이트”로 처리하고, 전체 스냅샷/전체 리로드를 회피합니다.

### 3.2 Diffable 적용 여부

Diffable은 편하지만, 대용량에서 snapshot 생성/적용 비용이 문제가 될 수 있어 스파이크로 결정합니다.

- 후보 A: Diffable(구현 용이, 변경 반영 간편)
- 후보 B: 전통 data source(필요한 구간만 invalidate/insert/delete)

결정 기준:
- 스크롤 hitch 비율, 삭제 반영 시간, 메모리 상한을 만족하는 쪽으로 확정

---

## 4. 이미지 로딩/캐싱 설계

### 4.1 그리드 썸네일 정책

- 타깃 사이즈: “셀의 실제 픽셀 크기”에 맞춘 정사각형
- 옵션: 빠른 표시 우선(저품질 먼저 → 고품질 대체 가능)
- 네트워크 접근: 불허(MVP)

### 4.2 요청 취소/코얼레싱(오표시 0)

셀 재사용 시 반드시 아래를 수행합니다.

- 셀은 “현재 바인딩된 assetID + 요청 토큰(requestID)”를 보유
- 재사용/바인딩 변경 시 이전 요청을 취소
- 콜백 수신 시 토큰/assetID가 현재와 일치할 때만 이미지 적용

### 4.3 프리패치 + 프리히트(preheat)

- `UICollectionViewDataSourcePrefetching`로 “곧 보일 셀”을 선제 요청
- 별도의 preheat 윈도우(가시 영역 ±N 화면)를 운영하여 `PHCachingImageManager.startCachingImages`로 캐시 히트율을 올림
- N은 고정값이 아니라 “스크롤 속도 적응형”을 후보로 두고 스파이크로 수치화 후 확정

---

## 5. 핀치 줌/앵커 유지(Photos-like)

### 5.1 구현 목표

- 핀치 제스처 중심점 아래 콘텐츠(가장 가까운 셀)를 앵커로 캡처
- 줌 중에도 해당 콘텐츠가 화면에서 크게 튀지 않도록 오프셋을 보정

### 5.2 MVP 범위

- MVP는 All Photos 내부 “연속 밀도 변화”만 제공
- Years/Months/Days/All 모드 스냅은 후속(레이아웃/인덱스 확장 후)

---

## 6. 삭제 구현

### 6.1 정책 정리

- 삭제는 항상 라이브러리에서 삭제(`PHAssetChangeRequest.deleteAssets`)
- 확인 UI 없음(즉시)
- 멀티선택 삭제 지원
- 뷰어에서 위 스와이프 삭제 지원
- 뷰어 삭제 후 이동: 이전 사진 우선
- 앱 내부 휴지통/복구, Undo: MVP 제외

### 6.2 권한 처리

- `PHAuthorizationStatus`가 `readWrite`일 때만 삭제 UI를 활성화
- `limited` 등 경계 케이스는 실패 시 사용자 피드백 규칙을 별도 정의(스파이크/QA)

---

## 7. 계측/품질 게이트(구현 단계에서 반드시 수행)

### 7.1 Instruments

- Time Profiler: 메인 스레드 점유(프레임 예산 침범) 확인
- Core Animation: hitch/프레임 드랍 원인 확인
- Allocations/Leaks: 스크롤/뷰어 왕복에서 누수 및 메모리 스파이크 확인

### 7.2 MetricKit

- 릴리즈 이후 기기별 성능 회귀를 수집할 수 있도록 도입(옵션)

---

## 8. 파일 구조(제안)

아래는 “초기 제안”이며, 실제 프로젝트 구조는 팀 합의로 확정합니다.

```
Sources/AppCore/
  Models/
  Services/
  Stores/

PickPhoto/
  Features/
    Grid/
    Albums/
    Viewer/
    Permissions/
  Shared/
```

