# W3（6d1ee5ef）のレビュー

対象: `git show 6d1ee5ef`。作業ディレクトリ・ビルドには触れず、コミットの内容だけを読んだ。行番号は 6d1ee5ef の時点のもの。

## 重大

### 1. R18 の `pair_failure` が、返す式の内側の制約まで宣言の位置へ移す（`float_literal_help` の退行）

- 場所: `crates/benitoite/src/typeck/solve.rs` 955〜978 行（`pair_failure`）。呼び出し元は 880・913・938・943 行。
- 原因: `return value * 2`（`-> Float`）で、`binary_constraints`（`generate.rs` 529 行〜）は結果の型変数 `t` を作り、二つの被演算子を `Equal { expected: t, found: 被演算子, reason: Operands }`（手順 2、`int_literal` 付き）で結ぶ。`return_expr`（1241 行〜）の流れ込む制約は `from = t` で手順 1 に解かれ、`flow` の `_` の分岐（`solve.rs` 487〜493 行）が `declared[root(t)] = Return の理由` を記録する。手順 2 で `Equal(t, Integer)`（被演算子 `2`）が失敗すると、`pair_failure` は `expected` が `ITy::Var(t)` で根が `declared` にあるので、失敗の理由を問わず `late` に回す。結果、主な位置が `2` から `value * 2` 全体へ移り、注記が `because_operands` から `because_return` に替わり、`r.int_literal` を持たない Return の理由で報告するので `float_literal` の修正案（`2.0`）が消えた。
- 判定の仕組みが「失敗した側の型変数の根が手順 1 で決まったか」だけで、失敗した制約が返す式のどこに由来するかを見ていない。`return s` で直したい食い違い（束縛のパターンの `Equal`、`generate.rs` 1349 行）は返す式の外にあり、退行した食い違い（被演算子）は返す式の内側にある。
- 同じ一般化で悪くなる形（いずれも返す式の型そのものが型変数で、その変数を内側の部分式と `Equal`・`Flow` で結ぶもの）:
  - 二項演算の被演算子（`Operands`、`int_literal` 付き）。`return value * 2` の退行そのもの。`return a + 1`（`a: String`）の `to_string` の help も、理由が `Operands { Add }` でなくなるので消える。
  - `if` の分岐（`IfBranches`、`generate.rs` 638・662 行。662 行は `int_literal` 付き）。`-> Float` の `return if c then value else 2 end if` で、`2` の位置と `2.0` の help を失う。
  - `match` の分岐（`MatchArms`、1220 行）。分岐の本体の位置を失い、`return` の式全体を指す。
  - `bind x: Float <- value * 2` も同じ。`BindAnnotation` は `declared` 付きの流れ込み（1330 行）なので、被演算子の失敗が注釈の理由（`value * 2` 全体、`because_bind_annotation`）へ移り、`2.0` の help を失う。
  - 影響しない形: リストのリテラル（`List[β]` は `ITy::Var` でないので `declared` に記録されない）、`return 2`（`from` が `Integer` で、Flow 自身の失敗として元の理由と `int_literal` で報告）、レコードの構築（各フィールドは `CallArg` の非宣言の流れ込みで、返す式の型は構成子の戻り値の型）。呼び出しの戻り値（FE403）は `call_return` が先に処理する。
  - 今のゴールデンで変わったのは `float_literal_help` だけだが、上の形はゴールデンも単体テストもないので、退行が検出されていない。
- 直し方の案（規則）: **失敗した制約の理由の位置が、`declared` に記録した理由の位置（`return` の式、`bind` の右辺）の内側にあるときは、元の理由のまま報告する。外側にあるときだけ、宣言への流れ込みの位置へ移す。** 内側の制約は返す式の部分式（被演算子・分岐・パターンの照合の対象）を指し、元の理由のほうが位置が細かく、`int_literal` や `to_string` の help を持つ。外側の制約は、その変数を定義した束縛（`return s` の f・g・h）か、別の場所での使用であり、手順 1 の狙い（宣言に合わない側を誤りにする）に合わせて宣言の位置で示す。

  ```rust
  fn pair_failure(&mut self, ctx, code, expected, found, reason) {
      if reason.priority != Priority::Declared && code == DiagCode::E0401 {
          for (declared, other) in [(expected, found), (found, expected)] {
              if let ITy::Var(v) = declared {
                  let root = self.root(*v).0;
                  if let Some(r) = self.declared.get(&root).cloned()
                      && !within(reason.span, r.span)   // 返す式の内側は元の理由のまま
                  {
                      if self.redirected.insert(root) {  // 中の 1 を参照
                          self.late.push((code, declared.clone(), other.clone(), r));
                      }
                      return;
                  }
              }
          }
      }
      self.failure(ctx, code, expected, found, reason);
  }
  // within(a, b): a.file == b.file && a.start >= b.start && a.end <= b.end
  ```

  Return の理由の位置は `flow` の `reason(e.span(), kind)` で `e.value` の span、BindAnnotation は `bind.value` の span なので、そのまま比べられる。f・g・h はパターンの位置（2 行目）が `return s` の `s`（3 行目）の外なので今のまま移る。`float_literal_help` は `2` が `value * 2` の内側なので元に戻る（ゴールデンを 6d1ee5ef~1 の内容へ戻す）。
