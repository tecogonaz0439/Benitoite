# L00.01-ii の結果（案 (ii)：構造を持つ名前の記述と署名表）

作業 L00.01 のうち案 (ii) の枝の記録である。採用を決めない。案 (i) の欄は書かない（取りまとめが合わせる）。記録の `<wt>` は作業用のディレクトリ、`<repo>` は本線のディレクトリ、`<home>` はホームを表す。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.01-ii（plan「作業 L00.01」の案 (ii)） |
| 基準 | B_WORK `6124775788579e60530f55fb85570f26ef7fa900`（B0）。作業用のディレクトリの HEAD は `1009954381de6dd2f4a082b16221f3c762303bd3`（`git rev-parse HEAD`）。依頼文のとおり B0 から `formal/`・`crates/`・`scripts/` に差はない |
| 閉じた範囲 | 基準の既定ビルド、試行（15 回の比較用ビルド）、宣言・ファイル別の件数、試行の取り消し、独立の比較用の模型の配置と既定 import への追加、受け渡す状態の既定ビルド（`sorry` なし）、案 (ii) の比較の欄 |
| 未完の範囲 | 案 (i) との突き合わせ（取りまとめ）。plan「work L00 の各枝」の `scripts/check.sh --level work` は実行していない（「ずれと申し送り」） |

## 試行の内容

既存の構成子の引数の数を保ったまま、範囲を名前の記述へ入れ、範囲付きの署名を表の項目として通した。試行は最後の差分（`trial-15.diff`、36 ファイル、追加 305 行・削除 127 行）で既定ビルドの全入口が終了 0 になった。ただし `sorry` が 2 件残る（下の「未解決」）ので、成功とは数えない。試行はコミットせず、取り消した。

定義の変更（試行 1 で入れ、以後の試行で利用側を直した）:

| 対象 | 変更 |
|---|---|
| `Release/Atom.lean` | `EffName` を `String` の別名から構造体（`base : EffBase`（`String`）と `scope : NameScope`）へ変えた。`NameScope` は試行に要る最小の形（`top`・`pathExact`・`pathTree`）。`String` から Top の記述への暗黙の変換（`Coe`）を置いた。`stateEff` は `EffBase` |
| `Release/Types.lean` | `OpaqueName` を構造体（`base` と `index : NameScope`）へ変え、同じ変換を置いた。`Ty.opaque`・`Const.opaque` の引数の数は 1 のまま |
| `Release/Typing.lean` | `PrimSig` に欄 `target : Option Nat := none`（具体化できる対象の位置）を加え、`opEff` を `Option EffBase` にした。具体化 `PrimSig.inst s R`（R = Top なら `s` そのもの。それ以外は対象の位置の型の添字と効果の原子を同じ R にする）と、具体化が保つ欄の `simp` 補題、`inst_top`・`inst_eq_of_opEff_none`・`inst_eff_single` を加え、`inst` を既約にした。`V_Prim` は R を暗黙の引数に持ち、型は `fnTy (s.inst R)…`。項 `.prim b ts es` は変えていない。`Builtins.isResource`・`effects`、`OpSig.eff`、`effOps` は元の名前（`String`）で引き、`handled` は `l.base` で引く。旧の構築を保つ `HasTypeVQ.V_PrimTop` を加えた |
| `Release/Syntax.lean`・`Surface/Syntax.lean` | `OpDecl.eff`・`Program.effects`・`Declarations.effects` の鍵を元の名前にした |
| `Release/Semantics.lean` | 解放の規則の `isResource o.base`、`BuiltinOnly` の `l.base` |
| `Release/Assumptions.lean` | `delta_typed`・`io_typed`・`io_exists` を「任意の R について `s.inst R` の引数型・結果型」へ量化し直した。`io_op` に「対象の位置の型は Top の添字の不透明な型」の連言を加えた。`release_exists` は `o.base` |

## 比較用ビルドごとの終了・時間・件数

各ビルドは `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>`（既定の全入口、lakefile の `-M 12288`）。「時間」は `/usr/bin/time -l` の real（秒）、「待ち」は排他の待ち（秒、能動時間に入れない）。「未検査」は、失敗したモジュールを推移的に import するため検査されなかったモジュールの数で、既定の全入口の import の閉包は 267 モジュールである（`breakage.py` が lakefile の 8 つの根から数えた）。検出した件数は、その時点で検査できた範囲の破損であり、全依存の破損の総数ではない。

