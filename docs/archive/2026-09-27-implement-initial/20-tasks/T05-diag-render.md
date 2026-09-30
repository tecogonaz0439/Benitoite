# T05 診断の書き出し

- 依存する作業: [T04](T04-source.md)
- 難易度: 2（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/T05-diag-render

## 目的

診断の内部の表現（`Diagnostic`）を、CLI が標準エラー出力に書く二つの形式、Rust 風の文章と JSON Lines にする（02-10「文章の形式」「JSON の形式」「実行時エラーと資源の不足の報告」）。検査の誤り、実行時エラー、資源の不足、処理系の不具合、処理系の制限、コマンドライン引数の誤りのすべてを、同じ表現からこの作業の関数で書き出す。ゴールデンテスト（T25）は JSON の形式の文字列を期待値と比べるので、JSON の書き方は一通りに決める。

## 読む設計書の節

- [診断エンジン](../../2026-09-27-design-initial/02-impl/02-10-diagnostics.md): 「診断の内部の表現」「文章の形式」「JSON の形式」「実行時エラーと資源の不足の報告」「処理系の不具合と処理系の制限の報告」
- [ソース管理と位置情報](../../2026-09-27-design-initial/02-impl/02-02-source-and-spans.md): 「行と列」
- ADR: [0032](../../2026-09-27-design-initial/decisions/0032-rust-style-text-and-json.md)、[0034](../../2026-09-27-design-initial/decisions/0034-call-trace-in-runtime-errors.md)
- インターフェース: [10-02](../10-interfaces/10-02-diagnostics.md)（全体。特に「診断の書き出し」と `codes::text`）、[10-01](../10-interfaces/10-01-base.md)「ソースの表」

## 作るもの

- `src/diag/render.rs`: 10-02 の `sig=src/diag/render.rs`（`TextOptions`、`render_check_text`、`render_one_text`、`render_json_line`）を実装する。
- 同じファイルの `#[cfg(test)] mod tests` のテスト。

## 手順の要点

**文章の形式の骨組み**

本作業で決める書式を、02-10 の例と一致するように次のとおり定める。G は行番号の欄の幅で、その診断で抜粋に示す行番号の桁数の最大値と 2 の大きいほうである（02-10 の例は、1 桁の行でも 2 桁の行でも同じ字下げになっている）。

```text
<見出し>
<G 個の空白>--> <ファイル>:<行>:<列>
<G+1 個の空白>|
<行番号を G 桁で右寄せ> | <行の内容>
<G+1 個の空白>| <字下げ><印> <ラベル>
（補助の位置の塊。後述）
<G+1 個の空白>|            ← 注記・修正案・履歴があるときだけ
<G+1 個の空白>= note: <注記>
<G+1 個の空白>= help: <修正案>
```

- 見出しは、報告の種類で決める。`Check`・`Limit`・`Args` は `error[<コード>]: <文言>`、`Runtime`・`Resource` は `runtime error[<コード>]: <文言>`（02-10 の例）、`Internal` は `internal error: <文言>`（コードなし）とする。`Args` を `runtime error` にしないのは、`main` を呼ぶ前の誤りであり、実行時エラーではないからである（本作業で決める）。警告は `warning[<コード>]` とする（最小実行版では現れない）。
- 主な位置がないときは、`-->` の行と抜粋を書かず、見出しの直後に注記・修正案・履歴を書く。このときの G は 2 とする。
- 印の行: 字下げは、行の先頭から span の開始までの表示の幅である。印は、span の開始から終了までの表示の幅の数だけ並べる（主な位置は `^`、補助の位置は `-`）。長さ 0 の span は印を 1 つにする。span が複数行にわたるときは、最初の行だけを示し、印をその行の末尾まで並べる（行の末尾にあるときは 1 つ）。ラベルが空なら、印の後に空白を置かない。
- 表示の幅は、コードポイント一つを 1、タブを 4 と数える。抜粋の中のタブは空白 4 つに置き換える（02-10）。正しくない UTF-8 のバイトは、抜粋では U+FFFD として示し、幅 1 と数える。
- 補助の位置: 主な位置と同じファイルの同じ行にあれば、主な位置の印の行の下に、補助の位置ごとに印の行を 1 行ずつ加える（列の順）。別の行か別のファイルにあれば、次の塊を補助の位置の順に加える。

