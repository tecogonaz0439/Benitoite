import Benitoite.Release.Refinement.LegacyPatternCoverage
import Benitoite.Release.Refinement.ScopePublicTyping

namespace Benitoite.Release.Refinement
noncomputable section

namespace LegacyPatternExamples

def kinds : DeclarationKinds := ⟨fun _ => .value,fun _ => [],fun _ _ => []⟩
/-- At の診断の公開の宣言と Option の、旧 Release の構成子。 -/
def oldConstructors : List (ConName × Benitoite.Release.ConDecl) :=
  ScopePublic.constructors.map (fun e =>
      (e.1, (⟨e.2.1, 0, e.2.2.map ScopePublic.PublicTy.oldTy⟩ : Benitoite.Release.ConDecl))) ++
    [("Option.Some", ⟨"Option",1,[.tvar 0]⟩), ("Option.None", ⟨"Option",1,[]⟩)]
def atDecl : Benitoite.Release.ConDecl := ⟨"Scope.ScopeError",0,[.data "Scope.AtDetail" []]⟩
def unitOperation : Benitoite.Release.OpDecl :=
  ⟨"UnitEffect",[],[],[],.base .unit,[]⟩
def oldProgram : Benitoite.Release.Program :=
  ⟨fun _ => none,fun c => oldConstructors.lookup c,
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

private theorem lookup_map {α β : Type} (f : α → β) (xs : List (ConName × α)) (c : ConName) :
    (xs.map fun e => (e.1, f e.2)).lookup c = (xs.lookup c).map f := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    simp only [List.map_cons, List.lookup]
    split <;> simp_all

/-- 埋め込んだ旧プログラムの構成子の lookup は、公開の宣言だけを持つプログラムと同じである。 -/
theorem embedded_cons (c : ConName) :
    (embedProgramWithKinds kinds oldProgram).cons c = ScopePublic.program.cons c := by
  change (oldConstructors.lookup c).map embedConDecl = ScopePublic.programConstructors.lookup c
  rw [← lookup_map]
  congr 1

theorem embedded_public : (embedProgramWithKinds kinds oldProgram).HasScopePublic :=
  Program.HasScopePublic.of_cons embedded_cons ScopePublic.program_public.1

private theorem old_lookup {c cd} (hc : oldProgram.cons c = some cd) :
    (∃ d as, (c, d, as) ∈ ScopePublic.constructors ∧ cd = ⟨d, 0, as.map ScopePublic.PublicTy.oldTy⟩) ∨
    (cd = ⟨"Option",1,[.tvar 0]⟩) ∨ (cd = ⟨"Option",1,[]⟩) := by
  change oldConstructors.lookup c = some cd at hc
  obtain ⟨before, after, eq, _⟩ := List.lookup_eq_some_iff.mp hc
  have mem : (c, cd) ∈ oldConstructors := by rw [eq]; exact List.mem_append_right _ List.mem_cons_self
  simp only [oldConstructors, List.mem_append, List.mem_map, List.mem_cons, List.not_mem_nil, or_false,
    Prod.mk.injEq] at mem
  rcases mem with ⟨⟨c', d, as⟩, hm, rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
  · exact .inl ⟨d, as, hm, rfl⟩
  · exact .inr (.inl rfl)
  · exact .inr (.inr rfl)

private theorem old_embedded {c cd} (hc : oldProgram.cons c = some cd) :
    ScopePublic.program.cons c = some (embedConDecl cd) := by
  rw [← embedded_cons]; simp [hc]

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
  · intro c cd c' cd' hc hc' hd
    have h := ScopePublic.program_arity (old_embedded hc)
    exact (h.2 c' _ (old_embedded hc') hd.symm).symm
  · intro c cd hc a ha
    rcases old_lookup hc with ⟨d, as, hm, rfl⟩ | rfl | rfl
    · obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
      have hk := (ScopePublic.constructor_fields hm).2 b hb
      rw [ScopePublic.PublicTy.embed_oldTy]
      exact ⟨b.annotation embedded_public _ _ hk, b.kind embedded_public _ hk⟩
    · obtain rfl := List.mem_singleton.mp ha
      exact ⟨⟨by simp [embedTy, Ty.WF], trivial, trivial⟩, by simp [embedTy, Ty.HasKind]⟩
    · cases ha
  · intro c cd hc a ha
    rcases old_lookup hc with ⟨d, as, hm, rfl⟩ | rfl | rfl
    · obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
      rw [ScopePublic.PublicTy.embed_oldTy]
      exact b.sourceScoped _ _ _
    · obtain rfl := List.mem_singleton.mp ha
      exact ⟨by simp [embedTy, Ty.WF], by simp [embedTy, Ty.RowsIn], by simp [embedTy, Ty.RangesScoped]⟩
    · cases ha

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

def atPattern : Pat := .con "Scope.ScopeError.At" [.var]

theorem at_detail_binding (detail : AtError) :
    matchVal atPattern (.atError detail) = some detail.values := by
  simp [atPattern,Detail.values,matchVal,matchList]

theorem at_old_correspondence (detail : AtError) :
    Benitoite.Release.Pat.matchVal atPattern (legacyPatternVal (.atError detail)) =
      some [detail.publicTree.legacy] := by
  rw [legacy_matchVal,at_detail_binding,Option.map_some]
  simp [Detail.values,legacyPatternVals,ScopePublic.PublicTree.legacy_toVal]

theorem at_wrong_name (detail : AtError) :
    matchVal (.con "Other" [.var]) (.atError detail) = none := by
  simp [matchVal]

theorem at_wrong_arity (detail : AtError) :
    matchVal (.con "Scope.ScopeError.At" (List.replicate 7 .var)) (.atError detail) = none := by
  simp [Detail.values,matchVal,matchList]

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
