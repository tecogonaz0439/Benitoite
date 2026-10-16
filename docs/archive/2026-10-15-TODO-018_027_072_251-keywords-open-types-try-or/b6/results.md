# B6 明示 return の AST・解析・全走査

## 目的と実装

開始時の HEAD は `fe98695b443d2176af265a633f7d83de0bb97ed9`、作業ツリーは clean だった。B6 と共通の関門 K、design.md の「文法と式の境界」「AST・フォーマッタ・名前解決」「型・エフェクト・書く位置」、R13 の回答 B・R14・R50 を確認した。今回の B6 の実装依頼に従って作業し、G4 の外部レビューや合意がこの作業で完了したとは扱わない。

`TryExpr.action` と `TryAction::ImplicitReturn` / `Return { span }` を加えた。処置の span は `or` から `return` までで、入力の value と独立して保持する。Pratt の経路と同じ深さの普通の return の値へ処置の停止条件を渡し、括弧・引数・ブロックは通常の式の範囲から読む。内側の try が自分の処置を先に取り、外側の try の処置は残す。`or` の後が return でなければ Boolean の演算子として読む。

処置は普通の parse_return を呼ばず値を取らない。A4 の一般の改行規則をそのまま使い、newline.rs と lambda_bounds.rs は変更していない。裸と明示形の型・エフェクト・脱糖は同じである。Die の場合と本番受理は追加していない。

フォーマッタは既存の字句による印字を使い、裸／明示、処置前後のコメント、短いラムダの物理行を保持する。verify は改行判定後の全字句・コメント列と再解析を検証するため、処置専用の別の字句表や印字を加える必要はない。

## 変更したファイル

| まとまり | ファイルと内容 |
|---|---|
| AST・解析 | `syntax/ast.rs`、`syntax/parser/{exprs,effects}.rs`。処置の情報、Pratt の停止条件、値なしの処置、E0258/E0259 |
| 全走査 | `resolve/walk.rs`、`runtime/assert.rs`、`typeck/{consts,generate}.rs`、`typeck/effects/{mod,tail}.rs`、`ir/desugar/effects.rs`、`cli/tools/formatter/roles/walk.rs`。二つの処置を網羅的に分けて入力を辿る |
| 開発用の走査 | `examples/named_arguments_inventory.rs`、`examples/named_inventory/index.rs`、`tests/random_programs/shrink.rs`、`tests/desugar_export/exchange.rs` |
| テスト | parser/effects、formatter/print、typeck/effects、ir/desugar の既存のテスト、`tests/{fmt_command,runtime_builtins}.rs` |
| 設計書 | 01-01・01-02・01-09・02-03。受理した文法、改行、意味、処置の位置と診断を反映 |
| 診断と生成物 | `diag/codes.rs`、`cli/tools/skill/generate.rs` の文法の境界・普通の return と処置の区別の説明、gen_skill で再生成した `skill/references/{grammar,diagnostics}.md` |
| 作業記録 | 本記録と全位置の照合一覧 |

表の処理系のパスは `crates/benitoite/src/` を基準とする。設計書 02-03 の実ファイル名は `02-03-frontend.md` である。

## test-audit の作成時の関門

1. 守る契約は、公開 parser の入力と処置の区別・次の文の境界・診断、公開 typecheck の戻り型の制約、公開 desugar の成功型と戻り型を区別した失敗の再構築、フォーマッタの保持、公開実行の成功・失敗と入力一回評価である。
2. 捕まえる退行は、Boolean or と処置の混同、パイプの入力の切断、次行の取り込み、値を要求する return への誤接続、戻り型・エラー型の制約の欠落、処置やコメントの整形時の消失、失敗後の処理の実行、入力の重複評価である。
3. 解析は parser の表を使い、型と脱糖は既存テストを裸／明示の両方で実行する。既存の assert はすべて残す。実行の境界では型・脱糖だけでは分からない入力の評価回数と失敗後の短絡を、Result/Option × 成功/失敗 × 裸/明示 × Direct/Request で確かめる。fmt の既存の表にはコメント・CRLF・短いラムダの行を追加する。golden の既存入力・期待値は変更しない。
4. テスト用の本番 API・フラグ・公開範囲の拡大はない。実行は既存の RunEnv と出力捕捉を使う。

最初に加えた文の境界のテストは、実装前には `or` の右辺の return を E0201 として拒否して失敗した。処置の解析を加えた後に成功した。最後の確認では、普通の return の値も同じ深さの式であることを確認し、そこにも処置の停止条件を引き継いだ。`try return r or return` の受理を解析の表へ追加した。

