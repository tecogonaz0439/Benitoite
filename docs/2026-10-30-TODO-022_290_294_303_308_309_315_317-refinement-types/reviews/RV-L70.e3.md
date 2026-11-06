# RV-L70.e3: L70 群 E の後半（L70.34 の表層の主定理と、安全な位置の消去）の独立レビュー

2026-11-07。対象はブランチ `m014/l70.e3` の未コミットの作業木（新規の Lean 11 モジュール、`formal/Benitoite.lean` の import 11 行、01-12・07-04 の追記、`C/l70/e3/`）である。基準は `73585979113c7acf25b38673f9c2c52d1d38dfaf` で、HEAD と一致する。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-e3/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回であり、再レビューは重・中の処置の確認に限って一回とする。

読んだもの:

- 本体の作業木にある依頼文 `work/m014/L70.e3-prompt.md`・`L70.e3-r1-prompt.md`（「初回の停止への判断」で案 B を採る）と報告 `L70.e3-r1-report.md`。記録の形式は [RV-L70.e2](RV-L70.e2.md) の初回の部分に倣った。
- [e3 の結果](../l70/e3/results.md)（初回と再開1）と [obstruction.lean](../l70/e3/obstruction.lean)。[e2 の結果](../l70/e2/results.md) と [RV-L70.e2](RV-L70.e2.md)。
- [detail.md](../l70/detail.md) の第2.5節の L70.34 の行と第4.1節の群 E の完了条件。plan.md の「計画の変更と取りまとめへの確認点」の 2026-11-06 の群 E の後半の停止（案 B）、RV-L70.e2、群 E の前半の取り込み（`Program.WellFormed` を checker が導かない申し送り）の項。
- 新規の R/`SurfaceMain`・`SurfaceLibrary`・`SurfaceMainExamples`・`SafeCheckErasure`・`SafeCheckSimulation`・`SafeCheckReflection`・`SafeCheckObservations`・`SafeCheckErasureExamples`・`SafeCheckTyping`・`SafeCheckPreservation`・`SafeCheckPreservationExamples`。読み合わせとして、R/`StandardModelApplication`（`ProgramGuarantees`・`included_guarantees`）、R/`StandardModelCompletion`（`Includes`・`complete`・`Completion`）、R/`Surface/Property1Base`（`Declarations.Realizes`）、R/`Surface/CheckTablesBase`（`Extends`）、R/`Surface/CheckInput`（`Input.Sound`）、R/`Surface/CheckArguments`（`HeadTableSupport`）、R/`Surface/CheckBuiltinSource`、R/`Surface/CheckExamples`、R/`Semantics` の δ と IO 応答の規則。
- `git diff 73585979 -- docs/design formal/Benitoite.lean`。担当の台本は読んで判定し、実行していない。

したことは、確認用入力による完全名・前提・定義域の確認と、主な定理の公理依存の表示である。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行した。`-o` は使っていない。`lake build`・cargo・`scripts/check.sh`・台本の実行・git の書き込み操作は行っていない。変更したリポジトリのファイルは本書だけである。

## 結論

**可。重0件、中2件、軽3件（一行）、情報4件である。中の2件は記録と後段への申し送りで処置でき、今回の Lean の言明の変更を要しない。**

表層の主定理 `surface_guarantees` の結論は群 B・C の `ProgramGuarantees P (complete L T A) σ` そのものであり、`link_additions` が性質1（範囲パラメータを持つ本体の全具体化を含む）から同じ表の `Program.Additions` の十一欄を作って `included_guarantees` へ渡す。`Program.WellFormed` は checker から導かず、表層の `p.WellFormed` と標準の包含から `included_premises` が構成する。前提のうち `Includes`・`DataTable`・`Completion`・標準側の `ExternalWF`・`L.WF` は群 C の `included_guarantees` と同じ前提であり、今回新しく足した信頼条件ではない。`HasMain` から開始の型付けと閉性を構成し、起点の束縛だけを `σ.Ready` で受ける。証人 `main_guarantees` は外部宣言を一つ持つ標準の本体の上で前提を同時に満たすので、主定理の前提は空疎でない。

