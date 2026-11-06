import Benitoite.Release.Refinement.Surface.Theorems
import Benitoite.Release.Refinement.CertificateEntails
import Benitoite.Release.Refinement.Surface.CheckMaterials

/-! # record 全体の篩から射影の結果への事実の移送 -/
namespace Benitoite.Release.Refinement.Surface.FieldProjectionExamples
noncomputable section

private def box (a : Ty) : ConDecl := ⟨"Box",0,[a]⟩
private def field (s : «Sort») (t : Term) : Term := .field ⟨"Box","Box",0,s⟩ t

/-- 全体の篩を持つ受け手の文脈で、実際の射影の結果型を必要な篩へ狭められる。 -/
private def Projection (a : Ty) (cs : List ConName) (p q : Pred) : Prop :=
  ∀ P, Ty.LeQ P [some (.refined (.data "Box" []) p)] []
    (accessorRet "Box" (box a) 0 cs) (.refined (accessorBase (box a) 0) q)

private theorem project {a : Ty} {cs : List ConName} {p q : Pred}
    (observed : accessorObserved (box a) 0 cs = true)
    (atom : p.conjuncts = [p])
    (hs : (accessorPred "Box" (box a) 0 cs).Sorted [some (.refined (.data "Box" []) p)]
      (some (accessorBase (box a) 0)))
    (hq : q.Sorted [some (.refined (.data "Box" []) p)] (some (accessorBase (box a) 0)))
    (transfer : Entails [accessorPred "Box" (box a) 0 cs, Pred.lift (p.open (.var 0))] q) :
    Projection a cs p q := by
  intro P
  unfold accessorRet
  rw [ite_eq_left observed]
  apply Ty.LeQ.refine .refl hs hq
  apply transfer.cut
  intro r hr
  rcases List.mem_cons.mp hr with rfl | hr
  · exact .hyp List.mem_cons_self
  · cases List.mem_singleton.mp hr
    apply Entails.hyp
    apply List.mem_cons_of_mem
    apply List.mem_append_right
    apply List.mem_map.mpr
    refine ⟨_,List.mem_append_left _ ?_,rfl⟩
    simp [Ctx.facts, Ty.assume, Ty.core, Ty.carrierFacts, Ty.refinementPredicates, atom]

private theorem integer_transfer (a b : Term) :
    Entails [.eq a b, .eq b (.integer 7)] (.eq a (.integer 7)) := by
  have h := EqProof.substitute_entails
    (Φ := [.eq a b, .eq b (.integer 7)])
    (p := .eq (.var 0) (.integer 7)) (t := b) (u := a) (mode := .integer)
    (eq := .symm (.hyp 0))
    (by simp [EqProof.checkRaw,termEq_spec])
    (by decide) (by simpa [Pred.open, predBind, termBind, termBind?] using
      (Entails.hyp (List.mem_cons_of_mem _ List.mem_cons_self) :
        Entails [.eq a b,.eq b (.integer 7)] (.eq b (.integer 7))))
  simpa [Pred.open, predBind, termBind, termBind?] using h

private theorem implication_elim {Φ : List Pred} {p q : Pred}
    (hi : Entails Φ (BuiltinSchema.implies p q)) (hp : Entails Φ p) : Entails Φ q := by
  apply Entails.or_elim hi
  · exact .false_elim (.not_elim (hp.weaken (fun _ => List.mem_cons_of_mem _)) (.hyp List.mem_cons_self))
  · exact .hyp List.mem_cons_self

private theorem scalar_transfer {s : «Sort»}
    (hs : s ∈ orderedScalarSorts ∨ s ∈ equalityScalarSorts) (a b c : Term) :
    Entails [.compare s .eq a b, .compare s .eq b c] (.compare s .eq a c) := by
  have hm : BuiltinSchema.scalarOrder s .eqTrans a b c ∈ BuiltinSchema.candidates .scalarOrder [a,b,c] := by
    rcases hs with hs | hs
    · apply List.mem_append_left
      exact List.mem_flatMap.mpr ⟨s,hs,List.mem_map.mpr ⟨.eqTrans,by simp [BuiltinSchema.scalarRules],rfl⟩⟩
    · apply List.mem_append_right
      exact List.mem_flatMap.mpr ⟨s,hs,List.mem_map.mpr ⟨.eqTrans,by simp [BuiltinSchema.equalityRules],rfl⟩⟩
  have hl := PreparedLeaf.raw_entails (Φ := [.compare s .eq a b,.compare s .eq b c])
    (l := ⟨BuiltinSchema.scalarOrder s .eqTrans a b c,.scalarOrder,[a,b,c],[]⟩)
    (by
      simp only [PreparedLeaf.checkRaw, List.isEmpty_nil, Bool.true_and]
      exact List.any_eq_true.mpr ⟨_,hm,(predEq_spec _ _).mpr rfl⟩)
  exact implication_elim hl (.and_intro (.hyp List.mem_cons_self)
    (.hyp (List.mem_cons_of_mem _ List.mem_cons_self)))

