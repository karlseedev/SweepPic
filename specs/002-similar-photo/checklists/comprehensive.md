# Comprehensive Quality Checklist: 유사 사진 정리 기능

**Purpose**: 유사 사진 정리 기능의 전체 요구사항 품질 검토 (Vision 분석, UX/UI, 성능/캐시 포함)
**Created**: 2026-01-02
**Reviewed**: 2026-01-02
**Feature**: [spec.md](../spec.md)

**Note**: 이 체크리스트는 요구사항 자체의 품질(완전성, 명확성, 일관성, 측정 가능성)을 검증합니다.

---

## Summary

| 카테고리 | 통과 | 미통과 | 통과율 |
|---------|------|--------|--------|
| Requirement Completeness | 1 | 9 | 10% |
| Requirement Clarity | 7 | 1 | 88% |
| Requirement Consistency | 5 | 1 | 83% |
| Acceptance Criteria Quality | 2 | 3 | 40% |
| Scenario Coverage | 1 | 6 | 14% |
| Edge Case Coverage | 2 | 4 | 33% |
| Non-Functional Requirements | 0 | 6 | 0% |
| Dependencies & Assumptions | 3 | 2 | 60% |
| Ambiguities & Conflicts | 3 | 1 | 75% |
| **Total** | **24** | **33** | **42%** |

---

## Requirement Completeness

- [ ] CHK001 - 유사도 분석 실패 시 동작에 대한 요구사항이 정의되어 있는가? [Gap]
  - ❌ **누락**: Vision API 오류, 이미지 로드 실패 시 동작 미정의
- [ ] CHK002 - 얼굴 감지 실패 시 폴백 동작이 명세되어 있는가? [Gap]
  - ❌ **부분 정의**: Edge Case에 "얼굴이 없을 때" 있으나 감지 실패와 다름
- [ ] CHK003 - 메모리 부족 상황에서의 동작이 요구사항에 포함되어 있는가? [Gap]
  - ❌ **누락**: 메모리 경고 시 캐시 정리 정책 미정의
- [ ] CHK004 - 디바이스 과열 시 분석 완화 정책이 정의되어 있는가? [Gap]
  - ❌ **누락**: Thermal state 모니터링 미정의
- [ ] CHK005 - 앱 백그라운드 전환 시 분석 작업 처리 요구사항이 있는가? [Gap]
  - ❌ **누락**: 백그라운드 진입 시 분석 중단/계속 정책 미정의
- [ ] CHK006 - 사진 라이브러리 변경(PHPhotoLibraryChangeObserver) 시 캐시 무효화 요구사항이 정의되어 있는가? [Gap]
  - ❌ **부분 정의**: 앱 내 삭제만 정의, 외부 변경(다른 앱, 사진앱) 미정의
- [ ] CHK007 - +버튼이 5개 이상일 때의 우선순위 선택 기준이 명시되어 있는가? [Spec §FR-016]
  - ❌ **누락**: "최대 5개"만 명시, 6개 이상 얼굴 시 선택 기준 미정의
- [ ] CHK008 - 테두리 애니메이션의 시각적 사양(색상, 두께, 속도)이 정의되어 있는가? [Gap]
  - ❌ **부분 정의**: research.md에 "흰색 그라데이션, 시계방향" 있으나 spec에 없음
- [x] CHK009 - ~~경고 배지의 시각적 디자인 사양이 명세되어 있는가?~~ [삭제됨]
  - ✅ **해당 없음**: 인물 매칭 경고 기능 삭제됨 (Feature Print 기반 매칭으로 변경)
- [ ] CHK010 - 분석 진행 중 로딩 인디케이터 요구사항이 있는가? [Gap]
  - ❌ **누락**: 캐시 miss 시 분석 대기 중 UI 피드백 미정의

---

## Requirement Clarity

- [x] CHK011 - "빛이 도는 테두리 애니메이션"이 구체적인 시각적 사양으로 정의되어 있는가? [Ambiguity, Spec §FR-007]
  - ✅ **research.md §5**: CAShapeLayer + CAKeyframeAnimation, 시계방향, 흰색 그라데이션
- [x] CHK012 - "유효 슬롯 얼굴"의 정의가 명확하게 문서화되어 있는가? [Clarity, Spec §FR-011]
  - ✅ **data-model.md**: "isValidSlot: 그룹 내 2장 이상 감지된 슬롯"
