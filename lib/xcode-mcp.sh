#!/bin/bash
# claude が起動する Xcode MCP。動いている Xcode Service に固定してつなぐ。
# 固定しないと mcpbridge が自分で起動した Xcode Service の接続を待ち続け、
# XcodeOpenWorkspace のほかの呼び出しが返らない。

SERVICE="$(xcode-select -p)/Library/Xcode/Agents/Xcode Service.app"
PATTERN="Xcode Service.app/Contents/MacOS/Xcode Service"

PID=$(pgrep -f "$PATTERN" | head -1)
if [ -z "$PID" ]; then
  open -g "$SERVICE"
  for _ in $(seq 1 40); do
    PID=$(pgrep -f "$PATTERN" | head -1)
    [ -n "$PID" ] && break
    sleep 0.5
  done
fi
[ -n "$PID" ] || { echo "Xcode Service を起動できません" >&2; exit 1; }

MCP_XCODE_PID=$PID exec xcrun mcpbridge "$@"
