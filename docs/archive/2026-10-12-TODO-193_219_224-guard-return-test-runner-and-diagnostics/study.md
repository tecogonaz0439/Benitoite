# 調査

項目ごとの調査を Opus 三つに任せた結果を、部として並べたものである（2026-10-12、san_benito の bf85fddc の時点。リポジトリを変えず、小さな入力で今の診断と出力を確かめた）。部の中の推奨と `decisions.md` が違うときは、`decisions.md` を正とする。部は、A（TODO-193）、B（TODO-219）、C（TODO-224）である。再現に使った入力（scratchpad の `orch9/`）は保管しない。

## 調査 A: TODO-193 の調査: ガードの中のプレースホルダの引数の `return`

調べた版: `san_benito` の `bf85fddc`。実行ファイルは `target/debug/benitoite`（2026-10-12 20:03 のビルド。最後のコミットより後）。再現の入力は `orch9/a/`（Benitoite は `01`〜`09` の `.bnt`、他の言語は `orch9/a/other/`）。行番号は、断りがなければ `crates/benitoite/src/` からの相対で示す。

結論を先に書く。TODO の前提（プレースホルダでない引数は展開後のラムダの本体に入り、その中の `return` は展開後のラムダから抜ける）は、今のコード・仕様・実行のどれでも正しい。外で先に評価されることはない。ガードの中で拒否しているのは構文解析器だけで、仕様（01-05・01-02・01-12）と Lean の表層の型付けを組み合わせると、受け付ける側に読める。推奨は「拒否を続け、仕様と E0218 の文言で明示する」（選択肢 B）。

#### 1. 今のコードの事実

##### 今のコードの事実

構文解析器（E0218 を出す箇所）

- `syntax/parser/mod.rs:136-140` の `EscapeContext`（`Allowed`・`InLazy`・`InGuard`）を、`Context` の欄 `escape`（`mod.rs:144`）に持つ。
- ガード: `syntax/parser/patterns_ext.rs:49-61`。`if` を読んだら `p.ctx.escape = EscapeContext::InGuard`（`:53`）とし、ガードの式を読み終えたら文脈を戻す（`:59`）。
- `lazy` の本体: `syntax/parser/effects.rs:396` で `InLazy` にする。
- ラムダ: `syntax/parser/exprs.rs:946-954`。本体を読む前に `p.ctx.escape = EscapeContext::Allowed`（`:954`）とする。だから明示の `lambda … end lambda` の中では `return`・`try` を受け付ける。
- `return`: `syntax/parser/exprs.rs:397-400` の `parse_return` が `effects::check_escape` を呼ぶ。`try` は `effects.rs:427` で同じ関数を呼ぶ。
- `check_escape`: `syntax/parser/effects.rs:475-490`。文脈が `Allowed` でなければ E0218 を報告する。助言は文脈ごとの一つ（`lazy_body` か `guard`）と `lambda` の二つである。
- 引数: `syntax/parser/exprs.rs:481-514`（`parse_args`・`push_arg`）。`_` の直後が `,` か `)` ならプレースホルダとし、そうでなければ普通の式として `parse_expr` で読む。escape の文脈は変えない。したがって、ガードの中の `add(return 100, _)` の `return` は、プレースホルダの `_` を読む前に `InGuard` の文脈で E0218 になる。呼ぶ関数（`(return f)(_)` の `(return f)`）も同じく拒否される。
- 文言: `diag/codes.rs:244-248`。

  ```text
  E0218 "`{keyword}` cannot be used inside {context}"
    guard:  "a guard is a condition; check the value in the branch body instead"
    lambda: "`{keyword}` is allowed inside a lambda written there"
    説明:   "`return` and `try` cannot leave a `lazy` body or a `match` guard, except inside a lambda written there."
  ```

- 単体テスト: `syntax/parser/patterns_ext.rs:443-470`（`n if return 1`・`n if try f()` が E0218）、`syntax/parser/effects.rs:805-830`（`lazy` の中）。ゴールデンテストは `testdata/effects/c11-lazy-return.diag.json` だけで、ガードの中のプレースホルダの形を確かめるテストはない。

プレースホルダの展開（型検査・脱糖）

- 型検査: `typeck/generate.rs:240-259`。プレースホルダを含む呼び出しでは、新しい戻り値の型 `ret` とエフェクトを作り、`ctx.ret`・`ctx.clauses`・`ctx.return_annotation` を差し替え、`return_owner` を `ReturnOwner::Placeholder(span)`（`typeck/context.rs:14-18`）にしてから `call_body` で呼ぶ関数と引数を検査する。つまり、引数の中の `return`・`try` は、展開後のラムダの戻り値の型で検査する。
- 脱糖: `ir/desugar/exprs.rs:325-326` でプレースホルダを含む呼び出しを `placeholder` へ回す。`placeholder`（`:341-388`）は、`return_ty` を展開後のラムダの戻り値の型に替え（`:353`）、閉包の本体の中で `self.prepare(&e.callee, …)`（`:357`）と、プレースホルダでない引数の `self.eval(e, …)`（`:361`）を行い、それを `ValKind::Lambda` の本体（`:378-386`）にする。呼ぶ関数とプレースホルダでない引数は、ラムダの外で先に評価せず、ラムダの本体の中で評価する。
- TODO-192 の `Let` は、プレースホルダの位置の引数（ラムダの引数の変数）を `bind(self, returned(variable(v, …)))` で束縛し直すもの（`:362-367`）であり、プレースホルダでない引数を外へ出すものではない。「外で先に評価され、`return` がガードを評価している関数から戻る」という懸念は当たらない。

仕様

- 01-02「`return`」（`docs/design/01-spec/01-02-syntax.md:204`）: `return e` は「`return` を含む最も内側の関数の宣言かラムダの呼び出し」を終える。
- 01-02「部分適用のプレースホルダ」（同 `:327-340`）。`:338` に「展開後のラムダの本体には、呼び出される関数 `f` と、プレースホルダでない引数の式がそのまま入る。…これらの式の中の `return` と `try` は展開後のラムダから抜け、その戻り値の型で検査する」とある。
- 01-08（`01-08-evaluation.md:72`）: プレースホルダを含む呼び出しはラムダを作るだけで、呼ぶ関数とプレースホルダでない引数は、ラムダを呼ぶたびに評価する。
- 01-05「パターンの拡張」（`01-05-data-types.md:189`）: 「ガードの中には、内側のラムダの中を除き、`return` と `try` を書けない」。
- 01-12（`01-12-core-calculus.md:711`）: ガードは R を持たない判断で検査する。だから「内側のラムダの中を除き」書けない。`:448`: プレースホルダの呼ぶ関数と引数は、R を展開後のラムダの戻り値の型として検査する。`:340`: 展開後のラムダの本体で、呼ぶ関数と引数を評価する。
- 01-06（`01-06-type-system.md:496`）の `resume` の規則は、プレースホルダの呼ぶ関数と引数を「ラムダの本体の中と同じ」と明記している。`return`・`try` には、ガードと `lazy` についてこれに当たる明記がない。
- 利用者向けのリファレンス（`docs/reference/benitoite.md:267`）は、`Integer.maximum(_, 0)` を「`lambda(x) return Integer.maximum(x, 0) end lambda` である」と説明している。

仕様の文を組み合わせると、「ガードの中のプレースホルダの引数はラムダの中」と読める。したがって、今の構文解析器は 01-05 の文面より狭い。これは処理系と仕様の食い違いにあたり、どちらの選択肢を採っても、仕様か処理系のどちらかを直す必要がある。

Lean の表層

- `formal/Benitoite/Surface/Typing.lean:186-191` の `E_PartialCall` と `:193-198` の `E_PartialCon` は、呼ぶ関数とプレースホルダでない引数を `(hideConts Γ) (some r)`、つまり R を展開後の戻り値の型にして検査する。
- ガードは `:368-373` の `guarded` で、R を `none` にして検査する。
- 検査の関数も同じ形である: `formal/Benitoite/Surface/Check.lean:270-277`（`partialCall` は `some r`）、`:526-535`（ガードは `none`）。
- 例: `CheckExamples.lean:242-256`。非穴の引数の `returnE` は、外側の R ではなく展開後の戻り値の型で検査する。
- 以上から、Lean の型付けは、ガードの中の `add(return 100, _)(n) > 50` に型を付ける（R が `none` の中で `partialCall` が R を `some r` に戻すため）。Lean には構文解析器の escape の文脈がないので、処理系のほうが狭い。差分テストは処理系が受け付けた入力だけを比べるので、この食い違いは見つからない（TODO の記述のとおり）。

##### 今の出力

`target/debug/benitoite run` で実行した結果を示す（入力は `orch9/a/`）。

| 入力 | 内容 | 結果 |
|---|---|---|
| `01-body-placeholder.bnt` | 関数 `f` の本体で `bind g <- add(return 100, _)`、`g(x)` に 1000 を足す。`h` は `g` を作るだけで呼ばない | `1100` と `5`。`return 100` は展開後のラムダから抜け、`g(5)` が 100 になる。`f` からは抜けない。`g` を呼ばなければ評価されない |
| `02-lambda-return.bnt` | 本体で `lambda(n) -> Integer return 100 end lambda` | `1100`。ラムダの中の `return` はラムダから抜ける |
| `03-guard-placeholder.bnt` | `case n if add(return 100, _)(n) > 50 -> "big"` | E0218「`return` cannot be used inside a match guard」。助言は「a guard is a condition; …」と「`return` is allowed inside a lambda written there」 |
| `04-guard-lambda.bnt` | ガードの中で `(lambda(m) -> Integer return 100 end lambda)(n) > 50` | `big`。受け付ける |
| `05-guard-plain.bnt` | `case n if (return "early") ->` | E0218 |
| `06-lazy-placeholder.bnt` | `lazy add(return 100, _) end lazy` | E0218（`lazy` の本体）。ガードと同じ扱いである |
| `07-guard-placeholder-try.bnt` | ガードの中のプレースホルダの引数で `try` | E0218（`try`） |
| `08-body-placeholder-try.bnt` | `Option` を返す関数の本体で `bind g <- add(try o, _)` | E0441「`try` on `Option[Integer]` needs the function to return Option」と「this call with `_` makes a function」「the function made by `_` in this call returns `Integer`」。囲む関数から抜けるつもりで書いた `try` は、型検査で捕まる |
| `09-guard-placeholder-noreturn.bnt` | ガードの中で `add(100, _)(n) > 50` | `big`。プレースホルダそのものはガードの中で使える |

E0218 の 2 番目の助言「`return` is allowed inside a lambda written there」は、プレースホルダの呼び出しをラムダと説明するリファレンス（`benitoite.md:267`）と並べると、`add(return 100, _)` が許されると読める。今の文言は、拒否した理由を読み手に示せていない。

#### 2. 他の言語

##### 他の言語

