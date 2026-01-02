# Requirements Quality Checklist: 유사 사진 정리 기능

**Purpose**: 구현 전 요구사항 품질 검증 (Author용)
**Created**: 2025-12-31
**Updated**: 2025-12-31
**Feature**: [spec.md](../spec.md)
**Focus**: UX + 성능 + 접근성 + 엣지 케이스 전체 범위

---

## Requirement Completeness (요구사항 완전성)

- [x] CHK001 - 테두리 애니메이션의 시각적 스펙(색상, 두께, 회전 속도)이 명시되어 있는가? [Spec §FR-007 - 흰색 그라데이션, 시계방향 회전]
- [x] CHK002 - "빛이 회전하는" 애니메이션의 구체적인 구현 방식이 정의되어 있는가? [Spec §FR-007]
- [x] CHK003 - 유사사진정리버튼의 정확한 아이콘 및 크기가 명시되어 있는가? [Spec §FR-010 - square.stack.3d.up]
- [x] CHK004 - + 버튼의 시각적 디자인(크기, 색상, 반투명도)이 정의되어 있는가? [Spec §FR-017a - 반투명 원형 배경]
- [x] CHK005 - 얼굴 비교 화면의 헤더/하단바 레이아웃이 상세히 정의되어 있는가? [Spec §FR-032, §FR-033]
- [x] CHK006 - 인물 순환 시 "크로스페이드" 애니메이션의 지속 시간이 명시되어 있는가? [Spec §FR-034 - 0.3초]

---

## Requirement Clarity (요구사항 명확성)

- [x] CHK007 - "유사도 거리 10.0"의 실제 의미와 예상 결과가 명확히 설명되어 있는가? [Spec §FR-002 - 0=동일, 0~5=거의 같음, 5~10=유사]
- [x] CHK008 - "화면 너비 5% 이상" 얼굴 크기의 측정 기준(뷰어 표시 크기 vs 원본 이미지)이 명확한가? [Spec §FR-013 - 뷰어에 표시되는 이미지 기준]
- [x] CHK009 - "앞뒤 7장 범위"가 현재 사진 포함/미포함인지 명확한가? [Spec §FR-001 - 앞 7장 + 뒤 7장 = 총 14장]
- [x] CHK010 - "좌→우, 위→아래 순서"의 정확한 정렬 기준(x좌표 우선 vs y좌표 우선)이 명시되어 있는가? [Spec §FR-015 - x좌표 우선 정렬]
- [x] CHK011 - 버튼 겹침 시 "자동 위치 조정"의 이동 방향 및 우선순위가 명확한가? [Spec §FR-016 - 좌→우→아래, 1.2배씩, 최대 4회]

---

## Requirement Consistency (요구사항 일관성)

- [x] CHK012 - 그리드와 뷰어의 유사 사진 판정 기준(3장 이상 + 얼굴)이 일관되게 적용되는가? [Spec §FR-003, §FR-004]
- [x] CHK013 - iOS 16~25와 iOS 26+의 버튼/UI 위치가 기능적으로 동등하게 정의되어 있는가? [Spec §FR-036~038]
- [x] CHK014 - Cancel 버튼 동작이 얼굴 비교 화면 전체에서 일관되게 정의되어 있는가? [Spec §FR-024]

---

## Acceptance Criteria Quality (수락 기준 품질)

- [x] CHK015 - "4탭 이내 삭제" 기준이 구체적인 탭 시퀀스로 정의되어 있는가? [Spec §SC-001 - 유사사진정리버튼→+버튼→사진선택→Delete]
- [x] CHK016 - "1초 이내 테두리 표시"의 측정 시작점이 명확한가? [Spec §SC-002 - 스크롤 멈춤 시점, 0.3초 디바운싱 포함]
- [x] CHK017 - 5만 장 라이브러리 테스트의 구체적 조건이 정의되어 있는가? [Spec §SC-004 - iPhone SE 2세대+, 인물 60%/풍경·음식 30%/스크린샷 10%]

---

## Scenario Coverage (시나리오 커버리지)

