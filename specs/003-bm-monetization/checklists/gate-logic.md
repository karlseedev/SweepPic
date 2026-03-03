# Checklist: 게이트 + 한도 로직 요구사항 품질

**Purpose**: 게이트 판단, 일일 한도, 리워드 광고, Grace Period 흐름의 요구사항 완전성/명확성/일관성 검증
**Created**: 2026-03-03
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md)
**Focus**: 게이트 판단 로직, 한도 관리, 리워드 흐름, Grace Period

---

## Requirement Completeness

- [x] CHK001 - 게이트 판단의 모든 진입 조건이 명시되어 있는가? (Plus 구독, Grace Period, 한도 이내, 한도 초과 4가지 분기) [Completeness, Spec §US-1]
- [x] CHK002 - 게이트 판단 시 "삭제 대상 수"의 정의가 명확한가? trashedCount 전체인지, 선택된 항목인지? (emptyTrash는 전체, trashDeleteSelected는 선택분) [Clarity, Spec §FR-006]
- [x] CHK003 - 리워드 광고 횟수 차감 시점에 대한 요구사항이 완전한가? (시스템 팝업 확인 후에만 차감, 취소 시 미차감) [Completeness, Spec §FR-013]
- [x] CHK004 - "광고 N회 보고 X장 전체 삭제"에서 N 계산 공식이 명시되어 있는가? (필요 광고 수 = ceil((trashCount - remainingLimit) / rewardBonusPerAd)) [Clarity, Gap]
- [x] CHK005 - 게이트 팝업에서 "닫기" 후 사용자가 삭제대기함 장수를 줄인 뒤 다시 "비우기"를 탭하는 시나리오가 명시되어 있는가? [Coverage, Gap]
- [x] CHK006 - 일일 한도 리셋의 "이중 체크" 두 번째 방법(자정 시스템 알림)의 구체적 메커니즘이 정의되어 있는가? (NSCalendar notification? Timer? Background task?) [Clarity, Spec §FR-005]
- [x] CHK007 - Grace Period 중 구독 구매 시 "즉시 종료" 후의 상태 전이가 완전히 정의되어 있는가? (배너 제거, 게이지 미표시, Plus 상태) [Completeness, Spec Edge Cases]
- [x] CHK008 - "생애 최초 no-fill 1회 무료"의 조건이 모든 광고 유형에 적용되는지 리워드에만 적용되는지 명시되어 있는가? [Clarity, Spec §FR-021]

## Requirement Clarity

- [x] CHK009 - "일일 한도 10장"에서 "장"의 정의가 명확한가? 사진 1장 = 1, 동영상 1개 = 1인지, 아니면 burst/live photo가 다르게 카운트되는지? [Clarity, Spec §FR-001]
- [x] CHK010 - "삭제대기함 장수 ≤ 남은 한도이면 게이트 없이"에서 "남은 한도"가 기본 한도만인지, 리워드로 확장된 한도를 포함하는지? [Ambiguity, Spec §FR-007]
- [x] CHK011 - "리워드 2회 소진 시 골든 모먼트"가 게이트 팝업 내에서 표시되는 건지, 별도 화면인지 명시되어 있는가? [Clarity, Spec §FR-014]
- [x] CHK012 - "광고 버튼 3단계 상태(Ready/Loading/Failed)"의 각 상태 전이 조건과 시각적 명세가 정의되어 있는가? [Clarity, Spec §FR-018]
- [x] CHK013 - "지수 백오프 재시도(2→4→8초)"의 최대 재시도 횟수와 최종 실패 시 동작이 정의되어 있는가? [Clarity, Spec §FR-020]
- [x] CHK014 - Grace Period "Day 0~1", "Day 2", "Day 3"의 기준이 UTC인지 로컬 시간인지 명시되어 있는가? [Ambiguity, Spec §FR-024]

## Requirement Consistency

