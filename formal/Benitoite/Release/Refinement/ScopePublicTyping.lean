import Benitoite.Release.Refinement.ScopePublicValues
import Benitoite.Release.Refinement.AtPatterns
import Benitoite.Release.Refinement.KeyContracts
import Benitoite.Release.Refinement.AtStateInputs
import Benitoite.Release.Refinement.CanonicalValues

/-! # At の診断の公開形の観測・照合・網羅性と、公開の入口が作る診断

公開の宣言を持つプログラムで、公開の値の項の観測・鍵の観測・照合・網羅性を同じ `P.cons` で述べる。
公開の入口が作る準備と検査の失敗は、公開形を持つ（設計書 07-04「篩を含む形式化の範囲」）。 -/
namespace Benitoite.Release.Refinement.ScopePublic
open Scope.Domain

/-- 新しい19の公開型について、宣言にない構成子を持たない。 -/
def _root_.Benitoite.Release.Refinement.Program.ScopePublicComplete (P : Program) : Prop :=
  ∀ D ∈ declarations, ∀ c cd, P.cons c = some cd → cd.data = D.name →
    ∃ as, (c, as) ∈ D.constructors ∧ cd = ⟨D.name, 0, as.map PublicTy.ty⟩

/-! ## 観測と鍵 -/

mutual
  /-- 型付きの公開の値の観測は、どの観測の環境でも鍵の形を持つ。 -/
  theorem PublicTree.Typed.key (η : ObservationEnvModel) {t : PublicTree} {a : PublicTy}
      (h : t.Typed a) : ∃ o, t.toTerm.observe η = Option.some o ∧ o.KeyShape := by
    match h with
    | .text s => exact ⟨_, rfl, .string s⟩
    | .integer n => exact ⟨_, rfl, .integer _⟩
    | .bytes (bs := bs) hb =>
      exact ⟨_, rfl, .bytes (List.all_eq_true.mpr fun b hm => decide_eq_true (hb b hm))⟩
    | .list _ hs => exact ⟨_, rfl, .list (PublicTree.TypedEach.keys η hs)⟩
    | .none _ => exact ⟨_, rfl, .data .nil⟩
    | .some _ hx =>
      obtain ⟨o, ho, hk⟩ := PublicTree.Typed.key η hx
      exact ⟨_, rfl, .data (by simpa [observeSlots, ho] using Observation.KeySlots.cons hk .nil)⟩
    | .con _ hs => exact ⟨_, rfl, .data (PublicTree.TypedAll.keys η hs)⟩
  theorem PublicTree.TypedAll.keys (η : ObservationEnvModel) {ts : List PublicTree} {as : List PublicTy}
      (h : PublicTree.TypedAll ts as) : Observation.KeySlots (observeSlots η (PublicTree.toTermSlots ts)) := by
    match h with
    | .nil => exact .nil
    | .cons hx hs =>
      obtain ⟨o, ho, hk⟩ := PublicTree.Typed.key η hx
      simpa [PublicTree.toTermSlots, observeSlots, ho] using
        Observation.KeySlots.cons hk (PublicTree.TypedAll.keys η hs)
  theorem PublicTree.TypedEach.keys (η : ObservationEnvModel) {ts : List PublicTree} {a : PublicTy}
      (h : PublicTree.TypedEach ts a) : Observation.KeySlots (observeSlots η (PublicTree.toTermSlots ts)) := by
    match h with
    | .nil => exact .nil
    | .cons hx hs =>
      obtain ⟨o, ho, hk⟩ := PublicTree.Typed.key η hx
      simpa [PublicTree.toTermSlots, observeSlots, ho] using
        Observation.KeySlots.cons hk (PublicTree.TypedEach.keys η hs)
end

