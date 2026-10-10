# C5a-1 の定義のレビュー結果（Opus）

レビュー担当: Claude Code の Opus 5.5（medium）。

性質 1 を偽にする反例は見つからなかった。残った 3 か所の `sorry` は、どれも今の定義のまま証明できる見込みである（`E_FunDicts` は `Ty.subst ts es` と `Ty.subst ts []` が `.dict cl (.tvar n)` の上で定義から等しく、辞書を `hideConts Γ` の下へ移して `HasTypeV.rename` と `boundVars_typed` を組み合わせれば足りる。`E_MethName` は `take ++ drop` の再結合で C-Meth の前提になる。D-Impl は指摘 3 の補題を足せば閉じる）。観点 2・3 で 01-06・01-12 と意味が違う誤りは見つからなかった。指摘は中が 2 件、低が 4 件で、高はない。

## 指摘

### 1. `E_MethName` の Ū の分け方が型付けで決まらない

- 重さ: 中
- 場所: `formal/Benitoite/Surface/Typing.lean:73-79`
- 問題: 01-12 の表の第 2 行では、Ū はメソッド自身の制約の辞書のすべて、Ā は値の引数の型だけである。表層の規則は `us.length` で分ける位置を自由に選べるので、自身の制約の辞書の一部をラムダの引数（型 `Dict[…]`）に回す形にも型が付く。性質 1 は広い側で成り立つので偽にならないが、C5a-2 の直接の呼び出しでは Ū とパイプで挿入した引数の境界が型付けで決まらず、C5c の差分テストの前提（Ū は全部）も表層の規則が保証しない。
- 原因の分類: 表現の都合（`Release.MethSig` が自身の制約の個数を持たない）
- 直し方の案: (a) 前提に「値の引数の型の先頭は辞書の型でない」を足す（表層の値の引数は `Dict` 型を書けないので、分ける位置が自身の制約の個数に決まる）、(b) 表層の `Declarations` にメソッドごとの自身の制約の個数の表を置く、(c) 広さを認めて 01-12 に書き足す、のどれか。C5a-2 の前に決める。

### 2. ADR 0312 の制限を外した版の計画の見込み

- 重さ: 中（計画の記述の妥当性）
- 場所: `docs/2026-10-10-TODO-162-desugar-formalization-phase2/plan.md:64`
- 問題: P6 と、メソッド自身の制約の辞書を `ms.params` の先頭の `.dict` 型で表す今回の方式を操作に当てはめ、`OpDecl.params` の先頭に `.dict cl (.tvar i)` を置けば、`HasTypeClauses` は `binds sg.params` で辞書を節の Γ に束縛し、`V_Op` も辞書を含む全引数の関数型を与える。このため (b)「辞書を値の引数の前に渡す脱糖」は、`Release` の `OpDecl`・`V_Op`・`HasTypeClauses` を変えずに通る見込みが高く、直すのは表層の `opName`・節の `arity`・C5a-2 の呼び出しの頭だけになる。計画の「`Release` と合わせて直す必要がある」は言い過ぎの可能性がある。(a)「辞書を渡さない脱糖」の抜けは、証明が止まる前に、節の中で操作の型パラメータの制約から辞書を得る `DictEv` の構成子に `toVal` の行き先がない、という定義の段で現れそうである。
- 原因の分類: その他（計画の見込み）
- 直し方の案: plan.md の (b) を「`Release` を変えずに、`OpDecl.params` の先頭に辞書の型を置く案をまず試す」に改め、(a) の記録では抜けが定義の段で現れることを書く。C5a-2 で呼び出しの頭を一般化するとき、操作の頭にも辞書の列を持たせられる形にしておく。

### 3. D-Impl の証明に要る補題

- 重さ: 低（証明の見込みの補足）
- 場所: `formal/Benitoite/Surface/Lemmas/Program.lean:59`、`Lemmas/Invariants.lean:29`（`subst_clean`）
- 問題: D-Impl で `HasBlock.desugar` を使うには、環境 `binds (id.dictTys.map (Ty.shift g 0) ++ ms.params.map (id.methTy ms))` の `EnvClean (g+b)` と、`methTy ms ms.ret` の `TyOK (g+b)` が要る。`methTy` は `Ty.substAt g [target] []` だが、既存の `subst_clean` は置き換えの位置が 0 の場合だけで、位置 g での置き換えについて `VarsIn` を保つ補題がない。
- 原因の分類: 表現の都合
- 直し方の案: C5b-1 で `substAt_clean`（位置 c 一般）を足す（`shift_clean` は C4b-2 の `ShiftClean.lean` にある）。

