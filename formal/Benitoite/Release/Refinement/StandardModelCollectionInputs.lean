import Benitoite.Release.Refinement.StandardModelWellFormed

/-! # 合成表のString・Bytes・List・Map・Setの行の契約の前提を満たす入力

`StandardModel.PureRow` の前提（合成表のlookupと、その署名の `BuiltinArgs`）を、型引数Integerと基本型の定数・
空の列・空のバイト列・空の写像・空の集合で満たす。具体化した依存列が `Ty.toTel` の形になる署名は値の列から、
結果の型が引数の値を読む署名は、合成表の署名の形成と型の具体化から依存列の注釈を得て、引数の値を一つずつ束縛して
満たす。依存の署名の入力は外部宣言の表の整形式性を前提に取る（合成プログラムの適格性が読む）。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
set_option linter.unusedSimpArgs false

/-- 具体化した依存列が `Ty.toTel` の形になる署名は、型付きの値の列から全欄を満たす。 -/
theorem arguments_of_toTel {P B Ψ b sg ts rs ws names inputs ret e}
    (admissible : PrimitiveAdmissible [] 0 sg Qempty ts [])
    (ranges : B.RangeAdmissible b sg rs)
    (source : (Ty.dependentFn (Tel.instR rs sg.tel)).WF 0 (sg.tparams.map TParamDecl.kind).length 0)
    (kinds : TypeArgsKinded P [] ts (sg.tparams.map TParamDecl.kind))
    (typeAnnotations : TypeAnnotations P [] [] ts)
    (inst : instantiatedTel (Tel.instR rs sg.tel) ts [] = Ty.toTel names inputs ret e)
    (annotation : Ty.Annotation P [] [] (.fn names inputs ret e))
    (inputsNormal : Ty.normTys inputs = inputs) (retNormal : ret.norm = ret) (retWF : ret.WF 0 0 0)
    (effectNormal : Eff.norm e = e) (effectWF : Eff.WF 0 0 0 e)
    (values : HasTypeVsQ P B Ψ Qempty [] [] [] ws inputs)
    (ground : ∀ w ∈ ws, w.Ground)
    (types : ∀ t ∈ ts, t.WF 0 0 0 ∧ t.Canonical) :
    BuiltinArgs P B Ψ b sg ts [] rs ws ret e := by
  refine ⟨admissible, ranges, ⟨source, typeAnnotations, kinds, (by intro e he; cases he),
    (by intro e he; cases he), ?_⟩, ?_, ground, types, (by intro e he; cases he), ⟨retWF, retNormal⟩,
    ⟨effectWF, effectNormal⟩⟩
  · rw [inst]; exact annotation.toTel
  · rw [inst]
    have h := HasTypeVsQ.toTel_normal annotation values
    rw [inputsNormal, retNormal, effectNormal] at h
    exact h

/-- 型ごとの一つの値。基本型は定数、列・バイト列・写像・集合は空の値。 -/
def inhabitant : Ty → Val
  | .base b => .const (sample b)
  | .list _ => .list []
  | .bytes => .bytesV []
  | .map _ _ => .mapV [] []
  | .set _ => .setV []
  | _ => .const .unit

/-- `inhabitant` が型付く形。列の要素型・写像と集合の鍵と値の型は注釈を持ち、鍵は鍵の制約を満たす。 -/
def Inhabitable (P : Program) (B : Builtins) : Ty → Prop
  | .base _ => True
  | .bytes => True
  | .list a => Ty.Annotation P [] [] a
  | .map a b => B.sat [] a.norm TParam.keyC ∧ Ty.Annotation P [] [] a ∧ Ty.Annotation P [] [] b
  | .set a => B.sat [] a.norm TParam.keyC ∧ Ty.Annotation P [] [] a
  | _ => False

theorem base_annotation {P : Program} (b : BaseTy) : Ty.Annotation P [] [] (.base b) :=
  ⟨trivial, trivial, trivial⟩

theorem inhabitant_typed {P B Ψ} : ∀ {a : Ty}, Inhabitable P B a →
    HasTypeVQ P B Ψ Qempty [] [] [] (inhabitant a) a
  | .base b, _ => sample_typed b
  | .bytes, _ => .V_Bytes (by intro b hb; cases hb)
  | .list _, h => .V_List .nil h.wf h.sorted h.declared
  | .map _ _, h => .V_Map .nil .nil rfl h.1 h.2.1 h.2.2
  | .set _, h => .V_Set .nil h.1 h.2

theorem inhabitants_typed {P B Ψ} : ∀ {as : List Ty}, (∀ a ∈ as, Inhabitable P B a) →
    HasTypeVsQ P B Ψ Qempty [] [] [] (as.map inhabitant) as
  | [], _ => .nil
  | a :: as, h => .cons (inhabitant_typed (h a (by simp))) (inhabitants_typed (fun b hb => h b (by simp [hb])))

theorem inhabitants_ground : ∀ (as : List Ty), ∀ w ∈ as.map inhabitant, w.Ground
  | [], _, h => by cases h
  | a :: as, w, h => by
    rcases List.mem_cons.mp h with rfl | h
    · cases a <;> trivial
    · exact inhabitants_ground as w h


/-- 行の署名の具体化が `Ty.toTel` の形になり、引数の列が型付くなら、契約の前提を満たす入力がある。 -/
theorem PureRow.Satisfiable.of_inputs {P : Program} (row : Primitive) {sg ts ws names inputs ret}
    (hsig : row.signature = sg)
    (admissible : PrimitiveAdmissible [] 0 sg Qempty ts [])
    (ranges : (builtins P).RangeAdmissible row.name sg [])
    (source : (Ty.dependentFn (Tel.instR [] sg.tel)).WF 0 (sg.tparams.map TParamDecl.kind).length 0)
    (kinds : TypeArgsKinded P [] ts (sg.tparams.map TParamDecl.kind))
    (typeAnnotations : TypeAnnotations P [] [] ts)
    (inst : instantiatedTel (Tel.instR [] sg.tel) ts [] = Ty.toTel names inputs ret Eff.empty)
    (annotation : Ty.Annotation P [] [] (.fn names inputs ret Eff.empty))
    (inputsNormal : Ty.normTys inputs = inputs) (retNormal : ret.norm = ret) (retWF : ret.WF 0 0 0)
    (values : HasTypeVsQ P (builtins P) StoreTy.empty Qempty [] [] [] ws inputs)
    (ground : ∀ w ∈ ws, w.Ground)
    (types : ∀ t ∈ ts, t.WF 0 0 0 ∧ t.Canonical) : PureRow.Satisfiable P row.name :=
  ⟨StoreTy.empty, sg, ts, [], [], ws, ret, Eff.empty, hsig ▸ row_lookup P row,
    arguments_of_toTel admissible ranges source kinds typeAnnotations inst annotation inputsNormal retNormal
      retWF rfl (by simp [Eff.WF, Eff.empty, Ty.WFList]) values ground types⟩

