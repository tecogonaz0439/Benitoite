# L00.06b の結果: 節の添字 S を案 (i) で閉じられるかの点検

2026-10-27。plan「計画の変更」の L00.06 の行が加えた枝 L00.06b を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l00.06b`）で行った。担当は Claude のサブエージェントである。試行はコミットしておらず、元に戻した。記録の `<wt>` は作業用のディレクトリ、`<repo>` は本線のディレクトリ、`<home>` はホーム、`<scratch>` は一時ディレクトリを表す。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.06b（案 (i) で、捕捉した組み込みの操作の節の添字 S を閉じられるかの実物の点検） |
| B_WORK | `91c9af89163fc08103efebf8642607bf05aee06c`（作業用のディレクトリの HEAD と同じ） |
| 閉じた範囲 | 案 (i) の最終の差分（`trial-30-final.diff`）の上に、署名の具体化（`PrimSig.inst`）と `V_Prim` の範囲 R を加えた試行 A が、節の添字を Top に置いたまま sorry なしで全体のビルドを通った。節の添字 S を節の型付けに持たせる一般化（試行 A2a）では、`E_OpPrim` の一つの義務だけが残った。二つの試行の件数、案 (ii) の未解決との比較、格納方式の判断への影響 |
| 未完 | 閉じた値が範囲付きの不透明型を持つ規則（値の所属の規則）を加えた、空でない実行時の場合の点検（下の「限界」と「申し送り」）。試行 A の閉じ方は、この規則がない今の状態では実行時に非 Top の値が現れないことに依っている |
| 採否 | 採用は決めていない。格納方式・最終の配置は L00.08 が決める |

## 変更と接続

受け渡す状態は「試行を元に戻した `<wt>` に、`l00.06b/` の記録だけを足した状態」である。`formal/` の差分はない（`git status --short` は `?? docs/…/l00.06b/` だけを示した）。設計書・01-12・07-04 は変えていない。

| 記録 | 内容 |
|---|---|
| `start-trial30.diff` | 開始状態（HEAD に `trial-30-final.diff` を当て、既定の import から三つの比較用の模型を外したもの）の HEAD からの差分 |
| `trial-A.diff`・`trial-A-incremental.diff` | 試行 A の HEAD からの累積の差分と、開始状態からの増分（16 ファイル、追加 207 行・削除 35 行） |
| `trial-A2a.diff`・`trial-A2a-incremental.diff`・`trial-A2a-vs-A.diff` | 試行 A2a の累積・開始状態からの増分（18 ファイル、+317/−56）・試行 A からの増分（6 ファイル、+110/−21） |
| `build-NN-*.log` | 全てのビルドの全出力（18 回） |
| `counts.json` | ビルドごとの終了・待ち・時間・最大常駐量・診断・失敗モジュール・未検査・sorry の警告・ジョブ数 |
| `axioms-A.lean`・`axioms-A.log` | 試行 A の状態での主定理と新しい補題の公理の依存 |
| `examples-A.lean` | 試行 A の状態で確かめた非 Top の小例（試行 A の状態でだけ通る） |
| `tools/unchecked.py`・`tools/decls.py` | 未検査のモジュールの数え方（既定の 8 つの根から import の閉包を辿る）と、差分の行を宣言へ対応付ける字句の近似 |
| `work-check-dry-run.log` | 受け渡す状態の work の dry-run |

## 開始状態の合わせ方

`trial-30-final.diff` は HEAD に競合なく当たった（`git apply --check` が通った）。ただし最初のビルド（01）は、L00.01 の後に置いた比較用の模型 `Scope/RepresentationExamplesI`・`RepresentationExamplesII` が旧の 1 引数の構成子（`.name l`・`.opaque o`）を使うために失敗した（22 診断、2 ファイル。両者を import する `CompatExamples` と根の `Benitoite` が未検査）。これらの模型は試行の前の `Release` と範囲付きの原子の対応を記す比較用の模型であり、本点検の対象ではないので、試行の間だけ `formal/Benitoite.lean` から三つ（`RepresentationExamplesI`・`II`・`CompatExamples`）の import を外して開始状態とした。開始状態のビルド（02）は 414 ジョブ、sorry なしで通った。模型を直して残す手当ては試していない。

## 試行の内容

### 試行 A: 署名の具体化と V_Prim の範囲（節の添字は Top）

L00.06 の提案と同じく、案 (ii) の L00.01 の試行（`candidate-ii/trial-15.diff`）の署名の具体化に条件をそろえた。

| 対象 | 変更 |
|---|---|
| `Release/Typing.lean` の `PrimSig` | 欄 `target : Option Nat := none`（具体化できる対象の引数の位置）を加えた。案 (ii) の試行と同じ欄である |
| `PrimSig.inst s R` | R = Top なら `s` そのもの。そうでなく `target = some p`、`opEff = some l` で、位置 p の引数が不透明型 `.opaque o _` なら、その引数を `.opaque o R`、効果を原子 `.name l R` 一つにする。それ以外は `s`。案 (ii) との違いは「位置 p の引数が不透明型のときだけ具体化する」という条件を定義に置いたことである（案 (ii) は `io_op` に「対象の位置の型は Top の添字の不透明な型」の連言を足した）。既約にした |
| `V_Prim` | 暗黙の引数 R を持ち、型は `fnTy (s.inst R).names (s.inst R).params (s.inst R).ret (s.inst R).eff ts es`。項 `.prim b ts es` は変えていない。旧の構築は新しい補題 `HasTypeVQ.V_PrimTop`（R = Top）で保った |
| `opSig`・`HasTypeClausesQ`・`E_OpPrim`・`Builtins.Assumptions` | 変えていない。節は表の署名（Top）の引数型で型付けされたままである |

`E_OpPrim` を閉じた方法: 閉じた値で範囲付きの不透明型を持つものはない（新しい補題 `HasTypeVQ.closed_opaque_top`。不透明型の閉じた値は定数だけで、案 (i) の試行の `Const.type` は Top の範囲の不透明型だけを返す）。具体化が署名を変えるのは対象の位置が R ≠ Top の不透明型になるときだけなので、閉じた引数の列が具体化した引数型を持つなら具体化は表の署名そのものである（`PrimSig.inst_eq_of_closed_args`）。これで `inv_prim_app`（閉じた呼び出しの分解）を旧の言明のまま証明し直し、その利用側（`preservationE` の `E_Prim`・`E_IO`・`E_OpPrim`、`progress_prim`・`progress_io`、`step_soundE`、`no_event`）を言明も証明も変えずに通した。

### 試行 A2a: 節の型付けに添字 S を持たせる（S を任意にした場合）

試行 A の上に次を加えた。

| 対象 | 変更 |
|---|---|
| `opSigAt P B S o` | 新しい定義。組み込みの操作では引数型を `(s.inst S).params` にし、型パラメータ・結果・引数名・エフェクトの名前は `opSig` と同じ。他の操作は `opSig` と同じ。`opSigAt_top`（S = Top で `opSig`）と `opSigAt_rel`（`opSig` との違いは対象の位置の引数型だけ）を証明した |
| `HasTypeClausesQ.cons` | 暗黙の引数 S を持ち、前提を `opSigAt P B S o = some sg` にした。S を選ぶ条件は置いていない |
| 利用側 | `HasTypeClausesQ.find` の言明を `∃ S sg, opSigAt P B S o = some sg ∧ …` に、`no_failure`・`substTy` の証明を新しい補題 `opSigAt_ne_fail`・`opSigAt_scoped` に替えた。Surface の `HasClausesQ.desugar` は S = Top を渡した |
| `pres_op_common` | 節の側の署名 `sg2`（`opSigAt S`）で証明し直した。型パラメータと結果は `opSigAt_rel` から旧と同じになり、引数型だけが違いうる。引数型が同じ場合は閉じ、対象の位置が `opaque o' S`（S ≠ Top）になる場合に `sorry` を一つ置いた |

