# 作業 X3 のレビュー（コミット 5cce6ec7）

指示どおりファイルは変えておらず、cargo も走らせていない。読んで確かめた範囲は次のとおり。コミットの差分、plan.md「作業 X3」、decisions.md の Q1・Q2・R1〜R3、依頼文（事前点検の補足を含む）、実装の報告、test-audit、02-09・02-10・03-07・CHANGELOG・`diag/codes.rs`・`runtime/report.rs` の該当する箇所。要修正の所見はない。

## 所見

1. **軽微** `docs/2026-10-12-TODO-182_183_184-test-reliability-and-io-details/decisions.md`（末尾の +8 行）
   - 問題: 追記した R13 は作業 X4 の事前点検の判断（失敗した `File.Writer` を `with` で解放するときの扱い）であり、X3 の内容ではない。それが X3 のコミットに入っている。コミットメッセージの「record decision R13」も、X3 で決めた判断のように読める。実装担当は、このファイルを編集していないと報告している。オーケストレータが作業中に追記し、取り込みのときに一緒に入ったものと見られる。
   - 修正案: 履歴は直さなくてよい。X4 のコミットメッセージか X4 のレビューで「R13 は 5cce6ec7 に先に入った」と一言残し、経緯を追えるようにする。

2. **軽微** `crates/benitoite/src/builtins/funcs/process/external_tests.rs:604-621`（`oversized_output_is_drained_before_reporting_input_limit`）
   - 問題: コメントと時間切れの文言は、読み捨て（`io::copy`）が壊れると「満杯のパイプで子が止まる」前提で書いてある。しかし今の `execute` では、パイプは閉包に移されており、`collect_output` が返ると閉じる。読み捨てを消す現実的な退行では、子は止まらず SIGPIPE で終わる。テストは止まりではなく、`assert_eq!(output.status.code(), Some(0))` で落ちる（`sh` が `head` を exec すれば `None`、しなければ `Some(141)`）。退行は捕まえられるが、落ちたときの手がかりがコメントと合わない。時間切れの経路が捕まえるのは、パイプを開いたまま読まない、という別の退行である。
   - 修正案: コメントを「読み捨てを止めると子は SIGPIPE で終わるか、パイプを開いたままなら止まる」の趣旨に直す。終了状態の assert に「上限の後も読み捨てて子が正常に終わるはず」という文言を添える。新しい契約を守るテストであり、修正の退行テストではないので、失敗の確認は必須ではない。それでも一度、`io::copy` を外して終了状態の assert で落ちることを見ておくと確実である。

3. **軽微** `crates/benitoite/src/builtins/funcs/console/tests.rs:173-208`（`remaining_input_checks_byte_limit_before_building_value`）
   - 問題: 判定の本体は `check_input_size` であり、`file/tests.rs` の表の形のテストも同じ関数を通る。このテストに独自の価値があるのは、`remaining_input` が受け取った `limit` を判定へ渡すことを確かめる点だけである。test-audit の「共有の補助の処理を、使う側ごとに繰り返し確かめるテスト」に近い。計画が置くと定めたテストなので、残してよい。
   - 修正案: コメントの 2 行目を「受け取った上限を判定に渡す配線を確かめる」の趣旨に絞り、守る契約を明確にする（任意）。

4. **軽微（以前からある）** `docs/design/02-impl/02-09-runtime.md:254`
   - 問題: 「読む大きさが決まっていない入力を読む操作」の一覧に `Process.runAttached` がない。`attached_done` は同じ `check_output` を通り、03-07 の 211 行も同じ上限を当てると書いている。X3 で入った食い違いではないが、この節を直した機会に気づいた。
   - 修正案: 一覧の `Process.run`・`Process.shell` を `Process.run`・`Process.runAttached`・`Process.shell` にする（後の作業でもよい）。

## 確かめて問題がなかった点

### 一行の読み取りの数え方（上限を L とする）
- `read_line_limited` は `take(L+2)` で読み、`complete_line` は LF を一つ、続けて末尾の CR を一つ除いてから `check_input` する。次の分け方はどれも正しい。
  - `L` バイトの内容に LF または CRLF が続く行は通る。
  - `L+1` バイトの内容に LF が続く行は止まる。
  - LF のないまま入力の終わりに達した場合、`L` バイトなら通り、`L+1` バイトなら止まる。`abcd\r` で終わる場合は CR を除いて通り、03-07 の規則と合う。
  - 行の途中の CR は内容として数える。`abcd\r\r\n` は `abcd\r\r` で切れ、CR を一つ除いても 5 バイトなので止まる。
