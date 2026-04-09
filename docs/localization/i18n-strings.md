# SweepPic 전체 문자열 한→영 매핑 테이블
수정 시 반영 파일 SweepPic/SweepPic/Localizable.xcstrings

> 주인님 확인용. 영어 번역(안)을 검토 후 확정해주세요.
> ✅ = 확인 완료, ❌ = 수정 필요

### 통일 규칙
1. **"Trash"**: 삭제대기함은 모두 "Trash"로 통일
2. **"Rewards"**: referral 맥락에서 "benefit" 대신 "reward" 통일
3. **단복수**: {count} 사용 항목에 "(plural 처리 필요)" 주석 추가
4. **닫기 버튼**: 모달/팝업은 "Close", 네비게이션은 "Back"으로 구분
5. **"cell" 금지**: 개발 용어 "cell" 대신 사진/항목 등 사용자 용어 사용
6. **"invite" 통일**: referral 맥락에서 사용자 대면 문자열은 "invite" 통일
7. **등급 표현**: 한국어는 숫자 등급 유지 + 5등급에 "(최저)" 표기. 영어는 Lowest Quality / Lower Quality & Below / Low Quality & Below
8. **"Restore Purchases"**: 구매 복원은 Apple StoreKit 표준 "Restore Purchases" 사용
9. **"Pro"**: 멤버십 명칭은 "Pro"로 통일 ("Premium" 사용 금지)
10. **"Open Settings"**: 설정 이동 버튼은 "Open Settings"로 통일
11. **"photo library access"**: 사진 접근 권한 표현 통일 ("photo access" 단독 사용 금지)
12. **인용 부호**: Apple 인용 스타일에 따라 큰따옴표("") 사용
13. **네트워크 에러**: "Please check your network connection."으로 통일
14. **미국식 영어**: "canceled" (미국식), "cancelled" (영국식) 금지
15. **"Yearly"**: 구독 기간 표현은 "Yearly"로 통일 ("Annual" 대신)

---

## 1. Permissions

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 1 | 사진 접근이\n제한되어 있습니다 | Photo Access\nIs Restricted | 제목 (권한 제한) | |
| 2 | 이 기기에서 사진 라이브러리 접근이\n제한되어 있습니다.\n관리자에게 문의해 주세요. | Photo library access is restricted\non this device.\nPlease contact your administrator. | 설명 (권한 제한) | |
| 3 | 설정 열기 | Open Settings | 버튼 | |
| 4 | 설정 > 스크린 타임에서 제한을 해제할 수 있습니다. | You can remove restrictions in Settings > Screen Time. | 보조 설명 | |
| 5 | 앱을 이용하려면\n전체 사진 접근 권한이\n필요합니다 | Full Photo Access\nRequired | 제목 (권한 거부) | |
| 6 | SweepPic은 전체 사진 라이브러리에\n접근해야 정상적으로 동작합니다.\n설정에서 '전체 접근 허용'을 선택해 주세요. | SweepPic needs full access to your\nphoto library to work properly.\nPlease select "Allow Full Access" in Settings. | 설명 (권한 거부) | |

---

## 2. Albums

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 7 | 앨범 | Albums | FloatingOverlay 타이틀 | |
| 8 | 앨범이 없습니다 | No Albums | EmptyState 제목 | |
| 9 | 앨범을 생성하세요 | Create an album | EmptyState 부제 | |
| 10 | 사진이 없습니다 | No Photos | EmptyState 제목 | |
| 11 | 이 앨범에 사진이 없습니다 | This album has no photos | EmptyState 부제 | |
| 12 | 선택 | Select | 네비게이션 바 버튼 | |
| 13 | 삭제대기함이 비어 있습니다 | Trash is Empty | EmptyState 제목 | |
| 14 | 삭제대기함 | Trash | 네비게이션 타이틀 | |
| 15 | 비우기 | Empty | 네비게이션 바 버튼 | |
| 16 | 오늘의 무료 삭제 한도예요.\n탭해서 자세히 볼 수 있어요 | Today's free limit for emptying Trash.\nTap for details. | 게이지 툴팁 | |
| 17 | 복구 | Restore | 툴바 버튼 (선택 모드) | |
| 18 | 항목 선택 | Select Items | 선택 개수 라벨 (초기) | |
| 19 | 삭제 | Delete | 툴바 버튼 (선택 모드) | |
| 20 | {count}개 항목 선택됨 | {count} Selected | 선택 개수 라벨 (동적) (plural 처리 필요 - 1 Selected / N Selected) | |

### 스마트 앨범 이름

> 스마트 앨범 이름은 Apple Photos 공식 영어명을 사용 (Recents, Slo-mo, Time-lapse 등)

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 436 | 모든 사진 | All Photos | 스마트 앨범 이름 | |
| 437 | 최근 추가 | Recents | 스마트 앨범 이름 | |
| 438 | 스크린샷 | Screenshots | 스마트 앨범 이름 | |
| 439 | 셀프카메라 | Selfies | 스마트 앨범 이름 | |
| 440 | 즐겨찾기 | Favorites | 스마트 앨범 이름 | |
| 441 | 비디오 | Videos | 스마트 앨범 이름 | |
| 442 | 파노라마 | Panoramas | 스마트 앨범 이름 | |
| 443 | 버스트 | Bursts | 스마트 앨범 이름 | |
| 444 | 타임랩스 | Time-lapse | 스마트 앨범 이름 | |
| 445 | 슬로모션 | Slo-mo | 스마트 앨범 이름 | |
| 446 | 인물 사진 | Portrait | 스마트 앨범 이름 | |
| 447 | 최근 삭제된 항목 | Recently Deleted | 스마트 앨범 이름 | |
| 448 | 미디어 유형 | Media Types | 앨범 섹션 헤더 | |
| 449 | 나의 앨범 | My Albums | 앨범 섹션 헤더 | |
| 450 | 제목 없음 | Untitled | 앨범 제목 fallback | |
| 494 | {count}개의 항목 | {count} Items | 보관함/삭제대기함 서브타이틀 (plural 처리 필요 - 1 Item / N Items) | |

---

## 3. Grid

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 21 | 사진보관함 | Library | FloatingOverlay 타이틀 | |
| 22 | 항목 선택 | Select Items | 선택 모드 라벨 (초기) | |
| 23 | {count}개 항목 선택됨 | {count} Selected | 선택 모드 라벨 (동적) (plural 처리 필요 - 1 Selected / N Selected) | |
| 24 | 기능이 실행되는\n사진을 찾고 있어요 | Finding a photo\nto demonstrate... | 코치마크 온보딩 | |
| 25 | 사진을 촬영하거나 가져오세요 | Take or import photos | 빈 상태 부제 | |
| 26 | 표시할 이미지가 없습니다 | No photos to display | Toast (코치마크) | |
| 27 | 인물사진 비교정리 할 사진을 찾지 못했습니다 | No photos found for Face Comparison | Toast | |
| 28 | 간편정리 | Clean Up | 메뉴 버튼 타이틀 | |
| 29 | 인물사진 비교정리 | Compare & Clean Portraits | 메뉴 항목 (타이틀 겸용) | |
| 30 | 저품질 사진 자동정리 | Auto Low-Quality Photo Cleanup | 메뉴 항목 (타이틀 겸용) | |
| 31 | 사진 선택 모드 | Select Mode | 메뉴 항목 | |
| 32 | 삭제대기함 보기 | View Trash | alert 버튼 | |
| 33 | 정리 실패 | Cleanup Failed | alert 제목 | |
| 34 | 정리할 사진 없음 | No Photos to Clean Up | alert 제목 | |
| 35 | {yearString}년에서 정리할 저품질 사진을 찾지 못했습니다. | No low-quality photos found in {yearString}. | alert 메시지 (yearString placeholder) | |
| 36 | 정리할 저품질 사진을 찾지 못했습니다. | No low-quality photos found. | alert 메시지 | |
| 37 | 설명 다시 보기 | Tutorial Replay | 메뉴 타이틀 | |
| 38 | 목록에서 밀어서 삭제 | Library: Swipe to Delete | 메뉴 항목 | |
| 39 | 뷰어에서 밀어서 삭제 | Viewer: Swipe Up to Delete | 메뉴 항목 | |
| 40 | 삭제 시스템 안내 | How Trash Works | 메뉴 항목 | |
| 41 | 비우기 완료 안내 | After Emptying Trash | 메뉴 항목 | |

---

## 4. Shared Components

