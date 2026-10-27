# A08 の結果

2026-10-25。基準 B_WORK・開始時の HEAD は `e61a5b09cf54aecac857b90aaf76580c4d224e7b`。指定された `mod012/A08` で実装と作業末の検査を完了した。private/ と、それを指すスキルのリンクは読んでいない。git の変更操作は行っていない。

## 実装と計画からのずれ

`and`・`or` の右辺へ、継続に必要な左辺の真偽の環境を渡す。`not` は正常な真偽と、条件分類で求める真偽を交換する。`and` の真と `or` の偽は左から順に絞り込み、反対の真偽は第一の環境、逆の真偽で左辺を絞ってから右辺を絞った第二の環境の順で求め、変数ごとの凸な区間へ合流する。候補は既存の本体ごとの列へ保存し、合流で複製しない。

二つの条件環境を同時に保持するため、指定の flow.rs・既存テストに加え、environment.rs・budget.rs と設計書 02-05 を変更した。環境は `BindingId`・値・接尾辞の番号を持つ列を一時領域に保存し、枝では先頭の番号だけを切り替える。絞り込みでは接頭辞だけを作り直し、枝入口の長さと先頭へ復元する。合流の元の位置を保つため、一般引数もソース順に整数 Top または未知の位置として登録する。別名への逆伝播は加えていない。

`Operation::JoinItem` は指定の履歴 `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` を確認して復元し、環境の合流で使用した。他の削除部品は戻しておらず、`#[allow(dead_code)]` も追加していない。言語の型・エフェクトの規則、通常の受理、実行時検査、Lean の定義・主定理・前提・結論・公理は変更していない。

## 検査

作業末の指定は次のとおりである。`--test` を省略し、全統合ターゲットを選択した。dry-run は初回・修正後とも終了0で、fmt、examples を含む clippy、全 lib、全統合、source_rules、skill_generated、spec_tally を確認した。

```sh
scripts/check.sh --level work --base e61a5b09cf54aecac857b90aaf76580c4d224e7b --dry-run
/usr/bin/time -l python3 <tmp>/a08-child.py scripts/check.sh --level work --base e61a5b09cf54aecac857b90aaf76580c4d224e7b
```

`a08-child.py` は指定の check.sh を一回実行して終了状態を表示・返却する計測用ラッパーである。外側の保存用ラッパーが生の出力の絶対パスを `<repo>`・`<home>`・`<tmp>` に伏せ、外側の経過時間も保存する。

