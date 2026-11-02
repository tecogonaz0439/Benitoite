# RV-L20.e: L20 群 E（L20.61〜.70）の独立レビュー

2026-11-02。対象はブランチ `m014/l20.e` の未コミットの作業木、基準 `f5a9edab`。依頼文 `L20.e-prompt.md`、`l20/e/` の結果、`l20/detail.md` の E1・E2、L20.61〜.70、S04、O003 を読み、新規の Lean 6ファイルを全文読んだ。補助の入力は scratchpad に置き、既存のファイルを変えていない。

## 総合判定

**条件付き可**。重 0 件、中 2 件、軽 7 件。

Lean の本体（`q_mono`・`normConts`・`Ctx.Regular`・`local_zero`・`withReturn`・`subst_congr`）に誤りは見つからず、言明はそのまま受け入れてよい。条件は記録と例の補充である。中1は閉鎖表の読者の照合の対象の欠け、中2は O167 が求める循環の受理と拒否の対照の欠けである。どちらも定理の言明、型付けの規則、公理に影響しない。

## 所見

### 中

#### 中1: 閉鎖表の「全件照合」の対象から、旧 withReturn と hide の3宣言が落ちている（読めば確定、実行でも確認）

- 場所: `l20/e/readers.lean` 7〜9行、`l20/e/closure-table.md` 11行・15行・50〜72行、`l20/e/results.md` 58行。
- 問題点1: `readers.lean` の対象は `startsWith "Benitoite.Release."` で選ぶ。旧の4定理 `Benitoite.Surface.HasTypeCQ.withReturn` など（`Surface/Lemmas/ReturnTry.lean`）は namespace が `Surface` なので対象に入らない。読者の表には `withReturn` の行がない。72行は新しい4入口だけを述べる。O003 は withReturn の全読者を要求しており、計画の S04 も旧 ReturnTry を名指しする。
- 問題点2: 接尾辞の一覧に `StoreTy.WF.hide`・`StoreTy.preserves_hide`・`StoreTy.hide_extends` がない。閉鎖表11行はこの3宣言を hide の本番の入口に挙げるが、読者の表の `hide` の行は `SubstOk.hide` と同じ末尾の名前の宣言の読者だけである。11行の使用先は CapturedFacts・LazyPreservation・DependentBeta と置換を挙げる。実際の `StoreTy.WF.hide` の読者は、ほかに Narrowing 13件、TypingShift 14件、TypeShiftTyping 10件、TypeSubstTyping 5件、TypeSubstCallSites 2件、TypeSubstGateExamples 2件、ReferenceStore 2件、HandlerOperation 1件、LazyStore 1件ある（補助の照合）。
- 検証: 同じ方法で接頭辞を `Benitoite.` と `_private.Benitoite.` に広げて環境を調べた。Surface の `*.withReturn` の読者は `Surface.Lemmas.ReturnTry` の `HasTypeCQ.withReturn` への参照1件である。
- 影響: 「全読者」の主張が過大である。証明には影響しない。残りの15行は環境と完全に一致する（後述）。
- 修正案: `readers.lean` の条件を `Benitoite.` へ広げ、対象の private も含める。接尾辞に上の3宣言を足す。読者の表に `withReturn` と `StoreTy.*hide*` の行を足し、件数（161・1509・1142）を更新する。11行の使用先を全モジュールへ直す。

#### 中2: 循環・前方依存の拒否に具体例がなく、O167 の受理との対照がない（読めば確定）

- 場所: `formal/Benitoite/Release/Refinement/ContextRegularity.lean` 92〜98行、`closure-table.md` 31行、`results.md` 66行。
- 問題点: 計画 L20.65 は `reject_forward_or_cyclic_context` を「O167 拒否例」と呼び、O167 は「循環」を含む制限を「受理と拒否の対照」で保持するよう求める。本番の定理は前提 `Depends` を仮定する一般定理であり、前提を満たす文脈の例が本番にない。`Ordered` を読む宣言は `Context/WF.lean` と本ファイルだけで、例のファイルにもない。`reject_unsorted_tapp_image` のように具体の値を持つ拒否例と揃っていない。
- 確認: 定理そのものは本物である。補助の入力で、下の例により前提を満たす文脈があることを確かめた。
- 修正案: `ContextRegularity.lean` か例のファイルに、次の拒否と受理の対照を置く（どちらも補助の入力で通った。`simp` の引数は現在の定義に合わせて確認済み）。循環は位置の順序の違反に帰着するので、自己参照を代表例とする。

