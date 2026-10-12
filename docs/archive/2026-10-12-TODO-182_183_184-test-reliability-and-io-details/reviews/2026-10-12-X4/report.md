# 作業 X4 のレビュー（コミット 7f23a2ec）

対象: `git show 7f23a2ec` の本番コード（`file.rs`）、テスト（`resource_tests.rs`）、文書（01-10・02-09・03-07・言語リファレンス・CHANGELOG）。照らし合わせたもの: plan.md「作業 X4」、decisions.md の Q3・Q4・R4〜R6・R13、実装者の報告 X4-report.md。関連する `runtime/io/resources.rs`、`vm/state.rs`、`vm/unwind.rs`、`process.rs`、`prelude/stdlib/IO/File.bnt` も読んだ。指示に従い、cargo は走らせず、ファイルも変えていない。

## 所見

### 1.【推奨】Writer の欠けを、言語の IOError として返すようになった
- 場所: `crates/benitoite/src/builtins/funcs/file.rs:1190-1193`（`FileWriter::write`）
- 問題: `writer` が `None` で `failure` も `None` という、起きないはずの状態を、`IoFailure`（種類 `Other`、文 `"File.Writer buffer missing during release"`）としてスクリプトへ返している。変更前は、`writer_work` の `.and_then(|writer| writer.0.as_mut())` がこの状態を `Stop::Internal` にしていた。
  - AGENTS.md「失敗を panic で表さない」は、型検査を通ったプログラムで起きない状態を、実行中は `Stop::Internal` で返すと定めている。今回の形はこの規約に反し、処理系の不具合をスクリプトが扱える IO の失敗に変えてしまう。
  - 文の「during release」も、書き込みの経路では当たらない。
  - 今の経路では到達しないので、振る舞いの退行は起きていない。
- 修正案: `writer_work` の閉包の中で、`failure` がなく `writer` が `None` なら `Stop::Internal(format!("{function} requires File.Writer"))` を返す。`FileWriter::write` は、`writer` があることを前提にするか、戻り値を `Result<Result<(), IoFailure>, Stop>` にする。

### 2.【推奨】`with` の中の `closeWriter` が取り消されたときの扱いが決まっていない（既存の振る舞い。docs/todo の項目にする）
- 場所: `docs/design/01-spec/01-10-resources.md:82`、`crates/benitoite/src/vm/unwind.rs:166-176`（`ReleaseStart::AlreadyReleased` の分岐）、decisions.md R6
- 仕組み: 報告にあった、`with` の版が Direct で `ReleaseFailed "fake flush failure"` になった結果は、次の流れで説明できる。
  1. `closeWriter` が `request_release` で状態を `Releasing` にし、`StateWait::Resource` で待つ。
  2. 待つ間にタスクが取り消され、`with` の解放の枠が `unwind_release` を呼ぶ。`request_release` は `InProgress` を返し、枠は `WaitReason::Release` で待つ。
  3. 解放の仕事が終わると、`finish_release` が失敗を `release_failure` に置く。
  4. 枠が起きて `request_release` を呼び直すと `AlreadyReleased` になる。`take_release_failure` が、`closeWriter` の呼び手が受け取るはずだった失敗を取り出し、取り消しの解放の失敗として報告する。
- 判定:
  - X4 の変更によるものではない。X4 は `FileWriter` しか変えておらず、このテストは偽の `open_failing_writer` を使う。`release_failure` は、解放を待った側のうち先に取りに来た方が受け取る仕組みであり、既にあった振る舞いである。
  - ただし R6 の理由（「`close` を呼んだリソースは解放済みとみなし、その失敗は `close` の結果としてだけ報告する」「`with` の規則とは対象が違い、矛盾しない」）とは食い違う。`with` で束縛したリソースでは、`close` の失敗を `with` が自分の解放の失敗として報告しているからである。
  - 一方、今の振る舞いにも理がある。取り消しの解放の失敗は実行時エラーにするという 01-10「解放の失敗」の第一段落に合い、設計原則 1（失敗を落とさない）にも沿う。どちらを選ぶかは、設計の判断である。
  - Request モードは確かめていない。モードによって振る舞いが変わる可能性も残る。
