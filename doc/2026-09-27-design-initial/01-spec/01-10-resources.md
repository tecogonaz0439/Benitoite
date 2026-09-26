# リソース管理

- 状態: 草稿
- 関連ADR: [0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md), [0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md), [0067](../decisions/0067-with-resource-scope.md), [0068](../decisions/0068-release-resources-on-stop.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-029](../open-issues.md#open-029)
- 移行元: [設計メモ](../sources/fp-language-design.md) 4

## 目的と範囲

リソーススコープ（resource scope）の構文、解放順序、エラー時の解放。

現在の版は、v1（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲を定める。対象は、リソースの型、`with` の構文と意味、解放の時期と順序、解放の失敗、解放したリソースを使ったときの扱いである。具体的なリソースの型（読み書きのためのファイルなど）と、それを開く関数は、std を設計するとき（実装言語の見直しの後）に定める。

## 前提

ここでいうリソース（resource）は、ファイルなどの OS の資源のうち、使い終えた時点で閉じる必要があるものである。メモリの回収は GC が行い、本章の対象ではない（[設計メモ](../sources/fp-language-design.md) 4）。

`?` の意味と、例外を設けないこと（[ADR 0064](../decisions/0064-no-exceptions-runtime-errors-uncatchable.md)）は[エラー処理](01-09-errors.md)で、実行時エラーと資源の不足による停止の手順は[評価意味論](01-08-evaluation.md)で定める。

## 仕様

### リソースの型

【決定】リソースにできる値は、prelude と std が定めるリソースの型の値に限る（[ADR 0067](../decisions/0067-with-resource-scope.md)）。

【方針】リソースの型は中身を見せない型であり、等値の型ではない。利用者が定義する型をリソースにする方法は、v1 にはない。

【方針】リソースの型ごとに、解放（release）の操作が一つ決まっている。解放は IO である。リソースの型は、`with` を使わずに解放する関数（`close` など）も持ってよい。この関数は `Result[Unit, IoError]` を返し、解放の失敗をスクリプトが扱えるようにする。

### `with` の構文

【決定】`with x = e { ... }` は、`e` の値のリソースを `x` に束縛してブロックを評価し、ブロックを抜けるときに `x` を解放する。`with a = e1, b = e2 { ... }` のように複数を並べられる（[ADR 0067](../decisions/0067-with-resource-scope.md)）。

```text
fn copyHeader(src: String, dst: String) -> Result[Unit, String] uses IO {
  with input = File.openRead(src) |> Result.mapErr(_, IoError.message)?,
       output = File.openWrite(dst) |> Result.mapErr(_, IoError.message)? {
    let line = FileReader.readLine(input) |> Result.mapErr(_, IoError.message)?
    FileWriter.write(output, line) |> Result.mapErr(_, IoError.message)
  }
}
```

この例のファイルの型と関数（`File.openRead` など）は、説明のための仮の名前である。

【方針】`with` の規則は次のとおりである。

- `with` は式であり、値はブロックの値、型はブロックの型である。`with` は IO エフェクトを持つ。
- `e` の型はリソースの型でなければならない。失敗しうる操作でリソースを開くときは、`?` か `match` で `Result` から取り出してから束縛する。`?` は v1 の方針であり、確定していない（[OPEN-029](../open-issues.md#open-029)）。
- `x` の有効範囲は、`with` のブロックと、後に並べた `e` の中である。`with a = e1, b = e2` では、`e2` の中で `a` を使える。
- 並べた `e1`、`e2`、… は書いた順に評価し、それぞれを評価した直後に束縛する。途中の `e` の評価で `?` が関数を終えたときは、それまでに束縛したリソースだけを解放する。

構文は[構文](01-02-syntax.md)の「リソーススコープ（v1）」で定める。

### 解放の時期と順序

【方針】`with` で束縛したリソースは、次のときに、束縛と逆の順に解放する。

- ブロックの評価が終わったとき。ブロックの値を決めてから解放する。
- ブロックの中の `?` が、`with` を含む関数かラムダの呼び出しを終えるとき。内側の `with` から順に解放する。
- 実行時エラーか資源の不足でプログラムが止まるとき。その時点で開いているすべての `with` のリソースを、内側のスコープから順に解放してから止まる（[ADR 0068](../decisions/0068-release-resources-on-stop.md)）。手順の順序は[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」で定める。
- `ExitCap` を使って、終了状態を指定してプロセスを終えるとき。その時点で開いているすべての `with` のリソースを、内側のスコープから順に解放してから終わる（[エフェクト](01-07-effects.md)の「ケーパビリティ（v1）」）。

【決定】処理系が上限を設けていない資源が実行環境で尽きたとき（[ADR 0044](../decisions/0044-heap-exhaustion-outside-stop-procedure.md)）は、解放することを保証しない（[ADR 0068](../decisions/0068-release-resources-on-stop.md)）。

`with` のブロックの最後の式は、その後に解放が続くので、末尾位置にない（[評価意味論](01-08-evaluation.md)の「末尾呼び出し」）。

### 解放の失敗

【方針】ブロックを抜けるときの解放が失敗したときは、実行時エラー（リソースの解放の失敗）とする。残りのリソースの解放は続け、失敗をすべて報告する。

【決定】実行時エラーか資源の不足で止まる途中で解放が失敗したときは、止まる理由の報告に解放の失敗を加える。先の実行時エラーを置き換えない（[ADR 0068](../decisions/0068-release-resources-on-stop.md)）。

解放の失敗をスクリプトの中で扱うときは、ブロックの最後で、リソースの型の `close` などの関数を呼んで `Result` を調べる。

【方針】`close` などの関数を呼んだリソースは、`close` が `Err` を返したときも解放済みとみなす。解放済みのリソースを `with` がもう一度解放することはない。

### 解放したリソースの使用

【方針】リソースの値は、`with` のブロックの外へ返したり、ラムダに捕捉したりして、解放した後に使えてしまう。解放したリソースに対する操作は、実行時エラー（解放したリソースの使用）とする。これを検査で見つける仕組み（線形型など）は、v1 にはない。

【方針】リソースの型の値を、`with` を使わずに `let` で束縛することもできる。この値は、スクリプトが `close` などで解放しない限り、プログラムが終わるまで解放しない。プログラムが止まるときに解放するのは、`with` で束縛したリソースだけである。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（`with` の書き方の成功率）
- [OPEN-029](../open-issues.md#open-029): エラーを呼び出し元へ伝える構文（`with` の規則と例は、方針の `?` を使う）
