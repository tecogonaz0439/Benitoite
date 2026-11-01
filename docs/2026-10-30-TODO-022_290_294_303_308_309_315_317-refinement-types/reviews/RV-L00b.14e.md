# RV-L00b.14e: 節の引数と resume の代表の独立レビュー

**判定: 条件付き可。所見は重0、中1、軽5である。** 代表の5定理は開始の `StateTyE` から閉じており、結論の仮定も偽の事実の反例もない。分類は「一部」でよく、「行き詰まり」には当たらない。条件は中1の処置である。`E_DropRel` の全保存は、今の `CoreAssumptions` だけからは偽である。旧の主定理が持つ前提を写せば、今の定義のまま閉じることを Lean で確かめた。

2026-11-01。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ `m014/l00b.14e` の未コミットの作業ツリー、基準は `c64c0dc3` である。

## 動かしたもの

補助の入力は `<tmp>/rv14e/` に置いた。実行は `cd formal && lake env lean -M 12288 <ファイル>` である。本番のファイルは変えていない。公理の依存は、`rv-14e-t5.lean` が propext だけ、ほかは propext・Classical.choice・Quot.sound だけである。`sorryAx` はない。

| 入力 | 内容 | 結果 |
|---|---|---|
| `lake build`（対象の173ジョブ）と `boundary.lean` | 本番のビルドと境界の再実行 | 終了0。境界のエラー0、`sorryAx` 0、宣言100 |
| `rv-14e-counts.lean` | 実際の環境から構成子の数を読む | `ContTy` 10、`HasTypeVQ` 29、`HasTypeCQ` 24、`Step` 76、`GuardBodyTy` 1 |
| `rv-14e-t1.lean` | `CoreAssumptions` を満たす `P`・`B` で、`E_DropRel` の到達に型が付かない反例（`no_drop_rel_preservation`） | エラー0 |
| `rv-14e-t2.lean` | `NoStateHandled` を足した `E_DropRel` の定数の代表（`state_end`・`prepend_releases`・`StateTyE.drop_rel_const`） | エラー0 |
| `rv-14e-t3.lean` | Fail の値と節の宣言の一致（`fail_input`）、Fail の節の切り出し（`split_fail`） | エラー0 |
| `rv-14e-t4.lean` | 任意の引数の数の捕捉の延長（`capture_tel`）と依存する結果（`result_tel`）、二引数の例 | エラー0 |
| `rv-14e-t5.lean` | 継続の変数は `hideConts` の後に読めない（`no_cont_after_hide`） | エラー0 |

全宣言の公理依存（15,418件）は再実行していない。新規の本番ソースに `sorry`・`admit`・`axiom`・`native_decide`・`unsafe`・`implemented_by` はない。記録に絶対パスはない。

## 所見

### 中

**中1. `E_DropRel` の全保存は `CoreAssumptions` だけでは偽である。残件の記述に要る前提がない**（再現済み。`rv-14e-t1.lean`、`rv-14e-t2.lean`。**五つの境界のうち「主な定理の前提」に触れる**）

