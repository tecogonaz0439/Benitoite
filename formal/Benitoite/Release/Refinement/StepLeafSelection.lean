import Benitoite.Release.Refinement.StoreReplyLeaves

/-! # 実行関数が使う応答と空き場所の選択 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 存在する IO 応答だけを選び、応答のない入力では任意の既定値を返す。 -/
def Builtins.selectOracle (B : Builtins) : Oracle := by
  classical
  exact fun b ts es ws =>
  if h : ∃ out obs, B.ioResponse b ts es ws out obs then
    ⟨Classical.choose h,Classical.choose (Classical.choose_spec h)⟩
  else ⟨.err "NoResponse",[]⟩

def Builtins.selectRelease (B : Builtins) (v : Val) : Option ErrKind := by
  classical
  exact if h : ∃ r, B.releaseResponse v r then Classical.choose h else none

def Store.selectFresh (μ : Store) : Nat := by
  classical
  exact if h : ∃ l, μ l = none then Classical.choose h else 0

theorem Builtins.selectOracle_response {B : Builtins} {b ts es ws}
    (h : ∃ out obs, B.ioResponse b ts es ws out obs) :
    B.ioResponse b ts es ws (B.selectOracle b ts es ws).1 (B.selectOracle b ts es ws).2 := by
  simp only [Builtins.selectOracle,dite_eq_left h]
  exact Classical.choose_spec (Classical.choose_spec h)

theorem Builtins.selectRelease_response {B : Builtins} {v} (h : ∃ r, B.releaseResponse v r) :
    B.releaseResponse v (B.selectRelease v) := by
  simp only [Builtins.selectRelease,dite_eq_left h]
  exact Classical.choose_spec h

theorem StoreOk.selectFresh_empty {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) :
    μ μ.selectFresh = none ∧ Ψ μ.selectFresh = none := by
  obtain ⟨l,hl,_⟩ := h.fresh
  have hex : ∃ l, μ l = none := ⟨l,hl⟩
  have he : μ μ.selectFresh = none := by
    simp only [Store.selectFresh,dite_eq_left hex]
    exact Classical.choose_spec hex
  refine ⟨he,?_⟩
  cases ht : Ψ μ.selectFresh with
  | none => rfl
  | some t => exact False.elim (h.domain _ t ht he)

/-- pure の応答は δ 自身から得る。exit は契約で排除される。 -/
theorem step_pure_selected {P B σ oracle externalOracle rel fresh q b ts es rs ws k μ sg Ψ a e}
    (hB : B.CoreAssumptions P) (hq : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (ha : BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e) :
    ∃ event dest, step P B σ oracle externalOracle rel fresh (.run q k μ) = some (event,dest) ∧
      Step P B σ (.run q k μ) event dest := by
  obtain ⟨out,hd,hn,_,_⟩ := hB.delta_typed Ψ b sg _ _ rs ws a e hs hk ha
  cases out with
  | val v => exact ⟨_,_,step_prim_val hq hs hk hd⟩
  | err r => exact ⟨_,_,step_prim_err hq hs hk hd⟩
  | exit n => exact False.elim (hn n rfl)

/-- 同じ選択関数を全入力で使い、型付き入力での存在から応答との適合を得る。 -/
theorem step_io_selected {P B σ externalOracle rel fresh q b ts es rs ws k μ sg Ψ a e}
    (hB : B.CoreAssumptions P) (hq : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : B.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit)
    (hn : NoHandler k (.prim b))
    (ha : BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e) :
    ∃ event dest, step P B σ B.selectOracle externalOracle rel fresh (.run q k μ) = some (event,dest) ∧
      Step P B σ (.run q k μ) event dest := by
  have hr := Builtins.selectOracle_response (hB.io_exists Ψ b sg _ _ rs ws a e hs hk ha)
  generalize ho : B.selectOracle b (Ty.normTys ts) (es.map Eff.norm) ws = result at hr
  obtain ⟨out,obs⟩ := result
  have hkind := hB.io_kind Ψ b sg _ _ rs ws a e out obs hs ha hr
  cases out with
  | val v =>
    rcases hkind with ⟨hio,_⟩ | ⟨_,hbad⟩
    · exact ⟨_,_,step_io_val hq hs hio hn ho hr⟩
    · exact False.elim (hbad v rfl)
  | err r => exact ⟨_,_,step_io_err hq hs hk hn ho hr⟩
  | exit n =>
    rcases hkind with ⟨_,hbad⟩ | ⟨hexit,_⟩
    · exact False.elim (hbad n rfl)
    · exact ⟨_,_,step_io_exit hq hs hexit hn ho hr⟩

/-- 全資源値に対する既存の量化をそのまま使う。 -/
theorem ContTy.selected_release {P B σ Ψ R e k a b Eb Re v}
    (hB : B.CoreAssumptions P)
    (h : ContTy P B σ Ψ R e (.release v :: k) a b Eb Re) :
    B.releaseResponse v (B.selectRelease v) :=
  Builtins.selectRelease_response (h.release_response_exists hB)

/-- builder の割当ては選択した同じ空き場所で実行される。 -/
theorem step_builder_new_selected {P B σ oracle externalOracle rel q kind body k μ Ψ}
    (h : StoreOk P B σ Ψ μ) (hv : q.view = .builderLet kind body) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (.mk q.capture (body.subst builderValueSubst (builderLocalSubst μ.selectFresh))) k
        (μ.set μ.selectFresh (.builder kind.empty))) ∧
    Step P B σ (.run q k μ) none
      (.run (.mk q.capture (body.subst builderValueSubst (builderLocalSubst μ.selectFresh))) k
        (μ.set μ.selectFresh (.builder kind.empty))) := by
  constructor
  · simp only [step,hv]; rfl
  · exact .E_BuilderNew hv h.selectFresh_empty.1

