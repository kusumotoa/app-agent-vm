#!/bin/bash
# VM の中を用意する（git、署名鍵、スキル、リポジトリ）。mise run start が、起動のたびに一度だけ呼ぶ。
# claude を開くのは mise run claude（lib/vm-env.sh を読んでから）。
set -e

S="/Volumes/My Shared Files/shared"

. "$S/env.sh"

# ビルドのたびに本番の Crashlytics へマッピングを送らない。
mkdir -p ~/.gradle/init.d
cat > ~/.gradle/init.d/no-crashlytics-upload.gradle <<'EOG'
allprojects {
    tasks.configureEach {
        if (name.startsWith("uploadCrashlyticsMappingFile")) enabled = false
    }
}
EOG

gh auth setup-git 2>/dev/null || true
git config --global user.name  "$(cat "$S/git-name")"
git config --global user.email "$(cat "$S/git-email")"

if [ -f "$S/signing-key" ]; then
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  cp "$S/signing-key" ~/.ssh/signing && chmod 600 ~/.ssh/signing
  ssh-keygen -y -f ~/.ssh/signing > ~/.ssh/signing.pub
  git config --global gpg.format ssh
  git config --global user.signingkey ~/.ssh/signing
  git config --global commit.gpgsign true
fi

# スキルは共有フォルダが消えても残るよう、コピーする。
mkdir -p ~/.claude
rm -rf ~/.claude/skills
cp -R "$S/skills" ~/.claude/skills

# Xcode 同梱のスキルは、Xcode の plugin を入れる。起動のたびに入れ直すので、Xcode を上げれば追従する。
# plugin path は、標準入力を閉じないと、パスを出したあとも待ち続ける。
XP="$(xcrun agent plugin path --plugin-format claude < /dev/null 2>/dev/null)"
if [ -d "$XP/skills" ]; then
  XM=~/.claude/xcode-marketplace
  claude plugin uninstall xcode-integration@xcode-local < /dev/null >/dev/null 2>&1 || true
  claude plugin marketplace remove xcode-local < /dev/null >/dev/null 2>&1 || true
  rm -rf "$XM"
  mkdir -p "$XM/.claude-plugin"
  cp -R "$XP" "$XM/xcode-integration"
  chmod -R u+w "$XM/xcode-integration"
  cp "$S/xcode-marketplace.json" "$XM/.claude-plugin/marketplace.json"
  claude plugin marketplace add "$XM" < /dev/null >/dev/null &&
    claude plugin install xcode-integration@xcode-local < /dev/null >/dev/null ||
    echo "warning: Xcode のスキルを claude に入れられませんでした" >&2
else
  echo "warning: Xcode の plugin の場所を引けませんでした。Xcode のスキルは入りません" >&2
fi

# Xcode の MCP。動いている Xcode Service に固定してつなぐ（lib/xcode-mcp.sh）。
cp "$S/xcode-mcp.sh" ~/.claude/xcode-mcp.sh
chmod +x ~/.claude/xcode-mcp.sh
claude mcp get xcode >/dev/null 2>&1 ||
  claude mcp add --scope user xcode -- "$HOME/.claude/xcode-mcp.sh" >/dev/null ||
  echo "warning: Xcode の MCP を登録できませんでした" >&2

cp "$S/repos-lib.sh" ~/repos-lib.sh
cp "$S/repos.sh" ~/repos.sh
mkdir -p ~/work
cp "$S/work-CLAUDE.md" ~/work/CLAUDE.md
echo "==> リポジトリを用意します"
bash ~/repos.sh
