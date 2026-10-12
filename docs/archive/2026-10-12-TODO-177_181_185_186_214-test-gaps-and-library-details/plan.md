# 実装プラン

作業は直列に進める。どの作業も、メインの作業ディレクトリで作業ごとのブランチ（`mod/<作業>`）の上で Codex（GPT-6.1-Sol、high）が実装し、終えたらすぐ `san_benito` に取り込む。レビュー（Opus）は取り込んだコミットを `git show` で読み、直しは後のコミットで行う。作業ごとには関係するテスト・回収の強制の構成の関係するテスト・clippy・fmt だけを走らせ、`scripts/check.sh` と性能の短い測定は最後に一度だけ行う。設計書・言語リファレンス・CHANGELOG の未リリースの節・`gen_skill` の生成物は、各作業が同じ変更で直す。テストを加えるときは、スキル `test-audit` の作成時の関門を通し、退行のテストは直す前のコード（または一時的に壊したコード）で落ちることを確かめて報告に書く。

各作業の内容は `study.md` の部と節で示す（「214 部 4 節」は「TODO-214 の調査」の部の 4 節）。部の中の推奨と `decisions.md` が違うときは、`decisions.md` を正とする。以下の `$GCS` は次の機能の指定を表す（`scripts/check.sh` の「gc-stress (mark-sweep)」と同じ構成）。zsh では語に分かれないので、機能の指定をそのまま書く。`cargo test` は `--` の前にフィルタを一つしか受け付けないので、二つ以上は `--` の後に書く。

```sh
GCS='--no-default-features --features gc-mark-sweep,heap-verify,gc-stress'
```

どの作業の完了の条件にも、最後に次を含める（以下では省く）。

```sh
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo fmt --all --check
```

VM の命令の振り分けと呼び出しの経路を変える作業はないので、fib・loop の短い測定（`tools/bench/gate.py`）は最後に一度だけ行う。

## 作業 Y1: `with` の解放の失敗の固定（TODO-214、Q1・R12）

214 部の 6 節の「作業 Y214」のとおり。点 3（02-08 の文を直す）は了承済み（R12）。本番のコードは変えない。

完了の条件:

```sh
cargo test -p benitoite --lib builtins::funcs::file::resource_tests
cargo test -p benitoite $GCS --lib builtins::funcs::file::resource_tests
cargo test -p benitoite --lib vm::dispatch::tasks::tests::cancellation
```

## 作業 Y2: 取り消された `close` の失敗を捨てる（TODO-214、Q5）

214 部の 2.4 節の筋書きを、`with` で束縛していないリソースについて、Direct と Request の両方で再現するテストを先に書き、後の `close` が `Result.Error` を返すことを確かめる（当てはまらなければ、作業を止めて結果を報告する）。当てはまったら、取り消された `close` の失敗を、そのリソースがどの `with` の枠にも束縛されていないときに限って記録から消し、後の `close` が `Ok` を返すようにする。`with` で束縛したリソース（同じタスクの枠でも、別のタスクの枠でも）は Y1 のとおり枠が報告する。直し方は 214 部の 5 節の点 1 の「代替」を出発点にし、リソースが `with` で束縛されているかを、枠を辿らずに分かる形（リソースの記録の印など）にできるかを先に調べる。01-10「解放の失敗」と 02-09 の該当の文を、直した振る舞いに合わせる。CHANGELOG の Fixed に書く。

完了の条件:

```sh
cargo test -p benitoite --lib -- builtins::funcs::file::resource_tests runtime::io::resources vm::dispatch::tasks vm::dispatch::unwinding vm::dispatch::resource
cargo test -p benitoite $GCS --lib -- builtins::funcs::file::resource_tests runtime::io::resources vm::dispatch::tasks
cargo test -p benitoite --test open_062 --test runtime_builtins
```

## 作業 Y3: ゴールデンテストの実行器（TODO-181、R2）

181 部の「作業の分け方の案」の W3 と W4（6・7・8 (a)・9 節）。外した件数は R2 のとおり集計のファイルに書く。

完了の条件:

```sh
cargo test -p benitoite --test golden -- --nocapture
cargo test -p benitoite --test random_programs
BENITOITE_GOLDEN_FILTER=lines cargo test -p benitoite --test golden -- --nocapture
BENITOITE_GOLDEN_FILTER=testdata/fmt cargo test -p benitoite --test golden
```

## 作業 Y4: 参照インタプリタの変換の費用（TODO-181、Q8・R1）

二つのコミットに分ける（オーケストレータが、Codex の報告の後に分けてコミットする。Codex は変更を二つの段に分けて報告する）。

