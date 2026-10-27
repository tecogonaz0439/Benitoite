# A04 の結果

状態: A04 の実装・局所検査と、指定された work の七単位を完了した。検査本体は終了0である。time -l による最大常駐量の取得はサンドボックスの制限で失敗した。独立レビューと受け入れは取りまとめが担当する。

## 基準と実装した範囲

- 作業日: 2026-10-25。ブランチは `mod012/A04`。
- B_WORK と開始時の HEAD は `e9f08f4c0e1fb4e30e0d5223d4cc94cfd46ffa7a`。開始時の差分はなかった。
- AGENTS.md、共通依頼文、plan.md の前提・内部契約・A04・work A04、D2/D8/D16、study 8.2、README の設計者の決定、preflight、A02 の申し送りと取りまとめのレビュー、A03 の申し送りを確認した。Lean は環境と束縛の定義・予算付きの局所走査を読んだ。
- private/ と、それを指すスキルは読んでいない。git の変更操作は行っていない。`interval/mod.rs` の一時的な `#![allow(dead_code)]` は残した。

`environment.rs` に、BindingId の辞書と変更前の項目の積み重ねを追加した。ブロックの入口では差分の位置だけを保存し、正常終了と停止の両方で変更分を戻す。新しい辞書項目と復元用の保存は別々に計上し、同じ束縛への一時的な更新では復元用の一項だけを追加する。全環境の複製や、別名への逆向きの伝播は行わない。

`flow.rs` に、リテラル・定数参照・局所参照・括弧・block・bind/shadow の走査を追加し、既存の analyze_body から同じ予算で呼ぶ。定数は評価済みの共有表を借り、数値の伝播のために本体を再評価しない。定数ごとの環境や局所結果の箱を作らない。ワイルドカードは位置を増やさず、構造のパターンは各変数を型に応じた Top とする。専用構築器の位置は通常値と区別する。辞書に事実のない引数・捕捉値の整数参照は、確定した型から Top として読む。

正常な継続と return を分け、通常の return のオペランドまでを読む。完走した局所結果は、正常な継続の区間・return のオペランドの区間・継続の有無・整数だけを表すかどうか・失敗可能性・未対応の印を持ち、本体の報告へ移す。関数間解析には使わない。Reference の内容、構築器の長さ、一般の呼び出し、構造の内部から具体的な整数の事実を作らない。文と括弧の連なりはループで辿る。設計書 02-05 に環境、Lean の位置との対応、入口と出力を反映した。

## 検査

