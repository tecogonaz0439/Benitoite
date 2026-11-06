import Benitoite.Exchange.Convert
import Benitoite.Release.BuiltinTable
import Benitoite.Release.Refinement.VarianceSyntax
import Benitoite.Release.Refinement.StandardKeyTyping
import Benitoite.Release.Refinement.Surface.CheckCompare

/-! 契約名とソース順を保持する独立した交換の入口。
設計書 07-04「証明する性質」の検査対象と既存形式を区別する。 -/
namespace Benitoite.Exchange
open Lean

deriving instance ToJson, FromJson for Benitoite.Release.Refinement.Variance, Benitoite.Release.Refinement.Polarity

structure PrimConstraint where
  equality : Bool
  key : Bool
  ordered : Bool
  deriving BEq, ToJson, FromJson

structure BuiltinEntry where
  name : String
  tparams : List PrimConstraint
  tparamKinds : List Benitoite.Release.Refinement.TyKind := tparams.map (fun _ => .value)
  neffs : Nat
  effParams : List EffParam
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  kind : String
  opEff : Option String
  classConstraints : List (String × Nat)
  unconvertibleTypes : List String
  /-- 範囲の変数ごとの対象の種類（`PrimSig.rkinds`）と IO の形（`PrimSig.shape`）。sidecar 7 で加えた。 -/
  rkinds : List Scope.Domain.Kind
  shape : Scope.Signature.IOShape
  deriving ToJson, FromJson

structure DataCtorEntry where
  constructorName : Option String := none
  fields : Option (List String)
  name : String
  args : List Ty
  deriving ToJson, FromJson

structure DataEntry where
  builtin : Benitoite.Exchange.BuiltinData
  package : String
  typeName : String
  isRecord : Bool
  extensible : Bool
  name : String
  ntys : Nat
  ctors : List DataCtorEntry
  variances : List Benitoite.Release.Refinement.Variance := List.replicate ntys .invariant
  requirements : List Ty := []
  publicBoundary : List (Benitoite.Release.Refinement.Polarity × Ty) := []
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

/-- 名前ごとの保持する要求の型（`valContent` の有限の表）。内容は交換の型（`Exchange.Ty`）であり、`Http.RequestIn` には
`Http.ClientRequest` のレコードの型（`{"data":{"name":…,"args":[]}}`）を書く。 -/
structure ContentEntry where
  name : String
  content : Ty
  deriving ToJson, FromJson

/-- 表の項目の内容の型を Release の型へ変換した有限の表。 -/
def ContentEntry.table (xs : List ContentEntry) : Except String (List (String × Benitoite.Release.Refinement.Ty)) :=
  xs.mapM fun e => return (e.name, ← e.content.toRelease)

/-- 有限の表の先頭の項目を引く。同じ名前の重複は `readBuiltins` が拒否し、変換できない内容は `readBuiltins` が拒否する
（変換に失敗した項目は、ここでは項目がないものとして読む）。 -/
def ContentEntry.lookup (xs : List ContentEntry) (n : String) : Option Benitoite.Release.Refinement.Ty :=
  (xs.find? (·.name == n)).bind fun e => e.content.toRelease.toOption

structure BuiltinInput where
  group : String
  name : String
  prims : List BuiltinEntry
  effects : List EffectEntry
  resources : List Nat
  opaqueNames : List (String × String) := []
  dataDecls : List DataEntry
  summaries : List DataSummary
  statePure : List String
  /-- 元の入力が import していない標準ライブラリの宣言。名前は入力の表へ移してある。 -/
  supplementalData : List (String × String)
  supplementalPrims : List String
  /-- 表のデータ（`Builtins.effKind`・`valKind`・`admitsR`・`valContent`）。sidecar 7 で加えた。旧版は空の表
  （`Builtins` の既定の値）で読む。正しさは信頼の対象である（設計書 07-04「形式化で仮定するもの」）。 -/
  effKinds : List KindEntry
  valKinds : List KindEntry
  admitsR : List AdmitsEntry
  valContents : List ContentEntry
  deriving ToJson, FromJson

