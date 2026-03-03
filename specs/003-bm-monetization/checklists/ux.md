# Checklist: UX 요구사항 품질

**Purpose**: 게이트 팝업, 게이지, Grace Period 배너, 축하 화면, 페이월, 메뉴 등 UI/UX 요구사항의 명확성/완전성 검증
**Created**: 2026-03-03
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md)
**Focus**: UI 레이아웃, 인터랙션 플로우, 상태별 화면 전환, 접근성

---

## Requirement Completeness

- [ ] CHK034 - 게이트 팝업의 시각적 레이아웃(카드 크기, 여백, 모서리, 배경 투명도)이 명세되어 있는가? [Completeness, Gap]
- [ ] CHK035 - 게이트 팝업에서 "광고 N회 보고 X장 전체 삭제" 버튼의 동적 텍스트 생성 규칙이 정의되어 있는가? (N=1일 때 "광고 1회", N=2일 때 "광고 2회") [Completeness, Gap]
- [ ] CHK036 - 게이지 바의 시각적 명세(높이, 색상, 프로그레스 비율 계산, 라운딩)가 정의되어 있는가? [Completeness, Gap]
- [ ] CHK037 - 게이지 "상세 팝업"(FR-011)의 레이아웃과 콘텐츠 구성이 정의되어 있는가? (한도 상태 + 광고 잔여 + 광고 보기 버튼의 배치) [Completeness, Spec §FR-011]
- [ ] CHK038 - Grace Period 배너의 시각적 명세(배경색, 아이콘, 텍스트 스타일)가 단계별(Day 0~1, Day 2, Day 3)로 정의되어 있는가? [Completeness, Spec §FR-024]
- [ ] CHK039 - 축하 화면의 레이아웃(삭제 수 표시 형식, 용량 단위 변환 규칙 KB/MB/GB, 누적 통계 위치)이 정의되어 있는가? [Completeness, Spec §FR-039]
- [ ] CHK040 - 페이월의 무료/Plus 비교표 내용(비교 항목, 비교 방식)이 구체적으로 정의되어 있는가? [Completeness, Spec §FR-035]
- [ ] CHK041 - 페이월 하단의 법적 고지(자동 갱신, 해지 방법)의 정확한 문구가 정의되어 있는가? [Completeness, Spec §FR-037]
- [ ] CHK042 - "골든 모먼트"(리워드 소진 시 전환 유도)의 구체적 UI 변화가 정의되어 있는가? 게이트 팝업 내에서 Plus 버튼이 어떻게 강조되는지? [Completeness, Spec §FR-014]

## Requirement Clarity

- [ ] CHK043 - "카운터 게이지 첫 표시 시 1회 툴팁"(Edge Case)의 툴팁 문구, 위치, 자동 dismiss 조건이 정의되어 있는가? [Clarity, Spec §Edge Cases]
- [ ] CHK044 - Grace Period 배너 "Plus로 계속 무제한 사용 →" 텍스트 링크와 Day 3 "[Plus로 무제한 계속하기]" 버튼의 시각적 차이가 명시되어 있는가? [Clarity, Spec §US-3]
- [ ] CHK045 - 갱신 실패 시 "⚠️ 뱃지"의 정확한 표시 위치(전체메뉴 아이콘 어디?)와 형태가 정의되어 있는가? [Clarity, Spec §FR-034]
- [ ] CHK046 - "비우기" 버튼 텍스트가 "항상 비우기"(FR-012)이지만, 게이트 팝업 내 버튼 텍스트는 달라야 하는데 이 관계가 명확한가? [Clarity, Spec §FR-012]
- [ ] CHK047 - 리딤 코드 시스템 시트 "실패/타임아웃(10초)"의 구분이 명확한가? 시스템 시트가 10초 내 응답 없으면 자동 dismiss인지, 별도 처리인지? [Clarity, Spec §US-4]

## Requirement Consistency

- [ ] CHK048 - iOS 16~25(FloatingUI)와 iOS 26+(시스템 네비바)에서 게이지/배너의 표시 위치가 일관되게 정의되어 있는가? [Consistency, Plan]
- [ ] CHK049 - 페이월 진입 경로(게이트 팝업 "Plus", 배너 탭, 메뉴 "구독 관리")에서 페이월 화면이 동일한지 다른지 정의되어 있는가? [Consistency, Gap]
- [ ] CHK050 - "구독 관리" 탭 시 무료 사용자는 페이월, Plus 사용자는 시스템 구독 관리 — 이 분기가 US-8과 US-4에서 일관되게 기술되어 있는가? [Consistency, Spec §US-4 vs §US-8]

## Scenario Coverage

- [ ] CHK051 - 축하 화면에서 "확인" 탭 후 이전 화면 복귀 시, 삭제대기함이 비어있는 상태의 emptyStateView와의 전환이 정의되어 있는가? [Coverage, Gap]
- [ ] CHK052 - 게이트 팝업 → 광고 시청 → iOS 시스템 팝업의 3단계 화면 전환에서 각 단계 사이의 전환 애니메이션/딜레이가 정의되어 있는가? [Coverage, Gap]
- [ ] CHK053 - 배너 광고(분석 대기 화면 하단)가 분석 완료 시 자동으로 제거되는지, 화면 전환까지 유지되는지 정의되어 있는가? [Coverage, Gap]
- [ ] CHK054 - FAQ 아코디언 리스트의 콘텐츠(질문/답변 목록)가 정의되어 있는가, 아니면 별도로 작성 예정인가? [Coverage, Gap]

## Accessibility & Edge Cases

- [ ] CHK055 - VoiceOver 환경에서 게이트 팝업의 접근성 요구사항(포커스 순서, 버튼 레이블, 게이지 읽기)이 정의되어 있는가? [Accessibility, Gap]
- [ ] CHK056 - Dynamic Type(큰 글자) 환경에서 게이트 팝업/게이지/배너의 레이아웃 대응이 정의되어 있는가? [Accessibility, Gap]
- [ ] CHK057 - 다크 모드에서의 게이트 팝업/게이지/배너 색상 대응이 정의되어 있는가? (현재 앱이 다크 모드 강제) [Edge Case, Gap]
- [ ] CHK058 - 가로 모드(landscape)에서의 게이트 팝업/페이월 레이아웃이 정의되어 있는가, 아니면 세로 고정인가? [Edge Case, Gap]
- [ ] CHK059 - 피드백 이메일 미지원 기기의 폴백(mailto: URL)이 정의되어 있지만, 이메일 앱이 아예 없는 기기의 처리는? [Edge Case, Spec §Edge Cases]

## Non-Functional UX Requirements

- [ ] CHK060 - 게이트 팝업의 표시 시간 목표(appear latency)가 정의되어 있는가? [Performance, Gap]
- [ ] CHK061 - 광고 로딩 중 스피너의 최대 대기 시간과 타임아웃 후 UX가 정의되어 있는가? (10초 후 재시도/취소 팝업 — 그 팝업의 명세는?) [Completeness, Spec §US-2]
- [ ] CHK062 - 축하 화면의 용량 표시에서 0bytes(파일 크기 계산 실패 시)인 경우의 표시 방식이 정의되어 있는가? [Edge Case, Gap]
