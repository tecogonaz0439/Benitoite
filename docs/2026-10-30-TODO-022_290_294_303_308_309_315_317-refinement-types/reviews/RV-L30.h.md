# RV-L30.h: 形式化の群 L30 H・I（L30.43〜.54）の独立レビュー

対象: `m014/l30.h` の未コミットの作業木（基準 `82a7f626`）。既存の変更23ファイルの差分の全件（Context・Context/Facts・ContextFacts・ValueMeaning・TypedMeaning・Le・CarrierFacts・TypedFacts は全文の該当部も読んだ）、新規の `CarrierFactsExamples.lean`・`NumericRepresented.lean` の全文、`Typing.lean` の `CaptureOk`・`ImageOk`、`Le.lean` の全規則、`Context/Facts.lean` の `Capture.facts_extend`、`SubstitutionContracts.lean` の `SubstOk`、`Transport.lean` の `Transport`、01-12・07-04・effort-ledger の差分、`l30/h/` の記録。基準: plan の「計画の変更と取りまとめへの確認点」の 2026-11-03 の J30-2 の項と「全 L 作業の停止条件」、`l30/detail.md` の第1節「入口で判明した不足」、第2節 S01、第5節、第6節の群 H・I と L30.43〜.54 の行、第10節の J30-2、`l30/a/signatures.md`、RV-L30-plan の重1・軽1、RV-L30.a の軽8、decisions.md の D02・D21。2026-11-03。担当の報告と依頼文は読んだが判定の根拠にしていない。git の操作、既存のファイルの変更、`lake build` はしていない。監査の台本 `audit.py` は改造内の `audit-summary.json` を、`inputs.py` は `inputs.json` を書き換えるので使わず、`audit.lean` を `lake env lean -M 12288` で直接実行して出力を `<tmp>` に置き、入力のハッシュは読み取りだけの Python で照合した。

## 総合判定

**可**（重0・中0・軽3、ほかに情報5）。軽はいずれも記録または名前の整理で済み、再レビューは要らない。

`Ty.assume` は `match a.core with | .cont _ _ _ => [] | _ => a.carrierFacts ++ a.refinementPredicates` になり、RV-L30-plan 軽1 の match の形を保つ。`Ctx.facts` は定義の本文を変えずにこの列を読む。`ValueMeaning.mk` は芯の形・明示した篩の真・`a.carrierFacts` の真の三条件になり、`ValueShapeMeaning` の構成子は変わらない。型域は七整数型と Byte の上下限、Decimal の `decimalRepresented self` で、`ConstOK`・`Const.NumericRepresented` の値域と一致する（補助入力で逆向きも証明した）。主な十移送の4ファイル、`Typing.lean`・`Basic.lean`、捕捉を直接・間接に構成する全ファイル、旧 Release の全ソースは基準から差分がない。公理監査の再実行は担当の記録と同じ 25,520宣言・同じ SHA-256 を再現した。

## 所見の分類

| 分類 | 所見 |
|---|---|
| 読めば確定する誤り・欠け | 軽1、軽2、軽3 |
| Lean で確かめた事実に基づく指摘・確認 | 観点2・3・5（`carrier_meaning_represented`・`carrier_from_image`・`no_typed_1000` ほかを証明）、軽3 |
| 実行しないと分からない推測 | 情報4 の成果物の時刻の解釈（Lake の内容のハッシュによる判断の推定） |

## J30-2 の約束の判定

