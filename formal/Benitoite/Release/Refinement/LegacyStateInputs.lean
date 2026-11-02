import Benitoite.Release.Refinement.LegacyEmbedding
import Benitoite.Release.Lemmas.PresHelpers

/-! # 旧状態の導出に沿った入力の構造検査（設計書 01-12「旧判断の適格な入力」） -/
namespace Benitoite.Release.Refinement
noncomputable section

def LegacyClosedCompInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (Ψ : Benitoite.Release.StoreTy)
    (Γ : List (Option Benitoite.Release.Ty)) (R : Option Benitoite.Release.Ty)
    (m : Benitoite.Release.Comp) (a : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) : Prop :=
  LegacyOutputInput K P0 B0 B (.comp [] Ψ Benitoite.Release.Qempty [] Γ R m a e []) ∧
    (embedComp m).ClosedAt 0 Γ.length

def LegacyContRegular (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Ψ : Benitoite.Release.StoreTy) (R : Option Benitoite.Release.Ty)
    (e : Benitoite.Release.Eff) (a b : Benitoite.Release.Ty) (out : Benitoite.Release.Eff)
    (Re : Option Benitoite.Release.Ty) : Prop :=
  LegacyNodeContext K P0 [] Ψ [] [] ∧
    LegacyNodeTypes K P0 [] [] 0 (a :: b :: (R.toList ++ Re.toList)) ∧
    LegacyRowsInput K P0 .closed [e,out]

