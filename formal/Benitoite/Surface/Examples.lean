import Benitoite.Surface.Desugar
import Benitoite.Surface.Typing
import Benitoite.Surface.Lemmas.Sequence
import Benitoite.Surface.Lemmas.Records
import Benitoite.Release.Examples

/-!
# 01-12 の各行の脱糖・型付け・実行の例（C1・C2・C4・C5a-1・C6a-1・C6a-2・C6a-3・C7b-2）

表の右辺を期待値として書き、rfl で一致を検査する。期待値を脱糖の補助関数で作らない。
特に二つ以上の引数と自由変数、捨てる束縛、ラムダの内外の束縛を区別する。
脱糖したプログラムを Release.run で実行し、戻り値と事象数も検査する。
-/

namespace Benitoite.Surface.Examples

open Benitoite.Release Benitoite.Surface

def intTy : Ty := .base .integer
def unitTy : Ty := .base .unit
def eInt (n : Nat) : Expr := .literal (.integer n)
def vInt (n : Int) : Val := .const (.integer n)
def eTrue : Expr := .literal (.boolean true)
def eFalse : Expr := .literal (.boolean false)

def opName : BinOp → String
  | .add => "add_Integer"
  | .sub => "sub_Integer"
  | .mul => "mul_Integer"
  | .div => "div_Float"
  | .intDiv => "div_Integer"
  | .mod => "mod_Integer"
  | .eq => "eq"
  | .ne => "ne"
  | .lt => "lt_Integer"
  | .le => "le_Integer"
  | .gt => "gt_Integer"
  | .ge => "ge_Integer"

/-- 出力を比較するための表。型付けの検査用の Builtins ではない。 -/
def opPrim : OpPrim
  | .binary o, t => some (opName o, (Operator.binary o).typeArgs t)
  | .neg, _ => some ("neg_Integer", [])

-- 01-12「名前とリテラル」: 局所の束縛の名前。
theorem local_row : desugarExpr opPrim .other (.local 2) = .ret (.var 2) := rfl

-- 同節: トップレベルの関数の名前。型引数とエフェクト引数を落とさない。
theorem fun_row : desugarExpr opPrim .other (.funName "f" [intTy] [Eff.single "Console.Write"]) =
    .ret (.fnRef "f" [intTy] [Eff.single "Console.Write"]) := rfl

-- 同節: prelude の関数。Σ に定義がある場合は fun_row と同じ。
theorem prim_row : desugarExpr opPrim .other (.primName "b" [intTy] [Eff.empty]) =
    .ret (.prim "b" [intTy] [Eff.empty]) := rfl

-- 同節: 引数のない構成子。
theorem null_con_row : desugarExpr opPrim .other (.nullCon "None" [intTy]) =
    .ret (.con "None" [intTy] []) := rfl

-- 同節: リテラル。各リテラルの値を検査する。
theorem literal_integer_row : desugarExpr opPrim .other (eInt 3) = .ret (vInt 3) := rfl
theorem literal_float_row : desugarExpr opPrim .other (.literal (.float 1.25)) =
    .ret (.const (.float 1.25)) := rfl
theorem literal_string_row : desugarExpr opPrim .other (.literal (.string "bnt")) =
    .ret (.const (.string "bnt")) := rfl
theorem literal_char_row : desugarExpr opPrim .other (.literal (.character 'b')) =
    .ret (.const (.character 'b')) := rfl
theorem literal_bool_row : desugarExpr opPrim .other eTrue = .ret (.const (.boolean true)) := rfl

-- 同節: -n、()、(e)。括弧は末尾位置を引き継ぐ。
theorem neg_int_row : desugarExpr opPrim .other (.negInt 3) = .ret (vInt (-3)) := rfl
theorem neg_float_row : desugarExpr opPrim .other (.negFloat 1.25) =
    .ret (.const (.float (-1.25))) := rfl
theorem neg_float_zero_row : desugarExpr opPrim .other (.negFloat (Float.ofBits 0)) =
    .ret (.const (.float (-(Float.ofBits 0)))) := rfl

-- Float のビット変換は実行時に確かめる。数値の等値では +0.0 と -0.0 を区別できない。
#guard (match desugarExpr opPrim .other (.negFloat (Float.ofBits 0)) with
    | .ret (.const (.float x)) => x.toBits == 0x8000000000000000
    | _ => false)

theorem unit_row : desugarExpr opPrim .other .unit = .ret (.const .unit) := rfl
theorem paren_row : desugarExpr opPrim .tail (.paren (.returnE intTy (eInt 3))) = .ret (vInt 3) := rfl

-- 01-12「呼び出し」: 構成子の呼び出し。元の変数は引数の let の分だけずらす。
theorem con_call_row :
    desugarExpr opPrim .other (.conCall "Pair" [intTy] (.cons (.local 0) (.cons (.local 1) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2)) (.ret (.con "Pair" [intTy] [.var 1, .var 0]))) := rfl

-- 同節: そのほかの呼び出し。名前でない callee を先に束縛する。
theorem call_row :
    desugarExpr opPrim .tail (.call (.local 0) (.cons (.local 1) (.cons (.local 2) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2))
      (.letIn (.ret (.var 4)) (.app (.var 2) [.var 1, .var 0]))) := rfl

-- 01-12 との食い違い: 直接の関数・組み込みの名前は callee の let を作らない。
theorem direct_fun_call_row :
    desugarExpr opPrim .tail (.call (.funName "f" [intTy] [Eff.empty]) (.cons (.local 0) .nil)) =
    .letIn (.ret (.var 0)) (.app (.fnRef "f" [intTy] [Eff.empty]) [.var 0]) := rfl
theorem direct_prim_call_row :
    desugarExpr opPrim .tail (.call (.primName "b" [] []) (.cons (eInt 1) .nil)) =
    .letIn (.ret (vInt 1)) (.app (.prim "b" [] []) [.var 0]) := rfl
-- 括弧で囲んだ名前は Rust prepare の直接の名前の条件に当たらず、一般の呼び出しになる。
theorem paren_call_row :
    desugarExpr opPrim .tail (.call (.paren (.primName "b" [] [])) (.cons (eInt 1) .nil)) =
    .letIn (.ret (.prim "b" [] [])) (.letIn (.ret (vInt 1)) (.app (.var 1) [.var 0])) := rfl
theorem zero_arg_call_row : desugarExpr opPrim .tail (.call (.funName "f" [] []) .nil) =
    .app (.fnRef "f" [] []) [] := rfl

-- 01-12「演算子」: e1 ⊕ e2。型引数なしの項目と eq[T]・ne[T] を区別する。
theorem binary_row : desugarExpr opPrim .other (.binary .add intTy (.local 0) (.local 1)) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2)) (.app (.prim "add_Integer" [] []) [.var 1, .var 0])) := rfl
theorem eq_row : desugarExpr opPrim .other (.binary .eq intTy (eInt 1) (eInt 2)) =
    .letIn (.ret (vInt 1)) (.letIn (.ret (vInt 2)) (.app (.prim "eq" [intTy] []) [.var 1, .var 0])) := rfl
theorem ne_row : desugarExpr opPrim .other (.binary .ne intTy (eInt 1) (eInt 2)) =
    .letIn (.ret (vInt 1)) (.letIn (.ret (vInt 2)) (.app (.prim "ne" [intTy] []) [.var 1, .var 0])) := rfl

-- 同節: -e、not e。
theorem neg_row : desugarExpr opPrim .other (.neg intTy (.local 0)) =
    .letIn (.ret (.var 0)) (.app (.prim "neg_Integer" [] []) [.var 0]) := rfl
theorem not_row : desugarExpr opPrim .other (.not (.local 0)) =
    .letIn (.ret (.var 0)) (.ite (.var 0) (.ret (.const (.boolean false)))
      (.ret (.const (.boolean true)))) := rfl

-- 同節: and・or。右辺に末尾位置を渡すことと、自由変数のずらしを検査する。
theorem and_row : desugarExpr opPrim .tail (.and eTrue (.returnE (.base .boolean) (.local 0))) =
    .letIn (.ret (.const (.boolean true))) (.ite (.var 0) (.ret (.var 1))
      (.ret (.const (.boolean false)))) := rfl
theorem or_row : desugarExpr opPrim .tail (.or eFalse (.returnE (.base .boolean) (.local 0))) =
    .letIn (.ret (.const (.boolean false))) (.ite (.var 0) (.ret (.const (.boolean true)))
      (.ret (.var 1))) := rfl

-- 01-12「リスト、ラムダ、条件分岐、match」: リスト（空も含む）。
theorem list_row : desugarExpr opPrim .other (.list intTy (.cons (.local 0) (.cons (.local 1) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2)) (.ret (.list [.var 1, .var 0]))) := rfl
theorem empty_list_row : desugarExpr opPrim .other (.list intTy .nil) = .ret (.list []) := rfl

-- 同節: ラムダ。二引数の最後が番号 0 で、return は末尾位置。
theorem lambda_row :
    desugarExpr opPrim .other (.lam [intTy, intTy] intTy Eff.empty (.last (.returnE intTy (.local 0)))) =
    .ret (.lam [intTy, intTy] (.ret (.var 0))) := rfl

-- 同節: else ありの if。挿入した条件の let は、ラムダの引数をずらさない。
theorem if_row :
    desugarExpr opPrim .other (.ite eTrue
      (.last (.lam [intTy] intTy Eff.empty (.last (.returnE intTy (.local 1)))))
      (.last (.lam [intTy] intTy Eff.empty (.last (.returnE intTy (.local 0)))))) =
    .letIn (.ret (.const (.boolean true))) (.ite (.var 0)
      (.ret (.lam [intTy] (.ret (.var 2)))) (.ret (.lam [intTy] (.ret (.var 0))))) := rfl

-- 同節: else if。各分岐の return に末尾位置を渡す。
theorem else_if_row :
    desugarExpr opPrim .tail (.elseIf eTrue (.last (.returnE intTy (eInt 1)))
      (.ite eFalse (.last (.returnE intTy (eInt 2))) (.last (.returnE intTy (eInt 3))))) =
    .letIn (.ret (.const (.boolean true))) (.ite (.var 0) (.ret (vInt 1))
      (.letIn (.ret (.const (.boolean false))) (.ite (.var 0) (.ret (vInt 2)) (.ret (vInt 3))))) := rfl

-- 同節: else なし。
theorem if_only_row : desugarExpr opPrim .tail (.ifOnly eTrue (.last (.returnE unitTy .unit))) =
    .letIn (.ret (.const (.boolean true))) (.ite (.var 0) (.ret (.const .unit)) (.ret (.const .unit))) := rfl

-- 01-12「ブロック」: { }、{ e }。
theorem empty_block_row : desugarBlock opPrim .tail .empty = .ret (.const .unit) := rfl
theorem last_expr_row : desugarBlock opPrim .other (.last (eInt 1)) = .ret (vInt 1) := rfl

-- 同節: 最後が束縛の文。shadow、_ も同じ出力。
theorem last_bind_row : desugarBlock opPrim .tail (.lastBind .bind intTy (eInt 1)) =
    .letIn (.ret (vInt 1)) (.ret (.const .unit)) := rfl
theorem last_shadow_row : desugarBlock opPrim .tail (.lastBind .shadow intTy (eInt 1)) =
    .letIn (.ret (vInt 1)) (.ret (.const .unit)) := rfl
theorem last_discard_row : desugarBlock opPrim .tail (.lastDiscard (eInt 1)) =
    .letIn (.ret (vInt 1)) (.ret (.const .unit)) := rfl

-- 同節: { bind x <- e; s̄ }。続きの番号 0 は新しい束縛である。
theorem bind_row : desugarBlock opPrim .tail (.bind .bind intTy (eInt 1) (.last (.returnE intTy (.local 0)))) =
    .letIn (.ret (vInt 1)) (.ret (.var 0)) := rfl

-- 同節の shadow。旧変数の値で新しい束縛を作り、続きは新しい番号 0 を指す。
theorem shadow_row : desugarBlock opPrim .tail (.bind .shadow intTy (.local 0) (.last (.returnE intTy (.local 0)))) =
    .letIn (.ret (.var 0)) (.ret (.var 0)) := rfl

-- 同節: { bind _ <- e; s̄ }。続きの既存の変数は、捨てる let の分だけずらす。
theorem discard_row : desugarBlock opPrim .tail (.discard (eInt 1) (.last (.returnE intTy (.local 0)))) =
    .letIn (.ret (vInt 1)) (.ret (.var 1)) := rfl

-- 同節: { e; s̄ }。式文の挿入は、続きで導入する bind の番号をずらさない。
theorem seq_row : desugarBlock opPrim .tail (.seq .unit
    (.bind .bind intTy (.local 0) (.last (.returnE intTy (.local 0))))) =
    .letIn (.ret (.const .unit)) (.letIn (.ret (.var 1)) (.ret (.var 0))) := rfl

-- 01-12「return」: 末尾位置なら e の計算そのもの。
theorem return_tail_row : desugarExpr opPrim .tail (.returnE intTy (.call (.funName "f" [] []) .nil)) =
    .app (.fnRef "f" [] []) [] := rfl

-- 同節: 非末尾位置なら escape。結果型の注釈は戻り値型と異なってよい。
theorem return_other_row : desugarExpr opPrim .other (.returnE unitTy (eInt 1)) =
    .letIn (.ret (vInt 1)) (.escape (.var 0)) := rfl

-- 非末尾の分岐で return すると、関数の mark まで抜ける計算を作る。
theorem return_in_branch_row : desugarExpr opPrim .other
    (.ifOnly eTrue (.last (.returnE unitTy (eInt 1)))) =
    .letIn (.ret (.const (.boolean true))) (.ite (.var 0)
      (.letIn (.ret (vInt 1)) (.escape (.var 0))) (.ret (.const .unit))) := rfl

-- 01-12「トップレベルの関数」: シグネチャをそのまま写す。
def identity : Surface.Def :=
  { tparams := [{ equality := true }], neffs := 1, params := [.tvar 0], ret := .tvar 0,
    eff := fun a => a == .rho 0, body := .last (.returnE (.tvar 0) (.local 0)) }

theorem function_row : desugarDef opPrim identity =
    { tparams := [{ equality := true }], neffs := 1, params := [.tvar 0], ret := .tvar 0,
      eff := fun a => a == .rho 0, body := .ret (.var 0) } := rfl

def program : Surface.Program :=
  { defs := fun f => if f == "f" then some identity else none,
    cons := fun c => if c == "None" then some ⟨"Option", 1, []⟩ else none }

-- プログラムの関数を比較せず、名前で引いた定義を比較する。
theorem program_row : (desugarProgram opPrim program).defs "f" = some
    { tparams := [{ equality := true }], neffs := 1, params := [.tvar 0], ret := .tvar 0,
      eff := fun a => a == .rho 0, body := .ret (.var 0) } := rfl

theorem program_con_row : (desugarProgram opPrim program).cons "None" = some ⟨"Option", 1, []⟩ := rfl

/-! ## C2 の追加行

01-12 の右辺と、01-02 の展開の評価順序・評価の時期を独立した期待値で検査する。
パイプは t の再束縛を省き、プレースホルダは新しい引数を再束縛する。
-/

-- 01-12「名前とリテラル」: 引数を持つ構成子の名前を値として使う。
theorem con_value_row : desugarExpr opPrim .other (.conValue "Pair" [intTy, intTy] [intTy, intTy]) =
    .ret (.lam [intTy, intTy] (.ret (.con "Pair" [intTy, intTy] [.var 1, .var 0]))) := rfl

-- 01-12 の pi' の説明: 全基本パターン、負の定数と修飾の除去。
theorem pattern_rows : Pattern.toCoreList
    [.wild, .var, .integer 3, .negInt 2, .string "yes", .character 'b', .boolean true, .unit,
     .con (some "Option") "Some" [.var], .con (some "Option") "None" []] =
    [.wild, .var, .const (.integer 3), .const (.integer (-2)), .const (.string "yes"),
     .const (.character 'b'), .const (.boolean true), .const .unit,
     .con "Some" [.var], .con "None" []] := rfl

-- 01-12「リスト、ラムダ、条件分岐、match」: 分岐順と分岐ごとの束縛を保つ。
theorem match_row : desugarExpr opPrim .tail (.matchE intTy (.local 0)
    (.single (.integer 0) (.last (.returnE intTy (eInt 1)))
      (.single .var (.last (.returnE intTy (.local 0))) .nil))) =
    .letIn (.ret (.var 0)) (.match (.var 0)
      [.mk [⟨.const (.integer 0), []⟩] none (.ret (vInt 1)),
       .mk [⟨.var, [0]⟩] none (.ret (.var 0))]) := rfl

-- パターンの二束縛の後の外側の変数だけをずらす。内側の let の束縛も保護する。
theorem match_pair_scope_row : desugarExpr opPrim .other (.matchE (.list intTy) (.local 0)
    (.single (.con none "Pair" [.var, .var])
      (.last (.list intTy (.cons (.local 0) (.cons (.local 1) (.cons (.local 2) .nil))))) .nil)) =
    .letIn (.ret (.var 0)) (.match (.var 0)
      [.mk [⟨.con "Pair" [.var, .var], [0, 1]⟩] none (.letIn (.ret (.var 0))
        (.letIn (.ret (.var 2)) (.letIn (.ret (.var 5)) (.ret (.list [.var 2, .var 1, .var 0])))))]) := rfl

