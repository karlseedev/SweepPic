# Requirements Quality Checklist: PickPhoto MVP

**Purpose**: spec.md 전체 요구사항의 완전성, 명확성, 일관성, 측정가능성 검증
**Created**: 2025-12-17
**Updated**: 2025-12-17
**Feature**: [spec.md](../spec.md)

**Summary**: 62개 항목 중 **37개 충족**, **25개 스킵 (의도적 제외/구현 상세)**

---

## Requirement Completeness (요구사항 완전성)

- [x] CHK001 - 모든 User Story에 대해 해당하는 Functional Requirements가 정의되어 있는가? [Completeness, Spec US1-6 ↔ FR-001~FR-036] ✅ 매핑 완료
- [x] CHK002 - 권한 거부 후 재요청 시나리오가 명시되어 있는가? ✅ FR-034에 추가됨
- [x] CHK003 - 앱 내 휴지통 저장소 용량 한계 또는 항목 수 제한이 정의되어 있는가? ✅ Assumptions에 "제한 없음 (MVP)" 추가됨
- [x] CHK004 - iCloud-only 사진의 placeholder 동작이 상세히 정의되어 있는가? ✅ Edge Cases에 정의됨
- [x] CHK005 - 네트워크 오류 시 동작(iCloud 사진 다운로드 실패 등)이 정의되어 있는가? ✅ N/A (다운로드 시도 안함)
- [x] CHK006 - 앱 종료/백그라운드 전환 시 휴지통 상태 저장 정책이 명시되어 있는가? ✅ FR-022에 "상태 변경 행동마다 즉시 저장" 추가됨
- [x] CHK007 - 빈 앨범 표시 정책이 정의되어 있는가? ✅ Edge Cases에 추가됨
- [x] CHK008 - 비디오 duration/재생 아이콘 스타일이 구체적으로 정의되어 있는가? ✅ FR-035에 "iOS 사진 앱과 동일한 스타일" 추가됨
- [x] CHK009 - Live Photo 배지/아이콘 표시 요구사항이 있는가? ✅ FR-036에 "배지 없이 정지 이미지" 추가됨
- [x] CHK010 - 그리드 셀 간격, 셀 비율(정사각/원본비율) 요구사항이 명시되어 있는가? ✅ FR-001에 "셀 간격 2pt, 정사각형 비율" 추가됨

## Requirement Clarity (요구사항 명확성)

- [x] CHK011 - "딤드(어둡게) 처리"의 구체적 시각적 사양(opacity, 오버레이 색상 등)이 정의되어 있는가? ✅ FR-008에 "50% opacity 검정 오버레이" 추가됨
- [x] CHK012 - "부드러운 스크롤"이 hitch < 5 ms/s로 정량화되어 있는가? ✅ FR-006에 정의됨
- [x] CHK013 - "자연스럽게 변경"(핀치 줌)의 애니메이션 duration/easing이 명시되어 있는가? ⏭️ 스킵 (iOS Core Animation 기본값 사용)
- [x] CHK014 - "줌 전환 애니메이션"의 duration(0.25초)이 spec.md에 명시되어 있는가? ⏭️ 스킵 (구현 상세, plan.md에 있음)
- [x] CHK015 - "체크마크" 표시의 위치, 크기, 스타일이 정의되어 있는가? ✅ FR-016에 "iOS 사진 앱과 동일한 선택 표시 스타일" 추가됨
- [x] CHK016 - "더 많은 사진 선택" 배너의 위치, 동작, 탭 시 반응이 정의되어 있는가? ⏭️ 스킵 (iOS 표준 동작)
- [x] CHK017 - "설정 앱 이동 안내"의 구체적 UI/문구가 정의되어 있는가? ✅ FR-034에 구체적 문구 추가됨
- [x] CHK018 - "복구/완전삭제" 옵션의 UI 형태(버튼, 액션시트, 스와이프 등)가 명시되어 있는가? ✅ FR-015에 "하단 원형 플로팅 삭제 버튼" 추가됨
- [x] CHK019 - "2열 그리드"(앨범 목록)의 셀 크기, 텍스트 위치 등이 정의되어 있는가? ✅ FR-027에 "iOS 사진 앱 앨범 목록과 동일한 레이아웃" 추가됨
- [x] CHK020 - "화면 높이의 20% 이상"의 측정 기준(전체 화면 vs safe area)이 명확한가? ✅ FR-011에 "UIScreen.main.bounds.height 기준" 추가됨

## Requirement Consistency (요구사항 일관성)

