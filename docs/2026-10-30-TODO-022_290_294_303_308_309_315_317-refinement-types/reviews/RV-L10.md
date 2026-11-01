# RV-L10 段末の独立レビューの記録

2026-11-01。対象はブランチ `m014/l10.f` の未コミットの作業ツリー、L10 の開始の基準は `c668ff024b99287de702c5823c6280f8130a6aa5`、この群の基準は `f4952052e9474f40ac9a257d260065cf8103cfaf` である。補助の入力は `<tmp>/rvl10f/` に置き、`<repo>/formal` で `lake env lean -M 12288 <入力>` により検査した。リポジトリのファイルは本記録のほかに変えていない。

**判定: 条件付き可。所見は重0、中5、軽6 の計11件である。**

本番の Lean の定義・定理に誤りは見つからなかった。主な十言明は開始の基準と字面まで同じで、公理依存も再実行の出力が SHA-256 まで一致した。条件は受渡しの文書にある。L20 が最初に選ぶ証明の経路を誤らせる記述（中1）、L20 の入力の欠け（中2・中4）、義務の判定の根拠の不在（中3）、見込みの据置きの根拠の不足（中5）である。修正は `l10/f/` の三文書と plan への転記だけで足り、本番の Lean の変更は要らない。

五つの境界（主な定理の前提と結論、公理、提供範囲、利用者の書ける形、精密な外部状態）に触れる所見は軽1だけである。中1は、誤った経路を採ると境界に触れるので、そうしないための修正である。

## 所見

### 中1: Φ の弱化の経路は、禁じた `ValueAssumptions` を要求する

- 箇所: `l10/f/handoff.md`「全導出・状態と宣言本体の完全署名」の「Arms の入口の観測は none、Φ は空であり、必要な強化は既存の事実の弱化で扱う」、同「空の局所文脈」の「ValueAssumptions を新しい独立の埋め込み前提に加えない」。`l10/detail.md` E の「空Φから任意Φへは既存弱化で拡張する」。
- 問題: 既存の弱化 `HasTypeVQ/CQ.weaken_conditions`（`TypingShift.lean`）は `h.shift_values (k := 0)` を経由するので、`Builtins.ValueAssumptions P B` と `store.WF` を要求する。七判断の契約の前提は `K.WF`・`LegacyTables`・入力であり、`ValueAssumptions` を含まない。`LegacyTables.sat` は旧の受理から新の受理への片方向だけで、新の `sat` の改名と値の置換への安定を与えない。一方、`C_If` の両枝は `boolCond t _ :: Φ`、`C_Let`・`V_Lam` は持ち上げた Φ、`plain`・`guarded` の腕は `pathFacts … ++ Φ` の下の判断を要求する。契約の Φ を `[]` に固定して帰納すると、`C_If` の場合の帰納法の仮定（Φ が空）から新の子を作るときに弱化が要る。同じ文書が局所文脈について禁じた経路へ、Φ の側で誘導している。
- 再現: 読めば確定する（`weaken_conditions` の署名）。`[]` の契約の言明が偽だという反例ではない。
- 修正案: 七判断の帰納の結論を任意の Φ で述べる（`∀ Φ`）。旧の導出は Φ を読まず、`embedLe`・`embedCovers` は任意の Γ・Φ で成り立ち、`obs = none` の腕では `FactsWF` が空の列を読むだけなので、追加の前提は要らない。handoff の `[]` の形はその系とする。handoff の上の一文と detail の一文を差し替える。腕の入口の `none` はこのままでよい（`C_Match` の `obs` は規則の添字であり、`none` なら条件が空に成り立つ）。
- 五つの境界: 修正後は触れない。弱化のために `ValueAssumptions` を埋め込みの前提へ足すと、計画が禁じた形になる。

### 中2: `C_Match` の埋め込みに要る旧→新の網羅性が受渡しにない

