# L20.3 の結果: 値の形と署名の範囲の変数・表のデータ

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L20.3（plan-l10-l50「L20」の表の L20.3 の行） |
| B_WORK | `c7a75b8549d5c00374a6bdc6d7f444d3eca8f1df`（本線、L20.2 の取り込みと前提の変更の了承の記録の後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l20.3`。git の状態は変えていない |
| 閉じた範囲 | 値の検査済みの対象の構成子 `Val.checked` と、`Val` を場合分けする定義・定理の追随。L20.4 の葉の場合の補題。`PrimSig.rkinds`・`PrimSig.nranges`、範囲の変数の番号の上限で読む `PrimSig.ScopedRanges`。具体化 `PrimSig.inst`（引数は最上位の対象の位置だけ、結果と効果は全ての位置）と `inst_params_agree_off_target`、具体化と型代入・行代入・shift・正規化の交換、空の列の具体化、個数の合う閉じた列での整形式性。`Builtins.RangeAdmissible`（個数と種類・`Range.WF`・`Range.Canonical`・表の制約、全て Top の列は常に許す）。表のデータ `effKind`・`valKind`・`admitsR`。範囲の変数 0 の表での `sig_scoped` の同値。01-12・07-04 の反映。既定の全入口のビルドが sorry なしで通る |
| 未完・ずれ | `PrimSig.Scoped`（`sig_scoped`・`hsig` が読む定義）は文脈 0 のまま残し、範囲の変数の個数で読む形は別名 `PrimSig.ScopedRanges` に置いた（「ずれと申し送り」1）。引数の型の文脈 0 の整形式性は、引数の範囲の変数が最上位の対象の位置だけにある条件 `PrimSig.TargetRangesOnly` のもとで示した。この条件の置き場所は未決である（同 4。取りまとめへ返す） |
| 適用した前提の変更の行 | なし。表の L20.3 の行（`sig_scoped` の範囲の変数の上限、表層の `hsig`）は、内容を変えずに同値の補題だけを置いた（「主定理の言明と前提の内容」） |
| 停止条件 | 該当しないと判断した。主定理の字面と前提の内容は L20.2 の状態から変わらない。`Builtins.Assumptions` の欄の追加・内容の変更、結論の弱化、公理の追加はない。ただし「具体化した署名が文脈 0 で整形式」は追加の条件のもとでだけ閉じたので、L20.5 の前に置き場所の判断を求める（「ずれと申し送り」4） |

## 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `Val`（`Release/Syntax.lean`） | 構成子 `checked (t : Scope.Domain.Target)` を末尾に加えた |
| `Val.substTyAt`・`Val.rename`・`Val.subst`（`Release/Subst.lean`） | `.checked t => .checked t` |
| `Val.VarsIn`（`Release/WellFormed.lean`）、`Val.LocalRefs`（`Release/LocalScope.lean`）、`Val.LambdaNamesWF`・`Val.VarsInNoLamNames`（`Release/Lemmas/Names.lean`）、`Val.Reads`（`Surface/Lemmas/BuilderCapture.lean`・`BuilderCaptureAll.lean`） | 新しい場合は `True` |
| `PrimSig`（`Release/Typing.lean`） | 欄 `rkinds : List Scope.Domain.Kind := []`（範囲の変数ごとの種類）を加え、`PrimSig.nranges := s.rkinds.length` を定義した |
| `Builtins`（`Release/Typing.lean`） | 欄 `effKind : EffName → Option Kind := fun _ => none`・`valKind : OpaqueName → Option Kind := fun _ => none`・`admitsR : PrimName → List Range → Prop := fun _ _ => False` を加えた |
| `PrimSig.Scoped`（`Release/WellFormed.lean`） | 定義は変えていない（文脈 0）。説明の文を直し、範囲の変数の番号の上限で読む `PrimSig.ScopedRanges`（`Ty.VarsIn s.nranges …`）を隣に加えた |
| `Release.Model.builtins`（`Release/Model.lean`） | 三つの欄を明示し（対象の種類なし、具体化の制約は何も許さない）、`builtins_valKind`・`builtins_effKind`・`builtins_nranges` を置いた |
| `Qsig.varsIn_scoped`（`Release/Admissible.lean`） | 前提の範囲の変数の文脈を任意の `nr` へ一般化した（証明は同じ） |
| `Surface/BuilderExamples.lean` の `signature` | 無名の構築子に `rkinds` の `[]` を補った |

`Val` を場合分けする定理（NV）は、次の宣言に新しい場合を足して閉じた: `Release/Lemmas/Closed.lean` の5つの相互帰納（`Val.VarsIn.substTyAt` ほか）、`Lemmas/Names.lean` の3つ（`Val.varsIn_iff_noLamNames` ほか）、`Lemmas/SubstTyping.lean` の `Val.rename_id`、`Lemmas/PresBase.lean` の `Val.VarsIn.toTrue`、`Lemmas/Canonical.lean` の `canonical_boolean`・`canonical_ref`・`canonical_lazy`、`Lemmas/BuilderTyping.lean` の `canonical_bytes`、`Lemmas/Progress.lean` の `canonical_fn_or_raise`・`canonical_dict`。標準形の定理の新しい場合は、新しい逆転の補題 `HasTypeVQ.inv_checked`（`Lemmas/Inversion.lean`。検査済みの対象の値には型付けの規則がない）で閉じた。

## 置いた定理（`Release/RangeInst.lean`、新規、既定の import に追加）

公開の宣言は定理 97・定義 14、`example` 8（ほかに private の補助 5）。主なもの:

| 群 | 名前 |
|---|---|
| 範囲の位置の補助 | `RangeInst.ix_inst_eq_fixed_iff`・`ix_inst_eq_rvar_iff` |
| 原子と効果の具体化 | `Atom.instR`・`Eff.instAtoms`・`Eff.instAtoms_spec`（像の特徴付け）・`Eff.instAtoms_nil`・`Eff.instAtoms_of_wf_zero`・`Atom.instR_wf_zero` |
| 型の具体化 | `Ty.rawInstR`（全ての範囲の位置）・`Ty.instR`（正規化つき）・`Eff.instR`（最上位の Fail の列の並びを保つ）・`Ty.instTarget`（最上位の不透明型だけ）・`PrimSig.inst` と欄ごとの `simp` 補題 |
| 空の列・範囲の変数のない型 | `Ty.rawInstR_nil`・`Ty.instR_nil`・`Ty.instTarget_nil`・`Ty.rawInstR_of_rangesIn`・`Ty.instR_of_rangesIn` |
| 正規化・shift との交換 | `Ty.norm_rawInstR`・`Eff.norm_rawInstR`・`Eff.norm_instR`・`Ty.instR_norm`・`Ty.rawInstR_rawShift`・`Ty.instR_shift`・`Ty.instTarget_shift` |
| 型代入・行代入との交換（RV-PL10 中5） | `Eff.instAtoms_substAtoms`・`Eff.rowFails_rawInstR`・`Ty.rawInstR_rawBind`・`Ty.instR_bind`・`Eff.norm_rawInstR_bind`・`SubstEnv.at_rawInstR`・`Ty.instR_substAt`・`Eff.norm_rawInstR_substAt`・`Ty.substAt_rows_norm`・`Ty.instR_substAt_of_rangeFree`（範囲の変数のない像では像を変えずに交換）・`Ty.instTarget_substAt`（像の最上位が範囲の変数を持たないとき） |
| 整形式性（`Ix.inst_wf_zero` の持ち上げ） | `Ty.rawInstR_rawWF`・`Ty.instR_wf_zero`・`Eff.instR_wf_zero`・`Ty.instTarget_wf_zero`・`PrimSig.inst_ret_eff_wf_zero`（条件なし）・`PrimSig.inst_wf_zero`（引数は `PrimSig.TargetRangesOnly` を要する） |
| 署名の具体化 | `PrimSig.inst_nil`（`ScopedRanges` のもとで `inst [] = s`）・`PrimSig.inst_nil_of_canonical`・`PrimSig.inst_nil_of_scoped`（`nranges = 0`）・`PrimSig.inst_of_scoped`（範囲の変数のない署名はどの列でも不変）・`PrimSig.inst_params_getElem?`・`PrimSig.inst_params_agree_off_target`・`PrimSig.inst_params_target` |
| `sig_scoped` | `PrimSig.scopedRanges_iff_old`・`PrimSig.scoped_iff_scopedRanges`・`sig_scopedRanges_iff`・`sig_scopedRanges_iff_old`・`PrimSig.not_scopedRanges_of_ret`（個数以上の番号の範囲の変数を拒否） |
| 範囲の具体化の許容 | `Builtins.RangeAdmissible` と `.length`・`.wf`・`.canonical`・`.fits`・`.top_or_admitsR`・`.nranges_le`、`fitsKinds_replicate_top`・`Builtins.rangeAdmissible_tops`（全て Top の列は常に許す）・`Builtins.rangeAdmissible_iff_nil`（範囲の変数のない項目は空の列だけ） |
| 値（L20.4 の葉の場合） | `Val.target?`・`Val.substTyAt_checked`・`Val.substTy_checked`・`Val.rename_checked`・`Val.subst_checked`・`Val.instantiate_checked`・`Val.varsIn_checked` |

### 決めたことと理由

1. 具体化は正規化を通す（`Ty.instR = norm ∘ rawInstR`）。範囲の位置を変えると Fail の列の型の固定順序と重複が変わり、生の具体化は正規形を保たないためである。計算の最上位の効果 `Eff.instR` は内側の型だけを正規化し、最上位の Fail の列の並びを保つ（`Eff.WF` が最上位に正規形を求めないので、正規化すると `inst [] = s` が成り立たない）。
2. 効果の所属関数の具体化 `Eff.instAtoms` は、所属関数（`Atom → Bool`）の像を有限の判定で書いた。閉じた範囲の原子 `L[fixed R]` は、同じ原子か `rs[i] = R` となる `L[rvar i]` があれば所属する。範囲の変数の原子は列が短いときだけ残る。
3. `Builtins.RangeAdmissible` は Release の側に置いた。採用定義 `Scope.Signature.RangeAdmissible` の項目の制約に「全て Top の列か `admitsR`」を渡し、`Range.Canonical` を連言で加える。`Scope/Signature.lean` は変えていない（既存の宣言を変えずに済むため）。
4. `nranges` は欄ではなく `rkinds` の長さとした（「ずれと申し送り」2）。

## 同値の補題

| 補題 | 内容 |
|---|---|
| `sig_scopedRanges_iff` | 範囲の変数 0 の表（全項目が `nranges = 0`。旧の項目だけの表を含む）で、範囲の変数の番号の上限で読む欄 `∀ b s, B.sig b = some s → s.ScopedRanges` が今の `sig_scoped`（`s.Scoped`）と同値 |
| `sig_scopedRanges_iff_old` | 範囲の変数のない表で、同じ欄が L20.2 の前の旧の欄（`PrimSig.ScopedOld`）と同値 |
| `PrimSig.scoped_iff_scopedRanges` | `nranges = 0` の項目で `Scoped ↔ ScopedRanges` |
| `PrimSig.scopedRanges_iff_old` | `ScopedRanges ↔ ScopedOld ∧ RangesIn s.nranges`（L20.2 の `PrimSig.scoped_iff_old` の範囲の変数の個数の形） |
| `PrimSig.inst_of_scoped`・`Builtins.rangeAdmissible_iff_nil` | 旧の項目は具体化で変わらず、許容される列は空だけ |
| `Model.builtins_valKind`・`builtins_effKind`・`builtins_nranges` | 唯一の仮定の実例の表は、範囲付きの値型・対象の種類・範囲の変数を持たない |

## 確かめた例（`Release/RangeInst.lean` の末尾）

- `File.writeTextIn` の形のモデルの署名（引数 `Scope.PathIn[rvar 0]`、効果 `File.Write[rvar 0]`、`rkinds = [path]`）を `[/data/**]` で具体化すると、引数の対象の位置と効果の原子が同じ範囲になる。空の列では引数が変わらない（Top に狭めない）。
- 同じ署名は `ScopedRanges` を満たし、文脈 0 の `Scoped` を満たさない。
- 制約が全てを許す表でも、全て Top の列は許され、種類の違うエンドポイントの範囲と、正規形でない `/32` の CIDR の範囲は許されない。範囲の変数のない項目には `[Top]` を許さない。

## 主定理の言明と前提の内容

七つの主定理（`Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`、`Surface.desugar_typed`・`surface_effect_soundness`）の言明の字面は、L20.2 の状態（`l20.2/results.md`「主定理の言明と前提の内容」に写した字面）と同じである。証明も既定のビルドで検査し直した（`sig_scoped` を使う `Release/Lemmas/Regularity.lean`・`TySubstMain.lean` は B_WORK の内容のまま通った）。

前提の内容が変わらない根拠:

| 前提 | 根拠 |
|---|---|
| `B.Assumptions`（`sig_scoped` を含む全ての欄） | 欄の定義を変えていない。`sig_scoped` と `hsig` が読む `PrimSig.Scoped` も変えていない。新しい欄 `PrimSig.rkinds` と `Builtins.effKind`・`valKind`・`admitsR` は、どの欄・型付けの規則・意味論も読まない。`delta_typed`・`io_typed`・`io_exists`・`release_exists` は型の付いた値だけを量化し、型の付かない `checked` の値はその対象に入らない |
| `P.WellTyped`・`HasTypeC`・`StateTy`（`progress`・`preservation`・`step_sound`・`effect_soundness`） | 型付けの規則を変えていない。構文に `checked` の値が加わったが、型付けの規則がない（`HasTypeVQ.inv_checked`）ので、これを含む項・ストア・継続は型付かない。型の付く対象は旧の構文の対象だけで、その判断は変わらない |
| `P.WellFormed`・`m.ClosedNoEffVars`・`Comp.VarsInNoLamNames` | `checked` の値を受理するが、これらは各定理で型付けの前提と組で使われる（`checked` を含むプログラムと項は型付けの前提を満たさない）。旧の構文の対象の判断は変わらない |
| 表層の `p.WellFormed`・`p.WellTyped`・`hsig`（`desugar_typed`・`surface_effect_soundness`） | 表層の構文と型付けは変えていない。`hsig` は変えていない `PrimSig.Scoped` を読む |

## 設計書

- 01-12「構文」の箇条に二つ加えた: 検査済みの対象の値 `checked(t)` と、署名の範囲の変数・具体化・具体化の許容・表のデータ（`effKind`・`valKind`・`admitsR`）。型付けがまだ具体化を使わないので `PrimSig.Scoped` を文脈 0 で読むことも書いた。` ```text ` の文法のブロックは変えていない。
- 07-04「形式化で仮定するもの」に【方針】の段落を一つ加えた: `effKind`・`valKind`・`admitsR` の正しさと、プログラムの型の注釈の範囲の正規形と整形式性（解析器の側）を信頼の対象にし、まだ照合していないこと。
- 07-04「01-12 との対応」に行「構文（検査済みの対象の値、署名の範囲の変数と具体化、範囲の具体化の許容）」（Rust は未接続）を加えた。
- 見出しは追加・改名していない（`git grep` の確認は不要）。07-04「証明する性質」は前提の内容が変わらないので直していない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 全体のビルド（途中、11回） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 1（回 1〜9）、0（回 10・11） | 回 1 22.85 秒、回 2 15.23 秒（ほかは計時なし） | [builds/](builds/) |
| 局所の単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`RangeInst.lean` 約10回、`SubstTyping`・`TySubstMain`・`Inversion`・`BuilderTyping` ほか） | 0 か 1（直して再実行） | 各数秒以内（計時なし） | 本書 |
| 全体のビルド（作業末） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <l20.3>/lake-build.log` | 0。433 ジョブ、`Build completed successfully`。`declaration uses 'sorry'` なし。警告は `Interval/` の既存のものだけ | 161.00 秒 | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base c7a75b8549d5c00374a6bdc6d7f444d3eca8f1df --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean`）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base c7a75b8549d5c00374a6bdc6d7f444d3eca8f1df` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.88 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l20.3>/axioms.lean`（149件の `#print axioms`） | 0 | 0.67 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 149件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 85、`propext`・`Quot.sound` 18、`propext` だけ 29、依存なし 17）。`sorryAx` と独自の公理はない。対象は、`RangeInst.lean` の公開の宣言 111件、ほかのファイルで定義を変えた・新しく置いた宣言 31件、旧の主定理7件である。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（作業末。`Release/Syntax.lean` の注釈を直した後の作り直しで、下流の大半を検査し直した） | 2645196800 | 2522.7 | 2.46 |
| 全体のビルドの回 1（途中、`WellFormed.lean` で失敗） | 1608613888 | 1534.1 | 1.50 |
| 公理の確かめ（`lake env lean -M 12288`、`Benitoite` 全体を読み込む） | 1507229696 | 1437.4 | 1.40 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1384218624 | 1320.1 | 1.29 |

局所の単一ファイルの検査と途中のビルドの回 3〜11 は計時していない（値なし。0 ではない）。`-M 12288` は変えていない。

## 失敗と修正

- 回 1: `Val.VarsIn`・`Val.LocalRefs` の場合の不足。腕を加えた。
- 回 2: `PrimSig.Scoped` を `s.nranges` の文脈に替えた試行で、`Release/Lemmas/Regularity.lean`（`HasTypeVQ.wf` の `V_Prim` の腕、3件）、`Admissible.lean`（`of_noRows`）、`RangeWF.lean`（`scoped_iff_old`）が壊れた。`Qsig.varsIn_scoped` を一般化し、`Builtins.Assumptions.sig_scoped` に暫定の連言 `s.nranges = 0` を足す案を試した（回 3〜5 は `Closed`・`Names`・`SubstTyping`・`TySubstMain` の追随）。
- 回 5: 上の案で、表層の `Surface/Lemmas/Invariants.lean`（`E_Prim` と組み込みの操作の型の clean の不変条件、約17件）が `desugar_typed` の `hsig`（`s.Scoped`）から文脈 0 の条件を得られず壊れた。`hsig` に連言を足すと `desugar_typed` の字面が変わり、共通の条件に反する。そこで `Assumptions.lean`・`Regularity.lean`・`TySubstMain.lean`・`RangeWF.lean` を B_WORK の内容に戻し、`PrimSig.Scoped` を文脈 0 のまま残して、範囲の変数の個数で読む形を `PrimSig.ScopedRanges` として加えた（回 6）。
- 回 6〜9: 標準形の定理（`Canonical`・`BuilderTyping`・`Progress`）、`PresBase`、`BuilderCapture`・`BuilderCaptureAll`、`BuilderExamples` の無名の構築子の追随。標準形の定理の新しい場合のために `HasTypeVQ.inv_checked` を加えた。回 10 で全体が通った。
- `RangeInst.lean` の単一ファイルの検査で、範囲の位置の補題の `simp` の閉じ残し、`Ty.TopRangeFree` の不透明型の場合の単射の取り出し、`Inhabited Builtins` の欠如（例の表を明示した）、`Model.refGetSig` の参照（import の外。モデルの署名に替えた）などを直した。使っていない `simp` の引数の警告を全て消した。
- 01-12・07-04 を標準入力の Python で書き換えようとして、macOS の Python が多バイト文字で `SyntaxError: Non-UTF-8 code` を出した（L20.2 の記録と同じ）。スクリプトをファイルに書いて実行した。結果に影響しない。
- 途中のビルドのログの手元の絶対パスは、写すときに `<wt>`・`<home>`・`<tmp>` へ置き換えた。

## ずれと申し送り

計画からのずれ:

1. **`sig_scoped` と `hsig` の切り替えを L20.5 へ送った。** 依頼は `PrimSig.Scoped` の文脈 0 を `s.nranges` に替えることだったが、`V_Prim` がまだ具体化しない署名で型付けるので、範囲の変数を持つ項目では正則性（`V_Prim` の値の型の文脈 0 の整形式）と表層の型の clean の不変条件が成り立たない（「失敗と修正」の回 2・5）。`Release` の欄だけに暫定の `nranges = 0` を足すと表層の `hsig` の字面を変える必要が出る。そこで `PrimSig.Scoped` を変えず、範囲の変数の番号の上限で読む `PrimSig.ScopedRanges` と、範囲の変数 0 の表での同値（`sig_scopedRanges_iff`・`sig_scopedRanges_iff_old`）を置いた。表の L20.3 の行「`sig_scoped` の範囲の変数の上限」「表層の `hsig`」の内容の変更は、`V_Prim` が `s.inst rs` を使う L20.5 で `sig_scoped`・`hsig` を `ScopedRanges` へ替えるときに適用することを推す（同値の補題は本枝の補題をそのまま使える）。取りまとめが plan の表の枝を L20.5 へ直すかを判断する。
2. **`nranges` は欄ではなく `rkinds` の長さ。** `RangeAdmissible` の `FitsKinds` が範囲の変数ごとの種類を要るので、種類の列 `rkinds`（既定 `[]`）を欄にし、`nranges := rkinds.length` とした（L00.08 の軽7 の対応と同じ形）。個数と種類の列の長さが食い違う項目を作れない。既定の空の列のまま `rvar` を書いた項目は `ScopedRanges` で拒否される（`not_scopedRanges_of_ret`）ので、計画の注「`nranges` の既定値」の性質は保つ。
3. `Builtins.RangeAdmissible` は Release の側に置き、`Scope/Signature.lean` を変えていない（「決めたことと理由」3）。
4. **具体化した引数の型の整形式性には追加の条件が要る（取りまとめへ返す）。** 引数は最上位の対象の位置だけを具体化するので、引数の関数型の内側などに範囲の変数があれば、具体化の後も残り、`fnTy (s.inst rs) …` は文脈 0 で整形式でない。結果と効果は条件なしで閉じた（`PrimSig.inst_ret_eff_wf_zero`）。引数は `PrimSig.TargetRangesOnly`（引数の範囲の変数は最上位の対象の位置だけ）のもとで閉じた（`PrimSig.inst_wf_zero`）。計画の注の「残った rvar を持つ型にはプログラムの値が属さない」だけでは、`V_Prim` の正則性（L20.5）を閉じられない。置き場所の候補: (a) L20.5 で `sig_scoped` を `ScopedRanges` へ替えるときに `TargetRangesOnly` も含める（範囲の変数のない表では自明に成り立つ。RV-PL10 重大1 は `sig_scoped` に位置の条件を置くと問18 の行 4 を越えるとしたので、設計者の了承が要る）。(b) `V_Prim` の前提に加える（問18 の行 6「`V_Prim` の R」の変更の一部として読む）。(c) L20.7 の `shapeOk` に置く（L20.5 より後なので、L20.5 の正則性に間に合わない）。問22 の表の項目（`File.writeTextIn`・`Scope.widenPathIn`・`Scope.checkPathIn`・HTTP の項目）は、範囲の変数が引数の最上位の対象の位置か結果・効果にだけあるので、どの案でも満たす見込みである（表の項目は L20.7 が置くので未確認）。推す案は (a) である（表のデータの性質なので表の仮定に置き、型付けの規則を増やさない）。
5. `Ty.VarsIn` の代入の補題（L20.2 の申し送り 9）は一般化していない。本枝には範囲の変数を残したまま代入する箇所がない。L20.5 でも、(4) の条件のもとで個数の合う列で具体化すれば全て文脈 0 になるので、要らない見込みである（確かめていない）。
6. 新しいファイル `Release/RangeInst.lean` は計画に候補の名前がなかった。

### L20.4 への申し送り

7. 葉の規則（`valKind o = some t.kind ∧ R.Mem t` を前提に `.checked t : opaque o (fixed R)`）を加えると、`HasTypeVQ.inv_checked`（型付けの規則がないことの補題）は成り立たなくなる。逆転の補題に置き換え、`canonical_*` の `checked` の場合（`Canonical.lean`・`BuilderTyping.lean`・`Progress.lean` の6定理）は「不透明型でない型には属さない」形で直す。代入・改名・shift の葉の場合は `Val.substTyAt_checked`・`rename_checked`・`subst_checked`・`instantiate_checked` を使う。
8. `delta_typed`・`io_typed`・`io_exists`・`release_exists` の旧の像での同値は、`Model.builtins_valKind`（と既定の `valKind`）の `none` から葉の規則が使えないことで示せる見込みである。

### L20.5 への申し送り

9. `V_Prim` は `s.inst rs` と `B.RangeAdmissible b s rs` で型付ける。正則性は `PrimSig.inst_wf_zero`（`RangeAdmissible.nranges_le` で個数を得る）と上の 4 の条件、旧の項目は `PrimSig.inst_of_scoped`、脱糖と交換が書く Top の列は `Builtins.rangeAdmissible_tops` を使う。`PrimSig.inst` は `names`・`ntys`・`neffs`・`admits`・`kind`・`opEff`・`rkinds` を変えない（`simp` 補題）。`Qsig` が具体化した署名で変わらないことは示していない（具体化は行の原子を変えないが、`Ty.instR` が正規化するので補題が要る見込み）。
10. `E_OpPrim` の拡大は `PrimSig.inst_params_agree_off_target`（対象の位置でない引数は二つの具体化で同じ）と `inst_params_target`（対象の位置は `O[ix.inst rs]`）を使う。
11. 具体化と代入の交換は `Ty.instR_substAt_of_rangeFree`（範囲の変数のない正規形の型の像）と `Ty.instTarget_substAt`（像の最上位が範囲の変数を持たない）を使う。型付けの型引数 `ts` は `Ty.WF 0` だけを満たし、潜在効果の原子に範囲の変数を持ちうる（L20.2 の申し送り 10）ので、`Ty.RangesIn 0` が要る箇所では一般形 `Ty.instR_substAt` を使う。

### L20.7・L30・L40・L50 への申し送り

12. L20.7: 表の項目を加えるときに `effKind`・`valKind`・`admitsR` の値を入れる。`Model.builtins` の三つの欄は対象なしのままなので、新版の実例で置き換える。`Surface/CheckTables.lean` の `builtins` は既定値（対象なし）を使っている。
13. L30.1: 組み込みの操作の型 `opSig` はまだ具体化しない `s.params`・`s.ret` を使う（範囲の変数のない項目だけなので今は問題がない）。節の添字 S の具体化 `e.inst [S]` は `PrimSig.inst` を使える。
14. L50.1: 交換形式の書き出し `fromVal` は `checked` を `unsupported "Release.Val"` に落とす（既存の既定の腕）。読み込みは `checked` を作らない。
15. L50.3: `PrimSig.ScopedOld`・`ScopedRanges` と `Scoped` の二本立ては、L20.5 の切り替えの後に整理の対象になる。

### 取りまとめへ

16. 上の 1（`sig_scoped`・`hsig` の切り替えの枝）と 4（`TargetRangesOnly` の置き場所）の判断を、L20.5 の起動の前に求める。L20.4 はどちらにも依存しない見込みである。
17. 新しい欄の追加・公理の追加・主定理の字面と前提の内容の変更はない。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 00:33 ごろ（JST、依頼文を読み始めた時刻） |
| 終了 | 01:20 ごろ（本書の作成まで） |
| 外側の所要 | 約47分 |
| 能動時間 | 約40分（文書と定義を読む約10分、値の構成子と追随約8分、`sig_scoped` の試行と戻し約5分、`RangeInst.lean` の定義と証明約12分、設計書と本書約8分。ビルドの待ちを除く） |
| ビルドの回数と時間 | 途中の全体のビルド 11回（失敗した回は各15〜30秒、成功した回は約2〜3分）、作業末 1回 161.00 秒、局所の単一ファイル 約15回（各数秒） |
| 検査 | work 1回 9.88 秒（dry-run 数秒）、公理の確かめ 0.67 秒 |
| 待ち | 排他の道具の待ちは記録上なし。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.5〜4.5時間の範囲内。上端の2倍（9時間）を超えていない |