theorem match_empty_row : desugarExpr opPrim .other (.matchE intTy (.local 0) .nil) =
    .letIn (.ret (.var 0)) (.match (.var 0) []) := rfl

-- 01-12「ブロック」: 必ず照合するパターンの束縛。最後の束縛の変数が番号 0。
theorem bind_pattern_row : desugarBlock opPrim .tail
    (.bindPat .bind (.con none "Pair" [.var, .var]) (.data "Pair" [intTy, intTy]) (.local 0)
      (.last (.returnE intTy (.local 2)))) =
    .letIn (.ret (.var 0)) (.match (.var 0)
      [.mk [⟨.con "Pair" [.var, .var], [0, 1]⟩] none (.ret (.var 3))]) := rfl

theorem bind_triple_pattern_row : desugarBlock opPrim .tail
    (.bindPat .shadow (.con none "Triple" [.var, .wild, .var])
      (.data "Triple" [intTy, intTy, intTy]) (.local 0) (.last (.returnE intTy (.local 0)))) =
    .letIn (.ret (.var 0)) (.match (.var 0)
      [.mk [⟨.con "Triple" [.var, .wild, .var], [0, 1]⟩] none (.ret (.var 0))]) := rfl

-- 同節: 最後の bind p。() の束縛も一分岐の match になる。
theorem last_pattern_row : desugarBlock opPrim .tail
    (.lastPat .bind (.con none "Pair" [.var, .var]) (.data "Pair" [intTy, intTy]) (.local 0)) =
    .letIn (.ret (.var 0)) (.match (.var 0)
      [.mk [⟨.con "Pair" [.var, .var], [0, 1]⟩] none (.ret (.const .unit))]) := rfl

theorem last_unit_pattern_row : desugarBlock opPrim .tail (.lastPat .shadow .unit unitTy .unit) =
    .letIn (.ret (.const .unit)) (.match (.var 0) [.mk [⟨.const .unit, []⟩] none (.ret (.const .unit))]) := rfl

-- 01-12「呼び出し」: パイプ。01-02 規則 1 の直接の関数・prelude・構成子の呼び出し。
theorem pipe_fun_call_row : desugarExpr opPrim .tail
    (.pipe (.local 0) (.call (.funName "f" [] []) (.cons (.local 1) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2)) (.app (.fnRef "f" [] []) [.var 1, .var 0])) := rfl

theorem pipe_prim_call_row : desugarExpr opPrim .tail
    (.pipe (.local 0) (.call (.primName "b" [] []) (.cons (.local 1) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2)) (.app (.prim "b" [] []) [.var 1, .var 0])) := rfl

theorem pipe_con_call_row : desugarExpr opPrim .tail
    (.pipe (.local 0) (.conCall "Pair" [intTy, intTy] (.cons (.local 1) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2)) (.ret (.con "Pair" [intTy, intTy] [.var 1, .var 0]))) := rfl

-- callee も評価する呼び出し。順序は左辺、callee、残りの引数。
theorem pipe_indirect_call_row : desugarExpr opPrim .tail
    (.pipe (.local 0) (.call (.local 1) (.cons (.local 2) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2))
      (.letIn (.ret (.var 4)) (.app (.var 1) [.var 2, .var 0]))) := rfl

-- 呼び出しを重ねた右辺では、最も外側の呼び出しだけに左辺を加える。
theorem pipe_outer_call_row : desugarExpr opPrim .tail (.pipe (eInt 1)
    (.call (.call (.funName "g" [] []) (.cons (eInt 2) .nil)) (.cons (eInt 3) .nil))) =
    .letIn (.ret (vInt 1)) (.letIn
      (.letIn (.ret (vInt 2)) (.app (.fnRef "g" [] []) [.var 0]))
      (.letIn (.ret (vInt 3)) (.app (.var 1) [.var 2, .var 0]))) := rfl

-- 01-02 規則 2: 裸の名前と値の式。
theorem pipe_fun_name_row : desugarExpr opPrim .tail (.pipe (.local 0) (.funName "f" [] [])) =
    .letIn (.ret (.var 0)) (.app (.fnRef "f" [] []) [.var 0]) := rfl

theorem pipe_prim_name_row : desugarExpr opPrim .tail (.pipe (.local 0) (.primName "b" [] [])) =
    .letIn (.ret (.var 0)) (.app (.prim "b" [] []) [.var 0]) := rfl

theorem pipe_con_name_row : desugarExpr opPrim .tail (.pipe (.local 0) (.conValue "Some" [intTy] [intTy])) =
    .letIn (.ret (.var 0)) (.ret (.con "Some" [intTy] [.var 0])) := rfl

theorem pipe_value_row : desugarExpr opPrim .tail (.pipe (.local 0) (.local 1)) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2)) (.app (.var 0) [.var 1])) := rfl

-- 括弧付き呼び出しは結果を適用する。外側の call に第 1 引数を加えない。
theorem pipe_paren_call_row : desugarExpr opPrim .tail
    (.pipe (.local 0) (.paren (.call (.funName "make" [] []) (.cons (.local 1) .nil)))) =
    .letIn (.ret (.var 0)) (.letIn
      (.letIn (.ret (.var 2)) (.app (.fnRef "make" [] []) [.var 0])) (.app (.var 0) [.var 1])) := rfl

-- 01-12「呼び出し」の前段: プレースホルダの展開。左からの穴の順と非穴の自由変数。
theorem partial_call_row : desugarExpr opPrim .other
    (.partialCall (.funName "between" [] [])
      (.hole intTy (.expr (.local 0) (.hole intTy .nil))) intTy Eff.empty) =
    .ret (.lam [intTy, intTy] (.letIn (.ret (.var 1))
      (.letIn (.ret (.var 3)) (.letIn (.ret (.var 2))
        (.app (.fnRef "between" [] []) [.var 2, .var 1, .var 0]))))) := rfl

theorem partial_prim_row : desugarExpr opPrim .other
    (.partialCall (.primName "b" [] []) (.expr (eInt 1) (.hole intTy .nil)) intTy Eff.empty) =
    .ret (.lam [intTy] (.letIn (.ret (vInt 1))
      (.letIn (.ret (.var 1)) (.app (.prim "b" [] []) [.var 1, .var 0])))) := rfl

-- callee を含め全計算がラムダの内側にある。
theorem partial_indirect_row : desugarExpr opPrim .other
    (.partialCall (.local 0) (.hole intTy (.expr (.local 1) .nil)) intTy Eff.empty) =
    .ret (.lam [intTy] (.letIn (.ret (.var 1))
      (.letIn (.ret (.var 1)) (.letIn (.ret (.var 4)) (.app (.var 2) [.var 1, .var 0]))))) := rfl

-- 構成子のプレースホルダ。穴の再束縛も残す。
theorem partial_con_row : desugarExpr opPrim .other
    (.partialCon "Pair" [intTy, intTy] (.expr (.local 0) (.hole intTy .nil))) =
    .ret (.lam [intTy] (.letIn (.ret (.var 1)) (.letIn (.ret (.var 1))
      (.ret (.con "Pair" [intTy, intTy] [.var 1, .var 0]))))) := rfl

-- 非穴の return は新しいラムダから抜ける。外側で先に評価しない。
theorem partial_return_row : desugarExpr opPrim .other
    (.partialCall (.funName "f" [] []) (.expr (.returnE unitTy (eInt 7)) (.hole intTy .nil))
      intTy Eff.empty) =
    .ret (.lam [intTy] (.letIn (.letIn (.ret (vInt 7)) (.escape (.var 0)))
      (.letIn (.ret (.var 1)) (.app (.fnRef "f" [] []) [.var 1, .var 0])))) := rfl

-- 直接の穴を持つ右辺は規則 2。ラムダを得てから左辺の値を適用する。
theorem pipe_partial_row : desugarExpr opPrim .tail
    (.pipe (.local 0) (.partialCall (.funName "f" [] [])
      (.expr (.local 1) (.hole intTy .nil)) intTy Eff.empty)) =
    .letIn (.ret (.var 0)) (.letIn
      (.ret (.lam [intTy] (.letIn (.ret (.var 3)) (.letIn (.ret (.var 1))
        (.app (.fnRef "f" [] []) [.var 1, .var 0]))))) (.app (.var 0) [.var 1])) := rfl

-- 引数の中の穴は、パイプの第 1 引数の挿入を妨げない（01-02 の f(g(_))）。
theorem pipe_nested_partial_row : desugarExpr opPrim .tail
    (.pipe (.local 0) (.call (.funName "f" [] []) (.cons
      (.partialCall (.funName "g" [] []) (.hole intTy .nil) intTy Eff.empty) .nil))) =
    .letIn (.ret (.var 0)) (.letIn
      (.ret (.lam [intTy] (.letIn (.ret (.var 0)) (.app (.fnRef "g" [] []) [.var 0]))))
      (.app (.fnRef "f" [] []) [.var 1, .var 0])) := rfl

/-! ## C4a-1: try・with・lazy の脱糖

追加した行の期待値をコアの項として直接書く。try の失敗側の型引数、with の入れ子と
非末尾位置、lazy の捕捉と内側のラムダの境界を確かめる。実行の例は下の C4b-1 の節に置く。
-/

-- 01-12「関数の境界と escape」の Result の行。成功側と失敗側の変数は各パターンの番号 0。
-- 戻り値の成功の型 U は、入力の成功の型 T と異なってよい。
theorem try_result_row (p : Position) : desugarExpr opPrim p
    (.tryResult [.base .string, .opaque "IOError"] "Result.Ok" "Result.Error" (.local 2)) =
    .letIn (.ret (.var 2)) (.match (.var 0)
      [.mk [⟨.con "Result.Ok" [.var], [0]⟩] none (.ret (.var 0)),
       .mk [⟨.con "Result.Error" [.var], [0]⟩] none
         (.escape (.con "Result.Error" [.base .string, .opaque "IOError"] [.var 0]))]) := rfl

-- 同節の Option の行。None の分岐は変数を束縛せず、escape の構成子も引数を持たない。
theorem try_option_row (p : Position) : desugarExpr opPrim p
    (.tryOption [.base .string] "Option.Some" "Option.None" (.local 1)) =
    .letIn (.ret (.var 1)) (.match (.var 0)
      [.mk [⟨.con "Option.Some" [.var], [0]⟩] none (.ret (.var 0)),
       .mk [⟨.con "Option.None" [], []⟩] none (.escape (.con "Option.None" [.base .string] []))]) := rfl

-- 01-12「解放の枠」の一束縛。body の番号 0 はリソース、番号 2 は束縛前の番号 1。
theorem with_single_row (p : Position) : desugarExpr opPrim p
    (.withE "File.Reader" (.local 0) (.last (.local 2))) =
    .letIn (.ret (.var 0)) (.use (.var 0) (.ret (.var 2))) := rfl

-- 同じ行の複数束縛。二つ目の式は一つ目のリソースを参照できる。
-- 最後の番号 3 は二つの束縛の外の番号 1。use は新しい変数を束縛しない。
theorem with_nested_row (p : Position) : desugarExpr opPrim p
    (.withE "File.Reader" (.local 0)
      (.last (.withE "File.Reader" (.local 0) (.last (.local 3))))) =
    .letIn (.ret (.var 0)) (.use (.var 0)
      (.letIn (.ret (.var 0)) (.use (.var 0) (.ret (.var 3))))) := rfl

-- 末尾位置の with でも、本体の return は escape になる（Rust の Result 位置と同じ項）。
theorem with_return_row (p : Position) : desugarExpr opPrim p
    (.withE "File.Reader" (.local 0) (.last (.returnE unitTy (.local 2)))) =
    .letIn (.ret (.var 0)) (.use (.var 0)
      (.letIn (.ret (.var 2)) (.escape (.var 0)))) := rfl

-- 01-12「ストア」の lazy の箇条。lazy 自身は束縛を増やさず、bind は一つ増やす。
theorem lazy_capture_row (p : Position) : desugarExpr opPrim p
    (.lazyE (.bind .bind intTy (.local 1)
      (.last (.binary .add intTy (.local 0) (.local 2))))) =
    .lazyC (.letIn (.ret (.var 1)) (.letIn (.ret (.var 0))
      (.letIn (.ret (.var 3)) (.app (.prim "add_Integer" [] []) [.var 1, .var 0])))) := rfl

-- lazy の本体は非末尾でも、内側のラムダの本体は末尾位置として移す。
theorem lazy_lambda_row (p : Position) : desugarExpr opPrim p
    (.lazyE (.last (.lam [intTy] intTy Eff.empty (.last (.returnE unitTy (.local 1)))))) =
    .lazyC (.ret (.lam [intTy] (.ret (.var 1)))) := rfl

/-! ## 脱糖したプログラムの実行

同じプログラムに対する入力と期待値を表で検査する。コアの本体を期待値から作らず、
関数の呼び出し、束縛の内外、途中の return と短絡評価を実行の結果で確かめる。
-/

def execOp : OpPrim
  | .binary .add, _ => some ("add", [])
  | _, _ => none

def printOne : Expr := .call (.primName "print" [] []) (.cons (eInt 1) .nil)

def effectfulBool : Expr := .ite eTrue (.seq printOne (.last eTrue)) (.last eFalse)

/-- 非穴の引数を評価した回数を IO の事象で観察する。 -/
def effectfulInt : Expr := .ite eTrue (.seq printOne (.last (eInt 22))) (.last (eInt 0))

def delayedPick : Expr := .partialCall (.funName "pick" [] [])
  (.hole intTy (.expr effectfulInt .nil)) intTy (Eff.single "Console.Write")

def execProgram : Surface.Program where
  defs
    | "pick" => some
        { tparams := [], neffs := 0, params := [intTy, intTy], ret := intTy,
          eff := Eff.empty, body := .last (.returnE unitTy (.local 1)) }
    | "capture" => some
        { tparams := [], neffs := 0, params := [intTy], ret := intTy,
          eff := Eff.empty, body :=
            .bind .bind intTy (.binary .add intTy (.local 0) (eInt 2))
              (.discard (eInt 9) (.last (.returnE unitTy
              (.call (.paren (.lam [intTy] intTy Eff.empty
                  (.last (.returnE unitTy (.binary .add intTy (.local 1) (.local 0))))))
                  (.cons (eInt 3) .nil))))) }
    | "early" => some
        { tparams := [], neffs := 0, params := [], ret := intTy,
          eff := Eff.empty, body :=
            .discard (.ifOnly eTrue (.last (.returnE unitTy (eInt 7))))
              (.last (.returnE unitTy (eInt 99))) }
    | "and" => some
        { tparams := [], neffs := 0, params := [], ret := .base .boolean,
          eff := Eff.single "Console.Write", body := .last (.returnE unitTy (.and eFalse effectfulBool)) }
    | "or" => some
        { tparams := [], neffs := 0, params := [], ret := .base .boolean,
          eff := Eff.single "Console.Write", body := .last (.returnE unitTy (.or eTrue effectfulBool)) }
    | "emit" => some
        { tparams := [], neffs := 0, params := [], ret := unitTy,
          eff := Eff.single "Console.Write", body := .seq printOne (.last .unit) }
    | "matchPair" => some
        { tparams := [], neffs := 0, params := [intTy], ret := intTy,
          eff := Eff.empty, body :=
            .bindPat .bind (.con none "Pair" [.var, .var]) (.data "Pair" [intTy, intTy])
              (.conCall "Pair" [intTy, intTy] (.cons (eInt 11) (.cons (eInt 22) .nil)))
              (.last (.returnE unitTy (.matchE intTy eFalse
                (.single (.boolean true) (.last (.returnE unitTy (eInt 99)))
                  (.single .wild (.last (.returnE unitTy
                    (.binary .add intTy (.local 1) (.local 2)))) .nil))))) }
    | "pipeCall" => some
        { tparams := [], neffs := 0, params := [], ret := intTy,
          eff := Eff.empty, body := .last (.returnE unitTy
            (.pipe (eInt 11) (.call (.funName "pick" [] []) (.cons (eInt 22) .nil)))) }
    | "pipeValue" => some
        { tparams := [], neffs := 0, params := [], ret := intTy,
          eff := Eff.empty, body := .last (.returnE unitTy
            (.pipe (eInt 7) (.paren (.lam [intTy] intTy Eff.empty
              (.last (.returnE unitTy (.binary .add intTy (.local 0) (eInt 3)))))))) }
    | "partialUnused" => some
        { tparams := [], neffs := 0, params := [], ret := unitTy,
          eff := Eff.single "Console.Write", body :=
            .bind .bind (.fn [intTy] intTy (Eff.single "Console.Write")) delayedPick (.last .unit) }
    | "partialCalled" => some
        { tparams := [], neffs := 0, params := [], ret := intTy,
          eff := Eff.single "Console.Write", body :=
            .bind .bind (.fn [intTy] intTy (Eff.single "Console.Write")) delayedPick
              (.bind .bind intTy (.call (.local 0) (.cons (eInt 11) .nil))
                (.last (.returnE unitTy (.binary .add intTy (.local 0)
                  (.call (.local 1) (.cons (eInt 33) .nil)))))) }
    | "main" => some
        { tparams := [], neffs := 0, params := [], ret := unitTy,
          eff := Eff.empty, body := .last .unit }
    | _ => none
  cons
    | "Pair" => some { data := "Pair", ntys := 2, args := [.tvar 0, .tvar 1] }
    | _ => none


