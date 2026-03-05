# Supabase 메인 DB 승격 — 검증 결과

> **실행일:** 2026-03-03
> **구현 문서:** 260303supabase-impl.md
> **커밋:** `b735ba9` (feat: Supabase 메인 DB 승격)
> **기기:** iPhone 13 Pro (iPhone14,2)

---

## 1. DB 변경 — PASS

Supabase Dashboard SQL Editor에서 수동 실행.

**is_test 컬럼 추가:**
```sql
ALTER TABLE events ADD COLUMN is_test BOOLEAN NOT NULL DEFAULT true;
```
- 기존 272행 전부 `is_test = true` 확인
- NULL 없음 (NOT NULL 제약 정상)

**RLS 정책 업데이트 (9종 → 11종):**
```sql
DROP POLICY IF EXISTS "anon_insert" ON events;
CREATE POLICY "anon_insert" ON events FOR INSERT TO anon
    WITH CHECK (event_name IN (11종));
```
- `pg_policies` 조회로 11종 화이트리스트 확인

---

## 2. 빌드 — PASS

```
xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17' build
** BUILD SUCCEEDED **
```

---

## 3. 실기기 테스트 (40/40) — PASS

`run-test-inject-device.sh` 실행 결과:

```
[즉시 전송 이벤트]
  [PASS] app.launched                        존재
  [PASS] similar.groupClosed.totalCount      = 12
  [PASS] similar.groupClosed.deletedCount    = 5
  [PASS] cleanup.completed.reachedStage      = cleanupDone
  [PASS] cleanup.completed.trashWarningShown = true
  [PASS] cleanup.completed.foundCount        = 23
  [PASS] cleanup.completed.durationSec       = 45.3
  [PASS] cleanup.completed.method            = fromLatest
  [PASS] cleanup.completed.result            = completed
  [PASS] cleanup.previewCompleted.reachedStage = finalAction
  [PASS] cleanup.previewCompleted.foundCount = 15
  [PASS] cleanup.previewCompleted.durationSec = 28.7
  [PASS] cleanup.previewCompleted.maxStageReached = standard
  [PASS] cleanup.previewCompleted.expandCount = 4
  [PASS] cleanup.previewCompleted.excludeCount = 2
  [PASS] cleanup.previewCompleted.viewerOpenCount = 3
  [PASS] cleanup.previewCompleted.finalAction = moveToTrash
  [PASS] cleanup.previewCompleted.movedCount = 11

[세션 카운터]
  [PASS] session.photoViewing.total          = 17
  [PASS] session.photoViewing.fromLibrary    = 10
  [PASS] session.photoViewing.fromAlbum      = 5
  [PASS] session.photoViewing.fromTrash      = 2
  [PASS] session.deleteRestore.gridSwipeDelete = 9
  [PASS] session.deleteRestore.gridSwipeRestore = 3
  [PASS] session.deleteRestore.viewerSwipeDelete = 7
  [PASS] session.deleteRestore.viewerTrashButton = 4
  [PASS] session.deleteRestore.viewerRestoreButton = 2
  [PASS] session.deleteRestore.fromLibrary   = 14
  [PASS] session.deleteRestore.fromAlbum     = 11
  [PASS] session.trashViewer.permanentDelete = 6
  [PASS] session.trashViewer.restore         = 8
  [PASS] session.similarAnalysis.completedCount = 3
  [PASS] session.similarAnalysis.cancelledCount = 1
  [PASS] session.similarAnalysis.totalGroups = 11
  [PASS] session.similarAnalysis.avgDurationSec = 4.7
  [PASS] session.errors.photoLoad.gridThumbnail = 5
  [PASS] session.errors.face.detection       = 2
  [PASS] session.errors.cleanup.trashMove    = 1

[추가 이벤트 확인 (전 이벤트 수집)]
  [PASS] permission.result                   존재
  [PASS] session.gridPerformance.grayShown   = 42

  결과: 40 통과 / 0 실패 (총 40 항목)
```

---

## 4. Supabase 데이터 확인 — PASS

**permission.result:**
```json
{
    "event_name": "permission.result",
    "is_test": true,
    "created_at": "2026-03-03T05:39:37.564599+00:00"
}
```

**session.gridPerformance:**
```json
{
    "event_name": "session.gridPerformance",
    "is_test": true,
    "created_at": "2026-03-03T05:39:38.643897+00:00"
}
```

- 두 이벤트 모두 Supabase에 존재 확인
- `is_test = true` 확인 (Debug 빌드)

---

## 5. 오프라인 큐 — PASS

**테스트 절차:**
1. 앱 실행 상태에서 비행기 모드 ON
2. 홈으로 나가기 (백그라운드) → 세션 flush 시도 → 네트워크 실패 → 큐 저장
3. 비행기 모드 OFF
4. 앱 다시 열기 (포그라운드) → `flushPendingQueue()` → 큐 재전송

**결과:** 비행기 모드 중 실패한 `session.similarAnalysis`가 네트워크 복구 후 정상 전송됨.

```json
{
    "event_name": "session.similarAnalysis",
    "params": {
        "totalGroups": "1",
        "avgDurationSec": "1.4",
        "cancelledCount": "0",
        "completedCount": "1"
    },
    "is_test": true,
    "created_at": "2026-03-03T13:13:35.372777+00:00"
}
```

- 테스트 주입 데이터(completedCount=3)가 아닌 **실제 앱 사용 데이터**(completedCount=1)
- 비행기 모드 중 실패 → 큐 저장 → 네트워크 복구 후 재전송 성공 확인

---

## 요약

| # | 항목 | 결과 |
|---|------|:----:|
| 1 | DB 변경 (is_test 컬럼 + RLS 11종) | PASS |
| 2 | Xcode 빌드 | PASS |
| 3 | 실기기 테스트 주입 (40/40) | PASS |
| 4 | Supabase is_test=true 확인 | PASS |
| 5 | 오프라인 큐 (비행기 모드 → 복구 → 재전송) | PASS |

**전체 결과: 5/5 PASS**
