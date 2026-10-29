import Benitoite.Release.Theorems

/-!
# 仮定を満たす組み込みの関数の例（段階 B）

`Builtins.Assumptions` が矛盾しない（定理が空虚に成り立っていない）ことを、仮定を満たす組み込みの関数の
集まりを一つ作って確かめる。組み込みの関数は `Reference.get` と `Reference.set` の二つだけで、IO を行う関数も
リソースの型も持たない。どのプログラムについても仮定を満たす。加えて、定義を持たないプログラムが定理の
前提を満たすことを示す。型クラスの実装を持つプログラムについても、同じことを示す。
-/

namespace Benitoite.Release.Model

open Benitoite.Release

def refGetSig : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference"]
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

def refSetSig : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference", "value"]
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

def builtins : Builtins where
  sig := fun b => if b = "Reference.get" then some refGetSig
    else if b = "Reference.set" then some refSetSig else none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ r => r = none
  isResource := fun _ => false
  effects := fun l => if l = stateEff then some [] else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"
  -- 署名表のデータ（問 11）。この表のエフェクト（`State`）は対象を持たず、不透明型と資源の型は範囲付きの値型でない
  -- （RV-PL10 中3 (b)）。範囲の変数を持つ項目がないので、具体化の制約は何も許さない（Top の列だけを許す）。
  effKind := fun _ => none
  valKind := fun _ => none
  admitsR := fun _ _ => False

/-- この表には範囲付きの値型がない（既存の不透明型と資源の型は `valKind = none`）。 -/
theorem builtins_valKind (o : OpaqueName) : builtins.valKind o = none := rfl

/-- この表のエフェクトの名前は対象の種類を持たない。 -/
theorem builtins_effKind (l : EffName) : builtins.effKind l = none := rfl

/-- この表の項目は範囲の変数を持たない。 -/
theorem builtins_nranges {b s} (h : builtins.sig b = some s) : s.nranges = 0 := by
  simp only [builtins] at h
  split at h
  · cases h; rfl
  · split at h
    · cases h; rfl
    · cases h

theorem sig_cases {b s} (h : builtins.sig b = some s) : s = refGetSig ∨ s = refSetSig := by
  simp only [builtins] at h
  split at h
  · cases h; exact Or.inl rfl
  · split at h
    · cases h; exact Or.inr rfl
    · cases h

theorem single_no_rho (i : Nat) : Eff.test (Eff.single stateEff) (.rho i) = false := by
  simp [Eff.test, Eff.single, Eff.ofAtoms, Eff.atoms]

theorem assumptions (P : Program) : builtins.Assumptions P where
  sig_scoped := by
    intro b s h
    rcases sig_cases h with rfl | rfl <;>
      simp [PrimSig.Scoped, refGetSig, refSetSig, PrimSig.ntys, NamesWF, Ty.VarsInList,
        Ty.VarsIn, Eff.VarsIn, Eff.single, Eff.ofAtoms]

  admits_subst := by
    intro b s C0 C1 ts ts' es' h ha _ _
    rcases sig_cases h with rfl | rfl <;> simpa [refGetSig, refSetSig] using ha
  sat_subst := fun _ _ _ _ _ _ _ _ _ => trivial
  sat_unconstrained := fun _ _ => trivial
  admits_sat := by
    intro b s C ts h ha
    rcases sig_cases h with rfl | rfl <;>
      exact ⟨by simpa [refGetSig, refSetSig] using ha, fun _ _ _ _ _ => trivial⟩
  sat_local := fun _ _ _ _ _ _ => trivial
  admits_local := by
    intro b s C1 C0 ts h _ ha
    rcases sig_cases h with rfl | rfl <;> exact ha
  delta_typed := by
    intro Ψ b s rs ts es ws h hk
    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
  io_kind := fun _ _ _ _ _ _ _ _ h => h.elim
  io_typed := fun _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ h => h.elim
  io_exists := by
    intro Ψ b s rs ts es ws h hk
    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
  io_op := by
    intro b s h hk
    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
  effect_ops := by
    intro l bs b h hb
    simp only [builtins] at h
    split at h
    · cases h; simp at hb
    · cases h
  opEff_io := by
    intro b s l h hl
    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hl
  state_effect := by simp [builtins]
  store_shape := by
    intro b s h
    rcases sig_cases h with rfl | rfl <;>
      simp [PrimSig.StoreShape, PrimSig.ntys, refGetSig, refSetSig]
  store_admits := by
    intro b s C ts h _ _ _ hl
    rcases sig_cases h with rfl | rfl <;> simpa [PrimSig.ntys, refGetSig, refSetSig] using hl
  ref_get := ⟨refGetSig, by simp [builtins], rfl⟩
  ref_set := ⟨refSetSig, by simp [builtins], rfl⟩
  release_exists := fun _ _ _ _ _ => ⟨none, rfl⟩
  io_target := by
    intro Ψ b s rs ts es ws o obs _ _ _ _ _ _ _ h
    exact h.elim

