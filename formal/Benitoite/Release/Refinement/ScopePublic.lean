import Benitoite.Release.Refinement.Types

/-! # At の診断の公開形

At の失敗の診断の公開形（`Scope.ScopeError.At(Scope.AtDetail)` と、九欄が読む19の公開の data と record）を、
構成子の名前・欄の型・内部の値からの写しで定める（設計書 07-04「篩を含む形式化の範囲」）。
公開の値は、文字列・整数・バイト列・列・Option・構成子だけからなる有限の木で表す。
内部の値からの写しは、内部の型の構成子ごとに公開の構成子へ写し、列の要素と並びを保つ。整数の欄は
Integer の上端に飽和する。公開の構成子を持たない内部の値（`AtFailure.outsideScope`）と、写し方を
呼び出し側が渡す元の入力は `Option` で受け、写せないときは `none` を返す。 -/
namespace Benitoite.Release.Refinement.ScopePublic
open Scope.Domain

/-- 公開の欄の型。名前の data は型引数を持たない。 -/
inductive PublicTy where
  | string
  | integer
  | bytes
  | list (element : PublicTy)
  | option (element : PublicTy)
  | data (name : DataName)
  deriving DecidableEq

/-- 公開の欄の型の核の型。Option は標準の `Option` の宣言を読む。 -/
def PublicTy.ty : PublicTy → Ty
  | .string => .base .string
  | .integer => .base .integer
  | .bytes => .bytes
  | .list a => .list a.ty
  | .option a => .data "Option" [a.ty]
  | .data d => .data d []

/-- 公開の値の有限の木。構成子は型引数を持たず、Option だけが要素の型を持つ。 -/
inductive PublicTree where
  | text (value : String)
  | integer (value : Integer64Value)
  | bytes (values : List Nat)
  | list (element : PublicTy) (items : List PublicTree)
  | none (element : PublicTy)
  | some (element : PublicTy) (value : PublicTree)
  | con (constructor : ConName) (args : List PublicTree)

mutual
  /-- 公開の値の観測。各欄は欠けずに観測される。 -/
  def PublicTree.toTerm : PublicTree → Term
    | .text s => .string s
    | .integer n => .integer n.toInt
    | .bytes bs => .bytesValue bs
    | .list _ xs => .listValue (PublicTree.toTermSlots xs)
    | .none _ => .dataValue "Option.None" []
    | .some _ x => .dataValue "Option.Some" [Option.some x.toTerm]
    | .con c xs => .dataValue c (PublicTree.toTermSlots xs)
  def PublicTree.toTermSlots : List PublicTree → List (Option Term)
    | [] => []
    | x :: xs => Option.some x.toTerm :: PublicTree.toTermSlots xs
end

mutual
  /-- 公開の値の観測は自由変数を持たない。 -/
  theorem PublicTree.toTerm_varsIn (P : Nat → Prop) : ∀ t : PublicTree, t.toTerm.VarsIn P
    | .text _ | .integer _ | .bytes _ | .none _ => by simp [PublicTree.toTerm, Term.VarsIn, varsInSlots]
    | .list _ xs => PublicTree.toTermSlots_varsIn P xs
    | .some _ x => ⟨PublicTree.toTerm_varsIn P x, trivial⟩
    | .con _ xs => PublicTree.toTermSlots_varsIn P xs
  theorem PublicTree.toTermSlots_varsIn (P : Nat → Prop) :
      ∀ xs : List PublicTree, varsInSlots P (PublicTree.toTermSlots xs)
    | [] => trivial
    | x :: xs => ⟨PublicTree.toTerm_varsIn P x, PublicTree.toTermSlots_varsIn P xs⟩
end

mutual
  /-- 公開の値の観測は、項の束縛で変わらない。 -/
  theorem PublicTree.termBind_toTerm (ν : ObservationEnv) :
      ∀ t : PublicTree, termBind? ν t.toTerm = Option.some t.toTerm
    | .text _ | .integer _ | .bytes _ | .none _ => rfl
    | .list _ xs => by simp only [PublicTree.toTerm, termBind?, PublicTree.bindSlots_toTermSlots ν xs]
    | .some _ x => by
      simp only [PublicTree.toTerm, termBind?, bindSlots, slotBind, PublicTree.termBind_toTerm ν x]
    | .con _ xs => by simp only [PublicTree.toTerm, termBind?, PublicTree.bindSlots_toTermSlots ν xs]
  theorem PublicTree.bindSlots_toTermSlots (ν : ObservationEnv) :
      ∀ xs : List PublicTree, bindSlots ν (PublicTree.toTermSlots xs) = PublicTree.toTermSlots xs
    | [] => rfl
    | x :: xs => by
      simp only [PublicTree.toTermSlots, bindSlots, slotBind, PublicTree.termBind_toTerm ν x,
        PublicTree.bindSlots_toTermSlots ν xs]
