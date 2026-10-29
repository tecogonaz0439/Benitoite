import Benitoite.Surface.CheckProgramSound
import Benitoite.Surface.Theorems
import Benitoite.Release.Examples

/-!
# 二引数クラスの宣言・辞書・実行の具体例

既存の Program / Declarations / Check を使い、型構成子の受理から確かめる。
種類検査と任意の実装の法則は証明しない
（設計書 01-12「Resultの法則と二引数辞書の具体例」）。
-/
namespace Benitoite.Surface.Monad2Examples
open Benitoite.Release CheckTools Check CheckTables

set_option maxRecDepth 8192
set_option maxHeartbeats 4000000

private def intTy : Ty := .base .integer
private def strTy : Ty := .base .string
private def row : Eff := Eff.ofAtoms (fun a => a == .rho 0)

/-- F はメソッドの型パラメータの直後に束縛される。 -/
def mapSig : MethSig :=
  { tparams := [{}, {}, {}], neffs := 1, names := ["x", "f"],
    params := [.tapp 3 [.tvar 0, .tvar 2], .fn ["value"] [.tvar 0] (.tvar 1) row],
    ret := .tapp 3 [.tvar 1, .tvar 2], eff := row }

/-- pure はエフェクトを持たない。 -/
def pureSig : MethSig :=
  { tparams := [{}, {}], neffs := 0, names := ["x"], params := [.tvar 0],
    ret := .tapp 2 [.tvar 0, .tvar 1], eff := Eff.empty }

/-- apply の関数側と値側は同じ X を使う。 -/
def applySig : MethSig :=
  { tparams := [{}, {}, {}], neffs := 1, names := ["fs", "x"],
    params := [.tapp 3 [.fn ["value"] [.tvar 0] (.tvar 1) row, .tvar 2],
      .tapp 3 [.tvar 0, .tvar 2]], ret := .tapp 3 [.tvar 1, .tvar 2], eff := row }

/-- flatMap のコールバックも同じ F と X を返す。 -/
def flatMapSig : MethSig :=
  { mapSig with params := [.tapp 3 [.tvar 0, .tvar 2],
      .fn ["value"] [.tvar 0] (.tapp 3 [.tvar 1, .tvar 2]) row] }

private def classMaterials : List (ClassName × ClassMaterial) :=
  [("Functor2", ⟨[], [("map", mapSig)]⟩),
   ("Applicative2", ⟨["Functor2"], [("pure", pureSig), ("apply", applySig)]⟩),
   ("Monad2", ⟨["Applicative2"], [("flatMap", flatMapSig)]⟩)]

private def builtinMaterial : BuiltinMaterial := ⟨[], [], "get", "set"⟩
private def builtins : Builtins := CheckTables.builtins [] [] builtinMaterial
private def selectOp : Operator → Ty → Option PrimName := fun _ _ => none
private def opPrim : OpPrim := makeOpPrim selectOp
private def initialMaterials : Materials :=
  { defs := [], conFields := [], accessors := [], data := [], ops := [], effects := [],
    classes := classMaterials, impls := [], trustedFuns := [], trustedImpls := [] }

/-- 裸の Result は、既存の本体の型の規則で許される。 -/
theorem result_constructor_wf : Ty.WF 0 0 (.ctor (.data "Result")) := trivial

/-- クラス引数に渡す空制約の型パラメータを、実際の組み込み表で満たす。 -/
theorem result_constructor_sat :
    SatAll builtins [] [.ctor (.data "Result")] [{}] := by
  refine ⟨rfl, ?_⟩
  intro i t p ht hp
  cases i with
  | zero => cases ht; cases hp; rfl
  | succ i => simp at ht

-- 二つの型は同じ成功先行の形を持つが、別の宣言と辞書を使う。
private def dataMaterial (name : String) : DataMaterial :=
  ⟨name, 2, [(name ++ ".Ok", ⟨name, 2, [.tvar 0]⟩),
    (name ++ ".Error", ⟨name, 2, [.tvar 1]⟩)]⟩

