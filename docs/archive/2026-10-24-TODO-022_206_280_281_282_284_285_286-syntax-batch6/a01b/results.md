# A01b の結果

状態: A01b の実装と担当する work 検査を完了した。独立レビューと受け入れは取りまとめが担当する。

## 基準と範囲

- 作業日: 2026-10-25。
- ブランチ: `mod012/A01b`。B_WORK と開始時の HEAD はともに `2dbaac35dfa373b1a9368e6f7b7c5bc0f8ed2e90`。開始時の差分はなかった。
- plan.md の作業群 A01 の枝 A01b を実装した。`identity.rs` とその局所検査、`interval/mod.rs`、正規化に必要な `input.rs` の読み取り情報、設計書 02-05 を変更した。
- private/ と、それを指すスキルは読んでいない。git の変更操作は行っていない。`interval/mod.rs` の一時的な `#![allow(dead_code)]` は指示どおり残した。

番号付けと元ソース対応、定数の展開、合成節点、元定義の番号を使う境界本体名、取得済みの接頭辞を残す停止を実装した。正規化に必要な補間の型・try の種類・Fail ハンドラの出現を BodyInput へ保存し、共有表へ宣言の型を加えた。実装内容は設計書 02-05「区間解析の式の識別」へ記した。通常の型検査の署名と入力の収集条件は変更していない。

## 検査

