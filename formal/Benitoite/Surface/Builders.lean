import Benitoite.Surface.Syntax
import Benitoite.Surface.SingleFail
import Benitoite.Release.Admissible
import Benitoite.Release.FiniteSupport
import Benitoite.Release.Lemmas.Closed
import Benitoite.Release.Lemmas.Rename

/-!
# 局所構築器の分類とセル環境

通常変数と専用名の番号を共有し、専用名の位置だけを既存の Reference 型で埋める。
このモジュールは表層の型付けに依存しない（設計書 01-12「構築器の分類と環境の対応」）。
-/
namespace Benitoite.Surface
open Benitoite.Release

namespace BuilderCtx

@[simp] theorem kindAt_nil (i : Nat) : kindAt [] i = none := rfl
@[simp] theorem kindAt_zero (k : Option BuilderKind) (Δ : BuilderCtx) :
    kindAt (k :: Δ) 0 = k := rfl
@[simp] theorem kindAt_succ (k : Option BuilderKind) (Δ : BuilderCtx) (i : Nat) :
    kindAt (k :: Δ) (i + 1) = kindAt Δ i := rfl

/-- 専用位置は Γ の通常値として読めず、Γ の範囲内にある。 -/
def Aligned (Γ : List (Option Ty)) (Δ : BuilderCtx) : Prop :=
  Δ.length ≤ Γ.length ∧ ∀ i k, Δ.kindAt i = some k → Γ[i]? = some none

/-- 種類の内部にある通常の型に課す条件を、一つの持ち上げでそろえる。 -/
def All (p : Ty → Prop) (Δ : BuilderCtx) : Prop :=
  ∀ i k, Δ.kindAt i = some k → p k.contents

/-- 内容の型が型変数の範囲内にあり、継続型を含まない。 -/
def Clean (n : Nat) (Δ : BuilderCtx) : Prop := All (TyOK n) Δ
/-- 内容の型内部のエフェクトの原子が候補集合に含まれる。 -/
def AtomsIn (atoms : List Atom) (Δ : BuilderCtx) : Prop := All (Ty.Support (· ∈ atoms)) Δ
/-- 内容の型内部でも表層の単一 Fail の条件を満たす。 -/
def Single (Q : NoFailCtx) (Δ : BuilderCtx) : Prop := All (SingleTy Q) Δ

theorem aligned_empty (Γ : List (Option Ty)) : Aligned Γ [] := by
  exact ⟨by simp, by simp⟩

theorem aligned_value {Γ Δ} (h : Aligned Γ Δ) (t : Option Ty) :
    Aligned (t :: Γ) (none :: Δ) := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i k hi
  cases i with
  | zero => simp at hi
  | succ i => simpa using h.2 i k hi

theorem aligned_builder {Γ Δ} (h : Aligned Γ Δ) (k : BuilderKind) :
    Aligned (none :: Γ) (some k :: Δ) := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i l hi
  cases i with
  | zero => rfl
  | succ i => simpa using h.2 i l hi

theorem aligned_values {Γ Δ} (h : Aligned Γ Δ) (xs : List (Option Ty)) :
    Aligned (xs ++ Γ) (List.replicate xs.length none ++ Δ) := by
  induction xs with
  | nil => exact h
  | cons x xs ih => simpa only [List.length_cons, List.replicate_succ, List.cons_append] using aligned_value ih x

theorem all_empty (p : Ty → Prop) : All p [] := by simp [All]

theorem all_value {p Δ} (h : All p Δ) : All p (none :: Δ) := by
  intro i k hi
  cases i with
  | zero => simp at hi
  | succ i => exact h i k hi

theorem all_builder {p Δ k} (h : All p Δ) (hk : p k.contents) :
    All p (some k :: Δ) := by
  intro i l hi
  cases i with
  | zero => simpa using (Option.some.inj hi ▸ hk)
  | succ i => exact h i l hi

theorem all_values {p Δ} (h : All p Δ) (n : Nat) :
    All p (List.replicate n none ++ Δ) := by
  induction n with
  | zero => exact h
  | succ n ih => exact all_value ih

