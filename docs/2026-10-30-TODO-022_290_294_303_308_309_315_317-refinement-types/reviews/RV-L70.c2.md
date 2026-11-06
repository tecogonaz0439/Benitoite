# RV-L70.c2: L70 群 C 再開3（L70.19、利用者のプログラムへの適用の系）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.c2` の未コミットの作業木である。基準は `e70794188e24de95b5bb424f9d75090f77d1c703` で、HEAD と一致する。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-c2/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。対象は L70.19 の部分だけであり、群 C の前半（RV-L70.c が扱った範囲）は見直していない。

読んだもの:

- 本体の作業木にある依頼文 `work/m014/RV-L70.c2-prompt.md`、担当への依頼文 `work/m014/L70.c-r3-prompt.md`、担当の報告 `work/m014/L70.c-r3-report.md`。記録の形式は RV-L70.d の初回の部分に倣った。
- [群 C の結果](../l70/c/results.md)の全節、特に「群 K を待つ部分」「取りまとめに判断を求める点」「再開3（L70.19）」。
- [detail.md](../l70/detail.md) の L70.19 の行、群 C の完了条件、第2節の仮定150・`Val.Source`・`RoundingMode`・Map/Set・`%List.getFront` の行、L70.28・L70.34 の行、J70-8。[collection.md](../l70/collection.md) の F03 (1)〜(3)、[tables.md](../l70/tables.md) の L70.19 を名指す行。
- plan.md の 2026-11-06 の群 C の判断（`DataTable P` を系の前提に置き R50 で照合する、Map・Set の鍵の順序を R50 で照合する）。
- `R/MainStatements.lean` の十言明、`R/MainTheorems.lean`、`R/MainEffects.lean` の `effect_soundness`・`effect_soundness_noLamNames`、`R/StandardModelCompletion.lean` の `DataTable`・`AssumedTable`・`NameLists`・`complete`・`Completion`・`Includes`、`R/StandardModelComposedRows.lean` の `included_typed`・`included_wellFormed`・`included_effectsOk`・`completion_core`・`additions_refl`、`R/StandardModelConditionInputs.lean` の `positiveExternals`・`positive_wf`。
- 新規の `R/StandardModelApplication.lean`・`R/StandardModelApplicationExamples.lean`、根の import、01-12・07-04 の差分、`l70/c/` の `verify.py`・`run_check.py`・`axioms.lean`・`audit-modules.json`・`required-names.json`・`audit-summary.json`・`resume3-*.json`。

したことは、十欄と主言明の対応の Lean による確認、新規二モジュールの単独 Lean 検査、主要な宣言の公理依存の確認、ソースと保存されたハッシュの照合、台本と記録の読み合わせである。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、確認用入力は `<tmp>` に置いた。`-o` は使っていない。

`lake build`・cargo・`scripts/check.sh`・`verify.py`・`run_check.py`・git の書き込み操作は行っていない。処理系との照合（R50）と表層の性質1（群 D・E）は検査していない。変更したリポジトリのファイルは本書だけである。

## 結論

**条件付き可。重0件、中3件、軽1件、情報3件である。**

