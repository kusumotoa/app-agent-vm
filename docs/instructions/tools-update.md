# VM の中のツールを更新する

イメージは作り直さず、起動中の VM に `tart exec` で実行する。
VM 名は `config.local.sh` の `VM_NAME` で、以下の例は `app-agent-vm`。
VM のディスクは残るので、次の起動にも効く。
`mise run build` で作り直すと消える。

## Android CLI

`android` は mise で入る（`vm/config.toml`）。
`mise run build` で作る VM には、そのとき `minimum_release_age` を満たす最新が入る。
すでにある VM は下で更新する。

```bash
mise exec -- tart exec app-agent-vm /bin/bash -lc 'mise upgrade android-cli && mise exec -- android -V'
```

要る宛先は `dl.google.com`。

スキル（`skills/android-cli/`）は、[Android のエミュレータ](android.md)の入れ方と同じコマンドで更新する。
VM への反映は、`mise run start` をやり直すだけ。
