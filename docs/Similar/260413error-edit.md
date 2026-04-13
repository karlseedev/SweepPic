# 얼굴 비교 화면 검은 화면 버그 → 결정론적 그룹 경계 확정

날짜: 2026-04-10 ~ 2026-04-13

## 버그 현상

얼굴 비교 화면(FaceComparisonViewController)에서 인물 전환 시 특정 인물(인물2, 인물5)에서 검은 화면만 나옴. 인물1, 인물3은 정상.

## 원인 분석

### 직접 원인: validPersonIndices와 photosForPerson()의 범위 불일치
- `validPersonIndices`: 그룹 전체 멤버(19장) 기준으로 계산
- `photosForPerson()`: ComparisonGroup의 selectedAssetIDs(최대 12장)에서만 필터링
- 12장에 없는 인물이 validPersonIndices에는 있으면 → 0개 셀 → 검은 화면

### 근본 원인: 비결정적 그룹 형성
- ±7장 범위로 lazy 분석 후 겹치면 병합(mergeOverlappingGroups)
- 같은 사진을 어디서 보느냐에 따라 그룹이 22장→23장→31장으로 변함
- 병합이 비결정성의 원인

## 논의 과정

### 1. ComparisonGroup 12장 제한
- `maxComparisonGroupSize = 12` (SimilarityConstants.swift)
- 주석은 "최대 8장"으로 남아있었음 (상수만 12로 변경, 주석 미수정)
- 그룹 전체(19장)에서 현재 사진 기준 거리순 12장만 선택

### 2. 그룹 크기 무제한 문제
- SimilarThumbnailGroup에는 상한 없음 (최소 3장만 검증)
- 50장 연사도 전부 하나의 그룹으로 묶일 수 있음
- 스크롤할 때마다 병합으로 그룹이 점점 커짐

### 3. 해결 방향 결정
- **A안**: validPersonIndices를 12장 기준으로 재계산 → 사용자 혼란 (뷰어에서 5명인데 비교에서 3명)
- **B안**: 12장 선택 시 모든 인물 커버 → 여전히 12장 제한, 부분적 해결
- **최종**: 그룹 경계 확정 + ComparisonGroup 제한 제거 + 병합 제거

### 4. 경계 확정 방식
- 기존 ±7장 분석(formGroups)은 그대로 유지
- 그룹이 분석 범위 끝에 걸쳐있을 때만 한 장씩 경계 확인
- "2번 분석"이 아니라 "기존 분석 + 경계 확인" (한 파이프라인)

### 5. confirmed 그룹 보호
- 경계 확인 완료된 그룹은 confirmedGroupIDs에 등록
- 다음 분석에서 confirmed 멤버를 분석 대상에서 제외
- prepareForReanalysis, T014.4 preliminary, T014.5-6 얼굴 감지 등 파이프라인 전체에서 보호
- 이유: prepareForReanalysis가 확정 그룹을 파괴하면 그룹이 쪼개짐

### 6. 성능 제약
- 얼굴 분석: ~200ms/장 (iPhone 13 Pro 기준, Load 15ms + YuNet 160ms + SFace 25ms)
- 50장 → ~10초, 100장 → ~20초
- maxBoundaryExpansion = 100 (한 방향당)

### 7. GPT Codex 리뷰 반영사항
- video/trashed 처리: 확장에서도 fetchPhotos()와 동일하게 건너뛰기 (끊기 X)
- 중복 감지: 과반수 → 1장이라도 겹치면 기존 그룹 반환
- confirmed 보호: prepareForReanalysis만 아니라 분석 범위에서 멤버 제외 (파이프라인 전체 보호)
- maxBoundaryExpansion 도달 시 confirmed 등록 안 함
- invalidateGroup/clear 시 confirmedGroupIDs 정리
- PHPhotoLibrary 변경 시 confirmedGroupIDs 전체 초기화

## 구현 계획

상세 계획: `/Users/karl/.claude/plans/abstract-munching-kitten.md`

### Phase 1: ComparisonGroup 제한 제거 (독립)
- maxComparisonGroupSize 상수 제거
- ComparisonGroup.init/create에서 prefix 제거
- FaceScanListViewController에서 prefix 제거

### Phase 2: 그룹 경계 확인 (핵심)
- resolveGroupBoundaries() 메서드 추가
- formGroupsForRange() 수정

### Phase 3: 병합 제거 + 확정 그룹 보호
- mergeOverlappingGroups() 제거
- confirmedGroupIDs 추가
- prepareForReanalysis에서 confirmed 멤버 보호 (분석 대상에서 제외)
- addGroupIfValid에서 중복 감지

## 수정 파일
- SimilarityConstants.swift
- SimilarPhotoGroup.swift
- FaceScanListViewController.swift
- SimilarityAnalysisQueue.swift
- SimilarityCache.swift
