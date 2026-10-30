# RV-L00a.06b: L00a.06b（新判断の並置と旧導出の埋め込み）のレビュー

2026-10-30。レビュー担当は Opus 5.5 のサブエージェント（effort medium、所要約30分）。対象はブランチ m014/l00a.06b の `formal/Benitoite/Release/Refinement/*.lean`（9モジュール）、`formal/Benitoite.lean` の import、[l00a.06b/results.md](../l00a.06b/results.md)。定義・言明・仮定のレビューとして行った。リポジトリのファイルは書き換えず、報告を応答で返した。取りまとめが要点を保存した。

**総評**: 重大な問題はない。取り込みの前に直すべきものは記録の一点（中1）だけ。新しい9モジュールは契約（[l00a.06a/contracts.md](../l00a.06a/contracts.md)）の公開名・署名・構成子・規則に合い、契約から黙って変えた点はない。`embedLe`・`embedCovers`・`Ty.LeQ.assume` の言明は契約と RV-P4 M1 の形どおりで、前提が強すぎることも空になることもない。

## 実行して確かめたこと

- 既定のビルド: `cd formal && lake build` は終了0、582ジョブ（成果物が揃っていたので全モジュールが再利用された）。警告88件はすべて既存の Interval 系のもので、Refinement の警告は0件。
- 9モジュールを `lake env lean -M 12288 Benitoite/Release/Refinement/<M>.lean` で一つずつ検査し直し、9件とも終了0・警告なし・sorry なし（各0.3〜1.1秒、最大常駐量 約0.69〜0.76 GB）。
- 新しいモジュールに `sorry`・`admit`・独自の `axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`set_option` はない（`opaque` は Ty の構成子名だけ）。
- 20補題（embedLe、embedCovers、Ty.LeQ.assume、Entails.cut/weaken、embedTy_norm、embedEff_norm、embed_memFail、embed_canonical、embed_wf、tyCompare_embed、embedTy_injective、Ty.norm_idem、Ty.normTys_idem、Eff.norm_idem、Eff.norm_memFail、tyCompare_eq_iff/total/lt_trans/antisymm）の `#print axioms` は propext・Classical.choice・Quot.sound の部分集合（Entails.cut と weaken は propext だけ）。sorryAx はない。
- `#check` で主な署名が契約と一致することを確かめた。判断が空でないことの例（V_Refine で `var 0 : Integer{self = self}` を導ける、`introduce` が Γ[0] の篩の事実を `Ctx.facts` 経由の `hyp` で使える、`Ty.LeQ.assume` が `trans forget refl` を越えて事実を移せる）が sorry なしに通った。
- Refinement を import するのは集約の `formal/Benitoite.lean:288` だけで、旧 Release から新しいモジュールへの import はない。`Benitoite.lean` の差分は空行と import 1行。

## 読んで確かめたこと

構成子（Ty 16、Val 17、Comp 13、Arm 1、Clause 2、Entails 17、LeQ 9）は契約の表と一致する。正規化は `norm (refined a p) = refined a.norm p` で述語を保ち、`Eff.norm` は atoms を変えず `sortUnique tyCompare (normTys fs)` を返し、tyCompare は旧の順位0〜14を保ち refined を15とする。SubstEnv は types・rows（List Eff）・ranges（List Range）・values の四欄で、rawBind は像へ置換を再適用せず、`Ty.bind`・`Eff.bind` は rawBind の後に norm を取る。V_Refine の前提は契約の6つ（IntegerCarrier を含む）と一致する。ConstOK の各幅の範囲と Decimal（2^96−1、scale ≤ 28）は `crates/benitoite/src/base/decimal.rs:5,8` と一致し、旧 `Const.opaque` は valKind/valContent が none のときだけ通す（D22）。embedLe・embedCovers は任意の Γ/Φ について成り立ち、旧入力に新しい条件を足していない（新しい条件は V_Const の ConstOK だけで、承認済みの D21/D22）。embedCovers の Fail の枝は整列や重複なしを仮定しない。embedLe は旧 `Ty.Le` の二枝を `refl` と `fn_effect (embedCovers …)` で作り直し、lift やアダプタを使わない。`Ty.LeQ.assume` の言明は `LeQ Γ Φ a b → ∀ q ∈ b.assume, Entails (a.assume ++ (Γ.facts ++ Φ).map lift) q` で追加の前提はない。型付けの規則は旧 `Typing.lean:526-628` と照合して正しい。予約名は定義していない。

## 中

- **中1. 記録が、作業末のビルドが増分だったことを書いていない**: work の約1秒は、新しい9モジュールが直前の局所ビルドで作成済みで既存の成果物を再利用したためだが、本文は全件のビルドを work に集約したと読める（plan の L00a.01b の行に「以後のbuildは増分と明記」）。修正案: その旨を一文で加える。→ 取りまとめが results.md に追記した。

## 軽（後の作業へ送る）

| 所見 | 送り先 |
|---|---|
| 軽1. 後の作業が使う補助の定義が非公開（`Context.lean` の termBind/predBind/termWF/termSorted/sortedTys/sortedEff/shiftVTys/upValues/rawApply/rawBindTys、`Subst.lean` の valEnv/renEnv/typeEnvAt、`Le.lean` の assumptions）。別のファイルから名前を書けず simp でも展開できない | .08〜.12a（必要な補助を公開へ変えてよい。公開名の追加は報告） |
| 軽2. 値の改名の実装が二つある（`Context.lean` の `Ty.shiftV` と `Subst.lean` の非公開の renameTy） | .08（両者を結ぶ補題） |
| 軽3. 使われていない非公開の定義（`Syntax.lean:89,108,112,115,149`） | 次にこれらのファイルを触る作業 |
| 軽4. 篩を付けた継続の型を継続の除外が見落とす余地（`Typing.lean:6-8,29` の V_Var と hideConts は最外の `cont` だけを除く。L00a では到達しない） | L00b.02a/L10（cont を carrier にする篩を WF で禁じるか、篩を除いた核で判定するか） |
| 軽5. 型構成子の変数の像が篩付きのとき型引数が落ちる（`Context.lean:179-188` の rawApply。旧の既定の枝と同じ扱い） | .09a/L00b.11（型構成子の位置の像に篩を許すか） |
| 軽6. Normalize 以外の8モジュールに先頭の説明がない | 次にこれらのファイルを触る作業 |
| 軽7. ログの1行目に道具の注意の行 | 対応不要 |

## 義務の行の判定

L00a.06b は実装を完了し、中1を直せば受け入れの条件を満たす。O042（.06b の分）は閉じた（全体は L10/L20/L70 が残る）。O159（.06b の分）は閉じた（L00b/L10 の全構成子と L70 の切替が残る）。O002/O004/O029/O031 は定義と embed_wf・cut だけで、保存の証明は未実施（results.md も閉鎖に数えておらず正しい）。O003/O010 は未実施。
