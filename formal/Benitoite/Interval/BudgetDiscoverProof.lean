import Benitoite.Interval.BudgetDiscover
import Benitoite.Interval.BudgetTraversal

/-! # 予算付きの発見と数学的なmanifestの対応 -/
namespace Benitoite.Interval.BudgetDiscovery
open Benitoite.Surface Benitoite.Release Budget
open BudgetAnalysis (Halt numberFrom)

/-- 証明用の射影。環境や予算を比較のために再走査しない。 -/
structure View where
  next : OperationKey
  identitiesRev : List (OperationKey × Expr)
  entriesRev : List EmbeddedBody

def view (ctx : Context) : View :=
  ⟨ctx.walk.next, ctx.walk.identitiesRev, ctx.entriesRev.map Entry.embedded⟩

def emit (entries : List EmbeddedBody) (v : View) : View :=
  { v with entriesRev := entries.reverse ++ v.entriesRev }

def numberedStep (source : Expr) (v : View) : View :=
  ⟨advanceKey v.next 1, v.identitiesRev,
    (embeddedBodies v.next source).reverse ++ v.entriesRev⟩

def visit (sources : List Expr) (v : View) : View := sources.foldl (fun v e => numberedStep e v) v

@[simp] theorem visit_nil (v : View) : visit [] v = v := rfl
@[simp] theorem visit_cons (e es v) : visit (e :: es) v = visit es (numberedStep e v) := rfl
theorem visit_append (xs ys v) : visit (xs ++ ys) v = visit ys (visit xs v) :=
  List.foldl_append

/-- 完走した場合の対応。停止を完走の前提に偽装せず、別に保存列を扱う。 -/
def Transforms (work : Discovery α) (f : View → View) : Prop :=
  ∀ limits ctx value final, work limits ctx = (.ok value, final) → view final = f (view ctx)

theorem transforms_pure (value : α) : Transforms (pure value) id := by
  intro limits ctx result final h
  cases h
  rfl

theorem transforms_throw (reason : Halt) (f : View → View) :
    Transforms (throw reason : Discovery α) f := by
  intro limits ctx value final h
  cases h

theorem transforms_bind {first : Discovery α} {next : α → Discovery β} {f g : View → View}
    (hf : Transforms first f) (hn : ∀ value, Transforms (next value) g) :
    Transforms (first >>= next) (g ∘ f) := by
  intro limits ctx value final h
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind] at h
  cases eq : first limits ctx with
  | mk outcome middle =>
    cases outcome with
    | error reason =>
      simp only [eq, ExceptT.bindCont, pure, StateT.pure] at h
      cases h
    | ok firstValue =>
      have hi := hf limits ctx firstValue middle eq
      have hj := hn firstValue limits middle value final (by rw [eq] at h; exact h)
      exact hj.trans (congrArg g hi)

theorem transforms_scan (work : BudgetScan.Scan α) : Transforms (scan work) id := by
  intro limits ctx value final h
  unfold scan lift BudgetAnalysis.scan at h
  cases eq : work.run limits ctx.walk.budget <;> simp only [eq] at h
  case stopped => cases h
  obtain ⟨rfl, rfl⟩ := h
  rfl

theorem transforms_scan_bind {work : BudgetScan.Scan α} {expected : α}
    {next : α → Discovery β} {f : View → View}
    (agrees : BudgetScan.Agrees work expected) (hn : Transforms (next expected) f) :
    Transforms (scan work >>= next) f := by
  intro limits ctx value final h
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind] at h
  cases eq : scan work limits ctx with
  | mk outcome middle =>
    cases outcome with
    | error reason =>
      simp only [eq, ExceptT.bindCont, pure, StateT.pure] at h
      cases h
    | ok found =>
      have same : found = expected := by
        unfold scan lift BudgetAnalysis.scan at eq
        cases run : work.run limits ctx.walk.budget <;> simp only [run] at eq
        case stopped => cases eq
        obtain ⟨rfl, rfl⟩ := eq
        exact agrees limits ctx.walk.budget found _ run
      subst found
      have hi := transforms_scan work limits ctx expected middle eq
      exact (hn limits middle value final (by rw [eq] at h; exact h)).trans (congrArg f hi)

