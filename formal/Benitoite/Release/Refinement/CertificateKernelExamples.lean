import Benitoite.Release.Refinement.Certificate
import Benitoite.Release.Refinement.CertificateLegacy
import Benitoite.Release.Refinement.Basic

/-! # 検査の成功、構文の含意、任意の置換像の適用例 -/
namespace Benitoite.Release.Refinement.CertificateKernelExamples

def premise : Pred := .le (.var 0) (.integer 5)
def goal : Pred := .le (.scale 2 (.var 0)) (.integer 10)
def twice : Certificate := .refute (.consume (.consume (.consume
  (.derive (.combine [(0,2),(1,1)] ⟨[0,0],-1⟩) (.closeLinear 2)))))

theorem twice_checked : CertificateKernel.check premise goal twice = true := by decide

theorem twice_entails : Entails [premise] goal :=
  Entails.checked twice_checked (.hyp List.mem_cons_self)

theorem twice_entails_at (ν : ObservationEnv) :
    Entails [predBind ν premise] (predBind ν goal) :=
  .checkedAt ν twice_checked (.hyp List.mem_cons_self)

-- 元のνと外側のτを合成する四つの像。証明書はtwiceのまま使う。
def images : List ObservationEnv :=
  [fun _ => some (.var 1),
   fun _ => some (.integer 1),
   fun _ => some (.add (.var 1) (.var 2)),
   fun _ => some (.measure .setSize (.setValue [some (.var 1)]))]
example (ν : ObservationEnv) (τ : ObservationEnv) :
    Entails [predBind (fun i => (ν i).bind (termBind? τ)) premise]
      (predBind (fun i => (ν i).bind (termBind? τ)) goal) := by
  simpa only [List.map_cons, List.map_nil, predBind_comp] using (twice_entails_at ν).bind τ
example (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν premise).interpret η = true → (predBind ν goal).interpret η = true :=
  CertificateKernel.implication_sound_at twice_checked ν η
example (σ τ : ObservationEnv) (η : ObservationEnvModel) :
    (predBind τ (predBind σ premise)).interpret η = true →
      (predBind τ (predBind σ goal)).interpret η = true :=
  Pred.bind_implication_comp (CertificateKernel.implication_sound_at twice_checked) σ τ η
example (η : ObservationEnvModel) : premise.interpret η = true → goal.interpret η = true :=
  CertificateKernel.implication_sound twice_checked η
example (η : ObservationEnvModel) : (Pred.and premise (.not goal)).interpret η ≠ true :=
  CertificateKernel.check_sound twice_checked η
example : ∀ ν ∈ images, Entails [predBind ν premise] (predBind ν goal) := by
  intro ν _; exact twice_entails_at ν
example : Entails [premise,.truth] goal := twice_entails.weaken (by simp)
example : Entails [.and premise .truth] goal := twice_entails.cut (by
  intro p hp
  cases List.mem_singleton.mp hp
  exact .and_left (.hyp List.mem_cons_self))
example (η : ObservationEnvModel) (h : premise.interpret η = true) : goal.interpret η = true :=
  twice_entails.sound η (by intro p hp; cases List.mem_singleton.mp hp; exact h)

-- 正しい結合の係数だけを変えると検査が拒否する。
def badTwice : Certificate := .refute (.consume (.consume (.consume
  (.derive (.combine [(0,1),(1,1)] ⟨[0,0],-1⟩) (.closeLinear 2)))))
theorem bad_twice_rejected : CertificateKernel.check premise goal badTwice = false := by decide

def nonnegative : PreparedLeaf :=
  ⟨.le (.integer 0) (.measure .listLength (.var 0)),.measureNonnegative,[.var 0],[]⟩
def negativeLength : Certificate := .refute (.consume (.consume (.discardTodo
  (.builtin nonnegative (.consume
    (.derive (.combine [(0,1),(1,1)] ⟨[0,0],-1⟩) (.closeLinear 2)))))))
theorem negative_length_checked : CertificateKernel.check
    (.lt (.measure .listLength (.var 0)) (.integer 0)) .falsity negativeLength = true := by decide
example : Entails [.lt (.measure .listLength (.var 0)) (.integer 0)] .falsity :=
  Entails.checked negative_length_checked (.hyp List.mem_cons_self)

def booleanApart : Pred := .not (.and
  (.compare .boolean .eq (.var 0) (.boolean true))
  (.compare .boolean .eq (.var 0) (.boolean false)))
