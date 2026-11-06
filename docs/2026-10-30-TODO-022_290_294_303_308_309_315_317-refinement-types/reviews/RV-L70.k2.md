# RV-L70.k2: L70 群 K2（核の欄の事実の拡張）の独立レビュー

2026-11-07。対象はブランチ `m014/l70.k2` の作業木の未コミットの差分と未追跡のファイルである。基準は `5cb33d0e5ecf5b8b9d2ffa02e88a70084d89e50e` で、`git rev-parse HEAD` の一致を確かめた。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-k2/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回である。

読んだもの:

- 本体の作業木の依頼文 `work/m014/L70.k2-prompt.md`・`L70.k2-r1-prompt.md`（初回の停止への判断で案 A を採ったもの）と報告 `L70.k2-report.md`・`L70.k2-r1-report.md`、[群 K2 の結果](../l70/k2/results.md)と [counterexamples.lean](../l70/k2/counterexamples.lean)。
- [群 D の結果](../l70/d/results.md)の R10 の射影と重4の処置、[RV-L70.d](RV-L70.d.md) の重4とその再レビュー。本体の作業木の最新の `plan.md` の先頭の判断のうち、停止の条件の改め、RV-L70.e3 の処置と群 K2 の起動、群 K2 の初回の停止（案 A）。[U02 の決定](../u02/decisions.md)の R10、README の J70-4。記録の形は [RV-L70.d2](RV-L70.d2.md) の初回の部分に倣った。
- 新規の `R/FieldRelations.lean`・`R/Surface/FieldProjectionExamples.lean` の全文。変更した既存21モジュールの差分（`FieldFacts`・`Logic`・`LogicSound`・`Basic`・`CapturedFacts`・`MatchFacts`・`MatchStateLeaves`・標準本体4件・`Surface.Basic`・`Syntax`・`Desugar`・`Theorems`・`CheckMaterials`・`CheckInferCertificates`・`CheckPatternFacts` と例4件）。照合のために、`ClosedEvaluation`・`Observation` の観測と意味、`Declared`、`Context` の `Ty.carrierFacts`、`BuiltinSchema` の候補、`EqProofSyntax`・`EqualityMode`、`Check.lean` の腕の再検査、`SurfaceLibrary` の `accessorDef_wellTyped` の読者、`Surface/Predicates.lean` の既存の例を読んだ。01-12・07-04 の差分。
- 群 K2 の `verify.py`・`run_check.py` と保存された集計。台本は読んで判定し、実行していない。

したことは、関係の定義と意味論・部分評価の読み合わせ、`Entails` の帰納の全読者の照会、既存の形の保持と取り出しの関数の結果型の Lean による確認、`AccessorOk` の新しい形成の条件の証人の構成、主な宣言の公理依存の確認、組込みの論理の規則による移送の経路の照会である。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、確認用の入力は `<tmp>` に置いた。`-o` は使っていない。

`lake build`・cargo・`scripts/check.sh`・台本の実行・git の書き込み操作は行っていない。変更したリポジトリのファイルは本書だけである。

## 結論

**可。重0件、中2件、軽2件、情報4件である。**

生成する欄の事実は、照合と欄の読み出しが成功した全場合で閉じた導出を持つ。`MatchFacts.field_relation_entails` が、束縛値と経路の項が同じ部分観測を返すこと（`value_observe_shape`・`readPath_observe`）から、`fieldRelation_entails` で関係全体の `Entails []` を作る。値の比較・Float の分類・構成子の判定は部分評価の `some true`、測度は `Entails.measured` による。`Entails.measured` は意味論で健全であり、`bind`・`weaken`・`cut`・`sound` の全読者が追随した。整数の値と List の長さの述語は元の形と定義上同じで、`tailLinks` と精密な getter の読者も保たれている。新しい公理・`sorry`・独立の信頼条件はなく、書ける形も狭めていない。

