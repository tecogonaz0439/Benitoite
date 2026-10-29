import Benitoite.Exchange.Version
import Benitoite.Surface.CheckTables

namespace Benitoite.Exchange
open Lean

/-- Fail は名前の原子と区別し、支持はエラー型の内部まで収集する。範囲の位置はそのまま写す（旧版の入力は読み込みの前に
明示の Top を持つ。`Exchange/Range.lean` の `legacyRangeNode`）。 -/
def Atom.toRelease : Atom → Option Benitoite.Release.Atom
  | .name s ix => some (.name s ix)
  | .rho i => some (.rho i)
  | .fail _ => none

/-- Release の名前の原子と行の原子を交換の原子にする（`Atom.toRelease` の逆）。 -/
def fromAtom : Benitoite.Release.Atom → Atom
  | .name s ix => .name s ix
  | .rho i => .rho i

@[simp] theorem Atom.toRelease_fromAtom (a : Benitoite.Release.Atom) : (fromAtom a).toRelease = some a := by
  cases a <;> rfl

/-- Release の原子の列を交換の原子にして読み戻すと元の列になる。 -/
theorem filterMap_toRelease_fromAtom (l : List Benitoite.Release.Atom) :
    (l.map fromAtom).filterMap Atom.toRelease = l := by
  induction l with
  | nil => rfl
  | cons a l ih => simp [ih]

/-- 範囲が Top の名前の原子は、Release の Top の構築関数 `Atom.nameTop` に写る（Top の対応）。 -/
theorem Atom.toRelease_top (s : String) :
    (Atom.name s Scope.Signature.Ix.top).toRelease = some (.nameTop s) := rfl

/-- 旧版の名前の原子の読み込み（明示の Top を加えてから読む）は、Release の Top の構築関数に写る（旧版の Top の対応）。 -/
theorem legacy_atom_toRelease (l : String) :
    (((legacyRangeNode (legacyNameAtomJson l)).getObjVal? "name" >>= decodeNameBody).map
      (fun p => (Atom.name p.1 p.2).toRelease)) = .ok (some (.nameTop l)) := by
  rw [legacy_name_atom_top]; rfl

/-- 不透明型の葉の変換。範囲の位置をそのまま写す。 -/
def opaqueToRelease (n : String) (ix : Scope.Signature.Ix) : Benitoite.Release.Ty := .opaque n ix

/-- 旧版の不透明型の読み込みは、Release の Top の構築関数 `Ty.opaqueTop` に写る（旧版の Top の対応）。 -/
theorem legacy_opaque_toRelease (n : String) :
    (((legacyRangeNode (legacyOpaqueJson n)).getObjVal? "opaque" >>= decodeOpaqueBody).map
      (fun p => opaqueToRelease p.1 p.2)) = .ok (.opaqueTop n) := by
  rw [legacy_opaque_top]; rfl

partial def collectAtoms : Json → Eff
  | .arr xs => xs.toList.flatMap collectAtoms
  | j@(.obj xs) => match (fromJson? j : Except String Atom) with
      | .ok (.name n ix) => [.name n ix]
      | .ok (.rho i) => [.rho i]
      | _ => xs.toArray.toList.flatMap (fun (_, v) => collectAtoms v)
  | _ => []

/-- JSON の組み込みの呼び出し（`prim`・`primName`）の名前と範囲の列を集める。範囲の列を持たない同名の欄
（節の操作の参照 `OpRef.prim`）は呼び出しでないので数えない。 -/
partial def collectPrimRanges : Json → List (String × List Scope.Domain.Range)
  | .arr xs => xs.toList.flatMap collectPrimRanges
  | j@(.obj xs) =>
      let own := ["prim", "primName"].filterMap fun tag => (do
        let o ← j.getObjVal? tag
        let n ← o.getObjValAs? String "name"
        let rs ← decodeRanges (← o.getObjVal? "ranges")
        pure (n, rs) : Except String _).toOption
      own ++ xs.toArray.toList.flatMap (fun (_, v) => collectPrimRanges v)
  | _ => []

/-- 署名の原子の範囲の変数を、呼び出しの範囲の列で具体化した原子（`Ix.inst` と同じ。列の外の番号の変数は作らない）。 -/
def instAtoms (sig : Eff) (rs : List Scope.Domain.Range) : Eff :=
  sig.filterMap fun a => match a with
    | .name l (.rvar i) => rs[i]?.map fun r => .name l (.fixed r)
    | _ => none

def baseTy : String → Except String Benitoite.Release.BaseTy
  | "Integer" | "Integer64" => .ok .integer
  | "Float" | "Float64" => .ok .float
  | "String" => .ok .string | "Character" => .ok .character
  | "Boolean" => .ok .boolean | "Unit" => .ok .unit
  | "Byte" | "UnsignedInteger8" => .ok .byte
  | "Decimal" => .ok .decimal
  | "Integer8" => .ok .integer8 | "Integer16" => .ok .integer16
  | "Integer32" => .ok .integer32
  | "UnsignedInteger16" => .ok .unsignedInteger16
  | "UnsignedInteger32" => .ok .unsignedInteger32
  | "UnsignedInteger64" | "UnsignedInteger" => .ok .unsignedInteger64
  | "Float32" => .ok .float32
  | n => .error s!"unknown base type: {n}"

def baseName : Benitoite.Release.BaseTy → String
  | .integer => "Integer" | .float => "Float" | .string => "String"
  | .character => "Character" | .boolean => "Boolean" | .unit => "Unit"
  | .byte => "Byte" | .decimal => "Decimal"
  | .integer8 => "Integer8" | .integer16 => "Integer16" | .integer32 => "Integer32"
  | .unsignedInteger16 => "UnsignedInteger16" | .unsignedInteger32 => "UnsignedInteger32"
  | .unsignedInteger64 => "UnsignedInteger64" | .float32 => "Float32"

def TyCon.toRelease : TyCon → Benitoite.Release.TyCon
  | .data n => .data n | .list => .list | .set => .set | .map => .map
  | .reference => .reference | .lazyT => .lazy

def fromTyCon : Benitoite.Release.TyCon → TyCon
  | .data n => .data n | .list => .list | .set => .set | .map => .map
  | .reference => .reference | .lazy => .lazyT

/-- 並行する名前を補わず、宣言順と一意性を交換の境界で検査する。 -/
def checkNames (names : List String) (arity : Nat) : Except String Unit := do
  if names.length != arity || names.eraseDups != names then
    throw "invalid parameter names"

/-- 交換の効果の名前と行の原子の所属（Fail の原子は含めない）。 -/
def Eff.readAtoms (e : Eff) : Benitoite.Release.Atom → Bool :=
  fun a => (e.filterMap Atom.toRelease).contains a

/-- Fail のない交換の効果の読み込み（`Eff.toRelease` が Fail のない効果について返す値）。 -/
def Eff.namesToRelease (e : Eff) : Benitoite.Release.Eff := .mk (Eff.readAtoms e) []

mutual
  partial def Ty.toRelease : Ty → Except String Benitoite.Release.Ty
    | .base n => return .base (← baseTy n)
    | .opaque n ix => return opaqueToRelease n ix
    | .data n ts => return .data n (← ts.mapM Ty.toRelease)
    | .list t => return .list (← t.toRelease)
    | .fn names ps r e => do
        checkNames names ps.length
        return .fn names (← ps.mapM Ty.toRelease) (← r.toRelease) (← Eff.toRelease e)
    | .tvar i => return .tvar i
    | .reference t => return .reference (← t.toRelease)
    | .lazyT t => return .lazy (← t.toRelease)
    | .map k v => return .map (← k.toRelease) (← v.toRelease)
    | .set t => return .set (← t.toRelease)
    | .bytes => return .bytes
    | .dict cl t => return .dict cl (← t.toRelease)
    | .tapp i ts => return .tapp i (← ts.mapM Ty.toRelease)
    | .ctor h => return .ctor h.toRelease

  partial def Eff.toRelease (e : Eff) : Except String Benitoite.Release.Eff := do
    let atoms := (collectAtoms (toJson e)).filterMap Atom.toRelease
    let fails ← e.filterMap (fun a => match a with | .fail t => some t | _ => none) |>.mapM Ty.toRelease
    -- Fail のない効果は全域の `Eff.namesToRelease` と同じ値になる（`normWith` は空の Fail 列を変えない）。
    if fails.isEmpty then return Eff.namesToRelease e
    return Benitoite.Release.Eff.normWith atoms
      ⟨Eff.readAtoms e, fails⟩
end