/-- 定義も宣言も持たないプログラム。 -/
def emptyProgram : Program :=
  ⟨fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none⟩

theorem emptyProgram_wellFormed : emptyProgram.WellFormed :=
  ⟨fun _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h),
    fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

theorem emptyProgram_wellTyped : emptyProgram.WellTyped builtins :=
  ⟨fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

theorem emptyProgram_effectsOk : emptyProgram.EffectsOk builtins :=
  ⟨fun _ _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

example : ∀ s, Steps emptyProgram builtins (.run (.ret (.const .unit)) [] Store.empty) s →
    (∀ ev s', ¬ Step emptyProgram builtins s (some ev) s') ∧ ¬ UnhandledOp s :=
  effect_soundness emptyProgram_wellFormed emptyProgram_wellTyped emptyProgram_effectsOk
    (assumptions emptyProgram).core (.C_Return .V_Const) trivial

/-! ## 型クラスを使うプログラム

型クラスの定理の前提が、型クラスの実装を持つプログラムで満たせることを確かめる。

- `trait C[P] { m() -> P }`、`trait D[P: C] { n() -> P }`
- `CInt : C[Integer]`（`m` は 0 を返す）、`DInt : D[Integer]`（`n` は 1 を返し、上位の型クラスの辞書は `CInt[]()`）
-/

def constSig : MethSig := { tparams := [], neffs := 0, names := [], params := [], ret := .tvar 0, eff := Eff.empty }

def classC : ClassDecl := { supers := [], methods := fun m => if m = "m" then some constSig else none }
def classD : ClassDecl := { supers := ["C"], methods := fun m => if m = "n" then some constSig else none }

def implC : ImplDecl where
  tparams := []
  dictParams := []
  cls := "C"
  target := .base .integer
  supers := fun _ => none
  methods := fun m => if m = "m" then some (.ret (.const (.integer ⟨0, by decide⟩))) else none

def implD : ImplDecl where
  tparams := []
  dictParams := []
  cls := "D"
  target := .base .integer
  supers := fun s => if s = "C" then some (.dict "CInt" [] []) else none
  methods := fun m => if m = "n" then some (.ret (.const (.integer ⟨1, by decide⟩))) else none

def classProgram : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun c => if c = "C" then some classC else if c = "D" then some classD else none
  impls := fun i => if i = "CInt" then some implC else if i = "DInt" then some implD else none

theorem classProgram_classes {c cd} (h : classProgram.classes c = some cd) :
    (c = "C" ∧ cd = classC) ∨ (c = "D" ∧ cd = classD) := by
  simp only [classProgram] at h
  split at h
  · cases h; exact Or.inl ⟨by assumption, rfl⟩
  · split at h
    · cases h; exact Or.inr ⟨by assumption, rfl⟩
    · cases h

theorem classProgram_impls {i id} (h : classProgram.impls i = some id) :
    (i = "CInt" ∧ id = implC) ∨ (i = "DInt" ∧ id = implD) := by
  simp only [classProgram] at h
  split at h
  · cases h; exact Or.inl ⟨by assumption, rfl⟩
  · split at h
    · cases h; exact Or.inr ⟨by assumption, rfl⟩
    · cases h

