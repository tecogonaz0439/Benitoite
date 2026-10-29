import Benitoite

open Benitoite

-- 新しい定理（L50.1、Exchange/Range.lean）
#print axioms Benitoite.Exchange.decodeNat_encodeNat
#print axioms Benitoite.Exchange.decodeWord_encodeWord
#print axioms Benitoite.Exchange.decodeKind_encodeKind
#print axioms Benitoite.Exchange.decodeFamily_encodeFamily
#print axioms Benitoite.Exchange.decodeIPAddr_encodeIPAddr
#print axioms Benitoite.Exchange.decodeCIDR_encodeCIDR
#print axioms Benitoite.Exchange.decodePathPattern_encode
#print axioms Benitoite.Exchange.decodeNamePattern_encode
#print axioms Benitoite.Exchange.decodeIPPattern_encode
#print axioms Benitoite.Exchange.decodeHostPattern_encode
#print axioms Benitoite.Exchange.decodePort_encodePort
#print axioms Benitoite.Exchange.decodeEndpointPattern_encode
#print axioms Benitoite.Exchange.decodeRange_encodeRange
#print axioms Benitoite.Exchange.decodeIx_encodeIx
#print axioms Benitoite.Exchange.legacy_name_atom_top
#print axioms Benitoite.Exchange.legacy_opaque_top
#print axioms Benitoite.Exchange.decodeIOShape_encode
#print axioms Benitoite.Exchange.AdmitsRule.check_sound
#print axioms Benitoite.Exchange.AdmitsEntry.admitsRDec_sound
-- 新しい定理（L50.1、Exchange/Convert.lean・Builtins.lean・CheckInput.lean）
#print axioms Benitoite.Exchange.Atom.toRelease_fromAtom
#print axioms Benitoite.Exchange.filterMap_toRelease_fromAtom
#print axioms Benitoite.Exchange.Atom.toRelease_top
#print axioms Benitoite.Exchange.legacy_atom_toRelease
#print axioms Benitoite.Exchange.legacy_opaque_toRelease
#print axioms Benitoite.Exchange.mem_writeAtoms_iff
#print axioms Benitoite.Exchange.readAtoms_writeAtoms
#print axioms Benitoite.Exchange.writeAtoms_readAtoms_writeAtoms
#print axioms Benitoite.Exchange.fromEffNames_ok
#print axioms Benitoite.Exchange.fromEffNames_error_of_unlisted
#print axioms Benitoite.Exchange.support_of_atomsIn
#print axioms Benitoite.Exchange.fromEffNames_complete_of_atomsIn
#print axioms Benitoite.Exchange.top_eff_roundtrip
#print axioms Benitoite.Exchange.BuiltinInput.admitsRDec_sound
#print axioms Benitoite.Exchange.CheckInput.Prepared.writeEffNames_complete
-- 既存の定理（L40.5、交換）
#print axioms Benitoite.Exchange.unlistedAtom?_eq_none
#print axioms Benitoite.Exchange.unlistedAtom?_complete
-- 主定理
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.step_target_sound
#print axioms Benitoite.Release.reachable_target_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
