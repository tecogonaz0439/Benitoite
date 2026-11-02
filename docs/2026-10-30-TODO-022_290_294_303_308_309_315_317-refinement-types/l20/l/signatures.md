# L20 群 L・M の完全署名

基準 B_WORK は `2f2a27900721ad93b0189930359fc48f8c887db0`、ブランチは依頼の `m014/l20.l` である。各まとまりの完全署名を実装前に記録し、以下は最終ソースの署名と定義にそろえた一覧である。相互定理は全成分、補助の帰納的な条件は全構成子を含める。元の型・行・戻り先・捕捉の証人、応答の条件を省略しない。型を周囲の判断から推論する暗黙変数はソースと同じ書式である。

型付けの規則・CaptureOk・ClosureTy・StateTyE・ValueMeaning・CoreAssumptions と主な10言明は変更しない。採用する専用参照の条件は ReadLocalRefs/LocalInvariant の導出に対応する条件である。全捕捉位置の SlotBuilderLive と δ の構文の読取りの例は対照として残す。StoreReplyInputs は同名の Step のソース入力を束ね、行先の型付けを前提にしない。ReferencePreservation の内部の update_body は一般の関数値と生の型引数で使うため reference_update_body として公開する。

署名・定義の完全な一覧は本文、宣言の生の集計は <tmp> に置く。declarations.json には件数とその大きさ・SHA-256 を残す。公理の監査の対象は audit-modules.txt と audit-declarations.txt に保存する。既存の一般の Lazy 作成・error/exit の更新枠の pop、handler の used と error/exit の解放付き drop、ContTy.store 等は引用し、再定義しない。

## HandlerGeneral

```lean
private theorem drop_tail_all {P B σ Ψ R e k a b Eb Re l}
    (h : ContTy P B σ Ψ R e (.drop l :: k) a b Eb Re) :
    ∃ x t ec r, Ψ l = some (.cont x t ec r) ∧
      (ec.mem (.name stateEff (.fixed .top)) → e.mem (.name stateEff (.fixed .top))) ∧
      ContTy P B σ Ψ R e k a b Eb Re

private theorem return_destination {P B σ Ψ R q a e k b Eb v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .ret v)
    {ε : Eff} (hk : ContTy P B σ Ψ R ε k a b Eb none) :
    ∃ R', ClosureTy P B Ψ [] R' (Closure.pure (.ret v)) a Eff.empty ∧
      ContTy P B σ Ψ R' ε k a b Eb none

private theorem close_escape_all {P B Ψ Q C Γ Φ Rs m a e L cap R v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hr : cap.closeR Rs = R)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .escape v) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.escape (closeVal cap v))
      (cap.closeTy a) (cap.closeEff e) []

private theorem escape_destination {P B Ψ R q a e v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .escape v)
    (hret : ∀ r, R = some r → Ty.Annotation P [] [] r) :
    ClosureTy P B Ψ [] R (Closure.pure (.escape v)) a e

theorem StateTyE.drop_used_all {P B σ Eb q v l k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .ret v) (hl : μ l = some .used) :
    Step P B σ (.run q (.drop l :: k) μ) none (.run (Closure.pure (.ret v)) k μ) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.drop_release_all {P B σ Eb q v l k μ saved}
    (hdecl : P.EffectsOk B)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .ret v) (hl : μ l = some (.cont saved)) :
    Step P B σ (.run q (.drop l :: k) μ) none
      (.run (Closure.pure (.ret v)) (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) (releases saved ++ k) (μ.set l .used))

theorem StateTyE.escape_drop_used {P B σ Eb q v l k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .escape v) (hl : μ l = some .used) :
    Step P B σ (.run q (.drop l :: k) μ) none (.run (Closure.pure (.escape v)) k μ) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.escape v)) k μ)

theorem StateTyE.escape_drop_release {P B σ Eb q v l k μ saved}
    (hdecl : P.EffectsOk B)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .escape v) (hl : μ l = some (.cont saved)) :
    Step P B σ (.run q (.drop l :: k) μ) none
      (.run (Closure.pure (.escape v)) (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.escape v)) (releases saved ++ k) (μ.set l .used))

private theorem release_tail_all {P B σ Ψ R e k a b Eb Re v}
    (h : ContTy P B σ Ψ R e (.release v :: k) a b Eb Re) :
    (∃ o, HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) ∧
      B.isResource o = true) ∧ ContTy P B σ Ψ R e k a b Eb Re

theorem StateTyE.error_drop {P B σ Eb rs l k μ}
    (h : StateTyE P B σ Eb (.error rs ((.drop l) :: k) μ))
    (hl : μ l = some .used) :
    Step P B σ (.error rs ((.drop l) :: k) μ) none (.error rs k μ) ∧
      StateTyE P B σ Eb (.error rs k μ)

theorem StateTyE.exit_drop {P B σ Eb n rs l k μ}
    (h : StateTyE P B σ Eb (.exit n rs ((.drop l) :: k) μ))
    (hl : μ l = some .used) :
    Step P B σ (.exit n rs ((.drop l) :: k) μ) none (.exit n rs k μ) ∧
      StateTyE P B σ Eb (.exit n rs k μ)

theorem StateTyE.error_handler {P B σ Eb rs cap cs k μ}
    (h : StateTyE P B σ Eb (.error rs ((.handleF cap cs) :: k) μ)) :
    Step P B σ (.error rs ((.handleF cap cs) :: k) μ) none (.error rs k μ) ∧
      StateTyE P B σ Eb (.error rs k μ)

theorem StateTyE.exit_handler {P B σ Eb n rs cap cs k μ}
    (h : StateTyE P B σ Eb (.exit n rs ((.handleF cap cs) :: k) μ)) :
    Step P B σ (.exit n rs ((.handleF cap cs) :: k) μ) none (.exit n rs k μ) ∧
      StateTyE P B σ Eb (.exit n rs k μ)

theorem StateTyE.error_release {P B σ Eb rs v k μ}
    (h : StateTyE P B σ Eb (.error rs ((.release v) :: k) μ))
    (hr : B.releaseResponse v none) :
    Step P B σ (.error rs ((.release v) :: k) μ) (some (.release v none)) (.error rs k μ) ∧
      StateTyE P B σ Eb (.error rs k μ)

theorem StateTyE.error_release_failure {P B σ Eb rs v r k μ}
    (h : StateTyE P B σ Eb (.error rs ((.release v) :: k) μ))
    (hr : B.releaseResponse v (some r)) :
    Step P B σ (.error rs ((.release v) :: k) μ) (some (.release v (some r))) (.error (rs ++ [r]) k μ) ∧
      StateTyE P B σ Eb (.error (rs ++ [r]) k μ)

theorem StateTyE.exit_release {P B σ Eb n rs v k μ}
    (h : StateTyE P B σ Eb (.exit n rs ((.release v) :: k) μ))
    (hr : B.releaseResponse v none) :
    Step P B σ (.exit n rs ((.release v) :: k) μ) (some (.release v none)) (.exit n rs k μ) ∧
      StateTyE P B σ Eb (.exit n rs k μ)

theorem StateTyE.exit_release_failure {P B σ Eb n rs v r k μ}
    (h : StateTyE P B σ Eb (.exit n rs ((.release v) :: k) μ))
    (hr : B.releaseResponse v (some r)) :
    Step P B σ (.exit n rs ((.release v) :: k) μ) (some (.release v (some r))) (.exit n (rs ++ [r]) k μ) ∧
      StateTyE P B σ Eb (.exit n (rs ++ [r]) k μ)

theorem StateTyE.return_release {P B σ Eb q w v k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = .ret w) (hr : B.releaseResponse v none) :
    Step P B σ (.run q (.release v :: k) μ) (some (.release v none))
      (.run (Closure.pure (.ret w)) k μ) ∧ StateTyE P B σ Eb (.run (Closure.pure (.ret w)) k μ)

theorem StateTyE.return_release_failure {P B σ Eb q w v k μ r}
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = .ret w) (hr : B.releaseResponse v (some r)) :
    Step P B σ (.run q (.release v :: k) μ) (some (.release v (some r)))
      (.error [r] k μ) ∧ StateTyE P B σ Eb (.error [r] k μ)

theorem StateTyE.escape_release {P B σ Eb q w v k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = .escape w) (hr : B.releaseResponse v none) :
    Step P B σ (.run q (.release v :: k) μ) (some (.release v none))
      (.run (Closure.pure (.escape w)) k μ) ∧ StateTyE P B σ Eb (.run (Closure.pure (.escape w)) k μ)

theorem StateTyE.escape_release_failure {P B σ Eb q w v k μ r}
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = .escape w) (hr : B.releaseResponse v (some r)) :
    Step P B σ (.run q (.release v :: k) μ) (some (.release v (some r)))
      (.error [r] k μ) ∧ StateTyE P B σ Eb (.error [r] k μ)

theorem ContTy.release_response_exists {P B σ Ψ R e k a b Eb Re v}
    (hB : B.CoreAssumptions P)
    (h : ContTy P B σ Ψ R e (.release v :: k) a b Eb Re) :
    ∃ r, B.releaseResponse v r

private theorem use_inputs_all {P B Ψ Q C Γ Φ R code a e L v m}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hh : code = .use v m) :
    (∃ o, HasTypeVQ P B Ψ Q C Γ Φ v (.opaque o (.fixed .top)) ∧ B.isResource o = true) ∧
      HasTypeCQ P B Ψ Q C Γ Φ R m a e L ∧ e.mem (.name stateEff (.fixed .top))

theorem StateTyE.use_all {P B σ Eb q v m k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .use v m) :
    Step P B σ (.run q k μ) none (.run (.mk q.capture m) (.release v :: k) μ) ∧
      StateTyE P B σ Eb (.run (.mk q.capture m) (.release v :: k) μ)
```

## ClosureTyping

```lean
theorem HasTypeCQ.builderBody_image {P B Ψ Q C Γ Φ} {R : Option Ty} {body : Comp} {a : Ty} {e : Eff} {L k}
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF)
    (hb : HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) body
      (a.shiftV 1 0) (e.shiftV 1 0) (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) L)) :
    HasTypeCQ P B Ψ Q C Γ Φ ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst))
      (body.subst builderValueSubst LocalRef.bound)
      (substTyValues builderValueSubst (a.shiftV 1 0)) (substEffValues builderValueSubst (e.shiftV 1 0))
      (some (substKind builderValueSubst (renameKind (shiftIndex 1 0) k)) :: imageLocal L)
```

## StoreGeneral

```lean
private theorem finite_set_all {μ : Store} (h : ∃ n, ∀ l, n ≤ l → μ l = none)
    (l : Nat) (c : Cell) : ∃ n, ∀ i, n ≤ i → (μ.set l c) i = none

theorem StoreOk.write_cell {P B σ Ψ μ l c}
    (h : StoreOk P B σ Ψ μ) (hc : CellOk P B σ Ψ l c) :
    StoreOk P B σ Ψ (μ.set l c)

theorem StoreOk.allocate_cell {P B σ Ψ μ l x c}
    (h : StoreOk P B σ Ψ μ) (hB : B.ValueAssumptions P) (hl : μ l = none)
    (hw : x.WF) (hs : x.Sorted) (hd : x.Declared P)
    (hc : CellOk P B σ (Ψ.put l x) l c) :
    StoreOk P B σ (Ψ.put l x) (μ.set l c)

theorem StoreOk.fresh {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) :
    ∃ l, μ l = none ∧ Ψ l = none

theorem Store.Closed.set_cell {μ : Store} {l c} (h : μ.Closed) (hc : c.Closed) :
    (μ.set l c).Closed
```

## RuntimeBuilderScope

