# RV-L00b.02b-closures-r4: 緩めた CaptureOk に絞った確認

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02b-closures の未コミットの作業ツリーであり、基準は `1170a4a6` である。群全体の再レビューではなく、[再々レビュー](RV-L00b.02b-closures-r3.md)の中1〜3の修正だけを確かめた。

照合した入力は次のとおりである。

- [再々レビュー](RV-L00b.02b-closures-r3.md)、plan.md の「計画の変更と取りまとめへの確認点」の先頭の行、`l00b.02/results.md` の「再々レビューの所見の対応」、`l00b.02/signatures.md` の第24節・第30節の該当行
- Refinement の `Typing.lean`（`Ty.CaptureWF` など、`CaptureOk`、`ImageOk`、`ClosureTy`、C_Resume・C_ResumeL・C_Handle）、`StateTyping.lean`（`K_Handle`）、`ClosureTyping.lean`、`Context.lean` の `Ty.WF`・`Ty.Sorted`、`Capture.lean`、`HandlerContracts.lean`、`SubstTyping.lean` の `SubstOk`・`HasTypeCQ.subst`、`TypingDeclared.lean`、`Semantics.lean` の E_BuilderNew・E_Op
- `l00b.02/02b-closures-r4-rows.lean` の全文

Lean は局所に実行した。`02b-closures-r4-rows.lean` を `<tmp>/rv02bclosures4/` へ写して `lake env lean -M 12288` で終了0を確かめた。補助の `t1_builder_dup.lean`（SHA-256 の先頭 `153d9dc2`）も終了0、誤り0件、`sorry` なしであり、公理の依存はすべて propext・Classical.choice・Quot.sound である。最大常駐は約1.5 GiB である。全体の `lake build` は実行せず、担当の結果を引用する。`.lake` の境界入力のコピーは `02b-closures-r4-boundary.lean`・`-extra.lean` と SHA-256 が一致した。補助のファイルはリポジトリに置いていない。受け入れの根拠として引くなら、取りまとめが改造へ写す。

## 総評

**条件付き可。** 案(a)の緩和は、継続の項目のソースの行を読まないことだけを緩めており、通常の値の項目・None・長さ・実値・Ground・Φ・facts を緩めていない。読まなくなった行が不整合を起こす穴は見つからなかった。`K_Handle` の変更、正例、`builderBody_image` の差し替え、中2の補題の移動も、言明の弱まりはない。

条件は一つである。中1として、緩和の結果、`builderBody_image` の前提 `Ctx.WF` が `ClosureTy` から供給できない閉包が生じた。これは E_BuilderNew の保存の道筋の問題であり、保存の反例ではない。Lean で別の形の補題を証明したので道筋はあるが、その補題と `CaptureOk` の接続の補題が、本番にも義務の表にもない。

全遷移の保存は未証明である。「穴がない」は、下の範囲を読み、作れなかったという意味である。

## 観点ごとの判定

