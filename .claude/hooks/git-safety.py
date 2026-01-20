#!/usr/bin/env python3
"""
Git Safety Hook for PickPhoto iOS Project

CLAUDE.md 규칙 강제:
- git checkout, git reset, git revert 등 롤백 명령어는 사용자 확인 없이 실행 금지
- 롤백이 필요한 경우 수동으로 코드 수정하거나 사용자에게 명시적 허락 받아야 함
"""
import json
import sys
import re

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

    # 규칙 1: git checkout/reset/revert/restore - 롤백 명령어 차단
    # (CLAUDE.md: "롤백 작업 요청 시 수동으로 코드를 수정하는 것을 기본으로 한다")
    if re.search(r"git\s+(checkout|reset|revert|restore)\b", command):
        # git checkout -b (새 브랜치 생성)는 허용
        if re.search(r"git\s+checkout\s+-b\s+", command):
            sys.exit(0)

        # git reset HEAD (스테이징 취소)는 허용 - 코드 변경 없이 스테이징만 해제
        # 허용 패턴: git reset HEAD, git reset HEAD -- <file>
        # 차단 패턴: git reset --hard, git reset HEAD~1, git reset <commit-hash>
        if re.search(r"git\s+reset\s+HEAD(\s|$)", command):
            # --hard 옵션이 있으면 차단
            if "--hard" not in command:
                sys.exit(0)

        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "ask",
                "permissionDecisionReason": (
                    "WARNING: git 롤백 명령어입니다. "
                    "CLAUDE.md 규칙: 롤백은 수동 수정이 기본이며, git 명령어는 사용자 확인 필요. "
                    "실행을 허용하시겠습니까?"
                )
            }
        }
        print(json.dumps(output))
        sys.exit(0)

    # 규칙 2: git push --force - 경고 후 사용자 확인
    if re.search(r"git\s+push\s+.*--force", command):
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "ask",
                "permissionDecisionReason": (
                    "WARNING: Force push는 원격 히스토리를 덮어씁니다. "
                    "정말 실행하시겠습니까?"
                )
            }
        }
        print(json.dumps(output))
        sys.exit(0)

    # 기본: 통과
    sys.exit(0)

if __name__ == "__main__":
    main()
