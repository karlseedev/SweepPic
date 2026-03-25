# 경쟁앱 심층 분석

> 조사일: 2026-03-04
> 가격 데이터: App Store 페이지 직접 fetch (US: apps.apple.com/us, KR: apps.apple.com/kr) — 2026-03-04 기준
> 조사 방법: App Store 페이지, 독립 리뷰 사이트(InsanelyMac, MacPaw, MacGasm, CleanMyMac Blog), Sensor Tower, Connor Tumbleson 보안 분석, JustUseApp, Trustpilot
> 검증: 1~15번 앱 교차 검증 완료

---

## 앱별 상세 분석

---

### 1. Cleaner Kit — Clean Up Storage

| 항목 | 내용 |
|------|------|
| 개발사 | BPMobile (BP Mobile LLC) |
| 평점 / 리뷰 | 4.4 / ~333K |
| 월 매출 | ~$2M (Sensor Tower, 소스별 $850K~$2M 편차) |
| 다운로드 | 누적 6,800만+, 월 ~70만 |
| 앱 크기 | 170.4MB, iOS 15.0+ |

**자동 분석 기능:**
- 유사 사진, 중복 사진, 흐린 사진, 스크린샷, 텍스트 포함 사진, 유사 영상, 대용량 비디오, 라이브포토
- AI 14개 카테고리 자동 분류 (People, Animals, Nature, Home, Vehicles, Urban, Devices, Sports, Food, Tools, Clothes, Hobbies, Docs, Other)
- Best Photo 자동 선택 ~95% 정확도 (단일 리뷰어 체감)
- 온디바이스 AI 표방, 클라우드 업로드 없음

**정리 UX:**
- 스와이프(Tinder식, 좌=삭제/우=보관) + 체크박스 병행
- 자동 삭제 아님 (사용자 최종 확인)
- Undo: 앱 내 없음, iOS "최근 삭제" 의존
- 배치 삭제 지원

**무료 범위:**
- 스캔 무료, 광고 시청당 20장 삭제
- 무료체험 **3일 또는 7일** (A/B 테스트, App Store에 기간 미명시, 리뷰에서 양쪽 혼재)

**가격 (App Store 직접 확인):**
- US: 주간 $4.99~$6.99
- KR: 주간 ₩7,700~₩14,000
- KR 평점 4.2 / 리뷰 8,240개

**약점/불만:**
- 65K장 스캔 ~5분 (느림)
- 공격적 과금 유도 (주간 구독 우선)
- 연락처 병합 오류 (다른 사람 합침)
- Surfshark 조사: "10개 클리너 앱 중 가장 많은 데이터를 서드파티에 공유" (9개 데이터 카테고리)
- 가짜 리뷰 의혹, JustUseApp 안전점수 34.2/100

