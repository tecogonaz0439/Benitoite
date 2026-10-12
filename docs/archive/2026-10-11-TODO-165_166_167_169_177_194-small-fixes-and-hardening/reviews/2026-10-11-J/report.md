# 作業 J（TODO-194）のレビュー

- 対象: git worktree の `impl/TODO-194-J`（基準 61c32e5、コミットしていない変更）。`Cargo.toml`・`Cargo.lock`・`crates/benitoite/src/builtins/funcs/json.rs`・`crates/benitoite/tests/desugar_export.rs`・`crates/benitoite/tests/desugar_export/exchange.rs`・`crates/benitoite/testdata/network/todo194-json-parse-server.*`。
- レビューした人: Claude（Opus 5.5）。2026-10-11。レビューした人の道具が書き込みを拒んだので、返答の全文をオーケストレータがこのファイルに写した。
- 結論: **直すべき 1 件（所見 1）を直してから取り込む。** 特殊なキーの不具合は直っており、外部の入力で `Stop::Internal` や panic に至る経路は見つからなかった。数の字面の対応がずれた入力でも、誤った値を黙って返すことはなく `Result.Error` になる。ただし、範囲外の数を含まない構文の誤りの一部が「number out of range」と報告されるように変わった。この変化は Q2 が受け入れた範囲の外にある。

## 確かめたこと