| ビルド | 直した群 | 終了 | 失敗モジュール | 未検査 | 診断 | ファイル | 宣言 | 時間 | 待ち | RSS（MiB） |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 00 基準 | 変更なし | 0 | 0 | 0 | 0 | 0 | 0 | 0.14 | 0 | 65.9 |
| 01 | 根の定義だけ | 1 | 1 | 239 | 2 | 1 | 1 | 0.65 | 0 | 663 |
| 02 | 順序（Order/Atoms・Order/Types） | 1 | 3 | 188 | 9 | 3 | 5 | 20.70 | 0 | 1609 |
| 03 | Finite・Semantics・Inversion | 1 | 4 | 183 | 9 | 4 | 7 | 18.57 | 0 | 1827 |
| 04 | Examples・ContLemmas・Regularity・比較の計算可能性 | 1 | 1 | 181 | 2 | 1 | 1 | 24.46 | 0 | 1824 |
| 05 | Regularity の R の名指し | 1 | 2 | 179 | 2 | 2 | 2 | 7.61 | 0 | 869 |
| 06 | OuterC、`inst` の既約化 | 1 | 3 | 167 | 4 | 3 | 3 | 32.54 | 0 | 1646 |
| 07a | （誤って変更なしで再実行。下の「失敗と修正」） | 1 | 2 | 167 | 3 | 2 | 2 | 7.61 | 72 | 909 |
| 07 | FailureCont・TySubstMain・Surface/Syntax | 1 | 3 | 81 | 8 | 3 | 8 | 118.41 | 0 | 1595 |
| 08 | Canonical・Surface/Check・符号化の構造化 | 1 | 4 | 58 | 11 | 4 | 9 | 157.00 | 88 | 1645 |
| 09 | Preservation・BuilderTyping・CheckTables・Surface/Typing | 1 | 4 | 41 | 19 | 4 | 5 | 39.39 | 0 | 2552 |
| 10 | PresBase・Extensions・ReturnTry・Convert、Top の具体化の恒等化 | 1 | 3 | 27 | 11 | 3 | 4 | 162.51 | 7 | 2551 |
| 11 | PresMain（一部）・Exchange/Builtins・Surface/Lemmas/Typing | 1 | 2 | 13 | 2 | 2 | 2 | 25.27 | 12 | 1394 |
| 12 | PresMain の残り・BuilderExamples | 1 | 1 | 12 | 21 | 1 | 3 | 4.07 | 32 | 832 |
| 13 | Progress | 1 | 2 | 10 | 3 | 2 | 2 | 3.90 | 0 | 838 |
| 14 | EffectSound・StepSound | 1 | 1 | 4 | 8 | 1 | 2 | 157.51 | 6 | 2551 |
| 15 | Model | 0 | 0 | 0 | 0 | 0 | 0 | 5.84 | 5 | 1429 |

試行の差分は `trial-NN.diff`（B0 からの累積）、各ビルドの全出力は `build-NN-trial.log`、宣言とファイルと未検査のモジュールの一覧は `count-NN.json` に置いた。`count-05/06/07a.json` の FailureCont の宣言は手で訂正した（誤りの位置 250 行は次の宣言 `HasTypeCQ.inv_handle_failure` の文書コメントの先頭で、道具が直前の宣言へ対応付けた）。最後の差分の宣言の一覧は `changed-decls-15.txt`（字句の近似。下の分類で手で整えた）、集計の道具は `breakage.py`・`changed_decls.py`。

各ビルドで新しく検出した破損は数件ずつで、失敗した import の先が毎回大きく残った（試行 1 で 239、試行 9 でも 41）。したがって、一回の比較用ビルドの件数を全体の破損の数として読むことはできない。全体の規模は、最後の差分の宣言の分類（次節）で読む。

## 破損の分類（最後の差分 trial-15 と B0 の比較）

字句の差分を宣言に対応付け、手で分類した。

