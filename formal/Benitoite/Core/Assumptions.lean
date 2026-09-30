import Benitoite.Core.WellFormed

/-!
# 形式化で仮定するもの（段階 A）

設計書 07-04「形式化で仮定するもの」の表を書き写す。01-12 は、組み込みの関数の値（δ）と
IO の応答を他の章に委ねている。形式化では中身を定めず、ここに挙げる性質だけを仮定する。
仮定は `axiom` としては置かず、定理の引数（`Builtins.Assumptions`）として明示する。
-/

namespace Benitoite.Core

/-- 組み込みの関数の結果が型 A を持つ。`error(r)` はどの型についても許す。 -/
def OutcomeTy (P : Program) (B : Builtins) : Outcome → Ty → Prop
  | .val v, a => HasTypeV P B [] v a
  | .err _, _ => True

/-- 組み込みの関数について仮定する性質。 -/
structure Builtins.Assumptions (P : Program) (B : Builtins) : Prop where
  /-- 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う。 -/
  sig_scoped : ∀ b s, B.sig b = some s → s.Scoped
  /-- 型パラメータの制約は、型とエフェクトの置き換えで保たれる。関数の定義の中で制約を満たした
  型は、その関数を呼ぶときの置き換えの後も制約を満たす。 -/
  admits_subst : ∀ b s ts ts' es', B.sig b = some s → s.admits ts →
    s.admits (ts.map (Ty.subst ts' es'))
  /-- δ の型の保存。型 `(Ā) → B ! ε` の IO を行わない組み込みの関数に型 `Ā` の値を渡すと、
  δ は型 `B` の値か `error(r)` を返す（01-12 の E-Prim・E-Err が必ずどちらかに当たる）。 -/
  delta_typed : ∀ b s ts es ws, B.sig b = some s → s.io = false →
    ts.length = s.ntys → es.length = s.neffs → s.admits ts →
    HasTypeVs P B [] ws (s.params.map (Ty.subst ts es)) →
    ∃ o, B.delta b ts es ws = some o ∧ OutcomeTy P B o (Ty.subst ts es s.ret)
  /-- IO の応答の型。型 `(Ā) → B ! ε` の IO を行う組み込みの関数の応答は、型 `B` の値か
  `error(r)` である（01-12 の性質 2 の「IO の応答は、関数の戻り値の型の値であるとする」）。 -/
  io_typed : ∀ b s ts es ws o, B.sig b = some s → s.io = true →
    ts.length = s.ntys → es.length = s.neffs → s.admits ts →
    HasTypeVs P B [] ws (s.params.map (Ty.subst ts es)) →
    B.ioResponse b ts es ws o → OutcomeTy P B o (Ty.subst ts es s.ret)
  /-- IO を行う組み込みの関数に型の付いた引数を渡すと、起こりうる応答が少なくとも一つある
  （E-IO か E-IOErr で遷移できる）。 -/
  io_exists : ∀ b s ts es ws, B.sig b = some s → s.io = true →
    ts.length = s.ntys → es.length = s.neffs → s.admits ts →
    HasTypeVs P B [] ws (s.params.map (Ty.subst ts es)) →
    ∃ o, B.ioResponse b ts es ws o
  /-- IO を行う組み込みの関数の型のエフェクトは、`IO` を含む。 -/
  io_effect : ∀ b s, B.sig b = some s → s.io = true → s.eff .io = true

end Benitoite.Core
