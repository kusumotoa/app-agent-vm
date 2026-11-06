# ALLOW の名前の宛先を、VM の 127.0.0.1:443 からホストへ渡す。
MARK="# acv-vpn-relay"

relay_hosts_add() {
  printf "127.0.0.1 %s ${MARK}\n" "${RELAY[@]}" | tart exec -i "$1" sudo tee -a /etc/hosts >/dev/null
}

# 直後に VM を止めても残らないよう sync まで待つ。
relay_hosts_drop() {
  tart exec "$1" /bin/bash -c "sudo sed -i '' '/${MARK}\$/d' /etc/hosts && sync" >/dev/null 2>&1 || true
}

relay_forever() {
  while :; do
    "$ROOT/mise-tasks/relay" "$1" "${RELAY[@]}"
    sleep 5
  done
}
