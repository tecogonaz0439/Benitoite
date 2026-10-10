# L22 `Regex`

- 依存する作業: [L00](L00-u3-interfaces.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L22-regex

## 目的

正規表現の `Benitoite.Regex` の 12 の組み込みの関数の本体を、`regex` クレートを使って書く。10-15 の部分 38（`regex::DECLS`）である。`Regex.replaceAllWith` は L00 が置いたソースの関数であり、本作業はスクリプトのテストで確かめる。初回リリース版の処理系は、検査の時点で正規表現の構文を確かめない（03-08「Regex」、[ADR 0316](../../2026-10-09-design-first-release/decisions/0316-no-compile-time-regex-check-in-first-release.md)）。構文の誤りは、実行時に `Regex.compile` が返す `Result.Error` だけで分かる。

| 項目 | 権限 |
|---|---|
| `Regex.compile`・`isMatch`・`find`・`findAll`・`matchText`・`matchByteStart`・`matchByteEnd`・`group`・`namedGroup`・`replaceFirst`・`replaceAll`・`split` | `Pure` |
| `Regex.replaceAllWith`（ソース） | — |

## 読む設計書の節

- [テキストとデータの処理](../../2026-10-09-design-first-release/03-interop/03-08-text-and-data.md)の「Regex」（関数の表と箇条: バイト位置と半開区間、構文、`replacement` を書いたとおりに扱うこと、`replaceAllWith` の書き方、検査の段で構文を確かめないこと）、「各モジュールの範囲」の `regex` クレートの照合の時間の箇条、「共通の規則」
- [未決・要検証事項](../../2026-10-09-design-first-release/open-issues.md#open-062)の OPEN-062 の R08（初回リリース版では対処しない）
- ADR: [0168](../../2026-10-09-design-first-release/decisions/0168-regex-match-and-stdlib-opaque-values.md)、[0248](../../2026-10-09-design-first-release/decisions/0248-regex-byte-position-function-names.md)、[0138](../../2026-10-09-design-first-release/decisions/0138-crates-and-licenses-for-stdlib.md)、[0316](../../2026-10-09-design-first-release/decisions/0316-no-compile-time-regex-check-in-first-release.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「テキストとデータ」の表と `Regex.bnt`
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `regex`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `OpaqueData`・`alloc_opaque`・`opaque`

## 作るもの

- `src/builtins/funcs/regex.rs` の 12 項目の本体と単体テスト。`regex` を依存に加える（10-16 の表の指定）
- `Regex.replaceAllWith` などを確かめるスクリプトのテスト。`src/builtins/funcs/regex/tests.rs` に置き（`regex.rs` から `mod tests;` で読む）、`src/builtins/funcs/runtime_test_support.rs` の `compile`・`runtime`・`finish` を使う（`clock/tests.rs` の形に倣う）

## 手順の要点

- 組み立て: `regex::RegexBuilder` で組み立てる。設定（大きさの上限など）は `regex` の既定の値のままとする。誤りの理由は、クレートの誤りの表示（`regex::Error` の `Display`）をそのまま使う（03-08「共通の規則」の、理由の文面は定めない）。
- `Regex.Pattern` の値は、組み立てた `regex::Regex` を持つ `OpaqueData` である。`regex::Regex` は言語の値を含まないので `OpaqueData` にできる。
- `Regex.Match` の値は、照合した文字列の写し（Rust の `String`）、一致の全体と捕獲グループのバイト位置（`Option<(usize, usize)>` の並び）、名前付きのグループの名前から番号への対応を持つ `OpaqueData` である（10-15「テキストとデータ」の箇条）。照合した文字列を写すので、`findAll` の一致ごとに文字列を写さず、同じ写しを `Rc` などで共有してよい（`OpaqueData` は作った後に変えないので、共有してよい）。
- `matchByteStart`・`matchByteEnd` は、照合した文字列の中のバイト位置であり、一致は半開区間である（ADR 0248）。`String.byteSlice` にそのまま渡せる。
- `group(m, index)`: 0 は一致の全体。グループがないか（負の番号、数を超える番号）、一致に加わらなかったときは `None`。`namedGroup` は `(?P<name>…)` の名前で引く。
- `replaceFirst`・`replaceAll`: `replacement` を書いたとおりの文字列として扱い、`$1` などを展開しない。`regex::NoExpand` を使う。
- `split`: 一致を区切りとして分けた部分のリスト（`regex::Regex::split` の結果）。空の文字列、先頭と末尾の一致、空の一致の扱いを `regex` の振る舞いのまま使い、単体テストで確かめて `///` のコメントに書く。
- 作る文字列とリストの大きさを、確保の前に確かめる（`replaceAll` の結果は、置き換えの数から先に計算する）。`findAll` は、先に一致を数えて `CheckedLen::elements` で確かめてから `Regex.Match` の値を作る。空の一致を許す正規表現では、一致の数が入力のバイト数 + 1 になりうるためである。
- 最悪の場合の照合の時間が正規表現の大きさと入力の長さの積に比例する範囲に収まること（03-08「各モジュールの範囲」）は `regex` クレートの性質であり、本作業はこれを崩す使い方（後方参照を持つ別のエンジンなど）をしない。
- スクリプトのテストで `replacement` の `$1`・`${1}`・`${name}` が展開されないことを確かめるときは、生の文字列（`r"$1"`・`r"${1}"`）で書く。通常の文字列リテラルでは `${` が文字列補間を始める（`$` の後に `{` が続かなければ `$` はそのまま文字なので `"$1"` は書けるが、生の文字列に揃える。01-01「文字列リテラル」）。
- 本作業のモジュールの名前 `regex` と外部のクレート `regex` が同じなので、Rust のコードで指す先に迷ったら、クレートを `::regex::Regex` のように `::regex::` で書く。
- スクリプトのテストでは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Regex`。[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-08 の例の `import Benitoite.Regex` の形をそのまま写すと、E0321 になる。

## 受け入れテスト

- 項目ごとの単体テスト: 03-08 の表の各関数。捕獲グループ（番号と名前、一致に加わらなかったグループ）、ASCII でない文字を含む入力のバイト位置、`(?i)` による大文字と小文字を区別しない照合、空の一致（`a*` を `"baaa"` に）、`findAll` の重ならない一致、`replacement` に `$1` を含めても展開されない。
- `compile` の失敗: 閉じない括弧、後方参照（`(a)\1`）、先読み（`(?=a)`）で `Result.Error` になり、理由が空でない。閉じない括弧の場合は、OPEN-062 の R08 の反例と同じく、関数の本体に文字列リテラルで書いた `Regex.compile(r"[")` が検査を通り、実行時に `Result.Error` を返すことをスクリプトのテストで確かめる（ADR 0316 の決定 6）。
- 大きさ: 大きな正規表現（`regex` の既定の大きさの上限を超えるもの）で `compile` が `Result.Error` になり、処理系が止まらない。
- スクリプト: `Regex.replaceAllWith` が一致ごとに左から順に関数を呼び（`Reference` で順を記録する）、`Regex.group` を使った置き換えができる。03-08 の `extractDates` の例と同じ形のスクリプトが期待どおりの値を返す。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置、L00 が置いたソースを変えていない
- `regex` の版と、`split` の空の一致の扱いを完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。
- `OpaqueData` に言語の値を含めていないか。

## 難易度の理由

クレートが照合を行うが、一致の値の表現、バイト位置の扱い、置き換えの文字列を展開しないことを正しく作る必要がある。
