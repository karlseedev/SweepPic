# 유사사진 그룹 셀 효과 비교 테스트 (2026-02-10)

## 배경

현재 유사사진 그룹핑 시 썸네일 테두리에 흰색 그라데이션 빛이 도는 shimmer border 방식 사용 중.
촌스럽다는 피드백으로 대안 8가지를 쇼케이스로 구현하여 비교 테스트.

## 쇼케이스 파일

- `PickPhoto/Features/SimilarPhoto/UI/EffectShowcaseViewController.swift`
- 진입점: `SceneDelegate.swift` `#if DEBUG` 블록 주석 해제로 활성화

## 8가지 효과 비교

### 셀 0: 현재 (Shimmer) — 기존 방식
- `BorderAnimationLayer` 사용
- 흰색 그라데이션 빛이 사각형 테두리를 따라 1.5초 주기로 회전
- **평가**: 촌스러움, 교체 대상

### 셀 1: Stacked Cards — 겹친 카드
- 셀 뒤에 CALayer 2장 (오프셋 + 회전 ±2~3도)
- 우측 상단 `+3` 뱃지
- 애니메이션 없이 정적으로 "여러 장" 직관 전달

### 셀 2: Shadow Pulse — 그림자 맥동
- contentView에 systemBlue 그림자
- shadowOpacity 0.3~0.7, shadowRadius 4~10 반복 (1.5초)
- 은은하고 자연스러운 효과

### 셀 3: Corner Dots — 코너 도트
- 좌하단 5pt 파란 원형 뷰 3개
- 순차 fade-in + breathing 애니메이션
- 미니멀, 정보 전달력 높음

### 셀 4: Glass+Gradient — 블러 뱃지 + 색상 변화 (방법 1) :star:
- UIVisualEffectView (systemUltraThinMaterialDark) 블러 뱃지
- `contentView.backgroundColor`를 4색 순환 (보라→핑크→파랑→오렌지, 1.5초 간격)
- 블러가 색상 변화를 은은하게 감싸줌
- **주인님 선호: 가장 마음에 듦**

### 셀 5: Gradient Badge — 그라데이션 직접 배경 (방법 2)
- CAGradientLayer를 뱃지 배경 자체로 사용
- 4색 키프레임 순환 (4초), 블러 없이 선명
- 셀 4 대비 더 눈에 띄지만 덜 세련됨

### 셀 6: Scale + Badge — 크기 확대 + 뱃지
- 셀 4% 확대 (스프링 애니메이션)
- 우측 상단 18pt 원형 뱃지 (systemBlue)
- 그리드 레이아웃과 겹칠 수 있는 단점

### 셀 7: Intelligence Glow — Apple Intelligence 스타일
- CAShapeLayer 4개 겹침 (lineWidth 2~8, blur 0~12)
- 보라/핑크/파랑/오렌지 4색 순환
- 가장 화려하지만 성능 부담 큼

## 결론

**셀 4 (Glass+Gradient)** 채택 방향.
블러 뱃지 + 배경색 순환 방식이 세련되고 성능 부담 적음.

## 다음 단계

- [ ] 셀 4 방식을 실제 `GridViewController+SimilarPhoto.swift`에 적용
- [ ] 기존 `BorderAnimationLayer` 기반 shimmer 제거/교체
- [ ] 뱃지 내 표시 정보 확정 (아이콘 + 숫자)
- [ ] 스크롤 시 뱃지 표시/숨김 로직 연동
