import Benitoite.Exchange.Convert
import Benitoite.Release.BuiltinTable

/-! E2a-1a: 入力ごとの組み込み・データ型の宣言。版 7 の Corpus の原子を増やさない。
E2a-1b: 宣言から求めた要約と制約の判定を使い、具体的な Builtins を作る。 -/
namespace Benitoite.Exchange
open Lean

structure PrimConstraint where
  equality : Bool
  key : Bool
  ordered : Bool
  deriving BEq, ToJson, FromJson

structure BuiltinEntry where
  name : String
  tparams : List PrimConstraint
  neffs : Nat
  params : List Ty
  ret : Ty
  eff : Eff
  kind : String
  opEff : Option String
  classConstraints : List (String × Nat)
  unconvertibleTypes : List String
  deriving ToJson, FromJson

structure DataCtorEntry where
  name : String
  args : List Ty
  deriving ToJson, FromJson

structure DataEntry where
  name : String
  ntys : Nat
  ctors : List DataCtorEntry
  deriving ToJson, FromJson

/-- always は「等値でない型（鍵では Float）を型引数によらず含む」である。 -/
structure TypeSummary where
  always : Bool
  dependsOn : List Nat
  deriving BEq, ToJson, FromJson

structure DataSummary where
  name : String
  eq : TypeSummary
  key : TypeSummary
  deriving ToJson, FromJson

structure BuiltinInput where
  group : String
  name : String
  prims : List BuiltinEntry
  effects : List EffectEntry
  resources : List Nat
  dataDecls : List DataEntry
  summaries : List DataSummary
  statePure : List String
  /-- 元の入力が import していない標準ライブラリの宣言。名前は入力の表へ移してある。 -/
  supplementalData : List (String × String)
  supplementalPrims : List String
  deriving ToJson, FromJson

structure BuiltinCorpus where
  version : Nat
  inputs : List BuiltinInput
  deriving ToJson, FromJson

def primKind : String → Except String Benitoite.Release.PrimKind
  | "pure" => pure .pure | "io" => pure .io | "exit" => pure .exit
  | "refNew" => pure .refNew | "refGet" => pure .refGet | "refSet" => pure .refSet
  | "refUpdate" => pure .refUpdate | "force" => pure .force
  | n => throw s!"unknown primitive kind: {n}"

/-- ordered の位置は等値・鍵の制約とともに保持し、admits で検査する。 -/
structure PrimMaterial where
  constraints : List PrimConstraint
  neffs : Nat
  params : List Benitoite.Release.Ty
  ret : Benitoite.Release.Ty
  eff : Benitoite.Release.Eff
  kind : Benitoite.Release.PrimKind
  opEff : Option Benitoite.Release.EffName

def PrimMaterial.toPrimSig (m : PrimMaterial)
    (admits : List Benitoite.Release.TParam → List Benitoite.Release.Ty → Prop) :
    Benitoite.Release.PrimSig where
  tparams := m.constraints.map (fun c => ⟨c.equality, c.key⟩)
  neffs := m.neffs
  params := m.params
  ret := m.ret
  eff := m.eff
  admits := admits
  kind := m.kind
  opEff := m.opEff

/-- opaque の型引数を文字列に埋め込む旧交換形式は、型の置き換えに対応しない。 -/
partial def Ty.hasOpaqueArguments : Ty → Except String Bool
  | .opaque n => do
      let pieces := n.splitOn ":"
      let some id := pieces.head? | throw s!"invalid opaque name: {n}"
      if id.toNat?.isNone then throw s!"invalid opaque type id: {n}"
      let args ← Json.parse (String.intercalate ":" pieces.tail)
      let ts ← (fromJson? args : Except String (List Ty))
      return !ts.isEmpty
  | .data _ ts | .tapp _ ts => do
      return (← ts.mapM Ty.hasOpaqueArguments).any id
  | .fn ps r _ => do
      return (← r.hasOpaqueArguments) || (← ps.mapM Ty.hasOpaqueArguments).any id
  | .list t | .reference t | .lazyT t | .set t | .dict _ t => t.hasOpaqueArguments
  | .map k v => do return (← k.hasOpaqueArguments) || (← v.hasOpaqueArguments)
  | _ => pure false

def BuiltinEntry.hasOpaqueArguments (b : BuiltinEntry) : Except String Bool := do
  return (← b.ret.hasOpaqueArguments) || (← b.params.mapM Ty.hasOpaqueArguments).any id

/-- 補った標準ライブラリの型も、同じ入力のデータ型の表を参照していることを確かめる。 -/
partial def Ty.checkDataNames (ds : List DataEntry) : Ty → Except String Unit
  | .data n ts => do
      let some d := ds.find? (fun d => d.name == n) | throw s!"missing data declaration: {n}"
      if d.ntys != ts.length then throw s!"data type arity mismatch: {n}"
      ts.forM (Ty.checkDataNames ds)
  | .ctor (.data n) =>
      if ds.any (fun d => d.name == n) then pure () else throw s!"missing data constructor type: {n}"
  | .tapp _ ts => ts.forM (Ty.checkDataNames ds)
  | .fn ps r _ => do ps.forM (Ty.checkDataNames ds); r.checkDataNames ds
  | .list t | .reference t | .lazyT t | .set t | .dict _ t => t.checkDataNames ds
  | .map k v => do k.checkDataNames ds; v.checkDataNames ds
  | _ => pure ()

