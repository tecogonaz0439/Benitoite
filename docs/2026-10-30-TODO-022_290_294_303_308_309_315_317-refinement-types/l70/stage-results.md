# L70 段末の照合と受け入れ資料

2026-11-07。実装担当（Claude、Opus 5.5）が L70.46・L70.47 を行った段末の資料である。指定ブランチは `m014/l70.h`、B_WORK は `084c8f6a848a035fc9d2240b638ff9411f629536`（群 G を取り込んだ後の san_benito）、段の開始版 B_STAGE は `657b3ae713040e78826d2f19cd7b8ac9f415a6d6`（L70 の最初の実装の群 U の基準）である。B_STAGE より前に L70 の実装の取り込みはなく、B_STAGE から B_WORK までに L70 の作業の枝の取り込みが21件ある（[h/results.md](h/results.md)「基準」）。git の操作は行っていない。**段末レビュー（L70.48 はその処置）、取りまとめの段末の work・正式 RSS、F-REG（`scripts/check-formal.sh` の全比較）と設計者の受け入れは未実施**である。群 H の作業記録は [h/results.md](h/results.md) にある。

## 担当分と全体の区別

L70 は篩付きの形式化への切替の段である。新しい核の主定理（進行・保存・実行関数の健全性・開始の型付け・エフェクトの健全性と noLamNames・一段と到達先の対象健全性）、篩付きの表層と性質1、検査器と受理と網羅性と消去の健全性、利用者のプログラムへの系、交換の新しい版と7入口の切替、旧 Surface・旧主定理・Core の削除を既定ビルドに置いた。本段の成功を Rust/Lean の全比較（F-REG・F-CONN）の成功や処理系の実装の完了と呼ばない。F-REG は設計者の指示（plan.md 2026-11-07）により段末のレビューと処置の後の最後の関係状態で一度だけ取りまとめが流す。tables.md の申し送り78行と義務59行を一行ずつ判定した（下の「義務と申し送りの最終の判定」）。残る段が「なし」の行（L70 の分の完了で義務全体が閉じる行）は申し送り33・義務20である。義務全体の閉鎖は段末レビューと設計者の受け入れの後に判定し、ここでは閉鎖と呼ばない。他の行は右列の段に残る。

## 段で足した定義・言明・仮定

段の公理監査の入力（[axioms.lean](axioms.lean)）で、段の開始版と最終版の既定 import の閉包と7入口の根ごとの環境の全宣言（private・生成宣言・構造体の欄・マクロのスコープを持つ名前を含む）を書き出し、型の印字の64ビットのハッシュで比べた（[h/stage.py](h/stage.py)、記録は [h/declarations.json](h/declarations.json)）。開始版は `git archive` で一時領域に取り出して既定ビルドした（1330 jobs、終了0）。private は所属モジュールと実名の接頭辞を除いた名前で対応させ、7入口の根に同じ名前（`main` など）があるものはモジュールを付けて別に数えた。比較は宣言の型の印字だけであり、定義の本体の変更（例えば `handled` の本体）は「同じ」に数える。名前の一覧は一時領域に置き、大きさと SHA-256 を記録に残した。

| 状態 | 宣言 | 定理 | 定義（def・opaque） | 帰納型 | 構成子 | 再帰原理 | private | 生成 | マクロのスコープ | 名前付きの公開 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 足した | 48,954 | 29,720 | 16,924 | 370 | 1,558 | 382 | 25,898 | 12,535 | 27 | 10,501 |
| 削除した | 12,518 | 6,925 | 4,652 | 153 | 630 | 158 | 3,626 | 4,245 | 16 | 4,631 |
| 型が変わった | 2,615 | 1,039 | 1,425 | 0 | 63 | 88 | 944 | 1,131 | 4 | 536 |
| 同じ | 71,263 | 39,343 | 26,612 | 785 | 3,790 | 733 | 18,734 | 27,958 | 8 | 24,563 |

開始版は 86,396 宣言（既定 import の閉包 85,411 と7入口 985）、最終版は 122,832 宣言（既定 import の閉包 121,830 と7入口）である。モジュール（ファイルの import の閉包）は開始版 1,079・最終版 1,304 で、段で足したモジュールは 370（うち宣言を持たないもの2: `SafeCheckPreservationExamples`・`Surface.NoRangeScopedExamples`）、削除したモジュールは閉包の中で 145 である。L70.44 の削除の計画の146（[g/deletion-plan.json](g/deletion-plan.json)。旧 Surface 94・旧 Release 36・Core 16）のうち `Benitoite.Release.LegacyCheck` は開始版の既定 import の閉包の外のファイルだったので、閉包の差は145になる。削除した宣言 12,518 のうち 11,639 は削除したモジュールにあり、残りは残したモジュールで除いた宣言（旧三モデルの `assumptions` とその読者33、`R.CurrentSignatureRows` の4など）と、篩付きの核で置き換えた宣言である。所属のモジュールが変わった宣言は502（改名したファイル3を含む）。

| 系統 | 足した | 削除した | 型が変わった | 同じ |
|---|---:|---:|---:|---:|
| Release.Refinement | 6,678 | 710 | 1,956 | 41,292 |
| Release.Refinement.Surface | 40,409 | 0 | 7 | 150 |
| Exchange | 1,178 | 105 | 477 | 2,684 |
| Interval | 666 | 0 | 11 | 11,009 |
| 7入口 | 23 | 6 | 164 | 815 |
| Release | 0 | 1,531 | 0 | 9,250 |
| Surface | 0 | 8,655 | 0 | 1,565 |
| Core | 0 | 1,511 | 0 | 0 |
| Scope | 0 | 0 | 0 | 3,240 |
| Checked | 0 | 0 | 0 | 836 |
| Shared | 0 | 0 | 0 | 315 |
| Library | 0 | 0 | 0 | 107 |

旧 `Release` は削除と同じだけで型の変わった宣言はなく、残した旧 `Surface` は区間の入力の構文3モジュールの1,565宣言である。型の変わった宣言のうち、核の判断の構成子の変化は次である（型の印字の比較）。

- `Step` の14構成子（`E_Err`・`E_Exit`・`E_Force`・`E_ForceDone`・`E_Fun`・`E_IO`・`E_IOErr`・`E_OpPrim`・`E_PathBasesApply`・`E_Prim`・`E_RefGet`・`E_RefNew`・`E_RefSet`・`E_RefUpdate`）。範囲引数の列（`RangeIx`）と、発行の適用をハンドラの探索から外す変更（plan.md 2026-11-06、RV-L70.b の重1）による。
- `HasTypeCQ.C_Match`（照合の型の宣言 `Ty.Declared`）、`HasTypeVQ.V_Fun`・`V_Prim`、`Val.fnRef`・`Val.prim`、`Def.mk`（範囲パラメータの核の拡張）、`AtCallAdmissible.mk` と構成子 `AtCallAdmissible.text` の追加（J70-2）、`Entails` の構成子 `fieldAtom`・`measured` の追加（篩の論理の含意の規則）。
- 帰納型 `Step`・`StateTyE`・`HasTypeCQ`・`HasTypeVQ`・`Comp`・`Val`・`Ty.LeQ` と、`Program.WellTyped`・`WellFormed`・`EffectsOk`、`Builtins.CoreAssumptions`・`TargetAgreement`・`ValueAssumptions`・`ExternalAssumptions` とその構成子 `mk` の型は変わっていない（欄の数と型の式が同じ。参照先の定義は段で変わった）。

仮定は次のとおりである。

- Lean の公理: 追加0。全宣言の公理依存は `propext`・`Quot.sound`・`Classical.choice` の部分集合だけで、`sorryAx` は0（下の「段末の公理監査」）。
- 信頼条件: `Builtins.CoreAssumptions`・`TargetAgreement`・`ExternalAssumptions`・`ValueAssumptions` の構成子の型は開始版と同じである。完成した表の信頼条件は `StandardModel.completion_core` が合成済みの行と仮定側の表の契約（`StandardModel.Completion`）から構成し、主定理への新しい仮定にしていない。仮定側の名前（δ 80・IO 応答47・通常資源の状態16。形式化の外の7名は署名を持たない）は `Completion` の区分ごとの欄で量化する。
- 主な言明: 群 A が置いた `MainStatements` から群 H の開始版までの変更は、`StepTargetStatement` に `P.WellFormed`・`P.WellTyped B` を足した一つだけである（`git diff`。群 B、plan.md 2026-11-06 の L70 群 B の報告の (2)。設計者の見直しの対象）。
- 系の前提: `StandardModel.included_guarantees` は `DataTable P`・`Includes`・`Completion`・`Additions`・外部宣言の表の整形式を前提に取る（群 C。設計者の見直しの対象）。