消去は案 B のとおりである。`erase` は計算の子・腕とガード・処理節・`lazyC`・`builderLet` の本体を辿り、値（`lam`・`dependentLam`・`closure`）に入らない（検査2）。δ と IO の応答は値の列だけを読みストアを読まないので、本体を書き換えた遅延・継続をストアと継続の中に置いても応答は変わらない。`StateRel` は値・失敗の理由列・終了コードを同じ値で対応させ、`state_step`・`state_reflect` の両方向の模倣から、有限の事象列と終端観測、非停止、無限実行の存在が両方向で保たれる。観測の定理は型付けの前提を持たず、前提の `Agreement B` は `Agreement.complete` が完成した表の p392 の行から供給する。`computation_preservation` は任意の Q・C・Γ・Φ・R・Δ で同じ型と効果を保ち、`Ctx.Regular` などを足していない。新しい公理と `sorry` はない（検査2）。

ただし、実入口の系 `checkProgramAccepted_main` は、標準の完成表の下で前提が同時に満たされることを示していない（中1）。また `q.D.Realizes P` は、checker の宣言表が標準の関数の署名を補う場合に、表層の整形式・checker・合成表のどれからも供給されない。証人もその場合を通っていない（中2）。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | R/`SurfaceLibrary.lean` の `checkProgramAccepted_main`・`checkProgramAccepted_guarantees`、R/`SurfaceMainExamples.lean` の実入口の `example`、[results.md](../l70/e3/results.md) 再開1の「O066と群Eの完了条件の照合」の実入口の行 | 系は `q.Sound`・実際の成功 `checkProgramAccepted q Ai p = .ok ()`・`q.B = complete L T A`・`Includes`・`Realizes` を同時に受ける。この同時の充足の証人がない。具体の `example` は checker の前提をすべて仮定として受ける形であり、証人ではない。群 E の実入口の成功例（R/`Surface/CheckExamples.lean` の `required_entry_checked`）は `.custom` の小さな表を使う。`Input.Sound` の `HeadTableSupport.prims` は、`q.B` の全署名が有限の原子一覧で支持されることを要求する。完成表についてこれを示した補題はない。さらに、checker の構成元 `.standard P'` が返す表は `StandardModel.builtins P'` であり、`complete L T A` との等号や移送の補題はない。したがって、実入口が `.standard` を使うとき、系の `hB` を満たす経路は示されていない。担当は CheckedUnder を導出から作った限界を記録しているが、完了の判定はこの差を区別していない | Lean の変更は要さない。results.md の実入口の行に「標準の完成表での前提の同時の充足は未証明」と書く。群 G の受け持ちとして、次のどちらかを申し送る。(a) 7入口が checker の構成元に `.custom (complete L T A)` を使い、その入力の `q.Sound`（完成表の全署名の原子の支持）を示す。(b) `.standard` の表と `complete` の等号又は型付けの移送の補題を置く。どちらでも、標準の関数を呼ぶ main の実入口の成功例を一つ置く | 定義と言明を読めば確定。`.standard` との接続の補題がないことは R の検索で確かめた |
| 中2 | 中 | R/`SurfaceLibrary.lean` の `surface_guarantees`・`link_additions` の `hR : q.D.Realizes P`、R/`SurfaceMainExamples.lean` の `input`・`guarantees`・`main_guarantees`、results.md 再開1の「止めずに進めた変更」の一行目 | `Extends q.D p.declarations` は、利用者の宣言にない関数の署名を checker の表に補うことを許す。利用者が標準の関数を呼ぶ普通のプログラムでは、checker の `D` は標準の関数の署名を持つ。その署名と、`linkProgram` が保持した標準の核の本体の署名（`tparams`・`names`・`params`・`ret`・`eff`・`rkinds`）の一致は、`Realizes.funs`・`ranges` が要求する。表層の整形式から供給されるのは利用者自身の宣言の分（`link_realizes`）だけであり、標準の署名の分は checker・合成表・完成表のどれも供給しない。証人の `input` の `D.funs` は main 以外で `none` であり（検査3）、標準の関数を呼ぶ場合を通っていない。結果の記録は「IncludesとRealizesをlookupで受ける」とだけ書き、この前提の供給元を示していない。これは有限の二つの表の一致で判定でき、組込みの振る舞いを信頼する条件ではないので、重とはしない | results.md の前提の供給元の表に、標準の署名を補う `D` では `Realizes` が残る前提であることと、その判定が checker の宣言表と標準の核の本体の署名の一致であることを書く。群 G（7入口が `D` を作る箇所）の受け持ちとして、標準の宣言表から作った `D` が `linkProgram (program externals) op p` を実現する補題を置くか、証人を標準の関数を呼ぶ main に広げる。R50 では処理系の標準の宣言表とこの一致を照合する | 定義を読めば確定。証人の表の内容は検査3で確認。標準の署名を補う `D` で前提が充足できるかは試していない |