```lean
private theorem builder_env_wf (nt nv c : Nat) (hc : c ≤ nv) :
    (valEnv (upSubst c builderValueSubst)).WFImages 0 nt (nv+1) 0 nt nv

private theorem builder_type_wf {nt nv c a} (hc : c ≤ nv) (h : a.WF 0 nt (nv+1)) :
    (substTyValues (upSubst c builderValueSubst) a).WF 0 nt nv

private theorem builder_types_wf {nt nv c : Nat} {as : List Ty} (hc : c ≤ nv)
    (h : ∀ a ∈ as, a.WF 0 nt (nv+1)) :
    ∀ a ∈ as.map (substTyValues (upSubst c builderValueSubst)), a.WF 0 nt nv

private theorem builder_rows_wf {nt nv c : Nat} {es : List Eff} (hc : c ≤ nv)
    (h : ∀ e ∈ es, Eff.WF 0 nt (nv+1) e ∧ e.Canonical) :
    ∀ e ∈ es.map (substEffValues (upSubst c builderValueSubst)), Eff.WF 0 nt nv e ∧ e.Canonical

private theorem builder_var_scope {nt nv c i} {σ : PathEnv} (hc : c ≤ nv) (hi : i < nv+1) :
    ((upSubst c builderValueSubst) i).ClosedAt nt nv ∧ ((upSubst c builderValueSubst) i).Adequate σ

private theorem builder_local_scope {nv c l} (hc : c ≤ nv) {ref : LocalRef}
    (h : match ref with | .bound i => i < nv+1 | .loc _ => True) :
    (match ref.subst (upLocalSubst c (builderLocalSubst l)) with | .bound i => i < nv | .loc _ => True)

theorem Val.ClosedAt.builder_subst_scope {nt nv c l : Nat} {v : Val}
      (h : v.ClosedAt nt (nv+1)) {σ : PathEnv} (had : v.Adequate σ)
      (hc : c ≤ nv) :
      (v.subst (upSubst c builderValueSubst) (upLocalSubst c (builderLocalSubst l))).ClosedAt nt nv ∧ (v.subst (upSubst c builderValueSubst) (upLocalSubst c (builderLocalSubst l))).Adequate σ

theorem builder_values_scope {nt nv c l : Nat} {vs : List Val}
      (h : Val.ClosedList nt (nv+1) vs) {σ : PathEnv} (had : adequateVals σ vs)
      (hc : c ≤ nv) :
      Val.ClosedList nt nv (Val.substList (upSubst c builderValueSubst) vs (upLocalSubst c (builderLocalSubst l))) ∧ adequateVals σ (Val.substList (upSubst c builderValueSubst) vs (upLocalSubst c (builderLocalSubst l)))

theorem Comp.ClosedAt.builder_subst_scope {nt nv c l : Nat} {m : Comp}
      (h : m.ClosedAt nt (nv+1)) {σ : PathEnv} (had : m.Adequate σ)
      (hc : c ≤ nv) :
      (m.subst (upSubst c builderValueSubst) (upLocalSubst c (builderLocalSubst l))).ClosedAt nt nv ∧ (m.subst (upSubst c builderValueSubst) (upLocalSubst c (builderLocalSubst l))).Adequate σ

theorem builder_arms_scope {nt nv c l : Nat} {arms : List Arm}
      (h : Arm.ClosedList nt (nv+1) arms) {σ : PathEnv} (had : adequateArms σ arms)
      (hc : c ≤ nv) :
      Arm.ClosedList nt nv (Arm.substList (upSubst c builderValueSubst) arms (upLocalSubst c (builderLocalSubst l))) ∧ adequateArms σ (Arm.substList (upSubst c builderValueSubst) arms (upLocalSubst c (builderLocalSubst l)))

theorem builder_clauses_scope {nt nv c l : Nat} {cs : List Clause}
      (h : Clause.ClosedList nt (nv+1) cs) {σ : PathEnv} (had : adequateClauses σ cs)
      (hc : c ≤ nv) :
      Clause.ClosedList nt nv (Clause.substList (upSubst c builderValueSubst) cs (upLocalSubst c (builderLocalSubst l))) ∧ adequateClauses σ (Clause.substList (upSubst c builderValueSubst) cs (upLocalSubst c (builderLocalSubst l)))
```

## BuilderStateLeaves

```lean
private theorem builder_new_inputs {P B Ψ Q C Γ Φ R code a e L kind body}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hh : code = .builderLet kind body) :
    ∃ t et, Ty.Annotation P C Γ kind.contents ∧
      TypeArgsKinded P C [kind.contents] [.value] ∧
      HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
        body (t.shiftV 1 0) (et.shiftV 1 0)
        (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) L) ∧
      t.Declared P C Γ ∧ Ty.LeQ P Γ Φ t a ∧ Eff.Covers Γ Φ e et

private theorem builder_empty_cell {P B σ} {Ψ : StoreTy} {l : Nat} {kind : BuilderKind}
    (ha : Ty.Annotation P [] [] kind.contents) :
    CellOk P B σ (Ψ.put l (.builder kind)) l (.builder kind.empty)

private theorem builder_location_annotation {P} {kind : BuilderKind}
    (ha : Ty.Annotation P [] [] kind.contents) :
    (LocTy.builder kind).WF ∧ (LocTy.builder kind).Sorted ∧ (LocTy.builder kind).Declared P

private theorem close_kind_contents (cap : Capture) (kind : BuilderKind) :
    (substKind cap.env kind).contents = cap.closeTy kind.contents

private theorem builder_close_return (cap : Capture) (R : Option Ty) :
    cap.closeR ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst)) = cap.closeR R

private theorem builder_image_declared {P C Γ R}
    (hr : ∀ r, R = some r → r.Declared P C Γ) :
    ∀ r, ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst)) = some r → r.Declared P C Γ

private theorem inner_done_all {P a t e f}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e))) (ht : Ty.Annotation P [] [] t)
    (hc : Eff.Covers [] [] e f) (hn : f.Canonical) :
    Ty.Annotation P [] [] (.dependentFn (.done t f))

theorem StateTyE.builder_new {P B σ Eb q kind body k μ l}
    (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderLet kind body) (hl : μ l = none) :
    Step P B σ (.run q k μ) none
      (.run (.mk q.capture (body.subst builderValueSubst (builderLocalSubst l))) k (μ.set l (.builder kind.empty))) ∧
    StateTyE P B σ Eb
      (.run (.mk q.capture (body.subst builderValueSubst (builderLocalSubst l))) k (μ.set l (.builder kind.empty)))

private theorem close_builder_operation {P B Ψ Q C Γ Φ Rs m a e L cap R kind op ref args ρ}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hl : CaptureLocals Ψ cap.env L ρ)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .builderOp kind op ref args) :
    HasTypeCQ P B Ψ Qempty [] [] [] R
      (.builderOp (substKind cap.env kind) op (ref.subst ρ) (closeVals cap args))
      (cap.closeTy a) (cap.closeEff e) []

private theorem builder_arguments_resolve {P B Ψ Q C Γ Φ Rs m a e L kind op ref args}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L) (hm : m = .builderOp kind op ref args) (ρ) :
    Val.resolveLocalsList ρ args = args

private theorem builder_view_operation {P B Ψ R q a e kind op ref args}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .builderOp kind op ref args) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.builderOp kind op ref args) a e []

private theorem builder_operation_inputs {P B Ψ Q C Γ Φ R code a e L kind op ref args}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hh : code = .builderOp kind op ref args) :
    Ty.Annotation P C Γ kind.contents ∧ LocalRef.HasKind Ψ L ref kind ∧
      HasTypeVsQ P B Ψ Q C Γ Φ args (op.parameters kind) ∧ Ty.LeQ P Γ Φ (op.resultType kind) a

private theorem builder_local_inv {Ψ L kind ref l}
    (h : LocalRef.HasKind Ψ L ref kind) (hh : ref = .loc l) :
    ∃ k, Ψ l = some (.builder k) ∧ k.norm = kind.norm

private theorem builder_cell_annotation {P B Ψ kind c}
    (h : BuilderCellOk P B Ψ kind c) : Ty.Annotation P [] [] kind.contents

private theorem builder_cell_convert {P B Ψ source target c}
    (h : BuilderCellOk P B Ψ source c) (ha : Ty.Annotation P [] [] target.contents)
    (he : source.norm = target.norm) : BuilderCellOk P B Ψ target c

private theorem builder_closed_values {vs : List Val} (h : ∀ v ∈ vs, v.Ground) :
    Val.ClosedList 0 0 vs

theorem StateTyE.builder_operation {P B σ Eb q kind op l args k μ c c' v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderOp kind op (.loc l) args)
    (hl : μ l = some (.builder c)) (hr : builderApply op c args = some (.value c' v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k (μ.set l (.builder c'))) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k (μ.set l (.builder c')))

theorem StateTyE.builder_error {P B σ Eb q kind op l args k μ c r}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderOp kind op (.loc l) args)
    (hl : μ l = some (.builder c)) (hr : builderApply op c args = some (.error r)) :
    Step P B σ (.run q k μ) none (.error [r] k μ) ∧ StateTyE P B σ Eb (.error [r] k μ)
```

## BuilderValueTyping

```lean
private theorem each_append_all {P B Ψ Q C Γ Φ a vs ws}
    (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (k : HasTypeEachQ P B Ψ Q C Γ Φ ws a) :
    HasTypeEachQ P B Ψ Q C Γ Φ (vs++ws) a

private theorem builder_list_elements {P B Ψ a vs}
    (hv : HasTypeV P B Ψ [] [] [] (.list vs) (.list a)) (ha : Ty.Annotation P [] [] a) :
    HasTypeEach P B Ψ [] [] [] vs a

private theorem builder_snapshot {P B Ψ kind c} (h : BuilderCellOk P B Ψ kind c) :
    HasTypeV P B Ψ [] [] [] c.snapshot kind.contents

private def BuilderPayload (P : Program) (B : Builtins) (Ψ : StoreTy) : BuilderKind → BuilderContents → Prop
  | .string,.string _ | .bytes,.bytes _ => True
  | .list a,.list vs => Ty.Annotation P [] [] a ∧ HasTypeEach P B Ψ [] [] [] vs a
  | _,_ => False

private theorem builder_checked_value {P B Ψ kind c c' v}
    (ht : BuilderPayload P B Ψ kind c) (hr : builderCheckUpdate c = .value c' v) :
    BuilderCellOk P B Ψ kind c' ∧ HasTypeV P B Ψ [] [] [] v (.base .unit)

theorem builderApply_value_typed {P B Ψ kind c op args c' v}
    (hok : BuilderCellOk P B Ψ kind c)
    (hargs : HasTypeVs P B Ψ [] [] [] args (op.parameters kind))
    (hr : builderApply op c args = some (.value c' v)) :
    BuilderCellOk P B Ψ kind c' ∧ HasTypeV P B Ψ [] [] [] v (op.resultType kind)

private theorem builder_closed_append {vs ws : List Val}
    (h : Val.ClosedList 0 0 vs) (k : Val.ClosedList 0 0 ws) : Val.ClosedList 0 0 (vs++ws)

private theorem builder_adequate_append {σ : PathEnv} {vs ws : List Val}
    (h : adequateVals σ vs) (k : adequateVals σ ws) : adequateVals σ (vs++ws)

private theorem builder_snapshot_scope {c : BuilderContents} {σ : PathEnv}
    (h : (Cell.builder c).Closed) (ha : (Cell.builder c).Adequate σ) :
    c.snapshot.Ground ∧ c.snapshot.Adequate σ

private theorem builder_checked_scope {c c' : BuilderContents} {v : Val} {σ : PathEnv}
    (h : (Cell.builder c).Closed) (ha : (Cell.builder c).Adequate σ)
    (hr : builderCheckUpdate c = .value c' v) :
    (Cell.builder c').Closed ∧ v.Ground ∧ (Cell.builder c').Adequate σ ∧ v.Adequate σ

theorem builderApply_value_scope {op c args c' v σ}
    (hc : (Cell.builder c).Closed) (hac : (Cell.builder c).Adequate σ)
    (ha : Val.ClosedList 0 0 args) (haa : adequateVals σ args)
    (hr : builderApply op c args = some (.value c' v)) :
    (Cell.builder c').Closed ∧ v.Ground ∧ (Cell.builder c').Adequate σ ∧ v.Adequate σ
```

## ContinuationGeneral

