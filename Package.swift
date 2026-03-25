// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// AppCore: SweepPic MVP의 비즈니스 로직을 담당하는 Swift Package
/// - Models: PhotoAssetEntry, Album, TrashState 등 데이터 모델
/// - Services: PhotoLibraryService, ImagePipeline 등 서비스 레이어
/// - Stores: TrashStore, PermissionStore 등 상태 관리
let package = Package(
    name: "AppCore",
    platforms: [
        // iOS 16+ 최소 지원 (PhotoKit API 호환성 보장)
        .iOS(.v16)
    ],
    products: [
        // AppCore 라이브러리 - SweepPic 앱에서 import 가능
        .library(
            name: "AppCore",
            targets: ["AppCore"]
        ),
    ],
    dependencies: [
        // 외부 의존성 없음 - PhotoKit만 사용
    ],
    targets: [
        // AppCore 메인 타겟 - 비즈니스 로직 포함
        .target(
            name: "AppCore",
            dependencies: [],
            path: "Sources/AppCore"
        ),
        // AppCore 테스트 타겟
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"],
            path: "Tests/AppCoreTests"
        ),
    ]
)