- [x] CHK018 - 유사 사진이 정확히 3장인 경계 조건의 동작이 명시되어 있는가? [Spec §FR-003 - 현재 사진 포함 3장 이상]
- [x] CHK019 - 모든 유사 사진에서 동일 인물이 감지되지 않는 경우의 동작이 정의되어 있는가? [Spec §FR-046 - 해당 사진만 비교에서 제외]
- [x] CHK020 - 유사 사진 분석 중 사용자가 다른 화면으로 이동하는 경우가 정의되어 있는가? [Spec §FR-039 - 분석 취소]
- [x] CHK021 - 얼굴 비교 화면에서 모든 사진을 선택 후 Delete하는 경우가 정의되어 있는가? [User Story 5 - 뷰어 닫힘, 그리드로 복귀]

---

## Edge Case Coverage (엣지 케이스 커버리지)

- [x] CHK022 - 사진 라이브러리가 비어있거나 1-2장만 있는 경우의 동작이 정의되어 있는가? [Spec §FR-040 - 3장 미만이면 기능 미표시]
- [x] CHK023 - 분석 중 PhotoKit 권한이 취소되는 경우의 에러 처리가 정의되어 있는가? [Spec §FR-041 - 권한 없음 화면 표시]
- [x] CHK024 - 얼굴이 이미지 경계에 걸쳐 있어 30% 여백 추가 시 이미지 밖으로 나가는 경우가 정의되어 있는가? [Spec §FR-035 - 클램핑 처리]
- [x] CHK025 - 동일 사진에 같은 인물이 여러 번 감지되는 경우(옆모습/정면)의 처리가 정의되어 있는가? [Spec §FR-017b - 감지된 얼굴 그대로 처리]

---

## Non-Functional Requirements (비기능 요구사항)

### 성능
- [x] CHK026 - 메모리 사용량 관련 그룹 정의가 명시되어 있는가? [Spec §FR-028~031 - 썸네일그룹 무제한, 정리그룹 최대 8장]
- [x] CHK027 - Vision 분석의 병렬 처리 제한(동시 작업 수)이 정의되어 있는가? [Spec §FR-027 - 그리드 5개, 뷰어 3개]

### 접근성
- [x] CHK028 - VoiceOver 라벨의 정확한 문구가 모든 UI 요소에 대해 정의되어 있는가? [Spec §FR-042]
- [x] CHK029 - Dynamic Type 지원 요구사항이 정의되어 있는가? [Spec §FR-044 - MVP 미지원, 추후 개선]
- [x] CHK030 - 정적 테두리의 시각적 스펙(색상, 두께)이 모션 감소 설정에 대해 정의되어 있는가? [Spec §FR-043 - 흰색, 애니메이션과 동일]

---

## Dependencies & Assumptions (의존성 및 가정)

- [x] CHK031 - Vision Framework API 가용성(iOS 버전별)이 검증되어 있는가? [iOS 11+, 프로젝트는 iOS 16+]
- [x] CHK032 - "위치 기반 인물 매칭" 자동 검증 방법이 정의되어 있는가? [Spec §FR-047~050, 상세: prd8algorithm.md]
- [x] CHK033 - TrashStore와의 통합 인터페이스가 명시되어 있는가? [Spec §FR-023]

---

## Summary

| 카테고리 | 전체 | 완료 | 미완료 |
|----------|------|------|--------|
| Requirement Completeness | 6 | 6 | 0 |
| Requirement Clarity | 5 | 5 | 0 |
| Requirement Consistency | 3 | 3 | 0 |
| Acceptance Criteria Quality | 3 | 3 | 0 |
| Scenario Coverage | 4 | 4 | 0 |
| Edge Case Coverage | 4 | 4 | 0 |
| Non-Functional Requirements | 5 | 5 | 0 |
| Dependencies & Assumptions | 3 | 3 | 0 |
| **Total** | **33** | **33** | **0** |

---

## Notes

- 이 체크리스트는 구현 전 요구사항 품질 검증용입니다
- 모든 항목이 spec.md에 정의 완료됨
- CHK032 (자동 매칭 검증): Feature Print 기반 검증 알고리즘 정의됨 ([prd8algorithm.md](../../../docs/prd8algorithm.md) 참조)
- 기존 SC-005 (표정 차이 측정)은 주관적 기준으로 제거됨