structure BuiltinCorpus where
  version : Nat
  inputs : List BuiltinInput
  deriving ToJson, FromJson

def primKind : String → Except String Benitoite.Release.Refinement.PrimKind
  | "pure" => pure .pure | "io" => pure .io | "exit" => pure .exit
  | "refNew" => pure .refNew | "refGet" => pure .refGet | "refSet" => pure .refSet
  | "refUpdate" => pure .refUpdate | "force" => pure .force | "pathBases" => pure .pathBases
  | n => throw s!"unknown primitive kind: {n}"

/-- ordered の位置は等値・鍵の制約とともに保持し、admits で検査する。 -/
structure PrimMaterial where
  constraints : List Benitoite.Release.BuiltinConstraint
  tparamKinds : List Benitoite.Release.Refinement.TyKind
  names : List String
  neffs : Nat
  params : List Benitoite.Release.Refinement.Ty
  ret : Benitoite.Release.Refinement.Ty
  eff : Benitoite.Release.Refinement.Eff
  kind : Benitoite.Release.Refinement.PrimKind
  opEff : Option String

def PrimMaterial.toPrimSig (m : PrimMaterial)
    (admits : List Benitoite.Release.TParam → List Benitoite.Release.Refinement.Ty → Prop) :
    Benitoite.Release.Refinement.PrimSig where
  tparams := m.constraints.zipWith (fun c k => ⟨⟨c.equality,c.key⟩,k⟩) m.tparamKinds
  neffs := m.neffs
  names := m.names
  params := m.params
  ret := m.ret
  eff := m.eff
  admits := admits
  kind := m.kind
  opEff := m.opEff

structure DataMaterial where
  name : String
  ntys : Nat
  ctors : List (String × Benitoite.Release.Refinement.ConDecl)

/-- opaque の型引数を文字列に埋め込む旧交換形式は、型の置き換えに対応しない。 -/
partial def Ty.hasOpaqueArguments : Ty → Except String Bool
  | .opaque n _ => do
      if !n.contains ':' then return false
      let pieces := n.splitOn ":"
      let some id := pieces.head? | throw s!"invalid opaque name: {n}"
      if id.toNat?.isNone then throw s!"invalid opaque type id: {n}"
      let args ← Json.parse (String.intercalate ":" pieces.tail)
      let ts ← (fromJson? args : Except String (List Ty))
      return !ts.isEmpty
  | .data _ ts | .tapp _ ts | .external _ ts => do
      return (← ts.mapM Ty.hasOpaqueArguments).any id
  | .fn _ ps r e | .dependentFn _ ps r e => do
      let fs := e.filterMap fun a => match a with | .fail t => some t | _ => none
      return (← r.hasOpaqueArguments) || (← (ps ++ fs).mapM Ty.hasOpaqueArguments).any id
  | .cont a r e => do
      let fs := e.filterMap fun x => match x with | .fail t => some t | _ => none
      return (← (a :: r :: fs).mapM Ty.hasOpaqueArguments).any id
  | .list t | .reference t | .lazyT t | .set t | .dict _ t | .refined t _ => t.hasOpaqueArguments
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
  | .tapp _ ts | .external _ ts => ts.forM (Ty.checkDataNames ds)
  | .fn _ ps r e | .dependentFn _ ps r e => do
      ps.forM (Ty.checkDataNames ds)
      r.checkDataNames ds
      (e.filterMap fun a => match a with | .fail t => some t | _ => none).forM (Ty.checkDataNames ds)
  | .cont a r e => do
      a.checkDataNames ds
      r.checkDataNames ds
      (e.filterMap fun x => match x with | .fail t => some t | _ => none).forM (Ty.checkDataNames ds)
  | .list t | .reference t | .lazyT t | .set t | .dict _ t | .refined t _ => t.checkDataNames ds
  | .map k v => do k.checkDataNames ds; v.checkDataNames ds
  | _ => pure ()

