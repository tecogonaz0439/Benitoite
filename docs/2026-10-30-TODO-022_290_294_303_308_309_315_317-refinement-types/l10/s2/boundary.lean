import Lean
import Benitoite.Release.Refinement.NarrowingObstruction
import Benitoite.Release.Refinement.TypeArgumentRegularity
import Benitoite.Release.Refinement.TypeVariables
import Benitoite.Release.Refinement.TypeShiftFacts
import Benitoite.Release.Refinement.EffectFacts

namespace L10S2Boundary
open Benitoite.Release.Refinement

-- 本番の入口に対して、篩・外部型・依存列・非空の行とFailを使う。
def outerImage : Ty := .external (.mk 7)
  [.refined (.base .integer) (.eq (.var 0) (.var 1))]
def underImage : Ty := .external (.mk 7)
  [.refined (.base .integer) (.eq (.var 0) (.var 2))]
def signature : Tel := .param "x" (.tvar 0) (.done (.tvar 0) Eff.empty)

theorem outerImage_wf : outerImage.WF 0 0 1 := by
  exact ⟨⟨trivial, ⟨by decide, by decide⟩, by simp [Ty.NotContCore, Ty.core]⟩, trivial⟩
theorem outerImage_ordinary : Ordinary outerImage := by simp [outerImage, Ordinary, Ty.core]
theorem signature_wf : signature.WF 0 1 1 := ⟨by exact (by decide : 0 < 1), by exact (by decide : 0 < 1), trivial, rfl⟩

-- 像に同じ値置換を再適用せず、paramの下では外側の値参照1を2にする。
theorem dependent_raw_image :
    Tel.rawBind (typeEnvAt 0 [outerImage] []) signature =
      .param "x" outerImage (.done underImage Eff.empty) := by
  simp [signature, outerImage, underImage, Tel.rawBind, Ty.rawBind, typeEnvAt,
    SubstEnv.up, upValues_id, Eff.rawBind, substAtoms_nil, rowFails, instAtoms_nil,
    rawBindTys, Ty.shiftV, shiftVTys, predBind, termBind, termBind?, Eff.empty]

theorem dependent_subst_wf : ((Ty.dependentFn signature).subst [outerImage] []).WF 0 0 1 := by
  apply Ty.subst_wf [outerImage] []
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_wf
  · intro e he; cases he
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_ordinary
  · exact signature_wf

def withCutoff : Ty := .map (.tvar 0) (.external (.mk 8) [.tvar 1])

theorem retained_type_binder : withCutoff.rawBind (typeEnvAt 1 [outerImage] []) =
    .map (.tvar 0) (.external (.mk 8) [outerImage]) := rfl

theorem cutoff_subst_wf : (withCutoff.substAt 1 [outerImage] []).WF 0 1 1 := by
  apply Ty.substAt_wf 1 [outerImage] []
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_wf
  · intro e he; cases he
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_ordinary
  · exact ⟨by exact (by decide : 0 < 2), by exact (by decide : 1 < 2), trivial⟩

def allImages : SubstEnv :=
  ⟨fun _ => outerImage, [Eff.empty], [.based .cwd (.tree [])], fun | 0 => some (.integer 7) | _+1 => none⟩
def mixed : Ty := .refined (.external (.mk 9) [.tvar 0, .scoped "" .path (.rvar 0)])
  (.eq (.var 0) (.var 1))

theorem allImages_wf : allImages.WFImages 1 1 1 0 0 1 := by
  constructor
  · intro i hi; exact outerImage_wf
  · intro e he; cases List.mem_singleton.mp he; trivial
  · intro ix hi
    cases ix with
    | fixed r => trivial
    | rvar i =>
      have : i = 0 := by change i < 1 at hi; omega
      subst i
      trivial
  · intro i hi t ht
    have : i = 0 := by omega
    subst i
    cases ht
    trivial
  · intro i; exact outerImage_ordinary

theorem mixed_wf : mixed.WF 1 1 1 := by
  exact ⟨⟨by exact (by decide : 0 < 1), by exact (by decide : 0 < 1), trivial⟩, ⟨by decide, by decide⟩,
    by simp [Ty.NotContCore, Ty.core]⟩

theorem four_namespaces_raw : mixed.rawBind allImages =
    .refined (.external (.mk 9) [outerImage, .scoped "" .path (.fixed (.based .cwd (.tree [])))])
      (.eq (.var 0) (.integer 7)) := rfl

theorem four_namespaces_wf : (mixed.bind allImages).WF 0 0 1 :=
  Ty.bind_wf mixed mixed_wf allImages_wf

-- WFからCanonicalも、公開shiftの元との等号も出ない。
def nonnormal : Ty := .refined (.base .integer) .truth