/-- 型引数のInteger一つ。 -/
theorem integer_kinds {P : Program} (k : TyKind) (hk : k = .value) :
    TypeArgsKinded P [] [.base .integer] [k] := by
  subst hk
  refine ⟨rfl, ?_⟩
  intro i a k ha hk
  cases i with
  | zero => simp at ha hk; subst ha; subst hk; exact ⟨trivial, fun _ => by simp [Ty.core]⟩
  | succ i => simp at ha

private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]

local macro "row_simp" " [" args:Lean.Parser.Tactic.simpLemma,* "]" : tactic => `(tactic|
  simp [PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,
    rowFails,empty_range,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,RowTransport,Tel.RowsIn,Ty.RowsIn,
    Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row,Ty.WF,Tel.WF,Eff.WF,Ty.WFList,
    Eff.Canonical,Builtins.RangeAdmissible,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
    declaredEff,NamesWF,Inhabitable,base_annotation,Ordinary,StandardPureResults.Kind.type,$args,*])

section
open StandardStringOrdinaryResponse

private theorem string_admissible (api : API) : PrimitiveAdmissible [] 0 api.signature Qempty [] [] := by
  cases api <;> constructor <;> row_simp [API.signature,API.names,API.inputs,API.resultKind]

private theorem string_source (api : API) :
    (Ty.dependentFn (Tel.instR [] api.signature.tel)).WF 0 (api.signature.tparams.map TParamDecl.kind).length 0 := by
  cases api <;> row_simp [API.signature,API.names,API.inputs,API.resultKind]

private theorem string_instantiated (api : API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs api.resultKind.type Eff.empty := by
  cases api <;> row_simp [API.signature,API.names,API.inputs,API.resultKind]

private theorem string_annotation {externals} (api : API) :
    Ty.Annotation (program externals) [] [] (.fn api.names api.inputs api.resultKind.type Eff.empty) := by
  have arity := (option_declarations externals).arity
  cases api <;> exact ⟨by row_simp [API.names,API.inputs,API.resultKind], by row_simp [API.inputs,API.resultKind],
    by row_simp [API.inputs,API.resultKind,arity]⟩

private theorem string_forms {P : Program} {B : Builtins} (api : API) :
    Ty.normTys api.inputs = api.inputs ∧ api.resultKind.type.norm = api.resultKind.type ∧
      api.resultKind.type.WF 0 0 0 ∧ ∀ a ∈ api.inputs, Inhabitable P B a := by
  cases api <;> row_simp [API.inputs,API.resultKind]

/-- Stringの行の署名は、空の文字列・整数1・空の列・空のバイト列で全欄を満たす。 -/
theorem PureRow.Satisfiable.string {externals} (row : Primitive) (api : API)
    (hsig : row.signature = api.signature) : PureRow.Satisfiable (program externals) row.name :=
  have forms := string_forms (P := program externals) (B := builtins (program externals)) api
  PureRow.Satisfiable.of_inputs row hsig (ts := []) (ws := api.inputs.map inhabitant)
    (string_admissible api) (by row_simp [API.signature]) (string_source api) ⟨rfl, by intro i a k ha; cases ha⟩
    (by intro a ha; cases ha) (string_instantiated api) (string_annotation api) forms.1 forms.2.1 forms.2.2.1
    (inhabitants_typed forms.2.2.2) (inhabitants_ground _) (by intro t ht; cases ht)
end

section
open StandardBytesOrdinaryResponse

/-- 整数の読み書きの行の値の列。順序は大きい側の端を先に置く構成子。 -/
def bytesOrdinaryInputs (api : API) : List Val :=
  match api with
  | .readUnsigned | .readSigned => [.bytesV [], .const (sample .integer), .const (sample .integer),
      .con "ByteOrder.BigEndian" [] []]
  | .fromUnsigned | .fromSigned => [.const (sample .integer), .const (sample .integer),
      .con "ByteOrder.BigEndian" [] []]
  | _ => api.inputs.map inhabitant

private theorem byte_order_typed {externals} :
    HasTypeVQ (program externals) (builtins (program externals)) StoreTy.empty Qempty [] [] []
      (.con "ByteOrder.BigEndian" [] []) (.data "ByteOrder" []) :=
  .V_Con (cd := ⟨"ByteOrder", 0, []⟩) rfl rfl ⟨rfl, by intro i a k ha; simp at ha⟩ (by intro t ht; cases ht) .nil
    ⟨by simp [Ty.WF, Ty.WFList], by trivial, ⟨⟨0, (arities externals).2.2.2.2.2.2.2.2.2.2.2.2.2.2.1, rfl⟩, trivial⟩⟩

/-- Bytesの構築・変換・取得・連結・整数の読み書きの行は、空のバイト列・整数1・空の文字列・大きい側の端で全欄を満たす。 -/
theorem PureRow.Satisfiable.bytesOrdinary {externals} (row : Primitive) (api : API)
    (hsig : row.signature = api.signature) : PureRow.Satisfiable (program externals) row.name := by
  have arity := (option_declarations externals).arity
  have orderArity := (arities externals).2.2.2.2.2.2.2.2.2.2.2.2.2.2.1
  refine PureRow.Satisfiable.of_inputs row hsig (ts := []) (ws := bytesOrdinaryInputs api)
    (names := api.names) (inputs := api.inputs) (ret := api.resultKind.type) ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_
    (by intro t ht; cases ht)
  · cases api <;> constructor <;> row_simp [API.signature,API.names,API.inputs,API.resultKind]
  · row_simp [API.signature]
  · cases api <;> row_simp [API.signature,API.names,API.inputs,API.resultKind]
  · exact ⟨rfl, by intro i a k ha; cases ha⟩
  · intro a ha; cases ha
  · cases api <;> row_simp [API.signature,API.names,API.inputs,API.resultKind]
  · cases api <;> exact ⟨by row_simp [API.names,API.inputs,API.resultKind], by row_simp [API.inputs,API.resultKind],
      by row_simp [API.inputs,API.resultKind,arity,orderArity]⟩
  · cases api <;> row_simp [API.inputs]
  · cases api <;> row_simp [API.resultKind]
  · cases api <;> row_simp [API.resultKind]
  · cases api
    all_goals first
      | exact inhabitants_typed (by row_simp [API.inputs])
      | exact .cons (inhabitant_typed (a := .bytes) trivial) (.cons (sample_typed .integer) (.cons (sample_typed .integer)
          (.cons byte_order_typed .nil)))
      | exact .cons (sample_typed .integer) (.cons (sample_typed .integer) (.cons byte_order_typed .nil))
  · cases api
    all_goals first
      | exact inhabitants_ground _
      | (intro w hw; simp [bytesOrdinaryInputs] at hw; rcases hw with rfl | rfl | rfl | rfl <;> first | trivial | exact ⟨by simp, trivial⟩)
      | (intro w hw; simp [bytesOrdinaryInputs] at hw; rcases hw with rfl | rfl | rfl <;> first | trivial | exact ⟨by simp, trivial⟩)
end

section
open StandardBytesResponse

/-- Stringのバイト数・文字数とBytesの長さ・Listとの変換の行。 -/
theorem PureRow.Satisfiable.bytes {externals} (row : Primitive) (api : API)
    (hsig : row.signature = api.signature) : PureRow.Satisfiable (program externals) row.name := by
  refine PureRow.Satisfiable.of_inputs row hsig (ts := []) (ws := api.inputs.map inhabitant)
    (names := api.names) (inputs := api.inputs) (ret := api.result) ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_
    (inhabitants_typed ?_) (inhabitants_ground _) (by intro t ht; cases ht)
  · cases api <;> constructor <;> row_simp [API.signature,API.names,API.inputs,API.result]
  · row_simp [API.signature]
  · cases api <;> row_simp [API.signature,API.names,API.inputs,API.result]
  · exact ⟨rfl, by intro i a k ha; cases ha⟩
  · intro a ha; cases ha
  · cases api <;> row_simp [API.signature,API.names,API.inputs,API.result]
  · cases api <;> exact ⟨by row_simp [API.names,API.inputs,API.result], by row_simp [API.inputs,API.result],
      by row_simp [API.inputs,API.result]⟩
  · cases api <;> row_simp [API.inputs]
  · cases api <;> row_simp [API.result]
  · cases api <;> row_simp [API.result]
  · cases api <;> row_simp [API.inputs]
end

private theorem integer_types : ∀ t ∈ [Ty.base .integer], t.WF 0 0 0 ∧ t.Canonical := by
  intro t ht; simp at ht; subst ht; exact ⟨trivial, rfl⟩

private theorem integer_annotations {P : Program} : TypeAnnotations P [] [] [.base .integer] := by
  intro t ht; simp at ht; subst ht; exact base_annotation _

section
open StandardListResponse

/-- Listの長さ・空・前置・連結・反転の行は、型引数Integerと空の列・整数1で全欄を満たす。 -/
theorem PureRow.Satisfiable.list {externals} (row : Primitive) (api : API)
    (hsig : row.signature = api.signature) : PureRow.Satisfiable (program externals) row.name := by
  refine PureRow.Satisfiable.of_inputs row hsig (ts := [.base .integer])
    (ws := (api.inputs (.base .integer)).map inhabitant)
    (names := api.names) (inputs := api.inputs (.base .integer)) (ret := api.result (.base .integer))
    ?_ ?_ ?_ (integer_kinds _ rfl) integer_annotations ?_ ?_ ?_ ?_ ?_
    (inhabitants_typed ?_) (inhabitants_ground _) integer_types
  · cases api <;> constructor <;> row_simp [API.signature,API.names,API.inputs,API.result,TypeCtx.valueParam]
  · row_simp [API.signature]
  · cases api <;> row_simp [API.signature,API.names,API.inputs,API.result,TypeCtx.valueParam]
  · cases api <;> row_simp [API.signature,API.names,API.inputs,API.result]
  · cases api <;> exact ⟨by row_simp [API.names,API.inputs,API.result], by row_simp [API.inputs,API.result],
      by row_simp [API.inputs,API.result]⟩
  · cases api <;> row_simp [API.inputs]
  · cases api <;> row_simp [API.result]
  · cases api <;> row_simp [API.result]
  · cases api <;> row_simp [API.inputs]
end

/-- 合成表の制約の判定は、Integerについて全ての制約を満たす。 -/
theorem integer_sat (P : Program) (C : List TParam) (p : TParam) :
    (builtins P).sat C (.base .integer) p := by
  rcases p with ⟨equality, key⟩
  cases equality <;> cases key <;> rfl

/-- Integerだけを並べた型引数の列の全位置は、合成表の任意の制約を満たす。 -/
theorem integers_sat {P : Program} {C : List TParam} {ts : List Ty} (hts : ∀ t ∈ ts, t = .base .integer)
    (ps : List TParam) : ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → ps[i]? = some p →
      (builtins P).sat C t p := by
  intro i t p ht _
  rw [hts t (List.mem_of_getElem? ht)]
  exact integer_sat P C p

section
open StandardListRemainingResponse

/-- Listの取得・切り出し・所属・整列の行は、型引数Integerと空の列・整数1で全欄を満たす。 -/
theorem PureRow.Satisfiable.listRemaining {externals} (row : Primitive) (api : API)
    (hsig : row.signature = API.signature signatureBase.sat api) :
    PureRow.Satisfiable (program externals) row.name := by
  have arity := (option_declarations externals).arity
  refine PureRow.Satisfiable.of_inputs row hsig (ts := [.base .integer])
    (ws := (api.inputs (.base .integer)).map inhabitant)
    (names := api.names) (inputs := api.inputs (.base .integer)) (ret := api.result (.base .integer))
    ?_ ?_ ?_ (integer_kinds _ rfl) integer_annotations ?_ ?_ ?_ ?_ ?_
    (inhabitants_typed ?_) (inhabitants_ground _) integer_types
  · refine ⟨rfl, ⟨rfl, fun _ => integers_sat (P := program externals) (by simp [Ty.normTys, Ty.norm]) _,
      fun _ t ht => ?_⟩, ?_, rfl, ?_, ?_, ?_, ?_, ?_⟩
    · simp [Ty.normTys, Ty.norm] at ht; subst ht; exact trivial
    all_goals cases api <;> row_simp [API.signature,API.names,API.inputs,API.result,API.constraint]
  · row_simp [API.signature]
  · cases api <;> row_simp [API.signature,API.names,API.inputs,API.result,API.constraint]
  · cases api <;> row_simp [API.signature,API.names,API.inputs,API.result]
  · cases api <;> exact ⟨by row_simp [API.names,API.inputs,API.result], by row_simp [API.inputs,API.result],
      by row_simp [API.inputs,API.result,arity]⟩
  · cases api <;> row_simp [API.inputs]
  · cases api <;> row_simp [API.result]
  · cases api <;> row_simp [API.result]
  · cases api <;> row_simp [API.inputs]

/-- List.rangeの行は、二つの整数1で全欄を満たす。 -/
theorem PureRow.Satisfiable.range {P : Program} (row : Primitive) (hsig : row.signature = rangeSignature) :
    PureRow.Satisfiable P row.name := by
  refine PureRow.Satisfiable.of_inputs row hsig (ts := []) (ws := [.const (sample .integer), .const (sample .integer)])
    (names := ["start","stop"]) (inputs := [.base .integer, .base .integer]) (ret := .list (.base .integer))
    ?_ ?_ ?_ ⟨rfl, by intro i a k ha; cases ha⟩ (by intro a ha; cases ha) ?_ ?_ rfl rfl ?_
    (.cons (sample_typed _) (.cons (sample_typed _) .nil)) (by intro w hw; simp at hw; rcases hw with rfl | rfl <;> trivial)
    (by intro t ht; cases ht)
  · constructor <;> row_simp [rangeSignature]
  · row_simp [rangeSignature]
  · row_simp [rangeSignature]
  · row_simp [rangeSignature]
  · exact ⟨by row_simp [], by row_simp [], by row_simp []⟩
  · row_simp []
end

/-- 合成プログラムでIntegerの対の型は注釈を持つ。 -/
theorem pair_annotation (externals : List (ExternalKey × ExternalDecl)) :
    Ty.Annotation (program externals) [] [] (.data "Pair" [.base .integer, .base .integer]) :=
  ⟨by simp [Ty.WF, Ty.WFList], by simp [Ty.Sorted, sortedTys],
    ⟨⟨2, (arities externals).2.2.2.2.2.2.1, rfl⟩, by simp [declaredTys, Ty.Declared]⟩⟩

section
open StandardCollections

/-- Mapの通常の行は、型引数Integer・Integerと空の写像・整数1で全欄を満たす。 -/
theorem PureRow.Satisfiable.map {externals} (row : Primitive) (api : MapAPI)
    (hsig : row.signature = MapAPI.signature signatureBase.sat api) :
    PureRow.Satisfiable (program externals) row.name := by
  have arity := (option_declarations externals).arity
  have pair := (arities externals).2.2.2.2.2.2.1
  refine PureRow.Satisfiable.of_inputs row hsig (ts := [.base .integer, .base .integer])
    (ws := (api.inputs (.base .integer) (.base .integer)).map inhabitant)
    (names := api.names) (inputs := api.inputs (.base .integer) (.base .integer))
    (ret := api.result (.base .integer) (.base .integer))
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ ?_ (inhabitants_typed ?_) (inhabitants_ground _) ?_
  · refine ⟨rfl, ⟨rfl, integers_sat (P := program externals) (by simp [Ty.normTys, Ty.norm]) _⟩, ?_, rfl, ?_, ?_, ?_, ?_, ?_⟩
    all_goals cases api <;> row_simp [MapAPI.signature,MapAPI.names,MapAPI.inputs,MapAPI.result,TypeCtx.valueParam]
  · row_simp [MapAPI.signature]
  · cases api <;> row_simp [MapAPI.signature,MapAPI.names,MapAPI.inputs,MapAPI.result,TypeCtx.valueParam]
  · refine ⟨rfl, ?_⟩
    intro i a k ha hk
    rcases i with _ | _ | i <;> simp [MapAPI.signature, TypeCtx.valueParam] at ha hk
    all_goals (subst ha; subst hk; exact ⟨trivial, fun _ => by simp [Ty.core]⟩)
  · intro t ht; simp at ht; rcases ht with rfl | rfl <;> exact base_annotation _
  · cases api <;> row_simp [MapAPI.signature,MapAPI.names,MapAPI.inputs,MapAPI.result]
  · cases api <;> exact ⟨by row_simp [MapAPI.names,MapAPI.inputs,MapAPI.result], by row_simp [MapAPI.inputs,MapAPI.result],
      by row_simp [MapAPI.inputs,MapAPI.result,arity,pair]⟩
  · cases api <;> row_simp [MapAPI.inputs]
  · cases api <;> row_simp [MapAPI.result]
  · cases api <;> row_simp [MapAPI.result]
  · cases api <;> row_simp [MapAPI.inputs, integer_sat, pair_annotation]
  · intro t ht; simp at ht; rcases ht with rfl | rfl <;> exact ⟨trivial, rfl⟩

/-- Setの通常の行は、型引数Integerと空の集合・空の列・整数1で全欄を満たす。 -/
theorem PureRow.Satisfiable.set {externals} (row : Primitive) (api : SetAPI)
    (hsig : row.signature = SetAPI.signature signatureBase.sat api) :
    PureRow.Satisfiable (program externals) row.name := by
  refine PureRow.Satisfiable.of_inputs row hsig (ts := [.base .integer])
    (ws := (api.inputs (.base .integer)).map inhabitant)
    (names := api.names) (inputs := api.inputs (.base .integer)) (ret := api.result (.base .integer))
    ?_ ?_ ?_ (integer_kinds _ rfl) integer_annotations ?_ ?_ ?_ ?_ ?_
    (inhabitants_typed ?_) (inhabitants_ground _) integer_types
  · refine ⟨rfl, ⟨rfl, integers_sat (P := program externals) (by simp [Ty.normTys, Ty.norm]) _⟩, ?_, rfl, ?_, ?_, ?_, ?_, ?_⟩
    all_goals cases api <;> row_simp [SetAPI.signature,SetAPI.names,SetAPI.inputs,SetAPI.result]
  · row_simp [SetAPI.signature]
  · cases api <;> row_simp [SetAPI.signature,SetAPI.names,SetAPI.inputs,SetAPI.result]
  · cases api <;> row_simp [SetAPI.signature,SetAPI.names,SetAPI.inputs,SetAPI.result]
  · cases api <;> exact ⟨by row_simp [SetAPI.names,SetAPI.inputs,SetAPI.result], by row_simp [SetAPI.inputs,SetAPI.result],
      by row_simp [SetAPI.inputs,SetAPI.result]⟩
  · cases api <;> row_simp [SetAPI.inputs]
  · cases api <;> row_simp [SetAPI.result]
  · cases api <;> row_simp [SetAPI.result]
  · cases api <;> row_simp [SetAPI.inputs, integer_sat]
end

/-- 内部の %List.getFront の行は、型引数Integerと空の列・整数1で全欄を満たす。 -/
theorem PureRow.Satisfiable.front {P : Program} (row : Primitive) (hsig : row.signature = StandardSafe.frontSig) :
    PureRow.Satisfiable P row.name := by
  refine PureRow.Satisfiable.of_inputs row hsig (ts := [.base .integer])
    (ws := [.list [], .const (sample .integer)])
    (names := ["xs","index"]) (inputs := [.list (.base .integer), .base .integer]) (ret := .base .integer)
    ?_ ?_ ?_ (integer_kinds _ rfl) integer_annotations ?_ ?_ rfl rfl trivial
    (.cons (inhabitant_typed (a := .list (.base .integer)) (base_annotation _)) (.cons (sample_typed _) .nil))
    (by intro w hw; simp at hw; rcases hw with rfl | rfl <;> trivial) integer_types
  · constructor <;> row_simp [StandardSafe.frontSig,TypeCtx.valueParam]
  · row_simp [StandardSafe.frontSig]
  · row_simp [StandardSafe.frontSig,TypeCtx.valueParam]
  · row_simp [StandardSafe.frontSig]
  · exact ⟨by row_simp [], by row_simp [], by row_simp []⟩


/-- 外部宣言の表が整形式なら、合成表の行の署名をIntegerだけの型引数で具体化した依存列は注釈を持つ。 -/
theorem instance_annotation {externals} (hw : (program externals).ExternalWF) (row : Primitive)
    {ts : List Ty} (hts : ∀ t ∈ ts, t = .base .integer)
    (count : ts.length = row.signature.tparams.length) (ranges : row.signature.rkinds = [])
    (kinds : TypeArgsKinded (program externals) [] ts (TypeCtx.kinds row.signature.tparams)) :
    Ty.Annotation (program externals) [] []
      (.dependentFn (instantiatedTel (Tel.instR [] row.signature.tel) ts [])) := by
  have formed := (core externals).sig_scoped row.name row.signature (row_lookup _ row)
  have inst := formed.inst (rs := []) (by rw [ranges]; rfl)
  have hf : (program externals).WellFormed ∧ (program externals).WellTyped (builtins (program externals)) ∧
      (builtins (program externals)).CoreAssumptions (program externals) ∧ StoreTy.empty.WF :=
    ⟨program_wellFormed externals hw, program_typed externals hw, core externals, StoreTy.WF.empty⟩
  have hi : TypeSubstInput (program externals) (builtins (program externals)) row.signature.tparams [] ts [] :=
    ⟨count, fun t ht => by rw [hts t ht]; trivial, kinds,
      fun t ht => by rw [hts t ht]; exact ⟨trivial, trivial, trivial⟩,
      ⟨by simp [count, TypeCtx.constraints], fun i t p ht _ => by
        rw [hts t (List.mem_of_getElem? ht)]; rcases p with ⟨equality, key⟩; cases equality <;> cases key <;> rfl⟩,
      (by intro e he; cases he), (by intro e he; cases he), (by intro e he; cases he)⟩
  have h := Tel.annotation_substAt (Ψ := StoreTy.empty) hf hi (C1 := []) (Γ := []) (by simpa using inst.2.2.2)
  simpa [Tel.substAt, instantiatedTel, Ctx.bindTypes] using h

/-- 型付きの値の列と依存列の注釈から、契約の前提を満たす入力を組み立てる。 -/
theorem PureRow.Satisfiable.of_arguments {P : Program} (row : Primitive) {sg ts ws a e}
    (hsig : row.signature = sg)
    (admissible : PrimitiveAdmissible [] 0 sg Qempty ts [])
    (ranges : (builtins P).RangeAdmissible row.name sg [])
    (source : (Ty.dependentFn (Tel.instR [] sg.tel)).WF 0 (sg.tparams.map TParamDecl.kind).length 0)
    (kinds : TypeArgsKinded P [] ts (sg.tparams.map TParamDecl.kind))
    (typeAnnotations : TypeAnnotations P [] [] ts)
    (result : Ty.Annotation P [] [] (.dependentFn (instantiatedTel (Tel.instR [] sg.tel) ts [])))
    (arguments : HasTypeTelArgsQ P (builtins P) StoreTy.empty Qempty [] [] [] ws
      (instantiatedTel (Tel.instR [] sg.tel) ts []) a e)
    (ground : ∀ w ∈ ws, w.Ground) (types : ∀ t ∈ ts, t.WF 0 0 0 ∧ t.Canonical)
    (resultForm : a.WF 0 0 0 ∧ a.Canonical) (effectForm : Eff.WF 0 0 0 e ∧ e.Canonical) :
    PureRow.Satisfiable P row.name :=
  ⟨StoreTy.empty, sg, ts, [], [], ws, a, e, hsig ▸ row_lookup P row,
    ⟨admissible, ranges, ⟨source, typeAnnotations, kinds, (by intro e he; cases he), (by intro e he; cases he), result⟩,
      arguments, ground, types, (by intro e he; cases he), resultForm, effectForm⟩⟩

/-- 一つの引数の依存列は、その引数の型の値と全体の注釈から、束縛した結果の型までを型付ける。 -/
theorem one_argument {P B v name input R E}
    (annotation : Ty.Annotation P [] [] (.dependentFn (.param name input (.done R E))))
    (typed : HasTypeVQ P B StoreTy.empty Qempty [] [] [] v input) :
    HasTypeTelArgsQ P B StoreTy.empty Qempty [] [] [] [v] (.param name input (.done R E))
      (R.bind (Tel.argumentsEnv v)) (Eff.bind (Tel.argumentsEnv v) E) ∧
    (R.bind (Tel.argumentsEnv v)).WF 0 0 0 ∧ (R.bind (Tel.argumentsEnv v)).Canonical ∧
    Eff.WF 0 0 0 (Eff.bind (Tel.argumentsEnv v) E) ∧ (Eff.bind (Tel.argumentsEnv v) E).Canonical := by
  have opened := Tel.annotation_open (by intro i a h; cases i <;> cases h) annotation typed
  rw [Tel.bind_done] at opened
  exact ⟨.param ⟨annotation.wf.1, annotation.sorted.1, annotation.declared.1⟩ typed (by rw [Tel.bind_done]; exact .done opened),
    opened.wf.1, Ty.norm_idem _, opened.wf.2.1, Eff.norm_idem _⟩


local macro "dependent_simp" " [" args:Lean.Parser.Tactic.simpLemma,* "]" : tactic => `(tactic|
  simp [PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,Ty.norm,Ty.normTys,
    Tel.norm,rawBindTys,typeEnvAt,SubstEnv.up,Eff.rawBind,Eff.norm,Eff.empty,rowFails,
    substAtoms_nil,instAtoms_nil,predBind,termBind,termBind?,upValues,Ty.refineNorm,
    Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Ty.core,
    Ty.shiftV,Term.bind_closed,Tel.argumentsEnv,valEnv,Ty.WF,Ty.WFList,Tel.WF,Ty.NotContCore,
    Pred.WF,Pred.VarsIn,Term.VarsIn,empty_range,mapRangesTys,RowTransport,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,
    Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row,Eff.WF,Eff.Canonical,Builtins.RangeAdmissible,
    TypeCtx.valueParam,Ordinary,$args,*])

