# 困ったとき

| 症状 | 原因と直し方 |
|---|---|
| ホストで `tart: command not found` | tart は mise の管理下で、このリポジトリのディレクトリでしか使えない。`cd app-agent-vm && mise exec -- tart <cmd>` で呼ぶ |
| VM が起動しなくて `root privileges are required` | softnet に SUID が付いていない。`mise run preflight` が手順を出してくれる。sudo なので、普通のターミナルで実行する |
| `mise run claude` が「VM がありません」で止まる | まだ `mise run build` をしていない。`tart list` に `VM_NAME` の VM があるか見る |
| 「すでに起動しています」で止まる | 別のターミナルで動いているか、前回が落ちて VM が残っている。`mise run stop` |
| 起動したのに claude が開かない | 背景の出力は `$TMPDIR/<VM 名>.log` に出ている |
| ログインの URL が開けない | 表示された URL をホストのブラウザで開いて、出てきたコードを VM の中の claude に貼る。`claude.ai` と `platform.claude.com` が `ALLOW` に入っているかも確かめる |
| claude が `api.anthropic.com` に届かない | `ALLOW` に `api.anthropic.com` があるか。名前の宛先は 443 の HTTPS しか通らない |
| `Could not resolve host` | その宛先が `ALLOW` にない。足して `mise run claude` をやり直す（[通信の制限](network.md)） |
| 許可したはずの宛先に届かない | `ALLOW` に `@host` があるか。名前解決がブリッジのゲートウェイを通るので、これがないとどのドメインも引けない |
| `maven.pkg.github.com` が 401 | `github-packages-token` が登録されていない（[GitHub Packages の PAT](secrets.md#github-packages-の-pat)） |
| `maven.pkg.github.com` が 403 で `Resource protected by organization SAML enforcement` | PAT の SSO 認可がまだ。トークンの Configure SSO で、その組織を Authorize する |
| PAT で 404 が返る | リポジトリが PAT の範囲に入っていない（[PAT の作り方](secrets.md#pat-の作り方)） |
| PAT で 401 が返る | 有効期限が切れている。作り直して `mise run secrets` |
| PR にスクリーンショットが付かない | `uploads.github.com` が許可されているか。`@github` の範囲には入っていない |
| Xcode MCP が使えない | VM の中で `claude mcp list` に `xcode` があるか。なければ `claude mcp add --scope user xcode -- ~/.claude/xcode-mcp.sh` |
| AVD や anchor がないと言って止まる | VM を起動する前に確かめている。言われたものを用意する。Android を使わないなら `ANDROID_AVDS` を空にする |
| macOS を更新したら anchor がないと言われる | 更新で `/etc/pf.conf` が元に戻って、足した宣言が消えた。VM を止めて `mise run android-user` をやり直す |
| VPN をつないだら「VPN の anchor より後ろにあります」と言われる | VM を止めて `mise run android-user` をやり直すと、VPN の前に置き直してくれる |
| VPN をつないだら Apple や GitHub に届かない | IP で許可した宛先は、VPN の間だけ通らない。名前で `ALLOW` に足す（[VPN をつないだとき](network.md#vpn-をつないだとき)） |
| `mise run stop` のあとも規則が残っている | `printf '' \| sudo pfctl -a acvemu -f -` で外す |
| `mise run build` が `Timeout waiting for SSH` で止まる | Packer がホストから VM に SSH で入れていない。ターミナルアプリにローカルネットワークの許可がないと `no route to host` になる。システム設定のプライバシーとセキュリティ > ローカルネットワークで許可して、ターミナルアプリを終了して起動し直す。すでにオンなら、一度オフにして戻す |
