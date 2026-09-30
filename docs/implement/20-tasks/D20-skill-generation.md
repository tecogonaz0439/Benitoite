# D20 同梱の Agent Skill の参照の文書の生成

- 依存する作業: [D00](D00-u4-interfaces.md), L00
- 難易度: 3（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行。生成物を除く）
- ブランチ: impl/D20-skill-generation

## 目的

同梱の Agent Skill の参照の文書のうち、生成できるもの（文法、標準ライブラリのリファレンス、診断コードの説明）を、処理系のクレートの関数で生成する（06-06「同梱の Agent Skill の構成」、ADR 0229・0288）。生成の道具（`examples/gen_skill.rs`）で生成物をリポジトリに置き、埋め込みの一覧（`bundle.rs`）を書き、生成物が古くないことを確かめるテスト（`tests/skill_docs.rs`）を置く。

L00 に依存するのは、U3 のすべての標準ライブラリのソースとドキュメントコメントがそろってから生成するためである。診断の表（F16 が確かめたもの）は D00 の依存に含まれる。

## 読む設計書の節

- [Agent Skills 対応](../../design/06-tooling/06-06-agent-skills.md): 「前提」「同梱の Agent Skill の構成」「言語の文書と日本語の訳」
- [配布形態](../../design/05-platform/05-01-distribution.md): 「ソースからのビルド」
- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md): 「標準のモジュールと非公式のモジュール（初回リリース版）」「標準ライブラリのソースの書き方」
- [構文](../../design/01-spec/01-02-syntax.md): 「初回リリース版の文法の全体」「ドキュメントコメント（初回リリース版）」
- [診断エンジン](../../design/02-impl/02-10-diagnostics.md): 「診断コード」
- [ADR 0229](../../design/decisions/0229-bundled-skill-contents-and-japanese-translations.md)、[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)、[ADR 0288](../../design/decisions/0288-skill-documents-generated-by-tool-and-committed.md)
- インターフェース: [10-19](../10-interfaces/10-19-skill-and-distribution.md) の「Skill のファイルの置き場所」「生成の道具と、生成物が古くないことのテスト」、[10-14](../10-interfaces/10-14-prelude-and-stdlib-sources.md) の `STDLIB`、[10-02](../10-interfaces/10-02-diagnostics.md) の `codes::ALL`・`CodeInfo`、[10-03](../10-interfaces/10-03-syntax.md) の AST とドキュメントコメント

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。

- `src/cli/tools/skill/generate.rs`: `generate_references`・`bundle_source` の本体。
- `src/cli/tools/skill/mod.rs`: `files` の本体（`bundle::FILES` を返す）。
- `src/cli/tools/skill/bundle.rs`: 生成の道具が書く。
- `examples/gen_skill.rs`: 生成の道具。
- `tests/skill_docs.rs`: 生成物が古くないことのテスト。
- `skill/references/grammar.md`・`diagnostics.md`・`stdlib/index.md`・`stdlib/<モジュール>.md`: 生成物。
- リポジトリの `AGENTS.md` の「ディレクトリ構成」の表: `crates/benitoite/skill/`（同梱の Agent Skill。生成物は生成の道具で作り直す）の行を加える。
- `skill/SKILL.md`・`skill/references/idioms.md`・`common-mistakes.md`・`language-comparison.md`: D21 が中身を書くまでの仮の文書（前付けと見出しと、D21 が書くことを示す一行）。`bundle.rs` の `include_str!` がファイルを要するので、ここで置く。`SKILL.md` の前付けは 10-19 の形（`metadata` の `benitoite-version` は型板 `{{benitoite-version}}`）にする。

## 手順の要点

