あなたは Benitoite の改造 TODO-162（脱糖の形式化と性質 1 の証明）の段階 C3 の前半（C3a: Lean の脱糖と Rust の脱糖の差分テストを作り、走らせて不一致を分類する）を実装する実装担当である。Rust と Lean 4 とシェルのスクリプトを書く。

## 作業の場所

- 作業ディレクトリは `/Users/tecogonaz/src/Benitoite-C1`（ブランチ `impl/TODO-162-C1-surface`）である。このディレクトリの外のファイルを変えない。
- コミットしない（git の操作はオーケストレータが行う）。

## 経緯

段階 C1・C2 で、`formal/Benitoite/Surface/` に、型の情報を付けた表層の構文・表層の型付け・脱糖（出力は `Benitoite.Release` のコア計算）を定め、性質 1 を証明した（C2 の証明の後の定義を読むこと）。性質 1 は Lean の脱糖についての定理なので、Rust の脱糖が Lean の脱糖と同じでなければ処理系について何も言わない。C3 では、同じ入力に対して二つの脱糖が同じコアの項を作ることを確かめる。C3a では道具を作って走らせ、不一致を分類する。直すのは正規化の不足だけで、Rust と Lean の定義の誤りは後半の C3b で直す。

## 読むもの

1. `docs/2026-10-09-TODO-162-desugar-formalization/` の `README.md`、`plan.md` の「C3 Rust の脱糖との差分テスト」、`decisions.md` の D7・D11、`study.md` の (d)。
2. `formal/reviews/` の `2026-10-10-surface-c1-definitions/` と `2026-10-10-surface-c2-definitions/` の `response.md`・`handling.md`（Lean と Rust の脱糖の既知の違い）。
3. `formal/Benitoite/Surface/`（`Syntax.lean`・`Desugar.lean`・`Examples.lean`）、`formal/Benitoite/Release/Syntax.lean`・`Subst.lean`、`formal/lakefile.toml`。
4. Rust: `crates/benitoite/src/pipeline.rs`（`check_text`・`check_path`・`desugar_checked`・`CheckedProgram`）、`typeck/mod.rs` の `TypeckOutput`、`resolve/mod.rs` の `ResolveOutput`・`Binding`、`base/mod.rs` の `NodeMap`・`BindingMap`、`builtins/table.rs` の `OPERATORS`・`EQUALITY`・`INEQUALITY`、`builtins/mod.rs` の `builtin_decl`、`types/mod.rs` の `AdtTable`・`CtorDef`、`ir/core_ir.rs`、`ir/desugar.rs`・`ir/desugar/`。テスト: `tests/golden.rs`（入力の集め方、`golden/differential.rs` の `#[path]` の前例）、`tests/random_programs.rs`・`tests/random_programs/generator.rs`。
5. `docs/design/02-impl/02-06-ir-and-lowering.md`、10-05 の型パラメータの番号（`docs/archive/2026-10-09-implement-first-release/` の中。`grep -rn "型パラメータの番号" docs/archive/2026-10-09-implement-first-release` で探す）、`docs/design/07-quality/07-03-compiler-testing.md`、スキル `test-audit`（`.claude/skills/test-audit/SKILL.md`）、AGENTS.md の「実装の規約」と「テストの運用」。

## 作業

