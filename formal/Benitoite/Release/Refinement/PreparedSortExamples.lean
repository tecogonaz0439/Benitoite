import Benitoite.Release.Refinement.PreparedLeaf
import Benitoite.Release.Refinement.CertificateKeys
import Benitoite.Release.Refinement.CertificateKernelExamples

/-! # 十六sortの観測成功と原子の置換 -/
namespace Benitoite.Release.Refinement.PreparedSortExamples

private def rows : List («Sort» × Val) :=
  [(.integer,.const (.integer8 7)), (.character,.const (.character 'A')),
   (.float64,.const (.float64 0)), (.float32,.const (.float32 0)),
   (.decimal,.const (.decimal 1 0)), (.boolean,.const (.boolean false)),
   (.unit,.const .unit), (.string,.const (.string "é")),
   (.list,.list [.lam [] [] (.ret (.const .unit))]), (.bytes,.bytesV [0,255]),
   (.map,.mapV [.const (.integer8 1)] [.lam [] [] (.ret (.const .unit))]),
   (.set,.setV [.const (.integer8 1)]), (.data,.con "Box.Make" [] [.const .unit]),
   (.target .path,.checked (.path [])), (.target .host,.checked (.host (.name ["example"]))),
   (.target .endpoint,.checked (.endpoint ⟨.name ["example"],⟨443,by decide⟩⟩))]

/-- 表の各行は、値からのsnapshotとその外側の観測を持つ。
List/Map の内部の観測不能な関数はNoneのまま残す。 -/
theorem observations_16 (η : ObservationEnvModel) : rows.length = 16 ∧
    ∀ row ∈ rows, ∃ t o, row.2.toTerm? = some t ∧ t.HasSort [] row.1 ∧
      t.Closed ∧ t.observe η = some o ∧ o.sort = row.1 := by
  refine ⟨rfl, ?_⟩
  intro row hr
  simp only [rows, List.mem_cons, List.not_mem_nil, or_false] at hr
  rcases hr with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals
    refine ⟨_,_,rfl,?_,?_,rfl,rfl⟩
    all_goals trivial

/-- 全sortについて、型付き閉値の既存の入口から観測の成功まで進む。 -/
theorem typed_observation {P B Ψ Q C Φ v a s}
    (hv : HasTypeVQ P B Ψ Q C [] Φ v a) (hs : a.carrier.HasSort s)
    (η : ObservationEnvModel) :
    ∃ t o, v.toTerm? = some t ∧ t.HasSort [] s ∧ t.Closed ∧
      t.observe η = some o ∧ o.sort = s ∧ t.interpret η = some o := by
  obtain ⟨t,ht,hst,hc⟩ := hv.represented hs
  obtain ⟨o,ho,hsort⟩ := Val.toTerm_observed ht hst η
  exact ⟨t,o,ht,hst,hc,ho,hsort,Term.observe_sound ho⟩

example (P : Program) (B : Builtins) (η : ObservationEnvModel) :
    ∃ t o, (Val.const (.character 'A')).toTerm? = some t ∧ t.HasSort [] .character ∧
      t.Closed ∧ t.observe η = some o ∧ o.sort = .character ∧ t.interpret η = some o :=
  typed_observation (Ψ := StoreTy.empty) (Q := Qempty) (C := []) (Φ := [])
    (HasTypeVQ.V_Const (P := P) (B := B) (c := .character 'A') trivial) rfl η

example (P : Program) (B : Builtins) (η : ObservationEnvModel) :
    (Term.measure .stringBytes (.string "é")).observe η = some (.integer 2) ∧
    (Term.measure .stringBytes (.string "é")).interpret η = some (.integer 2) ∧
    0 ≤ (2 : Int) ∧
    ∀ (ν : ObservationEnv) (ξ : ObservationEnvModel),
      (∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ))) →
      (Term.measure .stringBytes (termBind ν (.string "é"))).observe ξ = some (.integer 2) := by
  obtain ⟨t,ht,_,_,ho,hi,hn,stable⟩ := HasTypeVQ.observed_measure
    (Ψ := StoreTy.empty) (Q := Qempty) (C := []) (Φ := []) (m := .stringBytes)
    (HasTypeVQ.V_Const (P := P) (B := B) (c := .string "é") trivial) rfl η rfl rfl
  cases ht
  exact ⟨ho,hi,hn,stable⟩

-- sameObservationを強めなくても、構造等号のsubstituteは任意の原子を移せる。
example {Ξ : List Pred} (p : Pred) (t u : Term) (c : EqProof)
    (eq : c.checkRaw Ξ .structural t u = true) (source : Entails Ξ (p.open t)) :
    Entails Ξ (p.open u) :=
  EqProof.substitute_entails eq (by cases p <;> rfl) source

example : (Pred.charactersIn (.string "abc") 'a' 'z').evalClosed = some true ∧
    (Pred.charactersIn (.string "Abc") 'a' 'z').evalClosed = some false := by decide

example : (Pred.member .path (.targetValue none (.path [])) .top).evalClosed = some true ∧
    (Pred.member .path (.targetValue none (.path [])) (.based .cwd (.tree []))).evalClosed = none := by decide

-- 入れ子の鍵は上層の既定の入口から取り出し、全ての子へ検査を移す。
theorem top_keys : ∃ P C Γ, Certificate.AllKeysChecked P C Γ
    [CertificateKernelExamples.premise] CertificateKernelExamples.goal CertificateKernelExamples.twice :=
  ⟨_,_,_,Certificate.checkIn_all_keys CertificateKernelExamples.typed_twice⟩

example : ∃ P C Γ, Certificate.AllKeysChecked P C Γ
    [.truth,CertificateKernelExamples.premise] CertificateKernelExamples.goal
    (.discard CertificateKernelExamples.twice) := by
  obtain ⟨P,C,Γ,checked⟩ := top_keys
  have top := checked.1
  refine ⟨P,C,Γ,Certificate.keys_checked_all ?_⟩
  simpa only [Certificate.keys, Certificate.extraKeys, Pred.ofConjuncts, Pred.linearKeys,
    List.nil_append] using top

-- consumeとcasesの下のrefuteでも、平坦化後の鍵列を検査する。
example :
    (Certificate.consume (.cases CertificateKernelExamples.twice CertificateKernelExamples.twice)).check
      [.and (.or CertificateKernelExamples.premise CertificateKernelExamples.premise) .truth]
      CertificateKernelExamples.goal = true ∧
    ∃ P C Γ, Certificate.AllKeysChecked P C Γ
      [.and (.or CertificateKernelExamples.premise CertificateKernelExamples.premise) .truth]
      CertificateKernelExamples.goal
      (.consume (.cases CertificateKernelExamples.twice CertificateKernelExamples.twice)) := by
  refine ⟨by decide, ?_⟩
  obtain ⟨P,C,Γ,checked⟩ := top_keys
  obtain ⟨valid, terms⟩ := KeyTable.checkIn_sound checked.1
  refine ⟨P,C,Γ,Certificate.keys_checked_all ?_⟩
  classical
  simp only [KeyTable.checkIn, decide_eq_true_eq]
  refine ⟨valid, ?_⟩
  intro t ht
  apply terms t
  simp only [Certificate.keys, Certificate.extraKeys, Pred.ofConjuncts, Pred.linearKeys,
    List.append_nil, List.mem_append] at ht ⊢
  grind

end Benitoite.Release.Refinement.PreparedSortExamples
