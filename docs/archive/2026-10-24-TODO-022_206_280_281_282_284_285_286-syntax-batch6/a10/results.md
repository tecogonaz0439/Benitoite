# A10 の結果

2026-10-25。基準 B_WORK は `7d2277bd3e8d9017b6020dd30bc9a70b80f7d8ae`、作業ブランチは `mod012/A10` である。git の変更操作は行っていない。

## 検査

作業末の検査スクリプトは全選択単位に成功した。`/usr/bin/time -l` の外側の時間は435.31秒である。計測用ラッパーは `sysctl kern.clockrate: Operation not permitted` により終了1を返した。検査本体は `selected checks passed` の直後に終了0となる経路まで完了している（`scripts/check.sh` の work の終端）。最大常駐量は取得不能であり、数値を推測で補っていない。

| コマンド・対象 | 終了状態と結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| `scripts/check.sh --level work --base 7d2277bd3e8d9017b6020dd30bc9a70b80f7d8ae --dry-run` | 0。fmt、examples込みclippy、既定lib全件、全統合、規約、Skill生成照合、仕様集計を選択 | 未計測 | [dry-run](logs/dry-run.log) |
| `/usr/bin/time -l scripts/check.sh --level work --base 7d2277bd3e8d9017b6020dd30bc9a70b80f7d8ae` | 検査本体0、計測ラッパー1。lib成功1,295件・既定除外21件、全40統合ターゲットで成功382件・既定除外10件。fmt・lint・規約・生成照合・仕様集計も成功 | 435.31秒 | [work全出力](logs/work.log) |
| `cargo test -p benitoite --lib typeck::interval -- --nocapture`（作業途中） | 0。23件成功 | 外側は未計測、テスト0.59秒 | [局所](logs/interval-local.log) |
| `cargo test -p benitoite --test declarations interval_boundaries -- --nocapture`（作業途中） | 0。公開境界の35行の表が成功 | 外側は未計測、テスト1.94秒 | [公開境界](logs/boundaries-local.log) |
| `lake env lean -M 12288 <tmp>/benitoite-a10-probe.lean`（formalをcwdとする） | 0。空引数・一引数のlambdaの発見 `(operations,saved,peak,temporary)` が `(7,1,6,0)`・`(11,2,8,0)`。根の準備と待ち行列を加えたRustは `(10,2,6,0)`・`(14,3,8,0)` で一致 | 未計測 | [入力](logs/lean-probe-input.txt)、[実行値の抜粋](logs/lean-probe.log) |
| `target/debug/benitoite check <tmp>/benitoite-a10-generic-handler.bnt` | 0。`Trait.Show`の辞書を持つ操作の節の内側でW0401一件。通常の検査は成功 | 0.1秒未満（道具の外側） | [入力](logs/generic-handler-input.txt)、[出力](logs/generic-handler.log) |
| `/usr/bin/time -l target/debug/benitoite check <tmp>/benitoite-a10-independent-return.bnt` | 検査0、計測ラッパーはsysctl制限。独立入力内のreturnを親へ戻さず、その未知の呼び出しの後の局所束縛に基づくW0401一件を保持 | 1.20秒 | [入力](logs/independent-return-input.txt)、[出力](logs/independent-return.log) |

仕様例の統合ターゲットは全統合に含めて実行した。Lean のプローブは並行実行していない。作業末の work の後にはRust・設計書・入力・期待値を変更していない。後に追加したのはこの結果記録と保存ログだけである。

### 割り当て量

二件とも作業途中と最終状態で局所実行し、workの全統合でも成功した。最終状態のコマンドはそれぞれ `/usr/bin/time -l cargo test -p benitoite --test call_allocations <下表のテスト名> -- --nocapture` である。Cargoの検査は成功、計測ラッパーは上記のsysctl制限により各終了1となった。上限・入力・期待値は変更していない。

| テスト | 最終状態の割り当て量 | 上限 | 外側の時間 | 記録 |
|---|---:|---:|---:|---|
| `long_constant_chain_has_bounded_check_allocations` | 440,032,577バイト | 536,870,912バイト（512 MiB） | 11.83秒 | [出力](logs/allocations-long.log) |
| `repeated_constant_diagnostics_share_bounded_origin_work` | 252,266,832バイト | 268,435,456バイト（256 MiB） | 1.40秒 | [出力](logs/allocations-repeated.log) |

作業途中の値は439,793,505バイト・252,027,760バイトだった。以後に段の状態の保存などを追加したため、最終状態で数値を取り直した。

### 初回の失敗と修正

1. 初回のworkはfmtの後、列挙型のワイルドカード7箇所とまとめられる条件式2箇所でclippyが停止した。lib全件と全統合へ進んでいない。分岐を明示し、条件式をまとめた。外側11.78秒、検査1。記録は[初回](logs/work-first-lint-failure.log)に残した。
2. 二回目はclippyに成功したが、libの既存の深い式のテストがスタック超過になった。外側59.71秒、検査1。記録は[二回目](logs/work-second-stack-failure.log)に残した。
3. `deep_expressions_stay_within_the_normal_stack`の加算450段で局所再現し、親の解析の後の発見で起きることを確認した。発見の大きい分岐（名前・呼び出し・レコード・補間）を補助関数へ分け、発見側の括弧をループにした。各括弧のscopeの枠は保持する。元の6形・深さ・スレッドのスタック量を保って成功した。デバッグ出力を取り除き、既存のテストファイルは元と同じ状態へ戻した。[再現](logs/stack-reproduction.log)と[局所修正後](logs/stack-fixed-local.log)を保存した。A11に渡す値の解析側の既存の括弧の計上差は変更していない。
4. 初期の局所表では、根のseed一項、Fail節の別本体二件、入口作成後の番号未取得に対する既存の期待値三件を更新した。新しい表の試作時の構文・importの誤りと、右辺の括弧を含む元番号の誤りも修正した。入力と上限を緩めて成功にしていない。最終のworkではすべて成功した。

