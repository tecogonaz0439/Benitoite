# 実装プラン

本書は実装プランである。`decisions.md` の問いは、2026-10-11 にすべて推奨どおりに決まった（Q4 の予算は 64 MiB）。根拠と行番号は `study.md`。

## 進め方

1. 作業ごとに、オーケストレータ（Claude Code）が依頼文を書き、Claude のサブエージェントで事前点検してから、Codex の GPT-6.1-Sol（high）を新しいセッションで起動する。作業は git worktree で行う。docs/todo は worktree に現れないので、依頼文に要る内容（本ディレクトリの文書で足りる）を示す。
2. 作業を終えたら、Opus 5.5（medium）が差分をレビューする。記録は本ディレクトリの `reviews/<日付>-<作業>/` に置く。指摘を直してから `san_benito` に取り込む。
3. テストを書く・変えるときは、スキル `test-audit` に従う（作成時の関門）。新しいテストには、該当する仕様の節の印（`// spec: 01-05 選ばれない分岐の検査` など）を付ける。
4. 検査を走らせる前に、`scripts/check.sh --dry-run` で選ばれる検査を確かめ、設計者に知らせる。`scripts/check-formal.sh` は約 9 分かかる（フェーズ 3 の記録で 536 秒）。長いテストや `check-heap.sh` を含むときは、走らせる前に見込みの時間を報告する。`check.sh` が止まったら（終了状態 3）、設計者に尋ねる。
5. 設計書・`formal/README.md`・CHANGELOG.md・リファレンスへの反映は、作業ごとにオーケストレータが行う（T9）。処理系の作業の依頼文には、設計書を変えないことを書く。
6. ビルドを伴う Codex の作業は 3 つまで並べる。

## 作業の一覧

| 作業 | 内容 | 依存 | 見積もり（推測） |
|---|---|---|---|
| T1 | TODO-190 ガードの中の `resume`、E0509 の拡張、生成器と差分テストの TODO-190 の印を外す | なし | 250〜350 行 |
| T2 | プレースホルダの引数の `return`・`try`・`resume`（型検査と脱糖）、差分テストの印と分類を外す | T1 | 250〜400 行 |
| T3 | 網羅性の (a)(b)(c)、既存テストと生成器の直し、網羅性の差分テストの knownQ3 を外す | T1 | 250〜350 行 |
| T4 | 網羅性の (d)(e) の回帰のテスト | なし | 60〜120 行 |
| T5 | E0439 の重複と辿る範囲 | なし | 100〜150 行 |
| T6 | 誤りのある型の別名、孤立した実装の E0702、型クラスの (a)(d) | なし | 150〜250 行 |
| T7 | 定数の評価器の上限と予算 | なし | 100〜200 行 |
| T8 | 振る舞いを変えない整理と原型の共有の鍵 | T2・T5・T6 | 150〜300 行 |
| T9 | 設計書・`formal/README.md`・CHANGELOG.md・リファレンスへの反映（オーケストレータ） | 各作業 | — |
| T10 | 閉じる作業（docs/todo、保管） | すべて | — |

## 順序と並べられるもの

- 最初に T1 を行う。T1・T2・T3 は、どれも形式化の生成器（`tests/random_programs/generator.rs` の `formal_patterns` と `generate_formal`）と差分テストの道具（`tests/desugar_export/exchange.rs`、`formal/DesugarDiff`・`SurfaceCheck`・`CoverageDiff`・`CoverageProgramDiff`）に触れる。T1 が既知の差を数える仕組みの多くを外すので、T2・T3 はその後に始める。
- T2 と T3 は並べてよい。生成器では、T2 は新しい関数を足し、T3 は `formal_patterns` の既存の関数を直すので、重なりは小さい。取り込みは T2 → T3 の順にし、T3 を取り込む前に T2 を取り込んだ `san_benito` へ載せ替えて `scripts/check-formal.sh` を走らせ直す。
- T4・T5・T6・T7 は、T1 と並べてよい（ビルドを伴う作業は 3 つまで）。T5 と T2 はどちらも `typeck/generate.rs` に触れるが、T5 は `reachability`・`reach_expr`、T2 は `call` を変えるので、後に取り込むほうが載せ替える。
- T8 は、同じファイルに触れる T2・T5・T6 を取り込んだ後に行う。
- 推奨の順: T1 ∥ T4 ∥ T5 → T2 ∥ T3 ∥ T6 → T7 → T8 → T9 の残り → T10。

