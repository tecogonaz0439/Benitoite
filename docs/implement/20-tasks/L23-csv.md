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
- ADR: [0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)、[0329](../../design/decisions/0329-csv-and-time-details-from-u3-preflight.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「テキストとデータ」の表と `Csv.bnt`、「レコードの値の作り方」
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `csv-core`（`cargo deny` の【要検証】）
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `runtime::list`・`runtime::map`

## 作るもの

- `src/builtins/funcs/csv.rs` の 5 項目の本体と単体テスト。`csv-core` を依存に加える（10-16 の表の指定）。`crates/benitoite/Cargo.toml` には、版を固定して `csv-core = "=0.1.13"` と書く

## 手順の要点

- `csv-core` を加えるときに `cargo deny check licenses` を実行し、`Unlicense/MIT` の表示を読めるかを確かめる（10-16 の【要検証】）。読めなければ、`deny.toml` の `clarify` で `Unlicense OR MIT` と明示し、MIT を選ぶ。どちらにしたかを完了の報告に書く。`csv-core` は `memchr` を新たに依存に持ち込む。`memchr` のライセンスは `Unlicense OR MIT`（memchr 2.8.3 の `Cargo.toml`）であり、`deny.toml` の許可の一覧の `MIT` に当たるので、`cargo deny` を通り、`memchr` には `clarify` が要らない見込みである。
- 解析は `csv_core::Reader`（`ReaderBuilder` で区切りを与える）で行う。行の終わりは LF と CR LF のどちらも受け付け、最後の行の後の改行はなくてよい。`csv-core` の既定の行の終わり（`Terminator::CRLF`）は CR LF・LF・CR 単独のどれも一つの行の終わりとして扱う（csv-core 0.1.13 の `reader.rs` の `ReaderBuilder::terminator` の説明）。CR 単独を行の終わりとして扱うことは、03-08 の箇条（LF と CR LF を受け付ける）と食い違わない。引用符で囲んだフィールドの中の改行と `""` を受け付ける。
- 閉じていない引用符は解析の誤りとし、`line` は引用符を開いたレコードを始めた行の番号（1 から数える）とする。引用符の中の改行で複数行にまたがるときも、誤りを見つけた入力の終わりの行ではなく、レコードを始めた行を指す（03-08「Csv」、ADR 0329 の決定 1）。`csv-core` の `Reader` は誤りを返さない（閉じていない引用符も誤りとして知らせない）ので、入力の終わりで引用符の中にいるかを自前で判定する。
- `csv-core` の `Reader::line()` は `\n` の数だけを数え（`reader.rs`）、レコードの始まりの行を表さない。処理系は、各レコードを始めた行の番号を自前で数える（レコードを読み始める前の行の番号を覚えておく）。自前で数えるときは、CR LF を一つ、CR 単独と LF をそれぞれ一つの行の終わりとして数え、`csv-core` が読み捨てる空の行も数えに入れる。
- `csv-core` が CR 単独の行の終わりと空の行（`"a\n\nb"` の 2 行目）をどう扱うかを単体テストで確かめ、03-08 の箇条と食い違わない扱いにして、完了の報告に書く。
- `parseWithHeader`: 最初の行を見出しとし、残りの各行を見出しの名前からフィールドへの `Map` にする。見出しに同じ名前が二つ以上あるとき、見出しとフィールドの数が違う行があるときは解析の誤り。フィールドの数が違う行が複数行にまたがるレコードなら、`line` はそのレコードを始めた行とする（ADR 0329 の決定 1）。`map_from_sorted` は組の数の上限を確かめないので、見出しの数を先に `CheckedLen::elements` で確かめてから渡す（行とフィールドのリストも同じく先に確かめる）。`map_from_sorted` は組を並べ直さず、組が鍵の順に並び、同じ鍵を含まないことを前提とする（U3 の `runtime/map.rs`）。見出しの重なりを確かめた後に、組を `runtime::map::compare_keys` の順に並べてから渡す（見出しの順のまま渡さない）。空の入力の扱い（見出しがない）は 03-08 が定めていないので、空のリストを返し、`///` のコメントと完了の報告に書く。
- `parse` は、行ごとにフィールドの数が違ってもよい。
- `format`: 区切り、引用符、CR、LF を含むフィールドを引用符で囲み（中の `"` は `""`）、行の終わりは LF とする。空のフィールド一つだけの行（`[""]`）は `""` と書く。フィールドのない行（`[]`）は空の行のまま書く（03-08「Csv」、ADR 0329 の決定 2。`Csv.parse` は空の行を飛ばすので、`[""]` を空の行に書くと往復で行が消える）。`formatWith` も同じ。
- `parseWith`・`formatWith` の `delimiter` に `"`・CR・LF を指定すると実行時エラー（`ArgumentOutOfDomain`。引数の位置は 0 から数えて 1）。
- `parseWith` の `delimiter` は ASCII の文字に限る。ASCII でない文字なら実行時エラー（`ArgumentOutOfDomain`。引数の位置は 0 から数えて 1）とする（03-08「Csv」、ADR 0322 の決定 2）。ASCII の区切りは 1 バイトなので、そのまま `csv_core::ReaderBuilder::delimiter` に渡す。ASCII でない区切りの解析を自作しない。
- `formatWith` の区切りは、03-08 の制限（`"`・CR・LF）のほかに制限がないので、ASCII でない文字も受け付ける（書き出しは自前で文字列をつなぐので、1 バイトの制約がない）。
- 作る文字列とリストの大きさを、確保の前に確かめる。
- スクリプトのテストを書くときは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Csv`。[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-08 の例の `import Benitoite.Csv` の形をそのまま写すと、E0321 になる。

## 受け入れテスト

- 項目ごとの単体テスト: 03-08 の箇条の各場合（LF と CR LF、最後の改行の有無、引用符の中の改行と `""`、閉じない引用符と `line`、閉じていない引用符が引用符の中の改行で複数行にまたがるときの `line`（引用符を開いたレコードを始めた行）、`parseWithHeader` で複数行にまたがるレコードのフィールドの数が見出しと違うときの `line`（そのレコードを始めた行）、CR 単独の行の終わり、空の行、行ごとに数の違うフィールド、見出しの重なり、見出しと数の違う行、空の入力、空のフィールド）。
- 往復: `format` の後の `parse` が元の行に戻る（区切りと引用符と改行を含むフィールドを含む）。`formatWith` と `parseWith` でタブ区切り。往復の対象から、フィールドのない行（`[]`）は除く（空の行に書くので、読み直すと消える）。
- 空のフィールド一つだけの行: `format([[""]])` が `""` と LF になり、`parse` で `[[""]]` に戻る。
- スクリプトのテスト: `import Benitoite.Unofficial.Csv` のスクリプトで、解析の誤りの値を `Csv.ParseError.line(e)` と `Csv.ParseError.message(e)` で読む（10-15「レコードの値の作り方」の、フィールドの並びを確かめるテスト）。
- 区切りの制限: `'"'`・`'\r'`・`'\n'` で実行時エラー（`parseWith` と `formatWith` の両方。引数の位置 1）。`parseWith` に ASCII でない区切り（`'、'`・`'é'` など）で `ArgumentOutOfDomain`（引数の位置 1）。`parseWith` に ASCII の区切り（`';'`・`'|'`）で解析できる。`formatWith` に ASCII でない区切りで、区切りを含むフィールドが引用符で囲まれた文字列になる。

## 完了条件

- `scripts/check.sh`（`cargo deny check licenses` を含む）が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- `csv-core` のライセンスの扱い、空の入力・CR 単独・空の行の扱いを完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。
- `csv` クレート（`csv-core` の上の、`serde` を使う層）を加えていないか（ADR 0138 は `csv-core` を名指しした）。

## 難易度の理由

クレートが字句の状態の機械を持つので、書くのは行とフィールドの組み立てと誤りの位置である。
