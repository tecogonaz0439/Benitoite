# RV2 の L2a 後の確認（Fail 捕捉の定義・言明・仮定）

## 判定

**先に直すべき点あり。** 直す点は二つあり、どちらも文書と計画を直せば済む。規則の作り直しは要らない。一つ目（重1）は、進行の言明に反例があることである。直すには `BuiltinOnly` を強める必要があり、これは状態の型付け `StateTy` の前提を変えるので、設計者の了承を要する。二つ目（重2）は、L2b を Release だけで取り込むと、脱糖の型の保存（性質1）の既存の証明が壊れることである。L2b と L2c の分け方と見積もりを直す必要がある。残りの指摘（中・軽）は、L2b の最初の作業に含めて直せばよい。

## 対象と読んだもの

基準は `b30c58e2`（L2a の取り込み後）である。読んだのは次のとおり。

- `l2a/statements.md` の全体と `l2a/results.md`
- `decisions.md` の R46〜R50。照合のために R6・R7・R13・R14・R21・R22・R24 も読んだ
- `plan.md` の作業 L2a〜L2c、`design.md` の TODO-249 と「段2の形式化」
- `reviews/RV2-initial.md` の中5〜中7
- 正式なモデル: `formal/Benitoite/Release/Typing.lean`・`Semantics.lean`・`Effect.lean`・`TypeSubst.lean`、`Lemmas/TySubst.lean`・`SubstTyping.lean`・`Preservation.lean`・`Progress.lean`、`Surface/Typing.lean`、`Surface/Lemmas/CallHead.lean`

依頼に従い、観点を四つに絞って確かめた。精読はしていない。

## 重

### 重1 `ProgressGoal` は、今の `BuiltinOnly` のままでは偽になる

- 箇所: `l2a/statements.md`「Releaseの主な三性質」の `ProgressGoal`（643〜645行目）と、658行目の「progressはFailの未捕捉をBuiltinOnlyにより除き」。定義は `formal/Benitoite/Release/Semantics.lean` 567行目の `BuiltinOnly`。
- 問題: `BuiltinOnly P B ε` が調べるのは `Eff.mem`（名前と行の所属）だけで、Fail の列を見ない。このため、次の状態が反例になる。
  - 状態は `s = .run (.app (.raise Unit Unit) [.const .unit]) [] σ` とする。
  - この状態には型が付く。`HasTypeC … [] [] none s.m Unit (singleFail Unit)` を V_Raise と C_App で導く。継続は K_Empty で、`ε = Eb = singleFail Unit` とする。`singleFail` の atoms はすべて false なので、`BuiltinOnly Eb` は空虚に成り立つ。項は閉じているので、`StateTy` が成り立つ。
  - この状態は Final でない。継続が空なので SplitAt は成り立たず、E_OpFail を使えない。ほかに一歩進める規則もない。
  - よって `ProgressGoal` の結論は成り立たない。利用者の操作が処理されずに残る場合は、エフェクトの名前が `P.effects l = none` に反することから除ける。Fail には、それに当たる除外がない。
  - `EffectSoundnessGoal` は影響を受けない。始めの状態の Eb が空の効果なので、伝播させれば矛盾が出る。影響を受けるのは、`StateTy` を前提にする進行と保存の言明である。
- 修正案: `BuiltinOnly` に `ε.fails = []`（または `∀ t, ¬ Eff.memFail ε t`）を加える。強めた条件も保存で保たれる。保存の間 Eb は変わらないので、`StateTyE` の内部の証明に新しい義務は生じない。
  - これは `StateTy` を強めるので、進行と保存の前提を変えることになる。依頼文の止まる条件に当たるので、設計者の了承を R の番号で記録する。了承を求める根拠は三つある。第一に、`BuiltinOnly` の注釈は「組み込みのエフェクトの名前の集合」とあり、Fail を含まないのが元の意図である。第二に、Fail を持たない旧来の効果は自動で条件を満たす。第三に、`effect_soundness` の前提は変わらない。
  - あわせて、statements.md の「主な三性質と同じ前提・結論」という記述を改める。

### 重2 L2b を Release だけで取り込むと、性質1の既存の証明が壊れる

