# リポジトリとクレートの配置

本章は、処理系のソースコード・テスト・道具・測定記録をリポジトリのどこに置くかと、処理系のクレートのモジュールの構成を定める。設計書・実装プラン・ソースコードを一つのリポジトリに置くことは [ADR 0040](../../2026-09-27-design-initial/decisions/0040-single-repository.md) で決めた。07-02 と 07-03 が「最初の実装プランで決める」とした置き場所（測定記録、grammar-check の道具）も、本章で決める。

## リポジトリの配置

```text
Benitoite/
├── AGENTS.md                      エージェント向けの指示（ディレクトリ構成と実装の規約を含む）
├── Cargo.toml                     Cargo のワークスペースの定義と lint の水準（T00）
├── Cargo.lock
├── rust-toolchain.toml            Rust の版の固定（T00）
├── deny.toml                      cargo-deny の設定（T00）
├── .cargo/config.toml             警告を誤りにする設定（T00）
├── .claude/                       プロジェクトのスキル（skills/）とサブエージェントの定義（agents/）
├── .agents/skills/                スキルへのシンボリックリンク（Codex・OpenCode 向け）
├── crates/
│   └── benitoite/                 処理系のクレート（lib と bin）
│       ├── Cargo.toml
│       ├── src/                   処理系のソース（次節）
│       ├── tests/                 統合テスト（ゴールデンテストの実行器など。T25）
│       ├── testdata/              ゴールデンテストのスクリプトと期待値（T25〜T28）
│       └── examples/              開発用の例（逆アセンブルの結果を示す disasm、バイトコードの大きさを数える bytecode_stats）
├── tools/                         開発の道具（処理系の配布物に含めない）
│   ├── grammar-check/             言語仕様の例の検査（Python）
│   ├── spec-coverage/             仕様の網羅の集計（Python。T25）
│   └── bench/                     ベンチマーク（T31）
│       ├── programs/              本言語と比較対象の言語のスクリプト
│       ├── run.py                 測定の手順を行うスクリプト（Python）
│       ├── report_html.py         測定記録からグラフ付きの HTML を作るスクリプト
│       └── results/               測定記録（Markdown と HTML）とプロファイル
├── fuzz/                          cargo-fuzz のクレート（ワークスペースに含めない。T30）
├── scripts/                       検査と fuzzing のシェルスクリプト（check.sh、fuzz-seed.sh、fuzz-short.sh）
└── doc/
    ├── 2026-09-27-design-initial/ 設計書
    ├── 2026-09-27-implement-initial/ 本実装プラン
    └── reference/                 言語リファレンス（最小実行版の範囲は T32）
```

- 処理系のクレートは `crates/` の下に、開発の道具は `tools/` の下に置く（2026-09-27 に、Cargo のワークスペースの慣例に合わせて `src/benitoite/` と `src/tools/` から移した）。grammar-check は、v1 の構文解析器を実装したときに削除する（07-03「言語仕様の例の検査」）。
- 測定記録は `tools/bench/results/` に置く。07-02 の「設計書と別の測定記録」に当たる。測定の手順はスキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）にまとめた。
- `fuzz/` をワークスペースに含めないのは、cargo-fuzz が nightly の Rust を必要とし、ほかの検査を stable の Rust で行うためである（T30）。

## 処理系のクレートのモジュール

処理系は単一のクレート `benitoite` とし、ライブラリ（`src/lib.rs`）と実行ファイル（`src/main.rs`）を持つ。段ごとにクレートを分けないのは、段の間の境界を、クレートではなく本プランで凍結した型とシグネチャ（[10-interfaces](../10-interfaces/)）で守るからである。

| モジュール | 役割 | 設計書 | インターフェース |
|---|---|---|---|
| `base` | 専用の整数の型、span、ソースの表、ノード番号を鍵とする表 | 02-02 | [10-01](../10-interfaces/10-01-base.md) |
| `diag` | 診断の表現、診断コードの表、診断の書き出し | 02-10 | [10-02](../10-interfaces/10-02-diagnostics.md) |
| `syntax` | 字句、AST、字句の切り出し、改行の判定、構文解析 | 02-03 | [10-03](../10-interfaces/10-03-syntax.md) |
| `resolve` | 名前解決 | 02-04 | [10-04](../10-interfaces/10-04-resolve.md) |
| `types` | 型の表現、代数的データ型の表 | 02-05 | [10-05](../10-interfaces/10-05-types.md) |
| `typeck` | 型検査（推論、制約を解く部分、パターンの検査、宣言の検査） | 02-05 | [10-05](../10-interfaces/10-05-types.md) |
| `ir` | コア IR、下位 IR、脱糖、判定の木への変換、コア IR の検査器 | 02-06 | [10-06](../10-interfaces/10-06-ir.md) |
| `refinterp` | 参照インタプリタ（テスト専用） | 02-01, 01-12 | [10-06](../10-interfaces/10-06-ir.md) |
| `bytecode` | 命令の符号化、コンパイル済みプログラム、コード生成、逆アセンブラ | 02-07 | [10-07](../10-interfaces/10-07-bytecode.md) |
| `vm` | 仮想機械 | 02-08 | [10-08](../10-interfaces/10-08-runtime.md) |
| `runtime` | 実行時の値、ヒープ、IO のハンドラ、IO 実行器、panic 境界、報告、実行の流れ | 02-09 | [10-08](../10-interfaces/10-08-runtime.md) |
| `builtins` | 組み込みの関数と組み込みの表 | 02-04, 03-06 | [10-10](../10-interfaces/10-10-builtins.md) |
| `prelude` | prelude のソース | 02-04, 03-06 | [10-11](../10-interfaces/10-11-prelude-source.md) |
| `pipeline` | 段をつなぐ公開の関数 | 02-01, 02-11 | [10-09](../10-interfaces/10-09-pipeline-api.md) |
| `cli` | CLI | 06-01 | [10-09](../10-interfaces/10-09-pipeline-api.md) |

参照インタプリタとコア IR の検査器はテストだけで使うが、`#[cfg(test)]` にはしない。統合テスト（`tests/`）と fuzzing のクレートから呼ぶので、ライブラリの公開の関数にする。利用者が使う経路（`pipeline` と `cli`）からは呼ばない。

モジュールの中のファイルの分け方は、10-interfaces がファイルを指定したものはそれに従い、そのほかは各作業の文書に従う。作業の文書が指定しないときは、実装 LLM が決めてよい。
