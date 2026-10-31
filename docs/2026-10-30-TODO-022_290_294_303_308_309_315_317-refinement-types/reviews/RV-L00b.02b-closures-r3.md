# RV-L00b.02b-closures-r3: 閉包・状態・依存呼出しの群の再々レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02b-closures の未コミットの作業ツリーにある `formal/` の本番の変更であり、基準は `1170a4a6` である。

照合した入力は次のとおりである。

- [依頼](RV-L00b.02b-closures-r3-request.md)、[r2 のレビュー](RV-L00b.02b-closures-r2.md)、plan.md の「計画の変更と取りまとめへの確認点」の先頭の行
- `l00b.02/signatures.md` の第8.2節・第24節・第30節、`l00b.02/results.md` の「再レビューの所見の対応」、`l00b.02/02b-closures-r3-boundary.lean`、`l00b.02/02b-closures-r3-extra.lean`
- Refinement の `Typing.lean`（`git diff` と全規則）、`StateTyping.lean`、`LocalResolve.lean`、`LocalResolveLemmas.lean`、`ClosureTyping.lean`、`Semantics.lean`（Step の76構成子）、`TypingShift.lean` の `ClosureTy.store`、`HandlerContracts.lean` の `OpSig.context`、`Le.lean`、`Normalize.lean` の Eff の定義
- 旧の `formal/Benitoite/Release/Semantics.lean` の K_Handle

Lean は局所に8ファイルで実行した。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で終了0、誤り0件、`sorry` なしである。公理の依存は調べたものすべてで propext・Classical.choice・Quot.sound だけである。最大常駐は最大で約1.6 GiB である。補助のファイルは `<tmp>/rv02bclosures3/` に置き、リポジトリには置いていない。受け入れの根拠として引くなら、取りまとめがこれらを改造へ写す。

| ファイル | SHA-256 の先頭 | 確かめたこと |
|---|---|---|
| `counts.lean` | `628e2a50` | 相互帰納14型の構成子の計71（V28・Vs2・Each2・C21・TelArgs2・TelBody2・CaptureOk1・DependentClosureTy1・Witness2・AtCall1・Arms3・Clauses2・Failure1・ImageOk3）。ClosureTy は単独1型1構成子。ContTy10・Step76・Frame7・Cell6・LocTy4・State4 |
| `t1_resolve_identity.lean` | `fa5a1ff6` | 型付きの値・節は任意の ρ で解決しても変わらない。計算は L の `some` の位置で ρ が bound なら変わらない（中2） |
| `t2_capture_apply.lean` | `0c9c5b25` | `CaptureLocals` の開放の向き。`apply_one`（入力へ値を渡す）と `extendMany`（腕の束縛の下へ入る）（中2） |
| `t3_builder_body.lean` | `1a1fe852` | `builderBody_keepsBound` の前提 `he` が満たされない型付きの `builderLet`。前提を外した `builderBody_image`、閉じる像が正規化を区別しないこと（中3） |
| `t4_progress.lean` | `7c5e390b` | 型付きの `builderOp` の参照は `.loc` で、その場所は builder である。隠したストアの L に `some` は置けない（観点3） |
| `t5_handle_ann.lean` | `92ea8239` | 外側の閉じた Annotation と `Eff.Covers` から、内側の閉じた行の Annotation が得られる（軽3） |
| `t6_guard_builder.lean` | `bd5daf58` | 表にない行。`L=[some kind0]` の K_Guard の E_MatchGuard・E_GuardT・E_GuardF（軽1） |
| `t7_clause_context.lean` | `8f7f6c1f` | K_Handle の全欄が満たされるのに、E_Op の節の閉包が使うソースの文脈が `Ctx.WF` を満たさない例（中1） |

`02b-closures-r3-extra.lean` も実行し、終了0、誤りなしを確かめた。`.lake` の境界入力のコピーは `02b-closures-r3-boundary.lean` と SHA-256 が一致した。既定の `lake build` は担当の結果（673 jobs、終了0）を引用し、繰り返していない。この記録のほかにリポジトリのファイルを書き換えていない。

## 総評

**条件付き可。** 差し替えの本体は成立している。`ClosureTy.mk` は前の反例の状態を空虚でなく型付け、`L`・ρ は調べた束縛の形のすべてで作り直せた。`Step` と書ける形は変わらない。r2 の中1〜3と軽1〜3は、下の中1の一点を除いて解消した。保存の反例は作れていない。ただし全遷移の保存は証明されていないので、これは反例を見つけられなかったという意味である。

