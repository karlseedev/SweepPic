# Comprehensive Requirements Quality Checklist: 저품질 사진 자동 정리

**Purpose**: 구현 전 요구사항 완전성, 명확성, 일관성 검증
**Created**: 2026-01-21
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md)
**Depth**: 상세 (전체 영역)

---

## 분석 파이프라인 요구사항

### 임계값 정의

- [ ] CHK001 - Laplacian Variance 50/100 임계값이 테스트 검증 필요 여부와 조정 방법이 명시되어 있는가? [Clarity, Spec §FR-014]
- [ ] CHK002 - 휘도 임계값 0.10/0.90이 야경/실루엣 등 의도적 노출 사진 오탐 가능성에 대해 문서화되어 있는가? [Coverage, Research §2]
- [ ] CHK003 - RGB 표준편차 10/15 임계값의 산출 근거가 "설계값"만으로 충분한가, 추가 검증 기준이 필요한가? [Clarity, Research §3]
- [ ] CHK004 - Face Quality 0.4 임계값이 Apple 권고(상대 비교)와 다르게 절대 임계값으로 사용하는 위험이 명시되어 있는가? [Risk, Research §5]
- [ ] CHK005 - AestheticsScore -0.3/0 임계값이 Apple 공식 권장이 아닌 설계값임이 명확히 문서화되어 있는가? [Clarity, Research §4]
- [ ] CHK006 - 비네팅 0.05 임계값의 검증 방법과 조정 절차가 정의되어 있는가? [Gap, Research §6]

### iOS 버전 분기

- [ ] CHK007 - iOS 18+ AestheticsScore 실패 시 Metal fallback 조건이 명확히 정의되어 있는가? [Completeness, Spec §FR-026]
- [ ] CHK008 - iOS 16-17과 iOS 18+ 파이프라인 간 결과 일관성 검증 방법이 명시되어 있는가? [Consistency, Gap]
- [ ] CHK009 - AestheticsScore의 isUtility == true 처리가 스크린샷과 동일 취급임이 명확한가? [Clarity, Research §4]
- [ ] CHK010 - 시뮬레이터에서 AestheticsScore 미지원 시 테스트 전략이 정의되어 있는가? [Coverage, Gap]

### Safe Guard

- [ ] CHK011 - Safe Guard 조건(즐겨찾기, 편집됨, 숨김, 공유앨범)의 우선순위가 명시되어 있는가? [Completeness, Spec §FR-017]
- [ ] CHK012 - 심도 효과가 있는 사진의 블러 판정 무효화 조건이 구체적으로 정의되어 있는가? [Clarity, Spec §FR-018]
- [ ] CHK013 - Safe Guard 적용 시점(Stage 1 vs Stage 4)이 일관되게 문서화되어 있는가? [Consistency, Plan §Pipeline]
- [ ] CHK014 - 공유앨범 사진 판별 방법(PHAsset 속성)이 명시되어 있는가? [Gap]

### 특수 미디어

- [ ] CHK015 - Live Photo의 "정지 이미지만 분석" 시 어떤 이미지를 사용하는지 명시되어 있는가? [Clarity, Spec §FR-021]
- [ ] CHK016 - Burst 사진의 "대표 사진" 선택 기준이 PHFetchResult 기본 동작으로 충분한지 명시되어 있는가? [Clarity, Spec §FR-022]
- [ ] CHK017 - RAW+JPEG 분석 시 JPEG 선택 로직이 명확히 정의되어 있는가? [Gap, Spec §FR-023]
- [ ] CHK018 - 비디오 프레임 3개 추출 위치(0%, 50%, 100%)와 중앙값 판정 로직이 명시되어 있는가? [Clarity, Spec §FR-024]
- [ ] CHK019 - 10분 초과 비디오 제외 기준이 duration > 600초로 명확한가? [Completeness, Spec §FR-025]

---

## UX 흐름 요구사항

### 진입 조건

