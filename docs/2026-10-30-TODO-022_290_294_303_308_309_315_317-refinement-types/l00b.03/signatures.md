# L00b.03: 文脈の完全署名

2026-10-31。指定ブランチは `m014/l00b.03`、B_WORK は `5016f55febc6973855c37dc22fda24a6317e2b28` である。git の照合・操作を行わない。共通依頼文、plan の同日の全変更行、L00b.03 と O029・O039・O053、前群の署名と申し送りを受ける。本書を実装前に置き、同じ起動で実装する。

## 配置と変更しない契約

`formal/Benitoite/Release/Refinement/Context/WF.lean` に番号・参照順序・ソースの整形式を、`Context/Facts.lean` に Φ と facts の再構成を、`Context/Declarations.lean` に宣言順と kind の補助契約を置く。既定の集約 import に追加する。既存の Ctx.WF、CaptureWF、CaptureOk、型付け・状態・Step、CoreAssumptions を変更しない。数値・近似が必要なときは Shared を直接読む。

以下の公開名の接頭辞は `Benitoite.Release.Refinement.` である。省略した暗黙変数は各型から一意に決まる。P:Program、B:Builtins、Ψ:StoreTy、Q:NoFailCtx、C:List TParam、Γ/Δ:Ctx、Φ/Ξ:List Pred、a/b:Ty、p/q:Pred、ν:ObservationEnv、cap:Capture とする。公開する補助の細部の修正は、末尾の決定の記録に理由と不採用案を記す。

## 番号・外側の参照・整形式

```lean
Ctx.outer : Ctx → Nat → Ctx
-- outer Γ i は 0..i の項目を None にし、残りの番号・注釈を保つ。
Ctx.Ordered (Γ : Ctx) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → a.References (Γ.outer i)
Ctx.Sorted (Γ : Ctx) : Prop := ∀ i a, Γ[i]? = some (some a) → a.Sorted Γ
structure Ctx.Regular (P : Program) (C : List TParam) (Γ : Ctx) : Prop where
  wf : Ctx.WF 0 C.length Γ
  sorted : Ctx.Sorted Γ
  declared : Ctx.Declared P C Γ
  ordered : Γ.Ordered

Ctx.outer_length (Γ) (i) : (Γ.outer i).length = Γ.length
Ctx.lookup_outer : (Γ.outer i)[j]? = some (some a) ↔ i < j ∧ Γ[j]? = some (some a)
Ctx.outer_extend_zero (Γ) (a) : (Γ.extend a).outer 0 = Γ.extendNone
Ctx.outer_extend_succ (Γ) (a) (i) :
  (Γ.extend a).outer (i+1) = (Γ.outer i).extendNone
Ctx.outer_extendNone_succ (Γ) (i) :
  Γ.extendNone.outer (i+1) = (Γ.outer i).extendNone
Ctx.lookup_extend (Γ) (a) (i) :
  (Γ.extend a)[i+1]? = (Γ[i]?).map (Option.map (Ty.shiftV 1 0))
Ctx.lookup_extendNone (Γ) (i) :
  Γ.extendNone[i+1]? = (Γ[i]?).map (Option.map (Ty.shiftV 1 0))
Ctx.not_readable_none : Γ[i]? = some none → ¬ Γ.Readable i
Ctx.Ordered.nil : Ctx.Ordered []
Ctx.Ordered.extend : Γ.Ordered → a.References Γ → (Γ.extend a).Ordered
Ctx.Ordered.extendNone : Γ.Ordered → Γ.extendNone.Ordered
Ctx.Ordered.lookup : Γ.Ordered → Γ[i]? = some (some a) → a.References (Γ.outer i)
Ctx.outer_readable : (Γ.outer i).Readable j → i < j ∧ Γ.Readable j
Ctx.without : Ctx → Nat → Ctx
Ctx.Depends (Γ : Ctx) (i j : Nat) : Prop :=
  ∃ a : Ty, Γ[i]? = some (some a) ∧ ¬ a.References (Γ.without j)
Ctx.Ordered.depends_lt : Γ.Ordered → Γ.Depends i j → i < j
Ctx.no_dependency_cycle : Γ.Ordered → Relation.TransGen Γ.Depends i i → False
Ctx.WF.extend : Ctx.WF nr nt Γ → a.WF nr nt Γ.length → Ctx.WF nr nt (Γ.extend a)
Ctx.WF.extendNone : Ctx.WF nr nt Γ → Ctx.WF nr nt Γ.extendNone
Ctx.Regular.empty (P) (C) : Ctx.Regular P C []
Ctx.Regular.extend : Ctx.Regular P C Γ → Ty.Annotation P C Γ a → Ctx.Regular P C (Γ.extend a)
Ctx.Regular.extendNone : Ctx.Regular P C Γ → Ctx.Regular P C Γ.extendNone
```

