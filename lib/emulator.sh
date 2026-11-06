EMU_GROUP="_acvemu"
EMU_ANCHOR="acvemu"
EMU_TOKEN_FILE="${TMPDIR:-/tmp}/acvemu.pftoken"
EMU_STATE_FILE="${TMPDIR:-/tmp}/acvemu.state"
# mise run stop が止めている間だけある。claude タスクは、止められたと分かって静かに終わる
STOP_MARK="${TMPDIR:-/tmp}/acvemu.stopping"
EMU_DENIED="1.1.1.1"
EMU_DENIED_PORT=443
EMU_ALLOWED="https://github.com/"
EMU_VERIFY_ERROR=""

emulator_gid() { dscl . -read "/Groups/$EMU_GROUP" PrimaryGroupID 2>/dev/null | awk '{print $2}'; }

emulator_ports() {
  local pid port
  lsof -nP -iTCP -sTCP:LISTEN -a -c qemu 2>/dev/null |
    awk '$9 ~ /^127\.0\.0\.1:/ {
           split($9, a, ":")
           p = a[2] + 0
           if (p >= 5554 && p <= 5585 && p % 2 == 0) print p, $2
         }' | sort -u |
  while read -r port pid; do
    [ -n "$port" ] || continue
    printf '%s %s %s\n' "$port" \
      "$(ps -o gid= -p "$pid" | tr -d ' ')" \
      "$(ps -o command= -p "$pid" | awk '{for (i = 1; i < NF; i++) if ($i == "-avd") print $(i + 1)}')"
  done
}

wanted_emulators() {
  local port gid name
  while read -r port gid name; do
    [ -n "$name" ] || continue
    for want in ${ANDROID_AVDS[@]+"${ANDROID_AVDS[@]}"}; do
      [ "$name" = "$want" ] && printf '%s %s %s\n' "$port" "$gid" "$name"
    done
  done <<< "$(emulator_ports)"
  return 0
}

# VPN（Cisco）の anchor は、先に pass quick で通してしまう。それより前に置かないと block が効かない
pf_anchor_ready() {
  awk -v a="anchor \"${EMU_ANCHOR}\"" -v c='anchor "cisco.anyconnect.vpn"' '
    $0 == a { mine = NR }
    $0 == c { cisco = NR }
    END { exit !(mine && (!cisco || mine < cisco)) }' /etc/pf.conf
}

check_emulator_setup() {
  local have name
  command -v emulator >/dev/null || die "emulator がありません（Android SDK の emulator）"
  command -v adb >/dev/null || die "adb がありません（Android SDK の platform-tools）"
  [ -n "$(emulator_gid)" ] || die "グループ ${EMU_GROUP} がありません（mise run android-user）"
  gid_matches ||
    die "${EMU_GROUP} に切り替えられません。ログインし直してください"
  pf_anchor_ready ||
    die "/etc/pf.conf に anchor \"${EMU_ANCHOR}\" が無いか、VPN の anchor より後ろにあります（VM を止めて mise run android-user）"
  have=$(emulator -list-avds 2>/dev/null)
  for name in "${ANDROID_AVDS[@]}"; do
    printf '%s\n' "$have" | grep -qx "$name" ||
      die "AVD '${name}' がありません。config.local.sh の ANDROID_AVDS を直してください
  ある AVD: $(printf '%s' "$have" | tr '\n' ' ')"
  done
}

start_emulators() {
  local gid name port running ready
  gid=$(emulator_gid)
  for name in "${ANDROID_AVDS[@]}"; do
    running=$(wanted_emulators | awk -v n="$name" '$3 == n {print $1 " " $2}')
    if [ -n "$running" ]; then
      [ "${running#* }" = "$gid" ] ||
        die "${name} が ${EMU_GROUP} の外で動いています。止めてから実行してください"
      continue
    fi
    STARTED_AVDS="${STARTED_AVDS:-} ${name}"
    as_emulator_group "nohup emulator -avd '${name}' -no-window -no-audio > '${TMPDIR:-/tmp}/emu-${name}.log' 2>&1 &
      disown; sleep 2" >/dev/null 2>&1 || true
  done
  for name in "${ANDROID_AVDS[@]}"; do
    ready=""
    for _ in $(seq 1 90); do
      port=$(wanted_emulators | awk -v n="$name" '$3 == n {print $1}')
      if [ -n "$port" ] && adb -s "emulator-$port" get-state 2>/dev/null | grep -qx device; then
        ready=1
        break
      fi
      sleep 2
    done
    [ -n "$ready" ] ||
      die "${name} が device になりません。${TMPDIR:-/tmp}/emu-${name}.log を見てください"
  done
}