残った `sorry` の義務: 呼び出しの閉じた引数は表の（Top の）署名の型を持つ（試行 A の `inv_prim_app`）。節は S ≠ Top の範囲の不透明型を対象の位置に求める。S を任意に選べる規則では、この義務は一般に偽である。Top の型だけを持つ定数を、範囲 S の不透明型の引数を期待する節の本体へ渡すと、置き換えた後の本体に型が付かない場合がある。したがって A2a は「S を任意にすると閉じない」ことの記録であり、`sorry` は未証明の部分ではなく、満たせない義務を示す。

## 比較用ビルドごとの終了・時間・件数

各ビルドは `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>`（既定の全入口、lakefile の `-M 12288`）。時間は `/usr/bin/time -l` の real（秒）、待ちは排他の待ち（秒、能動時間に入れない）。未検査は、失敗したモジュールを推移的に import するため検査されなかったモジュールの数である（`tools/unchecked.py`。開始状態の import の閉包は 271 モジュール、HEAD は 274）。宣言は診断の位置を手で宣言へ対応付けた数である。

| ビルド | 状態・直した群 | 終了 | 失敗モジュール | 未検査 | 診断 | ファイル | 宣言 | sorry | 時間 | 待ち | RSS（MiB） |
|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 00 | HEAD（基準） | 0 | — | 0 | 0 | 0 | 0 | 0 | 0.15 | 0 | 66.2 |
| 01 | `trial-30-final.diff` を当てた | 1 | RepresentationExamplesI・II | 2 | 22 | 2 | 比較用の模型 | （誤りから 5） | 164.83 | 0 | 2534.1 |
| 02 | 開始状態（三つの import を外した） | 0 | — | 0 | 0 | 0 | 0 | 0 | 0.79 | 0 | 1438.5 |
| 03 | A: `PrimSig.inst`・`V_Prim` の R | 1 | Inversion | 184 | 4 | 1 | 1（`inv_prim`） | 0 | 14.44 | 1 | 1377.8 |
| 04 | `inv_prim` の言明 | 1 | Regularity | 183 | 3 | 1 | 1（`HasTypeVQ.wf`） | 0 | 9.97 | 0 | 1616.2 |
| 05 | `inst_scoped` の利用（R の名指し漏れ） | 1 | Regularity | 183 | 2 | 1 | 1 | 0 | 15.93 | 12 | 1622.0 |
| 06 | R の名指し | 1 | OuterC | 181 | 1 | 1 | 1（`HasTypeVQ.outer`） | 0 | 7.50 | 0 | 894.1 |
| 07 | `PrimitiveAdmissible.outer`・`.substTy` の言明 | 1 | OuterC | 181 | 3 | 1 | 1（`PrimitiveAdmissible.outer`） | 0 | 1.75 | 9 | 762.2 |
| 08 | 引数の順の誤りを直した | 1 | TySubstMain | 46 | 2 | 1 | 1（`HasTypeVQ.substTy`） | 0 | 129.33 | 112 | 2524.6 |
| 09 | `HasTypeVQ.substTy` | 1 | Canonical | 40 | 3 | 1 | 3（`canonical_boolean`・`_ref`・`_lazy`） | 0 | 10.15 | 5 | 981.5 |
| 10 | 分解の要素数（5 宣言）、`closed_opaque_top`・`inst_eq_of_closed_args`・`inv_prim_app` | 1 | PresBase・Extensions・ReturnTry | 25 | 17 | 3 | 3（`refUpdate_typed`・`stringAdd_typed`・`DieExitOk.app_typed`） | 0 | 11.27 | 0 | 998.2 |
| 11 | `V_PrimTop` への置き換え（8 か所。うち 4 か所は先回り） | 1 | BuilderExamples | 1 | 1 | 1 | 1（`signature`） | 0 | 24.85 | 19 | 1427.6 |
| 12 | 位置の無名構築子 | **0** | — | 0 | 0 | 0 | 0 | **0** | 1.64 | 0 | 1437.7 |
| 13 | A2a: `opSigAt`・節の S・利用側 | 1 | Preservation | 34 | 1 | 1 | 1（`pres_op_common`） | 0 | 146.87 | 0 | 2522.9 |
| 14 | `pres_op_common`（sorry 1） | 1 | Surface/Lemmas/Typing | 11 | 1 | 1 | 1（`HasClausesQ.desugar`） | 1 | 150.10 | 111 | 2527.3 |
| 15 | S = Top を渡した | **0** | — | 0 | 0 | 0 | 0 | **1** | 23.48 | 0 | 1449.6 |
| 16 | 試行 A の状態を作り直した（公理の確かめのため） | 0 | — | 0 | 0 | 0 | 0 | 0 | 152.26 | 0 | 2519.8 |
| 17 | 受け渡す状態（試行を元に戻した） | 0 | — | 0 | 0 | 0 | 0 | 0 | 164.44 | 0 | 2521.5 |