0. 最初に、`formal/lakefile.toml` に `lean_exe` を足して小さな実行ファイルが作れて動くこと（`lake build <名前>` と実行）を確かめる。macOS で作れないなら、ほかの作業に進まず報告して止まる。
1. 交換用の表現（`formal/Benitoite/Exchange/`）: 型の情報を付けた表層の構文（定義ごと）とコアの項を JSON でやり取りする型。エフェクトの集合は有限の並びで表す。`ToJson`・`FromJson` を導出してよい。交換用の表現から Lean の `Surface` の構文へ写す関数と、Lean の脱糖の出力（`Release` の項）を交換用の表現へ戻す関数を作る。エフェクトは、入力に現れた原子の有限の集まりについて関数を調べて集合に戻す（脱糖はエフェクトを写すだけなので正確に戻せる）。比較は交換用の表現の上で行い、エフェクトは集合として比べる。浮動小数点数はビットの並び（u64）で受け渡しビットで比べる（Lean で `Float` とビットを相互に変換できる関数があるかを確かめる。なければ報告する）。
2. 名前の付け方を、両側で同じ規則にする。関数の名前（`FunName`）は Rust の定義の束縛の番号（`TopFn.def` の BindingId）から、構成子（`ConName`）は `(adt, tag)` から、組み込みの関数（`PrimName`）は `builtin_decl(id).name`（例: `%Integer.add`、`%eq`）から、エフェクトの名前は組み込みのエフェクトの名前と利用者のエフェクトの束縛から作る。構成子の名前は、値・構成子の呼び出し・パターンのすべてで同じ規則にする。
3. 演算子の表: Rust の書き出しは JSON の先頭に `OPERATORS`・`EQUALITY`・`INEQUALITY` から作った表を書き、Lean はそれと `Operator.typeArgs` で `opPrim` を作る（C1 のレビューの対応 9）。等値の項目の型のスキームがエフェクト変数を持たないこと（Lean の `[]` と一致すること）を確かめる。
4. Rust の書き出し: 統合テスト `crates/benitoite/tests/desugar_export.rs` に、`#[ignore = "formal: scripts/check-formal.sh が走らせる"]` を付けたテストを一つ置く。
   - 本番のコードに公開の API を足す必要はない見込みである（上の 4 の項目で届く）。足す必要が生じたら、足さずに報告する。`serde` の導出も本番のコードに加えない。
   - 入力は、ゴールデンテストの入力（`golden.rs` と同じ集め方。`mode=test` は `require_main: false`、ディレクトリのケースは利用者のすべてのモジュール）と、無作為に生成したプログラム。型検査の誤りになる入力は「除外（検査の誤り）」として数え、「対象外」と分ける。`tools/bench/programs` は入力に含めない。
   - 比べるのは、利用者のモジュールの、`DefOrigin::User` かつ `DefKind::Fn` の定義だけとする（標準ライブラリの定義、フィールドを取り出す関数は除く）。
   - 範囲の判定は Rust の側で、トップレベルの関数ごとに行う。定義ごとに `inScope(…)` か `outOfScope(要素の名前の並び)` を書く。範囲の外の要素は、AST の要素（文字列補間、レコード、`try`、`lazy`、`with`、ハンドラ、`resume`、ガード、選択肢、範囲・リスト・レコードのパターン、展開）、`Byte`・`Decimal` のリテラル、定数の参照、型クラスのメソッド、型クラスの制約を持つ関数（`class_constraints` が空でない）、利用者の操作、フィールドである。組み込みのエフェクトの操作（`Console.writeLine` など、`builtin_ops` を通って組み込みの関数になるもの）は、範囲に入れて組み込みの関数の名前として書く。型は、脱糖が型によらないので Release で表せるものは比べ、`Rigid`・`App`・高カインド型（`TypeArg::Head`）を含むものだけを対象外にする。
   - 整合の検査: 書き出しは、範囲内と判定した定義のコア IR に範囲の外の節（`Lazy`、`Handle`、`Use`、`Resume`、`Method`、空でない `dicts`、`ConstRef`、利用者の `Op`、範囲・リストのパターン、ガード）を見つけたら `unsupported(名前)` と書き、Lean は表層が範囲内なのにこれが出たら不一致として数える。
   - 出力先は環境変数で受け取り、指定がなければ `target/desugar-diff/` の下の一時の場所に書く（git が無視する場所）。どの入力も「書き出した」「対象外」「除外（検査の誤り）」のどれかに分類され、書き出しに処理系の不具合がないことを assert する（`--include-ignored` で走っても意味のある検査にするため）。
   - 1 回の時間を測り、10 秒を超えるなら報告に書く。
