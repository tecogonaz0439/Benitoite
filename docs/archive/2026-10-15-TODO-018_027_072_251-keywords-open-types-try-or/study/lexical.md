# 現在の語の分類と、今回加える語の候補

## 現在のキーワード

[01-01「キーワード」](../../design/01-spec/01-01-lexical.md#キーワード)、`src/syntax/token.rs` の `TokenKind`、`src/syntax/lexer.rs:753` の `keyword` は、次の 34 語で一致している。本書の `src/` は `crates/benitoite/src/` を指す。

```text
and bind case const data div do effect else end false function handle if
implement import lambda lazy match mod not or public record resume return
shadow then trait true try type uses with
```

| 役割 | 語 |
|---|---|
| 論理・数の演算 | `and`・`or`・`not`・`div`・`mod` |
| 値のリテラル | `true`・`false` |
| 宣言・公開・取り込み | `function`・`data`・`record`・`type`・`const`・`trait`・`implement`・`effect`・`import`・`public` |
| 束縛 | `bind`・`shadow` |
| 式・ブロック・処置 | `lambda`・`if`・`then`・`else`・`match`・`case`・`with`・`do`・`end`・`return`・`try`・`lazy`・`handle`・`resume`・`uses` |

役割の区分には重なりがある。`with` は照合・ハンドラの区切りとリソースのスコープ、`effect` はエフェクト宣言と型パラメータ、`function` は関数宣言と関数型に使う。34 語以外に、意味を持たず名前だけを禁止する予約語はない。`or` はすでに Boolean の短絡演算子であり、251 のために新たに予約する必要はない。

## 識別子のまま、位置を限って読む語

| 語 | 意味を持つ位置と実装 |
|---|---|
| `as` | import の別名。`parser/items.rs::parse_import`。それ以外では名前に使える |
| `language`・`dependency`・`package` | ファイルの先頭の宣言。`parser/header.rs` と `syntax/header.rs`。`end package`・`end dependency` の語も識別子の綴りで照合する |
| `package` | `public(package)` の公開範囲。`parser/items.rs::parse_public` |
| `path`・`hash`・`effects`・`license` | dependency / package の欄。`syntax/header.rs`。通常の局所名としては禁止しない |
| `source`・`version`・`commit` | 先頭のブロックで、現在は使えない欄として専用診断を出す。受理する欄と区別する |
| `equality`・`key` | 型パラメータの組み込みの制約。`parser/traits.rs::builtin_constraint` |
| `ordered` | 標準ライブラリのソースだけで使える組み込みの制約。利用者が同じ位置に書くと診断する |
| `test`・`deprecated`・`external`・`builtin` | `@` の後の属性名。最後のものは標準ライブラリ専用。`parser/items.rs::attribute_name_error` / `attribute_args_error`。`@inline` は受理する属性ではない |

01-01 は `permissions` も予約しないと明記する。現在の `parser/header.rs` に、この語を受理する先頭の宣言はない。将来の権限の構文を実装済みとして数えない。WIT の `borrow`・`own` は外部の型を照合する側の語であり、Benitoite のキーワードではない。

誤記を見つけるために読む語もある。`fn`、`let`、`of`、`when`、`where`、`from`、`typealias`、`alias` などは、他言語の構文に似た形に専用の案内を出す。例えば `foreign.rs::fn_lambda_ahead` は、`fn(...)` に波括弧が続く場合を通常の関数呼び出しと区別している。これらを診断で認識することと、どの位置でも名前に使えなくすることは別である。

## TODO-018 の綴りの問い

| 問い | 調査からの判断材料 |
|---|---|
| 省略形と省略しない語 | `function`・`public`・`implement` を保つと、現在の関数型・宣言・終端が揃う。`lambda` は独立した概念名であり、`function` の別綴りとして追加した語ではない。生成・修正の成功率の優劣は今回は測っていない |
| 省略形の予約 | `fn` には有効な呼び出しを守りながら他言語風の形だけを診断する実装がある。すべてを予約する理由は、現在より良い案内が必要な具体例で評価すべきである |
| 制御の語の予約 | `for`・`while`・`loop`・`break`・`continue`・`switch`・`where` は今のまま普通の名前にできる。`as` はすでに import で役割を持つので、一律に「存在しない構文の語」として扱えない |
| 並行処理の語の予約 | `Task.await`・`TaskGroup.spawn` は実在する API である。現在はドットの後も名前を期待するため、`await`・`spawn` の一律予約は API の綴りにも影響する |

`const`、`div`、`mod` も現在の綴りのままにする案を推す。「省略しない」という原則だけで機械的に `constant`・`divide`・`modulo` に変えると、既存の構文と文書の移行を増やす。これらを読みにくいと判断する具体的な根拠は今回得られていない。`else`・`shadow` は現在も有効であり、前回の「新しいコードでは勧めない」という案内を、構文の廃止と取り違えない。

## 今回および後続の追加候補

| 候補 | 衝突と推す扱い |
|---|---|
| `or` | 既存のキーワード。try の直後に読む式の同じ深さで、`or return`・`or die` を処置の区切りとして読む規則が要る |
| `return` | 既存のキーワード。処置の後に任意の戻り値式を付ける意味は今回加えない |
| `die` | 現在は小文字の識別子。キーワードへ加える案を推す。既存の有効な `x or die()` を処置と取り違える危険をなくす。走査したコード候補内での同名は 0 件。ただし補間内・外部の利用者コードまで不存在を保証しない |
| `@extensible` | data 宣言の属性名として読む案を推す。属性の外の `extensible` は名前に使える。`@nonExhaustive`、`@non_exhaustive`、`@open` と比較し、将来構成子を加えられることを正の語で示す |
| `open data` | 新しい修飾語を要する。`open` の一律予約は `File.open` などを壊す。今回の走査では標準ライブラリに 2 出現、testdata に 18 出現の候補がある |
| 型付きの失敗の新しい語 | TODO-249 の具体的な綴りは未決である。今から `fail`・`throw`・`catch` などを予約しない。`or` の後の文法を処置の種類ごとに拡張できる構成を取る |
| `derive` などカテゴリ C の語 | 属性名として使う可能性を残す。今回、予約語を先取りして増やす必要はない |

追加・削除・変更の案は、全体で「キーワードへ `die` を 1 語追加、既存のキーワードの削除と改名は 0 語、意味のない予約語の追加は 0 語」である。`@extensible` は新しい属性であり、キーワードの 35 語には数えない。集計の条件と位置は [migration-and-size.md](migration-and-size.md) と [inventory.json](inventory.json) にある。