Ty.References と Tel.References は既存の全構成子へ再帰するので、整数だけの別判断は作らない。self は型の内部の束縛として残る。`Ctx.Ordered` はソースの注釈の参照順序の条件であり、継続のソース行を読まない CaptureWF の置換物ではない。

## Φ・facts・捕捉の延長

```lean
structure Pred.WellFormed (P : Program) (C : List TParam) (Γ : Ctx) (p : Pred) : Prop where
  wf : p.WF Γ.length
  sorted : p.Sorted Γ none
  declared : p.Declared P C Γ none
FactsWF (P : Program) (C : List TParam) (Γ : Ctx) (Φ : List Pred) : Prop :=
  ∀ p ∈ Φ, Pred.WellFormed P C Γ p
Pred.Sorted.map : p.Sorted Γ self →
  Term.ImagesSorted (match self with | none => Γ | some a => some a :: Γ)
    (match other with | none => Δ | some a => some a :: Δ) ν →
  Term.ImageReferences (match self with | none => Γ | some a => some a :: Γ)
    (match other with | none => Δ | some a => some a :: Δ) ν →
  (predBind ν p).Sorted Δ other
Pred.WellFormed.shift : ShiftMap k c Γ Δ → Pred.WellFormed P C Γ p →
  Pred.WellFormed P C Δ (p.shiftV k c)
Ty.assume_wellFormed : Ty.Annotation P C Γ a → ∀ p ∈ a.assume, Pred.WellFormed P C (Γ.extend a) p
Ctx.Regular.facts : Ctx.Regular P C Γ → FactsWF P C Γ Γ.facts
FactsWF.extend : FactsWF P C Γ Φ → FactsWF P C (Γ.extend a) (Φ.map Pred.lift)
FactsWF.extendNone : FactsWF P C Γ Φ → FactsWF P C Γ.extendNone (Φ.map Pred.lift)
Ctx.facts_entails_extend : Entails (Γ.facts ++ Φ) p →
  Entails ((Γ.extend a).facts ++ Φ.map Pred.lift) p.lift
Ctx.facts_entails_extendNone : Entails (Γ.facts ++ Φ) p →
  Entails (Γ.extendNone.facts ++ Φ.map Pred.lift) p.lift
Capture.facts_extend :
  (∀ p ∈ Γ.facts ++ Φ, Entails [] (predBind (valEnv cap.env).values p)) →
  HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a) →
  ∀ p ∈ (Γ.extend a).facts ++ Φ.map Pred.lift,
    Entails [] (predBind (valEnv (cap.extend v).env).values p)
CaptureOk.facts_extend : CaptureOk P B Ψ R Γ Φ cap →
  HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a) →
  ∀ p ∈ (Γ.extend a).facts ++ Φ.map Pred.lift,
    Entails [] (predBind (valEnv (cap.extend v).env).values p)
```

facts は元の列と像の列の等号を要求しない。型付きの値から assume_optional を使って含意を作り、元の facts と Φ の像を使う。関数の未観測値を整数0とみなさない。捕捉の一般の CaptureOk 保存、全遷移の保存とは区別する。

## 宣言順・依存列・固定した kind

