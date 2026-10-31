# 今回の差し替え: 制約を正規形で読む

2026-10-31。型付けの制約の読み手を norm に揃える第三案を採る。Builtins/TypeAssumptions の欄と Val.shiftEAt 等の項の変換は保つ。

```lean
def SatAll (B : Builtins) (C : List TParam) (ts : List Ty) (tps : List TParam) : Prop :=
  ts.length = tps.length ∧ ∀ i t p, ts[i]? = some t → tps[i]? = some p → B.sat C t.norm p
-- PrimitiveAdmissible.admits : s.admits C (Ty.normTys ts)
-- V_Map / V_Set / ExternalCarrierEach.map / .set の鍵: B.sat C a.norm TParam.keyC

theorem Ty.renameTypes_shift_of_wf {nr nt nv a} (hw : Ty.WF nr nt nv a) (k c : Nat) :
  a.renameTypes (shiftIndex k c) = (shiftTypes k c a).norm

theorem Builtins.TypeAssumptions.sat_shiftTypes_raw {P B C C' Γ Δ a p k c}
  (h : Builtins.TypeAssumptions P B) (hr : TypeParamRenaming C C' (shiftIndex k c))
  (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C' Δ (shiftTypes k c a))
  (hs : B.sat C a.norm p) : B.sat C' (shiftTypes k c a).norm p

theorem Builtins.TypeAssumptions.admits_shiftTypes_raw {P B C C' Γ Δ ts b sg k c}
  (h : Builtins.TypeAssumptions P B) (hr : TypeParamRenaming C C' (shiftIndex k c))
  (hl : B.sig b = some sg) (ha : TypeAnnotations P C Γ ts)
  (hb : TypeAnnotations P C' Δ (ts.map (shiftTypes k c)))
  (hs : sg.admits C (Ty.normTys ts)) : sg.admits C' (Ty.normTys (ts.map (shiftTypes k c)))
```

決定の記録: 制約の判定の入力だけを正規形とする。TypeAssumptions に不変性を追加する案は信頼条件を強めるため捨てる。Val.shiftEAt を正規化する案は主定理の項の変換の意味を変えるため捨てる。SatAll.shiftTypes と値・型・行の置換は、元の Annotation の norm 保存と、norm と各変換の交換から導く。生の型引数と、述語の残る篩を正規形に限って拒否しない。前回の生の制約を要求した反例は、同じ入力を主定理で移動する正例へ反転した。

# 今回の差替え（取りまとめの第三案）

rawApply の refined の枝を `refined (rawApply a as) p` とする。as は篩の述語の束縛の外にあり、移動しない。ソース kind を型付けの前提へ足す案は主定理の導出を制限し、生の値置換案は Val.subst の意味を変えるため、いずれも採らない。SignatureInstance・V_Con・V_Dict の前提と Val.subst は保つ。

```lean
def rawApply (t : Ty) (as : List Ty) : Ty
-- refined a p => refined (rawApply a as) p

theorem rawApply_norm (t : Ty) (as : List Ty) :
  (rawApply t.norm (Ty.normTys as)).norm = (rawApply t as).norm

theorem rawApply_refined (a : Ty) (p : Pred) (as : List Ty) :
  rawApply (.refined a p) as = .refined (rawApply a as) p

structure SubstEnv.SameTypes (θ τ : SubstEnv) : Prop where
  types : ∀ i, (θ.types i).norm = (τ.types i).norm
  rows : θ.rows = τ.rows
  ranges : θ.ranges = τ.ranges
  values : θ.values = τ.values

theorem Ty.bind_sameTypes (a : Ty) {θ τ} (h : SubstEnv.SameTypes θ τ) :
  (a.rawBind θ).norm = (a.rawBind τ).norm

theorem Ty.subst_norm_images (a : Ty) (ts : List Ty) :
  a.subst (Ty.normTys ts) [] = a.subst ts []

theorem Ty.subst_norm_typeImages (a : Ty) (ts : List Ty) (es : List Eff) :
  a.subst (ts.map Ty.norm) es = a.subst ts es
```

旧反例の入力は、新定義では元の導出を持てない。typing-normalization-obstruction.lean の original_derivation_rejected で、V_Sub/V_Refine を含む全29場合を検査した。値kindの篩付きの像と、適切な型構成子の適用の正例も保つ。

# L00b.11 の完全署名と補助契約

## 再開時の差し替え契約（2026-10-31、取りまとめの判断1〜6）

以下を今回の実装の正とする。連言は順序を保ち、重複と falsity を残す。truth だけを除き、右に括って再構成する。関数は NamesWF を持つ toTel の像だけを fn へ戻す。依存する引数型を持つ列を非依存の fn に写さない。

