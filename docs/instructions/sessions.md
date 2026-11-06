# 会話の再開と並行作業

`mise run start` で VM が動いている間は、`mise run claude` を何回でも実行できる。
ターミナルを分ければ、会話が同時に何本でも走る。
会話は VM の `~/.claude` に保存されるので、VM を止めても消えない。

## 新しい会話を始める

```bash
mise run claude
```

VM の `~/work` で claude が開く。
`REPOS` のリポジトリが全部並んでいるので、横断して見たいときや、ちょっと試したいときはこれで足りる。

claude に渡したい引数は `--` のあとに書く。

```bash
mise run claude -- --model opus
```

`config.sh` の `CLAUDE_ARGS`（既定は `--dangerously-skip-permissions`）は、毎回先頭に付く。

## 作業を分ける

同じ `~/work/<名前>` を複数の会話で触ると、お互いの変更が混ざる。
並行して別々の作業をするなら、`--repo` で作業ツリーを切る。

```bash
mise run claude --repo ConnpassFinder
```

次のものが用意されて、そこで claude が開く。

- 作業ツリー: `~/work/sessions/<日時>/ConnpassFinder`
- ブランチ: デフォルトブランチから切った `agent/<日時>`
- `local.properties` や `secret.properties`: 元の clone から持ってくる
- `Pods/`: 元の clone と `Podfile.lock` が同じなら、APFS の複製で持ってくる

名前は `config.sh` の `REPOS` にあるもの。
毎回新しい作業ツリーになるので、ビルドの成果物は引き継がれない。

作業ツリーは、自動では消えない。
要らなくなったら、VM の中で消す。

```bash
git -C ~/work/ConnpassFinder worktree remove ~/work/sessions/<日時>/ConnpassFinder
git -C ~/work/ConnpassFinder branch -D agent/<日時>
```

## 前の会話を再開する

claude を抜けるときに、次のような行が出る。

```
Resume this session with:
claude --resume 0c1f2a3e-....
```

この ID を、そのまま渡す。

```bash
mise run claude 0c1f2a3e-....
```

VM の中で ID から会話を探して、始めたフォルダに移ってから、`claude --resume` を開く。
作業ツリーで始めた会話なら、その作業ツリーに戻ってくる。

ID を控え忘れたときは、VM の中で探す。

```bash
tart exec <VM 名> /bin/bash -lc 'ls -t ~/.claude/projects/*/*.jsonl | head'
```

ファイル名の `.jsonl` の前が ID になる。
あるいは、`mise run claude` で開いて、claude の中で `/resume` を使えば、`~/work` で始めた会話の一覧が出る。

## 気をつけること

- 動いている claude に、あとから繋ぐことはできない。保存された会話から、新しい claude を立ち上げて続きを話す
- `mise run start` を止めると、VM の中の claude も閉じられる。会話は保存されているので、起動し直してから再開すればいい
- 会話の履歴は VM のディスクにある。`tart delete` で VM を消すと、履歴も一緒に消える