end

/-! ## 公開の宣言 -/

/-- 型引数を持たない公開の data の宣言。record は data と同名の構成子を一つ持つ。 -/
structure PublicData where
  name : DataName
  constructors : List (ConName × List PublicTy)
  deriving DecidableEq

abbrev words : PublicTy := .list .string

def atDetailDecl : PublicData := ⟨"Scope.AtDetail", [("Scope.AtDetail",
  [.data "Scope.AtFailure", .data "Scope.AtInput", .data "Scope.AtInput",
   .option (.data "Scope.RangeExpression"), .option (.data "Scope.TargetInput"),
   .option (.list (.data "Scope.RangeAtom")), .option (.data "Scope.Target"),
   .option (.data "Scope.PathBase"), .option (.data "Scope.PathBase")])]⟩
def atInputDecl : PublicData := ⟨"Scope.AtInput",
  [("Scope.AtInput.Text", [.string]), ("Scope.AtInput.Pattern", [.data "Scope.RangeExpression"])]⟩
def pathBaseDecl : PublicData := ⟨"Scope.PathBase",
  [("Scope.PathBase.Root", []), ("Scope.PathBase.Cwd", []), ("Scope.PathBase.Home", []),
   ("Scope.PathBase.Work", []), ("Scope.PathBase.Tmp", [])]⟩
def atFailureDecl : PublicData := ⟨"Scope.AtFailure",
  [("Scope.AtFailure.Unbound", [.data "Scope.PathBase"]), ("Scope.AtFailure.SecretsUnbound", []),
   ("Scope.AtFailure.InvalidPattern", []), ("Scope.AtFailure.InvalidTarget", []),
   ("Scope.AtFailure.DynamicCondition", []), ("Scope.AtFailure.StaticIndex", [])]⟩
def rangeExpressionDecl : PublicData := ⟨"Scope.RangeExpression",
  [("Scope.RangeExpression.Absolute", [.data "Scope.RangeAtom"]),
   ("Scope.RangeExpression.Based", [.data "Scope.PathBase", .data "Scope.PathPattern"]),
   ("Scope.RangeExpression.Secrets", [])]⟩
def targetInputDecl : PublicData := ⟨"Scope.TargetInput",
  [("Scope.TargetInput.Absolute", [.data "Scope.Target"]),
   ("Scope.TargetInput.RelativePath", [words]), ("Scope.TargetInput.HomePath", [words])]⟩
def rangeAtomDecl : PublicData := ⟨"Scope.RangeAtom",
  [("Scope.RangeAtom.Top", []), ("Scope.RangeAtom.Path", [.data "Scope.PathPattern"]),
   ("Scope.RangeAtom.Host", [.data "Scope.HostPattern"]),
   ("Scope.RangeAtom.Endpoint", [.data "Scope.EndpointPattern"])]⟩
def targetDecl : PublicData := ⟨"Scope.Target",
  [("Scope.Target.Path", [words]), ("Scope.Target.Host", [.data "Scope.HostTarget"]),
   ("Scope.Target.Endpoint", [.data "Scope.Endpoint"])]⟩
def pathPatternDecl : PublicData := ⟨"Scope.PathPattern",
  [("Scope.PathPattern.Exact", [words]), ("Scope.PathPattern.Tree", [words])]⟩
def namePatternDecl : PublicData := ⟨"Scope.NamePattern",
  [("Scope.NamePattern.Exact", [words]), ("Scope.NamePattern.One", [words]),
   ("Scope.NamePattern.Many", [words])]⟩
def ipFamilyDecl : PublicData := ⟨"Scope.IPFamily", [("Scope.IPFamily.V4", []), ("Scope.IPFamily.V6", [])]⟩
def ipAddressDecl : PublicData := ⟨"Scope.IPAddress", [("Scope.IPAddress", [.data "Scope.IPFamily", .bytes])]⟩
def cidrDecl : PublicData := ⟨"Scope.CIDR", [("Scope.CIDR", [.data "Scope.IPFamily", .bytes, .integer])]⟩
def ipPatternDecl : PublicData := ⟨"Scope.IPPattern",
  [("Scope.IPPattern.Exact", [.data "Scope.IPAddress"]), ("Scope.IPPattern.CIDR", [.data "Scope.CIDR"])]⟩
