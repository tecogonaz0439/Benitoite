import Benitoite.Release.Refinement.ConstraintAssumptions
import Benitoite.Release.Refinement.ProgramTyping
import Benitoite.Release.Refinement.ValueFacts
import Benitoite.Release.Refinement.Context.Declarations

/-! # 標準契約の有限な分類と正常応答の事実 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace StandardContracts

/-- 標準本体に対応させる有限の関係。任意の命題の登録欄は持たない。 -/
inductive Relation where
  | arithmetic | division | comparison | byte | character | float | decimal
  | stringLength | bytes | listLength | listInsert | listConcatenate | listReverse
  | listMap | listFilter | listAccess | mapBuild | mapProjection | mapUpdate
  | mapHigherOrder | setBuild | setUpdate | setAlgebra | record | decode
  | checkedInteger | checkedLength | checkedIndex | equalLengthAccess | nonempty
  | functionVariance | scoped | intervalFlow | integerConversion | floorDivision | integerBits
  deriving DecidableEq

inductive Implementation where
  | pureDelta | core
  deriving DecidableEq

/-- 契約の構文と実装先。型付けと実行の関係の証明はデータへ埋め込まない。 -/
structure Row where
  name : String
  tparams : List TParamDecl
  neffs : Nat
  tel : Tel
  body : Option Comp
  implementation : Implementation
  relations : List Relation

/-- 宣言の注釈は既に先行する値引数の下で格納されている。 -/
def Row.definition (r : Row) : Option Def :=
  match r.implementation, r.body with
  | .core, some body => some ⟨r.tparams, r.neffs, r.tel.names,
      r.tel.inputs, r.tel.result, r.tel.effect, body⟩
  | _, _ => none

theorem signatureTel_rebuild (t : Tel) :
    signatureTel t.names t.inputs t.result t.effect = t := by
  cases t with
  | done r e => rfl
  | param n a t => simpa only [Tel.names, Tel.inputs, Tel.result, Tel.effect, signatureTel] using congrArg (Tel.param n a) (signatureTel_rebuild t)

/-- 行と同じ宣言の本体を、既存の判断そのもので検査する。 -/
def Row.BodyTyped (r : Row) (P : Program) (B : Builtins) : Prop :=
  ∃ d, r.definition = some d ∧ d.WellTyped P B

theorem Row.definition_tel {r : Row} {d : Def} (h : r.definition = some d) :
    d.tel = r.tel := by
  cases r with
  | mk name tparams neffs tel body implementation relations =>
    cases implementation <;> cases body <;> simp [Row.definition] at h
    subst d
    exact signatureTel_rebuild tel

end StandardContracts

/-- 同じ実引数・同じ正常応答の型付けから、結果の最外の事実を読む。 -/
theorem normal_reply_facts {P B Ψ b sg ts es rs ws a e out v t}
    (hB : B.CoreAssumptions P)
    (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (hd : B.delta b ts es rs ws = some out)
    (hv : out = .val v) (ht : v.toTerm? = some t) :
    ∀ r ∈ a.assume, Entails [] (r.open t) := by
  obtain ⟨o, ho, _, typed, _⟩ := hB.delta_typed Ψ b sg ts es rs ws a e hs hk args
  cases Option.some.inj (hd.symm.trans ho)
  subst out
  exact typed.1.facts ht

/-- 正常値を返した具体の δ を、値の束縛の後にも同じ事実として使う。 -/
theorem normal_reply_facts_at {P B Ψ b sg ts es rs ws a e v t}
    (hB : B.CoreAssumptions P)
    (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (hd : B.delta b ts es rs ws = some (.val v)) (ht : v.toTerm? = some t)
    (ν : ObservationEnv) :
    ∀ r ∈ a.assume, Entails [] (predBind ν (r.open t)) := by
  intro r hr
  simpa only [List.map_nil] using (normal_reply_facts hB hs hk args hd rfl ht r hr).bind ν

/-- 同じ7を返したδから得る事実を、開いた項の像にも渡せる。 -/
example {P B Ψ b sg ts es rs ws a e}
    (hB : B.CoreAssumptions P) (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (hd : B.delta b ts es rs ws = some (.val (.const (.integer ⟨7,by decide⟩)))) :
    ∀ r ∈ a.assume, Entails []
      (predBind (fun i => some (.add (.var i) (.integer 1))) (r.open (.integer 7))) :=
  normal_reply_facts_at hB hs hk args hd rfl _

end
end Benitoite.Release.Refinement