`included_guarantees` は十言明を弱めずに利用者のプログラムへ当てており、新しい公理・`sorry`・独立の信頼条件・書ける形の制限はない。前提は同じ完成した表で同時に満たせ、外部宣言を含む P も覆う。中の3件は記録と照合の台本、および後段への受け口の記録に関するもので、系の言明と証明は変えずに処置できる。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | `l70/c/verify.py`・`axioms.lean`・`audit-modules.json`・`required-names.json`・`audit-summary.json`、results.md の「検査」と「RV-L70.c の処置」の節 | 群 C の再開1・2の照合の台本と記録を、再開3用に上書きした。前の節は今も「[audit-summary.json] 必須の名前82・監査の対象16モジュール」「対象1682」と書くが、リンク先は必須27名・2モジュール・全環境92,356宣言の内容になった。旧の台本が確かめていた `StandardModelComposedRows` の maxHeartbeats が一か所だけであることなどの条件も、新しい台本からは消えた。前の節の記述と引用先が一致しない | 前の節の引用を、旧の版がある基準のコミット（`e7079418` の版）を指す形に直すか、再開3の台本と記録を `resume3-` の名前で別に置き、旧の台本を残す。どちらにするかを results.md の再開3に一行書く | 読めば確定 |
| 中2 | 中 | `l70/c/verify.py` の変更範囲と保護範囲の照合 | 保護範囲に改造ディレクトリ全体（`HERE.parents[1]`）を含め、未追跡は ALLOWED か `l70/c/` の下に限る。旧の台本は独立レビューの記録を照合の外に置いていたが、新しい台本はそうしていない。本書（reviews/RV-L70.c2.md）を置いた時点で、未追跡の検査と保護範囲の件数・指紋の検査がともに失敗し、取りまとめが照合を再実行できない | 旧の台本と同じく、群のレビューの記録（reviews/RV-L70.c2.md）を未追跡の検査と保護範囲から除く。処置の後の照合は一回だけ実行し直す | 台本を読めば確定（実行していない） |
| 中3 | 中 | results.md の「再開3（L70.19）」の義務の判定、detail.md の L70.28・L70.34 の行 | `Program.Additions (program externals) P (complete L T A)` と `DataTable P` は系の明示した前提であり、L70.19 の完了条件を欠くものではない（L70.19 の行は前提を `Additions` で供給すると書き、detail.md 第2節は供給元を性質1の L70.28 とする）。ただし、後段が満たすべき形が記録にない。追加宣言の検査は完成した表 `complete L T A`（仮定側の表 A を含む）の上で要り、L70.28 の表層の型付けが読む表をこれに合わせる必要がある。L70.34 の行は `included_guarantees` を名指さない。表層の主定理が今回の系を経由するかが読めない | 再開3の義務の判定に、L70.28 への申し送り（同じ `complete L T A` での `Additions` の供給）と、L70.34 への申し送り（`included_guarantees` に `Additions`・`DataTable P` を渡して十欄を受け、`HasMain` から開始の条件を作る）を行で足す。`DataTable P` の供給は R50 の照合のままとする | 読めば確定 |
| 軽1 | 軽 | `l70/c/run_check.py` の audit の command の組み立て、results.md の作業末の検査の表 | `command` の最後の要素を一度 `ROOT.parent` からの相対パスで作り、直後に上書きしている（最初の値は使われない）。results.md の表の「1,385ジョブ」は群 K の結合による増加を含むが、前の節の1,345ジョブとの差の理由がない | 最初の組み立てを除く。ジョブ数の差が群 K・D の取り込みによることを一言添える | 読めば確定 |
| 情報1 | 情報 | `ApplicationExamples.noAssumptions`・`user_guarantees` | 前提の同時の証人は、仮定側の行を一つも持たない A で作られている。系は任意の A で述べてあるので空疎ではないが、仮定側の名前（`Json.parse` など）を呼ぶ利用者のプログラムについては、署名を持つ A が `Completion` を満たせることを示す証人がない。仮定側を 07-04 の仮定として名前で記す既決の方針（J60-3）の範囲であり、担当も「仮定側150名の応答の実装とは扱わない」と記している | 必要なら後段で、仮定側の行を一つだけ持つ A（純粋な δ の行など）の `Completion` の証人を置く。判断は取りまとめに委ねる | 読めば確定 |
| 情報2 | 情報 | `Includes.constructor_entry`・`complete_delta`、tables.md の L60-MapSet の行 | tables.md の行は「`Program.Extends` の cons の欄で並びが変わらないことを示す」と書くが、実装は lookup の保存と、δ が同じ `T.keyNames` を読むことに分けた。並びは `DataTable P` の一覧の順で決まり、`Extends.cons` からは導けないので、この分け方は妥当である。系はどの並びでも成り立ち、処理系の順序との一致は plan.md の判断 (2) のとおり R50 で照合する。計画との差として results.md に記録済み | 処置は不要。R50 の照合で、標準の data 型の構成子の並びが利用者の一覧でも保たれることを対象に含める | 読めば確定 |
| 情報3 | 情報 | `ProgramGuarantees`・`program_guarantees` | 十欄は主言明の前提（整形式・型付け・効果の検査・Core・対象条件）を外した結論そのものである。検査1で、各欄から九つの `*Statement` を前提なしに組めることと、`program_guarantees` が逆向きを与えることを確かめた。`effect_soundness_noLamNames` の欄は群 K の定理と同じ前提・結論である | — | Lean で確認 |