theorem clean_empty (n : Nat) : Clean n [] := all_empty _
theorem atomsIn_empty (atoms : List Atom) : AtomsIn atoms [] := all_empty _
theorem single_empty (Q : NoFailCtx) : Single Q [] := all_empty _
theorem clean_value {n Δ} (h : Clean n Δ) : Clean n (none :: Δ) := all_value h
theorem atomsIn_value {atoms Δ} (h : AtomsIn atoms Δ) : AtomsIn atoms (none :: Δ) := all_value h
theorem single_value {Q Δ} (h : Single Q Δ) : Single Q (none :: Δ) := all_value h
theorem clean_builder {n Δ k} (h : Clean n Δ) (hk : TyOK n k.contents) :
    Clean n (some k :: Δ) := all_builder h hk
theorem atomsIn_builder {atoms Δ k} (h : AtomsIn atoms Δ) (hk : Ty.Support (· ∈ atoms) k.contents) :
    AtomsIn atoms (some k :: Δ) := all_builder h hk
theorem single_builder {Q Δ k} (h : Single Q Δ) (hk : SingleTy Q k.contents) :
    Single Q (some k :: Δ) := all_builder h hk

theorem aligned_hideConts {Γ Δ} (h : Aligned Γ Δ) : Aligned (hideConts Γ) Δ := by
  refine ⟨by simpa only [hideConts_length] using h.1, ?_⟩
  intro i k hi
  simp only [hideConts, List.getElem?_map, h.2 i k hi, Option.map_some]

end BuilderCtx

/-- 分類表のない末尾は元の Γ を保つ。Γ の長さは変えない。 -/
def fillBuilders : List (Option Ty) → BuilderCtx → List (Option Ty)
  | [], _ => []
  | Γ, [] => Γ
  | t :: Γ, k :: Δ => (match k with | none => t | some k => some k.cell) :: fillBuilders Γ Δ

namespace fillBuilders

@[simp] theorem empty (Γ : List (Option Ty)) : fillBuilders Γ [] = Γ := by cases Γ <;> rfl
@[simp] theorem under_value (Γ : List (Option Ty)) (Δ : BuilderCtx) (t : Option Ty) :
    fillBuilders (t :: Γ) (none :: Δ) = t :: fillBuilders Γ Δ := rfl
@[simp] theorem under_builder (Γ : List (Option Ty)) (Δ : BuilderCtx) (k : BuilderKind) :
    fillBuilders (none :: Γ) (some k :: Δ) = some k.cell :: fillBuilders Γ Δ := rfl

theorem under_values (Γ : List (Option Ty)) (Δ : BuilderCtx) (xs : List (Option Ty)) :
    fillBuilders (xs ++ Γ) (List.replicate xs.length none ++ Δ) = xs ++ fillBuilders Γ Δ := by
  induction xs with
  | nil => rfl
  | cons x xs ih => simpa only [List.length_cons, List.replicate_succ, List.cons_append,
      under_value] using congrArg (List.cons x) ih

@[simp] theorem length (Γ : List (Option Ty)) (Δ : BuilderCtx) :
    (fillBuilders Γ Δ).length = Γ.length := by
  induction Γ generalizing Δ with
  | nil => rfl
  | cons t Γ ih => cases Δ with
    | nil => rfl
    | cons k Δ => simp only [fillBuilders, List.length_cons, ih]

theorem lookup (Γ : List (Option Ty)) (Δ : BuilderCtx) (i : Nat) :
    (fillBuilders Γ Δ)[i]? =
      (Γ[i]?).map (fun t => match Δ.kindAt i with | none => t | some k => some k.cell) := by
  induction Γ generalizing Δ i with
  | nil => simp [fillBuilders]
  | cons t Γ ih => cases Δ with
    | nil => simp [empty, BuilderCtx.kindAt]
    | cons k Δ => cases i with
      | zero => cases k <;> rfl
      | succ i => simpa only [fillBuilders, List.getElem?_cons_succ,
          BuilderCtx.kindAt_succ] using ih Δ i

theorem value_lookup {Γ Δ a} {i : Nat} (h : BuilderCtx.Aligned Γ Δ)
    (hi : Γ[i]? = some (some a)) : (fillBuilders Γ Δ)[i]? = some (some a) := by
  rw [lookup, hi]
  cases hk : Δ.kindAt i with
  | none => rfl
  | some k => have he := h.2 i k hk; rw [hi] at he; cases he

