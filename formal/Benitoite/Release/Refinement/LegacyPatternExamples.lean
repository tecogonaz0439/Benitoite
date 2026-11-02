import Benitoite.Release.Refinement.LegacyPatternCoverage

namespace Benitoite.Release.Refinement
noncomputable section

namespace LegacyPatternExamples

def kinds : DeclarationKinds := ⟨fun _ => .value,fun _ => [],fun _ _ => []⟩
def atDecl : Benitoite.Release.ConDecl := ⟨"Scope.ScopeError",0,List.replicate 7 (.base .string)⟩
def unitOperation : Benitoite.Release.OpDecl :=
  ⟨"UnitEffect",[],[],[],.base .unit,[]⟩
def oldProgram : Benitoite.Release.Program :=
  ⟨fun _ => none,fun c => if c = "Scope.ScopeError.At" then some atDecl else none,
    fun o => if o = "unitOp" then some unitOperation else none,
    fun e => if e = "UnitEffect" then some ["unitOp"] else none,
    fun _ => none,fun _ => none⟩
def oldBuiltins : Benitoite.Release.Builtins :=
  { sig := fun _ => none,delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False,releaseResponse := fun _ _ => False,
    isResource := fun _ => false,effects := fun _ => none,sat := fun _ _ _ => True,
    refGet := "get",refSet := "set" }
def builtins : Builtins :=
  { sig := fun _ => none,delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False,releaseResponse := fun _ _ => False,
    isResource := fun _ => false,effects := fun _ => none,sat := fun _ _ _ => True,
    refGet := "get",refSet := "set" }

theorem tables : LegacyTables kinds oldProgram oldBuiltins builtins := by
  constructor
  · intro b s hs; cases hs
  · intro C a p _; trivial
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · intro o; rfl
  · intro b rs h; cases h
  · intro c cd c' cd' hc hc' _
    simp only [oldProgram] at hc hc'
    split at hc <;> try cases hc
    split at hc' <;> cases hc'
    rfl
  · intro c cd hc a ha
    simp only [oldProgram] at hc
    split at hc <;> cases hc
    simp only [atDecl,List.mem_replicate] at ha
    obtain ⟨_,rfl⟩ := ha
    exact ⟨⟨trivial,trivial,trivial⟩,trivial⟩
  · intro c cd hc a ha
    simp only [oldProgram] at hc
    split at hc <;> cases hc
    simp only [atDecl,List.mem_replicate] at ha
    obtain ⟨_,rfl⟩ := ha
    trivial

theorem kinds_wf : kinds.WF oldProgram := by
  constructor
  · intro f d h; cases h
  · intro cl cd m ms h; cases h

def opaqueType : Benitoite.Release.Ty := .opaque "o" (.fixed .top)
def allList : Pat := .list [] (some .skip) []

private theorem old_list_coverage (P0 : Benitoite.Release.Program) (a : Benitoite.Release.Ty) :
    Benitoite.Release.Exhaustive P0 (.list a) [allList] := by
  intro v hv
  generalize he : Benitoite.Release.Ty.list a = t at hv
  cases hv with
  | const =>
    rename_i c
    cases c <;> simp [Benitoite.Release.Const.type,Benitoite.Release.Ty.opaqueTop] at he
  | list hs =>
    cases he
    exact ⟨allList,by simp,by simp [allList,Benitoite.Release.Pat.matchVal,Benitoite.Release.Pat.matchList]⟩
  | _ => cases he

theorem list_input : LegacyNodeTypes kinds oldProgram [] [] 0 [.list opaqueType] := by
  intro a ha
  obtain rfl := List.mem_singleton.mp ha
  exact ⟨trivial,trivial,trivial,trivial,trivial⟩

theorem list_coverage : Exhaustive (embedProgramWithKinds kinds oldProgram)
    (embedTy (.list opaqueType)) [allList] :=
  embedExhaustive tables (legacy_wf (list_input _ (List.mem_cons_self)).2.1) (old_list_coverage oldProgram opaqueType)

