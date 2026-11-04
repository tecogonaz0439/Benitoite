import Benitoite.Release.Refinement.StandardKeySummary
import Benitoite.Release.Refinement.SubstitutionContracts
import Benitoite.Release.Refinement.TypeShiftContracts

/-! # モデルの制約の骨格と具体化の境界 -/
namespace Benitoite.Release.Refinement.ModelConstraints
open StandardKeyTyping
noncomputable section

def sat (S : Benitoite.Release.SummaryTable) (C : List TParam) (a : Ty) (p : TParam) : Prop :=
  Benitoite.Release.satB S C (carrier a) p = true

/-- 実引数数と、位置ごとの非空制約を同時に検査する。 -/
def admits (S : Benitoite.Release.SummaryTable) (ps C : List TParam) (ts : List Ty) : Prop :=
  ts.length = ps.length ∧ ∀ (i : Nat) (a : Ty) (p : TParam), ts[i]? = some a → ps[i]? = some p → sat S C a p

mutual
  private theorem carrier_rawBind_values (a : Ty) (θ : SubstEnv)
      (ht : ∀ i, θ.types i = .tvar i) : carrier (a.rawBind θ) = carrier a := by
    cases a <;> simp only [Ty.rawBind,carrier,carrier_rawBind_values _ θ ht,carriers_rawBind_values _ θ ht,ht,rawApply]
  private theorem carriers_rawBind_values (as : List Ty) (θ : SubstEnv)
      (ht : ∀ i, θ.types i = .tvar i) : carriers (rawBindTys θ as) = carriers as := by
    cases as <;> simp only [rawBindTys,carriers,carrier_rawBind_values _ θ ht,carriers_rawBind_values _ θ ht]
end

/-- 全ての型と行の像について、値だけの置換は制約の骨格を保つ。 -/
theorem sat_bind_values (S : Benitoite.Release.SummaryTable) (C : List TParam)
    (a : Ty) (p : TParam) (θ : SubstEnv) (ht : ∀ i, θ.types i = .tvar i) :
    sat S C (a.bind θ) p ↔ sat S C a p := by
  simp only [sat,Ty.bind,carrier_norm,carrier_rawBind_values a θ ht]

/-- 実引数列全体の長さと各制約も、同じ置換で保つ。 -/
theorem admits_bind_values (S : Benitoite.Release.SummaryTable) (ps C : List TParam)
    (as : List Ty) (θ : SubstEnv) (ht : ∀ i, θ.types i = .tvar i) :
    admits S ps C (as.map (fun a => a.bind θ)) ↔ admits S ps C as := by
  simp only [admits,List.length_map,List.getElem?_map]
  constructor
  · rintro ⟨count,h⟩
    refine ⟨count,?_⟩
    intro i a p ha hp
    exact (sat_bind_values S C a p θ ht).mp (h i (a.bind θ) p (by simp [ha]) hp)
  · rintro ⟨count,h⟩
    refine ⟨count,?_⟩
    intro i a p ha hp
    obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp ha
    exact (sat_bind_values S C b p θ ht).mpr (h i b p hb hp)

example (S : Benitoite.Release.SummaryTable) (C ps : List TParam) (as : List Ty)
    (a : Ty) (p : TParam) (ν : Nat → Val) (ξ : Nat → Nat) :
    (sat S C (substTyValues ν a) p ↔ sat S C a p) ∧
    (sat S C (renameTy ξ a) p ↔ sat S C a p) ∧
    (admits S ps C (as.map (substTyValues ν)) ↔ admits S ps C as) := by
  refine ⟨sat_bind_values S C a p (valEnv ν) (fun _ => rfl),?_,
    admits_bind_values S ps C as (valEnv ν) (fun _ => rfl)⟩
  simp only [renameTy,sat,carrier_rawBind_values a (renEnv ξ) (fun _ => rfl)]

/-- 値変数の改名は、制約の骨格を変えない。 -/
theorem sat_rename (S : Benitoite.Release.SummaryTable) (C : List TParam)
    (a : Ty) (p : TParam) (ξ : Nat → Nat) :
    sat S C (renameTy ξ a) p ↔ sat S C a p := by
  simp only [renameTy,sat,carrier_rawBind_values a (renEnv ξ) (fun _ => rfl)]

