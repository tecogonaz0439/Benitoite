# T10 組み込みの表とテスト用のハンドラ表

- 依存する作業: [T07](T07-builtins-numeric.md), [T08](T08-builtins-string.md), [T09](T09-builtins-list.md)
- 難易度: 2（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/T10-builtin-table

## 目的

組み込みの表（組み込みの関数ごとのモジュール・名前・型・実装・引数の個数）を、10-10 の一覧のとおりに作る。名前解決・型検査・コード生成・VM・参照インタプリタは、この表を通して組み込みの関数を扱う。あわせて、処理系のテストが使うテスト用のハンドラ表 `TestIo` と、`IoError.message` を実装する。

## 読む設計書の節

- [名前解決とモジュール読込](../../2026-09-27-design-initial/02-impl/02-04-resolver.md)の「prelude」（組み込みの表、「prelude のソースの中だけで使える」印）
- [ランタイム](../../2026-09-27-design-initial/02-impl/02-09-runtime.md)の「ハンドラ表」
- [エフェクト](../../2026-09-27-design-initial/01-spec/01-07-effects.md)の「IO を行う組み込み関数」「IO の失敗」
- [型システム](../../2026-09-27-design-initial/01-spec/01-06-type-system.md)の「演算子の型付け」「等値の型」「prelude の関数の型」
- [組み込みの関数](../10-interfaces/10-10-builtins.md)の全体
- [型と型検査](../10-interfaces/10-05-types.md)の「型の表現」（`Scheme`・`TypeParamInfo`・`ParamConstraint`・`TySet`）
- [実行時の値、VM、ランタイム](../10-interfaces/10-08-runtime.md)の「IO の操作とハンドラ」

## 作るもの

- `src/builtins/table.rs`: 10-10 の `sig=src/builtins/table.rs` の `spec`・`scheme`・`lookup`。
- `src/builtins/io_error.rs`: `IoError.message` の `PureFn`（`message`）と、IO の失敗の文言の定数（後述）。
- `src/runtime/test_io.rs`: 10-08 の `sig=src/runtime/test_io.rs` の `TestIo::new` と `IoHandlers` の実装。
- 上のファイルの中のテスト。

## 手順の要点

### `spec`

- `BuiltinId` ごとに `match` で `BuiltinSpec` を返す。`_` の分岐は使わない（lint `wildcard_enum_match_arm`）。
- `module` は 10-10 の一覧の名前の欄の `.` の左（演算子は `None`）、`name` は `.` の右（演算子は記号。単項の `-` は `"-"`）。
- `kind` は、実装の欄が Rust の関数なら `BuiltinKind::Pure(<その関数>)`、IO の操作なら `BuiltinKind::Io(<IoOp>)`。
- `prelude_only` は `ListDropFirst` だけ `true`。
- `arity` は型の欄の引数の個数。

### `scheme`

10-10 の一覧の型の欄を `Scheme` にする。

- 型パラメータの名前は、型の欄に書いた名前（`T`・`U`・`A`・`X`）を、書いた順に `type_params` に並べる。`Ty::Param(i)` の `i` はこの並びの位置である。
- 型パラメータの制約: `Eq`・`Ne`・`ListContains` の `T` は `ParamConstraint::Equality`、`ListSort` の `T` は `ParamConstraint::OneOf(TySet::ORD)`、ほかは `ParamConstraint::None`。
- 演算子の型は、オペランドの型が決まった形（`AddInt` は `fn(Int, Int) -> Int`）で書く。演算子の型付けの集まりの制約は型検査器が扱う（10-05 の `OneOf` の制約）ので、ここには書かない。
- `effect_params` はどの組み込みの関数も空。`effects` は IO を行う関数だけ `EffectSet::io()`、ほかは空集合。
- 型の欄の `Option[T]`・`Result[String, IoError]`・`List[T]` は、`Ty::option`・`Ty::result`・`Ty::list` などで作る。

### `lookup`

`BuiltinId::ALL` を順に見て、`spec` の `module` と `name` が一致するものを返す。演算子は `module` が `None` なので引けない。`prelude_only` の関数も引ける（利用者のプログラムから見えなくするのは名前解決の仕事である。02-04）。

### IO の失敗の文言（新しく決めること）

