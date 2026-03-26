검토 결론: 계획 방향은 맞지만, 현재 상태로는 `G1/G2`는 가능해도 `G3/G4`를 안정적으로 달성하기엔 부족합니다.

**Findings (심각도 순)**
1. `[높음]` 에러/취소/클라우드 대기 상태가 UI로 전달되지 않아 `G3` 달성이 불완전합니다.  
`docs/260213iCloud.md:430`은 시그니처 유지(`completion(nil,false)`)를 제안하지만, 현재 `ImagePipeline`은 `info`를 버리고 `UIImage? + isDegraded`만 전달합니다(`Sources/AppCore/Services/ImagePipeline.swift:356`, `Sources/AppCore/Services/ImagePipeline.swift:417`, `Sources/AppCore/Services/ImagePipeline.swift:454`).  
`completion`에 상태 enum(예: success/degraded/inCloudWaiting/error/cancelled)을 추가해야 합니다.

2. `[높음]` 문서의 “뒤로 가기 시 추가 작업 불필요”는 실제 코드와 다릅니다.  
문서는 `deinit` 취소로 충분하다고 하나(`docs/260213iCloud.md:375`), 실제 `deinit`은 `requestCancellable`만 취소하고 `fullSizeRequestCancellable`은 취소하지 않습니다(`SweepPic/SweepPic/Features/Viewer/PhotoPageViewController.swift:221`).  
`fullSizeRequestCancellable`도 `deinit`/`viewDidDisappear`에서 취소해야 합니다.

3. `[높음]` iCloud/로컬 판별 근거가 잘못되었습니다.  
`sourceType`은 자산 출처 타입이지 “원본이 로컬에 있는지” 보장이 아닙니다. 현재 코드도 잘못된 가정이 들어가 있습니다(`SweepPic/SweepPic/Features/Grid/PhotoCell.swift:818`).  
로컬 부재 판별은 `requestImage` 결과의 `image == nil` + `PHImageResultIsInCloudKey`로 처리해야 합니다.

4. `[중간]` 문서의 현황/경로/전제가 실제 코드와 불일치합니다.  
파일 경로가 실제보다 한 단계 짧습니다(`docs/260213iCloud.md:77` vs 실제 `SweepPic/SweepPic/...`).  
또한 문서는 prefetch 취소 흐름을 핵심 전제로 설명하지만(`docs/260213iCloud.md:221`), 실제 `GridViewController`는 prefetch/cancel을 비활성화했습니다(`SweepPic/SweepPic/Features/Grid/GridViewController.swift:914`).

5. `[중간]` preheat stop 조건 누락입니다.  
현재 `startCaching`은 `targetSize`로 시작하고(`Sources/AppCore/Services/ImagePipeline.swift:499`), `stopCaching`은 `PHImageManagerMaximumSize`로 중지하고 있습니다(`Sources/AppCore/Services/ImagePipeline.swift:511`). 캐싱 start/stop 매칭 불일치가 생길 수 있는데, 계획에서 이 리스크를 다루지 않았습니다.

6. `[중간]` 계획 내부에 옵션 관리 충돌이 있습니다.  
2-1에서는 “공유 options를 직접 수정하면 안 됨”이라 했는데(`docs/260213iCloud.md:310`), 1-5에서는 스크롤 중 `thumbnailOptions`를 토글하는 방향을 제안합니다(`docs/260213iCloud.md:229`).  
런타임 토글은 경쟁 상태를 만들 수 있으니 요청별 복사 옵션으로 처리해야 합니다.

7. `[중간]` 자동 재시도를 파이프라인 내부 공통 정책으로 넣는 건 부작용 위험이 큽니다.  
`docs/260213iCloud.md:468` 방식은 그리드/뷰어/앨범 모두에 동일 적용되어 네트워크 낭비, 중복 요청, 통계 왜곡 가능성이 있습니다. 재시도는 UI 계층에서 명시적으로(뷰어 중심) 제어하는 게 안전합니다.

8. `[중간]` 테스트 시나리오 보강이 필요합니다.  
현재 표(`docs/260213iCloud.md:633`)에 아래가 없습니다: 권한 `.limited`/거부, iCloud 비활성/로그아웃, Low Data Mode, 에러코드별 재시도 정책 검증.

**요약 판단**
1. 현재 계획은 “기능 켜기” 관점에서는 충분하지만, “상태 모델링/취소/오류 분류”가 약해 실제 사용자 경험 목표(G3, G4) 달성에는 미흡합니다.
2. 특히 `ImagePipeline` 결과 모델을 먼저 확장한 뒤(상태 포함), UI/재시도/플레이스홀더를 붙이는 순서로 재정렬하면 성공 확률이 높습니다.

**확인 필요 질문**
1. 1차 릴리즈에서 그리드의 iCloud 실패 상태를 “플레이스홀더 표시”까지 할지, “무표시 + 재시도 없음”으로 갈지 결정됐나요?
2. 셀룰러/Low Data Mode에서 다운로드 정책을 앱이 개입할지, 시스템 설정에만 맡길지 결정이 필요합니다.
3. 공유 앨범은 이번 릴리즈에서 조회만 지원인지(삭제/편집 제외) 범위를 명시해야 합니다.

**참고 소스**
- Apple Developer: `isNetworkAccessAllowed`  
https://developer.apple.com/documentation/photos/phimagerequestoptions/isnetworkaccessallowed
- Apple Support: iCloud Photos / Optimize Storage / 원본 다운로드(Wi-Fi 또는 cellular)  
https://support.apple.com/en-afri/108782
- Apple Support: Low Data Mode에서 iCloud Photos 업데이트 일시정지  
https://support.apple.com/en-us/HT210596
- Apple SDK Header(로컬): `PHImageManager.h`  
`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.0.sdk/System/Library/Frameworks/Photos.framework/Headers/PHImageManager.h`
- Apple SDK Header(로컬): `PHAsset.h`, `PhotosTypes.h`  
`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.0.sdk/System/Library/Frameworks/Photos.framework/Headers/PHAsset.h`  
`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.0.sdk/System/Library/Frameworks/Photos.framework/Headers/PhotosTypes.h`