section
open StandardHeadTail

private theorem head_tel :
    instantiatedTel (Tel.instR [] headSignature.tel) [.base .integer] [] =
      .param "xs" (.list (.base .integer))
        (.done (.refined (.data "Option" [.base .integer]) (headPredicate (.var 0) (.var 1))) Eff.empty) := by
  dependent_simp [headSignature, headPredicate, length]

private theorem tail_tel :
    instantiatedTel (Tel.instR [] tailSignature.tel) [.base .integer] [] =
      .param "xs" (.list (.base .integer))
        (.done (.refined (.data "Option" [.list (.base .integer)]) (tailPredicate (.var 0) (.var 1))) Eff.empty) := by
  dependent_simp [tailSignature, tailPredicate, headPredicate, length, someField]

/-- 一つの引数を持ち、型引数をIntegerだけで具体化する依存の署名の行は、その引数の型の値から契約の前提を満たす。 -/
theorem PureRow.Satisfiable.of_one {externals} (hw : (program externals).ExternalWF) (row : Primitive)
    {sg ts name input R E v} (hsig : row.signature = sg) (hts : ∀ t ∈ ts, t = .base .integer)
    (admissible : PrimitiveAdmissible [] 0 sg Qempty ts [])
    (ranges : (builtins (program externals)).RangeAdmissible row.name sg [])
    (source : (Ty.dependentFn (Tel.instR [] sg.tel)).WF 0 (sg.tparams.map TParamDecl.kind).length 0)
    (rangeKinds : sg.rkinds = [])
    (kinds : TypeArgsKinded (program externals) [] ts (sg.tparams.map TParamDecl.kind))
    (inst : instantiatedTel (Tel.instR [] sg.tel) ts [] = .param name input (.done R E))
    (typed : HasTypeVQ (program externals) (builtins (program externals)) StoreTy.empty Qempty [] [] [] v input)
    (ground : v.Ground) : PureRow.Satisfiable (program externals) row.name := by
  subst hsig
  have annotation := instance_annotation hw row hts admissible.typeCount rangeKinds kinds
  rw [inst] at annotation
  obtain ⟨args, rw', rc, ew, ec⟩ := one_argument annotation typed
  refine PureRow.Satisfiable.of_arguments row rfl admissible ranges source kinds
    (fun t ht => by rw [hts t ht]; exact base_annotation _) (inst ▸ annotation) (inst ▸ args)
    (by intro w hw; simp at hw; subst hw; exact ground) (fun t ht => by rw [hts t ht]; exact ⟨trivial, rfl⟩)
    ⟨rw', rc⟩ ⟨ew, ec⟩