```lean
def selfRef : Ty := .refined (.base .integer) (.eq (.var 0) (.var 1))
def okTy : Ty := .base .integer
def bwdRef : Ty := .refined (.base .integer) (.eq (.var 0) (.var 2))
def fwd : Ctx := [some selfRef]
def back : Ctx := [some bwdRef, some okTy]

theorem fwd_dep : fwd.Depends 0 0 := by
  refine ⟨selfRef, rfl, ?_⟩
  simp [selfRef, fwd, Ctx.without, Ty.References, Pred.References, Pred.VarsIn, Term.VarsIn,
    Ctx.Readable, Ordinary, Ty.core]
theorem fwd_rejected : ¬ fwd.Ordered :=
  reject_forward_or_cyclic_context (.inl ⟨0, 0, fwd_dep, Nat.le_refl _⟩)
theorem back_ordered : back.Ordered := by
  intro i a hi
  cases i with
  | zero =>
    cases hi
    simp [bwdRef, back, Ctx.outer, Ty.References, Pred.References, Pred.VarsIn, Term.VarsIn,
      Ctx.Readable, Ordinary, Ty.core, okTy]
  | succ i =>
    cases i with
    | zero => cases hi; simp [okTy, Ty.References]
    | succ i => simp [back] at hi
```

### 軽

#### 軽1: 閉鎖表の rename・hide の行に実際の入力が欠ける（読めば確定）

- 場所: `closure-table.md` 11行・12行。
- 問題点: `HasTypeVQ.subst`・`HasTypeCQ.subst` は `Builtins.SubstitutionAssumptions P B` と `store.WF` を要る。`SubstOk.hide` と `CaptureOk.store` は `Builtins.ValueAssumptions P B` を要る。store の行には書いてあるが、rename と hide の行にはない。O003 の「署名・供給元」の欄として欠けている。
- 修正案: 二行の「入力の供給元」に上の前提を足す。

#### 軽2: 「閉じた実行データ」の分離が閉鎖表にない（読めば確定）

- 場所: `closure-table.md` 10〜13行、計画 L20.64。
- 問題点: 計画は hideBuilders・R の変更・閉じた実行データを分けると書く。前の二つは行があるが、三つ目を受ける記述がない。
- 確認: `CaptureOk P B (hideBuilders Ψ) R' (hideConts Γ) Φ cap` は `(h.hideConts_any).store hA hw (StoreTy.preserves_hide _)` の一行で作れる（補助の入力で確認）。証明の欠けはない。
- 修正案: 閉鎖表に、閉じた `cap` は保持し、この合成で移すことを一行書く。

#### 軽3: normConts の移送先の入口に、Γ の導出からの経路の補題がない（読めば確定、実行で確認）

- 場所: `CaptureTransport.lean` 126〜138行、計画 L20.64・L20.68。
- 問題点: `capture_normConts_*_annotation` の前提は `normConts Γ` での導出である。`Γ` の導出から移す `Ctx.NormEq.comp` の `hc`（継続の位置の対応）を与える補題が本番にない。`normConts` の読者は `CaptureTransport` の外に一つもない。計画の「全使用先で確認」は、現時点の使用先が二つの系だけである。
- 確認: 下の3件は補助の入力で通った。L20.64 の形は後の群で使える。F 群・`K_Handle` は `CaptureOk.normConts` をそのまま適用できる。

```lean
theorem normConts_cont {Γ : Ctx} {i : Nat} {b t : Ty} {e : Eff}
    (hi : Γ[i]? = some (some (Ty.cont b t e))) :
    ∃ b' t' e', (normConts Γ)[i]? = some (some (Ty.cont b' t' e')) :=
  ⟨b.norm, t.norm, Eff.norm e, by simp [normConts, hi, normContTy]⟩
-- (normConts_normEq Γ).comp (fun _ _ _ _ hi => normConts_cont hi) hA hw hm
--   は capture_normConts_comp_annotation の入力になり、結論は cap.closeTy a.norm
-- hideConts (normConts Γ) = normConts (hideConts Γ) も成り立つ
```

- 修正案: `normConts_cont` を本番に足す。使用先が F 群で決まるなら、その依頼文へ申し送るだけでもよい。

#### 軽4: SubstAgree の範囲が計画の文と違い、「計画からのずれ」に書かれていない（読めば確定）

