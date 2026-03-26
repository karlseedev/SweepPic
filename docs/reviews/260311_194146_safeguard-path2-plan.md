**Findings (심각도 순)**  
1. **High**: 계획안만으로는 Path2 단독 케이스에서 기존 SafeGuard 의미(메타데이터+얼굴)를 완전히 재현하지 못합니다. 현재 Stage4는 메타데이터(`depthEffect`)를 먼저 보고 얼굴을 봅니다. Path2에 얼굴만 추가하면 `depthEffect` 보호가 비어 있는 구간이 생깁니다.  
[SafeGuardChecker.swift:67](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/AutoCleanup/Analysis/SafeGuardChecker.swift:67)  
[QualityAnalyzer.swift:232](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/AutoCleanup/Analysis/QualityAnalyzer.swift:232)  
[CleanupPreviewService.swift:267](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/AutoCleanup/Preview/CleanupPreviewService.swift:267)

2. **High**: `SafeGuard 적용 시 continue`를 넣으면 진행률 보고가 누락될 수 있습니다. 지금 진행률 보고는 분기 뒤쪽 1곳에만 있습니다.  
[CleanupPreviewService.swift:323](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/AutoCleanup/Preview/CleanupPreviewService.swift:323)

3. **Medium**: `oldResult.safeGuardApplied` 재사용은 빠른 최적화로 유효하지만, 의미가 “얼굴”만은 아닙니다(`depthEffect` 포함). 목표가 “얼굴 SafeGuard”라면 이유 필터(`.clearFace`만) 여부를 명확히 해야 합니다.  
[QualityResult.swift:120](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/AutoCleanup/Models/QualityResult.swift:120)  
[QualityResult.swift:176](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/AutoCleanup/Models/QualityResult.swift:176)

4. **Medium**: 성능 영향이 큽니다. Path2(any) 조건은 deep(<0.2)까지 포함되어 대상이 넓고, 이미 텍스트 Vision도 도는 구조라 얼굴 Vision 추가 시 iOS18 스캔 시간이 눈에 띄게 증가할 가능성이 높습니다.  
[CleanupPreviewService.swift:255](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/AutoCleanup/Preview/CleanupPreviewService.swift:255)  
[CleanupPreviewService.swift:280](/Users/karl/Project/Photos/iOS/SweepPic/SweepPic/Features/AutoCleanup/Preview/CleanupPreviewService.swift:280)

5. **Low**: `checkFaceQualityDetailed`의 `maxFaceQuality`는 `Optional` 권장입니다(얼굴 0개와 품질 0.0 구분). 디버그/튜닝 품질이 좋아집니다.

**질문별 답변**  
1. **충분한가?** 부분적으로 충분합니다. 다만 Path2에 `checkMetadata`까지 포함해야 누락이 없습니다.  
2. **누락/엣지케이스?** `depthEffect` 공백, `continue` 시 progress 누락, 얼굴 0개/품질 nil 구분, Vision 실패 시 처리 정책(권장: fail-open + 로깅).  
3. **구조적 오류?** 큰 구조 오류는 없지만 `continue` 위치/중복 Vision 호출 설계는 주의 필요.  
4. **loadedImage 스코프 확장 안전?** 네, per-asset 로컬 변수로 확장하면 안전합니다.  
5. **oldResult.safeGuardApplied 재사용 논리?** 빠른 경로로 타당하지만 “얼굴 전용” 요구와 의미가 다를 수 있어 reason 체크가 필요합니다.  
6. **성능 영향?** iOS18에서 중~고 영향 예상(특히 deep 단계 대상이 넓음).  
7. **iOS16-17 호환성?** `#available(iOS 18.0, *)` 블록 안에서만 Path2 SafeGuard 실행하면 문제 없습니다.  
8. **교차 검토 결론**: 방향은 맞고, 아래 2개를 추가하면 안정적입니다.  
1. Path2 SafeGuard 순서: `oldResult 재사용 -> checkMetadata -> checkFaceQualityDetailed`  
2. SafeGuard로 제외할 때도 progress/report 경로는 반드시 통과하도록 구조화