| 言語 | (a) ガードの中の `return` | (b) ガードの中のラムダ・プレースホルダの中の `return` | プレースホルダの糖衣 |
|---|---|---|---|
| Rust | 許す。`return` は型 `!` の式で、ガードは任意の式（範囲・代入・`||` などを文法で除く）。`n if n < 0 && return "early"` は囲む関数から抜けた（手元で確かめた）。`?` も同じで、`n if o? > n` は `None` を返して関数から抜けた | クロージャの中の `return` はクロージャから抜ける（手元の `rustc 1.98.1` で `big(closure)`） | なし |
| Scala | 文法は `Guard ::= 'if' PostfixExpr`、`return` は `Expr1` なので、括弧なしでは書けない。括弧で囲めば `SimpleExpr` として書ける（文法からの推論。コンパイラで確かめていない） | 無名関数の中の `return` は、囲むメソッドから抜ける非局所の return（`NonLocalReturnControl` の例外で実装する）。Scala 3.2 から非推奨 | あり。`_` を含む式を、`_` を新しい識別子に置き換えた無名関数に展開する。`f(return 1, _)` は `x => f(return 1, x)` になり、`return` は**囲むメソッド**から抜ける（規則からの推論。コンパイラで確かめていない）。ガードの中の `_` がどの式に束縛されるかも確かめていない |
| Kotlin | ガードは 2.1 で preview、2.2 で stable。KEEP の文法は `whenEntryGuard: 'if' {NL} expression` で、式の種類を制限しない。`return` は型 `Nothing` の式なので書けると考えられるが、コンパイラで確かめていない | ラベルのない `return` は、`fun` で宣言した関数から抜ける。ラムダの中のラベルのない `return` は、inline の関数に渡したラムダの中でだけ許す（非局所の return）。そのほかは誤りとし、`return@label` を使う。無名関数（`fun(…)`）の中の `return` は無名関数から抜ける | なし（`it` と関数の参照） |
| Swift | 書けない。`return` は文（制御を移す文）で、`where` の後は式なので、`n > 0 && (return "x")` は構文の誤りになった（手元の Swift 6.4） | クロージャの中の `return` はクロージャから抜ける（手元で `big(closure)`） | なし（`$0` は波括弧のクロージャの中だけ） |

まとめ:

- ガードの中の素の `return` は、言語によって扱いが分かれる。Rust と Kotlin（推定）は式として許し、Swift は書けない。Scala は括弧が要る。Benitoite の拒否は Swift の側に入る。
- ラムダの中の `return` が何を指すかも分かれる。Rust・Swift・Kotlin の無名関数・Benitoite はラムダ自身から抜ける。Scala と Kotlin のラムダ（inline のとき）は囲む関数から抜ける。
- 比べた中で、`_` のプレースホルダの糖衣を持つのは Scala だけである。Scala では、プレースホルダの引数の中の `return` は**囲むメソッド**から抜ける。Benitoite の意味（展開後のラムダから抜ける）とは逆で、その Scala でも非推奨になった形である。プレースホルダの引数の `return` を、ラムダから抜ける意味で積極的に許す前例は見つからなかった。
- Haskell・OCaml・Elm・F# には `return` の制御の移動がないので、比べる対象から外した。

出典:

- Rust match: https://doc.rust-lang.org/reference/expressions/match-expr.html （`MatchArmGuard → if MatchConditions`、除く式の一覧）
- Rust return: https://doc.rust-lang.org/reference/expressions/return-expr.html （「current function call」の枠を終える。クロージャへの言及はないので、手元で確かめた）
- Scala 2.13 仕様 6 章（Return Expressions、Placeholder Syntax for Anonymous Functions）: https://scala-lang.org/files/archive/spec/2.13/06-expressions.html
- Scala 2.13 仕様 8 章（`CaseClause ::= 'case' Pattern [Guard] '=>' Block`）: https://scala-lang.org/files/archive/spec/2.13/08-pattern-matching.html
- Scala 3 の文法（`Guard ::= 'if' PostfixExpr`、`Expr1` の `'return' [Expr]`）: https://docs.scala-lang.org/scala3/reference/syntax.html
- Scala 3 の非局所の return の非推奨（3.2.0 から）: https://docs.scala-lang.org/scala3/reference/dropped-features/nonlocal-returns.html
- Kotlin のガード: https://kotlinlang.org/docs/control-flow.html 、KEEP: https://github.com/Kotlin/KEEP/blob/master/proposals/guards.md 、2.2 で stable: https://kotlinlang.org/docs/whatsnew22.html
- Kotlin のラムダの return: https://kotlinlang.org/docs/lambdas.html 、https://kotlinlang.org/docs/inline-functions.html
- Swift の文: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/ （取得したページの本文が空で、文言を確かめられなかった。代わりに手元の `swiftc`（Apple Swift 6.4）で確かめた）

確かめられなかった点: Scala と Kotlin はコンパイラが手元になく、動かして確かめていない。Scala でガードの中の `f(return 1, _)` の `_` がどの式に束縛されるかは、仕様の文からは読み切れなかった。Swift の公式文書の文言も取得できなかった。

#### 3. 選択肢と推奨

##### 選択肢と推奨

選択肢 A: 受け付ける（ガードと `lazy` の中でも、プレースホルダを含む呼び出しの呼ぶ関数と引数を、ラムダの中と同じに扱う）

- 構文解析器: 引数を読む前には、プレースホルダの有無が分からない。直し方は二つある。一つは、`(` から対応する `)` までの字句を先読みし、深さ 1 に `_`（前が `(` か `,`、後が `,` か `)`）があれば、引数を読む間 escape を `Allowed` にする方法。もう一つは、引数の中の E0218 を保留しておき、`)` の後にプレースホルダがあれば捨てる方法。呼ぶ関数（`(return f)(_)`）は引数より先に読むので、仕様の文面どおり（呼ぶ関数も展開後のラムダに入る）にするなら、呼ぶ関数の前から先読みが要る。`exprs.rs` に 20〜40 行と単体テスト。`clause` の文脈（`resume`）は型検査が `placeholder_boundary` で扱っているので、変えなくてよい。
- 型検査・脱糖・VM: 変更は要らないと見込む（`generate.rs:240-259` と `desugar/exprs.rs:341-388` が R を差し替える）。ただし、ガードの中で通した例はまだないので、ゴールデンテストで確かめる必要がある。
- Lean: 変更なし。今の Lean の型付けと一致する。
- 仕様: 01-05:189 と 01-12:711 の「内側のラムダ」に「プレースホルダを含む呼び出しの呼ぶ関数と引数を含む」と添える。`lazy` の節（01-02 の「`return`」の箇条）も同じ。
- テスト: 単体テストを 2〜3 件と、受け付けて実行するゴールデンテスト（ガードと `lazy`）。
- 規模: 小〜中（構文解析器の先読みと、仕様の 3 か所）。
- 長所: 仕様の組み立て（プレースホルダは展開後のラムダ）と Lean にそのまま合う。例外の規則が一つ減る（原則 5）。
- 短所: 受け付けても、意味のある使い道がほとんどない。`add(return 100, _)` は呼び出しを捨てて定数を返す関数を作るだけである。一方、`return`・`try` を書いた人（LLM を含む）は、囲む関数から抜けるつもりで書いた見込みが高い。Scala はこの形を囲むメソッドからの return とする。受け付けると、ガードを使う関数から抜けると誤読されたコードが、型が偶然合えば黙って通る（`01` の出力 `1100` の形）。原則 1（静的に検出できる誤りを実行前に報告する）と原則 3（利用者が結果を理解できる）に反する向きである。構文解析器の先読みは、ガードと `lazy` の中だけの特別な経路になる。

選択肢 B: 拒否を続け、仕様と診断で明示する（推奨）

- 構文解析器・型検査・Lean: 動作は変えない。
- 仕様:
  - 01-05:189 を「ガードの中には、内側の `lambda … end lambda` の本体の中を除き、`return` と `try` を書けない。プレースホルダを含む呼び出しの呼ぶ関数と引数の中にも書けない」とし、理由を 1〜2 文添える（例: プレースホルダの引数の `return`・`try` は展開後のラムダから抜けるが、書いた人は囲む関数から抜けるつもりで書きやすく、ガードの中で意味のある使い道がないため）。
  - 01-02:338 の箇条に「ガードと `lazy` の本体の中に書いたプレースホルダの呼び出しでは、これらの式の中に `return` と `try` を書けない（01-05）」を加える。01-02「`return`」の `lazy` の箇条（`:209`）も「内側の `lambda` の中を除き」と揃える。
  - 01-12:711 の「内側のラムダの中を除き」に、構文の制限としてプレースホルダの引数を除くことを書く。Lean の型付けはこれより広いので、07-04「01-12 との対応」の表（段階 C1・C2・C7 の行か段階 E2 の行）に「ガードと `lazy` の中のプレースホルダの引数の `return`・`try` には形式化の型付けが型を付けるが、構文で拒否する（形式化のほうが広い）」と書き足す。この扱いは、表がすでに「01-06 より広い」と記している箇所と同じ種類である。
- 診断（E0218）: 文言を改める必要がある。今の助言「`{keyword}` is allowed inside a lambda written there」は、プレースホルダの呼び出しをラムダと説明するリファレンスと並べると、LLM に「`_` の呼び出しなら書ける」と読ませる。案は次の二つ。
  - 最小: `codes.rs:247` の助言を「`{keyword}` is allowed inside a `lambda ... end lambda` written there」とし、説明の文（`:248`）に「Arguments of a call with `_` placeholders are not exempt.」を加える。構文解析器は変えない。`gen_skill` で `skill/references/diagnostics.md` を作り直し、単体テスト（`patterns_ext.rs:461-470`、`effects.rs:818-823` は "inside a lambda" を含むかを見ている）がそのまま通るかを確かめる。
  - 丁寧: 呼び出しの引数の中で E0218 を出したときに、その呼び出しがプレースホルダを含むかを `)` の後で調べ、含めば助言を `placeholder`（例: "arguments of a call with `_` are part of the guard; compute the value before `match` with `bind`, or write the function with `lambda ... end lambda`"）に替える。選択肢 A と同じ保留の仕組みが要るので、規模は A に近い。この形は稀なので、最小の案で足りると考える。
- テスト: `patterns_ext.rs:443` のテストに `n if f(return 1, _)(n)` と `n if f(try g(), _)(n)` の行を加え、E0218 を確かめる。`effects.rs:805` に `lazy f(return 1, _) end lazy` を加える。今の動作を固定するテストであり、仕様の文に対応させて `// spec: 01-05 …` の印を付ける（test-audit の作成時の関門の範囲）。
- 規模: 小（仕様 3〜4 か所、07-04 の表 1 か所、文言 1〜2 行、単体テスト 3 行、生成物の作り直し）。
- 長所: 処理系の動作を変えない。ガードと `lazy` の規則を「明示の `lambda` の中だけ」と一言で言える。誤読しやすい形を実行前に止める（原則 1・3）。設計者の見込みと一致し、Swift（ガードに `return` を書けない）と同じ側に立つ。プレースホルダの引数の `return` をラムダから抜ける意味で許す前例は、比べた言語に見つからなかった。
- 短所: 「プレースホルダは展開後のラムダ」という説明に例外が一つ増える（原則 5 にやや反する）。`resume` の規則（01-06:496）は、プレースホルダの引数を「ラムダの本体の中と同じ」と扱うので、`return`・`try` とは向きが違う。ただし `resume` は「書けない側」を広げる規則なので、どちらも安全側に倒すという点では揃っている。Lean より狭いことを 07-04 に記す手間がある。

