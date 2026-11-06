import Benitoite.Release.Refinement.Surface.CheckArguments
import Benitoite.Release.Refinement.StandardModelApplicationExamples

/-! # 完成した標準表の署名の有限支持 -/
namespace Benitoite.Release.Refinement.Surface.StandardSupport
noncomputable section
open StandardModel CheckArguments
set_option linter.unusedSimpArgs false

/-- 標準署名が参照する行原子と操作効果の有限の一覧。 -/
def atoms : List Atom := [.rho 0, .rho 1,
  .name "State" (.fixed .top), .name "Console.Write" (.fixed .top),
  .name "Process.Exit" (.fixed .top), .name "Process.Environment" (.fixed .top),
  .name "File.Read" (.fixed .top), .name "File.Write" (.fixed .top),
  .name "Http.Connect" (.fixed .top), .name "File.Read" (.rvar 0),
  .name "File.Write" (.rvar 0), .name "Http.Connect" (.rvar 0)]

private def Supported (sat : List TParam → Ty → TParam → Prop) (row : Primitive) : Prop :=
  let s := row.signatureWith sat
  SignatureSupport atoms s.params s.ret s.eff s.tel

private theorem support001 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p001 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support016 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p016 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support076 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p076 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support115 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p115 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support121 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p121 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support126 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p126 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support128 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p128 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support130 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p130 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support152 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p152 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support156 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p156 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support157 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p157 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support159 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p159 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support160 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p160 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support185 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p185 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support187 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p187 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support269 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p269 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support270 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p270 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support271 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p271 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support273 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p273 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support275 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p275 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support277 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p277 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support279 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p279 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support280 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p280 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support281 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p281 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support372 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p372 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support373 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p373 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support376 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p376 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem support392 (sat : List TParam → Ty → TParam → Prop) : Supported sat .p392 := by
  repeat' constructor
  all_goals intro a h
  all_goals cases a <;> simp_all [Eff.empty, Eff.row, Eff.single, atoms, stateEff, processEnvironmentEff]