- 場所: `ConstraintAssumptions.lean` の `Builtins.CoreAssumptions`、`StateTyping.lean` の `K_Drop`・`K_Release`、`results.md`「残りと送り先」の E_DropRel の行と冒頭の「表の条件の不足…の反例は得ていない」、`signatures.md` 末尾。
- 問題: `K_Drop` の `State` の条件は、継続の行 `e'` に `State` があるときだけ外側の行を縛る。`handled` が `State` を消せると、継続の中の `release` は `e'` に現れない。旧の証明はこれを `handled_state` で防ぐ。`handled_state` は旧の `CoreAssumptions.state_effect` と `Program.EffectsOk` に依存する。新しい `CoreAssumptions` には `state_effect` がなく、Refinement の側に `EffectsOk` もない。
- 再現: `P.effects stateEff = some ["abort"]` とする。`saved = [.release r, .handleF empty cs]`、`Ψ 0 = .cont U U Eff.empty none`、`Eb = Eff.empty` とする。開始の `StateTyE` は成り立ち、`E_DropRel` は実際の `Step` である。到達の `.run … [.release r] μ2` には型が付かない。`K_Release` が `State` を要求し、末尾の `Eff.Sub e Eff.empty` と両立しないからである。結論は `Builtins.CoreAssumptions P B ∧ StateTyE … s0 ∧ Step … s0 none s1 ∧ ¬ StateTyE … s1` である。
- 判断:
  - 規則の障害ではない。`NoStateHandled P B`（どの `handled` も `State` を含まない）を足すと、`StateTyE.drop_rel_const` は `ContTy`・`StateTyE`・遷移を変えずに閉じた。任意の `k'` について `state_end` と `prepend_releases` の約40行で足りる。
  - 新しい前提でもない。旧の主定理の `hdecl` と `state_effect` の写しである。したがって D19 の方式と「行き詰まり」の定義には触れない。ただし L00b.15 の新旧対照と主定理の前提の一覧から落ちると、全保存が偽になる。
  - 今回の5代表はこの前提を使わないので、`results.md` の「今回の代表は既存の CoreAssumptions で閉じ」は正しい。読者が E_DropRel の残件も同じと読む書き方になっている点が問題である。
- 修正案: 次の順に行う。
  1. `results.md` の E_DropRel の行に、`NoStateHandled`（`state_effect` と `EffectsOk` の写し）が要ることと、反例の入力を書く。
  2. 新しい `CoreAssumptions` と `Program.WellTyped` のどちらへ置くかを取りまとめが決める。境界のモデルは `effects := fun _ => none` なので、`state_effect` を旧の形のまま足すと境界の `B` を直すことになる。`P.effects stateEff = none` と、`B.effects stateEff` が `none` か `some []` である形なら、現在の全モデルをそのまま満たせる。
  3. L20 で閉じる補題は `rv-14e-t2.lean` の形を初回の候補とする。今足してもよいが、前提の置き場を決めるまでは補題の仮定 `NoStateHandled` のまま置く。
  4. `E_EscDropRel`・`E_ErrDropRel`・`E_ExitDropRel` は同じ `prepend_releases` で閉じる見込みである。これは未実行である。

### 軽

**軽1. `E_OpPrim` の残件に `ShapeOk` の写しの必要が書かれていない**（読めば確定する範囲と未再現の範囲を分ける。**「主な定理の前提」に触れる可能性がある**）。旧の `CoreAssumptions.io_op` は `Builtins.ShapeOk` を要求する。これは、引数の範囲の添字と効果の添字の一致を保証する。新しい `CoreAssumptions` にこの欄はない（読めば確定）。すると、効果が `l@S0`（固定）で引数が `.scoped o k (.rvar 0)` の項目を、表が持てる。`rs = [top]` で呼ぶと `ClauseRangeIs` は `S0` を選び、節の入力の型は `S0` に狭まる。`S0` の外の対象を持つ値が、節の文脈の型を満たさない見込みである（机上の反例で、未再現）。修正案: `results.md` の E_OpPrim の行へ `io_op` の写しの要否を確かめる義務を足し、L20 で再現テストを置く。なお `Ty.LeQ` には `opaque` の範囲を広げる規則がない。閉じた値の逆転で `scoped` の範囲を広げて読み直す補題が要る。今の規則で書ける見込みである（未実行）。

**軽2. `E_OpFail` の残件は `split_handle` の再利用では閉じない**（読めば確定。補助は再現済み、`rv-14e-t3.lean`）。`split_handle` は `handles cs .fail = false` を要求するので、Fail の節に使えない。`K_Handle` の `ec` をそのまま格納の行にすると `rest` を被覆できない。`split_fail` は格納の行を `.mk et.atoms ec.fails` として、この点を閉じた。`fail_input` は、`Fail` が k1 の全枠を通り節の宣言の型と正規形で一致することを示した。`Eff.Covers` の Fail は不変なので、値は `V_Normal` で節の入力の型へ移る。この二つの補題は規則の変更を要さず、`E_OpFail` に残るのは型置換だけである。修正案: `results.md` の行に `split_fail` を明記し、`rv-14e-t3.lean` の補題を L20 の初回の候補とするか、本番へ置く。

