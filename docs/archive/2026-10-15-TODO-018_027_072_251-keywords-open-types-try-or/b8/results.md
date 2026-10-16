# B8 終了結果と報告の型の実装

## 目的と範囲

die の言語からの実行に先行して、原因・任意の説明・位置の受け渡しと文章・JSON の描画を用意した。ソースの die はまだ受理しない。コミット、docs/todo の変更、formal の変更は行っていない。

## 変更した箇所

- `vm/mod.rs` の `DieFailure` と `StopReason::Exit`、`runtime/io/mod.rs` の `Request`、`runtime/run.rs` の `RunEnd` に所有した情報の欄を追加した。既存の構築箇所は `None` とする。RunEnd への変換は `Exited(1)` の停止結果だけから情報を受け取る。Internal への置き換えと、値で終わった後の中断では保持しない。
- `Request` の `Copy` を外し、`vm/dispatch/tasks/io.rs` の移動後に使っていた task・site は先に取り出す。公開の publish の引数は変えず、要求の情報の採用は B10-2 の担当とする。
- `runtime/report.rs` と `diag/{mod,render,codes}.rs` に `Die` の共通の報告を追加した。固定文は `codes::text` に置く。説明は指定時だけ、原因は常に注記へ写し、位置を主位置にする。
- `cli/mod.rs` は最後の転送が済んだ RunEnd から die、補足の reports の順に描画する。`cli/tools/test_runner/{mod,report}.rs` は `Failure::Exit` に情報を保持し、捕捉した出力を変更せず文章・JSON へ出す。通常の exit の形式は保つ。
- 型の追加に伴い、VM・runtime・組み込みの既存テストの Exit の構築・パターンへ `die_failure: None` を補った。既存の assert はすべて維持した。`cli/tools/skill/generate.rs` の報告の種類の全場合にも `Die` を追加した。
- 06-01・06-04 と、報告の種類の正である 02-10 に、内部の描画の入口と本番未接続の範囲を反映した。JSON の具体化は decisions.md の R55、停止理由の保持箇所は R56 に記録した。

## test-audit の作成時の関門

| 問い | 回答 |
|---|---|
| 守る振る舞い・契約 | 共通の報告の入口で原因・説明の省略と空文字列・位置を失わない。CLI は採用された die を補足より先に一度だけ描画する。test runner は exit の分類・状態・補足・捕捉した出力を保つ |
| 捕まえる退行 | 空の説明を省略扱いにする、原因を説明で上書きする、引用符や位置を落とす、die を runtime/internal に分類する、報告の順序を逆転する、別の終了理由に die を描画する、捕捉した stderr へ報告を重複して書く |
| 既存テストとの差・主となる境界 | `runtime::report::die_diagnostic` から文章と JSON への描画を主となる境界とする。既存の Stop の入力は DieFailure を持たない。CLI の報告順と test runner の failure JSON・捕捉出力は、それぞれに固有の危険なので lib で追加した。通常の実行の `None` は既存の表を拡張して確認する。停止結果から RunEnd への情報の移動と解放の補足の維持も、既存の停止結果の表に一行を追加して確認する |
| 本番の差し込み口 | 追加しない。CLI の描画は本番でも使う非公開の共通処理へ分けた。構造化した結果を直接渡し、本物のソースの die を通した検査とは扱わない |

既存テストの削除、assert の削除、期待値の緩和、ignore の追加はない。新しい描画テストの初回は、既存の文章の溝の幅と JSON の位置の形に合わない期待値で失敗したため、既存の描画仕様を確認して厳密な期待値へ直した。処理系の既存の描画は変更していない。

Rust の本番部分は 153 行追加・24 行削除（差し引き 129 行増）、テスト部分は 284 行追加・15 行削除（差し引き 269 行増）である。削除行は受け渡しの形と既存の処理の書き換えであり、テストそのものの削除はない。テスト専用の本番コードの削減を目的とする監査は行っていない。

## 診断の変更

既存の診断コード・主文・help・主副位置・終了状態に変更はない。追加する報告は次のとおりである。

| 項目 | 内容 |
|---|---|
| 種類・コード | `die`・`null` |
| 主文 | `explicit failure exit`（文章の接頭語は `error:`） |
| 主位置・副位置 | DieFailure.at・副位置なし |
| 注記 | 説明があれば `message: ...`、常に `cause: ...`。この順に出す |
| help・履歴 | なし |
| 終了状態 | `Exited(1)`・1。解放と flush の補足は既存の分類・順序・状態を保つ |
| 元の誤りの検査の維持先 | 既存の runtime::report/run、cli_process、test_command。裸の try の入力と期待値は変更しない |

## 検査

コマンドはリポジトリの根で、rtk 経由で実行した。clippy の最初の失敗の詳細は `rtk proxy cargo clippy --workspace --all-targets` でも確認した。最後の Rust の変更後に lib 全体・関連統合テスト・clippy・fmt を再実行した。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 最終 1,169 件成功、既存の ignore 21 件、失敗 0。72.25 秒。runtime::run と追加した三つの報告テストを含む |
| `cargo test -p benitoite --lib runtime::report` | 11 件成功。以後の lib 全体でも同じ検査が成功 |
| `cargo test -p benitoite --test cli_process --test test_command --test runtime_builtins --test open_062 --test skill_docs` | 最終 5 スイート・49 件成功。11.49 秒。先行する四統合テスト 41 件と skill_docs 8 件の個別実行も成功 |
| `cargo run -p benitoite --example gen_skill` | 成功。生成物の差分なし |
| `cargo clippy --workspace --all-targets` | 最終成功。R56 の保持箇所の修正後は警告・誤りなし |
| `cargo fmt --all --check` | 成功。実装中に `cargo fmt --all` で整形した |
| `git diff --check` | 成功 |

実装途中の `cargo check -p benitoite --all-targets` は新しい欄の補完漏れと Request の移動後の参照を検出した。これらを補い、最終の all-targets の clippy で全ターゲットのコンパイルを確認した。初期の `cargo test -p benitoite --lib die_` は上記の新しい描画テストの期待値で失敗し、文章・JSON の厳密な期待値を直した後の runtime::report と lib 全体は成功した。初回の clippy の失敗と修正は R56 のとおりである。

`scripts/check.sh`（dry-run を含む）と gc-stress の構成の検査は、今回の明示指示に従い実行していない。formal は変更していないため、`lake build` と `check-formal.sh` も実行していない。構文の章・仕様の例・英語リファレンス・手書き Skill の例は変更していない。

## 計画の補足と申し送り

R55 で test runner の追加フィールドを `failure.die` の診断オブジェクトに具体化した。R56 で停止情報の保持箇所を StopEnd の独立欄から StopReason::Exit の欄に改めた。初回の clippy は VmStep の分岐の大きさの差を拒否したため、列挙型全体の大きさを増やさない保持箇所を選んだ。公開の言語 API、構文・型・脱糖、形式化の意味の変更はない。

B9 は内部の引数を IR とバイトコードへ保持し、B10-1/B10-2 は採用する既定の exit へだけ情報を移す。現時点の VM の全構築箇所は `None` である。B11/B12 で本物のソースから CLI/test runner の報告、継続する次のテスト、解放・flush・競合停止を確認する。共通の検査と gc-stress は今回の指示に従いオーケストレータへ引き継ぐ。
