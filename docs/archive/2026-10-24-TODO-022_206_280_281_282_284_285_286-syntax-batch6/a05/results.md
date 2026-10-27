# A05 の結果

## 基準と変更

2026-10-25。作業ブランチは `mod012/A05`、B_WORK と開始時の HEAD はともに `fc6a495df66e8c560e26d9950e5c60021fca3d2f` である。開始時の追跡対象の差分はなかった。git の変更操作は行っていない。private/ と、それを指すスキルのリンクは読んでいない。

`interval/arithmetic.rs` を新設し、Integer64 の加算の数学上の結果区間と型の値域の交差、演算自身の失敗可能性、全域外のあふれ候補を分けた。端点の中間計算には i128 を使う。div/mod は正常な二引数があり、除数が一点0の場合だけ候補を作り、正常区間は Top にする。0を含む複数値の区間、最小値と -1 の商・剰余から、新しいあふれ候補を作らない。

`flow.rs` で、型検査済みの左右が Integer64 である対象演算を、左辺・右辺・演算自身の順で解析する。子の Bottom から正常値を復活させず、未到達の右辺や親へ候補を追加しない。候補は先行順番号、元 NodeId/span、一次位置、演算、原因、左右の正常区間を持つ。本体名は所有する報告から得る。候補の保存は Lean の `BudgetAnalyze.lean` の `own`・`saveWarnings` と同じく、作業枠の確保、保存一項の確保、列への追加、作業枠の返却の順にした。算術そのものに Lean にない追加の操作数を計上していない。

保存済み候補を後続の停止でも残すため、`interval/mod.rs` の本体結果を `flow::Analysis` の箱へ変更し、値の `Result<Approx, IdentityStop>` と候補列を分けた。番号付け前の停止では従来どおり flow は None、値の解析中の停止では Some の内部に Err と保存済み候補を持つ。候補を Approx ごとに複製せず、定数ごとの局所結果の箱も増やしていない。設計書 02-05 に算術と保存・停止の扱いを反映した。

## 検査

Cargo は先行作業と同じ `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。manifest・lock・検査設定は変更していない。一時的な Python 実行器は、コマンドを `/usr/bin/time -l` と zsh で包み、出力の絶対パスを `<repo>`・`<home>`・`<tmp>` に伏せ、外側の時間を記録した。ログの `A05_COMMAND_EXIT_STATUS` は検査本体の終了状態、`A05_OUTER_EXIT_STATUS` は計測も含む外側の終了状態である。

| コマンド・確認 | 本体の終了状態 | 外側の時間・記録 |
|---|---|---|
| `cargo test -p benitoite --lib typeck::interval::tests -- --nocapture`（接続直後、既存の局所検査） | 0、9件成功 | 26.260秒。[local-first.log](local-first.log) |
| 同じ局所検査（新しい表・停止の検査を追加後） | 101、10件成功・1件失敗 | 13.368秒。[local-arithmetic.log](local-arithmetic.log)。新規入力に誤った整数接尾辞 i8 を書き、E0115 になった |
| 同じ局所検査（接尾辞を規定の s8 へ修正後） | 0、11件成功 | 11.058秒。[local-arithmetic-fixed.log](local-arithmetic-fixed.log) |
| `cargo test -p benitoite --test call_allocations long_constant_chain_has_bounded_check_allocations -- --exact --nocapture` | 0、1件成功 | 26.141秒。455,816,427バイト、既存512 MiB未満。[allocation-chain.log](allocation-chain.log) |
| `cargo test -p benitoite --test call_allocations repeated_constant_diagnostics_share_bounded_origin_work -- --exact --nocapture` | 0、1件成功 | 4.935秒。267,690,706バイト、既存256 MiB未満。[allocation-repeated.log](allocation-repeated.log) |
| `cargo test -p benitoite --lib deep_expressions_stay_within_the_normal_stack -- --nocapture` | 0、1件成功 | 5.451秒。既存の入力とスタックを維持。[deep-stack.log](deep-stack.log) |
| `cargo fmt --all` | 0 | 編集後の整形。外側未計測 |
| 02-05 の相対リンク・アンカー・フェンス・末尾空白・禁止リンクの読み取り点検 | 0 | 1秒未満、相対リンクとアンカー103件。最初の一時実行器はコードフェンス内の型の例をリンクと誤認したため、フェンスを除いて点検し直した。文書の修正は不要だった |
| `git diff --check`（読み取り） | 0 | 1秒未満 |
| `scripts/check.sh --level work --base fc6a495df66e8c560e26d9950e5c60021fca3d2f --dry-run` | 0、七単位を選択 | 0.080秒。[dry-run.log](dry-run.log) |

割り当て量の二件の上限・入力・期待値は変更していない。両方とも A04 の記録と同じバイト数であり、後者の残量は744,750バイトである。

作業末のコマンドは次のとおりである。統合ターゲットを絞る `--test` は指定していない。

```sh
env CARGO_HOME=<tmp>/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh -c \
  '"$@"; task_exit=$?; print -r -- "A05_COMMAND_EXIT_STATUS=$task_exit"; exit "$task_exit"' \
  a05 scripts/check.sh --level work --base fc6a495df66e8c560e26d9950e5c60021fca3d2f
