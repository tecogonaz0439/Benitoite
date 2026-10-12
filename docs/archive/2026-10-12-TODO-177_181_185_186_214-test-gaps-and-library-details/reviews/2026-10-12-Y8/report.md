# Y8 のレビュー

対象: `fd20edf5`（Limit Csv.formatWith to ASCII separators and document the parser's leniency）。`git show` だけで読み、作業ツリーとビルドには触れていない。csv-core の振る舞いは、手元のレジストリにある csv-core 0.1.13 のソース（`~/.cargo/registry/src/index.crates.io-*/csv-core-0.1.13/src/reader.rs`）で確かめた。`Cargo.lock` と `crates/benitoite/Cargo.toml:25`（`=0.1.13`）の版と一致する。

結論: 要修正の指摘はない。計画（plan.md 作業 Y8、study.md 7.3・8.3、decisions.md Q2）のとおりに実装されており、観点ごとに確かめた結果は次のとおりである。指摘は推奨 2 件、軽微 4 件である。

## 確かめたこと（問題なし）

- **区切りの確かめ**: `delimiter`（csv.rs:66-77）は `ascii` の引数を消し、`"`・CR・LF と ASCII の外を常に `ArgumentOutOfDomain { function, argument: 1 }` で返す。`parse_with` と `format_with` が同じ関数を通るので、誤りの種類と文言は揃う。文言は既存のゴールデン（`l40-csv-invalid-delimiter.diag.json`）と同じく「argument 2 of `Csv.formatWith` is out of range」（R0701）になる。テストは `'"'`・CR・LF・`'、'`・`'é'` を両関数の同じ表で確かめている。
- **ASCII の区切りの往復**: `,`・`\t`・`;`・`|`・`\0` で `formatWith` → `parseWith` の往復を確かめる。`formatWith` が区切りを無視して `,` を書く退行は、`;` などの往復で捕まる。
- **03-08 の寛容さの記述と csv-core の一致**: `transition_nfa`（reader.rs:998-1040）で、`StartField` 以外で始まったフィールド（`InField`）は引用符をそのまま写し、`InDoubleEscapedQuote` で引用符・区切り・行の終わりのどれでもない文字は `InField` に移って写す。したがって `a"b` は `a"b`、`"abc"x` は `abcx` になる。csv-core は誤りを返さないので、誤りは処理系の `Position` が見る「入力の終わりで引用符の中」だけであり、「引用符の使い方で誤りにするのは、閉じていない引用符だけである」も実装と一致する。`Position` の遷移（`AfterQuote` の後の文字は `Plain`、`Plain` の引用符は文字）も csv-core と同じ状態を辿る。足したテストの `"a"b"c` → `ab"c` も、この遷移で説明できる。
- **4 KiB の境界のテスト**: `read_field` は既定で `read_field_dfa`（reader.rs:702-744）を使う。ループの条件が `nout < output.len()` なので、出力が満ちた時点で次のバイトを消費しない。`""` の一つ目の引用符は出力せず（`InDoubleEscapedQuote` へ移るだけ）、二つ目で 1 バイトを出す。これで次が成り立ち、テストのコメントは正しい。
  - k=4096: x を書いて満ち、二重の引用符の直前で切れる。
  - k=4095: 二重の引用符の二つ目で満ち、直後で切れる。
  - k=4094: CR で満ち、LF が次の呼び出しに入る。`previous_cr` の持ち越しを確かめる（実装者は、持ち越しを消すと k=4094 で行の番号が 4 になることを確かめている）。
  - 二重の引用符の間で切れることはない。実装者が報告した事前点検の補足の誤りの指摘は正しい。
  - 行の番号の期待値 3 も正しい。引用符の中の CR LF で 1 行、行の終わりの LF で 1 行進み、続く `"unfinished` が 3 行目に始まる。
- **parseWith の行の番号**: `("a;b\n1;\"x", With(';'), 2, …)` は、`Position::consume` に `,` を渡す退行で `Ok` を返して失敗する（study 8.1 の説明のとおり。実装者も確かめた）。
- **空の行の後の BOM**: `write_csv` の `leading_bom` は出力が空のときだけ真なので、`[[], ["\u{feff}x"]]` は `"\n\u{feff}x\n"` になる。csv-core の `strip_utf8_bom`（reader.rs:610-619）は、最初の呼び出しで入力が BOM で始まるときだけ読み飛ばすので、読み直すと BOM が残る。テストの期待値はこれと一致する。
- **CHANGELOG**: Unreleased の「Some functions and commands also behave differently.」の表に、study 7.3 の案どおりの一行がある。移行の手順に挙げた `String.join` は `String.bnt:53` にある。
- **Csv.bnt と生成物**: `Csv.bnt` の `parseWith`・`formatWith` の `///` と、`skill/references/stdlib/Csv.md` の文は一字ずつ一致する。`docs/reference/` と `docs/ja/` に `formatWith` の区切りを書いた箇所はなく、直す箇所の漏れはない。

## 指摘