- 箇所: `l10/f/handoff.md` の契約の表と「支持・近似・表層への接点」のパターンの行。`RV-L10.k`「確かめて問題がなかった重点」の「網羅性は `checkedAt`・`atError` の値について L20 の補題が要る」。
- 問題: 新の `C_Match` は新の `Exhaustive`（正規形・新の `Inhabits`）を要求する。旧の導出が持つのは旧の `Exhaustive` である。新の `Inhabits` は `checkedAtOpaque`・`atError` と旧の像にない値を含むので、全称の範囲が違う。この含意は七判断の埋め込みの一場合であるのに、handoff の網羅性の記述は G09 の型付け→所属と型置換だけを挙げる。`PatTy`・`AltsTy` の旧→新の写しも同じ場所にある。
- 再現: あり。`rv-f-t2.lean`。`.opaque "o" (.rvar 0)` は旧で値がなく、空の腕で `Exhaustive` が空虚に成り立つ（`old_exhaustive`）。同じ型の像は新で `checkedAt` を持ち、空の腕は網羅的でない（`new_not_exhaustive`）。この型は範囲の深さ0の `LegacyTypeInput` が拒む（`input_rejects`）ので、埋め込みの反例ではない。無条件の含意は偽で、節点の適格性の入力を使う必要があることを示す。読む限り、`checkedAt` は旧の `checked`・未使用の番号の opaque 定数へ、`atError` は同じ七つの文字列の `At` 構成子へ読み替えて閉じる見込みである。一般の補題は Lean で確かめていない。
- 修正案: handoff の契約の表へ「`LegacyNodeTypes` の a について、旧 `Exhaustive P0 a ps` から新 `Exhaustive (embedProgramWithKinds K P0) (embedTy a) ps` を示す。`PatTy`/`AltsTy` も写す」の行を足し、担当を G06 か旧埋め込みの行にする。

### 中3: O037・O066・O138 の判定の根拠が handoff に実在しない

- 箇所: `l10/f/results.md` と `transfer.md` の O037「同じ篩付き結果/効果を保つ契約だけを引渡し」、O066「handoffの結果/効果の契約を引渡し」、O138「handoffにΓのlen(l)=n・Φのn>0からの静的合成と、暗黙の動的検査を追加しない契約を記録」。
- 問題: `handoff.md` に「動的」「篩付き」の語はなく、同じ篩付きの結果型・効果を保つ checker/脱糖の契約も、暗黙の実行時検査を足さない契約も書かれていない。七判断の署名が保つのは旧→新の結果型と効果であり、表層の契約ではない。O138 の根拠は値依存長の行の「静的な scrutinee 型の合成は未実装」の半分だけである。三行は C 分類で、この引渡しが L10 の唯一の成果である。元の内容は `l10/x/results.md` の L70/R10b の行にあるが、handoff が引き継ぐのは各群の signatures であり results ではない。`transfer.md` の L70/R10b の行にも二つの契約がない。
- 再現: 読めば確定する。
- 修正案: handoff と transfer の L70/R10b の行へ、detail の「転記」の表の O037・O066・O138 の完了条件（同じ篩付きの結果型と効果、unknown で腕を除かない、暗黙の実行時検査を足さない）を写す。

### 中4: G04 の捕捉からの正則性が受渡しから落ちている

- 箇所: `l10/f/handoff.md`、`transfer.md` の G04 の行、`results.md` の「実績と見込みの比較」。`RV-L10.s2`「G03・G04 の見通し」、`l00b.15/theorems.md` の G04 の行と「全状態への方式の適合は未確定」の段落。
- 問題: RV-L10.s2 は「継続の束縛は `Ty.CaptureWF` が潜在効果の WF を持たないので `Ty.bind_wf` を適用できず `ImageOk` の証拠に頼る。緩い三条件からの全正則性は未確認」と報告した。三文書のどこにも `CaptureWF` と「緩い三条件」がなく、transfer の G04 は kind・ProperApply・Sorted・Declared と旧読者12件だけを挙げる。L10 が閉じたのは閉じた束縛の `close_wf` の試行（レビューの補助入力であり本番にない）までである。theorems.md は同じ点を方式の適合の未確定の一つに数えており、L20 の見込みの幅の主因の一つである。
- 再現: あり。`rv-f-t1.lean`。`k0` は `CaptureWF 0 0 0` を満たし（`capture_accepts`、文脈でも `ctx_capture`）、`WF 0 0 0` を満たさない（`not_wf`）。規則の誤りではない。`CaptureOk` へ強い `Ctx.WF` を足さない判断（theorems.md の G04）の帰結である。
- 修正案: transfer の G04 の行へ「捕捉の三条件から結果の WF/Sorted/Declared。Ordinary の束縛は `Ty.CaptureWF.ordinary` で WF へ戻り、継続の束縛は `ImageOk` から供給する。全正則性は未確認」を足す。`close_wf`・`ground_term` を G04 の入力として写す。