theorem transforms_scope {work : Unit → Discovery α} {f : View → View}
    (hwork : Transforms (work ()) f) : Transforms (scope work) f := by
  intro limits ctx value final h
  unfold scope at h
  cases eq : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    cases outcome with
    | error reason =>
      simp only [eq] at h
      cases h
    | ok ignored =>
      have hi := transforms_scan (BudgetScan.allocate .stackFrame) limits ctx ignored entered eq
      cases run : work () limits entered with
      | mk outcome last =>
        simp only [eq, run] at h
        obtain ⟨rfl, rfl⟩ := h
        exact (hwork limits entered value last run).trans (congrArg f hi)

theorem transforms_saveEntry (entry : EmbeddedBody) (prepare : BudgetScan.Scan AbstractEnv) :
    Transforms (saveEntry entry prepare) (emit [entry]) := by
  unfold saveEntry
  apply transforms_scan_bind (BudgetScan.agrees_unit _)
  intro limits ctx value final h
  cases hp : scan prepare limits ctx with
  | mk prepared middle =>
    cases prepared with
    | error reason => simp only [hp] at h; cases h
    | ok env =>
      have hm := transforms_scan prepare limits ctx env middle hp
      cases hf : scan (BudgetScan.forgetEnv env) limits middle with
      | mk forgotten last =>
        cases forgotten with
        | error reason => simp only [hp, hf] at h; cases h
        | ok initial =>
          have hl := transforms_scan (BudgetScan.forgetEnv env) limits middle initial last hf
          simp only [hp, hf, Except.toOption] at h
          obtain ⟨rfl, rfl⟩ := h
          change emit [entry] (view last) = emit [entry] (view ctx)
          simp only [hl, hm, id_eq]

theorem transforms_saveClauses (env owner start ordinal clauses) :
    Transforms (saveClauses env owner start ordinal clauses)
      (emit (clauseBodies owner start ordinal clauses)) := by
  rw [saveClauses.eq_def]
  apply transforms_scope
  apply transforms_scan_bind (BudgetScan.agrees_unit _)
  cases clauses with
  | nil => exact transforms_pure _
  | cons op arity ntys body rest dictCount =>
    have head := transforms_scope (work := fun _ => saveEntry
      ⟨owner, ordinal, .handler, body, start⟩ (clauseEnv env arity dictCount))
      (transforms_saveEntry _ _)
    have tail := transforms_scan_bind (next := fun count =>
      saveClauses env owner (start + count) (ordinal + 1) rest) (BudgetScan.countBlock_agrees body)
      (transforms_saveClauses env owner (start + (preorderBlock body).length) (ordinal + 1) rest)
    have both := transforms_bind head (fun _ => tail)
    have same :
        (emit (clauseBodies owner (start + (preorderBlock body).length) (ordinal + 1) rest) ∘
          emit [⟨owner, ordinal, .handler, body, start⟩]) =
        emit (clauseBodies owner start ordinal (.cons op arity ntys body rest dictCount)) := by
      funext v
      simp [clauseBodies, emit, List.reverse_cons, List.append_assoc]
    rw [same] at both
    exact both

/-- 出現の一番号を取得した後の処理を、根の先行順へ接続する。 -/
theorem transforms_identify_bind (source : Expr) (children : List Expr)
    (work : OperationKey → Discovery α)
    (hwork : ∀ owner, Transforms (work owner)
      (fun v => visit children (emit (embeddedBodies owner source) v))) :
    Transforms (lift (reidentify source) >>= work)
      (visit (source :: children)) := by
  intro limits ctx value final h
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind] at h
  cases run : reidentify source limits ctx.walk with
  | mk outcome middle =>
    cases outcome with
    | error reason => simp only [lift, run, ExceptT.bindCont, pure, StateT.pure] at h; cases h
    | ok key =>
      have info := reidentify_success source limits ctx.walk run
      have hw := hwork key limits { ctx with walk := middle } value final
        (by simp only [lift, run] at h; exact h)
      rw [hw]
      simp only [visit_cons, emit, view, numberedStep]
      congr 1
      cases ctx
      simp_all [advanceKey]

theorem transforms_before_scan (work : BudgetScan.Scan α) (next : α → Discovery β)
    {f : View → View} (hn : ∀ value, Transforms (next value) f) :
    Transforms (scan work >>= next) f := by
  simpa only [Function.comp_id] using transforms_bind (transforms_scan work) hn