- [x] CHK013 - "거리순"의 정확한 측정 방식(인덱스 거리 vs 시간 거리)이 명시되어 있는가? [Ambiguity, Spec §FR-028]
  - ✅ **data-model.md §4**: "거리순 선택 (동일 거리면 앞쪽 우선)" - 인덱스 거리
- [x] CHK014 - "앞뒤 7장 범위"가 인덱스 기준인지 화면 표시 기준인지 명확한가? [Clarity, Spec §FR-001]
  - ✅ **spec.md FR-001**: "화면에 보이는 사진 기준 앞뒤 7장"
- [x] CHK015 - "즉시 표시"의 구체적인 시간 임계값이 정의되어 있는가? [Ambiguity, Spec §SC-002]
  - ✅ **정의됨**: spec.md SC-002 "100ms 이내"로 수치적 정의 완료
- [x] CHK016 - 얼굴 위치 기준(좌→우, 위→아래)의 동점 처리 규칙이 명시되어 있는가? [Clarity, Spec §FR-019]
  - ✅ **research.md §3**: "X좌표 오름차순, X 동일 시 Y 내림차순"
- [x] CHK017 - "30% 여백"이 bounding box 기준인지 얼굴 크기 기준인지 명확한가? [Clarity, Spec §FR-024]
  - ✅ **research.md §6**: "bounding box 너비/높이 각각 30% 추가"
- [ ] CHK018 - 인물 순환 시 "다음 인물"의 순서 결정 규칙이 정의되어 있는가? [Ambiguity, Spec §FR-023]
  - ❌ **누락**: 인물 번호 순인지, 원형 순환인지 미정의

---

## Requirement Consistency

- [x] CHK019 - 그리드 디바운싱(0.3초)과 테두리 표시 목표(1초)가 일관되게 정의되어 있는가? [Consistency, Spec §FR-006, §SC-001]
  - ✅ **일관됨**: 0.3초 디바운싱 + 0.7초 분석 여유 = 1초 이내 목표
- [x] CHK020 - 유효 슬롯 정의(2장 이상)와 그룹 최소 크기(3장)가 논리적으로 일관되는가? [Consistency, Spec §FR-005, §FR-003]
  - ✅ **일관됨**: 3장 그룹에서 동일 인물 2장 이상 가능
- [x] CHK021 - 매칭 거리 임계값(1.0)과 유사도 거리 임계값(10.0)이 동일한 단위인가? [Consistency, Spec §FR-002, §FR-030]
  - ✅ **일관됨**: 10.0은 이미지 전체 FeaturePrint, 1.0은 얼굴 크롭 FeaturePrint 매칭 (다른 측정 대상)
- [ ] CHK022 - VoiceOver 비활성화 요구사항과 접근성 표준이 일관되는가? [Consistency, Spec §FR-036]
  - ⚠️ **검토 필요**: research.md에 근거 있으나 WCAG 표준과의 일관성 검토 필요
- [x] CHK023 - 캐시 재사용(FR-012)과 notAnalyzed 분석 요청(FR-013)이 상호 배타적으로 정의되어 있는가? [Consistency]
  - ✅ **일관됨**: 캐시 hit → 재사용, 캐시 miss → 분석 (상호 배타적)
- [x] CHK024 - 선택 모드 비활성화(FR-037)와 얼굴 비교 화면의 선택 기능이 충돌하지 않는가? [Consistency]
  - ✅ **충돌 없음**: 그리드 선택 모드와 얼굴 비교 화면 선택은 별도 컨텍스트

---

## Acceptance Criteria Quality

- [x] CHK025 - 모든 성공 기준(SC-001~SC-007)이 객관적으로 측정 가능한가? [Measurability]
  - ✅ **통과**: SC-006 0.5초 이내로 변경되어 모든 SC 측정 가능
- [x] CHK026 - "+버튼 탭 후 0.5초 이내 얼굴 비교 화면 표시"가 측정 가능하게 정의되어 있는가? [Measurability, Spec §SC-006]
  - ✅ **측정 가능**: Feature Print 비교 시간 0.5초 이내로 명확히 정의됨
- [ ] CHK027 - "메모리 누수가 발생하지 않는다"의 검증 방법이 정의되어 있는가? [Measurability, Spec §SC-007]
  - ❌ **부분 정의**: quickstart.md에 Xcode Memory 언급, 구체적 임계값 미정의
- [ ] CHK028 - "3탭 이내로 원하는 사진을 삭제"의 시작점이 명확히 정의되어 있는가? [Measurability, Spec §SC-005]
  - ❌ **누락**: +버튼 탭부터인지, 얼굴 비교 화면 진입 후인지 불명확
