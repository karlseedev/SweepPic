# Query API 분석 스크립트 구현 계획

> **작성일:** 2026-02-13
> **상태:** 작성 완료
> **기반 문서:** 260212db-Archi.md 섹션 7.2~7.9
> **목적:** Claude가 TelemetryDeck 데이터를 조회·분석할 수 있는 스크립트 구축

---

## 1. 목표

```
주인님: "지난 주 분석 데이터 요약해줘"
    ↓
Claude: td-report.sh 실행 (Bash)
    ↓
Claude: JSON 파싱 → 인사이트 추출 → 마크다운 리포트
```

Claude Code에서 Bash 한 줄로 데이터를 뽑고, 결과 JSON을 직접 분석하는 구조.

---

## 2. 파일 구조

```
scripts/analytics/
├── .env.example           # 환경변수 템플릿 (git 추적)
├── .env                   # 실제 credentials (git 제외)
├── td-auth.sh             # 토큰 발급 + 캐싱
├── td-query.sh            # 비동기 3단계 쿼리 실행 (범용)
├── td-report.sh           # 주간 리포트 (전체 시그널 일괄 조회)
└── queries/               # 시그널별 TQL 쿼리 템플릿
    ├── app-launched.json
    ├── permission.json
    ├── photo-viewing.json
    ├── delete-restore.json
    ├── trash-viewer.json
    ├── similar-analysis.json
    ├── similar-group.json
    ├── errors.json
    ├── cleanup.json
    └── preview-cleanup.json
```

`.gitignore` 추가:
```
scripts/analytics/.env
/tmp/td-token.json
```

---

## 3. Credential 관리

### 3.1 .env 파일

```bash
# scripts/analytics/.env
TELEMETRYDECK_EMAIL=user@example.com
TELEMETRYDECK_PASSWORD=****
TELEMETRYDECK_APP_ID=<App ID>
```

### 3.2 .env.example (git 추적)

```bash
# scripts/analytics/.env.example
# TelemetryDeck API credentials
# 이 파일을 .env로 복사한 후 실제 값을 입력하세요
TELEMETRYDECK_EMAIL=
TELEMETRYDECK_PASSWORD=
TELEMETRYDECK_APP_ID=
```

### 3.3 보안 규칙

- `.env`는 **절대 git에 커밋하지 않음**
- Bearer Token은 `/tmp/td-token.json`에 캐싱 (만료 시간 기반 자동 갱신)
- 스크립트 내부에 credential 하드코딩 금지

---

## 4. 스크립트별 설계

### 4.1 td-auth.sh — 토큰 발급 + 캐싱

**용도:** 유효한 Bearer Token을 stdout으로 출력. 다른 스크립트에서 `$(./td-auth.sh)`로 호출.

**동작:**
```
1. /tmp/td-token.json 확인
   ├─ 존재 + 만료 전 → 캐시된 토큰 출력
   └─ 없음 or 만료 → 2로
2. .env에서 credentials 로드
3. POST /api/v3/users/login (Basic Auth)
4. 응답 → /tmp/td-token.json에 캐싱
5. 토큰 값(value) stdout 출력
```

**만료 판정:** `expiresAt`를 파싱하여 현재 시간과 비교. 10분 여유를 둠.

**의존성:** `curl`, `jq`, `date`

**예상 크기:** ~40줄

### 4.2 td-query.sh — 비동기 3단계 쿼리 실행

**용도:** TQL JSON을 받아 결과 JSON을 stdout으로 출력.

**사용법:**
```bash
# 파일에서 쿼리 읽기
./td-query.sh queries/app-launched.json

# stdin으로 쿼리 전달
echo '{"queryType":"timeseries",...}' | ./td-query.sh

# 기간 오버라이드 (기본 7일)
./td-query.sh queries/app-launched.json --days 30
```

