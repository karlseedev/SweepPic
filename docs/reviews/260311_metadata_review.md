**판정**
현재 초안은 기본 골격은 좋지만, 이 상태만으로는 심사 통과 “충분”하다고 보기 어렵습니다.  
`2.3.7`은 대체로 양호하고, 핵심 리스크는 `3.1.2`/`5.1.1`입니다.

**Findings (심각도 순)**
1. **High - 5.1.1(정확한 개인정보 고지) 리스크**
- 문제: “사진 데이터는 외부 서버로 전송되지 않습니다” 같은 절대 표현은, 광고 SDK/분석 SDK가 있는 경우 심사자가 오해하거나 모순으로 볼 수 있습니다.
- 위치: [Metadata.md:55](/Users/karl/Project/Photos/iOS/docs/appstore/document/Metadata.md:55), [Metadata.md:60](/Users/karl/Project/Photos/iOS/docs/appstore/document/Metadata.md:60)
- 권장: “사진 **이미지 자체**는 서버로 전송하지 않음”처럼 범위를 명확히 하고, App Privacy(영양성분표)와 1:1 일치시키세요.

2. **High - 3.1.2(c) 구독 안내 명확성 보강 필요**
- 문제: 구독 가치 설명은 있으나, 가격/청구 조건 안내가 메타데이터에서 다소 약합니다.
- 위치: [Metadata.md:63](/Users/karl/Project/Photos/iOS/docs/appstore/document/Metadata.md:63)~[Metadata.md:70](/Users/karl/Project/Photos/iOS/docs/appstore/document/Metadata.md:70)
- 권장: 설명문에 “가격은 앱 내 결제 화면에 표시되며 국가/통화별로 다를 수 있음” 문구 추가. 무료체험이 항상 제공되지 않는다면 해당 문구는 조건부로 바꾸세요.

3. **Medium - 2.3.7(정확한 메타데이터) 관점의 과장/오해 가능성**
- 문제: “지금 무료로 시작하세요”는 실제 무료 사용 범위가 제한적이므로 오해 소지가 있습니다.
- 위치: [Metadata.md:32](/Users/karl/Project/Photos/iOS/docs/appstore/document/Metadata.md:32), [Metadata.md:59](/Users/karl/Project/Photos/iOS/docs/appstore/document/Metadata.md:59)
- 권장: “기본 기능 무료, 추가 삭제는 광고 시청 또는 Plus 구독”처럼 즉시 명확화.

4. **Medium - 제출 완성도 관점의 누락 가능성**
- 문제: 이 문서엔 App Privacy 답변, ATT 필요 여부, 심사용 메모(광고/구독 동작 설명) 등이 없습니다.
- 영향: 문서 자체 문제라기보다, 실제 제출 시 `5.1.1`/결제 심사에서 자주 막히는 포인트입니다.
- 권장: App Store Connect의 Privacy, Tracking, Review Notes까지 함께 준비하세요.

**좋은 점 (유지 권장)**
- 제목/부제/키워드 스팸성 낮고 `2.3.7` 취지에 대체로 부합.
- 길이 제한 충족: Subtitle 17자, Promo 76자, 키워드(ko 49 / en 76자), 설명 4,000자 이내.

**결론**
- 현재 상태: **조건부 통과 가능**, 하지만 `3.1.2`/`5.1.1` 보강 없이 제출하면 리젝 가능성이 있습니다.
- 위 1~3번 문구 보완 + App Privacy/ATT/Review Notes 정합성까지 맞추면 심사 안정성이 크게 올라갑니다.

**참고한 원문**
- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple Subscriptions 안내(구독 고지/링크 관련): https://developer.apple.com/app-store/subscriptions/