## 観点ごとの根拠

### 1. `included_guarantees` と `ProgramGuarantees` の十欄

`ProgramGuarantees P B σ` の欄は、`MainStatements` の `ProgressStatement`・`PreservationStatement`・`StepsPreservationStatement`・`StepSoundStatement`・`InitialTypingStatement`・`EffectSoundnessStatement`・`StepTargetStatement`・`ReachableTargetStatement`・`ReachableTargetEventStatement` から、プログラムと表についての前提（`P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B`・`B.CoreAssumptions P`・`B.TargetAgreement P`）だけを除いた形である。第十欄は `MainEffects.effect_soundness_noLamNames` の前提と結論をそのまま写す。残った前提は元の言明と同じである。状態の型付け、開始の閉包の型付けと `StartCondition`、`StepSelection`、`Steps`、一段の対象健全性の `σ.Valid` が各欄に残り、量化子の順序も変わっていない。`step_sound` の欄は元の言明どおり oracle 等を全称し、`EffectsOk` を要しない。

`program_guarantees` は各欄に群 B・K の定理を前提つきで渡すだけであり、補助の仮定を足していない。`included_premises` は、既存の `included_wellFormed`・`included_typed`・`included_effectsOk` と `completion_core` を同じ `complete L T A` で組み立てる。`included_typed` に渡す `ComposedAgree` は `complete_agree` から、`P.ExternalWF` は新しい `Includes.externalWF` から得る。後者は `Extends.externals` の等号の下での既存の `ExternalWF.ofExtends` の適用である。

前段の公開署名は変わっていない。差分は新規二モジュールと根の import 2行、01-12・07-04 の追記だけであり、`MainStatements`・`Typing`・Surface・旧 Release に変更はない。

### 2. 前提が空疎でないか

`user_guarantees` は、任意の `externals` と `(program externals).ExternalWF` の下で、同じ `userProgram externals`・`userData externals`・`noAssumptions` について `included_guarantees` の前提をすべて供給する。`user_includes` は追加した `User.main` 以外の lookup を保ち、内部名と衝突18名の欄を満たす。`user_additions` は追加した定義の型付けと有効範囲を、任意の B で示す。`noAssumptions_completion` の各欄は、A の署名・応答・資源がないことから閉じる。合成側の16条件・解放・表全体の12条件は `completion_core` が別に供給し、この証人に移していない。

`positiveExternals` は外部関数を一つ持つ外部宣言表であり、`Includes` の `externals` の欄により `userProgram positiveExternals` の外部表はその表と等しい（検査1で `rfl` で確認）。`Includes` は P の外部表を `program externals` の外部表と等しくするが、`externals` は全称されているので、外部宣言を空に制限していない。外部宣言のない P への制限はない。

同じ表で `User.main()` が型付き、一段で `return ()` へ進む適用例があり、追加した宣言を読む証人になっている。仮定側の行を持つ A の証人がないことは情報1に記した。

### 3. `Additions` を明示の前提にしたこと

detail.md の L70.19 の行は、主定理の前提を `Includes`・`Completion`・性質1の `Additions` で供給すると書き、第2節の行は `Additions` の供給元を性質1（L70.28）とする。collection.md の F03 (2) も、表層の型付けの結論から追加の宣言の欄を取り出すのは L70.28 とする。したがって、表層の性質1から `Additions` を得る接続をこの系に含めないことは、L70.19 の完了条件を欠くものではない。01-12 の追記も「追加宣言の検査は脱糖の型保存から受ける義務であり、この系が表層の検査器の受理から直接導くものではない」と範囲を正しく述べている。