- [x] CHK015 - FR-006("항상 전체 비우기")과 US-1 시나리오 2("광고 2회 보고 15장 삭제")가 일관되는가? (15장이 전체 비우기인 상황이므로 일관됨 — 부분 삭제로 오독 가능성 확인) [Consistency, Spec §FR-006 vs §US-1]
- [x] CHK016 - US-1 시나리오 3("Plus만 가능")과 FR-009("광고로 해결 가능 vs Plus만 가능")의 조건 분기가 일관되는가? [Consistency, Spec §US-1 vs §FR-009]
- [x] CHK017 - Grace Period 중 "게이트 없이 무제한"(FR-023)과 "카운터 없이"의 정의가 일관되는가? Grace Period 중에도 UsageLimit.recordDelete()를 호출하는지 안 하는지? [Consistency, Spec §FR-023]
- [x] CHK018 - 게이트 삽입 지점 5개(plan.md)와 FR-008("한도 초과이면 게이트 시트 표시")의 범위가 일치하는가? (개별 삭제 vs 전체 비우기 모두 포함 여부) [Consistency, Plan vs Spec]

## Acceptance Criteria Quality

- [x] CHK019 - US-1 시나리오 2에서 "광고 2회 가능"의 전제조건이 측정 가능하게 정의되어 있는가? (dailyRewardCount, remainingRewards의 구체적 값) [Measurability, Spec §US-1]
- [x] CHK020 - US-2 시나리오 6의 "no-fill" 판단 기준이 객관적으로 측정 가능한가? (타임아웃 10초 명시됨 — 10초의 근거가 있는가?) [Measurability, Spec §US-2]
- [x] CHK021 - SC-001("80% 이상이 3초 이내에 선택")의 측정 방법이 정의되어 있는가? (어떤 이벤트 간격으로 측정하는지) [Measurability, Spec §SC-001]

## Scenario Coverage

- [x] CHK022 - 게이트 팝업 표시 중 앱이 백그라운드로 전환되었다가 복귀하는 시나리오가 정의되어 있는가? [Coverage, Gap]
- [x] CHK023 - 리워드 광고 시청 중 전화/알림으로 중단되는 시나리오가 정의되어 있는가? [Coverage, Gap]
- [x] CHK024 - 동시에 여러 삭제 지점에서 게이트가 트리거되는 경쟁 조건이 고려되어 있는가? [Coverage, Gap]
- [x] CHK025 - 하루에 기본 10장 + 리워드 20장 = 30장을 모두 소진한 후의 사용자 경험이 완전히 정의되어 있는가? [Coverage, Spec §US-1]
- [x] CHK026 - 삭제대기함이 정확히 한도와 같은 수(예: 10장, 한도 10장)일 때의 동작이 명확한가? (≤ 이므로 게이트 없음 — 경계값) [Edge Case, Spec §FR-007]

## Edge Case Coverage

- [x] CHK027 - 삭제대기함 0장 상태에서 "비우기" 탭 시 게이트 평가를 건너뛰는 요구사항이 있는가? [Edge Case, Gap]
- [x] CHK028 - Grace Period 만료일(Day 3)의 정확한 시각 기준(설치 시각 + 72시간? 설치일 기준 3일 자정?)이 정의되어 있는가? [Edge Case, Spec §FR-023]
- [x] CHK029 - 리워드 광고 1회 시청 후 + 한도 확장 후, 나머지 삭제 대상이 정확히 0장인 경우(모두 커버됨)의 동작이 정의되어 있는가? [Edge Case, Gap]
- [x] CHK030 - 앱 업데이트 시 기존 UsageLimit 데이터(Keychain)의 마이그레이션/호환성 요구사항이 정의되어 있는가? [Edge Case, Gap]

## Dependencies & Assumptions

- [x] CHK031 - "수치는 조정 가능"(Assumption 2)에 대해 어떤 수치를 어떤 범위로 변경할 수 있는지 구체적 제약이 정의되어 있는가? [Assumption, Spec §Assumptions]
- [x] CHK032 - AdMob SDK의 최소 iOS 버전 요구사항이 프로젝트 타겟(iOS 16+)과 호환되는지 명시적으로 확인되었는가? [Dependency, Gap]
- [x] CHK033 - 게이트 로직이 FeatureFlags로 완전 비활성화 가능하다는 요구사항이 명시되어 있는가? (A/B 테스트, 긴급 비활성화용) [Completeness, Gap]
