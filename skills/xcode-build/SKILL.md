---
name: xcode-build
description:
  Xcode プロジェクトをビルドし、テストする。iOS の変更を確かめるとき。
---

# Xcode のビルドとテスト

`xcodebuild` は自分で呼ばず、`xcode` MCP のツールを使う。

`XcodeOpenWorkspace` に `.xcodeproj` か `.xcworkspace` のパスを渡すと、workspace の識別子が返る。
ほかのツールはすべてこれを取る。

`BuildProject` でビルドし、`RunAllTests` でテストする。
ビルドが失敗したら `GetBuildLog` を読む。
