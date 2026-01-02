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
| Requirement Completeness | 10 | 0 | 100% |
| Requirement Clarity | 8 | 0 | 100% |
| Requirement Consistency | 6 | 0 | 100% |
| Acceptance Criteria Quality | 5 | 0 | 100% |
| Scenario Coverage | 7 | 0 | 100% |
| Edge Case Coverage | 6 | 0 | 100% |
| Non-Functional Requirements | 6 | 0 | 100% |
| Dependencies & Assumptions | 5 | 0 | 100% |
| Ambiguities & Conflicts | 4 | 0 | 100% |
| **Total** | **57** | **0** | **100%** |

---

## Requirement Completeness

- [x] CHK001 - 유사도 분석 실패 시 동작에 대한 요구사항이 정의되어 있는가? [Spec §Error Handling]
  - ✅ **정의됨**: Vision API 오류, 이미지 로드 실패, 전체 분석 실패 시 동작 정의 완료
- [x] CHK002 - 얼굴 감지 실패 시 폴백 동작이 명세되어 있는가? [Spec §Error Handling]
  - ✅ **정의됨**: 얼굴 감지 API 오류 시 "얼굴 없음"으로 폴백 처리 정의 완료
- [x] CHK003 - 메모리 부족 상황에서의 동작이 요구사항에 포함되어 있는가? [Spec §System State Handling]
  - ✅ **정의됨**: didReceiveMemoryWarning 시 캐시 50% LRU 제거 정의 완료
- [x] CHK004 - 디바이스 과열 시 분석 완화 정책이 정의되어 있는가? [Spec §System State Handling]
  - ✅ **정의됨**: thermalState .serious/.critical 시 동시 분석 5개→2개 제한 정의 완료
- [x] CHK005 - 앱 백그라운드 전환 시 분석 작업 처리 요구사항이 있는가? [Spec §System State Handling]
  - ✅ **정의됨**: 백그라운드 전환 시 분석 취소, 포그라운드 복귀 시 재분석 없음 정의 완료
- [x] CHK006 - 사진 라이브러리 변경(PHPhotoLibraryChangeObserver) 시 캐시 무효화 요구사항이 정의되어 있는가? [Spec §System State Handling]
  - ✅ **정의됨**: PHPhotoLibraryChangeObserver로 감지된 외부 변경 시 해당 캐시 무효화 정의 완료
- [x] CHK007 - +버튼이 5개 이상일 때의 우선순위 선택 기준이 명시되어 있는가? [Spec §FR-016]
  - ✅ **정의됨**: 6개 이상 시 얼굴 크기순으로 상위 5개 선택 정의 완료
- [x] CHK008 - 테두리 애니메이션의 시각적 사양(색상, 두께, 속도)이 정의되어 있는가? [Spec §FR-007]
  - ✅ **정의됨**: 흰색 그라데이션, 시계방향 회전, 1.5초 주기 정의 완료
- [x] CHK009 - ~~경고 배지의 시각적 디자인 사양이 명세되어 있는가?~~ [삭제됨]
  - ✅ **해당 없음**: 인물 매칭 경고 기능 삭제됨 (Feature Print 기반 매칭으로 변경)
- [x] CHK010 - 분석 진행 중 로딩 인디케이터 요구사항이 있는가? [Spec §FR-013]
  - ✅ **정의됨**: 분석 중 로딩 인디케이터 표시

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
- [x] CHK018 - 인물 순환 시 "다음 인물"의 순서 결정 규칙이 정의되어 있는가? [Spec §FR-023]
  - ✅ **정의됨**: 인물 번호 오름차순, 마지막→첫 번째 원형 순환 정의 완료

---

## Requirement Consistency

- [x] CHK019 - 그리드 디바운싱(0.3초)과 테두리 표시 목표(1초)가 일관되게 정의되어 있는가? [Consistency, Spec §FR-006, §SC-001]
  - ✅ **일관됨**: 0.3초 디바운싱 + 0.7초 분석 여유 = 1초 이내 목표
- [x] CHK020 - 유효 슬롯 정의(2장 이상)와 그룹 최소 크기(3장)가 논리적으로 일관되는가? [Consistency, Spec §FR-005, §FR-003]
  - ✅ **일관됨**: 3장 그룹에서 동일 인물 2장 이상 가능
- [x] CHK021 - 매칭 거리 임계값(1.0)과 유사도 거리 임계값(10.0)이 동일한 단위인가? [Consistency, Spec §FR-002, §FR-030]
  - ✅ **일관됨**: 10.0은 이미지 전체 FeaturePrint, 1.0은 얼굴 크롭 FeaturePrint 매칭 (다른 측정 대상)
