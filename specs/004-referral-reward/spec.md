# Feature Specification: 초대 리워드 프로그램

**Feature Branch**: `004-referral-reward`
**Created**: 2026-03-26
**Status**: Draft
**Input**: 260316Reward.md 기반 — Offer Code URL Redemption + Promotional Offer 하이브리드 초대 보상 시스템

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 초대 링크 생성 및 공유 (Priority: P1)

초대자가 앱 내에서 고유한 초대 링크를 생성하고, 카카오톡/인스타그램/메시지 등으로 친구에게 공유한다. 공유 메시지에는 초대 코드, 설치 안내, 수동 입력 폴백 안내가 포함된다.

**Why this priority**: 초대 프로그램의 진입점. 이 기능 없이는 전체 플로우가 시작되지 않음.

**Independent Test**: 초대하기 버튼 탭 → 초대 설명 화면 확인 → 공유 시트에서 메시지 내용 확인 → 공유 완료 후 Push 프리프롬프트 표시까지 독립적으로 테스트 가능.

**Acceptance Scenarios**:

1. **Given** 사용자가 앱에 로그인된 상태, **When** "초대하기" 버튼을 탭, **Then** 초대 설명 화면이 표시되고, 초대하기를 탭하면 고유 초대 코드(`x0{6자리영숫자}9j` 형식)가 생성되어 공유 시트가 열린다.
2. **Given** 초대자가 이전에 초대 코드를 생성한 적 있음, **When** "초대하기"를 다시 탭, **Then** 동일한 기존 초대 코드가 재사용된다 (새로 생성하지 않음).
3. **Given** 공유 시트가 열림, **When** 카카오톡으로 공유, **Then** 메시지에 초대 코드, 설치 링크(`{domain}/r/{code}`), 수동 입력 폴백 안내가 포함된다.
4. **Given** 공유 완료 후 앱 복귀 (completionHandler completed=true), Push 프리프롬프트를 아직 한 번도 표시한 적 없음, **When** 복귀 감지, **Then** Push 권한 상태에 따라 분기:
   - `.notDetermined`: 프리프롬프트 "친구가 가입하면 알려드릴까요?" + [알림 받기] + [닫기]. [알림 받기] → 시스템 Push 권한 팝업. [닫기] → 프리프롬프트 닫힘.
   - `.denied`: 프리프롬프트 동일 UI + [알림 받기] → 알림 꺼짐 안내 ("알림이 꺼져 있어요. 설정에서 SweepPic 알림을 켜면 친구 가입 소식을 받을 수 있어요") + [설정으로 이동] / [나중에]. [닫기] → 프리프롬프트 닫힘.
   - `.authorized`: 프리프롬프트 미표시.
   - 프리프롬프트는 결과에 관계없이 **1회만 표시**. 표시 여부를 로컬에 기록하여 다음 공유 시 재표시하지 않음.
5. **Given** 공유 완료 후 앱 복귀, 프리프롬프트를 이전에 이미 표시한 적 있음, **When** 복귀 감지, **Then** 프리프롬프트 미표시. 초대 설명 화면으로 복귀.
6. **Given** 공유 시트에서 취소 (completionHandler completed=false), **When** 취소 감지, **Then** 초대 설명 화면 유지 (아무 동작 없음).
7. **Given** "초대하기" 탭 후 서버와 통신 중, **When** 코드 생성 대기, **Then** 버튼이 로딩 스피너로 전환되고 중복 탭이 차단된다.
8. **Given** 서버 통신 실패 (네트워크 오류 또는 서버 다운), **When** 코드 생성 실패, **Then** "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." 에러 안내와 [다시 시도] 버튼이 표시된다.

---

### User Story 2 - 피초대자 앱 설치 및 혜택 적용 (Priority: P1)

피초대자가 초대 링크를 통해 앱을 설치한 후, 초대 코드를 입력하여 14일 프리미엄 무료 혜택을 받는다. 코드 입력 시 메시지 전체를 붙여넣으면 자동으로 코드를 추출한다.

**Why this priority**: 피초대자의 핵심 가치 제안. 혜택 적용이 안 되면 초대 프로그램의 의미가 없음.

**Independent Test**: 초대 코드를 받은 사용자가 앱 설치 → 코드 입력 → 14일 프리미엄 활성화까지 독립적으로 테스트 가능.

**Acceptance Scenarios**:

1. **Given** 피초대자가 초대 링크 클릭, **When** 랜딩 페이지 로드, **Then** App Store 앱 페이지로 리다이렉트되어 앱 설치를 유도한다 (이 시점에는 혜택 적용 안 됨).
2. **Given** 앱이 설치되고 피초대자가 "초대 코드 입력" 메뉴 진입, **When** 카톡 메시지 전체를 붙여넣기, **Then** 정규식(`/x0([a-zA-Z0-9]{6})9j/`)으로 코드를 자동 추출하여 인식한다.
3. **Given** 유효한 초대 코드 입력, **When** 코드 매칭 성공, **Then** 피초대자 구독 상태에 따른 적절한 Offer Code가 할당되고, App Store 리딤 시트가 열린다.
4. **Given** App Store 리딤 시트에서 "확인" + Face ID 완료, **When** 리딤 성공, **Then** 14일 프리미엄이 시작되고, "초대 코드가 적용되었습니다! 초대 코드는 1회만 입력할 수 있습니다." 메시지가 표시된다.
5. **Given** 피초대자가 코드 입력 메뉴 진입, 서버에 이미 matched 상태 (코드 매칭됨, 리딤 미완료), **When** check-status 결과 matched, **Then** "혜택이 아직 적용되지 않았어요" 메시지와 [혜택 받기] 버튼을 표시한다. 탭 시 이전에 할당된 코드(만료 시 새 코드)로 리딤 URL을 다시 연다. (붙여넣기 화면을 보여주지 않음)
6. **Given** 피초대자가 코드 입력 메뉴 진입, 서버에 이미 redeemed 상태 (리딤 완료), **When** check-status 결과 redeemed, **Then** "이미 초대 코드가 적용되어 있습니다." 메시지를 표시하고 추가 입력을 막는다.
7. **Given** 피초대자가 코드 입력 메뉴 진입, 서버에 레코드 없음, **When** check-status 결과 none, **Then** 붙여넣기 화면을 표시한다.
8. **Given** 피초대자가 자신의 초대 코드 입력 시도, **When** 서버에서 자기 초대 감지, **Then** "본인의 초대 코드는 사용할 수 없습니다" 메시지를 표시하고 중단한다.

---

### User Story 3 - 초대자 보상 수령 (Priority: P1)

피초대자가 Offer Code를 리딤 완료하면, 초대자에게 14일 프리미엄/구독 연장 보상이 생성된다. 초대자는 앱 실행 시 보상 팝업을 통해 보상을 수령한다.

**Why this priority**: 초대자의 핵심 인센티브. 보상 없으면 초대 동기가 사라짐.

**Independent Test**: 피초대자 리딤 완료 → 초대자 보상 생성 → 초대자 앱 실행 시 팝업 → 보상 수령까지 독립적으로 테스트 가능.

**Acceptance Scenarios**:

1. **Given** 피초대자가 Offer Code 리딤 완료, **When** 서버에서 리딤 감지, **Then** 초대자의 보상 대기 기록이 생성된다 (보상 유형은 수령 시점에 결정).
2. **Given** 초대자가 현재 구독자 또는 과거 구독 이력 있음, **When** "보상 받기" 탭, **Then** Promotional Offer로 앱 내에서 즉시 14일 구독 연장이 적용된다 (App Store 리딤 시트 불필요).
3. **Given** 초대자가 한 번도 구독한 적 없음, **When** "보상 받기" 탭, **Then** Offer Code가 할당되어 App Store 리딤 시트를 통해 14일 무료 구독이 시작된다.
4. **Given** 초대자가 한 번도 구독한 적 없는 상태에서 첫 보상을 리딤하여 구독자가 됨 → 이후 해지/만료, **When** 두 번째 보상 수령, **Then** 이제 "만료 구독자"이므로 Promotional Offer 경로로 자동 전환된다.
5. **Given** 보상 대기 기록이 30일 경과, **When** 만료 기간 도달, **Then** 보상 상태가 "expired"로 변경된다.
6. **Given** 초대자에게 다수의 보상이 대기 중, **When** 앱 콜드 스타트, **Then** 가장 오래된 보상 1건의 팝업이 표시된다. 수령 완료 후 다음 보상 팝업이 자동으로 표시된다. 닫기 시 팝업은 닫히고, 남은 보상은 다음 콜드 스타트 시 다시 표시. 포그라운드 복귀 시에는 팝업 미표시. 팝업을 놓쳐도 설정 > 프리미엄 > "초대 혜택 받기" 메뉴에서 언제든 수령 가능.
7. **Given** 초대자가 "보상 받기" 탭 후 서버와 통신 중, **When** 서명 생성 또는 코드 할당 대기, **Then** 버튼이 로딩 스피너로 전환된다.
8. **Given** Promotional Offer 구매가 StoreKit 에러로 실패, **When** 실패 감지, **Then** "혜택 적용에 실패했습니다. 잠시 후 다시 시도해주세요." 안내와 [다시 시도] 버튼이 표시된다. pending_rewards 상태는 pending 유지.
9. **Given** 보상 수령 중 앱이 백그라운드 전환 또는 종료, **When** 다음 앱 실행 시, **Then** StoreKit 2의 Transaction.updates가 미완료 거래를 전달하여 자연 복구. pending_rewards 상태가 completed가 아니면 팝업을 다시 표시.

