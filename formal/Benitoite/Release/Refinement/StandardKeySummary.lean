import Benitoite.Release.Refinement.StandardKeyTyping
import Benitoite.Release.Refinement.VarianceValidation
import Lean

/-! # 計算した鍵の要約と欄の依存位置 -/
namespace Benitoite.Release.Refinement.StandardKeyTyping
noncomputable section
open Benitoite.Release (BoundSummary SummaryTable)

private def SummaryCompatible (eq key : BoundSummary) : Prop :=
  eq.always = false → key.always = false → eq.dependsOn = key.dependsOn

private def SummariesCompatible (S : SummaryTable) : Prop :=
  ∀ s ∈ S, SummaryCompatible s.eq s.key

private theorem merge_compatible {a b c d : BoundSummary}
    (ha : SummaryCompatible a c) (hb : SummaryCompatible b d) :
    SummaryCompatible (a.merge b) (c.merge d) := by
  unfold SummaryCompatible BoundSummary.merge at *
  intro he hk
  by_cases aa : a.always = true
  · simp [aa] at he
  by_cases ba : b.always = true
  · simp [ba] at he
  by_cases ca : c.always = true
  · simp [ca] at hk
  by_cases da : d.always = true
  · simp [da] at hk
  have af : a.always = false := Bool.eq_false_iff.mpr aa
  have bf : b.always = false := Bool.eq_false_iff.mpr ba
  have cf : c.always = false := Bool.eq_false_iff.mpr ca
  have df : d.always = false := Bool.eq_false_iff.mpr da
  simp only [af,bf,cf,df,Bool.false_or,Bool.false_eq_true,ite_false] at *
  rw [ha trivial trivial,hb trivial trivial]

mutual
  private theorem summaries_ty_compatible (S : SummaryTable) (compatible : SummariesCompatible S)
      (a : Benitoite.Release.Ty) :
      SummaryCompatible (Benitoite.Release.summarizeTy S false a)
        (Benitoite.Release.summarizeTy S true a) := by
    cases a with
    | base b => cases b <;> simp [SummaryCompatible,Benitoite.Release.summarizeTy]
    | list a | set a => exact summaries_ty_compatible S compatible a
    | map a b => exact merge_compatible (summaries_ty_compatible S compatible a) (summaries_ty_compatible S compatible b)
    | data d as =>
      simp only [Benitoite.Release.summarizeTy,Bool.false_eq_true,ite_false,ite_true]
      cases h : S.find? (fun s => s.name == d) with
      | none => simp [SummaryCompatible]
      | some s =>
        have pair := compatible s (List.mem_of_find?_eq_some h)
        by_cases he : s.eq.always = true
        · simp [he,SummaryCompatible]
        by_cases hk : s.key.always = true
        · simp [hk,SummaryCompatible]
        have ef : s.eq.always = false := Bool.eq_false_iff.mpr he
        have kf : s.key.always = false := Bool.eq_false_iff.mpr hk
        simp only [ef,kf,Bool.false_eq_true,ite_false]
        rw [pair ef kf]
        exact summaries_args_compatible S compatible (some s.key.dependsOn) 0 as
    | bytes | tvar | fn | «opaque» | reference | lazy | cont | dict | tapp | ctor =>
      simp [SummaryCompatible,Benitoite.Release.summarizeTy]
  private theorem summaries_args_compatible (S : SummaryTable) (compatible : SummariesCompatible S)
      (deps : Option (List Nat)) (k : Nat) (as : List Benitoite.Release.Ty) :
      SummaryCompatible (Benitoite.Release.summarizeArgs S false deps k as)
        (Benitoite.Release.summarizeArgs S true deps k as) := by
    cases as with
    | nil => simp [SummaryCompatible,Benitoite.Release.summarizeArgs]
    | cons a as =>
      simp only [Benitoite.Release.summarizeArgs]
      split
      · exact merge_compatible (summaries_ty_compatible S compatible a)
          (summaries_args_compatible S compatible deps (k+1) as)
      · exact summaries_args_compatible S compatible deps (k+1) as
end

private theorem summaryStep_compatible (ds : List Benitoite.Release.BuiltinDataDecl)
    (S : SummaryTable) (compatible : SummariesCompatible S) :
    SummariesCompatible (Benitoite.Release.summaryStep ds S) := by
  intro s hs
  obtain ⟨d,hd,rfl⟩ := List.mem_map.mp hs
  exact summaries_args_compatible S compatible none 0 d.ctors.flatten

-- 同じ本番の非公開の反復を参照し、反復の写しを別に定義しない。
local elab "summaryIteration%" : term => do
  return Lean.mkConst (Lean.mkPrivateNameCore `Benitoite.Release.BuiltinTable `Benitoite.Release.iterateSummaries)