条件は三つである。

1. 中1を判断する。r2 の中1の修正で K_Handle からソースの情報を落としたが、節の閉包の `CaptureOk` はソースの文脈の WF・Sorted・Declared を要求する。r2 の「閉じた像だけで節の閉包を作れる」という記述は誤りであった。これは r2 の見落としである。`.02c` の公開入口が読む `CaptureOk` か K_Handle の形に関わるので、進む前に決める。
2. 中2の補題を本番へ置くか、義務の表へ載せる。L20 の全遷移がこれに依存するのに、第24節と第30.3節に書かれていない。
3. 中3の `builderBody_keepsBound` を、前提を外した形へ置き換える。

## 観点ごとの判定

| 観点 | 判定 | 根拠と補足 |
|---|---|---|
| 1. 前の反例 | 可 | `s1_typed`・`s3_typed` は `ClosureTy.mk` の新しい欄で通り、先の状態を前提にしない。`builder_new`・`nested_builder_new`・`input_builder_return`・`builder_match_transition`・`builder_op` はいずれも `L` に `some` を持つ。Ψ は閉じたままである |
| 1. `CaptureLocals` の結び | 可 | `Ψ l = builder (substKind ν kind)` は、E_BuilderNew の `substKind cap.env k` と一致する。入力と腕の下は下の観点2のとおり |
| 1. `Step` と書ける形 | 可 | Syntax・Semantics・Step は差分がない。71構成子は不変で、ClosureTy は相互帰納の外である |
| 2. `resolveLocals` | 可 | Val25・Comp16 を読んだ。型・効果の注釈は全構成子で変えない。束縛の数は `Comp.subst` と同じである。`.closure` は中へ入らない |
| 2. 交換の補題の言明 | 可 | `Comp.builderBody_resolve` の左辺は Step が作るコードそのもの、右辺は `code0' = m.subst builderValueSubst .bound`、`ρ' = pushLocal (.loc l) ρ` である。入れ子の `builderLet` は `upLocalSubst 1 ρ'` で同じ補題に戻る |
| 2. `builderBody_keepsBound` | **中3** | 前提を一般の `ClosureTy` から供給できない。本番でも境界入力でも使われていない |
| 2. `L`・ρ の作り直し | 可（**中2**） | letIn・ite・use・handle の本体は同じ `L`・ρ か `localExtend 1`。`match` の腕・E_MatchBody・E_GuardF・E_GuardT は Lean で確かめた（`t2`・`t6`）。builderLet は pushBuilder。作り直せない形はなかった。開放の向きの補題は本番にない |
| 3. `NoBuilders` の役割 | 可 | `t4` で確かめた。`HasKind.bound` が `L[i]? = some (some b)` を要求し、`CaptureLocals` が ρ i を `.loc l` に定めるので、`.builderOp _ _ (.bound _)` は残らない。`L` より大きい i は型付かず、ρ は全域の関数なので、長さの不一致の穴はない。thunk・節・lam は `hideBuilders` か `L=[]` で読むので `some` を置けない |
| 4. `K_Guard`・`matchRun` | 可 | E_GuardF の先を `.match vs arms0`・`L`・ρ で作り直せる。`t6` の `builder_guard_false` で確かめた |
| 4. `K_Handle` の欄 | **中1** | 下の所見。余分な欄は軽2 |
| 4. `Eff.Sub`・`RowAnnotations` | 可（**軽3**） | C_Handle の `Eff.Sub` と K_Handle の `Eff.Sub`・`Eff.Covers` はつながる。K_Handle_Fail は `HasFailureClause` の `RowAnnotations` と Annotation で足りる |
| 5. 遷移の表 | 可（**軽1**） | 30行すべてが前の StateTy・Step・先の StateTy の連言であり、仮定に状態を持たない（言明を機械的に抽出して照合した）。E_ の種類は23で記録と一致する。追加の7行は依存する正例である |
| 6. `ClosureTy.store` | 可 | `HasTypeCQ.shift_values` と `CaptureLocals` の移動で閉じる。相互帰納の外の普通の補題である。`ContTy.store` は未設置だが、K_ の欄は既存の族で移せると読んだ（未実行） |
| 6. 義務の第24節・第30.3節 | **中2** | 開放の向きと恒等の補題が書かれていない。「入力の適用・分岐・guard へ `Comp.subst_resolveLocals` を接続する」という記述は不正確である。これらの遷移は捕捉を延ばすだけで `Comp.subst` を使わない |
| 6. L20 の残り | 下記 | r2 の約90場合は消えた。下の見込みのとおり |
| 7. 五つの境界 | 可 | 主な定理の前提と結論、公理、提供範囲、書ける形、精密な外部状態に触れていない |
| 7. 抜け道・件数 | 可 | Refinement と境界入力に `sorry`・`admit`・`axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern` はない。71構成子・相互14型は `counts.lean` で確かめた |

