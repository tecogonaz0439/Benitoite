# ValueRel の強化で維持できない二つの署名

再開1では指定「強めると閉じない補題があれば、その一覧を書いて止める」に従って停止した。以下は当時の弱い ValueRel に対する旧署名と、強い関係では旧署名が偽になることの記録である。旧の弱い関係での証明の誤りを発見したものではない。再開2では取りまとめが内部署名の変更を承認し、of_ground の向きと typed_returned_mark の入力を改めた。実装後の署名は signatures.md を正とする。問題は、要求された Unit・構造値の区別を満たす関係へ置き換えたとき、現在の入力だけでは同じ結論を得られないことである。

必要条件を `IntervalRelationBoundary.ValueShape` に書いた。Unit は定数 Unit、構成子は同じ tag の構成子でなければならないという条件だけであり、要求された再帰的な ValueRel 全体の代用ではない。この必要条件への含意すら成立しないことを既定ビルドで証明した。再開2の ValueRel.shape は、強い関係からこの必要条件を取り出す。ValueMeaning・型付け規則・主な言明は変更していない。

| 閉じない署名 | 現在の入力から欠ける情報 | 既定ビルドの証拠 |
|---|---|---|
| `ValueRel.of_ground` | ConcreteValue と実値の近似の一致、および実値の Ground だけでは、Unit や構成子の形は決まらない | `RelationBoundary.ground_signature_obstruction`。独立値 Unit と実値 `con Result.Error [] []` は近似が一致し、実値は Ground であるが、実値は定数 Unit ではない |
| `typed_returned_mark` | 元状態の型付け・実際の escape・近似の一致だけでは、独立値と返却される実値の構造の対応は決まらない。仮定にあるのは `c.toApprox = v.toApprox` であり、強い値の関係ではない | `RelationBoundary.marked_signature_obstruction`。同じ具体の P/B/有効な σ で WellFormed・WellTyped・CoreAssumptions と `escape Unit` の元状態を構成する。独立値 `con Result [] Result.Ok [Unit]` と実値 Unit は旧の弱い ValueRel では関係したが、同じ行先の view の値が Result.Ok の構成子であるという必要条件は否定される |

再開1で停止した旧署名は次のとおりである。`typed_returned_mark` の EndState は、関係を強めればその強い関係を結果の値に要求するため、入力の近似の等号だけでは不足する。

```lean
theorem ValueRel.of_ground
    {c : Benitoite.Interval.ConcreteValue} {v : Val}
    (h : c.toApprox = v.toApprox) (hv : v.Ground) : ValueRel c v

theorem typed_returned_mark {P B σ Eb q k μ c v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.mark :: k) μ))
    (hv : q.view = .escape v) (happrox : c.toApprox = v.toApprox) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) ∧
    EndState (fun _ _ => False) (.normal c) k
      (.run (Closure.pure (.ret v)) k μ)
```

`marked_signature_obstruction` は、終状態の閉包を別に選ぶ逃げ道も塞ぐ。実際の行先が `run (Closure.pure (ret Unit)) [] Store.empty` であるという等号と view の等号から、関係で照合する実値が Unit であることが決まる。その実値を Result.Ok の構成子へ置き換えることはできない。未知のプログラムの整形式や組み込みの契約を別々に仮定した反例ではない。

内部署名を変える処置の候補は、`of_ground` を近似から構造を復元する入口としては使わず、既に得た強い値の関係から観測の一致を取り出す向きにすることと、`typed_returned_mark` に元の同じ値の強い関係を渡すことである。主な十言明や型付け規則の変更を要するとは判断していない。再開1では内部署名を維持できない場合にも停止する指定だったため処置を実装せず、再開2の承認後に実装した。

## 再開2の依存先

ValueRel.close、Runs.let_returned、Runs.returned_mark、normal_shared_iff、環境の延長、Examples.unit_escape は、強い関係で型検査と既定ビルドを通した。concrete_interval_control は同じ実行の終状態に関係と型付けを結んだ。Result の具体の構成子では関係から firstAlt と再帰的な束縛列を得る。未同定の other が両 tag を許す境界は results.md に分けた。主な言明・型付け規則の変更を要する新しい反例は得ていない。

再開3で、観測の射影の現行名を `ValueRel.toApprox_eq` とした。上の `ValueRel.of_ground` は、停止の根拠となった旧署名を示す名前として残す。