private theorem iteration_compatible (ds : List Benitoite.Release.BuiltinDataDecl)
    (n : Nat) (S : SummaryTable) (compatible : SummariesCompatible S) :
    SummariesCompatible (summaryIteration% ds n S) := by
  induction n generalizing S with
  | zero => exact compatible
  | succ n ih =>
    change SummariesCompatible (if Benitoite.Release.summaryStep ds S == S then S
      else summaryIteration% ds n (Benitoite.Release.summaryStep ds S))
    split
    · exact compatible
    · exact ih _ (summaryStep_compatible ds S compatible)

private theorem dataSummaries_compatible (ds : List Benitoite.Release.BuiltinDataDecl) :
    SummariesCompatible (Benitoite.Release.dataSummaries ds) := by
  apply iteration_compatible
  intro s hs
  obtain ⟨d,_,rfl⟩ := List.mem_map.mp hs
  intro _ _
  rfl

theorem carrier_core (a : Ty) : carrier a.core = carrier a := by
  cases a <;> try rfl
  case refined a p => exact carrier_core a

private theorem carrier_refineNorm (a : Ty) (p : Pred) : carrier (Ty.refineNorm a p) = carrier a := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> simpa [carrier] using carrier_core a

private theorem carrier_foldFn (t : Tel) : carrier (Ty.foldFn t) =
    Benitoite.Release.Ty.fn [] [] (.base .unit) Benitoite.Release.Eff.empty := by
  unfold Ty.foldFn
  split <;> rfl

mutual
  theorem carrier_norm (a : Ty) : carrier a.norm = carrier a := by
    cases a <;> simp only [Ty.norm,carrier,carrier_norm,carriers_norm,carrier_refineNorm,carrier_foldFn]
  theorem carriers_norm (as : List Ty) : carriers (Ty.normTys as) = carriers as := by
    cases as <;> simp only [Ty.normTys,carriers,carrier_norm,carriers_norm]
end

/-- 要約の成功を、参照する型引数の位置ごとに読む。 -/
def SummaryHolds (S : SummaryTable) (key : Bool) (ts : List Ty) (s : BoundSummary) : Prop :=
  s.always = false ∧ ∀ i ∈ s.dependsOn,
    ∃ a, ts[i]? = some a ∧ Benitoite.Release.satisfiesB S [] key (carrier a) = true

private def insertDependency (i : Nat) (ds : List Nat) : List Nat :=
  (BoundSummary.merge ⟨false,ds⟩ ⟨false,[i]⟩).dependsOn

private theorem insertDependency_mem (i j : Nat) (ds : List Nat) :
    j ∈ insertDependency i ds ↔ j = i ∨ j ∈ ds := by
  induction ds with
  | nil => change j ∈ [i] ↔ j = i ∨ j ∈ []; simp
  | cons k ds ih =>
    change j ∈ (if i < k then i :: k :: ds else if i == k then k :: ds
      else k :: insertDependency i ds) ↔ j = i ∨ j ∈ k :: ds
    split
    · simp only [List.mem_cons]
    · split
      · rename_i _ eq
        have : i = k := by simpa using eq
        subst k
        simp
      · simp only [List.mem_cons,ih]; simp [or_left_comm]

private theorem dependencies_fold (ds is : List Nat) (j : Nat) :
    j ∈ is.foldl (fun ds i => insertDependency i ds) ds ↔ j ∈ ds ∨ j ∈ is := by
  induction is generalizing ds with
  | nil => simp
  | cons i is ih =>
    simp only [List.foldl,ih,insertDependency_mem,List.mem_cons]
    simp [or_assoc,or_comm,or_left_comm]

private theorem summary_merge {S key ts a b}
    (h : SummaryHolds S key ts (a.merge b)) :
    SummaryHolds S key ts a ∧ SummaryHolds S key ts b := by
  unfold SummaryHolds at h ⊢
  unfold BoundSummary.merge at h
  split at h
  · cases h.1
  · rename_i hn
    have ha : a.always = false := by cases ha : a.always <;> simp_all
    have hb : b.always = false := by cases hb : b.always <;> simp_all
    have deps : ∀ i, i ∈ a.dependsOn ∨ i ∈ b.dependsOn →
        ∃ t, ts[i]? = some t ∧ Benitoite.Release.satisfiesB S [] key (carrier t) = true := by
      intro i hi
      apply h.2 i
      change i ∈ b.dependsOn.foldl (fun ds j => insertDependency j ds) a.dependsOn
      exact (dependencies_fold _ _ _).mpr hi
    exact ⟨⟨ha,fun i hi => deps i (Or.inl hi)⟩,⟨hb,fun i hi => deps i (Or.inr hi)⟩⟩

