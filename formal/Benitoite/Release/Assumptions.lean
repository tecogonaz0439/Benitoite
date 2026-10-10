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
  (∀ t ∈ ts, Ty.WF 0 t) ∧ SatAll B C1 ts C0

/-- 可変のセルと明示遅延の組み込みの関数の型（01-07「可変のセル（初回リリース版）」、01-06「明示遅延の型（初回リリース版）」）。 -/
def PrimSig.StoreShape (s : PrimSig) : Prop :=
  match s.kind with
  | .refNew => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.tvar 0] ∧ s.ret = .reference (.tvar 0) ∧
      s.eff = Eff.single stateEff
  | .refGet => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.single stateEff
  | .refSet => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0), .tvar 0] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff
  | .refUpdate => s.ntys = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0), .fn [.tvar 0] (.tvar 0) Eff.empty] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff
  | .force => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.lazy (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.empty
  | .pure => True
  | .io => True
  | .exit => True

structure Builtins.Assumptions (P : Program) (B : Builtins) : Prop where
  /-- 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う。 -/
  sig_scoped : ∀ b s, B.sig b = some s → s.Scoped
  /-- 制約の保存。制約の並びの `C1` の外側の `C0` を閉じた型で置き換えても、制約を満たす。 -/
  admits_subst : ∀ b s C0 C1 ts ts' es', B.sig b = some s → s.admits (C1 ++ C0) ts →
    ClosedSat B C0 C1 ts' → ts'.length = C0.length →
    s.admits C1 (ts.map (Ty.substAt C1.length ts' es'))
  sat_subst : ∀ C0 C1 t p ts' es', B.sat (C1 ++ C0) t p →
    ClosedSat B C0 C1 ts' → ts'.length = C0.length → B.sat C1 (t.substAt C1.length ts' es') p
  /-- 組み込みの関数の制約を満たす型引数は、その型パラメータの組み込みの制約も満たす。 -/
  admits_sat : ∀ b s C ts, B.sig b = some s → s.admits C ts → SatAll B C ts s.tparams
  /-- 制約の並び `C1` の型パラメータだけを使う型が制約を満たすかは、`C1` の外側の並びによらない。 -/
  sat_local : ∀ C1 C0 t p, Ty.WF C1.length t → B.sat C1 t p → B.sat (C1 ++ C0) t p
  admits_local : ∀ b s C1 C0 ts, B.sig b = some s → (∀ t ∈ ts, Ty.WF C1.length t) →
    s.admits C1 ts → s.admits (C1 ++ C0) ts
  /-- δ の型の保存（IO を行わない組み込みの関数）。 -/
  delta_typed : ∀ Ψ b s ts es ws, B.sig b = some s → s.kind = .pure →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    ∃ o, B.delta b ts es ws = some o ∧ (∀ n, o ≠ .exit n) ∧ OutcomeTy P B Ψ o (Ty.subst ts es s.ret)
  /-- IO の応答の型。IO を行う関数の応答は値か `error(r)`、プロセスの終了の関数の応答は `exit(n)` か
  `error(r)` である。 -/
  io_kind : ∀ b s ts es ws o, B.sig b = some s → B.ioResponse b ts es ws o →
    (s.kind = .io ∧ ∀ n, o ≠ .exit n) ∨ (s.kind = .exit ∧ ∀ v, o ≠ .val v)
  io_typed : ∀ Ψ b s ts es ws o, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    B.ioResponse b ts es ws o → OutcomeTy P B Ψ o (Ty.subst ts es s.ret)
  /-- IO の応答の存在。 -/
  io_exists : ∀ Ψ b s ts es ws, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    ∃ o, B.ioResponse b ts es ws o
  /-- IO を行う組み込みの関数は、組み込みのエフェクトの操作であり、型のエフェクトはそのエフェクトの
  名前だけである。 -/
  io_op : ∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ∃ l bs, s.opEff = some l ∧ s.eff = Eff.single l ∧ s.neffs = 0 ∧ B.effects l = some bs ∧ b ∈ bs
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
  release_exists : ∀ Ψ v o, HasTypeV P B Ψ [] [] v (.opaque o) → B.isResource o = true →
    ∃ r, B.releaseResponse v r

/-- エフェクトの宣言が、操作の宣言と合っている。利用者が宣言したエフェクトの名前は、組み込みのエフェクトの
名前と重ならない。 -/
def Program.EffectsOk (P : Program) (B : Builtins) : Prop :=
  (∀ l os o, P.effects l = some os → o ∈ os → ∃ od, P.ops o = some od ∧ od.eff = l) ∧
    (∀ o od, P.ops o = some od → ∃ os, P.effects od.eff = some os ∧ o ∈ os) ∧
    (∀ l os, P.effects l = some os → B.effects l = none)

end Benitoite.Release