```lean
private theorem cont_covered_name {outer inner : Eff} {name ix}
    (hc : Eff.Covers [] [] outer inner) (hm : inner.mem (.name name ix)) :
    ∃ jx, outer.mem (.name name jx) ∧ (Atom.name name jx).Covers (.name name ix)

theorem ContTy.name_end_ix {P B σ Ψ R e k a b Eb Re name ix}
    (h : ContTy P B σ Ψ R e k a b Eb Re) (hm : e.mem (.name name ix))
    (hn : ∀ cap cs jx, Frame.handleF cap cs ∈ k → ¬(handled P B cs).mem (.name name jx)) :
    ∃ jx, Eb.mem (.name name jx) ∧ (Atom.name name jx).Covers (.name name ix)

theorem ContTy.mono_end {P B σ Ψ R e k a b Eb Eb' Re}
    (h : ContTy P B σ Ψ R e k a b Eb Re) (he : Eff.Sub Eb Eb') :
    ContTy P B σ Ψ R e k a b Eb' Re

def FramesOk (P : Program) (B : Builtins) (Ψ : StoreTy) (Eb : Eff) (k : Cont) : Prop :=
  ∀ f ∈ k, match f with
    | .release v => (∃ o, HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) ∧ B.isResource o = true) ∧
        Eb.mem (.name stateEff (.fixed .top))
    | .drop l => ∃ a t e r, Ψ l = some (.cont a t e r) ∧
        (e.mem (.name stateEff (.fixed .top)) → Eb.mem (.name stateEff (.fixed .top)))
    | _ => True

theorem ContTy.framesOk {P B σ Ψ R e k a b Eb Re} (hN : NoStateHandled P B)
    (h : ContTy P B σ Ψ R e k a b Eb Re) : FramesOk P B Ψ Eb k

private theorem releases_kind {k : Cont} {f : Frame} (h : f ∈ releases k) :
    (∃ v, f = .release v) ∨ ∃ l, f = .drop l

private theorem prepend_frames {P B σ Ψ R e k a b Eb Re saved}
    (hk : ContTy P B σ Ψ R e k a b Eb Re) (hf : FramesOk P B Ψ e saved)
    (hr : ∀ f ∈ saved, (∃ v, f = .release v) ∨ ∃ l, f = .drop l)
    (had : saved.Adequate σ) : ContTy P B σ Ψ R e (saved++k) a b Eb Re

theorem ContTy.drop_releases {P B σ Ψ R e k a b Eb Re R0 e0 saved x t ec r}
    (hN : NoStateHandled P B) (hk : ContTy P B σ Ψ R e k a b Eb Re)
    (hs : ContTy P B σ Ψ R0 e0 saved x t ec r)
    (hc : ec.mem (.name stateEff (.fixed .top)) → e.mem (.name stateEff (.fixed .top))) :
    ContTy P B σ Ψ R e (releases saved++k) a b Eb Re
```

## HandlerStoreExamples

```lean
private def declaration : OpDecl := ⟨"Example.effect",[{}],["value"],[.tvar 0],.tvar 0,[]⟩

private def modelProgram : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun o => if o = "Example.identity" then some declaration else none
  effects := fun l => if l = "Example.effect" then some ["Example.identity"] else none
  classes := fun _ => none
  impls := fun _ => none

private def modelGet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference"]
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

private def modelSet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference", "value"]
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

private def modelBuiltins : Builtins where
  sig := fun b => if b = "Reference.get" then some modelGet
    else if b = "Reference.set" then some modelSet else none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => True
  isResource := fun _ => true
  effects := fun l => if l = stateEff then some [] else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"

private theorem model_sig_cases {b s} (h : modelBuiltins.sig b = some s) :
    s = modelGet ∨ s = modelSet

private theorem model_external : modelProgram.ExternalWF

private theorem model_wellFormed : modelProgram.WellFormed where
  defs

private theorem model_wellTyped : modelProgram.WellTyped modelBuiltins where
  variance

private theorem model_core : modelBuiltins.CoreAssumptions modelProgram where
  sat_rename

private def item : Ty := .base .unit

private def result : Ty := .list item

private def value : Val := .list [.const .unit]

private def resource : Val := .const (.opaque "Example.Resource" 0)

private def empty : Eff := Eff.empty

private def state : Eff := Eff.single stateEff

private theorem result_annotation : Ty.Annotation modelProgram [] [] result

private theorem value_typed (Ψ : StoreTy) : HasTypeV modelProgram modelBuiltins Ψ [] [] [] value result

private theorem result_normal : result.Normal

private theorem empty_sub (e : Eff) : Eff.Sub empty e

private theorem sub_refl (e : Eff) : Eff.Sub e e

private theorem saved_typed (σ : PathEnv) :
    ContTy modelProgram modelBuiltins σ StoreTy.empty none empty [.handleF Capture.empty []]
      result result empty none

private def location : LocTy := .cont result result empty none

private def usedStore : Store := Store.empty.set 0 .used

private def saved : Cont := [.handleF Capture.empty []]

private def savedStore : Store := Store.empty.set 0 (.cont saved)

private def storeType : StoreTy := StoreTy.empty.put 0 location

private theorem loc_wf : location.WF

private theorem loc_sorted : location.Sorted

private theorem loc_declared : location.Declared modelProgram

private theorem used_ok (σ : PathEnv) : StoreOk modelProgram modelBuiltins σ storeType usedStore

private theorem saved_ok (σ : PathEnv) : StoreOk modelProgram modelBuiltins σ storeType savedStore

private theorem store_closed : usedStore.Closed ∧ savedStore.Closed

private theorem return_state {σ Ψ μ R e k Eb}
    (hs : StoreOk modelProgram modelBuiltins σ Ψ μ) (hμ : μ.Closed) (hkc : k.Closed)
    (hk : ContTy modelProgram modelBuiltins σ Ψ R e k result result Eb none)
    (hRn : ∀ r, R = some r → r.Normal) :
    StateTyE modelProgram modelBuiltins σ Eb (.run (Closure.pure (.ret value)) k μ)

private theorem escape_state {σ Ψ μ e k Eb}
    (hs : StoreOk modelProgram modelBuiltins σ Ψ μ) (hμ : μ.Closed) (hkc : k.Closed)
    (hk : ContTy modelProgram modelBuiltins σ Ψ (some result) e k result result Eb none) :
    StateTyE modelProgram modelBuiltins σ Eb (.run (Closure.pure (.escape value)) k μ)

private theorem drop_cont (σ : PathEnv) (R : Option Ty) (k : Cont)
    (hk : ContTy modelProgram modelBuiltins σ storeType R empty k result result empty none) :
    ContTy modelProgram modelBuiltins σ storeType R empty (.drop 0::k) result result empty none

private theorem effects_ok : modelProgram.EffectsOk modelBuiltins

theorem drops_concrete (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty (.run (Closure.pure (.ret value)) [] usedStore) ∧
    StateTyE modelProgram modelBuiltins σ empty (.run (Closure.pure (.ret value)) [] (savedStore.set 0 .used)) ∧
    StateTyE modelProgram modelBuiltins σ empty (.run (Closure.pure (.escape value)) [.mark] usedStore) ∧
    StateTyE modelProgram modelBuiltins σ empty (.run (Closure.pure (.escape value)) [.mark] (savedStore.set 0 .used))

private theorem empty_store_closed : Store.empty.Closed

private theorem no_frames_closed : Cont.Closed []

private theorem resource_typed (Ψ : StoreTy) :
    HasTypeV modelProgram modelBuiltins Ψ [] [] [] resource (.opaque "Example.Resource" (.fixed .top))

private theorem state_annotation : Ty.Annotation modelProgram [] [] (.dependentFn (.done result state))

private theorem release_cont (σ : PathEnv) :
    ContTy modelProgram modelBuiltins σ StoreTy.empty none state [.release resource] result result state none

private theorem escape_release_cont (σ : PathEnv) :
    ContTy modelProgram modelBuiltins σ StoreTy.empty (some result) state [.release resource,.mark] result result state none

private theorem release_closed : Cont.Closed [.release resource]

private theorem escape_release_closed : Cont.Closed [.release resource,.mark]

theorem resource_existence_and_effect (σ : PathEnv) :
    (∃ r, modelBuiltins.releaseResponse resource r) ∧
    (∃ ix, state.mem (.name stateEff ix) ∧ (Atom.name stateEff ix).Covers (.name stateEff (.fixed .top)))

theorem resume_used_concrete (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty (.error [rResume] [] usedStore)

private theorem exceptional_state {σ Ψ μ R e k Eb}
    (hs : StoreOk modelProgram modelBuiltins σ Ψ μ) (hμ : μ.Closed) (hc : k.Closed)
    (hk : ContTy modelProgram modelBuiltins σ Ψ R e k result result Eb none) (rs : List ErrKind) (n : Int) :
    StateTyE modelProgram modelBuiltins σ Eb (.error rs k μ) ∧
      StateTyE modelProgram modelBuiltins σ Eb (.exit n rs k μ)

theorem exceptional_drops (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty (.error [rResume] [] usedStore) ∧
    StateTyE modelProgram modelBuiltins σ empty (.exit 7 [rResume] [] usedStore) ∧
    StateTyE modelProgram modelBuiltins σ empty (.error [rResume] [] (savedStore.set 0 .used)) ∧
    StateTyE modelProgram modelBuiltins σ empty (.exit 7 [rResume] [] (savedStore.set 0 .used))

theorem exceptional_pops (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty (.error [rResume] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ empty (.exit 7 [rResume] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.error [rResume] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.error [rResume,rValueTooLarge] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.exit 7 [rResume] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.exit 7 [rResume,rValueTooLarge] [] Store.empty)

theorem release_returns (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ state (.run (Closure.pure (.ret value)) [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.error [rValueTooLarge] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.run (Closure.pure (.escape value)) [.mark] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.error [rValueTooLarge] [.mark] Store.empty)

theorem use_concrete (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ state
      (.run (Closure.pure (.ret value)) [.release resource] Store.empty)

theorem continuation_contracts (σ : PathEnv) :
    ContTy modelProgram modelBuiltins σ StoreTy.empty none empty [] result result state none ∧
    ContTy modelProgram modelBuiltins σ StoreTy.empty none empty (releases saved) result result empty none

private theorem unit_annotation : Ty.Annotation modelProgram [] [] item

private theorem builder_initial (σ : PathEnv) (kind : BuilderKind)
    (hka : Ty.Annotation modelProgram [] [] kind.contents)
    (hkk : TypeArgsKinded modelProgram [] [kind.contents] [.value]) :
    StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.builderLet kind (.ret (.const .unit)))) [] Store.empty)

private theorem builder_allocate_example (σ : PathEnv) (kind : BuilderKind)
    (hka : Ty.Annotation modelProgram [] [] kind.contents)
    (hkk : TypeArgsKinded modelProgram [] [kind.contents] [.value]) :
    ∃ l, StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const .unit))) [] (Store.empty.set l (.builder kind.empty)))

private theorem simple_kind (kind : BuilderKind)
    (h : kind = .string ∨ kind = .bytes ∨ kind = .list item) :
    TypeArgsKinded modelProgram [] [kind.contents] [.value]

theorem builder_allocations (σ : PathEnv) :
    (∃ l, StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const .unit))) [] (Store.empty.set l (.builder (.string ""))))) ∧
    (∃ l, StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const .unit))) [] (Store.empty.set l (.builder (.list []))))) ∧
    (∃ l, StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const .unit))) [] (Store.empty.set l (.builder (.bytes [])))))

theorem string_builder_copy (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const (.string "")))) [] (Store.empty.set 0 (.builder (.string ""))))

private theorem repeated_units (Ψ : StoreTy) (n : Nat) (σ : PathEnv) :
    HasTypeEach modelProgram modelBuiltins Ψ [] [] [] (List.replicate n (.const .unit)) item ∧
    Val.ClosedList 0 0 (List.replicate n (.const .unit)) ∧ adequateVals σ (List.replicate n (.const .unit))

theorem list_builder_overflow (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty
      (.error [rValueTooLarge] [] (Store.empty.set 0 (.builder (.list (List.replicate maxBuilderListLen (.const .unit))))))
```

## HiddenCaptureBoundary

