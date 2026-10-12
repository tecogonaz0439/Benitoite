# T2 のレビュー（プレースホルダの呼び出しの環境の差し替え）

- 対象: 作業ディレクトリ `Benitoite-T1`（ブランチ impl/TODO-178-T2、基準 1622594）の未コミットの変更と、未追跡の `testdata/*/todo178-placeholder-*`
- レビュー担当: Claude Opus 5.5（推論の度合い medium）
- 確かめ方: 差分を読み、worktree で `cargo build` した `target/debug/benitoite` で小さな `.bnt` を試した（scratchpad の `t178/`）。`check-formal.sh` などの検査は実装担当の報告を信用し、走らせ直していない。

## 確かめたこと（問題なし）

1. **型検査の環境の差し替えと復元**（`crates/benitoite/src/typeck/generate.rs:268-287`）: 呼び出しを `call` と `call_body` に分け、`call_body` は途中で戻らないので、`ctx.effect`・`ctx.ret`・`ctx.clauses`・`ctx.return_annotation`・`ctx.placeholder_boundary` は、誤りの経路でも必ず戻る。呼ばれる関数の式（`call_body` の先頭の `ctx.expr(&e.callee)`）も差し替えた環境で検査するので、Lean の `E_PartialCall`（`formal/Benitoite/Surface/Typing.lean:186-191`。`f` と `args` の両方を `hideConts Γ` と `some r` で検査する）と一致する。構成子の部分適用も同じ経路を通り、`E_PartialCon`（同 193-198）と同じく引数を展開後の戻り値の型で検査する。
2. 実行で確かめた例（すべて期待どおり）:
   - 入れ子: `add(add(return 1, _)(2), _)` の `g(10)` は 11。内側の `return` は内側の展開後のラムダだけを抜ける。
   - 引数の中のラムダの `return` はラムダを抜ける（111）。引数の中の `handle` の節の `resume` は内側の `handle` の継続を指し、受け付けて 13 になる。
   - 呼ばれる関数の式の中の `return`: `(if c then return 5 else add end if)(_, 1)` は `c` が真で 5、偽で 3。
   - 多相と型クラスの辞書: `both[T: Describe](return Describe.describe(y), _)`、`pick(_, return x)`、`wrapT[T](try o, _)` は正しく型が付き、実行の結果も正しい（`i2i1`、`some i4`、`none`）。脱糖の `ty.ret` は `self.ty(e.id)`（確定した展開後のラムダの型）から取るので、辞書の引数は呼ばれる関数の側の具体化に入り、戻り値の型には影響しない。
   - 復元: プレースホルダの引数に `return 1` を書いた後の `return 5`（外側は `String`）は E0401 になる（`ctx.ret` が戻っている）。
   - 引数の中の `match` の分岐の本体の `resume`（外側の節を指す）は E0509 と補助 `placeholder` になる。
