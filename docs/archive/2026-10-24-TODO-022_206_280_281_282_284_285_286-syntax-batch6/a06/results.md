# A06 の結果

## 基準と変更

2026-10-25。作業ブランチは `mod012/A06`、B_WORK と開始時の HEAD はともに `6a6fd6ea78de81da6fbe04d225ac3728bb65a98a` である。開始時の追跡対象の差分はなかった。git の変更操作は行っていない。private/ と、それを指すスキルのリンクは読んでいない。

`interval/flow.rs` に、Integer64 の六比較と左右反転、if/else if/ifOnly の枝入口の絞り込みと正常値の合流を追加した。正常な偽と真の有無を整数区間と分け、条件に正常値がない場合と、比較の交差が Bottom の場合は枝の値を解析せず、候補も作らない。等値の偽枝にできる内部の穴は元の区間を保ち、端点だけの除去は区間を狭める。k±1 は i128 で求めて値域と交差する。枝内で狭めた束縛と新しい束縛は、正常終了・停止とも差分だけを復元する。if の後へ条件を残さず、別名の逆方向への伝播と算術式の逆算を行わない。

`BudgetAnalysis.branch` の scope は、正常な真偽の有無を調べる前に一枠確保する。`BudgetScan.branch` と同じく、対象の真偽に正常値がないときは条件を再分類しない。分類する場合は condition、comparison、左右の位置と定数、到達判定、到達する場合の再参照と更新の順を保つ。新しい分類走査の括弧と定数参照はループで下り、各訪問の枠を内側の処理が終わるまで保持する。候補は本体ごとの既存の列へ保存し、合流で複製しない。

比較の定数の認定を Lean の integerConstant と揃えるため、`interval/mod.rs` から既存の定数入力の共有表を flow へ借用で渡す。括弧・リテラル・負のリテラル・定数参照の連なりだけを認定し、計算結果が一点である任意の式を比較の定数にはしない。定数ごとの結果の箱や環境の複製は追加していない。設計書 02-05 に、比較と分岐、内部結果の真偽値を反映した。

## 検査

Cargo は先行作業と同じ `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。manifest・lock・検査設定は変更していない。一時的な Python 実行器がコマンドを `/usr/bin/time -l` と zsh で包み、生の出力の絶対パスを `<repo>`・`<home>`・`<tmp>` に伏せた。ログの `A06_COMMAND_EXIT_STATUS` は本体、`A06_OUTER_EXIT_STATUS` は計測も含む外側の終了状態である。

| コマンド・確認 | 本体の終了状態 | 外側の時間・記録 |
|---|---|---|
| `cargo test -p benitoite --lib typeck::interval::tests -- --nocapture`（接続直後の既存検査） | 0、11件成功 | 外側未計測。ビルド24.07秒・検査0.32秒。保存ログなし |
| 同じ局所検査（比較と予算停止の表を追加後） | 0、13件成功 | 13.028秒。[local-branches.log](local-branches.log) |
| 同じ局所検査（真偽値の合流・幅の境界などを表へ追加後、スタック修正前） | 0、13件成功 | 12.532秒。[local-final.log](local-final.log)。後続のスタック修正は最終 work で検査した |
| `cargo test -p benitoite --test call_allocations long_constant_chain_has_bounded_check_allocations -- --exact --nocapture` | 0、1件成功 | 25.413秒。455,816,427バイト。[allocation-chain.log](allocation-chain.log) |
| `cargo test -p benitoite --test call_allocations repeated_constant_diagnostics_share_bounded_origin_work -- --exact --nocapture` | 0、1件成功 | 5.023秒。267,690,706バイト。[allocation-repeated.log](allocation-repeated.log) |
| `cargo test -p benitoite --lib deep_expressions_stay_within_the_normal_stack -- --nocapture`（初回） | 101、SIGABRT | 5.283秒。[deep-stack.log](deep-stack.log) |
| 同じ深い式の検査（return・束縛の処理を分割後） | 101、SIGABRT | 9.875秒。[deep-stack-fixed.log](deep-stack-fixed.log) |
| 同じ深い式の検査（失敗する形を一時出力で同定） | 101、SIGABRT | 9.252秒。[deep-stack-probe.log](deep-stack-probe.log)。if 450段で失敗 |
| 同じ深い式の検査（結果を参照で受け渡す修正の途中） | 101、SIGABRT | 9.928秒。[deep-stack-fixed2.log](deep-stack-fixed2.log) |
| 同じ深い式の検査（末尾式の経路を分割後） | 0、1件成功 | 10.859秒。[deep-stack-fixed3.log](deep-stack-fixed3.log)。一時出力は検査後に除去 |
| `cargo fmt --all` | 0 | 編集後の整形。外側未計測 |
| 02-05 の相対リンク・アンカー・フェンス・末尾空白・禁止リンクの読み取り点検 | 0 | 1秒未満。相対リンクとアンカー104件 |
| `git diff --check`（読み取り） | 0 | 1秒未満 |
| `scripts/check.sh --level work --base 6a6fd6ea78de81da6fbe04d225ac3728bb65a98a --dry-run` | 0、七単位を選択 | 初回0.072秒、修正後0.078秒。[dry-run.log](dry-run.log)、[dry-run-fixed.log](dry-run-fixed.log) |

割り当て量の二件の上限・入力・期待値は変更していない。途中の実装の両件は A05 と同じバイト数で、後者の残量は744,750バイトだった。最終状態でも全統合を含む work の中で両件とも成功した。

作業末のコマンドは次のとおりである。`--test` を省き、全統合ターゲットを実行する。初回は lint で停止したため、修正で古くなった検査と未実施の後続単位を同じ指定で実行し直した。

```sh
env CARGO_HOME=<tmp>/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh -c \
  '"$@"; task_exit=$?; print -r -- "A06_COMMAND_EXIT_STATUS=$task_exit"; exit "$task_exit"' \
  a06 scripts/check.sh --level work --base 6a6fd6ea78de81da6fbe04d225ac3728bb65a98a
