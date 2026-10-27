import Benitoite.Interval.BudgetDiscoverProof
import Benitoite.Interval.BudgetIndependentPosition

/-!
# 検査全体の順序と共有予算

読み込み済みモジュールのソース順、定義順、親本体、元の定義から発見した別本体の順。
別本体の解析結果から再発見しない。深さの停止は予算の停止と別に報告する。
（設計書 01-12「区間解析の検査全体の駆動」）。
-/
namespace Benitoite.Interval.BudgetWhole
open Benitoite.Surface Benitoite.Release Budget
open BudgetAnalysis (Halt)

/-- 型検査成功後の、ソース順の読み取り専用入力。定数のparamsは空とする。
同定表だけをmetadataから借用し、局所位置は新しく構築する。 -/
structure Definition where
  name : String
  kind : BodyKind
  params : List Ty
  body : Block
  metadata : AbstractEnv

structure Module where
  definitions : List Definition

/-- 既存の本体入口に渡した入力と、その入口が返した結果を一緒に保存する。 -/
structure BodyOutput where
  definition : String
  seed : BodySeed
  output : BudgetAnalysis.Report

def runBody (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) : BodyOutput :=
  ⟨definition, seed, BudgetAnalysis.analyzeBody limits state fuel definition seed⟩

/-- 全体が尽きた後は、次の環境・番号・出力枠を作らない。 -/
def exhausted (limits : Limits) (state : Budget.State) : Option Halt :=
  if state.whole.operations ≥ limits.whole.operations then
    some (.budget (.exceeded ⟨.whole, .operations⟩))
  else if state.wholeHeld ≥ limits.whole.items then
    some (.budget (.exceeded ⟨.whole, .items⟩))
  else none

/-- 発見列の反転も有界に行う。途中の列は一時保持であり、失敗すれば返却する。 -/
def reverseEntries (remaining accumulated : List BudgetDiscovery.Entry) :
    BudgetScan.Scan (List BudgetDiscovery.Entry) := BudgetScan.frame fun _ => do
  BudgetScan.tick .classification
  match remaining with
  | [] => pure accumulated
  | entry :: rest =>
    BudgetScan.allocate .auxiliary
    reverseEntries rest (entry :: accumulated)

/-- 完走した待ち行列だけ保存保持へ移す。入力の発見項目と環境は参照を共有する。 -/
def prepareQueue (entries : List BudgetDiscovery.Entry) :
    BudgetAnalysis.Analysis (List BudgetDiscovery.Entry) := fun limits ctx =>
  let (result, final) := BudgetAnalysis.scan (reverseEntries entries []) limits ctx
  match result with
  | .error reason => (.error reason, final)
  | .ok queue =>
    let count := final.budget.body.temporary - ctx.budget.body.temporary
    (.ok queue, { final with budget := save final.budget count (Nat.sub_le _ _) })

theorem reverseEntries_agrees (remaining accumulated : List BudgetDiscovery.Entry) :
    BudgetScan.Agrees (reverseEntries remaining accumulated) (remaining.reverse ++ accumulated) := by
  rw [reverseEntries.eq_def]
  apply BudgetScan.agrees_frame
  apply BudgetScan.agrees_bind (BudgetScan.agrees_unit _)
  cases remaining with
  | nil => exact BudgetScan.agrees_pure _
  | cons entry rest =>
    apply BudgetScan.agrees_bind (BudgetScan.agrees_unit _)
    simpa only [List.reverse_cons, List.append_assoc, List.singleton_append] using
      reverseEntries_agrees rest (entry :: accumulated)

/-- 本体の出力枠を先に確保し、拒否したらその本体を開始しない。 -/
def bodySlot (limits : Limits) (state : Budget.State) : BudgetScan.Outcome Unit :=
  (BudgetScan.region fun _ => BudgetScan.frame fun _ => do
    BudgetScan.tick .classification
    BudgetScan.allocate .auxiliary .saved).run limits state

structure EmbeddedOutput where
  bodiesRev : List BodyOutput := []
  pending : List BudgetDiscovery.Entry := []
  stopped : Option Halt := none
  after : Budget.State

