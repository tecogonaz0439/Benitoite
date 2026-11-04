# 再開2での扱い

2026-11-04の決定では、正常関係はtelの結果と補助引数の篩で表し、呼出し側はd.telと主な保存を読む。CallRunを作らず、順序の実行検査はR40へ送る。以下のFirstReturnと二つの反例は旧候補を調べた記録として保持する。再開2のmapFrom試行はNone枝の含意の不足で指定どおり停止した。現在の停止点と代案は[結果](results.md)の再開2を正とする。旧候補の追加実装を現在の計画として扱わない。

# 正常返却の境界と末端の同じ継続への再到達

2026-11-03。L40.23 の担当が実際の有限遷移で確認した。固定 F06 自体が偽という指摘ではない。既存の末端 `Steps` / `IntervalConnection.Runs` だけで「同じ本体の正常返却」を具体化する候補では不十分であり、最初の呼出しの返却の境界をどう定義するかが未承認である。既存の判断・Runs・固定署名は変更していない。

## 実際に通した命題

証明は本番 [StandardListBodies.lean](../../../../formal/Benitoite/Release/Refinement/StandardListBodies.lean) の `ListModel.later_return_same_continuation` と `endpoint_length_not_contract` にある。既定 import に含め、匿名の適用例も置いた。

`unitFromBody` は、実ソースに合わせた `listFromBody false` に型引数 `[Unit, Unit]` と潜在効果 `[{}]` を代入した本体そのものである。この等号を `rfl` で照合する。標準の List.get の δ は ListModel.builtins 内の getDelta であり、負数を区別した後に実有限列の `getElem?` を読む。空列の添字0と一要素の列の添字1の両応答が `Option.None[Unit]` であることも `rfl` で照合する。

継続 `repeatCont` は `[mark, letF (pure repeatTail), mark]`、`repeatTail` は引数のない `Example.repeat` の通常の fnRef 呼出しである。`Example.repeat` は同じ List.mapFrom を `xs=[Unit]`・`i=1`・`acc=[Unit]` で呼び、その後に同じ repeatTail を持つ。callback は Unit の恒等関数の実 closure であるが、両方の get が None のため呼ばれない。

| 区間 | 実遷移 | 入力・結果 |
|---|---|---|
| 最初の五歩 | E_Let、E_Prim、E_Return、E_Match、E_MatchBody | 元の `xs=[]`・`i=0`・`acc=[]` から `ret []` に至る。継続は repeatCont |
| 中間の五歩 | E_Mark、E_Return、E_Fun(repeat)、E_Let、E_Fun(mapFrom) | 最初の返却を消費し、別の mapFrom を起動する。引数のない repeat の E_Fun は空の Capture で本体を開始し、同じ構造の letF を作り直す。markPush の先頭 mark に対する冪等性により継続は再び repeatCont |
| 最後の五歩 | E_Let、E_Prim、E_Return、E_Match、E_MatchBody | `xs=[Unit]`・`i=1`・`acc=[Unit]` から `ret [Unit]` に至る。継続は repeatCont |

この15歩を同じ `Steps` へ合成すると、元の空列の呼出しの始状態から、同じ継続で一要素の返却へ到達する。`endpoint_length_not_contract` は、この末端の条件だけを受ける「返却の列の長さは元の空列の長さ0」という全称命題を否定する。存在する終端の `ret [Unit]` の長さは1である。これは最初の呼出しが1要素を返したという意味ではない。最初の呼出しは途中で空列を返しており、その返却を消費した後の別の呼出しを末端だけでは区別できない。

`IntervalConnection.Runs` は有限 Steps と末端 EndState の存在である。この例は `ret` と同じ構造の継続だけを読む正常境界の不足を示す。既存 Runs の定義は変えていない。既存 ValueRel の具体的な List 観測までを使う Runs の反例へ言い換えた定理は追加していない。

## 型と宣言について確認した範囲