```lean
private def hiddenBody : Closure := .pure (.builderOp .string .copy (.loc 7) [])

private def hiddenValue : Val := .closure (.done (.base .unit) Eff.empty) hiddenBody

private def hiddenCapture : Capture := Capture.empty.extend hiddenValue

private def hiddenState : State := .run (.mk hiddenCapture (.ret (.const .unit))) [] Store.empty

private theorem unitAnnotation {P : Program} : Ty.Annotation P [] [] (.base .unit)

private theorem hiddenGround : hiddenValue.Ground

private def SlotBuilderLive (μ : Store) (cap : Capture) : Prop :=
  ∀ ov ∈ cap.values, ∀ runtime body kind op l args,
    ov = some (.closure runtime body) → body.code = .builderOp kind op (.loc l) args →
      ∃ c, μ l = some (.builder c)

private theorem hidden_state_typed (P : Program) (B : Builtins) (σ : PathEnv) : StateTyE P B σ Eff.empty hiddenState

theorem hidden_slot_counterexample (P : Program) (B : Builtins) (σ : PathEnv) :
    StateTyE P B σ Eff.empty hiddenState ∧ ¬SlotBuilderLive Store.empty hiddenCapture

theorem empty_capture_accepts (P : Program) (B : Builtins) (σ : PathEnv) :
    StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      SlotBuilderLive Store.empty Capture.empty

theorem hidden_slot_read_localrefs (P : Program) (B : Builtins) (σ : PathEnv) :
    LocalStateInvariant P B σ hiddenState ∧ ¬SlotBuilderLive Store.empty hiddenCapture

theorem reject_executed_stale_builder (P : Program) (B : Builtins) (σ : PathEnv) :
    ¬StateTyE P B σ Eff.empty (.run hiddenBody [] Store.empty)
```

## CaptureReadBoundary

```lean
private def modelProgram : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private def modelGet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference"]
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

private def modelSet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference", "value"]
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

private def inspectSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["function"]
  params := [.fn [] [] (.base .unit) Eff.empty]
  ret := .base .unit
  eff := Eff.empty
  admits := fun _ ts => ts.length = 0
  kind := .pure
  opEff := none

private def hiddenTag : List Val → ErrKind
  | [Val.closure _ (Closure.mk cap _)] => match cap.values[0]? with
    | some (some (Val.closure _ (Closure.mk _ (Comp.builderOp _ _ (LocalRef.loc l) _)))) =>
        if l = 7 then "HiddenBuilder7" else "HiddenBuilderOther"
    | _ => "Other"
  | _ => "Other"

private def modelBuiltins : Builtins where
  sig := fun b => if b = "Reference.get" then some modelGet
    else if b = "Reference.set" then some modelSet
    else if b = "Example.inspect" then some inspectSig else none
  delta := fun _ _ _ _ ws => some (.err (hiddenTag ws))
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => True
  isResource := fun _ => true
  effects := fun l => if l = stateEff then some [] else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"

private theorem model_sig_cases {b s} (h : modelBuiltins.sig b = some s) :
    s = modelGet ∨ s = modelSet ∨ s = inspectSig

private theorem model_external : modelProgram.ExternalWF

private theorem model_wellFormed : modelProgram.WellFormed where
  defs

private theorem model_wellTyped : modelProgram.WellTyped modelBuiltins where
  variance

private theorem model_core : modelBuiltins.CoreAssumptions modelProgram where
  sat_rename

private def hiddenValue (l : Nat) : Val := .closure (.done (.base .unit) Eff.empty)
  (.pure (.builderOp .string .copy (.loc l) []))

private def unreadCapture (l : Nat) : Capture := Capture.empty.extend (hiddenValue l)

private def argument (l : Nat) : Val := .closure (.done (.base .unit) Eff.empty)
  (.mk (unreadCapture l) (.ret (.const .unit)))

private def call (l : Nat) : Comp := .app (.prim "Example.inspect" [] [] []) [argument l]

private theorem hidden_ground (l : Nat) : (hiddenValue l).Ground

private theorem unread_capture_ok (l : Nat) : CaptureOk modelProgram modelBuiltins
    StoreTy.empty none [none] [] (unreadCapture l)

private theorem unit_annotation {Γ : Ctx} : Ty.Annotation modelProgram [] Γ (.base .unit)

private theorem argument_typed (l : Nat) : HasTypeV modelProgram modelBuiltins StoreTy.empty
    [] [] [] (argument l) (.fn [] [] (.base .unit) Eff.empty)

private theorem inspect_signature : SignatureInstance modelProgram [] [] (Tel.instR [] inspectSig.tel) [] [] []

private theorem call_typed (l : Nat) : HasTypeC modelProgram modelBuiltins StoreTy.empty
    [] [] [] none (call l) (.base .unit) Eff.empty

private theorem call_closed (l : Nat) : (call l).ClosedAt 0 0

private theorem call_adequate (l : Nat) (σ : PathEnv) : (call l).Adequate σ

private theorem source_typed (l : Nat) (σ : PathEnv) : StateTyE modelProgram modelBuiltins σ Eff.empty
    (.run (Closure.pure (call l)) [] Store.empty)

theorem primitive_reads_hidden_capture (σ : PathEnv) :
    modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
    modelBuiltins.CoreAssumptions modelProgram ∧
    CaptureOk modelProgram modelBuiltins StoreTy.empty none [none] [] (unreadCapture 7) ∧
    CaptureOk modelProgram modelBuiltins StoreTy.empty none [none] [] (unreadCapture 8) ∧
    modelBuiltins.delta "Example.inspect" [] [] [] [argument 7] ≠
      modelBuiltins.delta "Example.inspect" [] [] [] [argument 8] ∧
    StateTyE modelProgram modelBuiltins σ Eff.empty (.run (Closure.pure (call 7)) [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ Eff.empty (.run (Closure.pure (call 8)) [] Store.empty) ∧
    Step modelProgram modelBuiltins σ (.run (Closure.pure (call 7)) [] Store.empty) none
      (.error ["HiddenBuilder7"] [] Store.empty) ∧
    Step modelProgram modelBuiltins σ (.run (Closure.pure (call 8)) [] Store.empty) none
      (.error ["HiddenBuilderOther"] [] Store.empty)

theorem hidden_capture_reply_states (σ : PathEnv) (hσ : σ.Valid) :
    (StateTyE modelProgram modelBuiltins σ Eff.empty (.error ["HiddenBuilder7"] [] Store.empty) ∧
      LocalStateInvariant modelProgram modelBuiltins σ (.error ["HiddenBuilder7"] [] Store.empty)) ∧
    (StateTyE modelProgram modelBuiltins σ Eff.empty (.error ["HiddenBuilderOther"] [] Store.empty) ∧
      LocalStateInvariant modelProgram modelBuiltins σ (.error ["HiddenBuilderOther"] [] Store.empty))

private theorem unit_prepared (P B σ) (hσ : σ.Valid) :
    InitialPrepared P B σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty)

theorem prepared_unit_source (σ : PathEnv) (hσ : σ.Valid) :
    modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
    modelBuiltins.CoreAssumptions modelProgram ∧
    StateTy modelProgram modelBuiltins σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
    σ.Ready modelProgram modelBuiltins (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
    modelProgram.ExternalWF

theorem prepared_unit_concrete :
    ∃ σ, σ.Valid ∧ modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
      modelBuiltins.CoreAssumptions modelProgram ∧
      StateTy modelProgram modelBuiltins σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      σ.Ready modelProgram modelBuiltins (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      modelProgram.ExternalWF
```

## ReadLocalRefs

