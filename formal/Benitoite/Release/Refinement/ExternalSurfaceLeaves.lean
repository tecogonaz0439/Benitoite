import Benitoite.Release.Refinement.BuiltinTypingTransport
import Benitoite.Release.Refinement.ExternalNominal
import Benitoite.Release.Refinement.TelApplication
import Benitoite.Surface.Lemmas.Calls

/-! # 外部宣言を読む表層・脱糖の型付き入力 -/
namespace Benitoite.Release.Refinement.ExternalSurface

/-- 同じ宣言の適格な型引数を、外部関数の参照へ渡す。 -/
theorem ref_typed {P B Ψ Q C Γ Φ f d ts}
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (inst : SignatureInstance P C Γ d.parameters d.kinds ts []) :
    HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts)
      (.dependentFn (instantiatedTel d.parameters ts [])) :=
  .V_ExternalRef lookup wf admissible inst

/-- 並べ替え・捕捉を終えた実引数を、同じ宣言の依存列へ渡す。 -/
theorem call_typed {P B Ψ Q C Γ Φ R Δ f d ts ws a e}
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws
      (Tel.bind (typeEnv ts) d.parameters) a e) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.externalCall f ts ws) a e Δ :=
  .C_External lookup wf admissible args

/-- 応答関係を差し替えた表でも、参照と呼出しの全添字を保つ。 -/
example {P B B' Ψ Q C Γ Φ R Δ f d ts ws a e}
    (fields : Builtins.TypingFieldsEq B B')
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (inst : SignatureInstance P C Γ d.parameters d.kinds ts [])
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws (Tel.bind (typeEnv ts) d.parameters) a e) :
    HasTypeVQ P B' Ψ Q C Γ Φ (.externalRef f ts)
      (.dependentFn (instantiatedTel d.parameters ts [])) ∧
    HasTypeCQ P B' Ψ Q C Γ Φ R (.externalCall f ts ws) a e Δ :=
  ⟨(ref_typed lookup wf admissible inst).of_fields fields,
    (call_typed lookup wf admissible args).of_fields fields⟩

/-- 行と範囲を置き換えない束縛は、失敗の型を持たない効果を変えない。 -/
private theorem rawBind_failure_free {θ : SubstEnv} (rows : θ.rows = []) (ranges : θ.ranges = [])
    (atoms : Atom → Bool) : Eff.rawBind θ (.mk atoms []) = .mk atoms [] := by
  simp [Eff.rawBind,rows,ranges,instAtoms_nil,substAtoms_nil,rawBindTys,rowFails]

private theorem effect_rawBind {θ : SubstEnv} (rows : θ.rows = []) (ranges : θ.ranges = [])
    {atoms : Atom → Bool} : ∀ {t : Tel}, t.effect = .mk atoms [] →
      (Tel.rawBind θ t).effect = .mk atoms []
  | .done _ _, effect => by
    simp only [Tel.effect] at effect
    subst effect
    exact rawBind_failure_free rows ranges atoms
  | .param _ _ _, effect => effect_rawBind (θ := θ.up) (by simp [rows]) (by simpa using ranges) effect

private theorem effect_norm {atoms : Atom → Bool} : ∀ {t : Tel}, t.effect = .mk atoms [] →
    (Tel.norm t).effect = .mk atoms []
  | .done _ _, effect => by
    simp only [Tel.effect] at effect
    subst effect
    simp [Tel.norm,Tel.effect,Eff.norm,Ty.normTys]
  | .param _ _ rest, effect => effect_norm (t := rest) effect

/-- 失敗の型を持たない宣言の効果は、全実引数の束縛を通じて呼出しの効果になる。 -/
theorem args_effect {P B Ψ Q C Γ Φ ws t a e atoms}
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e) (effect : t.effect = .mk atoms []) :
    e = .mk atoms [] := by
  match args with
  | .done _ => exact effect
  | .param _ _ rest =>
    exact args_effect rest (effect_norm (effect_rawBind (θ := Tel.argumentsEnv _) rfl rfl effect))
