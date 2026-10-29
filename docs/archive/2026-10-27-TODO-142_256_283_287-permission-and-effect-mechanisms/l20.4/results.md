# L20.4 の結果: 値の所属の葉の規則（一度の切り替え）

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L20.4（plan-l10-l50「L20」の表の L20.4 の行）。担当は Claude のサブエージェント |
| B_WORK | `599a9a70a02010987d2c6ec0b30a0d2c7dd4ef02`（本線、L20.3 の取り込みと `sig_scoped` の切り替えの付け替えの記録の後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l20.4`。git の状態は変えていない |
| 閉じた範囲 | 葉の規則 `HasTypeVQ.V_Checked` と、相互帰納の全ての場合への追随。`HasTypeVQ.inv_checked` の逆転の補題への置き換えと、標準形の定理の `checked` の場合の直し（6定理）。網羅性の値の形 `Inhabits` への検査済みの対象の値の場合の追加と追随（「ずれと申し送り」1）。標準形・範囲の拡大・旧の像での同値の補題と、閉じた非 Top の値の小例（新しいファイル `Release/Lemmas/Membership.lean`、既定の import に追加）。01-12・07-04 の反映。既定の全入口のビルドが sorry なしで通る |
| 未完 | なし（計画の L20.4 の行の範囲）。組み込みの関数が範囲付きの値型を受け取る場合（`E_Prim`・`E_IO`・`E_OpPrim`）は計画どおり L20.5 |
| 適用した前提の変更の行 | 停止の表の「値の所属の規則」（問18 の行 7）。網羅性の値の形の変更もこの行に含めて扱った。取りまとめの確認を求める（「ずれと申し送り」1） |
| 停止条件 | 表にない前提の変更、結論の弱化、公理と `Builtins.Assumptions` の欄の追加はないと判断した。ただし網羅性の値の形の変更を問18 の行 7 に含めることは担当の判断である |

## 試行（最初の30〜60分）

plan「検査の割り当て」の「L の一度の切り替えの試行ビルド」の行に従い、`HasTypeVQ` に葉の規則を一つ加えた差分（[trial/trial.diff](trial/trial.diff)）から、排他の道具で既定の全入口の `lake build` を走らせた。Lake は失敗したモジュールを import する先を検査しないので、一回のビルドでは最初の層の破損しか数えられない。そこで、壊れた宣言を機械的に直しては全体のビルドを繰り返し、回ごとの破損を数えた。数え方は、`error:` の診断をファイルと宣言に対応付けた一意数である。未検査の数は、その回に失敗したモジュールを推移的に import するモジュールの数であり、作業末の import の関係から数えた（[trial/unchecked.tsv](trial/unchecked.tsv)。新しいファイル `Membership.lean` の1件を含む概数）。

| 回 | 壊れた宣言 | 壊れたファイル | 未検査のモジュール | 内容 | ログ |
|---|---:|---:|---:|---|---|
| 1 | 1 | 1 | 221 | `Typing.lean` の `hideBuilders_strengthen_val`（場合の不足） | [trial-build-1.log](trial/trial-build-1.log) |
| 2 | 6 | 4 | 191 | `LocalScope`・`Names`・`Rename`（3）・`Inversion`（`inv_checked`）の場合の不足 | [trial-build-2.log](trial/trial-build-2.log) |
| 3 | 3 | 3 | 188 | `Irrelevant`・`NoFailContext`・`Regularity` の場合の不足 | [trial-build-3.log](trial/trial-build-3.log) |
| 4 | 2 | 2 | 184 | `OuterC` の場合の不足、`FailureCont` の `inv_handle_failure` の heartbeats の上限超過 | [trial-build-4.log](trial/trial-build-4.log) |
| 5 | 1 | 1 | 183 | `SubstTyping` の場合の不足 | [trial-build-5.log](trial/trial-build-5.log) |
| 6 | 2 | 2 | 177 | `CoverageTypes` の `inhabits_erase_transfer`、`TySubstMain` の `Inhabits.of_substAt`（網羅性の値の形に場合を足した後の不足） | [trial-build-6.log](trial/trial-build-6.log) |
| 7 | 1 | 1 | 16 | `Surface/Lemmas/PatternSupport` の `Inhabits.consCongr` | [trial-build-7.log](trial/trial-build-7.log) |
| 8 | 0 | 0 | 0 | 全体が通った（`Build completed successfully`） | [trial-build-8.log](trial/trial-build-8.log) |

診断として現れた宣言の一意数は16、ファイルの一意数は14である。ほかに、回 2 の後に `inv_checked` の言明を変えたために壊れると分かっていた標準形の定理 6 件（`Canonical`・`BuilderTyping`・`Progress`）と、場合の不足が確実な 5 件（`StoreLemmas`・`TySubstMain` の `substTy`・`SubstTyping`・`Canonical` の `inhabits'`・`BuilderCapture`）は、診断を待たずに同じ回で直した。これらを含めて直した宣言は 27 件である。計画が見込んだ印 NT の 118 定理より少ないのは、場合の不足は相互帰納の組ごとに一件として現れ、`match` の多くは添字の単一化で新しい場合を自動で除くためである。