/-- 対象外の印を信頼して、変換できない型を黙って通さない。 -/
def BuiltinEntry.toMaterial (b : BuiltinEntry) : Except String PrimMaterial := do
  if !b.classConstraints.isEmpty then throw s!"typeclass constraints: {b.name}"
  if (← b.hasOpaqueArguments) then throw s!"opaque type arguments: {b.name}"
  return {
    constraints := b.tparams
    neffs := b.neffs
    params := ← b.params.mapM Ty.toRelease
    ret := ← b.ret.toRelease
    eff := b.eff.toRelease
    kind := ← primKind b.kind
    opEff := b.opEff }

structure DataMaterial where
  name : Benitoite.Release.DataName
  ntys : Nat
  ctors : List (Benitoite.Release.ConName × Benitoite.Release.ConDecl)

def DataEntry.toMaterial (d : DataEntry) : Except String DataMaterial := do
  return { name := d.name, ntys := d.ntys, ctors := ← d.ctors.mapM (fun c => do
    return (c.name, { data := d.name, ntys := d.ntys, args := ← c.args.mapM Ty.toRelease })) }

/-- 宣言順を保存し、E1c の型からの列挙と Program.cons の材料を同じ表から得る。 -/
def dataConstructors (ds : List DataMaterial) (name : Benitoite.Release.DataName) :
    List Benitoite.Release.ConName :=
  ((ds.find? (fun d => d.name == name)).map (fun d => d.ctors.map Prod.fst)).getD []

def constructorDecl (ds : List DataMaterial) (name : Benitoite.Release.ConName) :
    Option Benitoite.Release.ConDecl :=
  ((ds.flatMap DataMaterial.ctors).find? (fun c => c.1 == name)).map Prod.snd

def BuiltinInput.effectOps (b : BuiltinInput) (name : Benitoite.Release.EffName) :
    Option (List Benitoite.Release.PrimName) :=
  (b.effects.find? (fun e => e.name == name)).map EffectEntry.ops

/-- リソースの識別子を opaque 名の先頭から読む。Task[T] の引数は判定に使わない。 -/
def BuiltinInput.isResource (b : BuiltinInput) (name : Benitoite.Release.OpaqueName) : Bool :=
  match (name.splitOn ":").head?.bind String.toNat? with
  | some id => b.resources.contains id
  | none => false

/-- JSON に依存しない要約の宣言へ、同じ入力の名前のままで移す。 -/
def DataMaterial.toBuiltinDataDecl (d : DataMaterial) : Benitoite.Release.BuiltinDataDecl :=
  ⟨d.name, d.ntys, d.ctors.map (fun c => c.2.args)⟩

/-- 書き出した summaries はここでは使わず、宣言の型を変換する。 -/
def BuiltinInput.summaryDecls (b : BuiltinInput) : Except String (List Benitoite.Release.BuiltinDataDecl) := do
  return (← b.dataDecls.mapM DataEntry.toMaterial).map DataMaterial.toBuiltinDataDecl

/-- E2 の検査でも直接使える、Lean で計算した要約の表。 -/
def BuiltinInput.summaryTable (b : BuiltinInput) : Except String Benitoite.Release.SummaryTable := do
  return Benitoite.Release.dataSummaries (← b.summaryDecls)

/-- ordered を失わずに純粋な判定へ渡す。 -/
def PrimConstraint.toBuiltinConstraint (c : PrimConstraint) : Benitoite.Release.BuiltinConstraint :=
  ⟨c.equality, c.key, c.ordered⟩

/-- prim の変換と admits の束縛は、sig を引くたびに繰り返さず一度だけ行う。
対象外の印のある prim は表から除き、それ以外の変換の失敗は返す。 -/
def BuiltinInput.primSignatures (b : BuiltinInput) (S : Benitoite.Release.SummaryTable) :
    Except String (List (Benitoite.Release.PrimName × Benitoite.Release.PrimSig)) := do
  let mut sigs := []
  for p in b.prims do
    if p.unconvertibleTypes.isEmpty && p.classConstraints.isEmpty then
      let m ← p.toMaterial
      let cs := m.constraints.map PrimConstraint.toBuiltinConstraint
      sigs := sigs ++ [(p.name, m.toPrimSig (fun C ts => Benitoite.Release.admitsB S cs C ts = true))]
  return sigs

/-- 入力ごとの具体的な組み込みの表。実行の欄は E2 で使わない。
Reference.get/set は IO の操作ではないので、使われない入力では sig が none になりうる。 -/
def mkBuiltins (b : BuiltinInput) : Except String Benitoite.Release.Builtins := do
  let S ← b.summaryTable
  let sigs ← b.primSignatures S
  return {
    sig := fun name => (sigs.find? (fun p => p.1 == name)).map Prod.snd
    delta := fun _ _ _ _ => none
    ioResponse := fun _ _ _ _ _ => False
    releaseResponse := fun _ _ => False
    isResource := b.isResource
    effects := b.effectOps
    sat := fun C t p => Benitoite.Release.satB S C t p = true
    refGet := ((b.prims.find? (fun p => p.kind == "refGet")).map BuiltinEntry.name).getD "Reference.get"
    refSet := ((b.prims.find? (fun p => p.kind == "refSet")).map BuiltinEntry.name).getD "Reference.set" }

end Benitoite.Exchange
