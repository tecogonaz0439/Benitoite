# RV-L70.h2: L70 群 H2（削除で失った保証の述べ直し）の独立レビュー

2026-11-07。対象はブランチ `m014/l70.h` の HEAD `e447e3d6b` と、群 H のコミット `698f2350b` との差分（24ファイル）である。旧の言明は段の開始版 B_STAGE `657b3ae713040e78826d2f19cd7b8ac9f415a6d6` で読んだ。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-h2/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回である。

読んだもの:

- 本体の作業木の依頼文 `work/m014/L70.h2-claude-prompt.md` と報告 `L70.h2-claude-report.md`、[群 H2 の結果](../l70/h2/results.md)、[群 H の旧の性質の照合](../l70/h/legacy.md)、[段の結果](../l70/stage-results.md)の「旧の性質の照合」と群 H2 の段落、[changes.json](../l70/h2/changes.json)・[audit.json](../l70/h2/audit.json)の集計。記録の形は [RV-L70.k2](RV-L70.k2.md) の初回の部分に倣った。
- 新規の `R/BuilderStore.lean`・`R/Surface/ScopeEval.lean`・`R/Surface/ScopeReach.lean`・`R/Surface/ScopeConnection.lean`・`R/Surface/ScopeConnectionExamples.lean`・`R/SurfaceTargetReachExamples.lean`・`R/SurfaceTargetObservedExamples.lean`・`R/Surface/LogExamples.lean`・`R/Surface/FailureExamples.lean`・`R/FailureExamples.lean`・`R/Surface/BuilderExamples.lean` の全文と、`R/HandlerStoreExamples.lean`・`R/Surface/CheckSupport.lean`・`formal/Benitoite.lean` の差分。照合のために `R/StateTyping.lean` の `CellOk`・`BuilderCellOk`、`R/ReferenceStore.lean` の `CellOk.store`、`R/Surface/ScopeAccept.lean` の `acceptOccurrence`・`acceptCall`・`absoluteRanges`、`R/Surface/OpenScopeAccept.lean` の `acceptBody`・`selections`・`selectExpr`、`R/Surface/ScopeLower.lean` の `analyzeExpr`、`R/Surface/ScopeRules.lean` の `requestLitBound`、`R/Surface/ScopeSound.lean` の `productionRules_sound`、`R/Surface/Syntax.lean` の `Expr` を読んだ。
- 旧の証明（B_STAGE）: `Release/Lemmas/BuilderStore.lean`・`Surface/CheckPredicates.lean` の `interpAllowed_spec`・`Surface/ScopeLower.lean`・`Surface/ScopeSound.lean`・`Release/TargetReachExamples.lean`・`Surface/LogExamples.lean` の定理の一覧、旧の 07-04 の Scope の二行と到達先の対象健全性の段落。
- 01-12・07-04・`formal/README.md` の差分、`l70/verify.py` の差分。

したことは、旧と新の言明の行ごとの読み合わせ、本番の読者の照会、接続定理の前提の充足と量化の範囲の確認、例の前提と結論の読み合わせ、文書と Lean の言明の照合である。Lean は `<repo>/formal/` から共有ロックの下で `lake env lean -M 12288 <tmp>/check1.lean` を一回実行した（検査1。終了0）。`-o` は使っていない。

`lake build`・`scripts/check.sh`・台本の実行・git の書き込み操作は行っていない。変更したリポジトリのファイルは本書だけである。

## 結論

**条件付き可。重0件、中1件、軽7件、情報4件である。**

重い18行は全て、旧の意味を弱めずに篩付きの核と表層で述べ直されている。前提が増えたのは `capture_builder_cell` の `B.ValueAssumptions P`（主定理の `CoreAssumptions` の一部）と、`scope_local_typed` の値の形の条件（篩付きの V_Checked・V_CheckedRequest の前提そのもの）だけである。接続定理の前提は「本体の受理と出現の所属」から「出現の受理」（`OccurrenceAccepted`）へ弱まり、閉じた由来の本体の受理を前提にとる系（`*_at`）が旧の言明と同じ前提を与える。範囲 S の結論は、旧の全称と別定理の存在を合わせた存在の形で、同値である。呼び出しの範囲の列を `fixedRanges rs` に限ったことは量化を狭めない。規則を持つ出現の受理は範囲の列が全て絶対の固定範囲であることを含むからである（検査1）。接続定理の前提は `ScopeConnectionExamples` の具体の受理と到達で満たされ、空疎でない。表層の対象健全性の全前提は `main_reach`・`main_observed` の具体の main で満たされ、観測が空でない事象へも到達する。

