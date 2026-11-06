import Benitoite.Release.Refinement.Surface.PredicateStandardFamilies

/-! # 標準行の署名の有限支持 -/
namespace Benitoite.Release.Refinement.Surface.PredicateStandardSupport
open StandardModel
noncomputable section

theorem support_p099 :
    Supported Primitive.p099.signature :=
  support_binary "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p100 :
    Supported Primitive.p100.signature :=
  support_binary "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p101 :
    Supported Primitive.p101.signature :=
  support_binary "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p102 :
    Supported Primitive.p102.signature :=
  support_binary "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean

theorem support_p103 :
    Supported Primitive.p103.signature :=
  support_binary "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean

theorem support_p104 :
    Supported Primitive.p104.signature :=
  support_binary "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean

theorem support_p105 :
    Supported Primitive.p105.signature :=
  support_binary "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean

theorem support_p106 :
    Supported Primitive.p106.signature :=
  support_binary "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p107 :
    Supported Primitive.p107.signature :=
  support_binary "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p108 :
    Supported Primitive.p108.signature :=
  support_binary "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64

theorem support_p109 :
    Supported Primitive.p109.signature :=
  support_structural

theorem support_p110 :
    Supported Primitive.p110.signature :=
  support_structural

theorem support_p111 :
    Supported Primitive.p111.signature :=
  support_binary "a" "b" .byte .byte .byte

theorem support_p112 :
    Supported Primitive.p112.signature :=
  support_binary "a" "b" .byte .byte .byte

theorem support_p113 :
    Supported Primitive.p113.signature :=
  support_unary "a" .byte .byte

theorem support_p114 :
    Supported Primitive.p114.signature :=
  support_binary "a" "b" .byte .byte .byte

theorem support_p115 :
    Supported Primitive.p115.signature :=
  support_option "n" .integer .byte

theorem support_p116 :
    Supported Primitive.p116.signature :=
  support_binary "a" "n" .byte .integer .byte

theorem support_p117 :
    Supported Primitive.p117.signature :=
  support_binary "a" "n" .byte .integer .byte

theorem support_p118 :
    Supported Primitive.p118.signature :=
  support_unary "b" .byte .integer

theorem support_p119 :
    Supported Primitive.p119.signature :=
  support_unary "b" .byte .string

theorem support_p120 :
    Supported Primitive.p120.signature :=
  support_bytesOrdinary .concatenate

theorem support_p121 :
    Supported Primitive.p121.signature :=
  support_bytesOrdinary .empty

theorem support_p122 :
    Supported Primitive.p122.signature :=
  support_bytesOrdinary .fromBinary

theorem support_p123 :
    Supported Primitive.p123.signature :=
  support_bytesOrdinary .fromHex

theorem support_p124 :
    Supported Primitive.p124.signature :=
  support_bytesOrdinary .fromIntegers

theorem support_p125 :
    Supported Primitive.p125.signature :=
  support_bytes .bytesFromList

theorem support_p126 :
    Supported Primitive.p126.signature :=
  support_bytesOrdinary .fromSigned

theorem support_p127 :
    Supported Primitive.p127.signature :=
  support_bytesOrdinary .fromUnsigned

theorem support_p128 :
    Supported Primitive.p128.signature :=
  support_bytesOrdinary .get

theorem support_p129 :
    Supported Primitive.p129.signature :=
  support_bytes .bytesLength

theorem support_p130 :
    Supported Primitive.p130.signature :=
  support_bytesOrdinary .readSigned

theorem support_p131 :
    Supported Primitive.p131.signature :=
  support_bytesOrdinary .readUnsigned

theorem support_p132 :
    Supported Primitive.p132.signature :=
  support_bytesOrdinary .slice

theorem support_p133 :
    Supported Primitive.p133.signature :=
  support_bytesOrdinary .toBinary

theorem support_p134 :
    Supported Primitive.p134.signature :=
  support_bytesOrdinary .toHex

theorem support_p135 :
    Supported Primitive.p135.signature :=
  support_bytes .bytesToList

theorem support_p136 :
    Supported Primitive.p136.signature :=
  support_option "n" .integer .character

theorem support_p137 :
    Supported Primitive.p137.signature :=
  support_unary "c" .character .boolean

theorem support_p138 :
    Supported Primitive.p138.signature :=
  support_unary "c" .character .boolean

theorem support_p139 :
    Supported Primitive.p139.signature :=
  support_unary "c" .character .boolean

theorem support_p140 :
    Supported Primitive.p140.signature :=
  support_unary "c" .character .boolean

theorem support_p141 :
    Supported Primitive.p141.signature :=
  support_unary "c" .character .boolean

theorem support_p142 :
    Supported Primitive.p142.signature :=
  support_unary "c" .character .boolean

theorem support_p143 :
    Supported Primitive.p143.signature :=
  support_unary "c" .character .boolean

theorem support_p144 :
    Supported Primitive.p144.signature :=
  support_unary "c" .character .integer

theorem support_p145 :
    Supported Primitive.p145.signature :=
  support_unary "c" .character .string

theorem support_p146 :
    Supported Primitive.p146.signature :=
  support_unary "c" .character .string

theorem support_p147 :
    Supported Primitive.p147.signature :=
  support_unary "c" .character .string

theorem support_p148 :
    Supported Primitive.p148.signature :=
  support_unary "x" .decimal .decimal

theorem support_p149 :
    Supported Primitive.p149.signature :=
  support_option "x" .float .decimal

theorem support_p150 :
    Supported Primitive.p150.signature :=
  support_unary "n" .integer .decimal

theorem support_p151 :
    Supported Primitive.p151.signature :=
  support_option "s" .string .decimal

