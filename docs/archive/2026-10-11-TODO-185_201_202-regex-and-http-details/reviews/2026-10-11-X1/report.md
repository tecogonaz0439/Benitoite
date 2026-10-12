# X1（886aac9）のレビュー

一番重いのは所見 1 です。期限のテストは退行を捕まえておらず、作り直す必要があります。正しさについて、新しい関数とループは regex の反復と同じ結果を返します（細かい確認は所見 2）。そのほかは小さな所見です。

## 1. 【直す】`regex_find_all_times_out_between_matches` は直す前の版でも通る

場所: `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs` 1654〜1676 行（コメントは 1654〜1655 行）

**直す前の版でも通る理由**
- 仮想時間を進める `Advance` は、`ScriptWorkers::try_recv` → `advance()` が消費します（`runtime/sched/testing.rs` 366〜401 行）。`try_recv` は `io::boundary` の完了の取り込み（`vm/dispatch/tasks/io.rs` 639 行）から呼ばれます。
- `tasks.rs` の `boundary`（139 行〜）では、この `io::boundary` が先に走ります。そのため、時計を読む処理（`monotonic_millis`）と `expire_timers` が、同じ境界の中で、進めた後の時刻を見ます。
- 直す前の版の流れは次のとおりです。
  1. `PickTask(1)` で子が選ばれ、一つの `PRIM` の中で `findAll` を全部終えます。
  2. `cancel::deliver`（`cancel.rs` 312〜321 行）は、期限の判定を後に回して親を `pending_timeouts` に入れます。
  3. 次の境界で `Advance(10)` が読まれ、時刻が 10 になります。期限は 0+10 なので `expire` が `timed_out` を記録し、`None` が配送されます。
- これは同じファイルの `timeout_discards_a_child_result_completed_at_or_after_the_deadline` が守っている、期限と同時かその後に終えた子の結果は捨てる、という契約そのものです。
- `picks == [1]` と `consumed == 2` も、どちらの版でも同じです。
- コメントの「全件を一つの組み込みで探す退行では Some が返る」は誤りです。

**直し方の案**（子が予算で一度切り替わって ready に戻った後に時間を進める。あわせて、子が最後まで走らなかったことを副作用で確かめる）

```rust
let source = r#"
import Benitoite.Unofficial.Regex
import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit, String] uses Clock.Time, State
  bind p <- try Regex.compile("a")
  bind input <- String.repeat("a", 20000)
  bind finished <- Reference.new(false)
  bind result <- Task.withTimeout(10, lambda()
    bind n <- List.length(Regex.findAll(p, input))
    Reference.set(finished, true)
    return n
  end lambda)
  return if result = Option.None and not Reference.get(finished) then Result.Ok(()) else Result.Error("regex timeout") end if
end function
"#;
let (step, record) = run(source, 1000,
    vec![ScheduleStep::PickTask(1), ScheduleStep::PickTask(1), ScheduleStep::Advance(10)]);
assert_eq!(step, VmStep::Finished(MainOutcome::Ok));
assert_eq!(picks(&record), [1, 1]);
assert_eq!(record.consumed, 3);
```

**直す前の版では失敗する**
- 子は一回の実行で終わるので、二つ目の境界で `PickTask(1)` を選べません。
- picker が `None` を返し、`task picker refused ready tasks`（筋書きの誤り）になります。
- 仮に選べても、時刻 0 で `pending_timeouts` が判定されて `Some` が返ります。

**直した後は通る**
- 子は一致ごとに 4 回ほど関数を呼ぶので、20,000 個の一致で約 80 回切り替わります。
- 二回目の切り替えの境界で `Advance` が読まれて期限が切れ、子は `restore` → `cancel::begin` で止まります。
- そのため `finished` は false のままです。

**`finished` の印を入れる理由**
期限が切れると `timed_out` が立ち、子が最後まで走っても `None` になります。印がないと、「一致の間で切り替わるが、取り消しが効かない」という退行を捕まえられません。

