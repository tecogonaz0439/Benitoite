# RV-L20-plan: L20 の詳細計画の下書きの独立レビュー

2026-11-01。対象は `l20/detail.md`・`l20/results.md`（未コミット、基準 841fe6ea）。`formal/` と `plan.md` は変更していない。git の操作はしていない。Lean の補助入力は一時領域に置き、再現に要る全文を本書の末尾へ写した。パスは改造のディレクトリからの相対で書き、`R/` は `formal/Benitoite/Release/Refinement/`、`O/` は `formal/Benitoite/Release/` を指す。

## 総合判定

**不可**（重3・中10・軽6、計19件）。

計画の骨格（群の順序、76遷移の分担、義務の集合、46規則の網羅、算術）は正しい。不可の理由は、最初の群 A の土台になる署名に確定した誤りがあることである。S01 は Lean の反例で偽であり（重1）、S01 の閉じた形は帰納の仮定になれない（重2）。S02 の結論は `ClosureTy` が要求する `Qempty` へ届かない（重3）。S01 の修正は `C_ResumeL` 系の規則又は `StoreOk` の定義に触れる見込みがあり、本書の「既存定義の実質的な変更は sig_scoped だけ」が崩れる。全面の書き直しは要らない。重と中1〜中3の修正の後、該当箇所に絞った再確認でよい。

## 所見の分類

| 種類 | 所見 |
|---|---|
| Lean で確定した誤り | 重1 |
| 読めば確定する誤り | 重2、重3、中1、中3、中4、中5、中6、中7、中8、中10、軽1〜軽4 |
| 実行しないと分からない推測 | 中9、軽5、重1の到達可能性、重2の修正案の成立 |
| 判断の問題 | 中2（通過条件の定義） |

## 重

### 重1: S01 `capture_comp_annotation` は偽である（Lean で確定）

- 箇所: `l20/detail.md`「S01: 捕捉の結果の形成」、群 A の表の .01、L20.01、L20.24。
- 問題: `StoreOk` は場所の型の `Sorted` を保持しない。`LocTy.WF`（`R/StoreTransport.lean`）は WF だけ、`StoreTy.Declared` は Declared だけを持つ。`CellOk` の `.used` の枝（`R/StateTyping.lean`）は `∃ b t e r, Ψ l = some (.cont b t e r)` だけである。一方 `C_ResumeL`・`C_ResumeLNorm`（`R/Typing.lean`）の結果の型の前提は `Ty.Declared` だけである。よって、使用済みの継続の場所に不適格な sort の結果型を持たせると、S01 の前提の StoreOk・CaptureOk・型付けがすべて成り立ち、結論の Annotation が偽になる。
- 再現: 末尾の入力 `rv1.lean`。`S01_comp_false` は任意の `P B σ` について、`Ψ0 0 = .cont .bytes badT Eff.empty none`、`μ0 0 = .used`、計算 `.resume (.loc 0) (.bytesV [])` で、`StoreOk`・`CaptureOk.empty`・`HasTypeCQ … badT …` と `¬ Ty.Annotation P [] [] (Capture.empty.closeTy badT)` を同時に証明する。`badT` は `.refined (.base .integer) (.eq (.boolean true) (.boolean true))` である。終了0、公理は propext・Classical.choice・Quot.sound。`P.WellFormed`・`P.WellTyped B`・`B.CoreAssumptions P` は結論に関わらないので、これらを満たす `P B` が一つでもあれば S01 は偽である。
- 限定: `.resume (.loc l)` は実行では `Closure.view` が作る形で、ソースのコードには現れない。実際の実行で上の状態へ到達するかは確かめていない。`ContTy` の `K_Empty` が `Annotation` を持つので `.cont` のセルからは結果の形成を得られるが、`E_Resume` が `.used` へ書き換えるとその証拠が消える。これは不変条件の欠けであり、到達不能の議論だけでは言明を救えない。`StateTyE` の `E_Let` の葉は `K_Let` の `Ty.Annotation` を要るので、同じ欠けが葉へ及ぶ見込みである（未検証）。
- 修正案: 次のどれかを取りまとめが選び、plan の停止条件に沿って設計者へ示す。(1) `C_ResumeL`・`C_ResumeLNorm` の前提を `Ty.Annotation` へ強める。構成子2個で、四本の移送の8枝と G10 の旧 `C_ResumeL` の枝が変わる。(2) `LocTy.Sorted` を定義し `StoreOk` へ足す。場所の生成の4種と `StoreOk.empty` が追随する。(3) S01 の前提へ「コードに `.resume (.loc _)` がない」を足す。新しい状態の不変条件が要る。詳細の「StoreOk にない強い条件を足さない」と「sig_scoped だけ」も同じ変更で直す。どの案でも J20-1 の境界に当たるので、群 A の起動前に決める。

### 重2: S01 の閉じた形は帰納の仮定になれず、関門 .01 の motive が存在しない

- 箇所: 「S01」、群 A の表の .01、L20.24「.01のmotiveで全結果のWF/Sorted/Declaredを供給する」。
- 問題: S01 は `CaptureOk P B Ψ R Γ Φ cap` を前提に取る。`C_Let` の子 `n` の文脈 `Γ.extend a` には捕捉がない。`m` を評価していないので、型 `a` の値を持たないからである。`C_BuilderLet` の `Γ.extendNone` も同じである。`C_If` の子の `boolCond t true :: Φ` は、偽の側の枝で `CaptureOk` の `Entails [] …` の欄を満たせない。したがって S01 を直接の motive にできない。`C_Let` は結果の `b` について `Ty.Declared` だけを持つので、WF と Sorted は子の `b.shiftV 1 0` から戻す必要がある。詳細はこの経路を書いていない。
- 再現: 読めば確定する（`R/Typing.lean` の `C_Let`・`C_BuilderLet`・`C_If`、`CaptureOk.mk`）。
- 修正案: 開いた形の motive を完全署名として固定する。形は `Ctx` の条件（`Ty.CaptureWF`・`CaptureSorted`・`CaptureDeclared` の三条件。ここで `Γ.extend a` は IH の `Annotation a` から延長する）と場所の条件から `Ty.Annotation P [] Γ a` を結論し、S01 はその系として `hc.substOk.annotation` で閉じる。腕の結果は末尾の `nil` の Annotation、`C_Handle` の結果は `m` から得るので、節と腕の本体へ下りる必要はない。`shiftV` の逆の WF・Sorted・Declared の補題が必要である。現行には `Ty.unshift_shift` があるが、Sorted の逆の補題は確認できなかった。この補題を .01 の完了条件に入れる。開いた形の全証明の成立は未確認である。

### 重3: S02 の結論の Q が元の Q のままで、`Qempty` の `ClosureTy` へ接続できない

- 箇所: 「S02」の `type_subst_comp`、`ClosedTypeSubstInput`、`results.md` の `closedTypeSubstGoal`、L20.34。
- 問題: 関数の本体の判断は `TelBodyTy P B StoreTy.empty (QTel d.tel) …`（`R/ProgramTyping.lean`）であり、`Q` は空でない。到達先の `ClosureTy.mk` と `DependentClosureTy.mk` は `Qempty` を要求する。S02 は `HasTypeCQ P B Ψ Q … → HasTypeCQ P B Ψ Q …` と同じ Q を保つ。S04 の `q_mono` は `Q → Q'` の向きなので `Qempty` へ戻せない。旧 `O/Lemmas/TySubstMain.lean` の `HasTypeCQ.substTy` は別の `Q'` と `RowTransport Q Q' es'` を取る。入力の説明の「元 Q で消す行変数の NoFail」はこの条件に当たるが、結論が Q のままなので使えない。`Admissible`・`PrimitiveAdmissible`・`MethodRowsAdmissible` の移送も同じ形を要る。
- 再現: 読めば確定する。
- 修正案: 14成分の全署名を `{Q'}`、`RowTransport Q Q' es`、結論 `Q'` へ改める。S02 の入力は `Q'` を含む形にする。閉じた `es` と `Q' = Qempty` で E_Fun/E_Meth/E_Op へ渡す例を L20.02 の完了条件に入れる。

