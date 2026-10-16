# G5b のレビュー（2026-10-16、Opus 5.5 のサブエージェント）

対象: B10-2・B10-3・B10a-1・B10a-2・B10a-3（`git diff 890d6bce dae655bd`、コミット b6d4b35e〜0c0080a7）。読んだのは git のコミットだけで、ファイルは変えていない。cargo・lake・check.sh も走らせていない。

結論: 【重大】1 件、【中】3 件、【軽】5 件。型・脱糖・交換は、G4 で合意した Lean の規則と一致する。die が本番で受理される経路は見つからなかった。ただし、B10-3 で全プログラムの検査の時間がほぼ倍になったとみられる。R64・R66 は、この退行を「変更前から再現する」と誤って扱っている（指摘 1）。

## 確かめた点

- **die が本番で受理される経路**: 見つからなかった。`TryAction::Die` を作るのは `parse_try_action` だけである。そこへ進むには `try_action_ahead` が真になる必要があり、それには `Parser::accepts_die()` が真でなければならない。`accepts_die()` は `#[cfg(not(test))]` では常に `false` を返す（parser/mod.rs:224 付近）。`allow_die` 欄は `#[cfg(test)]` のときだけ存在し、`true` にするのは `parser/test_support.rs` の `parse_with_die`（`#[cfg(test)]` のモジュール）だけである。そこから使う `typeck::test_support::check_die_source`・`ir::desugar::test_support::desugar_die_source`・`lib.rs` の `exchange_tests` も、どれも `#[cfg(test)]` である。統合テストは cfg(test) なしでライブラリを使うので、本番と同じく die を拒否する。newline.rs の `ends_die` は本番にも入るが、効くのは本番で誤りになる入力（`die` の後の改行、`die(` の閉じ括弧の後の改行）だけである。
- **Lean の規則（E_TryResultDie・E_TryOptionDie・dieFailure）との一致**:
  - 入力は囲む `ret` のまま `ctx.expr(&e.value)` で型付けする。Die は `TryConstraintAction::Return` を作らない。このため、`solve_try` は囲む戻り値を単一化する前に抜け、囲む戻り値を制約しない。Lean の「R を制約しない」と一致する。
  - `Process.Exit` は `EffSub` で囲む関数かラムダのエフェクトに加わる。Lean の ε ∪ Process.Exit に当たる。
  - Show の制約は、入力が確定した後に `args.get(1)`、つまり Result の E に対して登録する。成功型 T とは取り違えていない。Option には登録しない。
  - 説明は `expr_in(message, fresh, None)` で型付けする。これは R = none に当たる。継続は `ctx.clauses` を空にして隠し（hideConts）、String への Flow と空のエフェクト集合への EffSub を生成する。
  - 説明の中の直接の try と return は、parser が E0218 にして `Expr::Error` に置き換える。このため、型検査の `debug_assert!` には達しない。
  - 脱糖（effects.rs `die_failure`）は、入力を分岐の外の一つの let に束縛し、失敗側でだけ「説明の let → 原因の let（`Trait.Show.show` の Method 呼び出し、または固定の文）→ `exit[T](1)`」の順に組み立てる。T は `self.ty(e.id)`、つまり try の成功型である。01-12 の表の四行と一致する。
