# Gate 1. 업로드 차단

> 바이너리가 Apple 서버에 올라가지 않음 (ITMS 자동 검증 실패)
> 이 게이트가 해결 안 되면 나머지 Gate 2~4는 의미 없음

---

### 분류 요약

```
1. 업로드 차단
   1) 코드/설정: PrivacyInfo.xcprivacy, SDK Privacy Manifest
   2) 에셋: 앱 아이콘
```

---

## 1) 코드/설정 — 프로젝트 파일 변경

### PrivacyInfo.xcprivacy 생성

> 프로젝트 전체에 파일 없음 → ITMS-91053 오류로 업로드 차단

**단계별 시행 이력:**
- 2024-03-13: Required Reason API 누락 시 경고 이메일 발송
- 2024-05-01: Required Reason API 사유 선언 필수 + 새 서드파티 SDK에 privacy manifest/서명 필수
- 2024-11-12: 기존 포함 SDK까지 유효한 privacy manifest 검증 확대 적용
- **2025-02-12: Privacy-impacting SDK에 Privacy Manifest 미포함 시 ITMS-91061 오류로 업로드 차단 (현재 시행 중)**

([근거: TN3181](https://developer.apple.com/documentation/technotes/tn3181-debugging-an-invalid-privacy-manifest))

**파일 구조:**

| 키 | 설명 | 필수 여부 |
|----|------|----------|
| NSPrivacyTracking | ATT 정의에 따른 추적 여부 (Boolean) | 추적 시 `true`, 안 하면 키 생략 가능 |
| NSPrivacyTrackingDomains | 추적 도메인 목록 | 추적 도메인이 있을 때만 |
| NSPrivacyCollectedDataTypes | 수집 데이터 타입 배열 | 데이터를 수집하는 경우에만 |
| NSPrivacyAccessedAPITypes | 필수 사유 API 배열 | Required Reason API 사용 시에만 |

> 각 키는 **해당 행위를 할 때만 선언** (opt-in 방식). Apple은 사용하지 않는 키는 제거를 안내.

**수집 데이터 선언 구조 (각 데이터 타입별):**

```xml
<dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypePhotos</string>
    <key>NSPrivacyCollectedDataTypeLinked</key>       <!-- 사용자 신원과 연결 여부 -->
    <false/>
    <key>NSPrivacyCollectedDataTypeTracking</key>     <!-- 추적 목적 사용 여부 -->
    <false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>     <!-- 사용 목적 -->
    <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
    </array>
</dict>
```

### PrivacyInfo.xcprivacy 작성 예시 (PickPhoto 기준)

```xml
<!-- PrivacyInfo.xcprivacy -->
NSPrivacyAccessedAPITypes:
  - UserDefaults (CA92.1) — analytics opt-out 상태 저장
  - FileTimestamp (DDA9.1) — 사진 파일 타임스탬프 접근

NSPrivacyCollectedDataTypes: (온디바이스 전용이므로 비어있을 수 있음)

NSPrivacyTrackingDomains: []
NSPrivacyTracking: false
```

> 출처: MenuResearch §6 — Privacy Manifest 구조 예시

### Required Reason API — PickPhoto 사용 현황

| API 카테고리 | 사용 여부 | 위치 | 사유 코드 |
|-------------|:--------:|------|----------|
| **파일 타임스탬프** | O | ThumbnailCache.swift (contentModificationDateKey, setAttributes) | `DDA9.1` (앱 컨테이너 내 접근) |
| **UserDefaults** | O | Debug 폴더, CleanupConstants | `CA92.1` (앱 자체 접근) |
| 시스템 부팅 시간 | X | - | - |
| 디스크 공간 | X | - | - |
| 활성 키보드 | X | - | - |

**Required Reason API 전체 5개 카테고리 (참고):**

| # | 카테고리 | API 타입 키 | 주요 사유 코드 |
|---|---------|------------|--------------|
| 1 | 파일 타임스탬프 | NSPrivacyAccessedAPICategoryFileTimestamp | `DDA9.1` 앱 컨테이너 내 접근 / `C617.1` 사용자에게 표시 / `3B52.1` 검색 / `0A2A.1` 내부 파일 접근 |
| 2 | 시스템 부팅 시간 | NSPrivacyAccessedAPICategorySystemBootTime | `35F9.1` 경과 시간 측정 / `8FFB.1` 타이머 / `3D61.1` 부팅 시간 확인 |
| 3 | 디스크 공간 | NSPrivacyAccessedAPICategoryDiskSpace | `85F4.1` 표시 / `E174.1` 쓰기 확인 / `7D9E.1` 앱 기능 / `B728.1` 사용자에게 표시 |
| 4 | 활성 키보드 | NSPrivacyAccessedAPICategoryActiveKeyboards | `3EC4.1` 커스텀 키보드 / `54BD.1` 활성 키보드 결정 |
| 5 | UserDefaults | NSPrivacyAccessedAPICategoryUserDefaults | `CA92.1` 앱 자체 접근 / `1C8F.1` App Group 공유 / `C56D.1` 제3자 SDK / `AC6B.1` MDM 구성 |

### SDK Privacy Manifest 확인/추가

> 앱이 사용하는 모든 서드파티 SDK에 유효한 Privacy Manifest가 포함되어야 함
> SDK 제작자가 미제공 시 앱 개발자가 직접 해당 SDK 번들 내에 PrivacyInfo.xcprivacy를 추가해야 함

**PickPhoto 서드파티 라이브러리 현황:**

| 라이브러리 | 유형 | Privacy Manifest | 비고 |
|-----------|------|:----------------:|------|
| AppCore | 로컬 패키지 | 없음 | CryptoKit(SHA256), 파일 타임스탬프 사용 |
| BlurUIKit | 원격 (TimOliver/BlurUIKit >= 1.2.2) | **확인 필요** | - |
| LiquidGlassKit | 로컬 패키지 | 없음 | Metal/MetalKit 사용 |

---

## 2) 에셋 — 이미지 파일 제작

### 앱 아이콘

> 현재 상태: Contents.json만 존재, 실제 이미지 없음 → ITMS-90717 오류로 업로드 차단

**사양:**

| 항목 | 요구사항 |
|------|---------|
| 크기 | **1024 x 1024 px** |
| 형식 | **PNG** (JPEG/GIF 불가) |
| 투명도 | **불투명 필수** (알파 채널/투명 영역 없음) |
| 모양 | 정사각형 (모서리 라운딩 Apple이 자동 적용) |
| 색상 공간 | sRGB 또는 Display P3 |

---

## Gate 1 체크리스트

- [ ] PrivacyInfo.xcprivacy가 프로젝트에 포함되어 있는가?
- [ ] Required Reason API 사유 코드가 올바르게 선언되어 있는가? (파일 타임스탬프 `DDA9.1`, UserDefaults `CA92.1`)
- [ ] 서드파티 SDK(BlurUIKit, LiquidGlassKit)에 Privacy Manifest가 포함되어 있는가?
- [ ] 앱 아이콘이 1024x1024 불투명 PNG인가? (알파 채널 없음)

---

## ITMS 오류 코드 대응 (Gate 1 관련)

> 업로드 시 발생할 수 있는 ITMS 오류와 해결법

| 오류 코드 | 제목 | 원인 | 해결법 |
|----------|------|------|--------|
| **ITMS-90683** | Missing Purpose String | `NSPhotoLibraryUsageDescription` 등 필수 Usage Description 누락 | Info.plist에 해당 키 + 사유 문자열 추가 |
| **ITMS-91053** | Missing API Declaration | Privacy Manifest에서 Required Reason API 사유 미선언 | PrivacyInfo.xcprivacy에 해당 API + 사유 코드 추가 |
| **ITMS-91061** | Missing Privacy Manifest in SDK | 서드파티 SDK에 Privacy Manifest 미포함 | SDK 업데이트하거나, SDK 번들 내에 PrivacyInfo.xcprivacy 직접 추가 |
| **ITMS-90717** | Invalid App Store Icon | 아이콘에 알파 채널/투명 영역 포함, 또는 PNG 아닌 형식 | 1024x1024 불투명 PNG로 교체, 알파 채널 제거 |
| **ITMS-90032** | Invalid Binary Architecture | 32비트 아키텍처 포함 | arm64 전용 빌드 확인 |
| **ITMS-90474** | Missing Bundle Version | CFBundleVersion 누락/무효 | Info.plist에 유효한 버전 번호 설정 |

---

## 참고 문서

| 문서 | URL |
|------|-----|
| Privacy Manifest | https://developer.apple.com/documentation/bundleresources/privacy-manifest-files |
| Required Reason API | https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api |
| 앱 아이콘 가이드 (HIG) | https://developer.apple.com/design/human-interface-guidelines/app-icons |
| 수출 규정 | https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations |
| TN3181 디버깅 가이드 | https://developer.apple.com/documentation/technotes/tn3181-debugging-an-invalid-privacy-manifest |
