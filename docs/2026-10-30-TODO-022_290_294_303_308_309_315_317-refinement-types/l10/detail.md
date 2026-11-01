# L10: 共通の定義と葉の起動単位（レビュー処置後の下書き）

2026-11-01、RV-L10-plan 再レビュー処置版。計画担当の下書きであり、実装と起動の承認を表さない。[共通依頼文](../implementation-request.md)を最初に読み、[plan](../plan.md)の指定された節、L00b の最終対照と申し送り、現在の Lean の順に照合した。指定ブランチは `m014/l10-plan`、B_WORK は `b63a091da90626d13f4d079580728d8d8d3cde49` である。いずれも起動依頼の値を記し、git による照合・変更をしていない。

本書のソースのパスはリポジトリの根からの相対パスである。`R/` は `formal/Benitoite/Release/Refinement/`、`O/` は旧 `formal/Benitoite/Release/`、`I/` は `formal/Benitoite/Interval/`、`S/` は `formal/Benitoite/Shared/` を表す。宣言名は、断らない限り `Benitoite.Release.Refinement` の名前空間に属する。コード枠の「予定」は定義・言明の案であり、今回 Lean で型検査した署名ではない。既存の宣言と区別して読む。

## 入口の点検と既済みの差引き

L00b のレビューと設計者の了承は、plan「計画の変更と取りまとめへの確認点」の L00b 受入の行を正とする。状態代表は閉じた4・一部2、行き詰まり0であり、8件の見直しと guard の偽の事実を後続腕へ渡さない判断も了承済みである。これは L10 の詳細の独立レビューを済ませたことではない。前回までの独立レビューは条件付き可で、再レビューの変更節の確認を取りまとめが行い、段の表とO行へ段別の判定・保存先を追記してから起動する。全体の再レビューは置かない。

U01 は README「設計者の決定」の 2026-10-30 の計画了承、および decisions 末尾の「設計者の回答」で Nat の de Bruijn と WF に確定している。実配置は `R/Types.lean` の `Ty.tvar`・`Ty.tapp`、`R/TermSyntax.lean` の `Term.var`、`R/ScopeSyntax.lean` の `RangeIx.rvar`、`R/Context.lean` の `SubstEnv`・`Ty.WF`・`Eff.WF` で確認した。型・行・範囲・値の四名前空間と self の区別を引き継ぎ、Fin への変更を起動条件へ戻さない。U08/U09 も回答済みであり、L10 が再選択しない。

既定 import は `formal/Benitoite.lean` で確認した。旧 `Release.Theorems`・`Model`・`ModelHttp`・`ModelTargets` と新しい判断・葉を並置し、Shared 三モジュールと区間・新旧の adapter を含む。L00b.15 の最後の build/A-L は [その results](../l00b.15/results.md)の証拠であり、今回再実行した証拠ではない。

| L10 の元の項目 | 読んで確認した既存のファイルと定義 | 差し引く範囲／L10 に残す範囲 |
|---|---|---|
| 全 sort・measure・有限構文 | `R/ScopeSyntax.lean` の `Sort`・`Measure`・`FieldRef`、`R/TermSyntax.lean` の `Term`・`Pred`・`VarsIn`・`Source`、`R/Context.lean` の `Term.HasSort`・`Pred.Sorted` | 全 sort の構成子と移送を再作成しない。sort/measure の提供表と否定の制限の対応を .01 で確定する |
| refined・依存列・Γ/Φ・WF | `R/Types.lean` の `Ty`・`Tel`、`R/Context.lean` の `WF`・`Ctx.facts`、`R/Context/WF.lean` の `Ordered`・`Regular` | 定義を再作成しない。形成の一般化は L20 G04 等。効果の再帰的な有限支持は別に .31〜.51 で置く |
| 平坦化・true 消去・関数の正規化 | `R/Conjunction.lean`、`RefinementNormalForm.lean`、`FunctionNormalForm.lean`、`Normalize.lean` の `conjNorm`・`refineNorm`・`foldFn`・`Ty.norm_idem`・`embedTy_norm` | 正規化を作り直さない。有限支持を入力にする比較・正規化との一致だけを残す |
| 型付き像・移動・値置換・narrowing | `R/TypingShift.lean` の `shift_values`、`TypeShiftTyping.lean` の `shift_types`、`SubstTyping.lean` の `subst`・`subst_under_none`、`Narrowing.lean` の `narrow`、`EffectCover.lean` の `Covers.bind`・`Sub.bind` | 値29・計算24を含む相互76構成子について L00b が閉じた場合を差し引く。76は遷移の数と別である。新しい規則を加える場合だけ同じ群で追随する |
| 外部の構文・遷移・応答 | `R/Syntax.lean` の `Ty.external` を読む宣言表・`Val.externalRef`・`externalHandle`・`Comp.externalCall`、`R/External.lean` の `Program.ExternalWF`、`R/Semantics.lean` の `E_ExternalApply`・`E_External`・`E_ExternalErr`、`R/Step.lean` の `step`、`ExternalResponse.lean` の三条件、`ExternalConnection.lean` の受信の葉 | 構成子と carrier の受信後検査は既存。実表・三モデル・全保存は L60/L20/L70。L10 は .01 で照合するだけ |
| σ・At・範囲付き値 | `R/ScopeSyntax.lean` の `PathEnv`、`Preparation.lean` の `Required`・`Ready`・`InitialPrepared`、`AtPrepare.lean` の `groundVal`、`Typing.lean` の `V_Checked`・`V_CheckedRequest`・`V_CheckedAt`、`Semantics.lean` の PathBases/At の遷移 | 構成子・計算可能前提・固定した σ の配置は既存。同じ要求・端点の旧導出の葉だけ .30 に残す。全 σ の所属・必要束縛の準備は L50 |
| 状態・捕捉 | `R/Typing.lean` の `CaptureOk`・`ClosureTy`、`R/RuntimeSyntax.lean` の `Frame`・`Cell`・`State`、`R/StateTyping.lean` の `ContTy`・`CellOk`・`StoreOk`・`StateTyE`・`StateTy` | 全構成子を差し引く。K_Update の Annotation、腕の観測の添字、捕捉環境を保持する方式を変更しない。全状態の葉は G/H、主定理は L70 |
| 幅・Byte・Decimal・Top・Request の新前提 | `R/Syntax.lean` の `ConstOK`、`R/Typing.lean` の `V_Const`・`V_Bytes`・`V_CheckedRequest`、`HeldValues.lean` の `inv_checkedRequest`・`checkedRequest_widen`、`ModelHttp.lean` の `valueRun_request` | 前提の導入と保持要求の逆転は既存。旧入力の表現可能性と保持を .26〜.30、数値 adapter を .54、コメントと07-04の区別を .56 で扱う |
| 共有層の分離・二成分 | `S/Integer.lean`・`Interval.lean`・`Approximation.lean` の `IntegerValue`・`Interval`・`ValueApprox`・`FlowApprox`・`EvalResult`、`I/ApproxAdapter.lean` の `normalToShared_mem` | 分離と構成子を差し引く。実解析の BaseApprox の写し、逆方向、空の判定と WF は .52〜.54 |
| 旧導出の埋め込み | `R/Le.lean` の `embedCovers`・`embedLe`、`R/Embedding.lean` の `embedVal`・`embedComp`・`embedProgram`・`embedState`、`R/Context.lean` の `embed_wf` | 構文の変換・部分型の片方向の橋を差し引く。kind 表付き宣言と適格性、値の葉、限定等号を .24〜.30/.55 で補う。全型付け・状態の埋め込みは未完。単純な一段遷移の可換性は要求から外す |

旧の信頼条件20欄は [theorems の全欄の表](../l00b.15/theorems.md)のとおり、移行済み19（うち導出2）・移行が必須で未着手1・不要0である。未着手は `sig_scoped` だけで、`PrimSig.Scoped` を新しい束縛に合わせる **L20 G08** の義務である。`release_exists`・`sat_unconstrained`・`admits_sat`・`io_op/ShapeOk` を再追加しない。三モデルの全欄の充足は L50/L60、使用先の保存・進行と主定理への接続は L20/L70 に残る。


## 定義を先に固定する群と判断

[RV-L10-plan](../reviews/RV-L10-plan.md)の全文と末尾の「取りまとめの追記」、planの最新の先頭行を今回の入口とする。設計者の「推奨の方法で進める」指示に従い、J01/J02を以下の形に具体化した。kind表の旧L10.02は **L10.24** へ移し、その前の.01〜.23で定義と既存読者への接続を固定する。後段が全相互証明を始めてから同じ族を作り直す工程は置かない。

定義を変更する.02〜.23は連続して作業する群である。各単位の局所検査と、公開署名・全読者・既定ビルドをそろえて群を取り込む判定を区別する。群の途中を受入済みにせず、既定ビルドを保つところまでを同じ群で閉じる。L40 H02から定義・単調性3〜7時間、L20 G09から定義1〜2時間をL10へ移す。G07の計算可能なfnViewとG08の三つのWellTypedの定義も下の表の額だけ移し、他段へ同じ作業を残さない。

### V: dataの変性はPを渡して検証する

| 案 | 利点 | 照合の必要と判断 |
|---|---|---|
| `Ty.LeQ P Γ Φ`・`TelLe P Γ Φ` | 型付け・PatTy・宣言のlookupと同じPを読む | **採用**。P.WellTypedに宣言の変性の構造検証を含める |
| 検証済みのVarianceEnvを別引数に渡す | 部分型から大きなProgramを隠せる | 不採用。既存判断のPと環境、constructor・公開境界の表の一致を各移送へ別に渡す必要がある |

配置は、Typesだけを読むVarianceSyntax → SyntaxのProgram → Leの四族 → Kinds/Admissible等 → VarianceValidation/VarianceTransport → ProgramTypingの順とする。LeはSyntaxの宣言データを読み、検証の証明やProgram.WellTypedをimportしない。検証が部分型の定義を再び必要とする循環を作らない。

以下は予定する完全署名又は定義の形である。現行Leanの宣言でも、型検査済みの実装でもない。変性の検証は欄の単調性の証明を入力に取らず、有限構文の正負の出現を検査する。

```lean
inductive Variance where
  | covariant | contravariant | invariant
inductive Polarity where
  | positive | negative | both
structure DataVarianceDecl where
  arity : Nat
  variances : List Variance
  requirements : List Ty
  publicBoundary : List (Polarity × Ty)
-- Programに追加する欄。既存の構成は既定noneを使える。
-- dataInfo : DataName → Option DataVarianceDecl := fun _ => none
def Program.varianceFor (P : Program) (d : DataName) (n : Nat) : List Variance
-- dataInfo dのarity=nかつvariances.length=nならその列。
-- それ以外はList.replicate n .invariant。旧embedProgramは既定none。

def Ty.VarianceOK (P : Program) (vs : List Variance)
    (polarity : Polarity) (a : Ty) : Prop
def Tel.VarianceOK (P : Program) (vs : List Variance)
    (polarity : Polarity) (t : Tel) : Prop
def Eff.VarianceOK (P : Program) (vs : List Variance)
    (polarity : Polarity) (e : Eff) : Prop
def Ty.ParamOccurs (i : Nat) (a : Ty) : Prop
-- 型変数とtappのhead、Ty/Eff/Telの全子を構文で調べる。
def Program.ParamOccursInFields (P : Program) (d : DataName) (i : Nat) : Prop :=
  ∃ c cd a, P.cons c = some cd ∧ cd.data = d ∧
    a ∈ cd.args ∧ a.ParamOccurs i
def Program.VarianceValid (P : Program) : Prop :=
  (∀ d info, P.dataInfo d = some info →
    info.variances.length = info.arity ∧
    (∀ i variance, info.variances[i]? = some variance →
      (¬ P.ParamOccursInFields d i → variance = .invariant)) ∧
    (∀ a ∈ info.requirements, Ty.VarianceOK P info.variances .both a) ∧
    (∀ item ∈ info.publicBoundary,
      Ty.VarianceOK P info.variances item.1 item.2)) ∧
  (∀ c cd, P.cons c = some cd →
    (∀ info, P.dataInfo cd.data = some info → info.arity = cd.ntys) ∧
    (∀ a ∈ cd.args,
      Ty.Annotation P (List.replicate cd.ntys ({} : TParam)) [] a ∧
      Ty.HasKind P (List.replicate cd.ntys .value) a .value ∧
      Ty.VarianceOK P (P.varianceFor cd.data cd.ntys) .positive a))

mutual
  inductive Ty.LeQ (P : Program) : Ctx → List Pred → Ty → Ty → Prop
  -- 既存13規則はPを通す。新data規則は
  -- data {Γ Φ d as bs} :
  --   TypeArgsLe P Γ Φ (P.varianceFor d as.length) as bs →
  --   Ty.LeQ P Γ Φ (.data d as) (.data d bs)
  inductive TelLe (P : Program) : Ctx → List Pred → Tel → Tel → Prop
  -- done/paramのTy.LeQ/TelLeへ同じPを渡す。
  inductive TelClosure (P : Program) : Ctx → List Pred → Tel → Tel → Prop
  -- refl/tailへ同じPを渡す。
  inductive TypeArgsLe (P : Program) :
      Ctx → List Pred → List Variance → List Ty → List Ty → Prop
  -- nil。
  -- covariant_consはLeQ P Γ Φ a b、contravariant_consはLeQ P Γ Φ b a、
  -- invariant_consはa.norm=b.norm。
  -- 三つのconsは残りのTypeArgsLeを前提とし、三列の長さをそろえる。
end

theorem Ty.LeQ.dataCore {P : Program} {Γ : Ctx} {Φ : List Pred}
    {a b : Ty} {d : DataName} {as : List Ty}
    (h : Ty.LeQ P Γ Φ a b) (hd : a.norm.core = .data d as) :
    ∃ bs, b.norm.core = .data d bs ∧
      TypeArgsLe P Γ Φ (P.varianceFor d as.length) as bs
```


欄に現れない型引数は不変とする。VarianceValidはParamOccursInFieldsが偽ならmetadataの指定がinvariantであることも検査し、単にunusedの規則を消しただけでcovariantの指定を空に認めることはしない。たとえばToken[A]の欄にAがなければ、Token[Read]からToken[Write]へ型引数を取り替える根拠は増えない。これはplanの最新の判断で確定済みであり、新たな設計者への問いにはしない。

変性とpolarityは正・負・両方に対応する三値とする。正負の合成と合流を有限表で定義し、出現の有無は別の構文上のBoolで記録する。tvarは宣言の向きと現在のpolarityの適合を検査し、dataの各引数は同じP.varianceForと合成する。関数引数は符号反転、結果・潜在効果・List/Lazy/Map値は同じ向きとする。Reference・Map鍵・Set・辞書・継続・外部型・不明なtapp・Failの型は両方の向きを要求する。refinedはcarrierに加え、述語が読む欄の宣言とsortを保つことを検査する。Pred自体は型変数を持たないが、欄の観測を無関係として省かない。

相互再帰dataは一つの候補表全体について構造検証し、その検証の健全性を構文への相互帰納法で示す。候補表の推論はR20が有限な合流で行う。requirements/publicBoundaryに格納された型の構造的な正負は検査するが、元の辞書制約・公開境界から取りこぼさず格納したことはLeanの外の照合である。ConDeclは辞書制約を持たず、LeanのProgramには公開境界の概念がない。P.WellFormedは格納済みの宣言とmetadataのscope/Annotation/kind/arityを検査し、原ソースとの完全な収集の一致を意味しない。D14全体との一致の照合はL70/R10bが担当する。dataInfoがない旧宣言は不変として扱う。これにより新機能の入力を欠く旧プログラムを排除しない。

**dataCoreの変更と欄の単調性は同じ群で必要**である。現行 `R/ValueFacts.lean` の `inv_con`・`field_facts_by_type`、`R/TypedFacts.lean` の `dataCore_source`・`data_observation`、`R/DeclaredTransport.lean` の `DataImages`・`DeclarationImages` は型引数の等号を読む。返す等号をTypeArgsLeへ替えるだけでは、欄の型付けを移せない。

```lean
-- 予定。像の形成は、使う箇所で型付き入力から供給する。
def VarianceSubstInput (P : Program) (C : List TParam) (Γ : Ctx)
    (vs : List Variance) (as bs : List Ty) : Prop :=
  as.length = vs.length ∧ bs.length = vs.length ∧
  (∀ t ∈ as ++ bs, Ty.Annotation P C Γ t)
theorem variance_field_mono (P : Program) (C : List TParam)
    (Γ : Ctx) (Φ : List Pred) (vs : List Variance) (a : Ty)
    (as bs : List Ty) (valid : P.VarianceValid)
    (occurs : Ty.VarianceOK P vs .positive a)
    (scoped : a.WF 0 vs.length 0)
    (sourceField : Ty.Annotation P C Γ (a.subst as []))
    (targetField : Ty.Annotation P C Γ (a.subst bs []))
    (inputs : VarianceSubstInput P C Γ vs as bs)
    (args : TypeArgsLe P Γ Φ vs as bs) :
  Ty.LeQ P Γ Φ (a.subst as []) (a.subst bs [])
-- 負は向きを反転、両方はnorm等号。Tel/Effも同じ相互証明で扱う。
```

欄の単調性ではsourceField/targetFieldの形成を明示する。型引数のAnnotationだけから、任意の不適格な欄の述語のSortedまで得られるとはしない。VarianceValidでconstructor欄のAnnotation/kindを検査し、欄への型代入の形成と使用先の注釈から両前提を供給する。この形成の補助も.05〜.07/.08に含める。

値型としてのkindの検査は既存V_ConのTypeArgsKindedと宣言の条件で保持する。欄の単調性の入力には、V_Subの行き先から供給できない別のkind文脈を要求せず、両方の型引数のAnnotationを使う。

.05〜.07/.08で引数関係の反射・推移・正規化とこの単調性を証明し、constructor逆転・欄の観測・宣言の移送を直す。証明できない場合に単調性そのものを信頼表の欄へ登録する逃げ方はしない。dataCore_sourceも同じdata名と、元の型引数から行き先の型引数へのTypeArgsLeを返す形へ替える。

欄の観測の移送は、行き先のFieldRef.DeclaredとHasSortを前提として向きを固定する。scopedからopaqueへの型忘却ではsortの情報を失い得るので、任意のLeQが欄の観測可能性を両方向に保つとは述べない。必要な型の補題は次の片方向である。

```lean
-- 予定。逆向きのHasSort保存を仮定しない。
theorem Ty.LeQ.hasSort_source {P : Program} {Γ : Ctx} {Φ : List Pred}
    {a b : Ty} {s : «Sort»} (h : Ty.LeQ P Γ Φ a b)
    (hb : b.HasSort s) : a.HasSort s
```

DataImages/DeclarationImagesも、受け手のdata引数を等号で固定する形を、欄の単調性とこの向きのsortの反映を供給する形に直す。公開境界で必要な形成・欄の宣言の前提は落とさない。

主な定理では `P.VarianceValid` を **P.WellTypedのフィールド**に置く。P.WellFormedだけに置くと、旧の形ではそれを前提に持たない進行で使えないためである。Ty.LeQは構文的な関係としてvalidを引数にせず、欄の逆転・保存・進行で使用するときに供給する。公理、Builtins.CoreAssumptionsの信頼欄、精密な外部状態は増やさない。

### X: 網羅性は観測できる篩を初期領域に反映する

**B・Γ・Φを追加しない。** Inhabitsを、照合が読む値の形の安全な上側近似として定義する。閉じたselfの観測でfalseになる値だけを篩から除き、外側の自由変数は未観測のnoneとして評価する。観測不能なslotもnoneのまま残す。判定器のunknownを成功の証拠とする規則ではなく、網羅性の量化から値を落としすぎないための近似である。