軽（3件）: (1) `effects_preserved` は、`Event.Covered` が事象だけを読むので `observations_preserved` の直接の系であり、型の効果の保存は `computation_preservation` の同じ `e` が担う。01-12 の「同じ効果の被覆を保つ」は正しいが、効果の保存の実質がどちらにあるかを一文で添えるとよい。(2) 07-04 の「実入口の系にも具体の main から適用する」は、checker の前提をすべて仮定に置いた `example` を指す。中1の処置と合わせて「前提を仮定とした適用」と書く。(3) `surface_guarantees` の `Realizes` の欄 `externalWF` は `Includes.externalWF` と標準側の `ExternalWF` から得られる重複であり、記録で触れるか、後段で前提を減らすときの材料とする。

## 観点ごとの根拠

### 1. `surface_guarantees`・`linked_main`・`checkProgramAccepted_main` の前提と結論

完全な署名は検査1で表示した。前提の供給元は次である。

| 前提 | 供給元 |
|---|---|
| `p.WellFormed` | 表層の整形式。checker から導かない（群 E の申し送りどおり） |
| `CheckedUnder p q` | 主定理では前提。実入口の系では `checkProgramAccepted_sound` が成功から供給する |
| `L.WF`・`DataTable P`・`Completion L T A`・`(program externals).ExternalWF`・`Includes externals P` | 群 C の `included_guarantees` と同じ前提。`Completion` は仮定側の表の契約で、群 C で受け入れた範囲である。外部宣言を空に制限しない |
| `q.B = complete L T A` | checker の入力の構成。中1 |
| `q.D.Realizes P` | 利用者自身の宣言の分は `link_realizes` が `p.WellFormed` から供給する。標準の署名を補う分は中2 |
| `p.HasMain ε` と `σ.Ready` | main の宣言の形と、初期状態の起点の束縛。開始の型付け・閉性・保持値の適格性は `main_typed_realized` と `StartCondition.of_noLamNames` が構成する |

`HasMain` は main の型・行・範囲パラメータと値引数が空で、結果が Unit か `Result[Unit, String]` であることを読む。01-07「プログラムの入口」と 01-12 の入口の条件に一致する。main 以外の関数の範囲パラメータは制限しない。

結論は群 B の `ProgramGuarantees` をそのまま使う。`MainGuarantees` は今回足した構造であり、各欄は `ProgramGuarantees` の `initial_typing`・`effect_soundness`・`reachable_target_sound` を `mainClosure` に当てたものである（情報1）。`checkProgramAccepted_main` は `Accepted`・`ProgramGuarantees`・`MainGuarantees` を同時に返すので、群 B の形より弱くない。

### 2. `linkProgram` と `desugar_additions`・`link_additions`

`linkProgram` は脱糖した利用者の定義を優先し、空欄に標準の核の定義を置く。型・構成子・効果・外部宣言は収集した表のまま（`link_sameTypes`）である。`Additions.defs` は標準に無い名前の定義だけを要求し、利用者の定義・アクセサ・テスタの三経路を `lookupFun_desugar` で分ける。通常の定義は `Def.WellTyped.desugar` が範囲パラメータの全具体化を量化した `TelBodyTyR` を返し、実装は `ImplDecl.WellTyped.desugar`、変性と効果は `CheckedUnder` の欄から同じ `q.B` で作る。性質1と群 C の受け口（同じ `complete L T A` の上の `Additions (program externals) P B`）に合う。利用者が標準の鍵と同じ名前の定義を書けば `Includes.extends_` が偽になり系は適用されないが、これは群 C の `Includes` の範囲である。