```lean
def BuilderLive (μ : Store) (l : Nat) : Prop := ∃ c, μ l = some (.builder c)

def StoreTy.BuilderPlaces (Ψ : StoreTy) (places : Nat → Prop) : Prop :=
  ∀ l kind, Ψ l = some (.builder kind) → places l

def LocalRef.Allowed (depth : Nat) (places : Nat → Prop) : LocalRef → Prop
  | .bound i => i < depth
  | .loc l => places l

def Val.LocalLeaf : Val → Prop
  | .var .. | .const .. | .fnRef .. | .prim .. | .op .. | .raise .. | .loc .. |
    .bytesV .. | .externalRef .. | .externalHandle .. | .pathBases .. |
    .scopePattern .. | .atError .. | .checked .. => True
  | _ => False

inductive Val.LocalRefs (P : Program) (B : Builtins) : StoreTy → Nat → (Nat → Prop) → Val → Prop where
    | leaf {Ψ depth places v} : v.LocalLeaf → Val.LocalRefs P B Ψ depth places v
    | lam {Ψ depth places ns ps body} : Comp.LocalRefs P B (hideBuilders Ψ) ps.length (fun _ => False) body →
        Val.LocalRefs P B Ψ depth places (.lam ns ps body)
    | dependentLam {Ψ depth places t body} : Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) body →
        Val.LocalRefs P B Ψ depth places (.dependentLam t body)
    | closure {Ψ depth places runtime cap code Γ Φ t} :
        CaptureOk P B (hideBuilders Ψ) none Γ Φ cap →
        TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ t code →
        Capture.LocalRefs P B (hideBuilders Ψ) Γ Φ cap →
        Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) code →
        Val.LocalRefs P B Ψ depth places (.closure runtime (.mk cap code))
    | con {Ψ depth places c ts vs} : Val.LocalRefsList P B Ψ depth places vs →
        Val.LocalRefs P B Ψ depth places (.con c ts vs)
    | list {Ψ depth places vs} : Val.LocalRefsList P B Ψ depth places vs → Val.LocalRefs P B Ψ depth places (.list vs)
    | setV {Ψ depth places vs} : Val.LocalRefsList P B Ψ depth places vs → Val.LocalRefs P B Ψ depth places (.setV vs)
    | dict {Ψ depth places i ts vs} : Val.LocalRefsList P B Ψ depth places vs → Val.LocalRefs P B Ψ depth places (.dict i ts vs)
    | mapV {Ψ depth places ks vs} : Val.LocalRefsList P B Ψ depth places ks → Val.LocalRefsList P B Ψ depth places vs →
        Val.LocalRefs P B Ψ depth places (.mapV ks vs)
    | super {Ψ depth places v cl} : Val.LocalRefs P B Ψ depth places v → Val.LocalRefs P B Ψ depth places (.super v cl)
    | checkedRequest {Ψ depth places t req} : Val.LocalRefs P B Ψ 0 (fun _ => False) req →
        Val.LocalRefs P B Ψ depth places (.checkedRequest t req)
    | checkedAt {Ψ depth places range snapshot target req} :
        (∀ v, req = some v → Val.LocalRefs P B Ψ 0 (fun _ => False) v) →
        Val.LocalRefs P B Ψ depth places (.checkedAt range snapshot target req)

inductive Val.LocalRefsList (P : Program) (B : Builtins) : StoreTy → Nat → (Nat → Prop) → List Val → Prop where
    | nil {Ψ depth places} : Val.LocalRefsList P B Ψ depth places []
    | cons {Ψ depth places v vs} : Val.LocalRefs P B Ψ depth places v → Val.LocalRefsList P B Ψ depth places vs →
        Val.LocalRefsList P B Ψ depth places (v::vs)

inductive Comp.LocalRefs (P : Program) (B : Builtins) : StoreTy → Nat → (Nat → Prop) → Comp → Prop where
    | builderLet {Ψ depth places kind body} : Comp.LocalRefs P B Ψ (depth+1) places body →
        Comp.LocalRefs P B Ψ depth places (.builderLet kind body)
    | builderOp {Ψ depth places kind op r vs} : LocalRef.Allowed depth places r → Val.LocalRefsList P B Ψ depth places vs →
        Comp.LocalRefs P B Ψ depth places (.builderOp kind op r vs)
    | ret {Ψ depth places v} : Val.LocalRefs P B Ψ depth places v → Comp.LocalRefs P B Ψ depth places (.ret v)
    | escape {Ψ depth places v} : Val.LocalRefs P B Ψ depth places v → Comp.LocalRefs P B Ψ depth places (.escape v)
    | letIn {Ψ depth places m n} : Comp.LocalRefs P B Ψ depth places m → Comp.LocalRefs P B Ψ (depth+1) places n →
        Comp.LocalRefs P B Ψ depth places (.letIn m n)
    | app {Ψ depth places f vs} : Val.LocalRefs P B Ψ depth places f → Val.LocalRefsList P B Ψ depth places vs →
        Comp.LocalRefs P B Ψ depth places (.app f vs)
    | ite {Ψ depth places v m n} : Val.LocalRefs P B Ψ depth places v → Comp.LocalRefs P B Ψ depth places m →
        Comp.LocalRefs P B Ψ depth places n → Comp.LocalRefs P B Ψ depth places (.ite v m n)
    | matchC {Ψ depth places v arms} : Val.LocalRefs P B Ψ depth places v → Arm.LocalRefsList P B Ψ depth places arms →
        Comp.LocalRefs P B Ψ depth places (.match v arms)
    | lazyC {Ψ depth places m} : Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) m →
        Comp.LocalRefs P B Ψ depth places (.lazyC m)
    | use {Ψ depth places v m} : Val.LocalRefs P B Ψ depth places v → Comp.LocalRefs P B Ψ depth places m →
        Comp.LocalRefs P B Ψ depth places (.use v m)
    | handle {Ψ depth places m cs} : Comp.LocalRefs P B Ψ depth places m → Clause.LocalRefsList P B Ψ cs →
        Comp.LocalRefs P B Ψ depth places (.handle m cs)
    | resume {Ψ depth places k v} : Val.LocalRefs P B Ψ depth places k → Val.LocalRefs P B Ψ depth places v →
        Comp.LocalRefs P B Ψ depth places (.resume k v)
    | externalCall {Ψ depth places f ts vs} : Val.LocalRefsList P B Ψ depth places vs →
        Comp.LocalRefs P B Ψ depth places (.externalCall f ts vs)
    | issuePathBases {Ψ depth places b} : Comp.LocalRefs P B Ψ depth places (.issuePathBases b)
    | checkAt {Ψ depth places kind name shape bases pattern input index} :
        (∀ v, bases = some v → Val.LocalRefs P B Ψ depth places v) →
        Val.LocalRefs P B Ψ depth places pattern → Val.LocalRefs P B Ψ depth places input →
        Comp.LocalRefs P B Ψ depth places (.checkAt kind name shape bases pattern input index)
    | meth {Ψ depth places v m ts es vs} : Val.LocalRefs P B Ψ depth places v → Val.LocalRefsList P B Ψ depth places vs →
        Comp.LocalRefs P B Ψ depth places (.meth v m ts es vs)

inductive Arm.LocalRefsList (P : Program) (B : Builtins) : StoreTy → Nat → (Nat → Prop) → List Arm → Prop where
    | nil {Ψ depth places} : Arm.LocalRefsList P B Ψ depth places []
    | plain {Ψ depth places alts body arms} : Comp.LocalRefs P B Ψ (depth+Benitoite.Release.Arm.bindersOf alts) places body →
        Arm.LocalRefsList P B Ψ depth places arms → Arm.LocalRefsList P B Ψ depth places (.mk alts none body::arms)
    | guarded {Ψ depth places alts guard body arms} : Comp.LocalRefs P B Ψ (depth+Benitoite.Release.Arm.bindersOf alts) places guard →
        Comp.LocalRefs P B Ψ (depth+Benitoite.Release.Arm.bindersOf alts) places body → Arm.LocalRefsList P B Ψ depth places arms →
        Arm.LocalRefsList P B Ψ depth places (.mk alts (some guard) body::arms)

inductive Clause.LocalRefsList (P : Program) (B : Builtins) : StoreTy → List Clause → Prop where
    | nil {Ψ} : Clause.LocalRefsList P B Ψ []
    | cons {Ψ o n k body cs} : Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) body →
        Clause.LocalRefsList P B Ψ cs → Clause.LocalRefsList P B Ψ (.mk o n k body::cs)
    | fail {Ψ e body} : Comp.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) body →
        Clause.LocalRefsList P B Ψ [.fail e body]
  /-- 通常値の像だけを再帰して検査する。型・述語・snapshot の参照は Transport が保持する。 -/

inductive Capture.LocalRefs (P : Program) (B : Builtins) : StoreTy → Ctx → List Pred → Capture → Prop where
    | mk {Ψ Γ Φ cap} : Transport (valEnv cap.env) Γ Φ [] [] →
        (∀ i a, Γ[i]? = some (some a) → a.Ordinary → Val.LocalRefs P B Ψ 0 (fun _ => False) (cap.env i)) →
        Capture.LocalRefs P B Ψ Γ Φ cap

def Val.NoFreeBuilders (P : Program) (B : Builtins) (Ψ : StoreTy) (v : Val) : Prop :=
  Val.LocalRefs P B Ψ 0 (fun _ => False) v

def LocalCtx.Resolved (L : LocalCtx) (ρ : Nat → LocalRef) (depth : Nat) (places : Nat → Prop) : Prop :=
  ∀ i kind, L[i]? = some (some kind) → LocalRef.Allowed depth places (ρ i)

theorem LocalCtx.Resolved.empty (ρ) (depth) (places) : LocalCtx.Resolved [] ρ depth places

theorem StoreTy.BuilderPlaces.hidden (Ψ : StoreTy) : (hideBuilders Ψ).BuilderPlaces (fun _ => False)

theorem LocalCtx.Resolved.extend {L ρ depth places} (h : LocalCtx.Resolved L ρ depth places) (x) :
    LocalCtx.Resolved (LocalCtx.extend x L) (upLocalSubst 1 ρ) (depth+1) places

theorem LocalCtx.Resolved.many {L ρ depth places} (h : LocalCtx.Resolved L ρ depth places) (n) :
    LocalCtx.Resolved (localExtend n L) (upLocalSubst n ρ) (depth+n) places

theorem LocalRef.HasKind.localRefs {Ψ L r kind ρ depth places}
    (h : LocalRef.HasKind Ψ L r kind) (hL : LocalCtx.Resolved L ρ depth places)
    (hΨ : Ψ.BuilderPlaces places) : LocalRef.Allowed depth places (r.subst ρ)

theorem HasTypeVQ.localRefs {P B Ψ Q C Γ Φ v a depth places} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
      Val.LocalRefs P B Ψ depth places v

theorem HasTypeVsQ.localRefs {P B Ψ Q C Γ Φ vs as depth places} (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
      Val.LocalRefsList P B Ψ depth places vs

theorem HasTypeEachQ.localRefs {P B Ψ Q C Γ Φ vs a depth places} (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) :
      Val.LocalRefsList P B Ψ depth places vs

theorem HasTypeCQ.localRefs {P B Ψ Q C Γ Φ R m a e L ρ depth places}
      (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
      (hL : LocalCtx.Resolved L ρ depth places) (hΨ : Ψ.BuilderPlaces places) :
      Comp.LocalRefs P B Ψ depth places (m.resolveLocals ρ)

theorem HasTypeTelArgsQ.localRefs {P B Ψ Q C Γ Φ vs t a e depth places}
      (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) : Val.LocalRefsList P B Ψ depth places vs

theorem TelBodyTy.localRefs {P B Ψ Q C Γ Φ t body depth places}
      (h : TelBodyTy P B Ψ Q C Γ Φ t body) (hΨ : Ψ.BuilderPlaces places) :
      Comp.LocalRefs P B Ψ depth places body

theorem DependentClosureTy.localRefs {P B Ψ q t runtime depth places}
      (h : DependentClosureTy P B Ψ q t) : Val.LocalRefs P B Ψ depth places (.closure runtime q)

theorem CaptureOk.localRefs {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
      Capture.LocalRefs P B Ψ Γ Φ cap

theorem ImageOk.localRefs {P B Ψ Q C Γ Φ R ν i a} (h : ImageOk P B Ψ Q C Γ Φ R ν i a)
      (ho : a.Ordinary) : Val.LocalRefs P B Ψ 0 (fun _ => False) (ν i)

theorem CheckedWitness.localRefs {P B Ψ o k range snapshot target req}
      (h : CheckedWitness P B Ψ o k range snapshot target req) :
      ∀ v, req = some v → Val.LocalRefs P B Ψ 0 (fun _ => False) v

theorem AtCallAdmissible.localRefs {P B Ψ Q C Γ Φ kind name shape bases pattern input index depth places}
      (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
      Comp.LocalRefs P B Ψ depth places (.checkAt kind name shape bases pattern input index)

theorem HasTypeArmsQ.localRefs {P B Ψ Q C Γ Φ R obs arms a b e L ρ depth places}
      (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L)
      (hL : LocalCtx.Resolved L ρ depth places) (hΨ : Ψ.BuilderPlaces places) :
      Arm.LocalRefsList P B Ψ depth places (Arm.resolveLocalsList ρ arms)

theorem HasTypeClausesQ.localRefs {P B Ψ Q C Γ Φ R eb cs t e L}
      (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) : Clause.LocalRefsList P B Ψ cs

theorem HasFailureClause.localRefs {P B Ψ Q C Γ Φ E R cs t e L}
      (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) : Clause.LocalRefsList P B Ψ cs
```

## LocalInvariant

```lean
def Closure.LocalRefs (P : Program) (B : Builtins) (Ψ : StoreTy) (depth : Nat)
    (places : Nat → Prop) (q : Closure) : Prop :=
  ∃ Γ Φ Ξ R Rs source a e L ρ ss,
    ss.length = depth ∧ CaptureOk P B Ψ R Γ Φ q.capture ∧
    HasTypeCQ P B Ψ Qempty [] (bindParams Γ ss) Ξ Rs source a e L ∧
    CaptureLocals Ψ (upSubst ss.length q.capture.env) L ρ ∧ q.code = source.resolveLocals ρ ∧
    Capture.LocalRefs P B Ψ Γ Φ q.capture ∧ Comp.LocalRefs P B Ψ depth places q.code

theorem CaptureLocals.resolved {Ψ ν L ρ depth places} (h : CaptureLocals Ψ ν L ρ)
    (hΨ : Ψ.BuilderPlaces places) : LocalCtx.Resolved L ρ depth places

theorem ClosureTy.localRefs {P B Ψ ps R q a e depth places}
    (h : ClosureTy P B Ψ ps R q a e) (hn : ps.length = depth)
    (hΨ : Ψ.BuilderPlaces places) : Closure.LocalRefs P B Ψ depth places q

theorem GuardBodyTy.localRefs {P B Ψ R q input a e places}
    (h : GuardBodyTy P B Ψ R q input a e) (hΨ : Ψ.BuilderPlaces places) :
    Closure.LocalRefs P B Ψ 0 places q

def Frame.LocalRefs (P : Program) (B : Builtins) (Ψ : StoreTy) (places : Nat → Prop) : Frame → Prop
  | .letF q => Closure.LocalRefs P B Ψ 1 places q
  | .release v => v.NoFreeBuilders P B Ψ
  | .handleF cap cs => ∃ Γ Φ R Rs eb t e,
      CaptureOk P B (hideBuilders Ψ) R Γ Φ cap ∧ Capture.LocalRefs P B (hideBuilders Ψ) Γ Φ cap ∧
      (HasTypeClausesQ P B (hideBuilders Ψ) Qempty [] Γ Φ Rs eb cs t e [] ∨
        ∃ E, HasFailureClause P B (hideBuilders Ψ) Qempty [] Γ Φ E Rs cs t e []) ∧
      Clause.LocalRefsList P B (hideBuilders Ψ) cs
  | .guardF v cap arms _ body => ∃ Γ Φ R Rs vs t a e obs arms0 L ρ,
      CaptureOk P B Ψ R Γ Φ cap ∧ Capture.LocalRefs P B Ψ Γ Φ cap ∧
      HasTypeV P B Ψ [] Γ Φ vs t ∧ HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms0 t a e L ∧
      CaptureLocals Ψ cap.env L ρ ∧ v = closeVal cap vs ∧ arms = Arm.resolveLocalsList ρ arms0 ∧
      Arm.LocalRefsList P B Ψ 0 places arms ∧ Closure.LocalRefs P B Ψ 0 places body
  | .mark | .update _ | .drop _ => True

def Cont.LocalRefs (P : Program) (B : Builtins) (Ψ : StoreTy) (places : Nat → Prop) (k : Cont) : Prop :=
  ∀ f ∈ k, Frame.LocalRefs P B Ψ places f

theorem ContTy.localRefs {P B σ Ψ R e k a b Eb Re places}
    (h : ContTy P B σ Ψ R e k a b Eb Re) (hΨ : Ψ.BuilderPlaces places) :
    Cont.LocalRefs P B Ψ places k

theorem StoreOk.builder_places {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) : Ψ.BuilderPlaces (BuilderLive μ)

def Cell.LocalRefs (P : Program) (B : Builtins) (Ψ : StoreTy) (places : Nat → Prop) : Cell → Prop
  | .builder (.list vs) => Val.LocalRefsList P B Ψ 0 (fun _ => False) vs
  | .builder (.string _) | .builder (.bytes _) | .used => True
  | .val v | .done v => v.NoFreeBuilders P B Ψ
  | .thunk q => Closure.LocalRefs P B (hideBuilders Ψ) 0 (fun _ => False) q
  | .cont k => Cont.LocalRefs P B Ψ places k

theorem CellOk.localRefs {P B σ Ψ l c places} (h : CellOk P B σ Ψ l c)
    (hΨ : Ψ.BuilderPlaces places) : Cell.LocalRefs P B Ψ places c

def LocalStateInvariant (P : Program) (B : Builtins) (σ : PathEnv) (s : State) : Prop :=
  ∃ Ψ, (match s with
    | .run q k μ => StoreOk P B σ Ψ μ ∧ Closure.LocalRefs P B Ψ 0 (BuilderLive μ) q ∧
        Cont.LocalRefs P B Ψ (BuilderLive μ) k ∧ ∀ l c, μ l = some c → Cell.LocalRefs P B Ψ (BuilderLive μ) c
    | .matchRun v cap arms _ k μ => StoreOk P B σ Ψ μ ∧
        (∃ vs, v = closeVal cap vs ∧ Closure.LocalRefs P B Ψ 0 (BuilderLive μ) (.mk cap (.match vs arms))) ∧
        Cont.LocalRefs P B Ψ (BuilderLive μ) k ∧ ∀ l c, μ l = some c → Cell.LocalRefs P B Ψ (BuilderLive μ) c
    | .error _ k μ | .exit _ _ k μ => StoreOk P B σ Ψ μ ∧
        Cont.LocalRefs P B Ψ (BuilderLive μ) k ∧ ∀ l c, μ l = some c → Cell.LocalRefs P B Ψ (BuilderLive μ) c) ∧
    (∀ Q C Γ Φ v a, HasTypeVQ P B Ψ Q C Γ Φ v a → v.NoFreeBuilders P B Ψ)

theorem StateTyE.local_invariant {P B σ Eb s} (h : StateTyE P B σ Eb s) : LocalStateInvariant P B σ s

theorem Closure.LocalRefs.builder_location {P B Ψ q depth places kind op l args}
    (h : Closure.LocalRefs P B Ψ depth places q) (hv : q.view = .builderOp kind op (.loc l) args) : places l

theorem StateTyE.builder_live {P B σ Eb q k μ kind op l args}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .builderOp kind op (.loc l) args) : BuilderLive μ l
```