回 2 の時点（試行の開始から約10分）で、残りが機械的な場合の追加だと分かり、枝の上端（3時間）の2倍を超える見込みはなかったので、止めずに本体へ進んだ。試行の8回は合計で約13分（01:22〜01:35、JST）だった。回 8 の後の差分がそのまま本体の出発点である（試行の差分を捨てて作り直してはいない）。

## 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `HasTypeVQ`（`Release/Typing.lean`） | 構成子 `V_Checked {Γ o R t} : B.valKind o = some t.kind → R.Mem t → HasTypeVQ P B Ψ Q C Γ (.checked t) (.opaque o (.fixed R))` を末尾に加えた |
| `Inhabits`（`Release/Typing.lean`） | 構成子 `checked {o R t} : Inhabits P (.opaque o (.fixed R)) (.checked t)` を加えた（「ずれと申し送り」1） |
| `Val.checked` の説明（`Release/Syntax.lean`） | 型付けは V-Checked だけで行うことに直した |
| `HasTypeVQ.inv_checked`（`Release/Lemmas/Inversion.lean`） | 「型付けの規則がない（`False`）」から逆転の補題 `∃ o R, T = .opaque o (.fixed R) ∧ B.valKind o = some t.kind ∧ R.Mem t` に置き換えた。V-Sub は不透明型を広げない（`Ty.Le` は関数の型の効果だけを広げる）ので、導出の型はちょうど葉の規則の型である |
| `inv_handle_failure`（`Release/Lemmas/FailureCont.lean`） | 証明は変えず、`set_option maxHeartbeats 800000 in` を付けた（相互帰納の型の構造的な再帰の展開が既定の上限を超えた。同じ値を `Interval/` の補題が使っている） |

相互帰納の場合を足した宣言: `Typing.lean` の `hideBuilders_strengthen_val`、`LocalScope.lean` の `HasTypeVQ.localRefs`、`Lemmas/Names.lean` の `HasTypeVQ.lambdaNamesWF`、`Lemmas/Rename.lean` の `HasTypeVQ.rename`・`store`・`hide`、`Lemmas/Irrelevant.lean` の `HasTypeVQ.subst_congr`、`Lemmas/NoFailContext.lean` の `HasTypeVQ.q_mono`、`Lemmas/Regularity.lean` の `HasTypeVQ.wf`（型 `O[R]` は文脈 0 で整形式。L20.2 の申し送り 11 のとおり `simp [Ty.WF]` で閉じた）、`Lemmas/OuterC.lean` の `HasTypeVQ.outer`、`Lemmas/SubstTyping.lean` の `HasTypeVQ.subst`、`Lemmas/StoreLemmas.lean` の `HasTypeVQ.notCont`、`Lemmas/TySubstMain.lean` の `HasTypeVQ.substTy`、`Lemmas/Canonical.lean` の `HasTypeVQ.inhabits'`、`Surface/Lemmas/BuilderCapture.lean` の `HasTypeVQ.reads`。網羅性の値の形の場合を足した宣言: `CoverageTypes.lean` の `inhabits_erase_transfer`、`Lemmas/TySubstMain.lean` の `Inhabits.of_substAt`、`Surface/Lemmas/PatternSupport.lean` の `Inhabits.consCongr`。標準形の定理の `checked` の場合（`canonical_boolean`・`canonical_ref`・`canonical_lazy`・`canonical_bytes`・`canonical_fn_or_raise`・`canonical_dict`）は、`inv_checked` が与える `T = .opaque …` と不透明型でない型との矛盾で閉じた（L20.3 の申し送り 7）。

