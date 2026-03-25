# 사진 정리 앱 고객 세분화 리서치

> 조사일: 2026-03-13
> 목적: 사업계획서 타겟 고객 분석(STP) 근거 마련

---

## 1. 사진 정리 사용자 행동 데이터

### 핵심 통계

| 데이터 | 수치 | 출처 |
|--------|------|------|
| 불필요한 사진을 삭제하지 않는 비율 | 71% | EverPresent |
| 쌓인 사진 정리 소요 시간 추정 | 약 45시간 | EverPresent |
| 쌓인 사진에 압도감을 느끼는 비율 | 55% | Mixbook/YouGov 2025 |
| 정리를 고려하면서도 실행하지 못하는 비율 | 60% | Western Digital/OnePoll 2020 |
| 평균 스마트폰 사진 보유량 | 약 2,000장 (iPhone 평균 2,400장) | Mobile Photography Statistics 2025 |
| 전 세계 연간 촬영량 (2025) | 2.1조 장 (일 53억 장) | PetaPixel 2025 |
| 전체 사진 중 스마트폰 촬영 비율 | 92.5~94% | electroiq 2025 |

### 사진 정리 트리거 (사용자가 정리를 시작하는 계기)

| 트리거 | 설명 | 빈도 |
|--------|------|------|
| 저장공간 부족 | "저장 공간이 거의 찼습니다" 알림 → 급하게 삭제 시작 | 가장 흔함 |
| 대량 촬영 후 | 여행/이벤트/육아 등 단기간 대량 촬영 후 정리 필요 | 이벤트성 |
| 습관적 정리 | 주기적으로(주간/월간) 카메라롤을 청소하는 습관 | 소수 파워유저 |
| 특정 사진 검색 실패 | 사진을 찾으려는데 못 찾아서 정리 필요성 인식 | 계기성 |

### 디지털 사진 호딩 행동 연구 (Frontiers in Psychology 2025)

사진을 삭제하지 못하는 주요 요인:

1. **감정적 애착** — 사진이 자아의 연장으로 인식됨
2. **FOMO** — "나중에 필요할까봐"
3. **대인관계 영향** — 타인과 공유된 사진은 삭제 저항이 더 큼
4. **기술 진보** — 저장 공간 확대로 삭제 동기 감소

---

## 2. 경쟁사 고객 세분화 사례

| 앱 | 포지셔닝 | 핵심 타겟 | 모델 |
|----|----------|----------|------|
| Slidebox | 스와이프 기반 직관적 정리 (수동 제어 선호) | 10,000장+ 빠른 정리 | 무료+광고, ★4.8 (12K+ 리뷰) |
| CleanMyPhone (MacPaw) | AI 기반 자동 분류 + 스토리지 최적화 | 50,000장+ 파워유저 | 구독 |
| Gemini Photos | 중복/유사 사진 정리 특화 | 버스트/유사 사진이 많은 사용자 | 구독 |
| Google Photos | 클라우드 백업 + AI 검색 | 삭제 자체를 원치 않는 사용자 (저장으로 해결) | 프리미엄 |

---

## 3. SweepPic용 고객 세분화 (MECE)

구분 축: **정리 동기**(왜 정리하는가)

| 세그먼트 | 정리 동기 | 핵심 페인 | 대응 기능 |
|----------|----------|----------|----------|
| 연속 촬영자 | 같은 장면 다수 촬영 후 베스트샷 선별 | 축소 썸네일로는 표정·눈감김 차이 비교 불가 | 유사사진 얼굴 크롭·비교 |
| 무관심 축적자 | 저장공간 부족 알림에 반응 | 뭘 지워야 할지 모름, 정리할 엄두가 안 남 | 품질점수 기반 3단계 자동정리 |
| 대량 정리자 | 여행·이벤트 후 일괄 정리 | 기본 사진앱에서 하나씩 삭제가 너무 느림 | 그리드 스와이프 즉시 삭제 |

### MECE 검증

| | 연속 촬영자 | 무관심 축적자 | 대량 정리자 |
|--|-----------|-------------|-----------|
| 정리 빈도 | 촬영 직후 | 저장공간 부족 시만 | 이벤트 후 |
| 의사결정 | "어떤 게 제일 잘 나왔지?" | "뭘 지워도 되지?" | "빨리 끝내고 싶다" |
| 핵심 감정 | 선택 피로 | 무관심/압도감 | 효율 추구 |

---

## 출처

- [EverPresent — Digital Photo Statistics](https://www.everpresent.com/stat/digital-photo-statistics)
- [Mixbook/YouGov 조사 (2025)](https://www.mixbook.com/photo-books)
- [Western Digital/OnePoll 조사 (2020)](https://www.westerndigital.com/)
- [Mobile Photography Statistics 2025 — electroiq](https://electroiq.com/stats/mobile-photography-statistics/)
- [PetaPixel — Photos Taken in 2025](https://petapixel.com/2025/06/18/the-number-of-photos-taken-in-2025-is-expected-to-exceed-two-trillion/)
- [Digital photo hoarding behavior — Frontiers in Psychology 2025](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2025.1607274/full)
- [Slidebox Alternatives — AlternativeTo](https://alternativeto.net/software/slidebox/)
- [CleanMyPhone Review — Cult of Mac](https://www.cultofmac.com/reviews/cleanmyphone-app-review)
- [Best Duplicate Photo Cleaner — MacPaw](https://macpaw.com/how-to/best-duplicate-photo-cleaner-iphone)
- [Smartphone photo organization — ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S1077314219301055)
