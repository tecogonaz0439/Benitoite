import Benitoite.Release.SubstEnv
import Benitoite.Release.TypeCongruence
import Benitoite.Release.TypeVariables

/-!
# 範囲内の型と行の代入

一般の合成から、宣言の束縛数で制限した代入と閉じた型の恒等性を導く
（設計書 01-12「コア計算と脱糖」）。
-/

namespace Benitoite.Release

theorem Eff.substRho_true {es : List Eff} {ε : Eff} {a : Atom} :
    Eff.mem (Eff.substRho es ε) a ↔
      ((match a with
        | .name l => Eff.mem ε (.name l)
        | .rho k => es.length ≤ k ∧ Eff.mem ε (.rho k)) ∨
       ∃ i e, es[i]? = some e ∧ Eff.mem ε (.rho i) ∧ Eff.mem e a) := by
  rw [Eff.substRho_eq_bind, Eff.bind, Eff.mem_norm, Eff.mem_rawBind]
  exact Eff.mem_substAtoms es ε a

theorem Eff.substRho_true_scoped {es : List Eff} {ε : Eff} (h : Eff.RhosIn (· < es.length) ε)
    {a : Atom} :
    Eff.mem (Eff.substRho es ε) a ↔
      ((∃ l, a = .name l ∧ Eff.mem ε (.name l)) ∨
        ∃ i e, es[i]? = some e ∧ Eff.mem ε (.rho i) ∧ Eff.mem e a) := by
  rw [Eff.substRho_true]
  apply or_congr _ Iff.rfl
  cases a with
  | name l => simp
  | rho k =>
    simp only [reduceCtorEq, false_and, exists_false, iff_false, not_and]
    intro hk hε
    have := h.top k hε
    omega

/-- 再帰的な範囲から、切り詰めた合成列でも同じ結果を得る。 -/
theorem Eff.substRho_comp {es es' : List Eff} {ε : Eff} (h : Eff.RhosIn (· < es.length) ε) :
    Eff.substRho es' (Eff.substRho es ε) = Eff.substRho (es.map (Eff.substRho es')) ε := by
  rw [Eff.substRho_composeRows]
  apply Eff.substRho_congr_rows
  apply Eff.RowsIn.mono (e := ε) (h := h)
  intro i hi
  rw [Eff.rowImage_composeRows]
  simp [Eff.rowImage, List.getElem?_map, List.getElem?_eq_getElem hi]

/-- 閉じた型への代入は、型内部の正規形を含めて恒等である。 -/
theorem Ty.substAt_of_closed {c : Nat} (ts : List Ty) (es : List Eff)
    (a : Ty) (h : Ty.VarsIn c (fun _ => False) a) : a.substAt c ts es = a := by
  rw [Ty.substAt_eq_bind]
  have hc : Ty.bind (SubstEnv.at c ts es) a = Ty.bind SubstEnv.identity a := by
    apply Ty.bind_congr_scoped (n := c)
    · intro i hi
      simp only [SubstEnv.at, SubstEnv.identity, hi, ↓reduceIte]
    · exact Ty.WF.raw a (Ty.VarsIn.wf a h)
    · exact Ty.RowsIn.mono (fun _ hi => hi.elim) a (Ty.VarsIn.rows a h)
  rw [hc, Ty.bind_identity, (Ty.VarsIn.wf a h).canonical a]

theorem Ty.substAtList_of_closed {c : Nat} (ts : List Ty) (es : List Eff)
    (as : List Ty) (h : Ty.VarsInList c (fun _ => False) as) :
    as.map (Ty.substAt c ts es) = as := by
  calc
    _ = as.map id := List.map_congr_left (fun a ha =>
      Ty.substAt_of_closed ts es a (Ty.VarsInList.iff.mp h a ha))
    _ = as := List.map_id as

/-- 型と行の像を同時に置き換える、宣言の範囲での合成。 -/
theorem Ty.subst_comp {ts : List Ty} {es : List Eff} (c : Nat) (ts' : List Ty) (es' : List Eff)
    (a : Ty) (h : Ty.VarsIn ts.length (· < es.length) a) :
    Ty.substAt c ts' es' (Ty.subst ts es a) =
      Ty.subst (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substAt c ts' es')) a := by
  simp only [Ty.subst, Ty.substAt_eq_bind]
  rw [Ty.bind_comp]
  apply Ty.bind_congr_scoped (n := ts.length)
  · intro i hi
    simp only [SubstEnv.compose, SubstEnv.at, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero,
      hi, List.getElem?_eq_getElem hi, Option.getD_some, Ty.rawShift_zero,
      List.length_map, List.getElem?_map, Option.map_some]
    rw [Ty.substAt_eq_bind]
    rfl
  · exact Ty.WF.raw a (Ty.VarsIn.wf a h)
  · apply Ty.RowsIn.mono (h := Ty.VarsIn.rows a h)
    intro i hi
    rw [Eff.rowImage_compose]
    simp only [Eff.rowImage, SubstEnv.at, List.getElem?_map, List.getElem?_eq_getElem hi,
      Option.map_some, Option.getD_some, Eff.rawShift_zero, List.map_map, Function.comp_apply,
      Eff.rawShift_zero]
    rfl

