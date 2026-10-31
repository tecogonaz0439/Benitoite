import Lean
import Benitoite

namespace Benitoite.Release.Refinement.AtReviewBoundary
noncomputable section
set_option maxRecDepth 8192
set_option maxHeartbeats 4000000
open Scope.Domain

def σ : PathEnv := ⟨["project"], ["project", "src"], ["home"], none, none, none⟩
def other : PathEnv := {σ with cwd := ["elsewhere"]}
def emptySecrets : PathEnv := {σ with secrets := some []}
def pat : RangeExpr := .based .root (.tree ["data"])
def t : Target := .path ["project", "data", "a.txt"]
def shape : ResultShape := ⟨"Result", "Ok", "Error", atErrorType⟩
def requestDecl : ConDecl := ⟨"Http.ClientRequest", 0,
  [.base .string, .base .string, .list (.base .string), .bytes, .base .integer]⟩
def okDecl : ConDecl := ⟨"Result", 2, [.tvar 0]⟩
def errorDecl : ConDecl := ⟨"Result", 2, [.tvar 1]⟩
def diagnosticDecl : ConDecl := ⟨"Scope.ScopeError", 0, atErrorFields⟩
def P : Program :=
  { defs := fun _ => none
    cons := fun c => match c with
      | "Http.ClientRequest" => some requestDecl
      | "Ok" => some okDecl
      | "Error" => some errorDecl
      | "Scope.ScopeError.At" => some diagnosticDecl
      | _ => none
    ops := fun _ => none, effects := fun _ => none
    classes := fun _ => none, impls := fun _ => none }
def requestType : Ty := .data "Http.ClientRequest" []
def baseSig : PrimSig :=
  { tparams := [], neffs := 0, names := [], params := [], ret := .pathBases,
    eff := Eff.single processEnvironmentEff, admits := fun _ _ => True,
    kind := .pathBases, opEff := some processEnvironmentEff }
def B : Builtins :=
  { sig := fun b => if b = "Scope.pathBases" then some baseSig else none
    delta := fun _ _ _ _ _ => none, ioResponse := fun _ _ _ _ _ _ => False
    releaseResponse := fun _ _ => True, isResource := fun _ => false
    effects := fun _ => none, sat := fun _ _ _ => True, refGet := "get", refSet := "set"
    valKind := fun o => if o = "Scope.PathIn" then some .path else
      if o = "Http.RequestIn" then some .endpoint else none
    valContent := fun o => if o = "Http.RequestIn" then some requestType else none }

theorem sigma_valid : σ.Valid := by decide
theorem token_typed : HasTypeV P B StoreTy.empty [] [] [] (.pathBases σ) .pathBases := .V_PathBases sigma_valid
theorem token_same_run : (Val.pathBases σ).Adequate σ := rfl
theorem foreign_token_rejected : ¬ (Val.pathBases other).Adequate σ := by
  change other ≠ σ
  intro h; exact (by decide : other.cwd ≠ σ.cwd) (congrArg PathEnv.cwd h)

theorem checked_typed : HasTypeV P B StoreTy.empty [] [] []
    (.checkedAt pat (some σ) t none) (.scoped "Scope.PathIn" .path (.fixed pat)) :=
  .V_CheckedAt (.plain rfl rfl rfl (by decide))

theorem checked_current : pat.Mem σ .path t :=
  CheckedWitness.membership (.plain (P := P) (B := B) (Ψ := StoreTy.empty)
    (o := "Scope.PathIn") (snapshot := some σ) rfl rfl rfl (by decide)) rfl

theorem unbound_is_error : (checkAt (some σ) .path (.based .work (.tree []))
    (.absolute t) .top) = .error (atDetail (some σ) (.based .work (.tree [])) (.absolute t) (.unbound .work)) := by decide

theorem empty_secrets_is_bound : checkAt (some emptySecrets) .path .secrets (.absolute t) .top =
    .error (atDetail (some emptySecrets) .secrets (.absolute t) .dynamicCondition) := by decide

