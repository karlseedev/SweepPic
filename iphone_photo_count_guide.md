# iPhone 사진 개수 확인 방법

## 1. 설정 앱에서 확인 (가장 쉬운 방법)

1. **설정** 앱 열기
2. **[이름]** > **iCloud** 탭
3. **사진** 탭
4. **iCloud 사진** 섹션에서 사진 개수 확인

또는:

1. **설정** 앱 열기
2. **일반** > **iPhone 저장 공간**
3. **사진** 앱 탭
4. 저장 공간 사용량과 함께 사진/동영상 개수 표시

## 2. 사진 앱에서 직접 확인

### 방법 A: 라이브러리 전체 보기
1. **사진** 앱 열기
2. **라이브러리** 탭 (하단 중앙)
3. **모두 보기** 선택
4. 화면 상단에 총 사진/동영상 수 표시 (예: "15,234개 항목")

### 방법 B: 사진 수 선택 가능
1. **사진** 앱 열기
2. **선택** 버튼 탭 (오른쪽 상단)
3. 왼쪽 상단에 선택된 사진 수 표시
4. **전체 선택** 시 총 개수 확인 가능

## 3. Mac에서 확인 (동기화된 경우)

1. **사진** 앱 열기
2. 왼쪽 사이드바에서 **라이브러리**
3. 마지막 사진으로 이동 (Command+화살표 아래)
4. 사진 정보 보기 (Command+I)로 전체 개수 확인

## 4. 저장 공간으로 대략적 개수 추정

- **iPhone 설정** > **일반** > **iPhone 저장 공간**
- **사진** 앱의 저장 공간 사용량 확인
- 평균 사진 크기로 개수 추산:
  - HEIC: 2-4MB/장
  - JPEG: 3-6MB/장
  - Live Photo: 4-7MB/장

예: 사진 앱이 45GB 사용 중이라면 약 15,000-22,500장으로 추정

## 5. 프로그래밍 방식 (개발자용)

```swift
import Photos

// PHPhotoLibrary.requestAuthorization 필요
let options = PHFetchOptions()
options.includeAssetSourceTypes = [.typeUserLibrary, .typeiTunesSynced]
let allPhotos = PHAsset.fetchAssets(with: options)
print("총 사진 수: \(allPhotos.count)")
```

## 팁

- 사진 개수는 동영상 포함일 수 있음
- 삭제된 사진(최근 삭제된 항목)은 제외된 수치
- iCloud에만 있는 사진은 설정에서만 확인 가능