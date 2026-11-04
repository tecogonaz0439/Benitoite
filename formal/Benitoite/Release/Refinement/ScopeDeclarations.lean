import Benitoite.Release.Refinement.StandardKeyTyping
import Benitoite.Release.Refinement.AtContracts
import Benitoite.Release.Refinement.ProgramWellFormed

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
/-- 有限の宣言だけを持つ同じプログラム。 -/
def program : Program where
  defs := fun _ => none
  cons := fun c => (http.flatMap DataDecl.entries).lookup c
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private theorem lookup_mem {α : Type} {xs : List (ConName × α)} {c : ConName} {cd : α}
    (h : xs.lookup c = some cd) : (c,cd) ∈ xs := by
  induction xs with
  | nil => simp at h
  | cons x xs ih =>
    rcases x with ⟨n,t⟩
    simp only [List.lookup] at h
    split at h
    · rename_i he
      have hn : c = n := by simpa only [beq_iff_eq] using he
      subst n; cases h; exact .head _
    · exact .tail _ (ih h)

/-- 同じ lookup は各データ名についてただ一つの arity を持つ。 -/
theorem program_arity {d : DataDecl} (hd : d ∈ http) : program.DataArity d.name d.ntys := by
  simp only [http,file,List.mem_append,List.mem_cons,List.not_mem_nil,or_false] at hd
  rcases hd with (rfl | rfl) | rfl | rfl | rfl
  all_goals constructor
  all_goals first
    | (first
        | exact ⟨"Result.Ok",⟨"Result",2,[.tvar 0]⟩,rfl,rfl⟩
        | exact ⟨"Scope.ScopeError.InvalidPattern",⟨"Scope.ScopeError",0,[.base .string,.base .string]⟩,rfl,rfl⟩
        | exact ⟨"Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩,rfl,rfl⟩
        | exact ⟨"Http.ClientRequest",⟨"Http.ClientRequest",0,
            [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),.bytes,.base .integer]⟩,rfl,rfl⟩
        | exact ⟨"Http.RequestCheckError.InvalidUrl",⟨"Http.RequestCheckError",0,[.base .string]⟩,rfl,rfl⟩)
    | (intro c cd hc he
       have hm := lookup_mem hc
       simp only [http,file,List.flatMap_append,List.flatMap_cons,List.flatMap_nil,
         result,scopeError,pair,clientRequest,requestCheckError,DataDecl.entries,List.map,
         List.mem_append,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq,or_assoc] at hm
       rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
       all_goals simp_all [result,scopeError,pair,clientRequest,requestCheckError])

/-- Result・Pair・要求・両 Error の lookup と全 arity を同じ P から供給する。 -/
theorem program_hasHttp : HasHttp program := by
  intro d hd
  refine ⟨program_arity hd,?_⟩
  simp only [http,file,List.mem_append,List.mem_cons,List.not_mem_nil,or_false] at hd
  rcases hd with (rfl | rfl) | rfl | rfl | rfl
  all_goals intro c hc
  all_goals simp only [result,scopeError,pair,clientRequest,requestCheckError,DataDecl.entries,List.map,
    List.mem_cons,List.not_mem_nil,or_false] at hc
  all_goals rcases hc with rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals rfl

/-- 有限宣言のプログラムは、各構成子の欄の形成も満たす。 -/
theorem program_wellFormed : program.WellFormed := by
  have hr := program_arity (d := result) (by simp [http,file])
  have hs := program_arity (d := scopeError) (by simp [http,file])
  have hp := program_arity (d := pair) (by simp [http])
  have hc := program_arity (d := clientRequest) (by simp [http])
  have he := program_arity (d := requestCheckError) (by simp [http])
  change program.DataArity "Result" 2 at hr
  change program.DataArity "Scope.ScopeError" 0 at hs
  change program.DataArity "Pair" 2 at hp
  change program.DataArity "Http.ClientRequest" 0 at hc
  change program.DataArity "Http.RequestCheckError" 0 at he
  constructor
  · intro f d hd; cases hd
  · intro c cd hlookup
    have hm := lookup_mem hlookup
    simp only [http,file,List.flatMap_append,List.flatMap_cons,List.flatMap_nil,
      result,scopeError,pair,clientRequest,requestCheckError,DataDecl.entries,List.map,
      List.mem_append,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq,or_assoc] at hm
    rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals refine ⟨by first | exact hr | exact hs | exact hp | exact hc | exact he,?_⟩
    all_goals intro a ha
    all_goals simp only [List.mem_cons,List.not_mem_nil,or_false,atErrorFields,List.replicate] at ha
    all_goals rcases ha with rfl | rfl | rfl | rfl | rfl | rfl | rfl
    all_goals simp [Ty.SourceScoped,Ty.WF,Ty.WFList,Ty.RowsIn,Ty.RowsInList,
      Ty.RangesScoped,rangesScopedTypes,atErrorType,Ty.HasKind,kindsList,TyCon.arity_data hp]
    all_goals try apply And.intro
    all_goals first
      | exact TyCon.arity_data hs
      | (constructor <;> simp [Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,Ty.Declared,declaredTys,hp,hs])
  · intro o od hd; cases hd
  · intro cl cd hd; cases hd
  · intro i id hd; cases hd
  · intro d info hi; cases hi
  · exact ⟨by simp [program],by intro k d hd; cases hd⟩

example : HasFile program ∧ HasHttp program ∧ program.WellFormed :=
  ⟨program_hasHttp.file,program_hasHttp,program_wellFormed⟩
end Benitoite.Release.Refinement.ScopeDeclarations
