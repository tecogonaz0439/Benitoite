# L10 群 W の完全署名と決定の記録

2026-11-01。指定ブランチは `m014/l10.w`、B_WORK は `d3a22dfb5dff5525888e4332e4bb978a4961074c`。git 操作をせず、起動依頼の値を使う。初回は本番への追加前に署名を固定して実装へ続けた。以下は RV-L10.w の修正を反映した最新の完全署名である。名前空間は `Benitoite.Release.Refinement` である。

## 補助の契約の判断

1. `Def.WellTyped` は承認済みの四条件を保つ。`TelBodyTy.done` が自分の結果型を return 契約として使う。Q の三等号は名前数の一致だけから証明し、NoFail を呼出し側へ要求しない。
2. Impl のクラス引数への型代入 `typeEnvAt g [target] []` と、辞書の個数だけの値移動を別々に行う。制約は `ms.tparams.map constraints ++ id.tparams`、辞書文脈は `bindParams [] (dictTys.map (Ty.shift g 0))` とする。メソッド・上位辞書の定義域は厳密一致である。実装の型パラメータは既存表現に従って value kind とする。
3. `Program.WellTyped` は variance/external/defs/impls の構造とする。同じ P の検証を射影でき、ValueMeaning・型付けから所属への定理を信頼する欄を作らない。
4. `SourceScoped` は型・行・範囲・値の上限を構文で再帰検査する。実行時専用の値と局所の場所は拒否し、依存列・let・lambda・腕・節の束縛を数える。範囲式には既存の WF/Canonical、型には既存の WF/RowsIn を使う。型付けの条件をこの判断から導く主張はしない。
5. 宣言の依存列は `SignatureScoped` に WF/RowsIn/HasKind/Annotation を集める。Annotation が順に拡張する文脈で注釈を検査する。別に本体の SourceScoped を検査する。PrimSig.Scoped と sig_scoped は G08 に残し、重複する信頼欄を作らない。
6. MetadataScoped は some の格納済み項目、列の長さ、同名構成子の arity、requirements と publicBoundary の型の WF/RowsIn/Annotation/kind を検査する。dataInfo=none の場合はその項目への全称条件、空 requirements/publicBoundary はその列への全称条件だけが空に成り立つ。対応する構成子がない metadata の同名 arity の全称も空に成り立つ。構成子の欄の変性と形成、存在する同名構成子の arity の検査は残る。原ソースとの一致は主張しない。辞書制約・公開境界の収集と変性の一致は L70/R10b の Lean の外の照合である。
7. 主な定理の subst/subst_under_none/shift_values/shift_types/narrow の結論、公理、提供範囲、利用者が書ける形、精密な外部状態を変えない。

## 本番に置く完全署名・定義

署名だけでなく各条件を以下に示す。証明の局所的な書換えは条件の変更と区別する。

### ProgramTyping.lean

