put() { printf '%s' "$2" > "$SHARED/$1"; chmod 600 "$SHARED/$1"; }

stage_github() {
  local tok ro
  tok="$(read_secret github-token)"
  put github-token "$tok"
  stage_identity "$tok"
  ro="$(read_secret github-token-ro)"
  [ -n "$ro" ] && put github-token-ro "$ro"
  stage_packages "$tok"
  return 0
}

# GitHub Packages から取る Gradle プロジェクト（secret.properties の gpr.user / gpr.key）用。無くてもよい。
stage_packages() {
  local pk
  pk="$(read_secret github-packages-token)"
  [ -n "$pk" ] || return 0
  put github-packages-token "$pk"
  put github-login "$(GH_TOKEN="$1" gh api /user --jq .login)"
}

stage_identity() {
  local who
  who=$(GH_TOKEN="$1" gh api /user --jq '"\(.name // .login)\t\(.id)+\(.login)@users.noreply.github.com"' 2>/dev/null) ||
    die "GitHub の利用者を引けません。PAT を確かめてください"
  put git-name  "${who%%	*}"
  put git-email "${who#*	}"
}

# Claude の OAuth トークン（claude setup-token で作ったもの）。無ければ VM の中でログインする。
stage_claude_token() {
  local t
  t="$(read_secret claude-token)"
  [ -n "$t" ] || return 0
  put claude-token "$t"
}

# claude に渡す引数。VM の中で bash が 1 語ずつ読めるように %q で quote する。
stage_claude_args() {
  local out="" a
  for a in ${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}; do
    out="${out}$(printf '%q' "$a") "
  done
  put claude-args "$out"
}

stage_repo_files() {
  cp -R "$ROOT/skills" "$SHARED/skills"
  build_repos_lib > "$SHARED/repos-lib.sh"
  build_repos > "$SHARED/repos.sh"
  build_work_claude_md > "$SHARED/work-CLAUDE.md"
}

stage_all() {
  stage_github
  stage_claude_token
  stage_claude_args
  stage_repo_files
  stage_signing
}
