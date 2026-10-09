# 0233. 初回リリース版は GitHub Releases で環境ごとの tar.gz と SHA256SUMS を配り、導入の手順を文書に書く

- 状態: 採択（決定 1・2・4 の配布の形を、初回リリース版ではなく実行ファイルを配る最初のリリース（`0.1.0`）から適用することを [0358](0358-release-versions-and-published-history.md) で定めた。帰結のうち公開の時期は初回リリース（`0.0.1`）のままとした）
- 日付: 2026-09-29
- 関連章: [配布形態](../05-platform/05-01-distribution.md), [Agent Skills 対応](../06-tooling/06-06-agent-skills.md)
- 関連する未決事項: [OPEN-060](../open-issues.md#open-060)

## 背景

初回リリース版は、macOS（arm64）と Linux（x86_64・arm64）の三つの環境で処理系の実行ファイルを配る（[ADR 0176](0176-first-release-targets-and-static-linux-build.md)）。配り方（置き場所、ファイルの形、利用者が導入する手順）は決めていなかった。

設計書と処理系のソースは一つのリポジトリに置く（[ADR 0040](0040-single-repository.md)）。

macOS では、Gatekeeper が、App Store の外から配られたソフトウェアの Developer ID の証明書を確かめる。Developer ID の証明書を作るには、Apple Developer Program のチームのアカウントの持ち主である必要がある（[Developer ID](https://developer.apple.com/developer-id/)、2026-09-29 に確認）。Apple Developer Program の会費は、会員の一年ごとに 99 米ドルである（[What's included](https://developer.apple.com/programs/whats-included/)、同日に確認）。

## 決定

1. 初回リリース版は GitHub Releases で配る。環境ごとに一つの `tar.gz` のアーカイブ（[ADR 0176](0176-first-release-targets-and-static-linux-build.md) の三つ）と、各アーカイブの SHA-256 のハッシュ値を並べた `SHA256SUMS` を置く。
2. 導入の手順（アーカイブの展開、実行ファイルを `PATH` の通ったディレクトリに置くこと、`benitoite skill install`）を文書に書く。`curl … | sh` の形の導入のスクリプトは用意しない。
3. Homebrew などのパッケージ管理の仕組みでの配布は、初回リリース版の後に検討する。
4. 初回リリース版では、macOS の実行ファイルに署名と公証（notarization）を行わない。ブラウザでダウンロードしたときに Gatekeeper が出す警告への対処を文書に書く。
5. ソースからビルドして導入する手順（`cargo install`）も文書に書く。

## 検討した代替案

- **初回リリース版で、導入のスクリプトと Homebrew の tap を用意する**: 利用者の手順が一行になる。しかし、導入のスクリプトは、利用者が中身を読まずにシェルで実行する形であり、スクリプトの保守と試験も要る。tap は macOS と Linux の Homebrew の利用者にしか役立たず、リポジトリをもう一つ保つ必要がある。初回リリース版の利用者は、展開して置くだけの手順で導入でき、その手順は Agent Skills を使う LLM にも実行させられる。

## 帰結

- このリポジトリを GitHub で公開し、同じリポジトリの Releases で配る。公開は、初回リリース版をリリースするときに行う（設計者の決定）。公開の前に、設計メモ（`docs/design/sources/fp-language-design.md`）を公開の対象から外すか、非公開のリポジトリへ移すかを決める（[OPEN-061](../open-issues.md#open-061)）。
- 利用者は、ダウンロードしたアーカイブを `SHA256SUMS` で確かめられる。`SHA256SUMS` 自体には署名しないので、GitHub Releases の置き場所を信頼することが前提になる。
- 署名と公証を行わないので、macOS でブラウザからダウンロードした実行ファイルは、Gatekeeper に止められうる。どの条件で止められ、どう対処できるかは【要検証】である（[OPEN-060](../open-issues.md#open-060)）。署名と公証は、Apple Developer Program に加わると決めたときに改めて検討する。
- Windows の利用者は、WSL2 の中で Linux 向けのアーカイブを使う。