ビルド 10 の前に、同じ要素数のずれを持つ `canonical_dict`（Progress）・`canonical_bytes`（BuilderTyping）を、ビルド 11 の前に `V_Prim` を構築する Surface/Lemmas/Typing の 3 か所と Model の 1 か所を、検出を待たずに先回りして直した。そのため、これらは一回のビルドの破損として数えていない。破損の全体は、次節の最終の差分で数える。

## 破損と変更の分類（開始状態からの増分）

字句の差分を宣言へ対応付け（`tools/decls.py`、文書コメントの行は直前の宣言へ寄るので手で直した）、手で分類した。

### 試行 A（sorry なしで通った）

| 区分 | 件数 | 宣言 |
|---|---:|---|
| 中心の定義の変更（意図） | 2 定義 | `PrimSig`（欄 `target`）、`HasTypeVQ` の構成子 `V_Prim`（R） |
| 新しい定義 | 1 | `PrimSig.inst`（既約） |
| 定義の追随 | 1 | `Surface/BuilderExamples.signature`（位置の無名構築子に `none` を一つ） |
| 既存の定理の言明の変更 | 3 | `HasTypeVQ.inv_prim`（∃ s R、`s.inst R`）、`PrimitiveAdmissible.outer`・`PrimitiveAdmissible.substTy`（`s` を `s.inst R` に） |
| 証明だけの変更 | 12 | `canonical_boolean`・`canonical_ref`・`canonical_lazy`・`canonical_bytes`・`canonical_dict`（分解の要素数）、`HasTypeVQ.wf`・`HasTypeVQ.substTy`（`inst_scoped`）、`inv_prim_app`（閉じた引数から `inst R = s`）、`refUpdate_typed`・`stringAdd_typed`・`DieExitOk.app_typed`・`HasTypeQ.desugar`・Model の例 1 件（`V_PrimTop`）。このほか `HasTypeVQ.outer` はビルド 06 で壊れたが、`PrimitiveAdmissible.outer` の言明を変えたことで字面を変えずに通った |
| 新しい補題 | 17 | `PrimSig.inst_top`・`inst_cases`・`inst_eq`・`inst_fields` と欄ごとの simp 補題 9 件（`inst_tparams`・`ntys`・`neffs`・`admits`・`kind`・`names`・`ret`・`opEff`・`params_length`）、`PrimSig.inst_scoped`、`HasTypeVQ.V_PrimTop`、`HasTypeVQ.closed_opaque_top`、`PrimSig.inst_eq_of_closed_args` |
| 前提（`Builtins.Assumptions`）の変更 | 0 | 欄の追加・量化・内容の変更はない |
| 変えずに通った主な宣言 | — | `opSig`・`opSig_scoped`・`opSig_ne_fail`・`HasTypeClausesQ`・`HasTypeClausesQ.find`・`Step`、`preservationE`・`pres_op_common`・`progress_prim`・`progress_io`・`step_soundE`・`no_event`、`Model.assumptions`、四つの主定理と `step_sound`・`effect_soundness_noLamNames`、Surface の `HasClausesQ`・`Check.opSig_atoms`・`opSig_clean` |

