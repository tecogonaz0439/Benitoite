# RV4 の指摘の直し（Z3）の確認

## 対象・実行したこと・件数

- 対象:
  - `git diff e9de51fc..aed9c6fe`（Z3 の取り込み。HEAD は `aed9c6fe`）。
  - RV4.md、RV4-response.md、decisions.md の R198〜R201、z3/results.md、work/m010/notes/Z3.md。
- 実行したこと:
  - `cargo build --release -p benitoite` で作った `./target/release/benitoite` で、次を実行した。
    - `check`・`run`・`test`・`check --report=json`・`fmt`・`fmt --check`
    - 入力は RV4 の `work/m010/reviews/rv4-scratch/`（rec1・log2・here3）と、新しく作った `work/m010/reviews/rv4b-scratch/` の .bnt である。
  - 名指しの単体テストを実行した。`cargo test -p benitoite --lib -- record_values_preserve_statement_boundaries record_declarations_allow_newlines_before_the_type_name record_is_rejected_as_a_field_name io_all_warning_uses_the_canonical_log_name source_location_errors_do_not_hide_independent_type_errors` は 5 件とも成功した。`cargo test -p benitoite --lib syntax::` は 115 件成功した。
  - 新しい golden（opaque-wrapper-equality）は、`./target/release/benitoite test` で直接実行した。環境変数を付けた golden の実行は許可されなかった。表示の left・right と結果（成功 1・失敗 3・終了 1）は、`.stdout` の期待と一致した。
  - コードと設計書の差分、関係する parser・typeck・formatter のコードを読んだ。
- しなかったこと: cargo test の全件、scripts/check.sh、古い版との比較用の worktree の作成。
- 件数: **重 0・中 0・軽 5**。

RV4 の中1・軽1〜5 は、どれも指摘の筋書きでは直っている（後述の「確かめた内容」）。下の軽は、直しの範囲の外に残った点か、直しで新しく生じた細かい点である。

## 軽

### 軽1 01-02 の文法の RecordDecl が、`record` と型名の間の NL を許していない（中1 の直しの続き、確かめた事実）

- 場所:
  - `docs/design/01-spec/01-02-syntax.md` の 512 行と 948 行。どちらも `RecordDecl  = "record" UpperIdent [ TypeParams ] LineList(Field) "end" "record" .` である。
  - 対応する 01-01「改行による区切り」の規則 2 の追記。
- 問題点:
  - Z3 で、`record` の後の改行は字句の段で消えなくなった。そのため `record` と型名の間には NEWLINE（文法の `NL`）が残る。
  - 01-01 は「宣言の構文解析で読み飛ばす」と書いた。しかし 01-02 の文法は直していない。文法どおりに読むと `record NL Box` は RecordDecl に当たらない。
  - 01-02 は、ほかの省ける改行を `MatchExpr = "match" Expr "with" [ NL ] …` のように文法の中に `[ NL ]` で書いている。RecordDecl だけが、別の章の文章で例外を足す形になった。
  - 01-spec に「宣言の構文解析で」という処理の段の言い方が入った点も、文法に書けば要らなくなる。
- 失敗の筋書き: 01-02 の文法だけを見て parser や道具（構文の強調、外部の parser）を作る人や LLM は、`public record` の後で改行してから型名を書く宣言を拒む。処理系は受理するので、仕様と実装が食い違う。
- 修正案:
  - 01-02 の二か所を `RecordDecl = "record" [ NL ] UpperIdent …` に直す。
  - 01-01 の追記は「レコード宣言では `record` と型名の間に NEWLINE を置いてよい（01-02 の RecordDecl）」のように、文法を指す書き方にする。

### 軽2 E0467 の置き換えの後にも、連鎖した診断が出る場合が残る（軽3 の直し、確かめた事実）

- 場所:
  - `crates/benitoite/src/pipeline/source_location.rs` の 191〜194 行（誤りの式への置き換え）。
  - `crates/benitoite/src/typeck/consts.rs` の `bad_shape`（262 行で `Expr::Error` を定数に使えない式とする）。
  - `docs/design/02-impl/02-04-resolver.md`「位置の式の事前展開」の追記。「型の誤りを連鎖させずに同じファイルの独立した誤りも報告する」とある。