```lean
import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.VarianceValidation

/-! # 定義・実装・プログラムの型付け（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 依存列と非依存の呼出し側で、同じ行変数の条件を読む。 -/
theorem QTel_signatureTel (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : NamesWF ns ps) :
    QTel (signatureTel ns ps r e) = Qsig ps r e := by
  induction ns generalizing ps with
  | nil =>
    have hp : ps = [] := List.eq_nil_of_length_eq_zero hn.1.symm
    subst ps
    funext i
    apply propext
    simp [signatureTel, QTel, Qsig, QTys, Qempty]
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hns : NamesWF ns ps := ⟨by simpa using hn.1, hn.2.tail⟩
      funext i
      apply propext
      simp only [signatureTel, QTel, ih ps hns, Qsig, QTys]
      exact or_assoc.symm

theorem Def.QTel_eq_Qsig (d : Def) (hn : NamesWF d.names d.params) :
    QTel d.tel = Qsig d.params d.ret d.eff :=
  QTel_signatureTel d.names d.params d.ret d.eff hn

theorem MethSig.QTel_eq_Qsig (ms : MethSig) (hn : NamesWF ms.names ms.params) :
    QTel ms.tel = Qsig ms.params ms.ret ms.eff :=
  QTel_signatureTel ms.names ms.params ms.ret ms.eff hn

/-- 各引数を順に束縛し、done の結果型を return 契約にする。 -/
def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  Ty.HasKind P (d.tparams.map TParamDecl.kind) (.dependentFn d.tel) .value ∧
  Ty.Annotation P (d.tparams.map TParamDecl.constraints) [] (.dependentFn d.tel) ∧
  TelBodyTy P B StoreTy.empty (QTel d.tel)
    (d.tparams.map TParamDecl.constraints) [] [] d.tel d.body

/-- 型クラスの引数の型代入の後、実装の辞書の個数だけ値参照を移す。 -/
def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (List.replicate id.tparams.length .value) id.target cd.argumentKind ∧
    TypeAnnotations P id.tparams [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := ms.tparams.map TParamDecl.constraints ++ id.tparams
      let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
      let t' := Tel.shiftV id.dictTys.length 0 t
      TelBodyTy P B StoreTy.empty (QTel ms.tel) C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty id.tparams (bindParams [] id.dictTys) []
        u (.dict s id.target))

/-- 呼出し規則 C-Meth が読む代入前の Qsig で、実装の本体を取り出す。 -/
theorem ImplDecl.WellTyped.method_body {P : Program} {B : Builtins} {id : ImplDecl}
    (h : id.WellTyped P B) {cd : ClassDecl} {m : MethName} {ms : MethSig}
    (hc : P.classes id.cls = some cd) (hm : cd.methods m = some ms) :
    ∃ body, id.methods m = some body ∧ NamesWF ms.names ms.params ∧
      TelBodyTy P B StoreTy.empty (Qsig ms.params ms.ret ms.eff)
        (ms.tparams.map TParamDecl.constraints ++ id.tparams)
        (bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))) []
        (Tel.shiftV id.dictTys.length 0
          (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel)) body := by
  obtain ⟨cd', hc', _, _, _, _, hb, _⟩ := h
  have he : cd' = cd := Option.some.inj (hc'.symm.trans hc)
  subst cd'
  obtain ⟨body, hbody, hn, ht⟩ := hb m ms hm
  exact ⟨body, hbody, hn, by simpa only [ms.QTel_eq_Qsig hn] using ht⟩

/-- 変性と外部宣言の構造検証を、全 lookup の本体の型付けと同じ P に対して要求する。 -/
structure Program.WellTyped (P : Program) (B : Builtins) : Prop where
  variance : P.VarianceValid
  external : P.ExternalWF
  defs : ∀ f d, P.defs f = some d → Def.WellTyped P B d
  impls : ∀ i id, P.impls i = some id → ImplDecl.WellTyped P B id

end
end Benitoite.Release.Refinement
```

### ProgramWellFormed.lean

