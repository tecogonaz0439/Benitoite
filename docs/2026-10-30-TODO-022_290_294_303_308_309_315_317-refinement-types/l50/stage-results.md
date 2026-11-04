# L50 段末の照合と受け入れ資料

2026-11-05。実装担当がL50.56〜.58・.60の担当分を照合した資料である。指定ブランチは `m014/l50.l`、B_WORK は `70d726b70b6cb4cbf5abace21d377f6ae155b512`。gitの操作は行っていない。段末の独立レビューRV-L50.lを受け、再開1でL50.59の中1〜3・軽1〜6を処置し、再開2で軽1を指摘の三箇所へ限定した。**正式な最終work/RSS・設計者の受け入れは未実施**である。

## 担当分と全体の区別

技術26義務のL50担当分と、記録2義務の今回の記録を照合した。他段1義務の入力推論と、共通4義務の後段・レビュー・限定採取を分ける。各群末の独立レビューと群Kのtraceの判断を集計したL50の技術的な独立未完は0件であり、未実施のレビューや受け入れを完了へ繰り上げない。33義務の全体を閉鎖した行は0である。

31申し送りは技術24・継承5・他段2の全行を照合した。H17の既済み三補題やH18の処分済み事項を再実装せず、L60/L70/R/D/Vの受け口を保持した。三モデルの75欄は実証済みの出力であり、各モデルのexternal三欄とrelease一欄、計12欄はL60の所有である。

## 全場合と実δ・実行の接続

| 母集団 | 照合結果・証拠 | 後段との境界 |
|---|---|---|
| F01〜F10 | 下記の実定義・実署名。F04/F05は承認済みのNamesWFを含み、F06.currentは不要なCaptureOkを持たない | 主な十言明の形を今回変更していない |
| 起点付加と被覆 | 4パターン対、RangeExpr9対、5起点の等号/不等号、RangeIx4対、Atom9対。ScopeCoverage/MembershipTargets/EffectTargets。全σの所属、同じsnapshot、対象3sortへ接続 | 静的被覆はσを読まない。異なる起点の解決先が等しくても静的には同一視しない |
| 値の型付け | 29規則・25構文、canonical_heldの四形からConstOKで定数を排除し保持三形へ。要求はcheckedRequestとcheckedAt(some req)の二経路 | 任意Ψと非Top/Top、全適格σを維持。一般のValの全shape一致へ強めない |
| 準備とAt | 局所23葉は別母集団。終端失敗15、成功4経路×checkAt8の上限47から12組を排除して35、型付きindexで34。[全場合](d/cases.md)とStateTyE.at_step | 経路の全直積や到達する型付き状態の存在数ではない。全失敗の保存を保持 |
| 13範囲API | 純粋6行・IO7行の全入力、同じ実δ又は実応答関係、全応答の型・適格性・非exit、応答存在を[別列](l/apis.md)で照合 | 正常応答の存在・実IOの成功・副通信の隔離を保証しない |
| 共通表とモデルの署名 | 共通16行＝13＋Reference2＋発行1。Model3・ModelTargets15・ModelHttp7の延べ25行 | 同じPの有限宣言・lookup・arity・行支持。全標準328APIの収集はL60/L70 |
| U1 | 2規則・4保持経路、7位置・5具体化行を[k/connections](k/connections.md)へ照合 | 同じ保持元と実引数位置の一致は入口の前提であり、全体の値の流れはL70。推論手続きはR10b/R30 |
| 実行の読者 | E_Prim/E_Err、E_IO/E_IOErr/E_Exit、E_OpPrimとAt3/発行2の11葉。ScopedTargetInputsと既存保存葉 | 同じσ/Eb/μ、捕捉したhandlerだけfresh継続セルを追加。全保存・到達・表層はL70 |
| 診断の保存 | 失敗7構成子、unboundの5base展開で11形、20等号（save9/fromCheck9/準備の元入力2）。AtErrorReaders | 内部の九欄と七String観測。元の生Valを観測から取り出さない条件を保持。公開形はU02後 |
| 否定 | DET-R01〜26を[k/denials](k/denials.md)の解析済みの内側と字句・CLI・外部・公開形へ分離 | 起点差/分割被覆/未束縛/偽造のLean境界と、実CLIの拒否を混同しない |
| 移植 | 27目的＝新規候補26＋継承T07。Bの13新移植と継承1、C/E/F/Gの残る族を実入口へ対応 | 同じ目的を新定理の件数に加算しない。後段のTargetStep/TargetPropagationは合成の読者 |

充足と応答存在は別に判定した。単に欄の型が存在することや、空の関係についての全称命題を、型付き入力に対する存在証明の代用にしていない。

## 三モデルの75欄

完全名の先頭は、特に断らない限り `Benitoite.Release.Refinement` である。表の各行の原契約は[j/conditions](j/conditions.md)、その75欄の全称の契約を同じ既定環境で単独Leanにより再検査した記録は[l/conditions-check](l/conditions-check.json)である。再開1では[75欄の判定](l/condition-judgments.json)と[判定の検査](l/vacuity-check.json)を追加した。Modelは任意P、ModelTargetsはHasFile P、ModelHttpはHasHttp Pを使う。

| 番号 | 同じモデル | 欄 | 実証の入口と出力 | 判定 |
|---:|---|---|---|---|
| 1 | Model.builtins | sat_rename | `(Model.substitutionAssumptions P).sat_rename` → `(Model.scopeConditions P).sat_rename` | 証明済み（実質） |
| 2 | Model.builtins | admits_rename | `(Model.substitutionAssumptions P).admits_rename` → `(Model.scopeConditions P).admits_rename` | 証明済み（実質） |
| 3 | Model.builtins | sat_values | `(Model.substitutionAssumptions P).sat_values` → `(Model.scopeConditions P).sat_values` | 証明済み（実質） |
| 4 | Model.builtins | admits_values | `(Model.substitutionAssumptions P).admits_values` → `(Model.scopeConditions P).admits_values` | 証明済み（実質） |
| 5 | Model.builtins | sat_renameTypes | `(Model.substitutionAssumptions P).sat_renameTypes` → `(Model.scopeConditions P).sat_renameTypes` | 証明済み（実質） |
| 6 | Model.builtins | admits_renameTypes | `(Model.substitutionAssumptions P).admits_renameTypes` → `(Model.scopeConditions P).admits_renameTypes` | 証明済み（実質） |
| 7 | Model.builtins | sat_subst | `(Model.substitutionAssumptions P).sat_subst` → `(Model.scopeConditions P).sat_subst` | 証明済み（実質） |
| 8 | Model.builtins | admits_subst | `(Model.substitutionAssumptions P).admits_subst` → `(Model.scopeConditions P).admits_subst` | 証明済み（実質） |
| 9 | Model.builtins | delta_typed | `Model.delta_typed` → `(Model.scopeConditions P).delta_typed` | 証明済み（前提の否定で空疎） |
| 10 | Model.builtins | io_typed | `Model.io_typed` → `(Model.scopeConditions P).io_typed` | 証明済み（前提の否定で空疎） |
| 11 | Model.builtins | io_kind | `Model.io_kind` → `(Model.scopeConditions P).io_kind` | 証明済み（前提の否定で空疎） |
| 12 | Model.builtins | io_exists | `Model.io_exists` → `(Model.scopeConditions P).io_exists` | 証明済み（前提の否定で空疎） |
| 13 | Model.builtins | sig_scoped | `Model.sig_scoped` → `(Model.scopeConditions P).sig_scoped` | 証明済み（実質） |
| 14 | Model.builtins | sat_unconstrained | `Model.sat_unconstrained` → `(Model.scopeConditions P).sat_unconstrained` | 証明済み（実質） |
| 15 | Model.builtins | admits_sat | `Model.admits_sat` → `(Model.scopeConditions P).admits_sat` | 証明済み（実質） |
| 16 | Model.builtins | pathBases_shape | `Model.pathBases_shape` → `(Model.scopeConditions P).pathBases_shape` | 証明済み（実質） |
| 17 | Model.builtins | io_op | `Model.io_op` → `(Model.scopeConditions P).io_op` | 証明済み（前提の否定で空疎） |
| 18 | Model.builtins | opEff_io | `Model.opEff_io` → `(Model.scopeConditions P).opEff_io` | 証明済み（実質） |
| 19 | Model.builtins | effect_ops | `Model.effect_ops` → `(Model.scopeConditions P).effect_ops` | 証明済み（実質） |
| 20 | Model.builtins | state_effect | `Model.state_effect` → `(Model.scopeConditions P).state_effect` | 証明済み（実質） |
| 21 | Model.builtins | ref_get | `Model.ref_get` → `(Model.scopeConditions P).ref_get` | 証明済み（実質） |
| 22 | Model.builtins | ref_set | `Model.ref_set` → `(Model.scopeConditions P).ref_set` | 証明済み（実質） |
| 23 | Model.builtins | store_shape | `Model.store_shape` → `(Model.scopeConditions P).store_shape` | 証明済み（実質） |
| 24 | Model.builtins | store_admits | `Model.store_admits` → `(Model.scopeConditions P).store_admits` | 証明済み（実質） |
| 25 | Model.builtins | io_target | `(Model.targetAgreement P).io_target` → `(Model.scopeConditions P).io_target` | 証明済み（前提の否定で空疎） |
| 26 | ModelTargets.builtins | sat_rename | `(ModelTargets.substitutionAssumptions P).sat_rename` → `(ModelTargets.scopeConditions P hp).sat_rename` | 証明済み（実質） |
| 27 | ModelTargets.builtins | admits_rename | `(ModelTargets.substitutionAssumptions P).admits_rename` → `(ModelTargets.scopeConditions P hp).admits_rename` | 証明済み（実質） |
| 28 | ModelTargets.builtins | sat_values | `(ModelTargets.substitutionAssumptions P).sat_values` → `(ModelTargets.scopeConditions P hp).sat_values` | 証明済み（実質） |
| 29 | ModelTargets.builtins | admits_values | `(ModelTargets.substitutionAssumptions P).admits_values` → `(ModelTargets.scopeConditions P hp).admits_values` | 証明済み（実質） |
| 30 | ModelTargets.builtins | sat_renameTypes | `(ModelTargets.substitutionAssumptions P).sat_renameTypes` → `(ModelTargets.scopeConditions P hp).sat_renameTypes` | 証明済み（実質） |
| 31 | ModelTargets.builtins | admits_renameTypes | `(ModelTargets.substitutionAssumptions P).admits_renameTypes` → `(ModelTargets.scopeConditions P hp).admits_renameTypes` | 証明済み（実質） |
| 32 | ModelTargets.builtins | sat_subst | `(ModelTargets.substitutionAssumptions P).sat_subst` → `(ModelTargets.scopeConditions P hp).sat_subst` | 証明済み（実質） |
| 33 | ModelTargets.builtins | admits_subst | `(ModelTargets.substitutionAssumptions P).admits_subst` → `(ModelTargets.scopeConditions P hp).admits_subst` | 証明済み（実質） |
| 34 | ModelTargets.builtins | delta_typed | `ModelTargets.delta_typed` → `(ModelTargets.scopeConditions P hp).delta_typed` | 証明済み（実質） |
| 35 | ModelTargets.builtins | io_typed | `ModelTargets.io_typed` → `(ModelTargets.scopeConditions P hp).io_typed` | 証明済み（実質） |
| 36 | ModelTargets.builtins | io_kind | `ModelTargets.io_kind` → `(ModelTargets.scopeConditions P hp).io_kind` | 証明済み（実質） |
| 37 | ModelTargets.builtins | io_exists | `ModelTargets.io_exists` → `(ModelTargets.scopeConditions P hp).io_exists` | 証明済み（実質） |
| 38 | ModelTargets.builtins | sig_scoped | `ModelTargets.sig_scoped` → `(ModelTargets.scopeConditions P hp).sig_scoped` | 証明済み（実質） |
| 39 | ModelTargets.builtins | sat_unconstrained | `ModelTargets.sat_unconstrained` → `(ModelTargets.scopeConditions P hp).sat_unconstrained` | 証明済み（実質） |
| 40 | ModelTargets.builtins | admits_sat | `ModelTargets.admits_sat` → `(ModelTargets.scopeConditions P hp).admits_sat` | 証明済み（実質） |
| 41 | ModelTargets.builtins | pathBases_shape | `ModelTargets.pathBases_shape` → `(ModelTargets.scopeConditions P hp).pathBases_shape` | 証明済み（実質） |
| 42 | ModelTargets.builtins | io_op | `ModelTargets.io_op` → `(ModelTargets.scopeConditions P hp).io_op` | 証明済み（実質） |
| 43 | ModelTargets.builtins | opEff_io | `ModelTargets.opEff_io` → `(ModelTargets.scopeConditions P hp).opEff_io` | 証明済み（実質） |
| 44 | ModelTargets.builtins | effect_ops | `ModelTargets.effect_ops` → `(ModelTargets.scopeConditions P hp).effect_ops` | 証明済み（実質） |
| 45 | ModelTargets.builtins | state_effect | `ModelTargets.state_effect` → `(ModelTargets.scopeConditions P hp).state_effect` | 証明済み（実質） |
| 46 | ModelTargets.builtins | ref_get | `ModelTargets.ref_get` → `(ModelTargets.scopeConditions P hp).ref_get` | 証明済み（実質） |
| 47 | ModelTargets.builtins | ref_set | `ModelTargets.ref_set` → `(ModelTargets.scopeConditions P hp).ref_set` | 証明済み（実質） |
| 48 | ModelTargets.builtins | store_shape | `ModelTargets.store_shape` → `(ModelTargets.scopeConditions P hp).store_shape` | 証明済み（実質） |
| 49 | ModelTargets.builtins | store_admits | `ModelTargets.store_admits` → `(ModelTargets.scopeConditions P hp).store_admits` | 証明済み（実質） |
| 50 | ModelTargets.builtins | io_target | `(ModelTargets.targetAgreement P).io_target` → `(ModelTargets.scopeConditions P hp).io_target` | 証明済み（実質） |
| 51 | ModelHttp.builtins | sat_rename | `(ModelHttp.substitutionAssumptions P).sat_rename` → `(ModelHttp.scopeConditions P hp).sat_rename` | 証明済み（実質） |
| 52 | ModelHttp.builtins | admits_rename | `(ModelHttp.substitutionAssumptions P).admits_rename` → `(ModelHttp.scopeConditions P hp).admits_rename` | 証明済み（実質） |
| 53 | ModelHttp.builtins | sat_values | `(ModelHttp.substitutionAssumptions P).sat_values` → `(ModelHttp.scopeConditions P hp).sat_values` | 証明済み（実質） |
| 54 | ModelHttp.builtins | admits_values | `(ModelHttp.substitutionAssumptions P).admits_values` → `(ModelHttp.scopeConditions P hp).admits_values` | 証明済み（実質） |
| 55 | ModelHttp.builtins | sat_renameTypes | `(ModelHttp.substitutionAssumptions P).sat_renameTypes` → `(ModelHttp.scopeConditions P hp).sat_renameTypes` | 証明済み（実質） |
| 56 | ModelHttp.builtins | admits_renameTypes | `(ModelHttp.substitutionAssumptions P).admits_renameTypes` → `(ModelHttp.scopeConditions P hp).admits_renameTypes` | 証明済み（実質） |
| 57 | ModelHttp.builtins | sat_subst | `(ModelHttp.substitutionAssumptions P).sat_subst` → `(ModelHttp.scopeConditions P hp).sat_subst` | 証明済み（実質） |
| 58 | ModelHttp.builtins | admits_subst | `(ModelHttp.substitutionAssumptions P).admits_subst` → `(ModelHttp.scopeConditions P hp).admits_subst` | 証明済み（実質） |
| 59 | ModelHttp.builtins | delta_typed | `ModelHttp.delta_typed` → `(ModelHttp.scopeConditions P hp).delta_typed` | 証明済み（実質） |
| 60 | ModelHttp.builtins | io_typed | `ModelHttp.io_typed` → `(ModelHttp.scopeConditions P hp).io_typed` | 証明済み（実質） |
| 61 | ModelHttp.builtins | io_kind | `ModelHttp.io_kind` → `(ModelHttp.scopeConditions P hp).io_kind` | 証明済み（実質） |
| 62 | ModelHttp.builtins | io_exists | `ModelHttp.io_exists` → `(ModelHttp.scopeConditions P hp).io_exists` | 証明済み（実質） |
| 63 | ModelHttp.builtins | sig_scoped | `ModelHttp.sig_scoped` → `(ModelHttp.scopeConditions P hp).sig_scoped` | 証明済み（実質） |
| 64 | ModelHttp.builtins | sat_unconstrained | `ModelHttp.sat_unconstrained` → `(ModelHttp.scopeConditions P hp).sat_unconstrained` | 証明済み（実質） |
| 65 | ModelHttp.builtins | admits_sat | `ModelHttp.admits_sat` → `(ModelHttp.scopeConditions P hp).admits_sat` | 証明済み（実質） |
| 66 | ModelHttp.builtins | pathBases_shape | `ModelHttp.pathBases_shape` → `(ModelHttp.scopeConditions P hp).pathBases_shape` | 証明済み（実質） |
| 67 | ModelHttp.builtins | io_op | `ModelHttp.io_op` → `(ModelHttp.scopeConditions P hp).io_op` | 証明済み（実質） |
| 68 | ModelHttp.builtins | opEff_io | `ModelHttp.opEff_io` → `(ModelHttp.scopeConditions P hp).opEff_io` | 証明済み（実質） |
| 69 | ModelHttp.builtins | effect_ops | `ModelHttp.effect_ops` → `(ModelHttp.scopeConditions P hp).effect_ops` | 証明済み（実質） |
| 70 | ModelHttp.builtins | state_effect | `ModelHttp.state_effect` → `(ModelHttp.scopeConditions P hp).state_effect` | 証明済み（実質） |
| 71 | ModelHttp.builtins | ref_get | `ModelHttp.ref_get` → `(ModelHttp.scopeConditions P hp).ref_get` | 証明済み（実質） |
| 72 | ModelHttp.builtins | ref_set | `ModelHttp.ref_set` → `(ModelHttp.scopeConditions P hp).ref_set` | 証明済み（実質） |
| 73 | ModelHttp.builtins | store_shape | `ModelHttp.store_shape` → `(ModelHttp.scopeConditions P hp).store_shape` | 証明済み（実質） |
| 74 | ModelHttp.builtins | store_admits | `ModelHttp.store_admits` → `(ModelHttp.scopeConditions P hp).store_admits` | 証明済み（実質） |
| 75 | ModelHttp.builtins | io_target | `(ModelHttp.targetAgreement P).io_target` → `(ModelHttp.scopeConditions P hp).io_target` | 証明済み（実質） |