## ClosedRename

```lean
private theorem upRen_fixed {nv ξ} (h : ∀ i, i<nv → ξ i = i) (n : Nat) :
    ∀ i, i<nv+n → upRen n ξ i = i

private theorem type_rename_fixed {nt nv : Nat} {a : Ty} {ξ : Nat → Nat} (h : a.WF 0 nt nv) (hf : ∀ i, i<nv → ξ i = i) : renameTy ξ a = a

private theorem types_rename_fixed {nt nv : Nat} {ts : List Ty} {ξ : Nat → Nat} (h : ∀ a∈ts,a.WF 0 nt nv) (hf : ∀ i, i<nv → ξ i = i) :
    ts.map (renameTy ξ) = ts

private theorem rows_rename_fixed {nt nv : Nat} {es : List Eff} {ξ : Nat → Nat} (h : ∀ e∈es,Eff.WF 0 nt nv e ∧ e.Canonical) (hf : ∀ i, i<nv → ξ i = i) :
    es.map (renameEff ξ) = es

private theorem tel_rename_fixed {nt nv : Nat} {t : Tel} {ξ : Nat → Nat} (h : Tel.WF 0 nt nv t) (hf : ∀ i, i<nv → ξ i = i) :
    Tel.rawBind (renEnv ξ) t = t

theorem Val.ClosedAt.rename_closed_scope {nt nv nv' : Nat} {v : Val} {ξ : Nat → Nat} (h : v.ClosedAt nt nv)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : v.rename ξ = v ∧ v.ClosedAt nt nv'

theorem Val.ClosedList.rename_closed_scope {nt nv nv' : Nat} {vs : List Val} {ξ : Nat → Nat} (h : Val.ClosedList nt nv vs)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : Val.renameList ξ vs = vs ∧ Val.ClosedList nt nv' vs

theorem Comp.ClosedAt.rename_closed_scope {nt nv nv' : Nat} {m : Comp} {ξ : Nat → Nat} (h : m.ClosedAt nt nv)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : m.rename ξ = m ∧ m.ClosedAt nt nv'

theorem Arm.ClosedList.rename_closed_scope {nt nv nv' : Nat} {arms : List Arm} {ξ : Nat → Nat} (h : Arm.ClosedList nt nv arms)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : Arm.renameList ξ arms = arms ∧ Arm.ClosedList nt nv' arms

theorem Clause.ClosedList.rename_closed_scope {nt nv nv' : Nat} {cs : List Clause} {ξ : Nat → Nat} (h : Clause.ClosedList nt nv cs)
      (hle : nv ≤ nv') (hf : ∀ i, i<nv → ξ i = i) : Clause.renameList ξ cs = cs ∧ Clause.ClosedList nt nv' cs
```

## StateLeaves

```lean
private theorem ground_list {vs : List Val} (h : ∀ v∈vs,v.Ground) : Val.ClosedList 0 0 vs

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e

theorem StateTyE.app_view_pure {P B σ Eb q f ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app f ws) :
    StateTyE P B σ Eb (.run (Closure.pure (.app f ws)) k μ)

theorem StateTyE.reference_new_all {P B σ Eb q b ts es rs v k μ s l}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [v])
    (hs : B.sig b = some s) (hk : s.kind = .refNew) (hl : μ l = none) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v)))

theorem StateTyE.reference_get_all {P B σ Eb q b ts es rs l k μ s v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l])
    (hs : B.sig b = some s) (hk : s.kind = .refGet) (hl : μ l = some (.val v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.reference_set_all {P B σ Eb q b ts es rs l v k μ s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l,v])
    (hs : B.sig b = some s) (hk : s.kind = .refSet) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v)))

private theorem primitive_raw {P B Ψ Q C Γ Φ v b s ts T}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .prim b (Ty.normTys ts) [] [])
    (hs : B.sig b = some s) (ha : TypeAnnotations P C Γ ts)
    (hk : TypeArgsKinded P C ts (s.tparams.map TParamDecl.kind))
    (hscope : ∀ a∈ts,a.WF 0 C.length Γ.length ∧ a.Ordinary) :
    HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts [] []) T

private theorem raw_reference_heads {P B Ψ b s ts es rs T}
    (hB : B.CoreAssumptions P) (hv : HasTypeV P B Ψ [] [] [] (.prim b ts es rs) T)
    (hs : B.sig b = some s) (hkind : s.kind = .refUpdate) {a : Ty}
    (hts : Ty.normTys ts = [a]) (ha : Ty.Annotation P [] [] a) (hn : a.Normal)
    (ho : a.Ordinary) (hk : a.HasKind P [] .value) :
    HasTypeV P B Ψ [] [] [] (.prim B.refGet ts [] [])
      (.fn ["reference"] [.reference a] a (Eff.single stateEff)) ∧
    HasTypeV P B Ψ [] [] [] (.prim B.refSet ts [] [])
      (.fn ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff))

theorem StateTyE.reference_update_all {P B σ Eb q b ts es rs l f k μ s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l,f])
    (hsig : B.sig b = some s) (hkind : s.kind = .refUpdate) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
        (.letIn (.app (f.rename (·+1)) [.var 0]) (.app (.prim B.refSet ts [] []) [.loc l,.var 0])))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
        (.letIn (.app (f.rename (·+1)) [.var 0]) (.app (.prim B.refSet ts [] []) [.loc l,.var 0])))) k μ)

theorem StateTyE.force_done_all {P B σ Eb q b ts es rs l k μ s v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l])
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.done v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.force_thunk_all {P B σ Eb q b ts es rs l k μ s m}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) [.loc l])
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.thunk m)) :
    Step P B σ (.run q k μ) none (.run m (.update l::k) μ) ∧
    StateTyE P B σ Eb (.run m (.update l::k) μ)

theorem StateTyE.lazy_update_all {P B σ Eb q v l k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.update l::k) μ)) (hv : q.view = .ret v) :
    Step P B σ (.run q (.update l::k) μ) none (.run (Closure.pure (.ret v)) k (μ.set l (.done v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k (μ.set l (.done v)))
```

## ReplyState

```lean
private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e

private theorem adequate_member {σ vs} (h : adequateVals σ vs) :
    ∀ v∈vs,v.Adequate σ

theorem reply_value_state {P B σ Eb Ψ R a b e k μ r v}
    (hs : StoreOk P B σ Ψ μ)
    (hk : ContTy P B σ Ψ R e k a b Eb none)
    (hr : Ty.Annotation P [] [] r) (hn : r.Normal) (hle : Ty.LeQ P [] [] r a)
    (hv : HasTypeV P B Ψ [] [] [] v r) (hg : v.Ground) (ha : v.Adequate σ)
    (hkc : k.Closed) (hμ : μ.Closed) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.error_from_run {P B σ Eb q k μ rs}
    (h : StateTyE P B σ Eb (.run q k μ)) : StateTyE P B σ Eb (.error rs k μ)

theorem StateTyE.exit_from_run {P B σ Eb q k μ n rs}
    (h : StateTyE P B σ Eb (.run q k μ)) : StateTyE P B σ Eb (.exit n rs k μ)

theorem ClosureTy.primitive_view_inputs {P B Ψ R q a e b ts es rs ws s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hc : q.ClosedAt 0)
    (hv : q.view = .app (.prim b ts es rs) ws) (hb : B.sig b = some s) :
    ∃ r ef, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r ef ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e ef

theorem StateTyE.primitive_value_all {P B σ Eb q b ts es rs ws k μ s v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .pure)
    (hδ : B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.val v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.primitive_error_all {P B σ Eb q b ts es rs ws k μ s r}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .pure)
    (hδ : B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.err r)) :
    Step P B σ (.run q k μ) none (.error [r] k μ) ∧ StateTyE P B σ Eb (.error [r] k μ)

theorem StateTyE.io_value_all {P B σ Eb q b ts es rs ws k μ s v obs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .io) (hnh : NoHandler k (.prim b))
    (hio : B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.val v) obs) :
    Step P B σ (.run q k μ) (some (.io b ws (.val v) obs)) (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.io_error_all {P B σ Eb q b ts es rs ws k μ s r obs}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .io ∨ s.kind = .exit) (hnh : NoHandler k (.prim b))
    (hio : B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.err r) obs) :
    Step P B σ (.run q k μ) (some (.io b ws (.err r) obs)) (.error [r] k μ) ∧
    StateTyE P B σ Eb (.error [r] k μ)

theorem StateTyE.io_exit_all {P B σ Eb q b ts es rs ws k μ s n obs}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .exit) (hnh : NoHandler k (.prim b))
    (hio : B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.exit n) obs) :
    Step P B σ (.run q k μ) (some (.io b ws (.exit n) obs)) (.exit n [] k μ) ∧
    StateTyE P B σ Eb (.exit n [] k μ)
```

## ExternalStateLeaves

