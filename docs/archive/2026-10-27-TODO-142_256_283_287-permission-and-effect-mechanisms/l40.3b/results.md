# L40.3b の結果: 検査済みの要求の値と葉の規則（一度の切り替え）

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.3b（plan-l10-l50「L40」の表の L40.3b の行。RV-L20 中3 で加えた枝）。担当は Claude のサブエージェント |
| B_WORK | `1c6a787ff47da6bdfacd5371b127b6b8d79f5ac8`（本線、L40.4 の取り込みと RV-L30 の文言の修正の後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l40.3b`。git の状態は変えていない |
| 閉じた範囲 | 依頼の 1〜6。値の形 `Val.checkedRequest` と葉の規則 `V_CheckedRequest`、網羅性の値の形 `Inhabits.checkedRequest`、表のデータ `valContent`、全ての場合分けへの追随、逆転・標準形・拡大・旧の像の補題、Http の三項目の δ と応答を持ち二つの信頼条件を満たす実例の表、検査した要求が `Http.sendIn` まで保たれる小例、一段・到達先の対象健全性を Http の項目に当てる例、01-12・07-04 の反映。既定の全入口のビルドが sorry なしで通る |
| 未完 | なし（計画の行の範囲）。Scope の局所解析（`Surface/ScopeState.lean`）の成功値の対応と検査の契約は検査済みの要求の値を含まないままであり、L40.6 へ申し送る（「ずれと申し送り」3） |
| 適用した前提の変更の行 | 停止の表の「値の所属の規則」（問18 の行 7。L40.3b の検査済みの要求の値と葉の規則を含む行） |
| 停止条件 | 該当しないと判断した。表にない前提・結論の内容の変更、結論の弱化、公理と `Builtins.Assumptions` の欄の追加はない。`Builtins` に表のデータの欄 `valContent` を一つ加えた（`Assumptions` の欄ではない）。この判断の確認を求める（「ずれと申し送り」1） |

## 試行（最初の30〜60分）

plan「検査の割り当て」の「L の一度の切り替えの試行ビルド」の行に従った。基準のビルド（B_WORK の状態で `.lake` を作り直す一回。[builds/build-00-base.log](builds/build-00-base.log)、終了 0、133.57 秒）の後、推す案の最小の差分（構成子 `Val.checkedRequest`、規則 `V_CheckedRequest`、`Inhabits.checkedRequest`、`Val.target?` の場合、`Builtins.valContent`。[trial/trial-1.diff](trial/trial-1.diff)）を当て、排他の道具で既定の全入口の `lake build` を走らせた。Lake は失敗したモジュールを import する先を検査しないので、L20.4 と同じく、壊れた宣言を機械的に直しては全体のビルドを繰り返した。各回の差分（ビルドの直前の `git diff`）を `trial/trial-N.diff` に置いた。

数え方: `error:` の診断を、その回の差分を当てたソース（リポジトリの外の一時ディレクトリに再現）の宣言とファイルへ対応付けた一意数。同じファイルの中で、失敗した定義を参照して連鎖した診断（`Unknown constant` など）を含む。未検査の数は、その回に失敗したモジュールを推移的に import するモジュールの数で、`formal/` の全ての `.lean` の import から数えた（`trial/unchecked-N.txt`）。集計は [trial/counts.txt](trial/counts.txt)。

| 回 | 壊れた宣言 | 壊れたファイル | 未検査のモジュール | 内容 | 外側の時間 | ログ |
|---|---:|---:|---:|---|---:|---|
| 1 | 8 | 1 | 248 | `Subst.lean` の代入・改名・型代入の定義の場合の不足（3 定義と、連鎖した 5 件） | 2.19 秒 | [trial-build-1.log](trial/trial-build-1.log) |
| 2 | 35 | 4 | 226 | `Inversion.lean` の逆転の補題（`match` が残りの場合を自動で閉じる展開が再帰の上限を超えた）、`Rename.lean`（3）、`LocalScope.lean`・`WellFormed.lean` の定義の場合の不足と連鎖 | 11.00 秒 | [trial-build-2.log](trial/trial-build-2.log) |
| 3 | 1 | 1 | 208 | `Inversion.lean` の `inv_lam_wf` | 21.24 秒 | [trial-build-3.log](trial/trial-build-3.log) |
| 4 | 4 | 3 | 198 | `CoverageTypes`・`TySubstMain` の網羅性の値の形の場合、`FailureCont` の `inv_raise` | 29.07 秒 | [trial-build-4.log](trial/trial-build-4.log) |
| 5 | 6 | 2 | 62 | `Canonical.lean` の標準形の定理 3 件・`inv_list_wf`・`Pat.matchVal_closed`、`Surface/Lemmas/PatternSupport` の `Inhabits.consCongr` | 126.16 秒 | [trial-build-5.log](trial/trial-build-5.log) |
| 6 | 3 | 2 | 43 | `Dict.lean` の `superStep_super_typed`（と連鎖）、`MembershipBase.lean` の `canonical_opaque` | 12.76 秒 | [trial-build-6.log](trial/trial-build-6.log) |
| 7 | 1 | 1 | 22 | `Model.lean` の `lambda_names_wellFormed` | 23.36 秒 | [trial-build-7.log](trial/trial-build-7.log) |
| 8 | 1 | 1 | 4 | `ModelTargets.lean` の `assumptions` の `io_target`（`ws` の全ての構成子を並べた `match`） | 14.02 秒 | [trial-build-8.log](trial/trial-build-8.log) |
| 9 | 0 | 0 | 0 | 全体が通った（`Build completed successfully (461 jobs)`） | 2.74 秒 | [trial-build-9.log](trial/trial-build-9.log) |

診断として現れた宣言の一意数は延べ 58、ファイルの一意数は 14 である。回 2 の後に `inv_checkedRequest` を置き、診断を待たずに `Progress.lean`・`BuilderTyping.lean`・`Canonical.lean` の `inv_checked` を使う一行の場合にも同じ形の場合を足した。回 6 の前に `canonical_opaque` の言明に三つ目の場合（検査済みの要求の値）を加え、利用側の `widen_opaque`・`canonical_opaque_of_noValKind`・`Inhabits.opaque_iff`・`Exhaustive.opaqueTop_iff`・`TargetAgreement.obs_allowed` を同じ回で直した。どの破損も場合の追加で、証明の方針を変えたものはない。

試行の 9 回は約 10 分（06:50〜07:00、JST）だった。回 2 の時点で残りが機械的な場合の追加だと分かり、枝の上端（3時間）の2倍を超える見込みはなかったので、止めずに本体へ進んだ。回 9 の差分がそのまま本体の出発点である。

代案（`Val.checked` に省略可能な中身を持たせる形）は試行していない。代案では、Release と Surface で `checked` の値か V-Checked を書く 35 ファイル（`grep` による）の全ての `.checked t` が中身の引数を扱う必要があり、推す案の破損（14 ファイル）より広いと字面から判断した。

## 採った案と理由

推す案（検査済みの要求の構成子）を採った。値の形は `Val.checkedRequest (t : Target) (req : Const)` である。

- 要求を `Val` でなく不透明型の定数 `Const` で持つ。形式化では要求の型 `Http.ClientRequest` は範囲が Top の不透明型であり、その型の閉じた値は不透明型の定数だけである（`canonical_opaque`。`valKind "Http.ClientRequest" = none` なので検査済みの値も属さない）。定数で持っても保持する要求を失わず、規則は前提に部分の導出を持たない葉の規則になり、代入・改名・shift の場合は自明になる。`Val` で持つと規則が部分の導出を前提に持ち、相互帰納の全ての補題に帰納法の仮定を使う場合が増える。
- 規則の前提に、表のデータ `valContent : OpaqueName → Option OpaqueName`（既定は全て `none`。`TargetTable` は `Http.RequestIn` に `Http.ClientRequest`）を読む条件 `B.valContent o = some n ∧ c.type = .opaqueTop n` を置いた。要求の型の名前を規則に直に書くと、標準ライブラリの名前がコアの型付けの規則に入る。条件を置かないと射影の δ の結果が型付かない。表のデータにする形は `effKind`・`valKind`（問11）と同じ扱いである。
- V-Checked は変えていない。V-Checked に `valContent o = none` を加えても、範囲が Top の `Http.RequestIn` には要求を持たない不透明型の定数が属するので、「`Http.RequestIn` の値は必ず要求を保持する」を型付けでは表せず、規則の変更だけが増える。検査した要求が保たれることは表の δ の性質として示した（`check_send_preserves`）。

## 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `Val`（`Release/Syntax.lean`） | 構成子 `checkedRequest (t : Scope.Domain.Target) (req : Const)` を加えた。`checked` の説明の「この値を作る遷移はない」を、作るのは表の δ であることに直した |
| `Builtins`（`Release/Typing.lean`） | 表のデータの欄 `valContent : OpaqueName → Option OpaqueName := fun _ => none` を加えた |
| `Val.target?`（同） | `.checkedRequest t _ => some t` |
| `Inhabits`（同） | 構成子 `checkedRequest {o R t c} : Inhabits P (.opaque o (.fixed R)) (.checkedRequest t c)` |
| `HasTypeVQ`（同） | 構成子 `V_CheckedRequest {Γ o R t c n} : B.valKind o = some t.kind → R.Mem t → B.valContent o = some n → c.type = .opaqueTop n → HasTypeVQ P B Ψ Q C Γ (.checkedRequest t c) (.opaque o (.fixed R))` |
| `Val.substTyAt`・`Val.rename`・`Val.subst`（`Release/Subst.lean`）、`Val.VarsIn`（`WellFormed.lean`）、`Val.LocalRefs`・`NoFreeBuilders`（`LocalScope.lean`）、`Names.lean` の 3 定義、`Surface/Lemmas/BuilderCapture*.lean` の 2 定義 | 新しい場合（値を変えない、または `True`） |
| `PrimSig.shapeAt` の説明（`Release/Assumptions.lean`） | 対象は `Val.target?` で取り出し、検査済みの要求の値も対象を保持することを書いた（定義は不変） |
| `TargetTable.valContent`・`TargetTable.builtins`（`Release/TargetTable.lean`） | 表のデータ `valContent` を置き、表に入れた。先頭の説明の「`Http.requestInValue` の δ を定めない」を直した |
| `ModelTargets.firstTarget`（`Release/ModelTargets.lean`） | `.checkedRequest t _ :: _ => [t]` を加えた（`io_target` の単一の対象の形の場合に要る） |

場合を足した証明: `Typing.lean` の `hideBuilders_strengthen_val`、`Inversion.lean` の逆転の補題 16 件（`match` の先頭に `| .V_CheckedRequest .. => cases hv`）、`Rename.lean` の `rename`・`store`・`hide`、`SubstTyping`・`TySubstMain`・`OuterC`・`NoFailContext`・`Irrelevant`・`Regularity`・`StoreLemmas`・`PresBase`・`Closed`（5）・`Names`、`CoverageTypes` の `inhabits_erase_transfer`、`TySubstMain` の `Inhabits.of_substAt`、`FailureCont` の `inv_raise`、`Canonical` の標準形の定理 3 件・`inv_list_wf`・`Pat.matchVal_closed`・`HasTypeVQ.inhabits'`、`Progress` の 2 件、`BuilderTyping` の 1 件、`Dict` の `superStep_super_typed`、`Model` の `lambda_names_wellFormed`、`ModelTargets.assumptions` の `io_target`、`Surface/Lemmas/PatternSupport` の `Inhabits.consCongr`、`TargetSound` の `obs_allowed`（検査済みの要求の値の場合。観測はちょうど `[t]`）。

