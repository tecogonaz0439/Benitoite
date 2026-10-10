import Benitoite.Surface.CheckTables

/-! E2c の sidecar を読み、元の corpus を変えずに検査の材料を作る。 -/
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

/-- 表示用の末尾の括弧にある BindingId だけを鍵に使う。 -/
def functionKey (display : String) : Except String String := do
  let some piece := (display.splitOn " (fn:").getLast?
    | throw s!"invalid function display name: {display}"
  let id := (piece.splitOn ")").headD ""
  let some n := id.toNat? | throw s!"invalid function binding: {display}"
  if display.endsWith s!" (fn:{n})" then return s!"fn:{n}"
  else throw s!"invalid function suffix: {display}"

def FunEntry.convert (f : FunEntry) : Except String Benitoite.Surface.FunDecl := do
  return {
    tparams := f.header.tparams.map (fun (e,k) => ⟨e,k⟩)
    neffs := f.header.neffs, params := ← f.header.params.mapM Ty.toRelease
    ret := ← f.header.ret.toRelease
    eff := f.header.eff.toRelease, dictParams := f.dictParams }

def ImplEntry.convert (i : ImplEntry) : Except String Benitoite.Surface.ImplSig := do
  return {
    tparams := i.tparams.map (fun (e,k) => ⟨e,k⟩), dictParams := i.dictParams
    cls := i.cls
    target := ← i.target.toRelease }

def ClassEntry.convert (c : ClassEntry) : Except String ClassMaterial := do
  let methods ← c.methods.mapM fun m => do
    let sg : Benitoite.Release.MethSig := {
      tparams := m.header.tparams.map (fun (e,k) => ⟨e,k⟩), neffs := m.header.neffs
      params := ← m.header.params.mapM Ty.toRelease
      ret := ← m.header.ret.toRelease, eff := m.header.eff.toRelease }
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

/-- rho の明示使用だけでなく、宣言された未使用の引数も含める。 -/
partial def maxEffArgs : Json → Nat
  | .arr xs => xs.foldl (fun n j => max n (maxEffArgs j)) 0
  | j@(.obj xs) =>
    let own := ((j.getObjVal? "neffs").bind (fromJson? · : Json → Except String Nat)).toOption.getD 0
    xs.toArray.foldl (fun n (_,v) => max n (maxEffArgs v)) own
  | _ => 0

def atomsFor (input : Input) (b : BuiltinInput) (s : StdlibInput)
    (operators : List OperatorEntry) : Eff :=
  let json := toJson [toJson input, toJson b, toJson s, toJson operators]
  ((collectAtoms json) ++ [Atom.name "State"] ++
    ((input.effects ++ b.effects).map fun e => Atom.name e.name) ++
    (input.ops.map fun o => Atom.name o.eff) ++
    ((List.range (maxEffArgs json)).map Atom.rho)).eraseDups

def uniqueKeys (xs : List (String × α)) : Bool :=
  let names := xs.map Prod.fst
  names.eraseDups.length == names.length

/-- 変換は入口で一度だけ行う。証明が使う Materials の構築は全域である。 -/
def prepare (input : Input) (b : BuiltinInput) (s : StdlibInput)
    (operators : List OperatorEntry) : Except String Prepared := do
  if input.group != b.group || input.name != b.name || input.group != s.group || input.name != s.name then
    throw "sidecar input identity mismatch"
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
      return (k < cd.args.length) && recordOk (atoms.map Atom.toRelease) data con cd
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
    let methods ← (bodies.filterMap fun d => d.method.map (fun name => (name,d.body))).mapM
      fun (name,body) => do return (name, ← body.toSurface cache)
    let supers ← (bodies.flatMap (·.supers)).mapM fun (name,d) => do return (name, ← d.toSurface)
    return (i.name, ({ signature := ← ImplEntry.convert i, methods := methods, supers := supers } : ImplMaterial))
  let trustedFuns ← s.functions.mapM fun f => do return (f.name, ← f.convert)
  let m : Materials := {
    defs, accessors, data, ops, effects := input.effects.map fun e => (e.name,e.ops)
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
  let entries := primEntries S raw
  let B := builtins S entries b
  let q := m.input B (Benitoite.Release.satB S) (admitsDec S entries)
    (makeOpPrim atoms operators) (atoms.map Atom.toRelease)
  return ⟨m, q, constructorsOk m, recordChecks.all id,
    implNamesOk m m.names.methods m.names.supers, outside⟩
end Benitoite.Exchange.CheckInput
