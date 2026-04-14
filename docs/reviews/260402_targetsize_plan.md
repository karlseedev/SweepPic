**Findings**

1. High: 계획의 핵심 전제가 Apple 공식 설명과 충돌합니다. [scalable-waddling-squirrel.md](/Users/karl/.claude/plans/scalable-waddling-squirrel.md):44-75 는 `.aspectFit` + `targetSize = (S, S)` + `.exact` 조합에서 반환 이미지가 `S × S*(short/long)`라고 가정하지만, Photos SDK 헤더는 `PHImageRequestOptionsResizeModeExact`가 “delivered image is exactly targetSize”라고 설명합니다. 또 Apple 문서는 `aspectFit`을 “larger dimension fits the target size”로 설명합니다. 현재 문서의 수식은 “원본 비율 유지 + 패딩 없음”을 전제로만 맞습니다. 만약 실제 반환이 정확히 `S×S`라면, 현재 [FaceCropper.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/Analysis/FaceCropper.swift):146-157 의 bounding box 변환은 잘못된 좌표계를 보게 되어 크롭 위치 자체가 어긋날 수 있습니다. 이 계획은 `targetSize`를 정사각형으로 만들지 말고, 긴 변만 `clampedSize`로 맞춘 뒤 원본 종횡비를 유지한 직사각형 `CGSize(width: originalW*scale, height: originalH*scale)`로 요청하는 쪽이 안전합니다. 근거: [PHImageManager.h](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.0.sdk/System/Library/Frameworks/Photos.framework/Headers/PHImageManager.h):40-43, [PHImageManager.h](/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.0.sdk/System/Library/Frameworks/Photos.framework/Headers/PHImageManager.h):140-155, Apple docs https://developer.apple.com/documentation/photos/phimagecontentmode/default

2. Medium: 셀 크기 추정이 실제 레이아웃과 정확히 맞지 않습니다. [scalable-waddling-squirrel.md](/Users/karl/.claude/plans/scalable-waddling-squirrel.md):29-31 의 `UIScreen.main.bounds.width / 2 * scale` 는 현재 구현의 실제 셀 폭 `(collectionView.bounds.width - gridSpacing) / 2`, `minCellSize` 보장과 다릅니다. 실제 셀 계산은 [PersonPageViewController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/UI/PersonPageViewController.swift):84-87, [PersonPageViewController.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/UI/PersonPageViewController.swift):281-283 에 있습니다. iPhone portrait에서는 근사치로 통하지만, iPad, Split View, 회전, 향후 spacing 변경에는 쉽게 어긋납니다. `loadFaceImage()`가 실제 렌더링 크기를 모르므로, 셀 픽셀 크기를 호출부에서 넘기거나 collectionView 기반으로 계산하는 항목이 계획에 추가돼야 합니다.

3. Medium: 검증 계획이 가장 중요한 리스크를 직접 검증하지 않습니다. [scalable-waddling-squirrel.md](/Users/karl/.claude/plans/scalable-waddling-squirrel.md):142-148 은 UI/메모리만 보는데, 이 변경의 성패는 “PhotoKit이 실제로 어떤 크기의 이미지를 반환하느냐”에 달려 있습니다. 최소한 `requestImage` 직후 `requested targetSize`, 반환 `cgImage.width/height`, 최종 `croppedImage` 크기를 로그로 남기는 검증 항목이 필요합니다. 특히 4:3, 16:9, 파노라마 각각 한 장씩은 별도로 확인해야 합니다.

4. Low: 예시 몇 개가 재현 가능한 입력으로 완전히 정의돼 있지 않습니다. [scalable-waddling-squirrel.md](/Users/karl/.claude/plans/scalable-waddling-squirrel.md):89-96 은 `bb.height=0.8`만 있고 `bb.width`가 없습니다. [scalable-waddling-squirrel.md](/Users/karl/.claude/plans/scalable-waddling-squirrel.md):98-103 도 `bb=0.30` 뒤에 “facePixelW > facePixelH 가정”이 붙어 있어, 검산용 예시라기보다 설명용 예시입니다. 문서 품질 차원에서는 `CGRect(x:, y:, width:, height:)` 형태로 통일하는 편이 낫습니다.

**Math Check**

`FaceCropper` 기준 수식 자체는 조건부로 맞습니다. [FaceCropper.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/Analysis/FaceCropper.swift):166-175 가 padding을 각 축에 30%씩 더해 `1.6x`, [FaceCropper.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/Analysis/FaceCropper.swift):181-191 이 `max(width,height)` 정사각형으로 만들고, [FaceCropper.swift](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/Analysis/FaceCropper.swift):197-209 이 최대 크기를 `min(imageWidth, imageHeight, rect.width)`로 제한하므로:

`effectiveDim = min(max(facePixelW, facePixelH) * 1.6, shortSide)`

는 맞습니다. 그리고 “반환 이미지가 원본의 균일 축소본이고 패딩이 없다”는 전제하에  
`crop = effectiveDim * S / longSide`,  
`S >= cellPixels * longSide / effectiveDim`  
도 맞습니다. 문서의 수학 문제라기보다, 그 수학이 성립하는 `PhotoKit` 반환 모델을 아직 입증하지 못한 것이 핵심 문제입니다.

**Conclusion**

목표 자체는 한 파일 수정으로 달성 가능해 보이지만, 현재 계획은 그대로 구현하기엔 부족합니다. 특히 정사각형 `targetSize`와 `.exact` 조합에 대한 가정이 위험합니다. 안전한 방향은:

1. `clampedLongSide`만 계산한다.
2. `targetSize`는 원본 종횡비를 유지한 직사각형으로 요청한다.
3. 검증 항목에 실제 반환 이미지 크기 로깅을 추가한다.

참고로 Apple 공식 확인은 로컬 SDK 헤더와 공식 문서 URL까지는 확인했지만, 이 환경에서는 실기기 Photo Library에 대해 `requestImage`를 직접 실행해 실측하진 못했습니다. 그래서 런타임 동작은 문서/헤더 기반으로 판단했고, 최종 확정은 앱 내부 로그 검증이 필요합니다.