- 問題点と筋書き（三つ。どれも run・test へは進まない。終了は 2 で、`--report=json` も `executed:false` である）:
  1. **定数の中の E0467 に E0433 が重なる（Z3 で新しく出る）**。
     - `rv4b-scratch/here_const.bnt` は `const loc: function() -> SourceLocation.Location = SourceLocation.here` である。
     - 同じ範囲に E0467 と E0433 "this expression cannot be used in a constant" が出た。E0433 の help は "write a function without parameters…" である。
     - E0467 の help（`SourceLocation.here()` と書く）と、向きの違う修正案が同じ位置に並ぶ。`[SourceLocation.here]` の形（here_const2.bnt）でも同じだった。
     - G1 の時点では型検査へ進まなかったので、E0467 だけだった。
  2. **パイプの右辺の引数付きの呼び出しでは、引数のエフェクトが消える（Z3 で新しく出る）**。
     - `rv4b-scratch/here_effect.bnt` は `function main() -> Unit uses IO.All` の本体に `bind h <- () |> SourceLocation.here(noisy())` を置いた。`noisy` は Console.Write を使う。
     - 結果は E0467 と W0501 "remove `uses IO.All`; this function performs no effects" で、宣言を消す差分も付いた。
     - 呼び出し全体を誤りの式にしたので、`noisy()` の分のエフェクトも消えたためである。入力の形は不自然なので、実害は小さい。
  3. **束縛した名前を後で別の型として使うと、離れた位置に E0401 が出る（型検査の既存の回復の性質）**。
     - `rv4b-scratch/here_chain2.bnt` で次を書いた。
       - `bind f <- SourceLocation.here`
       - `bind n: Integer <- f`
       - `match f with case Option.Some(v) -> …`
     - パターンの位置に E0401 "expected `Integer`, found `Option[_]`" が出た。
     - `bind f <- 1(2)`（E0403）で同じ形を試しても、同じ E0401 が出た（typeck_recovery.bnt）。つまり Z3 が作った不具合ではない。誤りの型になった値を束縛した名前が、次の注釈で型を決められてしまうという、既存の回復の性質である。
     - それでも 02-04 の「型の誤りを連鎖させずに」は言い過ぎになる。名前を使わない入力（Z3 のテスト）では成り立つ。
     - あわせて「同じファイルの独立した誤り」とあるが、型検査はプログラム全体を対象にするので、ほかのファイルの誤りも出る。
- テストの不足: `source_location_errors_do_not_hide_independent_type_errors` の入力では、束縛した名前を使わない。定数・パイプの引数・名前の後の使用の場合はない。
- 修正案:
  - 1 は、`bad_shape` で `Expr::Error` を `None`（報告済み）として扱う。または、E0467 で置き換えたノードの番号を型検査に渡し、E0433 を出さない。
  - 2 は、パイプの右辺の呼び出しでは、callee だけを誤りの式にして引数を残す。または、誤りのある関数では W0501 を出さない。
  - 3 は、02-04 の文を「誤りの式は型検査の既存の回復（02-05「誤りの報告と検査の継続」）で扱い、独立した誤りも報告する」に弱める。束縛の回復の改善は、docs/todo の項目にする。
  - 1 と 2 を直すなら、pipeline の同じテストに表の行を足す。

### 軽3 宣言の 2 番目以降の欄名に `record` を書くと、「`record` が閉じていない」と出る（軽2 の直しの範囲外、確かめた事実）

- 場所:
  - `crates/benitoite/src/syntax/parser/items.rs` の `parse_record_decl` の欄の繰り返し（862 行の `is_decl_start` で抜ける）。
  - 01-01 のキーワードの節の追記「宣言・構築・更新・パターンのいずれでも拒否する」。
- 問題点:
  - Z3 は、構築・更新・パターンの欄名を `records::field_name` の検査で E0201 "expected a record field, found `record`" にそろえた。
  - しかし、宣言の欄は `field_name` を通らない。欄の繰り返しは、`record` を次の宣言の始まりとみなして抜ける。
- 失敗の筋書き:
  - `rv4b-scratch/rec_field_decl.bnt` では、`record Box` の 2 番目の欄に `record: Integer` を書いた。E0214 "`record` is not closed"（`end record` を求める）と、E0201 "expected an uppercase name, found `:`" が出た。
  - 利用者や LLM は `end record` を足しにいく。欄名を変えるという正しい直し方の手掛かりがない。
  - 1 番目の欄に書いた場合（rec_field_decl_first.bnt）は "expected a record field" が出るが、後ろに `:` の E0201 も重なる。
  - 拒否するという 01-01 の規定は守られている。G1 からある振る舞いで、Z3 が持ち込んだものではない。