theorem cell_lookup {Γ Δ k} {i : Nat} (h : BuilderCtx.Aligned Γ Δ)
    (hi : Δ.kindAt i = some k) : (fillBuilders Γ Δ)[i]? = some (some k.cell) := by
  simp only [lookup, h.2 i k hi, Option.map_some, hi]

theorem renOk {Γ Δ} (h : BuilderCtx.Aligned Γ Δ) : RenOk Γ (fillBuilders Γ Δ) id :=
  fun _ _ hi => value_lookup h hi

end fillBuilders

theorem fillBuilders_hideConts (Γ : List (Option Ty)) (Δ : BuilderCtx) :
    fillBuilders (hideConts Γ) Δ = hideConts (fillBuilders Γ Δ) := by
  induction Γ generalizing Δ with
  | nil => rfl
  | cons t Γ ih => cases Δ with
    | nil => simp only [fillBuilders.empty]
    | cons k Δ =>
        cases k <;> simpa only [hideConts, List.map_cons, fillBuilders, BuilderKind.cell] using
          congrArg (List.cons _) (ih Δ)

/-! ## 宣言表から検査する参照先 -/

/-- 具体化前の宣言の条件と、具体化後の契約を分けて検査する。 -/
structure BuilderPrimRef.Valid (B : Builtins) (C : List TParam) (Q : NoFailCtx)
    (r : BuilderPrimRef) (kind : PrimKind) (names : List String) (ps : List Ty)
    (ret : Ty) (eff : Eff) (s : PrimSig) : Prop where
  declared : B.sig r.name = some s
  kind_eq : s.kind = kind
  namesWF : NamesWF s.names s.params
  signatureScoped : s.Scoped
  noRows : s.neffs = 0
  typeCount : r.types.length = s.ntys
  typeScope : ∀ t ∈ r.types, Ty.WF C.length t ∧ ∀ b a e, t ≠ .cont b a e
  admits : s.admits C r.types
  single : SingleTy Q (fnTy s.names s.params s.ret s.eff r.types [])
  shape : fnTy s.names s.params s.ret s.eff r.types [] = .fn names ps ret eff

/-- 組み込み参照の宣言と具体化後の契約の一致。 -/
def BuilderPrimRef.Ok (B : Builtins) (C : List TParam) (Q : NoFailCtx)
    (r : BuilderPrimRef) (kind : PrimKind) (names : List String) (ps : List Ty)
    (ret : Ty) (eff : Eff) : Prop := ∃ s, r.Valid B C Q kind names ps ret eff s

/-- 行のない通常関数の署名。辞書の不在は Valid で別に検査する。 -/
def BuilderFunScoped (d : FunDecl) : Prop :=
  NamesWF d.names d.params ∧
  Ty.VarsInList d.tparams.length (· < d.neffs) d.params ∧
  Ty.VarsIn d.tparams.length (· < d.neffs) d.ret ∧
  Eff.VarsIn d.tparams.length (· < d.neffs) d.eff

/-- 辞書も行引数もない通常関数の宣言と、具体化後の純粋な契約。 -/
structure BuilderPureRef.FunValid (D : Declarations) (B : Builtins) (C : List TParam)
    (Q : NoFailCtx) (f : FunName) (ts : List Ty) (names : List String)
    (ps : List Ty) (ret : Ty) (d : FunDecl) : Prop where
  declared : D.funs f = some d
  namesWF : NamesWF d.names d.params
  noDicts : d.dictParams = []
  signatureScoped : BuilderFunScoped d
  noRows : d.neffs = 0
  typeCount : ts.length = d.tparams.length
  typeScope : ∀ t ∈ ts, Ty.WF C.length t ∧ ∀ b a e, t ≠ .cont b a e
  sat : SatAll B C ts d.tparams
  single : SingleTy Q (fnTy d.names d.params d.ret d.eff ts [])
  shape : fnTy d.names d.params d.ret d.eff ts [] = .fn names ps ret Eff.empty

