# W6（7bf5d907）のレビュー

対象: コミット `7bf5d907`（12 ファイル、+76・-29）。計画 `plan.md` の「作業 W6」、`decisions.md` の Q7・R20〜R22、`study.md` の D 部、事前点検の「W6 への補足」、実装者の報告 `W6-report.md` と照らした。ファイルは `git show 7bf5d907:<path>` で読み、ビルド・テストは走らせていない。

## 結論

重大・中の所見はない。計画と判断（Q7 案 B、R20、R21 案 1、R22 案 Y）のとおりに実装されており、補足からの逸脱は、補足が書き漏らした件数の期待値 3 か所の更新だけである（正しい直し）。軽微な所見を 6 件挙げる。いずれも取り込みを止める理由にはならない。

## 観点ごとの確かめ

### (1) 計画と判断との一致

- Q7: `Regex.maxStringBytes` を `regex.rs` の `span_at` の後に `builtin!` で加え、`DECLS` の末尾に登録した。`Regex.bnt` は `public` なしで宣言し、`appendPart` の `1073741824` を `maxStringBytes()` に置き換えた。03-08 に二か所書き足した。補足のとおり。
- R20: `run_fmt_case` で `fmt` の方式（`fmt-check` でない）のとき、実際の出力（`results`）を再び整形する。`Syntax` は飛ばし、`changed` と `Verify` は失敗にする。`check_properties` と補助の関数 `is_idempotent` を共有した。BLESS の前に確かめ、失敗があれば書き直さずに戻る。07-03 と 06-03「テスト」を直した。
- R21: `walk.rs` の `top_decl` の印を消し、`roles/tests.rs` の 2 行目を `(false, false)` にし、06-03「空の行」を直して E0228 の一文を足した。06-03「コメント」の「加えない」側の記述は残した。補足のとおり。
- R22: `if_chain` の両枝（`ElseBranch::Block`・`ElseBranch::If`）と `handle` で、直前の本体の `stmts` が空のときだけ `closers` に積む。`match` は対象外。`print.rs` は変えていない。ゴールデンの 2 行だけが変わった。

### (2) 正しさ

- 権限・純粋さ・登録: `pure fn`、引数 0、`Pure` として登録表のテスト（名前・権限・引数の数・部分の長さ・総数 304・Pure 231・凍結した部分表の合計 136）に載った。値を作らず確保もないので、大きさの確かめは要らない。`u64 → i64` の変換は `try_from` で行い、失敗を `Stop::Internal` にしている（実際には失敗しない）。
- 非公開: `Regex.bnt` の宣言に `public` がないので、利用者は `Regex.maxStringBytes()` を名指しできない。利用者のスクリプトが `@builtin("Regex.maxStringBytes")` と書いても E0807（`@builtin` は標準ライブラリだけ）で断られる。`findAt`・`spanAt` と同じ扱いで、`gen_skill` の生成物に差分が出ないことを実装者が確かめている。
- 呼び出しの回数と費用: `appendPart` は一致ごとに 2 回（間の部分と置換の文字列）と最後に 1 回呼ばれ、そのたびに `maxStringBytes()` を 1 回呼ぶ。組み込みの関数の呼び出し 1 回は、同じ関数の中の `List.append`・`String.byteLength` と同じ程度の費用であり、一致ごとの `findAt`/`spanAt` の照合と比べて小さい。判定の意味（`nextBytes > 2^30` で結合を試す）は変わらない。所見 L6 に、気になるときの代替を書いた。
- 冪等性の確かめと失敗の見逃し: 二度目の整形で `Syntax` を飛ばすのは、一度目が構文の誤りで整形を断って元のままのファイル（`syntax_error.bnt`）のためである。一度目が成功した出力は、`verify::check_syntax` が構文の誤りのないことを確かめてから書かれるので、二度目に `Syntax` が出ることはなく、飛ばす分岐が整形の不具合を隠すことはない。一度目が `Verify` で失敗して元のままのファイルは、二度目も `Verify` になり失敗として数える。実装者は、出力に空の行を一時的に足して「formatting is not idempotent」で失敗すること、そのとき BLESS がサイドカーを書き換えないことを確かめている。
- BLESS との関係: 冪等でないときは `failures` に積んでから `return Ok(())` するので、BLESS の実行でもテストは失敗し、`.formatted` と `.stdout` 等は書き換わらない。古い `.formatted` の削除（関数の先頭）は冪等性の確かめより前に行うが、冪等性とは無関係なので問題ない。
- `///` の印を消したことの影響: 説明が結び付く入力では `///` の行と最初の字句の行の間に空の行がなく、結び付かない入力は E0228（E02nn）で整形を断る。さらに `print.rs` は前の行がコメントだけの行なら `leading` を見ない。出力は変わらず、ゴールデンにも差分がない。設計書・Skill・リファレンスに「`///` の行と属性の間の空の行を除く」の記述は残っていない（`git grep` で確かめた）。
- 空の本体の前のコメント:
  - 空でない分岐: `stmts` が空でないときは `closers` に積まないので、`comments.formatted` の `// before else` は外側のまま（実装者がバイト単位で同じことを確かめた）。
  - `match`: 触れていない。`case` の前のコメントは今のとおり次の `case` の段。
  - 入れ子・`else if`: `if_chain` は連なりのどの段でも `open` に最も外側の `if` を渡すので、`inner_level` は「最も外側の `if` の行の段 + 1」になり、`end if` の `inner_level` と同じ段になる。`else if` の分岐が空のときは、再帰した `if_chain` の中で内側の `then_block` を見て判定するので、分岐ごとに正しく決まる。`if` が `bind x <- if ...` のように行の途中で始まるときも、`end if` と同じ計算なので揃う。
  - 冪等性: 判定は AST の構造（文の有無）だけで決まり、コメントの段は入力の字下げに依らないので、整形の結果を再び整形しても同じ段になる。R20 の確かめが `blank_lines_comments` でこれを確かめる。