- [ ] CHK029 - 기기 네이티브 주사율 유지(SC-004)의 테스트 조건이 명시되어 있는가? [Measurability]
  - ❌ **누락**: 테스트 기기 종류, 사진 수, 측정 도구 미정의

---

## Scenario Coverage

- [x] CHK030 - 네트워크 연결/해제 시나리오가 필요한지 검토되어 있는가? [Coverage, Scope]
  - ✅ **명시적 제외**: Out of Scope "클라우드 동기화된 사진의 실시간 분석"
- [ ] CHK031 - 사진 라이브러리 접근 권한 거부 시 동작이 정의되어 있는가? [Coverage, Exception Flow]
  - ❌ **누락**: 권한 거부/제한 시 기능 동작 미정의
- [ ] CHK032 - 분석 중 앱 종료 시 재시작 후 동작이 정의되어 있는가? [Coverage, Recovery Flow]
  - ❌ **누락**: 앱 재시작 시 캐시 상태, 재분석 정책 미정의
- [ ] CHK033 - 동시에 여러 사용자 제스처(스와이프 + 탭) 발생 시 동작이 정의되어 있는가? [Coverage, Edge Case]
  - ❌ **누락**: 제스처 충돌 처리 미정의
- [ ] CHK034 - 분석 범위 내 일부 사진만 삭제된 경우 재분석 요구사항이 있는가? [Coverage, Spec §FR-034]
  - ❌ **부분 정의**: 그룹 무효화만 정의, 재분석 트리거 여부 미정의
- [ ] CHK035 - 화면 회전 시 +버튼 위치 재계산 요구사항이 있는가? [Coverage, Gap]
  - ❌ **누락**: 화면 회전/크기 변경 시 오버레이 재배치 미정의
- [ ] CHK036 - 스플릿 뷰/멀티윈도우 환경에서의 동작이 정의되어 있는가? (iPad) [Coverage, Gap]
  - ❌ **누락**: iPad 멀티태스킹 환경 미정의

---

## Edge Case Coverage

- [x] CHK037 - 8개 Edge Cases가 모든 주요 경계 조건을 커버하는가? [Coverage, Spec §Edge Cases]
  - ✅ **적절함**: 그룹 크기, 얼굴 유무, 삭제 시나리오 등 주요 케이스 포함
- [ ] CHK038 - 동일한 사진이 여러 그룹에 속할 수 있는 경우가 검토되어 있는가? [Edge Case, Gap]
  - ❌ **검토 필요**: 현재 알고리즘상 불가능할 수 있으나 명시적 정의 없음
- [x] CHK039 - 얼굴이 이미지 경계에 걸쳐있을 때의 처리가 정의되어 있는가? [Edge Case, Gap]
  - ✅ **research.md §6**: "경계 처리: 중심 고정, 경계 내 최대 크기로 축소"
- [ ] CHK040 - 매우 작은 해상도 사진에서의 얼굴 감지 제한이 정의되어 있는가? [Edge Case, Gap]
  - ❌ **부분 정의**: 분석용 480px 다운스케일 있으나 원본 작을 때 미정의
- [ ] CHK041 - 500장 캐시 한도 도달 시 eviction과 현재 분석 간 우선순위가 정의되어 있는가? [Edge Case, Gap]
  - ❌ **부분 정의**: LRU eviction 정책 있으나 분석 중 항목 처리 미정의
- [ ] CHK042 - 비정상적으로 긴 분석 시간(타임아웃) 처리가 정의되어 있는가? [Edge Case, Gap]
  - ❌ **누락**: 분석 타임아웃, 재시도 정책 미정의

---

## Non-Functional Requirements

- [ ] CHK043 - 동시 분석 5개 제한의 근거와 조정 가능성이 문서화되어 있는가? [Performance, Gap]
  - ❌ **누락**: 결정만 있고 근거(메모리, CPU) 미문서화
- [ ] CHK044 - 분석 이미지 해상도(480px) 결정 근거가 문서화되어 있는가? [Performance, research.md]
  - ❌ **누락**: 결정만 있고 근거(정확도 vs 속도 트레이드오프) 미문서화
- [ ] CHK045 - ProMotion(120Hz) vs 일반(60Hz) 디스플레이 구분 처리가 명시되어 있는가? [Performance, Spec §SC-004]
  - ❌ **누락**: 목표만 있고 구현 구분 처리 미정의
