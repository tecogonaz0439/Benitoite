import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.CheckMaterialsSound

/-! # 欄の関係と測度の証明書を使うプログラムの実入口 -/
namespace Benitoite.Release.Refinement.Surface.FieldCheckerExamples
open CheckTables CheckSubtyping
noncomputable section

private def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => False,
    refGet := "get", refSet := "set" }

private def field (s : «Sort») (t : Term) : Term := .field ⟨"Box", "Box", 0, s⟩ t
private def box (a : Ty) : ConDecl := ⟨"Box", 0, [a]⟩

private def definition (a : Ty) (p q : Pred) : Def where
  tparams := []
  neffs := 0
  names := ["record"]
  params := [.refined (.data "Box" []) p]
  ret := .refined a q
  eff := .empty
  body := .last (.call (.funName "Box.value" [] []) [some "value"] [0] (.cons (.local 0) .nil))

private def materials (a : Ty) (p q : Pred) : Materials where
  defs := [("project", definition a p q)]
  cons := [("Box", box a)]
  conFields := [("Box", ["value"])]
  accessors := [("Box.value", ("Box", 0))]

private def baseInput (proof : ExchangeCertificate) : Check.Input where
  D := { funs := fun _ => none, cons := fun _ => none }
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  proofSteps := 100
  logicCertificates := fun _ _ => some proof

private def acceptInput : CheckAccept.AcceptInput :=
  { ok := "Ok", rules := fun _ => none, limits := ⟨⟨100,100⟩,⟨100,100⟩⟩, methodKey := fun i m => i ++ "." ++ m }

private inductive Payload where
  | decimal | float64 | float32 | string | map | set | bytes

private def payloadType : Payload → Ty
  | .decimal => .base .decimal | .float64 => .base .float | .float32 => .base .float32
  | .string => .base .string | .map => .map (.base .unit) (.base .unit)
  | .set => .set (.base .unit) | .bytes => .bytes

private def payloadSort : Payload → «Sort»
  | .decimal => .decimal | .float64 => .float64 | .float32 => .float32
  | .string => .string | .map => .map | .set => .set | .bytes => .bytes

private def payloadAtom : Payload → Term → Pred
  | .decimal, t => .compare .decimal .ge t (.decimal 0 0)
  | .float64, t => .compare .float64 .ge t (.float64 0)
  | .float32, t => .compare .float32 .ge t (.float32 0)
  | .string, t => .charactersIn t 'a' 'z'
  | .map, t => .eq (.measure .mapSize t) (.integer 0)
  | .set, t => .eq (.measure .setSize t) (.integer 0)
  | .bytes, t => .eq (.measure .bytesLength t) (.integer 0)

private def payloadArguments : Payload → List Term
  | .decimal => [.decimal 0 0] | .float64 => [.float64 0] | .float32 => [.float32 0]
  | .string => [.character 'a', .character 'z'] | _ => []

private def payloadMaterials (x : Payload) : Materials :=
  materials (payloadType x) (payloadAtom x (field (payloadSort x) (.var 0))) (payloadAtom x (.var 0))

private def consumes : Nat → Refutation → Refutation
  | 0, proof => proof
  | n+1, proof => .consume (consumes n proof)

private def decimalRefutation : Refutation :=
  .cases
    (.cases
      (consumes 4 (.closeAtom 1 0))
      (consumes 8 (.closeAtom 3 0)))
    (consumes 10 (.closeAtom 0 5))

