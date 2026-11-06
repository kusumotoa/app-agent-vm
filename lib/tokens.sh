check_github_token() {
  local code
  code=$(printf 'header = "Authorization: Bearer %s"\n' "$1" |
         curl -s --config - -o /dev/null -w '%{http_code}' --max-time 15 \
         https://api.github.com/user 2>/dev/null) || {
    echo "到達できません"; return 1; }
  case "$code" in
    200) return 0 ;;
    401) echo "失効しています"; return 1 ;;
    *)   echo "HTTP ${code}"; return 1 ;;
  esac
}

verify_tokens() {
  local bad=0 r v
  v=$(read_secret github-token)
  if [ -n "$v" ]; then
    r=$(check_github_token "$v") || { echo "  GitHub のトークン: $r" >&2; bad=1; }
  fi
  v=$(read_secret github-token-ro)
  if [ -n "$v" ]; then
    r=$(check_github_token "$v") || { echo "  読み取り専用の PAT: $r" >&2; bad=1; }
  fi
  return $bad
}
