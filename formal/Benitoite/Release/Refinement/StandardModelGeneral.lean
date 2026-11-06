import Benitoite.Release.Refinement.StandardModelResponse
import Benitoite.Release.Refinement.ProgramExtensionTransport

/-! # 合成表の行を任意の表で述べるための土台

合成表の行の証明は、行の名前の lookup・δ・IO 応答と、プログラムの共有の宣言（Option・Result・Pair・要求・丸め方式・
写像の鍵の宣言表と変性の検査）だけを読む。これらを満たす任意のプログラムと組込みの表で行の契約を述べるため、
行の lookup の条件（`RowLookup`）と、宣言の条件（`RowEnv`）を置く（設計書 07-04「01-12 との対応」）。

型の制約（等値・鍵）の判定を読む28行（`%Map.replaceValues` 1・等号と不等号2・List 5・Map 10・Set 10）の署名は、表の
制約の判定で作る（`Primitive.signatureWith`）。この28は信頼条件の29条件とは別の数である。合成表の制約の
判定は合成プログラムの宣言の要約であり、利用者のプログラムの表では利用者のプログラムの全宣言の要約である。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
open StandardKeyTyping StandardCollections

/-- 行の署名を、型の制約の判定 sat で作る。制約を読む28行だけが sat に依り、他の行は合成表の署名である。 -/
def Primitive.signatureWith (sat : List TParam → Ty → TParam → Prop) : Primitive → PrimSig
  | .p076 => StandardMapReplaceValues.signature sat
  | .p109 => StandardEqualityResponse.fullSignature sat
  | .p110 => StandardEqualityResponse.fullSignature sat
  | .p257 => StandardListRemainingResponse.API.signature sat .contains
  | .p258 => StandardListRemainingResponse.API.signature sat .drop
  | .p259 => StandardListRemainingResponse.API.signature sat .get
  | .p266 => StandardListRemainingResponse.API.signature sat .sort
  | .p268 => StandardListRemainingResponse.API.signature sat .take
  | .p269 => MapAPI.signature sat .contains
  | .p270 => MapAPI.signature sat .empty
  | .p271 => StandardCollectionPrecision.signature sat true true
  | .p272 => MapAPI.signature sat .get
  | .p273 => MapAPI.signature sat .keys
  | .p274 => MapAPI.signature sat .remove
  | .p275 => MapAPI.signature sat .set
  | .p276 => MapAPI.signature sat .size
  | .p277 => StandardCollectionPrecision.signature sat true false
  | .p278 => MapAPI.signature sat .values
  | .p284 => SetAPI.signature sat .add
  | .p285 => SetAPI.signature sat .contains
  | .p286 => SetAPI.signature sat .difference
  | .p287 => SetAPI.signature sat .empty
  | .p288 => StandardCollectionPrecision.signature sat false true
  | .p289 => SetAPI.signature sat .intersection
  | .p290 => SetAPI.signature sat .remove
  | .p291 => SetAPI.signature sat .size
  | .p292 => StandardCollectionPrecision.signature sat false false
  | .p293 => SetAPI.signature sat .union
  | row => row.signature

/-- 署名の許容が制約の判定を読む28行。 -/
def Primitive.readsSat : Primitive → Bool
  | .p076 | .p109 | .p110 | .p257 | .p258 | .p259 | .p266 | .p268 | .p269 | .p270 | .p271 | .p272 | .p273
  | .p274 | .p275 | .p276 | .p277 | .p278 | .p284 | .p285 | .p286 | .p287 | .p288 | .p289 | .p290 | .p291
  | .p292 | .p293 => true
  | _ => false

theorem Primitive.signatureWith_of_not_readsSat {row : Primitive} (h : row.readsSat = false)
    (sat : List TParam → Ty → TParam → Prop) : row.signatureWith sat = row.signature := by
  cases row <;> first | rfl | (exfalso; revert h; decide)

/-- 合成表の制約の判定で作った署名は、合成表の署名である。 -/
theorem Primitive.signatureWith_base (row : Primitive) : row.signatureWith signatureBase.sat = row.signature := by
  cases row <;> rfl

/-- 鍵の符号化に構成子の並びを読む21行（精密な Map・Set の変換、%Map.replaceValues、Map・Set の通常の行）。 -/
def Primitive.readsKeys : Primitive → Bool
  | .p076 | .p269 | .p270 | .p271 | .p272 | .p273 | .p274 | .p275 | .p276 | .p277 | .p278
  | .p284 | .p285 | .p286 | .p287 | .p288 | .p289 | .p290 | .p291 | .p292 | .p293 => true
  | _ => false