3. **ガードとの重なり**: `pattern_ext.rs:165` が `ctx.clauses` を空にした後でプレースホルダがさらに `take` しても、空の列を退避して空の列を戻すだけで、ガードを出るときに元の列に戻る。二重に隠しても問題ない。ガードの中の `resume` は構文解析器が先に補助 `guard` で報告する。
4. **パイプ**: 規則 1 は直接の引数にプレースホルダがないときだけ `call(ctx, c, Some(lhs))` を呼ぶ（`generate.rs:1095-1101`）ので、左辺が差し替えた環境で検査されることはない。規則 2 は右辺の部分適用の検査で環境を戻した後に左辺を検査し、脱糖（`ir/desugar/exprs.rs` の `pipe`）も左辺を外で先に評価する。`1 |> add(return 9, _)` は 9 になる。
5. **脱糖**（`ir/desugar/exprs.rs:323-349`）: ラムダの脱糖（同 510-514）と同じ形で `conts` を空にし `return_ty` を差し替え、閉包の結果をいったん保持して戻してから `?` を適用するので、`InternalError` の経路でも戻る。型検査と同じ範囲（呼ばれる関数の式と、プレースホルダでない引数）を対象にしている。外側の継続を指す `resume` は、`conts` が空なので既存の継続の引き当てで `InternalError` になる。
6. **常に戻るかの判定**: `always_expr`（`generate.rs:817-846`）は `Call` を偽とするので、引数の中の `return` が外側の関数の戻り忘れ（E0438）を隠すことはない。`effects/tail.rs` の `escape` は引数の中の `return` を真と見るが、末尾再開の判定を保守的に倒すだけで、正しさは損なわない（補足 8 のとおり変えていない）。到達しない文の警告も出ない（`check` が警告なしで通る）。
7. **書き出しと Lean の道具**（観点 3）: `exchange.rs:1160-1189` の `return_ty` の差し替えは、呼ばれる関数の式と引数の両方に掛かり、構成子の部分適用でも Lean の `walkHoles q r`（`Walk.lean` の `partialCon`）と同じ型を使う。`placeholder_argument`・`placeholder_clause_depth` を消しても、型検査が誤って外側の継続を指す `resume` を受け付けた場合は、書き出しが外側の継続の番号を出し、Lean の `hideConts` が拒否して不一致に数えるので、見逃しにはならない。`partialReturns` と `rustTypecheckerCandidate` を外した後も、不一致はすべて `mismatched`（`requiresReview`）として終了状態を失敗にする（`Batch.lean` の `category`）。`git grep` で外した名前の残りはない（改造の文書を除く）。
8. **テスト**（観点 4）: 5 組のゴールデン、型検査の単体テスト、書き出しのテストは、いずれも直す前の実装で失敗することを実装担当が確かめている。単体テストは呼ばれる関数の式の中の `return` という、引数の側の CLI テストでは届かない境界を確かめており、重複ではない。仕様の節の印と関門のコメントがある。`unwrap` などはテストの中だけで、実装の規約に反する箇所はない。診断の文言は `diag::codes` にあり、指定の文言と一致する。

## 所見

### 1. 【中】型の合わない `return` の診断が、`return` の値ではなく呼び出し全体を指す

- 根拠: `crates/benitoite/testdata/types/todo178-placeholder-return-error.diag.json`。`add(return "escaped", _)` の診断は次の形になる。

  ```
  error[E0401]: mismatched types
   7 |   bind g <- add(return "escaped", _)
     |             ^^^^^^^^^^^^^^^^^^^^^^^^ expected `function(Integer, Integer) -> String`, found `function(Integer, Integer) -> Integer`
   3 | function add(a: Integer, b: Integer) -> Integer
     |          --- expected because of this
  ```

  展開後の戻り値の型 `ret` を先に作り、引数の `return` の `Flow` が先に `ret` を `String` に決め、その後の呼ばれる関数との `Equal`（`generate.rs` の `call_body` の `ctx.add(Constraint::Equal { expected, found: callee, .. })`）で食い違いが出るためである。読み手（主に LLM）は、`return "escaped"` が原因であることを、関数の型の差から推し量る必要がある。`try` の例（E0441）は `try` の位置を指すので、この問題はない。設計原則 4（検査と診断の明確さ）に照らすと、直す価値がある。拒否すること自体は正しく、健全性の問題ではない。
- 直し案: プレースホルダを含む呼び出しに限り、引数の個数から `params`・`expected` を作って `Equal` を加える処理を、呼ばれる関数の式を検査した直後（引数を検査する前）へ移す。こうすると `ret` が先に `Integer` に決まり、`return "escaped"` が「expected `Integer`, found `String`」として値の位置で報告される見込みである（解決器が制約を加えた順に解くことを前提にしている。確かめていない）。T2 の範囲で直さない場合は、docs/todo に項目を加え、ゴールデンの期待のファイルが今の文面を固定していることを書き添える。

### 2. 【低】ガードの中のプレースホルダの引数の `return` を、構文解析器が E0218 で拒否する（Lean は受け付ける）

