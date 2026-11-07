import Benitoite.Release.Refinement.Surface.PredicateStandardFamilies

/-! # 標準行の署名の有限支持 -/
namespace Benitoite.Release.Refinement.Surface.PredicateStandardSupport
open StandardModel
noncomputable section

theorem support_p295 :
    Supported Primitive.p295.signature :=
  support_bytes .stringBytes

theorem support_p296 :
    Supported Primitive.p296.signature :=
  support_string .byteSlice

theorem support_p297 :
    Supported Primitive.p297.signature :=
  support_string .characterAt

theorem support_p298 :
    Supported Primitive.p298.signature :=
  support_bytes .stringCharacters

theorem support_p299 :
    Supported Primitive.p299.signature :=
  support_string .characterSlice

theorem support_p300 :
    Supported Primitive.p300.signature :=
  support_string .characters

theorem support_p301 :
    Supported Primitive.p301.signature :=
  support_string .contains

theorem support_p302 :
    Supported Primitive.p302.signature :=
  support_string .displayWidth

theorem support_p303 :
    Supported Primitive.p303.signature :=
  support_string .displayWidthCJK

theorem support_p304 :
    Supported Primitive.p304.signature :=
  support_string .displayWidthPadEnd

theorem support_p305 :
    Supported Primitive.p305.signature :=
  support_string .displayWidthPadEndCJK

theorem support_p306 :
    Supported Primitive.p306.signature :=
  support_string .displayWidthPadStart

theorem support_p307 :
    Supported Primitive.p307.signature :=
  support_string .displayWidthPadStartCJK

theorem support_p308 :
    Supported Primitive.p308.signature :=
  support_string .endsWith

theorem support_p309 :
    Supported Primitive.p309.signature :=
  support_string .fromCharacters

theorem support_p310 :
    Supported Primitive.p310.signature :=
  support_string .fromUTF8

theorem support_p311 :
    Supported Primitive.p311.signature :=
  support_string .isEmpty

theorem support_p312 :
    Supported Primitive.p312.signature :=
  support_string .join

theorem support_p313 :
    Supported Primitive.p313.signature :=
  support_string .lines

theorem support_p314 :
    Supported Primitive.p314.signature :=
  support_string .repeat

theorem support_p315 :
    Supported Primitive.p315.signature :=
  support_string .replace

theorem support_p316 :
    Supported Primitive.p316.signature :=
  support_string .split

theorem support_p317 :
    Supported Primitive.p317.signature :=
  support_string .startsWith

theorem support_p318 :
    Supported Primitive.p318.signature :=
  support_string .toLowercase

theorem support_p319 :
    Supported Primitive.p319.signature :=
  support_string .toUTF8

theorem support_p320 :
    Supported Primitive.p320.signature :=
  support_string .toUppercase

theorem support_p321 :
    Supported Primitive.p321.signature :=
  support_string .trim

theorem support_p322 :
    Supported Primitive.p322.signature :=
  support_unary "n" .unsignedInteger16 .unsignedInteger16

theorem support_p323 :
    Supported Primitive.p323.signature :=
  support_binary "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p324 :
    Supported Primitive.p324.signature :=
  support_binary "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p325 :
    Supported Primitive.p325.signature :=
  support_unary "a" .unsignedInteger16 .unsignedInteger16

theorem support_p326 :
    Supported Primitive.p326.signature :=
  support_binary "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p327 :
    Supported Primitive.p327.signature :=
  support_binary "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p328 :
    Supported Primitive.p328.signature :=
  support_binary "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p329 :
    Supported Primitive.p329.signature :=
  support_option "n" .integer .unsignedInteger16

theorem support_p330 :
    Supported Primitive.p330.signature :=
  support_binary "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p331 :
    Supported Primitive.p331.signature :=
  support_binary "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p332 :
    Supported Primitive.p332.signature :=
  support_option "s" .string .unsignedInteger16

