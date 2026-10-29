import Benitoite.Surface.CheckTables
import Benitoite.Exchange.Builtins
import Benitoite.Exchange.Observe

/-! 契約名とソース順を保持する独立した交換の入口。
設計書 07-04「証明する性質」の検査対象と既存形式を区別する。 -/
namespace Benitoite.Exchange.CheckInput
open Lean Benitoite.Surface.CheckTables

structure FunEntry where
  name : String
  header : Header
  dictParams : List (String × Nat)
  deriving ToJson, FromJson

structure TrustedImpl where
  signature : ImplEntry
  methods : List String
  supers : List String
  deriving ToJson, FromJson

structure StdlibInput where
  group : String
  name : String
  functions : List FunEntry
  impls : List TrustedImpl
  deriving ToJson, FromJson

structure StdlibCorpus where
  version : Nat
  inputs : List StdlibInput
  deriving ToJson, FromJson

def FunEntry.convert (f : FunEntry) : Except String Benitoite.Surface.FunDecl := do
  f.header.validateNoFail
  checkNames f.header.names f.header.params.length
  return {
    tparams := f.header.tparams.map (fun (e,k) => ⟨e,k⟩)
    neffs := f.header.neffs, names := f.header.names, params := ← f.header.params.mapM Ty.toRelease
    ret := ← f.header.ret.toRelease
    eff := ← f.header.eff.toRelease, dictParams := f.dictParams }

def ImplEntry.convert (i : ImplEntry) : Except String Benitoite.Surface.ImplSig := do
  return {
    tparams := i.tparams.map (fun (e,k) => ⟨e,k⟩), dictParams := i.dictParams
    cls := i.cls
    target := ← i.target.toRelease }

def ClassEntry.convert (c : ClassEntry) : Except String ClassMaterial := do
  let methods ← c.methods.mapM fun m => do
    m.header.validateNoFail
    checkNames m.header.names m.header.params.length
    let sg : Benitoite.Release.MethSig := {
      tparams := m.header.tparams.map (fun (e,k) => ⟨e,k⟩), neffs := m.header.neffs
      names := m.header.names
      params := ← m.header.params.mapM Ty.toRelease
      ret := ← m.header.ret.toRelease, eff := ← m.header.eff.toRelease }
    return (m.name, sg)
  return ⟨c.supers, methods⟩

structure Prepared where
  materials : Materials
  input : Benitoite.Surface.Check.Input
  constructors : Bool
  records : Bool
  implNames : Bool
  /-- JSON に本体がない定義を成功扱いせず、準備の失敗として返す。 -/
  outside : List (String × List String)
  /-- 交換の原子の一覧（`atomsFor`）。検査器の原子の集合はこの一覧の像である。 -/
  atoms : Eff
  atoms_eq : input.atoms = atoms.filterMap Atom.toRelease
  /-- 必須の判定の受理の入力（L50.2）。新版は入力の `scopeAcceptance` から作り、旧版は規則のない受理の入力
  （旧の像）である（`ScopeAcceptanceEntry.acceptInput`）。 -/
  accept : Benitoite.Surface.CheckAccept.AcceptInput

/-- rho の明示使用だけでなく、宣言された未使用の引数も含める。 -/
partial def maxEffArgs : Json → Nat
  | .arr xs => xs.foldl (fun n j => max n (maxEffArgs j)) 0
  | j@(.obj xs) =>
    let own := ((j.getObjVal? "neffs").bind (fromJson? · : Json → Except String Nat)).toOption.getD 0
    xs.toArray.foldl (fun n (_,v) => max n (maxEffArgs v)) own
  | _ => 0

/-- 交換の原子の一覧。入力・組み込みの表（署名の範囲の変数の原子を含む）・標準ライブラリの宣言に現れる原子と、
組み込みの呼び出しの範囲の列で署名の原子を具体化した原子（`instAtoms`）を含める。検査器は具体化の像の原子が
この集合にあることを求め（`instClosed`）、書き出しはこの集合を候補にする（`Prepared.writeEffNames`）。 -/
def atomsFor (input : Input) (b : BuiltinInput) (s : StdlibInput)
    (operators : List OperatorEntry) : Eff :=
  let json := toJson [toJson input, toJson b, toJson s, toJson operators]
  let instantiated := (collectPrimRanges (toJson input)).flatMap fun (n, rs) =>
    match b.prims.find? (·.name == n) with
    | some p => instAtoms (collectAtoms (toJson p)) rs
    | none => []
  ((collectAtoms json) ++ [Atom.name "State" .top] ++
    ((input.effects ++ b.effects).map fun e => Atom.name e.name .top) ++
    (input.ops.map fun o => Atom.name o.eff .top) ++ instantiated ++
    ((List.range (maxEffArgs json)).map Atom.rho)).eraseDups

def uniqueKeys (xs : List (String × α)) : Bool :=
  let names := xs.map Prod.fst
  names.eraseDups.length == names.length

