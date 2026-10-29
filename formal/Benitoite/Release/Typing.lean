import Benitoite.Release.Subst
import Benitoite.Release.NoFail
import Benitoite.Release.RangeInstDef
import Benitoite.Release.EffectCoverDef

/-!
# 型付け規則（段階 B）

設計書 01-12 の型付け規則に、「初回リリース版の拡張」の制御の構成の型付けを加える。
計算の判断は 01-12 の `Γ; R ⊢c M : A ! ε` であり、値の判断にはストアの型付け Ψ を加える。

段階 A からの表現の違い:

- 型付けの判断は、型パラメータの組み込みの制約の並び `C`（型の変数の番号の順）を持つ（01-12「型パラメータの組み込みの制約」）。V-Prim は
  組み込みの関数の型パラメータの制約を `C` のもとで確かめ、V-Fun は型引数が関数の型パラメータの制約を
  満たすことを確かめる。型が制約を満たすか（等値の型・鍵の型）は 01-06 に委ね、`Builtins.sat` で与える。
- 環境 Γ の要素は `Option Ty` である。V-Lam の前提と `lazy M` の M の検査では、Γ から継続の型を持つ変数を
  除く（01-12「ハンドラ」）。番号で表した変数を除くと番号がずれるので、要素を `none` に置き換えて表す。
- 型クラスのメソッドの型と実装の定義は、型の変数を番号で表す（`Syntax.lean` の `MethSig`・`ImplDecl`）。
  D-Impl のメソッドの本体の型付けは、メソッドの型パラメータを内側（番号 `0..g-1`）、実装の型パラメータを
  外側に並べた制約の並びで行う。
- `handle` の節が処理する操作の型パラメータは、節の中で型の変数の番号 `0..k-1` に束縛し、制約の並びの
  先頭に加える（01-06「エフェクトの宣言とハンドラの型付け（初回リリース版）」）。節の外側の型（環境の型、
  `handle` の式の型、R）は、節の中では番号を k だけずらす。
-/

noncomputable section

namespace Benitoite.Release

/-! ## 組み込みの関数 -/

abbrev ErrKind := String

/-- 組み込みの関数の結果。値、実行時エラー、プロセスの終了（E-Exit の `b(W̄) ↦ exit(n)`）。 -/
inductive Outcome where
  | val (v : Val)
  | err (r : ErrKind)
  | exit (n : Int)

/-- 組み込みの関数の種類。ストアの規則（E-RefNew など）を使う関数は、E-Prim・E-IO を使わない
（01-12「ストア：可変のセルと明示遅延」）。終了状態を指定したプロセスの終了の関数（`exit`）には、E-IO を使わず
E-Exit を使う（01-12「プロセスの終了」）。 -/
inductive PrimKind where
  | pure | io | exit | refNew | refGet | refSet | refUpdate | force
  deriving DecidableEq

structure PrimSig where
  tparams : List TParam
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  /-- 型パラメータの制約（組み込みの制約と演算子の型の集まり）。制約の並び `C` のもとで判定する。 -/
  admits : List TParam → List Ty → Prop
  kind : PrimKind
  /-- 組み込みのエフェクトの操作のとき、そのエフェクトの名前。 -/
  opEff : Option EffName
  /-- 署名の範囲の変数ごとの対象の種類（問 2・4、RV-L00 軽7）。範囲の変数 `Ix.rvar i` の i 番目の種類である。
  既定は空の列（範囲の変数のない旧の項目）。既定の空の列のまま `rvar` を書いた項目は、`PrimSig.Scoped` の
  番号の上限で拒否される（範囲を書かないと黙って Top になる既定引数とは別である）。 -/
  rkinds : List Scope.Domain.Kind := []
  /-- IO を行う項目の形（`Scope.Signature.IOShape`。問 7〜9）。対象なし（`untargeted`）、旧 Top の対象あり
  （`topTargeted k`）、単一の対象（`single k p`。引数の位置 p が種類 k の範囲付きの値型）のどれかである。
  `Builtins.Assumptions` の `io_op`（形の検査 `Builtins.ShapeOk`）が効果・範囲の変数・引数と照らし合わせ、
  `io_target`（`TargetAgreement`）が観測の条件に使う。IO を行わない項目は読まない。既定は対象なし。 -/
  shape : Scope.Signature.IOShape := .untargeted

def PrimSig.ntys (s : PrimSig) : Nat := s.tparams.length

/-- 値が保持する検査済みの対象（`Scope.Signature.ShapeTargets` の `target?`）。検査済みの要求の値は実効の endpoint を返す。 -/
def Val.target? : Val → Option Scope.Domain.Target
  | .checked t => some t
  | .checkedRequest t _ => some t
  | _ => none

/-- 署名の範囲の変数の個数（`rkinds` の長さ）。範囲の変数の番号はこの個数より小さい（`PrimSig.Scoped`）。 -/
def PrimSig.nranges (s : PrimSig) : Nat := s.rkinds.length

/-- 組み込みの関数と、01-12 がほかの章に委ねているもの。 -/
structure Builtins where
  sig : PrimName → Option PrimSig
  /-- IO を行わない組み込みの関数の値 δ(b[T̄; Ē], W̄)（01-12「実行の規則」）。 -/
  delta : PrimName → List Ty → List Eff → List Scope.Domain.Range → List Val → Option Outcome
  /-- IO を行う組み込みの関数の応答と、その応答で作用した対象の観測（有限列）として起こりうるもの
  （問 8 の O1。観測は応答の関係に含める。設計書 01-12「実行の規則」）。 -/
  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Scope.Domain.Target → Prop
  /-- 事象 `release(V)` の応答として起こりうるもの。`none` が `ok`、`some r` が `error(r)`。 -/
  releaseResponse : Val → Option ErrKind → Prop
  /-- リソースの型か。リソースの型の解放のエフェクト `rel(O_r)` は `{State}` である。 -/
  isResource : OpaqueName → Bool
  /-- 組み込みのエフェクトと、その操作。`State` は操作を持たない。 -/
  effects : EffName → Option (List PrimName)
  /-- 型が組み込みの制約を満たすか（01-06「等値の型」「鍵の型（初回リリース版）」）。制約の並び `C` のもとで判定する。 -/
  sat : List TParam → Ty → TParam → Prop
  /-- `Reference.get` と `Reference.set` の名前。`Reference.update` の遷移が使う。 -/
  refGet : PrimName
  refSet : PrimName
  /-- エフェクトの名前の対象の種類（`File.Read`・`File.Write` は path、`Http.Connect` は endpoint）。対象を持たない
  名前は `none` である。表のデータであり、正しさは信頼の対象である（問 11、設計書 07-04「形式化で仮定するもの」）。
  `Builtins.Assumptions` の欄にはしない。既定は全て `none`。 -/
  effKind : EffName → Option Scope.Domain.Kind := fun _ => none
  /-- 範囲付きの値型の名前の対象の種類（`Scope.PathIn` は path、`Http.RequestIn` は endpoint）。既存の不透明型と
  資源の型は `none` である（RV-PL10 中3 (b)）。表のデータであり、正しさは信頼の対象である。既定は全て `none`。 -/
  valKind : OpaqueName → Option Scope.Domain.Kind := fun _ => none
  /-- 組み込みの関数ごとの範囲の具体化の制約（明示拡大の被覆など。型引数の `admits` に当たる）。全て Top の列は
  この制約によらず許す（`Builtins.RangeAdmissible`）。表のデータであり、正しさは信頼の対象である。既定は何も
  許さない（Top の列だけを許す）。 -/
  admitsR : PrimName → List Scope.Domain.Range → Prop := fun _ _ => False
  /-- 範囲付きの値型の名前の値が保持する要求の型（`Http.RequestIn` は `Http.ClientRequest` のレコードの型）。検査済みの
  要求の値の規則 V-CheckedRequest が読む。表のデータであり、正しさは信頼の対象である。既定は全て `none`。 -/
  valContent : OpaqueName → Option Ty := fun _ => none

