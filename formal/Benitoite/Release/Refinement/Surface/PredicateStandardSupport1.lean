import Benitoite.Release.Refinement.Surface.PredicateStandardFamilies

/-! # 標準行の署名の有限支持 -/
namespace Benitoite.Release.Refinement.Surface.PredicateStandardSupport
open StandardModel
noncomputable section

theorem support_p001 :
    Supported Primitive.p001.signature :=
  support_binary "left" "right" .byte .byte .boolean

theorem support_p002 :
    Supported Primitive.p002.signature :=
  support_binary "left" "right" .byte .byte .boolean

theorem support_p003 :
    Supported Primitive.p003.signature :=
  support_binary "left" "right" .byte .byte .boolean

theorem support_p004 :
    Supported Primitive.p004.signature :=
  support_binary "left" "right" .byte .byte .boolean

theorem support_p005 :
    Supported Primitive.p005.signature :=
  support_binary "left" "right" .character .character .boolean

theorem support_p006 :
    Supported Primitive.p006.signature :=
  support_binary "left" "right" .character .character .boolean

theorem support_p007 :
    Supported Primitive.p007.signature :=
  support_binary "left" "right" .character .character .boolean

theorem support_p008 :
    Supported Primitive.p008.signature :=
  support_binary "left" "right" .character .character .boolean

theorem support_p009 :
    Supported Primitive.p009.signature :=
  support_binary "left" "right" .decimal .decimal .decimal

theorem support_p010 :
    Supported Primitive.p010.signature :=
  support_binary "left" "right" .decimal .decimal .decimal

theorem support_p011 :
    Supported Primitive.p011.signature :=
  support_binary "left" "right" .decimal .decimal .boolean

theorem support_p012 :
    Supported Primitive.p012.signature :=
  support_binary "left" "right" .decimal .decimal .boolean

theorem support_p013 :
    Supported Primitive.p013.signature :=
  support_binary "left" "right" .decimal .decimal .boolean

theorem support_p014 :
    Supported Primitive.p014.signature :=
  support_binary "left" "right" .decimal .decimal .boolean

theorem support_p015 :
    Supported Primitive.p015.signature :=
  support_binary "left" "right" .decimal .decimal .decimal

theorem support_p016 :
    Supported Primitive.p016.signature :=
  support_unary "value" .decimal .decimal

theorem support_p017 :
    Supported Primitive.p017.signature :=
  support_binary "left" "right" .decimal .decimal .decimal

theorem support_p018 :
    Supported Primitive.p018.signature :=
  support_binary "left" "right" .float .float .float

theorem support_p019 :
    Supported Primitive.p019.signature :=
  support_binary "left" "right" .float .float .float

theorem support_p020 :
    Supported Primitive.p020.signature :=
  support_binary "left" "right" .float .float .boolean

theorem support_p021 :
    Supported Primitive.p021.signature :=
  support_binary "left" "right" .float .float .boolean

theorem support_p022 :
    Supported Primitive.p022.signature :=
  support_binary "left" "right" .float .float .boolean

theorem support_p023 :
    Supported Primitive.p023.signature :=
  support_binary "left" "right" .float .float .boolean

theorem support_p024 :
    Supported Primitive.p024.signature :=
  support_binary "left" "right" .float .float .float

theorem support_p025 :
    Supported Primitive.p025.signature :=
  support_unary "value" .float .float

theorem support_p026 :
    Supported Primitive.p026.signature :=
  support_binary "left" "right" .float .float .float

theorem support_p027 :
    Supported Primitive.p027.signature :=
  support_binary "left" "right" .float32 .float32 .float32

theorem support_p028 :
    Supported Primitive.p028.signature :=
  support_binary "left" "right" .float32 .float32 .float32

theorem support_p029 :
    Supported Primitive.p029.signature :=
  support_binary "left" "right" .float32 .float32 .boolean

theorem support_p030 :
    Supported Primitive.p030.signature :=
  support_binary "left" "right" .float32 .float32 .boolean