- 元の四本（map・filter・mapFrom・filterFrom）の `Row.BodyTyped` は、具体の Option の宣言・網羅性、具体の再帰 lookup と三つの組込み署名、satB の空制約の計算から証明した。
- 反例の repeatProgram でも、実 mapFrom の再帰 lookup と同じ Option/組込み署名を使う `Row.BodyTyped` の適用例を置いた。
- 同じ callback の実 closure が `function(value: Unit) -> Unit ! {}` の依存列で型付けられることを直接証明した。
- repeatProgram の `EffectsOk` は空の操作表と効果表から計算した。元の型と効果の規則を変えていない。
- repeatDefinition 自身の Def.WellTyped、反例の全 Program.WellFormed / Program.WellTyped / Builtins.CoreAssumptions、始状態全体の StateTyE は、この反例では証明していない。したがって、それらをすべて追加した別の候補の偽を証明したとは扱わない。標準表全体の CoreAssumptions の充足も、この担当分では未完である。

別の有限例として、生の lambda を空 Capture で閉じると closure へ変わり、元の生構文とは等しくないことを確認した。Some の七歩は、子へ渡る実値を `closeVal Capture.empty x` として保持する。これは型の不一致の反例ではなく、実行中の値とソースの生構文の区別である。

## 採っていない修正と代案

| 案 | 変更・既存契約との差 | 未証明の作業と見込み | 実用上の影響 |
|---|---|---|---|
| 最初の返却までを区切る実行関係 | 既存 Steps の有限導出に、指定した呼出しの最初の返却までという境界を定義する。既存 Runs を書き換えず別の定義とする案。F06 prose の正常返却の具体化を取りまとめが承認する必要がある | 正常/失敗/効果・handler の外側への移動と復帰を含む境界の定義、同じ実 Steps との関係、map/filter の添字・suffix・順序の帰納。指定kで最初のretという候補は下記の追加試行で実装し、不足も実証した。呼出しの由来を識別する境界は未実装であり、更新した見込みは末尾を正とする | 処理系の実行を変えず、最初の呼出しの返却にだけ長さ契約を適用できる |
| 呼出しを識別する専用の区切り | 実行関係の観測用の区切りなら新しい補助判断に限る案。実 Frame/mark に新しい識別子を入れるなら構文・Step・全保存・主言明への波及があり、担当の承認範囲外 | 識別子の必要性・表現と主10の形との関係を先に検討する。能動時間は不明。境界を定義するだけの案より波及が大きい可能性がある | 実行そのものへ追加すれば本番実装にも波及しうる。今回実装していない |
| 既存末端Runsだけで長さを結論する | 今回確認した候補では、最初の返却を消費した後の再到達を排除できない | 上の実15歩で候補を否定済み。採用していない | 誤った長さ契約を導くため採らない |

いずれも固定 Row/BodyTyped・安全な内部19契約・既存 Runs・主な十言明の変更として実装していない。callback の全域性・無失敗・純粋な E、独自の保存の信頼条件も足していない。正常返却の境界の定義を確定する前に停止し、L40.23 を未完として取りまとめへ返す。

## 15〜25分の追加試行：指定kでの最初のret

担当内で14:33 UTCに停止判定を再点検し、固定F06には正常関係の具体Lean署名がないことを確認した。そのため既存Runsを変えず、指定kでの最初のretを内部の有限関係として具体化する短い本番試行を行った。`FirstReturn.lean` に次の関係を実装し、既定 import に含めた。

- `ReturnAt k s` は `s = run q k μ` と `q.view = ret v` を持つことだけを表す。意味上の正しさ・型・長さ・全域性を含まない。
- `FirstReturn.done` はその境界で止まる。`FirstReturn.step` は現在の状態が ReturnAt でないことと、同じ実 Step と、後続の FirstReturn を持つ。
- `FirstReturn.steps` は同じ Steps と末端の正常値への射影である。`typed` は同じ初期StateTyEと既存の有限保存から末端StateTyEを得る。
- 一般のContの等号はEffの関数表現を含む。したがって、これは有限導出をLeanで検査する関係であり、一般のCont等号のBool決定器又は実行可能な正常性判定器を実装したとはしない。