- [ ] CHK020 - "휴지통 비어있는지 확인" 시점이 버튼 탭 직후인지 명확히 정의되어 있는가? [Clarity, Spec §FR-001]
- [ ] CHK021 - 휴지통 비어있지 않을 때 표시되는 메시지와 버튼 텍스트가 정확히 명시되어 있는가? [Completeness, Spec §FR-002]
- [ ] CHK022 - 정리 버튼 위치 "그리드 화면 상단, 셀렉트 버튼 왼쪽"이 충분히 구체적인가? [Clarity, Spec §UI 배치]

### 정리 방식 선택

- [ ] CHK023 - 세 가지 정리 방식(최신/이어서/연도별)의 UI 컴포넌트 형태(시트/팝업)가 명시되어 있는가? [Gap]
- [ ] CHK024 - "이어서 정리" 비활성화 상태의 시각적 표현이 정의되어 있는가? [Gap, Spec §FR-005]
- [ ] CHK025 - 연도별 정리의 연도 선택 UI가 하위 메뉴인지 별도 화면인지 명시되어 있는가? [Clarity, Spec §FR-006]
- [ ] CHK026 - 연도 목록 생성 기준(사진이 있는 연도만? 전체 연도?)이 정의되어 있는가? [Gap]

### 진행 화면

- [ ] CHK027 - 탐색 진행 UI의 정확한 레이아웃과 컴포넌트가 명시되어 있는가? [Completeness, Spec §5.3]
- [ ] CHK028 - "N/50" 형식의 진행 표시가 50장 미만 찾을 때도 동일한지 명시되어 있는가? [Clarity]
- [ ] CHK029 - 현재 탐색 시점 표시 형식("2026년 5월부터")이 연도별 정리에서도 동일한지 명시되어 있는가? [Consistency]
- [ ] CHK030 - 취소 버튼 탭 시 확인 다이얼로그 필요 여부가 정의되어 있는가? [Gap]

### 결과 표시

- [ ] CHK031 - 결과 메시지 4가지(50장/N장/0장/취소)의 정확한 문구가 명시되어 있는가? [Completeness, Spec §5.4]
- [ ] CHK032 - 결과 알림이 Alert인지 Toast인지, 자동 닫힘 여부가 정의되어 있는가? [Gap]
- [ ] CHK033 - 결과 알림에서 휴지통으로 이동하는 버튼/링크 제공 여부가 정의되어 있는가? [Gap]

---

## 데이터/저장 요구사항

### 세션 저장

- [ ] CHK034 - CleanupSession 저장 파일 경로(Documents/CleanupSession.json)가 명확한가? [Completeness, Data Model §6]
- [ ] CHK035 - 세션 저장 시점(배치마다? 종료 시?)이 명시되어 있는가? [Gap]
- [ ] CHK036 - 앱 강제 종료 시 부분 저장된 세션 복구 정책이 정의되어 있는가? [Gap, Edge Case]
- [ ] CHK037 - CleanupMethod.byYear의 associated value 인코딩 방식이 명시되어 있는가? [Gap, Data Model §1]

### 휴지통 연동

- [ ] CHK038 - 기존 TrashStore의 moveToTrash API가 배치 처리에 적합한지 검증되었는가? [Completeness, Plan §기존 파일 수정]
- [ ] CHK039 - 정리 완료 후 trashedAssetIDs와 TrashStore 동기화 방법이 명시되어 있는가? [Consistency]
- [ ] CHK040 - 휴지통 이동 실패 시 롤백 정책이 정의되어 있는가? [Gap, Exception Flow]

### 상태 관리

- [ ] CHK041 - 백그라운드 전환 시 "일시정지" 상태의 정확한 저장 범위가 명시되어 있는가? [Clarity, Spec §FR-029]
- [ ] CHK042 - 포그라운드 복귀 시 자동 재개 조건(마지막 사진부터? 배치 처음부터?)이 정의되어 있는가? [Gap]
- [ ] CHK043 - SessionStatus 상태 전이 다이어그램이 모든 경로를 커버하는가? [Coverage, Data Model §1]

