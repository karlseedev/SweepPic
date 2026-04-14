# Edge Function 배포 및 테스트 기록

**작성일**: 2026-03-30
**대상**: `referral-api` (create-link 엔드포인트)

---

## 1. 배포 환경 설정

### Supabase CLI 설치 및 연결

```bash
brew install supabase/tap/supabase    # CLI 설치 (v2.75.0)
supabase login                         # 브라우저에서 Supabase 계정 로그인
supabase link --project-ref ewuqdgazvfataoakdton   # 프로젝트 연결
```

### config.toml 수정 사항

배포 과정에서 에러가 발생하여 아래 항목을 수정함.

| 변경 | 이유 |
|------|------|
| `[project] id` 제거 | CLI가 인식 못하는 키. `supabase link`로 연결하면 자동 저장됨 |
| `[functions.offer-code-replenish] schedule` 주석 처리 | CLI config.toml에서 지원 안 하는 키. cron은 Supabase Dashboard에서 설정 |
| `[db] major_version` 15 → 17 | Supabase 프로젝트의 실제 PostgreSQL 버전에 맞춤 |
| `[functions.referral-api] verify_jwt = false` 추가 | 아래 JWT 관련 내용 참조 |

### JWT 검증 비활성화 (`verify_jwt = false`)

**문제**: Supabase 신규 키 형식(`sb_publishable_...`)으로 Edge Function 호출 시 401 에러 발생
```
{"code":401,"message":"Invalid Token or Protected Header formatting"}
```

**원인**: Supabase Gateway가 레거시 JWT(`eyJ...`) 형식만 검증 가능. 신규 키 형식은 JWT가 아님.

**해결**: `config.toml`에 `verify_jwt = false` 설정 후 재배포

**보안 영향 없음**:
- 기존 JWT 검증도 공개 키(anon key)를 확인하는 것이라 보안 효과 사실상 없음
- 우리 코드에 이미 실질적 보안 구현됨: user_id 필수 검증 + rate limiting + 비즈니스 로직
- Supabase 공식 권장 방향과 일치 ([Discussion #41834](https://github.com/orgs/supabase/discussions/41834))

---

## 2. 배포

```bash
supabase functions deploy referral-api
```

- Docker 미실행 경고는 무시 (로컬 실행이 아닌 클라우드 배포이므로)
- 업로드 파일: `index.ts` + `_shared/rate-limiter.ts`

---

## 3. 테스트 결과

### 3-1. 새 코드 생성 — 성공

```bash
curl -s -X POST \
  'https://ewuqdgazvfataoakdton.supabase.co/functions/v1/referral-api/create-link' \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "test-user-001"}'
```

```json
{
    "success": true,
    "data": {
        "referral_code": "x0xh82bM9j",
        "share_url": "https://ewuqdgazvfataoakdton.supabase.co/functions/v1/referral-landing/r/x0xh82bM9j"
    }
}
```

- 코드 형식 `x0{6자리}9j` 정상
- share_url 폴백(CUSTOM_DOMAIN 미설정 → Edge Function URL) 정상

### 3-2. 같은 user_id 재요청 — 동일 코드 반환 (중복 생성 안 됨)

```json
{
    "success": true,
    "data": {
        "referral_code": "x0xh82bM9j",
        "share_url": "https://ewuqdgazvfataoakdton.supabase.co/functions/v1/referral-landing/r/x0xh82bM9j"
    }
}
```

### 3-3. user_id 누락 — 에러 정상 반환

```bash
curl -s -X POST ... -d '{}'
```

```json
{
    "success": false,
    "error": "user_id가 필요합니다."
}
```

### 3-4. 없는 엔드포인트 — 에러 정상 반환

```bash
curl -s -X POST .../referral-api/unknown -d '{"user_id": "test"}'
```

```json
{
    "success": false,
    "error": "알 수 없는 엔드포인트: unknown"
}
```

---

## 4. 테스트 데이터

| 테이블 | 데이터 | 비고 |
|--------|--------|------|
| `referral_links` | user_id: `test-user-001`, code: `x0xh82bM9j` | 테스트용, 필요시 삭제 |

---

## 5. 참고

- Supabase Dashboard: https://supabase.com/dashboard/project/ewuqdgazvfataoakdton/functions
- Edge Function 로그 확인: Dashboard > Edge Functions > referral-api > Logs
