---
name: android-ui
description:
  Android エミュレータでアプリを動かし、画面を確かめる。見た目や遷移が変わる Android の変更のとき。
---

# エミュレータの操作

`adb devices` で `device` で終わる行が無ければ操作できない。`offline` は繋がっていない。

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -W -n <パッケージ>/<Activity>
```

## 画面は文字で確かめる

画面の階層（文字）を読み、表示の文字、有無、順序で確かめる。
色、余白、はみ出しは確かめられない。確かめていないと PR に書き、人に任せる。

```bash
adb exec-out uiautomator dump /dev/tty
```

端末にファイルを残さない。`adb shell uiautomator dump <パス>` は残し、エミュレータは作り直さないので、セッションをまたいで溜まり続ける。
末尾の `UI hierchary dumped to: /dev/tty` は XML ではない。
要素は `text="..."` と `bounds="[左,上][右,下]"` を持つ。文字の `&` は `&amp;` になる。

## 操作する

文字から `bounds` を探し、中心をタップする。

```bash
adb exec-out uiautomator dump /dev/tty | grep -o 'text="Network[^"]*"[^>]*bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"'
echo '[252,755][648,820]' | sed 's/[][,]/ /g' | awk '{print int(($1+$3)/2), int(($2+$4)/2)}'
```

```bash
adb shell input tap 450 787
adb shell input swipe 672 2200 672 800 300
adb shell input text "hello%sworld"
adb shell input keyevent KEYCODE_BACK
```

`%s` が空白になる。
操作のあと、画面が変わるのを 1〜2 秒待ってから階層を読み、変わったことを確かめる。
入力欄の `text` は、階層で空のままのことがある。入力が効いたかは、入力で変わる一覧の文字で確かめる。
