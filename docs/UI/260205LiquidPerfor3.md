# LiquidGlassKit 로컬 패키지 전환

> **선행 문서**: [260205LiquidPerfor2.md](260205LiquidPerfor2.md) — 렌더링 파이프라인 최적화 계획 (Group A~C)
>
> 이 문서는 Perfor2의 **그룹 C 구현을 위한 인프라 전환**입니다.
> DerivedData SPM checkout 직접 수정 → 로컬 패키지 방식으로 전환하여,
> `import LiquidGlassKit` 후 새 public API 추가가 가능한 환경을 구축합니다.

---

## 왜 전환하는가

DerivedData SPM checkout 직접 수정 방식의 문제:

| 문제 | 영향 |
|------|------|
| 클린 빌드 시 모든 수정 소실 | Group A blur=0 등 기존 수정도 위험 |
| git에 변경 이력 없음 | DerivedData는 gitignore 대상 |
| 새 public 심볼 추가 불가 | .swiftmodule 인터페이스 갱신 안 됨 → C-1 빌드 실패 원인 |
| 값 변경만 가능 | internal 코드 값 수정은 되지만 API 확장 불가 |

Perfor2 C-1 구현 중 `Cannot find 'LiquidGlassSettings' in scope` 빌드 에러로 확인됨.

---

## 전환 계획

### Step 1: LiquidGlassKit 소스 복사

DerivedData의 현재 수정된 소스를 프로젝트 루트로 복사.

```
복사 원본: DerivedData/.../SourcePackages/checkouts/LiquidGlassKit/
복사 대상: /Users/karl/Project/Photos/iOS/LiquidGlassKit/
```

복사 후 구조:
```
iOS/
├── Package.swift              # AppCore
├── Sources/AppCore/
├── LiquidGlassKit/            <-- 여기 (AppCore와 같은 레벨)
│   ├── Package.swift          # swift-tools-version: 6.2, iOS 13+
│   └── Sources/LiquidGlassKit/
│       ├── LiquidGlassView.swift        (Group A blur=0 + C-1 frameCounter 포함)
│       ├── LiquidGlassSettings.swift    (C-1 public enum)
│       ├── LiquidGlassEffectView.swift
│       ├── LiquidLensView.swift
│       ├── LiquidGlassSlider.swift
│       ├── LiquidGlassSwitch.swift
│       ├── ZeroCopyBridge.swift
│       ├── LiquidGlassFragment.metal
│       └── LiquidGlassVertex.metal
├── PickPhoto/
└── docs/
```

**복사할 것**: `Package.swift`, `Sources/` 디렉토리
**복사 안 할 것**: `.git/`, `.swiftpm/`, `BUILD`, `README.md`, `Info.plist`

### Step 2: C-1 코드 정리 (로컬 소스에서)

DerivedData에 KVC 우회용으로 수정된 코드를 LiquidGlassSettings 방식으로 전환.

**LiquidGlassView.swift:**
```swift
// 제거:
@objc dynamic var captureInterval: Int = 1

// draw()에서 변경:
// captureInterval → LiquidGlassSettings.captureInterval
```

**LiquidGlassSettings.swift:**
- 이미 생성되어 있음, 변경 불필요

### Step 3: project.pbxproj 수정 (3곳)

ID `CB9721C02EF4000000F85BF4`는 유지하고 타입만 변경.

**A. packageReferences 배열 (라인 228):**
```
변경 전: CB9721C02EF4000000F85BF4 /* XCRemoteSwiftPackageReference "LiquidGlassKit" */,
변경 후: CB9721C02EF4000000F85BF4 /* XCLocalSwiftPackageReference "../LiquidGlassKit" */,
```

**B. 패키지 정의 (라인 636-643):**