## T1 ガードの中の `resume`（TODO-190）

目的: ガードの中に直接書いた、外側の節の継続への `resume` を E0509 にする。ガードの中の `handle` の節で自分の継続を再開する形は受け付け続ける。

変えるファイル:

- `src/syntax/parser/patterns_ext.rs`: ガードを読む間、`p.ctx.clause` が `ClauseContext::Direct` なら `Blocked` にする（読み終えたら戻す。今の `saved` の扱いに含まれる）。ガードの中であることを `check_resume` が見分けられるよう、文脈に印を持たせる（`EscapeContext::InGuard` を使えるか確かめる）。
- `src/syntax/parser/effects.rs`: `check_resume` で、ガードの中なら補助の型板 `guard` を付ける。単体テストの表（640〜685 行）に、ガードの中の `resume`（E0509）とガードの中の `handle` の節の `resume`（誤りなし）を加える。
- `src/typeck/pattern_ext.rs`: `guard` で `ctx.clauses` を空にして検査し、戻す（構文解析器を通った入力では起きないが、型検査の側も Lean の `hideConts` と同じ環境にする）。
- `src/typeck/effects/mod.rs`: `resume` の検査で節がないときの `debug_assert!(false)` を、E0509 を出して誤りの型を返す形にする（T2 も使う）。
- `src/diag/codes.rs`: E0509 に補助の型板 `guard`（例: 「`resume` cannot be used in a match guard; resume in the branch body instead」）を加え、説明の文にガードを含める。文言は依頼文で示す。
- `testdata/handlers/`: ガードの中の `resume` の受け入れテスト（`.bnt` と `.diag.json`）と、ガードの中の `handle` の節の `resume` の実行のゴールデンテスト（`.bnt`・`.stdout`・`.exit`・`.mode`）。`INDEX.md` があれば更新する。
- `tests/random_programs/generator.rs`: `formalPatternGuardResume` とその呼び出し、機能の名前 `guard-resume-known` を消す。`formalPatternGuardLocal` は残す。
- `tests/desugar_export/exchange.rs`: `guard_clause_depth` と印「ガードの中の resume（TODO-190）」、`known_differences` の欄と書き出しの `knownDifferences` を消す（ほかに印の種類がないことを確かめる）。
- `tests/desugar_export.rs`: `export_distinguishes_guard_continuation_scope` を、`test-audit` に従って消すか、`formalPatternGuardLocal` が対象内で一致することを確かめる形に直す。
- `formal/DesugarDiff/Main.lean`: 既知の差の分類（362〜364 行の印の検査、`knownMismatched`、399〜413 行、441 行の集計）を外し、どの不一致も失敗にする。交換形式から `knownDifferences` を消すなら、読み込みも合わせる。
- `formal/SurfaceCheck/Batch.lean`・`Validation.lean`: 分類「knownDifference」と印の一覧を外し、`#guard` を直す。
- `skill/references/`: `cargo run -p benitoite --example gen_skill` で作り直す。

完了の条件:

- `cargo test -p benitoite --lib syntax::parser::effects`、`cargo test --test golden`、`cargo test --test desugar_export`、`cargo test --test random_programs`、`cargo test --test skill_docs` が通る。
- 受け入れテストで、ガードの中の `resume` が E0509（補助 `guard`）になり、終了状態 2 である。ガードの中の `handle` の例が期待の出力を出す。
- `formal/` の `lake build` が `sorry` なしで通る。
- `scripts/check-formal.sh` が通り、脱糖の差分テストに既知の差の行が出ず、`surfaceCheckAll` の knownDifference の分類がなくなり、不一致 0 である。
- `scripts/check.sh`（変更に応じて選ばれる検査）が通る。

## T2 プレースホルダの引数の `return`・`try`・`resume`