### 3. 証人 `main_guarantees`

`source` は標準の構成子・data の一覧・外部宣言を収集し、利用者は本体が空の main だけを書く。`includes`・`data`・`wellFormed`・`checked` を別々に証明し、`noAssumptions` の完成表と全起点を束縛した環境で `linked_main` の前提を同時に満たす。外部宣言は `positiveExternals` であり空ではない。主定理の前提は空疎でない。

担当が述べる限界（`CheckedUnder` を有限の型付き導出から作り、checker の `Sound` と実入口の成功を証明した証人ではない）は妥当である。ただしこの限界により、実入口の系の前提の同時の充足は示されていないまま残る（中1）。証人の checker の表は main しか持たないので、標準の関数の呼出しを含む場合の `Realizes` も通っていない（中2）。

### 4. `SafeCheckErasure`

`erase` は `.app (.prim checkName [t,u] [] []) [v]` の形で `Site t u v` が成り立つときだけ `.ret (ok u v)` に替える。他の計算は子の計算だけを辿り、値の中へ入らない。検査2で、`.ret (.closure sig q)` と `.ret (.dependentLam sig body)` が変わらないこと、範囲引数を持つ `check` の呼出しを保持すること、`lazyC` の中の成功した検査を消すことを確かめた。`variable_retained` は変数の実引数を保持する。

`Site` は期待型の閉じた WF、両型の正規形、芯の一致、`accepts v u = true`、`Stable` である。`Stable` は任意の捕捉・値置換・型と行の置換・範囲具体化で呼出しと置換先が変わらないことであり、プログラムの文面だけで決まる。実行時の応答に条件を足さない。ただし `erase` は古典的な決定可能性で `Site` を判定する非計算的な関数であり、構文の十分条件から `Site` を導く補題はない（情報2）。

模倣について。`Step` の δ（`B.delta b ts es rs ws`）と IO の応答（`B.ioResponse b ts es ws …`）は値の列だけを受け、ストアを読まない（R/`Semantics.lean` の規則）。消去後のプログラムで書き換わったコードを持つのは、実行中の閉包、継続の枠、ストアの遅延と継続であり、`StateRel` はこれらをコードの対応で結ぶ。値は同じままなので、初回の反例（応答が渡された閉包のコードを読む）の経路はない。`ClosureRel.returned` は、根の検査を省いた直後の捕捉の違いを `closeVal` の不変性で吸収する。`root_step` の省略の段には減少する尺度（`silentRank`）があり、元の無限実行が消去後の有限実行に潰れることはない。

観測の言明は、全 `events`・`obs` についての `Steps` と `terminal` の同値であり、`terminal` は正常値、失敗の理由列の全体、終了コードと理由列を区別する。`Diverges` は `¬Acc` で定義し、`diverges_iff_infinite` で無限実行の存在と同値にしている。これらの定理は型付けの前提を持たない。`Agreement B` は検査の署名と δ の二等式であり、`Agreement.complete` が仮定側の表 A に依らず供給するので、合成表が満たさない前提ではない。

型付けについて。`computation_preservation` は元の型付き計算の帰納（`Code.typed`）と、プログラムの差し替え（`in_erased_program`）で証明している。消去する位置では、開いた文脈の `check_typed_in_context` が `ok u v` を同じ篩付きの結果型で型付ける。`Ctx.Regular` やストアの型の条件を足さずに閉じており、追加の前提は要らない。`program_preservation` は範囲パラメータを持つ定義を全具体化で扱う（`Code.instR`）。前提の `RefinementCheck.Declarations P` は、証人で `RowEnv.ofAgree` の `check` 欄から供給している。

### 5. 01-12・07-04 の差分