XCRemoteSwiftPackageReference section에서 삭제하고 XCLocalSwiftPackageReference section에 추가:
```
변경 전:
    CB9721C02EF4000000F85BF4 /* XCRemoteSwiftPackageReference "LiquidGlassKit" */ = {
        isa = XCRemoteSwiftPackageReference;
        repositoryURL = "https://github.com/karlseedev/LiquidGlassKit.git";
        requirement = {
            branch = master;
            kind = branch;
        };
    };

변경 후 (XCLocalSwiftPackageReference section에):
    CB9721C02EF4000000F85BF4 /* XCLocalSwiftPackageReference "../LiquidGlassKit" */ = {
        isa = XCLocalSwiftPackageReference;
        relativePath = ../LiquidGlassKit;
    };
```

상대 경로: `../LiquidGlassKit` (AppCore의 `../../iOS` 패턴과 동일)

**C. ProductDependency 주석 (라인 658):**
```
변경 전: package = CB9721C02EF4000000F85BF4 /* XCRemoteSwiftPackageReference "LiquidGlassKit" */;
변경 후: package = CB9721C02EF4000000F85BF4 /* XCLocalSwiftPackageReference "../LiquidGlassKit" */;
```

### Step 4: Package.resolved 정리

로컬 패키지는 Package.resolved에 기록되지 않으므로 LiquidGlassKit 항목 제거.

파일: `PickPhoto.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

라인 13-21의 LiquidGlassKit 항목 삭제. originHash는 Xcode가 다음 resolve 시 자동 갱신.

### Step 5: LiquidGlassOptimizer.swift — C-1 연동

```swift
import LiquidGlassKit  // 추가

static var scrollCaptureInterval: Int = 3  // 추가

// optimize(): LiquidGlassSettings.captureInterval = scrollCaptureInterval
// restore():  LiquidGlassSettings.captureInterval = 1
```

### Step 6: 빌드 검증

### Step 7: 커밋

---

## 수정 파일 목록

| 파일 | 작업 |
|------|------|
| `iOS/LiquidGlassKit/` (새 디렉토리) | DerivedData에서 소스 복사 |
| `LiquidGlassView.swift` (로컬) | @objc dynamic 제거, Settings 참조로 전환 |
| `LiquidGlassSettings.swift` (로컬) | 그대로 유지 (이미 생성됨) |
| `project.pbxproj` | Remote → Local 전환 (3곳) |
| `Package.resolved` | LiquidGlassKit 항목 제거 |
| `LiquidGlassOptimizer.swift` | import LiquidGlassKit + Settings 연동 |

---

## 리스크 검토

### 확인된 안전 사항

- **Metal 셰이더**: SPM에서 .metal 파일은 소스로 자동 컴파일됨 (resources 등록 불필요). 현재 원격 패키지에서도 동일 동작.
- **swift-tools-version: 6.2**: 현재 원격에서도 동일 버전으로 정상 동작 중. 변경 불필요.
- **iOS/Package.swift 충돌**: 없음. Xcode 프로젝트가 직접 SPM 의존성 관리. AppCore와 LiquidGlassKit은 독립 패키지.
- **.gitignore**: `Packages/` 무시 설정 있으나, `LiquidGlassKit/`은 해당 안 됨.
- **Info.plist**: Bazel 빌드용. SPM에서 불필요, 복사 안 함.

### 주의 사항

1. **pbxproj 수동 수정**: 형식 오류 시 Xcode가 프로젝트를 열지 못함 → 커밋 후 작업하여 즉시 롤백 가능하게
2. **DerivedData 캐시 충돌**: 원격 패키지 빌드 캐시가 남아있으면 로컬 패키지와 충돌 → 빌드 실패 시 클린 빌드
3. **DerivedData의 기존 수정 상태**: 복사 시 현재 수정 포함 (Group A blur=0 + C-1 KVC 코드) → Step 2에서 정리

---

## 전환 후 효과

| 항목 | 전환 전 (DerivedData) | 전환 후 (로컬 패키지) |
|------|----------------------|---------------------|
| 클린 빌드 안전성 | 수정 소실 | git에 보존 |
| 변경 이력 추적 | 불가 | git diff/log |
| public API 추가 | 모듈 인터페이스 미갱신 | 정상 동작 |
| import LiquidGlassKit | 기존 심볼만 접근 | 새 심볼도 접근 |
| C-1~C-4 구현 | KVC 우회 필요 | 타입 안전한 Swift 코드 |