- 場所: `SubstAgreement.lean` 8〜12行、計画 S04、`results.md` 62〜64行。
- 問題点: 計画は「実際に参照する some の型の位置」と書くが、定義は Γ の全 some の位置である。局所も全 some の位置である。旧 `Irrelevant` の条件と同じなので後続の支障は見えず、`SubstAgree [none] σ τ` のように None の位置の差も許す（補助の入力で確認）。ただし前提は計画の文より強い。closure-table.md と 01-12 は実際の定義のとおりに書いている。
- 修正案: `results.md` の「計画からのずれ」に一文足す。

#### 軽5: OpSig.regular_context の二つの入力の供給元が未確定である（推測）

- 場所: `ContextRegularity.lean` 78〜82行、`closure-table.md` 29行。
- 問題点: `hc` の `sg.continuation t e` の Annotation は開いた `e` の形成を含む。`K_Handle` が持つのは `Ty.Annotation P [] Γ ts` と閉じた done の Annotation である。`OpSig.WF` も局所の WF だけで、`hp` の Sorted・Declared を直接は供給しない。`OpSig.regular_context` に読者はまだない。定理は条件付きで正しく、closure-table.md は K_Handle が別経路であることを明記しており、過大な主張ではない。RV-L20.d 中2の問題点3と同じ論点である。
- 修正案: O053 の残りとして、`hp`・`hc` の供給が L70/R10b のソースの照合に依存することを閉鎖表に書く。

#### 軽6: 機械生成の束縛名と optParam が公開の言明に残る（読めば確定）

- 場所: `ContextTransport.lean`・`LocalTyping.lean` の全定理。
- 問題点: `z0`〜`z11`・`x0`〜`x28` の名前と `{z9 : optParam LocalCtx []}` が署名に現れ、S04 の `{P B Ψ Q C Γ Φ R m a e L}` より読みにくい。呼出しは支障がない（`h.withReturn rfl rfl R`、`h.local_zero …` を補助の入力で確認）。
- 修正案: 公開の入口の署名だけ計画の名前へ直す。`optParam` は `L : LocalCtx` に書き換える。後の群へ回してもよい。

#### 軽7: 「有限環境」が既存の用例と用語集にない（読めば確定）

- 場所: `01-12-core-calculus.md` の追加段落（`CaptureOk.normConts` の文）、`07-04-formal-semantics.md` の追加段落。
- 問題点: 基準の設計書・`plan.md`・`l20/detail.md` に「有限環境」の用例がなく、用語集にもない。依頼文の語でもあるが、設計書には「捕捉」で足りる。「依存閉包」「保持値」「戻り先」「経路条件」は 01-12 に既存の用例がある。
- 修正案: 「同じ捕捉（`cap`）・戻り先・経路条件」と書く。

## 観点ごとの確認

### 1. q_mono

- 11入口はすべて `∀ i, Q i → Q' i` の向きで、固定の3入口は Qempty を保つ恒等である。`NoFail Q e := e.fails = [] ∧ ∀ i, e.test (.rho i) = true → Q i` なので Q について単調であり、`RowTransport`・`Admissible` 系の証明も第2成分だけを写す。
- `AtCallAdmissible.q_mono` は `bases` の全 `some`・`pattern`・`input` の三つの値を写す。他の欄は Q を持たない。C_CheckAt は入口を実際に使い、C_Handle_Fail は `NoFail.q_mono` を使う。
- `mutual` の全構成子を読んだ。内訳は V29・Vs2・Each2・CQ24・TelArgs2・TelBody2・Capture1・DepClosure1・Checked2・At1・Arms3・Clauses2・Failure1・Image4 で、合計76である。

### 2. 捕捉の再構成

- `CaptureOk.normConts` は前提が `h` だけで、結論の `cap`・`R`・`Φ` は同じである。8欄を全部作り直す。`builderBody_image_norm` は `ImageOk` の4場合を全部扱い、`ν`・`Δ`・`Ξ`・`R0` を保つ。
- hide は `CaptureOk.hideConts_any`、R の変更は同じ定理（隠した文脈に限る）、store は `CaptureOk.store` で覆う。任意の NormEq からの移送は主張していない。
- 補助の入力で、Γ の導出から閉じた Annotation まで通した（軽3）。`hideConts` は `t.core` を見て refined の下の cont も隠すが、`normContTy` は最上位だけを写す。この違いの下でも可換である。

### 3. 正則性

