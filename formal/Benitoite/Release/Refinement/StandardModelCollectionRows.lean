import Benitoite.Release.Refinement.StandardModelPureRows

/-! # 合成表の文字列・バイト列・リスト・写像・集合の純粋な行

String・Bytes・List・Map・Setの公開モジュールの組込みの行と内部の %Map.replaceValues は、既存の
任意のP/Bの応答の補題から、合成表の同じlookupと同じBuiltinArgsの応答を得る。Optionの宣言・
写像の鍵の宣言表・変性の検査は合成プログラムが供給する。MapとSetの鍵の符号化は、合成プログラムの
全構成子の並び（`constructorNames`）を読む。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
open StandardKeyTyping StandardCollections

/-- 合成プログラムの宣言表は、合成表の制約の判定と同じ要約を持つ。 -/
def table (externals : List (ExternalKey × ExternalDecl)) :
    StandardKeyTyping.Table (program externals) (builtins (program externals)) :=
  ⟨declarations, by decide, by decide, rfl, by decide, fun _ _ _ => Iff.rfl⟩

/-- 合成プログラムの構成子のlookupの結果は、合成プログラムの構成子の並びに入る。 -/
theorem cons_mem {externals c cd} (h : (program externals).cons c = some cd) :
    (c, cd) ∈ constructors := by
  change constructors.lookup c = some cd at h
  obtain ⟨before, after, eq, _⟩ := List.lookup_eq_some_iff.mp h
  rw [eq]
  exact List.mem_append_right _ List.mem_cons_self

/-- 合成プログラムは変性の情報を持たない。 -/
theorem dataInfo_none (externals : List (ExternalKey × ExternalDecl)) (d : String) :
    (program externals).dataInfo d = none := rfl

/-- 合成プログラムは変性の情報を持たず、全構成子の欄は整形式で既定の変性を満たす。 -/
theorem variance_valid (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).VarianceValid := by
  have http := http_declarations externals
  have pair : (program externals).DataArity "Pair" 2 :=
    (http ScopeDeclarations.pair (by simp [ScopeDeclarations.http])).1
  have scope : (program externals).DataArity "Scope.ScopeError" 0 :=
    (http ScopeDeclarations.scopeError (by simp [ScopeDeclarations.http, ScopeDeclarations.file])).1
  have pairK := TyCon.arity_data pair
  have scopeK := TyCon.arity_data scope
  have pub := http.scopePublic
  constructor
  · intro d info h; cases h
  · intro c cd h
    rcases (constructors_split (cons_mem h)).symm with mem | mem
    · obtain ⟨hn, _, as, hargs, hk⟩ := ScopeDeclarations.public_entry mem
      constructor
      · intro info h; cases h
      · intro a ha
        rw [hargs] at ha
        obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
        rw [hn]
        exact ⟨b.annotation pub _ _ (hk b hb), b.kind pub _ (hk b hb), b.varianceOK _ _ _⟩
    simp only [baseDeclarations, byteOrder, roundingMode, StandardOrdinaryCoreBodies.declarations,
      ScopeDeclarations.base, ScopeDeclarations.file, ScopeDeclarations.result, ScopeDeclarations.scopeError,
      ScopeDeclarations.pair, ScopeDeclarations.clientRequest, ScopeDeclarations.requestCheckError,
      StandardOrdinaryCoreBodies.Record.owner, StandardOrdinaryCoreBodies.Record.fields,
      StandardSafe.names] at mem
    simp (config := {decide := true}) [List.filter, StandardKeyTyping.DataDecl.entries] at mem
    repeat' (rcases mem with ⟨rfl, rfl⟩ | mem)
    all_goals try (obtain ⟨rfl, rfl⟩ := mem)
    all_goals subst_vars
    all_goals
      constructor
      · intro info h; cases h
      · intro a ha
        try (simp at ha; done)
        try simp only [atErrorFields, List.mem_cons, List.not_mem_nil, or_false] at ha
        repeat' (rcases ha with rfl | ha)
        all_goals first
          | exact ⟨ScopePublic.PublicTy.annotation pub _ _ (a := .data "Scope.AtDetail") (by decide),
              ScopePublic.PublicTy.kind pub _ (.data "Scope.AtDetail") (by decide),
              ScopePublic.PublicTy.varianceOK _ _ (.data "Scope.AtDetail") _⟩
          | skip
        all_goals
          refine ⟨⟨?_, ?_, ?_⟩, ?_, ?_⟩ <;>
            try simp [Ty.WF, Ty.Sorted, Ty.Declared, Ty.HasKind, TypeCtx.valueParam, Ty.VarianceOK,
              Program.varianceFor, Variance.accepts, atErrorType, declaredTys, Ty.WFList, sortedTys,
              kindsList, varianceArgsOK, dataInfo_none, pair, scope, pairK, scopeK]