| 区分 | 件数 | 宣言 |
|---|---:|---|
| 中心の定義の変更（意図した変更） | 8 ファイル | 上の「試行の内容」の表 |
| 定義の追随（鍵の型・`.base`・符号化・比較） | 20 宣言 | `Order/Atoms` の `code`（と `scopeChars`）、`Order/Types` の `Ty.toTree`・`tyCompare`（と範囲の木・順位・比較）、`Finite.tyCompareWith`、`Semantics.BuiltinOnly`・`ContTy` の解放の規則、`HasTypeCQ.C_Use`、`ContLemmas.FramesOk`、`Release/Examples.sig`、`Surface/BuilderExamples.signature`（位置の無名構築子）、`Surface/CheckTables` の 6 宣言、`Surface/Check.checkExprR`、`Exchange/Builtins` の 2 宣言、`Exchange/Convert.fromTy`（Top 以外を書き出さない） |
| 言明の変更 | 10 宣言と `Builtins.Assumptions` | `HasTypeVQ.inv_prim`・`inv_prim_app`（∃ s R、`s.inst R`）、`PrimitiveAdmissible.outer`・`.substTy`（`s.inst R`）、`progress_io`（引数を `s.inst R` の型で受ける）、`ContTy.end_of_noHandler`（名前を `EffName` に一般化）、`HasTypeCQ.inv_use`・`ContTy.inv_release`・`ContTy.prepend_releases`（`o.base`）、Surface の `E_With`（`o : OpaqueName` を明示し `o.base`）、`Builtins.Assumptions` の 5 欄（`delta_typed`・`io_typed`・`io_exists`・`io_op`・`release_exists`） |
| 証明だけの変更 | 22 宣言 | `canonical_boolean`・`canonical_ref`・`canonical_lazy`・`canonical_bytes`・`canonical_dict`（分解の要素数）、`HasTypeVQ.wf`（`inst_scoped`）、`HasTypeVQ.substTy`、`HasTypeVQ.outer`、`HasTypeCQ.inv_handle_failure`（heartbeats を 250000 に）、`store_prim_inv`・`refUpdate_typed`、`preservationE`（E_Prim・E_IO）、`progress_prim`、`step_soundE`、`no_event`、`Model.assumptions` と例、`HasTypeQ.desugar`・`stringAdd_typed`・`DieExitOk.app_typed`（`V_PrimTop`）、`Ty.toTree_injective`・`tyCompare_eq_treeCompare` |
| 新しい補題 | 16 宣言 | `PrimSig.inst_*` の 8 件、`inst_top`・`inst_eq_of_opEff_none`・`inst_eff_single`、`V_PrimTop`、`Ty.withIndex_varsIn`・`PrimSig.inst_scoped`、`NameScope.toTree_injective`・`scopeCompare_eq_treeCompare` |
| 未解決（試行で `sorry` を仮置き） | 2 宣言 | 下の表 |

主な定理（`Release.progress`・`preservation`・`effect_soundness`・`Surface.desugar_typed`）の言明の字面は変わっていない。ただし前提 `Builtins.Assumptions` の 5 欄の量化と内容が変わったので、前提が不変とは言えない（「ずれと申し送り」）。

| 未解決 | 理由 | 性格 |
|---|---|---|
| `Atom.code_injective`（`Order/Atoms`） | 構造を持つ名前を自然数へ単射に符号化する証明。試行では符号化の定義だけを構造的にした（`scopeChars`） | 証明だけ。案 (i) でも名前の構成子に範囲を持てば同じ義務が生じる |
| `preservationE` の `E_OpPrim`（`PresMain`） | 捕捉した組み込みの操作の節は、表の元の署名（Top）の引数型で型付けされる。引数は具体化した型を持つので、非関数の共変を足さない限り節の型付けへ渡せない | 設計の未決。節の添字 S と所属の専用補題（判断 11）が要り、`opSig`・節の型付けの言明の変更を伴う。証明だけの変更ではない |

### 暗黙の変換による黙った狭め

`String` から名前の記述への暗黙の変換は旧の綴りを Top として読むが、型が `String` のまま推論された箇所で、意味の狭めがコンパイルを通ったまま入った。次の 2 件は下流の証明の失敗で初めて見つかった。

- Surface の `E_With`: `isResource o` から `o` が `String` と推論され、`.opaque o` が Top の不透明な型に狭まった（`CheckSoundControl.with_case` の失敗で発覚）。
- `ContTy.end_of_noHandler`: `B.effects l` から `l` が `String` と推論され、`.name l` が Top の原子に限られた（`EffectSound.no_event` の失敗で発覚）。

変換に頼る箇所は B0 で、`.name "…"` 36 行（13 ファイル）、`Eff.single "…"` 75 行（9）、`.opaque "…"` 13 行（7）、`Eff.single <変数>` 47 行（18）、`stateEff` 53 行（15）ある。コンパイルが通ったことは、これらの箇所の意味が変わっていないことを示さない。案 (ii) を採るなら、変換を置かず、Top の記述を明示の構築関数で書くことを推す（その場合の検出件数はこの試行より増える）。

## 案 (ii) の比較の欄

