**주요 이슈(심각도 순)**
- `High` `beginBackgroundTask` 종료 보장이 완전하지 않습니다. 계획은 `onFlushComplete`에 의존하는데(`docs/db/260217db-hybrid.md:254`), 현재 코드상 `handleSessionEnd()`는 `shouldSkip`면 즉시 반환합니다(`SweepPic/SweepPic/Shared/Analytics/AnalyticsService+Session.swift:96`). 이 경로에서 `onFlushComplete`가 호출되지 않아 백그라운드 태스크가 만료 핸들러에만 의존하게 됩니다. `handleSessionEnd(completion:)` 형태로 바꿔 모든 경로에서 completion 1회 보장하는 게 안전합니다.
- `High` `endBackgroundTask` 중복/경합 가능성이 있습니다. 만료 핸들러와 플러시 완료 콜백이 모두 `endBackgroundTask`를 직접 호출합니다(`docs/db/260217db-hybrid.md:248`, `docs/db/260217db-hybrid.md:255`). Apple 가이드(Quinn 노트) 기준으로 begin/end는 정확한 1:1 북키핑이 중요하므로, `if bgTaskID != .invalid` 가드 + 메인 스레드 단일 종료 함수로 합치는 게 맞습니다.
- `Medium` 키 전략이 `anon JWT`에 고정되어 있습니다(`docs/db/260217db-hybrid.md:295`, `docs/db/260217db-hybrid.md:528`). 최신 Supabase는 publishable/secret 키를 권장하며, publishable 키를 `Authorization: Bearer`에 넣으면 JWT가 아니라 거절될 수 있습니다. “반드시 legacy anon key 사용”을 명시하거나, 키 타입별 헤더 전략을 분리해야 합니다.
- `Medium` PostgREST 헤더 설명이 문서 내 상충됩니다. 본문 헤더에는 `Prefer: return=minimal`만 있고(`docs/db/260217db-hybrid.md:198`), 하단 기록에는 `missing=default`를 추가했다고 되어 있습니다(`docs/db/260217db-hybrid.md:639`). 현재 설계(모든 객체 동일 키)면 동작 가능하지만, 문서 일관성 차원에서 하나로 정리해야 합니다.
- `Medium` RLS가 `event_name` 화이트리스트만 검사합니다(`docs/db/260217db-hybrid.md:63`). anon 키 특성상 외부 임의 삽입(데이터 오염/비용 증가) 여지는 남습니다. `params` 크기 제한/허용 키 제한 같은 CHECK를 추가하는 게 좋습니다.
- `Low` 응답코드 기대치가 다소 좁습니다(`docs/db/260217db-hybrid.md:217`). 실제 운영에서는 401/403/409 등도 나올 수 있으니 “2xx 성공, 그 외 실패 로깅”으로 표현하는 편이 정확합니다.

**요약 판단**
- 목표 달성 가능성은 높습니다. 특히 `SceneDelegate → handleSessionEnd → flushCounters → sendEventBatch → SupabaseProvider.sendBatch` 흐름 설계 방향은 맞습니다(`SweepPic/SweepPic/App/SceneDelegate.swift:290`, `SweepPic/SweepPic/Shared/Analytics/AnalyticsService+Session.swift:95`).
- 다만 위 `High` 2건(종료 보장/중복 종료)은 구현 전 문서에서 반드시 수정해야 실제 백그라운드 안정성이 확보됩니다.

**검증에 사용한 주요 자료**
- PostgREST Bulk Insert/Prefer:  
  https://docs.postgrest.org/en/v12/references/api/tables_views.html#bulk-insert  
  https://docs.postgrest.org/en/v12/references/api/preferences.html
- Supabase REST 헤더/키 정책/크론:  
  https://supabase.com/docs/guides/api/quickstart  
  https://supabase.com/docs/guides/api/api-keys  
  https://supabase.com/docs/guides/cron/quickstart
- iOS 백그라운드 태스크 운영 주의(Apple DTS):  
  https://developer.apple.com/forums/thread/85066
- xcconfig 문법(`//` 주석, `$(VAR)` 치환):  
  https://help.apple.com/xcode/mac/current/en.lproj/dev745c5c974.html