### EmptyStateView

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 42 | 사진이 없습니다 | No Photos | noPhotos 프리셋 제목 | |
| 43 | 사진 라이브러리에 사진을 추가해주세요 | Add photos to your library | noPhotos 프리셋 부제 | |
| 44 | 사진 없음 | No Photos | emptyAlbum 프리셋 제목 | |
| 45 | 이 앨범에는 사진이 없습니다 | This album has no photos | emptyAlbum 프리셋 부제 | |
| 46 | 삭제대기함이 비어 있습니다 | Trash is Empty | emptyTrash 프리셋 제목 | |
| 47 | 사진 접근 권한 필요 | Photo Access Required | permissionRequired 프리셋 제목 | |
| 48 | 설정에서 사진 라이브러리 접근을 허용해주세요 | Please allow photo library access in Settings | permissionRequired 프리셋 부제 | |

### FloatingTabBar

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 49 | 보관함 | Library | 사진 탭 버튼 | |
| 50 | 앨범 | Albums | 앨범 탭 버튼 | |
| 51 | 삭제대기함 | Trash | 삭제대기함 탭 버튼 | |
| 52 | 삭제하기 | Delete | 접근성 라벨 | |
| 53 | 항목 선택 | Select Items | Select 모드 라벨 | |
| 54 | 삭제 | Delete | Select 모드 삭제 버튼 | |
| 55 | 복구 | Restore | Trash Select 모드 복구 버튼 | |
| 56 | {count}개 항목 선택됨 | {count} Selected | 동적 선택 카운트 (plural 처리 필요 - 1 Selected / N Selected) | |

---

## 5. CoachMark