```lean
def Pred.conjuncts : Pred → List Pred
def Pred.ofConjuncts : List Pred → Pred
def Pred.conjNorm (p : Pred) : Pred := Pred.ofConjuncts p.conjuncts
def Ty.refineNorm (a : Ty) (p : Pred) : Ty

structure FnView where
  names : List String
  params : List Ty
  result : Ty
  effect : Eff
  names_wf : NamesWF names params
def FnView.toTel (f : FnView) : Tel := Ty.toTel f.names f.params f.result f.effect
noncomputable def Tel.fnView? (t : Tel) : Option FnView
noncomputable def Ty.foldFn (t : Tel) : Ty
-- fnView? は toTel が t と等しい証人があるときだけ返す。
-- foldFn は some のとき fn、none のとき dependentFn t を返す。

abbrev Ty.Normal (a : Ty) : Prop := a.Canonical
def Tel.Normal (t : Tel) : Prop := Tel.norm t = t
-- Ty.Canonical と Eff.Canonical は固定点の既存名として残す。

theorem Pred.conjuncts_bind (ν : ObservationEnv) (p : Pred) :
  (predBind ν p).conjuncts = p.conjuncts.map (predBind ν)
theorem Pred.conjNorm_idem (p : Pred) : p.conjNorm.conjNorm = p.conjNorm
theorem Ty.norm_idem (a : Ty) : a.norm.norm = a.norm
theorem Tel.norm_idem (t : Tel) : Tel.norm (Tel.norm t) = Tel.norm t
theorem Eff.norm_idem (e : Eff) : e.norm.norm = e.norm
theorem Ty.norm_rawBind (θ : SubstEnv) (a : Ty) :
  (a.norm.rawBind θ).norm = (a.rawBind θ).norm
theorem Ty.norm_refined_truth (a : Ty) : (Ty.refined a .truth).norm = a.norm
theorem Ty.norm_toTel {ns ps r e} (hn : NamesWF ns ps) :
  (Ty.dependentFn (Ty.toTel ns ps r e)).norm = (Ty.fn ns ps r e).norm

-- 新しい導出の規則。新公理ではなく、帰納的な構文規則である。
-- Ty.LeQ.convert {Γ Φ a b} : a.norm = b.norm → Ty.LeQ Γ Φ a b
theorem TelLe.of_norm_eq {Γ Φ t u} (h : Tel.norm t = Tel.norm u) : TelLe Γ Φ t u
theorem HasTypeVQ.convert {P B Ψ Q C Γ Φ v a b}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (he : a.norm = b.norm)
  (hb : Ty.Annotation P C Γ b) : HasTypeVQ P B Ψ Q C Γ Φ v b
theorem HasTypeCQ.convert {P B Ψ Q C Γ Φ R m a b e L}
  (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (he : a.norm = b.norm)
  (hb : Ty.Annotation P C Γ b) : HasTypeCQ P B Ψ Q C Γ Φ R m b e L
```

Ty.norm の refined は子を正規化して refineNorm を使い、dependentFn は Tel.norm の後に foldFn を使う。fn はそのまま子を正規化する。Ty.bind/Eff.bind/Tel.bind は引き続き rawBind の後の norm である。embedTy_norm/embedEff_norm、冪等性、正規化と置換・移動の交換は言明を保って閉じ直す。rawApply_norm は冒頭の無制限な署名を使う。kind は適格な適用の逆転の入口として残す。

canonical_of_wf と、それを直接の理由とする「任意のWF型・型列は固定点」という言明は撤回する。WF・Sorted・Declared の norm による保存を置き、固定点を使う呼出し元には Normal を明示するか型付けの convert を使う。型付けの移動・値の相互置換・narrowing と TypedFacts は、LeQ.convert の場合を全て追加する。変更した補助の完全署名は公開APIの出力と本節へ随時確定し、未検査の前提として登録しない。

正規化で消える篩の下に cont がある不適格な型を参照可能としないため、補助の Ordinary は芯で cont を除く判断へそろえる。V_Var の条件も同じ判断を使う。WF は既にそのような refined を除いているため、WF な文脈から来る利用者の型付けを狭めない。`Ty.WF` と従来の最外の非contの条件から新しい Ordinary を導く補題を置き、この対応を検査する。最外の cont だけを除く Ordinary と、その正規化保存を無条件に両立させる案は採らない。

`Ty.assume a` は、芯が cont のとき空列、それ以外では芯から外へたどった `a.refinementPredicates` とする。適格な型では `Ty.assume_of_wf` により後者と一致する。truth を除き、連言の順序と重複を保つ。これにより norm の前後で事実の列が一致する。元の述語は `Entails.of_conjuncts`、分解した各事実は `Entails.conjuncts` で相互に導く。Γ/Φ を任意の意味上の前提へ置き換えず、有限の構文の事実列として維持する。

2026-10-31。B_WORK は `5fd3664ed92b4eb20de0ba422e9e55c825019aff`、指定ブランチは `m014/l00b.11` である。git の操作を行わない。共通の名前空間は `Benitoite.Release.Refinement` とする。冒頭は実装前に固定した署名である。群末の検査結果と後続へ残す範囲は末尾に記す。

## 公開する射影と構文の逆転

型の最外の篩だけを除く `Ty.core` は既存の定義を使う。要素型や参照内容の篩を除かない。

