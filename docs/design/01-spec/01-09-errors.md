# エラー処理

## 目的と範囲

失敗の表し方（`Result`・`Option`）、例外と実行時エラーの扱い、`Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`、IO とネットワークの失敗の種類、標準ライブラリが包むライブラリの誤りとの対応を定める。外部の関数を呼ぶ層は、初回リリース版に含めない。

## 前提

`Option`・`Result` の型と構成子は[代数的データ型とパターンマッチ](01-05-data-types.md)で、それらをつなぐ prelude の関数は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。IO の失敗と `IOError` は[エフェクト](01-07-effects.md)で、実行時エラーによる停止の手順は[評価意味論](01-08-evaluation.md)で定める。

## 仕様

### 失敗の表し方

【方針】失敗は、次の三つに分けて扱う。

| 失敗 | 表し方 | 例 |
|---|---|---|
| 値がないこと | `Option[T]` の `Option.None` | リストの先頭の要素（空のリスト） |
| 回復できる失敗 | `Result[T, E]` の `Result.Error` | ファイルが読めない（`Result[String, IOError]`） |
| スクリプトの誤りか、処理系が扱えない状況 | 実行時エラー | 整数の溢れ、0 による除算（[基本型の意味論](01-04-types-basic.md)） |

呼び出し元が失敗に応じて処理を変えられるべき失敗は、`Option` か `Result` で表す。prelude の関数もこの分け方に従う。失敗しうる IO の関数とネットワークの関数は `Result` を返し、整数の溢れと 0 による除算は実行時エラーとする。

### 例外