- テストの不足: `record_is_rejected_as_a_field_name` は、構築・更新・後続の欄・パターンの四つだけで、宣言の欄はない。
- 修正案:
  - 宣言の欄の繰り返しで、`record` の次が `:` なら欄名の誤り（E0201 "expected a record field"）として報告し、行を読み飛ばす。
  - 同じテストに、宣言の 1 番目と 2 番目の欄の行を足す。

### 軽4 利用者の `Log` モジュールがある所では、W0501 の修正案 `uses Log` が通らない（軽1 の直し、確かめた事実）

- 場所: `crates/benitoite/src/typeck/effects/declarations.rs` の `effect_name`（284 行）。モジュールの最後の段と名前が同じ組み込みのエフェクトでは、取り込みの状況を見ずに `Log` を返す。
- 問題点と筋書き:
  - `rv4b-scratch/proj/Main.bnt` で `import Log`（利用者のモジュール）を書き、`uses IO.All` の関数から `Benitoite.Log.info(…)` を呼んだ。
  - W0501 は "write `uses Log`" とその差分を出した。適用すると E0315 "`Log` is not an effect" になった。通る書き方は `uses Benitoite.Log` だった。
  - 同時に出る E0501 の help（"add `uses Log`"）も、前から同じ誤りを持つ。
  - G1 の修正案 `uses Log.Log` も、この場面では E0303 になる。退行ではない。
  - 02-04 は「利用者同名の宣言には正規表示Logを適用しない」と書くが、利用者のモジュールが prelude の Log を隠す場合の修正案は決めていない。
- 修正案:
  - 診断の位置のモジュールで `Log` が利用者のモジュールを指すなら、`Benitoite.Log` を返す（E0501 の help も同じ関数にそろえる）。
  - 優先度は低い。直さないなら docs/todo の項目にする。

### 軽5 三つの包みが鍵の型として使えることと、その鍵の順序を書いていない（軽4 の直しの続き、確かめた事実）

- 場所:
  - `docs/design/03-interop/03-06-stdlib.md` の Range と NonEmptyList の節。
  - `Range.bnt`・`NonEmptyList.bnt` の説明と、生成した Skill の参照。
- 問題点:
  - Z3 は「`=` は保存した欄全体を構造で比べる」と書いた。また、もとの「等値・key・Showを包みの公開契約として追加しない」を「独自の等値やkeyの規則、Trait.Showの実装を加えない」に改めた。
  - 一方、実際には包みは `key` の制約も構造で満たす。`rv4b-scratch/opaque_key.bnt` の `Map.fromList([Pair(ne, 1)])`（`ne` は `NonEmptyList[Integer]`）は受理され、実行できた。
  - 鍵の順序（Map.keys・Set.toList の並び）も内部の欄の順序で決まるはずである（推測。順序は確かめていない）。等値と同じく、欄の中身が観察できる経路になる。
- 失敗の筋書き: Skill を読んだ LLM は、包みを Map の鍵に使えるかを判断できない。使えたとしても、並びが内部の欄（CheckedLength なら minimum が先）で決まることを知らない。
- 修正案:
  - 03-06 と二つの標準ソースの説明に、「要素が鍵の型なら、包みも鍵の型になり、保存した欄の順に比べる」と一文を足す（順序を確かめてから書く）。
  - 鍵にしたくないなら、等値の規則とは別の項目にする。

## 確かめた内容（指摘なし）

### 中1（値の `record` の後の改行）

- 直しの形:
  - `newline.rs` の `continues_after` から `KwRecord` を外し、G1 で足した「次が大文字識別子か」の条件を消した。
  - `parse_record_decl` は、`record` の直後で `skip_newlines` を呼ぶ。宣言の位置は `decls.rs` の `parse_item` が `KwRecord` で振り分けるので、値の `record` には効かない。
  - G1 より前の版は、`record` の後の改行を常に消していた（`git diff 498943fe e9de51fc` で確かめた）。宣言の受理の範囲は、その版と同じになった。
- 実行した結果:
  - RV4 の `rec1.bnt` から、23:3 の E0201 は消えた。残るのは、入力に元からある名前の隠しの E0338 の 2 件だけである。
  - `rec_value.bnt`（`bind y <- record` の次の行が `Console.writeLine(…)`）は、`run` で 3 と 4 を出した。
  - `rec_decl.bnt` は受理され、`run` で 15 を出した。中身は次の宣言である。
    - `record` の後で改行してから型名を書く形
    - `public record` の後で改行し、型名を字下げした形
    - 文書コメント・`@opaque`・`public record` の後で改行する形
    - `public` と `record` と型名を別々の行に書く形
    - `record` の行末のコメント・空行・コメントだけの行を挟んでから型名を書く形
    - 一行の `public record Single`
