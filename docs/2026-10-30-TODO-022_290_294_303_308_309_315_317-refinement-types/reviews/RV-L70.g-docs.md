# RV-L70.g-docs: L70 群 G の文書（01-12・07-04・formal/README.md の書き直し）の独立レビュー

2026-11-07。対象はブランチ `m014/l70.g` の作業木の `git diff 05341b96 HEAD -- docs/design formal/README.md` である。HEAD は `4823e272805af11e04d5bec5d82f9c73a547b3c3` で、`git rev-parse HEAD` の一致と、未コミットの変更がないことを確かめた。本書の `<repo>` は対象の worktree、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/`、S は `R/Surface/` である。行番号は HEAD の版のものである。

読んだもの:

- `AGENTS.md` の「設計書の規約」「文章の規範」「レビューの観点」と、スキル japanese-tech-writing。
- 本体の作業木の文書の担当の依頼文 `work/m014/L70.g3-docs-claude-prompt.md` と報告 `L70.g3-docs-claude-report.md`、Lean の担当の報告 `L70.g3-claude-report.md` の「文書への取り込み」。
- [書き直しの記録](../l70/g/docs-rewrite.md)の全文（書き直した節・除いた名前の表・最後の照合）、[群 G の結果](../l70/g/results.md)の該当箇所、[既定 import に残すモジュールの表](../l70/g/modules-for-spec.md)。
- 01-12・07-04・`formal/README.md` の差分の全体と、差分の周りの現在の本文（01-12 の構築器の5節・Scope の局所解析の5節・die のモデル・契約名・確かめる性質の冒頭、07-04 の「目的と範囲」「証明する性質」「篩を含む形式化の範囲」の照合の段落・「形式化で仮定するもの」「道具と置き場所」「01-12 との対応」の表）。
- 01-07 と 07-01 の形式化への言及。

したことは、名前と言明の Lean のソースとの照合（grep。下記の標本）、除いた名前の表の131行の旧の版 `dc22b231` と現在の Lean での照会（台本で全行）、交換の版の記述の三文書での照会、見出しの増減と参照の照会（`git grep`）、01-spec の ```text のブロックの新旧の一致の確かめ、相対リンクの確かめ、`python3 tools/spec-coverage/spec_coverage.py --self-test` と通常の実行（ともに終了0）である。

Lean・`lake build`・`scripts/check.sh`・git の書き込み操作は行っていない。サブエージェントは起動していない。変更したリポジトリのファイルは本書だけである。

## 結論

**条件付き可。重1件、中2件、軽7件、情報4件である。**