### 中5: 旧導出の全埋め込みに見込みの配分がなく、L20 の据置きの根拠にならない

- 箇所: `l10/f/transfer.md`「見込みと算入先」の L20、G/H の表の「旧埋め込み」の行（「L20の既定枠」）、`results.md` の L20 の行。plan の段の表の L20 の行。
- 問題: 全埋め込みは 46 局所規則の相互帰納、全状態の `LegacyStateInput` の定義と `embedStateTyE`、k=0 の局所文脈、宣言の三親判断を含む大きな証明である。`l00b.15/theorems.md` の G01〜G09 の表（「L20 の同じ枠」の注の列挙を含む）にこの行はない。detail の G08 の「全宣言の充足/埋め込み」の 1〜3 時間は宣言の分として書かれ、46 規則の全導出の時間ではない。したがって「既定枠」は指す先がない。さらに plan の L20 の完了条件の文にも全埋め込みがない。O042 の担当は L10/L20 であり、L10 の行の「埋め込み」を detail が絞った結果、残りの完了条件の置き場所が plan にない。L20 の据置きの根拠は「G03 の像の Ordinary の供給がそろった」という減る側の材料だけを挙げ、増える側（本件、中2、中4、入れ子の継続の確認）を数値へ反映していない。
- 再現: 読めば確定する。
- 修正案: 取りまとめが全埋め込みの行を G 表へ足し、能動時間の見込みと L20 の枠に収まるかの判断を設計者へ示す。実績がないので根拠は規則の数とし、不明なら不明と書く。plan の L20 の完了条件へ「適格な旧導出の七判断と状態の片方向の埋め込み」を足す。上端を超える場合は既存の相談の条件に従う。

### 軽1: 新の `OpDecl.Scoped` の辞書の先頭の一致に供給元がない（主な定理の前提の中身に触れる）

- 箇所: `ProgramWellFormed.lean` の `OpDecl.Scoped`、`LegacyInput.lean` の `LegacyDeclarationsInput`、`l10/f/handoff.md` の宣言の節、transfer の G08 の行。
- 問題: RV-L10.w 軽2 の処置で `od.params.take … = dictParams の辞書型` を `Program.WellFormed` の内容へ足した。旧の `OpDecl.Scoped` はこの条件も辞書の添字の範囲も読まず、`LegacyDeclarationsInput` と `LegacyTables` にもない。旧の `WellFormed` から新の `WellFormed` を作るときの入力が足りない。handoff は `SourceScoped` の供給だけを名指しする。
- 再現: あり。`rv-f-t3.lean` の `new_rejects`。辞書を宣言し先頭が Unit の旧の操作の像は新の `OpDecl.Scoped` を満たさない。旧の条件を満たす全ての実プログラムで問題になるとは言っていない。
- 境界: `Program.WellFormed` は新の主定理の前提である。強まるのは宣言の形の条件で、plan の判断の行に名指しがない。RV-L10.w の処置の記録にはある。
- 修正案: G08 の入力へ操作の辞書の先頭と添字の条件を足す。設計者の見直しの一覧へ、`ImplDecl.Scoped` の辞書型の kind とともに載せる。

### 軽2: 群の申し送りの残りの取りこぼし