/-- 合成プログラムはMapとSetの応答が読むPairとOptionの宣言を持つ。 -/
theorem map_set_declarations (externals : List (ExternalKey × ExternalDecl)) :
    StandardCollections.MapSetDeclarations (program externals) := by
  have http := http_declarations externals
  have options := option_declarations externals
  have pair : (program externals).DataArity "Pair" 2 :=
    (http ScopeDeclarations.pair (by simp [ScopeDeclarations.http])).1
  refine ⟨rfl, pair, ?_, options.some_decl, options.none_decl, options.arity⟩
  intro c cd h owner
  rcases (constructors_split (cons_mem h)).symm with mem | mem
  · obtain ⟨_, hd, _⟩ := ScopeDeclarations.public_entry mem
    exact absurd owner (ScopeDeclarations.public_not_option _ hd).2.1
  simp only [baseDeclarations, byteOrder, roundingMode, StandardOrdinaryCoreBodies.declarations,
    ScopeDeclarations.base, ScopeDeclarations.file, ScopeDeclarations.result, ScopeDeclarations.scopeError,
    ScopeDeclarations.pair, ScopeDeclarations.clientRequest, ScopeDeclarations.requestCheckError,
    StandardOrdinaryCoreBodies.Record.owner, StandardOrdinaryCoreBodies.Record.fields,
    StandardSafe.names] at mem
  simp (config := {decide := true}) [List.filter, StandardKeyTyping.DataDecl.entries] at mem
  repeat' (rcases mem with ⟨rfl, rfl⟩ | mem)
  all_goals try (obtain ⟨rfl, rfl⟩ := mem)
  all_goals simp_all

/-! ## 出典の表ごとの行 -/

