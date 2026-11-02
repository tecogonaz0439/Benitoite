# 置換の二方式の比較

両案の代表は閉じた。案(ii)を推す。検査済みの元の式と、構成子が持つ置換νを分けると、二鍵の像の衝突・新しい一致・加算の像でも係数の再配列を必要としない。`Entails.bind`の新しい場合は、νと外側の置換を`predBind_comp`で合成する。

案(i)を全規則へ拡張する場合は、再線形化と係数位置の変換に加え、splitの対象を一般の線形式へ拡張し、組込み葉と途中の参照も再生成する。言語の構文や探索の完全性を変える利点はなく、帰納の負担が増える。

案(ii)でも、全域モデルの意味の置換から健全性を推論しない。各算術・論理規則をνの像の上で証明する。本番の`CertificateKernelBind`と`LinearSound`の補題、`LogicKernelExamples`の具体例が採用する代表である。全NNF28場合・全反証9構成子・全証明書7構成子の帰納は群C/D/F/Gへ残る。

## 案(i)の代表

3変数の加算・負号・定数倍を再線形化し、係数2のcombineを検査する小さい核である。二鍵の像の衝突は係数を合算し、非鍵の定数との新しい一致は定数項へ合算し、加算の像は二位置へ分ける。単に鍵の列をmapした証明ではない。全証明書の`check_bind`の証明ではない。splitは再線形化した整数式へ適用する必要がある。

```lean
import Benitoite.Release.Refinement.LinearSound
open Benitoite.Release.Refinement
namespace Reconstruct
structure Affine where
  x : Int
  y : Int
  z : Int
  constant : Int
  deriving DecidableEq

def plus (a b : Affine) : Affine :=
  ⟨a.x+b.x, a.y+b.y, a.z+b.z, a.constant+b.constant⟩
def times (k : Int) (a : Affine) : Affine :=
  ⟨k*a.x, k*a.y, k*a.z, k*a.constant⟩

def linearize : Term → Option Affine
  | .integer n => some ⟨0,0,0,n⟩
  | .var 0 => some ⟨1,0,0,0⟩
  | .var 1 => some ⟨0,1,0,0⟩
  | .var 2 => some ⟨0,0,1,0⟩
  | .add a b => return plus (←linearize a) (←linearize b)
  | .neg a => return times (-1) (←linearize a)
  | .scale k a => return times k (←linearize a)
  | _ => none

-- 係数2の単一のcombineを検査する。証明書は再計算する左右の式を持つ。
structure Proof where
  source : Affine
  result : Affine
  deriving DecidableEq

def check (p q : Pred) (c : Proof) : Bool :=
  match p,q with
  | .le a (.integer b), .le d (.integer e) =>
    linearize a == some c.source && linearize d == some c.result &&
      c.result == times 2 c.source && decide (e = 2*b)
  | _,_ => false

def p (t : Term) : Pred := .le t (.integer 5)
def q (t : Term) : Pred := .le (.scale 2 t) (.integer 10)
def c (a : Affine) : Proof := ⟨a,times 2 a⟩

def collision : ObservationEnv := fun _ => some (.var 2)
def freshMatch : ObservationEnv := fun i =>
  if i = 0 then some (.integer 1) else some (.var 0)
def addition : ObservationEnv := fun i =>
  if i = 0 then some (.add (.var 1) (.var 2)) else some (.var i)

-- 二鍵の像は一鍵へ合流し、その係数は2になる。
example : check (p (.add (.var 0) (.var 1))) (q (.add (.var 0) (.var 1)))
    (c ⟨1,1,0,0⟩) = true ∧
    ∃ c', check (predBind collision (p (.add (.var 0) (.var 1))))
      (predBind collision (q (.add (.var 0) (.var 1)))) c' = true := by
  exact ⟨by decide, c ⟨0,0,2,0⟩, by decide⟩

-- 元の非鍵の定数1と変数0の像が一致する。定数項を合算し2にする。
example : check (p (.add (.var 0) (.integer 1))) (q (.add (.var 0) (.integer 1)))
    (c ⟨1,0,0,1⟩) = true ∧
    ∃ c', check (predBind freshMatch (p (.add (.var 0) (.integer 1))))
      (predBind freshMatch (q (.add (.var 0) (.integer 1)))) c' = true := by
  exact ⟨by decide, c ⟨0,0,0,2⟩, by decide⟩

-- 元の一鍵が二鍵を含む和になる。出力の係数位置を作り直す。
example : check (p (.var 0)) (q (.var 0)) (c ⟨1,0,0,0⟩) = true ∧
    ∃ c', check (predBind addition (p (.var 0)))
      (predBind addition (q (.var 0))) c' = true := by
  exact ⟨by decide, c ⟨0,1,1,0⟩, by decide⟩

-- splitを単一key番号に限らず、再線形化した整数式へ適用する代表。
example (η : ObservationEnvModel) :
    integerAs η (termBind addition (.var 0)) ≤ 7 ∨
      8 ≤ integerAs η (termBind addition (.var 0)) := integerAs_split_at η addition _ 7
end Reconstruct
```