```lean
private theorem typeEnv_nil : typeEnv [] = renEnv id

private theorem close_external {P B Ψ Q C Γ Φ Rs m a e L cap R f ts vs}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .externalCall f ts vs) (Rt : Option Ty) :
    HasTypeCQ P B Ψ Qempty [] [] [] Rt (.externalCall f (ts.map cap.closeTy) (closeVals cap vs))
      (cap.closeTy a) (cap.closeEff e) []

theorem ClosureTy.external_view_typed {P B Ψ R q a e f ts vs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .externalCall f ts vs) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.externalCall f ts vs) a e []

private theorem external_inputs {P B Ψ Q C Γ Φ R m a e L f ts vs d}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hm : m = .externalCall f ts vs) (hd : P.externalFunction f = some d)
    (hg : ∀ v∈vs,v.Ground) :
    ∃ r ef, ExternalArgs P B Ψ d ts vs r ef ∧ Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e ef

theorem ClosureTy.external_view_inputs {P B Ψ R q a e f ts vs d}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hc : q.ClosedAt 0)
    (hv : q.view = .externalCall f ts vs) (hf : P.externalFunction f = some d) :
    ∃ r ef, ExternalArgs P B Ψ d ts vs r ef ∧ Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e ef

theorem StateTyE.external_value_all {P B σ Eb q f ts vs k μ d out obs v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .externalCall f ts vs)
    (hd : P.externalFunction f = some d) (hr : B.externalResponse f ts vs out obs)
    (hrec : externalReceive P d ts vs out = some (.val v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.external_error_all {P B σ Eb q f ts vs k μ d out obs r}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .externalCall f ts vs)
    (hd : P.externalFunction f = some d) (hr : B.externalResponse f ts vs out obs)
    (hrec : externalReceive P d ts vs out = some (.err r)) :
    Step P B σ (.run q k μ) none (.error [r] k μ) ∧ StateTyE P B σ Eb (.error [r] k μ)

private theorem external_inv {P B Ψ Q C Γ Φ v T f ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .externalRef f ts) :
    ∃ d u, P.externalFunction f = some d ∧ d.WF P ∧ ExternalCallAdmissible P B C d ts ∧
      SignatureInstance P C Γ d.parameters d.kinds ts [] ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.parameters ts []) u

private theorem external_annotation {P B Ψ Q C Γ Φ v T f ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .externalRef f ts) : Ty.Annotation P C Γ T

private theorem external_apply {P B Ψ Q C Γ Φ R m a e L f ts vs}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hm : m = .app (.externalRef f ts) vs) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.externalCall f ts vs) a e []

theorem StateTyE.external_apply_all {P B σ Eb q f ts vs k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.externalRef f ts) vs) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.externalCall f ts vs)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.externalCall f ts vs)) k μ)
```

## AtStateInputs

```lean
private theorem checkAt_resolve {P B Ψ Q C Γ Φ R kind name shape bases pattern input index a e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.checkAt kind name shape bases pattern input index) a e L)
    (ρ : Nat → LocalRef) :
    (Comp.checkAt kind name shape bases pattern input index).resolveLocals ρ =
      .checkAt kind name shape bases pattern input index

private theorem at_source {P B Ψ Q C Γ Φ Rs m a e L cap R kind name shape bases pattern input index}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L) (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = [])
    (hm : m = .checkAt kind name shape bases pattern input index) :
    AtCallAdmissible P B Ψ Qempty [] Γ Φ kind name shape bases pattern input index ∧
      Ty.LeQ P [] [] (cap.closeTy (.data shape.owner [.scoped name kind index,shape.errorType])) (cap.closeTy a)

theorem ClosureTy.at_inputs {P B Ψ R q a e kind name shape bases pattern input index}
    (hq : ClosureTy P B Ψ [] R q a e)
    (hv : q.code = .checkAt kind name shape bases pattern input index) :
    ∃ Γ Φ, CaptureOk P B Ψ R Γ Φ q.capture ∧
      AtCallAdmissible P B Ψ Qempty [] Γ Φ kind name shape bases pattern input index ∧
      Ty.LeQ P [] [] (q.capture.closeTy (.data shape.owner [.scoped name kind index,shape.errorType])) a

private theorem closed_input_type {cap : Capture} {a : Ty} (h : a.WF 0 0 0) : cap.closeTy a.norm = a.norm

theorem AtCallAdmissible.closed_input {P B Ψ R Γ Φ cap kind name shape bases pattern input index}
    (h : AtCallAdmissible P B Ψ Qempty [] Γ Φ kind name shape bases pattern input index)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) :
    ∃ inputTy,
      (inputTy = .base .string ∧ B.valContent name = none ∨
        B.valContent name = some inputTy ∧ inputTy.WF 0 0 0 ∧ inputTy.RowsIn (· < 0)) ∧
      HasTypeV P B Ψ [] [] [] (closeVal cap input) inputTy.norm

theorem AtCallAdmissible.result_image {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
    {cap : Capture} (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
    cap.closeTy shape.errorType = shape.errorType ∧
    cap.closeTy (.data shape.owner [.scoped name kind index,shape.errorType]) =
      .data shape.owner [.scoped name kind index,shape.errorType] ∧
    Ty.Annotation P [] [] (.data shape.owner [.scoped name kind index,shape.errorType]) ∧
    (.data shape.owner [.scoped name kind index,shape.errorType] : Ty).Normal
```

## AtStateLeaves

```lean
private theorem result_kinds {P shape name kind index} (hs : ResultShape.Declared P shape) :
    TypeArgsKinded P [] [.scoped name kind index,shape.errorType] [.value,.value]

private theorem result_ok {P B Ψ shape name kind index v}
    (hs : ResultShape.Declared P shape)
    (ha : Ty.Annotation P [] [] (.data shape.owner [.scoped name kind index,shape.errorType]))
    (hv : HasTypeV P B Ψ [] [] [] v (.scoped name kind index)) :
    HasTypeV P B Ψ [] [] [] (.con shape.ok [.scoped name kind index,shape.errorType] [v])
      (.data shape.owner [.scoped name kind index,shape.errorType])

private theorem result_error {P B Ψ shape name kind index detail}
    (hs : ResultShape.Declared P shape)
    (ha : Ty.Annotation P [] [] (.data shape.owner [.scoped name kind index,shape.errorType])) :
    HasTypeV P B Ψ [] [] [] (.con shape.error [.scoped name kind index,shape.errorType] [.atError detail])
      (.data shape.owner [.scoped name kind index,shape.errorType])

private theorem shape_of_at {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
    (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
    shape.Declared P ∧ B.valKind name = some kind

theorem StateTyE.at_ok_all {P B σ Eb q kind name shape bases pattern input index snapshot pat target bound t k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (hp : AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound)
    (hcurrent : ∀ ρ, snapshot = some ρ → ρ = σ)
    (hat : checkAt snapshot kind pat target bound = .ok t) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.con shape.ok [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.checkedAt bound snapshot t (AtRequest B name (closeVal q.capture input))]))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.con shape.ok [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.checkedAt bound snapshot t (AtRequest B name (closeVal q.capture input))]))) k μ)

theorem StateTyE.at_error_all {P B σ Eb q kind name shape bases pattern input index snapshot pat target bound detail k μ}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (hp : AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound)
    (hcurrent : ∀ ρ, snapshot = some ρ → ρ = σ)
    (hat : checkAt snapshot kind pat target bound = .error detail) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.con shape.error [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.atError detail]))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.con shape.error [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.atError detail]))) k μ)

theorem StateTyE.at_prepare_error_all {P B σ Eb q kind name shape bases pattern input index detail k μ}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (hat : AtPrepare B q.capture kind name bases pattern input index = .error detail) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.con shape.error [.scoped name kind index,q.capture.closeTy shape.errorType]
        [.atError detail]))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.con shape.error [.scoped name kind index,q.capture.closeTy shape.errorType]
        [.atError detail]))) k μ)
```

## PathBasesLeaves

```lean
private theorem path_annotation (P : Program) (Γ : Ctx) :
    Ty.Annotation P [] Γ (.dependentFn (.done .pathBases (Eff.single processEnvironmentEff)))

private theorem path_arguments {P B Ψ b s r e}
    (hB : B.CoreAssumptions P) (hs : B.sig b = some s) (hk : s.kind = .pathBases)
    (h : BuiltinArgs P B Ψ b s [] [] [] [] r e) :
    r = .pathBases ∧ e = Eff.single processEnvironmentEff

theorem StateTyE.path_bases_apply_all {P B σ Eb q b s k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b [] [] []) [])
    (hsig : B.sig b = some s) (hkind : s.kind = .pathBases) (hnh : NoHandler k (.prim b)) :
    Step P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ) ∧
    StateTyE P B σ Eb (.run (.mk q.capture (.issuePathBases b)) k μ)

private theorem issue_source {P B Ψ Q C Γ Φ Rs m a e L cap R b}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L) (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .issuePathBases b) :
    Ty.LeQ P [] [] .pathBases (cap.closeTy a)

theorem ClosureTy.issue_path_bases_input {P B Ψ R q a e b}
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .issuePathBases b) :
    Ty.LeQ P [] [] .pathBases a

theorem StateTyE.issue_path_bases_all {P B σ Eb q b s k μ}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .issuePathBases b)
    (hsig : B.sig b = some s) (hkind : s.kind = .pathBases)
    (hop : s.opEff = some processEnvironmentEff) (hσ : σ.Valid) :
    Step P B σ (.run q k μ) (some (.pathBases b σ)) (.run (Closure.pure (.ret (.pathBases σ))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.pathBases σ))) k μ)
```

## SourcePreparation

```lean
theorem InitialPrepared.source_state {P B σ m a e}
    (h : InitialPrepared P B σ (.run (Closure.pure m) [] Store.empty))
    (hext : P.ExternalWF) (hb : HasTypeC P B StoreTy.empty [] [] [] none m a e)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e)))
    (hc : m.ClosedAt 0 0) (had : m.Adequate σ) (he : BuiltinOnly P B e) :
    StateTy P B σ (.run (Closure.pure m) [] Store.empty) ∧
      σ.Ready P B (.run (Closure.pure m) [] Store.empty) ∧ P.ExternalWF
```

## StoreReplyLeaves