/-- 別本体の番号で標準束縛を読むとき、元の定義の同じ出現へ戻す。
有効範囲は実際の本体の走査が決めるため、長さの事前走査をしない。 -/
def entryEnv (entry : EmbeddedBody) (env : AbstractEnv) : AbstractEnv :=
  { env with apiAt := fun key =>
    if key.definition = entry.definition then
      match key.surfacePreorder with
      | 0 => none
      | i + 1 => env.apiAt ⟨entry.owner.definition, entry.parentStart + i⟩
    else env.apiAt key }

theorem entryEnv_api (entry : EmbeddedBody) (env : AbstractEnv) (i : Nat) :
    (entryEnv entry env).apiAt ⟨entry.definition, i + 1⟩ =
      env.apiAt ⟨entry.owner.definition, entry.parentStart + i⟩ := by
  simp [entryEnv]

theorem entryEnv_parent (entry : EmbeddedBody) (env : AbstractEnv) (i : Nat)
    (inside : i < (preorderBlock entry.body).length) :
    (entryEnv entry env).apiAt ⟨entry.definition, i + 1⟩ =
      (entry.parentKey (i + 1)).bind env.apiAt := by
  simp [entryEnv_api, entry.parentKey_content i inside]

/-- 反転済みの発見列を順に解析する。全体上限では残りの参照だけを保存する。
環境未作成の項目も、解析済みの空本体と取り違えない。 -/
def runEntries (limits : Limits) (fuel : Nat) (entries : List BudgetDiscovery.Entry)
    (state : Budget.State) (outputsRev : List BodyOutput := []) : EmbeddedOutput :=
  match entries with
  | [] => ⟨outputsRev, [], none, state⟩
  | entry :: rest =>
    match exhausted limits state with
    | some reason => ⟨outputsRev, entries, some reason, state⟩
    | none => match entry.initial with
      | none => ⟨outputsRev, entries, none, state⟩
      | some initial => match bodySlot limits state with
        | .stopped reason last => ⟨outputsRev, entries, some (.budget reason), finishBody last⟩
        | .ok _ ready =>
          let kind := match entry.embedded.kind with
            | .lambda => BodyKind.lambda | .lazy => .lazy | _ => .clause
          let seed : BodySeed := ⟨kind, entry.embedded.body, entryEnv entry.embedded initial⟩
          let output := runBody limits ready fuel entry.embedded.definition seed
          runEntries limits fuel rest output.output.after (output :: outputsRev)

structure DefinitionOutput where
  input : Definition
  prepared : Except Halt BodySeed
  root : Option BodyOutput := none
  discovery : Option BudgetDiscovery.Report := none
  queue : Option (Except Halt (List BudgetDiscovery.Entry)) := none
  embedded : EmbeddedOutput

/-- 出力枠の確保後にだけ、引数を一位置ずつ作る。独立入力と異なり、
親解析の後の発見へ渡すseedの環境は保存保持へ移す。 -/
def prepareRoot (input : Definition) : BudgetAnalysis.Analysis BodySeed :=
  BudgetAnalysis.scope fun _ => do
    let env ← BudgetAnalysis.scan (BudgetDiscovery.typedValues (clearLocals input.metadata) input.params)
    let initial ← fun limits ctx =>
      let (result, final) := BudgetAnalysis.scan (BudgetScan.forgetEnv env) limits ctx
      match result with
      | .error reason => (.error reason, final)
      | .ok initial =>
        let count := final.budget.body.temporary - ctx.budget.body.temporary
        (.ok initial, { final with budget := save final.budget count (Nat.sub_le _ _) })
    pure ⟨input.kind, input.body, initial⟩