**동작:**
```
1. td-auth.sh로 토큰 획득
2. 쿼리 JSON 읽기 (파일 or stdin)
3. --days 옵션 → relativeIntervals 자동 주입/교체
4. --test-mode 옵션 → isTestMode 필터 추가 (기본: false)
5. appID 필터 + isTestMode 필터 자동 주입 (필터 래핑)
6. POST /api/v3/query/calculate-async/ → taskID 획득
7. 폴링: GET /api/v3/task/{taskID}/status/ (2초 간격, 최대 30초)
8. GET /api/v3/task/{taskID}/value/ → 결과 JSON stdout 출력
```

**필터 자동 주입 로직 (jq):**

쿼리 템플릿의 기존 filter를 `and` 필터로 감싸서 appID + isTestMode 조건을 추가:

```bash
# 기존 filter를 $original_filter로 추출 후:
jq --arg appID "$APP_ID" --arg testMode "$TEST_MODE" \
  '.filter = {
    "type": "and",
    "fields": [
      .filter,
      { "type": "selector", "dimension": "appID", "value": $appID },
      { "type": "selector", "dimension": "isTestMode", "value": $testMode }
    ]
  }' <<< "$query_json"
```

**에러 처리:**
- 토큰 발급 실패 → stderr에 메시지, exit 1
- 쿼리 제출 실패 → stderr에 HTTP 응답, exit 2
- 폴링 타임아웃 → stderr에 "timeout", exit 3
- 쿼리 실패 → stderr에 에러 메시지, exit 4

**예상 크기:** ~90줄

### 4.3 queries/ — 시그널별 TQL 쿼리 템플릿

각 JSON 파일은 `relativeIntervals`와 `appID 필터`를 **포함하지 않음** — `td-query.sh`가 자동 주입.

#### 10개 쿼리 목록

| 파일 | queryType | 시그널 | aggregation 전략 | 핵심 데이터 |
|------|-----------|--------|-----------------|-----------|
| `app-launched.json` | timeseries | `app.launched` | eventCount | 일별 실행 수 |
| `permission.json` | groupBy | `permission.result` | eventCount | result×timing별 건수 |
| `photo-viewing.json` | timeseries | `session.photoViewing` | eventCount + longSum | 세션 수 + 총 열람 수 |
| `delete-restore.json` | timeseries | `session.deleteRestore` | eventCount + longSum | 세션 수 + 삭제/복구 합산 |
| `trash-viewer.json` | timeseries | `session.trashViewer` | eventCount + longSum | 세션 수 + 완전삭제/복구 합산 |
| `similar-analysis.json` | timeseries | `session.similarAnalysis` | eventCount + longSum | 세션 수 + 완료/취소/그룹 합산 |
| `similar-group.json` | groupBy | `similar.groupClosed` | eventCount | deletedCount 분포 |
| `errors.json` | timeseries | `session.errors` | eventCount + longSum×13 | 에러 항목별 발생 합산 |
| `cleanup.json` | groupBy | `cleanup.completed` | eventCount | reachedStage별 퍼널 |
| `preview-cleanup.json` | groupBy | `cleanup.previewCompleted` | eventCount | finalAction별 분포 |

> **aggregation 타입 주의:**
> - `eventCount`: TelemetryDeck 시그널 건수 카운팅 (~~`count`~~ 는 Druid 내부 row 수이므로 사용 금지)
> - `longSum`: 파라미터 값(문자열 숫자)을 세션 간 합산 — Druid가 자동 형변환 수행 (구현 후 실측 검증 필수)

#### 예시: app-launched.json (단순 카운팅)

```json
{
  "queryType": "timeseries",
  "dataSource": "telemetry-signals",
  "granularity": "day",
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "PickPhoto.app.launched"
  },
  "aggregations": [
    { "type": "eventCount", "name": "launchCount" }
  ]
}
```

> `relativeIntervals`, `appID` 필터, `isTestMode` 필터는 `td-query.sh`가 실행 시 자동 주입.

#### 예시: photo-viewing.json (세션 카운터 합산)

세션 카운터 시그널은 파라미터에 숫자 문자열(`"total": "5"`)을 담아 보냄.
`eventCount`는 세션 수만 세므로, `longSum`으로 실제 값을 합산해야 함.