代入・改名・shift の葉の場合は、定義の展開（`simp only [Val.subst]`・`[Val.substTyAt, Ty.substAt]`）で閉じた。L20.3 の `Val.subst_checked` などは使わずに済んだ。

## 置いた定理（`Release/Lemmas/Membership.lean`、新規、既定の import に追加）

| 群 | 名前 | 内容 |
|---|---|---|
| 逆転 | `HasTypeVQ.checked_iff` | 検査済みの対象の値の型付けは、ちょうど V-Checked が与えるもの |
| 範囲の拡大（葉の値） | `HasTypeVQ.checked_widen`・`checked_widen_covers`・`checked_widen_top` | 所属の包含 `R.Sub R'`、被覆 `R'.Covers R`（L10.4 の `Range.Covers.sound`）、Top への拡大 |
| 標準形 | `HasTypeVQ.canonical_opaque` | 不透明型 `O[ix]` の閉じた値は、`ix = fixed top` の不透明型の定数か、V-Checked の検査済みの対象の値 |
| 範囲の拡大（閉じた値） | `Scope.Domain.Range.eq_top_of_top_sub`・`HasTypeVQ.widen_opaque`・`widen_opaque_top` | 閉じた値の最上位の不透明型の範囲だけを広げる（L20.5 の `E_OpPrim` が使う形） |
| 旧の像 | `Builtins.NoValKind`（定義）・`HasTypeVQ.not_checked_of_noValKind`・`canonical_opaque_of_noValKind`・`const_opaqueTop`・`release_exists_iff_old`・`Model.builtins_noValKind` | 下の「同値の補題」 |
| 網羅性 | `Inhabits.opaque_iff`・`Pat.catchAll_of_matches_opaque`・`Exhaustive.opaqueTop_iff` | 同上 |
| 例 | `MembershipExample.checked_typed`・`not_typed_database`・`not_typed_other`・`widened`・`widened_top`・`not_exhaustive_nil`・`exhaustive_wild` | 下の「確かめた例」 |

拡大は葉の規則の補題と、閉じた値の最上位の不透明型の範囲だけに限った。関数の型・リストの要素などの内側へ範囲を広げる補題・規則は置いていない（L20 の段末の確認「非関数の共変なし」）。

## 同値の補題

旧の像は、組み込みの表の不透明型の名前がどれも対象の種類を持たない（`Builtins.NoValKind`、`∀ o, B.valKind o = none`）表と、範囲が Top だけの型である（既存の不透明型と資源の型は `valKind = none`。RV-PL10 中3 (b)）。

| 補題 | 内容 |
|---|---|
| `HasTypeVQ.not_checked_of_noValKind` | 旧の像の表では、検査済みの対象の値はどの型も持たない。V-Checked の結論が成り立たないので、どの導出も V-Checked を使わず、値の型付けの関係は旧の規則だけで作った関係と同じである |
| `HasTypeVQ.canonical_opaque_of_noValKind` | 旧の像の表では、不透明型の閉じた値は旧の不透明型の定数だけで、型の範囲は Top |
| `release_exists_iff_old` | 旧の像の表で、`release_exists` の欄は「資源の型の全ての不透明型の定数に解放の応答がある」ことと同値。欄が量化する値の集合が旧と同じことを示す |
| `Exhaustive.opaqueTop_iff` | 範囲が Top の不透明型の網羅性は、旧の値の形（不透明型の定数）の全てに当たるパターンがあることと同値。`Inhabits.checked` を加えても旧の像の網羅性は変わらない |
| `Inhabits.opaque_iff`・`Pat.catchAll_of_matches_opaque` | 不透明型の値の形は定数と検査済みの対象の値だけ。不透明型の定数に当たるパターンは変数か `_` だけ（`Exhaustive.opaqueTop_iff` の証明に使う） |
| `Model.builtins_noValKind` | 唯一の仮定の実例の表は旧の像の表である |