```lean
BinderTypes.Annotations (P : Program) (C : List TParam) : Ctx → List Ty → Prop
-- [] は True、a::as は Annotation P C Γ a ∧ Annotations P C (Γ.extend a) as。
BinderTypes.Annotations.wf : BinderTypes.Annotations P C Γ as → BinderTypes.WF C.length Γ as
BinderTypes.Annotations.sorted : BinderTypes.Annotations P C Γ as → BinderTypes.Sorted Γ as
BinderTypes.Annotations.extendMany : Ctx.Regular P C Γ →
  BinderTypes.Annotations P C Γ as → Ctx.Regular P C (Γ.extendMany as)
BinderTypes.localWF_iff : BinderTypes.LocalWF nt Γ.length as ↔ BinderTypes.WF nt Γ as
Tel.inputs : Tel → List Ty
Tel.context : Ctx → Tel → Ctx
Tel.annotation_inputs : Ty.Annotation P C Γ (.dependentFn t) →
  BinderTypes.Annotations P C Γ t.inputs
Tel.annotation_result : Ty.Annotation P C Γ (.dependentFn t) →
  Ty.Annotation P C (t.context Γ) (Tel.result t)
Tel.regular_context : Ctx.Regular P C Γ → Ty.Annotation P C Γ (.dependentFn t) →
  Ctx.Regular P C (t.context Γ)
TypeArgsKindedAt (P : Program) (D : List TParamDecl) (ts : List Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∀ i a k, ts[i]? = some a → ks[i]? = some k →
    a.HasKind P (D.map TParamDecl.kind) k
TypeArgsKindedAt.forget : TypeArgsKindedAt P D ts ks →
  TypeArgsKinded P (D.map TParamDecl.constraints) ts ks
TypeArgsKindedAt.shift / subst : 値の shiftV / substTyValues を全 ts に適用して同じ D の判断を保つ
OpDecl.SignatureWF (d : OpDecl) : Prop :=
  BinderTypes.LocalWF d.tparams.length 0 d.params ∧ d.ret.WF 0 d.tparams.length d.params.length
Program.OpSignaturesWF (P : Program) : Prop := ∀ o d, P.ops o = some d → d.SignatureWF
Program.OpSignaturesWF.user : Program.OpSignaturesWF P →
  opSigAt P B S (.user o) = some sg → sg.WF
-- 組込みは既存の表の適格性を増やさず、元の宣言と instTarget の WF から接続する。
BinderTypes.LocalWF.instTarget : BinderTypes.LocalWF nt n ps →
  BinderTypes.LocalWF nt n (ps.map (Ty.instTarget rs))
```

`Program.WellTyped` 自体をここで新設・変更しない。宣言表の構文から供給する局所の正則性を分け、L20 の主な定理への接続時に既定の全 Program.WellTyped へ組み込む。kind は呼出し元の宣言 D に一度固定し、既存の存在量化した補助へ忘れる向きだけを供給する。存在する K が常に D の kind 列に等しいとは主張しない。

## 場合の数と境界入力

予定は outer のリスト/番号の 3 枝、Ordered の lookup の 0/succ、文脈の拡張の some/None、BinderTypes と Tel の nil/cons・done/param、Pred.Sorted.map の全16構成子である。型付けの三族各71場合、TypedFacts56場合、Step76場合は増減しない。新しい値/計算/遷移の構成子は0である。最終の実数は results と機械の一覧へ記す。

補助入力は (1) 外側の値依存を持つ2引数 Tel の逐次具体化、(2) 依存βの型付き引数列、(3) None を間に残した facts/Φ、(4) 型付き値から捕捉を延長した後の facts と CaptureOk の入口、(5) self/後方/相互循環の拒否、(6) 同じ型変数を異なる kind で照合し直すことの拒否、(7) CaptureWF と Ctx.WF の相違を扱う。正例の結論や先の状態を仮定しない。test-audit の作成時の関門は results に記す。

## L20 等へ残す分

O029 の一般の型/行/範囲/値の相互置換と全状態の保存、O039 の canonical/ground からの全状態の facts、O053 のソースの文脈形成での Regular の保存は L20/L40 に残す。第31節の normConts/builderBody_image_norm/CaptureOk.normConts、CaptureWF からの結果の正則性、型置換の型付けも L20 のままである。閉じた評価は L00b.04、受信後の全篩の検査は .04/.05 へ残す。