条件は中1の処置である。旧の `wrong_rule_unsound` は handle の節の添字の許容（`ClauseIxOk`）が要ることを示す反例で、旧の 07-04 が名指していた。新しい反例は、範囲を照合しない効果の包含が不健全であることを示す別の性質であり、`ClauseIxOk` の必要性は述べ直されていない。results.md と件数は、この行を「述べ直した」に数えている。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | `R/SurfaceTargetObservedExamples.lean` の `NameOnlyCovers`・`WrongTyped`・`wrong_rule_unsound`、results.md の `wrong_rule_unsound` の行、stage-results.md の件数（軽い9） | 旧の反例は、本番の `C_Handle` の前提のうち節の操作の型（`ClauseIxOk` と `opSigAt`）だけを許容を問わない形に替えた誤った規則 `WrongHandleTyped` で、節の添字 `/etc/**` の handle を型付け、実行が初期の効果の許さない `/data/a.txt` を観測することを示した（旧 07-04 の到達先の対象健全性の段落が `wrong_rule_unsound`・`handleEtc_rejected` を名指す）。新しい `WrongTyped` は、本番の型付けで得た効果を範囲を照合しない包含で事後に広げる関係であり、型付けの規則の一つを替えたものではない。示すのは「範囲を見ない包含は不健全」であり、旧が示した「節の添字の許容は要る」ではない。篩付きの核は `ClauseIxOk` を持つ（`R/HandlerContracts.lean:34`）ので、同じ対照を置く対象はある。results.md の「旧との違い」の欄は誤りの規則が違うことを書くが、行の判定と件数は述べ直したとしている | 次のどちらかにする。(i) 篩付きの核で旧と同じ対照を置く。`HandlerContracts` の `ClauseSig` から `ClauseIxOk` だけを外した誤った節の型付けで、範囲付きの書き込みの節を持つ handle を型付け、実行の観測が上限に許されないことを示し、本番の型付けがそれを認めないことを `reachable_target_sound` から導く。(ii) 置けないなら、この行を「別の対照に置き換えた」として述べ直した件数から外し（重い18・軽い8・置き換え1・述べ直していない4）、`ClauseIxOk` の必要性の反例を取りまとめが docs/todo に回す。どちらでも、新しい反例は範囲の照合の必要性の例として残してよい | 読めば確定 |
| 軽1 | 軽 | `R/BuilderStore.lean:22-27` の `OrdinaryStoreEq.symm`・`trans`、results.md の `OrdinaryStoreEq` の行 | results.md は「旧の `symm`・`trans` は読者がないので置いていない」と書くが、二つの定理は置かれている。本番にも例にも読者がない（`git grep` で `BuilderStore.lean` の外に参照がない）。依頼文の「読者のない補題を残さない」に反する | 二つを除くか、`HandlerStoreExamples` に適用例を置く。results.md の記述を実物に合わせる | 読めば確定 |
| 軽2 | 軽 | `R/Surface/ScopeConnection.lean` の `http_check_connection` の引数 `facts`、01-12「Scope の局所解析の接続定理」の表の `http_check_connection` の行 | (1) `facts : String → Option Range` は明示の引数だが、結論にも他の前提にも現れず、`productionRules_sound` に渡すだけである。どの値を渡しても同じ定理になる（例は `fun _ => none` を渡す）。使わない前提に当たる。(2) Lean の前提 `hne : ok ≠ "Result.Error"` が 01-12 の表の前提の欄にない | (1) 証明の中で `fun _ => none` を渡し、引数から外す。(2) 01-12 の表の前提に「`ok` が `Result.Error` でないこと」を足す | 読めば確定 |
| 軽3 | 軽 | results.md の `analyzeBody_numbered`・`requestLitBound_known_ports_wf` の行、01-12・07-04 の Scope の節 | 見送りの理由「旧でも読者がなかった」は、`analyzeBody_numbered` について事実と違う。旧の `Surface/ScopeLowerExamples.lean:294` が具体の本体に適用していた。また旧の 07-04 は両者を性質として名指していた（「記録は束縛番号の新規性の不変条件を満たす（`analyzeBody_numbered`）」「最小が最大より大きい組は未知（Top）にする（`requestLitBound_known_ports_wf`・`requestLitBound_known_wf`）」）。後者は篩付きの `requestLitBound` の定義の `if (…).WF` で読めば成り立ち、述べなくても失う保証はほぼない。前者は篩付きの解析で確かめていない | `analyzeBody_numbered` は、述べ直すか、理由を「接続定理の証明に使わない。旧の読者は例だけだった」に改めて docs/todo に回す。`requestLitBound_known_ports_wf` は理由を「定義の条件から直ちに従う」と書き、要るなら一行の補題と適用例を置く | 読めば確定 |
| 軽4 | 軽 | 01-12「Scope の局所解析の接続定理」の `ScopeReach` の段落、07-04「証明する性質」の Scope の接続の行と表の行 | 到達の関係 `ReachAtExpr` は、文を含む本体へ下りる形（ブロック・分岐・照合・ラムダ・遅延・handle・失敗の節・with・呼び出しの頭と引数）だけを辿り、二項演算・構成子の呼び出し・レコード・リスト・パイプ・try・resume・補間などの部分式の中の文には到達しない。局所解析（`analyzeExpr`）もそこに記録を作らず、受理は `factFree` で読む。この範囲は旧と同じであり弱化ではない。ただし旧の 07-04 は「記録の番号の一意性、定数の埋め込み本体と辿らない式の内側の地点は結論しない」と書いていたのに、新しい文書は「表層の具体の評価と核の実行の一致は結論しない」だけを書き、この限界が落ちた | 01-12 と 07-04 に「辿らない式の内側の地点（演算子・構成子・リスト・パイプ・try などの部分式の中のブロック）と定数の埋め込み本体は対象に含めない」を戻す | 読めば確定 |
| 軽5 | 軽 | `R/Surface/ScopeConnection.lean` の `scope_local_typed`、results.md の同じ行 | 前提 `hc` は、値が `checked t` なら名前が内容型を持たないこと、`checkedRequest t req` なら種類が endpoint で内容型・`groundVal`・`req.reqTarget = some t` を満たすことを要する。篩付きの V_Checked・V_CheckedRequest の前提そのものであり、弱化ではない。ただし旧には `hc` を値の型付けから得る系 `scope_local_typed_of_typed` があり、新しい版にはない。旧より前提を満たす手段が少ない（例 `project_typed` は具体の値で直接与える） | 篩付きの `HasTypeVQ` の V_Checked・V_CheckedRequest の逆転から `hc` を得る系を置くか、置かない理由を results.md に書く | 読めば確定。逆転の補題の有無は確かめていない |
| 軽6 | 軽 | `R/Surface/ScopeConnectionExamples.lean` の `request_connection` | 受理と到達は具体に与えるが、δ の成功 `hrun` と成功値 `hw` は仮定のままである。`http_check_connection` の結論が実際の成功値について成り立つ場合（`ModelHttp.builtins` の δ が `Result.Ok` を返す入力）は例で示していない。定理は条件付きの形なので空疎ではないが、成功の場合の存在は確かめていない | 具体の pattern・lo・hi・req で δ が `Result.Ok` を返す入力を一つ置き、`hrun`・`hw` を `rfl` で与える | 実行しないと分からない（成功する入力を作れるか） |
| 軽7 | 軽 | results.md の `emit_checked` と `FailureExamples` の行、stage-results.md の件数 | 旧の Log の例は `enabled_checked`・`forwarded_checked`（送り直し）・`console_remains_checked`・`program_checked`（同じ宣言表でのプログラム全体）を持ち、旧の型付きの失敗の例は約30件と変換の型付け（`toResult_typed` など）を持った。新しい例はその一部であり、results.md も一部であることを書く。それでも行の判定は「述べ直した」である | 判定を「一部を置き直した」と書き、置かなかった例（Log の送り直しとプログラム全体の検査、変換の型付け）を取りまとめが docs/todo に回す | 読めば確定 |
| 情1 | 情報 | `R/BuilderStore.lean` の `capture_builder_cell` | 足した前提 `B.ValueAssumptions P` は要る。篩付きの `CellOk.store`（`R/ReferenceStore.lean:95`）は、List の専用セルの要素の型付けをストアの拡張へ移すときに `HasTypeEach.shift_values` を使い、これが値の信頼条件を取る。主定理の `CoreAssumptions` の欄 `values` から得られ、`HandlerStoreExamples` が `model_core.values` で適用している。新しい独立の信頼条件ではない。ストア型の更新が `StoreTy.set` から `StoreTy.put` に、状態の判定が計算項から閉包の view に替わったほかは、旧と同じ結論である | なし | 読めば確定 |
| 情2 | 情報 | `R/Surface/ScopeConnection.lean` の `OccurrenceAccepted`・`scope_check_connection` ほか | 新しい前提 `OccurrenceAccepted … k e` は e と本体の番号 k の文との対応を求めないが、証明は記録の健全性（`analyzeBody_sound`）と e の受理だけを使い、結論も e の範囲の列についてなので、旧より強い言明である。呼び出しの範囲の列を `fixedRanges rs` に限った点は、規則を持つ出現の受理が `absoluteRanges` の成功を含む（`acceptOccurrence` は失敗に `unknownSource` を返す）ので、受理された全ての規則付きの呼び出しを覆う（検査1） | なし | 実行で確定（検査1） |
| 情3 | 情報 | 担当の判断1、`R/Surface/OpenScopeAccept.lean` の `acceptBody`・`selectExpr`、`ScopeConnection.lean` の `OccurrenceAccepted.of_def`・`accepted_check_connection` | 選ばれる出現は、関数のパラメータの型が保持する範囲を位置0の引数で読む直接の末尾呼び出しである。旧の閉じた由来の受理では、本体の入口のパラメータの位置は事実を持たないので、その出現の必須の判定は Top であり、接続定理の結論は「S は Top」に留まる。新しい受理はこの出現を型の範囲で受理し、範囲は `acceptSelection_sound` が与える。したがって対象外にしても旧の保証は弱まらず、担当の主張は正しい。旧と同じ前提（閉じた由来の本体の受理）からは `*_at` の系が全ての出現を覆う。なお `of_def` は、`acceptBody` が第一の枝（範囲の文脈が空で閉じた由来の受理が成功）を通る場合も `hsel` を要求するので、その場合の選ばれた出現はプログラム全体の受理からの系の対象外になる。必要なら第一の枝の場合を `hsel` なしで与える系を足せる | 任意。第一の枝の系を足すなら `OccurrenceAccepted.of_open` の証明の第一の場合をそのまま使える | 読めば確定 |
| 情4 | 情報 | `R/SurfaceTargetReachExamples.lean`・`R/SurfaceTargetObservedExamples.lean`、`l70/verify.py` | (1) `main_reach` の観測は空なので結論の後半は自明だが、前提の具体の証人（整形式・型付け・`CoreAssumptions`・`TargetAgreement`・`HasMain`・`Ready`）を与え、開始状態からの4段と IO の一歩を構成子で示すので、空疎でないことの例として成り立つ。`main_observed` は観測 `/data/a.txt` を持つ事象へ到達する。到達する事象は読取りの失敗の応答（`E_IOErr`、`.err "IO"`）であり、成功の応答ではないが、観測は応答によらない。`decide +kernel` は `readObs` の具体の文字列の解析の結果の等式だけに使い、言明の量化を狭めない。`narrow_rejected` は核の閉包の型付けについて述べ、表層の型付けでの拒否は `desugar_typed` を通して従う。(2) `verify.py` は群 H の照合を群 H のコミットの formal を取り出した木で再計算し、群 H2 の照合を足した。群 H の `comments.json`・`heartbeats.json` の再現は外したが、同じ取り出した木（`h-root`）で `comments.py`・`heartbeats.py` を走らせれば再現を残せた。群 H の記録は群 H の照合で一度確かめているので、照合の弱化は小さい。基準 `B_H` を `changes.json` から読むので、`B_H` が `B_WORK` の子孫であることを確かめる一行を足すとよい | (2) 任意。`stage.ROOT` と同じく二つの台本の根を `h-root` に差し替えて再現を戻す | 読めば確定。台本は実行していない |

