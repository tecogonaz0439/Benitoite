# L70 群 H3 の Lean の担当の結果

担当: Claude（Opus 5.5）。作業ブランチ `m014/l70.h`。B_WORK `7069a03ffc4de6d8d7bf15034678287c5d369399`（作業の開始時に HEAD と一致することを確かめた）、段の開始版 B_STAGE `657b3ae713040e78826d2f19cd7b8ac9f415a6d6`。並行の担当（群 H3 の監査の担当）の結果は [results.md](results.md) にある。

群 H の照合（[../h/legacy.md](../h/legacy.md)）が「導ける」「別の形」とした98行を、旧の言明と根拠の新しい定理の言明を全文で読み比べてやり直し（[legacy-recheck.md](legacy-recheck.md)）、失った保証に改めた行と、群 H2 が見送った2行を、篩付きの核と表層の上で述べ直した。独立レビュー [RV-L70.h2](../../reviews/RV-L70.h2.md) の中1・軽1〜7・情3と、[RV-L70.h](../../reviews/RV-L70.h.md) の中5を処置した。新しい公理・`sorry`・既定 import からの除外はなく、既存の規則は変えていない。旧の保証が篩付きの規則の下で成り立たない例は見つからなかった。旧の型付きの失敗と Log の例の期待値は、全て篩付きの検査器で同じ値になった。

失った保証に改めた14行のうち、11行を述べ直した。表層の具体例の3行（`main_never_passwd`・`program_target_sound`・`desugared_typed`）は述べ直していない（下の「述べ直していない行」。取りまとめに判断を求める）。

## 時刻

外側の時間（`date` の読み）である。能動時間と待ち時間は分けていない。単位は並行して進めたので重なる。

| 単位 | 開始 | 終了 |
|---|---|---|
| 読む（依頼文・共通依頼文・二つのレビュー・群 H・H2 の記録）と旧の言明の98行の抜き出し | 2026-11-07 21:06 | 21:12 |
| 旧の言明の全文の読みと照合のやり直しの判定（[legacy-recheck.md](legacy-recheck.md)） | 21:12 | 21:48 |
| 到達しない選択肢の実行時の系（`CoverageRuntime`） | 21:14 | 21:24 |
| 明示拡大（`ScopeWiden`）・番号の不変条件（`ScopeNumbering`）・リテラルの要求（`ScopeLitBound`） | 21:18 | 21:30 |
| 専用操作の拒否と組込みの名前の脱糖（`CheckBuilderRejection`）・軽1・軽2・軽5・軽6 | 21:24 | 21:55 |
| 有界 Integer の網羅性の独立例（`CoverageIntegerExamples`） | 21:44 | 21:52 |
| 範囲付きの上限の一段と到達先の具体例（`SurfaceTargetStepExamples`） | 21:56 | 22:01 |
| 節の添字の許容の反例（中1）と別の対象を読む節の例（`SurfaceTargetClauseExamples`） | 22:01 | 22:11 |
| Log・型付きの失敗の例の拡張（軽7）と Result の変換の型付け（`FailureTypingExamples`） | 22:11 | 22:19 |
| 既定ビルド・01-12・07-04・`formal/README.md` | 22:19 | 22:24 |
| 公理監査・根拠の名前の照会・記録 | 22:24 | 22:31 |
| 適用例の追加（`ScopeFactExamples` ほか）と既定ビルド・公理監査のやり直し | 22:28 | 22:45 |

## 照合のやり直し

旧の言明は段の開始版の `git show <B_STAGE>:formal/Benitoite/<ファイル>` から98行の全ての旧の名前の宣言（ドキュメント・コメントを含む）を抜き出して全文を読んだ。名前空間の3行（`PrimRangeExamples`・`Release.CoverageExamples`・`CoverageIntegerExamples.lean`）はファイルの該当の範囲を読んだ。根拠の新しい定理の言明は作業木の Lean のソースで読んだ。判定の基準は [legacy-recheck.md](legacy-recheck.md) の冒頭にある。

| 判定（やり直しの後） | 行 |
|---|---:|
| 導ける | 21 |
| 別の形 | 54 |
| 別の形（旧の判断どうし） | 9 |
| 失った（重い） | 5 |
| 失った（軽い） | 9 |
| 計 | 98 |