/-- 実行の観察結果。燃料不足などの途中の状態は other とする。 -/
inductive ExecResult where
  | integer (n : Int)
  | boolean (b : Bool)
  | unit
  | other
  deriving DecidableEq

def execSurface (f : FunName) (args : List Val) : ExecResult × Nat :=
  let (s, events) := Release.run (desugarProgram execOp execProgram)
    Release.Examples.builtins Release.Examples.oracle Release.Examples.rel Release.Examples.fresh
    200 (.run (.app (.fnRef f [] []) args) [] Store.empty) []
  let result := match s with
    | .run (.ret (.const (.integer n))) [] _ => .integer n
    | .run (.ret (.const (.boolean b))) [] _ => .boolean b
    | .run (.ret (.const .unit)) [] _ => .unit
    | _ => .other
  (result, events.length)

/-- 引数順序、捕捉、return、短絡評価、パターン束縛、match、パイプと IO。
部分適用は作成だけなら事象なし、二回呼ぶと非穴の引数も二回評価して事象が二つになる。 -/
theorem execution_rows :
    [("pick", [vInt 11, vInt 22], ExecResult.integer 11, 0),
     ("capture", [vInt 5], ExecResult.integer 10, 0),
     ("early", [], ExecResult.integer 7, 0),
     ("and", [], ExecResult.boolean false, 0),
     ("or", [], ExecResult.boolean true, 0),
     ("emit", [], ExecResult.unit, 1),
     ("matchPair", [vInt 5], ExecResult.integer 16, 0),
     ("pipeCall", [], ExecResult.integer 11, 0),
     ("pipeValue", [], ExecResult.integer 10, 0),
     ("partialUnused", [], ExecResult.unit, 0),
     ("partialCalled", [], ExecResult.integer 44, 2),
     ("main", [], ExecResult.unit, 0)].all
      (fun (f, args, result, events) => decide (execSurface f args = (result, events))) = true := by
  decide

/-! ## C4b-1: try・with・lazy の実行

try の失敗は最も内側の関数から抜け、with の解放は途中の return でも内側から行う。
lazy の本体は純粋な再帰呼び出しであり、強制するまでその呼び出しを評価しない。
-/

def stringTy : Ty := .base .string
def resultIntTy : Ty := .data "Result" [intTy, stringTy]
def resultStringTy : Ty := .data "Result" [stringTy, stringTy]
def optionIntTy : Ty := .data "Option" [intTy]
def fileTy : Ty := .opaque "File"

def loopCall : Expr := .call (.funName "loop" [] []) .nil

def lazyLoop : Expr := .lazyE (.last loopCall)

def c4Program : Surface.Program where
  defs
    | "tryResult" => some
        { tparams := [], neffs := 0, params := [resultIntTy], ret := resultStringTy,
          eff := Eff.empty, body :=
            .bind .bind intTy (.tryResult [stringTy, stringTy] "Result.Ok" "Result.Error" (.local 0))
              (.last (.returnE unitTy (.conCall "Result.Ok" [stringTy, stringTy]
                (.cons (.literal (.string "after")) .nil)))) }
    | "tryOption" => some
        { tparams := [], neffs := 0, params := [optionIntTy], ret := optionIntTy,
          eff := Eff.empty, body :=
            .bind .bind intTy (.tryOption [intTy] "Option.Some" "Option.None" (.local 0))
              (.last (.returnE unitTy (.conCall "Option.Some" [intTy] (.cons (.local 0) .nil)))) }
    | "tryCaller" => some
        { tparams := [], neffs := 0, params := [resultIntTy], ret := intTy,
          eff := Eff.empty, body :=
            .discard (.call (.funName "tryResult" [] []) (.cons (.local 0) .nil))
              (.last (.returnE unitTy (eInt 42))) }
    | "withNormal" => some
        { tparams := [], neffs := 0, params := [fileTy], ret := intTy,
          eff := Eff.single stateEff, body := .last (.returnE unitTy
            (.withE "File" (.local 0) (.last (eInt 5)))) }
    | "withReturn" => some
        { tparams := [], neffs := 0, params := [fileTy, fileTy], ret := intTy,
          eff := Eff.single stateEff, body :=
            .discard (.withE "File" (.local 1)
              (.last (.withE "File" (.local 1) (.last (.returnE unitTy (eInt 7))))))
              (.last (.returnE unitTy (eInt 99))) }
    | "loop" => some
        { tparams := [], neffs := 0, params := [], ret := intTy,
          eff := Eff.empty, body := .last (.returnE unitTy loopCall) }
    | "lazyUnused" => some
        { tparams := [], neffs := 0, params := [], ret := intTy,
          eff := Eff.empty, body := .bind .bind (.lazy intTy) lazyLoop
            (.last (.returnE unitTy (eInt 7))) }
    | "lazyForced" => some
        { tparams := [], neffs := 0, params := [], ret := intTy,
          eff := Eff.empty, body := .bind .bind (.lazy intTy) lazyLoop
            (.last (.returnE unitTy
              (.call (.primName "force" [intTy] []) (.cons (.local 0) .nil)))) }
    | _ => none
  cons
    | "Result.Ok" => some { data := "Result", ntys := 2, args := [.tvar 0] }
    | "Result.Error" => some { data := "Result", ntys := 2, args := [.tvar 1] }
    | "Option.Some" => some { data := "Option", ntys := 1, args := [.tvar 0] }
    | "Option.None" => some { data := "Option", ntys := 1, args := [] }
    | _ => none

/-- lazy 本体の再帰呼び出しは、任意の局所環境でも空のエフェクトで型が付く。
関数名の参照には宣言を使い、本体の停止性を仮定しない。 -/
theorem loopCall_typed (Γ : List (Option Ty)) (R : Option Ty) (pos : Position) :
    HasType c4Program.declarations Release.Examples.builtins execOp [] Γ R pos
      loopCall intTy Eff.empty := by
  apply HasType.E_Call (ps := []) (εf := Eff.empty) (εargs := Eff.empty) (εcall := Eff.empty)
  · have hf : HasType c4Program.declarations Release.Examples.builtins execOp [] Γ R .other (.funName "loop" [] [])
      (fnTy [] intTy Eff.empty [] []) Eff.empty := by
      apply HasType.E_Fun (d :=
        { tparams := [], neffs := 0, params := [], ret := intTy, eff := Eff.empty })
      · rfl
      · exact ⟨rfl, by intro i t tp hi; cases hi⟩
      · rfl
      · rfl
    simpa [fnTy_eq, Ty.subst, Ty.substAt, intTy, Eff.substRho_empty] using hf
  · exact .nil

/-- E_Lazy の要求どおり、隠した環境・R = none・非末尾位置で本体を検査する。 -/
theorem lazyLoop_typed (Γ : List (Option Ty)) (R : Option Ty) (pos : Position) :
    HasType c4Program.declarations Release.Examples.builtins execOp [] Γ R pos
      lazyLoop (.lazy intTy) Eff.empty :=
  .E_Lazy (.B_Last (loopCall_typed (hideConts Γ) none .other))

/-- 強制前と強制後の両方の例は純粋な関数として型が付く。 -/
theorem lazy_definitions_typed :
    (∀ d, c4Program.defs "lazyUnused" = some d →
      d.WellTyped c4Program.declarations Release.Examples.builtins execOp) ∧
    (∀ d, c4Program.defs "lazyForced" = some d →
      d.WellTyped c4Program.declarations Release.Examples.builtins execOp) := by
  constructor
  · intro d hd
    have hd' : d = _ := (Option.some.inj hd).symm
    subst d
    refine ⟨Or.inl trivial, .B_Bind (lazyLoop_typed _ _ _) ?_⟩
    exact .B_Last (.E_ReturnTail .E_Literal)
  · intro d hd
    have hd' : d = _ := (Option.some.inj hd).symm
    subst d
    refine ⟨Or.inl trivial, .B_Bind (lazyLoop_typed _ _ _) ?_⟩
    apply HasBlock.B_Last
    apply HasType.E_ReturnTail
    apply HasType.E_Call (ps := [.lazy intTy]) (εf := Eff.empty) (εargs := Eff.empty) (εcall := Eff.empty)
    · have hf : HasType c4Program.declarations Release.Examples.builtins execOp
        [] [some (.lazy intTy)] (some intTy) .other (.primName "force" [intTy] [])
        (fnTy [.lazy (.tvar 0)] (.tvar 0) Eff.empty [intTy] []) Eff.empty := by
        apply HasType.E_Prim
          (s := Release.Examples.sig [{}] [.lazy (.tvar 0)] (.tvar 0) Eff.empty .force)
        all_goals rfl
      simpa [fnTy_eq, Ty.subst, Ty.substAt, Ty.shift_zero, Eff.substRho_empty, FunDecl.dictTys, binds] using hf
    · exact .cons (.E_Local rfl (by intro b t ε h; cases h)) .nil

/-- Event は DecidableEq を持たないので、事象の種類と解放する値を観察する。 -/
inductive C4Event where
  | io (b : PrimName)
  | release (o : OpaqueName) (id : Nat) (error : Option ErrKind)
  | other
  deriving DecidableEq

def c4Event : Event → C4Event
  | .io b _ _ => .io b
  | .release (.const (.opaque o id)) error => .release o id error
  | _ => .other

inductive C4Result where
  | integer (n : Int)
  | ok (s : String)
  | error (s : String)
  | someInt (n : Int)
  | noneOption
  | fuelExhausted
  | other
  deriving DecidableEq

/-- 未終了の状態は、次の一歩が存在するときだけ燃料切れとして記録する。
組み込みの関数・解放の応答・確保は既存の Release の例を使う。 -/
def execC4 (fuel : Nat) (f : FunName) (args : List Val) : C4Result × List C4Event :=
  let core := desugarProgram execOp c4Program
  let (s, events) := Release.run core Release.Examples.builtins Release.Examples.oracle
    Release.Examples.rel Release.Examples.fresh fuel
    (.run (.app (.fnRef f [] []) args) [] Store.empty) []
  let result := match s with
    | .run (.ret (.const (.integer n))) [] _ => .integer n
    | .run (.ret (.con "Result.Ok" _ [.const (.string message)])) [] _ => .ok message
    | .run (.ret (.con "Result.Error" _ [.const (.string message)])) [] _ => .error message
    | .run (.ret (.con "Option.Some" _ [.const (.integer n)])) [] _ => .someInt n
    | .run (.ret (.con "Option.None" _ [])) [] _ => .noneOption
    | _ => if (Release.step core Release.Examples.builtins Release.Examples.oracle
        Release.Examples.rel Release.Examples.fresh s).isSome then .fuelExhausted else .other
  (result, events.map c4Event)

def okInput : Val := .con "Result.Ok" [intTy, stringTy] [vInt 11]
def errorInput : Val := .con "Result.Error" [intTy, stringTy] [.const (.string "bad")]

/-- 成功側では後続を評価する。失敗側では後続の Ok を作らず、呼び出した関数だけを抜ける。
Result の入力の成功型は Integer、戻り値の成功型は String である。 -/
theorem try_execution_rows :
    [("tryResult", [okInput], C4Result.ok "after"),
     ("tryResult", [errorInput], C4Result.error "bad"),
     ("tryOption", [.con "Option.Some" [intTy] [vInt 11]], C4Result.someInt 11),
     ("tryOption", [.con "Option.None" [intTy] []], C4Result.noneOption),
     ("tryCaller", [errorInput], C4Result.integer 42)].all
      (fun (f, args, result) => decide (execC4 100 f args = (result, []))) = true := by
  decide

/-- 通常終了で一回解放し、入れ子の途中の return では内側 2、外側 1 の順に解放する。
return の後の 99 は評価されない。 -/
theorem with_execution_rows :
    execC4 100 "withNormal" [.const (.opaque "File" 1)] =
      (.integer 5, [.release "File" 1 none]) ∧
    execC4 100 "withReturn" [.const (.opaque "File" 1), .const (.opaque "File" 2)] =
      (.integer 7, [.release "File" 2 none, .release "File" 1 none]) := by
  decide

/-- 同じ純粋な無限再帰を含む lazy を、強制せずに作ると 7 を返し、force すると燃料切れになる。
燃料を増やした場合も、強制しない例は終了し、強制した例には次の一歩が残る。 -/
theorem lazy_execution_rows :
    [40, 100].all (fun fuel => decide
      (execC4 fuel "lazyUnused" [] = (.integer 7, []) ∧
       execC4 fuel "lazyForced" [] = (.fuelExhausted, []))) = true := by
  decide

/-! ## C4a-2: ハンドラ・再開・利用者の操作

節の番号は継続、最後の引数から順に、外側の環境の順である。
以下の脱糖の一致を rfl で検査し、続く C4b-2 の例で型付けと実行も検査する。
-/

-- 01-12「ハンドラ」: 利用者の操作を値として使う。
theorem user_op_value_row :
    desugarExpr opPrim .other (.opName "Log.write" [intTy]) =
      .ret (.op "Log.write" [intTy]) := rfl

-- 同節: 操作を直接呼ぶ。操作の値の let を省き、引数は左から評価する。
theorem user_op_call_row :
    desugarExpr opPrim .tail (.call (.opName "Pair.choose" [.tvar 0])
      (.cons (.local 0) (.cons (.local 1) .nil))) =
      .letIn (.ret (.var 0)) (.letIn (.ret (.var 2))
        (.app (.op "Pair.choose" [.tvar 0]) [.var 1, .var 0])) := rfl

-- 同節: 原子的な引数にも let を作り、その下で継続の番号を増やす。
theorem resume_row :
    desugarExpr opPrim .tail (.resume 2 (.local 1)) =
      .letIn (.ret (.var 1)) (.resume (.var 3) (.var 0)) := rfl

-- 同節: 二つの節。利用者と組み込みの操作を区別し、引数と継続の順を保つ。
theorem handle_clauses_row :
    desugarExpr opPrim .tail (.handleE (.last (eInt 7))
      (.cons (.user "Pair.choose") 2 0 (.last (.resume 0 (.local 2)))
        (.cons (.prim "writeLine") 1 0 (.last (.resume 0 .unit)) .nil))) =
      .handle (.ret (vInt 7))
        [.mk (.user "Pair.choose") 2 0
          (.letIn (.ret (.var 2)) (.resume (.var 1) (.var 0))),
         .mk (.prim "writeLine") 1 0
          (.letIn (.ret (.const .unit)) (.resume (.var 1) (.var 0)))] := rfl

-- 本体と節の return は、handle 自体が末尾位置でも escape に移す。
theorem handle_return_other_row :
    desugarExpr opPrim .tail (.handleE (.last (.returnE intTy (eInt 7)))
      (.cons (.user "Abort.fail") 0 0 (.last (.returnE intTy (eInt 9))) .nil)) =
      .handle (.letIn (.ret (vInt 7)) (.escape (.var 0)))
        [.mk (.user "Abort.fail") 0 0 (.letIn (.ret (vInt 9)) (.escape (.var 0)))] := rfl

-- (i) 内側の handle の本体には、外側の節の継続が見える。
-- 外側の節で bind した後なので継続は番号 1。内側の節の (ii) は番号 0 を使う。
theorem nested_handle_resumes_row :
    desugarExpr opPrim .other (.handleE (.last (eInt 7))
      (.cons (.user "Outer.op") 2 0
        (.bind .bind intTy (eInt 9)
          (.last (.handleE (.last (.resume 1 (.local 0)))
            (.cons (.user "Inner.op") 1 0 (.last (.resume 0 (.local 1))) .nil)))) .nil)) =
      .handle (.ret (vInt 7))
        [.mk (.user "Outer.op") 2 0
          (.letIn (.ret (vInt 9))
            (.handle (.letIn (.ret (.var 0)) (.resume (.var 2) (.var 0)))
              [.mk (.user "Inner.op") 1 0
                (.letIn (.ret (.var 1)) (.resume (.var 1) (.var 0)))]))] := rfl

-- 番号を明示する表層では、内側の節から外側の継続を指す形も表せる。
-- 内側の継続と一引数の後、番号 2 が外側の継続である。
theorem inner_clause_outer_resume_row :
    desugarExpr opPrim .other (.handleE (.last (eInt 7))
      (.cons (.user "Outer.op") 0 0
        (.last (.handleE (.last (eInt 8))
          (.cons (.user "Inner.op") 1 0 (.last (.resume 2 (.local 1))) .nil))) .nil)) =
      .handle (.ret (vInt 7))
        [.mk (.user "Outer.op") 0 0
          (.handle (.ret (vInt 8))
            [.mk (.user "Inner.op") 1 0
              (.letIn (.ret (.var 1)) (.resume (.var 3) (.var 0)))])] := rfl