## 既存の部分型の入口への接続の型の確認

以下は現行Certificateから同じTy.LeQへ入る形を確認した補助入力である。全refuteの実装済みを意味しない。

```lean
import Benitoite.Release.Refinement.Certificate
import Benitoite.Release.Refinement.LinearSound
open Benitoite.Release.Refinement
namespace SignatureBridge
noncomputable section
-- 現行のCertificateのsoundから、同じLeQのrefineへ入る形を確認する。
example {P : Program} {Γ : Ctx} {Φ : List Pred} {a b : Ty} {p q : Pred} {c : Certificate}
    (hab : Ty.LeQ P Γ Φ a b) (hp : p.Sorted Γ (some a)) (hq : q.Sorted Γ (some b))
    (hc : Certificate.check (p :: assumptions Γ Φ a) q c = true) :
    Ty.LeQ P Γ Φ (.refined a p) (.refined b q) :=
  Ty.LeQ.refine hab hp hq (Certificate.sound hc)

-- 比較用の三つの入力にも、同じ数学上のcombineが適用できる。
example (t : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.le t (.integer 5))).interpret η = true →
    (predBind ν (.le (.scale 2 t) (.integer 10))).interpret η = true :=
  Pred.scaled_le_at _ (by decide) ν η
end
end SignatureBridge
```

## 案(ii)の検査器の水準の代表（再開1）

RV-L30.aのCheckedAtToyの全文を保存した。元の式で検査した同じ証明書について、任意のνの像の上の健全性をTermの構造の帰納から示す。二鍵の衝突、定数との新しい一致、加算の像、snapshotの中への像の四つで証明書を再構成しない。

この三変数・係数2の検査器は補助入力だけに置く。群Bの任意の鍵の線形化と群Gの全証明書の検査に重なるため、本番へ別の検査器を増やさない。本番にはCertificateKernelBind/LinearSoundの一般のνの補題とLogicKernelExamplesの読者を残す。群Gではそれらを本番の全規則へ合成する。

