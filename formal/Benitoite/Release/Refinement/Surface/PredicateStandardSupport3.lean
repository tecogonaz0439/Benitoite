import Benitoite.Release.Refinement.Surface.PredicateStandardFamilies

/-! # 標準行の署名の有限支持 -/
namespace Benitoite.Release.Refinement.Surface.PredicateStandardSupport
open StandardModel
noncomputable section

theorem support_p197 :
    Supported Primitive.p197.signature :=
  support_binary "a" "b" .integer .integer .integer

theorem support_p198 :
    Supported Primitive.p198.signature :=
  support_option "s" .string .integer

theorem support_p199 :
    Supported Primitive.p199.signature :=
  support_binary "a" "n" .integer .integer .integer

theorem support_p200 :
    Supported Primitive.p200.signature :=
  support_binary "a" "n" .integer .integer .integer

theorem support_p201 :
    Supported Primitive.p201.signature :=
  support_binary "a" "n" .integer .integer .integer

theorem support_p202 :
    Supported Primitive.p202.signature :=
  support_unary "n" .integer .float

theorem support_p203 :
    Supported Primitive.p203.signature :=
  support_unary "n" .integer .string

theorem support_p204 :
    Supported Primitive.p204.signature :=
  support_unary "n" .integer16 .integer16

theorem support_p205 :
    Supported Primitive.p205.signature :=
  support_binary "a" "b" .integer16 .integer16 .integer16

theorem support_p206 :
    Supported Primitive.p206.signature :=
  support_binary "a" "b" .integer16 .integer16 .integer16

theorem support_p207 :
    Supported Primitive.p207.signature :=
  support_unary "a" .integer16 .integer16

theorem support_p208 :
    Supported Primitive.p208.signature :=
  support_binary "a" "b" .integer16 .integer16 .integer16

theorem support_p209 :
    Supported Primitive.p209.signature :=
  support_binary "a" "b" .integer16 .integer16 .integer16

theorem support_p210 :
    Supported Primitive.p210.signature :=
  support_binary "a" "b" .integer16 .integer16 .integer16

theorem support_p211 :
    Supported Primitive.p211.signature :=
  support_option "n" .integer .integer16

theorem support_p212 :
    Supported Primitive.p212.signature :=
  support_binary "a" "b" .integer16 .integer16 .integer16

theorem support_p213 :
    Supported Primitive.p213.signature :=
  support_binary "a" "b" .integer16 .integer16 .integer16

theorem support_p214 :
    Supported Primitive.p214.signature :=
  support_option "s" .string .integer16

theorem support_p215 :
    Supported Primitive.p215.signature :=
  support_binary "a" "n" .integer16 .integer .integer16

theorem support_p216 :
    Supported Primitive.p216.signature :=
  support_binary "a" "n" .integer16 .integer .integer16

theorem support_p217 :
    Supported Primitive.p217.signature :=
  support_binary "a" "n" .integer16 .integer .integer16

theorem support_p218 :
    Supported Primitive.p218.signature :=
  support_unary "n" .integer16 .float

theorem support_p219 :
    Supported Primitive.p219.signature :=
  support_unary "n" .integer16 .integer

theorem support_p220 :
    Supported Primitive.p220.signature :=
  support_unary "n" .integer16 .string

theorem support_p221 :
    Supported Primitive.p221.signature :=
  support_unary "n" .integer32 .integer32

theorem support_p222 :
    Supported Primitive.p222.signature :=
  support_binary "a" "b" .integer32 .integer32 .integer32

theorem support_p223 :
    Supported Primitive.p223.signature :=
  support_binary "a" "b" .integer32 .integer32 .integer32

theorem support_p224 :
    Supported Primitive.p224.signature :=
  support_unary "a" .integer32 .integer32

theorem support_p225 :
    Supported Primitive.p225.signature :=
  support_binary "a" "b" .integer32 .integer32 .integer32

theorem support_p226 :
    Supported Primitive.p226.signature :=
  support_binary "a" "b" .integer32 .integer32 .integer32

theorem support_p227 :
    Supported Primitive.p227.signature :=
  support_binary "a" "b" .integer32 .integer32 .integer32

theorem support_p228 :
    Supported Primitive.p228.signature :=
  support_option "n" .integer .integer32

theorem support_p229 :
    Supported Primitive.p229.signature :=
  support_binary "a" "b" .integer32 .integer32 .integer32

theorem support_p230 :
    Supported Primitive.p230.signature :=
  support_binary "a" "b" .integer32 .integer32 .integer32

theorem support_p231 :
    Supported Primitive.p231.signature :=
  support_option "s" .string .integer32

theorem support_p232 :
    Supported Primitive.p232.signature :=
  support_binary "a" "n" .integer32 .integer .integer32

theorem support_p233 :
    Supported Primitive.p233.signature :=
  support_binary "a" "n" .integer32 .integer .integer32

theorem support_p234 :
    Supported Primitive.p234.signature :=
  support_binary "a" "n" .integer32 .integer .integer32

theorem support_p235 :
    Supported Primitive.p235.signature :=
  support_unary "n" .integer32 .float

theorem support_p236 :
    Supported Primitive.p236.signature :=
  support_unary "n" .integer32 .integer

theorem support_p237 :
    Supported Primitive.p237.signature :=
  support_unary "n" .integer32 .string

theorem support_p238 :
    Supported Primitive.p238.signature :=
  support_unary "n" .integer8 .integer8

theorem support_p239 :
    Supported Primitive.p239.signature :=
  support_binary "a" "b" .integer8 .integer8 .integer8

theorem support_p240 :
    Supported Primitive.p240.signature :=
  support_binary "a" "b" .integer8 .integer8 .integer8