### 4. 新しい規則に型付けの導出の例がない

- 重さ: 低
- 場所: `formal/Benitoite/Surface/Examples.lean:957-1088`
- 問題: `DictEv.HasType`、`E_FunDicts`、`E_MethName`、`ImplDecl.WellTyped` に型付けの導出の例がなく、規則の前提が満たせない誤りを例で検出できない。`meth_value_row` は `combine` に型引数と Ū を与えるが、同じファイルの `c5Class` の `combine` は型パラメータも自身の制約も持たないので、型の付く例と誤解しやすい。
- 原因の分類: その他
- 直し方の案: `c5Impl.WellTyped`、`choose` を値として使う `E_MethName`（Ū は `Show` の辞書 1 個）、`renderPair` を値として使う `E_FunDicts` の導出の例を足し、`meth_value_row` は `choose` を使う形に直すか、脱糖だけの例と断る。

### 5. `Desugar.lean` のコメントの不正確さ

- 重さ: 低
- 場所: `formal/Benitoite/Surface/Desugar.lean:57`
- 問題: 「辞書の自由変数を値引数の個数だけずらす（Rust dictionary_lambda と同じ）」は不正確である。処理系は名前の付いた変数を使うのでずらす操作はなく、ずらすのは de Bruijn の番号の都合である。意味の一致は正しい。
- 原因の分類: 書き写しの誤り（コメント）
- 直し方の案: 「処理系は名前の変数なのでずらさない。de Bruijn の番号ではラムダの引数の下へ移すのでずらす（意味は dictionary_lambda と同じ）」とする。

### 6. `Dict` 型の値を普通の値として扱える広さと、01-12 への反映

- 重さ: 低
- 場所: `Syntax.lean`（`FunDecl.params`、`Expr.local`）、01-12「型の情報を付けた表層の構文と型付け」
- 問題: 表層の構文と型付けは、値の引数の型に `.dict` を持つ関数や、`Dict` 型の局所変数を値として返す・渡す形を許す。01-06 の利用者はこれらを書けないが、`Release` が型を付けるので性質 1 は偽にならない。01-12 の同節は、まだ辞書の根拠・`funDicts`・`methName`・実装の表を含まない。
- 原因の分類: 表現の都合
- 直し方の案: C5 を設計書へ反映するとき、同節の情報の列挙に辞書の根拠と二つの値として使う形を加え、広さの列挙に `Dict` 型の値を普通の値として扱えること（と、指摘 1 を直さない場合は Ū の分け方）を加える。

## 観点ごとのまとめ

1. 脱糖の各場合と 01-12・処理系の一致: 問題なし（コメントの不正確さは指摘 5）。ラムダの中で辞書の値の番号を値の引数の個数だけずらし、`Comp.meth` の引数は Ū・値の引数の順、制約を持つ関数の定義は `params := dictTys ++ params`、実装のメソッドの本体は `.tail`、上位の型クラスの辞書は `toVal` で移す。
2. 表層の型付けの規則: 指摘 1。`DictEv` の型付けは V-Dict・V-Super の写しとして正しい。`E_Fun` と `E_FunDicts` は `dictParams = []` と `≠ []` で分かれる。実装の定義の型付けは `Release.ImplDecl.WellTyped` と 01-06 に合う。表の条件の振り分けは妥当。
3. 構文と規則の過不足: 指摘 6。
4. 性質 1 の反例: なし。補足は指摘 3。
5. 後の作業の妨げ: 指摘 1 のとおり、C5a-2 の前に Ū の分け方を決める。`funDicts`・`methName` が値の引数の型の注釈を持つことは、直接の呼び出しにしても矛盾しない。C5a-2 では、`directCallee : Expr → Option Val` が `.meth` の頭を表せないので頭の型を一般化し、`callComp_typed` を呼ぶ関数の型の前半に辞書の型を置く形に一般化する必要がある。高カインドの型を妨げる制限は加わっていない。
6. ADR 0312 の制限を外した版: 指摘 2。
