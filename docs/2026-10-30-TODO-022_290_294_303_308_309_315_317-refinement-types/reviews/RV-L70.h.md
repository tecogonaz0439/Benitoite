# RV-L70.h: L70 群 H（段の公理監査・宣言の一覧・義務と申し送りの最終の判定）の独立レビュー

2026-11-07。対象はブランチ `m014/l70.h` の群 H のコミット `698f2350b`（基準 `084c8f6a8` からの差分）である。群 H2 の差分（`698f2350b..e447e3d6b`）は、群 H2 が足した [stage-results.md](../l70/stage-results.md) の段落と [verify.py](../l70/verify.py) の改めだけを、群 H の資料との整合の観点で読んだ。本書の `<repo>` は対象の worktree、`<tmp>` は会話の scratchpad の群 H の一時領域 `l70h/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回である。

読んだもの:

- 本体の作業木の依頼文 `work/m014/L70.h-claude-prompt.md` と報告 `L70.h-claude-report.md`。
- [群 H の結果](../l70/h/results.md)、[段末の資料](../l70/stage-results.md)、台本 [stage.py](../l70/h/stage.py)・[support.py](../l70/h/support.py)・[obligations.py](../l70/h/obligations.py)・[legacy.py](../l70/h/legacy.py)・[comments.py](../l70/h/comments.py)・[heartbeats.py](../l70/h/heartbeats.py)・[four.py](../l70/h/four.py) と各記録、[axioms.lean](../l70/axioms.lean)、[verify.py](../l70/verify.py)。
- [detail.md](../l70/detail.md) の第10.2節と L70.46・.47 の行、[tables.md](../l70/tables.md) の全行。四分類の定義は第10.2節が指す [l60/detail.md](../l60/detail.md) の第2.4節（l70 の第2.4節は表層の節で、四分類の定義はない）。
- 前の段の [l60/stage-results.md](../l60/stage-results.md) と `l60/h/` の台本の形。
- 本体の `C/plan.md` の確認点の先頭から 2026-11-06・07 の L70 の項目（556〜624行）。
- 照合のために、R の該当の Lean のソースと、段の開始版の旧の言明（`git show 657b3ae71:<ファイル>`）。

したこと:

- `<tmp>` に残る生の出力（`final-*.log`）から、宣言の数・名前の重なり・`AUDIT_UNRESOLVED` を作り直した。
- 依存の書き出しから逆向きの読者の表を作り、証拠の名前の読者と経路を照会した（`stage.merged` と `obligations.stage_path` を読み取りで呼んだ。記録は書いていない）。
- `toString (e : Expr)` の印字が束縛子の種類・宇宙の水準を含むかを、`import Lean` だけの小さな入力で確かめた（共有ロックの下で `lake env lean -M 12288` を一回）。
- `verify.py` は実行していない。`stage.analyze` が `h/` の記録を書き直してから比べるので、並行して読む群 H2 のレビューと記録を共有するためである。
- `lake build`・`scripts/check.sh`・段の開始版のビルド・git の書き込み操作・サブエージェントの起動はしていない。変更したリポジトリのファイルは本書だけである。

## 結論

**条件付き可。重0件、中5件、軽8件、情報4件である。**

公理監査の対象・件数・結論は、台本と生の出力で支えられている（情1）。主定理の対応、モジュールの増減、コメントの工程 ID の書き換え、heartbeat の除去、後段への義務の表の主な項目、設計者の見直しの対象の37項目も、記録と plan.md に合う。

ただし、次の五点は段末レビューの前に直す必要がある。

- 主な言明の型のハッシュは言明の中身を固定しない（中1）。
- 型だけの比較で「信頼条件は同じ」と読める書き方をしている（中2）。
- 義務と申し送りの完了の判定で、台本の検査の一つが常に真である。四分類を定義や帰納型に当てている（中3）。
- 読者の閉包に入らない証拠が27行にあり、表に示していない（中4）。
- 旧の性質の照合の「別の形」に、実際には失った保証が少なくとも二組ある（中5）。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | stage-results.md「主定理の一覧と型のハッシュ」の表、[audit-summary.json](../l70/h/audit-summary.json) の `required`、[axioms.lean](../l70/axioms.lean) の `SIGNATURE_BEGIN` の印字 | 主な言明17名は `Program → Builtins → PathEnv → Prop` などの関数型の定義である。そのため、型の SHA-256 は言明の本体を含まない。`ProgressStatement`・`PreservationStatement`・`StepsPreservationStatement`・`InitialTypingStatement`・`EffectSoundnessStatement`・`StepTargetStatement`・`ReachableTargetStatement`・`ReachableTargetEventStatement` の8名は同じ値 `e529d7e1…` を持ち、標準の表の言明4名も同じ値 `b4ea9790…` を持つ（`<tmp>/signatures.txt` で確かめた）。主定理の型も `∀ P B σ, ProgressStatement P B σ` の形なので、ハッシュは言明の名前しか固定しない。群 B の `StepTargetStatement` の変更のような本体の変更は、この77名の表では検出できない。「主な言明の変更は一つだけ」は `git diff` だけが支えている（`MainStatements.lean` の差分で確かめた。結論そのものは正しい） | 言明の定義は値（`ci.value?`）の印字の SHA-256 も記録する。主定理は、言明を一段展開した型（`whnfR` か `unfold` の後）の印字の SHA-256 も記録する。L60 の `h/definitions.md` のように、主な定義の本体の写しを一回分置く形でもよい。表の見出しを「型の SHA-256」から、何を固定する値かが分かる名前に改める | 読めば確定（印字の写しと表の値） |
| 中2 | 中 | stage-results.md「段で足した定義・言明・仮定」の46行（信頼条件）と、表の「同じ」の列。[stage.py](../l70/h/stage.py) の `states` | 全宣言の比較は型の印字だけで行う。定義の本体の変更と、型が参照する定義の変更は「同じ」に数える。表の前の本文はこのことを書いている。一方、仮定の節は「信頼条件: `CoreAssumptions`・`TargetAgreement`・`ExternalAssumptions`・`ValueAssumptions` の構成子の型は開始版と同じである」を、信頼条件が増えていない根拠として挙げる。欄の型が参照する `Step`（14構成子の型が変わった）・`HasTypeVQ`・`Val` は段で変わったので、印字が同じでも欄の意味は変わっている。直前の箇条（「参照先の定義は段で変わった」）と合わせて読まないと、信頼条件の中身が開始版と同じだと誤読させる。なお、64ビットのハッシュの使用は比較を弱めていない。`toString` の印字（`Expr.dbgToString`）は束縛子の種類・宇宙の水準・束縛名を含む（小さな入力で `{α}` と `(α)` の差、`Eq.{1}` の印字を確かめた）。比べるのは同じ鍵の組だけなので、偶然の衝突の確率は組ごとに約 2^-64 である | 46行を「構成子の欄の型の印字は同じであり、欄が参照する `Step`・`HasTypeVQ`・`Val` などの定義は段で変わった。したがって信頼条件の意味は変わり、新しい欄・構成子は足していない」の形に改める。できれば、欄の型の定数の閉包と「型が変わった」宣言の積を台本で一覧にする。「同じ」の列の見出しに「型の印字が同じ（本体は比べない）」と添える。定義（def・opaque）にも値の印字のハッシュを足すと、本体の変更を数えられる | 読めば確定。印字の性質は実行で確定 |
| 中3 | 中 | [obligations.py](../l70/h/obligations.py) 225行の `assert any(k == "theorem" …) or cls != SUB or True`、同ファイルの冒頭の説明、HANDOFFS・OBLIGATIONS の四分類の欄 | (1) 冒頭の説明は「『完了』の行の証拠に定理があること」を確かめると書く。しかし検査は `or True` で常に真である。完了の行のうち、証拠に定理が一つもない行が24ある（L60-受口1・L50-H08・L50-H28・L40-F05・L40-F07・L40-後段2・L30-A2・L30-A4・L20-J7・L00b-主・L00b-区間・plan-1101・plan-1102・plan-RV03・U02-署名・O005・O033・O043・O139・O140・O142・O143・O167・O169）。証拠は `Ty.LeQ`・`Program.WellTyped`・`IntervalReport.connect`・`PublicNames.safeEntries`・`RefinementBinderOk` などの定義・帰納型・構成子である。(2) l60/detail.md 第2.4節の四分類は、前提と結論を持つ欄（言明）の分類である。この24行の多くは定義を証拠にして「実質」と書くが、定義には前提も結論もない。証人も、群の四分類の表への総称の参照（`W_SURFACE` など）であり、行ごとの言明に当てたものではない | `or True` を外す。定義だけの行は、その定義を読む定理（読者の主定理の場合）を証拠に加える。又は四分類を「対象外（定義）」とし、読者の定理の分類を別の列に書く。冒頭の説明を実際の検査に合わせる | 読めば確定 |
| 中4 | 中 | [obligations.json](../l70/h/obligations.json) の `unread_evidence`、[obligations.md](../l70/h/obligations.md) の冒頭（「読者の…閉包に証拠が含まれることを…確かめた」）、stage-results.md「義務と申し送りの最終の判定と残る所有」 | 台本は、各読者に証拠のどれか一つが閉包にあれば通す。読まれない証拠は `unread_evidence` に記録するが、検査で落とさず、表にも示さない。27行に読まれない証拠がある。主なものは次のとおりである（逆向きの読者の照会で確かめた）。`step_external_selected`（L60-受口3。環境の中に読者がない。進行・step_sound が読むのは `StateTyE.external_response_step` だけ）、`ExternalNominal.transformations`（O087。読者0）、`Detail.values_typed`（L50-H31。`progress` の閉包にない）、`steps_preservation`（L50-実行。`surface_target_sound` と `reachable_target_sound` の閉包にない）、`ExternalSurface.call_typed`（L60-受口2・O088。`desugar_typed` の閉包にない）、`Check.checkExprAt_sound`（O037）、`complete_shapeOk_composed`（L60-仮定150）、`CheckAccept.checkProgramAccepted_sound`（L60-H30・O086・O121。実行ファイルの根は定理を読まない）、`Surface.HasTypeQ.desugar`（18行）。基準が「名前の一致だけで判定しない」ことなので、表の見かけの証拠と機械で照合した証拠が食い違う | obligations.md に「読者の閉包にない証拠」の列を足す。各行で、(a) 証拠から外す、(b) 閉包に入る名前へ替える、(c) 読者を要しない理由を書く、のどれかにする。L60-受口3 は、step_sound の外部の場合が実際に読む補題を確かめて証拠を改める。`HasTypeQ.desugar` は相互帰納の共通の補助（`HasBlockQ.desugar` と同じ相互ブロックの定数）を経路として示すか、注記を表に出す | 読めば確定（依存の書き出しの照会） |
| 中5 | 中 | [legacy.py](../l70/h/legacy.py) 82・83・87行（`checkMatch_unreachable_runtime`・`_of_C_Match`・`SlotsOk`）、139・140行（`widenRanges`・`widenPathIn_target_unique`）、stage-results.md 254行「旧の言明は `git show <B_STAGE>:<ファイル>` で読んだ」 | (1) 旧 `checkMatch_unreachable_runtime` は、到達しないと報告した腕が実行時に選ばれない（`¬ RuntimeSelected`）ことを、`SlotsOk` の下で結論していた。篩付きの `checkMatchWithView_unreachable_sound` が結論するのは、照合の上の `¬ AlternativeSelected` だけである。R の中に `RuntimeSelected` と `SlotsOk` はなく、`AlternativeSelected` の読者は網羅性の補題と例だけである。`Coverage.lean` 1827行の説明は「firstAlt と実行の規則への接続には、slots が整うという前提が必要である」と書いており、`E_MatchSkip`・`E_MatchBody` へ結ぶ定理はない。到達しない腕の判定の実行の意味は失われており、「別の形」ではない。(2) `widenRanges`・`widenPathIn_target_unique`（明示拡大の行き先が戻り値の注釈から一意に決まること）の根拠 `OpenScopeAccept.contextsBlock_length` は文脈の列の長さの補題で、拡大の行き先を述べない。R の中で `widen` は署名の表と名前の表にしか現れない。(3) results.md「計画からのずれ」は、旧の言明の全文を読んだのは候補と迷う行に限ると書く。stage-results.md の254行は全行を `git show` で読んだように書き、食い違う | (1) の3名を「失った」（実行の観測。重い）に改める。docs/todo の候補の題は「網羅性の到達しない腕の判定を篩付きの実行の規則へ結ぶ」とする。(2) の2名は、篩付きの受理で行き先を決める実際の箇所を探して根拠を替えるか、「失った」（受理）にする。(3) stage-results.md を results.md の書き方に揃える。「別の形」70行のうち全文を読んでいない行は、旧の言明の結論が根拠の名前の結論に含まれるかを再度確かめる | 読めば確定（名前と接続の不在）。導けないことの証明はしていない |
| 軽1 | 軽 | [legacy.py](../l70/h/legacy.py) の `main_never_passwd`・`no_write_event_passwd`・`ioCall_no_passwd`・`handleLog_never_observes_data`・`program_target_sound`・`desugared_typed`（導ける）と `main_reach`・`wrong_rule_unsound`・`emit_checked`（失った）、86行の `Release.CoverageExamples` | 具体のプログラムの例について、判定の基準が揃っていない。前の6名は「具体例は置いていない」と書いたうえで「導ける」とし、後の3名は同じく具体例がないので「失った（軽い）」とする。主定理の適用で導けるのは一般の言明であり、具体のプログラムで前提を満たすことは示していない。`Release.CoverageExamples` は「同じ組かは確かめていない」としながら「別の形」とする | 具体例の行は一つの基準で判定する（例: 具体例がなければ「失った（軽い）」、一般の言明は主定理で導ける、と分けて書く）。確かめていない行は判定を確定せず、未確認として残す | 読めば確定 |
| 軽2 | 軽 | obligations.md の L60-H02・L50-H03・L60-受口5、tables.md の各行の「完了の判定」 | (1) L60-H02: tables.md の基準は「進行の外部参照の場合が名前付きの読者になる」である。`StateTyE.externalRef_contract_inputs` は最終版にあるが、読者は0である。`E_ExternalApply` は前提を持たない（Semantics.lean 84行）ので、読者を要しない判断の中身は妥当である。しかし証拠は `progress` だけで、この理由を示す名前になっていない。(2) L50-H03: 基準は「進行の正常応答の場合」である。`normal_facts` の4名（ScopeResponse・ModelTargets・ModelHttp・StandardModel）はどれも読者が0である。証拠の `composed_rows` は `included_guarantees` が読むが、`progress` の閉包にはない。進行が任意の B の信頼条件の欄から正常応答を読むことを示す名前がない。(3) L60-受口5: `ModelCase.composition` の閉包に `ExternalModel.external_assumptions` がある（経路の長さ3）。基準の中身は支えられ、無名の例を機械で照合できない点も記録どおりである。ただし判定「記録」と四分類「実質」の組は、ほかの「記録」の行（対象外）と揃わない | (1) 証拠を `Step.E_ExternalApply`（前提なし）にし、基準を改めた理由と、読者のない `externalRef_contract_inputs` を記録に残す。(2) 進行が読む信頼条件の欄の名前を証拠に加え、読者を `progress` にする。基準を改めたことを書く。(3) 判定を「完了（L70 の分）」にするか、四分類を対象外に揃える。3行の判断は、この形に直せば妥当である | 読めば確定 |
| 軽3 | 軽 | obligations.md の O159・U02-署名 | O159 は「完了（L70 の分）」なのに証拠の完全名がない（第10.2節の「完了と書くときは、証拠の完全名…を同じ行に書く」に合わない）。U02-署名の「残る段」は「L70.37・.38 で δ の行（群 F2）」で、L70 の中の単位を残る段に書いている | O159 は判定を「完了（記録）」にするか、証拠（f09.json の照合の名前など）を書く。U02-署名は群 F2 の完了を確かめ、残る段を「なし」か後段の名前にする | 読めば確定 |
| 軽4 | 軽 | [four.py](../l70/h/four.py) と [four.json](../l70/h/four.json)、stage-results.md「四分類の最終件数」 | 集計は見出しか表の頭に「四分類」を含む表だけを拾う。群 C の「空疎でない証人と三モデル」の表、群 E3 の表（「一般の書換えでは不成立」・「未実装」の行）、群 G・K2 の表は入っていない。それなのに「各群の results.md の条件の四分類の表（12節）」を全体の集計のように書く | 拾わなかった群と表を明記するか、拾う規則を広げる。E3 の「不成立」行は、閉じた言明の不成立でないことを一文で書く | 読めば確定 |
| 軽5 | 軽 | stage-results.md 184行、[heartbeats.json](../l70/h/heartbeats.json) の `inherited_by_file` | 依頼の (f) は全箇所について既定値で timeout することの記録を照合することを求める。段の前からの330箇所は、ファイルごとの件数だけを数え、記録との照合をしていない。「前の段までの記録のものである」は台本が支えない | 330箇所は照合の対象外としたことを「計画からのずれ」に書くか、前段の記録への対応を台本で付ける | 読めば確定 |
| 軽6 | 軽 | [required-names.json](../l70/h/required-names.json)、obligations.py の `MAIN_READERS` | 77名は、収集と標準の表の言明8名（`Program.ExtendsTypingStatement`・`ExtendsExhaustiveStatement`・`ExtendsDeclarationStatement`・`ComposeStatement`・`StandardModel.ComposedRowsStatement`・`ComposedReleaseStatement`・`TableConditionsStatement`・`CompletionCoreStatement`）を含む。一方、それを結論とする定理 `Program.extends_typing`・`extends_exhaustive`・`extends_declaration`・`Program.compose`・`StandardModel.composed_rows`・`composed_release`・`table_conditions` は含まない（逆向きの照会で、これらが言明の唯一の読者であることを確かめた）。読者の28組は核の言明9名だけを扱い、7入口の根のうち `builtinCheck`・`surfaceCheckAll`・`coverageProgramDiff` を扱わない。`("main", …)` は、`merged` が最初に置いた根の `main` に頼っている | 7定理を必須の名前に加え、言明との読者の組を足す。残る3根の読者の組を足す。`main` は `main@@DesugarDiff.Main` と明記する | 読めば確定 |
| 軽7 | 軽 | stage-results.md 266〜272行の候補の表、339行以降「段末レビューへ渡す点」の一つ目、「設計者の見直しの対象」#2 の影響、[legacy.md](../l70/h/legacy.md) の冒頭 | 群 H2 が「失った」31行のうち27行を述べ直した段落と表を足した。しかし、群 H の部分は「docs/todo の候補5項目」「重い3項目を後段のどこで述べ直すか」のまま残り、同じ資料の中で食い違う | 候補の表を、述べ直していない4行（`Prepared.writeEffNames`・`writeEffNames_complete`・`requestLitBound_known_ports_wf`・`analyzeBody_numbered`）と中5で加わる行に改める。段末レビューへ渡す点と #2 の影響を群 H2 の後の状態に合わせる。legacy.md に群 H2 の後の判定を指す一文を置く | 読めば確定 |
| 軽8 | 軽 | stage-results.md「後段へ送った義務と申し送り」 | plan.md 561行の (2)「処理系の実装の範囲は R 段で設計書へ反映して改造の終わりに整合を確かめる」（07-04「目的と範囲」の篩型の記述）が、35行に入っていない。群 G の分類（`Http.sendIn`・At・結果型の篩・取得関数の差・`unknownBuiltins`）と R50 の接続の義務（閉包の外の行、`DefSupport`・`ImplSupport`、data の欄と `extensible`、完成表との接続）は全て入っている。件数は群 G の最新の集計（results-claude.md の20・22・23）と一致する | R 段の文書の反映の行を足す（受け持つ単位 R 段の各段・改造の終わり、0件にする条件「07-04 の範囲の記述が処理系の実装と一致する」） | 読めば確定 |
| 情1 | 情報 | [axioms.lean](../l70/axioms.lean)、[stage.py](../l70/h/stage.py) の `analyze`、`<tmp>/final-*.log` | 公理監査の対象・件数・結論は、台本と出力で支えられている。所属モジュールの名前で選び、印字が実体化する宣言も2巡の不動点まで含める。private・生成宣言（実体化された核の等式の補題を含む）・構造体の欄・マクロのスコープを持つ名前（`collectAxioms` で直接調べた39）が入る。根ごとの環境の同名（`main` など）は根ごとに監査し、部分ごとに許可の集合を確かめてから合わせる。`library_modules == default` の表明があり、全7根の閉包のモジュールは `Benitoite` か入口の接頭辞で始まり、選択から漏れるものは0である（作業木の import の表で確かめた）。生の出力から作り直すと、`NODE` の行は122,832、異なる名前は122,817で、差の15は6名（`main`・`run` など）の根ごとの重なりである。`AUDIT_UNRESOLVED` は0である。`#print axioms` の出力の名前と `NODE` の名前の集合の一致の表明が通っているので、印字の逃げ（`«»`）による取りこぼしもない | なし | 実行で確定（生の出力の再集計） |
| 情2 | 情報 | 群 H の Lean の差分（16ファイル） | コメントの79件の書き換えを全て読んだ。工程 ID を除いた文と、設計書の節の名前への置き換え（07-04「篩を含む形式化の信頼条件」「篩を含む形式化の範囲」「形式化で仮定するもの」は 698f2350b の 07-04 にある）で、意味は保たれている。「R40 の後の標準ライブラリは精密側を指す」を「公開名は精密側を指す」とした箇所は、Lean の `FunctionNames.publicTarget` の写像としては正しい。処理系の切替の義務は後段の表の15行にある。`PredicateSimulationAlgebra.lean` 189行の除去は、外した写しの単独の検査（終了0、28.3秒、出力なし）と、除去の後の既定ビルドで支えられている。残した6箇所は、外すと既定値で timeout した記録がある | なし | 読めば確定 |
| 情3 | 情報 | stage-results.md「設計者の見直しの対象」 | plan.md 556〜624行の L70 の項目のうち、太字の「設計者の見直しの対象」を持つ37項目（587行の停止の条件の改めを除く）と一対一に対応する。項目ごとの選んだ案・退けた案の写しを、小項目の番号（556行・561〜563行・570行の (1)・(2)）まで照らして食い違いはなかった | なし | 読めば確定 |
| 情4 | 情報 | [verify.py](../l70/verify.py)（群 H2 の改め） | 群 H の範囲の照合（コメントを除いたコードの一致、heartbeat の一行の除去）と、群 H2 の照合（B_H の行を消さないこと、追加モジュールの既定 import）は、群 H の資料と整合する。ただし、3 の再計算は `stage.analyze` が `h/` の記録と `<tmp>` の名前の一覧を書き直してから比べる。並行して読む担当がいると、途中の状態を読ませうる。6 の件数の照合は `str(n) in text` なので、28・70 のような小さな数は本文のどこかにあれば通り、検出力が弱い | 再計算の出力を一時領域へ書いて比べる。小さな数は表の行の形（`| 導ける | 28 |` など）で照合する | 読めば確定 |