- 箇所: `plan.md`「作業L2b」の「触るファイル」と「正式なモデルへの取り込みは定義と証明を同時に行い」。`l2a/statements.md`「L2cの表層・検査器への契約」の597行目「Releaseの七判断を先に証明した後、Surface…をQ付きへ一般化する」。
- 問題: L2b では、Release の V_Fun・V_Prim・C_Meth の前提に `Admissible`・`PrimitiveAdmissible`・`MethodRowsAdmissible` を加える。`Def.WellTyped` も Qsig で検査するように変わる。ところが、性質1の証明（`Surface/Lemmas/CallHead.lean` 159行目の `HasTypeV.V_Fun …` など）は、Release の判断を表層の規則の前提だけから組み立てている。表層の規則が持つのは `SatAll` と `es.length` だけである（`Surface/Typing.lean` 93〜119行目）。
  - 次の入力が反例になる。表層で `f[effect r](g: () -> Unit uses Fail[Int], r)` のように、Fail と並ぶ行 r を持つ関数を宣言する。その r を `Fail[String]` で具体化して呼ぶ。今の表層はこの呼び出しを受理する。一方、L2b 後の Release は `RowTransport` を満たさないので、この呼び出しを型付けしない。
  - したがって、L2b を取り込んだ時点で `DesugarTypedGoal` を前提を足さずに保てない。既定のビルドも通らない。`RowTransport` を Release から外すことはできない。外すと、Qsig のもとの `NoFail Q Rest` が、具体化した後に Fail を含みうるからである。このとき K_Handle_Fail は型付けできず、型の違う Fail を捕捉してしまう。
- 修正案: 次のどちらかを計画に書き、L2b と L2c の見積もりを付け直す。
  - (a) L2b に、表層の呼び出し・値化・メソッドへの Admissible の検査を加える。これには、表層の規則の前提、脱糖の証明、検査器の Q の計算、健全性11件の該当箇所の修正が含まれる。L2c には、Fail の節・単一 Fail・最小効果・正負の例を残す。
  - (b) L2b の Release の変更を差分（R23 と同じ方式）で保存し、正式なモデルへは L2c と一度に取り込む。
  - どちらの案でも、Legacy の拒否は再導入しない。(a) なら L2b の内訳に表層と脱糖の接続を 90〜180 分ほど足し、そのぶん L2c から移す。

## 中

### 中1 捕捉安全の伝播の補題を、選んだ枠より手前の K1 についての形にする

- 箇所: 「最も内側の節とEの一致」の `ContNoFailurePropagatesGoal`（501〜504行目）。
- 問題: 言明は継続全体 k について `NoHandler k .fail` を前提とし、末尾の `eout` の所属を結論にする。`FailureClauseSelectedTypedGoal` で使うのは、選んだ枠の手前の K1 で、K_Handle_Fail の穴の効果まで Fail の所属が届くことである。522行目には「分割する補題と組み合わせる」とあるが、組み合わせた形の言明がない。この言明のままでは、K1 だけの ContTy を別に作ることになる（522行目はそれを避けると書いている）。
- 修正案: 次の形の言明を加える。`ContTy R ein (k1 ++ .handleF h :: k2) a b Eb Re → NoHandler k1 .fail → memFail ein E' → ∃ ein', (handleF h :: k2 の導出の入力が ein') ∧ memFail ein' E'`。K_Sub を経由して K_Handle_Fail に至る場合も含める。言明が偽になるわけではないので、L2b の最初に加えればよい。

### 中2 Q を判断の添字でなく、パラメータにする

- 箇所: 「採る判断と閉じた入口」（112〜135行目）と `HasFailureClause` の型（389〜391行目）。
- 問題: Q は、どの構成子でも前提と結論で同じである。V_Lam・節・C_Handle_Fail も今の Q をそのまま渡す。それなのに、Q を添字（`:` の右）に置いている。Lean 4 の `induction`・`cases` では、添字に `Qempty` のような具体的な関数が入ると、一般化を手で書く必要がある。そうなると、既存の補助33件と、Regularity・Inversion・Closed・Names などの相互帰納のすべてで手間が増える。
- 修正案: Q を P・B・Ψ と同じパラメータに置く。Q を付け替える補題（型代入と単調性）は、別の Q の判断を結論にする定理として書ける。閉じた入口の別名 `HasTypeC := HasTypeCQ … Qempty` もそのまま保てる。これは見積もりの上限を超えにくくするための提案で、正しさの問題ではない。

## 軽