| 約束 | 判定 | 根拠 |
|---|---|---|
| 主な定理の言明の形（量化と結論）を変えない | **守られた** | 主な十移送（`HasTypeVQ/CQ` の `subst`・`subst_under_none`・`shift_values`・`shift_types`・`narrow`）を置く SubstTyping・TypingShift・TypeShiftTyping・Narrowing、型付けの規則の `Typing.lean`、`Entails.bind` の `Basic.lean` は `git diff 82a7f626` が空である。旧 Release の主定理（progress・preservation など）を含む `formal/Benitoite/Release/` の Refinement 以外は差分がない。`typed_value_meaning_closed`（TypedMeaning 176行）、`valueMeaning_sub`（MeaningTransport 202行）、`close_value_typed`（CloseTyping、差分なし）は差分の hunk の外で、本文も変わっていない。補助入力の `#check` で、各型が基準の本文どおりであることを確かめた。言明の文字列を変えた公開の宣言は `const_meaning`（`c.NumericRepresented` の追加）と例の `context_facts` 二件だけで、どちらも S01 と detail の予定どおりである |
| 受理を減らさない（書ける形を狭めない） | **守られた** | `Ctx.facts` は型付けの規則の中で、`Ty.LeQ.introduce`・`refine` の `assumptions` と `V_Refine` の `Entails (Γ.facts ++ Φ) …` に仮定としてだけ現れる（`Typing.lean`・`Le.lean` の全規則を読んだ。`Eff.Covers` は Γ・Φ を読まない）。仮定が増えるだけなので、既存の導出はそのまま成り立つ。義務の側に現れるのは `CaptureOk.mk` の最後の欄だけで、補助入力の `carrier_from_image` で、その欄の型域の部分が同じ構成子の `ImageOk` の欄から導けることを証明した。したがって `CaptureOk` の成り立つ範囲は変わらない。`SubstOk` は `ImageOk` だけの定義で、事実の欄を持たない |
| L20 で閉じた `CaptureOk` の構成に前提を足さない | **守られた** | detail 第5節の直接12構成（Typing・Context/Capture・ContextTransport・TypeSubstTyping・CaptureTransport・CapturedFacts・ClosureApply・DependentBeta・HandlerGeneral・TypingShift）と間接の構成・供給（CaptureApplicationAlgebra・MatchPaths・MatchStateLeaves・SuperClosure・CaptureReadBoundary・ReferenceStore ほか）を置くファイルは、いずれも基準から差分がない。新しい事実は `Capture.facts_extend` が既存の `HasTypeVQ.assume_optional` と `Ty.assume_bind` から作り、両者の言明は変わらず、証明だけが V_Const の枝で `ConstOK.represented` を読むように直った。「追加前提0」は差分の上で機械的に成り立つ |

## 所見

### 軽1: 並置名の補題が旧名と二重に残っている（読めば確定）

- 箇所: `CarrierFacts.lean`（`Ty.assumeWithCarrier_eq_carrier_append`・`_norm`・`_refined`・`_of_wf`）、`ContextFacts.lean`（`Ty.assumeWithCarrier_shiftV`・`Ctx.mem_factsWithCarrier_extend`・`Ctx.mem_factsWithCarrier`・`Ctx.mem_factsWithCarrier_extendNone`）、`ContextNormEq.lean`（`Ctx.factsWithCarrier_map_norm`・`Ctx.NormEq.factsWithCarrier`）、`Le.lean`（`Ty.LeQ.assumeWithCarrier`・`abbrev assumptionsWithCarrier`）、`NormalizationLogic.lean`（`Ty.assumeWithCarrier_of_norm_eq`）、`Transport.lean`（`Ty.assumeWithCarrier_bind`・`assumptionsWithCarrier_bind`）、`RangeSubst.lean`・`TypeShiftContracts.lean`（`_rawMapRanges`・`_shiftTypes`）、`NormalWellFormed.lean`（`Ty.assume_of_wf`）。
- 問題: `Ty.assumeWithCarrier`・`Ctx.factsWithCarrier`・`assumptionsWithCarrier` は `abbrev` で同じ定義になり、二つの判断は残っていない（detail の「二つの判断を提供し続けない」は満たす）。ただし、約16組の補題が「旧名 := 新名」または「新名 := 旧名」の一行の別名として両方残り、本体の証明が新名の側にある組が多い。`Ty.LeQ.assumeWithCarrier` は言明を `b.assume` で書くので、名前と言明の語が食い違う。新名の補題の多くは、別名の定義と自身の定義の2か所にしか現れない（字句の出現数で確かめた）。`Ty.assume_of_wf` と `Ty.assumeWithCarrier_of_wf` は同じ言明である。基準の `LogicKernelExamples` と 01-12 が `Ty.assumeWithCarrier`・`Ctx.factsWithCarrier` の名前を使うので、`abbrev` 自体は残す理由がある。
- 修正案: 補題は旧名（`Ty.assume_*`・`Ctx.mem_facts*`・`Ty.LeQ.assume`・`Transport.assumptions`）に本体を戻し、新名の補題は例が使う `Ctx.mem_factsWithCarrier*`・`Ty.entails_assumeWithCarrier_iff` などに限る。後の群で整理するなら、results.md の「並置と切替」に「補題の別名を残した。後の群で整理する」と書く。健全性には影響しない。

