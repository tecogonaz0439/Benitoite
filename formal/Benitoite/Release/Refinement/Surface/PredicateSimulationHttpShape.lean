import Benitoite.Release.Refinement.Surface.PredicateSimulationABI
import Benitoite.Release.Refinement.StandardModelComposedRows

/-! # 標準の要求の型付きの値の構造

標準の包含が既存dataへの構成子の追加を断ることを使い、要求とヘッダの値に
関数の本体が入らないことを同じプログラムの宣言から導く。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open StandardModel ScopeDeclarations PredicateOverlayExternal
noncomputable section

private def pairDecl : ConDecl := ⟨"Pair",2,[.tvar 0,.tvar 1]⟩
private def requestDecl : ConDecl := ⟨"Http.ClientRequest",0,
  [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),.bytes,.base .integer]⟩

private theorem standard_request_pair {externals c cd}
    (found : (StandardModel.program externals).cons c = some cd)
    (owner : cd.data = "Pair" ∨ cd.data = "Http.ClientRequest") :
    (c = "Pair.Pair" ∧ cd = pairDecl) ∨ (c = "Http.ClientRequest" ∧ cd = requestDecl) := by
  rcases (constructors_split (cons_mem found)).symm with member | member
  · obtain ⟨_,owned,_⟩ := ScopeDeclarations.public_entry member
    have different : ∀ name ∈ ScopePublic.declarations.map ScopePublic.PublicData.name,
        name ≠ "Pair" ∧ name ≠ "Http.ClientRequest" := by decide
    rcases owner with same | same
    · exact False.elim ((different _ owned).1 same)
    · exact False.elim ((different _ owned).2 same)
  · simp [baseDeclarations,byteOrder,roundingMode,checkError,StandardOrdinaryCoreBodies.declarations,
      ScopeDeclarations.base,ScopeDeclarations.file,ScopeDeclarations.result,ScopeDeclarations.scopeError,
      ScopeDeclarations.pair,ScopeDeclarations.clientRequest,ScopeDeclarations.requestCheckError,
      StandardKeyTyping.DataDecl.entries,StandardOrdinaryCoreBodies.Record.owner,StandardSafe.names] at member
    repeat' first | (rcases member with ⟨rfl,rfl⟩ | member) | (rcases member with ⟨rfl,rfl⟩)
    all_goals simp_all [pairDecl,requestDecl]

private theorem included_request_pair {externals P c cd} (included : Includes externals P)
    (found : P.cons c = some cd) (owner : cd.data = "Pair" ∨ cd.data = "Http.ClientRequest") :
    (c = "Pair.Pair" ∧ cd = pairDecl) ∨ (c = "Http.ClientRequest" ∧ cd = requestDecl) := by
  have oldData : (StandardModel.program externals).HasData cd.data := by
    rcases owner with same | same
    · rw [same]
      exact Or.inl ⟨"Pair.Pair",pairDecl,rfl,rfl⟩
    · rw [same]
      exact Or.inl ⟨"Http.ClientRequest",requestDecl,rfl,rfl⟩
  exact standard_request_pair (included.extends_.consClosed c cd found oldData) owner

private theorem included_pair {externals P c cd} (included : Includes externals P)
    (found : P.cons c = some cd) (owner : cd.data = "Pair") : c = "Pair.Pair" ∧ cd = pairDecl := by
  rcases included_request_pair included found (Or.inl owner) with same | ⟨_,same⟩
  · exact same
  · subst cd
    simp [requestDecl] at owner

private theorem included_request {externals P c cd} (included : Includes externals P)
    (found : P.cons c = some cd) (owner : cd.data = "Http.ClientRequest") :
    c = "Http.ClientRequest" ∧ cd = requestDecl := by
  rcases included_request_pair included found (Or.inr owner) with ⟨_,same⟩ | same
  · subst cd
    simp [pairDecl] at owner
  · exact same

/-- 標準の包含は、文字列どうしのヘッダの組を受渡し可能な構造として供給する。 -/
theorem header_shape {externals P} (included : Includes externals P) (component : ComponentId) (unit : Bool) :
    ExternalValueType P component unit (.data "Pair" [.base .string,.base .string]) := by
  have http := StandardModel.HasDeclarations.ofExtends included.extends_ (http_declarations externals)
  have pair := http ScopeDeclarations.pair (by simp [ScopeDeclarations.http])
  have lookup : P.cons "Pair.Pair" = some pairDecl :=
    pair.2 ("Pair.Pair",pairDecl) (by simp [ScopeDeclarations.pair,StandardKeyTyping.DataDecl.entries,pairDecl])
  refine .data ["Pair.Pair"] (by simp) (by simp) ?_ pair.1 ?_
  · intro name
    constructor
    · intro member
      cases List.mem_singleton.mp member
      exact ⟨pairDecl,lookup,rfl⟩
    · rintro ⟨decl,found,owner⟩
      rw [(included_pair included found owner).1]
      exact List.mem_cons_self
  · intro name decl found owner a member
    obtain ⟨_,rfl⟩ := included_pair included found owner
    simp only [pairDecl,List.mem_cons,List.not_mem_nil,or_false] at member
    rcases member with rfl | rfl <;> exact .scalar trivial

/-- 標準の包含は、要求全体の文字列・ヘッダ・bytes・整数の構造を供給する。 -/
theorem request_shape {externals P} (included : Includes externals P) (component : ComponentId) (unit : Bool) :
    ExternalValueType P component unit TargetTable.clientRequestTy := by
  have http := StandardModel.HasDeclarations.ofExtends included.extends_ (http_declarations externals)
  have request := http ScopeDeclarations.clientRequest (by simp [ScopeDeclarations.http])
  have lookup : P.cons "Http.ClientRequest" = some requestDecl :=
    request.2 ("Http.ClientRequest",requestDecl)
      (by simp [ScopeDeclarations.clientRequest,StandardKeyTyping.DataDecl.entries,requestDecl])
  refine .data ["Http.ClientRequest"] (by simp) (by simp) ?_ request.1 ?_
  · intro name
    constructor
    · intro member
      cases List.mem_singleton.mp member
      exact ⟨requestDecl,lookup,rfl⟩
    · rintro ⟨decl,found,owner⟩
      rw [(included_request included found owner).1]
      exact List.mem_cons_self
  · intro name decl found owner a member
    obtain ⟨_,rfl⟩ := included_request included found owner
    simp only [requestDecl,List.mem_cons,List.not_mem_nil,or_false] at member
    rcases member with rfl | rfl | rfl | rfl | rfl
    · exact .scalar trivial
    · exact .scalar trivial
    · exact .list (header_shape included component false)
    · exact .bytes
    · exact .scalar trivial

/-- 型付き要求の対応は、元の要求全体と準備後の要求全体の生の等号を与える。 -/
theorem request_value_equal {externals P B Ψ Q source rows x y} (included : Includes externals P)
    (valid : P.VarianceValid) (typed : HasTypeVQ P B Ψ Q [] [] [] y TargetTable.clientRequestTy)
    (related : Value source rows x y) : x = y :=
  abi_argument_equal valid (request_shape included (.mk 0) true) typed related

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