/-- 書式化の頭は入力と同じ組み込み宣言表に存在しなければならない。 -/
partial def validateFormatHeads (b : BuiltinInput) : Json → Except String Unit
  | .arr xs => xs.toList.forM (validateFormatHeads b)
  | j@(.obj xs) => do
      if let .ok head := j.getObjVal? "primName" then
        let name ← head.getObjValAs? String "name"
        if name.startsWith "%Format." && !b.prims.any (·.name == name) then
          throw s!"missing format builtin: {name}"
      xs.toArray.toList.forM (fun (_, v) => validateFormatHeads b v)
  | _ => pure ()

/-- 変換は入口で一度だけ行う。証明が使う Materials の構築は全域である。 -/
def prepare (input : Input) (b : BuiltinInput) (s : StdlibInput)
    (operators : List OperatorEntry) : Except String Prepared := do
  if input.group != b.group || input.name != b.name || input.group != s.group || input.name != s.name then
    throw "sidecar input identity mismatch"
  if !input.dataTypes.isEmpty && input.dataTypes != b.dataDecls.map DataEntry.info then
    throw "corpus/builtin data type metadata mismatch"
  -- 新版の空表を旧版と混同しない検査は JSON の入口で行う。
  let operations ← input.operationProgram
  -- 型付けへ変換すると使わなくなる交換専用の注釈も、境界で検査する。
  validateClauses operations input.primOps (toJson input)
  validateFormatHeads b (toJson input)
  let atoms := atomsFor input b s operators
  let cache ← input.constantCache
  let ordinary := input.definitions.filterMap fun d => match d.scope with
    | .inScope surface _ => if surface.implementation.isNone then some (d.name, surface) else none
    | _ => none
  let defs ← ordinary.mapM fun (name,d) => do
    return (← functionKey name, ← d.toSurface cache)
  let accessors := input.definitions.filterMap fun d => match d.scope with
    | .accessor name con k _ _ => some (name, (con,k))
    | _ => none
  let outside := input.definitions.filterMap fun d => match d.scope with
    | .outOfScope reasons => some (d.name, reasons)
    | _ => none
  let data ← b.dataDecls.mapM DataEntry.toMaterial
  let recordChecks ← (input.definitions.filterMap fun d => match d.scope with
    | .accessor name con k decl _ => some (d.name,name,con,k,decl)
    | _ => none).mapM fun (display,name,con,k,decl) => do
      if (← functionKey display) != name then throw "accessor binding name mismatch"
      let cd : Benitoite.Release.ConDecl := {
        data := decl.data, ntys := decl.ntys, args := ← decl.args.mapM Ty.toRelease }
      checkNames decl.fields decl.args.length
      let actualFields := b.dataDecls.flatMap (fun d => d.ctors) |>.find? (fun c => c.name == con)
      if actualFields.bind (·.fields) != some decl.fields then throw "record fields mismatch"
      return (k < cd.args.length) && recordOk (atoms.filterMap Atom.toRelease) data con cd
  let ops ← input.ops.mapM fun o => do return (o.name, ← o.toRelease)
  let classes ← input.classes.mapM fun c => do return (c.name, ← ClassEntry.convert c)
  -- sidecar の実装は元の表のシグネチャと一致しなければならない。
  let trustedImpls ← s.impls.mapM fun i => do
    let some original := input.impls.find? (fun x => x.name == i.signature.name)
      | throw s!"trusted implementation absent from corpus: {i.signature.name}"
    if toJson original != toJson i.signature then throw "trusted implementation signature mismatch"
    let some cl := input.classes.find? (fun c => c.name == i.signature.cls)
      | throw "trusted implementation class missing"
    if i.methods != cl.methods.map (·.name) || i.supers != cl.supers then
      throw "trusted implementation member set mismatch"
    return (i.signature.name, ← ImplEntry.convert i.signature)
  let userImpls := input.impls.filter fun i => !s.impls.any (fun x => x.signature.name == i.name)
  let impls ← userImpls.mapM fun i => do
    let bodies := input.definitions.filterMap fun d => match d.scope with
      | .inScope surface _ => if surface.implementation == some i.name then some surface else none
      | _ => none
    -- メソッド宣言は辞書込みの契約を持つ。実装自身の辞書数から内部名を作り、
    -- 利用者の実名を宣言から転記せずに比較する（設計書 01-12「型クラス」）。
    let methods ← (bodies.filterMap fun d => d.method.map (fun name =>
      (name, Benitoite.Surface.internalNames d.dictParams.length ++ d.header.names, d.body))).mapM
      fun (name,names,body) => do return (name, ({ names, body := ← body.toSurface cache } : Benitoite.Surface.Check.MethodInput))
    let supers ← (bodies.flatMap (·.supers)).mapM fun (name,d) => do return (name, ← d.toSurface)
    return (i.name, ({ signature := ← ImplEntry.convert i, methods := methods, supers := supers } : ImplMaterial))
  let trustedFuns ← s.functions.mapM fun f => do return (f.name, ← f.convert)
  let views ← (input.definitions.filterMap fun d => match d.scope with
    | .inScope s _ => if s.implementation.isNone || s.method.isSome then some (d.name,s) else none
    | _ => none).mapM fun (name,s) => do
      let view ← coverageView input.dataTypes s.package s.coverageView
      return (← functionKey name, s.implementation, s.method, view)
  let functionKeys := views.filterMap fun (key,i,_,_) => if i.isNone then some key else none
  let methodKeys := views.filterMap fun (_,i,m,_) => do return (← i, ← m)
  if functionKeys.eraseDups.length != functionKeys.length ||
      methodKeys.eraseDups.length != methodKeys.length then throw "duplicate body coverage view"
  let m : Materials := {
    functionViews := fun n => ((views.find? fun (key,i,_,_) => key == n && i.isNone).map
      fun (_,_,_,v) => v).getD Benitoite.Release.closedView
    methodViews := fun i n => ((views.find? fun (_,impl,m,_) => impl == some i && m == some n).map
      fun (_,_,_,v) => v).getD Benitoite.Release.closedView
    defs, conFields := b.dataDecls.flatMap (fun d => d.ctors.filterMap (fun c => c.fields.map (fun fs => (c.name,fs)))), accessors, data, ops, effects := input.effects.map fun e => (e.name,e.ops)
    classes, impls, trustedFuns, trustedImpls }
  if !uniqueKeys m.defs || !uniqueKeys m.accessors || !uniqueKeys m.ops ||
      !uniqueKeys m.effects || !uniqueKeys m.classes || !uniqueKeys m.impls ||
      !uniqueKeys m.trustedFuns || !uniqueKeys m.trustedImpls ||
      m.impls.any (fun (_,i) => !uniqueKeys i.methods || !uniqueKeys i.supers) ||
      m.classes.any (fun (_,c) => !uniqueKeys c.methods) then
    throw "duplicate declaration name"
  let raw ← (b.prims.filter fun p => p.unconvertibleTypes.isEmpty && p.classConstraints.isEmpty).mapM
    fun p => do return (p.name, ← p.toMaterial)
  if !uniqueKeys raw then throw "duplicate primitive name"
  let S ← b.summaryTable
  -- 範囲の変数の種類と IO の形を表の項目から署名へ入れる。
  let entries := (primEntries S raw).map fun e => match b.prims.find? (·.name == e.name) with
    | some p => { e with signature := p.withRanges e.signature }
    | none => e
  let B := b.withTableData (builtins S entries b.toBuiltinMaterial)
  let q := { m.input B (Benitoite.Release.satB S) (admitsDec S entries)
    (makeOpPrim atoms operators) (atoms.filterMap Atom.toRelease) with
    admitsRDec := AdmitsEntry.admitsRDec b.admitsR }
  -- 必須の判定の受理の入力。旧版の入力は null（規則のない受理の入力）。
  let scope : Option ScopeAcceptanceEntry ←
    if input.scopeAcceptance == Json.null then pure none else some <$> fromJson? input.scopeAcceptance
  -- 実装のメソッドの本体の鍵は、その本体の定義の名前（関数の鍵と同じ変換）とする。
  let methodNames ← (input.definitions.filterMap fun d => match d.scope with
    | .inScope s _ => do return (← s.implementation, ← s.method, d.name)
    | _ => none).mapM fun (i, mn, n) => do return (i, mn, ← functionKey n)
  let base := ScopeAcceptanceEntry.acceptInput scope
  let accept := { base with methodKey := fun i mn =>
    ((methodNames.find? fun (a, b, _) => a == i && b == mn).map (·.2.2)).getD (base.methodKey i mn) }
  return ⟨m, q, constructorsOk m, recordChecks.all id,
    implNamesOk m m.names.methods m.names.supers, outside, atoms, rfl, accept⟩

