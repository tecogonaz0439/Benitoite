# P3b: 文脈に依存する部分型の棚卸し

P1 inventory.pyをコピーしてRV-P1 S2の検索語を足した。コメント除去・宣言分割は同じ。字面の候補であり、修正必須数・推移的な依存数・派生定理数を保証しない。分類は既存の宣言名と本体の字面から付けた点検の入口である。

## 集計

| 範囲 | 旧直接D | 旧追加構造S | 文脈検索C | 新直接D∪C | 追加直接 | うちS内 | D∪S外の脱落 | 新追加構造 | 新全和集合 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Release | 75 | 515 | 94 | 116 | 41 | 10 | 31 | 505 | 621 |
| Surface | 20 | 159 | 23 | 36 | 16 | 7 | 9 | 152 | 188 |

DとSは定義上重ならない。追加直接はC−D、既に構造候補の分は(C−D)∩S、脱落はC−(D∪S)。新しい追加構造はS−C。直接95はRelease75とSurface20の計であり、構造515はReleaseだけである。D全体95∪SのRelease515は610件。Surfaceの構造159も含む旧全候補は769件となる。

## RV-P1の24/3との差と採る候補

| 範囲 | 字面の脱落 | 無関係hle | 復元するRV件数 | RVより追加の意味ある候補 | 採る脱落 | 採る直接 | 採る全和集合 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Release | 31 | 1 | 24 | 6 | 30 | 115 | 620 |
| Surface | 9 | 1 | 3 | 5 | 8 | 35 | 187 |

RVの全脱落リストは提供されていないため、24/3は本書で復元した集合の件数である。RV本人の全集合と一致したとまでは主張しない。ReleaseはV_Sub/C_Subを含む23件とprogress_runの未使用のhle 1件、SurfaceはBuilderCaptureのreads 2件とReturnTry.withReturn 1件で24/3となる。これにK_Subで実際のTy.Leを運ぶRelease 6件と、E_Sub/B_SubへcheckerのTy.Leを渡すSurface 5件を追加する。単に24/3へ戻すためにこの11件を除かない。無関係なhleはRelease/Order/Tree.leanのtreesCompare_isLE_transとSurface/Lemmas/Dict.leanのclause_outer_instantiateであり、字面の一覧には残すが推す優先集合から除く。

推す直接集合150は旧95から55増え、そのうち17は既に構造候補、38は旧直接・旧構造の双方の外である。全構造674を含む旧全候補769との和集合は807。Releaseの構造515だけと旧直接95を合わせた610を基準にするなら、追加の意味ある未重複候補45を加えて655となる（Surfaceの構造159の全体を含まないので807と混同しない）。

## 優先集合

P1の型基盤の集合F（Type*・RangeInst*・RangeWF*・Normalize*・FiniteSupport*・Order/の旧追加構造）と、無関係hleを除いた新直接の和集合を推す。変更種にTy.Leの文脈依存化（Γ・Φ）を明示した。

| 範囲 | F | 採る直接 | 優先和集合 | 優先外の候補 |
|---|---:|---:|---:|---:|
| Release | 269 | 115 | 384 | 236 |
| Surface | 0 | 35 | 35 | 152 |

F269と採る直接150は今回重ならないので、優先集合は419件（旧364から55増）。残り388件も修正不要とはしない。変数表現を変えるM1の判断は、優先外を含む型・効果の構造の候補へ波及しうる。これは修正件数の見積りの更新そのものではなく、点検する入口の更新である。

## M1: Natの交換・合成の既存候補

宣言名だけに大文字小文字を区別せず、依頼のregex `shift.*subst|subst.*shift|subst.*comp|bind.*comp|inst.*shift|shift.*inst|inst.*subst|subst.*inst|shift.*comm|shift.*comp` を当てる。補足のregex `subst.*subst|instR.*instR|shift.*shift|bind.*bind` は同じ操作を重ねる名前の合成も拾う。コメント除去・宣言分割は上と同じで、theorem/lemmaだけを数える。名前の一致は意味の交換則の網羅ではない。新しい四namespaceへ必要な全数・修正必須数・証明工数とは解釈しない。二つの検索に重なる定理は和集合で一度だけ数える。

| 範囲 | 依頼regex | 補足regex | 和集合 | 旧D∪S外 |
|---|---:|---:|---:|---:|
| Release | 44 | 3 | 47 | 12 |
| Surface | 0 | 0 | 0 | 0 |

Release47にはshift.*compが拾うshift_compare等の比較の保存7件も含む。SubstOk.instのように名前空間のSubstを拾うものもある。47を厳密な交換定理の数と呼ばない。Surfaceの0も、SurfaceがReleaseの交換補題へ依存しないことを意味しない。

