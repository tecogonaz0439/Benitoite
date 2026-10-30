import Derivations

/- P3/M6Body.lean:17-40,149-173 の接続を構文の葉へ変更。
   P2 の証明書の検査は Logic.lean の Entails.checked で直接使う。
   全 sort・幅・公開された measure の正規化器を実装したという意味ではない。 -/
namespace P4.M6
open Derivation
set_option maxHeartbeats 400000

-- M6 の machine_exact/stable/represented から作る事実は、任意の意味の Γ ではなく、
-- 同じ鍵の列に対する構文の導出 prepared として葉へ渡す。
-- prepared は型の篩/形の事実と有限の組込みの補題から作る義務であり、公理ではない。
theorem checked_subtype (Φ : List Pred) (a : TyQ) (p : Pred)
    (keys : List Term) (assumptions goal : P2.Formula) (cert : P2.Cert)
    (prepared : Entails (p :: a.assume ++ Φ.map Pred.lift) (.arithmetic keys assumptions))
    (checked : P2.check (.and assumptions (.not goal)) cert = true) :
    TyLe Φ (.refined a p) (.refined a (.arithmetic keys goal)) := by
  exact .refine (.refl a) (.checked checked prepared)

-- 「三条件を満たす意味のモデルがある」だけから Entails の構文導出は出ない。
-- 本番の全体の言明は、以下の三つを有限の規則として構成することである。
structure PreparedLeaf (Φ : List Pred) (a : TyQ) (p : Pred) where
  keys : List Term
  assumptions : P2.Formula
  goal : P2.Formula
  cert : P2.Cert
  -- capture の根の同一性・現在の値との一致（machine_exact/stable）の構文の証拠と、
  -- 幅・長さなど（represented）の組込みの証拠を合わせたもの。
  prepared : Entails (p :: a.assume ++ Φ.map Pred.lift) (.arithmetic keys assumptions)
  checked : P2.check (.and assumptions (.not goal)) cert = true

theorem PreparedLeaf.subtype {Φ a p} (m : PreparedLeaf Φ a p) :
    TyLe Φ (.refined a p) (.refined a (.arithmetic m.keys m.goal)) :=
  checked_subtype Φ a p m.keys m.assumptions m.goal m.cert m.prepared m.checked

-- 空でない全 List に使えるが、空 List でも契約自体は成立する。区間へ型を狭めない。
-- 長さの非負性 -x≤0 から -x≤1 を実際の証明書で導く。
def relaxedLength : P2.Formula := .le ⟨[-1], 1⟩
def lengthCert : P2.Cert := .consume (.consume (.consume
  (.derive (.combine [(0,1),(1,1)] ⟨[0], -2⟩) (.close 2))))

example : P2.check (.and lengthFact (.not relaxedLength)) lengthCert = true := by decide

def lengthPrepared (a : TyQ) (Φ : List Pred) : PreparedLeaf Φ (.list a) .truth where
  keys := [.length (.var 0)]
  assumptions := lengthFact
  goal := relaxedLength
  cert := lengthCert
  prepared := .length_nonnegative (.hyp (by simp [TyQ.assume]))
  checked := by decide

theorem length_subtype (a : TyQ) (Φ : List Pred) :
    TyLe Φ (.refined (.list a) .truth)
      (.refined (.list a) (.arithmetic [.length (.var 0)] relaxedLength)) :=
  (lengthPrepared a Φ).subtype

-- 得られた葉を四種の像（型・行・範囲・値）のある本体の導出で置換できる。
theorem length_subtype_bind (a : TyQ) (Φ : List Pred) (θ : Sub) :
    TyLe (Φ.map (Pred.bind θ.values))
      ((TyQ.refined (.list a) .truth).bind θ)
      ((TyQ.refined (.list a) (.arithmetic [.length (.var 0)] relaxedLength)).bind θ) :=
  (length_subtype a Φ).bind θ

-- この代表では、数学の式が通常の長さの比較を表すことも確認する。
-- 任意の Φ の意味の健全性を構文の Entails へ置き換える完全性は仮定しない。
theorem one_key_correct (t : Term) (c d : Int) (parse) (ρ : Nat → Value) :
    (Pred.arithmetic [t] (.le ⟨[c], d⟩)).Holds parse ρ ↔
      ∃ n, t.eval ρ = some (.int n) ∧ c*n ≤ d := by
  constructor
  · rintro ⟨ν, hk, hf⟩
    exact ⟨ν 0, hk 0 t rfl, by simpa [P2.Formula.Holds, P2.Lin.Holds, P2.dot] using hf⟩
  · rintro ⟨n, he, hn⟩
    refine ⟨fun _ => n, ?_, ?_⟩
    · intro i u hu
      cases i with
      | zero => have hh : t = u := Option.some.inj hu; subst u; exact he
      | succ => simp at hu
    · simpa [P2.Formula.Holds, P2.Lin.Holds, P2.dot] using hn

theorem relaxed_length_correct (t : Term) (parse) (ρ : Nat → Value) :
    (Pred.arithmetic [.length t] relaxedLength).Holds parse ρ ↔
      (Pred.le (.lit (.int (-1))) (.length t)).Holds parse ρ := by
  rw [show relaxedLength = P2.Formula.le ⟨[-1], 1⟩ from rfl, one_key_correct]
  constructor
  · rintro ⟨n, he, hn⟩
    exact ⟨-1, n, rfl, he, by omega⟩
  · rintro ⟨x, n, hx, he, hn⟩
    have hxx : (-1 : Int) = x := Value.int.inj (Option.some.inj hx)
    exact ⟨n, he, by omega⟩

#print axioms one_key_correct
#print axioms relaxed_length_correct
#print axioms checked_subtype
#print axioms PreparedLeaf.subtype
#print axioms length_subtype
#print axioms length_subtype_bind
end P4.M6
