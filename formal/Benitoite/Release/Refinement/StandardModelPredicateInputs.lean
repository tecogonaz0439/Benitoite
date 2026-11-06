import Benitoite.Release.Refinement.StandardModelCollectionInputs

/-! # 純粋な判定の型付き入力と受理・拒否の対照 -/
namespace Benitoite.Release.Refinement.PredicateResponse
open StandardModel
noncomputable section

/-- 任意の正常な基本型の引数列で、判定の原署名の全入力条件を満たす。 -/
theorem arguments {P B Ψ ws} (api : API)
    (values : HasTypeVsQ P B Ψ Qempty [] [] [] ws api.inputs)
    (ground : ∀ w ∈ ws, w.Ground) :
    BuiltinArgs P B Ψ api.name api.signature [] [] [] ws (.base .boolean) Eff.empty := by
  have ann : Ty.Annotation P [] [] (.fn api.names api.inputs (.base .boolean) Eff.empty) := by
    cases api <;> try (rename_i w t; cases w)
    all_goals exact ⟨by simp [API.names,API.inputs,Ty.WF,Ty.WFList,Eff.WF,Eff.empty,
      NamesWF,Eff.Canonical,Eff.norm],by trivial,by trivial⟩
  refine arguments_of_toTel ?_ ?_ ?_ ?_ ?_ (instantiated api) ann ?_ rfl trivial rfl
    (by simp [Eff.WF,Eff.empty,Ty.WFList]) values ground ?_
  · cases api <;> try (rename_i w t; cases w)
    all_goals constructor <;> simp [API.signature,API.names,API.inputs,RowTransport,PrimSig.tel,
      signatureTel,Eff.empty,Ty.normTys,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,
      QTy,QTys,QEff,Eff.row]
  · simp [Builtins.RangeAdmissible,API.signature]
  · cases api <;> try (rename_i w t; cases w)
    all_goals simp [API.signature,API.names,API.inputs,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,
      Tel.mapRanges,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Tel.norm,Ty.norm,Ty.normTys]
  · exact ⟨rfl,by intro i t k ht; cases ht⟩
  · intro t ht; cases ht
  · cases api <;> try (rename_i w t; cases w)
    all_goals rfl
  · intro t ht; cases ht

def FloatTest.sampleBits (t : FloatTest) (single accepted : Bool) : Nat :=
  let infinity := if single then 2139095040 else 9218868437227405312
  let sign := if single then 2147483648 else 9223372036854775808
  match t,accepted with
  | .finite,true => 0 | .finite,false => infinity
  | .infinite,true => infinity | .infinite,false => 0
  | .positiveInfinity,true => infinity | .positiveInfinity,false => infinity + sign
  | .negativeInfinity,true => infinity + sign | .negativeInfinity,false => infinity
  | .positiveZero,true => 0 | .positiveZero,false => sign
  | .negativeZero,true => sign | .negativeZero,false => 0

/-- 二つの正常入力で、各判定の真偽の両側を満たす。 -/
def API.sample (api : API) (accepted : Bool) : List Val :=
  match api with
  | .path => [.const (.string "/"),.const (.string (if accepted then "/" else "/x"))]
  | .host => [.const (.string "127.0.0.1"),.const (.string (if accepted then "127.0.0.1" else "127.0.0.2"))]
  | .characters => [.const (.string (if accepted then "a" else "A")),.const (.character 'a'),.const (.character 'z')]
  | .floating .binary64 t => [.const (.float64 (UInt64.ofNat (t.sampleBits false accepted)))]
  | .floating .binary32 t => [.const (.float32 (UInt32.ofNat (t.sampleBits true accepted)))]

theorem sample_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (api : API) (accepted : Bool) :
    HasTypeVsQ P B Ψ Qempty [] [] [] (api.sample accepted) api.inputs := by
  cases api <;> try (rename_i w t; cases w)
  all_goals first
    | exact .cons (.V_Const trivial) .nil
    | exact .cons (.V_Const trivial) (.cons (.V_Const trivial) .nil)
    | exact .cons (.V_Const trivial) (.cons (.V_Const trivial) (.cons (.V_Const trivial) .nil))

theorem sample_ground (api : API) (accepted : Bool) : ∀ w ∈ api.sample accepted, w.Ground := by
  cases api <;> try (rename_i w t; cases w)
  all_goals simp [API.sample,Val.Ground,Val.ClosedAt]

/-- 判定の真偽の双方で全 BuiltinArgs の前提を供給する。 -/
theorem sample_arguments (P : Program) (B : Builtins) (Ψ : StoreTy) (api : API) (accepted : Bool) :
    BuiltinArgs P B Ψ api.name api.signature [] [] [] (api.sample accepted) (.base .boolean) Eff.empty :=
  arguments api (sample_typed P B Ψ api accepted) (sample_ground api accepted)

/-- 同じ絶対形の pattern を固定し、受理と範囲外を区別する。 -/
theorem path_samples (accepted : Bool) : API.path.run (API.path.sample accepted) = accepted := by
  cases accepted <;> simp +decide [API.run,API.sample,matchString,parseAtPattern,parsePatternText,parsePathPatternText,
    parseAbsolutePathPattern,parseAtInput,parseTargetInput,splitText,splitChars,Scope.Domain.PathWordWF,stringMember]