theorem missing_secrets_is_unbound : checkAt (some σ) .path .secrets (.absolute t) .top =
    .error (atDetail (some σ) .secrets (.absolute t) .secretsUnbound) := by decide

theorem dynamic_and_index_failures_distinct :
    checkAt (some σ) .path pat (.absolute t) (.path (.exact ["another"])) =
      .error (atDetail (some σ) pat (.absolute t) .staticIndex) := by decide

theorem absolute_without_token : checkAt none .path (.path (.tree ["project"])) (.absolute t) .top = .ok t := by decide

theorem relative_uses_cwd : TargetInput.resolve σ (.relativePath ["a"]) =
    some (.path ["project", "src", "a"]) := rfl

theorem literal_star_in_base : checkAt (some ⟨["*"], [], [], none, none, none⟩) .path
    (.based .root (.tree [])) (.absolute (.path ["*", "a"])) .top = .ok (.path ["*", "a"]) := by decide

theorem shape_declared : shape.Declared P := by
  have arity (d : DataName) (n : Nat) (c : ConName) (cd : ConDecl)
      (hc : P.cons c = some cd) (hd : cd.data = d) (hn : cd.ntys = n)
      (hall : ∀ c cd, P.cons c = some cd → cd.data = d → cd.ntys = n) : P.DataArity d n :=
    ⟨⟨c,cd,hc,hd⟩,hall⟩
  constructor
  · refine ⟨rfl, ?_, diagnosticDecl, rfl, rfl, rfl, rfl⟩
    apply arity _ _ "Scope.ScopeError.At" diagnosticDecl rfl rfl rfl
    intro c cd hc hd
    simp only [P] at hc
    split at hc <;> cases hc <;> simp_all [requestDecl, okDecl, errorDecl, diagnosticDecl]
  · apply arity _ _ "Ok" okDecl rfl rfl rfl
    intro c cd hc hd
    simp only [P] at hc
    split at hc <;> cases hc <;> simp_all [requestDecl, okDecl, errorDecl, diagnosticDecl]
  · decide
  · exact ⟨okDecl, rfl, rfl, rfl, rfl⟩
  · exact ⟨errorDecl, rfl, rfl, rfl, rfl⟩

def req : Val := .con "Http.ClientRequest" []
  [.const (.string "GET"), .const (.string "http://a"), .list [], .bytesV [],
   .const (.integer ⟨30000, by decide⟩)]
def endpoint : Target := .endpoint ⟨.name ["a"], 80⟩

theorem request_ground : req.Ground := groundVal_ground (by decide : groundVal req = true)
theorem request_endpoint : req.reqTarget = some endpoint := by
  change parseUrlTarget "http://a" = some endpoint
  cbv

theorem request_typed : HasTypeV P B StoreTy.empty [] [] [] req requestType := by
  apply HasTypeVQ.V_Con (cd := requestDecl) rfl rfl
  · exact ⟨rfl, [], rfl, by intro i a k hi; simp at hi⟩
  · intro a ha
    simp only [requestDecl, List.mem_cons, List.not_mem_nil, or_false] at ha
    rcases ha with rfl | rfl | rfl | rfl | rfl <;> trivial
  · exact .cons (.V_Const trivial) (.cons (.V_Const trivial)
      (.cons (.V_List .nil trivial trivial trivial) (.cons (.V_Bytes (by simp))
        (.cons (.V_Const trivial) .nil))))
  · refine ⟨trivial, trivial, ?_⟩
    refine ⟨⟨0, ?_, rfl⟩, trivial⟩
    refine ⟨⟨"Http.ClientRequest",requestDecl,rfl,rfl⟩, ?_⟩
    intro c cd hc hd
    simp only [P] at hc
    split at hc <;> cases hc <;> simp_all [requestDecl, okDecl, errorDecl, diagnosticDecl]

theorem retained_request_typed : HasTypeV P B StoreTy.empty [] [] []
    (.checkedAt .top none endpoint (some req)) (.scoped "Http.RequestIn" .endpoint (.fixed .top)) :=
  .V_CheckedAt (.request rfl rfl request_typed request_ground request_endpoint ⟨rfl, trivial⟩)