`delta_typed`・`io_typed`・`io_exists` は、字面を変えていない。欄が読む値の型付け（`HasTypeVs` と応答の型の `OutcomeTy`）は、旧の像の表では `not_checked_of_noValKind` により V-Checked を使わない。網羅性は範囲が Top の型では `Exhaustive.opaqueTop_iff` により変わらず、ほかの型の値の形は変えていない（`Inhabits.checked` の添字は `opaque o (fixed R)` だけ）。したがって、範囲の変数を持たず範囲が Top だけの型と旧の像の表では、四つの欄の内容は旧の内容と同値である。`release_exists` だけは、量化する値の集合を補題 `release_exists_iff_old` で直接示した。他の三つの欄について、旧の関係を別の帰納型として並べて同値を一つの定理にすることはしていない（旧の値の型付けの相互帰納の全体を複製することになるため）。

## 確かめた例（`Release/Lemmas/Membership.lean` の末尾、名前空間 `MembershipExample`）

表 `MembershipExample.builtins` は、唯一の仮定の実例の表 `Model.builtins` の `valKind` だけを替え、`Scope.PathIn` に種類 path を与えた。

- `checked_typed`: `/data/a.txt`（`Target.path ["data", "a.txt"]`）の検査済みの対象の値が、本番の型付け `HasTypeV` で `Scope.PathIn[/data/**]`（`Ty.opaque "Scope.PathIn" (.fixed (.path (.tree ["data"])))`）の型を持つ。所属は `decide` で確かめた。
- `not_typed_database`: 同じ値は `Scope.PathIn[/database/**]` の型を持たない。
- `not_typed_other`: 対象の種類を持たない名前（`File.Handle`）の範囲付きの型は持たない。
- `widened`・`widened_top`: 被覆による `/**` への拡大と、Top の型への拡大。
- `not_exhaustive_nil`・`exhaustive_wild`: `Scope.PathIn[/data/**]` の分岐のない照合は網羅的でなく、`_` の選択肢があれば網羅的である。

組み込みの関数はまだ範囲が Top の型だけを受け取り、V-Prim を変えていないので、`E_Prim`・`E_IO`・`E_OpPrim` の場合の証明は変わっていない（`Progress.lean`・`PresMain.lean` の差分は標準形の定理の `checked` の場合だけ）。

## 主定理の言明と前提の内容

七つの主定理（`Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`、`Surface.desugar_typed`・`surface_effect_soundness`）の言明の字面は、B_WORK と同じである（`Release/Theorems.lean`・`Surface/Theorems.lean` は変えていない。字面は `l20.2/results.md`「主定理の言明と前提の内容」に写したものと同じ）。証明は既定のビルドで検査し直した。

前提の内容の変化（旧の像の外だけで起きる）:

| 主定理 | 前提・結論 | 変更前（B_WORK） | 変更後 | 旧の像で旧と同値であることの補題 |
|---|---|---|---|---|
| `progress` | `StateTy P B s`、`P.WellTyped B`、`B.Assumptions P` | 検査済みの対象の値を含む状態・プログラムは型付かない。範囲が Top でない不透明型の値の照合は、値の形が空なので分岐なしでも網羅的 | 対象の種類を持つ名前の表では、検査済みの対象の値を含む状態とプログラムが型付く（前提が広がる）。範囲が Top でない不透明型の照合には変数か `_` が要る（`P.WellTyped` が狭まる）。`Assumptions` の `delta_typed`・`io_typed`・`io_exists`・`release_exists` は検査済みの対象の値を量化に含む | `not_checked_of_noValKind`・`canonical_opaque_of_noValKind`・`release_exists_iff_old`・`Exhaustive.opaqueTop_iff` |
| `preservation` | 同上と結論の `StateTy P B s'` | 同上 | 前提と結論の両方が同じく広がる | 同上 |
| `effect_soundness`・`effect_soundness_noLamNames` | `HasTypeC … m a Eff.empty`、`P.WellTyped B`、`B.Assumptions P` | 同上 | 同上 | 同上 |
| `step_sound` | `StateTy P B s`、`B.Assumptions P` | 同上 | 同上 | 同上 |
| `Surface.desugar_typed` | 前提 `p.WellFormed`・`p.WellTyped`・`hsig`、結論の `(desugarProgram opPrim p).WellTyped B` | 表層の構文と型付けは変えていない。ソースの照合の `ViewExhaustive` は判定の手順で定義され、変えていない | 前提の内容は不変。結論のコアの型付けの網羅性は、範囲が Top でない不透明型について強くなった（判定の手順の健全性の証明がそのまま通った） | 前提は不変。結論は `Exhaustive.opaqueTop_iff` |
| `Surface.surface_effect_soundness` | 前提 `hb : B.Assumptions (desugarProgram opPrim p)` | 同上 | `hb` の内容は上の `Assumptions` と同じく変わる | 上と同じ |