依頼の三つの対象（01-12 の構築器の5節と Scope の局所解析の5節、07-04 の「目的と範囲」「証明する性質」「形式化で仮定するもの」、`formal/README.md` の主定理の一覧）は、標本のほぼ全てが今の Lean の定義と定理に一致した。主定理の言明（`MainStatements` の六つの言明、`desugar_typed`・`surface_effect_soundness`・`surface_target_sound`、`checkProgram_sound`・`checkProgramAccepted_sound`、`prepare_agrees` の閉包の形）は前提を含めて読み合わせ、強く書きすぎた箇所は軽い前提の省略（軽4）だけだった。01-spec の ```text のブロック（24個）は新旧で一致し、相対リンクの切れはない。

ただし、書き直しの範囲の外に残った07-04の記述が、書き直した01-12・07-04・README と食い違う。07-04「01-12 との対応」の表の構築器の二行は、削除した旧 Surface の定理（`builders_no_capture` など）を証明済みとし、01-12 が新しく書いた「篩付きの形式化は脱糖の出力の捕捉禁止の定理を持たない」と逆の保証を述べる（重1）。07-04「道具と置き場所」などには、Lean が受理しない旧版の交換（13/5・11/4・15/7・14/6）の読者の記述と、削除した `Surface.BuilderExamples` の記述が残る（中1）。記録の「最後の照合」は逆引用符で囲んだ識別子だけを照らしたので、表の中の囲まない名前を拾えなかった。01-12「die のモデル」は規則の表を今の Lean に合わせたが、同じ節の地の文が、規則が検査しなくなったメソッドの純粋性と exit の種類を「型付けの前提で検査する」と述べ続ける（中2）。

重1・中1・中2を直せば可とする。軽は同じ単位で直すのが望ましいが、受け入れの条件にしない。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 重1 | 重 | 07-04「01-12 との対応」の表の行「構築器の分類と環境の対応」（1461行）と「穴の直接参照とブロック式」（1462行）。同じ表の「専用セルの構文と通常値の捕捉境界」（1460行）も段階 B・C・E の旧の説明のまま | 1461行は「ΓとΔの整列」「`toLocal_kindAt`」「`congrΔ`と旧構文のΔの任意性を証明する」「checkerの相互帰納とstrict/relaxedの支持保存」「公開11件」「Captures を `builders_no_capture`・`builders_block_no_capture` で示す」と書く。1462行は「`ArgTypesQ` の評価列と値列の型保存」「checkerのstrict/relaxedと公開11件」「corpus 13だけでblockを受け、旧版を拒否する」と書く。`toLocal_kindAt`・`congrΔ`・`builders_no_capture`・`ArgTypesQ` は今の `formal/` のどこにもない（grep）。01-12「構築器の局所宣言と捕捉」（2855行）と記録の除いた名前の表は「篩付きの形式化は脱糖の出力についての独立の捕捉禁止の定理を持たない」とし、01-12 482行と `Exchange/Version.lean` は corpus 16 だけを受理する。設計書の正の章が、証明していない保証を証明済みと書いている | 二行（と1460行）を篩付きの対応物で書き直す。構築器の行は 01-12 の構築器の5節の名前（`C_BuilderLet`・`C_BuilderOp`・`hideBuilders`・`B_BuilderBind`・`HasTypeQ.desugar`・`checkBlockAt_sound`・`LocalInvariant`・`StateTyE.builder_live`・`Exchange.BuilderExamples`）に揃え、捕捉禁止は「型付けの境界で禁じ、脱糖の出力についての定理は持たない」と書く。ブロック式の行は版 16 に改め、`ArgTypesQ`・strict/relaxed・公開11件を除く。最後の照合を、表の中の逆引用符で囲まない名前にも当てる | 読めば確定 |
| 中1 | 中 | 07-04「道具と置き場所」の744〜762行、868行（区間解析を含む全比較への接続）、表の1444行・1446行・1503〜1505行 | 744行は「corpus 13の表層構築器」「版12の構築器は版13での再生成を求める」「sidecarの対応はcorpus 8→2、9/10→3、11/12→4、13→5」、748行は「交換13/5の独立入力」、752行は「`Exchange.BuilderExamples`は、版13の専用コアを…照合し」「`Surface.BuilderExamples`は…strict/relaxed」、754行は「交換11/4は」、762行は「Rust の交換器は現在 corpus 15・sidecar 7 を出力し」、868行は「既存の六つの実行器・corpus14・sidecar6 の形式と、…旧主定理」と書く。`Exchange/Version.lean` は corpus 16 と付随の表 8 だけを読み（207行・228行）、`Exchange/BuilderExamples.lean` は版 16 の受理と版 15 の拒否を確かめ（52〜53行）、旧 `Surface.BuilderExamples` は削除した。同じ節の742・746・798・812行と 01-12 2857行・README は版 16/8 だけを書くので、同じ章の中で受理する版の記述が食い違う。1503〜1505行の表の行（「交換13/5の独立入力と旧版の拒否」など）も、今の読者が持たない旧版の読者を対象とする | 旧版の読者・旧版の独立入力・旧 `Surface.BuilderExamples` の段落と行を除くか、「版 16/8 だけを受理し、それより前の版を断る」の一文に改める。過去の全比較の記録（748行の 2026-10-21 の実行など）を残すなら、どの版の記録かを明示する | 読めば確定 |
| 中2 | 中 | 01-12「die のモデル」の第2段落（「辞書の型・メソッドの純粋性・exit の種類と型は、次の型付けの前提で検査する」）、第5段落（「純粋な一引数の String のメソッドと exit の種類・効果を持つ組み込みを宣言表で検査するため」）、第4段落（901行「exit の呼出しの効果は ε に覆われなければならないので、`Process.Exit` は式の効果 ε に含まれる」）、920行（「説明や表示の純粋性は」） | 表の二規則は S `Rules.lean` 827〜890行の `E_TryResultDie`・`E_TryOptionDie`（と説明付きの二規則）と一致する（下記）。しかし今の規則は、show の呼出しの効果 es′ を ε が覆うこと（`Eff.Covers … es'`）だけを求め、空の効果を求めない。exit は `CallHeadTy … (.primName exit [t] [] [])` で型付けるだけで、種類が exit であることも所属エフェクトが `Process.Exit` であることも検査しない。検査器（S `Check.lean` 676〜740行）も同じである。したがって「メソッドの純粋性」「exit の種類」を検査するという文は旧の `DieShowOk`・`DieExitOk` の記述が残ったものであり、「`Process.Exit` は ε に含まれる」は表の exit の署名の効果が `Process.Exit` であるときに限って成り立つ | 第2・第5段落を、今の規則が検査するもの（辞書の型付け、頭の型付け、結果の型、効果の被覆）に改める。901行は「exit の署名の効果を ε が覆うので、標準の表のように exit の効果が `Process.Exit` なら ε はそれを含む」と条件を書く。920行の「表示の純粋性」は、show の効果が ε に覆われることに改める | 読めば確定 |
| 軽1 | 軽 | 01-12「構築器の表層の局所文脈」2822行 | 七判断の列挙の `HasHoleArgsQ` は Lean の判断の名前ではない。S `Rules.lean` の相互帰納の判断は `HasFixedQ`（936行）であり、`HasHoleArgsQ` は S `Typing.lean` 26行の型の別名 `HoleArgsJudgment` の文書コメントにだけ現れる | `HasFixedQ` に改める | 読めば確定 |
| 軽2 | 軽 | 01-12「契約名を持つ関数と呼び出し」1155行 | 1134行の【決定】で正を篩付きの核・表層・交換に改めたが、1155行は `Builtins.Assumptions.sig_scoped`・`opSig_scoped`・`HasTypeV.lambdaNamesWF`・`HasTypeC.lambdaNamesWF` を引く。`opSig_scoped` と `lambdaNamesWF` は旧 `Release/Lemmas/Names.lean`・`TySubstMain.lean` にだけあり、篩付きの核にない。`Builtins.Assumptions` は旧 Release の信頼条件である | 篩付きの対応物（`Builtins.CoreAssumptions` の `sig_scoped` の欄など）に改めるか、旧 Release の定義を指すと明記する | 読めば確定 |
| 軽3 | 軽 | 01-12 の見出し「Scope の局所解析の接続定理」（2764行）。07-04 44行と表の1457行がこの見出しを引く | 本文は `Surface.CheckAccept` の受理と `productionRules_sound` だけを書き、接続定理（`scope_check_connection` 系）は篩付きの形式化にない。見出しが本文にない定理を指す | 見出しを内容に合う名前（例: 「Scope の必須の判定のプログラム全体の受理」）に改め、07-04 の二つの参照と spec-coverage の参照を同じ変更で直す。見出しを保つなら、接続定理を持たないことを一文で書く | 読めば確定 |
| 軽4 | 軽 | 07-04「証明する性質」23行・25行、01-12「確かめる性質」4461行 | (1) `effect_soundness` は `Refinement.MainEffects`（R `MainEffects.lean` 111行）にあり、`MainTheorems` にない。07-04 は「`Refinement.MainTheorems` の … `effect_soundness`」、01-12 は性質 3 の証明の場所を `Refinement.MainTheorems` とする。(2) 07-04 25行の `surface_effect_soundness` の説明は「main が空の効果を宣言し、σ が準備済みなら」とするが、言明（R `SurfaceMain.lean` 109行）は表層の整形式・型付けと `B.CoreAssumptions (desugarProgram op p)` も前提に取る。性質 1 の前提の値の条件より強い信頼条件である | (1) 置き場所を「`MainTheorems`・`MainEffects`」とする。(2) 前提に「性質 1 と同じ表層の条件と、脱糖したプログラムについての `CoreAssumptions`」を足す | 読めば確定 |
| 軽5 | 軽 | 01-12「構築器の専用セルの内容と上限」2808〜2810行 | (1) `builderApply` の型は `Option BuilderReply` であり、引数の形が操作に合わないときと、length で大きさが上限を超えるときに none を返す（R `BuilderExec.lean` 58〜69行）。本文は `BuilderReply` を返すとする。(2) `builderApply_value_scope` は、元のセルの閉性と適格性、引数の閉性と適格性を前提に取る（R `BuilderValueTyping.lean` 137行）。本文は前提を書かない | (1)「`Option BuilderReply`（形の合わない引数では none）」とする。(2) 前提を一句で足す | 読めば確定 |
| 軽6 | 軽 | 07-04「篩を含む形式化の範囲」62〜71行の「照合の対象」と、同章の681行・717行、01-12 2594行 | 新しく定義した「照合の対象」（`closureOf` の名前の集まり）を、同じ章の681行（「処理系の表と解析器との照合の対象である」）・717行（「処理系との照合の対象として信頼する」）が一般の意味で使う。01-12 2594行は照合する値を「照合対象」と呼び、用語集の「照合」はパターンマッチの意味である。読み手が語の地位を決められない。用語集に行もない | 用語集の他言語の呼び名を調べたうえで別の語にするか、用語集に行を加えて 07-04 の一般の用法を言い換える（例:「照合すべき範囲」）。語の選定は設計者に問う | 読めば確定 |
| 軽7 | 軽 | [書き直しの記録](../l70/g/docs-rewrite.md)の「除いた名前の表」と、07-04 1451行 | (1) `SingleFail` の右欄は「なし」だが、篩付きの表層に同名の定義がある（S `CheckSingle.lean` 6行。`norm` で比べる形）。`NoFreeBuilders` も R `LocalInvariant.lean` に同名がある。(2) 既定 import に残す旧モジュールに今も定義がある名前を「除いた」としている: `stateTy_of_old`（`Release/Lemmas/PresHelpers.lean` 88行）、`Ty.wf_iff_old`・`Ty.WFOld`・`sat_unconstrained_iff_old`（`Release/RangeWF.lean`）、`LocalCtx.kindAt_extend`（`Release/Typing.lean` 498行）。07-04 1451行は `stateTy_of_old` と `BuiltinOnly.iff_old` を今も引く。(3) 旧の版 `dc22b231` の旧のファイルに語として現れない名前がある: `ScopeLimits`（実名は `Limits`）、`analyze_pending`・`renumber`（どの版にもない）、`presFailure`（実名は `pres_failure`）、`cons_sig`（実名は `HasClausesQ.cons_sig_unique`）、`writeEffNames`・`writeEffNames_complete`（基準 `05341b96` にはあるが `dc22b231` にない）。`CoverageIntegerExamples` はファイル名であり、名前空間は `CoverageExamples` である | (1) 右欄を対応物の名前に改める。(2) 旧モジュールに残る名前は「設計書から除いたが、Lean には残る」と区別する。(3) 名前を実名に直し、旧の版の列を正す | 読めば確定 |
| 情1 | 情報 | 07-04「形式化で仮定するもの」672行 | 「δや `Builtins.Assumptions` に…の仮定を加えない」の `Builtins.Assumptions` は旧 Release の構造体（`Release/Assumptions.lean` 140行）であり、今の主定理の信頼条件は `CoreAssumptions` である。同じ節の表は `CoreAssumptions` で書いたので、軽2と同じ単位で揃えるとよい | — | 読めば確定 |
| 情2 | 情報 | `formal/Benitoite/Exchange/BuilderExamples.lean` 8行、`Exchange/FormatExamples.lean` 3行 | 二つの文書コメントが 07-04「証明する性質」を対応する契約として引くが、同節は交換の例を扱わなくなった（記録は FormatExamples だけを挙げる）。Lean のファイルは本単位の範囲外である | 群 H か次の Lean の単位で、引く節を 01-12「構築器の局所宣言と捕捉」と 07-04「交換の形式の版」に改める | 読めば確定 |
| 情3 | 情報 | `formal/README.md` の公理の確かめの例（`/tmp/axioms.lean`・`/tmp/side-axioms.lean`） | 一時のファイルの絶対パスは基準の版から続く例示であり、手元の絶対パスではない。公開の記録の決まりには反しない | — | 読めば確定 |
| 情4 | 情報 | 記録の「最後の照合」 | 照合は逆引用符で囲んだ識別子の最後の成分だけを対象にしたので、表の中の囲まない名前（重1・中1の名前）と、旧版の番号（中1）を拾えない。また同名の定義が旧 Release に残る名前（`checkMatchWithView_*`・`HasTypeCL` など）は、篩付きの対応物があるかを区別しない | 次の照合では、囲まない英字の識別子と「corpus/sidecar/版 N」の数も照らす | 読めば確定 |

