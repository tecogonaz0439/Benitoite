# L00.04 の結果: 観測と主定理の境界

2026-10-27。plan「作業 L00.04」を、作業用のディレクトリ `<wt>`（ブランチ `m013/l00.04`）で行った。担当は Claude Opus 5.5 のサブエージェントである。採用は決めていない。観測の欄の最終の形と配置は L00.08 が決める。

## 作業と状態

| 項目 | 内容 |
|---|---|
| 作業 | L00.04（観測と主定理の境界） |
| B_WORK | `d771588c94c1f24b1a47958043451325dd35a028`（L00.03 の取り込みの後） |
| 閉じた範囲 | 観測の三案の比較と、案 O1（観測を応答の関係に含める）の模型。引数からの観測と実際の観測の分離。小さい機械での進行・保存・空効果の健全性（旧の条件だけ）と、一段・到達先の対象の健全性（信頼条件も使う）。対象の健全性が旧の条件から従わないことの証明。有限の非 Top の例、旧 Top の HTTP のリダイレクトの例、SK の反例の対応。本番の言明の案（Prop の定義）と、到達先の言明が一段の言明から従うことの証明。L00.03 の申し送り 1・2、L00.01 の申し送り 2 の判定の案 |
| 未完（意図して後へ送る） | 本番の一段の対象の健全性の証明（L20・L30）。本番の事象 `Event.io` への観測の欄の追加と `Oracle`・`step` の変更（L20）。ハンドラ・継続を通した名前と対象の伝播（`end_of_noHandler` の対象版。L30）。`ContTy` の末尾の添字についての単調性（L00.01 の申し送り 2 の案 BB を採る場合。L30） |
| 採否 | 採用は決めていない |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/TargetExamples.lean` | 新規（563行）。名前空間 `Benitoite.Scope.TargetExamples`。`Benitoite.Scope.SignatureExamples`（L00.03）と `Benitoite.Release.Lemmas.EffectSound` を import する。SHA-256 は `29e210784ff9eabc2d857cafcd84c10d07312967259dae03b940a7c064869fdd` |
| `formal/Benitoite.lean` | 既定の import の末尾に `import Benitoite.Scope.TargetExamples` を一行加えた |
| `l00.04/` | 本書と生のログ |

既存の定義と定理は変えていない。本番の定義（`Release.StateTyE`・`Step`・`Steps`・`HasTypeC`・`steps_preserve` など）は、言明の案と一つの新しい補題（`stateTyE_init_eff`）が読むだけである。設計書（01-12・07-04 など）には反映していない（採用前の候補のため）。

## 観測の設計の比較

### 観測を置く場所

| 観点 | O1: 応答の関係に含める（模型で採った形） | O2: 応答と別の関係にする | O3: 観測を持たず、要求の引数から取り出す（今の本番） |
|---|---|---|---|
| 形 | `ioResponse b rs ws v obs`。事象は `Event.io b ws o obs` | `ioResponse b … o` と `ioObs b … o obs` | `Event.io b ws o` のまま。対象は `argObs` などで引数から取り出す |
| 進行に要るもの | `io_exists` が応答と観測の組の存在を与える（模型の `progress`）。新しい欄は要らない | 観測の存在を与える欄が新しく要る（停止条件の「新しい欄」に当たる） | 要らない |
| 旧 Top のリダイレクト・複数の対象 | 有限列で表せる（`redirect_step`）。最初の URL と同じ対象を要求しない | 同じく表せる | 表せない。旧 Top の引数は文字列なので、取り出せる観測は空になる（`argObs_raw`）。対象のある操作を対象なしと報告するか、最初の URL と同じ対象を要求するかになる |
| 実際の対象との関係 | 観測は実装が作用した対象の仕様上の記述であり、`io_target` がそれを引数と形に結ぶ | O1 と同じ | 要求の引数の所属は値の型付けだけで示せる（`argObs_mem`）。しかし実際の対象の所属とは言い換えられない（下の SK の反例の対応） |
| 既存の欄の変化 | `io_kind`・`io_typed`・`io_exists` が観測の引数についても量化する（L00.03 の申し送り 1 の案 A と同じ種類の量化の変更）。`Event`・`E_IO`・`E_IOErr`・`E_Exit`・`Oracle`・`step`・`step_sound` の `horacle` の形が変わる | O1 の変更に加え、観測の存在の欄 | 事象の変更はない。代わりに「事象が実際の操作を忠実に表す」ことを同じ信頼の境界で文書に明記する必要がある（SK §3.2） |

推す案は O1 である。O2 は観測の存在のために `io_target` 以外の欄を要し、O3 は旧 Top の入口で対象を隠すか、リダイレクト先に同一の URL を求めることになるからである。

### 観測の要素の型

観測は対象（`Scope.Domain.Target`）の有限列（`List Target`）とした。`Option Target` は旧 Top のリダイレクトや複数の対象を表せない。有限集合にしない理由は、リダイレクトの順を記録でき、所属の判定が決定可能なまま扱えることである。順と重複は対象の健全性の言明に使わない。

### 形ごとの観測の条件

`io_target` の内容は L00.03 の `ShapeTargets` をそのまま使った。対象なしの形は空の観測、旧 Top の形は宣言した種類の対象だけ（空も可）、新しい単一の対象の形は対象の位置の引数が保持する同じ対象一つである。比較のため、単一の対象の形で空の観測を許す `ShapeTargetsLoose`（観測は高々その対象だけ）も置いた。どちらでも観測の所属は導ける（`obs_mem_of_input_and_agreement`・`obs_mem_of_loose`）。

## 主定理の維持する結論

| 定理 | 維持する結論 | 観測の追加（O1）で変わる前提の内容 | 模型での対応 |
|---|---|---|---|
| `Release.progress` | `StateTy → Final ∨ ∃ Step` | `io_exists` が応答と観測の組の存在になる。`TargetAgreement` は要らない | `progress`（`CoreAssumptions` だけ） |
| `Release.preservation`・内部の `preservationE` | 同じ `StateTy`、内部では同じ Eb の `StateTyE` を保存 | 観測は状態に入らないので、IO の場合の証明は観測を読み捨てるだけ。`TargetAgreement` は要らない | `preservation`・`steps_preserve`（信頼条件を使わない） |
| `Release.effect_soundness`・`effect_soundness_noLamNames` | 空の効果の計算から IO・解放の事象と処理されない操作が出ない | `io_op`（形の検査）が効果の非空を与える。`TargetAgreement` は要らない | `effect_soundness`・`effect_soundness_steps`（`CoreAssumptions` だけ） |
| `Surface.desugar_typed` | `WellFormed ∧ WellTyped ∧ EffectsOk` | 観測は実行時の関係なので変わらない。`io_target` を前提に足す必要はない | 模型にしていない |
| `Release.step_sound` | `step` の遷移は `Step` の遷移 | `Oracle` が応答と観測の組を返す形になり、`horacle` の量化が観測を含む | 模型にしていない |
| 新、一段の対象の健全性 | `StateTyE P B Eb s` と `Step … (some ev) s'` から、観測の全ての対象が Eb に許される | `CoreAssumptions` と `TargetAgreement` の両方 | `step_target_sound`（証明済み）。本番は `ReleaseStepTargetStatement`（未証明） |
| 新、到達先の対象の健全性 | 初期の計算の型 `A ! ε` について、到達した状態が次に出す事象の観測が同じ ε に許される | 同上 | `reachable_target_sound`（証明済み）。本番は `ReleaseReachableTargetStatement`（未証明）。一段の言明から従うことは本番の定義で証明した（`reachable_of_step`） |