## 主定理の一覧と型のハッシュ

07-04「証明する性質」、01-12「確かめる性質」、`formal/README.md` の主定理の一覧の名前と主な言明の全77名の型の印字（`pp.fullNames`・`pp.proofs`）の SHA-256 である（[h/audit-summary.json](h/audit-summary.json) の `required`。型の全文は一時領域）。README の一覧の41名は全てこの77名に含まれ、07-04「証明する性質」の定理の名前は全て最終版の環境にある（[verify.py](verify.py) の4）。

| 名前（接頭辞 `Benitoite.` を省く） | 種類 | 型の SHA-256 | 公理 |
|---|---|---|---|
| `Release.Refinement.progress` | 定理 | `7b77fb8352768e2d74864568804e8087880600f1f45f84946c9eca3b39fa1b7f` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.preservation` | 定理 | `78f72dfe81a3433ace4eb3f618a3cb3a2fdb944770e0cbc3d497bdf2b6cb666c` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.steps_preservation` | 定理 | `53299e63080de4f325493d27c5c4ebb03788dc76db7ac3fcf655d8da5d4b13ca` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.step_sound` | 定理 | `1bbeeb3ff874e099c56347e1dc455caaa85824d486c3aff2a12587d3538029f7` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.initial_typing` | 定理 | `9283a762c996f6a9144af614a5943284e3375304c1fa8bb0bb156b5a5c60b5e1` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.effect_soundness` | 定理 | `44e101798453e58e0d52bf054a880c41c015032dd6f9c76103e119af88c18057` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.effect_soundness_noLamNames` | 定理 | `811e031f8fe51dc2990ec2d3969ead6713c46b7117b5585822b8817094fd85b2` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.step_target_sound` | 定理 | `bf50383a2e8d13b92f8c042df828096821bab00a49cd8bd1899b09ef906e8f08` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.reachable_target_sound` | 定理 | `77633486f08cec2330b58b2bcc4a6f02b050e45f83c6a4fb49239232552719ea` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.reachable_target_sound_event` | 定理 | `b40179f4251e2ae0daa206f68f46f2c77a857ee2a8dce53208ade4ee61c617f4` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.ProgressStatement` | 定義 | `e529d7e1d2fcbf8c10576174a469bfbe696c2c6c937c4a1ca5f509352acd9541` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.PreservationStatement` | 定義 | `e529d7e1d2fcbf8c10576174a469bfbe696c2c6c937c4a1ca5f509352acd9541` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StepsPreservationStatement` | 定義 | `e529d7e1d2fcbf8c10576174a469bfbe696c2c6c937c4a1ca5f509352acd9541` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StepSoundStatement` | 定義 | `dec840e5fa191f1aa86606089ffdebe9ba213fee0f70268af998c1bcb47242c8` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.InitialTypingStatement` | 定義 | `e529d7e1d2fcbf8c10576174a469bfbe696c2c6c937c4a1ca5f509352acd9541` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.EffectSoundnessStatement` | 定義 | `e529d7e1d2fcbf8c10576174a469bfbe696c2c6c937c4a1ca5f509352acd9541` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StepTargetStatement` | 定義 | `e529d7e1d2fcbf8c10576174a469bfbe696c2c6c937c4a1ca5f509352acd9541` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.ReachableTargetStatement` | 定義 | `e529d7e1d2fcbf8c10576174a469bfbe696c2c6c937c4a1ca5f509352acd9541` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.ReachableTargetEventStatement` | 定義 | `e529d7e1d2fcbf8c10576174a469bfbe696c2c6c937c4a1ca5f509352acd9541` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StartCondition.of_typed_noLamNames` | 定理 | `747d5ed32b29a396d6807baad84e5bff840fc7d4dd9244d92b3bd64abf3d1019` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.no_event` | 定理 | `748b7d9881c300268ea4a1717a85e2653d94478f0f46ea44f54bc4174e6946d7` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.no_unhandledOp` | 定理 | `7f5fee8e15efa1181367db5026211e62c7e86677009238fe3ca6129326f92e3b` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.step_preserved` | 定理 | `e872ef4aa0a968b6c83ba7437c05691fba7fa564973cf45bd32a2c07830cd141` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.steps_preserved` | 定理 | `d6be90ffd389ddbaf91770996f39e9dcda41fdf9b86ff013aee96cb99e2fc394` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.desugar_typed` | 定理 | `5e0995cc2f9f357ec47d11b6193f24ace5eda7bf26a7a6ed6e936ea33357eca4` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.HasTypeQ.desugar` | 定理 | `cf4c4c655c6474f64a23f4bbcb7368e96b2cf2c8761fb7340487ed422fe0e1ba` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.HasBlockQ.desugar` | 定理 | `578141b43e39ed5590b40e6d77055199277a175ab7eaef83e9a2d0cb94c20b39` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.surface_effect_soundness` | 定理 | `fc3e348163fd006d81555d15ceafa0e47b8763e65d85e20c6d7c4de95d6fb1da` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.surface_target_sound` | 定理 | `37893a0bc5452e8f71aa2da85a19e04917f0b5a0d53fd43c2354c84a45088106` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.surface_guarantees` | 定理 | `0e2e663d107c674d626dbd347fa35d06b2bd100b885968460a50631fa700d34f` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.linked_main` | 定理 | `cc4746eb81a2c345c97d04e7ee3e37805dd02bb7097ae434753f412cca1fe6fb` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.linkProgram` | 定義 | `c9b4fc5442036e3047ef858c0b8971cfa871de7e3288b357f54c0167cbeec5c9` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.link_additions` | 定理 | `ca35440c8ae755bf413a050652db032f88e4bebc091d049670b374e648f54269` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.checkProgramAccepted_main` | 定理 | `9dffc161b765c129c7f73718724882d0dfb6ac58d7ac13532734c4e5c49a1a30` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.checkProgramAccepted_guarantees` | 定理 | `d1fb4baef15f81db677d08fcd9785229595c13fe62c25edd2bc8dafebbf22dad` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.CheckedMainExamples.main_guarantees` | 定理 | `e38a4985187cd223fec079c3ef70849b05867af8b20fc9d25a1c73be3bcb506a` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.MainExamples.main_guarantees` | 定理 | `0c504a9c3b5021b2b6fbd81f44f270603906a05ff38a870a2daf343e59af9fc9` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.Check.checkExprAt_sound` | 定理 | `98099c63c2eaba3039606c2103b42d2a1ea1b8b3cd65bb2b847dd57673b8cfd1` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.Check.checkBlockAt_sound` | 定理 | `daf5c0c8c547623fea0c63c3673711ee0745ac7a3d3785b183926f3664e9940f` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.CheckTables.checkProgram_sound` | 定理 | `4d63f34651bd865a7f8516e07e614e3aedbeb256061d1ace3be5c853f2d4e1f7` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.CheckAccept.checkProgramAccepted_sound` | 定理 | `35c771fff09d8dc63c94417b393aa4fac251dd5fb3750e514ab1b92fb6b5d350` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.CheckAccept.acceptProgram_sound` | 定理 | `7cdd6d1403ca17debb922838a4ac18f61c7ee4c340170b6f80edc007f5285dfc` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Surface.ScopeSound.productionRules_sound` | 定理 | `0ffb1d34c4e082b1425ccedab10befe4bbc16878a144e3be20c44a496c792b6d` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StandardModel.included_guarantees` | 定理 | `7b69a7c8d048546c5b60bab626c447c8e8989a9f351c3461be0dee8e26e3291a` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StandardModel.completion_core` | 定理 | `a81e354e024f9e86f088e19a98747e6bc9db839abfc58fe7e1e3dafdf00d289c` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StandardModel.completion_core_of` | 定理 | `60a1209412064a063fe31aedc5c5523a821f55af0857152f880291aa5b5ad24a` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StandardModel.included_typed` | 定理 | `c5dd18baf7611436db404ebb170c9c7ca00297b5ca5847cbea527ba509abf4ac` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Coverage.coverage_sound` | 定理 | `134aa5c6c0e930d6b4fdd47590bf7fceaec8e741fc04325f674b0e413623619e` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Coverage.coverage_extension_sound` | 定理 | `3e549ca16a1a7d2c8d6da629a2680d942bdbde717401f1b05354ebe33a18495b` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.checkMatchWithView_exhaustive_sound` | 定理 | `d6fe6c5f3337a83d8bb19c1d1e61c991b05186049854270ca5fce6f4e58d5490` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.irrefutableWithView_sound` | 定理 | `785c008f7de1e9023b7249fd9c28561f913acd69fa9d855cb3220f428cb0dd24` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.checkMatchWithView_unreachable_sound` | 定理 | `14f52fccc832b1a86a78031df010b547045023667fbe9891c05947297539a3a5` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.usefulWithView_extension_exhaustive` | 定理 | `08c601a05ed718e91c432db729ee136fe79e5e65e0d47b6882cfbe31877ba999` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.builderApply_value_typed` | 定理 | `158a6c5bc88b981f270ba208b6f14727ef3e237f7a4d03e2f1a71c3a7b766e90` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.builder_new` | 定理 | `fd4021f07cea499e7b0b640e7a8cb2133504b8f5c6e096ca3bf52c40d9289a64` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.builder_operation` | 定理 | `448612de865351653b22b6f18c84f1cba29e5711af643c5bdef10f794eeb7a2a` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.builder_error` | 定理 | `76c12a2541ca375b5fbda7fe0ea47527f3944f4f1590ecd86a8b953efd3585fe` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.builder_progress` | 定理 | `35a7e211b4e5e96ae6846e8ff213a1ccc282a1527c57d21e4f82b013e1301de3` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.builder_live` | 定理 | `cdaaf1222d3a196108819786d99ee2e915d7a55986808d04a690ad27f1719171` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StateTyE.local_invariant` | 定理 | `8e6b01e7f84490a79619a46c7f034e7c4522ed1a4cdacec785f0458ef0c97776` | Classical.choice + Quot.sound + propext |
| `Exchange.CheckInput.prepare_sound` | 定理 | `2b25270e4065ffef8c300a14bd0bbdad58f2eebca58e6dcd287b55b66ccd6023` | Classical.choice + Quot.sound + propext |
| `Exchange.CheckInput.prepare_agrees` | 定理 | `0ad1ddcd8c9ca2da97b94b9636fd033e3edd11ce386ac6cbae57499b76b05d04` | Classical.choice + Quot.sound + propext |
| `Exchange.CheckInput.prepare_entry` | 定理 | `8d528f96fa22e52fbc30ab7d03b9fc86bf31a773edb1f20f38b55041b61893e2` | Classical.choice + Quot.sound + propext |
| `Exchange.BuiltinAgreement.standardCheck_sound` | 定理 | `d9c1b3ed12655d0e81364846ac16a9d9c9b2397947fbef65513ab1a6554f2c57` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Program.ExtendsTypingStatement` | 定義 | `acb778ebcc13382922e21a670805ba2a367cebf3b3631116fd0a90e2912150d4` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Program.ExtendsExhaustiveStatement` | 定義 | `e76a9834500f009748e416b2619cf7b13056a60f83c470b33d7d12a9ac619c92` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Program.ExtendsDeclarationStatement` | 定義 | `acb778ebcc13382922e21a670805ba2a367cebf3b3631116fd0a90e2912150d4` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.Program.ComposeStatement` | 定義 | `acb778ebcc13382922e21a670805ba2a367cebf3b3631116fd0a90e2912150d4` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StandardModel.ComposedRowsStatement` | 定義 | `b4ea9790a15c2c9fa6e583a8d9987055c9968bedfbd9411d0e56eddb50956c09` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StandardModel.ComposedReleaseStatement` | 定義 | `b4ea9790a15c2c9fa6e583a8d9987055c9968bedfbd9411d0e56eddb50956c09` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StandardModel.TableConditionsStatement` | 定義 | `b4ea9790a15c2c9fa6e583a8d9987055c9968bedfbd9411d0e56eddb50956c09` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.StandardModel.CompletionCoreStatement` | 定義 | `b4ea9790a15c2c9fa6e583a8d9987055c9968bedfbd9411d0e56eddb50956c09` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.embedProgramWellTyped` | 定理 | `e5c4c0d03f6c2d773363d4a805e74f4ce3f03959fca39ef5a81e795121c6446c` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.embedProgramWellFormed` | 定理 | `8a90e5cab91ce5eaddbec715d575e19a9d93776160e556dcb3b018ebd4624d3a` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.embedDefWellTyped` | 定理 | `3e2cf83be3063366be0581d025153629c21b4eca05b77106e42bddbe15774b9c` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.embedImplWellTyped` | 定理 | `1b4dd64c0a759ef0b095940f20d03dd965ae41bf9df31644e7c4e998d7e1f47e` | Classical.choice + Quot.sound + propext |
| `Release.Refinement.embedStateTyE` | 定理 | `4781f1d8ec0e34207bfc93efc6b10b762ad08e070a6826294a024ead88d08b22` | Classical.choice + Quot.sound + propext |

読者の依存は、段の最終状態の書き出しの型又は値の定数の閉包で機械的に照合した（[h/obligations.json](h/obligations.json) の `main_readers`、28組）。名前の一致だけで判定していない。主な結果は次である。各主定理の型は同名の言明（`ProgressStatement` など9）を読み、`Surface.surface_effect_soundness` は `Surface.desugar_typed` と `effect_soundness` を、`Surface.surface_target_sound` は `Surface.desugar_typed` と `reachable_target_sound` を、`StandardModel.included_guarantees` は `completion_core`・`progress`・`reachable_target_sound` を、`Surface.surface_guarantees` は `included_guarantees` と性質1の相互帰納（`HasBlockQ.desugar`）を、`CheckAccept.checkProgramAccepted_sound` は `CheckTables.checkProgram_sound` を、`Surface.checkProgramAccepted_main` は `checkProgramAccepted_sound` を、空疎でない証人 `Surface.CheckedMainExamples.main_guarantees` は `checkProgramAccepted_main` を読む。7入口の根は、`surfaceCheck` が `CheckAccept.checkProgramAccepted` と `Exchange.CheckInput.prepare` を、`desugarDiff` が `Surface.desugarProgram` を、`coverageDiff` が `checkMatchWithView` を、`intervalDiff` が `IntervalReport.connect` を読む（部分関数は実装の `._unsafe_rec` へ、根ごとの同じ名前は同じモジュールのものへ辿る）。相互帰納の兄弟の `Surface.HasTypeQ.desugar` は `HasBlockQ.desugar` から定数として読まれない（同じ相互の再帰の別の定数）ので、性質1の行の証拠には両方を並べた。

## 旧主定理と新しい主定理の対応

旧主定理は段の開始版にあり、最終版の環境にない。新しい主定理は最終版にある（[h/audit-summary.json](h/audit-summary.json) の `old_main`。全17行で成り立つ）。

| 旧主定理（段の開始版） | 新しい主定理（最終版） | 言明 |
|---|---|---|
| `Release.progress` | `Release.Refinement.progress` | `ProgressStatement` |
| `Release.preservation` | `Release.Refinement.preservation`・`steps_preservation` | `PreservationStatement`・`StepsPreservationStatement` |
| `Release.step_sound` | `Release.Refinement.step_sound` | `StepSoundStatement` |
| `Release.effect_soundness` | `Release.Refinement.effect_soundness` | `EffectSoundnessStatement` |
| `Release.effect_soundness_noLamNames` | `Release.Refinement.effect_soundness_noLamNames` | `EffectSoundnessStatement`（開始の条件を `StartCondition.of_typed_noLamNames` で与える） |
| `Release.reachable_target_sound` | `Release.Refinement.reachable_target_sound` | `ReachableTargetStatement` |
| `Release.reachable_target_sound_event` | `Release.Refinement.reachable_target_sound_event` | `ReachableTargetEventStatement` |
| `Release.reachable_target_sound_of_assumptions` | `Release.Refinement.StandardModel.included_guarantees`（完成した表の信頼条件の下の系） | — |
| `Release.step_target_sound` | `Release.Refinement.step_target_sound` | `StepTargetStatement` |
| `Release.Model.assumptions`・`ModelTargets.assumptions`・`ModelHttp.assumptions` | `Release.Refinement.ExternalModels.ModelCase.composition`（三モデルの適用例） | — |
| `Surface.desugar_typed` | `Release.Refinement.Surface.desugar_typed` | — |
| `Surface.surface_effect_soundness` | `Release.Refinement.Surface.surface_effect_soundness` | — |
| `Surface.surface_target_sound` | `Release.Refinement.Surface.surface_target_sound` | — |
| `Surface.CheckTables.checkProgram_sound` | `Release.Refinement.Surface.CheckTables.checkProgram_sound` | — |
| `Surface.CheckAccept.checkProgramAccepted_sound` | `Release.Refinement.Surface.CheckAccept.checkProgramAccepted_sound` | — |

旧の主定理と旧の表層の言明のうち、上の表にない旧の性質（設計書から除いた131名）の照合は下の「旧の性質の照合」にある。

## 削除した宣言の件数

段で削除した宣言は 12,518（上の表）。うち削除したモジュール 145 の宣言 11,639（旧 Surface 8,655・旧 Release 1,531・Core 1,511 ほか）である。L70.44 の削除の範囲（旧 Release 35＋`LegacyCheck`、旧 Surface 94、Core 16、残すモジュールの37宣言）は群 G の F09 の三条件（[g/f09.json](g/f09.json)）で確かめてあり、本段の比較はその結果と食い違わない。

## 段末の公理監査

[axioms.lean](axioms.lean) を既定 import の閉包と7入口の根ごとに一度ずつ、共有ロックの下で `lake env lean -M 12288` で実行した（8入力、全て終了0、[h/runs-final.json](h/runs-final.json)）。所属モジュールで選んだ全宣言を不動点（2巡。印字で実体化した宣言は0）で列挙し、`axiomInfo` の宣言がないことを確かめ、マクロのスコープを持たない名前は `#print axioms`、持つ名前は同じ関数 `collectAxioms` で調べた。名前の異なる宣言は 122,817 である。