**軽3. 複数引数の捕捉の延長は既存の補題の帰納で閉じる。残件の記述を小さくできる**（再現済み、`rv-14e-t4.lean`）。`capture_tel` は任意の `hcap` と任意の引数の数で、`CaptureOk` の延長を示す。`result_tel` は、依存する結果が `(cap.extendMany vs).closeTy t.result` と一致することを示す。第二引数の型と結果が先行の引数を読む二引数の例も通した。事実の読み替えは壊れない。`close_one` はこの一引数の場合である。修正案: 二つの補題を本番へ置き、`close_one` を置き換えるか、L20 の行の「extendTel と依存列の交換」を「`operation_one` の一般化」へ縮める。分類は「一部」のままである。

**軽4. `operation_one` の宣言の条件は、L20 の到達点を指す形で記す**（`hx` は読めば確定、`hy` と型置換は未実行）。`hx` は `hargs` の `.param` が持つ注釈から得られ、`hy` は `op_inv` の `SignatureInstance.result` から得られる見込みである。`Normal` の下では入力の仮定として要らない。これらは代表の範囲を示す条件であり、空虚でも結論の仮定でもない。生の宣言へ一般化するときに、生の `Sorted`・`Declared` を探す必要はない見込みである。型置換の補題の像の文脈は `Ctx.bindTypes` で正規化され、注釈は `SignatureInstance.result` から得られるからである。`hxn`・`hyn`・`hbn` は `ts = []` の型置換の補題が閉じれば消える。`dictParams` が空でない宣言は残件の表にない。修正案: 残件の表に「`hx`・`hy`・`hxn`・`hyn`・`hbn` は型置換の補題で全て消え、主定理の前提に残らない」と `dictParams` を足す。`Program.WellTyped` へ生の注釈を足す案は、この補題の結果を見てから判断する。

**軽5. `signatures.md` の guard の文が定理より広い**（読めば確定）。「guard の評価中の操作呼出しは型付かない」とあるが、定理は `.guardF` が継続の先頭にある場合だけである。`K_Handle` の下に guard を置く形では、内側の行が操作を持てる。guard の条件の中の `handle` が、その操作を処理する形である。修正案: 「先頭が guard の継続、または `K_Let` などで同じ行を共有する継続の下」と改める。定理そのものは正しい。

## 残件の見通し

| 対象 | 結果 |
|---|---|
| 二引数・依存する結果 | 閉じた（捕捉と結果の照合）。全遷移の合成は `operation_one` の一般化だけで、未実行である |
| 多相節 | 閉じない。理由は `ClosureTy` の本体が型文脈 `[]` を要求し、節の本体の導出は `sg.tparams ++ C` の下にあるからである。固定点の条件では代えられない。`HasTypeCQ` の型置換の補題が必要で、今は `Ty.LeQ.subst`・`Eff.Covers.subst`・`Transport.types` だけがある。規則の障害は読んだ範囲では見当たらない。入力は `V_Op` の `SatAll`・`SignatureInstance`、`TypeAssumptions.sat_subst`・`admits_subst`、`C_ResumeNorm` である |
| `E_OpFail` | 型置換の補題の後で閉じる見込みである。`fail_input`・`split_fail`・`CaptureOk.extendHidden` が揃っている。Fail の節は型パラメータの下にあるので、この補題の前に閉じる代表はない |
| `E_DropRel` | 定数の view で閉じた。前提は中1のとおりである |
| 行き詰まり | 当たらない。どの残件も `Step`・型付け規則・`ContTy`・`StateTyE` の変更を要さない。要るのは旧の前提の写しと、L20 の型置換の補題である |

