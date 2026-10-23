# RV-F4 作業 F3R・F4a・F4b のレビュー

2026-10-23、レビュー担当。対象は `75b6c717`（F3R）、`78c34404`（F4a）、`05fd5111`（F4b）である。`git show` と、`05fd5111` の時点のファイル（`git show 05fd5111:<path>`）を読んだ。比べた資料は、plan.md の作業 F4a・F4b・F5、decisions.md の D21・D29・D34、`formal/Benitoite/Surface/FormatSpec.lean`、`Desugar.lean` の `interpolate`、01-12「文字列補間」、reviews/RV-F13.md、f3r・f4a・f4b の results.md である。ビルドとテストは実行していない。

## 結論

重い指摘はない。中の指摘が 1 件（F5 への申し送り）、軽の指摘が 7 件ある。Rust と Lean の型の受理表、七定数の符号化と順序、脱糖の形（全式の評価、変換、連結）は一致している。F2・F4a の一時防御もすべて外れている。

## 確かめた点（指摘なし）

### 1. Rust と Lean の一致

- **受理表**: `typeck/generate.rs` の `format_set` を、Lean の `Compatible` と場合ごとに比べた。
  - 種類 d・b・o・x・X は `FORMAT_INT` で、`IntegerType` の 8 型と一致する。Byte を含む。
  - f は `FORMAT_FIXED`（`DIV` の Float・Decimal・Float32）で、`FractionalType` と一致する。
  - s・c に符号かゼロ埋めを付けた場合は空集合になる。Lean の「s は String」と「符号・ゼロ埋めは数」の積も空になるので一致する。
  - 種類を省略して符号かゼロ埋めを付けた場合は `FORMAT_NUMBER` の 11 型で、`IntegerType ∨ FractionalType` と一致する。
  - 種類の省略だけなら `INTERP` の 14 型で、`SupportedType` の 14 型と同じ集合である。
  - 構文の妥当性（`SyntaxValid`）は、解析器の `read_spec_inner` で判定している。空の指定、幅 1〜65535、精度 ≤28 かつ種類 f、寄せには幅、ゼロ埋めには幅かつ寄せの省略、`#` は b・o・x・X、の各条件が Lean と一致する。幅 0 と先頭の 0 を拒否することは、文法（`Width = NonZeroDigit {Digit}`）の側の条件である。
- **七定数**: `ast::FormatSpec::constants` は `kindCode`・`alignCode`・`signCode` と同じ番号を使い、幅の省略を 0、精度の省略を −1 にする。値の型は Integer・Integer・Integer・Boolean・Boolean・Integer・Integer で、`constantTypes` と同じ順である。内部頭の引数名（value・kind・align・sign・alternate・zero・width・precision）は `parameterNames` と一致する。`base::format::FormatSpec::decode` は、この符号化で妥当なものだけを受理する（幅 0 は省略と読む）。
- **脱糖**: `ir/desugar/exprs.rs` の `interpolation` を `interpolate` と比べた。
  - 先に全式を左から `eval` で評価する（Lean の sequence に当たる）。
  - 次に、部分を書いた順に処理する。書式付きの部分は `%Format.<型>`（`table::FORMAT` で、`headName` と同じ 14 の名前）を value と七定数で呼んで `bind` する。書式なしの String はそのまま使い、そのほかの型は `str_T` を `bind` する。
  - 書式付きの String も書式化の頭へ渡す。`if let Some(format)` を String の判定より先に置いているので、Lean で `.formatted` が `.stringExpr` より優先されるのと一致する。
  - 空の断片を省くこと、m = 0・1 のときの扱い、左結合の連結、最後の連結を末尾の計算にすることも、`joinStringParts` と同じである。

### 2. 定数評価

