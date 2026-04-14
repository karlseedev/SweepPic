# Comprehensive Requirements Quality Checklist: 초대 리워드 프로그램

**Purpose**: 스펙/플랜/데이터모델/API 계약 전체에 대한 요구사항 품질 검증
**Created**: 2026-03-26
**Reviewed**: 2026-03-26 (2차 — 전수 보완 후 재검토)
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md) | [data-model.md](../data-model.md) | [contracts/](../contracts/)
**Focus**: UX + API/데이터 모델 + 전체 흐름 통합 + 보안/어뷰징 방지

**Result**: 57 PASS / 0 FAIL

---

## Requirement Completeness

- [x] CHK001 - 로딩 상태 UI가 모든 비동기 화면에 정의되어 있는가? **PASS** — FR-039에서 3가지 상태(로딩/성공/에러) 명세. Story 1 시나리오 5, Story 3 시나리오 7에 구체 동작 정의.
- [x] CHK002 - 네트워크 오프라인 동작이 정의되어 있는가? **PASS** — FR-040에서 오프라인 안내 + NWPathMonitor 기반 자동 재시도 명세.
- [x] CHK003 - 초대 설명 화면 UI가 명세되어 있는가? **PASS** — 260316Reward.md에 와이어프레임 존재 + 스펙 Story 1에서 참조.
- [x] CHK004 - OG 메타태그 구체 값이 정의되어 있는가? **PASS** — FR-021에 og:title, og:description, og:image(1200×630px), og:type 구체 값 명세.
- [x] CHK005 - Push 배지 초기화 시점이 정의되어 있는가? **PASS** — FR-028에서 "Push 수신 시 badge=1, 보상 팝업 표시 시 badge=0 초기화" 명세.
- [x] CHK006 - 보상 수령 팝업 UI가 명세되어 있는가? **PASS** — FR-041에서 블러 배경 + 카드 형태, 제목/본문/버튼/닫기 동작 상세 명세. CelebrationViewController 패턴 재사용.
- [x] CHK007 - 공유 완료 성공 화면이 정의되어 있는가? **PASS** — Story 1 시나리오 4에서 "성공 토스트 2초간 표시 후 자동 닫힘" 명세.
- [x] CHK008 - 코드 보충 실패 시 관리자 알림이 정의되어 있는가? **PASS** — FR-034에서 최종 실패 시 이메일/Slack 알림 발송 명세.
- [x] CHK009 - 분석 이벤트 속성이 정의되어 있는가? **PASS** — FR-045에서 9개 이벤트별 속성(user_id, referral_code, offer_name, entry_method 등) 테이블로 명세.
- [x] CHK010 - Promotional Offer 실패 처리가 정의되어 있는가? **PASS** — Story 3 시나리오 8 + Edge Case에서 에러 안내 + 재시도 + pending 유지 명세.

---

## Requirement Clarity

- [x] CHK011 - "14일 프리미엄 무료" 범위가 명확한가? **PASS** — Offer Code가 pro_monthly/yearly 구독 상품이므로 기존 isProUser 권한과 동일.
- [x] CHK012 - "순차적으로 수령" UX가 정의되어 있는가? **PASS** — Story 3 시나리오 6에서 "가장 오래된 1건 팝업 → 수령 완료 후 다음 자동 표시 → 닫기 시 다음 앱 실행에 재표시" 명세.
- [x] CHK013 - 토큰 갱신 시점이 명확한가? **PASS** — FR-026에서 "sceneWillEnterForeground마다 갱신" 명시.
- [x] CHK014 - 코드 충돌 해결 전략이 명세되어 있는가? **PASS** — FR-001에서 "최대 5회 재생성, 초과 시 서버 에러" 명세.
- [x] CHK015 - subscription_status "none"이 명확한가? **PASS** — API 계약에서 "none = 비구독자 (Free Trial 포함)" 명시. 둘 다 invited_monthly를 받으므로 구분 불필요.
- [x] CHK016 - 보상 만료 알림이 정의되어 있는가? **PASS** — FR-044에서 "무고지(silent) 처리, 만료 보상은 응답에 미포함" 명시적 결정.

---

## Requirement Consistency

- [x] CHK017 - API match-code 응답 status ↔ 스펙 시나리오 대응? **PASS** — 5개 status가 Story 2 + Edge Cases와 정확히 대응.
- [x] CHK018 - 데이터 모델 상태 전이 ↔ API 로직 일치? **PASS** — matched→redeemed→rewarded 일관.
- [x] CHK019 - 5개 ASC Offer ↔ API 매핑 일치? **PASS** — 모든 subscription_status 경우에 정확히 매핑.
- [x] CHK020 - 자동/수동 API 시퀀스가 명세되어 있는가? **PASS** — Story 5 시나리오 2에서 "check-status → match-code 시퀀스, 수동 코드 입력도 동일" 명시.
- [x] CHK021 - UNIQUE 제약 ↔ FR-005 정합? **PASS** — matched 후 취소 → 같은 코드 재시도 가능, 다른 코드 차단.
- [x] CHK022 - Push action_type 양쪽 명세? **PASS** — API + FR-028 양쪽에 정의.

---

## Acceptance Criteria Quality

- [x] CHK023 - SC-003 측정 공식? **PASS** — `code_redeemed / link_shared × 100` 명세.
- [x] CHK024 - SC-004 분모 정의? **PASS** — `completed + expired` 포함, 30일 만료 포함 명세.
- [x] CHK025 - SC-008 측정 시점? **PASS** — reward_shown timestamp - pending_rewards.created_at 중앙값 명세.
- [x] CHK026 - SC-005 노출 대상자 정의? **PASS** — "게이트 팝업/한도 바 팝업을 본 무료 사용자 + 축하 화면을 본 유료 사용자" 명세.