theorem wrong_endpoint_rejected : req.reqTarget ≠ some (.endpoint ⟨.name ["evil", "example"], 443⟩) := by
  rw [request_endpoint]
  decide

theorem bare_request_rejected : ¬ CheckedWitness P B StoreTy.empty "Http.RequestIn" .endpoint .top none endpoint none := by
  intro h; cases h with | plain _ hc _ _ => cases hc

theorem open_request_rejected : ¬ (Val.con "Http.ClientRequest" [.tvar 0] []).Ground := by
  simp [Val.Ground, Val.ClosedAt, Ty.WF]

theorem checked_snapshot_subst :
    ((Val.checkedAt .top none endpoint (some req)).subst (fun _ => .const .unit)).toTerm? =
      some (.targetValue none endpoint) := rfl

theorem index_rejected : AtPrepare B Capture.empty .path "Scope.PathIn" none
    (.scopePattern .top) (.const (.string "/")) (.rvar 0) =
      .error (atDetail none .top (.absolute (.path [])) .staticIndex) := rfl

theorem prepare_index : AtPrepared B Capture.empty .path "Scope.PathIn" none
    (.scopePattern .top) (.const (.string "/")) (.fixed .top)
    none .top (.absolute (.path [])) .top := by
  cbv

theorem prepared_index_exact : RangeIx.fixed .top = .fixed (.absolute .top) := AtPrepared.fixed_index prepare_index

theorem path_bases_effect : HasTypeCQ P B StoreTy.empty Qempty [] [] [] none
    (.issuePathBases "Scope.pathBases") .pathBases (Eff.single processEnvironmentEff) [] :=
  .C_IssuePathBases _ _ rfl rfl rfl rfl rfl rfl

theorem issue_event : Step P B σ
    (.run (.pure (.issuePathBases "Scope.pathBases")) [] Store.empty)
    (some (.pathBases "Scope.pathBases" σ)) (.run (.pure (.ret (.pathBases σ))) [] Store.empty) :=
  .E_IssuePathBases rfl rfl rfl rfl sigma_valid

theorem at_success_transition : Step P B σ
    (.run (.pure (.checkAt .path "Scope.PathIn" shape none (.scopePattern .top)
      (.const (.string "/")) (.fixed .top))) [] Store.empty) none
    (.run (.pure (.ret (.con "Ok" [.scoped "Scope.PathIn" .path (.fixed .top), atErrorType]
      [.checkedAt .top none (.path []) none]))) [] Store.empty) :=
  .E_AtOk (P := P) (B := B) (σ := σ)
    (q := .pure (.checkAt .path "Scope.PathIn" shape none (.scopePattern .top) (.const (.string "/")) (.fixed .top)))
    (shape := shape) (bases := none) (pattern := .scopePattern .top) (input := .const (.string "/")) (index := .fixed .top)
    (kind := .path) (name := "Scope.PathIn") (snapshot := none) (pat := .top) (bound := .top)
    (target := .absolute (.path [])) (t := .path []) rfl prepare_index (by intro ρ h; cases h) (by decide)

-- 長い字句の例は実行して照合する。証明へnativeな真偽を注入しない。
run_cmd do
  unless parseUrlTarget "https://api.example.com/path" = some (.endpoint ⟨.name ["api", "example", "com"],443⟩) do
    throwError "URLの端点が一致しない"
  unless parseUrlTarget "https://user@api.example.com/%ZZ" = none do
    throwError "不正なURLを受け付けた"
  unless parseUrlTarget "https://[::ffff:192.0.2.1]/" = some (.endpoint ⟨.ip (.v6 281473902969345),443⟩) do
    throwError "IPv6の族又は数値を失った"
  unless parseAtInput .path (.const (.string "~/data")) = some (.homePath ["data"]) do
    throwError "homeの起点を失った"
  for bad in ["../x", "a/./b", "a//b", "a/", "~user/x"] do
    unless parseAtInput .path (.const (.string bad)) = none do
      throwError "不正なパスを受け付けた: {bad}"
  unless parseAtInput .path (.const (.string "./data")) = some (.relativePath ["data"]) do
    throwError "先頭./を受け付けない"