- [ ] CHK046 - 배터리 소모에 대한 요구사항이나 제약이 정의되어 있는가? [Performance, Gap]
  - ❌ **누락**: Vision 분석의 배터리 영향 미정의
- [ ] CHK047 - 모션 감소 설정 시 "정적 테두리"의 시각적 사양이 정의되어 있는가? [Accessibility, Spec §FR-039]
  - ❌ **누락**: 정적 테두리의 색상, 두께 등 미정의
- [ ] CHK048 - 개인정보 보호 관련 요구사항(분석 데이터 저장 범위)이 명시되어 있는가? [Privacy, Gap]
  - ❌ **누락**: 캐시 데이터 보안, 앱 삭제 시 처리 미정의

---

## Dependencies & Assumptions

- [x] CHK049 - "앱 내 휴지통 기능이 이미 구현되어 있다" 가정이 검증되었는가? [Assumption, Spec §Assumptions]
  - ✅ **검증됨**: plan.md에서 TrashStore.swift 기존 파일로 언급
- [ ] CHK050 - "기존 선택 모드 UI 재사용 가능" 가정이 실제 UI와 일치하는가? [Assumption, Spec §Assumptions]
  - ⚠️ **확인 필요**: 가정만 있고 실제 UI 호환성 검증 미완료
- [x] CHK051 - Vision Framework 버전 요구사항(iOS 16+)이 명시되어 있는가? [Dependency, plan.md]
  - ✅ **정의됨**: plan.md Technical Context "iOS 16+"
- [ ] CHK052 - PHCachingImageManager와의 통합 요구사항이 정의되어 있는가? [Dependency, Gap]
  - ❌ **부분 정의**: Primary Dependencies에 언급만, 구체적 통합 방식 미정의
- [x] CHK053 - ~~"연속 촬영 시 사람들의 위치가 거의 변하지 않는다" 가정~~ [삭제됨]
  - ✅ **해당 없음**: Feature Print 기반 매칭으로 변경되어 위치 기반 가정 불필요

---

## Ambiguities & Conflicts

- [x] CHK054 - iOS 26+ Liquid Glass와 기존 FloatingUI 간 전환 기준이 명확한가? [Ambiguity, research.md §8]
  - ✅ **명확함**: "#available(iOS 26.0, *)" 코드 예시로 명확한 분기 조건 제시
- [x] CHK055 - 유사사진썸네일그룹과 유사사진정리그룹의 관계가 명확히 정의되어 있는가? [Clarity, Spec §Key Entities]
  - ✅ **명확함**: data-model.md에서 SimilarThumbnailGroup(무제한)과 ComparisonGroup(max 8) 구분
- [ ] CHK056 - 삭제 후 그룹 무효화(3장 미만)와 즉시 UI 업데이트의 타이밍이 정의되어 있는가? [Ambiguity, Spec §FR-034]
  - ❌ **누락**: 무효화 후 UI 반영 시점(즉시 vs 다음 스크롤) 미정의
- [x] CHK057 - "이전 사진으로 자동 이동"에서 이전 사진도 삭제된 경우 동작이 정의되어 있는가? [Ambiguity, Spec §FR-032]
  - ✅ **정의됨**: FR-032 "(없으면 다음 사진)"

---

## 검토 결과 요약

### 🔴 Critical Gaps (즉시 보완 필요)

1. **CHK001**: 분석 실패 시 동작 미정의
2. **CHK015**: "즉시 표시" 수치적 정의 없음 → spec.md에서 100ms 이내로 정의됨 ✅
3. ~~**CHK026**: SC-006 측정 방법 없음~~ → 0.5초 이내로 변경됨 ✅
4. **CHK031**: 권한 거부 시 동작 미정의

### 🟡 Important Gaps (구현 전 보완 권장)

1. **CHK007**: 5개 초과 얼굴 시 우선순위
2. **CHK010**: 분석 대기 중 UI 피드백
3. **CHK018**: 인물 순환 순서 규칙
4. **CHK042**: 분석 타임아웃 처리

### ✅ Well-Defined Areas

- Requirement Clarity: 5/8 통과 (63%)
- Requirement Consistency: 5/6 통과 (83%)
- Ambiguities & Conflicts: 3/4 통과 (75%)

---

## Notes

- 체크 완료: `[x]}`, 미완료: `[ ]`
- ✅: 통과, ❌: 미통과, ⚠️: 검토 필요
- [Gap]: 요구사항 누락
- [Ambiguity]: 모호한 정의