- 特殊なキー: `{"$serde_json::private::Number":"1e9999"}` と `{"$serde_json::private::RawValue":"1"}` が object のまま読めることを CLI で確かめた。基準の処理系では、前者が処理系の不具合（`unchecked JSON number`）で止まる。
- serde_json の有効な機能: `cargo tree -e features -i serde_json` で、`default`・`std`・`float_roundtrip` だけが有効であることを確かめた（`arbitrary_precision` と `raw_value` を有効にする依存はない）。
- 書式化: serde_json 1.0.151 では、`arbitrary_precision` のときの `Number::from_f64` も、ないときの `Display` も、同じ `zmij::Buffer::format_finite` で書く（`src/number.rs` の 183 行と 350 行）。`Json.stringify` が書く Float の文字列は変わらない。
- 境目の入力（CLI で実行し、基準と変更後を比べた）: `-0`→`0`、`[-0.0e-0]`→`[-0.0]`、`1 2`→1:3 trailing characters、`[01]`・`[-]`・`[1.]`・`[1.0e]`→invalid number（基準と同じ）、BOM の前置→1:1 expected value、BOM の後置→1:4 trailing characters（基準と同じ）、`[1e400,}`→1:2 number out of range（Q2 の変化）。
- 字面の対応: serde が文書を受け付けたとき、文字列の外にあるのは構造の文字・空白・`true`/`false`/`null`・数だけである。走査は `-` か数字でだけ数を始める。文字列の中は `\` の次の 1 文字を読み飛ばしながら閉じの `"` まで進むので、`\"`・`\\`・`"` のどれも閉じと取り違えない。このため、文書が正しいときは字面の一覧と `visit_*` の呼び出しが一対一に対応し、誤った値を返す入力はない。ずれが起きるのは構文の誤りを含む入力だけで、そのときは所見 1 のとおり誤り（`Result.Error`）になる。
- サーバのゴールデン: この環境で TCP を開けたので、`BENITOITE_GOLDEN_FILTER=todo194-json-parse-server cargo test --test golden` を worktree で走らせ、通った（1 件）。同じスクリプトを基準の処理系で実行すると、最初の POST で処理系の不具合（`unchecked JSON number`）になる。直す前に落ちることも、これで確かめた。
- 交換形式: `BENITOITE_DESUGAR_DIFF_DIR` を `target/` の下に向けて、基準と変更後の両方で `export_desugar_corpus` を走らせた（各 8 分半）。新しいゴールデンのファイルがコーパスに入るので ID がずれ、バイト列は一致しない。そこで四つの出力ファイルすべてについて、次の 4 点を確かめた。Python で読み直し、鍵を整列した詰めた形（`separators=(',',':')`・`ensure_ascii=False`・`sort_keys=True`）で書き直した列が元の列と一致すること。`mantissa` の値がすべて JSON 整数であること。2^63 を超える整数が両方で 4000 個あること。浮動小数点数がないこと。書き出しの形は変わっていない。Lean の側（`formal/Benitoite/Exchange/Syntax.lean` の `decimal`・`negDecimal`）は `mantissa` を `Int` として読むので、読み手への影響もない。比較に使った出力は消した。
- Cargo.lock: パッケージの数は 110 で変わらない。

## 所見

### 1. 範囲外の数がない構文の誤りを「number out of range」と報告する

- 重さ: 直すべき
- 場所: `crates/benitoite/src/builtins/funcs/json.rs` の `number_lexemes`（115 行〜。数を読み進める条件は 137 行の `matches!(c, '0'..='9' | '.' | 'e' | 'E' | '+' | '-')`）。
- 問題: 走査は、数を JSON の数の文法ではなく `[0-9.eE+-]` の連なりで切る。一方 serde は、数を読み終えるとすぐに `visit_*` を呼び、続く字句はその後で確かめる。このため、数の直後に `-`・`+`・`.`・`e` が続く構文の誤りでは、`number_value` がつながった字面（`1-2` など）を分類できず、数の始まりの位置で `NUMBER_OUT_OF_RANGE` が返る。CLI で確かめた例を示す。

  | 入力 | 基準 | 変更後 |
  |---|---|---|
  | `[1-2]` | 1:3 expected `,` or `]` | 1:2 number out of range |
  | `[1+2]` | 1:3 expected `,` or `]` | 1:2 number out of range |
  | `[1.5.5]` | 1:5 expected `,` or `]` | 1:2 number out of range |
  | `{"a":1e5e5}` | 1:9 expected `,` or `}` | 1:6 number out of range |
  | `[1,2-]` | 1:5 expected `,` or `]` | 1:4 number out of range |
  | `[1E+2-3]` | 1:6 expected `,` or `]` | 1:2 number out of range |
  | `["\\",1-2]` | 1:8 expected `,` or `]` | 1:7 number out of range |

  どの入力も範囲外の数を含まない。Q2 が受け入れたのは、構文の誤りと範囲外の数がどちらもある入力で先の誤りを報告する変化だけであり、この変化は含まれない。誤った値は返さないが、診断の第一の読み手である LLM を、数を小さくするという誤った直しへ導くおそれがある。
- 直し方の案: 数の読み取りを JSON の数の文法（`-`? (`0` | `[1-9][0-9]*`) (`.` `[0-9]+`)? (`[eE]` `[+-]`? `[0-9]+`)?）で止める。こうすると `1-2` の走査は `1` で止まり、serde が `-` で構文の誤りを返すので、基準と同じ誤りになる。文法に合う数の直後には構造の文字か空白しか来ないので、文書が正しいときの対応は変わらない。上の表の入力のいくつか（`[1-2]`・`[1.5.5]`・`{"a":1e5e5}`）を `parse_errors` の表に加え、期待（行・列・文言）を基準と同じにする。

### 2. 字面の一覧をすべて先に集める

- 重さ: 直すとよい
- 場所: `json.rs` の `number_lexemes`（115 行〜）と `NumberState::lexemes`。
- 問題: 字面の一覧を `Vec<NumberLexeme>` に集めてから解析する。字面一つは 32 バイト（`&str` と、位置を表す二つの `usize`）で、`Vec` の倍々の伸びを含めると最大 64 バイトになる。`[0,0,0,…]` のような数の多い入力では、入力 1 バイトあたり 16〜32 バイトが、材料の木とは別に要る。基準の `arbitrary_precision` も数ごとに `String` を確保していたので、増え方は 2 倍以内と見積もる。それでも、減らせる確保である。
- 直し方の案: 走査を `Iterator<Item = NumberLexeme>` にし、`Peekable` で包んで遅延で読む。serde の範囲外の誤りで使う「次の字面の位置」（`peek`）も、読み終えた後の余りの確かめも、そのまま書ける。

### 3. serde を直接依存にすると、ビルドするクレートが一つ増える

- 重さ: 直すとよい（どちらを選ぶかは判断でよい）
- 場所: `crates/benitoite/Cargo.toml` の 32 行（`serde = "=1.0.229"`）。
- 問題: serde_json 1.0.151 が実際に依存するのは `serde_core` である。`serde` は `[target."cfg(any())".dependencies]` にしか書かれておらず、どの対象でもビルドしない。基準では `cargo tree -i serde` が「nothing to print」になり、`serde` クレートはビルドされない。この変更で Cargo.lock の集合は変わらないが、ビルドするクレートは一つ増える。ライセンスは `serde` も `serde_core` も `MIT OR Apache-2.0` で、ライセンスの検査には響かない。版の固定の書き方（`"=x.y.z"`）は、ほかの依存と揃っている。
- 直し方の案: `serde_core = { version = "=1.0.229", default-features = false }` を直接依存にし、`use serde_core::de::…`・`serde_core::ser::…` と書く（`serde_core` は `de` と `ser` を公開している。`crate_root.rs` の 136・138 行）。依存のクレートを増やさないことより `serde` という通常の名前を優先するなら、今のままでよい。その場合は、ビルドするクレートが増えることを報告に書く。

### 4. 読み終えた後に字面が余ったときの誤りが、行 0 を報告する

- 重さ: 記録だけ
- 場所: `json.rs` の 40 行（`if numbers.lexemes.peek().is_some()`）。
- 問題: この誤りは `Deserializer` の外で `de::Error::custom` から作るので、serde の位置が行 0・列 0 になる。`error_position` も `None` なので「line 0 column 1」と報告され、03-08 の「1 から数える」に反する。ただし「確かめたこと」の字面の対応の論証のとおり、文書が正しければ一覧と呼び出しは一致する。このため、この分岐には届かないと見る。
- 直し方の案: 余った字面の位置（`peek` した `position`）を使う。届かない分岐として扱うなら、その旨のコメントを置く。

### 5. serde の範囲外の誤りを文言の比較で見分ける

- 重さ: 記録だけ
- 場所: `json.rs` の 54 行（`reason == text::NUMBER_OUT_OF_RANGE`）。
- 問題: serde_json の `ErrorCode::NumberOutOfRange` の表示（`error.rs` の 366 行の `"number out of range"`）が自前の文言と同じであることに頼っている。serde_json の公開の API は誤りの種類を `Category` までしか示さないので、ほかの書き方はない。版を `=1.0.151` に固定しているので、今は正しく動く。
- 直し方の案: serde_json の版を上げるときに確かめる箇所として、この前提をコメントに書く。

### 6. 交換形式の `mantissa` の書き換えが鍵の名前に頼る

- 重さ: 記録だけ
- 場所: `crates/benitoite/tests/desugar_export/exchange.rs` の 32 行。
- 問題: `ExchangeJson` は、どの深さでも、鍵が `mantissa` で値が文字列のメンバを `i128` の整数に書き換える。今の交換形式で `mantissa` の鍵を作るのは `decimal` と `negDecimal` だけであり、書き出しの形が変わらないことは「確かめたこと」で確かめた。しかし、後で別の意味の `mantissa` を鍵に持つ形を加えると、黙って書き換わるか、書き出しが失敗する。
- 直し方の案: 今のままでよい。気になるなら、仮数を `{"$i128": "…"}` のような印付きの材料にし、書き出しのときに印で見分ける。

### 7. 形式化の検査と coverage_export の書き出しを、まだ走らせていない

- 重さ: 記録だけ
- 場所: `crates/benitoite/tests/coverage_export.rs`（549〜551 行の往復の確かめ）、`scripts/check-formal.sh`。
- 問題: 実装者が走らせた `cargo test --test coverage_export --test desugar_export` では、`formal` の印が付いた二つの書き出しのテストは `#[ignore]` で走らない。`desugar_export` の書き出しは、このレビューで形が変わらないことを確かめた。`coverage_export` の書き出しには Decimal も浮動小数点数も現れないので、`arbitrary_precision` を外しても往復の確かめ（`roundtrip == corpus`）は保たれると見る。ただし、走らせて確かめてはいない。
- 直し方の案: 取り込みの前に、オーケストレータが `scripts/check-formal.sh` を走らせる（`coverage_export` と `desugar_export` を `--include-ignored` で含む）。