---

### User Story 4 - 초대 프로그램 노출 및 발견 (Priority: P2)

사용자가 초대 프로그램의 존재를 적절한 시점에 인지하도록, 동기 강도가 높은 순간에 초대 프로모션을 노출한다.

**Why this priority**: 사용자가 초대 프로그램을 모르면 사용하지 않음. 그러나 핵심 플로우(P1)가 없으면 노출해도 의미 없으므로 P2.

**Independent Test**: 각 노출 포인트(무료삭제한도 바 팝업, 게이트 팝업, 축하 화면, 설정 메뉴)에서 초대 프로모션 UI가 정상 표시되는지 독립적으로 확인 가능.

**Acceptance Scenarios**:

1. **Given** 무료 사용자가 삭제 한도에 도달하여 한도 바 팝업이 표시됨, **When** 팝업 하단 확인, **Then** "초대 한 번마다 나도 친구도 14일 프리미엄 제공!" 텍스트와 [초대하기] 버튼이 표시된다.
2. **Given** 무료 사용자가 기능 게이트에 막혀 게이트 팝업이 표시됨, **When** 팝업 하단 확인, **Then** 동일한 초대 프로모션 UI가 표시된다.
3. **Given** 유료 사용자가 사진 정리를 완료하여 축하 화면이 표시됨, **When** 화면 확인, **Then** "친구에게도 알려주세요" 텍스트와 초대 버튼이 표시된다.
4. **Given** 사용자가 설정 > 프리미엄 메뉴에 진입, **When** 메뉴 목록 확인, **Then** "친구 초대", "초대 코드 입력", "초대 혜택 받기" 3개 항목이 표시된다. "친구 초대" 탭 시 초대 설명 화면, "초대 코드 입력" 탭 시 코드 입력 화면, "초대 혜택 받기" 탭 시 보상 수령 화면(모달)으로 이동한다.

---

### User Story 5 - 링크 재탭 자동 처리 (Priority: P2)

피초대자가 앱 설치 후 같은 초대 링크를 다시 탭하면, 수동 코드 입력 없이 자동으로 초대 코드가 매칭되고 혜택이 적용된다.

**Why this priority**: 사용자 경험을 크게 개선하는 편의 기능이지만, 수동 코드 입력(P1)이 있으므로 필수는 아님.

**Independent Test**: 앱 설치 완료 상태에서 초대 링크를 다시 탭 → 앱이 열리며 코드 자동 추출 → 리딤 URL 열기까지 테스트 가능.

**Acceptance Scenarios**:

1. **Given** 앱이 설치된 상태에서 카카오톡의 초대 링크를 다시 탭, **When** Safari로 전환 후 랜딩 페이지 로드, **Then** Universal Link 또는 Custom URL Scheme으로 앱이 열리고, URL에서 초대 코드가 자동 추출된다.
2. **Given** 앱이 코드를 자동 추출, **When** 서버에 check-status 호출 → 레코드 없음 → match-code 호출, **Then** 신규 초대이면 자동으로 Offer Code 할당 + 리딤 URL 열기가 수행된다. (수동 코드 입력(Story 2)도 동일한 check-status → match-code 시퀀스를 사용한다.)
3. **Given** 이미 리딤 완료된 상태(status=redeemed), **When** 링크를 다시 탭, **Then** 자동 처리를 무시한다 (중복 처리 방지).
4. **Given** 이전에 매칭되었으나 리딤 미완료(status=matched), **When** 링크를 다시 탭, **Then** 이전에 할당된 코드(만료 시 새 코드)로 리딤 URL을 다시 연다.
5. **Given** 자기 자신의 초대 링크를 탭 (초대자 user_id == 내 user_id), **When** 자기 초대 감지, **Then** "본인의 초대 코드는 사용할 수 없습니다" 메시지를 표시하고 자동 처리를 중단한다.

---

### User Story 6 - 초대자 Push 알림 (Priority: P3)

피초대자가 가입 완료하면 초대자에게 Push 알림을 보내 보상 수령을 유도한다. Push 미허용 사용자는 다음 앱 실행 시 인앱 팝업으로 폴백한다.

**Why this priority**: 보상 수령 적시성을 높이지만, 인앱 팝업 폴백이 있으므로 없어도 기능은 작동함.

**Independent Test**: Push 권한 허용 사용자가 초대 → 피초대자 가입 → Push 수신 → 탭 → 보상 화면 직행까지 테스트 가능.

**Acceptance Scenarios**:

> Push 권한 요청(프리프롬프트)은 Story 1 시나리오 4~6에서 정의. 이 Story는 Push 발송/수신 동작에 집중.

