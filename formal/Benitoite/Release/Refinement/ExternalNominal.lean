import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.TypeRenaming
import Benitoite.Release.Refinement.Carrier
import Benitoite.Release.Refinement.Source
import Benitoite.Release.Refinement.Finite
import Benitoite.Release.Refinement.Capture

/-! # 外部宣言の鍵と名目IDの保持 -/
namespace Benitoite.Release.Refinement
namespace ExternalNominal

/-- 外部宣言の有限表だけを持つ宣言照合用のプログラム。 -/
def program (entries : List (ExternalKey × ExternalDecl)) : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none,
    externals := entries }

/-- 鍵と宣言の四対を、有限表全体の一意性とともに照合する。 -/
theorem table_wf_iff (P : Program) : P.ExternalWF ↔
    (P.externals.map Prod.fst).Nodup ∧
    (∀ id td, (ExternalKey.type id, ExternalDecl.type td) ∈ P.externals →
      td.id = id ∧ td.arity = 0) ∧
    (∀ f g d, (ExternalKey.function f, ExternalDecl.function g d) ∈ P.externals →
      f = g ∧ d.WF P) ∧
    (∀ id f d, (ExternalKey.type id, ExternalDecl.function f d) ∉ P.externals) ∧
    (∀ f td, (ExternalKey.function f, ExternalDecl.type td) ∉ P.externals) := by
  constructor
  · intro h
    exact ⟨h.unique, (by intros; exact h.keys _ _ ‹_›),
      (by intros; exact h.keys _ _ ‹_›),
      (by intro id f d mem; exact h.keys (.type id) (.function f d) mem),
      (by intro f td mem; exact h.keys (.function f) (.type td) mem)⟩
  · rintro ⟨unique, types, functions, mixedType, mixedFunction⟩
    refine ⟨unique, ?_⟩
    intro key decl mem
    cases key <;> cases decl
    · exact types _ _ mem
    · exact mixedType _ _ _ mem
    · exact mixedFunction _ _ mem
    · exact functions _ _ _ mem

/-- 同じ鍵を二度収集した表は、値や表示名が同じでも整形式でない。 -/
theorem duplicate {P : Program} {key : ExternalKey} {a b : ExternalDecl}
    {rest : List (ExternalKey × ExternalDecl)}
    (table : P.externals = (key,a) :: (key,b) :: rest) : ¬ P.ExternalWF := by
  intro h
  have unique := h.unique
  simp [table] at unique

/-- 未知のIDでは宣言の前提を供給できない。 -/
theorem unknown {P C Γ id args} (missing : P.externalType id = none) :
    ¬ Ty.Declared P C Γ (.external id args) := by
  rintro ⟨⟨td, lookup, _⟩, _⟩
  simp [missing] at lookup

/-- 型の宣言を差し替えた場合も、鍵のIDと単相のarityを照合する。 -/
theorem type_entry {P : Program} {id td}
    (entry : (ExternalKey.type id, ExternalDecl.type td) ∈ P.externals)
    (bad : td.id ≠ id ∨ td.arity ≠ 0) : ¬ P.ExternalWF := by
  intro wf
  have valid := (table_wf_iff P).mp wf |>.2.1 id td entry
  exact bad.elim (· valid.1) (· valid.2)