`IoError` の文言の具体的な文面は、言語仕様では定めない（01-07「IO の失敗」）。ゴールデンテストの期待値を、本番のハンドラ表（T23）と揃えるために、次の定数を `builtins/io_error.rs` の子のモジュール `text` に置く（00-02「文言」）。

```rust
pub mod text {
    /// ファイルがないとき（Unix 系の OS の `std::io::Error` の表示と同じ文面）
    pub const MSG_NOT_FOUND: &str = "No such file or directory (os error 2)";
    /// ファイルの内容が正しい UTF-8 でないとき
    pub const MSG_INVALID_UTF8: &str = "file is not valid UTF-8";
}
```

本番のハンドラ表は、ファイルが読めないときは `std::io::Error` の表示をそのまま文言にし、内容が正しい UTF-8 でないときは `io_error::text::MSG_INVALID_UTF8` を使う。テスト用のハンドラ表は、ファイルがなければ `io_error::text::MSG_NOT_FOUND`、正しい UTF-8 でなければ `io_error::text::MSG_INVALID_UTF8` を使う。

### `TestIo`

- `new` は `args` と `files` を受け取り、`events`・`stdout`・`stderr` を空にして作る。
- `Print`・`Println`・`Eprintln`: 引数の文字列（`Println` と `Eprintln` は続けて `"\n"`）を `stdout` か `stderr` に加え、`IoEvent::Write { stream, text }` を記録する。`text` は加えた文字列（改行を含む）。応答は `Value::Unit`。書き込みは失敗しない。
- `ReadText`: 引数の文字列をそのまま `files` の鍵として引く（パスの正規化はしない）。あって正しい UTF-8 なら `Ok(内容)`（`heap.ctor(0, vec![heap.string(..)])`）、なければ `Err(heap.io_error(io_error::text::MSG_NOT_FOUND))`、正しい UTF-8 でなければ `Err(heap.io_error(io_error::text::MSG_INVALID_UTF8))`（`Err` はタグ 1）。どの場合も `IoEvent::ReadFile { path, ok }` を記録する。
- `Args`: `args` の文字列のリストを `heap.list_from_vec(.., "Process.args")` で作り、`IoEvent::Args` を記録する。
- 引数の種類が違えば `Stop::Internal`。`flush_all` は既定の実装（何もしない）のままにする。

## 受け入れテスト

- すべての `BuiltinId` について、`spec(id).id == id`、`spec(id).arity` が `scheme(id).params.len()` と等しい。`lookup(m, n)` が、演算子を除くすべての `id` について `Some(id)` を返す（`m`・`n` は `spec(id)` のもの）。
- 型の抜き取り: `scheme(ListContains)` の型パラメータが一つで制約が `Equality`。`scheme(ListSort)` の制約が `OneOf(TySet::ORD)`。`scheme(Eq)` が `fn[T](T, T) -> Bool` で制約が `Equality`。`scheme(FileReadText)` の戻り値が `Result[String, IoError]` でエフェクトが `IO`。`scheme(ListMap)` に当たる項目はない（`List.map` は prelude のソース）。
- `lookup(List, "map")` → `None`、`lookup(List, "dropFirst")` → `Some(ListDropFirst)`、`lookup(String, "length")` → `None`。
- `spec(ListDropFirst).prelude_only` だけが `true`。
- `TestIo`: `Println("a")` の後に `Print("b")` で、`stdout` が `"a\nb"`、事象が二つの `Write`。`files` にある `"in.txt"` の `ReadText` が `Ok`、ない `"x.txt"` が文言 `io_error::text::MSG_NOT_FOUND` の `Err`、内容が `[0xff]` のファイルが文言 `io_error::text::MSG_INVALID_UTF8` の `Err`。`Args` が与えた順の文字列のリスト。
- `IoError.message` が `IoError` の値の文言を返す。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- `spec` と `scheme` が 10-10 の一覧の 91 項目すべてを持つ

## 難易度の理由

大部分は 10-10 の一覧を `match` の表に写す定型の作業である。注意が要るのは、型の欄を `Scheme` に移すときの型パラメータの番号と制約の付け方と、テスト用のハンドラ表の文言を本番のハンドラ表と揃える決まりである。