termination_by structural args

/-- 署名の形成が定める呼出しの効果。usesが空なら空、そうでなければStateだけを持つ。 -/
def callEffect (d : ExternalSignature) : Eff :=
  if d.uses = [] then Eff.empty else
    .mk (fun a => match a with | .name n (.fixed .top) => decide (n = stateEff) | _ => false) []

private theorem tel_effect {P component effect t} (shape : ExternalTelWF P component effect t) :
    t.effect = effect := by
  induction shape with
  | done _ equal => exact equal
  | param _ _ ih => exact ih

private theorem declared_effect {P d} (wf : d.WF P) :
    ∃ atoms, d.parameters.effect = .mk atoms [] ∧ callEffect d = .mk atoms [] := by
  have equal := tel_effect wf.shape
  by_cases empty : d.uses = []
  · simp only [empty,↓reduceIte] at equal
    exact ⟨_,equal.trans rfl,by simp only [callEffect,empty,↓reduceIte]; rfl⟩
  · simp only [empty,↓reduceIte] at equal
    exact ⟨_,equal,by simp only [callEffect,empty,↓reduceIte]; rfl⟩

private theorem instantiated_nil (t : Tel) : instantiatedTel t [] [] = Tel.norm t := by
  have env : typeEnvAt 0 [] [] = renEnv id := by
    change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
    congr 1 <;> funext i <;> simp [typeEnvAt,renEnv]
  rw [instantiatedTel,env,Tel.bind,Tel.rawBind_id]

/-- 型IDの参照。整形式の有限表では、外部型の参照が宣言済みであることは、型引数が空で同じIDの型宣言が
あることと同値である。表示名は判定に現れない。 -/
theorem type_declared_iff {P C Γ id args} (wf : P.ExternalWF) :
    Ty.Declared P C Γ (.external id args) ↔ args = [] ∧ ∃ td, P.externalType id = some td := by
  constructor
  · intro declared
    obtain ⟨td,lookup,_,_⟩ := declared.1
    exact ⟨ExternalNominal.declared_arity wf declared,td,lookup⟩
  · rintro ⟨rfl,td,lookup⟩
    obtain ⟨same,arity⟩ := wf.type_lookup lookup
    exact ⟨⟨td,lookup,same,arity.symm⟩,trivial⟩

/-- 外部名の参照。有限表のlookupから署名の形成を読み、型引数のない参照へ宣言の依存列の正規形を与える。
結果の篩とStateは依存列の中にそのまま残る。この参照は呼出しの頭に置く形であり、第一級の関数値の
提供を表さない。 -/
theorem ref_of_lookup {P B Ψ Q C Γ Φ f d ts}
    (wf : P.ExternalWF) (lookup : P.externalFunction f = some d)
    (admissible : ExternalCallAdmissible P B C d ts)
    (inst : SignatureInstance P C Γ d.parameters d.kinds ts []) :
    ts = [] ∧ instantiatedTel d.parameters ts [] = Tel.norm d.parameters ∧
      (Tel.norm d.parameters).effect = callEffect d ∧
      HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts) (.dependentFn (Tel.norm d.parameters)) := by
  have signature := wf.function_lookup lookup
  have empty := admissible.types_nil signature
  subst ts
  obtain ⟨atoms,effect,state⟩ := declared_effect signature
  refine ⟨rfl,instantiated_nil _,(effect_norm effect).trans state.symm,?_⟩
  rw [← instantiated_nil]
  exact ref_typed lookup signature admissible inst

/-- 型付きの外部参照は、同じ表のlookup・単相の型引数と、宣言の依存列の正規形からの部分型の鎖だけを持つ。 -/
theorem ref_inputs {P B Ψ Q C Γ Φ f ts T}
    (typed : HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts) T) :
    ∃ d u, P.externalFunction f = some d ∧ d.WF P ∧ ts = [] ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (Tel.norm d.parameters) u := by
  obtain ⟨d,u,lookup,signature,admissible,_,core,closure⟩ := typed.inv_externalRef rfl
  have empty := admissible.types_nil signature
  subst ts
  rw [instantiated_nil] at closure
  exact ⟨d,u,lookup,signature,rfl,core,closure⟩