private theorem merge_bounded {a b : BoundSummary} {n : Nat}
    (ha : ∀ i ∈ a.dependsOn, i < n) (hb : ∀ i ∈ b.dependsOn, i < n) :
    ∀ i ∈ (a.merge b).dependsOn, i < n := by
  intro i hi
  unfold BoundSummary.merge at hi
  split at hi
  · cases hi
  · change i ∈ b.dependsOn.foldl (fun ds j => insertDependency j ds) a.dependsOn at hi
    rcases (dependencies_fold _ _ _).mp hi with hi | hi
    · exact ha i hi
    · exact hb i hi

mutual
  private theorem summary_bounded (S : SummaryTable) (key : Bool) (a : Ty) (n : Nat)
      (wf : a.WF 0 n 0) :
      ∀ i ∈ (Benitoite.Release.summarizeTy S key (carrier a)).dependsOn, i < n := by
    cases a with
    | base b => cases b <;> simp [carrier,Benitoite.Release.summarizeTy]
    | tvar j => simpa [carrier,Benitoite.Release.summarizeTy] using (show j < n from wf)
    | list a | set a => exact summary_bounded S key a n wf
    | map a b => exact merge_bounded (summary_bounded S key a n wf.1) (summary_bounded S key b n wf.2)
    | data d as =>
      simp only [carrier,Benitoite.Release.summarizeTy]
      cases h : S.find? (fun s => s.name == d) with
      | none => simp
      | some s =>
        cases key
        all_goals simp only [Bool.false_eq_true,ite_false,ite_true]
        all_goals split
        all_goals first
          | simp
          | exact summary_args_bounded S false (some s.eq.dependsOn) as 0 n wf
          | exact summary_args_bounded S true (some s.key.dependsOn) as 0 n wf
    | refined a p => exact summary_bounded S key a n wf.1
    | bytes | «opaque» | fn | dependentFn | reference | lazy |
        cont | dict | tapp | ctor | external | «scoped» | pathBases | scopePattern =>
      simp [carrier,Benitoite.Release.summarizeTy]
  private theorem summary_args_bounded (S : SummaryTable) (key : Bool) (deps : Option (List Nat))
      (as : List Ty) (k n : Nat) (wf : Ty.WFList 0 n 0 as) :
      ∀ i ∈ (Benitoite.Release.summarizeArgs S key deps k (carriers as)).dependsOn, i < n := by
    cases as with
    | nil => simp [carriers,Benitoite.Release.summarizeArgs]
    | cons a as =>
      simp only [carriers,Benitoite.Release.summarizeArgs]
      split
      · exact merge_bounded (summary_bounded S key a n wf.1)
          (summary_args_bounded S key deps as (k+1) n wf.2)
      · exact summary_args_bounded S key deps as (k+1) n wf.2
end

private theorem Table.constructor_mem {P B} (table : Table P B) {c cd}
    (hc : P.cons c = some cd) : (c,cd) ∈ table.declarations.flatMap DataDecl.entries := by
  rw [table.cons_eq] at hc
  obtain ⟨pre,post,eq,_⟩ := List.lookup_eq_some_iff.mp hc
  rw [eq]
  exact List.mem_append_right _ (List.mem_cons_self ..)

private instance : LawfulBEq BoundSummary where
  eq_of_beq := by
    intro a b h
    cases a with
    | mk aa ad =>
      cases b with
      | mk ba bd =>
        change (aa == ba && ad == bd) = true at h
        simp only [Bool.and_eq_true,beq_iff_eq] at h
        cases h.1; cases h.2; rfl
  rfl := by intro a; cases a; change (_ && _) = true; simp

private instance : LawfulBEq Benitoite.Release.BuiltinDataSummary where
  eq_of_beq := by
    intro a b h
    cases a with
    | mk an ac ae ak =>
      cases b with
      | mk bn bc be bk =>
        change (an == bn && (ac == bc && (ae == be && ak == bk))) = true at h
        simp only [Bool.and_eq_true,beq_iff_eq] at h
        rcases h with ⟨rfl,rfl,rfl,rfl⟩
        rfl
  rfl := by intro a; cases a; change (_ && _) = true; simp

/-- 収束の等号は同じ宣言列の各行へ戻せる。 -/
theorem Table.summary_rows {P B} (table : Table P B) :
    Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput) =
      Benitoite.Release.summaryStep (table.declarations.map DataDecl.summaryInput)
        (Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)) := by
  have h := table.converged
  unfold Benitoite.Release.summariesConverged at h
  exact (beq_iff_eq.mp h).symm