/-- 書式化の内部頭は名前で固定署名へ対応付け、δの算法を仮定へ追加しない。 -/
def BuiltinEntry.validateFormat (b : BuiltinEntry) : Except String Unit := do
  if !b.name.startsWith "%Format." then return
  let types : List Benitoite.Release.Refinement.Ty := [
    .base .integer, .base .integer8, .base .integer16, .base .integer32,
    .base .byte, .base .unsignedInteger16, .base .unsignedInteger32, .base .unsignedInteger64,
    .base .float, .base .float32, .base .decimal, .base .string, .base .character, .base .boolean]
  let names := ["Integer", "Integer8", "Integer16", "Integer32", "Byte", "UnsignedInteger16",
    "UnsignedInteger32", "UnsignedInteger64", "Float", "Float32", "Decimal", "String", "Character", "Boolean"]
  let some pair := (types.zip names).find? (fun (_, n) => "%Format." ++ n == b.name)
    | throw s!"unknown format builtin: {b.name}"
  let t := pair.1
  let actual : Benitoite.Release.Refinement.Ty := .fn b.names (← b.params.mapM Ty.toRelease)
    (← b.ret.toRelease) (← b.eff.toRelease)
  if !Benitoite.Release.Refinement.Surface.CheckCompare.rawTyEq [] actual (.fn ["value", "kind", "align", "sign", "alternate", "zero", "width", "precision"]
    [t,.base .integer,.base .integer,.base .integer,.base .boolean,.base .boolean,.base .integer,.base .integer]
    (.base .string) Benitoite.Release.Refinement.Eff.empty) ||
      !b.eff.isEmpty || !b.tparams.isEmpty ||
      b.neffs != 0 || !b.effParams.isEmpty || b.kind != "pure" || b.opEff.isSome ||
      !b.classConstraints.isEmpty || !b.unconvertibleTypes.isEmpty then
    throw s!"invalid format builtin signature: {b.name}"

/-- 対象外の印を信頼して、変換できない型を黙って通さない。 -/
def BuiltinEntry.toMaterial (b : BuiltinEntry) : Except String PrimMaterial := do
  b.validateFormat
  checkNames b.names b.params.length
  if b.tparamKinds.length != b.tparams.length then throw s!"type parameter kind count mismatch: {b.name}"
  let h : Header := {
    tparams := b.tparams.map (fun c => (c.equality,c.key)), tparamKinds := b.tparamKinds
    neffs := b.neffs, effParams := b.effParams, names := b.names
    params := b.params, ret := b.ret, eff := b.eff }
  h.validateNoFail
  if !b.classConstraints.isEmpty then throw s!"typeclass constraints: {b.name}"
  if (← b.hasOpaqueArguments) then throw s!"opaque type arguments: {b.name}"
  return {
    constraints := b.tparams.map (fun c => ⟨c.equality, c.key, c.ordered⟩)
    tparamKinds := b.tparamKinds
    names := b.names
    neffs := b.neffs
    params := ← b.params.mapM Ty.toRelease
    ret := ← b.ret.toRelease
    eff := ← b.eff.toRelease
    kind := ← primKind b.kind
    opEff := b.opEff }

/-- 署名に範囲の変数の種類と IO の形を入れる（材料 `PrimMaterial` は持たないので、署名を作った後に入れる）。 -/
def BuiltinEntry.withRanges (b : BuiltinEntry) (sg : Benitoite.Release.Refinement.PrimSig) : Benitoite.Release.Refinement.PrimSig :=
  { sg with rkinds := b.rkinds, shape := b.shape }

def DataEntry.info (d : DataEntry) : DataTypeInfo :=
  ⟨d.builtin, d.package, d.name, d.typeName, d.isRecord, d.extensible,
    d.ctors.map (fun c => (c.name, c.constructorName.getD ""))⟩