private def floatRefutation : Refutation :=
  .cases
    (.cases
      (.cases
        (consumes 2 (.cases
            (consumes 3 (.cases
                (consumes 1 (.closeAtom 2 0))
                (consumes 2 (.closeAtom 2 1))))
            (consumes 3 (.cases
                (consumes 1 (.closeAtom 2 0))
                (consumes 3 (.closeAtom 3 1))))))
        (.cases
          (consumes 1 (.cases
              (consumes 1 (.cases
                  (consumes 1 (.closeAtom 1 0))
                  (consumes 3 (.discardTodo (consumes 1 (.cases
                        (consumes 2 (.closeAtom 2 0))
                        (consumes 3 (.closeAtom 1 3))))))))
              (consumes 1 (.cases
                  (consumes 3 (.discardTodo (consumes 1 (.cases
                        (consumes 3 (.closeAtom 3 0))
                        (consumes 2 (.closeAtom 1 2))))))
                  (consumes 1 (.closeAtom 1 0))))))
          (.cases
            (consumes 1 (.cases
                (consumes 1 (.cases
                    (consumes 1 (.closeAtom 1 0))
                    (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                            (consumes 2 (.closeAtom 2 0))
                            (consumes 3 (.closeAtom 1 3))))))))))
                (consumes 1 (.cases
                    (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                            (consumes 3 (.closeAtom 3 0))
                            (consumes 2 (.closeAtom 1 2))))))))
                    (consumes 1 (.closeAtom 1 0))))))
            (.cases
              (consumes 1 (.cases
                  (consumes 1 (.cases
                      (consumes 1 (.closeAtom 1 0))
                      (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                                (consumes 2 (.closeAtom 2 0))
                                (consumes 3 (.closeAtom 1 3))))))))))))
                  (consumes 1 (.cases
                      (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                                (consumes 3 (.closeAtom 3 0))
                                (consumes 2 (.closeAtom 1 2))))))))))
                      (consumes 1 (.closeAtom 1 0))))))
              (.cases
                (consumes 1 (.cases
                    (consumes 1 (.cases
                        (consumes 1 (.closeAtom 1 0))
                        (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                                    (consumes 2 (.closeAtom 2 0))
                                    (consumes 3 (.closeAtom 1 3))))))))))))))
                    (consumes 1 (.cases
                        (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                                    (consumes 3 (.closeAtom 3 0))
                                    (consumes 2 (.closeAtom 1 2))))))))))))
                        (consumes 1 (.closeAtom 1 0))))))
                (.cases
                  (consumes 1 (.cases
                      (consumes 1 (.cases
                          (consumes 1 (.closeAtom 1 0))
                          (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                                        (consumes 2 (.closeAtom 2 0))
                                        (consumes 3 (.closeAtom 1 3))))))))))))))))
                      (consumes 1 (.cases
                          (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                                        (consumes 3 (.closeAtom 3 0))
                                        (consumes 2 (.closeAtom 1 2))))))))))))))
                          (consumes 1 (.closeAtom 1 0))))))
                  (.cases
                    (consumes 1 (.cases
                        (consumes 1 (.cases
                            (consumes 1 (.closeAtom 1 0))
                            (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                                            (consumes 2 (.closeAtom 2 0))
                                            (consumes 3 (.closeAtom 1 3))))))))))))))))))
                        (consumes 1 (.cases
                            (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.cases
                                            (consumes 3 (.closeAtom 3 0))
                                            (consumes 2 (.closeAtom 1 2))))))))))))))))
                            (consumes 1 (.closeAtom 1 0))))))
                    (consumes 1 (.closeAtom 0 0)))))))))
      (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 2 (.closeAtom 1 0)))))))))))))))))
    (consumes 3 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 1 (.discardTodo (consumes 4 (.closeAtom 0 3))))))))))))))))

private def stringRefutation : Refutation :=
  .cases
    (.cases
      (.cases
        (consumes 4 (.closeAtom 1 0))
        (.cases
          (.cases
            (consumes 16 (.derive (.combine [(0,1),(3,1)] ⟨[0,0,0,0,0,0,0,0],-1⟩) (.closeLinear 9)))
            (consumes 16 (.derive (.combine [(0,1),(2,1)] ⟨[0,0,0,0,0,0,0,0],-1⟩) (.closeLinear 9))))
          (.cases
            (consumes 16 (.derive (.combine [(0,1),(2,1),(3,1),(5,1)] ⟨[0,0,0,0,0,0,0,0],-1⟩) (.closeLinear 9)))
            (consumes 16 (.derive (.combine [(0,1),(2,1),(3,1),(4,1)] ⟨[0,0,0,0,0,0,0,0],-1⟩) (.closeLinear 9))))))
      (consumes 14 (.closeAtom 6 0)))
    (consumes 16 (.closeAtom 0 8))

private def measureRefutation : Refutation :=
  consumes 13 (.cases
      (consumes 1 (.derive (.combine [(1,1),(3,1),(4,1),(5,1),(6,1)] ⟨[0,0,0,0,0],-1⟩) (.closeLinear 7)))
      (consumes 1 (.derive (.combine [(0,1),(2,1),(4,1),(5,1),(6,1)] ⟨[0,0,0,0,0],-1⟩) (.closeLinear 7))))

private def payloadLeaf (x : Payload) : PreparedLeaf :=
  let a := Term.var 0
  let b := field (payloadSort x) (.var 1)
  let clause := BuiltinSchema.implies (.and (fieldRelation (payloadSort x) [] none a b) (payloadAtom x b)) (payloadAtom x a)
  match x with
  | .map | .set | .bytes => ⟨.truth, .closed, [], []⟩
  | _ => ⟨clause, .fieldAtom (payloadSort x) [], a :: b :: payloadArguments x, []⟩