```lean
import Benitoite.Release.Refinement.LinearSound
open Benitoite.Release.Refinement
namespace RVCheckedAt

/- レビューの補助入力。案(ii)で、比較文書の案(i)と同じ小さい検査器を元の式だけで検査し、
   任意のνの像の上の健全性を帰納で示せるかを確かめる。 -/
structure Affine where
  x : Int
  y : Int
  z : Int
  constant : Int
  deriving DecidableEq

def plus (a b : Affine) : Affine :=
  ⟨a.x+b.x, a.y+b.y, a.z+b.z, a.constant+b.constant⟩
def times (k : Int) (a : Affine) : Affine :=
  ⟨k*a.x, k*a.y, k*a.z, k*a.constant⟩

def linearize : Term → Option Affine
  | .integer n => some ⟨0,0,0,n⟩
  | .var 0 => some ⟨1,0,0,0⟩
  | .var 1 => some ⟨0,1,0,0⟩
  | .var 2 => some ⟨0,0,1,0⟩
  | .add a b => match linearize a, linearize b with
    | some l, some r => some (plus l r)
    | _, _ => none
  | .neg a => (linearize a).map (times (-1))
  | .scale k a => (linearize a).map (times k)
  | _ => none

noncomputable def ρ (ν : ObservationEnv) (η : ObservationEnvModel) (i : Nat) : Int :=
  integerAs η (termBind ν (.var i))

def Affine.eval (a : Affine) (r : Nat → Int) : Int :=
  a.x * r 0 + a.y * r 1 + a.z * r 2 + a.constant

theorem linearize_sound_at (ν : ObservationEnv) (η : ObservationEnvModel) :
    (t : Term) → (a : Affine) → linearize t = some a →
      integerAs η (termBind ν t) = a.eval (ρ ν η)
  | .integer n, a, h => by
    simp only [linearize, Option.some.injEq] at h; subst h
    simp [Affine.eval, integerAs_eq_integerD, Term.interpret, Observation.integerD]
  | .var 0, a, h => by simp only [linearize, Option.some.injEq] at h; subst h; simp [Affine.eval, ρ]
  | .var 1, a, h => by simp only [linearize, Option.some.injEq] at h; subst h; simp [Affine.eval, ρ]
  | .var 2, a, h => by simp only [linearize, Option.some.injEq] at h; subst h; simp [Affine.eval, ρ]
  | .var (n+3), a, h => by simp [linearize] at h
  | .add l r, a, h => by
    simp only [linearize] at h
    split at h
    · rename_i al ar hl hr
      simp only [Option.some.injEq] at h; subst h
      rw [integerAs_bind_add, linearize_sound_at ν η l al hl, linearize_sound_at ν η r ar hr]
      simp only [Affine.eval, plus, Int.add_mul]; omega
    · cases h
  | .neg t, a, h => by
    simp only [linearize, Option.map_eq_some_iff] at h
    obtain ⟨b, hb, rfl⟩ := h
    rw [integerAs_bind_neg, linearize_sound_at ν η t b hb]
    simp only [Affine.eval, times, Int.neg_mul, Int.one_mul]; omega
  | .scale k t, a, h => by
    simp only [linearize, Option.map_eq_some_iff] at h
    obtain ⟨b, hb, rfl⟩ := h
    rw [integerAs_bind_scale, linearize_sound_at ν η t b hb]
    simp only [Affine.eval, times, Int.mul_add, Int.mul_assoc]
  | .character _, _, h | .float64 _, _, h | .float32 _, _, h | .decimal _ _, _, h
  | .boolean _, _, h | .unitValue, _, h | .string _, _, h | .listValue _, _, h
  | .bytesValue _, _, h | .mapValue _ _, _, h | .setValue _, _, h | .dataValue _ _, _, h
  | .targetValue _ _, _, h | .field _ _, _, h | .measure _ _, _, h => by simp [linearize] at h

-- 案(i)の比較文書と同じ形の検査器。ただし元の式だけを検査する。
structure Proof where
  source : Affine
  result : Affine
  deriving DecidableEq

def check (p q : Pred) (c : Proof) : Bool :=
  match p, q with
  | .le a (.integer b), .le d (.integer e) =>
    linearize a == some c.source && linearize d == some c.result &&
      c.result == times 2 c.source && decide (e = 2*b)
  | _, _ => false

theorem implication_sound_at {p q : Pred} {c : Proof} (h : check p q c = true)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true → (predBind ν q).interpret η = true := by
  unfold check at h
  split at h
  · rename_i a b d e
    simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h
    obtain ⟨⟨⟨ha, hd⟩, hr⟩, he⟩ := h
    simp only [predBind, Pred.interpret, Pred.atomValue, decide_eq_true_eq, termBind_integer]
    rw [linearize_sound_at ν η a _ ha, linearize_sound_at ν η d _ hd, hr]
    simp only [integerAs_eq_integerD, Term.interpret, Observation.integerD, he]
    intro hle
    simp only [Affine.eval, times] at hle ⊢
    have := Int.mul_le_mul_of_nonneg_left hle (show (0:Int) ≤ 2 by decide)
    simp only [Int.mul_add] at this
    -- 2*(x r0 + ...) の並べ替え
    have e1 : 2 * c.source.x * ρ ν η 0 = 2 * (c.source.x * ρ ν η 0) := Int.mul_assoc _ _ _
    have e2 : 2 * c.source.y * ρ ν η 1 = 2 * (c.source.y * ρ ν η 1) := Int.mul_assoc _ _ _
    have e3 : 2 * c.source.z * ρ ν η 2 = 2 * (c.source.z * ρ ν η 2) := Int.mul_assoc _ _ _
    omega
  · cases h

def p (t : Term) : Pred := .le t (.integer 5)
def q (t : Term) : Pred := .le (.scale 2 t) (.integer 10)
def c (a : Affine) : Proof := ⟨a, times 2 a⟩

def collision : ObservationEnv := fun _ => some (.var 2)
def freshMatch : ObservationEnv := fun i =>
  if i = 0 then some (.integer 1) else some (.var 0)
def addition : ObservationEnv := fun i =>
  if i = 0 then some (.add (.var 1) (.var 2)) else some (.var i)
-- 比較文書にない像: snapshot の中へ写す置換
def intoSnapshot : ObservationEnv := fun i =>
  if i = 0 then some (.measure .setSize (.setValue [some (.var 1)])) else some (.var i)

-- 同じ元の証明書が、四つの像のすべてで再構成なしに健全である。
example (η : ObservationEnvModel) :
    ((predBind collision (p (.add (.var 0) (.var 1)))).interpret η = true →
      (predBind collision (q (.add (.var 0) (.var 1)))).interpret η = true) ∧
    ((predBind freshMatch (p (.add (.var 0) (.integer 1)))).interpret η = true →
      (predBind freshMatch (q (.add (.var 0) (.integer 1)))).interpret η = true) ∧
    ((predBind addition (p (.var 0))).interpret η = true →
      (predBind addition (q (.var 0))).interpret η = true) ∧
    ((predBind intoSnapshot (p (.var 0))).interpret η = true →
      (predBind intoSnapshot (q (.var 0))).interpret η = true) :=
  ⟨implication_sound_at (c := c ⟨1,1,0,0⟩) (by decide) _ η,
   implication_sound_at (c := c ⟨1,0,0,1⟩) (by decide) _ η,
   implication_sound_at (c := c ⟨1,0,0,0⟩) (by decide) _ η,
   implication_sound_at (c := c ⟨1,0,0,0⟩) (by decide) _ η⟩

end RVCheckedAt

#print axioms RVCheckedAt.linearize_sound_at
#print axioms RVCheckedAt.implication_sound_at
```
