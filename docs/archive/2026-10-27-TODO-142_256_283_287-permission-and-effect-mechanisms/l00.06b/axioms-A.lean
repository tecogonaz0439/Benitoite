-- L00.06b の試行 A の状態でだけ通る公理の依存の確かめ（`lake env lean -M 12288 <このファイル>`）。
import Benitoite
open Benitoite.Release
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Release.preservationE
#print axioms Benitoite.Release.pres_op_common
#print axioms Benitoite.Release.inv_prim_app
#print axioms Benitoite.Release.HasTypeVQ.inv_prim
#print axioms Benitoite.Release.HasTypeVQ.closed_opaque_top
#print axioms Benitoite.Release.PrimSig.inst_eq_of_closed_args
#print axioms Benitoite.Release.PrimSig.inst_cases
#print axioms Benitoite.Release.PrimSig.inst_eq
#print axioms Benitoite.Release.PrimSig.inst_fields
#print axioms Benitoite.Release.PrimSig.inst_top
#print axioms Benitoite.Release.PrimSig.inst_scoped
#print axioms Benitoite.Release.HasTypeVQ.V_PrimTop
#print axioms Benitoite.Release.PrimitiveAdmissible.outer
#print axioms Benitoite.Release.PrimitiveAdmissible.substTy
#print axioms Benitoite.Release.Model.assumptions
