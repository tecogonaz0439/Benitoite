# L00.08b の結果: 採用定義の最終の配置と、採らなかった候補の削除

2026-10-27。plan「作業 L00.08」の手順のうち、採択後の配置と削除を行った。取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l00.08b`）で行い、担当は Claude のサブエージェントである。コミットは取りまとめが行う。配置と削除の内容は [placement.md](placement.md)、直した本番の言明の案は [reviews/L00.08b-target-statements.md](../reviews/L00.08b-target-statements.md) にある。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.08b（L00.08 の採用定義の配置と候補の削除） |
| B_WORK | `cd34bfe117f99aeb56f6654b3db43209b08d498c`（設計者の回答の記録の後の本線） |
| 閉じた範囲 | 採用定義を `Scope.Domain`・`Scope.Signature`・`Scope.Inference`・`Scope.TopCompat` に置き、模型がそれを直接使う形に直した。RV-L00 の中1・中2・軽7 を直した。`stateTyE_init_eff` を `Release/Lemmas/EffectSound.lean` へ、`BindingScope` を `Interval/BindingScope.lean` へ移した。案 (ii) の模型と比較のためだけの定義・import を消した。既定の全体のビルドが sorry なしで通った |
| 未完 | なし（本作業の範囲）。本番の定義の切り替えは L10 以降。設計書への反映は、本番へ接続した後の枝が行う（plan「作業 L00.08」の「現行設計書には、配置して既定ビルドを通した定義と、その時点の証明・接続状況だけを反映する」。本作業は依頼の範囲が `formal/` と改造のディレクトリに限られるので反映していない） |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/Domain.lean` | 先頭のコメントを採用定義の説明と名前の決まりに改めた。`Range.Sub`（模型から移した）・`Range.MemK`・`Range.FitsKinds` と補題を加えた |
| `formal/Benitoite/Scope/Signature.lean` | 新規。`Ix`・`IOShape`・`ShapeTargets`・`RangeAdmissible` |
| `formal/Benitoite/Scope/Inference.lean` | 新規。局所解析の評価関係・抽象値・局所状態 |
| `formal/Benitoite/Scope/TopCompat.lean` | 新規。`TopEmbedding`・`GEff`・`lift`（`CompatExamples` から移した） |
| `formal/Benitoite/Interval/BindingScope.lean` | 新規。`BindingScope` と補題（`RangeState` から定義を変えずに移した） |
| `formal/Benitoite/Interval/RangeState.lean` | `BindingScope` を除き、新しいモジュールを import した |
| `formal/Benitoite/Release/Lemmas/EffectSound.lean` | `stateTyE_init_eff` を加えた（模型から移した。言明と証明は同じ） |
| `formal/Benitoite/Scope/SignatureExamples.lean`・`TargetExamples.lean`・`InferenceExamples.lean`・`CompatExamples.lean`・`SwitchExamples.lean` | 採用定義を直接使う形に直し、比較のためだけの定義を消した（placement.md「削除」） |
| `formal/Benitoite/Scope/RepresentationExamplesII.lean` | 削除 |
| `formal/Benitoite.lean` | `RepresentationExamplesII` の import を除き、`Interval.BindingScope`・`Scope.Signature`・`Scope.Inference`・`Scope.TopCompat` の import を加えた |
| `l00.08/placement.md`・`l00.08/results-placement.md`、`reviews/L00.08b-target-statements.md` | 新規 |
| `l00.08/` の生のログ | `placement-lake-build-first.log`・`placement-lake-build.log`・`placement-work-check-dry-run.log`・`placement-work-check.log`・`placement-axioms.lean`・`placement-axioms.log`・`target-statements.lean`・`target-statements.log`・`names-check.lean`・`names-check.log` |

