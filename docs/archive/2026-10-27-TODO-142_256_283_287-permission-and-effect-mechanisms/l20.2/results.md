# L20.2 の結果: 範囲の変数の整形式性（一度の切り替え）

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L20.2（plan-l10-l50「L20」の表の L20.2 の行）。一度の切り替えの枝 |
| B_WORK | `361ca673b4c98d4ea04367f3b08d65559743a6de`（本線、L10 の全枝の取り込みの後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l20.2`。git の状態は変えていない |
| 閉じた範囲 | `Ty.WF`・`Ty.VarsIn` に範囲の変数の個数の文脈 `nr` を加え、不透明型の範囲の位置に `Ix.WF nr` を求めた。`Ty.VarsIn`・`Eff.VarsIn` は名前の原子の範囲の位置にも同じ条件を求める。プログラムの宣言・項・型付け・状態と組み込みの署名は文脈 0 で読む。shift・subst・正規化・正則性の補題を直し、新旧の同値の補題を置いた。既定の全入口のビルドが sorry なしで通り、`desugar_typed` は `WellFormed` の結論に新しい条件を含んだまま通る |
| 未完 | なし（計画の手順の範囲）。プログラムの水準（`Val.VarsIn`・`Program.WellFormed`・`StateTy`）の新旧の同値は、型と署名と欄の水準の補題だけを置き、プログラム全体の旧の定義の写しは置いていない（「ずれと申し送り」4） |
| 適用した前提の変更の行 | 「P1 による `Ty.WF` の文脈（`P.WellFormed`、`desugar_typed` の結論、`sat_unconstrained`・`sat_local`・`admits_local`、`K_Empty`）」（L10〜L50 の計画の決定 (1)）。あわせて、表の L20.3 の行「`sig_scoped` の範囲の変数の上限」（問18 の行 4）と「表層の側の前提（`desugar_typed` の `hsig`）」を、範囲の変数 0 の形で前倒しした（「停止条件」） |
| 停止条件 | 該当しないと判断した。ただし、括弧の中に挙がっていない前提の内容も同じ読み替えで変わる（下の「主定理の言明と前提の内容」）。取りまとめと設計者の確認を求める |

## 試行（最初の30〜60分）

plan「検査の割り当て」の「L の一度の切り替えの試行ビルド」の行に従った。件数の詳細は [trial/counts.md](trial/counts.md)、差分の出発点は [trial/trial-1.diff](trial/trial-1.diff.gz)、各回のログは `trial/build-<回>.log`、数えた道具は [trial/tools/count.py](trial/tools/count.py) にある。

- 最初の差分は、七つの定義（`Ty.WF`・`Ty.WFList`・`Eff.WF`・`Ty.VarsIn`・`Ty.VarsInList`・`Eff.VarsIn`・`Eff.VarsInList`）に先頭の引数 `nr` を加え、利用側の呼び出しに機械的に `0` を挿入したもの（58ファイル）である。
- 10回のビルドで全体が通った。回 1〜9 を通した一意の壊れた宣言は 37、ファイルは 16（うち 4 宣言は、途中で外した `Eff.WF` の原子の条件だけによる）。各回の未検査のモジュールは 212・207・204・189・103・88・59・204・17・0（総数 284）である。
- 試行の所要は約25分（23:35〜23:59）で、枝の上端の2倍（6時間）を超える見込みはなかった。代案（新しい定義を並べて一群ずつ移す方式）には切り替えず、そのまま本体へ進めた。

## 変えた定義

| 定義 | 変更 |
|---|---|
| `Ty.WF nr n`・`Ty.WFList nr n`・`Eff.WF nr n`（`Release/Typing.lean`） | 文脈 `nr` を加えた。不透明型の腕を `True` から `ix.WF nr` にした。`Eff.WF` は Fail 型だけを読み、名前の原子の範囲の位置を読まない |
| `Ty.VarsIn nr n pe`・`Ty.VarsInList`・`Eff.VarsIn`・`Eff.VarsInList`（`Release/TypeVariables.lean`） | 文脈 `nr` を加えた。不透明型の腕は `ix.WF nr`。`Eff.VarsIn` に第三の項 `∀ x, a x = true → x.WF nr`（名前の原子の条件）を加えた |
| `Ty.RawWF nr n`・`Eff.RawWF`（`Release/TypeBounds.lean`） | 同じ文脈と不透明型の腕（正規化の前の補助述語） |
| `Atom.WF nr`（`Release/Atom.lean`、新規） | 名前の原子は `ix.WF nr`、行の原子は条件なし。`Decidable` の実例と `simp` の補題 `Atom.wf_name`・`Atom.wf_rho`・`Atom.ix_wf_fixed` |
| `Val.VarsIn`・`Comp.VarsIn` ほか、`Def.Scoped`・`OpDecl.Scoped`・`PrimSig.Scoped`・`MethSig.Scoped`・`ImplDecl.Scoped`（`Release/WellFormed.lean`）、`LocTy.WF`・`Frame.Closed` ほか（`Release/Semantics.lean`）、型付けの規則と `ContTy`（`Release/Typing.lean`・`Semantics.lean`）、`Builtins.Assumptions`（`Release/Assumptions.lean`）、表層の `Program.WellFormed` と型付け（`Surface/WellFormed.lean`・`Typing.lean`） | 字面の上で `Ty.WF 0 …`・`Ty.VarsIn 0 …` を読むだけの変更（文脈 0 の挿入） |
| 表層の検査器の有限支持の判定（`Surface/FinitePredicates.lean`・`CheckPredicates.lean`・`Check.lean`） | `wfTy`・`cleanTy` の不透明型の腕で `decide (ix.WF 0)`、`cleanEff` に原子の判定 `atomsWF` を加えた。部分適用した構成子の効果の検査を `cleanTys … εargs.fails` から `cleanTopEff … εargs`（Fail 型と原子の判定）に替えた。診断の文言は変えていない |

補題の言明の一般化: `Release/TypeRegularity.lean`・`TypeBounds.lean`・`TypeVariables.lean`・`TypeCongruence.lean` の補題（`Ty.WF.canonical`・`Ty.norm_WF`・`Ty.WF.mono`・`Ty.shift_of_wf`・`Ty.bind_wf`・`Ty.shift_wf`・`Ty.subst_wf`・`Ty.substAt_wf`・`Eff.bind_wf`・`Eff.subst_wf`・`Ty.VarsIn.wf`・`Ty.VarsIn.mono` など）は任意の `nr` について言明した。型付けの水準の補題（`Release/Lemmas/*`・`Surface/Lemmas/*`）は文脈 0 のままである。新しい補助の補題は `Eff.substAtoms_wf`・`Eff.rawShift_atoms`・`Eff.substAt_atoms_wf`（`TypeBounds.lean`）、`Eff.single_atoms_wf`（`TypeRegularity.lean`）、`atomsWF_spec`・`cleanTopEff_spec`（`FinitePredicates.lean`）である。

### 決めたことと理由

1. `Eff.WF` は名前の原子を読まない。試行の回 1〜7 では `Eff.WF` にも原子の条件を入れたが、`pres_failure`（E-OpFail の保存）で、保存する継続の効果 `captureEff Rest ec` の `Rest` の原子が条件を満たすことを示せなかった。`Rest` は継続の型付け `K_Handle_Fail` の導出が選ぶ効果で、`Rest ⊆ ε` だけが分かり、外側の `K_Handle` は処理する名前の任意の範囲の原子を入力の効果に許すので、`ε` の原子にも条件がない。原子の条件を `Eff.WF` に置くには `K_Handle_Fail` に新しい前提が要り、これは表にない `StateTy` の変更である。そこで原子の条件は、宣言と項の構文の条件 `Eff.VarsIn` だけに置いた（利用者の宣言と項には範囲の変数を置けない）。型付けの導出の中の型（包含で広げた潜在効果など）は範囲の変数の原子を持ちうるが、L10.5 の被覆はそれを同じ原子だけで覆うので、意味は変わらない。
2. `PrimSig.Scoped` も文脈 0 で読む。正則性の `HasTypeVQ.wf` の `V_Prim` の腕は、`sig_scoped` から署名の型の整形式を得る。署名に範囲の変数を許したままでは、型付けした値の型の整形式（文脈 0）を導けない。L20.3 が署名に `nranges` を持たせるまでは、署名の範囲の変数は 0 個として読む。
3. 新しいファイル `Release/RangeWF.lean` に、比較のためだけの旧の定義の写しと同値の補題を置いた（計画に候補の名前がなかった）。既定の import（`Benitoite.lean`）に加えた。

## 同値の補題（`Release/RangeWF.lean`）

旧の定義の写し `Ty.WFOld`・`Ty.WFListOld`・`Eff.WFOld`、`Ty.VarsInOld`・`Ty.VarsInListOld`・`Eff.VarsInOld`、`PrimSig.ScopedOld` と、範囲の位置の条件 `Ty.OpaqueRangesIn nr`（不透明型の位置）・`Ty.RangesIn nr`（不透明型と名前の原子の位置。`nr = 0` で「範囲の変数のない型」）を置いた。

| 補題 | 内容 |
|---|---|
| `Ty.wf_iff_old`・`Ty.wfList_iff_old`・`Eff.wf_iff_old` | `Ty.WF nr n t ↔ Ty.WFOld n t ∧ Ty.OpaqueRangesIn nr t`（新しい定義の分解） |
| `Ty.varsIn_iff_old`・`Ty.varsInList_iff_old`・`Eff.varsIn_iff_old` | `Ty.VarsIn nr n pe t ↔ Ty.VarsInOld n pe t ∧ Ty.RangesIn nr t` |
| `Ty.wf_iff_old_of_rangeFree`・`Ty.wf_iff_old_of_opaqueRangesIn`・`Ty.varsIn_iff_old_of_rangeFree` | 範囲の変数のない型（Top だけの旧の像を含む）で新旧が同値 |
| `Ty.WF.old`・`Ty.VarsIn.old` | 新しい定義から旧の定義が従う |
| `sat_unconstrained_iff_old`・`sat_local_iff_old`・`admits_local_iff_old` | 新しい欄 ↔ 旧の欄を不透明型の範囲の位置に範囲の変数のない型に制限したもの |
| `sat_unconstrained_of_old`・`sat_local_of_old`・`admits_local_of_old` | 旧の欄から新しい欄が従う（新しい欄は前提が強いぶん弱い） |
| `PrimSig.scoped_iff_old`・`sig_scoped_iff_old_of_rangeFree` | `s.Scoped ↔ s.ScopedOld ∧ s.RangesIn 0`。範囲の変数のない署名だけの表で新旧の `sig_scoped` が同値 |
| `Ty.RangesIn.opaque`・`Ty.OpaqueRangesIn.mono`・`ix_wf_mono` | 補助 |

`K_Empty` の前提 `Ty.WF 0 0 a` は `Ty.wf_iff_old_of_rangeFree` で旧の前提と同値になる。

## 確かめた例

`Release/RangeWF.lean` の末尾の `example`:

- `¬ Ty.WF 0 0 (.opaque "PathIn" (.rvar 0))`（プログラムの文脈で範囲の変数を持つ不透明型を拒否する）と `Ty.WF 1 0 (.opaque "PathIn" (.rvar 0))`（範囲の変数一つの文脈では整形式）。
- Top の不透明型は任意の文脈で新旧の `Ty.WF` を満たす。
- `¬ Eff.VarsIn 0 0 pe (Eff.ofAtoms (· == .name "File.Write" (.rvar 0)))`。
- 潜在効果に `File.Write[rvar 0]` を持つ関数型は、新しい `Ty.VarsIn 0` で拒否され、旧の `Ty.VarsInOld` では受理される。

## 主定理の言明と前提の内容

七つの主定理（`Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`、`Surface.desugar_typed`・`surface_effect_soundness`）の言明の字面は、変更の前後で同じである。字面は次のとおり（変更の前後で共通）。

- `progress (hwt : P.WellTyped B) (hdecl : P.EffectsOk B) (hb : B.Assumptions P) : StateTy P B s → s.Final ∨ ∃ l s', Step P B s l s'`
- `preservation (hwf : P.WellFormed) (hwt) (hdecl) (hb) : StateTy P B s → Step P B s l s' → StateTy P B s'`
- `effect_soundness (hwf) (hwt) (hdecl) (hb) : HasTypeC P B StoreTy.empty [] [] none m a Eff.empty → m.ClosedNoEffVars → ∀ s, Steps … s → (∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s`（`effect_soundness_noLamNames` は `Comp.VarsInNoLamNames 0 (fun _ => False) m` を前提に持つ）
- `step_sound (hb) (oracle) (rel) (fresh) (horacle) (hrel) (hfresh) : StateTy P B s → step … s = some (l, s') → Step P B s l s'`
- `desugar_typed (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim) (hsig : ∀ b s, B.sig b = some s → s.Scoped) : (desugarProgram opPrim p).WellFormed ∧ … .WellTyped B ∧ … .EffectsOk B`
- `surface_effect_soundness (hwf) (hwt) (hb) (hmain : p.HasMain Eff.empty) : ∀ s, Steps … s → …`

前提の内容の変更（いずれも `Ty.WF`・`Ty.VarsIn` を文脈 0 で読み、不透明型・名前の原子の範囲の変数を拒否する同じ読み替え）:

| 前提・結論 | 変わる箇所 | 旧の像での同値 |
|---|---|---|
| `P.WellFormed`（`preservation`・`effect_soundness`、`desugar_typed` の結論） | 宣言の型・本体の `Ty.VarsIn 0`（範囲の位置） | 型の水準で `Ty.varsIn_iff_old_of_rangeFree` |
| `B.Assumptions` の `sat_unconstrained`・`sat_local`・`admits_local` | 前提の `Ty.WF 0` | `sat_unconstrained_iff_old` ほか（上の表） |
| `B.Assumptions` の `sig_scoped`、`desugar_typed` の `hsig` | `PrimSig.Scoped` の `Ty.VarsIn 0`（L20.3 の行の前倒し） | `PrimSig.scoped_iff_old`・`sig_scoped_iff_old_of_rangeFree` |
| `B.Assumptions` の `admits_subst`・`sat_subst` | `ClosedSat` の `Ty.WF 0 0`（前提が強くなり、欄は弱くなる） | `Ty.wf_iff_old_of_rangeFree` |
| `B.Assumptions` の `delta_typed`・`io_typed`・`io_exists`・`release_exists` | 量化する `HasTypeV(s)` の規則の整形式の前提、`OutcomeTy` の `Val.VarsIn 0` | 型の水準の同値だけ（欄の水準の補題は置いていない） |
| `P.WellTyped`、`HasTypeC`（`effect_soundness`）、表層の `p.WellTyped` | 型付けの規則の `Ty.WF` の前提（V-Lam・V-Sub・C-Sub・Admissible の型の像など） | 型の水準の同値 |
| `StateTy`（`progress`・`preservation` の前提と結論、`step_sound`） | `StoreOk` の `LocTy.WF`、`ContTy` の `K_Empty`・`K_Let`・`K_Mark`・`K_Handle`・`K_Handle_Fail` の `Ty.WF 0 0`、`Comp.VarsIn`・`Cont.Closed`・`Store.Closed` | 型の水準の同値 |
| `m.ClosedNoEffVars`・`Comp.VarsInNoLamNames`（`effect_soundness`・`_noLamNames`） | `Comp.VarsIn` の型と効果の範囲の位置 | 型の水準の同値 |
| 表層の `p.WellFormed`（`desugar_typed`・`surface_effect_soundness`） | Release の `Ty.VarsIn 0` を使う型注釈の条件 | 型の水準の同値 |

範囲の変数を含む型と署名では、前提が強くなる（`sat_*` などの欄は弱くなる）。`preservation` の結論の `StateTy` も同じ向きに強くなり、前提と結論の両方で同じ条件を保つ。範囲の変数のない型と署名では、どの箇所も旧の内容と同じである。

## 設計書

- 01-12「型付け規則」に【決定】を一つ加えた（文脈 `nr`、不透明型と名前の原子の条件、文脈 0 で読む範囲、`Eff.WF` が原子を読まない理由、旧の定義との同値）。「表記」に、プログラムの型と項は範囲の変数を持たないことを一文加えた。
- 07-04「証明する性質」に、前提の内容の変更と旧の像での同値の【決定】を加えた。「形式化で仮定するもの」の型付けの前提の段落と、宣言の変数の範囲の箇条に、範囲の変数の条件を加えた。「01-12 との対応」の表に「型付け規則（範囲の変数の整形式性）」の行（Rust は未接続）を加えた。
- 見出しは変えていない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 試行ビルド（10回） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 1（回 1〜9）、0（回 10） | 1.07〜157.28 秒（上の「試行」） | [trial/](trial/) |
| 局所の単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`TypeBounds`・`TypeVariables`・`Closed`・`TypeRegularity`・`FinitePredicates`・`RangeWF` ほか、計14回ほど） | 0 か 1（直して再実行） | 各数秒以内（計時なし） | 本書 |
| 本体の途中の全体のビルド | 同じ排他の道具（2回） | 0・0 | 171.23 秒・156.05 秒 | 下の最大常駐量 |
| 全体のビルド（作業末） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <l20.2>/lake-build.log` | 0。432ジョブ、`Build completed successfully`。`declaration uses 'sorry'` なし。`Interval/` の既存の警告のほかに警告なし | 156.05 秒（排他の待ち 0 秒） | [lake-build.log](lake-build.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 361ca673b4c98d4ea04367f3b08d65559743a6de --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite.lean` による）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 361ca673b4c98d4ea04367f3b08d65559743a6de` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.82 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l20.2>/axioms.lean`（104件の `#print axioms`） | 0 | 0.64 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 104件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 76、`propext`・`Quot.sound` 4、`propext` だけ 1、依存なし 23）。`sorryAx` と独自の公理はない。対象は、`RangeWF.lean` の新しい宣言40件、ほかのファイルの新しい宣言12件、定義を変えた宣言と言明を一般化した補題45件、旧の主定理7件である。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（作業末） | 2664103936 | 2540.7 | 2.48 |
| 試行ビルドの最大（回 9） | 2644508672 | 2522.0 | 2.46 |
| 公理の確かめ（`lake env lean -M 12288`、`Benitoite` 全体を読み込む） | 1505542144 | 1435.8 | 1.40 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1383546880 | 1319.5 | 1.29 |

局所の単一ファイルの検査は計時していない（値なし。0 ではない）。`-M 12288` は変えていない。

## 失敗と修正

- 試行の回 1〜9 の失敗は上の「試行」と [trial/counts.md](trial/counts.md) のとおりで、各回の誤りを直して次の回へ進んだ。
- 回 5 の修正で `Regularity.lean` に不要な `simp` の引数の警告を出した。回 6 で書き換え、回 8 で `Eff.WF` を戻したときに元の証明に戻した。
- 回 7 の `pres_failure` の誤りから、`Eff.WF` の原子の条件を外した（「決めたことと理由」1）。外したことで回 8 で `Eff.VarsIn.wf` が壊れ、回 9・10 で直した。
- `RangeWF.lean` の最初の単一ファイルの検査で、`cases … with | opaque …` の `opaque` が予約語として読まれて終了1。`«opaque»` と書いて直した。続けて `Decidable` の実例のない `Eff.Canonical` を `decide` で閉じようとして終了1。`rfl` で閉じた。
- `Atom.WF` の `Decidable` の実例がなく、`FinitePredicates.lean` の `atomsWF` が終了1。実例を `Atom.lean` に置いた。
- 07-04 を標準入力の Python で書き換えようとして、macOS の Python が多バイト文字で `SyntaxError: Non-UTF-8 code` を出した（L10.2・L10.5 の記録と同じ）。スクリプトをファイルに書いて実行した。結果に影響しない。
- 使わなかった補題（`Atom.WF.mono`・`Atom.TopImage.wf`・`Eff.bind_atoms_wf`・`Eff.empty_atoms_wf`）を消した。自動の束縛に頼っていた `nr` を、言明を一般化した補題で `{nr : Nat}` と明示した。

## ずれと申し送り

計画からのずれ:

1. `Eff.WF` に名前の原子の条件を入れていない（「決めたことと理由」1）。原子の条件は `Ty.VarsIn`・`Eff.VarsIn` だけにある。
2. `sig_scoped`（`PrimSig.Scoped`）と `desugar_typed` の `hsig` の内容の変更を、L20.3 の行から範囲の変数 0 の形で前倒しした（「決めたことと理由」2）。L20.3 の完了の条件の「範囲の変数 0 の表で新旧の `sig_scoped` が同値」は `sig_scoped_iff_old_of_rangeFree` が示している。
3. 表層の検査器（`Surface/Check.lean`）の部分適用した構成子の効果の検査に、原子の判定を加えた（`cleanTopEff`）。範囲の位置が Top の入力では判定は変わらない。
4. プログラムの水準の新旧の同値（`Val.VarsIn`・`Program.WellFormed`・`StateTy` の旧の定義の写しとの同値）は置いていない。計画の手順（型と三つの欄）の外であり、各型の位置の同値から構造に沿って従う。
5. 新しいファイル `Release/RangeWF.lean` は計画の候補の名前になかった。

### 取りまとめへ

6. 前提の内容の変更は、L10〜L50 の計画の決定 (1) の括弧の中の箇所（`P.WellFormed`・`desugar_typed` の結論・三つの欄・`K_Empty`）より広い。`Ty.WF`・`Ty.VarsIn` の定義を変えるので、型付けの規則、`StoreOk`、`K_Empty` 以外の継続の規則、閉じた項の条件、`ClosedSat` を通じた `admits_subst`・`sat_subst`、`OutcomeTy` と型付けを通じた `delta_typed`・`io_typed`・`io_exists`・`release_exists`、`sig_scoped`・`hsig` の内容も同じ読み替えで変わる（上の表）。どれも範囲の変数のない型では旧の内容と同じである。決定 (1) の範囲に入ると判断して進めたが、設計者の確認を求める。
7. 新しい欄の追加・公理の追加・主定理の字面の変更はない。

### L20.3〜L20.7・L40 への申し送り

8. L20.3: `PrimSig.Scoped` の `Ty.VarsIn 0 s.ntys …` の `0` を `s.nranges` に替える。`PrimSig.ScopedOld`・`PrimSig.scoped_iff_old` も同じ形に直す。正則性の `HasTypeVQ.wf` の `V_Prim` の腕は署名の型の `Ty.WF 0` を `sig_scoped` から得ているので、L20.5 で `s.inst rs` を使うときは、個数の合う閉じた列で具体化した型が文脈 0 を満たすこと（`Ix.inst_wf_zero` の型への持ち上げ）が要る。
9. L20.3: 型の水準の移動・代入の整形式の補題（`Release/TypeBounds.lean`・`TypeRegularity.lean`・`TypeVariables.lean`）は任意の `nr` で使える。`Ty.VarsIn` の代入の補題（`Release/Lemmas/Closed.lean` の `Ty.VarsIn.substAt`、`VariableBind.lean` の `bind_clean`、`Surface/Lemmas/ShiftClean.lean`）は文脈 0 だけであり、署名の範囲の変数を残したまま代入するなら一般化が要る。
10. L20.3〜L20.7: `Eff.WF` は原子を読まないので、型付けの導出の中の効果（包含で広げた潜在効果、`K_Handle` の入力の効果）は範囲の変数の原子を持ちうる。プログラムの項と宣言の効果は `Eff.VarsIn 0` により範囲の変数の原子を持たない。L10.5 の申し送り 3 の「プログラムの効果の被覆は閉じた範囲の原子と行の原子だけを扱う」は、項と宣言の効果について成り立ち、導出の中の効果については成り立たない（`Atom.Covers` は範囲の変数の原子を同じ原子だけで覆うので、意味は変わらない）。
11. L20.4: 葉の規則が与える型 `Ty.opaque o (.fixed R)` は文脈 0 で整形式である（`Atom.ix_wf_fixed` の `simp` で閉じる）。
12. L40.4: 表層の型注釈は Release の `Ty.VarsIn 0` を使うので、表層の型にも範囲の変数を置けない。表層の検査器の `wfTy`・`cleanTy`・`cleanEff`・`cleanTopEff` は範囲の変数を拒否する。L40.4 の Surface の P1 は、この状態から表層の旧の像での同値を示せばよい見込みである（確かめていない）。
13. L50.2: 交換の入力の範囲の変数の拒否は、Lean の検査器の側では上の判定で既に拒否される。交換の読み込みの側は L50.2 のとおり。
14. L50.3: `Ty.WFOld`・`Ty.VarsInOld`・`PrimSig.ScopedOld` ほかの比較のための写しは、旧の互換層の整理の対象である。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 23:28 ごろ（JST、依頼文を読み始めた時刻） |
| 終了 | 00:20 ごろ（本書の作成まで） |
| 外側の所要 | 約52分 |
| 能動時間（試行） | 約20分（23:35〜23:59。定義の変更と機械的な書き換え約5分、回ごとの修正約15分。ビルドの待ちを除く） |
| 能動時間（本体） | 約25分（文書と定義を読む約7分、同値の補題と例約8分、設計書約5分、本書と記録の整理約5分）。試行の後半で本体の修正もほぼ終えたので、試行と本体の境は回 10 の成功（23:59）とした |
| ビルドの回数と時間 | 試行 10回（計 約11分）、本体の全体のビルド 2回（171.23 秒・156.05 秒、作業末を含む）、局所の単一ファイル 約14回（各数秒） |
| 検査 | work 1回 9.82 秒（dry-run 数秒）、公理の確かめ 0.64 秒 |
| 待ち | 排他の道具の待ち 0 秒。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 1〜3時間の下端を下回った。上端の2倍（6時間）を超えていない |