resolver_addrs() {
  scutil --dns 2>/dev/null |
    awk '$1 ~ /^nameserver\[[0-9]+\]$/ {print $3}' |
    grep -E '^[0-9]+(\.[0-9]+){3}$' | sort -u
}

emulator_rules() {
  local gid=$1 cidrs=$2 addr
  # ループバックは no state。TCP の pass は flags S/SA が付いて SYN だけに当たり、返事の SYN-ACK が block に落ちる
  printf 'pass out quick from any to 127.0.0.0/8 group %s no state\n' "$gid"
  printf 'pass out quick from any to ::1 group %s no state\n' "$gid"
  resolver_addrs | while read -r addr; do
    [ -n "$addr" ] || continue
    printf 'pass out quick proto { tcp, udp } from any to %s port 53 group %s\n' "$addr" "$gid"
  done
  printf '%s\n' "$cidrs" | while read -r addr; do
    [ -n "$addr" ] || continue
    printf 'pass out quick from any to %s group %s\n' "$addr" "$gid"
  done
  printf 'block drop out quick from any to any group %s\n' "$gid"
}

load_emulator_rules() {
  local err
  err=$(emulator_rules "$(emulator_gid)" "$1" | sudo pfctl -a "$EMU_ANCHOR" -f - 2>&1 >/dev/null) ||
    die "pf に規則を入れられません: $(printf '%s' "$err" | grep -v ALTQ | tr '\n' ' ')"
}

resolve_emulator_cidrs() {
  AAV_GITHUB_TOKEN="$(read_secret github-token)" "$ROOT/mise-tasks/netpolicy" --print "$1"
}

apply_emulator_policy() {
  local cidrs out token
  cidrs=$(resolve_emulator_cidrs "$1") ||
    die "通信先を解決できません。絞る先が欠けた状態では繋ぎません"
  if [ ! -f "$EMU_TOKEN_FILE" ]; then
    out=$(sudo pfctl -E 2>&1) || die "pf を有効にできません: $(printf '%s' "$out" | tr '\n' ' ')"
    token=$(printf '%s\n' "$out" | awk '/Token *:/ {print $NF}')
    [ -n "$token" ] || die "pf の控えを取れません: $(printf '%s' "$out" | tr '\n' ' ')"
    printf '%s\n' "$token" > "$EMU_TOKEN_FILE"
  fi
  load_emulator_rules "$cidrs"
  verify_emulator_policy || die "$EMU_VERIFY_ERROR"
}

as_emulator_group() { printf '%s\n' "$1" | newgrp "$EMU_GROUP" 2>/dev/null; }
gid_matches() { [ "$(as_emulator_group 'id -g' | tail -1 | tr -dc '0-9')" = "$(emulator_gid)" ]; }

emulator_policy_state() {
  local probe="nc -z -G 5 $EMU_DENIED $EMU_DENIED_PORT" allowed="curl -sS -o /dev/null -m 20 $EMU_ALLOWED"
  $probe >/dev/null 2>&1 || { echo unknown; return; }
  gid_matches || { echo unknown; return; }
  as_emulator_group "$probe" >/dev/null 2>&1 && { echo open; return; }
  as_emulator_group "$allowed" >/dev/null 2>&1 && { echo restricted; return; }
  $allowed >/dev/null 2>&1 && echo narrow || echo unknown
}

refresh_emulator_policy() {
  local cidrs
  cidrs=$(resolve_emulator_cidrs "$1") || return 1
  emulator_rules "$(emulator_gid)" "$cidrs" | sudo -n pfctl -a "$EMU_ANCHOR" -f -
}

verify_emulator_policy() {
  local state
  EMU_VERIFY_ERROR=""
  state=$(emulator_policy_state)
  printf '%s %s\n' "$state" "$(date +%s)" > "$EMU_STATE_FILE"
  case "$state" in
    restricted) return 0 ;;
    open) EMU_VERIFY_ERROR="絞れていません。/etc/pf.conf に anchor \"${EMU_ANCHOR}\" があるか確かめてください（mise run android-user）" ;;
    narrow) EMU_VERIFY_ERROR="${EMU_ALLOWED} に届きません。絞りすぎです" ;;
    *) EMU_VERIFY_ERROR="${EMU_GROUP} に切り替えられないか ${EMU_DENIED} に届かないので、確かめられません" ;;
  esac
  return 1
}