```lean
def Ty.listCore : Ty → Option Ty
def Ty.fnCore : Ty → Option Tel
def Ty.refCore : Ty → Option Ty

theorem TelClosure.trans {Γ Φ t u v}
    (h : TelClosure Γ Φ t u) (g : TelClosure Γ Φ u v) : TelClosure Γ Φ t v
theorem TelLe.toTel_effect {Γ Φ ns ps r e f}
    (h : Eff.Covers Γ Φ f e) :
    TelLe Γ Φ (Ty.toTel ns ps r e) (Ty.toTel ns ps r f)

theorem Ty.LeQ.listCore {Γ Φ a b x}
    (h : Ty.LeQ Γ Φ a b) (ha : a.listCore = some x) :
    ∃ y, b.listCore = some y ∧ Ty.LeQ Γ Φ x y
theorem Ty.LeQ.listCore_right {Γ Φ a b y}
    (h : Ty.LeQ Γ Φ a b) (hb : b.listCore = some y) :
    ∃ x, a.listCore = some x ∧ Ty.LeQ Γ Φ x y
theorem Ty.LeQ.fnCore {Γ Φ a b t}
    (h : Ty.LeQ Γ Φ a b) (ha : a.fnCore = some t) :
    ∃ u, b.fnCore = some u ∧ TelClosure Γ Φ t u
theorem Ty.LeQ.fnCore_right {Γ Φ a b u}
    (h : Ty.LeQ Γ Φ a b) (hb : b.fnCore = some u) :
    ∃ t, a.fnCore = some t ∧ TelClosure Γ Φ t u
theorem Ty.LeQ.names_eq {Γ Φ a b t u}
    (h : Ty.LeQ Γ Φ a b) (ha : a.fnCore = some t) (hb : b.fnCore = some u) :
    t.names = u.names

theorem Ty.LeQ.refCore {Γ Φ a b x}
    (h : Ty.LeQ Γ Φ a b) (ha : a.refCore = some x) :
    ∃ y, b.refCore = some y ∧ x.norm = y.norm
theorem Ty.LeQ.refCore_right {Γ Φ a b y}
    (h : Ty.LeQ Γ Φ a b) (hb : b.refCore = some y) :
    ∃ x, a.refCore = some x ∧ x.norm = y.norm

theorem Eff.memFail_single_iff (a b : Ty) :
    (Eff.singleFail a).memFail b ↔ a.norm = b.norm
```

listCore/refCore は最外の篩を再帰して List/Reference の内容を返す。fnCore は fn を toTel に写し、dependentFn の列を返す。逆向きも用意し、推移の中間型を存在量化して保持する。TelClosure の結論を意味上の包含や独自の構造だけへ置き換えない。

## 値の逆転と canonical forms

```lean
theorem HasTypeVQ.inv_list {P B Ψ Q C Γ Φ v T vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .list vs) :
    ∃ a, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧
      ∃ b, T.listCore = some b ∧ Ty.LeQ Γ Φ a b

theorem HasTypeVQ.inv_closure {P B Ψ Q C Γ Φ v T runtime body}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .closure runtime body) :
    ∃ t u, Ty.Annotation P C Γ (.dependentFn t) ∧
      Tel.RuntimeShape runtime t ∧ DependentClosureTy P B Ψ body t ∧
      T.fnCore = some u ∧ TelClosure Γ Φ t u

theorem HasTypeVQ.canonical_ref {P B Ψ Q C Φ v T a}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ha : T.refCore = some a) :
    ∃ l b, v = .loc l ∧ Ψ l = some (.ref b) ∧ b.norm = a.norm
```

V_Sub の鎖を帰納的に消去し、List は元の Each と要素 LeQ、閉包は元の本体の型付けと TelClosure、Reference はストアの実際の内容型と正規化後等号を返す。受信前の Outcome.Carrier は HasTypeVQ の導出とみなさず、受信後の元の型の HasTypeVQ だけを逆転する。

## kind と適用

```lean
theorem ProperApply.list_inv {a as x}
    (h : ProperApply a as (.list x)) : a = .ctor .list ∧ as = [x]
theorem ProperApply.fn_impossible {a as ns ps r e} :
    ¬ ProperApply a as (.fn ns ps r e)
theorem Ty.HasKind.not_refined_constructor {P K a p n} :
    ¬ Ty.HasKind P K (.refined a p) (.constructor n)
theorem rawApply_list_inv {P K a n as x}
    (hk : a.HasKind P K (.constructor n)) (hn : as.length = n)
    (he : rawApply a as = .list x) : a = .ctor .list ∧ as = [x]

theorem TypeImagesKinded.list_inv {P K L θ i n as x}
    (h : TypeImagesKinded P K L θ) (hi : K[i]? = some (.constructor n))
    (hn : as.length = n) (he : rawApply (θ i) as = .list x) :
    θ i = .ctor .list ∧ as = [x]
```