言明を変えた補題（主定理ではない）: `HasTypeVQ.canonical_opaque`（三つ目の場合）、`Inhabits.opaque_iff`（三つ目の場合）。利用側は全て直した。

## 置いた定理

| ファイル | 名前 | 内容 |
|---|---|---|
| `Release/Lemmas/Inversion.lean` | `HasTypeVQ.inv_checkedRequest` | 逆転。型は `O[R]` で、所属と `valContent`・定数の型の条件 |
| `Release/Lemmas/MembershipBase.lean` | `HasTypeVQ.checkedRequest_iff`・`checkedRequest_widen` | 型付けはちょうど V-CheckedRequest。範囲の拡大（所属の包含）は保持する要求を変えない |
| `Release/Lemmas/Membership.lean` | `Builtins.NoValContent`（定義）・`HasTypeVQ.not_checkedRequest_of_noValKind`・`not_checkedRequest_of_noValContent`・`Pat.catchAll_of_matches_checked`・`Exhaustive.opaque_iff_noRequest` | 旧の像での同値（下の節） |
| `Release/ModelHttp.lean`（新、既定の import に追加） | `HasHttp`・`checkRun`・`valueRun`・`firstTarget`・`builtins`（定義）、`sig_cases`・`effects_cases`・`checkRun_typed`・`checkRun_contract`・`valueRun_typed`・`assumptions`・`model_noValContent`・`modelTargets_noValContent`・`check_send_preserves` ほか補助 20、`Examples` の 27 定理 | 下の「Http の実例と対象健全性の例」 |