選択肢 C: プレースホルダの引数の `return`・`try` を、場所によらず一律に拒否する

- `01` のように、関数の本体の中で書いた `add(return 100, _)` も誤りにする。誤読の危険はガードの中と同じなので、規則は最も単純になる（「プレースホルダの引数の中には `return`・`try` を書けない」）。
- 変更: 構文解析器で、プレースホルダを含む呼び出しの呼ぶ関数と引数に新しい文脈を置く（A と同じ先読みか保留の仕組み）。仕様 01-02:338 の「`return` と `try` は展開後のラムダから抜け」を書き換える。型検査の `ReturnOwner::Placeholder` と E0441・E0442 の `declared_placeholder`・`placeholder_call`（`codes.rs:712-720`）は使われなくなるので、整理が要る。Lean は表層の型付けで `partialCall`・`partialCon` の R を `none` にし、性質 1 と検査の関数の健全性の証明を直す（07-04 の決まりにより処理系より先）。新しい診断の番号か E0218 の文脈を一つ加える。
- 規模: 中〜大（Lean の定義と証明、型検査の整理、診断）。今は使い道のない形を止めるだけの効果に比べて、規模が大きい。TODO-193 の範囲を超えるので、するなら別の項目にする。

推奨: 選択肢 B（拒否を続け、仕様と E0218 の文言で明示する。文言は最小の案）

理由:

1. 拒否は原則 1・3 に合う。この形には使い道がない。囲む関数から抜けるという誤読（Scala の意味）を実行前に止められる。
2. 今の処理系の動作を変えずに、仕様・Lean・処理系の食い違いを文書の上で解消できる。規模も最も小さい。
3. 原則 5 の観点では A がやや有利だが、原則の番号は 1・3 のほうが小さい。

C は筋が通るが、Lean の証明の手直しを伴うので、`try`・`return` の使い方の測定（LLM がこの形を書くか）を見てから、別の項目で検討するのがよい。`lazy` の本体の中の同じ形（`06`）も、同じ改造で同じ扱いにする。

## 調査 B: TODO-219 の調査（`benitoite test` の並行の実行と、`Assert` の報告の `<constructor #タグ>`）

調べた時点: 2026-10-12、ブランチ `san_benito`（`bf85fddc`）。リポジトリのファイルは変えていない。所要時間を測るために `cargo build --release -p benitoite --bin benitoite`（25 秒）で `target/release/benitoite` を作った（ビルドの生成物だけ）。行番号は `crates/benitoite/src/` からの相対で示す。再現の入力は `orch9/b/` に置いた。

- `orch9/b/ctor.bnt`、`orch9/b/ctor_nontail.bnt`: `<constructor #タグ>` の再現
- `orch9/b/small/`（5 テストのファイル 10 個）、`orch9/b/many.bnt`（200 テスト）、`orch9/b/sleepy/s.bnt`（`Clock.sleep(200)` のテスト 8 個）: 所要時間の測定
- `orch9/b/layout.rs`: 対象の頭と値の大きさの模型

---

#### 1. `benitoite test` の並行の実行

##### 今のコードの事実

- 実行器は `cli/tools/test_runner/mod.rs`。`run_test_command`（110 行）がパスからファイルの並び（`test_entries`、173 行）を作り、`for entry in &entries`（154 行）でファイルを一つずつ `Runner::run_file`（326 行）に渡す。モジュールの先頭の `//!`（1〜2 行）にも「テストは一つずつ別の実行として順に動かす」とある。
- `run_file` は、検査とコード生成を `pipeline::on_large_stack`（64 MiB のスタックのスレッド。`pipeline.rs:17`・`pipeline.rs:237`）で行い（`prepare`、553 行）、`for test in compiled.tests`（408 行）でテストを一つずつ `run::run_test`（`runtime/run.rs:1028`）に渡す。VM はコマンドを動かしたスレッド（主スレッド）で動く。結果は一件ごとに `write_result`（490 行）で標準出力へ書き、文章の形の失敗の詳細は `failures` に溜めて `finish`（516 行）で最後に書く。
- 実行ごとの状態: `run_entry`（`runtime/run.rs:205` 付近）が実行ごとに、隠れた乱数の種（`getrandom`）、イベントループ（`wakeup_with_poll`）、出力の書き出し用のスレッド 2 本（`io/output.rs:83`）、作業用のスレッドの組（`RuntimeParts::real`、`runtime/sched/parts.rs:87`。上限 `MAX_WORKERS = 64`、150 行）、VM とヒープ（`HeapCore::new`、`runtime/heap/core.rs`）を作る。テストの標準出力・標準エラー出力は `OutputTarget::Capture(Arc<Mutex<Vec<u8>>>)`（`runtime/run.rs:29`）でテストごとに捕らえ、プロセスの標準出力には触れない。
- 共有するもの: `CompiledProgram` は `Send + Sync` をコンパイルの時点で確かめている（`bytecode/program.rs:376` の `assert_shareable`）。02-01「コンパイル済みプログラムと実行ごとの状態」は「複数の実行と複数のスレッドが、同じコンパイル済みプログラムを同時に読んでよい」と定める。`AssertTable` は `Arc` で共有している（`test_runner/mod.rs:420` 付近）。
- 処理系の大域の状態（AGENTS.md「大域の状態」）を `grep` で確かめた。`thread_local!` は panic の記録（`runtime/panic.rs:26`。スレッドごとなので並行で混ざらない）、原子的な計数器はヒープの番号（`runtime/heap/core.rs:58`。複数のヒープを前提にした作り）だけで、ほかはテストのビルドの計数器（`cli/mod.rs:800`）である。処理系は作業ディレクトリと環境変数を書き換えない（`set_current_dir`・`set_var`・`remove_var` は本番のコードにない）。
- 中断: `SharedInterrupt(Rc<Box<dyn InterruptSource>>)`（`test_runner/mod.rs:261`）で一つの読み口をテストごとの `RunEnv` に配る。`Rc` で、`InterruptSource` のトレイト（`runtime/io/services.rs:22`）は `Send`・`Sync` を求めていないので、今の形のままではスレッドへ渡せない。読み口の中身はプロセスで一つの `Arc<AtomicBool>`（`runtime/run/interrupt.rs`）であり、実行ごとの `attach` は `signal_hook_mio::Signals` を実行ごとに作ってイベントループに登録する（`runtime/io/event.rs:49-67`）。
- 設計書:
  - 06-04「テストの実行」: 「テストは、ほかのテストの実行の順序と、実行したかどうかに依存してはならない。処理系は、テストを並行に動かしてよい。」
  - 06-04「結果の報告」: 「テストを並行に動かしても、報告は、ファイルを指定した順（ディレクトリの下ではパスの辞書順）と、ファイルの中のテストの関数の宣言の順に書く。」
  - 02-11「テストの実行」: 【決定】「テストは、一つずつ別の実行として動かす。」に加え、【方針】「テストの実行器は、テストを一つずつ順に実行する。」とある。06-04 の「並行に動かしてよい」と 02-11 の「一つずつ順に実行する」は、規範（06-04）と実装の記述（02-11）の差として読めるが、どちらにするかを決めたら揃える必要がある。
  - 02-11 は、処理系の不具合が起きたら「ほかのテストを続けず」に終了状態 3 で終えること、中断の要求では「残りのテストを実行せずに、それまでの結果を報告」することを定める。

##### 今の出力（所要時間）

10 論理 CPU の Mac で、3 回ずつ測った（`/usr/bin/time -p` の real）。

| 入力 | デバッグのビルド | リリースのビルド |
|---|---|---|
| 5 テストのファイル 1 個（`small/t00.bnt`） | 0.06 秒 | 0.01 秒 |
| 5 テストのファイル 10 個（`small/`、50 テスト） | 0.33〜0.60 秒 | 0.04〜0.05 秒 |
| 200 テストのファイル 1 個（`many.bnt`） | 0.13 秒 | 0.02 秒 |
| `Clock.sleep(200)` のテスト 8 個（`sleepy/s.bnt`） | 1.70 秒 | 1.62〜1.64 秒 |

- リリースのビルドで、ファイル一つの検査とコード生成は約 4 ミリ秒、純粋なテスト一つの実行（イベントループと出力のスレッドの用意を含む）は約 0.1 ミリ秒である。純粋な計算のテストは、並行にしても短くなる余地がほとんどない。
- 待つテスト（`Clock.sleep`、ネットワーク、外部のコマンド）と重い計算のテストだけ、並行で短くなる。`sleepy/s.bnt` はテストの単位で並行にすれば約 0.2 秒になる見込み（測っていない。待ちの合計 1.6 秒がテストの数で割れる計算）。ファイルの単位の並行では、同じファイルの中のテストは短くならない。

##### 並行にするときの障害と要る変更

| 点 | 今 | 並行にするときに要るもの |
|---|---|---|
| ヒープ | 実行ごと（`Heap::new`）。番号は原子的な計数器 | 変更なし。ただし上限のない実行ごとのヒープが同時に N 個生きるので、最大 RSS は最大で N 倍になる |
| IO 実行器 | 実行ごとにイベントループ・出力のスレッド 2 本・作業用のスレッド（最大 64） | 変更なし。スレッドの数は並行の度合いに比例して増える（最悪 N×66）。プロセスのファイル記述子の上限を並行の実行が分け合う |
| VM のスレッド | 主スレッドで動く | 作業用のスレッドで動かす。VM は Rust の再帰をしない（AGENTS.md「再帰の深さ」）が、主スレッドより小さい既定のスタックで足りるかを `examples/stack_probe.rs` などで確かめる |
| 中断の印 | `Rc` で共有。読み口は一つの `AtomicBool` | `Arc` にし、`InterruptSource` に `Send + Sync` を足す（トレイトの境界の変更）。実行ごとの `signal_hook_mio::Signals` の登録が同時に複数あってよいかは signal-hook の文書で確かめる（今は未確認） |
| 処理系の不具合・中断 | ループを抜ける | 走っている他の実行を止める仕組み（実行器の内側の取り消しの印）が要る。中断の報告で「それまでの結果」を、報告の順の連続した先頭までに限るなどの決まりが要る |
| 出力の取り込み | テストごとに `Capture` | 変更なし（プロセスの標準出力を使っていない） |
| 報告の順序 | 一件ごとに書く | 結果を（ファイル番号, 宣言の順）で受け取り、順が来たものから書く並べ直しの緩衝が要る。06-04 の規則はそのまま守れる |
| 時計・乱数 | 実行ごとの部品・実行ごとの種 | 変更なし |
| 環境変数・作業ディレクトリ | 処理系は書き換えない。テストの中から変える関数もない | 処理系の中は問題なし |
| 一時ファイル・ポート・外部の状態 | 順に動くので衝突しない | 利用者のテストが同じパスやポートを使うと、並行では結果が実行ごとに変わる。06-04 はそうしたテストを禁じているが、実行器は検出できない |
| 大域の状態の規約 | 例外は 4 つ | 新しい大域の状態は要らない（並べ直しも取り消しの印も実行器の局所の状態で書ける） |
| 選択 | なし（`PathArgs` に並行の欄はない。`cli/tools/args.rs:17`） | `--jobs N` のような選択を足すなら、06-01「`test` のコマンドライン」と同梱の Skill の文書を直す |