/-! ## 署名の具体化と範囲の具体化の許容 -/

/-- 署名の具体化 `s.inst rs`。引数は最上位の対象の位置だけを、結果と効果は全ての位置を具体化する。名前・型
パラメータ・制約・種類・範囲の変数の種類は変えない。 -/
noncomputable def PrimSig.inst (rs : List Scope.Domain.Range) (s : PrimSig) : PrimSig :=
  { s with params := s.params.map (Ty.instTarget rs), ret := s.ret.instR rs, eff := Eff.instR rs s.eff }


/-- 範囲の具体化の許容（問 4、RV-L00 軽7、RV-L10 中1）。採用定義 `Scope.Signature.RangeAdmissible`（範囲の変数
ごとの種類 `rkinds` に置けること。個数の一致を含む。整形式性と項目の制約）に、範囲の正規形を加える。項目の制約は
表のデータ `B.admitsR b` であり、全て Top の列はこの制約によらず許す。プログラムの型の注釈の範囲の正規形と整形式性は
解析器の側で扱い、ここでは条件にしない（問 4、設計書 07-04「形式化で仮定するもの」）。 -/
def Builtins.RangeAdmissible (B : Builtins) (b : PrimName) (s : PrimSig) (rs : List Scope.Domain.Range) : Prop :=
  Scope.Signature.RangeAdmissible s.rkinds (fun rs => (∀ r ∈ rs, r = .top) ∨ B.admitsR b rs) rs ∧
    ∀ r ∈ rs, r.Canonical


/-- 署名の範囲の変数の個数の長さの Top の列。脱糖と節の型付けが使う具体化である（節の添字は Top）。 -/
abbrev PrimSig.topRanges (s : PrimSig) : List Scope.Domain.Range := List.replicate s.nranges .top

def fnTy (names : List String) (params : List Ty) (ret : Ty) (eff : Eff) (ts : List Ty) (es : List Eff) : Ty :=
  Ty.subst ts es (.fn names params ret eff)

/-- 型引数 `ts` が、型パラメータの制約 `tps` を、制約の並び `C` のもとで満たす。制約の並びは、型の変数の番号の
順（内側から）に並べる。 -/
def SatAll (B : Builtins) (C : List TParam) (ts : List Ty) (tps : List TParam) : Prop :=
  ts.length = tps.length ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → tps[i]? = some p → B.sat C t p

/-! ## 操作 -/

/-- 操作の型 `∀ᾱ. (Ā) → B ! {L}`。 -/
structure OpSig where
  tparams : List TParam
  names : List String
  params : List Ty
  ret : Ty
  eff : EffName

def opSig (P : Program) (B : Builtins) : OpRef → Option OpSig
  | .fail => none
  | .user o => (P.ops o).map fun od => ⟨od.tparams, od.names, od.params, od.ret, od.eff⟩
  | .prim b =>
      match B.sig b with
      | some s =>
          match s.opEff with
          | some l => some ⟨s.tparams, s.names, s.params.map (Ty.instTarget s.topRanges), s.ret, l⟩
          | none => none
      | none => none

/-- 捕捉した組み込みの操作の型を節の添字 S で具体化した操作の型（L30.1）。組み込みの操作では引数を
`Ty.instTarget` で S の列（長さは範囲の変数の個数）に具体化し、結果は `s.ret` のままにする（組み込みの操作の結果の
型は範囲の変数を持たない。`PrimSig.Scoped` の操作の結果の条件）。利用者の操作は `opSig` と同じで S によらない。
`Ty.instTarget` だけで書くので計算できる。 -/
def opSigAt (P : Program) (B : Builtins) (S : Scope.Domain.Range) : OpRef → Option OpSig
  | .fail => none
  | .user o => (P.ops o).map fun od => ⟨od.tparams, od.names, od.params, od.ret, od.eff⟩
  | .prim b =>
      match B.sig b with
      | some s =>
          match s.opEff with
          | some l => some ⟨s.tparams, s.names, s.params.map (Ty.instTarget (List.replicate s.nranges S)), s.ret, l⟩
          | none => none
      | none => none

/-- 節の添字の規則の条件（判断 11）。保護本体の効果 e が行の変数を持たず、名前 l の原子をちょうど一つ持ち、
その範囲の位置が閉じた範囲 r である。 -/
def Eff.ClauseRangeIs (e : Eff) (l : EffName) (r : Scope.Domain.Range) : Prop :=
  (∀ i, ¬ Eff.mem e (.rho i)) ∧ Eff.mem e (.name l (.fixed r)) ∧
    ∀ ix, Eff.mem e (.name l ix) → ix = .fixed r

open Classical in
/-- 節の添字の規則（判断 11）。保護本体の効果 e に名前 l の閉じた原子がちょうど一つだけあればその範囲、
複数の原子・同名の Top・未確定の行の変数・同名の原子なしの場合は Top とする。節の本体や期待される出力を読まない。 -/
noncomputable def Eff.clauseRange (e : Eff) (l : EffName) : Scope.Domain.Range :=
  if h : ∃ r, e.ClauseRangeIs l r then Classical.choose h else .top

/-- 節の添字 S の許容（L30.1）。S は Top か、操作 o が組み込みの操作でエフェクトの名前 l を持ち、S が保護本体の
効果 e についての規則の値（`Eff.ClauseRangeIs`）である。型付けは規則の値のほかに Top も許す。型の代入で行の
変数を具体化すると規則の値が変わりうるので、代入の前に Top で型付けた節を代入の後も型付けるためである
（`ClauseIxOk.substAt`）。 -/
def ClauseIxOk (B : Builtins) (e : Eff) (o : OpRef) (S : Scope.Domain.Range) : Prop :=
  S = .top ∨ ∃ b s l, o = .prim b ∧ B.sig b = some s ∧ s.opEff = some l ∧ e.ClauseRangeIs l S

/-- 節の操作の型（L30.1）。保護本体の効果 e から許容される節の添字 S を選び、操作の型を S で具体化する。 -/
def ClauseSig (P : Program) (B : Builtins) (e : Eff) (o : OpRef) (sg : OpSig) : Prop :=
  ∃ S, ClauseIxOk B e o S ∧ opSigAt P B S o = some sg

/-- 節の添字が Top のとき、`opSigAt` は `opSig` である。 -/
theorem opSigAt_top (P : Program) (B : Builtins) (o : OpRef) : opSigAt P B .top o = opSig P B o := by
  cases o <;> rfl

/-- 利用者の操作の型は節の添字によらない。 -/
theorem opSigAt_user (P : Program) (B : Builtins) (S : Scope.Domain.Range) (o : OpName) :
    opSigAt P B S (.user o) = opSig P B (.user o) := rfl

