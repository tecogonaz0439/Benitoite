# 判定の健全性と部分型の接続

P3 は、RV-P2 の M6 が求めた三条件を明示して、P2 の証明書の検査成功から P1 の `TyLe.refine` へ進む形を Lean で検査した。最終の検査対象は [M6.lean](M6.lean)、P3 で加えた本文だけを読む場合は [M6Body.lean](M6Body.lean) である。`M6.lean` は、P1 の `Skeleton.lean`、P2 の `lean/P2.lean`、P3 の本文を連結した独立ファイルであり、元のファイルは変更しない。

## 検査した言明

`Model.valid` は、使う値環境がソートと形の条件を満たすことを表す。例えば長さの例では self が List であることを要求する。`checked_subtype` は、この条件を Φ と carrier の所属から導く `sort_ok`、以下の三条件、前提 p と目標 q の論理への写し、証明書の検査成功を入力とし、`refined carrier p <: refined carrier q` の構文上の部分型の導出を作る。

| RV-P2 M6 の条件 | P3 の定義・検査した補題 | 本番へ残る証明・条件 |
|---|---|---|
| 組み込みの補題を事実として渡す口 | `checked_subtype` の `trustedFacts` と `builtin_ok`。同じ実環境で `trustedFacts` が真である証明を要求し、Φ と p に論理積で加えて `P2.implication_sound` へ渡す | 本番は有限の組み込みの補題から生成する。利用者の arbitrary な補題の登録口ではない。長さの非負性、幅の上下限、文字列の二つの長さ、範囲の所属等をそれぞれ証明する |
| 鍵から番号への写しの一意性と値の不変 | `Model.slot/unique/captured/current/stable`、`env_slot`、`atom_exact`。同じ正規化済みの鍵を同じ番号に写し、異なる鍵の番号の衝突を禁止する。値環境は captured の値から構成し、current と一致することを使う | 根の識別、欄の列、measure の識別子を含む鍵の構築、別名解決、限定した合同性、有限支持の証明は残る。同じ意味の別名に別番号を割り当てるのは通常は精度を落とすが、違う値を同じ番号へ潰すと健全性を壊す |
| 各幅の整数と数学上の整数の対応 | `Width.bounds`、`Model.machine_exact/width/represented` と `width_fact`。有効な環境での論理項の評価が、対応する数学上の Int を返すことと、その値域を要求する | 現行の `Const`・VM・delta との対応を証明したものではない。Integer、Integer8/16/32、UnsignedInteger16/32/64、Byte を区別する。Byte に新しい算術は加えない。幅ごとの正常な演算結果、溢れによる Stop と論理上の式の対応は標準契約の前提を証明する仕事として残る |

`Model.env` は、鍵を番号へ写した先の整数環境を構成する数学上の存在証明であり、`Classical.choose` を使う。本番の番号付けのアルゴリズムではない。有限の interning 表を本番で作り、表の lookup が同じ意味を持つ補題へ置き換える必要がある。P3 の `unique` は正規化後の異なる鍵について単射を求める十分条件である。異なる鍵を共有する実装を採る場合は、同じ番号へ写るすべての鍵の意味が等しいという条件へ置き換えて証明できる。

`stable` が検査済みの接続で使われるのは、同じ値環境に対する current と captured の一致である。実機の遷移にわたって同じ鍵を再利用してよいことまで証明していない。環境を更新した後に古い事実を使う本番の処理には、捕捉した値と鍵の意味を保存する置換・状態の保存が別に要る。Reference の現在値を読む鍵を登録しないという制限も、この本番の義務へ含める。

## 論理への写しと部分型の導出

P3 で加えた `Term` は整数リテラル・鍵・加算、`Predicate` は整数の le/eq と and/or/not を持つ。`Term.source` は P1 の `Expr`、`Term.lower` は P2 の線形係数と定数へ写す。`Term.source_exact` と `Predicate.lower_correct` により、有効な環境で両者の意味が一致する。長さや欄の連鎖は、`Model.atom` の P1 の式として表し、`machine_exact` が要求する正しい意味を持たせる。

`checked_subtype` の証明は次の順である。

1. Φ と carrier の所属から、その self を含む値環境が有効であることを得る。
2. context の事実、組み込みの事実、元の述語 p を同じ論理環境へ写す。
3. `check ((context ∧ (builtin ∧ p)) ∧ ¬q) cert = true` に `P2.implication_sound` を使い、写した q を得る。
4. `Predicate.lower_correct` で P1 の q へ戻し、`TyLe.refine TyLe.refl` で部分型の導出を作る。

これは任意の判定器に「健全である」という一つの仮定を渡しただけの P1 より具体的である。判定器の論理上の健全性は P2 の検査済みの定理を直接使い、追加の仮定は、ソート・構文の原子と値の意味・不変な環境・渡す組み込みの事実に分けた。これらを本番の主定理の新しい未検査の欄へ置く提案ではない。型付けの規則と標準の意味から各前提を導く。

## 空でない具体例と反例

`lengthModel` は self が実際の `Value.list xs` である環境について、`length(self)` の意味を `xs.length : Int` と定める。`length_fact_valid` はその非負性を証明し、`length_subtype` はその事実を使う実際の証明書を `by decide` で検査して、List の篩から非負の長さの篩へ進む。検査成功を仮定しただけの例ではない。P2 の `#guard` と異なり、ここで使う証明書の成功には Lean のカーネルで検査する証明項がある。

`wordModel` は、各幅の範囲内の整数定数について三条件を同時に満たす例である。`UnsignedInteger64` の最大値 `2^64−1` が Integer の最大値より大きいことも `by decide` で検査した。したがって UInt64 を符号付き64ビットへ落としていない。ただし本番の幅付き定数の構成子をこのモデルへ写す一般の対応を証明したものではない。

`collision_impossible` は、同じ番号を値0と値1の異なる鍵へ与え、それぞれの意味を保つ整数環境は存在しないことを証明する。同じ番号へ鍵を潰してから、番号の一致だけで元の値の等号を導く案を除くための反例である。

## 演算の正常結果を Φ へ加えるときの言明

本番では、以下の形を追加の義務として明記する。これは P3 の検査済みの定理ではない。

```text
Represented(w,x) ∧ Represented(w,y)
∧ DeltaAdd(w,x,y) = Normal(z)
  → Represented(w,z) ∧ toMath(z) = toMath(x)+toMath(y)

Represented(w,x) ∧ Represented(w,y)
∧ 数学上の和がwの範囲外
  → DeltaAdd(w,x,y) = Stop
```

Φ へ `z=x+y` を加えるのは正常結果の枝だけである。型の述語の端点として数学上の `max+1` を使うことと、実行時にその値を構築できることを分ける。比較や演算の失敗を0へ置き換えない。P3 の `Model.machine_exact` はキーで参照する原子についての橋渡しであり、任意の実行時演算の正しさをそこへ暗黙に含めない。

## 最終の境界

全ソート、減算・定数倍・厳密比較を含む表層の全正規化、すべての measure、鍵の有限な正規化器、別名と欄の合同性、各幅の実際の演算と Stop、標準 delta、Rust の検査器との全比較は未証明である。P3 の三条件の接続が通ったことを理由に、RV-P2 M5 の中心70時間をそのまま採る根拠にはしない。