深い入れ子の既存の整形テストは、Pratt の再帰関数に置いた診断の一時値によってスタック超過した。診断の組み立てを cold・inline(never) の補助へ、処置の解析を非再帰の補助へ移して修正した。テストの深さ・スタックの設定・assert・ignore は変えていない。

## Try の全位置の照合

開始時の `git grep -n -E 'Expr::Try|TryExpr' -- crates/benitoite` と完了時の同じ検索を照合した。完了時の全位置は [try-sites.txt](try-sites.txt) に残す。

| 位置 | 分類と確認 |
|---|---|
| ast.rs の定義・Expr の id/span | action を追加。id/span の振り分けは終端の参照で、式の走査ではない |
| parser/effects.rs | 唯一の構築入口。処置なしは ImplicitReturn、明示形は Return。value と action を別に構築 |
| parser/exprs.rs | 明示形後の継続を拒否。短いラムダの直接入れ子の走査では action を分けて value を辿る。span_of は終端の参照 |
| parser/mod.rs・traits.rs のテスト | Try を対象にしない形の分類は既存の拒否のまま。既存の Try/Pipe の受理の assert は維持 |
| resolve/walk.rs、formatter/roles/walk.rs、runtime/assert.rs | action を分けて value を辿る。Return の span は式ではない |
| typeck/consts.rs | const の許可判定・型や値を扱う対象の分類は、両方とも Try 全体を拒否する既存のまま。参照収集の visit_expr は action を分けて value を辿る |
| typeck/generate.rs・effects/mod.rs | 各式の振り分けは既存のまま。到達性と制約生成は action を分けて value を辿る |
| typeck/infer.rs | Try 制約と既存の特殊解決を維持。処置の情報が型の意味を変えないため、TryInfo の Die 用の変更は B10a-1 に残す |
| typeck/effects/tail.rs | escape は両処置とも true。tail_expr は Try 全体を false とする既存の分類を維持 |
| typeck/{tests,effects/tests,traits/tests}.rs | Try を対象にしない式の分類と、既存の TryInfo の取得の検査を維持。戻り型・エラー型の正負は裸と明示へ拡張 |
| ir/desugar/{exprs,effects}.rs | 振り分けは同じ。action を分けて入力を一回評価し、既存の失敗の再構築と escape を使う |
| tests/desugar_export/exchange.rs | action を分けて入力を辿る。通常の corpus 9 の既存の tryResult/tryOption と同じ意味へ書き出す。処置を区別する corpus 10 のタグは R50 と B10a-3 の担当 |
| tests/random_programs/shrink.rs | action を分けて value の縮小候補を集める |
| examples/named_arguments_inventory.rs | 式の型の限定・主となる呼び出しの分類は既存のまま。再帰する収集は action を分けて value を辿る |
| examples/named_inventory/index.rs | action を分けて value 内の関数の契約と参照を収集 |

Die を追加する B10a-1 では、この表の走査へ message も接続する。特に現在 Try(_) として拒否・終端・非末尾とする分類を、式の訪問と取り違えない。

## 診断の対応

| 入力・契約 | 旧→新のコード・主文 | help | 主位置・副位置・終了状態 | 理由と既存検査の維持先 |
|---|---|---|---|---|
| `try r or return extra` | 未受理の新構文→E0258 ``invalid failure action after `try` `` | ``the `or return` action takes no value`` | extra の字句。副位置なし。check の終了状態 2 | 処置は値を取らない。parser の新しい表で help の全体と位置を厳密比較 |
| 明示形の後の演算子・呼び出し・型適用 | 未受理の新構文→E0259 ``parenthesize an explicit `try` expression before continuing it`` | ``write `(try ... or return)` before applying another operator or call`` | 続く演算子か開き字句。副位置なし。check の終了状態 2 | 明示形は括弧で囲んで続ける。外側の try の処置は parser の正の表に残す |
| 裸の try・通常の Boolean or | 変更なし | 変更なし | 変更なし | 既存の parser/typeck/golden の全 assert を維持 |
| 普通の return の値の欠落 | A4 の E0201 のまま | return_value_line のまま | 変更なし | 既存の parser と fmt の拒否を維持。処置にはこの help を付けない |
| 型の不一致 | E0440/E0441/E0442 のまま | 既存の修正案を維持 | try の式全体が主位置。明示形では処置まで含む。終了状態 2 | 既存の型の表を裸／明示に拡張 |

本番の Rust は追加 151 行・削除 25 行、テストとテストの補助は追加 307 行・削除 67 行、開発用の example は追加 6 行・削除 2 行である。src 内の cfg(test) 以下はテストへ含め、生成文書はこの集計から除いた。assert の数は parser/effects が 52→68、runtime_builtins が 37→42、他の変更した既存テストは不変である。既存の assert の移動・ループ化は、元の入力にも引き続き適用される。

