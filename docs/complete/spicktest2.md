# Gate 3 Spike Test 결과 요약 (핀치 줌/앵커)

본 문서는 Gate 3(핀치 줌: 1열/3열/5열 전환) 스파이크 테스트 결과를 정리한 것입니다.  
수동(육안) 테스트는 체감 차이가 명확하지 않아 **스킵**하고, **Auto 테스트 결과**를 기준으로 판단하였습니다.

## 1. 테스트 목적

1) 핀치 줌 전환(3↔1, 3↔5) 시 **앵커 유지**가 가능한지 검증합니다.  
2) 전환 중 **끊김(hitch)**이 제품 목표에 부합하는지 확인합니다.  
3) 전환 정책(임계값/쿨다운) 기본값을 확정합니다.

## 2. 전제/설정

- 화면/기능: 그리드(색상 더미 셀) + 핀치 줌 전환
- 전환 단계: 1열 / 3열 / 5열 (3단)
- 기본 파라미터:
  - threshold: 0.85 / 1.15
  - cooldown: 200ms
  - items: 10,000
- Auto 테스트 spot: Top / Center / Bottom
- Auto 테스트 전환 시퀀스: 3→1 → 1→3 → 3→5 → 5→3

## 3. 측정 지표(요약)

### 3.1 Anchor drift (px)

- 정의: 전환 후에도 “핀치 중심에 가장 가까운 항목”이 화면에서 같은 위치에 머무는 정도
- 목표: max drift가 작고(가능하면 20px 이하), 큰 점프가 재현되지 않을 것

### 3.2 Hitch (두 관점)

Auto 전환은 측정 구간이 짧아서, Apple 방식의 `ms/s`가 과대평가될 수 있어 **두 관점**을 함께 기록합니다.

- Apple Hitch Time Ratio (ms/s): 참고용(짧은 구간에서 과대평가 가능)
- longest hitch (연속 드랍): 체감에 더 가까운 1차 지표
  - Gate 3 종료 기준(현재): longest hitch가 2프레임 이상으로 자주 발생하지 않을 것

## 4. Auto 테스트 결과(최종 런들)

아래 2회 Auto 런에서 공통적으로:
- drift avg/max: **0px**
- longest hitch: **16.7ms (1f)**
- dropped: **1**
- hitchTime max: **9.1~9.9ms**
- Apple(ms/s) max: **26.7~29.1 ms/s** (참고)

### 4.1 런 A

- Apple(ms/s) max: 29.1 ms/s
- longest hitch: 16.7ms (1f), dropped: 1
- drift max: 0px
- Auto grade: Warning (Apple(ms/s) grade: Critical)

### 4.2 런 B

- Apple(ms/s) max: 26.7 ms/s
- longest hitch: 16.7ms (1f), dropped: 1
- drift max: 0px
- Auto grade: Warning (Apple(ms/s) grade: Critical)

## 5. 결론(결정)

### 5.1 결론

- **앵커 유지(드리프트)**는 안정적으로 달성되었습니다. (drift가 0px로 반복)
- **전환 hitch**는 Apple `ms/s`로는 Critical로 찍히는 경우가 있으나, **longest hitch 관점에서는 최악이 1프레임(16.7ms) 1회 수준**으로 관찰되었습니다.
- 따라서 Gate 3은 **“Warning 허용” 기준으로 종료**합니다.

### 5.2 Gate 3에서 확정(현 시점)

1) 전환 단계: 1열 / 3열 / 5열 (3단 유지)  
2) 앵커 규칙: 기본 사진앱과 동일한 목표(핀치 중심 근처 항목 유지)로 진행  
3) 기본 파라미터: threshold 0.85/1.15, cooldown 200ms  
4) Gate 3 종료 기준(우리 기준):
   - drift: max 20px(권장) 이내(현재는 0px)
   - longest hitch: 2f 이상이 “반복적으로” 발생하지 않을 것(현재는 1f 1회 수준)

## 6. 후속(Gate 4 제안)

Gate 4(성능/120Hz)에서 “실기기/실제 이미지 로딩 포함” 조건으로 다음을 확인하시는 것을 권장드립니다.

1) ProMotion(120Hz) 실기기에서의 longest hitch(전환/스크롤)  
2) 이미지 로딩(요청/취소/인플라이트)이 더해졌을 때도 longest hitch가 2f 이상으로 반복되는지  

만약 Gate 4에서 2f 이상 hitch가 자주 재현된다면, 그 시점에 “3→5 전환 방식(레이아웃 전환/애니메이션 방식)”을 바꾸는 플랜을 시작하는 것이 합리적입니다.