ただし、完了の判定「全 sort の欄の値…について、取り出しの関数の結果に篩の事実が流れる」は、値の等号で移せる事実に限られる。Decimal・Float の順序の比較、String の `charactersIn`・`member` は、関係から結果へ移す規則が論理にない（中1）。01-12 の写しには、取り出す関数の戻り値型と `Entails` の構成子数の古い記述が残る（中2）。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | `R/FieldRelations.lean:22` の `fieldRelation`（33行の decimal・boolean・unit、Float・String の枝）、`R/BuiltinSchema.lean:96` の `candidates`、`R/EqProofSyntax.lean:32` の `.hyp`、results.md「完了条件との照合」の一行目 | 関係の `compare s .eq` は、論理の中で書き換えに使える等号ではない。`EqProof` が仮定から書き換えるのは整数の `Pred.eq` だけであり、組込みの候補は `compare eq` の推移と対称（`scalarOrder` の `eqTrans`・`eqSymm`）、Character の符号位置との対応（`characterCompare`）、Float の分類と比較の関係だけを持つ。そのため、次の事実は全体の篩から射影の結果へ流れる経路がない。(a) Decimal の欄の順序（例 `amount: Decimal{a \| a >= 0}`）: `eq` から `le`・`ge` を導く規則がなく、`leTrans`・`ltLe`・`leLt` へ繋がらない。(b) Float の欄の順序（`x > 0.0` など）: 分類の判定同値は移るが、比較は移らない。(c) String の欄の `charactersIn`・`member`: `compare string eq` を受ける合同の規則がない。意味の上ではどれも関係から真であり（同じ観測）、健全性の問題ではない。Character の順序は `characterCompare` と符号位置の整数の等号で移る見込みがある。整数・List 等の測度・data の構成子・Boolean と各 sort の定数との等号は移る。例16件は、どれも定数との等号か、分類・測度・構成子の判定の移送だけを確かめており、この差を検出しない | 次のどちらかを選ぶ。(i) 観測の一致の形を広げる。Decimal は `compare le a b ∧ compare le b a` を関係に加え、既存の `leTrans` 等で順序を移す。Float は「両辺の `le` と `ge`、又は両辺の NaN」を加える。String の `charactersIn`・`member` は範囲が無限なので、(ii) が要る。(ii) 組込みの候補に、観測の同一を表す `compare s eq`（Character・String・Boolean・Unit）から任意の原子を移す合同の規則を加え、健全性を示す。どちらも書ける形を広げる側で、停止の条件に当たらない。足さない場合は、移らない事実の一覧と理由を results.md の表に置き、完了の判定を「値の等号と、分類・測度・構成子の判定で移せる事実」に改め、設計者の見直しの対象へ加える | 読めば確定（規則の一覧と書き換えの方式）。非導出の証明はしていない |
| 中2 | 中 | 01-12 の560行（`RecordsOk` の段落「戻り値の型が k 番目のフィールドの型」）、665行の表（`R.fi` の `: Ai`）、3820行（「`Entails`のweaken・cut・sound・bindは19構成子を扱う」） | 本番の `accessorRet` は観測できる欄に `accessorPred` の篩を付け、`Entails` は20構成子になった。同じ章の4003行の新しい段落と3754行の「20構成子」と食い違う。560行・665行は群 D で整数・List の篩を付けた時点から古く、今回の変更で全 sort に広がった | 560行・665行を、観測できる欄では基の型に `accessorPred` の篩を付けた型であること（対象・sort のない型・構成子列が空の data は基の型）に直す。3820行を20構成子とし、`measured` の場合が子の導出を持たないことを一文で書く | 読めば確定 |
| 軽1 | 軽 | `R/Surface/Basic.lean:428` の `accessorView` | `accessorPred` が `fieldRelation` を使うようになり、本番の読者がなくなった。読むのは `FieldProjectionExamples` の simp の補題の一覧だけである | 定義を除くか、読者を置く | 読めば確定 |
| 軽2 | 軽 | `FieldProjectionExamples` の `character_result_rejects_integer`・`data_result_rejects_unit`、01-12 の4003行「測度は `Entails.measured` から導く」 | (1) 二つの拒否の対照は、`accessorRet` が作らない自己型（Integer・Unit）で篩の形成が失敗することを示すだけで、「欄の型が合わない場合に事実が流れない」ことの対照としては弱い。意味のある対照は `target_result` と `partial_map_measure` である。(2) List の長さと整数の値は、測度でも `field_equality_true` の部分評価から導く。01-12 の文は全測度を `measured` とする | (1) 依頼の対照は中1の処置と合わせ、移らない事実（又は基の型を返す欄）の例で置き直す。(2) 「List の長さは部分評価、ほかの測度は `Entails.measured`」と書く | 読めば確定 |
| 情1 | 情報 | `R/Logic.lean` の `Entails.measured`、`R/LogicSound.lean`、`R/Basic.lean` | 規則は健全で、追加は必要最小に近い。両辺の閉じた部分観測が同じ `o` なら、全域モデル `Term.interpret` も両辺で `some o` を返し、`measure` の整数射影は同じ値になる（観測不能の Map・不正な Bytes では両辺とも既定値0）。`Sorted` を要求しないが、sort の合わない項でも意味は両辺0で真である（検査2の5）。より小さい代案は見当たらない。`EqProof.measure` は内側の構造の一致（`termEq`）を要し、値の項と欄の項は字面が違う。部分評価を成功させる案は鍵の観測の欠落で成り立たない。`CertificateKernel` と `evalClosed` は変わらず、`checkedAt` の健全性は意味の上の含意なので影響しない。`Entails` を帰納する読者は `weaken`・`cut`・`bind`・`sound` の4件だけで、全て追随した。処理系の検査器（R20）は事実を仮定として文脈へ加えるだけなので、この規則を導出として作る必要はない | なし | 実行で確定（検査1・2・3） |
| 情2 | 情報 | `R/Surface/Theorems.lean` の `AccessorOk`、`Surface/Examples.lean` の `mainProgram_wellFormed` | 観測できる欄が増え、`AccessorOk` の欄の関係の `FactsWF` の連言が新しい sort にも掛かる。空疎ではない。Float の欄では、宣言の表から `FactsWF` 全体（WF・Sorted・Declared）を構成した（検査3の `float_facts`）。data の欄では WF と Sorted を構成し、Declared は構成子名と欄の宣言の照合に帰着することを確かめた。ただし、取り出しの関数を持つプログラムの `Program.WellFormed` の具体の証人は、基準の版から一つもない（`mainProgram` は取り出しの関数を持たない）。これは今回の変更より前からの状態である | R50 か群 G で、取り出しの関数を持つ実入口の例を置くときに `AccessorOk` を供給する | 実行で確定（検査3） |
| 情3 | 情報 | `R/Surface/CheckInferCertificates.lean` の `inferFieldLinks`、`Check.lean:806` の腕の再検査 | checker は、単一の構成子のパターンの全ての腕で、全 sort の欄の事実を推論し、`linksValid` と `factsWF` で再検査する。`factsWF` が偽なら腕ごと断るので、新しい sort の形成が失敗すると受理が狭まる。経路の欄の sort は `binderRoutes` が具体化した欄の型の `sort?` から付け、`FieldRef.Declared` も同じ具体化（`a.subst ts []`）の sort を読むので、整数と同じ条件で通ると読んだ。構成子列は `q.formation.ctors` から取る。事実の数は Float の欄で7原子、data の欄で構成子の数に比例して増える | R20・R50 で、処理系が同じ関係の形（Float の連言の順、String の三つの連言）と、構成子列の順（`Materials.constructors` の宣言順）を生成することを照合する。受理が狭まらないことを、Float・data の欄を持つ record の match の受理例で確かめる | 読めば確定。受理例は実行していない |
| 情4 | 情報 | `R/Surface/Syntax.lean` の `Program.dataConstructors`・`Declarations.dataConstructors`、`CheckMaterials.lean` | 新しい欄は信頼の対象ではない。列にない構成子は事実を減らすだけで、宣言のない名前は `Pred.Declared`（`P.cons c = some cd ∧ cd.data = d`）が形成で断る。有限材料では `material_inventory` が実際の全構成子を供給する。抽象の `Program` で既定値 `[]` のままなら data の欄は基の型を返す。U02 R10 と J70-4（核の `ConDecl` を変えない）とも整合する。核で変わったのは `FieldLink` の欄の追加（既定値 `[]`）と `Entails` の構成子の追加だけである | なし | 読めば確定 |