/-- 値依存の述語と行の像を持つ置換にも、同じ制約を使う。 -/
theorem sat_values (S : Benitoite.Release.SummaryTable) (C : List TParam)
    (a : Ty) (p : TParam) (ν : Nat → Val) :
    sat S C (substTyValues ν a) p ↔ sat S C a p :=
  sat_bind_values S C a p (valEnv ν) (fun _ => rfl)

/-- 各要素の制約を保つ写像は、長さと全位置の許容を保つ。 -/
theorem admits_map {S : Benitoite.Release.SummaryTable} {ps C D : List TParam}
    {as : List Ty} {f : Ty → Ty}
    (preserve : ∀ a p, sat S C a p → sat S D (f a) p)
    (h : admits S ps C as) : admits S ps D (as.map f) := by
  refine ⟨by simpa using h.1,?_⟩
  intro i a p ha hp
  obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp (by simpa using ha)
  exact preserve b p (h.2 i b p hb hp)

theorem admits_rename (S : Benitoite.Release.SummaryTable) (ps C : List TParam)
    (as : List Ty) (ξ : Nat → Nat) (h : admits S ps C as) :
    admits S ps C (as.map (renameTy ξ)) :=
  admits_map (fun a p ha => (sat_rename S C a p ξ).mpr ha) h

theorem admits_values (S : Benitoite.Release.SummaryTable) (ps C : List TParam)
    (as : List Ty) (ν : Nat → Val) (h : admits S ps C as) :
    admits S ps C (as.map (substTyValues ν)) :=
  admits_map (fun a p ha => (sat_values S C a p ν).mpr ha) h

/-- 四条件は、非空制約を含む任意の型と入力列に同時に適用できる。 -/
example (S : Benitoite.Release.SummaryTable) (ps C : List TParam) (as : List Ty)
    (a : Ty) (p : TParam) (ξ : Nat → Nat) (ν : Nat → Val)
    (ha : sat S C a p) (hs : admits S ps C as) :
    sat S C (renameTy ξ a) p ∧ sat S C (substTyValues ν a) p ∧
    admits S ps C (as.map (renameTy ξ)) ∧ admits S ps C (as.map (substTyValues ν)) :=
  ⟨(sat_rename S C a p ξ).mpr ha,(sat_values S C a p ν).mpr ha,
    admits_rename S ps C as ξ hs,admits_values S ps C as ν hs⟩

private theorem carriers_length (as : List Ty) : (carriers as).length = as.length := by
  induction as <;> simp_all [carriers]

private theorem bindTys_length (θ : SubstEnv) (as : List Ty) : (rawBindTys θ as).length = as.length := by
  induction as <;> simp_all [rawBindTys]