群 H の判定から改めた行は25行である。失った保証に改めた14行は次のとおり。

- 重い5行: `checkMatch_unreachable_runtime`・`checkMatch_unreachable_runtime_of_C_Match`・`SlotsOk`（到達しない選択肢の判定の実行時の系。RV-L70.h 中5）、`widenRanges`・`widenPathIn_target_unique`（群 H の根拠の名前が無関係。同）。
- 軽い9行: `builderOp_empty_rejected`（拒否を述べる定理がない）、`desugar_primName`（群 H の根拠は型付けで、脱糖の等式を述べない）、具体例の基準（RV-L70.h 軽1）で改めた `main_never_passwd`・`no_write_event_passwd`・`ioCall_no_passwd`・`handleLog_never_observes_data`・`desugared_typed`・`program_target_sound` と `Release.CoverageExamples`（整数の区間の独立例）。

ほかに改めた11行は、別の形から導ける（`builder_value_no_free_local`。値の型付けが同じ言明を結論する）、導けるから別の形（`builderApply_total_typed`。関数の水準の存在は進行と保存で述べる）、別の形から「別の形（旧の判断どうし）」の9行である。後者は範囲を入れた旧の判断と範囲の前の旧の判断の同値（旧の像での同値）であり、篩付きの判断との関係は旧導出の埋め込み（一方向）だけで、決定 D29 が逆向きと全域の同値を要求しない。根拠は旧の言明を含まないが、この同値は旧の判断の中の性質であって今の言語の性質ではないので、失った保証に数えない（2026-11-07、取りまとめの判断。決定 D29 も逆向きと全域の同値を求めない）。

根拠の名前（48名）は、既定 import の環境で `#check` により一つに決まることを確かめた（根拠の名前の照会。終了0）。モジュールの名前で示した3つ（`Release.Refinement.ScopedIOExamples`・`ModelTargetsApplications`・`CoverageExamples`）は名前のない例を含むモジュールである。

## 足した・変えたモジュール

| モジュール | 状態 | 内容 |
|---|---|---|
| `Release.Refinement.CoverageRuntime` | 足した | 束縛の並べ替えの条件 `SlotsOk`、実行時の選択 `RuntimeSelected`、腕の型付けからの `SlotsOk`、到達しない選択肢の実行時の系と照合の遷移の前提への接続 |
| `Release.Refinement.CoverageIntegerExamples` | 足した | 有界 Integer の網羅性の独立例と、全域の後のワイルドカードの実行時の非選択 |
| `Release.Refinement.ScopeWiden` | 足した | 明示拡大の範囲の列の決め方と行き先の一意性 |
| `Release.Refinement.Surface.CheckBuilderRejection` | 足した | 宣言のない専用操作の拒否、組込みの名前の脱糖の等式 |
| `Release.Refinement.Surface.ScopeLitBound` | 足した | リテラルの要求が既知にする範囲の整形式 |
| `Release.Refinement.Surface.ScopeNumbering` | 足した | 局所解析の記録の束縛番号の新規性 |
| `Release.Refinement.Surface.ScopeRequestExamples` | 足した | 要求の検査の接続定理の δ の成功の具体例 |
| `Release.Refinement.SurfaceTargetStepExamples` | 足した | 範囲付きの上限での一段と到達先の対象健全性の具体例 |
| `Release.Refinement.SurfaceTargetClauseExamples` | 足した | 節の添字の許容を外した誤った規則の反例と本番の拒否、別の対象を読む節の handle の例 |
| `Release.Refinement.FailureTypingExamples` | 足した | Result の二構成子の値・Fail を Result へ変換する handle・二構成子の照合の型付けと、その照合への `C_Match` の系の適用 |
| `Release.Refinement.Surface.ScopeFactExamples` | 足した | 番号の不変条件・リテラルの要求・明示拡大の定理の適用例 |
| `Release.Refinement.HandlerStoreExamples` | 変えた（末尾に足した） | `OrdinaryStoreEq.symm`・`trans` の読者 `builder_steps_ordinary_compose` |
| `Release.Refinement.RequestDelta` | 変えた（末尾に足した） | 範囲 Top の要求の検査が成功する具体の入力 `run_top_ok` |
| `Release.Refinement.Surface.ScopeConnection` | 変えた | `http_check_connection` の使わない引数 `facts` を除いた（軽2）。`scope_local_typed_of_typed` を足した（軽5） |
| `Release.Refinement.Surface.ScopeConnectionExamples` | 変えた | 上の引数の除去への追随と、`project_typed_of_typed` を足した |
| `Release.Refinement.Surface.LogExamples` | 変えた（末尾に足した） | `enabled_checked`・`forwarded_checked`・`program_checked` |
| `Release.Refinement.Surface.FailureExamples` | 変えた（足した） | 旧の型付きの失敗の例の残り（11定理） |