01-12 の三段落（消去の範囲・`Site`・模倣と観測・型の保存）と表層の主定理の三段落、07-04 の二段落と対応表の二行を、Lean の定義と言明に照らした。`erase` が `let`・条件分岐・腕とガード・処理節・遅延と専用構築器を辿り値に入らないこと、`eraseProgram` が実装の宣言を保つこと、`Agreement` が二等式であること、`HasMain` の条件、表層の整形式を checker と独立に受けることは、実物と一致する。食い違いは軽(2)の一文だけである。

### 6. 処理系への受け口

R50 で処理系の消去と照合するための材料は情報2〜4にまとめた。消去の位置と条件は定義から読める。実入口と checker の表の接続は、中1・中2のとおり群 G の受け持ちとして明示する必要がある。

- **情報1**: `MainGuarantees` は群 B にない今回の構造である。依頼文の「群 B の MainGuarantees」に当たる既存の定義はない。各欄は `ProgramGuarantees` の欄の特殊化なので、群 G の旧主定理の交換では `ProgramGuarantees` を正とし、`MainGuarantees` を入口の系として扱えばよい。
- **情報2（R50 へ）**: `Site` は文面だけで決まるが、計算可能な判定や構文の十分条件の補題はない。処理系の消去の条件（例: 実引数が変数・ラムダ・場所を含まない閉じた値で、型引数が閉じて正規形、範囲引数がない）から `Site` を導く補題を、R50 の照合の前に置くと照合が機械的になる。期待型に型変数や範囲変数を含む呼出し、範囲引数を持つ呼出しは消去しない（検査2）。
- **情報3（R50 へ）**: 消去の位置は、トップレベルの定義の本体と main の計算の、ラムダの外である。遅延・専用構築器の本体・処理節・照合のガードは消去し、実装のメソッド本体は書き換えない（検査2の `(eraseProgram P).impls = P.impls`）。処理系がメソッド本体やラムダの中も消去するなら、その差を R50 で記録する（plan.md の案 B の判断）。
- **情報4**: 初回の反例 `CheckErasureBoundary.counterexample` と補助命題の反例 `PatternContextObstruction.obstruction` は、改造の確認用入力として残り、既定の import には入らない。前者はラムダの中を消去しない理由として、案 B の判断と整合する。

## 実行した検査

Lean はすべて `<repo>/formal/` から実行し、同時に一つだけとした。既定のビルド出力は上書きしていない。import 先は対象の worktree の既存のビルド済みモジュールである。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 1 | `<tmp>/Names.lean`。`surface_guarantees`・`linked_main`・`checkProgramAccepted_main`・`MainExamples.main_guarantees`・`erase`・`eraseProgram`・`observations_preserved`・`computation_preservation`・`program_preservation`・`Agreement.complete`・`BuiltinSource.builtins`・`StandardModel.builtins` の `#check`。616バイト、SHA-256 `f7c38220dcf06eae48112abfe14c252482674287f4eb778f5e0786f07ca77414` | 対象の名前はすべて解決し、署名は本書の記述と一致した。誤りは、存在しない名前を試しに引いた一行（`SafeCheckErasureExamples.checkedBody`。正しくは `SafeCheckErasure.checkedBody`）だけである |
| 2 | `<tmp>/Probe.lean`。`lazyC` の中の検査の消去、`closure`・`dependentLam` の保持、`(eraseProgram P).impls = P.impls`、範囲引数を持つ呼出しの保持、`Ty.tvar 0` が閉じた WF を満たさないこと、主な12定理（表層の主定理三つ・証人・観測四つ・型保存二つ・`state_step`・`state_reflect`）の公理依存。1,912バイト、SHA-256 `73793d68c7af389b20b7f0a00ea285b085c48a945c3c00c4fb590931ddcb4c14` | 終了0、誤りなし。公理は全て `propext`・`Classical.choice`・`Quot.sound` だけ |
| 3 | `<tmp>/Witness.lean`。証人の checker の表 `(MainExamples.input externals).D.funs f` が main 以外の全ての f で `none` であること | 終了0、誤りなし。506バイト、SHA-256 `0de114d2c95ff3f7f14a43a5ed51e6a93323a913351671644d02a9d2546cc90e` |
| 4 | 記録の読み合わせ。新規11モジュールの SHA-256 を記録した。`sorry`・`axiom`・`set_option` の出現は0件。`formal/Benitoite.lean` の追加は11 import 行だけ。01-12・07-04 の追記は観点5のとおり | 一致 |