## 同値の補題（旧の像での同値）

旧の像は、`valKind` が全て none の表（L20.4 の `Builtins.NoValKind`）か、`valContent` が全て none の表（`Builtins.NoValContent`。L40.3b の前の全ての表と、`Model.builtins`・`ModelTargets.builtins`）である。

| 補題 | 内容 |
|---|---|
| `HasTypeVQ.not_checkedRequest_of_noValKind`・`not_checkedRequest_of_noValContent` | 旧の像の表では、検査済みの要求の値はどの型も持たない。V-CheckedRequest の結論が成り立たないので、どの導出も V-CheckedRequest を使わず、値の型付けの関係は加える前の規則だけで作った関係と同じである |
| `ModelHttp.model_noValContent`・`modelTargets_noValContent` | 旧の実例の表 `Model.builtins` と L20.7 の実例の表 `ModelTargets.builtins` は旧の像である |
| `HasTypeVQ.canonical_opaque_of_noValKind`（言明は不変、証明に場合を足した）・`release_exists_iff_old`（不変） | 旧の像の表では不透明型の閉じた値は定数だけで、`release_exists` は以前と同値 |
| `Exhaustive.opaque_iff_noRequest` | どの表でも、最上位の不透明型の網羅性は、検査済みの要求の値を除いて判断しても同じ。検査済みの対象の値（範囲が Top でない型）か定数（Top の型）が既に属し、どちらにも当たるのは変数か `_` だけで、それは検査済みの要求の値にも当たる |
| `Exhaustive.opaqueTop_iff`（言明は不変、証明に場合を足した） | 範囲が Top の不透明型の網羅性は旧の判断と同値 |