この候補についても、`ListModel.first_return_after_handler_abort` と `first_return_length_not_contract` が、同じ呼出しを識別できない実20歩を与える。ここでは元の入力は一要素、返却は空列である。実本体は `listFromBody false` に `[Unit, Unit]` と `[Fail Unit]` を型・行代入したもの、List.getは同じ実有限列のgetElem?である。

| 区間 | 実遷移と境界 |
|---|---|
| 1〜7歩 | getのSomeとOption照合を通り、同じcallbackの実呼出し地点へ進む。元のaccは空列、元xsは一要素 |
| 8〜10歩 | E_Lamでcallbackを実行し、E_OpFailで指定kの中の外側Fail handlerへ移る。handlerは元の継続をresumeせず、空列を返す。E_DropRelで元の保存継続を破棄し、場所0をusedにする |
| 11〜15歩 | 外側のletがその返却を消費し、引数なしのrepeatFailを起動する。同じFail handlerとletの継続を組み直し、空入力の別のmapFromを呼ぶ |
| 16〜20歩 | 新しいhelperのgetはNoneを返し、空accを返す。このretが、指定kでの最初のretである |

FirstReturnの導出には、各途中状態が指定kでのretでない証拠をすべて含めた。途中のletF/markの深さ、handlerの外側へ移ったときの継続長、let/match等のviewの構文から証明する。したがって、この例は最初のretの後まで進んだ前の例とは異なり、「最初の同じkでのret」という追加条件を満たす。

`first_return_length_not_contract` は、このFirstReturnだけを正常境界とする元の一要素入力の長さ1の候補を否定する。元の呼出しは外側handlerで中断されているため、これを元の呼出しの正常返却として数えることが問題である。callbackの型は `function(value: Unit) -> Unit ! Fail[Unit]` に対応する依存列で直接証明した。効果を純粋へ制限していない。

この二番目の反例でも、repeatFailDefinition自身のDef.WellTyped、全Program.WellFormed/Program.WellTyped/Builtins.CoreAssumptions、始状態全体のStateTyEは未証明である。FirstReturnそのものと同じ実Steps、同じcallbackの型、実List.getの応答と本体特殊化を実証した範囲を超えて、全F06前提を満たす反例とはしない。固定F06自体又は主な十言明の偽を証明したとは扱わない。

## 現在未証明の正常関係の言明と前提

必要なのは、次の全量化で「同じ呼出しが正常返却した」ときの関係を得ることである。ここで「同じ呼出し」の正常導出の定義は未確定であり、新しい意味の真理を表す仮定欄として実装していない。

