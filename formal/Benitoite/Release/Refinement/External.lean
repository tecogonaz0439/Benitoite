import Benitoite.Release.Refinement.Admissible

/-!
# 外部宣言の有限な表と受け渡す型

名目IDと成分内のresourceの対応を保ち、所有権ヒープは表現しない。
型の展開は有限な導出と全構成子の有限列で検査する。有限の同名の入れ子は除外しない。
-/
namespace Benitoite.Release.Refinement
noncomputable section

def typeEnv (ts : List Ty) : SubstEnv := typeEnvAt 0 ts []

/-- 外部ABIに渡せる基本型。Unitは結果位置で別に認める。 -/
def ExternalScalar : BaseTy → Prop
  | .integer | .integer8 | .integer16 | .integer32 | .unsignedInteger16
  | .unsignedInteger32 | .unsignedInteger64 | .byte | .float | .float32
  | .boolean | .character | .string => True
  | _ => False

/-- 篩はABIの鍵のcarrierを変えない。浮動小数と複合型は鍵として渡さない。 -/
def ExternalMapKey : Ty → Prop
  | .base b => ExternalScalar b ∧ b ≠ .float ∧ b ≠ .float32
  | .refined a _ => ExternalMapKey a
  | _ => False

/-- 有限に展開できる受渡し型。ABIのUnitの省略等の細部は交換側で照合する。 -/
inductive ExternalValueType (P : Program) (component : ComponentId) : Bool → Ty → Prop where
  | scalar {unit b} : ExternalScalar b → ExternalValueType P component unit (.base b)
  | unit : ExternalValueType P component true (.base .unit)
  | bytes {unit} : ExternalValueType P component unit .bytes
  | handle {unit id ts td} : P.externalType id = some td → td.component = component →
      td.id = id → td.arity = 0 → ts = [] → ExternalValueType P component unit (.external id ts)
  | list {unit a} : ExternalValueType P component false a → ExternalValueType P component unit (.list a)
  | map {unit k v} : ExternalMapKey k → ExternalValueType P component false v →
      ExternalValueType P component unit (.map k v)
  | flags {unit d ts} (cs : List ConName) : cs.Nodup → 1 ≤ cs.length → cs.length ≤ 32 →
      (∀ c, c ∈ cs ↔ ∃ cd, P.cons c = some cd ∧ cd.data = d) → P.DataArity d ts.length →
      (∀ c cd, P.cons c = some cd → cd.data = d → cd.args = []) →
      ExternalValueType P component unit (.set (.data d ts))
  | data {unit d ts} (cs : List ConName) : cs.Nodup → cs ≠ [] →
      (∀ c, c ∈ cs ↔ ∃ cd, P.cons c = some cd ∧ cd.data = d) → P.DataArity d ts.length →
      (∀ c cd, P.cons c = some cd → cd.data = d →
        ∀ a ∈ cd.args, ExternalValueType P component true (a.subst ts [])) →
      ExternalValueType P component unit (.data d ts)
  | refined {unit a p} : ExternalValueType P component unit a →
      ExternalValueType P component unit (.refined a p)

/-- usesの過不足を検査するための、型の全入れ子にある外部型の出現。 -/
inductive ExternalOccurrence (P : Program) : Ty → List ExternalPathStep → ExternalId → Prop where
  | root {id ts} : ExternalOccurrence P (.external id ts) [] id
  | element {a path id} : ExternalOccurrence P a path id → ExternalOccurrence P (.list a) (.element :: path) id
  | key {a b path id} : ExternalOccurrence P a path id → ExternalOccurrence P (.map a b) (.key :: path) id
  | value {a b path id} : ExternalOccurrence P b path id → ExternalOccurrence P (.map a b) (.value :: path) id
  | field {d ts c cd i a path id} : P.cons c = some cd → cd.data = d → cd.ntys = ts.length →
      cd.args[i]? = some a → ExternalOccurrence P (a.subst ts []) path id →
      ExternalOccurrence P (.data d ts) (.field c i :: path) id
  | refined {a p path id} : ExternalOccurrence P a path id → ExternalOccurrence P (.refined a p) path id