/-- Lazy の割当ても有限性から同じ選択へ接続する。 -/
theorem step_lazy_selected {P B σ oracle externalOracle rel q body k μ Ψ}
    (h : StoreOk P B σ Ψ μ) (hv : q.view = .lazyC body) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (Closure.pure (.ret (.loc μ.selectFresh))) k
        (μ.set μ.selectFresh (.thunk (.mk q.capture body)))) ∧
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.loc μ.selectFresh))) k
        (μ.set μ.selectFresh (.thunk (.mk q.capture body)))) := by
  constructor
  · simp only [step,hv]; rfl
  · exact .E_Lazy hv h.selectFresh_empty.1

private theorem SplitAt.splitHandler_some {o k k1 cap h k2} (hs : SplitAt o k k1 cap h k2) :
    splitHandler o k = some (k1,cap,h,k2) := by
  obtain ⟨rfl,hh,hn⟩ := hs
  induction k1 with
  | nil => simp [splitHandler,hh]
  | cons f k1 ih =>
    have hk : NoHandler k1 o := fun c cs hc => hn c cs (List.mem_cons_of_mem _ hc)
    have hi := ih hk
    cases f <;> try simp only [List.cons_append,splitHandler,hi,Option.map_some]
    case handleF c cs =>
      simp only [hn c cs List.mem_cons_self,Bool.false_eq_true,ite_false]

/-- Reference.new でも、実行と規則に同じ空き場所を供給する。 -/
theorem step_ref_new_selected {P B σ oracle externalOracle rel q b ts es rs v k μ Ψ sg}
    (h : StoreOk P B σ Ψ μ) (hv : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) [v])
    (hs : B.sig b = some sg) (hk : sg.kind = .refNew) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (Closure.pure (.ret (.loc μ.selectFresh))) k (μ.set μ.selectFresh (.val v))) ∧
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.loc μ.selectFresh))) k (μ.set μ.selectFresh (.val v))) := by
  constructor
  · simp only [step,hv,stepRun,closedRanges_fixed]; change (match B.sig b with | none => none | some s => _) = _
    rw [hs]; simp only [hk]
  · exact .E_RefNew hv hs hk h.selectFresh_empty.1