独立入力内のreturnについては、実CLIの追加プローブで親への伝播を切ることも確認した。Leanが未知の親の後続として解析する位置の警告を、Rustだけの到達判定で消していない。

保存ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。基準とHEADは同じ完全IDであり、成果物は未コミットの差分として残す。

## 計画からのずれと申し送り

- 未対応の二項演算、呼び出し、レコード、リストと展開、補間、パイプ、穴、負号、try と説明、resume の直接の子と、with・handle の本体を独立入力として接続した。親の候補・未対応の印・局所環境を復元し、子の正常値・return・絞り込みを親へ戻さない。内側から保存した入力の候補も診断の統合へ渡す。
- 独立入力の枠は忘却より前に確保し、忘却中の停止も保存する。入口環境は一時保持だけとし、診断用の由来を空にする。由来は従来どおり最大8件で、予算に戻していない。
- `BudgetDiscover`・`BudgetWhole` に対応する予算付きの発見、節の先読み、待ち行列、別本体の解析を接続した。同じ handle の全節を内側の境界より先に登録し、値の到達判定によらず元定義から発見する。別本体から再発見しない。引数・捕捉環境を忘却し、辞書数は解決済みの操作の Scheme から読む。破棄した引数と継続の位置も保持する。
- `EmbeddedBody`・境界の分類・命名・`parent_key` と `Handling` を、指定の履歴から必要な経路へ戻した。発見の対応表を二重に保存しない。パターンの欄数の走査で必要になった `Item::RecordField` も使用経路とともに復元した。
- 根の seed と別本体の入口環境は共有して保存し、一時領域から保存領域へ移す。入口・発見・待ち行列・別本体の制御の停止、発見済み未解析の参照を `Report.definitions` に残す。01-04・02-05 を実装へそろえた。

- 大きい分岐と再帰の枠を分けるため、`interval/discovery.rs` と `interval/flow/independent.rs` を追加した。入力の分類、環境、駆動、診断と既存のテストも、接続に必要な範囲で変更した。
- 新しく加えた忘却・独立入力の保存と復帰、発見・先読み・待ち行列・結果枠は Lean の該当する関数の順序で計上する。A11 に渡っている既存の括弧の枠数、番号付けと値の二走査、skipExpr の違いは直していない。全経路・任意予算の厳密な比較は A11/X02 の担当であり、局所の数例の一致を全体の一致として扱わない。
- A12 は `Report.definitions` の prepared/discovery/queue/discovered/pending/embedded_stop と `first_incomplete`、`unsupported_bodies` を本体自身の状態と分けて集計する。停止した独立入力を本体数へ重ねず、未発見の本体数を推測しない。既知の全体停止の集計と利用者向け報告は A12 の範囲である。
- 型・エフェクトの規則、警告を許す通常の受理、実行時検査、Lean の定義・主定理・前提・結論・公理は変更していない。未決の言語の判断は発生していない。
- 独立レビュー・段の検査・受け入れは取りまとめが担当する。Lean の全ビルド・Rust/Lean の全比較、heap/stress、change/release、性能比較は A10 の割り当て外であり実施済みとしない。32ビット環境での実行・クロスビルドも未実施である。

### テストの変更の申し送り

新しい公開境界の表は機能の契約の検査であり、外の事実の忘却、子の内側の警告、子の return の後続を解析しないこと、未到達の子と到達によらない別本体の発見を守る。内部の表は、診断の重複排除だけでは観察できない独立入力の保存順・元番号・途中停止の候補と、Lean と共有する予算を守る。実際の名前解決・型検査・入力収集を使い、テスト専用の本番の引数・状態・公開範囲は追加していない。

テストは削除していない。既存の三件は、根の seed の保存、Fail 節の別本体、入口作成を含む停止分類へ期待値を合わせた。入力と予算の上限は維持した。復元した二件は、未使用の一覧の検査から、実際の発見と解析へ接続した元番号の契約の検査へ戻した。

本番Rustは追加1944行・削除49行、テストRustは追加302行・削除6行である（新規の二モジュールを含む）。担当範囲の未実施・不合格の検査と未決の判断は残っていない。独立レビューと受け入れを取りまとめへ引き渡す。

## 取りまとめのレビュー（2026-10-25）

未対応の形の子を外の事実を忘れた独立入力として解析し、子の正常値・return・絞り込みを親へ戻さないこと、lambda・lazy・handler の節を別本体として発見して引数・捕捉値を Top から解析すること、try・with・handle の親の値から外へ事実を伝えないことを、公開の境界の表（35入力）で確かめた。到達しない枝の未知の子は解析せず、到達しない枝の中の別本体は発見して解析する（`if false` の中の lambda の本体に W0401 が出る）。これは decisions.md の D8a と Lean の発見の規則（未到達・別本体は番号だけ走査し、別本体は自分の根から解析する）どおりであり、01-04 の追記（別本体の呼び出しの到達を断定しない）とも一致する。受け入れる。A08〜A12 をまとめた独立レビューを A12 の区切りで行う。