| 観点 | 案 (ii) |
|---|---|
| 引数の数 | `Atom.name`・`Ty.opaque`・`Const.opaque`・Surface の `withE` の引数の数は 1 のまま。名前の型（`EffName`・`OpaqueName`）を構造体にした。`V_Prim` の暗黙の引数に R が一つ増えた（項は不変）。`PrimSig` に欄が一つ増え（既定値あり）、名前付きの構築は壊れず、位置の無名構築子の 1 件が壊れた。`Builtins` の欄の数は不変 |
| 場合分け | `Atom`・`Ty` の構成子が増えないので、全場合分けの追加はない。不透明な型の欄を文字列として読む 4 宣言（`Ty.toTree`・`tyCompare`・`tyCompareWith`・`Exchange.fromTy`）が壊れた。`inv_prim`・`inv_prim_app` の帰結を分解する 13 か所の要素数がずれた（証明だけ）。依存の場合分け 1 件が既定の heartbeats の上限をわずかに超えた |
| 比較 | 原子の符号化と型の順序が範囲を含む構造の比較になる。型の側は範囲の木と比較の一致の補題で閉じた。原子の符号の単射性は未証明（上の表）。具体の `rfl` の例 4 件は符号化を構造的に定義すれば通る（`reprStr` を使うと通らない）。構造の等号は範囲を区別し、判断 5 と合う |
| 整形式性 | `Ty.WF` の `.opaque _ => True` は変えていない。範囲の整形式性を型の WF へ入れるかは未決（模型では `Scope.WF` を別に定義した）。`PrimSig.Scoped` が具体化で保たれる補題が新しく要った |
| 資源の型 | 資源の判定を元の名前で行う形（`isResource : String → Bool`、利用側で `o.base`）にした。添字によらず資源かが決まる。言明・定義の変更 7 件（`C_Use`・`ContTy` の解放の規則・`release_exists`・`inv_use`・`inv_release`・`FramesOk`・`prepend_releases`）と Surface・交換の 4 件に及んだ |
| 所有元の差 | 範囲付きの署名の所有元は、操作の名前を鍵とする表の元の署名一つ。エフェクトの操作の一覧・`opEff`・操作の宣言の効果の鍵を元の名前に分けた。利用者のエフェクトの操作（`V_Op`）は Top の原子のまま（README Q9(c) と整合） |
| 範囲の数だけ操作 ID を発行しない | 発行しない。具体化は操作の名前を変えず、表の鍵・エフェクトの操作の一覧・節の照合は範囲によらない（模型の `callSig_same_key`・`effects_independent_of_scope`・`handled_scope`） |
| Top の対応 | 旧の綴りは Top の記述として読む。具体化を R = Top で恒等に定め、`inst_top : s.inst .top = s` を無条件に得た。旧の署名（対象の位置なし、または操作でない関数）は任意の R で不変。旧の構築は `V_PrimTop` で保った。模型では原子の往復・単射と、旧の効果の読み替えが範囲付きの原子を含まないことを示した |
| 信頼条件の欄 | 呼び出しが R を選ぶので、`delta_typed`・`io_typed`・`io_exists` を具体化した署名について量化し直す必要があった（「ずれと申し送り」の 1） |

## 受け渡す状態

- `<wt>/formal/Benitoite/Scope/RepresentationExamplesII.lean`（名前空間 `Benitoite.Scope.RepresentationExamples.CandidateII`）を新しく置いた。既存の定義を変えない独立の模型で、`Release.Atom`・`Release.Types` だけを import する。内容は、範囲（Top・パスの完全一致と木）、整形式性・所属・保守的な被覆とその健全性、名前の記述・原子・型の部分、旧の原子・不透明な型の名前との対応（往復・単射・範囲付きの原子が旧に対応しないこと・旧の効果の読み替え）、表の署名と具体化（`inst_top`・対象の位置なしで不変・欄の保存）、元の名前で引く表・資源の判定・節の判定、`/data/**` と `/data/a.txt` の非空の例（`#guard` 6 件と小さい定理）である。
- `<wt>/formal/Benitoite.lean` の末尾に `import Benitoite.Scope.RepresentationExamplesII` を一行加えた。旧の主定理と小補題は外していない。
- 既定ビルド: `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>`。終了 0、`Build completed successfully (411 jobs)`（基準は 410）。出力に `sorry` の警告はない（`grep -i sorry` で 0 件）。時間 165.65 秒（試行の取り消しで多くのモジュールを作り直した）、待ち 0 秒。ログは `build-20-handover.log`。
- 途中で `lake env lean -M 12288 Benitoite/Scope/RepresentationExamplesII.lean` を 2 回走らせた（初回は `covers_sound` の証明の余分な行で失敗、直して終了 0）。
- 公理の依存（`#print axioms`）は確かめていない。定義・言明・仮定とあわせてレビューで確認する（plan「work L00 の各枝」）。