## 観点ごとの根拠

### 1. 公理監査の対象と件数

情1のとおりである。依頼の (c) の「外していた名前の件数」は、最終版の39と開始版の28を報告している。群ごとの台本が外した名前に限った件数ではないが、全てを監査に含めたので結論は変わらない。

### 2. 宣言の比較

中1・中2のとおりである。モジュールの増減（足した370・削除145・`LegacyCheck` の差1）と、旧主定理17行の対応（`old_main` の全行で、開始版にあり・最終版になし・新しい名前が最終版にあり）は記録で確かめた。

### 3. 読者の照合

経路は、型と値の定数を辿る最短の経路で求めている（`stage_path`）。名前の一致では判定していない。主定理と言明の型の読者は、型の定数の直接の参照で照合している。弱いのは、行ごとに「証拠のどれか一つ」で通す点（中4）、主な言明の全部を扱っていない点（軽6）である。

### 4. tables.md の137行

証拠の完全名を、Lean のソースで20名確かめた。全て宣言として存在し、名前空間も記録どおりである。確かめたのは `normal_facts`・`externalRef_contract_inputs`・`ModelCase.composition`・`ExternalModel.external_assumptions`・`pathBases_never_handled`・`obs_allowed`・`typed_nonempty_coverage`・`safeEntries`・`RefinementBinderOk`・`embedProgramWellTyped`・`Includes.constructor_entry`・`publicTarget_defs`・`IPPattern.mappedOnly_iff`・`outsideAllEnvs_iff_checkAt`・`erase_typed`・`StateTyE.app_inputs`・`ContTy.release_response_exists`・`InitialPrepared`・`Detail.publicTree_typed`・`constructor_exhaustive` である。