## 観点ごとの根拠

### 1. `fieldRelation`

`fieldRelation_entails` は、閉じた二項 a・b が同じ部分観測 o を返し、`o.sort = s` と関係の `Sorted` が成り立つとき、全 sort と全測度の場合で `Entails []` を返す。各場合は次のとおりである。

- 整数: 元の `Pred.eq` の部分評価。
- Character・String: `compare_observed_eval` と `measured` の連言。
- Decimal・Boolean・Unit: `compare_observed_eval`。
- Float 二幅: `floatFieldRelation_eval`。
- List・Bytes・Map・Set と `some m`: `measured`。
- data: `constructorFieldRelation_eval`。
- 対象: `.truth`。

反射性は `Observation.scalar_eq_refl` が `Observation.compare` の実定義から五 sort について示す。Float では、`ieee_eq_or_nan` が同じビット列の IEEE 等号か NaN の真を示す。六分類は同じ観測に同じ二値を返し、`predicateIff_eval` で判定同値が真になる（検査2の6で NaN のビット列 `0x7fc00000` に適用した）。ゼロの符号も同じ観測なので一致する。data の判定同値は列の各要素で同じ `decide (d = c)` を比べる。列の全件性は `material_inventory` が既存の `Materials.constructors_complete` から示す。

`CaptureOk.field_facts` の言明は基準と同じである。`fieldRelation_sorted` が `FieldRelation.Valid` と関係の `Sorted` から両辺の元の sort を取り出し、`MatchFacts.field_relation_entails` を呼ぶ。整数と List の長さの場合は、既存の `field_equality_true` をそのまま使う。

