あなたは Benitoite の改造 TODO-162（脱糖の形式化と性質 1 の証明）の段階 C3 の後半（C3b）を実装する実装担当である。Lean 4 と Rust を書く。

## 作業の場所

- 作業ディレクトリは `/Users/tecogonaz/src/Benitoite-C1`（ブランチ `impl/TODO-162-C1-surface`）である。このディレクトリの外のファイルを変えない。
- コミットしない（git の操作はオーケストレータが行う）。

## 経緯

前半の C3a（コミット 9987121）で、Lean の脱糖と Rust の脱糖の差分テスト（`scripts/check-formal.sh`）を作って走らせた。無作為な 1,000 プログラムはすべて一致し、ゴールデンテストの入力の不一致は 6 関数・16 か所で、すべて直接の負の Float リテラル（`-1.0` など）だった。Rust は型検査で符号込みのリテラルとして記録し、脱糖で定数を返す。Lean は整数の `-n` だけを定数にし、Float には一般の `neg` を使う。

まず次を読む。`docs/2026-10-09-TODO-162-desugar-formalization/c3-diff-results.md`、`formal/reviews/2026-10-10-surface-c3-diff/report-c3a.md`、`formal/Benitoite/Surface/` の全体、`formal/Benitoite/Exchange/`、`crates/benitoite/tests/desugar_export/exchange.rs`、Rust の `typeck/generate.rs` の `unary` と `ir/desugar/exprs.rs` の `unary`、01-12「名前とリテラル」と「演算子」の表。

## オーケストレータの決定

Lean を Rust に合わせる。単項の `-` を Float のリテラルに直接適用した式（括弧で囲んでいないもの）は、符号を反転した値の定数に移す（`return c`、c は −x）。理由: IEEE 754 の符号の反転は値を正確に定め（`-0.0` を含む）、`neg` を呼ぶ形と同じ値になるので言語の意味は変わらない。処理系の形に合わせると、差分テストの正規化を足さずに済む。01-12 の表の行（「単項の `-` を整数リテラルに直接適用した式 `-n`」）を Float にも広げる直しは、オーケストレータが行う。`Decimal` のリテラルは段階 C6 の範囲なので、今回は扱わない。

## この作業（C3b）で行うこと

1. 型の情報を付けた表層の構文に、直接の負の Float リテラルの要素を加える（C1 の `negInt` に倣う）。表層の型付け（型は `Float`、エフェクトは空）、範囲の条件、脱糖（定数）、`Exits`（必ず抜けない）を足す。
2. 性質 1 の証明に、足した場合を加える。二つの定理の言明は変えない。
3. `Examples.lean` に、足した行の脱糖の例（`rfl`）を加える。`-0.0` の例を含める（ビットで確かめられる形にする）。
4. 交換用の表現と Rust の書き出しを、直接の負の Float リテラルをこの要素として書き出すように直す（Rust の型検査が `lit_values` に符号込みで記録した直接の `-` のリテラルを使う）。整数の `-n` の扱いは変えない。
5. `scripts/check-formal.sh` を走らせ、ゴールデンテストの入力と無作為なプログラムのすべてが一致する（不一致 0）ことを確かめる。新しい不一致が出たら、C3a と同じく (a) Rust の脱糖の誤り、(b) Lean の定義の誤り、(c) 正規化の不足に分けて記録し、(b) と (c) は直す。(a) は処理系を直し、それを確かめるテストを加える（スキル `test-audit` に従う）。判断のつかないもの、言語の規則に関わるものは、直さずに報告して止まる。
6. `docs/2026-10-09-TODO-162-desugar-formalization/c3-diff-results.md` に、C3b の結果（直した内容と、最終の数と内訳）を書き足す。
7. 公理を確かめる（`formal/README.md` の手順。一時ファイルは `formal/` の中に作り、最後に消す）。

## 決まり

- `Benitoite.Release` の定義と証明を変えない。組み込みの関数の仮定を増やさない。二つの定理の言明を変えない。
- `docs/design/`・AGENTS.md・`formal/README.md`・`scripts/check.sh` は変えない。
- 実行環境はソケットの bind を許さないことがある。`scripts/check.sh` の Rust のテストが、HTTP のテストのソケットの bind だけで失敗するときは、その旨を報告すればよい（オーケストレータが別の環境で走らせる）。それ以外の失敗は直す。
- 完了の条件: `scripts/check-formal.sh` が成功する（不一致 0）。`formal/` の `lake build` が `sorry` なしで通る。二つの定理の公理が `propext`・`Classical.choice`・`Quot.sound` だけである。`cargo fmt --check` と、変えたテストのクレートの `cargo clippy --all-targets` が通る。

## 完了の報告

最後の応答を日本語で、次の見出しで書く。

1. 変えたファイル・作ったファイルと行数。
2. 足した要素と規則、Rust の書き出しの直し。
3. `scripts/check-formal.sh` の最終の出力（数と内訳）と時間。
4. 新しく見つかった不一致と、その分類と直し方（なければ「なし」）。
5. `#print axioms` の出力と、検査の結果（`lake build`、`cargo fmt --check`、`cargo clippy`、試せたなら `scripts/check.sh`）。
