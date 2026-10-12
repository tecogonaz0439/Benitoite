# Y10 のレビュー

対象: コミット `bd7f265f`「Follow the 06-03 blank line rules for comment-only bodies and leading with statements」（`16462a8f` で san_benito に取り込み済み）。`git show` だけで読んだ。cargo は走らせていない。

## 結論

要修正の指摘はない。`BlankBefore` を `leading`・`direct` の二つの真偽値に分け、`blank_rule` を字句の種類を見ない四つの判定に書き直した。この変更で直るのは study 5.2 の二つの外れだけで、ほかの入力の整形の結果は変わらない（下の「確かめたこと」の 1）。推奨は CHANGELOG の文の一件、軽微は三件である。

## 確かめたこと

1. **ほかの整形の結果を変えないか**: 旧の `blank_rule` は、`Remove` の行のうち `inner_level` を持つ字句か `KwElse`・`KwWith` で始まる行を「閉じ」とみなしていた。新しい印との対応は次のとおりである。
   - `closer()` は `direct` と `inner_level` を必ず一緒に立てる。`separator()` が立てるのは `else` と `with` だけである。したがって `direct` の行は、必ず旧の「閉じ」に入る。
   - 旧の「閉じ」のうち `direct` でない行は、`leading` の行のうち `with` で始まる行（外れの 2）だけである。`leading` の行が `else` で始まることはない。
   - `leading` と `direct` の両方が立つ行は、中身が空の構文の閉じ（外れの 1）だけである。`content()` の範囲の終わりは、いずれの呼び出し元でも閉じの字句か `end` で、`if` は `else` を含めて `end` までとる。
   - 残りの `leading` だけの行と `direct` だけの行では、新しい判定は旧と同じ値を返す。
2. **06-03「空の行」の各規則**: 中身の最初の行の前（コメントだけの行を含めて数える）、閉じ・`else`・節の並びを始める `with` の直前、コメントどうしの間は一つまで保つ、`match` と `handle` の `case` の前は一つまで、の四つを、新しいゴールデンテストの入力と `.formatted` に当てて手で辿った。どれも規則のとおりに整形される。空の `then`・空の `handle` の本体の後の `else`・`with` も、`content(if, end)`・`content(handle, end)` によって `leading` が立つので、コメントの前の空の行が除かれる。
3. **冪等性**: `.formatted` を入力として `blank_rule` を辿り直した。コメントの後の行は `KeepOne` か `direct` による `Zero` になり、開きの行の直後には空の行がないので、二度目の整形で変わる箇所はない（ただし自動では確かめていない。軽微の 2）。
4. **標準ライブラリのソース**: 正規形の検査は `cargo test --lib cli::tools::formatter` に含まれ、実装者の報告では通った。この変更は空の行を除く箇所を増やすだけなので、正規形のソースが変わるのは「開きの行、空の行、コメント」の並びがある場合だけである。検査が通ったことから、標準ライブラリにその並びはない。
5. **テスト**（test-audit）: 新しいゴールデンテスト `blank_lines_comments` は、外れの 1（リスト、引数のない呼び出し、関数、`if` の両分岐、`handle`・`with`・`lazy`・`lambda` の本体、`data`・`trait`・`implement`・`effect`）と外れの 2（`firstWith`）を含む。どちらかを旧の振る舞いに戻せば、開きの行の後に空の行が残って失敗する。関数 `unchanged` は、study 5.2 の「外れない場合」の五つを固定する。`direct` を `leading` のように扱う退行や、その逆の退行も捕まえる。実装者は `.formatted` を手で書き、直す前に失敗することを確かめている。役割の表の単体テストは、型の変更に合わせて期待値を書き換えただけである。両方の印が立つ行と `leading` の `with` の行は単体テストに含まれないが、振る舞いはゴールデンテストが確かめる（06-03「テスト」の持ち主の境界）ので、足さなくてよい。
6. **残り**: 設計書・リファレンス・Skill に `BlankBefore`・`Remove` の古い名前は残っていない。凍結した型の変更は、decisions.md の Q6 で了承されている。

## 指摘

### 1. 推奨 — CHANGELOG の文が、直した範囲より広く読める