既存の TypeImagesKinded.apply と rawApply_proper の7形を使う。constructor の像は ctor/tvar だけであり、篩・base・適用済みの像を除く。value の像に篩を許す条件は保つ。rawApply は全域のまま、refined の枝だけを下の頭へ適用する再帰へ改める。ctor/tvar でも refined でもない頭の既定枝はその頭を返す。

## 今回閉じた補助契約

以下は構文上の像を構成する補助であり、実行時の値の存在や外部状態の仮定を追加しない。完全な公開署名は [public-api.lean](public-api.lean) と [public-api.log](public-api.log) にも出力する。全差分の候補と、コンパイルできず署名・公理を監査できないモジュールは [source-delta.json](source-delta.json) と [axioms-summary.json](axioms-summary.json) で区別する。

```lean
theorem Ty.sorted_norm {Γ a} (h : Ty.Sorted Γ a) : a.norm.Sorted Γ
theorem Ty.Declared.norm {P C Γ a} (h : Ty.Declared P C Γ a) :
  Ty.Declared P C Γ a.norm

theorem Ty.substV_of_wf_zero {nr nt a} (h : a.WF nr nt 0) (ν : ObservationEnv) :
  a.substV ν = a.norm

theorem instantiatedTel_subst {nt t} (h : (Ty.dependentFn t).WF 0 nt 0)
  (ts es) (ν : Nat → Val) :
  substTyValues ν (.dependentFn (instantiatedTel t ts es)) =
    (Ty.dependentFn (instantiatedTel t (ts.map (substTyValues ν))
      (es.map (substEffValues ν)))).norm

theorem HasTypeVQ.norm {P B Ψ Q C Γ Φ v a}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (ha : Ty.Annotation P C Γ a) :
  HasTypeVQ P B Ψ Q C Γ Φ v a.norm
theorem HasTypeCQ.norm {P B Ψ Q C Γ Φ R m a e L}
  (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (ha : Ty.Annotation P C Γ a) :
  HasTypeCQ P B Ψ Q C Γ Φ R m a.norm e L

noncomputable def BuilderKind.norm : BuilderKind → BuilderKind
-- list a => list a.norm、string/bytes => そのまま
-- LocalRef.HasKind.normal : HasKind Ψ L r b → HasKind Ψ L r b.norm

theorem substKind_closed {b : BuilderKind} (h : LocTy.WF (.builder b)) (ν : Nat → Val) :
  substKind ν b = b.norm

theorem HasTypeTelArgsQ.normal {P B store Q C Γ Φ vs t a e}
  (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e) (hn : t.Normal) :
  a.norm = a ∧ e.norm = e

theorem HasTypeTelArgsQ.instantiate {P B store Q C Γ Φ vs t a e}
  (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e) (hn : t.Normal) :
  Tel.instantiate t vs = some (a, e)

theorem HasTypeTelArgsQ.arguments {P B store Q C Γ Φ vs t a e}
  (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e) (hn : t.Normal) :
  ∃ as, Tel.arguments t vs = some (as, a, e) ∧ HasTypeVsQ P B store Q C Γ Φ vs as
```

ShiftCancellation は、値の移動を打ち消す観測環境を構成する。Sorted・Declared・References の移動の逆方向は、この環境に sort と宣言の証拠を与えて証明する。未解決の外部状態を仮定しない。ValueRegularity・DeclaredTransport・ValueReferences は、この逆方向と toTel の逆転を使って foldFn の norm 保存を閉じた。型・行の像の正規化は ValueInstantiation の元の無制限の署名を保つ。

## 決定の記録

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| rawApply | refined の下の頭へ同じ引数を渡す。述語だけが束縛の内側なので引数は移動しない | ソース kind を SignatureInstance/V_Con/V_Dict の新しい前提にする案。利用者の導出を制限する |
| 項内の値置換 | Val.subst を保ち、正規化した像が適用と交換することを証明する | 項内の型引数だけ生の値置換にする案。Val.subst の意味が変わる |
| 像の合同性 | SameTypes の4欄と無制限な bind_sameTypes/subst_norm_images を復元する | kind を追加し構成子位置の生の一致を要求する前回案。新しい rawApply では不要 |
| 連言 | 芯から外への有限列、truth 除去、右結合、順序・重複・falsity 保持 | 並べ替え、重複除去、論理同値による等号 |
| 関数 | NamesWF を持つ toTel の像を、一意性を証明して fn に戻す | 全 fn を dependentFn にする案。embedTy_norm の等号を保ちにくい |
| 固定点 | Normal と norm_idem を使う | 任意の WF 型の固定点。Unit{true} で偽 |
| 型付けの変換 | LeQ.convert と既存の V_Sub/C_Sub を使う | 新しい公理、意味上の Subtype だけの結論 |
| facts | refinementPredicates に揃え、Entails で分解・再構成する | 旧の括り方が残る列で生の等号を主張する案 |
| Ordinary | core の cont を除き、WF と旧条件から接続する | 不適格な refined cont まで参照可能にする案 |
| builder の kind | normal の一方向の規則を追加し、閉じた要素型の norm を読む | 任意の正規化後等号による対称変換。norm 後の WF から生の WF は戻せない |
| 実引数列 | 生の done の結果を保つ補題は Normal を前提にする。外部呼出しの bind 後には norm_idem で供給する | done の raw な結果まで無条件に正規形とする案。具体的な偽の証明を保持 |
| ソース契約の二案 | [source-kind-contract.md](source-kind-contract.md) の冒頭に不採用と記す | この二案を判断待ちのままと扱うこと |