theorem transforms_then {first : Discovery α} {next : α → Discovery β} {xs ys : List Expr}
    (hf : Transforms first (visit xs)) (hn : ∀ value, Transforms (next value) (visit ys)) :
    Transforms (first >>= next) (visit (xs ++ ys)) := by
  have same : (visit ys ∘ visit xs) = visit (xs ++ ys) := by
    funext v; exact (visit_append xs ys v).symm
  rw [← same]
  exact transforms_bind hf hn

/-- 完走した発見は、値の到達・未対応によらず元の全出現を一度だけ辿り、
境界の先行順と節順にmanifestを保存する。環境はこの対応に関与しない。 -/
theorem discovery_complete (fuel : Nat) :
    (∀ env source, Transforms (expr fuel env source) (visit (surfacePreorder source))) ∧
    (∀ env sources, Transforms (exprs fuel env sources) (visit (preorderExprs sources))) ∧
    (∀ env args, Transforms (holes fuel env args) (visit (preorderHoles args))) ∧
    (∀ env body, Transforms (block fuel env body) (visit (preorderBlock body))) ∧
    (∀ env arms, Transforms (armList fuel env arms) (visit (preorderArms arms))) ∧
    (∀ env clauses, Transforms (clauseList fuel env clauses) (visit (preorderClauses clauses))) ∧
    (∀ env source, Transforms (optional fuel env source)
      (visit (match source with | none => [] | some e => surfacePreorder e))) := by
  induction fuel with
  | zero => exact ⟨fun _ _ => transforms_throw _ _, fun _ _ => transforms_throw _ _,
      fun _ _ => transforms_throw _ _, fun _ _ => transforms_throw _ _,
      fun _ _ => transforms_throw _ _, fun _ _ => transforms_throw _ _,
      fun _ _ => transforms_throw _ _⟩
  | succ fuel ih =>
    obtain ⟨he, hes, hh, hb, ha, hc, ho⟩ := ih
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro env source
      rw [expr]
      apply transforms_scope
      have split : surfacePreorder source = source :: (surfacePreorder source).tail := by
        cases source <;> try rfl
        all_goals rename_i message; cases message <;> rfl
      rw [split]
      apply transforms_identify_bind
      intro owner
      apply transforms_scan_bind (BudgetScan.agrees_unit _)
      cases source <;> simp only [surfacePreorder, List.tail_cons, embeddedBodies]
      all_goals try (simp only [emit, List.reverse_nil, List.nil_append, List.append_assoc])
      all_goals first
        | exact transforms_pure _
        | exact he _ _
        | exact hes _ _
        | exact hh _ _
        | exact hb _ _
        | exact transforms_then (he _ _) (fun _ => he _ _)
        | exact transforms_then (he _ _) (fun _ => hes _ _)
        | exact transforms_then (he _ _) (fun _ => hh _ _)
        | exact transforms_then (he _ _) (fun _ => hb _ _)
        | exact transforms_then (he _ _) (fun _ => ha _ _)
        | exact transforms_then (he _ _) (fun _ => ho _ _)
        | exact transforms_then (hes _ _) (fun _ => hes _ _)
        | exact transforms_then (he _ _) (fun _ => transforms_then (hb _ _) (fun _ => hb _ _))
        | exact transforms_then (he _ _) (fun _ => transforms_then (hb _ _) (fun _ => he _ _))
        | exact transforms_then (he _ _) (fun _ => transforms_then (hes _ _) (fun _ =>
            transforms_then (he _ _) (fun _ => hes _ _)))
        | skip
      case tryResultDie type ok err dict showMethod exit e message =>
        cases message <;> simp only [surfacePreorder, List.tail_cons]
        · exact transforms_then (he env e) (fun _ => ho env none)
        · exact transforms_then (he env e) (fun _ => ho env _)
      case tryOptionDie type someCon noneCon exit e message =>
        cases message <;> simp only [surfacePreorder, List.tail_cons]
        · exact transforms_then (he env e) (fun _ => ho env none)
        · exact transforms_then (he env e) (fun _ => ho env _)
      case lam names params ret eff body =>
        exact transforms_bind (transforms_saveEntry _ _) (fun initial => hb initial body)
      case lazyE body =>
        exact transforms_bind (transforms_saveEntry _ _) (fun initial => hb initial body)
      case withE name child body =>
        apply transforms_then (he env child)
        intro _
        apply transforms_before_scan
        intro inner
        exact hb inner body
      case handleFail error result body clause =>
        apply transforms_scan_bind (BudgetScan.countBlock_agrees body)
        exact transforms_bind (transforms_saveEntry _ _) (fun initial =>
          transforms_then (hb env body) (fun _ => hb initial clause))
      case handleE body clauses =>
        apply transforms_scan_bind (BudgetScan.countBlock_agrees body)
        exact transforms_bind (transforms_saveClauses _ _ _ _ _) (fun _ =>
          transforms_then (hb env body) (fun _ => hc env clauses))
    · intro env sources
      rw [exprs.eq_def]
      apply transforms_scope; apply transforms_scan_bind (BudgetScan.agrees_unit _)
      cases sources with
      | nil => exact transforms_pure _
      | cons e rest => exact transforms_then (he env e) (fun _ => hes env rest)
    · intro env args
      rw [holes.eq_def]
      apply transforms_scope; apply transforms_scan_bind (BudgetScan.agrees_unit _)
      cases args with
      | nil => exact transforms_pure _
      | expr _ _ e rest => exact transforms_then (he env e) (fun _ => hh env rest)
      | hole _ _ _ rest => exact hh env rest
    · intro env body
      rw [block.eq_def]
      apply transforms_scope; apply transforms_scan_bind (BudgetScan.agrees_unit _)
      cases body <;> first
        | exact transforms_pure _
        | exact he _ _
        | exact transforms_then (he _ _) (fun _ => hb _ _)
        | apply transforms_before_scan; intro inner; exact hb inner _
        | apply transforms_then (he _ _); intro _; apply transforms_before_scan
          intro inner; exact hb inner _
    · intro env arms
      cases arms with
      | nil =>
        simp only [armList]
        apply transforms_scope; apply transforms_scan_bind (BudgetScan.agrees_unit _)
        exact transforms_pure _
      | cons alts guard body rest =>
        simp only [armList]
        apply transforms_scope; apply transforms_scan_bind (BudgetScan.agrees_unit _)
        cases guard with
        | none =>
          apply transforms_then (xs := [] ++ preorderBlock body) (ys := preorderArms rest)
          · apply transforms_scope; apply transforms_before_scan; intro count
            apply transforms_before_scan; intro locals
            exact transforms_then (ho _ none) (fun _ => hb _ body)
          · intro _; exact ha env rest
        | some g =>
          apply transforms_then (xs := surfacePreorder g ++ preorderBlock body) (ys := preorderArms rest)
          · apply transforms_scope; apply transforms_before_scan; intro count
            apply transforms_before_scan; intro locals
            exact transforms_then (ho _ (some g)) (fun _ => hb _ body)
          · intro _; exact ha env rest
    · intro env clauses
      rw [clauseList.eq_def]
      apply transforms_scope; apply transforms_scan_bind (BudgetScan.agrees_unit _)
      cases clauses with
      | nil => exact transforms_pure _
      | cons op arity ntys body rest dictCount =>
        apply transforms_then (xs := preorderBlock body) (ys := preorderClauses rest)
        · apply transforms_scope; apply transforms_before_scan; intro inner
          exact hb inner body
        · intro _; exact hc env rest
    · intro env source
      cases source with
      | none => exact transforms_pure _
      | some e => exact he env e