6操作の定理を全部確かめた。`shiftE`・`OpSig.context`・`failureContext` は本ファイル、`hideConts`・`bindParams` は Context.Declarations、`extendNone` は Context.WF にある。失敗節の `he` は `HasFailureClause.one` が直接持つ。拒否の負例は本物である（中2）。

### 4. local_zero・withReturn

各4入口とも `ValueAssumptions` を足していない。`withReturn` は旧 ReturnTry と同じ等号の前提の形で、S04 の予定の形と同値である。guarded のガードは `none` のまま、Lazy は元の証拠を保つ。`Shift 0 0 [] [none,none]` と `Shift 0 0 [none,none] []` の両方向で `local_zero` を実際に適用でき、G10 の k=0 の橋に使える。

### 5. subst_congr

- 10成分の内訳は V29・Vs2・Each2・CQ24・TelArgs2・TelBody2・At1・Arms3・Clauses2・Failure1 で68である。定理は導出の帰納なので、型付けのない `Val`・`Comp` の形は対象外になる。`Val` と `Comp` の全構文形に対応する規則がある（`loc` は V_LocRef・V_LocLazy と C_ResumeL、`resume` は4規則）。
- snapshot は `Term.VarsIn` が `varsInSlots` で list・set・data・map の全 some slot を読み、`Pred.varsIn_mono` と `Pred.bind_congr` がそれを使う。None の slot は読まない。
- 関数 view の支持条件は L20.117 の担当である。本判断の規則は `fnView` を読まず、`subst_congr` に落とし穴はない。
- 前提は空でない。`SubstAgree [none]` は異なる置換でも成り立つ。C_External は `had.types_nil` で型引数が空であることを使う。V_Closure などの `rfl` は閉じた値に依存し、カーネルが受理した。

### 6. 閉鎖表

- `readers.lean` を再実行し、161対象・1509組・1142固有読者を再現した。表の15行のモジュール集合を環境の出力と機械的に比べ、差は0件である。欠けは対象の選び方にある（中1）。
- 閉鎖表が挙げる宣言は全部環境にある（`#check` で確認）。`resolveLocals_builderSubst`・`builderBody_resolve` は `Val.`・`Comp.` の接頭辞付きである。
- O003 全体を閉じたとは書いていない。L20.110〜.116・G10・L70 の残りは 39〜48行に記録され、過大な主張ではない。過大なのは読者の全件の主張だけである。

### 7. L20.66・.67 の控除

S01 の motive（Vs は TypeAnnotations、Each は `vs ≠ []` の下、Arms は末尾の b、TelArgs は done）と `open_*_annotation` の言明は一致する。A2 の定理は計画の予定より前提が少ない。控除の算術（2単位で1時間〜2時間30分、残り4時間15分〜7時間20分）も正しい。

### 8. 字面と仮定

- `git diff f5a9edab` の formal の変更は `Benitoite.lean` の import 6行（と空行）だけで、既存の定義・主な言明・旧 `Release` の変更はない。
- `lake build` は 807 ジョブで成功し、既定の8ターゲットを保つ。6ファイルに `sorry`・`axiom`・`native_decide`・`unsafe`・`implemented_by`・`set_option`・`instance`・属性はない。
- `axioms.lean` を再実行し、690件、依存なし245件、`sorryAx` 0件、公理は `propext`・`Classical.choice`・`Quot.sound` の部分集合だけであることを確かめた。
- `interfaces.lean` の印字を確かめ、`Qempty` は `Benitoite.Release.Qempty` に解決している（自動束縛ではない）。`inputs.json` の15件のハッシュと大きさは現在のファイルと一致する。宣言の件数の内訳（定義5・定理90）も読んだ数と一致する。

### 9. 設計書の写しと規約

- 手元の絶対パス、docs/todo へのリンク、`work/` を出どころとする参照、「費用」の語、変更の経緯の文はない。100 KB を超えるファイルはない。plan.md・l20/detail.md・レビューの記録・処理系の変更もない。
- 写しの11判断・76・10判断・6操作の記述は Lean と一致する。造語は軽7の1語である。

## 推測と確定の区別

- 実行で再現したもの: 中1の対象の欠け、中2の補充の例、軽2・軽3・軽4の確認。
- 推測: 軽5の供給の可否だけである。

## 取りまとめの追記

中2件と軽7件を群 E の再開で処置した。O003 の全体の閉鎖は L20.110〜.116 と L70 に残る。