mutual
  private theorem satisfies_bind (S : Benitoite.Release.SummaryTable) (C D : List TParam)
      (θ : SubstEnv)
      (vars : ∀ i key, Benitoite.Release.satisfiesB S C key (.tvar i) = true →
        Benitoite.Release.satisfiesB S D key (carrier (θ.types i)) = true)
      (a : Ty) (key : Bool) (h : Benitoite.Release.satisfiesB S C key (carrier a) = true) :
      Benitoite.Release.satisfiesB S D key (carrier (a.rawBind θ)) = true := by
    cases a with
    | tvar i => exact vars i key h
    | base b => cases b <;> exact h
    | bytes => exact h
    | list a | set a => exact satisfies_bind S C D θ vars a key h
    | map a b =>
      simp only [Ty.rawBind,carrier,Benitoite.Release.satisfiesB,Bool.and_eq_true] at h ⊢
      exact ⟨satisfies_bind S C D θ vars a key h.1,satisfies_bind S C D θ vars b key h.2⟩
    | refined a p => exact satisfies_bind S C D θ vars a key h
    | data d as =>
      simp only [carrier,Benitoite.Release.satisfiesB] at h
      simp only [Ty.rawBind,carrier,Benitoite.Release.satisfiesB]
      cases hs : S.find? (fun s => s.name == d) with
      | none => simp [hs] at h
      | some row =>
        simp only [hs,carriers_length,bindTys_length,Bool.and_eq_true,Bool.or_eq_true] at h ⊢
        obtain ⟨⟨⟨⟨hlen,he⟩,hb⟩,ha⟩,hk⟩ := h
        refine ⟨⟨⟨⟨hlen,he⟩,hb⟩,satArgs_bind S C D θ vars as false row.eq.dependsOn 0 ha⟩,?_⟩
        rcases hk with hn | ⟨⟨hn,hb⟩,ha⟩
        · exact Or.inl hn
        · exact Or.inr ⟨⟨hn,hb⟩,satArgs_bind S C D θ vars as true row.key.dependsOn 0 ha⟩
    | «opaque» | fn | dependentFn | reference | lazy | cont | dict | tapp | ctor | external |
        «scoped» | pathBases | scopePattern => cases h
  private theorem satArgs_bind (S : Benitoite.Release.SummaryTable) (C D : List TParam)
      (θ : SubstEnv)
      (vars : ∀ i key, Benitoite.Release.satisfiesB S C key (.tvar i) = true →
        Benitoite.Release.satisfiesB S D key (carrier (θ.types i)) = true)
      (as : List Ty) (key : Bool) (deps : List Nat) (j : Nat)
      (h : Benitoite.Release.satArgs S C key deps j (carriers as) = true) :
      Benitoite.Release.satArgs S D key deps j (carriers (rawBindTys θ as)) = true := by
    cases as with
    | nil => rfl
    | cons a as =>
      simp only [carriers,rawBindTys,Benitoite.Release.satArgs,Bool.and_eq_true,Bool.or_eq_true] at h ⊢
      refine ⟨?_,satArgs_bind S C D θ vars as key deps (j+1) h.2⟩
      rcases h.1 with hn | ha
      · exact Or.inl hn
      · exact Or.inr (satisfies_bind S C D θ vars a key ha)
end

private theorem key_eq (S : Benitoite.Release.SummaryTable) (C : List TParam) (a : Ty)
    (h : Benitoite.Release.satisfiesB S C true (carrier a) = true) :
    Benitoite.Release.satisfiesB S C false (carrier a) = true := by
  cases a with
  | base b => cases b <;> first | exact h | cases h
  | bytes => rfl
  | tvar i =>
    simp only [carrier,Benitoite.Release.satisfiesB] at h ⊢
    cases hi : C[i]? <;> simp_all
  | list a | set a => exact key_eq S C a h
  | map a b =>
    simp only [carrier,Benitoite.Release.satisfiesB,Bool.and_eq_true] at h ⊢
    exact ⟨key_eq S C a h.1,key_eq S C b h.2⟩
  | refined a p => exact key_eq S C a h
  | data d as =>
    simp only [carrier,Benitoite.Release.satisfiesB] at h ⊢
    cases hs : S.find? (fun s => s.name == d) with
    | none => simp [hs] at h
    | some row =>
      simp only [hs,Bool.not_false,Bool.not_true,Bool.true_or,Bool.false_or,
        Bool.and_true,Bool.and_eq_true] at h ⊢
      exact h.1
  | «opaque» | fn | dependentFn | reference | lazy | cont | dict | tapp | ctor | external |
      «scoped» | pathBases | scopePattern => cases h

private theorem satisfies_of_sat {S C a p key}
    (h : sat S C a p) (needed : (p.key || (!key && p.equality)) = true) :
    Benitoite.Release.satisfiesB S C key (carrier a) = true := by
  cases pk : p.key <;> cases pe : p.equality <;> cases key
  all_goals simp only [pk,pe,sat,Benitoite.Release.satB,Bool.false_eq_true,
    ite_false,ite_true,Bool.not_false,Bool.not_true,Bool.false_and,Bool.true_and,
    Bool.false_or,Bool.true_or] at h needed ⊢
  all_goals first | contradiction | assumption | exact key_eq S C a h

