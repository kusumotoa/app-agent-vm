# 通信を許可する宛先。ここに書いたものだけ VM から出られる。
# 名前（api.github.com など）はホストが代わりに繋ぐ（443 の HTTPS だけ）。
# @host（ブリッジのゲートウェイ）、@github（公開レンジ）と CIDR は softnet が通す。
ALLOW=(
  "@host"
  "@github"
  "17.0.0.0/8"           # Apple。ユニバーサルリンク、ランタイム、証明書の確認
  "app-site-association.cdn-apple.com"       # ユニバーサルリンクの検証（Apple の CDN）
  "app-site-association.networking.apple"
  "developer.apple.com"
  "www.apple.com"
  "apple.com"

  # Claude Code。ログイン（claude.ai、platform.claude.com）と API
  "api.anthropic.com"
  "claude.ai"
  "platform.claude.com"
  "console.anthropic.com"

  # エージェントが VM から使う先。起動の検証（api.github.com）もここを通る
  "api.github.com"
  "uploads.github.com"
  "github.com"

  # brew
  "formulae.brew.sh"                # claude-code の更新（brew）
  "ghcr.io"                         # brew 自身の Portable Ruby
  "pkg-containers.githubusercontent.com"

  # CocoaPods と Swift Package（iOS）
  "cdn.cocoapods.org"
  "cdn.jsdelivr.net"
  "codeload.github.com"
  "raw.githubusercontent.com"

  # Android を組み立てる先
  "services.gradle.org"             # 配布物は github.com から release-assets.githubusercontent.com へ 302 で飛ぶ
  "release-assets.githubusercontent.com"
  "plugins.gradle.org"
  "plugins-artifacts.gradle.org"    # plugins.gradle.org から 302 で飛ぶ
  "dl.google.com"
  "repo.maven.apache.org"
  "repo1.maven.org"
  "jcenter.bintray.com"             # repo1.maven.org へ 301 で飛ばす
  "maven.google.com"                # repository の並びの途中にある。届かないと後ろの成果物も解決できない

)