判定は、[台本](l/vacuity.py)が群Jの75契約の全ての引数と前提を導入し、結論だけをFalseへ置き換えた目標に、同じ[前提矛盾の手順](l/premise-probe.lean)を適用して行った。直接の矛盾又は各モデルのsig_casesによる全lookupの分岐と署名のkindの簡約だけで閉じるかを調べた。閉じた6欄には前提からFalseを導く宣言を生成し、カーネルが検査した。手順で閉じないことだけでは実質と断定せず、本番の置換保存・到達するlookup枝・具体の表や応答の結論と、[群H](../reviews/RV-L50.h.md)・[群I](../reviews/RV-L50.i.md)・[群J](../reviews/RV-L50.j.md)の各判定を併せて確認した。

集計はModelが実質19・前提の否定で空疎6、ModelTargetsとModelHttpが各実質25・空疎0である。Modelのdelta_typed・io_typed・io_kind・io_exists・io_op・io_targetの6欄はpure/io/exitの署名がなく、ioResponseも空である。実際の純粋応答・IO応答の証拠はModelTargetsとModelHttpの該当欄にある。L50の担当として実質で閉じるべき欄の新たな未完は見つからなかった。

## L60へ残す12欄と具体の入口

各行は同じP/Bで `ModelScopeConditions.core` のexternal又はrelease引数へ渡す。三モデルの外部応答関係は空である。external_typed/no_targetsの全称命題が空疎に成り立ってもexternal_existsを代用しない。外部宣言・ExternalWF・型付きExternalArgsを持つPでは現在のexternal_existsは成り立たない。

| モデル | 残る欄 | 具体の入口・現在の制限 |
|---|---|---|
| Model | external_typed | `Builtins.ExternalAssumptions.external_typed`を同じP/Model.builtinsで束ね、`(Model.scopeConditions P).core external release`へ |
| Model | external_exists | `Builtins.ExternalAssumptions.external_exists`を同じP/Model.builtinsで束ね、`(Model.scopeConditions P).core external release`へ |
| Model | external_no_targets | `Builtins.ExternalAssumptions.external_no_targets`を同じP/Model.builtinsで束ね、`(Model.scopeConditions P).core external release`へ |
| Model | release_exists | `(Model.scopeConditions P).core external release`のrelease引数。isResource=falseで前提が偽、空疎 |
| ModelTargets | external_typed | `Builtins.ExternalAssumptions.external_typed`を同じP/ModelTargets.builtinsで束ね、`(ModelTargets.scopeConditions P hp).core external release`へ |
| ModelTargets | external_exists | `Builtins.ExternalAssumptions.external_exists`を同じP/ModelTargets.builtinsで束ね、`(ModelTargets.scopeConditions P hp).core external release`へ |
| ModelTargets | external_no_targets | `Builtins.ExternalAssumptions.external_no_targets`を同じP/ModelTargets.builtinsで束ね、`(ModelTargets.scopeConditions P hp).core external release`へ |
| ModelTargets | release_exists | `(ModelTargets.scopeConditions P hp).core external release`のrelease引数。File.Handleの前提は充足可能で、現在のreleaseResponseはr=noneのため `⟨none, rfl⟩` でこの欄自体を供給できる。通常資源の解放の実際の関係を表へ入れ、その関係での存在を証明する作業をL60に残す |
| ModelHttp | external_typed | `Builtins.ExternalAssumptions.external_typed`を同じP/ModelHttp.builtinsで束ね、`(ModelHttp.scopeConditions P hp).core external release`へ |
| ModelHttp | external_exists | `Builtins.ExternalAssumptions.external_exists`を同じP/ModelHttp.builtinsで束ね、`(ModelHttp.scopeConditions P hp).core external release`へ |
| ModelHttp | external_no_targets | `Builtins.ExternalAssumptions.external_no_targets`を同じP/ModelHttp.builtinsで束ね、`(ModelHttp.scopeConditions P hp).core external release`へ |
| ModelHttp | release_exists | `(ModelHttp.scopeConditions P hp).core external release`のrelease引数。isResource=falseで前提が偽、空疎 |

L60は計画された外部応答・通常資源の関係を実表へ接続する。[群J](j/handoffs.md)・[群K](k/l60-fields.md)の注意を保持し、空の表から任意Pの全Coreを構成しない。外部型の名目性、borrow/own/Stateと通常資源のreleaseは範囲IOの新葉と別に閉じる。

## 33義務の段別の証拠と残る段

前段はREADMEに従いL20/L30を2026-11-03、L40を2026-11-04に設計者が受け入れ済みとして継承する。次表はL50担当分の証拠であり、義務全体の閉鎖は0行である。完全名・所在・実型のSHA-256は[l/trace-part](l/trace-part-01.json)の分割記録にある。

機械照合の範囲は、名前の実在・所在・実型のSHA-256・読者の型と値の依存の再抽出の一致である。[reconcile.py](l/reconcile.py)は全場合の量化を判定しない。量化範囲の判断は[各群の独立レビューと64行の対応](l/coverage-judgments.json)を出どころとし、群A〜Kの群末レビュー（再レビュー・取りまとめの処置を含む）と[群Kのtrace](k/trace.json)、[RV-L50.kの情報7・33義務/31申し送り・再レビュー](../reviews/RV-L50.k.md)に基づく。「独立未完0」はこの判断の集計であり、定理名の存在から導いた数ではない。台本は各行の出典・元のstatus/findingとの一致と未完リストの欠落を拒み、リストの件数を集計する。全体の閉鎖と受け入れはこの集計に含めない。

