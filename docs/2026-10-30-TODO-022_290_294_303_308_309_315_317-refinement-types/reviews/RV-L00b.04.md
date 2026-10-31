# RV-L00b.04: 閉じた評価（L00b.04）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.04 の未コミットの作業ツリーにある `formal/` の本番の変更である。基準 `610bd4eb` からの差分は、`formal/Benitoite.lean` の import の追加、`Logic.lean`・`Basic.lean` の変更、新規7ファイル（`Refinement/` の `Observation`・`ClosedEvaluation`・`ClosedDecidable`・`ClosedKeys`・`LogicSound`・`Carrier`・`ExternalCheck`）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.04-request.md)
- `l00b.04/` の `signatures.md`・`results.md`・`boundary.lean`・`case-inventory.txt`・`axioms-summary.json`・`delivery.json`
- plan.md の L00b.04 の行、O046 の行、2026-10-31 の外部の受信検査の判断の行
- decisions.md の D19、`l00b.02/signatures.md` の第3.2節・第12.2節の `.04`・`.05`・L60 の行・外部の信頼条件の改訂予定
- 本番の `Context.lean`・`TermSyntax.lean`・`Syntax.lean`・`PathResolution.lean`・`Typing.lean`・`Semantics.lean`・`Step.lean`・`External.lean`・`ExternalResponse.lean`・`TelTyping.lean`・`Telescope.lean`
- 設計書の 01-04（Float・Decimal・String）、01-06（等値の型・鍵の型）、03-06（Map と Set・鍵の順序）
- 処理系の `crates/benitoite/src/runtime/map/keys.rs`・`runtime/map.rs`・`runtime/equal.rs`・`base/prim.rs` の `cmp_key_atom`

Lean は局所に実行した。補助のファイルはリポジトリの外（`<tmp>/rv04/`）に置き、いずれも `cd formal && lake env lean -M 12288 <ファイル>` で誤り0件、`sorry` なしである。公理の依存は propext・Classical.choice・Quot.sound の範囲である。全体の `lake build` は繰り返していない。担当の `boundary.lean` も再実行し、誤り0件を確かめた。

1. `ieee.lean`。`ieeeCompare` を Lean の `Float`・`Float32` の比較と、特殊値16個の全組・比較6種の計3,072通りで突き合わせ、不一致0件である。`ieeeClass` も binary64 の同じ16値・6分類で不一致0件である。Decimal の比較と `decimalNormal` の負数・0も確かめた。
2. `orfail.lean`。型付けできる値を受信検査が拒む例（中1）。
3. `misc.lean`。`Const.type` が `.base k` の定数の受理、And/Or/Not の `ClosedObservable`、入れ子の鍵、`Allowed` の拒否、`¬ Entails [] .falsity`、閉じて偽の述語が導けないこと、`p` と `not p` が同時に `some true` にならないこと、`externalCheckedOutcome` の no-exit の保存、再帰する data の深い位置の受理と拒否。

## 総評

**条件付き可**である。重の所見はない。読んだ範囲の本番の定義と証明に、定理を偽にする誤りは見つからなかった。評価の失敗と sort の不適格は真へ変わらず、`Entails.sound` により導出は無矛盾であり、値の比較の意味は仕様と処理系に一致し、`externalCheck` は全入れ子を検査し、五つの境界にも触れていない。

条件は中の1件である。And/Or が両側の成功を要求する今の評価は依頼の契約どおりだが、`V_Refine` で型付けできる値を受信検査が拒む例がある。これは書ける形の実用に関わる決定なので、`.05` が検査を遷移へ接続する前に、設計者の判断を得ることを勧める。実装の誤りではない。

## 観点ごとの判定

