import Benitoite.Exchange.CheckSupport
import Benitoite.Release.Refinement.SurfaceStandardSupport

/-! # 交換した組み込みの表と標準表の一致

交換した組み込みの表の署名と data の宣言を、名前の有限の一覧について、標準表の合成済みの行の署名と標準の
data の宣言に照らす。表は、交換の内部名を同じ入力の宣言から決まる標準の名前へ写した照合用の表である
（`Exchange.CanonicalNames.ofInputs`。写しと一覧の作り方は `Exchange.CheckInput`）。型と効果は同じ有限の原子の
一覧による構造比較で照合し、型パラメータの制約の命題（`admits`）は比べない。型パラメータの制約は、照合用の表の
側の鍵の印をそろえてから比べる（`normKeys`）。成功から、一覧の名前ごとの一致を得る（設計書 07-04「証明する性質」）。
標準表の合成済みの名前でない組み込みの名前は、仮定側の名前として署名を照らさない。
-/
namespace Benitoite.Exchange.BuiltinAgreement
open Benitoite.Exchange.CheckSupport

namespace R
export Benitoite.Release.Refinement (Ty Eff Atom PrimSig TParamDecl)
export Benitoite.Release (PrimName)
end R

local instance : DecidableEq Benitoite.Release.TParam := by
  intro a b
  cases a; cases b
  simp only [Benitoite.Release.TParam.mk.injEq]
  infer_instance

local instance : DecidableEq R.TParamDecl := by
  intro a b
  cases a; cases b
  simp only [Benitoite.Release.Refinement.TParamDecl.mk.injEq]
  infer_instance