主定理の言明の字面は変わっていない。`V_Prim` は型付けの関係そのものの構成子なので、主定理の前提（`WellTyped`・`StateTy`）が使う関係の内容は変わる。これは非 Top の署名の型付けを入れる以上、格納方式によらず生じる（案 (ii) の試行も同じ）。

公理の依存（`axioms-A.log`。試行 A の状態で `lake env lean -M 12288 <scratch>/axiomsA.lean`）: 四つの主定理・`step_sound`・`effect_soundness_noLamNames`・`preservationE`・`pres_op_common`・`inv_prim_app`・`inv_prim`・`Model.assumptions`、新しい補題 8 件、言明を変えた `PrimitiveAdmissible.outer`・`.substTy` の計 21 件は、`propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する。`sorryAx` と独自の公理はない。

非 Top の小例（`examples-A.lean`、試行 A の状態で単一ファイルの検査が終了 0）: 対象の位置 0 が `Scope.PathIn` の署名を範囲 `pathExact ["data","a"]` で具体化すると、引数の型と効果の原子が同じ範囲を指す（`readSig_inst`）。開いた項では、この具体化した型を `.prim b [] []` に付けられる（静的な型付けは空でない）。一方、閉じた値はその型を持たない（`closed_opaque_top` から）。

### 試行 A2a（試行 A からの増分。sorry 1 で通った）

| 区分 | 件数 | 宣言 |
|---|---:|---|
| 定義の変更 | 1 | `HasTypeClausesQ.cons`（暗黙の S、前提 `opSigAt P B S o = some sg`） |
| 新しい定義 | 1 | `opSigAt` |
| 既存の定理の言明の変更 | 1 | `HasTypeClausesQ.find`（∃ S sg） |
| 証明だけの変更 | 4 | `HasTypeClausesQ.no_failure`・`HasTypeClausesQ.substTy`・Surface の `HasClausesQ.desugar`（S = Top を渡す）、`pres_op_common`（節の側の署名で証明し直した。場合の一つに sorry） |
| 新しい補題 | 4 | `opSigAt_top`・`opSigAt_rel`・`opSigAt_ne_fail`・`opSigAt_scoped` |
| 前提の変更 | 0 | — |
| 未解決 | 1 | `pres_op_common` の、対象の位置が `opaque o' S`（S ≠ Top）になる場合 |