private def one (e : Expr) : Exprs := .cons e .nil
private def two (x y : Expr) : Exprs := .cons x (one y)
private def call1 (f x : Expr) : Expr := .call f [some "value"] [0] (one x)
private def ok (name : String) (a x : Ty) (e : Expr) : Expr :=
  .conCall (name ++ ".Ok") [a, x] (one e)
private def err (name : String) (a x : Ty) (e : Expr) : Expr :=
  .conCall (name ++ ".Error") [a, x] (one e)
private def casesResult (name : String) (ret : Ty) (scrutinee yes no : Expr) : Expr :=
  .matchE ret scrutinee
    (.cons [⟨.con (some name) (name ++ ".Ok") [.var], [0]⟩] none (.last yes)
      (.cons [⟨.con (some name) (name ++ ".Error") [.var], [0]⟩] none (.last no) .nil))

private def mapBody (name : String) : Block :=
  let ret := Ty.data name [.tvar 1, .tvar 2]
  .last (.returnE ret (casesResult name ret (.local 1)
    (ok name (.tvar 1) (.tvar 2) (call1 (.local 1) (.local 0)))
    (err name (.tvar 1) (.tvar 2) (.local 0))))

private def pureBody (name : String) : Block :=
  .last (.returnE (.data name [.tvar 0, .tvar 1])
    (ok name (.tvar 0) (.tvar 1) (.local 0)))

private def applyBody (name : String) : Block :=
  let ret := Ty.data name [.tvar 1, .tvar 2]
  .last (.returnE ret (casesResult name ret (.local 1)
    (casesResult name ret (.local 1)
      (ok name (.tvar 1) (.tvar 2) (call1 (.local 1) (.local 0)))
      (err name (.tvar 1) (.tvar 2) (.local 0)))
    (err name (.tvar 1) (.tvar 2) (.local 0))))

private def flatMapBody (name : String) : Block :=
  let ret := Ty.data name [.tvar 1, .tvar 2]
  .last (.returnE ret (casesResult name ret (.local 1)
    (call1 (.local 1) (.local 0)) (err name (.tvar 1) (.tvar 2) (.local 0))))

private def implMaterials (name : String) : List (ImplName × ImplMaterial) :=
  [(name ++ "Functor2", ⟨⟨[], [], "Functor2", .ctor (.data name)⟩, [],
      [("map", ⟨["x", "f"], mapBody name⟩)]⟩),
   (name ++ "Applicative2", ⟨⟨[], [], "Applicative2", .ctor (.data name)⟩,
      [("Functor2", .impl (name ++ "Functor2") [] [])],
      [("pure", ⟨["x"], pureBody name⟩), ("apply", ⟨["fs", "x"], applyBody name⟩)]⟩),
   (name ++ "Monad2", ⟨⟨[], [], "Monad2", .ctor (.data name)⟩,
      [("Applicative2", .impl (name ++ "Applicative2") [] [])],
      [("flatMap", ⟨["x", "f"], flatMapBody name⟩)]⟩)]

/-- F[_, _]: Monad2 を受け取り、上位の map を呼ぶ関数。辞書は値引数より前。 -/
def genericMap : Def :=
  { tparams := [{}, {}, {}, {}], neffs := 1, names := ["x", "f"],
    params := mapSig.params, ret := mapSig.ret, eff := row,
    dictParams := [("Monad2", 3)],
    body := .last (.returnE mapSig.ret
      (.call (.methName (.super (.super (.local 2) "Applicative2") "Functor2")
        "map" [.tvar 0, .tvar 1, .tvar 2] [row] [] ["x", "f"] mapSig.params)
        [some "x", some "f"] [0, 1] (two (.local 1) (.local 0)))) }

/-- 辞書の引数は値引数の前に置き、本体からは番号2で参照する。 -/
theorem generic_dictionary_position :
    (desugarDef opPrim genericMap).names = ["%dict1", "x", "f"] ∧
    (desugarDef opPrim genericMap).params = .dict "Monad2" (.tvar 3) :: mapSig.params := by
  constructor <;> rfl