| 公理依存の集合 | 宣言 |
|---|---:|
| なし | 52,427 |
| propext | 36,080 |
| Classical.choice + Quot.sound + propext | 30,532 |
| Quot.sound + propext | 3,763 |
| Quot.sound | 11 |
| Classical.choice | 2 |
| Classical.choice + propext | 2 |

`sorryAx` は0、許可の外の公理は0、`axiom` の宣言は0である。群 D の申し送り（RV-L70.d3 の情8）の、群ごとの監査の台本が対象から外していたマクロのスコープを持つ名前は、最終版の環境に 39 ある（全て定義、どれも `axiom` でなく、公理依存はなし）。開始版の環境では28だった。`#print axioms` が途中で実体化する名前（群 D の (1) の62件）は、この監査では `collectAxioms` で直接調べるので生じなかった（`AUDIT_UNRESOLVED` 0）。

## コメントの工程 ID と heartbeat の設定

段で足した・変えた `formal/` の .lean 567ファイルのコメントを台本で検査した（[h/comments.py](h/comments.py)、[h/comments.json](h/comments.json)）。群 H の開始版には15ファイルに79件（段・単位の ID 25、問いの番号25、DET の番号8、決定の判断4、案 A 4、レビュー5、決定の番号 D 4 など）が残っていた。それらを今の性質の文と設計書の節の名前へ書き換え、今の作業木で0件である。R 段への義務を名指すコメント（`StandardModelCompletion` の衝突18名の公開名、`TargetTable` の Rust の表との照合）は設計書の節の名前で書いた。