模型の機械では、対象の健全性は旧の条件だけからは従わない（`target_not_from_core`）。旧の条件を満たし、対象の健全性を破る表 `badTable` がある。したがって対象の健全性は既存の三つの結論の系ではなく、`io_target` を要する別の定理である。

## 言明の案と未証明の範囲

本番の言明の案を、`TargetExamples.lean` の Prop の定義として置いた。どちらも未証明であり、仮定（`Builtins.Assumptions` や新しい構造体の欄）には入れていない。

- `ReleaseStepTargetStatement obs allows TA`: 本番の定義のまま、`P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B`・`B.Assumptions P`・`TA B P`・`StateTyE P B Eb s`・`Step P B s (some ev) s'` から `∀ t ∈ obs ev, allows Eb t` を結論する。`obs` は事象の観測（O1 なら事象の新しい欄の射影）、`allows` は効果の上限が対象を許すこと（L10 の被覆の意味）、`TA` は計画済みの `io_target` の信頼条件である。三つは今の本番に無いので引数にした。
- `ReleaseReachableTargetStatement obs allows TA`: 初期の `HasTypeC P B ∅ [] [] none m a ε` と `m.ClosedNoEffVars`、`Steps P B ⟨m, [], ∅⟩ s`、`Step P B s (some ev) s'` から、観測が同じ ε に許されることを結論する。

