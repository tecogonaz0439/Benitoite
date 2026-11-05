import Benitoite.Release.Refinement.StandardKeyTyping
import Benitoite.Release.Refinement.AtContracts
import Benitoite.Release.Refinement.ProgramWellFormed
import Benitoite.Release.Refinement.ScopePublicValues

/-! # 範囲付きモデルが読む有限の構成子宣言と全 arity -/
namespace Benitoite.Release.Refinement.ScopeDeclarations
open StandardKeyTyping

/-- 指定した構成子の lookup と、同じデータ名の全構成子の arity を検査する。 -/
def HasDeclarations (P : Program) (ds : List DataDecl) : Prop :=
  ∀ d ∈ ds, P.DataArity d.name d.ntys ∧
    ∀ c ∈ d.entries, P.cons c.1 = some c.2

def result : DataDecl := ⟨"Result",2,
  [("Result.Ok",[.tvar 0]),("Result.Error",[.tvar 1])]⟩

/-- 旧 API の6構成子と、At の詳細を一つの欄で持つ公開の宣言。 -/
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
/-- 標準の Option。At の詳細の任意の欄が読む。 -/
def option : DataDecl := ⟨"Option",1,[("Option.None",[]),("Option.Some",[.tvar 0])]⟩
/-- At の診断の公開の宣言。 -/
def publicDecl (d : ScopePublic.PublicData) : DataDecl :=
  ⟨d.name,0,d.constructors.map fun c => (c.1, c.2.map ScopePublic.PublicTy.ty)⟩
/-- 新しく公開する19の data と record。 -/
def publicDecls : List DataDecl := ScopePublic.declarations.map publicDecl
/-- At の診断の公開の宣言を除く、Result・ScopeError・Pair・要求・要求の誤りの宣言。 -/
def base : List DataDecl := file ++ [pair,clientRequest,requestCheckError]
def http : List DataDecl := file ++ [pair,clientRequest,requestCheckError] ++ (option :: publicDecls)
def HasHttp (P : Program) : Prop := HasDeclarations P http

theorem http_eq : http = base ++ option :: publicDecls := rfl

theorem mem_http {d : DataDecl} (h : d ∈ http) : d ∈ base ∨ d = option ∨ d ∈ publicDecls := by
  rw [http_eq] at h
  simpa only [List.mem_append, List.mem_cons] using h

/-- 公開の宣言の構成子は型引数を持たず、欄は公開の欄の型である。 -/
theorem public_entry {c : ConName} {cd : ConDecl} (h : (c, cd) ∈ publicDecls.flatMap DataDecl.entries) :
    cd.ntys = 0 ∧ cd.data ∈ ScopePublic.declarations.map ScopePublic.PublicData.name ∧
      ∃ as : List ScopePublic.PublicTy, cd.args = as.map ScopePublic.PublicTy.ty ∧ ∀ a ∈ as, a.Known := by
  obtain ⟨d, hd, he⟩ := List.mem_flatMap.mp h
  obtain ⟨D, hD, rfl⟩ := List.mem_map.mp hd
  obtain ⟨⟨c', args⟩, hm, eq⟩ := List.mem_map.mp he
  simp only [publicDecl, List.mem_map] at hm
  obtain ⟨⟨c'', as⟩, hc, eq'⟩ := hm
  cases eq'; cases eq
  refine ⟨rfl, List.mem_map_of_mem hD, as, rfl, fun a ha => ?_⟩
  exact (ScopePublic.constructor_fields
    (List.mem_flatMap.mpr ⟨D, List.mem_append_left _ hD, List.mem_map.mpr ⟨_, hc, rfl⟩⟩)).2 a ha

theorem public_not_option : ∀ d ∈ ScopePublic.declarations.map ScopePublic.PublicData.name, d ≠ "Option" ∧
    d ≠ "Pair" ∧ d ≠ "Scope.ScopeError" := by decide

theorem scopeError_public : scopeError = publicDecl ScopePublic.scopeErrorDecl := rfl

/-- HTTP の表は、At の診断の公開の宣言の全体と Option を同じ P に持つ。 -/
theorem HasHttp.scopePublic {P} (h : HasHttp P) : P.HasScopePublic := by
  have pub : ∀ d ∈ ScopePublic.all, publicDecl d ∈ http := by
    intro d hd
    simp only [ScopePublic.all, List.mem_append, List.mem_singleton] at hd
    rcases hd with hd | rfl
    · simp [http, publicDecls, List.mem_map_of_mem hd]
    · simp [http, file, ← scopeError_public]
  have opt := h option (by simp [http])
  refine ⟨fun d hd => (h _ (pub d hd)).1, ?_, opt.1, ?_, ?_⟩
  · intro c d as hm
    simp only [ScopePublic.constructors, List.mem_flatMap, List.mem_map] at hm
    obtain ⟨D, hD, ⟨c', as'⟩, hc, eq⟩ := hm
    simp only [Prod.mk.injEq] at eq
    obtain ⟨e1, e2, e3⟩ := eq
    subst e1 e2 e3
    exact (h _ (pub D hD)).2 _ (List.mem_map.mpr ⟨(c', as'.map ScopePublic.PublicTy.ty),
      List.mem_map.mpr ⟨(c', as'), hc, rfl⟩, rfl⟩)
  · exact opt.2 ("Option.Some", _) (by simp [option, DataDecl.entries])
  · exact opt.2 ("Option.None", _) (by simp [option, DataDecl.entries])