private theorem lookup_of_mem {xs : List (String × ConDecl)} {c cd}
    (unique : (xs.map Prod.fst).Nodup) (mem : (c,cd) ∈ xs) : xs.lookup c = some cd := by
  induction xs with
  | nil => cases mem
  | cons x xs ih =>
    rcases List.nodup_cons.mp unique with ⟨hn,hu⟩
    rcases List.mem_cons.mp mem with rfl | hm
    · simp
    · have ne : c ≠ x.1 := by
        intro eq
        apply hn
        exact List.mem_map.mpr ⟨(c,cd),hm,eq⟩
      simpa [List.lookup,show (c == x.1) = false from beq_eq_false_iff_ne.mpr ne] using ih hu hm

private theorem Table.declaration_fields {P B} (table : Table P B) (valid : P.VarianceValid)
    {d : DataDecl} (hd : d ∈ table.declarations) {c args} (hc : (c,args) ∈ d.constructors) :
    ∀ a ∈ args, a.WF 0 d.ntys 0 := by
  have mem : (c,⟨d.name,d.ntys,args⟩) ∈ table.declarations.flatMap DataDecl.entries :=
    List.mem_flatMap.mpr ⟨d,hd,List.mem_map.mpr ⟨(c,args),hc,rfl⟩⟩
  have he : P.cons c = some ⟨d.name,d.ntys,args⟩ := by
    rw [table.cons_eq]
    exact lookup_of_mem table.constructorNames mem
  intro a ha
  have wf := ((valid.2 c _ he).2 a ha).1.wf
  simpa only [List.length_replicate,List.length_nil] using wf

private theorem Table.summary_bounds {P B} (table : Table P B) (valid : P.VarianceValid)
    {s : Benitoite.Release.BuiltinDataSummary}
    (hs : s ∈ Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput))
    (key : Bool) : ∀ i ∈ (if key then s.key else s.eq).dependsOn, i < s.ntys := by
  rw [table.summary_rows] at hs
  unfold Benitoite.Release.summaryStep at hs
  obtain ⟨d,hd,rfl⟩ := List.mem_map.mp hs
  obtain ⟨e,he,rfl⟩ := List.mem_map.mp hd
  have fields : ∀ a ∈ (e.constructors.flatMap Prod.snd), a.WF 0 e.ntys 0 := by
    intro a ha
    obtain ⟨c,hc,ha⟩ := List.mem_flatMap.mp ha
    exact table.declaration_fields valid he hc a ha
  have wf : Ty.WFList 0 e.ntys 0 (e.constructors.flatMap Prod.snd) := by
    generalize h : e.constructors.flatMap Prod.snd = fs at fields ⊢
    clear h
    induction fs with
    | nil => trivial
    | cons a fs ih => exact ⟨fields a (List.mem_cons_self ..),ih (fun a ha => fields a (List.mem_cons_of_mem _ ha))⟩
  have eq : (e.summaryInput.ctors.flatten) = carriers (e.constructors.flatMap Prod.snd) := by
    change (e.constructors.map (fun c => carriers c.2)).flatten = carriers (e.constructors.flatMap Prod.snd)
    induction e.constructors with
    | nil => rfl
    | cons c cs ih =>
      simp only [List.map_cons,List.flatten_cons]
      have app (as bs : List Ty) : carriers (as ++ bs) = carriers as ++ carriers bs := by
        induction as with
        | nil => rfl
        | cons a as ih => simp [carriers,ih]
      simpa only [List.flatMap_cons,app] using congrArg (fun x => carriers c.2 ++ x) ih
  cases key
  all_goals simp only [Bool.false_eq_true,ite_false,ite_true]
  all_goals rw [eq]
  all_goals exact summary_args_bounded _ _ none _ 0 _ wf

private theorem find_named {ds : List DataDecl} (unique : (ds.map DataDecl.name).Nodup)
    {d : DataDecl} (hd : d ∈ ds) : ds.find? (fun e => e.name == d.name) = some d := by
  induction ds with
  | nil => cases hd
  | cons e ds ih =>
    rcases List.nodup_cons.mp unique with ⟨hn,hu⟩
    rcases List.mem_cons.mp hd with rfl | hd
    · simp
    · have ne : e.name ≠ d.name := by
        intro eq
        exact hn (eq ▸ List.mem_map.mpr ⟨d,hd,rfl⟩)
      simpa [List.find?,show (e.name == d.name) = false from beq_eq_false_iff_ne.mpr ne] using ih hu hd