### L20 に残る量

r2 の表の約90場合（CQ から OpenCodeTy への変換、BuilderLocFree の移送、OpenCode の置換・正則性・拡大、二枝の反転）は、定義ごと消えた。代わりに要る補題の大きさは次のとおりである。

| 補題 | 大きさ | 状況 |
|---|---|---|
| 解決の恒等（中2） | 約64場合、約140行 | `t1` で証明済み |
| `CaptureLocals` の開放（中2） | 約50行 | `t2` で証明済み |
| 構築器の本体の像の形（中3） | 約70行 | `t3` で証明済み。C_Sub・C_Eff の連なりの下での LeQ の正規化の接続は未実行 |
| 先頭の反転 | Comp 16形 | `code0.resolveLocals ρ` から `code0` の先頭を得る。各1行で、`t4` の形で足りる |
| 内側の行の Annotation（軽3） | 約40行 | `t5` で証明済み |
| 中1の対処 | 未定 | 案による。案(a)なら既存の補題の局所の直し、案(c)なら71場合の別の補題である |

closeVal の型付け・CaptureOk の hide・結果の WF/Sorted・腕の拡大は記録どおり残る。全体として、r2 の見込みどおり大きく減った。ただし中1の対処は見込みに含まれない。

## 新しい所見

### 中

**中1: K_Handle から落としたソースの情報を、E_Op の節の閉包の `CaptureOk` が要求する（欄の不足は読めば確定し、例は Lean で確定。保存の反例ではない）。**

- 箇所: `StateTyping.lean` 49〜57行の K_Handle、`Typing.lean` 329〜339行の `CaptureOk.mk`、`HandlerContracts.lean` の `OpSig.continuation`・`OpSig.context`、signatures 第30.2節の「handler の結果（再レビュー中1）」の行。
- 問題: E_Op の先は `Closure.mk (hcap.extendMany (ws ++ [.loc κ])) (c.body.substTy ts [])` である。`ClosureTy.mk` はこの閉包に、節の本体を検査した文脈の `CaptureOk` を要求する。節の文脈 `sg.context Γ ts ecs` の先頭は `.cont sg.ret ts' ecs'` であり、`CaptureOk.mk` の `Ctx.WF 0 0 Γ` と `a.Sorted Γ ∧ a.Declared P [] Γ` はこの項目にも及ぶ。`.cont` の WF は `Eff.Canonical` まで読む。一方で今の K_Handle は閉じた `t`・`ec` の Annotation だけを持ち、ソースの `ts`・`ecs` には何も持たない。`C_Handle` も ε に何も要求しない。
- 反例にあたる例: `t7_clause_context.lean`。Fail を二重に持つ行 `dupE` で `frame_dup`（K_Handle の全欄が成り立つ `ContTy`）と `clause_context_not_wf`（`¬ Ctx.WF 0 0 (pickSig.context Γ0 (R 0) dupE)`）を同時に証明した。末尾は `K_Empty` で `Eb` に Fail を持つので、`CellOk.cont` の形である。実行中の継続に載せるには外側に Fail の handler が要り、状態全体までは組んでいない。
- 範囲: これは E_Op の先が型付かないことの証明ではない。先の状態では `ClosureTy` が Γ を選べる。`dupE` なら行を `oneE` に替えた文脈で本体を型付け直せるはずである。しかし行に範囲外の値変数を持つ場合（r2 の `.var 6` の例）は、`Eff.Covers` の Fail が正規形の等号なので、narrowing では替えられない。既存の `Ctx.ContMap` も継続の型を同じに保つ。したがって今の欄からは、記録にある手段で E_Op の保存を構成できない。r2 の修正案の「ClosureTy.mk が要求するのも閉じた像だけなので、節の本体の閉包はこれで作れる」は `CaptureOk` を見落としていた。
- 旧との差: 旧の K_Handle は Γ=[] の閉じた節を持ち、`Ty.WF 0 0 t` だけで足りた。ソースの文脈に WF を要求するのは、この群の `CaptureOk` である。
- 修正案: 取りまとめが選ぶ。
  - 案(a): `CaptureOk` の `Ctx.WF`・Sorted・Declared の欄で、継続の項目は入力と結果の型だけを読み、行を読まない形に緩める。継続の項目の閉じた像は `ImageOk.contLoc` の WF が既に持つ。あわせて K_Handle にソースの `Ty.Annotation P [] Γ ts` を戻す。これは第24節の RV-closures 軽3（結果の正則性）の義務から E_Handle で供給できる。`ecs` は要求しない。読む箇所は `SubstOk.openValue` の継続の枝と `CaptureOk.declared` であり、少数である。
  - 案(b): `C_Handle` に ε の Annotation を足す。01-12 の `Eff.WF(ε)` に近づくが、plan は D29 の埋め込みから供給できないとして採らなかった。
  - 案(c): 型付きのコードが範囲外の値変数の置換で変わらないことを、中2の恒等と同じ形の相互帰納（約71場合）で示し、節の本体を閉じた行の文脈へ `HasTypeCQ.subst` で移す。定義は変わらないが、義務が増える。
  - 私は案(a)を推す。定義の変更が小さく、書ける形も主な定理も変わらず、利用者の入力に影響しない。案(a)の成立は未実行である。修正の後に、Fail を持つソースの行の下で E_Op の先を型付ける行を足して確かめる。

