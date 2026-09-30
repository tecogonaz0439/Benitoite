# L23 `Csv`

- 依存する作業: [L00](L00-u3-interfaces.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/L23-csv

## 目的

RFC 4180 の CSV を読み書きする `Benitoite.Csv` の 5 の関数の本体を、`csv-core` を使って書く。10-15 の部分 39（`csv::DECLS`）である。

| 項目 | 権限 |
|---|---|
| `Csv.parse`・`parseWith`・`parseWithHeader`・`format`・`formatWith` | `Pure` |

## 読む設計書の節

- [テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)の「Csv」（`Csv.ParseError`、関数の表と箇条: 行の終わり、引用符、誤りの行の番号、見出しの規則、書き出しの規則、区切りの制限）、「共通の規則」
- [評価意味論](../../design/01-spec/01-08-evaluation.md)の引数が定義域の外の実行時エラー
- ADR: [0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「テキストとデータ」の表と `Csv.bnt`、「レコードの値の作り方」
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `csv-core`（`cargo deny` の【要検証】）
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `runtime::list`・`runtime::map`

## 作るもの

- `src/builtins/funcs/csv.rs` の 5 項目の本体と単体テスト。`csv-core` を依存に加える（10-16 の表の指定）

## 手順の要点

- `csv-core` を加えるときに `cargo deny check licenses` を実行し、`Unlicense/MIT` の表示を読めるかを確かめる（10-16 の【要検証】）。読めなければ、`deny.toml` の `clarify` で `Unlicense OR MIT` と明示し、MIT を選ぶ。どちらにしたかを完了の報告に書く。
- 解析は `csv_core::Reader`（`ReaderBuilder` で区切りを与える）で行う。行の終わりは LF と CR LF のどちらも受け付け、最後の行の後の改行はなくてよい。引用符で囲んだフィールドの中の改行と `""` を受け付ける。
- 閉じていない引用符は解析の誤りとし、`line` は誤りを見つけた行の番号（1 から数える）とする。`csv-core` が閉じていない引用符を誤りとして知らせるかを確かめ、知らせなければ入力の終わりで状態を見て判定する。
- `parseWithHeader`: 最初の行を見出しとし、残りの各行を見出しの名前からフィールドへの `Map` にする。見出しに同じ名前が二つ以上あるとき、見出しとフィールドの数が違う行があるときは解析の誤り。空の入力の扱い（見出しがない）は 03-08 が定めていないので、空のリストを返し、`///` のコメントと完了の報告に書く。
- `parse` は、行ごとにフィールドの数が違ってもよい。
- `format`: 区切り、引用符、CR、LF を含むフィールドを引用符で囲み（中の `"` は `""`）、行の終わりは LF とする。
- `parseWith`・`formatWith` の `delimiter` に `"`・CR・LF を指定すると実行時エラー（`ArgumentOutOfDomain`。引数の位置は 1）。`csv-core` は区切りを 1 バイトで受け取るので、ASCII でない文字の区切りの扱いを決める必要がある。03-08 は区切りを `Character` とし、制限は上の三つだけなので、ASCII でない区切りは受け付ける必要がある。`csv-core` で扱えなければ、ASCII でない区切りの解析と書き出しを自作するか、作業を止めて報告するかを、完了の報告の前にオーケストレータに相談する。
- 作る文字列とリストの大きさを、確保の前に確かめる。

## 受け入れテスト

- 項目ごとの単体テスト: 03-08 の箇条の各場合（LF と CR LF、最後の改行の有無、引用符の中の改行と `""`、閉じない引用符と `line`、行ごとに数の違うフィールド、見出しの重なり、見出しと数の違う行、空の入力、空のフィールド）。
- 往復: `format` の後の `parse` が元の行に戻る（区切りと引用符と改行を含むフィールドを含む）。`formatWith` と `parseWith` でタブ区切り。
- 区切りの制限: `'"'`・`'\r'`・`'\n'` で実行時エラー。

## 完了条件

- `scripts/check.sh`（`cargo deny check licenses` を含む）が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- `csv-core` のライセンスの扱い、空の入力と ASCII でない区切りの扱いを完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。
- `csv` クレート（`csv-core` の上の、`serde` を使う層）を加えていないか（ADR 0138 は `csv-core` を名指しした）。

## 難易度の理由

クレートが字句の状態の機械を持つので、書くのは行とフィールドの組み立てと誤りの位置である。ASCII でない区切りの扱いだけ、判断が要る。