## 観点ごとの根拠

### 1. 実装との対応

標本は各対象で5件以上とし、名前・置き場所・言明の形を Lean のソースと照らした。

01-12 の構築器の5節（一致したもの）:

- `BuilderKind` の三構成子（R `Syntax.lean` 71行）、`Comp.builderLet kind body`・`builderOp kind op ref args`（同180〜181行）、`LocalCtx := List (Option BuilderKind)`（同479行）。
- `C_BuilderLet` の前提（`Ty.Annotation P C Γ kind.contents`・`TypeArgsKinded`・`Γ.extendNone`・事実と R と結果型と効果の一つのずらし・`LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ`・`Ty.Declared`）と、`C_BuilderOp` の前提と空の効果（R `Typing.lean` 272〜282行）。
- `LocalRef.HasKind` の三構成子（bound・loc・normal。同92〜95行）、`LocalCtx.extend`・`localExtend`（同85〜90行）、`hideBuilders` と V_Lam・V_DependentLam・C_Lazy・節の本体での使用（同32・156・161・311・483・496行）。
- `BuilderContents` の三種・`size`・`limit`・`snapshot`・`lengthValue`・`builderCheckUpdate` の ValueTooLarge と BuilderInvalidByte（R `BuilderExec.lean`）、上限の値（`Release/LocalRef.lean` 69・71行）、`BuilderCellOk` の四条件（R `StateTyping.lean` 42行）。
- `Step.E_BuilderNew/E_BuilderOp/E_BuilderErr` の前提と後続（R `Semantics.lean` 60〜73行）、`builderValueSubst` の 0 番が Unit（R `Capture.lean` 104行）、`StateTyE.builder_*` と `builder_live` と `HandlerStoreExamples` の三例の存在。
- 表層の `E_BuilderOp`（`ValsTys` と `renameKind (· + as.length)`。S `Rules.lean` 245行）と `B_BuilderBind`（同1000行）、Δ を空にする位置と `localExtend` を渡す位置（同258・298・574〜989行）、脱糖の `bound (i + ms.length)` と `builderLet k (desugarBlock …)`（S `Desugar.lean` 240〜242・492行）、`builderOp_step`・`checkBlockAt_sound`・`builderBind_core`・`BuilderSupport` の存在、`Exchange.BuilderExamples` の版 16 の受理・版 15 の拒否・refs の拒否（52〜57行）。

一致しなかったのは軽1（`HasHoleArgsQ`）と軽5である。

01-12 の Scope の局所解析の5節: `Benitoite.Scope.Inference`、`ScopeRules` の `models`・`checkRule`・`projectRule`、`ScopeSound` の `productionRules`・`productionRules_sound`、`ScopeState` の `standardTable`・`apiAt`（`Scope/Inference.lean` 109行の欄）・`absStep`・`intLitText`・`litInt?`・`Limits`・`Cap`・`Budget`・`Budget.checkLimit`・`Run.step`・`blindStep`・`Run.enter`・`Run.leave`、`ScopeLower` の `Records`・`directHead`・`contractOrder`・`constArg?`・`rhsStep`・`conArm?`・`armEntry`・`rejoin`・`analyzeBody`、`ScopeAccept` の `CoverFailure` の四構成子と `acceptRange_sound`・`acceptBody_sound`・`acceptBody_ranges`、`CheckAccept` の `acceptProgram`・`acceptProgram_sound`・`checkProgramAccepted`・`checkProgramAccepted_sound` は全て定義がある。`checkProgramAccepted_sound` の結論（準備後の `CheckedUnder` と `Accepted` の組）も本文と一致する。不一致は見出しだけである（軽3）。

07-04「目的と範囲」「証明する性質」: `MainStatements` の `ProgressStatement`・`PreservationStatement`・`StepsPreservationStatement`・`StepSoundStatement`・`InitialTypingStatement`・`EffectSoundnessStatement`・`StepTargetStatement`・`ReachableTargetStatement`・`ReachableTargetEventStatement` を読み合わせた。`EffectsOk` を取る定理と取らない定理（`step_sound`・`initial_typing`）、`step_target_sound` だけが `σ.Valid` を取ること、`StepSelection`・`StartCondition` の欄、`Eff.Allows σ B.effKind Eb l t` の結論は本文と一致する。`desugar_typed`（S `Theorems.lean` 399行）の前提 `p.WellFormed`・`p.WellTyped B opPrim`・`ValueAssumptions` と三つの結論、`surface_target_sound` の前提、`checkProgram_sound` の六前提（`Input.Sound`・`NamesComplete`・`DefSupport`・`ImplSupport`・`ImplNamesComplete`・`Extends`）、網羅性の定理の置き場所（R `Coverage.lean`・`CoverageInitial.lean` の名前空間 `Coverage`）も一致する。不一致は軽4である。

07-04「形式化で仮定するもの」: `StandardModel.statement_premises`（R `MainStatements.lean`）、`Builtins.selected_stepSelection`（同120行）、`main_start`、`Builtins.TargetAgreement.obs_allowed`（R `EffectTargets.lean` 265行）、`CheckAcceptBase.primResolve`、`ScopeAcceptanceEntry.acceptInput`（`Exchange/Observe.lean`）、`modelHttp_contract`、`check_send_preserves` は全て存在する。表の五種の前提は、上の言明の前提と一致する。情1を除き、旧の名前は残っていない。