## 補助の契約の決定の記録

| 論点 | 採る案と理由 | 捨てた案 |
|---|---|---|
| 参照順序 | 同じ長さの outer が自分と内側を隠す。既存の全構文の References をそのまま使える | Γ.length だけの検査は循環を通す。型や構文を Fin に変える案は U01 に反する |
| ソースと捕捉 | Regular を補助判断として追加し、CaptureWF と既存 WF は保つ | CaptureOk に Regular を追加する案はソース継続の行の問題を再導入する |
| kind | 宣言した D の kind 列で全引数を照合してから既存の入口へ渡す | 存在する K の長さだけで宣言の kind の一貫性を主張する案は採らない |
| 事実の延長 | 型付き像の assume_optional と構文の置換の交換を使う | 新しい facts の閉じた真を前提に取る案、意味上の全値の所属を外部前提へ置く案は採らない |

実装中に補助の細部を決めた場合は本節へ追記する。主な定理の前提・結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態の変更が必要なら停止する。


### 実装中の補助契約の具体化

捕捉の入口まで確認するため、facts だけの再構成に加えて `Context/Capture.lean` に下の一般の補題を置く。ソースの `Ctx.WF` を要求せず、継続の行を読まない既存の CaptureWF をそのまま移す。新しい信頼条件はない。

```lean
Capture.closeTy_shift (cap : Capture) (v : Val) (a : Ty) :
  (cap.extend v).closeTy (a.shiftV 1 0) = cap.closeTy a
-- Capture.closeTy_shift_none は extendNone の削除に伴い除いた。
Ty.CaptureWF.shift : a.CaptureWF nr nt nv →
  (a.shiftV k c).CaptureWF nr nt (nv+k)
ShiftMap.captureSorted : ShiftMap k c Γ Δ → a.CaptureSorted Γ →
  (a.shiftV k c).CaptureSorted Δ
ShiftMap.captureDeclared : ShiftMap k c Γ Δ → a.CaptureDeclared P C Γ →
  (a.shiftV k c).CaptureDeclared P C Δ
CaptureOk.extend : CaptureOk P B Ψ R Γ Φ cap → Ty.Annotation P [] Γ a →
  HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a) → v.Ground →
  CaptureOk P B Ψ R (Γ.extend a) (Φ.map Pred.lift) (cap.extend v)
-- CaptureOk.extendNone は RV-L00b.03 後に削除した。後掲の extendHidden を使う。
CaptureOk.extendTel : CaptureOk P B Ψ R Γ Φ cap →
  Ty.Annotation P [] Γ (.dependentFn t) →
  HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) a e →
  (∀ v ∈ vs, v.Ground) →
  CaptureOk P B Ψ R (t.context Γ) (liftMany t.arity Φ) (cap.extendMany vs)
```

署名の追加の理由は、facts の成立だけで CaptureOk の入口に接続したと数えないためである。拡張後の CaptureOk 自身を前提にする案は採らない。`Ctx.Regular.facts` は証明中の V_Var の表を具体化するため任意の B を明示引数として受ける。B の性質や追加の信頼条件は要求しない。

宣言の補助には `Ty.TargetWF`（対象の最上位だけ範囲変数を許す）と `BinderTypes.TargetWF`、`PrimSig.OperationWF`、`Builtins.OpSignaturesWF` を追加する。`OpDecl.SignatureWF` と合わせ、`ClauseSig.wf` が表の構文上の正則性から user/prim の両方の署名の WF を返す。CoreAssumptions の欄を足さず、最上位以外にも未具体化の範囲変数を残す宣言を無条件に正則と呼ぶ案は採らない。`SignatureInstanceAt` は元の SignatureInstance の五欄のうち kinds だけを TypeArgsKindedAt に固定し、forget で既存の型付けへ渡す。

Tel には `context_eq_extendMany`、`inputs_length`、`annotation_effect`、`annotation_open` も公開する。最後の補題は元の文脈の WF、元の param 全体の Annotation、実引数の HasTypeVQ から後続 Tel の Annotation を返し、具体化後の Annotation を前提にしない。これらの完全な型は群末の public-api.log へ出力する。


