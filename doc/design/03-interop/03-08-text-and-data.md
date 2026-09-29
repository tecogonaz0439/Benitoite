# テキストとデータの処理

- 状態: 確定
- 関連ADR: [0006](../decisions/0006-basic-types-semantics.md), [0012](../decisions/0012-invalid-utf8-input.md), [0056](../decisions/0056-record-fields-via-accessor-functions.md), [0101](../decisions/0101-unabbreviated-names.md), [0103](../decisions/0103-map-and-set-ordered-by-key.md), [0107](../decisions/0107-bytes.md), [0122](../decisions/0122-multiline-and-raw-strings.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0137](../decisions/0137-first-release-library-scope.md), [0138](../decisions/0138-crates-and-licenses-for-stdlib.md), [0168](../decisions/0168-regex-match-and-stdlib-opaque-values.md), [0173](../decisions/0173-time-format-specifiers.md), [0248](../decisions/0248-regex-byte-position-function-names.md)
- 未決事項: [OPEN-043](../open-issues.md#open-043), [OPEN-062](../open-issues.md#open-062)
- 移行元: [設計メモ](../sources/fp-language-design.md) 16

## 目的と範囲

テキストとデータを扱う純粋なモジュール（`Benitoite.Path`・`Benitoite.Json`・`Benitoite.Regex`・`Benitoite.Csv`・`Benitoite.Time`・`Benitoite.Encoding`・`Benitoite.Hash`）の範囲、型、関数を定める。

現在の版は、各モジュールに入れる機能の範囲と、実装に使うクレート（[ADR 0137](../decisions/0137-first-release-library-scope.md)、[ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md)）を定め、各モジュールの型と関数の草稿を示す。型と関数の一覧は、どれも【方針】（草稿）である。

## 前提

本章のモジュールは、どれも IO を行わない純粋なモジュールであり、prelude に入らない。使うには `import Benitoite.Json` のように取り込む（[標準ライブラリ](03-06-stdlib.md)の「名前空間と prelude（初回リリース版）」）。ファイルを読み書きする操作は[IO のモジュール](03-07-io-modules.md)の `File` で行い、本章のモジュールは読み書きした文字列やバイト列を扱う。標準ライブラリの作り方は[ライブラリの構成](03-01-library-structure.md)で定める。

## 仕様

### 各モジュールの範囲

【方針】初回リリース版の各モジュールには、次の機能を入れる（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。

| モジュール | 機能 | 実装 |
|---|---|---|
| `Benitoite.Path` | パスの結合、親のディレクトリ・ファイルの名前・拡張子への分解、正規化（`.` と `..` の除去）。文字列の操作だけを行い、ファイルシステムを読まない | Rust の標準ライブラリ |
| `Benitoite.Json` | JSON の値を表す型、文字列からの解析、文字列化（整形あり・なし） | `serde_json` |
| `Benitoite.Regex` | 正規表現の値の型（組み立てると失敗しうるので `Result` で返す）、照合、検索、置換、分割 | `regex` |
| `Benitoite.Csv` | CSV の解析と書き出し | `csv-core` |
| `Benitoite.Time` | 時刻の型、ISO 8601 の形の書式と解析、UTC と時差（オフセット）での表示 | `jiff` |
| `Benitoite.Encoding` | Base64 の符号化と復号（`Bytes` と `String` の間）。16 進数は `Bytes.toHex`・`Bytes.fromHex`（[標準ライブラリ](03-06-stdlib.md)）で行う | `base64` |
| `Benitoite.Hash` | SHA-256 | `sha2` |

- 【方針】`Benitoite.Regex` は、照合の時間が入力の長さに比例するエンジン（`regex` クレート）を使う。このクレートは、先読み・後読みと後方参照を持たない代わりに、最悪の場合の照合の時間を、正規表現の大きさと入力の長さの積に比例する範囲に抑える（`regex` クレートの README）。利用者が渡した正規表現で、照合の時間が爆発することはない。
- 【方針】`Benitoite.Time` は、IANA のタイムゾーンの名前（`Asia/Tokyo` など）を扱わない。時刻は UTC と、時差を指定した表示だけで扱う。
- UTF-8 以外の文字コードとの変換は [OPEN-043](../open-issues.md#open-043) で扱う。

【方針】初回リリース版には、gzip、URL の解析、YAML・TOML・XML、SQLite を入れない（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。

### 共通の規則

【方針】本章のモジュールに共通する規則は次のとおりである。

- 本章の型は、モジュールの名前で修飾して書く（`Json.Value`、`Regex.Pattern`）。構成子は型の名前でも修飾して書く（`Json.Value.Null`）。レコードのフィールドは、型のモジュールの関数で取り出す（`Json.ParseError.line(e)`。[ADR 0056](../decisions/0056-record-fields-via-accessor-functions.md)）。
- 入力の形が正しくないことによる失敗は `Result.Error` で返す。失敗の値の型は、モジュールごとの `ParseError` のレコードか、人間が読める理由の `String` である。理由の文面は処理系の版によって変わりうる。
- 文字列の位置は、名前に単位を含める（[基本型の意味論](../01-spec/01-04-types-basic.md)の「String」）。本章でバイト位置を返すものは、名前に `byte` を含める。
- 本章の関数は、どれも純粋であり、エフェクトを持たない。関数を引数にとる関数だけが、受け取った関数のエフェクト変数を持つ。

### Path

【方針】`Benitoite.Path` は、パスを `String` のまま扱い、文字列の操作だけで結合と分解を行う。ファイルシステムを読まないので、シンボリックリンクを解決せず、パスが指すものがあるかも確かめない。区切りと根の書き方は、処理系を動かしている OS の規則に従う（Unix では `/`、Windows では `\` と `/` の両方を区切りとし、`C:` などの接頭辞を根の一部とする）。

| 関数 | 型 | 値 |
|---|---|---|
| `Path.join(base, child)` | `function(String, String) -> String` | `base` の後に区切りを挟んで `child` を続けたパス。`child` が絶対パスなら `child` |
| `Path.joinAll(parts)` | `function(List[String]) -> String` | `parts` を先頭から順に `Path.join` でつないだパス。空のリストなら `""` |
| `Path.parent(p)` | `function(String) -> Option[String]` | 最後の構成要素を除いたパス。根だけのパスと空のパスなら `Option.None` |
| `Path.fileName(p)` | `function(String) -> Option[String]` | 最後の構成要素。最後が `..` のとき、根だけのとき、空のときは `Option.None` |
| `Path.stem(p)` | `function(String) -> Option[String]` | `Path.fileName(p)` から、最後の `.` とその後を除いた部分。`.` で始まり、ほかに `.` を含まない名前（`.bashrc`）は、名前全体 |
| `Path.extension(p)` | `function(String) -> Option[String]` | `Path.fileName(p)` の最後の `.` より後の部分（`.` を含まない）。拡張子がなければ `Option.None` |
| `Path.withExtension(p, extension)` | `function(String, String) -> String` | 拡張子を `extension` に替えたパス。`extension` が `""` なら拡張子を除く |
| `Path.isAbsolute(p)` | `function(String) -> Boolean` | 絶対パスか |
| `Path.components(p)` | `function(String) -> List[String]` | 構成要素の並び。絶対パスでは、先頭に根（Unix では `/`）を置く。`.` の構成要素と、重なった区切りは除く |
| `Path.normalize(p)` | `function(String) -> String` | `.` の構成要素を除き、`..` を直前の構成要素と打ち消したパス。打ち消す構成要素がない `..` は、相対パスでは残し、絶対パスでは除く。結果が空なら `"."` |

- `Path.normalize` は字面だけで打ち消すので、シンボリックリンクを含むパスでは、ファイルシステムの上の同じ場所を指すとは限らない。シンボリックリンクを解決した絶対パスは `File.canonicalize`（[IO のモジュール](03-07-io-modules.md)）で得る。
- 相対パスを絶対パスにするには、`Process.workingDirectory`（[IO のモジュール](03-07-io-modules.md)）と `Path.join` を組み合わせる。

### Json

【方針】`Benitoite.Json` は、JSON の値を代数的データ型 `Json.Value` で表す。

```text
type Value
  Null
  Boolean(Boolean)
  Integer(Integer)
  Float(Float)
  String(String)
  Array(List[Value])
  Object(Map[String, Value])
end type

record ParseError
  line: Integer
  column: Integer
  message: String
end record
```

- 小数点と指数を持たない数で、`Integer` の範囲に収まるものは `Json.Value.Integer`、それ以外の数は `Json.Value.Float` とする。`Float` の範囲も超える数は、解析の誤りとする。
- オブジェクトは `Map` で表すので、メンバは鍵の順序で並ぶ。入力に同じ鍵が二つ以上あれば、後のメンバの値を使う（`Map.fromList` と同じ）。
- `Json.Value` は等値の型である。`Json.Value.Float` を含むので、鍵の型ではない。
- `line` と `column` は 1 から数える。`column` は、その行の中の文字位置に 1 を足した値である。

| 関数 | 型 | 値 |
|---|---|---|
| `Json.parse(text)` | `function(String) -> Result[Json.Value, Json.ParseError]` | `text` を JSON として読んだ値。前後の空白を許す |
| `Json.stringify(value)` | `function(Json.Value) -> String` | 空白を入れない JSON の文字列 |
| `Json.stringifyPretty(value)` | `function(Json.Value) -> String` | 改行を入れ、入れ子ごとに 2 個の空白で字下げした JSON の文字列 |
| `Json.get(value, key)` | `function(Json.Value, String) -> Option[Json.Value]` | `value` がオブジェクトなら、`key` のメンバの値。オブジェクトでないか、`key` がなければ `Option.None` |
| `Json.at(value, index)` | `function(Json.Value, Integer) -> Option[Json.Value]` | `value` が配列なら、位置 `index`（0 から数える）の要素。配列でないか、範囲の外なら `Option.None` |
| `Json.asString(value)` | `function(Json.Value) -> Option[String]` | `Json.Value.String` の中身 |
| `Json.asInteger(value)` | `function(Json.Value) -> Option[Integer]` | `Json.Value.Integer` の中身 |
| `Json.asFloat(value)` | `function(Json.Value) -> Option[Float]` | `Json.Value.Float` の中身。`Json.Value.Integer` なら `Float` に変換した値 |
| `Json.asBoolean(value)` | `function(Json.Value) -> Option[Boolean]` | `Json.Value.Boolean` の中身 |
| `Json.asArray(value)` | `function(Json.Value) -> Option[List[Json.Value]]` | `Json.Value.Array` の中身 |
| `Json.asObject(value)` | `function(Json.Value) -> Option[Map[String, Json.Value]]` | `Json.Value.Object` の中身 |

- `Json.stringify` と `Json.stringifyPretty` は、メンバを鍵の順序で書くので、同じ値からは同じ文字列を作る。文字列の中の制御文字、`"`、`\` はエスケープする。それ以外の文字は、エスケープせずにそのまま書く。
- JSON は NaN と無限大を表せない。`Json.stringify` と `Json.stringifyPretty` は、これらの `Float` を `null` と書く。値の失敗を返さないのは、文字列化をどの値にも使えるようにするためである。
- 入力は `String` なので、正しくない UTF-8 は `Json.parse` に届かない。ファイルの内容が正しい UTF-8 でないときは、`File.readText` が失敗する（[ADR 0012](../decisions/0012-invalid-utf8-input.md)）。

```text
import Benitoite.IO.File
import Benitoite.Json

function totalAmount(path: String): Result[Integer, String] uses File.Read
  let text = try File.readText(path) |> Result.mapError(_, IOError.message)
  let value = try Json.parse(text) |> Result.mapError(_, Json.ParseError.message)
  let items = Json.asArray(value) |> Option.unwrapOr(_, [])
  return Result.Ok(List.fold(items, 0, lambda(sum, item)
    return case Json.get(item, "amount") of
      when Option.Some(Json.Value.Integer(n)): sum + n
      when _: sum
    end case
  end lambda))
end function
```

### Regex

【方針】`Benitoite.Regex` は、組み立てた正規表現を中身を見せない型 `Regex.Pattern` で、一つの一致を中身を見せない型 `Regex.Match` で表す（[ADR 0168](../decisions/0168-regex-match-and-stdlib-opaque-values.md)）。`Regex.Match` は、一致の全体と捕獲グループの位置を持つ。どちらの型も等値の型ではない。

| 関数 | 型 | 値 |
|---|---|---|
| `Regex.compile(source)` | `function(String) -> Result[Regex.Pattern, String]` | `source` を組み立てた正規表現。構文が正しくなければ、理由の文字列の `Result.Error` |
| `Regex.isMatch(pattern, text)` | `function(Regex.Pattern, String) -> Boolean` | `text` のどこかに一致する部分があるか |
| `Regex.find(pattern, text)` | `function(Regex.Pattern, String) -> Option[Regex.Match]` | 最も左で始まる一致 |
| `Regex.findAll(pattern, text)` | `function(Regex.Pattern, String) -> List[Regex.Match]` | 重ならない一致を、左から順に並べたリスト |
| `Regex.matchText(match)` | `function(Regex.Match) -> String` | 一致した部分の文字列 |
| `Regex.matchByteStart(match)` | `function(Regex.Match) -> Integer` | 一致した部分の始まりのバイト位置 |
| `Regex.matchByteEnd(match)` | `function(Regex.Match) -> Integer` | 一致した部分の終わりのバイト位置 |
| `Regex.group(match, index)` | `function(Regex.Match, Integer) -> Option[String]` | 番号 `index` の捕獲グループに一致した部分。0 は一致の全体。グループがないか、一致に加わらなかったときは `Option.None` |
| `Regex.namedGroup(match, name)` | `function(Regex.Match, String) -> Option[String]` | 名前 `name` の捕獲グループ（`(?P<name>…)`）に一致した部分 |
| `Regex.replaceFirst(pattern, text, replacement)` | `function(Regex.Pattern, String, String) -> String` | 最初の一致を `replacement` に置き換えた文字列 |
| `Regex.replaceAll(pattern, text, replacement)` | `function(Regex.Pattern, String, String) -> String` | すべての一致を `replacement` に置き換えた文字列 |
| `Regex.replaceAllWith(pattern, text, f)` | `function[effect E](Regex.Pattern, String, function(Regex.Match) -> String uses E) -> String uses E` | すべての一致を、その一致を `f` に渡した値に置き換えた文字列 |
| `Regex.split(pattern, text)` | `function(Regex.Pattern, String) -> List[String]` | 一致を区切りとして分けた部分のリスト |

- `Regex.matchByteStart` と `Regex.matchByteEnd` は、照合した文字列の中のバイト位置（[基本型の意味論](../01-spec/01-04-types-basic.md)）であり、一致した部分は半開区間 `[matchByteStart, matchByteEnd)` である（[ADR 0248](../decisions/0248-regex-byte-position-function-names.md)）。`String.byteSlice` にそのまま渡せる。
- 正規表現の構文は `regex` クレートの構文である。先読み・後読みと後方参照は書けない。大文字と小文字を区別しない照合などは、`(?i)` のような正規表現の中の指定で行う。
- `Regex.replaceFirst` と `Regex.replaceAll` の `replacement` は、書いたとおりの文字列として扱い、`$1` のようなグループの参照を展開しない。Benitoite の文字列リテラルでは `$` が文字列補間を始めるので、参照の記法を持ち込むと書き誤りを招く。グループを使って置き換えるときは、`Regex.replaceAllWith` と `Regex.group` を使う。
- `Regex.replaceAllWith` は、受け取った関数を呼ぶので、標準ライブラリのソースで書く。`Regex.findAll` で求めた一致を左から順に `f` に渡し、`Regex.matchByteStart`・`Regex.matchByteEnd` の位置で元の文字列と置き換えた文字列をつなぐ（[標準ライブラリ](03-06-stdlib.md)の「関数を引数にとる関数の共通の規則」）。ほかの関数は組み込みで実装する。
- 正規表現は、バックスラッシュを多く含むので、raw 文字列（`r"\d+"`。[字句構造](../01-spec/01-01-lexical.md)、[ADR 0122](../decisions/0122-multiline-and-raw-strings.md)）で書くことを勧める。
- 【方針】`Regex.compile` の引数が文字列リテラルか定数式のときは、処理系は検査の段で正規表現を組み立て、構文の誤りを検査の誤りとして報告する。実行する前に見つけられる誤りを実行の前に報告するためである（原則 1）。この場合も、`Regex.compile` の型は変わらない。

```text
import Benitoite.Regex

function extractDates(text: String): Result[List[String], String]
  let pattern = try Regex.compile(r"\d{4}-\d{2}-\d{2}")
  return Result.Ok(Regex.findAll(pattern, text) |> List.map(_, Regex.matchText))
end function
```

### Csv

【方針】`Benitoite.Csv` は、RFC 4180 の CSV を読み書きする。値はどれも `String` として扱い、数への変換は利用者が `Integer.parse` などで行う。

```text
record ParseError
  line: Integer
  message: String
end record
```

| 関数 | 型 | 値 |
|---|---|---|
| `Csv.parse(text)` | `function(String) -> Result[List[List[String]], Csv.ParseError]` | 行のリスト。各行はフィールドのリスト |
| `Csv.parseWith(text, delimiter)` | `function(String, Character) -> Result[List[List[String]], Csv.ParseError]` | 区切りを `delimiter`（`'\t'` など）とした `Csv.parse` |
| `Csv.parseWithHeader(text)` | `function(String) -> Result[List[Map[String, String]], Csv.ParseError]` | 最初の行を見出しとし、残りの各行を、見出しの名前からフィールドへのマップにしたリスト |
| `Csv.format(rows)` | `function(List[List[String]]) -> String` | `rows` を CSV の文字列にしたもの |
| `Csv.formatWith(rows, delimiter)` | `function(List[List[String]], Character) -> String` | 区切りを `delimiter` とした `Csv.format` |

- 行の終わりは、LF と CR LF のどちらも受け付ける。最後の行の後の改行はあってもなくてもよい。引用符で囲んだフィールドの中の改行と、`""`（引用符一つ）を受け付ける。
- 閉じていない引用符は、解析の誤りとする。`line` は、誤りを見つけた行の番号（1 から数える）である。
- `Csv.parseWithHeader` は、見出しに同じ名前が二つ以上あるとき、見出しとフィールドの数が違う行があるときを、解析の誤りとする。`Csv.parse` は、行ごとにフィールドの数が違ってもよい。
- `Csv.format` は、区切り、引用符、CR、LF を含むフィールドを引用符で囲む。行の終わりは LF とする（RFC 4180 は CR LF とするが、スクリプトが扱うファイルとの揃いを優先する）。
- `delimiter` に引用符（`"`）、CR、LF を指定すると、実行時エラー（引数が定義域の外。[評価意味論](../01-spec/01-08-evaluation.md)）とする。

### Time

【方針】`Benitoite.Time` は、時刻を型 `Time.Instant` で表し、暦の上の日付と時刻を型 `Time.DateTime` で表す。IANA のタイムゾーンの名前は扱わず、時差（UTC からのずれ）を分の数で指定する。現在の時刻と、実行している環境の時差は `Clock`（[IO のモジュール](03-07-io-modules.md)）で得る。

```text
record Instant
  unixNanoseconds: Integer
end record

record DateTime
  year: Integer
  month: Integer
  day: Integer
  hour: Integer
  minute: Integer
  second: Integer
  nanosecond: Integer
  offsetMinutes: Integer
end record
```

- `Time.Instant` は、1970-01-01T00:00:00Z からの経過をナノ秒で表す。`Integer` の範囲に収まるので、表せる時刻はおよそ 1677 年から 2262 年までである。フィールドがどれも `Integer` なので、`Time.Instant` と `Time.DateTime` は鍵の型であり、`Map` の鍵にできる。
- 時刻の前後は、`Time.Instant.unixNanoseconds(t)` を比べて判定する。
- うるう秒は扱わない。

| 関数 | 型 | 値 |
|---|---|---|
| `Time.fromUnixSeconds(seconds)` | `function(Integer) -> Time.Instant` | 1970-01-01T00:00:00Z から `seconds` 秒後の時刻 |
| `Time.fromUnixMilliseconds(milliseconds)` | `function(Integer) -> Time.Instant` | 同じく `milliseconds` ミリ秒後の時刻 |
| `Time.toUnixSeconds(t)` | `function(Time.Instant) -> Integer` | 経過の秒数（負の無限大の向きへ切り捨てる） |
| `Time.toUnixMilliseconds(t)` | `function(Time.Instant) -> Integer` | 経過のミリ秒数（負の無限大の向きへ切り捨てる） |
| `Time.addMilliseconds(t, milliseconds)` | `function(Time.Instant, Integer) -> Time.Instant` | `t` の `milliseconds` ミリ秒後の時刻 |
| `Time.differenceMilliseconds(a, b)` | `function(Time.Instant, Time.Instant) -> Integer` | `a` から `b` を引いた経過のミリ秒数（負の無限大の向きへ切り捨てる） |
| `Time.toDateTime(t, offsetMinutes)` | `function(Time.Instant, Integer) -> Time.DateTime` | 時差 `offsetMinutes` 分の地域で見た `t` の日付と時刻 |
| `Time.fromDateTime(dt)` | `function(Time.DateTime) -> Result[Time.Instant, String]` | `dt` が表す時刻。存在しない日付（2 月 30 日など）や範囲の外の値は `Result.Error` |
| `Time.formatISO8601(t, offsetMinutes)` | `function(Time.Instant, Integer) -> String` | ISO 8601 の形の文字列（`2026-09-28T12:34:56.789+09:00`）。時差が 0 なら末尾を `Z` にする。秒の端数は、0 でなければ必要な桁まで書く |
| `Time.parseISO8601(text)` | `function(String) -> Result[Time.Instant, String]` | ISO 8601 の形の文字列が表す時刻。時差（`+09:00` など）か `Z` を必須とする |
| `Time.format(t, offsetMinutes, pattern)` | `function(Time.Instant, Integer, String) -> Result[String, String]` | `pattern` の指定に従って書いた文字列。`pattern` に知らない指定があれば `Result.Error` |

- `Time.addMilliseconds` などの計算の結果が `Time.Instant` の範囲を超えたときは、実行時エラーとする（`Integer` の溢れと同じ扱い。[基本型の意味論](../01-spec/01-04-types-basic.md)）。
- `offsetMinutes` は、-1439 以上 1439 以下でなければならない。範囲の外の値を渡すと実行時エラーとする。
- 【決定】`Time.format` の `pattern` は、strftime の形の指定を使い、次の表の指定だけを受け付ける（[ADR 0173](../decisions/0173-time-format-specifiers.md)）。表にない指定を含む `pattern` には `Result.Error` を返す。`%` で始まらない文字は、そのまま書く。

  | 指定 | 書くもの |
  |---|---|
  | `%Y` | 年。4 桁に満たなければ 0 で埋める（`0042`）。負の年は `-` を付ける |
  | `%m`・`%d` | 月・日（2 桁、`01`〜） |
  | `%H`・`%I` | 時（`%H` は 24 時間制の `00`〜`23`、`%I` は 12 時間制の `01`〜`12`） |
  | `%p` | 午前か午後（`AM`・`PM`） |
  | `%M`・`%S` | 分・秒（2 桁） |
  | `%f` | 秒の端数のナノ秒（9 桁） |
  | `%j` | 年の初めからの日（3 桁、`001`〜`366`） |
  | `%a`・`%A` | 曜日の英語の名前（`%a` は `Mon`、`%A` は `Monday`） |
  | `%b`・`%B` | 月の英語の名前（`%b` は `Jan`、`%B` は `January`） |
  | `%z`・`%:z` | 時差（`%z` は `+0900`、`%:z` は `+09:00`） |
  | `%%` | `%` |

  曜日と月の名前は、地域の設定に依らない。実装は `jiff` の書式の機能を使ってよいが、`pattern` を表と照らし合わせてから渡す。

### Encoding

【方針】`Benitoite.Encoding` は、バイト列と Base64 の文字列を相互に変換する。16 進数の表記との変換は、`Bytes.toHex` と `Bytes.fromHex`（[標準ライブラリ](03-06-stdlib.md)の「Bytes と ByteOrder（初回リリース版）」）で行い、本章のモジュールには置かない。文字列とバイト列の変換は `String.toUTF8` と `String.fromUTF8` で行う。

| 関数 | 型 | 値 |
|---|---|---|
| `Encoding.base64Encode(data)` | `function(Bytes) -> String` | 標準の文字の表（RFC 4648 の 4 節）で、`=` の詰め物を付けた Base64 の文字列 |
| `Encoding.base64Decode(text)` | `function(String) -> Result[Bytes, String]` | 標準の文字の表の Base64 を読んだバイト列。`=` の詰め物を必須とする。空白や改行を含むか、形が正しくなければ `Result.Error` |
| `Encoding.base64UrlEncode(data)` | `function(Bytes) -> String` | URL とファイルの名前に使える文字の表（RFC 4648 の 5 節）で、詰め物を付けない Base64 の文字列 |
| `Encoding.base64UrlDecode(text)` | `function(String) -> Result[Bytes, String]` | URL 用の文字の表の、詰め物のない Base64 を読んだバイト列 |

### Hash

【方針】`Benitoite.Hash` は、SHA-256 のハッシュ値を求める。

| 関数 | 型 | 値 |
|---|---|---|
| `Hash.sha256(data)` | `function(Bytes) -> Bytes` | `data` の SHA-256 のハッシュ値（32 バイト） |

```text
import Benitoite.Hash

function fingerprint(text: String): String
  return Hash.sha256(String.toUTF8(text)) |> Bytes.toHex(_)
end function
```

## 未決事項

- [OPEN-043](../open-issues.md#open-043): UTF-8 以外の文字コードとの変換と、Base64 以外の符号化
- [OPEN-062](../open-issues.md#open-062): 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現（R08）