- [x] CHK022 - VoiceOver 비활성화 요구사항과 접근성 표준이 일관되는가? [Spec §FR-035]
  - ✅ **정의됨**: 시각 기반 기능으로 대체 인터페이스 제공 불가, 기존 사진 삭제 기능 유지로 합리적 제외 근거 명시 완료
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
- [x] CHK027 - "메모리 누수가 발생하지 않는다"의 검증 방법이 정의되어 있는가? [Spec §SC-007]
  - ✅ **정의됨**: Xcode Instruments Leaks 도구로 10분간 기능 사용 후 누수 0건 검증
- [x] CHK028 - "3탭 이내로 원하는 사진을 삭제"의 시작점이 명확히 정의되어 있는가? [Spec §SC-005]
  - ✅ **정의됨**: 얼굴 비교 화면 진입 후 시작, 실제 2탭으로 삭제 가능 명시
- [x] CHK029 - 기기 네이티브 주사율 유지(SC-004)의 테스트 조건이 명시되어 있는가? [Spec §SC-004]
  - ✅ **정의됨**: iPhone 12+, 5만장 라이브러리, Xcode Instruments Frame Rate 측정

---

## Scenario Coverage

- [x] CHK030 - 네트워크 연결/해제 시나리오가 필요한지 검토되어 있는가? [Coverage, Scope]
  - ✅ **명시적 제외**: Out of Scope "클라우드 동기화된 사진의 실시간 분석"
- [x] CHK031 - 사진 라이브러리 접근 권한 거부 시 동작이 정의되어 있는가? [Spec §System State Handling]
  - ✅ **정의됨**: 권한 거부 시 기능 비활성화, 기존 앱 권한 요청 UI 따름
- [x] CHK032 - 분석 중 앱 종료 시 재시작 후 동작이 정의되어 있는가? [Spec §System State Handling]
  - ✅ **정의됨**: 캐시 비영속, 재시작 시 처음부터 분석
- [x] CHK033 - 동시에 여러 사용자 제스처(스와이프 + 탭) 발생 시 동작이 정의되어 있는가? [Spec §Gesture Handling]
  - ✅ **정의됨**: 먼저 인식된 제스처만 처리 (UIGestureRecognizer 기본 동작)
- [x] CHK034 - 분석 범위 내 일부 사진만 삭제된 경우 재분석 요구사항이 있는가? [Spec §Gesture Handling]
  - ✅ **정의됨**: 그룹 무효화 후 다음 스크롤 멈춤 시 자동 재분석
- [x] CHK035 - 화면 회전 시 +버튼 위치 재계산 요구사항이 있는가? [Spec §Gesture Handling]
  - ✅ **정의됨**: viewWillTransition에서 얼굴 좌표 기준 재계산
- [x] CHK036 - 스플릿 뷰/멀티윈도우 환경에서의 동작이 정의되어 있는가? (iPad) [Spec §Gesture Handling]
  - ✅ **정의됨**: iPad 스플릿 뷰/슬라이드 오버 지원, 윈도우 크기 변경 시 재계산

---

## Edge Case Coverage

- [x] CHK037 - 8개 Edge Cases가 모든 주요 경계 조건을 커버하는가? [Coverage, Spec §Edge Cases]
  - ✅ **적절함**: 그룹 크기, 얼굴 유무, 삭제 시나리오 등 주요 케이스 포함
- [x] CHK038 - 동일한 사진이 여러 그룹에 속할 수 있는 경우가 검토되어 있는가? [Spec §Edge Cases]
  - ✅ **정의됨**: 연속 범위 기반이므로 중복 불가, 범위 겹침 시 병합
- [x] CHK039 - 얼굴이 이미지 경계에 걸쳐있을 때의 처리가 정의되어 있는가? [Edge Case, Gap]
  - ✅ **research.md §6**: "경계 처리: 중심 고정, 경계 내 최대 크기로 축소"
- [x] CHK040 - 매우 작은 해상도 사진에서의 얼굴 감지 제한이 정의되어 있는가? [Spec §Edge Cases]
  - ✅ **정의됨**: 480px 미만 원본은 원본 크기로 분석, 정확도 저하 허용
- [x] CHK041 - 500장 캐시 한도 도달 시 eviction과 현재 분석 간 우선순위가 정의되어 있는가? [Spec §Edge Cases]
  - ✅ **정의됨**: 현재 분석 중인 사진은 eviction 대상에서 제외
- [x] CHK042 - 비정상적으로 긴 분석 시간(타임아웃) 처리가 정의되어 있는가? [Spec §Edge Cases]
  - ✅ **정의됨**: 단일 사진 3초 초과 시 분석 실패 처리

---

## Non-Functional Requirements

- [x] CHK043 - 동시 분석 5개 제한의 근거와 조정 가능성이 문서화되어 있는가? [Spec §Non-Functional]
  - ✅ **정의됨**: Vision API당 50MB, 5개 동시 시 250MB로 저사양 기기(2GB RAM) 안정성 확보
