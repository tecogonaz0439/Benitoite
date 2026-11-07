import Benitoite.Release.Refinement.Surface.PredicateCalls
import Benitoite.Release.Refinement.Surface.Theorems

/-! # 判定の対象に書いたレコードの欄の解決

名前解決済みの取り出しの関数をプログラムの表と照合し、元の受け手の値と欄の観測の列を取り出す。
取り出しの関数と同名の利用者の定義は、この変換の対象にしない。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateAccessorTargets

/-- 元の表層の取り出しの関数一つと、その欄の観測の対応。 -/
structure Step where
  function : FunName
  constructor : ConName
  declaration : ConDecl
  position : Nat
  types : List Ty
  sort : «Sort»

def Step.reference (s : Step) : FieldRef :=
  ⟨s.declaration.data, s.constructor, s.position, s.sort⟩

/-- 元の呼出しの形と、同じ受け手の値からの欄の観測の対応。 -/
inductive Resolved (p : Program) : Expr → Expr → Val → Term → List Step → Prop where
  | value {source value term} : source.valueOf? = some value → value.toTerm? = some term →
      Resolved p source source value term []
  | paren {source root value term steps} : Resolved p source root value term steps →
      Resolved p (.paren source) root value term steps
  | accessor {s : Step} {labels receiver root value term steps field} :
      p.defs s.function = none → p.accessors s.function = some (s.constructor, s.position) →
      p.cons s.constructor = some s.declaration →
      s.declaration.args[s.position]? = some field → field.sort? = some s.sort →
      s.types.length = s.declaration.ntys → CallOk ["value"] 1 false labels [0] →
      Resolved p receiver root value term steps →
      Resolved p (.call (.funName s.function s.types [] []) labels [0] (.cons receiver .nil))
        root value (.field s.reference term) (steps ++ [s])

/-- 成功した解析と、そのソース・値・観測の対応の証拠。 -/
structure Parsed (p : Program) (source : Expr) where
  root : Expr
  value : Val
  term : Term
  steps : List Step
  sound : Resolved p source root value term steps

/-- 観測できる値又はそのレコードの欄の取り出しを解析する。証拠は各有限の照合から構成する。 -/
def parse (p : Program) (source : Expr) : Option (Parsed p source) :=
  match hv : source.valueOf? with
  | some value => match ht : value.toTerm? with
      | some term => some ⟨source, value, term, [], .value hv ht⟩
      | none => none
  | none => match source with
      | .paren e => do
          let result ← parse p e
          pure ⟨result.root, result.value, result.term, result.steps, .paren result.sound⟩
      | .call (.funName function types [] []) labels [0] (.cons receiver .nil) =>
          match hd : p.defs function with
          | some _ => none
          | none => match ha : p.accessors function with
              | none => none
              | some (constructor, position) => match hc : p.cons constructor with
                  | none => none
                  | some declaration => match hf : declaration.args[position]? with
                      | none => none
                      | some field => match hs : field.sort? with
                          | none => none
                          | some sort =>
                              if hn : types.length = declaration.ntys then
                                if hl : CallOk ["value"] 1 false labels [0] then do
                                  let result ← parse p receiver
                                  let step : Step := ⟨function, constructor, declaration, position, types, sort⟩
                                  pure ⟨result.root, result.value, .field step.reference result.term,
                                    result.steps ++ [step], .accessor (s := step) hd ha hc hf hs hn hl result.sound⟩
                                else none
                              else none
      | _ => none
termination_by source

/-- 解析の各照合の証拠は、同じソースについて解析の成功を示す。 -/
theorem Resolved.parse {p source root value term steps}
    (h : Resolved p source root value term steps) :
    parse p source = some ⟨root, value, term, steps, h⟩ := by
  induction h with
  | @value source value term hv ht =>
      rw [PredicateAccessorTargets.parse]
      split
      · rename_i actual ha
        have same : actual = value := Option.some.inj (ha.symm.trans hv)
        subst actual
        split
        · rename_i actualTerm hat
          have sameTerm : actualTerm = term := Option.some.inj (hat.symm.trans ht)
          subst actualTerm
          rfl
        · rename_i impossible
          rw [ht] at impossible
          cases impossible
      · rename_i impossible
        rw [hv] at impossible
        cases impossible
  | @paren source root value term steps child ih =>
      rw [PredicateAccessorTargets.parse]
      simp only
      rw [ih]
      rfl
  | @accessor step labels receiver root value term steps field hd ha hc hf hs hn hl child ih =>
      rw [PredicateAccessorTargets.parse]
      simp only
      split
      · rename_i actual impossible
        cases impossible
      · split <;> try simp_all
        all_goals try split <;> try simp_all <;> try subst_vars <;> try simp_all
        all_goals rename_i actualConstructor actualPosition actualAccessor
        all_goals obtain ⟨rfl, rfl⟩ := Prod.mk.inj (Option.some.inj (ha.symm.trans actualAccessor))
        all_goals try split <;> try simp_all <;> try subst_vars <;> try simp_all
        all_goals try split <;> try simp_all <;> try subst_vars <;> try simp_all
        all_goals try split <;> try simp_all <;> try subst_vars <;> try simp_all
        all_goals try split <;> try simp_all <;> try subst_vars <;> try simp_all
        all_goals subst_vars <;> rfl

/-- 欄の列の根には、解析時の同じ値がある。 -/
theorem Resolved.root_value {p source root value term steps}
    (h : Resolved p source root value term steps) : root.valueOf? = some value := by
  induction h with
  | value hv _ => exact hv
  | paren _ ih => exact ih
  | accessor _ _ _ _ _ _ _ _ ih => exact ih

/-- 解析の根の値は、そのソースから直接得られる。 -/
theorem Parsed.root_value {p source} (target : Parsed p source) :
    target.root.valueOf? = some target.value := target.sound.root_value

/-- 解析した各取り出しの関数の条件は、元のプログラムの整形式から供給できる。 -/
theorem Resolved.accessor_conditions {p source root value term steps}
    (h : Resolved p source root value term steps) (hw : p.WellFormed) :
    ∀ s ∈ steps, AccessorOk p.declarations s.constructor s.declaration s.position := by
  induction h with
  | value _ _ => intro s hs; cases hs
  | paren _ ih => exact ih
  | @accessor s labels receiver root value term steps field hd ha hc hf hs hn hl sub ih =>
      intro step hstep
      rcases List.mem_append.mp hstep with hstep | hstep
      · exact ih step hstep
      · have he : step = s := by simpa only [List.mem_singleton] using hstep
        subst step
        exact hw.accessors s.function s.constructor s.position ha hd s.declaration hc

/-- 解析の成功時には、列の全ての取り出しに既存の署名・パターン・網羅性の条件がある。 -/
theorem Parsed.accessor_conditions {p source} (target : Parsed p source) (hw : p.WellFormed) :
    ∀ s ∈ target.steps, AccessorOk p.declarations s.constructor s.declaration s.position :=
  target.sound.accessor_conditions hw

end Benitoite.Release.Refinement.Surface.PredicateAccessorTargets