`set_option maxHeartbeats`・`maxRecDepth` は345箇所あった（[h/heartbeats.py](h/heartbeats.py)、[h/heartbeats.json](h/heartbeats.json)）。段の前からの330箇所は前の段までの記録のものである。段で足した15箇所のうち8箇所は改造の記録に既定値での timeout がある。記録のない7箇所（群 D の再開10の `PredicateSimulationAlgebra` 2・`PredicateSimulationTyping` 2・`PredicateSimulationOpenPipeSafety` 3）は、その一行だけを外した写しを単独の Lean で検査した。6箇所は既定値で timeout し、`PredicateSimulationAlgebra` の189行の一箇所は外しても終了0だったので、本番から外した（今は344箇所）。

## 四分類の最終件数

l60/detail.md 第2.4節の定義（不成立・空疎・自明・実質）で、tables.md の各行の証拠の言明を判定した（[h/obligations.json](h/obligations.json)）。前提も入力も持たない欄は自明に数える（2026-11-05 の設計者の決定）。Lean の証拠を持たない行（記録・対応表・他段）は対象外とした。実質の行の空疎でない証人は、群 B の主定理の例・群 K の効果の健全性の適用例・群 C の `StandardModel.ApplicationExamples.user_guarantees`・群 E の `Surface.CheckedMainExamples.main_guarantees` と `Surface.MainExamples.main_guarantees`・群 D・E・E2・F1・U の四分類の表の証人である。

| 母集団 | 実質 | 自明 | 空疎 | 不成立 | 対象外 |
|---|---:|---:|---:|---:|---:|
| 申し送り78行 | 66 | 1 | 0 | 0 | 11 |
| 義務59行 | 48 | 0 | 0 | 0 | 11 |

自明の1行は L60-H02（外部参照の適用は前提を持たない遷移で、契約の入力を読まない。群 B の判断(3)）である。空疎と不成立は0である。各群の results.md の条件の四分類の表（[h/four.py](h/four.py)、[h/four.json](h/four.json)。12節）の集計は実質82・自明10・空疎1・不成立12・保留10・一部保留1であるが、群の途中の状態（退けた案や前段の署名への反例、未着手の保留）を含むので段の最終の件数にしない。不成立12は群 K の4表の退けた案と固定署名の旧い言明への反例と、群 F2 の String の所属の反例であり、閉じた言明の不成立ではない。群 A の保留3は群 B（`StartCondition`）と群 C（`additions_refl`・`noAssumptions_completion`・`user_guarantees`）で、群 K の保留3は群 K の再開4で解消した。群 E の空疎1は例の `satDec = false` の欄で、他の入力欄を空疎と呼ばない。

## 義務と申し送りの最終の判定と残る所有

tables.md の全行を、証拠の完全名と読者の経路で判定した。証拠が最終版の環境にあること、読者の型又は値の定数の閉包に証拠が含まれること（最短の経路の長さ）を台本で照合した（[h/obligations.py](h/obligations.py)。表は [h/obligations.md](h/obligations.md)）。「完了」の行には証拠の完全名と残る段を同じ行に書いた。他段の行を完了と書いていない。

| 母集団 | 完了（L70 の分） | 完了（読者を要しない） | 完了（記録） | 他段 | 読者の照合あり |
|---|---:|---:|---:|---:|---:|
| 申し送り78行 | 65 | 1 | 11 | 1 | 55 |
| 義務59行 | 49 | 0 | 8 | 2 | 36 |

他段の行は L40-O135（通常 decoder の接続。取りまとめが R40 の詳細化で担当を確定）、O170（構文の少数測定を行わない設計者の決定。R10a・R60・D10）、O027（正式 RSS は取りまとめの段末の work）である。F-REG を入口とする行（L60-H30・O086・O121）は L70 の分（7入口の切替と書き出しの新しい版）を完了とし、F-REG の実行は取りまとめの未実施の手順として残した。

### 後段へ送った義務と申し送り

群 A〜G・K・K2 が R10a・R10b・R20・R30・R40・R50・F-REG へ送った義務と申し送りを、各群の results.md・レビューの記録・plan.md から集めた。35行である。