-- 操作 identity[T](value:T) -> T の節は、型変数 0 を束縛する。
-- 呼び出しの型引数は外側の型変数 0、節の引数は節の型変数 0 である。
theorem handle_polymorphic_op_row :
    desugarExpr opPrim .other (.handleE
      (.last (.call (.opName "Identity.identity" [.tvar 0]) (.cons (.local 0) .nil)))
      (.cons (.user "Identity.identity") 1 1 (.last (.resume 0 (.local 1))) .nil)) =
      .handle (.letIn (.ret (.var 0)) (.app (.op "Identity.identity" [.tvar 0]) [.var 0]))
        [.mk (.user "Identity.identity") 1 1
          (.letIn (.ret (.var 1)) (.resume (.var 1) (.var 0)))] := rfl

-- 節の型パラメータが一つなので、外側の Option[α0] の α0 は節で α1 になる。
-- try の retArgs と、成功側で作り直す Some の型引数も α1 をそのまま写す。
theorem handle_clause_try_option_row :
    desugarExpr opPrim .tail (.handleE (.last (.local 0))
      (.cons (.user "Abort.fail") 0 1
        (.last (.conCall "Option.Some" [.tvar 1]
          (.cons (.tryOption [.tvar 1] "Option.Some" "Option.None" (.local 1)) .nil))) .nil)) =
      .handle (.ret (.var 0))
        [.mk (.user "Abort.fail") 0 1
          (.letIn (.letIn (.ret (.var 1))
            (.match (.var 0) [.mk [⟨.con "Option.Some" [.var], [0]⟩] none (.ret (.var 0)),
              .mk [⟨.con "Option.None" [], []⟩] none (.escape (.con "Option.None" [.tvar 1] []))]))
            (.ret (.con "Option.Some" [.tvar 1] [.var 0])))] := rfl

-- 同じずらしを Result の二つの戻り値型引数にも適用済みの形で持つ。
theorem handle_clause_try_result_row :
    desugarExpr opPrim .other (.handleE .empty
      (.cons (.user "Abort.fail") 0 1
        (.lastDiscard (.tryResult [.tvar 1, .tvar 2] "Result.Ok" "Result.Error" (.local 1))) .nil)) =
      .handle (.ret (.const .unit))
        [.mk (.user "Abort.fail") 0 1
          (.letIn (.letIn (.ret (.var 1))
            (.match (.var 0) [.mk [⟨.con "Result.Ok" [.var], [0]⟩] none (.ret (.var 0)),
              .mk [⟨.con "Result.Error" [.var], [0]⟩] none
                (.escape (.con "Result.Error" [.tvar 1, .tvar 2] [.var 0]))]))
            (.ret (.const .unit)))] := rfl

/-! ## C4b-2: 多相な利用者の操作とハンドラの型付け・実行

Identity.identity[T](value:T) -> T の節は型パラメータを一つ束縛する。
resume する節は引数を本体へ返し、本体の続きがその値に 1 を足す。
resume しない節は 99 を返し、本体の続きは評価しない。
-/

def identityCall : Expr := .call (.opName "Identity.identity" [intTy]) (.cons (eInt 11) .nil)

def identityBody : Block := .bind .bind intTy identityCall
  (.last (.call (.primName "add" [] []) (.cons (.local 0) (.cons (eInt 1) .nil))))

def identityClauses (doResume : Bool) : Clauses :=
  .cons (.user "Identity.identity") 1 1
    (.last (if doResume then .resume 0 (.local 1) else eInt 99)) .nil

def identityHandled (doResume : Bool) : Expr := .handleE identityBody (identityClauses doResume)

def handlerProgram : Surface.Program where
  defs
    | "resumed" => some
        { tparams := [], neffs := 0, params := [], ret := intTy, eff := Eff.empty,
          body := .last (.returnE unitTy (identityHandled true)) }
    | "aborted" => some
        { tparams := [], neffs := 0, params := [], ret := intTy, eff := Eff.empty,
          body := .last (.returnE unitTy (identityHandled false)) }
    | _ => none
  cons := fun _ => none
  ops
    | "Identity.identity" => some
        { eff := "Identity", tparams := [{}], params := [.tvar 0], ret := .tvar 0 }
    | _ => none
  effects
    | "Identity" => some ["Identity.identity"]
    | _ => none

theorem identityCall_typed (Γ : List (Option Ty)) (R : Option Ty) :
    HasType handlerProgram.declarations Release.Examples.builtins execOp [] Γ R .other
      identityCall intTy (Eff.single "Identity") := by
  have hf : HasType handlerProgram.declarations Release.Examples.builtins execOp [] Γ R .other
      (.opName "Identity.identity" [intTy])
      (fnTy [.tvar 0] (.tvar 0) (Eff.single "Identity") [intTy] []) Eff.empty := by
    apply HasType.E_Op (od :=
      { eff := "Identity", tparams := [{}], params := [.tvar 0], ret := .tvar 0 })
    · rfl
    · exact ⟨rfl, by intro i t tp hi htp; trivial⟩
  have hf' : HasType handlerProgram.declarations Release.Examples.builtins execOp [] Γ R .other
      (.opName "Identity.identity" [intTy]) (.fn [intTy] intTy (Eff.single "Identity")) Eff.empty := by
    simpa [fnTy_eq, Ty.subst, Ty.substAt, Ty.shift_zero, Eff.substRho_nil] using hf
  simpa only [identityCall, eInt, union_empty_left] using HasType.E_Call (p := .other) hf'
    (HasTypes.cons (.E_Literal (l := .integer 11)) HasTypes.nil)

theorem identityBody_typed (Γ : List (Option Ty)) (R : Option Ty) :
    HasBlock handlerProgram.declarations Release.Examples.builtins execOp [] Γ R .other
      identityBody intTy (Eff.single "Identity") := by
  have hf : HasType handlerProgram.declarations Release.Examples.builtins execOp [] (some intTy :: Γ) R .other
      (.primName "add" [] []) (fnTy [intTy, intTy] intTy Eff.empty [] []) Eff.empty := by
    apply HasType.E_Prim (s := Release.Examples.sig [] [intTy, intTy] intTy Eff.empty .pure)
    all_goals rfl
  have hf' : HasType handlerProgram.declarations Release.Examples.builtins execOp [] (some intTy :: Γ) R .other
      (.primName "add" [] []) (.fn [intTy, intTy] intTy Eff.empty) Eff.empty := by
    simpa [fnTy_eq, Ty.subst, Ty.substAt, intTy, Eff.substRho_empty] using hf
  have ht := HasType.E_Call (p := .other) hf' (HasTypes.cons
    (.E_Local (i := 0) rfl (by intro b t ε h; cases h)) (HasTypes.cons (.E_Literal (l := .integer 1)) .nil))
  simpa only [identityBody, eInt, union_empty_left, union_empty_right] using
    HasBlock.B_Bind (k := .bind) (identityCall_typed Γ R) (HasBlock.B_Last ht)

/-- E_Handle・HasClauses.cons・E_Resume を使う導出。節では C と Γ と R の型をずらす。 -/
theorem identityHandled_typed (doResume : Bool) (Γ : List (Option Ty))
    (R : Option Ty) (pos : Position) :
    HasType handlerProgram.declarations Release.Examples.builtins execOp [] Γ R pos
      (identityHandled doResume) intTy Eff.empty := by
  apply HasType.E_Handle (identityBody_typed Γ R)
  · intro a ha
    have he : a = .name "Identity" := by simpa only [Eff.single, beq_iff_eq] using ha
    subst a
    rfl
  · apply HasClauses.cons
      (sg := { tparams := [{}], params := [.tvar 0], ret := .tvar 0, eff := "Identity" }) rfl rfl rfl
    · simp only [Ty.shift, intTy]
      apply HasBlock.B_Last
      cases doResume with
      | false => exact .E_Literal
      | true => exact .E_Resume rfl (.E_Local rfl (by intro b t ε h; cases h))
    · exact .nil

/-- 二つの実行例は、同じ宣言のもとで空のエフェクトを持つ関数として型が付く。 -/
theorem handler_definitions_typed :
    (∀ d, handlerProgram.defs "resumed" = some d →
      d.WellTyped handlerProgram.declarations Release.Examples.builtins execOp) ∧
    (∀ d, handlerProgram.defs "aborted" = some d →
      d.WellTyped handlerProgram.declarations Release.Examples.builtins execOp) := by
  constructor
  all_goals
    intro d hd
    have hd' : d = _ := (Option.some.inj hd).symm
    subst d
    exact ⟨Or.inl trivial, .B_Last (.E_ReturnTail (identityHandled_typed _ _ _ _))⟩

def execHandler (f : FunName) : C4Result × List C4Event :=
  let core := desugarProgram execOp handlerProgram
  let (s, events) := Release.run core Release.Examples.builtins Release.Examples.oracle
    Release.Examples.rel Release.Examples.fresh 100
    (.run (.app (.fnRef f [] []) []) [] Store.empty) []
  let result := match s with
    | .run (.ret (.const (.integer n))) [] _ => C4Result.integer n
    | _ => C4Result.other
  (result, events.map c4Event)

/-- 再開値 11 が続きへ渡ると 12 になる。再開しない節の 99 は、そのまま handle の結果になる。 -/
theorem handler_execution_rows :
    execHandler "resumed" = (.integer 12, []) ∧
    execHandler "aborted" = (.integer 99, []) := by
  decide

/-! ## C5a-1: 01-12「型クラス」の辞書、値として使う形、定義 -/

-- 辞書の決め方: 実装の制約の辞書を入れ子の実装の辞書として渡す。
theorem dict_impl_row :
    (DictEv.impl "ShowBox" [intTy]
      [.impl "ShowInteger" [] [], .impl "OrderBox" [intTy] [.local 2]]).toVal =
      .dict "ShowBox" [intTy]
        [.dict "ShowInteger" [] [], .dict "OrderBox" [intTy] [.var 2]] := rfl

-- 受け取った辞書の引数は Γ の同じ番号に写す。
theorem dict_local_row : (DictEv.local 3).toVal = .var 3 := rfl

-- V-Super: 上位の上位へは ↑ を重ね、辞書の値はそのまま保持する。
theorem dict_super_row :
    (DictEv.super (.super (.local 1) "Monoid") "Semigroup").toVal =
      .super (.super (.var 1) "Monoid") "Semigroup" := rfl

theorem dict_list_row : DictEv.toValList
    [.local 0, .super (.impl "MonoidInteger" [] []) "Semigroup"] =
      [.var 0, .super (.dict "MonoidInteger" [] []) "Semigroup"] := rfl

-- 第 4 行: return λ(ȳ:Ā). f[T̄; Ē](Ū, ȳ)。二つの辞書と二つの引数の順を確かめる。
theorem fun_dicts_value_row (pos : Position) :
    desugarExpr opPrim pos
      (.funDicts "renderPair" [intTy] [Eff.single "IO"]
        [.local 0, .super (.local 2) "Show"] [intTy, intTy]) =
      .ret (.lam [intTy, intTy]
        (.app (.fnRef "renderPair" [intTy] [Eff.single "IO"])
          [.var 2, .super (.var 4) "Show", .var 1, .var 0])) := rfl

-- 辞書の入れ子の自由変数も、ラムダの一引数の下でずらす。
theorem fun_dicts_nested_value_row :
    desugarExpr opPrim .other
      (.funDicts "render" [.list intTy] []
        [.impl "ShowList" [intTy] [.super (.local 1) "Show"]] [.list intTy]) =
      .ret (.lam [.list intTy]
        (.app (.fnRef "render" [.list intTy] [])
          [.dict "ShowList" [intTy] [.super (.var 2) "Show"], .var 0])) := rfl

-- 引数のない制約付き関数も、辞書だけを渡すラムダにする。
theorem fun_dicts_nullary_value_row :
    desugarExpr opPrim .other (.funDicts "empty" [intTy] [] [.local 1] []) =
      .ret (.lam [] (.app (.fnRef "empty" [intTy] []) [.var 1])) := rfl

-- 第 2 行: return λ(ȳ:Ā). V.m[S̄; Ē](Ū, ȳ)。V と自身の制約の辞書を両方ずらす。
-- この行は脱糖だけの例であり、型付けの例は後の meth_value_typed に置く。
theorem meth_value_row (pos : Position) :
    desugarExpr opPrim pos
      (.methName (.super (.super (.local 0) "Monoid") "Semigroup")
        "combine" [intTy] [Eff.single "IO"] [.local 2] [intTy, intTy]) =
      .ret (.lam [intTy, intTy]
        (.meth (.super (.super (.var 2) "Monoid") "Semigroup")
          "combine" [intTy] [Eff.single "IO"] [.var 4, .var 1, .var 0])) := rfl

-- 戻り値の型だけから辞書が決まるメソッドにも、新しい呼び出しの規則は要らない。
theorem meth_nullary_value_row :
    desugarExpr opPrim .other
      (.methName (.impl "MonoidInteger" [] []) "empty" [] [] [] []) =
      .ret (.lam [] (.meth (.dict "MonoidInteger" [] []) "empty" [] [] [])) := rfl

-- 第 3 行: 直接の呼び出しは頭を束縛せず、辞書を値引数の前に渡す。
theorem fun_dicts_call_row :
    desugarExpr opPrim .other
      (.call (.funDicts "render" [intTy] [] [.local 0] [intTy]) (.cons (eInt 7) .nil)) =
      .letIn (.ret (vInt 7)) (.app (.fnRef "render" [intTy] []) [.var 1, .var 0]) := rfl

def constrainedDef : Surface.Def :=
  { tparams := [{}, {}], neffs := 0, dictParams := [("Show", 0), ("Order", 1)],
    params := [.tvar 1, .tvar 0], ret := .tvar 0, eff := Eff.empty,
    body := .last (.returnE (.tvar 0) (.local 0)) }

-- 関数の制約ごとの Dict[Cl, α] は、Release.Def.params の先頭に置く。
theorem constrained_function_row : desugarDef opPrim constrainedDef =
    { tparams := [{}, {}], neffs := 0,
      params := [.dict "Show" (.tvar 0), .dict "Order" (.tvar 1), .tvar 1, .tvar 0],
      ret := .tvar 0, eff := Eff.empty, body := .ret (.var 0) } := rfl

def c5Class : Release.ClassDecl :=
  { supers := ["BoxSemigroup"], methods := fun m => match m with
      | "combine" => some
          { tparams := [], neffs := 0, params := [.tvar 0, .tvar 0],
            ret := .tvar 0, eff := Eff.empty }
      | "choose" => some
          { tparams := [{}], neffs := 1,
            params := [.dict "Show" (.tvar 0), .tvar 1, .tvar 0], ret := .tvar 0,
            eff := fun a => a == .rho 0 }
      | _ => none }

def c5Impl : Surface.ImplDecl :=
  { tparams := [{}], dictParams := [("Monoid", 0)], cls := "BoxMonoid",
    target := .data "Box" [.tvar 0],
    supers := fun s => if s == "BoxSemigroup" then
      some (.impl "BoxSemigroupI" [.tvar 0] [.super (.local 0) "Semigroup"]) else none,
    methods := fun m => match m with
      | "combine" => some (.last (.returnE (.data "Box" [.tvar 0]) (.local 0)))
      | "choose" => some (.last (.returnE (.tvar 0) (.local 0)))
      | _ => none }

def c5EmptyClass (supers : List ClassName := []) : Release.ClassDecl :=
  { supers := supers, methods := fun _ => none }

def c5SemigroupImpl : Surface.ImplDecl :=
  { tparams := [{}], dictParams := [("Semigroup", 0)], cls := "BoxSemigroup",
    target := .data "Box" [.tvar 0], supers := fun _ => none, methods := fun _ => none }

def c5IntegerImpl (cl : ClassName) : Surface.ImplDecl :=
  { tparams := [], dictParams := [], cls := cl, target := intTy,
    supers := fun _ => none, methods := fun _ => none }

def c5Program : Surface.Program :=
  { defs := fun f => if f == "renderPair" then some constrainedDef else none,
    cons := fun _ => none,
    classes := fun cl => match cl with
      | "BoxMonoid" => some c5Class
      | "Monoid" => some (c5EmptyClass ["Semigroup"])
      | "Semigroup" | "BoxSemigroup" | "Show" | "Order" => some (c5EmptyClass [])
      | _ => none,
    impls := fun i => match i with
      | "BoxMonoidI" => some c5Impl
      | "BoxSemigroupI" => some c5SemigroupImpl
      | "ShowInteger" => some (c5IntegerImpl "Show")
      | "OrderInteger" => some (c5IntegerImpl "Order")
      | _ => none }

-- 型クラスの宣言はそのまま写す。関数の表は名前を当てて比べる。
theorem class_declaration_row :
    ((desugarProgram opPrim c5Program).classes "BoxMonoid").bind (·.methods "choose") =
      some
        { tparams := [{}], neffs := 1,
          params := [.dict "Show" (.tvar 0), .tvar 1, .tvar 0], ret := .tvar 0,
          eff := fun a => a == .rho 0 } := rfl