theorem support_p333 :
    Supported Primitive.p333.signature :=
  support_binary "a" "n" .unsignedInteger16 .integer .unsignedInteger16

theorem support_p334 :
    Supported Primitive.p334.signature :=
  support_binary "a" "n" .unsignedInteger16 .integer .unsignedInteger16

theorem support_p335 :
    Supported Primitive.p335.signature :=
  support_unary "n" .unsignedInteger16 .float

theorem support_p336 :
    Supported Primitive.p336.signature :=
  support_unary "n" .unsignedInteger16 .integer

theorem support_p337 :
    Supported Primitive.p337.signature :=
  support_unary "n" .unsignedInteger16 .string

theorem support_p338 :
    Supported Primitive.p338.signature :=
  support_unary "n" .unsignedInteger32 .unsignedInteger32

theorem support_p339 :
    Supported Primitive.p339.signature :=
  support_binary "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p340 :
    Supported Primitive.p340.signature :=
  support_binary "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p341 :
    Supported Primitive.p341.signature :=
  support_unary "a" .unsignedInteger32 .unsignedInteger32

theorem support_p342 :
    Supported Primitive.p342.signature :=
  support_binary "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p343 :
    Supported Primitive.p343.signature :=
  support_binary "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p344 :
    Supported Primitive.p344.signature :=
  support_binary "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p345 :
    Supported Primitive.p345.signature :=
  support_option "n" .integer .unsignedInteger32

theorem support_p346 :
    Supported Primitive.p346.signature :=
  support_binary "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p347 :
    Supported Primitive.p347.signature :=
  support_binary "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p348 :
    Supported Primitive.p348.signature :=
  support_option "s" .string .unsignedInteger32

theorem support_p349 :
    Supported Primitive.p349.signature :=
  support_binary "a" "n" .unsignedInteger32 .integer .unsignedInteger32

theorem support_p350 :
    Supported Primitive.p350.signature :=
  support_binary "a" "n" .unsignedInteger32 .integer .unsignedInteger32

theorem support_p351 :
    Supported Primitive.p351.signature :=
  support_unary "n" .unsignedInteger32 .float

theorem support_p352 :
    Supported Primitive.p352.signature :=
  support_unary "n" .unsignedInteger32 .integer

theorem support_p353 :
    Supported Primitive.p353.signature :=
  support_unary "n" .unsignedInteger32 .string

theorem support_p354 :
    Supported Primitive.p354.signature :=
  support_unary "n" .unsignedInteger64 .unsignedInteger64

theorem support_p355 :
    Supported Primitive.p355.signature :=
  support_binary "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p356 :
    Supported Primitive.p356.signature :=
  support_binary "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p357 :
    Supported Primitive.p357.signature :=
  support_unary "a" .unsignedInteger64 .unsignedInteger64

theorem support_p358 :
    Supported Primitive.p358.signature :=
  support_binary "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p359 :
    Supported Primitive.p359.signature :=
  support_binary "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p360 :
    Supported Primitive.p360.signature :=
  support_binary "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p361 :
    Supported Primitive.p361.signature :=
  support_option "x" .decimal .unsignedInteger64

theorem support_p362 :
    Supported Primitive.p362.signature :=
  support_option "n" .integer .unsignedInteger64

theorem support_p363 :
    Supported Primitive.p363.signature :=
  support_binary "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p364 :
    Supported Primitive.p364.signature :=
  support_binary "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p365 :
    Supported Primitive.p365.signature :=
  support_option "s" .string .unsignedInteger64

theorem support_p366 :
    Supported Primitive.p366.signature :=
  support_binary "a" "n" .unsignedInteger64 .integer .unsignedInteger64

theorem support_p367 :
    Supported Primitive.p367.signature :=
  support_binary "a" "n" .unsignedInteger64 .integer .unsignedInteger64

theorem support_p368 :
    Supported Primitive.p368.signature :=
  support_unary "n" .unsignedInteger64 .decimal

