# エラー処理

## 目的と範囲

失敗の表し方（`Result`・`Option`）、例外と実行時エラーの扱い、`Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`、失敗時に終了する処置、IO とネットワークの失敗の種類、標準ライブラリが包むライブラリの誤りとの対応を定める。初回リリース版の後に実験的として加えた外部の関数の失敗も定める。

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

関数が回復できる失敗を起こしうるかは、戻り値の型か `Failure.Fail[E]` のエフェクトで読み取れる。【決定】実行時エラーを起こしうることは、関数の型にもエフェクトにも現れない。実行時エラーはプロセスを異常終了させ、失敗を値で返す版の算術の関数は設けない。

### 型付きの失敗と Result の変換

【決定】`Benitoite.Unofficial.Failure` を明示的に import すると、次の関数を使える。エラー型 `E` に Show や等値比較の制約は要求しない。

| 関数 | 型と動作 |
|---|---|
| `Failure.fromResult(result)` | `function[T, E](result: Result[T, E]) -> T uses Failure.Fail[E]`。引数を一度評価し、Ok の値を返す。Error は元のエラー値を raise へ渡す |
| `Failure.toResult(body)` | `function[T, E, effect Rest](body: function() -> T uses Failure.Fail[E], Rest) -> Result[T, E] uses Rest`。ハンドラの内側で body を一度呼び、成功を Ok、捕捉した失敗を Error として返す |