theorem support_p241 :
    Supported Primitive.p241.signature :=
  support_unary "a" .integer8 .integer8

theorem support_p242 :
    Supported Primitive.p242.signature :=
  support_binary "a" "b" .integer8 .integer8 .integer8

theorem support_p243 :
    Supported Primitive.p243.signature :=
  support_binary "a" "b" .integer8 .integer8 .integer8

theorem support_p244 :
    Supported Primitive.p244.signature :=
  support_binary "a" "b" .integer8 .integer8 .integer8

theorem support_p245 :
    Supported Primitive.p245.signature :=
  support_option "n" .integer .integer8

theorem support_p246 :
    Supported Primitive.p246.signature :=
  support_binary "a" "b" .integer8 .integer8 .integer8

theorem support_p247 :
    Supported Primitive.p247.signature :=
  support_binary "a" "b" .integer8 .integer8 .integer8

theorem support_p248 :
    Supported Primitive.p248.signature :=
  support_option "s" .string .integer8

theorem support_p249 :
    Supported Primitive.p249.signature :=
  support_binary "a" "n" .integer8 .integer .integer8

theorem support_p250 :
    Supported Primitive.p250.signature :=
  support_binary "a" "n" .integer8 .integer .integer8

theorem support_p251 :
    Supported Primitive.p251.signature :=
  support_binary "a" "n" .integer8 .integer .integer8

theorem support_p252 :
    Supported Primitive.p252.signature :=
  support_unary "n" .integer8 .float

theorem support_p253 :
    Supported Primitive.p253.signature :=
  support_unary "n" .integer8 .integer

theorem support_p254 :
    Supported Primitive.p254.signature :=
  support_unary "n" .integer8 .string

theorem support_p255 :
    Supported Primitive.p255.signature :=
  support_append

theorem support_p256 :
    Supported Primitive.p256.signature :=
  support_list .concatenate

theorem support_p257 :
    Supported Primitive.p257.signature :=
  support_listRemaining .contains

theorem support_p258 :
    Supported Primitive.p258.signature :=
  support_listRemaining .drop

theorem support_p259 :
    Supported Primitive.p259.signature :=
  support_listRemaining .get

theorem support_p260 :
    Supported Primitive.p260.signature :=
  support_headTail false

theorem support_p261 :
    Supported Primitive.p261.signature :=
  support_list .isEmpty

theorem support_p262 :
    Supported Primitive.p262.signature :=
  support_list .length

theorem support_p263 :
    Supported Primitive.p263.signature :=
  support_list .prepend

theorem support_p264 :
    Supported Primitive.p264.signature :=
  support_range

theorem support_p265 :
    Supported Primitive.p265.signature :=
  support_list .reverse

theorem support_p266 :
    Supported Primitive.p266.signature :=
  support_listRemaining .sort

theorem support_p267 :
    Supported Primitive.p267.signature :=
  support_headTail true

theorem support_p268 :
    Supported Primitive.p268.signature :=
  support_listRemaining .take

theorem support_p269 :
    Supported Primitive.p269.signature :=
  support_map .contains

theorem support_p270 :
    Supported Primitive.p270.signature :=
  support_map .empty

theorem support_p271 :
    Supported Primitive.p271.signature :=
  support_precision true true

theorem support_p272 :
    Supported Primitive.p272.signature :=
  support_map .get

theorem support_p273 :
    Supported Primitive.p273.signature :=
  support_map .keys

theorem support_p274 :
    Supported Primitive.p274.signature :=
  support_map .remove

theorem support_p275 :
    Supported Primitive.p275.signature :=
  support_map .set

theorem support_p276 :
    Supported Primitive.p276.signature :=
  support_map .size

theorem support_p277 :
    Supported Primitive.p277.signature :=
  support_precision true false

theorem support_p278 :
    Supported Primitive.p278.signature :=
  support_map .values

theorem support_p279 :
    Supported Primitive.p279.signature := by
  change Supported ScopeSignatures.refGet
  dsimp only [ScopeSignatures.refGet, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p280 :
    Supported Primitive.p280.signature := by
  change Supported ScopeSignatures.refSet
  dsimp only [ScopeSignatures.refSet, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p281 :
    Supported Primitive.p281.signature := by
  change Supported ScopeSignatures.checkPathIn
  dsimp only [ScopeSignatures.checkPathIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p282 :
    Supported Primitive.p282.signature := by
  change Supported ScopeSignatures.pathInValue
  dsimp only [ScopeSignatures.pathInValue, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p283 :
    Supported Primitive.p283.signature := by
  change Supported ScopeSignatures.widenPathIn
  dsimp only [ScopeSignatures.widenPathIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p284 :
    Supported Primitive.p284.signature :=
  support_set .add

theorem support_p285 :
    Supported Primitive.p285.signature :=
  support_set .contains

theorem support_p286 :
    Supported Primitive.p286.signature :=
  support_set .difference

theorem support_p287 :
    Supported Primitive.p287.signature :=
  support_set .empty

theorem support_p288 :
    Supported Primitive.p288.signature :=
  support_precision false true

theorem support_p289 :
    Supported Primitive.p289.signature :=
  support_set .intersection

theorem support_p290 :
    Supported Primitive.p290.signature :=
  support_set .remove

theorem support_p291 :
    Supported Primitive.p291.signature :=
  support_set .size

theorem support_p292 :
    Supported Primitive.p292.signature :=
  support_precision false false

theorem support_p293 :
    Supported Primitive.p293.signature :=
  support_set .union

theorem support_p294 :
    Supported Primitive.p294.signature :=
  support_string .byteIndexOf

end
end Benitoite.Release.Refinement.Surface.PredicateStandardSupport