| 観点 | 判定 | 根拠 |
|---|---|---|
| 1. 評価の失敗・sort 不適格 | 可 | `evalClosed` は WF 0 と Sorted を先に検査する。原子は `atomReady` が成り立つときだけ値を返す。Not は `Option.map`、And/Or は do で両側を先に求め、短絡しない。`termReady` は `observe` を読むので、既定値を使う `interpret` は成功の可否に入らない |
| 1. 既定値の漏れ | 可（軽4） | 演算ごとの既定値は `interpret` にだけある。ready のとき `observe_sound` と sort の一致から `observeAs` は観測値そのものになる。読めば確定するが、本番の補題にはなっていない。`Term.observe_sound` は本番から引かれていない |
| 1. 言明の空虚さ | 可 | `evalClosed_sound` は定義からほぼ直ちに従うので、内容は `atomValue` の定義にある。その定義は観点3で照合した。`ClosedObservable` は atom・And・Or・Not の全構成子で正例を作れ、`missing_not_observable` が負例である |
| 2. `Entails.closed` | 可 | 公理ではなく構成子であり、健全性を `Entails.sound` の closed の枝で証明している。計画の `Entails.ground` は閉じた述語を空の仮定から導く規則であり、任意の Ξ への一般化は ground と弱化の合成と同じ強さである。`Ξ` を空に固定すると弱化の枝を再構成できないという理由も正しい |
| 2. 全規則と無矛盾性 | 可 | weaken・cut・bind は closed の枝を足しただけで、既存の枝の差分はない。`predBind ν p = p` は WF 0 と `bind_congr`・`predBind_id` から導かれ、`VarsIn` は slots の内側も数える。`misc.lean` で `¬ Entails [] .falsity` と閉じて偽の述語の非導出を確かめた |
| 3. Decimal | 可 | 比較は `c*10^t` と `d*10^s` の比較で数の大小である（01-04、`cmp_num`）。鍵は `decimalNormal` で数の等値に揃い、入れ子でも同じである。表現の範囲 |m|<2^96、e≤28 も 01-04 に一致する |
| 3. Map・Set | 可 | 大きさは鍵の重複を縮約した長さで、値の欠けを許す。元の鍵と後の値は 03-06 と `map.rs` に一致する。Map/Set を鍵にしたときの順序の独立と、値まで比べることは `keys.rs` の `Trees` と一致する。Float と target を鍵のコードから除くのは 01-06 の鍵の型に一致する（`scoped` は等値の型でない） |
| 3. IEEE | 可 | NaN は `<>` だけ true、符号付き0は等しい（01-04、`equal.rs`）。`ieee.lean` で実際の Float と全組を突き合わせた |
| 3. String・Character・Boolean | 可 | 文字数はスカラー値、バイト数は UTF-8 である。`Allowed` が String・Boolean・Unit の順序比較を拒むので、`fromEqLt` の `false false` には到達しない |
| 4. `Ty.carrier` | 可（軽1） | 全21構成子を扱い、`Atom` は型を持たないので Eff も fails だけでよい。`tapp` の頭は番号である。冪等性と `carrier_free` は証明済みである |
| 4. `ExternalCarrier` | 可 | `ExternalValueType` の全形（scalar・unit・bytes・handle・list・map・flags・data・refined）を覆う。`.scalar`・`.handle` の `HasTypeV` は基本型と外部型の所属だけであり、述語の真を含まない。`zero_still_has_carrier` が確かめる |
| 4. `externalCheck` | 可（中1） | 結果の最外、List・Set、Map の鍵と値、data の具体化した全欄を検査し、`toTerm?` の none と評価の失敗は false である。`getD` を通らない |
| 4. `checked_typed` | 可 | 前提は carrier と検査だけである。`refine_checked` は `closedTrue_entails` から `V_Refine` か `LeQ.introduce` へ戻す。sort のない芯の述語は `closedTrue` が WF 0 を要求する |
| 4. 再帰する data | 可 | `(sizeOf v, sizeOf a)` の辞書式で停止し、`partial` はない。境界に例がないので `misc.lean` で2段の連結の受理と深い位置の違反の拒否を確かめた（軽2） |
| 5. `.05` への形 | 可 | `HasTypeTelArgsQ.instantiate` が `Tel.instantiate` と型付けの結果型を結ぶので、`E_External` は `ExternalSignature.instantiate` で同じ `a` を得られる。`Outcome.err` は `ErrKind` を持ち、既存の `.error [r] k μ` へ進める。検査は Bool で全域なので進行を妨げない。no-exit の保存は `misc.lean` で確かめた。事象を足さない |
| 6. 正例と負例 | 可 | `closed_not_add` → `not_add_ground` → `seven_typed` → `captured_fact`・`capture_condition` は実値から作り、結論を仮定しない。`builtins` は `sat` だけを定める有限の例と明記している。負例は `decide` の計算で、前提の矛盾で真になっているものはない |
| 6. 場合の数 | 可 | Term20・Observation14・Entails18・ClosedObservable4・ExternalCarrier8・Each2・Fields2 を原文で数え、`case-inventory.txt` と一致する。境界の名前付き定理81件、新規7ファイル907行も一致する。予定の誤記は `signatures.md` 末尾で訂正している |
| 7. 五つの境界と抜け道 | 可 | 主な定理の前提と結論、提供範囲、利用者の書ける形、精密な外部状態の定義を変えていない。`Entails` は広がるが健全である。対象の9ファイルに `sorry`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern` はない。`opaque` の一致は `Carrier.lean` 16行の型の構成子だけである。文書に手元の絶対パスと `work/` の参照はない |

## 新しい所見

読めば確定するものと、実行しないと分からない疑いを区別する。

### 重

なし。

### 中

**中1. And/Or が両側の成功を要求するので、型付けできる値を受信検査が拒む**（`ClosedEvaluation.lean` 106〜110行、`ExternalCheck.lean` 27〜32行。Lean で再現済み）

問題: `evalWith` は And/Or の両側が成功するときだけ `some` を返す。依頼の「短絡で失敗を隠さない」には一致する。しかし、片側だけで真偽が決まる述語でも、もう一方の観測の失敗が全体の失敗になり、受信検査は false になる。

反例: `<tmp>/rv04/orfail.lean`。`Opt` が `None` と `Some(Integer)` を持つとき、述語は `x is None or 0 < x.value` である。`Term.Source` と `Pred.Source` はこの形を許す。

- `(cond.open None).evalClosed = none`（右の欄が観測できない）。
- `Entails [] (cond.open None)` は `or_left` と左の `ground` で導ける。したがって `V_Refine` で型付けできる。
- `externalCheck prog None (.refined Opt cond) = false`。

したがって、述語を満たすゲストの正常な結果が `ExternalRefinement` の err になる。安全側の誤りであり、どの定理も壊さない。ただし「違反した結果を err にする」という判断より拒否の範囲が広く、複数の構成子を持つ data の自然な述語で起きる。`not (x is Some and x.value <= 0)` も同じである。

修正案: 次のどちらかを設計者が選ぶ。制限の決定なので独立した問いとして示す。

- (a) And/Or を強い Kleene の三値にする。Or は片側が `some true` なら `some true`、And は片側が `some false` なら `some false` とする。`Pred.interpret` は二値なので `evalWith_sound` はそのまま成り立ち、上の反例が示すとおり `Entails` が既に導ける結論を計算で得るだけである。失敗が真へ変わるのではなく、真は成功した側から来る。Not も失敗を保つ。`failure_and_false`・`failure_or_true` の期待を改め、依頼の契約の文を直す。`evalClosed_complete` は今の条件のままでよい。
- (b) 今の契約を保つ。`.13` が複数の構成子の欄の意味（RV-L00b.02b-values 軽2の送り先）を決めるときに合わせて扱い、受信検査がこの形を拒むことを利用者向けの範囲に明記する。

(b) を採っても `.05` の接続は変わらない。(a) なら `.05` の前に直すほうが手戻りが少ない。

### 軽

**軽1. `Ty.carrier` が検査のどの定義からも読まれない**（`Carrier.lean`。読めば確定）

問題: `Ty.carrier`・`RefinementFree` は `ExternalCarrier`・`externalCheck`・`Outcome.Carrier` から参照されず、両者を結ぶ定理もない。data の欄の篩を除けないという理由は `signatures.md` にあり、判断は妥当である。しかし計画と義務の表の「結論を carrier へ弱める」を読むと `a.carrier` の型付けと誤読できる。

修正案: `.05` の改訂で、外部の信頼条件の結論が `Outcome.Carrier P B Ψ out a`（元の型 a に添字を持つ判断）であることを義務の表に書く。`Ty.carrier` が `.05` でも要らなければ、消すか使う場所を決める。

**軽2. 受理の側の補題がない**（`ExternalCheck.lean`。読めば確定）

問題: `checked_typed` と `externalCheckedOutcome_typed` は、`externalCheck` が常に false でも成り立つ。検査が正しい値を受理することは境界の正例だけが支えている。再帰する data の正例と負例も境界にない。

修正案: `.05` か L60 で、篩を持たない型の carrier なら検査が true になること、中1の扱いが決まれば篩を満たす観測可能な値が受理されることを補題にする。境界に再帰する data の受理と深い位置の拒否を足す（`<tmp>/rv04/misc.lean` の `deep_ok`・`deep_bad` の形でよい）。

**軽3. 鍵の縮約が二つあり、一致の補題がない**（`Observation.lean` 49〜95行と `ClosedKeys.lean` 17〜32行。読めば確定）

問題: 評価器が使うのは `mapKeys`・`keySetCodes` である。`Key.normalizeMap`・`normalizeSet`・`Key.equal` は本番から読まれず、境界だけが使う。`Key.equal_sound` も定義の展開である。今回の評価の健全性には影響しない。

修正案: O022 の担当（`.05`・L30・L50）が使う側を決め、片方に寄せるか、長さの一致の補題を置く。

**軽4. ready のときの観測の一致が本番の補題になっていない**（`ClosedEvaluation.lean` 84〜104行。読めば確定）

問題: `evalWith_sound` は `atomValue` 同士の一致なので、既定値が述語の真偽へ漏れないことを定理としては述べていない。`Term.observe_sound` はその根拠だが、本番から引かれていない。今の定義に誤りはない。

修正案: `termReady η s t = true` から `t.observe η = some o`・`o.sort = s`・`observeAs η s t = o` を導く補題を置く。O022 の「観測との一致」でこの補題が要るので、`.05` で足せばよい。

**軽5. 束縛の `getD (.integer 0)` と評価器の間の区別**（`TermSyntax.lean` 71〜76・85行。読めば確定した事実と、`.05` で確かめる義務）

問題: `termBind` は環境が none の変数を `.integer 0` へ写す。評価器は出どころを区別できず、この0を成功の観測として数える。`externalCheck` 自身は `toTerm?` の none を false にするので安全である。一方、`Tel.argumentsEnv` は実引数の `toTerm?` が none でも束縛するので、依存する結果型の具体化ではこの経路を通る。sort のない実引数を根の位置で読む述語は `Sorted` が拒み、slots の中は none を保つので、今の定義で0が結果へ届く例は見つけていない。

修正案: `.05` の改訂で、結果型の具体化を検査へ渡す前提として、sort を持つ型の閉じた値の `toTerm?` が some になることを補題で確かめる。

**軽6. 拒否した結果の所有ハンドルの解放**（`ExternalCheck.lean` 167〜170行。実装で確かめる事項）

問題: 外部の結果の `own` のハンドルを含む値が篩に違反すると、結果全体が err になる。形式化は所有権ヒープを表さないので遷移に現れない。実装が値を捨てるときにゲストのリソースを解放しないと、解放漏れになる。

修正案: 新しい義務として L70・R50 の受信経路の照合に加える。今回の形式化の変更は要らない。

## 申し送り

- 中1の判断は `.05` の開始の前に設計者へ示す。
- 軽1と軽5は `.05` の完了条件へ写す。軽2は `.05` か L60、軽3と軽4は O022 の担当、軽6は L70・R50 へ送る。
- `evalClosed_sound` の前提 `_hw`・`_hs` は証明に使わないが、公開の署名を計画に合わせたものなので残してよい。

## 取りまとめの追記

2026-10-31。補助の入力を `l00b.04/rv-04-ieee.lean`・`rv-04-orfail.lean`・`rv-04-misc.lean` へ写した。