1. 文法: 構文の章の Markdown から、見出し「初回リリース版の文法の全体」の節の最初のコードブロックを取り出し、`(* … *)` の注釈を除き（入れ子はない前提で、除いた後に空になった行も除く）、英語の短い説明の段落と一緒に `references/grammar.md` にする。見出しかコードブロックが見つからなければ `Err`。
2. 標準ライブラリのリファレンス: 10-19「Skill のファイルの置き場所」の二つ目の段落の規則で、`STDLIB` の項目ごとに一つのファイルを作る。各ファイルの先頭に `# Benitoite.<名前>` の見出し、状態と取り込みの名前の行（標準で prelude なら import が要らないこと、標準で prelude でなければ `import Benitoite.<名前>`、非公式なら `import Benitoite.Unofficial.<名前>` と、非公式のモジュールは標準に移すときに取り込みの名前が変わること）、モジュールの説明を置く。続けて `public` の宣言をソースの順に並べる。宣言の頭は、ソースのバイト列を AST の span で切り出して写す（`@builtin` の属性の行を除く）。本体は写さない。
3. `stdlib/index.md` は、モジュールごとに名前・状態・取り込みの名前・説明の最初の文を表にする。
4. 診断コードの説明: `codes::ALL` の順に、コード、報告の種類、文言の型板、説明を並べる。
5. 生成物の本文は英語で書く（06-06）。見出しと固定の文は `generate.rs` の中の定数か、そのモジュールの `text` に置く。
6. `bundle_source`: 手で書く文書・生成物・リポジトリの根の `LICENSE-MIT`・`LICENSE-APACHE`（D30 が置く。まだなければ、一覧から外すのではなく D30 を待つ。後述）を、`SkillFile { path, text: include_str!("…") }` の並びにした `pub const FILES: &[SkillFile]` のソースを作る。パスの並びは、`SKILL.md`、`references/` の辞書順、ライセンス文の順とする。
7. `gen_skill`: リポジトリの `docs/design/01-spec/01-02-syntax.md` を読み、`generate_references` の結果を `skill/references/` に書き、`skill/references/stdlib/` の生成しないファイルを消し、`bundle_source` の結果を `src/cli/tools/skill/bundle.rs` に書く。書いたファイルの一覧を標準出力に書く。
8. `tests/skill_docs.rs`: 同じ入力で生成したものとリポジトリのファイルを比べ、違えば `cargo run -p benitoite --example gen_skill` を実行するよう示して失敗させる。
9. ライセンス文: D30 がまだ取り込まれていなければ、`LICENSE-MIT`・`LICENSE-APACHE` を `bundle.rs` の一覧に入れられない（`include_str!` がファイルを要する）。そのときは、一覧に入れずに生成し、完了の報告に書く。D30 が、ライセンス文を置いた後に生成の道具を実行し直して一覧に加える（D30 の作業の文書）。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| 古くないことのテスト | 生成の直後に通る。標準ライブラリのソースの説明を 1 文字変えると失敗し、生成の道具の実行を示す。生成の道具を実行すると再び通る（手で確かめ、完了の報告に書く） |
| 文法 | `grammar.md` に日本語の注釈が残らない。文法の規則の数が構文の章のコードブロックと同じ |
| モジュールごとのファイル | `STDLIB` の項目の数と `stdlib/` のファイルの数（`index.md` を除く）が同じ。非公式のモジュール（`IO.Console` など）のファイルに `import Benitoite.Unofficial.IO.Console` がある。`Trait.md` に `import Benitoite.Trait`、`List.md` に import が要らないことがある |
| 宣言 | `@builtin` の属性と本体が写されていない。`public` でない補助の関数が含まれない |
| 診断コード | `codes::ALL` のすべてのコードがあり、廃止したコードがない |
| 埋め込み | `skill::files()` がすべてのファイルを持ち、`SKILL.md` の前付けに `benitoite-version` の型板がある |
| 構文の章の読み取りの失敗 | 見出しのない Markdown を与えると `Err` |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」。古くないことのテストを含む）
- 受け持つ関数に `todo!()` が残っていない
- 受け入れテストのすべての場合を確かめるテストか確認の記録がある

## 確認の観点

- 生成の関数がビルドのときに呼ばれていないか（`build.rs` を加えていないか。ADR 0288）
- 生成物が、構文の章・標準ライブラリのソース・診断の表だけから決まり、実行の日時や環境に依存しないか

## 難易度の理由

AST とソースの span から宣言の頭を写す処理と、Markdown の中の節を見つける処理が主である。生成物の形は 10-19 が定め、判断が要るのは宣言の頭の切り出し方の細部だけである。

## 後の作業への影響

本作業の後、構文の章（01-02 の文法の節）・標準ライブラリのソース・診断の表を変える作業は、生成の道具を実行して生成物の変更を同じ変更に含める（ADR 0288 の帰結）。`scripts/check.sh` の古くないことのテストが含め忘れを見つけ、失敗の文が道具の実行を示す。オーケストレータは、U3 の作業（L01 以降）の依頼の文面にこのことを書き添える。
