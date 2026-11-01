# RV-L20.bc: L20 群 B・C（L20.28〜.38）の独立レビュー

2026-11-02。対象はブランチ `m014/l20.bc` の未コミットの作業木、基準 `da004946`。依頼文 `work/m014/L20.bc-prompt.md` の九つの観点を、実装側の判定を前提にせず Lean を読んで確かめた。ファイルと git の状態は変えていない。補助の入力は作業用の一時領域に置き、`<repo>/formal` で `lake env lean -M 12288` により検査した。

## 総合判定

**条件付き可**。重 0 件、中 1 件、軽 11 件。

条件は中1の修正である。`HasTypeCQ.method_body_input` の結論が、実装 `id` と呼出しの類 `cl` を結ばず、E_Meth の遷移先へ接続できない。修正は結論の強化だけで足り、定義・型付け規則・主な言明は変わらない。導出に要る補題は補助の入力で証明した。ほかの項目（sig_scoped の強さ、型置換の交換、パターンの反映、31位置、公理、既定ビルド）に、再設計を要する問題はなかった。

## 所見

### 読めば確定する誤り

#### 中1: `method_body_input` の結論が実装の類と呼出しの類を結ばない

- 場所: `<repo>/formal/Benitoite/Release/Refinement/TypeSubstCalls.lean` 610・625・658・682 行（`HasTypeVQ.dict_callInputs`、`method_body_input`、`method_input_aux`、`HasTypeCQ.method_body_input`）。
- 問題点: `HasTypeCQ.method_body_input` の結論は `∃ id cl cd ms, P.impls i = some id ∧ P.classes cl = some cd ∧ cd.methods name = some ms ∧ TypeSubstInput …` である。`id.cls = cl` を含まない。E_Meth（`Semantics.lean` 133 行）は `P.classes id.cls = some cd'`・`cd'.methods m = some ms'` の `ms'` で本体を選び、`ImplDecl.WellTyped.method_body` もこの `ms'` の本体を返す。結論の `ms` は別の類の署名であり得るので、返された入力を本体へ適用できない。存在量化で `cl` を隠しているため、呼出し側が別の補題で `id.cls` を調べても、この `ms` へは戻れない。
- 同じ理由で、呼出しの `τ` と実装の像の関係（`τ.norm = (id.target.subst us []).norm`）も出力にない。E_Meth の結果型は `instantiatedTel ms.tel (ss ++ [τ]) es` を読み、本体の型は `id.target` を先に代入した依存列を読むので、両者の接続にこの等号が要る。
- 確認: `LeQ` に dict の規則はないが、`refl`・`convert`・`trans` と篩の三規則を経ても `a.norm.core` は同じ dict のままである。これを使い、補助の入力で次を公理3種だけで証明した。

```lean
theorem dict_call_link {P B Ψ Q C Γ Φ i ts vs cl τ}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.dict i ts vs) (.dict cl τ)) :
    ∃ id, P.impls i = some id ∧ id.cls = cl ∧ τ.norm = (id.target.subst ts []).norm
```

- 修正案: `dict_callInputs` の結論へ `a.norm.core = .dict id.cls (id.target.subst ts []).norm` を足し、`method_body_input` の二つの結論へ `id.cls = cl ∧ τ.norm = (id.target.subst us []).norm` を足す。`HasTypeCQ.method_body_input` は `cl := id.cls` に固定できる。E_Meth の捕捉が読む辞書引数 `vs` の `HasTypeVsQ … vs (id.dictTys.map (Ty.subst us []))` も、同じ逆転で返すとよい。実表・定義の変更は要らない。L20.37 の対象であり、群 D へ送らずこの群で閉じる。`signatures.md`・`results.md`・01-12・07-04 の該当の文も合わせる。

#### 軽1: 07-04 の `ProgramWellFormed` の説明が移動前のまま

- 場所: `<repo>/docs/design/07-quality/07-04-formal-semantics.md` 128 行。
- 問題点: `ProgramWellFormed` が「四名前空間の `SourceScoped`」を定義すると書くが、定義は `SourceScope` へ移った。同じ章の 148 行と矛盾する。
- 修正案: 128 行から `SourceScoped` を除くか、`SourceScope` の定義を読むと書く。

#### 軽2: 07-04 の Lean と写しの対応表に新しい7モジュールがない