- 場所: `CHANGELOG.md` の Unreleased の「### Fixed」の最初の行。
- 問題: 「now removes blank lines before a comment that is the first line inside a construct, including constructs containing only comments and bodies whose first statement is `with`」と書くと、中身の最初のコメントの前の空の行を、これまでは一般に除いていなかったように読める。実際には一般の場合はもとから除いていて、直したのは二つの場合だけである。また、この直しで `fmt --check` が新たに整形を求めるファイルが出ることが、文から読み取れない。
- 修正案: 例「`benitoite fmt` now also removes the blank line before a comment that is the first line inside a construct when the construct contains only comments or its first statement is `with`, as the standard layout requires. `fmt --check` reports such files until they are formatted again.」。「standard layout」はリファレンス（`docs/reference/benitoite.md` の `fmt` の節）の語に揃えたものである。

### 2. 軽微 — ゴールデンテストの `fmt` の方式は、`.formatted` が不動点かを確かめない

- 場所: `crates/benitoite/tests/golden/formatting.rs`（変更の外）。新しい `blank_lines_comments.formatted`。
- 問題: `fmt` の方式は、入力を整形した結果と `.formatted` を比べるだけである。`.formatted` をもう一度整形しても変わらないことは確かめない。冪等性を自動で確かめるのは、`formatter/tests.rs` の固定の場合と大きな入力だけである。今回の `.formatted` は手で辿った限り不動点だが、空の行の規則の退行で冪等性が崩れても、ゴールデンテストは捕まえない。
- 修正案: この作業では直さない。`fmt` の方式で `.formatted` も整形し直して変わらないことを確かめる案を、docs/todo の項目に加えるかを検討する。

### 3. 軽微 — `///` の後の `leading` の印は効かない

- 場所: `roles.rs` の `BlankBefore::leading` の `///` のコメント（「`///` と属性の間」）、`walk.rs` の `top_decl` の `decl.doc.is_some()` の印、`roles/tests.rs` の `blank_line_handling_follows_the_kind_of_line` の行 2。
- 問題: `///` は `LineKind::Comment` の行なので、その次の行に `leading` が立っていても、`blank_rule` は前の行がコメントだと見て `KeepOne` を返す。一方、解析器の `adjacent`（`parser/items.rs`）は、`///` と宣言の間が改行一つのときだけ説明を宣言に付ける。空の行を挟むと E0228 になり、`fmt` は整形を断る。つまり、この印が効く入力は存在しない。この作業より前からの状態で、整形の結果は正しい（06-03 の「`///` の行と属性の間に空の行を加えない」を満たす）。ただし、コメントと役割の表のテストは、効かない印を規則の実装であるかのように示している。
- 修正案: この作業では直さない。印を消すか、コメントに「解析器が空の行を許さないので、この印は空の行を加えないことの確認にとどまる」と書くかを、後の作業か docs/todo の項目で決める。

### 4. 軽微 — 空の `then`・`handle` の本体のコメントの段が、期待の出力で外側の段になる

- 場所: `crates/benitoite/testdata/fmt/blank_lines_comments.formatted` の 24 行と 29 行。
- 問題: 空の `then` の本体と空の `handle` の本体のコメントが、`if`・`handle` と同じ段（2 字）に置かれる。空の `else` の本体のコメント（26 行）は 4 字である。06-03「コメント」は、コメントの行を次のコードの行の段に置き、閉じの字句の前だけを一段深くする。`else` と節の並びを始める `with` は閉じの字句ではないので、今の出力は規則のとおりで、期待の出力の誤りではない。ただし、ゴールデンテストがこの見た目を正規形として固定する。
- 修正案: この作業では直さない。設計者がこの段を不自然と見るなら、06-03「コメント」の規則（区切りの字句の前のコメントで、前が開きの行のとき）を見直す項目を docs/todo に加える。

## 参考（この作業の範囲の外。指摘ではない）

- `@test`、コメント、空の行、`function` の並びで、コメントと宣言の間の空の行を一つ保つ。06-03 は、属性と宣言の間にコメントがある場合を明示していない。study 5.2 は今の振る舞いを「外れない場合」とし、新しいゴールデンテストがその解釈を固定した。
- 見出しが複数行にわたる関数（`function f(` から `) -> Unit` まで）では、`content(function, end)` の最初の行は引数の行になる。そのため、本体の最初の行の前の空の行は除かれない。これは前からの振る舞いで、06-03 の「開きの行の次の行」を字のとおりに読めば規則のとおりである。