- 箇所: `l10/f/handoff.md`・`transfer.md`。
- 問題: 次の二件が移っていない。(1) `l10/v/results.md` の L30/L40 の行「`Declared` だけでは欄の sort を元へ反映できず、検証済みの表の `VarianceValid` を観測の準備の証明で用いる」（`rv-v-t4.lean` の `sort_reflect_aux`）。(2) `l10/s1/results.md` の L70 の行「旧 `Surface/FiniteTools` の `union_support` 等の効果を構成する補助の移植」。
- 再現: 読めば確定する。
- 修正案: 接点の表の該当の行へ足す。

### 軽3: 「局所文脈の37署名」の語が実際の一覧と合わない

- 箇所: `l10/f/handoff.md`「kind・表・入力・葉・非継続・局所文脈の37署名」。
- 問題: `handoff.lean` の 37 件の `#check` に局所文脈の宣言はない。`LocalCtx.Shift.empty` は本番にあるが署名を印字していない。
- 再現: 読めば確定する。
- 修正案: 語を削るか、`LocalCtx.Shift.empty` を一覧へ足す。

### 軽4: O118 の段の判定が今回の差分だけを述べる

- 箇所: `l10/f/results.md`「全段共通の plan の行」の O118。
- 問題: 段全体の Lean の追加行に工程 ID は0件である（確認済み）。ただし `formal/Benitoite` の既存の行に工程 ID が 324 行残り、L10 が変更した `Surface/ScopeState.lean` にも 2 行ある（`L40.3c`、`L00.08`）。O118 の状態は「各L段: コメント未実施」なので、L10 の段の判定を読み取れない。Refinement・Shared と Interval の変更ファイルには0件である。
- 再現: `grep` で確認した。数は `L\d\d`・`L\d\d.\d`・`RV-` の行である。
- 修正案: 転記に「L10: 追加0、既存の除去は未実施（残りの担当を明記）」と書く。

### 軽5: O015 の「対応表」が sort ごとの表になっていない

- 箇所: `l10/detail.md` の O015、`l10/v/results.md` の提供表、`l10/f/results.md` の O015。
- 問題: detail の判定は全 sort・measure・`member`/`constructorIs`/Boolean の WF/Sorted/Source/意味の対応表である。提供表は領域ごとの定義の列挙で、各 sort の四欄の表ではない。定義自体は存在し（`Sort`、`Ty.sort?`、`Term.HasSort`、`Pred.Sorted`、`Term.Source`）、欠けは読めなかった。
- 再現: 読めば確定する。
- 修正案: 判定の文を「定義の実在を確認」に改めるか、L30 の入力として四欄の表を起こす。

### 軽6: 見直しの一覧に載らない定義の追加がある

- 箇所: plan の 2026-11-01 の判断の行、`Patterns.lean` の `P_Convert`、`Declared.lean` の `Term.HasData.widen`。
- 問題: どちらも群のレビューで妥当と判定され、01-12 と 07-04 に写してある。五つの境界に触れない判断も群の取りまとめの追記にある。ただし plan の判断の行にも detail の注記にもなく、detail の 10 規則・`assume`・`use` の nv+1 の差の注記も未転記である。
- 再現: 読めば確定する。
- 修正案: 転記のときに detail へ差の注記を足す。

## 完了条件の判定

