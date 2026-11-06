import Benitoite.Release.Refinement.StandardModelPureRows

/-! # 合成表の文字列・バイト列・リスト・写像・集合の純粋な行

String・Bytes・List・Map・Setの公開モジュールの組込みの行と内部の %Map.replaceValues は、既存の
任意のP/Bの応答の補題から、行の環境（`StandardModel.RowEnv`）の表の同じlookupと同じBuiltinArgsの応答を得る。
Optionの宣言・写像の鍵の宣言表・変性の検査は行の環境が供給する。MapとSetの鍵の符号化は、宣言表の全構成子の
並びを読む（合成表では合成プログラムの全構成子の並び `constructorNames`）。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
open StandardKeyTyping StandardCollections

/-! ## 出典の表ごとの行 -/

private theorem string_delta (api : StandardStringOrdinaryResponse.API) (ts es rs ws) :
    (StandardStringOrdinaryResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> rfl

/-- Stringの切り出し・検索・分割・変換・表示幅の行。 -/
theorem PureRow.string {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (api : StandardStringOrdinaryResponse.API)
    (hname : row.name = api.name) (hsig : row.signatureWith B.sat = api.signature)
    (hprovider : row.provider.delta = (StandardStringOrdinaryResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (fun ts es rs ws => by rw [hprovider]; exact string_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardStringOrdinaryResponse.response api env.options.some_decl
      env.options.none_decl env.options.arity args)

private theorem bytesOrdinary_delta (api : StandardBytesOrdinaryResponse.API) (ts es rs ws) :
    (StandardBytesOrdinaryResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> rfl

/-- Bytesの構築・16進と2進・取得・切り出し・連結・整数の読み書きの行。 -/
theorem PureRow.bytesOrdinary {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (api : StandardBytesOrdinaryResponse.API)
    (hname : row.name = api.name) (hsig : row.signatureWith B.sat = api.signature)
    (hprovider : row.provider.delta = (StandardBytesOrdinaryResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig
    (fun ts es rs ws => by rw [hprovider]; exact bytesOrdinary_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardBytesOrdinaryResponse.response api env.options.some_decl
      env.options.none_decl env.options.arity args)

private theorem bytes_delta (api : StandardBytesResponse.API) (ts es rs ws) :
    (StandardBytesResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> simp [StandardBytesResponse.table, StandardBytesResponse.API.name, StandardBytesResponse.API.delta]

/-- Stringのバイト数・文字数とBytesの長さ・Listとの変換の行。 -/
theorem PureRow.bytes {P : Program} {B : Builtins} [RowLookup B] (row : Primitive) (api : StandardBytesResponse.API)
    (hname : row.name = api.name) (hsig : row.signatureWith B.sat = api.signature)
    (hprovider : row.provider.delta = (StandardBytesResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (delta := api.delta)
    (fun ts es rs ws => by rw [hprovider]; exact bytes_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => by
      obtain ⟨out, delta, typed, adequate, nonexit, _⟩ := StandardBytesResponse.related_response api args
      exact ⟨out, delta, typed, adequate, nonexit⟩)

private theorem listRemaining_delta (api : StandardListRemainingResponse.API) (ts es rs ws) :
    (StandardListRemainingResponse.table signatureBase).delta api.name ts es rs ws =
      StandardListRemainingResponse.delta api api.name ts es rs ws := by
  cases api <;> rfl

/-- Listの取得・切り出し・所属・整列の行。 -/
theorem PureRow.listRemaining {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (api : StandardListRemainingResponse.API)
    (hname : row.name = api.name)
    (hsig : row.signatureWith B.sat = StandardListRemainingResponse.API.signature B.sat api)
    (hprovider : row.provider.delta = (StandardListRemainingResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig
    (fun ts es rs ws => by rw [hprovider]; exact listRemaining_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardListRemainingResponse.response api
      env.options.some_decl env.options.none_decl
      env.options.arity args)

/-- 整数の区間のListの行。 -/
theorem PureRow.range {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (hname : row.name = "List.range")
    (hsig : row.signatureWith B.sat = StandardListRemainingResponse.rangeSignature)
    (hprovider : row.provider.delta = (StandardListRemainingResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (fun ts es rs ws => by rw [hprovider]; rfl)
    (fun _ _ _ _ _ _ _ args => StandardListRemainingResponse.range_response
      env.options.some_decl env.options.none_decl
      env.options.arity args)

private theorem list_delta (api : StandardListResponse.API) (ts es rs ws) :
    (StandardListResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> simp [StandardListResponse.table, StandardListResponse.API.name, StandardListResponse.API.delta]

/-- Listの長さ・空判定・前置き・連結・反転の行。 -/
theorem PureRow.list {P : Program} {B : Builtins} [RowLookup B] (row : Primitive) (api : StandardListResponse.API)
    (hname : row.name = api.name) (hsig : row.signatureWith B.sat = api.signature)
    (hprovider : row.provider.delta = (StandardListResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (delta := api.delta)
    (fun ts es rs ws => by rw [hprovider]; exact list_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => by
      obtain ⟨out, delta, typed, adequate, nonexit, _⟩ := StandardListResponse.related_response api args
      exact ⟨out, delta, typed, adequate, nonexit⟩)

/-- Listの先頭と残り（精密な署名）の行。 -/
theorem PureRow.headTail {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (tail : Bool)
    (hname : row.name = if tail then "List.tail" else "List.head")
    (hsig : row.signatureWith B.sat = (StandardHeadTail.builtins.sig (if tail then "List.tail" else "List.head")).get
      (by cases tail <;> rfl))
    (hprovider : row.provider.delta = StandardHeadTail.builtins.delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name := by
  refine PureRow.of_row (hrow := hrow) row (fun Ψ ts es rs ws a e args => ?_)
  rw [hname] at args ⊢
  rw [hsig] at args
  rw [hprovider]
  cases tail
  · exact StandardHeadTail.option_response false env.options.some_decl
      env.options.none_decl env.options.arity args
  · exact StandardHeadTail.option_response true env.options.some_decl
      env.options.none_decl env.options.arity args

/-- Listの末尾への追加（精密な署名）の行。 -/
theorem PureRow.append {P : Program} {B : Builtins} [RowLookup B] (row : Primitive) (hname : row.name = "List.append")
    (hsig : row.signatureWith B.sat = StandardHeadTail.appendSignature)
    (hprovider : row.provider.delta = StandardHeadTail.builtins.delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (fun ts es rs ws => by rw [hprovider]; rfl)
    (fun _ _ _ _ _ _ _ args => StandardHeadTail.append_response args)

/-- Mapの構築・取得・更新・大きさ・鍵と値の列の行。δは宣言表の構成子の並びで鍵を読む。 -/
theorem PureRow.map {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive)
    (api : StandardCollections.MapAPI) (hname : row.name = api.name)
    (hsig : row.signatureWith B.sat = StandardCollections.MapAPI.signature B.sat api)
    (hprovider : (fun cs => row.deltaWith cs) = collectionDelta) :
    PureRowOn P B row.name :=
  PureRow.of_keys row (fun Ψ ts es rs ws a e args => by
    rw [hname, hsig] at args
    rw [show ∀ cs, row.deltaWith cs = collectionDelta cs from fun cs => congrFun hprovider cs, hname]
    obtain ⟨out, h, rest⟩ := StandardCollections.map_api_response api env.keys env.valid env.mapSet args
    refine ⟨out, ?_, rest⟩
    cases api <;> simpa [collectionDelta, StandardCollections.MapAPI.name] using h)

/-- Setの構築・所属・更新・大きさ・集合演算の行。δは宣言表の構成子の並びで鍵を読む。 -/
theorem PureRow.set {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive)
    (api : StandardCollections.SetAPI) (hname : row.name = api.name)
    (hsig : row.signatureWith B.sat = StandardCollections.SetAPI.signature B.sat api)
    (hprovider : (fun cs => row.deltaWith cs) = collectionDelta) :
    PureRowOn P B row.name :=
  PureRow.of_keys row (fun Ψ ts es rs ws a e args => by
    rw [hname, hsig] at args
    rw [show ∀ cs, row.deltaWith cs = collectionDelta cs from fun cs => congrFun hprovider cs, hname]
    obtain ⟨out, h, rest⟩ := StandardCollections.set_api_response api env.keys env.valid args
    refine ⟨out, ?_, rest⟩
    cases api <;> simpa [collectionDelta, StandardCollections.SetAPI.name] using h)

/-- MapとSetのListとの変換（精密な署名）の行。δは宣言表の構成子の並びで鍵を読む。 -/
theorem PureRow.precision {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (map build : Bool)
    (hname : row.name = StandardCollectionPrecision.name map build)
    (hsig : row.signatureWith B.sat = StandardCollectionPrecision.signature B.sat map build)
    (hprovider : (fun cs => row.deltaWith cs) = precisionDelta) :
    PureRowOn P B row.name :=
  PureRow.of_keys row (fun Ψ ts es rs ws a e args => by
    rw [hname, hsig] at args
    rw [show ∀ cs, row.deltaWith cs = precisionDelta cs from fun cs => congrFun hprovider cs, hname]
    cases map
    · obtain ⟨out, h, rest⟩ := StandardCollectionPrecision.set_response build env.keys env.valid args
      refine ⟨out, ?_, rest⟩
      cases build <;> simpa [precisionDelta, StandardCollectionPrecision.name] using h
    · obtain ⟨out, h, rest⟩ := StandardCollectionPrecision.map_response build env.keys env.valid env.mapSet args
      refine ⟨out, ?_, rest⟩
      cases build <;> simpa [precisionDelta, StandardCollectionPrecision.name] using h)

/-- 精密な写像の値の置き換え（内部の名前）の行。δは宣言表の構成子の並びで鍵を読む。 -/
theorem PureRow.replaceValues {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive)
    (hname : row.name = "%Map.replaceValues")
    (hsig : row.signatureWith B.sat = StandardMapReplaceValues.signature B.sat)
    (hprovider : (fun cs => row.deltaWith cs) = precisionDelta) :
    PureRowOn P B row.name :=
  PureRow.of_keys row (fun Ψ ts es rs ws a e args => by
    rw [hname, hsig] at args
    rw [show ∀ cs, row.deltaWith cs = precisionDelta cs from fun cs => congrFun hprovider cs, hname]
    obtain ⟨out, h, rest⟩ := StandardMapReplaceValues.response env.keys env.valid env.mapSet args
    exact ⟨out, by simpa [precisionDelta] using h, rest⟩)

/-- String・Bytes・List・Map・Setの公開モジュールの組込みの行と、内部の %Map.replaceValues。 -/
def Primitive.collection : Primitive → Bool
  | .p076 | .p120 | .p121 | .p122 | .p123 | .p124 | .p125 | .p126 | .p127 | .p128 | .p129 | .p130 | .p131 | .p132 | .p133 | .p134 | .p135 | .p255 | .p256 | .p257 | .p258 | .p259 | .p260 | .p261 | .p262 | .p263 | .p264 | .p265 | .p266 | .p267 | .p268 | .p269 | .p270 | .p271 | .p272 | .p273 | .p274 | .p275 | .p276 | .p277 | .p278 | .p284 | .p285 | .p286 | .p287 | .p288 | .p289 | .p290 | .p291 | .p292 | .p293 | .p294 | .p295 | .p296 | .p297 | .p298 | .p299 | .p300 | .p301 | .p302 | .p303 | .p304 | .p305 | .p306 | .p307 | .p308 | .p309 | .p310 | .p311 | .p312 | .p313 | .p314 | .p315 | .p316 | .p317 | .p318 | .p319 | .p320 | .p321 => true
  | _ => false

/-- String・Bytes・List・Map・Setの全79行の全BuiltinArgsは、合成表の同じlookupで型付きの非exitの応答を持つ。 -/
theorem collection_rows_of {P : Program} {B : Builtins} [RowEnv P B] (row : Primitive)
    (collection : row.collection = true) : PureRowOn P B row.name := by
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

theorem collection_rows (externals : List (ExternalKey × ExternalDecl)) (row : Primitive)
    (collection : row.collection = true) : PureRow (program externals) row.name :=
  collection_rows_of row collection

/-- 鍵の符号化に全構成子の並びを読むMap.getと、精密なMap.toListの行。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    PureRow (program externals) "Map.get" ∧ PureRow (program externals) "Map.toList" :=
  ⟨collection_rows externals .p272 rfl, collection_rows externals .p277 rfl⟩

end
end Benitoite.Release.Refinement.StandardModel