1. **Given** 초대자가 Push 허용 상태 (device token 서버 저장됨), **When** 피초대자가 리딤 완료, **Then** 초대자에게 Push 알림이 발송된다 ("초대한 사람이 SweepPic에 가입했어요! 14일 무료 혜택을 받으세요").
2. **Given** Push 탭으로 앱 진입, **When** 앱 실행, **Then** 보상 수령 화면으로 직행한다.
3. **Given** 초대자가 Push 미허용 (device token 없음), **When** 피초대자 가입 완료 후 초대자가 앱을 다음에 실행, **Then** 인앱 보상 팝업이 표시된다 (Push 발송 없이 폴백).
4. **Given** 초대자가 앱 사용 중(포그라운드)에 Push 수신, **When** 인앱 배너 표시, **Then** 배너 탭 시 보상 수령 화면으로 이동.

---

### User Story 7 - Offer Code 재고 자동 관리 (Priority: P3)

Offer Code 풀이 소진되지 않도록 자동으로 재고를 확인하고 보충하는 파이프라인을 운영한다.

**Why this priority**: 운영 안정성 기능. 초기에는 수동 관리도 가능하므로 P3이지만, 규모가 커지면 필수.

**Independent Test**: Offer Code 잔여량이 임계값 미만일 때 자동 보충이 트리거되는지 테스트 가능.

**Acceptance Scenarios**:

1. **Given** 특정 Offer Name의 사용 가능한 코드가 5,000개 미만, **When** 매일 새벽 자동 체크 실행, **Then** App Store Connect API를 통해 새 코드를 생성하고 풀에 추가한다.
2. **Given** 코드 생성 실패, **When** 재시도 로직 실행, **Then** 1시간 → 3시간 → 6시간 간격으로 최대 3회 재시도한다.
3. **Given** 코드의 Apple 만료일이 지남, **When** 매일 정리 작업 실행, **Then** 만료된 코드의 상태를 "expired"로 변경한다.
4. **Given** 코드 풀이 비어있는 상태에서 피초대자가 코드 입력, **When** 할당할 코드 없음, **Then** 사용자에게 "일시적으로 혜택을 적용할 수 없습니다. 잠시 후 다시 시도해주세요." 안내를 표시한다.

---

### Edge Cases

- **피초대자가 Free Trial 이용 중 초대 코드 입력**: Apple의 Introductory Offer 중복 정책에 따라 Free Trial 7일 → Offer Code 14일 → 정상 가격 순으로 순차 적용됨 (ASC에서 "Introductory Offer 적용 여부 = Yes" 설정 전제).
- **피초대자가 yearly 구독자**: `referral_invited_yearly` Offer Code가 할당되어 다운그레이드 방지. monthly Offer Code를 yearly 구독자에게 할당하면 다운그레이드 발생.
- **동일인이 2대 기기에서 자기 초대**: 동일 Apple ID의 Keychain이 공유되므로 같은 user_id로 자기 초대 감지됨.
- **초대 링크의 코드가 유효하지 않음** (변조/오타): 서버에서 referral_links 조회 실패 시 "유효하지 않은 코드" 안내.
- **인앱 브라우저에서 링크 클릭**: SNS별 대응 (카카오톡: 외부 브라우저 전환 스킴, LINE: openExternalBrowser 파라미터, Instagram/Facebook/X: App Store 페이지 리다이렉트 시도).
- **App Store 리딤 시트에서 취소**: 리딤 미완료 상태(matched)가 유지되며, 다음에 코드 입력 메뉴 진입 시 "혜택이 아직 적용되지 않았어요" + [혜택 받기] 버튼 표시.
- **앱 삭제 후 재설치**: Keychain 기반 user_id는 유지되므로, 이미 리딤한 사용자는 재설치 후에도 중복 적용 불가.
- **초대자의 구독 상태가 보상 대기 중 변경**: 보상 유형(Promotional Offer vs Offer Code)은 수령 시점에 결정되므로, 대기 중 구독 상태 변경에 자연스럽게 대응.
- **다수의 초대자가 동시에 링크 공유 → 피초대자 다수 유입**: 각 피초대자가 각자의 초대 코드를 입력하므로, 초대 코드 기반 매칭으로 혼선 없음 (시간 기반 매칭이 아님).
- **피초대자가 초대 코드를 2번 입력 시도**: 서버에서 이미 redeemed 상태이므로 "이미 초대 코드가 적용되어 있습니다" 안내.
- **코드 입력 시 정규식 매칭 실패** (코드 없는 텍스트 붙여넣기): "초대 코드를 찾을 수 없습니다. 받은 메시지를 다시 확인해주세요." 안내 표시.
- **Promotional Offer 구매 실패** (StoreKit 에러): "혜택 적용에 실패했습니다. 잠시 후 다시 시도해주세요." 안내 + [다시 시도] 버튼. pending_rewards 상태는 pending 유지.
- **앱 설치 직후 링크 재탭 시 Universal Link 미작동**: Apple은 앱 첫 실행 후에야 Universal Link를 활성화함. 설치 직후(한 번도 실행 안 함) 링크 재탭 시 Custom URL Scheme 폴백으로 처리. 랜딩 페이지의 JS가 Custom URL Scheme을 시도하므로 자연스럽게 대응됨.
- **Push 알림을 앱 포그라운드에서 수신**: 인앱 배너(UNNotificationPresentationOptions)로 표시. 탭 시 보상 수령 화면으로 이동.
- **피초대자가 App Store에 결제 수단 미등록 상태에서 리딤 시도**: Apple이 결제 수단 등록을 요구할 수 있음. 리딤 시트에서 실패/취소 시 matched 상태 유지. App Store 리딤 시트 취소와 동일하게 처리.
- **matched 상태에서 할당된 Offer Code가 Apple 만료일 경과**: check-status API에서 matched 상태이면 할당된 코드의 만료 여부를 확인하고, 만료 시 offer_codes에서 새 코드를 할당하여 새 리딤 URL을 반환한다. 기존 만료 코드는 expired 처리.
- **보상 수령 중 앱이 백그라운드 전환 또는 종료**: Promotional Offer의 경우 StoreKit 2의 Transaction.updates가 다음 실행 시 미완료 거래를 전달하여 자연 복구. Offer Code의 경우 리딤 URL이 이미 열렸으므로 App Store가 처리. pending_rewards가 completed가 아니면 다음 앱 실행 시 팝업 재표시.