## 最終の規則、導出可能性、場合の数

共通の暗黙引数は `P : Program`、`B : Builtins`、`Ψ : StoreTy`、`Q : NoFailCtx`、`C : List TParam`、`Γ : Ctx`、`Φ : List Pred`、`R R' : Option Ty`、`L : LocalCtx` とする。次の四つは帰納的規則であり、Lean の公理ではない。

```lean
HasTypeVQ.V_Normal :
  HasTypeVQ P B Ψ Q C Γ Φ v a → HasTypeVQ P B Ψ Q C Γ Φ v a.norm
HasTypeCQ.C_Normal :
  HasTypeCQ P B Ψ Q C Γ Φ R m a e L → HasTypeCQ P B Ψ Q C Γ Φ R m a.norm e L
HasTypeCQ.C_ResumeNorm :
  Γ[i]? = some (some (.cont b t e)) →
  HasTypeVQ P B Ψ Q C Γ Φ v b.norm → Ty.Declared P C Γ t.norm →
  HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.var i) v) t.norm (Eff.norm e) L
HasTypeCQ.C_ResumeLNorm :
  Ψ l = some (.cont b t e R') → R'.map Ty.norm = R.map Ty.norm →
  HasTypeVQ P B Ψ Q C Γ Φ v b.norm → Ty.Declared P C Γ t.norm →
  HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.loc l) v) t.norm (Eff.norm e) L
```

次は規則から導く補題と、その互換の名前である。独立した構成子 `C_DependentAppNorm` は削除した。

```lean
theorem HasTypeCQ.dependentApp_normalized {P B Ψ Q C Γ Φ Δ R f args t a e}
  (hv : HasTypeVQ P B Ψ Q C Γ Φ f (Ty.dependentFn t).norm)
  (hs : HasTypeTelArgsQ P B Ψ Q C Γ Φ args t a e) :
  HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) a e Δ

theorem HasTypeCQ.C_DependentAppNorm {P B Ψ Q C Γ Φ Δ R f args t a e}
  (hv : HasTypeVQ P B Ψ Q C Γ Φ f (Ty.dependentFn t).norm)
  (hs : HasTypeTelArgsQ P B Ψ Q C Γ Φ args t a e) :
  HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) a e Δ
```

証明は `HasTypeTelArgsQ.resultAnnotation`、`normInput`、`toTelValues` を使う。Tel の正規形に FnView がある場合は C_App、ない場合は C_DependentApp を使い、結果の Annotation と C_Sub/LeQ.convert で元の結果・効果へ戻す。FnView の二場合を閉じた。結論の Annotation を外から仮定しない。

| 規則 | 必要な入口 | V_Sub/C_Sub と convert だけでは足りない理由 |
|---|---|---|
| V_Normal | 型付き像、V_Var、閉じた場所・署名の型の正規化 | 元の V_Var は行き先の Sorted/Declared を持たない。WF だけから Annotation は出ない。正例と Sorted の否定を normalized-rules-boundary に置いた |
| C_Normal | 相互置換の C_Normal の場合、任意の計算結果を正規形へ変換する入口 | C_Sub に必要な行き先の Sorted がない計算も元の規則で型付く。同入力の C_Resume から正規化する正例を置いた |
| C_ResumeNorm | 生の継続束縛を保つ up・params・narrowing の後の再開 | 値の像は b.norm を持つが、生の b へ戻すための Annotation は一般にはない。入力の正規化は C_Normal では変更できない |
| C_ResumeLNorm | 生の格納契約を保つ閉じた継続場所と、置換後の R の照合 | C_Sub/C_Normal は R を変えない。some(Unit{true}) を保持した場所と some Unit を読む計算を、元の置換主定理の全前提から構成した |
| C_DependentAppNorm | 正規化した関数型での適用 | TelArgs の終端から結果の Annotation を取り出せるため、既存の二つの適用と C_Sub で導出できる。構成子を削除し補題だけ残す |

`Ty.Annotation.norm` は WF/Sorted/Declared を個別に保存する。再開の結果の WF は、変数版では Ctx.WF の lookup、場所版では StoreTy.WF の lookup から元の t の WF を取り出し、Ty.wf_norm で得る。Declared は各規則の前提で照合し、元の Sorted があるときは Ty.sorted_norm で保存する。元の規則が要求しなかった Sorted を無条件に導いたことにはしない。三族の公開主定理の前提と結論は変更せず、Builtins の信頼条件の欄も保った。