- `typeck/consts.rs` の `format_value` は、実行時と同じ `base::format` の `decode`・`prepare`・`parts` を使う。確保の前に、u64 の全長を論理上限と比べ、`usize` へ変換し、共有予算に数えている。書式付きの片に 128 バイトの見込みは使っていない。
- 書式付きの片の予算は、片を作るときと最後の連結で二度数えている。実行時も、内部頭の確保と連結の確保で二度確保するので、扱いは合っている。
- `formatted_interpolation_connects_constants_and_both_evaluators` は、22 組の同じ独立の期待値を、定数（`const text{i}`）と関数の実行の両方に求める。
  - 定数評価が `Unavailable` になると値が作られず、テストは通らない。したがって、このテストは定数評価の経路を実際に通っている。
  - main が `Result.Error` を返すと `EndKind::MainError` になり、`require_returned` で失敗する。期待値の比較が素通りすることはない。
  - 価値は高い。

### 3. 一時防御の除去

- 次の 4 か所がすべて消えている。
  - `pending_formats` とその E0262 の報告。
  - E0262 の注記 `pending`（`codes.rs` と生成した diagnostics.md）。
  - `eval_interp` の `Unavailable` での拒否。
  - 脱糖の `InternalError` での拒否。
- テストでも、`d.code != Some(C::E0262)` の除外、関数と定数の防御の期待、fmt_command の実行拒否の期待が除かれている。
- RV-F13 の L2 の 6 か所（01-02、01-12 の例の前の文、00-04、`pending`、生成 Skill、英語リファレンス）も、接続後の記述に変わっている。`git grep` で "not connected"・"intermediate build"・"未接続" を探したが、書式の残りはなかった（下の L1 を除く）。

### 4. F4a の E0468 と回復、F3R の修正

- E0468 は、コロンを含む書式全体を主位置、値を関連位置にしている。整数に f を当てた場合には専用の案内（`integer_fixed`）を出す。自動の修正案は付けない。
- 回復の条件は `!has_error(actual) || (InterpFormat && actual が全体として Error でない)` である。型全体が診断済みの原因から未確定になった場合だけ報告を抑え、`List[Error]`・`Box[Error]`・束縛の明示の契約による不適合は残す。declarations の 3 原因 × 6 入力の表が、抑える場合と残す場合の両方を確かめている。
- F3R の修正は、それぞれ RV-F13 の指摘に合っている。
  - M1: `from_utf8` が失敗したら、書式の診断を出さずに None を返す。
  - L9: 字句と字句の間にある非 ASCII 文字は、字句解析の報告に任せる。
  - L1: 修正案を当てた結果を一度だけ再検査する。空白と `-` は一つの編集でまとめて消す。
  - L6: 内部頭の失敗はすべて `Stop::Internal` にする。長さの上限は従来の `CheckedLen::bytes` が報告する。
  - L3: 用語集に「書式」「書式化」を加え、フォーマッタの操作の「整形」と書き分けた。
- 再検査は書式の長さに比例する一回だけなので、二乗の仕事量にはならない。

## 指摘

### 読めば確定するもの

#### M1（中）F4b→F5: 交換の書き出しが書式を捨てる。新しいゴールデン入力がまだ routing manifest にない

- 場所: `crates/benitoite/tests/desugar_export/exchange.rs` 1277〜1302 行（`a::Expr::Interp`）、`exchange-manifest.json`。対象の入力は `testdata/eval/formatted_interpolation_order.bnt`。
- 問題: 書き出しは `s.format` を見ない。書式付きの部分を、String なら `stringExpr`、そのほかの型なら `converted`＋`str_T` として出す。F4b で書式付きのプログラムが型検査を通るようになったので、ignored の `export_desugar_corpus`（`check-formal.sh` が走らせる）は、上のゴールデン入力を集めて書式なしとして書き出す。しかし、manifest にこの入力の行はない（`git grep` で 0 件）。そのため、HEAD では `check_named.py` の `check_routing` が「discovered golden input missing」か「routing identifiers」の不一致で止まると読める。F4b の検査の割り当てに `desugar_export` は入っておらず、計画どおり F5 の範囲である。ただし、manifest に行を足すだけで通すと、書式を落とした交換の入力が「範囲内」として Lean へ渡る。
- 修正案: F5 の完了の条件に次の三つを明記する。
  1. `exchange.rs` で、書式付きの部分を `formatted: {ty, spec}` として書き出し、変換頭に `%Format.<型>` を出す。七欄は必須とし、幅と精度の省略は null にする。
  2. 書き出しの版を corpus 14・sidecar 6 に上げる。
  3. 上の入力の routing の分類を、書式なしの形として登録しない。

  F5 の担当には、F4b の後から F5 までの間は check-formal 全体が通らない状態であることを伝える。