/-- HTTP の表は同じ Result と ScopeError を使う。 -/
theorem HasHttp.file {P} (h : HasHttp P) : HasFile P := by
  intro d hd
  exact h d (List.mem_append_left _ (List.mem_append_left _ hd))

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

private theorem lookup_of_mem {α : Type} {xs : List (ConName × α)} (nodup : (xs.map Prod.fst).Nodup)
    {k : ConName} {v : α} (h : (k, v) ∈ xs) : xs.lookup k = some v := by
  induction xs with
  | nil => cases h
  | cons x xs ih =>
    rcases x with ⟨k', v'⟩
    simp only [List.map_cons, List.nodup_cons] at nodup
    simp only [List.lookup]
    rcases List.mem_cons.mp h with eq | mem
    · cases eq; simp
    · have ne : k ≠ k' := by
        intro eq; subst eq
        exact nodup.1 (List.mem_map.mpr ⟨(k, v), mem, rfl⟩)
      have hb : (k == k') = false := by simpa using ne
      rw [hb]
      exact ih nodup.2 mem

private theorem keys_nodup : ((http.flatMap DataDecl.entries).map Prod.fst).Nodup := by decide
private theorem names_nodup : (http.map DataDecl.name).Nodup := by decide
private theorem constructors_nonempty : ∀ d ∈ http, d.constructors.length ≠ 0 := by decide

private theorem entry_owner {c : ConName} {cd : ConDecl} (h : (c, cd) ∈ http.flatMap DataDecl.entries) :
    ∃ d ∈ http, cd.data = d.name ∧ cd.ntys = d.ntys := by
  obtain ⟨d, hd, he⟩ := List.mem_flatMap.mp h
  obtain ⟨_, _, eq⟩ := List.mem_map.mp he
  cases eq
  exact ⟨d, hd, rfl, rfl⟩

private theorem name_injective {d d' : DataDecl} (hd : d ∈ http) (hd' : d' ∈ http)
    (eq : d.name = d'.name) : d = d' := by
  have nodup := names_nodup
  revert hd hd'
  generalize http = xs at nodup
  intro hd hd'
  induction xs with
  | nil => cases hd
  | cons x xs ih =>
    simp only [List.map_cons, List.nodup_cons] at nodup
    rcases List.mem_cons.mp hd with h1 | h1 <;> rcases List.mem_cons.mp hd' with h2 | h2
    · exact h1.trans h2.symm
    · subst h1; exact absurd (List.mem_map.mpr ⟨d', h2, eq.symm⟩) nodup.1
    · subst h2; exact absurd (List.mem_map.mpr ⟨d, h1, eq⟩) nodup.1
    · exact ih nodup.2 h1 h2

/-- 同じ lookup は各データ名についてただ一つの arity を持つ。 -/
theorem program_arity {d : DataDecl} (hd : d ∈ http) : program.DataArity d.name d.ntys := by
  constructor
  · obtain ⟨c, rest, hc⟩ := List.exists_cons_of_ne_nil (List.ne_nil_of_length_pos
      (Nat.pos_of_ne_zero (constructors_nonempty d hd)))
    refine ⟨c.1, ⟨d.name, d.ntys, c.2⟩, lookup_of_mem keys_nodup ?_, rfl⟩
    exact List.mem_flatMap.mpr ⟨d, hd, List.mem_map.mpr ⟨c, by rw [hc]; exact List.mem_cons_self, rfl⟩⟩
  · intro c cd hc owner
    obtain ⟨d', hd', hname, hn⟩ := entry_owner (lookup_mem hc)
    rw [hn, name_injective hd' hd (hname.symm.trans owner)]

/-- Result・Pair・要求・両 Error・Option・At の詳細の公開の宣言の lookup と全 arity を同じ P から供給する。 -/
theorem program_hasHttp : HasHttp program := by
  intro d hd
  refine ⟨program_arity hd, ?_⟩
  intro c hc
  exact lookup_of_mem keys_nodup (List.mem_flatMap.mpr ⟨d, hd, hc⟩)

private theorem public_field {c : ConName} {cd : ConDecl}
    (h : (c, cd) ∈ (option :: publicDecls).flatMap DataDecl.entries) :
    (cd.ntys = 1 ∧ ∀ a ∈ cd.args, a = .tvar 0) ∨
      (cd.ntys = 0 ∧ ∃ as : List ScopePublic.PublicTy, cd.args = as.map ScopePublic.PublicTy.ty ∧
        ∀ a ∈ as, a.Known) := by
  obtain ⟨d, hd, he⟩ := List.mem_flatMap.mp h
  rcases List.mem_cons.mp hd with rfl | hd
  · simp only [option, DataDecl.entries, List.map, List.mem_cons, List.not_mem_nil, or_false,
      Prod.mk.injEq] at he
    rcases he with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;> simp
  · obtain ⟨D, hD, rfl⟩ := List.mem_map.mp hd
    obtain ⟨⟨c', args⟩, hm, eq⟩ := List.mem_map.mp he
    simp only [publicDecl, List.mem_map] at hm
    obtain ⟨⟨c'', as⟩, hc, eq'⟩ := hm
    cases eq'; cases eq
    refine .inr ⟨rfl, as, rfl, fun a ha => ?_⟩
    exact ScopePublic.constructor_fields
      (List.mem_flatMap.mpr ⟨D, List.mem_append_left _ hD, List.mem_map.mpr ⟨_, hc, rfl⟩⟩) |>.2 a ha

/-- 有限宣言のプログラムは、各構成子の欄の形成も満たす。 -/
theorem program_wellFormed : program.WellFormed := by
  have hr := program_arity (d := result) (by simp [http,file])
  have hs := program_arity (d := scopeError) (by simp [http,file])
  have hp := program_arity (d := pair) (by simp [http])
  have hc := program_arity (d := clientRequest) (by simp [http])
  have he := program_arity (d := requestCheckError) (by simp [http])
  have ho := program_arity (d := option) (by simp [http])
  have pub := program_hasHttp.scopePublic
  change program.DataArity "Result" 2 at hr
  change program.DataArity "Scope.ScopeError" 0 at hs
  change program.DataArity "Pair" 2 at hp
  change program.DataArity "Http.ClientRequest" 0 at hc
  change program.DataArity "Http.RequestCheckError" 0 at he
  change program.DataArity "Option" 1 at ho
  constructor
  · intro f d hd; cases hd
  · intro c cd hlookup
    have hm := lookup_mem hlookup
    refine ⟨?_, ?_⟩
    · obtain ⟨d, hd, hname, hn⟩ := entry_owner hm
      rw [hname, hn]; exact program_arity hd
    have split : (c, cd) ∈ (file ++ [pair,clientRequest,requestCheckError]).flatMap DataDecl.entries ∨
        (c, cd) ∈ (option :: publicDecls).flatMap DataDecl.entries := by
      simpa only [http, List.flatMap_append, List.mem_append] using hm
    rcases split with hm | hm
    · simp only [file,List.flatMap_cons,List.flatMap_nil,
        result,scopeError,pair,clientRequest,requestCheckError,DataDecl.entries,List.map,
        List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq,List.cons_append,
        List.nil_append] at hm
      rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
      all_goals intro a ha
      all_goals simp only [List.mem_cons,List.not_mem_nil,or_false,atErrorFields] at ha
      all_goals rcases ha with rfl | rfl | rfl | rfl | rfl
      all_goals first
        | exact ⟨ScopePublic.PublicTy.sourceScoped _ _ _ (.data "Scope.AtDetail"),
            ScopePublic.PublicTy.annotation pub _ _ (a := .data "Scope.AtDetail") (by decide),
            ScopePublic.PublicTy.kind pub _ (.data "Scope.AtDetail") (by decide)⟩
        | skip
      all_goals simp [Ty.SourceScoped,Ty.WF,Ty.WFList,Ty.RowsIn,Ty.RowsInList,
        Ty.RangesScoped,rangesScopedTypes,atErrorType,Ty.HasKind,kindsList,TyCon.arity_data hp]
      all_goals try apply And.intro
      all_goals first
        | exact TyCon.arity_data hs
        | (constructor <;> simp [Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,Ty.Declared,declaredTys,hp,hs])
    · intro a ha
      rcases public_field hm with ⟨hn, hargs⟩ | ⟨hn, as, hargs, hk⟩
      · obtain rfl := hargs a ha
        rw [hn]
        exact ⟨⟨by simp [Ty.WF], by simp [Ty.RowsIn], by simp [Ty.RangesScoped]⟩,
          ⟨by simp [Ty.WF], trivial, trivial⟩, by simp [Ty.HasKind]⟩
      · rw [hargs] at ha
        obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
        rw [hn]
        exact ⟨b.sourceScoped _ _ _, b.annotation pub _ _ (hk b hb), b.kind pub _ (hk b hb)⟩
  · intro o od hd; cases hd
  · intro cl cd hd; cases hd
  · intro i id hd; cases hd
  · intro d info hi; cases hi
  · exact ⟨by simp [program],by intro k d hd; cases hd⟩

example : HasFile program ∧ HasHttp program ∧ program.WellFormed :=
  ⟨program_hasHttp.file,program_hasHttp,program_wellFormed⟩
end Benitoite.Release.Refinement.ScopeDeclarations