```

| 実行 | 結果・記録 | 外側の時間 real / user / sys | 最大常駐量（maximum resident set size） |
|---|---|---|---|
| 作業末の work（一度） | 七単位が全て成功。本体0、計測を含む外側1。[work.log](work.log) | 420.24 / 1280.71 / 48.19秒（実行器420.250秒） | 取得不能。サンドボックスの sysctl 制限 |

既定 lib は **1,291件成功・失敗0件・既存の除外21件**、全40統合ターゲットの合計は **378件成功・失敗0件・既存の除外10件** だった。fmt・examples を含む clippy・ソース規約・Skill 生成物の一致・仕様集計も成功し、初回リリースの完了条件の未記入は0件だった。仕様集計の「参照のない仕様節」の一覧は、検査の失敗と区別してログに残した。割り当て量の二件も全統合検査の中で再度成功した。work の後に Rust・生成物・検査入力は変更していない。

最後の読み取り点検で、検査の件数、結果記録とログのリンク、手元の絶対パスの伏せ、Markdown の末尾空白、`git diff --check` を確認し、全て成功した。

`time -l` はサンドボックスの `sysctl kern.clockrate: Operation not permitted` により、最大常駐量（maximum resident set size）を取得できない。検査本体が成功しても計測側の外側の終了状態は1となるため、各ログの本体の終了状態と区別する。

### test-audit の作成時の関門

表の一件は、公開 typecheck の本物の収集と駆動を通し、成功区間、失敗可能性、候補の原因・演算・一次位置を確かめる。境界の加算、一部だけのあふれ、全域外、中間失敗、左右の子 Bottom、未到達の右辺、除数0、0を含む [-1,1]、未知や別の幅を含めた。[-1,1] は各段で正常値を交差する加算列から作り、まだ接続していない if を仮定していない。既存の束縛だけの表では、算術の取り違えを観察できなかった。

停止の一件は、既存の実際の型付き入力の準備を使い、本体の操作数と保持項目数の上限をそれぞれ1〜200へ変えて、停止後も候補が解析順の接頭辞として残り、一時保持が0になること、完走時は二候補と同じ正常値が得られることを確かめる。停止位置や厳密な消費件数、辞書の並びを固定していない。テスト用の本番引数、型表の手作り、公開範囲の拡大、新しい差し込み口はない。

既存テストの値の参照を、新しい本体結果の Result を通す形へ変更した。停止時の候補保持に合わせて、値の未取得を None または Err として確かめ、全体上限・次本体の未着手・一時保持0の期待は維持した。テストの削除はない。本番 Rust は追加212行・削除18行、テスト Rust は追加294行・削除5行である。

## 計画からのずれと申し送り

- 候補の本体ごとの保存と停止後の保持を接続するため、指定の arithmetic.rs・flow.rs に加えて interval/mod.rs と既存テストの内部結果の参照を変更した。型・エフェクトの規則、公開 typecheck の署名、実行時検査、新しい利用者向け診断、Lean の定義・主定理・公理は変更していない。mod.rs の一時的な `#![allow(dead_code)]` は残した。
- A06: Integer64 の対象算術が既存の局所環境へ接続されている。正常区間と失敗可能性、正常な継続と return を分けた Approx を継続して使用できる。候補は Flow の一つの列へ保存し、分岐や合流で複製しない。
- A07: `BodyReport.flow` は `Option<Box<flow::Analysis>>` である。`value` は成功または停止、`candidates` は保存に成功した候補列であり、Err でも候補を読む。本体名と候補の preorder を組にしてキーを得る。型は現段階では Integer64 固定、由来の補助位置は未追加である。候補は子から親への解析順で保存しているので、利用者向け診断の重複排除と採用順は計画の本体順・先行順へ揃える。既存の定数警告を優先する。
- A10/A11/A12・X: 未対応の形の独立した子、別本体の発見と忘却、全計上の対応、公開報告、Rust/Lean の全比較は未実施である。A04 の二点（括弧の連なりの枠の数、番号付けと値の解析の走査順序）は変更していない。候補の元の出現は既得の番号表を参照して得ており、候補ごとの索引や本体名の複製を保持しない。
- 割り当て量の余裕は小さい。後の担当も指定の二件を局所で再確認し、上限・入力・期待値を緩めない。
- 独立レビューと受け入れは取りまとめが担当する。stage・change・release、Lean のビルド・全比較、heap/stress、性能比較、勧告の再照合は本作業の割り当てに含まれず、実行していない。

32ビット環境での実行・クロスビルドは未実施である。端点と加算の中間値には i128 を使い、ホスト幅の usize を整数の値域に使っていない。

## 取りまとめのレビュー（2026-10-25）

加算の正常区間・失敗可能性・確実なあふれ、整数除算と剰余の除数 `[0,0]` の判定を、Lean の `Interval/Arithmetic.lean` の `addApprox`・`divModApprox`・`divModAlwaysZero` と照合し、一致を確かめた。受け入れる。

- 未対応の演算（減算・乗算など）と Integer64 以外の型の二項演算は、子を辿らずに Top を返す。Lean の `expr` は `unknownChildren` で子を独立に解析する（decisions.md D8a）。未対応の形の独立した子は A10 の担当である（A04 の申し送り）。
- 左辺が継続しないときの右辺について、Lean は `skipExpr` で番号を消費する。Rust は番号付けを先に済ませるので値の解析では辿らない。計上の順序の違いとして A11 へ申し送る（A04 のレビューの二点目と同じ根）。
- `save_candidate` は候補ごとに番号表を線形に探す。候補は確実に失敗する演算だけなので今は小さいが、A11 で番号表の引き方を揃えるときに見直す。