```lean
-- この二定義の形と三つの境界例は<tmp>の入力で確認した。
noncomputable def selfObservation (v : Val) : Option Observation :=
  v.toTerm?.bind (Term.observe (fun _ => none))
noncomputable def RefinementPossible (p : Pred) (v : Val) : Prop :=
  p.evalWith (fun | 0 => selfObservation v | _+1 => none) ≠ some false

-- 予定。Inhabitsの既存23場合のうちrefinedを置換し、一場合を足す。
-- refined {a p v} : Inhabits P a v → RefinementPossible p v →
--   Inhabits P (.refined a p) v
-- checkedAtOpaque {o ix r snapshot target req} :
--   Inhabits P (.opaque o ix) (.checkedAt r snapshot target req)
def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
  ∀ v, Inhabits P a.norm v → ∃ p ∈ ps, (matchVal p v).isSome
-- PatTyに足す一場合。実行のmatchValは変えない。
-- P_Refined {p a φ δ} : PatTy P p a δ → PatTy P p (.refined a φ) δ
```

checkedAtの四引数は現行 `R/Syntax.lean` の `Val.checkedAt` に従う。scopedの既存の上側近似を保ち、opaqueへ型を忘れた成功値を新しい場合で含める。BのvalKind/valContentを使って値を除外しないのでBは不要である。Γ/Φは型付けとEntails.soundを用いる証明側にあり、Exhaustiveの量化へは追加しない。

外側の環境を存在量化する案も比較したが、今回必要なのは観測できる篩による安全な絞込みである。外側をnoneに固定すれば、未観測の値を残す条件と移送の証明が直接になる。Γ/Φから分かる追加の篩は型付け側のLeQ/Entailsでscrutineeの型に反映し、Exhaustive自体の引数は増やさない。

D27のMonth（`1 ≤ self ∧ self ≤ 12`）は閉じた整数の観測で1〜12だけを残し、falsityの空篩は全値を除外し、非空List（`0 < listLength self`）は空Listを除外できる。P_Refinedでcarrierのrange/listパターンを篩へ持ち上げ、束縛型はcarrier側の型にできる。既存P_Varを選べば篩型を保持できる。.18〜.20で三つのExhaustiveの実証明を作る。補助で確認したのは評価の境界例であり、これらの全証明を今完了したとは記録しない。

`Inhabits.core` は篩の証拠を捨てれば保てる。現行 `R/PatternSemantics.lean` の **無条件のInhabits.of_coreは廃止**し、必要なら `∀ p ∈ a.refinementPredicates, RefinementPossible p v` を加えた復元補題へ替える。core等号だけから篩へ戻す `of_subst_values_core` も廃止し、full typeと評価の反映から値置換の反映を証明する。Exhaustive.subst_values・shift_values・shift_types、PatTy/AltsTyの全移送を.15〜.17で直す。falseで値を除く定義と、旧の無条件の復元補題を並置しない。


### X1: 型付き値の意味の不変量と評価の移送

Inhabitsを型付けへの帰納法の仮定にしない。RefinementPossibleは「評価がfalseでない」だけであり、noneから述語の真は得られない。たとえば観測できない欄を使う矛盾したpはnoneになり得るが、pから導けるfalsityはfalseになる。したがってInhabitsがLeQ.refineでそのまま保たれるという補題を置かない。

予定する意味の不変量ValueMeaningは、正規化した型について、値の形・全ての子値の意味・最外の全事実が二値の解釈で真であることを同時に持つ。型付けへの帰納法の仮定はこの述語である。最後にだけ評価の健全性からInhabitsを導く。

```lean
-- 予定。外側の値変数のモデルηと、既に閉じた実行時値vのselfを分ける。
def selfModel (η : ObservationEnvModel) (v : Val) : ObservationEnvModel :=
  fun | 0 => selfObservation v | i+1 => η i
mutual
  inductive ValueMeaning (P : Program) (η : ObservationEnvModel) : Ty → Val → Prop
  -- mk {a v} : ValueShapeMeaning P η a.norm.core v →
  --   (∀ p ∈ a.norm.assume, p.interpret (selfModel η v) = true) →
  --   ValueMeaning P η a v
  inductive ValueShapeMeaning (P : Program) (η : ObservationEnvModel) : Ty → Val → Prop
  -- const/checked/checkedRequest/checkedAtOpaqueはcoreの形を検査する。
  -- conはP.cons/arity/欄のWFとValueMeaningsを、listはValueMeaningEachを要求。
  -- 関数等の照合が内部を観測しない形は現在のInhabitsのcore側と同じ上側近似。
  -- refinedの構成子は置かず、ValueMeaning.mkの正規形の事実で扱う。
  inductive ValueMeanings (P : Program) (η : ObservationEnvModel) :
      List Ty → List Val → Prop
  -- nil/cons。consはValueMeaningと残りのValueMeanings。
  inductive ValueMeaningEach (P : Program) (η : ObservationEnvModel) :
      Ty → List Val → Prop
  -- nil/cons。conの全欄/listの全要素も意味の真を持たせる。
end
```

意味をa.normから定めるため、convertの途中の非正規形や、既存の正規化が消す不適格な継続上の篩に真を要求しない。ValueMeaning.norm_iffはnorm_idemから得る。構文上のaそのものに戻すInhabits.norm_iffにはWFを明示する。任意の不適格な型について無条件のrawな同値は要求しない。

Exhaustiveの定義も正規形を入口にする。引数はP/a/psのままである。これで移送時に正規化された型を読むことを、C_Matchの未検証の新しいWF前提で代用しない。適格なWF型については下のnorm_iffで従前のrawな表現との一致を示す。

```lean
def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
  ∀ v, Inhabits P a.norm v → ∃ p ∈ ps, (matchVal p v).isSome

-- 予定、L10.16（旧L10.13の分割分）。
theorem ValueMeaning.norm_iff (P : Program) (η : ObservationEnvModel)
    (a : Ty) (v : Val) :
  ValueMeaning P η a.norm v ↔ ValueMeaning P η a v
theorem Inhabits.norm_iff {P : Program} {a : Ty} {v : Val} {nr nt nv : Nat}
    (wf : a.WF nr nt nv) : Inhabits P a.norm v ↔ Inhabits P a v
-- 正規形上の反映。一般の移送はraw型への無条件の復元を使わない。
theorem Inhabits.subst_values_reflect_normal {P : Program} {a : Ty} {w : Val}
    (ν : Nat → Val) :
  Inhabits P (substTyValues ν a) w → Inhabits P a.norm w
```

ValueMeaningのLeQによる移送では、モデルηがΓ.factsとΦを真にすることを前提にする。V_Sub/refineでは、帰納仮定からpとaの事実の真を取り出し、Γ/Φの真と合わせてEntails.soundを適用し、qの真を得る。qの評価がfalseならPred.evalWith_soundによりqの二値の解釈もfalseになるので矛盾する。qを三値でtrueまで評価できることや、三値の評価の完全性は使わない。convert/transは正規化した意味を通す。dataでは欄の単調性を使い、子値にも同じ意味の移送を行う。証明の整礎性は、data/listの子値への下降とLeQの導出への下降を区別して固定する。

```lean
-- 予定、L10.18で言明を固定しrefineの代表を示す。全証明はG09。
valueMeaning_sub : ∀ {P : Program} {Γ : Ctx} {Φ : List Pred}
    {a b : Ty} {v : Val} {η : ObservationEnvModel},
  P.VarianceValid → Ty.LeQ P Γ Φ a b →
  (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
  ValueMeaning P η a v → ValueMeaning P η b v
valueMeaning_inhabits_normal : ∀ {P : Program} {η : ObservationEnvModel}
    {a : Ty} {v : Val},
  ValueMeaning P η a v → Inhabits P a.norm v
```

評価の単調性は環境のOptionの有無だけでは足りない。list/data/map/setの内部の未観測slotも増えるため、Observationの構造を保つ情報の順序を定義する。noneは任意の観測以下、some同士は同じsort/構造の子の情報を比較する。scalar・bytes・targetの値は等号を要求し、targetのsnapshotを別のσへ変更する順序は置かない。map/setの鍵の符号化が一度成功したときは情報の追加で符号を変えないことも補題にする。

```lean
-- 予定、L10.15（旧L10.13の先頭）。
def Observation.InfoLE : Observation → Observation → Prop
def Observation.OptionInfoLE : Option Observation → Option Observation → Prop
def ObservationEnvModel.InfoLE (η ξ : ObservationEnvModel) : Prop :=
  ∀ i, Observation.OptionInfoLE (η i) (ξ i)
theorem Term.observe_mono (t : Term) (η ξ : ObservationEnvModel)
    (h : ObservationEnvModel.InfoLE η ξ) :
  Observation.OptionInfoLE (t.observe η) (t.observe ξ)
theorem Pred.evalWith_mono (p : Pred) (η ξ : ObservationEnvModel) (b : Bool)
    (h : ObservationEnvModel.InfoLE η ξ)
    (hp : p.evalWith η = some b) : p.evalWith ξ = some b
theorem Pred.close_preserves_decided (p : Pred) (ν : Nat → Val) (w : Val) (b : Bool)
    (hp : p.evalWith (selfModel (fun _ => none) w) = some b) :
  (predBind (valEnv ν).up.values p).evalWith (selfModel (fun _ => none) w) = some b
```

上のclose_preserves_decidedは、selfを保ち外側だけを閉じる場合の言明である。termBind?のgetDが現れる枝を含め、既に確定した評価が未知の部分に依存しないことを示す。Term.interpretが任意の情報の追加に対して不変という、既定値について偽となる補題は置かない。三値の単調性・有限連言の平坦化・Inhabitsの正規化を別々に示し、L10.17でshift_values/shift_types/subst_values/AltsTyとC_Match四枝へ接続する。

閉じた型付けからのValueMeaningはG09が全導出を証明する。捕捉のあるmatchRunには、CaptureOkの型付き像で元のv/aを閉じ、閉じた型付け→ValueMeaning→Inhabits(閉じた型)→上の値置換の反映→Inhabits(元の型の正規形)→Exhaustive、の順で接続する。開いたvそのものに閉じたInhabitsを帰納仮定として与えない。CaptureOkのΓ.facts/ΦのEntailsと型付き像からモデルの事実と閉じた型付けを供給し、その意味の交換を無検査の新しい表の欄へ入れない。

L10.18でValueMeaningの定義の利用、V_Sub/refineの代表と全言明を固定し、L10.20で開いた型・捕捉への上の接続の代表を示す。G09の全証明は、以前の残り1〜3時間から4〜8時間へ再見積もる。根拠は三値の所属からの単純な導出ではなく、型付け相互の意味の不変量、LeQの意味の移送、全子値、捕捉と任意の腕への接続が必要になったことである。実績のない見込みであり、最初の通常resultsで更新する。

### W: 三つの予約名を定義する

`R/Typing.lean` にまだない `Def.WellTyped`・`ImplDecl.WellTyped`・`Program.WellTyped` を.21/.22が受け持つ。旧 `O/Typing.lean` の三定義を参考にし、新しいTelBodyTyがparamで値を束縛しdoneで自分のret/effectを使う形にする。

```lean
-- 予定。StoreTy.emptyはfun _ => none。
def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  Ty.HasKind P (d.tparams.map TParamDecl.kind) (.dependentFn d.tel) .value ∧
  Ty.Annotation P (d.tparams.map TParamDecl.constraints) [] (.dependentFn d.tel) ∧
  TelBodyTy P B StoreTy.empty (QTel d.tel)
    (d.tparams.map TParamDecl.constraints) [] [] d.tel d.body
def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop
-- classesのlookup、methods/supersの定義域の厳密一致、
-- targetのcd.argumentKindでのHasKind、dictTysのAnnotationを要求する。
-- 各ms/bodyにθ=typeEnvAt ms.tparams.length [id.target] []、
-- t=Tel.bind θ ms.tel、C=ms.tparams.map constraints ++ id.tparamsを作る。
-- Γ=bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))、
-- t'=Tel.shiftV id.dictTys.length 0 t として
-- TelBodyTy P B StoreTy.empty (QTel t') C Γ [] t' bodyを要求する。
-- 各super uは、空ストア・id.tparams・bindParams [] id.dictTys・空Φで
-- HasTypeV P B StoreTy.empty id.tparams (bindParams [] id.dictTys) []
--   u (.dict s id.target)を持つ。
structure Program.WellTyped (P : Program) (B : Builtins) : Prop where
  variance : P.VarianceValid
  external : P.ExternalWF
  defs : ∀ f d, P.defs f = some d → Def.WellTyped P B d
  impls : ∀ i id, P.impls i = some id → ImplDecl.WellTyped P B id
```

上のメソッドの型代入と辞書引数分の値移動は別の操作である。現行のTelBodyTy/QTelの束縛と引数順に合わせる局所確認を.22へ割り当てる。Program.WellFormedは格納された宣言のWF/Ordered/Regularとmetadataのscope/arity、Program.WellTypedは本体の導出と構造検証の成立を担う。sig_scopedの全量化は既存Builtinsの信頼欄の未完分としてG08に保ち、この構造へ同じ任意の証明を重ねて格納しない。現行のR/ConstraintAssumptions.leanのCoreAssumptionsにはsig_scopedがまだない。G08がPrimSig.Scopedとその全量化を予定どおり追加する。これは旧20欄の対応の未完分であり、今回新しく作る信頼条件ではない。全プログラムの充足はL20/L50/L60/L70へ残す。


### W1: Program.WellFormedとmetadataの条件の範囲

L10.23を独立した起動単位にする。旧O/WellFormed.leanのDef/ConDecl/OpDecl/MethSig/ClassDecl/ImplDeclのScopedとProgram.WellFormedを読み、新しい四名前空間・依存する値の束縛に合わせて次の形を定義する。予約した名前だけをL70へ送らない。

```lean
-- 予定。SourceScopedは型/行/範囲/値の深さを読む有限構文の再帰検査。
def Comp.SourceScoped (nr nt ne nv : Nat) : Comp → Prop
def Val.SourceScoped (nr nt ne nv : Nat) : Val → Prop
def Def.Scoped (P : Program) (d : Def) : Prop
-- NamesWF、d.telのWF/RowsIn、宣言したkind、SourceScoped 0 d.ntys d.neffs
-- d.params.length d.body。依存列の各注釈を先行する値引数の下で検査する。
def ConDecl.Scoped (P : Program) (cd : ConDecl) : Prop
-- argsのWF 0 cd.ntys 0、行なし、value kind。元の宣言の辞書制約の意味は持たない。
def OpDecl.Scoped (P : Program) (od : OpDecl) : Prop
def MethSig.Scoped (P : Program) (argumentKind : TyKind) (ms : MethSig) : Prop
-- msの型パラメータ+class引数の型の深さ、行の深さ、値の依存列を検査。
def ClassDecl.Scoped (P : Program) (cl : ClassDecl) : Prop
-- 各methodをcl.argumentKindでMethSig.Scopedへ渡す。
def ImplDecl.Scoped (P : Program) (id : ImplDecl) : Prop
-- methodsはmsの型/行と辞書+値引数の値の深さ、supersはidの辞書文脈で検査。

def Program.MetadataScoped (P : Program) : Prop
-- 格納された各dataInfoのvariances.length=arity、同名consのntysとの一致。
-- requirementsとpublicBoundary内の型をarity個のvalue型変数の下で
-- WF/Annotation/HasKind検査する。元ソースの収集の完全性とは別である。
structure Program.WellFormed (P : Program) : Prop where
  defs : ∀ f d, P.defs f = some d → d.Scoped P
  cons : ∀ c cd, P.cons c = some cd →
    P.DataArity cd.data cd.ntys ∧ cd.Scoped P
  ops : ∀ o od, P.ops o = some od → od.Scoped P
  classes : ∀ cl cd, P.classes cl = some cd → cd.Scoped P
  impls : ∀ i id, P.impls i = some id → id.Scoped P
  metadata : P.MetadataScoped
  external : P.ExternalWF

theorem QTel_signatureTel (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : NamesWF ns ps) :
  QTel (signatureTel ns ps r e) = Qsig ps r e
theorem Def.QTel_eq_Qsig (d : Def) (hn : NamesWF d.names d.params) :
  QTel d.tel = Qsig d.params d.ret d.eff
theorem MethSig.QTel_eq_Qsig (ms : MethSig) (hn : NamesWF ms.names ms.params) :
  QTel ms.tel = Qsig ms.params ms.ret ms.eff
```

Qの三補題はL10.21で作り、L10.22のmethod、SignatureInstance/Admissibleへ同じ行変数の条件を渡す。signatureTelの引数列への帰納法とQTel/QTy/QEff/QTys、命題の∨の結合を使う。依存列の値の移動は行原子を変えないことを利用し、呼出し側に新しいNoFailの前提を要求しない。

| 対象 | Leanで確かめること | Leanだけでは確かめないこと・担当 |
|---|---|---|
| constructor欄と欄の述語 | VarianceOK、Annotation、HasKind、非出現引数の不変、欄の単調性 | Rustの宣言から同じ型/述語を抽出したことはR10b/L70 |
| requirements | **提供された列**の型のscope/kindと、両方向の出現の検査 | ConDeclに辞書制約はない。元の全制約を列へ入れたことと漏れの拒否はL70/R10b（O005/O033） |
| publicBoundary | **提供された列**の型のscope/kindと、指定polarityの構造検査 | Leanには公開/非公開の概念がない。opaqueの境界を含む公開宣言の全収集と向きの一致はL70/R10b（O005/O033/O167） |
| dataInfoなし/二つの空列 | noneの宣言は不変。列が空ならその列への全称検査は空に成り立つ | 元ソースに制約/公開境界がないとの証明にはならない。空列で不当に共変となる入力を含め、原ソースとの照合をL70/R10bで行う |

dataInfoが全てnoneならVarianceValidのmetadataを量化する第一節は空に成り立つ。一方、constructor欄を検査する第二節は空にはならず、実際のP.consの欄を検査する。some infoでもrequirements/publicBoundaryが空ならその二つの全称だけが空に成り立つ。Program.WellFormed.MetadataScopedも、入力として格納されたデータの適格性を表す範囲に限る。

dataCore・欄の単調性・値の意味の移送の健全性の補題は、constructor欄の検証を使い、requirements/publicBoundaryから原ソースの意味を導かない。D14とのLean内の一致は欄と述語及び**提供されたmetadata**の構造検査までである。辞書制約と公開境界を含む言語全体の変性の一致は、L70/R10bの独立の照合で閉じる。07-04の内外の表へこの区分をL10.56で反映し、主定理に「metadataは完全」という新しい公理を追加しない。

### X2: 値依存の長さと静的なscrutineeの型の合成

L10.19はMonth/空篩/非空List/unknown、L10.20は値依存の長さと開いた捕捉の代表を担当する。値依存の代表では、閉じた実行時の整数nとList値wについて、長さがnである篩付きの型付けと0<nから、ValueMeaningの等号の真を得る。閉じた観測から非空の述語のEntails.closedを構成し、V_Refineでwを非空Listの型へ強め、頭とrestのパターンのExhaustiveを適用する。nを1という定数だけへ限定せず、Listの要素が観測不能でも長さを観測できる例を含める。


```lean
-- 予定、L10.20。nとxsの関係を明示した閉じた核の代表。
length_refinement_representative : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
    {T : Ty} (n : Int) (xs : List Val),
  Ty.Annotation P [] [] (.list T) →
  HasTypeEachQ P B Ψ Qempty [] [] [] xs T →
  (xs.length : Int) = n → 0 < n →
  HasTypeVQ P B Ψ Qempty [] [] [] (.list xs)
    (.refined (.list T) (.eq (.measure .listLength (.var 0)) (.integer n))) ∧
  HasTypeVQ P B Ψ Qempty [] [] [] (.list xs)
    (.refined (.list T) (.lt (.integer 0) (.measure .listLength (.var 0))))
```

長さの等号はこの代表の契約の入力である。一般の「篩付き型付け→実際の長さの等号」はG09のValueMeaningから供給する。代表の後半の型に対する頭/restの網羅性はL10.19の補題を使うので、長さの型を作っただけで終えない。閉じた整数nはLeanの変数でよく、核のTerm.integer nは値変数を持たない。そのため閉じた評価の証明に、未実装の開いた等号の合同を仮定する必要はない。