`preservationE`・`progress_io`・`step_soundE`・`no_event` は A2a でも変えずに通った（`pres_op_common` の言明が変わらないため）。ただし `pres_op_common` が sorry を含むので、A2a の状態の主定理は `sorryAx` に依存する（公理の確かめは A2a では行っていない）。

## 閉じたかどうか

| 問い | 結果 |
|---|---|
| 案 (i) で、節の添字を Top に置いて `E_OpPrim` を閉じられるか | 閉じた（試行 A。sorry なし、`Builtins.Assumptions` の変更なし、主定理の言明の変更なし） |
| 節の型付けに添字 S を持たせ、S を任意にして閉じられるか | 閉じない（試行 A2a）。残った義務は一般に偽であり、S を選ぶ規則が要る |
| 判断 11 の規則（保護本体の効果の同名の閉じた一原子から S を選ぶ）で閉じられるか | 試していない。下の「限界」のとおり、今の試行の状態では実行時に非 Top の値が現れないので、規則を入れても実行時の場合は空になる見込みであり、規則の費用（継続の型に保護本体の効果か S を残すこと）だけが測れる |

## 限界（閉じ方の意味）

1. 試行 A の実行時の場合は、範囲 R ≠ Top では空に成り立つ。案 (i) の試行の `Const.type` は Top の型だけを返し、範囲付きの不透明型を持つ閉じた値の規則がないので、非 Top の具体化は開いた項（範囲付きの型の変数を引数に持つラムダの本体など）にだけ付き、閉じた呼び出しでは必ず `inst R = s` になる。試行 A は「非 Top の静的な型付けを加えても、実行時の定理の証明は変えずに済む」ことを示すが、「非 Top の値が実行時に現れても保存が成り立つ」ことは示さない。
2. 実行時に非 Top の値を現すには、値の所属の規則（L00.06 の印 NT。範囲付きの不透明型を、検査した対象がその範囲に属する値に与える規則）が要る。そのとき、`closed_opaque_top` は「R への所属から R を覆う S への所属を得る」拡大の補題（判断 11 の専用補題。L00.03 の模型の `clause_arg_typed`・`HasTypeV.widen`）に置き換わる。S = Top なら被覆は無条件である。
3. 同じとき、`E_IO`・`E_Prim`・`progress_io` の引数は `s.inst R` の型を持つので、`io_typed`・`io_exists`・`delta_typed` を R について量化する（案 (ii) の試行の形）か、引数を表の Top の型へ拡大してから旧の欄を使う必要がある。後者は、結果の型が R によらない七つの IO では旧の欄のままで足りる見込みである。結果の型に R が現れる純粋な検査（`checkPathIn` など）では `delta_typed` の量化が要る（判断 15・L00.03 の申し送り 1）。どちらも格納方式によらない。
4. S を Top 以外に選ぶには、呼び出しの R が S に覆われることを実行時に導く必要がある。今の継続の型 `K_Handle` は穴の効果を `εc ∪ handled h` とし、案 (i) の試行の `handled` は `.name l r` の r を見ないので、継続から R ⊆ S は出ない。継続の型に保護本体の効果（または S）を残す変更が要る（L00.03 の申し送り 4 の `hcov`、L30 の「節の添字の精度」）。これも格納方式によらない。
5. 件数は開始状態からの字句の差分であり、Top に特化した L00.01 の試行 30 の上に積んだ値である。値の所属の規則・継続の型の変更・観測の欄・`io_target` の費用を含まない。