theorem nonnormal_wf : nonnormal.WF 0 0 0 := by
  exact ⟨trivial, trivial, by simp [Ty.NotContCore, Ty.core]⟩
theorem nonnormal_norm : nonnormal.norm = .base .integer := rfl
theorem wf_not_canonical : ¬ nonnormal.Canonical := by
  intro h; change Ty.base .integer = Ty.refined (.base .integer) .truth at h; cases h
theorem raw_shift_identity : shiftTypes 3 0 nonnormal = nonnormal :=
  Ty.rawShift_of_wf 3 nonnormal nonnormal_wf
theorem public_shift_normalizes : nonnormal.shift 3 0 = .base .integer :=
  Ty.shift_of_wf 3 nonnormal nonnormal_wf
theorem public_shift_not_identity : nonnormal.shift 3 0 ≠ nonnormal := by
  rw [public_shift_normalizes]; intro h; cases h

-- 旧Le.wf/wf_revの無条件の移植も偽である。
def continuation : Ty := .cont (.base .unit) (.base .unit) Eff.empty

theorem continuation_wf : continuation.WF 0 0 0 := ⟨trivial, trivial, trivial, rfl⟩
theorem bad_refined_cont : ¬ (Ty.refined continuation .truth).WF 0 0 0 := by
  intro h
  exact h.2.2 _ _ _ rfl

theorem le_does_not_supply_target_wf (P : Program) :
    Ty.LeQ P [] [] continuation (.refined continuation .truth) :=
  .introduce trivial .truth

theorem le_does_not_supply_source_wf (P : Program) :
    Ty.LeQ P [] [] (.refined continuation .truth) continuation := .forget

-- WFの型像でも、Ordinaryを外すと篩の芯に継続が入る。
def badImageEnv : SubstEnv := ⟨fun _ => continuation, [], [], fun i => some (.var i)⟩
def selfEqual : Ty := .refined (.tvar 0) (.eq (.var 0) (.var 0))

theorem selfEqual_wf : selfEqual.WF 0 1 0 := by
  exact ⟨by exact (by decide : 0 < 1), ⟨by decide, by decide⟩, by simp [Ty.NotContCore, Ty.core]⟩
theorem bad_image_is_wf (i : Nat) : (badImageEnv.types i).WF 0 0 0 := continuation_wf
theorem bad_image_is_not_ordinary : ¬ Ordinary (badImageEnv.types 0) := by
  intro h; exact h _ _ _ rfl

theorem ordinary_needed_for_bind : ¬ (selfEqual.bind badImageEnv).WF 0 0 0 := by
  intro h
  -- WFだけでは結果の篩を認められない。述語のselfの種類はこのscopeの主張とは別である。
  change (Ty.refined continuation (.eq (.var 0) (.var 0))).WF 0 0 0 at h
  exact h.2.2 _ _ _ rfl

-- Fail内部とexternal/refined/dependentFnを通る行の再帰。
def row3 : Eff := Eff.row 3
def nestedRows : Ty := .external (.mk 10)
  [.refined (.dependentFn (.done (.base .unit) (.mk (fun _ => false)
    [.fn [] [] (.base .integer) row3]))) .truth]

theorem nested_rows_in : nestedRows.RowsIn (· < 4) := by
  refine ⟨⟨trivial, ?_⟩, trivial⟩
  constructor
  · intro i hi; cases hi
  · refine ⟨⟨trivial, trivial, ?_⟩, trivial⟩
    constructor
    · intro i hi
      have : i = 3 := of_decide_eq_true hi
      omega
    · trivial

theorem nested_rows_rejected : ¬ nestedRows.RowsIn (· < 3) := by
  intro h
  have hi := h.1.2.2.1.2.2.1 3 (by decide)
  omega

theorem nested_norm_rows_in : nestedRows.norm.RowsIn (· < 4) :=
  Ty.norm_rowsIn nestedRows nested_rows_in

def badRangeRow : Eff := .mk (fun a => decide (a = .name "" (.rvar 2))) []
theorem effect_wf_ignores_atom_ranges : badRangeRow.WF 0 0 0 := trivial

theorem badRangeRow_no_rows : badRangeRow.RowsIn (fun _ => False) := by
  constructor
  · intro i hi
    change false = true at hi
    cases hi
  · trivial

theorem range_atom_must_be_checked : ¬ badRangeRow.VarsIn 0 0 0 (fun _ => False) := by
  intro h
  have hx := h.2.2.1 "" (.rvar 2) (by decide)
  exact (by decide : ¬ 2 < 0) hx

theorem mixed_vars : mixed.VarsIn 1 1 1 (fun _ => False) :=
  ⟨mixed_wf, ⟨trivial, trivial, trivial⟩, ⟨trivial, by exact (by decide : 0 < 1), trivial⟩⟩
theorem mixed_norm_vars : mixed.norm.VarsIn 1 1 1 (fun _ => False) :=
  Ty.norm_VarsIn mixed mixed_vars

-- Failの不変性と、一原子のCoversを構造等号へ取り違えない。
theorem fail_does_not_forget_refinement :
    ¬ Eff.Sub (Eff.singleFail (.refined (.base .integer) .falsity)) (Eff.singleFail (.base .integer)) := by
  intro h
  have hf := h.2 (.refined (.base .integer) .falsity) ((Eff.memFail_singleFail _ _).mpr rfl)
  rw [Eff.memFail_singleFail] at hf
  cases hf

def topOnly : Eff := .mk (fun a => decide (a = .nameTop "")) []
def redundantAtom : Atom := .name "" (.fixed (.based .cwd (.tree [])))
def topAndExtra : Eff := .mk (fun a => decide (a = .nameTop "" ∨ a = redundantAtom)) []

theorem topOnly_canonical : topOnly.Canonical := rfl
theorem topAndExtra_canonical : topAndExtra.Canonical := rfl

theorem mutual_covers : Eff.Covers [] [] topOnly topAndExtra ∧ Eff.Covers [] [] topAndExtra topOnly := by
  constructor
  · constructor
    · intro a ha
      have ha : a = .nameTop "" ∨ a = redundantAtom := of_decide_eq_true ha
      refine ⟨.nameTop "", by decide, ?_⟩
      rcases ha with rfl | rfl
      · exact Atom.Covers.refl _
      · exact ⟨rfl, RangeExpr.top_covers _⟩
    · intro t ht; obtain ⟨_, hx, _⟩ := ht; cases hx
  · constructor
    · intro a ha
      have : a = .nameTop "" := of_decide_eq_true ha
      subst a
      exact ⟨.nameTop "", by decide, Atom.Covers.refl _⟩
    · intro t ht; obtain ⟨_, hx, _⟩ := ht; cases hx

theorem mutual_covers_not_equal : topOnly ≠ topAndExtra := by
  intro h
  have hx := congrArg (fun e => e.test redundantAtom) h
  change false = true at hx
  cases hx

theorem row_name_preserved :
    (Eff.substRho [Eff.singleFail outerImage] topAndExtra).mem redundantAtom :=
  Eff.substRho_name (by decide)

theorem empty_row_substitution : Eff.substRho [topAndExtra] Eff.empty = Eff.empty :=
  Eff.substRho_empty _

-- 両包含は順序や重複を区別しない。生の効果の等号には正規形が要る。
def duplicateFail : Eff := .mk (fun _ => false) [.base .unit, .base .unit]
def singleFail : Eff := .mk (fun _ => false) [.base .unit]

theorem mutual_sub : Eff.Sub duplicateFail singleFail ∧ Eff.Sub singleFail duplicateFail := by
  constructor <;> constructor
  · intro a ha; cases ha
  · intro t ht
    obtain ⟨x, hx, hxt⟩ := ht
    have hx : x = .base .unit := by simpa [duplicateFail, Eff.fails] using hx
    subst x
    exact ⟨.base .unit, by simp [singleFail, Eff.fails], hxt⟩
  · intro a ha; cases ha
  · intro t ht
    obtain ⟨x, hx, hxt⟩ := ht
    exact ⟨x, by simp only [singleFail, Eff.fails, List.mem_singleton] at hx; subst x; simp [duplicateFail, Eff.fails], hxt⟩

theorem unnormalized_sub_not_equal : duplicateFail ≠ singleFail := by
  intro h
  have hlen := congrArg (fun e => e.fails.length) h
  change 2 = 1 at hlen
  cases hlen

theorem normalized_sub_equal : duplicateFail.norm = singleFail.norm := by
  apply Eff.eq_of_sub_of_sub (Eff.norm_idem _) (Eff.norm_idem _)
  · exact Eff.sub_norm_right.mpr (Eff.sub_norm_left.mpr mutual_sub.1)
  · exact Eff.sub_norm_right.mpr (Eff.sub_norm_left.mpr mutual_sub.2)

def snapshot : PathEnv := ⟨[], [], [], none, none, none⟩
def pathKind : Benitoite.Release.EffName → Option Benitoite.Scope.Domain.Kind := fun _ => some .path

theorem based_permission : Eff.Allows snapshot pathKind topAndExtra "" (.path []) := by
  refine ⟨.path, .based .cwd (.tree []), rfl, by decide, ?_⟩
  decide

theorem based_permission_norm : Eff.Allows snapshot pathKind topAndExtra.norm "" (.path []) :=
  Eff.allows_norm.mpr based_permission

theorem kind_none_denies : ¬ Eff.Allows snapshot (fun _ => none) topOnly "" (.path []) := by
  rintro ⟨_, _, h, _⟩; cases h

theorem row_variable_denies : ¬ Eff.Allows snapshot pathKind (Eff.row 0) "" (.path []) := by
  rintro ⟨k, r, _, h, _⟩
  cases h

-- 行の像を再置換せず、そのFailに含まれる外側の値参照を保つ。
def insertedRow : Eff := .mk (fun a => decide (a = redundantAtom)) [outerImage]
def effectSource : Eff := .mk (fun a => decide (a = .rho 0)) [.external (.mk 11) [.tvar 0]]

theorem insertedRow_wf : insertedRow.WF 0 0 1 := ⟨outerImage_wf, trivial⟩
theorem effectSource_wf : effectSource.WF 0 1 1 :=
  ⟨⟨by exact (by decide : 0 < 1), trivial⟩, trivial⟩

theorem inserted_row_wf : (Eff.subst [outerImage] [insertedRow] effectSource).WF 0 0 1 := by
  apply Eff.subst_wf [outerImage] [insertedRow]
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_wf
  · intro e he; cases List.mem_singleton.mp he; exact insertedRow_wf
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_ordinary
  · exact effectSource_wf

theorem inserted_row_raw : Eff.rawBind (typeEnvAt 0 [outerImage] [insertedRow]) effectSource =
    .mk (fun a => decide (a = redundantAtom)) [.external (.mk 11) [outerImage], outerImage] := by
  change EffR.mk _ _ = EffR.mk _ _
  congr 1
  · funext a
    cases a <;> simp [insertedRow, typeEnvAt, instAtoms_nil, substAtoms,
      Eff.test, Eff.atoms, redundantAtom]

theorem range_wf_after_row_subst :
    (Eff.substAt 2 [outerImage] [insertedRow] topAndExtra).AtomsWF 0 := by
  apply Eff.substAt_atoms_wf
  · intro l ix hi
    have hi : Atom.name l ix = .nameTop "" ∨ Atom.name l ix = redundantAtom := of_decide_eq_true hi
    rcases hi with hi | hi <;> cases hi <;> trivial
  · intro e he; cases List.mem_singleton.mp he
    intro l ix hi
    have hi : Atom.name l ix = redundantAtom := of_decide_eq_true hi
    cases hi
    trivial

theorem list_subst_wf : Ty.WFList 0 0 1
    ([Ty.tvar 0, Ty.list (.tvar 0)].map (Ty.subst [outerImage] [])) := by
  apply Ty.substList_wf [outerImage] []
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_wf
  · intro e he; cases he
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_ordinary
  · exact ⟨by exact (by decide : 0 < 1), by exact (by decide : 0 < 1), trivial⟩

theorem type_shift_keeps_other_indices : shiftTypes 2 0 mixed =
    .refined (.external (.mk 9) [.tvar 2, .scoped "" .path (.rvar 0)])
      (.eq (.var 0) (.var 1)) := rfl

theorem shift_comparison : tyCompare (nonnormal.shift 2 0) ((Ty.base .integer).shift 2 0) = .eq := by
  rw [Ty.shift_compare_norm]
  exact (tyCompare_eq_iff _ _).mpr rfl

-- 行像のWFだけでは、生の潜在効果のCanonicalを保たない。
def latentRow : Ty := .fn [] [] (.base .unit) (Eff.row 0)
def duplicateEnv : SubstEnv := ⟨Ty.tvar, [duplicateFail], [], fun i => some (.var i)⟩

theorem latentRow_wf : latentRow.WF 0 0 0 := ⟨⟨rfl, by simp⟩, trivial, trivial, trivial, rfl⟩

theorem duplicateEnv_wf : duplicateEnv.WFImages 0 0 0 0 0 0 := by
  constructor
  · intro i hi; omega
  · intro e he; cases List.mem_singleton.mp he; exact ⟨trivial, trivial, trivial⟩
  · intro ix hi; simpa only [duplicateEnv, RangeIx.inst_nil] using hi
  · intro i hi; omega
  · intro i; simp [duplicateEnv, Ordinary, Ty.core]

theorem raw_bind_not_wf : ¬ (latentRow.rawBind duplicateEnv).WF 0 0 0 := by
  intro h
  have hc := h.2.2.2.2
  have hl := congrArg (fun e => e.fails.length) hc
  change 1 = 2 at hl
  cases hl

theorem normalized_bind_wf : (latentRow.bind duplicateEnv).WF 0 0 0 :=
  Ty.bind_wf latentRow latentRow_wf duplicateEnv_wf

-- RV-L10.s2: Topの許可、範囲変数、TopAtomsを同じ入口で対照する。
def oneAtom (a : Atom) : Eff := .mk (fun b => decide (b = a)) []
def otherSnapshot : PathEnv := ⟨[], ["x"], [], none, none, none⟩

theorem top_allows : Eff.Allows snapshot pathKind topOnly "" (.path []) :=
  ⟨.path, .top, rfl, by decide, by decide⟩

theorem range_variable_denies :
    ¬ Eff.Allows snapshot pathKind (oneAtom (.name "" (.rvar 0))) "" (.path []) := by
  rintro ⟨_, r, _, h, _⟩
  have : Atom.name "" (.fixed r) = .name "" (.rvar 0) := of_decide_eq_true h
  cases this

theorem secrets_unbound_denies :
    ¬ Eff.Allows snapshot pathKind (oneAtom (.name "" (.fixed .secrets))) "" (.path []) := by
  rintro ⟨k, r, _, h, hm⟩
  have : Atom.name "" (.fixed r) = .name "" (.fixed .secrets) := of_decide_eq_true h
  cases this
  exact hm.2.elim

theorem snapshot_changes_permission :
    Eff.Allows snapshot pathKind (oneAtom redundantAtom) "" (.path ["y"]) ∧
    ¬ Eff.Allows otherSnapshot pathKind (oneAtom redundantAtom) "" (.path ["y"]) := by
  constructor
  · exact ⟨.path, .based .cwd (.tree []), rfl, by decide, by decide⟩
  · rintro ⟨k, r, hk, h, hm⟩
    have : Atom.name "" (.fixed r) = redundantAtom := of_decide_eq_true h
    cases this
    cases hk
    revert hm
    decide

def topWithNestedNonTop : Eff := .mk (fun a => decide (a = .nameTop ""))
  [.fn [] [] (.base .unit) (oneAtom redundantAtom)]

theorem top_atoms_ignores_fail : topWithNestedNonTop.TopAtoms := by
  intro a ha
  have : a = .nameTop "" := of_decide_eq_true ha
  subst a
  rfl

theorem top_atoms_norm : topWithNestedNonTop.norm.TopAtoms := top_atoms_ignores_fail.norm

theorem top_atoms_rejects_based : ¬ (oneAtom redundantAtom).TopAtoms := by
  intro h
  have hc := h redundantAtom (by decide)
  cases hc

-- constructor kindの型引数は、valueの条件の追加後も受け入れる。
theorem constructor_kind_argument (P : Program) :
    TypeArgsKinded P [] [.ctor .list] [.constructor 1] := by
  refine ⟨rfl, [], rfl, ?_⟩
  intro i a k ha hk
  cases i with
  | zero =>
    cases ha; cases hk
    exact ⟨rfl, by intro h; cases h⟩
  | succ i => cases ha

-- rv-s2-t1と同じ操作宣言と継続型を使う。
def reviewOp : OpDecl := ⟨"L", [{}], [], [], .tvar 0, []⟩
def reviewProgram : Program := ⟨fun _ => none, fun _ => none,
  fun o => if o = "o" then some reviewOp else none,
  fun _ => none, fun _ => none, fun _ => none, [], fun _ => none⟩

theorem continuation_arg_rejected (B : Builtins) (Ψ : StoreTy) (Q : Benitoite.Release.NoFailCtx) (a : Ty) :
    ¬ HasTypeVQ reviewProgram B Ψ Q [] [] [] (.op "o" [continuation]) a := by
  intro h
  exact (h.op_typeScope continuation List.mem_cons_self).2 _ _ _ rfl

theorem continuation_instance_rejected :
    ¬ SignatureInstance reviewProgram [] [] reviewOp.tel [.value] [continuation] [] := by
  intro h
  exact h.ordinary continuation List.mem_cons_self _ _ _ rfl

theorem review_body_typed (P B Ψ Q) :
    HasTypeVQ P B Ψ Q [{}] [some (.tvar 0)] [] (.var 0) (.tvar 0) :=
  .V_Var rfl (by simp [Ordinary, Ty.core])

-- 元の無条件の置換の反例は残るが、新しい操作の入力にはならない。
theorem review_unrestricted_subst_false (P B Ψ Q) (a : Ty) :
    ¬ HasTypeVQ P B Ψ Q [] (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 [continuation] [])) []
      (Val.substTyAt 0 [continuation] [] (.var 0)) a := by
  intro h
  obtain ⟨b, hb, ho⟩ := h.variable_origin
  have ht : (Ty.tvar 0).bind (typeEnvAt 0 [continuation] []) = continuation := rfl
  simp only [Ctx.bindTypes, List.map_cons, List.map_nil, Option.map_some, ht] at hb
  have : b = continuation := by simpa using hb.symm
  subst b
  exact ho _ _ _ rfl

def unitTy : Ty := .base .unit

theorem unit_annotations (P : Program) : Ty.Annotation P [] [] unitTy := ⟨trivial, trivial, trivial⟩

theorem unit_arguments (P : Program) (n : Nat) :
    TypeArgsKinded P [] (List.replicate n unitTy) (List.replicate n .value) := by
  refine ⟨by simp, [], rfl, ?_⟩
  intro i a k ha hk
  have ha' := (List.mem_replicate.mp (List.mem_of_getElem? ha)).2
  have hk' := (List.mem_replicate.mp (List.mem_of_getElem? hk)).2
  subst a; subst k
  exact ⟨trivial, fun _ => by simp [unitTy, Ordinary, Ty.core]⟩

def reviewEffect : Eff := .mk
  (fun a => match a with | .name n (.fixed .top) => decide (n = "L") | _ => false) []

theorem safe_op_tel : ∃ e : Eff, instantiatedTel reviewOp.tel [unitTy] [] = .done unitTy e ∧
    e.fails = [] ∧ e.Canonical := by
  refine ⟨(Eff.rawBind (typeEnvAt 0 [unitTy] []) reviewEffect).norm, ?_, rfl, Eff.norm_idem _⟩
  have ht : reviewOp.tel = .done (.tvar 0) reviewEffect := rfl
  simp only [instantiatedTel, Tel.bind, ht, Tel.rawBind, Ty.rawBind, Tel.norm]
  rfl

theorem safe_op_instance : SignatureInstance reviewProgram [] [] reviewOp.tel [.value] [unitTy] [] := by
  refine ⟨⟨by exact (by decide : 0 < 1), trivial, rfl⟩, ?_, unit_arguments _ 1, ?_, ?_⟩
  · intro t ht; cases List.mem_singleton.mp ht; exact unit_annotations _
  · intro e he; cases he
  · obtain ⟨e, he, hf, hc⟩ := safe_op_tel
    rw [he]
    cases e with
    | mk atoms fs =>
      cases hf
      exact ⟨⟨trivial, trivial, hc⟩, ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩

theorem safe_op_typed (B : Builtins) (hb : B.CoreAssumptions reviewProgram) (Ψ : StoreTy) (Q : Benitoite.Release.NoFailCtx) :
    HasTypeVQ reviewProgram B Ψ Q [] [] [] (.op "o" [unitTy])
      (.dependentFn (instantiatedTel reviewOp.tel [unitTy] [])) := by
  refine .V_Op (od := reviewOp) rfl (by simp [NamesWF, reviewOp]) ⟨rfl, ?_⟩ safe_op_instance
  intro i t p ht hp
  cases i with
  | zero => cases ht; cases hp; exact hb.sat_unconstrained unitTy trivial
  | succ i => cases ht

theorem safe_operation_body (B : Builtins) (hb : B.CoreAssumptions reviewProgram) (Ψ : StoreTy) (Q : Benitoite.Release.NoFailCtx) :
    HasTypeCQ reviewProgram B Ψ Q []
      (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 [unitTy] [])) [] none
      ((Clause.mk (.user "o") 1 1 (.ret (.var 0))).body.substTy [unitTy] [])
      ((Ty.tvar 0).subst [unitTy] []) Eff.empty [] :=
  (safe_op_typed B hb Ψ Q).op_return_subst

theorem safe_operation_type (B : Builtins) (hb : B.CoreAssumptions reviewProgram) (Ψ : StoreTy) (Q : Benitoite.Release.NoFailCtx) :
    ((Ty.refined (.tvar 0) (.eq (.var 0) (.var 0))).subst [unitTy] []).WF 0 0 0 :=
  (safe_op_typed B hb Ψ Q).op_subst_wf ⟨by exact (by decide : 0 < 1),
    ⟨by decide, by decide⟩, by simp [Ty.NotContCore, Ty.core]⟩

theorem safe_operation_le (B : Builtins) (hb : B.CoreAssumptions reviewProgram) (Ψ : StoreTy) (Q : Benitoite.Release.NoFailCtx) :
    Ty.LeQ reviewProgram (Ctx.bindTypes [] (typeEnvAt 0 [unitTy] [])) []
      ((Ty.refined (.tvar 0) .truth).subst [unitTy] []) ((Ty.tvar 0).subst [unitTy] []) :=
  (safe_op_typed B hb Ψ Q).op_subst_le .forget

