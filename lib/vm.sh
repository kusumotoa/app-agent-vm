die() { echo "error: $*" >&2; exit 1; }

# softnet の実体パスを出す。無ければ空で失敗する。
softnet_real_path() {
  local p
  p=$(command -v softnet 2>/dev/null) || return 1
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p"
}

# VM の状態を出す。無ければ空。
vm_state() { tart list 2>/dev/null | grep -E "[[:space:]]$1[[:space:]]" | awk '{print $NF}'; }

# tart clone は同名の VM を黙って置き換える。build の前に、あれば止める。
verify_no_vm() {
  [ -z "$(vm_state "$1")" ] ||
    die "VM '$1' があります。作り直すと中の状態が消えます（消すなら tart delete $1）"
}

# Xcode の MCP がヘッドレスで使える状態か。permission.enabled と
# unsafeAlwaysAllowAllAgents の両方が立っていること（mise run build が入れる）。
verify_mcp_headless() {
  tart exec "$1" /bin/bash -lc '
    MS="$(xcode-select -p)/usr/bin/mcp-server"
    [ -x "$MS" ] || exit 1
    "$MS" status --format json 2>/dev/null |
      python3 -c "import json,sys; p=json.load(sys.stdin).get(\"permission\",{}); sys.exit(0 if p.get(\"enabled\") and p.get(\"unsafeAlwaysAllowAllAgents\") else 1)"'
}

wait_for_vm() {
  local vm=$1 waited=0 limit=${2:-180}
  while [ "$waited" -lt "$limit" ]; do
    if tart exec "$vm" /bin/bash -lc 'echo ready' 2>/dev/null | grep -q ready; then
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "VM が ${limit}s で応答しません" >&2
  return 1
}

verify_allow() {
  local entry
  for entry in "${ALLOW[@]}"; do
    case "${entry%%#*}" in
      *0.0.0.0/0*) echo "ALLOW に 0.0.0.0/0 があります。全部通ります" >&2; return 1 ;;
    esac
  done
}

verify_firewall() {
  local vm=$1 code
  verify_allow || return 1
  # 中継の受け口が立つまで数秒かかるので、届くまで繰り返す。
  for _ in 1 2 3 4 5 6; do
    code=$(tart exec "$vm" /bin/bash -lc '
      curl -s -o /dev/null -w "%{http_code}" --max-time 20 https://api.github.com/zen 2>/dev/null
    ' 2>/dev/null | tr -dc '0-9')
    [ -n "$code" ] && [ "$code" != 000 ] && break
    sleep 5
  done
  [ -n "$code" ] && [ "$code" != 000 ] || {
    echo "api.github.com へ届きません（${code:-応答なし}）。config.d/allow.sh の ALLOW を確認してください" >&2
    return 1
  }
}