- テスト: `returned_binding_mismatch_uses_the_declared_return_reason`（`typeck/tests.rs` 487 行）に、内側に残す場合を足す。少なくとも (a) `-> Float` の `return value * 2` が `2` を指し `2.0` の置き換えを持つこと、(b) `bind x: Float <- value * 2` も同じこと、(c) `-> Float` の `return if c then value else 2 end if` が `2` を指すこと。`float_literal_help` のゴールデンは戻す。
- 設計書: 02-05 の追加の段落（「制約の解決の手順 1 で宣言の型への流れ込む制約が決めた型変数について…」）に、「失敗した制約の位置が宣言の流れ込む式の内側にあるときは、元の理由で報告する」を足し、理由（部分式の位置と修正案を保つため）を添える。CHANGELOG の文は直した後も合う。

## 中

### 1. 宣言の位置へ移した報告が、同じ位置に同じ文で重なる

- 場所: `solve.rs` 955〜978 行。`late` は重複を除かず、`failure` も E0401 では型を誤りにしない（poison は E0208 だけ。617〜627 行）。
- 例（机上。再現テストで確かめる）:

  ```text
  function f() -> Unit
    bind s <- Integer.toString(1)
    bind n <- String.length(s)
    return s
  ```

  パターンの `Equal(String, α)` と、`String.length(s)` の引数の流れ込み（`from = α`）の両方が、根 `α` の記録で `late` に積まれ、`return s` の位置に「expected `Unit`, found `String`」が 2 件出る。変更前は位置の違う 2 件（束縛と引数）だった。中の規則（内側か外側か）を入れても、どちらも外側なので重なりは残る。
- 直し方: `Solver` に移した根の集合（例 `redirected: BTreeSet<u32>`）を持ち、同じ根の 2 件目以降は報告しない（上の案の `self.redirected.insert(root)`）。同じ根の後続の失敗は、`return` を直せば消える同じ原因の連鎖である。`Solver` の欄は `declared`・`late` と同じく凍結した 10-05 の外であることを確かめる。上の例を `typeck/tests.rs` に足し、E0401 が 1 件であることを確かめる。

### 2. E0303 の構築の help が、利用者のモジュールの場合に誤った形を示す

- 場所: `resolve/lookup.rs` 673〜681 行（`record_binding`）と 604〜614 行。テスト `resolve/tests.rs` の `("Geometry", "G")` の場合。
- 問題: `import Geometry as G` とモジュール `Geometry` の `public record Geometry` で `G.new(1, 2)` と書くと、help は `` `G(z: ..., a: ...)` `` を示す。しかし `G` はモジュールの束縛であり、`final_name`（783 行〜）の `type_in_module` は prelude と標準ライブラリのモジュールだけを同じ名前の型へ読み替える（145〜155 行）。利用者のモジュールでは `G(z: 1, a: 2)` の `G` は `Position::Record` で受け入れられず、E0304（`G` is a module, not a record）になる。help を当てると別の誤りになり、テストがその形を固定している。
- 直し方: `record_binding` がモジュールを経てレコードを見つけたときは、示す名前を `{参照に書いた段}.{レコードの名前}`（例 `G.Geometry(z: ..., a: ...)`）にする。`as_module` が標準ライブラリの型を兼ねるモジュールを返した場合（`type_in_module` が引ける場合）だけ、書いた段のままでよい。テストの期待を直し、可能なら help の形を名前解決に通して E0304・E0303 が出ないことを確かめる。02-04 の「参照に書いた修飾名を使い」も合わせて直す。

### 3. E0304 の構築の help が、構成子のパターンにも出る

- 場所: `resolve/lookup.rs` 275〜280 行。`Position::Ctor` は `resolve/shadow.rs` 175 行の構成子のパターンだけが使う（式の `Point(1, 2)` は `Position::Value`）。
- 問題: `case Point(x, y) ->` や `bind Point(x, y) <- p` で E0304（`Point` is a record, not a constructor）に「build a record with its field names, such as `Point(z: ..., a: ...)`」が付く。パターンでは値を作らないので「build」は誤った案内であり、判断 R6 も「値や呼び出しの位置」としている。事前点検の補足が `Position::Ctor` を挙げたことの誤りでもある。
- 直し方: 条件を `Position::Value` だけにする。パターンにも案内を出すなら、別の鍵（例 `match_record: "match a record with its field names, such as `{record}({fields})`"`、フィールドは `z: _, a: _` か `..` の形）にする。どちらにするかを決め、パターンの場合をテストに足す。02-04・02-10 の表の「値か構成子として書いた」の記述も合わせる。