theorem initial_does_not_require_dynamic_pattern :
    PreparationNode.Child P B (.val (.scopePattern (.based .work (.tree [])))) (.range (.based .work (.tree []))) = False := rfl

theorem wrong_request_witness_rejected : ¬ CheckedWitness P B StoreTy.empty "Http.RequestIn"
    .endpoint .top none (.endpoint ⟨.name ["evil", "example"], 443⟩) (some req) := by
  intro h
  cases h with | request _ _ _ _ ht _ => exact wrong_endpoint_rejected ht

theorem open_held_request_not_ground :
    ¬ (Val.checkedAt .top none endpoint (some (.var 0))).Ground := by
  simp [Val.Ground, Val.ClosedAt]

theorem at_call_admissible : AtCallAdmissible P B StoreTy.empty Qempty [] [] [] .path
    "Scope.PathIn" shape none (.scopePattern .top) (.const (.string "/")) (.fixed .top) := by
  refine .mk shape_declared rfl (by intro v h; cases h)
    (.V_ScopePattern trivial trivial (by decide)) (Or.inl ⟨rfl,rfl⟩) (.V_Const trivial) trivial ?_
  intro r h
  cases h
  exact ⟨trivial,trivial,by decide⟩

theorem at_call_typed : HasTypeCQ P B StoreTy.empty Qempty [] [] [] none
    (.checkAt .path "Scope.PathIn" shape none (.scopePattern .top)
      (.const (.string "/")) (.fixed .top))
    (.data "Result" [.scoped "Scope.PathIn" .path (.fixed .top), atErrorType]) Eff.empty [] :=
  .C_CheckAt at_call_admissible

def needsWork : State := .run (.pure (.checkAt .path "Scope.PathIn" shape none
  (.scopePattern .top) (.const (.string "/x")) (.fixed (.based .work (.tree []))))) [] Store.empty

theorem known_index_requires_work : PathEnv.Required P B needsWork (.base .work) := by
  apply PathEnv.Required.base (p := .tree [])
  exact .child (.child (.child .root (Or.inl rfl)) (Or.inr rfl)) (Or.inr (Or.inl rfl))

theorem missing_known_base_rejected_at_preparation : ¬ σ.Ready P B needsWork := by
  intro h
  obtain ⟨w,hw⟩ := h.2 (.base .work) known_index_requires_work
  cases hw


theorem home_resolves_home : TargetInput.resolve σ (.homePath ["x"]) = some (.path ["home", "x"]) := rfl

theorem source_cannot_forge_token : ¬ (Val.pathBases σ).Source := by intro h; cases h

theorem step_issues_same_sigma :
    step P B σ (fun _ _ _ _ => (.val (.const .unit), []))
      (fun _ _ _ => (.val (.const .unit), [])) (fun _ => none) (fun _ => 0)
      (.run (.pure (.issuePathBases "Scope.pathBases")) [] Store.empty) =
      some (some (.pathBases "Scope.pathBases" σ), .run (.pure (.ret (.pathBases σ))) [] Store.empty) := by cbv

theorem step_at_success_pure :
    step P B σ (fun _ _ _ _ => (.val (.const .unit), []))
      (fun _ _ _ => (.val (.const .unit), [])) (fun _ => none) (fun _ => 0)
      (.run (.pure (.checkAt .path "Scope.PathIn" shape none (.scopePattern .top)
        (.const (.string "/")) (.fixed .top))) [] Store.empty) =
      some (none, .run (.pure (.ret (.con "Ok"
        [.scoped "Scope.PathIn" .path (.fixed .top), atErrorType]
        [.checkedAt .top none (.path []) none]))) [] Store.empty) := by cbv


def diagnostic : AtError := atDetail (some σ) .secrets (.absolute t) .secretsUnbound