- `take` で切れたとき（LF なしで `L+2` バイト）は、CR を一つ除いても `L+1` 以上残るので、必ず止まる。上限を超えた行の残りを黙って次の行として返す経路はない。
- 保持するのは最大 `L+2` バイトである。`Vec` の容量が倍々に増える性質は、以前の `L+1` と変わらない。

### 退行の検出
- 表の形のテストを直す前の実装で走らせると、`abcd\r\n` と `abcd\r` が落ちる（`L+1` で読み、行末を除く前に判定していたため）。報告でも一度失敗を確かめている。
- 読む量だけを `L+1` に戻す部分的な退行も捕まえる。`abcd\r\r\n` が `abcd\r` で切れ、CR を除いて通ってしまい、テストが落ちる。

### まとめた判定の関数と呼び出し元
- `check_input_size(len, limit, unit, function)` を一つ置き、次の箇所がこれを通る。
  - File: `check_input`、`readLines` の行の数。
  - Console: `remaining_input`、`readAllLines` の行の数。
  - Process: `check_output`（標準出力と標準エラー出力の二回）。
- 本番の呼び出しは、どれも `MAX_STRING_BYTES` を渡す。行の数は `MAX_LIST_LEN` を渡す。
  - `read_all_limited`: `read_limited`、`read_bytes_job`、Console の `readAll` と `read_remaining`、`collect_output`。
  - `read_line_limited`: File と Console の両方。
  - `complete_text` と `complete_line`: 完了の関数の中で渡す。
  - `execute`: run・runAttached・shell。
- 大域の値も `cfg(test)` の分岐もない。完了の関数のシグネチャも変わっていない。
- 境界は以前と同じである。行の数は `> MAX_LIST_LEN` で止まり、`CheckedLen::check` と一致する。

### 振る舞いの変化
- 振る舞いが変わったのは、決めた二点だけである。
  - Q1・R3: readLine の数え方。
  - Q2・R2: `readLines` と `readAllLines` の行の数の超過が R0902（`ValueTooLarge`）から R0903（`InputTooLarge`）になった。
- R0903 の報告は "`…readLines` read more than the limit of 16777216 elements" になる。`listDirectory` と `walk` の書き方と同じであり、単位が elements の場合は `report.rs` の既存のテストが確かめている。
- `ValueTooLarge` の報告が持っていた size の注記はなくなるが、R0903 の形として妥当である。
- 診断の表の文は行の数にも当てはまるので、`gen_skill` を走らせなかったことは正しい。

### テスト
- 二つの既存のテストの期待を `InputTooLarge`（`limit: MAX_LIST_LEN`、`..` なし）に直してある。
- Process のテストについて。
  - `head -c` と `/dev/zero` は macOS（BSD の head）にも Linux にもある。
  - 1 MiB はパイプの容量（約 64 KiB）より十分大きい。
  - 30 秒の時間切れで有限に終わる。
  - `stdout.len() == 17` で、`L+1` で読みやめたことを確かめている。
  - 時間切れのときにスレッドと子が残っても、テストのプロセスが終われば SIGPIPE で片付く。

### 文書
- 02-09 の 255 行（`L+2` まで読むこと、行末の定義、理由）と 256 行（項目の数も R0903 にすること）は、コードと一致する。
- 03-07 の 58 行の追記も一致する。
- 01-08 と 02-10 は、変えなくても食い違わない（02-10 の 114 行は「入力を読む操作は R0903」と書いている）。
- CHANGELOG の Fixed と Changed の文は、コードと一致する。R0902 から R0903 への変更は、スクリプトが受け取る値を変えない。そのため、Incompatible changes ではなく Changed に置いたのは、計画どおりで妥当である。

### 規約
- 新しいコメントは日本語で、作業の ID や TODO の番号を含まない。
- 本番のコードに `unwrap`・`expect`・添字はない。Process のテストの `expect` は `unwrap_or_else` に直してある。
- 新しい文言はない。`process.rs` の import の整理と、不要になった `CheckedLen`・`ResourceError` の import の削除は正しい。
- 参照インタプリタは同じ `BuiltinDecl` と完了の関数を通り、別の上限を持たない。変えなかった判断は正しい。

### 付随の小さな直し
- `codegen/tests.rs` と `sched/testing.rs` のコメントの直しは、X2 のレビューの指摘どおりである。

## 判定

取り込みを維持してよい（要修正なし）。所見の 1〜4 はどれも軽微で、後の作業（X4 など）でまとめて直せばよい。報告によると、golden の `testdata/network/` の 10 件は sandbox の中で `Operation not permitted` により走っていない。sandbox の外での再実行の結果を、オーケストレータの記録で確かめておくこと。