`formal/README.md` の主定理の一覧: 41名のうち `checkProgramAccepted_main`（R `SurfaceLibrary.lean`）、`Coverage.coverage_extension_sound`（R `CoverageInitial.lean` 74行）、`irrefutableWithView_sound`・`checkMatchWithView_exhaustive_sound`（R `Coverage.lean` 2015・2034行。名前空間は `Benitoite.Release.Refinement`）、`usefulWithView_extension_exhaustive`、`BuiltinAgreement.standardCheck_sound`、`effect_soundness_noLamNames`、`prepare_agrees`（`Exchange/CheckInput.lean` 465行）を照らし、全て完全名で存在した。旧 Release の74モジュールと旧 Surface の3モジュールの数は、ファイルの数え上げ（`Release/` の `Refinement/` の外の74、`Surface/` の3）と一致する。交換の版（corpus 16・付随の表 8）は `Exchange/Version.lean` と一致する。

die のモデル: 表の `E_TryResultDie` の前提（`Ty.Annotation`、ok と err の `PatTy`、`t1.norm = t.norm`、入力の型付け、二分岐の `Exhaustive`、`CallHeadTy` の `methName` と `ValsTel`・`Ty.LeQ … (.base .string)`・`Eff.Covers`、`CallHeadTy` の `primName exit [t]` と整数 1 の `ValsTel`・`Ty.LeQ … t`・`Eff.Covers`）と結論 `t ε` は、S `Rules.lean` 827〜842行と一致する。`E_TryOptionDie`（865〜876行）も一致する。結果の効果が旧の `ε ∪ {Process.Exit}` から ε に変わったことは、表の結論に反映されている。検査器（S `Check.lean` 676〜740行）は規則の前提に加えて `rawTyEq … t a` と辞書の空を確かめ、「同じ順に確かめる」は読解の範囲で成り立つ。残る不一致は中2の地の文である。

### 2. 除いた事項

記録の除いた名前の表の131行を、旧の版 `dc22b231` の旧のファイルと現在の `formal/` で台本により照らした。今の篩付きの形式化に同じ役割の対応物があるのに「なし」とした行は `SingleFail` だけだった（軽7(1)）。旧モジュールに今も定義が残る名前と、旧の版にない名前の綴りは軽7(2)(3)に挙げた。構築器のセルの保持（`builder_step_frame`・`capture/resume_builder_cell`・`drop_local_silent`）、`builders_no_capture` 系、`scope_check_connection` 系、`main_reach` 系は、現在の `formal/` に語として現れず、「なし」の判定は正しい。対応物のない保証を除いた判断そのものは、依頼のとおり群 H の監査に委ねる。

### 3. 章どうしの整合

主定理と仮定: 01-12「確かめる性質」と 07-04「証明する性質」、README の一覧は、篩付きの二つの名前空間を規範とする点と主定理の名前で一致する。置き場所の食い違いは軽4(1)である。

交換の版: 01-12（482・729・2857行）、07-04（742・798・812・816行）、README は corpus 16・sidecar 8・surfaceVersion 16 で一致する。07-04 の残りの箇所が旧版を書く（中1）。

照合の対象: 07-04 の62〜71行の `closureOf`・`prims`・`data`・`dataStep`・`jsonStrings` の説明は `Exchange/CheckInput.lean` 82〜115行と一致し、`prepare_agrees` の結論の式も Lean の言明（470〜471行）と一致する。鍵の印の補題 `satB_normKey`・`sat_normKey`・`admits_normKey` は `BuiltinAgreement.lean` にある。01-12 には照合の対象の記述はなく、食い違いはない。語の地位は軽6である。

構築器の保証: 01-12 の構築器の5節と 07-04「証明する性質」の構築器の段落は一致する。07-04「01-12 との対応」の表が食い違う（重1）。

01-07 と 07-01: `git grep` で形式化の名前を探した。07-01 96行の `io_target` は篩付きの `TargetAgreement` の欄として今も実在し、07-04「形式化で仮定するもの」への参照も切れていない。01-07 に形式化の名前はない。削除した判断を正とする記述は両章に残っていない。

### 4. 未決事項の扱い

差分の追加行に【未決】【要検証】はない。「後の課題」の語は 07-04 の既存の行（`groundVal` の標準形の補題）に残るが、差分の外である。まだ実装していない機能を書いた追加行はない。

### 5. 論証の正しさ

追加した「理由:」は、01-12 の `hideBuilders`・辞書の番号の範囲・`SurfaceSyntax.eraseExpr`、07-04 の照合の対象・鍵の印・`prepare_agrees`・受理の位置付けで、いずれも1〜2文であり主張を支える。07-04 の `dataStep` の繰り返しの回数の論証（「一段ごとに宣言が一つ以上増えるか変わらなくなるので、この回数で閉じる」）は、名前の重複を除いた列が data の宣言の数を超えないことから成り立つ。定理ではないので、断定は Lean のコメントと同じ読解の水準である。前方参照のうち、01-12 2764行の「篩を含む表層の検査と受理」への参照は同節の59〜69行（`ScopeRules`・`productionRules`）で回収されている。01-12「die のモデル」の推論（901行）は中2のとおり条件が要る。

### 6. リンクと見出し