-- D-Impl: 実装のシグネチャと辞書の引数を写す。
theorem implementation_signature_row :
    ((desugarProgram opPrim c5Program).impls "BoxMonoidI").map
      (fun id => (id.tparams, id.dictParams, id.cls, id.target, id.dictTys)) =
      some ([{}], [("Monoid", 0)], "BoxMonoid", .data "Box" [.tvar 0], [.dict "Monoid" (.tvar 0)]) := rfl

-- D-Impl: 上位の辞書 Ui は、実装の制約の辞書の引数を使える。
theorem implementation_super_row :
    ((desugarProgram opPrim c5Program).impls "BoxMonoidI").bind (·.supers "BoxSemigroup") =
      some (.dict "BoxSemigroupI" [.tvar 0] [.super (.var 0) "Semigroup"]) := rfl

-- D-Impl: メソッドの return を末尾位置で脱糖し、escape を作らない。
theorem implementation_method_row :
    ((desugarProgram opPrim c5Program).impls "BoxMonoidI").bind (·.methods "combine") =
      some (.ret (.var 0)) := rfl

theorem implementation_polymorphic_method_row :
    ((desugarProgram opPrim c5Program).impls "BoxMonoidI").bind (·.methods "choose") =
      some (.ret (.var 0)) := rfl

/-- D-Impl: 多相な choose の本体と、受け取った Monoid から取る上位辞書を検査する。 -/
theorem implementation_typed :
    Surface.ImplDecl.WellTyped c5Program.declarations Release.Examples.builtins opPrim c5Impl := by
  refine ⟨c5Class, rfl, ?_, ?_, ?_, ?_⟩
  · intro m; simp only [c5Impl, c5Class]; split <;> rfl
  · intro s; by_cases he : s = "BoxSemigroup" <;> simp [c5Impl, c5Class, he]
  · intro m ms hm
    simp only [c5Class] at hm
    split at hm
    · cases hm
      refine ⟨.last (.returnE (.data "Box" [.tvar 0]) (.local 0)), rfl, Or.inl trivial, ?_⟩
      exact .B_Last (.E_ReturnTail (.E_Local rfl (by intro b t ε h; simp [Surface.ImplDecl.methTy, c5Impl, Ty.substAt, Ty.shift] at h)))
    · cases hm
      refine ⟨.last (.returnE (.tvar 0) (.local 0)), rfl, Or.inl trivial, ?_⟩
      apply HasBlock.B_Last
      apply HasType.E_ReturnTail
      apply HasType.E_Sub (ε := Eff.empty) (.E_Local rfl (by intro b t ε h; simp [Surface.ImplDecl.methTy, Ty.substAt] at h)) (.refl _)
      exact Eff.empty_sub _
    · cases hm
  · intro s hs
    have he : s = "BoxSemigroup" := by simpa only [c5Class, List.mem_singleton] using hs
    subst s
    refine ⟨.impl "BoxSemigroupI" [.tvar 0] [.super (.local 0) "Semigroup"], rfl, ?_⟩
    have hdict : DictEv.HasType c5Program.declarations Release.Examples.builtins c5Impl.tparams
        (binds c5Impl.dictTys)
        (.impl "BoxSemigroupI" [.tvar 0] [.super (.local 0) "Semigroup"])
        (.dict c5SemigroupImpl.cls (c5SemigroupImpl.target.subst [.tvar 0] [])) := by
      apply DictEv.HasType.impl (id := c5SemigroupImpl.toImplSig) rfl
      · exact ⟨rfl, by intro i t tp hi htp; trivial⟩
      · simp only [c5SemigroupImpl, ImplSig.dictTys, List.map_cons, List.map_nil,
          Ty.subst, Ty.substAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero,
          List.getElem?_cons_zero, Option.getD_some, Ty.shift_zero]
        apply DictEv.HasTypes.cons
        · exact .super (.local rfl) (cd := c5EmptyClass ["Semigroup"]) rfl (by simp [c5EmptyClass])
        · exact .nil
    simpa [c5SemigroupImpl, c5Impl, Ty.subst, Ty.substAt, Ty.shift_zero] using hdict

/-- choose の受け手 V と自身の制約 Ū は Γ の局所辞書であり、実装表を使わない。 -/
theorem meth_value_typed (R : Option Ty) (pos : Position) :
    HasType c5Program.declarations Release.Examples.builtins opPrim []
      [some (.dict "BoxMonoid" (.data "Box" [intTy])), some (.dict "Show" intTy)] R pos
      (.methName (.local 0) "choose" [intTy] [Eff.single "IO"] [.local 1]
        [.data "Box" [intTy], intTy])
      (.fn [.data "Box" [intTy], intTy] intTy (Eff.single "IO")) Eff.empty := by
  let ms : MethSig :=
    { tparams := [{}], neffs := 1,
      params := [.dict "Show" (.tvar 0), .tvar 1, .tvar 0], ret := .tvar 0,
      eff := fun a => a == .rho 0 }
  have h : HasType c5Program.declarations Release.Examples.builtins opPrim []
      [some (.dict "BoxMonoid" (.data "Box" [intTy])), some (.dict "Show" intTy)] R pos
      (.methName (.local 0) "choose" [intTy] [Eff.single "IO"] [.local 1]
        [.data "Box" [intTy], intTy])
      (.fn [.data "Box" [intTy], intTy] (ms.ret.subst [intTy, .data "Box" [intTy]] [Eff.single "IO"])
        (Eff.substRho [Eff.single "IO"] ms.eff)) Eff.empty := by
    apply HasType.E_MethName (cd := c5Class) (ms := ms) (.local rfl) rfl rfl
    · exact ⟨rfl, by intro i t tp hi htp; trivial⟩
    · rfl
    · simp [ms, Ty.subst, Ty.substAt, Ty.shift_zero]
      exact .cons (.local rfl) .nil
    · simp [ms, Ty.subst, Ty.substAt, Ty.shift_zero]
    · intro a ha cl t
      simp only [List.head?_cons, Option.mem_def, Option.some.injEq] at ha
      subst a
      intro h; cases h
  have heff : Eff.substRho [Eff.single "IO"] ms.eff = Eff.single "IO" := by
    funext a
    cases a with
    | name l => simp [ms, Eff.substRho, Eff.single]
    | rho i => cases i <;> simp [ms, Eff.substRho, Eff.single]
  simpa [ms, Ty.subst, Ty.substAt, Ty.shift_zero, heff] using h

/-- renderPair の二つの型制約の辞書は値引数に含まれず、ラムダに捕える。 -/
theorem renderPair_value_typed (D : Declarations)
    (hd : D.funs "renderPair" = some constrainedDef.toFunDecl) (Γ : List (Option Ty))
    (ds : List DictEv)
    (hds : DictEv.HasTypes D Release.Examples.builtins [] Γ ds
      [.dict "Show" intTy, .dict "Order" intTy]) (R : Option Ty) (pos : Position) :
    HasType D Release.Examples.builtins opPrim [] Γ R pos
      (.funDicts "renderPair" [intTy, intTy] [] ds [intTy, intTy])
      (.fn [intTy, intTy] intTy Eff.empty) Eff.empty := by
  have h : HasType D Release.Examples.builtins opPrim [] Γ R pos
      (.funDicts "renderPair" [intTy, intTy] [] ds [intTy, intTy])
      (fnTy constrainedDef.params constrainedDef.ret constrainedDef.eff [intTy, intTy] []) Eff.empty := by
    apply HasType.E_FunDicts (d := constrainedDef.toFunDecl) hd
    · exact ⟨rfl, by intro i t tp hi htp; trivial⟩
    · rfl
    · decide
    · simp [constrainedDef, Ty.subst, Ty.substAt, Ty.shift_zero]
    · simpa [constrainedDef, FunDecl.dictTys, Ty.subst, Ty.substAt, Ty.shift_zero] using hds
  simpa [constrainedDef, fnTy_eq, Ty.subst, Ty.substAt, Ty.shift_zero, Eff.substRho_empty] using h


theorem fun_dicts_value_typed (R : Option Ty) (pos : Position) :
    HasType c5Program.declarations Release.Examples.builtins opPrim []
      [some (.dict "Show" intTy), some (.dict "Order" intTy)] R pos
      (.funDicts "renderPair" [intTy, intTy] [] [.local 0, .local 1] [intTy, intTy])
      (.fn [intTy, intTy] intTy Eff.empty) Eff.empty :=
  renderPair_value_typed _ rfl _ _ (.cons (.local rfl) (.cons (.local rfl) .nil)) R pos

/-- 値にした制約付き関数を f に束縛し、異なる二つの整数を渡す。 -/
def c5ValueDef : Surface.Def :=
  { tparams := [], neffs := 0, params := [], ret := intTy, eff := Eff.empty,
    body := .bind .bind (.fn [intTy, intTy] intTy Eff.empty)
      (.funDicts "renderPair" [intTy, intTy] []
        [.impl "ShowInteger" [] [], .impl "OrderInteger" [] []] [intTy, intTy])
      (.last (.returnE intTy (.call (.local 0) (.cons (eInt 7) (.cons (eInt 11) .nil))))) }

def c5ValueProgram : Surface.Program :=
  { c5Program with defs := fun f => if f == "main" then some c5ValueDef else c5Program.defs f }

theorem constrained_value_definition_typed :
    c5ValueDef.WellTyped c5ValueProgram.declarations Release.Examples.builtins opPrim := by
  refine ⟨Or.inl trivial, ?_⟩
  dsimp only [c5ValueDef, FunDecl.dictTys, binds, List.map, List.reverse_nil, List.nil_append]
  apply HasBlock.B_Sub (ε := Eff.union Eff.empty Eff.empty) _ (.refl _) (by
    simpa only [union_empty_left] using Eff.Sub.refl Eff.empty)
  apply HasBlock.B_Bind
  · apply renderPair_value_typed _ rfl
    apply DictEv.HasTypes.cons
    · simpa [c5IntegerImpl, intTy, Ty.subst, Ty.substAt] using
      (DictEv.HasType.impl (D := c5ValueProgram.declarations) (B := Release.Examples.builtins)
        (C := []) (Γ := []) (i := "ShowInteger") (ts := []) (ds := [])
        (id := (c5IntegerImpl "Show").toImplSig) rfl
        ⟨rfl, by intro i t tp hi; cases hi⟩ .nil)
    · apply DictEv.HasTypes.cons
      · simpa [c5IntegerImpl, intTy, Ty.subst, Ty.substAt] using
        (DictEv.HasType.impl (D := c5ValueProgram.declarations) (B := Release.Examples.builtins)
          (C := []) (Γ := []) (i := "OrderInteger") (ts := []) (ds := [])
          (id := (c5IntegerImpl "Order").toImplSig) rfl
          ⟨rfl, by intro i t tp hi; cases hi⟩ .nil)
      · exact .nil
  · apply HasBlock.B_Last
    apply HasType.E_ReturnTail
    simpa only [eInt, union_empty_left, union_empty_right] using
      (HasType.E_Call (D := c5ValueProgram.declarations) (B := Release.Examples.builtins) (opPrim := opPrim)
        (C := []) (Γ := [some (.fn [intTy, intTy] intTy Eff.empty)]) (R := some intTy) (p := .tail)
        (.E_Local rfl (by intro b t ε h; cases h))
        (.cons (.E_Literal (l := .integer 7)) (.cons (.E_Literal (l := .integer 11)) .nil)))

/-- 評価結果と事象を比較できる形に写す。完了した整数の結果だけを integer とする。 -/
def execConstrainedValue : C4Result × List C4Event :=
  let core := desugarProgram opPrim c5ValueProgram
  let (s, events) := Release.run core Release.Examples.builtins Release.Examples.oracle
    Release.Examples.rel Release.Examples.fresh 100
    (.run (.app (.fnRef "main" [] []) []) [] Store.empty) []
  let result := match s with
    | .run (.ret (.const (.integer n))) [] _ => C4Result.integer n
    | _ => C4Result.other
  (result, events.map c4Event)

/-- 辞書を捕えた f(7, 11) が第 2 引数 11 を返し、事象を起こさずに終了する。 -/
theorem constrained_value_execution : execConstrainedValue = (.integer 11, []) := by
  decide

/-! ## C5a-2: 直接の頭、パイプ、プレースホルダ、括弧、高カインド型

既存の辞書なしの例は頭に自由変数を持たない。ここでは頭の辞書と挿入引数の移動量を区別し、
括弧による値化の境界と、型構成子を具体化する契約を確かめる。 -/

-- 第 1 行: 受け手 V と自身の辞書 Ū、二つの値引数の順。
theorem meth_call_row :
    desugarExpr opPrim .other
      (.call (.methName (.local 0) "choose" [intTy] [Eff.single "IO"] [.local 1]
        [.data "Box" [intTy], intTy]) (.cons (.local 2) (.cons (eInt 7) .nil))) =
      .letIn (.ret (.var 2)) (.letIn (.ret (vInt 7))
        (.meth (.var 2) "choose" [intTy] [Eff.single "IO"] [.var 3, .var 1, .var 0])) := rfl

-- 規則 1: 辞書は shift + 1、挿入引数は 1 だけ移る。
theorem fun_dicts_pipe_call_row :
    desugarExpr opPrim .other
      (.pipe (.local 3) (.call
        (.funDicts "renderPair" [intTy] [] [.local 0, .super (.local 2) "Show"] [intTy, intTy])
        (.cons (.local 4) .nil))) =
      .letIn (.ret (.var 3)) (.letIn (.ret (.var 5))
        (.app (.fnRef "renderPair" [intTy] []) [.var 2, .super (.var 4) "Show", .var 1, .var 0])) := rfl

theorem meth_pipe_call_row :
    desugarExpr opPrim .other
      (.pipe (.local 2) (.call
        (.methName (.super (.local 0) "Show") "choose" [intTy] [] [.local 1] [intTy, intTy])
        (.cons (eInt 7) .nil))) =
      .letIn (.ret (.var 2)) (.letIn (.ret (vInt 7))
        (.meth (.super (.var 2) "Show") "choose" [intTy] [] [.var 3, .var 1, .var 0])) := rfl

-- 規則 2: 引数の let がなくても、パイプの let の下へ辞書を移す。
theorem fun_dicts_pipe_value_row :
    desugarExpr opPrim .other
      (.pipe (eInt 7) (.funDicts "render" [intTy] []
        [.impl "ShowBox" [intTy] [.super (.local 2) "Show"]] [intTy])) =
      .letIn (.ret (vInt 7)) (.app (.fnRef "render" [intTy] [])
        [.dict "ShowBox" [intTy] [.super (.var 3) "Show"], .var 0]) := rfl

theorem meth_pipe_value_row :
    desugarExpr opPrim .other
      (.pipe (eInt 7) (.methName (.local 0) "show" [intTy] [] [.local 1] [intTy])) =
      .letIn (.ret (vInt 7)) (.meth (.var 1) "show" [intTy] [] [.var 2, .var 0]) := rfl

-- 二つの穴と非穴の式。辞書はラムダ引数 2 個と let 3 個の下へ移す。
theorem fun_dicts_partial_row :
    desugarExpr opPrim .other
      (.partialCall (.funDicts "render" [intTy] []
        [.super (.local 0) "Show", .impl "OrderBox" [intTy] [.local 1]] [intTy, intTy, intTy])
        (.hole intTy (.expr (.local 2) (.hole intTy .nil))) intTy Eff.empty) =
      .ret (.lam [intTy, intTy]
        (.letIn (.ret (.var 1)) (.letIn (.ret (.var 5)) (.letIn (.ret (.var 2))
          (.app (.fnRef "render" [intTy] [])
            [.super (.var 5) "Show", .dict "OrderBox" [intTy] [.var 6], .var 2, .var 1, .var 0]))))) := rfl

theorem meth_partial_row :
    desugarExpr opPrim .other
      (.partialCall (.methName (.local 0) "choose" [intTy] [] [.local 1] [intTy, intTy])
        (.expr (.local 2) (.hole intTy .nil)) intTy Eff.empty) =
      .ret (.lam [intTy] (.letIn (.ret (.var 3)) (.letIn (.ret (.var 1))
        (.meth (.var 3) "choose" [intTy] [] [.var 4, .var 1, .var 0])))) := rfl

-- 括弧は prepare の直接の頭にしない。旧 fun_dicts_call_row の値化する形を保つ。
theorem fun_dicts_paren_call_row :
    desugarExpr opPrim .other
      (.call (.paren (.funDicts "render" [intTy] [] [.local 0] [intTy])) (.cons (eInt 7) .nil)) =
      .letIn (.ret (.lam [intTy] (.app (.fnRef "render" [intTy] []) [.var 1, .var 0])))
        (.letIn (.ret (vInt 7)) (.app (.var 1) [.var 0])) := rfl

