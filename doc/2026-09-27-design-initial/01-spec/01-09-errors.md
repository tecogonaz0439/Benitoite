# エラー処理

- 状態: 草稿
- 関連ADR: [0006](../decisions/0006-basic-types-semantics.md), [0011](../decisions/0011-io-failure-and-entry-point.md), [0012](../decisions/0012-invalid-utf8-input.md), [0043](../decisions/0043-option-result-rust-names-no-unwrap.md), [0048](../decisions/0048-ioerror-not-equality-type.md), [0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md), [0065](../decisions/0065-ioerror-kind.md), [0077](../decisions/0077-abolish-go-layer.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-026](../open-issues.md#open-026), [OPEN-029](../open-issues.md#open-029), [OPEN-034](../open-issues.md#open-034), [OPEN-035](../open-issues.md#open-035)
- 移行元: [設計メモ](../sources/fp-language-design.md) 2.5（エラー）

## 目的と範囲

Result/Option、例外の有無、外部のライブラリの誤りとの対応。

現在の版は、v1（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲のうち、ライブラリの提供方法に依存しない部分を定める。対象は、失敗の表し方、例外と実行時エラーの扱い、`Err` を呼び出し元へ返す構文 `?`、IO の失敗の種類である。外部のライブラリの誤りと `Result`・実行時エラーの対応は、v1 のライブラリの提供方法とともに定める（[OPEN-035](../open-issues.md#open-035)）。

## 前提

`Option`・`Result` の型と構成子は[代数的データ型とパターンマッチ](01-05-data-types.md)で、それらをつなぐ prelude の関数は[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める（[ADR 0043](../decisions/0043-option-result-rust-names-no-unwrap.md)）。IO の失敗と `IoError` は[エフェクト](01-07-effects.md)で、実行時エラーによる停止の手順は[評価意味論](01-08-evaluation.md)で定める。

## 仕様

### 失敗の表し方

【方針】失敗は、次の三つに分けて扱う。

| 失敗 | 表し方 | 例 |
|---|---|---|
| 値がないこと | `Option[T]` の `None` | リストの先頭の要素（空のリスト） |
| 回復できる失敗 | `Result[T, E]` の `Err` | ファイルが読めない（`Result[String, IoError]`） |
| スクリプトの誤りか、処理系が扱えない状況 | 実行時エラー | 整数の溢れ、0 による除算（[基本型の意味論](01-04-types-basic.md)） |

呼び出し元が失敗に応じて処理を変えられるべき失敗は、`Option` か `Result` で表す。prelude の関数もこの分け方に従う。失敗しうる IO の関数は `Result` を返し（[ADR 0011](../decisions/0011-io-failure-and-entry-point.md)）、整数の溢れと 0 による除算は実行時エラーとする（[ADR 0006](../decisions/0006-basic-types-semantics.md)）。

### 例外

【決定】例外を投げて捕まえる仕組み（`throw` と `try`・`catch` など）は設けない。実行時エラーは捕捉できず、[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」の手順でプログラムを止める（[ADR 0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md)）。

関数が回復できる失敗を起こしうるかは、戻り値の型で読み取れる。実行時エラーを起こしうることは、関数の型に現れない。型やエフェクトで表すかは【未決】である（[OPEN-026](../open-issues.md#open-026)）。

### `Err` を呼び出し元へ返す構文 `?`

【方針】後置の `?` を、`Err` や `None` をそのまま呼び出し元へ返す構文として設ける。この方針は、[OPEN-012](../open-issues.md#open-012) の測定で、`?` を使うスクリプトと `Result.andThen` などでつなぐスクリプトのどちらを LLM が誤りにくいかを確かめてから確定する（[OPEN-029](../open-issues.md#open-029)）。

`?` の規則は次のとおりとする。

- `e?` の `e` の型は、`Result[T, E]` か `Option[T]` でなければならない。`e` の型は、`e?` を含む関数の本体の検査を終えた時点で、`Result` か `Option` のどちらかに決まっていなければならない。決まっていなければ誤りとし、診断は型注釈を書くよう示す。
- 戻り値の型注釈のないラムダの中の `e?` は、ラムダの戻り値の型を、`e` が `Result[T, E]` なら `Result[U, E]` と、`Option[T]` なら `Option[U]` と等しくする（`U` は新しい型変数）。
- `e` が `Ok(v)` か `Some(v)` なら、`e?` の値は `v` である。
- `e` が `Err(x)` なら、`e?` を含む最も内側の関数かラムダの呼び出しを終え、`Err(x)` を返す。`e` が `None` なら、同じく `None` を返す。
- `Result` に `?` を使えるのは、最も内側の関数かラムダの戻り値の型が `Result[U, E]` で、`E` が `e` の `Err` の型と等しい場合に限る。`Option` に `?` を使えるのは、戻り値の型が `Option[U]` の場合に限る。
- `Err` の型が違うとき（`IoError` と `String` など）は、自動では変換しない。`Result.mapErr` で変換してから `?` を使う。この誤りの診断は、`Result.mapErr` を使った書き方を修正案として示す。
- `Result` と `Option` の間も自動では変換しない。`Option.okOr` などで変換する。
- `lazy` のブロックの中には、内側のラムダの中を除き、`?` を書けない。`lazy` のブロックは、それを作った関数とは別の時点で評価されるからである（[評価意味論](01-08-evaluation.md)の「明示遅延（v1）」）。

```text
fn loadConfig(path: String) -> Result[Config, String] uses IO {
  let text = File.readText(path) |> Result.mapErr(_, IoError.message)?
  let config = parseConfig(text)?
  Ok(config)
}
```

構文と優先順位は次のとおりとする。

- `?` は、関数の呼び出しの括弧と同じ位置に書く後置の演算子であり、どの二項演算子より強く結び付く。`f(x)? + 1` は `(f(x)?) + 1` である。
- パイプの右辺の末尾に書いた `?` は、パイプを展開した後の式に付く。`x |> f(a)?` は `f(x, a)?` に、`x |> g(_, b)?` は `g(x, b)?` になる。パイプを重ねた途中に書いた `?` も、その段までを展開した式に付く（`x |> f? |> g` は `g(f(x)?)`）。

`?` は、[字句構造](01-01-lexical.md)と[構文](01-02-syntax.md)に加える。意味は、脱糖の規則として[コア計算と脱糖](01-12-core-calculus.md)で定める。

### IO の失敗の種類

【決定】prelude に、IO の失敗の種類を表す型 `IoErrorKind` と、関数 `IoError.kind` を加える。`IoErrorKind` は構成子を公開する代数的データ型であり、等値の型である（[ADR 0065](../decisions/0065-ioerror-kind.md)）。

| 関数 | 型 | 値 |
|---|---|---|
| `IoError.kind(e)` | `fn(IoError) -> IoErrorKind` | 失敗の種類 |

【方針】`IoErrorKind` の構成子は次のとおりとする。構成子の一覧は、v1 のファイルとプロセスの API を定めるときに確定する（[OPEN-034](../open-issues.md#open-034)）。

| 構成子 | 失敗 |
|---|---|
| `IoErrorKind.NotFound` | パスが指すものがない |
| `IoErrorKind.PermissionDenied` | 権限がない |
| `IoErrorKind.IsDirectory` | ファイルを求める操作に、ディレクトリを指定した |
| `IoErrorKind.InvalidUtf8` | 読んだ内容が正しい UTF-8 でない（[ADR 0012](../decisions/0012-invalid-utf8-input.md)） |
| `IoErrorKind.Other` | 上のどれにも当たらない |

```text
fn readOrEmpty(path: String) -> String uses IO {
  match File.readText(path) {
    Ok(text) => text
    Err(e) => match IoError.kind(e) {
      IoErrorKind.NotFound => ""
      _ => {
        Console.eprintln(IoError.message(e))
        ""
      }
    }
  }
}
```

`IoError` 自体は、v1 でも中身を見せない型であり、等値の型ではない（[ADR 0048](../decisions/0048-ioerror-not-equality-type.md)）。

### 外部のライブラリの誤りとの対応

設計メモの go.* の層は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。外部のライブラリ（Rust のクレートなど）を呼ぶ層を設けるか、設けるならその誤りを `Result` と実行時エラーにどう対応させるかは【未決】である（[OPEN-035](../open-issues.md#open-035)）。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（`?` とラムダでつなぐ書き方の比較）
- [OPEN-026](../open-issues.md#open-026): 実行時エラーを起こしうることを型やエフェクトで表すか
- [OPEN-029](../open-issues.md#open-029): エラーを呼び出し元へ伝える構文（方針は `?`。測定で確定する）
- [OPEN-034](../open-issues.md#open-034): `IoErrorKind` の構成子の一覧
- [OPEN-035](../open-issues.md#open-035): v1 のライブラリの提供方法
