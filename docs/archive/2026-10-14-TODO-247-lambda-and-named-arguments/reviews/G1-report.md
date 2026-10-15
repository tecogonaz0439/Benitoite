### レビューの記録（高 0・中 2・低 6）

中
1. docs/design/02-impl/02-03-frontend.md「AST」231 行付近の「現在の構文解析器が受理するラムダは終端付きであり、`Explicit` を作る。」が、短いラムダ（`Omitted`）の実装と食い違う。修正案:「終端付きは `Explicit`、短い形は `Omitted` を作る」。
2. docs/design/06-tooling/06-03-formatter.md の冒頭の「以下の節の規則は、どれも【方針】である。」を消したため、印のない後続の節の確度が不明。修正案: 一文を戻すか各節に【方針】を付ける。

低
3. parser/exprs.rs の `parse_short_body` と lambda_bounds.rs の止まる字句の一覧に `do`・`then` がなく、01-02「外側の…ブロック境界…を残す」と食い違う（`with r = lambda() return x do` が E0201）。修正案: 一覧に加えるか仕様の言い方を絞る。
4. parser/mod.rs の `same_line_lambda_before_end` が E0201 のたびに全字句を走査する（字句数×誤りの数）。修正案: Bounds に boundary をキーにした集合を持たせる。
5. 同じ判定が関係のない誤りにも help を付ける。外側の終端付きラムダの最後の行が `bind f <- lambda(x) return x +`、次の行が `end lambda` のとき、真因は行末の `+` なのに「`end lambda` を同じ行へ」の help が付く。修正案: 本体の直前の字句が演算子なら help を付けない（など、誤導しない条件にする）。
6. lambda_bounds.rs の `delimiter_pairs` は閉じない短いラムダもスタックに積む。match の分岐の本体が短いラムダで終わると次の `case` で `top.2` が立たず、その分岐のガードの `if` がブロックの開きとして積まれる。`close` が `rposition` で探すので今は結果が変わらないが、不変条件が暗黙でテストもない。修正案: 短いラムダは積まないとコメントで明記（または実装を直す）し、二つ目の `case` にガードを書く形のテストを加える。
7. E0243 の help（Python 形の修正案）が終端付きの形 `lambda(x) return x + 1 end lambda` を示し、「一文なら短い形を推奨」と揃わない。修正案: 短い形を示し、01-02 の該当文も合わせる。
8. skill/SKILL.md の return の項の「except inside a `lambda ... end lambda` written there」は短いラムダにも当たる。修正案:「inside a lambda written there」。

テストの不足（低）: 見出しが行をまたぎ本体と同じ行に `end lambda` がある終端付きの形（`lambda(x,⏎ y) return x + y end lambda`）と、3・6 の境界の形に正の例のテストがない。

問題のなかった観点: R20 との一致（入れ子・括弧・コンマ・一行の if/match・文字列とコメントと補間の中の end lambda・CRLF・単独の CR・複数行の文字列・見出しの行の後のコメント）、整形器の意味の保存と冪等性、E0213・E0201・E0254・E0256 の条件と文言、テストの弱化なし、else・shadow・case other の方針、AGENTS.md の規約。

## 対応

- 中 1: `docs/design/02-impl/02-03-frontend.md` の「AST」を、終端付きは `Explicit`、短い形は `Omitted` を作る説明に修正した。
- 中 2: `docs/design/06-tooling/06-03-formatter.md` の「整形の考え方」の末尾に、後続の節の規則を【方針】とする一文を戻した。
- 低 3: `parser/exprs.rs` と `lambda_bounds.rs` の境界一覧へ `do`・`then` を追加し、外側の `with`・`if` がその字句を使う正の例を既存の parser テストへ加えた。
- 低 4: `Bounds` に境界位置をキーにした集合を保持し、`same_line_lambda_before_end` の全字句の再走査を集合の照会へ置き換えた。
- 低 5: `same_line_lambda_before_end` に本体末尾の字句の条件を加え、演算子・単項演算子・ドット・開き括弧で未完の本体へ移行ヘルプを付けない回帰テストを加えた。
- 低 6: `delimiter_pairs` の `case` で最上段のラムダ候補を降ろして次のガードを認識するようにし、不変条件のコメント・設計書の説明と、二つ目の分岐にガードを書く正の例を加えた（R23）。
- 低 7: `diag/codes.rs` の E0243、01-02 の該当文、02-03 の修正案の表を短い形へ揃え、ゴールデンのヘルプ全文と parser の期待を更新し、`gen_skill` で診断の参照文書を再生成した（R24）。
- 低 8: `skill/SKILL.md` の return の説明を `except inside a lambda written there` に修正した。
- テストの不足: `short_lambdas_preserve_boundaries_and_explicit_endings` に、複数行の見出しと本体の行の終端、`do`・`then`、ガード付きの次の分岐の正の例を追加した。

### テストの作成時の関門

追加したテストの境界は、字句解析・改行判定をつないだ公開の parser の出力である。既存の表へ正の例を追加し、外側のブロック境界・終端の種別・文の数を確認する。既存例には `do`・`then` の外側の境界と複数行の見出し、短いラムダの後のガードがなかった。診断の回帰テストは、未完の本体の診断コードと、外側の終端を移すヘルプを付けない契約を確認する。差し込み口や公開 API は追加していない。

修正前に `cargo test -p benitoite --lib short_lambda` を実行し、`do` の境界で E0201 が出る失敗と、行末の `+` に移行ヘルプが付く失敗を確認した。既存の assert の削除、期待値の緩和、ignore の追加はない。E0243 の文言を探す既存の期待は、短い部分文字列にせず、新しいヘルプ全文へ更新した。

### 検査

- `cargo run -p benitoite --example gen_skill`: 成功。生成物の差分は `skill/references/diagnostics.md` の E0243 のみ。
- `cargo test -p benitoite --lib`: 成功（1,129 成功、既存の ignore 21）。
- `cargo test -p benitoite --test skill_docs --test spec_examples --test reference_examples --test fmt_command --test golden --test skill_examples --test random_programs`: 成功（7 本、計 39 テスト）。
- `cargo clippy --all-targets`: 成功。
- `cargo fmt --check`: 成功。
- `git diff --check`: 成功。

変更した Rust ファイルの行数の純増は、本番コード 52 行、テスト 39 行である。テストの削除・ignore の追加はない。`formal/` は変更していない。依頼に従い `scripts/check.sh` と gc-stress は実行しておらず、取り込み時の検査はオーケストレータへ引き継ぐ。コミットと `docs/todo/` の変更は行っていない。