private def payloadRefutation : Payload → Refutation
  | .decimal => decimalRefutation | .float64 | .float32 => floatRefutation
  | .string => stringRefutation | .map | .set | .bytes => measureRefutation

private def payloadProof (x : Payload) : ExchangeCertificate :=
  ⟨.refute (.builtin (payloadLeaf x) (payloadRefutation x)), []⟩

private def payloadInput (x : Payload) : Check.Input :=
  (payloadMaterials x).input (baseInput (payloadProof x))

/-- 七種類の取り出しの本体を、型付けと必須の判定の実入口で検査する。 -/
private def Checked (x : Payload) : Prop :=
  checkProgram (payloadInput x) (payloadMaterials x).program = .ok () ∧
  CheckAccept.checkProgramAccepted (payloadInput x) acceptInput (payloadMaterials x).program = .ok ()

/-- Decimal の順序を、取り出しの結果の戻り値の契約へ移す。 -/
theorem decimal_program_checked : Checked .decimal := by cbv

/-- IEEE の比較を変えずに Float64 の欄の順序を移す。 -/
theorem float64_program_checked : Checked .float64 := by cbv

/-- Float32 の欄も同じ実入口から順序の契約を検査する。 -/
theorem float32_program_checked : Checked .float32 := by cbv

/-- String の全文字の範囲を、取り出した String の契約へ移す。 -/
theorem string_program_checked : Checked .string := by cbv

/-- Map の欄の大きさを、取り出した値の大きさの契約へ移す。 -/
theorem map_program_checked : Checked .map := by cbv

/-- Set の欄の大きさを、取り出した値の大きさの契約へ移す。 -/
theorem set_program_checked : Checked .set := by cbv

/-- Bytes の欄の大きさを、取り出した値の大きさの契約へ移す。 -/
theorem bytes_program_checked : Checked .bytes := by cbv

private theorem input_sound (x : Payload) (p q : Pred) (proof : ExchangeCertificate) :
    ((materials (payloadType x) p q).input (baseInput proof)).Sound := by
  apply Materials.input_sound
  · intro c cd h
    change (if "Box" = c then some (box (payloadType x)) else none) = some cd at h
    split at h
    · cases h; cases x <;> trivial
    · cases h
  · refine ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩
    · intro i id h; cases h
    · intro f fd h
      change ((materials (payloadType x) p q).program.lookupFun Def.toFunDecl (@accessorDecl) testerDecl f).or none = some fd at h
      simp only [Program.lookupFun] at h
      split at h
      · rename_i d hd
        change (if "project" = f then some (definition (payloadType x) p q) else none) = some d at hd
        split at hd
        · cases hd; cases h
          cases x <;> repeat' first | exact Check.empty_effect_support _ | apply And.intro | trivial
        · cases hd
      · split at h
        · rename_i c k ha
          change (if "Box.value" = f then some ("Box", 0) else none) = some (c,k) at ha
          split at ha
          · cases ha
            simp only [materials, Materials.program, lookup, box, ite_true, Option.or_none] at h
            cases h
            cases x <;> repeat' first | exact Check.empty_effect_support _ | apply And.intro | trivial
          · cases ha
        · cases h
    · intro b sg h; cases h
    · intro o od h; cases h
    · intro c cd m ms hc hm; cases hc
    · intro f d h; cases h
  · intro C a p h; cases h
  · intro b sg C ts h; cases h
  · intro b rs h; cases h
  · intro o t b ts h; cases h

private theorem definitions_support (x : Payload) (p q : Pred) (proof : ExchangeCertificate) :
    ∀ n d, (materials (payloadType x) p q).program.defs n = some d →
      CheckDeclarations.DefSupport ((materials (payloadType x) p q).input (baseInput proof)) d := by
  intro n d h
  change (if "project" = n then some (definition (payloadType x) p q) else none) = some d at h
  split at h
  · cases h
    constructor
    · cases x <;> repeat' first | exact Check.empty_effect_support _ | apply And.intro | trivial
    · exact ⟨⟨trivial, (by intro e he; cases he), CheckArguments.rangeSupport_nil _⟩, ⟨trivial, trivial⟩⟩
  · cases h

private theorem checked_typed (x : Payload) (h : Checked x) :
    (payloadMaterials x).program.WellTyped builtins (fun _ _ => none) ∧
    CheckAccept.Accepted acceptInput (payloadInput x) (payloadMaterials x).program :=
  Materials.checkProgramAccepted_empty (input_sound x _ _ _) (definitions_support x _ _ _)
    (by intro i id hi; cases hi) rfl rfl h.2