| 義務 | 分類・今回の判定 | 実証の入口 | 残る段と具体の受け口 |
|---|---|---|---|
| O013 | 技術：担当分の証拠を照合。全体は未閉鎖 | `HasTypeVQ.target_member`、`Builtins.ShapeOk.single_target`、`ScopeModels.conditions` | L60：同じP/BのExternalAssumptions三欄とCoreAssumptions.release_existsをModelScopeConditions.coreへ供給する。三モデル12欄はl60-fields.md。 |
| O015 | 技術：担当分の証拠を照合。全体は未閉鎖 | `RangeExpr.Covers.mem`、`Pred.member_inst_mono`、`HasTypeVQ.target_member_interpret` | L60：各実表のCoreAssumptionsとTargetAgreementの合成。R50：対象path/host/endpointの所属・範囲具体化のRust/Lean比較。 |
| O016 | 共通：既定Benitoiteのimport閉包の監査完了。RV-L50.lとL50.59処置済み、受け入れ待ち | `ScopeModels.conditions`、`ModelScopeConditions.core` | 群L：既定環境の公理監査と定義・言明・仮定の独立レビュー。L60/L70：各段のレビュー結果をRust開始条件へ渡す。 |
| O022 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopeResponse.normal_facts`、`HasTypeVQ.target_member_interpret`、`ScopedIOResponse.target_member` | L60：同じ実δ/IOの正常値についてScopeResponse.normal_factsと対象所属を各実表へ合成。R50：同じ値の観測と所属の比較。 |
| O027 | 共通：固定メモリ設定を使用。正式RSSはレビュー後の取りまとめへ | `ScopeModels.conditions` | 群Lと各後段の限定採取：同じ最終workの本体と計測器の終了、正式RSSと機械・原単位を記録する。 |
| O034 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopeResponse.outcome_typed`、`ScopedIOResponse.io_typed`、`HasTypeVQ.target_member_interpret` | L60：対象所属のmachine_exact/stable/representedとOutcome.Typed/AdequateResultを各実表へ合成。R50：同じ対象の表現・観測の比較。 |
| O035 | 技術：担当分の証拠を照合。全体は未閉鎖 | `RequestDelta.response`、`RequestDelta.widenRequestIn_response`、`ScopedTargetExamples.request_io`、`ScopedTargetExamples.selected_request` | L60：要求の実δ/IOを全Coreへ。L70：関数・節の同じ要求を全到達へ合成。R30/R50：保持req・reqTarget・endpointの実装と比較。 |
| O036 | 技術：担当分の証拠を照合。全体は未閉鎖 | `Builtins.ShapeOk.single_target`、`Builtins.ShapeOk.single_request` | L70：全single入力のtarget?とshapeAtを実行のStepと表層の開始へ合成する。 |
| O038 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopedTargetInputs.response_inputs`、`ScopedTargetInputs.pure_steps`、`ScopedTargetInputs.io_steps`、`ScopedTargetInputs.handled_step` | L60：外部応答三条件と通常資源のrelease_exists。L70：StateTyEとStepの同じσ/Eb/μの全保存へ合成する。 |
| O044 | 記録：担当分の証拠を照合。全体は未閉鎖 | `HasTypeVQ.request_target`、`Detail.originals_unobserved`、`AtErrorReaders.check_reader` | D10：対象保持・groundValと旧Syntaxとの対照を公開文書へ。L70：新判断の規範と主定理の切替。 |
| O048 | 技術：担当分の証拠を照合。全体は未閉鎖 | `RangeExpr.Covers.mem`、`HasTypeVQ.widen_opaque`、`RequestDelta.widenRequestIn_response` | L60：同じ値の範囲拡大を実表へ。L70：関数・節へ合成。R30/R50：widenPathIn/widenRequestInの同じ保持値を実装・比較。 |
| O049 | 技術：担当分の証拠を照合。全体は未閉鎖 | `RequestDelta.response`、`RequestDelta.requestInValue_response`、`ModelHttp.sent_request` | L60：固定reqTarget/groundVal/valContentを全Coreへ。R30/R50：checkRequestIn→requestInValue→Http.sendInの同じ要求を実装・比較。 |
| O057 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopedTargetInputs.pure_steps`、`ScopedTargetInputs.io_steps`、`ScopedTargetInputs.at_steps` | L60：external_exists/release_exists。L70：At三分岐・発行・実IOの存在をprogressの全開始へ合成する。正常応答の存在を要求しない。 |
| O058 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopedCallContracts.single_inputs`、`ScopedTargetInputs.response_inputs` | L60：各実表の応答条件。L70：同じBuiltinArgsの依存結果/効果と全応答をpreservationへ合成する。 |
| O059 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopedTargetInputs.response_inputs`、`StateTyE.selected_primitive_step` | L60：実表の応答存在と選択。L70：selected_primitive_stepとAt全分岐をstep_soundへ合成する。逆方向の完全性は要求しない。 |
| O060 | 技術：担当分の証拠を照合。全体は未閉鎖 | `Builtins.CoreAssumptions.io_event_covered`、`Builtins.CoreAssumptions.pathBases_event_covered`、`Eff.Covers.allows`、`Builtins.TargetAgreement.obs_allowed` | L60：同じeffects表の事象被覆を全Coreへ。L70：呼出し効果から末尾Ebへの伝播をeffect_soundness/noLamNamesへ合成する。 |
| O061 | 技術：担当分の証拠を照合。全体は未閉鎖 | `Builtins.TargetAgreement.obs_allowed`、`ScopedIOResponse.target_member` | L60：ExternalAssumptions.external_no_targets。L70：同じσ/対象の一段のEff.Allowsを全到達と表層へ合成する。 |
| O062 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopeResponse.delta_typed`、`ModelTargets.pure_response`、`ModelHttp.pure_response` | L60：純粋6範囲APIの全BuiltinArgsについて、同じδのOutcome.Typed/AdequateResult/非exitを全実表のResponseAssumptionsへ組み込む。 |
| O063 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopedIOResponse.response`、`ModelTargets.io_exists`、`ModelHttp.io_exists` | L60：IO7本と各モデルのio_typed/io_kind/io_existsをCoreAssumptionsへ組み込む。externalの三条件と分ける。 |
| O065 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopeSignatures.sig_scoped`、`ModelConstraints.sat_subst`、`ModelConstraints.admits_subst`、`ScopeModels.conditions` | L60：同じPのarity/sourceTelRows/sig_scoped/八保存則を標準全表へ。L70：この実表で新判断へ切り替える。 |
| O074 | 他段：担当分の証拠を照合。全体は未閉鎖 | `ScopedCallContracts.single_inputs`、`ScopedTargetExamples.single_io`、`ScopedTargetExamples.incomparable` | R10b/R30：PrimitiveAdmissible/RangeAdmissible/SignatureInstanceへ直接・明示拡大・関数値・Top・比較不能の実入力を渡し、一度だけ範囲を具体化する。 |
| O082 | 技術：担当分の証拠を照合。全体は未閉鎖 | `TargetInput.resolve`、`RangeExpr.resolve`、`ScopedTargetExamples.equal_resolution_distinct_base` | R30/R70：scripts下・別cwd・run .の起動時rootと動的cwdの設定/CLI照合（src/cli/）。D10：起動形の公開文書。 |
| O084 | 共通：各群末レビューとtraceの判断による技術的独立未完0。受け入れは未実施 | `ScopeModels.conditions`、`ModelScopeConditions.core` | 群L：L50独立未完と他段所有を分けて段末レビュー。L60/L70/R/K/V：各合成・比較・受け入れ記録へ渡す。 |
| O092 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopedTargetExamples.secrets_members`、`RangeExpr.Covers.mem` | R30/R70：src/cli/のsecrets単独名・接尾辞・空/非空混在の拒否と起動側の一覧管理。所属成功を許可/分類解除に使わない。 |
| O096 | 技術：担当分の証拠を照合。全体は未閉鎖 | `PathEnv.Ready.resolve_required`、`InitialPrepared.source_state_of_source`、`AtPrepared.current` | R30：Source由来の必要束縛・PathBases発行・AtとFile6本/Httpへ同じ固定σを供給する。work/tmpの実在・管理、heap/stress構成で照合する。 |
| O097 | 技術：担当分の証拠を照合。全体は未閉鎖 | `AtError.save_exact`、`AtPrepare.error_saved`、`AtErrorReaders.check_reader`、`Detail.originals_unobserved` | U02確定後・L70前：Detail九欄からResultShape.Declared/Program.StandardErrorCompleteと公開宣言・観測・照合・網羅性へ写す。生Valを取り出すならVal.AdequateのatError枝を再点検。R30/R60：構成子・文言・Show。 |
| O118 | 共通：写し・コメント・全既定importを照合。後段の全読者は未実施 | `ScopeModels.conditions`、`AtErrorReaders.observed` | L70：01-12/07-04と全開始・主定理の写し。R50/R60：交換/診断、D10：公開文書、V10：実CLIまで同じ契約を照合する。 |
| O141 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopedTargetExamples.single_io`、`ScopedTargetExamples.request_io`、`ScopedTargetExamples.selected_request` | L70：U1全7位置の値の流れと保存の合成。R10b/R30：一度の添字具体化、R50：比較、R60/V10：公開入力と実CLI。 |
| O144 | 技術：担当分の証拠を照合。全体は未閉鎖 | `Pred.member_inst_mono`、`ScopeResponse.normal_facts`、`ScopedIOResponse.target_member` | R20/R10b/R40：対象3sortと論理/true/空篩の検査・推論・診断。R50/V10：同じ値の対象所属の全比較と実CLI。 |
| O156 | 記録：担当分の証拠を照合。全体は未閉鎖 | `Builtins.TargetAgreement.obs_allowed`、`ScopedTargetExamples.equal_resolution_distinct_base` | D10：00-01とAGENTS公開要約の静的上限・check/run・IFCの二文書。V10：実CLIでcheckの観測値とrunの固定値の区別を照合する。 |
| O165 | 技術：担当分の証拠を照合。全体は未閉鎖 | `RangeExpr.Covers.mem`、`ScopedTargetExamples.equal_resolution_distinct_base` | R10b/R30：src/typeck/scoped_calls.rs等の被覆判定で異なる起点を同じ解決先から同一視しない。R50/V10：同一起点の受理と起点差の拒否を比較・実CLI照合。 |
| O166 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopeLegacyContracts.relative_rejected`、`ScopeLegacyContracts.absolute_input`、`ScopeDelta.input_errors` | R30：src/builtins/funcs/scope.rsの旧純粋チェックとbases明示At。R40：拒否診断、D10：移行説明、V10：相対/home形の明示Errorと絶対射影のCLI照合。 |
| O168 | 技術：担当分の証拠を照合。全体は未閉鎖 | `ScopedTargetExamples.equal_resolution_distinct_base`、`ScopedTargetExamples.split_endpoint`、`PathEnv.Ready.resolve_required`、`AtPrepare.error_saved` | L60：externalの名目性。R30/R50/R60/R70/D10/V10：denials.mdのDET-R01〜26の字句・CLI・交換・公開診断・文書・実CLIを各所有で照合する。 |

O016/O084の段末独立レビューとL50.59、O027の正式な最終work/RSSは今回の担当を完了したことと区別する。O118の今回の写し・コメント照合は完了した。これらの既知の未実施を、新たに発見した証明の独立未完として後段へ付け替えていない。

## 31申し送りの一行ずつの照合