```text
<G+1 個の空白>|
<G 個の空白>::: <ファイル>:<行>:<列>
<G+1 個の空白>|
<行番号> | <行の内容>
<G+1 個の空白>| <字下げ><印> <ラベル>
```

- 呼び出しの履歴（`trace` があるとき）は、注記の最初に `= note: call trace (innermost first):`（`codes::text::TRACE_HEADER`）を置き、その後に各段を 1 行ずつ、G+1+8+2 個の空白で字下げして並べる。各段は、位置を持つ段では「名前を全段の名前の最大の長さまで空白で埋めたもの、空白 1 つ、`at `、位置」、位置を持たない段では名前だけ（後ろに空白を付けない）とする。位置は `<ファイル>:<行>:<列>` である。`omitted` が 0 でなければ、10 段目と 11 段目の間に、同じ字下げで `TRACE_OMITTED` の行を置く。履歴の後に `notes` の注記を順に続け、その後に `helps` を続ける。末尾呼び出しの注記（`TRACE_TAIL_NOTE`）は、報告を作る側（T23）が `notes` の最後に入れるので、この作業では合成しない。JSON の形式でも `notes` にそのまま現れる。
- ラムダの段の名前は `<lambda <ファイル>:<行>:<列>>` とする（`FrameName::Lambda` の span の開始の位置）。
- バックトレース（`backtrace` があるとき）は、注記と修正案の後に `= backtrace:` の行を置き、バックトレースの各行を G+3 個の空白で字下げして続ける。
- 一つの診断の文字列は、最後の行の改行で終える。

**色**

`opts.color` が真のときだけ、ANSI のエスケープで色を付ける（本作業で決める）。見出しの重大度とコード（`error[E0401]`、`runtime error[R0101]`、`internal error`）は太字の赤（`\x1b[1;31m`）、行番号の欄と `|`・`-->`・`:::`・`=` は太字の青（`\x1b[1;34m`）、`^` は太字の赤、`-` は太字の青、`note`・`help` は太字（`\x1b[1m`）とし、それぞれの後に `\x1b[0m` で戻す。文言・ラベル・ソースの行には色を付けない。`NO_COLOR` と端末の判定は CLI（T24）が行い、本作業は `opts.color` だけを見る。

**検査の誤りの一覧（`render_check_text`）**

- 渡された順に、最初の 50 件を書く。各診断の後に空行を 1 行置く。
- 51 件以上あれば、50 件の後に `error: ` に `codes::text::TOO_MANY`（`count` は書かなかった件数）を続けた行と空行を置く。
- 最後に `error: ` に `SUMMARY_ONE` か `SUMMARY_MANY`（`verb`・`file`・`count` を置き換える。`count` は誤りの総数）を続けた行を置く。誤りが 0 件なら空文字列を返す。

**JSON の形式（`render_json_line`）**

10-02「診断の書き出し」の最後の段落の順と書き方に従う。加えて、本作業で次のとおり決める。