/-- 正しい型の宣言と、ID又はarityを差し替えた宣言の境界。 -/
theorem singleton_type (td : ExternalTypeDecl) (id : ExternalId) :
    (program [(.type id, .type td)]).ExternalWF ↔
      td.id = id ∧ td.arity = 0 := by
  constructor
  · intro wf
    exact wf.keys _ _ (List.mem_singleton_self _)
  · intro h
    refine ⟨by simp [program], ?_⟩
    intro key decl mem
    change (key,decl) ∈ [_] at mem
    simp only [List.mem_singleton, Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩
    exact h

/-- 関数の鍵は関数IDを照合し、同じ表に対する署名の形成を要求する。 -/
theorem singleton_function (f g : ExternalFunctionId) (d : ExternalSignature) :
    (program [(.function f, .function g d)]).ExternalWF ↔
      f = g ∧ d.WF (program [(.function f, .function g d)]) := by
  constructor
  · intro wf
    exact wf.keys _ _ (List.mem_singleton_self _)
  · intro h
    refine ⟨by simp [program], ?_⟩
    intro key decl mem
    change (key,decl) ∈ [_] at mem
    simp only [List.mem_singleton, Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩
    exact h

/-- 鍵と異なる関数IDへの差し替えを、任意の有限表で拒否する。 -/
theorem function_entry {P : Program} {f g d}
    (entry : (ExternalKey.function f, ExternalDecl.function g d) ∈ P.externals)
    (different : f ≠ g) : ¬ P.ExternalWF := by
  intro wf
  exact different ((table_wf_iff P).mp wf |>.2.2.1 f g d entry).1

example (f g : ExternalFunctionId) (d : ExternalSignature) (different : f ≠ g) :
    ¬ (program [(.function f,.function g d)]).ExternalWF :=
  function_entry (f := f) (g := g) (d := d) (by simp [program]) different

/-- 表示名を変えても、型の同一性を決めるIDと宣言の整形式性は変わらない。 -/
example (id : ExternalId) (component : ComponentId) (resource : Nat) (a b : String) :
    let first : ExternalTypeDecl := ⟨id,component,a,0,resource⟩
    let alias : ExternalTypeDecl := ⟨id,component,b,0,resource⟩
    (program [(.type id,.type first)]).ExternalWF ∧
    (program [(.type id,.type alias)]).ExternalWF := by
  exact ⟨(singleton_type _ _).mpr ⟨rfl,rfl⟩, (singleton_type _ _).mpr ⟨rfl,rfl⟩⟩

/-- 異種の鍵と宣言、重複、差し替え、未知のIDはそれぞれ別の拒否理由である。 -/
example (id : ExternalId) (f : ExternalFunctionId) (d : ExternalSignature) :
    ¬ (program [(.type id,.function f d)]).ExternalWF := by
  intro wf
  exact (table_wf_iff _).mp wf |>.2.2.2.1 id f d (by simp [program])

example (f : ExternalFunctionId) (td : ExternalTypeDecl) :
    ¬ (program [(.function f,.type td)]).ExternalWF := by
  intro wf
  exact (table_wf_iff _).mp wf |>.2.2.2.2 f td (by simp [program])

example (id : ExternalId) (td : ExternalTypeDecl) :
    ¬ (program [(.type id,.type td),(.type id,.type td)]).ExternalWF :=
  duplicate rfl

example (id : ExternalId) (td : ExternalTypeDecl) (different : td.id ≠ id) :
    ¬ (program [(.type id,.type td)]).ExternalWF :=
  type_entry (by simp [program]) (Or.inl different)

example (id : ExternalId) (args : List Ty) (C : TypeCtx) (Γ : Ctx) :
    ¬ Ty.Declared (program []) C Γ (.external id args) := unknown rfl

/-- 変換の後も外部型の芯に同じIDがある。引数の像は変換ごとに異なる。 -/
def Preserves (transform : Ty → Ty) : Prop :=
  ∀ (id : ExternalId) (args : List Ty),
    ∃ resultArgs, (transform (.external id args)).core = .external id resultArgs

theorem norm : Preserves Ty.norm := by intro id args; exact ⟨_,rfl⟩
theorem normWith (support : List Atom) : Preserves (Ty.normWith support) := by
  intro id args; exact ⟨_,rfl⟩
theorem shiftV (k c : Nat) : Preserves (Ty.shiftV k c) := by intro id args; exact ⟨_,rfl⟩
theorem rawMapRanges (ρ : Nat → RangeIx) : Preserves (Ty.rawMapRanges ρ) := by
  intro id args; exact ⟨_,rfl⟩
theorem rawRenameTypes (ρ : Nat → Nat) : Preserves (fun a => a.rawRenameTypes ρ) := by
  intro id args; exact ⟨_,rfl⟩
theorem rawBind (θ : SubstEnv) : Preserves (Ty.rawBind θ) := by
  intro id args; exact ⟨_,rfl⟩
theorem shiftTypes (k c : Nat) : Preserves (Refinement.shiftTypes k c) := by
  intro id args; exact ⟨_,rfl⟩
theorem rawSubstV (ν : ObservationEnv) : Preserves (Ty.rawSubstV ν) := by
  intro id args; exact ⟨_,rfl⟩
theorem renameValues (ξ : Nat → Nat) : Preserves (Ty.renameValues ξ) := by
  intro id args; exact ⟨_,rfl⟩
theorem carrier : Preserves Ty.carrier := by intro id args; exact ⟨_,rfl⟩
theorem observationType : Preserves Ty.observationType := by intro id args; exact ⟨[],rfl⟩

theorem bind (θ : SubstEnv) : Preserves (Ty.bind θ) := by
  intro id args
  exact ⟨args.map (Ty.bind θ), congrArg Ty.core (Ty.bind_external id args θ)⟩
theorem renameTypes (ρ : Nat → Nat) : Preserves (fun a => a.renameTypes ρ) := by
  intro id args; exact ⟨_,rfl⟩
theorem mapRanges (ρ : Nat → RangeIx) : Preserves (Ty.mapRanges ρ) := by
  intro id args; exact ⟨_,rfl⟩
theorem substRAt (c : Nat) (rs : List RangeExpr) : Preserves (Ty.substRAt c rs) := mapRanges _
theorem instR (rs : List RangeExpr) : Preserves (Ty.instR rs) := substRAt 0 rs
theorem shiftR (k c : Nat) : Preserves (Ty.shiftR k c) := mapRanges _
theorem substAt (c : Nat) (ts : List Ty) (es : List Eff) : Preserves (Ty.substAt c ts es) := bind _
theorem subst (ts : List Ty) (es : List Eff) : Preserves (Ty.subst ts es) := substAt 0 ts es
theorem shift (k c : Nat) : Preserves (Ty.shift k c) := bind _
theorem substV (ν : ObservationEnv) : Preserves (Ty.substV ν) := bind _
theorem substVAt (c : Nat) (ν : ObservationEnv) : Preserves (Ty.substVAt c ν) := substV _

theorem renameTy (ξ : Nat → Nat) : Preserves (Refinement.renameTy ξ) := rawBind _
theorem substTyValues (ν : Nat → Val) : Preserves (Refinement.substTyValues ν) := bind _
theorem substTypeAt (c : Nat) (ts : List Ty) (es : List Eff) :
    Preserves (Refinement.substTypeAt c ts es) := bind _

theorem closeTy (cap : Capture) : Preserves cap.closeTy := substTyValues _
theorem closeTyAt (cap : Capture) (n : Nat) : Preserves (cap.closeTyAt n) := substTyValues _
theorem packRefinements (ps : List Pred) : Preserves (fun a => a.packRefinements ps) := by
  intro id args
  exact ⟨args, Ty.core_packRefinements _ _⟩
theorem refineNorm (p : Pred) : Preserves (fun a => a.refineNorm p) := by
  intro id args
  exact ⟨args, Ty.core_refineNorm _ _⟩

/-- 外部型を読む全変換の入力を、記号のまま一つの読者へ渡す。 -/
theorem transformations (support : List Atom) (θ : SubstEnv) (k c : Nat)
    (types : Nat → Nat) (ranges : Nat → RangeIx) (values : ObservationEnv)
    (rs : List RangeExpr) (ts : List Ty) (es : List Eff) (runtimeValues : Nat → Val)
    (cap : Capture) (ps : List Pred) (p : Pred) :
    ∀ transform ∈ [
      Ty.norm,
      Ty.normWith support,
      Ty.shiftV k c,
      Ty.rawMapRanges ranges,
      (fun a => a.rawRenameTypes types),
      Ty.rawBind θ,
      Refinement.shiftTypes k c,
      Ty.rawSubstV values,
      Ty.renameValues types,
      Ty.carrier,
      Ty.observationType,
      Ty.bind θ,
      (fun a => a.renameTypes types),
      Ty.mapRanges ranges,
      Ty.substRAt c rs,
      Ty.instR rs,
      Ty.shiftR k c,
      Ty.substAt c ts es,
      Ty.subst ts es,
      Ty.shift k c,
      Ty.substV values,
      Ty.substVAt c values,
      Refinement.renameTy types, Refinement.substTyValues runtimeValues,
      Refinement.substTypeAt c ts es,
      cap.closeTy, cap.closeTyAt c,
      (fun a => a.packRefinements ps), (fun a => a.refineNorm p)], Preserves transform := by
  simp only [List.forall_mem_cons]
  exact ⟨norm,normWith support,shiftV k c,rawMapRanges ranges,rawRenameTypes types,rawBind θ,shiftTypes k c,rawSubstV values,renameValues types,carrier,observationType,bind θ,renameTypes types,mapRanges ranges,substRAt c rs,instR rs,shiftR k c,substAt c ts es,subst ts es,shift k c,substV values,substVAt c values,renameTy types,substTyValues runtimeValues,substTypeAt c ts es,closeTy cap,closeTyAt cap c,packRefinements ps,refineNorm p,(by intro x h; cases h)⟩

/-- 異なる名目IDは、引数や表示名によらず正規形の等号で一致しない。 -/
theorem distinct {id other : ExternalId} (different : id ≠ other) (as bs : List Ty) :
    (Ty.external id as).norm ≠ (Ty.external other bs).norm := by
  intro equal
  exact different (Ty.external.inj equal).1

/-- 同じID保持の変換を適用しても、異なる外部IDは一致しない。 -/
theorem transformed_distinct {transform : Ty → Ty} (preserves : Preserves transform)
    {id other : ExternalId} (different : id ≠ other) (as bs : List Ty) :
    transform (.external id as) ≠ transform (.external other bs) := by
  obtain ⟨xs,hx⟩ := preserves id as
  obtain ⟨ys,hy⟩ := preserves other bs
  intro equal
  have cores := congrArg Ty.core equal
  rw [hx,hy] at cores
  exact different (Ty.external.inj cores).1

/-- Map内のdata引数、関数の引数のList、関数の結果を同じ宣言表で読む。 -/
theorem map_fn_declarations {P C Γ owner names id args resultId resultArgs effect}
    (declared : Ty.Declared P C Γ
      (.map (.data owner [.external id args])
        (.fn names [.list (.external id args)] (.external resultId resultArgs) effect))) :
    Ty.Declared P C Γ (.external id args) ∧
      Ty.Declared P C Γ (.external resultId resultArgs) :=
  ⟨declared.1.2.1,declared.2.2.1⟩

example {P C Γ owner names id args resultId resultArgs effect}
    (wf : P.ExternalWF)
    (declared : Ty.Declared P C Γ
      (.map (.data owner [.external id args])
        (.fn names [.list (.external id args)] (.external resultId resultArgs) effect))) :
    args = [] ∧ resultArgs = [] := by
  obtain ⟨first,last⟩ := map_fn_declarations declared
  obtain ⟨td,lookup,_,arity⟩ := first.1
  obtain ⟨rd,resultLookup,_,resultArity⟩ := last.1
  exact ⟨List.eq_nil_of_length_eq_zero (arity.trans (wf.type_lookup lookup).2),
    List.eq_nil_of_length_eq_zero (resultArity.trans (wf.type_lookup resultLookup).2)⟩

example (support : List Atom) (θ : SubstEnv) (k c : Nat)
    (types : Nat → Nat) (ranges : Nat → RangeIx) (values : ObservationEnv)
    (rs : List RangeExpr) (ts : List Ty) (es : List Eff) (runtimeValues : Nat → Val)
    (cap : Capture) (ps : List Pred) (p : Pred)
    (transform : Ty → Ty)
    (selected : transform ∈ [
      Ty.norm,
      Ty.normWith support,
      Ty.shiftV k c,
      Ty.rawMapRanges ranges,
      (fun a => a.rawRenameTypes types),
      Ty.rawBind θ,
      Refinement.shiftTypes k c,
      Ty.rawSubstV values,
      Ty.renameValues types,
      Ty.carrier,
      Ty.observationType,
      Ty.bind θ,
      (fun a => a.renameTypes types),
      Ty.mapRanges ranges,
      Ty.substRAt c rs,
      Ty.instR rs,
      Ty.shiftR k c,
      Ty.substAt c ts es,
      Ty.subst ts es,
      Ty.shift k c,
      Ty.substV values,
      Ty.substVAt c values,
      Refinement.renameTy types, Refinement.substTyValues runtimeValues,
      Refinement.substTypeAt c ts es,
      cap.closeTy, cap.closeTyAt c,
      (fun a => a.packRefinements ps), (fun a => a.refineNorm p)])
    (id other : ExternalId) (different : id ≠ other) (as bs : List Ty) :
    transform (.external id as) ≠ transform (.external other bs) :=
  transformed_distinct
    (transformations support θ k c types ranges values rs ts es runtimeValues cap ps p transform selected) different as bs

/-- 型付けから、元ハンドルと同じcomponent/resourceと単相arityを取り出す。 -/
theorem handle_declaration {P B Ψ Q C Γ Φ T h ts}
    (wf : P.ExternalWF)
    (typed : HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) T) :
    ∃ td, P.externalType h.typeId = some td ∧ td.id = h.typeId ∧
      td.component = h.component ∧ td.resource = h.resource ∧ td.arity = 0 ∧ ts = [] := by
  obtain ⟨td,lookup,component,resource,count,_,_⟩ := typed.inv_externalHandle rfl
  obtain ⟨id,arity⟩ := wf.type_lookup lookup
  exact ⟨td,lookup,id,component,resource,arity,
    List.eq_nil_of_length_eq_zero (count.trans arity)⟩

/-- 宣言がないIDに、包む部分型規則を使ってもハンドルを型付けできない。 -/
theorem unknown_handle {P B Ψ Q C Γ Φ T h ts} (missing : P.externalType h.typeId = none) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) T := by
  intro typed
  obtain ⟨td,lookup,_⟩ := typed.inv_externalHandle rfl
  simp [missing] at lookup

