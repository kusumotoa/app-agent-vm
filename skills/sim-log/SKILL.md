---
name: sim-log
description:
  シミュレータのログを読む。ビルドは通るのに動きがおかしいとき。
---

# シミュレータのログ

Xcode MCP が返すのはビルドとテストの結果だけ。実行中の振る舞いは `simctl` で引く。

## 起きたことを後から読む

```bash
xcrun simctl spawn booted log show --last 5m --style compact \
  --predicate 'subsystem BEGINSWITH "<Bundle ID>"'
```

`--last` は `30s` `5m` `1h` の形。範囲を広げる前に述語で絞る。絞らないと OS 全体のログが返り、
文脈が埋まる。

## 操作しながら読む

```bash
xcrun simctl spawn booted log stream --style compact \
  --predicate 'subsystem BEGINSWITH "<Bundle ID>"' > /tmp/app.log &
LOG=$!
# ここで DeviceInteractionSynthesize を使ってアプリを操作する
kill "$LOG"
```

## 落ちたとき

```bash
ls -t ~/Library/Logs/DiagnosticReports/*.ips | head -3
```

クラッシュレポートはホストのこのパスに出る。スタックトレースはこちらにしかない。

## 絞り込み

| 見たいもの | 述語 |
|---|---|
| 自分のアプリだけ | `subsystem BEGINSWITH "<Bundle ID>"` |
| プロセス名で | `process == "<アプリ名>"` |
| エラーだけ | `messageType == error` |
| 本文で | `eventMessage CONTAINS "<文字列>"` |

`--style compact` は 1 行 1 件、`json` は機械で読める。

`print` は出ない。調べるために足すなら `Logger` を使う。