**中2: 全遷移が依存する二組の補題が、本番にも義務の表にもない（義務の不足は読めば確定し、補題は Lean で証明済み）。**

- 箇所: signatures 第24節の「重2の同因箇所」の行、第30.3節の同じ行、results の「残りと申し送り」。
- 問題の一: 実行コードは `code0.resolveLocals ρ` であり、`Closure.view` が読む値も、枠の節も解決済みである。一方で値の型付け・`DependentClosureTy`・K_Handle の `HasTypeClausesQ` は局所の参照を持たないソースの判断である。E_Handle の枠 `handleF q.capture h` の `h` は `Clause.resolveLocalsList ρ h0` なので、K_Handle の欄を埋めるには解決が節を変えないことが要る。`closeVal` の型付け（第30.3節の別の義務）も、`w0.resolveLocals ρ` を読む遷移（ret・app・ite・match・escape・use・resume）のすべてで同じことを要する。
- 確かめたこと: `t1_resolve_identity.lean` で、`HasTypeVQ.resolve_id`・`HasTypeClausesQ.resolve_id` などを相互帰納（約64場合）で証明した。値と節は任意の ρ で不変であり、計算は `L` の `some` の位置で ρ が bound なら不変である。
- 問題の二: 本番の `CaptureLocals` の補題は `localExtend`・`localExtend_many`・`pushBuilder` だけで、`upSubst n cap.env` から `(cap.extendMany ws).env` へ開く向きがない。境界入力は具体例で作っている。E_Return・E_MatchBody・E_MatchGuard が要る。
- 確かめたこと: `t2_capture_apply.lean` で `CaptureLocals.apply_one` と `CaptureLocals.extendMany` を証明した。`L` の位置 0 に `some` の kind があっても、`Ψ.WF` の閉性から像は変わらない。したがって K_Let の `ss=[a]` の一般の `L` でも反例にならない。
- 修正案: 両方を `LocalResolveLemmas.lean`・`ClosureTyping.lean` へ移すのがよい。いずれも `Step` にも定義にも触れない。移さないなら第24節と第30.3節へ個別の行として載せる。あわせて「入力の適用・分岐・guard 等へ `Comp.subst_resolveLocals` を接続する」を、「構築器の生成は交換の補題、入力と腕は `CaptureLocals` の開放、値と節は恒等の補題」と書き分ける。

**中3: `builderBody_keepsBound` の前提は、一般の `ClosureTy` から供給できない（Lean で確定）。**