- 場所: 同 801〜825 行の表（810 行の Legacy の行、814 行の型置換の行など）。
- 問題点: SourceScope・PrimitiveScoped・RangeFormation・LegacyDeclarationInputs・TypeValueExchange・PatternTypeSubst・TypeSubstBindings の行がない。本文 148〜152 行には説明があるが、この表は各モジュールと 01-12 の節の対応を示す。
- 修正案: 既存の行へ足すか、行を加える。

#### 軽3: 07-04 の CoreAssumptions の【決定】の列挙に宣言の形成がない

- 場所: 同 160 行。
- 問題点: 「PathBases とストアの項目、組み込みの操作表に関する欄を持つ」と列挙し、`sig_scoped` の宣言の形成を含まない。164 行の表とも不揃いである。
- 修正案: 「宣言の形成」を列挙に足す。

#### 軽4: `PrimSig.Scoped` は制約を読まない

- 場所: `<repo>/docs/design/01-spec/01-12-core-calculus.md` 3266 行「同じ s.tparams の制約と kind を読み」、`改造/l20/bc/results.md` の L20.28 の行「kind/制約」。
- 問題点: `Ty.HasKind` は `TypeCtx.kinds s.tparams`、`Tel.Declared` も kind だけを読み、`Declared.lean` に `constraints` の参照はない。`Scoped` の欄は制約を検査しない。S09 の「kind/制約の長さと宣言表の一致」は、同じ `s.tparams` から両方を読むので自明に成り立つが、「制約を読む」は定義と合わない。
- 修正案: 「kind を読み」とし、制約は同じ列の別の射影であり Scoped の検査対象でないと書く。

#### 軽5: 旧 sig_scoped との差の記録が足りない

- 場所: 07-04 164 行、`results.md`「sig_scoped と停止条件」、01-12 3298 行。
- 問題点: 旧 `PrimSig.Scoped` の引数の位置の条件は全項目に掛かるが、新は `s.opEff ≠ none` の項目だけに掛かる。さらに最上位の `.scoped` を対象の位置に加えた。results は「旧 TargetRangesOnly … を実際の opSigAt の読者へ供給する」とだけ書き、緩めた点を差として示していない。
- 判断: 緩和自体は正しい。`instTarget` の読者は `opSigAt` だけで `opEff` を経由し、新 V_Prim は `Tel.instR` で全位置を具体化する。S09 の「実読者で必要な部分だけ射影」にも合う。設計書と results の記述だけの問題である。
- 修正案: 07-04 の表の行に「非操作の項目には引数の位置の条件を課さない。V_Prim が依存列全体を具体化するためである」と書く。

#### 軽6: 定義を移した後の文書コメントが別の宣言に付いている

- 場所: `<repo>/formal/Benitoite/Release/Refinement/Context/Declarations.lean` 175 行。
- 問題点: `Ty.TargetWF` の説明だった `/-- 範囲変数は操作の対象の最上位にあり、… -/` が、定理 `Ty.TargetWF.instTarget` に付いた。`PrimitiveScoped.lean` の定義には説明がない。
- 修正案: コメントを `PrimitiveScoped.lean` の `Ty.TargetWF` へ移す。

#### 軽7: `reject_unsorted_tapp_image` の言明は源の形成を含まない

- 場所: `<repo>/formal/Benitoite/Release/Refinement/TypeSubstFormation.lean` 991 行、01-12 の「tapp の形成を保存できない」の文。
- 問題点: 負例自体は本物である。`image` は WF 0 0 0 を満たし、像の `Sorted` が偽で、Annotation と constructor kind も全 P で偽である。しかし「保存できない」の前半である `(Ty.tapp 0 []).Sorted []` が言明にない。L20.30 が求める「正しい kind/Annotation の入力との対照」も同じ定理になく、`TypeSubstGateExamples` の `appTy` を results が名指ししていない。
- 修正案: 言明へ `(Ty.tapp 0 []).Sorted []` を足す。results に対照の例の名前を書く。

#### 軽8: 生成された match の名前に依存している

- 場所: `<repo>/formal/Benitoite/Release/Refinement/TypeSubstBindings.lean` 305 行の `S02_C.match_1`。
- 問題点: コンパイラが生成した補助の名前を本文に書いており、公開 S02 の字面の並びが変わると壊れる。
- 修正案: `S02Internal.C` の展開形に対する `funext b; cases b <;> rfl` の補題に替える。急がない。

#### 軽9: 体裁

