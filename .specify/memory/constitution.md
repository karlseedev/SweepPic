<!--
Sync Impact Report
==================
Version change: 1.0.4 → 1.1.0
Added: VI. 단계적 검증 (Incremental Validation) 원칙 추가
Templates requiring updates: None
Follow-up TODOs: None
-->

# PickPhoto Constitution

## Core Principles

### I. 대용량 전제 (Large-Scale Baseline)

5만 장 라이브러리에서도 목표 UX/성능을 유지한다.

### II. 모션 품질 (Motion Quality)

iOS 기본 사진 앱 수준의 부드러운 스크롤과 전환 경험을 제공해야 한다.

### III. 핀치 줌 앵커 (Pinch-Zoom Anchor)

핀치 제스처 중심점 아래 콘텐츠가 앵커로 유지되어야 한다.

### IV. 삭제 안정성 (Delete Stability)

삭제 후 UI가 안정적으로 수렴해야 한다.
- 뷰어 삭제 시 "이전 사진 우선" 이동 규칙
- 1단계(앱 내 휴지통 이동): 앱 자체 확인 팝업 없이 즉시 이동
- 2단계(완전 삭제): iOS 시스템 팝업은 필수 (PhotoKit 제약)

### V. 메모리 제한 (Memory Limit)

장시간 사용 후에도 메모리 상한 이내를 유지해야 한다.

### VI. 단계적 검증 (Incremental Validation)

모든 기능은 단계적으로 개발하고 검증한다. 각 단계는 독립적 가치와 테스트 가능성을 갖고, 다음 단계로 넘어가기 전에 사용성 검증을 완료한다.

## Performance KPI

| 항목 | 기준 | 출처 |
|------|------|------|
| 오표시 | 0 | 품질 필수 |
| 메모리 상한 | 250MB | [BrowserStack](https://www.browserstack.com/guide/how-to-conduct-ios-performance-testing) |

기타 성능 수치는 PRD에서 정의한다.

## Governance

- 본 헌법은 모든 기능 구현에 우선한다
- 헌법 위반 사항은 명시적 정당화와 문서화 필요
- 성능 KPI는 Instruments로 측정 검증

**Version**: 1.1.0 | **Ratified**: 2025-12-16 | **Last Amended**: 2025-12-16
