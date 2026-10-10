# 依頼: 形式検証の段階 B1 の、証明の作業で変えた定義と言明のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

関数型スクリプト言語 Benitoite の設計書の「コア計算と脱糖」（01-12）の規則を Lean 4 で書き写し、進行と保存・エフェクトの健全性を証明している（形式検証の段階 2）。段階 B1 の定義と定理の言明は、前回あなたにレビューしてもらった（そのときの指摘は反映済み）。その後、証明を書き上げ、`Theorems.lean` の四つの定理（`step_sound`・`progress`・`preservation`・`effect_soundness`）は `sorry` なしで通った。公理は `propext`・`Classical.choice`・`Quot.sound` だけである。

証明の作業の中で、定義と言明を次のように変えた。今回のレビューの対象は、この変更だけである。証明の本体は Lean が検査したのでレビューしない。

1. 型の変数の表し方を、外側から数えたレベルから、内側から数えた番号（de Bruijn の番号）に変えた。`handle` の節は操作の型パラメータを番号 0..k-1 に束縛し、節の外側の型（環境 Γ の型、`handle` の式の型 T、R）を `Ty.shift k 0` でずらす。置き換え `Ty.substAt c ts es` は番号 c 以上の変数を置き換え、入れる型を c だけずらす。
2. 型付けの規則のうち、項に現れない型を選べるもの（V-List の要素の型、C-Escape の型、分岐のない `match` の結果の型、K-Empty・K-Mark・K-Handle の型）に、型の正しさ（束縛された型の変数だけを使うこと、`Ty.WF n`）の前提を加えた。ストアの型付けに、Ψ の型が型の変数を含まないことを加えた。
3. 項の型（`Ty.VarsIn`）が継続の型を含まないことにした（継続の型は項に書けない）。
4. 01-12 の規則の誤りを二つ見つけ、ADR を添えて 01-12 を直し、Lean の定義を合わせた。
   - ADR 0301: 継続の型付けに K-Sub（継続が受け取る型を広げる）を加えた。
   - ADR 0302: K-Handle の節を、枠の下の継続が許すエフェクトに含まれるエフェクト εc で検査するようにした。
5. 仮定を変えた: `admits_closed`・`sat_closed` を `admits_local`・`sat_local` に置き換え、`admits_sat` を加え、`admits_shift`・`sat_shift` を消した。
6. 証明に使わなかった前提を定理から外した（`step_sound` から `hwf`・`hwt`・`hdecl`、`progress` から `hwf`・`hwt`）。`UnhandledOp` の定義を `Theorems.lean` から `Semantics.lean` へ移した。

## 見てほしいこと

1. 変更 1 の番号の扱い（`Ty.shift`・`Ty.substAt`・`Comp.substTyAt` の節の中の切れ目 `c + k`、`HasTypeClauses` の `shiftEnv`・`R.map (Ty.shift k 0)`、`E_Op` の `c.body.substTy ts []`）が、01-12 の「節が束縛する型パラメータ」と E-Op の θ = [T̄/ᾱ] の意味に一致しているか。
2. 変更 2・3 が、01-12 の型付けを狭めていないか。狭めているなら、01-12 で型が付くが形式化で型が付かない項があり、定理がその項を扱わないことになる。01-12 が型の正しさを暗黙に前提すると言えるか、言えないなら直し方の案。
3. 変更 4 の二つの ADR の内容が妥当か（01-12 の規則の誤りの直し方として、弱めすぎ・強めすぎがないか）。
4. 変更 5 の仮定が妥当で、07-04 の仮定の表（資料 4）に対応しているか。
5. 定理の言明（資料 3 の `Theorems.lean`）が 01-12 の性質を弱めていないか。

必要な資料はすべてこの依頼に含めた。リポジトリのファイルを読む必要はない。どうしても確かめたいことがあるときだけ、読む範囲を行で絞って読むこと。

## 出力の形

指摘ごとに次を書く。重要なものから並べる。問題がない観点は「問題なし」と一行で書く。

- 重さ: 高（定理が 01-12 の性質より弱い、または 01-12 と意味が違う）／中（段階 B2 で問題になる）／低（表記・説明）
- 場所: ファイルと行（01-12 の場合は規則名）
- 問題
- 原因の分類: 01-12 の規則の誤り／書き写しの誤り／表現の都合／その他
- 直し方の案

回答は日本語で書く。

## 資料 1: ADR 0301 と ADR 0302

```markdown
# 0301. 継続の型付けに、受け取る型の包含の規則 K-Sub を加える

- 状態: 採択
- 日付: 2026-09-30
- 関連章: [コア計算と脱糖](../../../../../formal/reviews/01-spec/01-12-core-calculus.md), [形式意味論と検証](../../../../../formal/reviews/07-quality/07-04-formal-semantics.md)
- 関連する未決事項: なし

## 背景

[コア計算と脱糖](../../../../../formal/reviews/01-spec/01-12-core-calculus.md)の「確かめる性質」の継続の型付け `R; ε ⊢k K : A ⇒ B ! ε0` は、枠ごとの規則（K-Empty・K-Let・K-Mark・K-Update・K-Release・K-Handle・K-Drop）からなり、受け取る型 A を広げる規則を持たない。K-Mark は、`mark` の枠の上の計算に許す `escape` の型 R を、受け取る型 A そのものにする。

形式検証の段階 B1 の証明を設計する過程で（[形式意味論と検証](../../../../../formal/reviews/07-quality/07-04-formal-semantics.md)）、この規則では E-Resume の保存が成り立たないことが分かった。次の定義を考える。

```text
fn g[;]() : A ! ε = handle M with { op() k ⇒ if c then escape w else resume k v }
```

`handle` の式の型を t とし、A は t より広い関数の型（`t ≤ A`、エフェクトだけが広い）、`w : A` とする。節の本体は `R = A` で検査するので、`escape w` に型が付く。E-Fun が `mark` を積み、E-Op の後、節の本体が `resume κ v` に達した状態の継続は `drop κ :: mark :: K''` である。`resume κ v` の型 t を C-Sub で A に広げれば、この状態には型が付く。

E-Resume の後の継続は `[handle □ with H] ++ drop κ :: mark :: K''` である。`handle` の枠は t の値を下へ渡すので、`drop κ :: mark :: K''` は t を受け取る。K-Mark により、`mark` の枠の上の R は t になる。一方、`handle` の枠の節は `R = A` で検査しなければ `escape w` に型が付かない。K-Handle は枠の上と下で同じ R を使うので、この継続に型が付かない。

実行としては、`handle` の式の結果（型 t の値）を、戻り値の型 A の関数の結果として返すだけであり、誤りはない。規則が、枠が受け取る値の型を広げることを許していないことが原因である。

## 決定

1. 継続の型付けに、次の規則を加える。

   ```text
   (K-Sub)   R; ε ⊢k K : A' ⇒ B ! ε0     A ≤ A'
             ─────────────────────────────────
             R; ε ⊢k K : A ⇒ B ! ε0
   ```

2. K-Sub は、受け取る型だけを広げ、R・ε・ε0 と、継続の結果の型 B を変えない。

## 検討した代替案

- **K-Mark だけを、R を受け取る型より広くできる形に改める**: 上の例は解消する。しかし、同じ問題は、`update` の枠（明示遅延の本体の中の `handle` で `resume` した後）と `handle` の枠（入れ子の `handle` の本体の結果）でも起こる。枠ごとに規則を改めるより、受け取る型の包含を一つの規則で表すほうが規則が少ない。
- **E-Resume の後に、捕まえた継続の `handle` の枠を、今の継続が受け取る型で型付けし直す**: 節の本体が `resume` の結果を型 t の値としてほかの関数に渡していると、型を広げた節には型が付かない。

## 帰結

- 01-12 の「確かめる性質」に K-Sub を加える。
- 形式化（`formal/`）の段階 B1 の継続の型付けに、構成子 `K_Sub` を加える。
- 処理系の実装と実装プランは変えない。
```

```markdown
# 0302. K-Handle で、節のエフェクトを枠の下の継続が許すエフェクトに含まれればよいとする

- 状態: 採択
- 日付: 2026-09-30
- 関連章: [コア計算と脱糖](../../../../../formal/reviews/01-spec/01-12-core-calculus.md), [形式意味論と検証](../../../../../formal/reviews/07-quality/07-04-formal-semantics.md)
- 関連する未決事項: なし

## 背景

[コア計算と脱糖](../../../../../formal/reviews/01-spec/01-12-core-calculus.md)の継続の型付けの K-Handle は、`handle` の枠の下の継続が許すエフェクト ε と、節を検査するエフェクトを同じ ε とし、枠の上で `ε ∪ handled(H)` を許す。

形式検証の段階 B1 の証明を設計する過程で（[形式意味論と検証](../../../../../formal/reviews/07-quality/07-04-formal-semantics.md)）、この規則では E-Resume の保存の証明が大きくなることが分かった。E-Resume は、ストアに置いた継続 K' を今の継続 K の上につなぐ（`K' ++ K`）。K' の末尾の `handle` の枠は、節のエフェクト ε_h で型付けされている。一方、`resume` の計算のエフェクトは ε_h を含み、C-Sub で広げられるので、K が許すエフェクト ε_cur は ε_h より広いことがある。K-Handle が枠の下のエフェクトと節のエフェクトを等しく求めるので、つないだ継続に型を付けるには、K' のすべての枠を ε_cur に持ち上げて型付けし直す必要がある。持ち上げには、節の本体を、継続の変数の型のエフェクトを広げた環境で型付けし直す補題が要る。

節の本体は、`handle` の枠の下の継続の中で実行される（E-Op が積む `drop κ` の枠の下は、`handle` の枠の下の継続である）。したがって、節の本体のエフェクトが、枠の下の継続が許すエフェクトに含まれていれば足りる。

## 決定

1. K-Handle を次の形にする。

   ```text
   (K-Handle)  R; ε ⊢k K : T ⇒ B ! ε0     εc ⊆ ε
               H の各節 op(x̄) k ⇒ N について、op : ∀ᾱ. (Ā) → B' ! {L}、ᾱ はほかの何とも等しくない型として
                 x̄:Ā, k:Cont(B' → T ! εc); R ⊢c N : T ! εc
               ─────────────────────────────────────
               R; εc ∪ handled(H) ⊢k (handle □ with H) :: K : T ⇒ B ! ε0
   ```

2. これまでの K-Handle は、εc = ε とした場合に当たる。この規則で型が付く継続は、これまでの規則でも型が付く継続を含む。

## 検討した代替案

- **K-Handle を変えず、E-Resume の保存の証明で K' の枠を持ち上げる**: 規則は変わらない。しかし、節の本体の型付けを、継続の変数の型のエフェクトを広げた環境で作り直す補題が要り、その補題は、`escape` の結果の型に継続の型を選んだ計算など、意味のない計算の型付けまで扱う必要がある。規則を緩めるほうが、健全性の論証が短い。

## 帰結

- 01-12 の「確かめる性質」の K-Handle を改める。
- 形式化（`formal/`）の段階 B1 の継続の型付けの構成子 `K_Handle` を、この形にする。
- 処理系の実装と実装プランは変えない。
```

## 資料 2: 前回のレビューの後の差分（01-12・07-04・Lean の定義）

```diff
diff --git a/docs/design/01-spec/01-12-core-calculus.md b/docs/design/01-spec/01-12-core-calculus.md
index 3554191..cdbdf47 100644
--- a/docs/design/01-spec/01-12-core-calculus.md
+++ b/docs/design/01-spec/01-12-core-calculus.md
@@ -1,7 +1,7 @@
 # コア計算と脱糖
 
 - 状態: 確定
