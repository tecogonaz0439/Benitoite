# L00b.05: 証明書の葉と外部受信検査の完全署名

2026-10-31。B_WORK は `0f771fa1789728aa00dc35b1eb6db9ac6345833e`、指定ブランチは `m014/l00b.05`。git の操作・照合は行わない。本書を本番の編集より先に置く。共通依頼文、plan の2026-10-31の全行、O019/O022、第12.2・25節、.04 の残りを引き継ぐ。主定理の結論、新しい公理、提供範囲、書ける形、精密な外部状態は変えない。external_typed の carrier 化と受信検査は承認済み D28 とする。

## 外部の公開署名

接頭辞は `Benitoite.Release.Refinement`。表示した自由変数は全称量化する。

```text
Builtins.ExternalAssumptions.external_typed : ∀ Ψ f d ts vs a e out obs,
  P.ExternalWF → P.externalFunction f = some d → ExternalArgs P B Ψ d ts vs a e →
  B.externalResponse f ts vs out obs → Outcome.Carrier P B Ψ out a ∧ (∀ n : Int, out ≠ .exit n)
```

external_exists/external_no_targets は前提・結論を保つ。Outcome.Typed の定義を ExternalCheck に移して import の循環を避ける。Outcome.Carrier は元の型と宣言欄を添字に持ち、Ty.carrier で型付けるという意味ではない。

```text
Builtins.ExternalAssumptions.checked_typed :
  P.ExternalWF → P.externalFunction f = some d → ExternalArgs P B Ψ d ts vs a e →
  B.externalResponse f ts vs out obs →
  Outcome.Typed P B Ψ (externalCheckedOutcome P a out) a ∧
  (∀ n : Int, externalCheckedOutcome P a out ≠ .exit n) ∧ obs = []
externalReceive : Program → ExternalSignature → List Ty → List Val → Outcome → Option Outcome
```

externalReceive は instantiate で結果型を求めて externalCheckedOutcome を適用する。E_External は externalReceive の結果が val であること、E_ExternalErr は err であることを検査する。raw val の拒否も後者に入る。step は同じ関数を呼び、exit には遷移しない。ラベルは none、σ は固定する。二規則の数は変えない。

```text
HasTypeVQ.closed_observation : HasTypeVQ P B Ψ Q C [] Φ v a → a.HasSort s →
  ∃ t, v.toTerm? = some t ∧ t.HasSort [] s ∧ t.Closed
HasTypeVQ.argumentsEnv_observation : HasTypeVQ P B Ψ Q C [] Φ v a → a.HasSort s →
  ∃ t, (Tel.argumentsEnv v).values 0 = some t ∧ termBind (Tel.argumentsEnv v).values (.var 0) = t ∧ t.Closed
Ty.sort_carrier : a.carrier.sort? = a.sort?
```

上の補題は型付きの値の observation と references から導く。snapshot の none を埋めず、termBind の根の getD が観測成功の代わりにならないことを示す。成功後の型付けは ExternalCarrier.checked_typed を使い、違反は ExternalRefinement の err へ進む。

## 証明書の公開署名と担当範囲

```text
EqProof : Type -- refl / symm / trans / add の有限木
EqProof.check : Term → Term → EqProof → Bool
EqProof.sound : EqProof.check t u c = true → t = u
BuiltinLemma : Type -- closed / lengthNonnegative
PreparedLeaf : Type -- predicate と有限 builtinLemma
PreparedLeaf.check : PreparedLeaf → Bool
PreparedLeaf.entails : leaf.check = true → Entails Φ leaf.predicate
Certificate : Type -- use / leaf / substitute / consume / cases / discard
Certificate.check : List Pred → Pred → Certificate → Bool
Certificate.sound : Certificate.check Φ p c = true → Entails Φ p
```

参照は現在の枝の仮定の列に対する Nat の lookup とする。未来・範囲外・兄弟の参照は成功しない。substitute は EqProof で検査した項の等号による述語の open の置換であり、意味上の任意の等号を前提にしない。consume は先頭 And を分解し、cases は先頭 Or の二枝を別々に検査し、discard は先頭を使わない。外部 normalizationTrace を受け取る欄は置かない。

machine_exact は閉じた評価の some true と二値モデルの一致、stable は閉じた葉への値置換の不変、represented は typed observation と数値の既存 ConstOK の範囲を指す。builtin の代表は閉じた List.length の非負とし、ground から Entails を構成する。全 sort の開いた線形算術、否定標準形・線形化との交換、意味上の別名合同、全 measure/実δ/鍵の等値の一致は L30/L50 に残す。未証明の一致を新しい信頼条件にしない。

## 場合の数と境界入力

予定は EqProof4、BuiltinLemma2、Certificate6、既存 ExternalCarrier8/Each2/Fields2 と Step76 を保持する。新補題は既存の型付き observation を再利用し、三族71と TypedFacts56 の場合を増やさない。境界入力で、受信成功/違反それぞれの StateTy → Step → StateTy と step の選択を示す。証明書は空でない consume/cases/葉を Entails に接続し、壊れた参照・葉・sort・等号を拒否する。正例は結論を仮定しない。