## Requirements *(mandatory)*

### Functional Requirements

**초대 링크 및 코드**

- **FR-001**: 시스템은 사용자당 하나의 고유 초대 코드를 생성해야 한다. 코드 형식: `x0{6자리 영숫자}9j` (예: `x0k7m2x99j`). 내부 6자리 코드는 "x0"으로 시작하거나 "9j"로 끝나지 않아야 한다 (충돌 방지). 생성 시 UNIQUE 충돌이 발생하면 최대 5회 재생성을 시도하고, 5회 초과 시 서버 에러를 반환한다.
- **FR-002**: 초대 링크는 `{도메인}/r/{초대코드}` 형식이어야 한다. 커스텀 도메인 사용 (브랜딩용).
- **FR-003**: 공유 메시지에는 다음 내용이 포함되어야 한다: (1) 앱 소개 문구, (2) 초대 코드 (평문), (3) 설치 링크, (4) 링크 재탭 안내, (5) 수동 코드 입력 폴백 안내.
- **FR-004**: 초대자당 초대 코드는 영구적이며, 동일 사용자가 여러 번 공유하더라도 같은 코드를 재사용해야 한다.

**피초대자 혜택 적용**

- **FR-005**: 피초대자는 초대 코드를 1회만 입력할 수 있다. 이미 적용된 경우 재입력을 차단해야 한다.
- **FR-006**: 코드 입력 시, 메시지 전체/일부/코드만 붙여넣기 모두 지원해야 한다. 정규식 `/x0([a-zA-Z0-9]{6})9j/`로 코드를 자동 추출한다. 매칭 실패 시 "초대 코드를 찾을 수 없습니다" 안내를 표시한다. 다수 매칭 시 첫 번째 코드를 사용한다.
- **FR-007**: 자기 초대을 감지하고 차단해야 한다 (초대자 user_id == 피초대자 user_id).
- **FR-008**: 피초대자의 구독 상태에 따라 적절한 Offer를 할당해야 한다: 비구독/무료/monthly 구독자 → `referral_invited_monthly`, yearly 구독자 → `referral_invited_yearly`.
- **FR-009**: Offer Code 할당은 코드 입력 또는 링크 재탭 시점에 수행해야 한다 (미리 할당하지 않음).
- **FR-010**: Offer Code 리딤 URL을 열어 App Store 리딤 시트를 표시해야 한다. 코드가 자동 입력된 상태로 열림.

**초대자 보상**

- **FR-011**: 피초대자 리딤 완료 시, 초대자에게 보상 대기 기록을 생성해야 한다. 보상 유형은 수령 시점에 결정한다.
- **FR-012**: 초대자가 현재 구독자 또는 과거 구독 이력이 있으면 Promotional Offer로 앱 내 즉시 적용한다.
- **FR-013**: 초대자가 한 번도 구독한 적 없으면 Offer Code(`referral_reward_01`)로 App Store 리딤 시트를 통해 적용한다.
- **FR-014**: 초대자 보상에 인위적 월간 상한을 두지 않는다. 초대 수에 비례하여 무제한 보상.
- **FR-015**: 보상 대기 기록은 생성 후 30일이 지나면 만료 처리한다.

**보상 구조**