`delta_typed`・`io_typed`・`io_exists` は字面を変えていない。旧の像の表では、欄が読む値の型付けは V-CheckedRequest を使わない（`not_checkedRequest_of_noValContent`）。網羅性は最上位の不透明型について変わらない（`Exhaustive.opaque_iff_noRequest`）。したがって、旧の像の表では四つの欄の内容はこの枝の前と同じである。L20.4 と同じく、入れ子の型の中の網羅性と、三つの欄の欄の水準の同値は Lean の補題でなく説明にとどまる（RV-L20 軽9 の限界と同じ）。

## 主定理の言明と前提の内容

九つの定理（`Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`、`Surface.desugar_typed`・`surface_effect_soundness`、一段の対象健全性 `Release.step_target_sound`、到達先の対象健全性 `Release.reachable_target_sound`）の言明の字面は、B_WORK と同じである（`Release/Theorems.lean`・`Surface/Theorems.lean`・`Release/Lemmas/TargetStep.lean` は変えていない。`git diff` が空）。証明は既定のビルドで検査し直した。

前提の内容の変化（`valKind` と `valContent` がともに none でない名前を持つ表、今の表では `TargetTable.builtins` と `ModelHttp.builtins` の `Http.RequestIn` だけで起きる）:

| 定理 | 前提・結論 | 変更前（B_WORK） | 変更後 | 旧の像で旧と同値であることの補題 |
|---|---|---|---|---|
| `progress`・`preservation`・`step_sound` | `StateTy P B s`、`P.WellTyped B`、`hb : B.CoreAssumptions P`（`preservation` は結論の `StateTy` も） | `Http.RequestIn[R]` の閉じた値は定数（R = Top）と検査済みの対象の値だけ | 検査済みの要求の値を含む状態・プログラムが型付く（前提が広がる）。`CoreAssumptions` の `delta_typed`・`io_typed`・`io_exists`・`release_exists` は検査済みの要求の値を量化に含む。網羅性の判断は最上位の不透明型について不変 | `not_checkedRequest_of_noValKind`・`not_checkedRequest_of_noValContent`・`Exhaustive.opaque_iff_noRequest` |
| `effect_soundness`・`effect_soundness_noLamNames` | `HasTypeC … Eff.empty`、`P.WellTyped B`、`hb` | 同上 | 同上 | 同上 |
| `Surface.desugar_typed` | 前提 `p.WellFormed`・`p.WellTyped`・`hsig`、結論のコアの `WellTyped` | 表層の構文と型付けは変えていない | 前提は不変。結論のコアの型付けは検査済みの要求の値を含む関係で読む（表層は値を作らないので、脱糖の出力に現れない） | 前提は不変。結論は上と同じ |
| `Surface.surface_effect_soundness` | `hb : B.CoreAssumptions (desugarProgram opPrim p)` | 同上 | `hb` の内容は上の `CoreAssumptions` と同じく変わる | 上と同じ |
| `step_target_sound`・`reachable_target_sound` | `StateTyE P B Eb s`（到達先は初期の型付け）、`hc : CoreAssumptions`、`ht : TargetAgreement` | 同上 | `StateTyE` と二つの信頼条件の内容が上と同じく変わる。`TargetAgreement` の `io_target` は検査済みの要求の値を引数に持つ呼び出しも量化する。証明は `obs_allowed` に一つの場合を足しただけで、`step_target_sound` の証明は変わっていない | 上と同じ |