def readBuiltins (j : Json) : Except String BuiltinCorpus := do
  let raw ← exchangeJson "builtins" j
  let c : BuiltinCorpus ← fromJson? raw
  if toJson c != raw then throw "unexpected builtin fields"
  for i in c.inputs do
    -- 表のデータは名前ごとに一つ。同じ名前の二つの項目のどちらかを黙って選ばない。
    let unique := fun (ns : List String) => ns.eraseDups.length == ns.length
    if !unique (i.effKinds.map (·.name)) || !unique (i.valKinds.map (·.name)) ||
        !unique (i.admitsR.map (·.name)) || !unique (i.valContents.map (·.name)) then
      throw "duplicate table data entry"
    -- 保持する要求の型は Release の型へ変換できなければならない（変換できない項目を黙って欠かさない）。
    let _ ← ContentEntry.table i.valContents
    for p in i.prims do
      if p.tparams.length != p.tparamKinds.length then throw "type parameter kind count mismatch"
      p.validateFormat
    validateDataTypes (i.dataDecls.map DataEntry.info)
    for d in i.dataDecls do
      validateBuiltinShape d.builtin d.ntys d.isRecord (d.ctors.map fun c =>
        (c.constructorName.getD "", c.args.map fun t => match t with | .tvar n => some n | _ => none))
      if d.isRecord != d.ctors.any (fun c => c.fields.isSome) ||
          (d.isRecord && d.ctors.length != 1) then throw "data isRecord/fields mismatch"
  return c

def DataEntry.toMaterial (d : DataEntry) : Except String DataMaterial := do
  return { name := d.name, ntys := d.ntys, ctors := ← d.ctors.mapM (fun c => do
    if let some fs := c.fields then checkNames fs c.args.length
    return (c.name, { data := d.name, ntys := d.ntys, args := ← c.args.mapM Ty.toRelease })) }

/-- 宣言順を保存し、網羅性の型からの列挙と Program.cons の材料を同じ表から得る。 -/
def dataConstructors (ds : List DataMaterial) (name : String) :
    List String :=
  ((ds.find? (fun d => d.name == name)).map (fun d => d.ctors.map Prod.fst)).getD []

def constructorDecl (ds : List DataMaterial) (name : String) :
    Option Benitoite.Release.Refinement.ConDecl :=
  ((ds.flatMap (fun d => d.ctors)).find? (fun c => c.1 == name)).map Prod.snd

def BuiltinInput.effectOps (b : BuiltinInput) (name : String) :
    Option (List String) :=
  (b.effects.find? (fun e => e.name == name)).map EffectEntry.ops

/-- リソースの識別子を opaque 名の先頭から読む。Task[T] の引数は判定に使わない。 -/
def BuiltinInput.isResource (b : BuiltinInput) (name : String) : Bool :=
  match (name.splitOn ":").head?.bind String.toNat? with
  | some id => b.resources.contains id
  | none => false

/-- JSON に依存しない要約の宣言へ、同じ入力の名前のままで移す。 -/
def toBuiltinDataDecl (d : DataMaterial) : Benitoite.Release.BuiltinDataDecl :=
  ⟨d.name, d.ntys, d.ctors.map (fun c => Benitoite.Release.Refinement.StandardKeyTyping.carriers c.2.args)⟩

/-- 書き出した summaries はここでは使わず、宣言の型を変換する。 -/
def BuiltinInput.summaryDecls (b : BuiltinInput) : Except String (List Benitoite.Release.BuiltinDataDecl) := do
  return (← b.dataDecls.mapM DataEntry.toMaterial).map toBuiltinDataDecl

/-- 宣言の検査でも直接使える、Lean で計算した要約の表。 -/
def BuiltinInput.summaryTable (b : BuiltinInput) : Except String Benitoite.Release.SummaryTable := do
  return Benitoite.Release.dataSummaries (← b.summaryDecls)