| 項目 | 判定 | 実際に確かめた証拠 |
|---|---|---|
| 外部呼出しの構文 | 満たす | `ExternalTypeDecl`・`ExternalSignature`・`Val.externalRef`・`externalHandle`・`Comp.externalCall`、`Program.ExternalWF`。全て実在 |
| 外部呼出しの遷移 | 満たす | `E_ExternalApply/E_External/E_ExternalErr`、`step`、受信の葉。Semantics・Step は L10 で無変更 |
| σ | 満たす | `PathEnv`、`Required/Ready/InitialPrepared`。静的な判断へ σ を足した差分なし。`Eff.Allows` だけが σ を読む |
| 範囲付き値 | 満たす | `V_Checked/V_CheckedRequest/V_CheckedAt` を読んだ。同じ要求全体・端点・`groundVal` を保つ |
| 状態の判断の全構成子 | 満たす | `StateTyE/StateTy/ContTy/CellOk/StoreOk`。L10 の変更は `K_Sub` の P だけ |
| shift | 満たす | `shift_values`・`shift_types`。十言明が基準と同じ。公理依存を確認 |
| subst・Covers・V_Sub/C_Sub | 満たす | `subst`・`subst_under_none`・`narrow`・`Covers`/`Sub` の補題 |
| 埋め込み | 条件付きで満たす | L10 の割当て（kind 表、入力、46 規則の記録、四葉と opaque の二葉、`embedLe`/`embedCovers`、限定等号）は実在する。全導出を L20 へ送ることは O042 の担当と plan の「detail を正とする」判断が許す。旧 Val の全構成子は `embedVal` で写る。ただし送り先の完了条件と見込みが未定である（中5） |
| 既定ビルド | 満たす | `lake build` 774 ジョブ、終了0を再確認。`Benitoite.lean` の差分は追加だけ、lakefile は無変更 |
| 幅/Byte/Decimal/Top/Request と 07-04 | 満たす | 下の節 |
| 二つの改名 | 満たす | `checkLimit` を `admit` へ戻すと基準の二ファイルと完全に一致。Lean と設計書の旧名0件、Rust は不変 |
| 公理依存 | 満たす | `l10/axioms.lean` を再実行し、大きさ 2,109,143 バイト・SHA-256 `c1a1dbb2…` が記録と一致。20,065 印字、依存は三公理だけ、`sorryAx` 0 件 |

## 義務の確認（37行と全段の2行）

分類は A12/B16/C6/D1/E2 で detail と一致する。根拠の宣言は名前と所在のファイルを機械で照合した（実在しないもの0件。`LegacyStateInput`・`embedStep`・`LegacyRuntimeRelation` は未定義と文書が明記する名前である）。