/-- 信頼する関数・実装を補わずに、本体の全プログラム検査へ渡す材料。 -/
def materials : Materials :=
  { initialMaterials with
    defs := [("genericMap", genericMap)],
    data := [dataMaterial "Result", dataMaterial "UserResult"],
    impls := implMaterials "Result" ++ implMaterials "UserResult" }

private def input : Input :=
  materials.input builtins (satB []) (admitsDec [] []) opPrim [.rho 0]

/-- 全メソッドの実名、上位辞書、汎用関数の辞書引数も検査する。 -/
theorem program_checked : checkProgram input materials materials.names = .ok () := by rfl

/-- 射影で実名を消す前の六実装も、クラスの契約名と一致する。 -/
theorem implementation_contracts :
    ∀ n id, CheckTables.lookup (materials.impls.map fun (n,i) => (n,i.input)) n = some id →
      id.ContractsMatch materials.declarations := by
  exact checkProgram_contracts (by decide) program_checked

private theorem declarations_atoms : materials.declarations.AtomsIn [.rho 0] := by
  constructor
  · intro n d h
    have hd : materials.declarations.funs n = (lookup materials.defs n).map Def.toFunDecl := by
      unfold Materials.declarations CheckTables.extend Materials.program Program.declarations Program.lookupFun
      by_cases hn : "genericMap" = n <;> simp [materials, initialMaterials, CheckTables.lookup, hn]
    rw [hd] at h
    have hm : (n, d) ∈ materials.defs.map (fun (n,d) => (n,d.toFunDecl)) := by
      apply lookup_mem
      simpa [CheckTables.lookup, List.find?_map, Function.comp_def, Option.map_map] using h
    simp [materials] at hm
    rcases hm with ⟨rfl, rfl⟩
    simp [genericMap, mapSig, FunDecl.dictTys, Ty.AtomsIn, Tys.AtomsIn,
      Ty.Support, Ty.SupportList, Eff.Support, row, Eff.ofAtoms]
  · constructor
    · intro n cd h
      have hm := lookup_mem h
      simp [materials, dataMaterial] at hm
      rcases hm with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
        simp [Tys.AtomsIn, Ty.SupportList, Ty.Support]
    · constructor
      · intro n od h; cases h
      · constructor
        · intro cl cd m ms h hc
          have hm := lookup_mem h
          simp [materials, initialMaterials, classMaterials] at hm
          rcases hm with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
          · have hh := lookup_mem hc
            simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hh
            rcases hh with ⟨rfl, rfl⟩
            simp [mapSig, Ty.AtomsIn, Ty.Support, Ty.SupportList, Eff.Support, row, Eff.ofAtoms]
          · have hh := lookup_mem hc
            simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hh
            rcases hh with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
            · simp [pureSig, Ty.AtomsIn, Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]
            · simp [applySig, Ty.AtomsIn, Ty.Support, Ty.SupportList, Eff.Support, row, Eff.ofAtoms]
          · have hh := lookup_mem hc
            simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hh
            rcases hh with ⟨rfl, rfl⟩
            simp [flatMapSig, mapSig, Ty.AtomsIn, Ty.Support, Ty.SupportList, Eff.Support, row, Eff.ofAtoms]
        · intro n id h
          change ((CheckTables.lookup (materials.impls.map fun (n,i) => (n,i.decl)) n).map ImplDecl.toImplSig).or none = some id at h
          have hm : (n,id) ∈ materials.impls.map (fun (n,i) => (n,i.signature)) := by
            apply lookup_mem
            simpa [CheckTables.lookup, List.find?_map, Function.comp_def, Option.map_map,
              ImplMaterial.decl, ImplMaterial.input, ImplInput.decl] using h
          simp [materials, implMaterials] at hm
          rcases hm with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ |
            ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;> trivial

