import Benitoite.Release.WellFormed

/-!
# 実行の規則（段階 B）

設計書 01-12 の「実行の規則」を、「初回リリース版の拡張」のストア、`escape`、`with`、プロセスの終了、
ハンドラの規則で広げたものを書き写す。構成子の名前は 01-12 の規則の名前に対応させる。

01-12 との表現の違い:

- E-Super は、値の等しさではなく、メソッドの呼び出しの辞書から `↑` を一段取り出す遷移として定める（01-12「型クラス」）。
- ストアは、場所から中身への関数とする。有限であることは、ストアの型付け（`StoreOk`）の条件にする。
- 組み込みの操作の E-Op は、規則 E-OpPrim として分けて書く。
- IO の事象は、組み込みの関数の名前、引数、応答からなり、型引数とエフェクト引数を含めない（01-12「実行の規則」）。
  応答の関係は、型引数とエフェクト引数も受け取る。
- `escape`、実行時エラーの状態、終了の状態が `drop κ` の枠を通るときの扱い（01-12「ハンドラ」の箇条）を、
  E-EscDrop・E-EscDropRel・E-ErrDrop・E-ErrDropRel・E-ExitDrop・E-ExitDropRel の規則として書く。
-/

namespace Benitoite.Release

/-- 継続の枠。 -/
inductive Frame where
  | letF (n : Comp)
  | mark
  | update (l : Nat)
  | release (v : Val)
  | handleF (h : List Clause)
  | drop (k : Nat)
  /-- ガードの結果を待つ。本体は束縛を置換済み。偽なら全体の next 番目から再開する。 -/
  | guardF (v : Val) (arms : List Arm) (next : Nat) (body : Comp)

abbrev Cont := List Frame

/-- ストアの中身。 -/
inductive Cell where
  | val (v : Val)
  | thunk (m : Comp)
  | done (v : Val)
  | cont (k : Cont)
  | used

abbrev Store := Nat → Option Cell

def Store.empty : Store := fun _ => none

def Store.set (σ : Store) (l : Nat) (c : Cell) : Store := fun l' => if l' = l then some c else σ l'

/-- 状態。 -/
inductive State where
  | run (m : Comp) (k : Cont) (σ : Store)
  | error (rs : List ErrKind) (k : Cont) (σ : Store)
  | exit (n : Int) (rs : List ErrKind) (k : Cont) (σ : Store)
  /-- 実行中だけの照合。分岐全体を保持し、next 番目から調べる。 -/
  | matchRun (v : Val) (arms : List Arm) (next : Nat) (k : Cont) (σ : Store)

/-- 事象。IO の事象 `b(W̄) ↦ …` と、解放の事象 `release(V) ↦ ok | error(r)`。 -/
inductive Event where
  | io (b : PrimName) (ws : List Val) (o : Outcome)
  | release (v : Val) (r : Option ErrKind)

/-- `mark ▷ K`。 -/
def markPush : Cont → Cont
  | .mark :: k => .mark :: k
  | k => .mark :: k

/-- `releases(K)`：K の中の `release` の枠と `drop` の枠だけを、順序を保って並べた継続。 -/
def releases : Cont → Cont
  | [] => []
  | .release v :: k => .release v :: releases k
  | .drop κ :: k => .drop κ :: releases k
  | _ :: k => releases k

/-- 節の並びから、操作 op の節を探す。 -/
def findClause (h : List Clause) (o : OpRef) : Option Clause :=
  h.find? (fun c => c.op == o)

/-- 継続の中に、操作 op の節を持つ `handle` の枠がない。 -/
def NoHandler (k : Cont) (o : OpRef) : Prop :=
  ∀ h, Frame.handleF h ∈ k → handles h o = false

/-- 状態が、継続のどの `handle` の枠も処理しない利用者の操作を呼ぶ。 -/
def UnhandledOp : State → Prop
  | .run (.app (.op o _) _) k _ => NoHandler k (.user o)
  | _ => False

/-- 継続を、op を処理する最も内側の `handle` の枠で分ける。`K = K1 ++ (handle □ with H) :: K2` で、
K1 の中の `handle` の枠はどれも op の節を持たない。 -/
def SplitAt (o : OpRef) (k k1 : Cont) (h : List Clause) (k2 : Cont) : Prop :=
  k = k1 ++ .handleF h :: k2 ∧ handles h o = true ∧ NoHandler k1 o

/-- 上位の型クラスの辞書の一歩の取り出し `V ⇝ V'`（E-Super）。`I[T̄](V̄)↑S ⇝ U[T̄/β̄][V̄/d̄]`（U は I の定義の
S の辞書）であり、`V ⇝ V'` なら `V↑S ⇝ V'↑S` である。 -/
def Val.superStep (P : Program) : Val → Option Val
  | .super (.dict i ts vs) s =>
      match P.impls i with
      | some id => (id.supers s).map fun u => (u.substTy ts []).instantiate vs
      | none => none
  | .super v s => (Val.superStep P v).map fun v' => .super v' s
  | _ => none

