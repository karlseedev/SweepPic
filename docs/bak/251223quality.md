# 251123 Quality Plan: 스크롤 품질(체감) 유지 + Hitch 개선

## 배경 / 현재 상태 요약

- 목표(릴리즈 기준): **일상 스크롤(사진 찾기 정도)**에서 Hitch **Warning(< 10 ms/s)**, 궁극적으로 **Good(< 5 ms/s)**.
- 품질 요구(사용자 관점):
  - 스크롤 중/정지 후 **썸네일 선명도 유지**(정지 후엔 반드시 최종 이미지로 업그레이드)
  - **회색(placeholder) 노출 최소화**(특히 “멈춰서 찾는” 상황에서)
  - 탭/스크롤 반응성 유지(메인 스레드 블로킹 금지)
- 이미 적용된 큰 개선(P0): `prefetchItemsAt` 경로의 preheat 제거로 “동기 fetchAsset(=PHAsset.fetchAssets) 비용” 제거.
  - 결과: hitch가 크게 낮아졌지만, 일부 시나리오에서 여전히 `> 10 ms/s`가 반복됨.
- 로그에서 반복적으로 보이는 신호:
  - `req/s`가 높을 때 `cancel/s`도 거의 같이 높아짐(“요청-취소 폭주” 패턴)
  - 즉, 남아있는 문제는 “이미지 품질”보다 **요청 생성/취소 오버헤드 + 콜백/이미지 적용 churn** 가능성이 큼

## 이 문서의 목적

P2(콜백/UI churn 제어)와 별개로, **사용자가 느끼는 품질을 유지**하면서도 **효율(=hitch 개선 가능성)이 더 큰 레버**를 선별해 “계획의 목적/달성 지표/부작용/완화책”까지 포함한 실행 계획으로 정리합니다.

---

## 공통 품질 기준(모든 실험에 적용)

각 실험은 아래를 만족해야 “품질 유지”로 판단합니다.

1. **선명도**
   - 스크롤 중에는 degraded(저해상도) first-paint는 허용
   - **정지 후**에는 최종(final) 이미지로 **반드시 업그레이드**되어야 함(“항상 흐림” 금지)
2. **회색(placeholder)**
   - 회색 노출은 “아주 빠른 스크롤”에서 일부 허용
   - “찾기 스크롤(중간 속도)”에서 **정지 후에도 회색이 남는 현상**은 허용하지 않음
3. **반응성**
   - 메인 스레드에서 디스크 I/O, 동기 PhotoKit 호출 금지
   - 스크롤 중 무거운 작업(대량 preheat, sync exists 체크 등) 금지

### 공통 측정 지표(최소)

- Hitch: `ms/s`, `dropped`, `longest`
- Pipeline: `req`, `cancel`, `complete`, `degraded`, `req/s`, `cancel/s`
- Gray(회색):
  - `grayShown`(willDisplay 시점 image nil)
  - `grayResolved`(nil→non-nil 전환)
  - **주의:** `pending = shown - resolved`는 음수가 정상일 수 있어 “남아있는 회색”으로 해석하면 안 됨
  - 권장 추가(가능하면): 스크롤 종료 시점 `visibleGrayCount`(visibleCells 중 image nil 개수)

### 실험 운영(신뢰도)

- 같은 시나리오로 **3회** 반복 후 중앙값(median) 비교(편차 큰 구간은 5회)
- 비교는 반드시 동일 조건(Release/Debug, 동일 기기, 동일 스크롤 패턴)로 수행

---

## 후보 1) 요청 시작 디바운스(30~60ms)

### 목적(무엇을 달성?)

**“스쳐 지나가는 셀”의 요청을 아예 만들지 않아서** 다음을 동시에 낮춥니다.

- `req/s` 감소 → PhotoKit/OperationQueue/콜백 전체 부하 감소
- `cancel/s` 감소 → cancel 처리/락(statsLock)/cancelImageRequest 오버헤드 감소

즉, *P2처럼 “콜백 처리”를 줄이기 전에,* **요청 생성 자체를 줄이는** 고효율 레버입니다.

### 기대 효과(왜 클 수 있나?)

