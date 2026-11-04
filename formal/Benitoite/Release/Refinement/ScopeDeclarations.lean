import Benitoite.Release.Refinement.StandardKeyTyping
import Benitoite.Release.Refinement.AtContracts

/-! # 範囲付きモデルが読む有限の構成子宣言と全 arity -/
namespace Benitoite.Release.Refinement.ScopeDeclarations
open StandardKeyTyping

/-- 指定した構成子の lookup と、同じデータ名の全構成子の arity を検査する。 -/
def HasDeclarations (P : Program) (ds : List DataDecl) : Prop :=
  ∀ d ∈ ds, P.DataArity d.name d.ntys ∧
    ∀ c ∈ d.entries, P.cons c.1 = some c.2

def result : DataDecl := ⟨"Result",2,
  [("Result.Ok",[.tvar 0]),("Result.Error",[.tvar 1])]⟩

/-- At の既存の内部観測を含む宣言。 -/
def scopeError : DataDecl := ⟨"Scope.ScopeError",0,[
  ("Scope.ScopeError.InvalidPattern",[.base .string,.base .string]),
  ("Scope.ScopeError.InvalidTarget",[.base .string,.base .string]),
  ("Scope.ScopeError.InvalidPortRange",[.base .integer,.base .integer]),
  ("Scope.ScopeError.InvalidPort",[.base .integer]),
  ("Scope.ScopeError.OutsideScope",[.base .string,.base .string]),
  ("Scope.ScopeError.PortOutsideScope",[.base .integer,.base .integer,.base .integer]),
  ("Scope.ScopeError.At",atErrorFields)]⟩

def file : List DataDecl := [result,scopeError]
def HasFile (P : Program) : Prop := HasDeclarations P file

def pair : DataDecl := ⟨"Pair",2,[("Pair.Pair",[.tvar 0,.tvar 1])]⟩
def clientRequest : DataDecl := ⟨"Http.ClientRequest",0,[("Http.ClientRequest",
  [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),
    .bytes,.base .integer])]⟩
def requestCheckError : DataDecl := ⟨"Http.RequestCheckError",0,[
  ("Http.RequestCheckError.InvalidUrl",[.base .string]),
  ("Http.RequestCheckError.Scope",[atErrorType])]⟩
def http : List DataDecl := file ++ [pair,clientRequest,requestCheckError]
def HasHttp (P : Program) : Prop := HasDeclarations P http

/-- HTTP の表は同じ Result と ScopeError を使う。 -/
theorem HasHttp.file {P} (h : HasHttp P) : HasFile P := by
  intro d hd
  exact h d (List.mem_append_left _ hd)

/-- arity だけ合い、欄が違う構成子は受け入れない。 -/
example {P} (h : HasHttp P) :
    P.DataArity "Result" 2 ∧ P.DataArity "Http.ClientRequest" 0 ∧
    P.DataArity "Pair" 2 ∧
    P.cons "Pair.Pair" = some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩ ∧
    P.cons "Http.ClientRequest" = some ⟨"Http.ClientRequest",0,
      [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),
        .bytes,.base .integer]⟩ := by
  have r := h result (by simp [http,file])
  have q := h clientRequest (by simp [http])
  have p := h pair (by simp [http])
  exact ⟨r.1,q.1,p.1,
    p.2 ("Pair.Pair", ⟨"Pair",2,[.tvar 0,.tvar 1]⟩) (by simp [pair,DataDecl.entries]),
    q.2 ("Http.ClientRequest", ⟨"Http.ClientRequest",0,
      [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),
        .bytes,.base .integer]⟩) (by simp [clientRequest,DataDecl.entries])⟩

example {P} (h : HasHttp P) : ¬ P.DataArity "Pair" 0 := by
  intro zero
  have two := (h pair (by simp [http])).1
  have := two.unique zero
  cases this
end Benitoite.Release.Refinement.ScopeDeclarations
