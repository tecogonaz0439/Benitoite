# Y7 のレビュー

対象: cf6a79b1「Check collection lengths before allocating and settle Json, Decimal, and Bytes details」（44f23209 で san_benito に取り込み）。`git show` だけで読み、cargo は走らせていない。

## 全体の所見

計画（plan.md 作業 Y7）、decisions.md の Q7・R6〜R8・R13、study.md の 185 部 4〜6・9・10 節の具体案のとおりに実装している。要修正は、03-08 に足した位置の規則の一文が、範囲外の数の誤りの位置と食い違う 1 点だけである。

確かめた点:

- **CheckedLen が確保の前か**: `Map.toList`・`Map.keys`・`Map.values`・`Set.toList` の四つとも、本体の最初の文で `CheckedLen::elements(u64::from(map_len/set_len(..)?), name)?` を呼ぶ。`map_to_vec`・`set_to_vec` の `Vec` と、`Map.toList` の `Pair` の確保より前にある。`Tree::len`（runtime/map/tree.rs:42）は根のノードの欄を読むだけなので、確かめの前に走査や確保は起きない。関数の名前は報告用の名前と一致している。builtins の中で Map・Set の要素をリストへ集める関数は、この四つのほかにない（`Json.stringify` の `map_to_vec` は文字列を作る経路で、範囲の外）。
- **Json の入力の終わりの位置**: `Category::Eof` は serde_json 1.0.151（Cargo.lock の版）の `EofWhileParsingList`・`Object`・`String`・`Value` だけで（error.rs:53-61）、どれも入力をすべて読んだ後にしか起きない。したがって位置を入力全体から計算してよい。
  - 多バイト文字: 列は `chars().count()` なので文字で数える（`"é` が 1・3。バイトで数えると 4 になり、テストが捕まえる）。
  - CR LF: 行は LF だけで数え、`rsplit('\n')` の最後の断片は空なので `[1,\r\n` は 2・1。03-08 の「行の区切りは LF だけ」と合う。
  - 空の入力: `rsplit` は空の断片を一つ返すので 1・1。空白だけの入力 `   ` は 1・4。
  - ほかの誤りへの影響: 分岐の順は Data → 範囲外の数（文言の比較）→ Eof → その他で、範囲外の数は serde が入力の終わりより前で止めて Syntax として返すので、Eof の分岐に入らない。`deserializer.end()` の誤りは TrailingCharacters（Syntax）で、これも入らない。Eof 以外の位置の計算（`character_column`）は変わっていない。
  - 計算は誤りのときだけの O(n) で問題ない。
- **Bytes**: `write_integer` の `bytes` は `get(start..)` で長さ `count` に切ってあり、`out` も `CheckedLen::bytes(count)` なので、zip に変えても結果は同じ。テストの `as` 11 か所はすべて `try_from(..).unwrap()` になった。
- **文書と生成物**: Set.bnt の 2 か所の説明と、gen_skill の生成物 `skill/references/stdlib/Set.md` の 2 か所が一字一句一致している。03-06 の TODO-185 → TODO-218 の付け替え（R13）も済んでいる。CHANGELOG の一行は study.md 9.1 の案のとおりで、「Incompatible changes」の behave differently の表に置かれている。01-04 の例（`1.0e21`・`1.5e-7`・`0.1`）は、同じ章の `Float.toString` の規則と、`decimal.rs` のテストの行（`1e21`、追加した `1.5e-7`）に合う。
- **テスト**: Json の表に `[1,`・空・空白だけ・CR LF を足し、`"é` の期待を直した。実装者は直す前にこのテストが失敗することを確かめている。`1e-400`・`-1e-400` は `to_bits` で比べるので 0 の符号まで確かめる。R7 のとおり上限の長いテストは足していない。

## 指摘

### 1. 要修正: 03-08 の「誤りを見つけた文字の位置」が、範囲外の数の誤りの位置と食い違う

- 場所: docs/design/03-interop/03-08-text-and-data.md「Json」の `line` と `column` の箇条（今回足した「誤りの位置は、誤りを見つけた文字の位置である。」）。
- 問題: 範囲外の数（`1e400`）と自前の数の誤りは、数の**最初の文字**の位置で報告する（json.rs のコメント「自前の数の誤りと serde の範囲外の誤りだけ始まりへ戻す」、テスト `("1e400", 1, 1, ..)`・`("[1e400,}", 1, 2, ..)`・`(r#"{"a":1e400,"a":0}"#, 1, 6, ..)`、統合テスト l21_json.rs:151）。範囲外は数を読み終えて初めて分かるので、「誤りを見つけた文字」と読むと数の最後の文字か直後になり、実装・テストと合わない。今回の一文が入る前は位置の規則がなかったので、この食い違いは今回の変更で生じた。01-spec ではないが、03-08 は利用者に見える `Json.ParseError` の契約を定める節である。
- 修正案: 一文を足す。例:「誤りの位置は、誤りを見つけた文字の位置である。ただし、数が `Float` の範囲を超える誤りは、その数の最初の文字の位置とする。入力が途中で終わった誤り（…）は、入力の最後の文字の直後の位置とする。行の区切りは LF だけとする。」CHANGELOG は要らない（振る舞いは変わらない）。