### 1. 推奨: 03-08「Csv」の冒頭の「RFC 4180 の CSV を読み書きする」が、新しい箇条と合わない

- 場所: `docs/design/03-interop/03-08-text-and-data.md` の「### Csv」の冒頭（174 行付近）の「【方針】`Benitoite.Csv` は、RFC 4180 の CSV を読み書きする。」
- 問題: 今回の箇条で、RFC 4180 に合わない入力も受け付けることを書いた。行の終わりを LF で書くことも、もともと RFC 4180 と違う。冒頭の文だけを読むと、RFC 4180 に厳密に従うと受け取れる（レビューの観点 4「断定しすぎていないか」）。
- 修正案: 冒頭を「【方針】`Benitoite.Csv` は、RFC 4180 の CSV を読み書きする。RFC 4180 との違い（受け付ける入力と、書く行の終わり）は、下の箇条に書く。」のように直す。

### 2. 推奨: 寛容さの理由に、csv-core の振る舞いの出典を添える

- 場所: 03-08「Csv」の新しい箇条の「理由: 実装に使う `csv-core`（0.1.13）の解析の振る舞いに合わせる。」
- 問題: 外部のクレートの振る舞いを根拠にしているが、出典がない（AGENTS.md「事実と出典」）。振る舞い自体はソースで確かめられ、正しい。ただ、版を上げたときに確かめ直す箇所が文書から辿れない。
- 修正案: 「理由: 実装に使う `csv-core`（0.1.13）の解析の振る舞いに合わせる（`csv_core::Reader` の状態遷移。csv-core 0.1.13 の `src/reader.rs` の `transition_nfa`）。」のように出典を添える。03-01「使う Rust のクレート」に csv-core の行があれば、そこへのリンクでもよい。

### 3. 軽微: 境界のテストが、読み出しの緩衝の大きさ 4096 を数の直書きで前提にしている

- 場所: `csv.rs` の `read_csv` の `let mut buffer = [0u8; 4096];`（175 行）と、テスト `long_fields_preserve_utf8_and_quotes_across_reader_output_chunks` の `for k in 4093..=4097`
- 問題: 緩衝の大きさを変えると、テストは通ったまま境界を試さなくなる。既存の UTF-8 の境界の確かめ（4095）も同じ前提に立つ。
- 修正案: `const READ_BUFFER_LEN: usize = 4096;` を置いて `read_csv` とテストの両方で使い、テストは `READ_BUFFER_LEN - 3..=READ_BUFFER_LEN + 1` の形にする。今回の範囲で直さないなら、そのままでよい。

### 4. 軽微: 境界のテストのコメントの「この入力では」は、一般に成り立つことを狭く書いている

- 場所: 同じテストのコメント「この入力では二重の引用符の間で出力の境界をまたぐことはない。」
- 問題: `read_csv` は入力全体を一度に渡すので、二重の引用符の間で出力が満ちて切れることは、どの入力でも起きない（一つ目の引用符は何も出力せず、満ちた後は次のバイトを消費しない）。「この入力では」と書くと、別の入力ならまたげると読める。あわせて、`Position` が `AfterQuote` の状態を呼び出しをまたいで持つ経路は、今の `read_csv` からは通らない。study 8.1 は「正しく扱えるはず」としていたので、そのことを書いておくと後の読み手が迷わない。
- 修正案: 「一つ目の引用符は何も出力せず、出力が満ちた後は次のバイトを消費しないので、二重の引用符の間で切れることはない（`Position` が `AfterQuote` を持ち越す経路は通らない）。」とする。

### 5. 軽微: 同じテストの中で、BOM の書き方が揃っていない

- 場所: `format_quotes_special_fields_and_round_trips_comma_and_tab` の追加部分 `char::from_u32(0xfeff).unwrap()`。同じテストの既存の行は `"\u{feff}data"` と書く。
- 問題: 同じものを二通りに書いている。`\u` が化ける落とし穴を避けた結果と思われるが、ファイルには既に `\u{feff}` の直書きが通っている。
- 修正案: `"\u{feff}x"` に揃える。化ける心配があるなら、そのままでよい。

### 6. 軽微: 「閉じた引用符の後に区切りか行の終わりが来ないとき」は、続く引用符（`""`）を除いていない

- 場所: 03-08 の新しい箇条の「閉じた引用符の後に区切りか行の終わりが来ないときは、続く文字をフィールドに加える」
- 問題: 引用符の後に引用符が来るときは、上の箇条の `""`（引用符一つ）になり、フィールドは閉じない。今の文を字句どおりに読むと、引用符が来た場合もこの規則に当たる。csv-core の `InDoubleEscapedQuote` の遷移は、引用符・区切り・行の終わりの三つを分けている。
- 修正案: 「閉じた引用符の後に、区切り・行の終わり・引用符のどれでもない文字が来るときは、その文字から後をフィールドに加える（後の引用符もそのまま文字として読む。`"abc"x` は `abcx`、`"a"b"c` は `ab"c`）。」とする。後の引用符の扱いは、テストに足した `"a"b"c` の例でも示せる。