def hostTargetDecl : PublicData := ⟨"Scope.HostTarget",
  [("Scope.HostTarget.Name", [words]), ("Scope.HostTarget.IP", [.data "Scope.IPAddress"])]⟩
def hostPatternDecl : PublicData := ⟨"Scope.HostPattern",
  [("Scope.HostPattern.Name", [.data "Scope.NamePattern"]), ("Scope.HostPattern.IP", [.data "Scope.IPPattern"])]⟩
def portRangeDecl : PublicData := ⟨"Scope.PortRange", [("Scope.PortRange", [.integer, .integer])]⟩
def endpointDecl : PublicData := ⟨"Scope.Endpoint", [("Scope.Endpoint", [.data "Scope.HostTarget", .integer])]⟩
def endpointPatternDecl : PublicData := ⟨"Scope.EndpointPattern",
  [("Scope.EndpointPattern", [.data "Scope.HostPattern", .data "Scope.PortRange"])]⟩

/-- 新しく公開する19の data と record。 -/
def declarations : List PublicData :=
  [atDetailDecl, atInputDecl, pathBaseDecl, atFailureDecl, rangeExpressionDecl, targetInputDecl,
   rangeAtomDecl, targetDecl, pathPatternDecl, namePatternDecl, ipFamilyDecl, ipAddressDecl, cidrDecl,
   ipPatternDecl, hostTargetDecl, hostPatternDecl, portRangeDecl, endpointDecl, endpointPatternDecl]

/-- 既存の6構成子を保ち、At の詳細を一つの欄で持つ ScopeError の公開の宣言。 -/
def scopeErrorDecl : PublicData := ⟨"Scope.ScopeError",
  [("Scope.ScopeError.InvalidPattern", [.string, .string]),
   ("Scope.ScopeError.InvalidTarget", [.string, .string]),
   ("Scope.ScopeError.InvalidPortRange", [.integer, .integer]),
   ("Scope.ScopeError.InvalidPort", [.integer]),
   ("Scope.ScopeError.OutsideScope", [.string, .string]),
   ("Scope.ScopeError.PortOutsideScope", [.integer, .integer, .integer]),
   ("Scope.ScopeError.At", [.data "Scope.AtDetail"])]⟩

/-- 公開の宣言の全体。 -/
def all : List PublicData := declarations ++ [scopeErrorDecl]

/-- 公開の構成子の表。 -/
def constructors : List (ConName × DataName × List PublicTy) :=
  all.flatMap fun d => d.constructors.map fun c => (c.1, d.name, c.2)

def lookup (c : ConName) : Option (DataName × List PublicTy) := constructors.lookup c

/-- 新しい公開型は19、構成子は合わせて52（ScopeError の7を含む）。データ名と構成子名は重ならない。 -/
theorem declarations_shape :
    declarations.length = 19 ∧ constructors.length = 52 ∧
    (all.map PublicData.name).Nodup ∧ (constructors.map Prod.fst).Nodup := by
  decide

/-- 欄の型が読むデータ名。 -/
def PublicTy.names : PublicTy → List DataName
  | .string | .integer | .bytes => []
  | .list a | .option a => a.names
  | .data d => [d]

/-- 欄が読む名前の data は、すべて公開の宣言にある。 -/
theorem fields_declared :
    ∀ c ∈ constructors, ∀ a ∈ c.2.2, ∀ d ∈ a.names, d ∈ all.map PublicData.name := by
  decide

/-- 欄の型が読むデータ名がすべて公開の宣言にある。 -/
def PublicTy.Known (a : PublicTy) : Prop := ∀ d ∈ a.names, d ∈ all.map PublicData.name

instance (a : PublicTy) : Decidable a.Known := by unfold PublicTy.Known; infer_instance

/-! ## 型付き木 -/