Cargo は先行作業と同じ `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。manifest・lock・検査設定は変更していない。保存した生ログの絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。Python の一時実行器はパスの伏せと外側の時間の記録だけを行い、以下のコマンドを `/usr/bin/time -l` と zsh で包んだ。`A04_COMMAND_EXIT_STATUS` は検査本体の終了状態である。

| コマンド・確認 | 終了状態 | 外側の時間・記録 |
|---|---|---|
| 初回の `cargo test -p benitoite --lib typeck::interval::tests -- --nocapture` | 101、既存6件中5件成功 | 時間未計測。番号付けで上限を使い切った後に値の走査へ進めない状態を、既存の一件が Prepared と期待していた |
| 新規テスト追加後の同じ局所検査 | 101、8件中5件成功 | 11.13秒のビルド、検査0.28秒。新規入力の予約語の関数名・存在しない長さ API と、上記の停止の期待に失敗 |
| 同じ局所検査の入力修正中 | 本体101、外側1 | 9.641秒。[local-bindings.log](local-bindings.log)。String.length が存在しないことと、到達不能な文を既存の型検査が拒否することを確認 |
| 同じ局所検査の入力修正後 | 本体0、外側1、8件成功 | 9.196秒。[local-bindings-fixed.log](local-bindings-fixed.log) |
| 予算の途中停止のテスト追加後の同じ局所検査 | 本体0、外側1、9件成功 | 13.542秒（検査0.30秒）。[local-budget.log](local-budget.log) |
| `cargo test -p benitoite --test call_allocations long_constant_chain_has_bounded_check_allocations -- --exact --nocapture` | 本体0、外側1、1件成功 | 27.481秒（検査8.51秒）。455,816,427バイト、既存512 MiB未満。[allocation-chain.log](allocation-chain.log) |
| `cargo test -p benitoite --test call_allocations repeated_constant_diagnostics_share_bounded_origin_work -- --exact --nocapture` | 本体0、外側1、1件成功 | 1.428秒（検査1.33秒）。267,690,706バイト、既存256 MiB未満。[allocation-repeated.log](allocation-repeated.log) |
| `cargo test -p benitoite --lib deep_expressions_stay_within_the_normal_stack -- --nocapture` | 本体0、外側1、1件成功 | 5.674秒（検査0.57秒）。既存の入力とスタックを維持。[deep-stack.log](deep-stack.log) |
| `cargo fmt --all` | 0 | 編集後の整形。外側未計測 |
| 02-05 の相対リンク・アンカー・フェンス・末尾空白・禁止リンクの読み取り点検 | 0 | 1秒未満。相対リンクとアンカー102件 |
| `git diff --check`（読み取り） | 0 | 1秒未満 |
| `scripts/check.sh --level work --base e9f08f4c0e1fb4e30e0d5223d4cc94cfd46ffa7a --dry-run` | 本体0、外側1 | 初回・修正後とも0.079秒。[dry-run.log](dry-run.log)、[dry-run-fixed.log](dry-run-fixed.log) |

二つの割り当て検査の上限・入力・期待値は変更していない。余裕の小さい後者の残量は744,750バイトである。両検査は途中の実装で実行し、その後の列挙型の分岐の明示・Bottom の継続の扱いを含む最終状態を work で再検査し、両方とも成功した。

作業末のコマンドは次のとおりである。初回の失敗は本体の lint によるものであり、修正によって古くなった Rust の検査と、未実施の後続単位を同じ指定で実行し直した。

```sh
env CARGO_HOME=<tmp>/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh -c \
  '"$@"; task_exit=$?; print -r -- "A04_COMMAND_EXIT_STATUS=$task_exit"; exit "$task_exit"' \
  a04 scripts/check.sh --level work --base e9f08f4c0e1fb4e30e0d5223d4cc94cfd46ffa7a
