# T08 組み込み関数: 文字列

- 依存する作業: [T06](T06-values-heap.md)
- 難易度: 3（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/T08-builtins-string

## 目的

`String` モジュールの組み込みの関数（`PureFn`）を実装する。位置と長さを扱う関数は、名前に含む単位（バイトか文字）で位置を数え、正しくない位置では実行時エラーにせず `None` を返す。新しい文字列やリストを作る関数は、結果の大きさを値を作る前に計算し、上限を超えるときは値を作らずに資源の不足で止める。

## 読む設計書の節

- [基本型の意味論](../../2026-09-27-design-initial/01-spec/01-04-types-basic.md)の「String」（位置の二つの単位、位置を扱う関数、正しくない位置、`byteLength` の計算量）と「Char」
- [標準ライブラリ](../../2026-09-27-design-initial/03-interop/03-06-stdlib.md)の「作る値の大きさの上限」「Char」（`isAsciiWhitespace` の文字）「String」（`split` と `lines` の規則と例）
- [ランタイム](../../2026-09-27-design-initial/02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」
- [組み込みの関数](../10-interfaces/10-10-builtins.md)の「prelude のモジュールの関数」のうち `String`、「実装の関数」
- [実行時の値、VM、ランタイム](../10-interfaces/10-08-runtime.md)の「止まる理由」「ヒープ」

## 作るもの

- `src/builtins/string.rs`: 10-10 の一覧の `String` の関数の `PureFn` すべて（`byte_length` から `from_chars` まで）。
- 同じファイルの中のテスト。

## 手順の要点

### 位置と長さ

- `String.byteLength` は `str::len`（長さによらない時間。ADR 0006）。`String.charCount` は `chars().count()`。
- `String.byteSlice(s, start, end)`: `start < 0`、`end < start`、`end > byteLength`、`start` か `end` が文字の境界でない（`str::is_char_boundary` が `false`）ときは `None`。`i64` から `usize` への変換は `usize::try_from` で行い、失敗も `None` にする。
- `String.charAt(s, i)`: `i < 0` か `i >= charCount` なら `None`。`chars().nth(i)`。
- `String.charSlice(s, start, end)`: `start < 0`、`end < start`、`end > charCount` なら `None`。`char_indices` で `start` と `end` の文字位置のバイト位置を求めて切り出す（`end == charCount` のバイト位置は `len`）。
- 結果の部分文字列は元の文字列より小さいので、大きさの上限を確かめなくてよい（02-09 の最後の項目）。

### 検索と判定

- `isEmpty`・`contains`（`sub` が空なら `true`）・`startsWith`・`endsWith` は Rust の `str` の同名の関数と同じ意味である。
- `byteIndexOf(s, sub)` は `str::find` の結果を `Int` にする。`sub` が空なら `Some(0)`。

### 分割と連結

- `String.split(s, sep)`（03-06 の方針のとおり）:
  - `sep` が空でなければ、`str::split(sep)` の結果の並びと一致する（先頭から重ならないように区切る。区切りの前後や連続する区切りの間は空文字列。`s` が空なら `[""]`）。
  - `sep` が空なら、各スカラー値を 1 文字の文字列にした並び。`s` が空なら `[]`。
  - 結果の要素の数を先に数え、`MAX_LIST_LEN` を超えるなら値を作らずに `ValueTooLarge { function: "String.split", unit: Elements, .. }` を返す。要素の文字列はそれぞれ `s` より小さいので、文字列の上限は確かめない。
- `String.lines(s)`: LF で区切り、各行の末尾の CR を一つ取り除く。`s` が LF で終わるとき、その後の空の行は含めない。`s` が空なら `[]`。Rust の `str::lines` は同じ規則だが、行の末尾の CR を LF の直前でなくても取り除く場合があるかを確かめず、LF で分けてから末尾の CR を一つ取り除く処理を自分で書く。要素の数の上限は `split` と同じく確かめる（関数の名前は `String.lines`）。
- `String.join(xs, sep)`: 結果の大きさを「要素のバイト数の合計 + `sep` のバイト数 ×（要素の数 − 1）」として `checked_add`・`checked_mul` で求め、上限を超えるか溢れたら資源の不足（`String.join`、`Bytes`）。要素が文字列でなければ `Stop::Internal`。
- `String.trim(s)`: 先頭と末尾の U+0020・U+0009・U+000A・U+000D だけを取り除く。Rust の `str::trim` は Unicode の空白を取り除くので使わず、`trim_matches` にこの四文字の判定を渡す。
- `String.replace(s, old, new)`: `old` が空なら `s` をそのまま返す（新しい値を作ってよい）。そうでなければ、先に `s.matches(old).count()` で出現を数え、結果の大きさ `len(s) − count × len(old) + count × len(new)` を検査付きの演算で求め、上限を超えれば資源の不足（`String.replace`）。超えなければ `str::replace`。
- `String.repeat(s, n)`: `n <= 0` なら空文字列。`len(s) × n` を `checked_mul` で求め、上限を超えるか溢れれば、文字列を作らずに資源の不足（`String.repeat`）。`s` が空なら、`n` によらず空文字列。
- `String.chars(s)`: 要素の数（`charCount`）が `MAX_LIST_LEN` を超えるなら資源の不足（`String.chars`、`Elements`）。そうでなければ `Value::Char` の並びのリストを `heap.list_from_vec` で作る。
- `String.fromChars(cs)`: 各要素の UTF-8 のバイト数の合計を先に求め、上限を超えれば資源の不足（`String.fromChars`）。要素が `Char` でなければ `Stop::Internal`。

大きさの上限を超えたときの `ValueTooLarge` の `size` は計算した結果の大きさ、`limit` は `MAX_STRING_BYTES` か `MAX_LIST_LEN` である。計算が `u64` で溢れたときは `size` を `u64::MAX` にする。

## 受け入れテスト

- 位置: `s = "aあb"`（バイト数 5、文字数 3）について、`byteLength` → 5、`charCount` → 3、`charAt(s, 1)` → `Some('あ')`、`charAt(s, 3)`・`charAt(s, -1)` → `None`、`byteSlice(s, 1, 4)` → `Some("あ")`、`byteSlice(s, 1, 2)` → `None`（境界でない）、`byteSlice(s, 2, 1)`・`byteSlice(s, 0, 6)` → `None`、`charSlice(s, 1, 3)` → `Some("あb")`、`charSlice(s, 3, 3)` → `Some("")`、`charSlice(s, 0, 4)` → `None`。
- 検索: `byteIndexOf("aあb", "b")` → `Some(4)`、`byteIndexOf("abc", "")` → `Some(0)`、`byteIndexOf("abc", "x")` → `None`、`contains("abc", "")` → `true`。
- `split`（03-06 の例）: `("a,,b", ",")` → `["a", "", "b"]`、`("", ",")` → `[""]`、`(",a,", ",")` → `["", "a", ""]`、`("aあ", "")` → `["a", "あ"]`、`("", "")` → `[]`、`("aaa", "aa")` → `["", "a"]`。
- `lines`（03-06 の例）: `"a\r\nb\n"` → `["a", "b"]`、`"a\n\nb"` → `["a", "", "b"]`、`""` → `[]`、`"a"` → `["a"]`、`"a\r"` → `["a"]`、`"\n"` → `[""]`。
- `join(["a", "b", "c"], ", ")` → `"a, b, c"`、`join([], ",")` → `""`。
- `trim(" \t x \r\n")` → `"x"`、`trim("\u{3000}x")` → `"\u{3000}x"`（全角空白は取り除かない）。
- `replace("aaa", "a", "bb")` → `"bbbbbb"`、`replace("aaa", "aa", "b")` → `"ba"`、`replace("abc", "", "x")` → `"abc"`。
- `repeat("ab", 3)` → `"ababab"`、`repeat("ab", 0)`・`repeat("ab", -1)` → `""`、`repeat("ab", 536870913)`（2^29 + 1。結果は 2^30 + 2 バイト）→ 文字列を作らずに `ValueTooLarge { function: "String.repeat", size: 1073741826, unit: Bytes, limit: 1073741824 }`（テストが大きな確保をしないことで、値を作る前に判定していることを確かめる）、`repeat("ab", i64::MAX)` → `size: u64::MAX` の資源の不足。
- `chars("aあ")` → `['a', 'あ']`、`fromChars(['a', 'あ'])` → `"aあ"`。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 新しい文字列かリストを作る関数が、すべて値を作る前に大きさを確かめている（02-09「一つの操作で作る値の大きさの上限」）

## 難易度の理由

関数の数が多く、バイト位置と文字位置の区別、境界の判定、`split` と `lines` の空文字列の扱いなど、仕様の細部を一つずつ満たす必要がある。大きさの上限を値を作る前に確かめる規則は、関数ごとに計算の仕方が違い（出現を数える、要素の大きさを合計する）、溢れの検査も要る。アルゴリズムそのものは単純である。