| 判断 | 従来 | 最終 | 閉じた場合 |
|---|---:|---:|---|
| Ty | 21 | 21 | 正規化、交換、Sorted/Declared/References、逆転 |
| Ty.LeQ | 12 | 13 | convert を含む移動・置換・narrowing、TypedFacts、逆転 |
| TelLe / TelClosure | 2 / 2 | 2 / 2 | 正規化後の等号、推移、names_eq |
| HasTypeVQ | 28 | 29 | V_Normal を含む全場合 |
| HasTypeCQ | 21 | 24 | C_Normal・C_ResumeNorm・C_ResumeLNorm を含む全場合 |
| ImageOk | 3 | 4 | hidden を含む移動・置換・narrowing・捕捉 |
| 三族の対象の合計 | 71 | 76 | 各族で5増。値1＋計算3＋ImageOk1 |
| LocalRef.HasKind | 2 | 3 | normal を含む移動・置換・resolve。71の場合表の外 |
| ProperApply | 7 | 7 | kind を使う適切な適用の逆転 |

場合の数は axioms.lean が Lean の構成子情報から検査する。L40 へ残すのは、当初からの全値・計算の逆転、全 canonical forms、data の検証済み変性、保持対象と Request の全接続だけである。D07 の本体、O001/O007、三族と閉包の追随は L00b.11 で閉じた。

## 補助契約の最終決定

| 対象 | 採った形と理由 | 捨てた形 |
|---|---|---|
| rawApply | refined の下へ再帰し、型引数を保持する。述語の束縛に引数は入らない | ソース kind を SignatureInstance/V_Con/V_Dict の前提に足す案、生の値置換で項の型引数を変換する案。前者は導出を制限し、後者は Val.subst を変える |
| 制約 | SatAll・鍵・PrimitiveAdmissible.admits は正規形を読む | TypeAssumptions の不変性の追加、Val.shiftEAt の正規化。信頼条件や項の変換は変えない |
| valContent | B.valContent の生の表を保ち、V_CheckedRequest/CheckedWitness.request/AtCallAdmissible の静的な入力照合は型の norm を読む | 表の差し替え、閉じた WF 型を固定点とする案。元の入力の証拠は V_Normal で新しい読み手に渡せる |
| ImageOk.contVar | 実際の cont の lookup と、その norm が置換後の cont に等しい証拠を保持 | 文脈の生の継続を正規形に限定する案、WF を固定点とする案 |
| ImageOk.hidden | ¬a.Ordinary と、a が生の cont でないことを保持する。一般の up/params の読めない束縛を扱う | upValue などへ新しい WF 前提を足す案。hidden と WF が両立しないことを境界で証明した |
| Ordinary / assume / hideConts | cont の芯を読めなくする。assume は順序付きの原子的連言の列。WF な型では assume_of_wf が refinementPredicates との一致を保証する | 不適格な refined-cont の fact や通常値の型付けを正規化後にも許す案。WF から来る形は狭めない |
| narrowing の継続 | 私有 ContImages は同じ生の束縛、または正規形の等号・実際の cont・元の型の Annotation を持つ | cont の生の等号を LeQ.convert から無条件に導く案。元の結果へ戻す Annotation は Narrows.here の元の前提から得る |
| 閉包の注釈 | SubstOk.telAnnotation は Tel.bind の外側に生の dependentFn を付けた注釈を保存する | 正規化で fn になった型から構造的に dependentFn を取り出す案 |
| 閉じた補助補題 | bind/close の結果を norm として読む。固定点が要る入口だけ Normal を明記する | WF を固定点とする旧補題。偽である具体例を normalization-retractions に残した |
| 継続場所の R | 生の格納 R' と現在の R は norm 後の等号で照合する。ストアの定義・格納値は保つ | 生の R の等号を返す旧 resume_location_contract。全前提付きの置換の正例と旧結論の否定が同じ入力で成立する |

最後の変更は、偽と Lean で示した補助補題の改訂として行った。主な三族の定理や実行時の外部状態を改訂したものではない。受信前の Outcome.Carrier と、受信後の元の型を持つ HasTypeV の区別も保つ。

## 撤回した偽の補助署名と置き換え

| 旧署名の主張 | 置き換えと否定の根拠 |
|---|---|
| 任意の WF 型・型列は norm の固定点 | Normal と norm_idem。Unit{true} が反例 |
| 閉じた WF 型・構築器・Tel の値置換は生のまま | Ty は a.norm、Tel は Tel.norm t、構築器は norm を返す。closed_value_subst_not_raw / closed_builder_subst_not_raw / closed_tel_bind_not_raw |
| instantiatedTel の dependentFn の像は生の dependentFn | norm 後の等号と Tel の等号。空の非依存関数でも fn へ畳まれる |
| renameTypes と生の shiftTypes の等号 | shiftTypes の後の norm。raw_renameTypes_not_raw_shift |
| TelArgs.normal/instantiate/arguments は元の Tel が非正規形でも生の結果を保存 | Tel.Normal を前提にする。done raw empty で tel_normal_without_premise_false 等が成立 |
| HasTypeTelArgsQ.of_arguments は Tel.Normal なしで使える | Tel.Normal を明記。of_arguments_without_normal_false は全入力と結論の否定を構成 |
| ClosureTy.pure は a/R の Normal なしで使える | a.Normal と、some r=R の r.Normal を明記。pure_without_normal_false / pure_without_return_normal_false |
| LeQ が contView の生の成分の等号を保存 | contView の norm 後の等号。cont Unit (Unit{true}) empty と cont Unit Unit empty は正規形が等しく生の形が異なる |
| resume_location_contract は格納 R と現在の R の生の等号を返す | ∃b t e R', lookup(.cont b t e R') ∧ R'.map norm=R.map norm。old_resume_location_contract_false |
| assume の事実は不適格な refined-cont からも得られる／source_variable は型付く | その芯の assume は空、source_variable_untypable。NarrowingObstruction の不適格な入力に限定した訂正 |