「完了（L70 の分）」の行は残る段を同じ行に持ち、他段の3行（L40-O135・O170・O027）を完了にしていない。問題は中3・中4・軽2・軽3のとおりである。

### 5. 後段への義務の表

軽8のほかに漏れは見つからなかった。群 G の F-REG の表は版が二つある。g/results.md 425行の古い表には `Http.sendIn` 1,454・鍵の印11 がある。後の results-claude.md の表では `Http.sendIn` 20・At 22・結果型の篩23・鍵の印0 である。35行は後者に従っており、正しい。

### 6. 旧の性質の照合

15行を旧の言明と照らした。`builders_no_capture` 系の「別の形」は妥当と読んだ。篩付きの核の `LocalStateInvariant` が、型付きの値に自由な専用参照がないこと（`∀ … HasTypeVQ … v → v.NoFreeBuilders`）を状態の不変条件として述べ、`hideBuilders` が節・遅延の本体の型付けに入る。実行時に専用セルが漏れないという観測の上の保証は保たれる。脱糖の出力の構文の性質を述べないことは legacy.md に書いてある。`builderOp_empty_rejected`（検査器の健全性と型付けの逆転で導ける）、`noRules`・`main_typed_eff`・`Limits`・`SingleFail`（同じ役割の名前が R にある）も妥当である。誤りは中5の5名、基準の不揃いは軽1である。