```lean
inductive StoreReplyInputs (P : Program) (B : Builtins) (σ : PathEnv) :
    State → Option Event → State → Prop where
  | E_RefNew {b ts es rs v k μ s l} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [v]) →
      B.sig b = some s → s.kind = .refNew → μ l = none →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v)))
  | E_RefGet {b ts es rs l k μ s v} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l]) →
      B.sig b = some s → s.kind = .refGet → μ l = some (.val v) →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_RefSet {b ts es rs l v k μ s} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l, v]) →
      B.sig b = some s → s.kind = .refSet →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v)))
  | E_RefUpdate {b ts es rs l f k μ s} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l, f]) →
      B.sig b = some s → s.kind = .refUpdate →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
                (.letIn (.app (f.rename (· + 1)) [.var 0])
                  (.app (.prim B.refSet ts [] []) [.loc l, .var 0])))) k μ)
  | E_Lazy {m k μ l} {q : Closure} :
      q.view = (.lazyC m) →
      μ l = none →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.thunk (Closure.mk q.capture m))))
  | E_ForceDone {b ts es rs l k μ s v} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l]) →
      B.sig b = some s → s.kind = .force → μ l = some (.done v) →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_Force {b ts es rs l k μ s m} {q : Closure} :
      q.view = (.app (.prim b ts es rs) [.loc l]) →
      B.sig b = some s → s.kind = .force → μ l = some (.thunk m) →
      StoreReplyInputs P B σ (.run q k μ) none (.run m (.update l :: k) μ)
  | E_Update {v l k μ} {q : Closure} :
      q.view = (.ret v) →
      StoreReplyInputs P B σ (.run q (.update l :: k) μ) none (.run (Closure.pure (.ret v)) k (μ.set l (.done v)))
  | E_ErrPopUpdate {rs l k μ} : StoreReplyInputs P B σ (.error rs (.update l :: k) μ) none (.error rs k μ)
  | E_ExitPopUpdate {n rs l k μ} : StoreReplyInputs P B σ (.exit n rs (.update l :: k) μ) none (.exit n rs k μ)
  | E_Prim {b ts es rs ws k μ s v} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → s.kind = .pure → B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.val v) →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_Err {b ts es rs ws k μ s r} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → s.kind = .pure → B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.err r) →
      StoreReplyInputs P B σ (.run q k μ) none (.error [r] k μ)
  | E_IO {b ts es rs ws k μ s v obs} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → s.kind = .io → NoHandler k (.prim b) →
      B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.val v) obs →
      StoreReplyInputs P B σ (.run q k μ) (some (.io b ws (.val v) obs)) (.run (Closure.pure (.ret v)) k μ)
  | E_IOErr {b ts es rs ws k μ s r obs} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → NoHandler k (.prim b) →
      B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.err r) obs →
      StoreReplyInputs P B σ (.run q k μ) (some (.io b ws (.err r) obs)) (.error [r] k μ)
  | E_Exit {b ts es rs ws k μ s n obs} {q : Closure} :
      q.view = (.app (.prim b ts es rs) ws) →
      B.sig b = some s → s.kind = .exit → NoHandler k (.prim b) →
      B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.exit n) obs →
      StoreReplyInputs P B σ (.run q k μ) (some (.io b ws (.exit n) obs)) (.exit n [] k μ)
  | E_ExternalApply {q : Closure} {f ts ws k μ} :
      q.view = .app (.externalRef f ts) ws →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.externalCall f ts ws)) k μ)
  | E_External {q : Closure} {f ts ws k μ decl v obs out} :
      q.view = .externalCall f ts ws → P.externalFunction f = some decl →
      B.externalResponse f ts ws out obs → externalReceive P decl ts ws out = some (.val v) →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_ExternalErr {q : Closure} {f ts ws k μ decl r obs out} :
      q.view = .externalCall f ts ws → P.externalFunction f = some decl →
      B.externalResponse f ts ws out obs → externalReceive P decl ts ws out = some (.err r) →
      StoreReplyInputs P B σ (.run q k μ) none (.error [r] k μ)
  | E_PathBasesApply {q : Closure} {b sg k μ} :
      q.view = .app (.prim b [] [] []) [] → B.sig b = some sg → sg.kind = .pathBases →
      NoHandler k (.prim b) →
      StoreReplyInputs P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ)
  | E_IssuePathBases {q : Closure} {b sg k μ} :
      q.view = .issuePathBases b → B.sig b = some sg → sg.kind = .pathBases →
      sg.opEff = some processEnvironmentEff → σ.Valid →
      StoreReplyInputs P B σ (.run q k μ) (some (.pathBases b σ))
        (.run (Closure.pure (.ret (.pathBases σ))) k μ)
  | E_AtOk {q : Closure} {kind name shape bases pattern input index snapshot pat target bound t k μ} :
      q.code = .checkAt kind name shape bases pattern input index →
      AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound →
      (∀ ρ, snapshot = some ρ → ρ = σ) → checkAt snapshot kind pat target bound = .ok t →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.con shape.ok
          [.scoped name kind (.fixed bound), q.capture.closeTy shape.errorType]
          [.checkedAt bound snapshot t (AtRequest B name (closeVal q.capture input))]))) k μ)
  | E_AtError {q : Closure} {kind name shape bases pattern input index snapshot pat target bound detail k μ} :
      q.code = .checkAt kind name shape bases pattern input index →
      AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound →
      (∀ ρ, snapshot = some ρ → ρ = σ) → checkAt snapshot kind pat target bound = .error detail →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.con shape.error
          [.scoped name kind (.fixed bound), q.capture.closeTy shape.errorType] [.atError detail]))) k μ)
  | E_AtPrepareError {q : Closure} {kind name shape bases pattern input index detail k μ} :
      q.code = .checkAt kind name shape bases pattern input index →
      AtPrepare B q.capture kind name bases pattern input index = .error detail →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.con shape.error
          [.scoped name kind index, q.capture.closeTy shape.errorType] [.atError detail]))) k μ)

theorem StateTyE.store_reply {P B σ Eb s event dest}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb s) (inputs : StoreReplyInputs P B σ s event dest) :
    Step P B σ s event dest ∧ StateTyE P B σ Eb dest ∧ LocalStateInvariant P B σ dest
```

## ReferencePreservation

```lean
theorem reference_update_body {P B Ψ a l f ts R}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (ha : Ty.Annotation P [] [] a) (ho : a.Ordinary)
    (hl : HasTypeV P B Ψ [] [] [] (.loc l) (.reference a))
    (hf : HasTypeV P B Ψ [] [] [] f (.fn ["value"] [a] a Eff.empty))
    (hg : HasTypeV P B Ψ [] [] [] (.prim B.refGet ts [] [])
      (.fn ["reference"] [.reference a] a (Eff.single stateEff)))
    (hs : HasTypeV P B Ψ [] [] [] (.prim B.refSet ts [] [])
      (.fn ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff)))
    (hts : ∀ t ∈ ts, t.WF 0 0 0) :
    HasTypeC P B Ψ [] [] [] R
      (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
        (.letIn (.app (f.rename (· + 1)) [.var 0])
          (.app (.prim B.refSet ts [] []) [.loc l,.var 0])))
      (.base .unit) (Eff.single stateEff)
```

## NormalReplyExamples

```lean
private def unitExternal : ExternalSignature :=
  ⟨.mk 0,"Example.unitExternal",[],[],.done (.base .unit) Eff.empty,[]⟩

private def resultOk : ConDecl := ⟨"Example.Result",2,[.tvar 0]⟩

private def resultError : ConDecl := ⟨"Example.Result",2,[.tvar 1]⟩

private def scopeError : ConDecl := ⟨"Scope.ScopeError",0,atErrorFields⟩

private def resultShape : ResultShape :=
  ⟨"Example.Result","Example.Ok","Example.Error",atErrorType⟩

private def modelProgram : Program where
  defs := fun _ => none
  cons := fun c => if c = "Example.Ok" then some resultOk
    else if c = "Example.Error" then some resultError
    else if c = "Scope.ScopeError.At" then some scopeError else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none
  externals := [(.function (.mk 0),.function (.mk 0) unitExternal)]

private def modelGet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference"]
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

private def modelSet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference", "value"]
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

private def unitSig (kind : PrimKind) (eff : Eff) (op : Option EffName) : PrimSig where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := eff
  admits := fun _ ts => ts.length = 0
  kind := kind
  opEff := op

private def pureSig : PrimSig := unitSig .pure Eff.empty none

private def ioSig : PrimSig := unitSig .io (Eff.single processEnvironmentEff) (some processEnvironmentEff)

private def modelBuiltins : Builtins where
  sig := fun b => if b = "Reference.get" then some modelGet
    else if b = "Reference.set" then some modelSet
    else if b = "Example.unit" then some pureSig
    else if b = "Example.ioUnit" then some ioSig else none
  delta := fun _ _ _ _ _ => some (.val (.const .unit))
  ioResponse := fun b _ _ _ out obs => b = "Example.ioUnit" ∧ out = .val (.const .unit) ∧ obs = []
  externalResponse := fun _ _ _ out obs => out = .val (.const .unit) ∧ obs = []
  releaseResponse := fun _ _ => True
  isResource := fun _ => true
  effects := fun l => if l = stateEff then some []
    else if l = processEnvironmentEff then some ["Example.ioUnit"] else none
  sat := fun _ _ _ => True
  valKind := fun o => if o = "Example.path" then some .path else none
  refGet := "Reference.get"
  refSet := "Reference.set"

private theorem model_sig_cases {b s} (h : modelBuiltins.sig b = some s) :
    s = modelGet ∨ s = modelSet ∨ s = pureSig ∨ s = ioSig

private theorem external_declaration : unitExternal.WF modelProgram

private theorem external_lookup {f d} (hd : modelProgram.externalFunction f = some d) : d = unitExternal

private theorem external_result {Ψ ts vs a e}
    (h : ExternalArgs modelProgram modelBuiltins Ψ unitExternal ts vs a e) : a = .base .unit

private theorem model_external : modelProgram.ExternalWF

private theorem cons_cases {c cd} (hc : modelProgram.cons c = some cd) :
    cd = resultOk ∨ cd = resultError ∨ cd = scopeError

private theorem result_arity : modelProgram.DataArity "Example.Result" 2

private theorem scope_arity : modelProgram.DataArity "Scope.ScopeError" 0

private theorem cons_scoped {c cd} (hc : modelProgram.cons c = some cd) : cd.Scoped modelProgram

private theorem shape_declared : resultShape.Declared modelProgram

private theorem model_wellFormed : modelProgram.WellFormed where
  defs

private theorem model_wellTyped : modelProgram.WellTyped modelBuiltins where
  variance

private theorem io_lookup {b s} (hs : modelBuiltins.sig b = some s)
    (hk : s.kind = .io ∨ s.kind = .exit) : b = "Example.ioUnit" ∧ s = ioSig

private theorem unit_result {Ψ b sg ts es rs ws a e}
    (hsg : sg = pureSig ∨ sg = ioSig)
    (h : BuiltinArgs modelProgram modelBuiltins Ψ b sg ts es rs ws a e) : a = .base .unit

private theorem model_core : modelBuiltins.CoreAssumptions modelProgram where
  sat_rename

private theorem unit_annotation {e : Eff} (he : e = Eff.empty ∨ e = Eff.single processEnvironmentEff) :
    Ty.Annotation modelProgram [] [] (.dependentFn (.done (.base .unit) e))

private theorem unit_tel {s : PrimSig} (hs : s = pureSig ∨ s = ioSig) :
    instantiatedTel (Tel.instR [] s.tel) [] [] = .done (.base .unit) s.eff

private def call (b : PrimName) : Comp := .app (.prim b [] [] []) []

private theorem call_typed {b s} (hl : modelBuiltins.sig b = some s) (hs : s = pureSig ∨ s = ioSig) :
    HasTypeC modelProgram modelBuiltins StoreTy.empty [] [] [] none (call b) (.base .unit) s.eff

private theorem source_state {σ m a e}
    (hb : HasTypeC modelProgram modelBuiltins StoreTy.empty [] [] [] none m a e)
    (ha : Ty.Annotation modelProgram [] [] (.dependentFn (.done a e))) (hn : a.Normal)
    (hc : m.ClosedAt 0 0) (had : m.Adequate σ) :
    StateTyE modelProgram modelBuiltins σ e (.run (Closure.pure m) [] Store.empty)

private def Returned (σ : PathEnv) (e : Eff) (m : Comp) (event : Option Event) (v : Val) : Prop :=
  Step modelProgram modelBuiltins σ (.run (Closure.pure m) [] Store.empty) event
    (.run (Closure.pure (.ret v)) [] Store.empty) ∧
  StateTyE modelProgram modelBuiltins σ e (.run (Closure.pure (.ret v)) [] Store.empty) ∧
  LocalStateInvariant modelProgram modelBuiltins σ (.run (Closure.pure (.ret v)) [] Store.empty)

private theorem pure_reply (σ : PathEnv) (hσ : σ.Valid) :
    Returned σ Eff.empty (call "Example.unit") none (.const .unit)

private theorem io_reply (σ : PathEnv) (hσ : σ.Valid) :
    Returned σ (Eff.single processEnvironmentEff) (call "Example.ioUnit")
      (some (.io "Example.ioUnit" [] (.val (.const .unit)) [])) (.const .unit)

private theorem external_reply (σ : PathEnv) (hσ : σ.Valid) :
    Returned σ Eff.empty (.externalCall (.mk 0) [] []) none (.const .unit)

private def atCode : Comp := .checkAt .path "Example.path" resultShape none
  (.scopePattern (.absolute .top)) (.const (.string "/")) (.fixed (.absolute .top))

private def atValue : Val := .con "Example.Ok" [.scoped "Example.path" .path (.fixed (.absolute .top)),atErrorType]
  [.checkedAt (.absolute .top) none (.path []) none]

private theorem at_admissible : AtCallAdmissible modelProgram modelBuiltins StoreTy.empty Qempty [] [] []
    .path "Example.path" resultShape none (.scopePattern (.absolute .top)) (.const (.string "/"))
    (.fixed (.absolute .top))

private theorem at_reply (σ : PathEnv) (hσ : σ.Valid) : Returned σ Eff.empty atCode none atValue

theorem concrete_normal_replies :
    ∃ σ, σ.Valid ∧ modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
      modelBuiltins.CoreAssumptions modelProgram ∧
      Returned σ Eff.empty (call "Example.unit") none (.const .unit) ∧
      Returned σ (Eff.single processEnvironmentEff) (call "Example.ioUnit")
        (some (.io "Example.ioUnit" [] (.val (.const .unit)) [])) (.const .unit) ∧
      Returned σ Eff.empty (.externalCall (.mk 0) [] []) none (.const .unit) ∧
      Returned σ Eff.empty atCode none atValue
```
