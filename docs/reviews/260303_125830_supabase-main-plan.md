1차 결론: 이 계획은 방향은 맞지만, 현재 상태로는 목표 (3) “데이터 유실 방지”를 **충분히 보장하지 못합니다**. 특히 큐/재시도 설계에 치명적인 경합과 영구 실패 처리 누락이 있습니다.

**Findings (심각도 순)**

1. **[High] 큐 flush/clear 경합으로 이벤트 유실 가능**
   - 근거: `enqueueForRetry`와 `flushPendingQueue`가 같은 파일을 비동기 처리하고, flush 성공 시 전체 파일 삭제(`clearPendingQueue`)로 설계됨.
   - 문제: flush 중 새로 enqueue된 이벤트까지 같이 지워질 수 있음.
   - 위치: [refactored-popping-origami.md:102](/Users/karl/.claude/plans/refactored-popping-origami.md:102), [refactored-popping-origami.md:120](/Users/karl/.claude/plans/refactored-popping-origami.md:120), [refactored-popping-origami.md:124](/Users/karl/.claude/plans/refactored-popping-origami.md:124)

2. **[High] `Caches` 저장 + `maxPendingCount=200`는 목표(유실 방지)와 충돌**
   - 근거: 큐 파일을 `Caches/supabase_pending.json`에 저장하고 초과분은 버림.
   - 문제: `Caches`는 OS가 정리 가능, 200 초과시 의도적으로 드롭됨.
   - 위치: [refactored-popping-origami.md:94](/Users/karl/.claude/plans/refactored-popping-origami.md:94), [refactored-popping-origami.md:95](/Users/karl/.claude/plans/refactored-popping-origami.md:95), [refactored-popping-origami.md:106](/Users/karl/.claude/plans/refactored-popping-origami.md:106)

3. **[High] URLSession 실패 처리가 “모든 non-2xx 재큐잉”이라 영구 실패(4xx) 누적 위험**
   - 근거: 2xx 외에는 모두 `enqueueForRetry`.
   - 문제: RLS/스키마 오류(400/403)는 재시도로 해결되지 않는데 큐를 오염시키고, 새 이벤트까지 밀어냄.
   - 위치: [refactored-popping-origami.md:141](/Users/karl/.claude/plans/refactored-popping-origami.md:141), [refactored-popping-origami.md:146](/Users/karl/.claude/plans/refactored-popping-origami.md:146), [refactored-popping-origami.md:162](/Users/karl/.claude/plans/refactored-popping-origami.md:162), [refactored-popping-origami.md:167](/Users/karl/.claude/plans/refactored-popping-origami.md:167)

4. **[Medium] 재시도 idempotency 부재로 중복 적재 가능**
   - 근거: 요청 타임아웃/응답 손실 시 서버는 이미 insert했을 수 있는데 클라이언트는 재큐잉.
   - 문제: 동일 이벤트 중복 삽입 가능, 분석 왜곡.
   - 위치: [refactored-popping-origami.md:102](/Users/karl/.claude/plans/refactored-popping-origami.md:102), [refactored-popping-origami.md:119](/Users/karl/.claude/plans/refactored-popping-origami.md:119), [refactored-popping-origami.md:132](/Users/karl/.claude/plans/refactored-popping-origami.md:132)

5. **[Medium] `is_test` 신뢰 모델이 약함 (클라이언트 값 신뢰)**
   - 근거: `#if DEBUG`로 body에 넣는 방식 + RLS에서 `is_test` 제약 없음.
   - 문제: anon key는 공개키라 클라이언트에서 임의 값 전송 가능, “디버그/프로덕션 구분” 신뢰도 낮음.
   - 위치: [refactored-popping-origami.md:43](/Users/karl/.claude/plans/refactored-popping-origami.md:43), [refactored-popping-origami.md:80](/Users/karl/.claude/plans/refactored-popping-origami.md:80)

6. **[Medium] PostgREST 호환성 누락: 구버전 클라이언트가 `is_test` 미전송 시 실패 가능**
   - 근거: `ALTER TABLE ... is_test BOOLEAN NOT NULL` 적용.
   - 문제: 롤링 업데이트 상황에서 미전송 컬럼 처리 정책 고려가 없음(`Prefer: missing=default` 등).
   - 위치: [refactored-popping-origami.md:57](/Users/karl/.claude/plans/refactored-popping-origami.md:57), [refactored-popping-origami.md:58](/Users/karl/.claude/plans/refactored-popping-origami.md:58)

7. **[Medium] “스레드 안전성 확인 완료” 판단은 과함**
   - 근거: 계획은 `endTask` 메인 디스패치만으로 충분하다고 결론.
   - 문제: 실제 코드에서 `onFlushComplete`는 메인/백그라운드에서 동시 접근 가능해 data race 여지.
   - 위치: [refactored-popping-origami.md:174](/Users/karl/.claude/plans/refactored-popping-origami.md:174), [AnalyticsService.swift:125](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Analytics/AnalyticsService.swift:125), [AnalyticsService.swift:268](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Shared/Analytics/AnalyticsService.swift:268), [SceneDelegate.swift:357](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/App/SceneDelegate.swift:357)

8. **[Low] SQL 실행 안정성/검증 범위 부족**
   - `DROP POLICY`에 `IF EXISTS` 없음(환경별 실패 가능): [refactored-popping-origami.md:61](/Users/karl/.claude/plans/refactored-popping-origami.md:61)
   - 검증에 `is_test=false`(릴리즈) 시나리오, 4xx 비재시도, 큐 파일 손상 복구 테스트가 없음: [refactored-popping-origami.md:255](/Users/karl/.claude/plans/refactored-popping-origami.md:255)

**권장 보완 (핵심만)**
1. 큐를 `Application Support`로 이동하고 파일 쓰기 `.atomic` 적용.
2. flush 성공 시 “전체 삭제” 대신 “전송한 구간만 제거”하는 원자적 dequeue 구현.
3. 재시도 대상을 `network/timeout/429/5xx`로 제한, `400/401/403/404`는 dead-letter 처리.
4. 이벤트에 `event_id(UUID)` 추가 + DB unique + PostgREST `on_conflict` 기반 idempotency.
5. `is_test`는 운영 분리를 더 강하게(최소한 별도 프로젝트/키, 또는 서버측 강제 규칙) 설계.
6. 롤링 배포 고려해 `missing=default` 전략 또는 단계적 마이그레이션 추가.

**참고한 공식 자료**
- Supabase API keys: https://supabase.com/docs/guides/api/api-keys  
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security  
- PostgREST tables/views (bulk insert, upsert, on_conflict): https://postgrest.org/en/v12/references/api/tables_views.html  
- PostgREST preferences (`return=minimal`, `missing=default`): https://postgrest.org/en/v12/references/api/preferences.html  
- PostgREST error mapping: https://postgrest.org/en/v12/references/errors.html  
- Apple File System Guide (`Library/Caches` 성격): https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html