/-- 直接の飽和呼出し。宣言順の全実引数を同じ宣言の依存列で型付け、引数の数・型引数・Stateの効果を同時に読む。 -/
theorem call_of_lookup {P B Ψ Q C Γ Φ R Δ f d ts ws a e}
    (wf : P.ExternalWF) (lookup : P.externalFunction f = some d)
    (admissible : ExternalCallAdmissible P B C d ts)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws (Tel.bind (typeEnv ts) d.parameters) a e) :
    ts = [] ∧ ws.length = d.parameters.arity ∧ e = callEffect d ∧
      HasTypeCQ P B Ψ Q C Γ Φ R (.externalCall f ts ws) a e Δ := by
  have signature := wf.function_lookup lookup
  have empty := admissible.types_nil signature
  subst ts
  obtain ⟨atoms,effect,state⟩ := declared_effect signature
  have bound : Tel.bind (typeEnv []) d.parameters = Tel.norm d.parameters := instantiated_nil _
  have length := args.length
  rw [bound,Tel.arity,Tel.names_norm] at length
  refine ⟨rfl,length,?_,call_typed lookup signature admissible args⟩
  rw [bound] at args
  exact (args_effect args (effect_norm effect)).trans state.symm

/-- 外部参照を頭とする適用も、同じ宣言順の実引数で外部の依存列へ入る。部分適用の生成ラムダの本体はこの形を使う。 -/
theorem apply_typed {P B Ψ Q C Γ Φ R Δ f d ts ws a e}
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (inst : SignatureInstance P C Γ d.parameters d.kinds ts [])
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws (Tel.bind (typeEnv ts) d.parameters) a e) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.app (.externalRef f ts) ws) a e Δ :=
  .C_DependentApp (ref_typed lookup wf admissible inst) args

/-- 部分型を経た外部参照の型 `T` の依存列 `u` に沿う実引数を、`TelClosure.apply` で同じ宣言の依存列へ戻す。
`Ctx.WF` は呼出し側の文脈から、元の列の注釈は参照の型付けの `SignatureInstance` から供給する。 -/
theorem ref_arguments {P B Ψ Q C Γ Φ f ts T u ws a e}
    (context : Ctx.WF 0 C.length Γ)
    (typed : HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts) T) (core : T.fnCore = some u)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e) :
    ∃ d b g, P.externalFunction f = some d ∧ d.WF P ∧ ExternalCallAdmissible P B C d ts ∧
      HasTypeTelArgsQ P B Ψ Q C Γ Φ ws (Tel.bind (typeEnv ts) d.parameters) b g ∧
      Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e g := by
  obtain ⟨d,v,lookup,signature,admissible,inst,found,closure⟩ := typed.inv_externalRef rfl
  cases Option.some.inj (found.symm.trans core)
  obtain ⟨b,g,original,le,cover⟩ := closure.apply context inst.result args
  exact ⟨d,b,g,lookup,signature,admissible,original,le,cover⟩