- 01-12 の追加の段落の連続した空行、07-04 152 行の句点の後の半角空白、`formal/Benitoite.lean` の import の間の空行と順序（SourceScope より PrimitiveScoped が先）。
- 修正案: 次に同じ箇所を直すときに整える。

### 申し送り（誤りではない）

#### 軽10: C_Match の入口のパターン列の補題がない

`Exhaustive.substAt` は同じ `ps` を結論するが、C_Match の目標は `unguardedPats (Arm.substTyAtList c ts es arms)` を読む。値置換の `unguardedPats_subst` に当たる型置換の補題がない。補助の入力で `induction` と `simp` の5行で証明した。L20.36 の接続として本群に足すか、群 D の C_Match の行に明記する。

#### 軽11: sig_scoped は P の宣言を要求する

新 `Scoped` の `kinds` と `declared` は、表の署名に現れる data・class・external を P が宣言していることを要求する。旧 `s.Scoped` は P を読まない。kind を持つ判断に必要な強化であり、緩める理由はない。ただし `Result` などを持つ表（TargetTable、ModelTargets、ModelHttp）は、P の条件なしには充足しない。L50/L60 の義務へ「表が読む data の arity を P が持つ」を明記する。

## 観点ごとの確認

### 1. sig_scoped と PrimSig.Scoped

- 旧の項目との対応: NamesWF は `names`。範囲深さ `nranges` の VarsIn は `source`（`rkinds.length`・`tparams.length`・`neffs`・値深さ0）。引数の位置の条件と結果型の範囲0は `operation`。
- 証明に足りるか: `operation` は `ClauseSig.wf` の読む `OperationWF` を含み、`opSignaturesWF` が射影する。`Scoped.inst` は `RangeAdmissible` の長さの欄から深さ0の SignatureScoped を返す。不足は見つからなかった。
- 実表が満たせるか: 補助の入力で、`Reference.get` の形の署名の kind・Sorted・Declared・names・operation と、`ShapeOk .single` の形（引数 `.opaque o (.rvar 0)`、効果原子に `.rvar 0`）の `source` を確かめた。`Eff.Canonical` も通る。強めすぎの例は見つからなかった。
- `RangesScoped`: 新しい信頼条件ではない。旧 `Ty.VarsIn nr` は `Ty.RangesIn`（効果原子の `∀ x, a x = true → x.WF nr` を含む）に分解され（`varsIn_iff_old`）、`Ty.WF` が読まない効果原子の範囲をこの述語が担う。`CoreAssumptions` の欄は `sig_scoped` の1欄だけ増えた。
- 強さ: kind・Sorted・Declared は旧より強い（軽11）。引数の位置の条件は旧より緩い（軽5）。いずれも S09 の範囲である。
- `LegacyDeclarationInputs`: 三つの本体の入力を旧 `Def.WellTyped`・`ImplDecl.WellTyped` と字面で照合し、Q・C・Γ・R・効果が一致した。読むのは `LegacyOutputInput` と写した構文の `SourceScoped` だけで、新 WellTyped を入力にしていない。片方向の埋め込みを超えない。`LegacyTables` に sig_scoped を足していない。

### 2. 型置換の交換と形成

- `Ty.subst_substAt`: 向きは `(a.subst ts es).substAt c us fs = a.subst (ts.map A) (es.map E)` であり、`instantiatedTel_substAt` の Tel 版の系である。前提 `a.WF 0 nt 0` は値深さ0なので、依存βの本体は Tel 版を使い、この定理は構成子の欄と dict の型に使う。使い分けは正しい。
- `*_substV_images`・`Capture.close*_typeSubst`: 値置換の後に型置換する向きで、像にも同じ値置換を掛ける。閉じた像なら像は不変である。`Val.toTerm_substTyAt` により観測環境は型置換で変わらず、`Tel.open_typeSubst` の依存βと両立する。
- `closeVal_lam/dependentLam_typeSubst`: 注釈は閉じた像、本体は値束縛の下へ移した開いた像で、同じ cap を持つ。環境を捨てる等号ではない。
- 範囲の形成: `SourceScoped.bind`・`instR`・`rawMapRanges` を読み、WFImages と支持の移送から導いていることを確かめた。

### 3. パターンの型置換と網羅性

