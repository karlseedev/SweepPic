# Research: PickPhoto MVP

**Branch**: `001-pickphoto-mvp`
**Created**: 2025-12-16
**Status**: 부분 완료 (Gate 2/4 실기기 테스트 보류)

## Overview

PickPhoto MVP의 핵심 기술 결정은 Spike 테스트와 Gate 검증을 통해 완료되었습니다. 본 문서는 그 결과를 정리합니다.

---

## Decision 1: UI Framework

**Decision**: UIKit 기반 (UICollectionView) - 통일성 우선

**Rationale**:
- 대용량 그리드(5만 장)에서 셀 재사용 완전 제어 가능
- 메모리 관리 세밀한 제어
- `performBatchUpdates`를 통한 일정 비용 업데이트 (50k 기준 p95 5ms)

**UI 프레임워크 정책**:
- 기본: UIKit으로 구현
- 예외: SwiftUI가 현저히 유리한 경우, 사용자 확인 후 부분적 하이브리드 허용
- 판단 기준: "UIKit 대비 개발 효율 또는 UX 품질이 현저히 높을 때"

**Alternatives Considered**:
- SwiftUI LazyVGrid: 셀 재사용/메모리 관리에서 불리, 스파이크 없이 제외
- SwiftUI 부분 하이브리드: 사용자 확인 후 허용 가능

---

## Decision 2: Data Source Pattern

**Decision**: `performBatchUpdates` + 수동 배열 관리

**Rationale** (Spike 1 결과):
- 50k 기준 단일 삭제 p95: **5ms** (프레임 예산 16.67ms 내)
- Hitch Time Ratio: **0 ms/s** (Good 등급)
- 스케일링: 50k까지 일정한 비용 관측

**Alternatives Considered**:
- DiffableDataSource: `apply()` 비용이 O(N), 50k에서 52ms/22ms hitch → **불합격**

**Spike 1 상세 결과**:

| 지표 | Plan A (Diffable) | Plan B (BatchUpdates) |
|------|-------------------|----------------------|
| 50k p95 | 52ms | **5ms** |
| Hitch | 22 ms/s ❌ | **0 ms/s** ✅ |
| 스케일링 | 선형 증가 | **일정** |

> 상세: [spiketest.md](../../docs/spiketest.md)

---

## Decision 3: Image Loading

**Decision**: `PHCachingImageManager` 기반 파이프라인 + 스크롤 중 품질 저하

**Rationale**:
- PhotoKit 공식 API로 시스템 최적화 활용
- 프리히트(preheat) 지원
- Gate 2 Mock 테스트: 1k~50k 모두 Good 등급

**Gate 2 실기기 테스트 결과** (38,241 photos):

| 테스트 방식 | hitch | 판정 |
|-------------|-------|------|
| Auto L1 (등속 스크롤) | 0.0 ms/s | ✅ Good |
| Auto L2 (flick 패턴) | 0.0 ms/s | ✅ Good |
| Manual (터치 스크롤) | 27.2 ms/s | ❌ Critical |

**핵심 발견**: Auto vs Manual 차이
- Auto: RunLoop 점유 없이 순차 실행 → hitch 없음
- Manual: 터치 이벤트가 RunLoop 점유 → "마이크로 스터터 누적"

**적용한 개선사항**:
- 스로틀링: `scrollViewDidScroll` 100ms 간격 제한
- 중복 제거: `pendingIdentifiers: Set<String>`
- 요청 취소: `didEndDisplayingCell`에서 취소
- **품질 저하**: 스크롤 중 50% 썸네일 크기

**Key Implementation Rules** (오표시 0 보장):
1. 셀은 `assetID + requestToken` 보유
2. 셀 재사용 시 이전 요청 취소 + 토큰 갱신
3. 콜백 수신 시 현재 토큰과 일치할 때만 이미지 적용

---

## Decision 4: Pinch Zoom Parameters

**Decision**: threshold 0.85/1.15, cooldown 200ms

**Rationale** (Gate 3 Auto 테스트 결과):
- 앵커 drift: **0px** (Auto 테스트 기준)
- longest hitch: **1f (16.7ms)** 1회
- 스케일 무관 일정 성능 (CompositionalLayout 가상화)

| 파라미터 | 값 | 설명 |
|----------|-----|------|
| zoomInThreshold | 0.85 | scale < 0.85 → 확대 |
| zoomOutThreshold | 1.15 | scale > 1.15 → 축소 |
| cooldown | 200ms | 전환 간 최소 간격 |

---

## Decision 5: 120Hz (ProMotion) Policy

**Decision**: 시스템 자동 관리 (잠정 - Mock 테스트 기준, 실사진 테스트 보류)

**Rationale** (Gate 4 Mock 테스트 관찰 결과):
- 컬러 셀 + 50k + 120Hz 실기기에서 hitch 2.0 ms/s (Good)
- 시스템이 콘텐츠에 따라 자동 프레임 레이트 조절
- `preferredFrameRateRange` 강제 시 발열/배터리 트레이드오프

**보류 사항**:
- 실사진 + 120Hz 조합 테스트 후 재검토 필요
- 테스트 결과에 따라 preferredFrameRateRange 적용 여부 결정

---

## Decision 6: Deletion Architecture

**Decision**: 2단계 삭제 (앱 내 휴지통 → iOS 휴지통)

**Rationale**:
- iOS PhotoKit의 `deleteAssets()`는 시스템 확인 팝업 강제 표시
- 빠른 정리 UX를 위해 앱 자체 확인 팝업 제거 필요
- 2단계 삭제로 "팝업 없는 즉각 삭제" + "복구 기능" 동시 제공

**Architecture**:

| 단계 | 동작 | 팝업 |
|------|------|------|
| 1단계 | 앱 내 휴지통 이동 (로컬 상태만 변경) | 없음 |
| 2단계 | PhotoKit `deleteAssets` 호출 | iOS 시스템 팝업 (필수) |

**Alternatives Considered**:
- 즉시 삭제: PhotoKit 팝업 강제 표시로 UX 저해 → **제외**

---

## 완료된 실기기 테스트

| 항목 | 결과 | 비고 |
|------|------|------|
| Gate 2 PhotoKit Provider | Auto: Good, Manual: Critical | 스크롤 중 품질 저하로 개선 |
| 실사진 로딩 latency | 완료 | latency 측정 완료 |

## Pending Research (실기기 테스트)

| 항목 | 필요 조건 | 우선순위 |
|------|----------|----------|
| 120Hz + 실사진 조합 | 실기기 + ProMotion | 중간 |

---

## References

- [TechSpec.md](../../docs/TechSpec.md) - 기술 설계 문서
- [spiketest.md](../../docs/spiketest.md) - Spike/Gate 테스트 결과
- [prd6.md](../../docs/prd6.md) - 제품 요구사항
- [constitution.md](../../.specify/memory/constitution.md) - 프로젝트 헌법