Decimal の `compare eq` は数値の等号であり、表現（スケール）を区別しない。ただし Decimal の型は運搬する事実 `decimalRepresented (var 0)`（`Ty.carrierFacts`）を持つので、表現可能性は結果型で別に得られる。Float と同じ「等号が観測できる性質を保存しない」障害には当たらない。

### 2. `Entails.measured`

情1のとおりである。01-12 の写しの規則は本番の構成子と一致する（`verify.py` が断片を照合し、本書でも読み合わせた）。この規則が要ったのは、`Observation.measure` の部分評価が Map の鍵の観測の欠落（`mapKeys` が `none`）、Set の同様の場合、Bytes の要素の範囲外で `none` になるためである。`partial_map_measure` は、鍵の欄に `none` を持つ Map で `evalClosed` が `none` になることと、`measured` の導出が両立することを示し、対照として意味を持つ。

### 3. 取り出しの関数の結果型

`accessorRet c cd k cs` は `accessorObserved cd k cs` のとき、`fieldRelation (accessorSort cd k) cs (accessorMeasure cd k) (var 0) (field (accessorRef c cd k) (var 1))` の篩を付ける。`accessorLink c cd k cs` は同じ sort・測度・列の `FieldLink` で、`FieldLink.predicate` の像が `accessorPred` に一致することを `accessorDef_wellTyped` が `simp` で示す。

`lookupFun` は `accessorConstructors p.dataConstructors cd k` を宣言（`accessorDecl`）と本体（`accessorDef`）へ同じく渡す。`Program.WellFormed.accessors` の `AccessorOk p.declarations c cd k` も、既定の引数で同じ列を読む。`SurfaceLibrary` の性質1の読者は、この三つを定義上の一致で受ける。checker の `inferFieldLinks` は同じ測度の選び方（List・Bytes・Map・Set）と `FieldRelation.Valid` の判定を使い、`fieldLinkValid` は `FieldLink.Valid` と同値である（`fieldLinkValid_spec`）。

対象の欄は `accessorObserved` が偽で基の型を返し（`target_result`）、`FieldRelation.Valid` も対象を断る。理由と要る述語は results.md の表にある。

### 4. 既存の読者

検査2で次を確かめた。

- `measure = none` かつ sort が整数の `FieldLink.predicate` と、`measure = some listLength` の `FieldLink.predicate` は、基準の形 `.eq (viewTerm m …) (viewTerm m …)` に `simp` で一致する。
- 整数と List の欄の `accessorRet` は、既定の構成子列で元の篩付きの型に `rfl` で一致する。
- 構成子列が空の data の欄は、基の型のままである。

`Surface/Predicates.lean` の `Span`・`Sized` の `rfl` の例は変更なしで既定ビルドに残る。標準本体の `tailLinks`（二系統）と `PreciseGetter.links` は、構成子列 `[]` を明示しただけである。旧 `Valid` は測度 `listLength` を経路の sort と無関係に許したが、関係の `Sorted` が経路の末尾の sort を List に限っていたので、新しい `s = m.input` の条件で失う入力はない。

### 5. 例と対照

16件の Projection は、全体の篩を持つ受け手の文脈で、実際の `accessorRet` から結果の篩への `Ty.LeQ` を任意の核 P について構成する。結果型の字面の照合だけではない。移す事実は、定数との等号（整数・Character・Decimal・Boolean・String・Unit）、六分類（Float 二幅）、測度と定数の等号（7測度）、構成子の判定（data）である。中1の順序・`charactersIn`・`member` の移送は含まない。対照の評価は軽2のとおりである。

### 6. 守ること

新規の2モジュールに `axiom`・`sorry`・`#eval`・`native_decide`・`set_option maxHeartbeats` はない。新規の補題12件の読者を照会し、どれも本番か例に読者がある。読者のない宣言は軽1の `accessorView` だけである。主な宣言の公理は `propext`・`Classical.choice`・`Quot.sound` の範囲内である（検査3）。

01-12・07-04 の写しは今回の定義と規則に当たる箇所で、経緯の文や工程の ID はない。ただし中2・軽2の古い記述が残る。記録は11ファイル・約423 KB で、最大は `declarations-03.md` の89,963バイトである。各ファイルは100 KB 以下に収まる。宣言の写しは群末の一回分だけである。

