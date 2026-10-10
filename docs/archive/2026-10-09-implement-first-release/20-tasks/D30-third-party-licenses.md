# D30 第三者のライセンスの表示

- 依存する作業: [D00](D00-u4-interfaces.md), L14, L21, L22, L23, L24, L25, L30, L32
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/D30-licenses

## 目的

第三者のライセンスの表示 `THIRD_PARTY_LICENSES` を cargo-about で生成する手順と、実行ファイルへの埋め込み、`benitoite --licenses` を作る（05-01「ライセンスの表示」、06-01「コマンドラインの形」、ADR 0235、[README](../README.md) の「U3・U4 で決めたこと」の 16）。処理系自身のライセンス文 `LICENSE-MIT`・`LICENSE-APACHE` をリポジトリの根に置く。

依存に U3 のクレートを加える作業（L14 の `getrandom`、L21〜L25 の `serde_json`・`regex`・`csv-core`・`jiff`・`base64`・`sha2`、L30 の `httparse` と `mio` の `net`、L32 の `ureq`・`rustls` など）を挙げるのは、すべての依存がそろってから表示を作り、ライセンスの扱いを確かめるためである。

## 読む設計書の節

- [配布形態](../../2026-10-09-design-first-release/05-platform/05-01-distribution.md): 「配布物と置き場所（初回リリース版）」「ソースからのビルド」「ライセンスの表示」
- [CLI](../../2026-10-09-design-first-release/06-tooling/06-01-cli.md): 「コマンドラインの形」
- [ロードマップ](../../2026-10-09-design-first-release/00-overview/00-03-roadmap.md): 「利用する既存の OSS のライセンス」
- [ADR 0003](../../2026-10-09-design-first-release/decisions/0003-license.md)、[ADR 0138](../../2026-10-09-design-first-release/decisions/0138-crates-and-licenses-for-stdlib.md)、[ADR 0235](../../2026-10-09-design-first-release/decisions/0235-third-party-licenses-generated-and-shown-by-option.md)、[ADR 0242](../../2026-10-09-design-first-release/decisions/0242-copyright-notice-for-llm-generated-code.md)、[ADR 0334](../../2026-10-09-design-first-release/decisions/0334-third-party-license-authors-and-offline-generation.md)
- インターフェース: [10-19](../10-interfaces/10-19-skill-and-distribution.md) の「第三者のライセンスの表示」「リリースのスクリプト」、[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の「U4 のサブコマンドの入口」
- [リポジトリとクレートの配置](../00-common/00-01-repository-layout.md) の「機能（feature）」

## 起動の前にオーケストレータが済ませること

- cargo-about の導入: オーケストレータが開発機に 0.9.2 を導入する（`cargo install cargo-about --locked --version 0.9.2 --features cli`。ネットワークを使う。00-03「担当と起動の方法」）。
- `cargo fetch --locked` で依存のパッケージを取得しておく。本作業の生成はネットワークを使わない（ADR 0334 の決定 3）。
- D20 を先に取り込んでおく。本作業は、ライセンス文を置いた後に D20 の生成の道具を実行し直す（手順 6）。

## 作るもの

パスはリポジトリの根からの相対パスである。

| ファイル | 内容 |
|---|---|
| `LICENSE-MIT`・`LICENSE-APACHE` | 処理系のライセンス文（MIT と Apache License 2.0 の全文）。MIT の著作権表示は `Copyright (c) 2026 tecogonaz and Benitoite contributors`（05-01「ライセンスの表示」、ADR 0290） |
| `crates/benitoite/Cargo.toml` | 機能 `bundled-licenses` を加える（00-01「機能（feature）」）。`[package]` に `publish = false` を加える（下の `about.toml` で処理系自身を一覧から外すため） |
| `crates/benitoite/src/cli/tools/licenses.rs` | `third_party_licenses` の本体。機能 `bundled-licenses` のビルドで `include_str!("../../../licenses/THIRD_PARTY_LICENSES")` を返す |
| `crates/benitoite/src/cli/tools.rs` | `print_licenses` の本体（`text::OWN_LICENSE` の後に、埋め込んだ表示があれば `THIRD_PARTY_HEADER` と表示を、なければ `NOT_BUNDLED` を書く。終了状態 0） |
| `.gitignore` | `crates/benitoite/licenses/THIRD_PARTY_LICENSES` と `dist/` を加える |
| `scripts/release/about.toml` | cargo-about の設定。`accepted` は `deny.toml` の許可の一覧と同じものを同じ並び（`MIT` を先頭）で書く。cargo-about は `accepted` を優先の順に読み、二つのライセンスから選べるクレート（`MIT OR Apache-2.0` など）を、並びで先にあるライセンスで載せる。そのため、二重ライセンスのクレートは MIT として載る。`private = { ignore = true }` を書き、`publish = false` の処理系自身を一覧から外す |
| `scripts/release/about.hbs` | 平文の `THIRD_PARTY_LICENSES` の型板。ライセンスごとに、使うクレートの名前と版の並びと、ライセンス文を書く。ADR 0334 の `authors` を添える場所を持つ（手順 1） |
| `scripts/release/licenses.sh` | ビルド先を引数に取り、`about.toml` の `targets` をそのビルド先だけにした設定で `cargo about generate --locked --offline` を実行し、`authors` と NOTICE を加えて、指定したファイルに書く。ネットワークを使わない（ADR 0334 の決定 3）。`scripts/release.sh` の `licenses` の段（D31）が呼ぶ |
| `crates/benitoite/src/cli/tools/skill/bundle.rs` | 生成の道具を実行し直して、`LICENSE-MIT`・`LICENSE-APACHE` を Skill のファイルの一覧に加える（D20 の手順 6、本作業の手順 6） |

## 手順の要点

1. 10-19「第三者のライセンスの表示」の【要検証】の二点を、実際の依存で確かめる。
   - `cargo about generate` の出力で、クレートごとの著作権表示がライセンス文に残るかを、MIT のクレートと Apache-2.0 のクレートを一つずつ選んで、配布物のライセンスのファイルと比べる。
   - 依存のクレートの配布物の根に `NOTICE` の類のファイルがあるものを、`cargo metadata --format-version 1` のパッケージの `manifest_path` の親のディレクトリで探して一覧にする。`licenses.sh` は、見つけた NOTICE の内容を、クレートの名前と版を添えて出力の末尾に加える。
   - 事前点検（2026-10-08）で、今の依存には、配布物のライセンスの文に著作権の行がないクレート（itoa、once_cell、serde_core、serde_json、utf8-zero、zmij など）と、ライセンスのファイルがパッケージにないクレート（graviola、rustls-graviola）があることが分かっている。05-01「ライセンスの表示」と ADR 0334 の規則で補う。前者は、そのクレートの `Cargo.toml` の `authors`（`cargo metadata` のパッケージの `authors`）を著作者として添える。後者は、そのライセンスの SPDX の標準の文（cargo-about がライセンスの識別子から出す文）を載せ、`authors` を添える。上流のリポジトリの文を取る `clarify` は使わない。添えるのは cargo-about の型板か `licenses.sh` のどちらでもよい。`authors` が空のクレートがあれば、完了の報告に書く（作業は止めない）。
   - 今の依存には、配布物の根に NOTICE の類のファイルを持つクレートは一つもない（事前点検）。NOTICE を加える処理は、小さな偽のパッケージで確かめる。一時ディレクトリに、根に `NOTICE` を置いたパッケージと、それにパスで依存する小さなワークスペースを作り、そのワークスペースで NOTICE の処理を実行して、出力に NOTICE の内容とクレートの名前と版が入ることを見る（手で確かめ、完了の報告に書く）。
   - 確かめた結果（著作権表示が残る範囲、`authors` を添えたクレートの一覧、NOTICE を持つクレートの一覧、使った cargo-about の版）を、完了の報告に書く。
2. `cargo deny check licenses` が、U3 の依存を含めて通ることを確かめる（ライセンスの検査は `cargo deny` のまま）。
3. `licenses.sh` を三つのビルド先で実行し、出力の差（ビルド先で違う依存）を完了の報告に書く。
4. `bundled-licenses` のビルド（`licenses/THIRD_PARTY_LICENSES` を置いてから `cargo build --features bundled-licenses`）で `--licenses` が表示を含むことと、置かないビルドで `NOT_BUNDLED` を書くことを確かめる。機能のビルドは `scripts/check.sh` に入れない（ファイルがなければビルドできない）。
5. F18 が `--licenses` の `TOOL_UNAVAILABLE` を確かめたテストは、`NOT_BUNDLED` を確かめるテストに置き換える。F18 のテスト `usage_errors_and_unavailable_tools_have_two_lines_and_exit_two`（`src/cli/mod.rs`）は、`skill` と `--licenses` を一つのループ（`for name in ["skill", "--licenses"]`）で確かめており、D22 も同じ箇所から `skill` を外す。後に取り込む方が、先の変更に合わせて直し直す（ループが空になればループを消す）。`src/cli/tools.rs` の非公開の関数 `unavailable` が使われなくなったら、後に取り込む方が消す。`cli::text::TOOL_UNAVAILABLE` もほかで使われなくなれば消す。
6. D20 の生成の道具（`cargo run -p benitoite --example gen_skill`）を実行し直し、`LICENSE-MIT`・`LICENSE-APACHE` を Skill のファイルの一覧（`bundle.rs`）に加える。D20 の判定は、リポジトリの根に二つのファイルがあれば加えるものである。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| 開発のビルドの `--licenses` | `OWN_LICENSE` と `NOT_BUNDLED` を標準出力に書き、終了状態 0（`cli::execute` のテスト） |
| `bundled-licenses` のビルド | 埋め込んだ表示を含む（手で確かめ、完了の報告に書く） |
| `licenses.sh` | 三つのビルド先で、依存のクレートの名前・版・ライセンス文を含む平文のファイルができる。NOTICE を持つクレートがあれば、その内容を含む |
| `cargo deny check licenses` | 通る |
| Skill のライセンス文 | `skill::files()` に `LICENSE-MIT`・`LICENSE-APACHE` がある。`tests/skill_docs.rs` が通る |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- `print_licenses`・`third_party_licenses` に `todo!()` が残っていない
- 【要検証】の二点を確かめた結果を完了の報告に書いている

## 難易度の理由

道具の設定と型板を書き、出力を確かめる作業である。cargo-about が載せないもの（NOTICE、著作権表示）の補い方は ADR 0334 と 10-19 が定めているので、判断が要るのは、それを型板とスクリプトのどちらで書くかの細部である。