## 中

### 中1: S02 の行像の条件が `typeEnvAt` と合わない

- 箇所: 「S02」`ClosedTypeSubstInput`「各行像の `WF 0 C1.length 0`」。
- 問題: `typeEnvAt c ts es`（`R/Subst.lean`）は行像を `shiftRowsTypes c 0` で移す。`Eff.substAt_wf`（`R/TypeBounds.lean`）は像の型深さ `n` から結果の `n+c` を結論する。`WF 0 C1.length 0` の像を入れると結果は `C1.length` の倍の深さになり、目的の深さへ戻らない。旧の `hes' : ∀ e ∈ es', Eff.WF 0 0 e` も閉じた像である。
- 修正案: 行像を `WF 0 0 0` に改める。C1 に依存する行の像が要るなら、その実例と `typeEnvAt` の定義の扱いを示す。

### 中2: 群 A の通過条件が成否を判定できない

- 箇所: 「最初の群 A と方式の確認」、L20.01〜.04。依頼文の項5。
- 問題: 表の「通過条件」は「供給できるか」「方法を固定」であり、何が残れば通過かを定めていない。L20.01 の完了条件も「独立仮定なしの構造又は停止票」である。重1は、Lean で S01 の言明を反例に当てるだけで見つかった。S01 の全証明は L20.24、つまり G03 の16単位の後なので、関門が閉じるのは全型置換の後になる。各30〜60分の4単位では、(a) の 29+24 場合の供給元の確認も、(d) の22規則と33場合の motive の固定も上端である。依頼文の a〜d を項目としては満たすが、結果として方式の成否を判定できない。
- 修正案: 各関門の成果物を次に固定する。(a) 開いた motive の完全署名、V29・CQ24 の全規則の結果の Annotation の供給元の表、最も弱い5規則（`C_Let`・`C_BuilderLet`・`C_ResumeL`・`V_LocRef`・`V_Checked`）の Lean の証明又は反例。(b) 重3を反映した署名と、`E_Fun`・`E_OpFail` の実際の入力で前提を満たす Lean の証明。(c) 次の条件で判定する。`HasTypeVQ.notContCore`（`R/ClosureTyping.lean`）により、閉じた値は継続の core の型を持たない。これから「閉じた `.list k0` の値は空である」と「`[y]` の照合は成功しない」を Lean で証明する。本書はこの既存の補題を挙げていない。(d) 値の大きさと導出の辞書式の motive の完全署名と、`.data`・`.trans`・`.refine` の三枝の証明。`.data` の欄の移送は `variance_field_mono` が返す新しい導出であり、部分導出ではないので、外側の帰納は値の大きさになる。止まる条件は「この成果物の Lean が閉じない」とする。見込みは 2〜4 時間で足りない可能性があるので、最初の1時間の後に見直す。

### 中3: 全文脈変更の27位置に漏れがある

- 箇所: 「子の文脈又は依存列が変わる位置」。本書は第二の数え方を「Γ/Φ/C/R/Ψ/L 又は依存列を変更して入る位置」と定める。
- 問題: 次が表にない。`V_CheckedAt` → `CheckedWitness`（`V_Closure` と同じく Q/C/Γ/Φ を落とす）。`C_External` → `HasTypeTelArgsQ`（`Tel.bind (typeEnv ts) d.parameters`）。`C_Meth` の `HasTypeVsQ ws as`（`Tel.arguments` で具体化した依存列）。14判断の外の `GuardBodyTy.mk`（`ClosureTy.mk` と同格で、`p.open true :: Φ`・CaptureOk・局所参照を持つ）。逆に、`HasTypeArmsQ.guarded` の後続は Φ が変わらないのに数えており、`HasTypeClausesQ.cons` の後続と扱いが違う。`ImageOk.contVar` は子の判断を持たない。
- 修正案: 表へ4行を足し、後続と contVar の扱いをそろえて合計を数え直す。`C_Meth`・`C_External` の型置換は L20.18 の手順にも名指しする。

### 中4: G 表の行の中身が単位から落ちている

- 箇所: 「G01〜G10との会計の対応」と `l00b.15/theorems.md` の G 表、`l10/f/transfer.md` の G 行。
- 問題: 次の語は `detail.md` に一度も現れない。G08 の InitialPrepared/Ready・固定σ・ExternalWF、`admits_sat` の使用先（G05 の E_OpPrim の接続）。G04 の `normConts`・`builderBody_image_norm`・`CaptureOk.normConts`。G05 の「範囲外変数を行に持つ Handle→Op」と `io_op` の全保存への接続。G07 の NamesWF/一意性、`termBind?` の成功/`getD` 非到達。G06 の `RootShape`。G08 は .05・.06 の宣言だけに縮んでいるが、transfer の G08 は「宣言・準備・外部・解放の入力」である。
- 修正案: 各語を受け持つ単位を名指しする。後段へ移すなら理由を書く。L20.63 や .65 の内数とする場合は完了条件へ書く。

### 中5: 単位の見込みが枠からの逆算である

- 箇所: 「起動単位と群の完了条件」「G01〜G10との会計の対応」。
- 問題: 全 G 行で単位数が下端の時間のちょうど2倍である（G01 2時間→4単位、G03 8→16、G10 13→26 など10行すべて）。上端も120分の単位の個数で各行の枠に合わせてある（機械照合で全一致）。本書は「枠への配分が方式の不確かさを解消した意味ではない」と書くが、単位の難しさから積み上げた見込みではない。とくに次は難度に合わない。全14判断76枝の型置換が群 D の5単位 2.5〜6 時間。旧 `TySubstMain` と新 `SubstTyping.lean`（1720行）の規模を見ると、V29 を2単位に分ける L20.16・.17 は 30〜60 分に収まりにくい。L20.67 は独立評価（`I/Eval.lean` の `EvalPartial` など）と Release の意味の関係の定義を 30〜60 分に置く。
- 修正案: 配分の根拠を「枠の割り振り」と明記し、区別できない単位の見込みを個別の積上げと呼ばない。群 D・L20.67 は枠の内で幅を移すか、不確かな単位として上端を上げ、他の単位から差し引いた根拠を書く。算術そのものに誤りはない（94単位 47〜109時間、群19行、G10行の四区分すべて一致）。

### 中6: 移管控除の G 行への配賦が行の範囲と合わない

- 箇所: 「L00b へ移した5〜9時間の照合」。
- 問題: 合計5〜9と四行の元の値は `l00b.02/signatures.md` 第12.2節と一致する。しかし `.02b-at` の移動の内容は「保持値の sort/WF と Request を含む相互置換」であり、G04（捕捉からの正則性・hide・局所構築器・Regular）の範囲にない。本書はこれを G04 から1〜2時間引く。transfer は「捕捉の全正則性と入れ子の継続は G03/G04 の未確認の仕事であり、解決済みと扱って減額しない」「根拠なく各行へ割り振って短縮した表は作らない」と定める。`.02b-closures` の「捕捉環境/依存βの構文の可換性」も G02 の範囲に近いが G01 から引いている。
- 修正案: G04 の控除を0にし、`.02b-at` の分は G01 又は G03 の保持値の枝へ移す。合計の 5〜9 は変えない。関門の行の下端を下げない。

### 中7: 本番追随の17件が plan の「同種の10〜20件」に当たらない

- 箇所: 「本番追随の最初の17件と残りの移植」。
- 問題: 17件は q_mono 9・local_zero 4・withReturn 4 の三種類で、どの種類も10件に届かない。q_mono の9件は一つの相互帰納の入口である。`local_zero` は旧に対応する補題がなく、「旧の補題から新判断へ移す」作業ではない。三種類とも N=0 なので、plan の `N_g×c_g` の更新は最初から0であり、見込みの更新に使えない。
- 修正案: 残件のある種類を受け持ちにする。候補は G10 の値19規則（.75〜.80、残り27規則）である。依存順で後になるなら、その理由と、それまで見込みを更新しないことを書く。q_mono 等は通常の作業として数える。

### 中8: 義務の完了判定の一部が言明として検査できない