初期の同じ ε を保つため、言明は存在量化の Eb を持つ `StateTy` でなく、Eb を固定した `StateTyE` を使う。`StateTy` を使うと途中の状態ごとに Eb を選び直せ、Top の像の Eb を選べば対象の言明は何も制限しない（模型の `stTy_widenTop`・`widened_allows_any`）。

証明したのは次の二つだけである。

- `stateTyE_init_eff`: 既存の `stateTyE_init`（空の ε だけ）を任意の ε へ広げた補題。証明は既存のものと同じで、`K_Empty` を `Eff.Sub.refl` で使う。
- `reachable_of_step`: 一段の言明から到達先の言明が、既存の `steps_preserve`（同じ Eb を保つ保存）と `stateTyE_init_eff` で従う。一段の言明は仮定ではなく、この定理の引数である。対象の健全性を証明したものとは数えない。

本番の一段の言明の未証明の部分は次である。事象に観測を加えること、`E_IO`・`E_IOErr`・`E_Exit` の各場合で引数の型付けと `io_target` から観測の所属を出すこと、計算の効果から継続の末尾 Eb までの対象の伝播（今の `ContTy.end_of_noHandler` は名前の所属だけを伝える）、`E_OpPrim` で節の効果が外側の上限に含まれること（SK §4。本番の `K_Handle` は既にその形）。模型の機械はハンドラ・継続・ストア・純粋な関数の呼び出しを含めておらず、この伝播を試していない。

## SK の「値所属だけでは不十分」の反例との対応

| SK の定理 | 本模型の対応 | 内容 |
|---|---|---|
| `request_argument_bound` | `argObs_mem` | 引数からの観測の所属は値の型付けだけから出る。信頼条件を使わない |
| `Examples.checked_alone_insufficient`・`bad_has_no_target_agreement` | `bad_core_and_arg_mem`・`bad_step_escapes`・`bad_no_target_agreement` | 書き込みの観測を `/etc/passwd` に固定した `badTable` は、旧の条件を全て満たし、引数（`/data/a.txt`）の所属も成り立つ。それでも事象の観測は `File.Write["/data/**"]` の上限の外にあり、`io_target` は成り立たない |
| （SK は言明していない） | `target_not_from_core` | 「旧の条件を満たす全ての表で一段の対象の健全性が成り立つ」は偽である |
| `io_bound` | `obs_mem_of_input_and_agreement`（と L00.03 の `target_sound`） | 入力の所属と対象の一致から観測の所属が出る |
| `step_target_soundness`・`reachable_target_soundness` | `step_target_sound`・`reachable_target_sound` | 一段と到達先。同じ初期の上限 |
| `effect_soundness`（`BasicAssumptions` だけ） | `effect_soundness`（`CoreAssumptions` だけ） | 空効果の健全性は対象一致の条件に依存しない |
| `Examples.good_assumptions` | `assumptions_goodTable` | 範囲付きの IO と旧 Top の IO を実際に持つ表が両方の条件を満たす。条件を矛盾させて定理を通したものではない |

SK の反例は事象の欄（`site`）に実際の対象を記録した。本模型では O1 の観測の欄がその役を持つ。SK の `redirect_*` はハンドラの節が別の対象へ作用する例であり、本模型の旧 Top のリダイレクト（実装の追従）とは別の現象である。前者は本模型に含めていない。

## 申し送りの判定の案

いずれも決定していない。L00.08 の一括の問いで尋ねる候補である。

### L00.03 の申し送り 1: 観測の対象の列を応答の関係に含めるか

| 案 | 内容 | 帰結 |
|---|---|---|
| O1（推す） | 応答の関係に含め、事象 `Event.io` に観測の欄を加える | 新しい欄は要らない。`io_kind`・`io_typed`・`io_exists` の観測についての量化と、`Event`・`Oracle`・`step_sound` の形の変更を、L00.03 の申し送り 1 の案 A と同じく前提の変更として列挙する |
| O2 | 別の関係にする | 観測の存在の欄が新しく要り、停止条件の「計画済みの `io_target` 以外の欄」に当たる |
| O3 | 事象を変えず、引数から取り出す | 旧 Top の入口で対象を隠すか、リダイレクト先に同一の URL を求めることになる（`argObs_raw`）。計画の完了の条件に反する |