theorem support_p031 :
    Supported Primitive.p031.signature :=
  support_binary "left" "right" .float32 .float32 .boolean

theorem support_p032 :
    Supported Primitive.p032.signature :=
  support_binary "left" "right" .float32 .float32 .boolean

theorem support_p033 :
    Supported Primitive.p033.signature :=
  support_binary "left" "right" .float32 .float32 .float32

theorem support_p034 :
    Supported Primitive.p034.signature :=
  support_unary "value" .float32 .float32

theorem support_p035 :
    Supported Primitive.p035.signature :=
  support_binary "left" "right" .float32 .float32 .float32

theorem support_p036 :
    Supported Primitive.p036.signature :=
  support_binary "left" "right" .integer .integer .integer

theorem support_p037 :
    Supported Primitive.p037.signature :=
  support_binary "left" "right" .integer .integer .integer

theorem support_p038 :
    Supported Primitive.p038.signature :=
  support_binary "left" "right" .integer .integer .boolean

theorem support_p039 :
    Supported Primitive.p039.signature :=
  support_binary "left" "right" .integer .integer .boolean

theorem support_p040 :
    Supported Primitive.p040.signature :=
  support_binary "left" "right" .integer .integer .boolean

theorem support_p041 :
    Supported Primitive.p041.signature :=
  support_binary "left" "right" .integer .integer .boolean

theorem support_p042 :
    Supported Primitive.p042.signature :=
  support_binary "left" "right" .integer .integer .integer

theorem support_p043 :
    Supported Primitive.p043.signature :=
  support_binary "left" "right" .integer .integer .integer

theorem support_p044 :
    Supported Primitive.p044.signature :=
  support_unary "value" .integer .integer

theorem support_p045 :
    Supported Primitive.p045.signature :=
  support_binary "left" "right" .integer .integer .integer

theorem support_p046 :
    Supported Primitive.p046.signature :=
  support_binary "left" "right" .integer16 .integer16 .integer16

theorem support_p047 :
    Supported Primitive.p047.signature :=
  support_binary "left" "right" .integer16 .integer16 .integer16

theorem support_p048 :
    Supported Primitive.p048.signature :=
  support_binary "left" "right" .integer16 .integer16 .boolean

theorem support_p049 :
    Supported Primitive.p049.signature :=
  support_binary "left" "right" .integer16 .integer16 .boolean

theorem support_p050 :
    Supported Primitive.p050.signature :=
  support_binary "left" "right" .integer16 .integer16 .boolean

theorem support_p051 :
    Supported Primitive.p051.signature :=
  support_binary "left" "right" .integer16 .integer16 .boolean

theorem support_p052 :
    Supported Primitive.p052.signature :=
  support_binary "left" "right" .integer16 .integer16 .integer16

theorem support_p053 :
    Supported Primitive.p053.signature :=
  support_binary "left" "right" .integer16 .integer16 .integer16

theorem support_p054 :
    Supported Primitive.p054.signature :=
  support_unary "value" .integer16 .integer16

theorem support_p055 :
    Supported Primitive.p055.signature :=
  support_binary "left" "right" .integer16 .integer16 .integer16

theorem support_p056 :
    Supported Primitive.p056.signature :=
  support_binary "left" "right" .integer32 .integer32 .integer32

theorem support_p057 :
    Supported Primitive.p057.signature :=
  support_binary "left" "right" .integer32 .integer32 .integer32

theorem support_p058 :
    Supported Primitive.p058.signature :=
  support_binary "left" "right" .integer32 .integer32 .boolean

theorem support_p059 :
    Supported Primitive.p059.signature :=
  support_binary "left" "right" .integer32 .integer32 .boolean

theorem support_p060 :
    Supported Primitive.p060.signature :=
  support_binary "left" "right" .integer32 .integer32 .boolean

theorem support_p061 :
    Supported Primitive.p061.signature :=
  support_binary "left" "right" .integer32 .integer32 .boolean