def booleanLeaf : Certificate := .leaf ⟨booleanApart,.booleanApart,[.var 0],[]⟩
example : CertificateKernel.check .truth booleanApart booleanLeaf = true := by decide
example : Entails [] booleanApart := Entails.checked (c := booleanLeaf) (by decide) .truth
example : CertificateKernel.check .truth (.compare .boolean .eq (.var 0) (.boolean true))
    (.leaf ⟨.compare .boolean .eq (.var 0) (.boolean true),.booleanApart,[.var 0],[]⟩) = false := by decide

-- 整数等号の参照と、Andの下の許された書換えを実際の構文の導出へ移す。
def source : Pred := .and (.le (.var 0) (.integer 7)) (.lt (.integer 0) (.var 0))
def target : Pred := .and (.le (.var 1) (.integer 7)) (.lt (.integer 0) (.var 1))
def replacing : Certificate := .substitute
  (.and (.le (.var 0) (.integer 7)) (.lt (.integer 0) (.var 0)))
  (.var 0) (.var 1) (.hyp 0) (.use 1) .integer
example : replacing.check [.eq (.var 0) (.var 1),source] target = true := by decide
example : Entails [.eq (.var 0) (.var 1),source] target := Certificate.sound (c := replacing) (by decide)

-- 旧の各分岐の保存を、同じ一般の定理で読める。
example {c : Certificate.Legacy} {Φ goal} (h : c.check Φ goal = true) : c.embed.check Φ goal = true :=
  Certificate.Legacy.success_preserved h

-- 一つの旧証明書が六構成子を全て読み、埋め込み後にも成功する。
def legacySix : Certificate.Legacy := .consume (.discard (.cases (.use 0)
  (.substitute .truth (.integer 1) (.integer 1) .refl
    (.leaf ⟨.truth,.closed,[],[]⟩))))
example : legacySix.embed.check [.and .truth (.or .truth .truth)] .truth = true := by
  apply Certificate.Legacy.success_preserved
  have ht : Pred.truth.closedTrue = true := by decide
  simp [legacySix, Certificate.Legacy.check, PreparedLeaf.check,
    EqProof.check, EqProof.checkRaw, termEq_spec, Pred.open, predBind, ht]

private def P : Program :=
  ⟨fun _ => none,fun _ => none,fun _ => none,fun _ => none,fun _ => none,fun _ => none,[],fun _ => none⟩
private theorem valid : P.VarianceValid := by
  constructor
  · simp [P]
  · intro c cd hc
    cases hc

private def Γ : Ctx := [some (.base .integer8)]

theorem typed_twice : twice.checkIn P [] Γ [premise] goal = true := by
  classical
  have hs : (Term.var 0).HasSort Γ .integer := by decide
  have hd : (Term.var 0).Declared P [] Γ := by
    exact ⟨.base .integer8,rfl,by intro b t e h; cases h⟩
  simp only [Certificate.checkIn, Bool.and_eq_true, decide_eq_true_eq]
  refine ⟨⟨by decide, ?_⟩, ?_, ?_, ?_, ?_⟩
  · simp [KeyTable.checkIn, Certificate.keys, Certificate.extraKeys, Refutation.keys,
      twice, premise, goal, Pred.ofConjuncts, Pred.linearKeys, Term.linearKeys, Term.AdmissibleIn, hs, hd, valid]
  · exact ⟨by decide,by decide⟩
  · exact ⟨hd,trivial⟩
  · intro p hp
    cases List.mem_singleton.mp hp
    exact ⟨⟨hs,by decide⟩,hd,trivial⟩
  · trivial

example : Entails [premise] goal := (Certificate.checkIn_sound typed_twice).2.2.2.2.2

-- この入力のraw検査は整数射影で成功する。上層はBooleanの両辺と鍵を拒否する。
example : Certificate.check [.eq (.boolean true) (.boolean true)]
    (.eq (.boolean true) (.boolean true)) (.use 0) = true := by decide
example : Certificate.checkIn P [] [] [.eq (.boolean true) (.boolean true)]
    (.eq (.boolean true) (.boolean true)) (.use 0) = false := by
  classical
  simp [Certificate.checkIn, Pred.Sorted, Term.HasSort, Term.Shape]