/-- 精密なコレクションの行の δ を、構成子の並び cs で作る。 -/
def precisionDelta (cs : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  if name = "%Map.replaceValues" then StandardMapReplaceValues.delta cs name ts es rs ws
  else if name = "Map.fromList" ∨ name = "Map.toList" then StandardCollections.mapDelta cs name ts es rs ws
  else StandardCollections.setDelta cs name ts es rs ws

/-- Map・Set の通常の行の δ を、構成子の並び cs で作る。 -/
def collectionDelta (cs : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  if name.startsWith "Map." then StandardCollections.mapDelta cs name ts es rs ws
  else StandardCollections.setDelta cs name ts es rs ws

/-- 行の δ を、鍵の符号化が読む構成子の並び cs で作る。鍵を読む21行だけが cs に依る。 -/
def Primitive.deltaWith (cs : List ConName) (row : Primitive) :
    PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome :=
  match row with
  | .p076 | .p271 | .p277 | .p288 | .p292 => precisionDelta cs
  | .p269 | .p270 | .p272 | .p273 | .p274 | .p275 | .p276 | .p278
  | .p284 | .p285 | .p286 | .p287 | .p289 | .p290 | .p291 | .p293 => collectionDelta cs
  | row => row.provider.delta

/-- 合成プログラムの構成子の並びで作った δ は、合成表の行の δ である。 -/
theorem Primitive.deltaWith_base (row : Primitive) : row.deltaWith constructorNames = row.provider.delta := by
  cases row <;> rfl

theorem Primitive.deltaWith_of_not_readsKeys {row : Primitive} (h : row.readsKeys = false) (cs : List ConName) :
    row.deltaWith cs = row.provider.delta := by
  cases row <;> first | rfl | (exfalso; revert h; decide)

/-- 制約の判定 sat で署名を作り、構成子の並び cs で鍵を読む δ を作った合成表。IO 応答・効果の表は合成表のもの
である。 -/
def baseBuiltinsFor (sat : List TParam → Ty → TParam → Prop) (cs : List ConName) : Builtins := {signatureBase with
  sat := sat
  sig := fun b => (primitive b).map (Primitive.signatureWith sat)
  delta := fun b => (primitive b).elim (fun _ _ _ _ => none) (fun row => row.deltaWith cs b)
  ioResponse := ioResponse
  effects := effects}

theorem baseBuiltinsFor_base : baseBuiltinsFor signatureBase.sat constructorNames = baseBuiltins := by
  have hs : (fun b => (primitive b).map (Primitive.signatureWith signatureBase.sat)) = signature := by
    funext b
    simp only [signature]
    congr 1
    funext row
    exact Primitive.signatureWith_base row
  have hd : (fun b => (primitive b).elim (fun _ _ _ _ => none) (fun row => row.deltaWith constructorNames b)) =
      delta := by
    funext b ts es rs ws
    simp only [delta]
    cases primitive b with
    | none => rfl
    | some row => simp [Primitive.deltaWith_base]
  simp only [baseBuiltinsFor, baseBuiltins, hs, hd]

/-- 行の名前の lookup・δ・IO 応答が、表の制約の判定で作った合成表の行と一致する表。 -/
class RowLookup (B : Builtins) : Prop where
  sig : ∀ row : Primitive, B.sig row.name = some (row.signatureWith B.sat)
  valKind : B.valKind = signatureBase.valKind
  valContent : B.valContent = signatureBase.valContent
  admitsR : B.admitsR = signatureBase.admitsR
  delta : ∀ row : Primitive, row.readsKeys = false → B.delta row.name = row.provider.delta row.name
  io : ∀ (row : Primitive) ts es ws out obs,
    B.ioResponse row.name ts es ws out obs ↔ row.provider.ioResponse row.name ts es ws out obs

/-- 表の lookup は、台帳の行の名前でだけ署名を持つ。 -/
theorem primitive_name {b : PrimName} {row : Primitive} (h : primitive b = some row) : b = row.name := by
  have hs : signature b = some row.signature := by simp [signature, h]
  obtain ⟨row', _, hn, _⟩ := lookup_primitive hs
  have := (primitive_lookup row').symm.trans (hn ▸ h)
  cases Option.some.inj this
  exact hn

theorem RowLookup.sig_primitive {B : Builtins} [RowLookup B] {n : PrimName} {row : Primitive}
    (h : primitive n = some row) : B.sig n = some (row.signatureWith B.sat) := by
  rw [primitive_name h]; exact RowLookup.sig row

theorem RowLookup.sig_with {B : Builtins} [RowLookup B] {n : PrimName} {s : PrimSig} (row : Primitive)
    (h : primitive n = some row) (hs : row.signatureWith B.sat = s) : B.sig n = some s := by
  rw [RowLookup.sig_primitive h, hs]

/-- 制約を読まない行の名前では、表の署名は合成表の署名である。 -/
theorem RowLookup.sig_eq {B : Builtins} [RowLookup B] {n : PrimName} {s : PrimSig}
    (h : signature n = some s) (hr : (primitive n).map Primitive.readsSat = some false) : B.sig n = some s := by
  obtain ⟨row, hrow, rfl⟩ := Option.map_eq_some_iff.mp h
  rw [hrow] at hr
  rw [RowLookup.sig_primitive hrow, Primitive.signatureWith_of_not_readsSat (Option.some.inj hr)]

instance RowLookup.builtins (P : Program) : RowLookup (builtins P) where
  valKind := rfl
  valContent := rfl
  admitsR := rfl
  sig row := by
    show signature row.name = some (row.signatureWith signatureBase.sat)
    rw [Primitive.signatureWith_base]
    simp only [signature, primitive_lookup, Option.map_some]
  delta row _ := by
    funext ts es rs ws
    show (primitive row.name).bind (fun r => r.provider.delta row.name ts es rs ws) = _
    rw [primitive_lookup]
    rfl
  io row ts es ws out obs := by
    show (∃ r, primitive row.name = some r ∧ r.provider.ioResponse row.name ts es ws out obs) ↔ _
    rw [primitive_lookup]
    simp

/-! ## 共有の宣言 -/

/-- 合成プログラムは、範囲付きのHTTPのモデルが読むResult・ScopeError・Pair・要求・要求の誤りを、
同じ構成子とarityで宣言する。 -/
theorem http_declarations (externals : List (ExternalKey × ExternalDecl)) :
    ScopeDeclarations.HasHttp (program externals) := by
  have keys : (constructors.map Prod.fst).Nodup := by decide
  have lookup_of_mem : ∀ {c cd}, (c, cd) ∈ constructors → (program externals).cons c = some cd := by
    intro c cd h
    change constructors.lookup c = some cd
    revert h keys
    generalize constructors = xs
    intro keys h
    induction xs with
    | nil => cases h
    | cons x xs ih =>
      rcases x with ⟨k', v'⟩
      simp only [List.map_cons, List.nodup_cons] at keys
      simp only [List.lookup]
      rcases List.mem_cons.mp h with eq | mem
      · cases eq; simp
      · have ne : c ≠ k' := by
          intro eq; subst eq
          exact keys.1 (List.mem_map.mpr ⟨(c, cd), mem, rfl⟩)
        have hb : (c == k') = false := by simpa using ne
        rw [hb]
        exact ih keys.2 mem
  have arity : ∀ d ∈ ScopeDeclarations.http, (program externals).DataArity d.name d.ntys := by
    intro d hd
    refine ⟨?_, ?_⟩
    · rcases ScopeDeclarations.mem_http hd with hd | rfl | hd
      · simp only [ScopeDeclarations.base, ScopeDeclarations.file, List.cons_append, List.nil_append,
          List.mem_cons, List.not_mem_nil, or_false] at hd
        rcases hd with rfl | rfl | rfl | rfl | rfl
        · exact ⟨"Result.Ok", _, rfl, rfl⟩
        · exact ⟨"Scope.ScopeError.InvalidPattern", _, rfl, rfl⟩
        · exact ⟨"Pair.Pair", _, rfl, rfl⟩
        · exact ⟨"Http.ClientRequest", _, rfl, rfl⟩
        · exact ⟨"Http.RequestCheckError.InvalidUrl", _, rfl, rfl⟩
      · exact ⟨"Option.Some", _, rfl, rfl⟩
      · obtain ⟨D, hD, rfl⟩ := List.mem_map.mp hd
        have ne : D.constructors.length ≠ 0 :=
          (show ∀ D ∈ ScopePublic.declarations, D.constructors.length ≠ 0 by decide) D hD
        obtain ⟨e, rest, he⟩ := List.exists_cons_of_ne_nil (List.ne_nil_of_length_pos (Nat.pos_of_ne_zero ne))
        refine ⟨e.1, _, lookup_of_mem (List.mem_flatMap.mpr ⟨ScopeDeclarations.publicDecl D,
          List.mem_append_right _ (List.mem_map_of_mem hD), List.mem_map.mpr ⟨(e.1, e.2.map ScopePublic.PublicTy.ty),
            by simp [ScopeDeclarations.publicDecl, he], rfl⟩⟩), rfl⟩
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
  rcases ScopeDeclarations.mem_http hd with hd | rfl | hd
  · simp only [ScopeDeclarations.base, ScopeDeclarations.file, List.cons_append, List.nil_append,
      List.mem_cons, List.not_mem_nil, or_false] at hd
    rcases hd with rfl | rfl | rfl | rfl | rfl
    all_goals
      intro c hc
      simp only [StandardKeyTyping.DataDecl.entries, ScopeDeclarations.result, ScopeDeclarations.scopeError,
        ScopeDeclarations.pair, ScopeDeclarations.clientRequest, ScopeDeclarations.requestCheckError,
        List.map_cons, List.map_nil, List.mem_cons, List.not_mem_nil, or_false] at hc
      repeat' (rcases hc with rfl | hc)
      all_goals first | rfl | (subst hc; rfl)
  · intro c hc
    simp only [ScopeDeclarations.option, StandardKeyTyping.DataDecl.entries, List.map_cons, List.map_nil,
      List.mem_cons, List.not_mem_nil, or_false] at hc
    rcases hc with rfl | rfl <;> rfl
  · intro c hc
    exact lookup_of_mem (List.mem_flatMap.mpr ⟨d, List.mem_append_right _ hd, hc⟩)

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
  unfold declarations baseDeclarations at member
  rcases (List.mem_append.mp member).symm with pub | member
  · have other : ∀ d ∈ ScopeDeclarations.publicDecls, d.name ≠ "RoundingMode" := by decide
    exact absurd owner (other decl pub)
  rcases List.mem_append.mp member with old | last
  · have other : ∀ d ∈ StandardOrdinaryCoreBodies.declarations ++ ScopeDeclarations.base.filter
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


/-- 行の証明が読むプログラムの共有の宣言と、写像の鍵の宣言表・変性の検査。 -/
class RowEnv (P : Program) (B : Builtins) extends RowLookup B where
  options : StandardActualListBodies.ListOptionDeclarations P
  http : ScopeDeclarations.HasHttp P
  rounding : StandardDecimalResponse.Declarations P
  mapSet : StandardCollections.MapSetDeclarations P
  keys : StandardKeyTyping.Table P B
  valid : P.VarianceValid
  /-- 鍵を読む行の δ は、宣言表の構成子の並びで作った δ である。 -/
  keyDelta : ∀ row : Primitive, B.delta row.name =
    row.deltaWith ((keys.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst) row.name

instance RowEnv.base (externals : List (ExternalKey × ExternalDecl)) :
    RowEnv (program externals) (builtins (program externals)) where
  options := option_declarations externals
  http := http_declarations externals
  rounding := rounding_declarations externals
  mapSet := map_set_declarations externals
  keys := table externals
  valid := variance_valid externals
  keyDelta row := by
    funext ts es rs ws
    show (primitive row.name).bind (fun r => r.provider.delta row.name ts es rs ws) = _
    rw [primitive_lookup, Option.bind_some]
    exact (congrFun (congrFun (congrFun (congrFun (congrFun (Primitive.deltaWith_base row) row.name) ts) es) rs) ws).symm

/-- 合成プログラムの本体の型付けが読む環境。行の環境に加え、プログラムが合成プログラムの宣言を同じ値で持つ。 -/
class BodyEnv (externals : outParam (List (ExternalKey × ExternalDecl))) (P : Program) (B : outParam Builtins)
    extends RowEnv P B where
  extends_ : Program.Extends (program externals) P

instance BodyEnv.base (externals : List (ExternalKey × ExternalDecl)) :
    BodyEnv externals (program externals) (builtins (program externals)) where
  toRowEnv := RowEnv.base externals
  extends_ := Program.Extends.refl _

/-- 行の環境の表の制約の判定は、宣言表の要約による制約の骨格の判定である。 -/
theorem RowEnv.sat_eq {P : Program} {B : Builtins} [env : RowEnv P B] :
    B.sat = ModelConstraints.sat (Benitoite.Release.dataSummaries
      (env.keys.declarations.map StandardKeyTyping.DataDecl.summaryInput)) := by
  funext C a p
  exact propext (env.keys.sat_eq C a p)

theorem RowEnv.sat_empty {P : Program} {B : Builtins} [RowEnv P B] (C : List TParam) (a : Ty) : B.sat C a {} := by
  rw [RowEnv.sat_eq (P := P)]; exact ModelConstraints.sat_unconstrained _ _ _

end
end Benitoite.Release.Refinement.StandardModel