開いた契約は、Γにnとlがあり、lの型がList{listLength self == n}、Φからn>0が得られる形とする。L70/R10bは、L30の有限の等号/線形の証明書を使って0<listLength(l)を導き、V_Refine又はLeQでscrutineeの型を非空の閉じたself述語へ強めてから網羅性へ渡す。値依存の等号だけを残して外側をnoneにしたExhaustiveへ直接渡すと空Listを排除できない。L10の閉じた代表を、実行時に型を強める暗黙検査の根拠にはしない。

現行R/Logic.leanのEntailsには開いた等号/線形の一般の交換規則がなく、その証明書の生成は既存のL30の義務である。L10.20は任意の閉じたnについての核の導出と、開いた場合に必要な有限のEntailsを受ける接続の言明を示す。開いた算術の証明書まで今回のL10の代表だけで完成したとは記録しない。L70/R10bはsourceからの自動合成、guard/unknown、篩付きの同じ結果型/効果を確認する（O037/O066/O079/O138）。この未完をcarrierだけの全域網羅性で代用しない。

### 現行ソースから数えた波及

数え方はR/の全leanの各行に完全な識別子の字面があるかである。同じ行の重複は行数では一つとし、コメントも含む。Leanの依存解析・必須編集行数・所要時間ではない。

| 読み手（R/） | Ty.LeQ | TelLe | TelClosure | 三判断の行の和集合 | Inhabits | Exhaustive |
|---|---:|---:|---:|---:|---:|---:|
| `AtPatterns.lean` | 0 | 0 | 0 | 0 | 1 | 2 |
| `Canonical.lean` | 4 | 0 | 2 | 6 | 0 | 0 |
| `ContextMap.lean` | 1 | 2 | 2 | 5 | 0 | 0 |
| `DependentBeta.lean` | 1 | 0 | 0 | 1 | 0 | 0 |
| `ExternalCheck.lean` | 2 | 0 | 0 | 2 | 0 | 0 |
| `HandlerCalls.lean` | 4 | 1 | 1 | 6 | 0 | 0 |
| `HandlerContinuation.lean` | 2 | 0 | 0 | 2 | 0 | 0 |
| `HandlerPreservation.lean` | 6 | 0 | 0 | 6 | 0 | 0 |
| `HeldValues.lean` | 2 | 0 | 0 | 2 | 0 | 0 |
| `InversionCore.lean` | 22 | 6 | 7 | 34 | 0 | 0 |
| `LazyInversion.lean` | 13 | 0 | 0 | 13 | 0 | 0 |
| `LazyPreservation.lean` | 4 | 0 | 0 | 4 | 0 | 0 |
| `LazyStore.lean` | 1 | 0 | 0 | 1 | 0 | 0 |
| `Le.lean` | 24 | 5 | 4 | 31 | 0 | 0 |
| `MatchFacts.lean` | 1 | 0 | 0 | 1 | 0 | 0 |
| `MatchPaths.lean` | 6 | 0 | 0 | 6 | 0 | 3 |
| `Narrowing.lean` | 5 | 0 | 0 | 5 | 0 | 0 |
| `NarrowingObstruction.lean` | 1 | 0 | 0 | 1 | 0 | 0 |
| `OpenSubstitution.lean` | 7 | 0 | 0 | 7 | 0 | 0 |
| `PathConditions.lean` | 2 | 0 | 0 | 2 | 0 | 0 |
| `PatternSemantics.lean` | 0 | 0 | 0 | 0 | 16 | 4 |
| `PatternTypeShift.lean` | 0 | 0 | 0 | 0 | 2 | 2 |
| `Patterns.lean` | 0 | 0 | 0 | 0 | 27 | 1 |
| `RangeSubst.lean` | 11 | 3 | 2 | 16 | 0 | 0 |
| `ReferenceCalls.lean` | 11 | 1 | 10 | 22 | 0 | 0 |
| `Shift.lean` | 2 | 0 | 0 | 2 | 0 | 0 |
| `StateTyping.lean` | 1 | 0 | 0 | 1 | 0 | 1 |
| `SubstTypingObstruction.lean` | 4 | 0 | 0 | 4 | 0 | 0 |
| `Telescope.lean` | 0 | 10 | 10 | 20 | 0 | 0 |
| `Transport.lean` | 14 | 8 | 7 | 25 | 0 | 0 |
| `TypeShiftContracts.lean` | 2 | 0 | 0 | 2 | 0 | 0 |
| `TypeSubst.lean` | 6 | 0 | 0 | 6 | 0 | 0 |
| `TypedFacts.lean` | 3 | 0 | 0 | 3 | 0 | 0 |
| `Typing.lean` | 2 | 0 | 0 | 2 | 0 | 1 |
| `TypingDeclared.lean` | 1 | 0 | 0 | 1 | 0 | 0 |
| `TypingShift.lean` | 2 | 0 | 0 | 2 | 0 | 0 |
| `ValueFacts.lean` | 4 | 0 | 0 | 4 | 0 | 0 |
| `ValueSubst.lean` | 4 | 0 | 0 | 4 | 0 | 0 |
| 合計 | 175 | 36 | 45 | 249 | 46 | 14 |

Ty.LeQはレビューと同じ **33ファイル175行**（同一行の重複を含む字面では211回）、TelLeは36行、TelClosureは45行、三判断の行の和集合は249行である。既存13+2+2=17規則はPを通し、新data1とTypeArgsLe4を加えて **22規則** の相互群になる。V_Sub/C_Subは規則を追加せず同じPを渡す。

値29・計算24を含む型付け相互14判断76規則について、値移動・型移動・値置換・narrowingの4本、**76×4=304枝**を照合する。304は新規証明数ではない。DataImages/DeclarationImages、constructor逆転、型付き観測は304とは別で、.05〜.07/.08が担当する。

Inhabitsは4ファイル46行、Exhaustiveは7ファイル14行である。現行23+2+2=27規則にcheckedAtOpaqueを一つ追加して **28規則** とし、refined一規則を変更する。PatTy7+PatTys2=9規則にはP_Refined一つを追加して **10規則** とする。core・値置換反映・型移動反映等の証明の27既存場合、C_Matchの相互四本の4枝、ContTyのguard/matchの読者を照合する。B/Γ/Φの追加による判断の引数数の変更は0である。

### 提供表と制限は最初に判定する


| 定義の群 | 現行の読み先 | .01で確定すること／後段 |
|---|---|---|
| 七種の整数・Byte・Decimal | ConstOK、Const.type、V_Const、V_Bytes、Shared.IntKind、Observation.decimalNormal | 端点とscale。Byteと七幅は述語では同じ.integerで比較可能である。IntKind算術の区分とは別。算術/正常結果/丸めの葉はL40 |
| Character・Float64/32 | Const/Term、Sort、Comparison.Allowed、ClosedEvaluation | Charの値、ビット幅、NaN等の分類と比較。全ビットの丸め実装は外側、標準の葉はL40 |
| String/Bytes/List | Measure.stringBytes/stringCharacters/bytesLength/listLength、Observation.measure | バイト数と文字数、非負、snapshotと可視な欄連鎖。開いた非負/標準事実はL30/L40 |
| Map/Set | mapSize/setSize、Observation.mapKeys、ClosedKeys、V_Map/V_Set | 鍵の構文コードと意味上の等値を区別。既存の重複縮約の観測を使い、言語の鍵との一致はL30/L40 |
| data/record・Boolean・対象 | FieldRef.Declared/Term.HasData、constructorIs/compare/member、SnapshotMem | 欄・構成子・比較・所属のsortと参照条件。data変性の定義/単調性はL10、利用側の葉はH02、同じσの所属/被覆はL50 |
| 否定の制限の定義側 | Term.Source/Pred.Source、Ty.WF/HasKind、Ty.LeQ、RangeExpr.Covers | DET-L01/02/03/04/05/06/07/11/12/13/14/15/18/19/27/31を定義の入口又は後段の規則へ対応。関数・セル・資源のeq、一般実行式、循環、一般量化/UFを足さない |
| 否定の制限の後段側 | 本書は担当を記録 | DET-L08/09/10/16/17/20/21/22/23/24/25/26/28/29/30を再帰契約・推論・探索・クラス・Range・表層・生成・構成・旧API・警告のL/R/V担当へ対応。これらをL10の拒否テストだけで閉じない |

全DET-L31行は上の二行で重複なく対応する。DET-L06のOrderedはソース注釈の参照順序でありCaptureOkを強めない。DET-L31のSourceはソースから書く形を制限する一方、値置換後の内部snapshotを禁止しない。L10で新しい制限は加えない。


DET-L03は数値型の暗黙変換を許さない制限であり、数学上の整数を観測する述語で異なる幅やByteを比較することを禁じる制限に読み替えない。現行 `R/Context.lean` の `Ty.sort?`、`R/TermSyntax.lean` の `Term.integer`、`R/ClosedEvaluation.lean` の整数の観測に合わせ、述語のsortは共通の.integerのまま保つ。通常の算術のIntKindとConstOKによる各幅/Byteの表現可能性は別に検査する。比較できる現行の式を禁止する変更は行わない。提供範囲の不足を.01で判定して.02〜.23の定義へ反映するので、有限正規化や数値adapterを終えた後で初めて判定する順にはしない。

### 進行へ残す署名

```lean
-- 予定、G09。主たる帰納法の結論は意味の不変量である。
typed_value_meaning_closed : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
    {v : Val} {a : Ty},
  P.VarianceValid → B.CoreAssumptions P →
  HasTypeVQ P B Ψ Qempty [] [] [] v a →
  ValueMeaning P (fun _ => none) a v
inhabits_of_typed : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
    {v : Val} {a : Ty},
  P.VarianceValid → B.CoreAssumptions P →
  HasTypeVQ P B Ψ Qempty [] [] [] v a → Inhabits P a.norm v
inhabits_of_typed_raw : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
    {v : Val} {a : Ty},
  P.VarianceValid → B.CoreAssumptions P →
  HasTypeVQ P B Ψ Qempty [] [] [] v a →
  a.WF 0 0 0 → Inhabits P a v
-- rawな結論が必要な箇所ではWFを明示してnorm_iffで戻す。
-- WFはG04の形成の入力/捕捉から供給し、型付け一般だけから無条件に仮定しない。
-- InhabitsだけをIHにしてValueMeaningを後から仮定する順は採らない。
```

inhabits_of_typedの結論は正規形a.normへの所属とし、Exhaustiveも同じ入口を読む。これは篩のcarrierへの消去ではなく、D07の平坦化/true消去/関数畳込みに合わせる変更である。適格なWF型にはnorm_iffを示し、rawな所属はWF付きの系に分ける。この定義上の選択も取りまとめが変更節で確認する。

このCoreAssumptionsはG08でsig_scopedを加えた後の予定の束を指す。ValueMeaningの全導出の証明はG09、L10は定義・評価/正規化の移送・refine/閉じた代表と開いた捕捉の代表を担当する。いずれも主定理の新しい独立前提や新公理にはしない。

## 義務の段別判定

元の「担当にL10を含む」29行を全て残した。分類はA残件実装9、B既済みの継承照合16、C本体の他段への明確化3、D通常記録1で計29行である。O011/O044/O076のコメント・07-04の実変更、O159の予約名をAへ移した。さらに今回L10へ定義を移すO005/O033をAで2行、全Lへ適用するO016/O084をE（共通停止・例外条件）で2行追加し、判定表は前回33行から、値依存長の代表と後段への接続O037/O066/O079/O138を加え、**37行、A12/B16/C6/D1/E2** とする。O037/O066/O138は後段への契約の引渡しの確認で、表層実装をL10へ移す行ではない。取りまとめがplanの担当と判定へ転記する。どの行もL10だけで義務全体を閉じる意味ではない。

| 義務 | 分類・受け持つ単位 | L10の完了の判定 | L10の後に残る段・理由 |
|---|---|---|---|
| O011 | A・.26/.30/.54/.56 | 既存 ConstOK/V_Bytes と全整数幅・Byte・Decimal の対応、旧入力の表現可能性、既存決定の変更を確認 | L40 の標準δ/正常結果の葉。新前提を置いただけでδを閉じない |
| O013 | C・.01/.30/.56 | 対象なしopaqueの除外と旧の保持値の葉を確認。ShapeOk の single が opaque を要求し scoped は scoped_forget で渡すことを記録 | 本体は L50：typed shapeAt・TargetAgreement・io_exists と三モデル。L10 が全モデルを閉じる配分を訂正する |
| O015 | B・.01 | 全sort、measure、targetMember/constructorTest/Booleanの WF/Sorted/Source/意味の対応表がそろう | L30 の有限規則・論理への接続、L50 の所属と具体化の意味 |
| O035 | C・.01/.30 | V_CheckedRequest の groundVal/reqTarget一致・valContent区分と旧保持入力の前提を確認 | 本体は L40 のδ・節、L50 の全δ/拡大/対象一致と存在。構成子追加は既済み |
| O042 | A・.24〜.30/.55/.59 | 既存 embedLe/embedCovers を再使用し、kind表付き変換と値の葉が既定importで閉じる | L20 の全導出・状態の埋め込み、L70 の読者切替 |
| O044 | A・.56/.58 | Syntax/07-04で旧の抽象化と新しい前提の差を区別し、旧定理の欠陥と書かない | L50 の対象の葉、D10 の公開文書の最終照合 |
| O049 | A・.26/.30/.55 | 旧保持要求の適格性から新しい計算可能前提を供給し、同じ要求全体・端点・Top拡大を保つ | L50 のσ/対象の具体化、L60 の全モデル。L00b.13 の葉を作り直さない |
| O050 | B・.01/.14〜.20 | sortに関数/Reference/資源の等号がなく、失敗をNotで真へ変えない境界を確認 | L20 の観測と全置換の交換、L30 の規則の健全性 |
| O065 | A・.02〜.51/.55 | kind表・旧適格性・有限支持・正規化と限定等号の署名、前提ごとの証拠がある | L20 sig_scoped/全文脈/全埋め込み、L40 変性の利用側の葉、L50/L60 表の充足。旧全域の同値は求めない |
| O076 | A・.56/.58 | 数値・Topの旧対象外行と新しい並置定義の差を07-04で説明する | D10 の最終文書。旧名前空間の説明を誤って新規則へ書き換えない |
| O087 | C・.01 | 全入れ子の Ty.external/ID/表・ExternalWF と unknown/duplicate/不正型引数の拒否位置を確認 | 本体は L60/R50：実表、三条件、名目IDの交換と両除外0。L10へ実表実装を重ねない |
| O116 | A・.57/.58 | 二つのadmit宣言・参照・写しを意味を変えず改名し既定buildを保つ | L70 の最終切替と残る全読者検索 |
| O124 | B・.01/.26/.54 | signed4種/unsigned3種の端点・ConstOK・IntegerValue・toApproxの幅一致を確認 | L40→R10a/R10b/R40/R50→V10 の規則・実装・交換・CLI |
| O125 | B・.01/.26/.56 | Byteの0/255・域外とV_Bytesを確認。IntKind算術と区別する一方、述語では七幅と同じ.integerで比較できる現行定義を保つ | L40→R10b/R40/R50→V10 |
| O126 | B・.01 | Charを持つConst/Term、characterCodeとsortの対応を確認 | L40 の値域/比較の葉→R10b/R40/R50→V10 |
| O127 | B・.01 | charactersInのsort・閉じた評価・有限構文の境界を確認 | L30/L40 の有限規則/葉→R10b/R40/R50→V10。正規表現の一般判定を足さない |
| O128 | B・.01 | float64/float32・分類・比較を確認し、線形整数のsortと分ける | L40 の特殊値/比較の葉→R10b/R40/R50→V10。一般算術を実数線形にしない |
| O129 | B・.01/.26/.54 | Decimalの係数両端/scale≤28、decimalRepresented/比較と丸めの境界を確認 | L40 の正常結果/丸めの葉→R10b/R40/R50→V10 |
| O130 | B・.01 | stringBytes/stringCharactersを別measureとしSourceの入力形を確認 | L30/L40 の関係と葉→R10b/R40/R50→V10 |
| O131 | B・.01/.04〜.08 | listLengthとsnapshot/欄連鎖の定義を確認。Listの共変は既存 | L30/L40 のmap/reverse/append/filter等の契約→R10b/R40/R50→V10 |
| O132 | B・.01 | bytesLengthの数学上の非負長とV_Bytesの値域条件を区別 | L30/L40 の非負/標準契約→R10b/R40/R50→V10 |
| O133 | B・.01/.03 | mapSizeとMap値の共変/鍵の不変、重複縮約の観測を確認 | L30/L40 の鍵の等値・大きさ/標準契約→R10b/R40/R50→V10 |
| O134 | B・.01/.03 | setSizeとSet要素の不変、重複縮約の観測を確認 | L30/L40 の鍵の等値・大きさ/標準契約→R10b/R40/R50→V10 |
| O135 | B・.01〜.08 | FieldRef.Declaredと不変な欄/全体述語の照合位置を確認 | L30/L40 の合同・data変性・decode契約→R10b/R40/R50→V10 |
| O144 | B・.01/.14〜.20/.58 | D07の構造等号・平坦化・true/空篩と有限の論理/measure/対象所属を対応させる | L30/L40/L50→R20/R10b/R40/R50→V10。一般UF/SMT/量化/非線形/入れ子measureは追加しない |
| O159 | A・.02〜.23/.55/.59 | 予約のDef/ImplDecl/Program.WellTyped、Program.WellFormedと検証済み変性、Inhabits/Exhaustiveを定義し、全構成子とimportの対照を更新 | L70 の主定理/交換/規範の切替と旧互換の利用者の確定 |
| O160 | D・.33〜.37/.59 | 棚卸し158=既済16+不要43+L10残99を対応。同種19件の最初17件を.33〜.36で閉じてcと残N_g=2を更新し、.37で残二件を別記録にする | L20/L40 の別種の追随は各段で更新。L00aの比とL00bの代表を重ねて掛けない |
| O167 | B・.01/.58 | 全DET-L行をsort/WF/導出/表層/外側へ分類し、L10の定義の制限と残る担当を明記 | L20/L30/L40/L70→R10a/R20/R10b/R40/R60→V10。比較連鎖等は表層、暗黙動的検査なしはRust/CLIで別判定 |
| O169 | A・.52〜.54/.58 | 共通値近似のWF/空判定、BaseApprox/実Reportの写しと所属、normalToSharedの限定逆方向、ConstOKの整数写像を置く | L20/L40 の独立評価→Release/returned/failedの条件付き所属、L70 の合成→R10b/R50。mayFailの複写を失敗の健全性と呼ばない |
| O005 | A・.02〜.13/.23 | data変性の宣言・検証・部分型と単調性を同時に定義し既定buildを保つ | H02の利用側の葉、L20全保存。L70/R10bで辞書制約/公開境界の内外の照合。planのL10/L70追記は取りまとめ |
| O033 | A・.03/.05〜.07/.08 | 欄・述語と提供されたmetadataの構造検証、非出現引数の不変、field_monoを置く。辞書制約/公開境界の収集の完全性はLeanで主張しない | L40標準data/δ。L70/R10bで元の辞書制約/公開境界の全収集と変性を照合し、R50で接続。planのL10/L70追記は取りまとめ |
| O016 | E・.59 | 新定義と葉及び旧主定理/三モデルの#print axiomsを実行し、許可依存だけを確認 | 全Lの共通停止条件として各段で反復。独立レビューは取りまとめ |
| O084 | E・.01/.58/.59 | TODO-250の例外を形式化の内外と分け、L10で作らない処理系の検査を達成済みにしない | 全L/R/Kの例外台帳と最終受入。例外そのものは広げない |
| O037 | C・.20/.55 | 開いた長さからの型の合成に必要な核の導出・署名と、同じ篩付き結果/効果を保つ契約を渡す | 担当はL70のまま。全表層literal/checker/脱糖の証明をL10で完了としない |
| O066 | C・.20/.55 | 正規形を入口にする網羅性と篩付き結果/効果の接続を渡す | 担当はL70/R50のまま。表層/交換の全実証と消去の観測は後段 |
| O079 | A・.18〜.20 | Month/空篩/非空List/値依存長・捕捉の代表を示し、unknownで腕を除かない | L70/R10bはΓのlen(l)=nとΦのn>0から静的にscrutineeを強める。L30は有限の論理の証明書、R50は受理/拒否の接続 |
| O138 | C・.01/.20/.55 | 既存の分岐factsと値依存長の型の合成の利用先を確認。新しい実行時検査を挿入しない契約を渡す | L20/L40/L70/R10b/R50/V10の既存配分を保ち、L70/R10bに静的な合成の完了条件を追記 |