Cargo の書き込み先は前作業で用意された `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。リポジトリの manifest・lock・検査設定は変更していない。以下の `<repo>`・`<home>`・`<tmp>` は、保存するログで手元の絶対パスを伏せた表記である。

| コマンド・確認 | 終了状態 | 外側の時間・記録 |
|---|---|---|
| `cargo check -p benitoite --lib`（rtk proxy 経由、上記 CARGO_HOME） | 0 | 外側は未計測。Cargo の表示は12.12秒 |
| `cargo test -p benitoite --lib typeck::interval::identity::tests -- --nocapture`（同じ環境） | 最終は0 | 最終8件成功・失敗0件。外側は未計測。Cargo のビルド10.86秒、テスト0.20秒。途中の失敗と修正は下記 |
| `cargo clippy -p benitoite --lib --tests --examples -- -D warnings`（同じ環境） | 101 | 外側は未計測。列挙型の網羅性を明示する規約の違反3箇所を検出し、全て列挙するよう修正。最終の確認は指定の work に含む |
| `cargo fmt --all`（rtk proxy 経由） | 0 | 外側は未計測。編集後の整形に使用 |
| Surface.Expr・SurfaceForm・identity の静的照合（読み取りの Python） | 0 | 1秒未満。53構成子、欠落・余分なし。変換の意味の全証明とは区別する |
| 02-05 の相対リンク・フェンス・末尾空白・禁止リンクの点検（読み取りの Python） | 0 | 1秒未満。リンク99件の参照先を確認。初回の点検器がコード内の型をリンクと誤認したため、コードを除外して再実行した |
| `git diff --check`（読み取り、rtk proxy 経由） | 0 | 1秒未満 |
| `scripts/check.sh --level work --base 2dbaac35dfa373b1a9368e6f7b7c5bc0f8ed2e90 --dry-run` | 0 | 1秒未満。fmt、examples 込み lint_default、lib_default、全統合 tests_related、source_rules、skill_generated、spec_tally を選択。[ログ](dry-run.log) |

作業末は、同じ基準・指定の work を一度実行した。rtk proxy 経由で実行した、計時と終了状態の識別を含むコマンドは次のとおりである。

```sh
env CARGO_HOME=<tmp>/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh -c 'scripts/check.sh --level work --base 2dbaac35dfa373b1a9368e6f7b7c5bc0f8ed2e90; check_exit=$?; print -r -- "A01B_CHECK_EXIT_STATUS=$check_exit"; exit "$check_exit"'
```

検査本体は終了0、time を含む外側は終了1である。外側の時間は real **529.31秒**、user 1575.64秒、sys 42.36秒だった。[保存ログ](work.log)に `selected checks passed` と `A01B_CHECK_EXIT_STATUS=0` がある。fmt、examples を含む clippy、既定 lib **1,280件成功・失敗0件・既存の除外21件**、全40統合ターゲットの合計 **378件成功・失敗0件・既存の除外10件**、ソース規約、Skill の生成物の一致、仕様集計が全て成功した。今回追加した局所検査8件は lib 全件にも含まれる。

最大常駐量（maximum resident set size）は取得不能である。`/usr/bin/time -l` は検査を終えて時間を表示した後、`time: sysctl kern.clockrate: Operation not permitted` と報告し、最大常駐量の行を出さなかった。外側の終了1はこのサンドボックスの計測制限によるもので、検査本体の失敗や最大常駐量0としては扱わない。計測だけを目的とした work の再実行はしていない。

### 局所検査の途中の失敗と修正

最初のテストの準備では、本番の関数の検査が与える末尾の Unit 制約を省いていた。そのため return 式の結果型が未解決になり、入力の収集が失敗した。本物の Body/solver に同じ制約を渡すよう準備を修正し、戻り値の注釈と関数のエフェクトの制約も本番へ揃えた。本番にテスト用の入口や型表の注入は追加していない。

リスト展開の合成関数の期待値は、初回には通常の関数としていた。標準の List.concatenate の解決済み宣言が BuiltinFn であることと既存の exporter を確認し、PrimName へ訂正した。番号・元位置・子の順序の期待は緩めていない。

Fail 節の初期入力では、通常の型検査で受理される Failure.raise／Failure.fromResult の呼び出し先に残る型変数を、既存の `BodyInput::collect` が InvalidType として断った。収集条件は変えていない。Fail 節の番号・元位置・境界の検査には、Failure.Fail[String] を宣言した、型が確定した通常関数の呼び出しを使用した。この既存の収集制約は、下の申し送りへ残す。

新しい局所検査8件は、独立交換のキー・順序と元ソース対応の契約を持ち主とする。負号と return・ソース順、直接の最小値と零、未対応の子と合成関数、定数の複数展開、境界と節順、予算停止の接頭辞、builder/try/with、Fail 節と空本体をそれぞれ確かめる。既存の脱糖検査は元 NodeId/span と未取得の接頭辞を返さないため、この対応漏れを捕まえられない。test-audit の作成時の関門を確認し、本番の公開範囲を広げず、本物の読み込み・名前解決・型検査・solver を使った。既存テストの削除・大きさや期待値の緩和はない。本番 Rust は追加924行・削除2行、テスト Rust は追加483行・削除0行である。

## 計画からのずれと申し送り

通常の型検査と利用者向けの警告への接続は A02 以降の範囲であり、ここでは行っていない。別本体の記録は名前と元番号範囲であり、忘却した入口環境や解析の待ち行列を作る処理ではない。言語の規則、Lean の定義・主定理・公理は変更していない。Lean のビルドと Rust/Lean の全比較は対象外として実行していない。

- A02: valid 条件の下で finish 前に入力を収集し、全本体の型検査後のソース順で使用する。定数展開用には、参照される定数の BodyInput とその元 AST を束縛番号で渡す。InputTables には完成した定数・リテラル・宣言の型の共有表を渡す。
- A02 の入力収集で確認する点: 通常の型検査が受理する多相な呼び出し先の未解決の型変数と、`BodyInput::collect` が全ての式型へ行う `unresolved_type` の拒否が両立しない場合がある。確認した入力は `return handle Failure.raise("bad") with case Failure.raise(error) -> 7 end handle`、および `r: Result[Integer, String]` への `handle Failure.fromResult(r)` である。前者の呼び出し先には未解決の結果型、後者には未解決の型引数が残り、通常の出力表では Unit に具体化されていた。入力作成の失敗を新しい言語の拒否にせず、収集対象と既存の finalize の扱いを A02 の接続時に点検する必要がある。A01b ではこの条件を緩めていない。
- A07: 一時的な dead_code の許可と AGENTS.md の一時的な行を、型検査への接続を終えた時点で消す。
- A10/A11: 保存した境界の範囲から別本体を扱い、型・環境・対応表・作業枠の費用を本体/全体の共通予算へ接続する。今回の NumberingBudget は操作と保存項目の残量を制限する部品であり、Lean の全ての計上規則や 4 MiB/16 MiB の共通上限との一致はまだ扱わない。
- 取りまとめ: 独立レビューと受け入れを担当する。未接続の部品の short は、計画どおり A07 の区切りへまとめる。

検査の実行手順では、局所の clippy を作業末の入口より先に実行した点が計画からのずれである。検出した網羅性の違反を直し、指定された work の clippy で最終状態を確認した。A01b が担当する検査の未実施は残っていない。