/-- Telの宣言順の番号と結果位置を保持する。 -/
inductive ExternalUseAt (P : Program) : Nat → Tel → ExternalUse → Prop where
  | argument {n name a rest path id} : ExternalOccurrence P a path id →
      ExternalUseAt P n (.param name a rest) ⟨.argument n, path, .borrow, id⟩
  | next {n name a rest use} : ExternalUseAt P (n+1) rest use →
      ExternalUseAt P n (.param name a rest) use
  | result {n a e path id} : ExternalOccurrence P a path id →
      ExternalUseAt P n (.done a e) ⟨.result, path, .own, id⟩

inductive ExternalTelWF (P : Program) (component : ComponentId) (effect : Eff) : Tel → Prop where
  | done {a e} : ExternalValueType P component true a → e = effect →
      ExternalTelWF P component effect (.done a e)
  | param {name a rest} : ExternalValueType P component false a →
      ExternalTelWF P component effect rest → ExternalTelWF P component effect (.param name a rest)

structure ExternalSignature.WF (P : Program) (d : ExternalSignature) : Prop where
  monomorphic : d.tparams = []
  kinds : d.kinds = []
  annotation : Ty.Annotation P [] [] (.dependentFn d.parameters)
  kinded : Ty.HasKind P [] (.dependentFn d.parameters) .value
  uses_exact : ∀ use, use ∈ d.uses ↔ ExternalUseAt P 0 d.parameters use
  uses_unique : d.uses.Nodup
  shape : ExternalTelWF P d.component (if d.uses = [] then Eff.empty else (EffR.mk (fun a => match a with | .name n (.fixed .top) => decide (n = stateEff) | _ => false) [])) d.parameters

structure Program.ExternalWF (P : Program) : Prop where
  unique : (P.externals.map Prod.fst).Nodup
  keys : ∀ key decl, (key, decl) ∈ P.externals → match key, decl with
    | .type id, .type td => td.id = id ∧ td.arity = 0
    | .function id, .function id' d => id = id' ∧ ExternalSignature.WF P d
    | _, _ => False

private theorem externalLookup_mem {P : Program} {key : ExternalKey} {decl : ExternalDecl}
    (h : P.externals.lookup key = some decl) : (key, decl) ∈ P.externals := by
  obtain ⟨l₁, l₂, he, _⟩ := List.lookup_eq_some_iff.mp h
  rw [he]
  exact List.mem_append_right _ (List.mem_cons_self)

theorem Program.ExternalWF.type_lookup {P : Program} (hw : P.ExternalWF) {id td}
    (h : P.externalType id = some td) : td.id = id ∧ td.arity = 0 := by
  unfold Program.externalType at h
  cases he : P.externals.lookup (.type id) with
  | none => simp [he] at h
  | some decl =>
    cases decl with
    | type d =>
      simp only [he, Option.some.injEq] at h
      cases h
      exact hw.keys _ _ (externalLookup_mem he)
    | function _ _ => simp [he] at h

theorem Program.ExternalWF.function_lookup {P : Program} (hw : P.ExternalWF) {f d}
    (h : P.externalFunction f = some d) : d.WF P := by
  unfold Program.externalFunction at h
  cases he : P.externals.lookup (.function f) with
  | none => simp [he] at h
  | some decl =>
    cases decl with
    | type _ => simp [he] at h
    | function id sg =>
      simp only [he, Option.some.injEq] at h
      cases h
      exact (hw.keys _ _ (externalLookup_mem he)).2

/-- 宣言は単相であるが、コアの呼出しは型引数の個数・kind・制約を明示して照合する。 -/
structure ExternalCallAdmissible (P : Program) (B : Builtins) (C : TypeCtx)
    (d : ExternalSignature) (ts : List Ty) : Prop where
  count : ts.length = d.tparams.length
  kinds : TypeArgsKinded P C ts d.kinds
  constraints : SatAll B C ts d.tparams
  types : TypeAnnotations P C [] ts

theorem ExternalCallAdmissible.types_nil {P B C d ts} (h : ExternalCallAdmissible P B C d ts)
    (hw : d.WF P) : ts = [] := by
  have := h.count
  rw [hw.monomorphic] at this
  exact List.eq_nil_of_length_eq_zero this

theorem ExternalCallAdmissible.map {P B C d ts} (h : ExternalCallAdmissible P B C d ts)
    (hw : d.WF P) (g : Ty → Ty) : ExternalCallAdmissible P B C d (ts.map g) := by
  rw [h.types_nil hw] at *
  exact h

end
end Benitoite.Release.Refinement
