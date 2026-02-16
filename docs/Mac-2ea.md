# 2대 맥북 Git 협업 분석 결과

> 분석일: 2026-02-16

## 결론

Git 원격 저장소(GitHub 등)를 설정하고 커밋/푸시만 잘 하면, 2대 맥에서 1대처럼 번갈아 작업 가능.

---

## 문제 없는 항목 (대부분 양호)

| 항목 | 상태 | 상세 |
|------|------|------|
| Package.swift 의존성 | OK | 절대경로 없음, 상대경로만 사용 |
| LiquidGlassKit | OK | Git에 직접 포함 (submodule 아님), clone만 하면 OK |
| 원격 SPM 패키지 | OK | BlurUIKit, TelemetryDeck — `Package.resolved`로 버전 잠금 |
| 빌드 설정 | OK | 하드코딩된 절대경로 없음 |
| TrashStore 로컬 데이터 | OK | 앱 샌드박스(Documents/)에 저장, Git과 무관 |
| xcuserdata (메인 프로젝트) | OK | `.gitignore`에 포함됨 |
| 로컬 패키지 경로 | OK | `../../iOS`, `../LiquidGlassKit` 모두 프로젝트 내 상대경로 |

---

## 해결/확인 필요 항목

### 1. 원격 저장소 없음 (필수)

현재 `git remote`가 비어 있음. GitHub private repo 생성 필요.

```bash
# GitHub에 private repo 생성 후
git remote add origin https://github.com/username/repo.git
git push -u origin master
```

### 2. test/ 폴더 xcuserdata 추적 중 (권장 수정)

`test/Spike1/` 하위에 아래 파일들이 Git에 추적되고 있음:
- `test/Spike1/.../xcuserdata/karl.xcuserdatad/UserInterfaceState.xcuserstate` (바이너리)
- `test/Spike1/.../xcuserdata/karl.xcuserdatad/xcschemes/xcschememanagement.plist`

**문제점**: 바이너리 파일이라 merge conflict 시 해소 불가능, 사용자명 `karl` 하드코딩.

**해결 방법**:
```bash
# .gitignore에 추가
echo 'test/**/xcuserdata/' >> .gitignore

# 추적 해제
git rm -r --cached test/Spike1/Spike1Test/Spike1Test.xcodeproj/xcuserdata/
git rm -r --cached test/Spike1/Spike1Test/Spike1Test.xcodeproj/project.xcworkspace/xcuserdata/
```

### 3. Apple Developer 계정 (확인 필요)

`DEVELOPMENT_TEAM = 7YD5497HFS`가 빌드 설정에 하드코딩.
- 두 번째 맥북에서 **동일한 Apple ID**로 Xcode 로그인하면 문제없음
- 다른 계정이면 Xcode에서 팀 재설정 필요

### 4. analytics .env 파일 (참고)

`scripts/analytics/.env`는 `.gitignore`로 무시됨.
- 두 번째 맥에서 `.env.example`을 복사하여 수동 설정 필요
- 앱 빌드 자체에는 영향 없음 (analytics 스크립트만 사용)

---

## 작업 루틴

```
맥 A에서 작업 끝 → git add & commit & push
맥 B에서 작업 시작 → git pull
(반복)
```

---

## 프로젝트 의존성 구조 참고

```
PickPhoto.xcodeproj
├── AppCore (로컬 SPM: ../../iOS)
├── LiquidGlassKit (로컬 SPM: ../LiquidGlassKit, Git에 직접 포함)
├── BlurUIKit (원격 SPM: GitHub, Package.resolved로 잠금)
└── TelemetryDeck (원격 SPM: GitHub, Package.resolved로 잠금)
```
