# エラー処理

- 状態: 確定
- 関連ADR: [0006](../decisions/0006-basic-types-semantics.md), [0011](../decisions/0011-io-failure-and-entry-point.md), [0012](../decisions/0012-invalid-utf8-input.md), [0043](../decisions/0043-option-result-rust-names-no-unwrap.md), [0048](../decisions/0048-ioerror-not-equality-type.md), [0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md), [0065](../decisions/0065-ioerror-kind.md), [0077](../decisions/0077-abolish-go-layer.md), [0091](../decisions/0091-acronyms-in-uppercase.md), [0097](../decisions/0097-prefix-try.md), [0099](../decisions/0099-qualified-option-result-constructors.md), [0118](../decisions/0118-effect-handlers.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0137](../decisions/0137-first-release-library-scope.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0144](../decisions/0144-ioerrorkind-constructors.md), [0145](../decisions/0145-network-error.md), [0146](../decisions/0146-runtime-errors-not-in-types.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-040](../open-issues.md#open-040), [OPEN-051](../open-issues.md#open-051)
- 移行元: [設計メモ](../sources/fp-language-design.md) 2.5（エラー）

## 目的と範囲

Result/Option、例外の有無、外部のライブラリの誤りとの対応。

現在の版は、初回リリース版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲のうち、ライブラリの提供方法に依存しない部分を定める。対象は、失敗の表し方、例外と実行時エラーの扱い、`Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`、IO とネットワークの失敗の種類である。初回リリース版には外部の関数の層がない（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。外部の関数（WASM のモジュールの関数）の失敗と `Result`・実行時エラーの対応は、外部の関数を実装する版で定める（[OPEN-051](../open-issues.md#open-051)）。

## 前提

`Option`・`Result` の型と構成子は[代数的データ型とパターンマッチ](01-05-data-types.md)で、それらをつなぐ prelude の関数は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める（[ADR 0043](../decisions/0043-option-result-rust-names-no-unwrap.md)）。IO の失敗と `IOError` は[エフェクト](01-07-effects.md)で、実行時エラーによる停止の手順は[評価意味論](01-08-evaluation.md)で定める。

## 仕様

### 失敗の表し方

【方針】失敗は、次の三つに分けて扱う。

| 失敗 | 表し方 | 例 |
|---|---|---|
| 値がないこと | `Option[T]` の `Option.None` | リストの先頭の要素（空のリスト） |
| 回復できる失敗 | `Result[T, E]` の `Result.Error` | ファイルが読めない（`Result[String, IOError]`） |
| スクリプトの誤りか、処理系が扱えない状況 | 実行時エラー | 整数の溢れ、0 による除算（[基本型の意味論](01-04-types-basic.md)） |

呼び出し元が失敗に応じて処理を変えられるべき失敗は、`Option` か `Result` で表す。prelude の関数もこの分け方に従う。失敗しうる IO の関数と、初回リリース版の失敗しうるネットワークの関数は `Result` を返し（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)、[ADR 0145](../decisions/0145-network-error.md)）、整数の溢れと 0 による除算は実行時エラーとする（[ADR 0006](../decisions/0006-basic-types-semantics.md)）。

### 例外

【決定】例外を投げて捕まえる仕組み（`throw` と `try { ... } catch` など）は設けない。実行時エラーは捕捉できず、[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」の手順でプログラムを止める（[ADR 0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md)）。

初回リリース版の利用者が定義するエフェクトとハンドラ（[エフェクト](01-07-effects.md)）を使えば、操作を呼んだ位置で計算を打ち切り、ハンドラの側で失敗を処理する形を書ける（[型システム](01-06-type-system.md)の `Abort` の例）。この操作はエフェクトとして関数の型に現れ、処理するハンドラがなければ型検査の誤りになる。実行時エラーを捕捉する手段にはならない。

関数が回復できる失敗を起こしうるかは、戻り値の型で読み取れる。【決定】実行時エラーを起こしうることは、関数の型にもエフェクトにも現れない。実行時エラーはプロセスを異常終了させ、失敗を値で返す版の算術の関数は設けない（[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md)）。

### `Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`

【決定】前置の `try` を、`Result.Error` や `Option.None` をそのまま呼び出し元へ返す構文として設ける（[ADR 0097](../decisions/0097-prefix-try.md)）。

`try` の規則は次のとおりとする。

- `try e` の `e` の型は、`Result[T, E]` か `Option[T]` でなければならない。`e` の型は、`try e` を含む関数の本体の検査を終えた時点で、`Result` か `Option` のどちらかに決まっていなければならない。決まっていなければ誤りとし、診断は型注釈を書くよう示す。
- 戻り値の型注釈のないラムダの中の `try e` は、ラムダの戻り値の型を、`e` が `Result[T, E]` なら `Result[U, E]` と、`Option[T]` なら `Option[U]` と等しくする（`U` は新しい型変数）。
- `e` が `Result.Ok(v)` か `Option.Some(v)` なら、`try e` の値は `v` である。
- `e` が `Result.Error(x)` なら、`try e` を含む最も内側の関数かラムダの呼び出しを終え、`Result.Error(x)` を返す。`e` が `Option.None` なら、同じく `Option.None` を返す。関数から抜ける点は、`return`（[構文](01-02-syntax.md)の「`return`」）と同じである。
- `Result` に `try` を使えるのは、最も内側の関数かラムダの戻り値の型が `Result[U, E]` で、`E` が `e` の `Result.Error` の型と等しい場合に限る。`Option` に `try` を使えるのは、戻り値の型が `Option[U]` の場合に限る。
- `Result.Error` の型が違うとき（`IOError` と `String` など）は、自動では変換しない。`Result.mapError` で変換してから `try` を使う。この誤りの診断は、`Result.mapError` を使った書き方を修正案として示す。
- `Result` と `Option` の間も自動では変換しない。`Option.okOr` などで変換する。
- `lazy` のブロックの中には、内側のラムダの中を除き、`try` を書けない。`lazy` のブロックは、それを作った関数とは別の時点で評価されるからである（[評価意味論](01-08-evaluation.md)の「明示遅延（初回リリース版）」）。

```text
import Benitoite.IO.File

function loadConfig(path: String): Result[Config, String] uses File.Read
  let text = try File.readText(path) |> Result.mapError(_, IOError.message)
  let config = try parseConfig(text)
  return Result.Ok(config)
end function
```

構文と優先順位は次のとおりとする。

- `try` は式の先頭に書き、右の式全体（パイプを含む）にかかる。どの演算子よりも弱く結び付く。`try x |> f(a)` は `try f(x, a)` である。`try f(x) + 1` は `try (f(x) + 1)` なので、`f(x)` の結果に 1 を足すときは `(try f(x)) + 1` と書くか、`let` で束縛してから足す。
- 関数の引数の中に書いた `try` は、その引数の式にかかる（`g(try f(x))`）。
- `try` の直後に `{` を書くことは誤りとする（[構文](01-02-syntax.md)の「`Result.Error` と `Option.None` を呼び出し元へ返す構文（初回リリース版）」）。LLM が例外を捕らえる構文のつもりで `try { ... } catch` と書いたときに、例外がないことを示す診断を出すためである。
- 後置の `?` は設けない。`e?` と書いたときは、`try e` と書くよう診断で示す。

`try` は、[字句構造](01-01-lexical.md)と[構文](01-02-syntax.md)に加える。意味は、脱糖の規則として[コア計算と脱糖](01-12-core-calculus.md)で定める。

### IO の失敗の種類

【決定】prelude に、IO の失敗の種類を表す型 `IOErrorKind` と、関数 `IOError.kind` を加える。`IOErrorKind` は構成子を公開する代数的データ型であり、等値の型である（[ADR 0065](../decisions/0065-ioerror-kind.md)）。

| 関数 | 型 | 値 |
|---|---|---|
| `IOError.kind(e)` | `function(IOError) -> IOErrorKind` | 失敗の種類 |

【決定】`IOErrorKind` の構成子は次の 9 個とする（[ADR 0144](../decisions/0144-ioerrorkind-constructors.md)）。各関数が返しうる構成子は[IO のモジュール](../03-interop/03-07-io-modules.md)の「IOErrorKind と関数の対応」で示す。

| 構成子 | 失敗 |
|---|---|
| `IOErrorKind.NotFound` | パスが指すもの、または起動するコマンドがない |
| `IOErrorKind.PermissionDenied` | OS が操作を拒んだ。実行時の権限制御による拒否は、これではなく実行時エラーとする（[エフェクト](01-07-effects.md)） |
| `IOErrorKind.AlreadyExists` | 作ろうとしたものが既にある |
| `IOErrorKind.IsDirectory` | ファイルを求める操作に、ディレクトリを指定した |
| `IOErrorKind.NotDirectory` | ディレクトリを求める操作に、ディレクトリでないものを指定した |
| `IOErrorKind.DirectoryNotEmpty` | 空のディレクトリを求める操作に、空でないディレクトリを指定した |
| `IOErrorKind.InvalidUTF8` | 読んだ内容が正しい UTF-8 でない（[ADR 0012](../decisions/0012-invalid-utf8-input.md)） |
| `IOErrorKind.InvalidInput` | 引数を OS に渡せない（パスに NUL を含むなど） |
| `IOErrorKind.Other` | 上のどれにも当たらない |

```text
import Benitoite.IO.Console
import Benitoite.IO.File

function readOrEmpty(path: String): String uses File.Read, Console.Write
  return case File.readText(path) of
    when Result.Ok(text): text
    when Result.Error(e): case IOError.kind(e) of
      when IOErrorKind.NotFound: ""
      when _:
        Console.writeErrorLine(IOError.message(e))
        ""
    end case
  end case
end function
```

`IOError` 自体は、初回リリース版でも中身を見せない型であり、等値の型ではない（[ADR 0048](../decisions/0048-ioerror-not-equality-type.md)）。

【決定】どの構成子にも当たらない失敗は `IOErrorKind.Other` で表し、分類していない失敗を入れる構成子を別に設けない。`IOErrorKind` の `case` に `_` の分岐を必須にする仕組みは設けず、構成子を加えることは互換性を壊す変更として扱う（[ADR 0144](../decisions/0144-ioerrorkind-constructors.md)）。メジャーバージョンが 0 の間は、この変更をしてよい。`_` の分岐を必須にする仕組みを設けるかは、正式リリース版の前に [OPEN-040](../open-issues.md#open-040) で決める。

### ネットワークの失敗の種類（初回リリース版）

【決定】ネットワークの操作（[ネットワークのモジュール](../03-interop/03-09-network.md)）の失敗は、`IOError` ではなく、prelude の型 `NetworkError` で表す（[ADR 0145](../decisions/0145-network-error.md)）。失敗しうるネットワークの関数は `Result[T, NetworkError]` を返す。`NetworkError` は、`IOError` と同じく中身を見せない型であり、等値の型ではない。

| 関数 | 型 | 値 |
|---|---|---|
| `NetworkError.kind(e)` | `function(NetworkError) -> NetworkErrorKind` | 失敗の種類 |
| `NetworkError.message(e)` | `function(NetworkError) -> String` | 失敗の理由を、人間が読める形で表す文字列。文面は定めない |

【決定】`NetworkErrorKind` は、構成子を公開する prelude の代数的データ型であり、等値の型である。構成子は次の 9 個とする（[ADR 0145](../decisions/0145-network-error.md)）。構成子を加えることと `Other` の扱いは、`IOErrorKind` と同じである。

| 構成子 | 失敗 |
|---|---|
| `NetworkErrorKind.HostNotFound` | 名前を解決できない |
| `NetworkErrorKind.ConnectionRefused` | 接続を拒まれた |
| `NetworkErrorKind.ConnectionReset` | 接続が途中で切れた |
| `NetworkErrorKind.TimedOut` | 時間切れ |
| `NetworkErrorKind.AddressInUse` | 待ち受けるアドレスとポートが使われている |
| `NetworkErrorKind.InvalidHTTPData` | 受け取った内容が、HTTP として正しくない |
| `NetworkErrorKind.InvalidInput` | URL やアドレスの形式が正しくない |
| `NetworkErrorKind.PermissionDenied` | OS が操作を拒んだ。実行時の権限制御による拒否は、これではなく実行時エラーとする（[エフェクト](01-07-effects.md)） |
| `NetworkErrorKind.Other` | 上のどれにも当たらない。TLS の証明書の検証の失敗を含む |

`InvalidHTTPData` は HTTP に固有の失敗を表し、ほかの構成子は HTTP に限らないネットワークの失敗を表す。IO とネットワークの両方の失敗を返す関数は、`Result.mapError` でどちらかの型にそろえる。

### 外部のライブラリの誤りとの対応

設計メモの go.* の層は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。初回リリース版には外部の関数を呼ぶ層を実装しない（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。標準ライブラリの関数がクレートを包むときは、クレートの誤りを、その関数の型の `Result` か実行時エラーとして定める（[IO のモジュール](../03-interop/03-07-io-modules.md)、[テキストとデータの処理](../03-interop/03-08-text-and-data.md)）。後の版の外部の関数（WASM のモジュールの関数。[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）の失敗（トラップ、メモリの不足）と `Result`・実行時エラーの対応は、[OPEN-051](../open-issues.md#open-051) で決める。

## 未決事項

- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細（外部の関数の失敗との対応）
- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（`try` と後置の `?` の比較を含めるか）
- [OPEN-040](../open-issues.md#open-040): 正式リリース版とする条件と、互換性を壊す変更の範囲（`_` の分岐を必須にする仕組み）
