# チームで共有する設定。個人の値は config.local.sh に書く。
# シークレットは入れない（キーチェーンへ）。

# https://github.com/cirruslabs/macos-image-templates/pkgs/container/macos-tahoe-xcode
BASE_IMAGE="ghcr.io/cirruslabs/macos-tahoe-xcode:27.1"
VM_CPU=8
VM_MEMORY_GB=16
VM_BOOT_TIMEOUT=240        # 起動を待つ上限（秒）
POLICY_INTERVAL=300        # 通信先を解決し直す間隔（秒）

SIGNING_ROTATE_SECONDS=28800

# claude に渡す引数。VM は通信を絞ってあり、確認を挟むと作業が止まるので、権限の確認は省く。
# 確認を残すなら config.local.sh で CLAUDE_ARGS=() と書く。
CLAUDE_ARGS=(--dangerously-skip-permissions)

# エージェントに渡す AVD。
ANDROID_AVDS=()

# 書き込む先。VM の ~/work/<名前> に clone する。
# 足したり直したりしたら、ここだけを直せばよい。VM の ~/work/CLAUDE.md の表は、起動のたびにここから作る。
# config.local.sh で REPOS=(...) と書くと置き換わる。足すだけなら REPOS+=(...)。
REPOS=(
  "kusumotoa/ConnpassFinder"       # connpass API v2 の iOS アプリ（Swift、SwiftUI、SPM のマルチモジュール）
  "kusumotoa/TodoMemoApp"          # ToDo メモの iOS アプリ（Swift）
  "kusumotoa/TodoMemoAndroidApp"   # ToDo メモの Android アプリ（Kotlin）
)

# 読むだけのリポジトリ。~/work/refs/<名前> に置く。
# config.local.sh で REFS=(...) と書くと置き換わる。足すだけなら REFS+=(...)。
REFS=(
  "kusumotoa/sim-use"        # iOS シミュレータと Android エミュレータを、AI エージェントが操作する CLI（公開）
  "kusumotoa/iPhoneDuoLab"   # iPhone Duo（折りたたみ）向け API を動かして確かめる試行錯誤用（公開）
)

VM_NAME=""

# config.d/*.sh（通信の許可など）。config.local.sh の前に読むので、そちらで ALLOW+=(...) と足せる。
for f in "${BASH_SOURCE[0]%/*}"/config.d/*.sh; do . "$f"; done

LOCAL="${BASH_SOURCE[0]%/*}/config.local.sh"
[ -f "$LOCAL" ] || { echo "config.local.sh がありません。config.local.sh.example をコピーしてください" >&2; exit 1; }
. "$LOCAL"

# ホストが代わりに繋ぐ宛先。ALLOW のうち、名前で書いたもの。
RELAY=()
for entry in "${ALLOW[@]}"; do
  case "$entry" in
    @*) ;;
    *[!0-9./]*) RELAY+=("$entry") ;;
  esac
done