theorem Ty.subst_comp_list {ts : List Ty} {es : List Eff} (c : Nat) (ts' : List Ty) (es' : List Eff)
    (as : List Ty) (h : Ty.VarsInList ts.length (· < es.length) as) :
    (as.map (Ty.subst ts es)).map (Ty.substAt c ts' es') =
      as.map (Ty.subst (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substAt c ts' es'))) := by
  simp only [List.map_map]
  exact List.map_congr_left (fun a ha => Ty.subst_comp c ts' es' a (Ty.VarsInList.iff.mp h a ha))

/-- cutoff より内側の像は、閉じた型を用いると移動なしに読める。 -/
theorem SubstEnv.at_type_closed (c : Nat) (ts : List Ty) (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF 0 t) (i : Nat) :
    (SubstEnv.at c ts es).types i =
      if i < c then .tvar i
      else if hi : i - c < ts.length then ts[i - c]
      else .tvar (i - ts.length) := by
  dsimp only [SubstEnv.at]
  split
  · rfl
  · split
    · rename_i hi
      rw [List.getElem?_eq_getElem hi, Option.getD_some,
        Ty.rawShift_of_wf c _ (hts _ (List.getElem_mem hi))]
    · rfl

/-- 型の像は、移動と cutoff 付き代入を入れ替えても一致する。 -/
theorem SubstEnv.shift_at_types {c k : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF 0 t) :
    ((SubstEnv.shift k 0).compose (SubstEnv.at (c + k) ts es)).types =
      ((SubstEnv.at c ts es).compose (SubstEnv.shift k 0)).types := by
  funext i
  change Ty.bind (SubstEnv.at (c + k) ts es) (.tvar (i + k)) =
    Ty.bind (SubstEnv.shift k 0) ((SubstEnv.at c ts es).types i)
  rw [← Ty.substAt_eq_bind, SubstEnv.at_type_closed c ts es hts i]
  simp only [Ty.substAt]
  by_cases hc : i < c
  · have hc' : i + k < c + k := by omega
    simp only [hc, hc', ↓reduceIte, ← Ty.shift_eq_bind, Ty.shift, Nat.not_lt_zero]
  · have hc' : ¬ i + k < c + k := by omega
    have he : i + k - (c + k) = i - c := by omega
    simp only [hc, hc', ↓reduceIte, he]
    by_cases hi : i - c < ts.length
    · simp only [hi, ↓reduceDIte, ↓reduceIte, List.getElem?_eq_getElem hi, Option.getD_some, ← Ty.shift_eq_bind]
      rw [Ty.shift_of_wf _ _ (hts _ (List.getElem_mem hi)),
        Ty.shift_of_wf _ _ (hts _ (List.getElem_mem hi))]
    · simp only [hi, ↓reduceDIte, ↓reduceIte, ← Ty.shift_eq_bind, Ty.shift, Nat.not_lt_zero]
      congr 1
      omega

/-- 閉じた行の型の像も、移動と代入の入れ替えで一致する。 -/
theorem Eff.shift_at_rowImages {c k : Nat} {ts : List Ty} (es : List Eff)
    (hes : ∀ e ∈ es, Eff.WF 0 e) (i : Nat) :
    Eff.rowImage ((SubstEnv.shift k 0).compose (SubstEnv.at (c + k) ts es)).rows i =
      Eff.rowImage ((SubstEnv.at c ts es).compose (SubstEnv.shift k 0)).rows i := by
  rw [Eff.rowImage_compose, Eff.rowImage_compose]
  change Eff.bind (SubstEnv.at (c + k) ts es) (Eff.row i) =
    Eff.bind (SubstEnv.shift k 0) (Eff.rowImage (es.map (Eff.rawShift c 0)) i)
  rw [Eff.bind_row]
  by_cases hi : i < es.length
  · simp only [Eff.rowImage, SubstEnv.at, List.getElem?_map, List.getElem?_eq_getElem hi,
      Option.map_some, Option.getD_some]
    rw [Eff.rawShift_of_wf _ _ (hes _ (List.getElem_mem hi)),
      Eff.rawShift_of_wf _ _ (hes _ (List.getElem_mem hi))]
    change Eff.norm es[i] = Eff.norm (Eff.rawBind (SubstEnv.shift k 0) es[i])
    rw [← Eff.rawShift_eq_rawBind, Eff.rawShift_of_wf _ _ (hes _ (List.getElem_mem hi))]
  · have he : es[i]? = none := List.getElem?_eq_none (by omega)
    simp only [Eff.rowImage, SubstEnv.at, List.getElem?_map, he, Option.map_none,
      Option.getD_none]
    rw [Eff.bind_row]
    rfl

/-- 移動と代入の交換。行の像内部の型も閉じていることを要求する。 -/
theorem Ty.shift_substAt {c k : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF 0 t) (hes : ∀ e ∈ es, Eff.WF 0 e) (a : Ty) :
    (a.shift k 0).substAt (c + k) ts es = (a.substAt c ts es).shift k 0 := by
  simp only [Ty.shift_eq_bind, Ty.substAt_eq_bind, Ty.bind_comp]
  apply Ty.bind_congr_rows
  · exact SubstEnv.shift_at_types es hts
  · have hall : ∀ t : Ty, t.RowsIn (fun i =>
        Eff.rowImage ((SubstEnv.shift k 0).compose (SubstEnv.at (c + k) ts es)).rows i =
          Eff.rowImage ((SubstEnv.at c ts es).compose (SubstEnv.shift k 0)).rows i) := by
      intro t
      exact Ty.RowsIn.mono (fun i _ => Eff.shift_at_rowImages es hes i) t (Ty.rowsIn_true t)
    exact hall a

/-- 代入後の Fail 列は、元の型への代入と、選んだ行の像の連結を正規化したものである。 -/
theorem Eff.substAt_fails (c : Nat) (ts : List Ty) (es : List Eff) (e : Eff) :
    (Eff.substAt c ts es e).fails = Order.sortUnique tyCompare
      (Ty.substTysAt c ts es e.fails ++
        Ty.normTys (Eff.rowFails (es.map (Eff.rawShift c 0)) e.atoms)) := by
  cases e with
  | mk a fs =>
    simp only [Eff.substAt, Eff.rawSubstAt, Eff.rawBind, Eff.norm, Eff.fails,
      Ty.normTys_append, Eff.atoms, SubstEnv.at, Ty.substTysAt_eq_rawBindTys]

/-- 型の変数が cutoff より内側なら、型の列だけの代入は恒等である。 -/
theorem Ty.substAt_nil_of_wf {c : Nat} (ts : List Ty) (a : Ty) (h : Ty.WF c a) :
    a.substAt c ts [] = a := by
  rw [Ty.substAt_eq_bind]
  have hc : Ty.bind (SubstEnv.at c ts []) a = Ty.bind SubstEnv.identity a := by
    apply Ty.bind_congr_scoped (n := c)
    · intro i hi
      simp only [SubstEnv.at, SubstEnv.identity, hi, ↓reduceIte]
    · exact Ty.WF.raw a h
    · exact Ty.RowsIn.mono (fun _ _ => rfl) a (Ty.rowsIn_true a)
  rw [hc, Ty.bind_identity, h.canonical a]

theorem Ty.substAtList_nil_of_wf {c : Nat} (ts : List Ty) (as : List Ty) (h : Ty.WFList c as) :
    as.map (Ty.substAt c ts []) = as := by
  calc
    _ = as.map id := List.map_congr_left (fun a ha => Ty.substAt_nil_of_wf ts a (Ty.WFList.iff.mp h a ha))
    _ = as := List.map_id as

/-- 空の行置換は正規化だけを行う。 -/
theorem Eff.substRho_nil_norm (e : Eff) : Eff.substRho [] e = Eff.norm e := by
  rw [Eff.substRho_eq_bind]
  exact Eff.bind_identity e

/-- 空の行置換の恒等性には、最上位の正規形を明示する。 -/
theorem Eff.substRho_nil (e : Eff) (h : Eff.Canonical e) : Eff.substRho [] e = e := by
  rw [Eff.substRho_nil_norm, h]

/-- 行だけの代入も和を保つ。 -/
theorem Eff.substRho_union (es : List Eff) (e f : Eff) :
    Eff.substRho es (Eff.union e f) = Eff.union (Eff.substRho es e) (Eff.substRho es f) := by
  simp only [Eff.substRho_eq_bind, Eff.bind_union]

/-- 型の像だけの代入は、閉じた Fail 型と正規形の最上位の効果を保つ。 -/
theorem Eff.substAt_nil_of_wf {c : Nat} (ts : List Ty) (e : Eff)
    (h : Eff.WF c e) (hc : Eff.Canonical e) : Eff.substAt c ts [] e = e := by
  have he : Eff.bind (SubstEnv.at c ts []) e = Eff.bind SubstEnv.identity e := by
    apply Eff.bind_congr_scoped (n := c)
    · intro i hi
      simp only [SubstEnv.at, SubstEnv.identity, hi, ↓reduceIte]
    · exact Eff.WF.raw e h
    · exact Eff.RowsIn.mono (fun _ _ => rfl) e (Eff.rowsIn_true e)
  change Eff.bind (SubstEnv.at c ts []) e = e
  rw [he, Eff.bind_identity, hc]

/-- 型と行の像を同時に置き換える、宣言の範囲での合成。 -/
theorem Eff.substAt_comp {ts : List Ty} {es : List Eff} (c : Nat) (ts' : List Ty) (es' : List Eff)
    (a : Eff) (h : Eff.VarsIn ts.length (· < es.length) a) :
    Eff.substAt c ts' es' (Eff.substAt 0 ts es a) =
      Eff.substAt 0 (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substAt c ts' es')) a := by
  change Eff.bind (SubstEnv.at c ts' es') (Eff.bind (SubstEnv.at 0 ts es) a) =
    Eff.bind (SubstEnv.at 0 (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substAt c ts' es'))) a
  rw [Eff.bind_comp]
  apply Eff.bind_congr_scoped (n := ts.length)
  · intro i hi
    simp only [SubstEnv.compose, SubstEnv.at, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero,
      hi, List.getElem?_eq_getElem hi, Option.getD_some, Ty.rawShift_zero,
      List.length_map, List.getElem?_map, Option.map_some]
    rw [Ty.substAt_eq_bind]
    rfl
  · exact Eff.WF.raw a (Eff.VarsIn.wf a h)
  · apply Eff.RowsIn.mono (h := Eff.VarsIn.rows a h)
    intro i hi
    rw [Eff.rowImage_compose]
    simp only [Eff.rowImage, SubstEnv.at, List.getElem?_map, List.getElem?_eq_getElem hi,
      Option.map_some, Option.getD_some, Eff.rawShift_zero, List.map_map, Function.comp_apply,
      Eff.rawShift_zero]
    rfl