運用の差（局所の Lean を一時二つ重ねたこと）は担当が results.md に記録しており、最終の既定ビルドと監査は指定のロックの下で順に一回ずつ実行された。

## 実行した検査

Lean はすべて `<repo>/formal/` から実行し、同時に一つだけとした。単独検査は対象 worktree の既存のビルド済みモジュール（最終ビルドの時刻のもの）を import する。最大常駐量は約2.0 GB であった。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 1 | `<tmp>/Names.lean`。`Entails.measured`・`fieldRelation`・`FieldRelation.Valid`・`accessorRet`・`AccessorOk`・`accessorDef_wellTyped`・`CaptureOk.field_facts`・`MatchFacts.field_relation_entails`・`field_equality_true`・`fieldRelation_entails`・`CaptureOk.addEntailedFacts` の `#check` | 終了0。言明は前記のとおり。`CaptureOk.field_facts` の言明は基準と同じ形 |
| 2 | `<tmp>/Check.lean`。(1)(2) 整数と List の `FieldLink.predicate` の元の形との一致と `FieldRelation.Valid`、(3) 整数と List の `accessorRet` の元の篩付きの型、(4) 構成子列が空の data の基の型、(5) sort の合わない `measured` の導出とその意味が真であること、(6) NaN のビット列での `floatFieldRelation` の部分評価 `some true` | 終了0、出力・警告なし |
| 3 | `<tmp>/Witness.lean`。Float の欄の `accessorLink` の `FactsWF`（WF・Sorted・Declared）の証明 `float_facts`、data の欄の WF と Sorted の証明、主な宣言（`Entails.measured`・`Entails.sound`・`fieldRelation_entails`・`field_relation_entails`・`CaptureOk.field_facts`・`accessorDef_wellTyped`・`floatFieldRelation_eval`・`desugar_typed`・例4件）の `#print axioms` | 終了0（simp の未使用の引数の警告だけ）。公理は許可された三公理の範囲内。初稿は `Ty.subst` の展開不足で終了1となり、確認用入力を直した |
| 4 | 読み取り専用の `grep`・`git diff` による照会。`Entails` を帰納する読者、`measured` の読者、新規補題の読者、`accessorView`・`addEvaluatedFacts` の読者、`BuiltinSchema.candidates`・`EqProof.checkRaw` の書き換えの方式、01-12・07-04 の古い記述、変更ファイルの時刻とビルドの記録 | 前記のとおり |

担当が記した既定ビルド1,557ジョブ・公理監査112,590宣言・照合の終了0は保存された報告として読み、本レビューで実行した検査としては数えていない。`verify.py`・`run_check.py` は実行していない。

確認用の最終入力は、`Names.lean` が536バイト（SHA-256 `86db7f893c97b643ef5847bef9183bd04e42963ab491d9d043aa47e3485cc5e5`）、`Check.lean` が2,609バイト（SHA-256 `207b18c8d6a65ce732e7800ef3c5d28e75c4a59b415193cbb867a7682b486d54`）、`Witness.lean` が2,847バイト（SHA-256 `8e44e170e2c59b0d451093de5d2bc265134c6f7e62335aa047e22309b5ffeb8e`）である。

## 処置の確認

2026-11-07。対象は同じ作業木の、再開2の後の未コミットの差分である。読んだのは、本体の作業木の依頼文 `work/m014/L70.k2-r2-prompt.md`・報告 `L70.k2-r2-report.md`、[群 K2 の結果](../l70/k2/results.md)の「再開2」、新規の `R/FieldRelationSyntax.lean`・`R/FieldAtomSound.lean`、`Logic`・`LogicSound`・`Basic` の差分、`FieldProjectionExamples` の追加の例と対照、01-12・07-04 の該当の段落である。

### 結論

**可。前回の所見は全て処置された。新しい所見は中1件、情報1件である。**