-- x |> (Show.show): 右辺の括弧により値化したラムダを束縛する。
theorem meth_paren_pipe_row :
    desugarExpr opPrim .other
      (.pipe (eInt 7) (.paren (.methName (.local 0) "show" [] [] [] [intTy]))) =
      .letIn (.ret (vInt 7))
        (.letIn (.ret (.lam [intTy] (.meth (.var 2) "show" [] [] [.var 0])))
          (.app (.var 0) [.var 1])) := rfl

-- プレースホルダの頭にも括弧による値化を適用する。
theorem fun_dicts_paren_partial_row :
    desugarExpr opPrim .other
      (.partialCall (.paren (.funDicts "render" [intTy] [] [.local 0] [intTy]))
        (.hole intTy .nil) intTy Eff.empty) =
      .ret (.lam [intTy]
        (.letIn (.ret (.lam [intTy] (.app (.fnRef "render" [intTy] []) [.var 2, .var 0])))
          (.letIn (.ret (.var 1)) (.app (.var 1) [.var 0])))) := rfl

-- x |> render(a, _): 規則 2 の値化と、ラムダの本体の直接の頭の両方を通る。
theorem fun_dicts_partial_pipe_row :
    desugarExpr opPrim .other
      (.pipe (eInt 7) (.partialCall
        (.funDicts "render" [intTy] [] [.local 0] [intTy, intTy])
        (.expr (.local 1) (.hole intTy .nil)) intTy Eff.empty)) =
      .letIn (.ret (vInt 7))
        (.letIn (.ret (.lam [intTy] (.letIn (.ret (.var 3)) (.letIn (.ret (.var 1))
          (.app (.fnRef "render" [intTy] []) [.var 4, .var 1, .var 0])))))
          (.app (.var 0) [.var 1])) := rfl

/-- Functor の型クラス引数 P は 1、メソッドの型パラメータは 0。
P[A] を List[Integer] に具体化する、最小の identity メソッドである。 -/
def higherClass : Release.ClassDecl :=
  { supers := [], methods := fun m => if m == "identity" then some
      { tparams := [{}], neffs := 0, params := [.tapp 1 [.tvar 0]],
        ret := .tapp 1 [.tvar 0], eff := Eff.empty } else none }

def higherImpl : Surface.ImplDecl :=
  { tparams := [], dictParams := [], cls := "Functor", target := .ctor .list,
    supers := fun _ => none,
    methods := fun m => if m == "identity" then
      some (.last (.returnE (.list (.tvar 0)) (.local 0))) else none }

def higherProgram : Surface.Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none,
    classes := fun cl => if cl == "Functor" then some higherClass else none,
    impls := fun i => if i == "FunctorList" then some higherImpl else none }

def higherName : Expr :=
  .methName (.impl "FunctorList" [] []) "identity" [intTy] [] [] [.list intTy]

-- 第 1 行: List の型構成子を持つ実装の辞書を直接のメソッドへ渡す。
theorem higher_method_call_row :
    desugarExpr opPrim .other (.call higherName (.cons (.list intTy (.cons (eInt 7) .nil)) .nil)) =
      .letIn (.letIn (.ret (vInt 7)) (.ret (.list [.var 0])))
        (.meth (.dict "FunctorList" [] []) "identity" [intTy] [] [.var 0]) := rfl

-- 第 2 行: 高カインド型でも、括弧・局所束縛で使う値の形はラムダである。
theorem higher_method_value_row : desugarExpr opPrim .other higherName =
    .ret (.lam [.list intTy]
      (.meth (.dict "FunctorList" [] []) "identity" [intTy] [] [.var 0])) := rfl

theorem higher_method_value_typed (R : Option Ty) (pos : Position) :
    HasType higherProgram.declarations Release.Examples.builtins opPrim [] [] R pos higherName
      (.fn [.list intTy] (.list intTy) Eff.empty) Eff.empty := by
  let ms : MethSig :=
    { tparams := [{}], neffs := 0, params := [.tapp 1 [.tvar 0]],
      ret := .tapp 1 [.tvar 0], eff := Eff.empty }
  have h : HasType higherProgram.declarations Release.Examples.builtins opPrim [] [] R pos higherName
      (.fn [.list intTy] (ms.ret.subst [intTy, .ctor .list] []) (Eff.substRho [] ms.eff)) Eff.empty := by
    apply HasType.E_MethName (D := higherProgram.declarations) (d := .impl "FunctorList" [] [])
      (cl := "Functor") (τ := .ctor .list) (cd := higherClass) (ms := ms)
    · simpa only [higherImpl, Ty.subst, Ty.substAt] using
        (DictEv.HasType.impl (D := higherProgram.declarations)
        (B := Release.Examples.builtins) (C := []) (Γ := [])
        (i := "FunctorList") (ts := []) (id := higherImpl.toImplSig) rfl
          ⟨rfl, by intro i t tp hi htp; trivial⟩ .nil)
    · rfl
    · rfl
    · exact ⟨rfl, by intro i t tp hi htp; trivial⟩
    · rfl
    · exact .nil
    · simp [ms, Ty.subst, Ty.substAt, Ty.shift_zero, Ty.applyTo, TyCon.apply]
    · intro a ha cl t
      simp only [List.head?_cons, Option.mem_def, Option.some.injEq] at ha
      subst a
      intro h; cases h
  simpa [ms, Ty.subst, Ty.substAt, Ty.shift_zero, Ty.applyTo, TyCon.apply,
    Eff.substRho_empty] using h

theorem higher_method_call_typed (R : Option Ty) (pos : Position) :
    HasType higherProgram.declarations Release.Examples.builtins opPrim [] [] R pos
      (.call higherName (.cons (.list intTy (.cons (eInt 7) .nil)) .nil))
      (.list intTy) Eff.empty := by
  simpa only [union_empty_left, eInt] using HasType.E_Call (higher_method_value_typed R .other)
    (HasTypes.cons (HasType.E_List (by trivial) (HasEach.cons (HasType.E_Literal (l := .integer 7)) HasEach.nil)) HasTypes.nil)

/-! ## C6a-1: Decimal・リストの展開・文字列補間

期待値は Release の項を直接書く。式→変換→連結の順、空の側の省略、
変換関数が捕える辞書と元の自由変数の移動を別々に確かめる。
-/

def c6OpPrim : OpPrim
  | .binary .add, .base .string => some ("add_String", [])
  | o, t => opPrim o t

def concatInt : Expr := .primName "concat" [intTy] []
def strInt : Expr := .primName "str_Integer" [] []
def strTy : Ty := .base .string
def eStr (s : String) : Expr := .literal (.string s)
def vStr (s : String) : Val := .const (.string s)

-- 01-12「基本型とコレクションの型」: Decimal のリテラル。scale を保つ。
theorem literal_decimal_row : desugarExpr c6OpPrim .other (.literal (.decimal 150 2)) =
    .ret (.const (.decimal 150 2)) := rfl

-- 01-12「基本型とコレクションの型」: 直接の - を適用した Decimal のリテラル。負のゼロはない。
theorem neg_decimal_row : desugarExpr c6OpPrim .other (.negDecimal 150 2) =
    .ret (.const (.decimal (-150) 2)) := rfl
theorem neg_decimal_zero_row : desugarExpr c6OpPrim .other (.negDecimal 0 1) =
    .ret (.const (.decimal 0 1)) := rfl
theorem decimal_no_negative_zero : desugarExpr c6OpPrim .other (.negDecimal 0 1) =
    desugarExpr c6OpPrim .other (.literal (.decimal 0 1)) := rfl

-- 01-12「リストの展開」: 先頭。後続の式も、原子的であっても束縛する。
theorem spread_first_row : desugarExpr c6OpPrim .other
    (.listSpread intTy concatInt .nil (.local 2) (.cons (.local 0) (.cons (.local 1) .nil))) =
    .letIn (.ret (.var 2)) (.letIn (.ret (.var 1)) (.letIn (.ret (.var 3))
      (.app (.prim "concat" [intTy] []) [.var 2, .list [.var 1, .var 0]]))) := rfl

-- 同節: 途中。最初の concat だけを束縛し、最後の concat は末尾に置く。
theorem spread_middle_row : desugarExpr c6OpPrim .other
    (.listSpread intTy concatInt (.cons (eInt 1) .nil) (.local 0) (.cons (eInt 3) .nil)) =
    .letIn (.ret (vInt 1)) (.letIn (.ret (.var 1)) (.letIn (.ret (vInt 3))
      (.letIn (.app (.prim "concat" [intTy] []) [.list [.var 2], .var 1])
        (.app (.prim "concat" [intTy] []) [.var 0, .list [.var 1]])))) := rfl

-- 同節: 末尾。後ろの空リストとの連結を省く。
theorem spread_last_row : desugarExpr c6OpPrim .other
    (.listSpread intTy concatInt (.cons (eInt 1) (.cons (eInt 2) .nil)) (.local 0) .nil) =
    .letIn (.ret (vInt 1)) (.letIn (.ret (vInt 2)) (.letIn (.ret (.var 2))
      (.app (.prim "concat" [intTy] []) [.list [.var 2, .var 1], .var 0]))) := rfl

-- 同節: 前だけが空。Σ の関数を呼ぶ値として持たせる形。
theorem spread_before_empty_row : desugarExpr c6OpPrim .other
    (.listSpread intTy (.funName "concatFn" [intTy] []) .nil (.local 0) (.cons (eInt 3) .nil)) =
    .letIn (.ret (.var 0)) (.letIn (.ret (vInt 3))
      (.app (.fnRef "concatFn" [intTy] []) [.var 1, .list [.var 0]])) := rfl

-- 同節: 後ろだけが空。
theorem spread_after_empty_row : desugarExpr c6OpPrim .other
    (.listSpread intTy concatInt (.cons (eInt 1) .nil) (.local 0) .nil) =
    .letIn (.ret (vInt 1)) (.letIn (.ret (.var 1))
      (.app (.prim "concat" [intTy] []) [.list [.var 1], .var 0])) := rfl

-- 同節: 両側とも空。concat は呼ばず、展開の式は必ず束縛する。
theorem spread_both_empty_row : desugarExpr c6OpPrim .other
    (.listSpread intTy concatInt .nil (.local 0) .nil) =
    .letIn (.ret (.var 0)) (.ret (.var 0)) := rfl

-- 01-12「文字列補間」: String の式。変換しないが、式の値は束縛する。
theorem interpolation_string_row : desugarExpr c6OpPrim .other
    (.interpolation [.text "a", .stringExpr, .text "b"] (.cons (.local 0) .nil) .nil) =
    .letIn (.ret (.var 0))
      (.letIn (.app (.prim "add_String" [] []) [vStr "a", .var 0])
        (.app (.prim "add_String" [] []) [.var 0, vStr "b"])) := rfl

-- 同節: String 以外。変換→連結の順であり、断片の文字列は束縛しない。
theorem interpolation_integer_row : desugarExpr c6OpPrim .other
    (.interpolation [.text "n=", .converted intTy] (.cons (eInt 7) .nil) (.cons strInt .nil)) =
    .letIn (.ret (vInt 7)) (.letIn (.app (.prim "str_Integer" [] []) [.var 0])
      (.app (.prim "add_String" [] []) [vStr "n=", .var 0])) := rfl

-- 同節: 0 部分。空の断片を省く。連結の表も変換関数も不要である。
theorem interpolation_zero_parts_row : desugarExpr (fun _ _ => none) .other
    (.interpolation [.text "", .text ""] .nil .nil) = .ret (vStr "") := rfl

-- 同節: 1 部分（断片）。連結しない。
theorem interpolation_one_text_row : desugarExpr (fun _ _ => none) .other
    (.interpolation [.text "", .text "only", .text ""] .nil .nil) = .ret (vStr "only") := rfl

-- 同節: 1 部分（String の式）。空の前後を省き、束縛した値を return する。
theorem interpolation_one_string_row : desugarExpr (fun _ _ => none) .other
    (.interpolation [.text "", .stringExpr, .text ""] (.cons (.local 0) .nil) .nil) =
    .letIn (.ret (.var 0)) (.ret (.var 0)) := rfl

-- 同節: 1 部分（Integer の式）。str を末尾に置かず、その結果を束縛して return する。
theorem interpolation_one_converted_row : desugarExpr (fun _ _ => none) .other
    (.interpolation [.text "", .converted intTy, .text ""]
      (.cons (eInt 7) .nil) (.cons (.funName "strFn" [] []) .nil)) =
    .letIn (.ret (vInt 7)) (.letIn (.app (.fnRef "strFn" [] []) [.var 0])
      (.ret (.var 0))) := rfl

-- 同節: 連続する式。全式を評価してから変換し、最後の連結だけが末尾である。
theorem interpolation_adjacent_row : desugarExpr c6OpPrim .other
    (.interpolation [.converted intTy, .text "", .converted intTy]
      (.cons (eInt 1) (.cons (.local 0) .nil)) (.cons strInt (.cons strInt .nil))) =
    .letIn (.ret (vInt 1)) (.letIn (.ret (.var 1))
      (.letIn (.app (.prim "str_Integer" [] []) [.var 1])
        (.letIn (.app (.prim "str_Integer" [] []) [.var 1])
          (.app (.prim "add_String" [] []) [.var 1, .var 0])))) := rfl

-- 同節: 変換・String・Decimal。変換結果の束縛の下で String の式の番号もずらす。
theorem interpolation_mixed_row : desugarExpr c6OpPrim .other
    (.interpolation [.converted intTy, .stringExpr, .converted (.base .decimal)]
      (.cons (eInt 7) (.cons (.local 0) (.cons (.literal (.decimal 150 2)) .nil)))
      (.cons strInt (.cons (.primName "str_Decimal" [] []) .nil))) =
    .letIn (.ret (vInt 7)) (.letIn (.ret (.var 1)) (.letIn (.ret (.const (.decimal 150 2)))
      (.letIn (.app (.prim "str_Integer" [] []) [.var 2])
        (.letIn (.app (.prim "str_Decimal" [] []) [.var 1])
          (.letIn (.app (.prim "add_String" [] []) [.var 1, .var 3])
            (.app (.prim "add_String" [] []) [.var 0, .var 1])))))) := rfl

-- CallHead の辞書も、全式の束縛の下へ移す。値化のラムダは作らない。
theorem interpolation_dict_head_row : desugarExpr c6OpPrim .other
    (.interpolation [.converted intTy] (.cons (eInt 7) .nil)
      (.cons (.funDicts "strDict" [] [] [.local 0] [intTy]) .nil)) =
    .letIn (.ret (vInt 7)) (.letIn (.app (.fnRef "strDict" [] []) [.var 1, .var 0])
      (.ret (.var 0))) := rfl

-- メソッドの頭の受け手と辞書も、全式の束縛の下へ移す。
theorem interpolation_method_head_row : desugarExpr c6OpPrim .other
    (.interpolation [.converted intTy] (.cons (eInt 7) .nil)
      (.cons (.methName (.local 0) "str" [] [] [.local 1] [intTy]) .nil)) =
    .letIn (.ret (vInt 7)) (.letIn (.meth (.var 1) "str" [] [] [.var 2, .var 0])
      (.ret (.var 0))) := rfl

-- 0・1 部分の型付けにも +_String のシグネチャを要求しない。
theorem interpolation_zero_parts_typed {D B op C Γ R pos} :
    HasType D B op C Γ R pos (.interpolation [.text ""] .nil .nil) strTy Eff.empty := by
  apply HasType.E_Interpolation (parts := [.text ""]) trivial HasTypes.nil HasTypes.nil trivial
  simp [InterpPart.count]

theorem interpolation_one_string_typed {D B op C Γ R pos i}
    (hi : Γ[i]? = some (some strTy)) :
    HasType D B op C Γ R pos
      (.interpolation [.text "", .stringExpr, .text ""] (.cons (.local i) .nil) .nil)
      strTy Eff.empty := by
  have he := HasTypes.cons (HasType.E_Local (D := D) (B := B) (opPrim := op) (C := C)
    (R := R) hi (by intro _ _ _ he; cases he)) HasTypes.nil
  apply HasType.E_Interpolation (parts := [.text "", .stringExpr, .text ""]) trivial
    (by simpa only [InterpPart.exprTypes, union_empty_left, strTy] using he) HasTypes.nil trivial
  simp [InterpPart.count]


-- 01-12「レコード」構築: 宣言の順と逆に書く。自由変数も評価順にずらす。
theorem record_construct_row : desugarExpr opPrim .other
    (.record "Point" [] [1, 0] (.cons (.local 0) (.cons (eInt 10) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (vInt 10))
      (.ret (.con "Point" [] [.var 0, .var 1]))) := rfl

-- 同節の更新: 0・2 を残し、1 だけを更新する。書いた値は二つの束縛の下へ移す。
theorem record_update_partial_row : desugarExpr opPrim .other
    (.recordUpdate "TripleRecord" [] 3 [1] (.local 0) (.cons (.local 1) .nil)) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2))
      (.match (.var 1) [.mk [⟨.con "TripleRecord" [.var, .wild, .var], [0, 1]⟩] none
        (.ret (.con "TripleRecord" [] [.var 1, .var 2, .var 0]))])) := rfl