守った契約: `Release`・`Surface`・`Builtins.Assumptions` の既存の構成子と主定理を変えていない（`EffectSound.lean` への補題の追加だけ）。`BindingScope` の名前と定義を変えていない。未証明の本番の言明を theorem として置いていない（本番の言明の案は reviews/ の文書に置き、一時ファイルで型検査した）。新しいモジュールはすべて既定の import に入れた。`questions.md` は変えていない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中、複数回） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/<ファイル>.lean`。依存のモジュールは `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ> <モジュール名>...` で作った | 途中の失敗は下の「失敗と修正」。最後は全ファイル 0 | 各 1 秒前後 | 本書 |
| 既定の全体のビルド（一回目、変更の後の再ビルド） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。`Build completed successfully (422 jobs)`、`declaration uses 'sorry'` は 0 件。警告は既存の `Interval` のファイルだけ（`RangeState` の変更で再ビルドされた既存の警告） | 93.05 秒（ロックの待ち 0 秒） | [placement-lake-build-first.log](placement-lake-build-first.log) |
| 既定の全体のビルド（最後） | 同じ | 0。422 ジョブ、sorry 0 件 | 0.14 秒（ビルド済み） | [placement-lake-build.log](placement-lake-build.log) |
| work の dry-run | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base cd34bfe117f99aeb56f6654b3db43209b08d498c --dry-run` | 0。変更 14 件、`formal_build`（`formal/Benitoite.lean` による）だけを選んだ | 0.08 秒 | [placement-work-check-dry-run.log](placement-work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base cd34bfe117f99aeb56f6654b3db43209b08d498c` | 0。変更 16 件（dry-run の後に置いた記録の 2 件を加えた）、選択は同じ `formal_build`、`selected checks passed` | 0.22 秒（ビルド済みの生成物の上） | [placement-work-check.log](placement-work-check.log) |
| work の dry-run（文書と記録を置いた後の最後の状態） | 同じ指定（計時なし） | 0。変更 27 件、選択は同じ `formal_build` だけ。work の後に加えたのは文書と記録だけで、Lean の変更はない | 1 秒未満 | 本書 |
| 公理 | 一時ファイル [placement-axioms.lean](placement-axioms.lean) を `lake env lean -M 12288` で実行。`Benitoite.Scope` と `Benitoite.Interval.BindingScope` の下の全ての定理と `Benitoite.Release.stateTyE_init_eff` の公理を `Lean.collectAxioms` で集め、主な20件を `#print axioms` で表示した | 0。定理の定数 735 件（自動生成の補題を含む。内部の名前を除く）、標準の三公理（`propext`・`Classical.choice`・`Quot.sound`）以外に依存するもの 0 件 | 0.76 秒 | [placement-axioms.log](placement-axioms.log) |
| 本番の言明の案の型検査 | 一時ファイル [target-statements.lean](target-statements.lean) を `lake env lean -M 12288` で実行 | 0。`reachable_of_step` の公理は標準の三公理 | 0.31 秒 | [target-statements.log](target-statements.log) |
| 名前の解決 | 一時ファイル [names-check.lean](names-check.lean) を `lake env lean -M 12288` で実行 | 1（意図した曖昧さの誤り一つ。修飾した名前は解決した） | 1 秒未満 | [names-check.log](names-check.log) |

sorry・admit・axiom・native_decide は、新しいモジュールにも直した模型にもない。

## 最大常駐量

macOS の `/usr/bin/time -l` の `maximum resident set size`。並行するプロセスはない。

| 計測 | 原値（バイト） | MiB | GiB |
|---|---|---|---|
| 全体のビルド（一回目。`lake build` の一括実行全体の最大） | 1659305984 | 1582.4 | 1.55 |
| 全体のビルド（最後、ビルド済み） | 69582848 | 66.4 | 0.06 |
| work（`check.sh`、ビルド済み） | 69566464 | 66.3 | 0.06 |
| work の dry-run | 10240000 | 9.8 | 0.01 |
| 公理の一時ファイル（`lake env lean` 一つ） | 1436942336 | 1370.4 | 1.34 |
| 本番の言明の案の一時ファイル | 705216512 | 672.5 | 0.66 |

`lake build` の値は `lake` の一括実行全体（子の `lean` のプロセスを含む `time` の値）であり、プロセスごとの値ではない。`-M 12288` は上げていない。

## 失敗と修正

| 初回の失敗 | 原因 | 修正 |
|---|---|---|
| `Domain.lean`: `eq_top_of_kind_none` が未定義、`List.Forall₂` が未定義 | 補題を定義の前に置いた。`List.Forall₂` は Lean の core にない | 追加の節を旧 Top の小補題の後へ移し、`Range.FitsKinds` を再帰の定義にした |
| `Domain.lean`: `FitsKinds` の決定可能性の実例でコード生成の誤り | `induction` の戦術で作った実例は再帰子を使い、コードを生成できない | パターン照合の再帰で実例を書いた |
| `Signature.lean`: `single_memK` で未知の識別子 | `subst` が束縛を逆向きに置き換えた | `rw` に替えた |
| `SignatureExamples.lean`: `Ix.fixed Range.top = Ix.top` が残る | `Ix.top` を `simp` が展開しない | `Ix.top` に `@[simp]` を付けた |
| `TargetExamples.lean`: `ShapeTargets` が未知、許容の第一成分の `rfl`、`simp` が進まない | `Scope.Signature` を開いていない。許容の第一成分が長さの等号から `FitsKinds` に変わった。`EffAllows` の形が変わった | 名前空間を開き、`by decide` と新しい形の分解に直した |
| `InferenceExamples.lean`: 書き換えの道具の照合の失敗、`toyTable` の型 | 消した節の中の定義を二度消そうとした。`ScopeTable` が値の型を引数に持つ | 道具を直して再実行し、`ScopeTable CVal` にした |
| `SwitchExamples.lean`: 許容の第三成分の `trivial` | 模型の表 `tableBase.admitsR` が `FitsKind` の項を持っていた | 種類は `RangeAdmissible` が受け持つので、`tableBase.admitsR` を自明にした |
| 公理の一時ファイル: 名前空間 `Command` が未知、未知の定数、数の型 | `import Lean` がない。`FitsKinds` は `Range` の名前空間にある。可変の変数の型を推論できない | import と名前を直し、型の注釈を加えた |

どれも作業の途中の誤りであり、最後の状態ではすべてのファイルが通る。

## ずれと申し送り

計画からのずれ:

- 問 16 の「模型のモジュールは消す」を、初めは `Release` を import する部分を除くことと読んだ。取りまとめの判断（モジュールごと消す）を受けて、下の「追加の作業」で `TargetExamples` を消した。
- 採用定義の観測の条件と局所解析を、値の型・対応・Range の事実の型を引数に取る形へ一般化した。模型はこれを元の型で具体化しており、模型の定理の意味は変わっていない。
- 模型の `Entry` の `nranges` の欄を `rkinds` に替えた（軽7 の修正のため）。

停止条件: 該当しない。旧の四つの主定理と `Builtins.Assumptions` の前提・結論を変えておらず、公理を加えていない。本番の前提を変えていない（問 18 の例外はこの枝では使っていない）。

L10 への申し送り:

1. L10.1 は案 (i) で `Release.Atom.name` と `Release.Ty.opaque` に `Scope.Signature.Ix` の引数を加え、旧の綴りを `Ix.top` で書く。`Release.Atom`・`Release.Types` が `Scope.Signature` を import する（循環しない）。本番の原子による `TopCompat.TopEmbedding` の具体化は `Release.Effect` より後のモジュールに置く（`TopCompat` が `Release.Effect` を import するため）。
2. `Checked` と `Interval` のモジュールでは `open Benitoite.Scope.Domain` をせず、`Scope.Domain.Range` などと修飾して書く（軽8）。L40 で `Checked.Scope` が `Domain` を import するときも同じ。
3. Top の被覆は名前の種類に相対的に定める（`Range.MemK`。中2、問 13）。L10.3 の被覆の健全性は `MemK` の上で言明する。
4. L20 は `PrimSig` に範囲の変数ごとの種類を持たせ、具体化の許容に `Scope.Signature.RangeAdmissible` を使う（軽7）。形の検査は単一の対象の形で範囲の変数の種類 `[k]` を求める。
5. L30 は [reviews/L00.08b-target-statements.md](../reviews/L00.08b-target-statements.md) の「L30 の義務」の定義（`obs`・`effKind`・`allows`・`TA`）を固定した言明を本番に置いて証明する。
6. 01-12「区間解析の同じ成功値の直接射影」は `Interval/RangeState.lean` の補助記録と書いている。`BindingScope` は `Interval/BindingScope.lean` へ移ったが、01-12 は `BindingScope` のファイルを名指ししていないので、本作業では設計書を変えていない。設計書へ配置を反映する枝で、記述が要るかを確かめる。
7. `RepresentationExamplesI` は採用定義ではない模型として残した（L00.07 の申し送り 4）。L10.1 で本番の原子に置き換えた後、消すかを決める。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 21:05（JST。依頼文の読み込みの開始） |
| 終了 | 21:33（本書を書き終えた時点の目安） |
| 外側の所要 | 約 28 分 |
| 能動時間 | 約 25 分（読み込み・配置の設計・Lean の書き換え・文書） |
| 検査・ビルドの待ち | 約 3 分（一回目の全体のビルド 93 秒と途中の局所のビルド） |
| 見込みとの比較 | 見込み 1〜2時間（plan「作業 L00.08」の配置・削除と対応の修正）の下端より短い。上端の2倍を超えていない |

## 追加の作業（取りまとめの指示: `TargetExamples` のモジュールごとの削除）

取りまとめは、問 16 の推す案の文言どおり `TargetExamples` のモジュールごと消す意図と読んだ（設計者は推す案をそのまま選んだ）。条件は L00.08b の依頼文と同じである。

| 欄 | 内容 |
|---|---|
| 変更 | `formal/Benitoite/Scope/TargetExamples.lean` を消し、`formal/Benitoite.lean` の import を外した。`formal/Benitoite/Scope/SwitchExamples.lean` の import を `SignatureExamples` に替え、1〜4 節を採用定義と `SignatureExamples` だけで書き直すか消した（宣言ごとの扱いは [placement.md](placement.md)「削除」の「`TargetExamples` のモジュールの削除と `SwitchExamples` の 1〜4 節」）。[reviews/L00.08b-target-statements.md](../reviews/L00.08b-target-statements.md) に「L30 の義務: 本番の定義の上に置き直す例」の表を足した |
| 消したもの | `TargetExamples` の 64 宣言（ファイルごと）。`SwitchExamples` の `writeAt`・`goodTable_valKind_pathIn`・`writeAt_ty`・`writeAt_obs`・`forward_clause_ty`・`rvar_atom_uncovered`・`printCall`・`epsMixed`・`printCall_ty`・`writeCall_ty_mixed`・`mixed_ty`・`mixed_progress`・`mixed_reachable`・`mixed_not_empty` |
| 書き直したもの | `pathIn_typed_iff`・`check_then_write`・`check_then_write_example`・`minimal_then_write`・`valA_narrow`・`widen_typed`・`widen_then_write_same_target`・`captured_arg_typed`・`log_clause_obs`・`outerLog_excludes_data`・`saveOp_not_builtin`・`save_clause`・`save_example`・`print_obs_nil`。足したもの: `dataTreeA`・`outsideTarget`・`dataTree_wf`・`exampleTable_valKind_pathIn`・`writeTextIn_eff`・`writeTextIn_admissible`・`write_obs_of_shape`・`forward_clause`。IO の観測の言明は、事象の遷移ではなく観測の条件 `ShapeTargets` を満たす観測について述べる形に弱めた |
| L30 の義務に足した例 | `mkTable`・`core_mkTable`・`goodTable`・`target_goodTable`・`assumptions_goodTable`・`badTable`・`bad_core_and_arg_mem`・`bad_step_escapes`・`bad_no_target_agreement`・`target_not_from_core`・`step_target_sound`・`reachable_target_sound`・`good_write_obs_mem`・`redirect_step`・`redirect_allowed`・`name_matters`・`top_kind_relative`・模型の `progress`・`preservation`・`effect_soundness`・`widened_allows_any`・`stTy_widenTop`・`argObs_mem`・`effAllows_of_covered`、`SwitchExamples` の `writeAt_ty`・`writeAt_obs`・旧の `minimal_then_write`・節の例・`mixed_*`・`rvar_atom_uncovered`（名前・中身・本番で置き直すときの形） |
| 停止条件 | 該当しない。本番の定義と主定理は変えていない |

検査（追加の作業の後の最後の状態）:

| 検査 | コマンド | 終了 | 外側の時間 | 最大常駐量 | 記録 |
|---|---|---|---|---|---|
| 局所の単一ファイル | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/SwitchExamples.lean` | 1回目 1（`write_obs_of_shape` の `subst` の向き。`rw` に直した）、2回目 0 | 各 1 秒前後 | — | 本書 |
| 既定の全体のビルド | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。`Build completed successfully (421 jobs)`、`declaration uses 'sorry'` 0 件。警告は既存の `Interval` のファイルだけ | 1.39 秒（`SwitchExamples` と根の再ビルド。ロックの待ち 0 秒） | 1509048320 B（1439.1 MiB、1.41 GiB。一括実行全体） | [placement-lake-build-2.log](placement-lake-build-2.log) |
| work の dry-run | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base cd34bfe117f99aeb56f6654b3db43209b08d498c --dry-run` | 0。変更 29 件、`formal_build` だけ | 0.07 秒 | 10207232 B（9.7 MiB、0.01 GiB） | [placement-work-check-dry-run-2.log](placement-work-check-dry-run-2.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base cd34bfe117f99aeb56f6654b3db43209b08d498c` | 0。`formal_build`、`selected checks passed` | 0.22 秒（ビルド済み） | 69861376 B（66.6 MiB、0.07 GiB） | [placement-work-check-2.log](placement-work-check-2.log) |
| 公理 | [placement-axioms.lean](placement-axioms.lean)（`TargetExamples` の表示を除き、書き直した `SwitchExamples` の5件を足した）を `lake env lean -M 12288` で実行 | 0。定理の定数 660 件、標準の三公理以外への依存 0 件 | 0.74 秒 | 1434763264 B（1368.3 MiB、1.34 GiB） | [placement-axioms.log](placement-axioms.log)（上書き） |

work の後に加えたのは本書・placement.md・reviews/ の文書だけで、Lean の変更はない。

時間: 追加の作業は 21:33〜21:40 ごろ（`date` の値。外側 約7分、能動 約6分）。L00.08b 全体の外側の所要は約35分であり、見込みの上端の2倍を超えていない。
