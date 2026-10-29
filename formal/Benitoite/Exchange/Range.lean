import Lean
import Benitoite.Scope.Signature
import Benitoite.Scope.RangeCover

/-!
# 交換の形式の範囲・範囲の位置・表のデータ（corpus 15・sidecar 7）

範囲付きの原子と不透明型、組み込みの呼び出しの範囲の列、署名の範囲の変数の種類と IO の形、表のデータ
（`effKind`・`valKind`・`admitsR`・`valContent`）を交換の形式で読み書きする（設計書 07-04「交換の形式の版」）。
範囲の値は採用定義 `Scope.Domain.Range`、範囲の位置は `Scope.Signature.Ix` をそのまま使い、交換のための別の型を
置かない。

旧版（corpus 14 以前・sidecar 6 以前）の入力には範囲がない。旧版は、名前の原子と不透明型の各々に明示の Top の範囲の
位置を、組み込みの呼び出しに空の範囲の列を加えてから読む（`legacyRangeNode`）。新版は欄を必須とし、欠けた欄を
Top で補わない。旧版の名前の原子と不透明型の読み込みが Top の構築関数（`Release.Atom.nameTop`・`Release.Ty.opaqueTop`）
に対応することは、本モジュールの全域の関数について `legacy_name_atom_top`・`legacy_opaque_top` で示し、
`Convert.lean` の `legacy_atom_toRelease`・`legacy_opaque_toRelease` で Release の構築関数へつなぐ。JSON の全体を辿る
部分（`Version.lean` の `legacyRanges`）は `partial` であり、Lean では証明しない（既存の交換の読み込みと同じ扱い。
Rust との全比較は K10）。
-/

namespace Benitoite.Exchange
open Lean Benitoite.Scope.Domain Benitoite.Scope.Signature

/-! ## 自然数・語・種類 -/

def encodeNat (n : Nat) : Json := toJson n

def decodeNat (j : Json) : Except String Nat := fromJson? j

theorem decodeNat_encodeNat (n : Nat) : decodeNat (encodeNat n) = .ok n := by
  simp [encodeNat, decodeNat, toJson, fromJson?, Json.getNat?, JsonNumber.fromNat]; rfl

def encodeWord (w : Word) : Json := .arr (w.map Json.str).toArray

def decodeWord : Json → Except String Word
  | .arr xs => xs.toList.mapM fun j => match j with
      | .str s => .ok s
      | _ => .error "expected a label string"
  | _ => .error "expected a label list"

theorem decodeWord_encodeWord (w : Word) : decodeWord (encodeWord w) = .ok w := by
  simp only [encodeWord, decodeWord]
  induction w with
  | nil => rfl
  | cons a w ih => simp [List.mapM_cons, ih]; rfl

def encodeKind : Kind → Json
  | .path => .str "path" | .host => .str "host" | .endpoint => .str "endpoint"

def decodeKind : Json → Except String Kind
  | .str "path" => .ok .path
  | .str "host" => .ok .host
  | .str "endpoint" => .ok .endpoint
  | _ => .error "unknown target kind"

theorem decodeKind_encodeKind (k : Kind) : decodeKind (encodeKind k) = .ok k := by
  cases k <;> rfl

instance : ToJson Kind := ⟨encodeKind⟩
instance : FromJson Kind := ⟨decodeKind⟩

def encodeFamily : Family → Json
  | .v4 => .str "v4" | .v6 => .str "v6"

def decodeFamily : Json → Except String Family
  | .str "v4" => .ok .v4
  | .str "v6" => .ok .v6
  | _ => .error "unknown address family"

theorem decodeFamily_encodeFamily (f : Family) : decodeFamily (encodeFamily f) = .ok f := by
  cases f <;> rfl

/-! ## 対象の領域のパターン -/

def encodeIPAddr (a : IPAddr) : Json :=
  Json.mkObj [("family", encodeFamily a.family), ("bits", encodeNat a.bits.val)]