### 群末の公開署名の確定

全公開定義・定理の完全名を [public-targets.txt](public-targets.txt)、Lean が出力した省略なしの引数の型を [public-api.log](public-api.log) に置く。[public-api.lean](public-api.lean) がその照合入力である。本書の先行する署名の欄に加えた補助は次である。

- `Ctx.Ordered.refined_outer` は lookup の篩の述語について、self の Ordinary と外側の厳密な参照順序を返す。循環の不在を自然数の長さの上限で済ませない。
- `ShiftMap.outerValue` と `Ty.References.shift_none` は値・None の共通の移動を与える。既存の `ShiftMap.annotation` を再利用し、同名の新しい定義を置かない。
- `Ctx.sortSelf` は Pred.Sorted が既に使う `some a :: Γ` の場合分けに名前を付けた補助である。`Pred.Sorted.wf_none`・`Pred.WellFormed.map` はその既存の参照判断から WF と移送を返す。Declared の self は従来どおり `Γ.extend a` である。
- `Capture.bind_extend_lift`・`bind_extend_assume` は、捕捉の延長の構文の交換を与える。初回の bind_extendNone_lift と Capture.facts_extendNone は、RV-L00b.03 後に遷移で使わない捕捉の形の整理として削除した。
- `FactsWF.extendMany` は宣言順の列の拡張と `liftMany` を一致させる。
- `Ty.instTarget_fixed`、`Ty.TargetWF.instTarget`、`BinderTypes.TargetWF.instTarget`、`Program.OpSignaturesWF.user`、`Builtins.OpSignaturesWF.prim`、`ClauseSig.wf` は、ユーザー操作・組込み操作の宣言表と範囲の具体化を OpSig.WF へ接続する。`TargetWF` は最上位以外の範囲変数を許すという意味ではない。RangeExpr の内容・kind・Canonical はこの番号の WF と別の既存の条件である。

予定の Pred の場合数「16」は誤記であり、実際は14である。生成した構成子一覧で全14場合を照合する。Ty は21、Tel は2であり、捕捉の三つの移動は Ty の全21場合へ追随する。型付け三族各71とTypedFacts56・Step76の既存の担当は増減しない。

Program.WellTyped は現行 Refinement に未定義であり、本作業で主な定理の前提として新設していない。今回の `Program.OpSignaturesWF` と `SignatureInstanceAt` は、宣言表から供給する構文の補助契約と、その既存型付けへの接続である。全本体の導出を同じ呼出し元の宣言と照合し、最終の Program.WellTyped にまとめる作業は L20/L70 が持つ。旧 TypeArgsKinded の存在する K を宣言の kind 列へ同定する偽の逆向きは置かない。


## RV-L00b.03 後の決定と公開署名（2026-10-31）

取りまとめの plan の先頭の判断に従う。本節が前の実装時点の記述を更新する。

| 所見 | 採った処置・理由・捨てた案 |
|---|---|
| 中1・案(b) | 参照順序はソースの注釈の判断である。CaptureOk に Ordered や Regular の欄を足さない。閉じた型付き像と事実が成立する捕捉では循環が意味上無害であり、CaptureOk に Ordered を加えると読まないと決めた継続のソース行を再び検査するためである。l00b.02 の CaptureOk の「外側参照順」の記述も訂正した。O053 の残りは HasTypeCQ の文脈の形成で Regular が保たれることである |
| 中2・実行値の残るNone | CaptureOk.extendHidden と extendCont を本番へ移す。None の位置に実値が残る形と、継続の場所を some の継続の位置へ加える形を区別する。通常値の HasTypeVQ で継続を作る案は採らない |
| 中2・extendNoneの扱い | 遷移が作らない CaptureOk.extendNone は削除し、None の位置に値が残る extendHidden を使う。その専用の Capture.closeTy_shift_none・Capture.bind_extendNone_lift・Capture.facts_extendNone も削除する。既存の Capture.extendNone の構文と Ctx.extendNone・FactsWF.extendNone は変更しない。実行と無関係な捕捉の形を本番の補題として保つ案は採らない |
| 軽1 | Depends は、注釈iについてjを隠すと References が成立しなくなる関係とする。全構文の References と内部束縛の規約を再利用でき、独立した変数出現の再帰を増やさない。Ordered から Depends の厳密な外向きの順序を導き、no_dependency_cycle に Ordered の前提を置く。単なる自然数の大小の閉包だけを依存と呼ぶ前の言明は差し替える |
| 軽2 | future_input_rejected を out_of_scope_input_rejected に改名し、番号の範囲外の拒否と明記する。順序の負例は長さの WF を通る自己・後方・相互循環、および Depends の実際の辺で示す |
| 軽3 | Pred.Valid を Pred.WellFormed へ、Ty.assume_valid を Ty.assume_wellFormed へ改名する。真理や含意を表す名前を避け、旧名の別名は残さない。wf 欄は CaptureOk の三つ組へ受け渡すために残す |