【決定】toResult の Rest は、シグネチャから定まる NoFail の条件を持つ（[型システム](01-06-type-system.md#型付きの失敗と行の条件)）。他のエフェクトと、返した値の型の内部の潜在エフェクトは消さない。エラー型を確定できないときは、結果の束縛か body の関数型に注釈を書く。関数呼び出しに明示的な型引数は書けない。

【決定】失敗後の続きは実行しない。List.map 全体を toResult の body に入れると、最初の失敗で map を打ち切り、リスト全体の Error を返す。既に行った操作は巻き戻さない。body 内の return と失敗を返す try は、従来どおり最も内側の関数かラムダから抜ける。その戻り値が Result でも、body が正常に返せば toResult はその値を Ok で包む。

【決定】toResult は die・Process.Exit・実行時エラー・資源の不足・中断・取消し・外部のトラップを捕捉しない。打ち切り時の with の解放と、その失敗は[リソース管理](01-10-resources.md)の規則に従う。lazy の本体に未処理の Fail は残せず、純粋性の検査で拒否する。本体内で toResult を使って Result を返す形は許し、その Result を遅延の結果として保存する。

### `Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`

【決定】前置の `try` を、`Result.Error` や `Option.None` をそのまま呼び出し元へ返す構文として設ける。`try e or return` は、同じ処置を明示する形であり、裸の `try e` と同じ型の規則・脱出先・評価を持つ。`or return` は値を取らない。

裸の `try e` の意味は今後も失敗を呼び出し元へ返す処置に固定し、囲む関数の戻り値や位置から終了する処置へ切り替えない。新たな手本では、再利用する関数・ライブラリ・コールバックには `or return`、実行を終える入口には `or die` を基本とする。`main` が Result.Error を返す契約を示す場合や Process.Exit を許さない場合は、入口でも `or return` を使う。

`try e` と `try e or return` の規則は次のとおりとする。

- `try e` の `e` の型は、`Result[T, E]` か `Option[T]` でなければならない。`e` の型は、`try e` を含む関数の本体の検査を終えた時点で、`Result` か `Option` のどちらかに決まっていなければならない。決まっていなければ誤りとし、診断は型注釈を書くよう示す。
- 戻り値の型注釈のないラムダの中の `try e` は、ラムダの戻り値の型を、`e` が `Result[T, E]` なら `Result[U, E]` と、`Option[T]` なら `Option[U]` と等しくする（`U` は新しい型変数）。
- `e` が `Result.Ok(v)` か `Option.Some(v)` なら、`try e` の値は `v` である。
- `e` が `Result.Error(x)` なら、`try e` を含む最も内側の関数かラムダの呼び出しを終え、`Result.Error(x)` を返す。`e` が `Option.None` なら、同じく `Option.None` を返す。関数から抜ける点は、`return`（[構文](01-02-syntax.md)の「`return`」）と同じである。
- `Result` に `try` を使えるのは、最も内側の関数かラムダの戻り値の型が `Result[U, E]` で、`E` が `e` の `Result.Error` の型と等しい場合に限る。`Option` に `try` を使えるのは、戻り値の型が `Option[U]` の場合に限る。
- `Result.Error` の型が違うとき（`IOError` と `String` など）は、自動では変換しない。`Result.mapError` で変換してから `try` を使う。この誤りの診断は、`Result.mapError` を使った書き方を修正案として示す。
- `Result` と `Option` の間も自動では変換しない。`Option` から `Result` へは `Option.okOr`、`Result` から `Option` へは `Result.ok` で変換する。この誤りの診断は、この二つの関数で変換する書き方を修正案として示す。
- `lazy` のブロックの中には、内側の `lambda … end lambda` の本体の中を除き、`try` を書けない。その中のプレースホルダを含む呼び出しの呼ぶ関数と引数は、この例外に当たらない（[構文](01-02-syntax.md)の「部分適用のプレースホルダ」）。`lazy` のブロックは、それを作った関数とは別の時点で評価されるからである（[評価意味論](01-08-evaluation.md)の「明示遅延（初回リリース版）」）。

```text
import Benitoite.Unofficial.IO.File

function loadConfig(path: String) -> Result[Config, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  bind config <- try parseConfig(text) or return
  return Result.Ok(config)
end function
```

構文と優先順位は次のとおりとする。

- `try` は式の先頭に書き、右の式全体（パイプを含む）にかかる。どの演算子よりも弱く結び付く。`try x |> f(b: a) or return` は `try f(a: x, b: a) or return` である。処置の有無によらず、`try f(x) + 1 or return` は `try (f(x) + 1) or return` である。`f(x)` の結果に 1 を足すときは、処置を明示して `(try f(x) or return) + 1` と書くか、`bind` で束縛してから足す。
- 関数の引数の中に書いた `try` は、その引数の式にかかる（`g(try f(x) or return)`）。明示形の入力は同じ深さの `or return` の手前で終わり、処置の後に外側の演算子を続けるときは `(try f(x) or return) + 1` と括弧で囲む。改行と処置の境界は[構文](01-02-syntax.md)の try の節に従う。
- `try` の直後に `{` を書くことは誤りとする（[構文](01-02-syntax.md)の「`Result.Error` と `Option.None` を呼び出し元へ返す構文（初回リリース版）」）。LLM が例外を捕らえる構文のつもりで `try { ... } catch` と書いたときに、例外がないことを示す診断を出すためである。
- 後置の `?` は設けない。`e?` と書いたときは、`try e or return` と書くよう診断で示す。

`try` は、[字句構造](01-01-lexical.md)と[構文](01-02-syntax.md)に加える。意味は、脱糖の規則として[コア計算と脱糖](01-12-core-calculus.md)で定める。

### 失敗時に終了する処置

【決定】`try e or die` と `try e or die(message)` は、入力を一度評価し、`Result.Ok(v)`・`Option.Some(v)` なら v を値とする。失敗側では任意の説明、原因の表示、`Process.exit[T](1)` の順に計算する。囲む関数やラムダの戻り値は任意であり、Result/Option に制約しない。T は成功時の型である。

- 入力は標準の Result/Option でなければならない（E0440）。Result の失敗型 E には標準の `Trait.Show` を要求し、実装不足は E0705、型パラメータの制約不足は E0706 とする。診断は Show の実装か `Result.mapError` による変換を案内する。Option に Show は要求しない。裸と `or return` は従来どおり Show を要求しない。
- 処置は `Process.Exit` を持つ。`uses IO.All` もこのエフェクトを含む。`uses Process.Exit` と書くには `import Benitoite.Unofficial.IO.Process` が要る。内部の標準参照は利用者の名前空間へ Process や Trait を追加せず、局所の exit・show で置き換わらない。die による E0501 は uses と必要な import を案内する。
- 説明は純粋な String 式でなければならない。型の不一致は E0401、エフェクトは E0511、直接の return/try は E0218、外側の継続を再開する resume は E0509 とする。内側のラムダの return は通常の規則に従う。成功時は説明と Show を評価しない。
- Result の原因は Show の結果とする。String の引用符とエスケープは保つ。Option.None の原因は `expected a value, got Option.None` とする。説明なしと空文字列は区別し、空の説明でも原因を残す。説明や Show が実行時エラーなどで停止すれば、その停止を採用し、die の報告を付けない。純粋性は停止性を保証しない。
- 既定の終了操作は状態1で実行を終える。ホストは説明・原因・ソース位置を一度報告し、Console.Write は要求しない。全タスクの取消・リソースの解放・出力の転送は通常の終了経路に従い、解放・転送の失敗は終了状態を変えず補足する。言語のハンドラは通常の Process.Exit として処理でき、処理された呼び出しの報告を後の独立した exit に持ち越さない。

理由: 再利用する関数の失敗の伝播と、入口で原因を示す終了を、戻り値とエフェクトの契約で区別するためである。

### IO の失敗の種類

【決定】prelude に、IO の失敗の種類を表す型 `IOErrorKind` と、関数 `IOError.kind` を加える。`IOErrorKind` は構成子を公開する代数的データ型であり、等値の型である。

| 関数 | 型 | 値 |
|---|---|---|
| `IOError.kind(e)` | `function(e: IOError) -> IOErrorKind` | 失敗の種類 |

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
      case otherKind ->
        Console.writeErrorLine(IOError.message(e))
        ""
    end match
  end match
end function
```

`IOError` 自体は不透明型であり、等値の型ではない。

【決定】どの構成子にも当たらない失敗は `IOErrorKind.Other` で表し、分類していない失敗を入れる構成子を別に設けない。`IOErrorKind` には `@extensible` を付ける。標準ライブラリの外からの照合には、将来の形を覆うガードのない変数または `_` のパターンを必要とする。`Other` は既知の構成子であり、将来の形を覆わない（[代数的データ型とパターンマッチ](01-05-data-types.md)の「拡張可能な型」）。理由: 失敗の種類を追加するときに、利用者のコードが既知の種類だけを前提にしないよう、型の使用条件として検査するためである。

### ネットワークの失敗の種類（初回リリース版）

【決定】ネットワークの操作（[ネットワークのモジュール](../03-interop/03-09-network.md)）の失敗は、`IOError` ではなく、prelude の型 `NetworkError` で表す。失敗しうるネットワークの関数は `Result[T, NetworkError]` を返す。`NetworkError` は、`IOError` と同じく不透明型であり、等値の型ではない。

| 関数 | 型 | 値 |
|---|---|---|
| `NetworkError.kind(e)` | `function(e: NetworkError) -> NetworkErrorKind` | 失敗の種類 |
| `NetworkError.message(e)` | `function(e: NetworkError) -> String` | 失敗の理由を、人間が読める形で表す文字列。文面は定めない |

【決定】`NetworkErrorKind` は、構成子を公開する prelude の代数的データ型であり、等値の型である。構成子は次の 9 個とする。`@extensible` による外部からの照合の条件と `Other` の扱いは、`IOErrorKind` と同じである。

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

【決定】外部の関数のトラップ、コンポーネントの ABI 違反、資源の上限以外のインスタンス化の失敗は、`Result.Error` に変換せず、実行時エラーとして停止する。燃料・メモリ・表の要素数・コアのインスタンスとメモリと表の数・値の受け渡しの予算の上限は資源の不足として停止する。宣言の戻り値の `Result` は通常の値として扱う（[外部の関数](../03-interop/03-10-external-functions.md)）。標準ライブラリの関数が Rust のクレートを包むときは、クレートの誤りを、その関数の型の `Result` か実行時エラーとして定める（[IO のモジュール](../03-interop/03-07-io-modules.md)、[テキストとデータの処理](../03-interop/03-08-text-and-data.md)）。