**別の書き方**
`check_timeout_after_child_runs` と同じく `test_boundary` の仕掛けを使う方法もあります。子（serial 1）が一度選ばれた記録があり、かつ ready にいる境界でだけ、`allow_time(10)` と `advance_time()` を呼びます。この形なら、直す前の版は結果が `Some` になって失敗し、筋書きの誤りではなく結果の違いで落ちます。

**直した後の確認**
直した後のテストも、5f43e75 の 4 ファイルに戻した版で失敗することを確かめてください。

## 2. 正しさ（直す所見なし）

**空の一致の探し直し**
- regex-automata 0.4.18（Cargo.lock の版）の `Searcher::try_advance` は、次の条件で 1 バイト先から一度だけ探し直します（`util/iter.rs` 433 行・676 行）。
  - 条件: `m.is_empty() && Some(m.end()) == last_match_end`
- `afterMatch` が真のとき `start` は直前の終わりなので、`retry_start` の条件 `range == Some((start, start))` はこれと同じです。
- 文字の途中の空の一致は報告されず、空でない一致も文字の境目からしか始まりません。このため、次の文字の境目から探しても結果は同じです。
- 入力の終わりでは regex も `is_done` で終わるので、`None` も一致します。

**開始の位置の確かめと panic の回避**
- `search_start`（265 行）は、負の数・長さ超え・文字の境目でない位置を `Stop::Internal` にします。
- そのため `find_at` / `captures_at` の panic の条件（`start >= len + 1`）には届きません。
- 探し直しの位置も `chars().next()` で求めるので、長さを超えません。

**ループ（Regex.bnt 66〜97 行）**
- `splitFrom` は meta の `Split::next`（`meta/regex.rs` 2237 行）と同じ形です。一致があれば `[last..m.start)`、なくなれば `[last..len)` を最後に一度だけ返します。空の入力、先頭・終わりの空の一致、多バイト文字の表の期待値も保たれています。
- `replaceAll` は `replacen(…, 0, NoExpand)` と同じ順で部分をつなぎます。
- `replaceAllWith` は、一致ごとに左から一度ずつ `f` を呼びます。直す前は全一致を先に求めてから呼んでいたので、`f` と探索が交互になる点は変わりました。呼ぶ順と回数は同じです。

**累積バイト数による早期の上限検査（107〜109 行）**
- `1073741824` は `MAX_STRING_BYTES` と同じ値です。
- 超えた時点では全体の長さが上限を超えているので、外側の `String.join` が必ず止めます。
- 未使用の束縛を消す最適化は処理系にありません（ir と bytecode を検索して確かめた）。

**compile の誤りの切り詰め**
- 上限は 4,096 バイトを超えません。
- `while !is_char_boundary` は 0 で必ず止まります。

## 3. 計算量（直す所見なし）

- `List.append` は RRB 木で、葉一つ（32 要素以内）と道筋だけを写します。
- `List.length` は頭の欄を読むだけです。
- 部分は 4,096 個ごとのまとまりで `String.join` するので、各バイトを写すのは二回です。
- 組み立ては一致の数と入力の長さに対して 2 乗になりません。
- ただし、一致ごとに確保が増えます（`Option`・`Pair` と、`appendPart` 二回分の `Pair` 4 個）。直す前の組み込みと比べてどれだけ遅くなるかは、まだ測っていません。プランの「最後に行うこと」2 の短い測定で確かめてください。

## 4. 【直すとよい】そのほかのテストの穴

1. **`position_searches_preserve_context_and_retry_empty_matches`（tests.rs 385〜400 行）【直すとよい】**
   - `afterMatch=true` で、開始の位置から空でない一致が始まる行がありません（例: `("a*", "aaa", 0, true, Some((0, 3)))`）。
   - 「`afterMatch` なら開始の位置の一致をどれでも捨てる」という退行を、単体では捕まえられません。スクリプトの `[ab]` on `aba` の名前付きグループの行が間接に捕まえますが、表に一行足すのが安上がりです。
