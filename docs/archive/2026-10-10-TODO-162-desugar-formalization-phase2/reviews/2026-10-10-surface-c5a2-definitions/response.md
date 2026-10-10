# C5a-2 の定義と証明のレビュー結果（Opus）

レビュー担当: Claude Code の Opus 5.5（medium）。

`lake build` は成功した（67 jobs）。`formal/Benitoite/Surface` に `sorry`・`admit`・`native_decide` はない。`Theorems.lean`・表層の `Typing.lean`・`Syntax.lean`・`Release`・`Core` は 6738ad7 から変わっていない。重さが高の指摘はない。

## 指摘

### 1. 01-12 の型クラスの表の 3 行目の書き方の不足と、Lean の「食い違い」の注記

- 重さ: 低（設計書へ反映するときに必ず直す）
- 場所: `formal/Benitoite/Surface/Desugar.lean` 39–40 行（`CallHead.apply` の docstring）、113–114 行（`.call` の注記）。01-12「型クラス」の表の第 3 行。
- 問題: 01-12 の第 3 行は「決めた辞書を、値の引数の前に並べて渡す」とだけ書く。Lean はその具体形として `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in f[T̄; Ē](Ū, x1, …, xn)` を出し、頭を変数に束縛しない。意味は 01-12 と矛盾しないが、Lean に「01-12 との食い違い」の注記が残る。01-12 には、括弧で包んだ `(f)`・`(Cl.m)` が第 2・4 行の値の形（ラムダ）を経て「そのほかの呼び出し」になることも書かれていない。
- 原因の分類: 01-12 の規則の誤り（書き方が足りない）
- 直し方の案: 01-12 の第 3 行を `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in f[T̄; Ē](Ū, x1, …, xn)`（Ū は決めた辞書。頭は束縛しない）に改め、表の下に「パイプとプレースホルダで展開した呼び出しの頭が裸の名前なら第 1・3 行に、括弧で囲んだ名前なら第 2・4 行の値を呼ぶ『そのほかの呼び出し』に移す」を加える。そのうえで Lean の 2 か所の「食い違い」の注記を消し、`CallHead.apply` の docstring を「`.app` は 01-12『呼び出し』の直接の呼び出しと型クラス第 3 行」とする（`.app` の分岐は辞書が空の `funName`・`primName`・`opName` にも使われる）。

### 2. `Ty.Le` を深い部分型に広げたときの `meth` の頭の前提

- 重さ: 低（後の段階の見込み）
- 場所: `formal/Benitoite/Surface/Lemmas/Calls.lean` 20–28 行（`CallHead.HasType.meth` の前提 `ms.params.map … = utys ++ as`）、`Lemmas/CallHead.lean` 128・137 行（`Ty.Le.fn_fn'`）
- 問題: 頭の型付けは、逆転で得る `Ty.Le` から引数の型と戻り値の型が等しいことを得ている。今の `Ty.Le` は最も外側の関数型のエフェクトだけを広げるので正しいが、`Ty.Le` を深い部分型に広げると `meth` の等式の前提が作れなくなる（`app` は `V_Sub` で吸収できる）。今回の定理は弱まっていない。
- 原因の分類: 表現の都合
- 直し方の案: 今は直さない。`Ty.Le` を広げる改造が来たときに、`meth` の前提を C-Meth の型を `Ty.Le` で広げた型に変える。そのことを `CallHead.HasType` のコメントに一行残す。

### 3. C5c-2 への申し送り

