AAV_KEYCHAIN_SERVICE="${AAV_VM:-$VM_NAME}"

# 環境変数があればそれを使う。無ければキーチェーンから読む。
# github-token なら AAV_GITHUB_TOKEN。
read_secret() {
  local var="AAV_$(printf '%s' "$1" | tr 'a-z-' 'A-Z_')"
  if [ -n "${!var:-}" ]; then
    printf '%s' "${!var}"
    return 0
  fi
  security find-generic-password -s "$AAV_KEYCHAIN_SERVICE" -a "$1" -w 2>/dev/null || true
}

write_secret() {
  security add-generic-password -U -s "$AAV_KEYCHAIN_SERVICE" -a "$1" -w "$2" 2>/dev/null
}