theorem constSig_scoped : constSig.Scoped := by
  simp [MethSig.Scoped, constSig, NamesWF, Ty.VarsInList, Ty.VarsIn, Eff.VarsIn, Eff.empty]

theorem classProgram_wellFormed : classProgram.WellFormed := by
  refine ⟨fun _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h), ?_, ?_⟩
  · intro c cd h m ms hm
    rcases classProgram_classes h with ⟨_, rfl⟩ | ⟨_, rfl⟩ <;>
    · simp only [classC, classD] at hm
      split at hm
      · cases hm; exact constSig_scoped
      · cases hm
  · intro i id h
    rcases classProgram_impls h with ⟨_, rfl⟩ | ⟨_, rfl⟩
    · refine ⟨by simp [implC], by simp [implC, Ty.VarsIn], fun s u hu => by simp [implC] at hu, ?_⟩
      intro cd m ms body _ _ hb
      simp only [implC] at hb
      split at hb
      · cases hb; simp [Comp.VarsIn, Val.VarsIn]
      · cases hb
    · refine ⟨by simp [implD], by simp [implD, Ty.VarsIn], ?_, ?_⟩
      · intro s u hu
        simp only [implD] at hu
        split at hu
        · cases hu; simp [Val.VarsIn, Ty.VarsInList, Val.VarsInList]
        · cases hu
      · intro cd m ms body _ _ hb
        simp only [implD] at hb
        split at hb
        · cases hb; simp [Comp.VarsIn, Val.VarsIn]
        · cases hb

/-- メソッドの本体 `return k` に、D-Impl が求める型 `Integer` が付く。 -/
theorem const_body_typed {Q : NoFailCtx} (k : Integer64Value) {id : ImplDecl} (ht : id.target = .base .integer) :
    HasTypeCQ classProgram builtins StoreTy.empty Q ([] ++ id.tparams)
      (binds (id.dictTys.map (Ty.shift 0 0) ++ constSig.params.map (id.methTy constSig)))
      (some (id.methTy constSig constSig.ret)) (.ret (.const (.integer k)))
      (id.methTy constSig constSig.ret) constSig.eff := by
  have e : id.methTy constSig constSig.ret = .base .integer := by
    simp [ImplDecl.methTy, constSig, Ty.substAt, ht, Ty.shift]
  rw [e]
  exact .C_Return .V_Const

theorem classProgram_wellTyped : classProgram.WellTyped builtins := by
  refine ⟨fun _ _ h => (by cases h), ?_⟩
  intro i id h
  rcases classProgram_impls h with ⟨_, rfl⟩ | ⟨_, rfl⟩
  · refine ⟨classC, by simp [classProgram, implC], ?_, ?_, ?_, ?_⟩
    · intro m; by_cases hm : m = "m" <;> simp [implC, classC, hm]
    · intro s; simp [implC, classC]
    · intro m ms hm
      simp only [classC] at hm
      split at hm
      · cases hm
        exact ⟨.ret (.const (.integer ⟨0, by decide⟩)), by simp [implC, *], by simp [NamesWF, constSig],
          (by simpa [constSig, implC, ImplDecl.methTy, Eff.substAt_empty] using const_body_typed (id := implC) ⟨0, by decide⟩ rfl)⟩
      · cases hm
    · intro s hs; simp [classC] at hs
  · refine ⟨classD, by simp [classProgram, implD], ?_, ?_, ?_, ?_⟩
    · intro m; by_cases hm : m = "n" <;> simp [implD, classD, hm]
    · intro s; by_cases hs : s = "C" <;> simp [implD, classD, hs]
    · intro m ms hm
      simp only [classD] at hm
      split at hm
      · cases hm
        exact ⟨.ret (.const (.integer ⟨1, by decide⟩)), by simp [implD, *], by simp [NamesWF, constSig],
          (by simpa [constSig, implD, ImplDecl.methTy, Eff.substAt_empty] using const_body_typed (id := implD) ⟨1, by decide⟩ rfl)⟩
      · cases hm
    · intro s hs
      simp [classD] at hs
      subst hs
      refine ⟨.dict "CInt" [] [], by simp [implD], ?_⟩
      have := HasTypeVQ.V_Dict (Q := Qempty) (P := classProgram) (B := builtins) (Ψ := StoreTy.empty) (C := [])
        (Γ := binds implD.dictTys) (i := "CInt") (ts := []) (vs := []) (id := implC)
        (by simp [classProgram]) ⟨rfl, fun _ _ _ h _ => by simp at h⟩ .nil
      simpa [implC, implD, Ty.subst, Ty.substAt, Eff.substAt] using this