このM1集合はS2の優先419へ機械的に加算しない。P1のmap/bindの統一と、本番Natのcutoff・shift・substAt・instRの交換群とを比較するための別の軸である。値binderを型・効果へ追加した場合の新しい交換補題は、この既存の実数に含まれない。

M1を含めて全ての軸の候補を一つにする場合は、S2候補807とM1候補47の重複を除き、未重複12を加えた819件となる。これは優先集合419の件数とは別である。

## RVの24/3を復元する集合

| 範囲 | ファイル | 行 | 宣言 | 変更種 |
|---|---|---:|---|---|
| Release | formal/Benitoite/Release/Lemmas/Canonical.lean | 21 | `HasTypeVQ.inhabits'` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 78 | `HasTypeVQ.fnRef_admissible` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 348 | `HasTypeCQ.inv_escape` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 564 | `HasTypeCQ.ret_value` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Irrelevant.lean | 75 | `HasTypeVQ.subst_congr` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Irrelevant.lean | 110 | `HasTypeCQ.subst_congr` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Names.lean | 135 | `HasTypeVQ.lambdaNamesWF` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Names.lean | 171 | `HasTypeCQ.lambdaNamesWF` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/NoFailContext.lean | 9 | `HasTypeVQ.q_mono` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/NoFailContext.lean | 45 | `HasTypeCQ.q_mono` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Progress.lean | 118 | `HasTypeCQ.resume_form` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Progress.lean | 463 | `progress_run` | Ty.Leの文脈依存化（Γ・Φ）、逆転の結果に部分型を含む（この証拠は未使用） |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 181 | `HasTypeVQ.rename` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 226 | `HasTypeCQ.rename` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 339 | `HasTypeVQ.store` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 375 | `HasTypeCQ.store` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 446 | `HasTypeVQ.hide` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/StoreLemmas.lean | 111 | `HasTypeVQ.notCont` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/SubstTyping.lean | 192 | `HasTypeVQ.subst` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入 |
| Release | formal/Benitoite/Release/Lemmas/SubstTyping.lean | 242 | `HasTypeCQ.subst` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入 |
| Release | formal/Benitoite/Release/LocalScope.lean | 68 | `HasTypeVQ.localRefs` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/LocalScope.lean | 104 | `HasTypeCQ.localRefs` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Model.lean | 391 | `lambda_names_wellFormed` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Typing.lean | 724 | `hideBuilders_strengthen_val` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Surface | formal/Benitoite/Surface/Lemmas/BuilderCapture.lean | 107 | `HasTypeVQ.reads` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Surface | formal/Benitoite/Surface/Lemmas/BuilderCapture.lean | 136 | `HasTypeCQ.reads` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Surface | formal/Benitoite/Surface/Lemmas/ReturnTry.lean | 15 | `HasTypeCQ.withReturn` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |

## 復元したRV件数へ追加する意味ある候補

| 範囲 | ファイル | 行 | 宣言 | 変更種 |
|---|---|---:|---|---|
| Release | formal/Benitoite/Release/Lemmas/ClauseIx.lean | 188 | `ContTyOld.toNew` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ClauseIx.lean | 203 | `ContTy.toOld` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 19 | `ContTy.store` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 100 | `ContTy.mono_end` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 172 | `ContTy.inv_release` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 215 | `ContTy.inv_drop` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 369 | `accept_expr` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 378 | `accept_block` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 387 | `accept_expr_eff` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 396 | `accept_block_eff` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 405 | `accept_block_effCover` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |

## 字面だけ一致した局所名

| 範囲 | ファイル | 行 | 宣言 | 変更種 |
|---|---|---:|---|---|
| Release | formal/Benitoite/Release/Order/Tree.lean | 109 | `treesCompare_isLE_trans` | 部分型と無関係な局所名（優先集合から除外） |
| Surface | formal/Benitoite/Surface/Lemmas/Dict.lean | 101 | `clause_outer_instantiate` | 部分型と無関係な局所名（優先集合から除外） |

## 追加直接だが旧構造に入っていた定理

| 範囲 | ファイル | 行 | 宣言 | 変更種 |
|---|---|---:|---|---|
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 297 | `ContTy.split` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/FailureCont.lean | 142 | `ContTy.split_failure` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/OuterC.lean | 46 | `HasTypeVQ.outer` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/OuterC.lean | 102 | `HasTypeCQ.outer` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/PresFailure.lean | 60 | `pres_failure` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Progress.lean | 224 | `progress_ret` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Regularity.lean | 139 | `HasTypeVQ.wf` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Regularity.lean | 205 | `HasTypeCQ.wf` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/TySubstMain.lean | 604 | `HasTypeVQ.substTy` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/TySubstMain.lean | 739 | `HasTypeCQ.substTy` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 581 | `checking_accept_expr_ok` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 600 | `checking_accept_block_ok` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/BlockSequence.lean | 15 | `HasBlockQ.desugar_of_expr` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 65 | `HasHoleArgsQ.desugar_of_expr` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 391 | `HasTypeQ.desugar` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 819 | `HasHoleArgsQ.desugar` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 917 | `HasBlockQ.desugar` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |

## Natの交換・合成の候補一覧

| 範囲 | ファイル | 行 | 宣言 | 変更種 |
|---|---|---:|---|---|
| Release | formal/Benitoite/Release/EffectCover.lean | 166 | `Eff.allows_bind_comp` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/Closed.lean | 709 | `ClosedSubst.inst` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/Dict.lean | 29 | `Ty.shift_subst_append` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/Dict.lean | 45 | `Ty.shiftList_subst_append` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/Irrelevant.lean | 33 | `SubstAgree.shiftEnv` | 置換と値代入、環境・番号・ストア・戻り先の変更、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/SubstTyping.lean | 139 | `SubstOk.shiftE` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/SubstTyping.lean | 342 | `SubstOk.inst` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/SubstTyping.lean | 363 | `SubstOk.inst_prefix` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/TyLemmas.lean | 93 | `Ty.shiftList_substAt` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/TySubst.lean | 105 | `shiftEnv_substAt` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Lemmas/TySubstMain.lean | 510 | `ImplDecl.subst_substAt` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/LocalRef.lean | 21 | `LocalRef.subst_comp` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/LocalTyping.lean | 144 | `LocalSubstOk.instantiate` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Order/Shift.lean | 15 | `Ty.shift_compare_norm` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Order/Shift.lean | 20 | `Ty.shift_compare` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Order/Shift.lean | 31 | `Ty.shift_compareList` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 276 | `Ty.rawInstR_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 281 | `Ty.rawInstRTys_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 287 | `Eff.rawInstR_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 294 | `Ty.instR_shift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 300 | `Ty.instTarget_shift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 341 | `Eff.instAtoms_substAtoms` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 423 | `SubstEnv.at_rawInstR` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 441 | `Ty.instR_substAt` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 449 | `Eff.norm_rawInstR_substAt` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 471 | `Ty.instR_substAt_of_rangeFree` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 525 | `Ty.instTarget_substAt` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/SubstEnv.lean | 53 | `SubstEnv.rowsOnly_compose` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/SubstEnv.lean | 59 | `Eff.substRho_composeRows` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/SubstEnv.lean | 65 | `Ty.bindTys_comp_map` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 227 | `Eff.bind_comp_of_types` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 279 | `Ty.bind_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 322 | `Ty.bindTys_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 333 | `Eff.bind_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 41 | `Eff.substRho_comp` | 置換と値代入、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 71 | `Ty.subst_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 93 | `Ty.subst_comp_list` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 117 | `SubstEnv.shift_at_types` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 163 | `Ty.shift_substAt` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 231 | `Eff.substAt_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 288 | `Eff.shift_substAt` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 51 | `shiftIndex_compare` | 環境・番号・ストア・戻り先の変更、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 60 | `Ty.rawShift_compare` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 66 | `Ty.rawShiftTys_compare` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 75 | `Eff.rawShift_compare` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 149 | `Ty.shift_eq_norm_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 154 | `Ty.shiftTys_eq_norm_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |

## 更新した優先集合