-- 同節の更新: 複数のフィールドを逆順で書く。元の自由変数を base と各 let の下へ移す。
theorem record_update_reordered_row : desugarExpr opPrim .other
    (.recordUpdate "TripleRecord" [] 3 [2, 0] (.local 0)
      (.cons (.local 1) (.cons (.local 2) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (.var 2)) (.letIn (.ret (.var 4))
      (.match (.var 2) [.mk [⟨.con "TripleRecord" [.wild, .var, .wild], [0]⟩] none
        (.ret (.con "TripleRecord" [] [.var 1, .var 0, .var 2]))]))) := rfl

-- 全フィールド更新でも match を残す。パターンは束縛を持たない。
theorem record_update_all_row : desugarExpr opPrim .other
    (.recordUpdate "Point" [] 2 [1, 0] (.local 0) (.cons (eInt 20) (.cons (eInt 10) .nil))) =
    .letIn (.ret (.var 0)) (.letIn (.ret (vInt 20)) (.letIn (.ret (vInt 10))
      (.match (.var 2) [.mk [⟨.con "Point" [.wild, .wild], []⟩] none
        (.ret (.con "Point" [] [.var 0, .var 1]))]))) := rfl

-- 同節のパターン: 書かなかった位置は _、書いた位置を宣言の順に並べる。
theorem record_pattern_partial_row :
    Pattern.toCore (.record "TripleRecord" 3 [2, 0] [.var, .integer 7]) =
    .con "TripleRecord" [.const (.integer 7), .wild, .var] := rfl

-- 入れ子でも同じ規則。番号 0 は最後に宣言されたフィールドの束縛である。
theorem record_pattern_nested_row :
    Pattern.toCore (.record "Outer" 2 [1, 0]
      [.var, .record "Inner" 3 [2, 0] [.var, .var]]) =
    .con "Outer" [.con "Inner" [.var, .wild, .var], .var] := rfl

def pointProgram : Surface.Program :=
  { defs := fun _ => none,
    cons := fun c => if c = "Point" then some ⟨"Point", 0, [intTy, intTy]⟩ else none,
    accessors := fun f => if f = "Point.y" then some ("Point", 1) else none }

/-- 取得関数の表は、範囲内の位置・単一構成子・通常の定義との非重複を満たす。 -/
theorem point_records_ok : pointProgram.RecordsOk := by
  intro f c k ha
  by_cases hf : f = "Point.y"
  · simp only [pointProgram, hf, ↓reduceIte, Option.some.injEq, Prod.mk.injEq] at ha
    obtain ⟨rfl, rfl⟩ := ha
    refine ⟨rfl, ⟨⟨"Point", 0, [intTy, intTy]⟩, by simp [pointProgram], by decide, ?_⟩⟩
    intro c' cd' hc _
    by_cases he : c' = "Point"
    · exact he
    · simp [pointProgram, he] at hc
  · simp [pointProgram, hf] at ha

-- 更新の網羅性の前提は、RecordsOk の単一構成子条件からも満たせる。
theorem record_update_typed {B op C Γ R pos}
    (hi : Γ[0]? = some (some (.data "Point" []))) :
    HasType pointProgram.declarations B op C Γ R pos
      (.recordUpdate "Point" [] 2 [1] (.local 0) (.cons (eInt 7) .nil))
      (.data "Point" []) Eff.empty := by
  obtain ⟨_, cd, hc, _, hu⟩ := point_records_ok "Point.y" "Point" 1 rfl
  have he : cd = ⟨"Point", 0, [intTy, intTy]⟩ := by simpa [pointProgram] using hc.symm
  subst cd
  have hex := recordUpdatePattern_exhaustive (P := pointProgram.declarations.patternProgram)
    (c := "Point") (cd := ⟨"Point", 0, [intTy, intTy]⟩)
    (ts := []) (positions := [1]) hc hu
  have hb := HasType.E_Local (D := pointProgram.declarations) (B := B) (opPrim := op)
    (C := C) (R := R) (p := .other) hi (by intro _ _ _ he; cases he)
  have hargs := HasTypes.cons (HasType.E_Literal (D := pointProgram.declarations) (B := B)
    (opPrim := op) (C := C) (Γ := Γ) (R := R) (l := .integer 7)) HasTypes.nil
  have h := HasType.E_RecordUpdate (p := pos) (c := "Point") (cd := ⟨"Point", 0, [intTy, intTy]⟩)
    (ts := []) (n := 2) (positions := [1]) hc rfl rfl
    (by decide) (by decide) (by intro i hi; simp at hi; subst i; decide) hb
    (by simpa [Ty.subst, Ty.substAt, intTy, Literal.toConst, Const.type] using hargs) hex
  simpa only [union_empty_right, Literal.toConst, Const.type, eInt] using h

-- 同節のフィールド取得関数: Σ に加えた定義を具体的な関数名で引く。
theorem record_accessor_row : (desugarProgram opPrim pointProgram).defs "Point.y" =
    some {
      tparams := [], neffs := 0, params := [.data "Point" []], ret := intTy, eff := Eff.empty,
      body := .match (.var 0) [.mk [⟨.con "Point" [.wild, .var], [0]⟩] none (.ret (.var 0))] } := rfl

-- 型パラメータは無制約。取得する型は構成子の宣言中の番号を保つ。
theorem record_accessor_polymorphic_row :
    accessorDef "Box" ⟨"Box", 1, [.tvar 0]⟩ 0 =
    { tparams := [{}], neffs := 0, params := [.data "Box" [.tvar 0]], ret := .tvar 0,
      eff := Eff.empty, body := .match (.var 0) [.mk [⟨.con "Box" [.var], [0]⟩] none (.ret (.var 0))] } := rfl

-- 通常の定義を先に引くことは宣言と Σ で共通（この重複した入力は RecordsOk を満たさない）。
def accessorOverlap : Surface.Program :=
  { pointProgram with
    defs := fun f =>
      if f = "Point.y" then
        some { tparams := [], neffs := 0, params := [], ret := unitTy,
               eff := Eff.empty, body := .empty }
      else none }

theorem record_lookup_priority_row :
    accessorOverlap.declarations.funs "Point.y" =
      some {
        tparams := [], neffs := 0, params := [], ret := unitTy, eff := Eff.empty } ∧
    (desugarProgram opPrim accessorOverlap).defs "Point.y" =
      some {
        tparams := [], neffs := 0, params := [], ret := unitTy, eff := Eff.empty,
        body := .ret (.const .unit) } := ⟨rfl, rfl⟩

def recordRunProgram : Surface.Program :=
  { pointProgram with
    defs := fun f =>
      if f = "main" then
        some {
          tparams := [], neffs := 0, params := [], ret := intTy, eff := Eff.empty,
          body := .last (.returnE intTy (.call (.funName "Point.y" [] [])
            (.cons (.recordUpdate "Point" [] 2 [1]
              (.record "Point" [] [1, 0] (.cons (eInt 2) (.cons (eInt 1) .nil)))
              (.cons (eInt 42) .nil)) .nil))) }
      else none }

-- 構築→一部の更新→フィールド取得を Release.run で実行し、値と事象数を確かめる。
def execRecordUpdateAccessor : C4Result × List C4Event :=
  let (s, events) := Release.run (desugarProgram opPrim recordRunProgram)
    Release.Examples.builtins Release.Examples.oracle Release.Examples.rel Release.Examples.fresh
    80 (.run (.app (.fnRef "main" [] []) []) [] Store.empty) []
  let result := match s with
    | .run (.ret (.const (.integer n))) [] _ => C4Result.integer n
    | _ => C4Result.other
  (result, events.map c4Event)

theorem record_update_accessor_run : execRecordUpdateAccessor = (.integer 42, []) := by decide

-- 01-12「トップレベルの定数」: 名前を本体の脱糖に置き換える。
theorem constant_row (pos : Position) :
    desugarExpr opPrim pos (.constE intTy (eInt 42)) = .ret (vInt 42) := rfl

/-- リストの定数の本体が、別の整数の定数を参照する。 -/
def nestedConstant : Expr :=
  .constE (.list intTy) (.list intTy (.cons (.constE intTy (eInt 42)) .nil))

theorem nested_constant_row (pos : Position) :
    desugarExpr opPrim pos nestedConstant =
      .letIn (.ret (vInt 42)) (.ret (.list [.var 0])) := rfl

-- 外側の値の変数があっても、定数の本体の let の番号は変わらない。
theorem constant_under_bind_row :
    desugarBlock opPrim .tail (.bind .bind intTy (eInt 7) (.last nestedConstant)) =
      .letIn (.ret (vInt 7)) (.letIn (.ret (vInt 42)) (.ret (.list [.var 0]))) := rfl

-- C・R は任意であり、使用位置の局所環境を本体の型付けに渡さない。
theorem nested_constant_typed (D : Declarations) (B : Builtins) (op : OpPrim)
    (C : List TParam) (Γ : List (Option Ty)) (R : Option Ty) (pos : Position) :
    HasType D B op C Γ R pos nestedConstant (.list intTy) Eff.empty := by
  apply HasType.E_Const
  apply HasType.E_List (by trivial)
  simpa only [union_empty_right, intTy, eInt, Literal.toConst, Const.type] using
    (HasEach.cons (HasType.E_Const (HasType.E_Literal (l := .integer 42)))
      (HasEach.nil (D := D) (B := B) (opPrim := op) (C := C) (Γ := []) (R := R)))

theorem constant_under_bind_typed (D : Declarations) (B : Builtins) (op : OpPrim)
    (C : List TParam) (Γ : List (Option Ty)) (R : Option Ty) :
    HasBlock D B op C Γ R .tail
      (.bind .bind intTy (eInt 7) (.last nestedConstant)) (.list intTy) Eff.empty := by
  have h := HasBlock.B_Bind (k := .bind) (t := intTy) (e := eInt 7) HasType.E_Literal
    (HasBlock.B_Last (nested_constant_typed D B op C (some intTy :: Γ) R .tail))
  simpa only [union_empty_right] using h

theorem nested_constant_scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) :
    nestedConstant.Scoped nt pe nv := by
  simp [nestedConstant, Expr.Scoped, Exprs.Scoped, intTy, eInt, Ty.VarsIn]

-- 使用位置で番号 0 が有効でも、定数の本体からは参照できない。
theorem constant_cannot_capture (nt : Nat) (pe : Nat → Prop) (nv : Nat) :
    ¬ (Expr.constE intTy (.local 0)).Scoped nt pe nv := by
  simp [Expr.Scoped]

/-! ## C7b-2: 表層のパターンの拡張

表層の型付け、独立したコアの期待値、脱糖した計算の実行を確かめる。
特に、偽のガードで残りの選択肢を飛ばすことと、挿入した let の下での
ガード・本体の束縛の保護は、Release の例だけでは検査できない。
-/

def c7Decls : Declarations :=
  { funs := fun _ => none,
    cons := fun c => if c = "A" ∨ c = "B" then
      some { data := "Choice", ntys := 0, args := [intTy, intTy] } else none }

def c7Fallback : Arms := .single .wild (.last (eInt 99)) .nil

private theorem c7Fallback_typed (D : Declarations) (a : Ty)
    (Γ : List (Option Ty)) (R : Option Ty) (pos : Position) :
    HasArms D Release.Examples.builtins opPrim [] Γ R pos c7Fallback a intTy Eff.empty := by
  simpa only [union_empty_right, c7Fallback, eInt, intTy, Literal.toConst, Const.type] using
    (HasArms.single (pat := .wild) trivial PatTy.P_Wild
      (HasBlock.B_Last (HasType.E_Literal (l := .integer 99))) (HasArms.nil trivial))

private theorem c7Covered (D : Declarations) (a : Ty) (ps : List Release.Pat)
    (hw : Release.Pat.wild ∈ ps) : Exhaustive D.patternProgram a ps := by
  intro v _
  exact ⟨.wild, hw, rfl⟩

/-- 最初の選択肢は false を、二番目は true を束縛する。
ガードが偽なら二番目の選択肢を試さず、次の分岐の 99 を返す。 -/
def c7GuardAlts : List Alternative :=
  [⟨.list [.var, .wild] none [], [0]⟩, ⟨.list [.wild, .var] none [], [0]⟩]

def c7GuardArms : Arms := .cons c7GuardAlts (some (.local 0)) (.last (eInt 1)) c7Fallback

def c7GuardMatch : Expr := .matchE intTy
  (.list (.base .boolean) (.cons eFalse (.cons eTrue .nil))) c7GuardArms

theorem c7Guard_typed : HasType c7Decls Release.Examples.builtins opPrim [] [] none .tail
    c7GuardMatch intTy Eff.empty := by
  have hp : AltsTy c7Decls.patternProgram (Alternative.toCoreList c7GuardAlts)
      (.list (.base .boolean)) [.base .boolean] := by
    refine ⟨by decide, rfl, ?_, ?_⟩
    · intro alt hh; simp [c7GuardAlts, Alternative.toCoreList] at hh; subst alt; rfl
    · intro alt hm
      simp only [c7GuardAlts, Alternative.toCoreList, List.map_cons, List.map_nil,
        List.mem_cons, List.not_mem_nil, or_false] at hm
      rcases hm with rfl | rfl
      · exact ⟨[.base .boolean], .P_List (.cons .P_Var (.cons .P_Wild .nil)) .nil
          (by intro _; rfl), .refl _, rfl⟩
      · exact ⟨[.base .boolean], .P_List (.cons .P_Wild (.cons .P_Var .nil)) .nil
          (by intro _; rfl), .refl _, rfl⟩
  have hs := HasArms.guarded (D := c7Decls) (B := Release.Examples.builtins) (opPrim := opPrim)
    (by intro alt hm; simp [c7GuardAlts] at hm; rcases hm with rfl | rfl <;>
        simp [Pattern.Valid, Pattern.ValidList]) hp
    (HasType.E_Local (i := 0) rfl (by intro b t e h; cases h))
    (HasBlock.B_Last (HasType.E_Literal (l := .integer 1)))
    (c7Fallback_typed c7Decls (.list (.base .boolean)) [] none .tail)
  have he := HasType.E_List (D := c7Decls) (B := Release.Examples.builtins)
    (opPrim := opPrim) (C := []) (Γ := []) (R := none) (p := .other) (a := .base .boolean) trivial
    (HasEach.cons (HasType.E_Literal (l := .boolean false))
      (HasEach.cons (HasType.E_Literal (l := .boolean true)) HasEach.nil))
  simpa only [union_empty_right, union_empty_left, c7GuardMatch, c7GuardArms,
    eInt, eTrue, eFalse, intTy, Literal.toConst, Const.type] using
    (HasType.E_Match (by intro h; cases h) he hs
      (c7Covered c7Decls _ _ (by simp [Arms.unguardedPatterns, c7Fallback,
        Arms.single, Alternative.toCoreList, Alternative.toCore, Pattern.toCore])))

theorem c7Guard_row : desugarExpr opPrim .tail c7GuardMatch =
    .letIn (.letIn (.ret (.const (.boolean false)))
      (.letIn (.ret (.const (.boolean true))) (.ret (.list [.var 1, .var 0]))))
      (.match (.var 0)
        [.mk [⟨.list [.var, .wild] none [], [0]⟩, ⟨.list [.wild, .var] none [], [0]⟩]
          (some (.ret (.var 0))) (.ret (vInt 1)),
         .mk [⟨.wild, []⟩] none (.ret (vInt 99))]) := rfl

/-- パターンの変数は番号 0、外側の Boolean は番号 1。
照合対象の let が外側の変数だけを一つずらす。 -/
theorem c7Guard_outer_row : desugarArms opPrim .tail
    (.cons [⟨.var, [0]⟩] (some (.local 1)) (.last (.local 0)) .nil) =
    [.mk [⟨.var, [0]⟩] (some (.ret (.var 2))) (.ret (.var 0))] := rfl

theorem c7Guard_run : (Release.run Release.Examples.program Release.Examples.builtins
    Release.Examples.oracle Release.Examples.rel Release.Examples.fresh 80
    (.run (desugarExpr opPrim .tail c7GuardMatch) [] Store.empty) []).1 =
    .run (.ret (vInt 99)) [] Store.empty := rfl

/-- A(x, y) の束縛順が分岐の変数の順。B(y, x) は slots で逆順にする。 -/
def c7ChoiceAlts : List Alternative :=
  [⟨.con none "A" [.var, .var], [0, 1]⟩, ⟨.con none "B" [.var, .var], [1, 0]⟩]

def c7ChoiceArms : Arms := .cons c7ChoiceAlts none (.last (.local 1)) c7Fallback

def c7ChoiceMatch : Expr := .matchE intTy
  (.conCall "B" [] (.cons (eInt 10) (.cons (eInt 20) .nil))) c7ChoiceArms