`Builtins.Assumptions` の欄は追加も字面の変更もしていない。前提の内容が変わるのは、値の型付けの関係と網羅性の値の形を通してだけである。

## 設計書

- 01-12「構文」の検査済みの対象の値の箇条: 「型付けの規則もない」を「型付けは V-Checked だけで行う」に直した。
- 01-12「型付け規則」の「値」: ` ```text ` の規則の並びに V-Checked を加え、【決定】の段落（規則、型の整形式性、V-Sub では広げないこと、拡大の補題、標準形、旧の像、小例）を加えた。同じ節の網羅性の値の形の段落に、不透明型の値の形（定数と検査済みの対象の値）と理由を加えた。このブロックは ASCII でない文字を含むので `spec_examples` の読み取りの対象外（`is_source_block`）であり、`spec_examples` は成功した。
- 07-04「証明する性質」: 【決定】の段落を一つ加え、性質 1〜3 の前提（状態の型付け・`Program.WellTyped`・型の付いた値を量化する四つの欄・網羅性・性質 1 の結論）の内容の変わり方、旧の像での同値の補題、設計者の承認の扱いを書いた。
- 07-04「01-12 との対応」: 行「型付け規則（値の所属の葉の規則 V-Checked）」（Rust は未接続）を加え、L20.3 の行の「型付けの規則はなく」を直した。
- 見出しは追加・改名していない（`git grep` の確認は不要）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 試行・途中の全体のビルド（8回） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 1（回 1〜7）、0（回 8） | 回ごとの `real` は 1.20〜127.61 秒 | [trial/](trial/) |
| 途中の全体のビルド（新しいファイルを既定の import に加えた後） | 同上 | 0 | 1.22 秒（ビルド済みの上に新しいファイルだけ） | [builds/build-09.log](builds/build-09.log) |
| 局所の単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`FailureCont.lean` 2回、`Membership.lean` 約6回） | 0 か 1（直して再実行） | 各 0.6〜5.5 秒 | 本書 |
| 全体のビルド（作業末の前の作り直し） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <l20.4>/lake-build.log` | 0。434 ジョブ、`Build completed successfully`。sorry なし | 158.82 秒 | ログは次の行で上書きした（値は本書に写した） |
| 全体のビルド（作業末） | 同上（`Membership.lean` の名前空間の直しと例の追加の後の作り直し） | 0。434 ジョブ、`Build completed successfully`。`declaration uses 'sorry'` なし。警告は `Interval/` の既存のものだけ | 1.22 秒（変わった `Membership.lean` だけを作り直し、他は検査済みのものを再生） | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 599a9a70a02010987d2c6ec0b30a0d2c7dd4ef02 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean`）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 599a9a70a02010987d2c6ec0b30a0d2c7dd4ef02` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 3.43 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l20.4>/axioms.lean`（56件の `#print axioms`） | 0 | 0.58 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

work は一度目（作業末のビルドの前の状態、終了 0、9.15 秒）の後に `Membership.lean` へ例を足したので、古くなった work をやり直した。上の表は二度目の値である。

