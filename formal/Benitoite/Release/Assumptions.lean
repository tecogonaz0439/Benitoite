import Benitoite.Release.Semantics

/-!
# 形式化で仮定するもの（段階 B）

段階 A の仮定（`Benitoite.Core.Builtins.Assumptions`）を、段階 B の組み込みの関数に広げる。
設計書 07-04「形式化で仮定するもの」の表に対応する。仮定は `axiom` としては置かず、定理の引数として明示する。
-/

namespace Benitoite.Release

/-- 組み込みの関数の結果が型 A を持つ。値は型の変数を含まない。 -/
def OutcomeTy (P : Program) (B : Builtins) (Ψ : StoreTy) : Outcome → Ty → Prop
  | .val v, a => HasTypeV P B Ψ [] [] v a ∧ Val.VarsIn 0 (fun _ => True) v
  | .err _, _ => True
  | .exit _, _ => True

/-- 型パラメータの制約の並び `C0`（`C1` の外側）を、閉じた型 `ts` で置き換えられる。 -/
def ClosedSat (B : Builtins) (C0 C1 : List TParam) (ts : List Ty) : Prop :=
  (∀ t ∈ ts, Ty.WF 0 0 t) ∧ SatAll B C1 ts C0

/-- 可変のセルと明示遅延の組み込みの関数の型（01-07「可変のセル（初回リリース版）」、01-06「明示遅延の型（初回リリース版）」）。
これらの項目は範囲の変数を持たない（`rkinds = []`）。`Reference.update` の遷移が作る `Reference.get`・`Reference.set` の
呼び出しは空の範囲の列を持つためである。 -/
def PrimSig.StoreShape (s : PrimSig) : Prop :=
  match s.kind with
  | .refNew => s.names = ["value"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.tvar 0] ∧ s.ret = .reference (.tvar 0) ∧
      s.eff = Eff.single stateEff ∧ s.rkinds = []
  | .refGet => s.names = ["reference"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.single stateEff ∧ s.rkinds = []
  | .refSet => s.names = ["reference", "value"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0), .tvar 0] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff ∧ s.rkinds = []
  | .refUpdate => s.names = ["reference", "f"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0), .fn ["value"] [.tvar 0] (.tvar 0) Eff.empty] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff ∧ s.rkinds = []
  | .force => s.names = ["value"] ∧ s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.lazy (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.empty ∧ s.rkinds = []
  | .pure => True
  | .io => True
  | .exit => True

/-- IO の項目の形の検査（問 18 の行 1。旧 `io_op` の内容を形ごとの条件に変えたもの）。全ての形で、元の操作の名前・
`opEff`・`neffs = 0`・組み込みのエフェクトの操作の一覧への所属を保つ。対象なしの形と旧 Top の形は範囲の変数を
持たず、効果は名前だけ（Top）の一原子である。単一の対象の形は範囲の変数を一つだけ持ち、効果は `L[rvar 0]` の一原子で、
対象の位置の引数が同じ範囲の変数を添字に持つ範囲付きの値型である（入力の添字と効果の一致）。エフェクトの名前と値型の
名前の対象の種類（`effKind`・`valKind`）は範囲の変数の種類と一致する（RV-L00 中2）。 -/
def Builtins.ShapeOk (B : Builtins) (b : PrimName) (s : PrimSig) : Prop :=
  ∃ l bs, s.opEff = some l ∧ s.neffs = 0 ∧ B.effects l = some bs ∧ b ∈ bs ∧
    match s.shape with
    | .untargeted => B.effKind l = none ∧ s.rkinds = [] ∧ s.eff = Eff.single l
    | .topTargeted k => B.effKind l = some k ∧ s.rkinds = [] ∧ s.eff = Eff.single l
    | .single k p => B.effKind l = some k ∧ s.rkinds = [k] ∧ s.eff = Eff.singleAt l (.rvar 0) ∧
        ∃ o, s.params[p]? = some (.opaque o (.rvar 0)) ∧ B.valKind o = some k

/-- 呼び出しの引数に照らした項目の形（`io_target` が読む形）。単一の対象の形の項目で、対象の位置の引数が検査済みの
対象を持たないとき（範囲が Top の不透明型の定数の値。`HasTypeVQ.canonical_opaque`）は、旧 Top の形として読む。
ほかの形と、対象の位置の引数が対象を保持する値（検査済みの対象の値か検査済みの要求の値。`Val.target?`）である
呼び出しでは、項目の形そのものである。 -/
def PrimSig.shapeAt (s : PrimSig) (ws : List Val) : Scope.Signature.IOShape :=
  match s.shape with
  | .single k p => if ((ws[p]?).bind Val.target?).isSome then .single k p else .topTargeted k
  | sh => sh

/-- 旧の条件（問 7 の S1。信頼条件のうち、四つの主定理が依存するもの）。欄の名前と並びは L20.7 の前の
`Builtins.Assumptions` の全ての欄と同じである。L20.7 で内容を変えたのは `io_op` だけであり、形の検査
`Builtins.ShapeOk` にした（問 18 の行 1）。ほかの欄の内容の変更（範囲の列と観測の量化、値の所属の葉の規則と被覆による
包含を通じた意味の変化）は、設計書 07-04「形式化で仮定するもの」のとおりである。 -/
structure Builtins.CoreAssumptions (P : Program) (B : Builtins) : Prop where
  /-- 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う。 -/
  sig_scoped : ∀ b s, B.sig b = some s → s.Scoped
  /-- 制約の保存。制約の並びの `C1` の外側の `C0` を閉じた型で置き換えても、制約を満たす。 -/
  admits_subst : ∀ b s C0 C1 ts ts' es', B.sig b = some s → s.admits (C1 ++ C0) ts →
    ClosedSat B C0 C1 ts' → ts'.length = C0.length →
    s.admits C1 (ts.map (Ty.substAt C1.length ts' es'))
  sat_subst : ∀ C0 C1 t p ts' es', B.sat (C1 ++ C0) t p →
    ClosedSat B C0 C1 ts' → ts'.length = C0.length → B.sat C1 (t.substAt C1.length ts' es') p
  /-- 閉じた整形式の型は、制約を付けない型パラメータを具体化できる。 -/
  sat_unconstrained : ∀ t, Ty.WF 0 0 t → B.sat [] t ({} : TParam)
  /-- 組み込みの関数の制約を満たす型引数は、その型パラメータの組み込みの制約も満たす。 -/
  admits_sat : ∀ b s C ts, B.sig b = some s → s.admits C ts → SatAll B C ts s.tparams
  /-- 制約の並び `C1` の型パラメータだけを使う型が制約を満たすかは、`C1` の外側の並びによらない。 -/
  sat_local : ∀ C1 C0 t p, Ty.WF 0 C1.length t → B.sat C1 t p → B.sat (C1 ++ C0) t p
  admits_local : ∀ b s C1 C0 ts, B.sig b = some s → (∀ t ∈ ts, Ty.WF 0 C1.length t) →
    s.admits C1 ts → s.admits (C1 ++ C0) ts
  /-- δ の型の保存（IO を行わない組み込みの関数）。 -/
  delta_typed : ∀ Ψ b s rs ts es ws, B.sig b = some s → s.kind = .pure → B.RangeAdmissible b s rs →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    ∃ o, B.delta b ts es rs ws = some o ∧ (∀ n, o ≠ .exit n) ∧ OutcomeTy P B Ψ o (Ty.subst ts es (s.inst rs).ret)
  /-- IO の応答の型。IO を行う関数の応答は値か `error(r)`、プロセスの終了の関数の応答は `exit(n)` か
  `error(r)` である。`io_kind`・`io_typed`・`io_exists` は応答とともに観測 `obs` を量化し、観測には条件を置かない
  （問 18 の行 3。観測を捨てた欄は旧の欄と同値である。`Builtins.ioKind_iff_noObs` ほか）。 -/
  io_kind : ∀ b s ts es ws o obs, B.sig b = some s → B.ioResponse b ts es ws o obs →
    (s.kind = .io ∧ ∀ n, o ≠ .exit n) ∨ (s.kind = .exit ∧ ∀ v, o ≠ .val v)
  io_typed : ∀ Ψ b s rs ts es ws o obs, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.RangeAdmissible b s rs →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    B.ioResponse b ts es ws o obs → OutcomeTy P B Ψ o (Ty.subst ts es (s.inst rs).ret)
  /-- IO の応答の存在。 -/
  io_exists : ∀ Ψ b s rs ts es ws, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.RangeAdmissible b s rs →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    ∃ o obs, B.ioResponse b ts es ws o obs
  /-- IO を行う組み込みの関数は、組み込みのエフェクトの操作であり、形の検査を通る（問 18 の行 1）。対象なしの形と
  旧 Top の形では、型のエフェクトはそのエフェクトの名前だけである（旧の内容。`Builtins.ShapeOk.old`）。 -/
  io_op : ∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.ShapeOk b s
  /-- 組み込みのエフェクトの操作は、そのエフェクトを `opEff` に持つ、IO を行う組み込みの関数である。 -/
  effect_ops : ∀ l bs b, B.effects l = some bs → b ∈ bs →
    ∃ s, B.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit) ∧ s.opEff = some l
  opEff_io : ∀ b s l, B.sig b = some s → s.opEff = some l → (s.kind = .io ∨ s.kind = .exit)
  /-- `State` は操作を持たない組み込みのエフェクトである。 -/
  state_effect : B.effects stateEff = some []
  /-- 可変のセルと明示遅延の組み込みの関数の型と、制約。これらの関数は、個数の合う型引数ならどれも受け入れる。 -/
  store_shape : ∀ b s, B.sig b = some s → s.StoreShape
  store_admits : ∀ b s C ts, B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io → s.kind ≠ .exit →
    ts.length = s.ntys → s.admits C ts
  ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
  ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet
  /-- 解放の事象には、起こりうる応答が少なくとも一つある。 -/
  release_exists : ∀ Ψ v o, HasTypeV P B Ψ [] [] v (.opaqueTop o) → B.isResource o = true →
    ∃ r, B.releaseResponse v r