目的: プレースホルダを含む呼び出しの、呼ばれる関数の式とプレースホルダでない引数を、展開後のラムダの本体と同じ環境（戻り値の型は展開後のラムダの型、外側の節の継続は隠す）で型検査し、脱糖も同じ環境で行う。

変えるファイル:

- `src/typeck/generate.rs` の `call`: プレースホルダを含むとき、展開後のラムダの戻り値の型 `ret` を、呼ばれる関数と引数の検査より前に作る。その間、`ctx.ret` を `Some(ret)`、`ctx.clauses` を空、`ctx.return_annotation` を `None` にし、終えたら戻す。プレースホルダを含まない呼び出しは今のまま。パイプの規則 1 で差し込む左辺（`insert`）は、プレースホルダを含む呼び出しと同時には現れないことを確かめる（規則 2 はラムダの外で左辺を評価する）。
- `src/ir/desugar/exprs.rs` の `placeholder`: ラムダの脱糖（499〜503 行）と同じく、`self.conts` を空にし、`self.return_ty` を展開後のラムダの戻り値の型にして、呼ばれる関数と引数を脱糖し、戻す。引数の中に外側の継続を指す `resume` が現れたら `InternalError` にする。
- `src/diag/codes.rs`: E0509 に補助の型板 `placeholder`（例: 「the arguments of a call with `_` placeholders are evaluated inside the function that the call creates」）を加え、説明の文に含める。
- `src/typeck/effects/mod.rs`: 節がないときの E0509 に、プレースホルダの引数の中かガードの中かで補助を選べるよう、隠した理由を `Body` に持たせる（T1 の形を拡げる）。
- テスト: `study.md` の 1 の三つの例（型の合わない `return`・`try` は型の誤り、`resume` は E0509）の受け入れテスト。型の合う `return`（`bind g <- add(return 5, _)` の後の `g(1)` が 5）と `try` の実行のゴールデンテスト。型検査の単体テストに、呼ばれる関数の式の中の `return` を加える。
- `tests/desugar_export/exchange.rs`: プレースホルダの引数の中の `try` の対象外の印（1062〜1063 行）と、外側の継続を指す `resume` の印（1110〜1115 行）を消す。プレースホルダの引数を書き出すとき、書き出しの戻り値の型を展開後のラムダの戻り値の型にする（1203〜1217 行）。`placeholder_argument`・`placeholder_clause_depth` が不要になれば消す。
- `formal/SurfaceCheck/Walk.lean`・`Batch.lean`・`Validation.lean`: `partialReturns` と分類「rustTypecheckerCandidate」を外す。
- `formal/Benitoite/Surface/CheckCounterexamples.lean`: 先頭のコメント（TODO-178 を指す）を、例が確かめる内容を述べる文に直す。例そのものは変えない（Lean の定義を変えないので、`lake build` は今のまま通るはずである）。
- `tests/random_programs/generator.rs` の `generate_formal`: 型の合う `return` と `try` をプレースホルダの引数に書いた関数を加え、機能の名前を加える（例: `function formalPlaceholderEscape(o: Option[Integer]) -> Integer` の中で `bind f <- add(return 1, _)`、`Option` を返す関数の部分適用の引数に `try o`）。
- `skill/references/`: 作り直す。

完了の条件:

- `cargo test -p benitoite --lib typeck`、`cargo test -p benitoite --lib ir::desugar`、`cargo test --test golden`、`cargo test --test desugar_export`、`cargo test --test random_programs`、`cargo test --test skill_docs` が通る。
- 三つの例が `check` で誤りになり、型の合う例が期待の値を出す。
- `scripts/check-formal.sh` が通る。脱糖の差分テストで、新しい関数が対象内で一致し、対象外の要素に「known:」で始まるものがない。`surfaceCheckAll` に rustTypecheckerCandidate の分類がなく、不一致 0 である。
- `scripts/check.sh` が通る。

## T3 網羅性の (a)(b)(c)

目的: 有用性の手順を Lean の定義（Q3・Q4）に揃え、`poison_pattern` をリストのパターンの子まで辿らせる。

変えるファイル:

- `src/typeck/patterns.rs`: `check_match` で、同じ分岐の前の選択肢を、ガードの有無によらず後の選択肢の判定の行に入れる（ガードの付いた分岐の選択肢は、後の分岐の判定には入れない）。`covering_alternatives` も同じ規則で前の行を集める（Lean の `Release/Coverage.lean:1302-1330` の行の集め方に揃える）。`usefulness` の不整合の箇所（365・402 行の `?`、問いがどの構成子にも特殊化できずに尽きる場合、202 行の `unwrap_or_default` が生む不一致）を「有用」に倒し、反例は Lean と同じく問いの形を保つ。
- `src/typeck/generate.rs` の `poison_pattern`: `Pattern::List` の前・後の要素と残りの変数を辿る。
- 単体テスト: `case 1, 1 if g ->` の 2 番目の `1` が E0608 であること、覆っている分岐の示し方（`q3/covered-by` と同じ形）、不整合の行列で「有用」と答えること。
- 受け入れテスト: `testdata/patterns/` に、ガードの付いた分岐の中の覆われる選択肢の E0608。
- 既存のテストの直し: `refinterp/tests.rs:287` を、重なるが覆われない選択肢（`[x, 0], [0, x]` など）に直し、ガードが偽のときに同じ分岐の残りを調べないことを確かめる意図を保つ。`typeck/pattern_ext.rs:527` を、覆われない形に直すか、誤りの例へ移す。
- `tests/random_programs/generator.rs` の `formal_patterns`: `formalPatternRecords`・`formalPatternLists` の `named`・`formalPatternNested` の 2 番目の選択肢を、1 番目に覆われない形に直す（選択肢ごとに変数の位置が入れ替わる形は残す）。
- `formal/CoverageDiff/Main.lean`・`formal/CoverageProgramDiff/Main.lean`: 分類「knownQ3」と、ガードの付いた分岐を分けて判定し直す処理、報告の q3 の欄を外す。
- `tests/coverage_export.rs`: 境界の入力の `q3/…` の四件を残し、名前の意味（既知の差の確かめ）を述べるコメントを直す。

完了の条件:

- `cargo test -p benitoite --lib typeck::patterns`、`cargo test -p benitoite --lib typeck::pattern_ext`、`cargo test -p benitoite --lib refinterp`、`cargo test --test golden`、`cargo test --test random_programs`、`cargo test --test coverage_export -- --include-ignored` が通る。
- `scripts/check-formal.sh` が通り、`coverageDiff` の 10,020 件と `coverageProgramDiff` の全件が一致し、不一致・燃料切れが 0 である。
- `scripts/check.sh` が通る。

## T4 網羅性の (d)(e) の回帰のテスト

目的: 深い入れ子と、パターンの節の多い `match` を、上限の直前で確かめる。

変えるファイル:

- `pipeline::check`（段のスレッド）を通す統合テストか、`pipeline.rs` の単体テストに、`study.md` の 7 (d) の八つの形を、受け付ける最大の深さ（上限 1000 から求める）で `check` が誤りなしに終えることと、一段深くすると E0208 になることを確かめるテストを加える。`typeck/pattern_ext.rs:715-758` の既定のスレッドのテストは今のまま残す。
- 同じ場所に、要素が上限の直前まであるリストのパターンと、真偽値のリストのパターンを並べた行列の `match` を検査するテストを加える（Q5 の (a)）。
- 10 秒を超えるなら `#[ignore = "long: ..."]` を付けるかを考える（見込みは 1 秒未満）。

完了の条件: 加えたテストが通る。`scripts/check.sh` が通る。

## T5 E0439 の重複と辿る範囲

目的: 必ず抜ける文の後の文の誤りをブロックごとに一度だけ報告し（Q3 の (a)）、`handle`・`try`・`resume`・`lazy` の子とガードの中のブロックも辿る。

変えるファイル:

- `src/typeck/generate.rs` の `reachability`: 必ず抜ける文を見つけた後、最初に続く文だけに E0439 を出す。`reach_expr`: `Try` の値、`Lazy` の本体、`Handle` の本体と節、`Resume` の値、`match` のガードを辿る。仮の本体と述べるコメントを今の説明に直す。
- 受け入れテスト: `handle` の本体、`handle` の節、`try` の引数の中の `match` の分岐で、`return` の後の文が E0439 になること。二つの文が続くとき E0439 が一つであること。