## 観点ごとの根拠

### 1. 重い18行の旧と新

構築器の5行。

- `builder_step_no_event`・`builder_step_frame`: 旧は計算項 m の `IsBuilder`、新は閉包 q の `q.view.IsBuilder` を前提にとる。私的な補題 `view_isBuilder` が閉包の本体の判定へ移す。後続の状態の四つの形（run・error・exit・matchRun）は同じであり、`matchRun` の欄が一つ増えたのは篩付きの状態の形による。
- `capture_builder_cell`: 情1のとおりである。
- `resume_builder_cell`: 起点の環境 σ を持つ `StoreOk P B σ Ψ μ` で述べ、ほかは旧と同じである。
- `drop_local_silent`: 値の状態を `q.view = .ret v` で量化し、後続は `Closure.pure (.ret v)` である。前提 `releases saved = []` は旧と同じで、E_At 系の場合は `q.view` の形で除く。

補間の1行。`interpAllowed_complete` は全ての部分の形を場合分けし、`interpAllowed_spec` は旧と同じ同値である。

Scope の12行。`RhsEval`・`ArgEval`・`ArmEnter`・`ReachAtExpr` 系は旧の構成子と一対一に対応する。違いは次の二点で、どちらも篩付きの表層の形による。

- 照合の腕の文脈が照合する値を一つ積む（`matchArms` の `v :: env`）。局所解析の `analyzeExpr` の `matchE` も `.step T L .unknown` を一つ積むので一致する。
- `ReachBlock` は `ReachAtBlock` の存在で定義した。

