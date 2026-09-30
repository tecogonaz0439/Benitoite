import Benitoite.Release.Theorems

/-!
# 仮定を満たす組み込みの関数の例（段階 B）

`Builtins.Assumptions` が矛盾しない（定理が空虚に成り立っていない）ことを、仮定を満たす組み込みの関数の
集まりを一つ作って確かめる。組み込みの関数は `Reference.get` と `Reference.set` の二つだけで、IO を行う関数も
リソースの型も持たない。どのプログラムについても仮定を満たす。加えて、定義を持たないプログラムが定理の
前提を満たし、エフェクトの健全性を具体的な計算に使えることを示す。型クラスの実装を持つプログラムについても、
同じことを示す（段階 B2）。
-/

namespace Benitoite.Release.Model

open Benitoite.Release

def refGetSig : PrimSig where
  tparams := [{}]
  neffs := 0
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

def refSetSig : PrimSig where
  tparams := [{}]
  neffs := 0
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

def builtins : Builtins where
  sig := fun b => if b = "Reference.get" then some refGetSig
    else if b = "Reference.set" then some refSetSig else none
  delta := fun _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ => False
  releaseResponse := fun _ r => r = none
  isResource := fun _ => false
  effects := fun l => if l = stateEff then some [] else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"

theorem sig_cases {b s} (h : builtins.sig b = some s) : s = refGetSig ∨ s = refSetSig := by
  simp only [builtins] at h
  split at h
  · cases h; exact Or.inl rfl
  · split at h
    · cases h; exact Or.inr rfl
    · cases h

theorem single_no_rho (i : Nat) : Eff.single stateEff (.rho i) = false := by
  simp [Eff.single]

theorem assumptions (P : Program) : builtins.Assumptions P where
  sig_scoped := by
    intro b s h
    rcases sig_cases h with rfl | rfl <;>
      exact ⟨by simp [Ty.VarsInList, Ty.VarsIn, PrimSig.ntys, refGetSig, refSetSig],
        by simp [Ty.VarsIn, PrimSig.ntys, refGetSig, refSetSig],
        fun i hi => by simp [refGetSig, refSetSig, single_no_rho] at hi⟩
  admits_subst := by
    intro b s C0 C1 ts ts' es' h ha _ _
    rcases sig_cases h with rfl | rfl <;> simpa [refGetSig, refSetSig] using ha
  sat_subst := fun _ _ _ _ _ _ _ _ _ => trivial
  admits_sat := by
    intro b s C ts h ha
    rcases sig_cases h with rfl | rfl <;>
      exact ⟨by simpa [refGetSig, refSetSig] using ha, fun _ _ _ _ _ => trivial⟩
  sat_local := fun _ _ _ _ _ _ => trivial
  admits_local := by
    intro b s C1 C0 ts h _ ha
    rcases sig_cases h with rfl | rfl <;> exact ha
  delta_typed := by
    intro Ψ b s ts es ws h hk
    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
  io_kind := fun _ _ _ _ _ _ _ h => h.elim
  io_typed := fun _ _ _ _ _ _ _ _ _ _ _ _ _ h => h.elim
  io_exists := by
    intro Ψ b s ts es ws h hk
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

/-- `return ()` からの実行は、事象を伴う遷移をしない。 -/
example : ∀ s, Steps emptyProgram builtins (.run (.ret (.const .unit)) [] Store.empty) s →
    (∀ ev s', ¬ Step emptyProgram builtins s (some ev) s') ∧ ¬ UnhandledOp s :=
  effect_soundness emptyProgram_wellFormed emptyProgram_wellTyped emptyProgram_effectsOk
    (assumptions emptyProgram) (.C_Return .V_Const) trivial

/-! ## 型クラスを使うプログラム

型クラスの定理の前提が、型クラスの実装を持つプログラムで満たせることを確かめる。

- `trait C[P] { m() -> P }`、`trait D[P: C] { n() -> P }`
- `CInt : C[Integer]`（`m` は 0 を返す）、`DInt : D[Integer]`（`n` は 1 を返し、上位の型クラスの辞書は `CInt[]()`）
-/

def constSig : MethSig := { tparams := [], neffs := 0, params := [], ret := .tvar 0, eff := Eff.empty }

def classC : ClassDecl := { supers := [], methods := fun m => if m = "m" then some constSig else none }
def classD : ClassDecl := { supers := ["C"], methods := fun m => if m = "n" then some constSig else none }