- **G4 の L5**: `tests/desugar_export/lib.rs` の `typed_try_exchange_matches_independent_corpus_ten` が照合している。この検査は、解決済みの `Benitoite.Trait.Show` とそのメソッドの BindingId、組み込みの `Benitoite.IO.Process.exit` の名前だけを、独立入力の `class:7`・`meth:9`・`prim:8` に付け替える。そのうえで、表層の処置・ヘッダ・dictParams と期待コアを厳密に比べる。別のクラスや別の exit が出れば、付け替えられずに不一致になる。Show のクラスの最初のメソッドが `meth:{show}` であることも assert している。局所の `show`・`exit` という名前で選び直さないことも、入力の 1 と 3 で確かめている。
- **Request の所有と取り消し（B10-2）**: `ReturnToExecutor` の時点で、要求ごとに `own_exit_report` を呼び、所有した文字列を `Request.die_failure` に入れる。`serve_inner` では、まず `take()` で取り出し、なければ Direct として所有する。停止理由に移すのは、`state.stopping.is_none()` で、かつ code が 1 のときだけである。このため、先に採用された終了・Internal・Interrupt に情報を転記しない。要求が取り消されたときは、情報も要求と一緒に捨てられる。二重に移す経路も、失う経路も見つからなかった。テストは、待機中に報告のレジスタを空にして GC を行う場合、Task.race で取り消した要求を再配送する場合、二つのタスクの順序、`run_program` の RunEnd を、両方の方式で比べる。
- **Show の追加（B10-3）**: 四つの実装は、型のモジュールの中に引数名 `x` で置いてあり、message をそのまま返す。孤児規則により、利用者はこれまでもこの四型の実装を書けなかった。このため、重複などで既存の利用者コードが壊れることはない。表示の変化は、それまで E0705 だった `show` を新たに受理することだけである。golden の差分は d7 の副位置の 12 行だけである（R59）。
- **テストが弱められていないか**: assert の削除、期待の緩和、ignore の追加は見つからなかった。変更は次のとおりである。
  - `info.ret ==` を `TryActionInfo::Return { ret }` との厳密な比較に置き換えた。
  - モジュールの数と FIFO の期待を +1 にした。
  - R60 で 58 実装の assert を保ち、62 実装の検査を加えた。
  - R65 で `desugar(..).is_err()` を、脱糖の成功と IR check が空であることの assert に変えた（強めている）。
  - l21・l23 は検査を追加した。
- **規約**: 本番のコードに unwrap・expect・panic・添字は増えていない（`unwrap_or(DiagCode::E0705)` は既定値を返すだけで panic しない）。文言は `diag::codes`（E0511 と各 help）と、`desugar/effects.rs` の `text`（`OPTION_NONE`）・`parser/text.rs`（`DIE_MESSAGE`）にある。`missing_standard` の説明は処理系の不具合の報告なので、表に載せていないのは規約どおりである。Skill の diagnostics.md は codes.rs と一致する。

## 指摘

### 【重大】