| 前回の番号 | 判定 | 根拠 |
|---|---|---|
| 中1 | 可（規則の健全性と例） | 下の「中1の確認」 |
| 中2 | 可 | 01-12 の560行の `RecordsOk` の段落と665行の表は、戻り値型を `accessorRet` とし、基の型を返す場合を書いた。3754行と3862行は21構成子に揃い、`measured`・`fieldAtom` の帰納の扱いも書いた。07-04 の表も21構成子である |
| 軽1 | 可 | `accessorView` は定義も例の参照も除かれた（`grep` で0件） |
| 軽2 | 可 | 対照の `character_result_rejects_integer`・`unit_result_rejects_constructor` は、実際の `accessorRet` を自己型にした形成の拒否になった。01-12・07-04 は、整数の値と List の長さを部分評価、ほかの測度を `Entails.measured` から導くと書く |
| 情1 | 可 | `fieldAtom` を加えた `Entails` の帰納の4読者（`weaken`・`cut`・`bind`・`sound`）が追随した |
| 情2・情3・情4 | 可（申し送り） | results.md の「後段への申し送り」に、R20・R50 での関係の形と構成子の順の照合、Float・data の欄の match の受理例、`AccessorOk` の実入口の供給が書かれた |

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中3 | 中 | `R/Logic.lean` の `Entails.fieldAtom`、`Certificate`（01-12 3856行の7構成子）と `BuiltinSchema.candidates`、results.md「後段への申し送り」 | 新しい移送は宣言的な `Entails` の構成子にしかない。`fieldAtom` の読者は論理の4補題と例だけで、checker（`Surface.Check`）の証明書（`Certificate`・`PreparedLeaf` の候補）には、この移送を表す形がない。checker は導出を `checkedAt` 経由の証明書の検査で作るので、`amount(r) >= 0` のような Decimal の順序・Float の順序・`charactersIn` の移送に頼る本体は、checker の実入口では受理されない。表層の型付けと性質1では使えるが、R20 の検査器が実装すべき受け口が決まっていない。健全性の問題ではなく、受理を狭める変更でもない（前の版でも受理されなかった） | 次のどちらかを選ぶ。(i) `BuiltinSchema` に候補 `fieldAtom` を加える。引数の項から `implies (and (fieldRelation s cs none a b) p) q` を `FieldAtom` の組について列挙し、`FieldAtom.sound` から葉の健全性を示す。(ii) この単位では checker の受理を対象外とし、results.md の申し送りに、R20 が `FieldAtom` と同じ範囲の証明書の形を持つ必要があることを書く | 読めば確定（読者の照会と証明書の構成子の一覧） |
| 情5 | 情報 | `FieldAtom` の範囲、`string_member_not_preserved` | 規則は健全である。`FieldAtom.sound` は任意の全域モデル η で、関係が真なら両原子の解釈が等しいことを示す。`Entails.sound` は全ての η を量化するので、String の `member` の反例（観測の欠けた `var 0` では既定値の比較は一致するが、`member` は元の解釈を読む）は、この規則から `member` を除く理由として正しい。より広い形には、`Entails.sound` を文脈の sort に合うモデルに限る版が要る。検査6では、`var 0` に String の観測があるモデルで `member` が一致することを確かめた。ただし、全読者が使う健全性の言明を変えることになり、小さい変更ではない。Decimal の `decimalRepresented`（`0e0` と `0e-29`）、列外の構成子、data の内部の欄の反例も、関係が区別しない値の対として意味を持つ。Decimal の表現可能性は結果型の運搬する事実で別に得られる | なし。`member` の移送が実用で要るなら、sort に合うモデルの健全性を別の項目として扱う | 実行で確定（検査5・6） |

### 中1の確認

`Entails.fieldAtom` は、`FieldAtom s cs a b p q` と、関係 `fieldRelation s cs none a b` の導出と、`p` の導出から `q` を導く。`FieldAtom` は次の組だけから作る。

- Character・Decimal・Float 二幅・Boolean・String・Unit の比較（`FieldRelation.Scalar`）。どちらかの位置を移し、相手の項は任意の項に固定する。
- String の `charactersIn`。
- Float の六分類。
- 列に含まれる構成子の `constructorIs`。
- これらの `reverse`。

`FieldAtom.sound` は sort ごとに次を示す。

- Decimal: 数値の等号から、相手の項との比較を保存する（`decimal_compare_congr`）。
- Float: IEEE 等号又は両辺の NaN から、比較を保存する（`ieee_compare_congr`）。
- String・Character・Boolean・Unit: 等号から `observeAs` の値が同じになる。

`bind` は `FieldAtom.bind` と `fieldRelation_bind`、`weaken`・`cut` は二つの子の帰納仮定を使う。`CertificateKernel` と `evalClosed` は変わらないので、証明書の健全性は影響を受けない。検査5で、相手の項が任意の開いた項 c の Decimal の `lt` の移送を構成した。

例の `decimal_order_projection`・`float64_order_projection`・`float32_order_projection` は、全ての比較 o を量化する。`character_order_projection` は右の位置の移送、`charactersIn_projection` は任意の下端と上端を扱う。どれも、全体の篩を持つ受け手の文脈で、実際の `accessorRet`（`project` が `accessorObserved` の下で展開する）から結果の篩への `Ty.LeQ` を構成する。Decimal の `.ge` が `a >= 0` に当たる。意味のある結果の篩を導いている。