def implC : ImplDecl where
  tparams := []
  dictParams := []
  cls := "C"
  target := .base .integer
  supers := fun _ => none
  methods := fun m => if m = "m" then some (.ret (.const (.integer 0))) else none

def implD : ImplDecl where
  tparams := []
  dictParams := []
  cls := "D"
  target := .base .integer
  supers := fun s => if s = "C" then some (.dict "CInt" [] []) else none
  methods := fun m => if m = "n" then some (.ret (.const (.integer 1))) else none

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

theorem constSig_scoped : constSig.Scoped :=
  ⟨trivial, by simp [constSig, Ty.VarsIn], fun i hi => by simp [constSig, Eff.empty] at hi⟩

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
theorem const_body_typed (k : Int) {id : ImplDecl} (ht : id.target = .base .integer) :
    HasTypeC classProgram builtins StoreTy.empty ([] ++ id.tparams)
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
        exact ⟨_, by simp [implC, *], const_body_typed 0 rfl⟩
      · cases hm
    · intro s hs; simp [classC] at hs
  · refine ⟨classD, by simp [classProgram, implD], ?_, ?_, ?_, ?_⟩
    · intro m; by_cases hm : m = "n" <;> simp [implD, classD, hm]
    · intro s; by_cases hs : s = "C" <;> simp [implD, classD, hs]
    · intro m ms hm
      simp only [classD] at hm
      split at hm
      · cases hm
        exact ⟨_, by simp [implD, *], const_body_typed 1 rfl⟩
      · cases hm
    · intro s hs
      simp [classD] at hs
      subst hs
      refine ⟨.dict "CInt" [] [], by simp [implD], ?_⟩
      have := HasTypeV.V_Dict (P := classProgram) (B := builtins) (Ψ := StoreTy.empty) (C := [])
        (Γ := binds implD.dictTys) (i := "CInt") (ts := []) (vs := []) (id := implC)
        (by simp [classProgram]) ⟨rfl, fun _ _ _ h _ => by simp at h⟩ .nil
      simpa [implC, implD, Ty.subst, Ty.substAt] using this

theorem classProgram_effectsOk : classProgram.EffectsOk builtins :=
  ⟨fun _ _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

/-- `(DInt[]()↑C).m[;]()` の型付け。上位の型クラスの辞書を取り出してからメソッドを呼ぶ。 -/
theorem super_call_typed :
    HasTypeC classProgram builtins StoreTy.empty [] [] none
      (.meth (.super (.dict "DInt" [] []) "C") "m" [] [] []) (.base .integer) Eff.empty := by
  have hd : HasTypeV classProgram builtins StoreTy.empty [] [] (.dict "DInt" [] []) (.dict "D" (.base .integer)) := by
    have := HasTypeV.V_Dict (P := classProgram) (B := builtins) (Ψ := StoreTy.empty) (C := []) (Γ := [])
      (i := "DInt") (ts := []) (vs := []) (id := implD)
      (by simp [classProgram]) ⟨rfl, fun _ _ _ h _ => by simp at h⟩ .nil
    simpa [implD, Ty.subst, Ty.substAt] using this
  have hs := HasTypeV.V_Super (s := "C") (cd := classD) hd (by simp [classProgram]) (by simp [classD])
  have hm := HasTypeC.C_Meth (R := none) (m := "m") (ss := []) (es := []) (ws := []) (cd := classC)
    (ms := constSig) hs
    (by simp [classProgram]) (by simp [classC]) ⟨rfl, fun _ _ _ h _ => by simp at h⟩ rfl .nil
  refine .C_Sub hm ?_ ?_
  · simp [constSig, Ty.subst, Ty.substAt, Ty.shift]; exact Ty.Le.refl _
  · simp [constSig, Eff.substRho_empty]; exact Eff.Sub.refl _

/-- 型クラスのメソッドの呼び出しからの実行は、事象を伴う遷移をしない。 -/
example : ∀ s, Steps classProgram builtins
      (.run (.meth (.super (.dict "DInt" [] []) "C") "m" [] [] []) [] Store.empty) s →
    (∀ ev s', ¬ Step classProgram builtins s (some ev) s') ∧ ¬ UnhandledOp s :=
  effect_soundness classProgram_wellFormed classProgram_wellTyped classProgram_effectsOk
    (assumptions classProgram) super_call_typed
    (by simp [Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Ty.VarsInList, Val.VarsInList,
      Eff.RhosInList])

end Benitoite.Release.Model
