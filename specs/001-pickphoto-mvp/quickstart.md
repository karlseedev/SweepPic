# Quickstart: PickPhoto MVP

**Branch**: `001-pickphoto-mvp`
**Created**: 2025-12-16

## Prerequisites

| 항목 | 최소 요구사항 | 권장 |
|------|-------------|------|
| macOS | Ventura (13.0) | Sonoma (14.0+) |
| Xcode | 15.0 | 15.2+ |
| iOS SDK | 16.0 | 17.0+ |
| Swift | 5.9 | 5.9+ |

## Project Structure

```
iOS/
├── Package.swift              # AppCore Swift Package
├── Sources/AppCore/           # 비즈니스 로직
├── Tests/AppCoreTests/        # 패키지 테스트
├── PickPhoto/                 # iOS 앱
│   └── PickPhoto.xcodeproj
├── docs/                      # PRD, TechSpec
├── specs/                     # Feature specs
│   └── 001-pickphoto-mvp/
└── test/Spike1/               # Spike 테스트 앱
```

## Getting Started

### 1. Clone & Setup

```bash
cd /Users/karl/Project/Photos/iOS
```

### 2. Build Swift Package

```bash
# AppCore 패키지 빌드
swift build

# 테스트 실행
swift test
```

### 3. Open in Xcode

```bash
# Xcode에서 프로젝트 열기
open PickPhoto/PickPhoto.xcodeproj
```

### 4. Select Target & Run

1. Xcode에서 `PickPhoto` 스킴 선택
2. 시뮬레이터 또는 실기기 선택
3. `Cmd + R`로 실행

## Development Workflow

### AppCore 패키지 개발

```bash
# 패키지 빌드
swift build

# 특정 타겟만 빌드
swift build --target AppCore

# 테스트 실행
swift test

# 특정 테스트만 실행
swift test --filter AppCoreTests
```

### iOS 앱 개발

```bash
# 커맨드라인 빌드
xcodebuild -project PickPhoto/PickPhoto.xcodeproj \
    -scheme PickPhoto \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 15'

# Xcode에서 직접 빌드/실행 권장
```

### Spike 테스트 앱 실행

Spike 테스트 앱은 성능 검증용입니다.

```bash
# Xcode에서 열기
open test/Spike1/Spike1Test/Spike1Test.xcodeproj

# Spike1Test 스킴 선택 후 실행
```

## Configuration

### Info.plist Keys

앱에서 사진 라이브러리 접근을 위해 필요한 권한 키:

```xml
<!-- 사진 라이브러리 읽기/쓰기 -->
<key>NSPhotoLibraryUsageDescription</key>
<string>사진을 보고 정리하기 위해 사진 라이브러리 접근이 필요합니다.</string>

<!-- 사진 추가 전용 (필요시) -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>사진을 저장하기 위해 사진 라이브러리 접근이 필요합니다.</string>
```

### Build Settings

| 설정 | 값 |
|------|-----|
| iOS Deployment Target | 16.0 |
| Swift Language Version | 5.9 |
| Build Active Architecture Only (Debug) | Yes |

## Testing

### Unit Tests

```bash
# AppCore 패키지 테스트
swift test

# Xcode에서 테스트
xcodebuild test -project PickPhoto/PickPhoto.xcodeproj \
    -scheme PickPhoto \
    -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Performance Tests (Spike)

1. `test/Spike1/Spike1Test.xcodeproj` 열기
2. 실기기 연결 (권장: 5만장 사진 라이브러리)
3. 각 Gate 테스트 실행

### Instruments Profiling

```bash
# Time Profiler
xcrun xctrace record --template 'Time Profiler' \
    --launch PickPhoto.app

# Core Animation (hitch 측정)
xcrun xctrace record --template 'Core Animation' \
    --launch PickPhoto.app
```

## Debugging Tips

### PhotoKit 권한 문제

```swift
// 권한 상태 확인
let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
print("Photo Library Status: \(status.rawValue)")
```

### 메모리 사용량 확인

```swift
// 현재 메모리 사용량
func reportMemory() {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    let kerr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    if kerr == KERN_SUCCESS {
        print("Memory: \(info.resident_size / 1024 / 1024) MB")
    }
}
```

### Hitch 측정 (Debug)

```swift
// CADisplayLink 기반 hitch 측정
class HitchMonitor {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var baseline: CFTimeInterval = 1/60.0 // 60Hz default

    func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func tick(_ link: CADisplayLink) {
        let delta = link.timestamp - lastTimestamp
        if delta > baseline * 1.5 {
            print("Hitch detected: \(delta * 1000)ms")
        }
        lastTimestamp = link.timestamp
    }
}
```

## Common Issues

### "Photos access denied"

1. 설정 앱 → 개인정보 보호 → 사진 → PickPhoto 활성화
2. 시뮬레이터: Device → Erase All Content and Settings 후 재시도

### "Module 'AppCore' not found"

```bash
# Package.resolved 재생성
rm -rf .build Package.resolved
swift package resolve
```

### Slow build times

```bash
# DerivedData 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/PickPhoto-*
```

## References

- [spec.md](./spec.md) - 기능 명세
- [plan.md](./plan.md) - 구현 계획
- [TechSpec.md](../../docs/TechSpec.md) - 기술 설계
- [prd6.md](../../docs/prd6.md) - 제품 요구사항