```json
{
  "queryType": "timeseries",
  "dataSource": "telemetry-signals",
  "granularity": "day",
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "PickPhoto.session.photoViewing"
  },
  "aggregations": [
    { "type": "eventCount", "name": "sessions" },
    { "type": "longSum", "name": "totalViews", "fieldName": "total" },
    { "type": "longSum", "name": "fromLibrary", "fieldName": "fromLibrary" },
    { "type": "longSum", "name": "fromAlbum", "fieldName": "fromAlbum" },
    { "type": "longSum", "name": "fromTrash", "fieldName": "fromTrash" }
  ]
}
```

> `delete-restore`, `trash-viewer`, `similar-analysis`도 동일 패턴. 각 시그널의 파라미터 키에 맞춰 `longSum` 항목 구성.

#### 예시: cleanup.json (퍼널 분석 — groupBy)

groupBy의 `dimensions`는 DimensionSpec 객체 배열 필수 (문자열 배열 불가):

```json
{
  "queryType": "groupBy",
  "dataSource": "telemetry-signals",
  "dimensions": [
    { "dimension": "reachedStage", "type": "default", "outputName": "reachedStage" }
  ],
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "PickPhoto.cleanup.completed"
  },
  "aggregations": [
    { "type": "eventCount", "name": "count" }
  ],
  "granularity": "all"
}
```

> `permission.json`, `similar-group.json`, `preview-cleanup.json`도 동일하게 DimensionSpec 객체 사용.

#### 예시: errors.json (에러 항목별 합산)

에러 카테고리가 파라미터 키(`"photoLoad.gridThumbnail": "3"`)로 전송되므로,
각 키별 `longSum`으로 세션 간 합산:

```json
{
  "queryType": "timeseries",
  "dataSource": "telemetry-signals",
  "granularity": "all",
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "PickPhoto.session.errors"
  },
  "aggregations": [
    { "type": "eventCount", "name": "errorSessions" },
    { "type": "longSum", "name": "photoLoad_gridThumbnail", "fieldName": "photoLoad.gridThumbnail" },
    { "type": "longSum", "name": "photoLoad_viewerOriginal", "fieldName": "photoLoad.viewerOriginal" },
    { "type": "longSum", "name": "photoLoad_iCloudDownload", "fieldName": "photoLoad.iCloudDownload" },
    { "type": "longSum", "name": "face_detection", "fieldName": "face.detection" },
    { "type": "longSum", "name": "face_embedding", "fieldName": "face.embedding" },
    { "type": "longSum", "name": "cleanup_startFail", "fieldName": "cleanup.startFail" },
    { "type": "longSum", "name": "cleanup_imageLoad", "fieldName": "cleanup.imageLoad" },
    { "type": "longSum", "name": "cleanup_trashMove", "fieldName": "cleanup.trashMove" },
    { "type": "longSum", "name": "video_frameExtract", "fieldName": "video.frameExtract" },
    { "type": "longSum", "name": "video_iCloudSkip", "fieldName": "video.iCloudSkip" },
    { "type": "longSum", "name": "storage_diskSpace", "fieldName": "storage.diskSpace" },
    { "type": "longSum", "name": "storage_thumbnailCache", "fieldName": "storage.thumbnailCache" },
    { "type": "longSum", "name": "storage_trashData", "fieldName": "storage.trashData" }
  ]
}
```

### 4.4 td-report.sh — 주간 리포트

**용도:** 전체 시그널 일괄 조회 후 마크다운 리포트 출력.

**사용법:**
```bash
./td-report.sh              # 기본 7일
./td-report.sh --days 30    # 30일
./td-report.sh --test-mode  # 테스트 데이터 포함
```

**동작:**
```
1. queries/ 디렉토리의 10개 쿼리를 순차 실행
   (병렬은 토큰 경합 방지를 위해 비권장, 순차로도 ~30초 이내)
2. 각 결과 JSON을 /tmp/td-results/ 에 저장
3. jq로 핵심 수치 추출
4. 마크다운 포맷으로 stdout 출력
```