-- Telの公開包装と、型束縛が置換範囲に入らない場合の正規化。
theorem tel_subst_preserves_wf : (Tel.substAt 0 [outerImage] [] signature).WF 0 0 1 := by
  apply Tel.substAt_wf 0 [outerImage] []
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_wf
  · intro e he; cases he
  · intro a ha; cases List.mem_singleton.mp ha; exact outerImage_ordinary
  · exact signature_wf

theorem closed_type_subst_normalizes : nonnormal.substAt 0 [continuation] [] = .base .integer :=
  Ty.substAt_nil_of_wf [continuation] nonnormal nonnormal_wf

theorem closed_tel_subst_normalizes :
    Tel.substAt 0 [continuation] [] (.done nonnormal Eff.empty) = Tel.norm (.done nonnormal Eff.empty) :=
  Tel.substAt_nil_of_wf [continuation] _ ⟨nonnormal_wf, trivial, rfl⟩

-- 継続は型引数とは別の文脈の束縛として引き続き使える。
theorem continuation_resume (P B Ψ Q) (hc : ConstOK B .unit) :
    HasTypeCQ P B Ψ Q [] [some continuation] [] none
      (.resume (.var 0) (.const .unit)) unitTy Eff.empty [] :=
  .C_Resume rfl (.V_Const hc) trivial

-- E_Methの本体の列ss++tsへ、同じメソッド呼出しから像の条件を渡す。
theorem method_body_wf {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D} {a : Ty}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D)
    (ha : a.WF 0 (ss++ts).length Γ.length) :
    (a.subst (ss++ts) es).WF 0 C.length Γ.length := h.method_subst_wf ha

theorem method_body_le {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D a b}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D)
    (hl : Ty.LeQ P Γ Φ a b) :
    Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 (ss++ts) es)) Φ
      (a.subst (ss++ts) es) (b.subst (ss++ts) es) := h.method_subst_le hl

theorem method_body_return {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D) :
    HasTypeCQ P B Ψ Q C (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 (ss++ts) es)) Φ none
      ((Comp.ret (.var 0)).substTy (ss++ts) es) ((Ty.tvar 0).subst (ss++ts) es) Eff.empty [] :=
  h.method_return_subst

theorem raise_continuation_rejected (P B Ψ Q) (a : Ty) :
    ¬ HasTypeVQ P B Ψ Q [] [] [] (.raise unitTy continuation) a := by
  intro h
  exact (h.raise_typeScope rfl).2.2 _ _ _ rfl

def reviewMethod : MethSig := ⟨[{}], 0, [], [], .tvar 0, Eff.empty⟩
def reviewClass : ClassDecl := ⟨.value, [], fun m => if m = "m" then some reviewMethod else none⟩
def reviewImpl : ImplDecl := ⟨[{}], [], "C", unitTy, fun _ => none,
  fun m => if m = "m" then some (.ret (.const .unit)) else none⟩
def methodProgram : Program := ⟨fun _ => none, fun _ => none, fun _ => none, fun _ => none,
  fun c => if c = "C" then some reviewClass else none,
  fun i => if i = "I" then some reviewImpl else none, [], fun _ => none⟩

theorem method_instantiation : instantiatedTel reviewMethod.tel [unitTy, unitTy] [] =
    .done unitTy Eff.empty := by
  simp [instantiatedTel, MethSig.tel, signatureTel, reviewMethod, Tel.bind, Tel.rawBind,
    Ty.rawBind, typeEnvAt, unitTy, Ty.norm, Tel.norm, Eff.rawBind, Eff.norm, Eff.empty,
    substAtoms_nil, rowFails, instAtoms_nil]

theorem safe_method_instance : SignatureInstance methodProgram [] [] reviewMethod.tel
    [.value, .value] [unitTy, unitTy] [] := by
  refine ⟨⟨by exact (by decide : 0 < 2), trivial, rfl⟩, ?_, unit_arguments _ 2, ?_, ?_⟩
  · intro t ht
    have : t = unitTy := by simpa using ht
    subst t; exact unit_annotations _
  · intro e he; cases he
  · rw [method_instantiation]
    exact ⟨⟨trivial, trivial, rfl⟩, ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩

theorem safe_dictionary (B : Builtins) (hb : B.CoreAssumptions methodProgram) (Ψ Q) :
    HasTypeVQ methodProgram B Ψ Q [] [] [] (.dict "I" [unitTy] []) (.dict "C" unitTy) := by
  refine .V_Dict (id := reviewImpl) rfl ⟨rfl, ?_⟩ ?_ (unit_arguments _ 1) ?_ trivial .nil ?_
  · intro i t p ht hp
    cases i with
    | zero => cases ht; cases hp; exact hb.sat_unconstrained unitTy trivial
    | succ i => cases ht
  · intro t ht; cases List.mem_singleton.mp ht; exact unit_annotations _
  · intro a ha; cases ha
  · exact ⟨trivial, trivial, trivial⟩