- 相対リンク: 三文書の `](…)` を台本で照らし、ファイルと見出しの切れはなかった（01-12 の数式の字面の誤検出と、全角括弧の見出しの slug の誤検出を除く）。
- 改名した見出し「構築器の局所文脈と旧構文の意味」→「構築器の表層の局所文脈」: 旧の見出しを引く箇所は、改造の過去の記録と `docs/archive/` の外に残っていない。コードのコメント・`// spec:` の印・`tools/spec-coverage/`・`gen_skill`・Lean のコメントにもない。新しい見出しは 01-12 2855行が引く。
- 範囲の中で消えた見出し「Logの通常宣言とハンドラの具体例」（`7523c6fb` で除いた。results.md に記録がある）を引く箇所も残っていない。
- spec-coverage の自己検査と通常の実行は終了0だった。
- 01-spec の ```text のブロックは、01-12 の24個が新旧で一致した。

### 7. 用語と文体

追加行は常体で書かれ、イ形容詞の「です」や LLM の空句は見当たらない。外部の事実を新しく書いた行はない。造語の疑いは「照合の対象」だけである（軽6）。「篩付きの核」「篩付きの表層」は既存の章の用法に揃っている。

### 8. 公開の記録の決まり

追加行に docs/todo へのリンクはない（07-04 25行の「docs/todo の TODO-162」は文字の参照）。手元の絶対パス、`reference/`・`private/` の参照はない。README の `/tmp` の例示は情3のとおりである。

## 処置

2026-11-07 15:45〜16:05、文書の担当（Claude）。取りまとめの判断に従い、作業木 `m014/l70.g`（HEAD `4823e272`）で直した。名前と言明は作業木の Lean のソースで確かめてから書いた。git の書き込み操作とサブエージェントの起動はしていない。変えたファイルは、`docs/design/01-spec/01-12-core-calculus.md`、`docs/design/07-quality/07-04-formal-semantics.md`、[書き直しの記録](../l70/g/docs-rewrite.md)、`formal/Benitoite/Exchange/BuilderExamples.lean`・`FormatExamples.lean` のコメントの各一行、本書である。`formal/README.md` は変えていない。

| 番号 | 処置 | 変えた場所 | 理由・確かめたこと |
|---|---|---|---|
| 重1 | 直した | 07-04「01-12 との対応」の表の「専用セルの構文と通常値の捕捉境界」「構築器の分類と環境の対応」「穴の直接参照とブロック式」の三行 | 段の欄を「篩付きの核（表層）の定義と定理」に改め、本文を篩付きの名前（`BuilderKind`・`Comp.builderLet/builderOp`・`LocTy.builder`・`Cell.builder`・`C_BuilderLet/C_BuilderOp`・`Step.E_Builder*`・`hideBuilders`・`BuilderCellOk`・`builderApply_value_typed/scope`・`StateTyE.builder_*`・`StateTyE.local_invariant`、表層の `BuilderCtx`・E_BuilderOp・B_BuilderBind・`HasTypeQ.desugar`・`builderBind_core`・`builderOp_step`・`checkBlockAt_sound`・`ExprSupport`・`BuilderSupport`、`ArgPlan`・`sequenceArgs`・`HasFixedQ.desugar`・E_Block・`block_step`）で書き直した。捕捉禁止は「型付けの境界で禁じ、脱糖の出力についての捕捉禁止の定理は持たない」とし、セルの保持の三性質を独立の補題として持たないと書いた。`toLocal_kindAt`・`congrΔ`・`builders_no_capture`・`ArgTypesQ`・strict/relaxed・公開11件・corpus 13 を除いた |
| 中1 | 直した | 07-04「道具と置き場所」の構築器・独立入力・BuilderExamples・Fail・dataTypes・try・網羅性の段落、「書式付き補間の交換形式」、「交換の形式の版」の観測の段落、「区間解析を含む全比較への接続」、「篩を含む形式化の範囲」の定数の段落、表の1444・1446・1472・1496・1503〜1505・1510行、01-12「形式化した操作の制約と節の辞書」の前の Fail の【決定】 | 旧版の読者（corpus 8〜15・sidecar 2〜7 の読み分け、旧版への新構成の混入の拒否、旧版の既定の補完、旧 `Surface.BuilderExamples`）と、旧版の記録（交換13/5の時点の2026-10-21の全比較）を除いた。版を名指す箇所は corpus 16・sidecar 8 に改め、版の番号で呼んでいた独立入力は試験のディレクトリ（`batch4-exchange`・`try-exchange`）で呼んだ。`Exchange/Version.lean` の `exchangeJson` が corpus 16 と他の種類の 8 だけを受理すること、独立入力の JSON が全て 16/8 であること、`test_batch3_exchange.py` などが旧版を拒否することを確かめた。同じ段落の「独立した Coverage の入力は版4を保つ」は、同じ段落の「版 8 で書く」と Lean・Rust の 8 に反するので除いた |
| 中2 | 直した | 01-12「die のモデル」の第2・4・5段落、説明の中の try の文、停止の段落。07-04 の表の「die の型付き表層の型付け・脱糖・検査」の行 | S `Rules.lean` の四規則と S `Check.lean` の四つの場合を読み、show と exit を `CallHeadTy` で型付け、結果の型と効果の被覆だけを確かめることを確かめた。「メソッドの純粋性・exit の種類を検査する」の文を除き、`Process.Exit` を ε が覆うのは exit の署名の効果が `Process.Exit` の表に限ると条件を書いた。07-04 の行も同じ誤り（入力の効果と Process.Exit の和、原子集合への Process.Exit の包含の検査）を持っていたので、同じ単位で直した |
| 軽1 | 直した | 01-12「構築器の表層の局所文脈」 | `HasHoleArgsQ` を `HasFixedQ`（S `Rules.lean` 936行）に改めた |
| 軽2 | 直した | 01-12「契約名と型付け」の表の下の段落と表の節の行 | 篩付きの核の規則が `NamesWF` を前提に持つことと、その出どころを `Program.WellFormed` の `Def.Scoped`・`OpDecl.Scoped`・`ClassDecl.Scoped`（`MethSig.Scoped`）と `Builtins.CoreAssumptions.sig_scoped`（`PrimSig.Scoped.names`）に改めた。`opSig_scoped`・`lambdaNamesWF` は篩付きにないので除き、`HasTypeVQ.closed_noLamNames` 系と `effect_soundness_noLamNames`（`MainEffects`）を書いた。表の `HasTypeClauses.cons` は `HasTypeClausesQ.cons` に改め、出どころを確かめられない「整形式から従う」を除いた |
| 軽3 | 直した | 01-12 の見出しを「Scope の必須の判定のプログラム全体の受理」に改名。07-04 の「目的と範囲」の参照、表の行名、表の「検査済みの要求の値」の行の参照 | `git grep` で、コードのコメント・`// spec:` の印・`tools/spec-coverage/`・`gen_skill`・Lean のコメントに参照がないことを確かめた。改造の過去の記録（`l00b.15`・`l20`・`l50`・`l70/g` の記録）の旧の見出しは当時の記録として残した。表の「検査済みの要求の値」の行は旧 `Surface.ScopeState` を引いていたので、`Val.target?` を持つ `Surface.ScopeRules` と、それを扱う行の名前に改めた |
| 軽4 | 直した | 07-04「証明する性質」の性質 2・3 と性質 1 の段落、01-12「確かめる性質」の冒頭 | `effect_soundness` の置き場所を `Refinement.MainEffects` とした。`surface_effect_soundness` の前提に、表層の整形式・型付けと `B.CoreAssumptions (desugarProgram op p)` を足した（R `SurfaceMain.lean` 109行） |
| 軽5 | 直した | 01-12「構築器の専用セルの内容と上限」と遷移の表 | `builderApply` の型を `Option BuilderReply` とし、none の場合（形の合わない引数、上限を超えた length）を書いた。`builderApply_value_scope` の前提（元のセルと引数の閉性・適格性）と結論（返却値の `Ground` を含む）を書いた。遷移の表も `some` の結果に合わせた |
| 軽6 | 直した | 07-04「篩を含む形式化の範囲」の `closureOf` の段落 | 新しい術語を作らない決まりに従い、「照合の対象」を「プログラムが参照する組み込みの関数と、そこから型を通じて届く data の宣言の有限の集まり」と `closureOf` の名前に置き換えた。07-04 681・717行と 01-12 の「照合対象」は一般の用法なので変えていない。用語集には行を加えていない |
| 軽7 | 直した | [書き直しの記録](../l70/g/docs-rewrite.md)の「除いた名前の表」と「書き直した節」の二行 | 全行を `dc22b231` と現在の `formal/` に台本で照らした。(1) 同名の対応物: `SingleFail`・`NoFreeBuilders` の右欄を篩付きの定義に改めた。(2) 旧モジュールに残る名前: `LocalCtx.kindAt_extend`・`stateTy_of_old`・`Ty.wf_iff_old`・`Ty.WFOld`・`sat_unconstrained_iff_old` に「既定 import に残す旧モジュールに今も定義がある」と書いた。`fieldNew_iff_old` は同名の別の小例が `Scope/SignatureExamples.lean` に残ると書いた。(3) 実名・綴り・版: `ScopeLimits`→`Limits`（篩付きの `ScopeState` にあり、除いていない）、`presFailure`→`pres_failure`、`cons_sig`→`HasClausesQ.cons_sig_unique`、`toNew`→`ContTyOld.toNew`、`exprExits` のファイルを `Surface/CheckPredicates.lean`、`FailureExamples`・`CoverageIntegerExamples` を名前空間の名前、`writeEffNames` 系を `Prepared.` 付きで基準 `05341b96` の定義と直した。どの版にもない `analyze_pending`・`renumber` の行は除いた。07-04 の `stateTy_of_old`・`BuiltinOnly.iff_old` の引用は、既定 import の旧モジュール（`Release/Lemmas/PresHelpers.lean`・`Release/Semantics.lean`）に実在し、表の行の説明とも合うので残した |
| 情1 | 直した | 07-04「形式化で仮定するもの」の書式の照合の段落 | `Builtins.Assumptions` を `Builtins.CoreAssumptions` に改めた。区間解析の段落などに残る「`Builtins.Assumptions` は変更しない」の定型句は、範囲の外として変えていない |
| 情2 | 直した | `Exchange/BuilderExamples.lean` 8行、`Exchange/FormatExamples.lean` 3行のコメント | 引く節を、今その例を扱う 07-04「道具と置き場所」と「書式付き補間の交換形式」に改めた。コード・証明は変えていない。共有ロックの下の既定の `lake build` は終了0（15:55、2,323ジョブ、`sorry` の警告なし） |
| 情3 | 処置不要 | — | 取りまとめの判断のとおり |
| 情4 | 直した | [書き直しの記録](../l70/g/docs-rewrite.md)の「最後の照合の拡大」 | 逆引用符の外の Lean らしい名前と交換の版の番号を三文書の全体で照らした。削除した名前 `capture_local_valid`・`resume_local_valid`（07-04 の表）と綴りの誤り narrowSlotsKind（01-12）を直した。残る字面と理由を記録に表で書いた |

