1차 결론부터 말하면, **지금 코드 기준으로 Vision 1차 감지를 바로 완전 제거하는 건 리스크가 있습니다.**  
성능 개선 효과는 크지만, YuNet/SFace 실패 시 안전망이 부족합니다.

**주요 findings (심각도 순)**
- **High**: YuNet/SFace 또는 고해상도 이미지 로드 실패 시, 주석과 달리 Vision 데이터로 진행하지 않고 해당 사진 얼굴 결과를 비워버립니다.  
  참조: [SimilarityAnalysisQueue.swift:664](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift:664), [SimilarityAnalysisQueue.swift:667](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift:667), [SimilarityAnalysisQueue.swift:672](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift:672)
- **High**: YuNet 추론이 throw되면 Vision fallback 분기로 가지 않고 바로 빈 결과 처리됩니다.  
  참조: [SimilarityAnalysisQueue.swift:678](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift:678), [SimilarityAnalysisQueue.swift:681](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift:681)
- **Medium**: `rawFacesMap`는 사실상 fallback(.basic/.extended)과 디버그 API용입니다. fallback을 끄면 1차 Vision 감지는 순수 오버헤드입니다.  
  참조: [SimilarityAnalysisQueue.swift:316](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift:316), [SimilarityAnalysisQueue.swift:329](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift:329), [SimilarityAnalysisQueue.swift:685](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift:685)
- **Medium**: 코드 자체가 “YuNet이 놓친 작은 얼굴”을 Vision으로 보완하도록 설계되어 있어, 완전 제거 시 작은 얼굴 리콜 저하 가능성이 있습니다.  
  참조: [SimilarityAnalysisQueue+ExtendedFallback.swift:23](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue+ExtendedFallback.swift:23), [SimilarityAnalysisQueue.swift:751](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift:751), [FaceComparisonDebug.swift:143](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/Debug/FaceComparisonDebug.swift:143)
- **Low**: `DetectedFace`는 프로덕션 뷰어 얼굴 확대/비교 경로에서 직접 쓰이지 않고 `CachedFace`가 사용됩니다.  
  참조: [ViewerViewController+SimilarPhoto.swift:549](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/Viewer/ViewerViewController+SimilarPhoto.swift:549), [FaceButtonOverlay.swift:410](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceButtonOverlay.swift:410), [FaceComparisonViewController.swift:679](/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceComparisonViewController.swift:679)

**질문별 답변**
1. `rawFacesMap`은 `assignPersonIndicesForGroup` 내부에서 **fallback 용도 + debug test API 용도**가 전부입니다. fallback 제거 시 실질 사용처 거의 사라집니다.  
2. Vision 우위 edge case는 코드상 “작은 얼굴 보완”이 명시돼 있습니다. 저해상도/특정 포즈 일반론보다, **현재 코드 근거로는 작은 얼굴 리콜**이 핵심입니다.  
3. YuNet 모델 로드 실패 시 파이프라인이 “크래시”되진 않지만, 얼굴 결과가 빈 배열로 떨어져 **그룹 형성 품질이 크게 깨질 리스크**가 있습니다.  
4. `DetectedFace`는 뷰어 얼굴 확대 등 핵심 UI 경로에서 직접 사용되지 않습니다. 그쪽은 `CachedFace` 기반입니다.  
5. 숨은 의존성은 주로 디버그/테스트 코드(`FaceComparisonDebug`, `ExtendedFallbackTester`, `testVisionFallback*`)입니다. 제거 시 같이 정리해야 합니다.  
6. 관련 파일 추가 확인 완료: `SimilarityAnalysisQueue+ExtendedFallback`, `VisionFallbackMode`, `YuNetFaceDetector`, `SFaceRecognizer`, `SimilarityImageLoader`, `SimilarityCache`, 뷰어/비교 UI 경로까지 확인했습니다.

원하시면 다음으로, “Vision 완전 제거” 전제로 **안전한 전환 체크리스트(필수 수정 포인트 5개)**를 바로 정리해드리겠습니다.