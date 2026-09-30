1. **重さ: 高 — `Examples.builtins` は `Builtins.Assumptions` を満たせず、提示された型クラスの実行例に定理を適用できない。**

   **場所:** `formal/Benitoite/Release/Examples.lean` 18–21 行・25–35 行、`formal/Benitoite/Release/Assumptions.lean` 49–50 行、`formal/Benitoite/Release/Typing.lean` 81–82 行。

   **問題:** 例の組み込みの関数の型は、すべて `admits := fun _ _ => True` を持つ。一方、`Builtins.Assumptions.admits_sat` は、`s.admits C ts` が成り立つすべての型引数の並びについて、`SatAll B C ts s.tparams` を要求する。`SatAll` は制約の充足に加え、型引数と型パラメータの個数の一致を要求するため、この二つは矛盾する。

   例えば、`b := "add"`、`C := []`、`ts := [intTy]` とする。`builtins.sig "add" = some s` と `s.admits [] [intTy]` は成り立つので、`admits_sat` から次を得る。

   ```lean
   SatAll builtins [] [intTy] []
   ```

   その第一条件は `1 = 0` である。したがって、任意の `P` について、`Examples.builtins.Assumptions P` は満たせない。`V_Prim` が別に個数を検査することでは解消しない。`admits_sat` 自身には、個数が一致するという前提がないためである。

   `SemigroupInt`・`MonoidInt`・`SemigroupBox` の宣言と本体には、`program.WellFormed`・`program.WellTyped builtins`・`program.EffectsOk builtins` を妨げる箇所は見えない。しかし、共通の前提である `builtins.Assumptions program` が満たせないため、235–246 行の型クラスの例は、定理の前提を満たすプログラムの例にはなっていない。`exec … = … := by decide` は `run` の計算結果を確かめるだけなので、この矛盾を検出しない。

   この指摘は `Examples.builtins` に関するものである。一般の `Builtins.Assumptions` が矛盾することや、型クラスを含むすべてのプログラムについて定理が空虚になることを示すものではない。

   **原因の分類:** その他（実行例の組み込みの関数の定義と、定理の仮定との不整合）。

   **直し方の案:** 例の `sig` の `admits` に、型引数の個数の一致を含める。現在の例は `sat := True` なので、次の形で足りる。

   ```lean
   admits := fun _ ts => ts.length = tps.length
   ```

   そのうえで、例の `builtins.Assumptions program` と、`program.WellFormed`・`program.WellTyped builtins`・`program.EffectsOk builtins` を明示的に言明する。型クラスの呼び出しにも型付けの言明を置けば、実行結果だけでなく、定理を適用できる例であることを検査できる。今回の問題を直すために、`Builtins.Assumptions` を弱める必要はない。

2. **重さ: 低 — 「次の二つ」と、その後の列挙の個数が一致していない。**

   **場所:** `docs/design/07-quality/07-04-formal-semantics.md`「形式化で仮定するもの」の「次の二つは、仮定ではなく定理の前提として言明する」と、その直後の箇条書き（提示資料に行番号なし）。

   **問題:** 箇条書きは三つあり、それぞれ `Program.WellTyped`・`Program.WellFormed`・`Program.EffectsOk` に対応する。説明の個数だけが、形式化の前提と一致していない。

   **原因の分類:** その他（説明の表記）。

   **直し方の案:** 「次の三つ」に改めるか、「次の条件」に改める。

問題なし — 前回の対応 1：`Theorems.lean` 32–33 行の `progress` に `P.WellTyped B` を加えたことは妥当である。型の付いた定義の集まり Σ を前提とする性質 2 に対応し、D-Impl から E-Meth・E-Super に必要な本体と辞書の存在を得られる。

問題なし — 前回の対応 2：`Syntax.lean` 275–285 行の `(ClassName × Nat)` と `dictTys`、`WellFormed.lean` 125–127 行の番号の範囲の条件は、辞書の引数を `Dict[Cl', β']` に限定する。高カインドの型パラメータも `.tvar` で表すため、この変更によって高カインドの辞書の引数が排除されることはない。

問題なし — 前回の対応 3：`Typing.lean` 390–391 行の `isSome` の等式は、メソッドと上位の辞書について宣言と実装の域の一致を表す。392–397 行の存在・型付けの条件と合わせて、必要な定義の欠落と余分な定義の両方を排除し、`ImplDecl.Scoped` のメソッド本体の検査も全本体を対象にする。

問題なし — 型クラスを含むプログラムについての前提の充足可能性：`Model.assumptions` は任意の `P` に対して成り立つ。例えば `Model.builtins` のもとで、上位の型クラスを持たず、`m() : Integer ! {}` とその本体 `return 0` を持つ型クラスと実装だけからなるプログラムは、`WellFormed`・`WellTyped`・`EffectsOk` を同時に満たせる。型クラスの実装を持つこと自体で前提が矛盾する箇所はない。

問題なし — `SemigroupBox` の本体：`Examples.lean` 89–95 行の二段の照合の後では、番号 4 が辞書、番号 1 と 0 が取り出した二つの中身を指す。各 `Box` の照合は `Inhabits` に対して網羅的であり、`letIn` の後の番号 0 を `Box[T]` に包む型付けも成立する。

問題なし — 定理の言明：`Theorems.lean` 39–53 行の `preservation` と `effect_soundness` は、B2 の追加によって結論を弱めていない。エフェクトの健全性は、到達した各状態からのすべての事象付き遷移を排除し、未処理の利用者の操作も排除する形を保っている。

問題なし — 07-04 と B2 の定義との対応：上記の列挙の個数を除き、辞書の引数の表現、実装の域の一致、型の番号付け、種類の検査を省く範囲、コレクションの表現、E-Super の遷移としての扱いは、提示された定義と一致している。

問題なし — その他の空虚性・意味の相違：提示資料からは、指摘 1 以外に、前提の矛盾や型クラスについて定理を空虚にする具体例は見えない。辞書の置き換え、メソッドの引数の並び、E-Super の一歩の取り出しにも、01-12 および ADR 0305 と異なる箇所は見えない。