| 観点 | 判定 | 根拠と補足 |
|---|---|---|
| 1. 緩めた範囲 | 可 | `Ty.CaptureWF` などの三定義は `.cont b t _` だけを分け、ほかは元の判断である。元の `.cont` の WF の4欄のうち b・t を保つ。`CaptureOk.mk` の8欄は順序も内容も残り、変わったのは第1欄と第4欄の継続の項目だけである。`ordinary_dup_rejected` は通常の関数型の重複 Fail を拒む |
| 1. 閉じた像 | 可 | `ImageOk.contLoc` の像の全 WF と `Ψ l` との一致は残る。`.rho` や型変数を持つ行は像が WF を満たさないので拒まれる。範囲外の値変数は `Capture.env` の既定値へ読まれ、像は閉じる |
| 1. C_Resume・C_ResumeL | 可 | C_Resume の効果はソースの ε そのものだが、`ClosureTy` が読むのは閉じた像であり、`contLoc` がそれを `Ψ l` の行と等号で結ぶ。C_ResumeL は `Ψ` だけを読む。`Eff.Covers` は Γ・Φ を読まないので、C_Eff の下でも行の Sorted を要しない |
| 1. 捕捉の延長 | 可 | `close_extend` を証明した。`(cap.extend v).closeTy (a.shiftV 1 0) = cap.closeTy a` は WF を要らない。重複 Fail の行を持つ項目も、E_Return などの延長で像が変わらない |
| 1. 既存の補題 | **中1**・**軽1** | `ClosureTy.store`・`CaptureOk.store`・`substOk`・`CaptureOk.declared` は崩れていない。`HasTypeCQ.subst` は Ctx.WF を読まない。一方、全 `Ctx.WF` か `Ctx.Declared` を読む補題へは、`CaptureOk` から渡せなくなった |
| 2. `ts` の Annotation の供給 | 可（未実行） | 値の規則の型は V_Var を除き注釈か定数から来る。V_Var は通常の項目なので `CaptureWF` が全条件を持つ。C_Resume の t は b・t を保つ緩和で足りる。C_Sub・C_Escape・C_Meth は Annotation を持つ。ただし L20 の補題は `Ctx.WF` でなく緩めた条件から導く必要がある（軽1） |
| 2. 節の閉包の `CaptureOk` | 可（例で確認、一般は未実行） | `row_capture` は重複 Fail の継続項目を持つ `CaptureOk` を8欄すべて証明する。一般の場合の b・t の WF は `OpSig.WF` と `ts` の Annotation から作れると読んだ。`contLoc` の R0 の WF は `K_Handle` が直接持たず、K_Mark の Annotation からの反転が要る |
| 2. 遷移の表の2組 | 可 | `dup_handle`・`dup_op`・`narrow_handle`・`narrow_op` は前の StateTy・Step・先の StateTy の連言で、状態を仮定しない。`.E_Handle rfl` と `.E_Op ...` を実際に適用する。`narrow_not_sub` で Sub の不成立を証明し、外側の枠の ε は `eps`、節の ec は別の行である。k=1 の多相の節である |
| 3. `builderBody_image` | 可（**中1**） | 前の `keepsBound` より弱い点はない。ソースの正準性の前提が外れ、結論は像の R・a・e・L である。`builder_sub_chain` は C_Sub の二段で適用する。残る `hΓ` が中1である |
| 3. 中2の移動 | 可 | `resolve_id` 系、`apply_one`・`extendMany`、`Ty.open_up`、`substKind_apply` は本番にある。`CaptureLocals.apply_one` の追加の前提は `Ψ.WF` だけである。r3 が補助の入力に置いた言明との一字ごとの照合はしていない |
| 3. 抜け道 | 可 | Refinement の全ファイルと r4 の入力に `sorry`・`admit`・`axiom`・`native_decide`・`implemented_by` はない。削除した宣言は `axioms.lean` の検査入力が残っていないことを確かめる。`builderBody_keepsBound` の文字列はその検査の中だけにある |
| 3. 五つの境界 | 可 | Semantics・Step・CoreAssumptions に差分がない。ソースの規則も変えていない。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態に触れていない |

## 所見

### 重

なし。

### 中

**中1: `CaptureOk` の緩和により、`builderBody_image` の `hΓ` が供給できない閉包が生じた（Lean で確定。保存の反例ではない）。**

- 箇所: `ClosureTyping.lean` 519〜520行の `HasTypeCQ.builderBody_image`、`Semantics.lean` 59行の E_BuilderNew、signatures 第24節の「重2の同因箇所」の行、第30節の「本体の像」の行、results の「残りと義務の表」。
- 問題: 義務の表は、構築器の生成に `builderBody_image` を使うと書く。この補題は `Ctx.WF 0 C.length Γ` を要求する。緩めた `CaptureOk` は、重複 Fail の行を持つ継続の項目について `Ctx.WF` を与えない。節の本体が `builderLet` を持つと、この文脈で E_BuilderNew が動く。results は「全Ctx.WFを無条件に取り出せるとはしていない」と書くが、その場合に E_BuilderNew をどう閉じるかが書かれていない。
- 反例にあたる例: `t1_builder_dup.lean` で次を証明した。
  - `dup_closure`: 再々レビューの `rowΓ` の下で、`builderLet .string (resume (var 1) (var 2))` を本体に持つ閉包が `ClosureTy` を満たす。
  - `dup_step`: この閉包で `Step.E_BuilderNew` が動く。
  - `hΓ_unavailable`: その文脈は `Ctx.WF` を満たさない。
  - `dup_substOk_false`: 前提を外すだけでは直らない。`Γ.extendNone` から同じ `Γ` への `SubstOk` 自体が偽である。`ImageOk.contVar` は `Δ[j]` を像と等号で結び、像は行を正規化するので、生の行を持つ `Γ` と一致しない。