### 7. コメントと heartbeat

情2・軽5のとおりである。

### 8. 設計者の見直しの対象

情3のとおりである。

## 確認用の入力と出力

`<tmp>` の外の確認用の入力は、会話の scratchpad の `rvh/` に置いた（`probe.lean`・`q.py`・`deps.pickle`）。リポジトリには置いていない。

## 処置の確認

2026-11-08。対象は `7069a03ff..9f6ff959f` の差分（群 H3 の監査の担当・Lean の担当、群 H4）である。[h3/results.md](../l70/h3/results.md)、[h3/legacy-recheck.md](../l70/h3/legacy-recheck.md)、[h3/trust.md](../l70/h3/trust.md)、[h3/obligations.md](../l70/h3/obligations.md)、`axioms.lean`・`h/stage.py`・`verify.py` の差分、stage-results.md の該当の節、`formal/` の heartbeat の差分を読んだ。`verify.py --tmp <群 H3 の一時領域> --h2-tmp <群 H2 の一時領域>` を一度実行した（終了0、外側3分24秒）。前後で `git status` に差はなく、記録を書き直していない。Lean の述べ直しの中身は RV-L70.h2 の担当が確かめるので、本節では見ていない。

**結論: 可。** 所見の中1〜中5・軽1〜軽8・情4は全て閉じた。新しい所見は軽1件・情報2件で、段末レビューの前提を変えるものではない。