`rhsEval_step`・`armEnter_steps`・`analyzeBody_sound`・`analyzeBody_requiredIndex` の言明は旧と同じ形である。接続の5定理は情2と次のとおりである。

- `scope_check_connection`・`scope_local_connection`: 結論の S は、旧の `∀ S, rs[0]? = some S → …` と `scope_check_range`（・`scope_local_range`）の存在を合わせた `∃ S, rs[0]? = some S ∧ …` である。`rs[0]?` が S を一意に決めるので同値である。
- `scope_check_core`: δ を正規化した型引数と効果引数で呼ぶ `deltaRunAt` で述べ、核の E_Prim と同じ呼び方である。結論に `directCallee` の等式が加わった。
- `http_check_connection`: 旧は抽象の `reqTarget` を持つ表で述べた。新は篩付きの本番の表で、成功値の形を `checkedRequest (endpoint t) req` まで具体にしており、旧の `t.kind = .endpoint` より強い。

前提の量化は、接続の5定理とも旧の「本体の受理・出現の所属・到達」を含む形である（`*_at` 系と `OccurrenceAccepted.of_body`）。

### 2. 空疎でないこと

`ScopeConnectionExamples` は、検査の結果を局所に保存して `Ok` の腕で射影へ渡す本体について、次の具体の導出を当てる。