- 根拠: 次の例は `E0218 "`return` cannot be used inside a match guard"` と補助 "`return` is allowed inside a lambda written there" で拒否される。

  ```
  case x if add(return 100, _)(x) > 50 -> "big"
  ```

  同じ位置のラムダの中の `return` は受け付ける。Lean の規則ではガードは `R = none`（`Typing.lean:370`）だが、`E_PartialCall` が `some r` に差し替えるので、この形は型が付く。T2 でプレースホルダの引数を「展開後のラムダの本体」として扱うことにしたので、ガードの中のプレースホルダの引数だけ構文解析器がラムダと違う扱いをするのは一貫しない。Rust の側が多く拒否する向き（保守的）で、受け付けたプログラムだけを比べる差分テストでは見つからない。`try` も同じ扱いと推測する（確かめていない）。
- 直し案: T2 の範囲外としてよい。docs/todo に項目を加え、(a) 構文解析器の E0218 の検査を、プレースホルダの引数でも型検査へ移すか、(b) 「ガードの中のプレースホルダの引数でも `return` を禁じる」と 01-02 に書いて Lean との差を明示するかを決める。

### 3. 【低】E0403・E0413 の経路では、引数を差し替えない環境で検査する

- 根拠: `generate.rs:259-264`。定数や引数のない構成子を呼んだ誤りの経路は、プレースホルダを含んでいても引数を外側の `ctx.ret`・`ctx.clauses` のまま検査する。誤りを報告して `ITy::Error` を返す経路なので結論は変わらないが、引数の中の `return` が外側の戻り値の型との食い違い（E0401）を余分に出すことがありうる。
- 直し案: 補足 3 のとおり今のままでよい。直すなら、この経路の引数の検査を、プレースホルダを含むときだけ同じ差し替えの中で行う。

### 4. 【低】`try` の誤りの注記「the function returns `Integer`」が、どの関数を指すか分かりにくい

- 根拠: `testdata/types/todo178-placeholder-try-error.diag.json`。囲む関数 `probe` は `Option[Integer]` を返すので、「the function」を `probe` と読むと注記が事実と食い違って見える。指しているのはプレースホルダが作る関数である。
- 直し案: 後の課題でよい。`try` の対象の戻り値の型がプレースホルダの展開から来たときに、補助か注記（例: "the function here is the one that the call with `_` creates"）を加える。所見 1 と合わせて docs/todo の 1 項目にしてもよい。

### 5. 【低】study.md の「現れたら書き出しの `expect` で止まる」は今の書き出しと合わない

- 根拠: `docs/2026-10-11-TODO-178_190-typecheck-and-desugar-fixes/study.md:47`。書き出しはプレースホルダの引数で継続の欄を `Ignored` にしない（ラムダの書き出し `exchange.rs:896-901` とは違う）ので、外側の継続を指す `resume` が仮に受け付けられても `expect` では止まらず、外側の継続の番号で書き出される。見逃しにならないことは「確かめたこと」7 のとおりである（Lean が拒否して不一致に数える）。
- 直し案: 書き出しを直す必要はない。改造の記録（decisions か T2 の結果）に「Lean の不一致として見つかる」と書き改めれば足りる。書き出しで止めたいなら、プレースホルダの引数を書き出す間、`env` の `Continuation` を `Ignored` に替えた写しを渡す。

## 判断

取り込んでよい。型検査・脱糖・書き出しの差し替えは同じ範囲を対象にし、誤りの経路でも復元され、Lean の `E_PartialCall`・`E_PartialCon` と一致する。入れ子、引数の中のラムダと `handle`、多相と型クラスの辞書、パイプの規則 1・2 で正しく動くことを実行して確かめた。所見 1（中）は診断の分かりやすさの問題で、T2 の中で直すか、docs/todo に項目を加えて後で直すかをオーケストレータが決めればよい。所見 2〜5（低）は後の課題か記録の直しで足りる。