/-- 利用者の操作の節でも、保存する継続の場所を同じ選択へ結ぶ。 -/
theorem step_op_selected {P B σ oracle externalOracle rel q o ts ws k μ Ψ k1 hcap h k2 c}
    (hμ : StoreOk P B σ Ψ μ) (hv : q.view = .app (.op o ts) ws)
    (hs : SplitAt (.user o) k k1 hcap h k2) (hc : findClause h (.user o) = some c) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h])))) ∧
    Step P B σ (.run q k μ) none
      (.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h])))) := by
  constructor
  · simp only [step,hv]
    change (match splitHandler (.user o) k with
      | some (k1,hcap,h,k2) => match findClause h (.user o) with
        | some c => some ((none : Option Event),State.run (Closure.mk (Capture.extendMany hcap (ws ++ [Val.loc μ.selectFresh]))
            (c.body.substTy ts [])) (.drop μ.selectFresh :: k2)
            (μ.set μ.selectFresh (.cont (k1 ++ [Frame.handleF hcap h]))))
        | none => none
      | none => none) = _
    rw [hs.splitHandler_some]
    simp only [hc]
  · exact .E_Op hv hs hc hμ.selectFresh_empty.1

/-- fail の一節についても同じ空き場所を使う。 -/
theorem step_raise_selected {P B σ oracle externalOracle rel q t e v k μ Ψ k1 hcap err body k2}
    (hμ : StoreOk P B σ Ψ μ) (hv : q.view = .app (.raise t e) [v])
    (hs : SplitAt .fail k k1 hcap [.fail err body] k2) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (.mk (hcap.extendMany [v,.loc μ.selectFresh]) (body.substTy [t] []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap [.fail err body]])))) ∧
    Step P B σ (.run q k μ) none
      (.run (.mk (hcap.extendMany [v,.loc μ.selectFresh]) (body.substTy [t] []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap [.fail err body]])))) := by
  constructor
  · simp only [step,hv]; change (match splitHandler .fail k with | some (k1,cap,[.fail err body],k2) => _ | _ => none) = _
    rw [hs.splitHandler_some]
  · exact .E_OpFail hv hs hμ.selectFresh_empty.1

/-- IO・exit の節がある場合にも、同じ保存継続を選ぶ。 -/
theorem step_prim_handler_selected {P B σ oracle externalOracle rel q b ts es rs ws k μ Ψ sg k1 hcap h k2 c}
    (hμ : StoreOk P B σ Ψ μ) (hv : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : B.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit)
    (hh : SplitAt (.prim b) k k1 hcap h k2) (hc : findClause h (.prim b) = some c) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) =
      some (none,.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h])))) ∧
    Step P B σ (.run q k μ) none
      (.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
        (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h])))) := by
  constructor
  · simp only [step,hv,stepRun,closedRanges_fixed]; change (match B.sig b with | none => none | some s => _) = _
    rw [hs]
    rcases hk with hk | hk <;> simp only [hk]
    all_goals rw [hh.splitHandler_some]; simp only [hc]
  · exact .E_OpPrim hv hs hk hh hc hμ.selectFresh_empty.1

/-- fresh を使う残り四枝の入力。行先の型付けは含めない。 -/
inductive FreshStepInputs (B : Builtins) (q : Closure) (k : Cont) (μ : Store) : State → Prop where
  | reference {b ts es rs v sg} : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) [v] →
      B.sig b = some sg → sg.kind = .refNew →
      FreshStepInputs B q k μ (.run (Closure.pure (.ret (.loc μ.selectFresh))) k (μ.set μ.selectFresh (.val v)))
  | operation {o ts ws k1 hcap h k2 c} : q.view = .app (.op o ts) ws →
      SplitAt (.user o) k k1 hcap h k2 → findClause h (.user o) = some c →
      FreshStepInputs B q k μ
        (.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
          (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h]))))
  | failure {t e v k1 hcap err body k2} : q.view = .app (.raise t e) [v] →
      SplitAt .fail k k1 hcap [.fail err body] k2 →
      FreshStepInputs B q k μ
        (.run (.mk (hcap.extendMany [v,.loc μ.selectFresh]) (body.substTy [t] []))
          (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap [.fail err body]]))))
  | primitive {b ts es rs ws sg k1 hcap h k2 c} : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws →
      B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
      SplitAt (.prim b) k k1 hcap h k2 → findClause h (.prim b) = some c →
      FreshStepInputs B q k μ
        (.run (.mk (hcap.extendMany (ws ++ [.loc μ.selectFresh])) (c.body.substTy ts []))
          (.drop μ.selectFresh :: k2) (μ.set μ.selectFresh (.cont (k1 ++ [.handleF hcap h]))))

