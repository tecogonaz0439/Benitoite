1. **重さ: 高 — `opPrim` が返す型引数の `AtomsIn` が、E2a-2b の健全性の前提から漏れている。**

   **場所:** [request.md:11](request.md:11) の健全性の前提、[CheckTools.lean:207](../../../../../formal/Benitoite/Surface/CheckTools.lean:207) の `tysEq_sound`、[Typing.lean:203](../../../../../formal/Benitoite/Surface/Typing.lean:203) の `E_Binary`。

   **問題:** `E_Binary` は、`opPrim (.binary o) t` から取り出した型引数 `ts` について、`ts = (Operator.binary o).typeArgs t` を要求する。この等式を `tysEq` で検査し、`tysEq_sound` で導くには、両側の `Tys.AtomsIn` が必要である。右側は注釈型 `t` の前提から得られるが、左側は得られない。`opPrim` は宣言表・組み込み表とは独立した任意の関数であり、それらの表と式の注釈・Γ・R に対する `AtomsIn` は、`opPrim` の返す型引数を制約しない。`SatDecSound` と `AdmitsDecSound` にも、その制約はない。

   具体的には、次の入力で問題が生じる。

   ```lean
   atoms := []
   t := Ty.fn [] (.base .unit) Eff.empty
   u := Ty.fn [] (.base .unit) (Eff.single "Hidden")
   opPrim := fun _ _ => some ("eq", [u])
   ```

   このとき `Ty.AtomsIn atoms t` は成り立ち、`tysEq atoms [u] ((Operator.binary .eq).typeArgs t)` は `true` を返す。しかし、要求される等式 `[u] = [t]` は偽である。有限集合の外にある `"Hidden"` を比較しないためである。この比較の成功と等式の否定は、ファイルを作らず Lean の標準入力で確認した。

   `tysEq_sound` 自体の言明は正しい。問題は、予定された検査全体の前提では、この補題の適用条件を満たせない点にある。同じ `ts` を `fnTyCheck` に渡す場合も、置換後の型に対する `AtomsIn` の導出で不足する。

   **修正案:** `opPrim` に対し、原子が集合内にある入力型から返される型引数も集合内にある、という契約を追加し、E2a-2b の健全性の前提に含める。

   ```lean
   def OpPrimAtomsIn (atoms : List Atom) (opPrim : OpPrim) : Prop :=
     ∀ op t b ts,
       Ty.AtomsIn atoms t →
       opPrim op t = some (b, ts) →
       Tys.AtomsIn atoms ts
   ```

   入力型の条件を付けることで、集合外の型を引数にした未使用の呼び出しまで制約する必要はない。具体的な演算子表についてこの契約を証明し、`E_Binary` の型引数比較と、その後の置換の原子保存に使う。有限集合上の比較が成功したことだけから、返された型引数の `AtomsIn` を導く形にはできない。

E2a-2b へは、`opPrim` の返す型引数に対する原子保存の契約を健全性の前提へ追加してから進むべきである。