theorem diagnostic_typed : HasTypeV P B StoreTy.empty [] [] [] (.atError diagnostic) atErrorType :=
  .V_AtError shape_declared

theorem diagnostic_pattern_binds_fields :
    matchVal (.con "Scope.ScopeError.At" (List.replicate 7 .var)) (.atError diagnostic) =
      some diagnostic.values := rfl

theorem diagnostic_string_field_observable :
    ((Val.atError diagnostic).toTerm?.bind fun t => match t with
      | .dataValue _ fields => (fields[0]?).join
      | _ => none) = some (.string (reprStr AtFailure.secretsUnbound)) := rfl


theorem nominal_type_reaches_declared_fields :
    PreparationNode.Child P B (.ty requestType) (.constructor "Http.ClientRequest") :=
  Or.inr ⟨"Http.ClientRequest",requestDecl,rfl,rfl,rfl⟩


/-! RV-L00b.02b-atの進行・署名・被覆・表層の境界。 -/
def pathClause : Clause := .mk (.prim "Scope.pathBases") 0 0 (.ret (.const .unit))
def handled : State := .run (.pure (.issuePathBases "Scope.pathBases"))
  [.handleF Capture.empty [pathClause]] Store.empty

theorem handled_has_handler : ¬ NoHandler [.handleF Capture.empty [pathClause]] (.prim "Scope.pathBases") := by
  intro h
  have hh := h Capture.empty [pathClause] (by simp)
  change true = false at hh
  cases hh

theorem handled_step_exists :
    Step P B σ handled (some (.pathBases "Scope.pathBases" σ))
      (.run (.pure (.ret (.pathBases σ))) [.handleF Capture.empty [pathClause]] Store.empty) :=
  .E_IssuePathBases rfl rfl rfl rfl sigma_valid

theorem handled_executable_step :
    step P B σ (fun _ _ _ _ => (.val (.const .unit), []))
      (fun _ _ _ => (.val (.const .unit), [])) (fun _ => none) (fun _ => 0) handled =
      some (some (.pathBases "Scope.pathBases" σ),
        .run (.pure (.ret (.pathBases σ))) [.handleF Capture.empty [pathClause]] Store.empty) := by cbv

theorem path_signature_shape : baseSig.PathBasesShape := ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

theorem path_shape_excludes_argument (s : PrimSig) (hs : s.PathBasesShape) : s.params = [] := hs.arguments

theorem path_shape_rejects_polymorphism :
    ¬ ({baseSig with neffs := 1} : PrimSig).PathBasesShape := by
  intro h
  have hh : (1 : Nat) = 0 := h.rows
  cases hh

theorem path_shape_not_store : ¬ baseSig.StoreShape := by intro h; cases h

def BE : Builtins := { B with effects := fun l =>
  if l = processEnvironmentEff then some ["Scope.pathBases"] else none }

theorem BE_sig_unique {b sg} (hs : BE.sig b = some sg) : sg = baseSig := by
  change (if b = "Scope.pathBases" then some baseSig else none) = some sg at hs
  split at hs <;> simp_all

theorem BE_sig_kind {b sg} (hs : BE.sig b = some sg) : sg.kind = .pathBases := by
  rw [BE_sig_unique hs]; rfl

