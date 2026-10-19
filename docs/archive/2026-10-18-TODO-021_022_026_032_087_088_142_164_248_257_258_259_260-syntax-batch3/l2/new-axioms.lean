import Benitoite
-- Resultの小モデル。主定理の外に置く。
#print axioms Benitoite.Library.ResultLaws.flatMap_left_identity
#print axioms Benitoite.Library.ResultLaws.flatMap_right_identity
#print axioms Benitoite.Library.ResultLaws.flatMap_associativity
#print axioms Benitoite.Library.ResultLaws.map_identity
#print axioms Benitoite.Library.ResultLaws.map_composition
#print axioms Benitoite.Library.ResultLaws.map_flatMap
#print axioms Benitoite.Library.ResultLaws.apply_flatMap
#print axioms Benitoite.Library.ResultLaws.apply_error_priority
#print axioms Benitoite.Library.ResultLaws.projected_map
#print axioms Benitoite.Library.ResultLaws.projected_pure
#print axioms Benitoite.Library.ResultLaws.projected_apply
#print axioms Benitoite.Library.ResultLaws.dictionary_type_does_not_imply_law
-- 本体の判断・性質1とコアの実行へ接続する具体例。
#print axioms Benitoite.Surface.Monad2Examples.result_constructor_wf
#print axioms Benitoite.Surface.Monad2Examples.result_constructor_sat
#print axioms Benitoite.Surface.Monad2Examples.generic_dictionary_position
#print axioms Benitoite.Surface.Monad2Examples.program_checked
#print axioms Benitoite.Surface.Monad2Examples.implementation_contracts
#print axioms Benitoite.Surface.Monad2Examples.program_typed
#print axioms Benitoite.Surface.Monad2Examples.program_wellFormed
#print axioms Benitoite.Surface.Monad2Examples.desugared_typed
#print axioms Benitoite.Surface.Monad2Examples.map_value_capture
#print axioms Benitoite.Surface.Monad2Examples.flatMap_value_capture
#print axioms Benitoite.Surface.Monad2Examples.expressions_checked
#print axioms Benitoite.Surface.Monad2Examples.executions_expected
#print axioms Benitoite.Surface.Monad2Examples.mismatched_error_rejected
#print axioms Benitoite.Surface.Monad2Examples.wrong_target_rejected
#print axioms Benitoite.Surface.Monad2Examples.constructor_dictionary_checked