theorem checkedAt_in_list (r : RangeExpr) (snapshot : Option PathEnv)
    (target : Scope.Domain.Target) (request : Option Val) :
    ∃ p ∈ [allList], (matchVal p (.list [.checkedAt r snapshot target request])).isSome :=
  list_coverage _ (.list (.cons .checkedAtOpaque .nil))

theorem nested_pattern : PatTy (embedProgramWithKinds kinds oldProgram)
    (.list [.var] (some .bind) []) (embedTy (.list opaqueType))
    (embedTys [opaqueType,.list opaqueType]) := by
  exact embedPatTy tables (.P_List (.cons .P_Var .nil) .nil (by simp))

theorem nested_alts : AltsTy (embedProgramWithKinds kinds oldProgram)
    [⟨.list [.var] (some .bind) [],[0,1]⟩] (embedTy (.list opaqueType))
    (embedTys [opaqueType,.list opaqueType]) := by
  apply embedAltsTy tables
  refine ⟨by simp, rfl, ?_, ?_⟩
  · intro alt h; cases h; rfl
  · intro alt h
    obtain rfl := List.mem_singleton.mp h
    exact ⟨_,.P_List (.cons .P_Var .nil) .nil (by simp),.refl _,rfl⟩

def atPattern : Pat := .con "Scope.ScopeError.At" (List.replicate 7 .var)

theorem at_seven_bindings (detail : AtError) :
    matchVal atPattern (.atError detail) = some detail.values := by
  simp [atPattern,AtError.values,AtError.textFields,matchVal,matchList]

theorem at_old_correspondence (detail : AtError) :
    Benitoite.Release.Pat.matchVal atPattern (legacyPatternVal (.atError detail)) =
      some (detail.textFields.map (fun s => Benitoite.Release.Val.const (.string s))) := by
  rw [legacy_matchVal,at_seven_bindings,Option.map_some]
  simp [AtError.values,legacyPatternVals_eq_map,List.map_map,Function.comp_def,
    legacyPatternVal,legacyPatternConst]

theorem at_wrong_name (detail : AtError) :
    matchVal (.con "Other" (List.replicate 7 .var)) (.atError detail) = none := by
  simp [matchVal]

theorem at_wrong_arity (detail : AtError) :
    matchVal (.con "Scope.ScopeError.At" (List.replicate 6 .var)) (.atError detail) = none := by
  simp [AtError.values,AtError.textFields,matchVal,matchList]

def rangeOpaque : Benitoite.Release.Ty := .opaque "o" (.rvar 0)

theorem old_range_exhaustive (P0 : Benitoite.Release.Program) :
    Benitoite.Release.Exhaustive P0 rangeOpaque [] := by
  intro v hv
  generalize he : rangeOpaque = a at hv
  cases hv with
  | const =>
    rename_i c
    cases c <;> simp [Benitoite.Release.Const.type,rangeOpaque,Benitoite.Release.Ty.opaqueTop] at he
  | _ => simp [rangeOpaque] at he

theorem new_range_not_exhaustive (P : Program) :
    ¬ Exhaustive P (embedTy rangeOpaque) [] := by
  intro h
  have hi : Inhabits P (embedTy rangeOpaque).norm (.checkedAt .top none (.path []) none) :=
    .checkedAtOpaque
  obtain ⟨p,hp,_⟩ := h _ hi
  cases hp

theorem range_wf_rejected (nt : Nat) : ¬ Benitoite.Release.Ty.WF 0 nt rangeOpaque :=
  Nat.not_lt_zero 0

theorem range_input_rejected (K : DeclarationKinds) (P0 : Benitoite.Release.Program) (κ C nv) :
    ¬ LegacyNodeTypes K P0 κ C nv [rangeOpaque] := by
  intro h
  exact range_wf_rejected κ.length (legacy_wf (nv := nv) (h rangeOpaque (by simp)).2.1)

end LegacyPatternExamples

end
end Benitoite.Release.Refinement
