# VM の中でシークレットとビルドの環境変数を揃える。boot-in-vm.sh が読む。
# 共有フォルダは mise run claude の間だけある。VM のディスクには何も書かない。
S="/Volumes/My Shared Files/shared"

export GITHUB_TOKEN="$(cat "$S/github-token")"
export GH_TOKEN="$GITHUB_TOKEN"

[ -f "$S/github-token-ro" ] && export GH_TOKEN_RO="$(cat "$S/github-token-ro")"
[ -f "$S/github-packages-token" ] && export GPR_KEY="$(cat "$S/github-packages-token")" GPR_USER="$(cat "$S/github-login")"

[ -d ~/android-sdk ] && export ANDROID_HOME=~/android-sdk
command -v java >/dev/null && export JAVA_HOME="$(cd "$(dirname "$(command -v java)")/.." && pwd)"

# 更新は brew が行う。本質的でない通信（テレメトリ、更新確認）は出さない。
export DISABLE_AUTOUPDATER=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

:
