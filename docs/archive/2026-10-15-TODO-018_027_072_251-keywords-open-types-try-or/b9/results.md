# B9 の実装結果

## 目的と範囲

内部の終了報告の値をコア IR・下位 IR・バイトコードに保持し、捕捉・値の変換・レジスタ割当・生存判定・検証・逆アセンブルへ接続する。通常の App と命令には None を設定する。実行の接続は B10、ソースからの生成は B10a/B11 の担当である。

## test-audit の作成時の関門

| 問い | 回答 |
|---|---|
| 守る契約 | 報告は標準 exit(1) の String 値だけを持つ。報告だけが使う変数も下位 IR と捕捉に残り、IO の読取レジスタとして生存する。命令と表の不整合を検証器が拒否する |
| 捕まえる退行 | 原因・説明の型や束縛の検査漏れ、別の関数や終了状態への付与、lowering での情報落ち、報告だけが使う変数の捕捉漏れ、IO 前の死値扱い、命令位置・範囲・表の長さの検査漏れ |
| 主となる境界と既存との差 | 型は check_program、変換と捕捉は lower_program/codegen、生存と破損入力は reg_use/verify を境界とする。既存の入力に報告情報はないため、新しい内部入力が必要である。バイトコードの破損検査にはソース生成と独立した既存の fixture を使う |
| 本番の差し込み口 | 加えない。既存の公開の IR とバイトコードの型を使う。VM と参照インタプリタは未接続の報告付き呼び出しを内部エラーで拒否し、実行できたとは扱わない |

## 変更したファイル

- `ir/{core_ir,lower_ir}.rs` に任意の内部報告を加え、`ir/check.rs` で標準の exit(1)・String・束縛の有効範囲を検査する。`ir/decision.rs` は報告値にも既存の値の変換を適用する。既存の変換は VarId を保ち、複製時には値内のラムダの BodyId を更新する。独立した変数の置換の処理はない。`ir/desugar.rs` と `ir/desugar/decls.rs` の通常の構築は None を入れる。
- `bytecode/program.rs` に命令ごとの `exit_reports` と `ExitReportSite` を加える。`bytecode/codegen/{state,mod,emit,analysis}.rs` は報告値の捕捉とレジスタ割当・命令位置の保持を行い、`bytecode/asm.rs` も通常の命令に None を追加する。
- `bytecode/liveness.rs` は報告レジスタを IO の読み出しに加える。`bytecode/verify.rs` は表の長さ・命令の対応・レジスタの範囲・生存の一致を確認し、`bytecode/disasm.rs` は命令位置と報告レジスタ・位置を表示する。
- `refinterp/{index,eval}.rs` は報告値も走査し、実行前の暫定拒否を加える。`vm/dispatch.rs` と `tests/desugar_export/exchange.rs` も未接続の情報の読み捨てを防ぐ。
- `ir/check.rs`、`bytecode/codegen/tests.rs`、`bytecode/verify.rs` に三つの内部入力のテストを加える。既存の liveness の入力は、命令列の構築・組み替えと同時に新しい表へ None を補う。既存の assert・期待値・ignore は変更しない。
- 現行設計書の 02-06・02-07 に保持と検査の契約を、07-04 に Rust の付加情報が形式化の対象外であることを反映する。Lean の定義・定理は変更しない。

Rust の本番部分は 243 行追加・16 行削除（差し引き 227 行増）、テスト部分は 342 行追加・3 行削除（差し引き 339 行増）である。削除行は App の欄の補完とパターンの書き換えであり、既存のテスト・assert の削除はない。テスト専用の本番の差し込み口は追加していない。

## 診断の変更

言語仕様上の診断コード・主文・help・主副位置・終了状態に変更はない。裸の try の検査の入力と期待値も変更していない。追加するエラーは不正な内部 IR・バイトコードと未接続の内部入力を拒否する処理系の不具合の報告だけである。

## 検査

コマンドはリポジトリの根から rtk 経由で実行した。最終の Rust の変更後は、lib 全体、clippy、関連統合テスト、fmt、差分検査、形式化の順に直列で実行した。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 最終 1,172 件成功、既存の ignore 21 件、失敗 0。74.09 秒。追加した三件と bytecode・VM・refinterp の検査を含む |
| `cargo test -p benitoite --lib bytecode::` | 個別では 34 件成功。以後の最終 lib 全体でも成功 |
| `cargo test -p benitoite --test desugar_export --test random_programs` | 最終 desugar_export 16 件成功・既存の ignore 1 件、random_programs 3 件成功。ランダム差分は 300 入力・反例 0 件・49.42 秒で既存の 60 秒制限を満たす |
| `cargo clippy --workspace --all-targets` | 最終成功。警告・誤りなし |
| `cargo fmt --all --check` | 成功。実装中は `cargo fmt --all` で整形した |
| `git diff --check` | 成功 |
| `bash scripts/check-formal.sh` | 成功。冒頭の `formal/` の `lake build` を含む。sorry の警告なし。六入口・独立入力・破損入力・manifest の照合がすべて成功 |

初回の lib 全体は、新しい表を補っていなかった既存の liveness の手書き入力 5 件で失敗した。命令の構築・組み替えに None の表の補完を加え、既存の assert と期待値を保ったまま修正した。追加した三つのテストの初回には、入力の構文、定数引数の束縛、待つ命令の既存の生存規則に合わない準備・期待もあり、契約に合う内部入力と期待へ直した。テストの捕捉の確認は順序の固定を避け、原因と説明がそれぞれ元の引数に対応することを検査する。初回の clippy はテストの enum の wildcard を拒否したため、全場合を明記した。

ランダム差分は途中で 67.16 秒と 60.30 秒の時間超過があった。どちらも 300 入力・反例 0 件であり、時間制限の assert が失敗した。入力数・時間制限・対象・ignore は変更していない。先行する単独実行は 49.63 秒、最後の直列実行は上表の 49.42 秒で成功した。

形式化の出力は `target/desugar-diff/run-56281/` にある。Rust の全コーパスの書き出しは 563.84 秒、最後の六入口の個別照合と破損入力の検査は 205 秒であった。通常の corpus 9・型表 3・網羅性 3 を保つ。独立した corpus 10 の try の正負の検査は既存の `test_try_exchange.py` で確認し、ソースの die の本番受理・書き出しを検査したとは扱わない。

| 形式化の入口・入力 | 件数と結果 |
|---|---|
| `coverageDiff` | 通常 10,020 件・view 付き 10,028 件がすべて一致。不一致・fuelExhausted 0 |
| `desugarDiff` | 1,736 入力のうち golden 349 件・random 1,000 件が対象。チェックエラーの除外は golden 387 件。範囲外・不一致 0。定義は golden 968 件・random 72,778 件が一致 |
| `builtinCheck` | 対象 1,349 入力。summary の比較 72,468 件、不一致・非収束 0。既存の Task.await/TaskGroup.spawn の不透明型の引数と State の仮定は維持 |
| `coverageProgramDiff` | match 16,417 件・bind 6,036 件、計 22,453 件一致。不一致・対象外・fuelExhausted 0 |
| `surfaceCheckAll` | 51,645 件一致、不一致・準備失敗・lazyRestriction 0。対象外は既存の unknown primitive 19 件、q11 は既存の 1 件。理由を含む全 outcomes が manifest と一致 |
| `surfaceCheck` | 1,736 入力の対応する表と定義・実装の数を個別確認し、全件の結果・位置付けが一致。検査の総数は 51,665 件 |
| 独立した交換形式・破損入力 | width 4 件・named 12 件・extensible 22 件・try 8 件の Python の検査が成功。最後の契約の破損 3 件、hole/pipe の破損 6 件、名前付きの破損 6 件も意図した理由で拒否 |

全入力の識別名・除外・scope・coverage の対応、73,746 定義・22,453 coverage entries、六入口の最終出力と manifest の一致を確認した。manifest、対象件数、対象外理由を下方修正していない。Lean の定義・証明・axiom・sorry/admit/native_decide は変更していない。

構文の章・診断の表・標準ライブラリ・仕様の例・英語リファレンス・手書き Skill の例は変更していないため、gen_skill と各例の個別検査は追加していない。

## 計画の補足と申し送り

表の具体的な形、値の木の Box、実行と交換の暫定拒否を decisions.md の R57 に推す案として記した。公開の言語 API と操作の引数の数は変更しない。現行の脱糖は通常の exit(1) の定数も一度変数へ束縛するため、新しい内部入力では App の公開引数に整数の定数 1 を明示している。B10a-2 の報告付き App の生成もこの契約に合わせる。

B10-1 は VM と参照インタプリタの暫定拒否を取り除き、言語のハンドラで処理されず既定の exit へ進む呼び出しだけの情報を所有した文字列へ移す。B10-2 は Request の寿命と採用に接続する。B10a-3 は交換の暫定拒否を取り除く。現在の本番ソースは報告付き App を生成せず、die のソースからの実行を検査したとは扱わない。

コミット、docs/todo の変更、scripts/check.sh（dry-run を含む）、gc-stress の構成の検査は、依頼に従って行っていない。共通の検査と gc-stress はオーケストレータへ引き継ぐ。