/-- 値がアドレス族の幅に収まらない入力は誤りにする（黙って切り詰めない）。 -/
def decodeIPAddr (j : Json) : Except String IPAddr := do
  let f ← decodeFamily (← j.getObjVal? "family")
  let n ← decodeNat (← j.getObjVal? "bits")
  if h : n < 2 ^ f.width then return ⟨f, ⟨n, h⟩⟩ else throw "IP address outside its family width"

theorem decodeIPAddr_encodeIPAddr (a : IPAddr) : decodeIPAddr (encodeIPAddr a) = .ok a := by
  obtain ⟨f, n, h⟩ := a
  show (do
    let f' ← decodeFamily (encodeFamily f)
    let n' ← decodeNat (encodeNat n)
    if h : n' < 2 ^ f'.width then (pure ⟨f', ⟨n', h⟩⟩ : Except String IPAddr)
    else throw "IP address outside its family width") = _
  rw [decodeFamily_encodeFamily, decodeNat_encodeNat]
  simp only [bind, Except.bind, pure, Except.pure, h, dite_true]

def encodeCIDR (c : CIDR) : Json :=
  Json.mkObj [("family", encodeFamily c.family), ("network", encodeNat c.network.val),
    ("prefixLen", encodeNat c.prefixLen)]

def decodeCIDR (j : Json) : Except String CIDR := do
  let f ← decodeFamily (← j.getObjVal? "family")
  let n ← decodeNat (← j.getObjVal? "network")
  let k ← decodeNat (← j.getObjVal? "prefixLen")
  if h : n < 2 ^ f.width then return ⟨f, ⟨n, h⟩, k⟩ else throw "CIDR network outside its family width"