#### L1（軽）F4b: テストのコメントが途中状態のまま残っている

- 場所: `crates/benitoite/tests/runtime_builtins.rs` 24〜25 行の「F4b 前なので表層の補間はまだ使わない。」
- 問題: F4b の後では事実と違う。AGENTS.md「コメントと名前」は、作業の ID をコメントに引かないことも求めている。
- 修正案: 「表層の型選択と定数評価は `formatted_interpolation_connects_constants_and_both_evaluators` が確かめる。」のように、接続後の役割の分担に書き換える。

#### L2（軽）F3・F3R: コメントが判断の番号 D29 を引いている

- 場所: `crates/benitoite/src/base/format.rs` 13 行、`crates/benitoite/src/builtins/table.rs` 648 行（F3R が書き換えた行）、`tests/runtime_builtins.rs` 82 行（「D29 / study 5.2」）。
- 問題: decisions.md は改造を終えると `docs/archive/` へ移る。AGENTS.md「コメントと名前」は、根拠を今の設計書の節で示すことを求めている。
- 修正案: 「（設計書 02-06「書式化の内部頭」）」に置き換える。テストの「study 5.2」は、03-06「書式付き補間の内部書式化」に置き換える。

#### L3（軽）F3R: Lean のコメントに「整形」が残っている

- 場所: `formal/Benitoite/Surface/FormatSpec.lean` 3 行（「内部の整形呼び出しの契約」）、163 行（「専用の整形頭」）、`Surface/Syntax.lean` 228 行（「整形関数」）、`Exchange/Builtins.lean` 127 行（「内部の整形頭」）。
- 問題: F3R は、値の操作を「書式化」、フォーマッタの操作を「整形」と書き分けた。そして 07-04・01-12・Rust のコメントを揃えた。Lean のコメントだけが古い語のままである（定義と定理は変わらない）。
- 修正案: Lean に触る F5 で、コメントを「書式化の内部頭」「書式化の関数」に揃える。

#### L4（軽）F4b: 予算のテストの名前とコメントが、確かめていない順序を主張している

- 場所: `crates/benitoite/src/typeck/consts.rs` の `formatted_interpolation_checks_size_and_budget_before_allocation`。
- 問題: 三つの組はどれも、最後の連結の `budget.string(len)` だけでも同じ結果（String の上限か予算の超過）になる。片を作る前の検査（`format_value` の中の検査）を消しても、このテストは通る。片の大きさは幅の上限 65535 と元の値の大きさで抑えられるので、実害は小さい。ただし、名前の「before_allocation」とコメントの「確保前に検査する」は、このテストでは確かめていない。表示の幅をバイト数と取り違える退行と、128 バイトの見込みを流用する退行は、一つ目の組の期待値で捕まえられる。
- 修正案: 名前を `formatted_interpolation_uses_display_width_and_checks_limits` などにし、コメントを、確かめていることに合わせる。順序そのものは観測できないので、読んで確かめる事項とする。

#### L5（軽）F4b: 手書きの Skill が、検査をハーネスがすると書いている

- 場所: `crates/benitoite/skill/references/idioms.md` の「Static interpolation formats」の 2 文目「The harness checks syntax and type compatibility before execution.」
- 問題: 構文と型の適合を検査するのは処理系（`benitoite check`・`run`）である。ハーネスは処理系を呼ぶだけである。英語リファレンスは「The harness can check and run scripts」と書いていて、それとも食い違う。
- 修正案: 「`benitoite check` reports format syntax errors (E0262) and type incompatibility (E0468) before execution.」に直す。

#### L6（軽）F4b: 定数評価が内部の不整合を `Unavailable` にまとめている