## 予定する署名と定義の形

### K: 宣言の kind 表と旧入力

既存の `embedProgram P` を全域の意味保存定理の相手にしない。既存の全value版は構文の便宜として残し、kindを保持する版を別名で追加する案を採る。旧の署名の変更を多数の既存の利用箇所へ波及させずに、L20 の定理の相手を先に固定できる。

```lean
-- 予定。旧宣言が失ったkindを明示するデータ。制約を追加する欄ではない。
structure DeclarationKinds where
  classArgument : ClassName → TyKind
  functionParams : FunName → List TyKind
  methodParams : ClassName → MethName → List TyKind

def embedTParamsWithKinds (ps : List Benitoite.Release.TParam)
    (ks : List TyKind) : List TParamDecl
-- ps.zip ks を constraints/kind へ写す。長さ一致は下のWFで要求する。
def DeclarationKinds.WF (K : DeclarationKinds)
    (P : Benitoite.Release.Program) : Prop
-- defsの各lookupでfunctionParamsの長さ=旧tparams長。
-- classes/methodsの各lookupでもmethodParamsの長さ=旧tparams長。
-- 型クラスの引数kindはclassArgumentに保持する。
def embedDefWithKinds (ks : List TyKind) (d : Benitoite.Release.Def) : Def
def embedMethSigWithKinds (ks : List TyKind) (d : Benitoite.Release.MethSig) : MethSig
def embedClassDeclWithKinds (K : DeclarationKinds) (cl : ClassName)
    (d : Benitoite.Release.ClassDecl) : ClassDecl
def embedProgramWithKinds (K : DeclarationKinds)
    (P : Benitoite.Release.Program) : Program
-- 項のembedVal/embedComp、ops/cons/impls/effects、空の外部表は既存どおり。
-- 上の三つのkind位置だけを表から受け取る。
```

操作・impl の型パラメータは現行の宣言どおり value とする。組み込みの kind は、旧/新の実署名の照合から受け取り、DeclarationKinds の利用者向けの新設定にはしない。`zip` が長さ不一致を黙って承認しないよう、WFを持たないデータから保存定理を述べない。高カインドの型引数を value に落としてから推論し直す案は採らない。


### I: 旧入力は導出から独立した構文の再帰述語にする

LegacyValueInputは旧HasTypeの導出hを引数に取らない。旧Val/CompはTypeなので、その構文への再帰でPropを定義する。`rv-l10-prop.lean` が拒否するPropの相互導出からの大消去を避け、証明だけを旧導出への帰納法で行う。下は署名と再帰の形の予定であり、型付けの結論を適格性の欄に含めない。

```lean
structure LegacyInputCtx where
  kinds : List TyKind
  constraints : List Benitoite.Release.TParam
  nr : Nat
  nv : Nat
def LegacyTypeInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (a : Benitoite.Release.Ty) (kind : TyKind) : Prop
-- embedTy aのHasKind、WF、宣言にある型引数/注釈の正則性を検査。
-- nr、kinds.length、nvをそれぞれ範囲・型・値の深さとして使う。
mutual
  def LegacyValueInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : Benitoite.Release.Val → Prop
  def LegacyValuesInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : List Benitoite.Release.Val → Prop
  def LegacyCompInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : Benitoite.Release.Comp → Prop
  def LegacyArmsInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : List Benitoite.Release.Arm → Prop
  def LegacyClausesInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : List Benitoite.Release.Clause → Prop
end
```

| 構文の群 | 再帰と局所条件 |
|---|---|
| const / bytesV / checked / checkedRequest | ConstOK、各byte≤255。裸opaqueはvalKind/valContentがnone。checkedは型に対応する同じ保持対象の所属、checkedRequestは内容を再帰しgroundVal・reqTarget・valContentの一致を要求する。内容の新HasType自体は適格性に入れない |
| fnRef / prim / op / raise / dict | lookupした宣言の各型引数を、そのkindでLegacyTypeInputへ渡す。行・範囲のWFと注釈も検査。dictの子値列を再帰する |
| lam / con / list / mapV / setV / super | lamはnames/paramsの整合・注釈を検査してnv+params.lengthで本体へ。conは型引数と子値、mapは鍵列/値列、list/set/superは各子へ再帰 |
| var / loc | 値の表現可能性の追加条件なし。変数の深さ・ストアの型は旧導出と別の文脈適格性から供給する |
| builderLet / builderOp / letIn / use | builderの型注釈を検査し、束縛先はnv+1。letInは左とnv+1の右、useは値とnv+1の本体へ再帰 |
| ret / escape / app / ite / lazyC / resume / meth | 構文にある全値・全本体へ再帰。methは型・行引数も宣言のkindで検査 |
| match / handle / arms / clauses | matchの値と全腕へ。腕のguard/bodyはArm.bindersOf altsだけnvを増やす。通常節はntysだけkinds/constraintsを、arity+1だけnvを増やす。Fail節のerror注釈・二つの値束縛・結果の型束縛も現行の構文の番号に従う |

局所条件の表をワイルドカードTrueで省略しない。返り値・計算の推論結果・局所参照の型は項だけには現れないので、後述のLegacyOutputInputで型/行/文脈を別に走査する。C_Resume・Fail・空の腕に必要な形成を構文に書かれた注釈だけから無条件に得たとはしない。構造再帰の可否だけを試した補助入力は局所条件をTrueにした形であり、適格性の完成した実装ではない。.26が値・注釈、.27が計算・腕・節と宣言本体を受け持つので、旧の全場合の割当てを一つの30分枠へ押し込まない。

文脈の入力は次の形とし、旧のC/Γ/ストア/返り値/局所参照の注釈を走査する。kindの出どころはWithKindsの表で固定する。

```lean
def LegacyContextInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Ψ : Benitoite.Release.StoreTy) (C : List Benitoite.Release.TParam)
    (Γ : List (Option Benitoite.Release.Ty)) (Δ : LegacyInputCtx) : Prop
-- constraints=C、nv=Γ.length、kinds.length=C.length、
-- Ψ/Γの各型の適格性。kind列は宣言の表又は明示の局所入力。

-- 予定。OldはBenitoite.Releaseの略記。κを結論と全ての前提に保持する。
inductive LegacyJudgment where
  | value : KindCtx → Old.StoreTy → Old.NoFailCtx → List Old.TParam →
      List (Option Old.Ty) → Old.Val → Old.Ty → LegacyJudgment
  | values : KindCtx → Old.StoreTy → Old.NoFailCtx → List Old.TParam →
      List (Option Old.Ty) → List Old.Val → List Old.Ty → LegacyJudgment
  | each : KindCtx → Old.StoreTy → Old.NoFailCtx → List Old.TParam →
      List (Option Old.Ty) → List Old.Val → Old.Ty → LegacyJudgment
  | comp : KindCtx → Old.StoreTy → Old.NoFailCtx → List Old.TParam →
      List (Option Old.Ty) → Option Old.Ty → Old.Comp → Old.Ty →
      Old.Eff → Old.LocalCtx → LegacyJudgment
  | arms : KindCtx → Old.StoreTy → Old.NoFailCtx → List Old.TParam →
      List (Option Old.Ty) → Option Old.Ty → List Old.Arm →
      Old.Ty → Old.Ty → Old.Eff → Old.LocalCtx → LegacyJudgment
  | clauses : KindCtx → Old.StoreTy → Old.NoFailCtx → List Old.TParam →
      List (Option Old.Ty) → Option Old.Ty → Old.Eff → List Old.Clause →
      Old.Ty → Old.Eff → Old.LocalCtx → LegacyJudgment
  | failure : KindCtx → Old.StoreTy → Old.NoFailCtx → List Old.TParam →
      List (Option Old.Ty) → Old.Ty → Option Old.Ty → List Old.Clause →
      Old.Ty → Old.Eff → Old.LocalCtx → LegacyJudgment
def LegacyJudgment.OldHolds (P0 : Old.Program) (B0 : Old.Builtins)
    (j : LegacyJudgment) : Prop
-- 7種類それぞれを現在の旧判断へ写す。新判断は参照しない。
def LegacyNodeRegular (K : DeclarationKinds) (P0 : Old.Program)
    (B0 : Old.Builtins) (B : Builtins) (j : LegacyJudgment) : Prop
-- jに格納された全C/κ/Γ/R/a/e/L/型列のWF・kind・宣言の整合、
-- 型引数/注釈/表現/保持に関する構文入力を検査する。
inductive LegacyRule (K : DeclarationKinds) (P0 : Old.Program)
    (B0 : Old.Builtins) : LegacyJudgment → List LegacyJudgment → Prop
-- 旧の7相互判断46規則に対応する局所規則。
-- parent/childrenの項・型・Γ・R・Lと旧の局所前提を一致させ、
-- λ/let/腕/通常節/Fail節の子のκを親又は宣言のkind表から決める。
-- 再帰する旧型付けそのものはchildrenとして記録する。
inductive LegacyOutputInput (K : DeclarationKinds) (P0 : Old.Program)
    (B0 : Old.Builtins) (B : Builtins) : LegacyJudgment → Prop where
  | node {j children} : LegacyRule K P0 B0 j children →
      LegacyNodeRegular K P0 B0 B j →
      (∀ child ∈ children, LegacyOutputInput K P0 B0 B child) →
      LegacyOutputInput K P0 B0 B j
theorem LegacyRule.old (K : DeclarationKinds) (P0 : Old.Program)
    (B0 : Old.Builtins) (j : LegacyJudgment) (children : List LegacyJudgment) :
  LegacyRule K P0 B0 j children →
  (∀ child ∈ children, child.OldHolds P0 B0) → j.OldHolds P0 B0

def LegacyTables (K : DeclarationKinds) (P0 : Old.Program)
    (B0 : Old.Builtins) (B : Builtins) : Prop
-- 署名・定数の表現・kind・保持対象/要求/端点・旧等号位置の対応。
-- 加えて全constructorの同名dataのarity一致と、埋め込んだ全欄について
-- Ty.Annotation (embedProgramWithKinds K P0) (replicate cd.ntys {}) []
--   (embedTy a)、HasKind (replicate cd.ntys .value) (embedTy a) .valueを要求する。
-- 対応の結論の新HasType、StateTy、Stepはフィールドにしない。
```

結論の型だけを走査する旧LegacyOutputInputは廃止する。新しい入力は、旧導出の全中間型を明示した、正則な旧導出の存在を表す帰納述語である。letInの左のaと右の拡張Γ、C_Appの中間の関数/結果型、空腕の結果、resumeの任意の結果、節の型束縛も各nodeで検査する。子のkind環境を自由に取り替えず、親と宣言の表からの延長に一致させる。

これはPropの導出hを分解してPropを返すdefではない。LegacyJudgmentというTypeのデータと、局所規則/正則性の帰納述語を定義する。新しい埋め込みの証明はLegacyOutputInputの証明への帰納法でPropを示す。旧HasTypeから型のkindが無条件に導けるという正則性は主張しない。適格な旧導出とはこの導出全体の入力を持つものに限り、単に根の型がkind付きであることと区別する。

局所規則の作成と検査をL10.28、再帰する入力とlet/App/Fail等の接続をL10.29に分ける（以下の新番号の表が正）。46は現行O/Typing.leanのV19・Vs2・Each2・C17・Arms3・Clauses2・Failure1の合計である。L20はこの入力の前提ごとの継承と旧判断への復元、同じ入力からの全埋め込みを受け持つ。L10はschemaと入口の代表までで、全46規則の新判断への証明を先取りしない。

LegacyTablesのconstructor条件は、旧のConDecl.Scopedの変数の範囲だけでは足りない新しい形成の入力である。これを明記して、embedProgramWithKindsのdataInfo=noneの第二節のVarianceValidと、Program.WellFormedのcons条件を構成する。入力が供給できなければ適格性を確認できないと記録し、新しい表の任意の健全性や新型付けの結論で補わない。LegacyStateInputも、各frame/ストア内のコードの型付けの葉にこの導出全体の入力を持つ形にし、全状態の証明はL20に残す。

### E: 片方向の旧導出の埋め込みと後段の署名

L10は構文・宣言・適格性と値の四葉を置く。レビューで短く閉じた葉だけの単位は.30へまとめ、注釈・適格性の供給と一緒に検査する。

```lean
-- 予定。新判断の葉。暗黙変数は全称である。
theorem embed_const {P B Ψ Q C Γ Φ} (c : Benitoite.Release.Const)
    (hc : ConstOK B (embedConst c)) :
  HasTypeVQ P B Ψ Q C Γ Φ (.const (embedConst c)) (embedTy c.type)
theorem embed_bytes {P B Ψ Q C Γ Φ} (bs : List Nat)
    (hb : ∀ b ∈ bs, b ≤ 255) :
  HasTypeVQ P B Ψ Q C Γ Φ (.bytesV bs) .bytes
theorem embed_checked {P B Ψ Q C Γ Φ o k range target}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k range target) :
  HasTypeVQ P B Ψ Q C Γ Φ (.checked target)
    (.scoped o k (.fixed (.absolute range)))
theorem embed_checkedRequest {P B Ψ Q C Γ Φ o range target req T}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some T)
    (ht : HasTypeVQ P B Ψ Qempty [] [] [] (embedVal req) T.norm)
    (hg : groundVal (embedVal req) = true)
    (he : (embedVal req).reqTarget = some target)
    (hm : Scope.Domain.Range.MemK .endpoint range target) :
  HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target (embedVal req))
    (.scoped o .endpoint (.fixed (.absolute range)))
theorem embed_normal_eq_iff (a b : Benitoite.Release.Ty) :
  (embedTy a).norm = (embedTy b).norm ↔ a.norm = b.norm
```

checked系はscopedから既存scoped_forgetで旧opaqueへ渡す。最後の要求のhtは葉の入力であり、L20の相互の埋め込みが旧の内容導出から供給する。旧の保持フラグだけから新しいground/端点一致を結論しない。

以下のOldはBenitoite.Releaseの説明用の略記である。新しいP付きのembedLeも、任意のPに対する既存二枝の片方向の橋として同じ群で更新する。全埋め込みの引数順は現行O/Typing.leanと照合する。

```lean
-- 予定、L20。Δは構文と文脈を読むデータ。LegacyOutputInputは根と全中間判断を覆う。
embedHasTypeVQ : ∀ {P0 B0 B Ψ Q C Γ v a}
    (K : DeclarationKinds) (Δ : LegacyInputCtx),
  K.WF P0 → LegacyTables K P0 B0 B →
  LegacyContextInput K P0 Ψ C Γ Δ →
  LegacyValueInput K P0 B0 B Δ v →
  LegacyOutputInput K P0 B0 B (.value Δ.kinds Ψ Q C Γ v a) →
  Old.HasTypeVQ P0 B0 Ψ Q C Γ v a →
  HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
    (Γ.map (Option.map embedTy)) [] (embedVal v) (embedTy a)
embedHasTypeCQ : ∀ {P0 B0 B Ψ Q C Γ R m a e L}
    (K : DeclarationKinds) (Δ : LegacyInputCtx),
  K.WF P0 → LegacyTables K P0 B0 B →
  LegacyContextInput K P0 Ψ C Γ Δ →
  LegacyCompInput K P0 B0 B Δ m →
  LegacyOutputInput K P0 B0 B (.comp Δ.kinds Ψ Q C Γ R m a e L) →
  Old.HasTypeCQ P0 B0 Ψ Q C Γ R m a e L →
  HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
    (Γ.map (Option.map embedTy)) [] (R.map embedTy)
    (embedComp m) (embedTy a) (embedEff e)
    (L.map (Option.map embedBuilderKind))
-- 同じ証明でVs/Each/Arms/Clauses/Failure/局所参照を扱う。
-- 空Φから任意Φへは既存弱化で拡張する。

def LegacyStateInput (K : DeclarationKinds) (P0 : Old.Program)
    (B0 : Old.Builtins) (B : Builtins) (σ : PathEnv) (s : Old.State) : Prop
-- 旧状態のコード/枠/ストアにある構文・型注釈・保持値を上の述語で検査する。
-- 新StateTyEや、閉包の行き先の等号は入力へ入れない。
embedStateTyE : ∀ {P0 B0 B σ Eb s} (K : DeclarationKinds),
  K.WF P0 → LegacyTables K P0 B0 B → σ.Valid →
  LegacyStateInput K P0 B0 B σ s → Old.StateTyE P0 B0 Eb s →
  StateTyE (embedProgramWithKinds K P0) B σ (embedEff Eb) (embedState s)
```

型付けの埋め込みは **導出全体のkind/形成が適格な旧導出→新導出だけ** とする。前提は数値・Byte・Decimal・bytesの表現可能性、同じ保持対象/要求/端点、宣言のkind表と長さ、注釈の正則性、表の明示の対応である。型引数のkindをvalueへ落とさない。新受理の増加、全域のTy.Le、δ/IOの全量化について旧新の同値を追加しない。限定等号だけをL10で示す。

**旧版のembedStepの言明は撤回する。** 旧E_Funは `(d.body.substTy ts es).instantiate ws` へ進むが、新E_Funは `Closure.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)` へ進む。embedStateが作るClosure.pureと一致しない。E_Lam/E_Return/E_Methにも同じ問題があり、表の対応を追加しても等号にはならない。

D29の適格な旧導出の保存は型付け導出の片方向の埋め込みとしてL20が示す。L70は新Stepの保存・進行・step_soundと、新しいモデル/表層の接続及び既定の全比較を示す。旧Step一段の可換性はL10/L20/L70の完了条件へ残さない。もし旧実行との一般の模倣を別途必要とするなら、closeValで閉包を読み解く状態関係と複数段の模倣が要るため、別の言明として取りまとめが範囲を決める。今回、その定理を無検査のLegacyRuntimeRelationで代用しない。embedStateTyEは型付き状態の橋であり、遷移の行き先の等号の主張ではない。

### S: 有限支持と移す補助の署名

旧 `O/TypeSupport.lean`・`FiniteSupport.lean`・`Finite.lean` の実際の宣言を移す。新しい効果の最上位は関数なので、すべての Eff の有限性を無条件に結論しない。既存の型付けへ有限性の新しい前提も加えない。

```lean
-- 予定：効果の原子の支持。述語中の値参照のWFとは別の判断。
mutual
  def Ty.Support (p : Atom → Prop) : Ty → Prop
  def Ty.SupportList (p : Atom → Prop) : List Ty → Prop
  def Eff.Support (p : Atom → Prop) : Eff → Prop
  def Tel.Support (p : Atom → Prop) : Tel → Prop
end
-- data/tapp/external: 子列。refined: carrierの支持（PredはEffを持たない）。
-- dependentFn: Tel.Support。Tel.param: argumentとrest、done: resultとeffect。
-- 旧と共通の構成子は旧と同じ再帰。Eff.mk f fsは
-- (∀a, f a=true → p a) ∧ Ty.SupportList p fs。
def Ty.Finite (a : Ty) : Prop := ∃ s : List Atom, a.Support (· ∈ s)
def Eff.Finite (e : Eff) : Prop := ∃ s : List Atom, e.Support (· ∈ s)
```