単位の比較:

- ファイルの単位: 検査とコード生成も並行になる。ファイルの中は今のまま順なので、ファイルの中の外部の状態の衝突は増えない。待つテストが一つのファイルに集まっていると短くならない。
- テストの単位: 待つテストが同じファイルにあっても短くなる。`CompiledProgram` と `AssertTable` を `Arc` で共有する形が要る（どちらも共有できる型）。同じファイルのテストが同じ一時ファイルを使う書き方（LLM が書きやすい）が壊れやすい。

ほかの処理系の既定（一次資料で確かめた分）:

- Rust のテストの実行器: 「By default, uses the amount of concurrency available on the hardware as indicated by `available_parallelism`」（`--test-threads`）。並行のときは実行の順が決まらないとも書く。https://doc.rust-lang.org/rustc/tests/index.html 。`cargo test` は一つのテストの実行ファイルの中のテストを複数のスレッドで動かし、テストの実行ファイルどうしは順に動かす。https://doc.rust-lang.org/cargo/commands/cargo-test.html
- Go: `go test` はパッケージの単位で `-p`（既定は GOMAXPROCS）まで並行に動かす。一つのテストの実行ファイルの中では、`t.Parallel` を呼んだテストだけを `-parallel`（既定は GOMAXPROCS）まで並行にする（既定は順）。https://pkg.go.dev/cmd/go
- pytest: 既定は一つずつ順（pytest-xdist の `--dist no` を「runs one test at a time」と説明）。並行は pytest-xdist の `-n` を指定したときだけで、`-n auto` は物理コアの数。`--dist loadfile` はファイルの単位で同じ作業者に送る。https://pytest-xdist.readthedocs.io/en/stable/distribution.html

##### 選択肢と推奨

| 案 | 変更の規模 | 危険 | 利点 |
|---|---|---|---|
| A. ファイルの単位で並行、既定は `available_parallelism`、`--jobs N` | 中（実行器の並べ直し・取り消し、`InterruptSource` の境界、VM を作業用のスレッドで動かす、06-01・06-04・02-11・Skill の文書） | 外部の状態を共有するファイルどうしの結果が実行ごとに変わる。メモリとスレッドの数が N 倍 | ファイルが多く、待つテストがファイルに散らばっているときだけ短くなる。純粋なテストでは 10 ファイルで 0.04 秒が縮む程度 |
| B. テストの単位で並行（既定は同上） | A より少し大（同じファイルの中のプログラムと表の共有、宣言の順の並べ直し） | A に加え、同じファイルのテストの一時ファイルなどの衝突 | 待つテストが一つのファイルにあっても短くなる（`sleepy` の 1.6 秒 → 約 0.2 秒の見込み） |
| C. 順のまま。06-04 の「並行に動かしてよい」と「結果の報告」の「テストを並行に動かしても」を消し、02-11 と揃える | 小（文書だけ） | なし | 結果が実行ごとに変わらない。テストの独立の要求（順序に依存しない）は残す |
| D. 順を既定にし、`--jobs N` を選んだときだけ並行（A か B） | A・B と同じ | 既定では起きない | 待つテストの多い利用者だけが選べる |

推奨: **C**（今は順のまま、06-04 と 02-11 を「順に動かす」で揃える）。理由: 測った限り、純粋なテストではファイル一つ約 4 ミリ秒・テスト一つ約 0.1 ミリ秒で、並行の利点が出るのは待つテストに限られる。一方、利用者は主に LLM にテストを書かせる非プログラマであり、外部の状態を共有するテストが並行で不定に失敗すると、原因を理解しにくい（設計原則 3）。06-04 が「並行に動かしてよい」と書いたまま実装が順であることは、利用者が実行の順を当てにしてよいかを曖昧にしているので、C で文書を実装に合わせる。待つテストの所要時間が問題になったら、D（選んだときだけ並行。単位はテスト）を別の項目として検討する。

---

#### 2. `Assert` の報告の `<constructor #タグ>`

##### 今のコードの事実

- 型の出どころ: `AssertTable::build`（`runtime/assert.rs:75-114`）が、利用者のモジュールの AST を辿り（`Collector`、331 行以降）、`Assert.equal`・`Assert.notEqual` を名前で呼ぶ式ごとに、型検査が名前のノードに記録した最初の型引数（`checked.types.type_args`、`compared_type`、370-387 行）を「呼び出しの式の span → 比べる値の型」の表 `value_types` に入れる。パイプの形は式全体の span も鍵にする（432-441 行）。実行時に型を渡しているのではなく、呼び出しの位置の静的な型を表で引く。
- 書き出し: VM は `assert_check`（`vm/dispatch/handlers.rs:81-130`）で操作の命令の由来位置 `site` を求め、`assert::evaluate`（`runtime/assert.rs:125`）に渡す。`evaluate` は `value_types` から型を引き（140 行）、`render_value`（164 行）で書く。
- `render_value` は、型が `None` か、型パラメータを含む（`has_params`、498-504 行。`Ty::Param`・`Ty::App`・`Ty::Rigid` を一つでも含む）ときは、値全体を形だけから書く（170-173 行）。`Option[T]` のように外側が分かる型でも、全体が形だけになる。
- 形だけの書き出しで、引数のない構成子（`Value::Tag`）は `render_shape`（695 行）、引数のある構成子・レコード（`FieldsKind::Ctor` の対象）は `render_object`（747-755 行）が `text::UNKNOWN_CONSTRUCTOR`（`"<constructor #{tag}>"`、300 行）にする。値が持つのは型の宣言の中のタグ（0 から数える）だけで、型を示す情報を持たない（`runtime/heap/value.rs:24` の `CtorTag`、`ObjHeader` の `tag`）。
- 型パラメータを持つ補助の関数（`function checkSame[T: equality](actual: T, expected: T)`）の中の `Assert.equal(actual, expected)` は、型が `T` なので必ずこの形になる。`T: equality` は組み込みの制約（`types/mod.rs:151`）で、辞書を渡さないので、実行時に型の情報は届かない。
- 枠: 失敗のときに VM は `state.stop_info` で呼び出しの枠（`FrameRecord { proto, call_site }`、`vm/mod.rs:70-75`）を集めて `CheckFailure` に入れる（`vm/dispatch/handlers.rs:117-125`）。ただし書き出し（`evaluate`）はその前に済んでいる。
- 既にある構成子の表: `CompiledProgram::ctors: Vec<CtorInfo>`（`bytecode/program.rs:171-178`・`261`）は、型の名前・構成子の名前・タグ・引数の数を持つ。コード生成が参照した構成子だけを `(型, タグ)` ごとに一つ載せ（`bytecode/codegen/tables.rs:86-110`）、表の大きさは 65,536 未満（`table_limit`、61 行、L0105）。`CON` の命令は `CtorIdx` で表を引くが、作る値には `ctor.tag` だけを入れる（`vm/dispatch.rs:1055-1090`）。

##### 今の出力

`orch9/b/ctor.bnt`（デバッグのビルド。抜粋）:

```text
---- ctor.bnt: "direct" ----
  left:  Color.Red
  right: Color.Blue
---- ctor.bnt: "generic helper with nullary constructor" ----
  left:  <constructor #0>
  right: <constructor #2>
   = note: call trace (innermost first):
             checkSame
---- ctor.bnt: "generic helper with fields" ----
  left:  <constructor #0>(1)
  right: <constructor #1>(2)
---- ctor.bnt: "generic helper with record" ----
  left:  <constructor #0>(1, 2)
  right: <constructor #0>(1, 3)
---- ctor.bnt: "generic helper with option" ----
  left:  <constructor #0>(<constructor #1>)
  right: <constructor #1>
---- ctor.bnt: "generic list helper" ----
  left:  [<constructor #0>]
  right: [<constructor #1>]
---- ctor.bnt: "lambda in forEach" ----
  left:  Color.Red
  right: Color.Green
```

- 型パラメータを持つ補助の関数では、引数のない構成子・引数のある構成子・レコード・`Option` のどれも型の名前が消える。レコードはフィールドの名前も消える。`List[T]` もリストの記号だけが残る。
- `List.forEach` に渡したラムダの中の確認は、ラムダの引数の型が具体的なので正しく書ける。
- テストの関数の最後の文で補助の関数を呼ぶと末尾呼び出しになり、呼び出しの履歴にテストの関数の枠が残らない（上の `checkSame` だけの履歴）。`orch9/b/ctor_nontail.bnt` のように補助の関数の後に文を置くと、`checkSame at …:18:3` → `nonTail` と枠が残る。2 段の補助の関数（`checkTwice` → `checkSame`）でも同じで、`<constructor #0>(<constructor #0>)` になる。

##### 選択肢と推奨

対象の頭の空き（`orch9/b/layout.rs` の模型で確かめた）: `ObjHeader`（`runtime/heap/core.rs:101-112`）は `kind: ObjKind`（1 バイト）・`len: u32`（位置 4）・`tag`・`index`・`word`・`serial` で 32 バイトちょうどであり、`kind` の後に 3 バイトの詰め物がある。`CtorIdx` は 65,536 未満なので 16 ビットで収まる。`Value`（16 バイト。`runtime/heap/value.rs:89` で確かめている）の `Tag(CtorTag)` に 32 ビットの欄を足しても、模型では 16 バイトのままだった。