theorem classProgram_effectsOk : classProgram.EffectsOk builtins :=
  ⟨fun _ _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

/-- `(DInt[]()↑C).m[;]()` の型付け。上位の型クラスの辞書を取り出してからメソッドを呼ぶ。 -/
theorem super_call_typed :
    HasTypeC classProgram builtins StoreTy.empty [] [] none
      (.meth (.super (.dict "DInt" [] []) "C") "m" [] [] []) (.base .integer) Eff.empty := by
  have hd : HasTypeV classProgram builtins StoreTy.empty [] [] (.dict "DInt" [] []) (.dict "D" (.base .integer)) := by
    have := HasTypeVQ.V_Dict (Q := Qempty) (P := classProgram) (B := builtins) (Ψ := StoreTy.empty) (C := []) (Γ := [])
      (i := "DInt") (ts := []) (vs := []) (id := implD)
      (by simp [classProgram]) ⟨rfl, fun _ _ _ h _ => by simp at h⟩ .nil
    simpa [implD, Ty.subst, Ty.substAt, Eff.substAt] using this
  have hs := HasTypeVQ.V_Super (s := "C") (cd := classD) hd (by simp [classProgram]) (by simp [classD])
  have hm := HasTypeCQ.C_Meth (Δ := []) (R := none) (m := "m") (ss := []) (es := []) (ws := []) (cd := classC)
    (ms := constSig) hs
    (by simp [classProgram]) (by simp [classC]) (by simp [NamesWF, constSig]) ⟨rfl, fun _ _ _ h _ => by simp at h⟩
    (by intro t ht; simp only [List.nil_append, List.mem_singleton] at ht; subst t
        exact ⟨trivial, by intros; simp⟩)
    (MethodRowsAdmissible.of_noRows
      (by simp [MethSig.Scoped, constSig, NamesWF, Ty.VarsIn, Ty.VarsInList,
        Eff.VarsIn, Eff.empty]) rfl) .nil
  simpa [constSig, Ty.subst, Ty.substAt, Eff.substAt_empty, Ty.shift] using hm

/-- 型クラスのメソッドの呼び出しからの実行は、事象を伴う遷移をしない。 -/
example : ∀ s, Steps classProgram builtins
      (.run (.meth (.super (.dict "DInt" [] []) "C") "m" [] [] []) [] Store.empty) s →
    (∀ ev s', ¬ Step classProgram builtins s (some ev) s') ∧ ¬ UnhandledOp s :=
  effect_soundness classProgram_wellFormed classProgram_wellTyped classProgram_effectsOk
    (assumptions classProgram).core super_call_typed
    (by simp [Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Ty.VarsInList, Val.VarsInList,
      Eff.VarsInList])

/-! ## 契約名の整形式・適合・位置による実行 -/

/-- ゼロ引数も名前の空の並びを持つ。一引数の名前も省かない。 -/
example : NamesWF [] [] ∧ NamesWF ["value"] [.base .integer] ∧
    NamesWF ["left", "right"] [.base .integer, .base .string] := by
  simp [NamesWF]

/-- 引数型の個数と異なる名前、同じ名前の二度の指定を認めない。 -/
example : ¬ NamesWF [] [.base .integer] ∧
    ¬ NamesWF ["value", "value"] [.base .integer, .base .integer] := by
  simp [NamesWF]