| 範囲 | ファイル | 行 | 宣言 | 変更種 |
|---|---|---:|---|---|
| Release | formal/Benitoite/Release/CoverCompat.lean | 33 | `Ty.LeOld.le` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/CoverCompat.lean | 39 | `Ty.le_iff_leOld` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/FiniteSupport.lean | 151 | `Ty.support_of_norm` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/FiniteSupport.lean | 163 | `Ty.supportList_of_norm` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/FiniteSupport.lean | 168 | `Eff.support_of_norm` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/FiniteSupport.lean | 179 | `Eff.norm_fails_support` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/FiniteSupport.lean | 188 | `Eff.support_of_sub` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Basic.lean | 63 | `refl` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/Basic.lean | 65 | `trans` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/Basic.lean | 74 | `fn_left` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/Basic.lean | 81 | `fn_right` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/Basic.lean | 88 | `eq_of_not_fn` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/Basic.lean | 94 | `eq_of_not_fn_left` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/Basic.lean | 99 | `substAt` | Ty.Leの文脈依存化（Γ・Φ）、置換と値代入 |
| Release | formal/Benitoite/Release/Lemmas/Basic.lean | 106 | `subst` | Ty.Leの文脈依存化（Γ・Φ）、置換と値代入 |
| Release | formal/Benitoite/Release/Lemmas/Basic.lean | 109 | `shift` | Ty.Leの文脈依存化（Γ・Φ）、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/BuilderTyping.lean | 26 | `HasTypeVQ.canonical_bytes` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Canonical.lean | 21 | `HasTypeVQ.inhabits'` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Canonical.lean | 63 | `HasTypeVQ.canonical_boolean` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Canonical.lean | 99 | `HasTypeVQ.canonical_ref` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Canonical.lean | 135 | `HasTypeVQ.canonical_lazy` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Canonical.lean | 227 | `HasTypeVQ.inv_list_wf` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/ClauseIx.lean | 188 | `ContTyOld.toNew` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ClauseIx.lean | 203 | `ContTy.toOld` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 19 | `ContTy.store` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 100 | `ContTy.mono_end` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 133 | `ContTy.inv_nil` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 141 | `ContTy.inv_let` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 152 | `ContTy.inv_mark` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 162 | `ContTy.inv_update` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 172 | `ContTy.inv_release` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 184 | `ContTy.inv_handle` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 202 | `ContTy.inv_handle_tail` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 215 | `ContTy.inv_drop` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 227 | `ContTy.inv_guard` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 260 | `ContTy.resume_append` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ |
| Release | formal/Benitoite/Release/Lemmas/ContLemmas.lean | 297 | `ContTy.split` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/EffectSound.lean | 103 | `no_unhandledOp` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/FailureCont.lean | 142 | `ContTy.split_failure` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/FailureCont.lean | 240 | `HasTypeVQ.inv_raise` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/FailureCont.lean | 255 | `HasTypeCQ.inv_handle_failure` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/FailureCont.lean | 274 | `HasTypeCQ.inv_raise_app` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 25 | `HasTypeVQ.inv_var` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 43 | `HasTypeVQ.inv_const` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 59 | `HasTypeVQ.inv_fnRef` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 78 | `HasTypeVQ.fnRef_admissible` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 95 | `HasTypeVQ.inv_prim` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 116 | `HasTypeVQ.inv_op` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 135 | `HasTypeVQ.inv_lam_wf` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 156 | `HasTypeVQ.inv_lam` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 163 | `HasTypeVQ.inv_con` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 182 | `HasTypeVQ.inv_list` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 200 | `HasTypeVQ.inv_loc` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 223 | `HasTypeCQ.inv_ret` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 243 | `HasTypeCQ.inv_let` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 266 | `HasTypeCQ.inv_app` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 289 | `HasTypeCQ.inv_ite` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 312 | `HasTypeCQ.inv_match` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 328 | `HasTypeCQ.inv_lazy` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 348 | `HasTypeCQ.inv_escape` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 366 | `HasTypeCQ.inv_use` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 389 | `HasTypeCQ.inv_handle` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 417 | `HasTypeCQ.inv_resumeL` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 440 | `HasTypeCQ.inv_resumeVar` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 466 | `HasTypeVQ.inv_mapV` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 476 | `HasTypeVQ.inv_setV` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 486 | `HasTypeVQ.inv_bytesV` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 500 | `HasTypeVQ.inv_checked` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 513 | `HasTypeVQ.inv_checkedRequest` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 523 | `HasTypeVQ.inv_dict` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 534 | `HasTypeVQ.inv_super` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 545 | `HasTypeCQ.inv_meth` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 564 | `HasTypeCQ.ret_value` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 575 | `HasTypeCQ.inv_builderLet` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Inversion.lean | 591 | `HasTypeCQ.inv_builderOp` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Irrelevant.lean | 75 | `HasTypeVQ.subst_congr` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Irrelevant.lean | 110 | `HasTypeCQ.subst_congr` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/MembershipBase.lean | 70 | `HasTypeVQ.canonical_opaque` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Names.lean | 135 | `HasTypeVQ.lambdaNamesWF` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Names.lean | 171 | `HasTypeCQ.lambdaNamesWF` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/NoFailContext.lean | 9 | `HasTypeVQ.q_mono` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/NoFailContext.lean | 45 | `HasTypeCQ.q_mono` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/OuterC.lean | 46 | `HasTypeVQ.outer` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/OuterC.lean | 102 | `HasTypeCQ.outer` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/PresBase.lean | 155 | `stE_ret` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/PresBase.lean | 178 | `store_prim_inv` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/PresFailure.lean | 60 | `pres_failure` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/PresHelpers.lean | 145 | `ContTy.markPush` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/PresMain.lean | 19 | `preservationE` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Preservation.lean | 17 | `Ty.Le.fn_fn'` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/Preservation.lean | 24 | `inv_prim_app` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Preservation.lean | 36 | `inv_op_app` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Preservation.lean | 133 | `pres_op_common` | Ty.Leの文脈依存化（Γ・Φ）、K_Subの部分型を同じ閉じた契約の下で保つ、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Progress.lean | 17 | `HasTypeVQ.canonical_fn_or_raise` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/Progress.lean | 55 | `HasTypeVQ.canonical_dict` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Progress.lean | 118 | `HasTypeCQ.resume_form` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Progress.lean | 224 | `progress_ret` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Progress.lean | 421 | `progress_app` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/Progress.lean | 463 | `progress_run` | Ty.Leの文脈依存化（Γ・Φ）、逆転の結果に部分型を含む（この証拠は未使用） |
| Release | formal/Benitoite/Release/Lemmas/Regularity.lean | 139 | `HasTypeVQ.wf` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Regularity.lean | 205 | `HasTypeCQ.wf` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 181 | `HasTypeVQ.rename` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 226 | `HasTypeCQ.rename` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 339 | `HasTypeVQ.store` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 375 | `HasTypeCQ.store` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/Rename.lean | 446 | `HasTypeVQ.hide` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Lemmas/StepSound.lean | 102 | `step_soundE` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/Lemmas/StoreLemmas.lean | 111 | `HasTypeVQ.notCont` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Lemmas/SubstTyping.lean | 192 | `HasTypeVQ.subst` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入 |
| Release | formal/Benitoite/Release/Lemmas/SubstTyping.lean | 242 | `HasTypeCQ.subst` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入 |
| Release | formal/Benitoite/Release/Lemmas/TySubstMain.lean | 604 | `HasTypeVQ.substTy` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Lemmas/TySubstMain.lean | 739 | `HasTypeCQ.substTy` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/LocalScope.lean | 68 | `HasTypeVQ.localRefs` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/LocalScope.lean | 104 | `HasTypeCQ.localRefs` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Release | formal/Benitoite/Release/Model.lean | 290 | `super_call_typed` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Model.lean | 391 | `lambda_names_wellFormed` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Release | formal/Benitoite/Release/Normalize.lean | 57 | `normTys_sortUnique` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 76 | `Ty.norm_idem` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 80 | `Ty.normTys_idem` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 86 | `Eff.norm_idem` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 96 | `Eff.norm_memFail` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 125 | `Ty.norm_legacy` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 139 | `Ty.normTys_legacy` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 146 | `Eff.norm_legacy` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 171 | `Ty.canonical_of_failsLeOne` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 186 | `Ty.canonicalTys_of_failsLeOne` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Normalize.lean | 192 | `Eff.canonical_of_failsLeOne` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Order/Shift.lean | 15 | `Ty.shift_compare_norm` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Order/Shift.lean | 20 | `Ty.shift_compare` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Order/Shift.lean | 24 | `shift_map` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Order/Shift.lean | 31 | `Ty.shift_compareList` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/Order/Shift.lean | 38 | `Ty.sortUnique_shift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 143 | `Eff.instAtoms_of_wf_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 191 | `Ty.instR_nil` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 198 | `Ty.rawInstR_of_rangesIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 215 | `Ty.rawInstRTys_of_rangesIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 222 | `Eff.rawInstR_of_rangesIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 230 | `Ty.instR_of_rangesIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 238 | `Ty.norm_rawInstR` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 242 | `Ty.normTys_rawInstR` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 248 | `Eff.norm_rawInstR` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 262 | `Eff.norm_instR` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 270 | `Ty.instR_norm` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 276 | `Ty.rawInstR_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 281 | `Ty.rawInstRTys_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 287 | `Eff.rawInstR_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 294 | `Ty.instR_shift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 300 | `Ty.instTarget_shift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 313 | `Ty.rawInstR_rawApplyTo` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 324 | `Eff.test_rawInstR` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 328 | `Eff.fails_rawInstR` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 341 | `Eff.instAtoms_substAtoms` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 374 | `Eff.rowFails_rawInstR` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 386 | `Ty.rawInstR_rawBind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 393 | `Ty.rawInstRTys_rawBind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 399 | `Eff.rawInstR_rawBind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 412 | `Ty.instR_bind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 417 | `Eff.norm_rawInstR_bind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 423 | `SubstEnv.at_rawInstR` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 441 | `Ty.instR_substAt` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 449 | `Eff.norm_rawInstR_substAt` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 460 | `Ty.substAt_rows_norm` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 471 | `Ty.instR_substAt_of_rangeFree` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 502 | `Ty.TopRangeFree.shift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 512 | `Ty.TopRangeFree.applyTo` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 559 | `Ty.rawInstR_rawWF` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 577 | `Ty.rawInstRTys_rawWF` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 583 | `Eff.rawInstR_rawWF` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 591 | `Ty.instR_wf_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 596 | `Eff.instR_wf_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 607 | `Ty.instTarget_wf_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 647 | `Ty.VarsIn.raw` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 659 | `Ty.VarsInList.raw` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 665 | `Eff.VarsIn.raw` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 673 | `Ty.rawInstR_rawVarsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 689 | `Ty.rawInstRTys_rawVarsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 695 | `Eff.rawInstR_rawVarsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 707 | `Ty.norm_rawVarsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 722 | `Ty.normTys_rawVarsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 728 | `Eff.norm_rawVarsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 738 | `Ty.instR_varsIn_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 743 | `Eff.instR_varsIn_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 762 | `Ty.RangesInList.iff` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 780 | `PrimSig.scoped_iff_scopedRanges` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 813 | `PrimSig.inst_nil_of_canonical` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 828 | `PrimSig.inst_nil` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 844 | `PrimSig.inst_of_scoped` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 889 | `PrimSig.inst_ret_eff_wf_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 896 | `PrimSig.inst_wf_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 920 | `PrimSig.scoped_iff` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 932 | `PrimSig.Scoped.inst_wf_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 949 | `PrimSig.Scoped.vars_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 959 | `PrimSig.Scoped.inst_varsIn_zero` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeInst.lean | 977 | `PrimSig.Scoped.inst_ret_of_opEff` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 119 | `Ty.wf_iff_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 167 | `Ty.wfList_iff_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 178 | `Eff.wf_iff_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 187 | `Ty.varsIn_iff_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 229 | `Ty.varsInList_iff_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 253 | `Ty.RangesIn.opaque` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 265 | `Ty.RangesInList.opaque` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 271 | `Eff.RangesIn.opaque` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 279 | `Ty.WF.old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 282 | `Ty.wf_iff_old_of_opaqueRangesIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 321 | `Ty.wf_iff_old_of_rangeFree` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 326 | `Ty.VarsIn.old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 330 | `Ty.varsIn_iff_old_of_rangeFree` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 341 | `sat_unconstrained_iff_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 349 | `sat_unconstrained_of_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 354 | `sat_local_iff_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 361 | `sat_local_of_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 366 | `admits_local_iff_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 378 | `admits_local_of_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 401 | `PrimSig.scoped_iff_old` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/RangeWF.lean | 416 | `sig_scoped_iff_old_of_rangeFree` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TargetStepExamples.lean | 64 | `inv_prim_app_eff` | Ty.Leの文脈依存化（Γ・Φ） |
| Release | formal/Benitoite/Release/TypeBounds.lean | 60 | `Ty.WF.raw` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 73 | `Ty.WFList.raw` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 78 | `Eff.WF.raw` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 85 | `Ty.norm_rawWF` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 100 | `Ty.normTys_rawWF` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 105 | `Eff.norm_rawWF` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 133 | `Ty.rawBind_rawWF` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 150 | `Ty.rawBindTys_rawWF` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 157 | `Eff.rawBind_rawWF` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 175 | `Eff.substAt_atoms_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 188 | `Ty.bind_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 195 | `Ty.rawShift_eq_rawBind` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 201 | `Ty.rawShiftTys_eq_rawBindTys` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 207 | `Eff.rawShift_eq_rawBind` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 215 | `Ty.shift_wf` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 223 | `Ty.substAt_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 245 | `Ty.subst_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 260 | `Eff.bind_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 266 | `Eff.subst_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 278 | `Ty.substList_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeBounds.lean | 288 | `Eff.substAt_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 13 | `Eff.mem_rawBind_rowImage` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 34 | `Eff.memFail_rawBind_rowImage` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 52 | `Eff.norm_ext` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 60 | `Ty.bind_congr_rows` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 87 | `Ty.bindTys_congr_rows` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 97 | `Eff.bind_congr_rows` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 126 | `Eff.substRho_congr_rows` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 154 | `Eff.memFail_bind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 167 | `Eff.bind_row` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 201 | `Ty.rawBind_rawApplyTo` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 211 | `Ty.bind_applyTo` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 223 | `Ty.bind_norm` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 227 | `Eff.bind_comp_of_types` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 279 | `Ty.bind_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 322 | `Ty.bindTys_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 333 | `Eff.bind_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 354 | `Eff.bind_union` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeComposition.lean | 366 | `Eff.bind_ofAtoms_noRhos` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 15 | `Ty.bind_congr_scoped` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 43 | `Ty.bindTys_congr_scoped` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 53 | `Eff.bind_congr_scoped` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 85 | `Ty.rawBind_identity` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 90 | `Ty.rawBindTys_identity` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 95 | `Eff.rawBind_identity` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 103 | `Ty.bind_identity` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 106 | `Eff.bind_identity` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 109 | `Eff.rowImage_normEnv` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 115 | `Ty.bind_normEnv` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeCongruence.lean | 119 | `Ty.bind_congr_scoped_norm` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 16 | `Ty.WF.canonical` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 29 | `Ty.WFList.norm_eq` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 36 | `Ty.norm_WF` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 41 | `Ty.WFList.iff` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 47 | `Eff.norm_WF` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 70 | `Ty.Le.wf` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 76 | `Ty.Le.wf_rev` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 82 | `Ty.WF.mono` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 97 | `Ty.WFList.mono` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 102 | `Eff.WF.mono` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 109 | `Ty.rawShift_of_wf` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 124 | `Ty.rawShiftTys_of_wf` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 130 | `Eff.rawShift_of_wf` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 136 | `Ty.shift_of_wf` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRegularity.lean | 139 | `Eff.shift_of_wf` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRows.lean | 31 | `Ty.RowsInList.iff` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRows.lean | 38 | `Ty.RowsIn.mono` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRows.lean | 52 | `Ty.RowsInList.mono` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRows.lean | 58 | `Eff.RowsIn.mono` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRows.lean | 66 | `Ty.norm_rowsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRows.lean | 79 | `Ty.normTys_rowsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRows.lean | 85 | `Eff.norm_rowsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRows.lean | 95 | `Ty.rowsIn_true` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeRows.lean | 102 | `Ty.rowsInList_true` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 51 | `Ty.substAt_of_closed` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 62 | `Ty.substAtList_of_closed` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 71 | `Ty.subst_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 93 | `Ty.subst_comp_list` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 101 | `SubstEnv.at_type_closed` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 117 | `SubstEnv.shift_at_types` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 141 | `Eff.shift_at_rowImages` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 163 | `Ty.shift_substAt` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 177 | `Eff.substAt_fails` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 187 | `Ty.substAt_nil_of_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 198 | `Ty.substAtList_nil_of_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 205 | `Eff.substRho_nil_norm` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 219 | `Eff.substAt_nil_of_wf` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 231 | `Eff.substAt_comp` | 置換と値代入、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 268 | `Eff.substAt_name` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 288 | `Eff.shift_substAt` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeScopedSubst.lean | 304 | `Eff.substAt_norm` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 60 | `Ty.rawShift_compare` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 66 | `Ty.rawShiftTys_compare` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 75 | `Eff.rawShift_compare` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 85 | `Ty.norm_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 89 | `Ty.normTys_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 95 | `Eff.norm_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 107 | `Ty.rawShift_canonical` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 112 | `Eff.rawShift_canonical` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 149 | `Ty.shift_eq_norm_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 154 | `Ty.shiftTys_eq_norm_rawShift` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補、Natの移動・置換・具体化の交換／合成の名前による候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 163 | `Ty.shift_canonical` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 166 | `Eff.shift_canonical` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 169 | `Ty.rawShift_zero` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 172 | `Ty.rawShiftTys_zero` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 177 | `Eff.rawShift_zero` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 183 | `Ty.shift_zero_norm` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeShift.lean | 186 | `Eff.shift_zero_norm` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 19 | `TyCon.norm_rawApply` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 27 | `Ty.norm_rawApplyTo` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 34 | `Ty.norm_rawBind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 45 | `Ty.normTys_rawBind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 51 | `Eff.norm_rawBind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 65 | `Ty.rawBind_norm_congr` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 70 | `Eff.memFail_rawBind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 115 | `Eff.mem_rawBind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 120 | `Eff.bind_mono` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 144 | `Eff.substAt_mono` | 置換と値代入、環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 151 | `Eff.substAtoms_map_norm` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 163 | `Eff.rowFails_map_norm` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 191 | `Ty.rawApplyTo_norm_congr` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 198 | `Ty.norm_rawBind_normEnv` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 208 | `Ty.normTys_rawBind_normEnv` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 214 | `Eff.norm_rawBind_normEnv` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 229 | `SubstEnv.at_norm` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 249 | `Ty.norm_substAt` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 256 | `Eff.norm_substAt` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 269 | `Ty.substAt_eq_rawBind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 288 | `Ty.substTysAt_eq_rawBindTys` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 297 | `Ty.substAt_eq_bind` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 327 | `Ty.rawShift_legacy` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 340 | `Ty.rawShiftTys_legacy` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 346 | `Eff.rawShift_legacy` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 363 | `Ty.rawBind_legacy` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 379 | `Ty.rawBindTys_legacy` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 386 | `Eff.rawBind_legacy` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 395 | `Ty.shift_eq_raw_of_legacy` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 398 | `Eff.shift_eq_raw_of_legacy` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 402 | `SubstEnv.at_legacy` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 421 | `Ty.substAt_eq_raw_of_legacy` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSubstLemmas.lean | 428 | `Eff.substAt_eq_raw_of_legacy` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 32 | `Ty.norm_support` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 44 | `Ty.normTys_support` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 49 | `Eff.norm_support` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 58 | `Ty.rawShift_support` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 71 | `Ty.rawShiftTys_support` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 76 | `Eff.rawShift_support` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 82 | `Ty.shift_support` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 86 | `Eff.shift_support` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 101 | `Ty.rawBind_support` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 119 | `Ty.rawBindTys_support` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 125 | `Eff.rawBind_support` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 149 | `SubstEnv.at_support` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 168 | `Ty.substAt_support` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeSupport.lean | 175 | `Eff.substAt_support` | 置換と値代入、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 41 | `Ty.VarsInList.iff` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 49 | `Ty.VarsIn.wf` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 62 | `Ty.VarsInList.wf` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 67 | `Eff.VarsIn.wf` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 73 | `Ty.VarsIn.rows` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 85 | `Ty.VarsInList.rows` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 90 | `Eff.VarsIn.rows` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 105 | `Ty.VarsIn.mono` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 120 | `Ty.VarsInList.mono` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 126 | `Eff.VarsIn.mono` | 環境・番号・ストア・戻り先の変更、型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 133 | `Ty.norm_VarsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/TypeVariables.lean | 138 | `Eff.norm_VarsIn` | 型・効果の構造／変数表現の追随候補 |
| Release | formal/Benitoite/Release/Typing.lean | 724 | `hideBuilders_strengthen_val` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 133 | `accept_sound` | Ty.Leの文脈依存化（Γ・Φ） |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 176 | `join_sound` | Ty.Leの文脈依存化（Γ・Φ） |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 369 | `accept_expr` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 378 | `accept_block` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 387 | `accept_expr_eff` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 396 | `accept_block_eff` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 405 | `accept_block_effCover` | Ty.Leの文脈依存化（Γ・Φ）、checker成功からΓ・Φの下で部分型を導く |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 581 | `checking_accept_expr_ok` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/CheckLemmas.lean | 600 | `checking_accept_block_ok` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/CheckSupport.lean | 11 | `tyJoin_sound` | Ty.Leの文脈依存化（Γ・Φ） |
| Surface | formal/Benitoite/Surface/CheckTools.lean | 59 | `tyLe_sound` | Ty.Leの文脈依存化（Γ・Φ） |
| Surface | formal/Benitoite/Surface/ClauseIxExamples.lean | 128 | `top_clause_typed` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/CoverExamples.lean | 173 | `writeE_bound` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/CoverExamples.lean | 180 | `writeE_narrow` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/CoverExamples.lean | 187 | `callGE_bound` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/CoverExamples.lean | 338 | `main_typed` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Examples.lean | 238 | `program_effect_soundness` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/FiniteTools.lean | 234 | `tyLe_sound` | Ty.Leの文脈依存化（Γ・Φ） |
| Surface | formal/Benitoite/Surface/FiniteTools.lean | 253 | `tyJoin_sound` | Ty.Leの文脈依存化（Γ・Φ） |
| Surface | formal/Benitoite/Surface/Lemmas/BlockSequence.lean | 15 | `HasBlockQ.desugar_of_expr` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/BuilderCapture.lean | 107 | `HasTypeVQ.reads` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Surface | formal/Benitoite/Surface/Lemmas/BuilderCapture.lean | 136 | `HasTypeCQ.reads` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Surface | formal/Benitoite/Surface/Lemmas/CallHead.lean | 76 | `HasTypeQ.inv_funDicts` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Surface | formal/Benitoite/Surface/Lemmas/CallHead.lean | 110 | `HasTypeQ.inv_opDicts` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Surface | formal/Benitoite/Surface/Lemmas/CallHead.lean | 145 | `HasTypeQ.inv_methName` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/CallHead.lean | 188 | `directCallee_typed` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する |
| Surface | formal/Benitoite/Surface/Lemmas/Invariants.lean | 31 | `clean_le` | Ty.Leの文脈依存化（Γ・Φ） |
| Surface | formal/Benitoite/Surface/Lemmas/Invariants.lean | 39 | `clean_data_le` | Ty.Leの文脈依存化（Γ・Φ）、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/ReturnTry.lean | 15 | `HasTypeCQ.withReturn` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、環境・番号・ストア・戻り先の変更 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 65 | `HasHoleArgsQ.desugar_of_expr` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 168 | `HasTypeQ.desugar_partialCall` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 210 | `HasTypeQ.desugar_partialCon` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 391 | `HasTypeQ.desugar` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 819 | `HasHoleArgsQ.desugar` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
| Surface | formal/Benitoite/Surface/Lemmas/Typing.lean | 917 | `HasBlockQ.desugar` | Ty.Leの文脈依存化（Γ・Φ）、V_Sub/C_Subの導出と部分型の文脈変更を点検する、型・効果の構造／変数表現の追随候補 |