| 案 | 中身 | 値の表現（02-09）・頭 | バイトコード | プログラムの大きさ | 性能 | 凍結した型とシグネチャ |
|---|---|---|---|---|---|---|
| (a) 値に構成子の番号を持たせる | ヒープの構成子の頭の詰め物に `CtorIdx`（16 ビット）、`Value::Tag` に番号を足す。書き出しは `CompiledProgram::ctors` を引く | 変える。頭の大きさは変わらない（内部の層 `runtime/heap/core.rs` の `unsafe` の範囲を直す）。組み込みの関数が作る `Option`・`Result` などの値（`FieldsKind::Ctor` を使う箇所は本番のコードで約 150、`Value::Tag(CtorTag` は約 37）にも番号が要り、プログラムごとに「組み込みの型のタグ → `CtorIdx`」の表を引く経路を足す。定数表の `ConstDesc::Ctor` は既に `CtorIdx` を持つ | `CON` はそのまま（番号を値に書き足すだけ） | 組み込みの関数が作る構成子も表に載せるので少し増える | 確保の大きさは同じ。構成子を作るたびに 16 ビットを一つ書く。`Value::Tag` の比較と鍵の順序は番号を無視させる | `Value` の `Tag(CtorTag)`（10-08 の `file=`）、`alloc_fields(kind, tag, items)` と `fields_header`（10-08 の `sig=`）、参照インタプリタの変換に触れる。設計者の了承が要る |
| (b) タグから候補を示す | `AssertTable::adts`（全ての型）から、同じタグ・同じ引数の数の構成子を候補として並べる（`<constructor #0: Color.Red or Ordering.Less …>`） | 変えない | 変えない | 変えない | 失敗のときだけ | `runtime/assert.rs` の中だけ。ただし候補が多く、標準ライブラリの型も混じるので読みにくい |
| (c) 型の情報を関数に渡す | `equality` の制約を持つ型パラメータに、型の記述を隠れた引数で渡す（辞書渡し）か、単相化する | 型の記述の値が増える | 呼び出しの引数が増える（単相化なら原型が増える） | 増える | 型パラメータを持つ全ての関数の呼び出しが重くなる（単相化なら大きさ） | 脱糖・コード生成・型検査、形式化した範囲（01-12・`formal/`）に触れる。最も大きい |
| (d) 表示を改める | `<constructor #2 of an unknown type>` などにし、06-04 と Skill の文書で、補助の関数の型パラメータでは型が分からないことと回避（比べる値の型を具体的にする）を案内する | 変えない | 変えない | 変えない | なし | `text::UNKNOWN_CONSTRUCTOR` の文言だけ |
| (e) 静的な型の復元（新しい案） | e1: 型パラメータを含む型でも、具体的な部分は型に従って書き、型パラメータの位置だけ形にする。e2: 失敗のときに呼び出しの枠を外へ辿り、各枠の呼び出しの位置で型検査が記録した型引数（`type_args`。`Assert` の表と同じ仕組み）で `T` を置き換える。e3: 枠が無いとき（末尾呼び出し、高階の関数を通した呼び出し）は、プログラムの中のその関数の全ての呼び出しの型引数の集まり（静的な実体の集まり）から、値の形に合う型を選ぶ（一つに決まらなければ (d) の表示） | 変えない | 変えない | 変えない（表はテストの実行器だけが作る） | 失敗のときだけ。テストの実行の前に表を一度作る | `AssertTable`（10-18 の `file=` の公開の型）に欄を足すか、別の表を足す。`evaluate`（10-18 の `sig=`）に枠を渡す関数を足し、`assert_check` で枠を書き出しの前に集める。凍結した型を変えるなら設計者の了承が要る。値の表現・バイトコード・ヒープの公開の層は変えない |

推奨: **(e)（e1＋e2＋e3）と、決まらない場合に (d) の表示**。理由:

- 今の型の情報は呼び出しの位置の静的な表から来ており、補助の関数の型パラメータの実体も、型検査が呼び出しの位置ごとに既に記録している（`type_args`）。同じ仕組みを広げるだけで、`ctor.bnt` の例はすべて名前で書ける。e3 は、末尾呼び出しで枠が消える最も多い書き方（テストの最後の文で補助の関数を呼ぶ）を救う。`ctor.bnt` の `checkSame` の実体は `Color`・`Shape`・`Point`・`Option[Color]` で、タグと引数の数と引数の形で、どの値も一つに決まる。
- 値の表現・バイトコード・ヒープの内部の層（`unsafe` の範囲）と、10-08・10-07 の凍結した型に触れない。触れるのはテストの実行器の表と `assert.rs`・VM の `assert_check` だけで、テストを動かさない `run` の性能に影響しない。
- (a) はどの場合も正しいが、組み込みの関数が作る構成子の値すべてに番号を通す変更になり、`Value` の凍結した定義と内部の層に触れる。`Assert` の表示のためだけには大きい。実行時の型の情報が別の目的（汎用の表示関数、デバッガなど）で要るようになったときに、改めて (a) を検討する。
- (c) は形式化した範囲まで触れ、全ての型パラメータの呼び出しを重くするので、この目的には合わない。(b) は候補が多すぎ、利用者と LLM に読める表示にならない。

(e) で残る点: 型パラメータを持つ値を高階の関数とラムダへ渡し、さらに複数の型で使う場合は一つに決まらないことがある。そのときは (d) の表示（`of an unknown type`）と、06-04・Skill の文書の案内で補う。

## 調査 C: TODO-224 の調査（診断の表示の後の課題）

調べた版は san_benito の bf85fddc（未追跡の改造のディレクトリを除き作業ツリーは変更なし）。行番号は `crates/benitoite/src/` からの相対で示す。再現の入力は `orch9/c/` に置いた（`r*.bnt` は項目 2、`e*.bnt` は項目 3、`d*.bnt` は項目 4）。出力は `target/debug/benitoite check <file>` で得た。

結論を先に書く。

| 項目 | 結論 | 規模 |
|---|---|---|
| 1. 表記の依存 | `base` の下に新しいモジュールを作って移す。振る舞いは変えない | 小（4〜5 ファイル、ゴールデンの変更なし） |
| 2. 剛な型の表示 | 付け替えのない経路では、剛な型が**外側の関数の型パラメータの名前**（同じ番号のもの）か `_` で示される。名前の取り違えであり、表記の不揃いより重い。型の表示を `Body` の側の一つの関数に集める | 中（typeck の 5〜6 ファイル。ゴールデンの変更は見込みなし） |
| 3. E0212 のレコードの案内 | 今は `{` と `}` の二つの E0212 に加えて、`}` が関数を閉じたと読まれて派生の誤りが出る。名前の直後の `{` を見つけたら閉じる `}` まで読み飛ばし、`(`・`)` への置き換え付きの help を出せる | 中（構文解析器 3 ファイル、診断の表、設計書 2〜3 章、Skill の生成物） |
| 4. `declared` の理由 | TODO に書いた形（後の記録が先の記録を上書きする）はコードの上で起きない。ただし同じ仕組みで**報告の位置と型を取り違える場合を再現した**（下記 d13・d18）。項目は閉じず、再現した形に書き直して直す | 小〜中（`typeck/solve.rs` が主。テストを数件） |

#### 1. 型検査が、テストの実行器の表記に依存する

##### 今のコードの事実

- `typeck/consts/key.rs:2` が `use crate::runtime::assert::{quoted, text};` で、テストの実行器の記号の表と `quoted` を引く。`const_key`（20 行〜）が、定数の鍵を `Show.show` の形で書くために使う（`text::SEPARATOR` など 20 か所、`quoted` は 71・73 行）。前の改造の W4 L4 の指摘を受けて、表記の処理は既に `typeck/text.rs` から `typeck/consts/key.rs` へ移してある。
- 表の本体は `runtime/assert.rs:279-306` の `pub(crate) mod text`。この中には二種類の定数が混ざっている。
  - `Show.show` の形の記号（`TRUE`・`FALSE`・`UNIT`・`LIST_OPEN`・`MAP_OPEN`・`SET_OPEN`・`BYTES_OPEN`・`FROM_LIST_CLOSE`・`PAIR_OPEN`・`ARGS_OPEN`・`ARGS_CLOSE`・`SEPARATOR`・`FIELD_SEPARATOR`・`QUALIFIER`）。型検査と実行器が共有するのはこちらだけである。
  - 実行器の報告だけが使うもの（`ASSERTION_FAILED`・`ELLIPSIS`・`UNKNOWN_CONSTRUCTOR`・`OPAQUE`・`FUNCTION`・`UNKNOWN_VALUE`）。
- 文字列のエスケープは、同じ規則の写しが三か所にある。
  - `runtime/assert.rs:895-903` の `quoted` と `:905-927` の `escape_into`（`:863-876` の `quoted_within` も `escape_into` を使う）。
  - `builtins/funcs/traits.rs:30-48` の `escaped`（`Trait.showString`・`Trait.showCharacter` の本体。`assert.rs:893` のコメントが「同じ規則を写したもの」と書く）。
- `quoted` の利用者は、`typeck/consts/key.rs`、`cli/tools/test_runner/report.rs:7`（テストの説明を引用符で囲む）、`runtime/assert.rs` 自身の三つである。
- `typeck` はほかにも `runtime` を引く（`typeck/consts.rs:274-275` の `crate::runtime::MAX_STRING_BYTES`・`MAX_LIST_LEN`）。上限の定数は実行時の規則そのものなので、こちらは今回の対象外とする（W4 L3 も層の違反ではないとした）。
- 設計書（`docs/design/`）には `runtime::assert` や `quoted` の置き場所の記述はない（`git grep` で確かめた）。

`scripts/check.sh` の分類（`classify`、180〜233 行）は次のとおりである。

- 191〜196 行: `crates/benitoite/src/runtime/heap/*` は rust・long・default_lib・heap。
- 197〜199 行: `crates/benitoite/src/runtime/*`・`vm/*`・`refinterp/*` は rust と **long**（`describe` の見込みで約 15 分）。
- 200〜201 行: それ以外の `crates/*` は rust だけ。

したがって今は、記号を一つ変えるだけでも `runtime/assert.rs` を触るので long が選ばれる。長いテスト（`#[ignore = "long: ..."]` の 21 件。`pipeline.rs`・`runtime/list.rs`・`runtime/equal.rs`・`runtime/map/tests.rs`・`vm/...` など）は大きさで確かめるテストで、値の表示の記号には依存しない（`ignore = "long` の付いたテストを `grep` で確かめた）。

##### 今の出力

振る舞いの問題ではないので、出力の再現はない。結び付きは、前の改造で `assert.rs` の 1 行の変更が long を選んだこと（W4 L3）で確かめられている。

##### 選択肢と推奨

- 案 A（推奨）: `base` の下に新しいモジュール（例: `base/literal.rs`。名前は作業で決めてよい）を作り、次を移す。
  - `quoted` と `escape_into`（`pub(crate)`）。`quoted_within` は実行器の書き出しの上限のための関数なので `assert.rs` に残し、`base` の `escape_into` を呼ぶ。
  - `Show.show` の形の記号の表（`pub(crate) mod text` として。AGENTS.md「文言」の決まりのとおり `text` という子のモジュールに定数を置く）。
  - `runtime/assert.rs` の `text` には実行器だけが使う定数を残し、記号は `base` の表を引く。`typeck/consts/key.rs` と `cli/tools/test_runner/report.rs` は `base` を引く。
  - 余力があれば、`builtins/funcs/traits.rs` の `escaped` も同じ `escape_into` を使う形にし、写しを一つにする（`Trait.showString` の大きさの見積もり（59 行）は 1 文字ずつの長さを使うので、`escape_into` で 1 文字分を書いた長さを数える形に直す）。
  - 理由: `base/mod.rs` の `//!` が「処理系の全段が共有する基本の型」と定めており、型検査（前の段）と実行器（後の段）の両方が引く場所として向きが自然である。`ir` は中間表現のモジュールで、値の表記とは関係がない。`diag` は診断の表と表示の層で、実行器の値の書き出しが `diag` を引く向きは別の結び付きを作る。
- 案 B: 型検査に写しを置く。写しが四つ目になり、表記を変えたときに食い違う危険が増すので勧めない。
- 案 C: 今のままにし、`runtime/assert.rs` の `//!` に型検査からも引くことを書く。long が選ばれる結び付きは残る。

移した後の `check.sh` の選ばれ方:

- `base/literal.rs`（記号の表・エスケープ）だけを変えたとき: `crates/*` に当たり rust だけ。long は選ばれない。
- `runtime/assert.rs` の残り（実行器の判定と書き出し）を変えたとき: 今と同じく rust と long。
- 移す作業そのものは `runtime/assert.rs` を変えるので、その取り込みでは long が一度選ばれる（約 15 分）。