### L00.03 の申し送り 2: 空の観測を許すか

| 形 | 案 E1（推す） | 案 E2 |
|---|---|---|
| 対象なし | 空だけ | 空だけ |
| 旧 Top | 種類の一致だけ。空も許す | 同じ |
| 新、単一の対象 | ちょうど引数の対象一つ（`ShapeTargets`）。対象に触れる前に失敗した IO も、試みた対象を報告する | 高々引数の対象一つ（`ShapeTargetsLoose`）。触れる前の失敗は空でよい |
| 定理への影響 | 所属の証明は空を禁じることを使わない | 同じ（`obs_mem_of_loose`） |
| 信頼条件のレビュー | 「触れた」の境界を操作ごとに定めなくてよい。試みた対象は R に属するので、報告しても健全性を損なわない | 操作ごとに「触れる前の失敗」の境界を定め、レビューする必要がある |

E1 を推す理由は、信頼条件が引数だけから決まり、レビューする内容が少ないことである。旧 Top で空を禁じる条件は、どちらの案でも定理に使わないので `io_target` に加えない案を推す。「対象ありの操作を対象なしと報告しない」は、L00.03 の形の分類（対象のあるエフェクトを `untargeted` に登録しない）で表す。実行前の表示や記録で試みた対象を示す要求は R30・R40 で扱う。

### L00.01 の申し送り 2: 非 Top の効果のための `BuiltinOnly` の拡張

`BuiltinOnly P B Eb`（継続の末尾の効果は名前だけの原子）は `StateTy` の中にあり、`StateTyE` には無い。

| 定理・定義 | `BuiltinOnly` の現れ方 | 案 BA（拡張する）で変わること | 案 BB（意味を保つ）で変わること |
|---|---|---|---|
| `StateTy` | 定義の一部 | 内容が変わる（範囲付きの原子も末尾に許す） | 字面だけが格納方式に合わせて変わり（Top の原子）、意味は Top の像の上で同じ |
| `Release.progress`・`progressE` | 前提（`StateTy`、`hEb`） | 前提の内容が変わる（弱くなるので定理は強くなる） | 変わらない |
| `Release.preservation` | 前提と結論（`StateTy`） | 前提と結論の内容が変わる | 変わらない |
| `Release.step_sound` | 前提（`StateTy`） | 前提の内容が変わる | 変わらない |
| `effect_soundness`・`noLamNames` | `StateTyE … Eff.empty` を使い、`builtinOnly_empty` だけ | 変わらない | 変わらない |
| `Surface.desugar_typed` | 現れない | 変わらない | 変わらない |
| 新しい対象の定理 | `StateTyE` を使うので現れない | 変わらない | 変わらない |
| 追加で要る補題 | — | `progressE` が範囲付きの原子の末尾を扱うこと | `StateTyE` が末尾の添字について単調であること（`ContTy` で ε0 を使うのは `K_Empty` の `Eff.Sub` だけなので、包含の推移で示せる見込み。未証明）。非 Top のプログラムは Eb を Top の像へ広げて公開の `StateTy` に入る（模型の `stTy_widenTop`・`widenTop_topOnly`） |

判定の案: BA は `StateTy` の内容を変えるので、停止条件の「前提・結論の変更」に当たる。判断 15 が列挙した `io_op` と `io_target` の変更にも含まれない。採るなら L00.08 で前提の変更として列挙して受け入れを尋ねる。BB は四つの主定理の前提の意味を Top の像の上で保ち、停止条件に当たらない見込みである。ただし `BuiltinOnly` の字面は格納方式に合わせて変わるので、「意味を保つ表現の変更」であることを L00.08 のレビューで確かめる必要がある。推す案は BB である。対象の健全性は Eb を固定した `StateTyE` で言明するので、公開の `StateTy` の Eb を Top の像に広げても精度は失われない。

## 定義と小補題の一覧

### 定義