### 2. 推奨: `character_column` のコメントが古くなった

- 場所: crates/benitoite/src/builtins/funcs/json.rs `character_column` のコメント「serde の列はバイトであり EOF では 0 になる。」
- 問題: 今回の変更で、Eof の誤りは `character_column` を通らなくなった。`.max(1)` は今も要るが、理由は別の場合である。serde_json 1.0.151 の read.rs:533 は、文字列の中の制御文字（生の LF など）で `self.index += 1` の後に誤りを作るので、`"a\nb"` のような入力では列 0（次の行）になる。コメントのままだと、後の変更で `.max(1)` を消してよいと読める。
- 修正案: 「serde の列はバイトであり、LF の直後を指すとき（文字列の中の LF の誤りなど）は 0 になる。」に直す。あわせて、Eof の分岐に、serde の位置を使わない理由（serde は最後の文字を指し、LF で終わるときだけ次の行になるため。設計書 03-08「Json」）を一文書くと、分岐の要る理由が読める。

### 3. 推奨: 四つの CheckedLen の行に理由のコメントがない

- 場所: crates/benitoite/src/builtins/funcs/map.rs:40・422・432、set.rs:33。
- 問題: `list::from_values` も同じ確かめをするので、二重に見える。R7 により、この順を守るテストはない（上限の経路は単体のテストにできない）。理由が書かれていないと、後の整理で「重複」として消され、その退行はどのテストも捕まえない。AGENTS.md「コメントと名前」は「なぜ」を書くことを求める。
- 修正案: 各行の前（または四つで共有する補助の関数に分けてその `///`）に、「集める前に確かめる。`from_values` の確かめだけでは、上限を超える数の要素と `Pair` を集めた後で止まる（設計書 02-09「一つの操作で作る値の大きさの上限」）。」の趣旨を書く。

### 4. 軽微: 「行の区切りは LF だけ」を CR だけの入力で確かめていない

- 場所: json.rs `parse_errors_report_character_columns_and_separate_reasons` の表。
- 問題: `[1,\r\n` は LF を含むので、CR を行の区切りとして扱う退行（`lines()` に置き換えるなど）を捕まえられない。`str::lines` は末尾の `\r\n` の `\r` も落とすため、CR LF の行と区別できる入力が要る。
- 修正案: `("[1,\r", 1, 5, "EOF while parsing a value")` を足す。03-08 の新しい一文「行の区切りは LF だけとする」を直接確かめる行になる。

### 5. 軽微: 01-04 の `Decimal.fromFloat` の例が `Option` を省いている

- 場所: docs/design/01-spec/01-04-types-basic.md「型の変換」の表の `Decimal.fromFloat(x)` の行。
- 問題: 型は `function(Float) -> Option[Decimal]` だが、例は「`Decimal.fromFloat(1.0e21)` は小数の桁数 0 の `1000000000000000000000`」と、包む前の値を結果として書いている。同じ欄の先頭の「…を、`Decimal` の値として読んだもの」と同じ省き方なので誤読は起きにくいが、規範の章の例としては厳密でない。
- 修正案: 「（`Decimal.fromFloat(1.0e21)` の中身は小数の桁数 0 の …）」のように「中身」を補うか、括弧の前に「`Option.Some` に包む値の」と一度だけ書く。

### 6. 軽微: Set.bnt の `difference` の説明が 03-06 の一文と揃っていない

- 場所: crates/benitoite/src/prelude/stdlib/Set.bnt の `difference`、03-06「Map と Set（初回リリース版）」の今回足した段落。
- 問題: 03-06 は `Set.difference` の結果の要素も第一の集合の要素であると書くが、Set.bnt（と生成物の Set.md）の `difference` には書いていない。差集合では b の要素が結果に入る余地がないので振る舞いの曖昧さはなく、study.md 5.3 の案も union・intersection だけだったので、計画からの逸脱ではない。
- 修正案: 揃えるなら `difference` に「Each element keeps its form from `a`.」を足して gen_skill で作り直す。揃えないなら対応は要らない。