private theorem Table.summary_of_declaration {P B} (table : Table P B)
    {d : DataDecl} (hd : d ∈ table.declarations) :
    let S := Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)
    S.find? (fun s => s.name == d.name) = some
      ⟨d.name,d.ntys,
        Benitoite.Release.summarizeArgs S false none 0 d.summaryInput.ctors.flatten,
        Benitoite.Release.summarizeArgs S true none 0 d.summaryInput.ctors.flatten⟩ := by
  dsimp only
  conv => lhs; rw [table.summary_rows]
  simp only [Benitoite.Release.summaryStep,List.map_map,List.find?_map]
  simp only [Function.comp_def,DataDecl.summaryInput]
  rw [find_named table.dataNames hd]
  rfl

private theorem Table.declaration_of_constructor {P B} (table : Table P B) {c cd}
    (hc : P.cons c = some cd) :
    ∃ d, d ∈ table.declarations ∧ cd.data = d.name ∧ cd.ntys = d.ntys ∧
      (c,cd.args) ∈ d.constructors := by
  obtain ⟨d,hd,mem⟩ := List.mem_flatMap.mp (table.constructor_mem hc)
  obtain ⟨entry,he,eq⟩ := List.mem_map.mp mem
  cases eq
  exact ⟨d,hd,rfl,rfl,he⟩

private theorem Table.summary_arity {P B} (table : Table P B) {d n}
    (arity : P.DataArity d n) :
    ∃ s, (Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)).find?
      (fun s => s.name == d) = some s ∧ s.ntys = n := by
  obtain ⟨c,cd,hc,same⟩ := arity.1
  obtain ⟨decl,hd,he,hn,_⟩ := table.declaration_of_constructor hc
  have eq : n = decl.ntys := (arity.2 c cd hc same).symm.trans hn
  rw [same] at he
  rw [he]
  exact ⟨_,table.summary_of_declaration hd,eq.symm⟩

private theorem summary_selected {S key ts deps as k j a}
    (h : SummaryHolds S key ts (Benitoite.Release.summarizeArgs S key (some deps) k (carriers as)))
    (member : k+j ∈ deps) (ha : as[j]? = some a) :
    SummaryHolds S key ts (Benitoite.Release.summarizeTy S key (carrier a)) := by
  induction as generalizing k j with
  | nil => simp at ha
  | cons b as ih =>
    cases j with
    | zero =>
      simp only [List.getElem?_cons_zero,Option.some.injEq] at ha
      subst b
      have has : k ∈ deps := by simpa using member
      exact (summary_merge (by simpa [carriers,Benitoite.Release.summarizeArgs,has] using h)).1
    | succ j =>
      have hs : SummaryHolds S key ts
          (Benitoite.Release.summarizeArgs S key (some deps) (k+1) (carriers as)) := by
        simp only [carriers,Benitoite.Release.summarizeArgs] at h
        split at h
        · exact (summary_merge h).2
        · exact h
      have he : k+1+j = k+(j+1) := by omega
      exact ih (j := j) hs (by rw [he]; exact member) ha

private theorem satArgs_of_all {S key deps} (as : List Benitoite.Release.Ty) (k : Nat)
    (each : ∀ j a, as[j]? = some a → k+j ∈ deps →
      Benitoite.Release.satisfiesB S [] key a = true) :
    Benitoite.Release.satArgs S [] key deps k as = true := by
  induction as generalizing k with
  | nil => rfl
  | cons a as ih =>
    change ((!deps.contains k || Benitoite.Release.satisfiesB S [] key a) &&
      Benitoite.Release.satArgs S [] key deps (k+1) as) = true
    simp only [Bool.and_eq_true]
    constructor
    · by_cases hm : k ∈ deps
      · simp [hm,each 0 a rfl (by simpa using hm)]
      · simp [hm]
    · apply ih
      intro j a ha hm
      have he : k+(j+1) = k+1+j := by omega
      exact each (j+1) a ha (by simpa only [he] using hm)

private theorem carriers_rawBind (θ : SubstEnv) (as : List Ty) :
    carriers (rawBindTys θ as) = (as.map (fun a => carrier (a.bind θ))) := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [rawBindTys,carriers,List.map_cons,Ty.bind,carrier_norm,ih]

private theorem carrier_subst_var (ts : List Ty) (i : Nat) (a : Ty) (ha : ts[i]? = some a) :
    carrier ((Ty.tvar i).subst ts []) = carrier a := by
  obtain ⟨hi,eq⟩ := List.getElem?_eq_some_iff.mp ha
  simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,typeEnvAt,hi,eq]