2. **`compile_errors_omit_long_patterns_and_keep_the_reason` 464〜469 行【直さなくてよい】**
   - 短い文面を、regex クレートの表示の形の字面で固定しています。クレートを更新すると壊れます。
   - `::regex::Regex::new("(").unwrap_err().to_string()` と比べれば、「短い文面は変えない」という契約だけを確かめられます。
   - 最後の行を文字の境目で切る枝は、regex の誤りの最後の行が短いため、実際には通りません。守りの処理として残してよいです。
3. **`appendPart` の 2^30 の早期検査と、`findAll`・`split` の 2^24 で止まる経路【直さなくてよい】**
   - どれもテストがありません。大きさの理由で移さないことは、事前点検で受け入れています。
   - 定数 `1073741824` が `MAX_STRING_BYTES` と食い違っても気づけません。docs/todo に「標準ライブラリのソースの上限の定数を処理系の定数と突き合わせる」を残すことを勧めます。
4. **SIGINT のテスト【直さなくてよい】**
   - 直す前の版で失敗することを確かめ済みで、作りも妥当です。

## 5. 規約（どれも直さなくてよい）

1. **regex.rs 120 行【直さなくてよい】**
   - `ERROR_LIMIT`（数値）が `text` のモジュールに入っています。`text` は文言の定数を置く場所なので、`compile_error` の近くの普通の `const` に移すのが筋です。軽い所見です。
2. **regex.rs 229〜253 行の `replace`【直さなくてよい】**
   - `replaceFirst` 専用になりましたが、`find_iter(text).take(1)` のループと `count` の計算が残っています。`pattern.find(text)` で書けばずっと短くなります。振る舞いは正しいです。
3. **regex.rs 332 行の `DECLS` のコメント「末尾以外には加えない」【直さなくてよい】**
   - 今回は途中の項目を消したので、コメントの前提と合いません。番号を固定するテストもゴールデンテストもないことは確かめ済みで、消すことは事前点検で認めています。
   - 番号を外へ保存する経路がないなら、そのままでよいです。
4. **規約に反するものはない**
   - `unwrap`・`expect`・添字・`as` はありません（`unwrap_or_default` は lint の対象外）。
   - `#[allow]` の追加もありません。
   - コメントは日本語で、設計書の節を引いており、作業の ID も書いていません。
   - `Stop::Internal` の説明の文字列は、`text` に置かなくてよい扱いです。

## 6. 文書（直す所見なし。CHANGELOG の空行だけ直すとよい）

1. **CHANGELOG.md 40 行【直すとよい】**
   - 新しい 2 項目と既存の項目の間に空行があり、Markdown では一つのリストが段落の空いたリストになります。空行を消してください。
2. **03-08（155〜159 行）は実装と合っている**
   - 合っている点: 非公開の `findAt`・`spanAt`、空の一致の規則、一致の間で中断と取り消しが効くこと、4,096 部分ごとの結合、`List.append`・`String.join` の名前、2^30 での早期の結合の試み、切り詰めの形（見出し・印・最後の行）。
   - 引いている 02-08「タスクの切り替え」と 02-09「一つの操作で作る値の大きさの上限」は、見出しが実在します。
   - 用語の「捕獲グループ」は同じ章の既存の語と揃っています。
3. **CHANGELOG 38〜39 行も実装と合っている**
   - 報告の関数の名前が変わることは、事前点検の決定のとおり Fixed に一言添えてあります。

## 推奨のまとめ

- 直す: 所見 1（テストの作り直しとコメントの訂正）。
- 直すとよい: 所見 4 の 1（表に一行足す）、所見 6 の 1（CHANGELOG の空行）。
- 直さなくてよい: そのほか（所見 4 の 2〜4、所見 5）。

レビューの対象は 886aac9（作業 X1）です。コードは `git show` で読み、ファイルは変えず、cargo も走らせていません。
