# 配布形態

- 状態: 確定
- 関連ADR: [0003](../decisions/0003-license.md), [0076](../decisions/0076-initial-implementation-in-rust.md), [0077](../decisions/0077-abolish-go-layer.md), [0090](../decisions/0090-version-numbers-and-codenames.md), [0138](../decisions/0138-crates-and-licenses-for-stdlib.md), [0174](../decisions/0174-mobile-as-dedicated-app-after-first-release.md), [0175](../decisions/0175-script-embedded-binary-before-stable-release.md), [0176](../decisions/0176-first-release-targets-and-static-linux-build.md), [0229](../decisions/0229-bundled-skill-contents-and-japanese-translations.md), [0230](../decisions/0230-skill-embedded-and-installed-by-subcommand.md), [0232](../decisions/0232-skill-evaluation-with-tasks-and-harnesses.md), [0233](../decisions/0233-distribution-via-github-releases.md), [0234](../decisions/0234-release-tests-on-development-machine.md), [0235](../decisions/0235-third-party-licenses-generated-and-shown-by-option.md), [0236](../decisions/0236-compatibility-during-0x.md), [0242](../decisions/0242-copyright-notice-for-llm-generated-code.md), [0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md), [0288](../decisions/0288-skill-documents-generated-by-tool-and-committed.md), [0290](../decisions/0290-copyright-holder-name-and-open-021.md), [0292](../decisions/0292-release-checks-needing-network-by-orchestrator.md)
- 未決事項: [OPEN-009](../open-issues.md#open-009), [OPEN-040](../open-issues.md#open-040), [OPEN-060](../open-issues.md#open-060), [OPEN-061](../open-issues.md#open-061)
- 移行元: [設計メモ](../sources/fp-language-design.md) 20

## 目的と範囲

処理系を利用者に配る形を定める。対象は、対応環境（OS と CPU）、処理系の実行ファイルの作り方、配布物と置き場所、利用者が導入する手順（Agent Skills の実行環境への Skill の導入を含む）、リリースのときの試験、配布物のライセンスと第三者の OSS の著作権表示、互換性の方針である。

現在の版は、初回リリース版の配布を定める。モバイルは初回リリース版の対象にしない（[モバイル・Android系](05-03-mobile.md)、[ADR 0174](../decisions/0174-mobile-as-dedicated-app-after-first-release.md)）。処理系コアの WASM 化も初回リリース版に含めない（[WASMコア化](05-02-wasm-core.md)）。設計メモ 20 の Go を前提にした記述（`go:embed`、`CGO_ENABLED=0`）は、処理系を Rust で実装し（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）、go.* の層を廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）ので、本章では扱わない。

## 前提

バージョンの付け方（メジャー・マイナー・パッチ、メジャーバージョンが 0 の間の扱い）は[ロードマップ](../00-overview/00-03-roadmap.md)の「バージョンとコードネーム」で定めた。本章の互換性の方針は、それに従って、メジャーバージョンが 0 の間の各版で変えてよいものを定める。正式リリース版で約束する範囲は [OPEN-040](../open-issues.md#open-040) で決める。

処理系・標準ライブラリ・同梱の Agent Skill のライセンスは `MIT OR Apache-2.0` である（[ADR 0003](../decisions/0003-license.md)）。依存のクレートと、許可するライセンスは [ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md) で定めた。同梱の Agent Skill の中身と導入のサブコマンドは [Agent Skills 対応](../06-tooling/06-06-agent-skills.md)で定める。

## 仕様

### 対応環境（初回リリース版）

【決定】初回リリース版は、次の環境で処理系の実行ファイルを配り、完了条件（[ロードマップ](../00-overview/00-03-roadmap.md)の「完了条件」）を確かめる（[ADR 0176](../decisions/0176-first-release-targets-and-static-linux-build.md)）。

| 環境 | Rust のビルド先 | 実行ファイルの依存 |
|---|---|---|
| macOS（arm64） | `aarch64-apple-darwin` | OS のシステムライブラリだけ。macOS 11.0 以降 |
| Linux（x86_64） | `x86_64-unknown-linux-musl` | なし（musl を静的にリンクする） |
| Linux（arm64） | `aarch64-unknown-linux-musl` | なし（musl を静的にリンクする） |

- Windows は、WSL2 の中の Linux で、上の Linux 向けの実行ファイルを使う。x86_64 の Windows でも arm64 の Windows でも同じである。Windows で直接動く実行ファイルは、初回リリース版では配らない。
- 各環境の実行ファイルは、その環境の OS の上でビルドする。処理系を開発するときの手元のビルドは、Linux でも既定のビルド先（glibc）でよい。
- ビルドに使う Rust のツールチェーンの版は、リポジトリの `rust-toolchain.toml` で固定する。
- musl の標準のメモリ確保が性能に与える影響は、初回リリース版の完了時の性能の測定で確かめる（[OPEN-009](../open-issues.md#open-009)）。
- 【方針】FreeBSD・OpenBSD・NetBSD は、余力があれば、初回リリース版の後から正式リリース版までの間に対応を検討する。
- モバイルは初回リリース版の対象にしない（前述）。スクリプトを埋め込んだ単一バイナリは、正式リリース版の前までに実装する（[ADR 0175](../decisions/0175-script-embedded-binary-before-stable-release.md)）。

### 配布物と置き場所（初回リリース版）

【決定】初回リリース版は GitHub Releases で配る（[ADR 0233](../decisions/0233-distribution-via-github-releases.md)）。このリポジトリは、初回リリース版をリリースするときに GitHub で公開する。公開の前に、設計メモの扱いを決める（[OPEN-061](../open-issues.md#open-061)）。一つのリリースに、次のものを置く。

| ファイル | 内容 |
|---|---|
| 環境ごとの `tar.gz` のアーカイブ（三つ） | 処理系の実行ファイル `benitoite`、第三者のライセンスの表示 `THIRD_PARTY_LICENSES`、処理系のライセンス文 `LICENSE-MIT`・`LICENSE-APACHE`（後述の「ライセンスの表示」） |
| `SHA256SUMS` | 各アーカイブの SHA-256 のハッシュ値の一覧 |

- 同梱の Agent Skill は、アーカイブにファイルとして入れず、実行ファイルに埋め込む（[ADR 0230](../decisions/0230-skill-embedded-and-installed-by-subcommand.md)）。
- 【方針】アーカイブの名前は、`benitoite-<バージョン>-<Rust のビルド先>.tar.gz` の形とする。
- `curl … | sh` の形の導入のスクリプトは用意しない。
- 【方針】Homebrew などのパッケージ管理の仕組みでの配布は、初回リリース版の後に検討する。
- `SHA256SUMS` には署名しない。利用者がアーカイブを確かめる根拠は、GitHub Releases の置き場所を信頼することである。

### 導入の手順（初回リリース版）

【決定】利用者向けの文書に、次の導入の手順を書く（[ADR 0233](../decisions/0233-distribution-via-github-releases.md)）。

1. 自分の環境のアーカイブと `SHA256SUMS` をダウンロードし、ハッシュ値を確かめる。
2. アーカイブを展開し、`benitoite` を `PATH` の通ったディレクトリに置く。
3. `benitoite skill install` を実行し、同梱の Agent Skill をエージェントの置き場所に書き出す（[Agent Skills 対応](../06-tooling/06-06-agent-skills.md)の「Skill の導入（初回リリース版）」）。

処理系を更新したときは、同じ手順で実行ファイルを置き換え、`benitoite skill install` を実行し直す。同梱の Skill は、同じ版の処理系だけを対象にするからである（後述の「互換性の方針」）。

【決定】初回リリース版では、macOS の実行ファイルに署名と公証（notarization）を行わない。Developer ID の証明書を作るには、Apple Developer Program のチームのアカウントの持ち主である必要があり（[Developer ID](https://developer.apple.com/developer-id/)）、Apple Developer Program の会費は会員の一年ごとに 99 米ドルである（[What's included](https://developer.apple.com/programs/whats-included/)。どちらも 2026-09-29 に確認）。利用者向けの文書には、ブラウザでダウンロードした実行ファイルを Gatekeeper が止めたときの対処を書く。どの条件で止められ、どう対処できるか（ダウンロードの方法による違い、隔離の属性を外す方法など）は【要検証】である（[OPEN-060](../open-issues.md#open-060)）。

### ソースからのビルド

【決定】ソースからビルドして導入する手順（`cargo install`）も、利用者向けの文書に書く（[ADR 0233](../decisions/0233-distribution-via-github-releases.md)）。

- 同梱の Agent Skill の生成する文書（設計書の[構文](../01-spec/01-02-syntax.md)の章から作る文法など）は、生成の道具で作ってリポジトリに置いてある。処理系のビルドは、それを実行ファイルに埋め込むだけであり、設計書を読まない（[ADR 0229](../decisions/0229-bundled-skill-contents-and-japanese-translations.md)、[ADR 0288](../decisions/0288-skill-documents-generated-by-tool-and-committed.md)）。【方針】手順は、リポジトリを取得して、処理系のクレートのディレクトリを `cargo install --locked --path` に指定する形とする。crates.io への公開は初回リリース版では行わない。
- ソースからのビルドは、リリースのスクリプトを通らないので、第三者のライセンスの一覧を埋め込まない（後述の「ライセンスの表示」）。
- Linux でソースからビルドした実行ファイルは、既定のビルド先（glibc）になる。musl で静的にリンクした実行ファイルが要るときは、配布物を使う。

### リリースの試験（初回リリース版）

【決定】リリースの試験は、配る実行ファイルそのものを使い、三つの環境のそれぞれで行う。ビルドと試験は、開発機（macOS の arm64）の上で一つのスクリプトから行い、CI は使わない（[ADR 0234](../decisions/0234-release-tests-on-development-machine.md)）。

| 環境 | ビルドと試験の場所 |
|---|---|
| macOS（arm64） | 開発機の上で直接行う |
| Linux（arm64） | 開発機の上の Linux のコンテナか軽量の仮想機械の中で行う。Linux の上でビルドするので、前述の「各環境の実行ファイルは、その環境の OS の上でビルドする」を満たす |
| Linux（x86_64） | x86_64 を模倣するコンテナ（Linux の仮想機械の Rosetta か QEMU）の中で行う。遅いが、リリースのときにしか行わない |

【決定】各環境で次のものを確かめる。

- `scripts/check.sh` が通る。
- 受け入れテスト（`testdata/acceptance/`）を配る実行ファイルで実行し、期待する結果になる。外部コマンドの起動（`Process.run`・`Process.shell`）は、テスト用のハンドラ表で置き換えず、実際に起動する（[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)の「受け入れ例と仕様の項目の対応」）。
- Linux の実行ファイルが、glibc のない最小のコンテナの中で起動する。
- `benitoite skill install` が、Skill を正しく書き出す。

【決定】同梱の Agent Skill の評価（[Agent Skills 対応](../06-tooling/06-06-agent-skills.md)の「Skill の評価」）は、構文・標準ライブラリ・Skill を変えたリリースでだけ行う。

- 【方針】スクリプトの名前は `scripts/release.sh` とする。手順の細部は実装プランで定める。
- 使うコンテナと仮想機械の道具と、x86_64 の模倣の上で Rust のビルドとテストが動くかは【要検証】であり、リリースの手順を書くときに選ぶ（[OPEN-060](../open-issues.md#open-060)）。
- 【方針】Windows の WSL2（Ubuntu 26.04 LTS）の中での確認は、開発機から SSH で WSL2 にログインし、Linux（x86_64）向けの実行ファイルを送って受け入れのテストを動かす形で、リリースのスクリプトから行う。行うのは、初回リリース版の完了を判定するときとマイナー版のリリースのときで、パッチ版では省く（[ADR 0176](../decisions/0176-first-release-targets-and-static-linux-build.md) の帰結、ADR 0234）。WSL2 に SSH でログインする設定は【要検証】である（[OPEN-060](../open-issues.md#open-060)）。
- 作ったアーカイブと `SHA256SUMS` は、試験を通った後に開発機から GitHub Releases に上げる。

### ライセンスの表示

【決定】第三者のライセンスの表示は次のように作り、示す（[ADR 0235](../decisions/0235-third-party-licenses-generated-and-shown-by-option.md)）。

- `THIRD_PARTY_LICENSES` は、リリースのスクリプトの中で、開発機の上で道具（cargo-about など）を使って生成する。道具は、`cargo deny` との役割の分け方を考えて実装プランで選ぶ。
- 【方針】`THIRD_PARTY_LICENSES` には、実行ファイルに含む依存のクレートごとに、名前・版・ライセンス・著作権表示・ライセンス文を載せ、Apache-2.0 のものは NOTICE ファイルの内容も載せる（[ロードマップ](../00-overview/00-03-roadmap.md)の「利用する既存の OSS のライセンス」）。依存のクレートはビルド先によって違いうるので、環境ごとに生成する。
- アーカイブには、実行ファイルに加えて、`THIRD_PARTY_LICENSES` と `LICENSE-MIT`・`LICENSE-APACHE` を入れる。
- 同じ `THIRD_PARTY_LICENSES` を実行ファイルに埋め込み、`benitoite --licenses` で標準出力に書く（[CLI](../06-tooling/06-01-cli.md)の「コマンドラインの形」）。そのために、環境ごとのビルドより前に生成する。
- 【方針】リリースのスクリプトを通さないビルド（開発のビルドと、ソースからのビルド）の `--licenses` は、処理系自身のライセンスと、第三者のライセンスの一覧を含まないビルドであることを書く。
- 同梱の Agent Skill のディレクトリにも、Skill のライセンス文を置く（[Agent Skills 対応](../06-tooling/06-06-agent-skills.md)の「同梱の Agent Skill の構成」）。

【決定】処理系自身の著作権表示は、次のように書く（[ADR 0242](../decisions/0242-copyright-notice-for-llm-generated-code.md)）。

- 著作権表示は `Copyright (c) 2026 tecogonaz and Benitoite contributors` とする（[ADR 0290](../decisions/0290-copyright-holder-name-and-open-021.md)）。`LICENSE-MIT` と、リポジトリの README の著作権表示に使う。
- リポジトリの README と、ライセンスのファイル（`LICENSE-MIT`・`LICENSE-APACHE`）の近くに、処理系のコードの大部分は LLM が生成したものであり、設計者は設計と生成したコードの確認を行ったことを書く。あわせて、ライセンスは著作権で保護される部分に適用され、保護されない部分はもともと誰でも自由に使えるので、利用者に許される範囲はどちらでも変わらないことを書く。
- どの部分が著作権で保護されるかについて、法的な結論は書かない。公開の前に、必要であれば専門家に確認する。

【方針】スクリプトを埋め込んだ実行ファイルについてランタイムの例外を設けるかは、その実行ファイルを設計するとき（正式リリース版の前。[ADR 0175](../decisions/0175-script-embedded-binary-before-stable-release.md)）に、埋め込む形とあわせて決める（[ADR 0290](../decisions/0290-copyright-holder-name-and-open-021.md)）。

### 互換性の方針

【決定】メジャーバージョンが 0 の間の互換性は、次のとおりとする（[ADR 0236](../decisions/0236-compatibility-during-0x.md)）。

| 版 | 例 | 変えてよいもの |
|---|---|---|
| マイナーの版 | `0.1.0` から `0.2.0` | 言語・標準ライブラリ・CLI・診断の互換性を壊す変更を含めてよい |
| パッチの版 | `0.1.0` から `0.1.1` | 不具合の修正だけを含め、互換性を壊さない |

- パッチの版で直す不具合は、処理系が仕様と食い違う振る舞いである。仕様（言語・標準ライブラリ・CLI・診断コードと JSON の形）は、パッチの版では変えない。仕様と食い違う振る舞いに頼っていたスクリプトは、パッチの版で動かなくなることがある。
- 【方針】診断の文言と修正案の中身は、互換性の約束に含めない。パッチの版でも改めてよい。ハーネスは、診断を文言ではなくコードと JSON の欄で見分ける。
- 互換性を壊す変更は、`CHANGELOG` に、移行の手順とともに記録する。
- 非公式のモジュール（[標準ライブラリ](../03-interop/03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」）を標準に移すと、取り込みの名前が変わる。これは互換性を壊す変更であり、マイナーの版で行う。非公式のモジュールも、パッチの版では変えない（[ADR 0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md)）。
- 廃止した診断コードの番号は、別の意味で使い回さない（[ADR 0031](../decisions/0031-numbered-diagnostic-codes.md)）。
- 処理系はコンパイル済みプログラム（バイトコード）を保存も配布もしない（[パイプライン](../02-impl/02-01-pipeline.md)）ので、バイトコードは 0.x の間の互換性の対象にしない。
- 同梱の Agent Skill は、同じ版の処理系だけを対象にする。
- 正式リリース版（`1.0.0`）で約束する範囲は、[OPEN-040](../open-issues.md#open-040) で決める。

## 未決事項

- [OPEN-009](../open-issues.md#open-009): 実行性能（musl のメモリ確保の影響）
- [OPEN-040](../open-issues.md#open-040): 正式リリース版とする条件と、互換性を壊す変更の範囲
- [OPEN-060](../open-issues.md#open-060): 配布と Agent Skill の導入に関する事実の確認
- [OPEN-061](../open-issues.md#open-061): リポジトリを公開する前の設計メモの扱い