/-- 型・行の同時代入も和を保つ。 -/
theorem Eff.substAt_union (c : Nat) (ts : List Ty) (es : List Eff) (e f : Eff) :
    Eff.substAt c ts es (Eff.union e f) = Eff.union (Eff.substAt c ts es e) (Eff.substAt c ts es f) :=
  Eff.bind_union (SubstEnv.at c ts es) e f

theorem Eff.substAt_empty (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c ts es Eff.empty = Eff.empty :=
  Eff.bind_ofAtoms_noRhos (SubstEnv.at c ts es) (fun _ => false) (fun _ => rfl)

theorem Eff.substAt_single (c : Nat) (ts : List Ty) (es : List Eff) (l : EffName) :
    Eff.substAt c ts es (Eff.single l) = Eff.single l :=
  Eff.bind_ofAtoms_noRhos (SubstEnv.at c ts es) _ (fun _ => rfl)

/-- 効果に含まれる名前は、型と行の同時代入後にも残る。 -/
theorem Eff.substAt_name {c ts es e l} (h : Eff.mem e (.name l)) :
    Eff.mem (Eff.substAt c ts es e) (.name l) :=
  (Eff.mem_bind (SubstEnv.at c ts es) e (.name l)).mpr (Or.inl ⟨l, rfl, h⟩)

/-- Fail 型を持つ効果も、移動と型・行代入の交換を満たす。 -/
theorem Eff.shift_substAt {c k : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF 0 t) (hes : ∀ e ∈ es, Eff.WF 0 e) (e : Eff) :
    Eff.substAt (c + k) ts es (Eff.shift k 0 e) = Eff.shift k 0 (Eff.substAt c ts es e) := by
  have hshift : ∀ e : Eff, Eff.shift k 0 e = Eff.bind (SubstEnv.shift k 0) e := by
    intro e
    rw [Eff.shift, Eff.rawShift_eq_rawBind]
    rfl
  simp only [hshift]
  change Eff.bind (SubstEnv.at (c + k) ts es) (Eff.bind (SubstEnv.shift k 0) e) =
    Eff.bind (SubstEnv.shift k 0) (Eff.bind (SubstEnv.at c ts es) e)
  rw [Eff.bind_comp, Eff.bind_comp]
  apply Eff.bind_congr_rows
  · exact SubstEnv.shift_at_types es hts
  · exact Eff.RowsIn.mono (fun i _ => Eff.shift_at_rowImages es hes i) e (Eff.rowsIn_true e)

/-- 型と行の代入は、入力の正規化に依存しない。 -/
theorem Eff.substAt_norm (c : Nat) (ts : List Ty) (es : List Eff) (e : Eff) :
    Eff.substAt c ts es (Eff.norm e) = Eff.substAt c ts es e :=
  Eff.norm_rawBind (SubstEnv.at c ts es) e

end Benitoite.Release