/-- コンテナの内側でも関数型の名前の整形式を検査する。 -/
example : ¬ Ty.WF 0 0 (.list (.fn ["value", "value"]
    [.base .integer, .base .integer] (.base .integer) Eff.empty)) ∧
    ¬ Ty.VarsIn 0 0 (fun _ => False)
      (.reference (.fn [] [.base .integer] (.base .integer) Eff.empty)) := by
  simp [Ty.WF, Ty.VarsIn, NamesWF]

/-- 名前の読み替えと宣言順の入れ替えは、エフェクトの包含で許さない。 -/
example : ¬ Ty.Le (.fn ["value"] [.base .integer] (.base .integer) Eff.empty)
    (.fn ["other"] [.base .integer] (.base .integer) Eff.empty) ∧
    ¬ Ty.Le (.fn ["left", "right"] [.base .integer, .base .integer] (.base .integer) Eff.empty)
      (.fn ["right", "left"] [.base .integer, .base .integer] (.base .integer) Eff.empty) := by
  constructor <;> intro h <;>
    rcases h with h | ⟨names, ps, r, ε, ε', h, h', _⟩
  · simp at h
  · cases h; simp at h'
  · simp at h
  · cases h; simp at h'

/-- Reference.get の契約名は型引数を置き換えても残る。 -/
example : HasTypeV emptyProgram builtins StoreTy.empty [] []
    (.prim "Reference.get" [.base .integer] [] [])
    (.fn ["reference"] [.reference (.base .integer)] (.base .integer) (Eff.single stateEff)) := by
  have hsc : refGetSig.Scoped := (assumptions emptyProgram).sig_scoped "Reference.get" refGetSig (by simp [builtins])
  have h0 : refGetSig.nranges = 0 := rfl
  have hinst := PrimSig.inst_nil_of_scoped hsc h0
  have hpa : PrimitiveAdmissible [] refGetSig Qempty [.base .integer] [] := PrimitiveAdmissible.of_noRows hsc rfl rfl rfl
    (by intro t ht; simp only [List.mem_singleton] at ht; subst t
        exact ⟨trivial, by intros; simp⟩)
  have h := HasTypeVQ.V_Prim (Q := Qempty) (P := emptyProgram) (B := builtins) (Ψ := StoreTy.empty)
    (C := []) (Γ := []) (b := "Reference.get") (s := refGetSig) (rs := []) (ts := [.base .integer])
    (es := []) (by simp [builtins]) ((Builtins.rangeAdmissible_iff_nil h0 []).mpr rfl)
    (by rw [hinst]; simp [NamesWF, refGetSig]) (by rw [hinst]; exact hpa)
  rw [hinst] at h
  have he : Eff.substAt 0 [.base .integer] [] (Eff.single stateEff) = Eff.single stateEff :=
    Eff.substAt_ofAtoms 0 _ _
  simpa [fnTy_eq, refGetSig, Ty.subst, Ty.substAt, he, Ty.shift] using h

/-- 最初の引数は番号 1、最後の引数は番号 0 に束縛する。契約名はこの位置を変えない。 -/
def firstLambda : Val := .lam ["left", "right"] [.base .integer, .base .string] (.ret (.var 1))

example : HasTypeV emptyProgram builtins StoreTy.empty [] [] firstLambda
    (.fn ["left", "right"] [.base .integer, .base .string] (.base .integer) Eff.empty) := by
  exact .V_Lam (by simp [NamesWF]) (by simp [Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]) (.C_Return (.V_Var rfl (by intros; intro h; cases h)))

/-- 束縛されていない型変数を引数に持つラムダは、本体がその引数を返すだけでも拒む。 -/
example : ∀ a, ¬ HasTypeV emptyProgram builtins StoreTy.empty [] []
    (.lam ["value"] [.tvar 0] (.ret (.var 0))) a := by
  intro a h
  obtain ⟨r, ε, hw, _, _, _⟩ := h.inv_lam_wf rfl
  have : 0 < 0 := hw.2.1.1
  omega