`Builtins.Assumptions`・`CoreAssumptions`・`TargetAgreement` の欄は追加も字面の変更もしていない。前提の内容が変わるのは、値の型付けの関係と網羅性の値の形を通してだけであり、停止の表の「値の所属の規則」の行の範囲である。Release の効果の包含（C-Sub・`Eff.Sub`）は変えていない（RV-L30 中1）。

## Http の実例と対象健全性の例（`Release/ModelHttp.lean`）

`ModelHttp.assumptions hostPat reqTarget P (hP : HasHttp P) : (builtins hostPat reqTarget).Assumptions P`。`Result` の `Ok`・`Err` と `Http.RequestCheckError` の `InvalidUrl`・`Scope`（問23）を宣言したどのプログラムについても、旧の条件と対象一致の条件の両方を満たす。ホストのパターンとポートの組の解析 `hostPat` と、要求から実効の endpoint を得る処理 `reqTarget`（URL の解析）は任意の関数である。

| 項目 | 種類・形 | δ・応答・観測 |
|---|---|---|
| `Reference.get`・`Reference.set` | 可変のセル | ストアの規則 |
| `Http.checkRequestIn` | pure（問22 の署名） | `checkRun`: `reqTarget req = some t`、`hostPat` の範囲 q、具体化した範囲 r について、`t.kind = endpoint ∧ q.Mem t ∧ r.Mem t` のときだけ `Ok(checkedRequest(t, req))`（渡された要求をそのまま保持）。endpoint を得られなければ `Err(InvalidUrl(""))`、そのほかは `Err(Scope(…))` |
| `Http.requestInValue` | pure（問22 の署名） | `valueRun`: `checkedRequest(_, req)` から `req` を返す。そのほかの値（要求を持たない値）には要求の型の定数を返す |
| `Http.sendIn` | io、`single endpoint 0`（問22 の署名） | `Ok(response)` か `Err(networkFailure)`、観測は最初の引数の `Val.target?`（検査済みの要求の値なら実効の endpoint 一つ。リダイレクトを追わない） |

`delta_typed` は検査と射影の項目について空に成り立たない（`checkRun_typed` は要求の引数の型から `req.type = Http.ClientRequest` を得て、成功値を V-CheckedRequest で型付ける。`valueRun_typed` は逆転から保持する要求の型を得る）。

一般の表の引数についての性質:

- `checkRun_contract`: `Ok(w)` なら、引数は `[hp, lo, hi, req]` の形で、`w = checkedRequest t req`（渡された同じ req）、`reqTarget req = some t`、`t.kind = endpoint`、t は q と r の両方に属する。
- `check_send_preserves`（検査した要求が `Http.sendIn` まで保たれること）: 検査の δ が `Ok(w)` を返すなら、`valueRun [w] = req`（射影は同じ要求を返す）、`w = checkedRequest t req`、`r.Mem t`、w を送る応答の関係の観測は `[t]` である。

例（名前空間 `Examples`。`api.example.com:443` の範囲 `apiRange`、対象 `apiT`、要求の定数 `req = Http.ClientRequest#7`）:

- `check_ok`・`check_range_rejects`・`check_invalid_url`: 範囲 `[api.example.com:443]` で `Ok(checkedRequest(apiT, req))`。具体化した範囲 `other.example.com:443` では動的な範囲が含んでも `Err(Scope)`。要求から endpoint を得られなければ `Err(InvalidUrl)`。
- `value_ok`・`check_then_send`: 射影は `req` を返す。検査の成功値を送ると観測は `[apiT]` で、`apiT ∈ apiRange`。
- `check_step`・`value_step`・`sendState_step`（遷移の水準）: 検査の呼び出しは E-Prim で `Ok(checkedReq)` に進み、`checkedReq` を送る E-IO の事象は `checkedReq` を引数に持ち観測は `[apiT]`、射影の呼び出しは同じ `req` に進む。
- `checkedReq_typed`・`checkedReq_not_other`: `checkedReq` は `Http.RequestIn[api.example.com:443]` の型を持ち、`Http.RequestIn[other.example.com:443]` の型を持たない。
- `send_io_target`: `io_target` の単一の対象の形（endpoint）が `[checkedReq]` の呼び出しに当たり、観測はちょうど `[apiT]`。
- `sendState_typedE`・`sendState_target_sound`（一段の対象健全性）: プログラム `httpProg`（構成子だけを宣言）で、`Http.sendIn[;;apiRange](checkedReq)` の状態は末尾 `{Http.Connect[apiRange]}` の `StateTyE` を持ち、観測した endpoint `apiT` はその `Http.Connect` の原子が許す。
- `sendState_reachable_target_sound`（到達先の対象健全性）: 同じ状態を初期状態（到達は零歩）として、初期の効果の `Http.Connect` の原子が `apiT` を許す。
- `other_not_allows`: `{Http.Connect[other.example.com:443]}` は `apiT` を許さない（許可が常に真でないこと）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 基準のビルド（B_WORK の状態で `.lake` を作り直す） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <l40.3b>/builds/build-00-base.log` | 0（461 ジョブ） | 133.57 秒（待ち 0 秒） | [builds/build-00-base.log](builds/build-00-base.log) |
| 試行の全体のビルド（9 回） | 同じ道具、`<l40.3b>/trial/trial-build-N.log` | 1（回 1〜8）、0（回 9） | 2.19〜126.16 秒 | [trial/](trial/) |
| 局所の単一ファイル | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`Subst`・`WellFormed`・`LocalScope` 各 1 回、`ModelHttp` 5 回、`Membership` 1 回） | 0 か 1（直して再実行） | 各 1 秒前後（計時なし） | 本書 |
| 途中の全体のビルド | 同じ道具、`builds/build-01.log`（`TargetTable` の変更の後）・`build-02.log`（`ModelHttp` を既定の import に加えた後） | 0・0（462 ジョブ） | 3.43 秒・11.81 秒 | [builds/](builds/) |
| 全体のビルド（作業末） | 同じ道具、`builds/build-03.log`（`Typing.lean` のコメントの直しで下流の全てを検査し直した） | 0。462 ジョブ、`Build completed successfully`。`declaration uses 'sorry'` なし | 169.37 秒 | [builds/build-03.log](builds/build-03.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 1c6a787ff47da6bdfacd5371b127b6b8d79f5ac8 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean`）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 1c6a787ff47da6bdfacd5371b127b6b8d79f5ac8` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7 件成功、`formal_build` 成功、`selected checks passed` | 9.62 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l40.3b>/axioms.lean`（64 件の `#print axioms`） | 0 | 0.62 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 64 件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 57、`propext` と `Quot.sound` 5、`propext` だけ 1、依存なし 1）。`sorryAx` と独自の公理はない。対象は、九つの定理、置いた定理と言明を変えた補題、`ModelHttp` の実例と例、`ModelTargets.assumptions`、場合を足した宣言の抜き取り 13 件である。

dry-run の後に本書と記録を足したので、work の計画の行の変更ファイル数は 73 から 75 に増えたが、選択は同じである。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（作業末、下流の全てを検査し直した） | 3565453312 | 3400.3 | 3.32 |
| 試行の回 5（試行で最大） | 3586768896 | 3420.6 | 3.34 |
| 基準のビルド | 3556622336 | 3391.8 | 3.31 |
| 公理の確かめ（`lake env lean -M 12288`、`Benitoite` 全体を読み込む） | 1522057216 | 1451.6 | 1.42 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1384333312 | 1320.2 | 1.29 |

局所の単一ファイルの検査は計時していない（値なし。0 ではない）。`-M 12288` は変えていない。

## 設計書

