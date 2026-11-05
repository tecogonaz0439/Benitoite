import Benitoite.Release.Refinement.StandardModelCollectionRows

/-! # 合成表の範囲付きの純粋な行・IOの行・終了の行

範囲付きのパスと要求の六つの純粋な行と、範囲付きのファイルとHTTPの七つのIOの行は、既存の任意の
P/Bの応答の補題（ScopeResponse・ScopedIOResponse）から、合成表の同じlookup・同じBuiltinArgs・同じ
IO応答の関係の応答を得る。範囲を持たないprint・exit・File.readTextは、ModelTargetsのモデルの同じ
応答の関係を合成表で読む。新しいIOの意味は定義しない。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

/-- 合成表の名前 `b` のIO・終了の応答の契約。`io_typed`・`io_kind`・`io_exists` と
`TargetAgreement.io_target` の欄を一つの名前へ制限したもの。 -/
def IORow (P : Program) (b : PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, (builtins P).sig b = some sg →
    BuiltinArgs P (builtins P) Ψ b sg ts es rs ws a e →
    (∀ out obs, (builtins P).ioResponse b ts es ws out obs →
      Outcome.Typed P (builtins P) Ψ out a ∧ AdequateResult ws out ∧
      ((sg.kind = .io ∧ ∀ n, out ≠ .exit n) ∨ (sg.kind = .exit ∧ ∀ v, out ≠ .val v)) ∧
      Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs) ∧
    ∃ out obs, (builtins P).ioResponse b ts es ws out obs

private theorem io_row_of {P : Program} {row : Primitive} {ts es ws out obs}
    (h : (builtins P).ioResponse row.name ts es ws out obs) :
    row.provider.ioResponse row.name ts es ws out obs := by
  obtain ⟨r, found, hr⟩ := h
  cases Option.some.inj (found.symm.trans (primitive_lookup row))
  exact hr

private theorem io_row_to {P : Program} {row : Primitive} {ts es ws out obs}
    (h : row.provider.ioResponse row.name ts es ws out obs) :
    (builtins P).ioResponse row.name ts es ws out obs :=
  ⟨row, primitive_lookup row, h⟩

/-- 範囲付きのファイルの六行とHttp.sendInの行。応答の関係は出典のモデルの同じ範囲付きIOの関係である。 -/
theorem IORow.scoped {externals} (row : Primitive) (op : ScopedIOResponse.Operation)
    (hname : row.name = op.name) (hsig : row.signature = op.signature)
    (hprovider : ∀ ts es ws out obs, row.provider.ioResponse op.name ts es ws out obs ↔
      ScopedIOResponse.ioResponse op.name ts es ws out obs) :
    IORow (program externals) row.name := by
  intro Ψ sg ts es rs ws a e lookup args
  cases Option.some.inj (lookup.symm.trans (row_lookup _ row))
  rw [hname, hsig] at args
  have kind : op.signature.kind = .io ∨ op.signature.kind = .exit := by cases op <;> exact Or.inl rfl
  have response := ScopedIOResponse.response (http_declarations externals).file op.lookup kind rfl rfl rfl
    ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ ⟨rfl, rfl⟩ args
  rw [hsig]
  refine ⟨fun out obs h => ?_, ?_⟩
  · have hr := (hprovider ts es ws out obs).mp (hname ▸ io_row_of h)
    obtain ⟨typed, adequate, nonexit, targets⟩ := response.1 out obs hr
    exact ⟨typed, adequate, Or.inl ⟨by cases op <;> rfl, nonexit⟩, targets⟩
  · obtain ⟨out, obs, hr⟩ := response.2
    exact ⟨out, obs, io_row_to (hname ▸ (hprovider ts es ws out obs).mpr hr)⟩

private theorem targets_scoped (op : ScopedIOResponse.Operation) (send : op ≠ .send)
    (ts es ws out obs) :
    ModelTargets.ioResponse op.name ts es ws out obs ↔ ScopedIOResponse.ioResponse op.name ts es ws out obs := by
  constructor
  · rintro (⟨op', _, hn, hr⟩ | ⟨hn, _⟩ | ⟨hn, _⟩ | ⟨hn, _⟩)
    · exact hn ▸ hr
    all_goals cases op <;> simp [ScopedIOResponse.Operation.name] at hn
  · intro hr
    exact Or.inl ⟨op, send, rfl, hr⟩

private theorem http_scoped (ts es ws out obs) :
    ModelHttp.ioResponse ScopedIOResponse.Operation.send.name ts es ws out obs ↔
      ScopedIOResponse.ioResponse ScopedIOResponse.Operation.send.name ts es ws out obs :=
  ⟨fun h => h.2, fun h => ⟨rfl, h⟩⟩

/-- 範囲を持たない出力・終了・読取りの署名では、型付きの結果は署名の結果の型である。 -/
private theorem legacy_result {P B Ψ b sg ts es rs ws a e}
    (form : sg = ModelTargets.printSig ∨ sg = ModelTargets.exitSig ∨ sg = ModelTargets.readTextSig)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e) : a = sg.ret := by
  have nt : sg.tparams = [] := by rcases form with rfl | rfl | rfl <;> rfl
  have ne : sg.neffs = 0 := by rcases form with rfl | rfl | rfl <;> rfl
  have nr : sg.rkinds = [] := by rcases form with rfl | rfl | rfl <;> rfl
  have ts0 : ts = [] := List.length_eq_zero_iff.mp (args.admissible.typeCount.trans (by rw [nt]; rfl))
  have es0 : es = [] := List.length_eq_zero_iff.mp (args.admissible.rowCount.trans ne)
  have rs0 : rs = [] := List.length_eq_zero_iff.mp (args.ranges.1.trans (by rw [nr]; rfl))
  subst ts; subst es; subst rs
  have instantiated : instantiatedTel (Tel.instR [] sg.tel) [] [] =
      Ty.toTel sg.names sg.params sg.ret sg.eff := by
    have atoms (l : EffName) : mapRangeAtoms (rangeAt 0 [])
        (fun a => decide (a = .name l .top)) = (fun a => decide (a = .name l .top)) := by
      funext a
      simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
    rcases form with rfl | rfl | rfl
    all_goals simp [ModelTargets.printSig,ModelTargets.exitSig,ModelTargets.readTextSig,
      ScopeSignatures.unscopedIO,PrimSig.tel,signatureTel,
      instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
      Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
      Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.single,
      typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,mapIx,RangeIx.inst,
      atoms]
  have names : NamesWF sg.names sg.params := by
    rcases form with rfl | rfl | rfl <;>
      simp [ModelTargets.printSig,ModelTargets.exitSig,ModelTargets.readTextSig,ScopeSignatures.unscopedIO,NamesWF]
  have normalized : sg.ret.norm = sg.ret := by rcases form with rfl | rfl | rfl <;> rfl
  have values := args.arguments
  rw [instantiated] at values
  exact args.result.2.symm.trans ((values.toTelValues names).2.1.trans normalized)

private theorem read_safe {P B Ψ out ws} (hp : ScopeDeclarations.HasFile P)
    (kind : B.valKind "IOError" = none) (content : B.valContent "IOError" = none)
    (h : ScopedIOResponse.Reply .text out) :
    Outcome.Typed P B Ψ out ModelTargets.readTextSig.ret ∧ AdequateResult ws out ∧
      ∀ n, out ≠ .exit n := by
  have ha : Ty.Annotation P [] [] (.base .string) := ⟨trivial,trivial,trivial⟩
  have he := (ScopeDelta.checked_annotation (P := P) "IOError" (.absolute .top)).1
  have oa : Ordinary (Ty.base .string) := by intro b c d h; cases h
  have oe : Ordinary (Ty.opaque "IOError" .top) := by intro b c d h; cases h
  cases h with
  | ok payload =>
    cases payload with
    | text text =>
      have safe := ScopeDelta.result_safe (B := B) (Ψ := Ψ) (ws := ws) hp true ha he trivial trivial
        rfl rfl oa oe (v := .const (.string text)) (.V_Const trivial) trivial (by intro σ _ _; trivial)
      exact ⟨safe.1,safe.2.1,safe.2.2.2⟩
  | error id =>
    have safe := ScopeDelta.result_safe (B := B) (Ψ := Ψ) (ws := ws) hp false ha he trivial trivial
      rfl rfl oa oe (v := .const (.opaque "IOError" id)) (.V_Const ⟨kind,content⟩) trivial (by intro σ _ _; trivial)
    exact ⟨safe.1,safe.2.1,safe.2.2.2⟩
  | err reason => exact ⟨trivial,by intro σ _ _; trivial,by intro n; simp⟩

/-- 出力の行。応答はModelTargetsのモデルの同じ関係（単位の値、観測なし）である。 -/
theorem IORow.print {externals} : IORow (program externals) Primitive.p373.name := by
  intro Ψ sg ts es rs ws a e lookup args
  cases Option.some.inj (lookup.symm.trans (row_lookup _ .p373))
  have result := legacy_result (Or.inl rfl) args
  refine ⟨fun out obs h => ?_, ⟨_, [], io_row_to (Or.inr (Or.inl ⟨rfl, rfl, rfl⟩))⟩⟩
  rcases io_row_of h with ⟨op, _, hn, _⟩ | ⟨_, rfl, rfl⟩ | ⟨hn, _⟩ | ⟨hn, _⟩
  · cases op <;> exact absurd hn (by decide)
  · rw [result]
    exact ⟨⟨.V_Const trivial,trivial⟩, by intro σ _ _; trivial, Or.inl ⟨rfl, by intro n; simp⟩, rfl⟩
  all_goals exact absurd hn (by decide)

/-- 終了の行。応答はModelTargetsのモデルの同じ関係（引数の整数の終了、観測なし）である。 -/
theorem IORow.exit {externals} : IORow (program externals) Primitive.p372.name := by
  intro Ψ sg ts es rs ws a e lookup args
  cases Option.some.inj (lookup.symm.trans (row_lookup _ .p372))
  refine ⟨fun out obs h => ?_, ⟨_, [], io_row_to (Or.inr (Or.inr (Or.inl ⟨rfl, rfl, rfl⟩)))⟩⟩
  rcases io_row_of h with ⟨op, _, hn, _⟩ | ⟨hn, _⟩ | ⟨_, rfl, rfl⟩ | ⟨hn, _⟩
  · cases op <;> exact absurd hn (by decide)
  · exact absurd hn (by decide)
  · exact ⟨trivial, by intro σ _ _; trivial, Or.inr ⟨rfl, by intro v; simp⟩, rfl⟩
  · exact absurd hn (by decide)

private theorem readObs_kind (ws : List Val) :
    ∀ t ∈ ModelTargets.readObs ws, t.kind = .path := by
  intro t ht
  unfold ModelTargets.readObs at ht
  split at ht
  · split at ht
    · simp only [List.mem_singleton] at ht
      subst t
      rfl
    · cases ht
  · cases ht

/-- Topの対象の読取りの行。応答はModelTargetsのモデルの同じ関係（文字列か誤りの結果、解析できた
パスの観測）である。 -/
theorem IORow.readText {externals} : IORow (program externals) Primitive.p160.name := by
  intro Ψ sg ts es rs ws a e lookup args
  cases Option.some.inj (lookup.symm.trans (row_lookup _ .p160))
  have result := legacy_result (Or.inr (Or.inr rfl)) args
  refine ⟨fun out obs h => ?_,
    ⟨_, ModelTargets.readObs ws, io_row_to (Or.inr (Or.inr (Or.inr ⟨rfl, .error 0, rfl⟩)))⟩⟩
  rcases io_row_of h with ⟨op, _, hn, _⟩ | ⟨hn, _⟩ | ⟨hn, _⟩ | ⟨_, reply, rfl⟩
  · cases op <;> exact absurd hn (by decide)
  · exact absurd hn (by decide)
  · exact absurd hn (by decide)
  · rw [result]
    obtain ⟨typed, adequate, nonexit⟩ := read_safe (B := builtins (program externals)) (Ψ := Ψ) (ws := ws) (http_declarations externals).file rfl rfl reply
    refine ⟨typed, adequate, Or.inl ⟨rfl, nonexit⟩, readObs_kind ws⟩

/-- 合成表のIOと終了の全10行（範囲付きのファイル六行・Http.sendIn・print・exit・File.readText）。 -/
def Primitive.io : Primitive → Bool
  | .p157 | .p158 | .p159 | .p160 | .p161 | .p162 | .p163 | .p187 | .p372 | .p373 => true
  | _ => false

/-- IOと終了の全10行の全BuiltinArgsと全応答は、合成表の同じIO応答の関係で型付き・適格で、対象の
条件を満たし、応答が少なくとも一つある。 -/
theorem io_rows (externals : List (ExternalKey × ExternalDecl)) (row : Primitive) (io : row.io = true) :
    IORow (program externals) row.name := by
  cases row
  case p157 => exact IORow.scoped .p157 .appendBytes rfl rfl (targets_scoped _ (by decide))
  case p158 => exact IORow.scoped .p158 .appendText rfl rfl (targets_scoped _ (by decide))
  case p159 => exact IORow.scoped .p159 .readBytes rfl rfl (targets_scoped _ (by decide))
  case p160 => exact IORow.readText
  case p161 => exact IORow.scoped .p161 .readText rfl rfl (targets_scoped _ (by decide))
  case p162 => exact IORow.scoped .p162 .writeBytes rfl rfl (targets_scoped _ (by decide))
  case p163 => exact IORow.scoped .p163 .writeText rfl rfl (targets_scoped _ (by decide))
  case p187 => exact IORow.scoped .p187 .send rfl rfl http_scoped
  case p372 => exact IORow.exit
  case p373 => exact IORow.print
  all_goals cases io

/-! ## 範囲付きのパスと要求の六つの純粋な行と内部の %List.getFront -/

/-- 範囲付きのパスと要求の検査・値の取り出し・明示の拡大の行。δは同じScopeResponseのδである。 -/
theorem PureRow.scope {externals} (row : Primitive) (sg : PrimSig)
    (hentry : ScopeSignatures.entries.lookup row.name = some sg) (hsig : row.signature = sg)
    (kind : sg.kind = .pure)
    (hprovider : row.provider.delta = ScopeResponse.delta) :
    PureRow (program externals) row.name := by
  refine PureRow.of_row row (fun Ψ ts es rs ws a e args => ?_)
  rw [hsig] at args
  obtain ⟨out, delta, nonexit, typed, adequate, _⟩ := ScopeResponse.response (http_declarations externals)
    hentry kind rfl rfl rfl rfl
    (fun _ _ h => ScopeResponse.widen_admitted (Or.inl rfl) h)
    (fun _ _ h => ScopeResponse.widen_admitted (Or.inr rfl) h) args
  rw [hprovider]
  exact ⟨out, delta, typed, adequate, nonexit⟩

/-- 安全な入口の本体が呼ぶ内部の列の前からの取得の行。δは同じ %List.getFront のδである。 -/
theorem PureRow.front {P : Program} : PureRow P Primitive.p377.name :=
  PureRow.of_response .p377 (delta := StandardSafe.frontDelta) rfl rfl (fun _ _ _ _ => rfl)
    (fun _ _ _ _ _ _ _ args => StandardSafe.front_response args)

/-- 範囲付きの純粋な6行と %List.getFront。 -/
def Primitive.scopePure : Primitive → Bool
  | .p185 | .p186 | .p188 | .p281 | .p282 | .p283 | .p377 => true
  | _ => false

theorem scope_rows (externals : List (ExternalKey × ExternalDecl)) (row : Primitive)
    (pure : row.scopePure = true) : PureRow (program externals) row.name := by
  cases row
  case p185 => exact PureRow.scope .p185 _ rfl rfl rfl rfl
  case p186 => exact PureRow.scope .p186 _ rfl rfl rfl rfl
  case p188 => exact PureRow.scope .p188 _ rfl rfl rfl rfl
  case p281 => exact PureRow.scope .p281 _ rfl rfl rfl rfl
  case p282 => exact PureRow.scope .p282 _ rfl rfl rfl rfl
  case p283 => exact PureRow.scope .p283 _ rfl rfl rfl rfl
  case p377 => exact PureRow.front
  all_goals cases pure

end
end Benitoite.Release.Refinement.StandardModel
