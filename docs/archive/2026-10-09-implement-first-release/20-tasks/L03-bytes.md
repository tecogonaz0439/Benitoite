# L03 `Bytes` と `String.toUTF8`・`fromUTF8`

- 依存する作業: [L00](L00-u3-interfaces.md)、[R35](R35-decimal-and-byte.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L03-bytes

## 目的

変更できないバイト列の型 `Bytes` の 16 の関数と、文字列とバイト列の変換 `String.toUTF8`・`String.fromUTF8` の本体を書く（[ADR 0107](../../2026-10-09-design-first-release/decisions/0107-bytes.md)）。10-15 の部分 26（`string::UTF8_DECLS`）と部分 27（`bytes::DECLS`）である。`Bytes` は、ファイル（L11・L12）、Base64 と SHA-256（L25）、HTTP の本体（L30〜L32）が使うので、U3 の多くの作業がこの作業を待つ。16 進と 2 進の変換は、クレートを使わずに自作する（03-01「使う Rust のクレート」）。

| 部分 | 項目 | 権限 |
|---|---|---|
| 26 | `String.toUTF8`・`String.fromUTF8` | `Pure` |
| 27 | `Bytes.empty`・`fromList`・`fromIntegers`・`fromHex`・`fromBinary`・`toList`・`toHex`・`toBinary`・`length`・`get`・`slice`・`concatenate`・`readUnsigned`・`readSigned`・`fromUnsigned`・`fromSigned` | `Pure` |

## 読む設計書の節

- [標準ライブラリ](../../2026-10-09-design-first-release/03-interop/03-06-stdlib.md)の「Bytes と ByteOrder（初回リリース版）」（関数の表、`count` の範囲、区切りと大文字と小文字、BOM、表現の方針）、「作る値の大きさの上限」
- [基本型の意味論](../../2026-10-09-design-first-release/01-spec/01-04-types-basic.md)の「Byte（初回リリース版）」
- ADR: [0107](../../2026-10-09-design-first-release/decisions/0107-bytes.md)、[0012](../../2026-10-09-design-first-release/decisions/0012-invalid-utf8-input.md)、[0049](../../2026-10-09-design-first-release/decisions/0049-size-limit-for-built-values.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「`Bytes`」の表と `Bytes.bnt`・`ByteOrder.bnt`、「構成子のタグ」の `BYTE_ORDER_*`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `ObjKind::Bytes`、`alloc_bytes`・`alloc_bytes_with`・`bytes`、`CheckedLen`、`alloc_str_utf8`、`runtime::list` の関数

## 作るもの

- `src/builtins/funcs/bytes.rs` の 16 項目と、`string.rs` の `UTF8_DECLS` の 2 項目の本体と単体テスト
- 16 進と 2 進の変換の非公開の関数

## 手順の要点

- 位置を受け取る関数（`get`・`slice`・`readUnsigned`・`readSigned`）は、位置が正しくなければ `Option.None` を返し、実行時エラーにしない（03-06）。負の位置、長さを超える位置、`start > stop` を `None` にする。
- `count` は 1 以上 8 以下でなければならず、外なら `Option.None`。`readUnsigned` の `count` が 8 で値が `Integer` の範囲を超えるときも `None`。`fromUnsigned` は負の `n` と、`count` バイトに収まらない `n` で `None`。`fromSigned` は 2 の補数で収まらない `n` で `None`。バイト順は `ByteOrder` の値のタグ（`tags::BYTE_ORDER_BIG_ENDIAN` など）で読む。
- `fromHex` と `fromBinary` は、区切りの `_` と空白（U+0020）を読み飛ばし、16 進は大文字と小文字のどちらも受け付ける。区切りを除いた桁の数が 2 の倍数（16 進）・8 の倍数（2 進）でなければ `None`。ほかの文字（タブ、全角の数字など）も `None`。
- `toHex` は小文字の 2 桁、`toBinary` は 8 桁で、区切りを入れない。結果の文字列の長さ（バイト数の 2 倍・8 倍）を、確保の前に `CheckedLen` で確かめる。
- `Bytes` の値の大きさは文字列と同じ上限（2^30 バイト。02-09）で確かめる。`concatenate`・`fromList`・`fromIntegers` は、結果の長さを計算してから確保する。結果の長さ（`toHex` の 2 倍、`toBinary` の 8 倍、`concatenate` の和）を `u64` で計算して `CheckedLen` に渡す長さを返す非公開の関数を分けて書き、上限超えのテストはこの関数に対して行う（下の受け入れテスト）。
- `Bytes.slice` の表現: 03-06 は「同じ領域を共有し、開始位置と長さだけを変えた値」とするが、10-08 の `ObjKind::Bytes` がこの表現を持たないときは写して作ってよい（10-15「`Bytes`」）。どちらにしたかを完了の報告に書く。
- `String.toUTF8` は文字列のバイト列をそのまま写す。`String.fromUTF8` は、UTF-8 を確かめる `alloc_str_utf8` で作り、正しくなければ `None`。先頭の BOM（U+FEFF）を取り除かない（03-06）。
- `Bytes` は等値の型であり、`=` と構造の等しさは R06・R37 の `values_equal` が扱う。鍵の順序（辞書式、短いほうが前）は `runtime::map::compare_keys` が扱う。本作業はこれらを変えない。`Bytes` の値の `=` と `Map` の鍵での順序を、スクリプトのテストで確かめ、食い違えば作業を止めて報告する。

## 受け入れテスト

- 項目ごとの単体テスト: 空のバイト列、1 バイト、長いバイト列。`fromIntegers([0, 255])` と `[256]`・`[-1]`。`fromHex("DE ad_BE ef")` が 4 バイト、`fromHex("abc")`・`fromHex("zz")` が `None`。`fromBinary("0000_0001 11111111")` が 2 バイト。`toHex`・`toBinary` と `fromHex`・`fromBinary` の往復。`get`・`slice` の境界（0、長さ、長さ + 1、負）。
- 整数の読み書き: `count` の 1〜8 と 0・9、両方のバイト順、符号なしの最大値、符号付きの最小値と最大値、`readUnsigned` の `count` 8 で最上位のビットが立つ場合（`None`）、`fromUnsigned(256, 1, …)` が `None`、`fromSigned(-129, 1, …)` が `None`。`fromSigned`・`readSigned` の往復。
- UTF-8: `toUTF8("é")` が 2 バイト、`fromUTF8` の往復、正しくない UTF-8（`[0xFF]`、途中で切れた列）で `None`、BOM を残す。
- 大きさの上限: 1 GiB 規模のバイト列を確保するテストは書かない。結果の長さを計算する非公開の関数（上の手順の要点）に、結果が上限（2^30 バイト）を超える大きな長さを与え、`CheckedLen` が資源の不足を返すことを確かめる（`concatenate` と `toHex` の場合）。上限の判定そのものは、10-08 の `StrBuf`・`CheckedLen` のテストに任せる。
- スクリプト: `Bytes` の値の `=`、`Map` の鍵にしたときの順序、`Trait.Show` を持たないこと（`Show` の実装がないので、`Show.show` に渡すと型の誤り E0705 になる）。
- `fromHex("")` が `Some`（空のバイト列）を返す（`fromBinary("")` も同じ）。
- スクリプトのテストで U3 の非公式のモジュールを取り込むときは、非公式の名前（`import Benitoite.Unofficial.Json` など。ADR 0286 の決定 3）で書く。03-08 などの設計書の例の `import Benitoite.Json` の形を写すと、E0321 になる。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- `Bytes.slice` の表現（共有か写すか）を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、結果の大きさを確保の前に確かめているか、位置の計算が溢れを検査しているか。
- 16 進と 2 進の変換で、外部のコードを写していないか（00-02「依存するクレート」）。

## 難易度の理由

関数の数が多く、位置と `count` の境界、符号の扱い、区切りの読み飛ばしなど、境界の条件が多い。値の表現は既にあるので、新しい仕組みは要らない。
