# T30 fuzzing

- 依存する作業: [T24](T24-pipeline-cli.md), [T18](T18-core-check.md)
- 難易度: 2（1〜5。README の「難易度の目安」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/T30-fuzz

## 目的

任意の入力で、処理系の検査の段（字句解析から型検査まで）と、検査を通ったプログラムの脱糖とコード生成が、処理系の不具合を起こさないことを fuzzing（ファジング）で確かめる（07-03「fuzzing」）。道具には cargo-fuzz を使う。fuzzing は通常のテストの実行（`scripts/check.sh`）に含めず、短時間の実行と長時間の実行を別のスクリプトで行う。

## 読む設計書の節

- [処理系のテスト戦略](../../2026-09-27-design-initial/07-quality/07-03-compiler-testing.md): 「fuzzing」「実装の規約と静的な検査」の依存のライセンスの行
- [パイプライン](../../2026-09-27-design-initial/02-impl/02-01-pipeline.md): 「誤りが見つかったときの段の進め方」
- [ソース管理と位置情報](../../2026-09-27-design-initial/02-impl/02-02-source-and-spans.md): 「span」
- [ADR 0003](../../2026-09-27-design-initial/decisions/0003-license.md): 依存するクレートのライセンス
- [リポジトリとクレートの配置](../00-common/00-01-repository-layout.md): `fuzz/` をワークスペースに含めないこと
- [実装の規約](../00-common/00-02-conventions.md): 「依存するクレート」
- [パイプライン API と CLI](../10-interfaces/10-09-pipeline-api.md)
- [中間表現](../10-interfaces/10-06-ir.md): `check_program`

## 作るもの

- `fuzz/Cargo.toml`、`fuzz/fuzz_targets/check_bytes.rs`、`fuzz/fuzz_targets/check_mutated.rs`、`fuzz/fuzz_targets/compile_ok.rs`
- `fuzz/README.md`（道具の導入と実行の手順）
- `scripts/fuzz-short.sh`（各対象を 60 秒ずつ実行する）
- `scripts/fuzz-seed.sh`（`crates/benitoite/testdata/` の `.bnt` を `check_mutated` と `compile_ok` の種の入力の置き場所に写す）

## 手順の要点

- 【新しい決定】道具は cargo-fuzz とする（07-03 が候補に挙げたもの）。cargo-fuzz は nightly の Rust を必要とする（07-03 が引いた Rust Fuzz Book）。ほかの検査は `rust-toolchain.toml` の stable の版で行い、fuzzing だけ `cargo +nightly fuzz run <対象>` で nightly を使う。nightly の版は固定しない。
- `fuzz/` は `cargo fuzz init` の形のクレートとし、ワークスペースに含めない。ルートの `Cargo.toml` の `[workspace]` には、`exclude = ["fuzz"]` が T00 の時点で既にある（00-02）ので、ルートは変えない。
- 依存するクレートは `libfuzzer-sys` と、パスで指定した処理系のクレート `benitoite` だけとする。`libfuzzer-sys` の最新版 0.4.13 のライセンスは `(MIT OR Apache-2.0) AND NCSA` である（2026-09-27 に crates.io の API で確かめた）。NCSA は、同梱する LLVM の libFuzzer のライセンス（University of Illinois/NCSA Open Source License）であり、許容型のライセンスである。`fuzz/` は処理系の配布物に含めないテストの道具なので、このクレートに限って NCSA を認める。作業のときに版が上がっていてライセンスが変わっていれば、組み込まずに作業を止めて報告する（ADR 0003、00-02「依存するクレート」）。`deny.toml` はワークスペースの外の `fuzz/` を検査しないので、この確認は手で行い、完了の報告に版とライセンスを書く。
- 各対象が確かめる性質は、07-03「fuzzing」の三つである。

| 対象 | 入力 | 確かめること |
|---|---|---|
| `check_bytes` | 任意のバイト列 | `pipeline::check_text("fuzz.bnt", data)` が panic しない。すべての診断の主な位置と補助の位置の span について、ファイルがソースの表にあり、`start <= end <= 内容の長さ` である |
| `check_mutated` | 既存のテストのスクリプトを libFuzzer が変形したもの（種の入力は `scripts/fuzz-seed.sh` で写す） | `check_bytes` と同じ |
| `compile_ok` | `check_mutated` と同じ | 検査に誤りがなければ、`desugar_checked` が `Ok` を返し、`ir::check::check_program` が空の並びを返し、`compile` が `Ok` か `CompileError::Limit` を返す（`Internal` は不具合） |

- 性質が破れたときは `panic!` で知らせる（fuzzing の道具は panic を失敗として扱う）。`fuzz/` のクレートの `Cargo.toml` に、ワークスペースと同じ lint の表を書かない。fuzzing の対象のコードは `panic!` と添字を使ってよい（テストのコードと同じ扱い。00-02「`#[allow]` を書いてよい箇所」の表に `fuzz/` を加える必要はない。ワークスペースの外だからである）。
- 実行時の段（VM とランタイム）は fuzzing の対象にしない。07-03「fuzzing」が挙げた性質に含まれず、任意のプログラムは停止しないことがあるからである。
- `scripts/fuzz-short.sh` は、nightly の Rust と cargo-fuzz がなければ、導入の手順を示して終了状態 1 で終わる。長時間の実行の手順（時間を指定して `cargo +nightly fuzz run <対象> -- -max_total_time=<秒>`）は `fuzz/README.md` に書く。
- 見つかった不具合を直すのは本作業の範囲ではない。見つかった入力は、完了の報告に対象と入力の置き場所（`fuzz/artifacts/`）を書き、処理系の該当する作業の不具合として報告する。直した後の退行テストは、持ち主の境界（その段の単体テストかゴールデンテスト）に置く（07-03「退行テスト」）。

## 受け入れテスト

- `scripts/fuzz-short.sh` が、三つの対象をそれぞれ 60 秒実行する。
- `check_bytes` に、次の手で作った入力を与えて実行し、性質の検査が働くことを確かめる: 空の入力、正しくない UTF-8 だけの入力、1001 段の括弧の入れ子、閉じていない文字列リテラルで終わる入力。`cargo +nightly fuzz run check_bytes <入力のファイル>` で一件ずつ実行できる。
- `compile_ok` を、`testdata/runner/` の検査を通るスクリプトで実行すると、性質の検査を通る。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）。`fuzz/` はワークスペースの外なので、check.sh の結果に影響しないことも確かめる
- 受け入れテストのすべての場合を確かめるテストがある
- 完了の報告に、`libfuzzer-sys` の版とライセンス、`fuzz-short.sh` の実行の結果（見つかった不具合があればその一覧）を書く

## 難易度の理由

cargo-fuzz の定型の構成に、公開の API を呼ぶ三つの対象を書く作業である。判断が要るのは、ワークスペースから切り離す方法と、依存するクレートのライセンスの確認である。見つかった不具合を直すことは範囲に含めない。
