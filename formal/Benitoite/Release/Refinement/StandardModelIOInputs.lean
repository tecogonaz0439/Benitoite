import Benitoite.Release.Refinement.StandardModelCollectionInputs
import Benitoite.Release.Refinement.StandardModelPredicateInputs
import Benitoite.Release.Refinement.StandardModelCheckInputs

/-! # 合成表の範囲付きの純粋な行とIO・終了の行の契約の前提を満たす入力

範囲付きの行は全体を許す範囲（`.absolute .top`）と、その範囲の下で保持したパス・要求の値で、範囲を持たない
print・exit・File.readTextは基本型の定数で、合成表のlookupと `BuiltinArgs` を満たす。保持した要求は
ループバックの端点への要求であり、要求の内容型と端点の一致を読む。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
set_option linter.unusedSimpArgs false


/-- 合成表の名前 `b` のIO・終了の応答の契約の前提（lookupとBuiltinArgs）を満たす入力がある。 -/
def IORow.Satisfiable (P : Program) (b : PrimName) : Prop :=
  ∃ Ψ sg ts es rs ws a e, (builtins P).sig b = some sg ∧
    BuiltinArgs P (builtins P) Ψ b sg ts es rs ws a e

/-- 範囲の引数を持ち、具体化が `Ty.toTel` の形になる行の署名は、型付きの値の列から全欄を満たす。 -/
theorem arguments_of_ranges {P : Program} (row : Primitive) {sg rs ws names inputs ret e}
    (hsig : row.signature = sg)
    (admissible : PrimitiveAdmissible [] 0 sg Qempty [] [])
    (ranges : (builtins P).RangeAdmissible row.name sg rs)
    (source : (Ty.dependentFn (Tel.instR rs sg.tel)).WF 0 (sg.tparams.map TParamDecl.kind).length 0)
    (kinds : TypeArgsKinded P [] [] (sg.tparams.map TParamDecl.kind))
    (inst : instantiatedTel (Tel.instR rs sg.tel) [] [] = Ty.toTel names inputs ret e)
    (annotation : Ty.Annotation P [] [] (.fn names inputs ret e))
    (inputsNormal : Ty.normTys inputs = inputs) (retNormal : ret.norm = ret) (retWF : ret.WF 0 0 0)
    (effectNormal : Eff.norm e = e) (effectWF : Eff.WF 0 0 0 e)
    (values : HasTypeVsQ P (builtins P) StoreTy.empty Qempty [] [] [] ws inputs)
    (ground : ∀ w ∈ ws, w.Ground) :
    ∃ Ψ sg ts es rs ws a e, (builtins P).sig row.name = some sg ∧
      BuiltinArgs P (builtins P) Ψ row.name sg ts es rs ws a e :=
  ⟨StoreTy.empty, sg, [], [], rs, ws, ret, e, hsig ▸ row_lookup P row,
    arguments_of_toTel admissible ranges source kinds (by intro t ht; cases ht) inst annotation inputsNormal
      retNormal retWF effectNormal effectWF values ground (by intro t ht; cases ht)⟩

private theorem false_range (ρ : Nat → RangeIx) : mapRangeAtoms ρ (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]

/-- 全体を許す範囲は、範囲の種類が一つの署名の範囲の入力を満たす。 -/
theorem top_range {B : Builtins} {b : PrimName} {sg : PrimSig} {k : Scope.Domain.Kind} (hk : sg.rkinds = [k]) :
    B.RangeAdmissible b sg [.absolute .top] := by
  refine ⟨by simp [hk], ?_, ?_, Or.inl (by simp)⟩
  · intro i r k' hr hk'
    rw [hk] at hk'
    cases i <;> simp at hr hk'
    subst hr; subst hk'
    cases k <;> decide
  · intro r hr; simp at hr; subst hr; exact ⟨by decide, by decide⟩