## 案 (ii) の未解決（`E_OpPrim`）との比較

| 観点 | 案 (ii) の L00.01 の試行（`trial-15`） | 案 (i) 試行 A（S = Top） | 案 (i) 試行 A2a（任意の S） |
|---|---|---|---|
| 署名の具体化 | `PrimSig.inst`（欄 `target`、R = Top で恒等） | 同じ条件。対象の位置が不透明型のときだけ具体化する | 試行 A と同じ |
| `V_Prim` | 暗黙の R、`s.inst R` | 同じ | 同じ |
| 節の型付け | 表の署名（Top）、`opSig` 不変 | 同じ | `opSigAt S`、S は任意 |
| 不透明な定数の型 | `Const.opaque` の名前が構造体（添字を含む）で、`Const.type` は添字付きの型を返す。範囲 R ≠ Top の閉じた値が、所属の不変条件なしに作れる | `Const.type` は Top の型だけ（L00.01 の案 (i) の試行 30 の定義）。範囲 R ≠ Top の閉じた値はない | 試行 A と同じ |
| `E_OpPrim` | sorry。引数（具体化した型）を節（Top の型）へ渡せない | 閉じた（`inv_prim_app` が `inst R = s` を導く） | sorry 1。Top の型の引数を S の型を求める節へ渡せない |
| `E_Prim`・`E_IO`・進行・`step_soundE`・`no_event` | 欄の量化で閉じた（証明の変更） | 言明・証明とも不変 | 不変 |
| `Builtins.Assumptions` | 5 欄（`delta_typed`・`io_typed`・`io_exists` の量化、`io_op` の連言、`release_exists` の `o.base`） | 0 | 0 |
| 既存の定理の言明の変更（署名の具体化に関わるもの） | `inv_prim`・`inv_prim_app`・`PrimitiveAdmissible.outer`・`.substTy`・`progress_io` など | `inv_prim`・`PrimitiveAdmissible.outer`・`.substTy` の 3 件（`inv_prim_app`・`progress_io` は不変） | 加えて `HasTypeClausesQ.find` の 1 件 |
| 残る義務の内容 | 閉じた値を R の型から S（= Top）の型へ拡大する | 同じ義務が空に成り立つ（閉じた非 Top の値がない） | 閉じた値を R（実際は Top）の型から S の型へ拡大する。R ⊆ S を導く規則がなく、一般に偽 |
| 義務の原因 | 定数が範囲を持ち、型付けが範囲を区別する（拡大の規則がない）という試行の条件 | — | 節の添字を選ぶ規則がないこと |

案 (ii) の義務と案 (i) A2a の義務は同じ形（閉じた値の、範囲の違う不透明型への拡大）であり、値の所属の規則と拡大の補題（限界 2）、R ⊆ S を導く規則（限界 4）で閉じる。どちらも格納方式によらない。

案 (ii) が S = Top でも閉じなかったのは、格納方式そのものより、定数の型が範囲を持つという試行の条件による見込みである。案 (ii) でも、不透明な定数の型を Top の添字に正規化する（または定数に元の名前だけを持たせる）なら、試行 A と同じ `closed_opaque_top`・`inst_eq_of_closed_args` で閉じ、欄の量化も要らなくなる見込みである。この見込みはビルドで確かめていない（案 (ii) の試行の状態を使う L00.06c で確かめられる）。

## 格納方式の判断への影響