theorem decodeCIDR_encodeCIDR (c : CIDR) : decodeCIDR (encodeCIDR c) = .ok c := by
  obtain ⟨f, ⟨n, h⟩, k⟩ := c
  show (do
    let f' ← decodeFamily (encodeFamily f)
    let n' ← decodeNat (encodeNat n)
    let k' ← decodeNat (encodeNat k)
    if h : n' < 2 ^ f'.width then (pure ⟨f', ⟨n', h⟩, k'⟩ : Except String CIDR)
    else throw "CIDR network outside its family width") = _
  rw [decodeFamily_encodeFamily, decodeNat_encodeNat, decodeNat_encodeNat]
  simp only [bind, Except.bind, pure, Except.pure, h, dite_true]

def encodePathPattern : PathPattern → Json
  | .exact w => Json.mkObj [("exact", encodeWord w)]
  | .tree w => Json.mkObj [("tree", encodeWord w)]

def decodePathPattern (j : Json) : Except String PathPattern := do
  if let .ok w := j.getObjVal? "exact" then return .exact (← decodeWord w)
  if let .ok w := j.getObjVal? "tree" then return .tree (← decodeWord w)
  throw "unknown path pattern"

theorem decodePathPattern_encode (p : PathPattern) :
    decodePathPattern (encodePathPattern p) = .ok p := by
  cases p with
  | exact w =>
    show (do let x ← decodeWord (encodeWord w); pure (PathPattern.exact x)) = _
    rw [decodeWord_encodeWord]; rfl
  | tree w =>
    show (do let x ← decodeWord (encodeWord w); pure (PathPattern.tree x)) = _
    rw [decodeWord_encodeWord]; rfl

def encodeNamePattern : NamePattern → Json
  | .exact w => Json.mkObj [("exact", encodeWord w)]
  | .one w => Json.mkObj [("one", encodeWord w)]
  | .many w => Json.mkObj [("many", encodeWord w)]

def decodeNamePattern (j : Json) : Except String NamePattern := do
  if let .ok w := j.getObjVal? "exact" then return .exact (← decodeWord w)
  if let .ok w := j.getObjVal? "one" then return .one (← decodeWord w)
  if let .ok w := j.getObjVal? "many" then return .many (← decodeWord w)
  throw "unknown host name pattern"

theorem decodeNamePattern_encode (p : NamePattern) :
    decodeNamePattern (encodeNamePattern p) = .ok p := by
  cases p with
  | exact w =>
    show (do let x ← decodeWord (encodeWord w); pure (NamePattern.exact x)) = _
    rw [decodeWord_encodeWord]; rfl
  | one w =>
    show (do let x ← decodeWord (encodeWord w); pure (NamePattern.one x)) = _
    rw [decodeWord_encodeWord]; rfl
  | many w =>
    show (do let x ← decodeWord (encodeWord w); pure (NamePattern.many x)) = _
    rw [decodeWord_encodeWord]; rfl

def encodeIPPattern : IPPattern → Json
  | .exact a => Json.mkObj [("exact", encodeIPAddr a)]
  | .cidr c => Json.mkObj [("cidr", encodeCIDR c)]

def decodeIPPattern (j : Json) : Except String IPPattern := do
  if let .ok a := j.getObjVal? "exact" then return .exact (← decodeIPAddr a)
  if let .ok c := j.getObjVal? "cidr" then return .cidr (← decodeCIDR c)
  throw "unknown IP pattern"

theorem decodeIPPattern_encode (p : IPPattern) : decodeIPPattern (encodeIPPattern p) = .ok p := by
  cases p with
  | exact a =>
    show (do let x ← decodeIPAddr (encodeIPAddr a); pure (IPPattern.exact x)) = _
    rw [decodeIPAddr_encodeIPAddr]; rfl
  | cidr c =>
    show (do let x ← decodeCIDR (encodeCIDR c); pure (IPPattern.cidr x)) = _
    rw [decodeCIDR_encodeCIDR]; rfl

def encodeHostPattern : HostPattern → Json
  | .name p => Json.mkObj [("name", encodeNamePattern p)]
  | .ip p => Json.mkObj [("ip", encodeIPPattern p)]

def decodeHostPattern (j : Json) : Except String HostPattern := do
  if let .ok p := j.getObjVal? "name" then return .name (← decodeNamePattern p)
  if let .ok p := j.getObjVal? "ip" then return .ip (← decodeIPPattern p)
  throw "unknown host pattern"

theorem decodeHostPattern_encode (p : HostPattern) :
    decodeHostPattern (encodeHostPattern p) = .ok p := by
  cases p with
  | name q =>
    show (do let x ← decodeNamePattern (encodeNamePattern q); pure (HostPattern.name x)) = _
    rw [decodeNamePattern_encode]; rfl
  | ip q =>
    show (do let x ← decodeIPPattern (encodeIPPattern q); pure (HostPattern.ip x)) = _
    rw [decodeIPPattern_encode]; rfl

def encodePort (p : Port) : Json := encodeNat p.val

/-- 65535 を超えるポートは誤りにする（黙って切り詰めない）。 -/
def decodePort (j : Json) : Except String Port := do
  let n ← decodeNat j
  if h : n < 65536 then return ⟨n, h⟩ else throw "port outside 0..65535"

theorem decodePort_encodePort (p : Port) : decodePort (encodePort p) = .ok p := by
  obtain ⟨n, h⟩ := p
  show (do
    let n' ← decodeNat (encodeNat n)
    if h : n' < 65536 then (pure ⟨n', h⟩ : Except String Port) else throw "port outside 0..65535") = _
  rw [decodeNat_encodeNat]
  simp only [bind, Except.bind, pure, Except.pure, h, dite_true]

def encodeEndpointPattern (e : EndpointPattern) : Json :=
  Json.mkObj [("host", encodeHostPattern e.host),
    ("ports", Json.mkObj [("lo", encodePort e.ports.lo), ("hi", encodePort e.ports.hi)])]

def decodeEndpointPattern (j : Json) : Except String EndpointPattern := do
  let h ← decodeHostPattern (← j.getObjVal? "host")
  let ps ← j.getObjVal? "ports"
  return ⟨h, ⟨← decodePort (← ps.getObjVal? "lo"), ← decodePort (← ps.getObjVal? "hi")⟩⟩