検査: `python3 tools/spec-coverage/spec_coverage.py --self-test` と通常の実行は終了0で、改名した見出しは試験の参照のない節の一覧に新しい名前で出る。変えた文書の相対リンクと見出しの切れは0（01-12 の数式の字面の誤検出1件を除く）。01-12 の ```text のブロック24個は変えていないので、`spec_examples` は実行していない。

範囲の外で見つけ、直していないもの（取りまとめへ）:

- 01-12「型の情報を付けた表層の構文と型付け」の `handle` の項（545行付近）の `clauseIx B εb o`（`Eff.clauseRange`）は篩付きの核にない。節の添字は `Refinement.HandlerContracts` の `ClauseSig`・`ClauseIxOk`（Top か規則の値）が定める。
- 篩付きの表層の Lean のコメント6箇所（`Surface/Rules.lean`・`Desugar.lean` 二箇所・`OpenSurface.lean`・`Property1Die.lean`・`Surface/Syntax.lean`）と旧 `Surface/Syntax.lean` が、01-12 にない見出し「die の先行モデル」を引く（今の見出しは「die のモデル」）。
- `Exchange/` の Lean のコメント（`BuiltinAgreement`・`Builtins`・`CheckInput` 二箇所・`CheckSupport`・`Convert` 二箇所・`Syntax`）と `Surface/ScopeSound.lean` が、交換の検査を扱わなくなった 07-04「証明する性質」を引く。
- 01-12「表層のブロック式」の「式と文列の型保存・clean・範囲保存・捕捉の相互帰納」、07-04 の表の「確かめる性質」の行の `ClosedNoEffVars`・「旧版の変数の範囲条件」、および表の旧 Release の行（段階 B・C・E の説明）は、旧の形式化の記述が残っている可能性がある。この単位では照らしていない。

### 取りまとめの判断の後の続き（2026-11-07 16:05〜16:20）

取りまとめの判断（範囲の外の古い記述は L70.44 の削除の結果なので、この単位で直す。並行の Lean の担当が変更中のファイルは変えず、直す行を記録に挙げる）に従った。基準は `808e6086` である。

| 対象 | 処置 | 変えた場所 | 理由・確かめたこと |
|---|---|---|---|
| 01-12 の `clauseIx` | 直した | 01-12「型の情報を付けた表層の構文と型付け」の `handle` の項の【決定】 | S `Rules.lean` の `HasClausesQ.cons` は核と同じ `ClauseSig D.core B εb o sg`（R `HandlerContracts.lean`）を前提に持ち、添字は Top か規則の値（`ClauseIxOk`・`Eff.ClauseRangeIs`）である。「表層は規則の値だけを使い Top を選ばない」の決定と理由は今の規則に合わないので、表層と核が同じ条件を使う形に改めた。検査器は入力の案内が与える添字を `clauseIxCheck` で判定し、成功から `ClauseIxOk` を導く（S `Check.lean` 862行、`CheckHandler.lean`） |
| 01-12「表層のブロック式」 | 直した | 第2段落の先頭の二文、同じ趣旨の「die のモデル」の `Expr.AtomsIn` | 篩付きの表層に `Expr.AtomsIn` と clean・捕捉の相互帰納はない。`Expr.Scoped`（S `Scoped.lean` 50行）・`Expr.Exits`（S `Basic.lean` 365行）・検査器の支持 `ExprSupport`（S `CheckSource.lean` 27行）と、性質 1 の E_Block の場合（S `Property1.lean` 49行の `HasBlockQ.desugar`）に改めた |
| 07-04 の表の旧 Release の行 | 直した | 「01-12 との対応」の表の前の説明、36行の段の欄と古い主張、表の後の【決定】、同節の外の `Release.ModelTargets`・`Release.ModelHttp` の段落と依存の表の一行 | 段の欄の「段階 A・B・C・E の…を拡張」を、篩付きの核・表層の行と「旧 Release の共有の定義（篩付きの核への埋め込みの定義域）」の行に分けて書き直し、表の前に二種類の行の読み方を書いた。削除した証明を引く文（旧の主定理の言明を変えないこと、`E_OpPrim` の保存、Http の対象健全性の例、`Benitoite.Core` が残ること、段階 E2 の11件の健全性と最小の型を返す検査の関数）を除き、篩付きの対応（`clauseIxCheck` の結論、`checkExprAt_sound` など七判断の健全性、`CheckInfer` と `Check` の二段の検査、`step_sound`、`StartCondition`、`ClosedNoLamNames`）に改めた。旧 Release は型の種類を検査しないが篩付きの核は検査する（R `Context/Declarations.lean` の `TypeArgsKindedAt`）ので、ハンドラと型クラスの行の「形式化の型付けは種類を検査しない」を旧 Release に限った。旧の `Model.assumptions`・`ModelTargets.assumptions`・`ModelHttp.assumptions` は定義がない（`formal/` の全体で定義を探した）ので、それを引く文を除いた |
| Lean のコメントの「die の先行モデル」 | 直した（7箇所） | R `Surface/Desugar.lean` 二箇所・`OpenSurface.lean`・`Property1Die.lean`・`Rules.lean`・`Surface/Syntax.lean`、旧 `Surface/Syntax.lean` | 01-12 の今の見出し「die のモデル」に改めた。コメントの行だけを変えた |
| Lean のコメントの 07-04「証明する性質」 | 直した（9箇所）・記録だけ（4ファイルの5箇所） | 直した: `Exchange/Builtins.lean`・`Convert.lean` 二箇所・`Syntax.lean`、`BuiltinCheck/Main.lean`・`CoverageDiff/Main.lean`・`CoverageProgramDiff/Main.lean`・`SurfaceCheck/Batch.lean` を「道具と置き場所」へ、`Exchange/CheckSupport.lean` を「篩を含む形式化の範囲」へ | 交換の入口と実行ファイルは今「道具と置き場所」が扱い、交換から作る材料の支持は「篩を含む形式化の範囲」の `Exchange.CheckSupport` の段落が扱う。R `Surface/ScopeSound.lean` 9行の参照は、「証明する性質」が `productionRules_sound` を今も扱うので残した。並行の担当が変更中の `Exchange/BuiltinAgreement.lean` 10行・`Exchange/CheckInput.lean` 7行と412行付近（「篩を含む形式化の範囲」の `standardCheck`・`closureOf`・`prepare` の段落へ改めるのがよい）、`SurfaceCheck/Main.lean` 4行（「道具と置き場所」）・`SurfaceCheck/Validation.lean` 4行（「道具と置き場所」）は変えていない |

検査: 共有ロックの下の既定の `lake build` は終了0（16:12〜16:30、2,323ジョブ、`sorry` の警告0件。`Surface/Rules.lean` のコメントの変更で依存するモジュールを再ビルドした）。`spec_coverage.py --self-test` と通常の実行は終了0。相対リンクと見出しの切れは0（01-12 の数式の字面の誤検出1件を除く）。01-12 の ```text のブロック24個は変えていない。