private theorem body_atoms (name : String) :
    (mapBody name).AtomsIn [.rho 0] ∧ (pureBody name).AtomsIn [.rho 0] ∧
    (applyBody name).AtomsIn [.rho 0] ∧ (flatMapBody name).AtomsIn [.rho 0] := by
  simp [mapBody, pureBody, applyBody, flatMapBody, casesResult, ok, err, call1, one,
    Block.AtomsIn, Expr.AtomsIn, Exprs.AtomsIn, Arms.AtomsIn,
    Ty.AtomsIn, Tys.AtomsIn, Ty.Support, Ty.SupportList]

private theorem impl_bodies_of_lists (i : ImplMaterial)
    (hs : ∀ entry ∈ i.supers, entry.2.AtomsIn [.rho 0])
    (hm : ∀ entry ∈ i.methods, entry.2.body.AtomsIn [.rho 0]) :
    ImplBodiesAtoms [.rho 0] i.decl := by
  constructor
  · intro s d h
    exact hs (s,d) (lookup_mem h)
  · intro m b h
    change (CheckTables.lookup i.methods m).map MethodInput.body = some b at h
    cases he : CheckTables.lookup i.methods m with
    | none => simp [he] at h
    | some method =>
      simp only [he, Option.map_some, Option.some.injEq] at h
      subst b
      exact hm (m,method) (lookup_mem he)

private theorem impl_bodies_atoms (name : String) :
    ∀ entry ∈ implMaterials name, ImplBodiesAtoms [.rho 0] entry.2.decl := by
  intro entry he
  simp only [implMaterials, List.mem_cons, List.not_mem_nil, or_false] at he
  rcases he with rfl | rfl | rfl
  all_goals
    apply impl_bodies_of_lists
    · simp [DictEv.AtomsIn, DictEvs.AtomsIn, Tys.AtomsIn, Ty.SupportList]
    · simp only [List.mem_cons, List.not_mem_nil, or_false, forall_eq_or_imp, forall_eq]
      first | exact (body_atoms name).1
            | exact ⟨(body_atoms name).2.1, (body_atoms name).2.2.1⟩
            | exact (body_atoms name).2.2.2

/-- 検査の成功を、既存の健全性定理から本体の型付けへ接続する。 -/
theorem program_typed : materials.program.WellTyped builtins opPrim := by
  apply checkProgram_empty (S := []) (raw := []) (b := builtinMaterial)
    (select := selectOp) (atoms := [.rho 0]) rfl rfl declarations_atoms
  · intro b s h; cases h
  · intro n d h
    have hm := lookup_mem h
    simp [materials] at hm
    rcases hm with ⟨rfl, rfl⟩
    simp [genericMap, mapSig, two, one, Block.AtomsIn, Expr.AtomsIn, Exprs.AtomsIn,
      DictEv.AtomsIn, DictEvs.AtomsIn, Ty.AtomsIn, Tys.AtomsIn, Ty.Support, Ty.SupportList,
      Eff.Support, row, Eff.ofAtoms]
  · intro n id h
    have hm := lookup_mem h
    obtain ⟨⟨n,i⟩, hi, he⟩ := List.mem_map.mp hm
    cases he
    simp only [materials, List.mem_append] at hi
    rcases hi with hi | hi
    · exact impl_bodies_atoms "Result" (n,i) hi
    · exact impl_bodies_atoms "UserResult" (n,i) hi
  · rfl
  · decide
  · exact program_checked

private theorem signatures_scoped : mapSig.Scoped ∧ pureSig.Scoped ∧
    applySig.Scoped ∧ flatMapSig.Scoped := by
  simp [MethSig.Scoped, mapSig, pureSig, applySig, flatMapSig,
    NamesWF, Ty.VarsIn, Ty.VarsInList, Eff.VarsIn, Eff.empty, row, Eff.ofAtoms, Eff.Canonical, Eff.norm, Ty.normTys]