- 箇所: 「plan のL20担当28行」。
- 問題: 集合は一致する（28行・37行・分類・重複7・合計58を機械照合）。判定が検査できない行がある。O136「移送を閉じる」、O140、O143「長さの関係を…保持する」は定理名がない。O143 の「元list/保持element/長さ」の関係を確かめる例もない。O167 は「受理と拒否の対照」を要るが、.03/.07/.23/.24/.40/.48 のどの単位にも拒否例の作成がない。O003 の「閉鎖表」の成果物の単位がなく、`subst_congr` を証明する単位もない（.25 は「一致条件を渡す」だけで、「残る移植」は使用先の内数とする）。O046・O138 の単位に .64 がないが、`E_IfT`/`E_IfF` の任意の捕捉の葉は .64 が受け持つ。
- 修正案: 各行へ S 番号か定理名を一つ以上書く。O143・O136 は代表の命題を一つ定理として置く。O167 は単位へ拒否例を足す。O003 は .25 の成果物とし `subst_congr` の単位を明記する。O046・O138 へ .64 を足す。

### 中9: 効果の Annotation の供給元が足りない見込み（未検証）

- 箇所: 「S01」の末尾「必要な効果の Annotation は ClosureTy/DependentClosureTy/K_Handle の既存の証拠から移す」。群 A の表の .01。
- 問題: `C_Handle` の本体の効果 `εm` と `C_Handle_Fail` の `eb` は外側の結果の効果に現れない。E_Handle の行先の `ClosureTy` は `(.dependentFn (.done a (closeEff εm)))` の Annotation を要る。本体が `.resume (.var k) v` なら `εm` は捕捉した継続の潜在効果であり、`CaptureWF` が読まない部分である。`contLoc` は閉じた像の WF を持つが Sorted を持たない。`C_Eff` で `Eff.union ε (handled P B h)` へ広げる経路はあるが、`handled` の形成の供給元が要る。
- 再現: Lean では確かめていない。読んだ範囲で供給元を特定できなかった。
- 修正案: 関門 .01 の表に効果の行を足す。結果の型だけでなく、状態の葉が要る効果の Annotation の全箇所（E_Handle、E_Let、E_Lam）の供給元を列挙する。

### 中10: 分岐する判断の列挙に欠けがある

- 箇所: 「分岐する判断と五つの境界」「骨格を固定する順序」。
- 問題: 関門 (d)（G09）が失敗した場合の J がない。「意味を主定理の仮定にしない」は本文にあるが、J20 の表は捕捉・型像・入れ子・failed・G10 の五つである。網羅性の健全性がこれに懸かるので独立の項目が要る。重1の処置は規則又は `StoreOk` の変更であり、J20-1 の「結果形成を主定理の独立入力にする」の範囲を超えて型付け規則の定義に触れる。S03 の像の形成の追加も J20-2 の対象外である。
- 修正案: J20-6（G09）を足し、J20-1 に「型付けの規則・StoreOk の定義の変更」を明記し、波及の場合の数を骨格の表へ足す。

## 軽

### 軽1: 実在しない名前

`Transport.conditions_cons` はない。実名は `Entails.conditions_cons`（`R/Typing.lean`）である。`Frame/Cont/Cell.localRefs` は旧の `Frame.LocalRefs` 等で、新にはまだない（.61 の新定義になる）。`step_prim` は `step_prim_val/err` である。ほかに照合した約190の名前は、名前空間の省略を除き実在した。

### 軽2: q_mono の成分数

`AtCallAdmissible` は Q を引数に持ち `C_CheckAt` から入るので、9成分では閉じない。相互帰納の recursor は14成分すべてを要る。閉じた成分の扱いを書く。

### 軽3: 全 L の義務

O016・O084 は「共通」として数えるが、担当が同じ「全L」の O027（RSS の区分）と O118（コメントに作業 ID を残さない）が表にない。RSS の行は検査の表にあるので、番号を足す。

### 軽4: 「完全署名」の節に形だけの項目がある

S09・S10・S11 は定義の形の説明で、S03・S06 は「候補」「.02/.30 で固定」と書く。依頼文の項7は完全署名を先に固定する。未固定の項目と固定した項目を見出しで分ける。

### 軽5: 依存の過剰（推測）

L20.83→.34、L20.86→.52/.53 は葉の定理への依存に見える。G10 の埋め込みは型付けの導出を作るだけなので、状態の葉を読まない可能性がある。不要なら外すと群 O〜S を別機で早く始められる。循環はない（全単位の依存を機械照合し、前方参照0）。

### 軽6: results の記述

`results.md` の「三つの Goal は Prop の定義」は正しいが、`closedTypeSubstGoal` は重3の誤りをそのまま型検査している。型検査の成功が署名の妥当性の証拠にならないことを追記する。

## 確かめて問題がなかった点

| 観点 | 確認 |
|---|---|
| 76構成子 | `R/Typing.lean` から 29+2+2+24+2+2+1+1+2+1+3+2+1+4=76 を確認。部分型22規則の数え方も矛盾なし |
| 76遷移 | `R/Semantics.lean` の `E_` 76件と本書の表の集合が過不足なく一致、重複0 |
| ContTy/Frame/Cell/State | 10/7/6/4 を定義で確認。Comp 16形、Ty 21形も一致 |
| 義務 | plan の担当 L20 は28行で集合一致。L10F の37行と分類 A12/B16/C6/D1/E2 も一致。58の算術も一致 |
| 依存 | 94単位に前方参照なし。相互の族の帰納を二度組む単位は見つからなかった |
| 見込みの算術 | 94単位 47〜109時間、15単位の上端、群19行、G 全10行、G10 の四区分が全一致。L10 の 371 分・117 分も台帳と矛盾なし |
| G10 | 旧 V19・CQ17 の規則名を単位 .75〜.86 へ過不足なく対応。Vs/Each4・腕3・節2・失敗1 で46。`∀ Φ`、`weaken_conditions` を使わない経路、条件付き Exhaustive、三親判断、embedStep の撤回は handoff と一致 |
| S07 | `l10/x/signatures.md` と字面が一致 |
| S03 の Inhabits の反映 | `Inhabits` の `tvar`/`tapp` が全値を許すので、`Inhabits.of_substAt` の方向に型変数の反例はない。`rawApply` を通す P_Con は像の kind が要る可能性があり、本書の留保のとおり未確定 |
| S04 | `LocalCtx.Shift.extend/localExtend`、`CaptureOk.hideConts_any` は実在し、署名は記述に合う |
| `store_extend` | 全般の補題である。ただし `Builtins.ValueAssumptions` を要る。L20 の葉は CoreAssumptions から供給できる |
| L30 との並行 | 共有箇所の列挙に漏れを見つけなかった。重1の処置で `StoreOk` 又は `Typing` を変えるなら、その取込みを L30 の開始より先にする |
| 規約 | 手元の絶対パス、docs/todo へのリンク、`work/` の出どころの参照、「費用」の語はなし |

## 再現の入力

`formal/` で `lake env lean -M 12288 rv1.lean` を実行した。終了0、未使用の simp 引数の警告だけである。公理は `[propext, Classical.choice, Quot.sound]`。SHA-256 は `5a02d1dcb48730f12ba204e0f44c6fc30dc074866563aa24329f066b3aa29837`（2956バイト）。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RVL20
noncomputable section

/-- 整形式で宣言済みだが sort が不適格な篩（boolean の項を .eq の integer で読む）。 -/
def bad : Pred := .eq (.boolean true) (.boolean true)
def badT : Ty := .refined (.base .integer) bad

def Ψ0 : StoreTy := fun l => if l = 0 then some (.cont .bytes badT Eff.empty none) else none
def μ0 : Store := fun l => if l = 0 then some .used else none

theorem badT_wf : badT.WF 0 0 0 := by
  simp [badT, bad, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]

theorem badT_declared (P : Program) (C : List Benitoite.Release.TParam) (Γ : Ctx) : badT.Declared P C Γ := by
  simp [badT, bad, Ty.Declared, Pred.Declared, Term.Declared]

theorem badT_unsorted (Γ : Ctx) : ¬ badT.Sorted Γ := by
  simp [badT, bad, Ty.Sorted, Pred.Sorted, Term.HasSort, Term.Shape]