/-- 新しい五欄と従来の応答・移送の条件が、PathBasesを持つ同じ表で両立する。 -/
theorem core_with_pathBases : Builtins.CoreAssumptions P BE where
  sat_rename := by intros; trivial
  admits_rename := by
    intro b sg C Γ Δ ts ξ hs
    rw [BE_sig_unique hs]
    intros; trivial
  sat_values := by intros; trivial
  admits_values := by
    intro b sg Ψ Q C Γ Δ Ξ ν ts hs
    rw [BE_sig_unique hs]
    intros; trivial
  external_typed := by intro Ψ f d ts vs a e out obs hw hf; cases hf
  external_exists := by intro Ψ f d ts vs a e hw hf; cases hf
  external_no_targets := by intro Ψ f d ts vs a e out obs hw hf; cases hf
  delta_typed := by
    intro Ψ b sg ts es rs ws a e hs hk
    rw [BE_sig_kind hs] at hk
    cases hk
  io_typed := by
    intro Ψ b sg ts es rs ws a e out obs hs hk
    rw [BE_sig_kind hs] at hk
    rcases hk with h | h <;> cases h
  io_kind := by
    intro Ψ b sg ts es rs ws a e out obs hs ha hr
    cases hr
  io_exists := by
    intro Ψ b sg ts es rs ws a e hs hk
    rw [BE_sig_kind hs] at hk
    rcases hk with h | h <;> cases h
  pathBases_shape := by intro b sg hs hk; rw [BE_sig_unique hs]; exact path_signature_shape
  opEff_io := by intro b sg l hs ho; exact Or.inr (Or.inr (BE_sig_kind hs))
  effect_ops := by
    intro l bs b he hb
    change (if l = processEnvironmentEff then some ["Scope.pathBases"] else none) = some bs at he
    split at he
    · have hbs : bs = ["Scope.pathBases"] := (Option.some.inj he).symm
      rw [hbs] at hb
      have hb' : b = "Scope.pathBases" := List.mem_singleton.mp hb
      subst b
      exact ⟨baseSig,rfl,Or.inr (Or.inr rfl),by simpa [baseSig] using congrArg some ‹l = processEnvironmentEff›.symm⟩
    · cases he
  store_shape := by intro b sg hs hk; exact False.elim (hk (BE_sig_kind hs))
  store_admits := by intro b sg C ts hs hp hi he hk; exact False.elim (hk (BE_sig_kind hs))

theorem core_supplies_issue_typing :
    HasTypeCQ P BE StoreTy.empty Qempty [] [] [] none (.issuePathBases "Scope.pathBases")
      .pathBases (Eff.single processEnvironmentEff) [] :=
  core_with_pathBases.issuePathBases_typed rfl rfl

theorem local_apply_typed (h : Builtins.CoreAssumptions P B) :
    Step P B σ (.run (.pure (.app (.prim "Scope.pathBases" [] [] []) [])) [] Store.empty) none
      (.run (.mk Capture.empty (.issuePathBases "Scope.pathBases")) [] Store.empty) ∧
    ∀ Ψ Q C Γ Φ R Δ, HasTypeCQ P B Ψ Q C Γ Φ R (.issuePathBases "Scope.pathBases")
      .pathBases (Eff.single processEnvironmentEff) Δ :=
  h.pathBases_apply_destination rfl rfl rfl (by intro cap cs hc; cases hc)

theorem event_path_covered :
    (Event.pathBases "Scope.pathBases" σ).Covered B [] [] (Eff.single processEnvironmentEff) :=
  Eff.Covers.refl [] [] _

theorem empty_effect_rejects_issue_event :
    ¬ (Event.pathBases "Scope.pathBases" σ).Covered B [] [] Eff.empty := by
  intro h
  have hm : (Eff.single processEnvironmentEff).mem (.name processEnvironmentEff .top) := by
    simp [Eff.mem, Eff.test, Eff.atoms, Eff.single]
  obtain ⟨a, ha, _⟩ := h.1 _ hm
  simp [Eff.mem, Eff.test, Eff.atoms, Eff.empty] at ha

theorem source_rejects_location (l : Nat) : ¬ (Val.loc l).Source := by intro h; cases h

theorem source_rejects_nested_location (l : Nat) : ¬ (Val.list [.loc l]).Source := by
  intro h; exact h.1

theorem diagnostic_typed_without_closed : HasTypeV P B StoreTy.empty [] [] []
    (.atError diagnostic) atErrorType := .V_AtError shape_declared


end
end Benitoite.Release.Refinement.AtReviewBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (name, _) in env.constants.toList do
    if name.toString.startsWith "Benitoite.Release.Refinement.AtReviewBoundary." then
      elabCommand (← `(command| #print axioms $(mkIdent name)))