drop_emulator_policy() {
  local token rules_ok=0 token_ok=1
  token=$(cat "$EMU_TOKEN_FILE" 2>/dev/null) || true
  # 控えが切れていても、端末があれば聞いて外す。規則を残すよりよい
  if ! sudo -n true 2>/dev/null && [ -t 0 ]; then
    echo "==> Android エミュレータの通信を絞っていた macOS の pf の規則を外します。sudo のパスワードが要ります" >&2
    sudo -v -p "パスワード（pf の規則を外すため）: " || true
  fi
  # 空の規則を入れて外す。入れるときと同じ形なので、入れられたなら外せる
  printf '' | sudo -n pfctl -a "$EMU_ANCHOR" -f - >/dev/null 2>&1 && rules_ok=1
  if [ -n "$token" ]; then
    sudo -n pfctl -X "$token" >/dev/null 2>&1 || token_ok=0
  fi
  [ "$rules_ok" = 1 ] && rm -f "$EMU_STATE_FILE"
  [ "$token_ok" = 1 ] && rm -f "$EMU_TOKEN_FILE"
  [ "$rules_ok" = 1 ] && [ "$token_ok" = 1 ] && return 0
  cat >&2 <<EOS
規則が残りました。手で外してください。
  printf '' | sudo pfctl -a ${EMU_ANCHOR} -f -${token:+
  sudo pfctl -X ${token}}
EOS
}

EMU_KEY="${TMPDIR:-/tmp}/adb-tunnel"
emulator_ssh_pids() {
  local esc
  esc=$(printf '%s' "$EMU_KEY" | sed 's/[.[\*^$()+?{|]/\\&/g')
  pgrep -f "^ssh -i $esc " 2>/dev/null
}

prime_adb() {
  tart exec "$1" /bin/bash -lc '
    set -o pipefail
    export PATH=$PATH:~/android-sdk/platform-tools
    command -v adb >/dev/null || exit 1
    adb kill-server >/dev/null 2>&1
    adb start-server || exit 1
    for _ in $(seq 1 60); do
      adb devices | grep -q "device$" && break
      adb reconnect offline >/dev/null 2>&1
      sleep 2
    done
    adb devices | sed -n "2,\$p"'
}

tunnel_forever() {
  local vm=$1 ip port pid fwd
  while :; do
    ip=$(tart ip "$vm" 2>/dev/null) || {
      echo "[android] VM の IP がありません" >&2
      sleep 10; continue
    }
    fwd=()
    while read -r port _ _; do
      [ -n "$port" ] || continue
      fwd+=(-R "$port:127.0.0.1:$port" -R "$((port + 1)):127.0.0.1:$((port + 1))")
    done <<< "$(wanted_emulators)"
    if [ "${#fwd[@]}" -eq 0 ]; then
      echo "[android] 渡せるエミュレータがありません" >&2
      sleep 30
      continue
    fi
    rm -f "$EMU_KEY" "$EMU_KEY.pub" "$EMU_KEY.known"
    ssh-keygen -t ed25519 -N "" -f "$EMU_KEY" -q || { sleep 10; continue; }
    tart exec "$vm" /bin/bash -lc "mkdir -p ~/.ssh && chmod 700 ~/.ssh &&
      printf '%s\n' '$(cat "$EMU_KEY.pub")' > ~/.ssh/authorized_keys &&
      chmod 600 ~/.ssh/authorized_keys" || { sleep 10; continue; }
    tart exec "$vm" /bin/bash -lc "cat /etc/ssh/ssh_host_ed25519_key.pub" |
      awk -v ip="$ip" "NF {print ip, \$1, \$2}" > "$EMU_KEY.known" || true
    [ -s "$EMU_KEY.known" ] || { sleep 10; continue; }
    ssh -i "$EMU_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$EMU_KEY.known" \
        -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
        -N "${fwd[@]}" "admin@$ip" &
    pid=$!
    prime_adb "$vm" | sed "s/^/[android] /" >&2 || true
    wait "$pid" || true
    echo "[android] トンネルが切れました。張り直します" >&2
    sleep 5
  done
}

drop_tunnel() {
  tart exec "$1" /bin/bash -lc "rm -f ~/.ssh/authorized_keys" >/dev/null 2>&1 || true
  rm -f "$EMU_KEY" "$EMU_KEY.pub" "$EMU_KEY.known"
}

stop_emulators() {
  local port gid name want gid_now cur still
  gid_now=$(emulator_gid)
  for want in ${STARTED_AVDS:-}; do
    while read -r port gid name; do
      if [ "$name" = "$want" ] && [ "$gid" = "$gid_now" ]; then
        adb -s "emulator-$port" emu kill >/dev/null 2>&1 || true
      fi
    done <<< "$(wanted_emulators)"
  done
  still=1
  for _ in $(seq 1 15); do
    cur=$(wanted_emulators)
    still=""
    for want in ${STARTED_AVDS:-}; do
      printf '%s\n' "$cur" | awk -v n="$want" '$3 == n' | grep -q . && still=1
    done
    [ -z "$still" ] && break
    sleep 1
  done
  [ -n "$still" ] || STARTED_AVDS=""
  return 0
}