private theorem sat_bind {S C D θ a p}
    (vars : ∀ i key, Benitoite.Release.satisfiesB S C key (.tvar i) = true →
      Benitoite.Release.satisfiesB S D key (carrier (θ.types i)) = true)
    (h : sat S C a p) : sat S D (a.bind θ) p := by
  simp only [sat,Ty.bind,carrier_norm,Benitoite.Release.satB] at h ⊢
  by_cases hk : p.key = true
  · simp only [hk,ite_true] at h ⊢
    exact satisfies_bind S C D θ vars a true h
  · simp only [hk,Bool.false_eq_true,ite_false] at h ⊢
    by_cases he : p.equality = true
    · simp only [he,ite_true] at h ⊢
      exact satisfies_bind S C D θ vars a false h
    · simp only [he,Bool.false_eq_true,ite_false]

private def renameTypesEnv (ρ : Nat → Nat) : SubstEnv :=
  ⟨fun i => .tvar (ρ i),[],[],fun i => some (.var i)⟩
mutual
  private theorem carrier_renameTypes (a : Ty) (ρ : Nat → Nat) :
      carrier (a.rawRenameTypes ρ) = carrier (a.rawBind (renameTypesEnv ρ)) := by
    cases a <;> simp only [Ty.rawRenameTypes,Ty.rawBind,carrier,renameTypesEnv,
      carrier_renameTypes,carriers_renameTypes,rawApply]
  private theorem carriers_renameTypes (as : List Ty) (ρ : Nat → Nat) :
      carriers (rawRenameTypesList ρ as) = carriers (rawBindTys (renameTypesEnv ρ) as) := by
    cases as <;> simp only [rawRenameTypesList,rawBindTys,carriers,carrier_renameTypes,carriers_renameTypes]
end

/-- 制約を保つ型パラメータの改名は、開いた型全体の制約を保つ。 -/
theorem sat_renameTypes {S C D ρ a p} (ren : TypeParamRenaming C D ρ)
    (h : sat S (TypeCtx.constraints C) a p) :
    sat S (TypeCtx.constraints D) (a.renameTypes ρ) p := by
  have vars : ∀ i key, Benitoite.Release.satisfiesB S (TypeCtx.constraints C) key (.tvar i) = true →
      Benitoite.Release.satisfiesB S (TypeCtx.constraints D) key (carrier ((renameTypesEnv ρ).types i)) = true := by
    intro i key hi
    cases hp : C[i]? with
    | none => simp [Benitoite.Release.satisfiesB,TypeCtx.constraints,hp] at hi
    | some p =>
      obtain ⟨q,hq,_,hc⟩ := ren i p hp
      simp only [Benitoite.Release.satisfiesB,TypeCtx.constraints,List.getElem?_map,hp,Option.map_some] at hi
      simp only [renameTypesEnv,carrier,Benitoite.Release.satisfiesB,TypeCtx.constraints,List.getElem?_map,hq,Option.map_some]
      rcases hc with ⟨he,hk⟩
      cases key
      · simp only [Bool.not_false,Bool.true_and,Bool.or_eq_true] at hi ⊢
        exact hi.elim (fun h => Or.inl (hk h)) (fun h => Or.inr (he h))
      · simpa using hk (by simpa using hi)
  have result := sat_bind vars h
  simpa only [sat,Ty.renameTypes,Ty.bind,carrier_norm,carrier_renameTypes] using result

theorem admits_renameTypes {S ps C D ρ as} (ren : TypeParamRenaming C D ρ)
    (h : admits S ps (TypeCtx.constraints C) as) :
    admits S ps (TypeCtx.constraints D) (as.map (fun a => a.renameTypes ρ)) :=
  admits_map (fun _ _ ha => sat_renameTypes ren ha) h

/-- 正規化した注釈と元の注釈は同じ骨格を持つ。 -/
theorem sat_norm (S : Benitoite.Release.SummaryTable) (C : List TParam) (a : Ty) (p : TParam) :
    sat S C a.norm p ↔ sat S C a p := by simp only [sat,carrier_norm]