theorem close_badT : Capture.empty.closeTy badT = badT := rfl

theorem store0 (P : Program) (B : Builtins) (σ : PathEnv) : StoreOk P B σ Ψ0 μ0 := by
  refine ⟨⟨1, ?_⟩, ?_, ?_, ?_, ?_⟩
  · intro l hl; have : l ≠ 0 := by omega
    simp [μ0, this]
  · intro l t ht
    by_cases h : l = 0
    · subst h; simp [Ψ0] at ht; subst ht
      refine ⟨?_, badT_wf, ?_, ?_, ?_⟩
      · simp [Ty.WF]
      · simp [Eff.WF, Eff.empty, Ty.WFList]
      · simp [Eff.Canonical, Eff.empty, Eff.norm, Eff.atoms, rowFails]
      · simp
    · simp [Ψ0, h] at ht
  · intro l x hx
    by_cases h : l = 0
    · subst h; simp [Ψ0] at hx; subst hx
      refine ⟨?_, badT_declared P [] [], ?_, ?_⟩
      · simp [Ty.Declared]
      · simp [declaredEff, Eff.empty, declaredTys]
      · simp
    · simp [Ψ0, h] at hx
  · intro l x hx
    by_cases h : l = 0
    · subst h; simp [μ0]
    · simp [Ψ0, h] at hx
  · intro l c hc
    by_cases h : l = 0
    · subst h; simp [μ0] at hc; subst hc
      exact ⟨_, _, _, _, rfl⟩
    · simp [μ0, h] at hc

def code0 : Comp := .resume (.loc 0) (.bytesV [])

theorem code0_typed (P : Program) (B : Builtins) :
    HasTypeCQ P B Ψ0 Benitoite.Release.Qempty [] [] [] none code0 badT Eff.empty [] :=
  .C_ResumeL (l := 0) (b := .bytes) rfl (.V_Bytes (by simp)) (badT_declared P [] [])

/-- S01 の capture_comp_annotation の前提のうち StoreOk/CaptureOk/型付けは満たすが結論は偽。
三つのプログラムの前提は P・B を量化したまま残す（結論に使っていない）。 -/
theorem S01_comp_false (P : Program) (B : Builtins) (σ : PathEnv) :
    StoreOk P B σ Ψ0 μ0 ∧ CaptureOk P B Ψ0 none [] [] Capture.empty ∧
    HasTypeCQ P B Ψ0 Benitoite.Release.Qempty [] [] [] none code0 badT Eff.empty [] ∧
    ¬ Ty.Annotation P [] [] (Capture.empty.closeTy badT) := by
  refine ⟨store0 P B σ, CaptureOk.empty P B Ψ0 none, code0_typed P B, ?_⟩
  intro h
  rw [close_badT] at h
  exact badT_unsorted [] h.sorted