private theorem group1 (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    match row with
    | .p001 | .p002 | .p003 | .p004 | .p005 | .p006 | .p007 | .p008 | .p009 | .p010 | .p011 | .p012 | .p013 | .p014 | .p015 | .p016 | .p017 | .p018 | .p019 | .p020 | .p021 | .p022 | .p023 | .p024 | .p025 | .p026 | .p027 | .p028 | .p029 | .p030 | .p031 | .p032 | .p033 | .p034 | .p035 | .p036 | .p037 | .p038 | .p039 | .p040 | .p041 | .p042 | .p043 | .p044 | .p045 | .p046 | .p047 | .p048 | .p049 | .p050 => Supported sat row
    | _ => True := by
    cases row
    case p001 => exact support001 sat
    case p002 => exact support001 sat
    case p003 => exact support001 sat
    case p004 => exact support001 sat
    case p005 => exact support001 sat
    case p006 => exact support001 sat
    case p007 => exact support001 sat
    case p008 => exact support001 sat
    case p009 => exact support001 sat
    case p010 => exact support001 sat
    case p011 => exact support001 sat
    case p012 => exact support001 sat
    case p013 => exact support001 sat
    case p014 => exact support001 sat
    case p015 => exact support001 sat
    case p016 => exact support016 sat
    case p017 => exact support001 sat
    case p018 => exact support001 sat
    case p019 => exact support001 sat
    case p020 => exact support001 sat
    case p021 => exact support001 sat
    case p022 => exact support001 sat
    case p023 => exact support001 sat
    case p024 => exact support001 sat
    case p025 => exact support016 sat
    case p026 => exact support001 sat
    case p027 => exact support001 sat
    case p028 => exact support001 sat
    case p029 => exact support001 sat
    case p030 => exact support001 sat
    case p031 => exact support001 sat
    case p032 => exact support001 sat
    case p033 => exact support001 sat
    case p034 => exact support016 sat
    case p035 => exact support001 sat
    case p036 => exact support001 sat
    case p037 => exact support001 sat
    case p038 => exact support001 sat
    case p039 => exact support001 sat
    case p040 => exact support001 sat
    case p041 => exact support001 sat
    case p042 => exact support001 sat
    case p043 => exact support001 sat
    case p044 => exact support016 sat
    case p045 => exact support001 sat
    case p046 => exact support001 sat
    case p047 => exact support001 sat
    case p048 => exact support001 sat
    case p049 => exact support001 sat
    case p050 => exact support001 sat
    all_goals trivial

private theorem group2 (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    match row with
    | .p051 | .p052 | .p053 | .p054 | .p055 | .p056 | .p057 | .p058 | .p059 | .p060 | .p061 | .p062 | .p063 | .p064 | .p065 | .p066 | .p067 | .p068 | .p069 | .p070 | .p071 | .p072 | .p073 | .p074 | .p075 | .p076 | .p077 | .p078 | .p079 | .p080 | .p081 | .p082 | .p083 | .p084 | .p085 | .p086 | .p087 | .p088 | .p089 | .p090 | .p091 | .p092 | .p093 | .p094 | .p095 | .p096 | .p097 | .p098 | .p099 | .p100 => Supported sat row
    | _ => True := by
    cases row
    case p051 => exact support001 sat
    case p052 => exact support001 sat
    case p053 => exact support001 sat
    case p054 => exact support016 sat
    case p055 => exact support001 sat
    case p056 => exact support001 sat
    case p057 => exact support001 sat
    case p058 => exact support001 sat
    case p059 => exact support001 sat
    case p060 => exact support001 sat
    case p061 => exact support001 sat
    case p062 => exact support001 sat
    case p063 => exact support001 sat
    case p064 => exact support016 sat
    case p065 => exact support001 sat
    case p066 => exact support001 sat
    case p067 => exact support001 sat
    case p068 => exact support001 sat
    case p069 => exact support001 sat
    case p070 => exact support001 sat
    case p071 => exact support001 sat
    case p072 => exact support001 sat
    case p073 => exact support001 sat
    case p074 => exact support016 sat
    case p075 => exact support001 sat
    case p076 => exact support076 sat
    case p077 => exact support001 sat
    case p078 => exact support001 sat
    case p079 => exact support001 sat
    case p080 => exact support001 sat
    case p081 => exact support001 sat
    case p082 => exact support001 sat
    case p083 => exact support001 sat
    case p084 => exact support001 sat
    case p085 => exact support001 sat
    case p086 => exact support001 sat
    case p087 => exact support001 sat
    case p088 => exact support001 sat
    case p089 => exact support001 sat
    case p090 => exact support001 sat
    case p091 => exact support001 sat
    case p092 => exact support001 sat
    case p093 => exact support001 sat
    case p094 => exact support001 sat
    case p095 => exact support001 sat
    case p096 => exact support001 sat
    case p097 => exact support001 sat
    case p098 => exact support001 sat
    case p099 => exact support001 sat
    case p100 => exact support001 sat
    all_goals trivial

private theorem group3 (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    match row with
    | .p101 | .p102 | .p103 | .p104 | .p105 | .p106 | .p107 | .p108 | .p109 | .p110 | .p111 | .p112 | .p113 | .p114 | .p115 | .p116 | .p117 | .p118 | .p119 | .p120 | .p121 | .p122 | .p123 | .p124 | .p125 | .p126 | .p127 | .p128 | .p129 | .p130 | .p131 | .p132 | .p133 | .p134 | .p135 | .p136 | .p137 | .p138 | .p139 | .p140 | .p141 | .p142 | .p143 | .p144 | .p145 | .p146 | .p147 | .p148 | .p149 | .p150 => Supported sat row
    | _ => True := by
    cases row
    case p101 => exact support001 sat
    case p102 => exact support001 sat
    case p103 => exact support001 sat
    case p104 => exact support001 sat
    case p105 => exact support001 sat
    case p106 => exact support001 sat
    case p107 => exact support001 sat
    case p108 => exact support001 sat
    case p109 => exact support001 sat
    case p110 => exact support001 sat
    case p111 => exact support001 sat
    case p112 => exact support001 sat
    case p113 => exact support016 sat
    case p114 => exact support001 sat
    case p115 => exact support115 sat
    case p116 => exact support001 sat
    case p117 => exact support001 sat
    case p118 => exact support016 sat
    case p119 => exact support016 sat
    case p120 => exact support001 sat
    case p121 => exact support121 sat
    case p122 => exact support115 sat
    case p123 => exact support115 sat
    case p124 => exact support115 sat
    case p125 => exact support016 sat
    case p126 => exact support126 sat
    case p127 => exact support126 sat
    case p128 => exact support128 sat
    case p129 => exact support016 sat
    case p130 => exact support130 sat
    case p131 => exact support130 sat
    case p132 => exact support126 sat
    case p133 => exact support016 sat
    case p134 => exact support016 sat
    case p135 => exact support016 sat
    case p136 => exact support115 sat
    case p137 => exact support016 sat
    case p138 => exact support016 sat
    case p139 => exact support016 sat
    case p140 => exact support016 sat
    case p141 => exact support016 sat
    case p142 => exact support016 sat
    case p143 => exact support016 sat
    case p144 => exact support016 sat
    case p145 => exact support016 sat
    case p146 => exact support016 sat
    case p147 => exact support016 sat
    case p148 => exact support016 sat
    case p149 => exact support115 sat
    case p150 => exact support016 sat
    all_goals trivial

private theorem group4 (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    match row with
    | .p151 | .p152 | .p153 | .p154 | .p155 | .p156 | .p157 | .p158 | .p159 | .p160 | .p161 | .p162 | .p163 | .p164 | .p165 | .p166 | .p167 | .p168 | .p169 | .p170 | .p171 | .p172 | .p173 | .p174 | .p175 | .p176 | .p177 | .p178 | .p179 | .p180 | .p181 | .p182 | .p183 | .p184 | .p185 | .p186 | .p187 | .p188 | .p189 | .p190 | .p191 | .p192 | .p193 | .p194 | .p195 | .p196 | .p197 | .p198 | .p199 | .p200 => Supported sat row
    | _ => True := by
    cases row
    case p151 => exact support115 sat
    case p152 => exact support152 sat
    case p153 => exact support016 sat
    case p154 => exact support016 sat
    case p155 => exact support115 sat
    case p156 => exact support156 sat
    case p157 => exact support157 sat
    case p158 => exact support157 sat
    case p159 => exact support159 sat
    case p160 => exact support160 sat
    case p161 => exact support159 sat
    case p162 => exact support157 sat
    case p163 => exact support157 sat
    case p164 => exact support016 sat
    case p165 => exact support016 sat
    case p166 => exact support016 sat
    case p167 => exact support016 sat
    case p168 => exact support115 sat
    case p169 => exact support016 sat
    case p170 => exact support016 sat
    case p171 => exact support016 sat
    case p172 => exact support115 sat
    case p173 => exact support016 sat
    case p174 => exact support016 sat
    case p175 => exact support016 sat
    case p176 => exact support115 sat
    case p177 => exact support016 sat
    case p178 => exact support016 sat
    case p179 => exact support115 sat
    case p180 => exact support016 sat
    case p181 => exact support016 sat
    case p182 => exact support016 sat
    case p183 => exact support016 sat
    case p184 => exact support115 sat
    case p185 => exact support185 sat
    case p186 => exact support016 sat
    case p187 => exact support187 sat
    case p188 => exact support016 sat
    case p189 => exact support016 sat
    case p190 => exact support001 sat
    case p191 => exact support001 sat
    case p192 => exact support016 sat
    case p193 => exact support001 sat
    case p194 => exact support001 sat
    case p195 => exact support001 sat
    case p196 => exact support001 sat
    case p197 => exact support001 sat
    case p198 => exact support115 sat
    case p199 => exact support001 sat
    case p200 => exact support001 sat
    all_goals trivial

private theorem group5 (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    match row with
    | .p201 | .p202 | .p203 | .p204 | .p205 | .p206 | .p207 | .p208 | .p209 | .p210 | .p211 | .p212 | .p213 | .p214 | .p215 | .p216 | .p217 | .p218 | .p219 | .p220 | .p221 | .p222 | .p223 | .p224 | .p225 | .p226 | .p227 | .p228 | .p229 | .p230 | .p231 | .p232 | .p233 | .p234 | .p235 | .p236 | .p237 | .p238 | .p239 | .p240 | .p241 | .p242 | .p243 | .p244 | .p245 | .p246 | .p247 | .p248 | .p249 | .p250 => Supported sat row
    | _ => True := by
    cases row
    case p201 => exact support001 sat
    case p202 => exact support016 sat
    case p203 => exact support016 sat
    case p204 => exact support016 sat
    case p205 => exact support001 sat
    case p206 => exact support001 sat
    case p207 => exact support016 sat
    case p208 => exact support001 sat
    case p209 => exact support001 sat
    case p210 => exact support001 sat
    case p211 => exact support115 sat
    case p212 => exact support001 sat
    case p213 => exact support001 sat
    case p214 => exact support115 sat
    case p215 => exact support001 sat
    case p216 => exact support001 sat
    case p217 => exact support001 sat
    case p218 => exact support016 sat
    case p219 => exact support016 sat
    case p220 => exact support016 sat
    case p221 => exact support016 sat
    case p222 => exact support001 sat
    case p223 => exact support001 sat
    case p224 => exact support016 sat
    case p225 => exact support001 sat
    case p226 => exact support001 sat
    case p227 => exact support001 sat
    case p228 => exact support115 sat
    case p229 => exact support001 sat
    case p230 => exact support001 sat
    case p231 => exact support115 sat
    case p232 => exact support001 sat
    case p233 => exact support001 sat
    case p234 => exact support001 sat
    case p235 => exact support016 sat
    case p236 => exact support016 sat
    case p237 => exact support016 sat
    case p238 => exact support016 sat
    case p239 => exact support001 sat
    case p240 => exact support001 sat
    case p241 => exact support016 sat
    case p242 => exact support001 sat
    case p243 => exact support001 sat
    case p244 => exact support001 sat
    case p245 => exact support115 sat
    case p246 => exact support001 sat
    case p247 => exact support001 sat
    case p248 => exact support115 sat
    case p249 => exact support001 sat
    case p250 => exact support001 sat
    all_goals trivial

private theorem group6 (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    match row with
    | .p251 | .p252 | .p253 | .p254 | .p255 | .p256 | .p257 | .p258 | .p259 | .p260 | .p261 | .p262 | .p263 | .p264 | .p265 | .p266 | .p267 | .p268 | .p269 | .p270 | .p271 | .p272 | .p273 | .p274 | .p275 | .p276 | .p277 | .p278 | .p279 | .p280 | .p281 | .p282 | .p283 | .p284 | .p285 | .p286 | .p287 | .p288 | .p289 | .p290 | .p291 | .p292 | .p293 | .p294 | .p295 | .p296 | .p297 | .p298 | .p299 | .p300 => Supported sat row
    | _ => True := by
    cases row
    case p251 => exact support001 sat
    case p252 => exact support016 sat
    case p253 => exact support016 sat
    case p254 => exact support016 sat
    case p255 => exact support001 sat
    case p256 => exact support001 sat
    case p257 => exact support001 sat
    case p258 => exact support001 sat
    case p259 => exact support128 sat
    case p260 => exact support115 sat
    case p261 => exact support016 sat
    case p262 => exact support016 sat
    case p263 => exact support001 sat
    case p264 => exact support001 sat
    case p265 => exact support016 sat
    case p266 => exact support016 sat
    case p267 => exact support115 sat
    case p268 => exact support001 sat
    case p269 => exact support269 sat
    case p270 => exact support270 sat
    case p271 => exact support271 sat
    case p272 => exact support076 sat
    case p273 => exact support273 sat
    case p274 => exact support076 sat
    case p275 => exact support275 sat
    case p276 => exact support273 sat
    case p277 => exact support277 sat
    case p278 => exact support273 sat
    case p279 => exact support279 sat
    case p280 => exact support280 sat
    case p281 => exact support281 sat
    case p282 => exact support016 sat
    case p283 => exact support016 sat
    case p284 => exact support001 sat
    case p285 => exact support001 sat
    case p286 => exact support001 sat
    case p287 => exact support121 sat
    case p288 => exact support016 sat
    case p289 => exact support001 sat
    case p290 => exact support001 sat
    case p291 => exact support016 sat
    case p292 => exact support016 sat
    case p293 => exact support001 sat
    case p294 => exact support128 sat
    case p295 => exact support016 sat
    case p296 => exact support126 sat
    case p297 => exact support128 sat
    case p298 => exact support016 sat
    case p299 => exact support126 sat
    case p300 => exact support016 sat
    all_goals trivial

private theorem group7 (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    match row with
    | .p301 | .p302 | .p303 | .p304 | .p305 | .p306 | .p307 | .p308 | .p309 | .p310 | .p311 | .p312 | .p313 | .p314 | .p315 | .p316 | .p317 | .p318 | .p319 | .p320 | .p321 | .p322 | .p323 | .p324 | .p325 | .p326 | .p327 | .p328 | .p329 | .p330 | .p331 | .p332 | .p333 | .p334 | .p335 | .p336 | .p337 | .p338 | .p339 | .p340 | .p341 | .p342 | .p343 | .p344 | .p345 | .p346 | .p347 | .p348 | .p349 | .p350 => Supported sat row
    | _ => True := by
    cases row
    case p301 => exact support001 sat
    case p302 => exact support016 sat
    case p303 => exact support016 sat
    case p304 => exact support001 sat
    case p305 => exact support001 sat
    case p306 => exact support001 sat
    case p307 => exact support001 sat
    case p308 => exact support001 sat
    case p309 => exact support016 sat
    case p310 => exact support115 sat
    case p311 => exact support016 sat
    case p312 => exact support001 sat
    case p313 => exact support016 sat
    case p314 => exact support001 sat
    case p315 => exact support152 sat
    case p316 => exact support001 sat
    case p317 => exact support001 sat
    case p318 => exact support016 sat
    case p319 => exact support016 sat
    case p320 => exact support016 sat
    case p321 => exact support016 sat
    case p322 => exact support016 sat
    case p323 => exact support001 sat
    case p324 => exact support001 sat
    case p325 => exact support016 sat
    case p326 => exact support001 sat
    case p327 => exact support001 sat
    case p328 => exact support001 sat
    case p329 => exact support115 sat
    case p330 => exact support001 sat
    case p331 => exact support001 sat
    case p332 => exact support115 sat
    case p333 => exact support001 sat
    case p334 => exact support001 sat
    case p335 => exact support016 sat
    case p336 => exact support016 sat
    case p337 => exact support016 sat
    case p338 => exact support016 sat
    case p339 => exact support001 sat
    case p340 => exact support001 sat
    case p341 => exact support016 sat
    case p342 => exact support001 sat
    case p343 => exact support001 sat
    case p344 => exact support001 sat
    case p345 => exact support115 sat
    case p346 => exact support001 sat
    case p347 => exact support001 sat
    case p348 => exact support115 sat
    case p349 => exact support001 sat
    case p350 => exact support001 sat
    all_goals trivial

private theorem group8 (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    match row with
    | .p351 | .p352 | .p353 | .p354 | .p355 | .p356 | .p357 | .p358 | .p359 | .p360 | .p361 | .p362 | .p363 | .p364 | .p365 | .p366 | .p367 | .p368 | .p369 | .p370 | .p371 | .p372 | .p373 | .p374 | .p375 | .p376 | .p377 | .p378 | .p379 | .p380 | .p381 | .p382 | .p383 | .p384 | .p385 | .p386 | .p387 | .p388 | .p389 | .p390 | .p391 | .p392 => Supported sat row
    | _ => True := by
    cases row
    case p351 => exact support016 sat
    case p352 => exact support016 sat
    case p353 => exact support016 sat
    case p354 => exact support016 sat
    case p355 => exact support001 sat
    case p356 => exact support001 sat
    case p357 => exact support016 sat
    case p358 => exact support001 sat
    case p359 => exact support001 sat
    case p360 => exact support001 sat
    case p361 => exact support115 sat
    case p362 => exact support115 sat
    case p363 => exact support001 sat
    case p364 => exact support001 sat
    case p365 => exact support115 sat
    case p366 => exact support001 sat
    case p367 => exact support001 sat
    case p368 => exact support016 sat
    case p369 => exact support016 sat
    case p370 => exact support115 sat
    case p371 => exact support016 sat
    case p372 => exact support372 sat
    case p373 => exact support373 sat
    case p374 => exact support016 sat
    case p375 => exact support279 sat
    case p376 => exact support376 sat
    case p377 => exact support001 sat
    case p378 => exact support001 sat
    case p379 => exact support001 sat
    case p380 => exact support152 sat
    case p381 => exact support016 sat
    case p382 => exact support016 sat
    case p383 => exact support016 sat
    case p384 => exact support016 sat
    case p385 => exact support016 sat
    case p386 => exact support016 sat
    case p387 => exact support016 sat
    case p388 => exact support016 sat
    case p389 => exact support016 sat
    case p390 => exact support016 sat
    case p391 => exact support016 sat
    case p392 => exact support392 sat
    all_goals trivial

/-- 制約の判定を変えても、全ての標準署名は同じ有限一覧で支持される。 -/
theorem primitive (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    let s := row.signatureWith sat
    SignatureSupport atoms s.params s.ret s.eff s.tel := by
  cases row
  case p001 => exact group1 sat .p001
  case p002 => exact group1 sat .p002
  case p003 => exact group1 sat .p003
  case p004 => exact group1 sat .p004
  case p005 => exact group1 sat .p005
  case p006 => exact group1 sat .p006
  case p007 => exact group1 sat .p007
  case p008 => exact group1 sat .p008
  case p009 => exact group1 sat .p009
  case p010 => exact group1 sat .p010
  case p011 => exact group1 sat .p011
  case p012 => exact group1 sat .p012
  case p013 => exact group1 sat .p013
  case p014 => exact group1 sat .p014
  case p015 => exact group1 sat .p015
  case p016 => exact group1 sat .p016
  case p017 => exact group1 sat .p017
  case p018 => exact group1 sat .p018
  case p019 => exact group1 sat .p019
  case p020 => exact group1 sat .p020
  case p021 => exact group1 sat .p021
  case p022 => exact group1 sat .p022
  case p023 => exact group1 sat .p023
  case p024 => exact group1 sat .p024
  case p025 => exact group1 sat .p025
  case p026 => exact group1 sat .p026
  case p027 => exact group1 sat .p027
  case p028 => exact group1 sat .p028
  case p029 => exact group1 sat .p029
  case p030 => exact group1 sat .p030
  case p031 => exact group1 sat .p031
  case p032 => exact group1 sat .p032
  case p033 => exact group1 sat .p033
  case p034 => exact group1 sat .p034
  case p035 => exact group1 sat .p035
  case p036 => exact group1 sat .p036
  case p037 => exact group1 sat .p037
  case p038 => exact group1 sat .p038
  case p039 => exact group1 sat .p039
  case p040 => exact group1 sat .p040
  case p041 => exact group1 sat .p041
  case p042 => exact group1 sat .p042
  case p043 => exact group1 sat .p043
  case p044 => exact group1 sat .p044
  case p045 => exact group1 sat .p045
  case p046 => exact group1 sat .p046
  case p047 => exact group1 sat .p047
  case p048 => exact group1 sat .p048
  case p049 => exact group1 sat .p049
  case p050 => exact group1 sat .p050
  case p051 => exact group2 sat .p051
  case p052 => exact group2 sat .p052
  case p053 => exact group2 sat .p053
  case p054 => exact group2 sat .p054
  case p055 => exact group2 sat .p055
  case p056 => exact group2 sat .p056
  case p057 => exact group2 sat .p057
  case p058 => exact group2 sat .p058
  case p059 => exact group2 sat .p059
  case p060 => exact group2 sat .p060
  case p061 => exact group2 sat .p061
  case p062 => exact group2 sat .p062
  case p063 => exact group2 sat .p063
  case p064 => exact group2 sat .p064
  case p065 => exact group2 sat .p065
  case p066 => exact group2 sat .p066
  case p067 => exact group2 sat .p067
  case p068 => exact group2 sat .p068
  case p069 => exact group2 sat .p069
  case p070 => exact group2 sat .p070
  case p071 => exact group2 sat .p071
  case p072 => exact group2 sat .p072
  case p073 => exact group2 sat .p073
  case p074 => exact group2 sat .p074
  case p075 => exact group2 sat .p075
  case p076 => exact group2 sat .p076
  case p077 => exact group2 sat .p077
  case p078 => exact group2 sat .p078
  case p079 => exact group2 sat .p079
  case p080 => exact group2 sat .p080
  case p081 => exact group2 sat .p081
  case p082 => exact group2 sat .p082
  case p083 => exact group2 sat .p083
  case p084 => exact group2 sat .p084
  case p085 => exact group2 sat .p085
  case p086 => exact group2 sat .p086
  case p087 => exact group2 sat .p087
  case p088 => exact group2 sat .p088
  case p089 => exact group2 sat .p089
  case p090 => exact group2 sat .p090
  case p091 => exact group2 sat .p091
  case p092 => exact group2 sat .p092
  case p093 => exact group2 sat .p093
  case p094 => exact group2 sat .p094
  case p095 => exact group2 sat .p095
  case p096 => exact group2 sat .p096
  case p097 => exact group2 sat .p097
  case p098 => exact group2 sat .p098
  case p099 => exact group2 sat .p099
  case p100 => exact group2 sat .p100
  case p101 => exact group3 sat .p101
  case p102 => exact group3 sat .p102
  case p103 => exact group3 sat .p103
  case p104 => exact group3 sat .p104
  case p105 => exact group3 sat .p105
  case p106 => exact group3 sat .p106
  case p107 => exact group3 sat .p107
  case p108 => exact group3 sat .p108
  case p109 => exact group3 sat .p109
  case p110 => exact group3 sat .p110
  case p111 => exact group3 sat .p111
  case p112 => exact group3 sat .p112
  case p113 => exact group3 sat .p113
  case p114 => exact group3 sat .p114
  case p115 => exact group3 sat .p115
  case p116 => exact group3 sat .p116
  case p117 => exact group3 sat .p117
  case p118 => exact group3 sat .p118
  case p119 => exact group3 sat .p119
  case p120 => exact group3 sat .p120
  case p121 => exact group3 sat .p121
  case p122 => exact group3 sat .p122
  case p123 => exact group3 sat .p123
  case p124 => exact group3 sat .p124
  case p125 => exact group3 sat .p125
  case p126 => exact group3 sat .p126
  case p127 => exact group3 sat .p127
  case p128 => exact group3 sat .p128
  case p129 => exact group3 sat .p129
  case p130 => exact group3 sat .p130
  case p131 => exact group3 sat .p131
  case p132 => exact group3 sat .p132
  case p133 => exact group3 sat .p133
  case p134 => exact group3 sat .p134
  case p135 => exact group3 sat .p135
  case p136 => exact group3 sat .p136
  case p137 => exact group3 sat .p137
  case p138 => exact group3 sat .p138
  case p139 => exact group3 sat .p139
  case p140 => exact group3 sat .p140
  case p141 => exact group3 sat .p141
  case p142 => exact group3 sat .p142
  case p143 => exact group3 sat .p143
  case p144 => exact group3 sat .p144
  case p145 => exact group3 sat .p145
  case p146 => exact group3 sat .p146
  case p147 => exact group3 sat .p147
  case p148 => exact group3 sat .p148
  case p149 => exact group3 sat .p149
  case p150 => exact group3 sat .p150
  case p151 => exact group4 sat .p151
  case p152 => exact group4 sat .p152
  case p153 => exact group4 sat .p153
  case p154 => exact group4 sat .p154
  case p155 => exact group4 sat .p155
  case p156 => exact group4 sat .p156
  case p157 => exact group4 sat .p157
  case p158 => exact group4 sat .p158
  case p159 => exact group4 sat .p159
  case p160 => exact group4 sat .p160
  case p161 => exact group4 sat .p161
  case p162 => exact group4 sat .p162
  case p163 => exact group4 sat .p163
  case p164 => exact group4 sat .p164
  case p165 => exact group4 sat .p165
  case p166 => exact group4 sat .p166
  case p167 => exact group4 sat .p167
  case p168 => exact group4 sat .p168
  case p169 => exact group4 sat .p169
  case p170 => exact group4 sat .p170
  case p171 => exact group4 sat .p171
  case p172 => exact group4 sat .p172
  case p173 => exact group4 sat .p173
  case p174 => exact group4 sat .p174
  case p175 => exact group4 sat .p175
  case p176 => exact group4 sat .p176
  case p177 => exact group4 sat .p177
  case p178 => exact group4 sat .p178
  case p179 => exact group4 sat .p179
  case p180 => exact group4 sat .p180
  case p181 => exact group4 sat .p181
  case p182 => exact group4 sat .p182
  case p183 => exact group4 sat .p183
  case p184 => exact group4 sat .p184
  case p185 => exact group4 sat .p185
  case p186 => exact group4 sat .p186
  case p187 => exact group4 sat .p187
  case p188 => exact group4 sat .p188
  case p189 => exact group4 sat .p189
  case p190 => exact group4 sat .p190
  case p191 => exact group4 sat .p191
  case p192 => exact group4 sat .p192
  case p193 => exact group4 sat .p193
  case p194 => exact group4 sat .p194
  case p195 => exact group4 sat .p195
  case p196 => exact group4 sat .p196
  case p197 => exact group4 sat .p197
  case p198 => exact group4 sat .p198
  case p199 => exact group4 sat .p199
  case p200 => exact group4 sat .p200
  case p201 => exact group5 sat .p201
  case p202 => exact group5 sat .p202
  case p203 => exact group5 sat .p203
  case p204 => exact group5 sat .p204
  case p205 => exact group5 sat .p205
  case p206 => exact group5 sat .p206
  case p207 => exact group5 sat .p207
  case p208 => exact group5 sat .p208
  case p209 => exact group5 sat .p209
  case p210 => exact group5 sat .p210
  case p211 => exact group5 sat .p211
  case p212 => exact group5 sat .p212
  case p213 => exact group5 sat .p213
  case p214 => exact group5 sat .p214
  case p215 => exact group5 sat .p215
  case p216 => exact group5 sat .p216
  case p217 => exact group5 sat .p217
  case p218 => exact group5 sat .p218
  case p219 => exact group5 sat .p219
  case p220 => exact group5 sat .p220
  case p221 => exact group5 sat .p221
  case p222 => exact group5 sat .p222
  case p223 => exact group5 sat .p223
  case p224 => exact group5 sat .p224
  case p225 => exact group5 sat .p225
  case p226 => exact group5 sat .p226
  case p227 => exact group5 sat .p227
  case p228 => exact group5 sat .p228
  case p229 => exact group5 sat .p229
  case p230 => exact group5 sat .p230
  case p231 => exact group5 sat .p231
  case p232 => exact group5 sat .p232
  case p233 => exact group5 sat .p233
  case p234 => exact group5 sat .p234
  case p235 => exact group5 sat .p235
  case p236 => exact group5 sat .p236
  case p237 => exact group5 sat .p237
  case p238 => exact group5 sat .p238
  case p239 => exact group5 sat .p239
  case p240 => exact group5 sat .p240
  case p241 => exact group5 sat .p241
  case p242 => exact group5 sat .p242
  case p243 => exact group5 sat .p243
  case p244 => exact group5 sat .p244
  case p245 => exact group5 sat .p245
  case p246 => exact group5 sat .p246
  case p247 => exact group5 sat .p247
  case p248 => exact group5 sat .p248
  case p249 => exact group5 sat .p249
  case p250 => exact group5 sat .p250
  case p251 => exact group6 sat .p251
  case p252 => exact group6 sat .p252
  case p253 => exact group6 sat .p253
  case p254 => exact group6 sat .p254
  case p255 => exact group6 sat .p255
  case p256 => exact group6 sat .p256
  case p257 => exact group6 sat .p257
  case p258 => exact group6 sat .p258
  case p259 => exact group6 sat .p259
  case p260 => exact group6 sat .p260
  case p261 => exact group6 sat .p261
  case p262 => exact group6 sat .p262
  case p263 => exact group6 sat .p263
  case p264 => exact group6 sat .p264
  case p265 => exact group6 sat .p265
  case p266 => exact group6 sat .p266
  case p267 => exact group6 sat .p267
  case p268 => exact group6 sat .p268
  case p269 => exact group6 sat .p269
  case p270 => exact group6 sat .p270
  case p271 => exact group6 sat .p271
  case p272 => exact group6 sat .p272
  case p273 => exact group6 sat .p273
  case p274 => exact group6 sat .p274
  case p275 => exact group6 sat .p275
  case p276 => exact group6 sat .p276
  case p277 => exact group6 sat .p277
  case p278 => exact group6 sat .p278
  case p279 => exact group6 sat .p279
  case p280 => exact group6 sat .p280
  case p281 => exact group6 sat .p281
  case p282 => exact group6 sat .p282
  case p283 => exact group6 sat .p283
  case p284 => exact group6 sat .p284
  case p285 => exact group6 sat .p285
  case p286 => exact group6 sat .p286
  case p287 => exact group6 sat .p287
  case p288 => exact group6 sat .p288
  case p289 => exact group6 sat .p289
  case p290 => exact group6 sat .p290
  case p291 => exact group6 sat .p291
  case p292 => exact group6 sat .p292
  case p293 => exact group6 sat .p293
  case p294 => exact group6 sat .p294
  case p295 => exact group6 sat .p295
  case p296 => exact group6 sat .p296
  case p297 => exact group6 sat .p297
  case p298 => exact group6 sat .p298
  case p299 => exact group6 sat .p299
  case p300 => exact group6 sat .p300
  case p301 => exact group7 sat .p301
  case p302 => exact group7 sat .p302
  case p303 => exact group7 sat .p303
  case p304 => exact group7 sat .p304
  case p305 => exact group7 sat .p305
  case p306 => exact group7 sat .p306
  case p307 => exact group7 sat .p307
  case p308 => exact group7 sat .p308
  case p309 => exact group7 sat .p309
  case p310 => exact group7 sat .p310
  case p311 => exact group7 sat .p311
  case p312 => exact group7 sat .p312
  case p313 => exact group7 sat .p313
  case p314 => exact group7 sat .p314
  case p315 => exact group7 sat .p315
  case p316 => exact group7 sat .p316
  case p317 => exact group7 sat .p317
  case p318 => exact group7 sat .p318
  case p319 => exact group7 sat .p319
  case p320 => exact group7 sat .p320
  case p321 => exact group7 sat .p321
  case p322 => exact group7 sat .p322
  case p323 => exact group7 sat .p323
  case p324 => exact group7 sat .p324
  case p325 => exact group7 sat .p325
  case p326 => exact group7 sat .p326
  case p327 => exact group7 sat .p327
  case p328 => exact group7 sat .p328
  case p329 => exact group7 sat .p329
  case p330 => exact group7 sat .p330
  case p331 => exact group7 sat .p331
  case p332 => exact group7 sat .p332
  case p333 => exact group7 sat .p333
  case p334 => exact group7 sat .p334
  case p335 => exact group7 sat .p335
  case p336 => exact group7 sat .p336
  case p337 => exact group7 sat .p337
  case p338 => exact group7 sat .p338
  case p339 => exact group7 sat .p339
  case p340 => exact group7 sat .p340
  case p341 => exact group7 sat .p341
  case p342 => exact group7 sat .p342
  case p343 => exact group7 sat .p343
  case p344 => exact group7 sat .p344
  case p345 => exact group7 sat .p345
  case p346 => exact group7 sat .p346
  case p347 => exact group7 sat .p347
  case p348 => exact group7 sat .p348
  case p349 => exact group7 sat .p349
  case p350 => exact group7 sat .p350
  case p351 => exact group8 sat .p351
  case p352 => exact group8 sat .p352
  case p353 => exact group8 sat .p353
  case p354 => exact group8 sat .p354
  case p355 => exact group8 sat .p355
  case p356 => exact group8 sat .p356
  case p357 => exact group8 sat .p357
  case p358 => exact group8 sat .p358
  case p359 => exact group8 sat .p359
  case p360 => exact group8 sat .p360
  case p361 => exact group8 sat .p361
  case p362 => exact group8 sat .p362
  case p363 => exact group8 sat .p363
  case p364 => exact group8 sat .p364
  case p365 => exact group8 sat .p365
  case p366 => exact group8 sat .p366
  case p367 => exact group8 sat .p367
  case p368 => exact group8 sat .p368
  case p369 => exact group8 sat .p369
  case p370 => exact group8 sat .p370
  case p371 => exact group8 sat .p371
  case p372 => exact group8 sat .p372
  case p373 => exact group8 sat .p373
  case p374 => exact group8 sat .p374
  case p375 => exact group8 sat .p375
  case p376 => exact group8 sat .p376
  case p377 => exact group8 sat .p377
  case p378 => exact group8 sat .p378
  case p379 => exact group8 sat .p379
  case p380 => exact group8 sat .p380
  case p381 => exact group8 sat .p381
  case p382 => exact group8 sat .p382
  case p383 => exact group8 sat .p383
  case p384 => exact group8 sat .p384
  case p385 => exact group8 sat .p385
  case p386 => exact group8 sat .p386
  case p387 => exact group8 sat .p387
  case p388 => exact group8 sat .p388
  case p389 => exact group8 sat .p389
  case p390 => exact group8 sat .p390
  case p391 => exact group8 sat .p391
  case p392 => exact group8 sat .p392

/-- 仮定側に署名を持たない完成表の全署名は、標準署名の有限原子一覧で支持される。 -/
theorem complete {P : Refinement.Program} (L : NameLists) (T : DataTable P) {b s}
    (h : (StandardModel.complete L T ApplicationExamples.noAssumptions).sig b = some s) :
    SignatureSupport atoms s.params s.ret s.eff s.tel := by
  change (if b ∈ L.composed then T.base.sig b else
    if b ∈ L.assumed then none else none) = some s at h
  split at h
  · change ((StandardModel.primitive b).map (Primitive.signatureWith T.sat)) = some s at h
    obtain ⟨row, _, rfl⟩ := Option.map_eq_some_iff.mp h
    exact primitive T.sat row
  · split at h <;> cases h

end
end Benitoite.Release.Refinement.Surface.StandardSupport