| 受け口 | 分類・L50の証拠 | 実際の入口 | 残る所有と受け口 |
|---|---|---|---|
| H01 | 継承：芯の対応とfacts、appの二規則と形成付きの元列を継承する。 | `HasTypeVQ.canonical_held`、`StateTyE.app_inputs` | L70：HasTypeVQの芯の対応・factsと形成付きapp_telを全開始へ合成する。撤回した元型全体のLeQを再採用しない。 |
| H02 | 継承：Ctx.WFと元列のAnnotationは既存の供給元を使い、除去済みの四前提を戻さない。 | `TelClosure.apply`、`StateTyE.primitive_contract_inputs` | L60/L70：TelClosure.applyの同じ実署名にCtx.WFと元列Annotationを実開始から供給する。除去済み四前提を戻さない。 |
| H03 | 継承：同じδ・正常値・toTerm?からのfactsを継承する。 | `ScopeResponse.normal_facts`、`ModelHttp.normal_facts`、`ModelTargets.normal_facts` | L60：同じ実δの正常応答とtoTerm?の等号からnormal_factsへ。L70：全実行へ合成する。 |
| H04 | 技術：要求の二保持形と同じ内容型・reqTarget・endpointを全位置の実応答へ渡す。 | `RequestDelta.response`、`RequestDelta.widenRequestIn_response`、`ScopedTargetExamples.request_io`、`ScopedTargetExamples.selected_request` | L60/L70：同じ保持対象・req・endpointと全σの所属を実表・全実行へ。R30/R50：拡大・関数・節・全IOの同じ値を実装・比較。 |
| H05 | 技術：篩付きPairを含む五欄要求の二保持形と同じ端点を継承する。根の射影形拒否は群E再開1を維持する。 | `HasTypeVQ.request_target`、`RequestDelta.response`、`ModelHttp.sent_request` | R30/R50：Pair[String{true},String]等の同じ型付き要求をAt→射影→Http.sendInへ通す実入力と比較。 |
| H06 | 技術：同じPの全署名のSourceScoped/RowsInを使う。 | `ScopeSignatures.sourceTelRows`、`ModelTargets.sourceTelRows`、`ModelHttp.sourceTelRows`、`TargetTable.content_rows` | L60：残りの実表にSourceScoped/RowsIn/sourceTelRowsを供給。L70/R10b：同じ閉じた内容型の行支持をソース生成へ渡す。 |
| H07 | 技術：sat=Trueへ戻さず、任意Ψ/非Topを含む実75欄を読む。 | `ScopeModels.conditions`、`Model.scopeConditions`、`ModelTargets.scopeConditions`、`ModelHttp.scopeConditions` | L60：三モデル75欄をModelScopeConditions.coreへ渡し、外部三欄と通常資源release_existsを組み合わせて全Coreを構成する。 |
| H08 | 技術：必要束縛と初期準備、動的未束縛Errorを分離する。Readyを全状態へ追加しない。 | `PathEnv.Ready.resolve_required`、`InitialPrepared.source_state_of_source` | L70：Ready/InitialPrepared.source_stateを初期表層と全到達へ接続する。Readyを全状態の新不変条件にしない。 |
| H09 | 技術：値の四保存則はFailの順序・長さ・重複を読まない骨格から得る。 | `ModelConstraints.sat_rename`、`ModelConstraints.admits_rename`、`ModelConstraints.sat_values`、`ModelConstraints.admits_values` | L60：ValueAssumptionsのsat_rename/admits_rename/sat_values/admits_valuesを各実表の全Coreへ再利用する。 |
| H10 | 技術：一般のTypeParamRenamingとSatAllを継承し、独立のsat_localを加えない。 | `ModelConstraints.sat_renameTypes`、`ModelConstraints.admits_renameTypes`、`ModelConstraints.sat_subst`、`ModelConstraints.admits_subst` | L60：TypeParamRenamingと型像・行像を含むTypeAssumptions四保存則を全Coreへ再利用する。 |
| H11 | 技術：発行八欄と同じProcess.Environment所属を使う。 | `ScopeSignatures.pathBases_shape`、`Builtins.CoreAssumptions.pathBases_membership` | L70：PathBasesShapeと同じeffectsのmembershipをeffect_soundnessへ。R30：Process.Environment事象を伴う実発行へ。 |
| H12 | 技術：opaque署名とscoped_forgetを維持する。 | `Builtins.ShapeOk.single_target`、`ScopeSignatures.io_op` | L60：ShapeOk.singleのopaque (rvar 0)署名へscoped_forgetした同じ値を供給し、実表を合成する。 |
| H13 | 技術：同じ有限PのResult/Pairのarity2と全lookupを継承する。 | `ScopeDeclarations.program_hasHttp`、`ScopeDeclarations.program_wellFormed`、`ScopeSignatures.sig_scoped` | L60：標準全表で同じPの有限宣言からResult/Pair/Request/Errorのarity・kind・PrimSig.Scopedを供給する。 |
| H14 | 技術：全有効σのAdequateResultを同じ応答から読む。外部条件と分離する。 | `ScopeResponse.delta_typed`、`ScopedIOResponse.response`、`AtTargets.adequate_atError` | L60：externalCheckedOutcomeと外部応答の三条件から適格性を得る。δ/IOのAdequateResultの証拠で代用しない。 |
| H15 | 技術：非Top→Top→opaqueと同じ値の逆転を継承。別範囲の拒否と要求なしRequestの拒否を分ける。 | `HasTypeVQ.widen_opaque`、`ScopedTargetExamples.widened_input`、`HasTypeVQ.target_member` | R30/R50：非Top→Top→opaqueのPathIn保持値の受理と、要求なしRequestInの拒否を同じ入力表で比較する。 |
| H16 | 技術：PathIn/pathとRequestIn/endpoint、内容型の同じ分類を使う。 | `TargetTable.valKind`、`TargetTable.request_content` | L60/R30：TargetTable.valKindのPathIn/path・RequestIn/endpointとvalContentを同じ実表で照合する。 |
| H17 | 継承：既済み三接続を継承し、新規補題数へ加えない。 | `AtPrepared.request`、`Val.reqTarget_kind`、`checkAt.absolute` | 追加の未完なし。AtPrepared.request/Val.reqTarget_kind/checkAt.absoluteの既存入口を継承し、At成功値を重複実装しない。 |
| H18 | 継承：全幅facts・List要素factsの既済み処置を継承し、内部エラーの読者を照合する。 | `HasTypeVQ.data_observation`、`Detail.match_pattern_typed` | 公開形の対応以外の再実装なし。U02後の公開写しでAtErrorの専用逆転と観測・照合を同じPへ対応させる。 |
| H19 | 技術：同じ値の対象3sortを観測・所属・具体応答へ渡す。 | `HasTypeVQ.target_member_interpret`、`Pred.member_inst_mono`、`ScopeResponse.normal_facts` | L60：対象3sortの観測・所属・具体化を同じ実δへ。R50：同じ値の二つのlength観測と実δを比較する。非対象13sortは既済み。 |
| H20 | 技術：20等号と全失敗・内部観測・適格性を照合する。公開写しはU02後である。 | `AtError.save_exact`、`AtPrepare.error_saved`、`AtErrorReaders.check_reader`、`Detail.originals_unobserved` | R30/R60/L70：Detail九欄から公開shape/readerへ写す。未解析の元入力は保持し、Show・reprStrと保存値を分ける。U02の選択は本群で行わない。 |
| H21 | 技術：同じP.cons/Term/照合/網羅性を保ち、公開表への一致はU02後へ渡す。 | `Detail.match_pattern_typed`、`Exhaustive.atError`、`AtErrorReaders.observed` | U02確定後・L70前：ResultShape.Declared/Program.StandardErrorCompleteと同じP.cons/Term/RuntimeMatch/Exhaustiveの公開写し。R60：全表層の観測・照合。生Valを返すならatError適格性を再点検する。 |
| H22 | 技術：型/行像・範囲具体化・値のbindの正規化を維持する。 | `Eff.allows_bind_comp`、`ScopedCallContracts.single_inputs`、`HasTypeVsQ.widen_covers` | L70：主定理の閉鎖に範囲具体化・型/行像・継続Rの同じ正規化済みbindを使う。L20の一般交換を継承する。 |
| H23 | 技術：Sourceからの直接生成の排除と、発行した同じσをAtへ渡す経路を継承する。 | `Val.Source`、`Val.SourceScoped`、`InitialPrepared.source_state_of_source`、`ModelTargetsExamples.issue_to_at` | R30/R50：record/JSON/外部からPathBasesを偽造する入力の拒否と、正規の発行→同じσのAtの比較。 |
| H24 | 技術：局所証拠を主定理や全Coreの閉鎖へ繰り上げない。L40の演算子/decoderを再移管しない。 | `ScopeModels.conditions`、`ScopedTargetInputs.response_inputs` | L60/L70/R50：O022/O034/O062/O065/O144の対象と実表を合成・比較する。L40の局所証拠を全体閉鎖へ繰り上げない。 |
| H25 | 技術：同じ有限宣言とcarrier/satBの骨格を継承する。 | `ScopeDeclarations.program_hasHttp`、`ModelConstraints.sat_subst`、`ScopeModels.conditions` | L60/L70/R10b/R50：同じPとsummary/satB/KeyObservationで標準全表を収集し、ソース生成・全比較へ接続する。 |
| H26 | 技術：捕捉内部の場所番号を観測できる既存契約を維持し、精密外部状態や新しい不変条件を足さない。 | `CaptureReadBoundary.primitive_reads_hidden_capture`、`CaptureReadBoundary.hidden_capture_reply_states` | R50：CaptureReadBoundaryでδが読まない捕捉の場所番号と、Rustが閉包内部を観測しない差を比較する。新しい不変条件は足さない。 |
| H27 | 他段：外部3欄＋release1欄を各モデルへ残す。空疎・noneの証人・空の外部関係の注意を12欄表に保持する。 | `ScopeModels.conditions`、`ModelScopeConditions.core`、`Builtins.ExternalAssumptions.external_exists` | L60：通常資源の任意の型付き値からCoreAssumptions.release_existsを供給し、外部三条件と全Coreへ束ねる。範囲IOの新葉とは分ける。 |
| H28 | 技術：任意Ψ・全適格σ・全入力を保ち、Top/空ストアへの縮小をしない。 | `HasTypeVQ.target_member`、`Builtins.ShapeOk.single_target`、`ScopedTargetInputs.response_inputs` | L70/R50：任意Ψ・全適格σと新F3受理を保ち、全開始・全応答の合成とRust/Lean比較へ接続する。 |
| H29 | 技術：File6本とsendを外部応答から分離し、同じ関係の応答存在を保存へ渡す。 | `ScopedIOResponse.response`、`ModelHttp.send_response`、`ModelTargets.io_exists` | L60：borrow/own/Stateの通常資源とexternalResponse。R30：File6本/Http.sendInの実IO・Atへ同じ固定σを供給する。 |
| H30 | 他段：局所Leanの成功をRust/Lean全比較や全表一致と呼ばない。 | `ScopeModels.conditions`、`StateTyE.selected_primitive_step` | R50/F-CONN：有限交換表と上層の証明の照合。L70/F-REG：既存コーパスの全比較。局所Lean/raw再生から全表一致としない。 |
| H31 | 技術：前段の9行を全有効σの証拠へ対応し、外部応答の充足と分離する。 | `RangeExpr.Covers.mem`、`HasTypeVQ.target_member`、`ScopeResponse.adequate_externalRef`、`ScopeResponse.adequate_externalHandle`、`ScopeResponse.adequate_scopePattern`、`AtTargets.adequate_atError` | L60：externalRef/externalHandle等の外部応答全条件。L70：全有効σのAdequateResultを主定理と公開写しへ。元入力を公開するならatErrorの適格性を再点検する。 |

義務・申し送り64行の読者は型と値の依存から再抽出した。**依存する読者あり49、証拠そのものが入口8、同じ前提を共有するだけ4、記録・監査の関係3**である。49行のうち33行は、証拠の一部だけに名前付きの読者がある。各行の証拠全部へ読者があるという意味ではない。証拠ごとの経路とprivateの読者は[k/reader-dependencies](k/reader-dependencies.json)と一致し、同じ80672節点の抽出を再検査した。無名の適用例は名前付きの読者へ数えない。

## F01〜F10の実際の完全署名と定義形

以下は同じ監査の型印字から名前空間の共通の接頭辞だけを省いたものである。量化・暗黙引数・前提・結論を省かない。`open Benitoite`・`open Benitoite.Release`を置いた `namespace Benitoite.Release.Refinement` の中で読む。全名を展開した1856実署名は[l/signatures-part](l/signatures-part-01.md)の分割記録、定義の本体・構造体の全欄は[l/definitions](l/definitions.md)にある。

### F01

所在: [PathPattern.covers_atBase](../../../formal/Benitoite/Release/Refinement/ScopeCoverage.lean)（行9）。

```lean
PathPattern.covers_atBase :
∀ (w : Scope.Domain.Word) {p q : Scope.Domain.PathPattern},
  p.Covers q →
    (PathPattern.atBase w p).Covers (PathPattern.atBase w q)
```

所在: [RangeExpr.Covers.mem](../../../formal/Benitoite/Release/Refinement/ScopeCoverage.lean)（行41）。

```lean
RangeExpr.Covers.mem :
∀ {outer inner : RangeExpr},
  outer.Covers inner →
    ∀ (σ : PathEnv) {k : Scope.Domain.Kind} {t : Scope.Domain.Target},
      RangeExpr.Mem σ k inner t → RangeExpr.Mem σ k outer t
```

所在: [SnapshotMem.mono](../../../formal/Benitoite/Release/Refinement/ScopeCoverage.lean)（行71）。

```lean
SnapshotMem.mono :
∀ {snapshot : Option PathEnv} {k : Scope.Domain.Kind}
  {r s : RangeExpr} {t : Scope.Domain.Target},
  SnapshotMem snapshot k r t →
    s.Covers r → SnapshotMem snapshot k s t
```

### F02

所在: [Eff.Allows](../../../formal/Benitoite/Release/Refinement/EffectFacts.lean)（行9）。

