# iOS 26 Liquid Glass NavigationBar 구현 자료

**작성일**: 2026-01-26
**상태**: 🔜 탭바 구현 후 상세화 예정

---

## 1. 개요

NavigationBar는 TabBar보다 복잡한 구조를 가짐:
- Platter 버튼 (좌/우)
- 타이틀 영역
- glassBackground 필터 (iOS 26 신규)
- CAMatchPropertyAnimation (속성 동기화)

---

## 2. 핵심 차이점 (vs TabBar)

| 항목 | TabBar | NavigationBar |
|------|--------|---------------|
| Platter 위치 | 중앙 1개 | 좌/우 분리 |
| 새 필터 | - | glassBackground |
| 컴포지팅 | destOut | normalBlendMode |
| 애니메이션 | matchPosition | matchBounds, matchCornerRadius 등 |
| cornerRadius | 27 | 22 |

---

## 3. 발견된 필터

| 필터 | 용도 |
|------|------|
| vibrantColorMatrix | 아이콘/텍스트 색상 |
| gaussianBlur | 블러 |
| glassBackground | 유리 배경 (신규) |
| normalBlendMode | 컴포지팅 |

---

## 4. 발견된 애니메이션

| 애니메이션 | key |
|------------|-----|
| CAMatchPropertyAnimation | match-bounds |
| CAMatchMoveAnimation | match-position |
| CAMatchPropertyAnimation | match-corner-radius |
| CAMatchPropertyAnimation | match-corner-radii |
| CAMatchPropertyAnimation | match-corner-curve |
| CAMatchPropertyAnimation | match-hidden |

---

## 5. Transform 값

NavBar Platter에서 발견된 스케일 변환:

```swift
// 0.91배 스케일
let scale1: [CGFloat] = [
    0.9128709291752769, 0, 0, 0,
    0, 0.9128709291752769, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
]

// 1.095배 스케일
let scale2: [CGFloat] = [
    1.0954451150103321, 0, 0, 0,
    0, 1.0954451150103321, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
]
```

---

## 6. 원본 데이터

| 파일 | 크기 |
|------|------|
| navbar_filters.json | 50KB |
| navbar_structure.json | 3KB |
| navbar_full_1.json ~ 7 | 660KB (7파트) |
| navbar_animations.json | 9KB |

---

## TODO

- [ ] 탭바 구현 완료 후 상세 분석
- [ ] glassBackground 필터 리버스 엔지니어링
- [ ] Platter 애니메이션 구현