| 検査・コマンド | 結果・外側の時間 | 記録 |
|---|---|---|
| 初回 `rtk cargo test -p benitoite --lib typeck::interval:: -- --nocapture` | 終了101。Checkpoint・Origins と新しいメソッドの公開範囲の不一致を修正した。初回の外側時間は未計測 | 下記の失敗の説明 |
| 修正後の同じ局所 lib 検査 | 19件成功、1293件除外。テスト0.40秒、外側時間は未計測 | ツールの出力で確認 |
| `cargo test -p benitoite --test declarations local_intervals_report_only_reached_arithmetic_failures -- --exact --nocapture` | 最初の追加分で1件成功、25件除外。外側22.277秒、テスト2.19秒 | [local-declarations.log](local-declarations.log) |
| 同じ公開境界の検査。未到達・環境の復元の対照を追加した後 | 1件成功、25件除外。外側7.526秒、テスト2.80秒 | [local-declarations-final.log](local-declarations-final.log) |
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture` | 2件成功、1件除外。外側11.455秒、テスト10.00秒 | [allocations.log](allocations.log) |
| 初回 dry-run | 終了0、外側0.079秒 | [work-dry-run.log](work-dry-run.log) |
| 初回 work | fmt 成功、clippy で終了1。外側11.194秒。time は11.19 real / 14.08 user / 0.91 sys | [work.log](work.log) |
| 修正後の同じ指定の dry-run | 終了0、外側0.084秒 | [work-recheck-dry-run.log](work-recheck-dry-run.log) |
| clippy 修正後の work | 全選択単位成功、check.sh 終了0。外側476.951秒。time は476.94 real / 1334.30 user / 54.22 sys。ただし実行中の自己点検で合流の由来を修正したため、最終状態の検査としては採用しない | [work-recheck.log](work-recheck.log) |
| 最終状態の dry-run | 終了0、外側0.083秒。選択は同じ | [work-final-dry-run.log](work-final-dry-run.log) |
| 最終状態の work | 全選択単位成功、check.sh 終了0。外側439.894秒。time は439.89 real / 1288.50 user / 54.74 sys | [work-final.log](work-final.log) |
| 全 lib（最終 work 内） | 成功1291件、失敗0件、ignored 21件。テスト75.19秒 | 同上 |
| 全40統合ターゲット（最終 work 内） | 成功380件、失敗0件、ignored 10件。割り当て量の二件・全宣言・CLI・仕様例・参照例・Skill の例・差分検査も含む | 同上 |
| fmt・examples を含む clippy・source_rules・生成 Skill の照合・仕様集計（最終 work 内） | 全て成功。生成物の追加差分なし | 同上 |

初回のコンパイルは、新しい補助型よりもメソッドが広く公開されていたため、private_interfaces の警告を拒否した。メソッドの公開範囲を実際の利用側である interval 内へ狭めて修正した。初回 work は、新しい enum の分岐の `_` が `clippy::wildcard_enum_match_arm` に違反した。否定と論理二項式を `if let` で判定する形へ直した。lint の許可や検査条件の緩和は行っていない。再検査中の自己点検では、合流で新しい由来を合成すると Lean の hull にない操作・保存が加わることを見つけ、合流自身は既存の由来への参照だけを使うよう修正した。この変更で古くなった fmt・clippy・全 lib・全統合を含む、同じ指定の work を最終状態で再実行し、全選択単位の成功を確認した。

作業末の全ての実行は `/usr/bin/time -l` で包んだ。`time: sysctl kern.clockrate: Operation not permitted` により、最大常駐量（maximum resident set size）は取得不能だった。成功した二回の work は `selected checks passed` と計測用ラッパーが表示する `timed command exit=0` を確認した。time と外側の保存用ラッパーの終了1を、検査本体の不合格として扱っていない。全ログの手元の絶対パスは伏せた。

割り当て量は次のとおりで、A07 の記録と同じ値だった。二件とも上限・入力・期待値を変更していない。

| テスト | 割り当て量 | 上限 |
|---|---:|---:|
| `long_constant_chain_has_bounded_check_allocations`（20,000定数） | 454,943,955バイト | 536,870,912バイト（512 MiB） |
| `repeated_constant_diagnostics_share_bounded_origin_work`（5,000定数・1,000診断） | 267,178,210バイト | 268,435,456バイト（256 MiB） |

## テストの作成時の関門と自己点検

テストは既存の三つの境界の表へ追加した。公開の検査入口では、短絡する右辺と到達する右辺、複合条件による除数0、否定、複数変数、凸な合流で精度を失う場合、別名への逆伝播がない場合、式の後へ環境が漏れない場合を対照した。単一比較だけの既存入力では、右辺の到達と二環境の合流の退行を捕まえられない。

本物の型検査の内部結果を読む既存の表には、合流後の具体区間と Top への退避を追加した。警告なしだけでは `[-2,3]` と Top の違いが分からないためである。任意の小予算での停止の既存検査には、元の入力・走査範囲を残した上で複合条件の入力を追加し、途中停止での一時保持の返却と保存済み候補の接頭辞を検査した。公開診断には現れない保持の不変条件を扱い、テスト専用の公開範囲・引数・差し込み口は追加していない。テストの削除や期待値の緩和は行っていない。

計上の自己点検では `BudgetEnvironment.lean` の condition・joinEnvs?・hull・readSlots・narrow と `BudgetAnalyze.lean` の shortCircuit・branch・not の経路を読んだ。第一の環境、逆の真偽の左辺、右辺、合流の順と、合流各項の操作・整数位置だけの左右の参照・空の末尾を含む枠・内側からの書き込みと保持を対応させた。合流自身は新しい由来の操作・保存を加えず、既存の由来を参照する。解析全体の任意予算での Rust/Lean 比較の成功を、この自己点検の結果としては主張しない。

## 申し送り

- A04・A05 のレビューから A11 へ回した括弧の枠数、番号付けと値の解析の二走査、skipExpr の計上順・回数の差は変更していない。A11 は更新した環境の参照・接頭辞の更新・合流も含め、入口・由来・全経路の計上と交換結果の一致を確認する。
- A09 は既存の branch と条件分類を使用できる。条件環境の先頭は同じ一時領域で共有し、外側の checkpoint へ戻すまで途中の環境を保持する。A10 の独立入力・別本体の解析・捕捉環境の構築は実装していない。
- 独立レビュー・段の検査・測定・受け入れは取りまとめが担当する。Lean のビルド・Rust/Lean の全比較、heap/stress、change/release、性能比較は A08 の割り当て外であり、実行していない。

本番側の Rust ファイルは追加307行・削除42行、テストの Rust ファイルは追加173行・削除7行である。A08 が受け持つ未実施・不合格の検査はない。独立レビューと受け入れは取りまとめへ引き渡す。

## 取りまとめのレビュー（2026-10-25）

and・or・not の短絡と真偽ごとの環境、未到達の右辺に候補を作らないこと、別名への逆伝播がないことを、公開の境界の表のテストで確かめた。取りまとめも実 CLI で、`bind z <- 0` の後の `if not (z = 0) then 10 div z` が警告を出さず、`if not (x <> 0) then 10 div x` が W0401 を出すことを確かめた（RV-A07 の軽3 の例2）。受け入れる。

環境は Lean の `BudgetScan.readSlots` と同じく、先頭から位置ごとに枠と読み取りを数える連結の形になった。束縛の多い本体では本体の予算に早く達するが、止まった本体は解析を止めるだけで診断と受理を変えない。既存の入力で上限に達しないことは U01 の棚卸しで確かめる。