theorem support_p062 :
    Supported Primitive.p062.signature :=
  support_binary "left" "right" .integer32 .integer32 .integer32

theorem support_p063 :
    Supported Primitive.p063.signature :=
  support_binary "left" "right" .integer32 .integer32 .integer32

theorem support_p064 :
    Supported Primitive.p064.signature :=
  support_unary "value" .integer32 .integer32

theorem support_p065 :
    Supported Primitive.p065.signature :=
  support_binary "left" "right" .integer32 .integer32 .integer32

theorem support_p066 :
    Supported Primitive.p066.signature :=
  support_binary "left" "right" .integer8 .integer8 .integer8

theorem support_p067 :
    Supported Primitive.p067.signature :=
  support_binary "left" "right" .integer8 .integer8 .integer8

theorem support_p068 :
    Supported Primitive.p068.signature :=
  support_binary "left" "right" .integer8 .integer8 .boolean

theorem support_p069 :
    Supported Primitive.p069.signature :=
  support_binary "left" "right" .integer8 .integer8 .boolean

theorem support_p070 :
    Supported Primitive.p070.signature :=
  support_binary "left" "right" .integer8 .integer8 .boolean

theorem support_p071 :
    Supported Primitive.p071.signature :=
  support_binary "left" "right" .integer8 .integer8 .boolean

theorem support_p072 :
    Supported Primitive.p072.signature :=
  support_binary "left" "right" .integer8 .integer8 .integer8

theorem support_p073 :
    Supported Primitive.p073.signature :=
  support_binary "left" "right" .integer8 .integer8 .integer8

theorem support_p074 :
    Supported Primitive.p074.signature :=
  support_unary "value" .integer8 .integer8

theorem support_p075 :
    Supported Primitive.p075.signature :=
  support_binary "left" "right" .integer8 .integer8 .integer8

theorem support_p076 :
    Supported Primitive.p076.signature :=
  support_replaceValues

theorem support_p077 :
    Supported Primitive.p077.signature :=
  support_binary "left" "right" .string .string .string

theorem support_p078 :
    Supported Primitive.p078.signature :=
  support_binary "left" "right" .string .string .boolean

theorem support_p079 :
    Supported Primitive.p079.signature :=
  support_binary "left" "right" .string .string .boolean

theorem support_p080 :
    Supported Primitive.p080.signature :=
  support_binary "left" "right" .string .string .boolean

theorem support_p081 :
    Supported Primitive.p081.signature :=
  support_binary "left" "right" .string .string .boolean

theorem support_p082 :
    Supported Primitive.p082.signature :=
  support_binary "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p083 :
    Supported Primitive.p083.signature :=
  support_binary "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p084 :
    Supported Primitive.p084.signature :=
  support_binary "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean

theorem support_p085 :
    Supported Primitive.p085.signature :=
  support_binary "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean

theorem support_p086 :
    Supported Primitive.p086.signature :=
  support_binary "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean

theorem support_p087 :
    Supported Primitive.p087.signature :=
  support_binary "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean

theorem support_p088 :
    Supported Primitive.p088.signature :=
  support_binary "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p089 :
    Supported Primitive.p089.signature :=
  support_binary "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p090 :
    Supported Primitive.p090.signature :=
  support_binary "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16

theorem support_p091 :
    Supported Primitive.p091.signature :=
  support_binary "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p092 :
    Supported Primitive.p092.signature :=
  support_binary "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p093 :
    Supported Primitive.p093.signature :=
  support_binary "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean

theorem support_p094 :
    Supported Primitive.p094.signature :=
  support_binary "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean

theorem support_p095 :
    Supported Primitive.p095.signature :=
  support_binary "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean

theorem support_p096 :
    Supported Primitive.p096.signature :=
  support_binary "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean

theorem support_p097 :
    Supported Primitive.p097.signature :=
  support_binary "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

theorem support_p098 :
    Supported Primitive.p098.signature :=
  support_binary "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32

end
end Benitoite.Release.Refinement.Surface.PredicateStandardSupport
