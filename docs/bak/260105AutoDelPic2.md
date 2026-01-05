# 저품질사진 분류 기준 (v1)

## 판정 원칙
- 대표 프레임(사진/라이브포토/비디오) 기준으로 분석한다.
- 저품질 조건 중 **하나라도 충족**하면 저품질로 분류한다.

## 저품질 판정 기준 (정량)

1) 노출 부족 (Underexposed)
- 평균 휘도: `mean_luma < 30/255 (~0.12)`
- 또는 어두운 픽셀 비율(0~50): `>= 40%`
- 심각 조건: `mean_luma < 0.10`

2) 과다 노출 (Overexposed)
- 평균 휘도: `mean_luma > 0.85 (~217/255)`
- 또는 밝은 픽셀 비율(200~255): `>= 65%`

3) 흐림/모션 블러 (Blur)
- `Laplacian variance < 100`
- 심각 조건: `< 50`

4) 렌즈 가림 (손가락/비네팅)
- 3x3 그리드 기준 `corner_mean < center_mean * 0.4`
- 또는 한 모서리 `mean < 0.15`

5) 단색/무의미 (저대비)
- `RGB 표준편차 < 10`

6) 주머니 속 사진 (복합)
- `mean_luma < 0.10`
- `RGB std < 15`
- `Laplacian var < 50`
- `corner-center diff < 0.05`

7) 저해상도
- `min(width, height) < R_min` 또는 `MP < MP_min`
- v1 제안: `R_min = 1024`, `MP_min = 1.0`

## 제외 규칙 (저품질에서 제외)
- 즐겨찾기: `isFavorite == true`
- 편집됨: `hasAdjustments == true`
- 심도 효과: `mediaSubtypes.contains(.depthEffect)`
- 얼굴 선명도 보존: `VNFaceCaptureQuality >= 0.4` 얼굴이 1개라도 있으면 Blur 조건 무효

## 스크린샷 처리
- 저품질에서 제외한다.
- 필요 시 "정리 대상(별도 카테고리)"로 분리한다.