| 番号 | 移す旧宣言（旧ファイル） | 新しい完全な言明の形（暗黙変数も全称） | 単位 |
|---|---|---|---|
| F01 | `Ty.SupportList.iff`（TypeSupport） | `∀ p ts, Ty.SupportList p ts ↔ ∀ t ∈ ts, t.Support p` | .31 |
| F02 | `Eff.support_iff`（Finite） | `∀ p e, e.Support p ↔ (∀ a, e.test a = true → p a) ∧ Ty.SupportList p e.fails` | .31 |
| F03 | `Ty.norm_support`（TypeSupport） | `∀ p t, t.Support p → t.norm.Support p` | .33 |
| F04 | `Ty.normTys_support`（TypeSupport） | `∀ p ts, Ty.SupportList p ts → Ty.SupportList p (Ty.normTys ts)` | .33 |
| F05 | `Eff.norm_support`（TypeSupport） | `∀ p e, e.Support p → e.norm.Support p` | .33 |
| F06 | `Ty.support_mono`（FiniteSupport） | `∀ p q t, t.Support p → (∀ a, p a → q a) → t.Support q` | .31 |
| F07 | `Ty.supportList_mono`（FiniteSupport） | `∀ p q ts, Ty.SupportList p ts → (∀ a, p a → q a) → Ty.SupportList q ts` | .31 |
| F08 | `Eff.support_mono`（FiniteSupport） | `∀ p q e, e.Support p → (∀ a, p a → q a) → e.Support q` | .31 |
| F09 | `Ty.collectAtoms_complete`（FiniteSupport） | `∀ s t, t.Support (· ∈ s) → t.Support (· ∈ t.collectAtoms s)` | .32 |
| F10 | `Ty.collectAtomsList_complete`（FiniteSupport） | `∀ s ts, Ty.SupportList (· ∈ s) ts → Ty.SupportList (· ∈ Ty.collectAtomsList s ts) ts` | .32 |
| F11 | `Eff.collectAtoms_complete`（FiniteSupport） | `∀ s e, e.Support (· ∈ s) → e.Support (· ∈ Eff.collectAtoms s e)` | .32 |
| F12 | `Ty.collectAtoms_sound`（FiniteSupport） | `∀ p s t, t.Support p → ∀ a ∈ t.collectAtoms s, p a` | .32 |
| F13 | `Ty.collectAtomsList_sound`（FiniteSupport） | `∀ p s ts, Ty.SupportList p ts → ∀ a ∈ Ty.collectAtomsList s ts, p a` | .32 |
| F14 | `Eff.collectAtoms_sound`（FiniteSupport） | `∀ p s e, e.Support p → ∀ a ∈ Eff.collectAtoms s e, p a` | .32 |
| F15 | `Ty.collectAtoms_support_iff`（FiniteSupport） | `∀ s t, t.Support (· ∈ s) → ∀ p, t.Support p ↔ ∀ a ∈ t.collectAtoms s, p a` | .32 |
| F16 | `Eff.collectAtoms_support_iff`（FiniteSupport） | `∀ s e, e.Support (· ∈ s) → ∀ p, e.Support p ↔ ∀ a ∈ Eff.collectAtoms s e, p a` | .32 |

`collectAtoms` は上の Support と同じ子へ再帰し、Effの最上位では候補 s を所属関数で filter する。Tel版の補題は相互再帰の追加分であり、移した旧宣言の件数へ重ねない。F03〜F05は `refineNorm` と `foldFn` が効果の支持を保つ補助を使う。新しい述語の値変数を原子の支持へ混ぜない。

```lean
-- .38〜.43の予定。比較・正規化の既存の意味を変更しない。
tyCompareWith : List Atom → Ty → Ty → Ordering
tysCompareWith : List Atom → List Ty → List Ty → Ordering
effCompareWith : List Atom → Eff → Eff → Ordering
telCompareWith : List Atom → Tel → Tel → Ordering
Ty.normWith : List Atom → Ty → Ty
Ty.normTysWith : List Atom → List Ty → List Ty
Eff.normWith : List Atom → Eff → Eff
Tel.normWith : List Atom → Tel → Tel
compareWith_eq_compare : ∀ s a b, a.Support (· ∈ s) → b.Support (· ∈ s) →
  tyCompareWith s a b = tyCompare a b
Ty.normWith_eq_norm : ∀ s a, a.Support (· ∈ s) → a.normWith s = a.norm
Eff.normWith_eq_norm : ∀ s e, e.Support (· ∈ s) → e.normWith s = e.norm
Tel.normWith_eq_norm : ∀ s t, t.Support (· ∈ s) → t.normWith s = Tel.norm t
```

これは定義の形であり、コロンの各行は独立したAPIの予定である。新 `R/Order.lean` の構成子ラベルの順序を保ち、型・型列・効果・Telの組への構造再帰で有限比較を定義する。実行経路から非計算的なtoTreeとencodeAtomsを外す。新体系に独立した `effCompare`・`telCompare` はまだない。効果/Tel/型列の比較一致の相手は、それぞれ `treeCompare labelCompare e.toTree f.toTree`、同じ木比較による `Tel.toTree`、木列の辞書式比較とする。

原子の比較にも新旧の型の違いがある。`R/AtomOrder.lean` の `encodeAtoms` は新原子 a を旧原子 `.rho a.code` へ写すので、候補 s を `s.map (fun a => Benitoite.Release.Atom.rho a.code)` へ写す支持の補題を置き、旧 `O/Order/FiniteAtoms.lean` の `atomsCompareWith_eq_compare` を再使用する。実行する側では非計算的な `encodeAtoms` を呼ばず、下の有限列による関数を使う。新しい符号の順序を勝手に変えない。この接点を .39 の内数とし、比較の健全性を未検査の仮定にしない。篩の連言の順を保つこと、trueの消去、非依存dependentFnをfnへ畳むことを `normWith` でもそのまま実行する。正規化後の構造等号を、論理同値や集合の等号へ変えない。

```lean
-- 予定：有限候補上の値だけを使う実行側と、既存の非計算的な意味を結ぶ。
def finiteEncodeAtoms (s : List Atom) (f : Atom → Bool) :
    Benitoite.Release.Atom → Bool := fun old =>
  s.any (fun a => decide (old = Benitoite.Release.Atom.rho a.code) && f a)
theorem finiteEncodeAtoms_eq (s : List Atom) (f : Atom → Bool)
    (hf : ∀ a, f a = true → a ∈ s) : finiteEncodeAtoms s f = encodeAtoms f
```


F01/F02及びF06〜F16の13件は旧棚卸しfoundationの外である。新しい本番補助として.31/.32に置くが、棚卸しから移した件数nとN_gへ加えない。F03〜F05の3件だけが棚卸し内である。最初の同種群は後述の棚卸し内17件へ替える。

計算可能な非依存列の判定はL10が全て受け持つ。.40/.41で構成と一致を分け、G07から1〜2時間を外す。L20に同じ手続きを残さない。

```lean
-- 予定。defとして実行可能にし、noncomputableとはしない。
def Tel.fnViewWith? (s : List Atom) (t : Tel) : Option FnView
def Ty.foldFnWith (s : List Atom) (t : Tel) : Ty
theorem Tel.fnViewWith?_eq_some_iff (s : List Atom) (t : Tel) (f : FnView)
    (ht : t.Support (· ∈ s)) :
  Tel.fnViewWith? s t = some f ↔ f.toTel = t
theorem Tel.fnViewWith?_eq_fnView? (s : List Atom) (t : Tel)
    (ht : t.Support (· ∈ s)) : Tel.fnViewWith? s t = t.fnView?
```

Telを走査してnames/params/result/effectの候補を作り、深さiの注釈をunshiftValue i 0で戻す。NamesWFの長さと重複を判定し、候補のtoTelと入力の構造等号を有限比較で再検査する。比較の支持は入力と候補の収集の和を使う。成功時の再構築等号と、FnViewである入力での逆移動の左逆を証明し、既存FnView.toTel_injectiveとTel.fnView?_eq_some_iffで非計算的な意味に一致させる。依存が残る列はnoneである。

normWithの実行順は、子の正規化、FailのsortUnique、篩の平坦化/true消去、foldFnWithとする。normWith→foldFnWith→fnViewWith?→有限な構造比較の実行経路でClassical.choose・既存Ty.foldFn・既存Ty.normを呼ばない。既存正規化は一致定理の右辺だけに置く。eff/tel比較の意味側は既存Treeの比較とし、実行側へ非計算的な符号化を持ち込まない。

移動/置換の支持11件はL10 .34/.35に持つ。型の移動は原子の番号を保つので同じpでよい。一般置換は範囲・行原子の像を変えるので、同じpを無条件に保つとは述べない。

```lean
-- 予定。現行SubstEnvの像から、支持の移送を構造的に検査する。
def SupportTransport (p q : Atom → Prop) (θ : SubstEnv) : Prop :=
  (∀ i, (θ.types i).Support q) ∧
  (∀ e ∈ θ.rows, e.Support q) ∧
  (∀ a, p a →
    (Eff.rawBind θ (.mk (fun b => decide (b = a)) [])).Support q)
theorem Ty.rawBind_support (p q : Atom → Prop) (θ : SubstEnv) (a : Ty) :
  a.Support p → SupportTransport p q θ → (a.rawBind θ).Support q
theorem Eff.rawBind_support (p q : Atom → Prop) (θ : SubstEnv) (e : Eff) :
  e.Support p → SupportTransport p q θ → (Eff.rawBind θ e).Support q
-- 型列/Telも相互に扱う。θ.upへの閉性は値移動が原子を変えないことから導く。
```

SubstEnv.at_supportの移植先は現行typeEnvAtのSupportTransport構成補題、substAt_supportの二件はrawBindとnorm_supportの合成とする。型・行の各像の支持と単一原子の像から証明し、G表へ未記名で送らない。

### A: 共有近似・実解析の写し

`S/Approximation.lean` の近似は既に幅の証拠を持つ Interval を格納する。空の表現を一つに強制する WF を追加すると既存の adapter を作り直すため、WF は空の三表現を許し、到達の判定を所属に結び付ける。

```lean
-- 予定。Shared名前空間。特定のRelease型・評価には依存しない。
def ValueApprox.possible : Shared.ValueApprox → Bool
-- bottom=false、integer k bottom=false、integer k closed=true、
-- boolean f t = f || t、unknown=true。
def ValueApprox.WF : Shared.ValueApprox → Prop
-- bottom/boolean/unknownはTrue。
-- integer k bottomはTrue、closed l h _ は k.min≤l ∧ l≤h ∧ h≤k.max。
def FlowApprox.WF (a : Shared.FlowApprox) : Prop := a.normal.WF ∧ a.returned.WF
theorem ValueApprox.possible_iff (a : Shared.ValueApprox) :
  a.possible = true ↔ ∃ v, a.Mem v
theorem ValueApprox.not_possible_iff (a : Shared.ValueApprox) :
  a.possible = false ↔ ∀ v, ¬ a.Mem v
theorem ValueApprox.wf (a : Shared.ValueApprox) : a.WF
```

WF の最後の定理は、Interval の証拠が構文で保持されることの射影である。新しい主定理の独立前提にしない。`possible=false` でも `mayFail=true` や returned が非空でありうるので、normalの空から全制御の到達不能を結論しない。

```lean
-- 予定。Benitoite.Interval名前空間。
def baseToShared (type : Benitoite.Release.Ty) (b : BaseApprox) : Shared.ValueApprox
-- rv-02c-checks2の案：IntKind.ofType type=some kならinteger k (b.rangeKind k)、
-- Booleanはb.boolean、その他はunknown。other等の情報は粗くしてよい。
theorem baseToShared_mem {b : BaseApprox} {value : ConcreteValue}
    (h : b.Contains value) :
  (baseToShared value.type b).Mem value.toApprox
theorem normalToShared_iff {type : Benitoite.Release.Ty}
    {range : NormalRange type} {value : ConcreteValue} (typed : value.type = type) :
  (normalToShared type range).Mem value.toApprox ↔ NormalMem type range value

-- 実際の解析出力を持つ入口。任意Propから範囲を抽出しない。
def BudgetAnalysis.Report.sharedFlow (r : BudgetAnalysis.Report) (type : Benitoite.Release.Ty)
    (returned : Shared.ValueApprox) : Shared.FlowApprox :=
  ⟨baseToShared type r.approx, returned, r.approx.mayFail⟩
theorem BudgetAnalysis.Report.shared_normal (r : BudgetAnalysis.Report) (type : Benitoite.Release.Ty)
    (returned : Shared.ValueApprox) {v : ConcreteValue}
    (h : (r.toAnalysisResult type).normal v) :
  (r.sharedFlow type returned).NormalMem v.toApprox
```

`AnalysisResult.normal : ConcreteValue → Prop` は計算による正確な範囲抽出の入力ではない。`I/BudgetAnalyze.lean` の `Report.toAnalysisResult` が実際の `approx.Contains` を持つので、その出力と同じ Report を adapter へ渡す。警告・キー・停止・追跡は Report/AnalysisResult 側に残す。returned は呼出し側の明示引数であり、旧実解析が returned を推論済みとは説明しない。`shared_normal` の成功から `.failed` や `.returned` の所属へ進めない。

```lean
-- 予定。Refinement名前空間。七種の整数だけを量化する。
theorem constOK_toApprox {B : Builtins} {c : Const} {k : Benitoite.Interval.IntKind}
    (ok : ConstOK B c)
    (kindOf : Benitoite.Interval.IntKind.ofRefinementType c.type = some k) :
  ∃ n : Benitoite.Interval.IntegerValue k, c.toApprox = .integer k n
```

「ConstOKならすべての定数がotherでない」という言明は採らない。String/Byte/Decimal等も現在の adapter では `.other` へ写す。上の署名は [保存済みの補助](../l00b.02/rv-02c-checks2.lean) の七種の整数の条件を保つ。補助には証明があるが、本書で再実行又は本番へ移したとは記録しない。

## 30〜60分を基本にした起動単位

L10.01〜L10.59の59単位で、各単位の所要時間（能動時間）は0.5〜1時間である。前回のL10.05は.05〜.07、L10.13は.15〜.17、L10.14は.18〜.20、L10.27は.36/.37へ分けた。Program.WellFormedを.23、全中間型の入力を.28/.29へ足した。本文の参照は以下の新番号に統一する。主な旧番号との対応は末尾にも転記する。

.05と.13を一時間で閉じる実績はなく、全体の上端へ合わせて一時間のままにする根拠もなかった。Tyの単調性とTel/Effの相互の部分、観測の単調性と正規化と全移送を分け、初回は通常の実装結果で見込みを更新する。余裕の3時間は下の見込み節で理由を示す。独立の測定専用の単位は置かない。