| 所見 | 確認 |
|---|---|
| 中1 | 閉じた。`axioms.lean` が、必須の名前の定義は本体を、定理は型に現れる主な言明を `Meta.deltaExpand` で一段展開した型を印字する。`stage.py` がその SHA-256 を記録する。`shared_contents` が空であることを `verify.py` が表明し、主な言明の8名が同じ値になる件は解消した。展開は一段だけだが、言明が参照する判断・定義の変更は、全宣言の比較の本体のハッシュ（中2）で数える形になっている |
| 中2 | 閉じた。定義・opaque の本体の構造のハッシュ（`Expr.hash`）を比較に足し、群 H が「同じ」とした714宣言を「本体が変わった」に分けた。`trust.py` が信頼条件の7構造体を比べる。欄・構成子・親の構造体の増減が0件であることと、閉包3,270定数のうち468が違うこと（型59・本体46・構成子の列3・足した247・閉包に入った17・削除56・外れた40。和が468）が [trust.md](../l70/h3/trust.md) と一致する。stage-results.md 51行は「欄の型の印字は同じでも、欄が量化する判断の意味は段で変わった。新しい独立の信頼条件ではない」と書き、誤読の余地はなくなった |
| 中3・中4 | 閉じた。`or True` を除き、実質の行に定理を、読者を持つ行に全証拠の閉包を要求する形になった。判定・四分類が変わった8行と右端の直しの列を読み、次の4行の基準も確かめた。L60-H02 は証拠を前提のない `Step.E_ExternalApply` にし、基準を改めた理由と読者のない補題を書いた。L50-H03 は `ResponseAssumptions.delta_typed` を証拠にし、読者を `progress` にした。L60-仮定150・O087 は、読者のない補題を除いても行の主張が残る理由（`complete_agree`、`Includes.externalWF`）を書いた。どれも妥当である。L40-後段2 と L60-受口5 は証拠と読者が同じ名前である。前者は証人 `first_failure_witness` が定理を読むことを台本で照らし、後者は無名の例のためであり、注記どおりである |
| 中5 | 閉じた。98行の全てで旧の宣言の全文と根拠の定理の言明を読み、前提・結論・量化を並べる方法でやり直した。25行を改め、指摘の5名は「失った（重い）」とし、述べ直しの定理の名前を付けた。具体例の基準もそろえた（軽1）。「別の形（旧の判断どうし）」9行は取りまとめの判断（D29）によるもので、根拠を明記している |
| 軽2〜軽8 | 閉じた。O159 は「完了（記録）」、U02-署名は後段の R10a に改めた。`four.py` は表を持たない群を記録する。heartbeat は、段で変えていないファイルの281箇所を開始版と同じ内容として記録する。段で変えたファイルの49箇所は外した写しで検査した。必須の名前に7定理と残る3根の読者を加えた。stage-results.md の候補の表と段末レビューへ渡す点を改め、後段への義務の36行目を足した |
| 情4 | 閉じた。`verify.py` は、記録を `mkdtemp` の一時の場所に作り直し、h3/ の14記録と h2/audit.json を内容の SHA-256 で照らす。h2/audit.py の書き込みは差し替える。件数の照合も表の行の形（`| 状態 | 件数 |`）になった |
| 公理監査の数 | 群 H3 の一時領域の生の出力から数え直した。`NODE` の行は126,442、異なる名前は126,427で、`audit_targets` と一致する。必須の名前は main 84・H2 44・H3 86・H4 89・H3A 2 の和305のうち、重なりを除いて304である |
| heartbeat | HEAD の設定は310箇所で、`7069a03ff` からの差分は除去34行・追加0行である。34箇所を同時に外した既定ビルドの終了0と、残す15箇所を外した後のファイルで再び検査した記録（全て上限に達した）がある。取りまとめの判断で認めた変更の範囲に収まる |