1. **B10-3 の後、パイプラインの時間がほぼ倍になった。R64・R66 の「変更前でも再現」は B10-3 の後を基準にしており、退行の出どころを見落としている**
   - 場所: `docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/decisions.md` の R64・R66。b10-3/results.md「起動と静的検査の短い測定」（未計時）。`crates/benitoite/src/prelude/stdlib/{IOError,NetworkError}.bnt` の `import Benitoite.Trait`。
   - 根拠（作業の記録から）:

     | 作業（基準） | `--lib` | random_programs | 全コーパスの書き出し |
     |---|---|---|---|
     | B9 | 74.09 秒 | 49.42 秒で合格 | 563.84 秒 |
     | B10-1 | 74.14 秒 | 3 スイートで合格（107.98 秒） | 563.88 秒 |
     | B10-2（c4bfba01） | 74.14 秒 | 3 スイートで合格（107.55 秒） | 562.409 秒 |
     | B10-3（aea63249） | 156.13 秒 | **走らせていない** | 787.808 秒 |
     | B10a-1 | 155.50 秒 | 121.9 秒で失敗 | 784.352 秒 |
     | B10a-2 | 158.21 秒 | 121.07 秒で失敗 | 783.130 秒 |
     | B10a-3 | 158.99 秒 | （再実行なし） | 785.203 秒 |

     R64 の「変更前の HEAD」`d2ac950e` は B10-3 の取り込みのコミットである。この基準で 123.066 秒だったことは、B10a-1 が原因でないことを示す。しかし、B10-3 が原因でないことは示さない。B10-3 の本番の変更は、標準ソースの 4 ファイルの import と実装だけである。その結果、prelude の IOError・NetworkError から Trait（526 行、58 実装）を、すべてのプログラムが読み込み、型検査するようになった。三つの時間が同時に約 1.4〜2.1 倍になったことは、この変更と整合する。並行作業による機械の負荷だけでは、B10-3 の後に毎回同じ水準で再現することを説明しにくい。
   - 問題:
     - 利用者のすべての `benitoite run`・`check` の起動が遅くなった疑いが強い（「短気」の目的に反する）。
     - random_programs は san_benito で失敗したままであり、check.sh も通らない見込みである。
     - B10-3 の完了条件の起動の測定は計時されておらず（R62）、B10 の親の完了確認もできない。
     - R64 と R66 は「変更前から再現」として未達を持ち越しており、原因の記録が誤っている。
   - 意見: 記録から見る限り、「変更前後で差がない」とは言えない。B10a-1〜3 の間に差がないことまでは言えるが、B10-2 → B10-3 の間で random_programs が 60 秒未満から約 122 秒に増えた可能性が高い。
   - 修正案:
     1. 同じ機械・同じ負荷の条件で、`c4bfba01` と `d2ac950e` の random_programs と、最小の入力の `run`・`check` を比べる（benchmark スキル。b10-3/measure_startup.py を使う）。B10-3 が原因かを確かめる。
     2. 確かめられたら、設計者に対策を諮る。案を二つ挙げる。
        - IOError・NetworkError の Show の実装を Trait モジュールへ移す（孤児規則ではクラスのモジュールにも置ける。二型は組み込みの型なので、Trait からの import は要らない）。Json・Csv は、import されたときだけ読む今の形のままにする。こうすれば、prelude が Trait を常に読まなくなる。design.md「標準ライブラリ」の「型のモジュール内に置く」の変更になる。
        - 標準モジュールの検査の結果を使い回すなどして、Trait の検査の費用そのものを下げる。
     3. R64・R66 を「B10-3 の後を基準とした比較であり、B10-3 による退行の疑いがある」と直す。時間の制限は緩めない。

### 【中】

2. **B10a-2・B10a-3・B10-2 の後に古くなった記述が設計書に残っている**
   - 場所と問題:
     - `docs/design/02-impl/02-05-typechecker.md:327`「Die の脱糖は未接続の InternalError とする」。B10a-2 で脱糖を接続した。
     - `docs/design/02-impl/02-06-ir-and-lowering.md:157`「交換出力の Die はまだ拒否する」。B10a-3 で交換器へ接続した。
     - `docs/design/02-impl/02-07-bytecode.md:59`「現在は実行への接続前であり、報告付きの命令を VM で実行すると内部エラーになる」。G5a の指摘 1 のうち、まだ残っている箇所である。B10-2 で Request も接続したので、両方の方式で食い違う。
   - 修正案:
     - 02-05 は「Die の脱糖は 02-06『内部の終了報告』に従う」に直す。
     - 02-06 の最後の文は「交換器はクレート内部のテスト入口の Die を corpus 10 へ書き出す（07-04）」に直す。
     - 02-07 は 02-08「IO の命令」を参照する記述に揃える。

3. **01-12 に Rust の交換器の記述が戻った（G4 の L3 の対応を打ち消している）**
   - 場所: `docs/design/01-spec/01-12-core-calculus.md:780` の後半「Rust の交換器も内部の報告の付加情報をコアから除き、…本番 parser はまだ Die を拒否する。」
   - 問題: AGENTS.md では、`01-spec/` に処理系の実装方式に依存する記述を入れない。G4 の L3 では、交換と Rust への接続の状況を 07-04 に集めると合意した。同じ内容は、07-04:131 と 07-04:206 にすでにある。文頭の「である。 Rust」には余分な空白もある。
   - 修正案: この 3 文を 01-12 から除く（「交換と処理系への接続は 07-04 に従う」の参照は既にある）。

