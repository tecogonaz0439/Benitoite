# テキストとデータの処理

## 目的と範囲

テキストとデータを扱う純粋なモジュール（`Benitoite.Path`・`Benitoite.Json`・`Benitoite.Regex`・`Benitoite.Csv`・`Benitoite.Time`・`Benitoite.Encoding`・`Benitoite.Hash`）の範囲、型、関数を定める。

各モジュールの実装に使うクレートも示す。

## 前提

本章のモジュールは、どれも IO を行わない純粋なモジュールであり、prelude に入らない。使うには `import Benitoite.Unofficial.Json` のように取り込む（[標準ライブラリ](03-06-stdlib.md)の「名前空間と prelude（初回リリース版）」）。ファイルを読み書きする操作は[IO のモジュール](03-07-io-modules.md)の `File` で行い、本章のモジュールは読み書きした文字列やバイト列を扱う。標準ライブラリの作り方は[ライブラリの構成](03-01-library-structure.md)で定める。

## 仕様

関数一覧の表の `f(a, b)` は、関数とパラメータを示す記法である。実際のコードでは、複数の引数を取る通常の関数は宣言のパラメータ名を付けて名前付きで呼ぶ。

### 各モジュールの範囲

初回リリース版では、本章のモジュールはどれも非公式のモジュールであり、`import Benitoite.Unofficial.Json` の形で取り込む（[標準ライブラリ](03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」）。本章は、`Unofficial` を挟まない名前（`Benitoite.Json`）で書く。

【方針】各モジュールには、次の機能を入れる。

| モジュール | 機能 | 実装 |
|---|---|---|
| `Benitoite.Path` | パスの結合、親のディレクトリ・ファイルの名前・拡張子への分解、正規化（`.` と `..` の除去）。文字列の操作だけを行い、ファイルシステムを読まない | Rust の標準ライブラリ |
| `Benitoite.Json` | JSON の値を表す型、文字列からの解析、文字列化（整形あり・なし） | `serde_json`・`serde_core` |
| `Benitoite.Regex` | 正規表現の値の型（組み立てると失敗しうるので `Result` で返す）、照合、検索、置換、分割 | `regex` |
| `Benitoite.Csv` | CSV の解析と書き出し | `csv-core` |
| `Benitoite.Time` | 時刻の型、ISO 8601 の形の書式と解析、UTC と時差（オフセット）での表示 | `jiff` |
| `Benitoite.Encoding` | Base64 の符号化と復号（`Bytes` と `String` の間）。16 進数は `Bytes.toHex`・`Bytes.fromHex`（[標準ライブラリ](03-06-stdlib.md)）で行う | `base64` |
| `Benitoite.Hash` | SHA-256 | `sha2` |

- 【方針】`Benitoite.Regex` は、照合の時間が入力の長さに比例するエンジン（`regex` クレート）を使う。このクレートは、先読み・後読みと後方参照を持たない代わりに、最悪の場合の照合の時間を、正規表現の大きさと入力の長さの積に比例する範囲に抑える（`regex` クレートの README）。利用者が渡した正規表現で、照合の時間が爆発することはない。
- 【方針】`Benitoite.Time` は、IANA のタイムゾーンの名前（`Asia/Tokyo` など）を扱わない。時刻は UTC と、時差を指定した表示だけで扱う。
- UTF-8 以外の文字コードとの変換は、初回リリース版に含めない。

【方針】初回リリース版には、gzip、URL の解析、YAML・TOML・XML、SQLite を入れない。

### 共通の規則

【方針】本章のモジュールに共通する規則は次のとおりである。

- 本章の型は、モジュールの名前で修飾して書く（`Json.Value`、`Regex.Pattern`）。構成子は型の名前でも修飾して書く（`Json.Value.Null`）。レコードのフィールドは、型のモジュールの関数で取り出す（`Json.ParseError.line(e)`）。
- 入力の形が正しくないことによる失敗は `Result.Error` で返す。失敗の値の型は、モジュールごとの `ParseError`・`ConversionError` のレコードか、人間が読める理由の `String` である。理由の文面は処理系の版によって変わりうる。
- 文字列の位置は、名前に単位を含める（[基本型の意味論](../01-spec/01-04-types-basic.md)の「String」）。本章でバイト位置を返すものは、名前に `byte` を含める。
- 本章の関数は、どれも純粋であり、エフェクトを持たない。関数を引数にとる関数だけが、受け取った関数のエフェクト変数を持つ。

### Path

【方針】`Benitoite.Path` は、パスを `String` のまま扱い、文字列の操作だけで結合と分解を行う。ファイルシステムを読まないので、シンボリックリンクを解決せず、パスが指すものがあるかも確かめない。区切りと根の書き方は、処理系を動かしている OS の規則に従う（Unix では `/`、Windows では `\` と `/` の両方を区切りとし、`C:` などの接頭辞を根の一部とする）。

| 関数 | 型 | 値 |
|---|---|---|
| `Path.join(base, child)` | `function(base: String, child: String) -> String` | `base` の後に区切りを挟んで `child` を続けたパス。`base` が区切りで終わるときは区切りを重ねない。`base` が空なら `child`。`child` が絶対パスなら `child` |
| `Path.joinAll(parts)` | `function(parts: List[String]) -> String` | `parts` を先頭から順に `Path.join` でつないだパス。空のリストなら `""` |
| `Path.parent(p)` | `function(p: String) -> Option[String]` | 最後の構成要素を除いたパス。根だけのパスと空のパスなら `Option.None` |
| `Path.fileName(p)` | `function(p: String) -> Option[String]` | 最後の構成要素。最後が `..` のとき、`.` だけのとき、根だけのとき、空のときは `Option.None` |
| `Path.stem(p)` | `function(p: String) -> Option[String]` | `Path.fileName(p)` から、最後の `.` とその後を除いた部分。`.` で始まり、ほかに `.` を含まない名前（`.bashrc`）は、名前全体 |
| `Path.extension(p)` | `function(p: String) -> Option[String]` | `Path.fileName(p)` の最後の `.` より後の部分（`.` を含まない）。拡張子がなければ `Option.None` |
| `Path.withExtension(p, extension)` | `function(p: String, extension: String) -> String` | 拡張子を `extension` に替えたパス。`extension` が `""` なら拡張子を除く。ファイルの名前がないパス（空、根、`.`、最後が `..`）は、そのまま返す。`extension` が区切りを含むときは、実行時エラー（引数が定義域の外） |
| `Path.isAbsolute(p)` | `function(p: String) -> Boolean` | 絶対パスか |
| `Path.components(p)` | `function(p: String) -> List[String]` | 構成要素の並び。絶対パスでは、先頭に根（Unix では `/`）を置く。`.` の構成要素と、重なった区切りは除く |
| `Path.normalize(p)` | `function(p: String) -> String` | `.` の構成要素を除き、`..` を直前の構成要素と打ち消したパス。打ち消す構成要素がない `..` は、相対パスでは残し、絶対パスでは除く。結果が空なら `"."` |

- `Path.normalize` は字面だけで打ち消すので、シンボリックリンクを含むパスでは、ファイルシステムの上の同じ場所を指すとは限らない。シンボリックリンクを解決した絶対パスは `File.canonicalize`（[IO のモジュール](03-07-io-modules.md)）で得る。
- `Path.join` は、`child` が空なら `base` の後に区切りを付けたパスを返す（`Path.join(base: "a", child: "")` は `"a/"`。`base` が空か区切りで終わるときは `base` のまま）。
- 相対パスを絶対パスにするには、`Process.workingDirectory`（[IO のモジュール](03-07-io-modules.md)）と `Path.join` を組み合わせる。

### Json

【方針】`Benitoite.Json` は、JSON の値を代数的データ型 `Json.Value` で表す。

```text
data Value
  Null
  Boolean(Boolean)
  Integer(Integer)
  Float(Float)
  String(String)
  Array(List[Value])
  Object(Map[String, Value])
end data

@extensible
record ParseError
  line: Integer
  column: Integer
  message: String
end record
```

【決定】`Json.ParseError` は `@extensible` を付けたレコードである。標準ライブラリの外からの `match` には、将来の形を覆うガードのない変数または `_` の分岐を必要とし、レコードパターンで分解する `bind` は拒否する。構築・更新・getter の契約と、現在の欄は変えない。欄の追加を互換とする保証は含まない（[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)の「拡張可能な型」）。理由: 解析の失敗を表す型にも、既知の分解形だけを前提にしない使用条件を適用するためである。

【決定】`Json.ParseError` の `Trait.Show` の実装は、Json のモジュールに置く。同モジュールは `Benitoite.Trait` を import する。`Show.show` は `ParseError.message` の文字列をそのまま返し、行番号・列番号や引用符を加えない。

- 小数点と指数を持たない数で、`Integer` の範囲に収まるものは `Json.Value.Integer`、それ以外の数は `Json.Value.Float` とする。`Float` の範囲も超える数は、解析の誤りとする。整数か浮動小数点かは数の元の字面で決めるので、`-0` は `Json.Value.Integer(0)`、`-0.0` は `Json.Value.Float(-0.0)` になる。絶対値が小さすぎて 0 に丸められる数は誤りにせず、符号を保った 0 の `Json.Value.Float` にする（`1e-400` は `Json.Value.Float(0.0)`、`-1e-400` は `Json.Value.Float(-0.0)`）。`Float.parse` と同じである（[基本型の意味論](../01-spec/01-04-types-basic.md)）。
- オブジェクトは `Map` で表すので、メンバは鍵の順序で並ぶ。入力に同じ鍵が二つ以上あれば、後のメンバの値を使う（`Map.fromList` と同じ）。鍵はどの文字列でもよく、鍵の文字列によってメンバの値の読み方を変えない。
- 入力に誤りが複数あるときは、入力の先頭から読んで最初の誤りを `Json.ParseError` として返す。捨てられる重複した鍵の値の中にある範囲外の数も誤りとする。
- `Json.Value` は等値の型である。`Json.Value.Float` を含むので、鍵の型ではない。
- `line` と `column` は 1 から数える。`column` は、その行の中の文字位置に 1 を足した値である。誤りの位置は、誤りを見つけた文字の位置である。ただし、数が `Float` の範囲を超える誤りは、その数の最初の文字の位置とする。入力が途中で終わった誤り（閉じていない配列・オブジェクト・文字列、値のない入力）は、入力の最後の文字の直後の位置とする。行の区切りは LF だけとする。

| 関数 | 型 | 値 |
|---|---|---|
| `Json.parse(text)` | `function(text: String) -> Result[Json.Value, Json.ParseError]` | `text` を JSON として読んだ値。前後の空白を許す |
| `Json.stringify(value)` | `function(value: Json.Value) -> String` | 空白を入れない JSON の文字列 |
| `Json.stringifyPretty(value)` | `function(value: Json.Value) -> String` | 改行を入れ、入れ子ごとに 2 個の空白で字下げした JSON の文字列 |
| `Json.get(value, k)` | `function(value: Json.Value, k: String) -> Option[Json.Value]` | `value` がオブジェクトなら、`k` のメンバの値。オブジェクトでないか、`k` がなければ `Option.None` |
| `Json.at(value, index)` | `function(value: Json.Value, index: Integer) -> Option[Json.Value]` | `value` が配列なら、位置 `index`（0 から数える）の要素。配列でないか、範囲の外なら `Option.None` |
| `Json.asString(value)` | `function(value: Json.Value) -> Option[String]` | `Json.Value.String` の中身 |
| `Json.asInteger(value)` | `function(value: Json.Value) -> Option[Integer]` | `Json.Value.Integer` の中身 |
| `Json.asFloat(value)` | `function(value: Json.Value) -> Option[Float]` | `Json.Value.Float` の中身。`Json.Value.Integer` なら `Float` に変換した値 |
| `Json.asBoolean(value)` | `function(value: Json.Value) -> Option[Boolean]` | `Json.Value.Boolean` の中身 |
| `Json.asArray(value)` | `function(value: Json.Value) -> Option[List[Json.Value]]` | `Json.Value.Array` の中身 |
| `Json.asObject(value)` | `function(value: Json.Value) -> Option[Map[String, Json.Value]]` | `Json.Value.Object` の中身 |

- `Json.stringify` と `Json.stringifyPretty` は、メンバを鍵の順序で書くので、同じ値からは同じ文字列を作る。文字列の中の制御文字、`"`、`\` はエスケープする。それ以外の文字は、エスケープせずにそのまま書く。
- `Json.stringify` と `Json.stringifyPretty` は、有限の `Float` を、必ず小数点（`.`）か指数を含む形で書く（`1.0`、`-0.0`、`1e+300` など）。書いた文字列を読み直すと、同じ `Json.Value.Float` になる。
- JSON は NaN と無限大を表せない。`Json.stringify` と `Json.stringifyPretty` は、これらの `Float` を `null` と書く。値の失敗を返さないのは、文字列化をどの値にも使えるようにするためである。
- 入力は `String` なので、正しくない UTF-8 は `Json.parse` に届かない。ファイルの内容が正しい UTF-8 でないときは、`File.readText` が失敗する。

```text
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.Json

function totalAmount(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  bind parsed <- try Json.parse(text) |> Result.mapError(r: _, f: lambda(error) return Json.ParseError.message(error)) or return
  bind items <- Json.asArray(parsed) |> Option.unwrapOr(o: _, fallback: [])
  return Result.Ok(List.fold(xs: items, initial: 0, f: lambda(acc, value)
    return match Json.get(value: value, k: "amount") with
      case Option.Some(Json.Value.Integer(n)) -> acc + n
      case otherFields -> acc
    end match
  end lambda))
end function
```

### Regex

【方針】`Benitoite.Regex` は、組み立てた正規表現を中身を見せない型 `Regex.Pattern` で、一つの一致を中身を見せない型 `Regex.Match` で表す。`Regex.Match` は、一致の全体と捕獲グループの位置を持つ。どちらの型も等値の型ではない。

| 関数 | 型 | 値 |
|---|---|---|
| `Regex.compile(source)` | `function(source: String) -> Result[Regex.Pattern, String]` | `source` を組み立てた正規表現。構文が正しくなければ、理由の文字列の `Result.Error` |
| `Regex.isMatch(pattern, text)` | `function(pattern: Regex.Pattern, text: String) -> Boolean` | `text` のどこかに一致する部分があるか |
| `Regex.find(pattern, text)` | `function(pattern: Regex.Pattern, text: String) -> Option[Regex.Match]` | 最も左で始まる一致 |
| `Regex.findAll(pattern, text)` | `function(pattern: Regex.Pattern, text: String) -> List[Regex.Match]` | 重ならない一致を、左から順に並べたリスト |
| `Regex.matchText(m)` | `function(m: Regex.Match) -> String` | 一致した部分の文字列 |
| `Regex.matchByteStart(m)` | `function(m: Regex.Match) -> Integer` | 一致した部分の始まりのバイト位置 |
| `Regex.matchByteEnd(m)` | `function(m: Regex.Match) -> Integer` | 一致した部分の終わりのバイト位置 |
| `Regex.group(m, index)` | `function(m: Regex.Match, index: Integer) -> Option[String]` | 番号 `index` の捕獲グループに一致した部分。0 は一致の全体。グループがないか、一致に加わらなかったときは `Option.None` |
| `Regex.namedGroup(m, name)` | `function(m: Regex.Match, name: String) -> Option[String]` | 名前 `name` の捕獲グループ（`(?P<name>…)`）に一致した部分 |
| `Regex.replaceFirst(pattern, text, replacement)` | `function(pattern: Regex.Pattern, text: String, replacement: String) -> String` | 最初の一致を `replacement` に置き換えた文字列 |
| `Regex.replaceAll(pattern, text, replacement)` | `function(pattern: Regex.Pattern, text: String, replacement: String) -> String` | すべての一致を `replacement` に置き換えた文字列 |
| `Regex.replaceAllWith(pattern, text, f)` | `function[effect E](pattern: Regex.Pattern, text: String, f: function(matched: Regex.Match) -> String uses E) -> String uses E` | すべての一致を、その一致を `f` に渡した値に置き換えた文字列 |
| `Regex.split(pattern, text)` | `function(pattern: Regex.Pattern, text: String) -> List[String]` | 一致を区切りとして分けた部分のリスト |

- `Regex.matchByteStart` と `Regex.matchByteEnd` は、照合した文字列の中のバイト位置（[基本型の意味論](../01-spec/01-04-types-basic.md)）であり、一致した部分は半開区間 `[matchByteStart, matchByteEnd)` である。`String.byteSlice` にそのまま渡せる。
- 正規表現の構文は `regex` クレートの構文である。先読み・後読みと後方参照は書けない。大文字と小文字を区別しない照合などは、`(?i)` のような正規表現の中の指定で行う。
- 照合の時間は、最悪で、一回の照合（`Regex.isMatch`・`Regex.find`・`Regex.replaceFirst`）では入力の長さとパターンの大きさの積に比例し、すべての一致を求める照合（`Regex.findAll`・`Regex.replaceAll`・`Regex.replaceAllWith`・`Regex.split`）では入力の長さの 2 乗とパターンの大きさの積に比例する。一致ごとの探索が入力の終わりまで走査しうるからである（出典: `regex` クレート 1.13.1 の文書の「Iterating over matches」）。処理系は、入力の長さと照合の時間に上限を設けない。信頼できない入力とパターンの両方ですべての一致を求めると、2 乗の時間がかかりうる。
- `Regex.replaceFirst` と `Regex.replaceAll` の `replacement` は、書いたとおりの文字列として扱い、`$1` のようなグループの参照を展開しない。Benitoite の文字列リテラルでは `$` が文字列補間を始めるので、参照の記法を持ち込むと書き誤りを招く。グループを使って置き換えるときは、`Regex.replaceAllWith` と `Regex.group` を使う。
- `Regex.findAll`・`Regex.replaceAll`・`Regex.replaceAllWith`・`Regex.split` は、標準ライブラリのソースの末尾呼び出しで繰り返す。一回の探索は、入力全体と開始のバイト位置を受け取る非公開の組み込みの関数で行う。`findAt` は捕獲グループを含む一つの `Match`、`spanAt` は一致の範囲だけを返す。入力を切り出さずに探すので、`\b`・`^` などの前後の文脈を保つ。直前の一致の終わりと同じ位置の空の一致は捨て、次の文字の境目から探し直す。入力の終わりでは探し直さずに一致なしとする。ほかの公開の関数は組み込みで実装する。非公開の組み込みの関数 `Regex.maxStringBytes` は、処理系の文字列の上限（バイト）を返す。
- 繰り返す照合では、一致の間の呼び出しで中断の要求と取り消しを調べ、予算を使い切るとタスクを切り替える。このため、Ctrl-C と `Task.withTimeout` の取り消しが一致の間で効く（[仮想機械](../02-impl/02-08-vm.md)の「タスクの切り替え」）。一回の探索の途中では中断も取り消しも調べず、最悪の照合の時間は変わらない。理由: 組み込みの関数の中ではタスクを切り替えず、繰り返しをソースの呼び出しに移すことで既存の切り替えの規則を使えるからである。
- `Regex.replaceAllWith` は、一致を一つ求めるごとに、その一致を左から順に `f` に渡す（[標準ライブラリ](03-06-stdlib.md)の「関数を引数にとる関数の共通の規則」）。置換結果は、元の文字列の一致の間の部分と置き換えた文字列を 4,096 部分ごとに `String.join` でつなぎ、最後にまとまりをもう一度つなぐ。`Regex.replaceAll` も同じ組み立て方を使う。結合では各部分のバイトを二回写す。入力の切り出しも各部分を一度ずつ写すだけなので、組み立ては一致の数に対して 2 乗にならない。
- `Regex.findAll`・`Regex.split` の結果のリストが 2^24 要素を超えるときは、組み立ての途中で `List.append` が資源の不足を返す。報告の関数の名前は `List.append` になる。置換の部分の累積バイト数を各部分の追加時に更新し、2^30 バイトを超えた時点で結合を試す。この上限の値は `Regex.maxStringBytes` から得る。理由: 処理系の定数と標準ライブラリの判定の値が食い違うことを防ぐためである。まとまりか最後の `String.join` が資源の不足を返し、報告の関数の名前は `String.join` になる。`Regex.replaceAllWith` では、止まる前の一致には `f` を呼ぶ。一回の `findAt` が作る `Match` は一つだけであり、全一致の捕獲グループを一度に確保しない（[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」）。
- `Regex.compile` が返す誤りの文面は、4 KiB（4,096 バイト）以下とする。長い文面は正規表現の全文と位置の表示を省き、`regex parse error:` の行、`(pattern omitted; error message truncated)` の行、元の文面の最後の行（誤りの種類）を残す。それでも長ければ、最後の行を文字の境目で切って全体を 4 KiB 以下にする。短い文面は変えない。理由: 正規表現の長さ自体に新しい上限を設けず、診断に使う値の大きさを抑えるためである。切り詰める前に外部クレートが作る一時の表示用文字列の大きさは、この上限では抑えない。
- 正規表現は、バックスラッシュを多く含むので、raw 文字列（`r"\d+"`。[字句構造](../01-spec/01-01-lexical.md)）で書くことを勧める。
- 【方針】処理系は、検査の段で正規表現の構文を確かめない。`Regex.compile` の引数が文字列リテラルか定数式であっても、組み立ては実行時に行い、構文の誤りは `Regex.compile` が返す `Result.Error` で分かる。処理系の検査の段と標準ライブラリの個々の関数との結び付きを、初回リリース版ではできるだけ少なくするためであり、設計原則 1 に対する例外である。

```text
import Benitoite.Unofficial.Regex

function extractDates(text: String) -> Result[List[String], String]
  bind pattern <- try Regex.compile(r"\d{4}-\d{2}-\d{2}") or return
  return Result.Ok(Regex.findAll(pattern: pattern, text: text) |> List.map(xs: _, f: lambda(value) return Regex.matchText(value)))
end function
```

### Json.Codec

【決定】`Benitoite.Unofficial.Json.Codec` は、通常の `Result` を返す純粋な変換を提供する。`PathPart` は `Field(String)`・`Index(Integer)`・`Key(String)`、`ConversionError` は `path: List[PathPart]`・`expected: String`・`found: String`・`reason: String` の公開レコードとする。`ConversionError` には `@extensible` を付ける。`Trait.Show` は外側からの経路と expected・found を表示し、reason と入力の値全体は自動で表示しない。理由: 変換に失敗した位置と種類を、入力の内容を複製せずに確認できるようにするためである。

基本型の `encodeString/decodeString`・`encodeBoolean/decodeBoolean`・`encodeInteger/decodeInteger`・`encodeFloat/decodeFloat` は、対応する `Json.Value` の構成子だけを変換する。Integer と Float の暗黙の相互変換は行わず、Float の符号化・復号の両方で NaN と無限大を拒否する。

| 関数 | 引数と変換 |
|---|---|
| `encodeList[T]` / `decodeList[T]` | `value` と純粋な `encode` / `decode` を取り、添字順で処理する。最初の失敗へ `Index` を前置する |
| `encodeMap[T]` / `decodeMap[T]` | String 鍵の Map を鍵順で処理し、最初の失敗へ `Key` を前置する |
| `encodeOption[T]` / `decodeOption[T]` | None は Null、Some は要素の変換とする。復号では Null を None とする |
| `decodeObject` | Object を取り出す。種類の不一致は空の経路の Error とする |
| `decodeField[T]` | `members`・`key`・`decode`・ゼロ引数の `decodeMissing` を取り、存在の有無で一方だけを呼ぶ。失敗へ JSON キーの `Field` を前置する |
| `missing[T]` | 必須欄の欠落を Error とする。欄の経路は呼び出し側が付ける |
| `rejectExtra` | 全欄の変換後に呼び、`keys` にない最初の鍵を鍵順で拒否する。経路には `Key` を使い、入力の鍵を引用・エスケープして表示する |
| `kind`・`error`・`prepend` | 入力内容を含めない種類名、相対経路のエラーの構築、外側の経路の追加を行う |

コンテナへ渡す関数の契約名は `value`、戻り値は `Result[..., ConversionError]` とする。各コンテナの変換も Result を返し、最初の失敗の後に残りの要素を変換しない。欄の欠落と Null の扱いは別に指定する。自動生成した Option 欄では、両方を None とする。

【決定】外部の [生成道具](../../../tools/derive/README.md) は、型パラメータのない非循環レコードから `encodePerson(value: Person) -> Result[Json.Value, Codec.ConversionError]`・`decodePerson(value: Json.Value) -> Result[Person, Codec.ConversionError]` の形の通常の関数を生成する。型と同じモジュールへ置き、公開かどうかも型に合わせる。別モジュールのレコードには公開の生成関数を持つ target を指定する。

対応する欄は基本四型、レコード、List、String 鍵の Map、区別を失わない Option の組み合わせである。入れ子 Option と、Null を成功として受け入れる要素を持つ Option の自動変換を拒否する。未対応型は欄全体のカスタム変換を要求する。`json.keys` は JSON キーを改名し、同じキーへの重複を拒否する。

レコードの欄は宣言順に変換し、失敗には JSON キーの Field を前置する。必須欄の欠落・Null・種類の不一致を拒否し、暗黙の既定値を入れない。全欄が成功した後に余分なキーを鍵順で拒否する。カスタムの encode/decode は純粋・単相な一引数の関数を対で指定し、必要ならゼロ引数の decodeMissing で欠落の扱いを置き換える。通常の型検査も生成後に行う。カスタムの戻す失敗は相対経路とし、呼び出し側が Field を前置する。

【決定】対応型の値に対し、カスタム変換も往復の条件を満たす場合に `decode(encode(x)) = Ok(x)` を受け入れ条件とする。任意の JSON の字面の保存、重複キーの検出、parse/stringify を挟んだ数の表現の保存は保証しない。ParseError と ConversionError は区別し、文字列の parse と値の decode は利用者が明示して組み合わせる。Codec は Fail を要求せず、型付き失敗を選ぶ場合は利用箇所で `Failure.fromResult` を呼ぶ。

### Csv

【方針】`Benitoite.Csv` は、RFC 4180 の CSV を読み書きする。RFC 4180 との違い（受け付ける入力と、書く行の終わり）は、下の箇条に書く。値はどれも `String` として扱い、数への変換は利用者が `Integer.parse` などで行う。

```text
@extensible
record ParseError
  line: Integer
  message: String
end record
```

【決定】`Csv.ParseError` にも `@extensible` を付ける。外部からの照合・束縛の条件、構築・更新・getter の契約、欄の追加に関する保証の範囲は、`Json.ParseError` と同じである。

【決定】`Csv.ParseError` の `Trait.Show` の実装は、Csv のモジュールに置く。同モジュールは `Benitoite.Trait` を import する。`Show.show` は `ParseError.message` の文字列をそのまま返し、行番号や引用符を加えない。

| 関数 | 型 | 値 |
|---|---|---|
| `Csv.parse(text)` | `function(text: String) -> Result[List[List[String]], Csv.ParseError]` | 行のリスト。各行はフィールドのリスト |
| `Csv.parseWith(text, delimiter)` | `function(text: String, delimiter: Character) -> Result[List[List[String]], Csv.ParseError]` | 区切りを `delimiter`（`'\t'` など）とした `Csv.parse` |
| `Csv.parseWithHeader(text)` | `function(text: String) -> Result[List[Map[String, String]], Csv.ParseError]` | 最初の行を見出しとし、残りの各行を、見出しの名前からフィールドへのマップにしたリスト |
| `Csv.format(rows)` | `function(rows: List[List[String]]) -> String` | `rows` を CSV の文字列にしたもの |
| `Csv.formatWith(rows, delimiter)` | `function(rows: List[List[String]], delimiter: Character) -> String` | 区切りを `delimiter` とした `Csv.format` |

- 行の終わりは、LF、CR LF、CR 単独のどれも受け付ける。入力の先頭の BOM（U+FEFF）は一つだけ読み飛ばす。最後の行の後の改行はあってもなくてもよい。引用符で囲んだフィールドの中の改行と、`""`（引用符一つ）を受け付ける。
- 解析は、RFC 4180 に合わない次の入力も誤りにせず受け付ける。引用符で始まらないフィールドの中の引用符は、そのまま文字として読む（`a"b` は `a"b`）。閉じた引用符の後に、区切り・行の終わり・引用符のどれでもない文字が来るときは、その文字から後をフィールドに加える（後の引用符もそのまま文字として読む。`"abc"x` は `abcx`、`"a"b"c` は `ab"c`）。引用符の使い方で誤りにするのは、閉じていない引用符だけである。理由: 実装に使う `csv-core`（0.1.13）の解析の振る舞いに合わせる（`csv_core::Reader` の状態遷移。csv-core 0.1.13 の `src/reader.rs` の `transition_nfa`）。
- 閉じていない引用符は、解析の誤りとする。`line` は、誤りを含むレコードを始めた行の番号（1 から数える）である。引用符の中の改行でレコードが複数行にまたがるときも、引用符を開いたレコードを始めた行を指す。`Csv.parseWithHeader` で、複数行にまたがるレコードのフィールドの数が見出しと違うときも、そのレコードを始めた行を指す。
- `Csv.parseWithHeader` は、見出しに同じ名前が二つ以上あるとき、見出しとフィールドの数が違う行があるときを、解析の誤りとする。`Csv.parse` は、行ごとにフィールドの数が違ってもよい。
- `Csv.format` は、区切り、引用符、CR、LF を含むフィールドを引用符で囲む。行の終わりは LF とする（RFC 4180 は CR LF とするが、スクリプトが扱うファイルとの揃いを優先する）。空のフィールド一つだけの行（`[""]`）は、引用符で囲んで `""` と書く（`Csv.parse` は空の行を飛ばすので、空の行に書くと読み直したときに行が消える）。フィールドのない行（`[]`）は空の行に書く。最初の行の先頭のフィールドが BOM で始まるときは、そのフィールドを引用符で囲み、読み直したときに BOM が読み飛ばされないようにする。
- `delimiter` に引用符（`"`）、CR、LF を指定すると、実行時エラー（引数が定義域の外。[評価意味論](../01-spec/01-08-evaluation.md)）とする。
- `Csv.parseWith` と `Csv.formatWith` の `delimiter` は ASCII の文字に限る。ASCII でない文字を指定すると、実行時エラー（引数が定義域の外）とする。理由: `Csv.formatWith` で書いたものを、同じ区切りの `Csv.parseWith` で読み戻せるようにするため。

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
| `Time.fromUnixSeconds(seconds)` | `function(seconds: Integer) -> Time.Instant` | 1970-01-01T00:00:00Z から `seconds` 秒後の時刻 |
| `Time.fromUnixMilliseconds(milliseconds)` | `function(milliseconds: Integer) -> Time.Instant` | 同じく `milliseconds` ミリ秒後の時刻 |
| `Time.toUnixSeconds(t)` | `function(t: Time.Instant) -> Integer` | 経過の秒数（負の無限大の向きへ切り捨てる） |
| `Time.toUnixMilliseconds(t)` | `function(t: Time.Instant) -> Integer` | 経過のミリ秒数（負の無限大の向きへ切り捨てる） |
| `Time.addMilliseconds(t, milliseconds)` | `function(t: Time.Instant, milliseconds: Integer) -> Time.Instant` | `t` の `milliseconds` ミリ秒後の時刻 |
| `Time.differenceMilliseconds(a, b)` | `function(a: Time.Instant, b: Time.Instant) -> Integer` | `a` から `b` を引いた経過のミリ秒数（負の無限大の向きへ切り捨てる） |
| `Time.toDateTime(t, offsetMinutes)` | `function(t: Time.Instant, offsetMinutes: Integer) -> Time.DateTime` | 時差 `offsetMinutes` 分の地域で見た `t` の日付と時刻 |
| `Time.fromDateTime(dt)` | `function(dt: Time.DateTime) -> Result[Time.Instant, String]` | `dt` が表す時刻。存在しない日付（2 月 30 日など）や範囲の外の値は `Result.Error`。ただし `offsetMinutes` の範囲の外は実行時エラー（下の箇条） |
| `Time.formatISO8601(t, offsetMinutes)` | `function(t: Time.Instant, offsetMinutes: Integer) -> String` | ISO 8601 の形の文字列（`2026-09-28T12:34:56.789+09:00`）。時差が 0 なら末尾を `Z` にする。秒の端数は、0 でなければ必要な桁まで書く |
| `Time.parseISO8601(text)` | `function(text: String) -> Result[Time.Instant, String]` | ISO 8601 の形の文字列が表す時刻。時差（`+09:00` など）か `Z` を必須とする。受け付ける形は下の箇条 |
| `Time.format(t, offsetMinutes, pattern)` | `function(t: Time.Instant, offsetMinutes: Integer, pattern: String) -> Result[String, String]` | `pattern` の指定に従って書いた文字列。`pattern` に知らない指定があれば `Result.Error` |

- `Time.addMilliseconds` などの計算の結果が `Time.Instant` の範囲を超えたときは、実行時エラーとする（`Integer` の溢れと同じ扱い。[基本型の意味論](../01-spec/01-04-types-basic.md)）。
- `offsetMinutes` は、-1439 以上 1439 以下でなければならない。範囲の外の値を渡すと実行時エラーとする。`Time.fromDateTime` に渡す `Time.DateTime` の `offsetMinutes` も同じである。
- `Time.parseISO8601` は、実装に使う `jiff` の `Timestamp` の解析が受け付ける形を、そのまま受け付ける。表の例の形（`2026-09-28T12:34:56.789+09:00`）のほかに、分と秒の省略、区切りを書かない基本形式、秒を含む時差（±25:59:59 まで）、`[Asia/Tokyo]` のような注記（読み飛ばし、タイムゾーンの名前は解決しない）などを受け付ける。秒の `60` は `59` として読む。解析した時刻が `Time.Instant` の範囲の外なら `Result.Error` とする。
- 【決定】`Time.format` の `pattern` は、strftime の形の指定を使い、次の表の指定だけを受け付ける。表にない指定を含む `pattern` には `Result.Error` を返す。`%` で始まらない文字は、そのまま書く。

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
| `Encoding.base64Encode(b)` | `function(b: Bytes) -> String` | 標準の文字の表（RFC 4648 の 4 節）で、`=` の詰め物を付けた Base64 の文字列 |
| `Encoding.base64Decode(text)` | `function(text: String) -> Result[Bytes, String]` | 標準の文字の表の Base64 を読んだバイト列。`=` の詰め物を必須とする。空白や改行を含むか、形が正しくなければ `Result.Error` |
| `Encoding.base64UrlEncode(b)` | `function(b: Bytes) -> String` | URL とファイルの名前に使える文字の表（RFC 4648 の 5 節）で、詰め物を付けない Base64 の文字列 |
| `Encoding.base64UrlDecode(text)` | `function(text: String) -> Result[Bytes, String]` | URL 用の文字の表の、詰め物のない Base64 を読んだバイト列 |

### Hash

【方針】`Benitoite.Hash` は、SHA-256 のハッシュ値を求める。

| 関数 | 型 | 値 |
|---|---|---|
| `Hash.sha256(b)` | `function(b: Bytes) -> Bytes` | `b` の SHA-256 のハッシュ値（32 バイト） |

`Hash.sha256` は `Bytes` を受け取るので、ファイルのハッシュを求めるにはファイル全体を一つの値に読む。そのため、1 GiB を超えるファイルには使えない（[ランタイム](../02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」）。初回リリース版は、少しずつ計算するハッシュの関数を持たない。

```text
import Benitoite.Unofficial.Hash

function fingerprint(text: String) -> String
  return Hash.sha256(String.toUTF8(text)) |> Bytes.toHex(_)
end function
```