/-- 入口作成・親解析・発見・待ち行列作成は、同じ本体予算である。
Report.afterを途中で使わず、終了前のcontext.budgetを渡してから一度だけ閉じる。 -/
def runDefinition (limits : Limits) (state : Budget.State) (fuel : Nat) (input : Definition) :
    DefinitionOutput :=
  let (prepared, ready) := prepareRoot input limits
    { budget := state, next := bodyRootKey input.name }
  match prepared with
  | .error reason =>
    ⟨input, .error reason, none, none, none, ⟨[], [], none, finishBody ready.budget⟩⟩
  | .ok seed =>
    let root := runBody limits ready.budget fuel input.name seed
    -- exhaustedの下ではdiscoverを呼ばず、未発見であることをnoneで残す。
    match exhausted limits root.output.context.budget with
    | some reason =>
      ⟨input, .ok seed, some root, none, none, ⟨[], [], some reason, root.output.after⟩⟩
    | none =>
      let discovery := BudgetDiscovery.discover limits root.output.context.budget fuel input.name seed
      match exhausted limits discovery.context.walk.budget with
      | some reason =>
        ⟨input, .ok seed, some root, some discovery, none,
          ⟨[], [], some reason, discovery.after⟩⟩
      | none =>
        let (queue, final) := BudgetAnalysis.scope (fun _ =>
          prepareQueue discovery.context.entriesRev) limits discovery.context.walk
        match queue with
        | .error reason =>
          ⟨input, .ok seed, some root, some discovery, some (.error reason),
            ⟨[], [], none, finishBody final.budget⟩⟩
        | .ok entries =>
          let embedded := runEntries limits fuel entries (finishBody final.budget)
          ⟨input, .ok seed, some root, some discovery, some (.ok entries), embedded⟩

/-- 返す残りは元入力への参照である。未発見の別本体の個数は求めない。 -/
structure Report where
  definitionsRev : List DefinitionOutput := []
  remainingDefinitions : List Definition := []
  remainingModules : List Module := []
  stopped : Option Halt := none
  after : Budget.State := {}

def definitions (limits : Limits) (fuel : Nat) (inputs : List Definition) (report : Report) : Report :=
  match inputs with
  | [] => report
  | input :: rest =>
    match exhausted limits report.after with
    | some reason => { report with remainingDefinitions := inputs, stopped := some reason }
    | none => match bodySlot limits report.after with
      | .stopped reason last => { report with remainingDefinitions := inputs, stopped := some (.budget reason), after := finishBody last }
      | .ok _ ready =>
        let output := runDefinition limits ready fuel input
        let next := { report with definitionsRev := output :: report.definitionsRev, after := output.embedded.after }
        definitions limits fuel rest next

/-- モジュールを平坦化せず、ソース順の二つの列を逐次読む。
分類の消費は全体へ残し、先頭の定義に本体消費を引き継がない。 -/
def modules (limits : Limits) (fuel : Nat) (inputs : List Module) (report : Report) : Report :=
  match inputs with
  | [] => report
  | input :: rest =>
    match exhausted limits report.after with
    | some reason => { report with remainingModules := inputs, stopped := some reason }
    | none =>
      match (BudgetScan.region fun _ => BudgetScan.frame fun _ =>
          BudgetScan.tick .classification).run limits report.after with
      | .stopped reason last => { report with remainingModules := inputs, stopped := some (.budget reason), after := finishBody last }
      | .ok _ ready =>
        let next := definitions limits fuel input.definitions { report with after := finishBody ready }
        match next.stopped with
        | some _ => { next with remainingModules := rest }
        | none => modules limits fuel rest next

/-- fuelは交換入力で明示する。0も受け付け、深さ停止を予算停止へ変換しない。 -/
def analyze (limits : Limits) (state : Budget.State) (fuel : Nat) (inputs : List Module) : Report :=
  modules limits fuel inputs { after := state }

/-- 比較の停止分類。番号未取得は、その原因の本体/全体と資源も保持する。 -/
inductive StopClass where
  | depth | bodyBudget | wholeBudget | unidentified
  deriving DecidableEq, Repr

def classify : Halt → StopClass
  | .depth => .depth
  | .budget (.unidentified _) => .unidentified
  | .budget (.exceeded ⟨.body, _⟩) => .bodyBudget
  | .budget (.exceeded ⟨.whole, _⟩) => .wholeBudget

/-- 深さ停止をRustとの一致の受け入れに使わない。他の停止は比較対象である。 -/
def comparable : Halt → Bool
  | .depth => false
  | .budget _ => true

theorem depth_not_comparable : comparable .depth = false := rfl

/-- 報告の射影。解析から呼ばず、保存済みの結果だけを集計する。 -/
def bodyOutputs (r : Report) : List BodyOutput := r.definitionsRev.reverse.flatMap fun d =>
  d.root.toList ++ d.embedded.bodiesRev.reverse

def bodyStops (r : Report) : List Halt := (bodyOutputs r).filterMap fun b =>
  match b.output.coverage with | .stopped reason => some reason | _ => none

