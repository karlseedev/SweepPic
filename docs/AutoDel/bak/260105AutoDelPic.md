# 저품질 사진 분류 기준 (최종 통합안)

## 목적
- 자동 정리에서 "저품질 사진"을 정량적으로 판별한다.
- 두 가지 운영 모드로 분리한다:
  - **Recall 모드**: 다양한 저품질을 놓치지 않으면서도 정확하게 분류
  - **Precision 모드**: 오탐 최소화(안전 모드, 기본값 권장)

---

## 공통 분석 전제
- 대표 프레임 기준 (사진/라이브포토/비디오 모두 적용)
- 다운스케일 후 분석 (긴 변 256~320px, 또는 64x64 요약 프레임)
- 정량 지표는 동일하며, 모드별 임계값/조합 규칙만 다름

---

## 공통 예외 규칙 (Safe Guard)
저품질로 판정되었더라도 아래 조건 중 하나라도 만족하면 **즉시 정상으로 복구**.

- 즐겨찾기: `isFavorite == true` → 모든 저품질 판정 무효
- 편집됨: `hasAdjustments == true` → 모든 저품질 판정 무효
- 심도 효과: `mediaSubtypes.contains(.depthEffect)` → Blur 판정만 무효
- 얼굴 선명도: `faceCaptureQuality >= 0.4` → Blur 판정만 무효

**스크린샷 처리**
- 저품질로 분류하지 않는다.
- 별도 "정리 대상(스크린샷)" 카테고리로 분리한다.

---

## Recall 모드 (놓치지 않으면서 정확하게)
**원칙**
- 강한 실패 신호 1개면 저품질 확정
- 약한 실패 신호는 2개 이상 조합 시 저품질 확정
- 예외 규칙은 강하게 적용

### A) 강한 실패 신호 (1개로 확정)
1) **주머니샷 복합 조건**
- `mean_luma < 0.10`
- `RGB std < 15`
- `Laplacian variance < 50`
- `corner-center diff < 0.05`

2) **극단 노출**
- `mean_luma < 0.10` 또는 `mean_luma > 0.90`

3) **심각 블러**
- `Laplacian variance < 50`

4) **극단 단색**
- `RGB std < 10` AND (`mean_luma < 0.15` OR `mean_luma > 0.85`)

5) **극단 렌즈 가림**
- `corner_mean < center_mean * 0.4` OR `corner mean < 0.15`

### B) 약한 실패 신호 (2개 이상이면 확정)
- 노출 부족: `mean_luma < 30/255` OR 어두운 픽셀(0~50) `>= 40%`
- 과다 노출: `mean_luma > 217/255` OR 밝은 픽셀(200~255) `>= 65%`
- 블러: `Laplacian variance < 100`
- 렌즈 가림: `corner_mean < center_mean * 0.4`
- 단색/무의미: `RGB std < 10`
- 저해상도: `min_dim < 1024` OR `MP < 1.0` (단독 사용 금지)

---

## Precision 모드 (오탐 최소화, 기본값 권장)
**원칙**
- 명백한 실패만 분류
- 모호한 지표(렌즈 가림/단색/저해상도/주머니샷)는 제외

### 저품질 확정 조건
1) **극단 노출**
- `mean_luma < 30` OR `mean_luma > 230`

2) **심한 블러**
- `Laplacian variance < 100`

### 의도적으로 제외한 항목
- 렌즈 가림: 비네팅/예술 사진 오탐 가능성
- 단색/무의미: 문서/메모 사진 오탐 가능성
- 저해상도: 오래된 추억 사진 오탐 가능성
- 주머니샷 복합: 야경/실루엣 오탐 가능성

---

## 판별 파이프라인 (공통)
1) **메타데이터 필터 (Fast)**
- 즐겨찾기/편집됨 → 즉시 제외
- 스크린샷 → 별도 카테고리 분리
- 심도효과 → Blur 판정만 제외

2) **밝기 분석 (64x64 썸네일)**
- 평균 휘도 계산
- 노출 조건 충족 여부 확인

3) **선명도 분석**
- Laplacian variance 계산
- Blur 조건 충족 여부 확인
- 얼굴 선명도 확인 후 Blur 판정 무효 처리

4) **부가 분석 (Recall 모드 전용)**
- RGB 표준편차
- 3x3 그리드 밝기 비교(렌즈 가림)
- 저해상도 확인

5) **저품질 후보 수집**
- Recall/Precision 모드 규칙 적용
- 후보 50장 수집 시 종료

---

## 파라미터 요약

### 공통 지표
- mean_luma (0~255)
- clip_black_ratio (0~50)
- clip_white_ratio (200~255)
- Laplacian variance
- RGB std
- corner_mean / center_mean
- min_dim / MP

### Recall 모드 임계값
- mean_luma: < 30/255 (어두움), > 217/255 (밝음)
- Laplacian: < 100 (블러), < 50 (심각)
- RGB std: < 10
- corner/center: < 0.4
- 저해상도: min_dim < 1024 또는 MP < 1.0

### Precision 모드 임계값
- mean_luma: < 30 또는 > 230
- Laplacian: < 100

---

## 모드 선택 가이드
- **Precision(기본)**: 안전하게 정리하고 싶은 사용자
- **Recall**: 공격적으로 정리하고 싶은 사용자