/-- 準備した入力の効果の書き出し（名前と行の原子）。書き出しの一覧は交換の原子の一覧、候補は検査器の原子の
集合 `q.atoms` である（RV-L40 軽6）。 -/
def Prepared.writeEffNames (p : Prepared) (e : Benitoite.Release.Eff) : Except String Eff :=
  fromEffNames p.atoms e p.input.atoms

/-- 検査器の不変条件 `AtomsIn q.atoms` を満たす効果は、この経路で必ず書き出せ、書き出した原子の列を読むと元の
効果の所属に戻る（黙った欠落がない）。 -/
theorem Prepared.writeEffNames_complete (p : Prepared) {e : Benitoite.Release.Eff}
    (he : Benitoite.Release.Eff.AtomsIn p.input.atoms e) :
    p.writeEffNames e = .ok (writeAtoms p.atoms e.test) ∧
      Eff.readAtoms (writeAtoms p.atoms e.test) = e.test := by
  have h : ∀ a, Benitoite.Release.Eff.test e a = true → a ∈ p.atoms.filterMap Atom.toRelease :=
    fun a ha => p.atoms_eq ▸ support_of_atomsIn he a ha
  exact ⟨fromEffNames_ok _ h, readAtoms_writeAtoms _ _ h⟩
end Benitoite.Exchange.CheckInput