private theorem bodies_scoped (name : String) :
    (mapBody name).Scoped 3 (· < 1) 2 ∧ (pureBody name).Scoped 2 (fun _ => False) 1 ∧
    (applyBody name).Scoped 3 (· < 1) 2 ∧ (flatMapBody name).Scoped 3 (· < 1) 2 := by
  simp [mapBody, pureBody, applyBody, flatMapBody, casesResult, ok, err, call1, one,
    Block.Scoped, Expr.Scoped, Exprs.Scoped, Arms.Scoped,
    Alternative.toCoreList, Alternative.toCore, Pattern.toCore, Pattern.toCoreList,
    Arm.bindersOf, Pat.binders, Pat.bindersList, Ty.VarsIn, Ty.VarsInList]

private theorem impl_scoped (name : String) :
    ∀ entry ∈ implMaterials name, entry.2.decl.Scoped materials.program.declarations := by
  intro entry he
  simp only [implMaterials, List.mem_cons, List.not_mem_nil, or_false] at he
  rcases he with rfl | rfl | rfl
  all_goals
    refine ⟨by simp [ImplMaterial.decl, ImplMaterial.input, ImplInput.decl], trivial, ?_, ?_⟩
    · intro s u h
      simp only [ImplMaterial.decl, ImplMaterial.input, ImplInput.decl] at h
      first
      | cases h
      | have hm := lookup_mem h
        simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hm
        rcases hm with ⟨rfl, rfl⟩
        trivial
  · intro cd m ms body hc hm hb
    cases hc
    have hh := lookup_mem hm
    simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hh
    rcases hh with ⟨rfl, rfl⟩
    cases hb
    exact (bodies_scoped name).1
  · intro cd m ms body hc hm hb
    cases hc
    have hh := lookup_mem hm
    simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hh
    rcases hh with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · cases hb; exact (bodies_scoped name).2.1
    · cases hb; exact (bodies_scoped name).2.2.1
  · intro cd m ms body hc hm hb
    cases hc
    have hh := lookup_mem hm
    simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hh
    rcases hh with ⟨rfl, rfl⟩
    cases hb
    exact (bodies_scoped name).2.2.2

/-- 脱糖の型保存が要求する番号の範囲も、同じ宣言で満たす。 -/
theorem program_wellFormed : materials.program.WellFormed := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro c names h; cases h
  · intro n d h
    have hm := lookup_mem h
    simp [materials] at hm
    rcases hm with ⟨rfl, rfl⟩
    simp [Def.Scoped, genericMap, mapSig, FunDecl.coreNames, FunDecl.dictTys,
      internalNames, NamesWF, two, one, Block.Scoped, Expr.Scoped, Exprs.Scoped,
      DictEv.Scoped, DictEv.ScopedList, Ty.VarsIn, Ty.VarsInList, Eff.VarsInList,
      Eff.VarsIn, row, Eff.ofAtoms, Eff.Canonical, Eff.norm, Ty.normTys]
    decide
  · intro n cd h
    have hm := lookup_mem h
    simp [materials, dataMaterial] at hm
    rcases hm with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      simp [ConDecl.Scoped, Ty.VarsInList, Ty.VarsIn]
  · intro n od h; cases h
  · intro l os o h; cases h
  · intro o od h; cases h
  · intro cl cd h m ms hc
    have hm := lookup_mem h
    simp [materials, initialMaterials, classMaterials] at hm
    rcases hm with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · have hh := lookup_mem hc
      simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hh
      rcases hh with ⟨rfl, rfl⟩
      exact signatures_scoped.1
    · have hh := lookup_mem hc
      simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hh
      rcases hh with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
      · exact signatures_scoped.2.1
      · exact signatures_scoped.2.2.1
    · have hh := lookup_mem hc
      simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hh
      rcases hh with ⟨rfl, rfl⟩
      exact signatures_scoped.2.2.2
  · intro n id h
    have hm := lookup_mem h
    obtain ⟨⟨n,i⟩, hi, he⟩ := List.mem_map.mp hm
    cases he
    simp only [materials, List.mem_append] at hi
    rcases hi with hi | hi
    · exact impl_scoped "Result" (n,i) hi
    · exact impl_scoped "UserResult" (n,i) hi
  · intro f c k h; cases h

