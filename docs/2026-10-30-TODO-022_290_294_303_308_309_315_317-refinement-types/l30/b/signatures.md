# 群B・Cの本番の署名

2026-11-03。名前空間は `Benitoite.Release.Refinement`。linearize_sound_at・normalize_sound_atの群Aの固定署名は維持する。再開1では軽2の指示に従い、符号化の意味の三補題から列長の前提を外した。`EqualityMode`は定義・完全名を保って独立モジュールへ移した。`Linear`・符号化・`keyEnv`・`linearDot_scale`は群Aの実装を読む。

## 鍵と構造比較

```lean
inductive EqualityMode where
  | structural | integer
  deriving DecidableEq
abbrev KeyTable := List Term

def termEq : Term → Term → Bool
def slotEq : Option Term → Option Term → Bool
def slotsEq : List (Option Term) → List (Option Term) → Bool
theorem termEq_spec (t u : Term) : termEq t u = true ↔ t = u
theorem slotEq_spec (a b : Option Term) : slotEq a b = true ↔ a = b
theorem slotsEq_spec (as bs : List (Option Term)) : slotsEq as bs = true ↔ as = bs

def predEq : Pred → Pred → Bool
theorem predEq_spec (p q : Pred) : predEq p q = true ↔ p = q

def keyIndex : KeyTable → Term → Option Nat
theorem keyIndex_sound {keys : KeyTable} {t : Term} {i : Nat}
    (h : keyIndex keys t = some i) : keys[i]? = some t
```

`termEq`/`slotEq`/`slotsEq`とその同値は相互再帰である。`predEq`はPredの構造再帰である。既存の非計算的なDecidableEqを使わずにTerm/Predを比較する。有限の付随データの等号には、その型の既存の構成的なDecidableEqを用いる。

## 線形化

```lean
def keyCoefficients : Nat → Nat → List Int
theorem linearDot_keyCoefficients {n i : Nat} (h : i < n) (ρ : Nat → Int) :
    linearDot (keyCoefficients n i) ρ = ρ i

def linearize (keys : KeyTable) (t : Term) : Option (List Int × Int)
theorem linearize_length {keys : KeyTable} {t : Term} {cs : List Int} {b : Int}
    (h : linearize keys t = some (cs,b)) : keys.length = cs.length

theorem linearDot_add {as bs : List Int} (h : as.length = bs.length) (ρ : Nat → Int) :
    linearDot (List.zipWith (·+·) as bs) ρ = linearDot as ρ + linearDot bs ρ

theorem linearize_sound_at {keys : KeyTable} {t : Term} {cs : List Int} {b : Int}
    (h : linearize keys t = some (cs,b)) (ν : ObservationEnv) (η : ObservationEnvModel) :
    integerAs η (termBind ν t) = linearDot cs (keyEnv η (keys.map (termBind ν))) + b
```

非公開の補助は `checkAffine (n : Nat) (a : List Int × Int)`、そのbindの成功と元の出力・長さの同値 `bind_checkAffine`、零係数の内積 `linearDot_zero`、成功した鍵の像の射影 `keyEnv_lookup`である。各出力を長さ検査に通す。構造再帰を明示したため、具体の計算は核内の`by decide`で再生できる。証明の帰納は任意のνをそのまま量化し、像で鍵の位置を作り直さない。

## 否定標準形

```lean
inductive NNF where
  | truth | falsity
  | linear (constraint : Linear)
  | literal (atom : Pred) (negative : Bool)
  | and (left right : NNF)
  | or (left right : NNF)
def NNF.toPred (keys : KeyTable) : NNF → Pred

def normalizeBound (keys : KeyTable) (a b : Term) (bound : Int) : Option NNF
theorem normalizeBound_sound_at {keys : KeyTable} {a b : Term} {bound : Int} {q : NNF}
    (h : normalizeBound keys a b bound = some q) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (q.toPred keys)).interpret η =
      decide (integerAs η (termBind ν a) - integerAs η (termBind ν b) ≤ bound)

def normalize (keys : KeyTable) (p : Pred) (negative : Bool) : Option NNF

theorem normalize_sound_at {keys : KeyTable} {p : Pred} {negative : Bool} {q : NNF}
    (h : normalize keys p negative = some q) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (q.toPred keys)).interpret η =
      (if negative then !((predBind ν p).interpret η) else (predBind ν p).interpret η)

theorem normalize_sound {keys : KeyTable} {p : Pred} {negative : Bool} {q : NNF}
    (h : normalize keys p negative = some q) : ∀ η : ObservationEnvModel,
    (q.toPred keys).interpret η = (if negative then !(p.interpret η) else p.interpret η)
```

`normalizeBound`とその健全性は整数の比較3形が共有する補助である。非公開の `literal_sound`・`integer_eq_normalized`・`integer_le_normalized`・`integer_lt_normalized`を全場合の一つの帰納で読む。恒等置換の系も本番の具体例が使う。trace・DNF全枝列・新しい外部状態・独立の上限を引数に足していない。

## 再開1: 列長を要求しない符号化

次の三署名へ置き換えた。同じ名前で前提を外し、列長を仮定する旧版と補助の別名を残さない。

```lean
theorem linearTerm_integerAs (η : ObservationEnvModel) (keys : List Term) (cs : List Int) :
    integerAs η (linearTerm keys cs) = linearDot cs (keyEnv η keys)
theorem Linear.toPred_sound (η : ObservationEnvModel) (keys : List Term) (l : Linear) :
    (l.toPred keys).interpret η = true ↔ l.Holds (keyEnv η keys)
theorem Linear.toPred_sound_at (η : ObservationEnvModel) (ν : ObservationEnv)
    (keys : List Term) (l : Linear) :
    (predBind ν (l.toPred keys)).interpret η = true ↔
      l.Holds (keyEnv η (keys.map (termBind ν)))
```

鍵が足りない位置のkeyEnvは整数0であり、係数が先に尽きれば符号化も内積もそこで終わる。LinearizationExamplesで両方向の列長不一致に適用し、LogicNormalizationExamplesでnormalizeから得た線形の葉のHoldsを取り出して、同じ環境で非負結合する。linearize_lengthは線形化の出力の長さの性質として具体の読者が使う。
