# 画像と動画

撮り方は [pr-create の画像と動画](../../pr-create/references/media.md)。

確かめた結果は、PR のコメントに `--attach` で添える。本文にローカルのパスを書いてもレビューする人には届かない。

```bash
gh pr comment <番号> --body-file /tmp/review.md \
  --attach '/tmp/after.png#確かめた画面'
```

`gh pr review` に `--attach` は無い。画像を付けるときはコメントで出す。

## 添えるもの

| 付ける | 付けない |
|---|---|
| 本文の画像と実際の画面が違った | 本文のとおりだった |
| 本文に無い崩れを見つけた | 見た目が変わらない差分 |
| 動画でないと伝わらない遷移 | |

## 幅を指定する

`--attach` が書き換えるのは `![alt](./path)` だけで、HTML のタグは書き換わらない。
幅を指定するときは、先に上げて URL を取り、コメントを組み直す。

```bash
gh pr comment <番号> --body-file /tmp/review.md --attach /tmp/after.png
gh pr view <番号> --json comments -q '.comments[-1].body' |
  grep -oE 'https://github.com/user-attachments/assets/[a-zA-Z0-9-]+'
gh pr comment <番号> --edit-last --body-file /tmp/review-final.md
```

画像は `<img src="<URL>" width="250" />`、動画は `<video src="<URL>" width="250" controls></video>`。