end
end RVL20
#print axioms RVL20.S01_comp_false
```

## r1 の再レビュー

2026-11-02。対象は `l20/detail.md`（r1、1,052行）・`l20/results.md` の修正箇所である。全文の再レビューではなく、依頼の観点の照合と抜き取りを行った。`formal/` は変更していない。git の操作はしていない。

### 総合判定

**不可**（新しい所見は重1・中3・軽4、計8件）。前回の所見のうち重2・重3・中1・中3・中4・中6〜中10・軽1〜軽6 は処置を確認した。重1の S00 も妥当である。不可の理由は、S02 の入力と E_OpFail の別入口の方針に新しい確定した誤りがあることである（r1 重1）。kind の問題は E_OpFail に限らず E_Fun にも及び、定義の変更の判断が要る。群 A3 までは起動できるが、群 D の前に決める必要がある。修正後は S02 の kind の入力に絞った再確認でよい。

### r1 の重

#### r1 重1: `TypeArgsKinded` の kind 文脈は出現ごとの存在量化なので、S02 は高カインドの像で偽である（Lean で確定）

- 箇所: 「S02」`ClosedTypeSubstInput`、「E_OpFail の kind に関する確定した不適合」、L20.09、J20-2。
- 問題: `TypeArgsKinded P C ts ks`（`R/KindValues.lean`）の kind 文脈 K は `∃ K, K.length = C.length` であり、出現ごとに選べる。宣言の kind へ縛られない。`Def.KindWF`（`R/KindInference.lean`）は署名だけを読み、`Program.WellFormed`・`Def.WellTyped` のどちらも本体の型引数の kind を宣言と照合しない。したがって本体の `.op o [.tvar 0]` は、tvar 0 の宣言の kind によらず `K := [.value]` で通る（`tvar_value_kinded`）。一方、像 `.op o [.ctor c]` はどの文脈でも型付かない（`op_ctor_untyped`）。`S02_V_conclusion_false` は `Val.substTyAt 0 [.ctor c] [] (.op o [.tvar 0])` の型付けを任意の P・B・Ψ・Q・Γ・Φ について否定する。入力の欄の内容に関わらず、S02_V の結論がこの像で偽になる。
- 帰結:
  - r1 が計画した「`[T]` の WF/Ordinary だけを使う Fail 用の別入口」は成立しない。失敗節の本体は `({}::C)` の下で `.op o [.tvar 0]` を含められるので、T=`.ctor .list` の E_OpFail の行先のコードが型付かない。`V_Fun`・`V_Prim`・`V_ExternalRef`・`C_Meth` の `SignatureInstance.kinds` も同じである。「fresh な T の出現条件」は既存の導出から得られない。
  - 問題は Fail に限らない。E_Fun でも、`d` の tparam が `.constructor 1`、`ts=[.ctor .list]`（`TypeArgsKinded` を満たす）で本体が `.op o [.tvar 0]` なら同じである。「kind を保つ入口」も同じ穴を持つ。
  - `V_Raise` に value kind を足すだけでは E_Fun の場合を閉じない。
- 限定: 源の型付けは V_Op の残りの前提（SatAll、Annotation）を要る。具体の P を構成した完全な状態の反例ではない。`tvar_value_kinded` は kinds の欄が通ることだけを示す。
- 修正案: 次のどれかを取りまとめが選び、設計者へ示す。(1) 本体の kind 検査 `Comp.Kinded K`（宣言の kind 文脈を固定して全型引数を読む）を `Def.Scoped`・実装・節の条件へ足し、S02 の入力にする。76 case の新しい族が一つ増える。あわせて `V_Raise` と失敗節の型束縛に value kind を足す。(2) `TypeArgsKinded` の K を判断の引数へ移す。14判断の引数が変わり、四本の304枝に波及する。(3) `SignatureInstance.kinds` の読者を調べ、Ordinary と形成に要る分だけを残して HasKind の照合を外す。tapp の形成（L20.16）の供給元を別に要る。どれも型付け又は前提の中身に触れるので J20-2 の条件付きの判断ではなく、群 D の前に決める項目として「骨格」の表へ載せる。

### r1 の中

#### r1 中1: `S02_Image` は恒等の置換でも偽である（Lean で確定）

- 箇所: 「S02」`S02_Image`、「Q を引数に持つ11成分の結論はすべて Q'」。
- 問題: `ImageOk.contLoc` は `Ψ l = some (.cont b' t' e' R0)` の R0 をそのまま読む。結論の `RR R` は `Ty.substAt` の正規化を通るので、正規形でない R0 では lookup が合わない。`image_source` と `image_target_false` が `ts=es=[]` の場合を示す（`r0 := .refined .bytes .truth`）。文脈が閉じていても起きる。
- 修正案: ImageOk の motive を True とする。`CaptureOk` の成分は元の証拠をそのまま返すので IH が要らない。Q を移す成分は10件、恒等又は True が4件へ改める。`q_mono` は ImageOk も写せるので現状でよい。

#### r1 中2: 関門 (b) の成果物が本体の case を読まない

- 箇所: 「最初の群 A と方式の確認」(b)、L20.09。
- 問題: 関門 (a)(c)(d) は全規則の表と弱い case の Lean で成否を判定できる。止まる条件も判定できる（前回の中2を処置済み）。(b) の成果物は「実呼出しの入力の全欄を供給する Lean」であり、入力が揃うかだけを見る。r1 重1は入力が全部そろっても本体の case で起きるので、この関門を通ってしまう。
- 修正案: (b) に「V_Op・V_Fun・C_Meth の型引数の case を S02_V の形で閉じる Lean」を足す。tvar を含む本体の例を完了条件にする。

#### r1 中3: 見込みの基準と単位の中身が合わない

- 箇所: 「起動単位と群の完了条件」。
- 問題: 算術は合う（128単位、75.5〜151時間、27群、G 10行、固定枠の残分 34〜80、前方参照0を機械照合）。枠に合わせて削っていない点も処置どおりである。しかし単位は 30〜60 分が82件、45〜90 分が46件の二種類だけで、全単位の上端は下端のちょうど2倍である。方式の関門と定型の枝で不確かさの幅が変わらない。本書が述べる基準「2〜5 の case」にも合わない単位がある。L20.47 は q_mono の14成分76 case を 30〜60 分に置く。L20.57 は Sub/Normal/Refine と残りの V/Vs/Each の合成を1単位に置く。S05 の33 case が3単位なのに対し、S02 の V29 は7単位である。closeVal は Lam の構成が新しい接続なので、G01 の積上げ 2.75〜5.5 時間が固定枠の下端4時間を下回る根拠が書かれていない。
- 修正案: 機械的な単位（q_mono）は「定型の相互帰納で case 数を基準にしない」と理由を書く。関門の単位と G01 の幅を個別に広げる。r1 重1の処置の時間は未計上なので、「不明」と明記する。

### r1 の軽

1. **`V_LocRef` の判断**: 「`.used` と同じ欠け」は当たらない可能性が高い。旧 `StoreOk` でも `Ψ l = .ref badT` にはセル `.val v` と `v : badT.norm` が要る。閉じた値の型付けの規則は、結果の Sorted を持つか（`V_Sub`・`V_Refine`・`V_List` など）、より小さい型へ下りる（`V_LocRef` はセルの型へ）ので、不適格な sort の型の値を作る底がない。`.used` は値を要らないので事情が違う。これは読んだ範囲の論証で、Lean では閉じていない（`results.md` も旧 `StoreOk` のμを構成していない）。したがって `V_LocRef` の版は反例ではなく、ストアの型の大きさによる帰納の負担である。それでも案2は妥当である。`.used` の反例を閉じ、この帰納も不要にし、`contLoc` の Sorted も供給する。依頼文の「案1 は少なくとも4構成子」の根拠は「`C_ResumeL` 系の2構成子で足りるが帰納の負担が残る」と読み替える。記録の訂正だけでよい。
2. **系の前提**: `capture_*_annotation`・`close_value_typed` は `StoreOk` を取るが、`K_Handle`・thunk・lambda の本体は `hideBuilders Ψ` の下にあり、builder のセルがあれば `StoreOk … (hideBuilders Ψ) μ` は成り立たない。系の前提を `Ψ.WF`・`Ψ.Sorted`・`StoreTy.Declared` の三つにし、`StoreTy.Sorted.hide` を L20.01 に足す。`StoreOk` は開いた motive の形では要らない。
3. **L20.91 の文言**: 「finite/domain/Declared/WF を保つ」に Sorted がない。
4. **S02 の恒等成分**: `S02_Capture` などの `RowTransport` の引数は使わないので消してよい。

### 前回の所見の処置の確認

| 所見 | 確認 | 結果 |
|---|---|---|
| 重1（S00） | `r` を外す判断は妥当。`K_Empty` の R は任意で、S01 の `t`・`e` に r は要らない。場所の生成は `R/Semantics.lean` の `μ.set` を列挙し E_BuilderNew・E_RefNew・E_Lazy・E_Op・E_OpFail・E_OpPrim の6件で一致。残りは同じ型の書換え。元の StoreOk から供給するので循環なし。`allocate_reference/lazy` の `ht : Ty.Annotation`、`allocate_continuation` の引数追加も実物と一致。raw 射影は `HandlerOperation`・`HandlerPreservation` のほかに `StoreOk` のものを見つけなかった | 可 |
| 重1（反例） | `Ψ.Sorted` の下で S01a の全53行を読み、閉じない規則・反例は見つからなかった。全証明は未確認 | 可 |
| 重2 | 開いた motive は帰納の仮定になる。Φ は自由で `C_If` の両枝に渡せる。`C_Let` は m の IH で延長する。`C_BuilderLet`・`C_Handle` も表のとおり。`Ty.sorted_shiftV_rev` 等の実在と `Ty.Annotation.norm` を確認 | 可 |
| 重3・中1 | `Q'`・`RowTransport`・閉じた行像は旧 `HasTypeCQ.substTy` と `typeEnvAt` に合う。Q のない3成分の恒等は妥当。ImageOk だけ r1 中1 | 可（1件除く） |
| 中2 | (a)(c)(d) は判定可能。(b) は r1 中2 | 条件付き |
| 中3 | 25+3+3=31 を確認。Tel の具体化の基準は一貫している。`V_Con`・`V_Dict` の期待型の代入を数えない扱いも依存列でないので妥当 | 可 |
| 中4 | 落ちた語はすべて単位へ名指しされた | 可 |
| 中5 | 算術と撤回は可。難度の根拠は r1 中3 | 条件付き |
| 中6 | G04 の控除0。G02 3〜4、G03 1〜2、G05 1〜3、合計 5〜9 | 可 |
| 中7 | G10 の値19規則、残り27規則。依存まで更新しないことを明記 | 可 |
| 中8 | O003・O046・O138・O136・O143・O167 に定理名、単位、拒否例がある | 可 |
| 中9 | S01b に効果の表があり、E_Handle/Fail を未確定の関門とした | 可 |
| 中10 | J20-6 を追加。J20-1 を修正。S00 は別に記録。ただし r1 重1を J20-2 に留めている | 条件付き |
| 軽1〜軽6 | 抜き取りで処置を確認。O027・O118 あり。Sorted の G10 の供給は `embedTy_sorted` を .126 に記載 | 可 |
| 規約 | 絶対パス、「費用」、docs/todo のリンク、`work/` の出どころなし | 可 |

### 再現の入力（r1）

`formal/` で `lake env lean -M 12288 rv2.lean` を実行した。エラーなし。三つの定理の公理は propext・Classical.choice・Quot.sound。SHA-256 は `61f22c6358ef48535cfec964a4f2cf9340dcc3f0fd8b198e7c4e03952f422171`（3741バイト）。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RVL20r1
noncomputable section

/-! 1. 本体の kind は宣言へ縛られない -/
theorem tvar_value_kinded (P : Program) (x : Benitoite.Release.TParam) :
    TypeArgsKinded P [x] [.tvar 0] [.value] := by
  refine ⟨rfl, [.value], rfl, ?_⟩
  intro i a k ha hk
  cases i with
  | zero =>
    simp at ha hk; subst ha; subst hk
    simp [Ty.HasKind, Ordinary, Ty.core]
  | succ n => simp at ha

theorem ctor_not_value (P : Program) (K : KindCtx) (c) : ¬ (Ty.ctor c).HasKind P K .value := by
  simp [Ty.HasKind]

/-- 型引数が .ctor の .op はどの文脈でも型付かない。 -/
theorem op_ctor_untyped {P B Ψ Q C Γ Φ v a} {c o}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = Val.op o [.ctor c]) : False := by
  match h with
  | .V_Op (od := od) _ _ _ hs =>
    cases hv
    obtain ⟨hlen, K, _, hk⟩ := hs.kinds
    simp only [List.length_cons, List.length_nil, List.length_replicate] at hlen
    have h0 : (List.replicate od.tparams.length TyKind.value)[0]? = some .value := by
      rw [← hlen]; rfl
    exact ctor_not_value _ _ _ (hk 0 _ _ rfl h0).1
  | .V_Sub hv' .. => exact op_ctor_untyped hv' hv
  | .V_Normal hv' => exact op_ctor_untyped hv' hv
  | .V_Refine hv' .. => exact op_ctor_untyped hv' hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim ..
  | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked ..
  | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict ..
  | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. =>
    cases hv