/-- 継続の二度目の再開の実行時エラーの種類 `r_resume`。 -/
def rResume : ErrKind := "ResumeTwice"

/-- 再開位置より前に、ガードのない照合可能な分岐はない。ガードの真偽は数えない。
型の付いた選択肢について、全体の網羅性とこの条件から、再開位置以降にもガードのない照合可能な分岐が残る。 -/
def MatchPrefix (v : Val) (arms : List Arm) (next : Nat) : Prop :=
  ∀ arm ∈ arms.take next, arm.guard = none → firstAlt v arm.alts = none

/-- 遷移。 -/
inductive Step (P : Program) (B : Builtins) : State → Option Event → State → Prop
  | E_Let {m n k σ} : Step P B (.run (.letIn m n) k σ) none (.run m (.letF n :: k) σ)
  | E_Return {v n k σ} :
      Step P B (.run (.ret v) (.letF n :: k) σ) none (.run (n.instantiate [v]) k σ)
  | E_Lam {ps body ws k σ} :
      ws.length = ps.length →
      Step P B (.run (.app (.lam ps body) ws) k σ) none (.run (body.instantiate ws) (markPush k) σ)
  | E_Fun {f ts es ws k σ d} :
      P.defs f = some d →
      ws.length = d.params.length → ts.length = d.ntys → es.length = d.neffs →
      Step P B (.run (.app (.fnRef f ts es) ws) k σ) none
        (.run ((d.body.substTy ts es).instantiate ws) (markPush k) σ)
  /-- E-Meth。メソッドの本体の型の変数は、メソッドの型パラメータ（番号 `0..g-1`）を S̄ に、実装の型パラメータを
  T̄ に置き換える。値の変数は、辞書の引数 d̄ を V̄ に、メソッドの引数 x̄ を W̄ に置き換える。 -/
  | E_Meth {i ts vs m ss es ws k σ id body cd ms} :
      P.impls i = some id → id.methods m = some body → P.classes id.cls = some cd →
      cd.methods m = some ms →
      ws.length = ms.params.length → vs.length = id.dictTys.length → ts.length = id.tparams.length →
      ss.length = ms.tparams.length → es.length = ms.neffs →
      Step P B (.run (.meth (.dict i ts vs) m ss es ws) k σ) none
        (.run ((body.substTy (ss ++ ts) es).instantiate (vs ++ ws)) (markPush k) σ)
  /-- E-Super。メソッドの呼び出しの辞書が上位の型クラスの辞書 `V↑S` のとき、`↑` を一段取り出す（01-12「型クラス」）。 -/
  | E_Super {v v' m ss es ws k σ} :
      v.superStep P = some v' →
      Step P B (.run (.meth v m ss es ws) k σ) none (.run (.meth v' m ss es ws) k σ)
  | E_IfT {m n k σ} :
      Step P B (.run (.ite (.const (.boolean true)) m n) k σ) none (.run m k σ)
  | E_IfF {m n k σ} :
      Step P B (.run (.ite (.const (.boolean false)) m n) k σ) none (.run n k σ)
  | E_Match {v arms k σ} :
      Step P B (.run (.match v arms) k σ) none (.matchRun v arms 0 k σ)
  | E_MatchSkip {v arms next alts guard body k σ} :
      arms[next]? = some (.mk alts guard body) → firstAlt v alts = none →
      Step P B (.matchRun v arms next k σ) none (.matchRun v arms (next + 1) k σ)
  | E_MatchBody {v arms next alts body ws k σ} :
      arms[next]? = some (.mk alts none body) → firstAlt v alts = some ws →
      Step P B (.matchRun v arms next k σ) none (.run (body.instantiate ws) k σ)
  | E_MatchGuard {v arms next alts guard body ws k σ} :
      arms[next]? = some (.mk alts (some guard) body) → firstAlt v alts = some ws →
      Step P B (.matchRun v arms next k σ) none
        (.run (guard.instantiate ws) (.guardF v arms (next + 1) (body.instantiate ws) :: k) σ)
  | E_GuardT {v arms next body k σ} :
      Step P B (.run (.ret (.const (.boolean true))) (.guardF v arms next body :: k) σ) none (.run body k σ)
  | E_GuardF {v arms next body k σ} :
      Step P B (.run (.ret (.const (.boolean false))) (.guardF v arms next body :: k) σ) none
        (.matchRun v arms next k σ)
  | E_ErrPopGuard {rs v arms next body k σ} :
      Step P B (.error rs (.guardF v arms next body :: k) σ) none (.error rs k σ)
  | E_ExitPopGuard {n rs v arms next body k σ} :
      Step P B (.exit n rs (.guardF v arms next body :: k) σ) none (.exit n rs k σ)
  | E_Prim {b ts es ws k σ s v} :
      B.sig b = some s → s.kind = .pure → B.delta b ts es ws = some (.val v) →
      Step P B (.run (.app (.prim b ts es) ws) k σ) none (.run (.ret v) k σ)
  | E_Err {b ts es ws k σ s r} :
      B.sig b = some s → s.kind = .pure → B.delta b ts es ws = some (.err r) →
      Step P B (.run (.app (.prim b ts es) ws) k σ) none (.error [r] k σ)
  /-- E-IO。組み込みの操作 b は、継続に b の節を持つ `handle` の枠がないときにだけ、E-IO を使う。 -/
  | E_IO {b ts es ws k σ s v} :
      B.sig b = some s → s.kind = .io → NoHandler k (.prim b) →
      B.ioResponse b ts es ws (.val v) →
      Step P B (.run (.app (.prim b ts es) ws) k σ) (some (.io b ws (.val v))) (.run (.ret v) k σ)
  /-- E-IOErr。プロセスの終了の関数の、引数が定義域の外のときの応答も `error(r)` である（01-12「プロセスの終了」）。 -/
  | E_IOErr {b ts es ws k σ s r} :
      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → NoHandler k (.prim b) →
      B.ioResponse b ts es ws (.err r) →
      Step P B (.run (.app (.prim b ts es) ws) k σ) (some (.io b ws (.err r))) (.error [r] k σ)
  /-- E-Exit。終了状態を指定したプロセスの終了の関数にだけ使う。 -/
  | E_Exit {b ts es ws k σ s n} :
      B.sig b = some s → s.kind = .exit → NoHandler k (.prim b) →
      B.ioResponse b ts es ws (.exit n) →
      Step P B (.run (.app (.prim b ts es) ws) k σ) (some (.io b ws (.exit n))) (.exit n [] k σ)
  -- ストア
  | E_RefNew {b ts es v k σ s l} :
      B.sig b = some s → s.kind = .refNew → σ l = none →
      Step P B (.run (.app (.prim b ts es) [v]) k σ) none (.run (.ret (.loc l)) k (σ.set l (.val v)))
  | E_RefGet {b ts es l k σ s v} :
      B.sig b = some s → s.kind = .refGet → σ l = some (.val v) →
      Step P B (.run (.app (.prim b ts es) [.loc l]) k σ) none (.run (.ret v) k σ)
  | E_RefSet {b ts es l v k σ s} :
      B.sig b = some s → s.kind = .refSet →
      Step P B (.run (.app (.prim b ts es) [.loc l, v]) k σ) none
        (.run (.ret (.const .unit)) k (σ.set l (.val v)))
  /-- `Reference.update[A](ℓ, V)` は `let x ⇐ Reference.get[A](ℓ) in let y ⇐ V(x) in Reference.set[A](ℓ, y)`
  と同じく遷移する。 -/
  | E_RefUpdate {b ts es l f k σ s} :
      B.sig b = some s → s.kind = .refUpdate →
      Step P B (.run (.app (.prim b ts es) [.loc l, f]) k σ) none
        (.run (.letIn (.app (.prim B.refGet ts []) [.loc l])
                (.letIn (.app (f.rename (· + 1)) [.var 0])
                  (.app (.prim B.refSet ts []) [.loc l, .var 0]))) k σ)
  | E_Lazy {m k σ l} :
      σ l = none →
      Step P B (.run (.lazyC m) k σ) none (.run (.ret (.loc l)) k (σ.set l (.thunk m)))
  | E_ForceDone {b ts es l k σ s v} :
      B.sig b = some s → s.kind = .force → σ l = some (.done v) →
      Step P B (.run (.app (.prim b ts es) [.loc l]) k σ) none (.run (.ret v) k σ)
  | E_Force {b ts es l k σ s m} :
      B.sig b = some s → s.kind = .force → σ l = some (.thunk m) →
      Step P B (.run (.app (.prim b ts es) [.loc l]) k σ) none (.run m (.update l :: k) σ)
  | E_Update {v l k σ} :
      Step P B (.run (.ret v) (.update l :: k) σ) none (.run (.ret v) k (σ.set l (.done v)))
  -- 関数の境界と `escape`
  | E_Mark {v k σ} : Step P B (.run (.ret v) (.mark :: k) σ) none (.run (.ret v) k σ)
  | E_EscLet {v n k σ} :
      Step P B (.run (.escape v) (.letF n :: k) σ) none (.run (.escape v) k σ)
  | E_EscHandle {v h k σ} :
      Step P B (.run (.escape v) (.handleF h :: k) σ) none (.run (.escape v) k σ)
  | E_EscMark {v k σ} : Step P B (.run (.escape v) (.mark :: k) σ) none (.run (.ret v) k σ)
  -- 解放の枠
  | E_Use {v m k σ} : Step P B (.run (.use v m) k σ) none (.run m (.release v :: k) σ)
  | E_Release {w v k σ} :
      B.releaseResponse v none →
      Step P B (.run (.ret w) (.release v :: k) σ) (some (.release v none)) (.run (.ret w) k σ)
  | E_RelErr {w v k σ r} :
      B.releaseResponse v (some r) →
      Step P B (.run (.ret w) (.release v :: k) σ) (some (.release v (some r))) (.error [r] k σ)
  | E_EscRel {w v k σ} :
      B.releaseResponse v none →
      Step P B (.run (.escape w) (.release v :: k) σ) (some (.release v none)) (.run (.escape w) k σ)
  | E_EscRelErr {w v k σ r} :
      B.releaseResponse v (some r) →
      Step P B (.run (.escape w) (.release v :: k) σ) (some (.release v (some r))) (.error [r] k σ)
  -- 実行時エラーの状態
  | E_ErrPopLet {rs n k σ} : Step P B (.error rs (.letF n :: k) σ) none (.error rs k σ)
  | E_ErrPopMark {rs k σ} : Step P B (.error rs (.mark :: k) σ) none (.error rs k σ)
  | E_ErrPopUpdate {rs l k σ} : Step P B (.error rs (.update l :: k) σ) none (.error rs k σ)
  | E_ErrPopHandle {rs h k σ} : Step P B (.error rs (.handleF h :: k) σ) none (.error rs k σ)
  | E_ErrRel {rs v k σ} :
      B.releaseResponse v none →
      Step P B (.error rs (.release v :: k) σ) (some (.release v none)) (.error rs k σ)
  | E_ErrRelErr {rs v k σ r} :
      B.releaseResponse v (some r) →
      Step P B (.error rs (.release v :: k) σ) (some (.release v (some r))) (.error (rs ++ [r]) k σ)
  -- プロセスの終了
  | E_ExitPopLet {n rs m k σ} : Step P B (.exit n rs (.letF m :: k) σ) none (.exit n rs k σ)
  | E_ExitPopMark {n rs k σ} : Step P B (.exit n rs (.mark :: k) σ) none (.exit n rs k σ)
  | E_ExitPopUpdate {n rs l k σ} : Step P B (.exit n rs (.update l :: k) σ) none (.exit n rs k σ)
  | E_ExitPopHandle {n rs h k σ} : Step P B (.exit n rs (.handleF h :: k) σ) none (.exit n rs k σ)
  | E_ExitRel {n rs v k σ} :
      B.releaseResponse v none →
      Step P B (.exit n rs (.release v :: k) σ) (some (.release v none)) (.exit n rs k σ)
  | E_ExitRelErr {n rs v k σ r} :
      B.releaseResponse v (some r) →
      Step P B (.exit n rs (.release v :: k) σ) (some (.release v (some r))) (.exit n (rs ++ [r]) k σ)
  -- ハンドラ
  | E_Handle {m h k σ} : Step P B (.run (.handle m h) k σ) none (.run m (.handleF h :: k) σ)
  | E_HRet {v h k σ} : Step P B (.run (.ret v) (.handleF h :: k) σ) none (.run (.ret v) k σ)
  /-- E-Op（利用者が宣言した操作）。節の本体に、操作の型引数の置き換えも施す。 -/
  | E_Op {o ts ws k σ k1 h k2 c κ} :
      SplitAt (.user o) k k1 h k2 → findClause h (.user o) = some c → σ κ = none →
      Step P B (.run (.app (.op o ts) ws) k σ) none
        (.run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ])) (.drop κ :: k2)
          (σ.set κ (.cont (k1 ++ [.handleF h]))))
  /-- E-Op（組み込みの操作）。継続に b の節を持つ `handle` の枠があるときは、E-IO の代わりに使う。 -/
  | E_OpPrim {b ts es ws k σ s k1 h k2 c κ} :
      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
      SplitAt (.prim b) k k1 h k2 → findClause h (.prim b) = some c → σ κ = none →
      Step P B (.run (.app (.prim b ts es) ws) k σ) none
        (.run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ])) (.drop κ :: k2)
          (σ.set κ (.cont (k1 ++ [.handleF h]))))
  | E_Resume {κ v k σ k'} :
      σ κ = some (.cont k') →
      Step P B (.run (.resume (.loc κ) v) k σ) none (.run (.ret v) (k' ++ k) (σ.set κ .used))
  | E_ResumeErr {κ v k σ} :
      σ κ = some .used →
      Step P B (.run (.resume (.loc κ) v) k σ) none (.error [rResume] k σ)
  | E_Drop {v κ k σ} :
      σ κ = some .used →
      Step P B (.run (.ret v) (.drop κ :: k) σ) none (.run (.ret v) k σ)
  | E_DropRel {v κ k σ k'} :
      σ κ = some (.cont k') →
      Step P B (.run (.ret v) (.drop κ :: k) σ) none
        (.run (.ret v) (releases k' ++ k) (σ.set κ .used))
  /-- `escape`、実行時エラーの状態、終了の状態が `drop κ` の枠を通るとき（01-12「ハンドラ」の箇条）。 -/
  | E_EscDrop {v κ k σ} :
      σ κ = some .used →
      Step P B (.run (.escape v) (.drop κ :: k) σ) none (.run (.escape v) k σ)
  | E_EscDropRel {v κ k σ k'} :
      σ κ = some (.cont k') →
      Step P B (.run (.escape v) (.drop κ :: k) σ) none
        (.run (.escape v) (releases k' ++ k) (σ.set κ .used))
  | E_ErrDrop {rs κ k σ} :
      σ κ = some .used → Step P B (.error rs (.drop κ :: k) σ) none (.error rs k σ)
  | E_ErrDropRel {rs κ k σ k'} :
      σ κ = some (.cont k') →
      Step P B (.error rs (.drop κ :: k) σ) none (.error rs (releases k' ++ k) (σ.set κ .used))
  | E_ExitDrop {n rs κ k σ} :
      σ κ = some .used → Step P B (.exit n rs (.drop κ :: k) σ) none (.exit n rs k σ)
  | E_ExitDropRel {n rs κ k σ k'} :
      σ κ = some (.cont k') →
      Step P B (.exit n rs (.drop κ :: k) σ) none (.exit n rs (releases k' ++ k) (σ.set κ .used))

inductive Steps (P : Program) (B : Builtins) : State → State → Prop
  | refl {s} : Steps P B s s
  | step {s l s' s''} : Step P B s l s' → Steps P B s' s'' → Steps P B s s''

/-- 実行を終えた状態。`⟨return V, [], σ⟩`、`error(r̄, [], σ)`、`exit(n, r̄, [], σ)`。 -/
def State.Final : State → Prop
  | .run (.ret _) [] _ => True
  | .error _ [] _ => True
  | .exit _ _ [] _ => True
  | _ => False

/-! ## 遷移を計算する関数 -/

/-- IO の応答を選ぶ関数（段階 A と同じく、同じ入力には同じ応答を返す）。 -/
abbrev Oracle := PrimName → List Ty → List Eff → List Val → Outcome

/-- 継続を、op を処理する最も内側の `handle` の枠で分ける。 -/
def splitHandler (o : OpRef) : Cont → Option (Cont × List Clause × Cont)
  | [] => none
  | .handleF h :: k =>
      if handles h o then some ([], h, k)
      else (splitHandler o k).map fun (k1, h', k2) => (.handleF h :: k1, h', k2)
  | f :: k => (splitHandler o k).map fun (k1, h', k2) => (f :: k1, h', k2)

/-- 解放の枠を一つ処理する遷移（`ret`・`escape`・実行時エラー・終了の状態で共通）。 -/
def releaseStep (rel : Val → Option ErrKind) (v : Val) (ok : State) (err : ErrKind → State) :
    Option (Option Event × State) :=
  match rel v with
  | none => some (some (.release v none), ok)
  | some r => some (some (.release v (some r)), err r)

/-- 一歩の遷移を計算する関数。IO の応答は `oracle`、解放の応答は `rel`、新しい場所は `fresh` から得る。
`step_sound`（`Theorems.lean`）で、`oracle`・`rel`・`fresh` が条件を満たすとき `Step` の遷移であることを示す。 -/
def step (P : Program) (B : Builtins) (oracle : Oracle) (rel : Val → Option ErrKind)
    (fresh : Store → Nat) : State → Option (Option Event × State)
  | .run (.letIn m n) k σ => some (none, .run m (.letF n :: k) σ)
  | .run (.ret v) (.letF n :: k) σ => some (none, .run (n.instantiate [v]) k σ)
  | .run (.ret v) (.mark :: k) σ => some (none, .run (.ret v) k σ)
  | .run (.ret v) (.update l :: k) σ => some (none, .run (.ret v) k (σ.set l (.done v)))
  | .run (.ret w) (.release v :: k) σ =>
      releaseStep rel v (.run (.ret w) k σ) (fun r => .error [r] k σ)
  | .run (.ret v) (.handleF _ :: k) σ => some (none, .run (.ret v) k σ)
  | .run (.ret v) (.drop κ :: k) σ =>
      match σ κ with
      | some .used => some (none, .run (.ret v) k σ)
      | some (.cont k') => some (none, .run (.ret v) (releases k' ++ k) (σ.set κ .used))
      | _ => none
  | .run (.ret (.const (.boolean true))) (.guardF _ _ _ body :: k) σ => some (none, .run body k σ)
  | .run (.ret (.const (.boolean false))) (.guardF v arms next _ :: k) σ =>
      some (none, .matchRun v arms next k σ)
  | .run (.ret _) (.guardF _ _ _ _ :: _) _ => none
  | .run (.ret _) [] _ => none
  | .run (.app (.lam ps body) ws) k σ =>
      if ws.length = ps.length then some (none, .run (body.instantiate ws) (markPush k) σ) else none
  | .run (.app (.fnRef f ts es) ws) k σ =>
      match P.defs f with
      | some d =>
          if ws.length = d.params.length ∧ ts.length = d.ntys ∧ es.length = d.neffs then
            some (none, .run ((d.body.substTy ts es).instantiate ws) (markPush k) σ)
          else none
      | none => none
  | .run (.app (.op o ts) ws) k σ =>
      match splitHandler (.user o) k with
      | some (k1, h, k2) =>
          match findClause h (.user o) with
          | some c =>
              let κ := fresh σ
              some (none, .run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ])) (.drop κ :: k2)
                (σ.set κ (.cont (k1 ++ [.handleF h]))))
          | none => none
      | none => none
  | .run (.app (.prim b ts es) ws) k σ =>
      match B.sig b with
      | none => none
      | some s =>
          match s.kind, ws with
          | .pure, _ =>
              match B.delta b ts es ws with
              | some (.val v) => some (none, .run (.ret v) k σ)
              | some (.err r) => some (none, .error [r] k σ)
              | _ => none
          | .io, _ | .exit, _ =>
              match splitHandler (.prim b) k with
              | some (k1, h, k2) =>
                  match findClause h (.prim b) with
                  | some c =>
                      let κ := fresh σ
                      some (none, .run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ]))
                        (.drop κ :: k2) (σ.set κ (.cont (k1 ++ [.handleF h]))))
                  | none => none
              | none =>
                  match s.kind, oracle b ts es ws with
                  | .io, .val v => some (some (.io b ws (.val v)), .run (.ret v) k σ)
                  | _, .err r => some (some (.io b ws (.err r)), .error [r] k σ)
                  | .exit, .exit n => some (some (.io b ws (.exit n)), .exit n [] k σ)
                  | _, _ => none
          | .refNew, [v] =>
              let l := fresh σ
              some (none, .run (.ret (.loc l)) k (σ.set l (.val v)))
          | .refGet, [.loc l] =>
              match σ l with
              | some (.val v) => some (none, .run (.ret v) k σ)
              | _ => none
          | .refSet, [.loc l, v] => some (none, .run (.ret (.const .unit)) k (σ.set l (.val v)))
          | .refUpdate, [.loc l, f] =>
              some (none, .run (.letIn (.app (.prim B.refGet ts []) [.loc l])
                (.letIn (.app (f.rename (· + 1)) [.var 0])
                  (.app (.prim B.refSet ts []) [.loc l, .var 0]))) k σ)
          | .force, [.loc l] =>
              match σ l with
              | some (.done v) => some (none, .run (.ret v) k σ)
              | some (.thunk m) => some (none, .run m (.update l :: k) σ)
              | _ => none
          | _, _ => none
  | .run (.app _ _) _ _ => none
  | .run (.meth (.dict i ts vs) m ss es ws) k σ =>
      match P.impls i with
      | some id =>
          match id.methods m, P.classes id.cls with
          | some body, some cd =>
              match cd.methods m with
              | some ms =>
                  if ws.length = ms.params.length ∧ vs.length = id.dictTys.length ∧
                      ts.length = id.tparams.length ∧ ss.length = ms.tparams.length ∧ es.length = ms.neffs then
                    some (none, .run ((body.substTy (ss ++ ts) es).instantiate (vs ++ ws)) (markPush k) σ)
                  else none
              | none => none
          | _, _ => none
      | none => none
  | .run (.meth v m ss es ws) k σ =>
      (v.superStep P).map fun v' => (none, .run (.meth v' m ss es ws) k σ)
  | .run (.ite (.const (.boolean true)) m _) k σ => some (none, .run m k σ)
  | .run (.ite (.const (.boolean false)) _ n) k σ => some (none, .run n k σ)
  | .run (.ite _ _ _) _ _ => none
  | .run (.match v arms) k σ => some (none, .matchRun v arms 0 k σ)
  | .matchRun v arms next k σ =>
      match arms[next]? with
      | none => none
      | some (.mk alts guard body) =>
          match firstAlt v alts with
          | none => some (none, .matchRun v arms (next + 1) k σ)
          | some ws =>
              match guard with
              | none => some (none, .run (body.instantiate ws) k σ)
              | some g => some (none, .run (g.instantiate ws)
                  (.guardF v arms (next + 1) (body.instantiate ws) :: k) σ)
  | .run (.lazyC m) k σ =>
      let l := fresh σ
      some (none, .run (.ret (.loc l)) k (σ.set l (.thunk m)))
  | .run (.escape v) (.letF _ :: k) σ => some (none, .run (.escape v) k σ)
  | .run (.escape v) (.handleF _ :: k) σ => some (none, .run (.escape v) k σ)
  | .run (.escape v) (.mark :: k) σ => some (none, .run (.ret v) k σ)
  | .run (.escape w) (.release v :: k) σ =>
      releaseStep rel v (.run (.escape w) k σ) (fun r => .error [r] k σ)
  | .run (.escape v) (.drop κ :: k) σ =>
      match σ κ with
      | some .used => some (none, .run (.escape v) k σ)
      | some (.cont k') => some (none, .run (.escape v) (releases k' ++ k) (σ.set κ .used))
      | _ => none
  | .run (.escape _) _ _ => none
  | .run (.use v m) k σ => some (none, .run m (.release v :: k) σ)
  | .run (.handle m h) k σ => some (none, .run m (.handleF h :: k) σ)
  | .run (.resume (.loc κ) v) k σ =>
      match σ κ with
      | some (.cont k') => some (none, .run (.ret v) (k' ++ k) (σ.set κ .used))
      | some .used => some (none, .error [rResume] k σ)
      | _ => none
  | .run (.resume _ _) _ _ => none
  | .error rs (.release v :: k) σ =>
      releaseStep rel v (.error rs k σ) (fun r => .error (rs ++ [r]) k σ)
  | .error rs (.drop κ :: k) σ =>
      match σ κ with
      | some .used => some (none, .error rs k σ)
      | some (.cont k') => some (none, .error rs (releases k' ++ k) (σ.set κ .used))
      | _ => none
  | .error rs (_ :: k) σ => some (none, .error rs k σ)
  | .error _ [] _ => none
  | .exit n rs (.release v :: k) σ =>
      releaseStep rel v (.exit n rs k σ) (fun r => .exit n (rs ++ [r]) k σ)
  | .exit n rs (.drop κ :: k) σ =>
      match σ κ with
      | some .used => some (none, .exit n rs k σ)
      | some (.cont k') => some (none, .exit n rs (releases k' ++ k) (σ.set κ .used))
      | _ => none
  | .exit n rs (_ :: k) σ => some (none, .exit n rs k σ)
  | .exit _ _ [] _ => none

/-- `step` を n 回まで続ける。 -/
def run (P : Program) (B : Builtins) (oracle : Oracle) (rel : Val → Option ErrKind)
    (fresh : Store → Nat) : Nat → State → List Event → State × List Event
  | 0, s, evs => (s, evs.reverse)
  | n + 1, s, evs =>
      match step P B oracle rel fresh s with
      | none => (s, evs.reverse)
      | some (none, s') => run P B oracle rel fresh n s' evs
      | some (some ev, s') => run P B oracle rel fresh n s' (ev :: evs)

/-! ## 継続とストアの型付け -/

/-- `R; ε ⊢k K : A ⇒ B ! ε0`（01-12「確かめる性質」）。最後の添字 `Rend` は、継続の末尾（空の継続）での
R である。ストアの継続の型付けで、末尾の `handle` の枠を κ を作った節の R で型付けすることを表すために使う。 -/
inductive ContTy (P : Program) (B : Builtins) (Ψ : StoreTy) :
    Option Ty → Eff → Cont → Ty → Ty → Eff → Option Ty → Prop
  | K_Empty {R ε a ε0} : Eff.Sub ε ε0 → Ty.WF 0 a → ContTy P B Ψ R ε [] a a ε0 R
  | K_Let {R ε n k a c b ε0 ε1 Re} :
      HasTypeC P B Ψ [] [some a] R n c ε1 → Eff.Sub ε1 ε → ContTy P B Ψ R ε k c b ε0 Re →
      ContTy P B Ψ R ε (.letF n :: k) a b ε0 Re
  | K_Mark {R' ε k a b ε0 Re} :
      ContTy P B Ψ R' ε k a b ε0 Re → Ty.WF 0 a → ContTy P B Ψ (some a) ε (.mark :: k) a b ε0 Re
  | K_Update {R ε l k a b ε0 Re} :
      Ψ l = some (.lazy a) → ContTy P B Ψ R ε k a b ε0 Re →
      ContTy P B Ψ none ε (.update l :: k) a b ε0 Re
  | K_Release {R ε v o k a b ε0 Re} :
      HasTypeV P B Ψ [] [] v (.opaque o) → B.isResource o = true → ε (.name stateEff) = true →
      ContTy P B Ψ R ε k a b ε0 Re → ContTy P B Ψ R ε (.release v :: k) a b ε0 Re
  /-- K-Handle。節は、枠の下の継続が許すエフェクトに含まれるエフェクト εc で検査する（01-12「確かめる性質」）。 -/
  | K_Handle {R ε εc h k t b ε0 Re} :
      ContTy P B Ψ R ε k t b ε0 Re → Eff.Sub εc ε → HasTypeClauses P B Ψ [] [] R h t εc →
      Ty.WF 0 t →
      ContTy P B Ψ R (Eff.union εc (handled P B h)) (.handleF h :: k) t b ε0 Re
  /-- K-Drop。捨てる継続の解放の枠を、この位置で実行できるように、κ の継続の型のエフェクトが `State` を
  含むなら、ε も `State` を含む（01-12「確かめる性質」）。 -/
  | K_Drop {R ε κ k a b ε0 Re b' t' ε' R'} :
      Ψ κ = some (.cont b' t' ε' R') → (ε' (.name stateEff) = true → ε (.name stateEff) = true) →
      ContTy P B Ψ R ε k a b ε0 Re →
      ContTy P B Ψ R ε (.drop κ :: k) a b ε0 Re
  /-- ガードは R = none、空のエフェクトで実行し、本体と再開先では元の R とエフェクトに戻る。 -/
  | K_Guard {R ε v arms next body k a b ε0 Re ε1} :
      HasTypeC P B Ψ [] [] R (.match v arms) a ε1 → Eff.Sub ε1 ε →
      MatchPrefix v arms next → HasTypeC P B Ψ [] [] R body a ε1 →
      ContTy P B Ψ R ε k a b ε0 Re →
      ContTy P B Ψ none Eff.empty (.guardF v arms next body :: k) (.base .boolean) b ε0 Re
  /-- K-Sub。継続が受け取る型を広げる（01-12「確かめる性質」）。 -/
  | K_Sub {R ε k a a' b ε0 Re} :
      ContTy P B Ψ R ε k a' b ε0 Re → Ty.Le a a' → ContTy P B Ψ R ε k a b ε0 Re

/-- 継続が `handle` の枠で終わる。 -/
def EndsWithHandle (k : Cont) : Prop := ∃ k1 h, k = k1 ++ [.handleF h]

/-- ストアの中身の型付け（01-12「確かめる性質」の箇条）。 -/
def CellOk (P : Program) (B : Builtins) (Ψ : StoreTy) (l : Nat) : Cell → Prop
  | .val v => ∃ a, Ψ l = some (.ref a) ∧ HasTypeV P B Ψ [] [] v a
  | .thunk m => ∃ a, Ψ l = some (.lazy a) ∧ HasTypeC P B Ψ [] [] none m a Eff.empty
  | .done v => ∃ a, Ψ l = some (.lazy a) ∧ HasTypeV P B Ψ [] [] v a
  | .cont k => ∃ b t ε r, Ψ l = some (.cont b t ε r) ∧ EndsWithHandle k ∧
      ∃ R' ε', ContTy P B Ψ R' ε' k b t ε r
  | .used => ∃ b t ε r, Ψ l = some (.cont b t ε r)

/-- ストアの場所の型は、型の変数を含まない。 -/
def LocTy.WF : LocTy → Prop
  | .ref a => Ty.WF 0 a
  | .lazy a => Ty.WF 0 a
  | .cont b t _ r => Ty.WF 0 b ∧ Ty.WF 0 t ∧ ∀ x, r = some x → Ty.WF 0 x

/-- ストアがストアの型付けに合う。ストアは有限であり、Ψ が型を与える場所には中身がある（`dom Ψ = dom σ`。
01-12「確かめる性質」）。 -/
def StoreOk (P : Program) (B : Builtins) (Ψ : StoreTy) (σ : Store) : Prop :=
  (∃ n, ∀ l, n ≤ l → σ l = none) ∧ (∀ l x, Ψ l = some x → x.WF) ∧
    (∀ l x, Ψ l = some x → σ l ≠ none) ∧
    (∀ l c, σ l = some c → CellOk P B Ψ l c)

/-- 継続の末尾で許すエフェクト Eb は、組み込みのエフェクトの名前の集合である。 -/
def BuiltinOnly (P : Program) (B : Builtins) (ε : Eff) : Prop :=
  ∀ a, ε a = true → ∃ l, a = .name l ∧ P.effects l = none ∧ (B.effects l).isSome

/-! ## 状態の中の項が閉じていること -/

def Frame.Closed : Frame → Prop
  | .letF n => Comp.VarsIn 0 (fun _ => True) n
  | .mark => True
  | .update _ => True
  | .release v => Val.VarsIn 0 (fun _ => True) v
  | .handleF h => Clause.VarsInList 0 (fun _ => True) h
  | .drop _ => True
  | .guardF v arms _ body => Val.VarsIn 0 (fun _ => True) v ∧
      Arm.VarsInList 0 (fun _ => True) arms ∧ Comp.VarsIn 0 (fun _ => True) body

def Cont.Closed (k : Cont) : Prop := ∀ f ∈ k, f.Closed

def Cell.Closed : Cell → Prop
  | .val v => Val.VarsIn 0 (fun _ => True) v
  | .thunk m => Comp.VarsIn 0 (fun _ => True) m
  | .done v => Val.VarsIn 0 (fun _ => True) v
  | .cont k => Cont.Closed k
  | .used => True

def Store.Closed (σ : Store) : Prop := ∀ l c, σ l = some c → c.Closed

/-! ## 状態の型付け -/

/-- 状態に型が付く（01-12「確かめる性質」の初回リリース版の状態の型付け）。継続の判断は、末尾の K-Empty を
`R = none` で使う導出で満たす（同節）。加えて、状態の中の項が型の変数を含まないこと
（`WellFormed.lean` の冒頭）を求める。 -/
def StateTy (P : Program) (B : Builtins) : State → Prop
  | .run m k σ => ∃ Ψ R a b ε ε1 Eb,
      StoreOk P B Ψ σ ∧ HasTypeC P B Ψ [] [] R m a ε1 ∧ Eff.Sub ε1 ε ∧
      ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
      Comp.VarsIn 0 (fun _ => True) m ∧ Cont.Closed k ∧ Store.Closed σ
  | .matchRun v arms next k σ => ∃ Ψ R a b ε ε1 Eb,
      StoreOk P B Ψ σ ∧ HasTypeC P B Ψ [] [] R (.match v arms) a ε1 ∧ Eff.Sub ε1 ε ∧
      ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
      Comp.VarsIn 0 (fun _ => True) (.match v arms) ∧ Cont.Closed k ∧ Store.Closed σ ∧
      MatchPrefix v arms next
  | .error _ k σ => ∃ Ψ R a b ε Eb,
      StoreOk P B Ψ σ ∧ ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
      Cont.Closed k ∧ Store.Closed σ
  | .exit _ _ k σ => ∃ Ψ R a b ε Eb,
      StoreOk P B Ψ σ ∧ ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
      Cont.Closed k ∧ Store.Closed σ

end Benitoite.Release
