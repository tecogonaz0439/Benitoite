# L2a: Fail捕捉の定義・言明・仮定

## 状態と現在の表現

基準Bは `3f599141daee721d3a44cdee3163de2e2da71b05`（L1d取り込み済み）である。本書はL2b/cで実装・証明する契約をレビューする文書である。正式な `formal/`、01-12と07-04の写しは変更しない。コード片の `…Goal : Prop` は証明すべき命題の定義であり、その命題の証明でも公理でもない。帰納的な判断のコード片は追加・変更する構成子の抜粋であり、単独のLeanファイルとしてコンパイルするものではない。省略した既存構成子は同じQを前提と結論へ渡す。

[L1bの完了記録](../l1b/results.md#l1bc7-表現bの正式な接続とl1bの完了)、[L1cの完了記録](../l1c/results.md#l1cc2-検査器の接続とl1cの完了)、[L1dの結果](../l1d/results.md)、[R36〜R45](../decisions.md#r36-表層で構築変換する型の整形式)を前提とする。[L0の下書き](../l0/statements.md)のL2部分は本書で具体化する。L0の記録自体は書き換えない。

現在の型は相互帰納的な `Ty` と `EffR.mk (atoms : Atom → Bool) (fails : List Ty)` である。FailはAtomの構成子ではない。`Eff.mem` は名前・行の所属、`Eff.memFail e E` は正規化したエラー型の所属を表す。`Eff.singleFail`・`union`・`substAt c ts es`・`shift k c` は型内部も正規化する。`Ty.WF`・`VarsIn`・`Eff.RhosIn`はFail内部まで辿り、型内部の効果にはCanonicalを要求する。最上位の計算の効果には要求しない。

L1cの検査器は `normWith` と再帰的な有限支持を使い、Legacyの一時的な拒否を撤去済みである。名前・行の関数を有限集合へ狭めず、支持外の原子を捨てない。L1dの旧交換の比較は列を正規化する。L0にあった「旧入力だからLegacyを要求して比較する」という接続を新しい規則の前提へ戻さない。

以下の数学上の定義は `Benitoite.Release` 内を想定する。`Q` はNoFailと分かっている行の番号の述語であり、既存のcheckerの設定変数 `q` とは別物である。選択の比較と理由は[decisions.mdのR46〜R50](../decisions.md#r46-l2aのqを判断の添字に置く案)に記す。

## Qsig・NoFail・許容される代入

### シグネチャ全体からのQ

Qsigは宣言した型の字面だけを辿る。各usesに明示のFailがあれば、そのusesの最外の行を集め、Failのエラー型の内部も再帰する。型の全構成子を次のように扱う。入れ子のfn/contは新しい行の束縛を導入しないので、行番号をずらさない。

```lean
abbrev NoFailCtx := Nat → Prop
def Qempty : NoFailCtx := fun _ => False
def QLe (Q Q' : NoFailCtx) : Prop := ∀ i, Q i → Q' i

mutual
  def QTy : Ty → NoFailCtx
    | .base _ | .opaque _ | .tvar _ | .bytes | .ctor _ => Qempty
    | .data _ as | .tapp _ as => QTys as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => QTy a
    | .map a b => fun i => QTy a i ∨ QTy b i
    | .fn _ ps r e => fun i => QTys ps i ∨ QTy r i ∨ QEff e i
    | .cont a b e => fun i => QTy a i ∨ QTy b i ∨ QEff e i
  def QTys : List Ty → NoFailCtx
    | [] => Qempty
    | t :: ts => fun i => QTy t i ∨ QTys ts i
  def QEff : Eff → NoFailCtx
    | .mk atoms fs => fun i =>
        (fs ≠ [] ∧ atoms (.rho i) = true) ∨ QTys fs i
end

def Qsig (ps : List Ty) (ret : Ty) (e : Eff) : NoFailCtx :=
  fun i => QTys ps i ∨ QTy ret i ∨ QEff e i

def NoFail (Q : NoFailCtx) (e : Eff) : Prop :=
  e.fails = [] ∧ ∀ i, Eff.mem e (.rho i) → Q i

def QsigScopedGoal : Prop :=
  ∀ ps ret e nt ne,
    Ty.VarsInList nt (· < ne) ps → Ty.VarsIn nt (· < ne) ret →
    Eff.VarsIn nt (· < ne) e → ∀ i, Qsig ps ret e i → i < ne
```

Qsigに本体・相互再帰の不動点・実装本体の条件を加えない。Defは `Qsig d.params d.ret d.eff`、PrimSigも同じ三欄、MethSigはクラスが宣言した三欄を使う。実装の対象型を代入した後にQsigを取り直して条件を強めることはしない。通常の操作は行パラメータを持たず、宣言の範囲条件からQsigは空になる。Failの操作の署名自体も行パラメータを持たない。

数学上のQは述語とする。任意のReleaseの効果の有限支持を仮定する必要がないためである。Surfaceの計算用Qは宣言の `neffs` 個のBoolとし、各位置をこの述語と照合する。QsigScopedGoalの前提は宣言の既存の範囲検査から得る。NoFailは最外の効果だけの条件であり、例えば行の像が持つ型の中の潜在Failは禁じない。

### 全行の具体化と型束縛下での代入

署名の全行を具体化するAdmissibleと、既存の型代入補題で行を残す場合の条件を分ける。後者では範囲外の行を残す `Eff.rowImage es i` の現在の意味を明示する。全行の具体化の範囲不足を、その残存で見逃すことはしない。

```lean
def RowTransport (Qs Qt : NoFailCtx) (es : List Eff) : Prop :=
  ∀ i, Qs i → NoFail Qt (Eff.rowImage es i)

structure Admissible (B : Builtins) (C : List TParam)
    (tps : List TParam) (ne : Nat) (Qs Qt : NoFailCtx)
    (ts : List Ty) (es : List Eff) (e : Eff) : Prop where
  types : SatAll B C ts tps
  typeScope : ∀ t ∈ ts, Ty.WF C.length t ∧ ∀ b r e, t ≠ .cont b r e
  rowCount : es.length = ne
  rowScope : ∀ f ∈ es, Eff.WF C.length f
  sourceRows : Eff.RhosIn (· < es.length) e
  sourceQ : ∀ i, Qs i → i < es.length
  noFailRows : RowTransport Qs Qt es

def NoFailSubstGoal : Prop :=
  ∀ B C tps ne Qs Qt ts es e,
    Admissible B C tps ne Qs Qt ts es e → NoFail Qs e →
    NoFail Qt (Eff.substAt 0 ts es e)

def NoFailSubstAtGoal : Prop :=
  ∀ Qs Qt c ts es e, RowTransport Qs Qt es → NoFail Qs e →
    NoFail Qt (Eff.substAt c ts es e)

def NoFailLawsGoal : Prop :=
  (∀ Q e, NoFail Q (Eff.norm e) ↔ NoFail Q e) ∧
  (∀ Q e k c, NoFail Q e → NoFail Q (Eff.shift k c e)) ∧
  (∀ Q e f, NoFail Q e → NoFail Q f → NoFail Q (Eff.union e f)) ∧
  (∀ Q Q' e, QLe Q Q' → NoFail Q e → NoFail Q' e) ∧
  (∀ Q e E, NoFail Q e → ¬ Eff.memFail e E) ∧
  (∀ e, NoFail Qempty e →
    e.fails = [] ∧ ∀ i, ¬ Eff.mem e (.rho i))

def RowTransportComposeScopedGoal : Prop :=
  ∀ Q0 Q1 Q2 es es' c ts',
    (∀ i, Q0 i → i < es.length) →
    RowTransport Q0 Q1 es → RowTransport Q1 Q2 es' →
    RowTransport Q0 Q2 (es.map (Eff.substAt c ts' es'))
```

列のmapによるRowTransportの合成には、Q0の行がすべて最初のesの範囲内にある条件を付ける。範囲外の行を残す一般の合成には、既存のSubstEnv.composeと行の像ごとの合成の補題を使う。

Admissible.sourceRowsはFail型の内部の行も覆う既存のEff.RhosInである。型・署名全体の範囲は、既存のScoped/VarsInから別に渡す。Admissibleは型引数の通常の制約も保持する。組み込みの `.admits` は既存のV_Primと同じく別途要求し、Builtins.AssumptionsにNoFailの新しい欄を追加しない。

型の束縛だけを一つ増やす節ではQは変わらない。es=[]のRowTransportは `QLe Qs Qt` に等しく、Qt=Qsで使える。閉じた全具体化ではQt=Qemptyにし、NoFailとマークした行の像に最外のFailも行も残らないことを呼び出しの型付けから得る。型の像や行の像の内部の効果にCanonicalが必要な位置は、既存の型操作の正規化とWFから導く。

## 判断にQを置く位置と代入の言明

### 採る判断と閉じた入口

Qを六つの相互帰納的な判断のパラメータに加える（RV2-L2a中2、R53）。以下ではQ付きの内部の名前を `HasTypeVQ` 等とし、従来の名前はQemptyでの別名として保つ。これにより主な定理の閉じた入口の型は保てる。定義本体・メソッド本体とその内部の補題はQ付きの判断を直接使う。PやBuiltinsの定義表へQの公理的な欄は加えない。

```lean
-- QはP・B・Ψと同じパラメータとし、各構成子で一定である。
-- 例: inductive HasTypeVQ (P : Program) (B : Builtins)
--       (Ψ : StoreTy) (Q : NoFailCtx) :
--       List TParam → List (Option Ty) → Val → Ty → Prop
-- HasTypeVQ       P B Ψ Q C Γ v a                 : Prop
-- HasTypeVsQ      P B Ψ Q C Γ vs as               : Prop
-- HasTypeEachQ    P B Ψ Q C Γ vs a                : Prop
-- HasTypeCQ       P B Ψ Q C Γ R m a e             : Prop
-- HasTypeArmsQ    P B Ψ Q C Γ R arms a b e        : Prop
-- HasTypeClausesQ P B Ψ Q C Γ R clauses t e      : Prop
-- HasFailureClause P B Ψ Q C Γ E R clauses t ec : Prop

abbrev HasTypeC (P : Program) (B : Builtins) (Ψ : StoreTy) :=
  HasTypeCQ P B Ψ Qempty
abbrev HasTypeV (P : Program) (B : Builtins) (Ψ : StoreTy) :=
  HasTypeVQ P B Ψ Qempty
abbrev HasTypeVs (P : Program) (B : Builtins) (Ψ : StoreTy) :=
  HasTypeVsQ P B Ψ Qempty
abbrev HasTypeEach (P : Program) (B : Builtins) (Ψ : StoreTy) :=
  HasTypeEachQ P B Ψ Qempty
abbrev HasTypeArms (P : Program) (B : Builtins) (Ψ : StoreTy) :=
  HasTypeArmsQ P B Ψ Qempty
abbrev HasTypeClauses (P : Program) (B : Builtins) (Ψ : StoreTy) :=
  HasTypeClausesQ P B Ψ Qempty

def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
    HasTypeCQ P B StoreTy.empty (Qsig d.params d.ret d.eff)
      d.tparams (binds d.params) (some d.ret) d.body d.ret d.eff
```

V_Funは元の三欄のQsigから現在のQへのAdmissibleを要求する。V_Primは通常の制約として既存のadmitsを保ち、型・行の範囲とRowTransportを別に要求する。C_Methは型の具体化に既存の `ss ++ [τ]` を使い、行については元のメソッド署名のQsigから現在のQへRowTransportを要求する。型クラス引数τをSatAllの新しい制約に置き換える必要はない。既存の `SatAll B C ss ms.tparams` とτの既存の型付けを保つ。メソッドの場合の正確な条件は次である。

```lean
def MethodRowsAdmissible (C : List TParam) (Q : NoFailCtx) (ms : MethSig)
    (es : List Eff) : Prop :=
  es.length = ms.neffs ∧ (∀ f ∈ es, Eff.WF C.length f) ∧
  Eff.RhosIn (· < es.length) ms.eff ∧
  (∀ i, Qsig ms.params ms.ret ms.eff i → i < es.length) ∧
  RowTransport (Qsig ms.params ms.ret ms.eff) Q es

structure PrimitiveAdmissible (C : List TParam) (s : PrimSig)
    (Q : NoFailCtx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = s.ntys
  admits : s.admits C ts
  typeScope : ∀ t ∈ ts, Ty.WF C.length t ∧ ∀ b r e, t ≠ .cont b r e
  rowCount : es.length = s.neffs
  rowScope : ∀ f ∈ es, Eff.WF C.length f
  sourceRows : Eff.RhosIn (· < es.length) s.eff
  sourceQ : ∀ i, Qsig s.params s.ret s.eff i → i < es.length
  noFailRows : RowTransport (Qsig s.params s.ret s.eff) Q es

-- HasTypeVQの構成子の変更。
| V_Fun {Γ f d ts es} :
    P.defs f = some d → NamesWF d.names d.params →
    Admissible B C d.tparams d.neffs (Qsig d.params d.ret d.eff) Q ts es d.eff →
    HasTypeVQ P B Ψ Q C Γ (.fnRef f ts es)
      (fnTy d.names d.params d.ret d.eff ts es)
| V_Prim {Γ b s ts es} :
    B.sig b = some s → NamesWF s.names s.params →
    PrimitiveAdmissible C s Q ts es →
    HasTypeVQ P B Ψ Q C Γ (.prim b ts es)
      (fnTy s.names s.params s.ret s.eff ts es)

-- HasTypeCQのC_Methの変更。
| C_Meth {Γ R v cl τ cd m ms ss es ws} :
    HasTypeVQ P B Ψ Q C Γ v (.dict cl τ) → P.classes cl = some cd →
    cd.methods m = some ms → NamesWF ms.names ms.params →
    SatAll B C ss ms.tparams →
    (∀ t ∈ ss ++ [τ], Ty.WF C.length t ∧ ∀ b r e, t ≠ .cont b r e) →
    MethodRowsAdmissible C Q ms es →
    HasTypeVsQ P B Ψ Q C Γ ws (ms.params.map (Ty.subst (ss ++ [τ]) es)) →
    HasTypeCQ P B Ψ Q C Γ R (.meth v m ss es ws)
      (ms.ret.subst (ss ++ [τ]) es) (Eff.substAt 0 (ss ++ [τ]) es ms.eff)
```

実装の入口は次の形にする。上位クラスの辞書にはQemptyを使い、メソッドにはクラスが宣言した元の署名のQsigを渡す。

```lean
def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧ NamesWF ms.names ms.params ∧
      HasTypeCQ P B StoreTy.empty (Qsig ms.params ms.ret ms.eff)
        (ms.tparams ++ id.tparams)
        (binds (id.dictTys.map (Ty.shift ms.tparams.length 0) ++ ms.params.map (id.methTy ms)))
        (some (id.methTy ms ms.ret)) body (id.methTy ms ms.ret)
        (Eff.substAt ms.tparams.length [id.target] [] ms.eff)) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeVQ P B StoreTy.empty Qempty id.tparams (binds id.dictTys) u (.dict s id.target))
```

クラス探索・メソッド名の条件・環境の構築は既存のImplDecl.WellTypedを保ち、各HasTypeV/CのQを上記のとおり選ぶ。

実装メソッドの本体は元の `Qsig ms.params ms.ret ms.eff` で検査する。`ImplDecl.methTy` と効果への対象型の代入はR30/R36どおりであり、型束縛を動かしても行の番号とQを動かさない。V_Lamは現在のQで本体を検査し、期待型・注釈から得た宣言側の条件を超えてQを増やさない。C_Sub・C_Eff・Ty.LeはL1末の規則をそのまま保つ。一般のReleaseのFail列の長さは制限しない。

### 型・行の置換と値の置換

新しい前提は内部の補助のRowTransportである。HasTypeVQ/VsQ/EachQ/CQ/ArmsQ/ClausesQとHasFailureClauseの七判断で同時に保存する。型束縛の内側では既存と同じくcを増やし、ts/esのFail内部の型も動かす。Q自体には型の番号がない。

```lean
def ComputationSubstTyGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      Ψ Qs Qt C Γ R m a e c ts es,
    HasTypeCQ P B Ψ Qs C Γ R m a e →
    c ≤ C.length → ClosedArgs ts → (∀ f ∈ es, Eff.WF 0 f) →
    SatAll B [] ts (C.drop c) → StoreFix Ψ ts es →
    RowTransport Qs Qt es →
    HasTypeCQ P B Ψ Qt (C.take c) (envSubst c ts es Γ)
      (R.map (Ty.substAt c ts es)) (m.substTyAt c ts es)
      (a.substAt c ts es) (Eff.substAt c ts es e)

def FailureClauseSubstTyGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      Ψ Qs Qt C Γ E R h t ec c ts es,
    HasFailureClause P B Ψ Qs C Γ E R h t ec →
    c ≤ C.length → ClosedArgs ts → (∀ f ∈ es, Eff.WF 0 f) →
    SatAll B [] ts (C.drop c) → StoreFix Ψ ts es →
    RowTransport Qs Qt es →
    HasFailureClause P B Ψ Qt (C.take c) (envSubst c ts es Γ)
      (E.substAt c ts es) (R.map (Ty.substAt c ts es))
      (Clause.substTyAtList c ts es h) (t.substAt c ts es)
      (Eff.substAt c ts es ec)

def DefinitionInstantiationGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      (d : Def) Q ts es,
    d.WellTyped P B → ClosedArgs ts →
    Admissible B [] d.tparams d.neffs
      (Qsig d.params d.ret d.eff) Q ts es d.eff →
    HasTypeCQ P B StoreTy.empty Q []
      (binds (d.params.map (Ty.subst ts es)))
      (some (d.ret.subst ts es)) (d.body.substTy ts es)
      (d.ret.subst ts es) (Eff.substAt 0 ts es d.eff)

def ClosedTyQ (P : Program) (B : Builtins) (Ψ : StoreTy)
    (v : Val) (x : Ty) : Prop :=
  ∀ Q C Γ, HasTypeVQ P B Ψ Q C Γ v x

def ClosedValueGoal : Prop :=
  ∀ P B (hb : B.Assumptions P) Ψ v x,
    HasTypeV P B Ψ [] [] v x → Val.VarsIn 0 (fun _ => True) v →
    ClosedTyQ P B Ψ v x
```

残る五判断の型代入言明も同じ条件を使う。

```lean
def ValueSubstTyGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      Ψ Qs Qt C Γ v a c ts es,
    HasTypeVQ P B Ψ Qs C Γ v a →
    c ≤ C.length → ClosedArgs ts → (∀ f ∈ es, Eff.WF 0 f) →
    SatAll B [] ts (C.drop c) → StoreFix Ψ ts es →
    RowTransport Qs Qt es →
    HasTypeVQ P B Ψ Qt (C.take c) (envSubst c ts es Γ)
      (v.substTyAt c ts es) (a.substAt c ts es)

def ValuesSubstTyGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      Ψ Qs Qt C Γ vs as c ts es,
    HasTypeVsQ P B Ψ Qs C Γ vs as →
    c ≤ C.length → ClosedArgs ts → (∀ f ∈ es, Eff.WF 0 f) →
    SatAll B [] ts (C.drop c) → StoreFix Ψ ts es →
    RowTransport Qs Qt es →
    HasTypeVsQ P B Ψ Qt (C.take c) (envSubst c ts es Γ)
      (Val.substTyAtList c ts es vs) (as.map (Ty.substAt c ts es))

def EachSubstTyGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      Ψ Qs Qt C Γ vs a c ts es,
    HasTypeEachQ P B Ψ Qs C Γ vs a →
    c ≤ C.length → ClosedArgs ts → (∀ f ∈ es, Eff.WF 0 f) →
    SatAll B [] ts (C.drop c) → StoreFix Ψ ts es →
    RowTransport Qs Qt es →
    HasTypeEachQ P B Ψ Qt (C.take c) (envSubst c ts es Γ)
      (Val.substTyAtList c ts es vs) (a.substAt c ts es)

def ArmsSubstTyGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      Ψ Qs Qt C Γ R arms a b e c ts es,
    HasTypeArmsQ P B Ψ Qs C Γ R arms a b e →
    c ≤ C.length → ClosedArgs ts → (∀ f ∈ es, Eff.WF 0 f) →
    SatAll B [] ts (C.drop c) → StoreFix Ψ ts es →
    RowTransport Qs Qt es →
    HasTypeArmsQ P B Ψ Qt (C.take c) (envSubst c ts es Γ)
      (R.map (Ty.substAt c ts es)) (Arm.substTyAtList c ts es arms)
      (a.substAt c ts es) (b.substAt c ts es) (Eff.substAt c ts es e)

def ClausesSubstTyGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      Ψ Qs Qt C Γ R h t ec c ts es,
    HasTypeClausesQ P B Ψ Qs C Γ R h t ec →
    c ≤ C.length → ClosedArgs ts → (∀ f ∈ es, Eff.WF 0 f) →
    SatAll B [] ts (C.drop c) → StoreFix Ψ ts es →
    RowTransport Qs Qt es →
    HasTypeClausesQ P B Ψ Qt (C.take c) (envSubst c ts es Γ)
      (R.map (Ty.substAt c ts es)) (Clause.substTyAtList c ts es h)
      (t.substAt c ts es) (Eff.substAt c ts es ec)

```

値置換のSubstOkは既存の変数・閉じた値・継続の場所という三通りを保ち、閉じた値の欄をClosedTyQにする。すべてのQで型付くことはClosedValueGoalで導く。七判断の値置換はQを保ち、NoFailへの追加条件は不要である。

```lean
def SubstOkQ (P : Program) (B : Builtins) (Ψ : StoreTy)
    (Γ Δ : List (Option Ty)) (R0 : Option Ty) (σ : Nat → Val) : Prop :=
  ∀ i x, Γ[i]? = some (some x) →
    (∃ j, σ i = .var j ∧ Δ[j]? = some (some x)) ∨
    ((∀ b t e, x ≠ .cont b t e) ∧ Ty.WF 0 x ∧ ClosedTyQ P B Ψ (σ i) x) ∨
    (∃ b t e l, x = .cont b t e ∧ Ty.WF 0 x ∧ σ i = .loc l ∧
      Ψ l = some (.cont b t e R0) ∧ ∀ r, R0 = some r → Ty.WF 0 r)

def ComputationSubstGoal : Prop :=
  ∀ P B Ψ Q C Γ Δ R m a e σ,
    HasTypeCQ P B Ψ Q C Γ R m a e →
    SubstOkQ P B Ψ Γ Δ R σ →
    HasTypeCQ P B Ψ Q C Δ R (m.subst σ) a e

def FailureClauseSubstGoal : Prop :=
  ∀ P B Ψ Q C Γ Δ E R h t ec σ,
    HasFailureClause P B Ψ Q C Γ E R h t ec →
    SubstOkQ P B Ψ Γ Δ R σ →
    HasFailureClause P B Ψ Q C Δ E R (Clause.substList σ h) t ec
```

```lean
def ValueSubstGoal : Prop :=
  ∀ P B Ψ Q C Γ Δ R0 v a σ,
    HasTypeVQ P B Ψ Q C Γ v a → SubstOkQ P B Ψ Γ Δ R0 σ →
    HasTypeVQ P B Ψ Q C Δ (v.subst σ) a

def ValuesSubstGoal : Prop :=
  ∀ P B Ψ Q C Γ Δ R0 vs as σ,
    HasTypeVsQ P B Ψ Q C Γ vs as → SubstOkQ P B Ψ Γ Δ R0 σ →
    HasTypeVsQ P B Ψ Q C Δ (Val.substList σ vs) as

def EachSubstGoal : Prop :=
  ∀ P B Ψ Q C Γ Δ R0 vs a σ,
    HasTypeEachQ P B Ψ Q C Γ vs a → SubstOkQ P B Ψ Γ Δ R0 σ →
    HasTypeEachQ P B Ψ Q C Δ (Val.substList σ vs) a

def ArmsSubstGoal : Prop :=
  ∀ P B Ψ Q C Γ Δ R arms a b e σ,
    HasTypeArmsQ P B Ψ Q C Γ R arms a b e → SubstOkQ P B Ψ Γ Δ R σ →
    HasTypeArmsQ P B Ψ Q C Δ R (Arm.substList σ arms) a b e

def ClausesSubstGoal : Prop :=
  ∀ P B Ψ Q C Γ Δ R h t ec σ,
    HasTypeClausesQ P B Ψ Q C Γ R h t ec → SubstOkQ P B Ψ Γ Δ R σ →
    HasTypeClausesQ P B Ψ Q C Δ R (Clause.substList σ h) t ec

```

ここで `SubstOkQ` は上記の三通りによる既存SubstOkの改名であり、Qという外部の仮定を追加する述語ではない。rename/store/outer/hideとQの単調性、WF・反転も七判断へ拡張する。PatTy・Inhabitsと網羅性はQを持たず、型の置換だけを従来の補題で処理する。

## Fail操作・一つの型束縛・ハンドラ

### 構文と束縛の数

専用の構成子を追加する。Failを利用者の文字列の操作名や組み込みのIO操作へ割り当てると、既存のopSigやBuiltinsの動作の仮定にFailの特例が混ざる。そのため操作の識別 `.fail`、値 `.raise T E`、節 `.fail E body` を使う。

```lean
-- 既存の帰納型へ追加する構成子。
-- OpRef:  | fail
-- Val:    | raise (result error : Ty)
-- Clause: | fail (error : Ty) (body : Comp)

-- 新構成子の射影。
-- Clause.op    (.fail E body) = OpRef.fail
-- Clause.arity (.fail E body) = 1
-- Clause.ntys  (.fail E body) = 1
-- Clause.body  (.fail E body) = body
-- opSig P B OpRef.fail = none
-- 通常の Clause.mk OpRef.fail ... はHasTypeClausesQで拒否する。

-- Clause.failの型代入の新しい場合。
-- substTyAtList c ts es (.fail E body :: cs) =
--   .fail (E.substAt c ts es) (body.substTyAt (c + 1) ts es) ::
--     substTyAtList c ts es cs
-- 値置換・renameはbodyで値束縛を二つ増やす。Eは変更しない。
```

節のEは外側の型変数の文脈に置く。bodyだけがrigidなTを0番に一つ束縛する。bodyの値環境は0番が予約したnone、1番がerror、2番以降が外側の変数である。型の範囲も `.fail E body` について `Ty.VarsIn n pe E ∧ Comp.VarsIn (n+1) pe body` とする。Support・ClosedNoEffVars・名前の検査もEとbodyをそれぞれの深さで辿る。値の新しい場合も `Val.VarsIn n pe (.raise T E) = Ty.VarsIn n pe T ∧ Ty.VarsIn n pe E` とし、Support・NamesWF・ClosedNoEffVarsはTとEの両方へ再帰する。FailureInstantiateGoalのClosedArgs [T]はV_RaiseのWFだけからでなく、閉じた計算のVarsInと既存のclosedArgs_ofから得る。辞書の追加はL3aで通常節に接続する。Fail自体の辞書数は0である。

### 値とFail節の型付け

```lean
-- HasTypeVQの新しい構成子。
| V_Raise {Γ T E} :
    Ty.WF C.length T → Ty.WF C.length E →
    HasTypeVQ P B Ψ Q C Γ (.raise T E)
      (.fn ["error"] [E] T (Eff.singleFail E))

-- 六判断と同じmutualブロックへ置く第七の判断。
inductive HasFailureClause (P : Program) (B : Builtins)
    (Ψ : StoreTy) (Q : NoFailCtx) :
    List TParam → List (Option Ty) → Ty → Option Ty →
      List Clause → Ty → Eff → Prop
  | one {C Γ E R body t ec} :
      Ty.WF C.length E → Ty.WF C.length t → Eff.WF C.length ec →
      HasTypeCQ P B Ψ Q (({} : TParam) :: C)
        (none :: some (E.shift 1 0) :: shiftEnv 1 Γ)
        (R.map (Ty.shift 1 0)) body (t.shift 1 0) (Eff.shift 1 0 ec) →
      HasFailureClause P B Ψ Q C Γ E R [.fail E body] t ec

-- HasTypeCQの新しい構成子。
| C_Handle_Fail {Γ R m h t E eb Rest ec} :
    HasTypeCQ P B Ψ Q C Γ R m t eb →
    Eff.Sub eb (Eff.union (Eff.singleFail E) Rest) → NoFail Q Rest →
    HasFailureClause P B Ψ Q C Γ E R h t ec →
    HasTypeCQ P B Ψ Q C Γ R (.handle m h) t (Eff.union Rest ec)
```

`({} : TParam)` は既存の無制約の型パラメータである。FailにShow等の新しい制約は加えない。通常のHasTypeClausesQ.consは元の前提に `o ≠ .fail` を加え、Clause.mkだけを導入する。通常節とFail節の混在、Fail節を複数置く導出は存在しない。通常のC_HandleとK_HandleはこのHasTypeClausesQを使う。

```lean
-- HasTypeClausesQの通常節の構成子。FailのClause.failはこの判断に入れない。
| cons {Γ R o n k body cs t ec sg} :
    o ≠ .fail → opSig P B o = some sg → NamesWF sg.names sg.params →
    n = sg.params.length → k = sg.tparams.length → Eff.WF C.length ec →
    HasTypeCQ P B Ψ Q (sg.tparams ++ C)
      (some (.cont sg.ret (t.shift k 0) (Eff.shift k 0 ec)) ::
        (binds sg.params ++ shiftEnv k Γ))
      (R.map (Ty.shift k 0)) body (t.shift k 0) (Eff.shift k 0 ec) →
    HasTypeClausesQ P B Ψ Q C Γ R cs t ec →
    HasTypeClausesQ P B Ψ Q C Γ R (.mk o n k body :: cs) t ec
```

handledは現在の名前だけの集合の定義を保つ。新しいClause.opでも計算できるhandles/findClauseへ接続するが、Failをhandledの名前集合へ入れない。次は規則の前提にせず定義から示す。

```lean
def HandledNoFailGoal : Prop :=
  ∀ P B h, (handled P B h).fails = [] ∧
    (∀ i, ¬ Eff.mem (handled P B h) (.rho i)) ∧
    (∀ E, ¬ Eff.memFail (handled P B h) E)

def OrdinaryClausesNoFailureGoal : Prop :=
  ∀ P B Ψ Q C Γ R h t ec,
    HasTypeClausesQ P B Ψ Q C Γ R h t ec → handles h .fail = false
```

### E-Op-Failの代入

Fail節にはT一つだけを代入する。raiseのE′は値引数の型検査と捕捉安全の証明に使うが、bodyの型変数として再束縛しない。通常のE_Op/E_OpPrimは従来の全型引数を代入する。

```lean
-- Stepの新しい構成子。EとE'を比較する前提は置かない。
| E_OpFail {T E' v k σ k1 E body k2 κ} :
    SplitAt .fail k k1 [.fail E body] k2 → σ κ = none →
    Step P B (.run (.app (.raise T E') [v]) k σ) none
      (.run ((body.substTy [T] []).instantiate [v, .loc κ])
        (.drop κ :: k2) (σ.set κ (.cont (k1 ++ [.handleF [.fail E body]]))))
```

探索はOpRef.failの一致だけで行い、最も内側を選ぶ。節のEは型付きモデルに残る注釈であり、選択に使わない。参考用step/runとstep_soundにもこの場合を加える。UnhandledOpは既存の利用者操作の場合に加えて `.run (.app (.raise _ _) _) k _ => NoHandler k .fail` を持つ。新しいIOの事象やBuiltinの応答は追加しない。

`instantiate [v, .loc κ]` は逆順の束縛なので、0番へloc κ、1番へvが入る。0番はnoneのため型付けできず、値置換にはnoneを許す専用の補題を使う。継続の型を0番へ一度与えてから禁止を確認する方式は採らない。

## 継続・捕捉安全・ストアと解放

### K_Handle_Failと保存継続

ContTy・CellOk・StoreOk・StateTyは閉じた状態の判断であり、Qのパラメータを加えない。内部の計算の型付けはQemptyの別名を使う。

```lean
-- ContTyの新しい構成子。
| K_Handle_Fail {R e ec Rest E h k t b e0 Re} :
    ContTy P B Ψ R e k t b e0 Re →
    Eff.Sub Rest e → NoFail Qempty Rest →
    HasFailureClause P B Ψ Qempty [] [] E R h t ec →
    Eff.Sub ec e → Ty.WF 0 t →
    ContTy P B Ψ R (Eff.union (Eff.singleFail E) Rest)
      (.handleF h :: k) t b e0 Re

def captureEff (Rest ec : Eff) : Eff := Eff.norm (Eff.union Rest ec)

def CaptureBaseGoal : Prop :=
  ∀ P B Ψ R E h t Rest ec,
    HasFailureClause P B Ψ Qempty [] [] E R h t ec →
    NoFail Qempty Rest → Ty.WF 0 t →
    ContTy P B Ψ R (Eff.union (Eff.singleFail E) Rest)
      [.handleF h] t t (captureEff Rest ec) R
```

CaptureBaseGoalの導出は、末尾から次の形になる。HasFailureClause.oneからecのWFとE/tのWFを得る。RestのFail列は空なのでRestのWFも得られる。captureEffのCanonicalとWFは既存のnormの補題による。

```lean
-- cap := captureEff Rest ec
-- K_Empty (Eff.Sub.refl cap) htw :
--   ContTy P B Ψ Rh cap [] t t cap Rh
-- K_Handle_Fail 上の導出 (Rest ⊆ cap) hNoFail hcl (ec ⊆ cap) htw :
--   ContTy P B Ψ Rh (singleFail E ∪ Rest) [.handleF h] t t cap Rh
```

capにはRestも残す。節が純粋でも、捨てるK1にStateの解放がある場合は、そのStateをdropが引き継ぐ必要がある。capをecだけにするとK_Dropの前提を導けない。

### 最も内側の節とEの一致

SplitAtのNoHandlerから、選択した節より内側にはFailを処理する枠がないことを得る。型付きのFail枠は必ずその節を持つので、そこでK_Handle_Failの分岐を除ける。NoHandler自体は現在の探索の定義を使う。

```lean
def SplitAtFailurePrefixGoal : Prop :=
  ∀ k k1 E body k2,
    SplitAt .fail k k1 [.fail E body] k2 →
    NoHandler k1 .fail ∧
      ∀ E' body', .handleF [.fail E' body'] ∉ k1

def ContNoFailurePropagatesGoal : Prop :=
  ∀ P B Ψ R ein k a b eout Re E',
    ContTy P B Ψ R ein k a b eout Re →
    NoHandler k .fail → Eff.memFail ein E' → Eff.memFail eout E'

-- 選ばれた枠の手前だけを伝播し、K_Subも含めて入力の効果を返す。
def FailurePrefixPropagatesGoal : Prop :=
  ∀ P B Ψ R ein k1 E body k2 a b Eb Re E',
    ContTy P B Ψ R ein (k1 ++ .handleF [.fail E body] :: k2) a b Eb Re →
    NoHandler k1 .fail → Eff.memFail ein E' →
    ∃ Rh eout Rest ec t,
      HasFailureClause P B Ψ Qempty [] [] E Rh [.fail E body] t ec ∧
      NoFail Qempty Rest ∧ Eff.Sub Rest eout ∧ Eff.Sub ec eout ∧ Ty.WF 0 t ∧
      ContTy P B Ψ Rh eout k2 t b Eb Re ∧
      Eff.memFail (Eff.union (Eff.singleFail E) Rest) E'

def FailureUpperBoundGoal : Prop :=
  ∀ E E' Rest,
    Ty.Canonical E → Ty.Canonical E' → NoFail Qempty Rest →
    Eff.memFail (Eff.union (Eff.singleFail E) Rest) E' → E' = E

def FailureClauseSelectedTypedGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      Ψ R T E' v a b ein em Eb k k1 E body k2 σ,
    StoreOk P B Ψ σ →
    HasTypeC P B Ψ [] [] R (.app (.raise T E') [v]) a em →
    Eff.Sub em ein → ContTy P B Ψ R ein k a b Eb none →
    Comp.VarsIn 0 (fun _ => True) (.app (.raise T E') [v]) →
    SplitAt .fail k k1 [.fail E body] k2 →
    E' = E ∧ HasTypeV P B Ψ [] [] v E
```

ContNoFailurePropagatesGoalではK_HandleのhandledにFailがないこと、K_Subは効果を変えないこと、K_Guardの入力は空なのでFail所属を仮定できないことを各場合で示す。K_Handle_Failの分岐はNoHandlerで排除する。K_Let/Mark/Update/Release/Dropの既存の包含を通じて伝播する。存在するK1だけについて独立したContTyを与える必要はなく、FailurePrefixPropagatesGoalで継続の導出を選択枠まで辿る。K_Subを通ってもK_Handle_Failの穴の効果への所属を返し、K1単独のContTyは構成しない。

FailureClauseSelectedTypedGoalは実行時の型の比較、E′=E、捕捉の安全性、Releaseの単一Failを前提にしない。raiseの型付けをC_Sub/C_EffとV_Subの内側まで反転し、`singleFail E' ⊆ em ⊆ ein` とv:E′を得る。E/E′のCanonicalは節とraiseのWFから得る。memFailが返す正規形同士の等号をWFで生のE′=Eへ戻す。

### 分割したK1とCellOk

Failの分割は、通常節のContTy.splitの結果と別の枝で返す。新しい枝の全契約は次である。`a` はraiseのC_Sub後の結果型であり、保存継続にTを付けるときだけTy.Le T aでK_Subを適用する。

```lean
def SplitFailureTypedGoal : Prop :=
  ∀ P B Ψ R ein k1 h k2 a b Eb Re E body,
    ContTy P B Ψ R ein (k1 ++ .handleF h :: k2) a b Eb Re →
    h = [.fail E body] →
    ∃ t Rh eout Rest ec,
      HasFailureClause P B Ψ Qempty [] [] E Rh h t ec ∧
      NoFail Qempty Rest ∧ Eff.Sub Rest eout ∧ Eff.Sub ec eout ∧
      Ty.WF 0 t ∧
      ContTy P B Ψ Rh eout k2 t b Eb Re ∧
      ContTy P B Ψ R ein (k1 ++ [.handleF h])
        a t (captureEff Rest ec) Rh

-- cap = captureEff Rest ec、Ψ' = Ψ.set κ (.cont T t cap Rh)。
-- 元のraiseの型付けと継続の反転からTy.Le T aを得る。
-- (K_Sub 上の保存継続 hle).store hΨsub :
--   ContTy P B Ψ' R ein (k1 ++ [.handleF h]) T t cap Rh
-- Ψ' κ = some (.cont T t cap Rh)
-- b' := T、t' := t、ε' := cap、R' := Rh。

def SavedFailureCellGoal : Prop :=
  ∀ P B Ψ κ T t cap Rh R ein k1 h,
    Ψ κ = some (.cont T t cap Rh) →
    ContTy P B Ψ R ein (k1 ++ [.handleF h]) T t cap Rh →
    CellOk P B Ψ κ (.cont (k1 ++ [.handleF h]))

def FailureDropGoal : Prop :=
  ∀ P B Ψ κ T t Rh Rest ec eout k2 b Eb Re,
    Ψ κ = some (.cont T t (captureEff Rest ec) Rh) →
    Eff.Sub Rest eout → Eff.Sub ec eout →
    ContTy P B Ψ Rh eout k2 t b Eb Re →
    ContTy P B Ψ Rh eout (.drop κ :: k2) t b Eb Re
```

SavedFailureCellGoalではCellOkの存在変数を `T,t,cap,Rh,R,ein` とし、EndsWithHandleの証人を `k1,h` とする。LocTy.WFにはT/t/Rhの型のWF、capのWFとCanonicalを渡す。σ κ=noneとStoreOkの領域の一致からΨ κ=noneを得て、StoreTy.set_subとStoreOk.setを現在と同じ順に使う。

FailureDropGoalは既存のK_Dropをそのまま使う。`State ∈ cap` はnormとunionの所属保存により `State ∈ Rest ∨ State ∈ ec` へ戻り、どちらからもeoutのStateを得る。dropの解放が行う効果はStateだけであり、capのFailが外へ漏れるとはしない。FramesOk・releases・resume_append・split・store・R_wfに新しいK_Handle_Failの場合を追加する。resume_appendで末尾のFail枠を置き換えるときはRestとecの両方の包含を合成する。

### 利用不能な0番と捕捉後の計算

noneを許す環境の置換を明示する。予約した値がどれかによらないことと、通常節の外側の継続を使うことは区別する。

```lean
def IrrelevantSlot (m : Comp) (i : Nat) : Prop :=
  ∀ σ τ : Nat → Val, (∀ j, j ≠ i → σ j = τ j) → m.subst σ = m.subst τ

-- 七判断の相互帰納で使う、任意のnoneの位置の言明。
def ComputationIrrelevantSlotGoal : Prop :=
  ∀ P B Ψ Q C Γ R m a e i,
    HasTypeCQ P B Ψ Q C Γ R m a e →
    Γ[i]? = some none → IrrelevantSlot m i

def ValueIrrelevantSlotGoal : Prop :=
  ∀ P B Ψ Q C Γ v a i,
    HasTypeVQ P B Ψ Q C Γ v a → Γ[i]? = some none →
    ∀ σ τ : Nat → Val, (∀ j, j ≠ i → σ j = τ j) →
      Val.subst σ v = Val.subst τ v

def ValuesIrrelevantSlotGoal : Prop :=
  ∀ P B Ψ Q C Γ vs as i,
    HasTypeVsQ P B Ψ Q C Γ vs as → Γ[i]? = some none →
    ∀ σ τ : Nat → Val, (∀ j, j ≠ i → σ j = τ j) →
      Val.substList σ vs = Val.substList τ vs

def EachIrrelevantSlotGoal : Prop :=
  ∀ P B Ψ Q C Γ vs a i,
    HasTypeEachQ P B Ψ Q C Γ vs a → Γ[i]? = some none →
    ∀ σ τ : Nat → Val, (∀ j, j ≠ i → σ j = τ j) →
      Val.substList σ vs = Val.substList τ vs

def ArmsIrrelevantSlotGoal : Prop :=
  ∀ P B Ψ Q C Γ R arms a b e i,
    HasTypeArmsQ P B Ψ Q C Γ R arms a b e → Γ[i]? = some none →
    ∀ σ τ : Nat → Val, (∀ j, j ≠ i → σ j = τ j) →
      Arm.substList σ arms = Arm.substList τ arms

def ClausesIrrelevantSlotGoal : Prop :=
  ∀ P B Ψ Q C Γ R h t e i,
    HasTypeClausesQ P B Ψ Q C Γ R h t e → Γ[i]? = some none →
    ∀ σ τ : Nat → Val, (∀ j, j ≠ i → σ j = τ j) →
      Clause.substList σ h = Clause.substList τ h

def FailureClauseIrrelevantSlotGoal : Prop :=
  ∀ P B Ψ Q C Γ E R h t e i,
    HasFailureClause P B Ψ Q C Γ E R h t e → Γ[i]? = some none →
    ∀ σ τ : Nat → Val, (∀ j, j ≠ i → σ j = τ j) →
      Clause.substList σ h = Clause.substList τ h

def FailureClauseNoResumeGoal : Prop :=
  ∀ P B Ψ Q C Γ R m a e,
    HasTypeCQ P B Ψ Q C (none :: Γ) R m a e → IrrelevantSlot m 0

def FailureInstantiateGoal : Prop :=
  ∀ P B (hwf : P.WellFormed) (hb : B.Assumptions P)
      Ψ R E t ec T body v κ,
    (∀ r, R = some r → Ty.WF 0 r) →
    HasFailureClause P B Ψ Qempty [] [] E R [.fail E body] t ec →
    ClosedArgs [T] → StoreTy.WF Ψ →
    HasTypeV P B Ψ [] [] v E → Val.VarsIn 0 (fun _ => True) v →
    HasTypeC P B Ψ [] [] R
      ((body.substTy [T] []).instantiate [v, .loc κ]) t (Eff.norm ec)
```

IrrelevantSlotの補題はfailure_clause_no_resumeを主張するためのものであり、FailureInstantiateGoalの証明には不要である。FailureInstantiateGoalはκの型を要求しない。noneの位置にはSubstOkQが値の型を要求しないためである。Tだけを置換してからE/t/Rの閉じた型の恒等式とecの正規化を使い、1番にvを入れる。IrrelevantSlotはbodyの下の束縛で番号を増やす既存のupSubstと整合する。型置換後にも同じ言明を適用でき、κの利用不能を保つ。外側の通常の継続のresumeは禁止しない。

この後、ec.normをeoutへ広げ、FailureDropGoalの継続と新ストアを組み合わせて保存を閉じる。元の状態の閉じた条件からbody/Eと型引数のVarsInを取り出し、置換後のComp・Cont・StoreのClosedを既存と同じく証明する。

## L2b/cの表層・検査器への契約

L2bではReleaseと同じ取り込みでSurfaceの式・ブロック・分岐・通常節・引数列・同型引数列・穴の引数の七判断をQ付きへ一般化する。Def/Implは署名のQで内部を呼ぶ。辞書の証拠自体はNoFailを消費しないので、DictEv.HasType/HasTypesへQは加えない。閉じた入口はQemptyの別名とwrapperを保つ。L2bに呼び出し・値化・メソッドのAdmissibleと健全性・脱糖の接続を含め、L2cにはFailの節・単一Fail・最小効果と正負例を残す（R52）。

checkerも内部の `checkExprQ` 等へ計算用Qを渡し、従来の公開入口は空Qのwrapperとして保つ。宣言の本体は署名のQを計算して一般化版へ渡す。公開する健全性11件には新しい外部の前提を加えない。内部のQのBool列と述語の対応は構築・参照成功から証明する。q.Soundに未検査のNoFailの主張を加えて済ませない。

```lean
def SingleFail (e : Eff) : Prop := (Eff.norm e).fails.length ≤ 1

mutual
  def SingleTy : Ty → Prop
    | .base _ | .opaque _ | .tvar _ | .bytes | .ctor _ => True
    | .data _ as | .tapp _ as => SingleTys as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => SingleTy a
    | .map a b => SingleTy a ∧ SingleTy b
    | .fn _ ps r e => SingleTys ps ∧ SingleTy r ∧ SingleEff e
    | .cont a b e => SingleTy a ∧ SingleTy b ∧ SingleEff e
  def SingleTys : List Ty → Prop
    | [] => True
    | t :: ts => SingleTy t ∧ SingleTys ts
  def SingleEff : Eff → Prop
    | .mk atoms fs => SingleFail (.mk atoms fs) ∧ SingleTys fs
end

def SingleSignature (ps : List Ty) (r : Ty) (e : Eff) : Prop :=
  SingleTys ps ∧ SingleTy r ∧ SingleFail e ∧ SingleTys e.fails

def InstantiatedSignatureOK (B : Builtins) (C : List TParam)
    (tps : List TParam) (ne : Nat) (ps : List Ty) (r : Ty) (e : Eff)
    (Q : NoFailCtx) (ts : List Ty) (es : List Eff) : Prop :=
  Admissible B C tps ne (Qsig ps r e) Q ts es e ∧
  SingleSignature (ps.map (Ty.subst ts es)) (r.subst ts es)
    (Eff.substAt 0 ts es e)
```

呼び出し・値化・部分適用・穴・パイプは具体化済みの署名をこの条件で検査する。合流は具体化した両枝と結果の各効果をSingleFailで検査し、型内部もSingleTyで検査する。単独の行二つを別型のFailへ具体化する場合、Qsigが空でも結果で拒否する。通常の行多相で一種類のFailを渡す形は受理する。NoFailの判定は外側だけ、SingleTyの再帰的な制限は表層の型として扱う。

表層のFail節はEが固定された一節だけとし、節の本体はrigidなT一つ、noneの0番、shiftしたEの1番で検査する。期待型・注釈の範囲でラムダを検査し、handleからQを増やさない。最小効果の計算では本体を `singleFail E ∪ Rest` の上限で検査し、節の効果を本体の上限へ戻さない。節の実際の効果を外側へ戻すR41/R44の検査もFailの新しい場合へ接続する。

健全性11件は現在の `CheckSound.lean` の前提と結論を保つ。Q付きの内部版では式から穴までの七件の型付けを対応するQ付き判断へ変える。辞書の二件の結論は同じ、Def/Implの二件は署名のQで定義したWellTypedへ返す。外側の11件は空Qの計算の成功から従来名の判断を返す。出力型・効果の支持、通常節でのactualの包含、元の入力全体のcheckProgram_sound/emptyも維持する。

## 維持する主な言明と仮定

### Releaseの主な三性質

次のGoalは現在のTheorems.leanの主な三性質の引数の形を保つ。ただし、進行と保存のStateTyが使うBuiltinOnlyは `ε.fails = []` を加えて強める（R51、設計者2026-10-17了承）。未捕捉のFailがないことを状態の前提に明示する変更であり、effect_soundnessの前提・結論は変えない。HasTypeCは空Qの別名とし、StateTy内部も空Qを使う。WellTyped内部で署名のQを選び、新しい構文・型付け・Step・UnhandledOpの意味を前述のとおり拡張する。

```lean
def BuiltinOnly (P : Program) (B : Builtins) (ε : Eff) : Prop :=
  ε.fails = [] ∧
    ∀ a, Eff.mem ε a → ∃ l, a = .name l ∧ P.effects l = none ∧ (B.effects l).isSome

def ProgressGoal : Prop :=
  ∀ P B, P.WellTyped B → P.EffectsOk B → B.Assumptions P →
    ∀ s, StateTy P B s → s.Final ∨ ∃ l s', Step P B s l s'

def PreservationGoal : Prop :=
  ∀ P B, P.WellFormed → P.WellTyped B → P.EffectsOk B → B.Assumptions P →
    ∀ s l s', StateTy P B s → Step P B s l s' → StateTy P B s'

def EffectSoundnessGoal : Prop :=
  ∀ P B, P.WellFormed → P.WellTyped B → P.EffectsOk B → B.Assumptions P →
    ∀ m a, HasTypeC P B StoreTy.empty [] [] none m a Eff.empty →
    m.ClosedNoEffVars → ∀ s, Steps P B (.run m [] Store.empty) s →
      (∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s
```

pres_op_commonの通常の枝は保ち、Failの保存はFailureClauseSelectedTypedGoal、SplitFailureTypedGoal、FailureInstantiateGoal、SavedFailureCellGoal、FailureDropGoalを順に使う。progressはFailの未捕捉をBuiltinOnlyにより除き、捕捉済みならE_OpFailを選ぶ。effect_soundnessのno_unhandledOpにもFailの伝播を加える。StateTyEで最後のEbを保つ内部の保存、step_sound、effect_soundness_noLamNamesも既存の結論を維持する。

### 脱糖と検査器の主な言明

```lean
-- Benitoite.Surface内の言明。
def DesugarTypedGoal : Prop :=
  ∀ p B opPrim, p.WellFormed → p.WellTyped B opPrim →
    (∀ b s, B.sig b = some s → s.Scoped) →
    (desugarProgram opPrim p).WellFormed ∧
      (desugarProgram opPrim p).WellTyped B ∧
      (desugarProgram opPrim p).EffectsOk B

def SurfaceEffectSoundnessGoal : Prop :=
  ∀ p B opPrim, p.WellFormed → p.WellTyped B opPrim →
    B.Assumptions (desugarProgram opPrim p) → p.HasMain Eff.empty →
    ∀ s, Steps (desugarProgram opPrim p) B
      (.run (.app (.fnRef "main" [] []) []) [] Store.empty) s →
      (∀ ev s', ¬ Step (desugarProgram opPrim p) B s (some ev) s') ∧
      ¬ UnhandledOp s
```

健全性11件とcheckProgramの完全な現行の型は `formal/Benitoite/Surface/CheckSound.lean` と `CheckProgramSound.lean` を正とする。L2b/cでは前述のQ付き内部版と空Qのwrapperでその型を保つ。網羅性の判定はL2で意味を変えず、パターンの束縛と脱糖を既存の補題へ接続する。捕捉安全の外部の仮定と公理は追加しない。Builtins.AssumptionsはL2bc3の反例を受け、設計者が了承したR57のsat_unconstrained一つを追加する。ここでのGoalはこの承認後の仮定で証明する。

| 条件 | 得る場所・証明の義務 |
|---|---|
| Qsigと行番号の範囲 | 宣言の全署名とScoped/VarsIn。実装本体からは増やさない |
| V_Fun/V_PrimのtypeScope・rowScope・sourceRows | 表層の型引数のWF・Ty.VarsIn、行引数のEff.VarsIn、s.Scoped・Def.Scopedから脱糖時に導く。L2bで検査器の成功からも取り出す |
| 呼び出しのRowTransport | V_Fun/V_Prim/C_MethとSurfaceの具体化の検査。閉じた状態ではQemptyへ写す |
| RestのNoFail | C_Handle_Failの検査。型代入はNoFailSubstGoal、実行の枠はK_Handle_Fail |
| E/E′の生の等号 | 型付けの反転・K1のFailの伝播・内側の上限・WFのCanonical |
| capのWF/CanonicalとStateの包含 | ecのWF、Restの空Fail列、norm/unionの所属保存。StoreOkとK_Dropへ渡す |
| 型・行の像の通常の範囲・制約 | 既存のClosedArgs・SatAll・StoreFix・WF/VarsIn。Fail内部までの再帰はR14/R21/R24 |
| 計算できるNoFail・Q・単一Failの判定 | 実際の入力の有限支持と範囲検査。normWithとの一致はL1cの証明を使う |
| 既存のIO・組み込みの保証と空制約の成立 | Builtins.Assumptions。Failの結果型の具体化にR57のsat_unconstrainedを加え、Modelでも示す。IO応答の仮定は変えない |

## 例・レビューと後続作業の区切り

L2bの有限遷移の例は、解放を含めない通常のmatch/handleで次の四つを置く。Result用の二構成子の名前を明示し、変換の新しい実行規則は作らない。Pに対応する二構成子の宣言を置いて型付けも確認するが、以下の有限遷移自体は構成子の照合だけを使う。関数呼び出しのmarkを例へ混ぜないよう、変換の本体の計算を直接示す。

```lean
def okValue (T E : Ty) (v : Val) : Val := .con "L2Result.Ok" [T, E] [v]
def errorValue (T E : Ty) (v : Val) : Val := .con "L2Result.Error" [T, E] [v]

def fromResultBody (T E : Ty) (v : Val) : Comp :=
  .match v
    [.mk [.mk (.con "L2Result.Ok" [.var]) [0]] none (.ret (.var 0)),
     .mk [.mk (.con "L2Result.Error" [.var]) [0]] none
       (.app (.raise T E) [.var 0])]

def toResultBody (T E : Ty) (body : Comp) : Comp :=
  .handle (.letIn body (.ret (okValue T E (.var 0))))
    [.fail E (.ret (errorValue (T.shift 1 0) (E.shift 1 0) (.var 1)))]

def FromResultOkGoal : Prop :=
  ∀ P B T E v,
    Steps P B (.run (fromResultBody T E (okValue T E v)) [] Store.empty)
      (.run (.ret v) [] Store.empty)

def FromResultErrorGoal : Prop :=
  ∀ P B T E v,
    Steps P B (.run (fromResultBody T E (errorValue T E v)) [] Store.empty)
      (.run (.app (.raise T E) [v]) [] Store.empty)

def ToResultReturnGoal : Prop :=
  ∀ P B T E v,
    Steps P B (.run (toResultBody T E (.ret v)) [] Store.empty)
      (.run (.ret (okValue T E v)) [] Store.empty)

def ToResultRaiseGoal : Prop :=
  ∀ P B T E v, ClosedArgs [T, E] →
    Steps P B (.run (toResultBody T E (.app (.raise T E) [v])) [] Store.empty)
      (.run (.ret (errorValue T E v)) [] (Store.empty.set 0 .used))
```

捕捉する例の最終ストアには、既存のdropが残すusedセルを明示する。最終ストアをemptyへ戻したと主張しない。型付けの例ではT/Eの項に書ける型の範囲も検査し、Failのエラー型はそのまま保持する。一般の外部資源の動作を前提にする例には広げない。

L2cでは、直接・高階・部分適用・別モジュール・持ち出したラムダ・別型への再raiseの正負を既存の公開checkerの例へ加える。追加前にtest-auditの四問を記録する。少なくとも、同じEの最内捕捉、異なるEの内側での完全処理、外へ返すラムダに残る潜在Fail、単独の行二つからの異型Failの拒否、Failなしの通常の行多相、NoFail不足と混在とresumeの拒否を確認する。既存のassert・期待値・ignoreは変更しない。

本書の定義と全言明の自己点検はL2aの結果へ記録する。RV2のL2a後の独立レビューは、これらの定義と型代入・捕捉・ストアの言明を対象とする。証明へ進む条件はレビューで前提・結論・仮定が確認されることであり、未変更の既定ビルドの成功を本書の証明と扱わない。主な定理の前提・結論、公理、Builtins.Assumptions、既存の結論の弱化が必要になれば設計者へ相談する。

## 健全性11件とプログラム全体の言明の写し

次は開始版の公開する言明を、証明を伴わないGoalの定義へ写したものである。L2b/cはこの外側の前提・結論を維持し、内部のQ付きの計算と型付けから導く。qは従来のCheck.Inputであり、NoFailCtxではない。前の節の全言明と併せてRV2の照合対象とする。

```lean
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

def checkExpr_soundGoal : Prop :=
  ∀ {q C Γ R p path e a ε}
    (hq : q.Sound) (he : e.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R)
    (h : checkExpr q .strict C Γ R p path e = .ok (a, ε)),
    HasType q.D q.B q.opPrim C Γ R p e a ε ∧
      a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms

def checkBlock_soundGoal : Prop :=
  ∀ {q C Γ R p path body a ε}
    (hq : q.Sound) (hb : body.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R)
    (h : checkBlock q .strict C Γ R p path body = .ok (a, ε)),
    HasBlock q.D q.B q.opPrim C Γ R p body a ε ∧
      a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms

def checkArms_soundGoal : Prop :=
  ∀ {q C Γ R p path arms a b ε}
    (hq : q.Sound) (ha : arms.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (hin : a.AtomsIn q.atoms) (hout : b.AtomsIn q.atoms)
    (h : checkArms q .strict C Γ R p path arms a b = .ok ε),
    HasArms q.D q.B q.opPrim C Γ R p arms a b ε ∧ ε.AtomsIn q.atoms

def checkClauses_soundGoal : Prop :=
  ∀ {q C Γ R path cs t ε actual}
    (hq : q.Sound) (hc : cs.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : t.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms)
    (h : checkClauses q .strict C Γ R path cs t ε = .ok actual),
    HasClauses q.D q.B q.opPrim C Γ R cs t ε ∧
      Eff.Sub actual ε ∧ actual.AtomsIn q.atoms

def checkTypes_soundGoal : Prop :=
  ∀ {q C Γ R path es ts ε}
    (hq : q.Sound) (he : es.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : Tys.AtomsIn q.atoms ts)
    (h : checkTypes q .strict C Γ R path es ts = .ok ε),
    HasTypes q.D q.B q.opPrim C Γ R es ts ε ∧ ε.AtomsIn q.atoms

def checkEach_soundGoal : Prop :=
  ∀ {q C Γ R path es a ε}
    (hq : q.Sound) (he : es.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ha : a.AtomsIn q.atoms)
    (h : checkEach q .strict C Γ R path es a = .ok ε),
    HasEach q.D q.B q.opPrim C Γ R es a ε ∧ ε.AtomsIn q.atoms

def checkHoleArgs_soundGoal : Prop :=
  ∀ {q C Γ R path args ts ε}
    (hq : q.Sound) (ha : args.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : Tys.AtomsIn q.atoms ts)
    (h : checkHoleArgs q .strict C Γ R path args ts = .ok ε),
    HasHoleArgs q.D q.B q.opPrim C Γ R args ts ε ∧ ε.AtomsIn q.atoms

def checkDict_soundGoal : Prop :=
  ∀ {q C Γ path d a}
    (hq : q.Sound) (hd : d.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (h : checkDict q C Γ path d = .ok a),
    DictEv.HasType q.D q.B C Γ d a ∧ a.AtomsIn q.atoms

def checkDicts_soundGoal : Prop :=
  ∀ {q C Γ path ds ts}
    (hq : q.Sound) (hd : DictEvs.AtomsIn q.atoms ds) (hΓ : Env.AtomsIn q.atoms Γ)
    (ht : Tys.AtomsIn q.atoms ts)
    (h : checkDicts q C Γ path ds ts = .ok ()),
    DictEv.HasTypes q.D q.B C Γ ds ts

def checkDef_soundGoal : Prop :=
  ∀ {q path d} (hq : q.Sound) (hd : d.AtomsIn q.atoms)
    (h : checkDef q path d = .ok ()),
    Def.WellTyped q.D q.B q.opPrim d

def checkImpl_soundGoal : Prop :=
  ∀ {q methods supers path id views}
    (hq : q.Sound) (hi : id.decl.AtomsIn q.atoms)
    (hn : ImplNamesComplete q id methods supers)
    (h : checkImpl q methods supers path id views = .ok ()),
    ImplDecl.WellTyped q.D q.B q.opPrim id.decl views

end Benitoite.Surface.Check
```

```lean
namespace Benitoite.Surface.CheckTables
open Benitoite.Release Benitoite.Surface Benitoite.Surface.CheckTools

def checkProgram_soundGoal : Prop :=
  ∀ {m : Materials} {S raw b select atoms}
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hdefs : ∀ n d, m.program.defs n = some d → d.body.AtomsIn atoms)
    (himpls : ∀ n id, m.program.impls n = some id → ImplBodiesAtoms atoms id)
    (hc : constructorsOk m = true)
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgram
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms) m m.names = .ok ()),
    CheckedUnder m.program
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms)

def checkProgram_emptyGoal : Prop :=
  ∀ {m : Materials} {S raw b select atoms}
    (hf : m.trustedFuns = []) (hi : m.trustedImpls = [])
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hdefs : ∀ n d, m.program.defs n = some d → d.body.AtomsIn atoms)
    (himpls : ∀ n id, m.program.impls n = some id → ImplBodiesAtoms atoms id)
    (hc : constructorsOk m = true)
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgram
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms) m m.names = .ok ()),
    m.program.WellTyped (builtins S (primEntries S raw) b)
      (makeOpPrim select)

end Benitoite.Surface.CheckTables
```

