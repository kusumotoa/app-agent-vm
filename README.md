# app-agent-vm

Claude Code を、Mac の中の別の macOS（VM）で動かすための環境。
`mise run start` で VM を立ち上げておいて、`mise run claude` でその中に入る。
VM は止めるまで動き続けるので、ターミナルをいくつも開いて、会話を同時に走らせられる。
抜けた会話は、あとから ID で再開できる。

![mise run start で VM を立ち上げてから、claude で入って、止めるまでの流れ](docs/images/overview.svg)

VM には [Tart](https://github.com/openai/tart) を使っている。
Xcode が最初から入っているので、ビルドをホストに橋渡しする必要がない。

VM から外に出られるのは、`config.d/allow.sh` に書いた宛先だけ。
この制限は VM の外側で効かせているので、VM の中で root を取っても抜けられない。

Android のエミュレータだけは VM の中で動かない。
ホストで動かして、`mise run start` が VM に繋ぐ。
その通信も `pf` で絞っている。

最初に一度だけ[セットアップ](docs/instructions/setup.md)が要る。

## 使い方

```bash
mise run build            # VM のイメージを作る（最初の一回）
mise run start            # VM を起動して置いておく。このターミナルは開けたままにする
mise run claude           # 別のターミナルで。VM の中で新しい会話を始める
mise run claude <ID>      # 前の会話を再開する
mise run claude --repo <名前>   # 作業ツリーを切って、新しい会話を始める
mise run status           # 何が動いているか見る
mise run stop             # 別のターミナルから止める（start のターミナルで Ctrl-C でもいい）
```

`mise run claude` は、ターミナルを分ければ何本でも開ける。
会話の ID の調べ方や、作業ツリーの扱いは[会話の再開と並行作業](docs/instructions/sessions.md)に書いた。
claude の引数は `--` のあとに書く（`mise run claude -- --model opus`）。

VM を止めても、ディスクは残る。
clone したリポジトリ、Claude のログイン、会話の履歴は、次に起動したときも使える。

Claude の認証は 2 通りある。
`claude setup-token` で作った OAuth トークンを `mise run secrets` に入れておくか、入れずに、VM の中で初回だけログインする。
トークンの扱いは[シークレット](docs/instructions/secrets.md#claude-の-oauth-トークン)に書いた。

## 触るリポジトリ

`config.sh` の `REPOS` が書き込む先で、`REFS` が読むだけの先。
VM の `~/work/<名前>` と `~/work/refs/<名前>` に clone して、起動のたびに fetch だけする。
作業ツリーやブランチには触らないので、途中の変更が消えることはない。

`mise run claude` は、何も付けなければ `~/work` で開く。
そこに置く `CLAUDE.md` には、リポジトリの表と、通信の制限、ビルドの方法が書いてある。
この表は `config.sh` から毎回作り直す。

![VM の ~/work に、書き込む先と読むだけの先がどう置かれるか](docs/images/repos.svg)

増やしたいときは `config.local.sh` に `REPOS+=("owner/repo")` と書く。

claude は `--dangerously-skip-permissions` 付きで開く（`config.sh` の `CLAUDE_ARGS`）。
通信を絞った VM の中だけで動かす前提で、確認のたびに止まらないようにしている。
ただし、VM の中には PAT を渡してあるので、claude は対象のリポジトリに push できてしまう。
PAT の範囲を必要なリポジトリだけに絞っておくこと（[シークレット](docs/instructions/secrets.md)）。

確認を残したければ、`config.local.sh` に `CLAUDE_ARGS=()` と書く。

## どこに何があるか

![リポジトリのどこに何があるか](docs/images/layout.svg)

## もっと詳しく

| | |
|---|---|
| [セットアップ](docs/instructions/setup.md) | 最初の一回 |
| [会話の再開と並行作業](docs/instructions/sessions.md) | ID で再開する。`--repo` で作業ツリーを切る |
| [シークレット](docs/instructions/secrets.md) | キーチェーンから VM へ渡す方法 |
| [通信の制限](docs/instructions/network.md) | softnet と `ALLOW` |
| [Android のエミュレータ](docs/instructions/android.md) | ホストで動かして VM から繋ぐ |
| [VM の中のツールを更新する](docs/instructions/tools-update.md) | イメージを作り直さずに Android CLI を上げる |
| [困ったとき](docs/instructions/troubleshooting.md) | 症状から探す |