/-- List.head・List.tailの行は、型引数Integerと空の列で全欄を満たす。 -/
theorem PureRow.Satisfiable.headTail {externals} (hw : (program externals).ExternalWF) (row : Primitive)
    (tail : Bool) (hsig : row.signature = if tail then tailSignature else headSignature) :
    PureRow.Satisfiable (program externals) row.name := by
  cases tail
  · refine PureRow.Satisfiable.of_one hw row hsig (by simp) ?_ ?_ ?_ rfl (integer_kinds _ rfl) head_tel
      (inhabitant_typed (a := .list (.base .integer)) (base_annotation _)) trivial
    · constructor <;> dependent_simp [headSignature, headPredicate, length]
    · dependent_simp [headSignature]
    · dependent_simp [headSignature, headPredicate, length]
  · refine PureRow.Satisfiable.of_one hw row hsig (by simp) ?_ ?_ ?_ rfl (integer_kinds _ rfl) tail_tel
      (inhabitant_typed (a := .list (.base .integer)) (base_annotation _)) trivial
    · constructor <;> dependent_simp [tailSignature, tailPredicate, headPredicate, length, someField]
    · dependent_simp [tailSignature]
    · dependent_simp [tailSignature, tailPredicate, headPredicate, length, someField]
end

section
open StandardCollectionPrecision

