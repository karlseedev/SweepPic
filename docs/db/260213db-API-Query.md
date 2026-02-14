# TelemetryDeck Query API — 쿼리 메모

> 쿼리 작성 시 헤매지 않기 위한 실측 기반 메모. 발견되는 대로 추가.

## 필수 설정

| 항목 | 값 | 비고 |
|------|-----|------|
| dataSource | `"com.simon"` | 조직 namespace. `"telemetry-signals"` 사용하면 0건 반환 |
| appID 필터 | `"B42FE72D-8A4F-4EA8-90C5-6E2EFA0E7ECC"` | .env의 TELEMETRYDECK_APP_ID |
| aggregation type (건수) | `"eventCount"` | 원본 이벤트 수 (rollup 전). TelemetryDeck 커스텀 |
| aggregation type (행수) | `"count"` | Druid 물리적 행 수 (rollup 후). 일반적으로 불필요 |

## isTestMode 분리

TelemetryDeck SDK가 **빌드 환경에 따라 자동 설정**:
- Xcode 디버그 빌드 / 시뮬레이터 → `isTestMode = "true"`
- 릴리스(앱스토어) 빌드 → `isTestMode = "false"`

```bash
./td-report.sh --test-mode   # 디버그 데이터 조회
./td-report.sh               # 릴리스 데이터만 (기본)
```

## 시그널 이름 규칙

코드에서 `TelemetryDeck.signal("app.launched")` → 저장 시 **`PickPhoto.app.launched`** (앱 이름 접두사 자동 추가)

쿼리 필터에는 접두사 포함된 전체 이름 사용:
```json
{ "type": "selector", "dimension": "type", "value": "PickPhoto.app.launched" }
```

## 전체 시그널 목록 조회 (groupBy)

```json
{
  "queryType": "groupBy",
  "dataSource": "com.simon",
  "granularity": "all",
  "dimensions": [{"type": "default", "dimension": "type", "outputName": "signalType"}],
  "aggregations": [{"type": "count", "name": "count"}]
}
```

2026-02-14 기준 확인된 시그널 (24건):

| signalType | count | 출처 |
|---|---|---|
| PickPhoto.app.launched | 5 | 이벤트 1 |
| PickPhoto.session.photoViewing | 1 | 이벤트 3 |
| PickPhoto.session.deleteRestore | 1 | 이벤트 4-1 |
| PickPhoto.session.trashViewer | 1 | 이벤트 4-2 |
| PickPhoto.session.similarAnalysis | 1 | 이벤트 5-1 |
| PickPhoto.similar.groupClosed | 1 | 이벤트 5-2 |
| PickPhoto.cleanup.completed | 4 | 이벤트 7 |
| TelemetryDeck.Session.started | 7 | SDK 자동 |
| TelemetryDeck.Acquisition.newInstallDetected | 2 | SDK 자동 |
| TelemetryDeck.AuditLog.httpRequest | 1 | SDK 자동 |

## 기본 쿼리 템플릿

```json
{
  "queryType": "timeseries",
  "dataSource": "com.simon",
  "granularity": "day",
  "relativeIntervals": [{
    "beginningDate": { "component": "day", "offset": -7, "position": "beginning" },
    "endDate":       { "component": "day", "offset": 0, "position": "end" }
  }],
  "filter": {
    "type": "and",
    "fields": [
      { "type": "selector", "dimension": "type", "value": "PickPhoto.시그널이름" },
      { "type": "selector", "dimension": "appID", "value": "APP_ID" },
      { "type": "selector", "dimension": "isTestMode", "value": "false" }
    ]
  },
  "aggregations": [{ "type": "count", "name": "total" }]
}
```

## 시간별 조회 (granularity + intervals)

`granularity: "hour"`로 시간 단위 데이터 확인 가능. 데이터 도착 여부 디버깅에 유용.

td-query.sh는 `--start/--end/--granularity` 플래그 미지원. **stdin으로 직접 쿼리** 전달:

```bash
cat <<'QUERY' | bash td-query.sh --test-mode
{
  "queryType": "timeseries",
  "dataSource": "com.simon",
  "granularity": "hour",
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "PickPhoto.session.deleteRestore"
  },
  "intervals": ["2026-02-14T00:00:00Z/2026-02-14T04:00:00Z"],
  "aggregations": [
    { "type": "count", "name": "sessions" },
    { "type": "longSum", "name": "viewerTrashButton", "fieldName": "viewerTrashButton" }
  ]
}
QUERY
```

- `intervals`: ISO 8601 형식 `"시작/끝"`. relativeIntervals 대신 사용
- `granularity`: `"all"`, `"day"`, `"hour"` 지원

## 타임스탬프 시간대

서버 응답 타임스탬프는 **UTC+0**. KST 변환 시 +9시간.

| KST | UTC |
|-----|-----|
| 10:00 | 01:00 |
| 22:00 | 13:00 |

세션 시그널 타임스탬프 = **백그라운드 진입(flush) 시점**. 개별 액션 시점이 아님.
예: 20:50에 삭제 → 21:05에 백그라운드 → 서버 기록은 21:00 UTC 버킷(=06:00 KST 버킷이 아닌 12:00 UTC 버킷)

## longSum aggregation

TelemetryDeck SDK는 파라미터를 **문자열**로 전송하지만, `longSum` aggregation이 숫자 파싱/합산 정상 작동:

```json
{ "type": "longSum", "name": "viewerTrashButton", "fieldName": "viewerTrashButton" }
```

- 세션 카운터(gridSwipeDelete, viewerTrashButton 등) 합산에 사용
- `count`는 시그널 건수(세션 수), `longSum`은 파라미터 값 합산 — 용도 구분 필수

## 동기 vs 비동기 엔드포인트

| 방식 | 엔드포인트 | 용도 |
|------|-----------|------|
| 동기 | `POST /api/v3/query/calculate/` | 빠른 테스트, 단건 조회 |
| 비동기 | `POST /api/v3/query/calculate-async/` → poll → value | td-query.sh 사용. 대량/복잡 쿼리 |

## 삽질 기록

- `"dataSource": "telemetry-signals"` → 모든 쿼리 0건. namespace 모드 조직은 `"com.simon"` 필수
- `eventCount` vs `count` 혼동 주의: `eventCount`=원본 이벤트 수(rollup 전), `count`=Druid 행 수(rollup 후). 세션 시그널 건수에는 `eventCount` 사용. 동일 구간에서 eventCount=16, count=12 차이 확인됨 (4건이 rollup으로 합쳐짐)
- isTestMode 필터 빠뜨리면 디버그+릴리스 합산됨 (의도적이면 OK)
- dimension을 문자열로 넣으면 에러 → `{"type": "default", "dimension": "...", "outputName": "..."}` 객체 형태 필요
- 수집 지연: 초기 테스트 시 2~6시간 지연 관찰. 이후 정상화됨 (수분 내 도착). 데이터 미도착 시 시간별 조회로 확인