## 確かめて問題がなかった重点

| 重点 | 結果 |
|---|---|
| 開始の逆転 | 5定理は開始の `StateTyE` を分解し、到達の型付け・本体の型付け・`Entails` を入力に持たない。境界の具体の状態で全入力が満たされ、空虚でない。`resume_used` は `ContTy` だけで足りる |
| `pure_operation` の逆転 | `C_Sub`・`C_Normal`・`C_Eff`・`V_Sub`・`V_Normal`・`V_Refine` と `C_App`・`C_DependentApp` を全て通す。捕捉の Φ は閉じた導出で除く |
| 依存する結果 | `close_one` は `hcap` が非空でも成り立つ。`y` は宣言の引数だけを読み、`hcap` の値と混ざらない。`heq` が継続の型の像 `.cont result t ec` を与える |
| `hcap` と継続の捕捉 | `HandlerFrameTy` は `K_Handle` の Γ・Φ・Rs・ts・ecs・ebs を全て保持する。節の本体の捕捉は `cap.extend v` と `.loc l` で、継続の末尾の `handleF` は元の `cap` を持つ |
| `resume` の回数 | 二度目は `E_ResumeErr` で型付き状態へ進む。呼ばないときは `E_Drop`/`E_DropRel` である。`.cont` は通常の値の変数にならず、`hideConts` が関数と thunk の本体から継続を隠す（`rv-14e-t5.lean`）。後で使う形は作れない |
| 全10構成子 | `split_handle`・`resume_append` は全構成子を扱う。`K_Guard` の `GuardBodyTy` と `K_Update` の注釈を保持する。末尾は `EndsWithHandle` で接続し、`K_Handle`・`K_Handle_Fail` とも `Covers` を合成する |
| `Covers` と `Sub` | 切り出した行は `ec` のままで、節の実行だけを `widen_atoms` で広げる。Fail を保ち、`Sub` を `Covers` から作る。向きは正しい。`K_Drop` の条件は `covers_state` から得る |
| ストア | `allocate_continuation`・`use_continuation` は有限性・WF・Declared・領域・全セルを保つ。`Ψ` を変えないので `K_Drop` と捕捉の場所は残る |
| guard | `operation_under_guard_false` と `guard_effect` は証明どおり正しい。切り出しの中の guard の保持とは別の命題として扱っている |
| 境界 | 5遷移は実際の `Step` である。`let_pair` だけは一般の定理でなく具体の導出で到達を作り、依頼はそれを明記している。`call_rejects_nine`・`input_contract_removed`・`result_contract_removed`・`nine_not_small` は、`x = 9` のモデルか値9の評価で偽を導き、別の理由の拒否ではない |
| 記録 | `ContTy` 10、値29、計算24、`Step` 76、公開17は一致する。三族76は `axioms-summary.json` の `THREE_FAMILY_CASES 76 (71 + 5)` と一致する。残りの見込みは既存枠の内数で、新しい加算はない。O051・O008 の記述は閉じた範囲に収まる |

## 五つの境界

中1と軽1だけが「主な定理の前提」に触れる。どちらも旧の主定理にある前提の写しの漏れであり、新しい信頼条件ではない。新しい公理、提供範囲、利用者の書ける形、精密な外部状態に触れる所見はない。

## 取りまとめの追記

2026-11-01。補助の入力は `l00b.14e/rv-14e-t1.lean`〜`t5.lean` と `rv-14e-counts.lean` へ写した。中1は `plan.md` の先頭の判断のとおり、`state_effect` と `EffectsOk` を主な定理の前提へ戻し、`drop_rel_const` をこの作業のうちに本番へ閉じる。軽1は L20 の義務へ書く。軽2・軽3の補助は本番へ入れる。軽4・軽5は同じ再開で処置する。