theorem support_p369 :
    Supported Primitive.p369.signature :=
  support_unary "n" .unsignedInteger64 .float

theorem support_p370 :
    Supported Primitive.p370.signature :=
  support_option "n" .unsignedInteger64 .integer

theorem support_p371 :
    Supported Primitive.p371.signature :=
  support_unary "n" .unsignedInteger64 .string

theorem support_p372 :
    Supported Primitive.p372.signature := by
  change Supported ModelTargets.exitSig
  dsimp only [ModelTargets.exitSig, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
    ScopeSignatures.pathIn, ScopeSignatures.requestIn, ScopeSignatures.resultTy,
    ScopeSignatures.scopeErrorTy, atErrorType,
    ScopeSignatures.clientRequestTy, TargetTable.clientRequestTy,
    Benitoite.Release.TargetTable.clientRequestTy, embedTy, embedTys,
    Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single,
    Eff.atoms, atoms, stateEff, processEnvironmentEff]
  first
  | solve
    | simp_all
  | simp_all [decide_eq_true_eq]

theorem support_p373 :
    Supported Primitive.p373.signature := by
  change Supported ModelTargets.printSig
  dsimp only [ModelTargets.printSig, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
    ScopeSignatures.pathIn, ScopeSignatures.requestIn, ScopeSignatures.resultTy,
    ScopeSignatures.scopeErrorTy, atErrorType,
    ScopeSignatures.clientRequestTy, TargetTable.clientRequestTy,
    Benitoite.Release.TargetTable.clientRequestTy, embedTy, embedTys,
    Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single,
    Eff.atoms, atoms, stateEff, processEnvironmentEff]
  first
  | solve
    | simp_all
  | simp_all [decide_eq_true_eq]

theorem support_p374 :
    Supported Primitive.p374.signature :=
  support_store.2.2.1

theorem support_p375 :
    Supported Primitive.p375.signature :=
  support_store.1

theorem support_p376 :
    Supported Primitive.p376.signature :=
  support_store.2.1

theorem support_p377 :
    Supported Primitive.p377.signature :=
  support_store.2.2.2

theorem support_p378 :
    Supported Primitive.p378.signature :=
  support_predicate (.path)

theorem support_p379 :
    Supported Primitive.p379.signature :=
  support_predicate (.host)

theorem support_p380 :
    Supported Primitive.p380.signature :=
  support_predicate (.characters)

theorem support_p381 :
    Supported Primitive.p381.signature :=
  support_predicate (.floating .binary64 .finite)

theorem support_p382 :
    Supported Primitive.p382.signature :=
  support_predicate (.floating .binary64 .infinite)

theorem support_p383 :
    Supported Primitive.p383.signature :=
  support_predicate (.floating .binary64 .positiveInfinity)

theorem support_p384 :
    Supported Primitive.p384.signature :=
  support_predicate (.floating .binary64 .negativeInfinity)

theorem support_p385 :
    Supported Primitive.p385.signature :=
  support_predicate (.floating .binary64 .positiveZero)

theorem support_p386 :
    Supported Primitive.p386.signature :=
  support_predicate (.floating .binary64 .negativeZero)

theorem support_p387 :
    Supported Primitive.p387.signature :=
  support_predicate (.floating .binary32 .finite)

theorem support_p388 :
    Supported Primitive.p388.signature :=
  support_predicate (.floating .binary32 .positiveInfinity)

theorem support_p389 :
    Supported Primitive.p389.signature :=
  support_predicate (.floating .binary32 .negativeInfinity)

theorem support_p390 :
    Supported Primitive.p390.signature :=
  support_predicate (.floating .binary32 .positiveZero)

theorem support_p391 :
    Supported Primitive.p391.signature :=
  support_predicate (.floating .binary32 .negativeZero)

theorem support_p392 :
    Supported Primitive.p392.signature :=
  support_check

end
end Benitoite.Release.Refinement.Surface.PredicateStandardSupport