mutual
  /-- 公開の値の木が、公開の宣言の欄の型に合う。 -/
  inductive PublicTree.Typed : PublicTree → PublicTy → Prop where
    | text (s : String) : PublicTree.Typed (.text s) .string
    | integer (n : Integer64Value) : PublicTree.Typed (.integer n) .integer
    | bytes {bs : List Nat} : (∀ b ∈ bs, b ≤ 255) → PublicTree.Typed (.bytes bs) .bytes
    | list {a : PublicTy} {xs : List PublicTree} : a.Known → PublicTree.TypedEach xs a →
        PublicTree.Typed (.list a xs) (.list a)
    | none {a : PublicTy} : a.Known → PublicTree.Typed (.none a) (.option a)
    | some {a : PublicTy} {x : PublicTree} : a.Known → PublicTree.Typed x a →
        PublicTree.Typed (.some a x) (.option a)
    | con {c : ConName} {d : DataName} {as : List PublicTy} {xs : List PublicTree} :
        lookup c = Option.some (d, as) → PublicTree.TypedAll xs as → PublicTree.Typed (.con c xs) (.data d)
  inductive PublicTree.TypedAll : List PublicTree → List PublicTy → Prop where
    | nil : PublicTree.TypedAll [] []
    | cons {x : PublicTree} {xs : List PublicTree} {a : PublicTy} {as : List PublicTy} :
        PublicTree.Typed x a → PublicTree.TypedAll xs as → PublicTree.TypedAll (x :: xs) (a :: as)
  inductive PublicTree.TypedEach : List PublicTree → PublicTy → Prop where
    | nil {a : PublicTy} : PublicTree.TypedEach [] a
    | cons {x : PublicTree} {xs : List PublicTree} {a : PublicTy} :
        PublicTree.Typed x a → PublicTree.TypedEach xs a → PublicTree.TypedEach (x :: xs) a
end

/-! ## 内部の値からの写し -/

/-- 整数の欄。ポートと接頭辞の長さは Integer の範囲に収まり、範囲を超える自然数は上端に飽和する。 -/
def natural (n : Nat) : Integer64Value :=
  ⟨min (n : Int) Benitoite.Release.max64, by
    unfold Benitoite.Release.min64 Benitoite.Release.max64; omega⟩

theorem natural_exact {n : Nat} (h : (n : Int) ≤ Benitoite.Release.max64) : (natural n).toInt = n := by
  simp only [natural, Integer64Value.toInt]; omega

def textList (w : Word) : PublicTree := .list .string (w.map .text)
/-- 網のバイト順の `count` バイト。 -/
def networkBytes (count n : Nat) : List Nat := (List.range count).reverse.map fun i => n / 256 ^ i % 256

def pathBaseTree : PathBase → PublicTree
  | .root => .con "Scope.PathBase.Root" [] | .cwd => .con "Scope.PathBase.Cwd" []
  | .home => .con "Scope.PathBase.Home" [] | .work => .con "Scope.PathBase.Work" []
  | .tmp => .con "Scope.PathBase.Tmp" []
def pathPatternTree : PathPattern → PublicTree
  | .exact w => .con "Scope.PathPattern.Exact" [textList w]
  | .tree w => .con "Scope.PathPattern.Tree" [textList w]
def namePatternTree : NamePattern → PublicTree
  | .exact w => .con "Scope.NamePattern.Exact" [textList w]
  | .one w => .con "Scope.NamePattern.One" [textList w]
  | .many w => .con "Scope.NamePattern.Many" [textList w]
def familyTree : Family → PublicTree
  | .v4 => .con "Scope.IPFamily.V4" [] | .v6 => .con "Scope.IPFamily.V6" []
def ipAddressTree (a : IPAddr) : PublicTree :=
  .con "Scope.IPAddress" [familyTree a.family, .bytes (networkBytes (a.family.width / 8) a.bits.val)]
def cidrTree (c : CIDR) : PublicTree :=
  .con "Scope.CIDR" [familyTree c.family, .bytes (networkBytes (c.family.width / 8) c.network.val),
    .integer (natural c.prefixLen)]
def ipPatternTree : IPPattern → PublicTree
  | .exact a => .con "Scope.IPPattern.Exact" [ipAddressTree a]
  | .cidr c => .con "Scope.IPPattern.CIDR" [cidrTree c]
def hostTargetTree : HostTarget → PublicTree
  | .name w => .con "Scope.HostTarget.Name" [textList w]
  | .ip a => .con "Scope.HostTarget.IP" [ipAddressTree a]
def hostPatternTree : HostPattern → PublicTree
  | .name p => .con "Scope.HostPattern.Name" [namePatternTree p]
  | .ip p => .con "Scope.HostPattern.IP" [ipPatternTree p]
def portRangeTree (r : PortRange) : PublicTree :=
  .con "Scope.PortRange" [.integer (natural r.lo.val), .integer (natural r.hi.val)]