### (3) 実装の規約（組み込みの関数の書き方）

`builtin!` の宣言の形で書き、内部の共通の形を直接書いていない。純粋な文脈を受け取り、`let _ = ctx;` は前例（`samples.rs`）どおり。`Stop::Internal` の説明の文字列は処理系の不具合の説明なので、`text` に載せなくてよい（AGENTS.md「文言」）。`///` のコメントと設計書の節の参照がある。`as` を使っていない。問題はない。

### (4) テスト（test-audit）

新しいテストの関数は加えず、既存の実行器の確かめを広げ、既存の表の期待を直した。`check_properties` と重複していた二度目の整形を補助の関数にまとめた（重複の決まりに合う）。R20 と R22 は、退行を入れて失敗することを実装者が確かめた。`else if` の空の分岐の枝はどのテストも通らない（所見 L1）。

### (5) 設計書・CHANGELOG

06-03「コメント」「空の行」「テスト」、07-03 の方式の表、03-08「Regex」は実装と合う。細部は所見 L2〜L4。

## 所見

### 重大

なし。

### 中

なし。

### 軽微

**L1. `else if` の空の分岐の枝を、どのテストも通らない**
- 場所: `crates/benitoite/src/cli/tools/formatter/roles/walk.rs` 801〜803 行（`ElseBranch::If` の枝の `if e.then_block.stmts.is_empty()`）、`crates/benitoite/testdata/fmt/blank_lines_comments.bnt`。
- 問題: ゴールデンが確かめるのは `if c then <空> else <空> end if`（`ElseBranch::Block` の枝）と `handle` だけである。`ElseBranch::If` の枝の 3 行を消しても、どのテストも失敗しない。06-03「コメント」は「`else` で始まる行」と一般に書いており、`else if` も含む。
- 直し方の案: `blank_lines_comments.bnt` に、中身がコメントだけの `if a then` の直後に `else if b then`（中身はコメントだけか文一つ）が続く例を加え、`.formatted` を BLESS で作り直す（ゴールデン 1 件の入力の追加で、新しいテストは増えない）。