5. 無作為なプログラム: 既存の生成器（`tests/random_programs/generator.rs`）の今の設定は、範囲に収まるプログラムをほぼ作らない（観察に文字列補間、段の部分にガード・選択肢・範囲・リストのパターン、段 2 以降にレコード・`Lazy`・定数・展開を使う）。形式化用の設定を加える（`generate` の引数か別の関数で）。その設定では、段の部分を出さず、観察を `Console.writeLine(Integer.toString(x))` の形にし、展開・レコード・`Lazy`・定数を選ばない。固定の種で 1,000 件を出発点とする。既存の `random_programs` のテストの種の並びと出力が変わらないことを確かめる。一致・不一致・対象外を、プログラム単位とトップレベルの関数単位の両方で数える。
6. Lean の実行ファイル（`formal/DesugarDiff/Main.lean`、`lakefile.toml` の `lean_exe`）: JSON を読み、Lean の脱糖を適用し、交換用の表現に戻して Rust のコア IR と比べる。正規化は次のものとし、ほかに要ったものは加えて場所とともに報告する。
   - 変数: Rust の名前を、Lean の番号の規則（定義の引数は最後の引数が番号 0、`let` とパターンの変数は `Release` の `binds` の順）に写す。
   - `match`: Rust のコア IR の行（`MatchRow { pattern, arm }`）と分岐（`MatchArm { vars, guard: None, body }`）を、Lean の `(Pat × Comp)` の並びに揃える。行の数と分岐の数が等しく、行 i の `arm` が i であることを前提として検査し、外れたら不一致とする。`vars` の順を照合の順に揃えて番号に写す。構成子の識別を上の 2 の規則で揃え、負の整数のパターンを定数に揃える。決定木へ変換した後の形とは比べない。
   - 捨てる情報: `Val`・`Comp` の `ty`・`origin`、`Var.ty`、`BuiltinInfo`、ラムダの `BodyId`・引数の名前。ラムダの引数の型とエフェクトは比べる。
   - 定義の頭（型パラメータとエフェクト変数の数、引数の型、戻り値の型、エフェクト）も比べる。型パラメータとエフェクト変数の番号は、Rust の `Ty::Param(i)`・`EffVar(i)` と Lean の番号が恒等で対応する見込みである。10-05 で確かめる。
   - `let x ⇐ return V in N` の有無: まず正規化なしで比べ、要った箇所だけに限定して加え、場所を報告する（一律に展開すると、プレースホルダの穴の再束縛の違いなどを隠すため）。
   - 辞書と継続の分類、定数の定義（`ConstRef`）、`App.dicts`、`Method`、`ContVar` は C3 の範囲に現れないので、正規化を作らず、範囲の外の印として扱う。
7. 形式化の検査のスクリプト `scripts/check-formal.sh`: `formal/` の `lake build`（`sorry` の検査は `scripts/check.sh` の formal の検査と同じ）、`lake build <実行ファイル名>`、書き出しのテスト（`cargo test --test desugar_export -- --include-ignored`）、実行ファイルの順に走らせ、一致・不一致・対象外・除外の数と、対象外の要素ごとの内訳を、ゴールデンテストと無作為なプログラムに分けて示す。不一致があれば失敗で終わる。macOS の `/bin/bash` 3.2 で動くこと（連想配列を使わない、`set -u` で空の配列を展開しない、`timeout` コマンドを使わない）。
8. `scripts/check.sh` の `classify` に、`scripts/check-formal.sh` を formal の検査に分類する一行を加える（今は `scripts/` の下が分類されず、変えるたびに止まるため）。ほかの部分は変えない。
9. 差分テストを走らせ、不一致を、(a) Rust の脱糖の誤り、(b) Lean の定義の誤り（01-12 の規則の読み違いを含む）、(c) 正規化の不足、に分けて記録する。記録は `docs/2026-10-09-TODO-162-desugar-formalization/c3-diff-results.md` に書く（入力の名前、不一致の箇所の最小の形、分類、直し方の案）。この作業で直すのは (c) だけとする。(a)・(b) と判断のつかないものは直さず記録する。

## 決まり

- `Benitoite.Release` と `Benitoite.Surface` の定義と定理を変えない（(b) は記録だけ）。交換用の表現から Surface へ写す関数は、Surface の定義を変えずに書く。
- `docs/design/`・AGENTS.md・`formal/README.md` は変えない（オーケストレータが反映する）。01-12 の写しの直しが要るものは、案を記録に書く。
- 実装の規約（AGENTS.md）に従う。テストのコードでは `unwrap` などが許される（「`#[allow]` を書いてよい箇所」の表）。新しい `#[ignore]` の理由の印（`formal:`）は、オーケストレータが 07-03 に反映する。
- 完了の条件: `scripts/check-formal.sh` が最後まで走り、数と内訳を示すこと（不一致が残っていてよい。そのときは失敗で終わる）。不一致はすべて (a)・(b)・(c) に分類して記録してあること。`scripts/check.sh --base HEAD --only rust,formal` が通ること。`formal/` の `lake build` が `sorry` なしで通ること。

## 完了の報告

最後の応答を日本語で、次の見出しで書く。

1. 変えたファイル・作ったファイルと行数（Rust・Lean・スクリプトに分けて）。
2. 交換用の表現の形と名前の付け方。本番のコードに足した公開の API（なければ「なし」）。
3. 正規化の一覧（依頼のものと、加えたもの。場所とともに）。
4. `scripts/check-formal.sh` の出力（数と内訳）と、各段の時間。書き出しのテストの 1 回の時間。
5. 不一致の一覧と分類（`c3-diff-results.md` の要約）。直した (c) の内容。
6. `scripts/check.sh --base HEAD --only rust,formal` の結果。
7. C3b（(a)・(b) の直し）の見込みと、後の段階（C4 以降）で差分テストの範囲を広げるときの注意。
