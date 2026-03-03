# Checklist: 보안 + 악용 방지 요구사항 품질

**Purpose**: Keychain 저장, 서버 시간, 재설치 방지, 오프라인 우회 등 보안/악용 방지 요구사항의 완전성/명확성 검증
**Created**: 2026-03-03
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md) | [research.md](../research.md)
**Focus**: 악용 방지, 데이터 무결성, 오프라인 동작, 구독 보안

---

## Requirement Completeness

- [ ] CHK063 - Keychain에 저장할 데이터의 정확한 범위가 정의되어 있는가? UsageLimit 전체인지, 일부 필드만인지? [Completeness, Spec §FR-051]
- [ ] CHK064 - Keychain 접근 권한 수준(kSecAttrAccessible 값)이 요구사항으로 정의되어 있는가? (AfterFirstUnlock vs WhenUnlocked 등) [Completeness, Gap]
- [ ] CHK065 - "온라인 시 서버 시간 기준"(FR-052)에서 "온라인" 판단 기준이 정의되어 있는가? (Reachability? Supabase 응답 성공?) [Completeness, Spec §FR-052]
- [ ] CHK066 - 서버 시간 확인 실패(Supabase 다운, 네트워크 오류) 시 한도 리셋 동작이 정의되어 있는가? [Completeness, Gap]
- [ ] CHK067 - 오프라인 구독자의 "로컬 캐시 기반 구독 확인"(FR-053)에서 캐시 만료 정책이 정의되어 있는가? (무기한? N일?) [Completeness, Spec §FR-053]
- [ ] CHK068 - 구독 환불 감지(FR-033) 시 "즉시 해제"의 감지 시점이 정의되어 있는가? (앱 실행 시? 포그라운드 진입 시? 실시간?) [Completeness, Spec §FR-033]
- [ ] CHK069 - Grace Period 악용(앱 삭제 → 재설치로 3일 리셋) 방지 요구사항이 있는가? UsageLimit은 Keychain에 있지만 Grace Period의 installDate는 UserDefaults → 리셋 가능 [Gap, Spec §Edge Cases]

## Requirement Clarity

- [ ] CHK070 - "앱 삭제/재설치에도 유지되는 보안 저장소"(FR-051)의 "보안 저장소"가 Keychain으로 확정되었는데, plan.md에만 있고 spec.md에는 구현 세부사항이 없는 것이 의도된 것인가? [Clarity, Spec §FR-051]
- [ ] CHK071 - "기기 시계 조작으로 우회할 수 없어야 한다"(FR-052)에서 "우회할 수 없다"의 범위가 명확한가? 100% 방지인지, 합리적 수준의 방어인지? [Clarity, Spec §FR-052]
- [ ] CHK072 - 오프라인 상태에서 시계를 앞으로 돌려 한도를 리셋한 뒤, 온라인 복귀 시 교정 동작이 구체적으로 정의되어 있는가? (이미 삭제한 사진을 되돌릴 수는 없으므로, 교정의 범위는?) [Clarity, Research §R5]
- [ ] CHK073 - "결제 유예 기간 16일"(Edge Cases)이 Apple의 Billing Grace Period 설정이므로 ASC 설정만으로 충분한지, 앱 코드에서도 별도 처리가 필요한지 명시되어 있는가? [Clarity, Spec §Edge Cases]

## Requirement Consistency

- [ ] CHK074 - FR-051(Keychain 유지)과 Grace Period(UserDefaults installDate)의 보호 수준 불일치가 인지되고 수용 가능한 것으로 문서화되어 있는가? [Consistency, Spec §FR-051 vs §FR-023]
- [ ] CHK075 - FR-052(서버 시간 기반 리셋)과 FR-005(이중 체크: 포그라운드 + 자정)의 구현이 일관되는가? 포그라운드 진입 시 서버 시간 확인 → 리셋 vs 자정 로컬 타이머 → 리셋의 우선순위는? [Consistency, Spec §FR-052 vs §FR-005]
- [ ] CHK076 - 오프라인 무료 사용자의 한도 내 삭제(FR-054)와 서버 시간 기반 리셋(FR-052)이 일관되는가? (오프라인이면 서버 시간 확인 불가 → 로컬 리셋 허용 → 시계 조작 가능) [Consistency, Spec §FR-054 vs §FR-052]

## Scenario Coverage

- [ ] CHK077 - 기기 변경(새 iPhone으로 이전) 시 Keychain 데이터 이전 시나리오가 정의되어 있는가? (iCloud Keychain 동기화 여부) [Coverage, Gap]
- [ ] CHK078 - 동일 Apple ID로 여러 기기에서 사용 시 한도가 기기별 독립인지 동기화되는지 정의되어 있는가? [Coverage, Gap]
- [ ] CHK079 - StoreKit 2 Transaction.updates에서 예상치 못한 상태(unknown, pending)의 처리가 정의되어 있는가? [Coverage, Gap]
- [ ] CHK080 - 앱이 포그라운드에서 자정을 넘기는 경우의 한도 리셋이 FR-005에 언급되어 있지만, 정확한 감지 메커니즘이 정의되어 있는가? [Coverage, Spec §FR-005]
- [ ] CHK081 - 구독 구매 직후 네트워크 끊김으로 Transaction이 서버에 확인되지 않는 시나리오가 정의되어 있는가? (StoreKit 2는 로컬 검증이므로 해당 없을 수 있음 — 명시 필요) [Coverage, Gap]

## Edge Case Coverage

- [ ] CHK082 - Keychain 접근 실패(잠금 화면, 기기 보호 비활성화 등) 시 폴백 동작이 정의되어 있는가? [Edge Case, Gap]
- [ ] CHK083 - DeletionStats.json 파일 손상/삭제 시 복구 전략이 정의되어 있는가? (0으로 초기화? 에러 무시?) [Edge Case, Gap]
- [ ] CHK084 - 사용자가 설정에서 앱의 Keychain 항목을 수동 삭제하는 경우(탈옥 기기 등)의 처리가 정의되어 있는가? [Edge Case, Gap]
- [ ] CHK085 - App Store 심사 시 테스트 계정에서의 한도/게이트 동작이 정의되어 있는가? (심사관이 게이트에 막히면 리젝 위험) [Edge Case, Gap]

## Non-Functional Security Requirements

- [ ] CHK086 - Keychain에 저장되는 데이터의 암호화 수준 요구사항이 정의되어 있는가? (Keychain 기본 암호화로 충분한지) [Security, Gap]
- [ ] CHK087 - 분석 이벤트 전송(TelemetryDeck, Supabase) 시 민감 데이터(구독 상태, 한도 정보) 포함 범위가 정의되어 있는가? [Privacy, Gap]
- [ ] CHK088 - ATT 거부 시에도 전송되는 분석 데이터의 범위가 개인정보보호법/GDPR 관점에서 정의되어 있는가? [Compliance, Gap]
- [ ] CHK089 - StoreKit 2의 온디바이스 검증만으로 구독 위조(탈옥 기기 등) 방어가 충분한지 리스크 평가가 문서화되어 있는가? [Security, Gap]