新規モジュールの SHA-256 は次である（レビュー時点）。

| モジュール | SHA-256 |
|---|---|
| SafeCheckErasure | `bdc11f48afe21940166f55576ece555ef4f3806e37f3e99bb1050c87a39751f7` |
| SafeCheckErasureExamples | `e7354586142aacf17291403f3f21ccf03082b95b705629a86003004465ff4b7c` |
| SafeCheckObservations | `83d07bb7e5c48b3c181a76d389814af83132b4cc72470e6a41850f00c004b738` |
| SafeCheckPreservation | `5b5b0a4249f1621514cae4cb0dc01648d4b10107badc1a3cff2213c10442f22b` |
| SafeCheckPreservationExamples | `75f2ce07a481dd4938497dff7ab9dff4ebee668cdec8bb0124ef21432639e2a5` |
| SafeCheckReflection | `462e206b44d671ffff302175b137a3bd3208bae38fda3aeae5a3f306b3633948` |
| SafeCheckSimulation | `40d03aacc8a9a7772eb9779af9ab79aaa14d849638dd10d22c60a9c84a3cabff` |
| SafeCheckTyping | `9272d646ed1f31a545e10481716eb5e23dbe146a5faa219e1f6059b1349d8bb4` |
| SurfaceMain | `fbb578bd125e903ffdaf2b359688f8181e69b776f244226c24fc53a43675957d` |
| SurfaceLibrary | `783c0a47682eb3455500dc91d06ceb02a91ba2b63d61b7ca4c1127ee4dd3c672` |
| SurfaceMainExamples | `eae9a87d022c6eee1c2c5d3a403911c0096e96987b664ad1754bbb67d4212f17` |

## 処置の確認

2026-11-07。対象は同じ worktree の未コミットの作業木（再開2）で、基準は同じ `73585979113c7acf25b38673f9c2c52d1d38dfaf` である。読んだものは、本体の作業木にある依頼文 `work/m014/L70.e3-r2-prompt.md`・報告 `L70.e3-r2-report.md`、[results.md](../l70/e3/results.md) の「再開2」、新規の R/`SurfaceStandardSupport`・`SurfaceDeclarationAgreement`・`SurfaceCheckedMainExamples` と、01-12・07-04 の追記である。確認は処置の確認の一回であり、決まりは本レビューと同じとした。

**結論: 可。中1・中2・軽3件の処置はいずれも可である。新しい所見は軽1件と情報1件で、どちらも記録だけでよい。**