完了の条件: `cargo test -p benitoite --lib typeck`、`cargo test --test golden` が通る。`scripts/check.sh` が通る。型検査を通るプログラムの集まりは狭まるだけで、脱糖の出力は変えないので、`check-formal.sh` は T9 の最後にまとめて走らせる（無作為なプログラムが新しい E0439 に当たれば、そのとき生成器を直す）。

## T6 誤りのある型の別名、孤立した実装、型クラスの (a)(d)

目的: 派生の診断を出さない（02-05「誤りの報告と検査の継続」）。

変えるファイル:

- `src/typeck/decls.rs`: 本体に誤りのあった型の別名を記録し、その別名を展開した側を誤りとして扱う（`study.md` の 2）。
- `src/typeck/traits/impls.rs`: E0701 を出した実装を重なりの検査に加えない。対象の形が誤り（E0712）の実装を型クラスごとに記録し、構成子を持たない型についてのその型クラスの制約で E0705 を出さない（`solve.rs` か `traits/` の制約の解決の箇所）。
- E0711 の期待の型を、型クラスの宣言の型パラメータの名前で示す。
- `src/typeck/traits/tests.rs:478-483` の期待を `[E0701]` に直す。
- 受け入れテスト: 別名の例で E0410 だけ。標準ライブラリの型クラスの孤立した実装で、CLI が E0701 だけを示し終了状態 2 で終わる（`tests/cli_process.rs` か `testdata/traits/`）。E0712 の後に三回使っても E0712 だけ。E0711 の期待の型に `A`・`B` が出る。

完了の条件: `cargo test -p benitoite --lib typeck`、`cargo test --test golden`、`cargo test --test cli_process` が通る。`scripts/check.sh` が通る。

## T7 定数の評価器の上限

目的: 定数の評価で、一つの値の大きさを実行時と同じ上限で確かめ、評価全体で作る値の大きさの和を予算で限る（Q4 の (b)。予算は 64 MiB）。

変えるファイル:

- `src/typeck/consts.rs`: 文字列の連結・補間、リストのリテラルと展開、`Map.fromList`・`Set.fromList`、構成子の適用で、作る値の大きさを確かめてから作る。上限は `runtime::MAX_STRING_BYTES`・`MAX_LIST_LEN` を使う（型検査の段から runtime を参照してよいかを確かめ、だめなら共有のモジュールに上限を移す）。超えたら E0435 の条件の文で上限と大きさを示す。条件の文は `typeck::text` に置く。
- 本体の中の算術の警告にも同じ評価器を使うので、警告の評価で上限に当たったときは警告を出さずに評価をやめる（誤りにしない）。
- 受け入れテスト: 倍にする定数の連なりで、上限を超えた定数が E0435 になること（テストが大きなメモリを使わないよう、予算で止まる大きさを選ぶ）。予算を超えた後の定数を評価しないこと。

完了の条件: `cargo test -p benitoite --lib typeck::consts`、`cargo test --test golden` が通る。再現の例（25 行）で `check` の最大 RSS が予算の数倍に収まることを手で確かめ、レビューの記録に書く。`scripts/check.sh` が通る。

## T8 振る舞いを変えない整理と原型の共有の鍵

目的: Q6 の (a) の点をまとめて直す。

変えるファイル:

- `src/typeck/generate.rs`・`context.rs`・`solve.rs`: `expr_stmts` を、`=` の比較の文の位置と左辺の名前・右辺の位置の記録に替える。`else if` の連なりを参照で辿る（`reach_expr`・`always_expr`）。`lambda_returns`・`matches` の複製を減らせるかを確かめ、減らせなければ理由をコメントに書く。
- `src/typeck/solve.rs`・`traits/mod.rs`: `mode: u8` を enum にする。
- `op_text` を `typeck::text` に一つにまとめる。
- `src/typeck/traits/collect.rs`: 型クラスの束縛から宣言を引く表を一度作り、`check_parameters` で使う。
- `src/ir/desugar/decls.rs`: 操作の名前の前置きを `ModuleKind` で分ける。
- `src/bytecode/codegen/`: `builtin_protos` の鍵を `(BuiltinId, 型引数)` にする。コード生成の単体テストで、二つの型の `%eq` を値として使うコア IR から、型ごとに違う命令の原型ができることを確かめる。