新しい所見:

| 番号 | 重さ | 場所 | 内容 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 確軽1 | 軽 | `h/stage.py` の冒頭の説明（「定義・opaque の本体の印字のハッシュで行う」） | 実装と `axioms.lean`・h3/results.md は、印字ではなく構造のハッシュ（`Expr.hash`。束縛子の名前と種類を含まない）を使う。説明だけが古い | 説明を「本体の構造のハッシュ」に改める | 読めば確定 |
| 確情1 | 情報 | h3/results.md「検査」と「取りまとめの判断の後の Lean の変更」 | 段の公理監査の名前の数が、126,430（H4 の後）から126,427（34箇所の除去と2定理の追加の後）に減った。2定理を足したのに3減った理由が記録にない。生の出力の数とは一致しており、監査の結論は変わらない | 差の内訳（`set_option … in` を外したことで変わった生成宣言の名前など）を一行で記す | 実行で確定（数の一致）。差の原因は調べていない |
| 確情2 | 情報 | `verify.py` の出力の `undocumented_h3` | 群 H3・H4 の必須の名前のうち85名（補助と例）は、01-12・07-04・README に名前がない。照合はこの一覧を出すだけである | 文書に載せるかどうかは、報告の判断点3のとおり取りまとめが決める | 実行で確定 |