- 閉じた由来の受理を `rfl` で、到達 `project_reach` を `bind`・`rhs`・`matchArms`・`body`・`con` の構成子で与える。
- 接続の5定理のうち4つ（`check_connection`・`project_connection`・`project_typed`・`check_core`）と、プログラム全体の受理からの系（`program_check_connection`）を適用する。
- 規則の表の健全性 `table_sound` は `checkRule_sound` と `projectRule_sound` で示す。

到達は文の始まり（番号4の射影の文）を量化しており、受理した本体の評価がそこへ到達する場合が実際にある。`http_check_connection` の例は軽6のとおりである。

`main_reach`・`main_observed` は情4の(1)のとおりである。`surface_target_sound` の全前提を、具体の表 `ExternalModels.targets` と表層のプログラムについて与えている。

### 3. 見送った4行

- `writeEffNames` の2名: 篩付きの交換の出口は効果を書き出さず、`Exchange.Convert` に `fromEffNames`・`fromEffNames_ok`・`fromEffNames_complete_of_atomsIn` が残る（`Convert.lean:179・215・247`）。理由は妥当である。
- `requestLitBound_known_ports_wf`・`analyzeBody_numbered`: 軽3のとおりである。

### 4. 公理と既定 import

- 足した11モジュールは全て `formal/Benitoite.lean` の既定 import にある（差分で確かめた）。
- 足した・変えた Lean のファイルに `sorry`・`axiom`・`set_option`・`native_decide`・`#eval` はない。`decide +kernel` は `SurfaceTargetObservedExamples` の2箇所だけで、カーネルの簡約であり公理を足さない。
- audit.json の集計は13モジュール・2647宣言、公理依存は許可した三公理の部分集合、`sorryAx`・`axiom` 宣言0である。生の出力の再計算は行っていない。
- `HandlerStoreExamples`・`CheckSupport` は行を足しただけである（verify.py の部分列の照合と差分で確かめた）。

### 5. 文書

01-12「Scope の局所解析の接続定理」の表、構築器の段落、例の段落と、07-04 の追記は、次の二点を除いて Lean の言明と一致する。

- 軽2(2): `http_check_connection` の前提 `ok ≠ "Result.Error"` が表にない。
- 軽4: 辿らない式の内側の地点を対象に含めないことが書かれていない。

`formal/README.md` の公理の一覧の追加17名は、本番の名前と一致する。

## 検査

| 番号 | 入力 | 確かめたこと | 結果 |
|---|---|---|---|
| 1 | `<tmp>/check1.lean`（`Surface.ScopeConnection` を import） | `OccurrenceAccepted … k (.call (.primName b ts es ix) …)` と `T.ruleAt k = some rule` から `∃ rs, ix = fixedRanges rs` が従うこと | 終了0。警告なし |