| 名前 | 内容 |
|---|---|
| `argObs` | 引数からの観測（位置 p の引数が保持する対象） |
| `ShapeTargetsLoose` | 単一の対象の形で空の観測を許す比較用の形の条件（案 E2） |
| `AtomCovered`・`EffCovered` | 上限 ε が原子・効果を覆う（同名の原子の範囲の意味の包含） |
| `Call`・`Ev` | 呼び出し（元の操作・範囲の具体化・引数）と、観測を持つ事象（O1） |
| `CallTy`・`StTy` | 同じ上限 ε での呼び出しと状態の型付け |
| `Step`・`Steps` | 小さい機械の一段と多段（多段は事象の列を保持しない） |
| `Atom.widenTop`・`TopOnly` | 閉じた原子を Top へ広げる関数と、閉じた原子が全て Top である上限（`BuiltinOnly` の模型） |
| `sendOld`・`sigOf`・`tableBase`・`mkTable` | 旧 `Http.send`、例の表（書き込みの観測の関数だけを引数にした表） |
| `goodTable`・`badTable` | 引数の対象を報告する表と、`/etc/passwd` を報告する表 |
| 例の値 | `dataTreeA`・`writeCall`・`epsData`・`endpointA`・`endpointB`・`sendCall`・`epsHttpTop`・`outsideTarget` |
| `StepTargetSound` | 模型の一段の対象の健全性の言明 |
| `ReleaseStepTargetStatement`・`ReleaseReachableTargetStatement` | 本番の言明の案（未証明） |

### 証明した定理（42件）

| 群 | 定理 |
|---|---|
| 引数からの観測と所属 | `argObs_mem`、`argObs_raw`、`obs_mem_of_input_and_agreement` |
| 空の観測の比較 | `shapeTargets_loose`、`shapeTargetsLoose_nil`、`obs_mem_of_loose` |
| 被覆 | `atomCovered_nil`、`effAllows_of_covered`、`inst_eff_nonempty` |
| 既存の三つの結論の模型 | `progress`、`preservation`、`steps_preserve`、`effect_soundness`、`effect_soundness_steps` |
| 対象の健全性 | `step_target_sound`、`reachable_target_sound`、`stepTargetSound_of_assumptions` |
| 上限を取り直す場合 | `widenTop_topOnly`、`stTy_widenTop`、`widened_allows_any` |
| 例の表 | `sigOf_cases`、`shapeOk_writeTextIn`、`shapeOk_sendOld`、`shapeOk_printLine`（三つとも小さい表の一項目の `decide`）、`core_mkTable`（観測の関数によらず旧の条件が成り立つ）、`target_goodTable`、`assumptions_goodTable` |
| 有限の非 Top の例 | `dataTree_wf`、`writeCall_ty`、`writeCall_ty_mk`、`good_write_obs_mem` |
| 旧 Top の HTTP | `sendCall_ty`、`redirect_step`、`endpointA_ne_B`、`redirect_allowed` |
| SK の反例の対応 | `outside_not_mem`、`bad_core_and_arg_mem`、`bad_step_escapes`、`bad_no_target_agreement`、`target_not_from_core` |
| 本番の定義への接続 | `stateTyE_init_eff`、`reachable_of_step` |

`good_write_obs_mem` は plan の「有限の非 Top 例について入力所属と対象一致から所属が出る小補題」に当たる。`File.Write["/data/**"]` の上限で型付く `/data/a.txt` への書き込みの事象の観測が `/data/**` に属することを、値の型付けと `target_goodTable` から導く。`redirect_allowed` は、A から B へ追従した観測 `[A, B]`（A ≠ B）が旧 Top の上限に許されることを示し、最初の URL と同じ対象を使わない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中、4回） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/TargetExamples.lean`（1・2回目と最後は `/usr/bin/time -l` で包んだ） | 1回目 1、2回目 1、3回目 0、4回目 0（空の観測の比較を加えた後） | 各 0.6 秒前後 | 本書の「失敗と修正」 |
| 全体のビルド | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。415ジョブ、`Built Benitoite.Scope.TargetExamples (603ms)`、sorry なし。ロックの待ちは0秒 | 1.32 秒（ビルド済みの生成物の上） | [lake-build.log](lake-build.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base d771588c94c1f24b1a47958043451325dd35a028 --dry-run` | 0。選択は `formal_build`（`formal/Benitoite.lean` の変更による。sorry の宣言を拒否する）だけ | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base d771588c94c1f24b1a47958043451325dd35a028` | 0。`formal_build` が通り `selected checks passed`。dry-run と同じ選択（変更の件数は記録を加えた分だけ 6→7）。本書を加えた後の dry-run（変更8件）も同じ選択 | 0.23 秒（ビルド済み） | [work-check.log](work-check.log) |
| 公理の依存 | `cd <wt>/formal && lake env lean -M 12288 <一時ファイル>/axioms.lean`（定理42件と定義19件の `#print axioms`） | 0 | 0.30 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log) |