theorem c7Choice_typed : HasType c7Decls Release.Examples.builtins opPrim [] [] none .tail
    c7ChoiceMatch intTy Eff.empty := by
  have hp : AltsTy c7Decls.patternProgram (Alternative.toCoreList c7ChoiceAlts)
      (.data "Choice" []) [intTy, intTy] := by
    refine ⟨by decide, rfl, ?_, ?_⟩
    · intro alt hh; simp [c7ChoiceAlts, Alternative.toCoreList] at hh; subst alt; rfl
    · intro alt hm
      simp only [c7ChoiceAlts, Alternative.toCoreList, List.map_cons, List.map_nil,
        List.mem_cons, List.not_mem_nil, or_false] at hm
      rcases hm with rfl | rfl
      · exact ⟨[intTy, intTy], .P_Con
          (cd := { data := "Choice", ntys := 0, args := [intTy, intTy] })
          (by simp [c7Decls, Declarations.patternProgram]) rfl
          (by simpa [intTy, Ty.subst, Ty.substAt, Pattern.toCoreList, Pattern.toCore] using
            (PatTys.cons (PatTy.P_Var (a := intTy)) (PatTys.cons (PatTy.P_Var (a := intTy)) .nil))),
          .refl _, rfl⟩
      · exact ⟨[intTy, intTy], .P_Con
          (cd := { data := "Choice", ntys := 0, args := [intTy, intTy] })
          (by simp [c7Decls, Declarations.patternProgram]) rfl
          (by simpa [intTy, Ty.subst, Ty.substAt, Pattern.toCoreList, Pattern.toCore] using
            (PatTys.cons (PatTy.P_Var (a := intTy)) (PatTys.cons (PatTy.P_Var (a := intTy)) .nil))),
          .swap 0 1 [], rfl⟩
  have hs := HasArms.plain (D := c7Decls) (B := Release.Examples.builtins) (opPrim := opPrim)
    (by intro alt hm; simp [c7ChoiceAlts] at hm; rcases hm with rfl | rfl <;> trivial) hp
    (HasBlock.B_Last (HasType.E_Local (i := 1) rfl (by intro b t e h; cases h)))
    (c7Fallback_typed c7Decls (.data "Choice" []) [] none .tail)
  have he := HasType.E_ConCall (D := c7Decls) (B := Release.Examples.builtins)
    (opPrim := opPrim) (C := []) (Γ := []) (R := none) (p := .other) (c := "B") (ts := [])
    (cd := { data := "Choice", ntys := 0, args := [intTy, intTy] })
    (by simp [c7Decls]) rfl (by
      simpa [intTy, Ty.subst, Ty.substAt, eInt, Literal.toConst, Const.type] using
        (HasTypes.cons (HasType.E_Literal (l := .integer 10))
          (HasTypes.cons (HasType.E_Literal (l := .integer 20)) HasTypes.nil)))
  simpa only [union_empty_right, union_empty_left, c7ChoiceMatch, c7ChoiceArms,
    eInt, intTy, Literal.toConst, Const.type] using
    (HasType.E_Match (by intro h; cases h) he hs
      (c7Covered c7Decls _ _ (by simp [Arms.unguardedPatterns, c7Fallback,
        Arms.single, Alternative.toCoreList, Alternative.toCore, Pattern.toCore])))

theorem c7Choice_row : desugarExpr opPrim .tail c7ChoiceMatch =
    .letIn (.letIn (.ret (vInt 10)) (.letIn (.ret (vInt 20))
      (.ret (.con "B" [] [.var 1, .var 0])))) (.match (.var 0)
        [.mk [⟨.con "A" [.var, .var], [0, 1]⟩, ⟨.con "B" [.var, .var], [1, 0]⟩]
          none (.ret (.var 1)), .mk [⟨.wild, []⟩] none (.ret (vInt 99))]) := rfl

theorem c7Choice_run : (Release.run Release.Examples.choiceProgram Release.Examples.builtins
    Release.Examples.oracle Release.Examples.rel Release.Examples.fresh 80
    (.run (desugarExpr opPrim .tail c7ChoiceMatch) [] Store.empty) []).1 =
    .run (.ret (vInt 20)) [] Store.empty := rfl

/-- 範囲の負の下端と Character の両端は、そのままコアの定数に移す。 -/
def c7IntRange : Pattern := .range (.integer (-2)) (.integer 2)
def c7CharRange : Pattern := .range (.character 'a') (.character 'z')

theorem c7Range_rows :
    (desugarExpr opPrim .tail (.matchE intTy (.local 0)
      (.single c7IntRange (.last (eInt 1)) c7Fallback)),
     desugarExpr opPrim .tail (.matchE intTy (.local 0)
      (.single c7CharRange (.last (eInt 1)) c7Fallback))) =
    (.letIn (.ret (.var 0)) (.match (.var 0)
      [.mk [⟨.range (.integer (-2)) (.integer 2), []⟩] none (.ret (vInt 1)),
       .mk [⟨.wild, []⟩] none (.ret (vInt 99))]),
     .letIn (.ret (.var 0)) (.match (.var 0)
      [.mk [⟨.range (.character 'a') (.character 'z'), []⟩] none (.ret (vInt 1)),
       .mk [⟨.wild, []⟩] none (.ret (vInt 99))])) := rfl

theorem c7IntRange_typed : HasArms c7Decls Release.Examples.builtins opPrim [] [] none .tail
    (.single c7IntRange (.last (eInt 1)) c7Fallback) intTy intTy Eff.empty := by
  simpa only [union_empty_right, eInt, intTy, Literal.toConst, Const.type] using
    (HasArms.single (pat := c7IntRange) (by change (-2 : Int) ≤ 2; decide) PatTy.P_RangeInt
      (HasBlock.B_Last (HasType.E_Literal (l := .integer 1)))
      (c7Fallback_typed c7Decls intTy [] none .tail))

theorem c7CharRange_typed : HasArms c7Decls Release.Examples.builtins opPrim [] [] none .tail
    (.single c7CharRange (.last (eInt 1)) c7Fallback) (.base .character) intTy Eff.empty := by
  simpa only [union_empty_right, eInt, intTy, Literal.toConst, Const.type] using
    (HasArms.single (pat := c7CharRange) (by change 'a'.toNat ≤ 'z'.toNat; decide) PatTy.P_RangeChar
      (HasBlock.B_Last (HasType.E_Literal (l := .integer 1)))
      (c7Fallback_typed c7Decls (.base .character) [] none .tail))

theorem c7ReversedRange_rejected :
    ¬ (Pattern.range (.integer 2) (.integer (-2))).Valid := by
  change ¬ ((2 : Int) ≤ -2); decide

/-- 束縛は first、rest、last の順なので、rest は番号 1 になる。 -/
def c7ListPat : Pattern := .list [.var] (some .bind) [.var]

def c7ListArms : Arms := .single c7ListPat (.last (.local 1))
  (.single .wild (.last (.list intTy .nil)) .nil)

theorem c7List_typed : HasArms c7Decls Release.Examples.builtins opPrim [] [] none .tail
    c7ListArms (.list intTy) (.list intTy) Eff.empty := by
  have hp : PatTy c7Decls.patternProgram c7ListPat.toCore (.list intTy)
      [intTy, .list intTy, intTy] :=
    .P_List (.cons .P_Var .nil) (.cons .P_Var .nil) (by intro h; cases h)
  simpa only [union_empty_right, c7ListArms, eInt, intTy, Literal.toConst, Const.type] using
    (HasArms.single (pat := c7ListPat) (by simp [c7ListPat, Pattern.Valid, Pattern.ValidList]) hp
      (HasBlock.B_Last (HasType.E_Local (i := 1) rfl (by intro b t e h; cases h)))
      (HasArms.single (pat := .wild) trivial PatTy.P_Wild
        (HasBlock.B_Last (HasType.E_List (a := intTy) trivial HasEach.nil)) (HasArms.nil trivial)))

theorem c7List_row : desugarArms opPrim .tail c7ListArms =
    [.mk [⟨.list [.var] (some .bind) [.var], [0, 1, 2]⟩] none (.ret (.var 1)),
     .mk [⟨.wild, []⟩] none (.ret (.list []))] := rfl

theorem c7List_without_rest_rejected : ¬ (Pattern.list [] none [.var]).Valid := by
  simp [Pattern.Valid]

/-- P12: 外側の節の継続は、番号を保ったままガードの環境から消える。
E_Resume の lookup の前提は、隠した番号について成立しない。 -/
theorem c7Guard_hides_outer_cont (b t : Ty) (ε : Eff) (Γ : List (Option Ty)) :
    hideConts (binds [intTy] ++ some (.cont b t ε) :: Γ) =
      some intTy :: none :: hideConts Γ := rfl

theorem c7Guard_outer_resume_lookup_impossible (b t : Ty) (ε : Eff)
    (Γ : List (Option Ty)) (b' t' : Ty) (ε' : Eff) :
    (hideConts (binds [intTy] ++ some (.cont b t ε) :: Γ))[1]? ≠
      some (some (.cont b' t' ε')) := by
  simp [c7Guard_hides_outer_cont]

/-- hideConts 後は、どの番号にも継続の型を検索できない。 -/
theorem c7Guard_hideConts_lookup_impossible (Γ : List (Option Ty)) (k : Nat)
    (b t : Ty) (ε : Eff) :
    (hideConts Γ)[k]? ≠ some (some (.cont b t ε)) := by
  induction Γ generalizing k with
  | nil => simp [hideConts]
  | cons x Γ ih =>
      cases k with
      | zero =>
          cases x with
          | none => simp [hideConts]
          | some a => cases a <;> simp [hideConts]
      | succ k => simpa [hideConts] using ih k

/-- E_Sub の連鎖を外すと、resume は必ず E_Resume の検索の前提を持つ。 -/
private theorem c7Guard_inv_resume {D B op C Γ R pos k e a ε}
    (h : HasType D B op C Γ R pos (.resume k e) a ε) :
    ∃ b t εk, Γ[k]? = some (some (.cont b t εk)) := by
  generalize he : Expr.resume k e = expr at h
  revert he
  apply HasType.rec (motive_1 := fun _ Γ _ _ expr _ _ _ =>
    Expr.resume k e = expr → ∃ b t εk, Γ[k]? = some (some (.cont b t εk)))
    (motive_2 := fun _ _ _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ _ _ => True)
    (motive_4 := fun _ _ _ _ _ _ _ => True)
    (motive_5 := fun _ _ _ _ _ _ _ _ _ => True)
    (motive_6 := fun _ _ _ _ _ _ _ => True)
    (motive_7 := fun _ _ _ _ _ _ _ _ => True) (t := h)
  all_goals intros
  all_goals first | exact True.intro | (rename_i he; cases he)
  · exact ⟨_, _, _, by assumption⟩
  · rename_i ih
    exact ih rfl

/-- E_ReturnTail・E_ReturnOther は、E_Sub を経由しても戻り先を必要とする。 -/
private theorem c7Guard_inv_return {D B op C Γ R pos t e a ε}
    (h : HasType D B op C Γ R pos (.returnE t e) a ε) :
    ∃ r, R = some r := by
  generalize he : Expr.returnE t e = expr at h
  revert he
  apply HasType.rec (motive_1 := fun _ _ R _ expr _ _ _ =>
    Expr.returnE t e = expr → ∃ r, R = some r)
    (motive_2 := fun _ _ _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ _ _ => True)
    (motive_4 := fun _ _ _ _ _ _ _ => True)
    (motive_5 := fun _ _ _ _ _ _ _ _ _ => True)
    (motive_6 := fun _ _ _ _ _ _ _ => True)
    (motive_7 := fun _ _ _ _ _ _ _ _ => True) (t := h)
  all_goals intros
  all_goals first | exact True.intro | (rename_i he; cases he)
  · exact ⟨_, rfl⟩
  · exact ⟨_, rfl⟩
  · rename_i ih
    exact ih rfl

/-- 局所変数の型は、E_Sub の連鎖で検索した型から広がるだけである。 -/
private theorem c7Guard_inv_local {D B op C Γ R pos k a ε}
    (h : HasType D B op C Γ R pos (.local k) a ε) :
    ∃ t, Γ[k]? = some (some t) ∧ Ty.Le t a := by
  generalize he : Expr.local k = expr at h
  revert he
  apply HasType.rec (motive_1 := fun _ Γ _ _ expr a _ _ =>
    Expr.local k = expr → ∃ t, Γ[k]? = some (some t) ∧ Ty.Le t a)
    (motive_2 := fun _ _ _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ _ _ => True)
    (motive_4 := fun _ _ _ _ _ _ _ => True)
    (motive_5 := fun _ _ _ _ _ _ _ _ _ => True)
    (motive_6 := fun _ _ _ _ _ _ _ => True)
    (motive_7 := fun _ _ _ _ _ _ _ _ => True) (t := h)
  all_goals intros
  all_goals first | exact True.intro | (rename_i he; cases he)
  · exact ⟨_, by assumption, .refl _⟩
  · rename_i ih
    obtain ⟨t, ht, hle⟩ := ih rfl
    exact ⟨t, ht, hle.trans (by assumption)⟩

/-- 呼び出しのエフェクトは、E_Sub を経由しても呼ぶ関数のエフェクトを含む。 -/
private theorem c7Guard_inv_call {D B op C Γ R pos f args a ε}
    (h : HasType D B op C Γ R pos (.call f args) a ε) :
    ∃ ps t εf εcall, HasType D B op C Γ R .other f (.fn ps t εcall) εf ∧
      Eff.Sub εcall ε := by
  generalize he : Expr.call f args = expr at h
  revert he
  apply HasType.rec (motive_1 := fun C Γ R _ expr _ ε _ =>
    Expr.call f args = expr →
    ∃ ps t εf εcall, HasType D B op C Γ R .other f (.fn ps t εcall) εf ∧
      Eff.Sub εcall ε)
    (motive_2 := fun _ _ _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ _ _ => True)
    (motive_4 := fun _ _ _ _ _ _ _ => True)
    (motive_5 := fun _ _ _ _ _ _ _ _ _ => True)
    (motive_6 := fun _ _ _ _ _ _ _ => True)
    (motive_7 := fun _ _ _ _ _ _ _ _ => True) (t := h)
  all_goals intros
  all_goals first | exact True.intro | (rename_i he; cases he)
  · refine ⟨_, _, _, _, by assumption, ?_⟩
    intro l hl
    simp [Eff.union, hl]
  · rename_i ih
    obtain ⟨ps, t, εf, εcall, hf, hsub⟩ := ih rfl
    exact ⟨ps, t, εf, εcall, hf, hsub.trans (by assumption)⟩

/-- 引数は Integer、再開結果は Boolean、エフェクトは空である。
HasArms.guarded が外側の継続を隠すため、この分岐に型は付かない。 -/
theorem c7Guard_outer_resume_rejected :
    ¬ HasArms c7Decls Release.Examples.builtins opPrim []
      [some (.cont intTy (.base .boolean) Eff.empty)] none .tail
      (.cons [⟨.var, [0]⟩] (some (.resume 1 (eInt 0))) (.last (eInt 1)) .nil)
      intTy intTy Eff.empty := by
  intro h
  generalize Eff.empty = ε at h
  cases h with
  | guarded _ _ hg _ _ =>
      obtain ⟨b, t, εk, hk⟩ := c7Guard_inv_resume hg
      exact c7Guard_hideConts_lookup_impossible _ _ b t εk hk

/-- Boolean を返す局所関数の呼び出しは、Console.Write を空に縮められない。
ワイルドカードは束縛を加えないので、局所関数の番号は 0 のままである。 -/
theorem c7Guard_effectful_rejected :
    ¬ HasArms c7Decls Release.Examples.builtins opPrim []
      [some (.fn [] (.base .boolean) (Eff.single "Console.Write"))] none .tail
      (.cons [⟨.wild, []⟩] (some (.call (.local 0) .nil)) (.last (eInt 1)) .nil)
      intTy intTy Eff.empty := by
  intro h
  generalize Eff.empty = ε at h
  cases h with
  | guarded _ hp hg _ _ =>
      have hδ : _ = [] := List.eq_nil_of_length_eq_zero hp.2.1
      subst hδ
      obtain ⟨ps, t, εf, εcall, hf, hs⟩ := c7Guard_inv_call hg
      obtain ⟨t0, ht, hle⟩ := c7Guard_inv_local hf
      have ht0 : t0 = .fn [] (.base .boolean) (Eff.single "Console.Write") := by
        simpa [binds, hideConts] using ht.symm
      rw [ht0] at hle
      obtain ⟨_, _, hsfn⟩ := Ty.Le.fn_fn' hle
      have hwrite := (hsfn.trans hs) (.name "Console.Write") rfl
      cases hwrite

/-- ガードは R = none で検査するため、Boolean の return にも型は付かない。 -/
theorem c7Guard_return_rejected :
    ¬ HasArms c7Decls Release.Examples.builtins opPrim [] [] (some (.base .boolean)) .tail
      (.cons [⟨.wild, []⟩] (some (.returnE (.base .boolean) eTrue))
        (.last (eInt 1)) .nil) intTy intTy Eff.empty := by
  intro h
  generalize Eff.empty = ε at h
  cases h with
  | guarded _ _ hg _ _ =>
      obtain ⟨r, hr⟩ := c7Guard_inv_return hg
      cases hr

end Benitoite.Surface.Examples
