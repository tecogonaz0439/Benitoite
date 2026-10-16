# G5a のレビュー（2026-10-16、Opus 5.5 のサブエージェント）

対象: B6・B7・B8・B9・B10-1（`git diff fe98695b 890d6bce`、コミット c6453c7b〜3acc5491）。ファイルは変えず、cargo・lake・check.sh は走らせていない。【重大】なし。

## 確かめた点

- **die が本番で受理される経路**: 見つからなかった。`TryAction` は `ImplicitReturn` と `Return { span }` だけで、`try_action_ahead` は `or` の直後が `KwReturn` の場合だけ真になる。`try r or die` は E0201 のまま（parser/effects.rs の表で確かめている）。`exit_report` を `Some` にするのは、`cfg(test)` のテスト（ir/check.rs の `exit_report_tests`、refinterp/exit_report_tests.rs、vm/exit_report_tests.rs、bytecode のテスト）だけである。脱糖の `app` と decls.rs はすべて `None` を入れる。
- **全走査**: 終了の時点で `git grep 'Expr::Try|TryExpr'` を引いた結果は b6/try-sites.txt と一致した。値を辿る箇所（resolve・formatter/roles・runtime/assert・typeck/{consts,generate,effects/{mod,tail}}・desugar・exchange・shrink・examples の 2 本・parser の check_direct_lambdas）は、どれも `action` を網羅的に分解している。`CompKind::App`・`LCompKind::App` を分解する本番の箇所（ir/check・decision の lower_app・codegen の analysis/emit・refinterp の index の walk と eval・exchange）は、`exit_report` を辿るか、明示的に拒否する。`..` で読み飛ばすのは、decision.rs のテストの中の補助だけである。
- **IR・バイトコード**: `exit_report` を付けられるのは、標準の `Process.exit` に辞書なしで整数の定数 1 を一つ渡す呼び出しに限る。検査器・コード生成・liveness の `reg_use`・VM・参照インタプリタは、どれもこの条件を確かめる。表の長さは verify・liveness の Site・VM で確かめ、原因と説明のレジスタは IO の読み出しに加える。振り分けのループでは、verify を通さない入力についても実行時に確かめる（範囲・String・code・opcode・builtin・表の長さの不正をテストで拒否する）。
- **実行**: Direct では、言語のハンドラを通過して `serve_inner` に入った時点でだけ String を所有する。採用した `Exit` の code が 1 のときだけ `StopReason::Exit.die_failure` に移る。Request では、外の実行器へ渡す直前に処理系の不具合として拒否する。参照インタプリタは、ハンドラの探索の後、既定の実装へ進む時点でだけ所有する。handled・resumed・reentered・later・resumed later の各場合で、VM と参照インタプリタの結果が独立した期待値と一致することをテストで確かめる。golden の差分比較も `die_failure` を比べる。
- **報告**: CLI は `Exited(1)` のときだけ die を出し、順は die、次に reports である（R18）。test runner は、終了状態の行、die、解放の注記、捕らえた出力の順に出し、JSON には `die` を加える（R55）。説明の省略と空文字列、引用符、位置は、文章と JSON の両方で厳密に比べる。文言は `diag::codes::text`（DIE_*）と skill の `text`（KIND_DIE）にあり、Stop::Internal の説明は規約どおり表に載せていない。
- **テストが弱められていないか**: 既存のテストの変更は次の二種類だけで、assert の削除、期待の緩和、ignore の追加は見つからなかった。
  - `StopReason::Exit(n)` を `Exit { code: n, die_failure: None }` に置き換え、`die_failure` の確認を加えた。
  - typeck・desugar の既存の表を、裸と明示の両方で回すようにした。

  liveness の手書きの入力には、新しい表の `None` を補っただけである。
- **規約**: 本番のコードに unwrap・expect・panic・添字は増えていない。新しいコメントは日本語で、設計書の節を引いている（例外は下の指摘 5）。parse_try_action と report_try_continuation は `#[inline(never)]`・`#[cold]` で再帰の枠から外してある。
- **設計書との一致**: 01-01・01-02・01-09・02-03 の try の境界・改行・E0258/E0259 の記述は、parser のテストの表と一致する。02-10 の `"die"` の行、06-01・06-04・02-11 の die_failure の記述は、実装と一致する。