- 로그에서 `cancel ≈ req`가 자주 관측됨 → “요청했다가 곧 취소”가 대량 발생
- 디바운스는 이 구간을 통째로 제거(요청 생성/취소가 모두 사라짐)

### 계획(구현 방향)

**핵심 원칙:** “품질을 유지하려면, 디바운스는 *스크롤 중 transient 셀*에만 적용하고, *정지/감속 종료* 시에는 즉시 요청으로 전환”

1. `PhotoCell`에 `pendingRequestWorkItem`(또는 `Timer`)를 둡니다.
2. `configure()` 흐름
   - 메모리 캐시 히트: 즉시 표시(기존 유지)
   - 캐시 미스:
     - 스크롤 중(`isFullSizeRequest == false` 또는 `isScrolling == true`): **30~60ms 지연 예약**
     - 정지 상태: 즉시 요청(기존 유지)
3. 지연 실행 시 조건 체크(필수)
   - `currentAssetID == assetID`
   - `imageView.image == nil`(이미 채워졌으면 skip)
   - `window != nil`(이미 offscreen이면 skip)
4. 취소 지점(필수)
   - `prepareForReuse()`에서 `pendingRequestWorkItem.cancel()`
   - 가능하면 `didEndDisplaying`에서 “pending + in-flight” 취소
5. 품질 가드레일(권장)
   - `scrollDidEnd()`(100ms 디바운스 완료 시점)에서 visible 셀의 pending을 **즉시 실행**(최대 N개, 예: 15)

### 성공 기준(측정으로 판단)

- 일상 스크롤에서
  - `req/s`와 `cancel/s`가 **동시에 유의미하게 감소**(권장: 30% 이상)
  - hitch가 `< 10 ms/s`에 근접/도달
  - 정지 후 선명도/회색 체감 악화가 없어야 함

### 단점/리스크

- (품질) 지연으로 인해 일부 셀이 더 오래 회색으로 남을 수 있음
- (품질) “정지 직후” 업그레이드가 늦어 보일 수 있음(특히 60ms 이상 설정 시)
- (구현) 셀 재사용/레이스 조건에서 “잘못된 에셋 요청”이 날 수 있음(체크 누락 시)

### 완화책

- 지연값은 보수적으로 시작(30ms) → 효과 부족 시 40~60ms로 조정
- 정지 시점에 pending을 즉시 실행(visible 한정)하여 체감 품질 유지
- 레이스 가드(AssetID/Window/Image nil 체크) 필수
- 롤백: 디바운스 부분만 토글 가능하도록 플래그화(실험/릴리즈 안전장치)

---

## 후보 2) in-flight dedupe(동일 요청 합치기)

### 목적(무엇을 달성?)

**같은 asset+size 요청이 짧은 시간에 중복될 때** PhotoKit 호출을 1회로 합쳐서:

- `req` 자체를 줄이고, 결과적으로 `cancel`도 감소
- OperationQueue/PhotoKit 부하 감소 → hitch 개선 가능

**품질은 “동일 결과를 공유”**하므로 원칙적으로 변화가 없습니다.

### 언제 효과가 큰가?

- 셀 재사용/재진입으로 인해 동일 키 요청이 반복되는 구간
- P2(최종 지연) 같은 정책과 결합하면, “같은 final”을 여러 셀/시점에 공유할 수 있어 추가 이득

### 계획(구현 방향)

**구현 위치:** `ImagePipeline.requestImage(for:targetSize:...)`

1. `RequestKey` 정의(충돌 방지)
   - `assetID`
   - `targetSize`(정수 픽셀로 정규화)
   - `contentMode`
   - (가능하면) `modificationDate`(변경 이미지 방지; nil 허용)
2. `inFlight` 테이블(동기화는 serial queue 또는 lock)
   - 키가 없으면 새 PhotoKit 요청 생성
   - 키가 있으면 “조인(join)” → callback 리스트에 등록
3. 콜백 fan-out 정책(품질 우선)
   - degraded/final을 모두 브로드캐스트(기존 동작 유지)
   - 신규 조인 시점에 이미 degraded가 도착했을 수 있으므로,
     - 선택 A(단순): 이후 콜백만 받음(구현 쉬움, 품질은 약간 손해 가능)
     - 선택 B(권장): `lastDeliveredDegraded`를 저장해두고 신규 조인에 즉시 1회 전달(품질 보존)
