/-!
# 純粋な Result と二引数辞書の法則

成功型を先に置き、通常の関数について法則を示す。本体の型付けとは独立した
小モデルである（設計書 01-12「Resultの法則と二引数辞書の具体例」）。
-/
namespace Benitoite.Library.ResultLaws

/-- 成功型が先の結果。失敗値はそのまま保存する。 -/
inductive Result (A X : Type) where
  | ok (value : A)
  | error (error : X)
  deriving DecidableEq, Repr

/-- 成功したときだけ関数を適用する。 -/
def map (x : Result A X) (f : A → B) : Result B X :=
  match x with
  | .ok a => .ok (f a)
  | .error e => .error e

/-- 成功値を作る。 -/
def pure (a : A) : Result A X := .ok a

/-- 関数側の失敗を先に返し、両方が成功したときに適用する。 -/
def apply (fs : Result (A → B) X) (x : Result A X) : Result B X :=
  match fs with
  | .error e => .error e
  | .ok f => map x f

/-- 成功値を次の計算へ渡す。 -/
def flatMap (x : Result A X) (f : A → Result B X) : Result B X :=
  match x with
  | .ok a => f a
  | .error e => .error e

/-- pureに続けて計算した結果は、計算へ直接渡した結果と等しい。 -/
theorem flatMap_left_identity (a : A) (f : A → Result B X) :
    flatMap (pure a) f = f a := rfl

/-- 成功として戻すだけの計算は元の結果を保つ。 -/
theorem flatMap_right_identity (x : Result A X) : flatMap x Result.ok = x := by
  cases x <;> rfl

/-- 成功値を渡す計算の結合順を変えても結果を保つ。 -/
theorem flatMap_associativity (x : Result A X) (f : A → Result B X) (g : B → Result C X) :
    flatMap (flatMap x f) g = flatMap x (fun a => flatMap (f a) g) := by
  cases x <;> rfl

/-- 恒等関数による変換は元の結果を保つ。 -/
theorem map_identity (x : Result A X) : map x id = x := by cases x <;> rfl

/-- 二回の変換と合成した関数による変換は等しい。 -/
theorem map_composition (x : Result A X) (f : A → B) (g : B → C) :
    map (map x f) g = map x (g ∘ f) := by cases x <;> rfl

/-- mapはflatMapと成功値の構成から得られる。 -/
theorem map_flatMap (x : Result A X) (f : A → B) :
    map x f = flatMap x (fun a => .ok (f a)) := by cases x <;> rfl

/-- applyは関数側のflatMapと値側のmapから得られる。 -/
theorem apply_flatMap (fs : Result (A → B) X) (x : Result A X) :
    apply fs x = flatMap fs (fun f => map x f) := by cases fs <;> rfl

/-- 二つの失敗では関数側の失敗を保存する。 -/
theorem apply_error_priority (first second : X) :
    apply (.error first : Result (A → B) X) (.error second) = .error first := rfl

/-- 型だけを指定する辞書。法則を欄に含めない。 -/
structure Functor2 (F : Type → Type → Type) where
  map : {A B X : Type} → F A X → (A → B) → F B X

/-- 上位辞書と pure/apply を持つ。 -/
structure Applicative2 (F : Type → Type → Type) where
  toFunctor2 : Functor2 F
  pure : {A X : Type} → A → F A X
  apply : {A B X : Type} → F (A → B) X → F A X → F B X

/-- 上位辞書と flatMap を持つ。 -/
structure Monad2 (F : Type → Type → Type) where
  toApplicative2 : Applicative2 F
  flatMap : {A B X : Type} → F A X → (A → F B X) → F B X

/-- Result の三辞書。 -/
def resultFunctor : Functor2 Result := ⟨map⟩
/-- Result の pure/apply と上位辞書。 -/
def resultApplicative : Applicative2 Result := ⟨resultFunctor, pure, apply⟩
/-- Result の flatMap と上位辞書。 -/
def resultMonad : Monad2 Result := ⟨resultApplicative, flatMap⟩

/-- 二段の上位射影から得るmapは直接の定義と等しい。 -/
theorem projected_map (x : Result A X) (f : A → B) :
    resultMonad.toApplicative2.toFunctor2.map x f = map x f := rfl

/-- 上位射影から得るpureは直接の定義と等しい。 -/
theorem projected_pure (a : A) :
    resultMonad.toApplicative2.pure (X := X) a = pure a := rfl

/-- 上位射影から得るapplyは直接の定義と等しい。 -/
theorem projected_apply (fs : Result (A → B) X) (x : Result A X) :
    resultMonad.toApplicative2.apply fs x = apply fs x := rfl

-- 型引数を使わない二引数型も辞書の型を満たすが、単位則は従わない。
/-- 型だけでは法則を要求できないことを示す辞書。 -/
def unlawfulMonad : Monad2 (fun _ _ => Bool) :=
  ⟨⟨⟨fun x _ => x⟩, fun _ => true, fun _ _ => false⟩, fun _ _ => false⟩

/-- 辞書の型を満たすだけでは左単位則が従わない。 -/
theorem dictionary_type_does_not_imply_law :
    unlawfulMonad.flatMap (A := Unit) (B := Unit) (X := Unit)
      (unlawfulMonad.toApplicative2.pure (X := Unit) ()) (fun _ => true) ≠ true := by decide

end Benitoite.Library.ResultLaws