/-- 同じラムダは、その型変数が束縛された位置なら型が付く。 -/
example : HasTypeV emptyProgram builtins StoreTy.empty [({} : TParam)] []
    (.lam ["value"] [.tvar 0] (.ret (.var 0)))
    (.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty) := by
  exact .V_Lam (by simp [NamesWF]) (by simp [Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys])
    (.C_Return (.V_Var rfl (by intros; intro h; cases h)))

/-- 型の包含を何度通しても、ラムダ自身の契約名の整形式は必要である。 -/
theorem lambda_names_wellFormed {P B Ψ Q C Γ v a names ps body}
    (h : HasTypeVQ P B Ψ Q C Γ v a) (hv : v = .lam names ps body) : NamesWF names ps := by
  match h with
  | .V_CheckedRequest .. => cases hv
  | .V_Lam hn hw _ => cases hv; exact hn
  | .V_Sub h _ hw => exact lambda_names_wellFormed h hv
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun .. => cases hv
  | .V_Prim .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Raise _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv
  | .V_Map _ _ _ _ _ _ => cases hv
  | .V_Set _ _ _ => cases hv
  | .V_Bytes => cases hv
  | .V_Dict _ _ _ => cases hv
  | .V_Super _ _ _ => cases hv
termination_by structural h

/-- 不正な契約は、戻り値を定数にしても型付けを通らない。 -/
example : ∀ a, ¬ HasTypeV emptyProgram builtins StoreTy.empty [] []
    (.lam ["value", "value"] [.base .integer, .base .integer] (.ret (.const .unit))) a := by
  intro a h
  have hn := lambda_names_wellFormed h rfl
  simp [NamesWF] at hn

example : step emptyProgram builtins (fun _ _ _ _ => (.err "unused", [])) (fun _ => none) (fun _ => 0)
    (.run (.app firstLambda [.const (.integer ⟨7, by decide⟩), .const (.string "second")]) [] Store.empty) =
    some (none, .run (.ret (.const (.integer ⟨7, by decide⟩))) [.mark] Store.empty) := by
  rfl

/-- 高階の引数では、引数型・戻り値型が同じでも、ラムダの契約名を読み替えない。 -/
def higherOrderCallee : Val :=
  .lam ["f"] [.fn ["value"] [.base .integer] (.base .integer) Eff.empty]
    (.ret (.const .unit))

/-- 名前以外の型と本体は、否定例と同じ条件で型付けできる。 -/
example : HasTypeC emptyProgram builtins StoreTy.empty [] [] none
    (.app higherOrderCallee [.lam ["value"] [.base .integer] (.ret (.var 0))])
    (.base .unit) Eff.empty := by
  exact .C_App (.V_Lam (by simp [NamesWF]) (by simp [Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]) (.C_Return .V_Const))
    (.cons (.V_Lam (by simp [NamesWF]) (by simp [Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]) (.C_Return (.V_Var rfl (by intros; intro h; cases h)))) .nil)

/-- C-App と C-Sub を経ても、異なる契約名の関数値を渡す呼び出しは型付けできない。 -/
example : ∀ a ε, ¬ HasTypeC emptyProgram builtins StoreTy.empty [] [] none
    (.app higherOrderCallee [.lam ["x"] [.base .integer] (.ret (.var 0))]) a ε := by
  intro a ε h
  obtain ⟨_, as, _, _, hf, hargs, _, _⟩ := h.inv_app rfl
  obtain ⟨_, _, _, _, hle⟩ := hf.inv_lam rfl
  have hps := (Ty.Le.fn_fn' hle).2.1
  change [.fn ["value"] [.base .integer] (.base .integer) Eff.empty] = as at hps
  subst as
  cases hargs with
  | cons hx _ =>
      obtain ⟨_, _, _, _, hle⟩ := hx.inv_lam rfl
      have hn := (Ty.Le.fn_fn' hle).1
      simp at hn

end Benitoite.Release.Model
