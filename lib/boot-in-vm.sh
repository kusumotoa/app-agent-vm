#!/bin/bash
# VM の中で、claude を立ち上げるところまで。mise run claude が tart exec -it で呼ぶ。
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

# 認証は VM の中で行う。初回と失効したときは、claude が出す手順でログインする。
cd ~/work
eval "set -- $(cat "$S/claude-args")"
exec claude "$@"
