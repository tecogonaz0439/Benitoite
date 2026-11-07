import Benitoite.Exchange.BuiltinAgreement
import Benitoite.Exchange.CanonicalNames
import Benitoite.Exchange.Observe
import Std.Data.HashSet

/-! 交換の入力から、表層の検査器の宣言材料・検査の入力・必須の判定の受理の入力を作る。
変換は入口で一度だけ行い、検査器と受理は同じ材料から作った表を読む（設計書 07-04「証明する性質」）。 -/
namespace Benitoite.Exchange.CheckInput
open Lean
open Benitoite.Release.Refinement.Surface.CheckTables (Materials ClassMaterial ImplMaterial MethodMaterial lookup)
open Benitoite.Exchange.CheckSupport

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

/-- 標準ライブラリの関数の宣言。本体を持たず、利用者の宣言の空欄を補う。引数・結果・効果は支持の証拠とともに
形成する。 -/
def FunEntry.convert (atoms : List Benitoite.Release.Refinement.Atom) (f : FunEntry) :
    Except String {d : Benitoite.Release.Refinement.Surface.FunDecl // SigSupport atoms d.params d.ret d.eff} := do
  f.header.validateNoFail
  checkNames f.header.names f.header.params.length
  let x ← formedHeader atoms f.header
  return ⟨{
    tparams := ← f.header.typeContext
    neffs := f.header.neffs, names := f.header.names, params := x.val.1, ret := x.val.2.1, eff := x.val.2.2
    dictParams := f.dictParams, rangeParams := f.header.rangeParams, proofSteps := f.header.proofSteps }, x.property⟩

/-- 実装の署名。対象の型は支持の証拠とともに形成する。 -/
def ImplEntry.convert (atoms : List Benitoite.Release.Refinement.Atom) (i : ImplEntry) :
    Except String {s : Benitoite.Release.Refinement.Surface.ImplSig // s.target.Support (· ∈ atoms)} := do
  let t ← FormationTypes.formedTy atoms i.target
  return ⟨{ tparams := i.tparams.map (fun (e,k) => ⟨e,k⟩), dictParams := i.dictParams, cls := i.cls, target := t.val },
    t.property⟩

/-- 型クラスの宣言の材料。メソッドの署名は宣言順に保ち、引数・結果・効果を支持の証拠とともに形成する。 -/
def ClassEntry.convert (atoms : List Benitoite.Release.Refinement.Atom) (c : ClassEntry) :
    Except String {cm : ClassMaterial // ∀ x ∈ cm.methods, SigSupport atoms x.2.params x.2.ret x.2.eff} := do
  let methods ← c.methods.mapM fun m => do
    m.header.validateNoFail
    checkNames m.header.names m.header.params.length
    if !m.header.rangeParams.isEmpty || m.header.proofSteps.isSome then
      throw "method cannot declare range parameters or proof step limit"
    let x ← formedHeader atoms m.header
    let sg : Benitoite.Release.Refinement.MethSig := {
      tparams := ← m.header.typeContext, neffs := m.header.neffs
      names := m.header.names
      params := x.val.1, ret := x.val.2.1, eff := x.val.2.2 }
    return (⟨(m.name, sg), x.property⟩ :
      {y : String × Benitoite.Release.Refinement.MethSig // SigSupport atoms y.2.params y.2.ret y.2.eff})
  return ⟨{ argumentKind := c.argumentKind, supers := c.supers, methods := methods.map Subtype.val },
    fun _ hx => mem_val (xs := methods) hx⟩

/-- 関数の証明の上限の指定がない本体の、論理の証明書の会計の上限。 -/
def defaultProofSteps : Nat := 4096

/-! ## 標準表との一致の判定の対象 -/

/-- 標準表との一致の判定の対象（閉包）。`prims` はプログラムが参照する組込みの名前、`data` はプログラムが使う型と
`prims` の署名の型から、data の宣言の構成子の引数の型を通じて届く data の名前である。どちらも組込みの表にある
名前だけを持つ。 -/
structure Closure where
  prims : List String
  data : List String

/-- JSON に値として現れる文字列。欄の名前は含めない。 -/
partial def jsonStrings : Json → List String
  | .str s => [s]
  | .arr xs => xs.toList.flatMap jsonStrings
  | .obj xs => xs.toArray.toList.flatMap fun (_, v) => jsonStrings v
  | _ => []

/-- 入力の JSON の、期待の核（欄 `core`）と data の属性の一覧（欄 `dataTypes`。全ての data を並べる）を除いた部分に
現れる文字列と欄の名前。検査器は期待の核を読まないので、参照は表層の部分だけで数える。 -/
partial def surfaceWords (acc : Array String × Array String) : Json → Array String × Array String
  | .str s => (acc.1.push s, acc.2)
  | .arr xs => xs.foldl surfaceWords acc
  | .obj xs => xs.toArray.foldl (fun acc (key, x) =>
      if key == "core" || key == "dataTypes" then acc else surfaceWords (acc.1, acc.2.push key) x) acc
  | _ => acc

/-- 名前の集合に、名前か構成子の名前が含まれる data の宣言の名前。 -/
def dataNamed (b : BuiltinInput) (names : Std.HashSet String) : List String :=
  (b.dataDecls.filter fun d => names.contains d.name || d.ctors.any fun c => names.contains c.name).map (·.name)

/-- data の名前の列に、その宣言の構成子の引数の型から届く data を一段加える。 -/
def dataStep (b : BuiltinInput) (names : List String) : List String :=
  let reached := (b.dataDecls.filter fun d => names.contains d.name).flatMap fun d => jsonStrings (toJson d.ctors)
  (names ++ dataNamed b (Std.HashSet.ofList reached)).eraseDups

/-- 閉包を作る。参照は、入力の JSON の期待の核を除いた部分に値として現れる文字列で数える（組込み・data・構成子の
名前と一致する文字列）。実装の宣言は、利用者の実装を全て、標準ライブラリの信頼する実装を名前が入力に現れるときに数える。演算子の表の行は、その演算子の名前が同じ部分に値か欄の名前として現れるとき、その行の組込みを
参照する（単項の負号は欄の名前 `neg` だけに現れる）。標準ライブラリの関数は、名前が入力に現れるとき、その宣言の型を
プログラムが使う型に含める。data の段は data の宣言の数より一つ多く繰り返す（一段ごとに宣言を一つ以上加えるか、
変わらなくなる）。 -/
def closureOf (input : Input) (b : BuiltinInput) (s : StdlibInput) (operators : List OperatorEntry) : Closure :=
  -- 実装の表（`impls`）は標準ライブラリの全ての実装を並べるので、標準ライブラリの信頼する実装は名前が入力に現れる
  -- ものだけを数える。利用者の実装は、メソッドの本体がなく名前が現れなくても検査器が対象の型を読むので、全て数える。
  let (values0, keys) := surfaceWords (#[], #[]) (toJson { input with impls := [] })
  let named := Std.HashSet.ofArray values0
  let trusted := Std.HashSet.ofList (s.impls.map (·.signature.name))
  let values := values0 ++ (jsonStrings (toJson (input.impls.filter fun i =>
    !trusted.contains i.name || named.contains i.name))).toArray
  let used := Std.HashSet.ofArray values
  let words := Std.HashSet.ofArray (values ++ keys)
  let funs := s.functions.filter fun f => used.contains f.name
  let opPrims := Std.HashSet.ofList ((operators.filter fun o => words.contains o.op).map (·.name))
  let prims := b.prims.filter fun p => used.contains p.name || opPrims.contains p.name
  let typed := Std.HashSet.ofList (values.toList ++ jsonStrings (toJson (funs.map (·.header))) ++
    jsonStrings (toJson prims))
  let data := (List.range (b.dataDecls.length + 1)).foldl (fun names _ => dataStep b names)
    (dataNamed b typed).eraseDups
  { prims := (prims.map (·.name)).eraseDups, data }

structure Prepared where
  materials : Materials
  input : Benitoite.Release.Refinement.Surface.Check.Input
  /-- data の名前が一意で、各構成子の所属がその data である。 -/
  constructors : Bool
  /-- 取得関数の record の宣言が、構成子の表の宣言と一致する。 -/
  records : Bool
  /-- 型クラスと実装のメソッド・上位の名前が、検査の名前の一覧に含まれる。 -/
  implNames : Bool
  /-- JSON に本体がない定義を成功扱いせず、準備の失敗として返す。 -/
  outside : List (String × List String)
  /-- 交換の原子の一覧（`atomsFor`）。検査器の原子の集合はこの一覧の像である。 -/
  atoms : Eff
  atoms_eq : input.formation.atoms = atoms.filterMap Atom.toRelease
  /-- 必須の判定の受理の入力。入力の `scopeAcceptance` から作る（`ScopeAcceptanceEntry.acceptInput`）。 -/
  accept : Benitoite.Release.Refinement.Surface.CheckAccept.AcceptInput
  /-- 検査器の組み込みの表の項目の名前（交換の名前のまま）。 -/
  builtinNames : List String
  /-- 標準表との照合に使った表の項目の名前（交換の内部名を標準の名前へ写した名前）。 -/
  canonicalNames : List String
  /-- 標準表との照合に使った表の署名（型パラメータの鍵の印を `BuiltinAgreement.normKeys` でそろえた）。
  検査器の表ではない。 -/
  canonicalSig : String → Option Benitoite.Release.Refinement.PrimSig
  /-- 鍵の印をそろえる前の、名前を写した表の署名。 -/
  canonicalRawSig : String → Option Benitoite.Release.Refinement.PrimSig
  /-- 名前を写した表の構成子の表。標準の data の宣言との照合に使う。 -/
  canonicalCons : List (String × Benitoite.Release.Refinement.ConDecl)
  /-- 標準表との照合に使った原子の一覧（写した入力の原子の一覧と標準の署名の原子の一覧の和）。 -/
  canonicalAtoms : List Benitoite.Release.Refinement.Atom
  /-- 標準表との一致の判定の対象（`closureOf`）。 -/
  closure : Closure
  /-- 閉包の data のうち、標準ライブラリの data（標準ライブラリの宣言か、Result・Option）の名前。標準の宣言と
  照らすのはこの data だけである（利用者の data の名前が標準の宣言の名前と同じでも照らさない）。 -/
  standardData : List String
  /-- 閉包の組込みの名前のうち、標準表の合成済みの名前でも名前の写しの仮定側の名前でもないもの。署名は照らさず、
  報告に残す。 -/
  unknownBuiltins : List String

/-- rho の明示使用だけでなく、宣言された未使用の引数も含める。 -/
partial def maxEffArgs : Json → Nat
  | .arr xs => xs.foldl (fun n j => max n (maxEffArgs j)) 0
  | j@(.obj xs) =>
    let own := ((j.getObjVal? "neffs").bind (fromJson? · : Json → Except String Nat)).toOption.getD 0
    xs.toArray.foldl (fun n (_,v) => max n (maxEffArgs v)) own
  | _ => 0

/-- 交換の原子の一覧。入力・組み込みの表（署名の範囲の変数の原子を含む）・標準ライブラリの宣言に現れる原子と、
組み込みの呼び出しの範囲の列で署名の原子を具体化した原子（`instAtoms`）を含める。 -/
def atomsFor (input : Input) (b : BuiltinInput) (s : StdlibInput)
    (operators : List OperatorEntry) : Eff :=
  let json := toJson [toJson input, toJson b, toJson s, toJson operators]
  let instantiated := (collectPrimRanges (toJson input)).flatMap fun (n, rs) =>
    match b.prims.find? (·.name == n) with
    | some p => instAtoms (collectAtoms (toJson p)) rs
    | none => []
  ((collectAtoms json) ++ [Atom.name "State" Benitoite.Release.Refinement.RangeIx.top] ++
    ((input.effects ++ b.effects).map fun e => Atom.name e.name Benitoite.Release.Refinement.RangeIx.top) ++
    (input.ops.map fun o => Atom.name o.eff Benitoite.Release.Refinement.RangeIx.top) ++ instantiated ++
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

/-- data の名前が一意で、各構成子の所属が宣言された data である。 -/
def constructorsOk (b : BuiltinInput) (m : Materials) : Bool :=
  let names := b.dataDecls.map (·.name)
  (names.eraseDups.length == names.length) && m.cons.all (fun (_, cd) => names.contains cd.data)

/-- 交換の record の宣言を構成子の表と照合する。表を上書きしない。 -/
def recordOk (atoms : List Benitoite.Release.Refinement.Atom) (m : Materials) (name : String)
    (cd : Benitoite.Release.Refinement.ConDecl) : Bool :=
  match lookup m.cons name with
  | none => false
  | some actual => (actual.data == cd.data) && (actual.ntys == cd.ntys) &&
      Benitoite.Release.Refinement.Surface.CheckArguments.tysEq atoms actual.args cd.args

/-- 型クラスと実装の名前が、検査の名前の一覧に含まれる。 -/
def implNamesOk (m : Materials) (methods supers : List String) : Bool :=
  (m.classes.flatMap fun (_,c) => c.methods.map Prod.fst).all methods.contains &&
  (m.impls.flatMap fun (_,i) => i.methods.map Prod.fst).all methods.contains &&
  (m.impls.flatMap fun (_,i) => i.supers.map Prod.fst).all supers.contains

/-- 交換の論理の証明書の表を、検査器が位置と番号で引く関数にする（鍵は交換の契約で一意である）。 -/
def certificateTable (entries : List LogicCertificateEntry) :
    List Nat → Nat → Option Benitoite.Release.Refinement.Surface.CheckSubtyping.ExchangeCertificate :=
  fun path index => (entries.find? fun e => e.path == path && e.index == index).map
    fun e => ⟨e.certificate, e.actions⟩

/-- 準備の成果と、検査器の入力の健全性の材料。宣言材料の全署名と組み込みの署名の支持、判定と表の対応を持つ。 -/
structure Parts where
  materials : Materials
  base : Benitoite.Release.Refinement.Surface.Check.Input
  /-- 検査器の表は交換した組込みの表（独自の表）である。 -/
  table : Benitoite.Release.Refinement.Builtins
  custom : base.builtinSource = .custom table
  constructors : Bool
  records : Bool
  implNames : Bool
  outside : List (String × List String)
  atoms : Eff
  accept : Benitoite.Release.Refinement.Surface.CheckAccept.AcceptInput
  atoms_eq : base.formation.atoms = atoms.filterMap Atom.toRelease
  support : MaterialSupport base.formation.atoms materials
  prims : ∀ b s, base.B.sig b = some s → SigSupport base.formation.atoms s.params s.ret s.eff
  sat : Benitoite.Release.Refinement.Surface.CheckArguments.SatSound base.B base.satDec
  admits : Benitoite.Release.Refinement.Surface.CheckArguments.AdmitsSound base.B base.admitsDec
  ranges : Benitoite.Release.Refinement.Surface.CheckArguments.RangeAdmitsSound base.B base.admitsRDec
  operators : ∀ o t b ts, base.opPrim o t = some (b, ts) → t.Support (· ∈ base.formation.atoms) →
    Benitoite.Release.Refinement.Ty.SupportList (· ∈ base.formation.atoms) ts
  builtinNames : List String
  canonicalNames : List String
  canonicalSig : String → Option Benitoite.Release.Refinement.PrimSig
  canonicalRawSig : String → Option Benitoite.Release.Refinement.PrimSig
  canonical_eq : canonicalSig = fun n => (canonicalRawSig n).map BuiltinAgreement.normKeys
  canonicalCons : List (String × Benitoite.Release.Refinement.ConDecl)
  canonicalAtoms : List Benitoite.Release.Refinement.Atom
  closure : Closure
  standardData : List String
  /-- 名前を標準の名前へ写した表で、閉包の組込みの名前のうち標準表の合成済みの名前の署名の欄が、標準表の行と
  一致する。 -/
  agreement : BuiltinAgreement.Agrees (BuiltinAgreement.composedNames closure.prims) canonicalSig
    BuiltinAgreement.standardSig
  /-- 閉包の data のうち標準の宣言と同じ名前を持つものは、標準の宣言と一致する。 -/
  dataAgreement : BuiltinAgreement.DataListAgrees canonicalAtoms canonicalCons standardData
  unknownBuiltins : List String

/-- 検査器の入力は、同じ宣言材料から表と名前の一覧を作った入力である。 -/
def Parts.prepared (x : Parts) : Prepared :=
  ⟨x.materials, x.materials.input x.base, x.constructors, x.records, x.implNames, x.outside, x.atoms,
    x.atoms_eq, x.accept, x.builtinNames, x.canonicalNames, x.canonicalSig, x.canonicalRawSig, x.canonicalCons,
    x.canonicalAtoms, x.closure, x.standardData, x.unknownBuiltins⟩

/-- 準備の成果の検査器の入力は健全である（`Check.Input.Sound`）。 -/
theorem Parts.sound (x : Parts) : x.prepared.input.Sound :=
  Benitoite.Release.Refinement.Surface.CheckTables.Materials.input_sound x.materials x.base
    (Materials.fieldsSupport x.support) (Materials.headTableSupport x.support x.prims)
    x.sat x.admits x.ranges x.operators

/-- 変換は入口で一度だけ行う。検査器の表は交換した組み込みの表（`builtinsOf`）であり、型の制約・型パラメータの
制約・範囲の許容の判定は同じ材料から作る。表の署名は有限の原子の一覧に対する支持の証拠とともに形成し、一覧に
ない原子を持つ入力は断る。 -/
def prepareParts (input : Input) (b : BuiltinInput) (s : StdlibInput)
    (operators : List OperatorEntry) : Except String Parts := do
  if input.group != b.group || input.name != b.name || input.group != s.group || input.name != s.name then
    throw "sidecar input identity mismatch"
  if !input.dataTypes.isEmpty && input.dataTypes != b.dataDecls.map DataEntry.info then
    throw "corpus/builtin data type metadata mismatch"
  let operations ← input.operationProgram
  -- 型付けへ変換すると使わなくなる交換専用の注釈も、境界で検査する。
  validateClauses operations input.primOps (toJson input)
  validateFormatHeads b (toJson input)
  let atoms := atomsFor input b s operators
  let atomsR := atoms.filterMap Atom.toRelease
  let cache ← input.constantCache
  let ordinary := input.definitions.filterMap fun d => match d.scope with
    | .inScope surface _ => if surface.implementation.isNone then some (d.name, surface) else none
    | _ => none
  let defs ← ordinary.mapM fun (name,d) => do
    let key ← functionKey name
    let sd ← d.toSurface cache
    let x ← formedHeader atomsR d.header
    return (⟨(key, { sd with params := x.val.1, ret := x.val.2.1, eff := x.val.2.2 }), x.property⟩ :
      {y : String × Benitoite.Release.Refinement.Surface.Def // SigSupport atomsR y.2.params y.2.ret y.2.eff})
  let accessors := input.definitions.filterMap fun d => match d.scope with
    | .accessor name con k _ _ => some (name, (con,k))
    | _ => none
  let outside := input.definitions.filterMap fun d => match d.scope with
    | .outOfScope reasons => some (d.name, reasons)
    | _ => none
  let cons ← b.dataDecls.flatMapM (formedConstructors atomsR)
  let dataInfo ← b.dataDecls.mapM fun d => do return (d.name, ← d.varianceDecl)
  let ops ← input.ops.mapM fun o => do
    let decl ← o.toRelease
    let x ← formedHeader atomsR o.header
    if hmem : atomsR.contains (Benitoite.Release.Refinement.Atom.nameTop o.eff) = true then
      return (⟨(o.name, { decl with eff := o.eff, params := x.val.1, ret := x.val.2.1 }),
        ⟨x.property.1, x.property.2.1, empty_support atomsR⟩, List.contains_iff_mem.mp hmem⟩ :
        {y : String × Benitoite.Release.Refinement.OpDecl //
          SigSupport atomsR y.2.params y.2.ret Benitoite.Release.Refinement.Eff.empty ∧
          Benitoite.Release.Refinement.Atom.nameTop y.2.eff ∈ atomsR})
    else throw "operation effect atom is not in the formation atom list"
  let classes ← input.classes.mapM fun c => do
    let cm ← ClassEntry.convert atomsR c
    return (⟨(c.name, cm.val), cm.property⟩ :
      {y : String × ClassMaterial // ∀ x ∈ y.2.methods, SigSupport atomsR x.2.params x.2.ret x.2.eff})
  -- sidecar の実装は元の表のシグネチャと一致しなければならない。
  let trustedImpls ← s.impls.mapM fun i => do
    let some original := input.impls.find? (fun x => x.name == i.signature.name)
      | throw s!"trusted implementation absent from corpus: {i.signature.name}"
    if toJson original != toJson i.signature then throw "trusted implementation signature mismatch"
    let some cl := input.classes.find? (fun c => c.name == i.signature.cls)
      | throw "trusted implementation class missing"
    if i.methods != cl.methods.map (·.name) || i.supers != cl.supers then
      throw "trusted implementation member set mismatch"
    let sg ← ImplEntry.convert atomsR i.signature
    return (⟨(i.signature.name, sg.val), sg.property⟩ :
      {y : String × Benitoite.Release.Refinement.Surface.ImplSig // y.2.target.Support (· ∈ atomsR)})
  let userImpls := input.impls.filter fun i => !s.impls.any (fun x => x.signature.name == i.name)
  let impls ← userImpls.mapM fun i => do
    let bodies := input.definitions.filterMap fun d => match d.scope with
      | .inScope surface _ => if surface.implementation == some i.name then some surface else none
      | _ => none
    -- メソッド宣言は辞書込みの契約を持つ。実装自身の辞書数から内部名を作り、
    -- 利用者の実名を宣言から転記せずに比較する（設計書 01-12「型クラス」）。
    let methods ← (bodies.filterMap fun d => d.method.map (fun name =>
      (name, Benitoite.Release.Refinement.Surface.internalNames d.dictParams.length ++ d.header.names, d.body))).mapM
      fun (name,names,body) => do return (name, ({ names, body := ← body.toSurface cache } : MethodMaterial))
    let supers ← (bodies.flatMap (·.supers)).mapM fun (name,d) => do return (name, ← d.toSurface)
    let sg ← ImplEntry.convert atomsR i
    return (⟨(i.name, ({ signature := sg.val, methods, supers } : ImplMaterial)), sg.property⟩ :
      {y : String × ImplMaterial // y.2.signature.target.Support (· ∈ atomsR)})
  let trustedFuns ← s.functions.mapM fun f => do
    let d ← FunEntry.convert atomsR f
    return (⟨(f.name, d.val), d.property⟩ :
      {y : String × Benitoite.Release.Refinement.Surface.FunDecl // SigSupport atomsR y.2.params y.2.ret y.2.eff})
  let aliases ← input.aliases.mapM fun a => do return (a.name, ← a.toSurface)
  let records ← input.records.mapM fun r => do return (r.constructor, ← r.toSurface)
  let externals ← input.externals.mapM (formedExternal atomsR)
  let testers := input.testers.map fun t => (t.function, t.constructor)
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
    defs := defs.map Subtype.val, cons := cons.map Subtype.val
    conFields := b.dataDecls.flatMap (fun d => d.ctors.filterMap (fun c => c.fields.map (fun fs => (c.name,fs))))
    ops := ops.map Subtype.val, effects := input.effects.map fun e => (e.name,e.ops)
    classes := classes.map Subtype.val, impls := impls.map Subtype.val, accessors, aliases, records, testers
    externals := externals.map Subtype.val, dataInfo, trustedFuns := trustedFuns.map Subtype.val
    trustedImpls := trustedImpls.map Subtype.val }
  have support : MaterialSupport atomsR m := {
    defs := fun _ hx => mem_val (xs := defs) hx, cons := fun _ hx => mem_val (xs := cons) hx
    ops := fun _ hx => mem_val (xs := ops) hx, methods := fun _ hx => mem_val (xs := classes) hx
    impls := fun _ hx => mem_val (xs := impls) hx, trustedFuns := fun _ hx => mem_val (xs := trustedFuns) hx
    trustedImpls := fun _ hx => mem_val (xs := trustedImpls) hx
    externals := fun _ hx => mem_val (xs := externals) hx }
  if !uniqueKeys m.defs || !uniqueKeys m.cons || !uniqueKeys m.accessors || !uniqueKeys m.ops ||
      !uniqueKeys m.effects || !uniqueKeys m.classes || !uniqueKeys m.impls ||
      !uniqueKeys m.aliases || !uniqueKeys m.records || !uniqueKeys m.testers || !uniqueKeys m.dataInfo ||
      !uniqueKeys m.trustedFuns || !uniqueKeys m.trustedImpls ||
      m.impls.any (fun (_,i) => !uniqueKeys i.methods || !uniqueKeys i.supers) ||
      m.classes.any (fun (_,c) => !uniqueKeys c.methods) then
    throw "duplicate declaration name"
  let recordChecks ← (input.definitions.filterMap fun d => match d.scope with
    | .accessor name con k decl _ => some (d.name,name,con,k,decl)
    | _ => none).mapM fun (display,name,con,k,decl) => do
      if (← functionKey display) != name then throw "accessor binding name mismatch"
      let cd : Benitoite.Release.Refinement.ConDecl := {
        data := decl.data, ntys := decl.ntys, args := ← decl.args.mapM Ty.toRelease }
      checkNames decl.fields decl.args.length
      let actualFields := b.dataDecls.flatMap (fun d => d.ctors) |>.find? (fun c => c.name == con)
      if actualFields.bind (·.fields) != some decl.fields then throw "record fields mismatch"
      return (k < cd.args.length) && recordOk atomsR m con cd
  let S ← b.summaryTable
  let prims ← formedMaterials atomsR b
  let ms := prims.map Subtype.val
  let builtinNames := ms.map (·.1.name)
  -- 標準表との照合は、交換の内部名（data・構成子・不透明型・効果・組み込み）を同じ入力の宣言から決まる標準の
  -- 名前へ写した表で行う。検査器の表は写さない交換の表のままである。写した後も署名の欄が標準表の行と一致しない
  -- 入力は断る（設計書 07-04「証明する性質」）。
  let names ← CanonicalNames.ofInputs input (toJson b)
  let bc : BuiltinInput ← fromJson? (names.json (toJson b))
  let inputC : Input ← fromJson? (names.json (toJson input))
  let atomsC := (atomsFor inputC bc s operators).filterMap Atom.toRelease
  let SC ← bc.summaryTable
  let primsC ← formedMaterials atomsC bc
  let msC := primsC.map Subtype.val
  let canonicalNames := msC.map (·.1.name)
  -- 型パラメータの制約は鍵の印をそろえて比べる（`BuiltinAgreement.admits_normKey`）。
  let canonicalRawSig := (builtinsOf bc SC msC).sig
  let canonicalSig := fun n => (canonicalRawSig n).map BuiltinAgreement.normKeys
  let consC ← bc.dataDecls.flatMapM (formedConstructors atomsC)
  let canonicalCons := consC.map Subtype.val
  let canonicalAtoms := atomsC ++ Benitoite.Release.Refinement.Surface.StandardSupport.atoms
  -- 照合の対象は、プログラムが参照する組込みと、型を通じて届く data の閉包に限る。閉包の中の差は断る。
  let sC : StdlibInput ← fromJson? (names.json (toJson s))
  let operatorsC : List OperatorEntry ← fromJson? (names.json (toJson operators))
  let closure := closureOf inputC bc sC operatorsC
  -- 閉包の組込みの署名、data の宣言、組込みの名前の三つの差を、それぞれの名前の一覧とともに一度に断る。
  let signatureGaps := (BuiltinAgreement.composedNames closure.prims).filter
    fun n => !BuiltinAgreement.standardCheck atomsC canonicalSig [n]
  let standardData := closure.data.filter fun n =>
    (bc.dataDecls.find? (·.name == n)).any fun d => d.package == "stdlib" || d.builtin != .ordinary
  let dataGaps := BuiltinAgreement.dataDisagreements canonicalAtoms canonicalCons standardData
  -- 標準の名前へ写らなかった標準ライブラリの data で、表示名が写されていない標準の宣言に対応するもの。
  let unmapped := (standardData.filterMap fun n => bc.dataDecls.find? (·.name == n)).flatMap fun d =>
    if (Benitoite.Release.Refinement.StandardModel.declarations.find? (·.name == d.name)).isSome then []
    else (CanonicalNames.displayCounterparts d.builtin d.package d.name d.typeName).filter
      fun c => !bc.dataDecls.any (·.name == c)
  let unknown := closure.prims.filter fun n =>
    (Benitoite.Release.Refinement.StandardModel.primitive n).isNone && !CanonicalNames.primitiveTargets.contains n
  -- 標準表にも名前の写しにもない組込みは、標準表が仮定側として持つかを決められないので、断らずに報告に残す。
  let report := [("builtin signature disagrees with the standard table", signatureGaps),
    ("data declaration disagrees with the standard table", dataGaps ++ unmapped)].filter (!·.2.isEmpty)
  if !report.isEmpty then
    throw ("; ".intercalate (report.map fun (reason, ns) => s!"{reason}: {ns}"))
  let agreed : PLift (BuiltinAgreement.standardCheck atomsC canonicalSig closure.prims = true) ←
    if h : BuiltinAgreement.standardCheck atomsC canonicalSig closure.prims = true then pure ⟨h⟩
    else throw s!"builtin signature disagrees with the standard table: {signatureGaps}"
  let dataAgreed : PLift (dataGaps = []) ←
    if h : dataGaps = [] then pure ⟨h⟩ else throw s!"data declaration disagrees with the standard table: {dataGaps}"

  let base : Benitoite.Release.Refinement.Surface.Check.Input := {
    D := { funs := fun _ => none, cons := fun _ => none }
    builtinSource := .custom (builtinsOf b S ms)
    opPrim := makeOpPrim atoms operators
    formation := { atoms := atomsR, ctors := fun _ => [] }
    satDec := satDecOf S
    admitsDec := admitsDecOf S ms
    admitsRDec := admitsRDecOf b
    proofSteps := defaultProofSteps
    logicCertificates := certificateTable input.logicCertificates }
  let q := m.input base
  -- 必須の判定の受理の入力。null は規則のない受理の入力を表す。
  let scope : Option ScopeAcceptanceEntry ←
    if input.scopeAcceptance == Json.null then pure none else some <$> fromJson? input.scopeAcceptance
  -- 実装のメソッドの本体の鍵は、その本体の定義の名前（関数の鍵と同じ変換）とする。
  let methodNames ← (input.definitions.filterMap fun d => match d.scope with
    | .inScope s _ => do return (← s.implementation, ← s.method, d.name)
    | _ => none).mapM fun (i, mn, n) => do return (i, mn, ← functionKey n)
  let accept := ScopeAcceptanceEntry.acceptInput scope
  let accept := { accept with methodKey := fun i mn =>
    ((methodNames.find? fun (a, b, _) => a == i && b == mn).map (·.2.2)).getD (accept.methodKey i mn) }
  return {
    materials := m, base, table := builtinsOf b S ms, custom := rfl
    constructors := constructorsOk b m, records := recordChecks.all id
    implNames := implNamesOk m q.methods q.supers, outside, atoms, accept, atoms_eq := rfl, support
    prims := builtinsOf_support b S prims, sat := satDecOf_sound b S ms, admits := admitsDecOf_sound b S ms
    ranges := admitsRDecOf_sound b S ms, operators := makeOpPrim_support atoms operators atomsR, builtinNames
    canonicalNames, canonicalSig, canonicalRawSig, canonical_eq := rfl, canonicalCons, canonicalAtoms, closure,
    standardData
    agreement := BuiltinAgreement.standardCheck_sound
      (BuiltinAgreement.normKeys_support (builtinsOf_support bc SC primsC)) agreed.down
    dataAgreement := BuiltinAgreement.dataDisagreements_nil dataAgreed.down
    unknownBuiltins := unknown }

/-- 交換の入力の準備。成功した準備の検査器の入力は健全である（`prepare_sound`）。 -/
def prepare (input : Input) (b : BuiltinInput) (s : StdlibInput)
    (operators : List OperatorEntry) : Except String Prepared :=
  Parts.prepared <$> prepareParts input b s operators

/-- 準備が成功すれば、検査器の入力は健全である。宣言材料と組み込みの表の全署名の支持は準備が形成した証拠から、
判定の健全性は同じ材料から作った表から得る。 -/
theorem prepare_sound {input : Input} {b : BuiltinInput} {s : StdlibInput} {operators : List OperatorEntry}
    {p : Prepared} (h : prepare input b s operators = .ok p) : p.input.Sound := by
  unfold prepare at h
  cases hp : prepareParts input b s operators with
  | error e => rw [hp] at h; cases h
  | ok x =>
    rw [hp] at h
    cases h
    exact x.sound

/-- 交換の表は独自の表なので、実入口の準備（`CheckPreparation.prepare`）はどの本体も入力ごとそのまま返し、
準備後の入力も健全である。実入口の健全性（`CheckAccept.checkProgramAccepted_sound`）の前提の入力はこれで供給する。 -/
theorem prepare_entry {input : Input} {b : BuiltinInput} {s : StdlibInput} {operators : List OperatorEntry}
    {p : Prepared} (h : prepare input b s operators = .ok p)
    (program : Benitoite.Release.Refinement.Surface.Program) :
    Benitoite.Release.Refinement.Surface.CheckPreparation.prepare p.input program = ⟨p.input, program⟩ ∧
      (Benitoite.Release.Refinement.Surface.CheckPreparation.prepare p.input program).input.Sound := by
  have hs := prepare_sound h
  unfold prepare at h
  cases hp : prepareParts input b s operators with
  | error e => rw [hp] at h; cases h
  | ok x =>
    rw [hp] at h
    cases h
    have same := Benitoite.Release.Refinement.Surface.CheckPreparation.prepare_custom x.prepared.input program
      x.table x.custom
    exact ⟨same, by rw [same]; exact hs⟩

/-- 準備が成功すれば、次の二つが成り立つ。(1) 名前を標準の名前へ写した表の、閉包（`closureOf`）の組込みの名前のうち
標準表の合成済みの名前の署名は、整形式の名前の一覧で作ったどの完成表の署名とも欄が一致する（型パラメータの制約の
命題と仮定側の名前を除く）。写した表の型パラメータの制約は鍵の印をそろえてある（`prepare_constraints`）。(2) 閉包の
標準ライブラリの data（`Prepared.standardData`）のうち標準の宣言と同じ名前を持つものは、構成子の名前の集合・型引数の数・引数の型（原子の一覧での構造比較）が
標準の宣言と一致する。閉包の組込みのうち標準表の合成済みの名前でも名前の写しの仮定側の名前でもないもの
（`Prepared.unknownBuiltins`）は照らさない。検査器の表と写した表の対応（名前の写しと鍵の印のそろえ）と、検査器が閉包の外の行を読まないことは、この定理は
述べない。 -/
theorem prepare_agrees {input : Input} {b : BuiltinInput} {s : StdlibInput} {operators : List OperatorEntry}
    {p : Prepared} (h : prepare input b s operators = .ok p)
    {L : Benitoite.Release.Refinement.StandardModel.NameLists} (hL : L.WF)
    {P : Benitoite.Release.Refinement.Program} (T : Benitoite.Release.Refinement.StandardModel.DataTable P)
    (A : Benitoite.Release.Refinement.StandardModel.AssumedTable) :
    (∀ n ∈ BuiltinAgreement.composedNames p.closure.prims, ∃ s s', p.canonicalSig n = some s ∧
      (Benitoite.Release.Refinement.StandardModel.complete L T A).sig n = some s' ∧ BuiltinAgreement.ShapeEq s s') ∧
    BuiltinAgreement.DataListAgrees p.canonicalAtoms p.canonicalCons p.standardData := by
  unfold prepare at h
  cases hp : prepareParts input b s operators with
  | error e => rw [hp] at h; cases h
  | ok x =>
    rw [hp] at h
    cases h
    exact ⟨BuiltinAgreement.agrees_complete x.agreement hL T A, x.dataAgreement⟩

/-- 準備が成功すれば、照合に使った署名は、名前を写した表の署名の型パラメータの鍵の印をそろえたものであり、
そろえても型パラメータの制約の判定（`ModelConstraints.admits`）は変わらない（`BuiltinAgreement.admits_normKey`）。
`prepare_agrees` の (1) の一致は、この意味で名前を写した表の制約についても成り立つ。 -/
theorem prepare_constraints {input : Input} {b : BuiltinInput} {s : StdlibInput} {operators : List OperatorEntry}
    {p : Prepared} (h : prepare input b s operators = .ok p) {n : String} {sg : Benitoite.Release.Refinement.PrimSig}
    (hs : p.canonicalSig n = some sg) :
    ∃ raw, p.canonicalRawSig n = some raw ∧ sg = BuiltinAgreement.normKeys raw ∧
      ∀ S C ts, Benitoite.Release.Refinement.ModelConstraints.admits S (sg.tparams.map (·.constraints)) C ts ↔
        Benitoite.Release.Refinement.ModelConstraints.admits S (raw.tparams.map (·.constraints)) C ts := by
  unfold prepare at h
  cases hp : prepareParts input b s operators with
  | error e => rw [hp] at h; cases h
  | ok x =>
    rw [hp] at h
    cases h
    change x.canonicalSig n = some sg at hs
    rw [x.canonical_eq] at hs
    obtain ⟨raw, hraw, rfl⟩ := Option.map_eq_some_iff.mp hs
    refine ⟨raw, hraw, rfl, fun S C ts => ?_⟩
    have hmap : (BuiltinAgreement.normKeys raw).tparams.map (·.constraints) =
        (raw.tparams.map (·.constraints)).map BuiltinAgreement.normKey := by
      simp [BuiltinAgreement.normKeys, List.map_map, Function.comp_def]
    rw [hmap]
    exact BuiltinAgreement.admits_normKey S _ C ts

end Benitoite.Exchange.CheckInput