/-- 数学的な訪問列から、次キーと別本体の順序、対応表を作らないことを読む。 -/
theorem visit_fields (sources : List Expr) (v : View) :
    (visit sources v).next = advanceKey v.next sources.length ∧
    (visit sources v).identitiesRev = v.identitiesRev ∧
    (visit sources v).entriesRev =
      ((numberFrom v.next sources).flatMap fun (key, source) => embeddedBodies key source).reverse ++
        v.entriesRev := by
  induction sources generalizing v with
  | nil => simp [visit, numberFrom]
  | cons source rest ih =>
    have h := ih (numberedStep source v)
    simpa [visit_cons, numberFrom, numberedStep, BudgetAnalysis.advanceKey_add,
      List.reverse_cons, List.reverse_append, List.append_assoc, Nat.add_comm] using h

/-- 実際の発見順は、既存のbodyManifestの境界先行順・節順と一致する。
停止時の結果について全発見を主張しない。 -/
theorem discover_manifest {limits state fuel definition seed value final}
    (ok : (discover limits state fuel definition seed).result = .ok value)
    (ctx : (discover limits state fuel definition seed).context = final) :
    final.entriesRev.map Entry.embedded = (bodyManifest definition seed.body).reverse ∧
    final.walk.next = advanceKey (bodyRootKey definition) (surfaceSize (bodyRoot seed.body)) ∧
    final.walk.identitiesRev = [] := by
  have h : Transforms
      (scope fun _ => do
        let initial ← scan (BudgetScan.forgetEnv seed.initial)
        expr fuel initial (bodyRoot seed.body)) (visit (surfacePreorder (bodyRoot seed.body))) := by
    apply transforms_scope
    apply transforms_before_scan
    intro initial
    exact (discovery_complete fuel).1 initial _
  let start : Context := ⟨{ budget := state, next := bodyRootKey definition }, []⟩
  have run : (scope fun _ => do
        let initial ← scan (BudgetScan.forgetEnv seed.initial)
        expr fuel initial (bodyRoot seed.body)) limits start = (.ok value, final) := by
    have first := ok
    have second := ctx
    unfold discover at first second
    cases run : (scope fun _ => do
      let initial ← scan (BudgetScan.forgetEnv seed.initial)
      expr fuel initial (bodyRoot seed.body)) limits start with
    | mk outcome last =>
      simp only [start, run] at first second
      exact Prod.ext first second
  have same := h limits start value final run
  have fields := visit_fields (surfacePreorder (bodyRoot seed.body)) (view start)
  rw [← same] at fields
  simp only [view, start, List.map_nil, List.append_nil, BudgetAnalysis.numberFrom_numbered] at fields
  exact ⟨fields.2.2, fields.1, fields.2.1⟩

