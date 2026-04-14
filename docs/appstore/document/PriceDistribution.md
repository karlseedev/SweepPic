# SweepPic 가격 및 배포 설정 가이드

> App Store Connect 입력용

---

## 1. 앱 가격

| 항목 | 설정값 |
|------|-------|
| Price | **무료** (Free) |

---

## 2. 배포 (Availability)

| 항목 | 설정값 |
|------|-------|
| 배포 국가 | 한국 (초기 출시) |
| Pre-Order | 사용 안 함 |

---

## 3. 인앱 구독 (SweepPic Pro)

### 구독 그룹

| 항목 | 설정값 |
|------|-------|
| Subscription Group Name | SweepPic Pro |
| Product ID (월간) | `pro_monthly` |
| Product ID (연간) | `pro_yearly` |

### 구독 가격 (런칭 할인가)

| 플랜 | 가격 (USD) | 비고 |
|------|-----------|------|
| 월간 | **$2.99/월** | 보조 옵션 |
| 연간 | **$19.99/년** | 메인 전환 타겟 (월 환산 $1.67) |

> 정가: 월간 $3.99, 연간 $29.99 → 데이터 분석 후 단계적 복구
> KRW 가격은 App Store Connect에서 자동 환산

### 구독 설정

| 항목 | 설정값 |
|------|-------|
| 자동 갱신 | 활성화 |
| Billing Grace Period | 16일 |
| 무료 체험 (Free Trial) | 사용 안 함 (자체 Grace Period 3일로 대체) |

### Pro 혜택 비교

| 기능 | 무료 | Pro |
|------|:----:|:----:|
| 일일 영구 삭제 | 10장 | 무제한 |
| 광고 | 있음 | 없음 |
| 게이트 시트 | 있음 | 없음 |
| 그리드/유사사진/자동정리 | 무제한 | 무제한 |

---

## 4. 콘텐츠 권리 (Content Rights)

| 질문 | 답변 |
|------|------|
| Does your app contain, show, or access third-party content? | **No** |

> 사용자 본인의 사진만 표시, 제3자 콘텐츠 없음

---

## 5. Tax Category

| 항목 | 설정값 |
|------|-------|
| Tax Category | App Store Connect 기본값 (Software) |

---

## 출처

- `docs/bm/260227bm-spec.md` §6 (구독)
- `Sources/AppCore/Models/SubscriptionTier.swift` (Product ID)