- 今の文書の正しさ: 01-10 の新しい一文を「`with` で束縛していないリソース」に限ったのは、今の実装と合っており正しい。既存の【方針】「解放済みのリソースを `with` がもう一度解放することはない」も、文字どおりには守られている（`with` は解放をもう一度行わず、失敗を拾うだけである）。
- 修正案: 今は処理系を直さない。docs/todo に項目を一つ加える。
  - 項目の内容: `with` で束縛したリソースで、`close` の待ちが取り消されたときの失敗を、`with` の解放の失敗として報告するか捨てるかの決定。両モードの再現テスト（X4 で外した `with` 版の筋書き）。`release_failure` の受け取り手を、待つ側ごとに区別するか。
  - decisions.md R6 には「`with` で束縛したリソースでは今は ReleaseFailed になる（docs/todo の TODO-nnn）」と注記し、「矛盾しない」の主張の範囲を限る。

### 3.【推奨】標準ライブラリの `closeWriter` の文書が、失敗の状態と合わない
- 場所: `crates/benitoite/src/prelude/stdlib/IO/File.bnt:69`
- 問題: `/// Writes out what was written and closes the writer. A with binding closes it in the same way.` とあり、失敗の状態では書き出さずに記録した失敗を返すことが書かれていない。`write`・`writeLine`・`writeChunk`（51〜56 行）にも、失敗の後に同じ失敗を返すことが書かれていない。同梱の Skill の標準ライブラリの参照は、この文書から作られる。LLM が書き手であるので、言語リファレンスだけに書いても届かない。
- 修正案: `closeWriter` と三つの書き込み関数の `///` に、それぞれ 1 文足す（例: "After a write fails, returns that error without writing." / "After a write failed, closes without writing and returns its message with `IOErrorKind.Other`."）。同じ変更で `cargo run -p benitoite --example gen_skill` を実行し、Skill の参照を作り直す。

### 4.【軽微】`with` の解放の失敗の理由を、空でないことしか確かめていない
- 場所: `crates/benitoite/src/builtins/funcs/file/resource_tests.rs:697`
- 問題: `close = false` の版は `!failures[0].reason.is_empty()` しか確かめていない。03-07 の「記録した失敗と同じ文を返す」は、`with` の解放の経路では固定されていない。たとえば、`release` が失敗の状態で別の文（`WRITER_BUFFER_MISSING` など）を返す退行を捕まえられない。
- 修正案: 書き込みの失敗の文をスクリプトから得るのは難しい。代わりに、同じ読み取り専用のファイルに対する書き込みの失敗の文（`EBADF` の `to_string`）を Rust の側で作って比べるか、少なくとも `WRITER_BUFFER_MISSING` と違うことを確かめる。

### 5.【軽微】`failed_writer_discards_buffered_data_before_release` が非公開の欄に頼っている
- 場所: `resource_tests.rs:441-473`（特に 464〜465 行）
- 問題: 観察できる部分（`closeWriter` が同じ文を返し、ファイルが `original` のまま）は、1 本目のテストと同じである。変更前のコードとの違いを捕まえるのは、`writer.writer.is_none()` と `failure` の欄だけである。test-audit の「非公開の状態で重ねて確かめる」に近い。ただし、読み取り専用のファイルでは解放の結果から破棄を区別できず、移植性のある一時的な書き込みの失敗（`/dev/full` は Linux だけ）もない。そのため、コメントのとおり残す理由は立つ。
- 修正案: 今のまま残してよい。欄の名前を変える作り直しで壊れることを、関門のコメントに一言足すと親切である。

## 確かめて問題がなかった点

- **バッファの破棄**: 失敗の状態に入るすべての経路で、`BufWriter` を drop せずに `into_parts()` で解体している。
  - `write`・`writeLine`・`writeChunk` と、`write_all` の中で起きる書き出し（バッファが満ちたときの `flush_buf`）の失敗は、`FileWriter::write` の `Err` の分岐を通る。`BufWriter::write_all` の中の書き出しの失敗も、この `Err` に含まれる。
  - 正常な状態の `release` が `flush` に失敗したときも、`into_parts()` で捨てる。
  - `Drop` は、残った `writer` を `into_parts()` で捨てる。失敗の状態では `writer` が既に `None` なので、何もしない。
  - `release` は `failure.take()` の後に `Err` を返す。その後の `Drop` では `writer` が `None` であり、二重の書き出しは起きない。