/-- 型付けが読む署名の欄の一致。型パラメータの制約の命題は含めない。 -/
structure ShapeEq (s s' : R.PrimSig) : Prop where
  tparams : s.tparams = s'.tparams
  neffs : s.neffs = s'.neffs
  names : s.names = s'.names
  params : s.params = s'.params
  ret : s.ret = s'.ret
  eff : s.eff = s'.eff
  kind : s.kind = s'.kind
  opEff : s.opEff = s'.opEff
  rkinds : s.rkinds = s'.rkinds
  shape : s.shape = s'.shape

/-- 二つの署名の欄の有限判定。型と効果は同じ有限の原子の一覧で比べる。 -/
def shapeCheck (atoms : List R.Atom) (s s' : R.PrimSig) : Bool :=
  decide (s.tparams = s'.tparams) && (decide (s.neffs = s'.neffs) && (decide (s.names = s'.names) &&
    (Benitoite.Release.Refinement.Surface.CheckArguments.tysEq atoms s.params s'.params &&
    (Benitoite.Release.Refinement.Surface.CheckCompare.rawTyEq atoms s.ret s'.ret &&
    (Benitoite.Release.Refinement.Surface.CheckCompare.rawEffEq atoms s.eff s'.eff &&
    (decide (s.kind = s'.kind) && (decide (s.opEff = s'.opEff) &&
    (decide (s.rkinds = s'.rkinds) && decide (s.shape = s'.shape)))))))))

theorem shapeCheck_sound {atoms : List R.Atom} {s s' : R.PrimSig}
    (hs : SigSupport atoms s.params s.ret s.eff) (hs' : SigSupport atoms s'.params s'.ret s'.eff)
    (h : shapeCheck atoms s s' = true) : ShapeEq s s' := by
  simp only [shapeCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨h1, h2, h3, h4, h5, h6, h7, h8, h9, h10⟩ := h
  exact ⟨h1, h2, h3, Benitoite.Release.Refinement.Surface.CheckArguments.tysEq_sound hs.1 hs'.1 h4,
    (Benitoite.Release.Refinement.Surface.CheckCompare.rawTyEq_spec hs.2.1 hs'.2.1).mp h5,
    (Benitoite.Release.Refinement.Surface.CheckCompare.rawEffEq_spec hs.2.2 hs'.2.2).mp h6, h7, h8, h9, h10⟩

/-- 一覧の名前ごとに、両方の表が署名を持たないか、両方が欄の一致する署名を持つ。 -/
def Agrees (names : List R.PrimName) (sig ref : R.PrimName → Option R.PrimSig) : Prop :=
  ∀ n ∈ names, (sig n = none ∧ ref n = none) ∨ ∃ s s', sig n = some s ∧ ref n = some s' ∧ ShapeEq s s'

/-- 有限の名前の一覧で、二つの表の署名を照らす判定。 -/
def check (atoms : List R.Atom) (sig ref : R.PrimName → Option R.PrimSig) (names : List R.PrimName) : Bool :=
  names.all fun n => match sig n, ref n with
    | none, none => true
    | some s, some s' => shapeCheck atoms s s'
    | _, _ => false

/-- 判定の成功から、名前ごとの署名の一致を得る。支持は比べる署名だけについて要求する。 -/
theorem agrees_of_check {atoms : List R.Atom} {sig ref : R.PrimName → Option R.PrimSig} {names : List R.PrimName}
    (hsig : ∀ n s, sig n = some s → SigSupport atoms s.params s.ret s.eff)
    (href : ∀ n s, ref n = some s → SigSupport atoms s.params s.ret s.eff)
    (h : check atoms sig ref names = true) : Agrees names sig ref := by
  intro n hn
  have hc := List.all_eq_true.mp h n hn
  cases hs : sig n with
  | none =>
    cases hr : ref n with
    | none => exact .inl ⟨rfl, rfl⟩
    | some s' => simp [hs, hr] at hc
  | some s =>
    cases hr : ref n with
    | none => simp [hs, hr] at hc
    | some s' =>
      simp only [hs, hr] at hc
      exact .inr ⟨s, s', rfl, rfl, shapeCheck_sound (hsig n s hs) (href n s' hr) hc⟩

/-! ## 鍵の印の正規化

鍵の制約は等値の制約を含む。制約の判定（`satB`）は鍵の印があれば鍵の判定だけを読むので、鍵の印を持つ制約から
等値の印を外しても、制約の意味（`ModelConstraints.sat`・`ModelConstraints.admits`）は変わらない。照合は、交換の側の
署名の型パラメータの制約をこの形にそろえてから比べる。 -/

/-- 鍵の印を持つ制約を、鍵の印だけの制約にそろえる。 -/
def normKey (p : Benitoite.Release.TParam) : Benitoite.Release.TParam := if p.key then { key := true } else p

theorem satB_normKey (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam)
    (t : Benitoite.Release.Ty) (p : Benitoite.Release.TParam) :
    Benitoite.Release.satB S C t (normKey p) = Benitoite.Release.satB S C t p := by
  cases p with
  | mk e k => cases e <;> cases k <;> rfl

theorem sat_normKey (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam)
    (a : R.Ty) (p : Benitoite.Release.TParam) :
    Benitoite.Release.Refinement.ModelConstraints.sat S C a (normKey p) ↔
      Benitoite.Release.Refinement.ModelConstraints.sat S C a p := by
  simp only [Benitoite.Release.Refinement.ModelConstraints.sat, satB_normKey]

theorem admits_normKey (S : Benitoite.Release.SummaryTable) (ps C : List Benitoite.Release.TParam)
    (ts : List R.Ty) :
    Benitoite.Release.Refinement.ModelConstraints.admits S (ps.map normKey) C ts ↔
      Benitoite.Release.Refinement.ModelConstraints.admits S ps C ts := by
  simp only [Benitoite.Release.Refinement.ModelConstraints.admits, List.length_map, List.getElem?_map]
  constructor
  · rintro ⟨hl, h⟩
    exact ⟨hl, fun i a p ha hp => (sat_normKey S C a p).mp (h i a (normKey p) ha (by simp [hp]))⟩
  · rintro ⟨hl, h⟩
    refine ⟨hl, fun i a p ha hp => ?_⟩
    obtain ⟨p0, hp0, rfl⟩ := Option.map_eq_some_iff.mp hp
    exact (sat_normKey S C a p0).mpr (h i a p0 ha hp0)

/-- 署名の型パラメータの制約を `normKey` でそろえる。ほかの欄は変えない。 -/
def normKeys (s : R.PrimSig) : R.PrimSig :=
  { s with tparams := s.tparams.map fun d => { d with constraints := normKey d.constraints } }

/-- 表の署名をそろえても、引数・結果・効果の支持は保たれる。 -/
theorem normKeys_support {atoms : List R.Atom} {sig : R.PrimName → Option R.PrimSig}
    (h : ∀ n s, sig n = some s → SigSupport atoms s.params s.ret s.eff) :
    ∀ n s, (sig n).map normKeys = some s → SigSupport atoms s.params s.ret s.eff := by
  intro n s hs
  obtain ⟨s0, h0, rfl⟩ := Option.map_eq_some_iff.mp hs
  exact h n s0 h0

/-! ## 標準表の合成済みの行との照合 -/

/-- 標準表の合成済みの行の署名（合成表の型の制約の判定で作った署名）。 -/
def standardSig (n : R.PrimName) : Option R.PrimSig := Benitoite.Release.Refinement.StandardModel.signature n

/-- 交換の組み込みの名前のうち、標準表の合成済みの行の名前。これ以外の名前は仮定側の名前である。 -/
def composedNames (names : List R.PrimName) : List R.PrimName :=
  names.filter fun n => (Benitoite.Release.Refinement.StandardModel.primitive n).isSome

theorem standardSig_support (n : R.PrimName) (s : R.PrimSig) (h : standardSig n = some s) :
    SigSupport Benitoite.Release.Refinement.Surface.StandardSupport.atoms s.params s.ret s.eff := by
  obtain ⟨row, _, rfl⟩ := Option.map_eq_some_iff.mp h
  have hs := Benitoite.Release.Refinement.Surface.StandardSupport.primitive
    Benitoite.Release.Refinement.StandardModel.signatureBase.sat row
  rw [Benitoite.Release.Refinement.StandardModel.Primitive.signatureWith_base] at hs
  exact ⟨hs.1, hs.2.1, hs.2.2.1⟩

/-- 原子の一覧を広げても支持は保たれる。 -/
theorem sigSupport_mono {atoms atoms' : List R.Atom} (hsub : ∀ a ∈ atoms, a ∈ atoms') {ps : List R.Ty} {r : R.Ty}
    {e : R.Eff} (h : SigSupport atoms ps r e) : SigSupport atoms' ps r e := by
  refine ⟨?_, Benitoite.Release.Refinement.Ty.support_mono r h.2.1 hsub,
    Benitoite.Release.Refinement.Eff.support_mono e h.2.2 hsub⟩
  have hp := Benitoite.Release.Refinement.Ty.SupportList.iff.mp h.1
  exact Benitoite.Release.Refinement.Ty.SupportList.iff.mpr
    fun t ht => Benitoite.Release.Refinement.Ty.support_mono t (hp t ht) hsub

/-- 交換の組み込みの表と標準表の合成済みの行の照合。比較は交換の原子の一覧と標準署名の原子の一覧の和で行う。 -/
def standardCheck (atoms : List R.Atom) (sig : R.PrimName → Option R.PrimSig) (names : List R.PrimName) : Bool :=
  check (atoms ++ Benitoite.Release.Refinement.Surface.StandardSupport.atoms) sig standardSig (composedNames names)

/-- 照合の成功から、合成済みの行の名前ごとに、交換の表と標準表の署名の欄が一致する。 -/
theorem standardCheck_sound {atoms : List R.Atom} {sig : R.PrimName → Option R.PrimSig} {names : List R.PrimName}
    (hsig : ∀ n s, sig n = some s → SigSupport atoms s.params s.ret s.eff)
    (h : standardCheck atoms sig names = true) : Agrees (composedNames names) sig standardSig :=
  agrees_of_check
    (fun n s hs => sigSupport_mono (fun _ ha => List.mem_append_left _ ha) (hsig n s hs))
    (fun n s hs => sigSupport_mono (fun _ ha => List.mem_append_right _ ha) (standardSig_support n s hs)) h


/-! ## 完成表との名前ごとの一致 -/

/-- 標準の行の署名の欄は、型の制約の判定によらない（判定は制約の命題だけに現れる）。 -/
theorem signatureWith_shape (sat : List Benitoite.Release.TParam → R.Ty → Benitoite.Release.TParam → Prop)
    (row : Benitoite.Release.Refinement.StandardModel.Primitive) : ShapeEq (row.signatureWith sat) row.signature := by
  cases row <;> exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

theorem ShapeEq.trans {s t u : R.PrimSig} (h : ShapeEq s t) (h' : ShapeEq t u) : ShapeEq s u :=
  ⟨h.1.trans h'.1, h.2.trans h'.2, h.3.trans h'.3, h.4.trans h'.4, h.5.trans h'.5, h.6.trans h'.6,
    h.7.trans h'.7, h.8.trans h'.8, h.9.trans h'.9, h.10.trans h'.10⟩

theorem ShapeEq.symm {s t : R.PrimSig} (h : ShapeEq s t) : ShapeEq t s :=
  ⟨h.1.symm, h.2.symm, h.3.symm, h.4.symm, h.5.symm, h.6.symm, h.7.symm, h.8.symm, h.9.symm, h.10.symm⟩

/-- 合成済みの名前では、完成表の署名は宣言の一覧の型の制約の判定で作った標準の行の署名である。 -/
theorem complete_sig {L : Benitoite.Release.Refinement.StandardModel.NameLists}
    (hL : L.WF) {P : Benitoite.Release.Refinement.Program} (T : Benitoite.Release.Refinement.StandardModel.DataTable P)
    (A : Benitoite.Release.Refinement.StandardModel.AssumedTable) {n : R.PrimName}
    {row : Benitoite.Release.Refinement.StandardModel.Primitive}
    (hrow : Benitoite.Release.Refinement.StandardModel.primitive n = some row) :
    (Benitoite.Release.Refinement.StandardModel.complete L T A).sig n = some (row.signatureWith T.sat) := by
  have hn : n ∈ L.composed := hL.composedAll n (by
    change (Benitoite.Release.Refinement.StandardModel.signature n).isSome = true
    simp [Benitoite.Release.Refinement.StandardModel.signature, hrow])
  simp [Benitoite.Release.Refinement.StandardModel.complete, Benitoite.Release.Refinement.ExternalModel.builtins,
    Benitoite.Release.Refinement.StandardModel.completeBase, hn, Benitoite.Release.Refinement.StandardModel.DataTable.base,
    Benitoite.Release.Refinement.StandardModel.baseBuiltinsFor, hrow]

/-- 標準表の合成済みの行との照合の成功から、整形式の名前の一覧で作ったどの完成表についても、交換の表と完成表の
署名の欄が合成済みの名前ごとに一致する。仮定側の名前と型パラメータの制約の命題はこの一致に含まない。 -/
theorem agrees_complete {names : List R.PrimName} {sig : R.PrimName → Option R.PrimSig}
    (h : Agrees (composedNames names) sig standardSig)
    {L : Benitoite.Release.Refinement.StandardModel.NameLists} (hL : L.WF)
    {P : Benitoite.Release.Refinement.Program} (T : Benitoite.Release.Refinement.StandardModel.DataTable P)
    (A : Benitoite.Release.Refinement.StandardModel.AssumedTable) :
    ∀ n ∈ composedNames names, ∃ s s', sig n = some s ∧
      (Benitoite.Release.Refinement.StandardModel.complete L T A).sig n = some s' ∧ ShapeEq s s' := by
  intro n hn
  have hp := (List.mem_filter.mp hn).2
  obtain ⟨row, hrow⟩ := Option.isSome_iff_exists.mp hp
  have hstd : standardSig n = some row.signature := by
    simp [standardSig, Benitoite.Release.Refinement.StandardModel.signature, hrow]
  rcases h n hn with ⟨_, hnone⟩ | ⟨s, s', hs, hs', heq⟩
  · rw [hstd] at hnone; cases hnone
  · rw [hstd] at hs'
    cases hs'
    exact ⟨s, row.signatureWith T.sat, hs, complete_sig hL T A hrow, heq.trans (signatureWith_shape T.sat row).symm⟩

/-! ## 標準の data の宣言との照合 -/

/-- 照合用の構成子の表のうち、data `n` の構成子（表の順）。 -/
def dataConstructors (cons : List (String × Benitoite.Release.Refinement.ConDecl)) (n : String) :
    List (String × Benitoite.Release.Refinement.ConDecl) :=
  cons.filter fun c => c.2.data == n

/-- data の宣言の一致。照合用の構成子の表の data の構成子の数が標準の宣言の構成子の数と同じで、各構成子について、
型引数の数が同じで、同じ名前の標準の構成子があり、引数の型が原子の一覧での構造比較（`tysEq`）で一致する。
構成子の名前は照合用の表で一意なので（準備の `uniqueKeys`）、構成子の名前の集合も一致する。順序は比べない。 -/
structure DataAgrees (atoms : List R.Atom) (cons : List (String × Benitoite.Release.Refinement.ConDecl))
    (decl : Benitoite.Release.Refinement.StandardKeyTyping.DataDecl) : Prop where
  count : (dataConstructors cons decl.name).length = decl.constructors.length
  fields : ∀ c ∈ dataConstructors cons decl.name, c.2.ntys = decl.ntys ∧
    ∃ args, decl.constructors.lookup c.1 = some args ∧
      Benitoite.Release.Refinement.Surface.CheckArguments.tysEq atoms c.2.args args = true

/-- data の宣言の一致の有限判定。 -/
def dataCheck (atoms : List R.Atom) (cons : List (String × Benitoite.Release.Refinement.ConDecl))
    (decl : Benitoite.Release.Refinement.StandardKeyTyping.DataDecl) : Bool :=
  decide ((dataConstructors cons decl.name).length = decl.constructors.length) &&
    (dataConstructors cons decl.name).all fun c =>
      decide (c.2.ntys = decl.ntys) && match decl.constructors.lookup c.1 with
        | some args => Benitoite.Release.Refinement.Surface.CheckArguments.tysEq atoms c.2.args args
        | none => false

theorem dataCheck_sound {atoms : List R.Atom} {cons : List (String × Benitoite.Release.Refinement.ConDecl)}
    {decl : Benitoite.Release.Refinement.StandardKeyTyping.DataDecl} (h : dataCheck atoms cons decl = true) :
    DataAgrees atoms cons decl := by
  simp only [dataCheck, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true] at h
  refine ⟨h.1, fun c hc => ?_⟩
  have hc' := h.2 c hc
  refine ⟨hc'.1, ?_⟩
  revert hc'
  cases hl : decl.constructors.lookup c.1 with
  | none => simp
  | some args => intro hc'; exact ⟨args, rfl, hc'.2⟩

/-- 名前の一覧の data のうち、標準の宣言と同じ名前を持つものが全て標準の宣言と一致する。 -/
def DataListAgrees (atoms : List R.Atom) (cons : List (String × Benitoite.Release.Refinement.ConDecl))
    (data : List String) : Prop :=
  ∀ n ∈ data, ∀ decl, Benitoite.Release.Refinement.StandardModel.declarations.find? (·.name == n) = some decl →
    DataAgrees atoms cons decl

/-- 名前の一覧の data のうち、標準の宣言と同じ名前を持ち、標準の宣言と一致しない data の名前。 -/
def dataDisagreements (atoms : List R.Atom) (cons : List (String × Benitoite.Release.Refinement.ConDecl))
    (data : List String) : List String :=
  data.filter fun n => match Benitoite.Release.Refinement.StandardModel.declarations.find? (·.name == n) with
    | some decl => !dataCheck atoms cons decl
    | none => false

theorem dataDisagreements_nil {atoms : List R.Atom} {cons : List (String × Benitoite.Release.Refinement.ConDecl)}
    {data : List String} (h : dataDisagreements atoms cons data = []) : DataListAgrees atoms cons data := by
  intro n hn decl hd
  have hnot : n ∉ dataDisagreements atoms cons data := by rw [h]; simp
  simp only [dataDisagreements, List.mem_filter, hd, not_and, Bool.not_eq_true'] at hnot
  exact dataCheck_sound (by simpa using hnot hn)

end Benitoite.Exchange.BuiltinAgreement