- **FR-016**: 모든 보상은 14일(2주) 프리미엄 무료로 통일한다 (초대자/피초대자 모두).
- **FR-017**: 기본 보상 상품은 pro_monthly (월간)로 한다. yearly 구독자만 pro_yearly Offer를 받는다.
- **FR-018**: Free Trial + Offer Code 중복 적용을 지원해야 한다 (ASC에서 Introductory Offer 적용 여부 = Yes 설정).

**랜딩 페이지 및 인앱 브라우저**

- **FR-019**: 랜딩 페이지는 초대 코드 유효성을 검증하고, 유효하면 분석 이벤트를 기록한 후 App Store 앱 페이지로 리다이렉트해야 한다. 무효하면 초대 보상 없이 App Store 앱 페이지로 리다이렉트한다.
- **FR-020**: 인앱 브라우저별로 외부 브라우저 전환을 처리해야 한다: 카카오톡 (자동 전환 스킴), LINE (외부 브라우저 파라미터), Instagram/Facebook/X/네이버 (App Store 페이지 리다이렉트 시도).
- **FR-021**: 랜딩 페이지에 OG 메타태그를 설정해야 한다. 구체 값: `og:title` = "SweepPic - 14일 프리미엄 무료 받기", `og:description` = "친구가 14일 프리미엄을 선물했어요!", `og:image` = 사전 제작한 OG 이미지 URL (1200×630px, "14일 프리미엄 무료" 문구 포함), `og:type` = "website".

**링크 재탭 자동 처리**

- **FR-022**: 앱 설치 후 초대 링크를 다시 탭하면, Universal Link 또는 Custom URL Scheme을 통해 앱이 열리고 코드가 자동 추출되어야 한다.
- **FR-023**: Universal Link 설정을 위해 커스텀 도메인에 apple-app-site-association 파일을 배포해야 한다.
- **FR-024**: Custom URL Scheme(`sweeppic://referral/{code}`)을 등록해야 한다.

**Push 알림**

- **FR-025**: 공유 완료 후 Push 프리프롬프트를 **1회만** 표시해야 한다. 표시 여부는 로컬(UserDefaults)에 기록하여, 한 번 표시했으면 결과에 관계없이 다시 표시하지 않는다. Push 상태별 동작: `.notDetermined` → [알림 받기] 시 시스템 권한 팝업, `.denied` → [알림 받기] 시 알림 꺼짐 안내 + [설정으로 이동] / [나중에], `.authorized` → 프리프롬프트 미표시. 프리프롬프트에는 [알림 받기]와 [닫기] 버튼이 있다.
- **FR-026**: Push 허용 시 device token을 서버에 저장하고, 앱이 포그라운드에 진입할 때마다(sceneWillEnterForeground) 토큰을 갱신해야 한다. APNs가 토큰 무효(410 Gone)를 반환하면 서버에서 해당 device_token을 NULL로 설정한다.
- **FR-027**: 피초대자 리딤 완료 시 초대자에게 Push 알림을 발송해야 한다. device token이 없으면 발송하지 않는다.
- **FR-028**: Push 탭 시 앱이 보상 수령 화면으로 직행해야 한다. 앱이 포그라운드에서 Push를 수신하면 인앱 배너(UNNotificationPresentationOptions: banner, sound)로 표시하고, 배너 탭 시 보상 화면으로 이동한다. Push 수신 시 앱 배지를 1로 설정하고, 보상 팝업을 표시하는 시점에 배지를 0으로 초기화한다.

**사용자 식별**

- **FR-029**: 초대 전용 영구 User ID를 Keychain에 저장해야 한다 (`sweeppic_referral_id`). 앱 삭제 후 재설치에도 유지.
- **FR-030**: 리딤 완료 판단은 서버 상태(referrals.status)로 수행해야 한다. 클라이언트 currentEntitlements는 구독 만료 시 사라지므로 사용하지 않는다.

**Offer Code 재고 관리**

- **FR-031**: Offer Name별 사용 가능한 코드 수를 매일 확인하고, 임계값(5,000개) 미만 시 자동으로 새 코드를 생성해야 한다.
- **FR-032**: 만료된 코드는 매일 정리하여 "expired" 상태로 변경해야 한다.
- **FR-033**: 코드 할당은 원자적(atomic)으로 수행해야 한다 (SELECT FOR UPDATE, 동시 요청 시 중복 할당 방지). 락 대기 타임아웃은 5초로 설정하고, 타임아웃 시 "잠시 후 다시 시도해주세요" 에러를 반환한다.
- **FR-034**: Offer Code 풀 보충이 3회 재시도 후에도 최종 실패하면, 관리자에게 이메일 또는 Slack 알림을 발송해야 한다. 알림에는 실패한 Offer Name과 현재 잔여 코드 수를 포함한다.

**데이터 정합성 및 장애 복구**