/-- 閉じた型像の各制約から、値依存の型・行像を含む型代入を保存する。 -/
theorem sat_subst {S : Benitoite.Release.SummaryTable} {C0 C1 : TypeCtx} {a : Ty} {p : TParam} {ts : List Ty} {es : List Eff}
    (h : sat S (TypeCtx.constraints (C1 ++ C0)) a p)
    (wf : ∀ t ∈ ts, t.WF 0 0 0)
    (images : ts.length = (TypeCtx.constraints C0).length ∧
      ∀ (i : Nat) (t : Ty) (q : TParam), ts[i]? = some t → (TypeCtx.constraints C0)[i]? = some q →
        sat S (TypeCtx.constraints C1) t.norm q)
    (count : ts.length = C0.length) :
    sat S (TypeCtx.constraints C1) (a.substAt C1.length ts es) p := by
  apply sat_bind (θ := typeEnvAt C1.length ts es) (h := h)
  intro i key hi
  by_cases low : i < C1.length
  · have lookup : (TypeCtx.constraints (C1 ++ C0))[i]? = (TypeCtx.constraints C1)[i]? := by
      simp only [TypeCtx.constraints,List.map_append]
      exact List.getElem?_append_left (by simpa using low)
    simpa only [typeEnvAt,low,ite_true,carrier,Benitoite.Release.satisfiesB,lookup] using hi
  · by_cases middle : i-C1.length < ts.length
    · let t := ts[i-C1.length]
      have ht : ts[i-C1.length]? = some t := by simp [t,middle]
      have lookup : (TypeCtx.constraints (C1 ++ C0))[i]? =
          (TypeCtx.constraints C0)[i-C1.length]? := by
        simp only [TypeCtx.constraints,List.map_append]
        simpa using List.getElem?_append_right (l₁ := C1.map TParamDecl.constraints)
          (l₂ := C0.map TParamDecl.constraints) (by simpa using Nat.le_of_not_gt low)
      cases hp : (TypeCtx.constraints C0)[i-C1.length]? with
      | none => simp [Benitoite.Release.satisfiesB,lookup,hp] at hi
      | some q =>
        have needed : (q.key || (!key && q.equality)) = true := by
          simpa only [Benitoite.Release.satisfiesB,lookup,hp] using hi
        have hs := satisfies_of_sat ((sat_norm S _ t q).mp (images.2 _ t q ht hp)) needed
        have closed := Ty.shiftTypes_of_wf_zero (wf t (List.getElem_mem middle)) C1.length 0
        simpa only [typeEnvAt,low,ite_false,middle,ite_true,ht,Option.getD_some,closed] using hs
    · have outside : (TypeCtx.constraints (C1 ++ C0)).length ≤ i := by
        simp only [TypeCtx.constraints,List.length_map,List.length_append]
        omega
      simp only [Benitoite.Release.satisfiesB,List.getElem?_eq_none outside] at hi
      cases hi

theorem admits_subst {S : Benitoite.Release.SummaryTable} {ps : List TParam} {C0 C1 : TypeCtx} {as ts : List Ty} {es : List Eff}
    (h : admits S ps (TypeCtx.constraints (C1 ++ C0)) as)
    (wf : ∀ t ∈ ts, t.WF 0 0 0)
    (images : ts.length = (TypeCtx.constraints C0).length ∧
      ∀ (i : Nat) (t : Ty) (q : TParam), ts[i]? = some t → (TypeCtx.constraints C0)[i]? = some q →
        sat S (TypeCtx.constraints C1) t.norm q)
    (count : ts.length = C0.length) :
    admits S ps (TypeCtx.constraints C1) (as.map (Ty.substAt C1.length ts es)) :=
  admits_map (fun _ _ ha => sat_subst ha wf images count) h

/-- 無制約は閉性や型の骨格によらず供給できる。 -/
theorem sat_unconstrained (S : Benitoite.Release.SummaryTable) (C : List TParam) (a : Ty) :
    sat S C a ({} : TParam) := rfl

private def eqC : TParam := ⟨true,false⟩
private def keyC : TParam := ⟨false,true⟩

