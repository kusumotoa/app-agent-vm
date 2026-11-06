---
name: android-log
description:
  エミュレータのログを読む。ビルドは通るのに動きがおかしいとき。
---

# Android のログ

Gradle が返すのはビルドとテストの結果だけ。実行中の振る舞いは `adb logcat` で引く。

`adb devices` で `device` で終わる行が無ければ読めない。`offline` は繋がっていない。

## 自分のアプリだけ読む

```bash
adb logcat -d --pid="$(adb shell pidof -s <パッケージ>)"
```

`-d` は溜まっている分を出して終わる。絞らないと OS 全体が返り、文脈が埋まる。

プロセスが落ちて再起動していると PID が変わる。読む直前に引き直す。

## 操作しながら読む

```bash
adb logcat -c
adb logcat --pid="$(adb shell pidof -s <パッケージ>)" > /tmp/app.log &
LOG=$!
# ここで adb shell input でアプリを操作する
kill "$LOG"
```

`-c` で先に消しておくと、操作の前後が混ざらない。

## 落ちたとき

```bash
adb logcat -d -b crash
```

`FATAL EXCEPTION` とスタックトレースがここに出る。通常のバッファにも出るが、`crash`
バッファの方が探しやすい。

ネイティブのクラッシュと ANR は別の場所に残る。

```bash
adb shell ls /data/tombstones
adb shell ls /data/anr
```

## 絞り込み

| 見たいもの | 書き方 |
|---|---|
| 自分のアプリだけ | `--pid="$(adb shell pidof -s <パッケージ>)"` |
| エラー以上だけ | `'*:E'` |
| タグで | `-s <タグ>:I` |
| 直近 N 行 | `-t <N>` |
| ある時刻から | `-t '<MM-DD hh:mm:ss.mmm>'` |
| クラッシュだけ | `-b crash` |

`-v time` で時刻を付け、`-v threadtime` でスレッド ID まで出る。

`System.out.println` は出ない。調べるために足すなら `android.util.Log` を使う。