## 指摘

### 【中】

1. **B10-1 の後に古くなった「未接続」の記述が設計書に残っている**
   - 場所:
     - `docs/design/02-impl/02-06-ir-and-lowering.md:153`「参照インタプリタと VM は未接続の報告付き呼び出しを内部エラーで拒否する」
     - `docs/design/02-impl/02-07-bytecode.md:59`「現在は実行への接続前であり、報告付きの命令を VM で実行すると内部エラーになる」
     - `docs/design/07-quality/07-04-formal-semantics.md:205` の表の行「VM と参照インタプリタの実行には未接続である」
   - 問題: B10-1 で、Direct と参照インタプリタはこの情報を所有して実行するようになった（02-08「IO の命令」「参照インタプリタ」と 02-11 には反映済み）。上の三箇所は B9 の時点の記述のままで、02-08 と食い違う。設計書の規約（今の実装だけを書く）にも反する。
   - 修正案: 三箇所を「直接呼び出しの方式と参照インタプリタは、既定の終了へ進む呼び出しで報告を所有する（02-08）。要求と応答の方式は、報告付きの要求を外の実行器へ渡す前に処理系の不具合として拒否する。ソースからは報告付き App を生成しない」という趣旨に揃える。

2. **G5a の共通の関門 K のうち、check.sh と gc-stress の構成が未実行である**
   - 場所: b7〜b10-1 の各 results.md（「check.sh と gc-stress 構成は、今回の依頼に従ってオーケストレータへ残す」）。
   - 問題: 各作業は、lib・関係する統合テスト・clippy・check-formal を通している。しかし、計画の K に含まれる `check.sh` の選択の検査と gc-stress は、どの作業も走らせていない。B10-1 の完了条件は「G5a を完了する」である。
   - 修正案: G5a を閉じる前に、オーケストレータが `scripts/check.sh --dry-run` で選ばれる検査を確かめて実行し、gc-stress の構成とあわせて記録する。走らせる前の設計者への知らせ方は AGENTS.md「テストの運用」に従う。

### 【軽】

3. **振り分けのループの hot path に、Prim ごとの表の確認が加わった**
   - 場所: `crates/benitoite/src/vm/dispatch.rs:580` 付近（`Opcode::Prim | Opcode::Io` の先頭の `exit_reports.get(pc)`）。
   - 問題: 報告を持たない純粋な Prim の呼び出しにも、毎回、範囲の確かめと Option の判定が入る。正しさに問題はない。ただ、性能の影響は測っていない。
   - 修正案: 次の短い測定（benchmark スキル）で Prim の多いベンチマークを前後で比べ、差があれば記録する。範囲の確かめは規約上省けないので、構造は変えなくてよい。

4. **02-07 の見出しの階層が変わった**
   - 場所: `docs/design/02-impl/02-07-bytecode.md:61`。
   - 問題: 「原型の名前と由来の種類」が `####`（「コンパイル済みプログラム」の子）から `###` に上がった。「内部の終了報告」を `####` で挿入したときの取り違えと見られる。
   - 修正案: `####` に戻す。

5. **新しい型のコメントが引く節が、内容の節と違う**
   - 場所:
     - `crates/benitoite/src/bytecode/program.rs:147`（`ExitReportSite`。02-07「コンパイル済みプログラム」を引いている）
     - `crates/benitoite/src/ir/core_ir.rs:274`（`ExitReportArgs`。02-06「コア IR」を引いている）
   - 修正案: どちらも「内部の終了報告」（02-07 は 53 行、02-06 は 147 行）を引く。

6. **作業の記録の終了状態が誤っている**
   - 場所: b6/results.md の診断の表（E0258・E0259・E0440〜E0442 の行の「check の終了状態 1」「終了状態 1」）。
   - 問題: 06-01「終了状態」では、検査の誤りの終了状態は 2 である。実装とテストには影響しない。
   - 修正案: 2 に直す。