## 最大常駐量

`/usr/bin/time -l` の maximum resident set size（バイト）。各ビルドは排他で一度に一つだけ走り、lake の全プロセスの中で最大の一つの値である（並行した別のプロセスの和ではない）。

| ビルド | 原値（バイト） | MiB | GiB |
|---|---:|---:|---:|
| 受け渡す状態の既定ビルド（20） | 2638364672 | 2516.1 | 2.46 |
| 試行の最大（10） | 2675195904 | 2551.3 | 2.49 |
| 基準（00、全て再利用） | 69058560 | 65.9 | 0.06 |

単一ファイルの検査の最大は 928497664 バイト（885.5 MiB）。`<repo>/work/m013/lean-guard.log` は確かめていない（ビルドの異常な停止はなかった）。

## 失敗と修正

- 試行 6 の初回: `attribute` の前に文書コメントを置いた構文の誤りで `Release.Typing` が失敗した（212 モジュールが未検査、1.29 秒）。行コメントに直して再実行した。初回のログは同じ名前で上書きしてしまい、残っていない。
- 試行 7a: 置き換えの道具が最初の置き換えで止まったのに、続くビルドが走った（変更は FailureCont の heartbeats の値 400000 だけ）。記録を `build-07a-noop-rerun.log`・`count-07a.json` に分け、差分は消して試行 7 をやり直した。
- `inv_handle_failure` の heartbeats は、単一ファイルの検査で 250000 と 400000 が通ることを確かめ、250000 にした。
- 模型の `covers_sound` の証明の余分な行を消した。

## ずれと申し送り

1. **信頼条件の欄の量化（要レビュー）**: 案 (ii) の試行では、`V_Prim` が R を選ぶので、既存の `delta_typed`・`io_typed`・`io_exists` を「任意の R について `s.inst R`」へ量化し直した。plan「全 L 作業の停止条件」は既存欄の量化や意味を変える場合を停止条件とし、一方で判断 15 は新しい索引付きの結果を既存欄の対象とすることを欄の追加に数えない。この量化の変更がどちらに当たるかは、L00.03（署名表と信頼条件）・L00.08 のレビューで決める必要がある。受け渡す状態は既存の定義を変えていないので、この枝は停止条件に該当しない。`io_op` に加えた連言と `release_exists` の `o.base` も同じ扱いである。
2. **捕捉した操作の節の添字**: `preservationE` の `E_OpPrim` は、節の添字 S と所属の専用補題（判断 11）なしには閉じない。`opSig`・節の型付けの言明の変更を伴う。L20・L30 の設計で扱う。案 (i) でも同じ論点が生じると見込むが、確かめていない。
3. **原子の符号の単射性**: 構造を持つ名前の単射な符号化の証明が要る（両案に共通の見込み）。
4. **暗黙の変換**: 採るなら変換を置かない形を推す（上の「暗黙の変換による黙った狭め」）。
5. **範囲の整形式性**: `Ty.WF` に範囲の整形式性を入れるか、所属の側で扱うかは未決。
6. **work の検査**: plan「work L00 の各枝」の `scripts/check.sh --level work --base 6124775788579e60530f55fb85570f26ef7fa900` は実行していない。依頼文が全体の `lake build` を排他の道具でだけ走らせるよう定めたためである。取りまとめが、取り込みの前に排他を保ったうえで実行するか、計画の割り当てを決める。
7. Surface の `E_Prim` は表の元の署名（Top）で型付けし、脱糖は `V_PrimTop` へ渡した。Surface が範囲付きの署名を選ぶ形は L40 の範囲である。

## 時間

| 区分 | 値 |
|---|---|
| 開始・終了 | 2026-10-27 17:50:12 〜 18:35（外側の所要 約 45 分） |
| ビルドの時間の和 | 約 953 秒（約 16 分。基準・試行 16 回・受け渡し。部分ビルドと単一ファイルの検査を除く） |
| 排他の待ちの和 | 222 秒（約 4 分） |
| 能動時間 | 約 25 分（外側の所要からビルドと待ちを除いた概算。読む時間を含む） |
| 見込みとの比 | plan の見込み 1〜2 時間の内。上端の 2 倍に達していない |