/-- 操作の型を持つ節の操作は Fail ではない。 -/
theorem ClauseSig.ne_fail {P : Program} {B : Builtins} {e : Eff} {o : OpRef} {sg : OpSig}
    (h : ClauseSig P B e o sg) : o ≠ .fail := by
  obtain ⟨S, -, h⟩ := h
  rintro rfl
  cases h

/-- Top の節の添字はどの保護本体の効果のもとでも許される。 -/
theorem ClauseSig.of_opSig {P : Program} {B : Builtins} {e : Eff} {o : OpRef} {sg : OpSig}
    (h : opSig P B o = some sg) : ClauseSig P B e o sg :=
  ⟨.top, Or.inl rfl, by rw [opSigAt_top]; exact h⟩

/-- 利用者の操作の節の操作の型は `opSig` である。 -/
theorem ClauseSig.user {P : Program} {B : Builtins} {e : Eff} {o : OpName} {sg : OpSig}
    (h : ClauseSig P B e (.user o) sg) : opSig P B (.user o) = some sg := by
  obtain ⟨S, -, h⟩ := h
  exact h

/-- 操作の辞書数。組み込みの操作は辞書を持たない。 -/
def opDictCount (P : Program) : OpRef → Nat
  | .user o => ((P.ops o).map fun d => d.dictParams.length).getD 0
  | .prim _ | .fail => 0

/-- エフェクト L の操作の一覧。利用者が宣言したエフェクトか、組み込みのエフェクト。 -/
def effOps (P : Program) (B : Builtins) (l : EffName) : Option (List OpRef) :=
  match P.effects l with
  | some os => some (os.map .user)
  | none => (B.effects l).map (·.map .prim)

/-- `handles(H, op)`。 -/
def handles (h : List Clause) (o : OpRef) : Bool := h.any (fun c => c.op == o)

/-- `handled(H)`。一つ以上の操作を持ち、そのすべての操作の節を H が持つエフェクトの集合。名前の原子は
範囲の位置 r を見ずに名前だけで判定する（`handled_name`）。 -/
def handled (P : Program) (B : Builtins) (h : List Clause) : Eff := Eff.ofAtoms fun a =>
  match a with
  | .name l _ =>
      match effOps P B l with
      | some (o :: os) => (o :: os).all (handles h)
      | _ => false
  | .rho _ => false

/-- `handled(H)` は名前の原子の範囲の位置を見ない。名前の全操作の節がそろえば、その名前のどの範囲の原子も
除く（判断 11。範囲の一部だけの処理を加えない）。 -/
theorem handled_name (P : Program) (B : Builtins) (h : List Clause) (l : EffName)
    (r : Scope.Signature.Ix) : Eff.test (handled P B h) (.name l r) = Eff.test (handled P B h) (.nameTop l) :=
  rfl

/-- 範囲の位置の違う二つの名前の原子は、`handled(H)` に同時に含まれるか、同時に含まれない。 -/
theorem mem_handled_name_iff (P : Program) (B : Builtins) (h : List Clause) (l : EffName)
    (r s : Scope.Signature.Ix) : Eff.mem (handled P B h) (.name l r) ↔ Eff.mem (handled P B h) (.name l s) := by
  simp only [Eff.mem, handled_name]

/-! ## 型の正しさ -/

mutual
  /-- 型の中の型の変数の番号が `n` より小さく（その位置で束縛された型の変数だけを使う）、範囲の位置の範囲の変数の
  番号が `nr` より小さい（`Scope.Signature.Ix.WF nr`）。プログラムの型は `nr = 0` で読み、範囲の変数を置かせない
  （問 3 の P1）。 -/
  def Ty.WF (nr n : Nat) : Ty → Prop
    | .base _ => True
    | .opaque _ ix => ix.WF nr
    | .data _ args => Ty.WFList nr n args
    | .list a => Ty.WF nr n a
    | .fn names params ret e => NamesWF names params ∧ Ty.WFList nr n params ∧ Ty.WF nr n ret ∧ Eff.WF nr n e ∧ Eff.Canonical e
    | .tvar i => i < n
    | .reference a => Ty.WF nr n a
    | .lazy a => Ty.WF nr n a
    | .cont b t e => Ty.WF nr n b ∧ Ty.WF nr n t ∧ Eff.WF nr n e ∧ Eff.Canonical e
    | .map a b => Ty.WF nr n a ∧ Ty.WF nr n b
    | .set a => Ty.WF nr n a
    | .bytes => True
    | .dict _ τ => Ty.WF nr n τ
    | .tapp i args => i < n ∧ Ty.WFList nr n args
    | .ctor _ => True

  def Ty.WFList (nr n : Nat) : List Ty → Prop
    | [] => True
    | a :: as => Ty.WF nr n a ∧ Ty.WFList nr n as

  /-- 効果の Fail 型がその位置の型変数・範囲の変数の範囲と正規形の条件を満たす。
  計算の最上位の効果の列自体には Canonical を求めない。名前の原子の範囲の位置は、ここでは検査せず、宣言と項の
  変数の範囲（`Ty.VarsIn`・`Eff.VarsIn`）で検査する。継続の型付け（`K_Handle_Fail` の `Rest` など）が導出の中で
  選ぶ効果にも整形式が求められるので、原子の条件をここに置くと継続の規則に新しい前提が要るためである。 -/
  def Eff.WF (nr n : Nat) : Eff → Prop
    | .mk _ fs => Ty.WFList nr n fs
end

structure Admissible (B : Builtins) (C : List TParam)
    (tps : List TParam) (ne : Nat) (Qs Qt : NoFailCtx)
    (ts : List Ty) (es : List Eff) (e : Eff) : Prop where
  types : SatAll B C ts tps
  typeScope : ∀ t ∈ ts, Ty.WF 0 C.length t ∧ ∀ b r e, t ≠ .cont b r e
  rowCount : es.length = ne
  rowScope : ∀ f ∈ es, Eff.WF 0 C.length f
  sourceRows : Eff.RowsIn (· < es.length) e
  sourceQ : ∀ i, Qs i → i < es.length
  noFailRows : RowTransport Qs Qt es