- [x] CHK021 - FR-006의 hitch 기준(< 5 ms/s)과 SC-001의 기준이 일치하는가? ✅ 둘 다 < 5 ms/s
- [x] CHK022 - "이전 사진 우선" 규칙이 FR-013과 US2 시나리오 4/5에서 일관되게 정의되어 있는가? ✅ 일관됨
- [x] CHK023 - 딤드 사진 탭 동작이 US1 시나리오 5와 US2 시나리오 7에서 일관되는가? ✅ 충돌 없음
- [x] CHK024 - 성능 기준(Success Criteria)과 Performance KPI(Constitution)가 일치하는가? ✅ 메모리 250MB 일치
- [x] CHK025 - 앨범 내 삭제(FR-031)와 일반 삭제(FR-011, FR-019)의 동작이 일관되는가? ✅ 모두 "앱 내 휴지통으로 이동"
- [x] CHK026 - "시스템 팝업" 표현이 FR-024, FR-025, SC-007에서 동일한 의미인가? ✅ iOS PhotoKit 시스템 확인 팝업

## Acceptance Criteria Quality (수용 기준 품질)

- [x] CHK027 - SC-003의 "0px drift"가 객관적으로 측정 가능한가? ✅ "Gate 3 검증 완료" 명시
- [x] CHK028 - SC-004의 "100% 정확"이 어떤 테스트 조건에서 검증되는지 명시되어 있는가? ✅ SC-004에 "테스트 코드로 검증" 추가됨
- [x] CHK029 - SC-001의 "빠르게 스크롤"이 정량화(속도, 프레임 등)되어 있는가? ⏭️ 스킵 (Instruments로 일반적 사용 패턴 적용)
- [x] CHK030 - 썸네일 응답 시간(< 100ms)의 측정 시점(요청~렌더링 완료)이 정의되어 있는가? ⏭️ 스킵 (Apple 출처로 암묵적 정의)
- [x] CHK031 - 콜드 스타트 시간의 측정 구간(앱 아이콘 탭 ~ 첫 프레임)이 명확한가? ⏭️ 스킵 (Apple 출처로 암묵적 정의)

## Scenario Coverage (시나리오 커버리지)

- [x] CHK032 - 권한이 "limited"에서 "full"로 변경될 때의 동작이 정의되어 있는가? ⏭️ 스킵 (PHPhotoLibraryChangeObserver가 자동 처리)
- [x] CHK033 - 사진 라이브러리가 외부에서 변경될 때 동작이 정의되어 있는가? ✅ "이전 사진 우선", "휴지통 자동 정리"
- [x] CHK034 - 메모리 경고(didReceiveMemoryWarning) 시 구체적 동작이 정의되어 있는가? ✅ "캐시 즉시 해제"
- [x] CHK035 - 앱이 백그라운드 상태에서 사진이 추가/삭제될 때 동작이 정의되어 있는가? ⏭️ 스킵 (PHPhotoLibraryChangeObserver가 자동 처리)
- [x] CHK036 - 뷰어에서 현재 보고 있는 사진이 외부에서 삭제될 때 동작이 정의되어 있는가? ✅ "이전 사진 우선"
- [x] CHK037 - 드래그 선택 중 화면 경계에 도달했을 때 자동 스크롤 동작이 정의되어 있는가? ✅ FR-017에 "MVP 미지원, 추후 지원 검토" 추가됨
- [x] CHK038 - Select 모드에서 핀치 줌 동작(허용/비허용)이 정의되어 있는가? ✅ FR-004에 "Select 모드에서도 핀치 줌 허용" 추가됨
- [x] CHK039 - 뷰어에서 핀치 줌 중 위 스와이프 삭제 제스처가 어떻게 처리되는지 정의되어 있는가? ✅ FR-011에 "줌 상태에서도 허용" 추가됨
- [x] CHK040 - 휴지통 화면에서 Select 모드(다중 선택 복구/삭제) 지원 여부가 명시되어 있는가? ✅ FR-023에 "MVP 미지원, 개별 처리만" 추가됨

## Edge Case Coverage (엣지 케이스 커버리지)

- [x] CHK041 - 사진이 정확히 1장일 때 뷰어에서의 좌우 스와이프 동작이 정의되어 있는가? ⏭️ 스킵 (자연스러운 동작)
- [x] CHK042 - 매우 큰 이미지(예: 파노라마, 48MP 사진)의 처리 정책이 정의되어 있는가? ⏭️ 스킵 (PhotoKit 기본 동작)
- [x] CHK043 - 손상된 사진/비디오 파일의 표시 정책이 정의되어 있는가? ⏭️ 스킵 (PhotoKit이 처리)
- [x] CHK044 - 앨범에 사진이 0장일 때의 표시가 정의되어 있는가? ⏭️ 스킵 (CHK007에서 처리됨)
- [x] CHK045 - 휴지통에 수만 장의 사진이 있을 때의 성능 요구사항이 있는가? ⏭️ 스킵 (일반 그리드와 동일 구현)
- [x] CHK046 - 핀치 줌 threshold(0.85/1.15) 값이 spec.md에 명시되어 있는가? ⏭️ 스킵 (구현 상세, plan.md에 있음)