/-- 全体を許す二つの範囲は、範囲の種類が二つの署名の範囲の入力を満たす。 -/
theorem top_ranges {B : Builtins} {b : PrimName} {sg : PrimSig} {k : Scope.Domain.Kind} (hk : sg.rkinds = [k, k]) :
    B.RangeAdmissible b sg [.absolute .top, .absolute .top] := by
  refine ⟨by simp [hk], ?_, ?_, Or.inl (by simp)⟩
  · intro i r k' hr hk'
    rw [hk] at hk'
    rcases i with _ | _ | i <;> simp at hr hk'
    all_goals (subst hr; subst hk'; cases k <;> decide)
  · intro r hr; simp at hr; rcases hr with rfl | rfl <;> exact ⟨by decide, by decide⟩

/-- 全体を許す範囲の下の保持したパス。 -/
def heldPath : Val := .checked (.path ["data"])

theorem held_path_typed {P : Program} :
    HasTypeVQ P (builtins P) StoreTy.empty Qempty [] [] [] heldPath
      (.opaque "Scope.PathIn" (.fixed (.absolute .top))) :=
  HasTypeVQ.checked_opaque rfl rfl (by decide)

private theorem top_label (l : EffName) :
    mapRangeAtoms (rangeAt 0 []) (fun a => decide (a = .name l .top)) = (fun a => decide (a = .name l .top)) := by
  funext x; cases x <;> simp [mapRangeAtoms, mapAtomRanges, mapIx, rangeAt, eq_comm]

private theorem request_type : ScopeSignatures.clientRequestTy = .data "Http.ClientRequest" [] := rfl

local macro "scope_simp" " [" args:Lean.Parser.Tactic.simpLemma,* "]" : tactic => `(tactic|
  simp [ScopeSignatures.pureIn,ScopeSignatures.ioIn,ScopeSignatures.unscopedIO,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,
    Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,Eff.single,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,RangeIx.inst,RangeIx.WF,rangeAt,mapRangeAtoms,mapAtomRanges,mapIx,
    RowTransport,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row,
    Ty.WF,Tel.WF,Eff.WF,Ty.WFList,Eff.Canonical,Builtins.RangeAdmissible,Ty.Sorted,sortedTys,sortedEff,
    Ty.Declared,declaredTys,declaredEff,NamesWF,base_annotation,atErrorType,false_range,request_type,top_label,$args,*])

/-- Scope.pathInValueの行は、全体を許す範囲と保持したパスで全欄を満たす。 -/
theorem PureRow.Satisfiable.pathInValue {P : Program} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.pathInValue) : PureRow.Satisfiable P row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [heldPath])
    (names := ["path"]) (inputs := [.opaque "Scope.PathIn" (.fixed (.absolute .top))]) (ret := .base .string)
    (e := Eff.empty) (by constructor <;> scope_simp [ScopeSignatures.pathInValue]) (top_range rfl)
    (by scope_simp [ScopeSignatures.pathInValue]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.pathInValue]) ⟨by scope_simp [], by scope_simp [], by scope_simp []⟩ rfl rfl trivial rfl
    (by scope_simp []) (.cons held_path_typed .nil) (by intro w hw; simp at hw; subst hw; trivial)

/-- 範囲付きの効果の印の範囲変数を、具体化した範囲へ置き換える。 -/
private theorem label_range (l : EffName) (r : RangeExpr) :
    mapRangeAtoms (rangeAt 0 [r]) (fun a => decide (a = .name l (.rvar 0))) =
      (fun a => decide (a = .name l (.fixed r))) := by
  funext a
  simp [mapRangeAtoms, mapAtomRanges, mapIx, rangeAt, eq_comm]

/-- 範囲付きの効果。 -/
def rangedEffect (l : EffName) : Eff := .mk (fun a => decide (a = .name l (.fixed (.absolute .top)))) []

theorem ranged_effect_form (l : EffName) : Eff.norm (rangedEffect l) = rangedEffect l ∧ Eff.WF 0 0 0 (rangedEffect l) :=
  ⟨rfl, by simp [rangedEffect, Eff.WF, Ty.WFList]⟩

/-- Scope.widenPathInの行は、全体を許す二つの範囲と保持したパスで全欄を満たす。 -/
theorem PureRow.Satisfiable.widenPathIn {P : Program} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.widenPathIn) : PureRow.Satisfiable P row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top, .absolute .top]) (ws := [heldPath])
    (names := ["path"]) (inputs := [.opaque "Scope.PathIn" (.fixed (.absolute .top))])
    (ret := .opaque "Scope.PathIn" (.fixed (.absolute .top)))
    (e := Eff.empty) (by constructor <;> scope_simp [ScopeSignatures.widenPathIn]) (top_ranges rfl)
    (by scope_simp [ScopeSignatures.widenPathIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.widenPathIn]) ⟨by scope_simp [], by scope_simp [], by scope_simp []⟩ rfl rfl
    (by scope_simp []) rfl (by scope_simp []) (.cons held_path_typed .nil) (by intro w hw; simp at hw; subst hw; trivial)

/-- Scope.checkPathInの行は、全体を許す範囲と二つの空の文字列で全欄を満たす。 -/
theorem PureRow.Satisfiable.checkPathIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.checkPathIn) : PureRow.Satisfiable (program externals) row.name := by
  obtain ⟨result, _, scopeError, _, _⟩ := (arities externals).2.2
  exact arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [.const (sample .string), .const (sample .string)])
    (names := ["pattern","path"]) (inputs := [.base .string, .base .string])
    (ret := ScopeSignatures.resultTy (.opaque "Scope.PathIn" (.fixed (.absolute .top))) ScopeSignatures.scopeErrorTy)
    (e := Eff.empty) (by constructor <;> scope_simp [ScopeSignatures.checkPathIn]) (top_range rfl)
    (by scope_simp [ScopeSignatures.checkPathIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.checkPathIn])
    ⟨by scope_simp [], by scope_simp [], by scope_simp [result, scopeError]⟩ rfl rfl
    (by scope_simp []) rfl (by scope_simp []) (.cons (sample_typed _) (.cons (sample_typed _) .nil))
    (by intro w hw; simp at hw; rcases hw with rfl | rfl <;> trivial)

/-- File.readTextInの行（範囲付きの読み取り（文字列））は、全体を許す範囲と保持したパスで全欄を満たす。 -/
theorem IORow.Satisfiable.readTextIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.readTextIn) : IORow.Satisfiable (program externals) row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [heldPath])
    (names := ScopeSignatures.readTextIn.names) (inputs := [.opaque "Scope.PathIn" (.fixed (.absolute .top))])
    (ret := ScopeSignatures.resultTy (.base .string) (.opaque "IOError" (.fixed .top))) (e := rangedEffect "File.Read")
    (by constructor <;> scope_simp [ScopeSignatures.readTextIn]) (top_range rfl)
    (by scope_simp [ScopeSignatures.readTextIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.readTextIn, label_range, rangedEffect])
    ⟨by scope_simp [ScopeSignatures.readTextIn, rangedEffect], by scope_simp [rangedEffect],
      by scope_simp [(arities externals).2.2.1, rangedEffect]⟩ rfl rfl
    (by scope_simp []) (ranged_effect_form _).1 (ranged_effect_form _).2 (.cons held_path_typed .nil)
    (by intro w hw; simp at hw; subst hw; trivial)

/-- File.readBytesInの行（範囲付きの読み取り（バイト列））は、全体を許す範囲と保持したパスで全欄を満たす。 -/
theorem IORow.Satisfiable.readBytesIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.readBytesIn) : IORow.Satisfiable (program externals) row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [heldPath])
    (names := ScopeSignatures.readBytesIn.names) (inputs := [.opaque "Scope.PathIn" (.fixed (.absolute .top))])
    (ret := ScopeSignatures.resultTy (.bytes) (.opaque "IOError" (.fixed .top))) (e := rangedEffect "File.Read")
    (by constructor <;> scope_simp [ScopeSignatures.readBytesIn]) (top_range rfl)
    (by scope_simp [ScopeSignatures.readBytesIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.readBytesIn, label_range, rangedEffect])
    ⟨by scope_simp [ScopeSignatures.readBytesIn, rangedEffect], by scope_simp [rangedEffect],
      by scope_simp [(arities externals).2.2.1, rangedEffect]⟩ rfl rfl
    (by scope_simp []) (ranged_effect_form _).1 (ranged_effect_form _).2 (.cons held_path_typed .nil)
    (by intro w hw; simp at hw; subst hw; trivial)

/-- File.writeTextInの行（範囲付きの書き込み（文字列））は、全体を許す範囲と保持したパスで全欄を満たす。 -/
theorem IORow.Satisfiable.writeTextIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.writeTextIn) : IORow.Satisfiable (program externals) row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [heldPath, .const (sample .string)])
    (names := ScopeSignatures.writeTextIn.names) (inputs := [.opaque "Scope.PathIn" (.fixed (.absolute .top)), .base .string])
    (ret := ScopeSignatures.resultTy (.base .unit) (.opaque "IOError" (.fixed .top))) (e := rangedEffect "File.Write")
    (by constructor <;> scope_simp [ScopeSignatures.writeTextIn]) (top_range rfl)
    (by scope_simp [ScopeSignatures.writeTextIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.writeTextIn, label_range, rangedEffect])
    ⟨by scope_simp [ScopeSignatures.writeTextIn, rangedEffect], by scope_simp [rangedEffect],
      by scope_simp [(arities externals).2.2.1, rangedEffect]⟩ rfl rfl
    (by scope_simp []) (ranged_effect_form _).1 (ranged_effect_form _).2 (.cons held_path_typed (.cons (sample_typed _) .nil))
    (by intro w hw; simp at hw; rcases hw with rfl | rfl <;> trivial)

/-- File.writeBytesInの行（範囲付きの書き込み（バイト列））は、全体を許す範囲と保持したパスで全欄を満たす。 -/
theorem IORow.Satisfiable.writeBytesIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.writeBytesIn) : IORow.Satisfiable (program externals) row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [heldPath, .bytesV []])
    (names := ScopeSignatures.writeBytesIn.names) (inputs := [.opaque "Scope.PathIn" (.fixed (.absolute .top)), .bytes])
    (ret := ScopeSignatures.resultTy (.base .unit) (.opaque "IOError" (.fixed .top))) (e := rangedEffect "File.Write")
    (by constructor <;> scope_simp [ScopeSignatures.writeBytesIn]) (top_range rfl)
    (by scope_simp [ScopeSignatures.writeBytesIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.writeBytesIn, label_range, rangedEffect])
    ⟨by scope_simp [ScopeSignatures.writeBytesIn, rangedEffect], by scope_simp [rangedEffect],
      by scope_simp [(arities externals).2.2.1, rangedEffect]⟩ rfl rfl
    (by scope_simp []) (ranged_effect_form _).1 (ranged_effect_form _).2 (.cons held_path_typed (.cons (inhabitant_typed (a := .bytes) trivial) .nil))
    (by intro w hw; simp at hw; rcases hw with rfl | rfl <;> trivial)

/-- File.appendTextInの行（範囲付きの追記（文字列））は、全体を許す範囲と保持したパスで全欄を満たす。 -/
theorem IORow.Satisfiable.appendTextIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.appendTextIn) : IORow.Satisfiable (program externals) row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [heldPath, .const (sample .string)])
    (names := ScopeSignatures.appendTextIn.names) (inputs := [.opaque "Scope.PathIn" (.fixed (.absolute .top)), .base .string])
    (ret := ScopeSignatures.resultTy (.base .unit) (.opaque "IOError" (.fixed .top))) (e := rangedEffect "File.Write")
    (by constructor <;> scope_simp [ScopeSignatures.appendTextIn]) (top_range rfl)
    (by scope_simp [ScopeSignatures.appendTextIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.appendTextIn, label_range, rangedEffect])
    ⟨by scope_simp [ScopeSignatures.appendTextIn, rangedEffect], by scope_simp [rangedEffect],
      by scope_simp [(arities externals).2.2.1, rangedEffect]⟩ rfl rfl
    (by scope_simp []) (ranged_effect_form _).1 (ranged_effect_form _).2 (.cons held_path_typed (.cons (sample_typed _) .nil))
    (by intro w hw; simp at hw; rcases hw with rfl | rfl <;> trivial)

/-- File.appendBytesInの行（範囲付きの追記（バイト列））は、全体を許す範囲と保持したパスで全欄を満たす。 -/
theorem IORow.Satisfiable.appendBytesIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.appendBytesIn) : IORow.Satisfiable (program externals) row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [heldPath, .bytesV []])
    (names := ScopeSignatures.appendBytesIn.names) (inputs := [.opaque "Scope.PathIn" (.fixed (.absolute .top)), .bytes])
    (ret := ScopeSignatures.resultTy (.base .unit) (.opaque "IOError" (.fixed .top))) (e := rangedEffect "File.Write")
    (by constructor <;> scope_simp [ScopeSignatures.appendBytesIn]) (top_range rfl)
    (by scope_simp [ScopeSignatures.appendBytesIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.appendBytesIn, label_range, rangedEffect])
    ⟨by scope_simp [ScopeSignatures.appendBytesIn, rangedEffect], by scope_simp [rangedEffect],
      by scope_simp [(arities externals).2.2.1, rangedEffect]⟩ rfl rfl
    (by scope_simp []) (ranged_effect_form _).1 (ranged_effect_form _).2 (.cons held_path_typed (.cons (inhabitant_typed (a := .bytes) trivial) .nil))
    (by intro w hw; simp at hw; rcases hw with rfl | rfl <;> trivial)
/-- ループバックの端点へのGETの要求。ヘッダーと本文は空である。 -/
def clientRequest : Val := .con "Http.ClientRequest" []
  [.const (.string "GET"), .const (.string "https://127.0.0.1/"), .list [], .bytesV [], .const (.integer ⟨1, by decide⟩)]

/-- その要求の端点。 -/
def loopback : Scope.Domain.Target := .endpoint ⟨.ip (.v4 2130706433 (by decide)), ⟨443, by decide⟩⟩

theorem client_request_typed {externals} :
    HasTypeV (program externals) (builtins (program externals)) StoreTy.empty [] [] [] clientRequest
      TargetTable.clientRequestTy := by
  have hP := http_declarations externals
  have hp := hP ScopeDeclarations.pair (by simp [ScopeDeclarations.http])
  have hc := hP ScopeDeclarations.clientRequest (by simp [ScopeDeclarations.http])
  have reqLookup : (program externals).cons "Http.ClientRequest" = some ⟨"Http.ClientRequest",0,
      [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),
       .bytes,.base .integer]⟩ :=
    hc.2 ("Http.ClientRequest",⟨"Http.ClientRequest",0,
      [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),
       .bytes,.base .integer]⟩)
      (by simp [ScopeDeclarations.clientRequest,StandardKeyTyping.DataDecl.entries])
  refine .V_Con reqLookup rfl ?_ ?_ ?_ ⟨?_,?_,?_⟩
  · exact ⟨rfl,by intro i a k ha; cases i <;> cases ha⟩
  · intro t hm
    simp at hm
    rcases hm with rfl | rfl | rfl | rfl <;> simp [Ty.WF,Ty.WFList]
  · exact .cons (.V_Const trivial) (.cons (.V_Const trivial)
      (.cons (.V_List .nil (by trivial) (by trivial) ⟨⟨2,hp.1,rfl⟩,by trivial⟩)
      (.cons (.V_Bytes (by simp)) (.cons (.V_Const trivial) .nil))))
  · trivial
  · trivial
  · exact ⟨⟨0,hc.1,rfl⟩,trivial⟩

/-- 全体を許す範囲の下の保持した要求。 -/
def heldRequest : Val := .checkedRequest loopback clientRequest

theorem held_request_typed {externals} :
    HasTypeVQ (program externals) (builtins (program externals)) StoreTy.empty Qempty [] [] [] heldRequest
      (.opaque "Http.RequestIn" (.fixed (.absolute .top))) :=
  HasTypeVQ.checkedRequest_opaque rfl rfl client_request_typed.V_Normal (by decide)
    parseUrlTarget_https_loopback (by decide)

theorem held_request_ground : heldRequest.Ground := by
  change clientRequest.Ground
  exact groundVal_ground (by decide)

/-- Http.requestInValueの行は、全体を許す範囲と保持した要求で全欄を満たす。 -/
theorem PureRow.Satisfiable.requestInValue {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.requestInValue) : PureRow.Satisfiable (program externals) row.name := by
  obtain ⟨_, _, _, _, _, _, _, _, request, _⟩ := arities externals
  exact arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [heldRequest])
    (names := ["request"]) (inputs := [.opaque "Http.RequestIn" (.fixed (.absolute .top))])
    (ret := ScopeSignatures.clientRequestTy)
    (e := Eff.empty) (by constructor <;> scope_simp [ScopeSignatures.requestInValue]) (top_range rfl)
    (by scope_simp [ScopeSignatures.requestInValue]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.requestInValue])
    ⟨by scope_simp [], by scope_simp [], by scope_simp [request]⟩ rfl rfl
    (by scope_simp []) rfl (by scope_simp []) (.cons held_request_typed .nil)
    (by intro w hw; simp at hw; subst hw; exact held_request_ground)

/-- Http.widenRequestInの行は、全体を許す二つの範囲と保持した要求で全欄を満たす。 -/
theorem PureRow.Satisfiable.widenRequestIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.widenRequestIn) : PureRow.Satisfiable (program externals) row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top, .absolute .top]) (ws := [heldRequest])
    (names := ["request"]) (inputs := [.opaque "Http.RequestIn" (.fixed (.absolute .top))])
    (ret := .opaque "Http.RequestIn" (.fixed (.absolute .top)))
    (e := Eff.empty) (by constructor <;> scope_simp [ScopeSignatures.widenRequestIn]) (top_ranges rfl)
    (by scope_simp [ScopeSignatures.widenRequestIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.widenRequestIn]) ⟨by scope_simp [], by scope_simp [], by scope_simp []⟩ rfl rfl
    (by scope_simp []) rfl (by scope_simp []) (.cons held_request_typed .nil)
    (by intro w hw; simp at hw; subst hw; exact held_request_ground)

/-- Http.checkRequestInの行は、全体を許す範囲と空の文字列・二つの整数1・要求で全欄を満たす。 -/
theorem PureRow.Satisfiable.checkRequestIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.checkRequestIn) : PureRow.Satisfiable (program externals) row.name := by
  obtain ⟨_, _, result, _, _, _, _, _, request, _, checkError, _⟩ := arities externals
  exact arguments_of_ranges row hsig (rs := [.absolute .top])
    (ws := [.const (sample .string), .const (sample .integer), .const (sample .integer), clientRequest])
    (names := ["hostPattern","minimumPort","maximumPort","request"])
    (inputs := [.base .string, .base .integer, .base .integer, ScopeSignatures.clientRequestTy])
    (ret := ScopeSignatures.resultTy (.opaque "Http.RequestIn" (.fixed (.absolute .top))) ScopeSignatures.requestCheckErrorTy)
    (e := Eff.empty) (by constructor <;> scope_simp [ScopeSignatures.checkRequestIn]) (top_range rfl)
    (by scope_simp [ScopeSignatures.checkRequestIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.checkRequestIn])
    ⟨by scope_simp [], by scope_simp [], by scope_simp [result, request, checkError]⟩ rfl rfl
    (by scope_simp []) rfl (by scope_simp [])
    (.cons (sample_typed _) (.cons (sample_typed _) (.cons (sample_typed _) (.cons client_request_typed.V_Normal .nil))))
    (by intro w hw; simp at hw; rcases hw with rfl | rfl | rfl | rfl <;> first | trivial | exact groundVal_ground (by decide))

/-- Http.sendInの行は、全体を許す範囲と保持した要求で全欄を満たす。 -/
theorem IORow.Satisfiable.sendIn {externals} (row : Primitive)
    (hsig : row.signature = ScopeSignatures.sendIn) : IORow.Satisfiable (program externals) row.name :=
  arguments_of_ranges row hsig (rs := [.absolute .top]) (ws := [heldRequest])
    (names := ["request"]) (inputs := [.opaque "Http.RequestIn" (.fixed (.absolute .top))])
    (ret := ScopeSignatures.resultTy (.opaque "Http.Response" (.fixed .top)) (.opaque "NetworkError" (.fixed .top)))
    (e := rangedEffect "Http.Connect")
    (by constructor <;> scope_simp [ScopeSignatures.sendIn]) (top_range rfl)
    (by scope_simp [ScopeSignatures.sendIn]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ScopeSignatures.sendIn, label_range, rangedEffect])
    ⟨by scope_simp [rangedEffect], by scope_simp [rangedEffect],
      by scope_simp [(arities externals).2.2.1, rangedEffect]⟩ rfl rfl
    (by scope_simp []) (ranged_effect_form _).1 (ranged_effect_form _).2 (.cons held_request_typed .nil)
    (by intro w hw; simp at hw; subst hw; exact held_request_ground)

/-- printの行は、空の文字列で全欄を満たす。 -/
theorem IORow.Satisfiable.print {P : Program} (row : Primitive) (hsig : row.signature = ModelTargets.printSig) :
    IORow.Satisfiable P row.name :=
  arguments_of_ranges row hsig (rs := []) (ws := [.const (sample .string)])
    (names := ["text"]) (inputs := [.base .string]) (ret := .base .unit) (e := Eff.single "Console.Write")
    (by constructor <;> scope_simp [ModelTargets.printSig]) (by scope_simp [ModelTargets.printSig])
    (by scope_simp [ModelTargets.printSig]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ModelTargets.printSig]) ⟨by scope_simp [], by scope_simp [], by scope_simp []⟩ rfl rfl
    trivial rfl (by scope_simp []) (.cons (sample_typed _) .nil) (by intro w hw; simp at hw; subst hw; trivial)

/-- exitの行は、整数1で全欄を満たす。 -/
theorem IORow.Satisfiable.exit {P : Program} (row : Primitive) (hsig : row.signature = ModelTargets.exitSig) :
    IORow.Satisfiable P row.name :=
  arguments_of_ranges row hsig (rs := []) (ws := [.const (sample .integer)])
    (names := ["code"]) (inputs := [.base .integer]) (ret := .base .unit) (e := Eff.single "Process.Exit")
    (by constructor <;> scope_simp [ModelTargets.exitSig]) (by scope_simp [ModelTargets.exitSig])
    (by scope_simp [ModelTargets.exitSig]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ModelTargets.exitSig]) ⟨by scope_simp [], by scope_simp [], by scope_simp []⟩ rfl rfl
    trivial rfl (by scope_simp []) (.cons (sample_typed _) .nil) (by intro w hw; simp at hw; subst hw; trivial)

/-- File.readTextの行は、空の文字列で全欄を満たす。 -/
theorem IORow.Satisfiable.readText {externals} (row : Primitive) (hsig : row.signature = ModelTargets.readTextSig) :
    IORow.Satisfiable (program externals) row.name :=
  arguments_of_ranges row hsig (rs := []) (ws := [.const (sample .string)])
    (names := ["path"]) (inputs := [.base .string])
    (ret := ScopeSignatures.resultTy (.base .string) (.opaque "IOError" .top)) (e := Eff.single "File.Read")
    (by constructor <;> scope_simp [ModelTargets.readTextSig]) (by scope_simp [ModelTargets.readTextSig])
    (by scope_simp [ModelTargets.readTextSig]) ⟨rfl, by intro i a k ha; cases ha⟩
    (by scope_simp [ModelTargets.readTextSig])
    ⟨by scope_simp [], by scope_simp [], by scope_simp [(arities externals).2.2.1]⟩ rfl rfl
    (by scope_simp []) rfl (by scope_simp []) (.cons (sample_typed _) .nil) (by intro w hw; simp at hw; subst hw; trivial)

/-- 純粋な判定の正常な基本型の入力を、合成表の入力の存在へ接続する。 -/
theorem PureRow.Satisfiable.predicate {externals} (row : Primitive) (api : PredicateResponse.API)
    (hn : row.name = api.name) (hs : row.signature = api.signature) :
    PureRow.Satisfiable (program externals) row.name := by
  refine ⟨StoreTy.empty,api.signature,[],[],[],api.sample true,.base .boolean,Eff.empty,?_,?_⟩
  · rw [← hs]; exact row_lookup _ row
  · rw [hn]; exact PredicateResponse.sample_arguments _ _ _ api true

/-- 範囲付きの行、前からの取得、純粋な判定と一般の検査は、全入力条件を満たす正常値を持つ。 -/
theorem scope_inputs (externals : List (ExternalKey × ExternalDecl)) (row : Primitive)
    (ranged : row.scopePure = true) : PureRow.Satisfiable (program externals) row.name := by
  cases row
  case p185 => exact PureRow.Satisfiable.checkRequestIn .p185 rfl
  case p186 => exact PureRow.Satisfiable.requestInValue .p186 rfl
  case p188 => exact PureRow.Satisfiable.widenRequestIn .p188 rfl
  case p281 => exact PureRow.Satisfiable.checkPathIn .p281 rfl
  case p282 => exact PureRow.Satisfiable.pathInValue .p282 rfl
  case p283 => exact PureRow.Satisfiable.widenPathIn .p283 rfl
  case p377 => exact PureRow.Satisfiable.front .p377 rfl
  case p378 => exact PureRow.Satisfiable.predicate .p378 (.path) rfl rfl
  case p379 => exact PureRow.Satisfiable.predicate .p379 (.host) rfl rfl
  case p380 => exact PureRow.Satisfiable.predicate .p380 (.characters) rfl rfl
  case p381 => exact PureRow.Satisfiable.predicate .p381 (.floating .binary64 .finite) rfl rfl
  case p382 => exact PureRow.Satisfiable.predicate .p382 (.floating .binary64 .infinite) rfl rfl
  case p383 => exact PureRow.Satisfiable.predicate .p383 (.floating .binary64 .positiveInfinity) rfl rfl
  case p384 => exact PureRow.Satisfiable.predicate .p384 (.floating .binary64 .negativeInfinity) rfl rfl
  case p385 => exact PureRow.Satisfiable.predicate .p385 (.floating .binary64 .positiveZero) rfl rfl
  case p386 => exact PureRow.Satisfiable.predicate .p386 (.floating .binary64 .negativeZero) rfl rfl
  case p387 => exact PureRow.Satisfiable.predicate .p387 (.floating .binary32 .finite) rfl rfl
  case p388 => exact PureRow.Satisfiable.predicate .p388 (.floating .binary32 .positiveInfinity) rfl rfl
  case p389 => exact PureRow.Satisfiable.predicate .p389 (.floating .binary32 .negativeInfinity) rfl rfl
  case p390 => exact PureRow.Satisfiable.predicate .p390 (.floating .binary32 .positiveZero) rfl rfl
  case p391 => exact PureRow.Satisfiable.predicate .p391 (.floating .binary32 .negativeZero) rfl rfl
  case p392 =>
    exact ⟨StoreTy.empty,RefinementCheck.signature,[.base .integer,RefinementCheck.nonnegative],[],[],
      [.const (.integer ⟨1,by decide⟩)],RefinementCheck.result RefinementCheck.nonnegative,Eff.empty,
      row_lookup _ .p392,RefinementCheck.integer_inputs externals ⟨1,by decide⟩⟩
  all_goals cases ranged

/-- IOと終了の全10行は、合成プログラムで契約の前提を満たす入力を持つ。 -/
theorem io_inputs (externals : List (ExternalKey × ExternalDecl)) (row : Primitive)
    (io : row.io = true) : IORow.Satisfiable (program externals) row.name := by
  cases row
  case p157 => exact IORow.Satisfiable.appendBytesIn .p157 rfl
  case p158 => exact IORow.Satisfiable.appendTextIn .p158 rfl
  case p159 => exact IORow.Satisfiable.readBytesIn .p159 rfl
  case p160 => exact IORow.Satisfiable.readText .p160 rfl
  case p161 => exact IORow.Satisfiable.readTextIn .p161 rfl
  case p162 => exact IORow.Satisfiable.writeBytesIn .p162 rfl
  case p163 => exact IORow.Satisfiable.writeTextIn .p163 rfl
  case p187 => exact IORow.Satisfiable.sendIn .p187 rfl
  case p372 => exact IORow.Satisfiable.exit .p372 rfl
  case p373 => exact IORow.Satisfiable.print .p373 rfl
  all_goals cases io

end
end Benitoite.Release.Refinement.StandardModel