- 重さ: 低
- 場所: `crates/benitoite/tests/desugar_export/exchange.rs` 1045–1047 行（`App.dicts` を対象外にしている）、1102 行（`Method` を対象外にしている）、353 行
- 問題: 直接の呼び出しを比べる対象に入れるとき、表現の写し方として次が要る（Rust 側の組み立ての順は Lean と一致している）。(1) `App { func, dicts, args }` を `.app func (dicts ++ args)` へ連結する。(2) `MethodCall` は `name_dicts` の先頭が受け手 V、残りが Ū。`targs.tys` は先頭の τ を除いて ss にし（`dicts.rs` 145 行の `skip(1)`）、`method: index` をメソッドの名前へ写す。(3) `DictVal` を `.dict`・`.var`・`.super` へ写し、辞書の引数の変数を `dictTys ++ params` の順の番号に合わせる。(4) 値の形のラムダでは、Rust は辞書を名前の変数で参照し、Lean はラムダの引数の個数だけずらす（変数の番号への変換で吸収できる）。(5) メソッドと実装の型パラメータの番号を並べ替える。正規化が要る構造の違い（let の有無など）は見当たらない。
- 原因の分類: 表現の都合
- 直し方の案: 上の 1〜5 を C5c-2 の依頼文に写す。生成器の形式化用の設定に、括弧で包んだ頭・パイプの規則 1 と 2・プレースホルダ・プレースホルダのパイプを、辞書付きの名前で入れる。

### 4. 括弧で包んだ頭へのパイプの規則 1 の例がない

- 重さ: 低（例の抜け）
- 場所: `formal/Benitoite/Surface/Examples.lean` 1259 行以降
- 問題: `x |> (render)(a)`（`.pipe lhs (.call (.paren (.funDicts …)) args)`）の例がない。`callComp` の `none` の分岐で、callee を shift だけずらし、挿入引数を `ms.length + 1` だけずらす経路である。証明は一般の形で済んでいるが、期待値を目で確かめる例として欠けている。
- 原因の分類: その他
- 直し方の案: `fun_dicts_paren_pipe_call_row` のような `rfl` の例を一つ加える。

## 観点ごとの結論

1. 01-12・処理系との一致: 問題なし（01-12 の書き方の不足は指摘 1）。辞書・挿入引数・引数の変数の順、頭の辞書を `shift + ms.length`・挿入引数を `ms.length` だけずらすこと、括弧で包んだ頭を値の形のままにすること、プレースホルダのパイプ（外側はラムダを束縛し、本体は直接の頭）は、処理系の `prepare`・`invoke`・`method`・`pipe`・`placeholder` と一致し、例でも確かめた。
2. 型付けと脱糖の食い違い、逆転の補題の一般さ: 問題なし。`inv_funDicts`・`inv_methName` は式と型を一般化した `HasType.rec` で証明され、`E_Sub` の連鎖は `Ty.Le` の推移律、エフェクトの包含は `weakenEff` と `Eff.Sub` で扱う。表層で直接の頭になるのは裸の名前だけで、`E_Paren` を経る導出は `directCallee = none` に落ちる。
3. 後の段階の妨げ: 問題なし（見込みは指摘 2）。`directCallee_typed` の、`.ret v` に脱糖する閉じた名前を `inv_ret` で受ける共通の枝に、C6 のフィールドを取り出す関数が乗る。定数は `none` のままにすれば済む。`callComp_typed` の頭の前提はすべての `ys` について量化した「ずらした後」の形で、`CallHead.HasType.rename` は一般の `RenOk` を受けるので C7 にも使える。削除した二つの補題で失われる用途はない。
4. 性質 1 の言明: 問題なし。二つの定理の言明と前提は変わらず、呼び出し元が新たに使うのは手元にある表層の導出だけである。
5. C5c-2 の正規化: 指摘 3 のとおり。
6. ADR 0312 の制限を外した版への備え: 問題なし。`CallHead.app (.op o ts) ds` の `apply` は `.app (.op o ts) (ds ++ args)` になり、`OpDecl.params` の先頭に辞書の型を置く案と `V_Op`・`CallHead.HasType.app` の `dtys ++ as` でつながる。その版では、`opName` に辞書の欄を加えること、値の形を `funDicts` と同じラムダにすること、頭の型付けを `inv_ret` から `inv_funDicts` のような逆転へ移すことが要る。
