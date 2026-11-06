# 本文の書き方

本文はファイルに書いて `--body-file` で渡す。`--fill` は使わない。

リポジトリに `.github/PULL_REQUEST_TEMPLATE.md` があれば、それを下書きにする。
**見出しと順番は変えない。** 無いときだけ、下の形で書く。

```bash
BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)

if [ -f .github/PULL_REQUEST_TEMPLATE.md ]; then
  cp .github/PULL_REQUEST_TEMPLATE.md /tmp/pr-body.md   # 各見出しの下を埋める
else
  cat > /tmp/pr-body.md <<'EOF'
<何を変えたか。1〜2 段落>

## 動作確認

<実際に確かめた振る舞いや画面>

## 実機で見てほしいこと

<実機で確かめてほしいこと。無ければ「該当なし」>
EOF
fi

gh pr create --draft --assignee @me --base "$BASE" --title "..." --body-file /tmp/pr-body.md
```

## テンプレートの埋め方

- 見出しは消さない。当てはまらない節は「該当なし」と書く
- 先頭の `<!-- ... -->`（レビューの言語の指定など）は残し、その言語で書く
- 「関連 issue」や `ref:` には、関連する issue やチケットの URL を書く（無ければ書かない）
- 「作業内容」「動作確認」の `やったこと1`、`確認1` などの雛形の文言は残さず、実際の項目にする
- 動作確認のチェックは、実際に確かめた項目だけ `[x]` にする。確かめていないものは `[ ]` のままにして、理由を添える
- QA 資料の更新など、人がする作業は `[ ]` のままにして「人が行う」と書く
- 変更前と変更後を、「イメージ」の節か「動作確認」に並べる。[画像と動画](media.md)。挙動が変わらない修正でも並べる