private theorem string_delta (api : StandardStringOrdinaryResponse.API) (ts es rs ws) :
    (StandardStringOrdinaryResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> rfl

/-- Stringの切り出し・検索・分割・変換・表示幅の行。 -/
theorem PureRow.string {externals} (row : Primitive) (api : StandardStringOrdinaryResponse.API)
    (hname : row.name = api.name) (hsig : row.signature = api.signature)
    (hprovider : row.provider.delta = (StandardStringOrdinaryResponse.table signatureBase).delta) :
    PureRow (program externals) row.name :=
  PureRow.of_response row hname hsig (fun ts es rs ws => by rw [hprovider]; exact string_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardStringOrdinaryResponse.response api (option_declarations externals).some_decl
      (option_declarations externals).none_decl (option_declarations externals).arity args)

private theorem bytesOrdinary_delta (api : StandardBytesOrdinaryResponse.API) (ts es rs ws) :
    (StandardBytesOrdinaryResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> rfl

/-- Bytesの構築・16進と2進・取得・切り出し・連結・整数の読み書きの行。 -/
theorem PureRow.bytesOrdinary {externals} (row : Primitive) (api : StandardBytesOrdinaryResponse.API)
    (hname : row.name = api.name) (hsig : row.signature = api.signature)
    (hprovider : row.provider.delta = (StandardBytesOrdinaryResponse.table signatureBase).delta) :
    PureRow (program externals) row.name :=
  PureRow.of_response row hname hsig
    (fun ts es rs ws => by rw [hprovider]; exact bytesOrdinary_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardBytesOrdinaryResponse.response api (option_declarations externals).some_decl
      (option_declarations externals).none_decl (option_declarations externals).arity args)

private theorem bytes_delta (api : StandardBytesResponse.API) (ts es rs ws) :
    (StandardBytesResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> simp [StandardBytesResponse.table, StandardBytesResponse.API.name, StandardBytesResponse.API.delta]

/-- Stringのバイト数・文字数とBytesの長さ・Listとの変換の行。 -/
theorem PureRow.bytes {P : Program} (row : Primitive) (api : StandardBytesResponse.API)
    (hname : row.name = api.name) (hsig : row.signature = api.signature)
    (hprovider : row.provider.delta = (StandardBytesResponse.table signatureBase).delta) :
    PureRow P row.name :=
  PureRow.of_response row hname hsig (delta := api.delta)
    (fun ts es rs ws => by rw [hprovider]; exact bytes_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => by
      obtain ⟨out, delta, typed, adequate, nonexit, _⟩ := StandardBytesResponse.related_response api args
      exact ⟨out, delta, typed, adequate, nonexit⟩)

private theorem listRemaining_delta (api : StandardListRemainingResponse.API) (ts es rs ws) :
    (StandardListRemainingResponse.table signatureBase).delta api.name ts es rs ws =
      StandardListRemainingResponse.delta api api.name ts es rs ws := by
  cases api <;> rfl

/-- Listの取得・切り出し・所属・整列の行。 -/
theorem PureRow.listRemaining {externals} (row : Primitive) (api : StandardListRemainingResponse.API)
    (hname : row.name = api.name)
    (hsig : row.signature = StandardListRemainingResponse.API.signature signatureBase.sat api)
    (hprovider : row.provider.delta = (StandardListRemainingResponse.table signatureBase).delta) :
    PureRow (program externals) row.name :=
  PureRow.of_response row hname hsig
    (fun ts es rs ws => by rw [hprovider]; exact listRemaining_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardListRemainingResponse.response api
      (option_declarations externals).some_decl (option_declarations externals).none_decl
      (option_declarations externals).arity args)

/-- 整数の区間のListの行。 -/
theorem PureRow.range {externals} (row : Primitive) (hname : row.name = "List.range")
    (hsig : row.signature = StandardListRemainingResponse.rangeSignature)
    (hprovider : row.provider.delta = (StandardListRemainingResponse.table signatureBase).delta) :
    PureRow (program externals) row.name :=
  PureRow.of_response row hname hsig (fun ts es rs ws => by rw [hprovider]; rfl)
    (fun _ _ _ _ _ _ _ args => StandardListRemainingResponse.range_response
      (option_declarations externals).some_decl (option_declarations externals).none_decl
      (option_declarations externals).arity args)

private theorem list_delta (api : StandardListResponse.API) (ts es rs ws) :
    (StandardListResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> simp [StandardListResponse.table, StandardListResponse.API.name, StandardListResponse.API.delta]

/-- Listの長さ・空判定・前置き・連結・反転の行。 -/
theorem PureRow.list {P : Program} (row : Primitive) (api : StandardListResponse.API)
    (hname : row.name = api.name) (hsig : row.signature = api.signature)
    (hprovider : row.provider.delta = (StandardListResponse.table signatureBase).delta) :
    PureRow P row.name :=
  PureRow.of_response row hname hsig (delta := api.delta)
    (fun ts es rs ws => by rw [hprovider]; exact list_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => by
      obtain ⟨out, delta, typed, adequate, nonexit, _⟩ := StandardListResponse.related_response api args
      exact ⟨out, delta, typed, adequate, nonexit⟩)

/-- Listの先頭と残り（精密な署名）の行。 -/
theorem PureRow.headTail {externals} (row : Primitive) (tail : Bool)
    (hname : row.name = if tail then "List.tail" else "List.head")
    (hsig : row.signature = (StandardHeadTail.builtins.sig (if tail then "List.tail" else "List.head")).get
      (by cases tail <;> rfl))
    (hprovider : row.provider.delta = StandardHeadTail.builtins.delta) :
    PureRow (program externals) row.name := by
  refine PureRow.of_row row (fun Ψ ts es rs ws a e args => ?_)
  rw [hname] at args ⊢
  rw [hsig] at args
  rw [hprovider]
  cases tail
  · exact StandardHeadTail.option_response false (option_declarations externals).some_decl
      (option_declarations externals).none_decl (option_declarations externals).arity args
  · exact StandardHeadTail.option_response true (option_declarations externals).some_decl
      (option_declarations externals).none_decl (option_declarations externals).arity args

/-- Listの末尾への追加（精密な署名）の行。 -/
theorem PureRow.append {P : Program} (row : Primitive) (hname : row.name = "List.append")
    (hsig : row.signature = StandardHeadTail.appendSignature)
    (hprovider : row.provider.delta = StandardHeadTail.builtins.delta) :
    PureRow P row.name :=
  PureRow.of_response row hname hsig (fun ts es rs ws => by rw [hprovider]; rfl)
    (fun _ _ _ _ _ _ _ args => StandardHeadTail.append_response args)

/-- Mapの構築・取得・更新・大きさ・鍵と値の列の行。 -/
theorem PureRow.map {externals} (row : Primitive) (api : StandardCollections.MapAPI)
    (hname : row.name = api.name)
    (hsig : row.signature = StandardCollections.MapAPI.signature signatureBase.sat api)
    (hprovider : row.provider.delta = collectionProvider.delta) :
    PureRow (program externals) row.name :=
  PureRow.of_response row hname hsig
    (fun ts es rs ws => by
      rw [hprovider]
      cases api <;> simp [collectionProvider, StandardCollections.MapAPI.name] <;> rfl)
    (fun _ _ _ _ _ _ _ args => StandardCollections.map_api_response api (table externals)
      (variance_valid externals) (map_set_declarations externals) args)

/-- Setの構築・所属・更新・大きさ・集合演算の行。 -/
theorem PureRow.set {externals} (row : Primitive) (api : StandardCollections.SetAPI)
    (hname : row.name = api.name)
    (hsig : row.signature = StandardCollections.SetAPI.signature signatureBase.sat api)
    (hprovider : row.provider.delta = collectionProvider.delta) :
    PureRow (program externals) row.name :=
  PureRow.of_response row hname hsig
    (fun ts es rs ws => by
      rw [hprovider]
      cases api <;> simp [collectionProvider, StandardCollections.SetAPI.name] <;> rfl)
    (fun _ _ _ _ _ _ _ args => StandardCollections.set_api_response api (table externals)
      (variance_valid externals) args)

/-- MapとSetのListとの変換（精密な署名）の行。 -/
theorem PureRow.precision {externals} (row : Primitive) (map build : Bool)
    (hname : row.name = StandardCollectionPrecision.name map build)
    (hsig : row.signature = StandardCollectionPrecision.signature signatureBase.sat map build)
    (hprovider : row.provider.delta = precisionProvider.delta) :
    PureRow (program externals) row.name := by
  refine PureRow.of_row row (fun Ψ ts es rs ws a e args => ?_)
  rw [hname] at args ⊢
  rw [hsig] at args
  rw [hprovider]
  cases map
  · obtain ⟨out, delta, rest⟩ :=
      StandardCollectionPrecision.set_response build (table externals) (variance_valid externals) args
    refine ⟨out, ?_, rest⟩
    cases build <;> simp [precisionProvider, StandardCollectionPrecision.name] <;> exact delta
  · obtain ⟨out, delta, rest⟩ := StandardCollectionPrecision.map_response build (table externals)
      (variance_valid externals) (map_set_declarations externals) args
    refine ⟨out, ?_, rest⟩
    cases build <;> simp [precisionProvider, StandardCollectionPrecision.name] <;> exact delta

/-- 精密な写像の値の置き換え（内部の名前）の行。 -/
theorem PureRow.replaceValues {externals} (row : Primitive) (hname : row.name = "%Map.replaceValues")
    (hsig : row.signature = StandardMapReplaceValues.signature signatureBase.sat)
    (hprovider : row.provider.delta = precisionProvider.delta) :
    PureRow (program externals) row.name :=
  PureRow.of_response row hname hsig (fun ts es rs ws => by rw [hprovider]; rfl)
    (fun _ _ _ _ _ _ _ args => StandardMapReplaceValues.response (table externals) (variance_valid externals)
      (map_set_declarations externals) args)

/-- String・Bytes・List・Map・Setの公開モジュールの組込みの行と、内部の %Map.replaceValues。 -/
def Primitive.collection : Primitive → Bool
  | .p076 | .p120 | .p121 | .p122 | .p123 | .p124 | .p125 | .p126 | .p127 | .p128 | .p129 | .p130 | .p131 | .p132 | .p133 | .p134 | .p135 | .p255 | .p256 | .p257 | .p258 | .p259 | .p260 | .p261 | .p262 | .p263 | .p264 | .p265 | .p266 | .p267 | .p268 | .p269 | .p270 | .p271 | .p272 | .p273 | .p274 | .p275 | .p276 | .p277 | .p278 | .p284 | .p285 | .p286 | .p287 | .p288 | .p289 | .p290 | .p291 | .p292 | .p293 | .p294 | .p295 | .p296 | .p297 | .p298 | .p299 | .p300 | .p301 | .p302 | .p303 | .p304 | .p305 | .p306 | .p307 | .p308 | .p309 | .p310 | .p311 | .p312 | .p313 | .p314 | .p315 | .p316 | .p317 | .p318 | .p319 | .p320 | .p321 => true
  | _ => false

/-- String・Bytes・List・Map・Setの全79行の全BuiltinArgsは、合成表の同じlookupで型付きの非exitの応答を持つ。 -/
theorem collection_rows (externals : List (ExternalKey × ExternalDecl)) (row : Primitive)
    (collection : row.collection = true) : PureRow (program externals) row.name := by
  cases row
  case p076 => exact PureRow.replaceValues .p076 rfl rfl rfl
  case p120 => exact PureRow.bytesOrdinary .p120 .concatenate rfl rfl rfl
  case p121 => exact PureRow.bytesOrdinary .p121 .empty rfl rfl rfl
  case p122 => exact PureRow.bytesOrdinary .p122 .fromBinary rfl rfl rfl
  case p123 => exact PureRow.bytesOrdinary .p123 .fromHex rfl rfl rfl
  case p124 => exact PureRow.bytesOrdinary .p124 .fromIntegers rfl rfl rfl
  case p125 => exact PureRow.bytes .p125 .bytesFromList rfl rfl rfl
  case p126 => exact PureRow.bytesOrdinary .p126 .fromSigned rfl rfl rfl
  case p127 => exact PureRow.bytesOrdinary .p127 .fromUnsigned rfl rfl rfl
  case p128 => exact PureRow.bytesOrdinary .p128 .get rfl rfl rfl
  case p129 => exact PureRow.bytes .p129 .bytesLength rfl rfl rfl
  case p130 => exact PureRow.bytesOrdinary .p130 .readSigned rfl rfl rfl
  case p131 => exact PureRow.bytesOrdinary .p131 .readUnsigned rfl rfl rfl
  case p132 => exact PureRow.bytesOrdinary .p132 .slice rfl rfl rfl
  case p133 => exact PureRow.bytesOrdinary .p133 .toBinary rfl rfl rfl
  case p134 => exact PureRow.bytesOrdinary .p134 .toHex rfl rfl rfl
  case p135 => exact PureRow.bytes .p135 .bytesToList rfl rfl rfl
  case p255 => exact PureRow.append .p255 rfl rfl rfl
  case p256 => exact PureRow.list .p256 .concatenate rfl rfl rfl
  case p257 => exact PureRow.listRemaining .p257 .contains rfl rfl rfl
  case p258 => exact PureRow.listRemaining .p258 .drop rfl rfl rfl
  case p259 => exact PureRow.listRemaining .p259 .get rfl rfl rfl
  case p260 => exact PureRow.headTail .p260 false rfl rfl rfl
  case p261 => exact PureRow.list .p261 .isEmpty rfl rfl rfl
  case p262 => exact PureRow.list .p262 .length rfl rfl rfl
  case p263 => exact PureRow.list .p263 .prepend rfl rfl rfl
  case p264 => exact PureRow.range .p264 rfl rfl rfl
  case p265 => exact PureRow.list .p265 .reverse rfl rfl rfl
  case p266 => exact PureRow.listRemaining .p266 .sort rfl rfl rfl
  case p267 => exact PureRow.headTail .p267 true rfl rfl rfl
  case p268 => exact PureRow.listRemaining .p268 .take rfl rfl rfl
  case p269 => exact PureRow.map .p269 .contains rfl rfl rfl
  case p270 => exact PureRow.map .p270 .empty rfl rfl rfl
  case p271 => exact PureRow.precision .p271 true true rfl rfl rfl
  case p272 => exact PureRow.map .p272 .get rfl rfl rfl
  case p273 => exact PureRow.map .p273 .keys rfl rfl rfl
  case p274 => exact PureRow.map .p274 .remove rfl rfl rfl
  case p275 => exact PureRow.map .p275 .set rfl rfl rfl
  case p276 => exact PureRow.map .p276 .size rfl rfl rfl
  case p277 => exact PureRow.precision .p277 true false rfl rfl rfl
  case p278 => exact PureRow.map .p278 .values rfl rfl rfl
  case p284 => exact PureRow.set .p284 .add rfl rfl rfl
  case p285 => exact PureRow.set .p285 .contains rfl rfl rfl
  case p286 => exact PureRow.set .p286 .difference rfl rfl rfl
  case p287 => exact PureRow.set .p287 .empty rfl rfl rfl
  case p288 => exact PureRow.precision .p288 false true rfl rfl rfl
  case p289 => exact PureRow.set .p289 .intersection rfl rfl rfl
  case p290 => exact PureRow.set .p290 .remove rfl rfl rfl
  case p291 => exact PureRow.set .p291 .size rfl rfl rfl
  case p292 => exact PureRow.precision .p292 false false rfl rfl rfl
  case p293 => exact PureRow.set .p293 .union rfl rfl rfl
  case p294 => exact PureRow.string .p294 .byteIndexOf rfl rfl rfl
  case p295 => exact PureRow.bytes .p295 .stringBytes rfl rfl rfl
  case p296 => exact PureRow.string .p296 .byteSlice rfl rfl rfl
  case p297 => exact PureRow.string .p297 .characterAt rfl rfl rfl
  case p298 => exact PureRow.bytes .p298 .stringCharacters rfl rfl rfl
  case p299 => exact PureRow.string .p299 .characterSlice rfl rfl rfl
  case p300 => exact PureRow.string .p300 .characters rfl rfl rfl
  case p301 => exact PureRow.string .p301 .contains rfl rfl rfl
  case p302 => exact PureRow.string .p302 .displayWidth rfl rfl rfl
  case p303 => exact PureRow.string .p303 .displayWidthCJK rfl rfl rfl
  case p304 => exact PureRow.string .p304 .displayWidthPadEnd rfl rfl rfl
  case p305 => exact PureRow.string .p305 .displayWidthPadEndCJK rfl rfl rfl
  case p306 => exact PureRow.string .p306 .displayWidthPadStart rfl rfl rfl
  case p307 => exact PureRow.string .p307 .displayWidthPadStartCJK rfl rfl rfl
  case p308 => exact PureRow.string .p308 .endsWith rfl rfl rfl
  case p309 => exact PureRow.string .p309 .fromCharacters rfl rfl rfl
  case p310 => exact PureRow.string .p310 .fromUTF8 rfl rfl rfl
  case p311 => exact PureRow.string .p311 .isEmpty rfl rfl rfl
  case p312 => exact PureRow.string .p312 .join rfl rfl rfl
  case p313 => exact PureRow.string .p313 .lines rfl rfl rfl
  case p314 => exact PureRow.string .p314 .repeat rfl rfl rfl
  case p315 => exact PureRow.string .p315 .replace rfl rfl rfl
  case p316 => exact PureRow.string .p316 .split rfl rfl rfl
  case p317 => exact PureRow.string .p317 .startsWith rfl rfl rfl
  case p318 => exact PureRow.string .p318 .toLowercase rfl rfl rfl
  case p319 => exact PureRow.string .p319 .toUTF8 rfl rfl rfl
  case p320 => exact PureRow.string .p320 .toUppercase rfl rfl rfl
  case p321 => exact PureRow.string .p321 .trim rfl rfl rfl
  all_goals cases collection

/-- 鍵の符号化に全構成子の並びを読むMap.getと、精密なMap.toListの行。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    PureRow (program externals) "Map.get" ∧ PureRow (program externals) "Map.toList" :=
  ⟨collection_rows externals .p272 rfl, collection_rows externals .p277 rfl⟩

end
end Benitoite.Release.Refinement.StandardModel