```lean
Eff.Allows :
PathEnv →
  (Release.EffName → Option Scope.Domain.Kind) →
    Eff → Release.EffName → Scope.Domain.Target → Prop
```

所在: [Eff.Covers.allows](../../../formal/Benitoite/Release/Refinement/EffectTargets.lean)（行75）。

```lean
Eff.Covers.allows :
∀ {Γ : Ctx} {Φ : List Pred}
  {e f : Eff} {σ : PathEnv}
  {κ : Release.EffName → Option Scope.Domain.Kind} {l : Release.EffName}
  {t : Scope.Domain.Target},
  Eff.Covers Γ Φ e f →
    Eff.Allows σ κ f l t → Eff.Allows σ κ e l t
```

Eff.Allowsの定義はEffectFactsに一つだけあり、対象の種類と同名の固定範囲原子の所属から同じσのMemを要求する。静的Coversにはσを足さない。

### F03

所在: [HasTypeVQ.target_member](../../../formal/Benitoite/Release/Refinement/MembershipTargets.lean)（行18）。

```lean
HasTypeVQ.target_member :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {Q : Release.NoFailCtx} {v : Val}
  {T : Ty} {o : Release.OpaqueName} {k : Scope.Domain.Kind}
  {r : RangeExpr} {σ : PathEnv},
  HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o k (RangeIx.fixed r) →
      B.valKind o = Option.some k →
        Val.Adequate σ v →
          ∃ t, v.target? = Option.some t ∧ RangeExpr.Mem σ k r t
```

所在: [HasTypeVQ.request_target](../../../formal/Benitoite/Release/Refinement/MembershipTargets.lean)（行152）。

```lean
HasTypeVQ.request_target :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {Q : Release.NoFailCtx} {v : Val}
  {T : Ty} {o : Release.OpaqueName} {r : RangeExpr}
  {σ : PathEnv} {A : Ty},
  HasTypeVQ P B Ψ Q [] [] [] v T →
    T.Holds o Scope.Domain.Kind.endpoint (RangeIx.fixed r) →
      B.valKind o = Option.some Scope.Domain.Kind.endpoint →
        B.valContent o = Option.some A →
          Val.Adequate σ v →
            ∃ target req,
              (v = Val.checkedRequest target req ∨
                  ∃ s snapshot, v = Val.checkedAt s snapshot target (Option.some req)) ∧
                ModelHttp.valueRun [v] = Outcome.val req ∧
                  HasTypeV P B Ψ [] [] [] req A.norm ∧
                    groundVal req = Bool.true ∧
                      req.reqTarget = Option.some target ∧
                        RangeExpr.Mem σ Scope.Domain.Kind.endpoint r target
```

### F04

所在: [Builtins.ShapeOk.single_target](../../../formal/Benitoite/Release/Refinement/ShapeTargets.lean)（行145）。

```lean
Builtins.ShapeOk.single_target :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff} {k : Scope.Domain.Kind} {p : Nat}
  {σ : PathEnv},
  B.ShapeOk b sg →
    sg.shape = Scope.Signature.IOShape.single k p →
      NamesWF sg.names sg.params →
        BuiltinArgs P B Ψ b sg ts es rs ws a e →
          (∀ (w : Val), w ∈ ws → Val.Adequate σ w) →
            ∃ r t,
              rs = [r] ∧
                ws[p]?.bind Val.target? = Option.some t ∧
                  RangeExpr.Mem σ k r t ∧
                    sg.shapeAt ws = Scope.Signature.IOShape.single k p
```

所在: [PrimSig.Scoped.namesWF](../../../formal/Benitoite/Release/Refinement/ShapeTargets.lean)（行55）。

```lean
PrimSig.Scoped.namesWF :
∀ {P : Program} {sg : PrimSig},
  PrimSig.Scoped P sg → NamesWF sg.names sg.params
```

NamesWFはplanで承認した追加前提であり、実表のPrimSig.Scoped.namesWFから供給する。任意の位置pを量化する。

### F05

所在: [Builtins.TargetAgreement.obs_allowed](../../../formal/Benitoite/Release/Refinement/EffectTargets.lean)（行265）。

```lean
Builtins.TargetAgreement.obs_allowed :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff} {out : Outcome}
  {obs : List Scope.Domain.Target} {σ : PathEnv},
  B.ShapeOk b sg →
    Builtins.TargetAgreement P B →
      B.sig b = Option.some sg →
        sg.kind = PrimKind.io ∨ sg.kind = PrimKind.exit →
          NamesWF sg.names sg.params →
            BuiltinArgs P B Ψ b sg ts es rs ws a e →
              (∀ (w : Val), w ∈ ws → Val.Adequate σ w) →
                B.ioResponse b ts es ws out obs →
                  ∃ l,
                    sg.opEff = Option.some l ∧
                      ∀ (t : Scope.Domain.Target),
                        t ∈ obs → Eff.Allows σ B.effKind e l t
```

### F06

所在: [PathEnv.Ready.resolve_required](../../../formal/Benitoite/Release/Refinement/PreparationTargets.lean)（行7）。

```lean
PathEnv.Ready.resolve_required :
∀ {P : Program} {B : Builtins}
  {σ : PathEnv} {s : State}
  {r : RangeExpr},
  PathEnv.Ready P B σ s →
    PreparationNode.Reachable P B (PreparationNode.state s)
        (PreparationNode.range r) →
      ∃ rs, RangeExpr.resolve σ r = Option.some rs
```

所在: [AtPrepared.current](../../../formal/Benitoite/Release/Refinement/PathBasesTargets.lean)（行7）。

```lean
AtPrepared.current :
∀ {B : Builtins} {σ : PathEnv}
  {cap : Capture} {kind : Scope.Domain.Kind}
  {name : Release.OpaqueName} {bs : Option Val}
  {p v : Val} {ix : RangeIx}
  {snap : Option PathEnv} {pat : RangeExpr}
  {t : TargetInput} {bound : RangeExpr},
  Capture.Adequate σ cap →
    (∀ (b : Val), bs = Option.some b → Val.Adequate σ b) →
      AtPrepared B cap kind name bs p v ix snap pat t bound →
        ∀ (ρ : PathEnv), snap = Option.some ρ → ρ = σ
```

所在: [StateTyE.at_step](../../../formal/Benitoite/Release/Refinement/AtTargets.lean)（行51）。

```lean
StateTyE.at_step :
∀ {P : Program} {B : Builtins}
  {σ : PathEnv} {Eb : Eff}
  {q : Closure} {k : Cont}
  {μ : Store} {kind : Scope.Domain.Kind} {name : Release.OpaqueName}
  {shape : ResultShape} {bases : Option Val}
  {pattern input : Val} {index : RangeIx},
  P.WellFormed →
    P.WellTyped B →
      Builtins.CoreAssumptions P B →
        σ.Valid →
          StateTyE P B σ Eb (State.run q k μ) →
            q.code = Comp.checkAt kind name shape bases pattern input index →
              ∃ next,
                Step P B σ (State.run q k μ) Option.none
                    next ∧
                  StateTyE P B σ Eb next
```

所在: [InitialPrepared.source_state_of_source](../../../formal/Benitoite/Release/Refinement/PreparationTargets.lean)（行89）。

```lean
InitialPrepared.source_state_of_source :
∀ {P : Program} {B : Builtins}
  {σ : PathEnv} {m : Comp}
  {a : Ty} {e : Eff},
  InitialPrepared P B σ
      (State.run (Closure.pure m) []
        Store.empty) →
    P.ExternalWF →
      HasTypeC P B StoreTy.empty [] [] [] Option.none m a e →
        Ty.Annotation P [] []
            (Ty.dependentFn (Tel.done a e)) →
          Comp.ClosedAt 0 0 m →
            m.Source →
              BuiltinOnly P B e →
                StateTy P B σ
                    (State.run (Closure.pure m) []
                      Store.empty) ∧
                  PathEnv.Ready P B σ
                      (State.run (Closure.pure m) []
                        Store.empty) ∧
                    P.ExternalWF
```

AtPrepared.currentはCaptureOkを要求しない。元状態の閉包・basesの適格性から供給する。Readyを全状態の新たな前提にしない。

### F07

所在: [ScopeResponse.delta_typed](../../../formal/Benitoite/Release/Refinement/ScopeResponse.lean)（行47）。

```lean
ScopeResponse.delta_typed :
∀ {P : Program}
  {io :
    Release.PrimName →
      List Ty →
        List Eff →
          List Val →
            Outcome → List Scope.Domain.Target → Prop}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff},
  ScopeDeclarations.HasHttp P →
    (ScopeSignatures.builtins ScopeResponse.delta io).sig b =
        Option.some sg →
      sg.kind = PrimKind.pure →
        BuiltinArgs P
            (ScopeSignatures.builtins ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          ∃ out,
            (ScopeSignatures.builtins ScopeResponse.delta
                      io).delta
                  b ts es rs ws =
                Option.some out ∧
              (∀ (n : Int), out ≠ Outcome.exit n) ∧
                Outcome.Typed P
                    (ScopeSignatures.builtins
                      ScopeResponse.delta io)
                    Ψ out a ∧
                  AdequateResult ws out
```

所在: [ScopeResponse.outcome_typed](../../../formal/Benitoite/Release/Refinement/ScopeResponse.lean)（行69）。

```lean
ScopeResponse.outcome_typed :
∀ {P : Program}
  {io :
    Release.PrimName →
      List Ty →
        List Eff →
          List Val →
            Outcome → List Scope.Domain.Target → Prop}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff} {out : Outcome},
  ScopeDeclarations.HasHttp P →
    (ScopeSignatures.builtins ScopeResponse.delta io).sig b =
        Option.some sg →
      sg.kind = PrimKind.pure →
        BuiltinArgs P
            (ScopeSignatures.builtins ScopeResponse.delta io)
            Ψ b sg ts es rs ws a e →
          ScopeResponse.delta b ts es rs ws = Option.some out →
            Outcome.Typed P
                (ScopeSignatures.builtins ScopeResponse.delta
                  io)
                Ψ out a ∧
              AdequateResult ws out ∧
                ∀ (n : Int), out ≠ Outcome.exit n
```

所在: [ScopedIOResponse.response](../../../formal/Benitoite/Release/Refinement/ScopedIOResponse.lean)（行348）。

```lean
ScopedIOResponse.response :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff},
  ScopeDeclarations.HasFile P →
    List.lookup b ScopeSignatures.entries = Option.some sg →
      sg.kind = PrimKind.io ∨ sg.kind = PrimKind.exit →
        B.valKind "Scope.PathIn" = Option.some Scope.Domain.Kind.path →
          B.valKind "Http.RequestIn" = Option.some Scope.Domain.Kind.endpoint →
            B.valContent "Http.RequestIn" = Option.some ScopeSignatures.clientRequestTy →
              B.valKind "IOError" = Option.none ∧ B.valContent "IOError" = Option.none →
                B.valKind "Http.Response" = Option.none ∧ B.valContent "Http.Response" = Option.none →
                  B.valKind "NetworkError" = Option.none ∧ B.valContent "NetworkError" = Option.none →
                    BuiltinArgs P B Ψ b sg ts es rs ws a e →
                      (∀ (out : Outcome) (obs : List Scope.Domain.Target),
                          ScopedIOResponse.ioResponse b ts es ws out obs →
                            Outcome.Typed P B Ψ out a ∧
                              AdequateResult ws out ∧
                                (∀ (n : Int), out ≠ Outcome.exit n) ∧
                                  Scope.Signature.ShapeTargets Val.target?
                                    (sg.shapeAt ws) ws obs) ∧
                        ∃ out obs, ScopedIOResponse.ioResponse b ts es ws out obs
```

所在: [ScopedIOResponse.io_exists](../../../formal/Benitoite/Release/Refinement/ScopedIOResponse.lean)（行438）。

```lean
ScopedIOResponse.io_exists :
∀ {P : Program}
  {delta :
    Release.PrimName →
      List Ty →
        List Eff →
          List RangeExpr →
            List Val → Option Outcome}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff},
  ScopeDeclarations.HasFile P →
    (ScopeSignatures.builtins delta
              ScopedIOResponse.ioResponse).sig
          b =
        Option.some sg →
      sg.kind = PrimKind.io ∨ sg.kind = PrimKind.exit →
        BuiltinArgs P
            (ScopeSignatures.builtins delta
              ScopedIOResponse.ioResponse)
            Ψ b sg ts es rs ws a e →
          ∃ out obs,
            (ScopeSignatures.builtins delta
                  ScopedIOResponse.ioResponse).ioResponse
              b ts es ws out obs
```