### 実行した検査

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 5 | `<tmp>/Atom.lean`。`FieldAtom.sound` の `#check`、任意の項 c との Decimal の `lt` の移送、主な宣言（`FieldAtom.sound`・`Entails.sound`・順序と `charactersIn` の例・`string_member_not_preserved`・`desugar_typed`）の `#print axioms` | 終了0。言明は任意の η を量化する。公理は許可された三公理の範囲内 |
| 6 | 同じ入力。`var 0` に String の観測を与えたモデルで、`member` の解釈が文字列の定数と一致すること | 終了0 |
| 7 | 読み取り専用の `grep` による照会。`fieldAtom`・`FieldAtom` の読者、`accessorView` の残り、01-12・07-04 の構成子数と戻り値型の記述、記録の大きさ | 前記のとおり。記録の最大は89,565バイト |

Lean は `<repo>/formal/` から、ビルド済みの生成物（`FieldAtomSound` は03:08のもの）を import して一つだけ実行した。担当の既定ビルド1,559ジョブ・公理監査112,636宣言・照合の終了0は、保存された報告として読み、本レビューの検査には数えていない。確認用の入力 `Atom.lean` は1,217バイト（SHA-256 `40337c82a1e0f18b7122a505a97d5b239324b77915fa5063e711ca76d9e8e44d`）である。

## 再開3の処置の確認

2026-11-07。対象は同じ作業木の、再開3の後の未コミットの差分である。読んだのは次のものである。

- 本体の作業木の依頼文 `work/m014/L70.k2-r3-prompt.md` と報告 `L70.k2-r3-report.md`。
- [群 K2 の結果](../l70/k2/results.md)の「再開3」と「取りまとめによる記録の置き換え」。
- `PreparedLeafSyntax`・`BuiltinSchema`・`BuiltinLogic` の差分。
- 新規の `R/Surface/FieldCheckerExamples.lean` の全文。
- 記録の `audit-summary.json`・`declarations-summary.json`・`verify-summary.json`・`compact_declarations.py`。

### 結論

**可。中3は処置された。新しい所見は軽1件、情報2件である。**

| 番号 | 判定 | 根拠 |
|---|---|---|
| 中3 | 可 | 下の「候補の再検査と健全性」と「実入口の例」 |

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽3 | 軽 | results.md「取りまとめによる記録の置き換え」 | 写しのファイル数を48と書くが、`declarations-summary.json` の `full_copy.files` と `parts` は49件である（`declarations.md` と `-02`〜`-49`）。また、置き換え前の `audit-summary.json` の指紋は残っていない。監査の結論の欄（件数・公理・対象）と `audit_inputs` は変わっていないので、証拠は崩れていない | 49に直す。置き換え前の `audit-summary.json` の大きさと SHA-256 を一行残す | 読めば確定 |
| 情6 | 情報 | `string_member_program_rejected`・`decimal_representation_program_rejected` | どちらも二つの項の引数で葉を作る。`fieldCandidates` は、String・Decimal の二引数には空列を返すので、拒否の直接の理由は引数の形である。ただし、`fieldCandidates` はどの引数の形でも `member`・`decimalRepresented` の原子を作らないので、全ての引数で拒否されることは定義を読めば確定する。対照の両側の意味は保たれている。署名の形成が通ること、入力の篩を満たす観測があること、Decimal の結論が閉じて偽であることを併せて示しているからである | 必要なら、三引数の形でも拒否されることを一行の `example` で足す | 読めば確定 |
| 情7 | 情報 | `measured_*_program_checked` | `measured` の三つの実入口の例の戻り値の篩は、閉じた具体値の測度の等号であり、取り出しの結果（`var 0`）を含まない。この三例が確かめるのは、葉の実入口での再検査と、`closed` の葉に替えると拒否されることである。Map・Set・Bytes の欄の大きさを射影の結果へ移す流れは、`map_program_checked` などが整数の書き換えと線形の反駁で確かめている。役割は分かれており、どちらの例も意味がある | なし | 読めば確定 |

### 候補の再検査と健全性

新しい登録の種類は `fieldAtom (sort) (constructors)` と `measured` である。証明書は `PreparedLeaf` の `lemma`・`arguments` を持つだけで、既存の `PreparedLeaf.checkRaw` が、葉の述語が `candidates lemma arguments` の要素であることを再検査する。候補の一覧は checker が引数から計算し、証明書の側の主張は信頼しない。