| 所見 | 判定 | 根拠 |
|---|---|---|
| 中1 | 可 | `CheckedMainExamples.main_guarantees` は前提を持たず、`Accepted ∧ ProgramGuarantees ∧ MainGuarantees` を結論する（検査5）。`checkProgramAccepted_main` に `input_sound`・`entry_succeeds`・`realizes` などを渡して得ており、実入口の成功を仮定に置いていない。`entry_succeeds` は `checker_succeeds`（部分の実行結果の合成）と `acceptance_succeeds` から導く。構成元に `.custom (complete …)` を選んだので、`q.B = complete nameLists T noAssumptions` は定義で成り立つ（検査5の `rfl`）。実入口の系の前提が空疎でないことの証人として十分である。`StandardSupport.complete` の392署名の支持は、台本に頼らず Lean の中で全件に及ぶ。`primitive` は `Primitive` の全構成子を `cases` で分け、各行を振分けの補題へ渡す。振分けの `match` が行を `Supported` に簡約しなければ型が合わないので、行の割り当ての誤りも漏れも Lean が検出する。台本は件数を数え直す照合にすぎない |
| 中2 | 可 | `realizes_of_check` は判定の成功から `funs`・`impls`・`ranges` を導き、`types` と `externalWF` を別に受けて `Realizes` の全欄を構成する。型の比較には、両側の有限支持の下で `rawTyEq_spec` を使う。証人の D は、利用者の表に無い `Range.checkInteger` の署名を補う（検査5。`source.defs` は `none`、`D.funs` は `standardDeclaration`）。保持した標準本体 `b016` との照合が真であり、利用者の main はこの関数を実際に呼んで checker を通る。`wrong_signature_rejected` は、同じ核の表との照合で `ret` だけを変えた宣言を偽にする。真の側と同じ表・同じ名前一覧なので、拒否の対照は意味を持つ |
| 軽(1) | 可 | `effects_preserved` の docstring と 01-12・07-04 に、直接の系であることと、型付けの効果の保存は `computation_preservation` が担うことを書いた |
| 軽(2) | 可 | 07-04 で、旧 example を「checker の前提を仮定とした適用」とし、実際の成功を供給する証人と分けて書いた |
| 軽(3) | 可 | 構造は保ったまま、`realizes` の呼出し元が `Includes.externalWF` と標準側の `ExternalWF` から供給している。docstring と写しにも供給元を書いた |
| 情報2〜4 | 可 | results.md の「後段への申し送り」に R50・群 G の照合事項として載った |

新しい所見:

- **軽**: results.md「完成表の支持と構成元」と報告は「392行の全件性は Python の照合台本で確認」と書く。上のとおり、全件性は `cases` の網羅で Lean が保証し、台本は件数の照合である。記録の一文を直すとよい。
- **情報**: `StandardSupport.complete` は仮定側の署名がない表（`noAssumptions`）に限る。IO など仮定側の組込みを呼ぶプログラムでは、実入口の `q.Sound` の `prims` の欄に、A の署名の有限支持が別に要る。results.md もこの範囲を書いているので、群 G の申し送りに「仮定側の署名の支持」を一行加えれば足りる。主定理と系は任意の A を受けたままであり、今回の可の判定は変わらない。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 5 | `<tmp>/Resume2.lean`。`main_guarantees`・`input_sound`・`entry_succeeds`・`realizes`・`realizes_of_check`・`StandardSupport.complete`・`primitive` の `#check`、証人の `q.B` が完成表に定義で一致すること、利用者の表に `Range.checkInteger` が無く D がその署名を補うこと、5定理の公理依存。1,241バイト、SHA-256 `5565175551736a4038cb367b1f720fdaf03a7cebf73bf60faf05de7bda4a37b9` | 終了0、誤りなし。`main_guarantees` の型に仮定は無い。公理は `propext`・`Classical.choice`・`Quot.sound` だけ |
| 6 | 新規3モジュールの読み合わせ。SHA-256 は `SurfaceStandardSupport` `b1d2cb957e9aad09aed64521433588e3ee8fb4754ad0fcbf82aad49a709520bd`、`SurfaceDeclarationAgreement` `d30f1c61d00514990c6aaee3e7e97708c7111b918c434ff5c921635af9828f33`、`SurfaceCheckedMainExamples` `ad316cc142ffb6db39a8f9d76166ac92642b8167c686bd9162b7d35e3ed91a17` | `sorry` と証明の上限の引上げは0件。`set_option` は `linter.unusedSimpArgs false` の一件だけで、証明の強さには関わらない |

## 取りまとめの追記

- 2026-11-07: 処置の確認は可。新しい軽（392行の全件性の保証の主語）は、取りまとめが results.md の該当の一文を「全件性は Lean の `cases` の網羅が保証し、台本は件数を照らすだけ」と直した。新しい情報（`StandardSupport.complete` は仮定側の署名がない完成表の支持であり、IO など仮定側の組込みを呼ぶプログラムでは `q.Sound` に仮定側の署名の支持が別に要る）は、群 G の依頼文の申し送りに足す。
- 前回の中1・中2 の処置案（群 G への申し送り）は採らず、群 E の後半の再開2で閉じた（前提が空疎でないことは群 E の完了条件のため）。