/-- 組み込みか通常関数の宣言を、その参照の種類に応じて検査する。 -/
def BuilderPureRef.Ok (D : Declarations) (B : Builtins) (C : List TParam)
    (Q : NoFailCtx) : BuilderPureRef → List String → List Ty → Ty → Prop
  | .prim r, names, ps, ret => r.Ok B C Q .pure names ps ret Eff.empty
  | .funRef f ts, names, ps, ret => ∃ d, FunValid D B C Q f ts names ps ret d

/-- 三つのセル操作は同じ内容の型を具体化し、State を保つ。 -/
def BuilderCellRefs.Ok (B : Builtins) (C : List TParam) (Q : NoFailCtx)
    (k : BuilderKind) (r : BuilderCellRefs) : Prop :=
  r.newRef.types = [k.contents] ∧ r.getRef.types = [k.contents] ∧ r.setRef.types = [k.contents] ∧
  r.newRef.Ok B C Q .refNew ["value"] [k.contents] k.cell (Eff.single stateEff) ∧
  r.getRef.Ok B C Q .refGet ["reference"] [k.cell] k.contents (Eff.single stateEff) ∧
  r.setRef.Ok B C Q .refSet ["reference", "value"] [k.cell, k.contents] (.base .unit) (Eff.single stateEff)

/-- 純粋な合成部分のラベル・型・効果も、参照先の宣言と照合する。 -/
def BuilderRefs.PureOk (D : Declarations) (B : Builtins) (C : List TParam) (Q : NoFailCtx) :
    BuilderRefs → Prop
  | .string _ add join len =>
      add.Ok D B C Q ["left", "right"] [.base .string, .base .string] (.base .string) ∧
      join.Ok D B C Q ["xs", "separator"] [.list (.base .string), .base .string] (.base .string) ∧
      len.Ok D B C Q ["s"] [.base .string] (.base .integer)
  | .list t _ append cat len =>
      append.Ok D B C Q ["xs", "x"] [.list t, t] (.list t) ∧
      cat.Ok D B C Q ["xs", "ys"] [.list t, .list t] (.list t) ∧
      len.Ok D B C Q ["xs"] [.list t] (.base .integer)
  | .bytes _ empty fromList cat len =>
      empty.Ok D B C Q [] [] .bytes ∧
      fromList.Ok D B C Q ["bs"] [.list (.base .byte)] .bytes ∧
      cat.Ok D B C Q ["a", "b"] [.bytes, .bytes] .bytes ∧
      len.Ok D B C Q ["b"] [.bytes] (.base .integer)

/-- 対象の専用位置と、その種類に必要な全参照の契約の検査。 -/
def BuilderRefs.Ok (D : Declarations) (B : Builtins) (C : List TParam) (Q : NoFailCtx)
    (Δ : BuilderCtx) (i : Nat) (r : BuilderRefs) : Prop :=
  Δ.kindAt i = some r.kind ∧ r.cells.Ok B C Q r.kind ∧ r.PureOk D B C Q

/-- 行の条件は Scoped と行数 0 から導き、呼び出し側 Q に追加の条件を課さない。 -/
theorem BuilderPrimRef.Valid.admissible {B C Q r kind names ps ret eff s}
    (h : BuilderPrimRef.Valid B C Q r kind names ps ret eff s) (Q' : NoFailCtx) :
    PrimitiveAdmissible C s Q' r.types [] :=
  .of_noRows h.signatureScoped h.noRows h.typeCount h.admits h.typeScope

theorem BuilderPureRef.FunValid.admissible {D B C Q f ts names ps ret d}
    (h : BuilderPureRef.FunValid D B C Q f ts names ps ret d) (Q' : NoFailCtx) :
    Admissible B C d.tparams d.neffs (Qsig d.params d.ret d.eff) Q' ts [] d.eff := by
  have hrows := Eff.VarsIn.rows d.eff h.signatureScoped.2.2.2
  have hqs := Qsig.varsIn_scoped h.signatureScoped.2.1 h.signatureScoped.2.2.1 h.signatureScoped.2.2.2
  rw [h.noRows] at hrows hqs
  exact ⟨h.sat, h.typeScope, h.noRows.symm, by simp, hrows, hqs,
    fun i hi => (Nat.not_lt_zero i (hqs i hi)).elim⟩

end Benitoite.Surface