### 軽2: 具体例の宣言表の `VarianceValid` を本番で示していない（Lean で確認）

- 箇所: results.md「具体の受理と拒否」の「Pは空の宣言表でVarianceValidを満たせる形」。`CarrierFactsExamples.lean` の `private def P`。
- 問題: 例のファイルは `P.VarianceValid` を証明しておらず、`closed_integer8_carrier` は `VarianceValid` を要しない `carrierFacts_meaning_closed` を使う。このため、例は主定理の入口 `typed_value_meaning_closed` を同じ P・B で読んでいない。記録の主張は Lean の上で確かめられていない。
- 確認: 補助入力で、同じ形の P' について `valid'`（`VarianceValid`）、`typed127`（127 を V_Sub で `upperType` へ）、`meaning127`（`typed_value_meaning_closed` の適用）、`no_typed_1000`（任意の B・Ψ で、生の `Integer8(1000)` の閉じた型付けがないこと。`typed_value_meaning_closed` と `raw_1000_not_meaning` の合成）を証明した。主張は正しい。
- 修正案: `CarrierFactsExamples` に `valid` と、`typed_value_meaning_closed` を `closed_integer8_upper` に当てはめる例を加える。型付けの拒否を直接示す `no_typed_1000` の形も加えると、新しい意味の拒否が型付けの拒否として読める。加えないなら results.md の該当の一文を「同じ形の表は他の例で `VarianceValid` を示した」と限定する。

### 軽3: 記録の「八整数型」と義務 O127 の判定の書き方（読めば確定）

- 箇所: results.md の L30.43 の行（「八整数型の16端点」）、義務 O137 の行（「八整数型とDecimal」）、O127 の行（「担当分完了」）。
- 問題: Lean と 01-12 は「七整数型と Byte」と書き、Byte を整数型に数えない。件数（8型・16端点）は正しいが、語が設計書と食い違う。O127 は detail 第7節で単位 49 が「charactersIn の有限区間包含と型付き入力の対応」を担当すると書くが、今回の差分は charactersIn に触れておらず、根拠は既存の `HasTypeVQ.assume` が明示した篩を供給し続けることだけである。「担当分完了」は、新しい証拠のない保持を完了と数えている。
- 修正案: 「七整数型と Byte の16端点」に直す。O127 は「今回の変更なし。既存の `HasTypeVQ.assume` が明示した charactersIn を保持することを既定ビルドで確認」と書き、完了の扱いは取りまとめが決める。

## 情報1: `valueMeaning_sub` の前提が意味の上で強くなった

`valueMeaning_sub` の `facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true` は、言明の文字列は同じだが、開いた Γ では型域の真も要求するようになった。部分型の導出が Γ の型域を仮定に使えるようになったので、この強化は健全性に必要である。本番の呼び手は `typed_meaning_aux` と `TypedMeaningExamples` の二つで、どちらも Γ = [] なので影響はない。01-12 の「文脈の事実と経路条件の真」は今の定義のままで正しい。

## 情報2: `Transport` の事実の欄は型域の移送も要求する

`Transport.facts` は `Γ.facts ++ Φ` の像を要求するので、型域も移送する必要がある。主な十移送では像が値（`Val.toTerm?`）で、型付きの像から型域が得られるので影響はない。`OpenSubstitution` のように値でない項（`var 2 + 1`）を像にすると、像の上下限は元の上下限だけからは導けず、経路の等式 `var 2 + 1 = 7` からの `EqProof.substitute_entails` で閉じている。この閉じ方は健全で、型域を独立の仮定にしていない。後の群で算術の項を像にする移送を作るときは、この追加の義務がある。

## 情報3: Character・Float は型域を持たない

D02 は Character と Float の値域も挙げるが、S01 の型域は七整数型・Byte・Decimal だけで、Character・Float・Float32・String・Boolean の芯は空列である（補助入力で `rfl` により確かめた）。Lean の `Char` は Unicode のスカラー値の証拠を持つので、Character の型域を述語で足さなくても表現可能性との食い違いはない。D21 の表現可能性の範囲（幅付き整数・Byte・Decimal）とは一致する。

## 情報4: 二つのソースの更新時刻が成果物より新しい

`Context.lean` と `NumericRepresented.lean` の更新時刻（10:18:30）は、それぞれの olean（10:17:39・10:17:40）より新しい。最後の既定ビルド（記録では 10:31〜10:33 の範囲、終了0）がこの二つを作り直していないので、Lake の追跡の内容のハッシュは一致しており、時刻だけの更新と推定する（推測）。二つのファイルを単独で `lake env lean -M 12288` にかけ、終了0・誤り0を確かめた。ほかの変更ファイルと新規2本は olean より古い。依頼に反した対象指定の `lake build`（終了1）は、その後の既定ビルドと監査の再現から、最終の状態に影響していない。

## 情報5: 型域の拒否の対照は事実列の比較である

`explicit_width_upper_unprovable` は、変更前の `Ctx.facts` と同じ形の `explicitFacts` を例の中で定義し直して比べる。`widthCtx` では両者とも空列なので、内容は「空の仮定から `x ≤ 127` を導けない」である。変更前の `Ty.LeQ` が導けなかったことの直接の証明ではないが、`introduce` の前提が `Entails (assumptions …)` だけなので、対照として十分である。

## 観点ごとの確認

| 観点 | 確認の結果 |
|---|---|
| 1. 言明の形と公開署名 | 上の「J30-2 の約束の判定」の一行目。補助入力の `#check` で `Entails.bind`（`Entails Ξ p → ∀ σ, Entails (Ξ.map (predBind σ)) (predBind σ p)`）、`typed_value_meaning_closed`、`valueMeaning_sub`、`close_value_typed`、`HasTypeVQ.subst`・`narrow`、`Ty.LeQ.introduce`・`refine` の型を確かめた。型付けの構成子は `Typing.lean` に差分がない |
| 2. 切替後の定義 | `Ty.assume` は match の形で継続を除き（RV-L30-plan 軽1）、`(cont).assume = []`・`(refined cont p).assume = []` を `rfl` で確かめた。`Ty.carrierFacts` の端点は `ConstOK` と同じで、Decimal の `decimalRepresented` の評価 `c.natAbs < 2^96 ∧ s ≤ 28` は `NumericRepresented` の `±79228162514264337593543950335`・`scale ≤ 28` と同値である。補助入力の `carrier_meaning_represented` で、全定数について「型域の全述語の真 → `NumericRepresented`」を証明した（逆向きは既存の `Const.NumericRepresented.carrierFacts`）。`ValueMeaning.mk` の第三条件は S01 の候補の形どおりで、`carrierFacts_norm` により正規形でも同じ列である。受理を減らさないことは上の判定の二行目 |
| 3. 捕捉と事実の供給元 | 捕捉の全構成のファイルに差分はない。新しい事実の供給は `ConstOK.represented`（V_Const の既存の前提）→ `Const.NumericRepresented.assume`（Entails の `integer_le` と、Decimal は `Entails.closed` の閉じた評価）→ `HasTypeVQ.assume`/`assume_optional` → `Capture.facts_extend` で、`ValueMeaning` を経由しないので循環しない。意味の側は `ValueMeaning.assume`（第一・第三条件の和）と `carrierFacts_meaning_closed`（型付き値の観測と `refine_bridge`）で、どちらも健全性の補題 `Entails.sound` だけを使う。V_Sub の枝は `valueMeaning_sub` が行き先の型域を `Ty.LeQ.assume` 経由で供給する |
| 4. 在庫の外の読者と簡約に頼る証明 | 壊れた読者の修正は、OpenSubstitution と SubstTypingObstruction の `context_facts`（事実列の言明を新しい列に改めた）と、仮定の先頭を位置で読んでいた `.hyp`/`List.mem_cons_self` を `simp [integerBounds]` へ替えたものである。`transport`・`source_le`・妨げの主張の言明は変わっていない。OpenSubstitution の上下限は情報2。MeaningTransportObstruction・CoverageRefinement・MeaningTransport の変更は第三条件の追加と `ValueMeaning.assume` への置換だけである。基準でこれらは `facts|assume` の広い検索に一致しており、在庫の外の新しい読者が0という主張と矛盾しない。名前の整理は軽1 |
| 5. 具体例 | `integer8_upper_sub` は任意の P・Γ・Φ で `Integer8` から `Integer8{self <= 127}` への `introduce` を型域だけから作り、`typed_integer8_upper` は実際の `V_Sub` へ渡す。`closed_integer8_upper` と `captured_decimal` は同じ P・B を使う。`Ctx.extend [] (.base .decimal)` の事実は `[decimalRepresented (var 0)]` で空でないことを `rfl` で確かめ、その欄は `NumericRepresented.assume` の Decimal の枝（閉じた評価）で閉じるので、捕捉は自明でない。`raw_1000_not_meaning` に加え、補助入力で `upperType` に対する生の 128 の意味の否定（`raw_128_not_upper`）と、型付けの拒否 `no_typed_1000` を証明した。`width_128_unprovable` は x=127 のモデルで、型域が上限を広げないことを示す。対照の弱さは情報5、`VarianceValid` は軽2 |
| 6. 公理・写し・記録 | 追加行と新規2本に `sorry`・`native_decide`・`axiom`・`admit`・`implemented_by`・`extern`・`unsafe`・`set_option`・`#eval` はない（`V_ExternalHandle` の語の一致だけ）。`formal/Benitoite.lean` は `CarrierFactsExamples` の import を一行足しただけで、除外はない。`NumericRepresented`・`ExternalObservation`・`CarrierFactsExamples` は既定の import に入る（監査の出力の AUDIT_MODULE で確認、350モジュール）。`audit.lean` の再実行は終了0、約32秒、最大常駐量 1,852,850,176 バイト、25,520宣言、`axioms.log`（5,001,554バイト）と `audit-targets.txt`（1,788,346バイト）の SHA-256 が記録と一致し、公理は propext・Quot.sound・Classical.choice の部分集合だけ、`error:` は0。`inputs.json` の34入力と全684ソースの一覧の SHA-256 も現在の作業木と一致した。`NumericRepresented` の定義は ExternalObservation から削除した本文と同じである。01-12・07-04 の写しは三条件・`assume = carrierFacts ++ refinementPredicates`・略記の扱いを実物どおりに書き、経緯の文を含まない。旧い「明示した篩だけを読む」の記述は残っていない。`l30/h/` の各ファイルは41 KB 以下で、手元の絶対パス・docs/todo へのリンク・`work/` の参照はない。対象指定の `lake build` の影響は情報4 |
| 7. 35義務 | 「完了」の行は担当分に限って書かれている。O137・O022・O016・O021・O084・O027・O118 の判定は差分と監査の再現で支えられる。O127 の書き方は軽3。過大な主張はほかにない |