def endpointTree (e : Endpoint) : PublicTree :=
  .con "Scope.Endpoint" [hostTargetTree e.host, .integer (natural e.port.val)]
def endpointPatternTree (e : EndpointPattern) : PublicTree :=
  .con "Scope.EndpointPattern" [hostPatternTree e.host, portRangeTree e.ports]
def rangeAtomTree : Range → PublicTree
  | .top => .con "Scope.RangeAtom.Top" []
  | .path p => .con "Scope.RangeAtom.Path" [pathPatternTree p]
  | .host p => .con "Scope.RangeAtom.Host" [hostPatternTree p]
  | .endpoint p => .con "Scope.RangeAtom.Endpoint" [endpointPatternTree p]
def targetTree : Target → PublicTree
  | .path w => .con "Scope.Target.Path" [textList w]
  | .host h => .con "Scope.Target.Host" [hostTargetTree h]
  | .endpoint e => .con "Scope.Target.Endpoint" [endpointTree e]
def rangeExpressionTree : RangeExpr → PublicTree
  | .absolute r => .con "Scope.RangeExpression.Absolute" [rangeAtomTree r]
  | .based b p => .con "Scope.RangeExpression.Based" [pathBaseTree b, pathPatternTree p]
  | .secrets => .con "Scope.RangeExpression.Secrets" []
def targetInputTree : TargetInput → PublicTree
  | .absolute t => .con "Scope.TargetInput.Absolute" [targetTree t]
  | .relativePath w => .con "Scope.TargetInput.RelativePath" [textList w]
  | .homePath w => .con "Scope.TargetInput.HomePath" [textList w]

/-- 失敗の種別。返す枝のない `outsideScope` は公開の構成子を持たない。 -/
def atFailureTree? : AtFailure → Option PublicTree
  | .outsideScope => Option.none
  | .unbound b => Option.some (.con "Scope.AtFailure.Unbound" [pathBaseTree b])
  | .secretsUnbound => Option.some (.con "Scope.AtFailure.SecretsUnbound" [])
  | .invalidPattern => Option.some (.con "Scope.AtFailure.InvalidPattern" [])
  | .invalidTarget => Option.some (.con "Scope.AtFailure.InvalidTarget" [])
  | .dynamicCondition => Option.some (.con "Scope.AtFailure.DynamicCondition" [])
  | .staticIndex => Option.some (.con "Scope.AtFailure.StaticIndex" [])

def optionTree (a : PublicTy) {α : Type} (f : α → PublicTree) : Option α → PublicTree
  | Option.none => .none a
  | Option.some x => .some a (f x)

/-- 元の入力の公開形。文字列は Text、解析済みの pattern は Pattern へ写す。 -/
def inputText (s : String) : PublicTree := .con "Scope.AtInput.Text" [.text s]
def inputPattern (r : RangeExpr) : PublicTree := .con "Scope.AtInput.Pattern" [rangeExpressionTree r]

/-- 九欄の公開形。元の入力の写し方は呼び出し側が渡す。 -/
def detailTree? {Raw : Type} (input : Raw → Option PublicTree) (d : Detail Raw) : Option PublicTree := do
  let failure ← atFailureTree? d.failure
  let pattern ← input d.originalPattern
  let target ← input d.originalTarget
  pure (.con "Scope.AtDetail" [failure, pattern, target,
    optionTree (.data "Scope.RangeExpression") rangeExpressionTree d.parsedPattern,
    optionTree (.data "Scope.TargetInput") targetInputTree d.parsedTarget,
    optionTree (.list (.data "Scope.RangeAtom")) (fun rs => .list (.data "Scope.RangeAtom") (rs.map rangeAtomTree))
      d.resolvedPatterns,
    optionTree (.data "Scope.Target") targetTree d.resolvedTarget,
    optionTree (.data "Scope.PathBase") pathBaseTree d.patternBase,
    optionTree (.data "Scope.PathBase") pathBaseTree d.targetBase])

/-- 公開形を持たない診断の観測に使う固定の値。準備と検査の失敗は、公開の入口ではこの値にならない
（`ScopePublic.prepare_public`・`ScopePublic.check_public`）。 -/
def unreachableTree : PublicTree :=
  .con "Scope.AtDetail" [.con "Scope.AtFailure.InvalidTarget" [], inputText "", inputText "",
    .none (.data "Scope.RangeExpression"), .none (.data "Scope.TargetInput"),
    .none (.list (.data "Scope.RangeAtom")), .none (.data "Scope.Target"),
    .none (.data "Scope.PathBase"), .none (.data "Scope.PathBase")]