theorem safe_method_typed (B : Builtins) (hb : B.CoreAssumptions methodProgram) (Ψ Q) :
    HasTypeCQ methodProgram B Ψ Q [] [] [] none
      (.meth (.dict "I" [unitTy] []) "m" [unitTy] [] []) unitTy Eff.empty [] := by
  refine .C_Meth (cd := reviewClass) (ms := reviewMethod) (τ := unitTy)
    (safe_dictionary B hb Ψ Q) rfl rfl (by simp [NamesWF, reviewMethod]) ⟨rfl, ?_⟩ safe_method_instance ?_ ?_ .nil (unit_annotations _)
  · intro i t p ht hp
    cases i with
    | zero => cases ht; cases hp; exact hb.sat_unconstrained unitTy trivial
    | succ i => cases ht
  · refine ⟨rfl, ?_, ⟨?_, trivial⟩, ?_, ?_⟩
    · intro e he; cases he
    · intro i hi; cases hi
    · intro i hi; simp [Qsig, QTys, QTy, QEff, reviewMethod, Eff.empty, Benitoite.Release.Qempty] at hi
    · intro i hi; simp [Qsig, QTys, QTy, QEff, reviewMethod, Eff.empty, Benitoite.Release.Qempty] at hi
  · change Tel.arguments (instantiatedTel reviewMethod.tel [unitTy, unitTy] []) [] = _
    rw [method_instantiation]; simp [Tel.arguments, unitTy, Ty.norm, Eff.norm, Eff.empty]

theorem safe_method_body (B : Builtins) (hb : B.CoreAssumptions methodProgram) (Ψ Q) :
    HasTypeCQ methodProgram B Ψ Q []
      (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 ([unitTy]++[unitTy]) [])) [] none
      ((Comp.ret (.var 0)).substTy ([unitTy]++[unitTy]) [])
      ((Ty.tvar 0).subst ([unitTy]++[unitTy]) []) Eff.empty [] :=
  (safe_method_typed B hb Ψ Q).method_return_subst

theorem safe_method_type (B : Builtins) (hb : B.CoreAssumptions methodProgram)
    (Ψ : StoreTy) (Q : Benitoite.Release.NoFailCtx) :
    ((Ty.refined (.tvar 1) (.eq (.var 0) (.var 0))).subst ([unitTy]++[unitTy]) []).WF 0 0 0 :=
  (safe_method_typed B hb Ψ Q).method_subst_wf ⟨by exact (by decide : 1 < 2),
    ⟨by decide, by decide⟩, by simp [Ty.NotContCore, Ty.core]⟩

theorem safe_method_le (B : Builtins) (hb : B.CoreAssumptions methodProgram)
    (Ψ : StoreTy) (Q : Benitoite.Release.NoFailCtx) :
    Ty.LeQ methodProgram (Ctx.bindTypes [] (typeEnvAt 0 ([unitTy]++[unitTy]) [])) []
      ((Ty.refined (.tvar 1) .truth).subst ([unitTy]++[unitTy]) [])
      ((Ty.tvar 1).subst ([unitTy]++[unitTy]) []) :=
  (safe_method_typed B hb Ψ Q).method_subst_le .forget

-- 結果型Unitとエラー型Integerを分け、E_OpFailの実際の像[T]へ公開補題を使う。
theorem raise_result_subst_wf {P B Ψ Q C Γ Φ T}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.raise unitTy (.base .integer)) T) :
    ((Ty.tvar 0).subst [unitTy] []).WF 0 C.length Γ.length :=
  h.raise_subst_wf (by exact (by decide : 0 < 1))

theorem raise_result_subst_le {P B Ψ Q C Γ Φ T}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.raise unitTy (.base .integer)) T) :
    Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 [unitTy] [])) Φ
      ((Ty.refined (.tvar 0) .truth).subst [unitTy] []) ((Ty.tvar 0).subst [unitTy] []) :=
  h.raise_subst_le .forget

-- 型変数を持つ旧入力でも、VarsInからNotContを供給できる。
theorem legacy_open_argument_notCont :
    ∀ a ∈ [Benitoite.Release.Ty.tvar 0], a.NotCont :=
  notCont_of_legacyVarsInList (nr := 0) (nt := 1) (pe := fun _ => True)
    ⟨by exact (by decide : 0 < 1), trivial⟩

end L10S2Boundary

-- 全境界宣言の公理依存。匿名exampleではなく名前付きの言明を監査する。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if name.toString.startsWith "L10S2Boundary." then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"LOCAL_CONSTANTS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