足した11モジュールは全て既定 import（`formal/Benitoite.lean`）に入れた。一覧と必須の名前は [changes-lean.json](changes-lean.json)。変えた既存の言明は `http_check_connection` の引数の除去だけであり、結論と残る前提は変わらない。`RequestDelta` は既存のファイルの先頭に `set_option maxHeartbeats 2000000`・`maxRecDepth 4000` を持つ（足していない）。足した `run_top_ok` は同じファイルの既存の例と同じ証明の形である。

## 述べ直した定理

完全名の接頭辞 `Benitoite.Release.Refinement.` を `R.` と書く。

| 旧の名前 | 重さ | 述べ直した定理の完全名 | 旧との違い |
|---|---|---|---|
| `SlotsOk` | 重い | `R.SlotsOk`、`R.HasTypeArmsQ.slotsOk` | 旧と同じ定義。腕の型付けからの導出は篩付きの腕の型付け（観測の事実を持つ `plain`・`guarded`）について示す。照合の束縛の個数の補題 `R.matchVal_binders`・`R.PatTy.length_binders` を足した（篩付きの `P_Convert`・`P_Refined` を含む） |
| `checkMatch_unreachable_runtime` | 重い | `R.checkMatchWithView_unreachable_runtime`・`R.checkMatch_unreachable_runtime`、`R.RuntimeSelected`・`R.RuntimeSelected.alternativeSelected` | 旧と同じ言明（任意の view と閉じた入口）。照合の遷移の前提 `firstAlt v alts = some ws` から実行時の選択を得る `R.RuntimeSelected.of_firstAlt` と、その選択肢が到達しないと報告された位置でないこと `R.firstAlt_not_unreachable` を足した（旧より強い接続） |
| `checkMatch_unreachable_runtime_of_C_Match` | 重い | `R.checkMatchWithView_unreachable_runtime_of_C_Match`・`R.checkMatch_unreachable_runtime_of_C_Match` | 旧は値の型付け・腕の型付け・網羅性を別々の前提に取り、値と網羅性の前提を使わなかった。篩付きの版は照合の計算の型付け（`HasTypeCQ … (.match v arms)`）だけを前提にとり、逆転（`HasTypeCQ.match_arms`）で照合の型 a と値の型付けを取り出し、結論に含める |
| `widenRanges` | 重い | `R.ScopeWiden.widenRanges`・`widenRanges_spec`・`widenRanges_pathIn`・`widenPathIn_instantiated`・`widenPathIn_result` | 旧と同じ定義（範囲は篩付きの `RangeExpr`）。具体化した署名は篩付きの依存列（`instantiatedTel (Tel.instR [r, s] widenPathIn.tel)`）で述べる。`widenRanges_spec` は決めた列が元の範囲と行き先の二つであることを足した |
| `widenPathIn_target_unique` | 重い | `R.ScopeWiden.widenPathIn_target_unique` | 旧と同じ言明（長さ2の列の具体化の結果型が同じなら位置1の範囲は同じ）。結果型は依存列の `Tel.result` で読む |
| `builderOp_empty_rejected` | 軽い | `R.Surface.Check.builderOp_empty_rejected` | 旧は推論の検査器の結果 `.ok` から False を導いた。篩付きの検査器は案内（`Guide`）を受ける判定なので、どの案内でも判定が false であることを案内の上の再帰で示す（同じ式を子の案内で検査し直す規則を含む） |
| `desugar_primName` | 軽い | `R.Surface.desugar_primName` | 同じ（範囲の列は篩付きの `RangeIx`） |
| `no_write_event_passwd` | 軽い | `R.Surface.TargetStepExamples.no_write_event_passwd`（`passwd_read_allowed`・`passwd_write_not_allowed`） | 旧の例の表 `ModelTargets.Examples.B` は篩付きの `ExternalModels.targets` に替わり、プログラムは表層の標準の宣言を脱糖した核 `TargetObservedExamples.core p`。上限 `{File.Write["/data/**"], File.Read}` と結論は同じ。上限が名前を落とすと `/etc/passwd` を許すことも同じ定理群で示す |
| `ioCall_no_passwd` | 軽い | `R.Surface.TargetStepExamples.readCall_no_passwd`（`readClosure_typed`・`readClosure_start`・`readCall_observed`・`readCall_allowed`） | 範囲付きの書き込み `File.writeTextIn["/data/**"]` を範囲付きの読取り `File.readTextIn["/data/**"]` に替えた（同じ範囲付きの IO の形 `ioIn` の項目）。実行が観測 `/data/a.txt` の事象へ進み、その観測を開始の効果が許すこと（前提が空疎でないこと）も示す |
| `handleLog_never_observes_data` | 軽い | `R.Surface.TargetStepExamples.handleLogs_never_observes_data`（`handleLogs_typed`・`handleLogs_reach_allowed`） | 旧は書き込みの一つの操作の節で `File.Write` を処理した。篩付きの表の `File.Write` は四つ、`File.Read` は三つの操作を持ち、`handled` は全ての操作の節を要るので、`File.Read` の三つの操作の節を置き、節は `/logs/l.txt` を読む。本番の型付けは三つの節を添字 Top の `ClauseSig` で型付ける |
| `Release.CoverageExamples`（`CoverageIntegerExamples.lean`） | 軽い | `R.CoverageIntegerExamples.integer_holes`・`integer_unreachable`・`integer_missing_points`・`integer_correlation`・`integer_list_elements`・`integer_fuel`・`choice_intervals`・`integer_wild_never_runtime` | 旧の名前のない例の全ての入力と期待値を、篩付きの入口（`coverage`・`checkMatchWithView`・`useful`・`usefulFuel`）で同じ値として照合した（`rfl`）。旧の `inspect` の組は `checkMatchWithView` の欄の組で書いた。全域の後のワイルドカードの実行時の非選択を足した |
| `analyzeBody_numbered`（群 H2 が見送った） | 軽い | `R.Surface.ScopeLower.analyzeBody_numbered`（`WellNumbered`・`Numbered`・`AllNumbered`、`WellNumbered.idAt_inj`・`fresh_new`） | 旧と同じ言明。篩付きの局所解析の照合の腕は照合する値を一つ積む（`(rejoin r p.1).step T L .unknown`）ので、その場合を足した |
| `requestLitBound_known_ports_wf`（群 H2 が見送った） | 軽い | `R.Surface.ScopeState.requestLitBound_known_ports_wf`（`requestLitBound_known_wf`・`requestLitBound_inverted_unknown`） | 旧と同じ言明。旧の 07-04 が書いた「最小が最大より大きい組は未知にする」を `requestLitBound_inverted_unknown` で述べた |

