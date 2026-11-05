import Benitoite.Release.Refinement.ResourceReleaseLeaves

/-! # 合成表の純粋な行の応答と、合成プログラムの共有の宣言

合成表の名前ごとに、`Builtins.ResponseAssumptions` の `delta_typed` と同じ形の契約
（`StandardModel.PureRow`）を置く。各行の証拠は、既存の任意のP/Bの応答の補題を、合成表の
同じlookupと同じBuiltinArgsへ当てて得る。部分表の `table_response` を合成表の証拠に流用しない。
合成プログラムが共有するOption・Result・Pair・要求・誤りの宣言と、Decimalの丸めの五方式の
宣言もここで供給する。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

/-- 合成表の名前 `b` の純粋な応答の契約。`delta_typed` の欄を一つの名前へ制限したもの。 -/
def PureRow (P : Program) (b : PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, (builtins P).sig b = some sg →
    BuiltinArgs P (builtins P) Ψ b sg ts es rs ws a e →
    ∃ out, (builtins P).delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P (builtins P) Ψ out a ∧ AdequateResult ws out

/-- 組込みの表の行（`Primitive`）の出典の表のδが、行の署名の全BuiltinArgsで型付きの応答を返すなら、合成表の同じ
名前は純粋な応答の契約を満たす。lookupは同じ行の署名へ解決する。 -/
theorem PureRow.of_row {P : Program} (row : Primitive)
    (response : ∀ Ψ ts es rs ws a e,
      BuiltinArgs P (builtins P) Ψ row.name row.signature ts es rs ws a e →
      ∃ out, row.provider.delta row.name ts es rs ws = some out ∧
        Outcome.Typed P (builtins P) Ψ out a ∧ AdequateResult ws out ∧ ∀ i, out ≠ .exit i) :
    PureRow P row.name := by
  intro Ψ sg ts es rs ws a e lookup args
  cases Option.some.inj (lookup.symm.trans (row_lookup P row))
  obtain ⟨out, delta, typed, adequate, nonexit⟩ := response Ψ ts es rs ws a e args
  refine ⟨out, ?_, nonexit, typed, adequate⟩
  show (primitive row.name).bind (fun r => r.provider.delta row.name ts es rs ws) = some out
  rw [primitive_lookup]
  exact delta

/-- 行の名前・署名・出典のδが既存の応答の名前・署名・δと一致すれば、既存の任意のP/Bの応答から
合成表の契約を得る。 -/
theorem PureRow.of_response {P : Program} (row : Primitive) {name : PrimName} {sg : PrimSig}
    {delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome}
    (hname : row.name = name) (hsig : row.signature = sg)
    (hdelta : ∀ ts es rs ws, row.provider.delta name ts es rs ws = delta name ts es rs ws)
    (response : ∀ Ψ ts es rs ws a e, BuiltinArgs P (builtins P) Ψ name sg ts es rs ws a e →
      ∃ out, delta name ts es rs ws = some out ∧
        Outcome.Typed P (builtins P) Ψ out a ∧ AdequateResult ws out ∧ ∀ i, out ≠ .exit i) :
    PureRow P row.name := by
  refine PureRow.of_row row (fun Ψ ts es rs ws a e args => ?_)
  rw [hname, hsig] at args
  rw [hname, hdelta]
  exact response Ψ ts es rs ws a e args

/-! ## 共有の宣言 -/

/-- 合成プログラムは、範囲付きのHTTPのモデルが読むResult・ScopeError・Pair・要求・要求の誤りを、
同じ構成子とarityで宣言する。 -/
theorem http_declarations (externals : List (ExternalKey × ExternalDecl)) :
    ScopeDeclarations.HasHttp (program externals) := by
  have arity : ∀ d ∈ ScopeDeclarations.http, (program externals).DataArity d.name d.ntys := by
    intro d hd
    refine ⟨?_, ?_⟩
    · simp only [ScopeDeclarations.http, ScopeDeclarations.file, List.cons_append, List.nil_append,
        List.mem_cons, List.not_mem_nil, or_false] at hd
      rcases hd with rfl | rfl | rfl | rfl | rfl
      · exact ⟨"Result.Ok", _, rfl, rfl⟩
      · exact ⟨"Scope.ScopeError.InvalidPattern", _, rfl, rfl⟩
      · exact ⟨"Pair.Pair", _, rfl, rfl⟩
      · exact ⟨"Http.ClientRequest", _, rfl, rfl⟩
      · exact ⟨"Http.RequestCheckError.InvalidUrl", _, rfl, rfl⟩
    · intro c cd lookup owner
      change constructors.lookup c = some cd at lookup
      obtain ⟨before, after, eq, _⟩ := List.lookup_eq_some_iff.mp lookup
      have mem : (c, cd) ∈ constructors := by rw [eq]; exact List.mem_append_right _ List.mem_cons_self
      obtain ⟨decl, member, entry⟩ := List.mem_flatMap.mp mem
      obtain ⟨field, _, same⟩ := List.mem_map.mp entry
      cases same
      have all : ∀ d ∈ ScopeDeclarations.http, ∀ decl ∈ declarations, decl.name = d.name →
          decl.ntys = d.ntys := by decide
      exact all d hd decl member owner
  intro d hd
  refine ⟨arity d hd, ?_⟩
  simp only [ScopeDeclarations.http, ScopeDeclarations.file, List.cons_append, List.nil_append,
    List.mem_cons, List.not_mem_nil, or_false] at hd
  rcases hd with rfl | rfl | rfl | rfl | rfl
  all_goals
    intro c hc
    simp only [StandardKeyTyping.DataDecl.entries, ScopeDeclarations.result, ScopeDeclarations.scopeError,
      ScopeDeclarations.pair, ScopeDeclarations.clientRequest, ScopeDeclarations.requestCheckError,
      List.map_cons, List.map_nil, List.mem_cons, List.not_mem_nil, or_false] at hc
    repeat' (rcases hc with rfl | hc)
    all_goals first | rfl | (subst hc; rfl)

/-- 合成プログラムはDecimalの応答が読むOptionと丸めの五方式を宣言し、丸め方式のデータ名を持つ
構成子は五つの方式に限る。 -/
theorem rounding_declarations (externals : List (ExternalKey × ExternalDecl)) :
    StandardDecimalResponse.Declarations (program externals) := by
  have options := option_declarations externals
  refine ⟨options.some_decl, options.none_decl, options.arity, ?_⟩
  intro c cd lookup owner
  change constructors.lookup c = some cd at lookup
  obtain ⟨before, after, eq, _⟩ := List.lookup_eq_some_iff.mp lookup
  have mem : (c, cd) ∈ constructors := by rw [eq]; exact List.mem_append_right _ List.mem_cons_self
  obtain ⟨decl, member, entry⟩ := List.mem_flatMap.mp mem
  obtain ⟨field, inside, same⟩ := List.mem_map.mp entry
  cases same
  unfold declarations at member
  rcases List.mem_append.mp member with old | last
  · have other : ∀ d ∈ StandardOrdinaryCoreBodies.declarations ++ ScopeDeclarations.http.filter
        (fun d => !(StandardOrdinaryCoreBodies.declarations.any (fun old => old.name == d.name))) ++ [byteOrder],
        d.name ≠ "RoundingMode" := by decide
    exact absurd owner (other decl old)
  cases List.mem_singleton.mp last
  simp only [roundingMode, List.mem_cons, List.not_mem_nil, or_false] at inside
  rcases inside with rfl | rfl | rfl | rfl | rfl
  · exact ⟨rfl, .halfToEven, rfl⟩
  · exact ⟨rfl, .halfAwayFromZero, rfl⟩
  · exact ⟨rfl, .towardZero, rfl⟩
  · exact ⟨rfl, .towardNegativeInfinity, rfl⟩
  · exact ⟨rfl, .towardPositiveInfinity, rfl⟩

/-- 宣言の供給は任意の外部宣言の表で成り立つ。ファイルの表もHTTPの表と同じResultと誤りを使う。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    ScopeDeclarations.HasFile (program externals) ∧
      (program externals).DataArity "Pair" 2 ∧ (program externals).DataArity "Result" 2 ∧
      (program externals).cons "RoundingMode.TowardZero" = some ⟨"RoundingMode", 0, []⟩ :=
  ⟨(http_declarations externals).file,
    ((http_declarations externals) ScopeDeclarations.pair (by simp [ScopeDeclarations.http])).1,
    ((http_declarations externals) ScopeDeclarations.result (by simp [ScopeDeclarations.http,
      ScopeDeclarations.file])).1, rfl⟩

/-! ## 演算子の表の最初の十六行 -/

/-- 演算子の表（整数のdiv/mod・二幅のFloat・Decimal・Stringの算術）の行は、同じentryの
任意のP/Bの応答から合成表の契約を得る。 -/
theorem PureRow.operator {P : Program} (row : Primitive) (entry : StandardOperatorResponse.Entry)
    (hname : row.name = entry.name) (hsig : row.signature = entry.signature)
    (hprovider : row.provider.delta = (StandardOperatorResponse.table signatureBase).delta) :
    PureRow P row.name :=
  PureRow.of_response row hname hsig
    (fun ts es rs ws => by
      rw [hprovider]
      show ((StandardOperatorResponse.dispatch entry.name).bind fun r => r.delta entry.name ts es rs ws) = _
      rw [StandardOperatorResponse.dispatch_name]
      rfl)
    (fun _ _ _ _ _ _ _ args => StandardOperatorResponse.response entry args)

/-- 演算子の表の並びの最初の十六行（七整数型のdiv/modと、Floatのadd/subtract）の全BuiltinArgsは、
合成表の同じlookupで型付きの非exitの応答を持つ。 -/
theorem first_sixteen_entries : StandardOperatorResponse.entries.take 16 =
    [.integer .integer8 false, .integer .integer8 true, .integer .integer16 false, .integer .integer16 true,
      .integer .integer32 false, .integer .integer32 true, .integer .integer64 false, .integer .integer64 true,
      .integer .unsignedInteger16 false, .integer .unsignedInteger16 true,
      .integer .unsignedInteger32 false, .integer .unsignedInteger32 true,
      .integer .unsignedInteger64 false, .integer .unsignedInteger64 true,
      .floating false .add, .floating false .subtract] := rfl

theorem first_sixteen (P : Program) :
    ∀ entry ∈ StandardOperatorResponse.entries.take 16, PureRow P entry.name := by
  intro entry member
  rw [first_sixteen_entries] at member
  simp only [List.mem_cons, List.not_mem_nil, or_false] at member
  rcases member with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl
  · exact PureRow.operator .p067 (.integer .integer8 false) rfl rfl rfl
  · exact PureRow.operator .p072 (.integer .integer8 true) rfl rfl rfl
  · exact PureRow.operator .p047 (.integer .integer16 false) rfl rfl rfl
  · exact PureRow.operator .p052 (.integer .integer16 true) rfl rfl rfl
  · exact PureRow.operator .p057 (.integer .integer32 false) rfl rfl rfl
  · exact PureRow.operator .p062 (.integer .integer32 true) rfl rfl rfl
  · exact PureRow.operator .p037 (.integer .integer64 false) rfl rfl rfl
  · exact PureRow.operator .p042 (.integer .integer64 true) rfl rfl rfl
  · exact PureRow.operator .p083 (.integer .unsignedInteger16 false) rfl rfl rfl
  · exact PureRow.operator .p088 (.integer .unsignedInteger16 true) rfl rfl rfl
  · exact PureRow.operator .p092 (.integer .unsignedInteger32 false) rfl rfl rfl
  · exact PureRow.operator .p097 (.integer .unsignedInteger32 true) rfl rfl rfl
  · exact PureRow.operator .p101 (.integer .unsignedInteger64 false) rfl rfl rfl
  · exact PureRow.operator .p106 (.integer .unsignedInteger64 true) rfl rfl rfl
  · exact PureRow.operator .p018 (.floating false .add) rfl rfl rfl
  · exact PureRow.operator .p026 (.floating false .subtract) rfl rfl rfl

/-- 合成表のlookupで %Integer8.div の型付き引数から、表のδの応答を得る。 -/
example (P : Program) {Ψ sg ts es rs ws a e} (lookup : (builtins P).sig "%Integer8.div" = some sg)
    (args : BuiltinArgs P (builtins P) Ψ "%Integer8.div" sg ts es rs ws a e) :
    ∃ out, (builtins P).delta "%Integer8.div" ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P (builtins P) Ψ out a ∧ AdequateResult ws out :=
  first_sixteen P (.integer .integer8 false)
    (by rw [first_sixteen_entries]; exact List.mem_cons_self) Ψ sg ts es rs ws a e lookup args

end
end Benitoite.Release.Refinement.StandardModel