/-! ## 写しの型付け -/

section
open PublicTree

private theorem textList_typed (w : Word) : Typed (textList w) words := by
  refine .list (by decide) ?_
  induction w with
  | nil => exact .nil
  | cons s w ih => exact .cons (.text s) ih

private theorem networkBytes_bound (count n : Nat) : ∀ b ∈ networkBytes count n, b ≤ 255 := by
  intro b hb
  simp only [networkBytes, List.mem_map] at hb
  obtain ⟨i, _, rfl⟩ := hb
  have := Nat.mod_lt (n / 256 ^ i) (by decide : 0 < 256)
  omega

theorem pathBase_typed (b : PathBase) : Typed (pathBaseTree b) (.data "Scope.PathBase") := by
  cases b <;> exact .con rfl .nil
theorem pathPattern_typed (p : PathPattern) : Typed (pathPatternTree p) (.data "Scope.PathPattern") := by
  cases p <;> exact .con rfl (.cons (textList_typed _) .nil)
theorem namePattern_typed (p : NamePattern) : Typed (namePatternTree p) (.data "Scope.NamePattern") := by
  cases p <;> exact .con rfl (.cons (textList_typed _) .nil)
theorem family_typed (f : Family) : Typed (familyTree f) (.data "Scope.IPFamily") := by
  cases f <;> exact .con rfl .nil
theorem ipAddress_typed (a : IPAddr) : Typed (ipAddressTree a) (.data "Scope.IPAddress") :=
  .con rfl (.cons (family_typed _) (.cons (.bytes (networkBytes_bound _ _)) .nil))
theorem cidr_typed (c : CIDR) : Typed (cidrTree c) (.data "Scope.CIDR") :=
  .con rfl (.cons (family_typed _) (.cons (.bytes (networkBytes_bound _ _)) (.cons (.integer _) .nil)))
theorem ipPattern_typed (p : IPPattern) : Typed (ipPatternTree p) (.data "Scope.IPPattern") := by
  cases p
  · exact .con rfl (.cons (ipAddress_typed _) .nil)
  · exact .con rfl (.cons (cidr_typed _) .nil)
theorem hostTarget_typed (h : HostTarget) : Typed (hostTargetTree h) (.data "Scope.HostTarget") := by
  cases h
  · exact .con rfl (.cons (textList_typed _) .nil)
  · exact .con rfl (.cons (ipAddress_typed _) .nil)
theorem hostPattern_typed (h : HostPattern) : Typed (hostPatternTree h) (.data "Scope.HostPattern") := by
  cases h
  · exact .con rfl (.cons (namePattern_typed _) .nil)
  · exact .con rfl (.cons (ipPattern_typed _) .nil)
theorem portRange_typed (r : PortRange) : Typed (portRangeTree r) (.data "Scope.PortRange") :=
  .con rfl (.cons (.integer _) (.cons (.integer _) .nil))
theorem endpoint_typed (e : Endpoint) : Typed (endpointTree e) (.data "Scope.Endpoint") :=
  .con rfl (.cons (hostTarget_typed _) (.cons (.integer _) .nil))
theorem endpointPattern_typed (e : EndpointPattern) :
    Typed (endpointPatternTree e) (.data "Scope.EndpointPattern") :=
  .con rfl (.cons (hostPattern_typed _) (.cons (portRange_typed _) .nil))
theorem rangeAtom_typed (r : Range) : Typed (rangeAtomTree r) (.data "Scope.RangeAtom") := by
  cases r
  · exact .con rfl .nil
  · exact .con rfl (.cons (pathPattern_typed _) .nil)
  · exact .con rfl (.cons (hostPattern_typed _) .nil)
  · exact .con rfl (.cons (endpointPattern_typed _) .nil)
theorem target_typed (t : Target) : Typed (targetTree t) (.data "Scope.Target") := by
  cases t
  · exact .con rfl (.cons (textList_typed _) .nil)
  · exact .con rfl (.cons (hostTarget_typed _) .nil)
  · exact .con rfl (.cons (endpoint_typed _) .nil)
theorem rangeExpression_typed (r : RangeExpr) :
    Typed (rangeExpressionTree r) (.data "Scope.RangeExpression") := by
  cases r
  · exact .con rfl (.cons (rangeAtom_typed _) .nil)
  · exact .con rfl (.cons (pathBase_typed _) (.cons (pathPattern_typed _) .nil))
  · exact .con rfl .nil
