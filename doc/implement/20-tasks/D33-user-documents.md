# D33 利用者向けの文書

- 依存する作業: [D21](D21-skill-handwritten-docs.md), [D03](D03-fmt-command.md), [D11](D11-test-report-and-command.md), [D22](D22-skill-install.md)
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 大（1500 行超。文書が主）
- ブランチ: impl/D33-user-docs

## 目的

初回リリース版の利用者向けの文書を書く（06-06「言語の文書と日本語の訳」、05-01「導入の手順」「ソースからのビルド」「ライセンスの表示」「互換性の方針」、ADR 0229・0233・0236・0242）。英語の言語リファレンスを初回リリース版の範囲に書き直し、導入の手順、`CHANGELOG`、リポジトリの README を書き、Skill の内容と言語リファレンスの日本語の訳を `doc/ja/` に置く。

D21 に依存するのは、日本語の訳が Skill の手で書く文書を含むからである。L40（標準ライブラリのゴールデンテスト）は D21 の依存に含まれる。

## 読む設計書の節

- [Agent Skills 対応](../../design/06-tooling/06-06-agent-skills.md): 「言語の文書と日本語の訳」
- [配布形態](../../design/05-platform/05-01-distribution.md): 「配布物と置き場所」「導入の手順」「ソースからのビルド」「ライセンスの表示」「互換性の方針」
- [CLI](../../design/06-tooling/06-01-cli.md): 全体（開発用の設定は載せない）
- 言語仕様（`doc/design/01-spec/`）の全体と、[標準ライブラリ](../../design/03-interop/03-06-stdlib.md)・[IO のモジュール](../../design/03-interop/03-07-io-modules.md)・[テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)・[ネットワークのモジュール](../../design/03-interop/03-09-network.md)、[フォーマッタ](../../design/06-tooling/06-03-formatter.md)、[利用者プログラムのテスト](../../design/06-tooling/06-04-test-runner.md)
- [ADR 0229](../../design/decisions/0229-bundled-skill-contents-and-japanese-translations.md)、[ADR 0233](../../design/decisions/0233-distribution-via-github-releases.md)、[ADR 0236](../../design/decisions/0236-compatibility-during-0x.md)、[ADR 0242](../../design/decisions/0242-copyright-notice-for-llm-generated-code.md)、[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)
- 既存の `doc/reference/benitoite-minimal.md`（最小実行版の言語リファレンス）
- D32 の記録（Gatekeeper の対処）

## 作るもの

パスはリポジトリの根からの相対パスである。

| ファイル | 内容 |
|---|---|
| `doc/reference/benitoite.md` | 初回リリース版の英語の言語リファレンス。最小実行版の `benitoite-minimal.md` を下敷きに、初回リリース版の言語（モジュール、レコード、型クラス、エフェクトとハンドラ、`lazy`、`with`、`try`、文字列補間など）と、CLI（`run`・`check`・`test`・`fmt`・`skill`・`--licenses`）、標準のモジュールと非公式のモジュール（取り込みの名前）を書く。設計書の規範の繰り返しでなく、利用者が書くための説明と例にする。`benitoite-minimal.md` は消さず、先頭に初回リリース版の文書への案内を一行加える |
| `doc/reference/install.md` | 導入の手順（05-01「導入の手順」の 1〜3、Gatekeeper に止められたときの対処、ソースからのビルド `cargo install --locked --path crates/benitoite`、更新のときに `skill install` を実行し直すこと） |
| `CHANGELOG.md` | 初回リリース版（`0.1.0`。ADR 0090）の項。最小実行版からの互換性を壊す変更（構文の改め、診断の JSON の `helps` の形、`--version` の行など）と移行の手順（ADR 0236 の決定 3）。非公式のモジュールを標準に移すときは互換性を壊す変更であることの説明（ADR 0286） |
| `README.md` | リポジトリの説明、導入の手順への案内、ライセンス（`MIT OR Apache-2.0`）、著作権表示と、処理系のコードの大部分は LLM が生成したものであり設計者は設計と確認を行ったことの注記（05-01「ライセンスの表示」、ADR 0242） |
| `doc/ja/` | 日本語の訳: `doc/ja/reference/benitoite.md`・`install.md`、`doc/ja/skill/SKILL.md`・`doc/ja/skill/references/` の手で書く三つの文書。生成の文書（文法・標準ライブラリのリファレンス・診断コードの説明）は訳さない（設計書と日本語のソースのコメントが元である） |
| `AGENTS.md` | 「ディレクトリ構成」の表に `doc/ja/`（日本語の訳。英語の版を正とする）の行を加え、`doc/reference/` の行を初回リリース版の文書に合わせて改める |
| `crates/benitoite/tests/reference_examples.rs` | `doc/reference/benitoite.md` のコードの例を、D21 の `tests/skill_examples.rs` と同じ規則で検査する。共通の部分は、D21 のファイルを `#[path]` で共有するか、同じファイルに文書の一覧を加える形にしてよい |

## 手順の要点

1. 英語の文書は、診断の文言と同じく英語で書く（ADR 0229 の決定 6）。コードの例は、非公式のモジュールを取り込みの名前で書き、D21 の検査の規則（情報文字列 `benitoite` と `output`）に従う。
2. 開発用の環境変数（`BENITOITE_DEV_*`）は載せない（06-01「開発用の設定」）。
3. 日本語の訳の各ファイルの先頭に、訳であること、訳した元の英語の文書と版（コミット）、英語の版を正とすること、エージェントが使うためのものではないことを書く（06-06）。日本語の訳は、設計書と同じく常体で書き、`doc/design/00-overview/00-04-glossary.md` の用語に揃える。
4. README の著作権表示は、D30 が `LICENSE-MIT` に書いたものと同じ `Copyright (c) 2026 tecogonaz and Benitoite contributors` とする（05-01「ライセンスの表示」、ADR 0290）。
5. 法的な結論（どの部分が著作権で保護されるか）は書かない（05-01、ADR 0242）。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| 言語リファレンスの例 | `tests/reference_examples.rs` がすべての例を通す |
| 導入の手順 | 05-01 の 1〜3、Gatekeeper の対処、ソースからのビルド、更新の手順がある |
| `CHANGELOG.md` | 互換性を壊す変更ごとに移行の手順がある |
| README | ライセンス、著作権表示、LLM が生成したことの注記がある |
| 日本語の訳 | 訳の対象のすべての英語の文書に対応するファイルがあり、先頭の注記がある |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を満たしている

## 難易度の理由

文書を書く量は多いが、内容は設計書と Skill の文書にあり、判断は少ない。