- 01-12「構文」: 名前の原子と不透明型の箇条の「閉じた値に範囲付きの不透明型を与える規則はない」を、V-Checked と V-CheckedRequest だけであることに直した。検査済みの対象の値の箇条の「この値を作る遷移はない」を、作るのは表の δ であることに直した。検査済みの要求の値の箇条（値の形、要求を定数で持つ理由、代入で変わらないこと、`Val.target?`、`valContent`、交換形式）を加えた。
- 01-12「型付け規則」の「値」: ` ```text ` の規則の並びに V-CheckedRequest を加え、【決定】の段落（前提、拡大の補題、逆転と標準形、旧の像、V-Checked を変えない理由、小例）を加えた。このブロックは ASCII でない文字を含むので `spec_examples` の読み取りの対象外であり、`spec_examples` は成功した。同じ節の網羅性の値の形の段落に、検査済みの要求の値と `Exhaustive.opaque_iff_noRequest` を加えた。
- 01-12「Scope の局所解析の状態と規則の表」: 成功値の対応と検査の契約が検査済みの要求の値を含まず、局所解析と Release の実例の表の Http の項目がまだ接続していないことを一文で書いた。
- 07-04「証明する性質」: V-CheckedRequest の【決定】の段落（前提の内容の変わり方、旧の像の補題、承認の扱い）を加えた。一段の対象健全性の段落の Http の三文を、仮定を満たす Http の表 `ModelHttp.assumptions` とその例を挙げ、言わないこと（要求の中身と実際の通信の一致）を残す形に直した（RV-L30 軽8）。到達先の対象健全性の段落の Http の文も、例を挙げる形に直した。
- 07-04「形式化で仮定するもの」: 表のデータの【方針】に `valContent` を加えた。`io_target` の箇条の旧 Top として読む場合の説明を `Val.target?` の形に、入力の所属の根拠を V-Checked・V-CheckedRequest に直した。範囲付きの項目の表の段落の「`Http.requestInValue` の δ を定めない」を `valContent` の記述に直した。Http の項目を持つ実例の表 `ModelHttp.assumptions` の段落と表を加えた。
- 07-04「01-12 との対応」: 行「構文・型付け規則（検査済みの要求の値と葉の規則 V-CheckedRequest）と Http の項目の実例」（Rust は未接続）を加えた。
- 見出しは追加・改名していない（`git grep` の確認は不要）。

## 失敗と修正

- 試行の回 1〜8 の破損は「試行」の表のとおりで、全て場合の追加で直した。逆転の補題の `match` は残りの場合を自動で閉じていたが、構成子が一つ増えて展開が再帰の上限（`maxRecDepth`）を超えた。上限を上げず、場合を明示して直した。
- 場合を機械的に足す一時のスクリプトが、`Names.lean` の複数行の場合（`| .checked _ => by` の後の行）を壊した。手で直した。
- `ModelHttp.lean` の単一ファイルの検査で、補題に `hP` を渡し忘れたこと、`clientRequest` の展開、`Const` に `DecidableEq` がない（`Float` を含む）ので例の `reqTarget` を `if` で書けなかったこと（パターンの照合に直した）、`ModelTargets` を import していなかったこと、`Ix.fixed` の単射の補題を `simp` に渡していなかったこと、`Kind` の自由変数を残した `decide` を直した。
- 公理の確かめの一回目は、二つの名前の名前空間の誤り（`Coverage.inhabits_erase_transfer`・`Surface.Inhabits.consCongr`）で終了 1。直して再実行した（上の表の値は二回目）。
- 記録のログの手元の絶対パスは `<wt>`・`<repo>`・`<home>`・`<tmp>` に置き換えた。

## ずれと申し送り

### 取りまとめへ

1. **表のデータの欄 `valContent` を `Builtins` に加えた（確認を求める）。** `Builtins.Assumptions` の欄ではなく、`effKind`・`valKind`・`admitsR`（問11）と同じ表のデータであり、正しさを 07-04「形式化で仮定するもの」の信頼の対象に載せた。前提の内容は値の型付けを通してだけ変わり、停止の表の「値の所属の規則」の行の範囲と判断した。代案は (a) 要求の型の名前 `Http.ClientRequest` を規則に直に書く（標準ライブラリの名前がコアの規則に入る）、(b) 要求の型を規則で制約せず、射影の δ が型を確かめる（葉の規則が「要求を保持する」を表さない）で、どちらも推さない。
2. 計画の対象ファイルの候補 `Release/Lemmas/Membership*.lean`・`ModelTargets.lean`・`TargetTable.lean` に加え、新しいファイル `Release/ModelHttp.lean` を置いた（Http の実例の表を `ModelTargets` と分けた。`ModelTargets` の 13 の証明を三項目分広げるより、同じ形の別の表にする方が小さいため）。`Model`・`ModelTargets`・`ModelHttp` の三つの実例の整理は L50.3 の対象である。

### L40.6 への申し送り

3. `Surface/ScopeState.lean` の `CheckedModels` と `CheckSpec.Contract` は成功値を `.checked t` に限る。Release の実例の表の要求の検査の δ（`ModelHttp.checkRun`）の成功値は `checkedRequest t req` なので、この契約を満たさず、局所解析の `Http.checkRequestIn` の規則と Release の Http の項目はまだ接続していない（01-12 に一文で書いた）。接続定理で Http を扱うには、`CheckedModels` を `Val.target?` で述べる形にし、要求の検査の契約を `w = checkedRequest t req`（req は第4引数）にする必要がある見込みである。`checkedModels_hasTypeV` は検査済みの要求の値について `valContent` と要求の型の条件を要する。`requestCheck.target`（`endpointOf : Val → Option Endpoint`）と `ModelHttp.reqTarget`（`Const → Option Target`）、`Boundary.requestValueRun` と `ModelHttp.valueRun` の対応も同じ枝で決める。本枝は `ScopeState` を変えていない。
4. 一段・到達先の対象健全性は、`obs_allowed` に一つの場合を足しただけで追随した（L30.4・L30.5 の申し送りの見込みどおり）。Http について言わないことは、要求の中身と実際の通信の一致である（要求は不透明型の定数、`reqTarget` は形式化の外側）。

### L40.5・L50 への申し送り

5. L40.5: 表層の構文と脱糖は検査済みの要求の値を作らない（L40.4 の申し送りのとおり）。交換の `fromVal` は `checkedRequest` を `checked` と同じく既存の残りの場合（`unsupported`）で書く。
6. L50.1: 交換形式は検査済みの要求の値を持たない。表のデータ `effKind`・`valKind`・`admitsR` を読み書きするときに `valContent` も含める必要がある。
7. L50.3: `Model.assumptions`・`ModelTargets.assumptions`・`ModelHttp.assumptions` の三つの実例と、`ModelHttp` が `ModelTargets` と同じ形で持つ `okDecl`・`errDecl`・`singleton_of_admissible` などの重複を整理する。

### R30・K10 への申し送り

8. R30: `Http.RequestIn` の実装は、検査した同じ要求と実効の endpoint を保持し（判断 7）、射影は同じ要求を返す。`Http.checkRequestIn` の失敗は、要求から endpoint を得られないとき `InvalidUrl`、ホストのパターン・端点・所属の失敗で `Scope` とする（`ModelHttp.checkRun` の分け方。問23）。`Http.sendIn` の観測は要求の endpoint ちょうど一つで、リダイレクトを追わない。K10 はこれと `valContent` の正しさ（`Http.RequestIn` が `Http.ClientRequest` を保持すること）を照合する。
9. 形式化の V-Checked は `Http.RequestIn` の範囲付きの型に要求を持たない検査済みの対象の値も許し、射影の δ はその値に要求の型の任意の定数を返す（`ModelHttp.valueRun`）。実装はこの値を作らない（検査の δ は検査済みの要求の値だけを作る）。R30 の照合の観点にする。
10. RV-L20 軽6（`ShapeOk` の単一の対象の形が、対象の位置以外の引数が同じ範囲付きの値型であることを禁じない）について、本枝が足した項目は既存の `Http.sendIn` の署名を使うだけで、引数は一つなので該当しない。`ShapeOk` に条件は足していない。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 06:43（JST、依頼文を読み始めた時刻） |
| 終了 | 07:19 ごろ（本書の作成まで） |
| 外側の所要 | 約36分 |
| 能動時間（試行） | 約17分（06:43〜07:00。読む約7分（基準のビルドの待ちと重なる）、試行の場合の追加約10分。ビルドの待ちを除く） |
| 能動時間（本体） | 約17分（`ModelHttp.lean` の実例と例 約8分、同値の補題 約2分、設計書 約4分、本書と記録の整理 約3分。作業末のビルドと検査の待ち約3分を除く） |
| ビルドの回数と時間 | 基準 1回（133.57 秒）、試行 9回（2.19〜126.16 秒）、途中 2回（3.43・11.81 秒）、作業末 1回（169.37 秒）、局所の単一ファイル 約9回（各 1 秒前後） |
| 検査 | work 1回（9.62 秒、dry-run 数秒）、公理の確かめ 2回（各 0.6 秒前後。1回目は名前の誤りで終了 1） |
| 待ち | 排他の道具の待ちは記録上なし（全て 0 秒）。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.25〜3時間の範囲内。上端の2倍（6時間）を超えていない |