## Non-Functional Requirements (비기능 요구사항)

- [x] CHK047 - 접근성(VoiceOver, Dynamic Type) 요구사항이 정의되어 있는가? ⏭️ 스킵 (MVP 범위 외)
- [x] CHK048 - 다국어/지역화 요구사항이 정의되어 있는가? ⏭️ 스킵 (MVP 범위 외)
- [x] CHK049 - 가로 모드(landscape) 지원 여부가 명시되어 있는가? ⏭️ 스킵 (MVP 범위 외)
- [x] CHK050 - iPad 지원 여부가 명시되어 있는가? ⏭️ 스킵 (MVP 범위 외)
- [x] CHK051 - Dark mode 지원 요구사항이 정의되어 있는가? ⏭️ 스킵 (MVP 범위 외)
- [x] CHK052 - 배터리/발열 관련 제약이 정의되어 있는가? ⏭️ 스킵 (MVP 범위 외)
- [x] CHK053 - 오프라인 동작(iCloud 동기화 불가 시) 정책이 정의되어 있는가? ✅ N/A (다운로드 시도 안함)

## Dependencies & Assumptions (의존성 및 가정)

- [x] CHK054 - iOS 16+ 최소 지원이 모든 PhotoKit API 사용과 호환되는지 검증되었는가? ✅ 명시됨
- [x] CHK055 - "5만 장 기준" 가정의 출처/근거가 문서화되어 있는가? ⏭️ 스킵 (Constitution에서 정의됨)
- [x] CHK056 - "수동 비우기 (MVP)" 가정이 향후 자동 정리로 전환 시 영향 범위가 정의되어 있는가? ✅ Clarifications에 언급됨
- [x] CHK057 - 파일 기반 저장의 구체적 위치(Documents, Caches 등)가 정의되어 있는가? ⏭️ 스킵 (구현 상세, TechSpec 담당)
- [x] CHK058 - PHCachingImageManager의 캐시 정책이 시스템 의존임이 명시되어 있는가? ⏭️ 스킵 (구현 상세)

## Ambiguities & Conflicts (모호성 및 충돌)

- [x] CHK059 - "빠른 연속 삭제"의 정량적 기준(초당 N회 등)이 정의되어 있는가? ⏭️ 스킵 (정성적 기준으로 충분)
- [x] CHK060 - 핀치 줌 cooldown(200ms)이 spec.md에 명시되어 있는가? ⏭️ 스킵 (구현 상세, plan.md에 있음)
- [x] CHK061 - 앨범 그리드 "3열 고정" 제약이 spec.md에 명시되어 있는가? ✅ Assumptions에 명시됨
- [x] CHK062 - TrashState의 trashDates 필드 용도(UI 표시, 자동 정리 등)가 정의되어 있는가? ⏭️ 스킵 (구현 상세)

---

## Summary by Category

| 카테고리 | 충족 | 스킵 | 총계 |
|----------|------|------|------|
| Completeness | 10 | 0 | 10 |
| Clarity | 7 | 3 | 10 |
| Consistency | 6 | 0 | 6 |
| Acceptance Criteria | 2 | 3 | 5 |
| Scenario Coverage | 7 | 2 | 9 |
| Edge Cases | 0 | 6 | 6 |
| NFR | 1 | 6 | 7 |
| Dependencies | 2 | 3 | 5 |
| Ambiguities | 1 | 3 | 4 |
| **Total** | **37** | **25** | **62** |

## Legend

- ✅ = 충족 (spec.md에 정의됨)
- ⏭️ = 의도적 스킵 (구현 상세, MVP 범위 외, 또는 시스템 기본 동작)
- N/A = 해당 없음

## Changes Made (2025-12-17)

사용자 검토 후 spec.md에 추가된 내용:
- FR-001: 셀 간격 2pt, 정사각형 비율
- FR-004: Select 모드에서 핀치 줌 허용
- FR-008: 50% opacity 검정 오버레이
- FR-011: UIScreen.main.bounds.height 기준, 줌 상태에서도 삭제 허용
- FR-015: 하단 원형 플로팅 삭제 버튼
- FR-016: iOS 사진 앱 선택 스타일
- FR-017: 자동 스크롤 MVP 미지원, 추후 지원 검토
- FR-022: 상태 변경 행동마다 즉시 저장
- FR-023: 휴지통 다중 선택 MVP 미지원
- FR-027: iOS 사진 앱 앨범 목록 레이아웃
- FR-034: 구체적 문구 및 권한 거부 후 재요청
- FR-035: iOS 사진 앱 동일 비디오 스타일
- FR-036: 배지 없이 정지 이미지
- SC-004: 테스트 코드로 검증
- Edge Cases: 앨범 0장 추가
- Assumptions: 휴지통 항목 수 제한 없음