/-- 型の宣言は、任意の入れ子から取り出した型引数数を同じ表で検査する。 -/
theorem declared_arity {P C Γ id args} (wf : Program.ExternalWF P)
    (declared : Ty.Declared P C Γ (.external id args)) : args = [] := by
  obtain ⟨td,lookup,_,count⟩ := declared.1
  exact List.eq_nil_of_length_eq_zero (count.trans (wf.type_lookup lookup).2)

example {P C Γ id args} (wf : Program.ExternalWF P) (nonempty : args ≠ []) :
    ¬ Ty.Declared P C Γ (.external id args) := fun declared => nonempty (declared_arity wf declared)

example {P B Ψ Q C Γ Φ T f ts} (missing : P.externalFunction f = none) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts) T := by
  intro typed
  obtain ⟨d,_,lookup,_⟩ := typed.inv_externalRef rfl
  simp [missing] at lookup

/-- 二つの宣言のIDが異なると、引数列によらず正規形は一致しない。 -/
example (a b : ExternalTypeDecl) (different : a.id ≠ b.id)
    (as bs : List Ty) : (Ty.external a.id as).norm ≠ (Ty.external b.id bs).norm :=
  distinct different as bs

example {P B Ψ Q C Γ Φ T h ts} (wf : P.ExternalWF)
    (typed : HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) T) :
    ∃ td, P.externalType h.typeId = some td ∧ td.component = h.component ∧
      td.resource = h.resource ∧ ts = [] := by
  obtain ⟨td,lookup,_,component,resource,_,args⟩ := handle_declaration wf typed
  exact ⟨td,lookup,component,resource,args⟩

example {B Ψ Q C Γ Φ T h ts} :
    ¬ HasTypeVQ (program []) B Ψ Q C Γ Φ (.externalHandle h ts) T := unknown_handle rfl

end ExternalNominal
end Benitoite.Release.Refinement
