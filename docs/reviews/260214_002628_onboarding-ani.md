검토 결과, 문서 목표(“그리드 스와이프 삭제를 직관적으로 학습”) 자체는 타당하지만 현재 계획만으로는 **실제 노출 안정성/정책 일치성에서 핵심 누락**이 있습니다.

1. `[높음]` 1회 스케줄 구조라 표시 실패 시 영구 미노출될 수 있습니다.  
`docs/260211onboarding-ani.md:313`~`docs/260211onboarding-ani.md:322`에서 `hasScheduledCoachMark = true`를 먼저 세팅하고 2초 후 표시하는데, 표시 시점 조건 실패(스크롤 중/화면 이탈) 시 재시도 규칙이 없습니다. `finishInitialDisplay`는 1회성(`SweepPic/SweepPic/Features/Grid/GridScroll.swift:361`~`SweepPic/SweepPic/Features/Grid/GridScroll.swift:364`)이라 다시 스케줄되지 않습니다.

2. `[높음]` `hasScheduledCoachMark` 저장 방식이 문서에 없어 구현 시 컴파일/설계 공백이 납니다.  
`GridViewController` extension 파일에서 stored property를 바로 추가할 수 없는데, 문서에는 저장 전략이 없습니다(`docs/260211onboarding-ani.md:313`). 현재 프로젝트는 extension 상태를 `objc_get/setAssociatedObject`로 해결하는 패턴을 이미 씁니다(`SweepPic/SweepPic/Features/Grid/GridViewController+Cleanup.swift:254`~`SweepPic/SweepPic/Features/Grid/GridViewController+Cleanup.swift:262`).

3. `[높음]` 상위 온보딩 정책과 불일치 가능성이 있습니다(실제 제스처 dismiss 시 “shown” 처리).  
상위 문서는 “실제 제스처 수행 시 dismiss”를 스킵 정책으로 명시합니다(`docs/260211onboarding.md:200`~`docs/260211onboarding.md:202`). 이번 문서는 `handleSwipeDeleteBegan`에서 dismiss만 추가(`docs/260211onboarding-ani.md:340`, `SweepPic/SweepPic/Features/Grid/BaseGridViewController.swift:795`)하고 `markAsShown()` 호출 시점이 명확하지 않아 재노출 버그 위험이 있습니다.

4. `[중간]` 터치 패스스루 설계가 오버레이 정합성을 깨뜨릴 수 있습니다.  
문서가 버튼 외 터치를 아래로 통과시키는데(`docs/260211onboarding-ani.md:301`), 오버레이는 특정 셀 스냅샷/프레임 기반이라 스크롤/탭이 들어가면 하이라이트 위치와 실제 UI가 어긋날 수 있습니다.

5. `[중간]` Stage 3 커스텀 easing 구현 설명이 기술적으로 불안정합니다.  
`CATransaction.setAnimationTimingFunction + UIView.animate` 조합(`docs/260211onboarding-ani.md:173`~`docs/260211onboarding-ani.md:177`)은 UIView 속성 애니메이션에 일관되게 원하는 cubic-bezier를 보장하지 않습니다. `UIViewPropertyAnimator + UICubicTimingParameters`로 명시하는 쪽이 안전합니다.

6. `[중간]` 파일 경로 표기가 현재 레포 기준으로 부정확합니다.  
문서의 `SweepPic/Shared/...`, `SweepPic/Features/...`(`docs/260211onboarding-ani.md:21`~`docs/260211onboarding-ani.md:22`) 대신 실제 소스 루트는 `SweepPic/SweepPic/...`입니다.

7. `[중간]` “Reduce Motion 대응은 앱 심사 필수” 문구는 과도하게 단정적입니다.  
`docs/260211onboarding-ani.md:264`는 “필수”라고 적었지만, Apple 가이드는 접근성 지원을 권장/요구 맥락으로 서술하며 해당 문구처럼 단일 체크리스트 항목으로 못 박혀 있진 않습니다. 표현을 “강력 권장 및 접근성 품질 기준” 정도로 수정하는 게 정확합니다.

8. `[낮음]` 근거 수치/출처 연결이 부족합니다.  
NNGroup 점수(4.92/5.49), WWDC23 권장 문구 등은 본문에 출처 링크가 없어 검증 가능성이 떨어집니다(`docs/260211onboarding-ani.md:37`, `docs/260211onboarding-ani.md:223`).

코드 참조 정확성 체크:
1. `BaseGridViewController.swift:795` 참조는 현재 정확합니다 (`SweepPic/SweepPic/Features/Grid/BaseGridViewController.swift:795`).  
2. `GridScroll.swift:420` 참조도 현재 정확합니다 (`SweepPic/SweepPic/Features/Grid/GridScroll.swift:420`).  
3. 실제 스와이프 동작 설명(50%/800pt/s/0.15s/마룬 딤드)은 코드와 일치합니다 (`SweepPic/SweepPic/Features/Grid/BaseGridViewController.swift:853`~`SweepPic/SweepPic/Features/Grid/BaseGridViewController.swift:856`, `SweepPic/SweepPic/Features/Grid/PhotoCell.swift:886`, `SweepPic/SweepPic/Features/Grid/PhotoCell.swift:1013`~`SweepPic/SweepPic/Features/Grid/PhotoCell.swift:1018`).

웹 확인에 사용한 자료:
- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/  
- Apple HIG Motion: https://developer.apple.com/design/human-interface-guidelines/motion  
- Apple Reduce Motion change notification API: https://developer.apple.com/documentation/uikit/uiaccessibility/reducemotionstatusdidchangenotification  
- Material Motion (easing/duration 참고): https://material.io/archive/guidelines/motion/duration-easing.html

원하시면 위 1~5번 이슈를 반영한 `docs/260211onboarding-ani.md` 수정안(v2)까지 바로 작성해드리겠습니다.