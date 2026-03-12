# SweepPic 연령 등급 설문 답변 가이드

> App Store Connect에서 그대로 입력하면 됩니다
> 마감: 2026년 1월 31일 (미응답 시 업데이트 제출 차단)

---

## 예상 결과: 4+ (전체이용가)

---

## A. In-App Controls (앱 내 제어)

| 질문 | 답변 | 이유 |
|------|------|------|
| Parental Controls | **No** | 보호자 통제 기능 없음 |
| Age Assurance | **No** | 연령 확인 메커니즘 없음 |

## B. Capabilities (기능)

| 질문 | 답변 | 이유 |
|------|------|------|
| Unrestricted Web Access | **No** | 웹 브라우저 기능 없음 |
| User-Generated Content | **No** | 사용자 콘텐츠를 배포하지 않음 (자기 사진만 열람) |
| Messaging and Chat | **No** | 채팅/메시징 기능 없음 |
| **Advertising** | **Yes** | Google AdMob (배너/리워드/전면 광고) 포함 |

> Advertising = Yes 시 App Store 제품 페이지에 "광고 포함" 표시됨

## C. Mature Themes (성인 주제)

| 질문 | 답변 |
|------|------|
| Profanity or Crude Humor | **None** |
| Horror/Fear Themes | **None** |
| Alcohol, Tobacco, or Drug Use or References | **None** |

## D. Medical or Wellness (의료/건강)

| 질문 | 답변 |
|------|------|
| Medical or Treatment Information | **None** |
| Health or Wellness Topics | **No** |

## E. Sexuality or Nudity (성적 콘텐츠/노출)

| 질문 | 답변 |
|------|------|
| Mature or Suggestive Themes | **None** |
| Sexual Content or Nudity | **None** |
| Graphic Sexual Content and Nudity | **None** |

## F. Violence (폭력)

| 질문 | 답변 |
|------|------|
| Cartoon or Fantasy Violence | **None** |
| Realistic Violence | **None** |
| Prolonged Graphic or Sadistic Realistic Violence | **None** |
| Guns or Other Weapons | **None** |

## G. Chance-Based Activities (확률 기반 활동)

| 질문 | 답변 |
|------|------|
| Gambling | **No** |
| Simulated Gambling | **None** |
| Contests | **None** |
| Loot Boxes | **No** |

---

## 추가 확인사항

| 항목 | 답변 | 이유 |
|------|------|------|
| Made for Kids | **No** | AdMob 사용으로 Kids 카테고리 부적합 |
| GRAC (한국 게임등급) | **해당 없음** | Photo & Video 카테고리 → GRAC 대상 아님 |

---

## 필수 코드 설정

4+ 등급 앱이므로 광고 콘텐츠도 연령에 적합해야 합니다:

```swift
// AppDelegate 또는 AdMob 초기화 시점
GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating = .general
```