| 義務 | 判定 | 確認の内容 |
|---|---|---|
| O011 | 可 | `ConstOK` 全枝と `V_Bytes`、`embed_const`/`embed_bytes`、14 端点を読んだ。01-12・07-04・Syntax が一致 |
| O013 | 可 | `ShapeOk` の `.single` は `.opaque o (.rvar 0)` を読み `valKind o = some k` を要求する。`scoped_forget` で渡す記述は正しい。本体は L50 |
| O015 | 可（軽5） | 定義は実在。表の形だけ不足 |
| O035 | 可 | `V_CheckedRequest` の前提を読んだ。`inv_checkedRequest`・`checkedRequest_widen` は HeldValues に実在 |
| O042 | 可（中5） | 葉と既定 import は成立。全導出の配分が未定 |
| O044 | 可 | 07-04・Syntax とも旧の抽象化の変更と書き、欠陥の修正ではないと明記 |
| O049 | 可 | `LegacyHeldTypeInput`、`LegacyValueInput` の保持要求の枝、`embed_checkedRequest`。内容の新型付けは葉の前提のまま |
| O050 | 可 | `Ty.sort?` は fn・reference・opaque へ none を返す。三値評価の扱いは L00b・X の証拠を継承 |
| O065 | 可（中2・軽1） | 表の欄は片方向で、handoff の写しは本番と一致。宣言の入力に不足あり |
| O076 | 可 | 旧対象外の行を「Release では対象外」へ改め、Refinement の行を分けた。旧 shapeAt の決定は節の冒頭が Release に限る |
| O087 | 可 | 宣言表と `ExternalWF` は実在。実表は L60/R50 |
| O116 | 可 | 上記の改名の照合 |
| O124 | 可 | `integer_endpoints`・`integer_endpoint_entry` は群 A の境界に実在 |
| O125 | 可 | Byte の 255/256、`.base .byte` は `Ty.sort?` で integer。七幅と同じ |
| O126 | 可 | `Const.character`、`Term.character`、`characterCode` |
| O127 | 可 | `Pred.charactersIn` |
| O128 | 可 | `Const.float64/float32`、sort は float64/float32 で integer と別 |
| O129 | 可 | `decimal_bounds`・`non_integer_other` が群 A の境界に実在。`ConstOK` の両端と scale を読んだ |
| O130 | 可 | `Measure.stringBytes/stringCharacters` |
| O131 | 可 | `Measure.listLength`、`length_refinement_coverage` |
| O132 | 可 | `Measure.bytesLength`、`V_Bytes` の別条件 |
| O133 | 可 | `Measure.mapSize`、変性の検証で Map 鍵は不変 |
| O134 | 可 | `Measure.setSize`、Set は不変 |
| O135 | 可 | `FieldRef.Declared`、`variance_field_mono`、TypeFormation |
| O144 | 可 | 正規化の定義と `empty_refinement_exhaustive`。一般 UF 等の追加なし |
| O159 | 可 | `Def/ImplDecl/Program.WellTyped`・`Program.WellFormed` を読んだ。Q は代入前の `QTel ms.tel` |
| O160 | 可 | 16+43+31+68=158、115 件の対応先の解決、missing 0。名前の存在の確認に限る記述も正しい。A_17 の未取得は群の時刻の記録が概数を含むので妥当 |
| O167 | 可 | DET-L の表は 31 行。`unused` なし |
| O169 | 可 | `possible_iff`・`not_possible_iff`・`normalToShared_iff`・`baseToShared_mem`・`Report.shared_normal`。returned/failed は未完と明記 |
| O005 | 可 | `Ty.LeQ.dataCore`・`variance_field_mono`・`Program.WellTyped.variance` |
| O033 | 可 | 収集の完全性を Lean の外と 07-04 の表に明記 |
| O016 | 可 | 監査対象は Refinement 190・Shared 3 の全ファイルと Interval 3・Surface 1 で、変更したモジュールに漏れなし。旧五主定理と旧三モデルを明示 |
| O084 | 可 | 全比較・主定理を達成済みと書いていない |
| O037 | **不足（中3）** | 根拠の契約が handoff にない |
| O066 | **不足（中3）** | 同上 |
| O079 | 可 | `month_exhaustive`・`nonempty_exhaustive`・`CaptureOk.variable_coverage`。unknown を除かない |
| O138 | **不足（中3）** | 動的検査を足さない契約が handoff にない |
| O027 | 未了 | RSS は取りまとめの最後の work の担当 |
| O118 | 一部（軽4） | 段の追加は0、既存は未処置 |

## 受渡しの突き合わせ

| 申し送り | 所在 | 判定 |
|---|---|---|
| G03: 捕捉・複数引数・全本体・tapp・入れ子の継続 | transfer G03・handoff 非継続の節 | あり |
| G03: `Exhaustive` の型置換 | handoff・transfer | あり |
| G04: 形成の全移送・旧読者12件 | transfer G04 | あり。捕捉の正則性は中4 |
| G06: パターン束縛 `v : a.norm` → `δ.map Ty.norm` | handoff・transfer | あり |
| G07: `fnViewWith?` の前提なし版の判断、支持不足 | handoff・transfer | あり |
| G08: `sig_scoped`、SourceScoped、三親判断 | handoff・transfer | あり。操作の辞書は軽1 |
| G09: 型付け→意味→所属、`valueMeaning_sub` | handoff・transfer・x/signatures | あり |
| 空の局所文脈 k=0 | handoff | あり。Φ の側は中1 |
| 非継続の二読者、旧読者12件、別枠2件 | handoff | あり。detail と一致 |
| embedStep の撤回 | handoff | あり |
| constOK の値の一致、J04、mayFail | handoff・transfer | あり |
| 符号の桁数、L70 の支持不変量 | handoff・transfer | あり。`union_support` は軽2 |
| 公開境界の行変数 | handoff・transfer | あり |
| 署名の写し | LegacyTables・契約8件を機械で比較 | `handoff.md` のコードは `handoff.lean` と一致。型検査の再実行は記録と同じ |