## 補助入力

`<tmp>/rv-l30-h/probe.lean`（6,002バイト、SHA-256 `ddc266e8f5d44af1ed21cf9b55d0b6a0cf9527e2c055d67bd1524f6d86d9cbc4`。`lake env lean -M 12288` で終了0、約1秒）。内容: 公開署名の `#check`、非数値の芯と継続の型域が空であること、Decimal の捕捉の事実が空でないこと、`carrier_meaning_represented`（型域の意味から `NumericRepresented`）、`carrier_from_image`（`ImageOk` から捕捉の事実の欄の型域の部分）、`raw_128_not_upper`、空の宣言表の `VarianceValid` と `typed127`・`meaning127`・`no_typed_1000`、新しい定理と例の公理依存（いずれも propext・Classical.choice・Quot.sound）。監査の再実行の出力は `<tmp>/rv-l30-h/axioms.log` と `audit-targets.txt`、`Context.lean`・`NumericRepresented.lean` の単独の検査の出力は同じ場所の `Context.out`・`NumericRepresented.out`。

## 取りまとめの追記

- 軽1〜3と情報1・2の申し送りは担当の再開1で処置した（l30/h/results.md の「再開1」）。所見はいずれも軽で、レビューが再レビューを要しないとしたので、取りまとめが報告と差分を確かめて受けた。
- J30-2 の三つの約束が守られたという本書の判定を、plan.md の J30-2 の項の証拠とする。J30-2 は設計者の見直しの対象のまま残す。
- 作業末の work は終了0、158.74秒（l30/h/results.md「作業末の work」）。