4. 취소 정책(품질/정합성)
   - 개별 구독 취소는 “자기 콜백만 제거”
   - 구독자가 0명이 되면 underlying request를 cancel
5. 종료/정리
   - final 도착 또는 cancel로 `inFlight` 엔트리 제거

### 성공 기준

- 동일 시나리오에서 `req/s` 감소 + hitch 개선
- “이미지 잘못 매칭(오표시)” 0건

### 단점/리스크

- (정합성) 키 설계가 부정확하면 다른 요청을 잘못 합쳐 품질/정확도 문제 발생
- (구현) degraded/final 순서, 신규 조인 타이밍 처리 등 복잡도 상승
- (메모리) inFlight 엔트리/콜백 리스트가 누수되면 메모리 증가

### 완화책

- 키는 보수적으로(정규화된 size + contentMode + modDate 포함) → “합칠 수 있는 것만 합치기”
- 엔트리 lifetime을 짧게(최종 도착 시 즉시 제거)
- 디버그에서 key 충돌/조인율/엔트리 수를 로깅하여 누수/오작동 조기 감지
- 초기에는 “조인율이 높은지”부터 계측 후, 낮으면 스킵 판단

---

## 후보 3) 완료된 요청 정리(불필요 cancel 제거 + 통계/오버헤드 노이즈 감소)

### 목적(무엇을 달성?)

요청이 이미 final까지 끝났는데도, 셀 재사용 과정에서 `cancel()`이 호출되면:

- 실제 cancel이 의미 없거나, 오히려 `cancelImageRequest` 호출/통계 업데이트가 발생할 수 있음
- `maxInFlight`, `cancelCount` 같은 계측 노이즈 증가

따라서 **final 완료 시점에 토큰/핸들러를 정리**하여 불필요한 cancel 경로를 없앱니다.

### 계획(구현 방향)

1. `PhotoCell` 측
   - final 수신 시점(`isDegraded == false`)에 `currentCancellable = nil` 처리
   - degraded에서 nil 처리 금지(최종 콜백을 잃을 수 있음)
2. `ImagePipeline` 측(선택)
   - final 완료 시점에 `CancellableToken`의 cancel 핸들러를 무력화하거나, “finished 플래그”로 cancel no-op 처리
   - cancel 핸들러에서 `inFlightCount`를 감소시키는 로직이 “완료 이후” 중복으로 실행되지 않도록 보호

### 성공 기준

- `cancel` 통계의 노이즈 감소(특히 cancel≈req 같은 과장 감소)
- hitch 개선은 부수효과(있으면 좋음)로 보고, 주목적은 안정화/노이즈 제거

### 단점/리스크

- (레이스) final 직전/직후 타이밍에서 nil 처리/finished 처리 순서가 잘못되면 취소 불가/중복 감소 등 버그 가능
- (효과) hitch 직접 개선폭은 1/2보다 작을 수 있음

### 완화책

- “final에서만” 정리한다는 규칙을 엄격히 유지
- 디버그에서 finished/cancel 경로를 로그로 확인(초기만)
- 1/2 적용 전 “계측 노이즈 제거”용으로 먼저 넣는 것도 가능

---

## 추천 실행 순서(품질 유지 + 효율 기준)

1. **후보 1(디바운스)**: req/cancel 자체를 줄이는 가장 큰 레버
2. **후보 2(dedupe)**: 품질 무손실로 중복 호출을 제거(조인율 높을 때 효과 큼)
3. **후보 3(완료 정리)**: 안정화/계측 노이즈 제거(부작용 거의 없음)

## 각 단계의 “스킵” 조건(시간 절약)

- 후보 1 적용 후 `req/s`가 이미 충분히 낮고 hitch가 목표에 근접하면 후보 2는 스킵 가능
- 후보 2의 조인율이 낮으면(예: 전체 req의 5% 미만) 비용 대비 효과가 작아 스킵 권장
- 후보 3은 효과가 작아도 리스크가 낮아 “정리 목적”이면 유지 가능