公理: 56件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 53、`propext` だけ 2、依存なし 1）。`sorryAx` と独自の公理はない。対象は、旧の主定理 7件、`Membership.lean` の定理 23件、場合を足した・言明を変えた宣言 26件である。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（作業末の前の作り直し、`Typing.lean` の説明の直しで下流の全てを検査し直した） | 2654027776 | 2531.1 | 2.47 |
| 試行の回 7（下流の大半を検査した回） | 2648571904 | 2525.9 | 2.47 |
| 全体のビルド（作業末、`Membership.lean` だけの作り直し） | 1513897984 | 1443.8 | 1.41 |
| 公理の確かめ（`lake env lean -M 12288`、`Benitoite` 全体を読み込む） | 1507131392 | 1437.3 | 1.40 |
| work の検査全体（一度目。`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1384300544 | 1320.2 | 1.29 |
| work の検査全体（二度目） | 77824000 | 74.2 | 0.07 |

二度目の work の値は一度目より小さい。`/usr/bin/time` が報告するのは、待ち合わせた子孫の中で最大の一プロセスの値である。二度目は cargo のテストのバイナリと Lake の作り直しが既にできていたので、大きなプロセスが走らなかったと考えている（確かめていない）。局所の単一ファイルの検査は計時していない（値なし。0 ではない）。`-M 12288` は変えていない。

## 失敗と修正

- 試行の最初の起動で `lake build -k` と打ち、`lake` が `unknown short option '-k'` で終了した（終了 1、ビルドなし）。引数なしで起動し直した。その記録は回 1 のログで上書きした。
- 試行の回 1〜7 の破損は「試行」の表のとおりで、全て場合の追加か網羅性の値の形の場合の追加で直した。
- 回 4: `FailureCont.lean` の `inv_handle_failure` が heartbeats の上限（200000）を超えた。証明を変えず、上限を 800000 にした（「変えた定義」）。
- 回 6 の前: 標準形の定理 `HasTypeVQ.inhabits'` の V-Checked の場合で、`Inhabits` に不透明型の検査済みの対象の値の場合がなく閉じないことが分かった。`Inhabits` に場合を加えた（「ずれと申し送り」1）。
- `Membership.lean` の単一ファイルの検査で、`Inhabits.opaque_iff` の `cases` の依存の除去の失敗（`Const.type` の `match` との単一化。等式を戻してから `cases` した）、`Inhabits.const` の暗黙の引数の推論の失敗、`Range.eq_top_of_top_sub` を `Benitoite.Release` の下の名前空間に置いてしまったこと（`_root_.Benitoite.Scope.Domain.Range` へ移した）を直した。
- `Inversion.lean` に一度置いた補題 `HasTypeVQ.checked_opaque`・`checked_of_valKind_none` は使わなかったので消した（`Membership.lean` の補題が同じ内容を含む）。
- 作業末の前の全体のビルドのログ（158.82 秒の作り直し）を、作業末のビルドで同じファイル名に上書きした。値は本書に写した。
- ログの手元の絶対パスは `<wt>`・`<repo>`・`<home>`・`<tmp>` へ置き換えた。

## ずれと申し送り

計画からのずれ:

1. **網羅性の値の形 `Inhabits` を変えた（取りまとめの確認を求める）。** 計画の L20.4 の行は値の型付けの葉の規則だけを挙げていた。しかし、範囲が Top でない不透明型 `O[R]` には、変更前は値の形が一つもなく（不透明型の定数の型は `O[Top]`）、その型の値の分岐のない `match` も網羅的だった。V-Checked でその型の閉じた値ができると、`match checked(t) {}` が型付いて進めなくなり、`progress` が成り立たない（標準形の定理 `HasTypeVQ.inhabits'` の V-Checked の場合が閉じない）。そこで `Inhabits` に `checked`（`O[fixed R]` の検査済みの対象の値）を加えた。結果として `P.WellTyped` の内容は、範囲が Top でない不透明型の照合に変数か `_` を求める形に狭まる。範囲が Top の不透明型では、不透明型の定数が既に属しているので網羅性は変わらない（`Exhaustive.opaqueTop_iff`）。表層のソースの照合の `ViewExhaustive` は判定の手順で定義されていて変えておらず、判定の手順の健全性の証明はそのまま通った。担当は、これを「値の所属の規則」（問18 の行 7）の一部（値の型付けの規則と、それに伴う網羅性の値の形）と判断して進めた。07-04 にもこの扱いを書いた。取りまとめがこの判断を表の範囲外と見るなら、代案は (a) `Exhaustive`・`Inhabits` に表の `valKind` を渡し、対象の種類を持つ名前の不透明型だけに値の形を加える（網羅性の使用箇所が多く、表層の網羅性の証明にも及ぶ）、(b) 範囲が Top でない不透明型の型付けを禁じる（L20.5 以降の意味が崩れる）で、どちらも推さない。
2. 旧の像での同値は、`release_exists` だけを欄の水準の同値の補題（`release_exists_iff_old`）にし、`delta_typed`・`io_typed`・`io_exists` は、V-Checked が使えないことと網羅性の同値の二つの補題から導く説明にとどめた（「同値の補題」の最後の段落）。旧の値の型付けの相互帰納を別に並べた形式の同値の定理は置いていない。
3. 新しいファイル `Release/Lemmas/Membership.lean` は計画に候補の名前がなかった。計画の対象ファイルの `Release/Model.lean` は変えていない（例は新しいファイルに置き、`Model.builtins_valKind` を使った）。
4. 試行は、一度の全体のビルドで数える形ではなく、直しながら8回のビルドを重ねる形で行った（「試行」）。