##### 規模

- 触るファイル: `base/mod.rs`（`pub(crate) mod literal;`）、`base/literal.rs`（新規、60 行程度）、`runtime/assert.rs`、`typeck/consts/key.rs`、`cli/tools/test_runner/report.rs`。案 A の余力の分で `builtins/funcs/traits.rs`。
- テスト: 出力は変わらない。`runtime/assert/tests.rs` は `quoted` を直接呼んでいない（`grep` で確かめた）。エスケープの単体テストを `base/literal.rs` に置くかは、test-audit の作成時の関門（今のテストが既に覆っているか）で決める。既存の `typeck` の定数の鍵のテストと実行器のゴールデンが、移した後も同じ出力であることを確かめれば足りる。
- ゴールデン・設計書・Skill の生成物: 変更なし。

#### 2. 剛な型を操作の型パラメータの名前で示す付け替えが、`Solver::show` にしかない

##### 今のコードの事実

付け替えは `typeck/solve.rs` にある。

- `:576-584` の `show` と `:585-600` の `show_named` が、`diagnostic_type`（`:659-680`。未確定の変数を `_` にする）で型を作り、`name_rigid_types`（`:603-656`）で `Ty::Rigid` を名前の表の後ろに足した `Ty::Param` に置き換えてから表示する。外側の関数の型パラメータと同じ名前なら `store.T` の形にし、さらに重なれば `store.T#2` とする（Z1Z2 L3 の指摘は `#` 付きの形で直してある）。
- E0401 の注記（`:776-791`）も同じ名前の表を使う。

付け替えのない経路では、`Ty::show`（`types/mod.rs:490`）が `Ty::Rigid { index, .. }` を `param_name(index, names.type_params)` で表示する。名前の表は**外側の関数の型パラメータ**なので、剛な型は外側の関数の同じ番号の型パラメータの名前で示され、番号が表の外なら `_` になる。元の剛な型の名前（`T`）が出るわけではない。

型を表示する経路をすべて挙げる（`TyNames {` と `.show(` を `typeck`・`types`・`ir` で探した）。

| 場所 | 診断 | 型の作り方 | 剛な型が現れうるか |
|---|---|---|---|
| `typeck/solve.rs:576`（`Solver::show`）・`:739`・`:751` | E0401・E0402・E0403・E0416・E0405（`:1305`）・E0406・E0422・E0423、エフェクトの診断の型の表示（`:1451`） | `diagnostic_type` と付け替え | 現れうる。付け替え済み |
| `typeck/effects/special.rs:214-226`（`show`） | E0443（`:59`）、E0440（`:131`）、E0441（`:149`・`:157`）、E0442（`:179-181`） | `finalize`（未確定を `Unit` にする）、付け替えなし | 現れうる（下記 r1・r2b・r3・r7） |
| `typeck/pattern_ext.rs:395` | E0607 | `finalize`、付け替えなし | 現れうる（r4・r7） |
| `typeck/traits/collect.rs:347-355`（`show`）を `typeck/traits/solve.rs:459`・`:465` から呼ぶ | E0705・E0715 | 渡された `Ty`（`argument_ty`）、付け替えなし | 現れうる（r6） |
| `typeck/generate.rs:951` | E0438 | `finalize`、付け替えなし | 再現できなかった。剛な型を返すラムダが末尾に届く形（r8）は E0401 になる。関数の戻り値の型は剛な型を含まない |
| `typeck/generate.rs:288` | E0403（定数を呼んだ） | `finalize`、名前の表は空 | 現れない（定数の型は剛な型を含まない） |
| `typeck/traits/collect.rs:253`、`typeck/traits/impls.rs:49`・`:144`・`:166`・`:201`・`:299-300` | 型クラスの宣言・実装の検査 | 宣言の型 | 現れない（宣言の段で、本体の剛な型はない） |
| `ir/desugar/decls.rs:339` | 診断ではない（実装の名前） | — | 対象外 |

このほか、剛な型の制約の誤り（E0405・E0406・E0424）は `typeck/traits/mod.rs:115-133` の `check_rigid_bound` が `check_parameter_bound`（`:135-183`）を通し、`"param"` と `"ty"` に操作の型パラメータの名前（`p.name`、例 `T`）をそのまま入れる。外側の関数が同じ名前の型パラメータを持つと区別できない。

##### 今の出力

外側の関数 `run[A](a: A)` の中のハンドラの節（`case store(x)`、`x: T`）で試した。

