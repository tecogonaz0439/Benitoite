# 群 S 後半の結果

2026-11-01。担当 Codex。指定ブランチ `m014/l10.s2`、B_WORK `42a09116fd2442fca93b38a7e18b8138356a8dcc`。値は起動依頼の指定であり、git による照合・切替・作成・コミットは行っていない。

**L10.44〜L10.51 の実装と担当検査を完了した。** 初回報告前にdetailの8行、foundationの分類、五つの境界、既定import、設計書の対応を自己点検した。初回の独立レビューは条件付き可であり、今回の処置の再レビュー・work・受け入れ・取り込みを取りまとめと設計者に残す。L10.52は開始していない。

## 単位ごとの完了と義務の照合

| 単位 | 判定 | 閉じた定義・補題とdetailの義務 |
|---|---|---|
| L10.44 | 完了・5件 | `TypeRegularity`。Ty/型列/Effの生の移動は入力と等しく、公開shiftは入力のnormと等しい。既存NormalWellFormedを再使用し、WFからCanonicalを仮定しない。Tel版は追加補助 |
| L10.45 | 完了・7件 | `TypeBounds`。rawBind三族は正規化後の新WFへ移す。`WFImages`は型像・行像・範囲像・観測できた値像のWFと型像のOrdinaryを分け、upで閉じる。`substAt_atoms_wf`、Ty.bind_wf、Ty/型列のrawShiftとrawBindの一致を閉じた。RawWFの層は追加していない |
| L10.46 | 完了・7件 | 同TypeBounds。EffのrawShift/rawBindの一致、Ty/EffのsubstAt/subst、Eff.bindと型列のsubstのWF。typeEnvAtの条件を有限列のWF/Ordinaryから構成し、型cutoff c、型像の上限n、外側値深さnvを区別した。結果の型深さはn+c |
| L10.47 | 完了・10件 | `TypeRows`。既存AdmissibleのRowsIn四族を再定義せず、支持の行原子への射影と同値にした。iff/mono/norm/trueを閉じ、refined・external・Tel・Fail内部を含めた。範囲のWFは別の条件 |
| L10.48 | 完了・12件 | `TypeVariables`。WF/RowsIn/RangesScopedを束ねたVarsIn、型列のiff、wf/rows/mono/norm。四名前空間を区別し、有限上限では既存SourceScopedと同じ条件になる。WFを前提とするRangesScopedと支持の同値、Tel版は追加補助 |
| L10.49 | 完了・8件 | `TypeShiftFacts`。shiftIndexの比較とTyのrawShift_canonicalを追加。生のTy/型列/Effの比較3件、norm交換3件は既存TypeShiftOrderの完全署名を直接再使用した |
| L10.50 | 完了・13件 | 同TypeShiftFacts。EffのrawShift_canonical、公開Ty/EffのCanonical、既存zero三件と公開shift_zero_norm二件、比較・型列の写像・型列の比較・sortUniqueの移動5件。既存のrefined/Telを含む移動の代数を再使用 |
| L10.51 | 完了・6件 | `EffectFacts`。singleFail、両包含からのCanonicalな効果の構造等号、Allowsの正規化不変性、TopAtomsの正規化保存、substRhoの空と名前の保存。Failの不変性と一原子Coversを区別した |

台帳内の件数は5+7+7+10+12+8+13+6=68である。初回の新規本番は6モジュール656行で、公開の定義・定理96、構造体WFImagesが1、private補助が1である。カーネルが生成する宣言を含む全252宣言を公理監査した。台帳の件数と、相互再帰の補助・生成宣言の件数を加算しない。

## foundation全158件の対応

