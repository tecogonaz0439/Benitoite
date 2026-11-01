import Benitoite.Release.Refinement.HandlerOperation

set_option pp.universes true
set_option pp.fullNames true

#check @Benitoite.Release.Refinement.HandlerFrameTy
#check @Benitoite.Release.Refinement.ContTy.nil_inv
#check @Benitoite.Release.Refinement.ContTy.resume_append
#check @Benitoite.Release.Refinement.ContTy.split_handle
#check @Benitoite.Release.Refinement.StoreOk.use_continuation
#check @Benitoite.Release.Refinement.StoreOk.allocate_continuation
#check @Benitoite.Release.Refinement.Program.EffectsOk
#check @Benitoite.Release.Refinement.NoStateHandled
#check @Benitoite.Release.Refinement.ContTy.state_end
#check @Benitoite.Release.Refinement.ContTy.prepend_releases
#check @Benitoite.Release.Refinement.Program.EffectsOk.noStateHandled
#check @Benitoite.Release.Refinement.ContTy.fail_input
#check @Benitoite.Release.Refinement.ContTy.split_fail
#check @Benitoite.Release.Refinement.HasTypeCQ.operation_call
#check @Benitoite.Release.Refinement.ClosureTy.pure_operation
#check @Benitoite.Release.Refinement.ClosureTy.pure_operation_signature
#check @Benitoite.Release.Refinement.telExtend
#check @Benitoite.Release.Refinement.telLift
#check @Benitoite.Release.Refinement.telExtend_sig
#check @Benitoite.Release.Refinement.capture_tel
#check @Benitoite.Release.Refinement.result_tel
#check @Benitoite.Release.Refinement.args_under_capture
#check @Benitoite.Release.Refinement.ContTy.return_annotation
#check @Benitoite.Release.Refinement.StateTyE.handler_return_const
#check @Benitoite.Release.Refinement.StateTyE.drop_used_const
#check @Benitoite.Release.Refinement.StateTyE.resume_used
#check @Benitoite.Release.Refinement.StateTyE.resume_const
#check @Benitoite.Release.Refinement.releases_mem
#check @Benitoite.Release.Refinement.StateTyE.drop_rel_const
#check @Benitoite.Release.Refinement.StateTyE.esc_drop_rel_const
#check @Benitoite.Release.Refinement.StateTyE.err_drop_rel
#check @Benitoite.Release.Refinement.StateTyE.exit_drop_rel
#check @Benitoite.Release.Refinement.ContTy.guard_effect
#check @Benitoite.Release.Refinement.StateTyE.operation_under_guard_false
#check @Benitoite.Release.Refinement.ClosureTy.widen_atoms
#check @Benitoite.Release.Refinement.StateTyE.operation_one

#check @Benitoite.Release.Refinement.Builtins.CoreAssumptions.state_effect
#print Benitoite.Release.Refinement.Program.EffectsOk