| 入力 | 出力（抜粋） | 正しい表示 |
|---|---|---|
| r1（`try x`） | E0440 ``try` cannot be applied to `A``` | `T`（外側に `T` があれば `store.T`） |
| r3（`try Option.Some(x)` をラムダの中で） | E0441 ``try` on `Option[A]` needs …`` | `Option[T]` |
| r2b（`try Result.Error(x)`） | E0442 ``… an error of type `A` from a function that returns errors of type `String```、注記 ``the lambda returns `Result[Unit, String]``` | `T`。注記の `Unit` は未確定の型を `finalize` が `Unit` にしたもので、`Solver::show` なら `Result[_, String]` |
| r4（`bind Option.Some(v) <- Option.Some(x)`） | E0607 ``… every value of `Option[A]``` | `Option[T]` |
| r6（`Trait.Show.show(Option.Some(x))`） | E0705 ```A` does not implement `Show``` | `T` |
| r7（外側に型パラメータがない `main`） | E0607 ``Option[_]``、E0440 ``try` cannot be applied to `_``` | `Option[T]`・`T` |
| r5（同じ節で `x = x`・`x < x`・`"${x}"`） | E0406 ``values of type `T` …``、E0405 ```<` cannot be applied to `T```（`check_rigid_bound` の経路） | 名前は合う |
| r11（r5 の外側を `run[T]` にした） | E0406 の help ``add the constraint `equality` to the type parameter, such as `[T: equality]``` | 外側の `run[T]` に制約を足しても直らない。`store.T` と示し、操作の宣言に足すことを案内するべき |
| r10（外側 `run[T]`、`x = a`） | E0401 ``expected `store.T`, found `T``` | 付け替え済みの経路。合う |

付随して見つけた別の点（この項目の範囲外。新しい項目の候補）:

- r9: 型パラメータの値を文字列に埋め込む `"${a}"` が、E0422 でなく E0405 ```ordered` cannot be applied to `A``` と help ``operators cannot be applied to values of a type parameter`` になる。`check_parameter_bound`（`typeck/traits/mod.rs:159-165`）が `ReasonKind::Interp` を見ずに `Bound::Set` を E0405 にするためで、剛な型でない普通の型パラメータでも起きる。
- r1・r3 などで、`handle` を `return` なしで本体の最後に置くと E0416 も出る（入力の書き方の問題で、診断は正しい）。

##### 選択肢と推奨

- 案 A（推奨）: 型の表示を `Body` の側の一つの関数（例: `Body::show_type(&self, t: &ITy) -> String` と、注記と名前の表を共有する `show_types(&[&ITy])`）に集める。中身は今の `Solver::show_named` と同じく、`diagnostic_type` → `name_rigid_types` → `Ty::show` とする。`special.rs:214`・`pattern_ext.rs:395`・`traits/solve.rs:459/465`・`generate.rs:951` をこれに置き換える。`generate.rs:288` と宣言の段の経路（`traits/impls.rs`・`traits/collect.rs:253`）は本体の文脈を持たないので今のままでよい（剛な型が現れない）。
  - 一つの診断に型が二つ入る E0442（`expected`・`found`・`declared`）は、名前の表を共有する（`Solver::failure` の `names`・`indices` と同じ作り方）。
  - `finalize` から `diagnostic_type` に変わるので、未確定の型が `Unit` でなく `_` で示される（r2b の注記）。これは 02-05「誤りの報告と検査の継続」の「出力用の finalize の既定値を診断へ持ち込まない」（`solve.rs:657-658` のコメント）に合わせる直しでもある。
  - `check_rigid_bound` の `param`・`ty` も同じ名前の付け方（外側と重なれば `store.T`）にする。E0406・E0424 の help の「`[T: equality]`」は、剛な型のときは操作の宣言に制約を書く案内に変える（置き換えは今も付けていない。`index` が `None`）。文言の鍵を足すかは作業で決める。
- 案 B: 各経路の中で `name_rigid_types` を個別に呼ぶ。経路が増えるたびに同じ漏れが起きるので勧めない。
- 案 C: `Ty::show` の側で `Ty::Rigid` を `?` などの固定の表示にする。操作の名前が分からず、`Solver::show` の表示とも揃わないので勧めない。

##### 規模

- 触るファイル: `typeck/solve.rs`（`name_rigid_types` と `diagnostic_type` を `Body` から使える形にする。`fn` を `pub(super)` にするか、`context.rs` に移す）、`typeck/context.rs`（新しい関数）、`typeck/effects/special.rs`、`typeck/pattern_ext.rs`、`typeck/traits/solve.rs`、`typeck/traits/mod.rs`（`check_rigid_bound`）、`typeck/generate.rs`（E0438。剛な型は現れないが経路を揃える）。
- 出力の変化: ハンドラの節の中の E0440・E0441・E0442・E0443・E0607・E0705・E0715 の型の名前、E0441・E0442 の注記などで未確定の型が `Unit` から `_` に変わる。
- テスト: `typeck/effects/tests.rs` に r1・r2b・r4・r6 の形（外側に `A` を持つもの）と r11 の形を加える。外側の型パラメータの名前が出ないこと、`store.T` が出ることを確かめる。既存のゴールデンで E0440・E0441・E0442・E0607・E0705 を含むものは 1・1・0・1・3 件あり、どれも剛な型と `Unit` の表示を含まないので変わらない見込み。`handlers/` にゴールデンを 1 件（例: `secf1-outer-type-param` の並びで E0607 か E0705）足すかは test-audit で決める。
- 設計書: 02-05「誤りの報告と検査の継続」の剛な型の名前の段落を、`Solver::show` に限らず本体の型の表示すべてに当てはまる書き方にする。02-10 の変更はない見込み。
- Skill の生成物: 文言の鍵を足したときだけ `gen_skill` で作り直す。

#### 3. 波括弧でレコードを作った誤り（E0212）に、構築の形を案内していない

##### 今のコードの事実

- 正しい書き方: 01-02「レコード（初回リリース版）」（`docs/design/01-spec/01-02-syntax.md:378-421`）の `RecordExpr = QualUpper "(" [ ".." Expr "," ] FieldArg { "," FieldArg } [ "," ] ")"`、`FieldArg = LowerIdent ":" Expr`。パターンも同じ形（`Person(name: n, ..)`）。416 行は「`QualUpper` の直後の `(` の次が『小文字の名前 `:`』か `..` であれば、レコードの構築として読む」と定める。丸括弧の中の改行は区切りにならない（e9 の複数行の `Point(\n x: 1,\n y: 2\n)` は誤りなく通った）。
- 波括弧は字句解析では誤りの字句（`TokenKind::BadSymbol`）になり、構文解析器が文脈で E0212 を選ぶ（02-03「字句の誤り」）。報告は `syntax/parser/foreign.rs:130-200` の `report_unclaimed` で、`{` は help `open`（162〜165 行）、`}` は開いているブロックがあれば help `end`（166〜176 行）。
- 回復の流れ（e1 の `bind p <- Point { x: 1, y: 2 }`）:
  1. `exprs.rs:372-385` の `parse_name` が `Point` を読み、`record_ahead`（`exprs.rs:232-237`、`(` の次が `..` か「小文字 `:`」）が偽なので名前の式で終わる。
  2. 文の終わりで `{` に出会い、`Parser::unexpected`（`mod.rs:408-416`）が `report_unclaimed` を呼んで E0212（open）を出す。
  3. 文の回復（`exprs.rs:742-745` の `recover_statement`、`Recovery::Line`）は、改行・`end`・`}` で止まる（`mod.rs:680`）。`{` は入れ子に数えないので、`x: 1, y: 2` を読み飛ばして `}` で止まる。
  4. ブロックの終わりの判定（`exprs.rs:565-567` の `block_end`）が `}` をブロックの終わりと見て、`close_block`（`mod.rs:767-781`）が E0212（end、「close the block with `end function` instead of `}`」）を出し、`}` で**関数の本体を閉じる**。
  5. 次の行の `bind _ <- p` が宣言の位置で読まれ、E0201「expected a declaration, found `bind`」が出る（派生の誤り）。`return Point { … }` の後では `end function` が E0201 になる（e10）。
- E0212 の表（`diag/codes.rs:217-220`）の help は `end` と `open` の二つで、修正案（`fix`）の欄はない。02-10 の修正案の表（`docs/design/02-impl/02-10-diagnostics.md:54`）も「波括弧でブロックを書いた」を「置き換え なし」としている。
- 似た誤りの先例: `fn(x) { … }` は `foreign.rs:31-72` の `fn_form` が、対応する `}` まで一つの旧式として読み飛ばし、波括弧を `reported_symbols` に入れて派生の E0212 を抑える。レコードを値の位置に書いた E0304 は、前の改造（R6）で help `construct`（「build a record with its field names, such as `Point(x: ..., y: ...)`」、`codes.rs:404-406`）を出す（e7）。
- 構文解析器の公開の関数の `records::parse_record_expr(p, path, start, depth)` は凍結したシグネチャ（`syntax/parser/mod.rs:25` の表）で、`open_record`（`records.rs:44`）は `(` を求める。

##### 今の出力

`record Point` に `x: Integer`・`y: Integer` を持たせ、`main` の中で試した（`orch9/c/e*.bnt`）。

| 入力 | 出力 |
|---|---|
| e1 `bind p <- Point { x: 1, y: 2 }` | E0212（`{`、help open）、E0212（`}`、help「close the block with `end function` instead of `}`」）、E0201「expected a declaration, found `bind`」（次の行） |
| e2 `Point{x: 1, y: 2}`（空白なし） | e1 と同じ 3 件 |
| e3 `bind p <- { x: 1, y: 2 }`（名前なし） | e1 と同じ 3 件 |
| e4 `Point { x = 1, y = 2 }`（`=`） | e1 と同じ 3 件 |
| e5 `Point { ..q, x: 1 }` | e1 と同じ 3 件 |
| e8 複数行の `Point {` … `}` | E0212（`{`）、E0201「found `:`」（次の行の `x: 1,`）、E0212（`}` が関数を閉じる）、E0201（`bind`）の 4 件 |
| e10 `return Point { x: 1, y: 2 }` | E0212 ×2、E0201「found `end`」（`end function`） |
| e12 `show(Point { x: 1, y: 2 })`（引数の中） | E0212（`{`）、E0201「expected `,` or `)`, found `:`」、E0212（`}` に「close the block with `end function`」） |
| e13 `bind Point { x: a, y: b } <- …`（パターン） | E0212 ×2、E0201「found `<-`」 |
| e7 `Point(1, 2)`（参考） | E0304 と help ``build a record with its field names, such as `Point(x: ..., y: ...)``` の 1 件 |

どの形でも、構築の書き方を示す案内はなく、`}` への help は「`end function` で閉じる」という誤った方向を示す。

付随して見つけた別の点（この項目の範囲外。新しい項目の候補）:

- e6 `bind p <- new Point(1, 2)`: E0201「expected a newline or the end of the block, found `Point`」だけで案内がない（`new` は名前として読まれる）。
- e11 `Point(x = 1, y = 2)`: E0304 と、`x`・`y` の E0301 が 2 件。`=` を `:` にする案内がない。

##### 選択肢と推奨

構文解析器の中で、波括弧のレコードの形を見つける箇所を三つに置く。

1. 式の名前の直後（`exprs.rs:372-385` の `parse_name`）: 大文字で終わる修飾した名前の直後が `{`（`p.symbol("{")`）のとき。
2. パターンの構成子の名前の直後（`patterns.rs:80-84` の `parse_ctor`）: 同じ条件。
3. 式の始まり（`exprs.rs:361` の `parse_primary` の最後の `unexpected` の前）: `{` の次（改行を飛ばして）が「小文字の名前 `:`」のとき。名前のないレコード（e3）。

見つけたら、`fn_form` と同じく、対応する `}` まで読み飛ばし（`{`・`}` を数え、行頭の宣言の始まりと `Eof` で止める）、二つの波括弧を `reported_symbols` に入れて、`Expr::Error`（パターンなら誤りのパターン）を返す。E0212 は `{` の位置に一件だけ出す。これで `}` が関数を閉じる派生の誤り（手順 4・5）が消える。

案内の出し方は次の二つから選ぶ。

- 案 A（推奨）: 文と置き換えの両方を出す。条件は「名前の直後の `{` で、中の最初の字句が『小文字の名前 `:`』か `..` であり、対応する `}` が見つかった」こと（置き換えた後に `record_ahead` が真になる条件と同じ）。
  - 置き換え: 名前の終わりから `{` の終わりまでを `(` に、`}` を `)` にする（2 件、重ならない）。e1 は `Point(x: 1, y: 2 )` になる（`}` の前の空白も消すなら、`}` の直前の空白から `}` までを `)` にする）。複数行の e8 も丸括弧の中の改行は区切りにならないので通る（e9 で確かめた）。`..q` の形（e5）も `Point(..q, x: 1)` になる。
  - 文: E0212 に新しい help の鍵（例: `record`「build a record with parentheses and field names, such as `{example}`」）を足し、`{example}` に置き換えた後の形を入れる。`fix [record]` を表に足す。
  - 02-10「修正案」の「当てれば誤りがなくなると処理系が決められるときだけ」に照らすと、消えるのはこの構文エラー（E0212）であり、`&&` を `and` にする E0211 などと同じ扱いになる。フィールドの名前が宣言と合うかは名前解決と型検査が別の診断で確かめる。
  - 置き換えを付けない場合: `{ x = 1 }`（e4。`=` は比較の演算子なので、`:` への置き換えを足せば通るが、条件を増やさないなら文だけにする）、`{ x, y }`（Rust の省略形。値が分からない）、`{}`（空）、名前のない e3（構文解析器はレコードの名前を知らない）。名前のない形の文は、例に `Name(x: 1, y: 2)` の形で書いたフィールドを使い、名前を補うことを示す別の鍵（例: `record_name`）にする。
- 案 B: 文だけを出す（置き換えなし）。実装は少し小さいが、読み飛ばしの処理は同じだけ要るので差は小さい。02-10 の表の「波括弧」の行の「置き換え なし」を変えずに済む。
- 案 C: 波括弧を丸括弧として読み、`RecordExpr` の木を作る（中のフィールドの誤りも報告できる）。`parse_record_expr` は凍結したシグネチャで `(` を前提にしており、構文エラーがあると名前解決と型検査へ進まないので得るものも少ない。勧めない。

推奨は案 A。LLM が書いた `Point { x: 1, y: 2 }` に、当てればそのまま通る置き換えを示せる。

##### 規模

- 触るファイル: `syntax/parser/foreign.rs`（見つけて読み飛ばし、報告する関数。`#[cold]`・`#[inline(never)]`）、`syntax/parser/exprs.rs`（`parse_name`・`parse_primary`）、`syntax/parser/patterns.rs`（`parse_ctor`）、`diag/codes.rs`（E0212 の help の鍵と `fix`）。
- 設計書: 01-02「レコード（初回リリース版）」に、波括弧で作った・照合したときの修正案を【方針】で一文足す（421 行の `p.name` の文と同じ形）。02-03「他の言語の書き方への診断」（166 行〜）の表に一行足す。02-10「修正案」の表（54 行）に行を足すか、波括弧の行を分ける。01-02 を変えると `check.sh` は spec_examples・spec_coverage・skill を選ぶ（`check.sh:202-205`）。形式化の範囲（07-04）には当たらない（構文の受け付ける範囲も、脱糖も変えない）。
- テスト: `syntax/parser/mod.rs:1441-` の `diagnostics_and_recovery_for_foreign_forms` に e1・e3・e8・e10・e12・e13 の形を足し、E0212 が 1 件で派生の E0201 が出ないことを確かめる。置き換えを当てた後に構文解析が通ることを確かめるテストを 1〜2 件（`diag/render/help_tests.rs` の先例に合わせる）。`testdata/syntax/` のゴールデン（`c11-braces`・`brace_next_line`）は形が違うので変わらない見込みだが、作業で確かめる。
- Skill の生成物: 診断の表を変えるので `cargo run -p benitoite --example gen_skill` で `skill/references/` を作り直す。CHANGELOG に一行。

#### 4. 宣言への流れ込みの記録（`declared`）が根ごとに一つの理由しか持たない

##### 今のコードの事実

- 欄は `typeck/solve.rs:68`（`declared: BTreeMap<u32, Reason>`）。
- 記録するのは `flow`（`:463-511`）の最後の分岐（`:501-509`）だけである。`r.priority == Priority::Declared` で、流れ込む側 `a` が `ITy::Var(v)` のときに `declared.insert(self.root(v).0, r)` し、直後に `self.equal(&b, &a, r)?` で結び付ける。
- `Priority::Declared` を付けるのは、`generate.rs:31-50` の `flow(..., declared: true)` と、部分適用の呼び出し（`generate.rs:405-408`）である。`flow(..., true)` は `return` の流れ込みのほかに、束縛の型注釈（`generate.rs:1328-1355` の `bind_stmt` の `ReasonKind::BindAnnotation`）でも使う。宣言の制約は、ほかの制約より先に解く（`solve.rs:950-975`、02-05「制約の解決」の手順 1）。
- 記録を引くのは二か所。`call_return`（`:518-552`、FE403）と `pair_failure`（`:1086-1124`）の移し替え（`:1107-1121`。宣言でない制約の E0401 が、記録のある根の変数と食い違ったら、失敗した位置が記録の理由の範囲の内側でない限り、記録の理由の位置へ移して `late` に積む）。

同じ根への二度目の記録が起きないことの根拠:

1. `flow` は先に `a`・`b` を `zonk_checked` する（`:465-466`）。`zonk_checked` は束縛のある変数を束縛先まで辿り、束縛のない変数だけを根の変数（`ITy::Var(root)`、`:174-176`）として返す。したがって記録の条件の `ITy::Var(v)` は、束縛のない根である。
2. `(Var, Var)` は手前の分岐（`:470`）で `Ok(false)` を返すので、記録の分岐に来るとき `b` は変数でない。
3. 記録の直後の `equal(&b, &a)` は、`equal_with_outer`（`:372-387`）の `(ITy::Var(v), t)` の分岐で `bind(v, t)` を呼ぶ。`bind`（`:301-320`）は `t` が変数でないとき根に束縛を書く。失敗（出現検査の E0404、節の剛な型の脱出の E0401）は `flow` の `?` で `pair_failure` へ行き、宣言の制約なので `failure`（`:1123`）が `poison`（`:554-`）で根を誤りの型に束縛する（`FnBody` を `late` へ回す分岐 `:1093-1104` は `equal` で作る Normal の制約だけで、宣言の流れ込みには当たらない）。
4. 束縛のある根は、それ以後 `zonk` で変数として返らないので、同じ鍵で記録の分岐に入らない。束縛のある変数が別の変数の子になることもない（変数どうしの `bind` は、どちらも束縛のない根のときだけ呼ばれる）。

よって「後に記録した理由だけが残る」は起きない。残るのは常に**最初の**宣言の流れ込みの理由で、二度目の流れ込みは、一度目が決めた型に対する普通の比較になる（d3 で、二つの `return s` のうち先の位置で報告された）。

##### 今の出力

再現を試みた入力（`orch9/c/d*.bnt`）。「正しい報告」は、その制約がなければ出る報告（d14・d15・d17 で確かめた）を基準にした。

| 入力 | 形 | 出力 | 判定 |
|---|---|---|---|
| d1 | `bind s <- n`（Integer）、`return s`、`return s + "x"` | `"x"` の位置で E0401 | 正しい |
| d2 | `bind s <- "x"`、`return s`、`return Integer.parse(s)`（関数は Integer） | 先の `return s` で String、後の `return` で Option[Integer] | 正しい |
| d3 | `bind s <- "x"`、二つの `return s`（関数は Unit） | 先の `return s` で 1 件 | 正しい（最初の記録が残る） |
| d5 | `return match c with … s … s + "x"` | 分岐の中の `"x"` | 正しい |
| d6 | ラムダの中の `return s` と外の `return k() + "x"` | `"x"` | 正しい |
| d11 | `bind s <- Option.None`、`return s`、`return Option.Some("x")` | `"x"` | 正しい |
| **d13** | `bind s <- n`（Integer）、`bind _ <- g(s)`（`g(x: String)`）、`return s`（関数は Integer） | `return s` の位置で「expected `Integer`, found `String`」、注記「the returned value must match the declared return type」 | **誤り**。`s` は Integer で、`return s` は正しい。誤りは `g(s)` の引数（`return s` がない d14 では `g(s)` の位置で「expected `String`, found `Integer`」） |
| d7・d4・d10 | d13 と同じ食い違いを、二つの `return` の後の方の式の中（`return g(s)`、`return if … g(s) …`）に置いた | 先の `return s` の位置で「found `String`」 | **誤り**（d13 と同じ原因） |
| d9 | 先の `return g(s)`、後の `return s` | 後の `return s` の位置で「found `String`」 | **誤り**（同上） |
| **d18** | `bind s <- n`（Integer）、`bind t: String <- s`、`return s`（関数は Integer） | `return s` の位置で「expected `Integer`, found `String`」 | **誤り**。誤りは型注釈の束縛（`return s` がない d17 では、注釈の位置で「expected `String`, found `Integer`」） |
| d16 | d18 で関数を Unit にした | `return s` で「expected `Unit`, found `String`」 | 位置は誤りの一つだが、`s` の型を String と示すのが誤り（`s` は Integer） |

原因は二つある。どちらも「同じ型変数に、宣言の流れ込みと別の制約が食い違う」場合で、TODO の見出しの疑いと同じ仕組みの中にある。

- d13 系（宣言の流れ込みは一つ）: 手順 1 で `return s` が `s` を Integer に決め、`declared[s]` を記録する。手順 2 で `bind s <- n` は通り、`g(s)` の引数の流れ込み（`CallArg`）が Integer と String で失敗する。`pair_failure` の移し替え（`:1107-1121`）は、失敗した制約が変数を**使う**側か**定める**側かを見ないので、使う側の失敗も `return s` へ移し、`found` に引数の型（String）を書く。R18 が想定した形（`bind s <- Integer.toString(1)` の後の `return s`。前の改造の study.md「`return s` の型の誤り」）は、失敗した制約が束縛の文のパターンの制約（`bind_stmt` の `ReasonKind::Pattern`、`generate.rs:1346-1352`）で、変数を定める側だった。
- d18 系（宣言の流れ込みが二つ）: 型注釈の流れ込み（Declared）が先に `s` を String に決め、`declared[s]` を記録する。次の `return s` の流れ込み（Declared）は String と Integer で失敗し、宣言の制約なので移し替えの対象にならず、その場で報告される。`s` を定める `bind s <- n` は手順 2 なので、まだ解かれていない。報告の後は `poison` で `s` が誤りの型になり、本当の誤り（注釈の位置）は報告されない。

##### 選択肢と推奨

TODO に書いた形（記録の上書き）は、上の根拠 1〜4 から起きない。項目はこの形では閉じてよいが、同じ仕組みで再現した d13 系と d18 系を、この改造で直す対象として書き直すことを勧める（または新しい項目に移す）。

d13 系の直し方:

- 案 A（推奨）: 移し替えを、失敗した制約が変数を定める側のときに限る。具体的には、理由の種類が `Pattern`（束縛の文・分岐のパターン）で、記録のある変数がパターンの側（`bind_stmt` の `equal(ctx, target, p, …)` の `p`）にあるとき。R18 の f・g・h の形はこの条件に入る。前の改造で足した `declaration_flow_preserves_inner_failure_positions_and_repairs`（`return` の二項演算、`bind` の注釈、`return if`）が通り続けるかは、作業で確かめる（`bind` の注釈の場合は、注釈の流れ込みが宣言の制約なので d18 系の直しとも関わる）。d13 の `CallArg` と d16・d18 の `BindAnnotation`（`s` は値の側）は入らず、失敗した位置で報告される。期待と実際のどちらがパターンの側かを `pair_failure` が知るには、`Reason` に印を足すか、`bind_stmt` の制約の向き（期待が値の型、実際がパターンの型）を決まりとして使う。どちらにするかは作業で決める（`Reason` の欄は凍結の対象かを確かめる）。
- 案 B: 失敗した位置が記録の理由より前（ソースの順）なら移さない。d13 は `g(s)` が前なので直るが、R18 の f（`bind s <- …` が前）も移らなくなるので不可。
- 案 C: 02-05 の study で「代案」とした、手順 1 で流れ込む側が未確定の変数の `return` を手順 2 の後へ回す。推論の順序が広く変わる。勧めない。

d18 系の直し方:

- 案 D（推奨）: 宣言の流れ込みが失敗したとき、流れ込む側の型が別の宣言の流れ込みで決まったもの（`flow` の始めの `zonk` の前の `a` が変数で、その根に `declared` の記録があり、理由が今の制約と違う）なら、その場で報告せず `late` に積み、手順 2 の後に、その変数が誤りの型になっていれば捨て、なっていなければ報告する。d18 では手順 2 の `bind s <- n` が注釈の記録へ移されて注釈の位置で報告され（案 A の条件に入る。パターンの側が `s`）、`return s` の報告は捨てられる。d16 では `return s` の誤り（Integer と Unit）が別に残るかを確かめる必要がある（`poison` の後なので出ない見込み。一件目を直せば再検査で出るので許容できる）。
- 案 E: 記録を `Vec<Reason>` にして、報告のときに複数の理由を注記に並べる。どれが誤りかを決めないので、LLM が直す位置を選べない。勧めない。

テストに残す形: d13・d7（二つの `return`）・d9・d18・d16 の 5 件を `typeck/tests.rs` に足し、R18 の 3 件と `redirected_binding_failures_report_once_per_root`、FE403 の既存のテストが通ることを確かめる。

##### 規模

- 触るファイル: `typeck/solve.rs`（`pair_failure` の条件、宣言の流れ込みの失敗を後へ回す処理、`LateFailure` の扱い）、必要なら `typeck/infer.rs`（`Reason` に印）と `typeck/generate.rs`（`bind_stmt`）。
- テスト: 上の 5 件。ゴールデンは、E0401 の位置を `return` へ移した形を固定したものがあるかを作業で確かめる（`grep` で `the returned value must match` を含む `.diag.json` を洗う）。
- 設計書: 02-05「誤りの報告と検査の継続」の、手順 1 で決めた変数との食い違いを宣言の理由で報告する段落に、移すのは変数を定める制約（束縛のパターン）の失敗に限ることと、宣言どうしの食い違いの扱いを書く。02-10 の表（E0401 の行）に関係する記述があれば合わせる。

#### 作業の分け方の案

項目 2 と 4 はどちらも `typeck/solve.rs` を中心に触り、項目 1 は振る舞いを変えない移動、項目 3 は構文解析器だけで閉じる。直列で進める前提（一作業ずつ、重い検査は最後に一度）で、次の 3 本を勧める。

1. 作業 1「表記の中立化」（項目 1）: `base/literal.rs` を作り、`quoted`・`escape_into`・`Show.show` の記号を移す。`builtins/funcs/traits.rs` の写しの統一は任意。出力は変えない。`runtime/assert.rs` を触るので、この取り込みの `check.sh` は long を選ぶ（約 15 分）。小さいので、作業 2 の先頭にまとめてもよい。
2. 作業 2「型検査の診断の表示と報告の位置」（項目 2・4）: 本体の型の表示を一つの関数に集めて剛な型の名前を揃え（`check_rigid_bound` の名前と help を含む）、`finalize` の既定値を診断から除く。続けて、宣言の流れ込みの移し替えを変数を定める制約に限り（案 A）、宣言どうしの食い違いを後へ回す（案 D）。どちらも 02-05 の同じ節を直す。項目 4 は案の選び方に判断が残るので、事前点検で案 A の印の持ち方（`Reason` の欄か制約の向きか）を決めてから渡す。
3. 作業 3「波括弧のレコードの案内」（項目 3）: 構文解析器の 3 か所で波括弧のレコードの形を見つけ、読み飛ばして E0212 を一件にし、`(`・`)` への置き換え付きの help を出す。診断の表、01-02・02-03・02-10、Skill の生成物、CHANGELOG を同じ作業で直す。

範囲の外で見つけた点（新しい TODO の項目の候補）:

- 型パラメータの値の文字列補間が E0405 ```ordered` cannot be applied to `A``` になる（r9。`typeck/traits/mod.rs:159-165` が `ReasonKind::Interp` を見ない）。
- `new Point(1, 2)` に案内がない（e6）。`Point(x = 1, y = 2)` に `=` を `:` にする案内がない（e11）。