-- 関連ADR: [0005](../../../../../formal/reviews/decisions/0005-direct-style-effects.md), [0007](../../../../../formal/reviews/decisions/0007-constructors-and-list.md), [0008](../../../../../formal/reviews/decisions/0008-effect-variables.md), [0013](../../../../../formal/reviews/decisions/0013-evaluation-order-and-tail-calls.md), [0014](../../../../../formal/reviews/decisions/0014-fine-grain-cbv-core.md), [0045](../../../../../formal/reviews/decisions/0045-late-detection-of-output-write-failure.md), [0046](../../../../../formal/reviews/decisions/0046-effect-subsumption-at-all-flow-positions.md), [0048](../../../../../formal/reviews/decisions/0048-ioerror-not-equality-type.md), [0055](../../../../../formal/reviews/decisions/0055-top-level-functions-and-types-only.md), [0058](../../../../../formal/reviews/decisions/0058-string-interpolation-of-base-types.md), [0081](../../../../../formal/reviews/decisions/0081-subsumption-on-computation-results.md), [0096](../../../../../formal/reviews/decisions/0096-explicit-return.md), [0097](../../../../../formal/reviews/decisions/0097-prefix-try.md), [0099](../../../../../formal/reviews/decisions/0099-qualified-option-result-constructors.md), [0102](../../../../../formal/reviews/decisions/0102-pair-and-triple.md), [0103](../../../../../formal/reviews/decisions/0103-map-and-set-ordered-by-key.md), [0105](../../../../../formal/reviews/decisions/0105-byte-type.md), [0107](../../../../../formal/reviews/decisions/0107-bytes.md), [0108](../../../../../formal/reviews/decisions/0108-keyword-blocks-closed-by-end.md), [0109](../../../../../formal/reviews/decisions/0109-lambda-keyword.md), [0110](../../../../../formal/reviews/decisions/0110-if-then-end-if.md), [0111](../../../../../formal/reviews/decisions/0111-case-of-when.md), [0112](../../../../../formal/reviews/decisions/0112-pascal-style-operators.md), [0113](../../../../../formal/reviews/decisions/0113-div-and-mod-operators.md), [0114](../../../../../formal/reviews/decisions/0114-decimal-type.md), [0116](../../../../../formal/reviews/decisions/0116-builtin-fine-grained-effects.md), [0117](../../../../../formal/reviews/decisions/0117-capabilities-as-effects.md), [0118](../../../../../formal/reviews/decisions/0118-effect-handlers.md), [0121](../../../../../formal/reviews/decisions/0121-pattern-extensions.md), [0123](../../../../../formal/reviews/decisions/0123-top-level-constants.md), [0124](../../../../../formal/reviews/decisions/0124-type-aliases.md), [0128](../../../../../formal/reviews/decisions/0128-prelude-and-benitoite-namespace.md), [0129](../../../../../formal/reviews/decisions/0129-effects-declared-in-modules.md), [0130](../../../../../formal/reviews/decisions/0130-builtin-effect-names-and-placement.md), [0133](../../../../../formal/reviews/decisions/0133-builtin-equality-and-key-constraints.md), [0134](../../../../../formal/reviews/decisions/0134-standard-type-classes.md), [0140](../../../../../formal/reviews/decisions/0140-network-separated-from-local-io.md), [0145](../../../../../formal/reviews/decisions/0145-network-error.md), [0146](../../../../../formal/reviews/decisions/0146-runtime-errors-not-in-types.md), [0149](../../../../../formal/reviews/decisions/0149-http-exchange-release-failure.md), [0150](../../../../../formal/reviews/decisions/0150-resource-release-as-state.md), [0151](../../../../../formal/reviews/decisions/0151-inherited-handlers-tail-resume-only.md), [0155](../../../../../formal/reviews/decisions/0155-resume-not-in-lazy.md), [0168](../../../../../formal/reviews/decisions/0168-regex-match-and-stdlib-opaque-values.md), [0177](../../../../../formal/reviews/decisions/0177-server-mode-after-first-release.md), [0184](../../../../../formal/reviews/decisions/0184-permissions-granted-per-builtin-effect.md), [0254](../../../../../formal/reviews/decisions/0254-return-type-after-arrow.md), [0255](../../../../../formal/reviews/decisions/0255-bind-and-shadow.md), [0257](../../../../../formal/reviews/decisions/0257-match-with-case-arms.md), [0272](../../../../../formal/reviews/decisions/0272-list-spread-in-list-literals.md), [0293](../../../../../formal/reviews/decisions/0293-formal-verification-stage-2-alongside-first-release.md), [0295](../../../../../formal/reviews/decisions/0295-core-calculus-chapter-normative-over-formalization.md), [0296](../../../../../formal/reviews/decisions/0296-delta-receives-type-arguments.md), [0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md), [0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md), [0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)
+- 関連ADR: [0005](../../../../../formal/reviews/decisions/0005-direct-style-effects.md), [0007](../../../../../formal/reviews/decisions/0007-constructors-and-list.md), [0008](../../../../../formal/reviews/decisions/0008-effect-variables.md), [0013](../../../../../formal/reviews/decisions/0013-evaluation-order-and-tail-calls.md), [0014](../../../../../formal/reviews/decisions/0014-fine-grain-cbv-core.md), [0045](../../../../../formal/reviews/decisions/0045-late-detection-of-output-write-failure.md), [0046](../../../../../formal/reviews/decisions/0046-effect-subsumption-at-all-flow-positions.md), [0048](../../../../../formal/reviews/decisions/0048-ioerror-not-equality-type.md), [0055](../../../../../formal/reviews/decisions/0055-top-level-functions-and-types-only.md), [0058](../../../../../formal/reviews/decisions/0058-string-interpolation-of-base-types.md), [0081](../../../../../formal/reviews/decisions/0081-subsumption-on-computation-results.md), [0096](../../../../../formal/reviews/decisions/0096-explicit-return.md), [0097](../../../../../formal/reviews/decisions/0097-prefix-try.md), [0099](../../../../../formal/reviews/decisions/0099-qualified-option-result-constructors.md), [0102](../../../../../formal/reviews/decisions/0102-pair-and-triple.md), [0103](../../../../../formal/reviews/decisions/0103-map-and-set-ordered-by-key.md), [0105](../../../../../formal/reviews/decisions/0105-byte-type.md), [0107](../../../../../formal/reviews/decisions/0107-bytes.md), [0108](../../../../../formal/reviews/decisions/0108-keyword-blocks-closed-by-end.md), [0109](../../../../../formal/reviews/decisions/0109-lambda-keyword.md), [0110](../../../../../formal/reviews/decisions/0110-if-then-end-if.md), [0111](../../../../../formal/reviews/decisions/0111-case-of-when.md), [0112](../../../../../formal/reviews/decisions/0112-pascal-style-operators.md), [0113](../../../../../formal/reviews/decisions/0113-div-and-mod-operators.md), [0114](../../../../../formal/reviews/decisions/0114-decimal-type.md), [0116](../../../../../formal/reviews/decisions/0116-builtin-fine-grained-effects.md), [0117](../../../../../formal/reviews/decisions/0117-capabilities-as-effects.md), [0118](../../../../../formal/reviews/decisions/0118-effect-handlers.md), [0121](../../../../../formal/reviews/decisions/0121-pattern-extensions.md), [0123](../../../../../formal/reviews/decisions/0123-top-level-constants.md), [0124](../../../../../formal/reviews/decisions/0124-type-aliases.md), [0128](../../../../../formal/reviews/decisions/0128-prelude-and-benitoite-namespace.md), [0129](../../../../../formal/reviews/decisions/0129-effects-declared-in-modules.md), [0130](../../../../../formal/reviews/decisions/0130-builtin-effect-names-and-placement.md), [0133](../../../../../formal/reviews/decisions/0133-builtin-equality-and-key-constraints.md), [0134](../../../../../formal/reviews/decisions/0134-standard-type-classes.md), [0140](../../../../../formal/reviews/decisions/0140-network-separated-from-local-io.md), [0145](../../../../../formal/reviews/decisions/0145-network-error.md), [0146](../../../../../formal/reviews/decisions/0146-runtime-errors-not-in-types.md), [0149](../../../../../formal/reviews/decisions/0149-http-exchange-release-failure.md), [0150](../../../../../formal/reviews/decisions/0150-resource-release-as-state.md), [0151](../../../../../formal/reviews/decisions/0151-inherited-handlers-tail-resume-only.md), [0155](../../../../../formal/reviews/decisions/0155-resume-not-in-lazy.md), [0168](../../../../../formal/reviews/decisions/0168-regex-match-and-stdlib-opaque-values.md), [0177](../../../../../formal/reviews/decisions/0177-server-mode-after-first-release.md), [0184](../../../../../formal/reviews/decisions/0184-permissions-granted-per-builtin-effect.md), [0254](../../../../../formal/reviews/decisions/0254-return-type-after-arrow.md), [0255](../../../../../formal/reviews/decisions/0255-bind-and-shadow.md), [0257](../../../../../formal/reviews/decisions/0257-match-with-case-arms.md), [0272](../../../../../formal/reviews/decisions/0272-list-spread-in-list-literals.md), [0293](../../../../../formal/reviews/decisions/0293-formal-verification-stage-2-alongside-first-release.md), [0295](../../../../../formal/reviews/decisions/0295-core-calculus-chapter-normative-over-formalization.md), [0296](../../../../../formal/reviews/decisions/0296-delta-receives-type-arguments.md), [0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md), [0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md), [0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md), [0301](../../../../../formal/reviews/decisions/0301-subsumption-on-continuation-input.md), [0302](../../../../../formal/reviews/decisions/0302-k-handle-clause-effect-within-below.md)
 - 未決事項: [OPEN-068](../../../../../formal/reviews/open-issues.md#open-068)
 - 移行元: [設計メモ](../../../../../formal/reviews/sources/fp-language-design.md) 25.2
 
@@ -767,21 +767,25 @@ mark ▷ K  =  mark :: K    （それ以外）
             ─────────────────────────────────────
             R; ε ⊢k (release V) :: K : A ⇒ B ! ε0
 
-(K-Handle)  R; ε ⊢k K : T ⇒ B ! ε0
+(K-Handle)  R; ε ⊢k K : T ⇒ B ! ε0     εc ⊆ ε
             H の各節 op(x̄) k ⇒ N について、op : ∀ᾱ. (Ā) → B' ! {L}、ᾱ はほかの何とも等しくない型として
-              x̄:Ā, k:Cont(B' → T ! ε); R ⊢c N : T ! ε
+              x̄:Ā, k:Cont(B' → T ! εc); R ⊢c N : T ! εc
             ─────────────────────────────────────
-            R; ε ∪ handled(H) ⊢k (handle □ with H) :: K : T ⇒ B ! ε0
+            R; εc ∪ handled(H) ⊢k (handle □ with H) :: K : T ⇒ B ! ε0
 
 (K-Drop)    Ψ(κ) = (Cont(B' → A' ! ε'), R')     State ∈ ε' ならば State ∈ ε     R; ε ⊢k K : A ⇒ B ! ε0
             ─────────────────────────────────────
             R; ε ⊢k (drop κ) :: K : A ⇒ B ! ε0
+
+(K-Sub)     R; ε ⊢k K : A' ⇒ B ! ε0     A ≤ A'
+            ─────────────────────────────────────
+            R; ε ⊢k K : A ⇒ B ! ε0
 ```
 
 - C-Use の `rel(O_r)` は、リソースの型 O_r の解放のエフェクトであり、初回リリース版ではどのリソースの型でも `{State}` である。
 - C-ResumeL は、節の変数 k を場所 κ に置き換えた後の `resume` の型付けである。`resume` の R は、κ を作った節の R と等しい。`resume` はラムダと `lazy` の本体の中に書けないので、節の中の `resume` はこの条件を満たす。
-- K-Mark は、関数の本体の結果の型 A を、その本体の中の `escape` の型にする。K-Update は、`thunk` の本体の実行の上に `escape` を許さない。
-- K-Handle は、`handle` の枠の上で、H が処理するエフェクトを許す。節は、枠の下の継続と同じ R と ε で検査する（C-Handle と同じ）。K-Drop の `drop` の枠は、受け取った値をそのまま渡すので、受け取る型 A は κ の答えの型と等しくなくてよい。E-Op が積んだ `drop` の枠では、A は κ の答えの型と等しいが、`releases(K')` で別の継続の先頭に移した `drop` の枠では、その継続を流れる値の型を受け取る。
+- K-Mark は、関数の本体の結果の型 A を、その本体の中の `escape` の型にする。 K-Sub は、継続が受け取る型を広げる。`handle` の式の型が、それを本体とする関数の戻り値の型より狭いとき、E-Resume の後の継続に型を付けるのに要る（[ADR 0301](../../../../../formal/reviews/decisions/0301-subsumption-on-continuation-input.md)）。K-Update は、`thunk` の本体の実行の上に `escape` を許さない。
+- K-Handle は、`handle` の枠の上で、H が処理するエフェクトを許す。節は、枠の下の継続と同じ R で、枠の下の継続が許すエフェクトに含まれるエフェクト εc で検査する。節の本体は枠の下の継続の中で実行されるので、εc が ε に含まれれば足りる。εc と ε を等しくしないのは、E-Resume で捕まえた継続を、より広いエフェクトを許す継続の上につなぐためである（[ADR 0302](../../../../../formal/reviews/decisions/0302-k-handle-clause-effect-within-below.md)）。K-Drop の `drop` の枠は、受け取った値をそのまま渡すので、受け取る型 A は κ の答えの型と等しくなくてよい。E-Op が積んだ `drop` の枠では、A は κ の答えの型と等しいが、`releases(K')` で別の継続の先頭に移した `drop` の枠では、その継続を流れる値の型を受け取る。
 - `drop κ` の枠が E-DropRel で加える `releases(K')` は、K' の中の `release` の枠と `drop` の枠である。解放のエフェクト `State` は、どの `handled(H)` にも含まれない。継続の枠が先頭で許すエフェクトは、下の枠のものに K-Handle が `handled(H)` を加えたものなので、ある枠が `State` を許していれば、その下のすべての枠も `State` を許している。K' の中の `release` の枠が `State` を許していれば、K' の末尾（κ の継続の型のエフェクト ε'）も `State` を許している。K-Drop の前提「State ∈ ε' ならば State ∈ ε」により、`drop` の枠の位置でも `State` を許しているので、`releases(K')` を `drop` の枠の位置に加えても型が付く。E-Op が積む `drop κ` の枠では、ε' は `handle` の式のエフェクトであり、`drop` の枠の位置のエフェクトと等しいので、この前提は成り立つ。前提がないと、この上下関係を持たないストアと `drop` の枠の組み合わせにも型が付き、保存が破れる（[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）。
 - ストア σ が Ψ のもとで型が付くとは、Ψ が型を与える場所に σ の中身があり（σ と Ψ の場所が一致する。[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）、σ のすべての場所について次が成り立つことである。σ(ℓ) = V なら `Ψ(ℓ) = Reference[A]` かつ `· ⊢v V : A`。σ(ℓ) = thunk(M) なら `Ψ(ℓ) = Lazy[A]` かつ `·; none ⊢c M : A ! { }`。σ(ℓ) = done(V) なら `Ψ(ℓ) = Lazy[A]` かつ `· ⊢v V : A`。σ(κ) = cont(K') なら `Ψ(κ) = (Cont(B → T ! ε), R_κ)` であり、K' の末尾の `handle` の枠に K-Handle を R_κ で使う導出で、ある R'、ε' について `R'; ε' ⊢k K' : B ⇒ T ! ε` が成り立つ。σ(κ) = used なら、Ψ(κ) は継続の型と R の組である。
 - 状態 `⟨M, K, σ⟩` に型が付くとは、σ が Ψ のもとで型が付き、`·; R ⊢c M : A ! ε1`、`ε1 ⊆ ε`、`R; ε ⊢k K : A ⇒ B ! Eb` が成り立つ Ψ、R、A、B、ε、ε1 があることである。Eb は組み込みのエフェクトの名前の集合である。`error(r̄, K, σ)` と `exit(n, r̄, K, σ)` に型が付くとは、σ が Ψ のもとで型が付き、`R; ε ⊢k K : A ⇒ B ! Eb` が成り立つ Ψ、R、A、B、ε があることである。 いずれの状態の型付けでも、継続の判断は、末尾の K-Empty を `R = none` で使う導出で満たす。実行は `⟨main[;](), [], ∅⟩` から始まり、関数の本体の `escape` は関数の呼び出しが積んだ `mark` の枠で止まるので、実際に到達する状態はこの条件を満たす。この条件がないと、`⟨escape V, [], σ⟩` に型が付き、進行が成り立たない（[ADR 0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md)）。
diff --git a/docs/design/07-quality/07-04-formal-semantics.md b/docs/design/07-quality/07-04-formal-semantics.md
index bc225a7..a3298da 100644
--- a/docs/design/07-quality/07-04-formal-semantics.md
+++ b/docs/design/07-quality/07-04-formal-semantics.md
@@ -1,7 +1,7 @@
 # 形式意味論と検証
 
 - 状態: 草稿
-- 関連ADR: [0014](../../../../../formal/reviews/decisions/0014-fine-grain-cbv-core.md), [0018](../../../../../formal/reviews/decisions/0018-reference-interpreter.md), [0146](../../../../../formal/reviews/decisions/0146-runtime-errors-not-in-types.md), [0213](../../../../../formal/reviews/decisions/0213-formal-verification-stage-1-in-first-release.md), [0293](../../../../../formal/reviews/decisions/0293-formal-verification-stage-2-alongside-first-release.md), [0294](../../../../../formal/reviews/decisions/0294-lean-4-for-formal-verification.md), [0295](../../../../../formal/reviews/decisions/0295-core-calculus-chapter-normative-over-formalization.md), [0296](../../../../../formal/reviews/decisions/0296-delta-receives-type-arguments.md), [0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md), [0298](../../../../../formal/reviews/decisions/0298-split-stage-b-into-control-and-types.md), [0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md), [0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)
+- 関連ADR: [0014](../../../../../formal/reviews/decisions/0014-fine-grain-cbv-core.md), [0018](../../../../../formal/reviews/decisions/0018-reference-interpreter.md), [0146](../../../../../formal/reviews/decisions/0146-runtime-errors-not-in-types.md), [0213](../../../../../formal/reviews/decisions/0213-formal-verification-stage-1-in-first-release.md), [0293](../../../../../formal/reviews/decisions/0293-formal-verification-stage-2-alongside-first-release.md), [0294](../../../../../formal/reviews/decisions/0294-lean-4-for-formal-verification.md), [0295](../../../../../formal/reviews/decisions/0295-core-calculus-chapter-normative-over-formalization.md), [0296](../../../../../formal/reviews/decisions/0296-delta-receives-type-arguments.md), [0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md), [0298](../../../../../formal/reviews/decisions/0298-split-stage-b-into-control-and-types.md), [0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md), [0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md), [0301](../../../../../formal/reviews/decisions/0301-subsumption-on-continuation-input.md), [0302](../../../../../formal/reviews/decisions/0302-k-handle-clause-effect-within-below.md)
 - 未決事項: [OPEN-068](../../../../../formal/reviews/open-issues.md#open-068), [OPEN-069](../../../../../formal/reviews/open-issues.md#open-069)
 - 移行元: [設計メモ](../../../../../formal/reviews/sources/fp-language-design.md) 25.1, 25.3, 0.2
 
@@ -47,6 +47,8 @@
 
 段階 A は 2026-09-30 に完了した。性質 2・3 と、遷移を計算する関数と遷移の関係の一致を証明した。定理が使う公理は、Lean の標準の `propext` と `Quot.sound` だけである。定義と定理の言明は、証明の前に Codex のレビューを経た（[ADR 0296](../../../../../formal/reviews/decisions/0296-delta-receives-type-arguments.md)）。
 
+段階 B1 は 2026-09-30 に完了した。性質 2・3 と、遷移を計算する関数が返す遷移が関係の遷移であること（健全性）を証明した。定理が使う公理は、Lean の標準の `propext`・`Classical.choice`・`Quot.sound` だけである。定義と定理の言明は、証明の前に Codex のレビューを経た（[ADR 0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md)、[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）。証明の作業では、01-12 の規則の誤りを二つ見つけて直し（[ADR 0301](../../../../../formal/reviews/decisions/0301-subsumption-on-continuation-input.md)、[ADR 0302](../../../../../formal/reviews/decisions/0302-k-handle-clause-effect-within-below.md)）、型の変数の表し方と型の正しさの前提を改めた（次節の対応の表）。
+
 ### 形式化で仮定するもの
 
 【方針】01-12 は、組み込みの関数の型と値（関数 δ）と IO の応答を、ほかの章に委ねている。形式化では、これらの中身を定義せず、次の性質を定理の仮定として与える。Lean の `axiom` としては置かず、定理の引数（`formal/` の `Builtins.Assumptions`）として明示する。
@@ -99,13 +101,13 @@
 | 末尾呼び出しの保証、置き換えてよい等式 | 対象外 | |
 | 表層からの脱糖 | 対象外（性質 1） | |
 | 初回リリース版の拡張: モジュール、トップレベルの定数、リストの展開、レコード、文字列補間 | 対象外（脱糖だけで表す） | |
-| 初回リリース版の拡張: 型パラメータの組み込みの制約 | 段階 B1 | 型付けの判断は、型パラメータの制約の並び（レベルの順）を持つ。型が制約を満たすか（等値の型・鍵の型）は 01-06 に委ね、組み込みの関数の欄として与える |
+| 初回リリース版の拡張: 型パラメータの組み込みの制約 | 段階 B1 | 型付けの判断は、型パラメータの制約の並び（型の変数の番号の順）を持つ。型が制約を満たすか（等値の型・鍵の型）は 01-06 に委ね、組み込みの関数の欄として与える |
 | 初回リリース版の拡張: 基本型 `Byte`・`Decimal`、中身を見せない型 | 段階 B1 | 中身を見せない型は名前で表し、リソースの型かどうかを組み込みの関数の欄として与える |
 | 初回リリース版の拡張: ストア | 段階 B1 | ストアは場所から中身への関数とし、有限であることはストアの型付けの条件にする。ストアの操作を行う組み込みの関数は、組み込みの関数の種類で区別し、その型は仮定として与える。`Reference.update` の遷移は、`Reference.get`・`Reference.set` の名前を組み込みの関数の欄として与えて書く |
 | 初回リリース版の拡張: 関数の境界と `escape`、`with`、プロセスの終了 | 段階 B1 | 解放の事象の応答は、組み込みの関数の欄として与える。プロセスの終了の関数は組み込みの関数の種類の一つとし、その応答 `exit(n)` に E-Exit を使う。IO の事象は、型引数とエフェクト引数を含めない（応答の関係には渡す）。`escape`・実行時エラー・終了の状態が `drop` の枠を通るときの扱い（01-12「ハンドラ」の箇条）を、規則 E-EscDrop・E-EscDropRel・E-ErrDrop・E-ErrDropRel・E-ExitDrop・E-ExitDropRel として書く。E-EscLet・E-ErrPop・E-ExitPop は、枠の種類ごとの規則に分けて書く |
 | 初回リリース版の拡張: エフェクトの名前と開始状態 | 段階 B1 | エフェクトの名前は、モジュールと名前の組を一つの文字列で表す。組み込みのエフェクトとその操作の一覧は、組み込みの関数の欄として与える |
-| 初回リリース版の拡張: ハンドラ | 段階 B1 | 型の変数を外側から数えたレベルで表し、節が束縛する操作の型パラメータを、節を囲む型パラメータの後のレベルにする。実行中の項は型の変数を含まないので、E-Fun と E-Op の置き換えは、閉じた型を先頭のレベルに入れ、残りのレベルを詰める。V-Lam と `lazy` の検査で環境から継続の型の変数を除くことは、環境の要素を `none` に置き換えて表す（番号をずらさないため）。E-Op は節の本体に操作の型引数の置き換えを施す（[ADR 0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。継続の型の値を `resume` の第一引数に限る規則（[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）は、V-Var の前提と、`resume` の第一引数ごとの規則 C-Resume（節の変数）・C-ResumeL（継続の場所）で表す。組み込みの操作の E-Op は、規則 E-OpPrim として分けて書く。同じ操作の節が二つあるときは、最初の節を選ぶ |
-| 確かめる性質（初回リリース版の読み替え） | 段階 B1 | ストアの型付けの「Ψ と σ の場所が一致する」と K-Drop の `State` の条件（ADR 0300）は、01-12 のとおりに書く。継続の末尾の R を `none` とする状態の型付けの条件（[ADR 0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md)）は、継続の型付けの末尾の R の添字で表す。状態の型付けに、状態の中の項が型の変数を含まないことを加える（01-12 は実行を `main` から始めるので暗黙に成り立つ）。継続の型付けに、継続の末尾での R を添字として加え、ストアの継続の型付けの「末尾の `handle` の枠に K-Handle を R_κ で使う」を表す。性質 3 の「IO の事象を伴う遷移をしない」は、解放の事象を含むすべての事象を伴わないこととして言明する（より強い形）。性質 3 の「M がエフェクト変数を含まない」に、型の変数を含まないことを加える（型パラメータのない環境で型が付くので暗黙に成り立つ）。性質 3 の `· ⊢c M` の R は `none` とする |
+| 初回リリース版の拡張: ハンドラ | 段階 B1 | 型の変数を内側から数えた番号（de Bruijn の番号）で表す。節は操作の型パラメータを番号 0 から順に束縛し、節の外側の型（環境の型、`handle` の式の型、R）の番号を、束縛した個数だけずらす（値が節の中へ入っても型を書き換えずに済むため）。実行中の項は型の変数を含まないので、E-Fun と E-Op の置き換えは閉じた型を入れる。V-Lam と `lazy` の検査で環境から継続の型の変数を除くことは、環境の要素を `none` に置き換えて表す（番号をずらさないため）。E-Op は節の本体に操作の型引数の置き換えを施す（[ADR 0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。継続の型の値を `resume` の第一引数に限る規則（[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）は、V-Var の前提と、`resume` の第一引数ごとの規則 C-Resume（節の変数）・C-ResumeL（継続の場所）で表す。組み込みの操作の E-Op は、規則 E-OpPrim として分けて書く。同じ操作の節が二つあるときは、最初の節を選ぶ |
+| 確かめる性質（初回リリース版の読み替え） | 段階 B1 | ストアの型付けの「Ψ と σ の場所が一致する」と K-Drop の `State` の条件（ADR 0300）は、01-12 のとおりに書く。継続の末尾の R を `none` とする状態の型付けの条件（[ADR 0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md)）は、継続の型付けの末尾の R の添字で表す。状態の型付けに、状態の中の項が型の変数を含まないことを加える（01-12 は実行を `main` から始めるので暗黙に成り立つ）。継続の型付けに、継続の末尾での R を添字として加え、ストアの継続の型付けの「末尾の `handle` の枠に K-Handle を R_κ で使う」を表す。性質 3 の「IO の事象を伴う遷移をしない」は、解放の事象を含むすべての事象を伴わないこととして言明する（より強い形）。性質 3 の「M がエフェクト変数を含まない」に、型の変数を含まないことを加える（型パラメータのない環境で型が付くので暗黙に成り立つ）。性質 3 の `· ⊢c M` の R は `none` とする。項に現れない型を型付けが選べる規則（V-List の要素の型、C-Escape の型、分岐のない `match` の型、K-Empty・K-Mark・K-Handle の型）に、その型が束縛された型の変数だけを使う（型が正しい）ことを前提として加える（01-12 は暗黙に前提する。置き換えの補題に要る）。項の型は継続の型を含まない（継続の型は項に書けない） |
 | 初回リリース版の拡張: `Map`・`Set`・`Bytes`、型クラス | 段階 B2 | 段階 B2 で記す |
 | 初回リリース版の拡張: 末尾呼び出しの保証の読み替え | 対象外 | |
 | 確かめる性質 | 性質 2・3 は段階 A・B。性質 1 は対象外 | |
diff --git a/formal/Benitoite/Release/Assumptions.lean b/formal/Benitoite/Release/Assumptions.lean
index 0888baa..929cd7a 100644
--- a/formal/Benitoite/Release/Assumptions.lean
+++ b/formal/Benitoite/Release/Assumptions.lean
@@ -15,9 +15,9 @@ def OutcomeTy (P : Program) (B : Builtins) (Ψ : StoreTy) : Outcome → Ty → P
   | .err _, _ => True
   | .exit _, _ => True
 
-/-- 型パラメータの制約の並び `C0` を、閉じた型 `ts` で置き換えられる。 -/
+/-- 型パラメータの制約の並び `C0`（`C1` の外側）を、閉じた型 `ts` で置き換えられる。 -/
 def ClosedSat (B : Builtins) (C0 C1 : List TParam) (ts : List Ty) : Prop :=
-  (∀ t ∈ ts, Ty.VarsIn 0 (fun _ => True) t) ∧ SatAll B C1 ts C0
+  (∀ t ∈ ts, Ty.WF 0 t) ∧ SatAll B C1 ts C0
 
 /-- 可変のセルと明示遅延の組み込みの関数の型（01-07「可変のセル（初回リリース版）」、01-06「明示遅延の型」）。 -/
 def PrimSig.StoreShape (s : PrimSig) : Prop :=
@@ -40,16 +40,18 @@ def PrimSig.StoreShape (s : PrimSig) : Prop :=
 structure Builtins.Assumptions (P : Program) (B : Builtins) : Prop where
   /-- 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う。 -/
   sig_scoped : ∀ b s, B.sig b = some s → s.Scoped
-  /-- 制約の保存。制約の並びの先頭 `C0` を閉じた型で置き換えても、制約を満たす。 -/
-  admits_subst : ∀ b s C0 C1 ts ts' es', B.sig b = some s → s.admits (C0 ++ C1) ts →
+  /-- 制約の保存。制約の並びの `C1` の外側の `C0` を閉じた型で置き換えても、制約を満たす。 -/
+  admits_subst : ∀ b s C0 C1 ts ts' es', B.sig b = some s → s.admits (C1 ++ C0) ts →
     ClosedSat B C0 C1 ts' → ts'.length = C0.length →
-    s.admits C1 (ts.map (Ty.subst ts' es'))
-  sat_subst : ∀ C0 C1 t p ts' es', B.sat (C0 ++ C1) t p →
-    ClosedSat B C0 C1 ts' → ts'.length = C0.length → B.sat C1 (t.subst ts' es') p
-  /-- 型の変数を含まない型が制約を満たすかは、制約の並びによらない。 -/
-  sat_closed : ∀ C C' t p, Ty.VarsIn 0 (fun _ => True) t → B.sat C t p → B.sat C' t p
-  admits_closed : ∀ b s C C' ts, B.sig b = some s → (∀ t ∈ ts, Ty.VarsIn 0 (fun _ => True) t) →
-    s.admits C ts → s.admits C' ts
+    s.admits C1 (ts.map (Ty.substAt C1.length ts' es'))
+  sat_subst : ∀ C0 C1 t p ts' es', B.sat (C1 ++ C0) t p →
+    ClosedSat B C0 C1 ts' → ts'.length = C0.length → B.sat C1 (t.substAt C1.length ts' es') p
+  /-- 組み込みの関数の制約を満たす型引数は、その型パラメータの組み込みの制約も満たす。 -/
+  admits_sat : ∀ b s C ts, B.sig b = some s → s.admits C ts → SatAll B C ts s.tparams
+  /-- 制約の並び `C1` の型パラメータだけを使う型が制約を満たすかは、`C1` の外側の並びによらない。 -/
+  sat_local : ∀ C1 C0 t p, Ty.WF C1.length t → B.sat C1 t p → B.sat (C1 ++ C0) t p
+  admits_local : ∀ b s C1 C0 ts, B.sig b = some s → (∀ t ∈ ts, Ty.WF C1.length t) →
+    s.admits C1 ts → s.admits (C1 ++ C0) ts
   /-- δ の型の保存（IO を行わない組み込みの関数）。 -/
   delta_typed : ∀ Ψ b s ts es ws, B.sig b = some s → s.kind = .pure →
     ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
diff --git a/formal/Benitoite/Release/Semantics.lean b/formal/Benitoite/Release/Semantics.lean
index e18a8e4..bfa80d1 100644
--- a/formal/Benitoite/Release/Semantics.lean
+++ b/formal/Benitoite/Release/Semantics.lean
@@ -74,6 +74,11 @@ def findClause (h : List Clause) (o : OpRef) : Option Clause :=
 def NoHandler (k : Cont) (o : OpRef) : Prop :=
   ∀ h, Frame.handleF h ∈ k → handles h o = false
 
+/-- 状態が、継続のどの `handle` の枠も処理しない利用者の操作を呼ぶ。 -/
+def UnhandledOp : State → Prop
+  | .run (.app (.op o _) _) k _ => NoHandler k (.user o)
+  | _ => False
+
 /-- 継続を、op を処理する最も内側の `handle` の枠で分ける。`K = K1 ++ (handle □ with H) :: K2` で、
 K1 の中の `handle` の枠はどれも op の節を持たない。 -/
 def SplitAt (o : OpRef) (k k1 : Cont) (h : List Clause) (k2 : Cont) : Prop :=
@@ -419,27 +424,32 @@ def run (P : Program) (B : Builtins) (oracle : Oracle) (rel : Val → Option Err
 R である。ストアの継続の型付けで、末尾の `handle` の枠を κ を作った節の R で型付けすることを表すために使う。 -/
 inductive ContTy (P : Program) (B : Builtins) (Ψ : StoreTy) :
     Option Ty → Eff → Cont → Ty → Ty → Eff → Option Ty → Prop
-  | K_Empty {R ε a ε0} : Eff.Sub ε ε0 → ContTy P B Ψ R ε [] a a ε0 R
+  | K_Empty {R ε a ε0} : Eff.Sub ε ε0 → Ty.WF 0 a → ContTy P B Ψ R ε [] a a ε0 R
   | K_Let {R ε n k a c b ε0 ε1 Re} :
       HasTypeC P B Ψ [] [some a] R n c ε1 → Eff.Sub ε1 ε → ContTy P B Ψ R ε k c b ε0 Re →
       ContTy P B Ψ R ε (.letF n :: k) a b ε0 Re
   | K_Mark {R' ε k a b ε0 Re} :
-      ContTy P B Ψ R' ε k a b ε0 Re → ContTy P B Ψ (some a) ε (.mark :: k) a b ε0 Re
+      ContTy P B Ψ R' ε k a b ε0 Re → Ty.WF 0 a → ContTy P B Ψ (some a) ε (.mark :: k) a b ε0 Re
   | K_Update {R ε l k a b ε0 Re} :
       Ψ l = some (.lazy a) → ContTy P B Ψ R ε k a b ε0 Re →
       ContTy P B Ψ none ε (.update l :: k) a b ε0 Re
   | K_Release {R ε v o k a b ε0 Re} :
       HasTypeV P B Ψ [] [] v (.opaque o) → B.isResource o = true → ε (.name stateEff) = true →
       ContTy P B Ψ R ε k a b ε0 Re → ContTy P B Ψ R ε (.release v :: k) a b ε0 Re
-  | K_Handle {R ε h k t b ε0 Re} :
-      ContTy P B Ψ R ε k t b ε0 Re → HasTypeClauses P B Ψ [] [] R h t ε →
-      ContTy P B Ψ R (Eff.union ε (handled P B h)) (.handleF h :: k) t b ε0 Re
+  /-- K-Handle。節は、枠の下の継続が許すエフェクトに含まれるエフェクト εc で検査する（ADR 0302）。 -/
+  | K_Handle {R ε εc h k t b ε0 Re} :
+      ContTy P B Ψ R ε k t b ε0 Re → Eff.Sub εc ε → HasTypeClauses P B Ψ [] [] R h t εc →
+      Ty.WF 0 t →
+      ContTy P B Ψ R (Eff.union εc (handled P B h)) (.handleF h :: k) t b ε0 Re
   /-- K-Drop。捨てる継続の解放の枠を、この位置で実行できるように、κ の継続の型のエフェクトが `State` を
   含むなら、ε も `State` を含む（ADR 0300）。 -/
   | K_Drop {R ε κ k a b ε0 Re b' t' ε' R'} :
       Ψ κ = some (.cont b' t' ε' R') → (ε' (.name stateEff) = true → ε (.name stateEff) = true) →
       ContTy P B Ψ R ε k a b ε0 Re →
       ContTy P B Ψ R ε (.drop κ :: k) a b ε0 Re
+  /-- K-Sub。継続が受け取る型を広げる（ADR 0301）。 -/
+  | K_Sub {R ε k a a' b ε0 Re} :
+      ContTy P B Ψ R ε k a' b ε0 Re → Ty.Le a a' → ContTy P B Ψ R ε k a b ε0 Re
 
 /-- 継続が `handle` の枠で終わる。 -/
 def EndsWithHandle (k : Cont) : Prop := ∃ k1 h, k = k1 ++ [.handleF h]
@@ -453,10 +463,16 @@ def CellOk (P : Program) (B : Builtins) (Ψ : StoreTy) (l : Nat) : Cell → Prop
       ∃ R' ε', ContTy P B Ψ R' ε' k b t ε r
   | .used => ∃ b t ε r, Ψ l = some (.cont b t ε r)
 
+/-- ストアの場所の型は、型の変数を含まない。 -/
+def LocTy.WF : LocTy → Prop
+  | .ref a => Ty.WF 0 a
+  | .lazy a => Ty.WF 0 a
+  | .cont b t _ r => Ty.WF 0 b ∧ Ty.WF 0 t ∧ ∀ x, r = some x → Ty.WF 0 x
+
 /-- ストアがストアの型付けに合う。ストアは有限であり、Ψ が型を与える場所には中身がある（`dom Ψ = dom σ`。
 ADR 0300）。 -/
 def StoreOk (P : Program) (B : Builtins) (Ψ : StoreTy) (σ : Store) : Prop :=
-  (∃ n, ∀ l, n ≤ l → σ l = none) ∧
+  (∃ n, ∀ l, n ≤ l → σ l = none) ∧ (∀ l x, Ψ l = some x → x.WF) ∧
     (∀ l x, Ψ l = some x → σ l ≠ none) ∧
     (∀ l c, σ l = some c → CellOk P B Ψ l c)
 
diff --git a/formal/Benitoite/Release/Subst.lean b/formal/Benitoite/Release/Subst.lean
index 817511e..70b06a1 100644
--- a/formal/Benitoite/Release/Subst.lean
+++ b/formal/Benitoite/Release/Subst.lean
@@ -3,63 +3,90 @@ import Benitoite.Release.Syntax
 /-!
 # 置き換えとパターンの照合（段階 B1）
 
-段階 A（`Benitoite.Core`）の置き換えを、段階 B1 の構成に広げる。型の変数はレベルで表す
-（`Syntax.lean` の冒頭）ので、型の置き換え `Ty.subst ts es` は、レベルが `ts` の長さより小さい
-型の変数を `ts` の型に置き換え、それ以上のレベルの型の変数を `ts` の長さだけ詰める。
+段階 A（`Benitoite.Core`）の置き換えを、段階 B1 の構成に広げる。型の変数は de Bruijn の番号で表す
+（`Syntax.lean` の冒頭）。型の置き換え `Ty.substAt c ts es` は、`c` 個の型の変数を束縛した内側で、
+番号 `c` から `c + ts.length - 1` の型の変数を `ts` の型（`c` だけずらしたもの）に置き換え、
+それより大きい番号を `ts` の長さだけ詰める。
 -/
 
 namespace Benitoite.Release
 
 /-! ## 型とエフェクトの置き換え -/
 
-def Ty.subst (ts : List Ty) (es : List Eff) : Ty → Ty
+/-- 型の変数の番号を、`c` 以上のものだけ `k` ずらす。 -/
+def Ty.shift (k c : Nat) : Ty → Ty
   | .base ι => .base ι
   | .opaque o => .opaque o
-  | .data d args => .data d (args.map (Ty.subst ts es))
-  | .list a => .list (Ty.subst ts es a)
-  | .fn params ret eff => .fn (params.map (Ty.subst ts es)) (Ty.subst ts es ret) (Eff.substRho es eff)
-  | .tvar i => if i < ts.length then (ts[i]?).getD (.tvar i) else .tvar (i - ts.length)
-  | .reference a => .reference (Ty.subst ts es a)
-  | .lazy a => .lazy (Ty.subst ts es a)
-  | .cont b t eff => .cont (Ty.subst ts es b) (Ty.subst ts es t) (Eff.substRho es eff)
+  | .data d args => .data d (args.map (Ty.shift k c))
+  | .list a => .list (Ty.shift k c a)
+  | .fn params ret eff => .fn (params.map (Ty.shift k c)) (Ty.shift k c ret) eff
+  | .tvar i => if i < c then .tvar i else .tvar (i + k)
+  | .reference a => .reference (Ty.shift k c a)
+  | .lazy a => .lazy (Ty.shift k c a)
+  | .cont b t eff => .cont (Ty.shift k c b) (Ty.shift k c t) eff
+
+def Ty.substAt (c : Nat) (ts : List Ty) (es : List Eff) : Ty → Ty
+  | .base ι => .base ι
+  | .opaque o => .opaque o
+  | .data d args => .data d (args.map (Ty.substAt c ts es))
+  | .list a => .list (Ty.substAt c ts es a)
+  | .fn params ret eff =>
+      .fn (params.map (Ty.substAt c ts es)) (Ty.substAt c ts es ret) (Eff.substRho es eff)
+  | .tvar i =>
+      if i < c then .tvar i
+      else if i - c < ts.length then ((ts[i - c]?).getD (.tvar i)).shift c 0
+      else .tvar (i - ts.length)
+  | .reference a => .reference (Ty.substAt c ts es a)
+  | .lazy a => .lazy (Ty.substAt c ts es a)
+  | .cont b t eff => .cont (Ty.substAt c ts es b) (Ty.substAt c ts es t) (Eff.substRho es eff)
+
+/-- 型の置き換え θ = [T̄/ᾱ, Ē/ρ̄]（束縛の外側での置き換え）。 -/
+def Ty.subst (ts : List Ty) (es : List Eff) : Ty → Ty := Ty.substAt 0 ts es
 
 mutual
-  def Val.substTy (ts : List Ty) (es : List Eff) : Val → Val
+  def Val.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Val → Val
     | .var i => .var i
-    | .const c => .const c
-    | .fnRef f tys effs => .fnRef f (tys.map (Ty.subst ts es)) (effs.map (Eff.substRho es))
-    | .prim b tys effs => .prim b (tys.map (Ty.subst ts es)) (effs.map (Eff.substRho es))
-    | .lam params body => .lam (params.map (Ty.subst ts es)) (Comp.substTy ts es body)
-    | .con c tys args => .con c (tys.map (Ty.subst ts es)) (Val.substTyList ts es args)
-    | .list elems => .list (Val.substTyList ts es elems)
-    | .op o tys => .op o (tys.map (Ty.subst ts es))
+    | .const k => .const k
+    | .fnRef f tys effs => .fnRef f (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substRho es))
+    | .prim b tys effs => .prim b (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substRho es))
+    | .lam params body => .lam (params.map (Ty.substAt c ts es)) (Comp.substTyAt c ts es body)
+    | .con k tys args => .con k (tys.map (Ty.substAt c ts es)) (Val.substTyAtList c ts es args)
+    | .list elems => .list (Val.substTyAtList c ts es elems)
+    | .op o tys => .op o (tys.map (Ty.substAt c ts es))
     | .loc l => .loc l
 
-  def Val.substTyList (ts : List Ty) (es : List Eff) : List Val → List Val
+  def Val.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Val → List Val
     | [] => []
-    | v :: vs => Val.substTy ts es v :: Val.substTyList ts es vs
-
-  def Comp.substTy (ts : List Ty) (es : List Eff) : Comp → Comp
-    | .ret v => .ret (Val.substTy ts es v)
-    | .letIn m n => .letIn (Comp.substTy ts es m) (Comp.substTy ts es n)
-    | .app f args => .app (Val.substTy ts es f) (Val.substTyList ts es args)
-    | .ite v m n => .ite (Val.substTy ts es v) (Comp.substTy ts es m) (Comp.substTy ts es n)
-    | .match v arms => .match (Val.substTy ts es v) (Comp.substTyArms ts es arms)
-    | .lazyC m => .lazyC (Comp.substTy ts es m)
-    | .escape v => .escape (Val.substTy ts es v)
-    | .use v m => .use (Val.substTy ts es v) (Comp.substTy ts es m)
-    | .handle m h => .handle (Comp.substTy ts es m) (Clause.substTyList ts es h)
-    | .resume k v => .resume (Val.substTy ts es k) (Val.substTy ts es v)
-
-  def Comp.substTyArms (ts : List Ty) (es : List Eff) : List (Pat × Comp) → List (Pat × Comp)
+    | v :: vs => Val.substTyAt c ts es v :: Val.substTyAtList c ts es vs
+
+  def Comp.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Comp → Comp
+    | .ret v => .ret (Val.substTyAt c ts es v)
+    | .letIn m n => .letIn (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n)
+    | .app f args => .app (Val.substTyAt c ts es f) (Val.substTyAtList c ts es args)
+    | .ite v m n => .ite (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n)
+    | .match v arms => .match (Val.substTyAt c ts es v) (Comp.substTyAtArms c ts es arms)
+    | .lazyC m => .lazyC (Comp.substTyAt c ts es m)
+    | .escape v => .escape (Val.substTyAt c ts es v)
+    | .use v m => .use (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m)
+    | .handle m h => .handle (Comp.substTyAt c ts es m) (Clause.substTyAtList c ts es h)
+    | .resume k v => .resume (Val.substTyAt c ts es k) (Val.substTyAt c ts es v)
+
+  def Comp.substTyAtArms (c : Nat) (ts : List Ty) (es : List Eff) :
+      List (Pat × Comp) → List (Pat × Comp)
     | [] => []
-    | (p, m) :: arms => (p, Comp.substTy ts es m) :: Comp.substTyArms ts es arms
+    | (p, m) :: arms => (p, Comp.substTyAt c ts es m) :: Comp.substTyAtArms c ts es arms
 
-  def Clause.substTyList (ts : List Ty) (es : List Eff) : List Clause → List Clause
+  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
+  def Clause.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Clause → List Clause
     | [] => []
-    | .mk o n k m :: cs => .mk o n k (Comp.substTy ts es m) :: Clause.substTyList ts es cs
+    | .mk o n k m :: cs => .mk o n k (Comp.substTyAt (c + k) ts es m) :: Clause.substTyAtList c ts es cs
 end
 
+/-- 01-12 の `Mθ`。 -/
+def Comp.substTy (ts : List Ty) (es : List Eff) (m : Comp) : Comp := Comp.substTyAt 0 ts es m
+
+def Val.substTy (ts : List Ty) (es : List Eff) (v : Val) : Val := Val.substTyAt 0 ts es v
+
 /-! ## 値の置き換え -/
 
 mutual
diff --git a/formal/Benitoite/Release/Syntax.lean b/formal/Benitoite/Release/Syntax.lean
index f96597c..2044015 100644
--- a/formal/Benitoite/Release/Syntax.lean
+++ b/formal/Benitoite/Release/Syntax.lean
@@ -8,10 +8,10 @@
 
 段階 A からの表現の違い（設計書 07-04「01-12 との対応」の表に記す）:
 
-- 型の変数は、外側から数えた番号（レベル）で表す。関数の定義の型パラメータが `0..n-1`、その本体の中の
-  `handle` の節が束縛する操作の型パラメータが `n..` である（01-06「エフェクトの宣言とハンドラの型付け」の
-  「その型パラメータをほかの何とも等しくない型として扱う」）。実行中の項は型の変数を含まないので、
-  E-Fun と E-Op の置き換えは、閉じた型を先頭の番号に入れ、残りの番号を詰めるだけで済む。
+- 型の変数は、内側から数えた de Bruijn の番号で表す。関数の定義の本体では、定義の型パラメータが
+  `0..n-1` である。`handle` の節は、操作の型パラメータを番号 `0..k-1` に束縛し、節の外側の型の変数の番号を
+  k だけずらす（01-06「エフェクトの宣言とハンドラの型付け」の「その型パラメータをほかの何とも等しくない型として
+  扱う」）。閉じた値は、節の内側へ運んでも変わらない。
 - エフェクトの原子は、エフェクトの名前（モジュールと名前の組を一つの文字列で表す）とエフェクト変数である。
 - 組み込みの関数のうち、ストアの操作（`Reference.new` など）とプロセスの終了は、組み込みの関数の種類
   （`PrimKind`）で区別する。
@@ -167,9 +167,8 @@ mutual
     /-- `resume κ V`。κ は節の変数か、継続の場所。 -/
     | resume (k : Val) (v : Val)
 
-  /-- 節 `op(x̄) k ⇒ N`。`arity` は x̄ の個数、`ntys` は操作の型パラメータの個数である。N の中で、番号 0 が k、番号 1 から n が x̄ を
-  最後の引数から順に指す。操作が型パラメータを持つとき、N の中では、その型パラメータを、
-  節を囲む型パラメータの後に続くレベルの型の変数として表す。 -/
+  /-- 節 `op(x̄) k ⇒ N`。`arity` は x̄ の個数、`ntys` は操作の型パラメータの個数である。N の中で、番号 0 が k、
+  番号 1 から n が x̄ を最後の引数から順に指す。操作の型パラメータは、N の中の型の変数の番号 `0..ntys-1` である。 -/
   inductive Clause where
     | mk (op : OpRef) (arity : Nat) (ntys : Nat) (body : Comp)
 end
diff --git a/formal/Benitoite/Release/Theorems.lean b/formal/Benitoite/Release/Theorems.lean
index 4bb2415..8a51202 100644
--- a/formal/Benitoite/Release/Theorems.lean
+++ b/formal/Benitoite/Release/Theorems.lean
@@ -1,10 +1,10 @@
-import Benitoite.Release.Assumptions
+import Benitoite.Release.Lemmas.StepSound
 
 /-!
 # 段階 B1 の定理
 
 設計書 01-12「確かめる性質」の性質 2（進行と保存）と性質 3（エフェクトの健全性）の、初回リリース版の
-読み替えの形を、段階 B1 の範囲で言明する。証明はまだ書いていない（`sorry`）。
+読み替えの形を、段階 B1 の範囲で言明し、証明する。証明の補題は `Lemmas/` に置く。
 
 段階 A と違い、遷移を計算する関数 `step` と遷移の関係の一致は、`step` が返す遷移が関係の遷移であること
 （`step_sound`）だけを言明する。`step` は例の実行を調べる道具であり、新しい場所と応答の選び方を固定するので、
@@ -17,32 +17,31 @@ variable {P : Program} {B : Builtins}
 
 /-- 型が付いた状態について、`step` が返す遷移は `Step` の遷移である。`oracle` と `rel` は、起こりうる応答が
 あるときは、その一つを選ぶ。`fresh` は、有限なストアに中身のない場所を選ぶ。 -/
-theorem step_sound (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
-    (hb : B.Assumptions P) (oracle : Oracle) (rel : Val → Option ErrKind) (fresh : Store → Nat)
+theorem step_sound (hb : B.Assumptions P) (oracle : Oracle) (rel : Val → Option ErrKind) (fresh : Store → Nat)
     (horacle : ∀ b ts es ws o, B.ioResponse b ts es ws o → B.ioResponse b ts es ws (oracle b ts es ws))
     (hrel : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v))
     (hfresh : ∀ σ : Store, (∃ n, ∀ l, n ≤ l → σ l = none) → σ (fresh σ) = none)
     {s : State} {l : Option Event} {s' : State} :
     StateTy P B s → step P B oracle rel fresh s = some (l, s') → Step P B s l s' := by
-  sorry
+  intro hs h
+  obtain ⟨Eb, _, hs⟩ := stateTy_iff.mp hs
+  exact step_soundE hb oracle rel fresh horacle hrel hfresh hs h
 
 /-- 進行。型が付いた状態は、`⟨return V, [], σ⟩`、`error(r̄, [], σ)`、`exit(n, r̄, [], σ)` のいずれかであるか、
 遷移できる。 -/
-theorem progress (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
-    (hb : B.Assumptions P) {s : State} :
+theorem progress (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {s : State} :
     StateTy P B s → s.Final ∨ ∃ l s', Step P B s l s' := by
-  sorry
+  intro hs
+  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
+  exact progressE hdecl hb hs hEb
 
 /-- 保存。型が付いた状態から遷移した先の状態も型が付く。 -/
 theorem preservation (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
     (hb : B.Assumptions P) {s : State} {l : Option Event} {s' : State} :
     StateTy P B s → Step P B s l s' → StateTy P B s' := by
-  sorry
-
-/-- 状態が、継続のどの `handle` の枠も処理しない利用者の操作を呼ぶ。 -/
-def UnhandledOp : State → Prop
-  | .run (.app (.op o _) _) k _ => NoHandler k (.user o)
-  | _ => False
+  intro hs hst
+  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
+  exact stateTy_iff.mpr ⟨Eb, hEb, preservationE hwf hwt hdecl hb hs hst⟩
 
 /-- エフェクトの健全性。`· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, [], ∅⟩` からの
 実行は、事象を伴う遷移（IO の事象と解放の事象）をせず、どの `handle` の枠も処理しない操作を呼ばない。
@@ -52,6 +51,8 @@ theorem effect_soundness (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.E
     HasTypeC P B StoreTy.empty [] [] none m a Eff.empty → m.ClosedNoEffVars →
     ∀ s, Steps P B (.run m [] Store.empty) s →
       (∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s := by
-  sorry
+  intro hm hc s hsteps
+  have hs := steps_preserve hwf hwt hdecl hb hsteps (stateTyE_init hwf hb hm hc)
+  exact ⟨no_event hdecl hb hs, no_unhandledOp hdecl hs builtinOnly_empty⟩
 
 end Benitoite.Release
diff --git a/formal/Benitoite/Release/Typing.lean b/formal/Benitoite/Release/Typing.lean
index 4ec93b9..e263d99 100644
--- a/formal/Benitoite/Release/Typing.lean
+++ b/formal/Benitoite/Release/Typing.lean
@@ -8,13 +8,14 @@ import Benitoite.Release.Subst
 
 段階 A からの表現の違い:
 
-- 型付けの判断は、型パラメータの組み込みの制約の並び `C`（レベルの順）を持つ（ADR 0297）。V-Prim は
+- 型付けの判断は、型パラメータの組み込みの制約の並び `C`（型の変数の番号の順）を持つ（ADR 0297）。V-Prim は
   組み込みの関数の型パラメータの制約を `C` のもとで確かめ、V-Fun は型引数が関数の型パラメータの制約を
   満たすことを確かめる。型が制約を満たすか（等値の型・鍵の型）は 01-06 に委ね、`Builtins.sat` で与える。
 - 環境 Γ の要素は `Option Ty` である。V-Lam の前提と `lazy M` の M の検査では、Γ から継続の型を持つ変数を
   除く（01-12「ハンドラ」）。番号で表した変数を除くと番号がずれるので、要素を `none` に置き換えて表す。
-- `handle` の節が処理する操作の型パラメータは、節を囲む型パラメータの後に続くレベルの型の変数として、
-  制約の並びに加える（01-06「その型パラメータをほかの何とも等しくない型として扱う」）。
+- `handle` の節が処理する操作の型パラメータは、節の中で型の変数の番号 `0..k-1` に束縛し、制約の並びの
+  先頭に加える（01-06「その型パラメータをほかの何とも等しくない型として扱う」）。節の外側の型（環境の型、
+  `handle` の式の型、R）は、節の中では番号を k だけずらす。
 -/
 
 namespace Benitoite.Release
@@ -72,13 +73,11 @@ structure Builtins where
 def fnTy (params : List Ty) (ret : Ty) (eff : Eff) (ts : List Ty) (es : List Eff) : Ty :=
   Ty.subst ts es (.fn params ret eff)
 
-/-- 型引数 `ts` が、型パラメータの制約 `tps` を、制約の並び `C` のもとで満たす。 -/
+/-- 型引数 `ts` が、型パラメータの制約 `tps` を、制約の並び `C` のもとで満たす。制約の並びは、型の変数の番号の
+順（内側から）に並べる。 -/
 def SatAll (B : Builtins) (C : List TParam) (ts : List Ty) (tps : List TParam) : Prop :=
   ts.length = tps.length ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → tps[i]? = some p → B.sat C t p
 
-/-- レベル `n` から始まる `k` 個の型の変数。操作の宣言の型パラメータを、節の中のレベルに移す。 -/
-def rigid (n k : Nat) : List Ty := (List.range k).map (fun i => .tvar (n + i))
-
 /-! ## 操作 -/
 
 /-- 操作の型 `∀ᾱ. (Ā) → B ! {L}`。 -/
@@ -116,6 +115,26 @@ def handled (P : Program) (B : Builtins) (h : List Clause) : Eff := fun a =>
       | _ => false
   | .rho _ => false
 
+/-! ## 型の正しさ -/
+
+mutual
+  /-- 型の中の型の変数の番号が `n` より小さい（その位置で束縛された型の変数だけを使う）。 -/
+  def Ty.WF (n : Nat) : Ty → Prop
+    | .base _ => True
+    | .opaque _ => True
+    | .data _ args => Ty.WFList n args
+    | .list a => Ty.WF n a
+    | .fn params ret _ => Ty.WFList n params ∧ Ty.WF n ret
+    | .tvar i => i < n
+    | .reference a => Ty.WF n a
+    | .lazy a => Ty.WF n a
+    | .cont b t _ => Ty.WF n b ∧ Ty.WF n t
+
+  def Ty.WFList (n : Nat) : List Ty → Prop
+    | [] => True
+    | a :: as => Ty.WF n a ∧ Ty.WFList n as
+end
+
 /-! ## 型の包含 -/
 
 def Ty.Le (a a' : Ty) : Prop :=
@@ -141,6 +160,9 @@ def hideConts (Γ : List (Option Ty)) : List (Option Ty) :=
 /-- 型の並びを、環境に加える形にする。 -/
 def binds (as : List Ty) : List (Option Ty) := as.reverse.map some
 
+/-- 環境の型の番号をずらす（節の内側に入るとき）。 -/
+def shiftEnv (k : Nat) (Γ : List (Option Ty)) : List (Option Ty) := Γ.map (Option.map (Ty.shift k 0))
+
 /-! ## パターンと網羅性 -/
 
 mutual
@@ -216,8 +238,10 @@ mutual
         P.cons c = some cd → ts.length = cd.ntys →
         HasTypeVs P B Ψ C Γ args (cd.args.map (Ty.subst ts [])) →
         HasTypeV P B Ψ C Γ (.con c ts args) (.data cd.data ts)
+    /-- V-List。要素の型は、その位置で束縛された型の変数だけを使う（空のリストの要素の型は項に現れないので、
+    型の正しさを前提に置く）。 -/
     | V_List {Γ elems a} :
-        HasTypeEach P B Ψ C Γ elems a → HasTypeV P B Ψ C Γ (.list elems) (.list a)
+        HasTypeEach P B Ψ C Γ elems a → Ty.WF C.length a → HasTypeV P B Ψ C Γ (.list elems) (.list a)
     /-- `Ψ(ℓ) = A` のとき `ℓ : A`（01-12「確かめる性質」）。 -/
     | V_LocRef {Γ l a} : Ψ l = some (.ref a) → HasTypeV P B Ψ C Γ (.loc l) (.reference a)
     | V_LocLazy {Γ l a} : Ψ l = some (.lazy a) → HasTypeV P B Ψ C Γ (.loc l) (.lazy a)
@@ -261,7 +285,7 @@ mutual
         HasTypeC P B Ψ C Γ R (.lazyC m) (.lazy a) Eff.empty
     /-- `Γ; R ⊢v V : R` のとき、`Γ; R ⊢c escape V : A ! ε`（任意の A と ε）。 -/
     | C_Escape {Γ r v a ε} :
-        HasTypeV P B Ψ C Γ v r → HasTypeC P B Ψ C Γ (some r) (.escape v) a ε
+        HasTypeV P B Ψ C Γ v r → Ty.WF C.length a → HasTypeC P B Ψ C Γ (some r) (.escape v) a ε
     /-- C-Use。解放のエフェクト `rel(O_r) = {State}` を ε が含む。 -/
     | C_Use {Γ R v o m b ε} :
         HasTypeV P B Ψ C Γ v (.opaque o) → B.isResource o = true →
@@ -283,23 +307,23 @@ mutual
 
   inductive HasTypeArms (P : Program) (B : Builtins) (Ψ : StoreTy) :
       List TParam → List (Option Ty) → Option Ty → List (Pat × Comp) → Ty → Ty → Eff → Prop
-    | nil {Γ R a b ε} : HasTypeArms P B Ψ C Γ R [] a b ε
+    | nil {Γ R a b ε} : Ty.WF C.length b → HasTypeArms P B Ψ C Γ R [] a b ε
     | cons {Γ R p m arms a b ε δ} :
         PatTy P p a δ → HasTypeC P B Ψ C (binds δ ++ Γ) R m b ε →
         HasTypeArms P B Ψ C Γ R arms a b ε →
         HasTypeArms P B Ψ C Γ R ((p, m) :: arms) a b ε
 
   /-- C-Handle の各節 `op(x̄) k ⇒ N`：`Γ, x̄:Ā, k:Cont(B → T ! ε); R ⊢c N : T ! ε`。操作の型パラメータは、
-  節を囲む型パラメータの後に続くレベルの、宣言の制約を持つ、ほかの型とは等しくない型の変数である。 -/
+  節の中の型の変数の番号 `0..k-1` に束縛した、宣言の制約を持つ、ほかの型とは等しくない型の変数である。
+  節の外側の Γ・T・R の型は、番号を k だけずらす。 -/
   inductive HasTypeClauses (P : Program) (B : Builtins) (Ψ : StoreTy) :
       List TParam → List (Option Ty) → Option Ty → List Clause → Ty → Eff → Prop
     | nil {Γ R t ε} : HasTypeClauses P B Ψ C Γ R [] t ε
     | cons {Γ R o n k body cs t ε sg} :
         opSig P B o = some sg → n = sg.params.length → k = sg.tparams.length →
-        HasTypeC P B Ψ (C ++ sg.tparams)
-          (some (.cont (sg.ret.subst (rigid C.length k) []) t ε) ::
-            (binds (sg.params.map (Ty.subst (rigid C.length k) [])) ++ Γ))
-          R body t ε →
+        HasTypeC P B Ψ (sg.tparams ++ C)
+          (some (.cont sg.ret (t.shift k 0) ε) :: (binds sg.params ++ shiftEnv k Γ))
+          (R.map (Ty.shift k 0)) body (t.shift k 0) ε →
         HasTypeClauses P B Ψ C Γ R cs t ε →
         HasTypeClauses P B Ψ C Γ R (.mk o n k body :: cs) t ε
 end
diff --git a/formal/Benitoite/Release/WellFormed.lean b/formal/Benitoite/Release/WellFormed.lean
index 2db970b..52f5b24 100644
--- a/formal/Benitoite/Release/WellFormed.lean
+++ b/formal/Benitoite/Release/WellFormed.lean
@@ -3,7 +3,7 @@ import Benitoite.Release.Typing
 /-!
 # 型とエフェクトの変数の範囲（段階 B1）
 
-型の変数はレベルで表す（`Syntax.lean`）。`VarsIn n pe` は、項の中の型の変数のレベルが、その位置で
+型の変数は de Bruijn の番号で表す（`Syntax.lean`）。`VarsIn n pe` は、項の中の型の変数の番号が、その位置で
 束縛されている個数（外側の `n` に、囲む節が束縛する個数を足したもの）より小さく、エフェクト変数の番号が
 `pe` を満たすことを表す。
 
@@ -18,7 +18,8 @@ def Eff.RhosIn (pe : Nat → Prop) (ε : Eff) : Prop :=
   ∀ i, ε (.rho i) = true → pe i
 
 mutual
-  /-- 型の中の型の変数のレベルが `n` より小さく、エフェクト変数の番号が `pe` を満たす。 -/
+  /-- 型の中の型の変数の番号が `n` より小さく、エフェクト変数の番号が `pe` を満たし、継続の型を含まない
+  （項の中に書ける型である）。 -/
   def Ty.VarsIn (n : Nat) (pe : Nat → Prop) : Ty → Prop
     | .base _ => True
     | .opaque _ => True
@@ -28,7 +29,8 @@ mutual
     | .tvar i => i < n
     | .reference a => Ty.VarsIn n pe a
     | .lazy a => Ty.VarsIn n pe a
-    | .cont b t eff => Ty.VarsIn n pe b ∧ Ty.VarsIn n pe t ∧ Eff.RhosIn pe eff
+    -- 継続の型は、項の中に書けない（01-12「ハンドラ」の「値として書けるのは節の中だけ」）。
+    | .cont _ _ _ => False
 
   def Ty.VarsInList (n : Nat) (pe : Nat → Prop) : List Ty → Prop
     | [] => True
@@ -71,7 +73,7 @@ mutual
     | [] => True
     | (_, m) :: arms => Comp.VarsIn n pe m ∧ Comp.VarsInArms n pe arms
 
-  /-- 節の本体では、操作の型パラメータの個数だけ、束縛されたレベルが増える。 -/
+  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
   def Clause.VarsInList (n : Nat) (pe : Nat → Prop) : List Clause → Prop
     | [] => True
     | .mk _ _ k m :: cs => Comp.VarsIn (n + k) pe m ∧ Clause.VarsInList n pe cs
```

## 資料 3: 変更後の定義と定理（全文）

### formal/Benitoite/Release/Subst.lean

```lean
import Benitoite.Release.Syntax

/-!
# 置き換えとパターンの照合（段階 B1）

段階 A（`Benitoite.Core`）の置き換えを、段階 B1 の構成に広げる。型の変数は de Bruijn の番号で表す
（`Syntax.lean` の冒頭）。型の置き換え `Ty.substAt c ts es` は、`c` 個の型の変数を束縛した内側で、
番号 `c` から `c + ts.length - 1` の型の変数を `ts` の型（`c` だけずらしたもの）に置き換え、
それより大きい番号を `ts` の長さだけ詰める。
-/

namespace Benitoite.Release

/-! ## 型とエフェクトの置き換え -/

/-- 型の変数の番号を、`c` 以上のものだけ `k` ずらす。 -/
def Ty.shift (k c : Nat) : Ty → Ty
  | .base ι => .base ι
  | .opaque o => .opaque o
  | .data d args => .data d (args.map (Ty.shift k c))
  | .list a => .list (Ty.shift k c a)
  | .fn params ret eff => .fn (params.map (Ty.shift k c)) (Ty.shift k c ret) eff
  | .tvar i => if i < c then .tvar i else .tvar (i + k)
  | .reference a => .reference (Ty.shift k c a)
  | .lazy a => .lazy (Ty.shift k c a)
  | .cont b t eff => .cont (Ty.shift k c b) (Ty.shift k c t) eff

def Ty.substAt (c : Nat) (ts : List Ty) (es : List Eff) : Ty → Ty
  | .base ι => .base ι
  | .opaque o => .opaque o
  | .data d args => .data d (args.map (Ty.substAt c ts es))
  | .list a => .list (Ty.substAt c ts es a)
  | .fn params ret eff =>
      .fn (params.map (Ty.substAt c ts es)) (Ty.substAt c ts es ret) (Eff.substRho es eff)
  | .tvar i =>
      if i < c then .tvar i
      else if i - c < ts.length then ((ts[i - c]?).getD (.tvar i)).shift c 0
      else .tvar (i - ts.length)
  | .reference a => .reference (Ty.substAt c ts es a)
  | .lazy a => .lazy (Ty.substAt c ts es a)
  | .cont b t eff => .cont (Ty.substAt c ts es b) (Ty.substAt c ts es t) (Eff.substRho es eff)

/-- 型の置き換え θ = [T̄/ᾱ, Ē/ρ̄]（束縛の外側での置き換え）。 -/
def Ty.subst (ts : List Ty) (es : List Eff) : Ty → Ty := Ty.substAt 0 ts es

mutual
  def Val.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Val → Val
    | .var i => .var i
    | .const k => .const k
    | .fnRef f tys effs => .fnRef f (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substRho es))
    | .prim b tys effs => .prim b (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substRho es))
    | .lam params body => .lam (params.map (Ty.substAt c ts es)) (Comp.substTyAt c ts es body)
    | .con k tys args => .con k (tys.map (Ty.substAt c ts es)) (Val.substTyAtList c ts es args)
    | .list elems => .list (Val.substTyAtList c ts es elems)
    | .op o tys => .op o (tys.map (Ty.substAt c ts es))
    | .loc l => .loc l

  def Val.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Val → List Val
    | [] => []
    | v :: vs => Val.substTyAt c ts es v :: Val.substTyAtList c ts es vs

  def Comp.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Comp → Comp
    | .ret v => .ret (Val.substTyAt c ts es v)
    | .letIn m n => .letIn (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n)
    | .app f args => .app (Val.substTyAt c ts es f) (Val.substTyAtList c ts es args)
    | .ite v m n => .ite (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n)
    | .match v arms => .match (Val.substTyAt c ts es v) (Comp.substTyAtArms c ts es arms)
    | .lazyC m => .lazyC (Comp.substTyAt c ts es m)
    | .escape v => .escape (Val.substTyAt c ts es v)
    | .use v m => .use (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m)
    | .handle m h => .handle (Comp.substTyAt c ts es m) (Clause.substTyAtList c ts es h)
    | .resume k v => .resume (Val.substTyAt c ts es k) (Val.substTyAt c ts es v)

  def Comp.substTyAtArms (c : Nat) (ts : List Ty) (es : List Eff) :
      List (Pat × Comp) → List (Pat × Comp)
    | [] => []
    | (p, m) :: arms => (p, Comp.substTyAt c ts es m) :: Comp.substTyAtArms c ts es arms

  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
  def Clause.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.substTyAt (c + k) ts es m) :: Clause.substTyAtList c ts es cs
end

/-- 01-12 の `Mθ`。 -/
def Comp.substTy (ts : List Ty) (es : List Eff) (m : Comp) : Comp := Comp.substTyAt 0 ts es m

def Val.substTy (ts : List Ty) (es : List Eff) (v : Val) : Val := Val.substTyAt 0 ts es v

/-! ## 値の置き換え -/

mutual
  def Pat.binders : Pat → Nat
    | .wild => 0
    | .var => 1
    | .const _ => 0
    | .con _ args => Pat.bindersList args

  def Pat.bindersList : List Pat → Nat
    | [] => 0
    | p :: ps => Pat.binders p + Pat.bindersList ps
end

def upRen (k : Nat) (ξ : Nat → Nat) (i : Nat) : Nat :=
  if i < k then i else ξ (i - k) + k

mutual
  def Val.rename (ξ : Nat → Nat) : Val → Val
    | .var i => .var (ξ i)
    | .const c => .const c
    | .fnRef f tys effs => .fnRef f tys effs
    | .prim b tys effs => .prim b tys effs
    | .lam params body => .lam params (Comp.rename (upRen params.length ξ) body)
    | .con c tys args => .con c tys (Val.renameList ξ args)
    | .list elems => .list (Val.renameList ξ elems)
    | .op o tys => .op o tys
    | .loc l => .loc l

  def Val.renameList (ξ : Nat → Nat) : List Val → List Val
    | [] => []
    | v :: vs => Val.rename ξ v :: Val.renameList ξ vs

  def Comp.rename (ξ : Nat → Nat) : Comp → Comp
    | .ret v => .ret (Val.rename ξ v)
    | .letIn m n => .letIn (Comp.rename ξ m) (Comp.rename (upRen 1 ξ) n)
    | .app f args => .app (Val.rename ξ f) (Val.renameList ξ args)
    | .ite v m n => .ite (Val.rename ξ v) (Comp.rename ξ m) (Comp.rename ξ n)
    | .match v arms => .match (Val.rename ξ v) (Comp.renameArms ξ arms)
    | .lazyC m => .lazyC (Comp.rename ξ m)
    | .escape v => .escape (Val.rename ξ v)
    | .use v m => .use (Val.rename ξ v) (Comp.rename ξ m)
    | .handle m h => .handle (Comp.rename ξ m) (Clause.renameList ξ h)
    | .resume k v => .resume (Val.rename ξ k) (Val.rename ξ v)

  def Comp.renameArms (ξ : Nat → Nat) : List (Pat × Comp) → List (Pat × Comp)
    | [] => []
    | (p, m) :: arms => (p, Comp.rename (upRen p.binders ξ) m) :: Comp.renameArms ξ arms

  def Clause.renameList (ξ : Nat → Nat) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.rename (upRen (n + 1) ξ) m) :: Clause.renameList ξ cs
end

def upSubst (k : Nat) (σ : Nat → Val) (i : Nat) : Val :=
  if i < k then .var i else (σ (i - k)).rename (· + k)

mutual
  def Val.subst (σ : Nat → Val) : Val → Val
    | .var i => σ i
    | .const c => .const c
    | .fnRef f tys effs => .fnRef f tys effs
    | .prim b tys effs => .prim b tys effs
    | .lam params body => .lam params (Comp.subst (upSubst params.length σ) body)
    | .con c tys args => .con c tys (Val.substList σ args)
    | .list elems => .list (Val.substList σ elems)
    | .op o tys => .op o tys
    | .loc l => .loc l

  def Val.substList (σ : Nat → Val) : List Val → List Val
    | [] => []
    | v :: vs => Val.subst σ v :: Val.substList σ vs

  def Comp.subst (σ : Nat → Val) : Comp → Comp
    | .ret v => .ret (Val.subst σ v)
    | .letIn m n => .letIn (Comp.subst σ m) (Comp.subst (upSubst 1 σ) n)
    | .app f args => .app (Val.subst σ f) (Val.substList σ args)
    | .ite v m n => .ite (Val.subst σ v) (Comp.subst σ m) (Comp.subst σ n)
    | .match v arms => .match (Val.subst σ v) (Comp.substArms σ arms)
    | .lazyC m => .lazyC (Comp.subst σ m)
    | .escape v => .escape (Val.subst σ v)
    | .use v m => .use (Val.subst σ v) (Comp.subst σ m)
    | .handle m h => .handle (Comp.subst σ m) (Clause.substList σ h)
    | .resume k v => .resume (Val.subst σ k) (Val.subst σ v)

  def Comp.substArms (σ : Nat → Val) : List (Pat × Comp) → List (Pat × Comp)
    | [] => []
    | (p, m) :: arms => (p, Comp.subst (upSubst p.binders σ) m) :: Comp.substArms σ arms

  def Clause.substList (σ : Nat → Val) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.subst (upSubst (n + 1) σ) m) :: Clause.substList σ cs
end

/-- 01-12 の `M[W̄/x̄]`。束縛した順の最後の値が番号 0 に当たる。 -/
def instSubst (ws : List Val) (i : Nat) : Val :=
  if i < ws.length then (ws.reverse[i]?).getD (.var i) else .var (i - ws.length)

def Comp.instantiate (ws : List Val) (m : Comp) : Comp :=
  Comp.subst (instSubst ws) m

/-! ## パターンの照合と分岐の選択（段階 A と同じ） -/

mutual
  def Pat.matchVal : Pat → Val → Option (List Val)
    | .wild, _ => some []
    | .var, v => some [v]
    | .const c, .const c' => if c.matches c' then some [] else none
    | .con c ps, .con c' _ args =>
        if c = c' then Pat.matchList ps args else none
    | _, _ => none

  def Pat.matchList : List Pat → List Val → Option (List Val)
    | [], [] => some []
    | p :: ps, v :: vs => do
        let a ← Pat.matchVal p v
        let b ← Pat.matchList ps vs
        pure (a ++ b)
    | _, _ => none
end

def firstMatch (v : Val) : List (Pat × Comp) → Option (Comp × List Val)
  | [] => none
  | (p, m) :: arms =>
      match Pat.matchVal p v with
      | some ws => some (m, ws)
      | none => firstMatch v arms

end Benitoite.Release
```

### formal/Benitoite/Release/Typing.lean

```lean
import Benitoite.Release.Subst

/-!
# 型付け規則（段階 B1）

設計書 01-12 の型付け規則に、「初回リリース版の拡張」の制御の構成の型付けを加える。
計算の判断は 01-12 の `Γ; R ⊢c M : A ! ε` であり、値の判断にはストアの型付け Ψ を加える。

段階 A からの表現の違い:

- 型付けの判断は、型パラメータの組み込みの制約の並び `C`（型の変数の番号の順）を持つ（ADR 0297）。V-Prim は
  組み込みの関数の型パラメータの制約を `C` のもとで確かめ、V-Fun は型引数が関数の型パラメータの制約を
  満たすことを確かめる。型が制約を満たすか（等値の型・鍵の型）は 01-06 に委ね、`Builtins.sat` で与える。
- 環境 Γ の要素は `Option Ty` である。V-Lam の前提と `lazy M` の M の検査では、Γ から継続の型を持つ変数を
  除く（01-12「ハンドラ」）。番号で表した変数を除くと番号がずれるので、要素を `none` に置き換えて表す。
- `handle` の節が処理する操作の型パラメータは、節の中で型の変数の番号 `0..k-1` に束縛し、制約の並びの
  先頭に加える（01-06「その型パラメータをほかの何とも等しくない型として扱う」）。節の外側の型（環境の型、
  `handle` の式の型、R）は、節の中では番号を k だけずらす。
-/

namespace Benitoite.Release

/-! ## 組み込みの関数 -/

abbrev ErrKind := String

/-- 組み込みの関数の結果。値、実行時エラー、プロセスの終了（E-Exit の `b(W̄) ↦ exit(n)`）。 -/
inductive Outcome where
  | val (v : Val)
  | err (r : ErrKind)
  | exit (n : Int)

/-- 組み込みの関数の種類。ストアの規則（E-RefNew など）を使う関数は、E-Prim・E-IO を使わない
（01-12「ストア：可変のセルと明示遅延」）。終了状態を指定したプロセスの終了の関数（`exit`）には、E-IO を使わず
E-Exit を使う（01-12「プロセスの終了」）。 -/
inductive PrimKind where
  | pure | io | exit | refNew | refGet | refSet | refUpdate | force
  deriving DecidableEq

structure PrimSig where
  tparams : List TParam
  neffs : Nat
  params : List Ty
  ret : Ty
  eff : Eff
  /-- 型パラメータの制約（組み込みの制約と演算子の型の集まり）。制約の並び `C` のもとで判定する。 -/
  admits : List TParam → List Ty → Prop
  kind : PrimKind
  /-- 組み込みのエフェクトの操作のとき、そのエフェクトの名前。 -/
  opEff : Option EffName

def PrimSig.ntys (s : PrimSig) : Nat := s.tparams.length

/-- 組み込みの関数と、01-12 がほかの章に委ねているもの。 -/
structure Builtins where
  sig : PrimName → Option PrimSig
  /-- IO を行わない組み込みの関数の値 δ(b[T̄; Ē], W̄)（ADR 0296）。 -/
  delta : PrimName → List Ty → List Eff → List Val → Option Outcome
  /-- IO を行う組み込みの関数の応答として起こりうるもの。 -/
  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → Prop
  /-- 事象 `release(V)` の応答として起こりうるもの。`none` が `ok`、`some r` が `error(r)`。 -/
  releaseResponse : Val → Option ErrKind → Prop
  /-- リソースの型か。リソースの型の解放のエフェクト `rel(O_r)` は `{State}` である。 -/
  isResource : OpaqueName → Bool
  /-- 組み込みのエフェクトと、その操作。`State` は操作を持たない。 -/
  effects : EffName → Option (List PrimName)
  /-- 型が組み込みの制約を満たすか（01-06「等値の型」「鍵の型」）。制約の並び `C` のもとで判定する。 -/
  sat : List TParam → Ty → TParam → Prop
  /-- `Reference.get` と `Reference.set` の名前。`Reference.update` の遷移が使う。 -/
  refGet : PrimName
  refSet : PrimName

def fnTy (params : List Ty) (ret : Ty) (eff : Eff) (ts : List Ty) (es : List Eff) : Ty :=
  Ty.subst ts es (.fn params ret eff)

/-- 型引数 `ts` が、型パラメータの制約 `tps` を、制約の並び `C` のもとで満たす。制約の並びは、型の変数の番号の
順（内側から）に並べる。 -/
def SatAll (B : Builtins) (C : List TParam) (ts : List Ty) (tps : List TParam) : Prop :=
  ts.length = tps.length ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → tps[i]? = some p → B.sat C t p

/-! ## 操作 -/

/-- 操作の型 `∀ᾱ. (Ā) → B ! {L}`。 -/
structure OpSig where
  tparams : List TParam
  params : List Ty
  ret : Ty
  eff : EffName

def opSig (P : Program) (B : Builtins) : OpRef → Option OpSig
  | .user o => (P.ops o).map fun od => ⟨od.tparams, od.params, od.ret, od.eff⟩
  | .prim b =>
      match B.sig b with
      | some s =>
          match s.opEff with
          | some l => some ⟨s.tparams, s.params, s.ret, l⟩
          | none => none
      | none => none

/-- エフェクト L の操作の一覧。利用者が宣言したエフェクトか、組み込みのエフェクト。 -/
def effOps (P : Program) (B : Builtins) (l : EffName) : Option (List OpRef) :=
  match P.effects l with
  | some os => some (os.map .user)
  | none => (B.effects l).map (·.map .prim)

/-- `handles(H, op)`。 -/
def handles (h : List Clause) (o : OpRef) : Bool := h.any (fun c => c.op == o)

/-- `handled(H)`。一つ以上の操作を持ち、そのすべての操作の節を H が持つエフェクトの集合。 -/
def handled (P : Program) (B : Builtins) (h : List Clause) : Eff := fun a =>
  match a with
  | .name l =>
      match effOps P B l with
      | some (o :: os) => (o :: os).all (handles h)
      | _ => false
  | .rho _ => false

/-! ## 型の正しさ -/

mutual
  /-- 型の中の型の変数の番号が `n` より小さい（その位置で束縛された型の変数だけを使う）。 -/
  def Ty.WF (n : Nat) : Ty → Prop
    | .base _ => True
    | .opaque _ => True
    | .data _ args => Ty.WFList n args
    | .list a => Ty.WF n a
    | .fn params ret _ => Ty.WFList n params ∧ Ty.WF n ret
    | .tvar i => i < n
    | .reference a => Ty.WF n a
    | .lazy a => Ty.WF n a
    | .cont b t _ => Ty.WF n b ∧ Ty.WF n t

  def Ty.WFList (n : Nat) : List Ty → Prop
    | [] => True
    | a :: as => Ty.WF n a ∧ Ty.WFList n as
end

/-! ## 型の包含 -/

def Ty.Le (a a' : Ty) : Prop :=
  a = a' ∨ ∃ ps r ε ε', a = .fn ps r ε ∧ a' = .fn ps r ε' ∧ Eff.Sub ε ε'

/-! ## ストアの型付けと環境 -/

/-- ストアの場所の型。可変のセル、明示遅延、継続（継続の型と、継続を作った節の R）。 -/
inductive LocTy where
  | ref (a : Ty)
  | lazy (a : Ty)
  | cont (b t : Ty) (ε : Eff) (r : Option Ty)

/-- ストアの型付け Ψ。 -/
abbrev StoreTy := Nat → Option LocTy

/-- 環境から継続の型を持つ変数を除く。番号をずらさないように、要素を `none` にする。 -/
def hideConts (Γ : List (Option Ty)) : List (Option Ty) :=
  Γ.map fun o => match o with
    | some (.cont _ _ _) => none
    | x => x

/-- 型の並びを、環境に加える形にする。 -/
def binds (as : List Ty) : List (Option Ty) := as.reverse.map some

/-- 環境の型の番号をずらす（節の内側に入るとき）。 -/
def shiftEnv (k : Nat) (Γ : List (Option Ty)) : List (Option Ty) := Γ.map (Option.map (Ty.shift k 0))

/-! ## パターンと網羅性 -/

mutual
  inductive PatTy (P : Program) : Pat → Ty → List Ty → Prop
    | P_Wild {a} : PatTy P .wild a []
    | P_Var {a} : PatTy P .var a [a]
    | P_Const {c} :
        (∀ x, c ≠ .float x) → (∀ n, c ≠ .byte n) → (∀ n s, c ≠ .decimal n s) →
        (∀ o n, c ≠ .opaque o n) →
        PatTy P (.const c) c.type []
    | P_Con {c ps cd ts δ} :
        P.cons c = some cd → ts.length = cd.ntys →
        PatTys P ps (cd.args.map (Ty.subst ts [])) δ →
        PatTy P (.con c ps) (.data cd.data ts) δ

  inductive PatTys (P : Program) : List Pat → List Ty → List Ty → Prop
    | nil : PatTys P [] [] []
    | cons {p ps a as δ δs} :
        PatTy P p a δ → PatTys P ps as δs → PatTys P (p :: ps) (a :: as) (δ ++ δs)
end

mutual
  /-- 網羅性を考えるうえでの値の形。パターンが中を調べない型（関数の型、型パラメータ、セル、明示遅延、
  継続）には、どの値も属するとする。 -/
  inductive Inhabits (P : Program) : Ty → Val → Prop
    | const {c} : Inhabits P c.type (.const c)
    | con {c ts tys' args cd} :
        P.cons c = some cd → cd.ntys = ts.length →
        InhabitsAll P (cd.args.map (Ty.subst ts [])) args →
        Inhabits P (.data cd.data ts) (.con c tys' args)
    | list {a elems} : InhabitsEach P a elems → Inhabits P (.list a) (.list elems)
    | fn {ps r ε v} : Inhabits P (.fn ps r ε) v
    | tvar {i v} : Inhabits P (.tvar i) v
    | reference {a v} : Inhabits P (.reference a) v
    | lazy {a v} : Inhabits P (.lazy a) v
    | cont {b t ε v} : Inhabits P (.cont b t ε) v

  inductive InhabitsAll (P : Program) : List Ty → List Val → Prop
    | nil : InhabitsAll P [] []
    | cons {a as v vs} : Inhabits P a v → InhabitsAll P as vs → InhabitsAll P (a :: as) (v :: vs)

  inductive InhabitsEach (P : Program) : Ty → List Val → Prop
    | nil {a} : InhabitsEach P a []
    | cons {a v vs} : Inhabits P a v → InhabitsEach P a vs → InhabitsEach P a (v :: vs)
end

def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
  ∀ v, Inhabits P a v → ∃ p ∈ ps, (Pat.matchVal p v).isSome

/-! ## 値と計算の型付け -/

mutual
  /-- `Γ ⊢v V : A`（制約の並び C とストアの型付け Ψ のもとで）。 -/
  inductive HasTypeV (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → Val → Ty → Prop
    /-- 継続の型の変数は、`resume` の第一引数にだけ書ける（C-Resume。ADR 0300）。 -/
    | V_Var {Γ i a} : Γ[i]? = some (some a) → (∀ b t ε, a ≠ .cont b t ε) →
        HasTypeV P B Ψ C Γ (.var i) a
    | V_Const {Γ c} : HasTypeV P B Ψ C Γ (.const c) c.type
    | V_Fun {Γ f d ts es} :
        P.defs f = some d → SatAll B C ts d.tparams → es.length = d.neffs →
        HasTypeV P B Ψ C Γ (.fnRef f ts es) (fnTy d.params d.ret d.eff ts es)
    | V_Prim {Γ b s ts es} :
        B.sig b = some s → ts.length = s.ntys → es.length = s.neffs → s.admits C ts →
        HasTypeV P B Ψ C Γ (.prim b ts es) (fnTy s.params s.ret s.eff ts es)
    | V_Op {Γ o od ts} :
        P.ops o = some od → SatAll B C ts od.tparams →
        HasTypeV P B Ψ C Γ (.op o ts) (fnTy od.params od.ret (Eff.single od.eff) ts [])
    | V_Lam {Γ ps body r ε} :
        HasTypeC P B Ψ C (binds ps ++ hideConts Γ) (some r) body r ε →
        HasTypeV P B Ψ C Γ (.lam ps body) (.fn ps r ε)
    | V_Con {Γ c ts args cd} :
        P.cons c = some cd → ts.length = cd.ntys →
        HasTypeVs P B Ψ C Γ args (cd.args.map (Ty.subst ts [])) →
        HasTypeV P B Ψ C Γ (.con c ts args) (.data cd.data ts)
    /-- V-List。要素の型は、その位置で束縛された型の変数だけを使う（空のリストの要素の型は項に現れないので、
    型の正しさを前提に置く）。 -/
    | V_List {Γ elems a} :
        HasTypeEach P B Ψ C Γ elems a → Ty.WF C.length a → HasTypeV P B Ψ C Γ (.list elems) (.list a)
    /-- `Ψ(ℓ) = A` のとき `ℓ : A`（01-12「確かめる性質」）。 -/
    | V_LocRef {Γ l a} : Ψ l = some (.ref a) → HasTypeV P B Ψ C Γ (.loc l) (.reference a)
    | V_LocLazy {Γ l a} : Ψ l = some (.lazy a) → HasTypeV P B Ψ C Γ (.loc l) (.lazy a)
    | V_Sub {Γ v a a'} :
        HasTypeV P B Ψ C Γ v a → Ty.Le a a' → HasTypeV P B Ψ C Γ v a'

  inductive HasTypeVs (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → List Val → List Ty → Prop
    | nil {Γ} : HasTypeVs P B Ψ C Γ [] []
    | cons {Γ v vs a as} :
        HasTypeV P B Ψ C Γ v a → HasTypeVs P B Ψ C Γ vs as → HasTypeVs P B Ψ C Γ (v :: vs) (a :: as)

  inductive HasTypeEach (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → List Val → Ty → Prop
    | nil {Γ a} : HasTypeEach P B Ψ C Γ [] a
    | cons {Γ v vs a} :
        HasTypeV P B Ψ C Γ v a → HasTypeEach P B Ψ C Γ vs a → HasTypeEach P B Ψ C Γ (v :: vs) a

  /-- `Γ; R ⊢c M : A ! ε`。R は最も内側の関数の戻り値の型で、`none` は `escape` を許さない。 -/
  inductive HasTypeC (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → Option Ty → Comp → Ty → Eff → Prop
    | C_Return {Γ R v a} : HasTypeV P B Ψ C Γ v a → HasTypeC P B Ψ C Γ R (.ret v) a Eff.empty
    | C_Sub {Γ R m a a' ε ε'} :
        HasTypeC P B Ψ C Γ R m a ε → Ty.Le a a' → Eff.Sub ε ε' → HasTypeC P B Ψ C Γ R m a' ε'
    | C_Let {Γ R m n a b ε} :
        HasTypeC P B Ψ C Γ R m a ε → HasTypeC P B Ψ C (some a :: Γ) R n b ε →
        HasTypeC P B Ψ C Γ R (.letIn m n) b ε
    | C_App {Γ R f args as b ε} :
        HasTypeV P B Ψ C Γ f (.fn as b ε) → HasTypeVs P B Ψ C Γ args as →
        HasTypeC P B Ψ C Γ R (.app f args) b ε
    | C_If {Γ R v m n a ε} :
        HasTypeV P B Ψ C Γ v (.base .boolean) → HasTypeC P B Ψ C Γ R m a ε →
        HasTypeC P B Ψ C Γ R n a ε → HasTypeC P B Ψ C Γ R (.ite v m n) a ε
    | C_Match {Γ R v arms a b ε} :
        HasTypeV P B Ψ C Γ v a → HasTypeArms P B Ψ C Γ R arms a b ε →
        Exhaustive P a (arms.map Prod.fst) → HasTypeC P B Ψ C Γ R (.match v arms) b ε
    /-- `Γ ⊢c M : A ! { }` のとき `Γ ⊢c lazy M : Lazy[A] ! { }`。M は R を持たない判断で、継続の型を持つ
    変数を除いた環境で検査する（01-12「ストア」「関数の境界と escape」「ハンドラ」）。 -/
    | C_Lazy {Γ R m a} :
        HasTypeC P B Ψ C (hideConts Γ) none m a Eff.empty →
        HasTypeC P B Ψ C Γ R (.lazyC m) (.lazy a) Eff.empty
    /-- `Γ; R ⊢v V : R` のとき、`Γ; R ⊢c escape V : A ! ε`（任意の A と ε）。 -/
    | C_Escape {Γ r v a ε} :
        HasTypeV P B Ψ C Γ v r → Ty.WF C.length a → HasTypeC P B Ψ C Γ (some r) (.escape v) a ε
    /-- C-Use。解放のエフェクト `rel(O_r) = {State}` を ε が含む。 -/
    | C_Use {Γ R v o m b ε} :
        HasTypeV P B Ψ C Γ v (.opaque o) → B.isResource o = true →
        HasTypeC P B Ψ C Γ R m b ε → ε (.name stateEff) = true →
        HasTypeC P B Ψ C Γ R (.use v m) b ε
    /-- C-Handle。 -/
    | C_Handle {Γ R m h t εm ε} :
        HasTypeC P B Ψ C Γ R m t εm → Eff.Sub εm (Eff.union ε (handled P B h)) →
        HasTypeClauses P B Ψ C Γ R h t ε →
        HasTypeC P B Ψ C Γ R (.handle m h) t ε
    /-- C-Resume（節の変数 k）と C-ResumeL（継続の場所 κ）。継続の型の値は、`resume` の第一引数に
    だけ書ける（ADR 0300）。κ に `resume` するときは、κ を作った節の R が、いまの R と等しい。 -/
    | C_Resume {Γ R i v b t ε} :
        Γ[i]? = some (some (.cont b t ε)) → HasTypeV P B Ψ C Γ v b →
        HasTypeC P B Ψ C Γ R (.resume (.var i) v) t ε
    | C_ResumeL {Γ R l v b t ε} :
        Ψ l = some (.cont b t ε R) → HasTypeV P B Ψ C Γ v b →
        HasTypeC P B Ψ C Γ R (.resume (.loc l) v) t ε

  inductive HasTypeArms (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → Option Ty → List (Pat × Comp) → Ty → Ty → Eff → Prop
    | nil {Γ R a b ε} : Ty.WF C.length b → HasTypeArms P B Ψ C Γ R [] a b ε
    | cons {Γ R p m arms a b ε δ} :
        PatTy P p a δ → HasTypeC P B Ψ C (binds δ ++ Γ) R m b ε →
        HasTypeArms P B Ψ C Γ R arms a b ε →
        HasTypeArms P B Ψ C Γ R ((p, m) :: arms) a b ε

  /-- C-Handle の各節 `op(x̄) k ⇒ N`：`Γ, x̄:Ā, k:Cont(B → T ! ε); R ⊢c N : T ! ε`。操作の型パラメータは、
  節の中の型の変数の番号 `0..k-1` に束縛した、宣言の制約を持つ、ほかの型とは等しくない型の変数である。
  節の外側の Γ・T・R の型は、番号を k だけずらす。 -/
  inductive HasTypeClauses (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → Option Ty → List Clause → Ty → Eff → Prop
    | nil {Γ R t ε} : HasTypeClauses P B Ψ C Γ R [] t ε
    | cons {Γ R o n k body cs t ε sg} :
        opSig P B o = some sg → n = sg.params.length → k = sg.tparams.length →
        HasTypeC P B Ψ (sg.tparams ++ C)
          (some (.cont sg.ret (t.shift k 0) ε) :: (binds sg.params ++ shiftEnv k Γ))
          (R.map (Ty.shift k 0)) body (t.shift k 0) ε →
        HasTypeClauses P B Ψ C Γ R cs t ε →
        HasTypeClauses P B Ψ C Γ R (.mk o n k body :: cs) t ε
end

/-! ## 定義とプログラム -/

/-- 空のストアの型付け。定義の本体は場所を含まない。 -/
def StoreTy.empty : StoreTy := fun _ => none

/-- 定義に型が付く。`x1:A1, …, xn:An; B ⊢c M : B ! ε`（R := B）。 -/
def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  HasTypeC P B StoreTy.empty d.tparams (binds d.params) (some d.ret) d.body d.ret d.eff

def Program.WellTyped (P : Program) (B : Builtins) : Prop :=
  ∀ f d, P.defs f = some d → d.WellTyped P B

end Benitoite.Release
```

### formal/Benitoite/Release/WellFormed.lean

```lean
import Benitoite.Release.Typing

/-!
# 型とエフェクトの変数の範囲（段階 B1）

型の変数は de Bruijn の番号で表す（`Syntax.lean`）。`VarsIn n pe` は、項の中の型の変数の番号が、その位置で
束縛されている個数（外側の `n` に、囲む節が束縛する個数を足したもの）より小さく、エフェクト変数の番号が
`pe` を満たすことを表す。

実行中の状態の項は、型の変数を含まない（`n = 0`）。01-12 では、実行は `⟨main[;](), [], ∅⟩` から
始まり、型パラメータを束縛しない環境で型が付くので、この条件は暗黙に成り立っている。形式化では、
E-Fun と E-Op が閉じた型だけを置き換えることを、この条件で示す。
-/

namespace Benitoite.Release

def Eff.RhosIn (pe : Nat → Prop) (ε : Eff) : Prop :=
  ∀ i, ε (.rho i) = true → pe i

mutual
  /-- 型の中の型の変数の番号が `n` より小さく、エフェクト変数の番号が `pe` を満たし、継続の型を含まない
  （項の中に書ける型である）。 -/
  def Ty.VarsIn (n : Nat) (pe : Nat → Prop) : Ty → Prop
    | .base _ => True
    | .opaque _ => True
    | .data _ args => Ty.VarsInList n pe args
    | .list a => Ty.VarsIn n pe a
    | .fn params ret eff => Ty.VarsInList n pe params ∧ Ty.VarsIn n pe ret ∧ Eff.RhosIn pe eff
    | .tvar i => i < n
    | .reference a => Ty.VarsIn n pe a
    | .lazy a => Ty.VarsIn n pe a
    -- 継続の型は、項の中に書けない（01-12「ハンドラ」の「値として書けるのは節の中だけ」）。
    | .cont _ _ _ => False

  def Ty.VarsInList (n : Nat) (pe : Nat → Prop) : List Ty → Prop
    | [] => True
    | a :: as => Ty.VarsIn n pe a ∧ Ty.VarsInList n pe as
end

def Eff.RhosInList (pe : Nat → Prop) : List Eff → Prop
  | [] => True
  | e :: es => Eff.RhosIn pe e ∧ Eff.RhosInList pe es

mutual
  def Val.VarsIn (n : Nat) (pe : Nat → Prop) : Val → Prop
    | .var _ => True
    | .const _ => True
    | .fnRef _ tys effs => Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs
    | .prim _ tys effs => Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs
    | .lam params body => Ty.VarsInList n pe params ∧ Comp.VarsIn n pe body
    | .con _ tys args => Ty.VarsInList n pe tys ∧ Val.VarsInList n pe args
    | .list elems => Val.VarsInList n pe elems
    | .op _ tys => Ty.VarsInList n pe tys
    | .loc _ => True

  def Val.VarsInList (n : Nat) (pe : Nat → Prop) : List Val → Prop
    | [] => True
    | v :: vs => Val.VarsIn n pe v ∧ Val.VarsInList n pe vs

  def Comp.VarsIn (n : Nat) (pe : Nat → Prop) : Comp → Prop
    | .ret v => Val.VarsIn n pe v
    | .letIn m m' => Comp.VarsIn n pe m ∧ Comp.VarsIn n pe m'
    | .app f args => Val.VarsIn n pe f ∧ Val.VarsInList n pe args
    | .ite v m m' => Val.VarsIn n pe v ∧ Comp.VarsIn n pe m ∧ Comp.VarsIn n pe m'
    | .match v arms => Val.VarsIn n pe v ∧ Comp.VarsInArms n pe arms
    | .lazyC m => Comp.VarsIn n pe m
    | .escape v => Val.VarsIn n pe v
    | .use v m => Val.VarsIn n pe v ∧ Comp.VarsIn n pe m
    | .handle m h => Comp.VarsIn n pe m ∧ Clause.VarsInList n pe h
    | .resume k v => Val.VarsIn n pe k ∧ Val.VarsIn n pe v

  def Comp.VarsInArms (n : Nat) (pe : Nat → Prop) : List (Pat × Comp) → Prop
    | [] => True
    | (_, m) :: arms => Comp.VarsIn n pe m ∧ Comp.VarsInArms n pe arms

  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
  def Clause.VarsInList (n : Nat) (pe : Nat → Prop) : List Clause → Prop
    | [] => True
    | .mk _ _ k m :: cs => Comp.VarsIn (n + k) pe m ∧ Clause.VarsInList n pe cs
end

/-! ## 宣言の変数の範囲 -/

/-- 関数の定義の型（引数、戻り値、エフェクト）と本体は、宣言した型パラメータとエフェクト変数だけを使う。
本体の範囲は、E-Fun の後の状態が型の変数を含まないことに要る。 -/
def Def.Scoped (d : Def) : Prop :=
  Ty.VarsInList d.ntys (· < d.neffs) d.params ∧ Ty.VarsIn d.ntys (· < d.neffs) d.ret ∧
    Eff.RhosIn (· < d.neffs) d.eff ∧ Comp.VarsIn d.ntys (· < d.neffs) d.body

def ConDecl.Scoped (cd : ConDecl) : Prop :=
  Ty.VarsInList cd.ntys (fun _ => False) cd.args

def OpDecl.Scoped (od : OpDecl) : Prop :=
  Ty.VarsInList od.tparams.length (fun _ => False) od.params ∧
    Ty.VarsIn od.tparams.length (fun _ => False) od.ret

def PrimSig.Scoped (s : PrimSig) : Prop :=
  Ty.VarsInList s.ntys (· < s.neffs) s.params ∧ Ty.VarsIn s.ntys (· < s.neffs) s.ret ∧
    Eff.RhosIn (· < s.neffs) s.eff

def Program.WellFormed (P : Program) : Prop :=
  (∀ f d, P.defs f = some d → d.Scoped) ∧ (∀ c cd, P.cons c = some cd → cd.Scoped) ∧
    (∀ o od, P.ops o = some od → od.Scoped)

/-- 01-12 の性質 3 の「M がエフェクト変数を含まない」と、型パラメータを束縛しない環境の項であること。 -/
def Comp.ClosedNoEffVars (m : Comp) : Prop :=
  Comp.VarsIn 0 (fun _ => False) m

end Benitoite.Release
```

### formal/Benitoite/Release/Semantics.lean

```lean
import Benitoite.Release.WellFormed

/-!
# 実行の規則（段階 B1）

設計書 01-12 の「実行の規則」を、「初回リリース版の拡張」のストア、`escape`、`with`、プロセスの終了、
ハンドラの規則で広げたものを書き写す。構成子の名前は 01-12 の規則の名前に対応させる。

01-12 との表現の違い:

- ストアは、場所から中身への関数とする。有限であることは、ストアの型付け（`StoreOk`）の条件にする。
- 組み込みの操作の E-Op は、規則 E-OpPrim として分けて書く。
- IO の事象は、組み込みの関数の名前、引数、応答からなり、型引数とエフェクト引数を含めない（ADR 0296）。
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

/-- 継続の二度目の再開の実行時エラーの種類 `r_resume`。 -/
def rResume : ErrKind := "ResumeTwice"

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
  | E_IfT {m n k σ} :
      Step P B (.run (.ite (.const (.boolean true)) m n) k σ) none (.run m k σ)
  | E_IfF {m n k σ} :
      Step P B (.run (.ite (.const (.boolean false)) m n) k σ) none (.run n k σ)
  | E_Match {v arms k σ m ws} :
      firstMatch v arms = some (m, ws) →
      Step P B (.run (.match v arms) k σ) none (.run (m.instantiate ws) k σ)
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
  /-- E-IOErr。プロセスの終了の関数の、許可がないときの応答も `error(r)` である（01-12「プロセスの終了」）。 -/
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
  | .run (.ite (.const (.boolean true)) m _) k σ => some (none, .run m k σ)
  | .run (.ite (.const (.boolean false)) _ n) k σ => some (none, .run n k σ)
  | .run (.ite _ _ _) _ _ => none
  | .run (.match v arms) k σ =>
      match firstMatch v arms with
      | some (m, ws) => some (none, .run (m.instantiate ws) k σ)
      | none => none
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
  /-- K-Handle。節は、枠の下の継続が許すエフェクトに含まれるエフェクト εc で検査する（ADR 0302）。 -/
  | K_Handle {R ε εc h k t b ε0 Re} :
      ContTy P B Ψ R ε k t b ε0 Re → Eff.Sub εc ε → HasTypeClauses P B Ψ [] [] R h t εc →
      Ty.WF 0 t →
      ContTy P B Ψ R (Eff.union εc (handled P B h)) (.handleF h :: k) t b ε0 Re
  /-- K-Drop。捨てる継続の解放の枠を、この位置で実行できるように、κ の継続の型のエフェクトが `State` を
  含むなら、ε も `State` を含む（ADR 0300）。 -/
  | K_Drop {R ε κ k a b ε0 Re b' t' ε' R'} :
      Ψ κ = some (.cont b' t' ε' R') → (ε' (.name stateEff) = true → ε (.name stateEff) = true) →
      ContTy P B Ψ R ε k a b ε0 Re →
      ContTy P B Ψ R ε (.drop κ :: k) a b ε0 Re
  /-- K-Sub。継続が受け取る型を広げる（ADR 0301）。 -/
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
ADR 0300）。 -/
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
`R = none` で使う導出で満たす（ADR 0299）。加えて、状態の中の項が型の変数を含まないこと
（`WellFormed.lean` の冒頭）を求める。 -/
def StateTy (P : Program) (B : Builtins) : State → Prop
  | .run m k σ => ∃ Ψ R a b ε ε1 Eb,
      StoreOk P B Ψ σ ∧ HasTypeC P B Ψ [] [] R m a ε1 ∧ Eff.Sub ε1 ε ∧
      ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
      Comp.VarsIn 0 (fun _ => True) m ∧ Cont.Closed k ∧ Store.Closed σ
  | .error _ k σ => ∃ Ψ R a b ε Eb,
      StoreOk P B Ψ σ ∧ ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
      Cont.Closed k ∧ Store.Closed σ
  | .exit _ _ k σ => ∃ Ψ R a b ε Eb,
      StoreOk P B Ψ σ ∧ ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
      Cont.Closed k ∧ Store.Closed σ

end Benitoite.Release
```

### formal/Benitoite/Release/Assumptions.lean

```lean
import Benitoite.Release.Semantics

/-!
# 形式化で仮定するもの（段階 B1）

段階 A の仮定（`Benitoite.Core.Builtins.Assumptions`）を、段階 B1 の組み込みの関数に広げる。
設計書 07-04「形式化で仮定するもの」の表に対応する。仮定は `axiom` としては置かず、定理の引数として明示する。
-/

namespace Benitoite.Release

/-- 組み込みの関数の結果が型 A を持つ。値は型の変数を含まない。 -/
def OutcomeTy (P : Program) (B : Builtins) (Ψ : StoreTy) : Outcome → Ty → Prop
  | .val v, a => HasTypeV P B Ψ [] [] v a ∧ Val.VarsIn 0 (fun _ => True) v
  | .err _, _ => True
  | .exit _, _ => True

/-- 型パラメータの制約の並び `C0`（`C1` の外側）を、閉じた型 `ts` で置き換えられる。 -/
def ClosedSat (B : Builtins) (C0 C1 : List TParam) (ts : List Ty) : Prop :=
  (∀ t ∈ ts, Ty.WF 0 t) ∧ SatAll B C1 ts C0

/-- 可変のセルと明示遅延の組み込みの関数の型（01-07「可変のセル（初回リリース版）」、01-06「明示遅延の型」）。 -/
def PrimSig.StoreShape (s : PrimSig) : Prop :=
  match s.kind with
  | .refNew => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.tvar 0] ∧ s.ret = .reference (.tvar 0) ∧
      s.eff = Eff.single stateEff
  | .refGet => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.single stateEff
  | .refSet => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0), .tvar 0] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff
  | .refUpdate => s.ntys = 1 ∧ s.neffs = 0 ∧
      s.params = [.reference (.tvar 0), .fn [.tvar 0] (.tvar 0) Eff.empty] ∧
      s.ret = .base .unit ∧ s.eff = Eff.single stateEff
  | .force => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.lazy (.tvar 0)] ∧ s.ret = .tvar 0 ∧
      s.eff = Eff.empty
  | .pure => True
  | .io => True
  | .exit => True

structure Builtins.Assumptions (P : Program) (B : Builtins) : Prop where
  /-- 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う。 -/
  sig_scoped : ∀ b s, B.sig b = some s → s.Scoped
  /-- 制約の保存。制約の並びの `C1` の外側の `C0` を閉じた型で置き換えても、制約を満たす。 -/
  admits_subst : ∀ b s C0 C1 ts ts' es', B.sig b = some s → s.admits (C1 ++ C0) ts →
    ClosedSat B C0 C1 ts' → ts'.length = C0.length →
    s.admits C1 (ts.map (Ty.substAt C1.length ts' es'))
  sat_subst : ∀ C0 C1 t p ts' es', B.sat (C1 ++ C0) t p →
    ClosedSat B C0 C1 ts' → ts'.length = C0.length → B.sat C1 (t.substAt C1.length ts' es') p
  /-- 組み込みの関数の制約を満たす型引数は、その型パラメータの組み込みの制約も満たす。 -/
  admits_sat : ∀ b s C ts, B.sig b = some s → s.admits C ts → SatAll B C ts s.tparams
  /-- 制約の並び `C1` の型パラメータだけを使う型が制約を満たすかは、`C1` の外側の並びによらない。 -/
  sat_local : ∀ C1 C0 t p, Ty.WF C1.length t → B.sat C1 t p → B.sat (C1 ++ C0) t p
  admits_local : ∀ b s C1 C0 ts, B.sig b = some s → (∀ t ∈ ts, Ty.WF C1.length t) →
    s.admits C1 ts → s.admits (C1 ++ C0) ts
  /-- δ の型の保存（IO を行わない組み込みの関数）。 -/
  delta_typed : ∀ Ψ b s ts es ws, B.sig b = some s → s.kind = .pure →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    ∃ o, B.delta b ts es ws = some o ∧ (∀ n, o ≠ .exit n) ∧ OutcomeTy P B Ψ o (Ty.subst ts es s.ret)
  /-- IO の応答の型。IO を行う関数の応答は値か `error(r)`、プロセスの終了の関数の応答は `exit(n)` か
  `error(r)` である。 -/
  io_kind : ∀ b s ts es ws o, B.sig b = some s → B.ioResponse b ts es ws o →
    (s.kind = .io ∧ ∀ n, o ≠ .exit n) ∨ (s.kind = .exit ∧ ∀ v, o ≠ .val v)
  io_typed : ∀ Ψ b s ts es ws o, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    B.ioResponse b ts es ws o → OutcomeTy P B Ψ o (Ty.subst ts es s.ret)
  /-- IO の応答の存在。 -/
  io_exists : ∀ Ψ b s ts es ws, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    ∃ o, B.ioResponse b ts es ws o
  /-- IO を行う組み込みの関数は、組み込みのエフェクトの操作であり、型のエフェクトはそのエフェクトの
  名前だけである。 -/
  io_op : ∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ∃ l bs, s.opEff = some l ∧ s.eff = Eff.single l ∧ s.neffs = 0 ∧ B.effects l = some bs ∧ b ∈ bs
  /-- 組み込みのエフェクトの操作は、そのエフェクトを `opEff` に持つ、IO を行う組み込みの関数である。 -/
  effect_ops : ∀ l bs b, B.effects l = some bs → b ∈ bs →
    ∃ s, B.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit) ∧ s.opEff = some l
  opEff_io : ∀ b s l, B.sig b = some s → s.opEff = some l → (s.kind = .io ∨ s.kind = .exit)
  /-- `State` は操作を持たない組み込みのエフェクトである。 -/
  state_effect : B.effects stateEff = some []
  /-- 可変のセルと明示遅延の組み込みの関数の型と、制約。 -/
  store_shape : ∀ b s, B.sig b = some s → s.StoreShape
  store_admits : ∀ b s C ts, B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io → s.kind ≠ .exit →
    s.admits C ts
  ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
  ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet
  /-- 解放の事象には、起こりうる応答が少なくとも一つある。 -/
  release_exists : ∀ Ψ v o, HasTypeV P B Ψ [] [] v (.opaque o) → B.isResource o = true →
    ∃ r, B.releaseResponse v r

/-- エフェクトの宣言が、操作の宣言と合っている。利用者が宣言したエフェクトの名前は、組み込みのエフェクトの
名前と重ならない。 -/
def Program.EffectsOk (P : Program) (B : Builtins) : Prop :=
  (∀ l os o, P.effects l = some os → o ∈ os → ∃ od, P.ops o = some od ∧ od.eff = l) ∧
    (∀ o od, P.ops o = some od → ∃ os, P.effects od.eff = some os ∧ o ∈ os) ∧
    (∀ l os, P.effects l = some os → B.effects l = none)

end Benitoite.Release
```

### formal/Benitoite/Release/Theorems.lean

```lean
import Benitoite.Release.Lemmas.StepSound

/-!
# 段階 B1 の定理

設計書 01-12「確かめる性質」の性質 2（進行と保存）と性質 3（エフェクトの健全性）の、初回リリース版の
読み替えの形を、段階 B1 の範囲で言明し、証明する。証明の補題は `Lemmas/` に置く。

段階 A と違い、遷移を計算する関数 `step` と遷移の関係の一致は、`step` が返す遷移が関係の遷移であること
（`step_sound`）だけを言明する。`step` は例の実行を調べる道具であり、新しい場所と応答の選び方を固定するので、
関係のすべての遷移を返すわけではない。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-- 型が付いた状態について、`step` が返す遷移は `Step` の遷移である。`oracle` と `rel` は、起こりうる応答が
あるときは、その一つを選ぶ。`fresh` は、有限なストアに中身のない場所を選ぶ。 -/
theorem step_sound (hb : B.Assumptions P) (oracle : Oracle) (rel : Val → Option ErrKind) (fresh : Store → Nat)
    (horacle : ∀ b ts es ws o, B.ioResponse b ts es ws o → B.ioResponse b ts es ws (oracle b ts es ws))
    (hrel : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v))
    (hfresh : ∀ σ : Store, (∃ n, ∀ l, n ≤ l → σ l = none) → σ (fresh σ) = none)
    {s : State} {l : Option Event} {s' : State} :
    StateTy P B s → step P B oracle rel fresh s = some (l, s') → Step P B s l s' := by
  intro hs h
  obtain ⟨Eb, _, hs⟩ := stateTy_iff.mp hs
  exact step_soundE hb oracle rel fresh horacle hrel hfresh hs h

/-- 進行。型が付いた状態は、`⟨return V, [], σ⟩`、`error(r̄, [], σ)`、`exit(n, r̄, [], σ)` のいずれかであるか、
遷移できる。 -/
theorem progress (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {s : State} :
    StateTy P B s → s.Final ∨ ∃ l s', Step P B s l s' := by
  intro hs
  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
  exact progressE hdecl hb hs hEb

/-- 保存。型が付いた状態から遷移した先の状態も型が付く。 -/
theorem preservation (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.Assumptions P) {s : State} {l : Option Event} {s' : State} :
    StateTy P B s → Step P B s l s' → StateTy P B s' := by
  intro hs hst
  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
  exact stateTy_iff.mpr ⟨Eb, hEb, preservationE hwf hwt hdecl hb hs hst⟩

/-- エフェクトの健全性。`· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, [], ∅⟩` からの
実行は、事象を伴う遷移（IO の事象と解放の事象）をせず、どの `handle` の枠も処理しない操作を呼ばない。
`· ⊢c M` の R は `none` とする（実行を始める計算は関数の本体の外にあるので `escape` を許さない。ADR 0299）。 -/
theorem effect_soundness (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.Assumptions P) {m : Comp} {a : Ty} :
    HasTypeC P B StoreTy.empty [] [] none m a Eff.empty → m.ClosedNoEffVars →
    ∀ s, Steps P B (.run m [] Store.empty) s →
      (∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s := by
  intro hm hc s hsteps
  have hs := steps_preserve hwf hwt hdecl hb hsteps (stateTyE_init hwf hb hm hc)
  exact ⟨no_event hdecl hb hs, no_unhandledOp hdecl hs builtinOnly_empty⟩

end Benitoite.Release
```

## 資料 4: 07-04「形式化で仮定するもの」と「01-12 との対応」

```markdown
### 形式化で仮定するもの

【方針】01-12 は、組み込みの関数の型と値（関数 δ）と IO の応答を、ほかの章に委ねている。形式化では、これらの中身を定義せず、次の性質を定理の仮定として与える。Lean の `axiom` としては置かず、定理の引数（`formal/` の `Builtins.Assumptions`）として明示する。

| 仮定 | 内容 | 01-12 の根拠 |
|---|---|---|
| δ の型の保存 | 型 `(Ā) → B ! ε` の IO を行わない組み込みの関数 `b[T̄; Ē]` に、置き換えた型 `Āθ` の値を渡すと、`δ(b[T̄; Ē], W̄)` は定義されていて、型 `Bθ` の値か `error(r)` を返す（θ = [T̄/ᾱ, Ē/ρ̄]。[ADR 0296](../../../../../formal/reviews/decisions/0296-delta-receives-type-arguments.md)） | 「実行の規則」の E-Prim・E-Err |
| IO の応答の型 | 型 `(Ā) → B ! ε` の IO を行う組み込みの関数 `b[T̄; Ē]` に型 `Āθ` の値を渡したときの応答は、型 `Bθ` の値か `error(r)` である | 「確かめる性質」の性質 2 の「IO の応答は、関数の戻り値の型の値であるとする」 |
| IO の応答の存在 | IO を行う組み込みの関数 `b[T̄; Ē]` に型 `Āθ` の値を渡すと、起こりうる応答が少なくとも一つある | E-IO・E-IOErr で遷移できること（性質 2 の進行） |
| 組み込みの関数のエフェクト | IO を行う組み込みの関数の型のエフェクトは、組み込みのエフェクトの名前（最小実行版では `IO`）を含む | 性質 3 が IO の事象の不在を型から導くための前提 |
| 組み込みの関数の型の変数 | 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う | 01-12 は名前の束縛として暗黙に前提する |
| 制約の保存 | 型パラメータの制約（V-Prim の「T̄ が b の型パラメータの制約を満たす」）を満たす型は、型とエフェクトの置き換えの後も制約を満たす | E-Fun の置き換えの後も V-Prim が成り立つための前提 |

「組み込みの関数のエフェクト」は、01-12 に明文の規則がなく、[エフェクト](../../../../../formal/reviews/01-spec/01-07-effects.md)が組み込みの関数ごとに与えるエフェクトから読み取れる性質である。「制約の保存」は、最小実行版では制約が演算子の型の集まりと等値の型に限られ、型パラメータが制約を満たさないので成り立つ。

【方針】段階 B1 では、上の表の仮定を初回リリース版の組み込みの関数に広げ、次の仮定を加える。

| 仮定 | 内容 | 01-12 の根拠 |
|---|---|---|
| 制約の保存（広げたもの） | 定義の型パラメータの制約の並びの先頭を、制約を満たす閉じた型で置き換えても、組み込みの関数の制約と組み込みの制約（等値の型・鍵の型）は満たされる。型の変数を含まない型が制約を満たすかは、制約の並びによらない | E-Fun・E-Op の置き換えの後も V-Prim・V-Fun が成り立つための前提（[ADR 0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)） |
| δ と IO の応答の値 | δ と IO の応答が返す値は、型の変数を含まない | 実行中の項が型の変数を含まないことを保つための前提 |
| IO の応答の種類 | IO を行う組み込みの関数の応答は値か `error(r)`、プロセスの終了の関数の応答は `exit(n)` か `error(r)` である | 「プロセスの終了」の「E-Exit は、b が終了状態を指定したプロセスの終了の関数のときに使い、この関数には E-IO を使わない」 |
| 組み込みのエフェクトの操作 | IO を行う組み込みの関数とプロセスの終了の関数は、組み込みのエフェクト L の操作であり、型のエフェクトは `{L}` だけで、エフェクト変数を持たない。組み込みのエフェクトの操作の一覧の関数は、そのエフェクトの操作である。`State` は操作を持たない組み込みのエフェクトである | 「ハンドラ」の「組み込みのエフェクトの操作は、外部に作用する操作を行う組み込みの関数 b である」「State は操作を持たず」 |
| ストアの操作の型 | `Reference.new`・`get`・`set`・`update` と `Lazy.force` の型は、01-07 と 01-06 が定める形である | 「ストア」の箇条 |
| 解放の応答の存在 | リソースの型の値の解放の事象には、起こりうる応答が少なくとも一つある | E-Release・E-RelErr で遷移できること（性質 2 の進行） |

次の二つは、仮定ではなく定理の前提として言明する。

- プログラムの定義の集まり Σ に型が付くこと（すべての定義が 01-12 の「定義」の型付けを満たすこと）。
- 各定義の中の型パラメータとエフェクト変数が、その定義が宣言したものに限られること、構成子の引数の型の中の型パラメータが、代数的データ型が宣言したものに限られること。01-12 は名前の束縛として暗黙に前提するが、形式化では変数を番号で表すので、別に言明する。段階 B1 では、定義の型（引数、戻り値、エフェクト）と本体、操作の宣言の型について言明する。本体の範囲は、E-Fun の後の状態が型の変数を含まないことに要る。
- 段階 B1 では、エフェクトの宣言が操作の宣言と合っていること、利用者が宣言したエフェクトの名前が組み込みのエフェクトの名前と重ならないこと。

### 道具と置き場所

【決定】証明支援系には Lean 4 を使う。形式化は、リポジトリの根の `formal/` に Lake のプロジェクトとして置き、処理系の Cargo のワークスペースには含めない。Lean の版は `lean-toolchain` で固定する。検査は `lake build` で行い、完了条件の共通の検査（`scripts/check.sh`）には含めない。外部のライブラリには初めは依存せず、依存を加えるときは ADR に記録する（[ADR 0294](../../../../../formal/reviews/decisions/0294-lean-4-for-formal-verification.md)）。

【方針】抽象機械の遷移は、関係として定義するとともに、一歩の遷移を計算する関数としても定義し、両者が一致することを証明する。関数の形は、小さなコア計算のプログラムを Lean の中で実行し、01-12 の規則の書き写しの誤りを証明の前に見つけるために使う。段階 B1 の関数は、新しい場所と応答の選び方を固定するので、型が付いた状態について、関数が返す遷移が関係の遷移であること（健全性）だけを証明する。

### 01-12 との対応

【決定】01-12 を正とし、Lean の定義は 01-12 の規則の写しとする。食い違ったときは Lean の定義を 01-12 に合わせる。01-12 の規則の誤りと判断したときは、ADR を添えて 01-12 を直してから Lean の定義を合わせる（[ADR 0295](../../../../../formal/reviews/decisions/0295-core-calculus-chapter-normative-over-formalization.md)）。

【決定】Lean の定義の名前は、01-12 の規則の名前に対応させる（規則 `E-Op` の遷移は構成子 `E_Op`、規則 `C-Sub` の計算の型付けは構成子 `C_Sub`、規則 `K-Handle` の継続の型付けは構成子 `K_Handle` とする）。01-12 の節と形式化の対応は、次の表で管理する。形式化のために 01-12 と違う形で書いた箇所は、「表現の違い」の欄にその内容と理由を記す。

| 01-12 の節 | 段 | 表現の違い |
|---|---|---|
| 構文 | 段階 A | 項の変数は de Bruijn の番号で表す（`λ(x1, …, xn). M` の本体では番号 0 が xn）。型パラメータとエフェクト変数は、宣言した関数の中での番号で表す。エフェクトの集合は、エフェクトの原子から真偽値への関数で表す（並びの違いを型の等しさに持ち込まないため）。定数は Lean の値で表し、`type(c)` を関数として定める。`IOError` の値は番号で区別する。エフェクトの集合を関数で表すので、01-12 にない無限集合も表せる。このため形式化の型付けは 01-12 より広い（01-12 の型付けの導出は、どれも形式化の型付けの導出になる）。広い型付けについて証明した性質 2・3 は、01-12 の型付けについても成り立つ |
| 型付け規則（値、計算、パターン、定義） | 段階 A | Γ は型の並びで、先頭が番号 0 の変数の型である。P-Con の「変数はすべて異なる」は、変数を番号で表すので要らない。C-Match の網羅性は、01-05 の検査の手順ではなく、「型 A の値の形をしたどの値にも照合する分岐がある」こととして定める。値の形の集合は、型の付いた閉じた値の集合より広く、関数の型と型パラメータにはどの値も、構成子の値には型引数によらず属する。広い集合について網羅的なら、型の付いた値についても網羅的である（01-05 の検査がこの性質を満たすことは対象外）。組み込みの関数の型と制約は、前述の仮定の欄として与える |
| 実行の規則 | 段階 A | `S → S'` と `S —ℓ→ S'` を、IO の事象の有無をラベルに持つ一つの関係で表す。E-Prim・E-Err と E-IO・E-IOErr のどちらを使うかは、組み込みの関数ごとに IO を行うかの印で決める。E-Lam と E-Fun の「引数の並びと束縛する変数の並びが対応する」ことは、01-12 では記法 `M[W̄/x̄]` が暗黙に前提するので、個数の一致を遷移の前提として明示する。遷移を計算する関数も定め、関係と一致することを一歩について定理として言明する。この関数が使う IO の応答の関数は、同じ入力に同じ応答を返すので、同じ呼び出しへの応答が途中で変わる遷移の列は再現できない。この関数は例の実行を調べる道具として使う |
| 末尾呼び出しの保証、置き換えてよい等式 | 対象外 | |
| 表層からの脱糖 | 対象外（性質 1） | |
| 初回リリース版の拡張: モジュール、トップレベルの定数、リストの展開、レコード、文字列補間 | 対象外（脱糖だけで表す） | |
| 初回リリース版の拡張: 型パラメータの組み込みの制約 | 段階 B1 | 型付けの判断は、型パラメータの制約の並び（型の変数の番号の順）を持つ。型が制約を満たすか（等値の型・鍵の型）は 01-06 に委ね、組み込みの関数の欄として与える |
| 初回リリース版の拡張: 基本型 `Byte`・`Decimal`、中身を見せない型 | 段階 B1 | 中身を見せない型は名前で表し、リソースの型かどうかを組み込みの関数の欄として与える |
| 初回リリース版の拡張: ストア | 段階 B1 | ストアは場所から中身への関数とし、有限であることはストアの型付けの条件にする。ストアの操作を行う組み込みの関数は、組み込みの関数の種類で区別し、その型は仮定として与える。`Reference.update` の遷移は、`Reference.get`・`Reference.set` の名前を組み込みの関数の欄として与えて書く |
| 初回リリース版の拡張: 関数の境界と `escape`、`with`、プロセスの終了 | 段階 B1 | 解放の事象の応答は、組み込みの関数の欄として与える。プロセスの終了の関数は組み込みの関数の種類の一つとし、その応答 `exit(n)` に E-Exit を使う。IO の事象は、型引数とエフェクト引数を含めない（応答の関係には渡す）。`escape`・実行時エラー・終了の状態が `drop` の枠を通るときの扱い（01-12「ハンドラ」の箇条）を、規則 E-EscDrop・E-EscDropRel・E-ErrDrop・E-ErrDropRel・E-ExitDrop・E-ExitDropRel として書く。E-EscLet・E-ErrPop・E-ExitPop は、枠の種類ごとの規則に分けて書く |
| 初回リリース版の拡張: エフェクトの名前と開始状態 | 段階 B1 | エフェクトの名前は、モジュールと名前の組を一つの文字列で表す。組み込みのエフェクトとその操作の一覧は、組み込みの関数の欄として与える |
| 初回リリース版の拡張: ハンドラ | 段階 B1 | 型の変数を内側から数えた番号（de Bruijn の番号）で表す。節は操作の型パラメータを番号 0 から順に束縛し、節の外側の型（環境の型、`handle` の式の型、R）の番号を、束縛した個数だけずらす（値が節の中へ入っても型を書き換えずに済むため）。実行中の項は型の変数を含まないので、E-Fun と E-Op の置き換えは閉じた型を入れる。V-Lam と `lazy` の検査で環境から継続の型の変数を除くことは、環境の要素を `none` に置き換えて表す（番号をずらさないため）。E-Op は節の本体に操作の型引数の置き換えを施す（[ADR 0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。継続の型の値を `resume` の第一引数に限る規則（[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）は、V-Var の前提と、`resume` の第一引数ごとの規則 C-Resume（節の変数）・C-ResumeL（継続の場所）で表す。組み込みの操作の E-Op は、規則 E-OpPrim として分けて書く。同じ操作の節が二つあるときは、最初の節を選ぶ |
| 確かめる性質（初回リリース版の読み替え） | 段階 B1 | ストアの型付けの「Ψ と σ の場所が一致する」と K-Drop の `State` の条件（ADR 0300）は、01-12 のとおりに書く。継続の末尾の R を `none` とする状態の型付けの条件（[ADR 0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md)）は、継続の型付けの末尾の R の添字で表す。状態の型付けに、状態の中の項が型の変数を含まないことを加える（01-12 は実行を `main` から始めるので暗黙に成り立つ）。継続の型付けに、継続の末尾での R を添字として加え、ストアの継続の型付けの「末尾の `handle` の枠に K-Handle を R_κ で使う」を表す。性質 3 の「IO の事象を伴う遷移をしない」は、解放の事象を含むすべての事象を伴わないこととして言明する（より強い形）。性質 3 の「M がエフェクト変数を含まない」に、型の変数を含まないことを加える（型パラメータのない環境で型が付くので暗黙に成り立つ）。性質 3 の `· ⊢c M` の R は `none` とする。項に現れない型を型付けが選べる規則（V-List の要素の型、C-Escape の型、分岐のない `match` の型、K-Empty・K-Mark・K-Handle の型）に、その型が束縛された型の変数だけを使う（型が正しい）ことを前提として加える（01-12 は暗黙に前提する。置き換えの補題に要る）。項の型は継続の型を含まない（継続の型は項に書けない） |
| 初回リリース版の拡張: `Map`・`Set`・`Bytes`、型クラス | 段階 B2 | 段階 B2 で記す |
| 初回リリース版の拡張: 末尾呼び出しの保証の読み替え | 対象外 | |
| 確かめる性質 | 性質 2・3 は段階 A・B。性質 1 は対象外 | |

段階 A の表現は、2026-09-30 に定義と定理の言明を書いた時点のものである。証明の作業で扱いにくいと分かれば改める（[OPEN-069](../../../../../formal/reviews/open-issues.md#open-069)）。

### レビューと、見つかった誤りの扱い
```

## 資料 5: 01-12 の抜粋（型付け規則、型パラメータの組み込みの制約、ハンドラ、確かめる性質。変更後）

```markdown
### 型付け規則

【方針】型付けは次の二つの判断からなる。Γ は、変数と型の組の並びである。

- `Γ ⊢v V : A`: 値 V は型 A を持つ。
- `Γ ⊢c M : A ! ε`: 計算 M は、型 A の値を結果とし、実行するとエフェクト ε のうちのものを起こしうる。

#### 値

```text
(V-Var)   x : A ∈ Γ
          ───────────────
          Γ ⊢v x : A

(V-Const) ─────────────────
          Γ ⊢v c : type(c)

(V-Fun)   Σ に fn f[ᾱ; ρ̄](x̄:Ā) : B ! ε = M がある     θ = [T̄/ᾱ, Ē/ρ̄]
          ─────────────────────────────────────────────────────
          Γ ⊢v f[T̄; Ē] : ((Ā) → B ! ε)θ

(V-Prim)  b の型が ∀ᾱ ρ̄. (Ā) → B ! ε である     T̄ が b の型パラメータの制約を満たす     θ = [T̄/ᾱ, Ē/ρ̄]
          ─────────────────────────────────────────────────────
          Γ ⊢v b[T̄; Ē] : ((Ā) → B ! ε)θ

(V-Lam)   Γ, x1:A1, …, xn:An ⊢c M : B ! ε
          ─────────────────────────────────────────
          Γ ⊢v λ(x1:A1, …, xn:An). M : (Ā) → B ! ε

(V-Con)   C は D[ᾱ] の構成子で、引数の型は C̄ である     Γ ⊢v Vi : Ci[T̄/ᾱ]（各 i）
          ─────────────────────────────────────────────────────
          Γ ⊢v C[T̄](V̄) : D[T̄]

(V-List)  Γ ⊢v Vi : A（各 i）
          ─────────────────────────────
          Γ ⊢v [V1, …, Vn] : List[A]

(V-Sub)   Γ ⊢v V : A     A ≤ A'
          ─────────────────────
          Γ ⊢v V : A'
```

`type(c)` は定数の型である。組み込みの関数の型と、型パラメータの制約（組み込みの制約 `equality`・`key`、演算子の型の集まりのどれかであること）は[型システム](01-06-type-system.md)と[標準ライブラリ](../../../../../formal/reviews/03-interop/03-06-stdlib.md)で定める。

【決定】`A ≤ A'` は、A と A' が等しいか、A が `(Ā) → B ! ε`、A' が `(Ā) → B ! ε'` で `ε ⊆ ε'` であることを表す。`≤` は型の最も外側の関数の型のエフェクトにだけ働き、[型システム](01-06-type-system.md)の「エフェクトの包含」に当たる。V-Sub と後述の C-Sub は、値と計算の結果が現れるどの位置でも使えるので、[型システム](01-06-type-system.md)で包含の規則が働く位置（[ADR 0046](../../../../../formal/reviews/decisions/0046-effect-subsumption-at-all-flow-positions.md)）をすべて含む（[ADR 0081](../../../../../formal/reviews/decisions/0081-subsumption-on-computation-results.md)）。

#### 計算

```text
(C-Return) Γ ⊢v V : A
           ─────────────────────────
           Γ ⊢c return V : A ! { }

(C-Sub)    Γ ⊢c M : A ! ε     A ≤ A'     ε ⊆ ε'
           ─────────────────────────────────
           Γ ⊢c M : A' ! ε'

(C-Let)    Γ ⊢c M : A ! ε     Γ, x:A ⊢c N : B ! ε
           ──────────────────────────────────────
           Γ ⊢c let x ⇐ M in N : B ! ε

(C-App)    Γ ⊢v V : (A1, …, An) → B ! ε     Γ ⊢v Wi : Ai（各 i）
           ─────────────────────────────────────────────
           Γ ⊢c V(W1, …, Wn) : B ! ε

(C-If)     Γ ⊢v V : Boolean     Γ ⊢c M : A ! ε     Γ ⊢c N : A ! ε
           ──────────────────────────────────────────────
           Γ ⊢c if V then M else N : A ! ε

(C-Match)  Γ ⊢v V : A     ⊢p pi : A ⊣ Δi（各 i）     Γ, Δi ⊢c Mi : B ! ε（各 i）
           p1, …, pn は A について網羅的である
           ─────────────────────────────────────────────
           Γ ⊢c match V { p1 ⇒ M1 | … | pn ⇒ Mn } : B ! ε
```

C-Sub は、計算を実行するエフェクトを広げることに加えて、計算の結果の型を `≤` で広げる。例えば、次の `widen` の本体は、脱糖すると `make` の呼び出し `make[;]()` であり、C-App による結果の型は純粋な関数の型である。C-Sub でこれを `uses Console.Write` の関数の型に広げるので、`widen` の本体に宣言した戻り値の型が付く。呼び出しを `let` の左側に移さないので、末尾呼び出しも保たれる。

```text
function make() -> function() -> Unit
  return lambda() () end lambda
end function

function widen() -> (function() -> Unit uses Console.Write)
  return make()
end function
```

網羅的であることの定義は[代数的データ型とパターンマッチ](01-05-data-types.md)の「網羅性の検査」に従う。

#### パターン

`⊢p p : A ⊣ Δ` は、パターン p が型 A の値に照合し、変数と型の組の並び Δ を束縛することを表す。

```text
(P-Wild)  ⊢p _ : A ⊣ ·

(P-Var)   ⊢p x : A ⊣ x:A

(P-Const) c は Float の値でも IOError の値でもない
          ─────────────────────────────────────
          ⊢p c : type(c) ⊣ ·

(P-Con)   C は D[ᾱ] の構成子で、引数の型は C̄ である     ⊢p pi : Ci[T̄/ᾱ] ⊣ Δi（各 i）
          Δ1, …, Δn の変数はすべて異なる
          ─────────────────────────────────────────────
          ⊢p C(p1, …, pn) : D[T̄] ⊣ Δ1, …, Δn
```

#### 定義

定義 `fn f[ᾱ; ρ̄](x̄:Ā) : B ! ε = M` は、`x1:A1, …, xn:An ⊢c M : B ! ε` が成り立つときに型が付く。このとき、ᾱ と ρ̄ は、ほかの何とも等しくない型とエフェクトとして扱う。

実行時エラーを起こしうることは、型にもエフェクトにも現れない（[ADR 0146](../../../../../formal/reviews/decisions/0146-runtime-errors-not-in-types.md)）。

#### 型パラメータの組み込みの制約

【方針】初回リリース版では、定義の型パラメータに組み込みの制約を持たせる（[ADR 0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。実装の定義とメソッドの定義の型パラメータも同じく制約を持つ。

```text
定義        d ::= fn f[α1 : c1, …, αn : cn; ρ̄](x̄:Ā) : B ! ε = M     （ci は αi に付けた組み込みの制約の集まり。空でもよい）

(V-Fun)     Σ に fn f[ᾱ : c̄; ρ̄](x̄:Ā) : B ! ε = M がある     Δ ⊢ Ti : ci（各 i）     θ = [T̄/ᾱ, Ē/ρ̄]
            ─────────────────────────────────────────────
            Δ; Γ ⊢v f[T̄; Ē] : ((Ā) → B ! ε)θ
```

- Δ は、型付けの位置で有効な型パラメータと、その組み込みの制約の並びである。定義の本体は、その定義の型パラメータの並びを Δ として検査する。`handle` の節の本体は、節を囲む Δ に、操作の型パラメータを宣言の制約とともに加えて検査する（後述の「ハンドラ」）。ほかの規則は Δ をそのまま受け渡す。
- `Δ ⊢ T : c` は、型 T が制約 c を満たすことを表す。c が `equality` なら T は等値の型、`key` なら鍵の型である（[型システム](01-06-type-system.md)の「等値の型」「鍵の型（初回リリース版）」）。Δ の中で `equality` を付けた型パラメータは等値の型、`key` を付けた型パラメータは鍵の型として扱う。
- V-Prim の「T̄ が b の型パラメータの制約を満たす」は、Δ のもとで判定する。
- 組み込みの制約は辞書の引数を持たず、実行の規則は変わらない。

#### ハンドラ

【方針】操作の呼び出しとハンドラのために、値に操作と継続の場所を、計算に `handle` と `resume` を、継続に `handle` の枠と `drop` の枠を加える（[ADR 0118](../../../../../formal/reviews/decisions/0118-effect-handlers.md)）。

```text
値          V ::= … | op[T̄]                    （操作）
                  | κ                          （継続の場所）
型          A ::= … | Cont(B → A ! ε)          （継続の型。値として書けるのは節の中だけ）
計算        M ::= … | handle M with H
                  | resume κ V
節の並び    H ::= { op1(x̄1) k ⇒ N1 | … | opn(x̄n) k ⇒ Nn }
枠          F ::= … | handle □ with H | drop κ
ストアの中身      ::= … | cont(K) | used
```

- 操作 `op` は、エフェクト L の宣言が定める `∀ᾱ. (Ā) → B ! {L}` の型を持つ（V-Prim と同じく型付けする）。表層では、操作は L を宣言したモジュールの関数として書く（[ADR 0129](../../../../../formal/reviews/decisions/0129-effects-declared-in-modules.md)）が、脱糖した後は、ほかの関数と区別した op である。組み込みのエフェクトの操作は、外部に作用する操作（IO とネットワークの操作）を行う組み込みの関数 b である。`State` は操作を持たず、`State` を型に持つ組み込みの関数（可変のセルとタスクの集まりの関数、`Task.await`、リソースを解放する関数）は op ではない。
- 節 `op(x̄) k ⇒ N` の k は、節の中で継続を指す変数である。表層の `resume(v)` は `resume k ⟦v⟧` に移す。
- `handles(H, op)` は、H が op の節を持つことを表す。`handled(H)` は、一つ以上の操作を持ち、そのすべての操作の節を H が持つエフェクトの集合である。操作を持たない `State` は、どの H の `handled(H)` にも含まれない。

型付けは次のとおりである。継続の型の値（節の変数 k と、継続の場所 κ）は、`resume` の第一引数にだけ書ける。V-Var は継続の型を持つ変数に型を付けず、継続の場所は値として型が付かない（[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)。表層でも、節の継続は `resume(v)` の形でだけ使える）。V-Lam の前提と、`lazy M` の M の検査では、Γ から継続の型を持つ変数を除く。したがって、ラムダの本体と `lazy` の本体では `resume` に型が付かない（[ADR 0155](../../../../../formal/reviews/decisions/0155-resume-not-in-lazy.md)）。

```text
(C-Handle) Γ; R ⊢c M : T ! εM     εM ⊆ ε ∪ handled(H)
           H の各節 op(x̄) k ⇒ N について、op : ∀ᾱ. (Ā) → B ! {L}、ᾱ はほかの何とも等しくない型として
             Γ, x̄:Ā, k:Cont(B → T ! ε); R ⊢c N : T ! ε
           ─────────────────────────────────────────────
           Γ; R ⊢c handle M with H : T ! ε

(C-Resume) k : Cont(B → T ! ε) ∈ Γ     Γ ⊢v V : B
           ─────────────────────────────────────
           Γ; R ⊢c resume k V : T ! ε
```

実行の規則は次のとおりである。K1 ++ K2 は継続の連結、`releases(K)` は K の中の `release` の枠と `drop` の枠だけを、順序を保って並べた継続である。

```text
(E-Handle)   ⟨handle M with H, K, σ⟩                   →  ⟨M, (handle □ with H) :: K, σ⟩
(E-HRet)     ⟨return V, (handle □ with H) :: K, σ⟩      →  ⟨return V, K, σ⟩
(E-Op)       ⟨op[T̄](W̄), K1 ++ (handle □ with H) :: K2, σ⟩
                →  ⟨Nθ[W̄/x̄, κ/k], (drop κ) :: K2, σ[κ ↦ cont(K1 ++ (handle □ with H) :: [])]⟩
                ただし op(x̄) k ⇒ N は H の節、K1 の中の handle の枠はどれも op の節を持たない、κ は σ にない新しい場所、θ = [T̄/ᾱ]（ᾱ は op の型パラメータ。ADR 0297）
(E-Resume)   ⟨resume κ V, K, σ⟩       →  ⟨return V, K' ++ K, σ[κ ↦ used]⟩    σ(κ) = cont(K') のとき
(E-ResumeErr)⟨resume κ V, K, σ⟩       →  error(r_resume, K, σ)               σ(κ) = used のとき
(E-Drop)     ⟨return V, (drop κ) :: K, σ⟩  →  ⟨return V, K, σ⟩               σ(κ) = used のとき
(E-DropRel)  ⟨return V, (drop κ) :: K, σ⟩  →  ⟨return V, releases(K') ++ K, σ[κ ↦ used]⟩   σ(κ) = cont(K') のとき
```

- E-Op は、op を処理する最も内側の `handle` の枠を探し、そこまでの継続（その `handle` の枠を含む）を場所 κ に移して、節を実行する。`handle` の枠を継続に含めるので、再開した続きの中で呼んだ op も同じハンドラが処理する（深いハンドラ）。
- 組み込みの操作 b には、継続に b の節を持つ `handle` の枠がないときにだけ、E-IO・E-IOErr・E-Exit を使う。枠があるときは E-Op を使う。`State` を型に持つ組み込みの関数は操作ではないので、常にストアの規則を使う。
- r_resume は、継続の二度目の再開の実行時エラーの種類である。
- 節が `resume` を呼ばずに値で終わると、E-DropRel が、捨てる続きの中の `release` の枠を内側から順に実行する。捨てる続きの中に `drop κ'` の枠があれば（続きの中の節が、再開する前に外側のハンドラの操作を呼んだとき）、その枠に達したときに、同じ規則で κ' の続きの中の `release` の枠も実行する。したがって、入れ子に捨てた続きの中のリソースも、内側から順に一度ずつ解放する。`escape`、実行時エラーの状態、終了の状態が `drop κ` の枠を通るときも、σ(κ) = cont(K') なら、同じく `releases(K')` を継続の先頭に加え、κ を used にしてから進む。σ(κ) = used なら、`drop κ` の枠を取り除くだけである。
- `escape` と、実行時エラーの状態と終了の状態は、`handle` の枠を取り除いて進む（E-EscLet・E-ErrPop・E-ExitPop の「let の枠」「release の枠でない枠」に `handle` の枠を含める）。

### 確かめる性質

【方針】次の性質が成り立つように、本章と[型システム](01-06-type-system.md)を定める。どれも証明していない。形式検証の段階 1（[ロードマップ](../../../../../formal/reviews/00-overview/00-03-roadmap.md)）で、ランダムに生成したプログラムを使って反例を探す。反例が見つかれば、仕様の誤りとして直す。性質 2 と性質 3 は、形式検証の段階 2 で、本章の規則を Lean 4 で書き写して証明する。書き写しは本章の写しであり、本章を正とする（[形式意味論と検証](../../../../../formal/reviews/07-quality/07-04-formal-semantics.md)、[ADR 0293](../../../../../formal/reviews/decisions/0293-formal-verification-stage-2-alongside-first-release.md)、[ADR 0295](../../../../../formal/reviews/decisions/0295-core-calculus-chapter-normative-over-formalization.md)）。

1. 脱糖の型の保存: [型システム](01-06-type-system.md)の型検査を通ったプログラムを脱糖すると、すべての定義に型が付く。
2. 進行と保存: 型が付いた状態 `⟨M, K⟩` は、`⟨return V, []⟩` であるか、遷移できる。遷移した先の状態も型が付くか、`error(r)` である。IO の応答は、関数の戻り値の型の値であるとする。
3. エフェクトの健全性: `· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, []⟩` からの実行は IO の事象を伴う遷移をしない。

初回リリース版の拡張でも、同じ三つの性質を確かめる。性質 3 は、「`· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, [], ∅⟩` からの実行は IO の事象を伴う遷移をせず、どの `handle` の枠も処理しない操作を呼ばない」と読み替える。性質 2 の状態の型付けでは、継続の型付けに、継続の先頭で許すエフェクトと、継続の末尾で許すエフェクトを加え、組み込みでない操作の呼び出しには、それを処理する `handle` の枠が継続にあることを確かめる。初回リリース版の性質 2 は、「型が付いた状態は、`⟨return V, [], σ⟩`、`error(r̄, [], σ)`、`exit(n, r̄, [], σ)` のいずれかであるか、遷移できる。遷移した先の状態も型が付く」と読み替える。初回リリース版の状態の型付けは、この節の最後に示す。

性質 2 の「型が付いた状態」は、継続の型付けを使って次のように定める。`⊢k K : A ⇒ B` は、継続 K が型 A の値を受け取り、最後に型 B の値を結果とすることを表す。

```text
(K-Empty) ⊢k [] : A ⇒ A

(K-Let)   x:A ⊢c N : C ! ε     ⊢k K : C ⇒ B
          ─────────────────────────────────────
          ⊢k (let x ⇐ □ in N) :: K : A ⇒ B
```

状態 `⟨M, K⟩` に型が付くとは、`· ⊢c M : A ! ε` と `⊢k K : A ⇒ B` が成り立つ型 A、B とエフェクト ε があることである。

【方針】初回リリース版の状態の型付けでは、ストアの型付け Ψ（場所から型への対応）と、最も内側の関数の戻り値の型 R を加える。R は、型か、`escape` を許さないことを表す `none` である。値の判断に Ψ を加え、`Ψ(ℓ) = A` のとき `ℓ : A` とする（可変のセルと明示遅延の場所。継続の場所は値として型が付かず、C-ResumeL の第一引数にだけ書ける）。計算の判断は `Γ; R ⊢c M : A ! ε` とし、`R = none` のときは `escape` に型が付かない。継続の場所 κ には、Ψ が継続の型と R の組 `Ψ(κ) = (Cont(B → T ! ε), R_κ)` を対応させる。R_κ は、κ を作った節の R である。

継続の判断は `R; ε ⊢k K : A ⇒ B ! ε0` とする。K は型 A の値を受け取り、最後に型 B の値を結果とする。R は K の先頭で実行する計算に許す `escape` の型、ε は K の先頭で実行する計算に許すエフェクト、ε0 は K の末尾（空の継続）で許すエフェクトである。

```text
(C-Use)     Γ ⊢v V : O_r（O_r はリソースの型）     Γ; R ⊢c M : B ! ε     rel(O_r) ⊆ ε
            ─────────────────────────────────────────────
            Γ; R ⊢c use V in M : B ! ε

(C-ResumeL) Ψ(κ) = (Cont(B → T ! ε), R)     Γ ⊢v V : B
            ─────────────────────────────────────
            Γ; R ⊢c resume κ V : T ! ε

(K-Empty)   ε ⊆ ε0
            ─────────────────────────────
            R; ε ⊢k [] : A ⇒ A ! ε0

(K-Let)     x:A; R ⊢c N : C ! ε1     ε1 ⊆ ε     R; ε ⊢k K : C ⇒ B ! ε0
            ─────────────────────────────────────
            R; ε ⊢k (let x ⇐ □ in N) :: K : A ⇒ B ! ε0

(K-Mark)    R'; ε ⊢k K : A ⇒ B ! ε0
            ─────────────────────────────
            A; ε ⊢k mark :: K : A ⇒ B ! ε0

(K-Update)  Ψ(ℓ) = Lazy[A]     R; ε ⊢k K : A ⇒ B ! ε0
            ─────────────────────────────────────
            none; ε ⊢k (update ℓ □) :: K : A ⇒ B ! ε0

(K-Release) · ⊢v V : O_r（O_r はリソースの型）     rel(O_r) ⊆ ε     R; ε ⊢k K : A ⇒ B ! ε0
            ─────────────────────────────────────
            R; ε ⊢k (release V) :: K : A ⇒ B ! ε0

(K-Handle)  R; ε ⊢k K : T ⇒ B ! ε0     εc ⊆ ε
            H の各節 op(x̄) k ⇒ N について、op : ∀ᾱ. (Ā) → B' ! {L}、ᾱ はほかの何とも等しくない型として
              x̄:Ā, k:Cont(B' → T ! εc); R ⊢c N : T ! εc
            ─────────────────────────────────────
            R; εc ∪ handled(H) ⊢k (handle □ with H) :: K : T ⇒ B ! ε0

(K-Drop)    Ψ(κ) = (Cont(B' → A' ! ε'), R')     State ∈ ε' ならば State ∈ ε     R; ε ⊢k K : A ⇒ B ! ε0
            ─────────────────────────────────────
            R; ε ⊢k (drop κ) :: K : A ⇒ B ! ε0

(K-Sub)     R; ε ⊢k K : A' ⇒ B ! ε0     A ≤ A'
            ─────────────────────────────────────
            R; ε ⊢k K : A ⇒ B ! ε0
```

- C-Use の `rel(O_r)` は、リソースの型 O_r の解放のエフェクトであり、初回リリース版ではどのリソースの型でも `{State}` である。
- C-ResumeL は、節の変数 k を場所 κ に置き換えた後の `resume` の型付けである。`resume` の R は、κ を作った節の R と等しい。`resume` はラムダと `lazy` の本体の中に書けないので、節の中の `resume` はこの条件を満たす。
- K-Mark は、関数の本体の結果の型 A を、その本体の中の `escape` の型にする。 K-Sub は、継続が受け取る型を広げる。`handle` の式の型が、それを本体とする関数の戻り値の型より狭いとき、E-Resume の後の継続に型を付けるのに要る（[ADR 0301](../../../../../formal/reviews/decisions/0301-subsumption-on-continuation-input.md)）。K-Update は、`thunk` の本体の実行の上に `escape` を許さない。
- K-Handle は、`handle` の枠の上で、H が処理するエフェクトを許す。節は、枠の下の継続と同じ R で、枠の下の継続が許すエフェクトに含まれるエフェクト εc で検査する。節の本体は枠の下の継続の中で実行されるので、εc が ε に含まれれば足りる。εc と ε を等しくしないのは、E-Resume で捕まえた継続を、より広いエフェクトを許す継続の上につなぐためである（[ADR 0302](../../../../../formal/reviews/decisions/0302-k-handle-clause-effect-within-below.md)）。K-Drop の `drop` の枠は、受け取った値をそのまま渡すので、受け取る型 A は κ の答えの型と等しくなくてよい。E-Op が積んだ `drop` の枠では、A は κ の答えの型と等しいが、`releases(K')` で別の継続の先頭に移した `drop` の枠では、その継続を流れる値の型を受け取る。
- `drop κ` の枠が E-DropRel で加える `releases(K')` は、K' の中の `release` の枠と `drop` の枠である。解放のエフェクト `State` は、どの `handled(H)` にも含まれない。継続の枠が先頭で許すエフェクトは、下の枠のものに K-Handle が `handled(H)` を加えたものなので、ある枠が `State` を許していれば、その下のすべての枠も `State` を許している。K' の中の `release` の枠が `State` を許していれば、K' の末尾（κ の継続の型のエフェクト ε'）も `State` を許している。K-Drop の前提「State ∈ ε' ならば State ∈ ε」により、`drop` の枠の位置でも `State` を許しているので、`releases(K')` を `drop` の枠の位置に加えても型が付く。E-Op が積む `drop κ` の枠では、ε' は `handle` の式のエフェクトであり、`drop` の枠の位置のエフェクトと等しいので、この前提は成り立つ。前提がないと、この上下関係を持たないストアと `drop` の枠の組み合わせにも型が付き、保存が破れる（[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）。
- ストア σ が Ψ のもとで型が付くとは、Ψ が型を与える場所に σ の中身があり（σ と Ψ の場所が一致する。[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）、σ のすべての場所について次が成り立つことである。σ(ℓ) = V なら `Ψ(ℓ) = Reference[A]` かつ `· ⊢v V : A`。σ(ℓ) = thunk(M) なら `Ψ(ℓ) = Lazy[A]` かつ `·; none ⊢c M : A ! { }`。σ(ℓ) = done(V) なら `Ψ(ℓ) = Lazy[A]` かつ `· ⊢v V : A`。σ(κ) = cont(K') なら `Ψ(κ) = (Cont(B → T ! ε), R_κ)` であり、K' の末尾の `handle` の枠に K-Handle を R_κ で使う導出で、ある R'、ε' について `R'; ε' ⊢k K' : B ⇒ T ! ε` が成り立つ。σ(κ) = used なら、Ψ(κ) は継続の型と R の組である。
- 状態 `⟨M, K, σ⟩` に型が付くとは、σ が Ψ のもとで型が付き、`·; R ⊢c M : A ! ε1`、`ε1 ⊆ ε`、`R; ε ⊢k K : A ⇒ B ! Eb` が成り立つ Ψ、R、A、B、ε、ε1 があることである。Eb は組み込みのエフェクトの名前の集合である。`error(r̄, K, σ)` と `exit(n, r̄, K, σ)` に型が付くとは、σ が Ψ のもとで型が付き、`R; ε ⊢k K : A ⇒ B ! Eb` が成り立つ Ψ、R、A、B、ε があることである。 いずれの状態の型付けでも、継続の判断は、末尾の K-Empty を `R = none` で使う導出で満たす。実行は `⟨main[;](), [], ∅⟩` から始まり、関数の本体の `escape` は関数の呼び出しが積んだ `mark` の枠で止まるので、実際に到達する状態はこの条件を満たす。この条件がないと、`⟨escape V, [], σ⟩` に型が付き、進行が成り立たない（[ADR 0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md)）。
- 継続の末尾で許すエフェクトを Eb とするので、型が付いた状態で呼ぶ組み込みでない操作 op のエフェクト L は、継続のどこかの `handle` の枠が K-Handle で許している。その枠の H は、L のすべての操作の節を持つので、op の節を持つ。したがって、E-Op の条件を満たす `handle` の枠がある。
- 並行処理のタスク（[並行処理](01-11-concurrency.md)）と、タスクが引き継いだハンドラ（[ADR 0151](../../../../../formal/reviews/decisions/0151-inherited-handlers-tail-resume-only.md)）は、本章の状態の型付けに含めない。

## 未決事項

- [OPEN-068](../../../../../formal/reviews/open-issues.md#open-068): 形式化した定義を本章の規則の正とするか
```