```lean
import Benitoite.Release.Refinement.ProgramTyping
import Benitoite.Release.Refinement.Context.WF
import Benitoite.Release.Refinement.Source

/-! # 格納された宣言の適格性（設計書 07-04「01-12 との対応」） -/
namespace Benitoite.Release.Refinement
noncomputable section

/- Eff.WF は Fail の型だけを読むため、効果原子の範囲添字を別に検査する。 -/
mutual
  def Ty.RangesScoped (nr : Nat) : Ty → Prop
    | .opaque _ ix | .scoped _ _ ix => ix.WF nr
    | .data _ as | .tapp _ as | .external _ as => rangesScopedTypes nr as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => a.RangesScoped nr
    | .map a b => a.RangesScoped nr ∧ b.RangesScoped nr
    | .fn _ ps r e => rangesScopedTypes nr ps ∧ r.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .cont a b e => a.RangesScoped nr ∧ b.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .dependentFn t => t.RangesScoped nr
    | _ => True
  def Tel.RangesScoped (nr : Nat) : Tel → Prop
    | .done a e => a.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .param _ a t => a.RangesScoped nr ∧ t.RangesScoped nr
  def Eff.RangesScoped (nr : Nat) : Eff → Prop
    | .mk atoms fs => (∀ name ix, atoms (.name name ix) = true → ix.WF nr) ∧ rangesScopedTypes nr fs
  def rangesScopedTypes (nr : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.RangesScoped nr ∧ rangesScopedTypes nr as
end

/-- 四名前空間のうち、型注釈に現れる範囲・型・値と、行変数の上限。 -/
def Ty.SourceScoped (nr nt ne nv : Nat) (a : Ty) : Prop :=
  a.WF nr nt nv ∧ a.RowsIn (· < ne) ∧ a.RangesScoped nr

def Eff.SourceScoped (nr nt ne nv : Nat) (e : Eff) : Prop :=
  e.WF nr nt nv ∧ e.RowsIn (· < ne) ∧ Eff.RangesScoped nr e

def BuilderKind.SourceScoped (nr nt ne nv : Nat) : BuilderKind → Prop
  | .list a => a.SourceScoped nr nt ne nv
  | .string | .bytes => True

mutual
  /-- ソースの値構文だけを受け入れ、束縛位置で各名前空間の深さを増やす。 -/
  def Val.SourceScoped (nr nt ne nv : Nat) : Val → Prop
    | .var i => i < nv
    | .const _ | .bytesV _ => True
    | .fnRef _ ts es => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es
    | .prim _ ts es rs => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es ∧
        (∀ r ∈ rs, r.WF ∧ r.Canonical)
    | .lam ns ps body => NamesWF ns ps ∧ scopedTypes nr nt ne nv ps ∧
        body.SourceScoped nr nt ne (nv + ps.length)
    | .dependentLam t body => (Ty.dependentFn t).SourceScoped nr nt ne nv ∧
        body.SourceScoped nr nt ne (nv + telBinders t)
    | .con _ ts vs | .dict _ ts vs => scopedTypes nr nt ne nv ts ∧ scopedValues nr nt ne nv vs
    | .list vs | .setV vs => scopedValues nr nt ne nv vs
    | .op _ ts | .externalRef _ ts => scopedTypes nr nt ne nv ts
    | .raise a e => a.SourceScoped nr nt ne nv ∧ e.SourceScoped nr nt ne nv
    | .mapV ks vs => scopedValues nr nt ne nv ks ∧ scopedValues nr nt ne nv vs
    | .super v _ => v.SourceScoped nr nt ne nv
    | .scopePattern r => r.WF ∧ r.Canonical
    | .closure _ _ | .loc _ | .externalHandle _ _ | .pathBases _ |
        .checkedAt _ _ _ _ | .atError _ | .checked _ | .checkedRequest _ _ => False
  def scopedValues (nr nt ne nv : Nat) : List Val → Prop
    | [] => True
    | v :: vs => v.SourceScoped nr nt ne nv ∧ scopedValues nr nt ne nv vs
  def Comp.SourceScoped (nr nt ne nv : Nat) : Comp → Prop
    | .builderLet k m => k.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne (nv+1)
    | .builderOp k _ r vs => k.SourceScoped nr nt ne nv ∧
        (match r with | .bound i => i < nv | .loc _ => False) ∧ scopedValues nr nt ne nv vs
    | .ret v | .escape v => v.SourceScoped nr nt ne nv
    | .letIn m n => m.SourceScoped nr nt ne nv ∧ n.SourceScoped nr nt ne (nv+1)
    | .app v vs => v.SourceScoped nr nt ne nv ∧ scopedValues nr nt ne nv vs
    | .ite v m n => v.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne nv ∧ n.SourceScoped nr nt ne nv
    | .match v arms => v.SourceScoped nr nt ne nv ∧ scopedArms nr nt ne nv arms
    | .lazyC m => m.SourceScoped nr nt ne nv
    | .use v m => v.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne nv
    | .handle m cs => m.SourceScoped nr nt ne nv ∧ scopedClauses nr nt ne nv cs
    | .resume k v => k.SourceScoped nr nt ne nv ∧ v.SourceScoped nr nt ne nv
    | .externalCall _ ts vs => scopedTypes nr nt ne nv ts ∧ scopedValues nr nt ne nv vs
    | .issuePathBases _ => False
    | .checkAt _ _ sh bs p v ix => sh.errorType.SourceScoped nr nt ne nv ∧ ix.WF nr ∧
        (match bs with | none => True | some b => b.SourceScoped nr nt ne nv) ∧
        p.SourceScoped nr nt ne nv ∧ v.SourceScoped nr nt ne nv
    | .meth d _ ts es vs => d.SourceScoped nr nt ne nv ∧ scopedTypes nr nt ne nv ts ∧
        scopedRows nr nt ne nv es ∧ scopedValues nr nt ne nv vs
  def scopedArms (nr nt ne nv : Nat) : List Arm → Prop
    | [] => True
    | .mk alts guard body :: arms =>
        (match guard with | none => True | some g => g.SourceScoped nr nt ne (nv + Benitoite.Release.Arm.bindersOf alts)) ∧
        body.SourceScoped nr nt ne (nv + Benitoite.Release.Arm.bindersOf alts) ∧ scopedArms nr nt ne nv arms
  def scopedClauses (nr nt ne nv : Nat) : List Clause → Prop
    | [] => True
    | .mk _ arity k body :: cs => body.SourceScoped nr (nt+k) ne (nv+arity+1) ∧ scopedClauses nr nt ne nv cs
    | .fail e body :: cs => e.SourceScoped nr nt ne nv ∧
        body.SourceScoped nr (nt+1) ne (nv+2) ∧ scopedClauses nr nt ne nv cs
  def scopedTypes (nr nt ne nv : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.SourceScoped nr nt ne nv ∧ scopedTypes nr nt ne nv as
  def scopedRows (nr nt ne nv : Nat) : List Eff → Prop
    | [] => True
    | e :: es => e.SourceScoped nr nt ne nv ∧ scopedRows nr nt ne nv es
end

/-- WF は依存列内の深さを増やし、Annotation は参照順序・sort・宣言を同時に読む。 -/
def SignatureScoped (P : Program) (C : List TParam) (K : KindCtx) (ne : Nat) (t : Tel) : Prop :=
  (Ty.dependentFn t).SourceScoped 0 K.length ne 0 ∧ t.RowsIn (· < ne) ∧
    Ty.HasKind P K (.dependentFn t) .value ∧ Ty.Annotation P C [] (.dependentFn t)

def Def.Scoped (P : Program) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
    SignatureScoped P (d.tparams.map TParamDecl.constraints) (d.tparams.map TParamDecl.kind) d.neffs d.tel ∧
    d.body.SourceScoped 0 d.ntys d.neffs d.params.length

def ConDecl.Scoped (P : Program) (cd : ConDecl) : Prop :=
  ∀ a ∈ cd.args, a.SourceScoped 0 cd.ntys 0 0 ∧
    Ty.Annotation P (List.replicate cd.ntys ({} : TParam)) [] a ∧
    Ty.HasKind P (List.replicate cd.ntys .value) a .value

def OpDecl.Scoped (P : Program) (od : OpDecl) : Prop :=
  NamesWF od.names od.params ∧
    (∀ p ∈ od.dictParams, p.2 < od.tparams.length) ∧
    od.params.take od.dictParams.length = od.dictParams.map (fun p => .dict p.1 (.tvar p.2)) ∧
    SignatureScoped P od.tparams (List.replicate od.tparams.length .value) 0 od.tel

def MethSig.Scoped (P : Program) (argumentKind : TyKind) (ms : MethSig) : Prop :=
  NamesWF ms.names ms.params ∧
    SignatureScoped P (ms.tparams.map TParamDecl.constraints ++ [({} : TParam)])
      (ms.tparams.map TParamDecl.kind ++ [argumentKind]) ms.neffs ms.tel

def ClassDecl.Scoped (P : Program) (cl : ClassDecl) : Prop :=
  ∀ m ms, cl.methods m = some ms → ms.Scoped P cl.argumentKind

def ImplDecl.Scoped (P : Program) (id : ImplDecl) : Prop :=
  (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
    id.target.SourceScoped 0 id.tparams.length 0 0 ∧
    Ty.Annotation P id.tparams [] id.target ∧
    TypeAnnotations P id.tparams [] id.dictTys ∧
    (∀ a ∈ id.dictTys, a.HasKind P (List.replicate id.tparams.length .value) .value) ∧
    (∀ s u, id.supers s = some u → u.SourceScoped 0 id.tparams.length 0 id.dictTys.length) ∧
    (∀ cd m ms body, P.classes id.cls = some cd → cd.methods m = some ms → id.methods m = some body →
      body.SourceScoped 0 (ms.tparams.length + id.tparams.length) ms.neffs (id.dictTys.length + ms.params.length))

/-- 格納済み metadata の検査。原ソースからの収集の完全性を表さない。 -/
def Program.MetadataScoped (P : Program) : Prop :=
  ∀ d info, P.dataInfo d = some info →
    info.variances.length = info.arity ∧
    (∀ c cd, P.cons c = some cd → cd.data = d → cd.ntys = info.arity) ∧
    (∀ a ∈ info.requirements ++ info.publicBoundary.map Prod.snd,
      a.SourceScoped 0 info.arity 0 0 ∧
      Ty.Annotation P (List.replicate info.arity ({} : TParam)) [] a ∧
      Ty.HasKind P (List.replicate info.arity .value) a .value)

structure Program.WellFormed (P : Program) : Prop where
  defs : ∀ f d, P.defs f = some d → d.Scoped P
  cons : ∀ c cd, P.cons c = some cd → P.DataArity cd.data cd.ntys ∧ cd.Scoped P
  ops : ∀ o od, P.ops o = some od → od.Scoped P
  classes : ∀ cl cd, P.classes cl = some cd → cd.Scoped P
  impls : ∀ i id, P.impls i = some id → id.Scoped P
  metadata : P.MetadataScoped
  external : P.ExternalWF

end
end Benitoite.Release.Refinement
```