/-- ソース順の値と契約上の位置から宣言順の列を作る一般の並べ替えが、外部宣言の全位置を一度ずつ埋めること。 -/
private theorem placement {d : ExternalSignature} {vs : List Val} {positions : List Nat} (fallback : Val)
    (order : positions.Perm (List.range d.parameters.arity)) (count : vs.length = positions.length) :
    (∀ k (hk : k < positions.length),
      (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)[positions[k]]? =
        some (vs[k]'(by omega))) ∧
    (∀ i, i < d.parameters.arity → ∃ k, ∃ hk : k < positions.length, positions[k] = i) ∧
    (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback).length = d.parameters.arity := by
  refine ⟨fun k hk => Benitoite.Surface.recordFields_getElem fallback order count hk,?_,by
    simp [Benitoite.Surface.recordFields]⟩
  intro i hi
  obtain ⟨k,hk,equal⟩ := List.getElem_of_mem (order.mem_iff.mpr (List.mem_range.mpr hi))
  exact ⟨k,hk,equal⟩

/-- 名前付き引数の呼出し。ソース順の値 `vs` を、宣言の位置の置換 `positions` に従って一般の並べ替え
`recordFields` で宣言順へ並べる。各値は宣言の一つの位置にちょうど一度置かれ、全位置が埋まり、ラベルは
型の具体化の後も同じ宣言の引数名を指す。並べた列を宣言の依存列で型付けた呼出しは、直接の飽和呼出しと同じ
結果型とStateの効果を持つ。ソース順の評価と束縛は一般の脱糖が受け持つ。 -/
theorem named_call {P B Ψ Q C Γ Φ R Δ f d ts vs positions labels a e} (fallback : Val)
    (wf : P.ExternalWF) (lookup : P.externalFunction f = some d)
    (admissible : ExternalCallAdmissible P B C d ts)
    (order : positions.Perm (List.range d.parameters.arity))
    (count : vs.length = positions.length)
    (named : labels = positions.map fun i => d.parameters.names[i]?)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ
      (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)
      (Tel.bind (typeEnv ts) d.parameters) a e) :
    (∀ k (hk : k < positions.length),
      (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)[positions[k]]? =
        some (vs[k]'(by omega)) ∧
      labels[k]? = some ((Tel.bind (typeEnv ts) d.parameters).names[positions[k]]?)) ∧
    (∀ i, i < d.parameters.arity → ∃ k, ∃ hk : k < positions.length, positions[k] = i) ∧
    e = callEffect d ∧
    HasTypeCQ P B Ψ Q C Γ Φ R
      (.externalCall f ts (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)) a e Δ := by
  obtain ⟨placed,filled,_⟩ := placement fallback order count
  obtain ⟨_,_,effect,typed⟩ := call_of_lookup (R := R) (Δ := Δ) wf lookup admissible args
  refine ⟨fun k hk => ⟨placed k hk,?_⟩,filled,effect,typed⟩
  simp [named,Tel.names_bind,hk]

/-- 穴を持つ部分適用。生成するラムダの本体では、穴の引数と非穴式の値をソース順に並べ、同じ並べ替えで外部参照を
頭とする適用へ渡す。文脈 `C Γ Φ` は任意であり、ラムダの引数を束縛した文脈もこれに含まれる。適用は
実行規則で同じ実引数の外部呼出しへ進み、Stateの効果を保つ。非穴式はラムダの呼出しごとに本体で評価される。 -/
theorem partial_call {P B Ψ Q C Γ Φ R Δ f d ts vs positions a e} (fallback : Val)
    (wf : P.ExternalWF) (lookup : P.externalFunction f = some d)
    (admissible : ExternalCallAdmissible P B C d ts)
    (inst : SignatureInstance P C Γ d.parameters d.kinds ts [])
    (order : positions.Perm (List.range d.parameters.arity))
    (count : vs.length = positions.length)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ
      (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)
      (Tel.bind (typeEnv ts) d.parameters) a e) :
    (∀ k (hk : k < positions.length),
      (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)[positions[k]]? =
        some (vs[k]'(by omega))) ∧
    e = callEffect d ∧
    HasTypeCQ P B Ψ Q C Γ Φ R
      (.app (.externalRef f ts) (Benitoite.Surface.recordFields d.parameters.arity positions vs fallback)) a e Δ := by
  obtain ⟨placed,_,_⟩ := placement fallback order count
  obtain ⟨_,_,effect,_⟩ := call_of_lookup (R := R) (Δ := Δ) wf lookup admissible args
  exact ⟨placed,effect,apply_typed lookup (wf.function_lookup lookup) admissible inst args⟩

end Benitoite.Release.Refinement.ExternalSurface