/-- S02_V の結論の値の形。源 `.op o [.tvar 0]` の像は `.op o [.ctor c]` になる。 -/
theorem image_shape (o c) :
    Val.substTyAt 0 [Ty.ctor c] [] (Val.op o [.tvar 0]) = Val.op o [.ctor c] := by
  simp [Val.substTyAt, substTypeAt, typeEnvAt, Ty.bind, Ty.rawBind, Ty.norm, shiftTypes]

/-- 型付きの源を仮定すると、S02_V の結論は偽である（kind の入力の内容によらない）。 -/
theorem S02_V_conclusion_false {P B Ψ Q G Φ a o c} :
    ¬ HasTypeVQ P B Ψ Q [] G Φ (Val.substTyAt 0 [Ty.ctor c] [] (Val.op o [.tvar 0])) a := by
  intro h
  rw [image_shape] at h
  exact op_ctor_untyped h rfl

/-! 2. S02_Image: 像なしの恒等の置換でも R0 の正規化で偽 -/
def r0 : Ty := .refined .bytes .truth
theorem r0_norm : r0.norm ≠ r0 := by
  simp [r0, Ty.norm, Ty.refineNorm, Pred.conjuncts, Ty.packRefinements, Ty.core, Ty.refinementPredicates]
def Ψi : StoreTy := fun _ => some (.cont .bytes .bytes Eff.empty (some r0))
def k0 : Ty := .cont .bytes .bytes Eff.empty

theorem image_source (P B) (hen : Ty.WF 0 0 0 k0) (hs : substTyValues (fun _ => Val.loc 0) k0 = k0)
    (hr : r0.WF 0 0 0) :
    ImageOk P B Ψi Benitoite.Release.Qempty [] [] [] (some r0) (fun _ => .loc 0) 0 k0 :=
  .contLoc (b := .bytes) (t := .bytes) (e := Eff.empty) rfl (by rw [hs]; rfl) (by rw [hs]; exact hen) rfl rfl
    (by intro r h; cases h; exact hr)

theorem image_target_false {P B a} (ha : ∃ b t e, a = Ty.cont b t e) :
    ¬ ImageOk P B Ψi Benitoite.Release.Qempty [] [] [] (some r0.norm) (fun _ => .loc 0) 0 a := by
  obtain ⟨b, t, e, rfl⟩ := ha
  intro h
  cases h with
  | ordinary ho => exact ho _ _ _ rfl
  | hidden _ hn => exact hn _ _ _ rfl
  | contLoc _ _ _ hv hl _ =>
    cases hv
    have := Option.some.inj hl
    simp only [Ψi, LocTy.cont.injEq] at this
    exact r0_norm (Option.some.inj this.2.2.2).symm
  | contVar _ hv _ => cases hv