### 기본 (CoachMarkOverlayView.swift)

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 57 | 완전히 새로운 삭제 방법 | A Brand New Way to Delete | 타이틀 | |
| 58 | 사진을 가로로 밀어서 바로 정리하세요`\u2028`다시 밀면 복원돼요`\n`정리한 사진은 삭제대기함으로 이동됩니다 | Swipe horizontally to clean up photos`\u2028`Swipe again to restore`\n`Deleted photos move to Trash | 본문 | |
| 59 | 정리 | Swipe horizontally | 키워드 (강조) | |
| 60 | 복원 | restore | 키워드 (강조) | |
| 61 | 삭제대기함 | Trash | 키워드 (강조) | |
| 62 | 확인 | OK | 버튼 | |
| 63 | 설명을 위해 사진을 임시로 삭제합니다\n(삭제 후 바로 복구돼요) | For this demo, a photo will be`\u2028`temporarily deleted`\n`(it'll be restored right away) | A 변형 카드 | |
| 64 | 임시로 삭제 | temporarily deleted | 키워드 (강조) | |
| 65 | 사진을 위로 밀면 바로`\u2028`삭제대기함으로 이동해요 | Swipe up to move a photo`\u2028`to Trash | B 뷰어 카드 | |
| 66 | 삭제대기함 | Trash | 키워드 (강조) | |

### A-1

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 67 | 사진을 가로로 밀어서`\u2028`삭제해 보세요`\n`(삭제 후 바로 복구돼요) | Swipe horizontally`\u2028`on a photo to delete`\n`(it'll be restored right away) | 본문 | |
| 68 | 가로로 밀어서 | Swipe horizontally | 키워드 (강조) | |

### A-2

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 69 | 한번에 쓱 | All at Once | 타이틀 | |
| 70 | 가로로 밀면서 좌우/상하까지 더 선택하면`\u2028`여러 장을 한번에 정리해요 | Swipe and extend up/down`\u2028`to select multiple photos`\u2028`and delete them all at once | 본문 | |
| 71 | 여러 장 | multiple photos | 키워드 (강조) | |
| 72 | 한번에 | all at once | 키워드 (강조) | |

### C-1, C-2

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 73 | 하얀색 테두리가 표시된 사진은`\u2028`여러 사진의 얼굴을 비교해서 삭제하는`\u2028`인물사진 비교정리가 가능한 사진이에요 | Photos with a white border support`\u2028`Compare & Clean Portraits —`\n`Compare faces across multiple photos`\u2028`and choose which photos to remove | C-1 본문 | |
| 74a | 얼굴을 비교해서 삭제 | Compare faces | C-1 키워드 1 | |
| 74b | (위와 동일) | choose which to remove | C-1 키워드 2 | |
| 75 | +버튼을 눌러 얼굴비교화면으로 이동하세요`\u2028`인물이 여러 명이면 좌우로 넘겨볼 수 있어요 | Tap the + button`\u2028`to open Face Comparison`\n`Swipe left/right to see other people | C-2 본문 | |
| 76 | `\n`※ 얼굴은 각도, 해상도에 따라 검출되지 않거나`\u2028`다른 인물로 분류될 수 있습니다 | `\n`Note: Faces may not be detected`\u2028`or misclassified depending on`\u2028`angle or resolution | C-2 부가 안내 | |
| 77 | +버튼 | + button | C-2 키워드 | |
| 78 | 얼굴비교화면 | Face Comparison | C-2 키워드 | |
| 78-1 | 간편정리 메뉴에서 편리하게`\u2028`인물비교 자동 탐색이 가능해요`\n`간편정리 → 인물사진 비교정리 | Auto scanning is available`\u2028`from the Clean Up menu`\n`Clean Up → Compare & Clean Portraits | C-2 후속 안내 본문 (키워드: "자동 탐색" / "Auto scanning") | |

### C-3

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 79 | 마음에 들지 않는 얼굴을 선택하세요`\n`옆으로 이동해서 다른 인물의 얼굴도`\u2028`확인하고 삭제할 수 있어요 | Select the faces you don't like`\n`Swipe to check other people`\u2028`and remove their photos too | Step 1 본문 | |
| 80 | 얼굴을 선택 | Select the faces | Step 1 키워드 | |
| 81 | 현재 인물사진 비교정리 그룹의`\u2028`사진 구별 번호예요`\n`얼굴 검출 여부에 따라`\u2028`인물별로 번호가 다르게 보일 수 있어요 | This is the photo number`\u2028`in the current Face Comparison group.`\n`Numbers may differ per person`\u2028`depending on face detection. | Step 2 본문 | |
| 82 | 사진 구별 번호 | photo number | Step 2 키워드 | |

### D

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 83 | 저품질사진 자동정리 | Auto Low-Quality Photo Cleanup | 타이틀 | |
| 84 | 흔들리거나 초점이 맞지 않은`\u2028`저품질 사진을 AI가 자동으로 찾아주는`\u2028`정리 기능을 사용해보세요`\n\n`간편정리 → 저품질사진 자동정리 | AI automatically finds blurry`\u2028`and out-of-focus photos.`\u2028`Try Low-Quality Cleanup`\n\n`Clean Up →`\n`Auto Low-Quality Photo Cleanup | 본문 | |
| 85 | 저품질 사진 | AI automatically | 키워드 1 (강조) | |
| 85-1 | AI가 자동 | Low-Quality Cleanup | 키워드 2 (강조) | |
| 86 | 간편정리 → 저품질사진 자동정리 | Clean Up →`\n`Auto Low-Quality Photo Cleanup | 경로 안내 | |
| 87 | 비우기 | Empty | E-1 페이크 버튼 라벨 | |

### D-1

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 87-1 | 사진의 품질 점수를 측정하여`\u2028`1~5 등급으로 분류했어요`\n`가장 낮은 5등급 사진을 먼저 확인해 보세요 | Photos have been rated by quality score`\u2028`and sorted into 5 levels`\n`Review the Lowest Quality photos first | Step 1 본문 | |
| 87-2 | 품질 점수 | quality score | Step 1 키워드1 (강조) | |
| 87-3 | 1~5 등급 | 5 levels | Step 1 키워드2 (강조) | |
| 87-4 | 4등급, 3등급 사진의 정리 여부를`\u2028`선택할 수 있어요`\n`2등급 이상 고품질 사진은 나오지 않아요 | You can choose whether to include`\u2028`Lower/Low Quality photos`\n`High-quality photos won't appear | Step 2 본문 | |
| 87-5 | 4등급, 3등급 | Lower/Low Quality | Step 2 키워드 (강조) | |
| 87-6 | `\n`아래 더보기 버튼은 3~4등급 사진이`\u2028`탐색된 경우에만 보여요 | `\n`The "show more" button below only appears`\u2028`when Lower/Low Quality photos are found | Step 2 주석 (작은 글씨) | |
| 87-7 | 4등급 사진 더 보기 | Show more: Lower Quality photos | Step 2 임시 버튼 라벨 | |
| 87-8 | 사진을 클릭해서 상세히 보거나`\u2028`가로로 밀어서 삭제 목록에서 제외할 수 있어요 | Tap a photo to view details,`\u2028`swipe to exclude it from cleanup | Step 3 본문 | |
| 87-9 | 클릭 | Tap | Step 3 키워드1 (강조) | |
| 87-10 | 가로로 밀어서 | swipe | Step 3 키워드2 (강조) | |
| 87-11 | 제외 | exclude | Step 3 키워드3 (강조) | |
| 87-12 | `\n`녹색으로 제외된 사진은`\u2028`삭제대기함으로 이동되지 않아요 | `\n`Excluded photos (shown in green)`\u2028`won't be moved to Trash | Step 3 주석 (작은 글씨) | |
| 87-13 | 사진을 모두 선별했다면`\u2028`삭제대기함 이동 버튼을 눌러 삭제하세요 | Once you've reviewed all photos,`\u2028`tap the Move to Trash button to delete them | Step 4 본문 | |
| 87-14 | 삭제대기함 이동 버튼 | Move to Trash button | Step 4 키워드 (강조) | |

### E-1, E-2

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 88 | 방금 삭제된 사진은`\u2028`삭제대기함으로 이동됐어요`\n`삭제대기함에서 확인해볼까요? | The deleted photo has been`\u2028`moved to Trash`\n`Want to check it in Trash? | E-1 본문 | |
| 89 | 삭제대기함으로 이동 | moved to Trash | E-1 키워드 | |
| 90 | 보관함에서 삭제된 사진은`\u2028`삭제대기함에 임시 보관돼요 | Deleted photos from your library`\u2028`are temporarily stored in Trash | E-2 Step 2 본문 | |
| 91 | 삭제대기함에 임시 보관 | temporarily stored in Trash | E-2 키워드 | |
| 92 | [비우기]를 누르면 사진이 최종 삭제돼요 | Tap [Empty] to permanently`\u2028`delete photos | E-2 Step 3 본문 | |
| 93 | [비우기] | [Empty] | E-2 키워드 | |

### E-3

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 94 | 사진을 밀어서`\u2028`편리하게 복구할 수 있어요`\n`연속으로 밀면 여러 장 복구도 가능해요 | Swipe a photo to`\u2028`restore it easily`\n`Swipe repeatedly to`\u2028`restore multiple photos | E-3 본문 | |
| 95 | 사진을 밀어서 | Swipe a photo | E-3 키워드 (강조) | |

### F

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 95-1 | 삭제 완료 | Deletion Complete | F 타이틀 | |
| 95-2 | 애플 사진앱의 '최근 삭제된 항목'에서`\u2028`30일 후 완전히 삭제됩니다 | Photos will be permanently deleted`\u2028`after 30 days in the Photos app's`\u2028`"Recently Deleted" album | F 본문 | |
| 95-3 | 애플 사진앱의 '최근 삭제된 항목' | the Photos app's`\u2028`"Recently Deleted" album | F 키워드 (강조) | |

---

## 6. Monetization — Gate/Gauge

### TrashGatePopupViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 96 | 무료 삭제 한도 부족 | Not Enough\nFree Deletions Left | 제목 | |
| 97 | 삭제할 사진 {trashCount}장\n무료 삭제 가능 {remaining}장 | {trashCount} photos to delete\n{remaining} free deletions left | info 라벨 | |
| 98 | 광고 {adsNeeded}회 보고 전체 삭제 | Watch {adsNeeded} Ads Delete All Photos | 광고 버튼 | |
| 99 | Pro 멤버십으로 무제한 삭제 | Go Unlimited with Pro | Pro 버튼 | |
| 100 | 닫기 | Close | 닫기 버튼 | |
| 101 | 오늘 광고 횟수를 모두 사용했습니다 | You've used all ad watches for today | 골든 모먼트 라벨 | |
| 102 | 인터넷 연결이 필요합니다 | Internet connection required | 오프라인 라벨 | |
| 103 | 광고를 불러올 수 없습니다 | Unable to load ad | 광고 로드 실패 | |
| 104 | 초대 한 번마다 나도 친구도\nPro 멤버십 14일 무료 제공! | Invite a friend and\nyou both get 14 days of Pro free! | 초대 프로모 라벨 | |
| 105 | 친구 초대하기 | Invite Friends | 초대 버튼 | |
| 106 | 이미 Pro멤버십 이용 중이어도 14일 무료 연장 | Already Pro? Get 14 extra days free! | 초대 부가 문구 | |
| 107 | 네트워크 상태를 확인하고 다시 시도해주세요. | Please check your network connection and try again. | 광고 실패 alert 메시지 | |
| 108 | 다시 시도 | Try Again | alert 버튼 | |

### UsageGaugeView

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 109 | 무료 삭제 한도 | Free Deletion Limit | 타이틀 | |
| 110 | {remaining}/{total}장 남음 | {remaining}/{total} remaining | 카운트 라벨 | |
| 111 | 광고 보고 +10장 추가 | Watch Ad for 10 More | 광고 버튼 | |
| 112 | Pro 멤버십으로 무제한 삭제 | Go Unlimited with Pro | Pro 버튼 | |
| 113 | 광고 시청 가능: {rewardsLeft}회 (회당 +10장) | {rewardsLeft} ad watches left (10 photos each) | status 라벨 | |
| 114 | 오늘 광고 시청 횟수를 모두 사용했습니다 | You've used all ad watches for today | status 라벨 (광고 없음) | |

---

## 7. Monetization — Paywall

### PaywallViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 115 | 무료 체험하고\n한 번에 비우세요 | Start Free Trial and\nClean Up All at Once | 헤드라인 | |
| 116 | Pro 멤버십으로 삭제 한도 없이, 광고 없이 | No limits, No ads with Pro | 서브헤드라인 | |
| 117 | 무료 체험 시작하기 | Start Free Trial | 구매 버튼 | |
| 118 | 멤버십 복원 | Restore Purchases | 복원 버튼 | |
| 119 | 리딤 코드 | Redeem Code | 리딤 버튼 | |
| 120 | Apple로 보호됨 | Secured by Apple | 보호 라벨 (NSAttributedString) | |
| 121 | 약관 | Terms | 약관 링크 (밑줄) | |
| 122 | 무료체험 | Free Trial | 비교표 Pro 헤더 제목 | |
| 122-1 | (Pro) | (Pro) | 비교표 Pro 헤더 배지 (한국어는 기존 크기, 그 외 로컬라이즈는 작은 폰트) | |
| 123 | 일반 | Free | 비교표 Free 헤더 | |
| 124 | 복원 완료 | Restored | alert 제목 | |
| 125 | Pro멤버십이 복원되었습니다. | Your purchase has been restored. | alert 메시지 | |
| 126 | 복원 결과 | Restore Result | alert 제목 | |
| 127 | 복원할 멤버십이 없습니다. | No purchases to restore. | alert 메시지 | |
| 128 | 승인 대기 | Awaiting Approval | alert 제목 (Ask to Buy) | |
| 129 | 구매 요청이 전송되었습니다.\n보호자의 승인 후 활성화됩니다. | Your purchase request has been sent.\nIt will be activated after approval. | alert 메시지 | |
| 130 | 네트워크 연결을 확인해주세요. | Please check your network connection. | 에러 메시지 | |
| 131 | 결제를 완료할 수 없습니다.\n다시 시도해주세요. | Unable to complete the purchase.\nPlease try again. | 에러 메시지 | |
| 132 | 결제 실패 | Payment Failed | alert 제목 | |
| 133 | 상품 정보를 불러올 수 없습니다 | Unable to load product info | 로드 실패 버튼 | |
| 134 | 확인 | OK | alert 버튼 | |
| 135 | 이용 약관 | Terms of Use | 약관 sheet 제목 | |
| 136 | 복원 실패 | Restore Failed | alert 제목 | |
| 137 | - 언제든 취소 가능 | - Cancel anytime | 체험 취소 안내 | |

### PaywallViewModel

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 138 | 로딩 중... | Loading... | 가격 텍스트 (로딩) | |
| 139 | 월 {formatted} | {formatted}/month | 연간 월 환산 가격 | |
| 140 | {price}/연 | {price}/year | 연간 가격 | |
| 141 | {price}/월 | {price}/month | 월간 가격 | |
| 142 | {N}일 무료체험 | {N}-day free trial | 체험 기간 (일) | |
| 143 | {N}개월 무료체험 | {N}-month free trial | 체험 기간 (월) | |
| 144 | {N}년 무료체험 | {N}-year free trial | 체험 기간 (년) | |
| 145 | 일일 삭제 | Daily Deletes | 비교표 feature | |
| 146 | 10장 | 10 photos | 비교표 (무료) | |
| 147 | 무제한 | Unlimited | 비교표 (Pro) | |
| 148 | 광고 | Ads | 비교표 feature | |
| 149 | 있음 | Shown | 비교표 (무료) | |
| 150 | 없음 | None | 비교표 (Pro) | |
| 151 | 인물사진 비교정리 | Face Compare | 비교표 feature | |
| 152 | 광고포함 | With Ads | 비교표 (무료) | |
| 153 | 광고없음 | Ad-Free | 비교표 (Pro) | |
| 154 | 저품질 사진 자동정리 | Auto Cleanup | 비교표 feature | |
| 155 | 상품 정보를 불러올 수 없습니다. 네트워크 연결을 확인해주세요. | Unable to load product info. Please check your network connection. | 에러 메시지 | |

### PaywallPlanTabView

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 156 | 월간 | Monthly | 탭 텍스트 | |
| 157 | 연간 | Yearly | 탭 텍스트 | |
| 158 | 인기 | Most Popular | 인기 배지 | |

### Paywall 접근성

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 451 | 리딤 코드 입력 | Enter redeem code | 리딤 버튼 accessibilityLabel | |
| 452 | {feature}, 무료: {freeValue}, Pro: {proValue} | {feature}, Free: {freeValue}, Pro: {proValue} | 비교표 행 accessibilityLabel (포맷) | |

### Paywall 이용약관 본문

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 488 | 무료 체험 기간이 끝나면 선택한 요금제로 자동 구독이 시작됩니다. 구독은 확인 시 Apple ID 계정으로 청구됩니다. 구독은 현재 기간 종료 최소 24시간 전에 해지하지 않으면 자동으로 갱신됩니다. 갱신 비용은 현재 기간 종료 24시간 이내에 청구됩니다. 구독은 구매 후 설정 > [사용자 이름] > 구독에서 관리하고 해지할 수 있습니다. 이용약관 및 개인정보처리방침이 적용됩니다. | Your subscription will automatically begin at the selected plan rate when the free trial ends. Payment will be charged to your Apple ID account upon confirmation. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. Renewal will be charged within 24 hours before the end of the current period. You can manage and cancel subscriptions in Settings > [Your Name] > Subscriptions after purchase. Terms of Use and Privacy Policy apply. | 이용약관 시트 법적 고지 본문 | |

---

## 8. Monetization — FAQ

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 159 | 자주 묻는 질문 | FAQ | 네비게이션 타이틀 | |
| 160 | 사진/기능 | Photos & Features | 섹션 제목 | |
| 161 | 삭제한 사진을 복구할 수 있나요? | Can I recover deleted photos? | Q1 | |
| 162 | 삭제대기함에 있는 사진은 언제든 복구할 수 있습니다. 삭제대기함을 비운 후에는 최근 삭제된 항목(iOS 기본 사진 앱)에서 30일 이내에 복구 가능합니다. | Photos in Trash can be restored anytime. After emptying Trash, you can recover them within 30 days from "Recently Deleted" in the Photos app. | A1 | |
| 163 | 내 사진이 외부 서버로 전송 또는 유출되나요? | Are my photos sent to or leaked to external servers? | Q2 | |
| 164 | 아니요. 모든 사진 처리(유사 사진 분석, 얼굴 감지 포함)는 기기 내에서만 이루어집니다. 사진 데이터는 외부 서버로 전송되지 않습니다. | No. All photo processing (including similarity analysis and face detection) happens entirely on your device. No photo data is sent to external servers. | A2 | |
| 165 | 지원하는 iOS 버전은? | What iOS versions are supported? | Q3 | |
| 166 | iOS 16 이상을 지원합니다. | Requires iOS 16 or later. | A3 | |
| 167 | 인물사진 비교정리가 정확하지 않아요 | Compare & Clean Portraits isn't accurate | Q4 | |
| 168 | 인물사진 비교정리는 사진의 화질, 얼굴 각도, 얼굴 위치 등에 따라 일부 오분류가 있을 수 있습니다. 삭제 전 반드시 확인하시고, 실수로 삭제해도 삭제대기함에서 복구할 수 있습니다. | Compare & Clean Portraits may occasionally misclassify due to photo quality, face angle, or face position. Always review before deleting. Accidentally deleted photos can be restored from Trash. | A4 | |
| 169 | 자동 정리는 어떤 기준으로 사진을 선택하나요? | How does Auto Cleanup select photos? | Q5 | |
| 170 | 유사 사진 그룹에서 화질, 초점, 구도 등을 분석하여 가장 좋은 사진을 남기고 나머지를 삭제대기함으로 이동합니다. 바로 삭제되지 않으니 안심하세요. | It analyzes quality, focus, and composition in similar photo groups, keeps the best one, and moves the rest to Trash. Don't worry — nothing is permanently deleted. | A5 | |
| 171 | 멤버십/결제 | Membership & Billing | 섹션 제목 | |
| 172 | 무료로 사용할 수 있나요? | Can I use it for free? | Q6 | |
| 173 | 네. 사진 정리(밀어서 삭제, 유사 사진 분석, 자동 정리, 복구)는 모두 무료입니다. 삭제대기함 비우기에만 일일 한도(10장)가 있으며, 광고를 보면 추가 삭제가 가능합니다. | Yes. Photo organizing (swipe delete, similarity analysis, auto cleanup, restore) is entirely free. Only emptying Trash has a daily limit (10 photos), and you can watch ads for more. | A6 | |
| 174 | 멤버십 가입했는데 멤버십이 활성화되지 않아요 | I subscribed but my membership isn't active | Q7 | |
| 175 | 전체 메뉴 > 멤버십 > "멤버십 복원"을 탭해주세요. 네트워크 연결 상태를 확인하고, 결제에 사용한 Apple ID로 로그인되어 있는지 확인해주세요. | Go to Menu > Membership > "Restore Purchases". Check your network connection and make sure you're signed in with the Apple ID used for the purchase. | A7 | |
| 176 | 멤버십을 해지하고 싶어요 | I want to cancel my membership | Q8 | |
| 177 | 설정 > [내 이름] > 구독 > SweepPic Pro > 구독 취소를 탭하세요. 앱을 삭제해도 자동으로 해지되지 않으니 반드시 위 경로에서 취소해주세요. | Go to Settings > [Your Name] > Subscriptions > SweepPic Pro > Cancel. Deleting the app does not cancel your subscription, so please use the path above. | A8 | |
| 178 | 환불받을 수 있나요? | Can I get a refund? | Q9 | |
| 179 | 환불은 Apple을 통해 처리됩니다. reportaproblem.apple.com에서 신청해주세요. | Refunds are handled by Apple. Please visit reportaproblem.apple.com. | A9 | |
| 180 | 삭제 한도가 뭔가요? | What is the limit for emptying Trash? | Q10 | |
| 181 | 무료 사용자는 하루 {dailyFreeLimit}장까지 삭제대기함 비우기가 가능합니다. 광고를 보면 하루 최대 {maxDailyTotal}장까지 늘릴 수 있고, Pro멤버십 가입 시 무제한입니다. 한도는 매일 자정에 초기화됩니다. | Free users can empty up to {dailyFreeLimit} photos from Trash per day. Watching ads increases this to {maxDailyTotal}/day. Pro members have no limit. The limit resets daily at midnight. | A10 | |
| 182 | 개인정보/보안 | Privacy & Security | 섹션 제목 | |
| 183 | 얼굴 인식 데이터는 어떻게 처리되나요? | How is face recognition data handled? | Q11 | |
| 184 | 얼굴 감지는 기기의 Vision 프레임워크를 사용하며, 기기 내에서만 처리됩니다. 얼굴 데이터는 서버에 전송되거나 저장되지 않습니다. | Face detection uses the device's Vision framework and is processed entirely on-device. No face data is sent to or stored on any server. | A11 | |
| ~~185~~ | ~~광고 추적을 끄고 싶어요~~ | ~~삭제~~ | ~~Q12 — 해당 기능 없음~~ | |
| ~~186~~ | ~~설정 > 개인정보 보호 및 보안 > 추적에서...~~ | ~~삭제~~ | ~~A12 — 해당 기능 없음~~ | |

---

## 9. Monetization — 기타

### CustomerServiceViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 187 | 고객센터 | Support | UIMenu 제목 | |
| 188 | 이메일 문의하기 | Contact Us | 메뉴 액션 | |
| 189 | [SweepPic] 문의하기 | [SweepPic] Support Request | 이메일 제목 | |
| 190 | 자주 묻는 질문 | FAQ | 메뉴 액션 | |
| 191 | 이용약관 | Terms of Use | 메뉴 액션 | |
| 192 | 개인정보처리방침 | Privacy Policy | 메뉴 액션 | |
| 193 | 사업자 정보 | ~~ko locale 전용 — 메뉴 숨김~~ | 메뉴 액션 | |
| 489 | 앱 버전: | App Version: | 이메일 문의 디바이스 정보 라벨 | |
| 490 | 기기: | Device: | 이메일 문의 디바이스 정보 라벨 | |
| 491 | 기기명: | Device Name: | 이메일 문의 디바이스 정보 라벨 | |
| 492 | 지원 ID: | Support ID: | 이메일 문의 디바이스 정보 라벨 | |

### BusinessInfoViewController

> ⚠️ **locale 분기**: 한국 전자상거래법 제10조 전용. ko locale에서만 메뉴 노출, 영어 번역 불필요.

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| ~~194~~ | 사업자 정보 | ~~ko locale 전용 — 번역 제외~~ | 네비게이션 타이틀 | |
| ~~195~~ | 상호 | ~~ko locale 전용 — 번역 제외~~ | 항목 제목 | |
| ~~196~~ | 대표자 | ~~ko locale 전용 — 번역 제외~~ | 항목 제목 | |
| ~~197~~ | 사업자등록번호 | ~~ko locale 전용 — 번역 제외~~ | 항목 제목 | |
| ~~198~~ | 연락처 | ~~ko locale 전용 — 번역 제외~~ | 항목 제목 | |
| ~~199~~ | 전자상거래 등에서의... | ~~ko locale 전용 — 번역 제외~~ | footer | |

### PremiumMenuViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 200 | 멤버십 | Membership | UIMenu 제목 | |
| 201 | 멤버십 관리 | Manage Membership | 메뉴 액션 | |
| 202 | 멤버십 복원 | Restore Purchases | 메뉴 액션 | |
| 203 | 리딤 코드 | Redeem Code | 메뉴 액션 | |
| 204 | 이미 멤버십 이용 중입니다 | You already have a membership | 토스트 | |
| 205 | 멤버십이 복원되었습니다 | Purchase has been restored | 토스트 | |
| 206 | 복원할 멤버십이 없습니다 | No purchases to restore | 토스트 | |
| 207 | 복원 실패: 네트워크를 확인해주세요 | Restore failed: Please check your network connection | 토스트 | |

### ATTPromptViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 208 | 광고 맞춤 설정 | Ad Personalization | 제목 | |
| 209 | 활동 추적을 허용하면\n관련없는 스팸성 광고를 줄여드립니다 | Allow tracking to see\nfewer irrelevant ads | 설명 | |
| 210 | 활동 추적을 허용 | Allow tracking | 키워드 (강조) | |
| 211 | 계속 | Continue | 버튼 | |
| 212 | 건너뛰기 | Skip | 버튼 | |

### CelebrationViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 213 | 확인 | OK | 확인 버튼 | |
| 214 | {count}장 삭제 완료 | {count} Photos Cleaned Up | 세션 라벨 (plural 처리 필요 - 1 Photo Cleaned Up / N Photos Cleaned Up) | |
| 215 | SweepPic에서 총 {total}장 삭제 | {total} photos cleaned up\nwith SweepPic | 총 삭제 라벨 | |
| 215-1 | {size} 확보 | {size} of space freed | 확보 용량 라벨 | |
| 216 | {freed} 확보 | {freed} freed | 확보 용량 라벨 | |

### ExitSurveyViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 217 | 왜 해지하셨나요? | Why did you cancel? | 제목 | |
| 218 | 더 나은 서비스를 위해 사유를 알려주세요 | Help us improve by sharing your reason | 부제 | |
| 219 | 가격이 부담돼요 | It's too expensive | 선택지 | |
| 220 | 무료로도 충분해요 | The free plan is enough | 선택지 | |
| 221 | 사진 정리를 다 했어요 | I've finished organizing my photos | 선택지 | |
| 222 | 다른 앱을 사용해요 | I'm using a different app | 선택지 | |
| 223 | 기타 | Other | 선택지 | |
| 224 | 사유를 입력해주세요 | Please enter your reason | placeholder | |
| 225 | 제출 | Submit | 버튼 | |

---

## 10. AutoCleanup

### CleanupMethodSheet

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 226 | 저품질 사진 자동정리 | Auto Low-Quality Photo Cleanup | 시트 제목 | |
| 227 | 흔들리거나 초점이 맞지 않은 사진들을\n자동으로 찾아 정리합니다.\n정리된 사진은 삭제대기함에서 복구할 수 있어요. | Automatically finds and cleans up\nblurry or out-of-focus photos.\nCleaned-up photos can be restored from Trash. | 시트 설명문 | |
| 228 | 최신사진부터 정리 | Clean Up from Latest | 액션 버튼 | |
| 229 | 이어서 정리 ({dateString} 이전) | Continue Before {dateString} | 액션 버튼 | |
| 230 | 이어서 정리 | Continue | 액션 버튼 (비활성) | |
| 231 | 연도별 정리 | Clean Up by Year | 액션 버튼 | |
| 232 | 취소 | Cancel | 액션 버튼 | |
| 233 | 사진별 연도 목록 확인 중 | Checking photo years... | 로딩 메시지 | |
| 234 | 연도 선택 | Select Year | 연도 시트 제목 | |
| 235 | 정리할 연도를 선택하세요 | Choose a year to clean up | 연도 시트 메시지 | |
| 236 | 뒤로 | Back | 액션 버튼 | |
| 237 | {yearString}년 이어서 ({month} 이전) | Continue {yearString} Before {month} | 연도별 이어서 버튼 (yearString placeholder) | |
| 238 | {yearString}년 | {yearString} | 연도 버튼 (yearString placeholder) | |

### CleanupProgressView

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 239 | 저품질 사진 탐색 중 | Scanning for`\u2028`Low-Quality Photos | 메인 제목 | |
| 240 | 최신 사진부터 | From latest | 서브 제목 | |
| 241 | 이어서 탐색 | Continuing scan | 서브 제목 | |
| 241-1 | {yearString}년 | {yearString} | 연도 서브 제목 (yearString placeholder) | |
| 242 | 준비 중... | Preparing... | 날짜 라벨 초기 | |
| 243 | {dateString} 사진 확인 중 | Checking photos from {dateString} | 탐색 시점 라벨 | |
| 244 | {found} / {max}장 발견 | {found} / {max} found | 발견 수 라벨 | |
| 245 | 취소 | Cancel | 취소 버튼 | |
| 246 | {scanned} / {max}장 검색 | {scanned} / {max} scanned | 검색 진행률 | |

### CleanupConstants (결과 메시지)

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 247 | 저품질 사진 정리 기능을 사용하려면\n삭제대기함을 먼저 비워주세요\n\n-Pro멤버십 가입 시 제한 해제- | To use Auto Cleanup,\nplease empty Trash first\n\n-No restriction with Pro- | 삭제대기함 비어있지 않음 | |
| 248 | {yearString}년의 마지막 사진까지 검색했지만 정리할 사진이 없습니다. | Searched to the last photo of {yearString}\nbut found none to clean up. | 결과 메시지 (yearString placeholder) | |
| 249 | {yearString}년의 마지막 사진까지 검색하여 {count}장을 찾았습니다. | Searched to the last photo of {yearString}\nand found {count} to clean up. | 결과 메시지 (yearString + count placeholder) | |

### PreviewGridViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 255 | 품질 5등급(최저) 사진 {count}장 | {count} Lowest Quality Photos | 헤더 (light) (plural 처리 필요) | |
| 256 | 품질 4등급 이하 사진 {count}장 | {count} Lower Quality & Below Photos | 헤더 (standard) (plural 처리 필요) | |
| 257 | 품질 3등급 이하 사진 {count}장 | {count} Low Quality & Below Photos | 헤더 (deep) (plural 처리 필요) | |
| 258 | 분석 결과를 닫으시겠습니까? | Close analysis results? | alert 제목 | |
| 259 | 현재 화면을 닫으면 분석 결과가 사라집니다. | Closing this screen will discard the results. | alert 메시지 | |
| 260 | 취소 | Cancel | alert 버튼 | |
| 261 | 닫기 | Close | alert 버튼 | |
| 262 | 품질 5등급(최저) | Lowest Quality | 등급 텍스트 | |
| 263 | 품질 4등급 이하 | Lower Quality & Below | 등급 텍스트 | |
| 264 | 품질 3등급 이하 | Low Quality & Below | 등급 텍스트 | |
| 265 | {gradeText} 사진 {count}장을\n삭제대기함으로 이동할까요? | Move {count} {gradeText} photos to Trash? | 정리 확인 alert (plural 처리 필요) | |
| 266 | 삭제대기함 이동 | Move to Trash | alert 버튼 | |

### PreviewBottomView

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 267 | 5등급(최저) 사진 {count}장 삭제대기함 이동 | Move {count} Lowest Quality to Trash | 정리 버튼 (light) | |
| 268 | 4등급 이하 사진 {count}장 삭제대기함 이동 | Move {count} Lower Quality & Below to Trash | 정리 버튼 (standard) | |
| 269 | 3등급 이하 사진 {count}장 삭제대기함 이동 | Move {count} Low Quality & Below to Trash | 정리 버튼 (deep) | |
| 270 | 4등급 사진 {N}장 덜 보기 | Show fewer: {N} Lower Quality | 축소 버튼 | |
| 271 | 3등급 사진 {N}장 덜 보기 | Show fewer: {N} Low Quality | 축소 버튼 | |
| 272 | 4등급 사진 {N}장 더 보기 | Show more: {N} Lower Quality | 확장 버튼 | |
| 273 | 3등급 사진 {N}장 더 보기 | Show more: {N} Low Quality | 확장 버튼 | |

### CleanupError

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 274 | 정리가 이미 진행 중입니다 | Cleanup is already in progress | 에러 | |
| 275 | 사진 라이브러리 접근 권한이 필요합니다 | Photo library access is required | 에러 | |
| 276 | 이전 정리 이력이 없습니다 | No previous cleanup session found | 에러 | |
| 277 | 분석 중 오류가 발생했습니다: {message} | An error occurred during analysis: {message} | 에러 | |
| 278 | 이미지 분석을 초기화할 수 없습니다 | Unable to initialize image analysis | 에러 | |
| 279 | 삭제대기함 이동 중 오류가 발생했습니다: {message} | An error occurred while moving to Trash: {message} | 에러 | |
| 280 | 현재 정리가 완료될 때까지 기다려주세요 | Please wait until the current cleanup finishes | 복구 제안 | |
| 281 | 삭제대기함을 비운 후 다시 시도해주세요 | Please empty Trash and try again | 복구 제안 | |
| 282 | 설정에서 사진 접근 권한을 허용해주세요 | Please allow photo library access in Settings | 복구 제안 | |
| 283 | '최신사진부터 정리'를 선택해주세요 | Please select "Clean Up from Latest" | 복구 제안 | |
| 284 | 앱을 재시작한 후 다시 시도해주세요 | Please restart the app and try again | 복구 제안 | |
| 285 | 다시 시도해주세요 | Please try again | 복구 제안 | |

### JudgmentMode

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 286 | 신중한 정리 | Careful Cleanup | precision 모드 | |
| 287 | 적극적 정리 | Thorough Cleanup | recall 모드 | |
| 288 | 확실한 저품질 사진만 정리합니다 | Only cleans up clearly low-quality photos | precision 설명 | |
| 289 | 더 많은 저품질 사진을 찾아 정리합니다 | Finds and cleans up more low-quality photos | recall 설명 | |

### PreviewBannerCell

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 290 | 품질 {scoreRange} 사진 {count}장 ↓ | {count} {scoreRange} quality photos ↓ | 배너 라벨 (plural 처리 필요) | |

---

## 11. FaceScan

### FaceScanMethodSheet

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 291 | 인물사진 비교정리 | Compare & Clean Portraits | 시트 제목 | |
| 292 | 비슷한 사진에서 같은 인물을\n찾아 얼굴을 비교합니다.\n마음에 들지 않는 사진을\n골라 정리할 수 있어요. | Finds the same person across similar photos\nand compares their faces.\nChoose the ones you don't like\nand clean them up. | 시트 설명문 | |
| 293 | 최신사진부터 정리 | Clean Up from Latest | 액션 버튼 | |
| 294 | 이어서 정리 ({dateString} 이전) | Continue Before {dateString} | 액션 버튼 | |
| 295 | 이어서 정리 | Continue | 액션 버튼 (비활성) | |
| 296 | 연도별 정리 | Clean Up by Year | 액션 버튼 | |
| 297 | 취소 | Cancel | 액션 버튼 | |
| 298 | 사진별 연도 목록 확인 중 | Checking photo years... | 로딩 메시지 | |
| 299 | 연도 선택 | Select Year | 연도 시트 제목 | |
| 300 | 정리할 연도를 선택하세요. | Choose a year to clean up. | 연도 시트 메시지 | |
| 301 | {yearString}년 (이어서: {dateString} 이전) | Continue {yearString} Before {dateString} | 연도별 이어서 버튼 (yearString placeholder) | |
| 302 | {yearString}년 | {yearString} | 연도 버튼 (yearString placeholder) | |

### FaceScanListViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 303 | 인물사진 비교정리 | Portrait Cleanup | 타이틀 | |
| 304 | 다음 분석 | Next Scan | 바 버튼 | |
| 305 | 분석 중 | Scanning... | emptyLabel | |
| 306 | 비교할 인물사진 그룹을\n찾지 못했습니다 | No face comparison groups found | emptyLabel (결과 없음) | |
| 307 | 분석이 진행 중입니다 | Scan in Progress | alert 제목 (닫기 확인) | |
| 308 | 현재까지의 분석결과는 초기화됩니다 | Current results will be lost | alert 메시지 | |
| 309 | 나가기 | Leave | alert 버튼 (destructive) | |
| 310 | 취소 | Cancel | alert 버튼 | |

### FaceScanProgressBar

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 311 | 분석 중 | Scanning | 진행 중 라벨 | |
| 312 | 분석 완료 | Scan Complete | 완료 라벨 | |
| 313 | · {groupCount}그룹 발견({scannedCount}장 분석 결과) | · {groupCount} groups found ({scannedCount} photos scanned) | 완료 상세 (그룹 있음) | |
| 314 | · 발견된 그룹 없음({scannedCount}장 분석 결과) | · No groups found ({scannedCount} photos scanned) | 완료 상세 (그룹 없음) | |
| 315 | {groupCount}그룹 발견 · {scannedCount} / {maxScanCount}장 검색 | {groupCount} groups found · {scannedCount} / {maxScanCount} scanned | progressText | |
| 316 | 분석 완료 · {groupCount}그룹 발견 | Scan Complete · {groupCount} groups found | completionText (그룹 있음) | |
| 317 | 분석 완료 · 발견된 그룹 없음 | Scan Complete · No groups found | completionText (그룹 없음) | |
| 318 | {yearString}년 사진 정리 | {yearString} Photo Cleanup | displayTitle (byYear, yearString placeholder) | |

### FaceScanGroupCell

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 319 | 정리 완료 | Cleaned Up | 그룹 완료 라벨 | |

---

## 12. SimilarPhoto (얼굴 비교)

### FaceComparisonViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 320 | 인물사진 비교정리 - 인물 {N} | Face Compare - Person {N} | 네비게이션 타이틀 | |
| 321 | 취소 | Cancel | 취소 버튼 | |
| 322 | 항목 선택 | Select Items | 선택 개수 라벨 | |
| 323 | {count}개 선택됨 | {count} Selected | 선택 개수 라벨 (동적) (plural 처리 필요 - 1 Selected / N Selected) | |
| 324 | 삭제 | Delete | 삭제 버튼 | |
| 325 | 사진을 먼저 선택하세요 | Please select photos first | alert 메시지 | |
| 326 | 확인 | OK | alert 버튼 | |
| 327 | 변경사항을 적용하시겠습니까? | Apply changes? | alert 메시지 (viewer) | |
| 328 | 적용 | Apply | alert 버튼 | |

---

## 13. Viewer

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 329 | 인물사진 비교정리 | Face Compare | 뷰어 상단 타이틀 | |
| 330 | 가능 | available | 뷰어 상단 키워드 (강조) | |
| 331 | 이전 사진 | Previous | 뷰어 툴바 버튼 | |
| 332 | 삭제하기 | Delete | 뷰어 툴바 삭제 버튼 | |
| 333 | 복구하기 | Restore | 뷰어 툴바 복구 버튼 | |
| 334 | 최종 삭제 | Erase | 뷰어 툴바 최종 삭제 버튼 | |
| 335 | 저품질 목록에서 제외 | Keep Photo | 뷰어 툴바 제외 버튼 | |
| 336 | 동영상을 로드할 수 없습니다 | Unable to load video | 비디오 에러 | |
| 337 | 재생 실패 | Playback Failed | 비디오 에러 | |

---

## 14. Referral

### ReferralMenuViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 338 | 친구 초대 | Invite Friends | UIMenu 제목 | |
| 339 | 친구 초대하기 | Invite Friends | 메뉴 액션 | |
| 340 | 초대 코드 입력 | Enter Referral Code | 메뉴 액션 | |
| 341 | 초대 혜택 받기 | Claim Referral Reward | 메뉴 액션 | |

### ReferralExplainViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 342 | 친구 초대하고\n함께 무료 혜택 받기 | Invite Friends,\nGet Rewards Together | 메인 제목 | |
| 343 | 함께 무료 혜택 받기 | Get Rewards Together | 키워드 (강조) | |
| 344 | 초대한 사람 | You | 보상 행 제목 | |
| 345 | 초대 1회마다 Pro 멤버십 14일 무료 혜택 제공 | 14 days of free Pro membership per invite | 보상 행 상세 | |
| 346 | 초대받은 사람 | Your Friend | 보상 행 제목 | |
| 347 | Pro 멤버십 14일 무료 혜택 제공 | 14 days of free Pro membership | 보상 행 상세 | |
| 348 | 초대하기 | Invite | 초대 버튼 | |
| 349 | 초대 링크를 생성하고 공유합니다 | Creates and shares an invite link | 접근성 힌트 | |
| 350 | 이미 Pro멤버십 이용 중이어도 14일 무료 연장 | Even if you're already Pro membership,\nget 14 extra days free | 부가 문구 | |
| 351 | 다시 시도 | Try Again | 재시도 버튼 (에러) | |
| 352 | 알 수 없는 에러입니다. | An unknown error occurred. | 에러 메시지 | |
| 353 | 알림이 없으면 보상 받기가 어려워요 | Don't Miss Your Reward | Push 프리프롬프트 제목 | |
| 354 | 친구가 등록하면 알려드릴까요? | Get notified when your friend signs up? | Push 프리프롬프트 메시지 | |
| 355 | 알림을 허용해야 친구가 등록했을 때\n바로 보상을 받을 수 있어요 | Enable notifications to get rewarded\nright when your friend joins | Push 프리프롬프트 상세 | |
| 356 | 알림 받기 | Enable Notifications | 알림 허용 버튼 | |
| 357 | 알림이 꺼져 있어요 | Notifications Are Off | 알림 비활성 alert 제목 | |
| 358 | 설정에서 SweepPic 알림을 켜야\n친구 등록 시 혜택을 바로 받을 수 있어요 | Turn on SweepPic notifications in Settings\nto claim rewards right away | 알림 비활성 alert 메시지 | |
| 359 | 설정으로 이동 | Open Settings | alert 버튼 | |
| 360 | 나중에 | Later | alert 버튼 | |
| 361 | 닫기 | Close | 닫기 버튼 | |

### ReferralCodeInputViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 362 | 초대 코드 입력 | Enter Referral Code | 제목 (입력 상태) | |
| 363 | 받은 초대 메시지 전체를 붙여넣으면\n자동으로 코드가 입력됩니다 | Paste the entire invite message\nand the code will be detected automatically | 설명 (입력 상태) | |
| 364 | 초대 메시지를 붙여넣으세요 | Paste invite message here | 텍스트뷰 placeholder | |
| 365 | 자동 붙여넣기 | Auto Paste | 붙여넣기 버튼 | |
| 366 | 코드 적용하기 | Apply Code | 액션 버튼 (inputReady) | |
| 367 | 혜택이 아직 적용되지 않았어요 | Your reward hasn't been applied yet | 제목 (matched) | |
| 368 | 아래 버튼을 눌러\n14일 프리미엄 혜택을 받으세요 | Tap below\nto claim 14 days of Pro free | 설명 (matched) | |
| 369 | 혜택 받기 | Claim Your Reward | 액션 버튼 (matched) | |
| 370 | 초대 코드 적용 완료 | Referral Code Applied | 제목 (redeemed) | |
| 371 | 이미 초대 코드가 적용되어 있습니다. | A referral code has already been applied. | 설명 (redeemed) | |
| 372 | 오류 | Error | 제목 (에러) | |
| 373 | 다시 시도 | Try Again | 재시도 버튼 | |
| 374 | 본인의 초대 코드는 사용할 수 없습니다. | You cannot use your own referral code. | 에러 메시지 | |
| 375 | 유효하지 않은 초대 코드입니다. | Invalid referral code. | 에러 메시지 | |
| 376 | 현재 일시적으로 오류가 발생했습니다.\n다음날 다시 시도해주세요. | A temporary error occurred.\nPlease try again tomorrow. | 에러 메시지 | |
| 377 | 알 수 없는 응답입니다. | Unknown response. | 에러 메시지 | |
| 378 | 서버에 연결할 수 없습니다. | Unable to connect to server. | 에러 메시지 | |
| 379 | 클립보드가 비어있습니다. | Clipboard is empty. | 에러 메시지 | |
| 380 | 초대 메시지를 붙여넣어 주세요. | Please paste the invite message. | 에러 메시지 | |
| 381 | 초대 코드를 찾을 수 없습니다.\n올바른 초대 메시지를 붙여넣어 주세요. | Referral code not found.\nPlease paste the correct invite message. | 에러 메시지 | |

### ReferralRewardViewController

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 382 | 초대 보상 도착! | Your Referral Reward Is Here! | 제목 (hasRewards) | |
| 383 | 초대한 사람이 SweepPic에 가입했어요!\n14일 무료 혜택을 받으세요 | Your friend joined SweepPic!\nClaim your 14-day free Pro reward | 설명 (hasRewards) | |
| 384 | 수령 가능한 보상: {count}건 | {count} rewards available | 보상 건수 (plural 처리 필요 - 1 reward available / N rewards available) | |
| 385 | 보상 받기 | Claim Reward | 액션 버튼 (hasRewards) | |
| 386 | 수령 가능한 보상이 없습니다 | No rewards available | 제목 (noRewards) | |
| 387 | 친구를 초대하고\nPro 멤버십 14일 무료 혜택을 받으세요! | Invite friends and\nget 14 days of Pro for free! | 설명 (noRewards) | |
| 388 | 친구 초대하기 | Invite Friends | 액션 버튼 (noRewards) | |
| 389 | 14일 무료 혜택이\n적용되었습니다! | 14 days of free Pro\nhas been applied! | 제목 (claimed) | |
| 390 | 확인 | OK | claimed 상태 버튼 | |
| 391 | 다시 시도 | Try Again | 재시도 버튼 (error) | |
| 392 | 보상 정보를 불러올 수 없습니다.\n잠시 후 다시 시도해주세요. | Unable to load reward info.\nPlease try again later. | 에러 메시지 | |
| 393 | 닫기 | Close | 닫기 버튼 | |

### Referral 에러 메시지 (추가)

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 394 | 서명 정보가 없습니다. | Signing information not found. | Promotional Offer 에러 | |
| 395 | 리딤 URL이 없습니다. | Redemption URL not found. | Offer Code 에러 | |
| 396 | 알 수 없는 보상 유형입니다. | Unknown reward type. | 보상 유형 에러 | |
| 397 | 서버 오류가 발생했습니다. | A server error occurred. | API 에러 폴백 | |
| 398 | 혜택 적용에 실패했습니다. 잠시 후 다시 시도해주세요. | Failed to apply reward. Please try again later. | StoreKit 에러 | |
| 399 | 일시적으로 혜택을 적용할 수 없습니다. | Unable to apply reward at this time. | 딥링크 코드풀 소진 | |
| 400 | 알 수 없는 에러가 발생했습니다. | An unexpected error occurred. | 일반 에러 (#352 "알 수 없는 에러입니다."와 구분) | |

### ReferralShareManager (공유 메시지)

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 401 | SweepPic 초대 | SweepPic Invite | 공유 시트 제목 | |

**#402 공유 본문 (한국어)**

```
편리한 사진 정리 앱 SweepPic을 추천합니다!
초대 링크로 가입하고 Pro멤버십 14일 무료 혜택을 받으세요!
(최초 등록 시 14+7일 무료 제공)

초대코드: {referralCode}

1. 아래 링크를 눌러 앱 설치

2. 앱 설치 후 아래 링크를 한 번 더 누르면 무료 혜택 자동 적용
(적용이 안되면 본 메시지를 통째로 복사해서 SweepPic앱 > 설정 > 초대코드입력에 붙여넣기 해주세요)

{shareURL}
```

**#402 공유 본문 (영어)**

```
Try SweepPic — the easy way to organize your photos!
Sign up with my invite link and get 14 days of Pro free!
(First-time users get 14+7 days free)

Invite code: {referralCode}

1. Tap the link below to install the app

2. After installing, tap the link again to activate your free Pro reward
(If it doesn't work, copy this entire message and paste it in SweepPic > Settings > Enter Referral Code)

{shareURL}
```

---

## 15. 서버 에러 메시지 (ReferralService.swift)

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 403 | 요청이 너무 많습니다. {retryAfter}초 후 다시 시도해주세요. | Too many requests. Please wait {retryAfter} seconds. | rateLimited | |
| 404 | 서버에 일시적인 문제가 있습니다. 잠시 후 다시 시도해주세요. | Server is temporarily unavailable. Please try again later. | serverUnavailable | |
| 405 | 네트워크 응답 시간이 초과되었습니다. | Network request timed out. | timeout | |
| 406 | 네트워크 연결을 확인해주세요. | Please check your network connection. | noConnection | |
| 407 | 서버 응답을 처리할 수 없습니다. | Unable to process server response. | decodingFailed | |
| 408 | 예상치 못한 서버 응답입니다. (코드: {code}) | Unexpected server response. (Code: {code}) | unexpectedStatus | |
| 409 | 서비스가 초기화되지 않았습니다. | Service not initialized. | 미설정 에러 | |
| 410 | 잘못된 URL입니다. | Invalid URL. | URL 에러 | |
| 411 | 잘못된 응답입니다. | Invalid response. | 응답 에러 | |
| 412 | 알 수 없는 에러입니다. | An unknown error occurred. | 기본 에러 | |

---

## 16. 접근성 전용 문자열 (주요 항목)

> UI 라벨과 동일한 접근성 문자열은 위 항목과 통합. 아래는 접근성 전용 문자열만.

| # | 한국어 (현재) | 영어 (제안) | 용도 | 파일 | 확인 |
|---|---|---|---|---|---|
| 413 | 사진 {index} / {total} | Photo {index} of {total} | 그리드 항목 | PhotoCell.swift | |
| 414 | , 삭제대기함에 있음 | , in Trash | 그리드 항목 추가 | PhotoCell.swift | |
| 415 | 삭제대기함 비우기 안내 | Trash cleanup guide | 게이트 카드 | TrashGatePopup | |
| 416 | 삭제 한도 게이지, {total}장 중 {remaining}장 남음 | Trash emptying limit, {remaining} of {total} remaining | 게이지 뷰 | UsageGaugeView | |
| 417 | 탭하면 한도 상세 정보를 볼 수 있습니다 | Tap for limit details | 게이지 힌트 | UsageGaugeView | |
| 418 | 광고를 보고 사진 삭제하기 | Watch ad to delete photos | 광고 버튼 | TrashGatePopup | |
| 419 | 광고를 시청한 후 사진을 삭제합니다 | Deletes photos after watching an ad | 광고 힌트 | TrashGatePopup | |
| 420 | Pro멤버십 안내 화면으로 이동합니다 | Goes to Pro membership info | Pro 힌트 | TrashGatePopup | |
| 421 | 팝업을 닫습니다 | Closes the popup | 닫기 힌트 | TrashGatePopup | |
| 422 | 한도 상세 팝업을 닫습니다 | Closes the limit detail popup | 닫기 힌트 | UsageGaugeView | |
| 453 | 광고를 보고 삭제 한도 10장 추가 | Watch ad to empty 10 more photos | watchAdButton accessibilityLabel | UsageGaugeView | |
| 423 | 초대 설명 화면으로 이동합니다 | Goes to invite explanation | 초대 힌트 | 여러 파일 | |
| 424 | 닫기 | Close | 닫기 버튼 | 여러 파일 | |
| 425 | 페이월 화면을 닫습니다 | Closes the paywall | 닫기 힌트 | PaywallVC | |
| 426 | 멤버십 플랜 선택 | Choose membership plan | 플랜 선택 | PaywallVC | |
| 427 | 이전에 구매한 멤버십을 복원합니다 | Restores a previous purchase | 복원 힌트 | PaywallVC | |
| 428 | 프로모션 코드를 입력합니다 | Enter a promotion code | 리딤 힌트 | PaywallVC | |
| 429 | 축하 화면을 닫습니다 | Closes the celebration screen | 확인 힌트 | CelebrationVC | |
| 430 | 광고 맞춤 설정 아이콘 | Ad personalization icon | ATT 아이콘 | ATTPromptVC | |
| 431 | 계속하여 추적 허용 여부 선택 | Continue to choose tracking preference | ATT 계속 | ATTPromptVC | |
| 432 | 탭하면 답변을 펼칩니다 | Tap to expand answer | FAQ 힌트 (닫힘) | FAQViewController | |
| 433 | 탭하면 답변을 접습니다 | Tap to collapse answer | FAQ 힌트 (열림) | FAQViewController | |
| 434 | 인물 {personIndex} 비교 | Compare person {personIndex} | 얼굴 버튼 | FaceButtonOverlay | |
| 435 | 탭하여 이 인물의 사진들을 비교합니다 | Tap to compare this person's photos | 얼굴 버튼 힌트 | FaceButtonOverlay | |
| 493 | Pro멤버십으로 삭제 한도 무제한 | No limit on emptying Trash with Pro membership | UsageGaugeView proButton accessibilityLabel (기존 #112 "Go Unlimited with Pro"와 별개의 접근성 전용 문자열) | UsageGaugeView | |

---

## 17. AppCore 에러 메시지

### PromotionalOfferService.OfferError

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 454 | 상품을 찾을 수 없습니다. ({id}) | Product not found. ({id}) | productNotFound | |
| 455 | 구매가 취소되었습니다. | Purchase was canceled. | userCanceled | |
| 456 | 구매가 대기 중입니다. | Purchase is pending. | purchasePending | |
| 457 | 혜택 적용에 실패했습니다: {error} | Failed to apply reward: {error} | storeKitError | |
| 458 | 거래 검증에 실패했습니다. | Transaction verification failed. | verificationFailed | |

### TrashStoreError

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 459 | 디스크 공간이 부족합니다 | Not enough disk space | diskSpaceFull | |
| 460 | 파일 저장 실패: {error} | Failed to save file: {error} | fileSystemError | |
| 461 | 데이터 인코딩 실패: {error} | Data encoding failed: {error} | encodingFailed | |

### AnalysisError

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 462 | 이미지 로드 실패: {assetID}... | Image load failed: {assetID}... | imageLoadFailed | |
| 463 | 분석 타임아웃 (5초 초과) | Analysis timed out (over 5 seconds) | timeout | |
| 464 | 비디오 프레임 추출 실패: {assetID}... | Video frame extraction failed: {assetID}... | videoFrameExtractionFailed | |

### CleanupImageLoadError

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 465 | 이미지 로딩 실패: {reason} | Image loading failed: {reason} | loadFailed | |
| 466 | 이미지 로딩 타임아웃 | Image loading timed out | timeout | |
| 467 | 잘못된 이미지 형식 | Invalid image format | invalidFormat | |

### VideoFrameExtractError

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 468 | 동영상 URL을 가져올 수 없습니다 | Unable to get video URL | urlNotAvailable | |
| 469 | 프레임 추출 실패: {reason} | Frame extraction failed: {reason} | extractionFailed | |
| 470 | 동영상이 너무 짧습니다 | Video is too short | tooShort | |
| 471 | 동영상이 아닙니다 | Not a video | notVideo | |
| 472 | 모든 프레임 추출 실패 | All frame extractions failed | allFailed | |

---

## 참고: 서버 에러 메시지 (코드 전환 대상)

> 서버에서 클라이언트로 내려보내는 한글 메시지. 향후 에러 코드 기반으로 전환 예정.

### 서버 에러 코드

| # | 서버 코드 (전환 예정) | 현재 한글 | 영어 (전환 후) | 확인 |
|---|---|---|---|---|
| 473 | server_error | 서버 오류가 발생했습니다. | A server error occurred. | |
| 474 | code_creation_failed | 코드 생성에 실패했습니다. 잠시 후 다시 시도해주세요. | Failed to create code. Please try again later. | |
| 475 | referral_not_found | 해당 초대 기록을 찾을 수 없습니다. | Referral record not found. | |
| 476 | invalid_request | 잘못된 요청입니다. | Invalid request. | |
| 477 | reward_not_found | 해당 보상을 찾을 수 없습니다. | Reward not found. | |
| 478 | reward_expired | 보상 수령 기간이 만료되었습니다. | Reward has expired. | |
| 479 | signing_failed | 서명 생성에 실패했습니다. 잠시 후 다시 시도해주세요. | Signing failed. Please try again later. | |
| 480 | temporary_error | 현재 일시적으로 오류가 발생했습니다. 다음날 다시 시도해주세요. | A temporary error occurred. Please try again tomorrow. | |
| 481 | reward_not_pending | 보상이 수령 대기 상태가 아닙니다. | Reward is not in pending state. | |
| 482 | invalid_format | 잘못된 요청 형식입니다. | Invalid request format. | |
| 483 | push_query_failed | 조회 실패 | Query failed. | |
| 484 | push_internal_error | 내부 오류 | Internal error. | |
| 494 | unknown_endpoint | 알 수 없는 엔드포인트입니다. | Unknown endpoint. | |

### 랜딩 페이지 문자열

| # | 한국어 (현재) | 영어 (제안) | 용도 | 확인 |
|---|---|---|---|---|
| 485 | 친구가 14일 프리미엄을 선물했어요! | Your friend gifted you 14 days of Pro! | OG/Twitter 메타 | |
| 486 | 14일 프리미엄 무료 혜택을 받���보세요! | Get 14 days of Pro free! | ���딩 페이지 본문 | |
| 487 | 앱을 설치해보세요! | Install the app! | 랜딩 페이지 본문 | |

---

### 참고: 날짜 포맷 코드 변경 대상

아래 파일의 DateFormatter 하드코딩을 setLocalizedDateFormatFromTemplate으로 변경 필요:

| 파일 | 현재 포맷 | 변경할 템플릿 |
|---|---|---|
| CleanupMethodSheet.swift:233 | "yyyy년 M월" | "yMMM" |
| CleanupMethodSheet.swift:242 | "M월" | "MMM" |
| CleanupProgressView.swift:337 | "yyyy년 M월" | "yMMM" |
| FaceScanMethodSheet.swift:210 | "yyyy년 M월" | "yMMM" |

---

**총 문자열 수: 약 494개**

> 이 문서는 주인님의 확인/수정 후 확정됩니다. 각 항목의 "확인" 열에 ✅ 또는 수정 내용을 기입해주세요.