1. L00.06 の未分類のうち、`E_OpPrim` に由来する群（`preservationE`・`pres_op_common`・`step_soundE`・`no_event`・`progress_io`・`HasTypeClausesQ.find`、`opSig_scoped`・`opSig_ne_fail`、`Step`・`HasTypeClausesQ`、Surface の `HasClausesQ`・`Check.opSig_atoms`・`opSig_clean`）は、案 (i) で節の添字を Top に置くかぎり、すべて変えずに通った（点検のみ）。節の型付けに S を持たせると、`HasTypeClausesQ`（定義）・`find`（言明）・`pres_op_common`（証明と未解決）・`no_failure`・`substTy`・Surface の `HasClausesQ.desugar`（証明）が変わる。`BuilderStore` の 4 件と `drop_local_silent` などはどちらの試行でも変わらなかった。
2. 二案の差として残るのは「範囲が定数に入るか」である。案 (i) は範囲が `Ty`・`Atom` の構成子の引数にだけあり、`Const.opaque` は範囲を持たないので、範囲付きの値は所属の規則を通してしか作れない。案 (ii) は名前の型を `Ty` と `Const` で共有するので、定数が範囲を持たないことを別の定義（元の名前の型を分けるか、`Const.type` の正規化）で保つ必要がある。この点では案 (i) の方が、所属の不変条件のない非 Top の値を構造上作りにくい。ただし案 (ii) で必要な手当ては定義一つとその追随であり、格納方式の判断を決めるほどの差ではない見込みである。
3. 節の添字の精度（任意の S、判断 11 の規則）と値の所属の規則の費用は、二案で同じ相互帰納と継続の型に及ぶ（L00.06 の印 NT・CS）。L20.2 の枝の大きさは、格納方式ではなく、値の所属の規則の置き方（L00.07）と継続の型に S を残す形（L30）で決まる。
4. L00.04 の推す案 BB と矛盾しない。`BuiltinOnly` は変えておらず、試行 A では非 Top の効果は開いた項の静的な型にだけ現れ、継続の末尾 Eb に届かない。

## 受け渡す状態

- `git restore --worktree --staged -- formal` と `git clean -fd -- formal/Benitoite formal/Benitoite.lean` で試行を戻した。`git status --short` は `?? docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.06b/` だけを示し、`formal/` の差分はない。
- 既定ビルド（17）: `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>`。終了 0、`Build completed successfully (417 jobs).`、出力に sorry の一致は 0 件（`grep -ci sorry`）、誤りの診断 0 件。時間 164.44 秒（試行を戻したため多くのモジュールを作り直した）、待ち 0 秒。ログは `build-17-handover.log`。
- work の dry-run: `cd <wt> && scripts/check.sh --level work --base 91c9af89163fc08103efebf8642607bf05aee06c --dry-run` は終了 0、`nothing to check: only documents changed`（`work-check-dry-run.log`）。選ばれる検査がないので、実行はしていない。

## 最大常駐量

`/usr/bin/time -l` の maximum resident set size（バイト）。各ビルドは排他で一度に一つだけ走り、値は lake が待ち合わせた子孫のうち最大の一プロセスの常駐量である（並行した lean のプロセスの和ではない）。

| 実行 | 原値（バイト） | MiB | GiB |
|---|---:|---:|---:|
| 受け渡す状態の既定ビルド（17） | 2644000768 | 2521.5 | 2.46 |
| 試行の最大（01） | 2657222656 | 2534.1 | 2.47 |
| 基準（00、全て再利用） | 69419008 | 66.2 | 0.06 |
| 公理の確かめ（単一ファイル） | 1500151808 | 1430.6 | 1.40 |
| 非 Top の小例（単一ファイル） | 1514815488 | 1444.6 | 1.41 |

途中の単一ファイルの検査（`lake env lean -M 12288 <ファイル>`、Typing・Inversion・OuterC・TySubstMain・Canonical・Preservation の約 10 回）は計時で包んでいない。`-M 12288` は変えていない。ビルドの異常な停止はなかったので、`<repo>/work/m013/lean-guard.log` は確かめていない。

## 失敗と修正

