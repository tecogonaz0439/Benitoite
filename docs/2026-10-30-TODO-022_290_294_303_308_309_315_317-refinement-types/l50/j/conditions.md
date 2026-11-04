# 三モデルの七十五欄

各行は同じ P/B の全称の欄である。外部三条件と release_exists はこの表へ加えない。名前は Benitoite.Release.Refinement 内であり、各式の実型を [contracts.lean](contracts.lean) が検査する。

| 番号 | モデル | 欄 | 実際の定理又は射影 | 同じ出力の欄 | 判定 |
|---:|---|---|---|---|---|
| 1 | Model.builtins | sat_rename | `(Model.substitutionAssumptions P).sat_rename` | `(Model.scopeConditions P).sat_rename` | 証明済み |
| 2 | Model.builtins | admits_rename | `(Model.substitutionAssumptions P).admits_rename` | `(Model.scopeConditions P).admits_rename` | 証明済み |
| 3 | Model.builtins | sat_values | `(Model.substitutionAssumptions P).sat_values` | `(Model.scopeConditions P).sat_values` | 証明済み |
| 4 | Model.builtins | admits_values | `(Model.substitutionAssumptions P).admits_values` | `(Model.scopeConditions P).admits_values` | 証明済み |
| 5 | Model.builtins | sat_renameTypes | `(Model.substitutionAssumptions P).sat_renameTypes` | `(Model.scopeConditions P).sat_renameTypes` | 証明済み |
| 6 | Model.builtins | admits_renameTypes | `(Model.substitutionAssumptions P).admits_renameTypes` | `(Model.scopeConditions P).admits_renameTypes` | 証明済み |
| 7 | Model.builtins | sat_subst | `(Model.substitutionAssumptions P).sat_subst` | `(Model.scopeConditions P).sat_subst` | 証明済み |
| 8 | Model.builtins | admits_subst | `(Model.substitutionAssumptions P).admits_subst` | `(Model.scopeConditions P).admits_subst` | 証明済み |
| 9 | Model.builtins | delta_typed | `Model.delta_typed` | `(Model.scopeConditions P).delta_typed` | 証明済み |
| 10 | Model.builtins | io_typed | `Model.io_typed` | `(Model.scopeConditions P).io_typed` | 証明済み |
| 11 | Model.builtins | io_kind | `Model.io_kind` | `(Model.scopeConditions P).io_kind` | 証明済み |
| 12 | Model.builtins | io_exists | `Model.io_exists` | `(Model.scopeConditions P).io_exists` | 証明済み |
| 13 | Model.builtins | sig_scoped | `Model.sig_scoped` | `(Model.scopeConditions P).sig_scoped` | 証明済み |
| 14 | Model.builtins | sat_unconstrained | `Model.sat_unconstrained` | `(Model.scopeConditions P).sat_unconstrained` | 証明済み |
| 15 | Model.builtins | admits_sat | `Model.admits_sat` | `(Model.scopeConditions P).admits_sat` | 証明済み |
| 16 | Model.builtins | pathBases_shape | `Model.pathBases_shape` | `(Model.scopeConditions P).pathBases_shape` | 証明済み |
| 17 | Model.builtins | io_op | `Model.io_op` | `(Model.scopeConditions P).io_op` | 証明済み |
| 18 | Model.builtins | opEff_io | `Model.opEff_io` | `(Model.scopeConditions P).opEff_io` | 証明済み |
| 19 | Model.builtins | effect_ops | `Model.effect_ops` | `(Model.scopeConditions P).effect_ops` | 証明済み |
| 20 | Model.builtins | state_effect | `Model.state_effect` | `(Model.scopeConditions P).state_effect` | 証明済み |
| 21 | Model.builtins | ref_get | `Model.ref_get` | `(Model.scopeConditions P).ref_get` | 証明済み |
| 22 | Model.builtins | ref_set | `Model.ref_set` | `(Model.scopeConditions P).ref_set` | 証明済み |
| 23 | Model.builtins | store_shape | `Model.store_shape` | `(Model.scopeConditions P).store_shape` | 証明済み |
| 24 | Model.builtins | store_admits | `Model.store_admits` | `(Model.scopeConditions P).store_admits` | 証明済み |
| 25 | Model.builtins | io_target | `(Model.targetAgreement P).io_target` | `(Model.scopeConditions P).io_target` | 証明済み |
| 26 | ModelTargets.builtins | sat_rename | `(ModelTargets.substitutionAssumptions P).sat_rename` | `(ModelTargets.scopeConditions P hp).sat_rename` | 証明済み |
| 27 | ModelTargets.builtins | admits_rename | `(ModelTargets.substitutionAssumptions P).admits_rename` | `(ModelTargets.scopeConditions P hp).admits_rename` | 証明済み |
| 28 | ModelTargets.builtins | sat_values | `(ModelTargets.substitutionAssumptions P).sat_values` | `(ModelTargets.scopeConditions P hp).sat_values` | 証明済み |
| 29 | ModelTargets.builtins | admits_values | `(ModelTargets.substitutionAssumptions P).admits_values` | `(ModelTargets.scopeConditions P hp).admits_values` | 証明済み |
| 30 | ModelTargets.builtins | sat_renameTypes | `(ModelTargets.substitutionAssumptions P).sat_renameTypes` | `(ModelTargets.scopeConditions P hp).sat_renameTypes` | 証明済み |
| 31 | ModelTargets.builtins | admits_renameTypes | `(ModelTargets.substitutionAssumptions P).admits_renameTypes` | `(ModelTargets.scopeConditions P hp).admits_renameTypes` | 証明済み |
| 32 | ModelTargets.builtins | sat_subst | `(ModelTargets.substitutionAssumptions P).sat_subst` | `(ModelTargets.scopeConditions P hp).sat_subst` | 証明済み |
| 33 | ModelTargets.builtins | admits_subst | `(ModelTargets.substitutionAssumptions P).admits_subst` | `(ModelTargets.scopeConditions P hp).admits_subst` | 証明済み |
| 34 | ModelTargets.builtins | delta_typed | `ModelTargets.delta_typed` | `(ModelTargets.scopeConditions P hp).delta_typed` | 証明済み |
| 35 | ModelTargets.builtins | io_typed | `ModelTargets.io_typed` | `(ModelTargets.scopeConditions P hp).io_typed` | 証明済み |
| 36 | ModelTargets.builtins | io_kind | `ModelTargets.io_kind` | `(ModelTargets.scopeConditions P hp).io_kind` | 証明済み |
| 37 | ModelTargets.builtins | io_exists | `ModelTargets.io_exists` | `(ModelTargets.scopeConditions P hp).io_exists` | 証明済み |
| 38 | ModelTargets.builtins | sig_scoped | `ModelTargets.sig_scoped` | `(ModelTargets.scopeConditions P hp).sig_scoped` | 証明済み |
| 39 | ModelTargets.builtins | sat_unconstrained | `ModelTargets.sat_unconstrained` | `(ModelTargets.scopeConditions P hp).sat_unconstrained` | 証明済み |
| 40 | ModelTargets.builtins | admits_sat | `ModelTargets.admits_sat` | `(ModelTargets.scopeConditions P hp).admits_sat` | 証明済み |
| 41 | ModelTargets.builtins | pathBases_shape | `ModelTargets.pathBases_shape` | `(ModelTargets.scopeConditions P hp).pathBases_shape` | 証明済み |
| 42 | ModelTargets.builtins | io_op | `ModelTargets.io_op` | `(ModelTargets.scopeConditions P hp).io_op` | 証明済み |
| 43 | ModelTargets.builtins | opEff_io | `ModelTargets.opEff_io` | `(ModelTargets.scopeConditions P hp).opEff_io` | 証明済み |
| 44 | ModelTargets.builtins | effect_ops | `ModelTargets.effect_ops` | `(ModelTargets.scopeConditions P hp).effect_ops` | 証明済み |
| 45 | ModelTargets.builtins | state_effect | `ModelTargets.state_effect` | `(ModelTargets.scopeConditions P hp).state_effect` | 証明済み |
| 46 | ModelTargets.builtins | ref_get | `ModelTargets.ref_get` | `(ModelTargets.scopeConditions P hp).ref_get` | 証明済み |
| 47 | ModelTargets.builtins | ref_set | `ModelTargets.ref_set` | `(ModelTargets.scopeConditions P hp).ref_set` | 証明済み |
| 48 | ModelTargets.builtins | store_shape | `ModelTargets.store_shape` | `(ModelTargets.scopeConditions P hp).store_shape` | 証明済み |
| 49 | ModelTargets.builtins | store_admits | `ModelTargets.store_admits` | `(ModelTargets.scopeConditions P hp).store_admits` | 証明済み |
| 50 | ModelTargets.builtins | io_target | `(ModelTargets.targetAgreement P).io_target` | `(ModelTargets.scopeConditions P hp).io_target` | 証明済み |
| 51 | ModelHttp.builtins | sat_rename | `(ModelHttp.substitutionAssumptions P).sat_rename` | `(ModelHttp.scopeConditions P hp).sat_rename` | 証明済み |
| 52 | ModelHttp.builtins | admits_rename | `(ModelHttp.substitutionAssumptions P).admits_rename` | `(ModelHttp.scopeConditions P hp).admits_rename` | 証明済み |
| 53 | ModelHttp.builtins | sat_values | `(ModelHttp.substitutionAssumptions P).sat_values` | `(ModelHttp.scopeConditions P hp).sat_values` | 証明済み |
| 54 | ModelHttp.builtins | admits_values | `(ModelHttp.substitutionAssumptions P).admits_values` | `(ModelHttp.scopeConditions P hp).admits_values` | 証明済み |
| 55 | ModelHttp.builtins | sat_renameTypes | `(ModelHttp.substitutionAssumptions P).sat_renameTypes` | `(ModelHttp.scopeConditions P hp).sat_renameTypes` | 証明済み |
| 56 | ModelHttp.builtins | admits_renameTypes | `(ModelHttp.substitutionAssumptions P).admits_renameTypes` | `(ModelHttp.scopeConditions P hp).admits_renameTypes` | 証明済み |
| 57 | ModelHttp.builtins | sat_subst | `(ModelHttp.substitutionAssumptions P).sat_subst` | `(ModelHttp.scopeConditions P hp).sat_subst` | 証明済み |
| 58 | ModelHttp.builtins | admits_subst | `(ModelHttp.substitutionAssumptions P).admits_subst` | `(ModelHttp.scopeConditions P hp).admits_subst` | 証明済み |
| 59 | ModelHttp.builtins | delta_typed | `ModelHttp.delta_typed` | `(ModelHttp.scopeConditions P hp).delta_typed` | 証明済み |
| 60 | ModelHttp.builtins | io_typed | `ModelHttp.io_typed` | `(ModelHttp.scopeConditions P hp).io_typed` | 証明済み |
| 61 | ModelHttp.builtins | io_kind | `ModelHttp.io_kind` | `(ModelHttp.scopeConditions P hp).io_kind` | 証明済み |
| 62 | ModelHttp.builtins | io_exists | `ModelHttp.io_exists` | `(ModelHttp.scopeConditions P hp).io_exists` | 証明済み |
| 63 | ModelHttp.builtins | sig_scoped | `ModelHttp.sig_scoped` | `(ModelHttp.scopeConditions P hp).sig_scoped` | 証明済み |
| 64 | ModelHttp.builtins | sat_unconstrained | `ModelHttp.sat_unconstrained` | `(ModelHttp.scopeConditions P hp).sat_unconstrained` | 証明済み |
| 65 | ModelHttp.builtins | admits_sat | `ModelHttp.admits_sat` | `(ModelHttp.scopeConditions P hp).admits_sat` | 証明済み |
| 66 | ModelHttp.builtins | pathBases_shape | `ModelHttp.pathBases_shape` | `(ModelHttp.scopeConditions P hp).pathBases_shape` | 証明済み |
| 67 | ModelHttp.builtins | io_op | `ModelHttp.io_op` | `(ModelHttp.scopeConditions P hp).io_op` | 証明済み |
| 68 | ModelHttp.builtins | opEff_io | `ModelHttp.opEff_io` | `(ModelHttp.scopeConditions P hp).opEff_io` | 証明済み |
| 69 | ModelHttp.builtins | effect_ops | `ModelHttp.effect_ops` | `(ModelHttp.scopeConditions P hp).effect_ops` | 証明済み |
| 70 | ModelHttp.builtins | state_effect | `ModelHttp.state_effect` | `(ModelHttp.scopeConditions P hp).state_effect` | 証明済み |
| 71 | ModelHttp.builtins | ref_get | `ModelHttp.ref_get` | `(ModelHttp.scopeConditions P hp).ref_get` | 証明済み |
| 72 | ModelHttp.builtins | ref_set | `ModelHttp.ref_set` | `(ModelHttp.scopeConditions P hp).ref_set` | 証明済み |
| 73 | ModelHttp.builtins | store_shape | `ModelHttp.store_shape` | `(ModelHttp.scopeConditions P hp).store_shape` | 証明済み |
| 74 | ModelHttp.builtins | store_admits | `ModelHttp.store_admits` | `(ModelHttp.scopeConditions P hp).store_admits` | 証明済み |
| 75 | ModelHttp.builtins | io_target | `(ModelHttp.targetAgreement P).io_target` | `(ModelHttp.scopeConditions P hp).io_target` | 証明済み |

独立の未完は0欄である。Model と ModelTargets の実証明は取り込み済みの本番を使い、ModelHttp の証明を追加した。Core の無条件の充足と主定理の閉鎖は、この75欄から結論しない。