/-- 三クラスを含むプログラム全体に、既存の性質1を適用する。 -/
theorem desugared_typed :
    (desugarProgram opPrim materials.program).WellFormed ∧
    (desugarProgram opPrim materials.program).WellTyped builtins ∧
    (desugarProgram opPrim materials.program).EffectsOk builtins := by
  exact desugar_typed program_wellFormed program_typed (by intro b s h; cases h)

private def resultTy (name : String) : Ty := .data name [intTy, strTy]
private def callbackTy : Ty := .fn ["value"] [intTy] intTy Eff.empty
private def projected (d : DictEv) (m : String) : DictEv :=
  if m == "map" then .super (.super d "Applicative2") "Functor2"
  else if m == "flatMap" then d else .super d "Applicative2"

private def methodValue (name m : String) (d : DictEv := .local 0) : Expr :=
  let r := resultTy name
  let (names, ps) := match m with
    | "pure" => (["x"], [intTy])
    | "apply" => (["fs", "x"], [.data name [callbackTy, strTy], r])
    | "flatMap" => (["x", "f"], [r, .fn ["value"] [intTy] r Eff.empty])
    | _ => (["x", "f"], [r, callbackTy])
  .methName (projected d m) m (if m == "pure" then [intTy, strTy] else [intTy, intTy, strTy])
    (if m == "pure" then [] else [Eff.empty]) [] names ps

/-- 値化したmapの外側の辞書は、二つの値引数の下で番号2になる。 -/
theorem map_value_capture :
    desugarExpr opPrim .other (methodValue "Result" "map") =
      .ret (.lam ["x", "f"] [resultTy "Result", callbackTy]
        (.meth (.super (.super (.var 2) "Applicative2") "Functor2") "map"
          [intTy, intTy, strTy] [Eff.empty] [.var 1, .var 0])) := rfl

/-- flatMapの値化も、二つの引数の下へ外側の辞書を移す。 -/
theorem flatMap_value_capture :
    desugarExpr opPrim .other (methodValue "Result" "flatMap") =
      .ret (.lam ["x", "f"] [resultTy "Result", .fn ["value"] [intTy] (resultTy "Result") Eff.empty]
        (.meth (.var 2) "flatMap" [intTy, intTy, strTy] [Eff.empty] [.var 1, .var 0])) := rfl

private def integer (n : Integer64Literal) : Expr := .literal (.integer n)
private def text (s : String) : Expr := .literal (.string s)
private def valueCallback : Expr :=
  .lam ["value"] [intTy] intTy Eff.empty (.last (.returnE intTy (integer ⟨42, by decide⟩)))
private def resultCallback (name : String) (fail : Bool) : Expr :=
  .lam ["value"] [intTy] (resultTy name) Eff.empty
    (.last (.returnE (resultTy name)
      (if fail then err name intTy strTy (text "callback") else ok name intTy strTy (.local 0))))

private def invoke (name m : String) (x f : Expr) (valued : Bool := false) : Expr :=
  .call (if valued then .paren (methodValue name m) else methodValue name m)
    [some (if m == "apply" then "fs" else "x"), some (if m == "apply" then "x" else "f")]
    [0, 1] (two x f)

private def genericCall (name : String) (x : Expr) : Expr :=
  .call (.funDicts "genericMap" [intTy, intTy, strTy, .ctor (.data name)] [Eff.empty]
    [.local 0] ["x", "f"] [resultTy name, callbackTy])
    [some "x", some "f"] [0, 1] (two x valueCallback)