private theorem summary_data_parts {S ts d as s}
    (lookup : S.find? (fun s => s.name == d) = some s)
    (he : SummaryHolds S false ts (Benitoite.Release.summarizeTy S false (carrier (.data d as))))
    (hk : SummaryHolds S true ts (Benitoite.Release.summarizeTy S true (carrier (.data d as)))) :
    s.eq.always = false ∧ s.key.always = false ∧
    SummaryHolds S false ts (Benitoite.Release.summarizeArgs S false (some s.eq.dependsOn) 0 (carriers as)) ∧
    SummaryHolds S true ts (Benitoite.Release.summarizeArgs S true (some s.key.dependsOn) 0 (carriers as)) := by
  simp only [carrier,Benitoite.Release.summarizeTy,lookup,Bool.false_eq_true,ite_false,ite_true] at he hk
  by_cases ef : s.eq.always = true
  · simp [ef,SummaryHolds] at he
  by_cases kf : s.key.always = true
  · simp [kf,SummaryHolds] at hk
  have en : s.eq.always = false := Bool.eq_false_iff.mpr ef
  have kn : s.key.always = false := Bool.eq_false_iff.mpr kf
  exact ⟨en,kn,by simpa only [en,Bool.false_eq_true,ite_false] using he,
    by simpa only [kn,Bool.false_eq_true,ite_false] using hk⟩