### L20.5 への申し送り

5. `E_OpPrim` の捕捉した引数の拡大は `HasTypeVQ.widen_opaque_top`（閉じた値の最上位の不透明型の範囲を Top へ）と `widen_opaque`（所属の包含）を使える。L20.3 の `PrimSig.inst_params_agree_off_target`・`inst_params_target` と組み合わせる見込みである（確かめていない）。
6. 組み込みの関数が範囲付きの値型の引数を受け取ると、`delta_typed` などが量化する値に検査済みの対象の値が入る。値の取り出しは `HasTypeVQ.canonical_opaque`（定数か検査済みの対象の値、所属の証拠つき）を使える。範囲が Top の型の閉じた値にも、対象の種類を持つ名前なら検査済みの対象の値が入る（V-Checked は R = Top を許す）。
7. `MembershipExample.builtins` は `Model.builtins` の `valKind` だけを替えた表であり、`Assumptions` を満たすことは示していない（範囲付きの値型の項目がなく、`delta_typed` などは型付く値を変えないので満たす見込みだが、確かめていない）。

### L20.6・L20.7・L40 への申し送り

8. L20.7: 表の新版（`effKind`・`valKind`・`admitsR` を持つ表）は `Builtins.NoValKind` を満たさないので、`release_exists_iff_old` などの旧の像の補題は使えない。範囲付きの値型が資源の型でないこと（`Scope.PathIn`・`Http.RequestIn` は `isResource = false`）を表の項目に置くと、`release_exists` の量化は旧と同じになる見込みである。
9. L40.4（表層の値の型付けと R、印 NS）: 表層の構文は検査済みの対象の値を持たない。表層の検査の関数を範囲付きの値型へ広げるときは、`MembershipExample.not_exhaustive_nil` のとおり、範囲付きの値型の照合に変数か `_` が要ることを判定の手順が扱う（今の判定の手順は不透明型を変数か `_` でだけ覆う型として扱っており、健全性の証明がそのまま通った）。
10. L50.1: 交換形式は検査済みの対象の値を持たない（L20.3 の申し送り 14 のまま）。網羅性の値の形の変更は交換形式に現れない。

### 取りまとめへ

11. 上の 1（網羅性の値の形の変更を問18 の行 7 に含める判断）の確認を求める。
12. 新しい欄の追加・公理の追加・主定理の字面の変更はない。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 01:22（JST、依頼文を読み始めた時刻） |
| 終了 | 01:53 ごろ（本書の作成まで） |
| 外側の所要 | 約31分 |
| 能動時間（試行） | 約13分（01:22〜01:35。読む約3分、場合の追加と網羅性の値の形の追加約10分。ビルドの待ちを除く） |
| 能動時間（本体） | 約15分（`Membership.lean` の定義と証明約6分、設計書約4分、本書と記録の整理約5分。作業末のビルドと検査の待ちを除く） |
| ビルドの回数と時間 | 試行の全体のビルド 8回（1.20〜127.61 秒）、途中 1回（1.22 秒）、作業末の前の作り直し 158.82 秒、作業末 1.22 秒、局所の単一ファイル 約8回（各数秒） |
| 検査 | work 2回（9.15 秒・3.43 秒、dry-run 各数秒）、公理の確かめ 3回（各 0.6 秒前後。1回目は名前の誤りで終了 1、3回目は例を足した後のやり直し） |
| 待ち | 排他の道具の待ちは記録上なし。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.4〜3時間の範囲内。上端の2倍（6時間）を超えていない |