### 4. 退行を見逃したテストの穴（R18）

- `returned_binding_mismatch_uses_the_declared_return_reason` は移す場合だけを確かめ、移さない場合（返す式の内側、`bind` の注釈の内側、重なり）を確かめていない。実装者は `float_literal_help` の変化を「意図した一般化の結果」と扱って作り直した。test-audit の作成時の関門の観点では、一般化した規則には「当てない場合」の境界のテストが要る。重大の 1 と中の 1 のテストを足す。

## 軽微

### 1. `if`・`match` を最後の文にした本体への `return ` の挿入を確かめていない

- 場所: `solve.rs` 776〜806 行。`body_end` は最後の文が `if … end if` ならその式を返し、型が戻り値と等しければ `return ` を挿入する。`return if c then … end if`（複数行のブロックの形）が構文として受け入れられるかを、`help_tests.rs` の `type_repairs_pass_typechecking_when_applied` に 1 件足して確かめる。受け入れられないなら、ブロックの形の式には置き換えを付けず文だけにする。

### 2. 型を書いていないラムダの `return` の置き換えが、戻り値の型がすでに決まっていても付く

- 場所: `solve.rs` 789 行（`!body.annotated || …`）。注釈のないラムダでも、`function() -> Unit` の引数に渡すなどで戻り値の型が解決時に `Unit` に決まっていれば、`return ` を当てると別の E0401 になる。R2 は両方に置き換えを付けると決めたので判断どおりではあるが、`zonk(&body.ty)` が型変数でなく `found` と違うときは文だけにする余地がある。設計者に確かめるか、docs/todo の項目にする。

### 3. コメントの規約

- `solve.rs` 955〜956 行の `pair_failure` のコメントは「（設計書 02-05）」で節の名前がない。AGENTS.md の「コメントと名前」は `（設計書 02-05「誤りの報告と検査の継続」）` の形を求める。
- `typeck/context.rs` の `Body` の `return_owner`・`try_owners`（68〜69 行）には `///` がない（隣の欄にはある）。`typeck/text.rs` の `FUNCTION`・`LAMBDA` も同じ。何のための欄かを一行で書く。

### 4. E0201 の判定

- `syntax/parser/exprs.rs` 652〜660 行の「直前の字句が名前」の判定と、669 行〜の括弧の数え方（`[` と `(` を同じ深さで数える）は、計画どおりで誤検出の形は見つからなかった。直前が改行の `[`（行頭のリスト）は対象外になる。`xs[0]` に「use `List.get`」を含む同じ help が出るのは判断どおり。指摘はない。

## 計画・判断との対応（確かめた点）

- R1: `body_end`（`generate.rs` 935 行）で E0416・E0438 の位置を最後の式文にし、`reported_body_values` で E0438、`lambda_body_ends` で `LambdaReturn` の E0401 を抑える。FnBody の制約が LambdaReturn より先に加わるので順も合う。`final_expression_reports_once_at_the_expression` が `expect` で診断の全体を確かめており、重なりの抑止も検出できる。
- R2: `-> Integer` の最後の `y * 2` に `return ` の挿入（当てると `return_expr` が新しい型変数を返すので FnBody の比較が通り、`always_block` で E0438 も出ない）。`-> Integer` の最後の `x = 5` は文だけと `reassign`。`help_tests.rs` が各置き換えを当てて型検査まで通すことを確かめている。`bind _ <- bind y <- …` の誤った置き換えは消えた。
- R19: 持ち主の差し替えと復元は、プレースホルダの呼び出し（`generate.rs` 251・259 行）とラムダ（695・697 行）で対になっている。`call_body` が誤りでも戻る作りで、復元は漏れない。両方向の入れ子をテストしている。ハンドラの節・`with` は `ret` を替えないので持ち主を替えないことと合う。
- R6・R7: 優先順（prelude の復元 → import → 構築 → 旧名と別名 → 既存）は W1W3 の補足どおり。`Pair` と無関係の名前に出ないことをテストしている。E0201 の 4 件の既存ゴールデンは変わっていない。
- 設計書・CHANGELOG・生成物: 02-03・02-04・02-05・02-10 と `skill/references/diagnostics.md` は実装と合う。ただし 02-05 の R18 の段落は重大の 1 の直しに合わせて条件を足し、02-04 の「参照に書いた修飾名を使い」は中の 2 に合わせて直す。
- AGENTS.md の規約: `unwrap`・添字・`as` の新しい使用は本番のコードにない（`saturating_*` と `get` で書いている）。`#[cold]`・`#[inline(never)]` を誤りの経路に付けている。凍結した `ReasonKind`・`Reason`・`Constraint` と AST は変えていない。
