# Research: 유사 사진 정리 기능

**Date**: 2026-01-02
**Branch**: `002-similar-photo`
**Status**: Complete

---

## 1. Vision Framework 이미지 유사도 분석

### Decision
`VNGenerateImageFeaturePrintRequest`를 사용하여 이미지 간 유사도를 측정

### Rationale
- Apple 공식 Vision Framework로 iOS에 최적화
- 별도 ML 모델 로딩 없이 시스템 리소스 활용
- `computeDistance(_:to:)` 메서드로 두 이미지 간 거리 계산 가능
- WWDC 2019/2021에서 검증된 기술

### Alternatives Considered
| 대안 | 장점 | 단점 | 탈락 이유 |
|------|------|------|----------|
| pHash (Perceptual Hash) | 매우 빠름 | 연속 촬영 사진 구분 어려움 | 유사도 정밀도 부족 |
| Core ML 커스텀 모델 | 높은 정확도 | 모델 크기, 메모리 사용량 | 복잡도 증가, 유지보수 부담 |
| 서버 기반 분석 | 강력한 처리 능력 | 네트워크 필요, 프라이버시 | 오프라인 지원 불가 |

### Key Implementation Details
- 분석 이미지 해상도: **긴 변 480px 이하**
- `PHImageManager.contentMode = .aspectFit` (패딩/크롭 금지)
- 유사도 임계값: **거리 10.0 이하**

---

## 2. Vision Framework 얼굴 감지

### Decision
`VNDetectFaceRectanglesRequest`를 사용하여 얼굴 위치 감지

### Rationale
- Vision Framework 통일로 API 일관성 유지
- `boundingBox` 반환으로 얼굴 위치 정보 제공
- 실시간 처리에 충분한 성능 (30ms 이하)

### Alternatives Considered
| 대안 | 장점 | 단점 | 탈락 이유 |
|------|------|------|----------|
| VNDetectFaceLandmarksRequest | 76개 특징점 제공 | 처리 시간 증가 | MVP에서 불필요한 복잡도 |
| Core ML Face Detection | 커스텀 학습 가능 | 별도 모델 필요 | 기본 제공 API로 충분 |
| AVFoundation | 실시간 카메라 최적화 | 정적 이미지에 부적합 | 사용 케이스 불일치 |

### Key Implementation Details
- 좌표계: Vision 정규화 좌표 (0~1, 원점 좌하단)
- Y축 반전 필요: `UIKit 좌표 = (1 - boundingBox.maxY)`
- 유효 얼굴 기준: 화면 너비의 **5% 이상**

---

## 3. 인물 매칭 알고리즘

### Decision
하이브리드 방식: 1차 위치 기반 + 2차 Feature Print 검증

### Rationale
- 연속 촬영 사진은 구도가 거의 동일 → 위치 기반 매칭 ~90% 정확도
- Feature Print 검증으로 불일치 사진은 비교 그리드에서 자동 제외 (spec FR-030)
- 빠른 초기 표시 + 백그라운드 검증으로 UX 최적화

### Alternatives Considered
| 대안 | 장점 | 단점 | 탈락 이유 |
|------|------|------|----------|
| 위치 기반만 | 매우 빠름 | 위치 변경 시 오류 | 정확도 부족 |
| Feature Print만 | 높은 정확도 | 초기 표시 지연 | UX 저하 |
| Face ID/Recognition | 정확한 인물 식별 | iOS 미제공 | 사용 불가 |

### Key Implementation Details
- 위치 정렬: X좌표 오름차순, X 동일 시 Y 내림차순
- 제외 임계값: 얼굴 크롭 Feature Print 거리 **1.0 이상**이면 다른 인물로 판정하여 비교 그리드에서 제외
- 인물 번호: 좌→우, 위→아래 순서

---

## 4. 캐시 설계

### Decision
`SimilarityCache` 클래스로 분석 결과 메모리 캐싱, LRU Eviction

### Rationale
- 뷰어에서 그리드 분석 결과 재사용 (재분석 방지)
- 메모리 제한으로 무한 증가 방지
- 상태 기반 관리로 분석 중복 방지

### Key Implementation Details
- 캐시 크기: **최대 500장**
- LRU Eviction: 오래된 항목부터 제거
- 상태 모델: `notAnalyzed` → `analyzing` → `analyzed`
- 저장 항목: CachedFace 배열, 그룹 멤버, 유효 인물 슬롯

---

## 5. 테두리 애니메이션

### Decision
`CAShapeLayer` + `CAKeyframeAnimation`으로 빛이 도는 테두리 구현

### Rationale
- Core Animation으로 GPU 가속
- `strokeStart/strokeEnd` 애니메이션으로 빛 이동 효과
- 메인 스레드 블로킹 없음

### Key Implementation Details
- 레이어: `CAShapeLayer`로 사각형 path 생성
- 애니메이션: 시계방향 회전, 빛 색상 흰색 그라데이션
- 최적화: `didEndDisplaying` 시 애니메이션 제거

---

## 6. 얼굴 크롭 규칙

### Decision
bounding box + 30% 여백 + 정사각형 조정

### Rationale
- 30% 여백으로 얼굴 주변 맥락 포함
- 정사각형으로 2열 그리드 표시 최적화
- 경계 처리로 이미지 밖 크롭 방지

### Key Implementation Details
- 여백: bounding box 너비/높이 각각 **30% 추가**
- 비율: **1:1 정사각형**
- 경계 처리: 중심 고정, 경계 내 최대 크기로 축소

---

## 7. 분석 타이밍 및 동시성

### Decision
스크롤 멈춤 후 0.3초 디바운싱, 최대 5개 동시 분석

### Rationale
- 디바운싱으로 불필요한 분석 방지
- 동시성 제한으로 메모리/CPU 관리
- 스크롤 성능 유지

### Key Implementation Details
- 디바운싱: **0.3초**
- 동시 분석: **최대 5개**
- 취소 규칙: 스크롤 재개 시 `source=grid` 작업만 취소, `source=viewer`는 유지

---

## 8. iOS 버전별 UI 분기

### Decision
iOS 16~25: 커스텀 FloatingUI, iOS 26+: 시스템 네비바/툴바 (Liquid Glass)

### Rationale
- iOS 26+ Liquid Glass 자동 적용으로 시스템 일관성
- 기존 iOS 버전은 커스텀 UI로 동일한 경험 제공

### Key Implementation Details
```swift
if #available(iOS 26.0, *) {
    // 시스템 네비바/툴바 사용
} else {
    // 커스텀 FloatingTitleBar/TabBar 사용
}
```

---

## 9. 접근성 고려사항

### Decision
VoiceOver 활성화 시 기능 전체 비활성화

### Rationale
- 얼굴 표정/눈 감김 비교는 시각 기반 기능
- 시각장애인에게 실질적 사용 가치 없음
- 모션 감소 설정 시 정적 테두리로 대체

### Key Implementation Details
- VoiceOver: `UIAccessibility.isVoiceOverRunning` 체크
- 모션 감소: `UIAccessibility.isReduceMotionEnabled` 체크

---

## References

- [Apple Developer - VNGenerateImageFeaturePrintRequest](https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequest)
- [Apple ML Research - Recognizing People in Photos](https://machinelearning.apple.com/research/recognizing-people-photos)
- [WWDC 2019 - Image Similarity](https://developer.apple.com/videos/play/wwdc2019/222/)
- [WWDC 2021 - Vision Updates](https://developer.apple.com/videos/play/wwdc2021/10040/)
- PRD 문서: [prd9.md](../../docs/prd9.md), [prd9algorithm.md](../../docs/prd9algorithm.md)