- **FR-035**: report-redemption API 호출 실패 시, 클라이언트는 지수 백오프(2초→4초→8초)로 최대 3회 재시도해야 한다. 최종 실패 시에도 다음 앱 실행 시 Transaction.updates에서 미보고 초대 리딤(offerName이 referral_invited_*)을 재감지하여 서버에 재보고해야 한다.
- **FR-036**: 모든 서버 의존 화면(코드 입력, 보상 수령, 초대 링크 생성)에서 서버 비가용 시 "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요." 에러 안내와 재시도 버튼을 표시해야 한다.

**API 보안**

- **FR-037**: API 엔드포인트에 IP 및 user_id 기반 속도 제한(rate limiting)을 적용해야 한다: match-code 분당 10회, create-link 분당 5회, claim-reward 분당 5회. 초과 시 429 응답과 재시도 가능 시점 안내.

**UI 상태 관리**

- **FR-038**: 모든 서버 호출 화면(초대 링크 생성, 코드 입력 매칭, 보상 수령)에서 3가지 상태를 표시해야 한다: (1) 로딩 — 액션 버튼이 스피너로 전환, 중복 탭 차단, (2) 성공 — 결과 표시, (3) 에러 — 에러 메시지 + [다시 시도] 버튼.
- **FR-039**: 네트워크 오프라인 상태에서 서버 의존 화면에 진입하면 "인터넷 연결을 확인해주세요." 안내를 표시하고, 네트워크 복구 시 자동으로 재시도해야 한다. (기존 TrashGatePopup의 NWPathMonitor 패턴 재사용)
- **FR-040**: 보상 수령 화면 UI — 블러 배경 위에 카드 형태 (모달). 제목: "초대 보상 도착!", 본문: "초대한 사람이 SweepPic에 가입했어요!\n14일 무료 혜택을 받으세요", 버튼: [보상 받기] (흰색 배경), 닫기: 우상단 X 버튼 또는 카드 바깥 탭. 빈 상태: "수령 가능한 보상이 없습니다" + [친구 초대하기]. 콜드 스타트 팝업과 메뉴 진입 모두 동일 화면(모달). 기존 CelebrationViewController의 BlurPopupCardView 패턴 재사용.
- **FR-041**: 설정 > 프리미엄 메뉴 내에 3개 항목으로 노출: (1) "친구 초대" → 초대 설명 화면 (초대하기 플로우), (2) "초대 코드 입력" → 코드 입력 화면 (피초대자 플로우), (3) "초대 혜택 받기" → 보상 수령 화면 (초대자 보상 수령). "초대 혜택 받기" 진입 시 pending_rewards를 조회하여 보상이 있으면 수령 UI, 없으면 "수령 가능한 보상이 없습니다" 표시. 3개 항목 모두 항상 표시.
- **FR-042**: API 응답의 HTTP 상태 코드 처리 — 200(success:true): 성공, 200(success:false): 비즈니스 에러(메시지 표시), 429: 속도 제한(재시도 대기 안내), 500/502/503: 서버 에러(FR-036의 에러 안내 표시), 네트워크 타임아웃(30초): 에러 안내 표시.
- **FR-043**: 보상 만료(30일) 전에 사용자에게 별도 알림하지 않는다. 보상 만료 시 무고지(silent) 처리하고, 만료된 보상은 get-pending-rewards 응답에 포함하지 않는다.

**분석 이벤트**

- **FR-044**: 다음 퍼널 이벤트를 기록해야 한다. 각 이벤트는 명시된 속성을 포함한다:

| 이벤트 | 속성 |
|--------|------|
| `referral.link_created` | user_id |
| `referral.link_shared` | user_id, share_target (kakao/instagram/message/other) |
| `referral.landing_visited` | referral_code, user_agent, referrer_url |
| `referral.code_entered` | user_id, referral_code, input_method (manual/paste) |
| `referral.auto_matched` | user_id, referral_code, entry_method (universal_link/custom_scheme) |
| `referral.code_assigned` | user_id, referral_code, offer_name, subscription_status |
| `referral.code_redeemed` | user_id, referral_id, offer_name |
| `referral.reward_shown` | user_id, reward_id, entry_method (push/in_app) |
| `referral.reward_claimed` | user_id, reward_id, reward_type (promotional/offer_code), offer_name |

**P8 키 관리**

- **FR-045**: ASC API 및 Promotional Offer 서명에 사용하는 In-App Purchase P8 키는 Supabase Vault에 저장한다. Apple P8 키는 만료되지 않으므로 정기 로테이션은 불필요하지만, 키 유출 의심 시 즉시 교체할 수 있도록 환경 변수로 관리한다.
- **FR-046**: APNs Push용 P8 키도 동일하게 Supabase Vault에 저장하고 환경 변수로 관리한다.

**개발 환경**