end
end RVL20r1
#print axioms RVL20r1.S02_V_conclusion_false
#print axioms RVL20r1.image_target_false
#print axioms RVL20r1.tvar_value_kinded
```

## r2 の再確認

2026-11-02。対象は `l20/detail.md`（r2）の S12・関門 (b)・J20-7・見込みの節に絞った。全文の再レビューではない。`formal/` と処理系は変更していない。git の操作はしていない。

### 総合判定

**不可**（新しい所見は重1・中2・軽3、計6件）。案4は型引数の穴（r1 重1）を閉じる。不可の理由は、kind の穴が型引数のほかに型注釈の `.tapp` にも残り、S02_C の結論が案4の下でも偽になることである（r2 重1）。修正は小さい見込みで、`Ty.Declared` の `.tapp` の枝が C の kind を読むようにする。これを案4へ含めれば、kind の方式は群 A3a を起動できる状態になると見込む。再確認は Declared の変更の波及に絞ってよい。

### r2 の重

#### r2 重1: `Ty.Annotation` が `.tapp` の kind を読まないので、案4の下でも S02_C の結論が偽である（Lean で確定）

- 箇所: S12.7（「全中間型のkindを独立の信頼欄へ追加しない」「`.tapp` ではこの像と引数のvalue kindを `rawApply_proper`/ProperApplyへ渡し」）、S12.9、L20.12、L20.25 の tapp の形成。
- 問題: `Ty.Declared`（`R/Declared.lean` の `.tapp _ as => declaredTys P C Γ as`）は head の kind と引数の個数を読まない。`Ty.Annotation` は WF・Sorted・Declared だけで HasKind を含まない。`C_Escape`・`HasTypeArmsQ.nil`・`V_List`・`V_Map`・`V_Sub`・`C_Sub` などの結果型と、`.lam` の引数の注釈、`V_Raise` の E は Annotation だけを読む。S12.7 が頼る source の `HasKind` は、これらの位置に存在しない。
- 再現: `rv3.lean`。C の要素が `constructor 1` の宣言でも、`badTapp := .tapp 0 [.bytes, .bytes]` は Annotation を満たす（`bad_annotation`、kind を読まないので宣言によらない）。`source_typed` は `.escape v : badTapp` の型付けを与える。像 `.ctor (.data d)` は `arity 1` で kind が正しい（`image_kinded`。`typeKinds` の欄を満たす）。像は `rawApply` で `.data d [.bytes, .bytes]` になり（`image_eq`）、`P.DataArity d` が1なら Declared でない。`target_false` は像の型での `.escape v` の型付けをどの規則でも否定する。三定理の公理は許可三つだけである。`TypeArgsKinded` の定義を使っていないので、案4に関わらず成り立つ。
- 修正案: 案4の一部として `Ty.Declared` の枝を `.tapp i as => C.kinds[i]? = some (.constructor as.length) ∧ declaredTys P C Γ as` へ改める。Declared は既に C を引数に取るので判断の引数は増えない。波及は `DeclaredTransport.lean` の `.tapp` の枝（値の移送と norm は C を変えないので前提を素通しする）、型の shift の改名（`TypeParamRenaming` の kind の等号）、`LegacyTypeInput` からの供給（既存の HasKind から得る）である。S12.7 は「source の HasKind」でなく「Declared の `.tapp` の kind」を読む形に直す。`Ty.Declared` の型置換の補題を L20.12 の完了条件へ足し、見込みへ計上する。C=[] の閉じた型には `.tapp` が現れない（WF）ので、捕捉と S00 には波及しない。全体のコンパイルは未確認である。

### r2 の中

#### r2 中1: 関門 (b) の例が型注釈の位置を読まない

S12.9 の3 case はいずれも型引数の位置である。r2 重1 は通る。`gate_annotation_case`（`.escape`・`.lam` の注釈に tapp を含む本体を S02 の結論まで閉じる。誤った個数は source で拒否される）を足す。

#### r2 中2: S12.8 の `rowKinds` は補足でなく案4に含めるべきである

例は実際の問題である。`HasKind` の `.fn` の枝は `kindsEff` を読み（`R/Kinds.lean`）、`Eff.row 0` は Fail 列が空なので value kind を満たす。よって本体の `.op o [.fn [] [] .bytes (Eff.row 0)]` は通り、es の像 `Eff.singleFail (.ctor .list)` の後は `op_ctor_untyped` と同じ形で型付かない。これは r1 重1 の行版であり、`rowKinds` なしでは `TypeArgsKinded.substAt` の前提 `kindsEff P [] e` を実呼出しから供給できない。es は `V_Fun`・`V_Prim`・`C_Meth` の `SignatureInstance` を通るので、S12.8 の位置で足りる。修正案は「見直しの対象の補足案」を「固定した案の一部」へ改めることである。「群 A3b のレビューで範囲を確認してから実装」の条件は要らない。

### r2 の軽

1. `S12.3` の `d.tparams.kinds` は `d.tparams : List TParamDecl` なので、`abbrev TypeCtx` の名前空間の `.kinds` へ解決されない見込みである（未検証）。`TypeCtx.kinds d.tparams` と書くか `List` の名前空間にする。
2. J20-7: `traits/collect.rs` の `collect_impl` は `d.parameters(…, true)` で impl の型パラメータに constructor を許す。Lean の `TypeCtx.values id.tparams` は value に固定する。既存の ImplDecl の `HasKind` の検査で target に現れる形は既に拒否されるが、これまで `∃ K` で通っていた本体の型引数は案4で新しく拒否される。合法な表層の例があるかを確かめていない。「新しく狭める表層記法は特定していない」に、この経路を未確認として名指しする。effect の操作の型パラメータの経路（`decls.rs` の残りの `parameters` の呼出し）は読んでいない。
3. r2 重1 の修正の時間は 93時間30分〜209時間5分に含まれない。切替の条件の 21時間20分へ含めるかを書く。

### 依頼の観点の確認

| 観点 | 確認 | 結果 |
|---|---|---|
| 1 型引数の穴 | `.op o [.tvar 0]` は宣言 constructor で拒否、value で受理（`tak4_*`）。`V_Fun`・`V_Prim`・`V_ExternalRef`・`C_Meth`・`V_Dict`・`V_Con`・`C_BuilderLet` の kinds は固定の `ks` と C.kinds を読むので `TypeArgsKinded.substAt` で言える。S12.7 の署名に反例は見つからなかった（全証明は未確認） | 閉じる |
| 2 kind の選び直し | 型引数の `∃` は `TypeArgsKinded` だけ。`Def.KindWF` は署名だけを読み、他から使われない。`SignatureScoped` の K の統合は妥当。`ClassDecl` の `argumentKind` は C の末尾の要素へ入る。Annotation は r2 重1 | 1件残る |
| 3 V_Raise | T の value kind で `[T]` の入力が閉じ、失敗節の `valueParam` と合う。別入口の撤回は正しい。E は代入されないので kind 前提は要らない（注釈の形成は r2 重1 の修正で足りる）。`V_Raise` の位置引数の8箇所（四移送4、外4）も実物と一致 | 可 |
| 4 rowKinds | r2 中2 | 含めるべき |
| 5 Rust | `Decls::parameters`・`named`・`arity`、`Body::instantiate`、`substitute`、`Solver::equal_with_outer`・`bind_head`、`check_function`、`collect_impl`、tests.rs の `F[_]` の拒否（E0426）を確認。記述は読んだとおり。Declared の修正も `Decls::arity` の検査と合う見込み。範囲は軽2 | 可（軽） |
| 6 波及と切替 | `List TParam` は76出現で一致。分類の合計も一致。12枝は V_Raise の位置引数と S12.4 の列挙に矛盾なし（コンパイルは未確認）。切替の条件（21時間20分、手修正76枝超）は判定できる | 可 |
| 7 見込み | 6種類の内訳、合計 5610〜12545 分、案4固有 255〜640 分、群の和が一致。前方参照なし。上端が下端の2倍の単位は 22/143 で、性質ごとに幅が違う。接続の71単位は幅の種類が少ないが、根拠は書かれている | 可 |
| 8 r2 の新しい誤り | r2 重1 は r1 からの残り。新しい誤りは軽1だけ | — |

### 再現の入力（r2）

`formal/` で `lake env lean -M 12288 rv3.lean` を実行した。エラーなし。五つの定理の公理は propext・Classical.choice・Quot.sound。SHA-256 は `cbf0826a2c6d8397712748a4831a4cf66e5640d20ed81c8f68ab7e752b320dcd`。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RVL20r2
noncomputable section

/-- 案4の kind を持つ文脈でも、型注釈の判断は `.tapp` の引数の個数を読まない。
現行の Declared は C の要素を読まないので、Annotation は宣言の kind によらない。 -/
def badTapp : Ty := .tapp 0 [.bytes, .bytes]

theorem bad_annotation (P : Program) (x : Benitoite.Release.TParam) :
    Ty.Annotation P [x] [] badTapp := by
  refine ⟨?_, ?_, ?_⟩
  · simp [badTapp, Ty.WF, Ty.WFList]
  · simp [badTapp, Ty.Sorted, sortedTys]
  · simp [badTapp, Ty.Declared, declaredTys]

/-- 宣言 constructor 1 の型変数の像として正しい kind の `.ctor (.data d)`。 -/
theorem image_kinded {P : Program} {d} (h : TyCon.arity P (.data d) = some 1) :
    (Ty.ctor (.data d)).HasKind P [] (.constructor 1) := by
  simpa [Ty.HasKind] using h

theorem image_eq (d) :
    Ty.substAt 0 [Ty.ctor (.data d)] [] badTapp = .data d [.bytes, .bytes] := by
  simp [Ty.substAt, substTypeAt, typeEnvAt, Ty.bind, Ty.rawBind, rawApply, badTapp, Ty.norm,
    rawBindTys_eq_map, Ty.normTys_eq_map, shiftTypes, Ty.normTys]

theorem image_undeclared {P : Program} {C Γ d}
    (ha : ∀ n, P.DataArity d n → n = 1) :
    ¬ Ty.Declared P C Γ (.data d [.bytes, .bytes]) := by
  simp only [Ty.Declared]
  rintro ⟨⟨n, hn, hl⟩, _⟩
  have := ha n hn
  simp at hl; omega

/-- `.escape` の結果型が宣言のない像なら、どの規則でも型付かない。 -/
theorem escape_untyped {P B Ψ Q C Γ Φ R m a e L d} (ha : ∀ n, P.DataArity d n → n = 1)
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hm : ∃ v, m = Comp.escape v)
    (ht : a.norm = .data d [.bytes, .bytes]) : False := by
  have hn : ∀ {x}, Ty.Declared P C Γ x → x.norm = .data d [.bytes, .bytes] → False := by
    intro x hx he
    have := hx.norm
    rw [he] at this
    exact image_undeclared ha this
  match h with
  | .C_Escape _ hann => exact hn hann.declared ht
  | .C_Sub _ _ _ _ _ hd => exact hn hd ht
  | .C_Eff hc _ => exact escape_untyped ha hc hm ht
  | .C_Normal hc => exact escape_untyped ha hc hm (by rwa [Ty.norm_idem] at ht)
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp ..
  | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail ..
  | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth ..
  | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. =>
    obtain ⟨v, hv⟩ := hm; cases hv

/-- 源は注釈だけで型付き。S02_C の結論の形は偽である。 -/
theorem source_typed {P B Ψ Q Γ Φ r L x v}
    (hv : HasTypeVQ P B Ψ Q [x] Γ Φ v r) (ha : Ty.Annotation P [x] Γ badTapp) :
    HasTypeCQ P B Ψ Q [x] Γ Φ (some r) (.escape v) badTapp Eff.empty L :=
  .C_Escape hv ha

theorem target_false {P B Ψ Q Γ Φ R v e L d} (ha : ∀ n, P.DataArity d n → n = 1) :
    ¬ HasTypeCQ P B Ψ Q [] Γ Φ R (.escape v) (Ty.substAt 0 [Ty.ctor (.data d)] [] badTapp) e L := by
  intro h
  rw [image_eq] at h
  exact escape_untyped ha h ⟨v, rfl⟩ (by simp [Ty.norm, Ty.normTys])

/-! 案4の断片。r1 重1 の型引数の形は閉じる。 -/
def TAK4 (P : Program) (C : List TParamDecl) (ts : List Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∀ (i : Nat) (a : Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k →
    a.HasKind P (C.map TParamDecl.kind) k ∧ (k = .value → Ordinary a)

theorem tak4_rejects_constructor_decl (P : Program) (c) :
    ¬ TAK4 P [⟨c, .constructor 1⟩] [.tvar 0] [.value] := by
  rintro ⟨_, h⟩
  have := (h 0 _ _ rfl rfl).1
  simp [Ty.HasKind] at this

theorem tak4_accepts_value_decl (P : Program) (c) :
    TAK4 P [⟨c, .value⟩] [.tvar 0] [.value] := by
  refine ⟨rfl, ?_⟩
  intro i a k ha hk
  cases i with
  | zero =>
    simp at ha hk; subst ha; subst hk
    simp [Ty.HasKind, Ordinary, Ty.core]
  | succ n => simp at ha

end
end RVL20r2
#print axioms RVL20r2.target_false
#print axioms RVL20r2.bad_annotation
#print axioms RVL20r2.source_typed
#print axioms RVL20r2.tak4_rejects_constructor_decl
#print axioms RVL20r2.tak4_accepts_value_decl
```