移植する補題の完全な型は次である。接頭辞は Benitoite.Release.Refinement である。レビューの regular_hide・regular_bindParams は Ctx.Regular.hideConts・Ctx.Regular.bindParams として置く。

```lean
Ctx.Regular.hideConts : Ctx.Regular P C Γ → Ctx.Regular P C (hideConts Γ)
Ctx.Regular.bindParams (n : Nat) : ∀ {ps Γ}, ps.length = n →
  Ctx.Regular P C Γ → TypeAnnotations P C Γ ps → Ctx.Regular P C (bindParams Γ ps)
CaptureOk.extendHidden : CaptureOk P B Ψ R Γ Φ cap → (w : Val) → w.Ground →
  CaptureOk P B Ψ R Γ.extendNone (Φ.map Pred.lift) (cap.extend w)
CaptureOk.extendCont : CaptureOk P B Ψ R Γ Φ cap →
  (Ty.cont b t e).CaptureWF 0 0 Γ.length →
  (Ty.cont b t e).CaptureSorted Γ → (Ty.cont b t e).CaptureDeclared P [] Γ →
  cap.closeTy (.cont b t e) = .cont b' t' e' → (cap.closeTy (.cont b t e)).WF 0 0 0 →
  Ψ l = some (.cont b' t' e' R) → (∀ r, R = some r → r.WF 0 0 0) →
  CaptureOk P B Ψ R (Γ.extend (.cont b t e)) (Φ.map Pred.lift) (cap.extend (.loc l))
```

以下を L20/L70 の義務として一行ずつ残す。

| 所見・送り先 | 閉じる義務 |
|---|---|
| 軽4・L20 | 本群の依存βの境界は hideConts Γ = Γ の場合である。rv-03-hide.lean の CaptureOk.hide・beta_target/full_target のように、元の捕捉を本体の hideConts Γ へ移し R を任意へ変える向きと、hideBuilders Ψ の捕捉を元の Ψ へ戻す向きを閉じる。ValueAssumptions と Ψ.WF、通常の場所の型の保持を照合し、E_Lam の先の t.context (hideConts Γ) へ接続する。逆向きだけの hide の申し送りでは閉じない |
| 軽5・L20/L70 | TypeArgsKindedAt の型の shift と置換、型の束縛を越える D の延長を閉じる。通常節の sg.tparams ++ C と Fail 節の文脈で使う D は呼出し元の宣言から与え、kind を持たない List TParam だけから選び直さない |
| 軽6・L20 | Regular の shiftE・OpSig.context・failureContext・Narrows での保存を閉じ、HasTypeCQ の文脈の形成に接続する。Narrows.here の行き先の型には WF だけでなく必要な Sorted/Declared/参照順序を供給する。今回移した hideConts・bindParams の保存と分けて扱う。未実行の残りを確認済みとは数えない |

移植と改名の後の公開署名は r2-public-api.lean/log、ビルドと公理依存は r2 の記録を正とする。初回の public-api.log と検査の集計は当時の履歴である。レビューの記録と rv-* の原文は変更しない。