## 境界の作成時の関門

持ち主は本番の Program.WellTyped/WellFormed である。非空の metadata と constructor、関数、method を持つ class/impl を共有し、条件を削った場合の受理の拡大を負例で検出する。既存の V/X の例はまだこの二つの入口を持たず、この義務を捕まえない。本番の定義を複製せず、テスト専用の差し込み口を作らない。Q の例は行と Fail を持つ署名を含める。これは構成子一覧をなぞる検査ではなく、定義から利用先への受渡しを確かめる境界である。

## 補助契約の補足（境界例の作成時）

既存の Eff.WF は Fail の型だけを検査し、name 原子の範囲添字を読まない。このため RangesScoped の相互再帰を追加し、SourceScoped と SignatureScoped に接続した。型付けや主な定理の前提を変えず、承認済みの WellFormed の四名前空間の範囲検査を具体化したものである。

## RV-L10.w の処置の判断（2026-11-01）

中1は計画の最新の承認に従い、メソッドの Q を代入前の QTel ms.tel とする。method_body は同じ NamesWF で C_Meth の Qsig に直して全ての本体の入力を取り出す。本体の C・辞書文脈・型代入・値移動は変更しない。軽1は ImplDecl.Scoped に辞書型の kind を要求し、WellTyped の信頼欄を増やさない。軽2は操作の辞書の並びと params の先頭の一致を検査する案を採用する。軽3の公開境界の行変数の扱いと、軽4のソース構文だけの埋め込みの入力は改造の送り先へ記録する。閉じた署名で値移動が恒等になることと、任意の WellTyped の補助契約で同じ操作を取り出すことを境界の説明で区別する。

境界の作成時の関門の追加: 初回の引数だけを返す例は辞書・C・Q を検査していなかった。今回の持ち主は WellTyped の本体の取り出しと、その本体の型付けである。辞書を返す例と辞書経由の C_Meth、異なる二制約を読む sat、Admissible の NoFail が Q を読む本体を追加する。変異は手書きの代替の定義を本番へ置かず、本番の一時コピーへ一変更ずつ適用して実際の Lean に検査させる。NoValueMove は閉じたソース署名だけでは区別できないため、任意の WellTyped から同じ移動後の本体を取り出す method_body の補助契約で検出する。