【決定】例外を投げて捕まえる仕組み（`throw` と `try { ... } catch` など）は設けない。実行時エラーは捕捉できず、[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」の手順でプログラムを止める。

利用者が定義するエフェクトとハンドラ（[エフェクト](01-07-effects.md)）を使えば、操作を呼んだ位置で計算を打ち切り、ハンドラの側で失敗を処理する形を書ける（[型システム](01-06-type-system.md)の `Abort` の例）。この操作はエフェクトとして関数の型に現れ、処理するハンドラがなければ型検査の誤りになる。実行時エラーを捕捉する手段にはならない。

関数が回復できる失敗を起こしうるかは、戻り値の型で読み取れる。【決定】実行時エラーを起こしうることは、関数の型にもエフェクトにも現れない。実行時エラーはプロセスを異常終了させ、失敗を値で返す版の算術の関数は設けない。

### `Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`

【決定】前置の `try` を、`Result.Error` や `Option.None` をそのまま呼び出し元へ返す構文として設ける。

`try` の規則は次のとおりとする。

- `try e` の `e` の型は、`Result[T, E]` か `Option[T]` でなければならない。`e` の型は、`try e` を含む関数の本体の検査を終えた時点で、`Result` か `Option` のどちらかに決まっていなければならない。決まっていなければ誤りとし、診断は型注釈を書くよう示す。
- 戻り値の型注釈のないラムダの中の `try e` は、ラムダの戻り値の型を、`e` が `Result[T, E]` なら `Result[U, E]` と、`Option[T]` なら `Option[U]` と等しくする（`U` は新しい型変数）。
- `e` が `Result.Ok(v)` か `Option.Some(v)` なら、`try e` の値は `v` である。
- `e` が `Result.Error(x)` なら、`try e` を含む最も内側の関数かラムダの呼び出しを終え、`Result.Error(x)` を返す。`e` が `Option.None` なら、同じく `Option.None` を返す。関数から抜ける点は、`return`（[構文](01-02-syntax.md)の「`return`」）と同じである。
- `Result` に `try` を使えるのは、最も内側の関数かラムダの戻り値の型が `Result[U, E]` で、`E` が `e` の `Result.Error` の型と等しい場合に限る。`Option` に `try` を使えるのは、戻り値の型が `Option[U]` の場合に限る。
- `Result.Error` の型が違うとき（`IOError` と `String` など）は、自動では変換しない。`Result.mapError` で変換してから `try` を使う。この誤りの診断は、`Result.mapError` を使った書き方を修正案として示す。
- `Result` と `Option` の間も自動では変換しない。`Option.okOr` などで変換する。
  - 初回リリース版（`0.0.1`）の処理系には、この誤りの診断（E0441）の修正案が、存在しない関数 `Result.toOption` を示す誤りがある。`Result` から `Option` への変換は `Result.ok` で行う。規則は本節のとおりとし、処理系を直す（docs/todo の TODO-165）。
- `lazy` のブロックの中には、内側のラムダの中を除き、`try` を書けない。`lazy` のブロックは、それを作った関数とは別の時点で評価されるからである（[評価意味論](01-08-evaluation.md)の「明示遅延（初回リリース版）」）。

```text
import Benitoite.Unofficial.IO.File

function loadConfig(path: String) -> Result[Config, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(_, IOError.message)
  bind config <- try parseConfig(text)
  return Result.Ok(config)
end function
```

構文と優先順位は次のとおりとする。

- `try` は式の先頭に書き、右の式全体（パイプを含む）にかかる。どの演算子よりも弱く結び付く。`try x |> f(a)` は `try f(x, a)` である。`try f(x) + 1` は `try (f(x) + 1)` なので、`f(x)` の結果に 1 を足すときは `(try f(x)) + 1` と書くか、`bind` で束縛してから足す。
- 関数の引数の中に書いた `try` は、その引数の式にかかる（`g(try f(x))`）。
- `try` の直後に `{` を書くことは誤りとする（[構文](01-02-syntax.md)の「`Result.Error` と `Option.None` を呼び出し元へ返す構文（初回リリース版）」）。LLM が例外を捕らえる構文のつもりで `try { ... } catch` と書いたときに、例外がないことを示す診断を出すためである。
- 後置の `?` は設けない。`e?` と書いたときは、`try e` と書くよう診断で示す。

`try` は、[字句構造](01-01-lexical.md)と[構文](01-02-syntax.md)に加える。意味は、脱糖の規則として[コア計算と脱糖](01-12-core-calculus.md)で定める。

### IO の失敗の種類

【決定】prelude に、IO の失敗の種類を表す型 `IOErrorKind` と、関数 `IOError.kind` を加える。`IOErrorKind` は構成子を公開する代数的データ型であり、等値の型である。

| 関数 | 型 | 値 |
|---|---|---|
| `IOError.kind(e)` | `function(IOError) -> IOErrorKind` | 失敗の種類 |

【決定】`IOErrorKind` の構成子は次の 9 個とする。各関数が返しうる構成子は[IO のモジュール](../03-interop/03-07-io-modules.md)の「IOErrorKind と関数の対応」で示す。

| 構成子 | 失敗 |
|---|---|
| `IOErrorKind.NotFound` | パスが指すもの、または起動するコマンドがない |
| `IOErrorKind.PermissionDenied` | OS が操作を拒んだ |
| `IOErrorKind.AlreadyExists` | 作ろうとしたものが既にある |
| `IOErrorKind.IsDirectory` | ファイルを求める操作に、ディレクトリを指定した |
| `IOErrorKind.NotDirectory` | ディレクトリを求める操作に、ディレクトリでないものを指定した |
| `IOErrorKind.DirectoryNotEmpty` | 空のディレクトリを求める操作に、空でないディレクトリを指定した |
| `IOErrorKind.InvalidUTF8` | 読んだ内容が正しい UTF-8 でない |
| `IOErrorKind.InvalidInput` | 引数を OS に渡せない（パスに NUL を含むなど） |
| `IOErrorKind.Other` | 上のどれにも当たらない |

```text
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File

function readOrEmpty(path: String) -> String uses File.Read, Console.Write
  return match File.readText(path) with
    case Result.Ok(text) -> text
    case Result.Error(e) -> match IOError.kind(e) with
      case IOErrorKind.NotFound -> ""
      case _ ->
        Console.writeErrorLine(IOError.message(e))
        ""
    end match
  end match
end function
```

`IOError` 自体は中身を見せない型であり、等値の型ではない。

【決定】どの構成子にも当たらない失敗は `IOErrorKind.Other` で表し、分類していない失敗を入れる構成子を別に設けない。`IOErrorKind` の `match` に `_` の分岐を必須にする仕組みは設けず、構成子を加えることは互換性を壊す変更として扱う。メジャーバージョンが 0 の間は、この変更をしてよい。

### ネットワークの失敗の種類（初回リリース版）

【決定】ネットワークの操作（[ネットワークのモジュール](../03-interop/03-09-network.md)）の失敗は、`IOError` ではなく、prelude の型 `NetworkError` で表す。失敗しうるネットワークの関数は `Result[T, NetworkError]` を返す。`NetworkError` は、`IOError` と同じく中身を見せない型であり、等値の型ではない。

| 関数 | 型 | 値 |
|---|---|---|
| `NetworkError.kind(e)` | `function(NetworkError) -> NetworkErrorKind` | 失敗の種類 |
| `NetworkError.message(e)` | `function(NetworkError) -> String` | 失敗の理由を、人間が読める形で表す文字列。文面は定めない |

【決定】`NetworkErrorKind` は、構成子を公開する prelude の代数的データ型であり、等値の型である。構成子は次の 9 個とする。構成子を加えることと `Other` の扱いは、`IOErrorKind` と同じである。

| 構成子 | 失敗 |
|---|---|
| `NetworkErrorKind.HostNotFound` | 名前を解決できない |
| `NetworkErrorKind.ConnectionRefused` | 接続を拒まれた |
| `NetworkErrorKind.ConnectionReset` | 接続が途中で切れた |
| `NetworkErrorKind.TimedOut` | 時間切れ |
| `NetworkErrorKind.AddressInUse` | 待ち受けるアドレスとポートが使われている |
| `NetworkErrorKind.InvalidHTTPData` | 受け取った内容が、HTTP として正しくない |
| `NetworkErrorKind.InvalidInput` | URL やアドレスの形式が正しくない |
| `NetworkErrorKind.PermissionDenied` | OS が操作を拒んだ |
| `NetworkErrorKind.Other` | 上のどれにも当たらない。TLS の証明書の検証の失敗を含む |

`InvalidHTTPData` は HTTP に固有の失敗を表し、ほかの構成子は HTTP に限らないネットワークの失敗を表す。IO とネットワークの両方の失敗を返す関数は、`Result.mapError` でどちらかの型にそろえる。

### 外部のライブラリの誤りとの対応

初回リリース版は、外部のライブラリの関数をスクリプトから呼ぶ層を持たない。標準ライブラリの関数が Rust のクレートを包むときは、クレートの誤りを、その関数の型の `Result` か実行時エラーとして定める（[IO のモジュール](../03-interop/03-07-io-modules.md)、[テキストとデータの処理](../03-interop/03-08-text-and-data.md)）。