local macro "precision_simp" : tactic => `(tactic|
  dependent_simp [StandardCollectionPrecision.signature,StandardBodies.collectionPrimitiveSig,
    input,result,collection,element,predicate,size,length])

/-- 精密なMap.fromList・Map.toList・Set.fromList・Set.toListの行は、型引数Integerと空の列・写像・集合で全欄を満たす。 -/
theorem PureRow.Satisfiable.precision {externals} (hw : (program externals).ExternalWF) (row : Primitive)
    (map build : Bool) (hsig : row.signature = StandardCollectionPrecision.signature signatureBase.sat map build) :
    PureRow.Satisfiable (program externals) row.name := by
  have pair := pair_annotation externals
  cases map <;> cases build
  · refine PureRow.Satisfiable.of_one hw row hsig (ts := [.base .integer]) (by simp) ?_ ?_ ?_ rfl
      (integer_kinds _ rfl) (by precision_simp; exact ⟨rfl, rfl, rfl⟩) (inhabitant_typed (a := .set (.base .integer)) ⟨integer_sat _ _ _, base_annotation _⟩)
      (inhabitants_ground [.set (.base .integer)] _ (by simp))
    · refine ⟨rfl, ⟨rfl, integers_sat (P := program externals) (by simp [Ty.normTys, Ty.norm]) _⟩, ?_, rfl, ?_, ?_, ?_, ?_, ?_⟩
      all_goals precision_simp
    · precision_simp
    · precision_simp
  · refine PureRow.Satisfiable.of_one hw row hsig (ts := [.base .integer]) (by simp) ?_ ?_ ?_ rfl
      (integer_kinds _ rfl) (by precision_simp; exact ⟨rfl, rfl, rfl⟩) (inhabitant_typed (a := .list (.base .integer)) (base_annotation _))
      trivial
    · refine ⟨rfl, ⟨rfl, integers_sat (P := program externals) (by simp [Ty.normTys, Ty.norm]) _⟩, ?_, rfl, ?_, ?_, ?_, ?_, ?_⟩
      all_goals precision_simp
    · precision_simp
    · precision_simp
  · refine PureRow.Satisfiable.of_one hw row hsig (ts := [.base .integer, .base .integer]) (by simp) ?_ ?_ ?_ rfl
      ?_ (by precision_simp; exact ⟨rfl, rfl, rfl⟩)
      (inhabitant_typed (a := .map (.base .integer) (.base .integer)) ⟨integer_sat _ _ _, base_annotation _, base_annotation _⟩)
      (inhabitants_ground [.map (.base .integer) (.base .integer)] _ (by simp))
    · refine ⟨rfl, ⟨rfl, integers_sat (P := program externals) (by simp [Ty.normTys, Ty.norm]) _⟩, ?_, rfl, ?_, ?_, ?_, ?_, ?_⟩
      all_goals precision_simp
    · precision_simp
    · precision_simp
    · refine ⟨rfl, ?_⟩
      intro i a k ha hk
      rcases i with _ | _ | i <;> simp [StandardCollectionPrecision.signature, TypeCtx.valueParam] at ha hk
      all_goals (subst ha; subst hk; exact ⟨trivial, fun _ => by simp [Ty.core]⟩)
  · refine PureRow.Satisfiable.of_one hw row hsig (ts := [.base .integer, .base .integer]) (by simp) ?_ ?_ ?_ rfl
      ?_ (by precision_simp; exact ⟨rfl, rfl, rfl⟩) (inhabitant_typed (a := .list (.data "Pair" [.base .integer, .base .integer])) pair)
      trivial
    · refine ⟨rfl, ⟨rfl, integers_sat (P := program externals) (by simp [Ty.normTys, Ty.norm]) _⟩, ?_, rfl, ?_, ?_, ?_, ?_, ?_⟩
      all_goals precision_simp
    · precision_simp
    · precision_simp
    · refine ⟨rfl, ?_⟩
      intro i a k ha hk
      rcases i with _ | _ | i <;> simp [StandardCollectionPrecision.signature, TypeCtx.valueParam] at ha hk
      all_goals (subst ha; subst hk; exact ⟨trivial, fun _ => by simp [Ty.core]⟩)
end

/-- 二つの引数の依存列は、一つ目の値と、それを束縛した二つ目の引数の型の値から型付ける。 -/
theorem two_arguments {P B v w n m i j R E}
    (annotation : Ty.Annotation P [] [] (.dependentFn (.param n i (.param m j (.done R E)))))
    (typed : HasTypeVQ P B StoreTy.empty Qempty [] [] [] v i)
    (second : Ty.Annotation P [] [] (j.bind (Tel.argumentsEnv v)) →
      HasTypeVQ P B StoreTy.empty Qempty [] [] [] w (j.bind (Tel.argumentsEnv v))) :
    ∃ a e, HasTypeTelArgsQ P B StoreTy.empty Qempty [] [] [] [v, w] (.param n i (.param m j (.done R E))) a e ∧
      a.WF 0 0 0 ∧ a.Canonical ∧ Eff.WF 0 0 0 e ∧ e.Canonical := by
  have opened := Tel.annotation_open (by intro i a h; cases i <;> cases h) annotation typed
  rw [Tel.bind_param, Tel.bind_done] at opened
  obtain ⟨args, h1, h2, h3, h4⟩ := one_argument opened (second ⟨opened.wf.1, opened.sorted.1, opened.declared.1⟩)
  exact ⟨_, _, .param ⟨annotation.wf.1, annotation.sorted.1, annotation.declared.1⟩ typed
    (by rw [Tel.bind_param, Tel.bind_done]; exact args), h1, h2, h3, h4⟩

/-- 二つの引数を持ち、型引数をIntegerだけで具体化する依存の署名の行は、二つの値から契約の前提を満たす。 -/
theorem PureRow.Satisfiable.of_two {externals} (hw : (program externals).ExternalWF) (row : Primitive)
    {sg ts n m i j R E v w} (hsig : row.signature = sg) (hts : ∀ t ∈ ts, t = .base .integer)
    (admissible : PrimitiveAdmissible [] 0 sg Qempty ts [])
    (ranges : (builtins (program externals)).RangeAdmissible row.name sg [])
    (source : (Ty.dependentFn (Tel.instR [] sg.tel)).WF 0 (sg.tparams.map TParamDecl.kind).length 0)
    (rangeKinds : sg.rkinds = [])
    (kinds : TypeArgsKinded (program externals) [] ts (sg.tparams.map TParamDecl.kind))
    (inst : instantiatedTel (Tel.instR [] sg.tel) ts [] = .param n i (.param m j (.done R E)))
    (typed : HasTypeVQ (program externals) (builtins (program externals)) StoreTy.empty Qempty [] [] [] v i)
    (second : Ty.Annotation (program externals) [] [] (j.bind (Tel.argumentsEnv v)) →
      HasTypeVQ (program externals) (builtins (program externals)) StoreTy.empty Qempty [] [] [] w
        (j.bind (Tel.argumentsEnv v)))
    (ground : v.Ground ∧ w.Ground) : PureRow.Satisfiable (program externals) row.name := by
  subst hsig
  have annotation := instance_annotation hw row hts admissible.typeCount rangeKinds kinds
  rw [inst] at annotation
  obtain ⟨a, e, args, h1, h2, h3, h4⟩ := two_arguments annotation typed second
  refine PureRow.Satisfiable.of_arguments row rfl admissible ranges source kinds
    (fun t ht => by rw [hts t ht]; exact base_annotation _) (inst ▸ annotation) (inst ▸ args)
    (by intro x hx; simp at hx; rcases hx with rfl | rfl <;> first | exact ground.1 | exact ground.2)
    (fun t ht => by rw [hts t ht]; exact ⟨trivial, rfl⟩) ⟨h1, h2⟩ ⟨h3, h4⟩

section
open StandardHeadTail

private theorem append_tel :
    instantiatedTel (Tel.instR [] appendSignature.tel) [.base .integer] [] =
      .param "xs" (.list (.base .integer)) (.param "x" (.base .integer)
        (.done (.refined (.list (.base .integer)) (appendPredicate (.var 0) (.var 2))) Eff.empty)) := by
  dependent_simp [appendSignature, appendPredicate, length]

/-- List.appendの行は、型引数Integerと空の列・整数1で全欄を満たす。 -/
theorem PureRow.Satisfiable.append {externals} (hw : (program externals).ExternalWF) (row : Primitive)
    (hsig : row.signature = appendSignature) : PureRow.Satisfiable (program externals) row.name := by
  refine PureRow.Satisfiable.of_two hw row hsig (by simp) ?_ ?_ ?_ rfl (integer_kinds _ rfl) append_tel
    (inhabitant_typed (a := .list (.base .integer)) (base_annotation _)) (fun _ => sample_typed .integer) ⟨trivial, trivial⟩
  · constructor <;> dependent_simp [appendSignature, appendPredicate, length]
  · dependent_simp [appendSignature]
  · dependent_simp [appendSignature, appendPredicate, length]
end

section
open StandardMapReplaceValues

private theorem replace_tel :
    instantiatedTel (Tel.instR [] (StandardMapReplaceValues.signature signatureBase.sat).tel)
      [.base .integer, .base .integer, .base .integer] [] =
      .param "m" (.map (.base .integer) (.base .integer))
        (.param "values" (.refined (.list (.base .integer)) (.eq (length (.var 0)) (size (.var 1))))
          (.done (.refined (.map (.base .integer) (.base .integer)) (.eq (size (.var 0)) (size (.var 2)))) Eff.empty)) := by
  dependent_simp [StandardMapReplaceValues.signature, size, length]

private theorem replace_values_typed {externals}
    (ann : Ty.Annotation (program externals) [] []
      (Ty.bind (Tel.argumentsEnv (.mapV [] [])) (.refined (.list (.base .integer)) (.eq (length (.var 0)) (size (.var 1)))))) :
    HasTypeVQ (program externals) (builtins (program externals)) StoreTy.empty Qempty [] [] [] (.list [])
      (Ty.bind (Tel.argumentsEnv (.mapV [] [])) (.refined (.list (.base .integer)) (.eq (length (.var 0)) (size (.var 1))))) := by
  have h : Ty.bind (Tel.argumentsEnv (.mapV [] [])) (.refined (.list (.base .integer)) (.eq (length (.var 0)) (size (.var 1)))) =
      .refined (.list (.base .integer)) (.eq (length (.var 0)) (size (.mapValue [] []))) := by
    dependent_simp [size, length, Val.toTerm?, Val.toTermSlots, bindSlots]
  rw [h] at ann ⊢
  exact StandardHeadTail.refine_value (inhabitant_typed (a := .list (.base .integer)) (base_annotation _)) rfl
    (sort := .list) rfl ann rfl

/-- 内部の %Map.replaceValues の行は、型引数Integer三つと空の写像・空の列で全欄を満たす。 -/
theorem PureRow.Satisfiable.replaceValues {externals} (hw : (program externals).ExternalWF) (row : Primitive)
    (hsig : row.signature = StandardMapReplaceValues.signature signatureBase.sat) : PureRow.Satisfiable (program externals) row.name := by
  refine PureRow.Satisfiable.of_two hw row hsig (ts := [.base .integer, .base .integer, .base .integer]) (by simp)
    ?_ ?_ ?_ rfl ?_ replace_tel
    (inhabitant_typed (a := .map (.base .integer) (.base .integer)) ⟨integer_sat _ _ _, base_annotation _, base_annotation _⟩)
    replace_values_typed ⟨⟨trivial, trivial⟩, trivial⟩
  · refine ⟨rfl, ⟨rfl, integers_sat (P := program externals) (by simp [Ty.normTys, Ty.norm]) _⟩, ?_, rfl, ?_, ?_, ?_, ?_, ?_⟩
    all_goals dependent_simp [StandardMapReplaceValues.signature, size, length]
  · dependent_simp [StandardMapReplaceValues.signature]
  · dependent_simp [StandardMapReplaceValues.signature, size, length]
  · refine ⟨rfl, ?_⟩
    intro i a k ha hk
    rcases i with _ | _ | _ | i <;> simp [StandardMapReplaceValues.signature, TypeCtx.valueParam] at ha hk
    all_goals (subst ha; subst hk; exact ⟨trivial, fun _ => by simp [Ty.core]⟩)
end

/-- String・Bytes・List・Map・Setの全79行は、外部宣言の表が整形式な合成プログラムで、契約の前提を満たす入力を持つ。 -/
theorem collection_inputs (externals : List (ExternalKey × ExternalDecl)) (hw : (program externals).ExternalWF)
    (row : Primitive) (collection : row.collection = true) :
    PureRow.Satisfiable (program externals) row.name := by
  cases row
  case p076 => exact PureRow.Satisfiable.replaceValues hw .p076 rfl
  case p120 => exact PureRow.Satisfiable.bytesOrdinary .p120 .concatenate rfl
  case p121 => exact PureRow.Satisfiable.bytesOrdinary .p121 .empty rfl
  case p122 => exact PureRow.Satisfiable.bytesOrdinary .p122 .fromBinary rfl
  case p123 => exact PureRow.Satisfiable.bytesOrdinary .p123 .fromHex rfl
  case p124 => exact PureRow.Satisfiable.bytesOrdinary .p124 .fromIntegers rfl
  case p125 => exact PureRow.Satisfiable.bytes .p125 .bytesFromList rfl
  case p126 => exact PureRow.Satisfiable.bytesOrdinary .p126 .fromSigned rfl
  case p127 => exact PureRow.Satisfiable.bytesOrdinary .p127 .fromUnsigned rfl
  case p128 => exact PureRow.Satisfiable.bytesOrdinary .p128 .get rfl
  case p129 => exact PureRow.Satisfiable.bytes .p129 .bytesLength rfl
  case p130 => exact PureRow.Satisfiable.bytesOrdinary .p130 .readSigned rfl
  case p131 => exact PureRow.Satisfiable.bytesOrdinary .p131 .readUnsigned rfl
  case p132 => exact PureRow.Satisfiable.bytesOrdinary .p132 .slice rfl
  case p133 => exact PureRow.Satisfiable.bytesOrdinary .p133 .toBinary rfl
  case p134 => exact PureRow.Satisfiable.bytesOrdinary .p134 .toHex rfl
  case p135 => exact PureRow.Satisfiable.bytes .p135 .bytesToList rfl
  case p255 => exact PureRow.Satisfiable.append hw .p255 rfl
  case p256 => exact PureRow.Satisfiable.list .p256 .concatenate rfl
  case p257 => exact PureRow.Satisfiable.listRemaining .p257 .contains rfl
  case p258 => exact PureRow.Satisfiable.listRemaining .p258 .drop rfl
  case p259 => exact PureRow.Satisfiable.listRemaining .p259 .get rfl
  case p260 => exact PureRow.Satisfiable.headTail hw .p260 false rfl
  case p261 => exact PureRow.Satisfiable.list .p261 .isEmpty rfl
  case p262 => exact PureRow.Satisfiable.list .p262 .length rfl
  case p263 => exact PureRow.Satisfiable.list .p263 .prepend rfl
  case p264 => exact PureRow.Satisfiable.range .p264 rfl
  case p265 => exact PureRow.Satisfiable.list .p265 .reverse rfl
  case p266 => exact PureRow.Satisfiable.listRemaining .p266 .sort rfl
  case p267 => exact PureRow.Satisfiable.headTail hw .p267 true rfl
  case p268 => exact PureRow.Satisfiable.listRemaining .p268 .take rfl
  case p269 => exact PureRow.Satisfiable.map .p269 .contains rfl
  case p270 => exact PureRow.Satisfiable.map .p270 .empty rfl
  case p271 => exact PureRow.Satisfiable.precision hw .p271 true true rfl
  case p272 => exact PureRow.Satisfiable.map .p272 .get rfl
  case p273 => exact PureRow.Satisfiable.map .p273 .keys rfl
  case p274 => exact PureRow.Satisfiable.map .p274 .remove rfl
  case p275 => exact PureRow.Satisfiable.map .p275 .set rfl
  case p276 => exact PureRow.Satisfiable.map .p276 .size rfl
  case p277 => exact PureRow.Satisfiable.precision hw .p277 true false rfl
  case p278 => exact PureRow.Satisfiable.map .p278 .values rfl
  case p284 => exact PureRow.Satisfiable.set .p284 .add rfl
  case p285 => exact PureRow.Satisfiable.set .p285 .contains rfl
  case p286 => exact PureRow.Satisfiable.set .p286 .difference rfl
  case p287 => exact PureRow.Satisfiable.set .p287 .empty rfl
  case p288 => exact PureRow.Satisfiable.precision hw .p288 false true rfl
  case p289 => exact PureRow.Satisfiable.set .p289 .intersection rfl
  case p290 => exact PureRow.Satisfiable.set .p290 .remove rfl
  case p291 => exact PureRow.Satisfiable.set .p291 .size rfl
  case p292 => exact PureRow.Satisfiable.precision hw .p292 false false rfl
  case p293 => exact PureRow.Satisfiable.set .p293 .union rfl
  case p294 => exact PureRow.Satisfiable.string .p294 .byteIndexOf rfl
  case p295 => exact PureRow.Satisfiable.bytes .p295 .stringBytes rfl
  case p296 => exact PureRow.Satisfiable.string .p296 .byteSlice rfl
  case p297 => exact PureRow.Satisfiable.string .p297 .characterAt rfl
  case p298 => exact PureRow.Satisfiable.bytes .p298 .stringCharacters rfl
  case p299 => exact PureRow.Satisfiable.string .p299 .characterSlice rfl
  case p300 => exact PureRow.Satisfiable.string .p300 .characters rfl
  case p301 => exact PureRow.Satisfiable.string .p301 .contains rfl
  case p302 => exact PureRow.Satisfiable.string .p302 .displayWidth rfl
  case p303 => exact PureRow.Satisfiable.string .p303 .displayWidthCJK rfl
  case p304 => exact PureRow.Satisfiable.string .p304 .displayWidthPadEnd rfl
  case p305 => exact PureRow.Satisfiable.string .p305 .displayWidthPadEndCJK rfl
  case p306 => exact PureRow.Satisfiable.string .p306 .displayWidthPadStart rfl
  case p307 => exact PureRow.Satisfiable.string .p307 .displayWidthPadStartCJK rfl
  case p308 => exact PureRow.Satisfiable.string .p308 .endsWith rfl
  case p309 => exact PureRow.Satisfiable.string .p309 .fromCharacters rfl
  case p310 => exact PureRow.Satisfiable.string .p310 .fromUTF8 rfl
  case p311 => exact PureRow.Satisfiable.string .p311 .isEmpty rfl
  case p312 => exact PureRow.Satisfiable.string .p312 .join rfl
  case p313 => exact PureRow.Satisfiable.string .p313 .lines rfl
  case p314 => exact PureRow.Satisfiable.string .p314 .repeat rfl
  case p315 => exact PureRow.Satisfiable.string .p315 .replace rfl
  case p316 => exact PureRow.Satisfiable.string .p316 .split rfl
  case p317 => exact PureRow.Satisfiable.string .p317 .startsWith rfl
  case p318 => exact PureRow.Satisfiable.string .p318 .toLowercase rfl
  case p319 => exact PureRow.Satisfiable.string .p319 .toUTF8 rfl
  case p320 => exact PureRow.Satisfiable.string .p320 .toUppercase rfl
  case p321 => exact PureRow.Satisfiable.string .p321 .trim rfl
  all_goals cases collection

end
end Benitoite.Release.Refinement.StandardModel