**출력 형식 (예시):**

```markdown
# PickPhoto 주간 리포트 (2026-02-07 ~ 2026-02-13)

## 핵심 지표
| 지표 | 값 |
|------|-----|
| 앱 실행 | 145회 |
| 사진 열람 | 1,230장 |
| 삭제 | 89건 |
| 복구 | 12건 |

## 정리 기능
| 단계 | 도달 수 |
|------|--------|
| buttonTapped | 23 |
| methodSelected | 18 |
| cleanupDone | 15 |

## 오류 현황
| 오류 | 발생 수 |
|------|--------|
| (없음 또는 항목별 표시) |

## 데이터 원본
조회 기간: 7일 / 쿼리 10건 / 생성: 2026-02-13 15:00
```

**예상 크기:** ~60줄

---

## 5. 의존성

| 도구 | 용도 | macOS 기본 설치 |
|------|------|----------------|
| `curl` | HTTP 요청 | ✅ |
| `jq` | JSON 파싱 | ❌ (`brew install jq`) |
| `date` | 만료 시간 비교 | ✅ (GNU date 아닌 BSD date) |
| `base64` | Basic Auth 인코딩 | ✅ |

> `jq`만 추가 설치 필요. 없으면 스크립트가 안내 메시지 출력.

---

## 6. 구현 순서

| 단계 | 작업 | 예상 크기 |
|------|------|----------|
| **1** | `.env.example` + `.gitignore` 추가 | ~10줄 |
| **2** | `td-auth.sh` (토큰 발급+캐싱) | ~40줄 |
| **3** | `td-query.sh` (비동기 3단계 쿼리 + 필터 주입) | ~90줄 |
| **4** | `queries/` 10개 JSON 파일 | ~350줄 |
| **5** | `td-report.sh` (주간 리포트) | ~60줄 |
| **6** | 실제 API 호출 테스트 + `longSum` 검증 | — |

**총 예상:** ~550줄 (쿼리 JSON 포함, longSum 항목 증가분 반영)

---

## 7. 사용 시나리오

### Claude Code에서 직접 호출

```bash
# 지난 7일 앱 실행 추이
./scripts/analytics/td-query.sh scripts/analytics/queries/app-launched.json

# 지난 30일 오류 현황
./scripts/analytics/td-query.sh scripts/analytics/queries/errors.json --days 30

# 주간 리포트 생성
./scripts/analytics/td-report.sh
```

### Claude가 데이터 분석

```
주인님: "정리 기능 퍼널 분석해줘"
    ↓
Claude: td-query.sh queries/cleanup.json --days 30 실행
    ↓
Claude: JSON 결과 파싱
    ↓
Claude: "버튼 탭 23건 → 방식 선택 18건(78%) → 완료 15건(65%) → 이탈 지점은 방식 선택 단계"
```

---

## 8. 주의사항

- TelemetryDeck API는 현재 무료 사용 가능하나, **Tier 2 유료 플랜에서 공식 지원** 예고
- Bearer Token 만료 시간을 반드시 확인 (보통 24시간~)
- BSD `date`와 GNU `date` 문법 차이 → macOS 호환 코드 작성 필수
- `isTestMode` 필터: 개발 중엔 `--test-mode` 플래그로 테스트 데이터 포함, 프로덕션에선 기본 제외

### 구현 후 검증 필수 항목

- **`longSum` + 문자열 파라미터 호환성**: 우리 SDK가 `String(count)` 로 보낸 값이 Druid `longSum`으로 합산 가능한지 실측 확인. 안 되면 `doubleSum`으로 대체하거나, `scan` 쿼리 + Claude 파싱 방식으로 전환
- **파라미터 키의 점(.) 포함 이름**: `"photoLoad.gridThumbnail"` 같은 키가 TQL dimension/fieldName으로 정상 작동하는지 확인. 문제 시 에러 파라미터 키를 밑줄(`_`)로 변경 필요