公開した定理の適用例: `CoverageRuntime` は `CoverageIntegerExamples.integer_wild_never_runtime`・`integer_full_selected` と `FailureTypingExamples.fromResult_runtime`、`ScopeWiden`・`ScopeNumbering`・`ScopeLitBound` は `Surface.ScopeFactExamples` の `widen_data`・`entryScope_numbered`・`body_records_numbered`・`inverted_ports_unknown`・`known_request_bound`、`CheckBuilderRejection` の二つは検査器と脱糖の全ての入力についての言明であり、`formal/README.md` の公理の確かめの一覧が読む。

## 述べ直していない行

取りまとめの判断（2026-11-07）は、この3行もこの群で述べ直すことである。この担当の会話の容量が残り少なく、下の見込みの作業を区切りまで進められないため、着手せずに記録して止めた（取りまとめの「容量が尽きそうなら、区切りまでを記録して報告」に当たる）。後の担当への引継ぎは、下の表の理由と、表層の照合の規則 `E_Match`・`HasArmsQ.plain`（`Surface/Rules.lean`）の前提（観測の事実 `scrutObs`・リンク・`FactsWF`・`ViewExhaustive`）、範囲付きの組み込みの頭の型付け `CallHeadTy.prim` の前提（`SurfaceTargetObservedExamples` の `read_head` と同じ形に範囲の列と許容を加える）である。被覆だけで型付く定義は main 自身でよい（本体の効果 `{File.Read["/data/a.txt"]}` を宣言の効果 `{File.Read["/data/**"]}` で覆う）。