- [x] CHK044 - 분석 이미지 해상도(480px) 결정 근거가 문서화되어 있는가? [Spec §Non-Functional]
  - ✅ **정의됨**: 정확도 95% 유지, 분석 시간 200ms 이내 (1080px 대비 4배 빠름)
- [x] CHK045 - ProMotion(120Hz) vs 일반(60Hz) 디스플레이 구분 처리가 명시되어 있는가? [Spec §Non-Functional]
  - ✅ **정의됨**: CADisplayLink로 네이티브 주사율 자동 감지, 별도 분기 불필요
- [x] CHK046 - 배터리 소모에 대한 요구사항이나 제약이 정의되어 있는가? [Spec §Non-Functional]
  - ✅ **정의됨**: 동시 분석 제한 + 백그라운드 취소로 최소화, 저전력 모드 미지원
- [x] CHK047 - 모션 감소 설정 시 "정적 테두리"의 시각적 사양이 정의되어 있는가? [Spec §Non-Functional]
  - ✅ **정의됨**: 흰색 2pt 실선 테두리로 대체 (애니메이션 없음)
- [x] CHK048 - 개인정보 보호 관련 요구사항(분석 데이터 저장 범위)이 명시되어 있는가? [Spec §Non-Functional]
  - ✅ **정의됨**: 메모리 전용 캐시, 디스크 저장 없음, 기기 내 처리(On-device)

---

## Dependencies & Assumptions

- [x] CHK049 - "앱 내 휴지통 기능이 이미 구현되어 있다" 가정이 검증되었는가? [Assumption, Spec §Assumptions]
  - ✅ **검증됨**: plan.md에서 TrashStore.swift 기존 파일로 언급
- [x] CHK050 - "기존 선택 모드 UI 재사용 가능" 가정이 실제 UI와 일치하는가? [Spec §Assumptions]
  - ✅ **정의됨**: FloatingTabBar 컴포넌트 명시로 재사용 대상 특정
- [x] CHK051 - Vision Framework 버전 요구사항(iOS 16+)이 명시되어 있는가? [Dependency, plan.md]
  - ✅ **정의됨**: plan.md Technical Context "iOS 16+"
- [x] CHK052 - PHCachingImageManager와의 통합 요구사항이 정의되어 있는가? [Spec §Assumptions]
  - ✅ **정의됨**: 기존 인스턴스 공유, 분석용 480px 별도 요청 방식 명시
- [x] CHK053 - ~~"연속 촬영 시 사람들의 위치가 거의 변하지 않는다" 가정~~ [삭제됨]
  - ✅ **해당 없음**: Feature Print 기반 매칭으로 변경되어 위치 기반 가정 불필요

---

## Ambiguities & Conflicts

- [x] CHK054 - iOS 26+ Liquid Glass와 기존 FloatingUI 간 전환 기준이 명확한가? [Ambiguity, research.md §8]
  - ✅ **명확함**: "#available(iOS 26.0, *)" 코드 예시로 명확한 분기 조건 제시
- [x] CHK055 - 유사사진썸네일그룹과 유사사진정리그룹의 관계가 명확히 정의되어 있는가? [Clarity, Spec §Key Entities]
  - ✅ **명확함**: data-model.md에서 SimilarThumbnailGroup(무제한)과 ComparisonGroup(max 8) 구분
- [x] CHK056 - 삭제 후 그룹 무효화(3장 미만)와 즉시 UI 업데이트의 타이밍이 정의되어 있는가? [Spec §FR-033]
  - ✅ **정의됨**: 그룹 무효화 시 테두리와 +버튼을 즉시 제거
- [x] CHK057 - "이전 사진으로 자동 이동"에서 이전 사진도 삭제된 경우 동작이 정의되어 있는가? [Ambiguity, Spec §FR-032]
  - ✅ **정의됨**: FR-032 "(없으면 다음 사진)"

---

## 검토 결과 요약

### ✅ 모든 항목 통과 (57/57, 100%)

모든 요구사항 품질 검증 항목이 통과되었습니다.

#### 주요 보완 내용

1. **Error Handling**: Vision API 오류, 이미지 로드 실패, 얼굴 감지 실패 시 동작 정의
2. **System State Handling**: 메모리 경고, 과열, 백그라운드 전환, 외부 라이브러리 변경, 권한 거부 처리
3. **Gesture & Layout Handling**: 제스처 충돌, 화면 회전, iPad 멀티윈도우 지원
4. **Non-Functional Requirements**: 성능 설계 근거, 배터리, 접근성, 개인정보 보호 명시
5. **Edge Cases**: 분석 타임아웃(3초), 캐시 eviction 우선순위, 작은 해상도 처리 정의

---

## Notes

- 체크 완료: `[x]}`, 미완료: `[ ]`
- ✅: 통과, ❌: 미통과, ⚠️: 검토 필요
- [Gap]: 요구사항 누락
- [Ambiguity]: 모호한 정의