公理: 61件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する。`sorryAx` と独自の公理はない。ソースに `sorry`・`admit`・`axiom`・`native_decide` はない。

Rust の検査は選ばれず、追加もしていない（Lean だけの枝）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの Lean のプロセスだけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（排他の道具、ビルド済みの生成物の上で新しいモジュールと根だけを作った） | 1507360768 | 1437.5 | 1.40 |
| work の検査（ビルド済み） | 69140480 | 65.9 | 0.06 |
| 局所の単一ファイル（計時した中の最大、1回目） | 777535488 | 741.5 | 0.72 |
| 公理の確かめ | 701792256 | 669.3 | 0.65 |

`-M 12288` は変えていない。

## 失敗と修正

- 局所の検査の1回目が終了1。(1) `split_ifs` は Mathlib の戦術であり、このプロジェクトでは使えなかった（`sigOf_cases`）。`split at h` に改めた。(2) `simp at hr` が `writeCall.rs` を展開せず進まなかった（`writeCall_ty`・`sendCall_ty`）。展開する定義を simp に渡した。(3) `bad_step_escapes` で書き換えの向きを取り違えた。(4) `bad_no_target_agreement` で `Exists.choose_spec` の項を `writeTextIn` の型に合わせられなかった。先に項目を `writeTextIn` に確定してから欄を取り出す形に改めた。
- 2回目が終了1。`if_pos`・`if_neg` がこの版で非推奨の警告を出し、`target_goodTable` の `rw [if_pos rfl]` は simp が条件を `True` にした後で一致しなかった。`split at h` と `simp` に改めた。3回目は終了0、警告なし。
- 4回目は失敗ではない。空の観測の比較（`ShapeTargetsLoose` と三つの補題）を加えた後の再検査である。全体のビルド・公理・work はこの状態で行った。

## ずれと申し送り

計画からのずれはない。停止条件に当たる事項は見つからなかった。既存の定義と定理は変えておらず、`Builtins.Assumptions` にも欄を加えていない。L00.01 の申し送り 2 の案 BA を採る場合は停止条件に当たる前提の変更になるので、上の判定の案として L00.08 へ渡す。

L00.05 以降への申し送り:

1. 本番の言明は `StateTyE`（Eb を固定）で書く。`StateTy` では初期の上限が失われる。
2. 到達先の言明は一段の言明から従う（`reachable_of_step`）。L30 は一段の言明だけを証明すればよい。ただし事象の観測の欄と `allows` の定義（L10 の被覆の意味）を先に決める必要がある。
3. 継続を通した対象の伝播（`end_of_noHandler` の対象版）と、`E_OpPrim` の節の効果の包含は、模型で試していない。L30 の主な証明の義務である。

L00.08 への申し送り:

- 観測を置く場所の案 O1〜O3（推す O1）と、O1 に伴う `io_kind`・`io_typed`・`io_exists`・`Event`・`Oracle`・`step_sound` の形の変更の列挙。
- 空の観測の案 E1・E2（推す E1）。旧 Top で空を禁じる条件を `io_target` に加えないこと。
- `BuiltinOnly` の案 BA・BB（推す BB）と、BB に要る `StateTyE` の末尾の添字についての単調性の補題。
- 比較用に本番の `Release` を import した（`stateTyE_init_eff` と言明の案のため）。最終の配置で、これらを `Release` の側へ移すか、比較の模型とともに削除するかを決める。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 19:09（JST） |
| 終了 | 19:22（本書の作成と最後の dry-run まで） |
| 外側の所要 | 約13分 |
| 能動時間 | 約12分（読む約5分、模型と証明約4分、本書約3分） |
| 検査 | 全体のビルド 1.32 秒、work 0.23 秒、局所と公理 計数秒。排他の道具の待ちは0秒 |
| 見込みとの比較 | 見込み 30〜60分に収まった。上端の2倍（120分）を超えていない |