| 旧の名前 | 重さ | 理由と再見込み |
|---|---|---|
| `main_never_passwd` | 軽い | 旧の例は、`Scope.checkPathIn` の結果を照合して `PathIn["/data/a.txt"]` の値を範囲付きの書き込みの関数へ渡す表層の main を、被覆で型付けて表層の対象健全性に当てた。篩付きの表層の構文も検査済みの対象の値を書けないので、Result の照合の腕（観測の事実・リンクを持つ篩付きの規則）を含む表層の型付けの導出を手で書くか、検査器の実入口（`checkProgramAccepted`）を範囲付きの表で通す（`SurfaceCheckedMainExamples` と同じ形で入力の健全性・宣言の実現などを示す）必要がある。見込み3〜6時間（能動時間）。同じ保証の核の水準の例は `readCall_no_passwd`・`no_write_event_passwd` にある |
| `program_target_sound` | 軽い | 同じ旧の例の、被覆でだけ型付く定義を含むプログラムへの表層の対象健全性の適用。上と同じ表層のプログラムで述べる（上の見込みに含む） |
| `desugared_typed` | 軽い | 旧の例は三つの二引数のクラス（型構成子を引数に取るクラス）と辞書を含む表層のプログラムに性質1を当てた（旧は `maxHeartbeats 4000000`・`maxRecDepth 8192` を置いた）。篩付きの表層では、上位クラスと実装を持つ一引数のクラスのプログラムの検査器の健全性の例（`Surface.CheckDeclarationExamples.material_typed`）はあるが、二引数のクラスの例はない。見込み4〜8時間（能動時間）で、heartbeat の設定を足さずに検査器の評価が通るかは未確認 |

## 所見ごとの処置

### RV-L70.h2