/-- 本体の停止件数と、発見・入口・待ち行列・制御の停止件数を混ぜない。 -/
def phaseStops (r : Report) : List Halt :=
  r.stopped.toList ++ r.definitionsRev.flatMap fun d =>
    (match d.prepared with | .error reason => [reason] | .ok _ => []) ++
    (match d.discovery with
      | some report => match report.result with | .error reason => [reason] | .ok _ => []
      | none => []) ++
    (match d.queue with | some (.error reason) => [reason] | _ => []) ++
    d.embedded.stopped.toList

def stopCount (kind : StopClass) (stops : List Halt) : Nat :=
  (stops.filter fun reason => decide (classify reason = kind)).length

/-- 本体ごとの比較可否。他の本体や発見の深さ停止でこの本体を除外しない。 -/
def comparisonEligible (body : BodyOutput) : Bool :=
  match body.output.coverage with | .stopped .depth => false | _ => true

/-- 深さで除外した本体は、件数と定義名を比較報告に残す。 -/
def excludedBodies (r : Report) : List BodyOutput :=
  (bodyOutputs r).filter fun body => !comparisonEligible body

/-- 全体のexceededと番号未取得を混ぜない。元の原因は別の内訳で読める。 -/
def wholeExceeded : Halt → Bool
  | .budget (.exceeded ⟨.whole, _⟩) => true
  | _ => false

def wholeCause : Halt → Bool
  | .budget (.exceeded ⟨.whole, _⟩) | .budget (.unidentified ⟨.whole, _⟩) => true
  | _ => false

def BodyOutput.stopped (body : BodyOutput) : Option Halt :=
  match body.output.coverage with | .stopped reason => some reason | _ => none

/-- 本体の親と独立入力の未対応を合わせ、一つの出力を高々一件とする。 -/
def unsupportedBodies (r : Report) : Nat :=
  ((bodyOutputs r).filter fun body => body.output.context.unsupported ||
    body.output.context.independentRev.any BudgetAnalysis.IndependentResult.unsupported).length

def bodyBudgetExceeded (r : Report) : Nat :=
  ((bodyOutputs r).filter fun body => match body.stopped with
    | some (.budget (.exceeded ⟨.body, _⟩)) => true | _ => false).length

def unidentifiedBodies (r : Report) : Nat :=
  ((bodyOutputs r).filter fun body => match body.stopped with
    | some (.budget (.unidentified _)) => true | _ => false).length

/-- 同じ元定義の入口・発見・待ち行列の全体停止を一度にまとめる。
親が既に全体原因で停止した場合と、発見済みの未解析本体は別に数える。 -/
def DefinitionOutput.incompleteWhole (d : DefinitionOutput) : Nat :=
  let phases :=
    (match d.prepared with | .error reason => [reason] | _ => []) ++
    (match d.discovery with | some r => (match r.result with | .error reason => [reason] | _ => []) | none => []) ++
    (match d.queue with | some (.error reason) => [reason] | _ => []) ++
    d.embedded.stopped.toList
  if d.embedded.pending.isEmpty &&
      !(d.root.any fun body => body.stopped.any wholeCause) && phases.any wholeExceeded
    then 1 else 0

/-- 既知の未解析本体と、不完全な元定義の範囲を数える。未発見本体を推測しない。
phaseStopsは停止事象列なので、この射影の代わりにその長さを使わない。 -/
def wholeBudgetSkipped (r : Report) : Nat :=
  ((bodyOutputs r).filter fun body => body.stopped.any wholeExceeded).length +
  (r.definitionsRev.map fun d => d.incompleteWhole +
    if d.embedded.stopped.any wholeCause then d.embedded.pending.length else 0).foldl (· + ·) 0 +
  (if r.stopped.any wholeCause then r.remainingDefinitions.length +
    (r.remainingModules.map fun m => m.definitions.length).foldl (· + ·) 0 else 0)

/-- 型検査成功の元定義数。別本体は足さず、解析未着手の元入力も含める。 -/
def inputDefinitionCount (r : Report) : Nat :=
  r.definitionsRev.length + r.remainingDefinitions.length +
    (r.remainingModules.map fun m => m.definitions.length).foldl (· + ·) 0

end Benitoite.Interval.BudgetWhole
