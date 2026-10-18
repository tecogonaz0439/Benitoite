import Benitoite.Release.Theorems

/-!
表現Bの保存差分を適用した状態の公理依存を確認する。
正式な開始状態の証拠やL1bの完了検査には使わない。
-/

#print axioms Benitoite.Release.Ty.bind_comp
#print axioms Benitoite.Release.Eff.bind_comp
#print axioms Benitoite.Release.Eff.substRho_congr_rows
#print axioms Benitoite.Release.Eff.substRho_comp
#print axioms Benitoite.Release.Ty.subst_comp
#print axioms Benitoite.Release.Ty.shift_substAt
#print axioms Benitoite.Release.Eff.shift_substAt
#print axioms Benitoite.Release.Ty.VarsIn.wf
#print axioms Benitoite.Release.Eff.VarsIn.wf
#print axioms Benitoite.Release.HasTypeV.wf
#print axioms Benitoite.Release.HasTypeC.wf
#print axioms Benitoite.Release.preservationE
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