所在: [ScopeResponse.adequate_externalRef](../../../formal/Benitoite/Release/Refinement/ScopeResponse.lean)（行84）。

```lean
ScopeResponse.adequate_externalRef :
∀ (id : ExternalFunctionId) (ts : List Ty)
  (ws : List Val),
  AdequateResult ws
    (Outcome.val (Val.externalRef id ts))
```

所在: [ScopeResponse.adequate_externalHandle](../../../formal/Benitoite/Release/Refinement/ScopeResponse.lean)（行88）。

```lean
ScopeResponse.adequate_externalHandle :
∀ (h : ExternalHandle) (ts : List Ty)
  (ws : List Val),
  AdequateResult ws
    (Outcome.val (Val.externalHandle h ts))
```

所在: [ScopeResponse.adequate_scopePattern](../../../formal/Benitoite/Release/Refinement/ScopeResponse.lean)（行91）。

```lean
ScopeResponse.adequate_scopePattern :
∀ (r : RangeExpr) (ws : List Val),
  AdequateResult ws
    (Outcome.val (Val.scopePattern r))
```

所在: [AtTargets.adequate_atError](../../../formal/Benitoite/Release/Refinement/AtTargets.lean)（行71）。

```lean
AtTargets.adequate_atError :
∀ (detail : AtError) (ws : List Val),
  AdequateResult ws
    (Outcome.val (Val.atError detail))
```

純粋六行・IO七行の各実名の完全型も署名分割記録へ保存した。ScopeResponseの同じ決定的δの存在と全応答、ScopedIOResponseの同じ関係の全応答と存在を区別する。正常成功の存在は要求しない。

### F08

所在: [ScopedCallContracts.single_inputs](../../../formal/Benitoite/Release/Refinement/ScopedCallContracts.lean)（行11）。

```lean
ScopedCallContracts.single_inputs :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff} {k : Scope.Domain.Kind} {p : Nat}
  {σ : PathEnv} {u : Tel},
  PrimitiveAdmissible [] 0 sg Release.Qempty ts es →
    B.RangeAdmissible b sg rs →
      SignatureInstance P [] [] (Tel.instR rs sg.tel)
          (List.map TParamDecl.kind sg.tparams) ts es →
        TelClosure P [] []
            (instantiatedTel (Tel.instR rs sg.tel) ts es) u →
          HasTypeTelArgsQ P B Ψ Release.Qempty [] [] [] ws u a e →
            (∀ (w : Val), w ∈ ws → w.Ground) →
              B.ShapeOk b sg →
                sg.shape = Scope.Signature.IOShape.single k p →
                  NamesWF sg.names sg.params →
                    (∀ (w : Val), w ∈ ws → Val.Adequate σ w) →
                      ∃ a₀ e₀ r t,
                        HasTypeTelArgsQ P B Ψ Release.Qempty [] [] [] ws
                            (instantiatedTel
                              (Tel.instR rs sg.tel) ts es)
                            a₀ e₀ ∧
                          BuiltinArgs P B Ψ b sg
                              (Ty.normTys ts)
                              (List.map Eff.norm es) rs ws a₀ e₀ ∧
                            Ty.LeQ P [] [] a₀ a ∧
                              Eff.Covers [] [] e e₀ ∧
                                rs = [r] ∧
                                  ws[p]?.bind Val.target? = Option.some t ∧
                                    RangeExpr.Mem σ k r t ∧
                                      sg.shapeAt ws = Scope.Signature.IOShape.single k p
```

所在: [ScopedCallContracts.request_inputs](../../../formal/Benitoite/Release/Refinement/ScopedCallContracts.lean)（行36）。

```lean
ScopedCallContracts.request_inputs :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff} {p : Nat} {σ : PathEnv}
  {u : Tel} {A : Ty},
  PrimitiveAdmissible [] 0 sg Release.Qempty ts es →
    B.RangeAdmissible b sg rs →
      SignatureInstance P [] [] (Tel.instR rs sg.tel)
          (List.map TParamDecl.kind sg.tparams) ts es →
        TelClosure P [] []
            (instantiatedTel (Tel.instR rs sg.tel) ts es) u →
          HasTypeTelArgsQ P B Ψ Release.Qempty [] [] [] ws u a e →
            (∀ (w : Val), w ∈ ws → w.Ground) →
              B.ShapeOk b sg →
                sg.shape = Scope.Signature.IOShape.single Scope.Domain.Kind.endpoint p →
                  NamesWF sg.names sg.params →
                    (∀ (w : Val), w ∈ ws → Val.Adequate σ w) →
                      (∀ (o : Release.OpaqueName),
                          sg.params[p]? =
                              Option.some
                                (Ty.opaque o
                                  (RangeIx.rvar 0)) →
                            B.valContent o = Option.some A) →
                        ∃ a₀ e₀ r w target req,
                          HasTypeTelArgsQ P B Ψ Release.Qempty [] [] [] ws
                              (instantiatedTel
                                (Tel.instR rs sg.tel) ts es)
                              a₀ e₀ ∧
                            Ty.LeQ P [] [] a₀ a ∧
                              Eff.Covers [] [] e e₀ ∧
                                rs = [r] ∧
                                  ws[p]? = Option.some w ∧
                                    sg.shapeAt ws =
                                        Scope.Signature.IOShape.single Scope.Domain.Kind.endpoint
                                          p ∧
                                      (w = Val.checkedRequest target req ∨
                                          ∃ s snapshot,
                                            w =
                                              Val.checkedAt s snapshot target
                                                (Option.some req)) ∧
                                        ModelHttp.valueRun [w] =
                                            Outcome.val req ∧
                                          HasTypeV P B Ψ [] [] [] req A.norm ∧
                                            groundVal req = Bool.true ∧
                                              req.reqTarget = Option.some target ∧
                                                RangeExpr.Mem σ
                                                  Scope.Domain.Kind.endpoint r target
```

所在: [ScopedTargetExamples.single_io](../../../formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean)（行11）。

```lean
ScopedTargetExamples.single_io :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff} {k : Scope.Domain.Kind} {p : Nat}
  {σ : PathEnv} {u : Tel},
  ModelScopeConditions P B →
    B.sig b = Option.some sg →
      sg.kind = PrimKind.io ∨ sg.kind = PrimKind.exit →
        sg.shape = Scope.Signature.IOShape.single k p →
          PrimitiveAdmissible [] 0 sg Release.Qempty ts es →
            B.RangeAdmissible b sg rs →
              SignatureInstance P [] [] (Tel.instR rs sg.tel)
                  (List.map TParamDecl.kind sg.tparams) ts es →
                TelClosure P [] []
                    (instantiatedTel (Tel.instR rs sg.tel) ts
                      es)
                    u →
                  HasTypeTelArgsQ P B Ψ Release.Qempty [] [] [] ws u a e →
                    (∀ (w : Val), w ∈ ws → w.Ground) →
                      (∀ (w : Val),
                          w ∈ ws → Val.Adequate σ w) →
                        ∃ a₀ e₀ r t,
                          BuiltinArgs P B Ψ b sg
                              (Ty.normTys ts)
                              (List.map Eff.norm es) rs ws a₀ e₀ ∧
                            Ty.LeQ P [] [] a₀ a ∧
                              Eff.Covers [] [] e e₀ ∧
                                rs = [r] ∧
                                  ws[p]?.bind Val.target? = Option.some t ∧
                                    RangeExpr.Mem σ k r t ∧
                                      sg.shapeAt ws = Scope.Signature.IOShape.single k p ∧
                                        (∃ out obs,
                                            B.ioResponse b (Ty.normTys ts)
                                              (List.map Eff.norm es) ws out obs) ∧
                                          ∀ (out : Outcome)
                                            (obs : List Scope.Domain.Target),
                                            B.ioResponse b (Ty.normTys ts)
                                                (List.map Eff.norm es) ws out obs →
                                              obs = [t] ∧
                                                Outcome.Typed P B Ψ out a₀ ∧
                                                  AdequateResult ws out ∧
                                                    ∃ l,
                                                      sg.opEff = Option.some l ∧
                                                        ∀ (target : Scope.Domain.Target),
                                                          target ∈ obs →
                                                            Eff.Allows σ B.effKind e l
                                                              target
```

所在: [ScopedTargetExamples.request_io](../../../formal/Benitoite/Release/Refinement/ScopedTargetExamples.lean)（行46）。

```lean
ScopedTargetExamples.request_io :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {b : Release.PrimName}
  {sg : PrimSig} {ts : List Ty}
  {es : List Eff} {rs : List RangeExpr}
  {ws : List Val} {a : Ty}
  {e : Eff} {p : Nat} {σ : PathEnv}
  {u : Tel} {A : Ty},
  ModelScopeConditions P B →
    B.sig b = Option.some sg →
      sg.kind = PrimKind.io ∨ sg.kind = PrimKind.exit →
        sg.shape = Scope.Signature.IOShape.single Scope.Domain.Kind.endpoint p →
          PrimitiveAdmissible [] 0 sg Release.Qempty ts es →
            B.RangeAdmissible b sg rs →
              SignatureInstance P [] [] (Tel.instR rs sg.tel)
                  (List.map TParamDecl.kind sg.tparams) ts es →
                TelClosure P [] []
                    (instantiatedTel (Tel.instR rs sg.tel) ts
                      es)
                    u →
                  HasTypeTelArgsQ P B Ψ Release.Qempty [] [] [] ws u a e →
                    (∀ (w : Val), w ∈ ws → w.Ground) →
                      (∀ (w : Val),
                          w ∈ ws → Val.Adequate σ w) →
                        (∀ (o : Release.OpaqueName),
                            sg.params[p]? =
                                Option.some
                                  (Ty.opaque o
                                    (RangeIx.rvar 0)) →
                              B.valContent o = Option.some A) →
                          ∃ a₀ e₀ r w target req,
                            BuiltinArgs P B Ψ b sg
                                (Ty.normTys ts)
                                (List.map Eff.norm es) rs ws a₀ e₀ ∧
                              Ty.LeQ P [] [] a₀ a ∧
                                Eff.Covers [] [] e e₀ ∧
                                  rs = [r] ∧
                                    ws[p]? = Option.some w ∧
                                      (w = Val.checkedRequest target req ∨
                                          ∃ s snapshot,
                                            w =
                                              Val.checkedAt s snapshot target
                                                (Option.some req)) ∧
                                        ModelHttp.valueRun [w] =
                                            Outcome.val req ∧
                                          HasTypeV P B Ψ [] [] [] req A.norm ∧
                                            groundVal req = Bool.true ∧
                                              req.reqTarget = Option.some target ∧
                                                RangeExpr.Mem σ
                                                    Scope.Domain.Kind.endpoint r target ∧
                                                  (∃ out obs,
                                                      B.ioResponse b (Ty.normTys ts)
                                                        (List.map Eff.norm es) ws out
                                                        obs) ∧
                                                    ∀ (out : Outcome)
                                                      (obs : List Scope.Domain.Target),
                                                      B.ioResponse b (Ty.normTys ts)
                                                          (List.map Eff.norm es) ws out
                                                          obs →
                                                        obs = [target] ∧
                                                          Outcome.Typed P B Ψ out a₀ ∧
                                                            AdequateResult ws out
```

### F09

所在: [ModelScopeConditions](../../../formal/Benitoite/Release/Refinement/TargetModelConditions.lean)（行5）。

```lean
ModelScopeConditions :
Program → Builtins → Prop
```

所在: [ModelScopeConditions.core](../../../formal/Benitoite/Release/Refinement/TargetModelConditions.lean)（行30）。

```lean
ModelScopeConditions.core :
∀ {P : Program} {B : Builtins},
  ModelScopeConditions P B →
    Builtins.ExternalAssumptions P B →
      (∀ (Ψ : StoreTy) (v : Val)
          (o : Release.OpaqueName),
          HasTypeV P B Ψ [] [] [] v
              (Ty.opaque o
                (RangeIx.fixed RangeExpr.top)) →
            B.isResource o = Bool.true → ∃ r, B.releaseResponse v r) →
        Builtins.CoreAssumptions P B
```

所在: [Model.scopeConditions](../../../formal/Benitoite/Release/Refinement/Model.lean)（行181）。

```lean
Model.scopeConditions :
∀ (P : Program),
  ModelScopeConditions P Model.builtins
```

所在: [ModelTargets.scopeConditions](../../../formal/Benitoite/Release/Refinement/ModelTargets.lean)（行442）。