範囲の外で見つけ、直していないもの（取りまとめへ）:

- 07-04「進め方」の節の全体（段階 A〜E の表と完了の記述）は、削除した `Benitoite.Core`・旧 `Benitoite.Surface` の定義と証明を今の置き場所として書く（「段階 A の定義と証明は、`Benitoite.Core` に残す」「段階 C の定義と証明は…`Benitoite.Surface` に置き」、段階 E2 の11件の健全性など）。節の構成を書き直す判断が要る。
- Rust の試験のコメント4箇所（`crates/benitoite/tests/desugar_export.rs` 753行、`desugar_export/named.rs` 1行・459行、`desugar_export/named_calls.rs` 1行）も 07-04「証明する性質」を交換の根拠として引く。

### 取りまとめの判断の後の続き（三回目、2026-11-07 16:35〜16:45）

取りまとめの判断（「進め方」の節を今の構成に書き直し、段階の経緯を設計書に残さない。Rust の試験のコメント4箇所を「道具と置き場所」へ改める）に従った。

| 対象 | 処置 | 変えた場所 | 理由・確かめたこと |
|---|---|---|---|
| 07-04「進め方」 | 書き直した | 節の全体（見出しは変えていない） | 段階 A〜E の三つの表と完了の記述を除き、今の構成の五部分（篩付きの核、篩付きの表層、交換と7入口、旧 Release の共有の定義、区間解析）と独立の小証明の置き場所を表にした。完了の条件（`sorry` なし、標準の三公理だけ、仮定は「形式化で仮定するもの」だけ）と、レビューの後に証明へ入ることを【決定】として残した。網羅性の判定の段落は今の定理に合わせ、選ばれない選択肢の系が照合の上の選択（`AlternativeSelected`）までで、`firstAlt` への接続を含まないと書いた（R `Coverage.lean` 2119行）。検査器の段落は `CheckInfer` と `Check` の二段に改め、旧の11件の健全性と最小の型を返す関数の記述を除いた。見出しは、R の外の `Release/Syntax.lean` 10行のコメントが引くので保った |
| 「進め方」の外の段階の名前 | 直した | 07-04「道具と置き場所」の遷移を計算する関数の段落（段階 B1）、「01-12 との対応」の Lean を正とする【決定】（段階 A・B・C7）、「レビューと、見つかった誤りの扱い」の担当の【方針】（段階 A・B・C の経緯）、01-12 の効果の所属の段落（段階 B の写し） | 定義を除いた段階 A・B・C の名前を、今の部分の名前に改めた。担当の経緯は除き、担当は改造の計画で決めると書いた。段階 1・2（ロードマップの段階）と段階 E・E1・E2（「証明する性質」が定める）は今も定義があるので残した |
| Rust の試験のコメント | 直した（4箇所） | `crates/benitoite/tests/desugar_export.rs` 753行、`desugar_export/named.rs` 1行・459行、`desugar_export/named_calls.rs` 1行 | 07-04「証明する性質」を「道具と置き場所」に改めた。コメントの行だけを変え、`check_named.py` には触れていない。`rustfmt --edition 2024 --check` は三ファイルで終了0 |

検査: `spec_coverage.py --self-test` と通常の実行は終了0。相対リンクと見出しの切れは0（01-12 の数式の字面の誤検出1件を除く）。01-12 の ```text のブロックは変えていない。Lean は変えていないので、ビルドしていない。

範囲の外で見つけ、直していないもの:

- `formal/Benitoite/Release/Syntax.lean` 10行のコメントは、「進め方」とともに「段階 A（`Benitoite.Core`）の定義は…」と削除したモジュールを書く。この回は Lean を変えない判断なので、記録だけにした。
- `formal/README.md` の「レビュー」の節の、記録の置き場所を段階 A・B・C・E の名前で示す一文は、過去の記録の場所を示すものとして残した。段階の名前の定義は設計書から除いたので、読み手には記録の側の名前として読める。

## 処置の確認

2026-11-07。対象は作業木の HEAD `83ee549f` の `git diff 4823e272 HEAD -- docs/design formal/README.md` と、`formal`・`crates` のうちコメントだけを変えた行、上の「処置」の三回分と[書き直しの記録](../l70/g/docs-rewrite.md)の追記である。取りまとめが直した `formal/Benitoite/Release/Syntax.lean` の冒頭のコメントと `formal/README.md` の「レビュー」の一文、Lean の担当が書いた 07-04「篩を含む形式化の範囲」の照合の段落も見た。方法は初回と同じである（Lean のソースの grep、見出しと参照の `git grep`、01-12 の ```text のブロックの新旧の比較、spec-coverage の自己検査と通常の実行）。Lean・`lake build`・`scripts/check.sh`・git の書き込み操作は行っていない。変えたのは本節の追記だけである。

### 結論

**可。** 重1・中1・中2・軽1〜7・情1・情2・情4 は閉じた。新しく残る所見は軽2件・情報1件であり、受け入れを止めない。

### 所見ごとの確認