private theorem implication_elim {Φ : List Pred} {p q : Pred}
    (hi : Entails Φ (BuiltinSchema.implies p q)) (hp : Entails Φ p) : Entails Φ q := by
  apply Entails.or_elim hi
  · exact .false_elim (.not_elim (hp.weaken (fun _ => List.mem_cons_of_mem _)) (.hyp List.mem_cons_self))
  · exact .hyp List.mem_cons_self

private theorem float_clause (w : FloatWidth) (c : FloatClass) (a b : Term) (Φ : List Pred) :
    Entails Φ (BuiltinSchema.floatClass w c a b) := by
  apply PreparedLeaf.raw_entails (l := ⟨BuiltinSchema.floatClass w c a b,.floatCompareClass,[a,b],[]⟩)
  simp only [PreparedLeaf.checkRaw, List.isEmpty_nil, Bool.true_and]
  apply List.any_eq_true.mpr
  refine ⟨_, ?_, (predEq_spec _ _).mpr rfl⟩
  apply List.mem_flatMap.mpr
  refine ⟨w, by cases w <;> simp, ?_⟩
  apply List.mem_map.mpr
  exact ⟨c, by cases c <;> simp [BuiltinSchema.classes], rfl⟩

-- 有限な両端点と成功する二つの境界比較から、分類の有限節だけでfiniteを導く。
theorem float_between (w : FloatWidth) (a lo hi : Term) :
    Entails [.floatClass w .finite lo, .floatClass w .finite hi,
      .compare (BuiltinSchema.floatSort w) .ge a lo,
      .compare (BuiltinSchema.floatSort w) .le a hi] (.floatClass w .finite a) := by
  let Φ : List Pred := [.floatClass w .finite lo, .floatClass w .finite hi,
    .compare (BuiltinSchema.floatSort w) .ge a lo,
    .compare (BuiltinSchema.floatSort w) .le a hi]
  have nan {Δ : List Pred} (hm : ∀ p ∈ Φ, p ∈ Δ)
      (hc : Entails Δ (.floatClass w .nan a)) : Entails Δ (.floatClass w .finite a) := by
    have hh := implication_elim (.and_right (float_clause w .nan a lo Δ)) hc
    exact .false_elim (.not_elim (.hyp (hm _ (by simp [Φ])))
      (.and_right (.and_right (.and_right (.and_right hh)))))
  have pos {Δ : List Pred} (hm : ∀ p ∈ Φ, p ∈ Δ)
      (hc : Entails Δ (.floatClass w .positiveInfinity a)) : Entails Δ (.floatClass w .finite a) := by
    have hh := implication_elim (.and_right (float_clause w .positiveInfinity a hi Δ))
      (.and_intro hc (.hyp (hm _ (by simp [Φ]))))
    exact .false_elim (.not_elim (.hyp (hm _ (by simp [Φ]))) (.and_right hh))
  have neg {Δ : List Pred} (hm : ∀ p ∈ Φ, p ∈ Δ)
      (hc : Entails Δ (.floatClass w .negativeInfinity a)) : Entails Δ (.floatClass w .finite a) := by
    have hh := implication_elim (.and_right (float_clause w .negativeInfinity a lo Δ))
      (.and_intro hc (.hyp (hm _ (by simp [Φ]))))
    exact .false_elim (.not_elim (.hyp (hm _ (by simp [Φ]))) (.and_right hh))
  have hp : Entails Φ (Pred.or
      (.or (.or (.floatClass w .finite a) (.floatClass w .nan a)) (.floatClass w .positiveInfinity a))
      (.floatClass w .negativeInfinity a)) := .and_left (.and_left (float_clause w .finite a lo Φ))
  apply Entails.or_elim hp
  · apply Entails.or_elim (.hyp List.mem_cons_self)
    · apply Entails.or_elim (.hyp List.mem_cons_self)
      · exact .hyp List.mem_cons_self
      · exact nan (by intro p hp; simp [hp]) (.hyp List.mem_cons_self)
    · exact pos (by intro p hp; simp [hp]) (.hyp List.mem_cons_self)
  · exact neg (by intro p hp; simp [hp]) (.hyp List.mem_cons_self)

example : Entails [.floatClass .binary64 .finite (.float64 0),
    .floatClass .binary64 .finite (.float64 4607182418800017408),
    .compare .float64 .ge (.var 0) (.float64 0),
    .compare .float64 .le (.var 0) (.float64 4607182418800017408)]
    (.floatClass .binary64 .finite (.var 0)) := float_between _ _ _ _

end Benitoite.Release.Refinement.CertificateKernelExamples