theorem support_p152 :
    Supported Primitive.p152.signature :=
  support_decimal .round

theorem support_p153 :
    Supported Primitive.p153.signature :=
  support_unary "x" .decimal .float

theorem support_p154 :
    Supported Primitive.p154.signature :=
  support_unary "x" .decimal .string

theorem support_p155 :
    Supported Primitive.p155.signature :=
  support_option "x" .decimal .integer

theorem support_p156 :
    Supported Primitive.p156.signature := by
  change Supported ScopeSignatures.pathBases
  dsimp only [ScopeSignatures.pathBases, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p157 :
    Supported Primitive.p157.signature := by
  change Supported ScopeSignatures.appendBytesIn
  dsimp only [ScopeSignatures.appendBytesIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p158 :
    Supported Primitive.p158.signature := by
  change Supported ScopeSignatures.appendTextIn
  dsimp only [ScopeSignatures.appendTextIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p159 :
    Supported Primitive.p159.signature := by
  change Supported ScopeSignatures.readBytesIn
  dsimp only [ScopeSignatures.readBytesIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p160 :
    Supported Primitive.p160.signature := by
  change Supported ModelTargets.readTextSig
  dsimp only [ModelTargets.readTextSig, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p161 :
    Supported Primitive.p161.signature := by
  change Supported ScopeSignatures.readTextIn
  dsimp only [ScopeSignatures.readTextIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p162 :
    Supported Primitive.p162.signature := by
  change Supported ScopeSignatures.writeBytesIn
  dsimp only [ScopeSignatures.writeBytesIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p163 :
    Supported Primitive.p163.signature := by
  change Supported ScopeSignatures.writeTextIn
  dsimp only [ScopeSignatures.writeTextIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p164 :
    Supported Primitive.p164.signature :=
  support_unary "x" .float .float

theorem support_p165 :
    Supported Primitive.p165.signature :=
  support_unary "x" .float .float

theorem support_p166 :
    Supported Primitive.p166.signature :=
  support_unary "x" .float .float

theorem support_p167 :
    Supported Primitive.p167.signature :=
  support_unary "x" .float .boolean

theorem support_p168 :
    Supported Primitive.p168.signature :=
  support_option "s" .string .float

theorem support_p169 :
    Supported Primitive.p169.signature :=
  support_unary "x" .float .float

theorem support_p170 :
    Supported Primitive.p170.signature :=
  support_unary "x" .float .float

theorem support_p171 :
    Supported Primitive.p171.signature :=
  support_unary "x" .float .string

theorem support_p172 :
    Supported Primitive.p172.signature :=
  support_option "x" .float .integer

theorem support_p173 :
    Supported Primitive.p173.signature :=
  support_unary "n" .float32 .float32

theorem support_p174 :
    Supported Primitive.p174.signature :=
  support_unary "n" .float32 .float32

theorem support_p175 :
    Supported Primitive.p175.signature :=
  support_unary "n" .float32 .float32

theorem support_p176 :
    Supported Primitive.p176.signature :=
  support_option "n" .float .float32

theorem support_p177 :
    Supported Primitive.p177.signature :=
  support_unary "n" .float32 .boolean

theorem support_p178 :
    Supported Primitive.p178.signature :=
  support_unary "n" .float32 .boolean

theorem support_p179 :
    Supported Primitive.p179.signature :=
  support_option "s" .string .float32

theorem support_p180 :
    Supported Primitive.p180.signature :=
  support_unary "n" .float32 .float32

theorem support_p181 :
    Supported Primitive.p181.signature :=
  support_unary "n" .float32 .float32

theorem support_p182 :
    Supported Primitive.p182.signature :=
  support_unary "n" .float32 .float

theorem support_p183 :
    Supported Primitive.p183.signature :=
  support_unary "n" .float32 .string

theorem support_p184 :
    Supported Primitive.p184.signature :=
  support_option "n" .float32 .integer

theorem support_p185 :
    Supported Primitive.p185.signature := by
  change Supported ScopeSignatures.checkRequestIn
  dsimp only [ScopeSignatures.checkRequestIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p186 :
    Supported Primitive.p186.signature := by
  change Supported ScopeSignatures.requestInValue
  dsimp only [ScopeSignatures.requestInValue, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p187 :
    Supported Primitive.p187.signature := by
  change Supported ScopeSignatures.sendIn
  dsimp only [ScopeSignatures.sendIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p188 :
    Supported Primitive.p188.signature := by
  change Supported ScopeSignatures.widenRequestIn
  dsimp only [ScopeSignatures.widenRequestIn, ScopeSignatures.pureIn, ScopeSignatures.ioIn, ScopeSignatures.unscopedIO,
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

theorem support_p189 :
    Supported Primitive.p189.signature :=
  support_unary "n" .integer .integer

theorem support_p190 :
    Supported Primitive.p190.signature :=
  support_binary "a" "b" .integer .integer .integer

theorem support_p191 :
    Supported Primitive.p191.signature :=
  support_binary "a" "b" .integer .integer .integer

theorem support_p192 :
    Supported Primitive.p192.signature :=
  support_unary "a" .integer .integer

theorem support_p193 :
    Supported Primitive.p193.signature :=
  support_binary "a" "b" .integer .integer .integer

theorem support_p194 :
    Supported Primitive.p194.signature :=
  support_binary "a" "b" .integer .integer .integer

theorem support_p195 :
    Supported Primitive.p195.signature :=
  support_binary "a" "b" .integer .integer .integer

theorem support_p196 :
    Supported Primitive.p196.signature :=
  support_binary "a" "b" .integer .integer .integer

end
end Benitoite.Release.Refinement.Surface.PredicateStandardSupport