/-- 型付きの公開の値の観測は、同じ宣言の項であり、自由変数を持たない。 -/
theorem PublicTree.Typed.observed {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
    {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} (hp : P.HasScopePublic) {t : PublicTree} {a : PublicTy}
    (h : t.Typed a) : t.toVal.toTerm? = Option.some t.toTerm ∧ Term.Declared P C Γ t.toTerm :=
  ⟨t.toVal_toTerm, (h.val (B := B) (Ψ := Ψ) (Q := Q) (Φ := Φ) hp).observation_declared t.toVal_toTerm⟩

/-! ## 照合と網羅性 -/

/-- 公開の構成子の欄の数の変数のパターン。 -/
def constructorPatterns (D : PublicData) : List Pat :=
  D.constructors.map fun c => .con c.1 (List.replicate c.2.length .var)

private theorem toVals_length (xs : List PublicTree) : (PublicTree.toVals xs).length = xs.length := by
  induction xs with
  | nil => rfl
  | cons x xs ih => simp [PublicTree.toVals, ih]

/-- 構成子のパターンは、同じ構成子の公開の値の全欄を順に束縛する。 -/
theorem constructor_match (c : ConName) (xs : List PublicTree) :
    matchVal (.con c (List.replicate xs.length .var)) (PublicTree.con c xs).toVal =
      Option.some (PublicTree.toVals xs) := by
  simp only [PublicTree.toVal, matchVal, ↓reduceIte]
  exact matchList_variables (toVals_length xs)

private theorem not_scopeError {D : PublicData} (hD : D ∈ declarations) : D.name ≠ "Scope.ScopeError" := by
  revert D; decide

private theorem constructor_match_all {P : Program} (complete : P.ScopePublicComplete)
    {D : PublicData} (hD : D ∈ declarations) {a : Ty} {v : Val} (hv : Inhabits P a v) :
    a = .data D.name [] → ∃ p ∈ constructorPatterns D, (matchVal p v).isSome := by
  match hv with
  | .con (c := c) (cd := cd) (args := args) hl _ _ hs =>
    intro ht
    obtain ⟨hdata, -⟩ := Ty.data.inj ht
    obtain ⟨as, hm, rfl⟩ := complete D hD c cd hl hdata
    refine ⟨.con c (List.replicate as.length .var), List.mem_map.mpr ⟨(c, as), hm, rfl⟩, ?_⟩
    have hlen : args.length = as.length := by simpa only [List.length_map] using hs.length
    simp only [matchVal, ↓reduceIte, matchList_variables hlen, Option.isSome_some]
  | .atError _ =>
    intro ht
    exact absurd (Ty.data.inj ht).1 (by simpa [atErrorType] using (not_scopeError hD).symm)
  | .const (c := k) => intro ht; cases k <;> cases ht
  | .list _ | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes | .dict |
    .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern | .refined _ _ | .checked |
    .checkedRequest | .checkedAtOpaque => intro ht; cases ht

/-- 新しい19の公開型の構成子のパターンは、宣言にない構成子を持たないプログラムで網羅的である。 -/
theorem constructor_exhaustive {P : Program} (complete : P.ScopePublicComplete)
    {D : PublicData} (hD : D ∈ declarations) :
    Exhaustive P (.data D.name []) (constructorPatterns D) := by
  intro v hv
  exact constructor_match_all complete hD hv (by simp [Ty.norm, Ty.normTys])

/-! ## 公開の宣言だけを持つプログラム -/

/-- 公開の宣言と標準の Option の構成子の表。 -/
def programConstructors : List (ConName × ConDecl) :=
  (constructors.map fun e => (e.1, (⟨e.2.1, 0, e.2.2.map PublicTy.ty⟩ : ConDecl))) ++
    [("Option.Some", ⟨"Option", 1, [.tvar 0]⟩), ("Option.None", ⟨"Option", 1, []⟩)]

/-- 公開の宣言と標準の Option だけを持つプログラム。 -/
def program : Program where
  defs := fun _ => none
  cons := fun c => programConstructors.lookup c
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private theorem lookup_of_mem {α : Type} {xs : List (String × α)} (nodup : (xs.map Prod.fst).Nodup)
    {k : String} {v : α} (h : (k, v) ∈ xs) : xs.lookup k = some v := by
  induction xs with
  | nil => cases h
  | cons x xs ih =>
    rcases x with ⟨k', v'⟩
    simp only [List.map_cons, List.nodup_cons] at nodup
    simp only [List.lookup]
    rcases List.mem_cons.mp h with eq | mem
    · cases eq; simp
    · have ne : k ≠ k' := by
        intro eq; subst eq
        exact nodup.1 (List.mem_map.mpr ⟨(k, v), mem, rfl⟩)
      have hb : (k == k') = false := by simpa using ne
      rw [hb]
      exact ih nodup.2 mem

private theorem programConstructors_nodup : (programConstructors.map Prod.fst).Nodup := by
  have h : programConstructors.map Prod.fst = constructors.map Prod.fst ++ ["Option.Some", "Option.None"] := by
    simp [programConstructors, List.map_append, List.map_map, Function.comp_def]
  rw [h]; decide

private theorem program_lookup {c : ConName} {cd : ConDecl} (h : program.cons c = some cd) :
    (∃ d as, (c, d, as) ∈ constructors ∧ cd = ⟨d, 0, as.map PublicTy.ty⟩) ∨
    (c = "Option.Some" ∧ cd = ⟨"Option", 1, [.tvar 0]⟩) ∨ (c = "Option.None" ∧ cd = ⟨"Option", 1, []⟩) := by
  change programConstructors.lookup c = some cd at h
  obtain ⟨before, after, eq, _⟩ := List.lookup_eq_some_iff.mp h
  have mem : (c, cd) ∈ programConstructors := by
    rw [eq]; exact List.mem_append_right _ List.mem_cons_self
  simp only [programConstructors, List.mem_append, List.mem_map, List.mem_cons, List.not_mem_nil,
    or_false, Prod.mk.injEq] at mem
  rcases mem with ⟨⟨c', d, as⟩, hm, rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
  · exact .inl ⟨d, as, hm, rfl⟩
  · exact .inr (.inl ⟨rfl, rfl⟩)
  · exact .inr (.inr ⟨rfl, rfl⟩)

private theorem program_cons (c : ConName) (d : DataName) (as : List PublicTy) (h : (c, d, as) ∈ constructors) :
    program.cons c = some ⟨d, 0, as.map PublicTy.ty⟩ :=
  lookup_of_mem programConstructors_nodup
    (List.mem_append_left _ (List.mem_map.mpr ⟨(c, d, as), h, rfl⟩))

private theorem names_not_option : ∀ D ∈ all, D.name ≠ "Option" := by decide

private theorem constructors_nonempty : ∀ D ∈ all, D.constructors ≠ [] := by decide

private theorem constructor_owner {c : ConName} {d : DataName} {as : List PublicTy}
    (h : (c, d, as) ∈ constructors) : ∃ D ∈ all, D.name = d ∧ (c, as) ∈ D.constructors := by
  simp only [constructors, List.mem_flatMap, List.mem_map, Prod.mk.injEq] at h
  obtain ⟨D, hD, ⟨c', as'⟩, hm, rfl, rfl, rfl⟩ := h
  exact ⟨D, hD, rfl, hm⟩

private theorem name_injective {xs : List PublicData} (nodup : (xs.map PublicData.name).Nodup)
    {D D' : PublicData} (hD : D ∈ xs) (hD' : D' ∈ xs) (eq : D.name = D'.name) : D = D' := by
  induction xs with
  | nil => cases hD
  | cons x xs ih =>
    simp only [List.map_cons, List.nodup_cons] at nodup
    rcases List.mem_cons.mp hD with h1 | h1 <;> rcases List.mem_cons.mp hD' with h2 | h2
    · exact h1.trans h2.symm
    · subst h1; exact absurd (List.mem_map.mpr ⟨D', h2, eq.symm⟩) nodup.1
    · subst h2; exact absurd (List.mem_map.mpr ⟨D, h1, eq⟩) nodup.1
    · exact ih nodup.2 h1 h2

/-- 構成子の lookup が同じプログラムは、公開の宣言の条件を共有する。 -/
theorem _root_.Benitoite.Release.Refinement.Program.HasScopePublic.of_cons {P Q : Program}
    (same : ∀ c, P.cons c = Q.cons c) (hq : Q.HasScopePublic) : P.HasScopePublic := by
  have arity : ∀ d n, Q.DataArity d n → P.DataArity d n := by
    intro d n ⟨⟨c, cd, hc, hd⟩, hu⟩
    exact ⟨⟨c, cd, (same c).trans hc, hd⟩, fun c' cd' hc' hd' => hu c' cd' ((same c').symm.trans hc') hd'⟩
  exact ⟨fun d hd => arity _ _ (hq.arity d hd), fun c d as hm => (same c).trans (hq.cons c d as hm),
    arity _ _ hq.optionArity, (same _).trans hq.optionSome, (same _).trans hq.optionNone⟩

/-- 公開の宣言だけを持つプログラムの全構成子は、データ名の arity を持つ。 -/
theorem program_arity {c : ConName} {cd : ConDecl} (h : program.cons c = some cd) :
    program.DataArity cd.data cd.ntys := by
  have ntys : ∀ {c cd}, program.cons c = some cd → cd.ntys = if cd.data = "Option" then 1 else 0 := by
    intro c cd h
    rcases program_lookup h with ⟨d, as, hm, rfl⟩ | ⟨_, rfl⟩ | ⟨_, rfl⟩
    · obtain ⟨D, hD, rfl, _⟩ := constructor_owner hm
      simp [names_not_option D hD]
    · rfl
    · rfl
  refine ⟨⟨c, cd, h, rfl⟩, ?_⟩
  intro c' cd' h' hd
  rw [ntys h', ntys h, hd]

/-- 公開の宣言だけを持つプログラムは、公開の宣言の全体と Option を持ち、ほかの構成子を持たない。 -/
theorem program_public : program.HasScopePublic ∧ program.ScopePublicComplete := by
  have owner : ∀ c cd, program.cons c = some cd → cd.data ≠ "Option" → ∃ d as,
      (c, d, as) ∈ constructors ∧ cd = ⟨d, 0, as.map PublicTy.ty⟩ := by
    intro c cd h ne
    rcases program_lookup h with found | ⟨_, rfl⟩ | ⟨_, rfl⟩
    · exact found
    · exact absurd rfl ne
    · exact absurd rfl ne
  have unique : ∀ {D D' : PublicData}, D ∈ all → D' ∈ all → D.name = D'.name → D = D' := by
    intro D D' hD hD' eq
    exact name_injective declarations_shape.2.2.1 hD hD' eq
  refine ⟨⟨?_, program_cons, ?_, rfl, rfl⟩, ?_⟩
  · intro D hD
    obtain ⟨⟨c, as⟩, rest, hc⟩ := List.exists_cons_of_ne_nil (constructors_nonempty D hD)
    have mem : (c, D.name, as) ∈ constructors :=
      List.mem_flatMap.mpr ⟨D, hD, List.mem_map.mpr ⟨(c, as), by rw [hc]; exact List.mem_cons_self, rfl⟩⟩
    refine ⟨⟨c, _, program_cons c D.name as mem, rfl⟩, ?_⟩
    intro c' cd h hd
    obtain ⟨d, as', hm, rfl⟩ := owner c' cd h (by rw [hd]; exact names_not_option D hD)
    rfl
  · refine ⟨⟨"Option.Some", _, rfl, rfl⟩, ?_⟩
    intro c cd h hd
    rcases program_lookup h with ⟨d, as, hm, rfl⟩ | ⟨_, rfl⟩ | ⟨_, rfl⟩
    · obtain ⟨D, hD, rfl, _⟩ := constructor_owner hm
      exact absurd hd (names_not_option D hD)
    · rfl
    · rfl
  · intro D hD c cd h hd
    have hall : D ∈ all := List.mem_append_left _ hD
    obtain ⟨d, as, hm, rfl⟩ := owner c cd h (by rw [hd]; exact names_not_option D hall)
    obtain ⟨D', hD', rfl, hc⟩ := constructor_owner hm
    have same := unique hD' hall hd
    subst same
    exact ⟨as, hc, rfl⟩

/-- 公開の宣言だけを持つプログラムの構成子のデータ名は、公開の名前か Option である。 -/
theorem program_data {c : ConName} {cd : ConDecl} (h : program.cons c = some cd) :
    cd.data ∈ all.map PublicData.name ∨ cd.data = "Option" := by
  rcases program_lookup h with ⟨d, as, hm, rfl⟩ | ⟨_, rfl⟩ | ⟨_, rfl⟩
  · exact .inl (constructor_fields hm).1
  · exact .inr rfl
  · exact .inr rfl

/-- 公開の宣言だけを持つプログラムに、公開の名前と Option を使わない構成子を足したプログラムも、
公開の宣言の条件を満たす。 -/
theorem program_extend {P : Program} (agree : ∀ c cd, program.cons c = some cd → P.cons c = some cd)
    (other : ∀ c cd, P.cons c = some cd → program.cons c = some cd ∨
      (cd.data ∉ all.map PublicData.name ∧ cd.data ≠ "Option")) : P.HasScopePublic := by
  have arity : ∀ d n, program.DataArity d n → (d ∈ all.map PublicData.name ∨ d = "Option") →
      P.DataArity d n := by
    intro d n ⟨⟨c, cd, hc, hd⟩, hu⟩ hn
    refine ⟨⟨c, cd, agree c cd hc, hd⟩, fun c' cd' hc' hd' => ?_⟩
    rcases other c' cd' hc' with hp | ⟨h1, h2⟩
    · exact hu c' cd' hp hd'
    · subst hd'; rcases hn with hn | hn
      · exact absurd hn h1
      · exact absurd hn h2
  have pub := program_public.1
  exact ⟨fun d hd => arity _ _ (pub.arity d hd) (.inl (List.mem_map_of_mem hd)),
    fun c d as hm => agree _ _ (pub.cons c d as hm), arity _ _ pub.optionArity (.inr rfl),
    agree _ _ pub.optionSome, agree _ _ pub.optionNone⟩

/-- 公開の宣言の構成子の欄は、公開の宣言を持つ任意のプログラムで形成される。 -/
theorem program_scoped {P : Program} (hp : P.HasScopePublic) {c : ConName} {cd : ConDecl}
    (h : program.cons c = some cd) : cd.Scoped P := by
  intro a ha
  rcases program_lookup h with ⟨d, as, hm, rfl⟩ | ⟨_, rfl⟩ | ⟨_, rfl⟩
  · obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
    have hk := (constructor_fields hm).2 b hb
    exact ⟨b.sourceScoped _ _ _, b.annotation hp _ _ hk, b.kind hp _ hk⟩
  · obtain rfl := List.mem_singleton.mp ha
    exact ⟨⟨by simp [Ty.WF], by simp [Ty.RowsIn], by simp [Ty.RangesScoped]⟩,
      ⟨by simp [Ty.WF], trivial, trivial⟩, by simp [Ty.HasKind]⟩
  · cases ha

/-- 公開の宣言の構成子の欄は、Option の変性の情報を持たないプログラムで既定の変性を満たす。 -/
theorem program_variance (P : Program) (hinfo : P.dataInfo "Option" = none) {c : ConName} {cd : ConDecl}
    (h : program.cons c = some cd) : ∀ a ∈ cd.args, a.VarianceOK P (P.varianceFor cd.data cd.ntys) .positive := by
  intro a ha
  rcases program_lookup h with ⟨d, as, hm, rfl⟩ | ⟨_, rfl⟩ | ⟨_, rfl⟩
  · obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
    exact b.varianceOK P _ _
  · obtain rfl := List.mem_singleton.mp ha
    simp [Ty.VarianceOK, Program.varianceFor, hinfo, Variance.accepts]
  · cases ha

/-! ## 公開の入口が作る診断 -/

theorem inputOfVal_typed {v : Val} {t : PublicTree} (h : inputOfVal v = Option.some t) :
    t.Typed (.data "Scope.AtInput") := by
  unfold inputOfVal at h
  split at h <;> cases h
  · exact inputText_typed _
  · exact inputPattern_typed _

/-- 検査の失敗は、返す枝のない `outsideScope` を種別に持たない。 -/
theorem checkAt_no_outsideScope {σ k p input bound detail}
    (h : checkAt σ k p input bound = .error detail) : detail.failure ≠ .outsideScope := by
  unfold checkAt at h
  split at h
  · cases p <;> cases h <;> (simp only [Refinement.atDetail]; intro e; cases e)
  · cases h; simp [Refinement.atDetail]
  · cases bound <;> cases h <;> (simp only [Refinement.atDetail]; intro e; cases e)
  · split at h
    · cases h; simp [Refinement.atDetail]
    · split at h
      · cases h; simp [Refinement.atDetail]
      · split at h
        · cases h; simp [Refinement.atDetail]
        · split at h
          · cases h; simp [Refinement.atDetail]
          · cases h

/-- 文字列か解析済みの pattern を元の入力に持つ At の準備と検査の失敗は、九欄の公開形を持つ。 -/
theorem prepare_public {B cap kind name bases pattern input index detail}
    (h : AtPrepare B cap kind name bases pattern input index = .error detail)
    (hp : (inputOfVal (closeVal cap pattern)).isSome) (hi : (inputOfVal (closeVal cap input)).isSome) :
    ∃ t, detailTree? inputOfVal detail = Option.some t ∧ t.Typed (.data "Scope.AtDetail") := by
  obtain ⟨snapshot, pp, pt, eq⟩ := AtPrepare.error_saved h
  have hf := AtPrepare.no_outsideScope h
  have some := detail_public (input := inputOfVal) hf (by rw [eq]; exact hp) (by rw [eq]; exact hi)
  obtain ⟨t, ht⟩ := Option.isSome_iff_exists.mp some
  exact ⟨t, ht, detail_typed (fun _ _ hu => inputOfVal_typed hu) ht⟩

theorem check_public (p t : Val) (snapshot : Option PathEnv) (pat : RangeExpr) (target : TargetInput)
    {σ k input bound} {d : AtCheckError} (h : checkAt σ k pat input bound = .error d)
    (hp : (inputOfVal p).isSome) (ht : (inputOfVal t).isSome) :
    ∃ u, detailTree? inputOfVal (AtError.fromCheck p t snapshot pat target d) = Option.some u ∧
      u.Typed (.data "Scope.AtDetail") := by
  have some := detail_public (input := inputOfVal) (d := AtError.fromCheck p t snapshot pat target d)
    (checkAt_no_outsideScope h) hp ht
  obtain ⟨u, hu⟩ := Option.isSome_iff_exists.mp some
  exact ⟨u, hu, detail_typed (fun _ _ hv => inputOfVal_typed hv) hu⟩

/-- 内容型を持たない名前の At（公開の入口 `Scope.checkPathInAt` の形）では、型付きの状態の閉じた元入力は
公開形を持つ。 -/
theorem _root_.Benitoite.Release.Refinement.StateTyE.at_public_inputs {P B σ Eb q k μ kind name shape bases pattern input index}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (hn : B.valContent name = none) :
    (inputOfVal (closeVal q.capture pattern)).isSome ∧ (inputOfVal (closeVal q.capture input)).isSome := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,_⟩ := h
  obtain ⟨Γ,Φ,hcap,hsrc,_⟩ := hq.at_inputs hv
  obtain ⟨inputTy,hty,hi⟩ := hsrc.closed_input hP hPB hB hs.wf hs.sorted hs.declared hcap
  rcases hty with ⟨rfl,_⟩ | ⟨hc,_⟩
  · cases hsrc with
    | mk _ _ _ hp _ _ _ _ =>
      have hpc := close_value_typed hP hPB hB hs.wf hs.sorted hs.declared hcap hp
      obtain ⟨r, hr⟩ := hpc.canonical_scopePattern (kind := kind)
        (by simp [Capture.closeTy, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, Ty.core])
      obtain ⟨c, hcv, _, hct⟩ := hi.canonical_scalar (tag := .string) (by simp [Ty.norm, Ty.core])
      refine ⟨by rw [hr]; rfl, ?_⟩
      rw [hcv]
      cases c <;> simp_all [Const.type, Ty.norm, Ty.core, inputOfVal]
    | text _ _ _ hp _ _ _ _ =>
      have hpc := close_value_typed hP hPB hB hs.wf hs.sorted hs.declared hcap hp
      obtain ⟨c, hcv, _, hct⟩ := hpc.canonical_scalar (tag := .string)
        (by simp [Capture.closeTy, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, Ty.core])
      obtain ⟨d, hdv, _, hdt⟩ := hi.canonical_scalar (tag := .string) (by simp [Ty.norm, Ty.core])
      rw [hcv, hdv]
      constructor
      · cases c <;> simp_all [Const.type, Ty.norm, Ty.core, inputOfVal]
      · cases d <;> simp_all [Const.type, Ty.norm, Ty.core, inputOfVal]
  · rw [hn] at hc; cases hc

/-- 内容型を持たない名前の At の準備の失敗の観測は、固定の値でなく九欄の公開形である。 -/
theorem _root_.Benitoite.Release.Refinement.StateTyE.at_prepare_public {P B σ Eb q k μ kind name shape bases pattern input index detail}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (hn : B.valContent name = none)
    (he : AtPrepare B q.capture kind name bases pattern input index = .error detail) :
    ∃ t, detailTree? inputOfVal detail = Option.some t ∧ detail.publicTree = t ∧
      t.Typed (.data "Scope.AtDetail") := by
  obtain ⟨hp, hi⟩ := StateTyE.at_public_inputs hP hPB hB h hv hn
  obtain ⟨t, ht, typed⟩ := prepare_public he hp hi
  exact ⟨t, ht, by simp [Detail.publicTree, ht], typed⟩

/-- 内容型を持たない名前の At の検査の失敗の観測は、固定の値でなく九欄の公開形である。 -/
theorem _root_.Benitoite.Release.Refinement.StateTyE.at_check_public {P B σ Eb q k μ kind name shape bases pattern input index
      snapshot pat target bound detail}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (hn : B.valContent name = none)
    (hat : checkAt snapshot kind pat target bound = .error detail) :
    let saved := AtError.fromCheck (closeVal q.capture pattern) (closeVal q.capture input) snapshot pat target detail
    ∃ t, detailTree? inputOfVal saved = Option.some t ∧ saved.publicTree = t ∧
      t.Typed (.data "Scope.AtDetail") := by
  obtain ⟨hp, hi⟩ := StateTyE.at_public_inputs hP hPB hB h hv hn
  obtain ⟨t, ht, typed⟩ := check_public _ _ snapshot pat target hat hp hi
  exact ⟨t, ht, by simp [Detail.publicTree, ht], typed⟩

/-- 公開の AtInput は、要求の値と、pattern と端点の範囲の三つ組の列を表さない。 -/
example (pattern : String) (lo hi : Integer64Value) (req : Val) :
    inputOfVal (.list [.const (.string pattern), .const (.integer lo), .const (.integer hi)]) = Option.none ∧
    inputOfVal (.con "Http.ClientRequest" [] [req]) = Option.none := ⟨rfl, rfl⟩

/-- 同じプログラムで、AtDetail の公開の値の型付け・観測・照合と、AtFailure の網羅性が成り立つ。 -/
example (B : Builtins) (d : Detail String) (t : PublicTree)
    (h : detailTree? (fun s => Option.some (inputText s)) d = Option.some t) :
    HasTypeVQ program B StoreTy.empty Qempty [] [] [] t.toVal (.data "Scope.AtDetail" []) ∧
    t.toVal.toTerm? = Option.some t.toTerm ∧ Term.Declared program [] [] t.toTerm ∧
    Exhaustive program (.data "Scope.AtFailure" []) (constructorPatterns atFailureDecl) := by
  have typed := detail_typed (fun s u hs => by cases hs; exact inputText_typed s) h
  have observed := typed.observed (B := B) (Ψ := StoreTy.empty) (Q := Qempty) (C := []) (Γ := []) (Φ := [])
    program_public.1
  exact ⟨typed.val program_public.1, observed.1, observed.2,
    constructor_exhaustive (D := atFailureDecl) program_public.2 (by decide)⟩

/-- 同じプログラムで、公開形を持つ準備と検査の失敗の値は閉じた正常値で、全環境で適格であり、鍵の観測を持つ。
構成子のパターンは全欄を束縛し、ポートの整数の欄は値を保つ。 -/
example (B : Builtins) (σ : PathEnv) (η : ObservationEnvModel) {cap kind name bases pattern input index detail}
    (h : AtPrepare B cap kind name bases pattern input index = .error detail)
    (hp : (inputOfVal (closeVal cap pattern)).isSome) (hi : (inputOfVal (closeVal cap input)).isSome)
    (p t : Val) (snapshot : Option PathEnv) (pat : RangeExpr) (target : TargetInput) {σ' k input' bound}
    {d : AtCheckError} (hc : checkAt σ' k pat input' bound = .error d)
    (hp' : (inputOfVal p).isSome) (ht' : (inputOfVal t).isSome) (port : Port) :
    (∃ u, detailTree? inputOfVal detail = Option.some u ∧
      HasTypeVQ program B StoreTy.empty Qempty [] [] [] u.toVal (.data "Scope.AtDetail" []) ∧
      u.toVal.Ground ∧ u.toVal.Adequate σ ∧ ∃ o, u.toTerm.observe η = Option.some o ∧ o.KeyShape) ∧
    (∃ u, detailTree? inputOfVal (AtError.fromCheck p t snapshot pat target d) = Option.some u ∧
      HasTypeVQ program B StoreTy.empty Qempty [] [] [] u.toVal (.data "Scope.AtDetail" [])) ∧
    matchVal (.con "Scope.PortRange" (List.replicate 2 .var)) (PublicTree.con "Scope.PortRange"
      [.integer (natural port.val), .integer (natural port.val)]).toVal =
      Option.some [.const (.integer (natural port.val)), .const (.integer (natural port.val))] ∧
    (natural port.val).toInt = port.val := by
  obtain ⟨u, hu, typed⟩ := prepare_public h hp hi
  obtain ⟨w, hw, typed'⟩ := check_public p t snapshot pat target hc hp' ht'
  refine ⟨⟨u, hu, typed.val program_public.1, groundVal_ground u.toVal_ground, u.toVal_adequate σ,
    typed.key η⟩, ⟨w, hw, typed'.val program_public.1⟩,
    constructor_match "Scope.PortRange" [.integer (natural port.val), .integer (natural port.val)],
    natural_exact ?_⟩
  have := port.isLt
  unfold Benitoite.Release.max64
  omega

/-- 公開形の前提は、文字列の元の入力を持つ準備の失敗と、起点のない secrets の検査の失敗で満たされる。 -/
example (B : Builtins) (cap : Capture) (kind : Kind) (name : OpaqueName) (bases : Option Val) :
    (∃ detail, AtPrepare B cap kind name bases (.const (.string "/data/**")) (.const (.string "/data/a"))
        (.rvar 0) = .error detail) ∧
    (inputOfVal (closeVal cap (.const (.string "/data/**")))).isSome ∧
    (inputOfVal (closeVal cap (.const (.string "/data/a")))).isSome ∧
    ∃ d, checkAt none .path .secrets (.absolute (.path [])) .secrets = .error d :=
  ⟨⟨_, rfl⟩, rfl, rfl, ⟨_, rfl⟩⟩

end Benitoite.Release.Refinement.ScopePublic