完了の条件: `cargo test -p benitoite` のうち関係するモジュールと `cargo test --test golden` が通る。脱糖の出力を変えないことを `scripts/check-formal.sh` で確かめる。`scripts/check.sh` が通る。必要なら、型検査の時間を `tools/bench/` の短い測定で比べる（スキル `benchmark`。本測定はしない）。

## T9 設計書と文書への反映（オーケストレータ）

作業ごとに、取り込みと同じ時期に反映する。文章はスキル `japanese-tech-writing` に従い、用語は 00-04 に揃える。見出しを変えるときは `git grep` で参照を探す。

| 作業 | 反映先 |
|---|---|
| T1 | 01-02「エフェクトの宣言とハンドラ（初回リリース版）」の `resume` を書く位置、「パターンの拡張（初回リリース版）」のガード。01-05「パターンの拡張（初回リリース版）」のガードに書けないもの。01-06 の `resume` の規則と理由。01-12 464 行（差の段落を規則の写しに直す）。02-03「文脈の制限」。02-10「診断コード」の E05 の行。07-03 148・157 行。07-04 147 行の末尾。 |
| T2 | 01-02「部分適用のプレースホルダ」（プレースホルダでない引数の中の `return`・`try` は展開後のラムダから抜け、`resume` は書けない）。01-06 495 行。02-05 の式の表の呼び出しの行。02-10 の E05 の行（プレースホルダの引数は型検査が報告する）。07-03 148・157 行。 |
| T3 | 01-05「選ばれない分岐の検査」（規則を直し、237 行の差の段落を消し、例を加える）。02-05「本体の後の検査」の行列の作り方・差の箇条・不整合の文。07-03 157 行。07-04 144 行。`formal/README.md` 69 行。 |
| T4 | なし（テストだけ）。07-03 に深さのテストの記述があれば合わせる。 |
| T5 | 01-06「必ず抜ける文」（Q3 の決定に従い、報告はブロックごとに一つと書くなら 02-05 に書く）。 |
| T6 | 02-05「型クラスと実装」（孤立した実装を重なりの検査に加えない）、「誤りの報告と検査の継続」（誤りのある別名の展開）。 |
| T7 | 02-05「定数の検査と評価」（上限と予算、超えたときの扱い）。02-09「一つの操作で作る値の大きさの上限」から 02-05 への参照。 |
| T8 | なし。 |

あわせて行うこと:

- `cargo test --test spec_examples` を、01-spec の `text` のブロックを変えたときに走らせる。
- CHANGELOG.md に未リリースの節を作り、互換性を壊す変更と移行の方法を書く（Q8 の (a)）。
- `docs/reference/benitoite.md` の「11. Effect handlers」に、`resume` を書けない位置の一文を加える（Q9 の (a)）。`docs/ja/` の訳はリリースのときに直す。
- すべての作業を取り込んだ後に、`scripts/check-formal.sh` と `scripts/check.sh` を走らせる。全体の検査（`--full`）を走らせるかは設計者に尋ねる。

## T10 閉じる作業

- docs/todo の `README.md` の決まりに従い、TODO-178 と TODO-190 を閉じる。今回外した点（Q7 で外した脱糖の (b)）と、作業の途中で見つけた後の課題を、新しい項目として docs/todo に加え、docs/todo の中でコミットする。
- 本ディレクトリの `README.md` の状態と、実際の分け方・コミットの要点を書き足す。
- 本ディレクトリを `git mv` で `docs/archive/` へ移す。

## 実際の分け方

2026-10-11 に、次の作業に分けて進めた。T4 は T5 と同じ作業ディレクトリで続けて行い、T9 は作業ごとにオーケストレータが行った。T2・T3・T6 は並べて進め、T7・T8 はそれらを取り込んだ後に始めた。各作業は、事前点検（Opus）で依頼文を直してから Codex（GPT-6.1-Sol、high）が実装し、Opus のレビューの後に `check.sh` を通して取り込んだ。レビューの記録は `reviews/`。