一方で、`Additions` は完成した表 `complete L T A` を B に固定している。L70.28 の性質1は、表層で受理した利用者の定義の核の型付けをこの同じ表で与える必要がある。L70.34 は表層の主定理を `included_guarantees` に接続する自然な読者だが、行に名前がない。この受け口を記録に書くことを中3とした。

### 4. 三モデルと記録

三モデルの適用例は、`ExternalModels.model P`・`targets P`・`http P` に、それぞれの `*_core` と `*_scope.toTargetAgreement` を渡す。P の三検査と、`HasFile P`・`HasHttp P` は前提に残している。これらの表を完成した表と同一視しておらず、tables.md の L60-受口5 の行と一致する。

`Val.Source` は `.externalRef` を `True` とする Lean の定義のままで、Rust の拒否は results.md の対応表に一方向として記した。detail.md の行（Lean を狭めない）と一致する。`RoundingMode` は Lean のデータ名と5構成子を prelude の5構成子と表で対応させ、処理系の型名との照合を R50 に渡した。`%List.getFront` は `Includes.internal` と標準の defs に同名がないことから、追加定義との非衝突を示した。Map・Set は情報2のとおりである。Task・TaskGroup の7名は `outsideNames` の全名について完成した表で署名がないことを示し、それらを呼ぶプログラムを範囲の外と記した。J70-8 のとおりで、新たな範囲の削減ではない。

### 5. 守ること

01-12 の「確かめる性質」と 07-04 の新しいモジュールの段落・対応表の行は、追加した言明だけを書いており、経緯の文・工程の ID・改造の段名はない。前提は実物どおり L・`DataTable P`・`Includes`・`Completion`・`ExternalWF`・`Additions` に分けて書いている。新規二モジュールに `sorry`・`axiom`・`#eval`・`maxHeartbeats` はなく、private の `user_fresh`・`user_typed`・`user_scoped` はいずれも同じモジュールに読者がある。公開の補題 `complete_outside`・`Includes.getFront_fresh`・`Includes.constructor_entry`・`complete_delta` は既定ビルドの適用例が読む。

## 実行した検査

Lean はすべて `<repo>/formal/` から実行し、同時に一つだけとした。既定のビルド出力は上書きしていない。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 1 | `<tmp>/check.lean`。`ProgramGuarantees` の各欄から九つの `*Statement` を組む例、`program_guarantees` による逆向き、`userProgram positiveExternals` の外部表の等号、`included_guarantees`・`user_guarantees`・`noAssumptions_completion` の `#print axioms` | 終了0。未使用の変数の警告だけ（各欄が主言明の前提を要しないことの裏付け）。三つの宣言の公理は propext・Classical.choice・Quot.sound だけ |
| 2 | 新規二モジュールを作業木のまま `lake env lean -M 12288 <file>` で順に検査 | 両方終了0、出力・警告なし。約1秒・約2秒 |
| 3 | 読み取り専用の SHA-256 の照合 | 新規二モジュールの SHA-256 が `audit-summary.json`・`resume3-build.json`・`resume3-audit.json` の値と一致 |

検査1の入力は1,905バイト、SHA-256 `7d026f2de4b249e0a08608a83d0199fd3181eb2b99171dc21718363bec570cff` である。担当が記した既定ビルド（1,385ジョブ）、全環境の公理監査（92,356宣言）、照合の成功は保存された報告として読み、本レビューで実行した検査としては数えていない。`verify.py` は読んで判定しただけであり、中2の失敗は実行で確かめていない。

## 取りまとめの追記

2026-11-06。L70.19 は Codex が実装し、独立レビューは Claude（Opus 5.5）が行った。中1〜中3・軽1は再開4で処置した。照合の記録は元の内容へ戻し、再開3用の記録を別の名前に分けた。レビューの記録は照合の外に置いた。`Additions` の受け口（L70.28 が供給し、L70.34 が `included_guarantees` で受ける）も記した。処置は記録と照合の台本に限られ、Lean の言明は変わっていないので、確認は取りまとめが差分を読んで行った。情報1は、既決の方針の範囲として plan.md に記した。処置の後に取りまとめが work の検査を行い、終了0（889.78秒）であった。