structure PrimitiveAdmissible (C : List TParam) (s : PrimSig)
    (Q : NoFailCtx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = s.ntys
  admits : s.admits C ts
  typeScope : ∀ t ∈ ts, Ty.WF 0 C.length t ∧ ∀ b r e, t ≠ .cont b r e
  rowCount : es.length = s.neffs
  rowScope : ∀ f ∈ es, Eff.WF 0 C.length f
  sourceRows : Eff.RowsIn (· < es.length) s.eff
  sourceQ : ∀ i, Qsig s.params s.ret s.eff i → i < es.length
  noFailRows : RowTransport (Qsig s.params s.ret s.eff) Q es

def MethodRowsAdmissible (C : List TParam) (Q : NoFailCtx) (ms : MethSig)
    (es : List Eff) : Prop :=
  es.length = ms.neffs ∧ (∀ f ∈ es, Eff.WF 0 C.length f) ∧
  Eff.RowsIn (· < es.length) ms.eff ∧
  (∀ i, Qsig ms.params ms.ret ms.eff i → i < es.length) ∧
  RowTransport (Qsig ms.params ms.ret ms.eff) Q es


/-! ## 型の包含 -/

/-- 型の包含。関数の型だけが、潜在効果を判断 5 の一原子の被覆（`Eff.Covers`。外側が先）で広げられる（判断 10 の
最外側の関数のエフェクトの拡大。L40.6c）。入れ子の関数型・リストの要素・値型の添字へは広げない。 -/
def Ty.Le (a a' : Ty) : Prop :=
  a = a' ∨ ∃ names ps r ε ε', a = .fn names ps r ε ∧ a' = .fn names ps r ε' ∧ Eff.Covers ε' ε

/-! ## ストアの型付けと環境 -/

/-- ストアの場所の型。可変のセル、明示遅延、継続（継続の型と、継続を作った節の R）。 -/
inductive LocTy where
  | builder (kind : BuilderKind)
  | ref (a : Ty)
  | lazy (a : Ty)
  | cont (b t : Ty) (ε : Eff) (r : Option Ty)

/-- ストアの型付け Ψ。 -/
abbrev StoreTy := Nat → Option LocTy

/-- 既に型のある場所を同じ型で保つ拡張。 -/
def StoreTy.Sub (Ψ Ψ' : StoreTy) : Prop := ∀ l x, Ψ l = some x → Ψ' l = some x

/-- 専用セルの位置だけを隠し、場所の番号を保つ。 -/
abbrev StoreTy.hideBuilders (Ψ : StoreTy) : StoreTy := fun l =>
  match Ψ l with
  | some (.builder _) => none
  | x => x

@[simp] theorem hideBuilders_idem (Ψ : StoreTy) :
    Ψ.hideBuilders.hideBuilders = Ψ.hideBuilders := by
  funext l
  cases h : Ψ l with
  | none => simp [StoreTy.hideBuilders, h]
  | some x => cases x <;> simp [StoreTy.hideBuilders, h]

@[simp] theorem hideBuilders_ref (Ψ : StoreTy) (l : Nat) (a : Ty) :
    Ψ.hideBuilders l = some (.ref a) ↔ Ψ l = some (.ref a) := by
  cases h : Ψ l with
  | none => simp [StoreTy.hideBuilders, h]
  | some x => cases x <;> simp [StoreTy.hideBuilders, h]

@[simp] theorem hideBuilders_lazy (Ψ : StoreTy) (l : Nat) (a : Ty) :
    Ψ.hideBuilders l = some (.lazy a) ↔ Ψ l = some (.lazy a) := by
  cases h : Ψ l with
  | none => simp [StoreTy.hideBuilders, h]
  | some x => cases x <;> simp [StoreTy.hideBuilders, h]

@[simp] theorem hideBuilders_cont (Ψ : StoreTy) (l : Nat) (b t : Ty) (e : Eff) (r : Option Ty) :
    Ψ.hideBuilders l = some (.cont b t e r) ↔ Ψ l = some (.cont b t e r) := by
  cases h : Ψ l with
  | none => simp [StoreTy.hideBuilders, h]
  | some x => cases x <;> simp [StoreTy.hideBuilders, h]

/-- 環境から継続の型を持つ変数を除く。番号をずらさないように、要素を `none` にする。 -/
def hideConts (Γ : List (Option Ty)) : List (Option Ty) :=
  Γ.map fun o => match o with
    | some (.cont _ _ _) => none
    | x => x

/-- 型の並びを、環境に加える形にする。 -/
def binds (as : List Ty) : List (Option Ty) := as.reverse.map some

/-- 環境の型の番号をずらす（節の内側に入るとき）。 -/
def shiftEnv (k : Nat) (Γ : List (Option Ty)) : List (Option Ty) := Γ.map (Option.map (Ty.shift k 0))

/-! ## パターンと網羅性 -/

/-- 残りを束縛する場合だけ List の型を一つ加える。 -/
def restTys (rest : Option ListRest) (a : Ty) : List Ty :=
  match rest with
  | some .bind => [.list a]
  | _ => []

mutual
  inductive PatTy (P : Program) : Pat → Ty → List Ty → Prop
    | P_Wild {a} : PatTy P .wild a []
    | P_Var {a} : PatTy P .var a [a]
    | P_Const {c} :
        c.patternAllowed = true →
        PatTy P (.const c) c.type []
    | P_RangeInt {lo hi : Integer64Value} :
        PatTy P (.range (.integer lo) (.integer hi)) (.base .integer) []
    | P_RangeChar {lo hi : Char} :
        PatTy P (.range (.character lo) (.character hi)) (.base .character) []
    | P_List {before rest after a δb δa} :
        PatTys P before (List.replicate before.length a) δb →
        PatTys P after (List.replicate after.length a) δa →
        (rest = none → after = []) →
        PatTy P (.list before rest after) (.list a) (δb ++ restTys rest a ++ δa)
    | P_Con {c ps cd ts δ} :
        P.cons c = some cd → ts.length = cd.ntys →
        PatTys P ps (cd.args.map (Ty.subst ts [])) δ →
        PatTy P (.con c ps) (.data cd.data ts) δ

  inductive PatTys (P : Program) : List Pat → List Ty → List Ty → Prop
    | nil : PatTys P [] [] []
    | cons {p ps a as δ δs} :
        PatTy P p a δ → PatTys P ps as δs → PatTys P (p :: ps) (a :: as) (δ ++ δs)
end

mutual
  /-- 網羅性を考えるうえでの値の形。パターンが中を調べない型（関数の型、型パラメータ、セル、明示遅延、
  継続、マップ、集合、バイト列、辞書、型パラメータの適用、型構成子）には、どの値も属するとする。 -/
  inductive Inhabits (P : Program) : Ty → Val → Prop
    | const {c} : Inhabits P c.type (.const c)
    | con {c ts tys' args cd} :
        P.cons c = some cd → cd.ntys = ts.length →
        InhabitsAll P (cd.args.map (Ty.subst ts [])) args →
        Inhabits P (.data cd.data ts) (.con c tys' args)
    | list {a elems} : InhabitsEach P a elems → Inhabits P (.list a) (.list elems)
    | fn {names ps r ε v} : Inhabits P (.fn names ps r ε) v
    | tvar {i v} : Inhabits P (.tvar i) v
    | reference {a v} : Inhabits P (.reference a) v
    | lazy {a v} : Inhabits P (.lazy a) v
    | cont {b t ε v} : Inhabits P (.cont b t ε) v
    | map {a b v} : Inhabits P (.map a b) v
    | set {a v} : Inhabits P (.set a) v
    | bytes {v} : Inhabits P .bytes v
    | dict {cl τ v} : Inhabits P (.dict cl τ) v
    | tapp {i as v} : Inhabits P (.tapp i as) v
    | ctor {φ v} : Inhabits P (.ctor φ) v
    /-- 検査済みの対象の値は範囲付きの値型に属する（V-Checked に対応する。不透明型の定数は `const` の場合）。
    パターンは検査済みの対象の値の中を調べないので、網羅性には変数か `_` の選択肢が要る。旧の像（範囲が Top の
    不透明型）では不透明型の定数が既に属するので、網羅性の判断は変わらない（`Exhaustive.opaqueTop_iff`）。 -/
    | checked {o R t} : Inhabits P (.opaque o (.fixed R)) (.checked t)
    /-- 検査済みの要求の値も範囲付きの値型に属する（V-CheckedRequest に対応する）。 -/
    | checkedRequest {o R t c} : Inhabits P (.opaque o (.fixed R)) (.checkedRequest t c)

  inductive InhabitsAll (P : Program) : List Ty → List Val → Prop
    | nil : InhabitsAll P [] []
    | cons {a as v vs} : Inhabits P a v → InhabitsAll P as vs → InhabitsAll P (a :: as) (v :: vs)

  inductive InhabitsEach (P : Program) : Ty → List Val → Prop
    | nil {a} : InhabitsEach P a []
    | cons {a v vs} : Inhabits P a v → InhabitsEach P a vs → InhabitsEach P a (v :: vs)
end

def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
  ∀ v, Inhabits P a v → ∃ p ∈ ps, (Pat.matchVal p v).isSome

/-- 各選択肢は同じ変数を一度ずつ束縛する。最初の対応は恒等であり、
全選択肢の束縛の型を対応で並べ替えると、分岐の変数の型 δ になる。 -/
def AltsTy (P : Program) (alts : List Alt) (a : Ty) (δ : List Ty) : Prop :=
  alts ≠ [] ∧ δ.length = Arm.bindersOf alts ∧
  (∀ alt, alts.head? = some alt → alt.slots = List.range alt.pat.binders) ∧
  ∀ alt ∈ alts, ∃ γ, PatTy P alt.pat a γ ∧
    alt.slots.Perm (List.range γ.length) ∧ selectSlots γ alt.slots = some δ

theorem AltsTy.witness {P alts a δ} (h : AltsTy P alts a δ) :
    ∃ p γ slots, PatTy P p a γ ∧ selectSlots γ slots = some δ := by
  cases alts with
  | nil => exact (h.1 rfl).elim
  | cons alt alts =>
      obtain ⟨γ, hp, _, hs⟩ := h.2.2.2 alt (by simp)
      exact ⟨alt.pat, γ, alt.slots, hp, hs⟩

/-! ## 値と計算の型付け -/

/-- Γ と番号を共有する分類表。末尾の none は省略でき、範囲外も利用不能である。 -/
abbrev LocalCtx := List (Option BuilderKind)

/-- 通常束縛の追加。専用名がない空の表は正規形のまま保つ。 -/
def LocalCtx.extend (n : Nat) : LocalCtx → LocalCtx
  | [] => []
  | x :: xs => List.replicate n none ++ (x :: xs)

/-- 通常の変数を読めない位置にある専用名の分類。 -/
def LocalCtx.kindAt (Δ : LocalCtx) (i : Nat) : Option BuilderKind := (Δ[i]?).join

/-- 末尾の none の省略は、通常束縛を追加した後の番号の対応を変えない。 -/
theorem LocalCtx.kindAt_extend (Δ : LocalCtx) (n i : Nat) :
    (Δ.extend n).kindAt i = if i < n then none else Δ.kindAt (i - n) := by
  cases Δ with
  | nil => simp [extend, kindAt]
  | cons x xs =>
      by_cases hi : i < n
      · simp [extend, kindAt, List.getElem?_append_left, hi]
      · simp [extend, kindAt, List.getElem?_append_right, Nat.le_of_not_gt hi, hi]

/-- 専用参照の種類。通常値の型付け規則には専用場所を足さない。 -/
inductive LocalRef.HasKind (Ψ : StoreTy) (Δ : LocalCtx) : LocalRef → BuilderKind → Prop
  | bound {i k} : Δ.kindAt i = some k → HasKind Ψ Δ (.bound i) k
  | loc {l k} : Ψ l = some (.builder k) → HasKind Ψ Δ (.loc l) k

/-- 共有番号の付け替えによる、局所分類の対応。 -/
def LocalRenOk (Δ Δ' : LocalCtx) (ξ : Nat → Nat) : Prop :=
  ∀ i k, Δ.kindAt i = some k → Δ'.kindAt (ξ i) = some k

/-- 局所置換の像は、通常値ではなく同じ種類の専用参照である。 -/
def LocalSubstOk (Ψ : StoreTy) (Δ Δ' : LocalCtx) (ρ : Nat → LocalRef) : Prop :=
  ∀ i k, Δ.kindAt i = some k → LocalRef.HasKind Ψ Δ' (ρ i) k


mutual
  /-- `Γ ⊢v V : A`（制約の並び C とストアの型付け Ψ のもとで）。 -/
  inductive HasTypeVQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → List (Option Ty) → Val → Ty → Prop
    /-- 継続の型の変数は、`resume` の第一引数にだけ書ける（C-Resume。01-12「ハンドラ」）。 -/
    | V_Var {Γ i a} : Γ[i]? = some (some a) → (∀ b t ε, a ≠ .cont b t ε) →
        HasTypeVQ P B Ψ Q C Γ (.var i) a
    | V_Const {Γ c} : HasTypeVQ P B Ψ Q C Γ (.const c) c.type
    | V_Fun {Γ f d ts es} :
        P.defs f = some d → NamesWF d.names d.params →
        Admissible B C d.tparams d.neffs (Qsig d.params d.ret d.eff) Q ts es d.eff →
        HasTypeVQ P B Ψ Q C Γ (.fnRef f ts es) (fnTy d.names d.params d.ret d.eff ts es)
    | V_Prim {Γ b s rs ts es} :
        B.sig b = some s → B.RangeAdmissible b s rs → NamesWF (s.inst rs).names (s.inst rs).params →
        PrimitiveAdmissible C (s.inst rs) Q ts es →
        HasTypeVQ P B Ψ Q C Γ (.prim b ts es rs)
          (fnTy (s.inst rs).names (s.inst rs).params (s.inst rs).ret (s.inst rs).eff ts es)
    | V_Op {Γ o od ts} :
        P.ops o = some od → NamesWF od.names od.params → SatAll B C ts od.tparams →
        HasTypeVQ P B Ψ Q C Γ (.op o ts) (fnTy od.names od.params od.ret (Eff.single od.eff) ts [])
    | V_Raise {Γ T E} :
        Ty.WF 0 C.length T → Ty.WF 0 C.length E →
        HasTypeVQ P B Ψ Q C Γ (.raise T E) (.fn ["error"] [E] T (Eff.singleFail E))
    | V_Lam {Γ names ps body r ε} :
        NamesWF names ps → Ty.WF 0 C.length (.fn names ps r ε) →
        HasTypeCQ P B Ψ.hideBuilders Q C (binds ps ++ hideConts Γ) (some r) body r ε [] →
        HasTypeVQ P B Ψ Q C Γ (.lam names ps body) (.fn names ps r ε)
    | V_Con {Γ c ts args cd} :
        P.cons c = some cd → ts.length = cd.ntys →
        HasTypeVsQ P B Ψ Q C Γ args (cd.args.map (Ty.subst ts [])) →
        HasTypeVQ P B Ψ Q C Γ (.con c ts args) (.data cd.data ts)
    /-- V-List。要素の型は、その位置で束縛された型の変数だけを使う（空のリストの要素の型は項に現れないので、
    型の正しさを前提に置く）。 -/
    | V_List {Γ elems a} :
        HasTypeEachQ P B Ψ Q C Γ elems a → Ty.WF 0 C.length a → HasTypeVQ P B Ψ Q C Γ (.list elems) (.list a)
    /-- `Ψ(ℓ) = A` のとき `ℓ : A`（01-12「確かめる性質」）。 -/
    | V_LocRef {Γ l a} : Ψ l = some (.ref a) → HasTypeVQ P B Ψ Q C Γ (.loc l) (.reference a)
    | V_LocLazy {Γ l a} : Ψ l = some (.lazy a) → HasTypeVQ P B Ψ Q C Γ (.loc l) (.lazy a)
    /-- V-Map。鍵と値の型は、V-List と同じく、その位置で束縛された型の変数だけを使う。 -/
    | V_Map {Γ ks vs a b} :
        HasTypeEachQ P B Ψ Q C Γ ks a → HasTypeEachQ P B Ψ Q C Γ vs b → ks.length = vs.length →
        B.sat C a TParam.keyC → Ty.WF 0 C.length a → Ty.WF 0 C.length b →
        HasTypeVQ P B Ψ Q C Γ (.mapV ks vs) (.map a b)
    | V_Set {Γ elems a} :
        HasTypeEachQ P B Ψ Q C Γ elems a → B.sat C a TParam.keyC → Ty.WF 0 C.length a →
        HasTypeVQ P B Ψ Q C Γ (.setV elems) (.set a)
    | V_Bytes {Γ bs} : HasTypeVQ P B Ψ Q C Γ (.bytesV bs) .bytes
    /-- V-Dict。実装の型パラメータの制約を、型引数が満たす。 -/
    | V_Dict {Γ i ts vs id} :
        P.impls i = some id → SatAll B C ts id.tparams →
        HasTypeVsQ P B Ψ Q C Γ vs (id.dictTys.map (Ty.subst ts [])) →
        HasTypeVQ P B Ψ Q C Γ (.dict i ts vs) (.dict id.cls (id.target.subst ts []))
    | V_Super {Γ v cl τ cd s} :
        HasTypeVQ P B Ψ Q C Γ v (.dict cl τ) → P.classes cl = some cd → s ∈ cd.supers →
        HasTypeVQ P B Ψ Q C Γ (.super v s) (.dict s τ)
    | V_Sub {Γ v a a'} :
        HasTypeVQ P B Ψ Q C Γ v a → Ty.Le a a' → Ty.WF 0 C.length a' → HasTypeVQ P B Ψ Q C Γ v a'
    /-- V-Checked（値の所属の葉の規則）。名前 o の対象の種類（表のデータ `valKind`）が対象の種類に合い、対象が
    範囲 R に所属するとき、検査済みの対象の値は範囲付きの値型 `o[R]` を持つ（設計書 01-12「型付け規則」）。
    範囲の拡大は V-Sub ではなく、この規則の補題（`HasTypeVQ.checked_widen`）で行う。 -/
    | V_Checked {Γ o R t} :
        B.valKind o = some t.kind → R.Mem t →
        HasTypeVQ P B Ψ Q C Γ (.checked t) (.opaque o (.fixed R))
    /-- V-CheckedRequest（検査済みの要求の値の規則）。V-Checked の所属に加え、名前 o の値が保持する要求の型（表の
    データ `valContent`）が T のとき、保持する要求は、同じストアの型付け Ψ、空の NoFail の文脈、空の型の文脈と値の
    文脈で型 T を持つ（閉じた値。設計書 01-12「型付け規則」）。外側の文脈を変える改名・代入・型代入は保持する要求を
    変えず、この前提をそのまま使える。 -/
    | V_CheckedRequest {Γ o R t req T} :
        B.valKind o = some t.kind → R.Mem t → B.valContent o = some T →
        HasTypeVQ P B Ψ Qempty [] [] req T →
        HasTypeVQ P B Ψ Q C Γ (.checkedRequest t req) (.opaque o (.fixed R))

  inductive HasTypeVsQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → List (Option Ty) → List Val → List Ty → Prop
    | nil {Γ} : HasTypeVsQ P B Ψ Q C Γ [] []
    | cons {Γ v vs a as} :
        HasTypeVQ P B Ψ Q C Γ v a → HasTypeVsQ P B Ψ Q C Γ vs as → HasTypeVsQ P B Ψ Q C Γ (v :: vs) (a :: as)

  inductive HasTypeEachQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → List (Option Ty) → List Val → Ty → Prop
    | nil {Γ a} : HasTypeEachQ P B Ψ Q C Γ [] a
    | cons {Γ v vs a} :
        HasTypeVQ P B Ψ Q C Γ v a → HasTypeEachQ P B Ψ Q C Γ vs a → HasTypeEachQ P B Ψ Q C Γ (v :: vs) a

  /-- `Γ; R ⊢c M : A ! ε`。R は最も内側の関数の戻り値の型で、`none` は `escape` を許さない。 -/
  inductive HasTypeCQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → List (Option Ty) → Option Ty → Comp → Ty → Eff → (Δ : LocalCtx := []) → Prop
    | C_BuilderLet {Δ Γ R kind body a ε} :
        Ty.WF 0 C.length kind.contents →
        HasTypeCQ P B Ψ Q C (none :: Γ) R body a ε (some kind :: Δ) →
        HasTypeCQ P B Ψ Q C Γ R (.builderLet kind body) a ε Δ
    | C_BuilderOp {Δ Γ R kind op ref args} :
        Ty.WF 0 C.length kind.contents → LocalRef.HasKind Ψ Δ ref kind →
        HasTypeVsQ P B Ψ Q C Γ args (op.params kind) →
        HasTypeCQ P B Ψ Q C Γ R (.builderOp kind op ref args) (op.result kind) Eff.empty Δ
    | C_Return {Δ Γ R v a} : HasTypeVQ P B Ψ Q C Γ v a → HasTypeCQ P B Ψ Q C Γ R (.ret v) a Eff.empty Δ
    /-- C-Sub。結果の型を `Ty.Le` で、許容エフェクトを判断 5 の一原子の被覆で広げる（L40.6c）。 -/
    | C_Sub {Δ Γ R m a a' ε ε'} :
        HasTypeCQ P B Ψ Q C Γ R m a ε Δ → Ty.Le a a' → Eff.Covers ε' ε → Ty.WF 0 C.length a' → HasTypeCQ P B Ψ Q C Γ R m a' ε' Δ
    /-- 結果の型を変えず、計算の許容エフェクトだけを被覆で広げる。型の整形式は元の導出から引き継ぐ。 -/
    | C_Eff {Δ Γ R m a ε ε'} :
        HasTypeCQ P B Ψ Q C Γ R m a ε Δ → Eff.Covers ε' ε → HasTypeCQ P B Ψ Q C Γ R m a ε' Δ
    | C_Let {Δ Γ R m n a b ε} :
        HasTypeCQ P B Ψ Q C Γ R m a ε Δ → HasTypeCQ P B Ψ Q C (some a :: Γ) R n b ε (LocalCtx.extend 1 Δ) →
        HasTypeCQ P B Ψ Q C Γ R (.letIn m n) b ε Δ
    | C_App {Δ Γ R f args names as b ε} :
        HasTypeVQ P B Ψ Q C Γ f (.fn names as b ε) → HasTypeVsQ P B Ψ Q C Γ args as →
        HasTypeCQ P B Ψ Q C Γ R (.app f args) b ε Δ
    | C_If {Δ Γ R v m n a ε} :
        HasTypeVQ P B Ψ Q C Γ v (.base .boolean) → HasTypeCQ P B Ψ Q C Γ R m a ε Δ →
        HasTypeCQ P B Ψ Q C Γ R n a ε Δ → HasTypeCQ P B Ψ Q C Γ R (.ite v m n) a ε Δ
    | C_Match {Δ Γ R v arms a b ε} :
        HasTypeVQ P B Ψ Q C Γ v a → HasTypeArmsQ P B Ψ Q C Γ R arms a b ε Δ →
        Exhaustive P a (unguardedPats arms) → HasTypeCQ P B Ψ Q C Γ R (.match v arms) b ε Δ
    /-- `Γ ⊢c M : A ! { }` のとき `Γ ⊢c lazy M : Lazy[A] ! { }`。M は R を持たない判断で、継続の型を持つ
    変数を除いた環境で検査する（01-12「ストア：可変のセルと明示遅延」「関数の境界と `escape`：途中の `return` と `try`」「ハンドラ」）。 -/
    | C_Lazy {Δ Γ R m a} :
        HasTypeCQ P B Ψ.hideBuilders Q C (hideConts Γ) none m a Eff.empty [] →
        HasTypeCQ P B Ψ Q C Γ R (.lazyC m) (.lazy a) Eff.empty Δ
    /-- `Γ; R ⊢v V : R` のとき、`Γ; R ⊢c escape V : A ! ε`（任意の A と ε）。 -/
    | C_Escape {Δ Γ r v a ε} :
        HasTypeVQ P B Ψ Q C Γ v r → Ty.WF 0 C.length a → HasTypeCQ P B Ψ Q C Γ (some r) (.escape v) a ε Δ
    /-- C-Use。解放のエフェクト `rel(O_r) = {State}` を ε が含む。 -/
    | C_Use {Δ Γ R v o m b ε} :
        HasTypeVQ P B Ψ Q C Γ v (.opaqueTop o) → B.isResource o = true →
        HasTypeCQ P B Ψ Q C Γ R m b ε Δ → Eff.mem ε (.nameTop stateEff) →
        HasTypeCQ P B Ψ Q C Γ R (.use v m) b ε Δ
    /-- C-Handle。 -/
    | C_Handle {Δ Γ R m h t εm ε} :
        HasTypeCQ P B Ψ Q C Γ R m t εm Δ → Eff.Sub εm (Eff.union ε (handled P B h)) →
        HasTypeClausesQ P B Ψ Q C Γ R εm h t ε Δ →
        HasTypeCQ P B Ψ Q C Γ R (.handle m h) t ε Δ
    | C_Handle_Fail {Δ Γ R m h t E eb Rest ec} :
        HasTypeCQ P B Ψ Q C Γ R m t eb Δ →
        Eff.Sub eb (Eff.union (Eff.singleFail E) Rest) → NoFail Q Rest →
        HasFailureClause P B Ψ Q C Γ E R h t ec Δ →
        HasTypeCQ P B Ψ Q C Γ R (.handle m h) t (Eff.union Rest ec) Δ
    /-- C-Resume（節の変数 k）と C-ResumeL（継続の場所 κ）。継続の型の値は、`resume` の第一引数に
    だけ書ける（01-12「ハンドラ」）。κ に `resume` するときは、κ を作った節の R が、いまの R と等しい。 -/
    | C_Resume {Δ Γ R i v b t ε} :
        Γ[i]? = some (some (.cont b t ε)) → HasTypeVQ P B Ψ Q C Γ v b →
        HasTypeCQ P B Ψ Q C Γ R (.resume (.var i) v) t ε Δ
    | C_ResumeL {Δ Γ R l v b t ε} :
        Ψ l = some (.cont b t ε R) → HasTypeVQ P B Ψ Q C Γ v b →
        HasTypeCQ P B Ψ Q C Γ R (.resume (.loc l) v) t ε Δ
    /-- C-Meth。θ = [τ/P, S̄/γ̄, Ē/ρ̄] は、メソッドの型パラメータ γ̄ の番号 `0..g-1` を S̄ に、型クラスの引数 P の
    番号 g を τ に置き換える。メソッドの型パラメータの制約を、型引数 S̄ が満たす。 -/
    | C_Meth {Δ Γ R v cl τ cd m ms ss es ws} :
        HasTypeVQ P B Ψ Q C Γ v (.dict cl τ) → P.classes cl = some cd → cd.methods m = some ms →
        NamesWF ms.names ms.params → SatAll B C ss ms.tparams →
        (∀ t ∈ ss ++ [τ], Ty.WF 0 C.length t ∧ ∀ b r e, t ≠ .cont b r e) →
        MethodRowsAdmissible C Q ms es →
        HasTypeVsQ P B Ψ Q C Γ ws (ms.params.map (Ty.subst (ss ++ [τ]) es)) →
        HasTypeCQ P B Ψ Q C Γ R (.meth v m ss es ws) (ms.ret.subst (ss ++ [τ]) es) (Eff.substAt 0 (ss ++ [τ]) es ms.eff) Δ

  inductive HasTypeArmsQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → List (Option Ty) → Option Ty → List Arm → Ty → Ty → Eff → (Δ : LocalCtx := []) → Prop
    | nil {Δ Γ R a b ε} : Ty.WF 0 C.length b → HasTypeArmsQ P B Ψ Q C Γ R [] a b ε Δ
    | plain {Δ Γ R alts body arms a b ε δ} :
        AltsTy P alts a δ → HasTypeCQ P B Ψ Q C (binds δ ++ Γ) R body b ε (LocalCtx.extend δ.length Δ) →
        HasTypeArmsQ P B Ψ Q C Γ R arms a b ε Δ →
        HasTypeArmsQ P B Ψ Q C Γ R (.mk alts none body :: arms) a b ε Δ
    | guarded {Δ Γ R alts guard body arms a b ε δ} :
        AltsTy P alts a δ →
        HasTypeCQ P B Ψ Q C (hideConts (binds δ ++ Γ)) none guard (.base .boolean) Eff.empty (LocalCtx.extend δ.length Δ) →
        HasTypeCQ P B Ψ Q C (binds δ ++ Γ) R body b ε (LocalCtx.extend δ.length Δ) →
        HasTypeArmsQ P B Ψ Q C Γ R arms a b ε Δ →
        HasTypeArmsQ P B Ψ Q C Γ R (.mk alts (some guard) body :: arms) a b ε Δ

  /-- C-Handle の各節 `op(x̄) k ⇒ N`：`Γ, x̄:Ā, k:Cont(B → T ! ε); R ⊢c N : T ! ε`。操作の型パラメータは、
  節の中の型の変数の番号 `0..k-1` に束縛した、宣言の制約を持つ、ほかの型とは等しくない型の変数である。
  節の外側の Γ・T・R の型は、番号を k だけずらす。 -/
  inductive HasTypeClausesQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → List (Option Ty) → Option Ty → Eff → List Clause → Ty → Eff → (Δ : LocalCtx := []) → Prop
    | nil {Δ Γ R εb t ε} : HasTypeClausesQ P B Ψ Q C Γ R εb [] t ε Δ
    | cons {Δ Γ R εb o n k body cs t ε sg} :
        ClauseSig P B εb o sg → NamesWF sg.names sg.params → n = sg.params.length → k = sg.tparams.length → Eff.WF 0 C.length ε →
        HasTypeCQ P B Ψ.hideBuilders Q (sg.tparams ++ C)
          (some (.cont sg.ret (t.shift k 0) (Eff.shift k 0 ε)) :: (binds sg.params ++ shiftEnv k Γ))
          (R.map (Ty.shift k 0)) body (t.shift k 0) (Eff.shift k 0 ε) [] →
        HasTypeClausesQ P B Ψ Q C Γ R εb cs t ε Δ →
        HasTypeClausesQ P B Ψ Q C Γ R εb (.mk o n k body :: cs) t ε Δ

  /-- Fail 節は一つだけであり、予約した継続の位置には型を与えない。 -/
  inductive HasFailureClause (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → List (Option Ty) → Ty → Option Ty → List Clause → Ty → Eff → (Δ : LocalCtx := []) → Prop
    | one {C Δ Γ E R body t ec} :
        Ty.WF 0 C.length E → Ty.WF 0 C.length t → Eff.WF 0 C.length ec →
        HasTypeCQ P B Ψ.hideBuilders Q (({} : TParam) :: C)
          (none :: some (E.shift 1 0) :: shiftEnv 1 Γ)
          (R.map (Ty.shift 1 0)) body (t.shift 1 0) (Eff.shift 1 0 ec) [] →
        HasFailureClause P B Ψ Q C Γ E R [.fail E body] t ec Δ

end

/-- 局所環境を明記する内部の入口。HasTypeC は空 Δ を使う。 -/
abbrev HasTypeCL (P : Program) (B : Builtins) (Ψ : StoreTy) (C : List TParam)
    (Δ : LocalCtx) (Γ : List (Option Ty)) (R : Option Ty) (m : Comp) (a : Ty) (ε : Eff) :=
  HasTypeCQ P B Ψ Qempty C Γ R m a ε Δ


/- 通常値は専用セルを捕捉しない。ラムダの本体には隠す操作の冪等性を使う。 -/
mutual
  theorem hideBuilders_strengthen_val {P B Ψ Q C Γ v a}
      (h : HasTypeVQ P B Ψ Q C Γ v a) : HasTypeVQ P B Ψ.hideBuilders Q C Γ v a := by
    match h with
    | .V_Var hi hc => exact .V_Var hi hc
    | .V_Const => exact .V_Const
    | .V_Fun hd hn ha => exact .V_Fun hd hn ha
    | .V_Prim hs hr hn ha => exact .V_Prim hs hr hn ha
    | .V_Op ho hn ha => exact .V_Op ho hn ha
    | .V_Raise ht he => exact .V_Raise ht he
    | .V_Lam hn hw hb => exact .V_Lam hn hw (by simpa only [hideBuilders_idem] using hb)
    | .V_Con hc ht hv => exact .V_Con hc ht (hideBuilders_strengthen_vals hv)
    | .V_List hv hw => exact .V_List (hideBuilders_strengthen_each hv) hw
    | .V_LocRef hl => exact .V_LocRef ((hideBuilders_ref _ _ _).mpr hl)
    | .V_LocLazy hl => exact .V_LocLazy ((hideBuilders_lazy _ _ _).mpr hl)
    | .V_Map hk hv hl hc ha hb =>
        exact .V_Map (hideBuilders_strengthen_each hk) (hideBuilders_strengthen_each hv) hl hc ha hb
    | .V_Set hv hc hw => exact .V_Set (hideBuilders_strengthen_each hv) hc hw
    | .V_Bytes => exact .V_Bytes
    | .V_Dict hi ht hv => exact .V_Dict hi ht (hideBuilders_strengthen_vals hv)
    | .V_Super hv hc hs => exact .V_Super (hideBuilders_strengthen_val hv) hc hs
    | .V_Sub hv hl hw => exact .V_Sub (hideBuilders_strengthen_val hv) hl hw
    | .V_Checked hk hm => exact .V_Checked hk hm
    | .V_CheckedRequest hk hm hc hr => exact .V_CheckedRequest hk hm hc (hideBuilders_strengthen_val hr)

  theorem hideBuilders_strengthen_vals {P B Ψ Q C Γ vs ts}
      (h : HasTypeVsQ P B Ψ Q C Γ vs ts) : HasTypeVsQ P B Ψ.hideBuilders Q C Γ vs ts := by
    match h with
    | .nil => exact .nil
    | .cons hv ht => exact .cons (hideBuilders_strengthen_val hv) (hideBuilders_strengthen_vals ht)

  theorem hideBuilders_strengthen_each {P B Ψ Q C Γ vs t}
      (h : HasTypeEachQ P B Ψ Q C Γ vs t) : HasTypeEachQ P B Ψ.hideBuilders Q C Γ vs t := by
    match h with
    | .nil => exact .nil
    | .cons hv ht => exact .cons (hideBuilders_strengthen_val hv) (hideBuilders_strengthen_each ht)
end

abbrev HasTypeV (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeVQ P B Ψ Qempty
abbrev HasTypeVs (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeVsQ P B Ψ Qempty
abbrev HasTypeEach (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeEachQ P B Ψ Qempty
abbrev HasTypeC (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeCQ P B Ψ Qempty
abbrev HasTypeArms (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeArmsQ P B Ψ Qempty
abbrev HasTypeClauses (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeClausesQ P B Ψ Qempty

/-! ## 定義とプログラム -/

/-- 空のストアの型付け。定義の本体は場所を含まない。 -/
def StoreTy.empty : StoreTy := fun _ => none

/-- 定義に型が付く。`x1:A1, …, xn:An; B ⊢c M : B ! ε`（R := B）。 -/
def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
    HasTypeCQ P B StoreTy.empty (Qsig d.params d.ret d.eff) d.tparams (binds d.params) (some d.ret) d.body d.ret d.eff

/-- D-Impl のメソッドの型 `Ājθ`・`Bjθ`（θ = [τ/P]）。型クラスの引数 P の番号 g（メソッドの型パラメータの
個数）を、実装の対象 τ に置き換える。 -/
def ImplDecl.methTy (id : ImplDecl) (ms : MethSig) (t : Ty) : Ty :=
  t.substAt ms.tparams.length [id.target] []

/-- 実装の定義に型が付く（D-Impl）。実装の定義は、型クラスが宣言したメソッドと上位の型クラスについてだけ、
本体と辞書を持つ。型クラスの各メソッドの本体を、実装の型パラメータの外側にメソッドの
型パラメータを加えた制約の並びと、辞書の引数 d̄ の後にメソッドの引数 x̄ を並べた環境で、R := Bjθ として検査する。
上位の型クラスの各辞書 U を、辞書の引数 d̄ の環境で検査する。 -/
def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧ NamesWF ms.names ms.params ∧
      HasTypeCQ P B StoreTy.empty (Qsig ms.params ms.ret ms.eff) (ms.tparams ++ id.tparams)
        (binds (id.dictTys.map (Ty.shift ms.tparams.length 0) ++ ms.params.map (id.methTy ms)))
        (some (id.methTy ms ms.ret)) body (id.methTy ms ms.ret)
        (Eff.substAt ms.tparams.length [id.target] [] ms.eff)) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty id.tparams (binds id.dictTys) u (.dict s id.target))

def Program.WellTyped (P : Program) (B : Builtins) : Prop :=
  (∀ f d, P.defs f = some d → d.WellTyped P B) ∧ (∀ i id, P.impls i = some id → id.WellTyped P B)

end Benitoite.Release