/-- 保存継続の有限な旧導出に沿う入力。場所の値からストアを再帰して読まない。 -/
inductive LegacyContInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (Ψ : Benitoite.Release.StoreTy) :
    ∀ {R e k a b out Re}, Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re → Prop where
  | empty {R e a out hs hw} :
      LegacyContRegular K P0 Ψ R e a a out R → LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Empty (R := R) (ε := e) (a := a) (ε0 := out) hs hw)
  | letFrame {R e n k a c b out e1 Re ht hw hs hk} :
      LegacyContRegular K P0 Ψ R e a b out Re →
      LegacyClosedCompInput K P0 B0 B Ψ [some a] R n c e1 → LegacyContInput K P0 B0 B Ψ hk →
      LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Let (R := R) (ε := e) (n := n) (k := k) (a := a) (c := c) (b := b) (ε0 := out) (ε1 := e1) (Re := Re) ht hw hs hk)
  | mark {R e k a b out Re hk hw} :
      LegacyContRegular K P0 Ψ (some a) e a b out Re → LegacyContInput K P0 B0 B Ψ hk →
      LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Mark (R' := R) (ε := e) (k := k) (a := a) (b := b) (ε0 := out) (Re := Re) hk hw)
  | update {R e l k a b out Re hl hk} :
      LegacyContRegular K P0 Ψ none e a b out Re → LegacyContInput K P0 B0 B Ψ hk →
      LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Update (R := R) (ε := e) (l := l) (k := k) (a := a) (b := b) (ε0 := out) (Re := Re) hl hk)
  | release {R e v o k a b out Re hv hr hs hk} :
      LegacyContRegular K P0 Ψ R e a b out Re →
      LegacyOutputInput K P0 B0 B (.value [] Ψ Benitoite.Release.Qempty [] [] v (.opaqueTop o)) →
      (embedVal v).Ground → LegacyContInput K P0 B0 B Ψ hk →
      LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Release (R := R) (ε := e) (v := v) (o := o) (k := k) (a := a) (b := b) (ε0 := out) (Re := Re) hv hr hs hk)
  | handle {R e ec eb cs k t b out Re hk hc hs ht hw} :
      LegacyContRegular K P0 Ψ R eb t b out Re →
      LegacyOutputInput K P0 B0 B (.clauses [] Ψ.hideBuilders Benitoite.Release.Qempty [] [] R eb cs t ec []) →
      Clause.ClosedList 0 0 (embedClauses cs) → LegacyContInput K P0 B0 B Ψ hk →
      LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Handle (R := R) (ε := e) (εc := ec) (εb := eb) (h := cs) (k := k) (t := t) (b := b) (ε0 := out) (Re := Re) hk hc hs ht hw)
  | handleFail {R e ec rest E cs k t b out Re hk hc hn ht hc' hw} :
      LegacyContRegular K P0 Ψ R (Benitoite.Release.Eff.union (Benitoite.Release.Eff.singleFail E) rest) t b out Re →
      LegacyOutputInput K P0 B0 B (.failure [] Ψ.hideBuilders Benitoite.Release.Qempty [] [] E R cs t ec []) →
      Clause.ClosedList 0 0 (embedClauses cs) → LegacyContInput K P0 B0 B Ψ hk →
      LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Handle_Fail (R := R) (ε := e) (ec := ec) (Rest := rest) (E := E) (h := cs) (k := k) (t := t) (b := b) (ε0 := out) (Re := Re) hk hc hn ht hc' hw)
  | drop {R e i k a b out Re b' t' e' R' hl hs hk} :
      LegacyContRegular K P0 Ψ R e a b out Re → LegacyContInput K P0 B0 B Ψ hk →
      LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Drop (R := R) (ε := e) (κ := i) (k := k) (a := a) (b := b) (ε0 := out) (Re := Re)
        (b' := b') (t' := t') (ε' := e') (R' := R') hl hs hk)
  | guard {R e v arms next m k a b out Re e1 ht hs hp hm hk} :
      LegacyContRegular K P0 Ψ none Benitoite.Release.Eff.empty (.base .boolean) b out Re →
      LegacyClosedCompInput K P0 B0 B Ψ [] R (.match v arms) a e1 →
      LegacyClosedCompInput K P0 B0 B Ψ [] R m a e1 → LegacyContInput K P0 B0 B Ψ hk →
      LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Guard (R := R) (ε := e) (v := v) (arms := arms) (next := next) (body := m) (k := k) (a := a) (b := b) (ε0 := out) (Re := Re) (ε1 := e1) ht hs hp hm hk)
  | sub {R e k a a' b out Re hk hs} :
      LegacyContRegular K P0 Ψ R e a b out Re → LegacyContInput K P0 B0 B Ψ hk →
      LegacyContInput K P0 B0 B Ψ (Benitoite.Release.ContTy.K_Sub (R := R) (ε := e) (k := k) (a := a) (a' := a') (b := b) (ε0 := out) (Re := Re) hk hs)

def LegacyBuilderContentsInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (Ψ : Benitoite.Release.StoreTy) :
    Benitoite.Release.BuilderContents → Prop
  | .string _ => True
  | .bytes bs => ∀ b ∈ bs, b ≤ 255
  | .list a vs => LegacyOutputInput K P0 B0 B (.each [] Ψ Benitoite.Release.Qempty [] [] vs a) ∧
      Val.ClosedList 0 0 (embedVals vs)

def LegacyCellInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (Ψ : Benitoite.Release.StoreTy) (l : Nat) :
    Benitoite.Release.Cell → Prop
  | .builder c => ∃ kind, Ψ l = some (.builder kind) ∧
      Benitoite.Release.BuilderCellOk P0 B0 Ψ kind c ∧
      LegacyBuilderInput K P0 .closed kind ∧ LegacyBuilderContentsInput K P0 B0 B Ψ c
  | .val v => ∃ a, Ψ l = some (.ref a) ∧
      LegacyOutputInput K P0 B0 B (.value [] Ψ Benitoite.Release.Qempty [] [] v a) ∧ (embedVal v).Ground
  | .thunk m => ∃ a, Ψ l = some (.lazy a) ∧
      LegacyClosedCompInput K P0 B0 B Ψ.hideBuilders [] none m a Benitoite.Release.Eff.empty
  | .done v => ∃ a, Ψ l = some (.lazy a) ∧
      LegacyOutputInput K P0 B0 B (.value [] Ψ Benitoite.Release.Qempty [] [] v a) ∧ (embedVal v).Ground
  | .cont k => ∃ b t e r, Ψ l = some (.cont b t e r) ∧ Benitoite.Release.EndsWithHandle k ∧
      ∃ R e1, ∃ (h : Benitoite.Release.ContTy P0 B0 Ψ R e1 k b t e r), LegacyContInput K P0 B0 B Ψ h
  | .used => ∃ b t e r, Ψ l = some (.cont b t e r)

/-- 有限ストアの各セルを一度検査し、場所の参照先へ値を展開しない。 -/
def LegacyStoreInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (Ψ : Benitoite.Release.StoreTy)
    (μ : Benitoite.Release.Store) : Prop :=
  Benitoite.Release.StoreOk P0 B0 Ψ μ ∧ LegacyNodeContext K P0 [] Ψ [] [] ∧
    ∀ l c, μ l = some c → LegacyCellInput K P0 B0 B Ψ l c

/-- 同じ旧状態の証拠と、コード・全中間型・保持値の構造検査。 -/
def LegacyStateInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (Eb : Benitoite.Release.Eff) :
    Benitoite.Release.State → Prop
  | .run m k μ => ∃ Ψ R a b e e1, ∃ (h : Benitoite.Release.ContTy P0 B0 Ψ R e k a b Eb none),
      LegacyStoreInput K P0 B0 B Ψ μ ∧ LegacyClosedCompInput K P0 B0 B Ψ [] R m a e1 ∧
      Benitoite.Release.Eff.Sub e1 e ∧ LegacyContInput K P0 B0 B Ψ h ∧
      Benitoite.Release.Comp.VarsIn 0 (fun _ => True) m ∧ Benitoite.Release.Cont.Closed k ∧ Benitoite.Release.Store.Closed μ
  | .matchRun v arms next k μ => ∃ Ψ R a b e e1, ∃ (h : Benitoite.Release.ContTy P0 B0 Ψ R e k a b Eb none),
      LegacyStoreInput K P0 B0 B Ψ μ ∧ LegacyClosedCompInput K P0 B0 B Ψ [] R (.match v arms) a e1 ∧
      Benitoite.Release.Eff.Sub e1 e ∧ LegacyContInput K P0 B0 B Ψ h ∧
      Benitoite.Release.Comp.VarsIn 0 (fun _ => True) (.match v arms) ∧ Benitoite.Release.Cont.Closed k ∧
      Benitoite.Release.Store.Closed μ ∧ Benitoite.Release.MatchPrefix v arms next
  | .error _ k μ | .exit _ _ k μ => ∃ Ψ R a b e, ∃ (h : Benitoite.Release.ContTy P0 B0 Ψ R e k a b Eb none),
      LegacyStoreInput K P0 B0 B Ψ μ ∧ LegacyContInput K P0 B0 B Ψ h ∧
      Benitoite.Release.Cont.Closed k ∧ Benitoite.Release.Store.Closed μ

theorem LegacyStateInput.old {K P0 B0 B Eb s} (h : LegacyStateInput K P0 B0 B Eb s) :
    Benitoite.Release.StateTyE P0 B0 Eb s := by
  cases s with
  | run m k μ =>
    obtain ⟨Ψ,R,a,b,e,e1,hk,store,code,sub,_,closed,kclosed,μclosed⟩ := h
    exact ⟨Ψ,R,a,b,e,e1,store.1,code.1.old,sub,hk,closed,kclosed,μclosed⟩
  | matchRun v arms next k μ =>
    obtain ⟨Ψ,R,a,b,e,e1,hk,store,code,sub,_,closed,kclosed,μclosed,hprefix⟩ := h
    exact ⟨Ψ,R,a,b,e,e1,store.1,code.1.old,sub,hk,closed,kclosed,μclosed,hprefix⟩
  | error rs k μ =>
    obtain ⟨Ψ,R,a,b,e,hk,store,_,kclosed,μclosed⟩ := h
    exact ⟨Ψ,R,a,b,e,store.1,hk,kclosed,μclosed⟩
  | exit n rs k μ =>
    obtain ⟨Ψ,R,a,b,e,hk,store,_,kclosed,μclosed⟩ := h
    exact ⟨Ψ,R,a,b,e,store.1,hk,kclosed,μclosed⟩


end
end Benitoite.Release.Refinement