rawApply_norm と subst_norm_images の限定版、以前の型移動の否定は、今回の第三案では不要になった。無制限の交換則と元の操作値の移動を正例として証明した。これらを未解決の反例として残さない。

## 完全署名の照合と後続

本書に主要な契約を列記し、公開する全定義・補題の暗黙引数を含む完全署名は [public-api.lean](public-api.lean) がコンパイル済み環境から列挙する。[public-api.log](public-api.log) と [large-records.md](large-records.md) に全出力の大きさ・SHA-256 を記録する。監査対象は Refinement 全129モジュールと Benitoite の集約モジュールであり、新規・変更対象をすべて含む。私有・生成宣言の公理は axioms.lean で別に監査する。

L00b.13 は未着手である。以後は正規形の制約、静的な valContent の読み手、継続の正規化した入力と R の等号、新しい四規則を使う。L20 の Rust 検査器でも同じ正規形で照合し、元の注釈・格納メタデータは保持する。生の型で Builtins の sat/admits を読み直さない。後続の全状態の保存では、StoreOk の下で生の等号を導いて連結に使う。ContTy.end_normal が格納した継続の末尾の R の正規形を、ClosureTy.return_normal が現在の R の正規形を与え、resume_raw_return で生の R の等号へ戻す。


## RV-L00b.11 への対応（2026-11-01）

取りまとめの判断に従い、中1・中2を同じ作業で修正した。Semantics の E_Prim/E_Err の delta、E_IO/E_IOErr/E_Exit の ioResponse は `Ty.normTys ts` と `es.map Eff.norm` を読む。Step の delta と IO oracle も同じ入力を読む。項の `.prim b ts es rs`、rs、BuiltinArgs の Canonical、Builtins と ResponseAssumptions の欄、Val.subst/Val.shiftEAt は保つ。

CellOk.val は `HasTypeV P B Ψ [] [] [] v a.norm` を読む。StoreOk に Sorted/Normal を足さず、CellOk の done/thunk/cont/used も変えない。Ty.Normal は Ty.Canonical の別名とし、固定点の定義を一つにした。今回、型付けや遷移の構成子の増減はない。軽4の全面ビルドの時間は取りまとめが work で確認する。