theorem targetInput_typed (t : TargetInput) : Typed (targetInputTree t) (.data "Scope.TargetInput") := by
  cases t
  · exact .con rfl (.cons (target_typed _) .nil)
  · exact .con rfl (.cons (textList_typed _) .nil)
  · exact .con rfl (.cons (textList_typed _) .nil)
theorem atFailure_typed {f : AtFailure} {t : PublicTree} (h : atFailureTree? f = Option.some t) :
    Typed t (.data "Scope.AtFailure") := by
  cases f <;> cases h
  all_goals first | exact .con rfl .nil | exact .con rfl (.cons (pathBase_typed _) .nil)
theorem inputText_typed (s : String) : Typed (inputText s) (.data "Scope.AtInput") :=
  .con rfl (.cons (.text s) .nil)
theorem inputPattern_typed (r : RangeExpr) : Typed (inputPattern r) (.data "Scope.AtInput") :=
  .con rfl (.cons (rangeExpression_typed r) .nil)

private theorem optionTree_typed {α : Type} {a : PublicTy} {f : α → PublicTree} (ha : a.Known)
    (hf : ∀ x, Typed (f x) a) (o : Option α) : Typed (optionTree a f o) (.option a) := by
  cases o
  · exact .none ha
  · exact .some ha (hf _)

private theorem ranges_typed (rs : List Range) :
    Typed (.list (.data "Scope.RangeAtom") (rs.map rangeAtomTree)) (.list (.data "Scope.RangeAtom")) := by
  refine .list (by decide) ?_
  induction rs with
  | nil => exact .nil
  | cons r rs ih => exact .cons (rangeAtom_typed r) ih

/-- 元の入力が AtInput へ写るとき、九欄の公開形は AtDetail の型を持つ。 -/
theorem detail_typed {Raw : Type} {input : Raw → Option PublicTree} {d : Detail Raw} {t : PublicTree}
    (hi : ∀ r u, input r = Option.some u → Typed u (.data "Scope.AtInput"))
    (h : detailTree? input d = Option.some t) : Typed t (.data "Scope.AtDetail") := by
  simp only [detailTree?, Option.bind_eq_bind, Option.bind_eq_some_iff, Option.pure_def,
    Option.some.injEq] at h
  obtain ⟨failure, hf, pattern, hp, target, ht, rfl⟩ := h
  exact .con rfl (.cons (atFailure_typed hf) (.cons (hi _ _ hp) (.cons (hi _ _ ht)
    (.cons (optionTree_typed (by decide) rangeExpression_typed _)
    (.cons (optionTree_typed (by decide) targetInput_typed _)
    (.cons (optionTree_typed (by decide) ranges_typed _) (.cons (optionTree_typed (by decide) target_typed _)
    (.cons (optionTree_typed (by decide) pathBase_typed _)
    (.cons (optionTree_typed (by decide) pathBase_typed _) .nil)))))))))

theorem unreachable_typed : Typed unreachableTree (.data "Scope.AtDetail") :=
  .con rfl (.cons (.con rfl .nil) (.cons (inputText_typed "") (.cons (inputText_typed "")
    (.cons (.none (by decide)) (.cons (.none (by decide)) (.cons (.none (by decide)) (.cons (.none (by decide))
    (.cons (.none (by decide)) (.cons (.none (by decide)) .nil)))))))))

/-- 公開の構成子を持たないのは `outsideScope` だけである。 -/
theorem atFailure_public (f : AtFailure) : (atFailureTree? f).isSome ↔ f ≠ .outsideScope := by
  cases f <;> simp [atFailureTree?]

/-- 元の入力の写しがあり、失敗の種別が公開の構成子を持つとき、九欄の公開形がある。 -/
theorem detail_public {Raw : Type} {input : Raw → Option PublicTree} {d : Detail Raw}
    (hf : d.failure ≠ .outsideScope) (hp : (input d.originalPattern).isSome)
    (ht : (input d.originalTarget).isSome) : (detailTree? input d).isSome := by
  obtain ⟨f, ef⟩ := Option.isSome_iff_exists.mp ((atFailure_public _).mpr hf)
  obtain ⟨p, ep⟩ := Option.isSome_iff_exists.mp hp
  obtain ⟨t, et⟩ := Option.isSome_iff_exists.mp ht
  simp [detailTree?, ef, ep, et]

end

/-! ## 内部名と公開名の対応 -/