新構文の導入前の偶発的な E0201 を旧仕様として固定せず、既存の有効入力と誤入力の期待値は変更していない。E0258/E0259 の案内は受理済みの return だけで、die を勧めない。診断の主文・help は gen_skill に反映した。

## 検査と結果

実行前に検査の内容と見込みの時間を報告した。最終の parser と Skill の説明を直したため、途中の形式化の実行を中断し、最終ツリーで再実行した。`scripts/check.sh`（dry-run を含む）と gc-stress の構成は依頼に従って実行しない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib syntax::` | 成功。109 passed、2.92 秒 |
| `cargo run -p benitoite --example gen_skill` | 成功。生成物を手で変更していない |
| `cargo test -p benitoite --lib` | 成功。1,164 passed、0 failed、既存の ignored 21、74.61 秒。typeck・desugar・formatter を含む |
| `cargo test -p benitoite --test fmt_command --test golden --test spec_examples --test skill_docs --test runtime_builtins` | 成功。40 passed、63.87 秒 |
| `cargo clippy --workspace --all-targets` | 成功。指摘なし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| `bash scripts/check-formal.sh` | 成功。終了状態 0。lake build（163 jobs、sorry の警告なし）、六入口、交換形式の自己検査と破損入力の拒否を含む |

Lean の定義と証明・形式化の対象範囲・六入口の入力件数と対象外理由の期待は変更していない。


### 六入口の照合

| 入口 | 結果 |
|---|---|
| desugarDiff | golden 968＋random 72,778＝73,746 定義が一致。不一致・定義の対象外・除外 0。プログラムは golden matched 349・既存の check error の excluded 386、random matched 1,000・excluded 0 |
| builtinCheck | 1,349 入力・72,468 比較。不一致・非収束 0 |
| coverageDiff | 閉じた型 10,020 件と外部 view 付き 10,028 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | match 16,417＋binding 6,036＝22,453 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,735 入力を単独入口で照合し、既存の拒否理由を含め固定 manifest と一致 |
| surfaceCheckAll | matched 51,645・outOfScope 19・q11 1。不一致・準備失敗・lazyRestriction 0 |

交換形式の自己検査は width 4・named 12・extensible 22・try 8 の全 46 件が成功した。Rust の coverage_export は 2 件、desugar_export は 17 件が成功した。Rust の書き出しは 564.96 秒、脱糖の比較は 28 秒、組み込み表は 18 秒、プログラム網羅性は 1 秒、表層の全件検査は 22 秒だった。

最終照合でも 1,735 入力・73,746 定義・22,453 網羅性入力の識別子・除外理由・scope・件数が一致した。幅付きの 3 入力・30 定義、外部 IOErrorKind の view と定数の所属も一致した。契約の破損 3 件、hole/pipe の破損 6 件、named export の破損 6 件を意図した理由で拒否し、corpus 9・型表 3・網羅性 3 の六入口の manifest が一致した。最後の照合は 208 秒だった。

ログは `target/b6-check-formal.log`、比較結果は `target/desugar-diff/run-41305/` と `target/coverage-diff/run-41305/` に残す。新しい axiom・sorry・admit・native_decide の追加はなく、Lean のソースと証明の変更はない。

## 計画との差と後の作業

R52 の推す案に従って、B6 の明示された実装依頼と G4 の未確認の記録を区別した（[G4 のレビュー](../reviews/G4-report.md)の「対応」で完了していたことを [R52 の追記](../decisions.md#r52-b6-の明示された実装依頼と-g4-の記録)に記録した）。文法・型・脱糖の範囲の変更はない。02-03 の実ファイル名へ合わせた。フォーマッタの印字・verify・newline は既存の仕組みで契約を満たすため、その本体を変えずに公開入口のテストで確認した。

B7 はより広いブロック・補間・内側のガードと短いラムダの診断の境界を完成する。Die の AST と説明の全走査・型制約は B10a-1、脱糖は B10a-2、処置を区別する corpus 10 の書き出しは B10a-3、本番受理は B11 に残す。G4 の所定レビューの回答・設計者の合意の記録はオーケストレータ側で確認する（[G4 のレビュー](../reviews/G4-report.md)の「対応」と [R52 の追記](../decisions.md#r52-b6-の明示された実装依頼と-g4-の記録)で完了を確認済み）。今回の自己確認をレビュー完了の記録へ置き換えない。

コミット、docs/todo/ の編集、段末の全体検査は行わない。
