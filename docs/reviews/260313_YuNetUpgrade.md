**주요 지적사항 (심각도 순)**

1. **High: Phase 1 변환 경로가 현재 프로젝트 이력/환경과 충돌합니다.**  
근거: 계획은 ONNX를 `ct.convert()`로 바로 변환하도록 되어 있음 ([260313YuNetUpgrade.md:36](/Users/karl/Project/Photos/iOS/docs/similar/260313YuNetUpgrade.md#L36)).  
근거: 기존 완료 문서에는 “ONNX 직접 변환 실패 → onnx2torch 경유” 이력이 명시돼 있음 ([260114SimilarEdit4.md:230](/Users/karl/Project/Photos/iOS/docs/similar/complete/260114SimilarEdit4.md#L230)).  
추가 확인: 현재 로컬은 `coremltools 6.3.0 + protobuf 4.x` 조합으로 기본 import도 오류가 나며, `onnx2torch`도 미설치 상태입니다.  
영향: 계획대로 실행 시 Phase 1에서 바로 막힐 가능성이 높습니다.

2. **High: Phase 3 API 변경 항목이 컴파일 영향 범위를 덜 잡았습니다.**  
근거: 문서에서 `YuNetOutputNames.outputs(for inputSize:)` 형태 변경을 예고 ([260313YuNetUpgrade.md:137](/Users/karl/Project/Photos/iOS/docs/similar/260313YuNetUpgrade.md#L137))했는데, 실제 코드에는 기존 시그니처를 쓰는 호출부가 존재합니다 ([YuNetDebugTest.swift:155](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/SimilarPhoto/Analysis/YuNet/YuNetDebugTest.swift#L155)).  
영향: 문서대로 구현하면 디버그 빌드 컴파일 에러 가능성이 큽니다.

3. **Medium: 출력 이름 확인 코드 예시가 coremltools API와 맞지 않을 가능성이 큽니다.**  
근거: 문서 예시는 `for out in m.output_description: print(out.name)` 형태 ([260313YuNetUpgrade.md:52](/Users/karl/Project/Photos/iOS/docs/similar/260313YuNetUpgrade.md#L52))인데, `output_description` 반복자는 보통 문자열 키를 반환합니다.  
영향: 출력 이름 확인 단계가 실패하거나 잘못된 정보로 이어질 수 있습니다.

4. **Medium: 성능 리스크/검증 설계가 목표 대비 약합니다.**  
근거: 리스크 표에서 “추론 속도 과다”를 낮음으로 둠 ([260313YuNetUpgrade.md:207](/Users/karl/Project/Photos/iOS/docs/similar/260313YuNetUpgrade.md#L207)).  
`320→960`은 입력 픽셀 수가 약 9배라 지연 증가 가능성이 큽니다.  
또한 비교 방식이 단일 타이밍 중심([260313YuNetUpgrade.md:161](/Users/karl/Project/Photos/iOS/docs/similar/260313YuNetUpgrade.md#L161))이라 워밍업/반복 측정(중앙값, p95) 기준이 필요합니다.

5. **Medium: End-to-end 목표(+버튼 개선)와 검증 연결이 부족합니다.**  
근거: 검증이 주로 FaceDebug 수동 확인에 치우침 ([260313YuNetUpgrade.md:188](/Users/karl/Project/Photos/iOS/docs/similar/260313YuNetUpgrade.md#L188)).  
실제 파이프라인에는 Vision fallback/슬롯 매칭 정책이 함께 작동하므로, “+버튼 개수 개선”은 배치 분석 결과로도 확인해야 합니다.

**총평**  
방향은 타당합니다. 다만 **변환 툴체인 사전고정(버전/의존성), API 변경 영향 범위, 성능 검증 방법** 3가지를 보완해야 계획 목표를 안정적으로 달성할 수 있습니다.

**보완 권장 (문서에 추가 권장)**

1. 변환 사전조건 섹션 추가: `coremltools/onnx/onnx2torch/protobuf` 버전 고정 + 실패 시 우회 경로.  
2. 코드 영향 범위 체크리스트 추가: `YuNetDebugTest` 포함 호출부 전수 확인.  
3. 실험 기준 추가: 워밍업 3회 + 20회 반복, median/p95, 허용 배수 기준.  
4. 최종 검증에 배치 지표 추가: 문제 샘플셋에서 +버튼 개선율/오탐 증가율.

**참고한 외부 자료**

- OpenCV YuNet 모델 카드: https://github.com/opencv/opencv_zoo/tree/main/models/face_detection_yunet  
- OpenCV Zoo 이슈(입력 크기/리사이즈 관련): https://github.com/opencv/opencv_zoo/issues/44  
- Core ML Tools 변환 가이드: https://apple.github.io/coremltools/docs-guides/source/convert-learning-models.html  
- Core ML Tools FAQ(ONNX 관련 안내): https://apple.github.io/coremltools/docs-guides/source/faqs.html