- 範囲: これは先の状態が型付かないことの証明ではない。`builderBody_image_norm` を証明した。前提の `Ctx.WF` を `Ctx.CaptureWF` へ替え、結論の文脈を継続の項目の行だけ正規化した `Ctx.normConts Γ` にしたものである。証明は `builderBody_image` とほぼ同じである。`close_normItem` で閉じた像の不変も証明した。
- 残る欠け: `CaptureOk ... Γ` から `CaptureOk ... (Ctx.normConts Γ)` を作る補題は未実行である。`Ty.Sorted.context`・`Ty.Declared.context` があり、継続の型の `Ty.assume` は空なので、facts も変わらない。局所の補題で足りると読んだ。
- 修正案: `builderBody_image_norm` と `close_normItem` を本番へ置き、`CaptureOk.normConts` を足す。第24節と第30節の行に「捕捉の文脈が通常値だけでないとき」の経路として書き分ける。`ImageOk.contVar` を緩める案は、C_Resume の場合の行が等号でなくなるので勧めない。`.02c` は定義を変えないので、補題の追加は `.02c` の前でも L20 でもよいが、義務の表には今回載せる。

### 軽

**軽1: `Ctx.WF`・`Ctx.Declared` の全項目を読む補題の前提が、中1と同じ原因で供給できない（読めば確定）。** いずれも読むのは通常の項目だけか、注釈だけで足りる。

- `TypingDeclared.lean` 15行の `HasTypeVQ.declared` と 64行の `HasTypeCQ.declared` は `Ctx.Declared` を要求する。`V_Var` の通常の項目だけを読むので、`CaptureDeclared` か通常の項目だけの条件へ弱められる。
- `ClosureTyping.lean` 57行の `SubstOk.openValue` と 98行の `HasTypeTelArgsQ.of_arguments` は `Ctx.WF` を要求し、前者は重複 Fail の文脈で中1と同じ理由で成り立たない。`of_arguments` は Annotation の移動にしか使わないので、`Ctx.normConts` を経由するか、結論だけの補題に分けられる。results は Γ0 が通常値だけの場合に限って適用したと記録しており、一般の閉包の文脈は未解決である。
- 第24節の「軽3 / 計算結果の正則性」の行は「文脈・場所・ソースの整形式の前提から導く」と書く。この前提を `Ctx.CaptureWF` などの緩めた条件と明記するとよい。`Ctx.WF` を前提に書くと E_Handle の `ts` の Annotation が供給できない。
- 修正案: 義務の表の一行として、これらの前提の読み替えを載せる。

**軽2: 範囲外の値変数を行に持つ場合の行が表にない（読めば確定）。** Rows の例は重複 Fail と原子の差である。r3 が narrowing では替えられないとした `.var 6` の形は、`close_extend` と `Capture.env` の既定値から成り立つと読んだが、状態の行としては未実行である。修正案: `row_capture` の行を、Fail の型の述語に範囲外の変数を持つ形で一行足す。

## この範囲の外で気付いたこと

- E_Op の `c.body.substTy ts []` の新しい判断での型付けの補題（旧の `HasTypeVQ.substTy` に当たるもの）が、Refinement にも signatures にも見当たらない。多相の節の本体が注釈を持つ場合の義務として、表にあるかを取りまとめが確かめるとよい。Rows の例の本体は注釈を持たないので通らない。

## 取り込みへの申し送り

| 区分 | 内容 |
|---|---|
| 取り込みの条件 | 中1の補題の移動か義務の追記 |
| 実行しないと分からない疑い | `CaptureOk.normConts`。範囲外の値変数の行。一般の E_Op と E_Handle の `ts` の供給。全遷移の保存 |
| 読めば確定する誤り | 中1の義務の表の不足、軽1の前提、軽2の表の範囲 |
| Lean で確定した点 | `dup_closure`・`dup_step`・`hΓ_unavailable`・`dup_substOk_false`・`builderBody_image_norm`・`close_normItem`・`close_extend`、Rows の入力の再実行 |
| 問題のなかった点 | 緩めた範囲、閉じた像、C_Resume と C_ResumeL、遷移の表の2組の言明、中2の移動、`builderBody_keepsBound` の差し替え、抜け道、五つの境界 |

## 取りまとめの追記

2026-10-31。`t1_builder_dup.lean` を [l00b.02/rv-02b-closures-r4-builder-dup.lean](../l00b.02/rv-02b-closures-r4-builder-dup.lean) へ写した。所見の処置は `l00b.02/signatures.md` 第31節に載せた。