/-- 同じ受理の成功を、表の有限支持と全件性の証人から型付けへ接続する。 -/
theorem field_programs_typed :
    (payloadMaterials .decimal).program.WellTyped builtins (fun _ _ => none) ∧
    (payloadMaterials .float64).program.WellTyped builtins (fun _ _ => none) ∧
    (payloadMaterials .float32).program.WellTyped builtins (fun _ _ => none) ∧
    (payloadMaterials .string).program.WellTyped builtins (fun _ _ => none) ∧
    (payloadMaterials .map).program.WellTyped builtins (fun _ _ => none) ∧
    (payloadMaterials .set).program.WellTyped builtins (fun _ _ => none) ∧
    (payloadMaterials .bytes).program.WellTyped builtins (fun _ _ => none) :=
  ⟨(checked_typed _ decimal_program_checked).1, (checked_typed _ float64_program_checked).1,
   (checked_typed _ float32_program_checked).1, (checked_typed _ string_program_checked).1,
   (checked_typed _ map_program_checked).1, (checked_typed _ set_program_checked).1,
   (checked_typed _ bytes_program_checked).1⟩

private def partialSnapshot : Payload → Term
  | .map => .mapValue [none] [none] | .set => .setValue [none]
  | .bytes => .bytesValue [256] | _ => .unitValue

private def payloadMeasure : Payload → Measure
  | .map => .mapSize | .set => .setSize | _ => .bytesLength

private def measuredGoal (x : Payload) : Pred :=
  let t := partialSnapshot x
  .eq (.measure (payloadMeasure x) (field (payloadSort x) (.dataValue "Box" [some t])))
    (.measure (payloadMeasure x) t)

private def measuredLeaf (x : Payload) : PreparedLeaf :=
  let t := partialSnapshot x
  ⟨measuredGoal x, .measured, [field (payloadSort x) (.dataValue "Box" [some t]), t], []⟩

private def measuredMaterials (x : Payload) : Materials :=
  materials (payloadType x) .truth (measuredGoal x)

private def measuredInput (x : Payload) : Check.Input :=
  (measuredMaterials x).input (baseInput ⟨.leaf (measuredLeaf x), []⟩)

private def MeasuredChecked (x : Payload) : Prop :=
  (measuredGoal x).evalClosed = none ∧
  checkProgram (measuredInput x) (measuredMaterials x).program = .ok () ∧
  CheckAccept.checkProgramAccepted (measuredInput x) acceptInput (measuredMaterials x).program = .ok () ∧
  (checkProgram ((measuredMaterials x).input (baseInput
    ⟨.leaf {measuredLeaf x with lemma := .closed}, []⟩)) (measuredMaterials x).program).toBool = false

/-- Map の鍵の観測が欠けても、同じ閉じた欄の測度を結ぶ葉を再検査する。 -/
theorem measured_map_program_checked : MeasuredChecked .map := by cbv

/-- Set の要素の観測が欠ける場合も、部分評価に頼らず同じ測度を結ぶ。 -/
theorem measured_set_program_checked : MeasuredChecked .set := by cbv

/-- 不適格な Bytes の観測でも、測度の全域整数射影の一致だけを使う。 -/
theorem measured_bytes_program_checked : MeasuredChecked .bytes := by cbv

/-- 閉じた観測の葉を使う三つの受理も、同じ健全性から型付けを得る。 -/
theorem measured_programs_typed :
    (measuredMaterials .map).program.WellTyped builtins (fun _ _ => none) ∧
    (measuredMaterials .set).program.WellTyped builtins (fun _ _ => none) ∧
    (measuredMaterials .bytes).program.WellTyped builtins (fun _ _ => none) := by
  have typed (x : Payload) (h : MeasuredChecked x) :=
    Materials.checkProgramAccepted_empty (input_sound x _ _ _) (definitions_support x _ _ _)
      (by intro i id hi; cases hi) rfl rfl h.2.2.1
  exact ⟨(typed _ measured_map_program_checked).1, (typed _ measured_set_program_checked).1,
    (typed _ measured_bytes_program_checked).1⟩

private def memberAtom (t : Term) : Pred := .member .path t .top
private def memberMaterials : Materials :=
  materials (.base .string) (memberAtom (field .string (.var 0))) (memberAtom (.var 0))
