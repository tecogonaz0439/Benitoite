import Benitoite.Release.Refinement.PathFacts

/-! # 構成子の欄とパターン束縛の等号 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 左から数えた生の束縛位置と、そこへ至る構成子の欄の列。 -/
inductive BinderPath : Pat → Nat → List FieldRef → Prop where
  | var : BinderPath .var 0 []
  | con {c ps j p i route ref} : ps[j]? = some p → ref.constructor = c →
      ref.position = j → BinderPath p i route →
      BinderPath (.con c ps) (Pat.bindersList (ps.take j) + i) (ref :: route)

/-- 整数欄は値、List欄は長さを比較する。 -/
structure FieldLink where
  slot : Nat
  raw : Nat
  route : List FieldRef
  measure : Option Measure

/-- 独立の意味論的前提を置かず、パターンとslotsだけで経路を検査する。 -/
def FieldLink.Valid (alts : List Alt) (n : Nat) (link : FieldLink) : Prop :=
  ∃ alt, alts = [alt] ∧ (∃ c ps, alt.pat = .con c ps) ∧
    link.slot < n ∧ alt.slots[link.slot]? = some link.raw ∧
    BinderPath alt.pat link.raw link.route ∧ link.route ≠ [] ∧
    (link.measure = none ∨ link.measure = some .listLength)

def LinksValid (alts : List Alt) (n : Nat) (links : List FieldLink) : Prop :=
  ∀ link ∈ links, link.Valid alts n

def routeTerm (t : Term) : List FieldRef → Term
  | [] => t
  | r :: rs => routeTerm (.field r t) rs

def viewTerm (m : Option Measure) (t : Term) : Term :=
  match m with | none => t | some m => .measure m t

def FieldLink.predicate (n : Nat) (t : Term) (link : FieldLink) : Pred :=
  .eq (viewTerm link.measure (.var (n-1-link.slot)))
    (viewTerm link.measure (routeTerm (termBind (fun i => some (.var (n+i))) t) link.route))

def fieldFacts (n : Nat) (obs : Option Term) (links : List FieldLink) : List Pred :=
  match obs with | none => [] | some t => links.map (FieldLink.predicate n t)


@[simp] theorem routeTerm_bind (ν : ObservationEnv) (t : Term) (rs : List FieldRef) :
    termBind ν (routeTerm t rs) = routeTerm (termBind ν t) rs := by
  induction rs generalizing t with
  | nil => rfl
  | cons r rs ih => exact ih (.field r t)

@[simp] theorem viewTerm_bind (ν : ObservationEnv) (m : Option Measure) (t : Term) :
    termBind ν (viewTerm m t) = viewTerm m (termBind ν t) := by
  cases m <;> rfl

/-- 束縛したn変数を固定する改名は、受け手をn個持ち上げる操作と可換である。 -/
theorem lift_receiver_rename (n : Nat) (ξ : Nat → Nat) (t : Term) :
    termBind (fun i => some (.var (upRen n ξ i)))
      (termBind (fun i => some (.var (n+i))) t) =
    termBind (fun i => some (.var (n+i)))
      (termBind (fun i => some (.var (ξ i))) t) := by
  rw [termBind_comp,termBind_comp]
  congr 1
  funext i
  simp [termBind?,upRen,Nat.not_lt.mpr (Nat.le_add_right n i),Nat.add_comm]

/-- 事実の改名は束縛後の変数番号を保つ。 -/
theorem fieldFacts_rename {n obs alts links} (valid : LinksValid alts n links) (ξ : Nat → Nat) :
    (fieldFacts n obs links).map (predBind (fun i => some (.var (upRen n ξ i)))) =
      fieldFacts n (obs.map (termBind (fun i => some (.var (ξ i))))) links := by
  cases obs with
  | none => rfl
  | some t =>
    simp only [fieldFacts,List.map_map,Option.map_some]
    apply List.map_congr_left
    intro link hl
    obtain ⟨alt,_,_,hs,_,_,_⟩ := valid link hl
    have hb : n-1-link.slot < n := by omega
    simp only [Function.comp_def,FieldLink.predicate,predBind,viewTerm_bind,routeTerm_bind]
    rw [lift_receiver_rename]
    simp [upRen,hb]