- **書き込みの失敗の種類**: `IoFailure` に `Clone` を加え、記録した `kind`・`reason` をそのまま返す。1 本目のテストが、3 関数 × 3 関数の組み合わせで、種類と文の一致を確かめている。
- **`closeWriter` の種類と文**: 失敗の状態の `release` は `failure.reason` を返す。`close_writer` の既存の処理が、それを `IO_ERROR_KIND_OTHER` で包む。R4 と 03-07 のとおりである。`with` の解放は `begin_release` を通り、`ReleaseFailed` になる。02-09 の追記のとおりである。
- **実行の終わりの破棄**: 束縛の文の未解放の Writer は、`close_all_silently` と `Drop` を通り、書き出されない。03-07 に足した 3 点目の記述と合う。
- **03-07「Process」の追記**: `collect_output` が EOF まで読むこと、`runAttached` が `process_stdio` に従うこと、02-09「タスクの待ちと取り消し」の「`Task.withTimeout` で `Process.run` を取り消しても、子プロセスは動き続ける」、02-09「リソースの追跡」の、実行の終わりに外部の操作を待たないことと合っている。言語リファレンスの「A timeout does not stop the started processes.」も合う。
- **R5 の出典**: Rust の `File` の文書には、閉じるときの誤りを `Drop` が捨てるとある。主張はリンク先の範囲に収まっている。
- **CHANGELOG**: 未公開の版の「Some functions and commands also behave differently」の表に、移行の方法と一緒に加えてある。「Before, ... the buffered data was written again on the next flush」は、変更前の `BufWriter` の振る舞い（`flush_buf` の失敗の後もバッファが残る）と合う。
- **テストが変更前のコードで失敗するか**:
  - 1 本目は、変更前には小さな書き込みが `Ok` を返して落ちる。報告で一度確かめてある。
  - 3 本目の `close = false` の版は、変更前には空のバッファの書き出しが成功して `Finished(Ok)` になり落ちる。`close = true` の版は、`closeWriter` が `Ok` を返して落ちる。
  - 取り消しのテストは、R6 の既存の振る舞いを固定するもので、計画どおりである。
- **テストの大きさ**: どのテストも 20,000 バイトの固定の大きさで、ループの回数も固定である。時間に頼る待ちはない（筋書きと `hold_release` で順序を決めている）。
- **規約**:
  - 本番コードに `unwrap`・`expect`・添字はない。
  - `Stop::Internal` の説明に関数の完全な名前を入れており、`text` に載せない扱いは AGENTS.md「文言」のとおりである。
  - コメントは日本語で、設計書の節を `（設計書 03-07「File」）` の形で引いている。作業の ID は引いていない。
  - テストの関門のコメントもある。本番コードに、テストのためだけの差し込み口は足していない（`FileWriter::new` は本番でも使う）。
- **文書の書き方**: 01-10・03-07 の追記は常体で、【決定】の後に「理由:」を 1〜2 文で書いている。01-spec の追記に、実装の方式に依存する記述はない。02-09 の追記は、03-07 の「File」へ正しくリンクしている。

## 判定

取り込みはそのままでよい（要修正の所見はない）。失敗の状態の本体（バッファの破棄、種類と文の保持、`closeWriter` が返す `Other`、`with` の解放の失敗）は、計画・判断・文書と合っており、正しい。

後の小さな直しとして、所見 1（起きないはずの状態を `Stop::Internal` に戻す）と所見 3（`File.bnt` の文書と Skill の参照の作り直し）を勧める。所見 2 の `with` と取り消された `closeWriter` の振る舞いは、X4 より前からある振る舞いで、設計の判断を要する。今は処理系を直さず、docs/todo の項目として残し、decisions.md R6 に範囲の注記を足すことを勧める。所見 4・5 は任意である。