/-- 空制約と、鍵として拒否される関数を同じ判定で区別する。 -/
example (S : Benitoite.Release.SummaryTable) (a : Ty) :
    sat S [] a {} ∧ ¬ sat S [] (.fn [] [] (.base .unit) Eff.empty) keyC := by
  exact ⟨rfl,by simp [sat,keyC,carrier,Benitoite.Release.satB,Benitoite.Release.satisfiesB]⟩

/-- 非空の二制約の変数を同じ位置へ改名できる。行き先は両方を満たす。 -/
example (S : Benitoite.Release.SummaryTable) :
    sat S [keyC,eqC] (.tvar 0) keyC ∧ sat S [keyC,eqC] (.tvar 1) eqC ∧
    sat S [keyC] ((Ty.tvar 0).renameTypes (fun _ => 0)) keyC ∧
    sat S [keyC] ((Ty.tvar 1).renameTypes (fun _ => 0)) eqC := by
  simp [sat,keyC,eqC,carrier,Ty.renameTypes,Ty.rawRenameTypes,Ty.norm,
    Benitoite.Release.satB,Benitoite.Release.satisfiesB]

/-- 型の像の篩は値に依存してよい。鍵の骨格はその述語を読まない。 -/
example (S : Benitoite.Release.SummaryTable) (p : Pred) :
    sat S [] ((Ty.tvar 0).subst [.refined (.base .integer) p] []) keyC ∧
    admits S [keyC] [] [.refined (.base .integer) p] := by
  constructor
  · simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,typeEnvAt,
      sat,carrier,keyC,Benitoite.Release.satB,Benitoite.Release.satisfiesB]
  · refine ⟨rfl,?_⟩
    intro i a q ha hq
    cases i with
    | zero => cases ha; cases hq; rfl
    | succ i => simp at ha

/-- 値・行の像に依存述語と Fail があっても、関数型を鍵にはしない。 -/
example (S : Benitoite.Release.SummaryTable) (p : Pred) (ν : Nat → Val) :
    ¬ sat S [] (substTyValues ν
      (.fn ["x"] [.refined (.base .integer) p] (.base .unit)
        (Eff.singleFail (.refined (.base .integer) p)))) keyC := by
  simp [sat,keyC,substTyValues,Ty.bind,carrier_norm,Ty.rawBind,carrier,
    Benitoite.Release.satB,Benitoite.Release.satisfiesB]

/-- 行の像は値に依存する Fail を持ってよい。 -/
example (S : Benitoite.Release.SummaryTable) (p : Pred) :
    ¬ sat S [] ((Ty.fn [] [] (.base .unit) (.mk (fun a => decide (a = .rho 0)) [])).subst
      [] [Eff.singleFail (.refined (.base .integer) p)]) keyC := by
  simp [sat,keyC,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,
    carrier,Benitoite.Release.satB,Benitoite.Release.satisfiesB]

/-- 型像の衝突で Fail は縮約する。骨格の関数拒否は列の長さを読まない。 -/
example (S : Benitoite.Release.SummaryTable) (p : Pred) :
    let a : Ty := .refined (.base .integer) p
    let e : Eff := .mk (fun _ => false) [.tvar 0,.tvar 1]
    (Eff.bind (typeEnvAt 0 [a,a] []) e).fails = [a.norm] ∧
    ¬ sat S [] (.fn [] [] (.base .unit) (Eff.bind (typeEnvAt 0 [a,a] []) e)) keyC := by
  dsimp
  constructor
  · have cmp := (tyCompare_eq_iff ((Ty.refined (.base .integer) p).norm) _).mpr rfl
    simp [cmp,Eff.bind,Eff.rawBind,rawBindTys,typeEnvAt,rowFails,Eff.norm,
      Ty.normTys,Ty.rawBind,Eff.fails,Order.sortUnique,Order.insertUnique]
  · simp [sat,keyC,carrier,Benitoite.Release.satB,Benitoite.Release.satisfiesB]
end
end Benitoite.Release.Refinement.ModelConstraints