1. 段 1: 181 部の 1 節の (A)（要る根だけを読み、回収を予算に従わせる）と、2 節（R1。`RefValue` に呼び出しの番号を持たせる）。
2. 段 2: 181 部の 1 節の (B)（変換の結果を値の同一性で覚える）。`EXPENSIVE_REFERENCE_CASES` から `list_hof_long` を一時的に外して差分比較を走らせ、時間を測って報告する（`BENITOITE_GOLDEN_FILTER=list_hof_long`。30 分を超えたら止め、それまでの観察を報告する）。段 1 だけの時間も、同じ方法で 5 分まで測る。`EXPENSIVE_REFERENCE_CASES` は元に戻しておく。

段 2 を採るかと、07-03 に外す理由を書くかは、測った結果を見て設計者が決める（Q8）。

完了の条件（段 1 と段 2 の両方の後で）:

```sh
cargo test -p benitoite --lib refinterp::
cargo test -p benitoite --test golden
cargo test -p benitoite --test random_programs
cargo test -p benitoite $GCS --lib refinterp::
```

## 作業 Y5: 参照インタプリタ・段ごと・CLI のテストと testdata の細部（TODO-181、R3）

181 部の W2・W5・W6（3・4・5・8 (b)・10・11 節）。相対パスの program のゴールデンと "1 orders" は扱わない（R3）。

完了の条件:

```sh
cargo test -p benitoite --lib -- refinterp:: ir::desugar:: pipeline::tests::checking_sorts_each_stage_and_stops_before_later_errors
cargo test -p benitoite --test golden --test cli_process
python3 tools/spec-coverage/spec_coverage.py
python3 tools/spec-coverage/spec_coverage.py --self-test
```

## 作業 Y6: 永続マップの木と文献（TODO-185、R4・R5）

185 部の 11 節の作業 A と、1.5 節の設計書の文（R4）。

完了の条件:

```sh
cargo test -p benitoite --lib -- runtime::map runtime::list
cargo test -p benitoite $GCS --lib -- runtime::map
```

## 作業 Y7: Map・Set の組み込みの関数と、Json・Decimal・Bytes の細部（TODO-185、Q7・R6〜R8・R13）

185 部の 11 節の作業 B と作業 D。Json の入力の終わりの誤りの位置は Q7（案 a）。03-06 の「（docs/todo の TODO-185）」（`Bytes.slice` の共有の表現）は「（docs/todo の TODO-218）」に直す（R13）。

完了の条件:

```sh
cargo test -p benitoite --lib -- builtins::funcs::map builtins::funcs::set builtins::funcs::json builtins::funcs::decimal builtins::funcs::bytes
cargo test -p benitoite $GCS --lib -- builtins::funcs::map builtins::funcs::set
cargo test -p benitoite --test l21_json --test skill_docs
cargo test --test spec_examples
cargo run -p benitoite --example gen_skill
```

## 作業 Y8: Csv（TODO-185、Q2）

185 部の 11 節の作業 C。

完了の条件:

```sh
cargo test -p benitoite --lib -- builtins::funcs::csv
cargo test -p benitoite --test l23_csv --test skill_docs
cargo run -p benitoite --example gen_skill
```

## 作業 Y9: `Assert` の書き出しの上限（TODO-186、Q3）

186 部の「作業の分け方の案」の作業 A。

完了の条件:

```sh
cargo test -p benitoite --lib runtime::assert
cargo test -p benitoite $GCS --lib runtime::assert
cargo test -p benitoite --test test_command --test reference_examples
BENITOITE_GOLDEN_FILTER=testdata/test/ cargo test -p benitoite --test golden
```

## 作業 Y10: フォーマッタの空の行（TODO-186、Q6）

186 部の作業 B。`BlankBefore` を変えることは設計者が了承した（Q6）。

完了の条件:

```sh
cargo test -p benitoite --lib cli::tools::formatter
BENITOITE_GOLDEN_FILTER=testdata/fmt/ cargo test -p benitoite --test golden
cargo test -p benitoite --test fmt_command
```

## 作業 Y11: CLI の小さな直しと `skill install` の HOME（TODO-186、Q4・R9〜R11）

186 部の作業 C と作業 D。

完了の条件:

```sh
cargo test -p benitoite --lib cli::tools
cargo test -p benitoite --test fmt_command --test test_command --test skill_docs
```

## 最後に行うこと（オーケストレータ）

1. fib・loop の短い測定（`tools/bench/gate.py`、取り出した前の版と交互）。
2. `scripts/check.sh --base eb8dac11 --dry-run` で選ばれる検査を設計者に知らせてから、`scripts/check.sh --base eb8dac11` を走らせる。
3. docs/todo で TODO-177・181・185・186・214 を閉じ（残りがあれば項目に残し）、R13 の TODO-218〜220 を加える。
4. 改造のディレクトリを `docs/archive/` へ移す。