/-- 相対形と解析不能の pattern は、実行時にも偽である。 -/
theorem path_pattern_rejections :
    API.path.run [.const (.string "a"),.const (.string "/a")] = false ∧
    API.path.run [.const (.string "/a/../b"),.const (.string "/b")] = false := by
  have suffix : "/a/../b".endsWith "/**" = false := by decide +kernel
  simp +decide [suffix,API.run,matchString,parseAtPattern,parsePatternText,parsePathPatternText,
    parseAbsolutePathPattern,parseAtInput,parseTargetInput,parseBasedRest,pathBasePrefixes,
    splitText,splitChars,Scope.Domain.PathWordWF]

/-- 同じホスト条件に対し、正常な対象の内外を区別する。 -/
theorem host_samples (accepted : Bool) : API.host.run (API.host.sample accepted) = accepted := by
  cases accepted <;> simp +decide [API.run,API.sample,matchString,parseAtPattern,parsePatternText,
    parseHostPatternText,parseAtInput,parseTargetInput,parseHost,parseIPv4,splitText,splitChars,parseNatDec,stringMember]

theorem characters_samples (accepted : Bool) : API.characters.run (API.characters.sample accepted) = accepted := by
  cases accepted <;> decide

/-- 有限値・正負の無限・符号付き零を区別する同じビット列の分類を用いる。 -/
theorem float_samples (w : FloatWidth) (t : FloatTest) (accepted : Bool) :
    (API.floating w t).run ((API.floating w t).sample accepted) = accepted := by
  cases w <;> cases t <;> cases accepted <;> decide

/-- NaN は有限値に含めず、正負の無限のどちらにも含めない。 -/
example :
    (API.floating .binary64 .finite).run [.const (.float64 9221120237041090560)] = false ∧
    (API.floating .binary32 .finite).run [.const (.float32 2143289344)] = false ∧
    (API.floating .binary64 .infinite).run [.const (.float64 9221120237041090560)] = false := by decide

/-- 合成表に属する判定は、真と偽の両側の正常入力で型付きの応答を持つ。 -/
theorem composed_sample (externals : List (ExternalKey × ExternalDecl)) (row : Primitive) (api : API)
    (hn : row.name = api.name) (hs : row.signatureWith signatureBase.sat = api.signature)
    (hd : row.provider.delta = api.delta) (hk : row.readsKeys = false) (accepted : Bool) :
    (builtins (program externals)).sig api.name = some api.signature ∧
    BuiltinArgs (program externals) (builtins (program externals)) StoreTy.empty api.name api.signature
      [] [] [] (api.sample accepted) (.base .boolean) Eff.empty ∧
    (builtins (program externals)).delta api.name [] [] [] (api.sample accepted) =
      some (.val (.const (.boolean accepted))) := by
  have raw : api.run (api.sample accepted) = accepted := by
    cases api with
    | path => exact path_samples accepted
    | host => exact host_samples accepted
    | characters => exact characters_samples accepted
    | floating w t => exact float_samples w t accepted
  refine ⟨?_,sample_arguments _ _ _ api accepted,?_⟩
  · rw [← hn]
    have h := row_lookup (program externals) row
    rwa [← Primitive.signatureWith_base row,hs] at h
  · rw [← hn,RowLookup.delta row hk,hd,hn]
    simp [API.delta,raw]

/-- 同じ表の新しい純粋判定の行と API の対応。 -/
def composedPredicates : List (Primitive × API) := [
  (.p378,(.path)),
  (.p379,(.host)),
  (.p380,(.characters)),
  (.p381,(.floating .binary64 .finite)),
  (.p382,(.floating .binary64 .infinite)),
  (.p383,(.floating .binary64 .positiveInfinity)),
  (.p384,(.floating .binary64 .negativeInfinity)),
  (.p385,(.floating .binary64 .positiveZero)),
  (.p386,(.floating .binary64 .negativeZero)),
  (.p387,(.floating .binary32 .finite)),
  (.p388,(.floating .binary32 .positiveInfinity)),
  (.p389,(.floating .binary32 .negativeInfinity)),
  (.p390,(.floating .binary32 .positiveZero)),
  (.p391,(.floating .binary32 .negativeZero))]

/-- 全ての対応行で、真偽双方の入力条件・lookup・実際の合成表の応答を確認する。 -/
theorem composed_inputs (externals : List (ExternalKey × ExternalDecl)) (accepted : Bool) :
    ∀ entry ∈ composedPredicates,
      (builtins (program externals)).sig entry.2.name = some entry.2.signature ∧
      BuiltinArgs (program externals) (builtins (program externals)) StoreTy.empty entry.2.name entry.2.signature
        [] [] [] (entry.2.sample accepted) (.base .boolean) Eff.empty ∧
      (builtins (program externals)).delta entry.2.name [] [] [] (entry.2.sample accepted) =
        some (.val (.const (.boolean accepted))) := by
  intro entry he
  simp only [composedPredicates,List.mem_cons,List.not_mem_nil,or_false] at he
  rcases he with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact composed_sample externals .p378 (.path) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p379 (.host) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p380 (.characters) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p381 (.floating .binary64 .finite) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p382 (.floating .binary64 .infinite) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p383 (.floating .binary64 .positiveInfinity) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p384 (.floating .binary64 .negativeInfinity) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p385 (.floating .binary64 .positiveZero) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p386 (.floating .binary64 .negativeZero) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p387 (.floating .binary32 .finite) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p388 (.floating .binary32 .positiveInfinity) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p389 (.floating .binary32 .negativeInfinity) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p390 (.floating .binary32 .positiveZero) rfl rfl rfl rfl accepted
  · exact composed_sample externals .p391 (.floating .binary32 .negativeZero) rfl rfl rfl rfl accepted

end
end Benitoite.Release.Refinement.PredicateResponse