**L2. `print.rs` のコメントが、広がった `inner_level` の意味に合っていない**
- 場所: `crates/benitoite/src/cli/tools/formatter/print.rs` 377 行「コメントだけの行は、後の最初のコードの行の段（閉じの字句なら閉じる構文の中の段）に置く。」
- 問題: `roles.rs`・`walk.rs` の説明は「閉じの字句か、中身が空の分岐・本体の後の区切りの字句」に直したが、`inner_level` を読む唯一の箇所のコメントは閉じの字句だけを挙げたまま。
- 直し方の案: 「（閉じの字句か、中身が空の分岐・本体の後の `else`・`with` なら、構文の中の段。設計書 06-03「コメント」）」に直す。

**L3. 03-08「Regex」の挿入の位置で、次の文の主語がずれる**
- 場所: `docs/design/03-interop/03-08-text-and-data.md` 155 行。
- 問題: 「`findAt` は…、`spanAt` は一致の範囲だけを返す。」と「入力を切り出さずに探すので、`\b`・`^` などの前後の文脈を保つ。」の間に `Regex.maxStringBytes` の文を挟んだので、「探す」の主語（`findAt`・`spanAt`）が一文離れた。また、158 行の項目にも「この上限の値は `Regex.maxStringBytes` から得る」とあり、関数の紹介が二か所に分かれている。
- 直し方の案: 155 行の挿入を項目の末尾（「ほかの公開の関数は組み込みで実装する。」の前か後）へ移すか、155 行からは消して 158 行の「この上限の値は、非公開の組み込みの関数 `Regex.maxStringBytes` から得る」に一本化する。補足は 155 行の列挙に加える指示だったので、前者が補足に近い。

**L4. CHANGELOG の項目に `fmt --check` への影響が書かれていない**
- 場所: `CHANGELOG.md` 66 行（Fixed の先頭の項目）。
- 問題: 正規形が変わるので、0.0.2 で `fmt` 済みのファイルのうち、中身がコメントだけの `then`・`else if`・`handle` の本体を持つものを `fmt --check` が報告するようになる。同じ節の既存の項目（構文の中身の最初の空の行の項目）は「`fmt --check` reports such files until they are formatted again.」と書いており、揃っていない。
- 直し方の案: 末尾に「`fmt --check` reports such files until they are formatted again.」を足す。あわせて、項目の後の空の行は、ほかの作業のまとまりの区切り方に合わせて取り込みのときに整える（今は Fixed の先頭の 1 項目だけが空の行で離れている）。

**L5. 07-03 の `fmt` の行に、BLESS が冪等でない結果を書き直さないことが書かれていない**
- 場所: `docs/design/07-quality/07-03-compiler-testing.md` 114 行、`crates/benitoite/tests/golden/formatting.rs` 91〜94 行。
- 問題: 実装は、冪等でない出力を BLESS で期待値にしない（テストを失敗させ、書き直さない）。設計書は冪等性を確かめることだけを書く。振る舞いとしては当然の帰結に近く、書かなくても誤りではない。
- 直し方の案: 書くなら、07-03 の BLESS の説明の節に「`fmt` の方式で冪等性の確かめが失敗したテストは、期待値を書き直さない」と一文足す。書かないままでもよい。

**L6. （任意）`appendPart` が呼ぶたびに `maxStringBytes()` を呼ぶ**
- 場所: `crates/benitoite/src/prelude/stdlib/Regex.bnt` 110 行。
- 問題: 置換の部分ごとに組み込みの関数の呼び出しが 1 回増える。費用は照合と比べて小さく、誤りではない。
- 直し方の案: 直さなくてよい。性能の測定で `replaceAll` の多数一致に差が見えたときに、`replaceAll` の入口で一度だけ求めて `parts` の組に持たせる形を検討する（組の型が変わるので、今は勧めない）。

## 報告への補足

- 実装者が書いた、凍結した 10-17 の `TokenRole::inner_level` の説明（閉じの字句のとき）より意味が広がった点は、補足の指示どおりであり、報告にも書かれている。型・欄・シグネチャは変わっていない。
- ゴールデン全体の TCP の 10 件は sandbox の制約による失敗で、W6 の変更（Regex の判定・フォーマッタ）とは関係しない。オーケストレータの最後の `check.sh` で確かめればよい。