| 欄 | 完全な対象と条件 |
|---|---|
| プログラムと実行 | 任意P:Program、B:Builtins、固定σ:PathEnv、Eb:Eff、k:Cont、μ/μ':Store、events:List Event、q:Closure。hP:P.WellFormed、hPB:P.WellTyped B、hdecl:P.EffectsOk B、hB:B.CoreAssumptions P、hσ:σ.Valid |
| 型と元の実値 | 任意の閉じたT/U:Ty、潜在E:Eff、xs/ys:List Val、同じf:Val、初期Ψ:StoreTy。StoreOk P B σ Ψ μ、T/Uの閉じたAnnotation、Eの閉じた行注釈。xsのHasTypeEachQ P B Ψ Qempty [] [] [] T。mapではfの型がfn [value] [T] U E、filterではfn [value] [T] Boolean Eである。Eへの純粋性・無失敗性は要求しない |
| 同じ標準定義と表 | mapFrom/filterFromの再帰lookupが対応するlistFromDefinitionと等しいこと。Optionの二構成子・arity・網羅性。List.get/List.append/整数加算の具体署名lookupと、実際に呼んだδが同じ有限列のget/一要素append/検査付き加算であること。任意callbackの結果型・保存・全域性をこの欄に入れない |
| 最初の内部状態 | s0 = run (mk (listCapture xs f 0 []) ((listFromBody flag).substTy typeArguments [E])) k μ。mapのtypeArguments=[T,U]、filterは[T]。同じs0のStateTyE P B σ Ebを持つ |
| 正常返却の必要条件 | s0から同じStep関係の有限導出でrun q k μ'へ至りq.view=ret(list ys)であることに加え、外側handlerへの移動・resume・保存継続の破棄を通じて、末端が元の呼出しの正常返却に属することを識別する。どの内部の有限判断でこの由来を定義するかが未確定。末端Steps/RunsだけとFirstReturnだけの二候補は、上の実例ではこの由来を供給しない |
| 結論 | あるΨ'についてStoreOk P B σ Ψ' μ'と、mapではysの各値のU型・ys.length=xs.length、filterではysの各値のT型・ys.length≤xs.lengthを返す。mapは元の要素順に実際に観測したcallbackの返却列、filterは元の要素順のうち同じcallbackがtrueを返した実値列と一致することを、同じ子Steps・同じ事象の順・ストアの連鎖で示す。callbackの実値は受信後の値として扱い、生のlambdaとの構文同一性を要求しない |
| 内部の帰納 | 任意の途中の数学添字i:Nat、remaining=xs.drop i、i+remaining.length=xs.lengthを保持する。mapはacc.length=i、filterはacc.length≤i、同じ実行でのaccの要素型と順序を保持する。機械添字の数学値はiと一致させ、次へ進む実加算が正常な場合だけi+1を得る。有限列の数学長全域をIntegerへ収める条件を足さない |

上の結論のうち、実append直前のacc/子のU.norm型は `list_append_reached_typed` で供給できる。まだ閉じていないのは、呼出し由来を識別する正常導出と、そこから全反復の長さ・suffix・順序・要素型を同じ実行として取り出す帰納である。「型付きcallbackだからその実結果はU型」という未証明の別前提には戻していない。

## 追加試行後の代案と停止点

| 案 | 変更が必要な定義・承認の点 | 未実装の作業の暫定見込み | 実用上の影響 |
|---|---|---|---|
| 呼出しの由来を追う補助の有限実行関係 | 実Stepと並行し、呼出しの継続がhandlerへ捕捉され、resumeされたか破棄されたかを追う。長さ/正常性を信頼欄にせず、個々の実構成子から対応を証明する。既存Runsは保持する。F06の正常境界の具体化として取りまとめが先に判断する | 設計/量化の確定30〜60分、実Stepとの対応と正常境界60〜120分、List二本の関係60〜120分、局所検査/既定build数分。能動の暫定積上げ150〜300分、未試行。独立レビュー/受け入れ待ちは不明 | 実処理系を変えず、外側handlerで中断された呼出しを正常契約の対象に数えず、resumeされた呼出しを扱うことを目指せる |
| 実行関係の観測用の専用区切り | 元の呼出しを識別する区切りと、handlerでの捕捉/復帰時の扱いを定義する。実Frameへ識別子を加えるなら主10/保存/実装まで波及するため今回の担当範囲外 | 観測用の別関係で済むかを先に検討する。能動時間は不明。実Frame変更なら上の案より広い可能性がある | 実行時変更を要する場合はRust/Leanの接続にも影響する |
| handlerなし又は純粋Eに限定 | F06の任意の潜在効果・失敗を保つ提供範囲を削る | 採用しない。了承を推定して実装しない | 外側handlerで処理する利用を除外するため、要求を満たさない |

追加試行は、FirstReturnの有限導出・実Stepへの射影・既存有限保存の読者と、外側Fail handlerによる中断の実20歩までを本番に残して終える。二つの境界の候補の不足を実証したが、固定F06を偽とせず、呼出し由来又は専用区切りの判断を取りまとめへ返す。既存Runs/Step/主10/固定Row/安全な内部19契約は変更していない。