private theorem float_transfer (w : FloatWidth) (c : FloatClass) (a b : Term) :
    Entails [floatFieldRelation w a b, .floatClass w c b] (.floatClass w c a) := by
  apply Entails.fieldAtom (.reverse (.floatClass (cs := []) w c))
  · cases w <;> exact .hyp List.mem_cons_self
  · exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

local macro "projection_sorted" : tactic => `(tactic|
  simp [accessorRet, accessorObserved, accessorPred, accessorMeasure, accessorSort, accessorBase, accessorRef,
    fieldRelation, floatFieldRelation, predicateIff, constructorFieldRelation, box, field,
    Pred.Sorted, Term.HasSort, Term.References, Term.Shape, Term.VarsIn, Ctx.Readable,
    Ty.HasSort, Ty.sort?, Ty.shiftV, Comparison.Allowed, Measure.input, Measure.output])

local macro "projection_fact" " using " t:term : tactic => `(tactic|
  simpa [accessorPred, accessorMeasure, accessorSort, accessorBase, accessorRef,
    fieldRelation, box, field, Ty.shiftV, Ty.sort?, Pred.lift, Pred.shiftV, Pred.open, predBind, termBind, termBind?] using $t)

theorem integer_projection :
    Projection (.base .integer) [] (.eq (field .integer (.var 0)) (.integer 7))
      (.eq (.var 0) (.integer 7)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · projection_fact using (integer_transfer (.var 0) (field .integer (.var 1)))

theorem character_projection :
    Projection (.base .character) [] (.compare .character .eq (field .character (.var 0)) (.character 'a'))
      (.compare .character .eq (.var 0) (.character 'a')) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · have h := scalar_transfer (s := .character) (by simp [orderedScalarSorts])
      (.var 0) (field .character (.var 1)) (.character 'a')
    apply h.cut
    intro r hr
    rcases List.mem_cons.mp hr with rfl | hr
    · exact .and_left (.hyp List.mem_cons_self)
    · cases List.mem_singleton.mp hr
      exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

theorem float64_projection (c : FloatClass) :
    Projection (.base .float) [] (.floatClass .binary64 c (field .float64 (.var 0)))
      (.floatClass .binary64 c (.var 0)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · projection_fact using (float_transfer .binary64 c (.var 0) (field .float64 (.var 1)))

theorem float32_projection (c : FloatClass) :
    Projection (.base .float32) [] (.floatClass .binary32 c (field .float32 (.var 0)))
      (.floatClass .binary32 c (.var 0)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · projection_fact using (float_transfer .binary32 c (.var 0) (field .float32 (.var 1)))

theorem decimal_projection :
    Projection (.base .decimal) [] (.compare .decimal .eq (field .decimal (.var 0)) (.decimal 12 1))
      (.compare .decimal .eq (.var 0) (.decimal 12 1)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · have h := scalar_transfer (s := .decimal) (by simp [orderedScalarSorts, equalityScalarSorts])
      (.var 0) (field .decimal (.var 1)) (.decimal 12 1)
    apply h.cut
    intro r hr
    rcases List.mem_cons.mp hr with rfl | hr
    · exact .hyp List.mem_cons_self
    · cases List.mem_singleton.mp hr
      exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

theorem boolean_projection :
    Projection (.base .boolean) [] (.compare .boolean .eq (field .boolean (.var 0)) (.boolean true))
      (.compare .boolean .eq (.var 0) (.boolean true)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · have h := scalar_transfer (s := .boolean) (by simp [orderedScalarSorts, equalityScalarSorts])
      (.var 0) (field .boolean (.var 1)) (.boolean true)
    apply h.cut
    intro r hr
    rcases List.mem_cons.mp hr with rfl | hr
    · exact .hyp List.mem_cons_self
    · cases List.mem_singleton.mp hr
      exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

theorem string_projection :
    Projection (.base .string) [] (.compare .string .eq (field .string (.var 0)) (.string "abc"))
      (.compare .string .eq (.var 0) (.string "abc")) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · have h := scalar_transfer (s := .string) (by simp [orderedScalarSorts, equalityScalarSorts])
      (.var 0) (field .string (.var 1)) (.string "abc")
    apply h.cut
    intro r hr
    rcases List.mem_cons.mp hr with rfl | hr
    · exact .and_left (.hyp List.mem_cons_self)
    · cases List.mem_singleton.mp hr
      exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

theorem unit_projection :
    Projection (.base .unit) [] (.compare .unit .eq (field .unit (.var 0)) (.unitValue))
      (.compare .unit .eq (.var 0) (.unitValue)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · have h := scalar_transfer (s := .unit) (by simp [orderedScalarSorts, equalityScalarSorts])
      (.var 0) (field .unit (.var 1)) (.unitValue)
    apply h.cut
    intro r hr
    rcases List.mem_cons.mp hr with rfl | hr
    · exact .hyp List.mem_cons_self
    · cases List.mem_singleton.mp hr
      exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

private theorem measurement_transfer {a : Ty} {s : «Sort»} {m : Measure}
    (hm : Pred.eq (.measure m (.var 0)) (.measure m (field s (.var 1))) ∈
      (accessorPred "Box" (box a) 0).conjuncts) :
    Entails [accessorPred "Box" (box a) 0,
      Pred.lift ((Pred.eq (.measure m (field s (.var 0))) (.integer 7)).open (.var 0))]
      (.eq (.measure m (.var 0)) (.integer 7)) := by
  apply (integer_transfer (.measure m (.var 0)) (.measure m (field s (.var 1)))).cut
  intro r hr
  rcases List.mem_cons.mp hr with rfl | hr
  · exact (show Entails _ (accessorPred "Box" (box a) 0) from .hyp List.mem_cons_self).conjuncts _ hm
  · cases List.mem_singleton.mp hr
    exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

theorem stringBytes_projection :
    Projection (.base .string) [] (.eq (.measure .stringBytes (field .string (.var 0))) (.integer 7))
      (.eq (.measure .stringBytes (.var 0)) (.integer 7)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply measurement_transfer
    simp [accessorPred, accessorMeasure, accessorSort, accessorBase, accessorRef,
      fieldRelation, box, field, Ty.shiftV, Ty.sort?, Pred.conjuncts]

theorem stringCharacters_projection :
    Projection (.base .string) [] (.eq (.measure .stringCharacters (field .string (.var 0))) (.integer 7))
      (.eq (.measure .stringCharacters (.var 0)) (.integer 7)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply measurement_transfer
    simp [accessorPred, accessorMeasure, accessorSort, accessorBase, accessorRef,
      fieldRelation, box, field, Ty.shiftV, Ty.sort?, Pred.conjuncts]

theorem listLength_projection :
    Projection (.list (.base .unit)) [] (.eq (.measure .listLength (field .list (.var 0))) (.integer 7))
      (.eq (.measure .listLength (.var 0)) (.integer 7)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply measurement_transfer
    simp [accessorPred, accessorMeasure, accessorSort, accessorBase, accessorRef,
      fieldRelation, box, field, Ty.shiftV, Ty.sort?, Pred.conjuncts]

theorem bytesLength_projection :
    Projection (.bytes) [] (.eq (.measure .bytesLength (field .bytes (.var 0))) (.integer 7))
      (.eq (.measure .bytesLength (.var 0)) (.integer 7)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply measurement_transfer
    simp [accessorPred, accessorMeasure, accessorSort, accessorBase, accessorRef,
      fieldRelation, box, field, Ty.shiftV, Ty.sort?, Pred.conjuncts]

theorem mapSize_projection :
    Projection (.map (.base .integer) (.base .unit)) [] (.eq (.measure .mapSize (field .map (.var 0))) (.integer 7))
      (.eq (.measure .mapSize (.var 0)) (.integer 7)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply measurement_transfer
    simp [accessorPred, accessorMeasure, accessorSort, accessorBase, accessorRef,
      fieldRelation, box, field, Ty.shiftV, Ty.sort?, Pred.conjuncts]

theorem setSize_projection :
    Projection (.set (.base .integer)) [] (.eq (.measure .setSize (field .set (.var 0))) (.integer 7))
      (.eq (.measure .setSize (.var 0)) (.integer 7)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply measurement_transfer
    simp [accessorPred, accessorMeasure, accessorSort, accessorBase, accessorRef,
      fieldRelation, box, field, Ty.shiftV, Ty.sort?, Pred.conjuncts]

theorem characterCode_projection :
    Projection (.base .character) [] (.eq (.measure .characterCode (field .character (.var 0))) (.integer 7))
      (.eq (.measure .characterCode (.var 0)) (.integer 7)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply measurement_transfer
    simp [accessorPred, accessorMeasure, accessorSort, accessorBase, accessorRef,
      fieldRelation, box, field, Ty.shiftV, Ty.sort?, Pred.conjuncts]

theorem data_projection (c : ConName) (hc : c ∈ ["Color.Red","Color.Blue"]) :
    Projection (.data "Color" []) ["Color.Red","Color.Blue"] (.constructorIs (field .data (.var 0)) c)
      (.constructorIs (.var 0) c) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply Entails.fieldAtom (.reverse (.constructorIs c hc))
    · exact .hyp List.mem_cons_self
    · exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

private def colorProgram : Program where
  defs := fun _ => none
  cons := fun c =>
    if c = "Box" then some (box (.data "Color" []))
    else if c = "Color.Red" ∨ c = "Color.Blue" then some ⟨"Color",0,[]⟩ else none
  dataConstructors := fun d => if d = "Color" then ["Color.Red","Color.Blue"] else []
  accessors := fun f => if f = "Box.color" then some ("Box",0) else none

/-- 有限の宣言材料は同じ構成子列をプログラムと形成の入力へ供給する。 -/
theorem material_inventory (m : CheckTables.Materials) :
    m.program.dataConstructors = m.constructors ∧
      CheckFormation.CtorsComplete m.program.declarations.core m.program.dataConstructors := by
  exact ⟨rfl,m.constructors_complete⟩

/-- lookupFun と脱糖が実際に読む有限列から、二構成子の関係を結果型に生成する。 -/
theorem data_inventory_lookup :
    ((colorProgram.declarations.funs "Box.color").map FunDecl.ret) =
      some (.refined (.data "Color" [])
        (constructorFieldRelation ["Color.Red","Color.Blue"] (.var 0) (field .data (.var 1)))) := by
  rfl

/-- 実際の Character の結果型を自己型にしても、Integer の比較の篩は形成できない。 -/
theorem character_result_rejects_integer :
    ¬ (Pred.le (.var 0) (.integer 0)).Sorted [some (.data "Box" [])]
      (some (accessorRet "Box" (box (.base .character)) 0)) := by
  projection_sorted

theorem measurement_sort_mismatch :
    ¬ FieldRelation.Valid .string [] (some .characterCode) := by decide

/-- 実際の Unit の結果型は、data の構成子判定の篩を形成できない。 -/
theorem unit_result_rejects_constructor :
    ¬ (Pred.constructorIs (.var 0) "Color.Red").Sorted [some (.data "Box" [])]
      (some (accessorRet "Box" (box (.base .unit)) 0)) := by
  projection_sorted

/-- Map の測度が観測不能でも、同じ観測の整数射影を結ぶ閉じた導出は健全である。 -/
theorem partial_map_measure :
    let a : Term := .mapValue [none] [some .unitValue]
    let b : Term := field .map (.dataValue "Box" [some a])
    Entails [] (.eq (.measure .mapSize a) (.measure .mapSize b)) ∧
      (Pred.eq (.measure .mapSize a) (.measure .mapSize b)).evalClosed = none := by
  constructor
  · exact .measured (by trivial) (by trivial) rfl rfl
  · simp [Pred.evalClosed, Pred.WF, Pred.VarsIn, Pred.Sorted, Term.HasSort, Term.References,
      Term.Shape, Term.VarsIn, Measure.input, Measure.output, Pred.evalWith, Pred.atomReady,
      termReady, Term.observe, Observation.measure, mapKeys, mapKeys.go, observeSlots, field, Observation.sort]

/-- 対象の所属を有限列へ置き換えず、基の型を返す。 -/
theorem target_result (k : Scope.Domain.Kind) :
    accessorRet "Box" (box (.scoped "Target" k (.fixed .top))) 0 =
      (Ty.scoped "Target" k (.fixed .top)).shiftV 1 0 := by
  rfl

/-- Decimal の全比較を、全体の篩から実際の結果型へ移す。ge は a >= 0 の例である。 -/
theorem decimal_order_projection (o : Comparison) :
    Projection (.base .decimal) [] (.compare .decimal o (field .decimal (.var 0)) (.decimal 0 0))
      (.compare .decimal o (.var 0) (.decimal 0 0)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply Entails.fieldAtom (.reverse (.compareLeft (by simp [FieldRelation.Scalar]) o (.decimal 0 0)))
    · exact .hyp List.mem_cons_self
    · exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

/-- 両幅の Float について、NaN と符号付きゼロを除かず全比較を移す。 -/
theorem float64_order_projection (o : Comparison) :
    Projection (.base .float) [] (.compare .float64 o (field .float64 (.var 0)) (.float64 0))
      (.compare .float64 o (.var 0) (.float64 0)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply Entails.fieldAtom (.reverse (.compareLeft (by simp [FieldRelation.Scalar]) o (.float64 0)))
    · exact .hyp List.mem_cons_self
    · exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

theorem float32_order_projection (o : Comparison) :
    Projection (.base .float32) [] (.compare .float32 o (field .float32 (.var 0)) (.float32 0))
      (.compare .float32 o (.var 0) (.float32 0)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply Entails.fieldAtom (.reverse (.compareLeft (by simp [FieldRelation.Scalar]) o (.float32 0)))
    · exact .hyp List.mem_cons_self
    · exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

/-- 比較の右辺にある Character の欄も、同じ原子の右辺へ移す。 -/
theorem character_order_projection (o : Comparison) :
    Projection (.base .character) [] (.compare .character o (.character 'a') (field .character (.var 0)))
      (.compare .character o (.character 'a') (.var 0)) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply Entails.fieldAtom (.reverse (.compareRight (by simp [FieldRelation.Scalar]) o (.character 'a')))
    · exact .hyp List.mem_cons_self
    · exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

/-- 全文字が指定した範囲に入る事実を、実際の String の結果型へ移す。 -/
theorem charactersIn_projection (lo hi : Char) :
    Projection (.base .string) [] (.charactersIn (field .string (.var 0)) lo hi)
      (.charactersIn (.var 0) lo hi) := by
  apply project rfl rfl
  · projection_sorted
  · projection_sorted
  · apply Entails.fieldAtom (.reverse (.charactersIn lo hi))
    · exact .hyp List.mem_cons_self
    · exact .hyp (List.mem_cons_of_mem _ List.mem_cons_self)

/-- 関係と両方の原子の形成が合っても、数値等号は Decimal の表現可能性を保存しない。 -/
theorem decimal_representation_not_preserved :
    (fieldRelation .decimal [] none (.decimal 0 0) (.decimal 0 29)).interpret (fun _ => none) = true ∧
    (Pred.decimalRepresented (.decimal 0 0)).interpret (fun _ => none) = true ∧
    (Pred.decimalRepresented (.decimal 0 29)).interpret (fun _ => none) = false := by decide

/-- 全域モデルの String への既定値は、member が読む元の観測を同定しない。 -/
theorem string_member_not_preserved :
    (fieldRelation .string [] none (.var 0) (.string "")).interpret (fun _ => none) = true ∧
    (Pred.member .path (.var 0) .top).interpret (fun _ => none) = true ∧
    (Pred.member .path (.string "") .top).interpret (fun _ => none) = false := by decide

/-- 有限列に含まれない構成子は、関係が真でも区別できない。 -/
theorem unlisted_constructor_not_preserved :
    (fieldRelation .data ["Other"] none (.dataValue "A" []) (.dataValue "B" [])).interpret
      (fun _ => none) = true ∧
    (Pred.constructorIs (.dataValue "A" []) "A").interpret (fun _ => none) = true ∧
    (Pred.constructorIs (.dataValue "B" []) "A").interpret (fun _ => none) = false := by decide

/-- data の構成子が等しくても、内部の欄の値は保存しない。 -/
theorem data_field_content_not_preserved :
    (fieldRelation .data ["Box"] none
      (.dataValue "Box" [some (.integer 0)]) (.dataValue "Box" [some (.integer 1)])).interpret
      (fun _ => none) = true ∧
    (Pred.eq (field .integer (.dataValue "Box" [some (.integer 0)])) (.integer 0)).interpret
      (fun _ => none) = true ∧
    (Pred.eq (field .integer (.dataValue "Box" [some (.integer 1)])) (.integer 0)).interpret
      (fun _ => none) = false := by decide

end
end Benitoite.Release.Refinement.Surface.FieldProjectionExamples