```lean
theorem instantiatedTel_norm_images (t : Tel) (ts : List Ty) (es : List Eff) :
  instantiatedTel t (Ty.normTys ts) (es.map Eff.norm) = instantiatedTel t ts es

theorem TypeArgsKinded.norm {P C ts ks} (h : TypeArgsKinded P C ts ks) :
  TypeArgsKinded P C (Ty.normTys ts) ks

theorem SignatureInstance.norm_images {P C Γ t ks ts es}
  (h : SignatureInstance P C Γ t ks ts es) :
  SignatureInstance P C Γ t ks (Ty.normTys ts) (es.map Eff.norm)

theorem NoFail.norm {Q e} (h : NoFail Q e) : NoFail Q e.norm

theorem PrimitiveAdmissible.norm {C nv s Q ts es}
  (h : PrimitiveAdmissible C nv s Q ts es) :
  PrimitiveAdmissible C nv s Q (Ty.normTys ts) (es.map Eff.norm)

theorem HasTypeTelArgsQ.effect_wf {P B Ψ Q C Γ Φ ws t a e}
  (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e) : e.WF 0 C.length Γ.length

theorem BuiltinArgs.normalized {P B Ψ b sg ts es rs ws a e}
  (ha : PrimitiveAdmissible [] 0 sg Qempty ts es)
  (hr : B.RangeAdmissible b sg rs)
  (hs : SignatureInstance P [] [] (Tel.instR rs sg.tel) (sg.tparams.map TParamDecl.kind) ts es)
  (hw : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel (Tel.instR rs sg.tel) ts es) a e)
  (hg : ∀ w ∈ ws, w.Ground) :
  BuiltinArgs P B Ψ b sg (Ty.normTys ts) (es.map Eff.norm) rs ws a e

theorem CellOk.val_write {P B σ Ψ l a b v}
  (hl : Ψ l = some (.ref b)) (he : b.norm = a.norm) (hn : a.Normal)
  (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
  CellOk P B σ Ψ l (.val v)

theorem CellOk.val_read {P B σ Ψ l a b v}
  (h : CellOk P B σ Ψ l (.val v)) (hl : Ψ l = some (.ref b))
  (he : b.norm = a.norm) (hn : a.Normal) : HasTypeV P B Ψ [] [] [] v a

theorem StoreOk.reference_read {P B σ Ψ μ l a b v}
  (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.ref b))
  (hc : μ l = some (.val v)) (he : b.norm = a.norm) (hn : a.Normal) :
  HasTypeV P B Ψ [] [] [] v a

theorem DependentClosureTy.normal {P B Ψ q t} (h : DependentClosureTy P B Ψ q t) : t.Normal

theorem Capture.closeRAt_normal {cap : Capture} {n : Nat} {R : Option Ty} {r : Ty}
  (h : cap.closeRAt n R = some r) : r.Normal

theorem ClosureTy.return_normal {P B Ψ ps R q a e} (h : ClosureTy P B Ψ ps R q a e) :
  ∀ r, R = some r → r.Normal

theorem closeR_normal {cap : Capture} {R : Option Ty} {r : Ty}
  (h : cap.closeR R = some r) : r.Normal

theorem ContTy.empty_ret {P B σ Ψ R ε k a b Eb Re}
  (h : ContTy P B σ Ψ R ε k a b Eb Re) (hk : k = []) : R = Re

theorem ContTy.end_normal {P B σ Ψ R ε k a b Eb Re}
  (h : ContTy P B σ Ψ R ε k a b Eb Re) (he : EndsWithHandle k) :
  ∀ r, Re = some r → r.Normal

theorem resume_raw_return {P B σ Ψ μ l b t e r R k}
  (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) (hμ : μ l = some (.cont k))
  (he : r.map Ty.norm = R.map Ty.norm) (hR : ∀ x, R = some x → x.Normal) : r = R
```

step と Step の対応は、影響を受ける5場合の `step_prim_val`・`step_prim_err`・`step_io_val`・`step_io_err`・`step_io_exit` を本番に置いた。各補題は同じ raw の q.view、正規化した delta または IO oracle/応答、既存の kind と NoHandler の条件から、step の計算結果と Step を同時に返す。`NoHandler.splitHandler_none` も本番に置いた。これらの全引数を含む完全署名は public-api の出力へ含める。Refinement 全体の step_sound の新設や旧主定理の変更は行わない。

### 完了条件の正例

- review-builtins-boundary の original_args_normalized は、レビューと同じ delta=none の表と `.prim "p" [Unit{true}] [] []` に対し、正規化した型・行引数で BuiltinArgs を作る。args_rejected の否定自体は正しく、rv-11-primraw は読み取り専用の負の入力として再検査する。
- delta_entry/io_entry は応答仮定の全欄を構成した表を使い、delta_typed/io_exists の応答から元の raw の値の Step と step の結果を導く。元の delta=none の表に成立しない応答仮定を置かない。非空の行引数についても instantiatedTel_norm_images の入口を置いた。
- review-store-boundary の store_ok と write_and_read は、格納型が Unit{true} の StoreOk を構成し、実際の canonical_ref から得た等号で CellOk.val_write と StoreOk.reference_read を使う。結論の型付けや Sorted/Normal のストア全体の不変条件を仮定しない。
- review-lambda-boundary は rv-11-lam の一引数の例を保存する。実際の closeVal(.lam ["x"] [Unit{true}] body) を fn ["x"] [Unit] Unit で読み、inv_closure と DependentClosureTy.normal を使う。

### 義務の具体化

| 送り先 | 義務 |
|---|---|
| L00b.13 / L20 / L40 | CellOk.val の読書きは正規化後の等号と値の型の Normal から作る。継続は StoreOk の下で生の等号を導いて連結に使う。ContTy.end_normal・ClosureTy.return_normal・resume_raw_return を使い、R の付け替えの76場合の補題を追加しない |
| L00b.15 | D28 の新旧対照に、制約の読み手の変更（sat/admits を norm/normTys で読むこと）、V_Normal/LeQ.convert 等による導出の増加、組込み遷移の信頼条件へ渡す型・行の入力の正規化、CellOk.val の a.norm への変更を列記する。欄名が同じことだけを前提の維持と呼ばない。01-12 の写しへも同じ変更を反映する |
| L60 | 実表の sat・admits を正規形の上で定め、D28 の仮定の充足と新旧対照を確認する。delta/ioResponse に渡す型と行は正規形であり、BuiltinArgs の Canonical を外して量化を広げない |
| L20（Rust の検査器への対応） | fnView? の決定手続きと、Lean の `∃ f : FnView, f.toTel = t` による存在の定義との一致を示す。段ごとの移動を戻せること、NamesWF、一意性を照合する |
| 取りまとめ | 軽4の全面ビルドの時間と探索上限の影響を work で読む。遅い宣言があれば宣言単位の set_option を検討する |