| ID・目的 | 触るファイル・署名又は定義の形 | 手順・完了条件 | 依存 | 所要時間（能動時間）・検査 |
|---|---|---|---|---|
| L10.01 入口・提供表の不足判定 | 改造l10文書、R/ScopeSyntax・TermSyntax・Context・Kinds・ClosedEvaluation；下の提供表 | 了承/U01/importを確認。数値と文字、collection、対象とDET-L全31行を三つに分けて照合し、足りない定義を.02〜.23へ反映。Byte/七幅の比較を維持する判定を固定 | L00b受入・変更節の取りまとめ確認 | 0.5〜1時間・局所D |
| L10.02 変性の宣言表 | R/Syntax.lean、新R/VarianceSyntax.lean；VのDataVarianceDecl/varianceFor | Pへ既定noneのdataInfoを追加。arity/宣言の収集元を定義し、既存Program/embedProgramを再構成できることを確認 | .01 | 0.5〜1時間・局所V |
| L10.03 変性の構造検証 | 新R/VarianceValidation.lean；VのVarianceOK三族/VarianceValid | 三値の変性、非出現引数の不変、全欄/述語と提供metadataを検証。空metadataが原ソースの制約/公開境界の不存在の証拠にならないことを確認し、L70/R10bへ渡す | .02 | 0.5〜1時間・局所V |
| L10.04 P付きの部分型の骨格 | R/Le.lean及び出現表の読者；Vの四族22規則 | 既存17場合へ同じPを通し、data1/TypeArgsLe4を追加。引数の反射/長さ/正規化/推移の補助を定義群へ置く。以降の全読者の追随を同じ群で閉じる | .03 | 0.5〜1時間・局所V |
| L10.05 dataCoreと型引数列の基盤 | R/ValueFacts、新R/VarianceTransport；VのdataCore/TypeArgsLe反射・長さ・推移・norm | 旧の等号をTypeArgsLeの存在へ替え、4規則の引数列の基盤を作る。Ty/Tel/Effの単調性の本体は次の二単位へ分ける | .04 | 0.5〜1時間・局所V |
| L10.06 Tyの変性の単調性 | VarianceTransport；variance_field_monoのTy側 | 正負/不変の型の各場合とnormal形の形成を示す。欄のsourceField/targetFieldを明示し、TyからTel/Effへ渡す相互の言明をそろえる | .05 | 0.5〜1時間・局所V |
| L10.07 Tel/Effの単調性と欄の形成 | VarianceTransport/NormalWellFormed；VのTel/Eff側と代入の形成 | 依存引数の反転、result/effect、Failの不変を閉じる。constructor欄へ使う形成と単調性を一緒に供給し、未検査の信頼欄へしない | .06 | 0.5〜1時間・局所V |
| L10.08 constructor欄と宣言の移送 | R/ValueFacts・TypedFacts・DeclaredTransport.lean；inv_con/field_facts_by_type/DataImages | 欄の型を単調性で移し、dataCore_sourceと観測/Declaredの等号依存を直す。新data規則を後段の仮定へ隠さない | .05〜.07 | 0.5〜1時間・局所V |
| L10.09 部分型の移動・置換・被覆 | R/Transport・RangeSubst・ContextMap・TypeSubst・Telescope・EffectCover.lean；P付き移送 | 四族22規則に対するcontext/rawBind/bind/値・型・範囲移動を追随。Covers/SubはP不要の既存の意味を保ち、型付け側へ渡す | .08 | 0.5〜1時間・局所V |
| L10.10 型付けの値移動の追随 | R/TypingShift.leanと出現表の呼出し側；shift_values | 14判断76場合を照合し、V_Sub/C_SubのP、data引数と変性の前提の供給を直す。証明全体を再作成しない | .09 | 0.5〜1時間・局所T |
| L10.11 型付けの型移動の追随 | R/TypeShiftTyping.leanと関連Contract；shift_types | 同じ76場合の型移動を照合。新TypeArgsLeの移動は.09を使い、宣言表は同じPに固定する | .10 | 0.5〜1時間・局所T |
| L10.12 型付けの値置換の追随 | R/SubstTyping・OpenSubstitution・ValueSubst.lean；subst/subst_under_none | 同じ76場合の値置換を照合。像/欄/変性の入力を供給し、既済みの型付き像の方式を変えない | .11 | 0.5〜1時間・局所T |
| L10.13 narrowingと既存読者 | R/Narrowing・InversionCore・ReferenceCalls等の出現表；narrow | 同じ76場合のnarrowingと残るPの読者を照合。data逆転に旧等号を要求する箇所を残さず、群の途中のビルド不一致を解消する | .12 | 0.5〜1時間・局所T |
| L10.14 篩とcheckedAtの初期領域 | R/Patterns.lean；XのInhabits/refined/checkedAtOpaque、新R/ValueMeaning.leanの四つの意味の判断の定義 | Inhabits28/PatTy10規則と正規形を入口にするExhaustiveを固定し、X1の意味の不変量の骨格を定義。B/Γ/Φの引数を増やさずAt成功値と未観測の値を保つ | .13 | 0.5〜1時間・局所X |
| L10.15 観測の情報と評価の単調性 | 新R/ObservationOrder.lean；X1のInfoLE/observe_mono/evalWith_mono/close_preserves_decided | 内部slotまでの情報の順序と鍵コードの安定性を示す。someの確定値は変えず、interpretの既定値の無条件の不変性を仮定しない | .14 | 0.5〜1時間・局所X |
| L10.16 意味とInhabitsの正規化 | 新R/PatternNormalForm.lean；ValueMeaning.norm_iff/Inhabits.norm_iffと有限連言 | 意味はnormを入口に定義しnorm_idemを使う。rawなInhabitsとの同値にはWFを付け、refineNorm/平坦化/true消去/関数畳込みを照合する | .15 | 0.5〜1時間・局所X |
| L10.17 網羅性の移動・値置換・読者 | PatternSemantics/PatternTypeShift/AtPatterns/MatchPathsと四本のC_Match；X1の反映 | 正規形を読むExhaustiveへ切替え、Inhabits a[ν] w→Inhabits a.norm wから全移送を閉じる。PatTy/AltsTyとguard/match枠も追随する | .16 | 0.5〜1時間・局所X/T |
| L10.18 意味の不変量とrefineの代表 | 新R/ValueMeaning.lean/CoverageRefinement；X1のValueMeaning/意味の移送の言明 | InhabitsをIHにせず全子値と述語の真を持たせる。V_Sub/refineでpの真からEntails.soundによりqの真を得る代表を示す。全型付けへの帰納はG09 | .17 | 0.5〜1時間・局所X |
| L10.19 Month・空篩・非空List・unknown | CoverageRefinement；XのD27/Exhaustive代表 | 三つの網羅性を実証明し、観測不能な要素を持つListとunknownで腕を除かない例を含める。単なる評価例だけで完了にしない | .18 | 0.5〜1時間・局所X |
| L10.20 値依存の長さと開いた型の接続 | CoverageRefinement/PatternSemantics；X2の値依存代表・CaptureOkの接続 | 任意の閉じたnと長さnのList、0<nからV_Refineと網羅性を構成。閉じた型の意味→所属→元の開いた型の正規形への反映を示し、静的な型の合成はL70/R10bへ渡す | .19 | 0.5〜1時間・局所X |
| L10.21 Defの条件とQの一致 | 新R/ProgramTyping.lean；WのDef.WellTyped、後続Program.WellTypedへ渡す入力；W1のQTel_signatureTel/Def.QTel_eq_Qsig | TelBodyTyのdoneの戻り契約、kind/Annotationと定義の全lookup条件を固定。Program.WellTypedのvariance/externalの位置を.22へ渡す。NamesWFの下でQsigとの一致を示し、Admissibleへ新しい前提を足さない | .18〜.20 | 0.5〜1時間・局所W |
| L10.22 Impl/Programの条件と定義群の受渡し | 同ProgramTyping、既定import；WのImplDecl.WellTyped/Program.WellTyped | method/superの定義域、型代入と辞書分の値移動、targetのkindを固定。旧17場合/304枝/網羅性の追随をそろえ、群V/X/Wの全読者をそろえ、全体の既定buildは.23で通す。MethSig.QTel_eq_Qsigを使う | .21 | 0.5〜1時間・局所W |
| L10.23 Program.WellFormedの定義 | 新R/ProgramWellFormed.lean、既定import；W1の全署名 | 全宣言のSourceScoped、同名dataのarity、格納metadataのScope/Annotation/kindを定義。None/空列の検査の範囲を確認し、原ソースとの一致は主張しない。定義群全体のbuildとレビューを閉じる | .22 | 0.5〜1時間・局所W・W-L・群V/X/W |
| L10.24 kind表と宣言の写し | 新R/LegacyKinds.lean、R/Embedding.lean；Kの全署名 | DeclarationKinds/WFと四つのWithKinds変換、lookupをまとめて作る。既存全value版は保持し、constraints/names/neffs/依存位置を保存する | .23 | 0.5〜1時間・局所K・W-L |
| L10.25 kind付き署名の利用先 | 新R/LegacyDeclarations.lean；KのDeclared/HasKind/SignatureInstance | 関数/メソッド/型クラスのkindを実際の宣言の入口へ渡す。高kindのFunctor[Option]相当をvalueへ落とさず閉じる | .24 | 0.5〜1時間・局所K・W-L |
| L10.26 旧値と注釈の構文入力 | 新R/LegacyInput.lean；IのLegacyInputCtx/TypeInput/ValueInput/ValuesInput | 数値/bytes/裸opaque/保持要求/λ/型引数の局所条件と値の再帰を置く。導出hからの再帰を使わずType構文へ再帰する | .25 | 0.5〜1時間・局所I・W-L |
| L10.27 旧計算・腕・節・宣言本体の入力 | 同LegacyInput；IのCompInput/ArmsInput/ClausesInput/ContextInput | 構文に現れる全注釈/型引数と束縛深さを再帰する。構文にも最終結論にもない中間型は次のLegacyOutputInputの全導出の入力へ分け、ここで覆ったとしない | .26 | 0.5〜1時間・局所I・W-L |
| L10.28 旧判断の中間型を記録する局所規則 | 新R/LegacyRegularity.lean；IのLegacyJudgment/LegacyNodeRegular/LegacyRule | 旧7判断46規則のparent/childrenと局所前提を列挙し、let/App/腕/節の全型/Γ/R/Lとkind環境の延長を保持。新型付けの結論を入力へ入れない | .27 | 0.5〜1時間・局所I・W-L |
| L10.29 全導出の適格性の入力 | LegacyRegularity；LegacyOutputInput/LegacyRule.oldとconstructorのLegacyTables | 帰納述語で全nodeを検査し、let中間型と拡張Γを覆う代表を示す。旧判断への復元とconstructor欄のAnnotation/HasKindを確認。型付けの全埋め込みはL20へ | .28 | 0.5〜1時間・局所I・W-L |
| L10.30 値の葉・注釈・限定等号 | 新R/LegacyValues.lean、LegacyDeclarations；Eの四葉/embed_normal_eq_iff | 直接閉じる定数/bytes/保持値の葉をまとめ、scoped_forget、内容導出の入力、Annotationと埋め込み/正規化の接点を確認。短い葉ごとの単位を作らない | .29 | 0.5〜1時間・局所E/K・W-L・群K/I/E |
| L10.31 支持の定義と単調性 | 新R/TypeSupport.lean；Sの四族/Finite/F01/F02/F06〜F08 | Ty21/型列2/Eff1/Tel2を再帰し、Fail内部/refined/dependentFn/externalを含む。支持単調性とcollectAtomsの定義を置く。棚卸し外の準備を別記録にする | .23 | 0.5〜1時間・局所S・W-L |
| L10.32 収集の完全性・健全性 | 新R/FiniteSupport.lean；SのF09〜F16 | 候補sを最上位の所属関数でfilterし子へ再帰。Telを含む収集の完全性/健全性/支持同値を作る。棚卸し外13件の準備の残りを閉じる | .31 | 0.5〜1時間・局所S・W-L |
| L10.33 本番追随の正規化の支持3件 | TypeSupport、R/Normalize/FunctionNormalFormの補助；FND対応のF03〜F05 | refineNorm/foldFn/Telの支持の補助を使ってnorm_support三件を移す。通常resultsの同種17件の最初として能動時間を読める範囲で記録する | .32 | 0.5〜1時間・局所S・W-L |
| L10.34 本番追随の移動の支持5件 | TypeSupport；rawShift三件/shift二件の新形 | 旧rawShiftを現行shiftTypesへ対応させ、原子を変えない移動の支持を証明。型列/Telの相互補助を含む | .33 | 0.5〜1時間・局所S・W-L |
| L10.35 本番追随の置換の支持6件 | TypeSupport；S追加のSupportTransport/rawBind/at/substAt | 一般置換で原子の像が変わる条件を明示し、up閉性・typeEnvAt・normとの合成を証明。11件の移動/置換をL10で閉じる | .34 | 0.5〜1時間・局所S・W-L |
| L10.36 支持の反映三件・最初17件の完了 | R/FiniteSupport；support_of_norm三件 | .33三件+.34五件+.35六件と本単位三件で最初17件を閉じる。単位単位の通常resultsからA_17とc_gを読み、残N_g=2を更新する | .35 | 0.5〜1時間・局所S・W-L |
| L10.37 同種の残二件 | FiniteSupport；Eff.norm_fails_support/Eff.support_of_sub | 前単位の結果を受け残二件を移しN_gを0にする。A_17にこの二件の所要を混ぜず、本番で再利用する | .36 | 0.5〜1時間・局所S・W-L |
| L10.38 型と型列の有限比較 | 新R/FiniteCompare.lean、R/Order/AtomOrder；Sのty/tysCompareWith | 型の組へ再帰し、ラベル順/Predの有限構文の比較を保つ。非計算的toTree/encodeAtomsを実行側から外す | .36〜.37 | 0.5〜1時間・局所S・W-L |
| L10.39 Eff/Telの有限比較と一致 | FiniteCompare；Sのeff/telCompareWith/finiteEncodeAtoms_eq | 旧原子へのrho code写像を有限候補で構成し、四比較を既存Treeの意味に一致させる。比較をType全域の決定可能等号と誤認しない | .38 | 0.5〜1時間・局所S・W-L |
| L10.40 計算可能なfnViewの候補 | 新R/FiniteFunctionView.lean；S追加のTel.fnViewWith? | 名前/非依存候補を逆移動で作り、NamesWFとtoTel再構築を有限比較で検査。依存列でnoneを返す実行を定義する | .39 | 0.5〜1時間・局所S・W-L |
| L10.41 fnViewの意味との一致 | FiniteFunctionView；fnViewWith?_eq_some_iff/eq_fnView? | 支持の下で候補の往復とFnViewの一意性から一致を示す。G07に同じ決定手続きを残さない | .40 | 0.5〜1時間・局所S・W-L |
| L10.42 計算可能な正規化 | 新R/Finite.lean；SのnormWith四族/foldFnWith | 子/Fail/篩/関数畳込みの順を実行可能に定義。Classical.chooseや既存norm/foldFnが実行経路にないことを確認する | .41 | 0.5〜1時間・局所S・W-L |
| L10.43 正規化の一致と有限版12件 | Finite；foundationのFinite12件 | 支持付きの一致を相互に示し、支持/Canonical/冪等/支持独立の包装へつなぐ。旧Legacyへの三橋は移さない | .42 | 0.5〜1時間・局所S・W-L・群S前半 |
| L10.44 WFと移動の恒等の5件 | 新R/TypeRegularity.lean；foundation対応5件 | rawはshiftTypes、公開shiftはnorm付きという新形に直す。新WFだけからTy.Canonicalを仮定せず、現行NormalWellFormedを再使用する | .43 | 0.5〜1時間・局所S・W-L |
| L10.45 bind/WFの基盤7件 | 新R/TypeBounds.lean、R/TypeSubst/Context；foundation前半7件 | 像のWF・範囲/型/値の深さ・束縛順を明示し、rawBindのscope/正規化後のWFへ置き換える。旧RawWF層を複製しない | .44 | 0.5〜1時間・局所S・W-L |
| L10.46 subst/WFの基盤7件 | 同TypeBounds；foundation後半7件 | 同じ像の条件からsubstAt/subst/substListを包装する。G04の全型付けの形成補題とは別に基盤の14件を閉じる | .45 | 0.5〜1時間・局所S・W-L |
| L10.47 行の再帰基盤10件 | 新R/TypeRows.lean；foundationのRowsIn群 | 範囲のWFと行変数の支持を分け、refined/Tel/Fail内部へ拡張。iff/mono/norm/trueを新しい形で置く | .46 | 0.5〜1時間・局所S・W-L |
| L10.48 型変数の再帰基盤12件 | 新R/TypeVariables.lean；foundationのVarsIn群 | 型変数/行/範囲/値の四名前空間を区別し、iff/wf/rows/mono/normを新しい構文へ移す | .47 | 0.5〜1時間・局所S・W-L |
| L10.49 型移動の代数の前半8件 | R/TypeShiftAlgebra/ShiftOrder、新R/TypeShiftFacts.lean；foundation前半8件 | 現行のshiftTypesと比較/正規化の代数を使い、旧rawShiftに対応する新しい入口の包装を作る | .48 | 0.5〜1時間・局所S・W-L |
| L10.50 型移動と順序の残13件 | 同TypeShiftFacts；foundation後半8＋Order/Shift5件 | Canonical/zero/norm及びsortUniqueの移動を既存の証明から包装。新Tel/refinedの場合を既存の移動の代数で閉じる | .49 | 0.5〜1時間・局所S・W-L |
| L10.51 効果と行置換の6件 | R/EffectCover、新R/EffectFacts.lean；foundationの効果群6件 | singleFail/正規形での両包含の等号/TopAtoms/row置換を移す。不変なFailと一原子Coversの区別を保つ | .50 | 0.5〜1時間・局所S・W-L・群S後半 |
| L10.52 共有近似のWFと空の判定 | S/Approximation.lean、I/ApproxAdapter.lean；Aのpossible/WF/normalToShared_iff | 空の三表現を許し、所属に結ぶ。normalの空をreturned/failed全体の到達不能と説明しない | .23 | 0.5〜1時間・局所A・W-L |
| L10.53 実解析出力の写し | I/ApproxAdapter/BudgetAnalyze.lean；AのbaseToShared/Report.sharedFlow | Reportの実approxを渡し所属を証明。任意Propから計算で範囲を取り出す入力にしない。returnedは明示引数とする | .52 | 0.5〜1時間・局所A・W-L |
| L10.54 数値の共有層への接続 | R/ApproxAdapter.lean；AのconstOK_toApprox | 七整数の条件付き写像、Byte/Decimal等のotherを区別し端点を検査。定数すべての非otherを主張しない | .53/.30 | 0.5〜1時間・局所A・W-L・群A |
| L10.55 旧表と全導出への受渡し | LegacyInput/Declarations、改造l10文書；I/Eの全中間判断を含む入力と全署名 | LegacyTablesのconstructor欄/arityの適格性、LegacyOutputInputの全中間型の検査を固定。L20へ46規則の全埋め込みと正則な入力の継承を渡す。旧読者12件の代替とembedStep撤回も確認 | .30/.51/.54 | 0.5〜1時間・局所E・W-L |
| L10.56 幅/Top/Requestのコメントと07-04 | R/Syntax.lean、docs/design/07-quality/07-04-formal-semantics.mdと対応する01-12の写し | ConstOKの新前提、幅・Byte・Decimal・bytes・Top・Requestと旧対象外の説明を区別し同じ群で変更。旧の欠陥を修正したとの説明にしない。07-04の表には辞書制約/公開境界の収集がLeanの外であることを明記する | .01/.22/.54/.55 | 0.5〜1時間・局所D・W-L |
| L10.57 TODO-294の改名 | I/Budget.lean、Surface/ScopeState.lean、全Lean参照と01-12/07-04 | 二つのadmitをcheckLimitへ改名する担当案であると記録。意味を変えず全読者を直し、Rustのadmitを対象に足さない。所要は相乗り枠へ計上 | .56 | 0.5〜1時間・局所N・W-L |
| L10.58 義務とG/H表の受渡し文書 | 改造l10文書、取りまとめへ渡す表 | 37義務/158基盤/旧読者12件の代替/見込み/主定理の前提を照合。末尾の転記表へ段/G/H/Oの変更を集め、未実装を完了にしない | .57 | 0.5〜1時間・文書の選択・群D/N |
| L10.59 段末の公理依存・レビュー処置 | 既定import、実装時のl10/axioms入力/results | 最後の変更後のworkとA-Lを実行。定義・言明・仮定の独立レビューへ証拠を渡し、所見を処置して取りまとめが受入を判定する。RSSは同じ最後のworkに含める | .58及び全群の処置 | 0.5〜1時間・最終W-L・A-L・RSS |

定義変更の群は.02〜.23、kind/旧入力/葉は.24〜.30、支持/有限比較/基盤は.31〜.51、共有近似は.52〜.54である。元の定義を変えた途中を取り込まず、相互四本・全読者・既定importをそろえて群の区切りのbuildを通す。各行の局所検査と、作業末の一度のwork、公理依存/群/段末レビューの割当ては後の検査表に従う。外部呼出し/σ/範囲付き値/状態の既済みの構成子を再作成しない。

各単位の上端の2倍を超える見込みなら、原因と場合の数を調べ、関係検査とbuildが通る区切りで取りまとめへ報告する。主な定理の前提・公理・提供範囲・書ける形・精密な外部状態に触れる未承認の変更は全Lの停止条件で止める。

## foundation全158件の処分と本番追随

[L00a.07bの台帳](../l00a.07b/members.md)のfoundationは158件で、当時の対応済み7件を差し引いた未処理候補がN_g=151であった。本書の処分は **既済16（当時7＋その後9）・不要43・L10残99・他段への未記名移管0** である。151=9+43+99である。「不要」は旧の言明を新しい規則へ移さない判断で、旧ソースの削除を意味しない。

16件の対応先を読んで確認した。名称が違うものは新しい宣言名を示す。済の欄は当該基盤の対応だけであり、P引数や新data規則による今回の追随を省く意味ではない。新しいWFからTy全体のCanonicalを導く旧言明や、任意のLeQからWFを導く旧言明はそのままでは採用しない。型の移動が恒等になる旧補題も、新しい公開shiftでは結論をa.normへ直し、必要なときだけCanonicalを加える。