```

| 実行 | 結果・保存ログ | 外側の時間 real / user / sys | 最大常駐量（maximum resident set size） |
|---|---|---|---|
| 初回 | 本体1、外側1。fmt 成功後、clippy が列挙型のワイルドカードの5箇所を拒否。[work.log](work.log) | 29.98 / 111.41 / 11.14秒（実行器29.987秒） | 取得不能。サンドボックスの `sysctl kern.clockrate: Operation not permitted` |
| 修正後 | 七単位が全て成功。本体0、外側1。[work-fixed.log](work-fixed.log) | 423.05 / 1292.39 / 47.82秒（実行器423.059秒） | 取得不能。サンドボックスの同じ sysctl 制限 |

最終 work は、既定 lib **1,289件成功・失敗0件・既存の除外21件**、全40統合ターゲットの合計 **378件成功・失敗0件・既存の除外10件** だった。fmt・examples を含む clippy・ソース規約・Skill 生成物の一致・仕様集計も成功し、初回リリースの完了条件の未記入は0件である。仕様集計の「参照のない仕様節」の一覧は、検査の失敗と区別してログに残した。作業末の work は初回と修正後の2回であり、最終 work の後に Rust・生成物・検査入力は変更していない。

`time -l` は全実行で最大常駐量を取得できず、計測側の外側の終了状態を1にした。上表の本体の成功・失敗は各ログの `A04_COMMAND_EXIT_STATUS` で判別した。

最終の読み取り点検で、work の件数、結果記録とログのリンク、パスの伏せ、Markdown の末尾空白、`git diff --check` を確認し、全て成功した。

### test-audit の作成時の関門と失敗の修正

新規の表の検査は、型検査の本物の入口から返る本体の区間を読み、bind/shadow・別名・ワイルドカード・block のスコープ・定数・引数 Top・両端と、構造のパターン・Reference・構築器からの過剰な推測を確かめる。番号付けだけの旧検査ではこれらの誤りを観察できなかった。予算の一件は、実際に型検査した入力を使い、操作数と保持項目数の上限をそれぞれ1〜100へ変えて、停止時の一時保持0と、完走時の同じ値を確かめる。停止位置や辞書の並びを固定せず、既存の入力の準備を使った。テスト用の本番引数、型表の手作り、公開範囲の拡大や新しい差し込み口はない。テストの削除はない。

既存の全体上限2の一件は、入力と上限を変えず、番号付けの次の走査を開始できない停止と、次本体の未着手を期待するように直した。出力の作成数、操作数、保存数の確認も維持した。新規入力では予約語の関数名を改名し、構築器の長さは実在する StringBuilder.byteLength を使った。return の後へ文を置く例は既存の型検査で E0439 になるため、受理済みの本体の検査から外した。clippy の5箇所は、未対応として扱う構成子も全て明示し、lint の許可を増やさずに直した。

本番 Rust は追加527行・削除4行、テスト Rust は追加165行・削除1行である。

## 計画からのずれと申し送り

- `environment.rs`・`flow.rs` の部品を既存の駆動へつなぐため、`interval/mod.rs` に局所結果を追加した。通常の return はオペランドまでを解析して正常な継続を止め、束縛値の参照を型検査の出力から確かめられるようにした。型・エフェクトの規則、公開の型検査の署名、既存の診断、Lean の定義・主定理・公理は変更していない。
- A05/A06: 算術・比較・if の走査は未接続であり、現時点では Top と未対応の印になる。Environment の read/write/checkpoint/rollback と、Approx の正常値・失敗可能性・継続の区別を使用できる。同じ BindingId の一時的な更新も差分で復元できる。別名への逆向きの絞り込みを加えない。
- A07: Coverage::Prepared を全解析の完了として扱わず、未対応の印を維持する。新しい W0401/W0402 と一時的な dead_code の解除は未実施である。
- A10/A11/A12: 未対応の形の独立した子、別本体の発見と忘却、特殊構文の境界、Rust/Lean の全計上箇所と交換結果の一致、非実行報告の公開は各担当で閉じる。本作業の辞書に事実のない整数位置は暗黙の Top である。定数の番号付けと、値表の既存結果の参照を区別する。return の区間を関数間の推論に使わない。
- 割り当て量の余裕は小さいため、後続の結果・由来・環境の保持を追加する担当も、指定の二件を局所で再確認する必要がある。
- 独立レビューと受け入れは取りまとめが担当する。stage・change・release、Lean のビルド・全比較、heap/stress、性能比較、勧告の再照合はこの作業に割り当てられておらず実行していない。

32ビット環境での実行・クロスビルドは未実施である。今回の端点は i128、usize は差分と文の位置の添字だけに使うことを点検した。

## 取りまとめのレビュー（2026-10-25）

環境の差分と復元、shadow・別名・パターンの Top、本体の終わりの一時保持の返却を確かめ、受け入れる。次の二点は Lean の `Interval/BudgetAnalyze.lean`・`BudgetWalk.lean` と計上の順序・回数が異なる。plan.md の A11 が計上と確保・返却の順序・回数を Lean の関数に一対一で揃える担当なので、A11 へ申し送る。

- 括弧の連なり: Lean の `expr` は `.paren` を含む各訪問で `scope` により作業スタックの一枠（stackFrame）を確保する。Rust の `flow.rs` の `expr` は括弧の連なりをループで辿り、式の訪問は一回ずつ数えるが、枠は連なり全体で一つしか確保しない。最大同時保持と、保持項目の上限で止まる位置が異なりうる。ループで辿ること自体（再帰の深さの規約）は保ち、枠の数だけを Lean に揃える。
- 番号付けと値の解析の順序: Lean は一つの走査で各式の `identify` と `tick .expression` を交互に行う。Rust は `IdentityMap::build` で番号付けを終えてから `flow::analyze` を走らせる。合計の回数が同じでも、操作・保持の上限で止まる位置と、番号未取得（unidentified）と超過（exceeded）の分類が異なりうる。