/-- ordered を失わずに純粋な判定へ渡す。 -/
def PrimConstraint.toBuiltinConstraint (c : PrimConstraint) : Benitoite.Release.BuiltinConstraint :=
  ⟨c.equality, c.key, c.ordered⟩

/-- prim の変換と admits の束縛は、sig を引くたびに繰り返さず一度だけ行う。
対象外の印のある prim は表から除き、それ以外の変換の失敗は返す。 -/
def BuiltinInput.primSignatures (b : BuiltinInput) (S : Benitoite.Release.SummaryTable) :
    Except String (List (String × Benitoite.Release.Refinement.PrimSig)) := do
  let mut sigs := []
  for p in b.prims do
    if p.unconvertibleTypes.isEmpty && p.classConstraints.isEmpty then
      let m ← p.toMaterial
      let cs := m.constraints
      sigs := sigs ++ [(p.name, p.withRanges (m.toPrimSig (fun C ts => Benitoite.Release.admitsB S cs C (Benitoite.Release.Refinement.StandardKeyTyping.carriers ts) = true)))]
  return sigs

/-- 入力ごとの具体的な組み込みの表。宣言の検査では実行の欄を使わない。
Reference.get/set は IO の操作ではないので、使われない入力では sig が none になりうる。 -/
def mkBuiltins (b : BuiltinInput) : Except String Benitoite.Release.Refinement.Builtins := do
  let S ← b.summaryTable
  let sigs ← b.primSignatures S
  return {
    sig := fun name => (sigs.find? (fun p => p.1 == name)).map Prod.snd
    delta := fun _ _ _ _ _ => none
    ioResponse := fun _ _ _ _ _ _ => False
    releaseResponse := fun _ _ => False
    isResource := b.isResource
    effects := b.effectOps
    sat := fun C t p => Benitoite.Release.satB S C (Benitoite.Release.Refinement.StandardKeyTyping.carrier t) p = true
    refGet := ((b.prims.find? (fun p => p.kind == "refGet")).map BuiltinEntry.name).getD "Reference.get"
    refSet := ((b.prims.find? (fun p => p.kind == "refSet")).map BuiltinEntry.name).getD "Reference.set"
    effKind := KindEntry.lookup b.effKinds
    valKind := KindEntry.lookup b.valKinds
    admitsR := fun n rs => ∃ old, rs = old.map Benitoite.Release.Refinement.RangeExpr.absolute ∧ AdmitsEntry.admitsR b.admitsR n old
    valContent := ContentEntry.lookup b.valContents }

/-- 表の組み込みの表に、交換した表のデータを入れる（`CheckTables.builtins` は表のデータを持たない）。 -/
def BuiltinInput.withTableData (b : BuiltinInput) (B : Benitoite.Release.Refinement.Builtins) : Benitoite.Release.Refinement.Builtins :=
  { B with
    effKind := KindEntry.lookup b.effKinds
    valKind := KindEntry.lookup b.valKinds
    admitsR := fun n rs => ∃ old, rs = old.map Benitoite.Release.Refinement.RangeExpr.absolute ∧ AdmitsEntry.admitsR b.admitsR n old
    valContent := ContentEntry.lookup b.valContents }

/-- 検査の入力の判定 `admitsRDec` は、表のデータを入れた組み込みの表の `admitsR` と合う
（`Check.Input.Sound` の欄 `admitsR` の内容）。 -/
theorem BuiltinInput.admitsRDec_sound (b : BuiltinInput) (B : Benitoite.Release.Refinement.Builtins) :
    ∀ n rs, AdmitsEntry.admitsRDec b.admitsR n rs = true →
      (b.withTableData B).admitsR n (rs.map Benitoite.Release.Refinement.RangeExpr.absolute) :=
  fun _ rs h => ⟨rs, rfl, AdmitsEntry.admitsRDec_sound h⟩

end Benitoite.Exchange