**출처:** [App Store](https://apps.apple.com/us/app/cleaner-kit-clean-up-storage/id1194582243), [InsanelyMac Review](https://www.insanelymac.com/blog/cleaner-kit-clean-up-storage-review/), [Predatory iOS Apps](https://connortumbleson.com/2025/01/13/predatory-ios-cleanup-applications/), [Surfshark](https://surfshark.com/research/chart/phone-cleaner-apps)

---

### 2. Cleanup — Phone Storage Cleaner

| 항목 | 내용 |
|------|------|
| 개발사 | Codeway Dijital (터키, 2020년 설립), 현재 퍼블리셔: DEEP FLOW SOFTWARE SERVICES |
| 평점 / 리뷰 | 4.7 / ~624K |
| 월 매출 | $4~9M (최근 ~$6.25M 추정) |
| 다운로드 | 월 ~175~200만, Cleanup 단독 5,000만+ (Codeway 공식), 전사 60개+ 앱 합산 3억+ |
| 앱 크기 | 203.9MB, iOS 15.0+ |

**자동 분석 기능:**
- 중복, 유사 사진, 유사 스크린샷, 유사 비디오, 화면 녹화, 흐린 사진
- 대용량 비디오: 별도 카테고리 아닌 Videos 내 크기순 정렬
- Best Photo 자동 선택 있으나 부정확 (눈 감은 사진 선택 등)
- 100% 온디바이스 표방, 실제 6개 분석 플랫폼 사용 (Adjust, Firebase, Cerebro, Admost, Facebook, Unity Ads)

**정리 UX:**
- 스와이프(Tinder식) — 여러 카테고리에서 접근 가능 (검증 정정: 숨겨져 있지 않음)
- 체크박스 병행, One-Tap Cleanup 지원
- Undo: 앱 내 없음, iOS "최근 삭제" 의존
- 삭제 처리 속도 느림 (그룹당 5~8초)

**무료 범위:**
- 스캔 무료, 무료 5장 삭제, 광고 시청 시 25장
- 무료체험 7일

**가격 (App Store 직접 확인):**
- US: 주간 $5.95~$9.99 / 연간 $29.99
- KR: 주간 ₩4,400~₩14,000 / 연간 ₩33,000
- KR 평점 4.6 / 리뷰 4,100개

**저품질 감지**: 흐림 전용 카테고리 없음. Best Photo 선택 시 "초점(in focus)" 기준 포함하나, 흐린 사진을 유지하고 선명한 사진을 삭제 추천하는 역전 현상 보고 (InsanelyMac, JustUseApp)

**약점/불만:**
- Best Photo 선택 오류 빈번
- **흐린 사진 유지 + 선명한 사진 삭제 추천** (역전 현상, 리뷰어 Pagerda)
- 구독 사기/자동 과금 불만
- 유사 사진 분류 부정확 (전혀 다른 사진을 같은 그룹)
- Facebook/YouTube에서 고령 사용자 집중 타겟팅
- iOS 기본 기능(중복 감지, 연락처 병합)과 중복

**출처:** [App Store](https://apps.apple.com/us/app/cleanup-phone-storage-cleaner/id1510944943), [InsanelyMac](https://www.insanelymac.com/blog/cleanup-phone-storage-cleaner-review/), [Predatory iOS Apps](https://connortumbleson.com/2025/01/13/predatory-ios-cleanup-applications/), [Growth Hacking Lab](https://thegrowthhackinglab.com/case-studies/codeway-150-million-revenue-16-apps/)

---

### 3. AI Cleaner — Clean Up Storage

| 항목 | 내용 |
|------|------|
| 개발사 | GRIMLAX TRADE, S.L. (스페인 바르셀로나, 2023년 설립) |
| 평점 / 리뷰 | 4.6 / ~183K (독립 리뷰 2.8/5) |
| 월 매출 | ~$3M |
| 다운로드 | 월 ~80만 |
| 앱 크기 | 243.2MB, iOS 15.0+, visionOS 1.0+ |

**자동 분석 기능:**
- 중복, 유사, 흐린 사진, 스크린샷, 중복 동영상
- **흐린 사진 감지 98.7% 오탐율** (79장 중 78장 오탐, InsanelyMac 테스트)
- 유사 사진: 인물 외 90% 실패, 인물도 30% 오류
- Best Photo 선택 90% 실패
- 중복 감지 87%, 유사 73% (autonomous.ai 단일 출처)
- 온디바이스 표방, 트래커 3개+ 확인 (Firebase, AppsFlyer, Amplitude)

**정리 UX:**
- "Smart Clean" 자동 모드 있으나 신뢰도 매우 낮음
- 스와이프 모드 하위 메뉴에 숨겨짐
- 사이드-바이-사이드 비교 없음
- Undo: 앱 내 없음

**무료 범위:**
- 스캔 무료, 삭제 하루 10~50건 (시기별 변동)
- 무료체험 3일

**가격 (App Store 직접 확인):**
- US: 주간 $6.99~$9.99 / 연간 $34.99~$39.99
- KR: 주간 ₩9,900~₩14,000 / 월간 ₩14,000 / 연간 ₩44,000~₩49,000
- KR 평점 4.5 / 리뷰 2,086개

**약점/불만:**
- "AI" 이름이 무색한 낮은 정확도
- **연락처/캘린더/리마인더까지 삭제하는 치명적 버그**
- 앱 크래시 빈번 (256GB 기기에서 스캔 중 크래시)
- 과도한 권한 요청 (캘린더, 마이크, GPS)
- 고객 지원 부재
- JustUseApp 안전점수 33.3/100

**출처:** [App Store](https://apps.apple.com/us/app/ai-cleaner-clean-up-storage/id6448330325), [InsanelyMac](https://www.insanelymac.com/blog/ai-cleaner-clean-up-storage-review/), [autonomous.ai](https://www.autonomous.ai/ourblog/ai-cleaner-app-review), [CleanMyMac](https://cleanmymac.com/blog/ai-cleaner-clean-up-storage-review)

---

### 4. Cleaner Guru — Clean Up Storage

| 항목 | 내용 |
|------|------|
| 개발사 | GM UniverseApps Limited (키프로스, 2019년 설립) |
| 평점 / 리뷰 | 4.5 / ~139K (Trustpilot 2.7/5, 4건 중 75% 1점) |
| 월 매출 | $4~6M (소스별 편차) |
| 다운로드 | 월 80~100만 |
| 앱 크기 | 124.8MB, iOS 16.0+ |

**자동 분석 기능:**
- 유사 사진, 라이브포토, 스크린샷, 대용량 파일, 비디오, 중복 연락처
- **흐린 사진 감지 미지원**
- **AI 카테고리 분류 미지원**
- Best Photo 90% 정확도 (단일 리뷰어, 다른 리뷰는 "부정확" 평가)
- 스캔 속도 ~30초 (테스트 앱 중 최고 수준)
- 오프라인 기능 부족 지적 있음

**정리 UX:**
- 스와이프(Tinder식) + 체크박스 병행
- Undo: 앱 내 없음 (연락처만 자동 백업)
- 배치 삭제 지원

**무료 범위:**
- 스캔 무료, **삭제 완전 유료** (무료 삭제 불가)
- 무료체험 3일/7일 (구독 옵션별 차이)

**가격 (App Store 직접 확인):**
- US: 주간 $4.99~$9.99 / 연간 $39.99
- KR: 주간 ₩6,600~₩13,500 / 연간 ₩55,000~₩66,000
- KR 평점 4.3 / 리뷰 2,400개

**약점/불만:**
- 30분간 사진 골라놓고 마지막에 페이월 ("Gotcha!" 방식)
- 구독 취소 다크패턴 ("취소" 링크 숨김, "유지" 버튼 크게)
- 연락처 전체 삭제 버그
- 다크 모드 미지원
- "약탈적 가격 책정의 iOS 클린업 앱 그룹"에 포함 (Connor Tumbleson)

**출처:** [App Store](https://apps.apple.com/us/app/cleaner-guru-clean-up-storage/id1476380919), [InsanelyMac](https://www.insanelymac.com/blog/cleaner-guru-review/), [Trustpilot](https://www.trustpilot.com/review/cleanerguru.com), [Predatory iOS Apps](https://connortumbleson.com/2025/01/13/predatory-ios-cleanup-applications/)

---

### 5. Cleaner for iPhone

> 조사 결과 정확한 이름의 독립 앱을 특정하지 못함. Cleaner Guru와 중복 가능성 높음. 추가 확인 필요.

---

### 6. Cleaner Neat — Clean Up Storage

| 항목 | 내용 |
|------|------|
| 개발사 | Smart Tool Studio (태국) |
| 구 이름 | Phone Cleaner・AI Clean Storage → Cleaner Neat으로 리브랜딩 |
| 평점 / 리뷰 | US: 4.6 / ~114K, KR: 4.2 / 717개 |
| 앱 크기 | 198.1MB, iOS 14+ |

**자동 분석 기능:**
- 유사 사진, 중복, 유사 Live Photos, 버스트, 스크린샷, 유사 비디오, 대용량
- 연락처 중복 병합, 비디오 압축, Private Vault(PIN 보호), AI 사진 보정
- **흐린 사진 감지 불확실** (공식 미명시)
- Best Photo 선택 정확도 **~10%** (테스트 앱 중 최악)
- AI 표방하나 실제 정확도 매우 낮음

**정리 UX:**
- 체크박스 방식 (스와이프 미지원)
- **자동 선택 강제 문제**: 전체 해제해도 스캔 계속되면서 다시 자동 선택
- 스캔 중 앱 이탈/화면 꺼짐 시 처음부터 다시
- Undo 없음

**무료 범위:**
- 스캔 무료, 광고당 20장 삭제
- 무료체험 3일

**가격 (App Store 직접 확인):**
- US: 주간 $1.99~$6.99 / 월간 $9.99 / 연간 $29.99 / 평생 $39.99~$59.99
- KR: 주간 ₩4,400~₩9,900 / 월간 ₩13,500 / 연간 ₩27,000 / 평생 ₩55,000~₩88,000
- KR 평점 4.2 / 리뷰 717개

**약점/불만:**
- Best Photo 10% 정확도
- 스캔 안정성 문제 (이탈 시 리셋)
- 스와이프 미지원
- 비디오 압축 시 크래시 보고
- 리뷰어 종합 3.2/5 (InsanelyMac)

**출처:** [App Store](https://apps.apple.com/us/app/cleaner-neat-clean-up-storage/id1463756032), [InsanelyMac](https://www.insanelymac.com/blog/phone-cleaner-ai-clean-storage-review/), [MacGasm](https://news.macgasm.net/reviews/cleaner-neat-for-iphone-review/)

---

### 7. CleanMyPhone (MacPaw)

| 항목 | 내용 |
|------|------|
| 개발사 | MacPaw Way Ltd (우크라이나, CleanMyMac으로 유명) |
| 전신 | Gemini Photos (2018) → 2024.03 리브랜딩 |
| 평점 / 리뷰 | 4.6 / ~22K |
| 다운로드 | 700만+ |
| 앱 크기 | 171.4MB, iOS 17.0+ |
| 수상 | Red Dot Award 2024 + UX Design Awards 2024 |

**자동 분석 기능:**
- **Declutter 모듈**: 중복, 유사, 흐린, 스크린샷, 화면녹화, 대용량비디오, 라이브포토
- **Organize 모듈**: AI 카테고리 분류 (Portraits, Travel, Pets, Food, Text, Other)
- 커스텀 ML 모델 (자체 제작), 완전 온디바이스
- Gemini Photos 대비 분석 속도 2배 향상
- 정확도 혼재: 중복/유사는 괜찮으나 "145GB에서 흐린/스크린샷만 찾고 유사사진 많이 놓침"
- **흐림 오탐 패턴**: 포트레이트 모드(보케)→흐림, 하늘/구름→흐림, 안개/해무→흐림으로 오판 (MacStories, Setapp 리뷰)

**정리 UX:**
- 체크박스 (AI 자동 pre-select) + 스와이프 모드 (2025.12 v2.11.0 추가)
- **광고 없음** (경쟁앱 중 유일)
- Undo: 앱 내 없음, iOS "최근 삭제" 의존
- 배치 삭제, 라이브포토 일괄 변환(최대 100장), 비디오 압축 지원

**무료 범위 (카테고리 제한 방식):**
- Declutter: 스크린샷 + 대용량 비디오만 무료 (중복/유사/흐림은 유료)
- Organize: Other 카테고리만 무료
- Health: 전체 무료

**가격 (App Store 직접 확인):**
- US: 월간 $2.99~$7.99 / 6개월 $36.99 / 연간 $19.99~$39.99 / 무제한 $34.99
- KR: 월간 ₩3,900~₩11,000 / 6개월 ₩55,000 / 연간 ₩27,000~₩55,000
- 무료체험 3일 (Setapp 경유 시 7일)
- KR 평점 4.0 / 리뷰 352개
- (Gemini Photos 레거시 가격도 App Store에 잔존)

**약점/불만:**
- 무료 범위 극단적 제한
- "CleanMyPhone인데 사진만 정리" — 이름과 기능 괴리
- Gemini Photos 대비 기능 퇴보 불만
- 체크박스 선택 시 랙 발생
- 리뷰어 종합 3.6/5: "프리미엄처럼 보이지만 프리미엄처럼 정리하지 못한다"

**출처:** [App Store](https://apps.apple.com/us/app/cleanmy-phone-cleanup-storage/id1277110040), [MacPaw 공식](https://macpaw.com/cleanmyphone), [InsanelyMac](https://www.insanelymac.com/blog/cleanmyphone-review/), [UX Design Awards](https://ux-design-awards.com/winners/2024-2-cleanmyphone-by-macpaw)

---

### 8. Slidebox — Photo Cleaner App

| 항목 | 내용 |
|------|------|
| 개발사 | Slidebox LLC (미국 워싱턴주, 2015년 설립, 설립자 Jiho Park) |
| 평점 / 리뷰 | US: **4.8** / 15,609개, KR: **4.8** / 24,005개 |
| 앱 크기 | **35.2MB** (최경량) |
| iOS 15.0+, visionOS 1.0+ |

**자동 분석 기능:**
- **없음** — AI/ML 사용하지 않음
- 흐린/유사/중복/스크린샷 자동 감지 전무
- "Compare Similar Photos" 표방하나 실제로는 수동 비교만
- 100% 수동 정리 앱

**정리 UX:**
- **스와이프 전문**: 위=삭제, 아래=즐겨찾기, 좌우=탐색, 앨범탭=분류
- **Undo 있음** (경쟁앱 중 유일하게 확인)
- 월별 사진 탐색, "Unsorted" 앨범 개념
- iOS Photos + iCloud 실시간 동기화

**무료 범위:**
- 삭제 장수 제한 없음 (관대)
- 20장마다 광고 1회
- 무료체험 기간 없음

**가격 (App Store 직접 확인):**
- US: 주간 $1.99 / 월간 $4.99 / 연간 $19.99~$49.99 / **일회성 $19.99**
- KR: 주간 ₩3,300 / 월간 ₩6,000 / 연간 ₩29,000~₩61,000 / **일회성 ₩29,000**
- KR 평점 4.8 / 리뷰 24,005개 (한국에서 리뷰 수 1위)

**약점/불만:**
- **진행 상황 리셋**: 앱 나갔다 오면 처음부터 다시
- 광고 닫기 불가 버그
- 중복 감지 기능 과대광고 (자동 탐지 없음)
- ~~비디오 미지원~~ → 2025.04 (v3.12.0) 비디오 정리 추가 (프리미엄 전용)
- 배치 처리 불편
- Editors' Choice 수상

**출처:** [App Store](https://apps.apple.com/us/app/slidebox-photo-cleaner-app/id984305203), [Slidebox 공식](https://slidebox.co/), [AppGrooves](https://appgrooves.com/app/slidebox-photo-and-album-manager-by-slidebox-llc/negative)

---

### 9. 클리너: 저장공간을 정리하고 최적화합니다 (Phone Cleaner Storage Cleanup)

| 항목 | 내용 |
|------|------|
| 개발사 | CoinCup OU (에스토니아, 앱 2개만 운영) |
| 평점 / 리뷰 | 4.5 / 한국 208개, 미국 6,483개 |
| 앱 크기 | 104.1MB, iOS 15.0+ |

**자동 분석 기능:**
- 중복 사진, 유사 사진, 중복 동영상, 중복 연락처
- 스크린샷/흐림/라이브포토 별도 감지 미확인
- AI/ML 미사용 추정 (기본 해시/PhotoKit API 기반)
- **삭제 전 프리뷰 부족** (카테고리명+숫자만 표시)

**정리 UX:**
- 체크박스 방식, 스와이프 아님
- Undo 없음
- "배터리 절약/RAM 정리/캐시 삭제" 등 **iOS에서 기술적으로 불가능한 기능을 과장 광고**

**무료 범위:**
- 스캔 무료, 삭제 시 페이월
- 무료체험 3일

**가격 (App Store 직접 확인):**
- US: 주간 $4.99~$7.99 / 월간 $12.99 / 연간 $49.99
- KR: 주간 ₩6,600~₩11,000 / 월간 ₩14,000 / 평생 ₩29,000~₩66,000
- KR 평점 4.5 / 리뷰 208개

**약점/불만:**
- iOS 불가능 기능 과장 광고
- 프리뷰 없이 삭제 → 중요 사진 손실 사례
- 프라이버시 우려 (사진 수집 가능 명시, Facebook/AppsFlyer/Branch Metrics 트래커)
- **리뷰 조작 강력 의심**: 6,483개 리뷰 중 1점이 4,749개(73.3%) → 단순 평균 ~1.7점인데 표시 평점 4.5

**출처:** [App Store KR](https://apps.apple.com/kr/app/id1659844441), [Predatory iOS Apps](https://connortumbleson.com/2025/01/13/predatory-ios-cleanup-applications/)

---

### 10. 사진청소기 — 사진정리, 클린업 (Cleansmith: Photo Cleaner)

| 항목 | 내용 |
|------|------|
| 개발사 | Monocraft |
| 출시 | 2014년 (오래된 앱) |
| 평점 / 리뷰 | US: 4.7 / 4,044개, KR: 4.6 / 5,800개 |
| 앱 크기 | 90.7MB, iOS 16.0+ |
| 특이사항 | App Store Featured 선정 (2020~2023, 최대 118개국), 167개국 서비스, 24개 언어 |

**자동 분석 기능:**
- 중복, 유사, 유사 비디오, 대용량, **눈 감은 사진**, 저해상도, 스크린샷, 셀카, 버스트, 라이브포토
- **날짜/위치 기반 유사 검색** (GPS 메타데이터 활용)
- **눈 감은 사진 감지** — 다른 앱에서 잘 안 보이는 기능
- AI Magic Eraser (객체 제거) 기능 보유
- 100% 온디바이스 (오프라인 작동 명시)
- 흐린 사진 감지는 명시적 언급 없음

**정리 UX:**
- 체크박스 방식 (스와이프 아님)
- "한 번의 탭으로 정리" 기능
- Undo 없음
- 압축 기능 (최대 95% 용량 절감 주장)

**무료 범위:**
- 기본 기능 부분 무료, 핵심 기능 유료
- 무료체험 3일

**가격 (App Store 직접 확인):**
- US: $1.99~$7.99 (주간/월간 추정) / $22.99~$29.99 (연간 추정)
- KR: ₩2,900~₩9,900 (주간/월간 추정) / ₩27,000~₩44,000 (연간 추정)
- KR 평점 4.6 / 리뷰 5,800개

**약점/불만:**
- 페이월 구조
- 주간 구독 가격 거부감
- 비디오 압축 버그
- 개발사 형식적 답변

**출처:** [App Store KR](https://apps.apple.com/kr/app/id926090192), [Photo Cleaner 공식](https://photocleanerapp.com/)

---

## Feature Matrix (비교표)

| 기능 | CleanerKit | Cleanup | AICleaner | CleanerGuru | CleanerNeat | CleanMyPhone | Slidebox | 클리너 | 사진청소기 | Boost | 클린업 | SmartCl | **Clever** | AIMax |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **흐림** | O | O | O(98%오탐) | X | ? | O | X | X | ? | X | X | ? | X | X |
| **유사** | O | O | O(90%실패) | O | O(10%) | O | X | O | O | O | O | O | **O(95%)** | O |
| **중복** | O | O | O(87%) | O | O | O | X | O | O | O | O | O | O | O |
| **스크린샷** | O | O | O | O | O | O | X | ? | O | O | O | ? | O | O |
| **라이브포토** | O | X | X | O | O | O | X | X | O | O | X | X | O | O |
| **AI카테고리** | O(14) | X | X | X | X | O(6) | X | X | X | X | X | X | X | X |
| **눈감은사진** | X | X | X | X | X | X | X | X | O | X | X | X | X | X |
| **스와이프** | O | O | O(숨김) | O | X | O | O(전문) | X | X | O | O | X | **O** | X |
| **Undo** | X | X | X | X | X | X | O | X | X | X | X | X | **O** | X |
| **온디바이스** | O | O(표방) | O(표방) | ? | ? | **O(확실)** | O | ? | O | O | ? | ? | **O(확실)** | ? |
| **광고없음** | X | X | X | X | X | **O** | X | X | X | X | X | X | **O** | X |
| **완전무료** | X | X | X | X | X | X | X | X | X | X | X | X | **O** | X |

## 가격 비교표 (App Store 직접 확인, 2026-03-04)

> A/B 테스트로 동일 구독에 여러 가격대 존재. App Store 상위 10개 인앱 구매만 표시되므로 일부 누락 가능.

### US App Store (USD)

| # | 앱 | 주간 | 월간 | 연간 | 평생 | 무료 삭제 | 체험 | 평점(US) | 리뷰(US) |
|---|-----|------|------|------|------|----------|------|---------|---------|
| 1 | Cleaner Kit | $4.99~$6.99 | - | - | - | 광고당 20장 | 3일 | 4.4 | 333K |
| 2 | Cleanup | $5.95~$9.99 | - | $29.99 | - | 5장+광고25장 | 7일 | 4.7 | 624K |
| 3 | AI Cleaner | $6.99~$9.99 | - | $34.99~$39.99 | - | 10~50건/일 | 3일 | 4.6 | 183K |
| 4 | Cleaner Guru | $4.99~$9.99 | - | $39.99 | - | 0 (완전유료) | 3~7일 | 4.5 | 139K |
| 6 | Cleaner Neat | $1.99~$6.99 | $9.99 | $29.99 | $39.99~$59.99 | 광고당 20장 | 3일 | 4.6 | 114K |
| 7 | CleanMyPhone | - | $2.99~$7.99 | $19.99~$39.99 | $34.99 | 카테고리 제한 | 3일 | 4.6 | 22K |
| 8 | Slidebox | $1.99 | $4.99 | $19.99~$49.99 | **$19.99** | 무제한(광고) | 없음 | **4.8** | 15.6K |
| 9 | 클리너(CoinCup) | $4.99~$7.99 | $12.99 | $49.99 | - | 0 (페이월) | 3일 | 4.5 | 6.5K |
| 10 | 사진청소기 | $1.99~$7.99 | - | $22.99~$29.99 | - | 부분 무료 | 3일 | 4.7 | 4K |
| 11 | Boost Cleaner | $5.99~$6.99 | $9.99~$12.99 | $34.99~$49.99 | - | 제한적(광고) | 3일 | 4.5 | 67K |
| 12 | 클린업(AppLavia) | $4.99~$7.99 | $2.99 | $49.99 | $9.99~$19.99 | 0 (페이월) | 3일 | 4.5 | 7.9K |
| 13 | Smart Cleaner | $5.99~$9.99 | $12.99 | $19.99~$34.99 | $23.99~$39.99 | 구독 필수 | 3일 | 4.6 | 18.6K |
| 14 | **Clever Cleaner** | **무료** | **무료** | **무료** | **무료** | **무제한** | **N/A** | **4.8** | **57K** |
| 15 | AI Cleaner Max | $3.99 | $7.99 | $24.99 | - | 제한적 | 3일 | 3.9 | 1.9K |

### KR App Store (₩ 원)

| # | 앱 | 주간 | 월간 | 연간 | 평생 | 평점(KR) | 리뷰(KR) |
|---|-----|------|------|------|------|---------|---------|
| 1 | Cleaner Kit | ₩7,700~₩14,000 | - | - | - | 4.2 | 8,240 |
| 2 | Cleanup | ₩4,400~₩14,000 | - | ₩33,000 | - | 4.6 | 4,100 |
| 3 | AI Cleaner | ₩9,900~₩14,000 | ₩14,000 | ₩44,000~₩49,000 | - | 4.5 | 2,086 |
| 4 | Cleaner Guru | ₩6,600~₩13,500 | - | ₩55,000~₩66,000 | - | 4.3 | 2,400 |
| 6 | Cleaner Neat | ₩4,400~₩9,900 | ₩13,500 | ₩27,000 | ₩55,000~₩88,000 | 4.2 | 717 |
| 7 | CleanMyPhone | - | ₩3,900~₩11,000 | ₩27,000~₩55,000 | - | 4.0 | 352 |
| 8 | Slidebox | ₩3,300 | ₩6,000 | ₩29,000~₩61,000 | **₩29,000** | **4.8** | **24,005** |
| 9 | 클리너(CoinCup) | ₩6,600~₩11,000 | ₩14,000 | - | ₩29,000~₩66,000 | 4.5 | 208 |
| 10 | 사진청소기 | ₩2,900~₩9,900 | - | ₩27,000~₩44,000 | - | 4.6 | 5,800 |
| 11 | Boost Cleaner | ₩8,800~₩12,000 | ₩13,500~₩19,000 | ₩44,000~₩66,000 | - | 4.5 | 414 |
| 12 | 클린업(AppLavia) | ₩6,500~₩10,500 | ₩4,000 | ₩66,000 | ₩14,000~₩29,000 | 3.9 | 28 |
| 13 | Smart Cleaner | ₩8,800~₩14,000 | ₩19,000 | ₩29,000~₩49,000 | ₩33,000~₩55,000 | 4.4 | 9 |
| 14 | **Clever Cleaner** | **무료** | **무료** | **무료** | **무료** | **4.9** | **358** |
| 15 | AI Cleaner Max | ₩5,500 | ₩11,000 | ₩33,000 | - | 4.3 | 49 |

### 가격 패턴 요약 (App Store 직접 확인 기준)

- **주간 구독 중앙값**: US $5.99~$7.99 / KR ₩8,800~₩11,000 (연 환산 $312~$416 / ₩457,600~₩572,000)
- **연간 구독 범위**: US $19.99~$49.99 / KR ₩27,000~₩66,000
- **평생 구매 제공**: 14개 유료 앱 중 6개 (43%)
- **완전 무료**: Clever Cleaner 1개뿐
- **한국 리뷰 수 TOP3**: Slidebox (24K) > Cleaner Kit (8.2K) > 사진청소기 (5.8K)

---

### 11. Boost Cleaner — Clean Up Smart

| 항목 | 내용 |
|------|------|
| 개발사 | CELESTIAN GOLDEN APPS SL (스페인 마드리드, 2023년 설립). 전 퍼블리셔: SCI BRONZE FILMS LIMITED |
| 출시 | 2019년 8월 |
| 평점 / 리뷰 | US: 4.5 / ~67K, KR: 4.5 / 414개 |
| 월 매출 | ~$5K~$16K (Sensor Tower/Adapty 추정, 2023년 대비 급감) |
| 앱 크기 | 155.7MB, iOS 15.0+ |
| 최신 버전 | v4.5.0 (2025.08), 연 2~3회 업데이트 (최소 유지보수) |

**자동 분석 기능:**
- 중복, 유사 사진, 라이브포토, GIF, 스크린샷, 대용량, 중복 비디오
- **위치/날짜 기반 필터링** (GPS 메타데이터 활용)
- 연락처 중복 병합, 캘린더 정리, 사진/비디오 압축, Secret Vault (PIN 보호), 네트워크 속도 테스트
- **흐린 사진 감지 미지원** (App Store 설명 및 리뷰 전수 확인)
- AI 명시하지 않음
- 사진 데이터 온디바이스 표방, 단 App Store 프라이버시 라벨 "Data Used to Track You" 존재 (Adapty 등)

**정리 UX:**
- 스와이프(좌=삭제/우=보관) + 체크박스 병행 + 원탭 정리
- Undo 없음

**무료 범위:**
- 스캔 무료, 삭제 제한 (광고 시청 시 일부 가능, 무료는 사진당 3단계 수동 작업)
- 무료체험 3일, 결제카드 등록 필수

**가격 (App Store 직접 확인):**
- US: 주간 $5.99~$6.99 / 월간 $9.99~$12.99 / 연간 $34.99~$49.99
- KR: 주간 ₩8,800~₩12,000 / 월간 ₩13,500~₩19,000 / 연간 ₩44,000~₩66,000
- 일회성 구매 없음
- KR 평점 4.5 / 리뷰 414개

**약점/불만:**
- 공격적 구독 유도, 앱 실행 즉시 광고 노출, 광고 닫기 불가 (X 버튼 없음)
- 중복 감지 정확도 부족 ("awful at recognizing duplicates")
- 스캔 후 재정리 시 스톨링, 중복 삭제 시 앱 크래시
- "Rate Us" 팝업 무한 반복, 스토어 스크린샷과 실제 UI 불일치
- JustUseApp 안전점수 66.5/100, 부정경험 26.7%

**출처:** [App Store](https://apps.apple.com/us/app/boost-cleaner-clean-up-smart/id1475887456), [JustUseApp](https://justuseapp.com/en/app/1475887456/boost-cleaner-clean-storage/reviews), [Setapp](https://setapp.com/app-reviews/best-iphone-cleaner-apps)

---

### 12. 클린업: 청소 중복사진 및 (Cleaner: Free Up Storage Guru)

| 항목 | 내용 |
|------|------|
| 개발사 | Cleaner LLC (AppLavia LLC), Cleaner LLC 명의 7개 앱 / AppLavia 전체 25개+ 포트폴리오. 소재지 불투명(방글라데시/말레이시아/미국 혼재) |
| 평점 / 리뷰 | US: 4.5 / ~7.9K, KR: 3.9 / 28개 |
| 앱 크기 | 93.5MB, iOS 13.0+ |
| 최신 버전 | v1.4.7 (2025.02.13), 이후 1년+ 업데이트 없음 |
| **Codeway의 Cleanup, GM UniverseApps의 Cleaner Guru 모두와 완전히 별개의 앱 (이름 유사 삼중 혼동 주의)** |

**자동 분석 기능:**
- 유사/중복, 유사 스크린샷, 대용량 비디오, 연락처 (셀카/버스트 별도 카테고리 미확인)
- Secret Space (PIN 보호), 캘린더 정리, 충전 애니메이션, 비디오 압축
- Best Photo 선택 기능: 대부분 적절히 선택 (리뷰어 평가). "90%" 수치의 공식 출처 없음, 체감 추정치
- 스캔 ~30초

**정리 UX:**
- 스와이프 삭제 지원 (좌=삭제, 우=유지, 월별 슬라이드쇼 방식) + Easy Clean 원탭 + 체크박스
- Undo 없음

**무료 범위:**
- 스캔 무료, **삭제 완전 유료** (페이월)
- 무료체험 3일

**가격 (App Store 직접 확인):**
- US: 주간 $4.99~$7.99 / 월간 $2.99 / 연간 $49.99 / 평생 $9.99~$19.99
- KR: 주간 ₩6,500~₩10,500 / 월간 ₩4,000 / 연간 ₩66,000 / 평생 ₩14,000~₩29,000
- KR 평점 3.9 / 리뷰 28개

**약점/불만:**
- 다크패턴 페이월, 연락처 오삭제, 프라이버시 우려
- 앱 크래시, 유사사진 오판 삭제, 무료체험 카드 강제 입력, 이중 청구 사례 보고
- App Store 프라이버시 라벨 추적 명시 (식별자/구매이력/연락처 등 수집)
- JustUseApp 안전점수 34.5/100

**출처:** [App Store KR](https://apps.apple.com/kr/app/id1521796505), [JustUseApp](https://justuseapp.com/en/app/1521796505/cleaner-free-up-storage-guru/reviews)

---

### 13. Smart Cleaner

> "Smart Cleaner" 이름의 앱이 최소 3개 존재. BPMobile의 Cleaner Kit(1번)이 구 Smart Cleaner로 리브랜딩된 것.

**NAICOO의 Smart Cleaner: Free Up Storage:**

| 항목 | 내용 |
|------|------|
| 개발사 | NAICOO PTE. LTD. (싱가포르). 다른 앱: AllScan(QR Reader), Boost Cleaner: Freeup Storage (**11번 Boost Cleaner(CELESTIAN)와 완전 별개**) |
| 평점 / 리뷰 | US: 4.6 / ~18.6K, KR: 4.4 / 9개 |
| 앱 크기 | 121.8MB, iOS 14.0+ |
| 최신 버전 | v1.7.2 (2026.01.15, 활발 유지) |
| JustUseApp 안전점수 | 20.9/100, 부정경험 79.1% |

- Fast/Deep Clean, 중복/유사 감지, 파일 압축, 이메일 정리(스팸 필터링), 캘린더 관리, 연락처 병합, 속도 테스트
- **저품질 감지**: 흐림/AI/스와이프 미확인
- 트래커: AdMob, Facebook, Firebase 확인. 설치 앱 목록 수집, 삭제 후 데이터 보존
- US: 주간 $5.99~$9.99 / 월간 $12.99 / 연간 $19.99~$34.99 / 평생 $23.99~$39.99
- KR: 주간 ₩8,800~₩14,000 / 월간 ₩19,000 / 연간 ₩29,000~₩49,000 / 평생 ₩33,000~₩55,000
- KR 평점 4.4 / 리뷰 9개
- 3일 체험, 삭제 구독 필수
- 불만: 비중복 파일 중복 분류, 구독 취소 어려움, 저장공간 실효성 낮음

**Skyrocket의 Smart Cleaner: Storage Clean Up:**

| 항목 | 내용 |
|------|------|
| 개발사 | Skyrocket Apps Limited (영국 런던 등록(가상 주소), 실제 베를린 운영 추정. 11개 앱 대량 퍼블리싱) |
| 평점 / 리뷰 | 4.4 / ~10K |
| 앱 크기 | 248.5MB, iOS 14.0+ |
| 최신 버전 | v8.6.21 (2025.03), **약 1년 미업데이트 (방치 의심)** |
| JustUseApp 안전점수 | **0/100**, 부정경험 **100%** |

- **저품질 감지**: 흐림 + 눈감음 + 나쁜 각도 감지 명시 (App Store 설명). 독립 정확도 테스트 없음, 사용자 오탐 불만 존재
- WhatsApp/Telegram 캐시 정리, 배터리 최적화, 속도 테스트, 연락처/캘린더
- US: 주간 $3.99~$4.99 / 월간 $10.99 / 연간 $19.99 / 평생 $49.99
- 프라이버시 라벨 "Data Not Collected" 표시이나 실제 광범위 접근 권한 요청 (불일치 의심)
- **치명적 불만**: 자녀 사진 전부 삭제 복구불가 사례, 연락처 오병합, 기능 미작동(8,117 스크린샷 중 0 감지), 3분 작동 후 크래시
- 일회성 구매($49.99)에서 주간 구독($4.99/주)으로 변경, 리뷰 봇 의심
- 카테고리 내 신뢰도 최하위

**출처:** [App Store NAICOO](https://apps.apple.com/us/app/smart-cleaner-free-up-storage/id6448222268), [App Store Skyrocket](https://apps.apple.com/us/app/smart-cleaner-storage-clean-up/id1472524442), [JustUseApp NAICOO](https://justuseapp.com/en/app/6448222268/smart-cleaner-free-up-storage/reviews), [JustUseApp Skyrocket](https://justuseapp.com/en/app/1472524442/smart-cleaner-fastest-clean/reviews)

---

### 14. Clever Cleaner — AI CleanUp App

| 항목 | 내용 |
|------|------|
| 개발사 | CleverFiles Inc. (법인명: 508 Software LLC, Disk Drill 개발사, 미국 버지니아, 2009년 설립, 연 $18M 매출 추정(RocketReach/ZoomInfo 제3자 추정치), 직원 21~28명) |
| 평점 / 리뷰 | US: **4.8** / ~57K, KR: **4.9** / 358개 |
| 앱 크기 | 112.7MB, iOS 16.0+ |
| 앱 출시 | 2025년 2월경, 현재 v2.4 (2026.02.09), 활발한 업데이트 |
| **완전 무료 + 광고 없음 + 인앱 결제 없음** |

**자동 분석 기능:**
- 유사/중복 사진, 스크린샷, 대용량(Heavies), 라이브포토, 비디오 압축
- AI 기반 유사 사진 그룹핑 **~95% 정확도** (InsanelyMac 독립 리뷰 테스트 기준, 자체 공식 수치 아님)
- 흐린 사진 별도 탭 없음, 유사 비디오 미지원
- **100% 온디바이스** (오프라인 동작 확인)

**정리 UX:**
- Smart Cleanup (원탭 자동) + 스와이프 모드 (좌=삭제/우=보관, 월별 그룹핑) + 체크박스
- **Side-by-side 비교 지원**
- **내부 Trash bin 존재 (Undo 가능)** — 경쟁앱 중 Slidebox와 함께 유일
- 스캔 5~20초

**무료 범위:**
- **모든 기능 완전 무료, 무제한, 광고 없음**
- 비즈니스 모델: Disk Drill 개발사의 브랜드 인지도 확장 전략 (앱 내 직접적 크로스셀링 증거는 미발견)
- "초기 사용자는 영구 무료 보장" 공식 입장 (단, "Early users" 표현은 향후 신규 사용자 대상 Pro 유료 티어 도입 가능성을 내포)

**약점:**
- 유사 비디오 미지원, 연락처/이메일/캘린더 정리 없음
- 특수 이미지(예술작품, 애니메이션) 감지 누락
- iPad 호환 모드 동작 (네이티브 최적화 아님)
- 일부 유사 사진 누락 사례 보고 (사용자 리뷰)
- Live Photo 압축 시 편집 이력 손실 가능, GIF/RAW 파일 미지원

**출처:** [App Store](https://apps.apple.com/us/app/clever-cleaner-ai-cleanup-app/id1666645584), [CleverFiles 공식](https://www.cleverfiles.com/clever-cleaner/), [InsanelyMac](https://www.insanelymac.com/blog/clever-cleaner-review/), [Sonny Dickson](https://sonnydickson.com/2025/03/18/review-clever-cleaner-for-iphone-a-truly-free-storage-cleanup-app/)

---

### 15. AI Cleaner Max — Clean Up Device

| 항목 | 내용 |
|------|------|
| 개발사 | 哲 魏 (중국 추정 개인 개발자, 유틸리티 5개+ 운영) |
| 평점 / 리뷰 | US: 3.9 / ~1.9K, KR: 4.3 / 49개 |
| 앱 크기 | 58.6MB, iOS 10.0+ (경쟁앱 대비 극단적으로 낮음 — 레거시 코드베이스) |
| **3번 AI Cleaner (GRIMLAX)와 완전히 다른 앱** |

- 구 이름: Clean Doctor → CleanerX → AI Cleaner Max (여러 차례 리브랜딩, 지역별 현재도 다른 이름 노출, 인앱에 "Clean Doctor Pro" 잔존)
- 유사/중복, 대용량, 스크린샷, 라이브포토, HDR, 버스트, 비디오
- 추가 기능: 연락처 병합, 캘린더/리마인더 정리, 프라이버시 볼트, 커스텀 위젯
- "저화질" 감지 표방하나 흐린 사진(blur) 감지 여부는 미확인 (App Store 설명에 미명시)
- 스와이프 없음, Undo 없음, 체크박스 방식
- US: 주간 $3.99 / 월간 $7.99 / 연간 $24.99
- KR: 주간 ₩5,500 / 월간 ₩11,000 / 연간 ₩33,000
- KR 평점 4.3 / 리뷰 49개
- 마지막 업데이트 2024.12.12 (v7.7), 약 15개월 경과 — 2024년에는 활발했으나 이후 중단
- JustUseApp 안전점수 **33.3/100** (부정경험 66.7%)
- 기기 식별자 기반 서드파티 추적 수집 (App Store 프라이버시 라벨)

**약점/불만:**
- 중복 감지 부정확, 삭제 전 프리뷰/확인 과정 부실 (원치 않는 사진 포함 삭제 사례, iOS "최근 삭제"로는 이동됨)
- 앱 프리징, 리브랜딩 후 기존 구매자에게 재구매 요구
- 기능 과장 (나열만 하고 실제 정리 수행 안함)

**출처:** [App Store](https://apps.apple.com/us/app/ai-cleaner-max-clean-up-device/id855008026), [JustUseApp](https://justuseapp.com/en/app/855008026/cleaner-app-clean-doctor/reviews)

---

## 공통 패턴 분석

### 1. 비즈니스 모델 패턴
- **"스캔 무료 → 삭제 페이월"** — 거의 모든 앱이 동일 구조
- **주간 구독 우선 유도** — 연 $260~$520 수준, 사용자 인지 없이 과금
- **A/B 가격 테스트** — 사용자마다 다른 가격 노출
- **고령 사용자 타겟팅** — Facebook/YouTube 광고로 구독 관리에 익숙하지 않은 층 공략

### 2. 기술적 패턴
- **"AI" 마케팅 vs 실제 정확도 괴리** — 대부분 "AI" 표방하나 Best Photo 정확도 10~90%로 편차 큼
- **온디바이스 표방 + 트래커 다수** — 사진은 업로드 안 하지만 사용자 행동 데이터는 외부 전송
- **Undo/삭제대기함 전무** — iOS 기본 "최근 삭제" 30일에 전적으로 의존

### 3. UX 패턴
- **스와이프 UX는 긍정 평가** — 있는 앱은 사용자 만족도 높음, 하지만 일부 앱에서 하위 메뉴에 숨겨짐
- **Best Photo 자동 선택** — 대부분 지원하나 정확도가 핵심 차별점
- **대규모 라이브러리에서 안정성 문제** — 크래시, 진행 리셋 등

### 4. 사용자 불만 공통 패턴
- 구독 함정 / 자동 과금
- 중요 데이터 손실 (사진, 연락처, 캘린더)
- AI 정확도 부족
- 고객 지원 부재

---

## SweepPic 차별화 포인트 (조사 기반)

| 경쟁앱 공통 약점 | SweepPic 대응 |
|----------------|-------------|
| Undo 없음 | 앱 내 삭제대기함 (30일 보관, 즉시 복구) |
| Best Photo 정확도 낮음 | Vision Framework 기반 정밀 분석 |
| 스와이프가 숨겨짐/미지원 | 스와이프 삭제가 핵심 UX (메인 화면) |
| 스캔→페이월 다크패턴 | 프리미엄 모델 투명 (무료 10회/일 + 광고 추가) |
| 주간 구독 과금 | 합리적 가격 ($2.99/월, $19.99/년) |
| 트래커 6개+ 내장 | 최소한의 분석 (광고 SDK만) |
| 연락처/캘린더 삭제 버그 | 사진 정리에만 집중 (범위 제한으로 안전성 확보) |

---

## 저품질 사진 감지 정확도 현황

> 조사일: 2026-03-05
> 목적: 사업계획서 "창업 아이템 필요성" 근거 수집
> 방법: InsanelyMac 독립 테스트, MacStories/Setapp/JustUseApp 리뷰, App Store 설명, Reddit/포럼 사용자 리포트 종합

### 1. 저품질 감지 기능 보유 현황

#### 기존 15개 앱

| # | 앱 | 흐림 | 어두움 | 과노출 | 저해상도 | 눈감음 | 포켓샷 | 비고 |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| 1 | Cleaner Kit | O | X | X | X | X | X | "Blurred Images" 별도 카테고리 |
| 2 | Cleanup | △ | X | X | X | X | X | 흐림 전용 카테고리 없음, Best Photo 초점 기준만 |
| 3 | AI Cleaner | O | X | X | X | X | X | 98.7% 오탐률 (InsanelyMac) |
| 4 | Cleaner Guru | X | X | X | X | X | X | 저품질 감지 미지원 |
| 6 | Cleaner Neat | ? | X | X | X | X | X | 공식 미명시, 미확인 |
| 7 | CleanMyPhone | O | X | X | X | X | X | Declutter 모듈 내 "흐림" 카테고리 |
| 8 | Slidebox | X | X | X | X | X | X | AI/자동 감지 전무 (수동 전용) |
| 9 | 클리너(CoinCup) | X | X | X | X | X | X | 저품질 감지 미지원 |
| 10 | 사진청소기 | ? | X | X | O | O | X | 저해상도+눈감음 감지. 흐림 미명시 |
| 11 | Boost Cleaner | X | X | X | X | X | X | 저품질 감지 미지원 |
| 12 | 클린업(AppLavia) | X | X | X | X | X | X | 저품질 감지 미지원 |
| 13 | Smart Cleaner(Skyrocket) | O | X | X | X | O | X | 흐림+눈감음+나쁜 각도 명시 |
| 13 | Smart Cleaner(NAICOO) | ? | X | X | X | X | X | 미확인 |
| 14 | Clever Cleaner | X | X | X | X | X | X | 유사/중복만, 저품질 별도 탭 없음 |
| 15 | AI Cleaner Max | ? | X | X | ? | X | X | "저화질" 표방하나 구체적 감지 방식 미확인 |

**요약**: 15개 앱 중 흐림 감지를 **명시적으로 제공**하는 앱 5개 (Cleaner Kit, AI Cleaner, CleanMyPhone, Smart Cleaner Skyrocket, Cleanup 간접). **어두움/과노출/포켓샷 감지**: 0개.

#### 추가 발견 앱 (기존 15개 외)

| 앱 | 개발사 | 흐림 | 어두움 | 과노출 | 비고 |
|---|---|:---:|:---:|:---:|---|
| **Hyper Cleaner** | Lempelto OOO | O | **O** | X | 어두움 감지를 명시한 희귀 앱 |
| **Clean.AI** | (신규) | O | **O** | X | 신규, 충분한 리뷰 데이터 없음 |
| **Blurry Photo Finder** | Inaware | O | X | X | 흐림 전용, 보수적 접근 (오탐 최소화) |
| **Magic Cleaner** | Flavor Factory | O | X | X | 독립 테스트 없음 |
| **Google Photos** | Google | O | **O** | **O** | 가장 포괄적. 단, 별도 클리너 앱 아님 |

**어두움 감지**: Hyper Cleaner, Clean.AI, Google Photos 3개만. **과노출 감지**: Google Photos 1개만 (iOS 앱 중 0개).

---

### 2. 독립 정확도 테스트 결과

#### InsanelyMac 테스트 (실제 iPhone, 실제 라이브러리)

| 앱 | 테스트 항목 | 정확도 | 상세 |
|---|---|---|---|
| **AI Cleaner** | 흐림 감지 | **1.3%** (79장 중 1장만 실제 흐림) | 오탐률 98.7%. 사실상 사용 불가 |
| **AI Cleaner** | 유사 사진 (비인물) | **10%** | 90% 무관한 사진을 같은 그룹 |
| **AI Cleaner** | Best Photo | **10%** | 90% 확률로 잘못된 사진 선택 |
| **Cleaner Kit** | Best Photo | **95%** | 조명/초점/구도 기준. 최상위 |
| **Clever Cleaner** | 유사 그룹핑 | **95%** | 최상위. 흐림 감지는 미지원 |
| **Cleanup** | 유사 그룹핑 | **낮음** (수치 미공개) | "완전히 다른 이미지를 같은 카테고리" |
| **Cleanup** | Best Photo | **낮음** | "눈 감은/어색한 표정/나쁜 조명 사진을 best로 선택" |
| **Cleaner Neat** | 유사 그룹핑 | **~60%** | 2~3그룹마다 1개 오류 |
| **Cleaner Neat** | Best Photo | **~10%** | 테스트 앱 중 최악 |
| **CleanMyPhone** | 전체 | **수치 미공개** | "일부 그룹 부정확" — 정량 평가 없음 |

> InsanelyMac 테스트 한계: 앱마다 다른 기기/데이터셋 사용. 동일 테스트 세트로 비교한 것이 아님.

#### 기타 독립 출처

| 출처 | 앱/도구 | 결과 |
|---|---|---|
| **Topaz Labs 공식** | Topaz Photo AI (프로 데스크톱) | 블러 라벨링 정확도 55% → 69% (개선 후에도 낮음) |
| **DPReview** | Aftershoot (프로 컬링) | 블러 감지 "hit-and-miss". 인물은 비교적 정확, 비인물에서 오류 증가 |
| **MacStories** | CleanMyPhone | 포트레이트 모드/하늘/안개 오판. "알고리즘을 믿고 전부 삭제했다면 실제 사진을 잃었을 것" |
| **Autonomous.ai** | AI Cleaner | 정확 중복 87%, 유사 매칭 73% (8,500장 테스트) |
| **학술 연구** | SVM 블러 분류기 | 1,000장 테스트 93.8% 정확도 (통제 환경, 실사용 대비 과대) |

---

### 3. 오탐(False Positive) 패턴 분석

| 오탐 유형 | 설명 | 해당 앱 | 출처 |
|----------|------|--------|------|
| **포트레이트 → 흐림** | 보케(배경 흐림) 효과를 저품질 흐림으로 오판 | CleanMyPhone | MacStories, Setapp |
| **하늘/구름 → 흐림** | 하늘이 주를 이루는 사진을 흐림으로 분류 | CleanMyPhone | MacStories |
| **안개/해무 → 흐림** | 안개 낀 풍경을 흐림으로 분류 | CleanMyPhone | Setapp 리뷰 |
| **저조도 → 흐림** | 조명이 약간 부족한 사진을 전부 흐림으로 분류 | AI Cleaner | Macgasm 리뷰 |
| **HDR → 블러** | HDR 사진을 삭제 대상으로 분류 | CleanMyPhone | Setapp 사용자 리뷰 |
| **역전 (흐림 유지)** | 흐린 사진을 best로 선택, 선명한 사진을 삭제 추천 | Cleanup | JustUseApp, InsanelyMac |
| **비관련 매칭** | 새와 고양이 사진을 "유사"로 그룹화 | Cleanup | JustUseApp (리뷰어 Valeord) |
| **눈감음 선택** | 눈 감은 사진을 Best Photo로 선택 | Cleanup, Cleaner Neat | InsanelyMac |
| **미탐 (False Negative)** | 24,000장 중 ~300장만 흐림 감지 — 수동 확인 시 더 많은 흐림 사진 발견. "일부만 식별" | CleanMyPhone | MacStories, Setapp |
| **미탐 (유사)** | 유사/중복 사진 상당수를 감지하지 못함. "여러 유사 또는 중복 사진이 미감지" | Clever Cleaner | InsanelyMac, JustUseApp |

---

### 4. 업계 공통 결론

**모든 독립 리뷰어의 공통 권고**: "자동 정리 결과를 그대로 믿고 삭제하면 안 된다. 수동 검토 필수."

**Apple Community 포럼 (Level 10 사용자 MrHoffman)**: "I don't trust AI or some app to not trash my photos."

**Canon PHIL 사례**: Canon이 자체 컴퓨터 비전 엔진(PHIL)으로 사진 품질 평가 앱(선명도+노이즈+감정+눈감김 4축 평가)을 출시했으나, 2023년 3월 App Store에서 철수. 대기업의 전용 기술로도 상용화에 실패한 사례. (출처: [DPReview](https://www.dpreview.com/news/0301330122/canon-photo-culling-is-a-new-ios-app-that-uses-artificial-intelligence-to-evaluate-your-photos))

**정량 요약**:
- 흐림 감지를 명시적으로 제공하는 iOS 앱: **5개** (기존 15개 중)
- 그 중 독립 정확도 테스트가 존재하는 앱: **1개** (AI Cleaner — 98.7% 오탐)
- 어두움/과노출/포켓샷 감지를 제공하는 iOS 전용 앱: **0개** (Google Photos 제외)
- 프로 도구(Topaz, Aftershoot)조차 블러 감지 정확도: **55~69%**
- **표준화된 업계 벤치마크**: 존재하지 않음

---

### 5. 출처 목록

- [InsanelyMac - AI Cleaner Review](https://www.insanelymac.com/blog/ai-cleaner-clean-up-storage-review/)
- [InsanelyMac - Cleaner Kit Review](https://www.insanelymac.com/blog/cleaner-kit-clean-up-storage-review/)
- [InsanelyMac - Clever Cleaner Review](https://www.insanelymac.com/blog/clever-cleaner-review/)
- [InsanelyMac - CleanMyPhone Review](https://www.insanelymac.com/blog/cleanmyphone-review/)
- [InsanelyMac - Cleanup Review](https://www.insanelymac.com/blog/cleanup-phone-storage-cleaner-review/)
- [InsanelyMac - Cleaner Neat Review](https://www.insanelymac.com/blog/phone-cleaner-ai-clean-storage-review/)
- [MacStories - Gemini Photos Review](https://www.macstories.net/reviews/gemini-photos-declutters-your-photo-library/)
- [Setapp - CleanMyPhone Customer Reviews](https://setapp.com/apps/cleanmyphone/customer-reviews)
- [JustUseApp - Cleanup Reviews](https://justuseapp.com/en/app/1510944943/cleanup-phone-storage-cleaner/reviews)
- [Autonomous.ai - AI Cleaner Review](https://www.autonomous.ai/ourblog/ai-cleaner-app-review)
- [Topaz Labs - Photo AI v1.1.5](https://www.topazlabs.com/learn/topaz-photo-ai-v1-1-5)
- [DPReview - Aftershoot Review](https://www.dpreview.com/articles/4050238990/aftershoot-pro-review-the-promise-of-an-ai-assistant-who-ll-take-away-all-the-gruntwork)
- [Connor Tumbleson - Predatory iOS Cleanup Apps](https://connortumbleson.com/2025/01/13/predatory-ios-cleanup-applications/)
- [Surfshark - Phone Cleaner Apps Research](https://surfshark.com/research/chart/phone-cleaner-apps)
- [Apple Community - Cleaner App Discussion](https://discussions.apple.com/thread/255912258)