| 作業 | コミット | 要点 |
|---|---|---|
| T5・T4 | c05b6ab | E0439 をブロックごとに一度だけ、続く最初の文で出し、`try`・`lazy`・`handle` の本体と節・`resume`・ガードの中も辿る。深い入れ子と長いリストのパターンの回帰テスト（深いパターンは約 26 秒で長いテスト）。`tests/vm_handlers.rs` の入力の到達しない文は、取り込みのときにオーケストレータが消した |
| T1 | 5817e31 | ガードの中の `resume` を構文解析器が E0509（補助 `guard`）にする。レビューの指摘で、ガードが `Blocked` にした場合だけ補助 `guard` を付ける（`ClauseContext::BlockedByGuard`）。型検査はガードの間に節を隠す。TODO-190 の既知の差を、生成器・交換形式（`knownDifferences` の欄）・DesugarDiff・SurfaceCheck から外した |
| T6 | b0f94d5 | 誤りのある別名を使う宣言と注釈を誤りにし、E0701 の実装を重なりの検査から外し（CLI が終了状態 3 の内部の誤りでなく E0701 を示す）、E0712 の後の E0705 を抑え、E0711 の期待の型を宣言の型パラメータの名前で示す。レビューの指摘で、誤りのある別名を対象に使った実装を表に入れない形と、独立した誤りが残る対照のテストを加えた |
| T2 | 610319a | プレースホルダの呼び出しの呼ばれる関数とプレースホルダでない引数を、作る関数の戻り値の型と節を隠した環境で型検査・脱糖する。`resume` は E0509（補助 `placeholder`）。レビューの指摘で、型の合わない `return` を値の位置で報告するよう、`Equal` の制約を引数の検査の前に加えた。既知の差の印と `rustTypecheckerCandidate` の分類を外し、生成器に型の合う `return`・`try` の関数を加えた |
| T3 | d37b2ca | 同じ分岐の前の選択肢をガードの有無によらず数え（Q3）、不整合を Lean の `usefulFuel` と同じ条件で「有用」に倒す（Q4）。`poison_pattern` がリストを辿る。既存のテストと生成器の覆われる選択肢を直し、網羅性の差分テストから knownQ3 を外した。理由のコメントは取り込みのときにオーケストレータが加えた |
| T7 | dad7787 | 定数の評価器で文字列とリストを作る前に実行時の上限で確かめ、評価の全体に 64 MiB の予算を設ける（再現の例の最大 RSS は約 2.52 GiB から約 64 MiB に下がった）。警告の評価は式ごとの予算。レビューの指摘で、W0403 の鍵の評価で予算を共有し、E0435 の説明と補助を予算に合わせた |
| T8 | 1454109 | 振る舞いを変えない整理（式文・`match`・束縛の複製を減らす、`else if` を参照で辿る、`Bound` の enum、演算子の綴りの表、型クラスの引数の種類の表、操作の名前の前置きを `ModuleKind` で）。`%eq`・`%ne` の値の原型を型引数で分けた。ゴールデンの期待は変わらなかった |
| T9 | 077b7f7、51efa8e、ca36832 | 01-02・01-05・01-06・01-12・02-03・02-05・02-10・07-03・07-04・`formal/README.md`・CHANGELOG.md の未リリースの節・リファレンスの「11. Effect handlers」 |

計画と違えた点:

- 脱糖の (b)（プレースホルダの引数の余分な `Let`）は Q7 のとおり含めず、docs/todo の新しい項目にした。
- `study.md` の 1 の「現れたら書き出しの `expect` で止まる」と 7 の件数 22,339 件は、起草の時点の記述である。外側の継続を指す `resume` が書き出しに現れても書き出しは止まらず、Lean の比較の不一致として見つかる。型検査を通ったプログラムの網羅性の件数は、T1 の前の時点でも 21,340 件だった（取り込み後は 22,341 件）。
- レビューで見つけた後の課題（ガードの中のプレースホルダの引数の `return` を構文解析器が E0218 で拒否すること、`try` の誤りの注記がどの関数を指すか分かりにくいこと）は、docs/todo に加えた。