## r3 の確認

2026-11-02。対象は `l20/detail.md`（r3）の S12.8・S12.9・S12.11、S12.4 の枝の数、J20-7、見込みの節に絞った。全文の再レビューではない。`formal/` と処理系は変更していない。git の操作はしていない。

### 総合判定

**可**（新しい所見は重0・中0・軽3、計3件）。r2 重1 は閉じる。kind を読まずに像で壊れる形は、読んだ範囲でほかに見つからなかった。**kind の穴の探索はここで打ち切ってよい。** 残りは関門 (b) の Lean が本番の定義で判定する。

この判定は Declared の変更の計画についてである。S02 の全証明の成立と四関門の通過を意味しない。見込み 97時間45分〜219時間45分は固定枠の上端の2倍を超えるので、枠の見直しは取りまとめの判断に残る。

### 観点ごとの確認

| 観点 | 確認 | 結果 |
|---|---|---|
| 1 r2 重1 | `.tapp 0 [.bytes,.bytes]` は `constructor 1` の宣言で head の照合が偽になり拒否される（`bad_rejected`）。個数が宣言と合う場合は、像の `.data d as` が宣言済みになる（`image_ok`）。よって `target_false` の源は作れない。`Tel.Declared`・`declaredTys`・`declaredEff` は `Ty.Declared` を呼ぶだけで、形を変えずに新しい枝が届く。`CaptureDeclared` も同じ。Fail 列の中の `.tapp` も `declaredEff` が読む | 閉じる |
| 2 `.list (.tvar 0)` | Annotation に value kind を足さない判断は正しい。像 `.list (.ctor c)` は WF・Sorted・Declared を満たす。`V_Map`・`V_Set` の `B.sat` は `sat_subst` が `a` を問わない。`Ordinary` と `.refined` の `NotContCore` も `.ctor` で保たれる | 正しい |
| 2 tapp の頭 | constructor の kind の閉じた像は `HasKind.constructor_shape` により `.ctor` だけである。`rawApply` の既定の枝と `.refined` の枝には来ない。`TyCon` は list/set/map/reference/lazy/data の6種で、`.tapp` の個数は arity と一致するので `headD` の既定値も使われない | 残らない |
| 2 `.dict` | `Ty.Declared` は `a` へ下りるだけで、kind を読む読者は `TypeArgsKinded` と `C_Meth` の `SignatureInstance` である。source で kind があるので `TypeArgsKinded.substAt` で移る | 残らない |
| 2 Pred・Term | `Term`・`Pred` は `Ty` を持たない。型を読むのは `Term.HasData` と `FieldRef.Declared` の Γ の lookup と `HasSort` である。`.tvar`・`.tapp` は `HasSort` を持たず、source で sort がある型は頭が固定なので像でも保たれる（単調）。本番の証明は L20.16 の残りである | 残らない見込み |
| 3 作る側 | `Def.WellTyped`・`SignatureScoped` は同じ C の Annotation を読み、`.tapp` の個数は既存の HasKind と同じ条件である。`ConstraintAssumptions` の `extra` の系は `hb` を受け取るだけで、作る側は `TypeCtxMap.annotation` の hC（`TypeParamRenaming.insert`）である。`extra` は TypeCtx になる。`Ty.Declared.closed_context` は C=[] から始まるので hC が空に成り立つ。`LegacyTypeInput` の Declared の欄は C を `legacyTypeCtx` へ替えるだけで、HasKind から head が届く（value の HasKind は `.tapp` まで下りる）。`LegacyTables.constructorFields` は value の kind 文脈なので `.tapp` を含まない。`embedTy_declared_context` の呼出しは `annotation_at` の1箇所で、同じ C なので kind の等号は反射律である | 供給できる |
| 4 39枝 | 19+11+3+1+2=36、36+3=39、304−39=265 は一致。切替の時間 495〜1280 分（8時間15分〜21時間20分）、2倍の 42時間40分も一致し、判定できる。.15 を共通として除く扱いも妥当である | 可（軽1） |
| 5 算術 | 148単位、5865〜13185 分（97時間45分〜219時間45分）、32群の和と全被覆、6種類の内訳、前方参照0を機械照合した | 可 |
| 6 r3 の新しい誤り | 軽2・軽3 のほかに見つからなかった。`rowKinds` は固定の案へ統合され、関門 (b) に型注釈の例が入り、J20-7 は impl と effect の経路を名指しして未確認を分けている | 可 |

### r3 の軽

1. **36枝の根拠**: 受入口の36構成子には `HasTypeArmsQ.plain` がないが、型 shift の36枝には入る。`plain` の Annotation は `FactsWF` だけで、`Pred.Declared` は kind を読まないので hC が要らない可能性がある。件数が一つ多いだけで見込みには影響しない。実装のときに確かめる。
2. **`TyCon.arity` の逆**: S12.11 は「像の HasKind と TyCon.arity から DataArity を得る」と書くが、現行の `TyCon.arity_data` は `DataArity → arity` の向きである。逆の補題を L20.16 の完了条件に名指しする。定義が `Classical.choose` なので短い。
3. **`Ty.Declared.substAt` の入力**: 四署名は `I` の `context` を固定の Γ で受けるが、`Tel.Declared` の `.param` の下では Γ が延びる。`CaptureContextRegular` を `Γ.extend a` へ延ばす手順か、Declared の型置換の入力から `context` を外すことを書く。延長は `Annotation a` から得られる見込みである。

### 再現の入力（r3）

`formal/` で `lake env lean -M 12288 rv4.lean` を実行した。エラーなし。公理は `bad_rejected` が propext、`image_ok` が propext・Classical.choice・Quot.sound。これは新しい枝の判定を写した断片であり、本番の定義の変更の検査ではない。SHA-256 は `1f22e8e72b14e351b616a459fbac52460ce5b6e7f890f33528f025e444b9ed85`。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace RVL20r3
noncomputable section

/-- 新しい `.tapp` の枝の断片（判定だけを写す）。 -/
def TappDeclared (C : List TParamDecl) (i : Nat) (as : List Ty) : Prop :=
  (C.map TParamDecl.kind)[i]? = some (.constructor as.length)

def badArgs : List Ty := [.bytes, .bytes]

/-- r2 重1 の源は arity 1 の宣言で拒否される。 -/
theorem bad_rejected (c) : ¬ TappDeclared [⟨c, .constructor 1⟩] 0 badArgs := by
  simp [TappDeclared, badArgs]

/-- 個数を宣言に合わせると、像の data は宣言済みになる。 -/
theorem image_ok {P : Program} {C : List TParamDecl} {i as d}
    (hs : TappDeclared C i as) (hk : (C.map TParamDecl.kind)[i]? = some (.constructor as.length))
    (ha : ∀ n, TyCon.arity P (.data d) = some n → P.DataArity d n)
    (hi : TyCon.arity P (.data d) = some as.length)
    {D Γ} (hd : declaredTys P D Γ as) :
    Ty.Declared P D Γ (.data d as) :=
  ⟨⟨_, ha _ hi, rfl⟩, hd⟩
end
end RVL20r3
#print axioms RVL20r3.bad_rejected
#print axioms RVL20r3.image_ok
```

## 取りまとめの追記

重1は案2を採った。依頼文に書いた「`V_LocRef`・`V_LocLazy` も同じ欠け」は取りまとめの誤りであり、r1 軽1のとおり反例ではなく帰納の負担である。r1 重1は、レビューの3案に加えて kind を `C` の要素に持たせる案を第一に採り、r2 重1は `Ty.Declared` の `.tapp` の枝で kind を読む案を採った。r2 中2の `rowKinds` は固定の案に含めた。r3 の軽1は件数だけの問題として残し、軽2・軽3は `l20/detail.md` の L20.16 に反映した。判断の記録は `plan.md` の先頭にある。

r3 の判定の「可」は計画についてであり、四つの関門の通過と全証明の成立を意味しない。関門は群 A で判定する。見込みは積上げの97時間45分〜219時間45分を段の見込みとし、設計者へ報告する。