`fieldCandidates s cs args` は、`FieldAtom` の構成子と同じ範囲の原子の組ごとに `implies (and R p) q` と `implies (and R q) p` を作る。範囲は、比較（`FieldRelation.Scalar` の7 sort・6演算・両位置・任意の相手の項）、`charactersIn`、Float の六分類、列に含まれる構成子である。`fieldTransfer_sound_at` は `FieldAtom.bind` と `FieldAtom.sound` から、各候補が任意の ν・η で真であることを示し、`candidates_sound_at` に二つの場合として入る（検査8で言明が任意の ν・η を量化することを確かめた）。

`measuredCandidates a b` は、`sameClosedObservation a b` が真のときだけ全七測度の等号を作る。`sameClosedObservation` は、両項の閉性を `decide` で、成功した部分観測の一致を `observationEq` で検査する。`observationEq` が構造の等号と同値であることは補題で示されている。`sameClosedObservation_sound` は `Entails.measured` と同じ三つの前提を返し、健全性は全域モデルの同じ解釈から閉じる。三条件を一つずつ欠く葉の拒否は `measured_leaves_rejected` にある。検査8では、観測が異なる Map と Set の組に候補が作られないことも確かめた。

既存の12種類の候補、`Certificate` の7構成子、`CertificateKernel` の検査の本文は変わっていない。新しい信頼条件はない。

### 実入口の例

`FieldCheckerExamples` の受理の7例（Decimal・Float64・Float32・String・Map・Set・Bytes）と `measured` の3例は、どれも `checkProgram` と `checkProgramAccepted` の両方の成功を `cbv` で示す。入力は、有限材料から作った取り出しの関数 `Box.value` を呼ぶ本体と、有限の交換の証明書である。Decimal・Float・String の例では、全体の篩の原子（`>= 0`・`charactersIn`）を、`fieldAtom` の葉と反駁で戻り値の篩へ移す。

`field_programs_typed`・`measured_programs_typed` は、同じ成功を `Materials.checkProgramAccepted_empty` に渡す。入力の `Sound` と有限支持は具体的に証明されている。こうして7件と3件のプログラムの `WellTyped` を得ており、受理から型付けまで届いている。公理は許可された三公理の範囲内である（検査8）。

### 記録の置き換え

`audit-summary.json` の `audit_inputs` の7件の SHA-256 は、今の記録のファイルとすべて一致した（読み取りの Python で計算した）。対象は `counterexamples.lean`・`axioms.lean`・`run_check.py`・`scope-input.json`・`generate_certificates.lean`・`certificate-summary.json`・`certificate-candidates.txt` である。

`build-summary.json` と `audit-summary.json` の入力の指紋も一致する。`declarations` の欄は `declarations-summary.json` の指紋に替わり、その指紋は今のファイルと一致する。宣言の件数1,989は、監査の `signature_count` と要約の件数で一致する。写しの全体の大きさと SHA-256 は `full_copy` に残る。`verify-summary.json` の `audit_summary` の指紋は、置き換え後の `audit-summary.json` と一致する。監査の証拠は崩れていない（軽3を除く）。

### 実行した検査

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 8 | `<tmp>/Cert.lean`。`candidates_sound_at`・`sameClosedObservation_sound`・`PreparedLeaf.raw_sound_at` の `#check`、観測の異なる閉じた Map と Set に `measuredCandidates` が空であること、`candidates_sound_at` と例・対照6件の `#print axioms` | 終了0。公理は許可された三公理の範囲内 |
| 9 | 読み取り専用の Python（`-I`）。`audit_inputs` の各ファイル・`declarations-summary.json`・`audit-summary.json` の SHA-256 と、件数・指紋の一致 | 前記のとおり一致 |

Lean は `<repo>/formal/` から、ビルド済みの生成物（`FieldCheckerExamples` は04:15のもの）を import して一つだけ実行した。担当の既定ビルド1,560ジョブ・公理監査114,465宣言・照合の終了0は、保存された報告として読み、本レビューの検査には数えていない。確認用の入力 `Cert.lean` は836バイト（SHA-256 `99ad1bcdb9857ef90e6e168364a16156dae9b971d093a34fc31bc6051e2db314`）である。

## 取りまとめの追記

- 2026-11-07: 初回の中1（移送の経路）は再開2で `Entails.fieldAtom` を、処置の確認の中3（checker の候補）は再開3で `fieldAtom`・`measured` の候補を足して閉じた。R20 への申し送りにはしなかった（一つの機能を後段へ分けないため）。
- 再開3の処置の確認の軽3（写しのファイルの数）は、取りまとめが results.md を直した。情6・情7 は記録だけとする。
- 宣言の型の写し（約4.2 MB）は、取りまとめが件数・指紋・例の名前の要約へ置き換えた（results.md の末尾）。