4. **共通の関門 K の check.sh と gc-stress の構成を、五つの作業のどれも走らせていない（G5a の指摘 2 と同じ）**
   - 場所: b10-2〜b10a-3 の各 results.md の末尾。
   - 問題: G5b の完了条件には K が含まれる。どの作業も、lib・関係する統合テスト・clippy・check-formal は通している。ただし、check.sh の選択の検査と gc-stress は未実行である。指摘 1 により、random_programs は失敗した状態にある。
   - 修正案: 指摘 1 を片付けた後、G5 を閉じる前に、オーケストレータが `scripts/check.sh --dry-run` で選ばれる検査を確かめ、gc-stress の構成とあわせて実行して記録する。設計者への事前の知らせは、AGENTS.md「テストの運用」に従う。

### 【軽】

5. **本番で受理しない `or die` が、公開の診断の説明と Skill に出ている**
   - 場所: `crates/benitoite/src/diag/codes.rs` の E0218・E0509 の説明文と E0511。`crates/benitoite/skill/references/diagnostics.md:399-405, 1670-1697`。
   - 問題: 説明文（`benitoite explain` と、実行ファイルに埋め込む Skill）が、`or die` を使える構文のように読める。Skill を読んだ LLM が `or die` を書くと、E0201 になる。design.md の 248 行目と B10a-1 の触るファイルの欄には沿っている。一方、B6 の「die の案内は B11 の受理と同時に有効にする」という方針とは、時期がずれている。
   - 修正案: B11 より前にリリースしないことを確かめておく。あるいは、説明文の die の部分だけを B11 で加える形に戻す。どちらにするかを設計者が決める。

6. **内部依存の抽出が専用の走査を新しく持ち、見つからない場合を黙って無視する**
   - 場所: `crates/benitoite/src/modules/internal.rs:51`（`Stmt` を `_ => {}` で受ける）。`crates/benitoite/src/modules/load.rs:316`（`stdlib.iter().find` が `None` のときは何もしない）。
   - 問題:
     - B6 の確認表にある走査（`typeck/consts.rs` の `visit_expr` など）と重複する、三つ目の式の走査である。`Stmt` の新しい種類が増えたときに、漏れをコンパイラが知らせない。
     - 標準モジュールの名前を取り違えたときは、診断を出さずに辺が欠ける。その結果は、型検査の `missing_standard`（処理系の不具合）として現れる。
   - 修正案:
     - `Stmt::Error(_)` を明示して網羅的に分解する。可能なら既存の走査を共有する。
     - 見つからないときは、処理系の不具合として報告する（B11 で本番に入る前に直す）。

7. **交換のテストの一時ディレクトリが、前の回の残りで失敗しうる**
   - 場所: `crates/benitoite/tests/desugar_export/lib.rs` の `std::fs::create_dir(&directory).unwrap()`（名前はプロセス番号と添字）。
   - 修正案: 先に `remove_dir_all` を試してから作る。または、既存の一時ディレクトリの補助を使う。

8. **文の中に余分な半角空白がある**
   - 場所: `docs/design/03-interop/03-07-io-modules.md:37`「返す。 `IOError` と」。01-12:780（指摘 3）。
   - 修正案: 空白を除く。

9. **利用者向けリファレンスに、四型の Show が書かれていない**
   - 場所: `docs/reference/benitoite.md`（825 行目付近の標準クラスの説明）。
   - 問題: 03-06・03-07・03-08 には反映済みである。しかし、英語のリファレンスには、IOError などを `Trait.Show.show` で表示できることが書かれていない。design.md の文書の表に従って B12 で扱う予定なら、問題はない。
   - 修正案: B12 の文書の更新の一覧に、この項目を明記する。

## 確かめていないこと