---

## Scenario Coverage — UX 흐름

- [x] CHK027 - 정규식 실패 UI? **PASS** — FR-006에 "매칭 실패 시 '초대 코드를 찾을 수 없습니다' 안내" 명세.
- [x] CHK028 - 다수 코드 우선순위? **PASS** — FR-006에 "다수 매칭 시 첫 번째 코드 사용" 명세.
- [x] CHK029 - 링크 생성 서버 실패? **PASS** — Story 1 시나리오 6에서 에러 안내 + [다시 시도] 명세.
- [x] CHK030 - 코드 입력 메뉴 위치? **PASS** — FR-042에서 "설정 > 프리미엄 내 '친구 초대' + '초대 코드 입력' + '초대 혜택 받기' 3개 항목" 명세.
- [x] CHK031 - Push 포그라운드 수신? **PASS** — FR-028에서 "인앱 배너(banner, sound)로 표시, 탭 시 보상 화면 이동" 명세.

---

## Scenario Coverage — 전체 흐름 통합

- [x] CHK032 - Universal Link 첫 실행 전 제한? **PASS** — Edge Case에서 "Apple은 첫 실행 후에야 Universal Link 활성화, Custom URL Scheme 폴백으로 대응" 명세.
- [x] CHK033 - 기존 설치자 첫 클릭? **PASS** — Story 5가 커버.
- [x] CHK034 - 초대 vs 일반 Offer 구분? **PASS** — offerName 매칭으로 구분.
- [x] CHK035 - 결제 중 앱 종료? **PASS** — Story 3 시나리오 9 + Edge Case에서 Transaction.updates 자연 복구 + 팝업 재표시 명세.
- [x] CHK036 - report-redemption 실패 재시도? **PASS** — FR-035에서 지수 백오프 3회 + 다음 실행 시 Transaction.updates 재감지 명세.

---

## Edge Case Coverage

- [x] CHK037 - 정규식 오탐? **PASS** — 확률 극히 낮음 + 서버 유효성 검증.
- [x] CHK038 - Keychain 비공유 자기 초대? **PASS** — Apple 1인1오퍼 제한으로 피해 제한.
- [x] CHK039 - 만료 코드 재할당? **PASS** — Edge Case에서 "check-status에서 만료 확인 → 새 코드 할당 → 새 리딤 URL 반환, 기존 코드 expired 처리" 명세.
- [x] CHK040 - 결제 수단 미등록? **PASS** — Edge Case에서 "리딤 시트 실패/취소 → matched 상태 유지" 명세.
- [x] CHK041 - reward_01→Promotional 전환? **PASS** — Story 3 시나리오 4에서 명확히 명세.

---

## Non-Functional Requirements — 보안 & 어뷰징

- [x] CHK042 - Rate limiting? **PASS** — FR-037에서 엔드포인트별 분당 한도 + 429 응답 명세.
- [x] CHK043 - user_id 사칭 방지? **PASS** — FR-038에서 HMAC 서명 명세 + rate limit 1차 방어.
- [x] CHK044 - 코드 엔트로피? **PASS** — 36^6 ≈ 22억 + rate limit.
- [x] CHK045 - device_token 검증? **PASS** — FR-026에서 "APNs 410 Gone 시 token NULL 설정" 명세.
- [x] CHK046 - Replay 공격? **PASS** — status == pending 확인으로 거부.
- [x] CHK047 - P8 키 관리? **PASS** — FR-046~047에서 Vault 저장 + 환경 변수 관리 + 유출 시 즉시 교체 명세.

---

## Non-Functional Requirements — 성능 & 가용성

- [x] CHK048 - 서버 다운 폴백? **PASS** — FR-036 + FR-043에서 에러 안내 + 재시도 + HTTP 상태별 처리 명세.
- [x] CHK049 - 락 타임아웃? **PASS** — FR-033에서 "5초 타임아웃, 초과 시 에러 반환" 명세.
- [x] CHK050 - 피크 처리량? **PASS** — FR-049에서 "초당 50건 이상" 목표 명세.

---

## Dependencies & Assumptions

- [x] CHK051 - Keychain 유지 가정? **PASS** — 기존 UsageLimitStore에서 동일 패턴 검증됨.
- [x] CHK052 - PremiumMenu 존재? **PASS** — 코드베이스에서 확인됨.
- [x] CHK053 - 도메인 미구매 개발 폴백? **PASS** — FR-048에서 Supabase 기본 도메인 폴백 + CUSTOM_DOMAIN 환경 변수 전환 명세.
- [x] CHK054 - Offer Code 한도 충분? **PASS** — 분기 1M × 3개 = 충분.

---

## Ambiguities & Conflicts

- [x] CHK055 - HTTP 에러 처리? **PASS** — FR-043에서 200/429/500/타임아웃별 클라이언트 처리 명세.
- [x] CHK056 - 코드 입력 경로 2개? **PASS** — Out of Scope + FR-042에서 명확.
- [x] CHK057 - FK 제약 의도? **PASS** — data-model.md에 "의도적으로 DB 수준 FK 미설정, Edge Function에서 참조 무결성 검증" 명세.

---

## Notes

- 1차 검토(39 FAIL) → 스펙 보완 → 2차 검토(57 PASS)
- 추가된 FR: FR-034~FR-049 (16개), 총 FR 49개
- 추가된 Edge Cases: 5개, 총 19개
- 추가된 Story 시나리오: Story 1 +2개, Story 3 +3개
- SC 전체에 측정 공식 추가