```

| 実行 | 結果・記録 | 外側の時間 real / user / sys | 最大常駐量（maximum resident set size） |
|---|---|---|---|
| 初回 | 本体1、外側1。fmt 成功後、clippy がワイルドカード1箇所と算術4箇所を拒否。[work.log](work.log) | 11.02 / 13.77 / 0.95秒（実行器11.027秒） | 取得不能。サンドボックスの sysctl 制限 |
| 修正後 | 七単位が全て成功。本体0、外側1。[work-fixed.log](work-fixed.log) | 422.90 / 1292.84 / 47.22秒（実行器422.906秒） | 取得不能。サンドボックスの同じ sysctl 制限 |

最終 work は、既定 lib **1,293件成功・失敗0件・既存の除外21件**、全40統合ターゲットの合計 **378件成功・失敗0件・既存の除外10件** だった。fmt、examples を含む clippy、ソース規約、Skill 生成物の一致、仕様集計も成功し、初回リリースの完了条件の未記入は0件だった。仕様集計の「参照のない仕様節」の一覧は、検査失敗と区別してログへ保存した。既存の深い式と割り当て量の二件も最終状態で成功した。作業末の work は初回と修正後の2回であり、最終 work の後に Rust・生成物・検査入力は変更していない。

最終の読み取り点検で、検査の件数、結果記録とログのリンク、絶対パスの伏せ、Markdown の末尾空白、`git diff --check` を確認した。

`time -l` はサンドボックスの `sysctl kern.clockrate: Operation not permitted` により最大常駐量（maximum resident set size）を取得できない。検査本体が成功しても、計測を含む外側の終了状態は1となるため、本体の終了状態と区別する。

### 失敗の原因と修正

新しく if の枝の中へ再帰する経路で、結果の値渡しのコピーと、文の連なりの処理用の作業領域が重なり、既存の if 450段の検査がスタックを超えた。return と束縛の分岐を `inline(never)` の補助関数へ分け、近似の合成は参照による更新へ変更した。枝の末尾式だけのブロックでは、文の連なり用の作業領域を通さず式を解析する。従来の容器と文の分類二回、作業枠の確保・返却と環境の復元は保った。失敗を同定する一時出力は除去し、既存テストのソースには最終差分を残していない。入力・深さ・スタックの大きさは変更していない。

clippy の初回の失敗は、Expr の未対応の構成子を列挙し、端点の ±1 を既存の算術と同じ i128 の saturating_add/sub へ揃えて修正した。入力は Integer64 の値域内なので、これらは数学上の加減算と一致する。lint の許可を追加していない。

### test-audit の作成時の関門

59行の比較の表は公開 typecheck の本物の収集・駆動を通し、両枝と左右反転、端点、等値偽枝の穴、凸な合流、未到達枝の候補抑制、if 後の事実の復元を、本体の区間と候補から確かめる。束縛と算術だけの既存の表では、これらの分岐の取り違えを観察できなかった。予算の一件は、既存の本物の型付き入力を用い、本体の操作数と保持項目数の上限をそれぞれ1〜350へ変えて、一時保持0、保存済み候補が解析順の接頭辞であること、完走時の同じ値と三候補を確かめる。停止位置と厳密な消費件数、辞書の保存形式を固定しない。テスト用の本番引数、手作りの型表、公開範囲の拡大はない。テストの削除はない。

本番 Rust は追加444行・削除62行、テスト Rust は追加168行・削除0行である。

## 計画からのずれと申し送り

- 定数の構文の認定を正確に行うため、指定の flow.rs・既存テストに加え、mod.rs の内部呼び出しへ既存の定数入力表の借用を追加した。environment.rs の辞書・差分の契約はそのまま使用した。既存の深い式の検査に対応するため、同じ flow.rs の return・束縛・末尾式の経路を分割した。型・エフェクトの規則、公開 typecheck の署名、実行時検査、Lean の定義・主定理・公理は変更していない。一時的な `#![allow(dead_code)]` は残した。
- A07: 本体ごとの候補列と値の成功/停止の区別は A05 の契約を保つ。整数の正常区間に加えて Approx.boolean は正常な偽・真の有無を持つ。未到達枝には候補を追加しないが、既存の定数警告は変更していない。W0401/W0402 の新候補の利用者向け診断と重複排除、由来の補助位置、一時的な dead_code の解除は A07 が担当する。
- A08/A09/A10: and/or/not の条件環境、match/guard、未知の形の独立した子と別本体は未接続である。新しい branch と局所の分類・比較の入口を使える。未対応の条件は既存の Unknown の正常な真偽を保ち、単一比較として認定しない。if 後への絞り込みは行わない。
- A11/X: 既存の括弧の値の解析の枠数、番号付けと値の解析の二走査、skipExpr の差は変更していない。未到達枝の番号は先行の番号付けで消費済みであり、値の走査では辿らない。環境の既存の辞書・差分の計上を含む全箇所と Lean の一対一の対応、任意予算での交換結果の一致は A11/X の担当である。今回の branch の scope、対象の正常な真偽による追加分類の有無、条件の分類と絞り込みの順序も、後続の比較で確認する。
- 割り当て量の余裕は小さい。後続担当も指定の二件を局所で再確認し、上限・入力・期待値を緩めない。
- 計画の割り当てどおり、未接続の補助実装の short は A07 の区切りへまとめる。独立レビューと受け入れ、性能比較は取りまとめが担当する。stage・change・release、Lean のビルド・全比較、heap/stress、勧告の再照合は本作業に割り当てられておらず、実行していない。

32ビット環境での実行・クロスビルドは未実施である。端点と k±1 は i128 とし、usize は環境の差分と文の位置の添字にだけ使う。

## 取りまとめのレビュー（2026-10-25）

六比較の絞り込み（不等値は端点だけを除く）、左右の反転、真偽の補の比較を、Lean の `Interval/Flow.lean` の `refineTrue`・`excludePoint`・`refineRange` と、`Interval/BudgetEnvironment.lean` の `comparisonOperands`・`atomic`（到達の判定の後に区間をもう一度読む順序）と照合し、一致を確かめた。受け入れる。
