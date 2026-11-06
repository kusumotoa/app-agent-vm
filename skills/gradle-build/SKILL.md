---
name: gradle-build
description:
  Gradle プロジェクトをビルドし、テストする。Android の変更を確かめるとき。
---

# Gradle のビルドとテスト

`./gradlew` を `exec` で実行する。
Android SDK は `$ANDROID_HOME` にある。

`adb devices` で、エミュレータが使えるか分かる。
`device` で終わる行だけが使える。`offline` と `unauthorized` は使えない。

使えるエミュレータが無ければ、ビルドと単体テストまでで止める。
実機で確かめることを、PR に書く。