```lean
ModelTargets.scopeConditions :
∀ (P : Program),
  ScopeDeclarations.HasFile P →
    ModelScopeConditions P ModelTargets.builtins
```

所在: [ModelHttp.scopeConditions](../../../formal/Benitoite/Release/Refinement/ModelHttpConditions.lean)（行327）。

```lean
ModelHttp.scopeConditions :
∀ (P : Program),
  ScopeDeclarations.HasHttp P →
    ModelScopeConditions P ModelHttp.builtins
```

所在: [ScopeModels.conditions](../../../formal/Benitoite/Release/Refinement/ScopeModels.lean)（行9）。

```lean
ScopeModels.conditions :
∀ (P : Program),
  ScopeDeclarations.HasHttp P →
    ModelScopeConditions P Model.builtins ∧
      ModelScopeConditions P ModelTargets.builtins ∧
        ModelScopeConditions P ModelHttp.builtins
```

実際の出力の定義形は次のとおりである。主定理の新しい未検査の前提ではない。

```lean
structure ModelScopeConditions (P : Program) (B : Builtins) : Prop extends
    Builtins.SubstitutionAssumptions P B,
    Builtins.ResponseAssumptions P B,
    Builtins.TargetAgreement P B where
  sig_scoped : ∀ b s, B.sig b = some s → PrimSig.Scoped P s
  sat_unconstrained : ∀ t : Ty, t.WF 0 0 0 → B.sat [] t.norm ({} : TParam)
  admits_sat : ∀ b s C ts, B.sig b = some s →
    s.admits (TypeCtx.constraints C) (Ty.normTys ts) →
    SatAll B C ts (s.tparams.map TParamDecl.constraints)
  pathBases_shape : ∀ b s, B.sig b = some s → s.kind = .pathBases →
    s.PathBasesShape B b
  io_op : ∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    B.ShapeOk b s
  opEff_io : ∀ b s l, B.sig b = some s → s.opEff = some l →
    s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases
  effect_ops : ∀ l bs b, B.effects l = some bs → b ∈ bs →
    ∃ s, B.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧
      s.opEff = some l
  state_effect : B.effects stateEff = some []
  ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
  ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet
  store_shape : ∀ b s, B.sig b = some s → s.kind ≠ .pathBases → s.StoreShape
  store_admits : ∀ b s C ts, B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io →
    s.kind ≠ .exit → s.kind ≠ .pathBases → ts.length = s.tparams.length → s.admits C ts
```

### F10

所在: [Detail](../../../formal/Benitoite/Release/Refinement/ScopeSyntax.lean)（行164）。

```lean
Detail :
Type → Type
```

所在: [AtError.save_exact](../../../formal/Benitoite/Release/Refinement/AtPrepare.lean)（行361）。

```lean
AtError.save_exact :
∀ (p t : Val) (snapshot : Option PathEnv)
  (pp : Option RangeExpr) (pt : Option TargetInput)
  (f : AtFailure),
  have d := AtError.save p t snapshot pp pt f;
  d.originalPattern = p ∧
    d.originalTarget = t ∧
      d.failure = f ∧
        d.parsedPattern = pp ∧
          d.parsedTarget = pt ∧
            d.resolvedPatterns = pp.bind (resolveSnapshot snapshot) ∧
              d.resolvedTarget = pt.bind (resolveTargetSnapshot snapshot) ∧
                d.patternBase = pp.bind RangeExpr.base? ∧
                  d.targetBase = pt.bind TargetInput.base?
```

所在: [AtPrepare.error_saved](../../../formal/Benitoite/Release/Refinement/AtPrepare.lean)（行424）。

```lean
AtPrepare.error_saved :
∀ {B : Builtins} {cap : Capture}
  {kind : Scope.Domain.Kind} {name : Release.OpaqueName}
  {bases : Option Val} {pattern input : Val}
  {index : RangeIx} {detail : AtError},
  AtPrepare B cap kind name bases pattern input index = Except.error detail →
    ∃ snapshot pp pt,
      detail =
        AtError.save (closeVal cap pattern)
          (closeVal cap input) snapshot pp pt detail.failure
```

所在: [AtError.fromCheck](../../../formal/Benitoite/Release/Refinement/Syntax.lean)（行235）。

```lean
AtError.fromCheck :
Val →
  Val →
    Option PathEnv →
      RangeExpr →
        TargetInput →
          AtCheckError → AtError
```

所在: [Detail.originals_unobserved](../../../formal/Benitoite/Release/Refinement/AtTargets.lean)（行79）。

```lean
Detail.originals_unobserved :
∀ (d : AtError) (p t : Val),
  have d' :=
    { failure := d.failure, originalPattern := p, originalTarget := t, parsedPattern := d.parsedPattern,
      parsedTarget := d.parsedTarget, resolvedPatterns := d.resolvedPatterns, resolvedTarget := d.resolvedTarget,
      patternBase := d.patternBase, targetBase := d.targetBase };
  Detail.textFields d' = Detail.textFields d ∧
    Detail.values d' = Detail.values d ∧
      (Val.atError d').toTerm? = (Val.atError d).toTerm? ∧
        ∀ (pat : Release.Pat),
          Option.map (List.map Val.toTerm?)
              (matchVal pat (Val.atError d')) =
            Option.map (List.map Val.toTerm?)
              (matchVal pat (Val.atError d))
```

所在: [AtErrorReaders.observed](../../../formal/Benitoite/Release/Refinement/AtErrorReaders.lean)（行9）。

```lean
AtErrorReaders.observed :
∀ {P : Program} {B : Builtins}
  {Ψ : StoreTy} {Q : Release.NoFailCtx}
  {C : TypeCtx} {Γ : Ctx}
  {Φ : List Pred} {shape : ResultShape},
  ResultShape.Declared P shape →
    ∀ (d : AtError),
      HasTypeVQ P B Ψ Q C Γ Φ (Val.atError d)
          atErrorType ∧
        (∀ (t : Term),
            (Val.atError d).toTerm? = Option.some t →
              Term.Declared P C Γ t) ∧
          matchVal atErrorPattern
                (Val.atError d) =
              Option.some (Detail.values d) ∧
            HasTypeVsQ P B Ψ Q C Γ Φ (Detail.values d)
                atErrorFields ∧
              ∀ (ws : List Val),
                AdequateResult ws
                  (Outcome.val (Val.atError d))
```

Detail Valは失敗・生入力二欄・解析済み二欄・解決済み二欄・両起点の九欄を保持する。未解析noneと未解決、解決済みの空列を区別する。公開PathBases/At/ScopeErrorの形はここで選択しない。


## 後段へ渡す署名と受け口

| 受け手 | 実際の署名・証拠 | 受け持つ残件 |
|---|---|---|
| L60 | `Benitoite.Release.Refinement.Model.scopeConditions`・`Benitoite.Release.Refinement.ModelTargets.scopeConditions`・`Benitoite.Release.Refinement.ModelHttp.scopeConditions`・`Benitoite.Release.Refinement.ModelScopeConditions.core`・`Benitoite.Release.Refinement.ScopeResponse.delta_typed`・`Benitoite.Release.Refinement.ScopedIOResponse.response`・`Benitoite.Release.Refinement.ScopedIOResponse.io_exists` | 同じP/Bの外部三条件と通常資源のreleaseを構成し、全標準実表へ組み込む。75欄の出力を新しい公理や独立の信頼条件にしない |
| L70 | F01〜F05の下記完全署名、`Benitoite.Release.Refinement.AtPrepared.current`・`Benitoite.Release.Refinement.StateTyE.at_step`・`Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs`・`Benitoite.Release.Refinement.ScopedTargetInputs.pure_steps`・`Benitoite.Release.Refinement.ScopedTargetInputs.io_steps`・`Benitoite.Release.Refinement.ScopedTargetInputs.handled_step`・`Benitoite.Release.Refinement.ScopedTargetInputs.at_steps`・`Benitoite.Release.Refinement.ScopedTargetInputs.path_bases_apply`・`Benitoite.Release.Refinement.ScopedTargetInputs.issue` | 主な全保存・進行・step_sound・事象/対象の一段・到達・表層、同じσ/Eb/ストアへの合成。保持元と実引数位置の全体の値の流れ |
| R10b/R30 | `Benitoite.Release.Refinement.ScopedCallContracts.single_inputs`・`Benitoite.Release.Refinement.ScopedCallContracts.request_inputs`・`Benitoite.Release.Refinement.ScopedTargetExamples.single_io`・`Benitoite.Release.Refinement.ScopedTargetExamples.request_io`・`Benitoite.Release.Refinement.ScopedTargetExamples.widened_input`・`Benitoite.Release.Refinement.ScopedTargetExamples.incomparable`と13API表 | 入力から一度だけ範囲を具体化する推論、5形と7位置の実受理・拒否。結果型/許容効果からrsを逆算しない |
| R30/R70 | `Benitoite.Release.Refinement.Val.Source`・`Benitoite.Release.Refinement.Comp.Source`・`Benitoite.Release.Refinement.InitialPrepared.source_state_of_source`、`Benitoite.Release.Refinement.ModelTargetsExamples.issue`、`Benitoite.Release.Refinement.AtPrepared.current`、`Benitoite.Release.Refinement.ScopedTargetExamples.equal_resolution_distinct_base`・`Benitoite.Release.Refinement.ScopedTargetExamples.secrets_members` | 固定σの供給、PathBases/Atと同じ保持絶対対象をFile6本/Httpへ。work/tmpの実在と管理、起動形・別cwd・secretsのCLI拒否、heap/stress |
| R50 | `Benitoite.Release.Refinement.ScopeResponse.delta_typed`・`Benitoite.Release.Refinement.ScopeResponse.outcome_typed`・`Benitoite.Release.Refinement.ScopedIOResponse.response`・`Benitoite.Release.Refinement.ScopedIOResponse.io_typed`、`Benitoite.Release.Refinement.ScopedTargetExamples.equal_resolution_distinct_base`、`Benitoite.Release.Refinement.parseUrlTarget`・`Benitoite.Release.Refinement.parseAtInput`・`Benitoite.Release.Refinement.ScopeDelta.pathValueRun_parseAtInput` | L70のF-REG後のF-CONN、外部関数を含む全比較。δの既知の三差はE再開1で揃え済みであり、未処置として送らない。関門外URLの受理、捕捉内部を読む契約の差は保持。`Benitoite.Release.Refinement.ModelTargets.readObs` は相対形・home形・解析の失敗で観測を空にする。処理系の `File.readText` がcwdから解決して実際に読む対象との比較をR50へ渡す |
| U02後・L70前の別作業 | `Benitoite.Release.Refinement.Detail`・`Benitoite.Release.Refinement.AtError.save_exact`・`Benitoite.Release.Refinement.AtError.fromCheck`・`Benitoite.Release.Refinement.AtPrepare.error_saved`・`Benitoite.Release.Refinement.AtErrorReaders.observed`・`Benitoite.Release.Refinement.ResultShape.Declared`・`Benitoite.Release.Refinement.Program.StandardErrorComplete` | J50-1。公開名・全署名・観測・宣言・照合・網羅性を写す。生Valを読むならatErrorの閉性・適格性を再点検 |
| R30/R60 | 同じ内部保存と全失敗、七String観測、D61 | 選ばれた公開構成子・文言・Show。保存値は非切詰め、表示は引用・エスケープ・4096バイト上限。outsideScopeの意味を動的/静的な不所属へ潰さない |
| D10/V10 | O044/O156、Sourceの直接構築の境界、全σの所属と静的被覆 | 00-01/AGENTSの公開要約と実CLIのcheck観測/run固定値の限界、IFC未実装。今回先行改訂しない |

## 設計者の見直しと計画との差

[全一覧](l/review-points.md)にplan/READMEの指定項目と各群の差をまとめ、[出どころ33行](l/review-point-sources.json)を保存した。L20/L30/L40の受け入れ済みの判断は再承認待ちへ戻さない。L50のNamesWF二前提、F06.currentの不要前提除去、Requestの三入口のform除去、D61の内部保存、δのRustとの三差の処置、内部配置・場合数・読者の分類を明記した。J50-1/U02の公開形と、CaptureReadBoundaryの登録判断を残す。今回新しく停止条件に当たる変更の判断は求めていない。

## 定義・言明・仮定の一覧と段末公理監査