| 所見 | 処置 |
|---|---|
| 中1 | 篩付きの核で旧と同じ対照を置いた。`R.Surface.TargetStepExamples.WrongClausesTyped`・`WrongHandleTyped` は、本番の `C_Handle` と `HasTypeClausesQ.cons` の前提のうち節の操作の型 `ClauseSig`（`ClauseIxOk` と `opSigAt`）だけを任意の添字の `opSigAt` に替えた誤った規則である（本番の節の型付けは誤った規則の型付けでもある: `wrong_of_clauses`）。`wrong_rule_admits` は、捕捉した引数を `File.readTextIn["/etc/**"]` へ渡す節を持つ handle を効果 `{File.Read["/etc/**"]}` で型付け、`wrong_rule_unsound` はその実行が `/data/a.txt` を観測し上限に許されないことを示す。`etc_not_clauseIxOk` は本番の規則が添字 `/etc/**` を許さないこと、`handleEtc_rejected` は到達先の対象健全性から本番の型付けがこの handle をその効果で型付けないことを示す。群 H2 の範囲を照合しない包含の反例（`TargetObservedExamples.wrong_rule_unsound`）は残した |
| 軽1 | `OrdinaryStoreEq.symm`・`trans` は残し、読者 `HandlerStoreExamples.builder_steps_ordinary_compose`（二つの専用項の一歩の比較の合成と逆向き）を置いた。群 H2 の results.md の記述（「読者がないので置いていない」）は群 H2 の記録なので書き換えず、本書で訂正する |
| 軽2 | `http_check_connection` の引数 `facts` を除き、証明の中で `fun _ => none` を渡す。01-12 の表に前提「Ok の構成子の名前 ok が `Result.Error` でないこと」を書いた |
| 軽3 | `analyzeBody_numbered`・`requestLitBound_known_ports_wf` を述べ直した（上の表） |
| 軽4 | 01-12「Scope の局所解析の接続定理」と 07-04「証明する性質」・「01-12 との対応」の表に、到達の関係が辿らない式の内側の地点と定数の埋め込み本体を対象に含めないことを書いた |
| 軽5 | `R.Surface.ScopeSound.scope_local_typed_of_typed` を置いた。値の形と内容の前提を、名前 name の範囲付きの型を保持する型（`Ty.Holds`）の値の型付けから、逆転 `HasTypeVQ.inv_checked`・`inv_checkedRequest` で得る。保持する対象と範囲の文脈を持つ値（`checkedAt`）は、型付けが文脈の証人を要るので前提で除く。取りまとめの指示（2026-11-07）に従い、旧の系と同じく異なるストア型の値を受ける版 `R.Surface.ScopeSound.scope_local_typed_of_typed_extend` も置いた。拡張前のストア型 Ψ′ での値の型付けと `Ψ′.Extends Ψ`・`Ψ′.WF` を受け、保持する要求の型付けを既存の補題 `HasTypeVQ.store_extend` で Ψ へ移す。旧の `StoreTy.Sub` に当たる篩付きの関係は `StoreTy.Extends` である。旧の系との違いは、値の信頼条件 `B.ValueAssumptions P` を前提に足したこと（篩付きの値の型付けのストア型の拡張がこれを要る。主定理の `CoreAssumptions` の欄であり、群 H2 の `capture_builder_cell` と同じ扱い）と、拡張前のストア型の整形式を受けることである。同じストア型の版 `scope_local_typed_of_typed` は値の信頼条件を要らない。適用例は `ScopeConnectionExamples.project_typed_of_typed`・`project_typed_of_typed_extend` |
| 軽6 | `RequestDelta.run_top_ok`（範囲 Top の検査が要求を保持する成功値を返す具体の入力。ホストのパターン `127.0.0.1`、ポート 443、要求 `GET https://127.0.0.1/`）を置き、`ScopeConnectionExamples.request_connection_ok` で δ の成功と成功値の前提を満たして `request_connection` の結論を得た |
| 軽7 | 旧の Log の例の残り（問合せの操作、送り直し、プログラムの定義ごとの受理）を `LogExamples.enabled_checked`・`forwarded_checked`・`program_checked` に置いた。プログラム全体の `checkProgram` は、定義ごとの `checkDef` で置き直した。旧の型付きの失敗の表層の例の残り（約20）を `Surface.FailureExamples` の11定理に置き、旧の期待値は全て篩付きの検査器で同じ値になった。旧の拒否の理由の文字列の例（2）は、篩付きの検査器が理由の文字列を同じ形で返さないので受理と拒否だけを照合した。旧の strict と relaxed の両方の照合の例（1）は、篩付きの検査器が照合の方式を持たないので対象がない。変換の型付け（`result_values_typed`・`toResult_typed`・`fromResult_typed`）を `FailureTypingExamples` に置いた。`fromResult_typed` は旧と同じく二つの構成子だけを持つ宣言表で述べる |
| 情3 | 確かめた。`OccurrenceAccepted.of_def` の `hsel` は第二の枝（`OpenScopeAccept.acceptBody` が出現ごとに判定する枝）で要り、`Accepted` だけからは第一の枝を通るかが決まらないので、要らない前提ではない。第一の枝の場合（範囲の文脈が空で閉じた由来の受理が成功する）は、閉じた由来の受理から `OccurrenceAccepted.of_body` が `hsel` なしで与える。系は足していない |

### RV-L70.h（この担当の分）

| 所見 | 処置 |
|---|---|
| 中5 | (1) 到達しない選択肢の3名を失った（重い）に改めて述べ直した。(2) 明示拡大の2名を失った（重い）に改めて述べ直した。(3) 98行の全てで旧の言明の全文を読み直した（[legacy-recheck.md](legacy-recheck.md)）。stage-results.md の「旧の性質の照合」の節の記述を、群 H の読み方（候補と迷う行に限って全文を読んだ）と群 H3 のやり直しに分けて書き直した |
| 軽1 | 具体例の行を一つの基準（同じ役割の具体例がなければ失った（軽い））で判定し直した。一般の言明が主定理で導けることは根拠の欄に「（一般の言明）」と書いた |
| 軽7 | stage-results.md の「旧の性質の照合」の節の候補の表と段落を、群 H2・H3 の後の状態に改めた。legacy.md は群 H の記録なので書き換えず、やり直しの結果は legacy-recheck.md を指す |