---

## 성능/비기능 요구사항

### 성능 목표

- [ ] CHK044 - "1,000장 스캔 30초 이내" 목표의 측정 환경(기기, iOS 버전)이 명시되어 있는가? [Clarity, Spec §SC-005]
- [ ] CHK045 - "분석당 10ms 이내" 목표가 어떤 분석(노출/블러/전체)을 의미하는지 명확한가? [Ambiguity, Plan §Performance Goals]
- [ ] CHK046 - 배치 크기 100, 동시 분석 4의 근거와 튜닝 가능 여부가 명시되어 있는가? [Gap, Research §9]

### iCloud 처리

- [ ] CHK047 - networkAccessAllowed=false 설정 시 "로컬 캐시 없음" 판별 방법이 명시되어 있는가? [Gap, Spec §FR-028]
- [ ] CHK048 - iCloud 전용 사진 비율이 높을 때 사용자 안내 메시지 필요 여부가 정의되어 있는가? [Gap, Edge Case]
- [ ] CHK049 - 썸네일 캐시 크기(~342×256)가 분석 정확도에 미치는 영향이 문서화되어 있는가? [Coverage, Research §7]

### 에러 처리

- [ ] CHK050 - Metal 초기화 실패 시 "전체 정리 중단" 정책이 적절한지 검토되었는가? [Risk, Contracts §10]
- [ ] CHK051 - Vision API 실패 시 SKIP 처리의 로깅/모니터링 방안이 정의되어 있는가? [Gap]
- [ ] CHK052 - 분석 타임아웃 기준(몇 초?)과 처리 정책이 명시되어 있는가? [Gap, Contracts §10]

---

## 요구사항 일관성/추적성

### 문서 간 일관성

- [ ] CHK053 - spec.md의 FR-012~014(Precision 임계값)와 research.md의 임계값이 일치하는가? [Consistency]
- [ ] CHK054 - plan.md의 파이프라인 구조와 contracts의 프로토콜 정의가 일치하는가? [Consistency]
- [ ] CHK055 - data-model.md의 QualitySignal 종류와 research.md의 신호 정의가 일치하는가? [Consistency]

### 누락 항목

- [ ] CHK056 - Recall 모드 Weak 신호 가중치(일반 블러 2점, 기타 1점)가 spec.md에 반영되어 있는가? [Gap, Spec §FR-016]
- [ ] CHK057 - 주머니 샷 복합 조건(휘도+RGB Std+Laplacian+비네팅)이 spec.md에 명시되어 있는가? [Gap]
- [ ] CHK058 - 렌즈 가림 조건(모서리 휘도 < 중앙 × 0.4)이 spec.md에 명시되어 있는가? [Gap]

### 테스트 가능성

- [ ] CHK059 - Success Criteria(SC-001~007)의 측정 방법이 구체적으로 정의되어 있는가? [Measurability, Spec §Success Criteria]
- [ ] CHK060 - "오탐률 5% 이하"의 테스트 데이터셋과 레이블링 기준이 정의되어 있는가? [Gap]

---

## Summary

| 카테고리 | 항목 수 |
|---------|:------:|
| 분석 파이프라인 (임계값/iOS 분기/Safe Guard/특수 미디어) | 19 |
| UX 흐름 (진입/선택/진행/결과) | 14 |
| 데이터/저장 (세션/휴지통/상태) | 10 |
| 성능/비기능 (성능/iCloud/에러) | 9 |
| 일관성/추적성 | 8 |
| **총계** | **60** |

---

## Usage Guide

1. 구현 시작 전 각 항목을 검토하여 요구사항 품질 확인
2. [Gap] 마커 항목은 추가 정의 필요
3. [Ambiguity] 마커 항목은 명확화 필요
4. 체크된 항목은 요구사항이 충분히 정의된 것으로 간주
5. 미체크 항목은 구현 전 해결 또는 의도적 제외 결정 필요