1. `FailureClauseNoResumeGoal`（576〜578行目）は、0番の場合だけを述べている。このままでは帰納法で示せない。七判断それぞれについて、`Γ[i]? = some none → IrrelevantSlot m i` という任意の位置の形に一般化した言明を置く。なお、`FailureInstantiateGoal` の証明にこの補題は要らない（`SubstOk` は `some` の位置しか調べない）。この補題が担うのは `failure_clause_no_resume` の主張だけであることを書き添える。
2. `.raise T E` の `Val.VarsIn`・`Support`・`NamesWF`・`ClosedNoEffVars` の場合が書かれていない。377行目にあるのは節の場合だけである。`FailureInstantiateGoal` の前提 `ClosedArgs [T]` は、V_Raise からは得られない（V_Raise が要求するのは WF だけで、NotCont を含まない）。得られるのは `Comp.VarsIn 0` からで、これは `closedArgs_of` が `Ty.VarsIn` に継続の型がないことを使うためである。`Val.VarsIn n pe (.raise T E) = Ty.VarsIn n pe T ∧ Ty.VarsIn n pe E` を明記する。
3. `ImplDecl.WellTyped` の新しい形をコード片で示していない（188行目は文章だけ）。メソッドの本体を `Qsig ms.params ms.ret ms.eff` で検査すること、上位の型クラスの辞書 u を Qempty で検査することを、`Def.WellTyped` と同じくコード片で示す。
4. V_Fun・V_Prim の `typeScope`・`rowScope`・`sourceRows` は、今の規則にない前提である。設計（design.md「Admissible…範囲と通常の制約」）の範囲内なので相談は要らない。ただし、性質1の証明が脱糖の出力についてこれらを示す義務を負う。その出どころ（表層の WF・`Ty.VarsIn`・`s.Scoped`・`Def.Scoped`）を、statements.md の表「得る場所・証明の義務」に一行足す。

## 観点ごとの確認

1. 言明の真偽と証明できる形
   - 重1のほかに偽の言明は見つからなかった。
   - `NoFailSubstAtGoal`・`RowTransportComposeScopedGoal` は成り立つ。後者は、範囲の前提 `Q0 i → i < es.length` を付けたことで成り立つ。どちらも、`rowImage` が範囲外の行を同じ番号で残す今の定義と整合する。
   - `FailureUpperBoundGoal` は成り立つ。`memFail` は正規化してから比べ、Rest の Fail 列は空だからである。
   - `CaptureBaseGoal`・`SplitFailureTypedGoal` は成り立つ。通常の `HasTypeClausesQ` は `Clause.fail` を型付けしないので、Fail の枠の上は K_Handle_Fail か、それを包む K_Sub に限られる。K_Mark が R を変えても、Rh を末尾の添字にしているので食い違わない。
   - `FailureDropGoal` と、cap に Rest を含める判断（R49）は、State の所属を戻す筋が正しい。
   - 型代入の言明は、V_Fun の場合を `sourceQ` と合成の補題で閉じられる。`typeScope` の NotCont も、`ClosedArgs` と `Ty.applyTo_notCont` で保たれる。
   - 有限遷移の四例の最終ストア（`Store.empty.set 0 .used`）は、ストアの関数の外延性で示せる。
2. 主な定理と仮定
   - 公理と `Builtins.Assumptions` の欄は足していない。捕捉の安全も仮定に置いていない。
   - E′=E と v:E は、型付けの反転・伝播・上限・Canonical から導く形になっている。
   - 性質1・健全性11件・網羅性の言明は、前提も結論も変えていない。ただし、性質1を保てるかどうかは重2に左右される。
   - 進行と保存は、重1の `BuiltinOnly` の強化を要する。
3. R46〜R50 と設計の整合
   - Release に単一 Fail を課していない（SingleFail は表層の L2c だけにある）。
   - 通常の `HasTypeClausesQ.cons` は、`Clause.mk` だけを `o ≠ .fail` の条件付きで受ける。`HasFailureClause` は `[.fail E body]` の一節だけを受ける。
   - handled の Fail 列が空であることは、定義から補題で示す形にしてある。
   - C_Handle_Fail・K_Handle_Fail の形と、Q を署名の字面だけから得ることは、design.md と R7 に一致する。
   - Fail 列を別に持つこと（R6）、正規化と `memFail` での比較（R13）、WF を Fail の内部まで再帰させること（R14）、結果の型の WF（R21）、行の像の一致を内部まで広げること（R24）とも矛盾しない。
4. 見積もり
   - L2b の Release の範囲だけなら、360〜720分は妥当な幅である。重1の直しは小さく、中2の提案を採れば上限を超えにくくなる。
   - 重2のとおり、既定のビルドを保つには、表層・脱糖・検査器の呼び出しの部分が L2b に入るか、取り込みを L2c と一度にする必要がある。今の分け方のままでは、L2b はその作業の分だけ見積もりの外にはみ出す。L2b と L2c の合計（600〜1200分）は、作業を移すだけなら大きく変わらない見込みである。