/-- 四枝の葉を、実行関数の同じ選択と同じ行先で読む。 -/
theorem step_fresh_selected {P B σ oracle externalOracle rel q k μ Ψ dest}
    (hμ : StoreOk P B σ Ψ μ) (input : FreshStepInputs B q k μ dest) :
    step P B σ oracle externalOracle rel Store.selectFresh (.run q k μ) = some (none,dest) ∧
      Step P B σ (.run q k μ) none dest := by
  cases input with
  | reference hv hs hk => exact step_ref_new_selected hμ hv hs hk
  | operation hv hs hc => exact step_op_selected hμ hv hs hc
  | failure hv hs => exact step_raise_selected hμ hv hs
  | primitive hv hs hk hh hc => exact step_prim_handler_selected hμ hv hs hk hh hc

/-- 選んだ解放応答を、ret と escape の実際の枠の step に結ぶ。 -/
theorem step_release_selected {P B σ oracle externalOracle fresh q k μ w v} {escape : Bool}
    (hv : q.view = if escape then .escape w else .ret w)
    (hr : ∃ result, B.releaseResponse v result) :
    let dest := match B.selectRelease v with
      | none => .run (Closure.pure (if escape then .escape w else .ret w)) k μ
      | some r => .error [r] k μ
    step P B σ oracle externalOracle B.selectRelease fresh (.run q (.release v :: k) μ) =
      some (some (.release v (B.selectRelease v)),dest) ∧
    Step P B σ (.run q (.release v :: k) μ) (some (.release v (B.selectRelease v))) dest := by
  have hrel := Builtins.selectRelease_response hr
  cases escape <;> simp only [Bool.false_eq_true,ite_false,ite_true] at hv ⊢
  all_goals cases he : B.selectRelease v <;> simp only [he] at hrel ⊢
  all_goals constructor
  all_goals first
    | (simp only [step,hv]
       change releaseStep B.selectRelease v _ _ = _
       simp only [releaseStep,he])
    | exact .E_Release hv hrel
    | exact .E_RelErr hv hrel
    | exact .E_EscRel hv hrel
    | exact .E_EscRelErr hv hrel

/-- 元の捕捉と導出から型付き入力を得て、実行関数の選択を接続する。 -/
theorem StateTyE.selected_primitive_step {P B σ Eb externalOracle rel fresh q b ts es rs ws k μ sg}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hs : B.sig b = some sg) (hk : sg.kind = .pure ∨ sg.kind = .io ∨ sg.kind = .exit)
    (hn : NoHandler k (.prim b)) :
    ∃ event dest, step P B σ B.selectOracle
      externalOracle rel fresh (.run q k μ) = some (event,dest) ∧ Step P B σ (.run q k μ) event dest := by
  obtain ⟨Ψ,R,a,c,e,e1,hsμ,hq,_,_,_,hcl,_,_⟩ := h
  have ht := hq.app_view_typed hP hPB hB hsμ.wf hsμ.sorted hsμ.declared hv
  have hg : ∀ w∈ws,w.Ground := fun w hw => hq.view_read_ground hcl
    (by rw [hv]; exact List.mem_cons_of_mem _ hw)
  obtain ⟨r,ef,hargs,_,_⟩ := ht.primitive_call hg rfl hs
  rcases hk with hpure | hio
  · exact step_pure_selected (oracle := B.selectOracle) hB hv hs hpure hargs
  · exact step_io_selected hB hv hs hio hn hargs

/-- 選んだ解放結果は関係の応答であり、実行関数もその同じ結果を使う。 -/
theorem ContTy.selected_release_step {P B σ Ψ R e k a b Eb Re v ok err}
    (hB : B.CoreAssumptions P)
    (h : ContTy P B σ Ψ R e (.release v :: k) a b Eb Re) :
    releaseStep B.selectRelease v ok err =
      some (some (.release v (B.selectRelease v)), match B.selectRelease v with | none => ok | some r => err r) ∧
      B.releaseResponse v (B.selectRelease v) := by
  constructor
  · cases hrel : B.selectRelease v <;> simp [releaseStep,hrel]
  · exact h.selected_release hB

end
end Benitoite.Release.Refinement