/-- 内部の Lean の名前と公開の綴り。公開名は既存の公開名と同じく語を省略しない。左が内部、右が公開。 -/
def names : List (String × String) :=
  [("Detail", "Scope.AtDetail"), ("Detail.originalPattern : Val", "Scope.AtInput"),
   ("PathBase", "Scope.PathBase"), ("AtFailure", "Scope.AtFailure"),
   ("RangeExpr", "Scope.RangeExpression"), ("TargetInput", "Scope.TargetInput"),
   ("Scope.Domain.Range", "Scope.RangeAtom"), ("Scope.Domain.Target", "Scope.Target"),
   ("Scope.Domain.PathPattern", "Scope.PathPattern"), ("Scope.Domain.NamePattern", "Scope.NamePattern"),
   ("Scope.Domain.Family", "Scope.IPFamily"), ("Scope.Domain.IPAddr", "Scope.IPAddress"),
   ("Scope.Domain.CIDR", "Scope.CIDR"), ("Scope.Domain.IPPattern", "Scope.IPPattern"),
   ("Scope.Domain.HostTarget", "Scope.HostTarget"), ("Scope.Domain.HostPattern", "Scope.HostPattern"),
   ("Scope.Domain.PortRange", "Scope.PortRange"), ("Scope.Domain.Endpoint", "Scope.Endpoint"),
   ("Scope.Domain.EndpointPattern", "Scope.EndpointPattern")]

/-- 公開の record の欄の名前。宣言の構成子の欄と同じ順である。 -/
def recordFields : List (DataName × List String) :=
  [("Scope.AtDetail", ["failure", "originalPattern", "originalTarget", "parsedPattern", "parsedTarget",
     "resolvedPatterns", "resolvedTarget", "patternBase", "targetBase"]),
   ("Scope.IPAddress", ["family", "bytes"]), ("Scope.CIDR", ["family", "network", "prefixLength"]),
   ("Scope.PortRange", ["minimum", "maximum"]), ("Scope.Endpoint", ["host", "port"]),
   ("Scope.EndpointPattern", ["host", "ports"])]

/-- record は data と同名の構成子を一つだけ持ち、欄の名前の数はその構成子の欄の数に等しい。 -/
theorem record_fields :
    ∀ r ∈ recordFields, ∃ D ∈ declarations, D.name = r.1 ∧
      D.constructors.map Prod.fst = [r.1] ∧ D.constructors.map (·.2.length) = [r.2.length] := by
  decide

/-- 名前を改めた欄。内部の欄（左）と、公開の record と欄の名前（右）。 -/
def fieldNames : List (String × DataName × String) :=
  [("CIDR.prefixLen", "Scope.CIDR", "prefixLength"), ("CIDR.network", "Scope.CIDR", "network"),
   ("IPAddr.bits", "Scope.IPAddress", "bytes"),
   ("PortRange.lo", "Scope.PortRange", "minimum"), ("PortRange.hi", "Scope.PortRange", "maximum")]

/-- 名前を改めた欄は、公開の record の欄にある。 -/
theorem field_names : ∀ f ∈ fieldNames, ∃ r ∈ recordFields, r.1 = f.2.1 ∧ f.2.2 ∈ r.2 := by
  decide

/-- 起点の構成子と、パス変数の綴り `{root}`・`{cwd}`・`{home}`・`{work}`・`{tmp}`。 -/
def pathBaseNames : PathBase → String × String
  | .root => ("Scope.PathBase.Root", "{root}") | .cwd => ("Scope.PathBase.Cwd", "{cwd}")
  | .home => ("Scope.PathBase.Home", "{home}") | .work => ("Scope.PathBase.Work", "{work}")
  | .tmp => ("Scope.PathBase.Tmp", "{tmp}")

/-- 対応の右辺は19の公開型の名前と同じ並びであり、五つの起点はそれぞれの公開の構成子へ写る。 -/
theorem names_cover :
    names.map Prod.snd = declarations.map PublicData.name ∧
    ∀ b : PathBase, pathBaseTree b = .con (pathBaseNames b).1 [] := by
  refine ⟨rfl, ?_⟩
  intro b; cases b <;> rfl

/-- 起点の構成子の綴りは、公開の PathBase の宣言の構成子の並びと同じである。 -/
theorem pathBase_names :
    [PathBase.root, .cwd, .home, .work, .tmp].map (fun b => (pathBaseNames b).1) =
      pathBaseDecl.constructors.map Prod.fst := rfl

end Benitoite.Release.Refinement.ScopePublic