/-- 効果 e が持つのに書き出しの一覧 `listed` にない原子を、候補 `univ` の中から探す（RV-L10 中2）。Release の効果は
原子の述語なので、候補の外の原子は調べられない。候補が効果の原子を全て含むとき（`Eff.Support (· ∈ univ) e`）、
`none` は効果の原子が全て一覧にあることを意味する（`unlistedAtom?_complete`）。 -/
def unlistedAtom? (univ listed : List Benitoite.Release.Atom) (e : Benitoite.Release.Eff) :
    Option Benitoite.Release.Atom :=
  univ.find? fun a => Benitoite.Release.Eff.test e a && !listed.contains a

theorem unlistedAtom?_eq_none {univ listed : List Benitoite.Release.Atom} {e : Benitoite.Release.Eff}
    (h : unlistedAtom? univ listed e = none) :
    ∀ a ∈ univ, Benitoite.Release.Eff.test e a = true → a ∈ listed := by
  intro a ha he
  have := List.find?_eq_none.mp h a ha
  simp only [he, Bool.true_and, Bool.not_eq_true'] at this
  simpa using this

/-- 候補が効果の原子を全て含み、一覧にない原子が見つからなければ、効果の原子は全て一覧にある（黙って落とす原子がない）。 -/
theorem unlistedAtom?_complete {univ listed : List Benitoite.Release.Atom} {e : Benitoite.Release.Eff}
    (hs : ∀ a, Benitoite.Release.Eff.test e a = true → a ∈ univ) (h : unlistedAtom? univ listed e = none) :
    ∀ a, Benitoite.Release.Eff.test e a = true → a ∈ listed :=
  fun a he => unlistedAtom?_eq_none h a (hs a he) he

/-- 名前と行の原子の書き出し。一覧 `atoms` の原子のうち所属 `f` が真のものを、原子の符号の順に重複なく並べる
（Rust に内部の符号順を要求せず、両辺を同じ読者で正規化する `normalizeEff` と同じ順）。 -/
def writeAtoms (atoms : Eff) (f : Benitoite.Release.Atom → Bool) : Eff :=
  let listed := (atoms.filterMap Atom.toRelease).filter f
  ((listed.mergeSort fun a b => decide (a.code ≤ b.code)).eraseDups).map fromAtom

/-- 効果の名前と行の原子の書き出し（Fail の列を除く）。候補 `univ` の中に、効果が持つのに一覧にない原子があれば
誤りにする（RV-L10 中2）。Release の効果は原子の述語なので、候補の外の原子は調べられない。候補が効果の原子を
全て含むとき（`unlistedAtom?_complete` の前提）、成功は効果の原子が全て一覧にあることを意味する。候補を作るのは
呼び出し側の義務であり、交換の入口は具体化した範囲と署名の表の原子まで含めた一覧を渡す（`exchangeAtoms`）。 -/
def fromEffNames (atoms : Eff) (e : Benitoite.Release.Eff)
    (univ : List Benitoite.Release.Atom := atoms.filterMap Atom.toRelease) : Except String Eff := do
  let listed := atoms.filterMap Atom.toRelease
  if let some a := unlistedAtom? (listed ++ univ) listed e then
    throw s!"effect atom is not in the exchange atom list: {repr a}"
  return writeAtoms atoms e.test

/-! ### 名前と行の原子の書き出しの性質

Release の効果は原子の述語なので、書き出しは一覧に相対的である。一覧が効果の原子を全て含むとき、書き出した
効果を読むと元の効果に戻る（`readAtoms_writeAtoms`）。範囲付きの原子も同じである。原子が全て Top の効果を
読んで書き戻すと、同じ効果を表し、Top の原子だけを持つ（`top_eff_roundtrip`。RV-L10 中2）。 -/

theorem mem_writeAtoms_iff (atoms : Eff) (f : Release.Atom → Bool) (a : Release.Atom) :
    a ∈ (writeAtoms atoms f).filterMap Exchange.Atom.toRelease ↔
      a ∈ atoms.filterMap Exchange.Atom.toRelease ∧ f a = true := by
  simp only [writeAtoms, List.filterMap_map]
  have : (Exchange.Atom.toRelease ∘ fromAtom) = some := funext Exchange.Atom.toRelease_fromAtom
  rw [this, List.filterMap_some, List.mem_eraseDups, List.mem_mergeSort, List.mem_filter]

/-- 一覧が所属 `f` の原子を全て含めば、書き出した原子の列を読むと `f` に戻る。 -/
theorem readAtoms_writeAtoms (atoms : Eff) (f : Release.Atom → Bool)
    (h : ∀ a, f a = true → a ∈ atoms.filterMap Exchange.Atom.toRelease) :
    Eff.readAtoms (writeAtoms atoms f) = f := by
  funext a
  apply Bool.eq_iff_iff.mpr
  simp only [Eff.readAtoms, List.contains_iff_mem, mem_writeAtoms_iff]
  exact ⟨fun h' => h'.2, fun h' => ⟨h a h', h'⟩⟩

/-- 書き出した形は、読んで書き戻しても同じ列になる（交換の形の上の往復）。 -/
theorem writeAtoms_readAtoms_writeAtoms (atoms : Eff) (f : Release.Atom → Bool)
    (h : ∀ a, f a = true → a ∈ atoms.filterMap Exchange.Atom.toRelease) :
    writeAtoms atoms (Eff.readAtoms (writeAtoms atoms f)) = writeAtoms atoms f := by
  rw [readAtoms_writeAtoms atoms f h]

/-- 一覧が効果の原子を全て含めば、名前と行の原子の書き出しは成功し、黙って落とす原子がない。 -/
theorem fromEffNames_ok {atoms : Eff} {e : Release.Eff} (univ : List Release.Atom)
    (h : ∀ a, Release.Eff.test e a = true → a ∈ atoms.filterMap Exchange.Atom.toRelease) :
    fromEffNames atoms e univ = .ok (writeAtoms atoms e.test) := by
  have hn : unlistedAtom? (atoms.filterMap Exchange.Atom.toRelease ++ univ)
      (atoms.filterMap Exchange.Atom.toRelease) e = none := by
    unfold unlistedAtom?
    apply List.find?_eq_none.mpr
    intro a _ ha
    simp only [Bool.and_eq_true, Bool.not_eq_true'] at ha
    have := h a ha.1
    simp [this] at ha
  simp only [fromEffNames, hn]; rfl

/-- 候補 `univ` の中に、効果が持つのに一覧にない原子があれば、書き出しは誤りになる（黙って落とさない）。 -/
theorem fromEffNames_error_of_unlisted {atoms : Eff} {e : Release.Eff} {univ : List Release.Atom} {a : Release.Atom}
    (ha : a ∈ univ) (he : Release.Eff.test e a = true) (hn : a ∉ atoms.filterMap Exchange.Atom.toRelease) :
    ∃ msg, fromEffNames atoms e univ = .error msg := by
  cases hu : unlistedAtom? (atoms.filterMap Exchange.Atom.toRelease ++ univ)
      (atoms.filterMap Exchange.Atom.toRelease) e with
  | some b => simp only [fromEffNames, hu]; exact ⟨_, rfl⟩
  | none =>
    have := unlistedAtom?_eq_none hu a (List.mem_append_right _ ha) he
    exact absurd this hn

/-- 検査器の不変条件の形 `Eff.AtomsIn univ e`（効果の原子が候補 `univ` にある）から、`unlistedAtom?_complete` の
前提が得られる。 -/
theorem support_of_atomsIn {univ : List Release.Atom} {e : Release.Eff} (he : Release.Eff.AtomsIn univ e) :
    ∀ a, Release.Eff.test e a = true → a ∈ univ :=
  ((Release.Eff.support_iff e).mp he).1

/-- 候補 `univ` が効果の原子を全て含むとき（検査器の `AtomsIn univ`）、書き出しが成功すれば、書き出した原子の列を
読むと元の効果の所属に戻る（黙った欠落がない）。 -/
theorem fromEffNames_complete_of_atomsIn {atoms : Eff} {e : Release.Eff} {univ : List Release.Atom} {xs : Eff}
    (he : Release.Eff.AtomsIn univ e) (h : fromEffNames atoms e univ = .ok xs) :
    Eff.readAtoms xs = e.test := by
  unfold fromEffNames at h
  cases hu : unlistedAtom? (atoms.filterMap Exchange.Atom.toRelease ++ univ)
      (atoms.filterMap Exchange.Atom.toRelease) e with
  | some b => simp [hu] at h; cases h
  | none =>
    simp only [hu] at h
    cases h
    apply readAtoms_writeAtoms
    exact unlistedAtom?_complete (fun a ha => List.mem_append_right _ (support_of_atomsIn he a ha)) hu

/-- 原子が Top の名前の原子か行の原子である（旧版の像。Fail は含めない）。 -/
def Atom.IsTop : Atom → Prop
  | .name _ ix => ix = Scope.Signature.Ix.top
  | .rho _ => True
  | .fail _ => False

/-- 原子が全て Top の交換の効果（旧版の入力の像）は、一覧にあれば、読んで書き戻すと成功し、書き戻した効果は
同じ効果を表し（`namesToRelease` が一致する）、Top の原子だけを持つ（RV-L10 中2）。 -/
theorem top_eff_roundtrip {atoms xs : Eff} (univ : List Release.Atom)
    (htop : ∀ x ∈ xs, Atom.IsTop x) (hin : ∀ x ∈ xs, x ∈ atoms) :
    ∃ ys, fromEffNames atoms (Eff.namesToRelease xs) univ = .ok ys ∧
      Eff.namesToRelease ys = Eff.namesToRelease xs ∧ ∀ y ∈ ys, Atom.IsTop y := by
  have hsupp : ∀ a, Release.Eff.test (Eff.namesToRelease xs) a = true →
      a ∈ atoms.filterMap Exchange.Atom.toRelease := by
    intro a ha
    simp only [Eff.namesToRelease, Release.Eff.test, Release.Eff.atoms, Eff.readAtoms,
      List.contains_iff_mem, List.mem_filterMap] at ha ⊢
    obtain ⟨x, hx, hxa⟩ := ha
    exact ⟨x, hin x hx, hxa⟩
  refine ⟨_, fromEffNames_ok univ hsupp, ?_, ?_⟩
  · exact congrArg (fun f => Release.EffR.mk f []) (readAtoms_writeAtoms atoms _ hsupp)
  · intro y hy
    simp only [writeAtoms, List.mem_map, List.mem_eraseDups, List.mem_mergeSort, List.mem_filter] at hy
    obtain ⟨a, ⟨_, ha⟩, rfl⟩ := hy
    simp only [Eff.namesToRelease, Release.Eff.test, Release.Eff.atoms, Eff.readAtoms,
      List.contains_iff_mem, List.mem_filterMap] at ha
    obtain ⟨x, hx, hxa⟩ := ha
    have ht := htop x hx
    cases x with
    | name l ix => simp only [Atom.toRelease, Option.some.injEq] at hxa; subst hxa; exact ht
    | rho i => simp only [Atom.toRelease, Option.some.injEq] at hxa; subst hxa; trivial
    | fail t => cases ht

mutual
  partial def fromTy (atoms : Eff) : Benitoite.Release.Ty → Except String Ty
    | .base t => return .base (baseName t)
    | .opaque n ix => return .opaque n ix
    | .data n ts => return .data n (← ts.mapM (fromTy atoms))
    | .list t => return .list (← fromTy atoms t)
    | .fn names ps r e => return .fn names (← ps.mapM (fromTy atoms)) (← fromTy atoms r) (← fromEff atoms e)
    | .tvar i => return .tvar i
    | .reference t => return .reference (← fromTy atoms t)
    | .lazy t => return .lazyT (← fromTy atoms t)
    | .map k v => return .map (← fromTy atoms k) (← fromTy atoms v)
    | .set t => return .set (← fromTy atoms t)
    | .bytes => return .bytes
    | .dict cl t => return .dict cl (← fromTy atoms t)
    | .tapp i ts => return .tapp i (← ts.mapM (fromTy atoms))
    | .ctor h => return .ctor (fromTyCon h)
    | _ => throw "unsupported Release type"

  /-- 効果を交換の原子の一覧 `atoms` で書き出す。名前と行の原子は `fromEffNames`（全域）が書き、一覧にない原子を
  候補 `univ` の中に持つ効果は黙って落とさず誤りにする（RV-L10 中2）。Fail の列はこの後に書く。 -/
  partial def fromEff (atoms : Eff) (e : Benitoite.Release.Eff)
      (univ : List Benitoite.Release.Atom := atoms.filterMap Atom.toRelease) : Except String Eff := do
    let names ← fromEffNames atoms e univ
    return names ++ (← e.fails.mapM (fun t => Atom.fail <$> fromTy atoms t))
end

/-- 両辺を同じ Lean の読者で正規化する。Rust に内部の符号順を要求しない。 -/
def normalizeEff (e : Eff) : Except String Eff := do
  fromEff (collectAtoms (toJson e)) (← e.toRelease)

/-- 比較では各エフェクトの列自体を正規化し、支持の一覧で要素を切り捨てない。
基本型の別名も揃えるが、契約名・引数・節などの並びは保つ。 -/
partial def canonicalJson : Json → Json
  | .arr xs =>
      match (xs.toList.mapM (fromJson? · : Json → Except String Atom)) with
      | .ok es => match normalizeEff es with
          | .ok normalized => toJson normalized
          | .error _ => .arr (xs.map canonicalJson)
      | .error _ => .arr (xs.map canonicalJson)
  | j@(.obj xs) =>
      match (j.getObjVal? "base").bind (fun b => b.getObjValAs? String "name") with
      | .ok n => match baseTy n with
          | .ok t => toJson (Ty.base (baseName t))
          | .error _ => j
      | _ => Json.mkObj (xs.toArray.toList.map (fun (k, v) => (k, canonicalJson v)))
  | j => j

/-! 契約名とソース順を保持する独立した交換の入口。
設計書 07-04「証明する性質」の検査対象と既存形式を区別する。 -/
def floatFromBits (bits : UInt64) : Except String Float := do
  let value := Float.ofBits bits
  if value.toBits != bits then throw s!"Float bits cannot round-trip: {bits}"
  return value

/-- 自然数から UInt32 への変換で上位のビットを黙って捨てない。 -/
private def float32Bits (bits : Nat) : Except String UInt32 := do
  if bits ≥ UInt32.size then throw s!"Float32 bits outside 32-bit range: {bits}"
  return UInt32.ofNat bits

/-- コアの整数は数学的な整数であるが、交換入力の符号なしの負値は誤りとする。 -/
private def unsignedValue (n : Int) : Except String Nat := do
  if n < 0 then throw "negative unsigned integer constant"
  return n.toNat

/-- 旧版の入力にも同じ Integer の範囲を要求する。 -/
def integer64Value (n : Int) : Except String Benitoite.Release.Integer64Value :=
  if h : Benitoite.Release.min64 ≤ n ∧ n ≤ Benitoite.Release.max64 then
    .ok ⟨n, h⟩
  else .error "integer outside i64"

/-- 正のリテラルの大きさ。 -/
def integer64Literal (n : Nat) : Except String Benitoite.Release.Integer64Literal :=
  if h : n ≤ 9223372036854775807 then .ok ⟨n, h⟩
  else .error "positive integer literal outside i64"

/-- 直接負号だけが最小値の大きさを許す。 -/
def integer64Magnitude (n : Nat) : Except String Benitoite.Release.Integer64Magnitude :=
  if h : n ≤ 9223372036854775808 then .ok ⟨n, h⟩
  else .error "negative integer magnitude outside i64"

def Const.toRelease : Const → Except String Benitoite.Release.Const
  | .integer n => return .integer (← integer64Value n)
  | .decimal n scale => return .decimal n scale
  | .float bits => return .float (← floatFromBits bits)
  | .string s => return .string s
  | .character n => if n ≤ 0x10ffff && !(0xd800 ≤ n && n ≤ 0xdfff)
      then return .character (Char.ofNat n) else throw "invalid Unicode scalar"
  | .boolean b => return .boolean b
  | .unit => return .unit
  | .byte n => return .byte n
  | .integer8 n => return .integer8 n
  | .integer16 n => return .integer16 n
  | .integer32 n => return .integer32 n
  | .unsignedInteger16 n => return .unsignedInteger16 (Int.ofNat (← unsignedValue n))
  | .unsignedInteger32 n => return .unsignedInteger32 (Int.ofNat (← unsignedValue n))
  | .unsignedInteger64 n => return .unsignedInteger64 (Int.ofNat (← unsignedValue n))
  | .float32 bits => return .float32 (← float32Bits bits)

def fromConst : Benitoite.Release.Const → Except String Const
  | .integer n => return .integer n.toInt
  | .decimal n scale => return .decimal n scale
  | .float x => return .float x.toBits
  | .string s => return .string s
  | .character c => return .character c.toNat
  | .boolean b => return .boolean b
  | .unit => return .unit
  | .byte n => return .byte n
  | .integer8 n => return .integer8 n
  | .integer16 n => return .integer16 n
  | .integer32 n => return .integer32 n
  | .unsignedInteger16 n => do let _ ← unsignedValue n; return .unsignedInteger16 n
  | .unsignedInteger32 n => do let _ ← unsignedValue n; return .unsignedInteger32 n
  | .unsignedInteger64 n => do let _ ← unsignedValue n; return .unsignedInteger64 n
  | .float32 bits => return .float32 bits.toNat
  | .opaque .. => throw "unsupported Release constant"

def ListRest.toRelease : ListRest → Benitoite.Release.ListRest
  | .skip => .skip | .bind => .bind

def fromListRest : Benitoite.Release.ListRest → ListRest
  | .skip => .skip | .bind => .bind

partial def Pattern.toSurface : Pattern → Except String Benitoite.Surface.Pattern
  | .wild => return .wild | .var => return .var
  | .con n ps => return .con none n (← ps.mapM Pattern.toSurface)
  | .record n count positions ps => do
      if positions.length != ps.length || positions.eraseDups != positions ||
          positions.any (fun i => i >= count) then throw "invalid record pattern positions"
      return .record n count positions (← ps.mapM Pattern.toSurface)
  | .range lo hi => do
      match lo, hi with
      | .integer _, .integer _ | .character _, .character _ =>
          return .range (← lo.toRelease) (← hi.toRelease)
      | _, _ => throw "invalid range endpoint types"
  | .list before rest after => do
      if rest.isNone && !after.isEmpty then throw "list suffix without rest"
      return .list (← before.mapM Pattern.toSurface) (rest.map ListRest.toRelease) (← after.mapM Pattern.toSurface)
  | .unsupported n => throw s!"unsupported surface pattern: {n}"
  | .const c => match c with
      | .integer n => if n < 0 then return .negInt (← integer64Magnitude n.natAbs)
          else return .integer (← integer64Literal n.toNat)
      | .string s => return .string s
      | .character _n => do
          let .character c ← c.toRelease | throw "expected character"
          return .character c
      | .boolean b => return .boolean b
      | .unit => return .unit
      | .float _ => throw "unsupported Float pattern"
      | .decimal .. => throw "unsupported Decimal pattern"
      | .byte _ | .integer8 _ | .integer16 _ | .integer32 _
        | .unsignedInteger16 _ | .unsignedInteger32 _ | .unsignedInteger64 _ | .float32 _ =>
          throw "width-specific numeric constant pattern is not supported"

partial def fromPattern : Benitoite.Release.Pat → Except String Pattern
  | .wild => return .wild | .var => return .var
  | .const c => return .const (← fromConst c)
  | .con n ps => return .con n (← ps.mapM fromPattern)
  | .range lo hi => return .range (← fromConst lo) (← fromConst hi)
  | .list before rest after => return .list (← before.mapM fromPattern) (rest.map fromListRest) (← after.mapM fromPattern)

def binOp : String → Except String Benitoite.Surface.BinOp
  | "add" => return .add | "sub" => return .sub | "mul" => return .mul
  | "div" => return .div | "intDiv" => return .intDiv | "mod" => return .mod
  | "eq" => return .eq | "ne" => return .ne | "lt" => return .lt
  | "le" => return .le | "gt" => return .gt | "ge" => return .ge
  | s => throw s!"unknown binary operator: {s}"

def operatorName : Benitoite.Surface.Operator → String
  | .neg => "neg"
  | .binary b => match b with
      | .add => "add" | .sub => "sub" | .mul => "mul" | .div => "div"
      | .intDiv => "intDiv" | .mod => "mod" | .eq => "eq" | .ne => "ne"
      | .lt => "lt" | .le => "le" | .gt => "gt" | .ge => "ge"

def makeOpPrim (atoms : Eff) (entries : List OperatorEntry) : Benitoite.Surface.OpPrim :=
  Benitoite.Surface.CheckTables.makeOpPrim (fun op ty => entries.findSome? fun entry =>
    if entry.op != operatorName op then none
    else if entry.operand.isNone || (fromTy atoms ty).toOption ==
        entry.operand.bind (fun t => (t.toRelease >>= fromTy atoms).toOption) then
      some entry.name
    else none)

def OpRef.toRelease : OpRef → Benitoite.Release.OpRef
  | .user n => .user n | .prim n => .prim n | .fail => .fail

def fromOpRef : Benitoite.Release.OpRef → Except String OpRef
  | .user n => pure (.user n) | .prim n => pure (.prim n)
  | .fail => pure .fail

partial def DictEv.toSurface : DictEv → Except String Benitoite.Surface.DictEv
  | .impl n ts ds => return .impl n (← ts.mapM Ty.toRelease) (← ds.mapM DictEv.toSurface)
  | .local i => return .local i
  | .clause outer arity count i depth => return .clause ⟨outer, arity, count⟩ i depth
  | .super d cl => return .super (← d.toSurface) cl

def BuilderKind.toSurface : BuilderKind → Except String Benitoite.Release.BuilderKind
  | .string => return .string
  | .list t => return .list (← t.toRelease)
  | .bytes => return .bytes

def BuilderOp.toSurface : BuilderOp → Benitoite.Release.BuilderOp
  | .append => .append | .appendAll => .appendAll | .copy => .copy | .length => .length

/-- 文字列の列挙値を閉じた表層の指定へ変換する。 -/
def FormatSpec.toSurface (s : FormatSpec) : Except String Benitoite.Surface.FormatSpec := do
  let kind ← match s.kind with
    | "default" => pure .default | "d" => pure .d | "b" => pure .b
    | "o" => pure .o | "x" => pure .x | "X" => pure .upperX
    | "f" => pure .f | "s" => pure .s | "c" => pure .c
    | _ => throw "invalid format kind"
  let align ← match s.align with
    | "default" => pure .default | "left" => pure .left
    | "right" => pure .right | "center" => pure .center
    | _ => throw "invalid format align"
  let sign ← match s.sign with
    | "default" => pure .default | "plus" => pure .plus
    | _ => throw "invalid format sign"
  return ⟨kind, align, sign, s.alternate, s.zero, s.width, s.precision⟩

def InterpPart.toSurface : InterpPart → Except String Benitoite.Surface.InterpPart
  | .text s => return .text s
  | .stringExpr => return .stringExpr
  | .converted t => do
      let .base n := t | throw "non-basic converted interpolation type"
      let basic ← baseTy n
      if basic == .string || basic == .unit then
        throw "invalid converted interpolation type"
      return .converted (← t.toRelease)
  | .formatted t spec => do
      let t ← t.toRelease
      let spec ← spec.toSurface
      if !(decide spec.SyntaxValid && decide (spec.Compatible t)) then
        throw "invalid formatted interpolation type or spec"
      return .formatted t spec

/-- 専用種類内の通常の型だけを交換する。 -/
def fromBuilderKind (atoms : Eff) : Benitoite.Release.BuilderKind → Except String BuilderKind
  | .string => pure .string
  | .list t => return .list (← fromTy atoms t)
  | .bytes => pure .bytes

def fromBuilderOp : Benitoite.Release.BuilderOp → BuilderOp
  | .append => .append
  | .appendAll => .appendAll
  | .copy => .copy
  | .length => .length

mutual
  partial def Expr.toSurface (constants : List (String × Benitoite.Surface.Expr) := []) : Expr → Except String Benitoite.Surface.Expr
    | .constName name => do
        let some e := (constants.find? (fun p => p.1 == name)).map Prod.snd
          | throw s!"missing expanded constant: {name}"
        return e
    | .builderOp op i args kind => return .builderOp op.toSurface i (← toExprs constants args) (← kind.toSurface)
    | .local i => return .local i
    | .funDicts n ts es ds names ps _ => return .funDicts n (← ts.mapM Ty.toRelease) (← es.mapM Eff.toRelease) (← ds.mapM DictEv.toSurface) names (← ps.mapM Ty.toRelease)
    | .methName d n ts es ds names ps _ => return .methName (← d.toSurface) n (← ts.mapM Ty.toRelease) (← es.mapM Eff.toRelease) (← ds.mapM DictEv.toSurface) names (← ps.mapM Ty.toRelease)
    | .opDicts n ts ds names ps _ => return .opDicts n (← ts.mapM Ty.toRelease) (← ds.mapM DictEv.toSurface) names (← ps.mapM Ty.toRelease)
    | .raise r e => return .raise (← r.toRelease) (← e.toRelease)
    | .handleFail e r b c => return .handleFail (← e.toRelease) (← r.toRelease) (← b.toSurface constants) (← c.toSurface constants)
    | .opName n ts => return .opName n (← ts.mapM Ty.toRelease)
    | .funName n ts es => return .funName n (← ts.mapM Ty.toRelease) (← es.mapM Eff.toRelease)
    | .primName n ts es rs => return .primName n (← ts.mapM Ty.toRelease) (← es.mapM Eff.toRelease) rs
    | .nullCon n ts => return .nullCon n (← ts.mapM Ty.toRelease)
    | .conValue n ts names ps => return .conValue n (← ts.mapM Ty.toRelease) names (← ps.mapM Ty.toRelease)
    | .literal c => match c with
        | .integer n => if n < 0 then return .negInt (← integer64Magnitude n.natAbs)
            else return .literal (.integer (← integer64Literal n.toNat))
        | .decimal n scale => do
            if n < 0 then throw "negative Decimal literal coefficient"
            return .literal (.decimal n scale)
        | .float b => return .literal (.float (← floatFromBits b))
        | .string s => return .literal (.string s)
        | .character _n => do
            let .character c ← c.toRelease | throw "expected character"
            return .literal (.character c)
        | .boolean b => return .literal (.boolean b)
        | .unit => return .unit
        | .byte n => return .literal (.byte n)
        | .integer8 n => if n < 0 then return .negInteger8 n.natAbs else return .literal (.integer8 n.toNat)
        | .integer16 n => if n < 0 then return .negInteger16 n.natAbs else return .literal (.integer16 n.toNat)
        | .integer32 n => if n < 0 then return .negInteger32 n.natAbs else return .literal (.integer32 n.toNat)
        | .unsignedInteger16 n => return .literal (.unsignedInteger16 (← unsignedValue n))
        | .unsignedInteger32 n => return .literal (.unsignedInteger32 (← unsignedValue n))
        | .unsignedInteger64 n => return .literal (.unsignedInteger64 (← unsignedValue n))
        | .float32 bits => return .literal (.float32 (← float32Bits bits))
    | .unit => return .unit
    | .paren e => return .paren (← e.toSurface constants)
    | .block body => return .block (← body.toSurface constants)
    -- 交換形式は符号込みの結果を持つ。表層の negFloat は反転前の値を持つ。
    | .negFloat bits => return .negFloat (-(← floatFromBits bits))
    | .negInteger8 n => return .negInteger8 n
    | .negInteger16 n => return .negInteger16 n
    | .negInteger32 n => return .negInteger32 n
    -- 交換形式は反転後、表層は反転前を持つので、符号ビットだけを戻す。
    | .negFloat32 bits => return .negFloat32 ((← float32Bits bits) ^^^ 0x80000000)
    | .negDecimal n scale => do
        if n < 0 then throw "negative negDecimal coefficient"
        return .negDecimal n scale
    | .record n ts positions es => do
        if positions.length != es.length || positions.mergeSort (· ≤ ·) != List.range es.length then
          throw "invalid record construction positions"
        return .record n (← ts.mapM Ty.toRelease) positions (← toExprs constants es)
    | .recordUpdate n ts count positions base es => do
        if positions.isEmpty || positions.length != es.length || positions.eraseDups != positions ||
            positions.any (fun i => i >= count) then throw "invalid record update positions"
        return .recordUpdate n (← ts.mapM Ty.toRelease) count positions (← base.toSurface constants) (← toExprs constants es)
    | .conCall n ts es => return .conCall n (← ts.mapM Ty.toRelease) (← toExprs constants es)
    | .call f labels positions es => return .call (← f.toSurface constants) labels positions (← toExprs constants es)
    | .pipe a b => return .pipe (← a.toSurface constants) (← b.toSurface constants)
    | .partialCall f names es r e => return .partialCall (← f.toSurface constants) names (← toHoles constants es) (← r.toRelease) (← e.toRelease)
    | .partialCon n ts es => return .partialCon n (← ts.mapM Ty.toRelease) (← toHoles constants es)
    | .binary op t a b => return .binary (← binOp op) (← t.toRelease) (← a.toSurface constants) (← b.toSurface constants)
    | .neg t e => return .neg (← t.toRelease) (← e.toSurface constants)
    | .not e => return .not (← e.toSurface constants)
    | .and a b => return .and (← a.toSurface constants) (← b.toSurface constants)
    | .or a b => return .or (← a.toSurface constants) (← b.toSurface constants)
    | .list t es => return .list (← t.toRelease) (← toExprs constants es)
    | .listSpread t f before e after => do
        let f ← f.toSurface constants
        if (Benitoite.Surface.directCallee f).isNone then throw "indirect list concat"
        return .listSpread (← t.toRelease) f (← toExprs constants before) (← e.toSurface constants) (← toExprs constants after)
    | .interpolation ps es fs => do
        let ps ← ps.mapM InterpPart.toSurface
        if es.length != (Benitoite.Surface.InterpPart.exprTypes ps).length ||
            fs.length != (Benitoite.Surface.InterpPart.converterTypes ps).length then
          throw "interpolation part/expression/converter count mismatch"
        let converted ← fs.mapM (Expr.toSurface constants)
        if converted.any (fun f => (Benitoite.Surface.directCallee f).isNone) then
          throw "indirect interpolation converter"
        -- 名前の一致は交換の境界で検査する。表層の型検査は署名を検査する。
        let mut heads := converted
        for part in ps do
          match part with
          | .converted _ => heads := heads.drop 1
          | .formatted t _ =>
              let some name := Benitoite.Surface.FormatSpec.headName t
                | throw "missing format head name"
              match heads.head? with
              | some (.primName n [] [] _) =>
                  if n != name then throw "formatted interpolation head name mismatch"
              | _ => throw "formatted interpolation requires direct primitive head"
              heads := heads.drop 1
          | _ => pure ()
        return .interpolation ps (← toExprs constants es) (← toExprs constants fs)
    | .lam names ps r e b => return .lam names (← ps.mapM Ty.toRelease) (← r.toRelease) (← e.toRelease) (← b.toSurface constants)
    | .ite c y n => return .ite (← c.toSurface constants) (← y.toSurface constants) (← n.toSurface constants)
    | .elseIf c y n => return .elseIf (← c.toSurface constants) (← y.toSurface constants) (← n.toSurface constants)
    | .ifOnly c y => return .ifOnly (← c.toSurface constants) (← y.toSurface constants)
    | .matchE r e as => return .matchE (← r.toRelease) (← e.toSurface constants) (← toArms constants as)
    | .returnE r e => return .returnE (← r.toRelease) (← e.toSurface constants)
    | .tryResult ts ok err e => return .tryResult (← ts.mapM Ty.toRelease) ok err (← e.toSurface constants)
    | .tryOption ts someCon noneCon e => return .tryOption (← ts.mapM Ty.toRelease) someCon noneCon (← e.toSurface constants)
    | .tryResultReturn ts ok err e => return .tryResult (← ts.mapM Ty.toRelease) ok err (← e.toSurface constants)
    | .tryOptionReturn ts someCon noneCon e => return .tryOption (← ts.mapM Ty.toRelease) someCon noneCon (← e.toSurface constants)
    | .tryResultDie t ok err dict showMethod exit e message =>
      return .tryResultDie (← t.toRelease) ok err (← dict.toSurface) showMethod exit
        (← e.toSurface constants) (← message.mapM (Expr.toSurface constants))
    | .tryOptionDie t someCon noneCon exit e message =>
      return .tryOptionDie (← t.toRelease) someCon noneCon exit
        (← e.toSurface constants) (← message.mapM (Expr.toSurface constants))
    | .withE o e b => return .withE o (← e.toSurface constants) (← b.toSurface constants)
    | .lazyE b => return .lazyE (← b.toSurface constants)
    | .handleE b cs => return .handleE (← b.toSurface constants) (← toClauses constants cs)
    | .resume k e => return .resume k (← e.toSurface constants)
  partial def toClauses (constants : List (String × Benitoite.Surface.Expr) := []) : List SurfaceClause → Except String Benitoite.Surface.Clauses
    | [] => return .nil
    | .mk op arity ntys b count failure :: cs => do
        if failure.isSome || op == .fail then throw "Fail requires handleFail"
        return .cons op.toRelease arity ntys (← b.toSurface constants) (← toClauses constants cs) count
  partial def toExprs (constants : List (String × Benitoite.Surface.Expr) := []) : List Expr → Except String Benitoite.Surface.Exprs
    | [] => return .nil
    | e :: es => return .cons (← e.toSurface constants) (← toExprs constants es)
  partial def toHoles (constants : List (String × Benitoite.Surface.Expr) := []) : List HoleArg → Except String Benitoite.Surface.HoleArgs
    | [] => return .nil
    | .expr label position e :: es => return .expr label position (← e.toSurface constants) (← toHoles constants es)
    | .hole label position t :: es => return .hole label position (← t.toRelease) (← toHoles constants es)
  partial def toArms (constants : List (String × Benitoite.Surface.Expr) := []) : List Arm → Except String Benitoite.Surface.Arms
    | [] => return .nil
    | .mk alts g b :: as => do
        let alts ← alts.mapM fun a => do
          let p ← a.pat.toSurface
          if a.slots.mergeSort (· ≤ ·) != List.range p.binders then throw "invalid alternative slots"
          pure ({ pat := p, slots := a.slots } : Benitoite.Surface.Alternative)
        let some first := alts.head? | throw "empty alternatives"
        if first.slots != List.range first.pat.binders then throw "nonidentity first alternative"
        if alts.any (fun a => a.slots.length != first.slots.length) then throw "alternative binder counts differ"
        return .cons alts (← g.mapM (Expr.toSurface constants)) (← b.toSurface constants) (← toArms constants as)
  partial def Block.toSurface (constants : List (String × Benitoite.Surface.Expr) := []) : Block → Except String Benitoite.Surface.Block
    | .builderBind k b => return .builderBind (← k.toSurface) (← b.toSurface constants)
    | .empty => return .empty
    | .last e => return .last (← e.toSurface constants)
    | .lastBind k t e => return .lastBind (if k then .shadow else .bind) (← t.toRelease) (← e.toSurface constants)
    | .lastDiscard e => return .lastDiscard (← e.toSurface constants)
    | .bind k t e b => return .bind (if k then .shadow else .bind) (← t.toRelease) (← e.toSurface constants) (← b.toSurface constants)
    | .discard e b => return .discard (← e.toSurface constants) (← b.toSurface constants)
    | .seq e b => return .seq (← e.toSurface constants) (← b.toSurface constants)
    | .lastPat k p t e => return .lastPat (if k then .shadow else .bind) (← p.toSurface) (← t.toRelease) (← e.toSurface constants)
    | .bindPat k p t e b => return .bindPat (if k then .shadow else .bind) (← p.toSurface) (← t.toRelease) (← e.toSurface constants) (← b.toSurface constants)
end

partial def constantNames : Json → List String
  | .arr xs => xs.toList.flatMap constantNames
  | j@(.obj xs) =>
      if let .ok o := j.getObjVal? "constName" then
        ((o.getObjVal? "name").bind Json.getStr?).toOption.toList
      else xs.toArray.toList.flatMap (fun (_,v) => constantNames v)
  | _ => []

structure ConstantState where
  cache : List (String × Benitoite.Surface.Expr) := []
  active : List String := []

/-- 展開中の名前は循環、完成した値は共有する。使用位置の環境を渡さない。 -/
partial def expandConstant (table : List ConstantEntry) (name : String) :
    StateT ConstantState (Except String) Unit := do
  let state ← get
  if state.cache.any (fun p => p.1 == name) then return
  if state.active.contains name then throw s!"cyclic constant: {name}"
  let some entry := table.find? (fun e => e.name == name) | throw s!"missing constant: {name}"
  modify fun s => { s with active := name :: s.active }
  for dependency in (constantNames (toJson entry.body)).eraseDups do
    expandConstant table dependency
  let body ← entry.body.toSurface (← get).cache
  let value := Benitoite.Surface.Expr.constE (← entry.ty.toRelease) body
  modify fun s => { s with cache := (name, value) :: s.cache, active := s.active.tail }

def Input.constantCache (input : Input) : Except String (List (String × Benitoite.Surface.Expr)) := do
  if (input.constants.map ConstantEntry.name).eraseDups.length != input.constants.length then
    throw "duplicate constant name"
  let (_, state) ← (input.constants.forM (fun e => expandConstant input.constants e.name)).run {}
  return state.cache

mutual
  partial def fromVal (atoms : Eff) (dictCounts : String → Nat) : Benitoite.Release.Val → Except String Val
    | .var i => return .var i
    | .raise r e => return .raise (← fromTy atoms r) (← fromTy atoms e)
    | .dict n ts ds => return .dict n (← ts.mapM (fromTy atoms)) (← ds.mapM (fromVal atoms dictCounts))
    | .super d cl => return .super (← fromVal atoms dictCounts d) cl
    | .op n ts => return .op n (← ts.mapM (fromTy atoms))
    | .const c => return .const (← fromConst c)
    | .fnRef n ts es => return .fnRef n (← ts.mapM (fromTy atoms)) (← es.mapM (fromEff atoms))
    -- 範囲の列を書き出す（corpus 15。RV-L20 軽5 の誤りを置き換えた）。
    | .prim n ts es rs => return .prim n (← ts.mapM (fromTy atoms)) (← es.mapM (fromEff atoms)) rs
    | .lam names ps b => return .lam names (← ps.mapM (fromTy atoms)) (← fromComp atoms dictCounts b)
    | .con n ts vs => return .con n (← ts.mapM (fromTy atoms)) (← vs.mapM (fromVal atoms dictCounts))
    | .list vs => return .list (← vs.mapM (fromVal atoms dictCounts))
    | _ => return .unsupported "Release.Val"
  partial def fromComp (atoms : Eff) (dictCounts : String → Nat) : Benitoite.Release.Comp → Except String Comp
    | .builderLet k b => return .builderLet (← fromBuilderKind atoms k) (← fromComp atoms dictCounts b)
    | .builderOp k op ref vs =>
        return .builderOp (← fromBuilderKind atoms k) (fromBuilderOp op)
          (match ref with | .bound i => .bound i | .loc i => .loc i) (← vs.mapM (fromVal atoms dictCounts))
    | .ret v => return .ret (← fromVal atoms dictCounts v)
    | .meth d n ts es vs => return .meth (← fromVal atoms dictCounts d) n (← ts.mapM (fromTy atoms)) (← es.mapM (fromEff atoms)) (← vs.mapM (fromVal atoms dictCounts))
    | .letIn m n => return .letIn (← fromComp atoms dictCounts m) (← fromComp atoms dictCounts n)
    | .app f vs => return .app (← fromVal atoms dictCounts f) (← vs.mapM (fromVal atoms dictCounts))
    | .ite v m n => return .ite (← fromVal atoms dictCounts v) (← fromComp atoms dictCounts m) (← fromComp atoms dictCounts n)
    | .match v arms => do
        let as ← arms.mapM fun
          | .mk alts guard body => do
              let alts ← alts.mapM fun a => do
                pure ({ pat := ← fromPattern a.pat, slots := a.slots } : Alternative)
              return CoreArm.mk alts (← guard.mapM (fromComp atoms dictCounts)) (← fromComp atoms dictCounts body)
        return .matchC (← fromVal atoms dictCounts v) as
    | .escape v => return .escape (← fromVal atoms dictCounts v)
    | .use v b => return .use (← fromVal atoms dictCounts v) (← fromComp atoms dictCounts b)
    | .lazyC b => return .lazyC (← fromComp atoms dictCounts b)
    | .handle b cs => return .handle (← fromComp atoms dictCounts b) (← cs.mapM (fromClause atoms dictCounts))
    | .resume (.var k) v => return .resume k (← fromVal atoms dictCounts v)
    | _ => return .unsupported "Release.Comp"
  partial def fromClause (atoms : Eff) (dictCounts : String → Nat) : Benitoite.Release.Clause → Except String CoreClause
    | .mk op arity ntys b => return .mk (← fromOpRef op) arity ntys (← fromComp atoms dictCounts b) (match op with | .user n => dictCounts n | _ => 0) none
    | .fail e b => return .mk .fail 1 1 (← fromComp atoms dictCounts b) 0 (some (← fromTy atoms e))
end

/-! 契約名とソース順を保持する独立した交換の入口。
設計書 07-04「証明する性質」の検査対象と既存形式を区別する。 -/
mutual
  partial def Expr.lambdaEffects (constants : List ConstantEntry := []) : Expr → List Eff
    | .constName name => ((constants.find? (fun e => e.name == name)).map (fun e => e.body.lambdaEffects constants)).getD []
    | .lam _ _ _ e b => e :: b.lambdaEffects constants
    | .conValue .. => [[]]
    | .funDicts _ _ _ _ _ _ e | .methName _ _ _ _ _ _ _ e => [e]
    | .partialCall f _ es _ e => e :: (f.headLambdaEffects constants ++ holesEffects constants es)
    | .partialCon _ _ es => [] :: holesEffects constants es
    | .call f _ _ es => f.headLambdaEffects constants ++ es.flatMap (Expr.lambdaEffects constants)
    | .builderOp _ _ es _ | .conCall _ _ es | .list _ es | .record _ _ _ es => es.flatMap (Expr.lambdaEffects constants)
    | .recordUpdate _ _ _ _ base es => base.lambdaEffects constants ++ es.flatMap (Expr.lambdaEffects constants)
    | .listSpread _ f before e after => before.flatMap (Expr.lambdaEffects constants) ++
        e.lambdaEffects constants ++ after.flatMap (Expr.lambdaEffects constants) ++ f.headLambdaEffects constants
    | .interpolation _ es fs => es.flatMap (Expr.lambdaEffects constants) ++ fs.flatMap (Expr.headLambdaEffects constants)
    | .pipe a b => a.lambdaEffects constants ++ (match b with
        | .conValue .. => []
        | .call f _ _ es => f.headLambdaEffects constants ++ es.flatMap (Expr.lambdaEffects constants)
        | other => other.headLambdaEffects constants)
    | .binary _ _ a b | .and a b | .or a b => a.lambdaEffects constants ++ b.lambdaEffects constants
    | .paren e | .neg _ e | .not e | .returnE _ e
      | .tryResult _ _ _ e | .tryOption _ _ _ e => e.lambdaEffects constants
    | .tryResultReturn _ _ _ e | .tryOptionReturn _ _ _ e => e.lambdaEffects constants
    | .tryResultDie _ _ _ _ _ _ e message | .tryOptionDie _ _ _ _ e message =>
      e.lambdaEffects constants ++ (message.map (Expr.lambdaEffects constants)).getD []
    | .withE _ e b => e.lambdaEffects constants ++ b.lambdaEffects constants
    | .lazyE b | .block b => b.lambdaEffects constants
    | .resume _ e => e.lambdaEffects constants
    | .opDicts _ _ _ _ _ e => [e]
    | .raise .. => []
    | .handleFail _ _ b c => b.lambdaEffects constants ++ c.lambdaEffects constants
    | .handleE b cs => b.lambdaEffects constants ++ cs.flatMap (fun (.mk _ _ _ b _ _) => b.lambdaEffects constants)
    | .ite c y n => c.lambdaEffects constants ++ y.lambdaEffects constants ++ n.lambdaEffects constants
    | .elseIf c y n => c.lambdaEffects constants ++ y.lambdaEffects constants ++ n.lambdaEffects constants
    | .ifOnly c y => c.lambdaEffects constants ++ y.lambdaEffects constants
    | .matchE _ e as => e.lambdaEffects constants ++ as.flatMap (fun (.mk _ g b) => (g.map (Expr.lambdaEffects constants)).getD [] ++ b.lambdaEffects constants)
    | _ => []
  /-- 裸の辞書付きの名前は CallHead になり、値化のラムダを作らない。
  paren はこの分岐に含めず、内側の値化のエフェクトを保持する。 -/
  partial def Expr.headLambdaEffects (constants : List ConstantEntry := []) : Expr → List Eff
    | .funDicts .. | .methName .. | .opDicts .. => []
    | e => e.lambdaEffects constants
  partial def holesEffects (constants : List ConstantEntry := []) (es : List HoleArg) : List Eff := es.flatMap fun
    | .expr _ _ e => e.lambdaEffects constants | .hole _ _ _ => []
  partial def Block.lambdaEffects (constants : List ConstantEntry := []) : Block → List Eff
    | .builderBind _ b => b.lambdaEffects constants
    | .empty => []
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e => e.lambdaEffects constants
    | .bind _ _ e b | .discard e b | .seq e b | .bindPat _ _ _ e b => e.lambdaEffects constants ++ b.lambdaEffects constants
end

/-- NoFail は本体から補わず、交換された宣言の型から独立に再計算する。 -/
def Header.validateNoFail (h : Header) : Except String Unit := do
  let ps ← h.params.mapM Ty.toRelease
  let r ← h.ret.toRelease
  let e ← h.eff.toRelease
  let atoms := (collectAtoms (toJson h)).filterMap Atom.toRelease
  if !(Benitoite.Surface.CheckTools.rowsTysCheck atoms h.neffs ps &&
      Benitoite.Surface.CheckTools.rowsTyCheck atoms h.neffs r &&
      Benitoite.Surface.CheckTools.rowsEffCheck atoms h.neffs e) then
    throw "effect row index outside declaration"
  if h.effParams.map (·.noFail) != Benitoite.Surface.CheckTools.signatureQ h.neffs ps r e then
    throw "NoFail signature mismatch"

def SurfaceDef.toSurface (d : SurfaceDef) (constants : List (String × Benitoite.Surface.Expr) := []) : Except String Benitoite.Surface.Def := do
  d.header.validateNoFail
  checkNames d.header.names d.header.params.length
  return {
    tparams := d.header.tparams.map (fun (e, k) => ⟨e, k⟩)
    dictParams := d.dictParams
    neffs := d.header.neffs
    names := d.header.names
    params := ← d.header.params.mapM Ty.toRelease
    ret := ← d.header.ret.toRelease
    eff := ← d.header.eff.toRelease
    body := ← d.body.toSurface constants }

def OpEntry.toRelease (o : OpEntry) : Except String Benitoite.Release.OpDecl := do
  o.header.validateNoFail
  checkNames o.header.names o.header.params.length
  if o.effectKind != "ordinary" then throw "user operation must be ordinary"
  if o.dictParams.any (fun p => p.2 >= o.header.tparams.length) then throw "operation dictionary type index out of range"
  if o.header.neffs != 0 then throw "operation declares effect parameters"
  return {
    eff := o.eff
    dictParams := o.dictParams
    tparams := o.header.tparams.map (fun (e, k) => ⟨e, k⟩)
    names := o.header.names
    params := ← o.header.params.mapM Ty.toRelease
    ret := ← o.header.ret.toRelease }

/-- 表示用の末尾の括弧にある BindingId だけを鍵に使う。 -/
def functionKey (display : String) : Except String String := do
  let some piece := (display.splitOn " (fn:").getLast?
    | throw s!"invalid function display name: {display}"
  let id := (piece.splitOn ")").headD ""
  let some n := id.toNat? | throw s!"invalid function binding: {display}"
  if display.endsWith s!" (fn:{n})" then return s!"fn:{n}"
  else throw s!"invalid function suffix: {display}"

/-- 表は一度だけ読み、表層のプログラムの表にする。脱糖はこの表をそのまま写す。 -/
def Input.operationProgram (input : Input) : Except String Benitoite.Surface.Program := do
  let ops ← input.ops.mapM (fun o => do return (o.name, ← o.toRelease))
  let classes ← input.classes.mapM (fun cl => do
    let methods ← cl.methods.mapM (fun m => do
      m.header.validateNoFail
      checkNames m.header.names m.header.params.length
      let sg : Benitoite.Release.MethSig := {
        tparams := m.header.tparams.map (fun (e,k) => ⟨e,k⟩)
        neffs := m.header.neffs
        names := m.header.names
        params := ← m.header.params.mapM Ty.toRelease
        ret := ← m.header.ret.toRelease
        eff := ← m.header.eff.toRelease }
      return (m.name, sg))
    let decl : Benitoite.Release.ClassDecl := {
      supers := cl.supers
      methods := fun n => (methods.find? (fun m => m.1 == n)).map Prod.snd }
    return (cl.name, decl))
  let impls ← input.impls.mapM (fun i => do
    let decl : Benitoite.Surface.ImplDecl := {
      tparams := i.tparams.map (fun (e,k) => ⟨e,k⟩)
      dictParams := i.dictParams
      cls := i.cls
      target := ← i.target.toRelease
      supers := fun _ => none
      methods := fun _ => none }
    return (i.name, decl))
  let accessors ← (input.definitions.filterMap (fun d => match d.scope with
    | .accessor name con k decl _ => some (name, con, k, decl)
    | _ => none)).mapM (fun (name, con, k, decl) => do
      checkNames decl.fields decl.args.length
      if k >= decl.args.length then throw "accessor index outside record"
      let cd : Benitoite.Release.ConDecl := {
        data := decl.data, ntys := decl.ntys, args := ← decl.args.mapM Ty.toRelease }
      return (name, con, k, cd, decl.fields))
  if (accessors.map (fun (n,_,_,_,_) => n)).eraseDups.length != accessors.length then
    throw "duplicate accessor name"
  let views ← (input.definitions.filterMap fun d => match d.scope with
    | .inScope s _ => if s.implementation.isNone || s.method.isSome then some (d.name,s) else none
    | _ => none).mapM fun (name,s) => do
      let view ← coverageView input.dataTypes s.package s.coverageView
      return (← functionKey name, s.implementation, s.method, view)
  let functionKeys := views.filterMap fun (key,i,_,_) => if i.isNone then some key else none
  let methodKeys := views.filterMap fun (_,i,m,_) => do return (← i, ← m)
  if functionKeys.eraseDups.length != functionKeys.length ||
      methodKeys.eraseDups.length != methodKeys.length then throw "duplicate body coverage view"
  return {
    functionViews := fun n => ((views.find? fun (key,i,_,_) => key == n && i.isNone).map
      fun (_,_,_,v) => v).getD Benitoite.Release.closedView
    methodViews := fun i n => ((views.find? fun (_,impl,m,_) => impl == some i && m == some n).map
      fun (_,_,_,v) => v).getD Benitoite.Release.closedView
    defs := fun _ => none
    cons := fun n => (accessors.find? (fun (_,c,_,_,_) => c == n)).map (fun (_,_,_,cd,_) => cd)
    conFields := fun n => (accessors.find? (fun (_,c,_,_,_) => c == n)).map (fun (_,_,_,_,fields) => fields)
    accessors := fun n => (accessors.find? (fun (f,_,_,_,_) => f == n)).map (fun (_,c,k,_,_) => (c,k))
    ops := fun n => (ops.find? (fun o => o.1 == n)).map Prod.snd
    effects := fun n => (input.effects.find? (fun e => e.name == n)).map EffectEntry.ops
    classes := fun n => (classes.find? (fun c => c.1 == n)).map Prod.snd
    impls := fun n => (impls.find? (fun i => i.1 == n)).map Prod.snd }

/-- HasClauses.cons の arity・ntys の前提を交換形式でも検査する。
JSON の全子を辿るので、プレースホルダ・ラムダ・遅延・入れ子の節も検査する。 -/
partial def validateClauses (program : Benitoite.Surface.Program)
    (prims : List PrimOpEntry) : Json → Except String Unit
  | .arr xs => xs.toList.forM (validateClauses program prims)
  | j@(.obj xs) => do
      if let .ok o := j.getObjVal? "opDicts" then
        let name ← o.getObjValAs? String "name"
        let some od := program.ops name | throw s!"missing operation: {name}"
        let e ← o.getObjValAs? Eff "eff"
        if canonicalJson (toJson e) != toJson ([Atom.name od.eff Scope.Signature.Ix.top]) then
          throw "operation latent effect mismatch"
      if let .ok h := j.getObjVal? "handleE" then
        let cs ← (← h.getObjVal? "clauses").getArr?
        for c in cs do
          let .mk op arity ntys _ count failure ← decodeSurfaceClause c
          if failure.isSome || op == .fail then throw "Fail requires handleFail"
          let (expectedArity, expectedNtys, expectedDicts) ← match op with
            | .user n => do
                let some od := program.ops n | throw s!"missing operation: {n}"
                pure (od.valueParams.length, od.tparams.length, od.dictParams.length)
            | .prim n => do
                let some od := prims.find? (fun p => p.name == n) | throw s!"missing primitive operation: {n}"
                checkNames od.names od.arity
                pure (od.arity, od.ntys, 0)
            | .fail => throw "Fail requires handleFail"
          if arity != expectedArity || ntys != expectedNtys || count != expectedDicts then
            throw s!"clause signature mismatch: {toJson op}, arity={arity}/{expectedArity}, ntys={ntys}/{expectedNtys}"
      xs.toArray.toList.forM (fun (_, v) => validateClauses program prims v)
  | _ => pure ()

def fromHeader (atoms : Eff) (ts : List Benitoite.Release.TParam) (neffs : Nat)
    (names : List String) (ps : List Benitoite.Release.Ty) (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) : Except String Header := do
  return {
    tparams := ts.map (fun p => (p.equality, p.key))
    neffs := neffs
    effParams := (Benitoite.Surface.CheckTools.signatureQ neffs ps r e).map EffParam.mk
    names := names
    params := ← ps.mapM (fromTy atoms)
    ret := ← fromTy atoms r
    eff := ← fromEff atoms e }

/-- 実装メソッドの頭は型クラス宣言から導く。上位辞書は実装ごとの一単位で比較する。 -/
def desugar (atoms : Eff) (entries : List OperatorEntry) (program : Benitoite.Surface.Program)
    (d : SurfaceDef) (constants : List (String × Benitoite.Surface.Expr))
    (table : List ConstantEntry) : Except String CoreDef := do
  let opPrim := makeOpPrim atoms entries
  let dictCounts := fun n => ((program.ops n).map (·.dictParams.length)).getD 0
  let lambdaEffects ← (d.body.lambdaEffects table).mapM (fun e => do fromEff atoms (← e.toRelease))
  if let some name := d.implementation then
    let some id := program.impls name | throw s!"missing implementation: {name}"
    let some cl := program.classes id.cls | throw s!"missing class: {id.cls}"
    if let some m := d.method then
      let some ms := cl.methods m | throw s!"missing implementation method: {m}"
      let body ← d.body.toSurface constants
      let decl := { id with methods := fun n => if n == m then some body else none }
      let result := Benitoite.Surface.desugarImpl opPrim decl
      let some core := result.methods m | throw "missing desugared method"
      let methodTy := Benitoite.Surface.CheckTools.substTyAt (atoms.filterMap Atom.toRelease) ms.tparams.length [id.target] []
      let methodEff := Benitoite.Surface.CheckTools.substEffAt (atoms.filterMap Atom.toRelease) ms.tparams.length [id.target] [] ms.eff
      let header ← fromHeader atoms (ms.tparams ++ id.tparams) ms.neffs ms.names
        (ms.params.map methodTy) (methodTy ms.ret) methodEff
      let surfaceHeader ← fromHeader atoms (← d.toSurface constants).tparams d.header.neffs (← d.toSurface constants).coreNames
        ((← d.toSurface constants).dictTys ++ (← d.toSurface constants).params) (← d.header.ret.toRelease) (← d.header.eff.toRelease)
      if canonicalJson (toJson header) != canonicalJson (toJson surfaceHeader) then
        throw s!"implementation method signature mismatch: {name}/{m}"
      return { header := header, body := ← fromComp atoms dictCounts core, lambdaEffects := lambdaEffects, supers := [] }
    else
      if d.supers.map Prod.fst != cl.supers then throw "implementation supers do not match class declaration"
      let supers ← d.supers.mapM (fun (n,e) => do return (n, ← e.toSurface))
      let decl := { id with supers := fun n => (supers.find? (fun p => p.1 == n)).map Prod.snd }
      let result := Benitoite.Surface.desugarImpl opPrim decl
      let converted ← d.supers.mapM (fun (n,_) => do
        let some v := result.supers n | throw "missing desugared superclass"
        return (n, ← fromVal atoms dictCounts v))
      let header ← fromHeader atoms result.tparams 0 [] [] (.base .unit) Benitoite.Release.Eff.empty
      return { header := header, body := .ret (.const .unit), lambdaEffects := [], supers := converted }
  else
    let result := Benitoite.Surface.desugarDef opPrim (← d.toSurface constants)
    return {
      header := ← fromHeader atoms result.tparams result.neffs result.names result.params result.ret result.eff
      body := ← fromComp atoms dictCounts result.body
      lambdaEffects := lambdaEffects
      supers := [] }
/-- Program.lookupFun と desugarProgram の経路を通して取得関数を比較する。 -/
def desugarAccessor (atoms : Eff) (entries : List OperatorEntry)
    (program : Benitoite.Surface.Program) (name con : String) (k : Nat)
    (decl : RecordConDecl) : Except String CoreDef := do
  let some (c, index) := program.accessors name | throw "missing accessor table entry"
  if c != con || index != k then throw "accessor table mismatch"
  let some cd := program.cons con | throw "missing record constructor"
  if cd.data != decl.data || cd.ntys != decl.ntys ||
      canonicalJson (toJson (← cd.args.mapM (fromTy atoms))) !=
        canonicalJson (toJson decl.args) then throw "record constructor table mismatch"
  let dictCounts := fun n => ((program.ops n).map (·.dictParams.length)).getD 0
  let result := Benitoite.Surface.desugarProgram (makeOpPrim atoms entries) program
  let some d := result.defs name | throw "missing desugared accessor"
  return {
    header := ← fromHeader atoms d.tparams d.neffs d.names d.params d.ret d.eff
    body := ← fromComp atoms dictCounts d.body
    lambdaEffects := []
    supers := [] }
end Benitoite.Exchange