/-- 改名後の事実の適格性を、観測と宣言の移送から導く。 -/
theorem FactsWF.rename_fields {P C Γ Δ n obs alts links ξ}
    (valid : LinksValid alts n links)
    (hw : FactsWF P C Γ (fieldFacts n obs links))
    (hs : Term.ImagesSorted Γ Δ (fun i => some (.var (upRen n ξ i))))
    (hr : Term.ImageReferences Γ Δ (fun i => some (.var (upRen n ξ i))))
    (hd : DeclarationImages P C Γ Δ (fun i => some (.var (upRen n ξ i)))) :
    FactsWF P C Δ (fieldFacts n (obs.map (termBind (fun i => some (.var (ξ i))))) links) := by
  rw [←fieldFacts_rename valid ξ]
  intro p hp
  obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
  exact (hw q hq).map hs hr hd

@[simp] theorem fieldFacts_empty (n : Nat) (obs : Option Term) : fieldFacts n obs [] = [] := by
  cases obs <;> rfl

theorem LinksValid.zero_eq_nil {alts links} (h : LinksValid alts 0 links) : links = [] := by
  apply List.eq_nil_iff_forall_not_mem.mpr
  intro link hl
  obtain ⟨_,_,_,hs,_⟩ := h link hl
  omega

/-- 型付きの観測の置換が成功すれば、欄の事実も同じ置換と可換である。 -/
theorem fieldFacts_bind_of_some {n obs alts links ν u}
    (valid : LinksValid alts n links) (hobs : obs.bind (termBind? ν) = some u) :
    (fieldFacts n obs links).map (predBind (upTerms n ν)) =
      fieldFacts n (some u) links := by
  cases obs with
  | none => cases hobs
  | some t =>
    change termBind? ν t = some u at hobs
    have hr : termBind (upTerms n ν) (termBind (fun i => some (.var (n+i))) t) =
        termBind (fun i => some (.var (n+i))) u := by
      rw [termBind_comp]
      have he : (fun i => (some (Term.var (n+i))).bind (termBind? (upTerms n ν))) =
          (fun i => (ν i).bind (termBind? (fun j => some (.var (n+j))))) := by
        funext i
        simp [upTerms,termBind?,Nat.not_lt.mpr (Nat.le_add_right n i),Nat.add_comm,map_rename_eq_bind]
      rw [he,←termBind_comp]
      simp [termBind,hobs]
    simp only [fieldFacts,List.map_map,Function.comp_def]
    apply List.map_congr_left
    intro link hl
    obtain ⟨_,_,_,hs,_,_,_⟩ := valid link hl
    have hb : n-1-link.slot < n := by omega
    simp only [FieldLink.predicate,predBind,viewTerm_bind,routeTerm_bind]
    rw [hr]
    simp [upTerms,hb]

/-- 非空の欄の経路があれば、根の構成子の観測も経路条件から型付けされる。 -/
theorem LinksValid.root_sorted {P C Γ obs alts n links link}
    (valid : LinksValid alts n links) (hl : link ∈ links)
    (hw : FactsWF P C Γ (pathFacts obs (matchedTests alts ++ excludedTests alts)))
    {t : Term} (ho : obs = some t) : t.HasSort Γ .data := by
  obtain ⟨alt,ha,⟨c,ps,hp⟩,_,_,_,_⟩ := valid link hl
  subst alts
  cases alt with
  | mk pat slots =>
    change pat = .con c ps at hp
    subst pat
    subst obs
    exact (hw (.constructorIs t c) (by simp [pathFacts,matchedTests,patternTest?,PathTest.predicate])).sorted

/-- 根の型付き観測から、部分的な値置換での事実の可換性を得る。 -/
theorem fieldFacts_bind {P C Γ Δ n obs alts links ν}
    (valid : LinksValid alts n links)
    (hw : FactsWF P C Γ (pathFacts obs (matchedTests alts ++ excludedTests alts)))
    (hs : Term.ImagesSorted Γ Δ ν) (hr : Term.ImageReferences Γ Δ ν) :
    (fieldFacts n obs links).map (predBind (upTerms n ν)) =
      fieldFacts n (obs.bind (termBind? ν)) links := by
  cases links with
  | nil =>
    have empty : ∀ o : Option Term, fieldFacts n o [] = [] := by intro o; cases o <;> rfl
    simp only [empty,List.map_nil]
  | cons link links =>
    cases obs with
    | none => rfl
    | some t =>
      obtain ⟨u,hu,_⟩ := Term.hasSort_bind (valid.root_sorted List.mem_cons_self hw rfl) ν hs hr
      exact (fieldFacts_bind_of_some (obs := some t) valid hu).trans (by rw [show (some t).bind (termBind? ν) = some u from hu])


end
end Benitoite.Release.Refinement