7. **`or return` の後に値を書いたときの診断が、先頭の字句によって E0259 になる**
   - 場所: `crates/benitoite/src/syntax/parser/effects.rs:463` の `parse_try_action` の字句の一覧。
   - 問題: `try r or return [x]` と `try r or return -1` は、二項演算と型適用の検査に回る。このため、help が「write `(try ... or return)` before applying another operator or call」の E0259 になり、処置に値を付けたという誤りの案内にならない。`try r or return die` は一般の E0201 になる。どちらも誤りとして拒否するので、受理の範囲の問題ではない。
   - 修正案（任意）: `[ ... ]` の型適用と区別しにくいので、今は変えなくてよい。B11 で die の help を加えるときに、`die` の字句で E0258 か die の案内を出すかを決め、parser の表に 1 行加える。

8. **test runner の文章で、die の前に「called `Process.exit` with status 1」が出る**
   - 場所: `crates/benitoite/src/cli/tools/test_runner/report.rs:119`、06-04 の追記。
   - 問題: R55 の決定どおりの実装である。ただ、`or die` を書いた利用者には、書いていない `Process.exit` の名前が先頭に出る。
   - 修正案: B11〜B13 で本物のソースの die を表示して確かめるときに、この行を残すか（終了状態の分類として残す）言い換えるかを判断し、06-04 に記録する。今は直さなくてよい。

## R52 の扱い

R52 の「作業ツリーには G4 の完了記録がない場合」は、B6 を始めた時点の作業の側から見た判断であり、事実としては reviews/G4-report.md の末尾の「対応」で G4 は閉じ、設計者も規則に合意した（2026-10-16）。直し方の提案: R52 の末尾に「追記: G4 は [G4 のレビュー](reviews/G4-report.md) の「対応」で閉じ、設計者が 2026-10-16 に規則に合意した。B6 の実装はその後の状態で進んだ。本項の前提（完了記録がない）は解消した」と一文を加え、b6/results.md の 114・116 行の「G4 の未確認の記録」の言及にも同じ参照を添える。R52 の本文は書き換えない。

## 確かめていないこと

- テスト・clippy・check-formal の実行（各 results.md の記録を前提とした）。
- bytecode/codegen/tests.rs の三つの内部入力のテストの細部と、formatter/verify の本体（変更なし。既存の字句による検証で処置を比べることは、テストの表から推測した）。
- newline.rs・lambda_bounds.rs は変更されていない。A4 の規則が `or return` の後にもそのまま働くことは、parser の正負の表（LF/CRLF・コメント・括弧内）で確かめられていると判断した。

## 対応

- 指摘1: 02-06・07-04 の実行への接続は G5b で反映済みである。Z6 で 02-07 の未接続の記述を直し、02-06 にも要求ごとの報告の保持と接続済みの交換出力を反映した。要求と応答の方式も G5b で接続済みのため、レビュー時の修正案にある暫定拒否には戻さない。本番 parser の die の拒否は維持している。
- 指摘2: `scripts/check.sh`（dry-run を含む）と gc-stress の構成の検査は、段末の B14 でオーケストレータが実行して記録する。Z6 では実行しない。
- 指摘3: M の段の前の短い測定で、オーケストレータが Prim の多い入力の性能への影響を比較して記録する。Z6 ではコードを変えない。
- 指摘4: 02-07 の「原型の名前と由来の種類」を `####` に戻した。
- 指摘5: `ExitReportSite` と `ExitReportArgs` のコメントの参照先を、それぞれ 02-07・02-06 の「内部の終了報告」へ直した。
- 指摘6: b6/results.md の E0258・E0259・E0440〜E0442 の検査の終了状態を 2 に直した。
- 指摘7: B11 の注意に `or return die` への die の help と parser の診断の表への一行追加を申し送った。
- 指摘8: R55 の補足を R70 に記録し、die のとき「called `Process.exit` with status 1」の行を省く実装・統合検査・06-04 への反映を B12 の注意に申し送った。
- R52: 本文を保ち、末尾に G4 の完了と設計者の合意の追記を加えた。b6/results.md の二箇所にも G4 の「対応」と R52 の追記の参照を添えた。

Z6 の検査（2026-10-16）: `cargo test -p benitoite --lib --test spec_examples --test skill_docs` は3スイート計1,206件成功・失敗0件（既存の ignored 21件、167.68秒）。`cargo clippy --all-targets`・`cargo fmt --check`・`git diff --check` も成功した。処理本体とテストは変更せず、`formal/` と docs/todo/ の変更・コミットは行っていない。