既定Benitoiteのimport閉包にある1032モジュール・80672宣言へ全名で#print axiomsを行い、固定点2巡でprivate・生成宣言を含めた。変更61モジュール（根importを含む）の5660宣言、新設33モジュールの1327宣言を区別する。再開1の本番コメント修正を含めて監査を一度更新した。この61モジュールは再開1の監査時の対象である。再開2で7ファイルのコメントを開始時へ戻し、L40の保存済み入力に対する変更対象は54モジュールへ戻った。監査対象は縮めず、監査時と現行のコメント外の一致を[l/resume2-source-check](l/resume2-source-check.json)で照合する。変更分にはprivateの全名1767、個別のソース位置を持たない生成宣言3523を含む（分類は重複する）。

新規の全宣言と使用定義・言明・仮定の所在は、[監査要約](l/audit-summary.json)が指すdeclarations-partの分割記録にある。各記録に所属モジュール・相対ソース・全名・種類・行番号を保存し、生成宣言の行番号を作らない。変更モジュール全体を収めるため追加宣言を漏らさないが、既存の宣言を新規件数とは呼ばない。標準ライブラリの使用定義への依存も各#print axiomsが再帰的に辿る。旧Releaseの主定理・モデルを含め既定から外したモジュールは0件である。

| 公理依存の集合 | 宣言数 |
|---|---:|
| none | 37476 |
| Classical.choice | 1 |
| Classical.choice + Quot.sound + propext | 20193 |
| Classical.choice + propext | 2 |
| Quot.sound | 9 |
| Quot.sound + propext | 3866 |
| propext | 19125 |

新公理・sorryAxは0件である。許可された三公理だけであることと、sorry拒否を別に照合した。全対象一覧は一時領域に置き、台本・件数・SHA-256を残す。

| 出力 | bytes | SHA-256 |
|---|---:|---|
| 監査生出力（再開1） | 19176573 | `65aee195ca9d8e97f25643b0c295e93b44175e4300e56f39a8195f1d75f418a7` |
| 全名対象一覧 | 5303859 | `434727ff0cc0ddd34c65a91d0817b30a329479b4ace801401bbb036550ad9359` |


## 検査と今回の変更

01-12と07-04へ、Sourceによる実行時構成子の直接構築の拒否と、静的判断・全σの意味・固定σの実行の境界を明記した。一般の型付きValを偽造不能とは呼ばず、check/runの環境の一致、実体・副通信の隔離、情報フロー制御を保証しない。曖昧なコメントを実名と内部観測の形へ直した。定義・言明・証明の中身は変更していない。工程ID・手元の絶対パス・新公理・未実装の段名を写しへ追加していない。

| 検査 | 中身・結果 | 記録 |
|---|---|---|
| 対象指定なしの既定lake build、1293 jobs | 終了0、外側21.057072秒 | [記録](l/build-check.json) |
| 前回の公理監査と実署名・定義形の印字 | 終了0、外側51.119676秒 | [記録](l/audit-full-check.json) |
| 三モデル75欄の全称の契約を単独Leanで再検査 | 終了0、外側0.926812秒 | [記録](l/conditions-check.json) |
| 指定B_WORK・onlyなしのworkの選択確認 | 終了0、外側0.334959秒 | [記録](l/dry-run-check.json) |
| 仕様対応表の自己検査/集計、仕様例、既定Leanビルドとsorry拒否 | 終了0、外側8.423303秒 | [記録](l/work-check.json) |

公理監査の印字API・未知オプションによる失敗と、署名の証明省略・容量を検出した再集計は[l/results](l/results.md)に残した。本番の不足や公理の発見ではない。最終に保存する宣言・実署名は成功した一回分だけである。

再開1（L50.59）の既定ビルドは1293 jobs成功・終了0、外側414.752619秒（6分54.75秒）である。コメント変更の依存先を再構築したため、前回の増分21秒より長い。公理監査は終了0・外側53.417849秒であり、既定Benitoiteのimport閉包1032モジュール・80672宣言、private/生成を含む固定点2巡、新公理・sorryAxとも0件、許可三公理の部分集合だけだった。変更61モジュール5660宣言、1856実署名を保存し、後段の必須81名も確認した。[ビルド](l/resume1-build-check.json)・[公理監査](l/resume1-audit-check.json)・[監査集計](l/audit-summary.json)を正とする。75欄の全称契約を含む前提矛盾検査も終了0だった。reconcile/verifyの最終の結果は[l/reconciliation](l/reconciliation.json)・[l/verification](l/verification.json)へ保存する。今回のworkは0回である。再開2では既定ビルドと最終reconcile/verifyを各一度実行し、公理監査はコメント外の一致を根拠に再開1の結果を引き継ぐ。再開2の終了・所要・検査の記録は[l/resultsの再開2](l/results.md)に置く。

## 見込みと実績

L50全段の枠36.5〜84時間（中心60.25）、60単位の参考積上げ38時間30分〜71時間5分（中心54時間47分30秒）は変更しない。今回の指定は.59を除き1時間55分〜3時間30分、上限7時間である。下表は各resultsにある外側の区間で、能動時間と待ちは未分離である。資料読解を含まない初回の単位区間と、読解を含む再開区間を別に置き、厳密な総能動時間を作らない。取りまとめの独立レビュー・clean再ビルド・正式RSSの時間はこの表へ加算していない。

| 群 | 初回又は本番単位の外側の区間 | 再開・補足 | 出どころ |
|---|---|---|---|
| A | 16:02:58〜16:09:48の6分50秒でF04停止 | 再開1 8分03秒、再開2 22分40秒、再開3 4分13秒。停止資料・各群末外の厳密な合計は未取得 | [a/results](a/results.md) |
| B | 16分54秒 | 再開1 4分00秒 | [b/results](b/results.md) |
| C | 36分33秒 | 再開1 9分13秒。誤起動した既定build2件の全生出力・外側時間は未取得 | [c/results](c/results.md) |
| D | 58分35秒 | 再開1 10分05秒。単位境界の一部はdate出力から転記 | [d/results](d/results.md) |
| E | 38分13秒 | 再開1 25分05秒 | [e/results](e/results.md) |
| F | 26分00秒 | 再開1 15分15秒 | [f/results](f/results.md) |
| G | 18分09秒 | 取りまとめの写し修正の外側時間は未取得 | [g/results](g/results.md) |
| H | 25分19秒 | 取りまとめの記録/写し修正の外側時間は未取得 | [h/results](h/results.md) |
| I | 19分11秒 | 取りまとめのコメント・上限設定・写し修正の外側時間は未取得 | [i/results](i/results.md) |
| J | 15分25秒 | 取りまとめの例・コメント・写し修正の外側時間は未取得 | [j/results](j/results.md) |
| K | 23分33秒 | 再開1 16分11秒。取りまとめの注記等の外側時間は未取得 | [k/results](k/results.md) |
| L（今回） | 24分05秒 | .56〜.58・.60の四区間。資料読解・検査待ちを含む。能動時間未分離 | [l/results](l/results.md) |

上表に数値がある区間の合計は7時間03分32秒（25412秒）である。積上げの下限38時間30分に対して18.34%、上限71時間05分に対して9.93%（約1/5.45〜1/10.07）である。未取得の取りまとめの処置・独立レビュー・回答待ち・計画下書きと、この再開1の時間はこの合計に含めない。能動時間と待ちを分離できないため、planの外挿の規則に従い、能動時間の見込みは変更しない。

再開1（L50.59）を加えた外側の合計と積上げに対する比は、終了時刻を確定する[l/resultsの再開1](l/results.md)に記録する。

計画下書きと再開1・2の外側時間は[l50/results](results.md)にある。初回の単位と同じ記録ではないため、実装の一件当たり係数には使わない。取得していないレビュー・回答待ちや能動時間を0として足さない。

## L50.59と最終検査・受け入れの受け口

L50.59は再開1でRV-L50.lの中1〜3・軽1〜6を処置した。本書・全F署名・定義の本体・全名の所在・33義務/31申し送り・75/12欄・13API表・群Kの依存の限定・見直しの一覧をレビューの入力とする。全所見について当たる本番/写し、前提・結論・供給元、処置と古くなった検査/監査を一行ずつ記録する。主な十言明・新公理・独立の信頼条件・書ける形・提供範囲・精密外部状態・型付け規則・U02依存の公開形の選択が必要なら、実装の前に停止する。

| 所見 | 処置と根拠 |
|---|---|
| 中1 | 01-12・07-04で、σを取らない `HasTypeVQ`・`HasTypeCQ`・腕・節と、同じσを取ってAdequateを読む `ContTy`・`StoreOk`・`StateTyE` を実名で書き分けた |
| 中2 | 全75欄へ同じ前提矛盾検査を適用し、本番の到達枝・群H〜Jレビューと併せて行ごとに判定。Modelは実質19/空疎6、他二モデルは各実質25/空疎0。[判定記録](l/condition-judgments.json) |
| 中3 | 名前・所在・型ハッシュ・依存の機械照合と量化範囲のレビュー判断を分離。64行に群Kのtraceと独立レビューの出典を持たせ、未完リストから件数を集計する形へ変更 |
| 軽1 | 01-12の4046行付近、07-04の151行付近、ScopeLegacyContracts.leanの12行の三箇所だけをScope.checkPath・Scope.checkPathInの実名へ変更。再開2で範囲外の置換97箇所（文書89・コメント8）を再開1開始時へ復元した。[実名の確認](l/legacy-word-check.json)・[復元と保持の照合](l/resume2-restoration.json)。中1〜3・軽2〜6は保持 |
| 軽2 | [見直しの群D](l/review-points.md)にStep.E_AtError・StoreReplyInputs.E_AtErrorの行先とVal.atErrorの引数型の変更、前提・量化の不変、Adequateの元入力非再帰を記載 |
| 軽3 | R50にModelTargets.readObsの相対形・home形・解析失敗での空観測と、処理系File.readTextの実際の対象との比較を追加 |
| 軽4 | 後段の受け口のLean名をBenitoite.Release.Refinementから始まる完全名に揃え、追加の実名も必須監査へ入れた |
| 軽5 | 数値がある外側の区間を合計し、38時間30分〜71時間05分との比と、未取得・除外範囲を明記。能動時間の見込みは変更していない |
| 軽6 | ModelTargetsのrelease_existsは現在の表なら `⟨none, rfl⟩` で供給できること、L60の残件は通常資源の実際の解放関係を表に入れてその関係で存在を示すことであることを記載 |

情報1は、ここでの「全環境」を既定Benitoiteのimport閉包と明記して処置した。情報2のU02後の再点検と情報3の保存上限は継承する。新しい前提・公理・提供範囲・型付け規則・公開形は選んでいない。新たに閉じる必要のあるL50独立未完は0件である。再開1・再開2の検査結果と単位時刻は[l/results](l/results.md)に記録し、workは取りまとめによる同じ最終実装状態での一度の実行に残す。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 段末独立レビュー | RV-L50.lで条件付き可。中1〜3・軽1〜6を再開1で処置 | 実施済み。レビューの外側時間は未取得 |
| L50.59の所見の処置と再確認 | 再開1で中1〜3・軽1〜6を処置し、古くなった監査・照合を更新 | 実績は[l/results](l/results.md)の再開1 |
| 正式な最終workと最大常駐量 | 取りまとめがレビュー処置後の同じ実装状態で一度採る。計測器と本体の終了を分け、機械・OS・原単位・HEAD/差分/入力を記録 | 不明。今回の増分実行を次の計測の初期値とする |
| 段末の照合・受け入れ | 取りまとめが証拠を集約し設計者が受け入れを判定 | 不明 |
| U02の公開形への写し | U02確定後・L70前の別作業。選んだ形の前提と全読者を確認 | 比較材料の仮見込みを短い代表一件で見直す。全体は不明 |
| L60/L70/R段 | 各既存計画の外部/解放・主定理/表層/全比較・固定σ/推論/実CLI | 各計画。待ちは不明 |

正式な最終work/RSSの記録欄は、対象HEAD/未コミット差分、入力/生成物/設定/道具/構成、コマンド、件数、終了、外側時間、最大常駐量・原単位、計測器の終了、関係状態一致の根拠、判断者/日付とする。2026-11-05 に取りまとめが、RV-L50.l の再確認の後の同じ最終実装状態で一度採った（終了0、外側 478.36秒、最大常駐量 2,938,339,328 バイト。記録は [l/results](l/results.md) の「L50 の段末の最終 work の検査」）。2026-11-05 に設計者が段末を受け入れた（README「設計者の決定」）。今回の既定build・公理監査・作業末workの成功を、Rust/Leanの全比較・主定理全体の閉鎖・実行時隔離・段末受け入れの証拠としない。
