# 対象のリポジトリは ~/work/<名前> に 1 つずつ clone する。履歴は VM のディスクに残り、起動のたびに fetch だけする。
# 作業ツリーには触らない（未コミットの変更や作業中のブランチを壊さない）。
# 関数は ~/repos-lib.sh に分け、~/repos.sh（起動のたびに作る）が読む。
build_repos_lib() {
  cat <<'EOS'
WORK="$HOME/work"
REFS_DIR="$WORK/refs"
mkdir -p "$WORK" "$REFS_DIR"

# $1 owner/repo。無ければ clone し、あれば fetch だけする。
sync_repo() {
  local d="$WORK/${1##*/}"
  if [ -d "$d/.git" ]; then
    git -C "$d" fetch --prune origin >&2 || return 1
  else
    gh repo clone "$1" "$d" >&2 || return 1
  fi
}

# Gradle の local.properties と secret.properties を雛形から作る。
# local.properties は sdk.dir だけ入れる（デバッグビルド用。署名の値は空）。
# secret.properties には GitHub Packages の認証を入れる。
# 雛形が SSH の URL で持つ submodule は、読み取り用の PAT で HTTPS から取る。
prepare_repo() {
  local d="$WORK/$1"
  if [ -f "$d/local.properties.template" ] && [ ! -f "$d/local.properties" ] && [ -n "${ANDROID_HOME:-}" ]; then
    sed -e "s|^sdk.dir=.*|sdk.dir=$ANDROID_HOME|" "$d/local.properties.template" > "$d/local.properties"
  fi
  if [ -f "$d/secret.properties.template" ] && [ ! -f "$d/secret.properties" ] && [ -n "${GPR_KEY:-}" ]; then
    sed -e "s|^gpr.user=.*|gpr.user=$GPR_USER|" -e "s|^gpr.key=.*|gpr.key=$GPR_KEY|" \
      "$d/secret.properties.template" > "$d/secret.properties"
  fi
  if [ -f "$d/.gitmodules" ] && [ -n "${GH_TOKEN_RO:-}" ]; then
    git -C "$d" -c "url.https://x-access-token:$GH_TOKEN_RO@github.com/.insteadOf=git@github.com:" \
      submodule update --init --depth 1 >&2 || return 1
  fi
  return 0
}

sync_ref() {
  if [ -d "$2/.git" ]; then
    GH_TOKEN="$GH_TOKEN_RO" git -C "$2" fetch --depth 1 origin || return 1
    git -C "$2" checkout --detach FETCH_HEAD || return 1
  else
    GH_TOKEN="$GH_TOKEN_RO" gh repo clone "$1" "$2" -- --depth 1 || return 1
  fi
}
EOS
}

# 起動のたびに VM の中で実行する。
build_repos() {
  local repo
  cat <<'EOS'
. "$HOME/repos-lib.sh"

# 1 つのリポジトリの準備に失敗しても、ほかは続ける。関係の無いリポジトリの失敗で、起動を止めない。
OK_COUNT=0
skip_repo() { echo "warning: $1 の準備に失敗しました。このリポジトリは使えません" >&2; }
EOS
  for repo in ${REPOS[@]+"${REPOS[@]}"}; do
    [ -n "$repo" ] || continue
    printf 'if sync_repo %s && prepare_repo %s; then OK_COUNT=$((OK_COUNT + 1)); else skip_repo %s; fi\n' "$repo" "${repo##*/}" "${repo##*/}"
  done
  for repo in ${REFS[@]+"${REFS[@]}"}; do
    [ -n "$repo" ] || continue
    printf 'sync_ref %s "$REFS_DIR/%s" || skip_repo %s\n' "$repo" "${repo##*/}" "${repo##*/}"
  done
  printf '[ "$OK_COUNT" -gt 0 ] || echo "warning: 書き込む先を 1 つも用意できませんでした" >&2\n'
}

# ~/work/CLAUDE.md。claude が ~/work から始まるので、そこで読まれる。
# 表は config.sh の REPOS / REFS とその行末のコメントから作る。
build_work_claude_md() {
  cat <<'EOS'
# 作業場所

この VM で、モバイルアプリを開発する。
このファイルは `mise run start` のたびにホストが作り直すので、VM の中で編集しない。

## リポジトリ

書き込めるリポジトリは `~/work/<名前>` にある。
起動のたびに `git fetch` だけして、作業ツリーとブランチには触らない。
ブランチは自分で切る。デフォルトブランチへ直接 push しない。
`~/work/sessions/<日時>/<名前>` の作業ツリー（ブランチ `agent/<日時>`）で会話が始まっていたら、そこが自分の作業場所になる。
ほかの会話とは混ざらないので、`~/work/<名前>` には触らない。

| リポジトリ | 内容 |
|---|---|
EOS
  repo_rows "$ROOT/config.sh" REPOS
  if [ "${#REFS[@]}" -gt 0 ]; then
    cat <<'EOS'

読むだけのリポジトリは `~/work/refs/<名前>` にある。編集しない。
変更が要るときは、その内容を pull request に書く。

| リポジトリ | 内容 |
|---|---|
EOS
    repo_rows "$ROOT/config.sh" REFS
  fi
  cat <<'EOS'

## 通信

出られるのは許可した宛先だけ。
`Could not resolve host`（終了コード 6）は、その宛先が許可に入っていないということ。
一時的な不調ではないので、再試行しても通らない。
同じ宛先は 2 回までしか試さず、待たない。
許可に足すのはユーザーで、ホスト側の `config.d/allow.sh` の `ALLOW` に書いて VM を起動し直す。
足りない宛先は、ユーザーに伝える。

## ビルド

Xcode のプロジェクトは `xcode-build` スキルを使う。
iOS シミュレータでアプリを動かして画面を確かめるのは `device-interaction` スキル（入っていれば）。
Gradle のプロジェクトは `gradle-build` スキル、エミュレータで確かめるのは `android-cli` スキル（入っていれば）。
画面は `android layout` が返す文字で確かめる。`android screen capture` で撮った画像は開かない。
実行時の挙動は、`sim-log`（iOS）か `android-log`（Android）でログを読む。

## pull request

`pr-create` スキルで出す。Draft のまま出して、マージしない。
レビューは `review` スキル。
EOS
}

# config.sh の配列から "owner/repo"  # 説明 の行を拾い、表の行にする。
# 配列は他の config.local.sh で置き換わることがあるので、実際の値（REPOS/REFS）を主にして、説明だけ config.sh から引く。
repo_rows() {
  local file=$1 name=$2 repo desc
  eval "set -- \${$name[@]+\"\${$name[@]}\"}"
  for repo in "$@"; do
    [ -n "$repo" ] || continue
    desc=$(grep -hF "\"$repo\"" "$file" "$ROOT/config.local.sh" 2>/dev/null | sed -n 's/.*#[[:space:]]*//p' | head -1)
    printf '| `%s` | %s |\n' "${repo##*/}" "${desc:-}"
  done
}