`declarationBodyInputs` の C/Q/Γ/R/効果/κ は旧 `Def.WellTyped`・`ImplDecl.WellTyped` と一致し、メソッドの Q は代入前である。`LegacyDeclarationsInput` で導出全体を代用しておらず、`LegacyStateInput` が未定義であることも明記している。

## 07-04・01-12

- 幅・Byte・Decimal・bytes・Top・Request の記述は `ConstOK`・`V_Bytes`・`V_Checked`・`V_CheckedRequest` に一致する。数値の端点も一致する。旧の欠陥とは書いていない。
- 工程 ID は段全体の追加行に0件である。「残る」の一件は全称条件の説明であり、未実施の予告ではない。
- 段全体の継ぎ目: `Ty.LeQ` の旧形の残り0件、`Program.WellTyped` 未定義という古い記述は置換済み、新三節は位置付けの文の範囲（「篩を含むコア計算の形式化」から「篩を含む状態の型付け」）の内にある。用語集のリンク先の見出しは実在する。段で新設した35モジュールは全て 07-04 に載る。
- `V_CheckedAt` は「対象を保持する」規則の説明に現れないが、別の節が扱うので所見にしない。

## 主な定理と五つの境界

- 主な十言明（値移動・型移動・値置換・None の下の値置換・narrowing の V/C）の宣言の全文は開始の基準と同じである（`P` は暗黙の変数）。旧 Release は L10 で無変更である。
- 消えた宣言は `admit` 系の改名と、RV-L10.x が確認した `Inhabits.of_core`・`of_subst_values_core` だけである。
- 定義の変更は、P 付きの部分型、`Inhabits`/`PatTy`/`Exhaustive`、`TypeArgsKinded`/`V_Raise` の Ordinary、メソッドの Q、`dataInfo`、`Term.HasData.widen` である。承認の記録がないのは軽1・軽6 の項目で、公理・提供範囲・利用者の書ける形・精密な外部状態の変更はない。`Semantics`・`Step`・`ConstraintAssumptions` は無変更である。

## 見込み

実績の和（216+111=327 分、レビュー 102 分）は台帳の行と一致する。外側の時間であり、29〜61 時間との比を他段へ掛けない判断は正しい。L40・L70 の据置きの根拠は妥当である。L20 は中4・中5 のとおり根拠が足りない。G03 の Ordinary は供給元が閉じたので、見込みを増やす発見ではない。

## 補助の入力

`<tmp>/rvl10f/` に置いた。三件とも終了0、`sorry` なし、公理は `propext`・`Quot.sound`・`Classical.choice` だけである。

| ファイル | 内容 |
|---|---|
| `rv-f-t1.lean` | CaptureWF を満たし WF を満たさない継続の型 |
| `rv-f-t2.lean` | 旧と新の網羅性の差と、旧入力による拒否 |
| `rv-f-t3.lean` | 操作の辞書の先頭の条件 |

## 実行していないもの

work と RSS、Rust の全 lib、Rust と Lean の全比較は実行していない。七判断の全埋め込みと旧→新の網羅性の一般の補題は証明していない。全 37 行の可は L10 の担当分の判定であり、義務全体の閉鎖ではない。

## 設計者へ示す点

- L20 の見込みに全埋め込みの配分がない（中5）。行を足して枠に収まるかを判断する必要がある。
- 捕捉からの正則性（中4）は、L20 の方式の適合の未確定の点として残っている。
- `Program.WellFormed` の操作の辞書と実装の辞書型の kind は、主な定理の前提の中身の追加である（軽1）。

## 取りまとめの追記

2026-11-01。補助の入力は `l10/f/rv-f-t1.lean`〜`t3.lean` へ写した。中1〜5 と軽1〜6 を文書と入力の修正で処置する。本番の定理は変えない。軽1は `plan.md` の先頭の判断のとおり明示する。全体の再レビューは置かず、修正箇所を取りまとめが確認する。