[detail](../detail.md#foundation全158件の処分と本番追随)の分類は既済16・不要43・L10残99である。前群31件と本群68件により、**L10残99件の対応先はすべて閉じた**。合計は16+43+31+68=158であり、L10に未実装として残るfoundationは0件である。不要43件を実装済みに数えてはいない。

[foundation-map.json](foundation-map.json)は158行の機械可読の対応で、[foundation.lean](foundation.lean)は対応先115件の存在を実環境で確認する。言明の型の照合はsignatures.leanが担う。既存のprivateなnormTys_sortUniqueだけは、Normalizeのモジュールと完全名の末尾で一件を特定する。他の114件は完全名を直接照合した。前群31件は[前群の結果](../s1/results.md)と現在の宣言の存在を照合したもので、本群で再実装したとは数えない。

以下の宣言名は、新旧とも `Benitoite.Release.` を省き、新の `Refinement.` も省略する。既済の宣言も現在のRefinementにある。不要の理由の詳細と旧読者の最初の12件の担当はdetailを正とし、漏れていた二読者は末尾の表で補い、ここでは処分を明示する。

| ID | 旧宣言 | 処分・単位 | 新宣言又は移さない理由 |
|---|---|---|---|
| FND001 | `Ty.LeOld.le` | 不要 | 旧LeOldとの同値はD29の片方向の条件に不要 |
| FND002 | `Ty.le_iff_leOld` | 不要 | 旧LeOldとの同値はD29の片方向の条件に不要 |
| FND003 | `Eff.memFail_singleFail` | 本群で完了・L10.51 | `Eff.memFail_singleFail` |
| FND004 | `Eff.eq_of_sub_of_sub` | 本群で完了・L10.51 | `Eff.eq_of_sub_of_sub` |
| FND005 | `Eff.allows_norm` | 本群で完了・L10.51 | `Eff.allows_norm` |
| FND006 | `Eff.TopAtoms.norm` | 本群で完了・L10.51 | `Eff.TopAtoms.norm` |
| FND007 | `Eff.covers_norm_left` | 既済 | `Eff.covers_norm_left` |
| FND008 | `Eff.covers_norm_right` | 既済 | `Eff.covers_norm_right` |
| FND009 | `Ty.normWith_eq_norm` | 前群で完了・L10.43 | `Ty.normWith_eq_norm` |
| FND010 | `Ty.normTysWith_eq_norm` | 前群で完了・L10.43 | `Ty.normTysWith_eq_norm` |
| FND011 | `Eff.normWith_eq_norm_of_fails` | 前群で完了・L10.43 | `Eff.normWith_eq_norm_of_fails` |
| FND012 | `Eff.normWith_eq_norm` | 前群で完了・L10.43 | `Eff.normWith_eq_norm` |
| FND013 | `Ty.normWith_legacy` | 不要 | 旧Legacy表現への橋 |
| FND014 | `Ty.normTysWith_legacy` | 不要 | 旧Legacy表現への橋 |
| FND015 | `Eff.normWith_legacy` | 不要 | 旧Legacy表現への橋 |
| FND016 | `Ty.normWith_support` | 前群で完了・L10.43 | `Ty.normWith_support` |
| FND017 | `Eff.normWith_support` | 前群で完了・L10.43 | `Eff.normWith_support` |
| FND018 | `Ty.normWith_canonical` | 前群で完了・L10.43 | `Ty.normWith_canonical` |
| FND019 | `Eff.normWith_canonical` | 前群で完了・L10.43 | `Eff.normWith_canonical` |
| FND020 | `Ty.normWith_idem` | 前群で完了・L10.43 | `Ty.normWith_idem` |
| FND021 | `Eff.normWith_idem` | 前群で完了・L10.43 | `Eff.normWith_idem` |
| FND022 | `Ty.normWith_support_independent` | 前群で完了・L10.43 | `Ty.normWith_support_independent` |
| FND023 | `Eff.normWith_support_independent` | 前群で完了・L10.43 | `Eff.normWith_support_independent` |
| FND024 | `Ty.support_of_norm` | 前群で完了・L10.36 | `Ty.support_of_norm` |
| FND025 | `Ty.supportList_of_norm` | 前群で完了・L10.36 | `Ty.supportList_of_norm` |
| FND026 | `Eff.support_of_norm` | 前群で完了・L10.36 | `Eff.support_of_norm` |
| FND027 | `Eff.norm_fails_support` | 前群で完了・L10.37 | `Eff.norm_fails_support` |
| FND028 | `Eff.support_of_sub` | 前群で完了・L10.37 | `Eff.support_of_sub` |
| FND029 | `Eff.substRho_empty` | 本群で完了・L10.51 | `Eff.substRho_empty` |
| FND030 | `Eff.substRho_name` | 本群で完了・L10.51 | `Eff.substRho_name` |
| FND031 | `Ty.Le.refl` | 既済 | `Ty.LeQ.refl` |
| FND032 | `Ty.Le.trans` | 既済 | `Ty.LeQ.trans` |
| FND033 | `normTys_sortUnique` | 既済 | `normTys_sortUnique` |
| FND034 | `Ty.norm_idem` | 既済 | `Ty.norm_idem` |
| FND035 | `Ty.normTys_idem` | 既済 | `Ty.normTys_idem` |
| FND036 | `Eff.norm_idem` | 既済 | `Eff.norm_idem` |
| FND037 | `Eff.norm_memFail` | 既済 | `Eff.norm_memFail` |
| FND038 | `Ty.norm_legacy` | 不要 | 旧のさらに古いLegacy表現への橋 |
| FND039 | `Ty.normTys_legacy` | 不要 | 旧のさらに古いLegacy表現への橋 |
| FND040 | `Eff.norm_legacy` | 不要 | 旧のさらに古いLegacy表現への橋 |
| FND041 | `Ty.canonical_of_failsLeOne` | 不要 | failsLeOneからの旧Canonical |
| FND042 | `Ty.canonicalTys_of_failsLeOne` | 不要 | failsLeOneからの旧Canonical |
| FND043 | `Eff.canonical_of_failsLeOne` | 不要 | failsLeOneからの旧Canonical |
| FND044 | `Ty.shift_compare_norm` | 本群で完了・L10.50 | `Ty.shift_compare_norm` |
| FND045 | `Ty.shift_compare` | 本群で完了・L10.50 | `Ty.shift_compare` |
| FND046 | `shift_map` | 本群で完了・L10.50 | `shift_map` |
| FND047 | `Ty.shift_compareList` | 本群で完了・L10.50 | `Ty.shift_compareList` |
| FND048 | `Ty.sortUnique_shift` | 本群で完了・L10.50 | `Ty.sortUnique_shift` |
| FND049 | `Ty.wf_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND050 | `Ty.wfList_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND051 | `Eff.wf_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND052 | `Ty.varsIn_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND053 | `Ty.varsInList_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND054 | `Eff.varsIn_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND055 | `Ty.RangesIn.opaque` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND056 | `Ty.RangesInList.opaque` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND057 | `Eff.RangesIn.opaque` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND058 | `Ty.WF.old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND059 | `Ty.wf_iff_old_of_opaqueRangesIn` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND060 | `Ty.wf_iff_old_of_rangeFree` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND061 | `Ty.VarsIn.old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND062 | `Ty.varsIn_iff_old_of_rangeFree` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND063 | `sat_unconstrained_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND064 | `sat_unconstrained_of_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND065 | `sat_local_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND066 | `sat_local_of_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND067 | `admits_local_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND068 | `admits_local_of_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND069 | `PrimSig.scoped_iff_old` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND070 | `sig_scoped_iff_old_of_rangeFree` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋 |
| FND071 | `Ty.WF.raw` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない |
| FND072 | `Ty.WFList.raw` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない |
| FND073 | `Eff.WF.raw` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない |
| FND074 | `Ty.norm_rawWF` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない |
| FND075 | `Ty.normTys_rawWF` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない |
| FND076 | `Eff.norm_rawWF` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない |
| FND077 | `Ty.rawBind_rawWF` | 本群で完了・L10.45 | `Ty.rawBind_norm_wf` |
| FND078 | `Ty.rawBindTys_rawWF` | 本群で完了・L10.45 | `rawBindTys_norm_wf` |
| FND079 | `Eff.rawBind_rawWF` | 本群で完了・L10.45 | `Eff.rawBind_norm_wf` |
| FND080 | `Eff.substAt_atoms_wf` | 本群で完了・L10.45 | `Eff.substAt_atoms_wf` |
| FND081 | `Ty.bind_wf` | 本群で完了・L10.45 | `Ty.bind_wf` |
| FND082 | `Ty.rawShift_eq_rawBind` | 本群で完了・L10.45 | `Ty.rawShift_eq_rawBind` |
| FND083 | `Ty.rawShiftTys_eq_rawBindTys` | 本群で完了・L10.45 | `Ty.rawShiftTys_eq_rawBindTys` |
| FND084 | `Eff.rawShift_eq_rawBind` | 本群で完了・L10.46 | `Eff.rawShift_eq_rawBind` |
| FND085 | `Ty.shift_wf` | 既済 | `Ty.wf_shift` |
| FND086 | `Ty.substAt_wf` | 本群で完了・L10.46 | `Ty.substAt_wf` |
| FND087 | `Ty.subst_wf` | 本群で完了・L10.46 | `Ty.subst_wf` |
| FND088 | `Eff.bind_wf` | 本群で完了・L10.46 | `Eff.bind_wf` |
| FND089 | `Eff.subst_wf` | 本群で完了・L10.46 | `Eff.subst_wf` |
| FND090 | `Ty.substList_wf` | 本群で完了・L10.46 | `Ty.substList_wf` |
| FND091 | `Eff.substAt_wf` | 本群で完了・L10.46 | `Eff.substAt_wf` |
| FND092 | `Ty.WF.canonical` | 不要 | 新WFはTy全体のCanonicalを含まず、refine/convertのLeQから任意のWFを導けない |
| FND093 | `Ty.WFList.norm_eq` | 不要 | 新WFはTy全体のCanonicalを含まず、refine/convertのLeQから任意のWFを導けない |
| FND094 | `Ty.norm_WF` | 既済 | `Ty.wf_norm` |
| FND095 | `Ty.WFList.iff` | 既済 | `Ty.wfList_iff` |
| FND096 | `Eff.norm_WF` | 既済 | `Eff.wf_norm` |
| FND097 | `Ty.Le.wf` | 不要 | 新WFはTy全体のCanonicalを含まず、refine/convertのLeQから任意のWFを導けない |
| FND098 | `Ty.Le.wf_rev` | 不要 | 新WFはTy全体のCanonicalを含まず、refine/convertのLeQから任意のWFを導けない |
| FND099 | `Ty.WF.mono` | 既済 | `Ty.WF.weaken` |
| FND100 | `Ty.WFList.mono` | 既済 | `Ty.WFList.weaken` |
| FND101 | `Eff.WF.mono` | 既済 | `Eff.WF.weaken` |
| FND102 | `Ty.rawShift_of_wf` | 本群で完了・L10.44 | `Ty.rawShift_of_wf` |
| FND103 | `Ty.rawShiftTys_of_wf` | 本群で完了・L10.44 | `Ty.rawShiftTys_of_wf` |
| FND104 | `Eff.rawShift_of_wf` | 本群で完了・L10.44 | `Eff.rawShift_of_wf` |
| FND105 | `Ty.shift_of_wf` | 本群で完了・L10.44 | `Ty.shift_of_wf` |
| FND106 | `Eff.shift_of_wf` | 本群で完了・L10.44 | `Eff.shift_of_wf` |
| FND107 | `Ty.RowsInList.iff` | 本群で完了・L10.47 | `Ty.RowsInList.iff` |
| FND108 | `Ty.RowsIn.mono` | 本群で完了・L10.47 | `Ty.RowsIn.mono` |
| FND109 | `Ty.RowsInList.mono` | 本群で完了・L10.47 | `Ty.RowsInList.mono` |
| FND110 | `Eff.RowsIn.mono` | 本群で完了・L10.47 | `Eff.RowsIn.mono` |
| FND111 | `Ty.norm_rowsIn` | 本群で完了・L10.47 | `Ty.norm_rowsIn` |
| FND112 | `Ty.normTys_rowsIn` | 本群で完了・L10.47 | `Ty.normTys_rowsIn` |
| FND113 | `Eff.norm_rowsIn` | 本群で完了・L10.47 | `Eff.norm_rowsIn` |
| FND114 | `Ty.rowsIn_true` | 本群で完了・L10.47 | `Ty.rowsIn_true` |
| FND115 | `Ty.rowsInList_true` | 本群で完了・L10.47 | `Ty.rowsInList_true` |
| FND116 | `Eff.rowsIn_true` | 本群で完了・L10.47 | `Eff.rowsIn_true` |
| FND117 | `shiftIndex_compare` | 本群で完了・L10.49 | `shiftIndex_compare` |
| FND118 | `Ty.rawShift_compare` | 本群で完了・L10.49 | `Ty.shiftTypes_compare` |
| FND119 | `Ty.rawShiftTys_compare` | 本群で完了・L10.49 | `Ty.trees_shiftTypes_compare` |
| FND120 | `Eff.rawShift_compare` | 本群で完了・L10.49 | `Eff.tree_shiftTypes_compare` |
| FND121 | `Ty.norm_rawShift` | 本群で完了・L10.49 | `Ty.norm_shiftTypes` |
| FND122 | `Ty.normTys_rawShift` | 本群で完了・L10.49 | `Ty.normTys_shiftTypes` |
| FND123 | `Eff.norm_rawShift` | 本群で完了・L10.49 | `Eff.norm_shiftTypes` |
| FND124 | `Ty.rawShift_canonical` | 本群で完了・L10.49 | `Ty.rawShift_canonical` |
| FND125 | `Eff.rawShift_canonical` | 本群で完了・L10.50 | `Eff.rawShift_canonical` |
| FND126 | `Ty.shift_canonical` | 本群で完了・L10.50 | `Ty.shift_canonical` |
| FND127 | `Eff.shift_canonical` | 本群で完了・L10.50 | `Eff.shift_canonical` |
| FND128 | `Ty.rawShift_zero` | 本群で完了・L10.50 | `shiftTypes_zero` |
| FND129 | `Ty.rawShiftTys_zero` | 本群で完了・L10.50 | `shiftTypesList_zero` |
| FND130 | `Eff.rawShift_zero` | 本群で完了・L10.50 | `shiftRowsTypes_zero` |
| FND131 | `Ty.shift_zero_norm` | 本群で完了・L10.50 | `Ty.shift_zero_norm` |
| FND132 | `Eff.shift_zero_norm` | 本群で完了・L10.50 | `Eff.shift_zero_norm` |
| FND133 | `Ty.norm_support` | 前群で完了・L10.33 | `Ty.norm_support` |
| FND134 | `Ty.normTys_support` | 前群で完了・L10.33 | `Ty.normTys_support` |
| FND135 | `Eff.norm_support` | 前群で完了・L10.33 | `Eff.norm_support` |
| FND136 | `Ty.rawShift_support` | 前群で完了・L10.34 | `Ty.rawShift_support` |
| FND137 | `Ty.rawShiftTys_support` | 前群で完了・L10.34 | `Ty.rawShiftTys_support` |
| FND138 | `Eff.rawShift_support` | 前群で完了・L10.34 | `Eff.rawShift_support` |
| FND139 | `Ty.shift_support` | 前群で完了・L10.34 | `Ty.shift_support` |
| FND140 | `Eff.shift_support` | 前群で完了・L10.34 | `Eff.shift_support` |
| FND141 | `Ty.rawBind_support` | 前群で完了・L10.35 | `Ty.rawBind_support` |
| FND142 | `Ty.rawBindTys_support` | 前群で完了・L10.35 | `Ty.rawBindTys_support` |
| FND143 | `Eff.rawBind_support` | 前群で完了・L10.35 | `Eff.rawBind_support` |
| FND144 | `SubstEnv.at_support` | 前群で完了・L10.35 | `typeEnvAt_support` |
| FND145 | `Ty.substAt_support` | 前群で完了・L10.35 | `Ty.substAt_support` |
| FND146 | `Eff.substAt_support` | 前群で完了・L10.35 | `Eff.substAt_support` |
| FND147 | `Ty.VarsInList.iff` | 本群で完了・L10.48 | `Ty.VarsInList.iff` |
| FND148 | `Ty.VarsIn.wf` | 本群で完了・L10.48 | `Ty.VarsIn.wf` |
| FND149 | `Ty.VarsInList.wf` | 本群で完了・L10.48 | `Ty.VarsInList.wf` |
| FND150 | `Eff.VarsIn.wf` | 本群で完了・L10.48 | `Eff.VarsIn.wf` |
| FND151 | `Ty.VarsIn.rows` | 本群で完了・L10.48 | `Ty.VarsIn.rows` |
| FND152 | `Ty.VarsInList.rows` | 本群で完了・L10.48 | `Ty.VarsInList.rows` |
| FND153 | `Eff.VarsIn.rows` | 本群で完了・L10.48 | `Eff.VarsIn.rows` |
| FND154 | `Ty.VarsIn.mono` | 本群で完了・L10.48 | `Ty.VarsIn.mono` |
| FND155 | `Ty.VarsInList.mono` | 本群で完了・L10.48 | `Ty.VarsInList.mono` |
| FND156 | `Eff.VarsIn.mono` | 本群で完了・L10.48 | `Eff.VarsIn.mono` |
| FND157 | `Ty.norm_VarsIn` | 本群で完了・L10.48 | `Ty.norm_VarsIn` |
| FND158 | `Eff.norm_VarsIn` | 本群で完了・L10.48 | `Eff.norm_VarsIn` |

detailの旧読者12件と旧Legacyのnormの橋は削除・置換していない。重1で漏れが分かった旧読者は下表へ補う。L20 G04/G08とL70が、新WF/VarsIn/RowsIn/RangesScoped、ProperApply/HasKind、正規化と明示のCanonicalを使って追随する。旧言明の同値やRawWFを戻すことを依存にしない。

## 場合の数の予定と実際

相互再帰の最外の構成子だけを数える。任意の自然数の添字、束縛の深さ、述語の意味の全状態を有限に列挙した数ではない。

| 対象 | 予定 | 実際と根拠 |
|---|---:|---|
| WFによる生の移動の恒等式 | Ty21+型列2+Eff1+Tel2=26 | 26。外部型、篩、依存列を含む相互四族 |
| rawApplyのscope | Ty21、型構成子6 | 同数。引数列は空/非空、mapの後続は空/非空の枝も扱う。kindやarityの適格性をこの補題から結論しない |
| 像の条件付きrawBindと正規化後のWF | 相互四族26 | 26。篩のselfとparamの値束縛を別々にupし、行像のFailは再置換しない |
| RowsInと支持の同値、rowsIn_true | 各相互四族26 | 各26。mono/normの包装は既存支持の証明から導く |
| WFの下のRangesScopedと支持の同値 | 相互四族26 | 26。VarsInのwf/rows/mono/normはこの補助と既存WFの弱化・正規化を使う |
| 生の移動の比較と正規化との交換 | 既存の組450と相互四族26 | 同じ既存の定理を再使用。今回450場合を新しく書き直した数にはしない。監査入力が構成子数21/2/1/2と組450を照合 |
| 移動の包装と効果の包装 | 台帳の21件+6件 | 21+6件。前提と結論の型を完全署名で照合 |
| HasTypeVQ/HasTypeCQなど | 14判断、値29・計算24を含む相互76、四本 | 再開で値移動・型移動・値置換・narrowingの四本を追随。各14判断76場合。Noneの下の置換は値置換の包装を再使用。主な十言明の宣言を群Vの保存ハッシュとも照合する |

## 補助契約で決めたこと

再開後の完全署名158件と構造体の欄は[signatures.md](signatures.md)、型の照合は[signatures.lean](signatures.lean)にある。

1. WFからTy全体のCanonicalを導かず、公開shiftの恒等式の右辺をnormとする。
2. 旧のrawBind/RawWFの三件は、rawBindの正規化後の新WFとして閉じる。元の型からCanonicalを得る層、又はRawWFと同等の層を新設しない。
3. WFImagesは入出力の範囲・型・値の深さ、型/行/範囲/値の像を分ける。型像にはOrdinaryも要求する。行の像は最上位でCanonicalでなくてもよい。観測像がnoneの場合は成功した観測の証拠と扱わない。
4. substAtは型cutoff cと型像の深さnを分け、結果をn+cとする。値深さnvは型cutoffと独立で、像の外側の値参照を除外しない。
5. RowsInは既存定義を使い、支持との同値で再帰の漏れを防ぐ。効果の名前の原子の範囲はRangesScoped/AtomsWFで別に検査する。
6. VarsInはscopeの条件を束ね、SourceScopedと同じ意味を保つ。AnnotationとHasKind.valueはOrdinaryを供給しない。再開で承認されたTypeArgsKinded/TypeArgsKindedAtのvalue kindの条件とV_Raiseの二型の条件からOrdinaryを供給する。constructor kindは形からOrdinaryを導く。LegacyInputも同じ入力を保持する。初回の「既存のAnnotation/HasKind/Ordinaryが検査する」という根拠は誤りであり、この決定へ訂正した。
7. 生の移動のWF四族は既存TypeShiftContextにあったため、それを再使用する。完全署名を直す必要のない既存の比較・norm・zeroには、重複した別名を追加しない。
8. Allowsは固定したσでRangeExpr.Memを読み、κがnoneの場合とrvarの原子から対象の許可を導かない。型付けやCovers/Subにσを渡さない。TopAtomsは最上位だけを読み、Fail内部を制限しない。
9. 構造等号にはCanonicalと双方向のSubを使い、双方向のCoversで代替しない。Failは正規化後の型等号のまま不変である。

主な十定理の前提・結論、公理、提供範囲、利用者の書ける形、精密な外部状態は保つ。型付け判断とLegacyInputの意味は、再開で承認されたOrdinaryの条件の追加に限り変更した。WFの基盤だけからSorted/Declaredや全型付けの形成を導いたと記録しない。

## 境界と作成時の関門

[boundary.lean](boundary.lean)は本番の定義をimportし、名前付きの151宣言を検査する。内訳は準備の値と補助の証明・生成宣言を含み、151個の独立した利用例とは数えない。初回は97宣言だった。

- 正例: 篩を含む外部型の像、依存列のparamの下で外側の値参照1を2へ移す置換、残す型束縛を持つcutoff、四名前空間の同時置換。型像に同じ値置換を再適用しないことを、元とは異なる観測像で確かめる。
- 正例: 非空の行像とそのFail内部の外側の値参照、型列のsubst、名前の原子の範囲のWF、external/refined/dependentFn/Failを通るRowsInとVarsInの正規化保存。
- 負例: WFのInteger{true}からCanonicalは導けず、公開shiftは元の篩と等しくない。篩の導入・除去のLeQの導出だけでは両側のWFを得られない。
- 負例: 型像のWFだけではOrdinaryは得られず、篩の芯に継続が入るとbind後のWFが偽になる。未整列の行像では生の潜在効果のWFが偽になり、正規化後のbindのWFは成り立つ。
- 負例: Eff.WFは名前の原子の範囲添字を検査せず、行変数がなくてもVarsInは偽になり得る。篩を忘れる部分型関係があっても、Failの型は忘れられない。
- 負例: 双方向にCoversを満たす二つのCanonicalな効果が構造的に異なる。双方向のSubも、生のFail列の重複を区別しない。正規化後にはeq_of_sub_of_subで等号を得る。
- 対象の正負例: cwdを読む非Topの原子でAllowsが成り立ち、normの前後で保たれる。種類がnoneの場合と行変数だけの場合は許可を導かない。

作成時の関門では、持ち主の境界を新しいLeanの形成・変数・移動・効果の公開契約とした。値のupの脱落、像への再置換、四名前空間の混同、Fail内部の再帰の脱落、WFとCanonical又はCoversとSubの混同を捕まえる。前群の有限比較の境界はこれらの一般置換とWFの契約を検査していない。本番を複製せず、テスト用フラグや差し込み口を追加していない。既存の不具合の修正の退行テストではなく、新しい入口の契約と、移さない旧言明の負例である。

## 初回のビルド・公理依存・変更の識別

以下の表は初回の記録である。再開後の最終検証は末尾と[verification.json](verification.json)を正とする。再実行はformalを作業ディレクトリとし、既定ビルドは `lake build`、直接の入力は `lake env lean -M 12288 <入力>` を使う。[check.py](check.py)は同じコマンドを記録し、[verify.py](verify.py)は保存した出力のSHA-256、台帳の件数、保護した既存入力、既定importを照合する。[prepare-evidence.py](prepare-evidence.py)は署名と台帳・監査入力を作り直す。

Leanはformalで固定した4.34.1（arm64-apple-darwin24.6.0）、コミット `5045d0056413266e57c625dcd7c365b10e377c52`。既定buildはlakefileのmoreLeanArgs、直接のLeanはすべて `-M 12288` を使用した。途中の版表示をリポジトリの根でも行い、そこで表示された4.35.0は今回のformalの検査には使っていない。

| 検査の実体 | 結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| 既定のlake build | 終了0、警告141件、771ジョブ、sorryなし | 0.783秒 | [run-026-build.json](run-026-build.json) |
| 完全署名106件 | 終了0、警告0件、sorryAx/許可外公理0 | 0.734秒 | [run-028-signatures.json](run-028-signatures.json) |
| 台帳の対応先115件 | 終了0、警告0件、sorryAx/許可外公理0 | 0.976秒 | [run-029-foundation.json](run-029-foundation.json) |
| 新規6モジュール全宣言と既存18件の公理依存 | 終了0、警告0件、sorryAx/許可外公理0 | 1.434秒 | [run-031-axioms.json](run-031-axioms.json) |
| 名前付きの正負例と準備97宣言 | 終了0、警告0件、sorryAx/許可外公理0 | 0.876秒 | [run-032-boundary.json](run-032-boundary.json) |

公理依存は合計473件（252+18+106+97）で、許した `propext`・`Quot.sound`・`Classical.choice` 以外は0件である。新規モジュールの内訳はTypeRegularity 10、TypeBounds 44、TypeRows 85、TypeVariables 72、TypeShiftFacts 17、EffectFacts 24である。privateと生成宣言を省いていない。既存18件は旧の五主定理・三モデルと、HasTypeVQ/HasTypeCQの主な十言明である。型付けの主な十言明の前提・結論を変えていない。

既定buildは増分である。新規モジュールは既定importに追加し、元のimportを削除していない。既定buildの141警告は既存のlintと既存のリンクの警告で、新規本番の直接検査、署名、台帳、境界、公理監査の最終出力は警告0である。RSSは未取得（計画上の非採取）。work/dry-run、Rustの検査、Rust/Leanの全比較、ベンチマークは実行していない。

01-12・07-04・用語集に、実装したWFの条件付き置換、四名前空間の再帰条件、移動と正規形、効果の等号と行置換を反映した。既存の見出しと仕様のtext例は変更していないため、spec_examplesは実行していない。設計書へ工程IDと未実施の予告を追加していない。

開始時の1855ファイルの控えとの比較では、変更した既存ファイルはformal/Benitoite.leanと設計書3ファイルだけで、他の1851ファイルと既存の定義・主定理のソースは不変である。plan/detail・レビュー原本・rv-*も同じ控えに含む。初回控えの生のJSONは289,770 bytesだったため一時領域へ移し、[initial-record.json](initial-record.json)と[large-records.md](large-records.md)へ大きさとSHA-256を残した。他の本群の生の記録は100,000 bytes以下である。診断に現れるリポジトリの絶対パスは保存前に `<repo>` へ置き換え、その保存内容のハッシュを記録する。

## 初回失敗と修正、計画との差

- 局所証明では、暗黙のRangeIxの型、upした行列の所属、型列のnormとmapの書換え、Eff.WFの型列への射影、cutoffの自然数の式、一般のrawApplyの枝の展開を補った。初回の失敗をrun-001/run-003〜005/run-007へ残し、成功はrun-002/run-006/run-008で確認した。
- TypeVariablesを接続した際、既存TypeShiftContextに生の移動のWF四族があることが分かった。作成中の同名の相互証明を取り除き、既存の証明をimportして使用した。新しい別名の証明は残していない。未作成のoleanによる初回失敗と、重複名の診断はrun-010〜011、修正後の依存buildと成功はrun-012〜013にある。
- EffectFactsでは、存在しないcongrArg₂/mk.injEq.mprを使った初稿を、atom関数の等号とFail列の等号からmkの等号を作る証明へ修正した。run-016〜018が初回失敗、run-019が成功である。
- 境界は、WFの全域の決定インスタンスを要求しないよう、具体的な添字の不等式を明示した。行の条件の組の投影と小さな構文の誤りも修正し、run-021〜022からrun-023へ、追加した非空行の例はrun-024からrun-025へ、最後の生の潜在効果の負例はrun-032へ成功を残した。
- 完全署名の初回監査は、既存のsignatureTelなど10宣言を名前の前置きで拾い、116件と368警告になった。照合対象を106件の完全名の一覧へ固定し、証明にはtheoremを使い、型注釈の使わない束縛名へ下線を付けた。署名の意味を変えず、run-028で106件・警告0を確認した。

detailの予定からの変更は、旧rawBind/RawWFを正規化後の新WFへ直接移す補助契約の具体化、既存RowsInとTypeShiftContextの再使用、VarsInをSourceScopedと同じscopeの束にすること、substAtの結果をn+cまで一般化したことである。初回の後、重1に対し2026-11-01の取りまとめの承認により型付けのOrdinary条件を追加した。主な十定理の前提変更、独自公理、結論の弱化、精密な外部状態の追加はない。

## 外側の時間と単位の記録

最初の時計確認は2026-11-01 19:13:33 JSTである。それ以前の読取り時間は未取得であり、能動時間と待ちは分離していない。以下の時刻は局所検査の成功時刻で、各単位の着手時刻や能動時間として補ってはいない。

| 単位 | 局所検査の成功の時刻（JST、秒は概数） | 記録 |
|---|---|---|
| .44 | 19:18:28 | run-002（生のWF移動四族の重複を除いた最終版はrun-012と既定buildへ含む） |
| .45 | 19:20:12 | run-006 |
| .46 | 19:20:40 | run-008 |
| .47 | 19:21:18 | run-009 |
| .48 | 19:22:28 | run-013 |
| .49 | 19:22:50 | run-014 |
| .50 | 19:22:50 | run-015 |
| .51 | 19:23:47 | run-019 |

この結果の記録を確定した時刻は2026-11-01T19:40:40.050450+09:00で、最初の時計確認からの外側の時間は1627.050秒（約27.1分）である。能動時間の測定値ではない。

既定buildと署名・公理・境界の検査の秒数は上の表の実測値である。並行した読み取り専用の検査の時間を足して外側の時間としていない。終了時刻と最初の時計確認からの外側の秒数はverification.jsonのended_utc/outer_secondsを正とする。見込み4〜8時間より短い実績を、他の群・全保存の証明・Rustとの接続へ外挿しない。

## 残りと次の群への申し送り

| 送り先 | 残る作業と受渡し | 見込み |
|---|---|---|
| 取りまとめ・設計者 | RV-L10.s2-requestにより定義・言明・前提を独立レビューし、workと受け入れ、取り込みを行う。担当の自己点検を独立レビュー済みとは扱わない | 不明 |
| L10.52〜.54 | 共有近似のWF・空の判定・実解析出力の写し・数値の共有層への接続。本群では開始していない | 既存detailの枠、合計1.5〜3時間 |
| L10.55 | L10で閉じるfoundation99件は完了。115件の対応先の存在、不要43件の扱い、旧読者12件と末尾に補った二読者の対応をこの結果から受け取る。旧RawWF/旧同値/WFからCanonicalを要求せず新入口へ接続する | 既存detailの0.5〜1時間 |
| L20 G04 | WFImages/型と行のsubstAt_wfを基盤として、型付き入力からのSorted/Declared/HasKind/ProperApply等の全形成を接続する。この基盤の14件を未完として重ねない。生のrawBindのWFを無条件に要求しない | 既存担当枠。本群では再見積もりしない |
| L20 G08・L70 | 新PrimSig.Scopedとsig_scoped、範囲/行/値の上限の読者を新判断へ接続する。旧ScopedOldとの同値を戻さない | 既存担当枠 |
| L20 G07・L70の有限API | 前群のfnViewの支持前提なし版の判断、支持不足で比較がeqになる問題、深い原子符号の費用に関する申し送りは継続する。本群では新しい一般証明を追加していない | 前群の申し送りどおり、不明 |
| L70以後 | 全主定理の合成、Rustとの接続・全比較。今回のLeanの検査をそれらの完了と扱わない | 不明 |

台帳の未実装はない。初回の独立レビューは条件付き可であり、下記の処置の再レビュー・work・受け入れは取りまとめが行う。L10.52は開始していない。

## 再開での所見の処置

2026-11-01。RV-L10.s2の全文・取りまとめの追記とplan先頭の承認に従い、重1と軽1〜4を処置した。rv-s2-t1〜t4とレビュー原本は変更していない。

| 所見 | 処置と証拠 | 判定 |
|---|---|---|
| 重1 | TypeArgsKindedとTypeArgsKindedAtへvalue kindのOrdinaryを追加。V_Raiseのt/eにも追加。SignatureInstanceのordinary/typeScope、操作・辞書・メソッド・raiseの反転から実際の型置換の入力を導く。群VのsourceOrd引数を取り除き、新しいkindsの欄から導出。LegacyInputから同じ条件を供給 | 実装・局所検査完了。独立再レビュー待ち |
| 軽1 | 境界へTopの許可、範囲変数の拒否、secrets未指定とsnapshot差、TopAtomsの正負例を追加 | 完了 |
| 軽2 | 下記に弱めた言明と利用先を転記し、Ordinaryの解決先を更新。foundation.leanの115件は対応先の存在の確認であり、完全署名の型の照合と区別 | 完了 |
| 軽3 | 07-04から未定義のRawWFの否定を削除し、SourceScopedとの「一致を示し」へ訂正 | 完了 |
| 軽4 | Tel.bind_wf、Tel.substAt_wf、Ty/Eff/Tel.substAt_nil_of_wfを追加。未使用の型像にOrdinaryを要求せず、閉じた入力の結果をnormとする | 完了 |

### 弱めた言明と利用先の判定

| 旧 → 新 | 変化 | 利用先の判定 |
|---|---|---|
| `Ty.shift_of_wf` | 結論を `a` から `a.norm` へ | 足りる。節の型は生の `shiftTypes` なので `Ty.rawShift_of_wf` を使える |
| `Eff.shift_of_wf` | Canonical の前提を外し、結論を `e.norm` へ | 同値 |
| `*.rawBind_rawWF` 三件 | 入力が RawWF から WF へ、結論が正規化後へ、Ordinary・範囲・値の像を追加 | 足りる。二重の生の置換は `rv-s2-t3.lean` の `raw_twice_wf` で閉じる |
| `Ty.bind_wf`・`Eff.bind_wf` | 像の条件が WFImages へ | 足りる。Ordinary は新しい型引数の条件から供給 |
| `*.substAt_wf`・`*.subst_wf`・`substList_wf` | `ho` を追加。一方で像の深さは n へ一般化し、値深さを追加 | 重1 の修正で型付けから Ordinary を供給。ほかは足りる |
| `Eff.allows_norm` | σ を追加 | 足りる。`rv-s2-t4.lean` の `allows_of_covers` で固定した σ の下の被覆の健全性も確認 |
| `Ty.VarsIn` 系 12 件 | 継続の禁止を失う | 重1 の修正で、非継続を VarsIn と別の型引数の条件で供給。範囲と行の移送は `rv-s2-t3.lean` の `substAt_varsIn` で足りる（行変数なしの場合） |
| `Ty.shift_compareList` | `tysCompare` から木の比較へ | 足りる。新体系に `tysCompare` がない |


### 漏れていた旧読者の対応

| 旧読者 | 旧入力と使う経路 | 新しい供給元と送り先 |
|---|---|---|
| Lemmas/Preservation.closedArgs_of | VarsInListからClosedArgs（閉じたWFとNotCont）を得てE_Fun・E_Meth・E_Op・E_OpFailへ渡す | 新VarsInは非継続を含まない。関数・操作はSignatureInstance.typeScope、メソッドはmethod_body_typeScope、raiseはraise_typeScopeからWFとOrdinaryを取り出す。E_OpFailの結果型Tの単一の像[T]にはraise_subst_wf/raise_subst_leを供給する。G03で全本体への型置換へ接続 |
| Lemmas/PresBase.ClosedArgs.single | `.prim b [t] es rs` の旧VarsInからClosedArgs [t]を得る。PresMainのReferenceなどの遷移で型のWFと非継続を使う | V_PrimのSignatureInstance.typeScopeとPrimitiveAdmissible.typeScopeから一つの型像のWF/Ordinaryを得る。ReferencePreservationは強めたSignatureInstanceへ追随済み。一般の本体の型置換への接続はG03 |

### 規則の新旧と契約の選択

- 旧TypeArgsKindedは各添字のHasKindだけを要求した。新形は `HasKind ∧ (k = .value → Ordinary a)`。TypeArgsKindedAtとLegacyKindArgs/LegacyTypesInputも同じ条件とした。SignatureInstanceを持つV_Fun・V_Prim・V_Op・V_ExternalRef・C_Meth、およびV_Con・V_Dict・C_BuilderLet・C_BuilderOpを一箇所から閉じる。
- 旧V_RaiseはAnnotationだけだった。新形はAnnotationにOrdinary tとOrdinary eを加える。C_Methのss++[τ]のWF/OrdinaryはSignatureInstanceから導き、同じ条件を規則へ重複して足さない。
- TyKindの構成子はvalue/constructorであり、継続用のkindはない。constructor kindはHasKind.constructor_shapeからOrdinaryを導く。継続の保存とresumeは型引数ではなく文脈・場所の型を使うため、この条件を課さない。constructor kindの正例とresumeの正例を境界に置く。
- HasTypeVQ/CQのshift_values・shift_types・subst・subst_under_none・narrowの宣言は変更しない。V_Raiseの増えた証拠とTypeArgsKindedの両欄を各移送で保存する。新しい公理やBuiltinsの信頼契約の欄は追加しない。
- LegacyTypesInput.iff_of_notContで、旧型引数のNotContの下では追加前の各型入力と同値である。閉性を要求しないので、多相の本体の中の型変数にも使える。旧NotContとembedTy後のOrdinaryの同値を使う。raiseは旧Val.VarsIn、builderは旧NotContの下で追加条件を供給する。builderの内容型はstring/list/bytesなのでLegacyBuilderInput.iffは追加前の入力との無条件の同値も示す。一般のLegacyTypeInputと継続を格納する文脈は制限しない。
- 群Vのconstructor_field_inputs・con_field_by_type・field_facts_by_typeは、V_Conのkinds.ordinaryからsourceOrdを導く。呼出し側へ独立したOrdinaryの前提を残さない。
- 利用者向けの型の文法には継続型の記法がなく、追加条件はコア内部の継続型を値型引数に使う導出を拒む。型構成子の引数、表層の型、提供範囲と外部状態に新しい制限は加えていない。

### 反例の排除と置換の代表

境界のcontinuation_arg_rejectedは、rv-s2-t1と同じ操作宣言に対し `.op "o" [continuation]` がどの型でも型付かないことを証明する。review_body_typedとreview_unrestricted_subst_falseは、無条件の型置換の反例そのものを保持する。新規則では反例の型引数がSignatureInstanceを満たさず、節の本体へ渡る型列にならない。safe_operation_bodyは通常の型引数[Unit]で実際のc.body.substTyの型付けを構成する。safe_method_typedは実装とメソッド双方に[Unit]を持つ呼出しを構成し、safe_method_body/type/leはss++tsの本体・WF・LeQの結論を具体化する。op_subst_wf/op_subst_leは同じ型付き操作からTy.subst_wf/Ty.LeQ.substAtのOrdinaryを供給する。method_subst_wf/method_subst_le/method_return_substも、型付きメソッドとその辞書からss++tsを取り出し、別のOrdinary前提なしで閉じる。

HandlerCallsのoperation_call・operation_annotation・pure_operationとそのsignature/annotationの反転は `.op o ts` へ一般化した。HandlerOperationのStateTyE.operation_typeScopeも型引数のある状態からWF/Ordinaryを得る。operation_oneの全状態の保存は単相のままであり、型引数のある任意の節本体の型置換、Sorted/Declaredのtappへの移送、E_OpFailとE_Methの全状態への接続はG03へ渡す。今回の代表の証明で全保存が完了したとは扱わない。

### 再開後の最終検査と自己点検

主な十言明は[main-contracts-reference.json](main-contracts-reference.json)に群Vの保存済みソースから完全な宣言を抽出し、[check-main-contracts.py](check-main-contracts.py)で現在の宣言と空白を除いて比較した。保存元のアーカイブの大きさとSHA-256は群Vのlarge-recordsと一致する。既定引数の内部の `:=` を本体の開始と取り違えず、括弧の深さ0の本体開始まで比較する。群Vの旧ハッシュは既定引数の位置で途切れるものがあるため、完全な宣言の写しを本群へ保存し直した。十件すべて一致し、main-contracts.leanによる型の照合と公理依存も成功した。

再開後の規則の義務と、detailの.44〜.51の八義務を報告前に再照合した。foundationの分類は16＋43＋31＋68のままであり、本群の対応68件と前群31件に未実装はない。型引数のOrdinaryは新しい規則の欄から供給し、VarsInから誤って導く前提は残していない。新規本番は7モジュール853行であり、この7モジュールの全284宣言を含めて監査した。

| 検査の実体 | 結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| 既定lake build、772ジョブ | 終了0、警告141、sorryなし | 2.525秒 | [run-051-build.json](run-051-build.json) |
| 完全署名158件 | 終了0、警告0、sorryなし | 0.773秒 | [run-063-signatures.json](run-063-signatures.json) |
| foundation対応先115件の存在 | 終了0、警告0、sorryなし | 2.038秒 | [run-055-foundation.json](run-055-foundation.json) |
| 全差分32モジュール2,551宣言＋既存18件 | 終了0、警告0、sorryなし | 4.802秒 | [run-060-axioms.json](run-060-axioms.json) |
| 名前付きの境界151宣言 | 終了0、警告0、sorryなし | 0.920秒 | [run-062-boundary.json](run-062-boundary.json) |
| 主な十定理の型と公理 | 終了0、警告0、sorryなし | 0.650秒 | [run-061-main-contracts.json](run-061-main-contracts.json) |
| 群Vの境界55宣言 | 終了0、警告0、sorryなし | 2.126秒 | [run-057-v-boundary.json](run-057-v-boundary.json) |
| 補助入力t2の形成・置換・捕捉 | 終了0、警告0、sorryなし | 2.041秒 | [run-055-review-t2.json](run-055-review-t2.json) |
| 補助入力t3の範囲・二重置換 | 終了0、警告0、sorryなし | 1.911秒 | [run-053-review-t3.json](run-053-review-t3.json) |
| 補助入力t4の被覆とAllows | 終了0、警告0、sorryなし | 1.928秒 | [run-054-review-t4.json](run-054-review-t4.json) |

公理の印字は合計2,946件（重複を含む）であり、許可外の公理は0件である。許したものはpropext・Quot.sound・Classical.choiceだけである。全差分の監査はprivate・相互証明・生成宣言も含む。[audit-modules.json](audit-modules.json)の32モジュールが監査の対象と一致する。既定buildの141警告は既存のlintとリンクの警告であり、最終の局所検査はすべて警告0である。buildは増分であり、RSSは非採取のため未取得である。

14判断の構成子数は値29・計算24・値列2・同型値列2・腕3・通常節2・失敗節1・依存引数列2・Tel本体2・捕捉1・Closure1・依存Closure1・CheckedWitness2・ImageOk4、合計76である。値移動・型移動・値置換・narrowingの四本について既存の証明を追随し、全変更モジュールの公理監査と既定buildで確認した。Noneの下の置換は同じ値置換とextendNoneの包装で閉じる。76×4個の独立したテストを追加した数ではない。

01-12と07-04の写し、用語集の継続の型付けの説明は、同じ変更でOrdinaryの条件へ更新した。既存のtextブロックは変えていないためspec_examplesは実行していない。work、処理系の変更、Rust/Leanの全比較、L10.52への着手、gitの操作はしていない。plan/detail・レビュー原本・rv-*の107入力は開始時のハッシュと一致する。

途中のrun-033〜042、046〜049は、追加した証拠の組の投影、相互型付けの再帰、暗黙の型、境界の具体化、完全署名の暗黙引数の順を直す前の失敗である。run-052の主定理の包装には未使用の束縛名のlintがあったため、束縛名に下線を付け、run-061で警告0を確認した。失敗出力にLeanが自動挿入したsorryAxがあっても、最終の成功出力には含まれない。100,000 bytesを超える公理監査の出力は一時領域へ保存し、large-records.mdに大きさとSHA-256を残した。

再開の開始は2026-11-01 10:59:18 UTC（19:59:18 JST）である。終了時刻と外側の秒数はverification.jsonを正とする。能動時間と待ちは分離しておらず、並行した検査の秒数を合計して外側の時間にはしていない。今回の上限6時間以内で終了した。

| 残る手順・送り先 | 内容 | 見込み |
|---|---|---|
| 取りまとめ・設計者 | 重1と軽1〜4の処置を独立再レビューし、work・受け入れ・取り込みを行う | 不明 |
| L20 G03 | 上記の実際の型引数のWF/Ordinaryを使い、任意の本体の型置換、tappのSorted/Declaredの移送、E_Op/E_OpFail/E_Methの全状態へ接続する。operation_oneの多相化と、入れ子の継続を持つ型像が全状態で害を生まないことの確認を含む | 既存担当枠。本群では見積もり直していない |
| L20 G04 | Ctx.WF、像のup、Groundな捕捉のWFは補助入力t2の正例を参照。CaptureWFが読まない継続の潜在効果をWFから得たとは扱わない | 既存担当枠 |
| L10の次の群 | foundationは全件閉じたものとして受け取り、旧VarsInの非継続の読者は末尾の二行の対応も使う。本群は.51で止める | 既存detailの枠 |

## 再レビューの所見の処置

2026-11-01。レビュー原本の「再レビュー」と末尾の取りまとめの追記に従い、再中1・再軽1・再軽2を処置した。型付け規則と主な十定理の前提・結論は変更していない。レビュー原本とrv-s2-t5を含む補助入力は変更していない。

| 所見 | 処置と根拠 | 判定 |
|---|---|---|
| 再中1 | raise_subst_wf/leの像をエラー型[e]から結果型[t]へ訂正し、raise_typeScopeの結果型側からWF/Ordinaryを供給する。実際のE_OpFailのbody.substTy [T] []と同じ型列である。境界では結果型Unitとエラー型Integerを分けて二補題を使用し、像の取り違えを検査 | 完了 |
| 再軽1 | of_closedArgs/iff_of_closedArgsをof_notCont/iff_of_notContへ替え、前提を各型のNotContだけへ弱めた。notCont_of_legacyVarsIn/Listを追加し、旧の開いた型変数を持つ型列にも適用できることを境界で確認 | 完了 |
| 再軽2 | Ordinaryは篩を外した芯の最上位だけを読み、`.op "o" [.list k0]` を拒まないと明記。旧ClosedArgsのNotContも最上位だけであり、入れ子も拒む旧VarsInとは区別する。rv-s2-t5のnested_op_typedとnested_bodyが成功 | 完了 |

Ordinaryを再帰的な継続の禁止へ強めない。型置換の代表ではOrdinaryの保存が成り立ち、継続型の閉じた値を作る規則もない。これを全状態での無害性の証明とは扱わず、G03の入力に入れ子の継続を持つ像の確認を加える。捕捉を持つ閉包、複数引数、全本体の型置換とtappのSorted/Declaredへの接続も引き続きG03の範囲である。

完全署名を再生成し、主な十定理の完全な宣言を再照合した。01-12のOrdinaryの説明に最上位だけの条件を明記し、07-04のLegacyの同値の説明をNotContだけの前提へ合わせた。textブロックと型付け規則は変更していない。spec_examplesとwork、gitの操作は実行していない。

以下が今回の最終検査である。前節の数と時刻は前回の処置時点の記録であり、現在の入力と最終検証はverification.jsonを正とする。

| 検査 | 結果 | 記録 |
|---|---|---|
| 既定lake build、772ジョブ | 終了0、sorryなし、警告141、2.461秒 | [run-065-build.json](run-065-build.json) |
| 完全署名160件 | 終了0、sorryなし、警告0、1.068秒 | [run-067-signatures.json](run-067-signatures.json) |
| 境界154宣言 | 終了0、sorryなし、警告0、1.203秒 | [run-068-boundary.json](run-068-boundary.json) |
| 全差分32モジュール2,553宣言＋既存18件 | 終了0、sorryなし、警告0、3.669秒 | [run-069-axioms.json](run-069-axioms.json) |
| 補助入力t5 | 終了0、sorryなし、警告0、0.885秒 | [run-066-review-t5.json](run-066-review-t5.json) |

全差分の公理監査はprivate・生成宣言を含む2,571件であり、許可外の公理とsorryAxは0件である。依存するのはpropext・Quot.sound・Classical.choiceだけである。今回の境界・完全署名・t5を含む全ての最終検査の印字は合計2,955件（重複を含む）。100,000 bytesを超える公理監査の生の出力は一時領域に置き、large-records.mdに大きさとSHA-256を記録した。buildは増分、141警告は既存のlintとリンクの警告であり、局所検査の最終出力は警告0である。RSSは計画上の非採取により未取得である。

run-064はof_notContの初稿で関数適用の括弧を欠いた失敗であり、直してから既定buildと署名・境界・公理監査を成功させた。今回の開始は2026-11-01 11:36:39 UTCであり、終了時刻と外側の時間はverification.jsonに保存する。能動時間と待ちは分離していない。今回の上限1時間以内で終了した。

取りまとめの追記の「再レビューはこれで閉じる」に従い、三所見への処置を完了した。work・受け入れ・取り込みは取りまとめと設計者が行う。L10.52は開始していない。

再開前に取りまとめがeffort-ledgerへ加えた二行は変更していない。この現在の入力もcoordinator-inputs.jsonで固定し、レビュー等108入力と合わせた109入力の保護を確認する。

## 作業末の work

取りまとめが実行した。基準は `42a09116fd2442fca93b38a7e18b8138356a8dcc`、コマンドは `scripts/check.sh --level work --base <基準>`、終了状態は 0、外側の時間は 99.89 秒である。実行の前に Refinement の生成物を消した。