- 場所: `crates/benitoite/src/typeck/consts.rs` の `format_value`（`decode`・`prepare`・`parts` の `map_err(|_| EvalError::Unavailable)` と、書式付きでない値の型の分岐）。
- 問題: 型検査を通った書式では起きない状態である。それでも、起きた場合は定数が無言で失敗の集合に入り、診断が出ない。後の段で定数の値がないことが別の形で現れることになる。実行時の内部頭は `Stop::Internal` で処理系の不具合として報告するので、扱いが揃っていない。AGENTS.md「失敗を panic で表さない」の内部の誤りの扱いにも合わせたい。
- 修正案: `EvalError` に内部の誤りを表す既存の手段があれば、それを使う。なければ現状のままとし、コメントに「型検査を通った書式では到達しない」と書く。必須ではない。

### 実行しないと分からないもの

#### L7（軽）F4a: どの型にも適合しない書式が、値が診断済みの原因で未確定のときに報告されないおそれ

- 場所: `crates/benitoite/src/typeck/solve.rs` 1736〜1744 行の、`matches!(&actual, ITy::Error)` による抑制。
- 問題: `+s`・`08c`・`+c` は、空集合になる書式である。どの型の値に対しても不適合なので、値の型の原因とは独立の誤りである。しかし、値が `SourceLocation.here` や `1(2)` で全体として Error になると、抑制の条件に当たって E0468 が出ないと読める。利用者が原因を直した後で、初めて E0468 が出ることになる。D21 の「原因に依存する不適合だけを抑える」に照らすと、報告してよい場合である。declarations の回復の表には `.2f` しかなく、この組み合わせは確かめていない。
- 修正案: まず `bind value <- 1(2)` の後の `"${value:+s}"` で再現を確かめる。再現したら、`set` が空のときは抑制の条件を外す。または、型に依存しない誤りとして、値の回復の状態にかかわらず報告する。回復の表にも空集合の書式を 1 行加える。

## テストの価値（test-audit の観点）

- F4a の 2 件（型検査の境界）と 1 件（公開パイプライン）について。
  - 14 型 × 21 書式の 294 組で、期待のマスクを仕様から固定している。主位置・関連位置・型の表への記録も確かめている。
  - 回復の表は、抑える場合と残す場合の両方を含む。
  - 書式の無視、Byte の漏れ、フラグの制限の漏れ、抑えすぎと抑え漏れを捕まえられる。重複はない。
- F4b について。
  - `runtime_builtins` の 1 件は、14 型・省略の精度・String の書式化・負の零・Decimal の符号の消失・結合文字・空の String を、定数と二つの実行器に同じ独立の期待値で求める。表層の型選択・引数の列・定数評価の欠落を捕まえられ、価値が高い。
  - ゴールデンの 1 件は、四つの式の副作用の順序と、混在した書式付きの連結を確かめる。変換は純粋なので、変換を評価の間に挟む方式とは区別できない。ただし、それは観測できる違いではないので、問題ではない。
  - 予算のテストの価値と名前の食い違いは L4 に書いた。
- F3R について。
  - M1・L9 の再現のテストは、公開の lex→改行判定→parse の境界で、修正の前に失敗したことが記録されている。
  - 修正案の表と L4 の丸めの三例は、既存の表へ足したもので、重複はない。
- テストのためだけにある本番のコードや、テスト用に公開の範囲を広げた箇所はない。

## 重さの要約

| ID | 重さ | 種類 | 要旨 |
|---|---|---|---|
| M1 | 中 | 読めば確定（F5 へ申し送り） | 交換の書き出しが書式を捨てる。新しいゴールデン入力が routing manifest にないので、HEAD の check-formal は通らない |
| L1 | 軽 | 読めば確定 | `runtime_builtins.rs` 25 行の「F4b 前」のコメント |
| L2 | 軽 | 読めば確定 | コメントの D29 の参照を設計書の節に置き換える |
| L3 | 軽 | 読めば確定 | Lean のコメントの「整形」 |
| L4 | 軽 | 読めば確定 | 予算のテストの名前が、確かめていない順序を主張している |
| L5 | 軽 | 読めば確定 | Skill の「The harness checks」 |
| L6 | 軽 | 読めば確定（任意） | 定数評価の内部の不整合が無言の `Unavailable` になる |
| L7 | 軽 | 実行しないと分からない | 空集合の書式が、値の回復の抑制で報告されないおそれ |
