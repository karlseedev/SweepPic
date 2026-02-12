#!/usr/bin/env python3
"""
Safety Hook for PickPhoto iOS Project

CLAUDE.md 규칙 강제:
- 파일 삭제 명령어는 사용자 확인 없이 실행 금지
- git 롤백 명령어는 사용자 확인 없이 실행 금지
- 파일 덮어쓰기/수정 명령어는 사용자 확인 없이 실행 금지
"""
import json
import sys
import re


def ask_permission(reason: str):
    """사용자에게 허가를 요청하는 출력을 생성"""
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": reason
        }
    }
    print(json.dumps(output))
    sys.exit(0)


def main():
    # stdin에서 hook input 받기
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Bash 도구가 아니면 통과
    if input_data.get("tool_name") != "Bash":
        sys.exit(0)

    command = input_data.get("tool_input", {}).get("command", "")

    # =========================================================================
    # 규칙 1: 파일/폴더 삭제 명령어 차단
    # =========================================================================

    # rm 명령어 차단 (rm, rm -r, rm -rf 등)
    if re.search(r"\brm\s+", command):
        ask_permission(
            "WARNING: 파일 삭제 명령어(rm)입니다. "
            "CLAUDE.md 규칙: 파일 삭제는 사용자 확인 필요. "
            "실행을 허용하시겠습니까?"
        )

    # unlink 명령어 차단
    if re.search(r"\bunlink\s+", command):
        ask_permission(
            "WARNING: 파일 삭제 명령어(unlink)입니다. "
            "CLAUDE.md 규칙: 파일 삭제는 사용자 확인 필요. "
            "실행을 허용하시겠습니까?"
        )

    # =========================================================================
    # 규칙 2: Git 위험 명령어 차단
    # =========================================================================

    # git checkout/reset/revert/restore - 롤백 명령어 차단
    if re.search(r"git\s+(checkout|reset|revert|restore)\b", command):
        # git checkout -b (새 브랜치 생성)는 허용
        if re.search(r"git\s+checkout\s+-b\s+", command):
            sys.exit(0)

        # git reset HEAD (스테이징 취소)는 허용
        if re.search(r"git\s+reset\s+HEAD(\s|$)", command):
            if "--hard" not in command:
                sys.exit(0)

        ask_permission(
            "WARNING: git 롤백 명령어입니다. "
            "CLAUDE.md 규칙: 롤백은 수동 수정이 기본이며, git 명령어는 사용자 확인 필요. "
            "실행을 허용하시겠습니까?"
        )

    # git push --force
    if re.search(r"git\s+push\s+.*--force", command):
        ask_permission(
            "WARNING: Force push는 원격 히스토리를 덮어씁니다. "
            "정말 실행하시겠습니까?"
        )

    # git clean - 추적되지 않는 파일 삭제
    if re.search(r"git\s+clean\b", command):
        ask_permission(
            "WARNING: git clean은 추적되지 않는 파일을 삭제합니다. "
            "실행을 허용하시겠습니까?"
        )

    # git branch -D - 브랜치 강제 삭제
    if re.search(r"git\s+branch\s+.*-D", command):
        ask_permission(
            "WARNING: 브랜치 강제 삭제(-D)입니다. "
            "실행을 허용하시겠습니까?"
        )

    # git stash drop/clear - stash 삭제
    if re.search(r"git\s+stash\s+(drop|clear)\b", command):
        ask_permission(
            "WARNING: git stash 삭제 명령어입니다. "
            "실행을 허용하시겠습니까?"
        )

    # git reflog expire - reflog 삭제
    if re.search(r"git\s+reflog\s+expire\b", command):
        ask_permission(
            "WARNING: git reflog expire는 복구 기록을 삭제합니다. "
            "실행을 허용하시겠습니까?"
        )

    # git gc --prune - 즉시 가비지 컬렉션
    if re.search(r"git\s+gc\s+.*--prune", command):
        ask_permission(
            "WARNING: git gc --prune은 객체를 즉시 삭제합니다. "
            "실행을 허용하시겠습니까?"
        )

    # =========================================================================
    # 규칙 3: 파일 덮어쓰기/수정 명령어 차단
    # =========================================================================

    # mv 명령어 - 파일 이동/이름변경 (덮어쓰기 가능)
    if re.search(r"\bmv\s+", command):
        ask_permission(
            "WARNING: mv 명령어는 기존 파일을 덮어쓸 수 있습니다. "
            "실행을 허용하시겠습니까?"
        )

    # cp -f 강제 복사
    if re.search(r"\bcp\s+.*-[a-zA-Z]*f", command):
        ask_permission(
            "WARNING: cp -f는 기존 파일을 강제로 덮어씁니다. "
            "실행을 허용하시겠습니까?"
        )

    # truncate - 파일 크기 변경
    if re.search(r"\btruncate\s+", command):
        ask_permission(
            "WARNING: truncate는 파일 내용을 손실시킬 수 있습니다. "
            "실행을 허용하시겠습니까?"
        )

    # dd - 디스크/파일 직접 쓰기
    if re.search(r"\bdd\s+", command):
        ask_permission(
            "WARNING: dd는 데이터를 직접 덮어쓰는 위험한 명령어입니다. "
            "실행을 허용하시겠습니까?"
        )

    # shred - 파일 완전 삭제
    if re.search(r"\bshred\s+", command):
        ask_permission(
            "WARNING: shred는 파일을 복구 불가능하게 삭제합니다. "
            "실행을 허용하시겠습니까?"
        )

    # codex exec는 -o 옵션으로 출력하므로 안전 — 명시적 허용
    # (allow 목록 버그 우회: sys.exit(0)은 "의견 없음"이라 permission 재확인됨)
    if re.search(r"\bcodex\b", command):
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "permissionDecisionReason": "codex 명령어 — 자동 허용"
            }
        }
        print(json.dumps(output))
        sys.exit(0)

    # 리다이렉션으로 파일 덮어쓰기 (> file)
    # 주의: >>는 추가이므로 덜 위험, >는 덮어쓰기
    # 따옴표 안의 >는 비교 연산자/문자열이므로 제외
    # 2>/dev/null 같은 안전한 리다이렉션도 제외
    stripped = re.sub(r"'[^']*'", '', command)   # 작은따옴표 내용 제거
    stripped = re.sub(r'"[^"]*"', '', stripped)   # 큰따옴표 내용 제거
    stripped = re.sub(r'\d+>/dev/null', '', stripped)  # N>/dev/null 제거
    if re.search(r"\s+>(?!>)\s*\S+", stripped):
        ask_permission(
            "WARNING: 리다이렉션(>)은 파일을 덮어씁니다. "
            "실행을 허용하시겠습니까?"
        )

    # =========================================================================
    # 규칙 4: 시스템 명령어 차단
    # (kill/killall/pkill은 제외 - 프로세스는 다시 실행하면 되므로 위험하지 않음)
    # =========================================================================

    # sudo - 관리자 권한 실행
    if re.search(r"\bsudo\s+", command):
        ask_permission(
            "WARNING: sudo는 관리자 권한으로 실행합니다. "
            "실행을 허용하시겠습니까?"
        )

    # chmod - 파일 권한 변경
    if re.search(r"\bchmod\s+", command):
        ask_permission(
            "WARNING: chmod는 파일 권한을 변경합니다. "
            "실행을 허용하시겠습니까?"
        )

    # chown - 파일 소유자 변경
    if re.search(r"\bchown\s+", command):
        ask_permission(
            "WARNING: chown은 파일 소유자를 변경합니다. "
            "실행을 허용하시겠습니까?"
        )

    # 기본: 통과
    sys.exit(0)


if __name__ == "__main__":
    main()