/-- 引数の逐次構築は、既存の束縛順の指定と一致する。 -/
theorem typedValues_agrees (env : AbstractEnv) (types : List Ty) :
    BudgetScan.Agrees (typedValues env types) (extendValues env (types.map some)) := by
  rw [typedValues.eq_def]
  apply BudgetScan.agrees_frame
  apply BudgetScan.agrees_bind (BudgetScan.agrees_unit _)
  cases types with
  | nil => exact BudgetScan.agrees_pure _
  | cons type rest =>
    apply BudgetScan.agrees_bind (BudgetScan.push_agrees env (topSlot (some type)))
    simpa [extendValues, extend, List.reverse_cons, List.map_append, List.append_assoc,
      RangeState.extendUnknown, RangeState.extendUnknown_extend] using
      typedValues_agrees (extend env (topSlot (some type))) rest

/-- 保存した入口には、捕捉値や引数の狭い整数区間を持ち込まない。 -/
theorem saveEntry_top {entry prepare limits ctx initial final}
    (ok : saveEntry entry prepare limits ctx = (.ok initial, final)) :
    ∀ index, integerAt initial index = top := by
  unfold saveEntry at ok
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind] at ok
  cases slot : scan (BudgetScan.allocate .auxiliary .saved) limits ctx with
  | mk outcome ready =>
    cases outcome with
    | error reason => simp only [slot, ExceptT.bindCont, pure, StateT.pure] at ok; cases ok
    | ok ignored =>
      simp only [slot, ExceptT.bindCont] at ok
      cases prep : scan prepare limits ready with
      | mk prepared middle =>
        cases prepared with
        | error reason => simp only [prep] at ok; cases ok
        | ok env =>
          cases forgotten : scan (BudgetScan.forgetEnv env) limits middle with
          | mk result last =>
            cases result with
            | error reason => simp only [prep, forgotten] at ok; cases ok
            | ok saved =>
              have agrees : saved = forget env := by
                unfold scan lift BudgetAnalysis.scan at forgotten
                cases run : (BudgetScan.forgetEnv env).run limits middle.walk.budget <;>
                  simp only [run] at forgotten
                case stopped => cases forgotten
                obtain ⟨rfl, rfl⟩ := forgotten
                exact BudgetScan.forgetEnv_agrees env limits middle.walk.budget saved _ run
              simp only [prep, forgotten] at ok
              cases ok
              rw [agrees]
              exact integerAt_forget _

end Benitoite.Interval.BudgetDiscovery