| # | 受け持つ単位 | 内容 | 出どころ | 0件にする条件 |
|---:|---|---|---|---|
| 1 | R10a | 新しい表層の構文と型付けの判断、別名の展開、record の依存する欄の表現、生成判定関数、新しい関数の署名を、処理系の型表現・構文・名前解決で同じ形に作る | detail.md 第8.4節 | 処理系の型表現と名前解決が同じ形を作り、F-CONN の比較で差がない |
| 2 | R10a | 別名の型引数が使う位置の局所の値を参照する形（`Integer{x \| x <= limit}`）は、別名の値引数に捕獲されて `AliasDecl.expand_annotation` の対象外になる。処理系がこの形を拒むか、捕獲を避けて受けるかを照合する | plan.md 2026-11-06（群 D の取り込み、RV-L70.d 情1） | 処理系の別名の展開がこの形を拒む又は捕獲を避け、Lean の展開との差が0件 |
| 3 | R10b | 性質1、checker と実入口の受理の健全性、期待型（O068）、変性（O005・O033）、ソース順序（O053）、`Program.Additions` の欄を、処理系の推論の結果と同じ判断で照合する | detail.md 第8.4節、tables.md の義務の残る段 | 推論の結果が同じ判断を満たし、比較の差が0件 |
| 4 | R10b・R50 | 部分適用の `.lam` と `.dependentLam` の選択と、結果型・効果を穴の束縛の下で読む差。処理系の脱糖は非依存の `.lam` だけを作る | d/results.md 再開1、RV-L70.d | 依存のある部分適用で処理系が同じ型付けの項を作り、差が0件 |
| 5 | R10b・R50 | match の腕のガードと本体を照合する値の束縛の下で書く新しい表層の約束と、処理系の書き出しの番号 | d/results.md（R10b・R50 への申し送り（追加）） | 書き出しの番号が同じ束縛を指し、差が0件 |
| 6 | R10b | 取得関数の結果型の欄の関係の篩（desugarDiff の `definition.header.ret` の差。固定入力 named 10・extensible 1、処理系の書き出しの全ての取得関数） | g/results-claude.md、plan.md 2026-11-07（RV-L70.g の処置の報告 (3)） | 処理系の脱糖が同じ篩を付け、`KNOWN_DESUGAR_DIFFERENCES` の列挙が空になる |
| 7 | R10b | `C_Match` の `Ty.Declared` を処理系の照合と一致させる | plan.md 2026-11-06（RV-L70.k の情報 (4)） | 処理系が同じ宣言を要求し、書ける match が減らないことを照合する |
| 8 | R 段の処理系の篩の書き出し（担当は取りまとめが決める） | 結果型の篩（7名）で準備の段に断った23入力 | g/results.md・results-claude.md の F-REG への申し送り | 処理系の書き出しが篩を付け、この理由の準備の失敗が0件 |
| 9 | R20 | checker が呼ぶ検査器の入口と `@proofSteps` の上限の入力。L30 の検査器の全実作業の対応 | detail.md 第8.4節、e/results.md | 判定の手続きと steps の計上が同じ契約を満たす |
| 10 | R20・R50 | Float の七原子の連言の順、String の比較と二測度の三つの連言の順、data の構成子列の宣言順 | k2/results.md「後段への申し送り」 | 処理系の生成が同じ順で、比較の差が0件 |
| 11 | R20・R50 | Float・data の欄を持つ record の match が `factsWF` の再検査で不当に拒否されないこと | k2/results.md「後段への申し送り」 | 実際の受理例で拒否が0件 |
| 12 | R30 | 動的な pattern の解析、`Process.pathBases`・`checkPathInAt` の公開名、`Refinement.check` の δ を組み込みと実行ごとの σ で同じにする | detail.md 第8.4節 | 処理系の実装が同じ δ と σ を使う |
| 13 | R30 | `Scope.ScopeError.At`（`Scope.checkPathIn`、data `Scope.ScopeError`・`Http.RequestCheckError`）で準備の段に断った22入力 | g/results-claude.md の F-REG・R50 への申し送り | 処理系が At を実装し、この理由の準備の失敗が0件 |
| 14 | R30・R60 | 公開形の値（`Detail.publicTree`）を処理系の値・Show・JSON と照合する。旧 API の静的拒否は旧構成子。要求の At の診断の固定値 `unreachableTree` の選び方 | u/results.md「申し送り」、plan.md 2026-11-06（群 U 再開1） | 処理系の値と表示が同じで、差が0件 |
| 15 | R40 | 衝突18名の公開名を精密側へ切り替える（今の処理系の公開名は通常側を呼ぶ） | c/results.md（`collisionBody_spec`）、J70-3 | 処理系の公開名が `FunctionNames.publicTarget` の指す内部名と一致する |
| 16 | R40 | 合成表の発行の内部名 `Example.pathBases` の改名（公開名 `Process.pathBases`） | u/results.md「申し送り」 | R40 で改名するかを決め、対応表と一致させる |
| 17 | R40・R60 | 合成表の `CheckError.expected` は不透明な定数。処理系の実診断の書式と比べるときは比較から外すか表示器を表の引数にする | f2/results.md、plan.md 2026-11-06（RV-L70.f2 (3)） | 比較の方法を決め、差が0件 |
| 18 | R50（F-CONN） | 交換の7入口が保証するのは交換した組込みの表の下での checker の健全性（`prepare_sound`）。主定理の前提 `q.B = complete …` との接続 | g/results.md「後段への申し送り（追加）」 | 完成表と交換の表を結ぶ定理を置き、F-CONN の全比較が成功する |
| 19 | R50 | 検査器（写さない交換の表を読む）がプログラムの検査で閉包の外の組込み・data の行を読まないこと（又は読んでも結果に効かないこと）の接続。閉包は文字列の出現で数える上への近似 | g/results-claude.md の F-REG への申し送り、plan.md 2026-11-07 | 閉包の像の上で接続を示す |
| 20 | R50 | 受理から型付けまでの接続。`Materials.checkProgramAccepted_sound` には `Check.Input.Sound` のほかに `DefSupport`・`ImplSupport` が要り、交換の準備はこれを示さない | g/results-claude.md（RV-L70.g の情2） | 7入口の成功から型付けまでを閉じる定理を置く |
| 21 | R50 | data の欄の名前（`conFields`）・`extensible`・変性と完成表の data の表との一致。標準の data の宣言の支持（`tysEq` の等号化）、鍵の印のそろえ（`prepare_constraints` と写さない表） | g/results-claude.md（RV-L70.g の軽8 ほか） | 一致を示す |
| 22 | R50 | `Http.sendIn`（処理系は `Http.Response` を record の data、標準表は不透明型）で準備の段に断った20入力 | g/results-claude.md | `Http.Response` の抽象と完成表を接続し、この理由の準備の失敗が0件 |
| 23 | R50 | `Prepared.unknownBuiltins` の名前を、標準表を広げて合成済みの行にするものと仮定側の一覧（`NameLists`）に置くものに分け、最後に一覧の外の名前を準備の段で断る | plan.md 2026-11-07（RV-L70.g の処置の報告 (1)） | 一覧の外の名前が0件になり、準備の段で断る形にする |
| 24 | R50・F-REG | 7入口は `.custom` の表を使い、群 D の名前解決（内部行の準備）を通らない。篩の中で利用者の述語の関数を呼ぶ入力は処理系が受理し Lean が断る差になりうる | g/results-claude.md（RV-L70.g の軽7） | F-REG で件数と結果を数え、交換の表に内部行を足す経路が要るかを R50 で決める |
| 25 | R50 | `DataTable P` の前提（宣言の一覧で尽くされる・要約の収束・変性の検査）と処理系の検査の照合、Map・Set の鍵の順序（`DataTable.keyNames`）と処理系の鍵の順序 | c/results.md（取りまとめの決めた3点）、plan.md 2026-11-06（群 C の途中の報告） | 照合で差が0件 |
| 26 | R50 | 構成子の並び: 19の公開の宣言を合成表の構成子の並びの最後に置いた。`CheckError` の宣言を挟んで位置がずれた | u/results.md、plan.md 2026-11-06（RV-L70.f2 (3)） | 新しい並びで鍵の順序を照合し、差が0件 |
| 27 | R50 | `Val.Source` の差（Lean は `.externalRef` を値として受け、Rust は拒否）、`RoundingMode` の名前と5構成子、仮定側150名の実登録との対応、Map・Set の δ が読む構成子の並び | tables.md の L60 行（c/results.md の再開3） | 対応表どおりに照合し、差が0件 |
| 28 | R50 | 射影形の host（`::ffff:127.0.0.1`）を Lean の `parseAtInput .host` は受け付け、処理系の `host_target` は拒否する | f1/results.md、plan.md 2026-11-06（群 F1 の報告） | 比較の対象に入れ、差を決める |
| 29 | R50 | 消去の範囲と条件: Lean は構文で決まる安全な位置（案 B）だけを消去する。処理系の消去の範囲・条件（Site の十分条件、実引数が変数の `check` は消さない）との照合、反例（`CheckErasureBoundary.counterexample`・`PatternContextObstruction.obstruction`）の照合、標準の宣言表の照合（`DeclarationAgreement.check`） | e3/results.md「後段への申し送り」、plan.md 2026-11-06（RV-L70.e2 情報1・群 E の後半の停止） | 処理系の消去が Lean の範囲に入るか、差と観測の保存を照合する |
| 30 | R50・群 G の例 | 取り出しの関数を持つ実入口の `Program.WellFormed` の証人で `AccessorOk` を供給する | k2/results.md（RV-L70.k2 の情2） | 証人を置く |
| 31 | R50 | 交換の新しい版、7入口と入力形成の層、L70.42 の書き出しを新機能（篩・σ・外部）へ広げ、外部の除外を両理由とも0件にする（O086・O121） | detail.md 第8.4節、tables.md の O086・O121 | F-CONN の全比較が成功し、外部の除外が0件 |
| 32 | F-REG | 旧 checker が受理した値域外の整数（`Integer8(128)` 等）。処理系の正常な書き出しに同じ形があるか | g/results.md「F-REG への申し送り」 | 入力を省かず、新しい除外を足さずに差を個別に判定する |
| 33 | F-REG | 推論の燃料（`4 * 節数 + 4`）の十分性は未証明 | g/results.md「F-REG への申し送り」 | 燃料切れの unknown を記録し、成功扱いしない |
| 34 | F-REG | 準備の失敗の件数と理由（`Http.sendIn` 20・At 22・結果型の篩 23・その他0）と `unknownBuiltins` の名前と件数、受理の規則の解析の表と処理系の `patterns`・`hosts` の食い違い（Top として扱う）の件数を全入力で数える | g/results.md・results-claude.md | 全比較で数え、分類の外の失敗が0件 |
| 35 | F-REG | 固定入力の試験の文言と件数の差（batch3・batch4 の一致の件数）、named-programs の表層の一括検査（73,853定義、6〜9時間の見込み） | g/results.md、plan.md 2026-11-07（設計者の指示、F-REG の時期） | 段末のレビューと処置の後の最後の関係状態で一度だけ流し、不一致と未処置の失敗が0件 |