/-- 対象一致の条件（問 7 の S1、計画済みの新しい信頼条件。決定の判断 15）。唯一の欄 `io_target` は、範囲の具体化
`rs` で型の付いた引数について、実装が報告する観測 `obs` が項目の形の条件（`Scope.Signature.ShapeTargets`）を満たすことを
求める。対象なしの形は対象を報告しない。旧 Top の形は宣言した種類の対象だけを報告する（リダイレクト・再帰・複数の
対象を含めてよい）。単一の対象の形は、対象の位置の引数が保持する同じ対象をちょうど一つ報告する（問 9 の E1）。
範囲は `rs` として欄の中で量化する（応答の関係は範囲の列を受け取らない。L20.5 の S2）。入力が範囲に属することは
仮定しない（値の型付けから示す）。

旧 Top の形には、文言として「実装が作用した対象をすべて観測に含む」（完全性。問 10）を加えて信頼する。完全性は
対象の健全性の証明に使わないので、この欄の Lean の条件には書かない（設計書 07-04「形式化で仮定するもの」）。
四つの主定理はこの構造体に依存しない（`CoreAssumptions` だけを前提に持つ）。 -/
structure Builtins.TargetAgreement (P : Program) (B : Builtins) : Prop where
  io_target : ∀ Ψ b s rs ts es ws o obs, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    B.RangeAdmissible b s rs → ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    B.ioResponse b ts es ws o obs → Scope.Signature.ShapeTargets Val.target? (s.shapeAt ws) ws obs

