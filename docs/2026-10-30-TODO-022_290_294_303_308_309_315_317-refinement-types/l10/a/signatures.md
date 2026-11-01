# 共有近似と実解析の写しの完全署名

2026-11-01。対象は L10.52〜L10.54。指定ブランチは `m014/l10.a`、B_WORK は `a0dc79a7a0014d1b4d4f61f8ac817beffec2f030`。git による照合・操作は行わない。本書を実装に先立って置く。

## 公開する定義と定理

`formal/Benitoite/Shared/Approximation.lean` の `Benitoite.Shared` 名前空間へ追加する。

```lean
def ValueApprox.possible : ValueApprox → Bool
def ValueApprox.WF : ValueApprox → Prop
def FlowApprox.WF (a : FlowApprox) : Prop := a.normal.WF ∧ a.returned.WF
theorem ValueApprox.possible_iff (a : ValueApprox) :
  a.possible = true ↔ ∃ v, a.Mem v
theorem ValueApprox.not_possible_iff (a : ValueApprox) :
  a.possible = false ↔ ∀ v, ¬ a.Mem v
theorem ValueApprox.wf (a : ValueApprox) : a.WF
theorem FlowApprox.wf (a : FlowApprox) : a.WF
```

`formal/Benitoite/Interval/ApproxAdapter.lean` の `Benitoite.Interval` 名前空間へ追加する。

```lean
theorem normalToShared_iff {type : Benitoite.Release.Ty}
    {range : NormalRange type} {value : ConcreteValue} (typed : value.type = type) :
  (normalToShared type range).Mem value.toApprox ↔ NormalMem type range value
def baseToShared (type : Benitoite.Release.Ty) (b : BaseApprox) : Shared.ValueApprox
theorem baseToShared_mem {b : BaseApprox} {value : ConcreteValue}
    (h : b.Contains value) :
  (baseToShared value.type b).Mem value.toApprox
```

`formal/Benitoite/Interval/BudgetAnalyze.lean` の `Benitoite.Interval.BudgetAnalysis` 名前空間へ追加する。

```lean
def Report.sharedFlow (r : Report) (type : Benitoite.Release.Ty)
    (returned : Shared.ValueApprox) : Shared.FlowApprox :=
  ⟨baseToShared type r.approx, returned, r.approx.mayFail⟩
theorem Report.shared_normal (r : Report) (type : Benitoite.Release.Ty)
    (returned : Shared.ValueApprox) {v : ConcreteValue}
    (h : (r.toAnalysisResult type).normal v) :
  (r.sharedFlow type returned).NormalMem v.toApprox
@[simp] theorem Report.shared_returned (r : Report) (type : Benitoite.Release.Ty)
    (returned : Shared.ValueApprox) (v : Shared.ApproxValue) :
  (r.sharedFlow type returned).ReturnedMem v ↔ returned.Mem v
@[simp] theorem Report.shared_mayFail (r : Report) (type : Benitoite.Release.Ty)
    (returned : Shared.ValueApprox) :
  (r.sharedFlow type returned).mayFail = r.approx.mayFail
```

`formal/Benitoite/Release/Refinement/ApproxAdapter.lean` の `Benitoite.Release.Refinement` 名前空間へ追加する。

```lean
theorem constOK_toApprox {B : Builtins} {c : Const} {k : Benitoite.Interval.IntKind}
    (ok : ConstOK B c)
    (kindOf : Benitoite.Interval.IntKind.ofRefinementType c.type = some k) :
  ∃ n : Benitoite.Interval.IntegerValue k, c.toApprox = .integer k n
```

## 補助の契約についての決定

1. `possible` は bottom、整数の bottom、Boolean の両フラグ false を空と判定する。構造等号による単一の空表現への正規化は要求しない。
2. `ValueApprox.WF` は整数の closed に限り、格納した証拠と同じ `k.min ≤ lo ∧ lo ≤ hi ∧ hi ≤ k.max` を要求する。他の場合は True とする。`wf` は全近似について証明し、主定理の仮定へ足さない。`FlowApprox.wf` は二成分への系として加える。
3. `normalToShared_iff` は明示された型一致を保つ。写しで情報を失う非整数型の逆向きに必要な条件である。
4. `baseToShared` は `IntKind.ofType` が some のとき `rangeKind`、Boolean のとき二フラグを読む。それ以外は `b.other && b.nonIntegerOther` が true のとき unknown、false のとき bottom とする。レビューの中1と取りまとめの判断を受け、非整数・非Boolean の位置でも実 Report の正常値なしを保つ形へ改めた。所属保存の署名は保つ。
5. `Report.sharedFlow` は計算可能な実データだけを読む。returned は明示引数で、解析済みと主張しない。警告・キー・停止・追跡は元の Report に残す。returned と mayFail の射影の等式を補助として加える。失敗の意味の健全性はこの群で結論しない。
6. `constOK_toApprox` は七整数の種類を入力条件とする。Byte・Decimal・String 等の非 other は主張しない。整数の値と端点は数学上の Int と証拠付きの値を使い、新しい ID・エラー・整数表現を加えない。

五つの境界（主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態）の変更はない。`HasTypeVQ`・`HasTypeCQ` と旧区間解析の定理は変更しない。

## 境界例の関門

`boundary.lean` を adapter の持ち主の境界とし、本番の定義と実解析の入口を import する。空の三表現を一つしか認識しない退行、returned と normal の混同、mayFail の消去、幅や端点の取り違え、Byte・Decimal を整数へ写す退行を捕まえる。既存の例は新しい実 Report の写しを通らないため、この境界に置く。定義の複製やテスト専用の本番入口は加えず、正例の結論を前提にしない。

具体的な Report の全体を所属の型合わせで展開すると、境界の検査がメモリ上限へ達した。境界だけの非公開補助 `return_witness`・`failure_witness` は任意の Report について制御成分の関係を証明し、公開する具体例で実解析から成分の等式を `cbv` で証明して渡す。実解析の結論を仮定する例は置かない。本番に補助の入力や計算上限を追加せず、既定の `-M 12288` を保つ。

## レビュー後の L40 への入力

`constOK_toApprox` の結論の `∃ n` は、共有の値が同じ幅の整数であることを述べる。n の値と元の定数の数学上の整数との一致は、この言明だけからは得られない。L40 の正常結果・算術の葉で値の一致を使う場合は、元の整数値を明示し、`n.toInt` との等式を結論する補題を同段の担当が加える。`ApproxValue.ofInt_bounded` はその証明に使える。既存の `constOK_toApprox` の署名は変えず、境界の14端点の一致を任意の定数の値保存の定理と扱わない。