| 番号 | 判定 | 確かめたこと |
|---|---|---|
| 重1 | 閉じた | 07-04 の表の三行（1430〜1432行）は篩付きの名前だけで書かれている。`StateTyE.local_invariant`・`LocalStateInvariant`（R `LocalInvariant.lean` 133・144行）、`HasFixedQ.desugar`（S `Property1.lean`）、`block_step`（S `CheckExprSimpleSound.lean` 142行。S `CheckSound.lean` 52行が E_Block の場合に使う）、`Block.Exits`（S `Basic.lean` 370行）は実在する。捕捉禁止とセルの保持の三性質は「持たない」と書かれ、01-12「構築器の局所宣言と捕捉」と一致する。`toLocal_kindAt`・`congrΔ`・`builders_no_capture`・`ArgTypesQ`・corpus 13 は 07-04 から消えた |
| 中1 | 閉じた | 「道具と置き場所」の構築器・独立入力・Fail・try の段落は corpus 16・sidecar 8 に揃い、旧版の読者と `Surface.BuilderExamples` の記述は消えた。`Exchange.BuilderExamples` の段落は Lean の `#guard`（52〜57行）と一致する。838行の区間の全比較の段落も版 16/8 に改められた |
| 中2 | 閉じた | 01-12「die のモデル」の地の文は、show と exit を頭の型付けで検査し、純粋性と exit の種類を検査しないと書く。`Process.Exit` を ε が覆うのは exit の署名の効果が `Process.Exit` の表に限る、という条件も入った。S `Rules.lean` 827〜890行と S `Check.lean` 676〜740行に合う |
| 軽1 | 閉じた | 2822行は `HasFixedQ` になった |
| 軽2 | 閉じた | 1155行の名前は篩付きのものになった。`HasTypeVQ.closed_noLamNames` などは R `StartLamNames.lean` に実在する |
| 軽3 | 閉じた | 見出しは「Scope の必須の判定のプログラム全体の受理」に改められた。旧の見出しを引く箇所は、`docs/archive` と改造の過去の記録の外に残っていない。07-04 の44行と1427行は新しい名前を引く。spec-coverage は二つとも終了0 |
| 軽4 | 閉じた | 07-04 23・25行と 01-12 4461行の置き場所と前提は、R `MainEffects.lean` 111行と R `SurfaceMain.lean` 109行に合う |
| 軽5 | 閉じた | `Option BuilderReply` の none の二つの場合と `builderApply_value_scope` の前提と結論（`Ground` を含む）が、R `BuilderExec.lean` 58〜69行と R `BuilderValueTyping.lean` 137行に合う |
| 軽6 | 一部残る | 62行の定義の文は言い換えられた。ただし67行の「照合の対象の中の差は断る」が残り、定義を除いた語が一度だけ使われている（下の軽8） |
| 軽7 | 閉じた | 記録の表の `SingleFail` の右欄と綴り（`Limits`・`pres_failure`・`HasClausesQ.cons_sig_unique` など）は直った。`analyze_pending`・`renumber` の行は消えた |
| 情1・情2・情4 | 閉じた | 672行は `CoreAssumptions` になった。`BuilderExamples`・`FormatExamples` のコメントは、今その例を扱う節を引く |

### 二回目・三回目と取りまとめの直し

- 01-12 の `clauseIx` の項（545行）: `HasClausesQ.cons` は `ClauseSig D.core B εb o sg` を前提に持つ（S `Rules.lean` 986〜987行）。`ClauseIxOk` は Top か `Eff.ClauseRangeIs` で（R `HandlerContracts.lean` 30〜40行）、本文の「行の変数を持たず、l の原子を持ち、範囲の位置が全て同じ閉じた範囲 S」と一致する。`ClauseSig` の三つ目の連言（署名の行の範囲 `s.tel.RowsIn`）は書かれていないが、本文は添字の許し方を述べる文なので、前提の落としとはしない。
- 01-12 の表層のブロック式（480行）と die の `ExprSupport`（922行）: `Expr.Scoped`・`Expr.Exits`・`ExprSupport` と、性質 1 の E_Block の場合は実在する。
- 07-04「進め方」: 五部分の表は、README の「構成」の表と、既定 import の実際の構成（旧 Release の74モジュール、旧 Surface の3モジュール）に合う。網羅性の段落の `AlternativeSelected` は R `Coverage.lean` 2119〜2123行の言明に合う。設計書の章に段階 A〜C の名前は残っていない。段階 E・E1・E2 は「証明する性質」が定義する。
- 07-04 の表の旧 Release の行: 段の欄が「旧 Release の共有の定義（篩付きの核への埋め込みの定義域）」に揃い、表の前の説明（1381行）が二種類の行の読み方を書く。引く `stateTy_of_old`・`BuiltinOnly.iff_old` は既定 import の旧モジュールに実在する。
- `Release/Syntax.lean` の冒頭のコメント: 引く 07-04「進め方」の表の「旧 Release の共有の定義」の行が、埋め込みの定義域と書くので対応する。コメントだけの変更である。
- `formal/README.md` の「レビュー」の一文: 段階の名前を、過去の記録を作った当時の名前として読ませる書き方であり、設計書の定義を前提にしない。
- Rust の試験のコメント4箇所: 引く節は 07-04「道具と置き場所」になり、コメントの行だけが変わった。

### Lean の担当の照合の段落

07-04 62〜71行を `Exchange/CheckInput.lean`・`BuiltinAgreement.lean`・`CanonicalNames.lean` と照らした。`surfaceWords`（95行。欄 `core`・`dataTypes` を除く）と `closureOf`（116行。`impls` を空にして数え、名前が現れる実装だけを足す。演算子は値か欄の名前で数える）は本文と一致する。`Prepared.standardData`・`unknownBuiltins`・`canonicalRawSig`・`canonicalCons`・`canonicalAtoms` の欄、`DataAgrees`（構成子の数・型引数の数・同じ名前の構成子の引数の `tysEq`。順序は比べない）と `dataCheck`、`DataListAgrees`、`CanonicalNames.displayCounterparts`・`primitiveTargets` も、本文の説明と一致する。`prepare_agrees` の結論は二つの連言（`ShapeEq` の一致と `DataListAgrees p.canonicalAtoms p.canonicalCons p.standardData`）であり、`prepare_constraints` の結論（`canonicalSig n = normKeys raw` と `admits` の同値）も本文と一致する。

### 残る所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽8 | 軽 | 07-04 67行「照合の対象の中の差は断る」 | 軽6の処置で「照合の対象」の定義を言い換えたが、この句に語が残った。今は定義のない語である | 「`closureOf` の名前の中の差は断る」などに改める | 読めば確定 |
| 軽9 | 軽 | 07-04 71行「`tysEq` の一致は、標準の宣言の構成子の引数が照合の原子の一覧で支持されるとき等号になる（`tysEq_sound`）」 | `tysEq_sound`（S `CheckArguments.lean` 240行）は、比べる両方の列の支持（`ha`・`hb`）を前提に取る。本文は標準の側の支持だけを書く | 「両方の引数の列が原子の一覧で支持されるとき」とする | 読めば確定 |
| 情5 | 情報 | `Exchange/BuiltinAgreement.lean` 10行（この差分で書き直した行）、`Exchange/CheckInput.lean` 7行・412行、`SurfaceCheck/Main.lean` 4行、`SurfaceCheck/Validation.lean` 4行 | 交換の照合や入口を扱わなくなった 07-04「証明する性質」を、今も引く。処置の記録が「並行の担当が変更中」として残した箇所である。`BuiltinAgreement.lean` 10行は、今回の Lean の変更で書き直した行に残っている | 次の Lean の単位で、照合の三ファイルは「篩を含む形式化の範囲」、入口の二ファイルは「道具と置き場所」に改める | 読めば確定 |

### 公開の記録の決まりと文書の形

追加行に、docs/todo へのリンク、手元の絶対パス、`reference/`・`private/` の参照、【未決】【要検証】はない。01-12 の ```text のブロック24個は `4823e272` と一致する。新しい造語は見当たらない。

## 処置の確認の後の処置

2026-11-07、基準 `83ee549f`。結果は [results-claude.md](../l70/g/results-claude.md) の「処置の確認の後の処置」にある。

| 番号 | 処置 | 場所 |
|---|---|---|
| 軽8 | 「照合の対象の中の差は断る」を「`closureOf` が作る名前の中の差は断る」にした | 07-04「証明する性質」の照合の段落 |
| 軽9 | `tysEq_sound` の説明を、比べる両方の引数の列の支持を前提にする形にした。照合用の表の側の支持は形成の証拠にあり、標準の側の支持は示していない | 同上 |
| 情5 | 処置なし（取りまとめの判断） | — |