-- 期待値は本体の実行や小モデルの関数から作らず、各入力に固定する。
private def cases (name : String) : List (Expr × (String × String)) :=
  let yes := ok name intTy strTy (integer ⟨7, by decide⟩)
  let no := err name intTy strTy (text "input")
  [(invoke name "map" yes valueCallback, (name ++ ".Ok", "42")),
   (invoke name "map" no valueCallback true, (name ++ ".Error", "input")),
   (invoke name "flatMap" yes (resultCallback name false) true, (name ++ ".Ok", "7")),
   (invoke name "flatMap" yes (resultCallback name true), (name ++ ".Error", "callback")),
   (invoke name "flatMap" no (resultCallback name false) true, (name ++ ".Error", "input")),
   (.call (methodValue name "pure") [some "x"] [0] (one (integer ⟨7, by decide⟩)), (name ++ ".Ok", "7")),
   (invoke name "apply" (ok name callbackTy strTy valueCallback) yes, (name ++ ".Ok", "42")),
   (invoke name "apply" (ok name callbackTy strTy valueCallback) no, (name ++ ".Error", "input")),
   (invoke name "apply" (err name callbackTy strTy (text "function")) yes, (name ++ ".Error", "function")),
   (invoke name "apply" (err name callbackTy strTy (text "function")) no, (name ++ ".Error", "function")),
   (genericCall name yes, (name ++ ".Ok", "42")),
   (genericCall name no, (name ++ ".Error", "input"))]

private def checkedCases (name : String) : Bool :=
  (cases name).all fun (e,_) =>
    match checkExpr input .strict [] [some (.dict "Monad2" (.ctor (.data name)))] none .other [] e with
    | .ok (t,eff) => tyEq [.rho 0] t (resultTy name) && effEq [.rho 0] eff Eff.empty
    | .error _ => false

/-- 同じ独立入力を、型検査から辞書の実行まで通す。 -/
theorem expressions_checked : checkedCases "Result" = true ∧ checkedCases "UserResult" = true := by
  constructor <;> rfl

private noncomputable def execute (name : String) (e : Expr) : Option (String × String) :=
  let body := (desugarExpr opPrim .other e).instantiate [.dict (name ++ "Monad2") [] []]
  match (Release.run (desugarProgram opPrim materials.program) builtins
      Release.Examples.oracle Release.Examples.rel Release.Examples.fresh 200
      (.run body [] Store.empty) []).1 with
  | .run (.ret (.con c _ [.const (.integer n)])) [] _ => some (c, toString n.toInt)
  | .run (.ret (.con c _ [.const (.string s)])) [] _ => some (c,s)
  | _ => none

/-- Ok/Error、二重Errorの優先順、上位辞書、値化したmap/flatMap、利用者型の実行。 -/
theorem executions_expected :
    (cases "Result").map (fun (e,_) => execute "Result" e) =
      (cases "Result").map (fun (_,expected) => some expected) ∧
    (cases "UserResult").map (fun (e,_) => execute "UserResult" e) =
      (cases "UserResult").map (fun (_,expected) => some expected) := by
  constructor <;> decide

private def mismatchedErrorCall : Expr :=
  invoke "Result" "flatMap" (ok "Result" intTy strTy (integer ⟨7, by decide⟩))
    (.lam ["value"] [intTy] (.data "Result" [intTy, intTy]) Eff.empty
      (.last (.returnE (.data "Result" [intTy, intTy])
        (ok "Result" intTy intTy (.local 0)))))

/-- X を暗黙に変換せず、コールバックの結果型の位置で拒否する。 -/
theorem mismatched_error_rejected :
    (checkExpr input .strict [] [some (.dict "Monad2" (.ctor (.data "Result")))]
      none .other [] mismatchedErrorCall).map (fun _ => true) =
        .error ⟨[1, 1], "type is not included in the expected type"⟩ := rfl

/-- 同じ二引数形でも別の型の辞書を、Result のメソッドへ使えない。 -/
theorem wrong_target_rejected :
    (checkExpr input .strict [] [some (.dict "Monad2" (.ctor (.data "UserResult")))]
      none .other [] (methodValue "Result" "map")).map (fun _ => true) =
        .error ⟨[], "method parameter annotation mismatch"⟩ := rfl

/-- 二段の上位射影も、裸の型構成子を対象とする辞書として検査する。 -/
theorem constructor_dictionary_checked :
    (checkDict input [] [] []
      (.super (.super (.impl "ResultMonad2" [] []) "Applicative2") "Functor2")).map
      (fun t => tyEq [.rho 0] t (.dict "Functor2" (.ctor (.data "Result")))) = .ok true := rfl

end Benitoite.Surface.Monad2Examples