private def memberLeaf : PreparedLeaf :=
  let a := Term.var 0
  let b := field .string (.var 1)
  ⟨BuiltinSchema.implies (.and (fieldRelation .string [] none a b) (memberAtom b)) (memberAtom a),
    .fieldAtom .string [], [a,b], []⟩

/-- String の所属を移す未登録の葉は、実入口でも拒否される。 -/
theorem string_member_program_rejected :
    CheckFormation.annotation (memberMaterials.input (baseInput ⟨.use 0,[]⟩)).formation
      memberMaterials.declarations.core [] [] []
      (.dependentFn (definition (.base .string) (memberAtom (field .string (.var 0))) (memberAtom (.var 0))).toFunDecl.tel) = true ∧
    (memberAtom (field .string (.var 0))).interpret
      (fun _ => some (.dataValue "Box" [some (.string "/")])) = true ∧
    memberLeaf.checkRaw [] = false ∧
    (checkProgram (memberMaterials.input (baseInput ⟨.refute (.builtin memberLeaf (.closeAtom 0 0)),[]⟩)) memberMaterials.program).toBool = false ∧
    (CheckAccept.checkProgramAccepted (memberMaterials.input (baseInput ⟨.refute (.builtin memberLeaf (.closeAtom 0 0)),[]⟩))
      acceptInput memberMaterials.program).toBool = false := by cbv

private def decimalBad : Term := .decimal 0 29
private def decimalRepresentationMaterials : Materials :=
  materials (.base .decimal)
    (.and (.compare .decimal .eq (field .decimal (.var 0)) decimalBad)
      (.decimalRepresented (field .decimal (.var 0))))
    (.decimalRepresented decimalBad)
private def decimalRepresentationLeaf : PreparedLeaf :=
  let t := field .decimal (.var 1)
  ⟨BuiltinSchema.implies (.and (fieldRelation .decimal [] none t decimalBad) (.decimalRepresented t))
      (.decimalRepresented decimalBad), .fieldAtom .decimal [], [t,decimalBad], []⟩

/-- 数値等号から表現可能性を移す偽の葉は、署名の形成が通る本体でも拒否する。 -/
theorem decimal_representation_program_rejected :
    CheckFormation.annotation (decimalRepresentationMaterials.input (baseInput ⟨.use 0,[]⟩)).formation
      decimalRepresentationMaterials.declarations.core [] [] []
      (.dependentFn (definition (.base .decimal)
        (.and (.compare .decimal .eq (field .decimal (.var 0)) decimalBad)
          (.decimalRepresented (field .decimal (.var 0)))) (.decimalRepresented decimalBad)).toFunDecl.tel) = true ∧
    (Pred.and (.compare .decimal .eq (field .decimal (.var 0)) decimalBad)
      (.decimalRepresented (field .decimal (.var 0)))).interpret
        (fun _ => some (.dataValue "Box" [some (.decimal 0 0)])) = true ∧
    (Pred.decimalRepresented decimalBad).evalClosed = some false ∧
    decimalRepresentationLeaf.checkRaw [] = false ∧
    (checkProgram (decimalRepresentationMaterials.input (baseInput ⟨.refute (.builtin decimalRepresentationLeaf (.closeAtom 0 0)),[]⟩))
      decimalRepresentationMaterials.program).toBool = false ∧
    (CheckAccept.checkProgramAccepted
      (decimalRepresentationMaterials.input (baseInput ⟨.refute (.builtin decimalRepresentationLeaf (.closeAtom 0 0)),[]⟩))
      acceptInput decimalRepresentationMaterials.program).toBool = false := by cbv

/-- 閉性・成功した観測・観測の一致をそれぞれ欠く葉は、測度の既定値が一致しても拒否する。 -/
theorem measured_leaves_rejected :
    (PreparedLeaf.checkRaw [] ⟨.eq (.measure .mapSize (.var 0)) (.measure .mapSize (.var 0)),
      .measured, [.var 0,.var 0], []⟩) = false ∧
    (PreparedLeaf.checkRaw [] ⟨.eq (.measure .mapSize (field .map (.dataValue "Box" [])))
      (.measure .mapSize (field .map (.dataValue "Box" []))), .measured,
      [field .map (.dataValue "Box" []),field .map (.dataValue "Box" [])], []⟩) = false ∧
    (PreparedLeaf.checkRaw [] ⟨.eq (.measure .mapSize (.mapValue [none] [none]))
      (.measure .mapSize (.mapValue [none,none] [none,none])), .measured,
      [.mapValue [none] [none], .mapValue [none,none] [none,none]], []⟩) = false := by decide

end
end Benitoite.Release.Refinement.Surface.FieldCheckerExamples
