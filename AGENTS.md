# app-agent-vm

- 操作は mise run start / claude / status / stop、検査は mise run test、イメージの作り直しは mise run build
- 使い方と構成は README.md
- VM の中身は tart.pkr.hcl と vm/mise.toml
- シェルはホストの bash 3.2 で動く。合わない書き方は mise run test が見つける
- docs は 1 文 1 行で書く（太字は行の中で閉じる）
- 困ったら @docs/instructions/troubleshooting.md を先に見る
- pf の anchor（acvemu）は、Symphony を使う別構成と共有している。名前を変えるときは両方で揃える