- ビルド・テスト・時間の実測（記録の数値だけで判断した）。
- refinterp と VM の exit_report_tests の全行の中身。主な表と、削除行が置き換えられていることだけを確かめた。
- formatter の印字と検証（`roles/walk.rs`・`verify.rs`）の細部。
- routing-manifest.json の 1,736 件。版の 9 → 10 だけが変わったことは、統計と B10a-3 の記録で確かめた。


## 対応

1. Z7: 設計者の2026-10-16の決定に従い、IOError・NetworkError の Show を Trait へ移して prelude からの import を除いた。Trait から各 message を呼べ、循環はない。R64・R66 に原因を追記し、R71・design.md・03-06〜03-08 と読み込みの期待を更新した。lib は77.21秒、random_programs は50.18秒で成功した（各ビルド込み82.18秒、53.54秒）。60秒制限・入力数・coverage は維持した。
2. Z7: 02-05 の未接続の記述を現行の脱糖への参照へ直した。02-06 の交換出力と02-07 の両 IO 方式の記述は、Z7 開始時点ですでに接続済みの説明であることを確認した。
3. Z7: 01-12 から Rust の交換器・テスト入口・本番 parser の3文を除き、07-04「道具と置き場所」に表示辞書を含む保持対象を揃えた。
4. Z7: `scripts/check.sh` と gc-stress の構成の検査は、B14 でオーケストレータが実行して記録する。Z7 では実行しない。
5. Z7: リリースは段3の後（M の段の最後）であり、B11 の本番受理より前に公開することはない。
6. Z7: 内部依存の抽出の Stmt を全場合で明示し、標準モジュールが見つからない場合は読み込みの内部エラーとして報告する。
7. Z7: 交換テストの一時ディレクトリ名に OS の乱数を加え、同じプロセス番号・添字の前回の残りと衝突しない名前にした。
8. Z7: 03-07 の余分な空白を除いた。01-12 の空白を含む記述は指摘3とあわせて除いた。
9. Z7: 四型の Show と message をそのまま返す契約を `docs/reference/benitoite.md` に追記する作業を、plan.md の B13 に明記した。

検査の記録（2026-10-16、既定構成）:

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib modules::tests::prelude_order_kinds_and_clock_dependency`（標準ソースの修正前） | Trait の不在を要求する assert で失敗し、退行を捕まえることを確認 |
| `cargo test -p benitoite --lib modules::tests`（修正後） | 29件成功、1.95秒 |
| `cargo test -p benitoite --lib` | 1,191件成功、既存の ignore 21件、77.21秒。`/usr/bin/time -p` の実時間82.18秒 |
| `cargo test -p benitoite --test random_programs` | 3件成功、50.18秒。ビルド込み実時間53.54秒。既存の60秒制限のまま成功 |
| `cargo test -p benitoite --test golden --test runtime_builtins --test spec_examples --test skill_docs --test desugar_export --test l21_json --test l23_csv` | 7スイート・45件成功、既存の ignore 1件、64.55秒 |
| `cargo run -p benitoite --example gen_skill` | 再生成成功、生成物の差分なし |
| `cargo clippy --all-targets` | 成功、指摘なし |
| `cargo fmt --check` | 成功 |

テストの作成時の関門: 読み込みの公開の結果で「Trait を使わない入力から Trait を読まない」契約を確認し、prelude の import が戻る退行を捕まえる。表示の契約は既存の runtime_builtins・Json/Csv の統合検査、辞書の対応は既存の型検査のテストで確認した。本番の差し込み口・依存の差し替え・新しいテストは増やしていない。テストの削除・ignore の追加・条件の緩和はなく、配置に依存する期待の変更理由は R71 に記録した。

本番の変更は28行追加・23行削除、テストは17行追加・13行削除である。formal/ の定義・証明・入力には触れていないため、`lake build` は実行していない。`scripts/check.sh` と gc-stress は指摘4のとおり B14 に残す。B13 の英語リファレンスへの追記と、M の段の最後での公開も計画どおりである。