## 既定ビルド・公理監査・照合

| 検査 | コマンド | 開始 | 終了状態 | 外側の時間 |
|---|---|---|---|---|
| 既定ビルド | 共有ロックの下で `lake build`（作業木の formal） | 22:19:54 | 0（2344 ジョブ。新しいモジュールの警告なし、`sorry` の警告なし） | 236秒（`/usr/bin/time -l` の最大常駐量 4,994,646,016 バイト、手元 M4。補助値） |
| 公理監査（最初） | [audit-lean.py](audit-lean.py) `prepare`・`run`・`analyze`（共有ロックの下で `lake env lean -M 12288`） | 22:24:49 | 0 | 16.7秒（16モジュール・2,487宣言） |
| 既定ビルド（適用例の追加の後） | 共有ロックの下で `lake build` | 22:32:43 | 0（2345 ジョブ。差分のビルド。22:34 にもう一度実行して最新であることを確かめた） | 数秒 |
| 公理監査（適用例の追加の後） | 同上 | 22:33:48 | 0 | 16.9秒（17モジュール・2,610宣言） |
| 既定ビルド（取りまとめの指示の後。ストア型の拡張の版を足した） | 共有ロックの下で `lake build` | 22:39:37 | 0（2345 ジョブ） | 7秒 |
| 公理監査（最後） | 同上 | 22:40:10 | 0 | 17.1秒（[audit-run-lean.json](audit-run-lean.json)） |
| 根拠の名前の照会 | 共有ロックの下で `lake env lean -M 12288`（`import Benitoite` と照合の表の48名の `#check`） | 22:26 | 0（誤り0） | 数秒 |

公理監査の結果（[audit-lean.json](audit-lean.json)。最後の実行）: 足した11・変えた6のモジュールの全宣言 2,612（private 2,049、マクロのスコープを持つ名前 0、解決できない名前 0）を監査し、公理依存は許可した三公理（propext・Quot.sound・Classical.choice）の部分集合だけである。`sorryAx` 0、`axiom` の宣言 0。依存の組は、なし 1,008・propext 1,253・Classical.choice + Quot.sound + propext 329・Quot.sound + propext 22。述べ直した主な名前と適用例の86名の型の SHA-256 と公理依存は `required` にある。入力の段の監査の入力 [../axioms.lean](../axioms.lean) と [../h/stage.py](../h/stage.py) の読み取り（`load`・`ALLOWED`）は、並行の担当が同じ作業木で改めている版を使った（入力の SHA-256 は audit-lean.json の `inputs`）。

作業中の局所の検査は、各ファイルを共有ロックの下で `lake env lean -M 12288` で検査し、依存のモジュールの再ビルドが要るときは共有ロックの下で `lake build <モジュール>` を実行した（`RequestDelta`・`ScopeConnection` の変更の後の依存の再ビルドは各約400秒と130秒）。`scripts/check.sh`・`scripts/check-formal.sh` は実行していない。

## 計画からのずれ

- 表層の具体例の3行（`main_never_passwd`・`program_target_sound`・`desugared_typed`）を述べ直していない（上の「述べ直していない行」）。
- 範囲付きの書き込みの例を範囲付きの読取りで置き直した（同じ `ioIn` の形の項目。`ioCall_no_passwd` の行）。
- 公理監査の記録の名前を、並行の担当の記録と重ならないよう `audit-lean.json` などにした。

## 後の作業への申し送り

- 述べ直していない3行の処置（取りまとめに判断を求める点の1）。
- 群 H3 の監査の担当の必須の名前の一覧（[required-names.json](required-names.json)）へ、[changes-lean.json](changes-lean.json) の `required` の86名を入れるか（同3）。

## Lean の変更の終わり

2026-11-07 22:41。この担当の Lean のソース・既定 import の変更はここで終わる（最後の既定ビルド 22:39:37 開始・終了0、最後の公理監査 22:40:10 開始・終了0）。監査の担当は最後の照合を流してよい。述べ直していない表層の具体例3行は、別の担当か会話で続ける。