- 回帰がないこと:
  - ほかの行末のキーワードの扱いは、`continues_after` から `KwRecord` を除いただけで変わっていない。`end record` の判定（`is_keyword`）も同じである。`cargo test --lib syntax::` の 115 件は成功した。
  - 名前のない `public record` の後に次の宣言がある入力では、E0216 などが続けて出る。これは G1 より前の版と同じ振る舞いである（rec_missing_name.bnt）。
  - formatter は `record` の後で改行した宣言の型名を一段下げて出し、二度目の `fmt --check` は変更なしだった。字下げは AST の範囲で決まるので、改行の字句の変化には依らない（コードを読んだ範囲。古い版では実行していない）。
- テスト:
  - `record_values_preserve_statement_boundaries` は、`bind` と `return` の二つで、文が二つになることと AST の形を確かめる。G1 のコードでは E0201 で失敗する入力である。
  - `record_declarations_allow_newlines_before_the_type_name` は、`skip_newlines` を消せば失敗する。

### 軽1（W0501 の `Log.Log`）

- RV4 の `log2.bnt` では、W0501 の help が "write `uses Log`"、差分が `uses Log` になった。
- 条件はモジュールの最後の段と名前が同じ組み込みのエフェクトであり、表（`types/builtin.rs`）で当たるのは Log だけである。利用者のエフェクトの経路は変わらない。
- テストは、help の文・編集の範囲（`IO.All`）・置換（`Log`）を固定する。

### 軽2（`record` の欄名）

- 構築・更新・後続の欄・パターンの四つは、E0201 "expected a record field, found `record`" の 1 件になる（単体テストで確認）。
- 01-01 の追記と R198 の判断は一致する。宣言の欄の診断の質は、上の軽3。

### 軽3（E0467 の後の型検査）

- RV4 の here3 は E0467 4 件・E0402・E0451・E0402 を、here5 は E0467・E0401 を一度に出した。
- `run`・`test`・`check --report=json` は、どれも E0467 で止まった。`run` は副作用の前で止まり、"must not run" を出さなかった。`test` は "1 files not run" だった（here_run.bnt）。
- 事前展開が出す診断は E0467 だけで、どれも式を置き換える。置き換えない直接呼び出しの誤りは、型検査の個数・ラベルの診断に回る（02-04 のとおり）。
- 外部の照合と CheckedProgram の生成は、誤りがあれば行わない（`pipeline.rs` の 344・357 行）。02-01 の追記と一致する。
- here_chain.bnt（ラムダの戻り値・括弧の中・パイプの左辺の here と、`f()`・`show(f)` などの使用）では、出た診断は次の三種類だった。
  - E0467 の 4 件
  - 入力そのものの誤り（List.map のラベル）の E0451
  - 軽2 の 3 の E0401
- 同じ入力の `f()` や `show(f)` からは、連鎖した誤りは出なかった。

### 軽4（不透明な包みの `=` と表示）

- 03-06・標準ソースの説明・生成した Skill の参照の三つが、同じ内容（比べる欄の名前と順序、Assert の表示、アクセサは使えない、Show は実装しない）を書いている。
- CheckedIndex の欄の順序（values・index・element）は、実際の表示と一致した。
- golden の 10 個の等値は、それぞれ一つの欄だけを変えている。length は values と連動するので、values の違いで確かめている。

### 軽5（README のリンク）

- `tools/source-migrate/README.md` は文字の参照になった。
- `git grep` で docs/design・docs/reference・tools・scripts・crates・AGENTS.md・README.md を探し、改造のディレクトリへの参照はなかった。

### 規約

- 新しい本番のコードに、unwrap・添字・panic・unsafe・作業 ID・R 番号の引用はない。
- テストの失敗は panic と assert で表しており、既存の許可の範囲である。
- 既存の assert の削除・期待値の緩和・ignore の追加は見つからなかった。
- 細かい点（指摘にしない）:
  - 02-04 の新しい【決定】には「理由:」がない。ただし、同じ節のほかの【決定】も同じ書き方である。
  - `pipeline.rs` の `mod tests {` の直後に空行が一行増えた。