R60・D10・V10 へ送った行は tables.md の「L70 の後に残る段」の列にある（[h/obligations.md](h/obligations.md)）。

## 旧の性質の照合

L70.45 で設計書から除いた旧の名前（[g/docs-rewrite.md](g/docs-rewrite.md)「除いた名前の表」129行・135名）を一つずつ判定した（[h/legacy.py](h/legacy.py)。表は [h/legacy.md](h/legacy.md)）。旧の名前は段の開始版の環境で所属と種類を引き（名前空間の5名を除く）、旧の言明は `git show <B_STAGE>:<ファイル>` で読んだ。根拠の名前は最終版の環境で一つに決まることを確かめた。

| 判定 | 行 |
|---|---:|
| 新しい主定理・定理から導ける | 28 |
| 新しい形式化では別の形で扱う | 70 |
| 失った保証（重い 18・軽い 13） | 31 |

「導ける」は、同じ定理・定義が既定 import に残る旧モジュールにあるもの6、同名の構造体が篩付きの表層にあるもの1（`Limits`）と、新しい主定理・性質1・保存と局所の不変条件の合成から導けるものである。「別の形」は、主定理の証明の内部の補題、旧の像との同値（旧導出の埋め込みで扱う）、検査器と受理の内部の判定を新しい健全性の定理で扱うものである。脱糖の捕捉禁止（`builders_no_capture` 系4）は、ラムダ・遅延・節の本体を専用位置を隠した文脈で型付ける規則と性質1と状態の局所の不変条件で扱い、脱糖の出力の構文の性質としては述べていないので「別の形」とした（違いを legacy.md に書いた）。

「失った保証」の docs/todo の項目の候補は次である（docs/todo へは取りまとめが足す）。

| 題 | 内容 | 重さ | 出どころ |
|---|---|---|---|
| 構築器の一歩の通常セルと事象の性質を篩付きの核で述べ直す | 専用項の一歩が事象を伴わず（`builder_step_no_event`）、通常の Reference の値セルを変えない（`builder_step_frame`、関係 `OrdinaryStoreEq`）。捕捉と再開の一歩が既存の専用セルの場所と内容を保つ（`capture_builder_cell`・`resume_builder_cell`）。E_DropRel の後続が事象なしで解放枠を足さない（`drop_local_silent`、`BuilderOnlyFrames`・`builder_frames_releases_nil`）。篩付きの `preservation` は型付けだけを結論する。Step の規則の直接の系として足せる見込み | 重い（実行の観測） | 段の開始版 `formal/Benitoite/Release/Lemmas/BuilderStore.lean`、[h/legacy.md](h/legacy.md) |
| Scope の局所解析と受理した本体の評価の接続を篩付きの表層で述べ直す | 受理した本体の評価が文の始まりへ到達したとき、局所解析の記録が局所の値に対応し、範囲を付けた位置の値がその範囲の対象を保持すること（`analyzeBody_sound`・`analyzeBody_requiredIndex`、定義 `RhsEval`・`ArmEnter`・`ReachBlock` と補題 `rhsEval_step`・`armEnter_steps`）、検査・射影・拡大の成功値とコアの実行の形の接続（`scope_check_connection`・`scope_local_connection`・`scope_local_typed`・`scope_check_core`・`http_check_connection`）。篩付きの受理の健全性（`acceptProgram_sound`）は範囲の被覆だけを述べる。補助の `reachAt_occurrences`・`analyzeBody_numbered`・`requestLitBound_known_ports_wf` も同じ項目に含める | 重い（受理と実行の観測） | 段の開始版 `formal/Benitoite/Surface/ScopeSound.lean`・`ScopeLower.lean`・`ScopeOccurrence.lean`・`ScopeState.lean`、plan.md 2026-11-07（L70.45 の文書の担当の報告） |
| 補間の部分の判定の完全性 | 旧 `interpAllowed_spec` は判定 `interpAllowed` と条件 `InterpPart.Allowed` の同値だった。篩付きは判定から条件への向き（`interpAllowed_sound`）だけで、条件を満たす補間を判定が受け付ける向きを述べていない | 重い（受理） | 段の開始版 `formal/Benitoite/Surface/CheckPredicates.lean` |
| 旧の具体例の篩付きの版 | 表層の対象健全性の前提を満たし IO の事象に到達する例（`main_reach`）、誤った規則で対象健全性が破れる反例（`wrong_rule_unsound`）、Log の検査器の例（`emit_checked`）、型付きの失敗の公開の検査入口と有限遷移の例（`FailureExamples`）、脱糖の番号の照合の例（`dedicated_lowering`） | 軽い（主定理の結論は変わらない） | 段の開始版の `Surface/CoverExamples.lean`・`Release/TargetReachExamples.lean`・`Surface/LogExamples.lean`・`Surface/FailureExamples.lean`・`Release/FailureExamples.lean`・`Surface/BuilderExamples.lean` |
| 交換の書き出しの効果の名前の完全性 | `Prepared.writeEffNames`・`writeEffNames_complete`（原子を落とさずに効果を書き出す）。篩付きの交換は Lean から効果を書き出さないので、要らなくなった可能性がある | 軽い | 段の開始版 `formal/Benitoite/Exchange/CheckInput.lean` |

群 H2 は、上の「失った保証」の31行を篩付きの核と表層の上で述べ直した（[h2/results.md](h2/results.md)。旧の行ごとの定理の完全名と述べ直さない理由は同書の「旧の行ごとの記録」）。重い18行は全て述べ直した（構築器の一歩の通常セルと事象の性質は `Refinement.BuilderStore`、補間の判定の完全性は `Surface.Check.interpAllowed_spec`、Scope の局所解析と受理した本体の評価の接続は `Surface.ScopeEval`・`ScopeReach`・`ScopeConnection`）。軽い13行のうち9行（`OrdinaryStoreEq`・`BuilderOnlyFrames`・`builder_frames_releases_nil`・`reachAt_occurrences`・`main_reach`・`wrong_rule_unsound`・`emit_checked`・型付きの失敗の例・`dedicated_lowering`）を述べ直し、4行（`Prepared.writeEffNames`・`writeEffNames_complete`・`requestLitBound_known_ports_wf`・`analyzeBody_numbered`）は理由を記して述べ直していない。旧の保証が篩付きの規則の下で成り立たない例はなかった。足したモジュール 11 と変えたモジュール 2 の全宣言 2,647 を公理監査し（[h2/audit.json](h2/audit.json)）、許可した三公理の外と `sorryAx` は 0 である。

| 判定（群 H2 の後） | 行 |
|---|---:|
| 新しい主定理・定理から導ける | 28 |
| 新しい形式化では別の形で扱う | 70 |
| 群 H2 で述べ直した（重い 18・軽い 9） | 27 |
| 述べ直していない（軽い 4） | 4 |

## 01-12・07-04・formal/README.md の主定理の一覧の照合

