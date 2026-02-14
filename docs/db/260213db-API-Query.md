# TelemetryDeck Query API — 쿼리 메모

> 쿼리 작성 시 헤매지 않기 위한 실측 기반 메모. 발견되는 대로 추가.

## 필수 설정

| 항목 | 값 | 비고 |
|------|-----|------|
| dataSource | `"com.simon"` | 조직 namespace. `"telemetry-signals"` 사용하면 0건 반환 |
| appID 필터 | `"B42FE72D-8A4F-4EA8-90C5-6E2EFA0E7ECC"` | .env의 TELEMETRYDECK_APP_ID |
| aggregation type | `"count"` | `"eventCount"`는 null 반환. 절대 쓰지 말 것 |

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

## 동기 vs 비동기 엔드포인트

| 방식 | 엔드포인트 | 용도 |
|------|-----------|------|
| 동기 | `POST /api/v3/query/calculate/` | 빠른 테스트, 단건 조회 |
| 비동기 | `POST /api/v3/query/calculate-async/` → poll → value | td-query.sh 사용. 대량/복잡 쿼리 |

## 삽질 기록

- `"dataSource": "telemetry-signals"` → 모든 쿼리 0건. namespace 모드 조직은 `"com.simon"` 필수
- `"type": "eventCount"` → null 반환. `"type": "count"`만 작동
- isTestMode 필터 빠뜨리면 디버그+릴리스 합산됨 (의도적이면 OK)
- dimension을 문자열로 넣으면 에러 → `{"type": "default", "dimension": "...", "outputName": "..."}` 객체 형태 필요
