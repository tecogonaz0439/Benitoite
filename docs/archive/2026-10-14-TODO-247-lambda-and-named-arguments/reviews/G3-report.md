### レビューの記録

- 中: 評価順と、値をどの位置へ置くかは一般の定理で保証されていない（NamedSurface/Desugar.lean の callComp、NamedSurface/Lemmas/Calls.lean の callComp_typed・recordFields_typed）。性質 1（desugar_typed）は型の保存だけで、ソース順の let の列は定義そのもの、確かめているのは DefinitionExamples の rfl の 6 例だけ。同じ型の引数（f(a: Int, b: Int) を b:1, a:2 で呼ぶ）で値の置き場所を取り違えても型の保存は成り立つので、性質 1 では検出できない。design.md「表層の呼び出しと性質 1」は「等式は証明しない」と認めるので設計の範囲内だが、名前付き引数で新たに生じた意味の危険が型の保存の外に残る。decisions.md の R33 の理由は「callee の先行評価、ソース順の束縛…を実際の脱糖の定義に対して示せる」と書き、証明した範囲より強く述べている。修正案: CallOk のもとで「positions[k] = i なら並べた後の第 i 成分が k 番目に束縛した値（.var (n-1-k)）である」補題を加える（recordFields/fieldAt の一般の補題でもよい）。R33 の文言を「型付けを示す。順序は定義と例で確かめる」に直す（補題を加えたなら、それに合わせて正確に書く）。
- 低: 型クラスの実装の引数名の一致は Lean で表せない（ImplDecl.WellTyped、NamedSurface/Typing.lean）。実装はクラスの ms.names を引き継ぐので食い違いはモデルに現れず、Rust の検査だけが拒否する。修正案: 07-04「01-12 との対応」に対象外として記録する申し送りを plan.md の N34a（写しの作業）に書く、または交換形式で実装の名前も渡し checker が照合する（N12〜N15 の範囲でできるなら）。
- 低: 名前の整形式の一部が範囲条件に入っている（Def.Scoped の NamesWF d.coreNames …、Program.WellFormed の conFields の条件）。型付けから導けず、「%dictN は利用者の名前と衝突しない」字句の条件に頼る。修正案: formal-rules.md に、範囲条件へ置いた名前の条件の一覧と理由を書く。

問題のなかった観点: 型付けの規則（CallOk の重複・漏れ・未知・混在の拒否、一引数、パイプ、穴、構成子の関数値の名前、Ty.Le の名前の一致）、定理の強さと公理（新しい axiom・sorry・native_decide なし、desugar_typed と surface_effect_soundness は旧と同じ形）、N7 の最終定理（旧と字句まで同じ）、R30〜R34 の妥当性（R33 の文言を除く）。

## 対応

- 中（値の配置と R33）: `NamedSurface/Lemmas/Calls.lean` に型に依存しない四補題を追加し、`CallOk` のもとで `positions[k] = i` に対応する成分が `.var (n - 1 - k)` であることを挿入引数込みで証明した。decisions.md の R33・R44 と design.md・formal-rules.md で、型保存・値の配置・定義と具体例で確かめる評価順の保証を区別した。
- 低（実装メソッド名）: N12〜N16 の `MethodInput.names`、`checkImpl_contracts`・`checkProgram_contracts`、R43 の交換形式の補正で対応済み。plan.md の N34a に、射影後の型付けと射影前の checker の保証を区別して写す申し送りを追加した。
- 低（範囲条件の名前）: formal-rules.md「範囲条件に置く名前の条件」に全条件と理由、`coreNames` の非衝突を支える字句規則の境界を記し、plan.md の N34a に写しの申し送りを追加した。
