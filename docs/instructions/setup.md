# セットアップ

Homebrew と [mise](https://mise.jdx.dev) が入っていれば、あとは上から順に実行していくだけ。

```bash
# 1. このリポジトリで mise を信頼する
cd app-agent-vm
mise trust

# 2. tart、packer、softnet、gh を入れる
mise bootstrap

# 3. softnet に SUID を付ける（VM の外から通信を絞るのに要る）
#    sudo が要るので、普通のターミナルで実行する
mise run softnet-suid

# 4. 自分用の設定を作る
cp config.local.sh.example config.local.sh
$EDITOR config.local.sh

# 5. GitHub にログインする
gh auth login
gh auth refresh -h github.com -s admin:ssh_signing_key

# 6. シークレットを登録する（ターミナルで直接）
#    PAT は Resource owner を kusumotoa にして作る（secrets.md）
mise run secrets

# 7. 足りないものがないか見る。出てきた手順をやって、何も出なくなるまで繰り返す
mise run preflight

# 8. VM を作る（イメージの取得に時間がかかる）
mise run build

# 9. VM を起動する。このターミナルは開けたままにする
mise run start

# 10. 別のターミナルで、claude を開く。初回はログインが始まるので、出てくる手順に従う
mise run claude
```

`mise run build` は、Packer がホストから VM に SSH で入る。
使っているターミナルアプリに、システム設定のプライバシーとセキュリティ > ローカルネットワークの許可が無いと、ここで `Timeout waiting for SSH` になる。
許可を付けたら、ターミナルアプリを一度終了して起動し直す。

## Android も使うなら

`mise run android-user` を実行して、AVD を用意する（[Android のエミュレータ](android.md)）。
Symphony を使う別構成ですでにやっていれば、`android-user` は要らない。