/-- 全体の信頼条件（問 7 の S1）。旧の条件 `CoreAssumptions` と対象一致の条件 `TargetAgreement` を明示して含む。 -/
structure Builtins.Assumptions (P : Program) (B : Builtins) : Prop extends
    Builtins.CoreAssumptions P B, Builtins.TargetAgreement P B

/-- 全体の信頼条件から旧の条件を得る射影。主定理（`hb : B.CoreAssumptions P`）は全体の信頼条件のもとでも使える。 -/
theorem Builtins.Assumptions.core {P : Program} {B : Builtins} (h : B.Assumptions P) : B.CoreAssumptions P :=
  h.toCoreAssumptions

/-- 全体の信頼条件から対象一致の条件を得る射影。 -/
theorem Builtins.Assumptions.target {P : Program} {B : Builtins} (h : B.Assumptions P) : B.TargetAgreement P :=
  h.toTargetAgreement

/-- エフェクトの宣言が、操作の宣言と合っている。利用者が宣言したエフェクトの名前は、組み込みのエフェクトの
名前と重ならない。 -/
def Program.EffectsOk (P : Program) (B : Builtins) : Prop :=
  (∀ l os o, P.effects l = some os → o ∈ os → ∃ od, P.ops o = some od ∧ od.eff = l) ∧
    (∀ o od, P.ops o = some od → ∃ os, P.effects od.eff = some os ∧ o ∈ os) ∧
    (∀ l os, P.effects l = some os → B.effects l = none)

end Benitoite.Release
