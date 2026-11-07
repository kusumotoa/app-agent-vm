# 画像と動画

添付は `--attach` で渡す。本文にローカルのパスを書いてもレビューする人には届かない。

撮った画像は開かない（プロンプトの "You cannot look at images"）。
画面が意図どおりかは画面の文字で確かめる。Android の引き方は `android-cli` スキル。

```bash
gh pr create --draft --base "$BASE" --title "..." --body-file /tmp/pr-body.md \
  --attach '/tmp/after.png#変更後の挨拶'
```

## 撮る（iOS）

`DeviceInteractionSynthesize` が一時ディレクトリにスクリーンショットを書くので、
そのパスをツールの結果から取る。移動も改名も要らない。

遷移やアニメーションのとき。

```bash
xcrun simctl io booted recordVideo --codec h264 --force /tmp/run.mov &
REC=$!
# ここで DeviceInteractionSynthesize を使ってアプリを操作する
kill -INT "$REC"; wait "$REC"
```

止めるのは `kill -INT`。`Recording started` が stderr に出てから操作を始める。
拡張子は `.mov`、コーデックは `h264`。

## 撮る（Android）

`adb devices` で `device` で終わる行が無ければ撮れない。`offline` は繋がっていない。

インストール、起動、操作は `android-cli` スキル。操作したあとの画面を撮る。

```bash
adb exec-out screencap -p > /tmp/after.png
```

遷移やアニメーションのとき。

```bash
adb shell screenrecord --time-limit 20 /sdcard/run.mp4 &
REC=$!
# ここで adb shell input でアプリを操作する
kill -INT "$REC"; wait "$REC"
while adb shell pgrep screenrecord >/dev/null 2>&1; do sleep 1; done
adb pull /sdcard/run.mp4 /tmp/run.mp4 && adb shell rm /sdcard/run.mp4
```

`--time-limit` を超えると自分で止まる。音声は入らない。
端末に書き終わるのを待ってから取り出す。取り出せたときだけ消す。

## 共通

上限は 10 MB なので、変化が見える数秒だけ撮る。

変更前と変更後を並べる。挙動が変わらない修正でも付ける。

スクリーンショットも動画もリポジトリにコミットしない。

## 画面に出ないとき

同じ操作の出力を変更前と変更後で取り、コードブロックで並べる。毎回変わる値は揃えてから比べる。

## 本文に並べる

**幅は必ず指定する。** 端末のスクリーンショットは 1280px 以上あり、そのまま貼ると本文を
埋め尽くしてレビューできない。

`--attach` が書き換えるのは markdown の `![alt](./path)` と `[text](./path)` だけで、
HTML のタグは書き換わらない。**先に上げて URL を取り、本文を組み直す。**

```bash
gh pr create ... --attach /tmp/before.png --attach /tmp/after.png
gh pr view --json body -q .body | grep -oE 'https://github.com/user-attachments/assets/[a-zA-Z0-9-]+'
gh pr edit --body-file /tmp/pr-body-final.md
```

画像は `<img>`、動画は `<video>` で書く。幅は 250 を目安にする。

```markdown
| | 変更前 | 変更後 |
| --- | --- | --- |
| 挨拶の表示 | <img src="<URL>" width="250" /> | <img src="<URL>" width="250" /> |
| 起動からの遷移 | <video src="<URL>" width="250" controls></video> | <video src="<URL>" width="250" controls></video> |
```

1 つだけのときも `<img>` と `<video>` で書く。

```markdown
<img src="<URL>" width="250" />
<video src="<URL>" width="250" controls></video>
```

動画に代替テキストは付けられない。**動画を表のセルに入れるとリンクに落ちる。**
