# A4 r2 の完全署名と証明の接続

開始版 B_WORK は `d243526e8adc08eaec15abdebd724022b52937b3`。初回の完全署名は開始後60分以内に保存した。2026-11-02 の r1 は、取りまとめが Ordinary の供給を撤回し、案Aを第一として再開した指示に従う。r1 でも最初の60分以内に、refined・入れ子の data の構造の下降と、子値の大きさの下降を Lean で確認した。r2で証明に使わない四つのmotiveとfield_inputsを削除した。以下は現行の本番の完全署名である。

```lean
namespace MeaningTransport
def MOrder {P : Program} {Γ : Ctx} {Φ : List Pred} {a b : Ty}
    (v : Val) (_h : MeaningLe P Γ Φ a b) : Prop :=
  ∀ (η : ObservationEnvModel),
    (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
    ValueMeaning P η a v → ValueMeaning P η b v
def Outer (n : Nat) : Prop :=
  ∀ (v : Val), sizeOf v = n →
    ∀ (P : Program), P.VarianceValid →
      ∀ (Γ : Ctx) (Φ : List Pred) (a b : Ty) (h : MeaningLe P Γ Φ a b),
        MOrder v h
def Below (n : Nat) : Prop :=
  ∀ (w : Val), sizeOf w < n → Outer (sizeOf w)
end MeaningTransport
```

`Outer` は新しく構成した欄の `MeaningLe` も量化する。末尾の `MOrder v h` は、η・facts の真・元の意味から先の意味への含意をすべて量化する。外側の IH は `Below n`、内側は `MeaningLe` と `MeaningArgs` の相互帰納であり、後者の motive は `fun _ _ _ _ => True` である。LeQ と TypeArgsLe は `of_le`・`of_args` で写す。TelLe・TelClosure の導出には帰納しない。Prop の導出から Nat のサイズを定義しない。

`field_order` は `variance_field_mono` を使わない。型像の Ordinary、宣言の欄の型の WF と Sorted を入力に持たず、VarianceOK と構造上の比較だけで欄の比較を作る。data の意味の再構成で必要な欄の WF は、元の ValueShapeMeaning.con の証拠を保つ。証明に使わない元の四つの motive と field_inputs は r2 で削除した。Ordinary の供給不能の反例は残す。

| 枝 | r1 の状態 | 証明の接続 |
|---|---|---|
| `.data` | 証明済み | field_order の新しい MeaningLe に子値の外側 IH を適用。内側の MeaningArgs の IH では代用しない |
| `.trans` | 証明済み | 中間型の Annotation を使わず二つの内側 IH を order_trans で合成する |
| `.refine` | 証明済み | source を基底と述語の真に分解し、内側 IH と既存の valueMeaning_refine に facts を供給する |

最終の判定は [gate.md](gate.md)、検査は [results.md](results.md) に記す。

## 案Aの欄の比較と意味の移送

以下を本番に証明した。MeaningLe と MeaningArgs の構成子の完全な定義は `formal/Benitoite/Release/Refinement/MeaningOrder.lean` にある。MeaningLe は値の意味だけの補助関係であり、型付けの部分型判断として用いない。関数・依存関数・lazy・map の内部を読まない規則は、ValueShapeMeaning の対応する構成子に一致する。

```lean
MeaningTransport.field_order {P Γ Φ vs as bs} {a : Ty}
    (occurs : a.VarianceOK P vs .positive)
    (args : MeaningArgs P Γ Φ vs as bs) :
    MeaningLe P Γ Φ (a.subst as []) (a.subst bs [])

MeaningTransport.order_trans {P Γ Φ a b c v}
    {left : MeaningLe P Γ Φ a b} {right : MeaningLe P Γ Φ b c}
    (hl : MOrder v left) (hr : MOrder v right) : MOrder v (.trans left right)

MeaningTransport.order_refine {P Γ Φ a b p q v} {base : MeaningLe P Γ Φ a b}
    (ih : MOrder v base) (entails : Entails (p :: assumptions Γ Φ a) q) :
    MOrder v (.refine base entails)

MeaningTransport.order_data {n v P Γ Φ d as bs} (ih : Below n) (small : sizeOf v = n)
    (valid : P.VarianceValid)
    (args : MeaningArgs P Γ Φ (P.varianceFor d as.length) as bs) :
    MOrder v (.data args)

MeaningTransport.order_step {n v P Γ Φ a b} (ih : Below n) (small : sizeOf v = n)
    (valid : P.VarianceValid) (order : MeaningLe P Γ Φ a b) : MOrder v order

MeaningTransport.outer_complete : ∀ n, Outer n

MeaningTransport.meaning_order_sound {P Γ Φ a b v η} (valid : P.VarianceValid)
    (order : MeaningLe P Γ Φ a b)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (source : ValueMeaning P η a v) : ValueMeaning P η b v

MeaningTransport.valueMeaning_field_mono {P Γ Φ vs as bs a v η}
    (valid : P.VarianceValid) (occurs : Ty.VarianceOK P vs .positive a)
    (args : TypeArgsLe P Γ Φ vs as bs)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (source : ValueMeaning P η (a.subst as []) v) : ValueMeaning P η (a.subst bs []) v

valueMeaning_sub {P Γ Φ a b v η} (valid : P.VarianceValid)
    (sub : Ty.LeQ P Γ Φ a b)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (source : ValueMeaning P η a v) : ValueMeaning P η b v
```

構造側の variance_meaning と variance_meaning_args は総称型と引数列の子へ下る。refined は基底の比較と同じ述語を保ち、入れ子の data は各引数の極性に従って MeaningArgs を構成する。意味側は fields_meaning が元の値の子に外側 IH を適用する。したがって型の構造と値の大きさを混同せず、新しい欄の比較を元の導出の IH として扱わない。

元の S07 の valueMeaning_sub に前提を足していない。型付けから意味への全33場合と inhabits_of_typed はこの作業の対象に含めず、後続の担当へ残す。