| 番号 | 旧宣言（Benitoite.Release.を省略） | 旧ファイル（O/） | 処分・単位 | 新しい宣言又は理由 |
|---|---|---|---|---|
| FND001 | `Ty.LeOld.le` | `CoverCompat.lean` | 不要 | 旧LeOldとの同値はD29の片方向の条件に不要。旧互換を新規則の正にしない |
| FND002 | `Ty.le_iff_leOld` | `CoverCompat.lean` | 不要 | 旧LeOldとの同値はD29の片方向の条件に不要。旧互換を新規則の正にしない |
| FND003 | `Eff.memFail_singleFail` | `Effect.lean` | L10・.51 | 新Eff.Sub/Covers/Failとrow置換の条件付きの新形 |
| FND004 | `Eff.eq_of_sub_of_sub` | `Effect.lean` | L10・.51 | 新Eff.Sub/Covers/Failとrow置換の条件付きの新形 |
| FND005 | `Eff.allows_norm` | `EffectCover.lean` | L10・.51 | 新Eff.Sub/Covers/Failとrow置換の条件付きの新形 |
| FND006 | `Eff.TopAtoms.norm` | `EffectCover.lean` | L10・.51 | 新Eff.Sub/Covers/Failとrow置換の条件付きの新形 |
| FND007 | `Eff.covers_norm_left` | `EffectCoverDef.lean` | 済 | R/EffectCover.lean：Eff.covers_norm_left |
| FND008 | `Eff.covers_norm_right` | `EffectCoverDef.lean` | 済 | R/EffectCover.lean：Eff.covers_norm_right |
| FND009 | `Ty.normWith_eq_norm` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND010 | `Ty.normTysWith_eq_norm` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND011 | `Eff.normWith_eq_norm_of_fails` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND012 | `Eff.normWith_eq_norm` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND013 | `Ty.normWith_legacy` | `Finite.lean` | 不要 | 旧Legacy表現への橋。有限な新normとの一致だけを証明する |
| FND014 | `Ty.normTysWith_legacy` | `Finite.lean` | 不要 | 旧Legacy表現への橋。有限な新normとの一致だけを証明する |
| FND015 | `Eff.normWith_legacy` | `Finite.lean` | 不要 | 旧Legacy表現への橋。有限な新normとの一致だけを証明する |
| FND016 | `Ty.normWith_support` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND017 | `Eff.normWith_support` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND018 | `Ty.normWith_canonical` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND019 | `Eff.normWith_canonical` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND020 | `Ty.normWith_idem` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND021 | `Eff.normWith_idem` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND022 | `Ty.normWith_support_independent` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND023 | `Eff.normWith_support_independent` | `Finite.lean` | L10・.43 | normWith一致/支持/正規形/冪等/支持独立の新形 |
| FND024 | `Ty.support_of_norm` | `FiniteSupport.lean` | L10・.36 | 新Supportとnorm/Coversの逆向きの支持。最初3件は同種17件 |
| FND025 | `Ty.supportList_of_norm` | `FiniteSupport.lean` | L10・.36 | 新Supportとnorm/Coversの逆向きの支持。最初3件は同種17件 |
| FND026 | `Eff.support_of_norm` | `FiniteSupport.lean` | L10・.36 | 新Supportとnorm/Coversの逆向きの支持。最初3件は同種17件 |
| FND027 | `Eff.norm_fails_support` | `FiniteSupport.lean` | L10・.37 | 新Supportとnorm/Coversの逆向きの支持。最初17件後の残二件。別単位で所要を記録 |
| FND028 | `Eff.support_of_sub` | `FiniteSupport.lean` | L10・.37 | 新Supportとnorm/Coversの逆向きの支持。最初17件後の残二件。別単位で所要を記録 |
| FND029 | `Eff.substRho_empty` | `Lemmas/Basic.lean` | L10・.51 | 新Eff.Sub/Covers/Failとrow置換の条件付きの新形 |
| FND030 | `Eff.substRho_name` | `Lemmas/Basic.lean` | L10・.51 | 新Eff.Sub/Covers/Failとrow置換の条件付きの新形 |
| FND031 | `Ty.Le.refl` | `Lemmas/Basic.lean` | 済 | R/Le.lean：Ty.LeQ.refl |
| FND032 | `Ty.Le.trans` | `Lemmas/Basic.lean` | 済 | R/Le.lean：Ty.LeQ.trans |
| FND033 | `normTys_sortUnique` | `Normalize.lean` | 済 | R/Normalize.lean：private normTys_sortUnique |
| FND034 | `Ty.norm_idem` | `Normalize.lean` | 済 | R/Normalize.lean：Ty.norm_idem |
| FND035 | `Ty.normTys_idem` | `Normalize.lean` | 済 | R/Normalize.lean：Ty.normTys_idem |
| FND036 | `Eff.norm_idem` | `Normalize.lean` | 済 | R/Normalize.lean：Eff.norm_idem |
| FND037 | `Eff.norm_memFail` | `Normalize.lean` | 済 | R/Normalize.lean：Eff.norm_memFail |
| FND038 | `Ty.norm_legacy` | `Normalize.lean` | 不要 | 旧のさらに古いLegacy表現への橋。新旧Releaseの橋embedTy_norm等と別 |
| FND039 | `Ty.normTys_legacy` | `Normalize.lean` | 不要 | 旧のさらに古いLegacy表現への橋。新旧Releaseの橋embedTy_norm等と別 |
| FND040 | `Eff.norm_legacy` | `Normalize.lean` | 不要 | 旧のさらに古いLegacy表現への橋。新旧Releaseの橋embedTy_norm等と別 |
| FND041 | `Ty.canonical_of_failsLeOne` | `Normalize.lean` | 不要 | failsLeOneからの旧Canonical。新しい篩/Telを含む正規化へ移植しない |
| FND042 | `Ty.canonicalTys_of_failsLeOne` | `Normalize.lean` | 不要 | failsLeOneからの旧Canonical。新しい篩/Telを含む正規化へ移植しない |
| FND043 | `Eff.canonical_of_failsLeOne` | `Normalize.lean` | 不要 | failsLeOneからの旧Canonical。新しい篩/Telを含む正規化へ移植しない |
| FND044 | `Ty.shift_compare_norm` | `Order/Shift.lean` | L10・.50 | 型の移動と順序/正規化。現行ShiftOrderを再使用し不足の包装を追加 |
| FND045 | `Ty.shift_compare` | `Order/Shift.lean` | L10・.50 | 型の移動と順序/正規化。現行ShiftOrderを再使用し不足の包装を追加 |
| FND046 | `shift_map` | `Order/Shift.lean` | L10・.50 | 型の移動と順序/正規化。現行ShiftOrderを再使用し不足の包装を追加 |
| FND047 | `Ty.shift_compareList` | `Order/Shift.lean` | L10・.50 | 型の移動と順序/正規化。現行ShiftOrderを再使用し不足の包装を追加 |
| FND048 | `Ty.sortUnique_shift` | `Order/Shift.lean` | L10・.50 | 型の移動と順序/正規化。現行ShiftOrderを再使用し不足の包装を追加 |
| FND049 | `Ty.wf_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない。旧読者の代替：L20 G04、R/Contextの四名前空間のWFとRangeSubstの範囲の移送を直接使う。旧WFとの同値を経由しない |
| FND050 | `Ty.wfList_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND051 | `Eff.wf_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND052 | `Ty.varsIn_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない。旧読者の代替：L20 G04／L70、型/行/範囲/値のscopeを直接分解。PrimRange/DesugarRangeの新しい署名のWF/RowsIn/Referencesの射影へ置換 |
| FND053 | `Ty.varsInList_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない。旧読者の代替：L20 G04／L70、型列のWF/RowsIn/Referencesを要素ごとに射影し、旧型列との同値を使わない |
| FND054 | `Eff.varsIn_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない。旧読者の代替：L20 G04／L70、新EffのRowsInとFail型のWF、範囲添字のWFを直接使う |
| FND055 | `Ty.RangesIn.opaque` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない。旧読者の代替：L20 G04、RangeIx.WFの射影と同じ添字のinstR/shiftRのscope保存を使う |
| FND056 | `Ty.RangesInList.opaque` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND057 | `Eff.RangesIn.opaque` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND058 | `Ty.WF.old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND059 | `Ty.wf_iff_old_of_opaqueRangesIn` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND060 | `Ty.wf_iff_old_of_rangeFree` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND061 | `Ty.VarsIn.old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND062 | `Ty.varsIn_iff_old_of_rangeFree` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND063 | `sat_unconstrained_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND064 | `sat_unconstrained_of_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND065 | `sat_local_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND066 | `sat_local_of_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND067 | `admits_local_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND068 | `admits_local_of_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない |
| FND069 | `PrimSig.scoped_iff_old` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない。旧読者の代替：L20 G08／L70、新PrimSig.Scopedを定義し各成分を直接使う。旧ScopedOldとの同値は提供しない |
| FND070 | `sig_scoped_iff_old_of_rangeFree` | `RangeWF.lean` | 不要 | 旧RangeWF表現との同値/旧意味の信頼欄の橋。新Γ/Φ/RangeIxの実装は直接扱い、旧同値を公開しない。旧読者の代替：L20 G08／L70、新sig_scopedの全量化と各実表の充足を直接供給。新表層の署名の入口も新Scopedへ切替 |
| FND071 | `Ty.WF.raw` | `TypeBounds.lean` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない。新WFの移送は像の条件付きの別の命題で示す。旧読者の代替：L20 G04、L10.44/.45の像の条件付きbind/substのWFとProperApply/HasKindを使い、RawWF層を経由しない |
| FND072 | `Ty.WFList.raw` | `TypeBounds.lean` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない。新WFの移送は像の条件付きの別の命題で示す。旧読者の代替：L20 G04、上と同じ型列のWFの移送を使う。Dict/TyLemmasの適用にはKind/ProperApplyの入力を渡す |
| FND073 | `Eff.WF.raw` | `TypeBounds.lean` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない。新WFの移送は像の条件付きの別の命題で示す。旧読者の代替：L20 G04、行の像とFail内部のWFから、正規化後のbind/substのWFへ直接進む |
| FND074 | `Ty.norm_rawWF` | `TypeBounds.lean` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない。新WFの移送は像の条件付きの別の命題で示す。旧読者の代替：L20 G04、新WFの正規化保存と、像のWFを前提にした代入後の形成で置換 |
| FND075 | `Ty.normTys_rawWF` | `TypeBounds.lean` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない。新WFの移送は像の条件付きの別の命題で示す |
| FND076 | `Eff.norm_rawWF` | `TypeBounds.lean` | 不要 | 旧RawWFとCanonicalを分離した二層を採らない。新WFの移送は像の条件付きの別の命題で示す |
| FND077 | `Ty.rawBind_rawWF` | `TypeBounds.lean` | L10・.45 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND078 | `Ty.rawBindTys_rawWF` | `TypeBounds.lean` | L10・.45 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND079 | `Eff.rawBind_rawWF` | `TypeBounds.lean` | L10・.45 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND080 | `Eff.substAt_atoms_wf` | `TypeBounds.lean` | L10・.45 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND081 | `Ty.bind_wf` | `TypeBounds.lean` | L10・.45 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND082 | `Ty.rawShift_eq_rawBind` | `TypeBounds.lean` | L10・.45 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND083 | `Ty.rawShiftTys_eq_rawBindTys` | `TypeBounds.lean` | L10・.45 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND084 | `Eff.rawShift_eq_rawBind` | `TypeBounds.lean` | L10・.46 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND085 | `Ty.shift_wf` | `TypeBounds.lean` | 済 | R/TypeSubst.lean：Ty.wf_shift |
| FND086 | `Ty.substAt_wf` | `TypeBounds.lean` | L10・.46 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND087 | `Ty.subst_wf` | `TypeBounds.lean` | L10・.46 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND088 | `Eff.bind_wf` | `TypeBounds.lean` | L10・.46 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND089 | `Eff.subst_wf` | `TypeBounds.lean` | L10・.46 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND090 | `Ty.substList_wf` | `TypeBounds.lean` | L10・.46 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND091 | `Eff.substAt_wf` | `TypeBounds.lean` | L10・.46 | 旧RawWFを複製せず、新WF/像のWF/束縛順の前提付きのbind・substの命題へ置換 |
| FND092 | `Ty.WF.canonical` | `TypeRegularity.lean` | 不要 | 新WFはTy全体のCanonicalを含まず、refine/convertのLeQから任意のWFを導けない。旧言明のまま移さない。旧読者の代替：L20 G04／L70、WFからCanonicalを結論しない。正規化した入口とnorm_idemを使い、元と同じ型へ戻す箇所は明示のNormalの証拠でつなぐ |
| FND093 | `Ty.WFList.norm_eq` | `TypeRegularity.lean` | 不要 | 新WFはTy全体のCanonicalを含まず、refine/convertのLeQから任意のWFを導けない。旧言明のまま移さない |
| FND094 | `Ty.norm_WF` | `TypeRegularity.lean` | 済 | R/NormalWellFormed.lean：Ty.wf_norm |
| FND095 | `Ty.WFList.iff` | `TypeRegularity.lean` | 済 | R/NormalWellFormed.lean：Ty.wfList_iff |
| FND096 | `Eff.norm_WF` | `TypeRegularity.lean` | 済 | R/NormalWellFormed.lean：Eff.wf_norm |
| FND097 | `Ty.Le.wf` | `TypeRegularity.lean` | 不要 | 新WFはTy全体のCanonicalを含まず、refine/convertのLeQから任意のWFを導けない。旧言明のまま移さない |
| FND098 | `Ty.Le.wf_rev` | `TypeRegularity.lean` | 不要 | 新WFはTy全体のCanonicalを含まず、refine/convertのLeQから任意のWFを導けない。旧言明のまま移さない |
| FND099 | `Ty.WF.mono` | `TypeRegularity.lean` | 済 | R/NormalWellFormed.lean：Ty.WF.weaken（型の上限） |
| FND100 | `Ty.WFList.mono` | `TypeRegularity.lean` | 済 | R/NormalWellFormed.lean：Ty.WFList.weaken（同左） |
| FND101 | `Eff.WF.mono` | `TypeRegularity.lean` | 済 | R/NormalWellFormed.lean：Eff.WF.weaken（同左） |
| FND102 | `Ty.rawShift_of_wf` | `TypeRegularity.lean` | L10・.44 | rawはshiftTypesの恒等、正規化付きshiftの結論はa.norm。a=a.normがある場合だけ旧形 |
| FND103 | `Ty.rawShiftTys_of_wf` | `TypeRegularity.lean` | L10・.44 | rawはshiftTypesの恒等、正規化付きshiftの結論はa.norm。a=a.normがある場合だけ旧形 |
| FND104 | `Eff.rawShift_of_wf` | `TypeRegularity.lean` | L10・.44 | rawはshiftTypesの恒等、正規化付きshiftの結論はa.norm。a=a.normがある場合だけ旧形 |
| FND105 | `Ty.shift_of_wf` | `TypeRegularity.lean` | L10・.44 | rawはshiftTypesの恒等、正規化付きshiftの結論はa.norm。a=a.normがある場合だけ旧形 |
| FND106 | `Eff.shift_of_wf` | `TypeRegularity.lean` | L10・.44 | rawはshiftTypesの恒等、正規化付きshiftの結論はa.norm。a=a.normがある場合だけ旧形 |
| FND107 | `Ty.RowsInList.iff` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND108 | `Ty.RowsIn.mono` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND109 | `Ty.RowsInList.mono` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND110 | `Eff.RowsIn.mono` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND111 | `Ty.norm_rowsIn` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND112 | `Ty.normTys_rowsIn` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND113 | `Eff.norm_rowsIn` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND114 | `Ty.rowsIn_true` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND115 | `Ty.rowsInList_true` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND116 | `Eff.rowsIn_true` | `TypeRows.lean` | L10・.47 | 新rows/ranges/Fail内部/Telを含む再帰述語の形へ置換 |
| FND117 | `shiftIndex_compare` | `TypeShift.lean` | L10・.49 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND118 | `Ty.rawShift_compare` | `TypeShift.lean` | L10・.49 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND119 | `Ty.rawShiftTys_compare` | `TypeShift.lean` | L10・.49 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND120 | `Eff.rawShift_compare` | `TypeShift.lean` | L10・.49 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND121 | `Ty.norm_rawShift` | `TypeShift.lean` | L10・.49 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND122 | `Ty.normTys_rawShift` | `TypeShift.lean` | L10・.49 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND123 | `Eff.norm_rawShift` | `TypeShift.lean` | L10・.49 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND124 | `Ty.rawShift_canonical` | `TypeShift.lean` | L10・.49 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND125 | `Eff.rawShift_canonical` | `TypeShift.lean` | L10・.50 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND126 | `Ty.shift_canonical` | `TypeShift.lean` | L10・.50 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND127 | `Eff.shift_canonical` | `TypeShift.lean` | L10・.50 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND128 | `Ty.rawShift_zero` | `TypeShift.lean` | L10・.50 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND129 | `Ty.rawShiftTys_zero` | `TypeShift.lean` | L10・.50 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND130 | `Eff.rawShift_zero` | `TypeShift.lean` | L10・.50 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND131 | `Ty.shift_zero_norm` | `TypeShift.lean` | L10・.50 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND132 | `Eff.shift_zero_norm` | `TypeShift.lean` | L10・.50 | 現行shiftTypes/TypeShiftAlgebraを再使用し、旧rawShift/公開shiftの新規則での包装 |
| FND133 | `Ty.norm_support` | `TypeSupport.lean` | L10・.33 | 新norm/Telの支持 |
| FND134 | `Ty.normTys_support` | `TypeSupport.lean` | L10・.33 | 新norm/Telの支持 |
| FND135 | `Eff.norm_support` | `TypeSupport.lean` | L10・.33 | 新norm/Telの支持 |
| FND136 | `Ty.rawShift_support` | `TypeSupport.lean` | L10・.34 | 型移動は同じ支持。新shiftTypes/shiftへ対応 |
| FND137 | `Ty.rawShiftTys_support` | `TypeSupport.lean` | L10・.34 | 型移動は同じ支持。新shiftTypes/shiftへ対応 |
| FND138 | `Eff.rawShift_support` | `TypeSupport.lean` | L10・.34 | 型移動は同じ支持。新shiftTypes/shiftへ対応 |
| FND139 | `Ty.shift_support` | `TypeSupport.lean` | L10・.34 | 型移動は同じ支持。新shiftTypes/shiftへ対応 |
| FND140 | `Eff.shift_support` | `TypeSupport.lean` | L10・.34 | 型移動は同じ支持。新shiftTypes/shiftへ対応 |
| FND141 | `Ty.rawBind_support` | `TypeSupport.lean` | L10・.35 | SupportTransportの像の条件付き。一般の範囲/行の変換もL10 |
| FND142 | `Ty.rawBindTys_support` | `TypeSupport.lean` | L10・.35 | SupportTransportの像の条件付き。一般の範囲/行の変換もL10 |
| FND143 | `Eff.rawBind_support` | `TypeSupport.lean` | L10・.35 | SupportTransportの像の条件付き。一般の範囲/行の変換もL10 |
| FND144 | `SubstEnv.at_support` | `TypeSupport.lean` | L10・.35 | SupportTransportの像の条件付き。一般の範囲/行の変換もL10 |
| FND145 | `Ty.substAt_support` | `TypeSupport.lean` | L10・.35 | SupportTransportの像の条件付き。一般の範囲/行の変換もL10 |
| FND146 | `Eff.substAt_support` | `TypeSupport.lean` | L10・.35 | SupportTransportの像の条件付き。一般の範囲/行の変換もL10 |
| FND147 | `Ty.VarsInList.iff` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND148 | `Ty.VarsIn.wf` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND149 | `Ty.VarsInList.wf` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND150 | `Eff.VarsIn.wf` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND151 | `Ty.VarsIn.rows` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND152 | `Ty.VarsInList.rows` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND153 | `Eff.VarsIn.rows` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND154 | `Ty.VarsIn.mono` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND155 | `Ty.VarsInList.mono` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND156 | `Eff.VarsIn.mono` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND157 | `Ty.norm_VarsIn` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |
| FND158 | `Eff.norm_VarsIn` | `TypeVariables.lean` | L10・.48 | 型変数の支持を新四名前空間と値のWFから区別して置換 |

残99件のうち、TypeSupport14件とFiniteSupport5件を同種群g（支持の保存/反映、N_g開始=19）とする。最初17件は.33のnorm_support三件、.34のrawShift/shift_support五件、.35のrawBind/at/substAt_support六件、.36のsupport_of_norm三件である。残二件のnorm_fails_support/support_of_subは.37へ分ける。棚卸し外の13補助は.31/.32で別の準備として記録し、n/N_gへ混ぜない。

c_gは.33/.34/.35/.36の単位ごとの通常resultsから、最初17件に要した能動時間A_17を読んでA_17/17とする。.36完了時に残N_g=19−17=2を記録し、同じ種類の残二件へ使う更新とする。.37の能動時間はA_17に加えず、その完了時にN_g=0へ更新する。能動時間と待ちが分離できない記録ならc_gは未取得とし、外側の時間だけを参考に添える。専用の測定や、本番へ残さない標本は作らない。

最初17件後の総残数は99−17=82（同種残2＋他群80）である。既済16・不要43・棚卸し外13を加えず、c_gを他群80やL20/G09の意味の不変量、L40の葉へ掛けない。三件と二件を同じ単位にまとめないので、今回は単位の通常記録でA_17と残二件の所要を分けられる。

### 不要とした旧言明の読者の代替

「不要43」は旧言明を新しい規則へそのまま移さない判断であり、読者の削除済みを意味しない。再レビューの12件の旧読者と代替を下に名指しする。foundationの各行にも担当を追記した。WellFormed.leanのscoped_iff_oldは説明内の参照で、RangeInst.leanには実際の証明の呼出しがある。これらはL10の未処理99へ戻さず、L20/L70が新しい入口を使う追随の内数とする。

| 旧言明（O/） | 確認した旧読者/説明の参照 | 代替の担当 | 新しい入口・前提 |
|---|---|---|---|
| `Ty.wf_iff_old` | `Release/RangeInst.lean` | L20 G04 | R/Contextの四名前空間のWFとRangeSubstの範囲の移送を直接使う。旧WFとの同値を経由しない |
| `Ty.varsIn_iff_old` | `Release/RangeInst.lean`、`Surface/PrimRange.lean`、`Surface/DesugarRange.lean` | L20 G04／L70 | 型/行/範囲/値のscopeを直接分解。PrimRange/DesugarRangeの新しい署名のWF/RowsIn/Referencesの射影へ置換 |
| `Ty.varsInList_iff_old` | `Release/RangeInst.lean`、`Surface/PrimRange.lean`、`Surface/DesugarRange.lean` | L20 G04／L70 | 型列のWF/RowsIn/Referencesを要素ごとに射影し、旧型列との同値を使わない |
| `Eff.varsIn_iff_old` | `Release/RangeInst.lean`、`Surface/PrimRange.lean`、`Surface/DesugarRange.lean` | L20 G04／L70 | 新EffのRowsInとFail型のWF、範囲添字のWFを直接使う |
| `Ty.RangesIn.opaque` | `Release/RangeInst.lean` | L20 G04 | RangeIx.WFの射影と同じ添字のinstR/shiftRのscope保存を使う |
| `PrimSig.scoped_iff_old` | `Release/WellFormed.lean`、`Release/RangeInst.lean` | L20 G08／L70 | 新PrimSig.Scopedを定義し各成分を直接使う。旧ScopedOldとの同値は提供しない |
| `sig_scoped_iff_old_of_rangeFree` | `Release/RangeInst.lean` | L20 G08／L70 | 新sig_scopedの全量化と各実表の充足を直接供給。新表層の署名の入口も新Scopedへ切替 |
| `Ty.WF.raw` | `Release/RangeInst.lean`、`Release/TypeScopedSubst.lean`、`Release/Lemmas/Dict.lean`、`Release/Lemmas/TyLemmas.lean` | L20 G04 | L10.44/.45の像の条件付きbind/substのWFとProperApply/HasKindを使い、RawWF層を経由しない |
| `Ty.WFList.raw` | `Release/Lemmas/TyLemmas.lean` | L20 G04 | 上と同じ型列のWFの移送を使う。Dict/TyLemmasの適用にはKind/ProperApplyの入力を渡す |
| `Eff.WF.raw` | `Release/TypeScopedSubst.lean` | L20 G04 | 行の像とFail内部のWFから、正規化後のbind/substのWFへ直接進む |
| `Ty.norm_rawWF` | `Release/RangeInst.lean`、`Release/Lemmas/TyLemmas.lean` | L20 G04 | 新WFの正規化保存と、像のWFを前提にした代入後の形成で置換 |
| `Ty.WF.canonical` | `Release/RangeInst.lean`、`Release/HandlerTargetExamples.lean` | L20 G04／L70 | WFからCanonicalを結論しない。正規化した入口とnorm_idemを使い、元と同じ型へ戻す箇所は明示のNormalの証拠でつなぐ |