- **FR-047**: 커스텀 도메인 미구매 상태에서도 개발/테스트가 가능해야 한다. Supabase 기본 도메인(`{project-ref}.supabase.co/functions/v1/referral-landing/r/{code}`)을 폴백 URL로 사용하고, 환경 변수(`CUSTOM_DOMAIN`)로 전환한다. Universal Link는 도메인 구매 후에만 테스트 가능하며, 개발 중에는 Custom URL Scheme으로 대체한다.

**성능**

- **FR-048**: 초기 규모에서 별도 성능 최적화는 불필요하다. 병목 발생 시 DB 커넥션 풀 확장으로 대응한다.

### Key Entities

- **초대 링크 (Referral Link)**: 초대자 식별자와 고유 초대 코드의 1:1 매핑. Push 알림용 device token 포함. 사용자당 하나만 존재.
- **초대 기록 (Referral)**: 초대자-피초대자 관계. 상태 흐름: matched(코드 입력) → redeemed(리딤 완료) → rewarded(보상 수령 완료). 할당된 Offer Code 참조.
- **보상 대기 (Pending Reward)**: 초대자가 수령해야 할 보상. 보상 유형(Promotional/Offer Code)과 코드는 수령 시점에 결정. 30일 만료. 상태: pending → completed/expired.
- **Offer Code 풀**: Apple이 생성한 일회용 코드 재고. Offer Name별 구분 (피초대자용 monthly/yearly, 초대자 비구독자용). 상태: available → assigned → used → expired.

### Assumptions

- 기존 구독 인프라(StoreKit 2, SubscriptionStore)가 구현되어 있다 (003-bm-monetization).
- Supabase 백엔드가 이미 구성되어 있다.
- Apple Developer Program 멤버십이 활성 상태이다 (P8 키 생성 가능).
- 커스텀 도메인은 구현 전에 별도 구매한다 (sweeppic.link, swp.link, sweeppic.app 후보).
- OG 태그용 디자인 에셋은 구현 전에 사전 제작한다.
- 설정 > 프리미엄 메뉴가 이미 존재한다.
- 앱의 최소 지원 iOS 버전은 16+이다.

### Dependencies

- **003-bm-monetization**: 구독 상품(pro_monthly, pro_yearly), StoreKit 2 인프라, Transaction.updates 리스너
- **커스텀 도메인 구매**: 랜딩 페이지 및 Universal Link에 필요
- **App Store Connect 설정**: 5개 Offer 생성, P8 키 발급
- **APNs Authentication Key**: Push 알림 발송에 필요 (ASC API 키와 별도)

### Out of Scope

- 온보딩 플로우 재설계 (온보딩 배너는 별도 온보딩 설계에서 결합)
- A/B 테스트 인프라 (2주 vs 1개월 보상 기간 실험)
- App Store Server Notifications V2 (`OFFER_REDEEMED`) 연동 (향후 보조 수단으로 추가)
- 월간→연간 업셀 프롬프트 (초대 프로그램 외 별도 기능)
- 초대 현황 대시보드 (초대자가 자신의 초대 현황을 조회하는 UI)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 사용자가 초대 링크 생성부터 공유 완료까지 30초 이내에 완료할 수 있다.
- **SC-002**: 피초대자가 초대 코드 입력부터 14일 프리미엄 활성화까지 2분 이내에 완료할 수 있다.
- **SC-003**: 초대 링크 공유 → 피초대자 앱 설치 → 혜택 적용 전환율이 10% 이상이다 (업계 평균 5.3%). 측정: `referral.code_redeemed 수 / referral.link_shared 수 × 100`.
- **SC-004**: 초대자의 보상 수령률이 80% 이상이다. 측정: `referral.reward_claimed 수 / (pending_rewards 중 status=completed + status=expired) × 100`. 분모는 30일 만료 포함.
- **SC-005**: 일일 활성 사용자 중 초대 프로그램 노출 대상자의 5% 이상이 초대 링크를 생성한다. "노출 대상자" 정의: 게이트 팝업 또는 한도 바 팝업을 본 무료 사용자 + 축하 화면을 본 유료 사용자. 측정: `referral.link_created DAU / (gate_shown + celebration_shown) DAU × 100`.
- **SC-006**: Offer Code 풀이 소진되어 혜택 적용이 실패하는 비율이 0.1% 미만이다. 측정: `match-code의 no_codes_available 응답 수 / match-code 총 요청 수 × 100`.
- **SC-007**: 어뷰징(자기 초대, 허위 계정 등)으로 인한 비정상 초대 비율이 전체 초대의 2% 미만이다. 측정: `match-code의 self_referral 응답 수 / match-code 총 요청 수 × 100`.
- **SC-008**: Push 알림을 통한 보상 수령이 인앱 팝업 대비 3배 이상 빠르다. 측정: Push 경로 = `reward_shown(entry_method=push)의 timestamp - pending_rewards.created_at` 중앙값. 인앱 경로 = `reward_shown(entry_method=in_app)의 timestamp - pending_rewards.created_at` 중앙값.