- 箇所: `ClosureTyping.lean` 435行、results の「中2 / 注釈と構文の交換」の行、signatures 第30.2節・第30.3節。r2 の `t1_keep_bound.lean` を移したものである。
- 問題: 前提の `hR`・`ha`・`he`・`hk`・`hL` は、ソースの結果・行・R・kind が正準形であることを要求する。`C_BuilderLet` は a に Declared、ε に何も要求しない。`ClosureTy.mk` も閉じた像だけを見る。`hL` は `L` の全項目を読むが、`L` は `CaptureLocals` の像でしか縛られない。`t3_builder_body.lean` の `builderLet_at_dup` は Fail が二重の行で `builderLet` が型付くことを示し、`keepsBound_he_fails` はその行で `he` が偽であることを示す。この補題は本番でも境界入力でも使われていない。r2 の時点の「核」としての記述が、そのまま残っている。
- 修正案: `t3` の `HasTypeCQ.builderBody_image` へ差し替える。前提は `hA`・`hw`・`hΓ`・`hb` だけで、結論は像の R・a・e と像の局所文脈 `imageLocal L` である。`substKind_image` が示すとおり閉じる像は正規化を区別しないので、`CaptureLocals` と `closeTy` は元と一致する。C_Sub の連なりの下では LeQ の左辺の正規化の接続が要る。既存の `HasTypeCQ.subst` の C_Sub の枝と同じ移送で足りると読んだが、未実行である。

### 軽

**軽1: K_Guard を `L` に `some` を持つ形で使う行が表にない（読めば確定し、Lean で通ることを確認）。** `guard_cont` と `true_guard_cont` は `CaptureLocals.empty` である。`builder_match_transition` は matchRun までで止まる。軽1の修正の主目的の形が検査されていない。`t6_guard_builder.lean` の `builder_guard_push`・`builder_guard_true`・`builder_guard_false` で、`L=[some kind0]`、ρ が場所を指す K_Guard の三つの遷移を前の StateTy・Step・先の StateTy の連言で証明した。問題は見つからなかった。この三行を表へ足すことを勧める。

**軽2: 余分な欄（読めば確定）。** K_Handle の `Ty.Annotation P [] [] t` は `Ty.Annotation P [] [] (.dependentFn (.done t ec))` に含まれる。K_Guard の `v = closeVal cap (vs.resolveLocals ρ)` は、中2の恒等の補題で `v = closeVal cap vs` に等しい。どちらも害はない。

**軽3: C_Eff・C_Sub に包まれた C_Handle では、K_Handle の閉じた Annotation は `ClosureTy` から直接出ない（読めば確定し、補題は Lean で証明済み）。** 外側の行の Annotation しかないからである。`t5_handle_ann.lean` の `done_annotation_of_covers` が、`Eff.Covers` と内側の閉じた行の正準性から内側の Annotation を導く。Annotation は Fail の列だけを読み、原子を読まないので足りる。第30.3節の義務に一行を足すとよい。また、節の本体の効果 ec と枠の下の ε は `Eff.Covers` であり `Eff.Sub` ではない。E_Op の先の状態の `Eff.Sub e1 e` には、ε の原子と ec の Fail を持つ行へ C_Eff で広げる構成が要る。表の例は ε = ec なのでここを通らない。原理上は作れると読んだが、未実行である。

## 取り込みへの申し送り

| 区分 | 内容 |
|---|---|
| 取り込みの条件 | 中1の案の判断、中2の補題の移動または義務の追記、中3の差し替え |
| 実行しないと分からない疑い | 中1の案(a)の成立と E_Op の先の一般の型付け。軽3の効果の広げ方。中3の C_Sub の連なり。`ContTy.store`。一般の保存全体 |
| 読めば確定する誤り | 中1の欄の不足、中2の義務の不足と記述の不正確さ、軽1の表の範囲、軽2 |
| Lean で確定した点 | 中1の例、中2の二組の補題、中3の不成立の例と差し替えの補題、軽1の三行、軽3の補題、観点3 |
| 問題のなかった点 | 前の反例の型付け、`resolveLocals` が注釈を変えないこと、交換の補題の言明、`L`・ρ の作り直し、`NoBuilders` の役割、K_Guard の欄、30行の言明の形、五つの境界、抜け道、構成子の数 |

## 取りまとめの追記

2026-10-31。補助の入力を `l00b.02/` へ `rv-02b-closures-r3-*.lean` として写した。対応は `t1_resolve_identity` が resolve-identity、`t2_capture_apply` が capture-apply、`t3_builder_body` が builder-body、`t4_progress` が progress、`t5_handle_ann` が handle-ann、`t6_guard_builder` が guard-builder、`t7_clause_context` が clause-context、`counts` が counts である。