`formal/README.md` の主定理の一覧（`#print axioms` の41名）、07-04「証明する性質」の定理の名前、01-12「確かめる性質」の主な名前（`Surface.desugar_typed`・`surface_effect_soundness`・`checkProgramAccepted_main`・`linked_main`・`StandardModel.included_guarantees`・`Surface.surface_guarantees`・`CheckedMainExamples.main_guarantees`・`StartCondition.of_typed_noLamNames`）が最終版の環境にあることを [verify.py](verify.py) で照合した。README の「旧 `Release` の74モジュールと旧 `Surface` の3モジュール」は既定 import の閉包の数（74・3）と一致し、Core は0である。食い違いはなく、文書は変えていない。

## 設計者の見直しの対象

plan.md「計画の変更と取りまとめへの確認点」の2026-11-06・07 の L70 の項目のうち「設計者の見直しの対象」と書いた37項目である（停止の条件を改めた項目は、この一覧の集め方を決めたものなので除いた）。

| # | 日付・出どころ（plan.md「計画の変更と取りまとめへの確認点」） | 内容 | 選んだ案 | 退けた案 | 影響 |
|---:|---|---|---|---|---|
| 1 | 2026-11-07 RV-L70.g の処置の報告 | 標準表にも名前の写しにもない組込み（`Json.*`・`Csv.parseWith`・`TaskGroup.open` など）を呼ぶ入力の扱い | 断らずに `Prepared.unknownBuiltins` に記録し、F-REG で名前と件数を集計する。R50 で標準表を広げるものと仮定側の一覧に置くものに分け、最後に一覧の外を断る | 写しにも標準表にもない組込みを準備の段で断る（named-programs の20入力の試しで15を断った） | 交換の7入口の検査器の健全性は交換した表の下で成り立つ。R50 の義務が一つ増えた |
| 2 | 2026-11-07 L70.45 の文書の担当の報告 | 篩付きの形式化に同じ名前の対応物がない旧の性質（構築器のセルの保持・脱糖の捕捉禁止・Scope の局所解析の接続定理・具体例）を設計書から除いた | 設計書は今の Lean が示すものだけを書き、旧の言明との照合を群 H で行う（本書「旧の性質の照合」） | 旧の名前を設計書に残す | 旧の性質のうち「失った」と判定したものは docs/todo の項目の候補（本書の表） |
| 3 | 2026-11-07 群 G の第2の担当の続き | 標準表との一致の判定の対象 | プログラムが参照する組込みの名前と、そこから型を通じて届く data の宣言の有限の閉包に限る。閉包の中の差は緩めずに断り分類する。検査器が閉包の外の行を読まないことの接続は R50 | `Http.Response` の record と不透明型を同じとみなす、全行の照合のまま記録だけにする | 評価できた1,454入力のうち1,403が準備を通り、F-REG の表層の比較に中身ができた |
| 4 | 2026-11-07 群 G の二人目の Claude の担当 | 標準表との一致の判定を緩めないこと | 判定は緩めず、断った入力を名前の一覧（At・結果型の篩・`Http.sendIn`）で分類し、R30・R50 の受け入れで0件にする義務として送る | 照合で篩を外す、記録だけにする、標準表を処理系に合わせる | 処理系がまだ設計の決定に追いついていない差を F-REG で分類して残す |
| 5 | 2026-11-07 群 G の L70.41 までの報告 | 交換の7入口の保証の範囲 | 7入口が保証するのは交換した表の下での checker の健全性。主定理の前提 `q.B = complete …` との接続は R50（F-CONN） | （なし。範囲を明記した） | 7入口の成功を主定理の前提の充足と呼ばない |
| 6 | 2026-11-07 群 D の結合の追随 | 期待型のない位置の呼出しの結果型の篩 | 束縛した実引数を指す篩の層を除く `dropBound` で番号の潰れを直す。期待型のない位置の「結果 = field(受け手)」の関係は外側で使えない | 実引数に依存する篩を代入で外側へ残す（型付けの規則か論理の核の変更になる。docs/todo の TODO-328） | 期待型のない位置の取り出しの結果の篩が外側で使えない |
| 7 | 2026-11-07 群 D と群 K2 の結合の後退 | checker の問い合わせの生成 | 問い合わせの番号の対応を直し、利用者の証明書なしに内部の候補で閉じる。証明書を与えない実入口の例を足す | 例に証明書を与える（書ける形を狭める） | String・Float の欄の取り出しの呼出しが証明書なしで受理される |
| 8 | 2026-11-07 群 G の Claude の担当の判断点 | (2) checker の入力の表の契約 | 7入口は交換した組込みの表（`mkBuiltins`。案 A）を使い、完成表との一致は有限の表どうしの判定として実装し、失敗した入力を断る | 依頼文の `.custom (complete …)` に揃える（交換の内部名を標準の名前へ写す必要がある） | 完成表と型付けの七欄の一致を前提に置かない |
| 9 | 2026-11-07 RV-L70.k2 の処置 | 篩の論理の含意の規則の追加 | 関係の事実と左辺の原子から右辺の同じ原子を導く規則を足す（受ける原子は関係の下で解釈が変わらないと sort ごとに証明したもの）。`Entails.measured` とあわせて二規則 | 篩の事実を射影の結果へ流さない | 健全性を証明した規則の追加で、書ける形を広げる |
| 10 | 2026-11-07 RV-L70.d3 の処置の確認と再開10 | 範囲パラメータを持たない定義の受理の規則の拡大 | 閉じた範囲の注釈を持つパラメータの転送と転送の五形を受理し、旧規則の受理から同じ結論が従う保存的な拡張の系を示す | 受理を広げない | 受理する形が広がる |
| 11 | 2026-11-07 群 K2 の初回の停止 | 取り出しの関数の結果型の篩の形（Float の NaN） | 案 A: Float の欄は観測できる性質の一致（`compare .eq` か両辺 NaN、と `floatClass` の同値）、data の欄は全構成子の `constructorIs` の同値を事実にする | 無条件の等号 | 対象の欄の `member` はこの単位では足さない |
| 12 | 2026-11-07 RV-L70.d3 の処置 | 受理の規則の範囲 | 14の判定の関数の公開呼出しの内部行への書き換えを実入口に組み込み、意味の一致を示す。閉じた範囲の注釈のパラメータにも宣言の範囲を読む規則を当て、記号側の受理を広げる | 範囲パラメータのない同じ形の転送を断る逆転を残す | 受理する形を広げる向き |
| 13 | 2026-11-06 群 E の後半の停止 | 消去の範囲 | 案 B: 構文だけで決まる安全な位置（トップレベルの定義の本体と main の計算のラムダの外）に限る。ラムダの中の `check` は消去しない | 案 A: 新しい独立の信頼条件を足す | 処理系の消去の範囲がより広ければ R50 で照合する |
| 14 | 2026-11-06 RV-L70.d2 の処置の確認 | 利用者の書ける形（範囲パラメータの転送の `unknownSource`） | 受理の範囲の判定を範囲変数のまま記号で扱えるよう広げる（群 D の再開8） | 制限を残す | 範囲パラメータの転送が受理される |
| 15 | 2026-11-06 RV-L70.f2 | 公開の関数の結果型（14の判定の関数の J70-9） | 群 D の J70-9 の作業が14関数の全てについて保守的な経路を選んで閉じる | 結果型を素の Boolean で仕上げたまま | 篩の中の判定の呼出しの結果型と if の事実 |
| 16 | 2026-11-06 群 F2 再開2の停止 | 公開の関数の結果型（pattern がリテラルの `pathMatches`・`hostMatches`） | δ の行・合成表・型付けを Boolean で仕上げ、リテラルの pattern を篩付きの結果型へ組み立てる変換は群 D の受け持ち | 一つの固定範囲を結果型に置く署名（反例で断られた） | 表層の変換で一致の篩を付ける |
| 17 | 2026-11-06 群 F2 再開1の停止 | 固定した署名の契約の変更（`Refinement.check` の全域性） | 評価が `some true` のときだけ `Ok`、`some false` と `none` を `CheckError` にする | 型付きの入力で評価が `none` にならないことの要求（`totality_obstruction` で不成立） | 公開署名・書ける形・型付けの規則・D19 の意味は変えない |
| 18 | 2026-11-06 群 F2 の停止 | 型付けの規則（篩の述語の整形式） | ①: `Pred.member` が String の対象も受け、δ と同じ解析で判定し、解析に失敗した文字列は所属しない | ②: String を解析する項を足す | 公開署名と書ける形は変えない。DET-L15 を保つ |
| 19 | 2026-11-06 群 D 再開6の停止 | 型付けの規則の変更（署名の範囲の形成） | 使う組込みの署名が宣言した範囲の深さで形成されていることを表層の葉の構文上の条件として要求する | （止める） | 合成表は `sig_scoped` が全件を満たすので実用への影響はない |
| 20 | 2026-11-06 群 D 再開5の停止 | 型付けの規則の変更（範囲の具体化と許容） | 案 A: 新しい範囲パラメータの規則の葉で、組込みの `admits` と制約の照合を全ての適格な具体化について要求する | 案 B（`ValueAssumptions` に範囲の具体化の保存を足す。新しい信頼条件）、案 C（型引数から範囲変数を除く。書ける形を狭める） | 合成表の各許容の条件が範囲の具体化で保たれることを示させた |
| 21 | 2026-11-06 群 K の取り込みの後の起動 | (2) 利用者の書ける形（発行専用の組込みの節） | 発行専用の組込み（`Process.pathBases`）を処理するハンドラの節を表層の型付けで断る | 受け付ける・警告する | 正しく動くプログラムで書けなくなる形はない |
| 22 | 2026-11-06 RV-L70.k の情報 | 情報3: 前段で固定した署名の変更（`LegacyClausesInput`） | 旧導出が元から持つ入力として三条件の (ii) の内として扱う | 止める | 公開の入口の頭部は変わらず、新しい信頼条件も増えない |
| 23 | 2026-11-06 群 K 再開3の停止 | 前段で固定した署名の変更（`Def.WellTyped.inputs`） | 全ての適格な範囲の具体化の後の入力の署名へ変える。三条件を満たす同種の変更は止めずに差の表に記す | 元の署名を保つ（新しい核で不成立） | 範囲パラメータを持たない定義では元の署名に戻る |
| 24 | 2026-11-06 群 K 再開2の停止 | 前段で固定した署名の変更（`canonical_function`） | 関数参照の枝を範囲引数の列を含む形へ広げる | 止める | 他の結論を弱めない |
| 25 | 2026-11-06 群 K 再開1の停止 | 型付けの規則の変更（`handled` の発行の判定） | `handledSelected`（`effOps` が選んだ操作の表に合わせる） | 案 D の `issuesIn` のまま（旧導出の埋め込みと両立しない） | `P.EffectsOk B` の下では案 D と一致する |
| 26 | 2026-11-06 群 K の K.1 の停止 | 型付けの規則と値の表現の変更 | 案 A: `Val.fnRef` と `Val.prim` の範囲引数を `List RangeIx`（`.fixed`・`.rvar`）にする | 案 B（開いた本体の構文を別に持つ） | 範囲変数を本体の中の呼出しへ渡せる |
| 27 | 2026-11-06 群 C の途中の報告 | 主な定理を利用者のプログラムへ当てる前提（`DataTable P`） | 系の前提として置き、処理系の検査との対応を R50 で照合する | 処理系の検査から供給する | 具体のプログラムでは宣言の一覧から決定できる |
| 28 | 2026-11-06 RV-L70.b の重1 | Step の規則と型付けの規則の変更 | 案 D に加え、発行の適用をハンドラの探索の対象から外す実行の規則の変更（`E_OpPrim` から pathBases を除く） | 案 D だけ（S13 を満たさない） | 型付けと実行の両方で U02 S13 を満たす |
| 29 | 2026-11-06 L70 群 B の報告 | 主な言明（エフェクトの健全性）と型付けの規則 | 言明は偽（反例）。型付けの側で操作でない組込みのラベルを処理済みから除かない案 D を推し、`StepTargetStatement` に WellFormed・WellTyped を足す | 担当の案 A（発行をハンドラへ移す。S13 と食い違う） | 効果を偽って受理していた形だけを断る |
| 30 | 2026-11-06 群 C の停止の後（設計者の決定） | 型付けの規則の変更と提供範囲 | ラベルの前提の追加、`C_Match` に `Ty.Declared`、型の制約の判定を利用者の全宣言の要約から作る | 提供範囲を狭める | 利用者の data 型への `==` と Map・Set の鍵を系の範囲に保つ |
| 31 | 2026-11-06 群 D の停止の後（設計者の決定） | 型付けの規則の変更（範囲パラメータを持つ利用者の関数） | 案 A: 核に範囲の種類の列と範囲の列を足す（群 K） | 表層だけで受ける（性質1が偽になる） | U02 S8・S9・R4・R5 の書き方を表層が受け付ける |
| 32 | 2026-11-06 RV-L70.a の重1の処置の後 | J70-5 の削除の範囲 | 旧 Release 74 を残し35を削除、旧 Surface は構文3を残して94を削除、Core 16 を削除、残すモジュールから37宣言を除く | 残すモジュールでは import の行だけを除く（成り立たない） | 旧主定理は残さない |
| 33 | 2026-11-06 L70 群 A の報告 | (1) J70-5 の削除の範囲（区間解析）、(2) 主な言明の前提 | (1) 旧 Surface の構文だけを区間解析の入力として残す（代案 b）。(2) 進行と実行関数の健全性に `P.WellFormed`（と `P.WellTyped B`）を前提に足す | (1) 区間解析を新しい表層へ移す（代案 a） | 検査を通ったプログラムが満たす前提で、書ける形を狭めない |
| 34 | 2026-11-06 L70 群 U の停止の後（設計者の決定） | 実行の規則 δ（旧 API の静的拒否） | 旧 API の拒否は旧構成子で返す | `ScopeError.At` を返す | 今の版の利用者から見える振る舞いは変わらない |
| 35 | 2026-11-06 分岐する判断の続き（設計者の決定） | J70-7〜J70-11 | Core の削除、Task・TaskGroup の7名は系の範囲の外、判定の関数の結果型の篩（J70-9）、`pathMatches` は絶対形だけ（J70-10）、Float の分類の名前（J70-11） | 推す案（J70-7 は異なる） | J70-10 は書ける形の制限 |
| 36 | 2026-11-06 分岐する判断（設計者の決定） | J70-1〜J70-6 | 旧版の交換の廃止（J70-1）、At の pattern の文字列の枝（J70-2）、18名は精密側（J70-3）、欄の依存は record 全体の篩（J70-4）、旧 Surface・旧主定理の削除（J70-5）、枠は外挿の後（J70-6） | 推す案（J70-1・J70-5 は異なる） | 既存コーパスを新しい版で書き出し直して F-REG にかける |
| 37 | 2026-11-06 U02 の残り（設計者の決定） | 書ける形を広げる6件（R2・R3・R5・R9(a)・R9(b)・R10） | 6件とも受け付ける | 推す案（受け付けない） | L70 と R 段の作業が増える |