同じ検索では、別にTy.norm_legacy/Eff.norm_legacyを使うO/TypeSubstLemmas.leanの読者も確認した。これら二件は旧Legacy層の恒等式なので、新規則の一般の恒等式にしない。L20は新しいnorm/bind/shiftの交換を直接使い、L70は残す旧互換の読者を限定する。上の12件に黙って混ぜず、旧のモジュールを残す場合の扱いを分けて記録する。検索は字面と読者の存在の確認であり、新規則で代替の全証明を既に実装したという意味ではない。

## 主な定理の前提と見直しの対象

取りまとめの追記に従い、以下は確定した判断又は取りまとめに確認を渡す定義上の選択である。設計者への同じ確認を待って計画作成を止めることはしない。実装時の定義・言明・仮定の独立レビューの対象には残す。

| 項目 | 今回固定する判断 | 主定理・提供範囲・実用への影響 |
|---|---|---|
| J01 dataの宣言の渡し方 | P付きLeQ/TelLe/TelClosureと構造的VarianceValidを採用 | P.WellTypedへconstructor欄のAnnotation/kindを含むvarianceの構造検証を追加。D14のうち欄/述語と提供されたmetadataの正負をLeanで検査し、辞書制約/公開境界の収集はL70/R10bで照合する。未検証の任意表、単調性の公理、利用者の新設定を作らない |
| J02 網羅性 | B/Γ/Φを追加せず、正規形を読むExhaustiveとcheckedAtOpaque/P_Refined、意味の不変量を採用 | Month/空型/非空List/値依存長/At成功値を保つ。型付け→ValueMeaning→Inhabitsを証明し、三値の評価の完全性や意味の所属を主定理の前提にしない |
| unusedの除外 | 非出現の型引数は不変とし、VarianceValidも不変の指定を検査 | planの最新の確定判断。Token[Read]からToken[Write]への任意の型引数の交換を追加しない |
| 述語のByte/七幅 | 共通.integerの数学上の比較を維持 | DET-L03の暗黙型変換の制限は保つ。これまで書ける比較式を禁止しない |
| 配分 | 下の三段及びL40の移動を同時に転記 | 既存の工程移動の合計は保ち、L70からのWF定義の移動と今回の見積もり不足の増分は別欄で提示する |

| 主な定理/契約 | 前提の変更の一覧 | 結論と残る担当 |
|---|---|---|
| progress | 既存形のP.WellTypedの内容をDef/ImplのTelBodyTy・kind/Annotation・constructor欄の形成/変性の検証・externalで定義する。とくにWellFormedを仮定しない入口でもvarianceを射影できる位置に置く | Final又は新Stepの結論は維持。全証明はL20/L70 |
| preservation | P.WellTyped.varianceと新しい本体条件を使う。L10.23で定義するP.WellFormedは格納済みの宣言とmetadataのscope/arityを表す。原ソースの辞書制約・公開境界の収集の一致はL70/R10bで照合する。任意のfield_monoを外部前提にしない | 新StateTyの保存を維持。L20/L70 |
| effect_soundness / noLamNames / reachable_target_sound系 | これらが渡す同じP.WellTyped/P.WellFormedの内容が上記へ変わる。計画で固定したCoreAssumptions/TargetAgreement/σの条件は増減させない。現行の束へのsig_scopedの追加はG08の既存残件 | 事象/到達対象の結論を弱めない。全合成はL70、対象の葉はL50/L60 |
| step_sound | 変性の無検査の信頼欄を追加しない。新Stepと実装したstepの一致を、その実行の構成に沿って証明する | 旧StepとembedStateの一段可換性へ結論を取り替えない。L70 |
| 型付け/状態の旧埋め込み | 宣言のkind表、構文の再帰適格性、全中間判断のLegacyOutputInput、constructor欄/arity、表現可能性、同じ保持対象/要求/端点と表の対応を明示 | 適格な旧導出→新導出の片方向。全導出はL20。単純embedStepは撤回 |
| 網羅性/進行の接点 | Exhaustiveの引数増加0でa.normを入口にする。型付けへのIHはValueMeaning、Inhabitsはその系。validはP.WellTypedから供給し、開いた型へは閉じた像からの反映を挟む | 型付け→Inhabitsを新公理/主定理の独立仮定にしない。全証明はG09 |

この表でいう前提の変更は新しい名前空間の主定理の予定であり、旧主定理の署名を今回書き換える指示ではない。新公理、独自公理依存、精密な外部状態、主定理の結論の弱化、利用者の書ける形の新しい制限はない。

J03（WithKindsを別名で追加）は取りまとめの採用済みの判断として.24/.25へ具体化した。`checkLimit` は既存の決定の記録にある名称ではなく、TODO-294の改名先の**担当案**として本書に記録する。意味を変えず全参照を直す範囲で採用する。残る分岐は **J04：failedの所属の入力条件と接続** だけで、L20/L40で具体化する。mayFailの複写を失敗の健全性とは呼ばず、normalの空/網羅性だけから失敗の主張を追加しない。実装時に予定の前提で単調性・網羅性の接続が示せない場合は、無検査の仮定で閉じず、理由と波及を取りまとめへ返す。

## 検査の割り当てとレビュー・受け入れ


本表は今後の実装の検査計画であり、今回実行したコマンドではない。今回の計画担当は文書の静的照合と<tmp>の補助入力による形の確認だけを行った。以下のB_WORKは各起動時に取りまとめが渡す直前の取り込みの完全IDに置き換える。最初の固定値は本書冒頭の値である。段内を一ブランチで続ける場合でも基準を自己判断で変えない。

| 検査・担当・時期 | 対象とコマンド | 見込み・証拠 |
|---|---|---|
| 局所V/X/W/T/K/I/E/S/A/N/D・各単位の担当、途中だけ | 該当する新モジュール又は実際の入口を持つ補助入力を、formalで `lake env lean -M 12288 <入力>`。本番の定義を複製しない。Vは検証済み変性/欄、XはD27/checkedAt/全移送、Wは定義/impl、Tは相互四本、Dは提供表と制限。Nは改名後のBudget/ScopeStateの読者、K/I/Eはkind表/保持値/構文入力、SはFail内部/非空支持、Aは全幅/空の三表現/実Report | 所要不明、短い局所実行から更新。入力・コマンド・終了・外側の時間を当該単位の結果へ保存。構成子一覧をなぞるだけのテストは追加しない |
| W-L・各単位の担当、作業末に一度 | 同じ引数の `scripts/check.sh --level work --base B_WORK --dry-run` で選択を確認後、`scripts/check.sh --level work --base B_WORK`。既定全Lean（formal_build）、変更した仕様のtext例があればspec_examples、構文を変えた場合の生成Skill/skill_docs/spec_tallyを方針どおり照合。LeanだけへRust全libを加えない | P4の約204秒は参考。直前L00b.15の737ジョブという規模と増分を踏まえ実行ごとに更新し、固定下限/積算へ使わない。resultsに選択名と実体・終了・時間・差分の識別を保存 |
| A-L・担当実行、取りまとめレビュー、L10段末 | 旧五主定理/旧三モデルと、新しいkind/埋め込み/有限支持/近似/既存相互補題を対象一覧にし、`#print axioms` を実際に実行する。formalで `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/axioms.lean`（入力は実装時に作成） | 計画の1〜5分案、build待ちは別。propext/Quot.sound/Classical.choiceだけを許し、sorryAx/独自公理/未承認依存は停止。生出力・完全名一覧をl10へ保存 |
| RSS・取りまとめ、段末の最後のW-Lのみ | sandboxの外で最後の同じworkへ計測を付ける。本体/計測器の終了、機械・OS・原単位を保存 | 追加build0回。他の単位は「未取得（計画上の非採取）」 |
| 群レビュー・取りまとめが依頼 | V/X/W(.02〜.23)、K/I/E(.24〜.30)、S(.31〜.51)、A(.52〜.54)、文書/改名/受渡しのまとまりと段末を照合。群内は同じセッションで修正。今回の計画の変更節は取りまとめが確認し、計画全体の再レビューは置かない。実装の段末は定義・言明・仮定と01-12/07-04を独立レビュー | 待ち時間不明。担当の自己点検と独立レビューを区別。重大な定義変更があれば該当群だけ再レビュー |
| 受け入れ・設計者/取りまとめ | 全37行の段別判定、既済み差引き、V/X/Wの定義と後段の受渡し条件、旧/新の読者・規範・全交換が未完である範囲を確認 | 時間不明。plan追記・取り込み・段基準固定は取りまとめ。L70/R50の全比較をL10へ前倒ししない |

## 取りまとめへの転記表

本節に段の見込み、G/Hの配分、義務の担当/完了条件の変更と番号の対応を集める。plan・theorems・レビュー原本は今回編集していない。以下は取りまとめが変更節を確認して写すための提案であり、実装の完了や新見込みの受入を代行しない。

### 段の見込みと算入先

前回の工程の移動はそのまま保ち、新たにProgram.WellFormedの定義0.5〜1時間をL70からL10へ移す。この移動自体は合計を変えない。その後の見積もり不足の訂正を別欄にする。前回の「移動だけで103〜236を維持」の表に、今回の証明作業の不足を隠して入れない。

| 段/小計 | planの当初 | 前回の移動後 | 今回の工程の移動 | 見積もり不足の訂正 | 転記する見込み |
|---|---:|---:|---:|---:|---:|
| L00b | 24〜56 | 36〜77 | 0 | 0 | **36〜77時間** |
| L10 | 22〜48 | 21〜49 | L70から+0.5〜1 | +7.5〜11 | **29〜61時間** |
| L20 | 39〜90 | 31〜75 | 0 | G09 +3〜5 | **34〜80時間** |
| 三段の小計 | 85〜194 | 88〜201 | +0.5〜1 | +10.5〜16 | **99〜218時間** |
| L40 | 18〜42 | 15〜35 | 0 | 0 | **15〜35時間** |
| 四段の小計 | 103〜236 | 103〜236 | +0.5〜1 | +10.5〜16 | **114〜253時間** |
| L70 | 24.5〜63 | 24.5〜63 | L10へ−0.5〜1 | 0 | **24〜62時間** |
| 五段の小計 | **127.5〜299** | **127.5〜299** | **0** | **+10.5〜16** | **138〜315時間** |

この表の「時間」は所要時間（能動時間）である。今回変えない他段の見込みへは増減を配らないので、改造全体の同じ算入範囲の増分も10.5〜16時間となる。前回までの純粋な移動は、L00b.02でL10から7〜12・L20から5〜9をL00bへ、次にH02から3〜7、G09/G07/G08から各1〜2をL10へ移したものである。各移動の下端同士・上端同士の合計を保つ。今回のWFの移動も、21+0.5+24.5−0.5=45.5、49+1+63−1=112で保存する。

| 今回の積上げ | 所要時間（能動時間） | 算入先と根拠 |
|---|---:|---|
| 59単位の基本枠 | **29.5〜59時間** | 各0.5〜1時間の合計 |
| L10本体58単位 | **29〜58時間** | TODO-294の一単位を除く。前回の積上げ24〜48より5〜10時間増 |
| TODO-294（L10.57） | **0.5〜1時間** | 相乗り294/315/317の6〜12時間から一度だけ計上。本体へ足さない |
| 修正の余裕 | **0〜3時間** | 単調性/形成1.5、観測・正規化0.75、旧入力/読者の接続0.75の各上限の目安。独立した測定の単位ではない |
| L10本体の転記する見込み | **29〜61時間** | 基本29〜58＋余裕0〜3。以前の配分下端21と積上げ下端24の差も解消して直接示す |
| 相乗り枠の残り | **5.5〜11時間** | TODO-294の上の一単位を除く。前回から不変 |
| 検査/build/独立レビュー/設計者の回答/受入の待ち | 不明 | 能動時間へ足さず通常resultsから読む |

増えた10単位は、旧.05の分割+2、旧.13の分割+2、旧.14の代表の分割+2、旧.27の分離+1、WellFormed+1、全中間判断の入力+2である。新しい言語機能の追加ではなく、欠けていた定義/前提の供給と中心の証明を一時間枠に隠していた点の訂正である。59×0.5−0.5=29、59×1−1+3=61を採る。前回の下端の配分と積上げの差3時間を残したまま、見込みを短く見せない。

.05〜.07の単調性は22規則の部分型とTy/Tel/Eff、反転する依存列・正規化・欄の形成を接続する。.15〜.17は観測内部の情報、三値の確定値、連言/正規化、全移送を分ける。これらを一時間で閉じる実績はなく、今回Qの短い補題が閉じた速さを掛ける根拠にもならない。上の余裕の配分は実測ではない。通常resultsで最初に実装した中心の補題の所要から更新し、単位の上端2倍と全Lの停止条件を保つ。

L00bまでの参考は[effort-ledger](../effort-ledger.md)と[最終の実績表](../l00b.15/theorems.md#実績と計画の見込み)である。.02の担当の外側約12時間2分、.03〜.14eの約12.7時間、.15の約52分には局所検査等を含む。能動時間の確定値へ直さず、代表の比を新しい意味の不変量や全埋め込みへ掛けない。支持の17件のc_gも同じ群の残二件だけに使う。

### G/Hと定義の移動

| 行 | L10で受け持つもの | 後段に残すもの・所要時間（能動時間） |
|---|---|---|
| H02 | .02〜.13のdata変性の表/検証/dataCore/単調性/既存追随。前回の移動3〜7時間は維持 | L40の標準data/δ/canonical formsの葉1〜3時間。新しい変性の定義を再追加しない |
| G09 | .14〜.20の意味の不変量、評価/正規化/値置換の反映、D27四種とrefine/捕捉の代表。前回の定義1〜2時間の移動は維持 | 閉じた型付け→ValueMeaning→Inhabits、任意の値/腕/捕捉の全接続を **4〜8時間**（旧残1〜3から+3〜5）。意味を主定理の仮定にはしない |
| G07 | .40/.41の計算可能fnViewの構成と一致。前回の1〜2時間の移動を維持 | L20のその他の形成/置換/呼出し5〜12時間。決定手続きを重ねない |
| G08 | .21/.22のWellTyped三件とQの一致。前回の1〜2時間の移動を維持 | L20の全宣言の充足/埋め込み、sig_scopedの全量化1〜3時間。P.WellFormedの定義はL10.23とする |
| L70のProgram.WellFormed | .23へ定義0.5〜1時間を移動 | L70は表層からの充足/主定理への全接続。L70の見込みは24〜62時間へ変更 |
| 旧導出の全埋め込み | .26〜.30/.55で構文入力、46局所規則、全中間型の入力、constructor欄/arityを固定 | L20は正則な旧入力からの全埋め込みと状態を証明。根だけのkindから無条件に中間型の正則性を結論しない |
| 不要43件の読者 | 上の12件の代替表と2件の旧Legacy読者の扱いを引き渡す | L20 G04/G08とL70の既存追随の内数。L10残99へ戻さず旧言明を復活させない |

### 義務の担当と完了条件の転記

| 義務 | 現行planの担当 | 担当欄へ写す変更 | 完了条件へ写す内容 |
|---|---|---|---|
| O005 | L40→R10b | **L10/L40/L70→R10b** | L10は欄/述語の変性と非出現引数の不変、H02は利用側の葉。辞書制約/公開境界の全収集と変性の一致はL70/R10bのLean外の照合 |
| O033 | L40→R10b | **L10/L40/L70→R10b** | 提供metadataの構造検証と原ソースの完全な収集を分ける。none/空列の全称が空に成り立つことを完全性の証拠にしない |
| O037 | L70 | 担当欄は据置き | 篩付きの同じ結果型/効果を保つchecker/脱糖の契約。L10.20の核の代表だけで全表層を閉じない |
| O066 | L70/R50 | 担当欄は据置き | 正規化した網羅性への接続と同じ篩付き型/効果、全交換/消去の観測を確認 |
| O079 | L70/R10b/R50 | **L10/L70/R10b/R50** | L10でMonth/空篩/非空List/値依存長・unknown・捕捉の代表。L70/R10bはlen(l)=nとn>0から静的にscrutineeの非空型を合成。L30が有限の論理の証明書を供給 |
| O138 | L20/L40/L70→R10b/R50→V10 | 担当欄は据置き | L70/R10bで分岐factsからscrutineeを強め、unknownで腕を除かず、暗黙の実行時検査を追加しない |
| O065 | L10/L20/L40 | 担当欄は据置き | LegacyOutputInputは全中間型/拡張Γ/R/Lを覆う。LegacyTablesのconstructor欄のAnnotation/HasKind/arityを明記。旧読者の代替は上の表へ対応 |
| O159 | L00a/L00b/L10/L70 | 担当欄は据置き | L10.21〜.23のWellTyped三件/WellFormedとQの一致、P付き判断22規則、正規化したExhaustiveを引き渡す |
| O160 | L00b→追随を受け持つL10/L20/L40内 | 担当欄は据置き | 最初17件は.33〜.36、残二件は.37。通常の単位ごとのresultsでA_17/17とN_g=2を対応づけ、残二件の所要を混ぜない |
| O167 | 既存のL/R/Vの担当 | 担当欄は据置き | unusedを置かず非出現引数は不変、Byte/七幅の述語比較を維持。D14の辞書/公開境界の内外をL70/R10bの照合へ対応 |
| O016/O084 | 全L／全L/R/K | 担当欄は据置き | 公理依存と形式化の内外/例外を全37行の段別判定にも含める |

判定表は元29＋前回追加4＋今回の代表/引渡し4＝37行で、A12/B16/C6/D1/E2である。O037/O066/O138の三行は本体を他段へ置く契約の確認としてCに数え、担当欄へL10を自動で足す意味ではない。L10単独で義務全体を閉じる行は0である。

### 前回の番号との対応

| 前回の単位 | 今回の単位 | 変更 |
|---|---|---|
| 旧L10.05 | L10.05〜.07 | dataCore/型引数列、Tyの単調性、Tel/Effと形成を分割 |
| 旧L10.13 | L10.15〜.17 | 評価の単調性、正規化、網羅性の全移送を分割 |
| 旧L10.14 | L10.18〜.20 | 意味の不変量/refine、三つの基本代表、値依存長/開いた型の接続を分割 |
| 旧L10.15/.16 | L10.21/.22 | WellTypedとQの一致。WellFormedをL10.23として追加 |
| 旧L10.20/.21 | L10.27〜.30 | 構文入力に加え、全中間判断の入力を.28/.29へ追加 |
| 旧L10.27 | L10.36/.37 | 最初17件を閉じる三件と、残二件を別単位へ分離 |
| 旧L10.47 | L10.57 | TODO-294は引き続き相乗り枠 |
| 旧L10.49 | L10.59 | 段末の公理依存/レビュー処置 |