- 項目の順: `kind`、`severity`、`code`、`message`、`primary`、`secondary`、`notes`、`helps`、（あれば）`trace`、`traceOmitted`、（あれば）`backtrace`。
- `kind` は `"check"`・`"limit"`・`"runtime"`・`"resource"`・`"args"`・`"internal"`。`code` は `"E0401"` の形、処理系の不具合では `null`。
- 位置の形は `{"file":…,"start":{"line":…,"column":…,"offset":…},"end":{…},"label":…}`。`offset` はバイトの位置。`primary` が `None` なら `null`。
- `trace` の各要素は `{"function":<名前>,"location":<位置の形か null>}` で、位置の形の `label` は空文字列 `""` とする。`traceOmitted` は数。
- 文字列のエスケープは、`"` を `\"`、`\` を `\\`、LF・CR・タブを `\n`・`\r`・`\t`、そのほかの U+0000〜U+001F を `\u` と小文字の 16 進 4 桁（`\u001b`）とする。それ以外の文字はそのまま UTF-8 で書く。
- 空白を入れない（`:` と `,` の後にも入れない）。

## 受け入れテスト

以下の期待値は、`opts.color` を偽にしたときの文字列そのものである。テストのソースは `SourceTable` に `count.bnt` の名前で加える。

1. 型の誤り（02-10「文章の形式」の例）。ソースを `fn f(x: Int) -> Int {\n  x\n}\nfn g() -> Unit {\n  let n: Int = "a"\n}\n` とし、主な位置を `"a"`（5 行 16 列から 3 バイト）、ラベル `` expected `Int`, found `String` ``、補助の位置を `Int`（1 行 9 列から 3 バイト）、ラベル `declared here` とした E0401 の診断は、`render_one_text` で次になる。

```text
error[E0401]: mismatched types
  --> count.bnt:5:16
   |
 5 |   let n: Int = "a"
   |                ^^^ expected `Int`, found `String`
   |
  ::: count.bnt:1:9
   |
 1 | fn f(x: Int) -> Int {
   |         --- declared here
```

2. 実行時エラーと履歴。10 行目が `  let q = a / b` のソースで、主な位置を `a / b`（10 行 11 列から 5 バイト）、履歴を `ratio`（22 行 33 列）、`<lambda>`（22 行 25 列、位置なし）、`List.map`（22 行 12 列）、`main`（位置なし）とし、`notes` を `[TRACE_TAIL_NOTE]` とした R0101 の報告は、次になる（02-10 の例と同じ）。

```text
runtime error[R0101]: division by zero
  --> count.bnt:10:11
   |
10 |   let q = a / b
   |           ^^^^^
   |
   = note: call trace (innermost first):
             ratio                    at count.bnt:22:33
             <lambda count.bnt:22:25>
             List.map                 at count.bnt:22:12
             main
   = note: functions left by tail calls are not shown
```

3. 位置のない書き込みの失敗（R0201、注記 `broken pipe`）は次になる。

```text
runtime error[R0201]: failed to write to standard output
   = note: broken pipe
```

4. 履歴が 25 段で `omitted` が 5 のとき、10 段目と 11 段目の間に `... 5 frames omitted ...` の行が入る。
5. `render_check_text` に誤りを 3 件渡すと、3 件の後に `error: could not run count.bnt due to 3 previous errors` の行が来る。1 件なら `due to 1 previous error`。0 件なら空文字列。
6. 誤りを 53 件渡すと、50 件だけを書き、`error: 3 more errors not shown` と、`due to 53 previous errors` の要約の行を書く。
7. タブを含む行 `\tlet x = y` の `y` に主な位置があると、抜粋はタブを空白 4 つにし、`^` が `y` の真下に来る。
8. 2 行にわたる span は、最初の行だけを示し、`^` を行の末尾まで並べる。長さ 0 の span は `^` を 1 つ示す。
9. 例 1 の診断の `render_json_line` が、次の 1 行になる（オフセットはソースのバイト位置）。

```text
{"kind":"check","severity":"error","code":"E0401","message":"mismatched types","primary":{"file":"count.bnt","start":{"line":5,"column":16,"offset":<"a" の開始>},"end":{"line":5,"column":19,"offset":<"a" の終了>},"label":"expected `Int`, found `String`"},"secondary":[{"file":"count.bnt","start":{"line":1,"column":9,"offset":8},"end":{"line":1,"column":12,"offset":11},"label":"declared here"}],"notes":[],"helps":[]}
```

10. 例 2 の報告の JSON が `"kind":"runtime"`、`"trace":[{"function":"ratio","location":{…,"label":""}},{"function":"<lambda count.bnt:22:25>","location":null},…]`、`"traceOmitted":0` を持つ。
11. 処理系の不具合の報告（`kind` が `Internal`、`code` が `None`）は、文章では `internal error: <文言>` で始まり、JSON では `"code":null` で、`backtrace` があれば `"backtrace":"…"` を最後に持つ。
12. 文言に `"`・`\`・LF・U+001B を含む診断の JSON が、10-02 のエスケープの規則どおりになり、一行に収まる。
13. `opts.color` が真のとき、見出しが `\x1b[1;31m` で始まる。偽のとき、出力にエスケープの文字（U+001B）を含まない。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 受け入れテストの 1〜3 の期待値の文字列が、テストの中に上のとおりに書かれている

## 難易度の理由

仕様が文章と例で与えられ、本作業の文書で書式の細部を決めてあるので、書くべきものは一通りに定まる。手間がかかるのは、字下げと印の位置を表示の幅で揃えることと、JSON のエスケープを誤りなく書くことである。