## 既定ビルドと照合

作業末の既定ビルド（共有ロック、`formal/` で `lake build`）は終了0、2323 jobs、外側の時間1,288秒、`sorry` の警告0（[h/build-final.json](h/build-final.json)）。コメントを変えた `Release/Syntax.lean` などの下位のモジュールの再ビルドを含む。段の公理監査は上の8入力、段の照合 `python3 -B <改造>/l70/verify.py --tmp <tmp>` は終了0（[h/results.md](h/results.md)）。`scripts/check.sh` と `scripts/check-formal.sh` は実行していない（取りまとめが行う）。

## 見込みと実績

段の枠は所要時間（能動時間）24〜62時間（中心43時間）、積上げは55時間35分〜96時間40分（detail.md 第10.1節）である。群ごとの外側の区間は各群の results.md と effort-ledger.md にあり、能動時間と待ちを分離していない。群 H の L70.46・.47 は外側で18:16〜19:40（約84分。開始版と最終版の既定ビルドの待ち約40分を含む）で、見込み（L70.46 45〜60分、L70.47 60〜90分、旧の性質の照合60〜120分）の合計の下端（2時間45分）より短い。

## 段末レビューへ渡す点

- 「失った保証」の候補5項目（上の表）の docs/todo への登録と、重い3項目を後段のどこで述べ直すか。
- 申し送り・義務の「完了」の判定の基準（証拠の言明の四分類と読者の経路）。特に、標準の表の葉の名前の読者がない行（L50-H03 の `normal_facts`、L60-H02 の外部参照の契約）を「読者を要しない」とした判断。
- 後段へ送った35行の受け持ちと0件にする条件。結果型の篩の23入力の担当（R 段の処理系の篩の書き出し）は取りまとめが決める。
- heartbeat の設定を一つ外した変更（証明の本体と言明は同じ）。