private theorem instantiate_summary {P B} (table : Table P B) (valid : P.VarianceValid)
    (a : Ty) (ts : List Ty)
    (wf : a.WF 0 ts.length 0) (declared : a.Declared P (List.replicate ts.length TypeCtx.valueParam) [])
    (he : SummaryHolds (Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)) false ts
      (Benitoite.Release.summarizeTy (Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)) false (carrier a)))
    (hk : SummaryHolds (Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)) true ts
      (Benitoite.Release.summarizeTy (Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)) true (carrier a))) :
    let S := Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)
    Benitoite.Release.satisfiesB S [] false (carrier (a.subst ts [])) = true ∧
    Benitoite.Release.satisfiesB S [] true (carrier (a.subst ts [])) = true := by
  let S := Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)
  change Benitoite.Release.satisfiesB S [] false (carrier (a.subst ts [])) = true ∧
    Benitoite.Release.satisfiesB S [] true (carrier (a.subst ts [])) = true
  cases a with
  | base b =>
    cases b <;> simp [carrier,Benitoite.Release.summarizeTy,SummaryHolds] at he hk
    all_goals simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,carrier,Benitoite.Release.satisfiesB]
  | bytes => exact ⟨rfl,rfl⟩
  | tvar i =>
    obtain ⟨b,hi,hs⟩ := he.2 i (by simp [carrier,Benitoite.Release.summarizeTy])
    obtain ⟨b',hi',hs'⟩ := hk.2 i (by simp [carrier,Benitoite.Release.summarizeTy])
    cases Option.some.inj (hi.symm.trans hi')
    rw [carrier_subst_var ts i b hi]
    exact ⟨hs,hs'⟩
  | list a | set a =>
    have ih := instantiate_summary table valid a ts wf declared he hk
    simpa only [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,carrier,
      Benitoite.Release.satisfiesB] using ih
  | map a b =>
    have he' := summary_merge he
    have hk' := summary_merge hk
    have ai := instantiate_summary table valid a ts wf.1 declared.1 he'.1 hk'.1
    have bi := instantiate_summary table valid b ts wf.2 declared.2 he'.2 hk'.2
    simp only [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm] at ai bi
    simpa only [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,carrier,
      Benitoite.Release.satisfiesB,Bool.and_eq_true] using ⟨⟨ai.1,bi.1⟩,⟨ai.2,bi.2⟩⟩
  | refined a p =>
    have ih := instantiate_summary table valid a ts wf.1 declared.1 he hk
    simpa only [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,carrier] using ih
  | data d as =>
    obtain ⟨n,arity,hlen⟩ := declared.1
    obtain ⟨s,lookup,hn⟩ := table.summary_arity arity
    have parts := summary_data_parts lookup he hk
    have mem : s ∈ S := List.mem_of_find?_eq_some lookup
    have same := dataSummaries_compatible (table.declarations.map DataDecl.summaryInput) s mem parts.1 parts.2.1
    have each (j : Nat) (a : Ty) (ha : as[j]? = some a) (hj : j ∈ s.eq.dependsOn) :
        Benitoite.Release.satisfiesB S [] false (carrier (a.subst ts [])) = true ∧
        Benitoite.Release.satisfiesB S [] true (carrier (a.subst ts [])) = true := by
      have wa : a.WF 0 ts.length 0 := Ty.wfList_iff.mp wf a (List.mem_of_getElem? ha)
      have da : a.Declared P (List.replicate ts.length TypeCtx.valueParam) [] :=
        (by
          have get (fs : List Ty) (h : declaredTys P (List.replicate ts.length TypeCtx.valueParam) [] fs)
              (i : Nat) (eq : fs[i]? = some a) : a.Declared P (List.replicate ts.length TypeCtx.valueParam) [] := by
            induction fs generalizing i with
            | nil => simp at eq
            | cons f fs ih =>
              cases i with
              | zero => cases eq; exact h.1
              | succ i => exact ih h.2 i eq
          exact get as declared.2 j ha)
      exact instantiate_summary table valid a ts wa da
        (summary_selected parts.2.2.1 (by simpa using hj) ha)
        (summary_selected parts.2.2.2 (by simpa only [Nat.zero_add,←same] using hj) ha)
    have eqArgs : Benitoite.Release.satArgs S [] false s.eq.dependsOn 0
        (as.map (fun a => carrier (a.subst ts []))) = true := by
      apply satArgs_of_all
      intro j a ha hj
      simp only [List.getElem?_map] at ha
      cases h : as[j]? with
      | none => simp [h] at ha
      | some b =>
        simp only [h,Option.map_some,Option.some.injEq] at ha
        subst a
        exact (each j b h (by simpa using hj)).1
    have keyArgs : Benitoite.Release.satArgs S [] true s.key.dependsOn 0
        (as.map (fun a => carrier (a.subst ts []))) = true := by
      rw [←same]
      apply satArgs_of_all
      intro j a ha hj
      simp only [List.getElem?_map] at ha
      cases h : as[j]? with
      | none => simp [h] at ha
      | some b =>
        simp only [h,Option.map_some,Option.some.injEq] at ha
        subst a
        exact (each j b h (by simpa using hj)).2
    have boundsE : s.eq.dependsOn.all (· < as.length) = true := by
      simp only [List.all_eq_true,decide_eq_true_eq]
      intro i hi
      have := table.summary_bounds valid mem false i hi
      simpa only [ite_false,Bool.false_eq_true,hn,←hlen] using this
    have boundsK : s.key.dependsOn.all (· < as.length) = true := by rw [←same]; exact boundsE
    have out : carrier ((Ty.data d as).subst ts []) =
        .data d (as.map (fun a => carrier (a.subst ts []))) := by
      simp only [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,carrier,carriers_rawBind]
    rw [out]
    have lookup' : S.find? (fun s => s.name == d) = some s := lookup
    simp only [Benitoite.Release.satisfiesB,lookup',List.length_map,parts.1,parts.2.1,boundsE,boundsK,
      Bool.not_false,Bool.not_true,eqArgs,keyArgs,Bool.and_true,Bool.false_or,Bool.true_or]
    simp only [hn,hlen,beq_self_eq_true,and_self]
  | «opaque» | fn | dependentFn | reference | lazy | cont | dict | tapp | ctor | external |
      «scoped» | pathBases | scopePattern =>
    simp [SummaryHolds,carrier,Benitoite.Release.summarizeTy] at he
termination_by sizeOf a
decreasing_by
  all_goals simp_wf
  all_goals try omega
  all_goals subst_vars
  all_goals simp_all
  all_goals try omega
  have hs := List.sizeOf_lt_of_mem (List.mem_of_getElem? ha)
  omega

private theorem satArgs_get {S key deps ts j a k}
    (ha : ts[j]? = some a) (hj : k+j ∈ deps)
    (hs : Benitoite.Release.satArgs S [] key deps k (carriers ts) = true) :
    Benitoite.Release.satisfiesB S [] key (carrier a) = true := by
  induction ts generalizing k j with
  | nil => simp at ha
  | cons b ts ih =>
    change ((!deps.contains k || Benitoite.Release.satisfiesB S [] key (carrier b)) &&
      Benitoite.Release.satArgs S [] key deps (k+1) (carriers ts)) = true at hs
    simp only [Bool.and_eq_true] at hs
    cases j with
    | zero =>
      cases ha
      have hm : k ∈ deps := by simpa using hj
      simpa [hm] using hs.1
    | succ j =>
      have he : k+1+j = k+(j+1) := by omega
      exact ih ha (by simpa only [he] using hj) hs.2

private theorem holds_of_arguments {S key ts s}
    (noAlways : s.always = false) (bounds : ∀ i ∈ s.dependsOn, i < ts.length)
    (hs : Benitoite.Release.satArgs S [] key s.dependsOn 0 (carriers ts) = true) :
    SummaryHolds S key ts s := by
  refine ⟨noAlways,?_⟩
  intro i hi
  have bound := bounds i hi
  exact ⟨ts[i],by simp [bound],satArgs_get (j := i) (a := ts[i])
    (by simp [bound]) (by simpa using hi) hs⟩

private theorem carriers_length (ts : List Ty) : (carriers ts).length = ts.length := by
  induction ts with
  | nil => rfl
  | cons a ts ih => simp [carriers,ih]

/-- 全欄の成功から、一つの欄の同じ要約の成功を取り出す。 -/
theorem summary_field {S key ts fields} (a : Benitoite.Release.Ty)
    (ha : a ∈ fields)
    (h : SummaryHolds S key ts (Benitoite.Release.summarizeArgs S key none 0 fields)) :
    SummaryHolds S key ts (Benitoite.Release.summarizeTy S key a) := by
  have go : ∀ (fs : List Benitoite.Release.Ty) (k : Nat), a ∈ fs →
      SummaryHolds S key ts (Benitoite.Release.summarizeArgs S key none k fs) →
      SummaryHolds S key ts (Benitoite.Release.summarizeTy S key a) := by
    intro fs
    induction fs with
    | nil => intro k mem; cases mem
    | cons f fs ih =>
      intro k mem holds
      have pair := summary_merge (by simpa only [Benitoite.Release.summarizeArgs,Option.isNone_none,
        Bool.true_or,ite_true] using holds)
      rcases List.mem_cons.mp mem with rfl | mem
      · exact pair.1
      · exact ih (k+1) mem pair.2
  exact go fields 0 ha h


/-- 同じ宣言から計算した成功を、具体化した各欄の鍵制約へ戻す。 -/
theorem Table.key_field {P B} (table : Table P B) (valid : P.VarianceValid)
    {us c cd a} (hc : P.cons c = some cd) (ha : a ∈ cd.args)
    (sat : B.sat [] (.data cd.data us) TParam.keyC) :
    B.sat [] ((a.subst us []).norm) TParam.keyC := by
  let S := Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)
  obtain ⟨d,hd,same,hn,hctor⟩ := table.declaration_of_constructor hc
  have lookup := table.summary_of_declaration hd
  have hs := (table.sat_eq [] (.data cd.data us) TParam.keyC).mp sat
  simp only [Benitoite.Release.satB,TParam.keyC,ite_true,carrier,Benitoite.Release.satisfiesB,same,
    lookup,carriers_length] at hs
  simp only [Bool.and_eq_true,beq_iff_eq] at hs
  rcases hs with ⟨⟨⟨⟨hlen,noEq⟩,boundEq⟩,eqArgs⟩,keyParts⟩
  have kp :
      (Benitoite.Release.summarizeArgs S true none 0 d.summaryInput.ctors.flatten).always = false ∧
      (Benitoite.Release.summarizeArgs S true none 0 d.summaryInput.ctors.flatten).dependsOn.all (· < us.length) = true ∧
      Benitoite.Release.satArgs S [] true
        (Benitoite.Release.summarizeArgs S true none 0 d.summaryInput.ctors.flatten).dependsOn 0 (carriers us) = true := by
    simpa [S,Bool.and_eq_true,and_assoc] using keyParts
  have eqHolds := holds_of_arguments (by simpa using noEq)
    (by simpa only [List.all_eq_true,decide_eq_true_eq] using boundEq) eqArgs
  have keyHolds := holds_of_arguments kp.1
    (by simpa only [List.all_eq_true,decide_eq_true_eq] using kp.2.1) kp.2.2
  have member : carrier a ∈ d.summaryInput.ctors.flatten := by
    apply List.mem_flatten.mpr
    refine ⟨carriers cd.args,?_,?_⟩
    · exact List.mem_map.mpr ⟨(c,cd.args),hctor,rfl⟩
    · have mem (xs : List Ty) : a ∈ xs → carrier a ∈ carriers xs := by
        induction xs with
        | nil => simp
        | cons b xs ih =>
          intro h
          rcases List.mem_cons.mp h with rfl | h
          · exact List.mem_cons_self ..
          · exact List.mem_cons_of_mem _ (ih h)
      exact mem cd.args ha
  have checked := ((valid.2 c cd hc).2 a ha).1
  have wf : a.WF 0 us.length 0 := by
    simpa only [List.length_replicate,List.length_nil,hn,hlen] using checked.wf
  have decl : a.Declared P (List.replicate us.length TypeCtx.valueParam) [] := by
    simpa only [hn,hlen] using checked.declared
  have result := (instantiate_summary table valid a us wf decl
    (summary_field (carrier a) member eqHolds)
    (summary_field (carrier a) member keyHolds)).2
  apply (table.sat_eq _ _ _).mpr
  simpa only [carrier_norm,Benitoite.Release.satB,TParam.keyC,ite_true] using result

end
end Benitoite.Release.Refinement.StandardKeyTyping