- `Exhaustive` の定義は変えていない。`PatternNormalForm` の差分は private の補題を `Inhabits.data_inv` として公開しただけである。
- 片方向で足りる。`Exhaustive` が現れる規則は C_Match の前提だけで、否定の位置に現れない。型置換で必要なのは「源の網羅 → 像の網羅」であり、そのために所属の「像 → 源」が要る。逆向きの網羅は要らず、型変数を Bool へ具体化する場合に偽である。
- `Inhabits.of_substAt` の入力は24構成子すべてを覆う。篩は `refineNorm_iff` から `RefinementPossible` を取り出し、`checkedAt` は opaque の枝、`atError` は data の枝にある。
- `PatTy.substAt`: P_Refined と P_Convert は正規形で閉じる。P_Con は `Program.WellFormed.cons` の行支持と WF を使い、像の追加形成を前提にしない。S03 の候補形と引数の順だけが違い、`signatures.md` に記録がある。

### 4. メソッド呼出しの入力

`ss ++ us` の kind・Annotation・SatAll の結合、`fs.length = ms.neffs`、`RowTransport (QTel ms.tel) Q fs` は正しい。代入前の `QTel ms.tel` は L10 の判断と、`ImplDecl.WellTyped` の `QTel ms.tel` に合う。Sub・Normal・Eff の包装も通る。不足は中1である。

### 5. 31の束縛位置

`results.md` の表の行・位置数は、`l20/detail.md`「全文脈変更の棚卸し」と一致し、14判断の内25と外の6で31である。挙げられた補題名（`Tel.open_typeSubst`、`Tel.arguments_typeSubst`、`SignatureInstance.substAt`、`TypeSubstInput.under`、`StoreTy.WF.hide` ほか）の実在も確かめた。

補助の入力で、`S02Internal.C.under_types` と `OpSig.context_typeSubst` を合成し、節の子の結論を `(sg.substAt …).context` の形で得た。`bindParams (hideConts Γ) ps` の V_Lam の文脈の写像も合成できた。IH は型束縛の下へ渡る。`sg.substAt` と原文 `sg` の橋は計画どおり L20.54 に残る。

### 6. 移動した定義

`SourceScope.lean` の定義を、`ProgramWellFormed.lean` から削除した93行と行単位で照合し、過不足がないことを確かめた。`Ty.TargetWF` などの3定義の本文も同一である。

### 7. 字面と公理

- 主な10言明と公開 S02 の14署名を置くファイルは差分にない。主な10言明を `#check` で確かめ、`SubstitutionAssumptions` などの前提の形を確かめた。
- `axioms.lean` を再実行し、832件の印字を再現した。現れる公理は `propext`・`Classical.choice`・`Quot.sound` だけで、`sorryAx` は0件である。
- 新規7ファイルに `sorry`・`axiom`・`native_decide`・`implemented_by` はない。
- `lake build` は 793 ジョブで成功した。新規7モジュールは `formal/Benitoite.lean` に import がある。
- `git diff` と未追跡の一覧に、`Refinement` の外の `Release` の変更はない。`formal/Benitoite.lean` だけが外の変更である。

### 8. 設計書の写し

01-12 の `Ty.TargetWF`・`BinderTypes.TargetWF`・`PrimSig.OperationWF`・`PrimSig.Scoped` の Lean の写しは一致する。`sig_scoped` の型も一致する。不一致は軽1〜軽5である。01-12・07-04 の中で中1に関わる文は、修正に合わせて直す。

### 9. 規約

- `l20/bc/` と新規の Lean、設計書の差分に、手元の絶対パス、`docs/todo` へのリンク、`work/` を出どころとする参照、「費用」の語はない。
- `l20/bc/` に 100 KB を超えるファイルはない。
- 設計書の差分に変更の経緯の文、新しい造語は見つからなかった。
- `signatures.md` の119宣言は実在し、新規6モジュールの定理・定義はすべて `signatures.md` にある（`SourceScope` は移動のため照合の対象外とした）。

## 確かめていないこと

- 新しい三モデルと標準の全表の `sig_scoped` の充足（L50/L60 の担当）。代表の2形だけを確かめた。
- G10 の V_Prim の接続で、非操作の項目の `Tel.instR` と旧 `PrimSig.inst` の一致がどこから供給されるか。旧 `sig_scoped` は全項目に引数の位置の条件を与えるが、`LegacyTables` はこれを持たない。本群の変更の外の論点であり、G10 の実装時に確かめる。
- 群 D の全相互帰納での使用。本群の補題が足りることは、節・V_Lam の文脈と C_Match の入口の代表で確かめただけである。

## 取りまとめの追記

中1と軽11件、申し送り2件を群 B・C の再開で処置した。