## 補助契約の決定の記録

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| 受信の結果型 | 宣言の逐次 instantiate の成功から選ぶ。同じ値を Step と step で検査する | 結果型を外部 oracle に指定させる案はゲストへの信頼を増やす |
| import | Outcome.Typed を検査の側へ移し、ExternalResponse が検査を読む | 外部三欄と検査の相互 import は成立しない |
| carrier | Outcome.Carrier を応答に使い、Ty.carrier は sort の不変の補題で使う | 元の P の下の HasTypeV v a.carrier は名目の欄に残る篩を消せない |
| 葉の段階 | 有限の検査と閉じた代表を今置き、全 sort と実δの一致を L30/L50 に明示して残す | Entails を葉の未検査の入力にする案、新しい axiom は採らない |

## 実装で確定した補助の完全署名

`EqProof.check` は構文の等号を証明する四規則である。異なる構文の一般の意味上の等号を既に扱うとはしない。`EqProof.checkSorted Γ s t u c` は両項の HasSort を検査し、`checkSorted_sound` はその二つと `t = u` を返す。`Certificate.checkSorted Γ Φ goal c` は goal と全仮定の `Sorted Γ none` を検査してから再生し、`checkSorted_sound` は両方の適格性と Entails を返す。型の文脈がなくても再生の論理自体が健全であることは `Certificate.sound` と分けた。sort 不適格の仮定を hyp で通すものを、受け入れの入口にしない。

`Observation.measure_nonnegative : Observation.measure m o = some (.integer n) → 0 ≤ n` は全7 measureの正常結果について証明した。個数はNatから数学上のIntへ写し、機械のIntegerへ無条件に収まるとはしない。`Const.NumericRepresented` は符号付き8/16/32、符号なし16/32/64、Byte、Decimalの範囲を明記し、`ConstOK.represented : ConstOK B c → c.NumericRepresented` を置いた。Integer64Valueは既存の型そのものが範囲を持ち、Float32/64はbitsの型で保持する。

`HasTypeVQ.represented` は `a.carrier.HasSort s` を受け取り、`Ty.sort_carrier` を実際に使って元の型付き値の閉じた観測を返す。受信の接続はTy.carrierとこのrepresentedを使わない。representedはL30での利用に備えた補題であり、そこで使わなければ削除する。根がsortを持つ型付き値ではtoTerm?がsomeになる。sortを持たない関数の根のtermBindが整数0になるという全域関数の定義自体は保ち、slotBindではnoneを保持する。受信検査は元のtoTerm?のnoneを拒否し、この根の既定値を成功として使わない。

`ExternalCarrier.adequate`・Each/Fields は値構造の8/2/2場合から任意のσで適格性を返す。`Builtins.ExternalAssumptions.external_adequate` は三欄のうちtypedのcarrierからそれを取り出す。Validと入力の適格性を仮定しなくても導ける強い補題なので、予約した言明にも使える。第四の信頼条件を追加していない。`externalReceive_of_args` は ExternalArgs.instantiate から結果型の選択を接続し、`Builtins.ExternalAssumptions.receive` は受信の存在・型付け・no-exit・obs=[]を返す。`Step.external_accept/reject` は同じ具体化の結果をE_External/E_ExternalErrへ供給する。

## L30へ固定する全規則の義務

以下は未証明の本番宣言を置く表ではなく、後続の実装とレビューで満たす署名の条件である。新しい公理やCoreAssumptionsの欄にはしない。

| 送り先と対象 | 固定する前提と結論 |
|---|---|
| L30・traceなしの否定標準形 | 入力Φとgoalから検査器が `Φ ∧ not goal` を作り、極性を持つ有限構文の正規化を再計算する。各環境で元の式と正規化結果の解釈の一致を証明し、その反証検査成功からEntails Φ goalへ接続する。外部normalizationTraceを前提にしない |
| L30・線形のderive/combine/round/split/close | 現在の枝の末尾までの参照だけをlookupし、係数和の一致・非負乗数・正の除数・床除算・整数二分の被覆・定数の矛盾を検査する。consume/cases/discardと合成したsoundを証明する。兄弟・未来・循環・範囲外を使った証明書を拒否する |
| L30・EqProof/substitute | 今回の構文の等号を含め、有限な型付きの別名・不変欄・measureの合同性を登録する。宣言・型引数・欄番号・受け手の名目型と全sortを検査する。一般の未解釈関数や任意のPropを登録しない。検査成功から置換前後の論理の解釈の一致を証明し、Entailsの構文の導出へ接続する。現在の構文等号だけを一般の別名合同の完成と数えない |
| L30・捨てる規則 | 残る論理項又は枝内の事実を捨てても、検査成功から得る元の含意を保つ。先頭の仮定を捨てる今回の規則を、残る論理項の列へ一般化する |
| L30・builtinLemmaの有限表 | keyを有限の識別子で照合し、項のsort・宣言・arity・型/行/値の引数を検査する。各項目のsoundをPreparedLeafへ構成する。未知key、sort違い、宣言の不一致を拒否する |
| L30/L50・machine_exact | 各組込みの宣言をlookupし、許容する型/行/範囲引数、型付きの閉じた値引数を全称量化する。正常な実δの結果について、toTerm?の成功、論理のmeasure/比較と同じ結果、必要な閉じた条件のClosedObservableを示す。計算失敗・桁あふれを成功へ写さない。今回のPreparedLeaf.machine_exactは閉じた評価とinterpretの一致であり、実δとの一致の代用ではない |
| L30/L50・stable | 型付きの不変の値・欄・snapshotの観測を、局所の値置換と捕捉の具体化後にも同じ観測として使えることを示す。宣言の欄のWF、名目型、別名の合同を保持する。今回のPreparedLeaf.stableは既に閉じた述語の置換不変であり、開いた欄の一般化は残る |
| L30/L50・represented | 各幅のConstOKとInteger64Value・Decimal・Byteから入力と正常結果の表現可能性を示す。数学上の長さの非負と機械の幅へ収まることを区別する。Map/Setの鍵についてsatだけから観測可能と仮定せず、実際の表と型付き値から正準コードの成功を示す |