theorem decodeEndpointPattern_encode (e : EndpointPattern) :
    decodeEndpointPattern (encodeEndpointPattern e) = .ok e := by
  obtain ⟨h, ⟨lo, hi⟩⟩ := e
  show (do
    let h' ← decodeHostPattern (encodeHostPattern h)
    let lo' ← decodePort (encodePort lo)
    let hi' ← decodePort (encodePort hi)
    pure (⟨h', ⟨lo', hi'⟩⟩ : EndpointPattern)) = _
  rw [decodeHostPattern_encode, decodePort_encodePort, decodePort_encodePort]; rfl

/-! ## 範囲と範囲の位置 -/

/-- 範囲の交換の形。Top は文字列 `"top"`、ほかは種類の名前を鍵に持つ一つの欄の対象である。 -/
def encodeRange : Range → Json
  | .top => .str "top"
  | .path p => Json.mkObj [("path", encodePathPattern p)]
  | .host p => Json.mkObj [("host", encodeHostPattern p)]
  | .endpoint p => Json.mkObj [("endpoint", encodeEndpointPattern p)]

def decodeRange (j : Json) : Except String Range := do
  if let .str "top" := j then return .top
  if let .ok p := j.getObjVal? "path" then return .path (← decodePathPattern p)
  if let .ok p := j.getObjVal? "host" then return .host (← decodeHostPattern p)
  if let .ok p := j.getObjVal? "endpoint" then return .endpoint (← decodeEndpointPattern p)
  throw "unknown range"

/-- 範囲の書き出しと読み込みの往復は元の範囲に戻る。 -/
theorem decodeRange_encodeRange (r : Range) : decodeRange (encodeRange r) = .ok r := by
  cases r with
  | top => rfl
  | path p =>
    show (do let x ← decodePathPattern (encodePathPattern p); pure (Range.path x)) = _
    rw [decodePathPattern_encode]; rfl
  | host p =>
    show (do let x ← decodeHostPattern (encodeHostPattern p); pure (Range.host x)) = _
    rw [decodeHostPattern_encode]; rfl
  | endpoint p =>
    show (do let x ← decodeEndpointPattern (encodeEndpointPattern p); pure (Range.endpoint x)) = _
    rw [decodeEndpointPattern_encode]; rfl

/-- 範囲の位置の交換の形。`{"fixed": 範囲}` か `{"rvar": 番号}`。`rvar` は組み込みの表の署名にだけ現れ、
corpus と表以外の sidecar では `Version.lean` の `exchangeJson` が拒否する。 -/
def encodeIx : Ix → Json
  | .fixed r => Json.mkObj [("fixed", encodeRange r)]
  | .rvar i => Json.mkObj [("rvar", encodeNat i)]

def decodeIx (j : Json) : Except String Ix := do
  if let .ok r := j.getObjVal? "fixed" then return .fixed (← decodeRange r)
  if let .ok i := j.getObjVal? "rvar" then return .rvar (← decodeNat i)
  throw "unknown range position"

theorem decodeIx_encodeIx (ix : Ix) : decodeIx (encodeIx ix) = .ok ix := by
  cases ix with
  | fixed r =>
    show (do let x ← decodeRange (encodeRange r); pure (Ix.fixed x)) = _
    rw [decodeRange_encodeRange]; rfl
  | rvar i =>
    show (do let x ← decodeNat (encodeNat i); pure (Ix.rvar x)) = _
    rw [decodeNat_encodeNat]; rfl

/-- 読み込みで欄の余りや別の綴りを残さない（書き戻した形と一致しない入力は誤りにする）。 -/
def decodeRangeStrict (j : Json) : Except String Range := do
  let r ← decodeRange j
  if encodeRange r != j then throw "noncanonical range fields"
  return r

def decodeIxStrict (j : Json) : Except String Ix := do
  let ix ← decodeIx j
  if encodeIx ix != j then throw "noncanonical range position fields"
  return ix

def encodeRanges (rs : List Range) : Json := .arr (rs.map encodeRange).toArray

def decodeRanges : Json → Except String (List Range)
  | .arr xs => xs.toList.mapM decodeRangeStrict
  | _ => .error "expected a range list"

instance : ToJson Range := ⟨encodeRange⟩
instance : FromJson Range := ⟨decodeRangeStrict⟩
instance : ToJson Ix := ⟨encodeIx⟩
instance : FromJson Ix := ⟨decodeIxStrict⟩

/-! ## 名前の原子・不透明型の本体と旧版の明示の Top -/

/-- 名前の原子の本体 `{"value": 名前, "ix": 範囲の位置}`（新版）。 -/
def encodeNameBody (l : String) (ix : Ix) : Json :=
  Json.mkObj [("value", .str l), ("ix", encodeIx ix)]

/-- 本体の内容を読む。欄の余りの拒否（書き戻した形との一致）は読み込みの側（`decodeAtom`）が別に行う。 -/
def decodeNameBody (o : Json) : Except String (String × Ix) := do
  let l ← o.getObjValAs? String "value"
  let ix ← decodeIx (← o.getObjVal? "ix")
  return (l, ix)

/-- 不透明型の本体 `{"name": 名前, "ix": 範囲の位置}`（新版）。 -/
def encodeOpaqueBody (n : String) (ix : Ix) : Json :=
  Json.mkObj [("name", .str n), ("ix", encodeIx ix)]

def decodeOpaqueBody (o : Json) : Except String (String × Ix) := do
  let n ← o.getObjValAs? String "name"
  let ix ← decodeIx (← o.getObjVal? "ix")
  return (n, ix)

/-- 旧版の明示の Top の範囲の位置。 -/
def legacyIx : Json := encodeIx Ix.top

/-- 対象 `inner` の欄の並びに欄 `(k, v)` を加えた対象。 -/
def withField (inner : Json) (k : String) (v : Json) : Json :=
  match inner with
  | .obj kvs => Json.mkObj (kvs.toArray.toList ++ [(k, v)])
  | j => j

/-- 旧版の一つの節点を新版の形にする。名前の原子 `{"name":{"value":l}}` と不透明型 `{"opaque":{"name":n}}` に明示の
Top の範囲の位置を、組み込みの呼び出し `{"prim":…}`・`{"primName":…}`（型引数の欄 `tys` を持つもの）に空の範囲の列を
加える。ほかの節点は変えない。鍵の一つだけの対象に限るので、`Definition` などの `name` の欄（文字列）は対象にならない。
旧版は先にこれらの欄を拒否してあるので（`exchangeJson`）、既存の欄を上書きしない。 -/
def legacyRangeNode (j : Json) : Json :=
  match j with
  | .obj kvs => match kvs.toArray.toList with
    | [("name", inner)] =>
        if (inner.getObjVal? "value").isOk then Json.mkObj [("name", withField inner "ix" legacyIx)] else j
    | [("opaque", inner)] =>
        if (inner.getObjVal? "name").isOk then Json.mkObj [("opaque", withField inner "ix" legacyIx)] else j
    | [("prim", inner)] =>
        if (inner.getObjVal? "tys").isOk then Json.mkObj [("prim", withField inner "ranges" (.arr #[]))] else j
    | [("primName", inner)] =>
        if (inner.getObjVal? "tys").isOk then Json.mkObj [("primName", withField inner "ranges" (.arr #[]))]
        else j
    | _ => j
  | _ => j

/-- `legacyRangeNode` と同じ節点に、欠けている欄だけを加える（既存の欄を上書きしない。L50.2）。区間解析の独立交換の
埋め込みの Surface は、版 14 では範囲の欄を全て拒否してからこれで明示の Top を加え、版 15 では欠けた欄がないこと
（この変換で変わらないこと）を確かめる。 -/
def legacyRangeNodeMissing (j : Json) : Json :=
  match j with
  | .obj kvs => match kvs.toArray.toList with
    | [("name", inner)] =>
        if (inner.getObjVal? "value").isOk && !(inner.getObjVal? "ix").isOk then
          Json.mkObj [("name", withField inner "ix" legacyIx)] else j
    | [("opaque", inner)] =>
        if (inner.getObjVal? "name").isOk && !(inner.getObjVal? "ix").isOk then
          Json.mkObj [("opaque", withField inner "ix" legacyIx)] else j
    | [("prim", inner)] =>
        if (inner.getObjVal? "tys").isOk && !(inner.getObjVal? "ranges").isOk then
          Json.mkObj [("prim", withField inner "ranges" (.arr #[]))] else j
    | [("primName", inner)] =>
        if (inner.getObjVal? "tys").isOk && !(inner.getObjVal? "ranges").isOk then
          Json.mkObj [("primName", withField inner "ranges" (.arr #[]))] else j
    | _ => j
  | _ => j

/-- 旧版の Rust が書き出す名前の原子。 -/
def legacyNameAtomJson (l : String) : Json := Json.mkObj [("name", Json.mkObj [("value", .str l)])]

/-- 旧版の Rust が書き出す不透明型。 -/
def legacyOpaqueJson (n : String) : Json := Json.mkObj [("opaque", Json.mkObj [("name", .str n)])]

/-- 旧版の名前の原子は、明示の Top の範囲の位置を持つ名前の原子として読む（暗黙に狭い範囲として読まない）。 -/
theorem legacy_name_atom_top (l : String) :
    ((legacyRangeNode (legacyNameAtomJson l)).getObjVal? "name" >>= decodeNameBody) = .ok (l, Ix.top) := by
  rfl

/-- 旧版の不透明型は、明示の Top の範囲の位置を持つ不透明型として読む。 -/
theorem legacy_opaque_top (n : String) :
    ((legacyRangeNode (legacyOpaqueJson n)).getObjVal? "opaque" >>= decodeOpaqueBody) = .ok (n, Ix.top) := by
  rfl

/-! ## 署名の IO の形と表のデータ -/

def encodeIOShape : IOShape → Json
  | .untargeted => .str "untargeted"
  | .topTargeted k => Json.mkObj [("topTargeted", Json.mkObj [("kind", encodeKind k)])]
  | .single k p => Json.mkObj [("single", Json.mkObj [("kind", encodeKind k), ("position", encodeNat p)])]

def decodeIOShape (j : Json) : Except String IOShape := do
  if let .str "untargeted" := j then return .untargeted
  if let .ok o := j.getObjVal? "topTargeted" then return .topTargeted (← decodeKind (← o.getObjVal? "kind"))
  if let .ok o := j.getObjVal? "single" then
    return .single (← decodeKind (← o.getObjVal? "kind")) (← decodeNat (← o.getObjVal? "position"))
  throw "unknown IO shape"

theorem decodeIOShape_encode (s : IOShape) : decodeIOShape (encodeIOShape s) = .ok s := by
  cases s with
  | untargeted => rfl
  | topTargeted k => cases k <;> rfl
  | single k p =>
    show (do
      let k' ← decodeKind (encodeKind k)
      let p' ← decodeNat (encodeNat p)
      pure (IOShape.single k' p')) = _
    rw [decodeKind_encodeKind, decodeNat_encodeNat]; rfl

instance : ToJson IOShape := ⟨encodeIOShape⟩
instance : FromJson IOShape := ⟨fun j => do
  let s ← decodeIOShape j
  if encodeIOShape s != j then throw "noncanonical IO shape fields"
  return s⟩

/-- 範囲の具体化の制約の交換の形（表のデータ `admitsR` の有限の記述）。`any` は種類と個数の合う全ての列を許し
（種類・個数・正規形は `Builtins.RangeAdmissible` の側が確かめる）、`covers i j` は j 番目の範囲が i 番目の範囲を
覆う列だけを許す（明示拡大の被覆）。表にない項目は Top の列だけを許す（`Builtins.admitsR` の既定）。 -/
inductive AdmitsRule where
  | any
  | covers (inner outer : Nat)
  deriving DecidableEq, Repr

def encodeAdmitsRule : AdmitsRule → Json
  | .any => .str "any"
  | .covers i j => Json.mkObj [("covers", Json.mkObj [("inner", encodeNat i), ("outer", encodeNat j)])]

def decodeAdmitsRule (j : Json) : Except String AdmitsRule := do
  if let .str "any" := j then return .any
  if let .ok o := j.getObjVal? "covers" then
    return .covers (← decodeNat (← o.getObjVal? "inner")) (← decodeNat (← o.getObjVal? "outer"))
  throw "unknown range admission rule"

instance : ToJson AdmitsRule := ⟨encodeAdmitsRule⟩
instance : FromJson AdmitsRule := ⟨fun j => do
  let r ← decodeAdmitsRule j
  if encodeAdmitsRule r != j then throw "noncanonical range admission fields"
  return r⟩

/-- 規則が許す範囲の列。 -/
def AdmitsRule.Holds : AdmitsRule → List Range → Prop
  | .any, _ => True
  | .covers i j, rs => ∃ r s, rs[i]? = some r ∧ rs[j]? = some s ∧ s.Covers r

/-- 規則の判定。 -/
def AdmitsRule.check : AdmitsRule → List Range → Bool
  | .any, _ => true
  | .covers i j, rs => match rs[i]?, rs[j]? with
    | some r, some s => s.covers? r
    | _, _ => false

theorem AdmitsRule.check_sound {a : AdmitsRule} {rs : List Range} (h : a.check rs = true) : a.Holds rs := by
  cases a with
  | any => trivial
  | covers i j =>
    simp only [AdmitsRule.check] at h
    cases hi : rs[i]? with
    | none => simp [hi] at h
    | some r =>
      cases hj : rs[j]? with
      | none => simp [hi, hj] at h
      | some s =>
        simp only [hi, hj] at h
        exact ⟨r, s, hi, hj, (Range.covers?_spec s r).mp h⟩

/-- 名前ごとの種類（`effKind`・`valKind` の有限の表）。 -/
structure KindEntry where
  name : String
  kind : Kind
  deriving ToJson, FromJson

/-- 組み込みの関数ごとの範囲の具体化の制約（`admitsR` の有限の表）。 -/
structure AdmitsEntry where
  name : String
  rule : AdmitsRule
  deriving ToJson, FromJson

/-- 有限の表の先頭の項目を引く。同じ名前の重複は `readBuiltins` が拒否する。 -/
def KindEntry.lookup (xs : List KindEntry) (n : String) : Option Kind :=
  (xs.find? (·.name == n)).map (·.kind)

/-- 表の `admitsR`: 名前の項目の規則が許す列。項目のない名前は何も許さない（Top の列は `RangeAdmissible` が許す）。 -/
def AdmitsEntry.admitsR (xs : List AdmitsEntry) (b : String) (rs : List Range) : Prop :=
  match xs.find? (·.name == b) with
  | some e => e.rule.Holds rs
  | none => False

/-- 表の `admitsR` の判定（検査の入力 `admitsRDec`）。 -/
def AdmitsEntry.admitsRDec (xs : List AdmitsEntry) (b : String) (rs : List Range) : Bool :=
  match xs.find? (·.name == b) with
  | some e => e.rule.check rs
  | none => false

/-- 判定は表の `admitsR` と合う（`CheckRanges.AdmitsRDecSound` の内容）。 -/
theorem AdmitsEntry.admitsRDec_sound {xs : List AdmitsEntry} {b : String} {rs : List Range}
    (h : AdmitsEntry.admitsRDec xs b rs = true) : AdmitsEntry.admitsR xs b rs := by
  unfold AdmitsEntry.admitsRDec at h
  unfold AdmitsEntry.admitsR
  cases hf : xs.find? (·.name == b) with
  | none => simp [hf] at h
  | some e => simp only [hf] at h ⊢; exact AdmitsRule.check_sound h

end Benitoite.Exchange