### 8. 再帰と材料の木の深さ

- 重さ: 記録だけ
- 場所: `json.rs` の `Visitor` の `visit_seq`・`visit_map` と `JsonMaterial` の破棄。
- 問題: serde の `Visitor` の入れ子の呼び出しと、`JsonMaterial` の木の破棄（自動の `Drop`）は再帰する。深さは serde の上限 128 で止まり、基準の `serde_json::Value` の破棄も同じく再帰していた。言語の値への変換（`convert`）は今までどおり明示の積み重ねで書かれており、AGENTS.md「再帰の深さ」に反しない。
- 直し方の案: なし。

## テストの質（test-audit）

- `special_number_key_remains_an_object` は公開の関数（`parse`・`stringify`）の境界で確かめており、関門のコメントもある。実装者は、値が `"123"` の場合に直す前に落ちることを確かめた。
- サーバのゴールデンは、既存の `routes-and-post.bnt` の書き方（印・関門のコメント・`.mode`・`.exit`・`.stdout`）と揃っている。直した後に通り、直す前に落ちることは、このレビューで確かめた。
- `export_preserves_decimal_mantissas_as_exact_json_integers` は既定で走り、`arbitrary_precision` を外したときの退行（大きな `i128` の拒否と、Float への丸め）を捕まえる。
- 今のテストには、所見 1 の変化を捕まえる行がない。所見 1 を直すときに、`[1-2]` などで基準と同じ誤りを期待する行を加える。

## 規約

- `unwrap`・`expect`・添字は、テストの外にない。`number_lexemes` の `input.get(start..end).unwrap_or("")` は文字の境目で切るので、空にならない。仮に空になっても、範囲外の数の誤り（`Result.Error`）になるだけである。
- 新しい文言（`INVALID_NUMBER`・`JSON_VALUE`）は `text` に置いてある。`JSON_VALUE` を使うのは `expecting` だけで、`deserialize_any` がすべての型を受け付けるので、実際に使われる経路はない。
- コメントは日本語で書かれ、理由と設計書の節を示している。