builtinの項目はStringのbyte/character長、List/Bytes長、Map/Setの重複縮約後の大きさ、characterCode、不変欄と欄の連鎖、整数各幅、Decimalの表現可能性と比較、Float32/64のbitsの分類と比較、Scopeのsnapshot所属である。Mapは元の鍵と後の値を保ち、Decimalの数の等値・別名の合同と既存δの鍵の等値を一致させる。全型/行/値の量化を消して「trueなら導ける」だけの契約にはしない。モデルの充足はL50、外部の三モデルはL60、呼出し全体と旧埋め込みはL20/L70、実装の受信とownの解放はR50/L70の担当を保つ。

## 群末レビューの対応と残りの義務

2026-10-31。軽4への対応として、既存の外部三条件を前提とする次の二補題をExternalConnectionへ追加する。自由変数は全称量化する。受信前の応答がvalであることや到達先の型付けを前提にせず、受信の結果を反転する。

```text
Builtins.ExternalAssumptions.received_value :
  Builtins.ExternalAssumptions P B → P.ExternalWF → P.externalFunction f = some d →
  ExternalArgs P B Ψ d ts vs a e → B.externalResponse f ts vs out obs →
  externalReceive P d ts vs out = some (.val v) → ∀ σ,
  HasTypeV P B Ψ [] [] [] v a ∧ v.Ground ∧ v.Adequate σ
Builtins.ExternalAssumptions.receive_no_exit :
  Builtins.ExternalAssumptions P B → P.ExternalWF → P.externalFunction f = some d →
  ExternalArgs P B Ψ d ts vs a e → B.externalResponse f ts vs out obs →
  externalReceive P d ts vs out ≠ some (.exit n)
```

| 所見・送り先 | 残る義務 |
|---|---|
| 軽2・L30 | EqProof.checkSortedは現在Certificate.checkから呼ばれない。checkSortedは結論と全仮定だけを検査し、substituteの項や途中の述語のsortを検査しない。意味上の等号へ広げる際は、substituteにsortを持たせ、検査へ文脈を渡し、途中の述語と等号の両項を検査する。現在の構文等号の健全性と、この未接続を区別する |
| 軽3・L30/R20 | DecidableEq Term/PredはClassical.propDecidableであり、Certificate.checkとEqProof.checkの等号の比較はLeanの中で計算できない。今回の境界はsimpで等号を証明する。R20のRust検査器との差分試験にLeanの実行を使うかを先に決め、使うなら構成的な等号をL30/R20で用意する。仕様として読む場合は実行しない範囲を明記する。今回、差分試験の方式を決めたとはしない |
| 軽5・L20 | argumentsEnv_observationはvar 0の根の一段だけを示す。Telの具体化で、Sortedな述語と型付きの実引数から、観測する項のtermBind?が成功しgetDの既定値へ落ちないことを一般の補題として示す。sortを持たない値を含むsnapshotのslotのnone保持は分ける |
| 軽6・L30 | lengthNonnegativeはclosedTrueを要求する閉じた代表であり、closedより導出範囲を増やさない。Observation.measure_nonnegativeを使う0 ≤ length(x)の開いた葉を置き、PreparedLeafの検査とstableの言明を開いた葉に合わせて改める。閉じた述語の置換不変を開いた述語へそのまま広げない |
| 軽4・L20/L30 | 受信の接続はTy.carrierを使わない。Ty.sort_carrier/HasTypeVQ.represented、Observation.measure_nonnegative、ConstOK.represented、PreparedLeaf.machine_exact/stableはL30で利用箇所を確認し、使わなければ削除する。external_adequateは今回received_valueから使用する。定義しただけの補題を受信での使用済みと説明しない |
