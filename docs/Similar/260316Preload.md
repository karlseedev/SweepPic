# 분석용 2200px 이미지 병렬 프리로드

## 선행 조건
- `260315ViewerLOD.md`의 pause/resume 구현이 완료되어 있어야 함
- SimilarityImageLoader.loadImage()에 `waitIfPaused()` 체크가 있는 상태

## Context
유사 사진 분석 파이프라인에서 그룹 내 사진을 순차 처리할 때,
2200px 이미지 로딩(~100ms/장)이 YuNet/SFace 사이에 끼어서 불필요한 대기 발생.

```
현재: [로딩1→YuNet1→SFace1→매칭1] → [로딩2→YuNet2→SFace2→매칭2] → ...
개선: [로딩1,2,3,4,5 병렬] → [YuNet1→SFace1→매칭1] → [YuNet2→SFace2→매칭2] → ...
```

그룹 3개 × 5장 기준: 로딩 ~1,500ms(순차) → ~100ms(병렬) = **~1,200ms 절약**

## pause/resume과의 연동
프리로드가 `loadImage(for:maxSize:)`을 호출하므로, ViewerLOD의 `waitIfPaused()`가 자동 적용됨.
- 뷰어 진입 시 pause → 프리로드 중인 개별 요청이 시작 전 대기
- LOD1 도착 시 resume → 프리로드 재개
- 추가 코드 불필요 — pause/resume이 loadImage 레벨에서 동작하기 때문

## 변경 내용

### 1. SimilarityImageLoader — loadImages에 maxSize 파라미터 추가
**파일**: `SimilarityImageLoader.swift` (Line 236)

기존 `loadImages(for:)` 메서드에 `maxSize` 파라미터만 추가:
```swift
// 변경 전
func loadImages(for assets: [PHAsset]) async -> [(Int, CGImage?)]

// 변경 후
func loadImages(for assets: [PHAsset], maxSize: CGFloat? = nil) async -> [(Int, CGImage?)]
```
내부에서 `self.loadImage(for: asset, maxSize: maxSize)` 호출로 변경.

### 2. SimilarityAnalysisQueue — assignPersonIndicesForGroup 수정
**파일**: `SimilarityAnalysisQueue.swift`

`assignPersonIndicesForGroup` 메서드의 `for assetID in assetIDs` 루프 진입 전에 프리로드 추가:

```swift
// === 이미지 프리로드 (병렬) ===
// 2200px 이미지를 그룹 전체에 대해 병렬 로드
let preloadStart = CFAbsoluteTimeGetCurrent()
let preloadResults = await imageLoader.loadImages(
    for: photos,
    maxSize: SimilarityConstants.personMatchImageMaxSize
)
// photos 배열 순서 기준으로 assetID → CGImage 딕셔너리 구성
var preloadedImages: [String: CGImage] = [:]
for (index, cgImage) in preloadResults {
    if let image = cgImage, index < photos.count {
        preloadedImages[photos[index].localIdentifier] = image
    }
}
let preloadMs = (CFAbsoluteTimeGetCurrent() - preloadStart) * 1000
Logger.similarPhoto.debug("Preloaded \(preloadedImages.count)/\(assetIDs.count) images in \(String(format: "%.0f", preloadMs))ms")

// 취소 체크: 프리로드 후
guard !Task.isCancelled else {
    Logger.similarPhoto.debug("Cancelled after preload")
    return result
}
```

루프 내 기존 로딩 코드를 프리로드 딕셔너리 조회로 교체:
```swift
// 변경 전
var cgImage: CGImage? = nil
if let photo = photoMap[assetID] {
    cgImage = try? await imageLoader.loadImage(
        for: photo,
        maxSize: SimilarityConstants.personMatchImageMaxSize
    )
}

// 변경 후
let cgImage = preloadedImages[assetID]
```

루프 내 각 사진 처리 완료 후 메모리 해제:
```swift
// 해당 사진의 YuNet/SFace/매칭 처리가 끝난 시점에 추가
preloadedImages[assetID] = nil  // 2200px CGImage 참조 해제 (~19MB/장)
```

### 3. 죽은 코드 제거 — photoMap
프리로드 적용 후 `photoMap` (기존 637행)은 루프 내 로딩에만 사용되므로 불필요해짐.
해당 라인 제거:
```swift
// 제거 대상
let photoMap = Dictionary(uniqueKeysWithValues: photos.map { ($0.localIdentifier, $0) })
```

### 주의: photos와 assetIDs 순서 불일치
호출부에서 `groupPhotos = photos.filter { ... }`로 생성하므로,
`photos` 배열 순서와 `assetIDs` 순서가 다를 수 있음.
→ 딕셔너리 키를 `photos[index].localIdentifier`로 사용하여 해결.

## 수정 파일 목록
| 파일 | 변경 |
|------|------|
| `SimilarityImageLoader.swift` | loadImages에 maxSize 파라미터 추가 |
| `SimilarityAnalysisQueue.swift` | assignPersonIndicesForGroup에 프리로드 로직 추가, 루프 내 로딩 제거 |

## 검증
1. 로그로 프리로드 시간 확인: `Preloaded X/Y images in Zms`
2. 뷰어 진입 시 프리로드가 자동 일시정지되는지 확인 (pause/resume 연동)
3. +버튼 표시까지 체감 속도 개선 확인
4. 스와이프 시 뷰어 LOD1이 정상적으로 도착하는지 확인