- ビルド 01: 比較用の模型が旧の構成子を使っていて失敗した。試行の間だけ三つの import を外した（「開始状態の合わせ方」）。
- ビルド 05: `V_Prim` の場合で範囲 R を名指しせず、`inst_scoped _` の R を推論できなかった。パターン `.V_Prim (R := R) …` で名指しした。
- ビルド 07: `admits_local` の引数の順（`b s C1 C0 ts`）を取り違えた。単一ファイルの検査で直してから進めた。
- 単一ファイルの検査で、`Ty.opaque` の省略記法が推論できない、`if_false` の非推奨、`HasTypeVsQ.lookup` より前に補題を置いた、`opSigAt_rel` を加えた後に古い olean で検査した（未知の識別子）、の誤りがあった。いずれも直すか全体のビルドで olean を作り直して解消した。
- ビルドの集計の補助の道具で、sorry の警告を `'sorry'`（直線の引用符）で数えていたため、ビルド 03〜14 の表示が 0 になっていた。ログの表記は逆引用符なので、`declaration uses .sorry.` に直して全ログを数え直した（上の表）。

## ずれと申し送り

計画・依頼からのずれ:

1. 依頼文以外の [`work/m013/`（写し）](../evidence/work-copies/m013/) のファイルを読まない指示に反して、ログの形式を確かめるために排他の道具 `lake-build-locked.sh` の中身を一度 `cat` で表示した。変更はしていない。
2. 片付けの途中で、排他の道具を `formal` でない `<wt>` の根でログ `/dev/null` を指定して一度起動した。`<wt>` の根に lakefile はなく、生成物ができていないこと（`git status --ignored` と `.lake` の有無）を確かめた。ビルドの件数には数えていない。
3. 試行の間、既定の import から比較用の模型三つを外した（受け渡す状態では戻した）。
4. 試行 A2a は依頼の「一般化」の一つの形（S を任意にする）だけを試した。判断 11 の S の選び方は限界 4 の理由で試していない。

申し送り（取りまとめが計画へ転記する候補）:

1. **値の所属の規則の点検**（L00.07 か L20）: 範囲付きの不透明型を閉じた値に与える規則を一つ足し、試行 A の `closed_opaque_top` を拡大の補題に置き換えて、`E_OpPrim`（S = Top）と `E_IO` が空でなく閉じるか、`io_typed`・`io_exists` を量化せずに済むか（限界 3）を確かめる。`HasTypeVQ` の構成子を足すと相互帰納の全ての場合分けに一つずつ腕が加わる（印 NT）ので、L00.07 の NT・NV の方針と合わせて決める。
2. **節の添字の精度**（L30）: 継続の型に保護本体の効果か S を残し、R ⊆ S を導く。A2a の `opSigAt`・`opSigAt_rel`・`HasTypeClausesQ.find` の言明の形は、その足場として使える。
3. **案 (ii) の定数の範囲**（L00.06c）: 案 (ii) で不透明な定数の型を Top の添字に正規化すれば、試行 A と同じ形で `E_OpPrim` が閉じ、欄の量化が要らなくなるかを確かめると、二案の比較が同じ条件にそろう。
4. **具体化の条件の置き場所**（L00.08）: 試行 A は「対象の位置の引数が不透明型のときだけ具体化する」を `PrimSig.inst` の定義に置き、`io_op` の内容を変えなかった。案 (ii) の試行はこれを `io_op` の連言に置いた。どちらにするかは、判断 15 の `io_op` の変更（具体化した入力添字・効果・対象位置の対応の検査）とあわせて決める。
5. 停止条件: 試行 A は旧の四主定理の前提・結論の字面、`Builtins.Assumptions` の欄を変えていない。A2a で節の型付けの関係を変えたことは比較の試行の記録である。どちらも受け渡す状態に残していない。停止条件に当たる事項は見つからなかった。

## 時間

| 区分 | 値 |
|---|---|
| 開始・終了 | 2026-10-27 19:52 〜 20:40（外側の所要 約 48 分） |
| ビルドの時間の和 | 約 1030 秒（約 17 分。18 回） |
| 排他の待ちの和 | 269 秒（約 4.5 分） |
| 能動時間 | 約 25〜30 分（外側の所要からビルドと待ちを除いた概算。ビルドの間の読みと準備が重なるので近似。読む時間と記録の作成を含む） |
| 見込みとの比 | plan の見込み 1.5〜3 時間の内。上端の 2 倍（6 時間）に達していない |
