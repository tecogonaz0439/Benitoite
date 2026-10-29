# L40.6c の結果: 効果の上限の被覆による包含の本体

2026-10-28。plan-l10-l50「L40」の表の L40.6c の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l40.6c`）で行った。担当は Claude のサブエージェントである。git の状態は変えていない（コミットは取りまとめが行う）。

**案 α（Release の C-Sub を被覆にし、L30.1 の S ≠ Top の保存を被覆の補題で証明し直す）で本体を閉じた。** 案 Y・γ には切り替えていない。既定の全入口のビルドは sorry なしで通り、主定理の字面は L40.6b の後と同じである。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.6c（効果の上限の被覆による包含の本体。L40.6b の後の推す案） |
| B_WORK | `e9daf28b63584ffb178024638b57f96cac47b4ab`（L40.6b と L50.1 の取り込みの後の本線） |
| 閉じた範囲 | 依頼の 1（試行）、2（判断: α）、3（α の本体）、5（完了の条件）、6（設計書）、7（主定理の言明の比較）。依頼の 4（Y と γ）は α を採ったので行っていない |
| 適用した前提の変更の行 | 停止の表の「表層の側の前提」（`p.WellTyped` の内容。E_Sub・B_Sub）と「節の添字 S と継続の型」の L40.6c の案 α の例外（C-Sub・C-Eff・`Ty.Le` と、継続の型 K-Handle・K-Handle-Fail の節の効果の前提） |
| 停止条件 | 該当しないと判断した。`Builtins.Assumptions` の欄の追加・公理の追加・結論の弱化はない。ただし、`Ty.Le` を被覆にしたので、`Builtins.Assumptions` の欄の字面と量化は変えずに、値の型付けを通じて欄の意味が変わる（下の「取りまとめへ返す点」1。レビューで確かめてほしい） |

## 試行（依頼の 1）

plan「検査の割り当て」の「L の一度の切り替えの試行ビルド」の行に従い、排他の道具で既定の全体の `lake build` を回ごとに走らせた。各回の差分は [trial/round-NN.diff](trial/)、生のログは `trial/build-NN.log`、回ごとの件数は [trial/counts.tsv](trial/counts.tsv) にある。

最初の変更は、`Release/Typing.lean` の `Ty.Le` の関数の型の効果、C-Sub・C-Eff の `Eff.Sub ε ε'` を `Eff.Covers ε' ε` に替えることだった。被覆の定義は `Release/EffectCover.lean` にあり、このファイルは `Typing` を推移的に読むので、そのまま import するとビルドの循環が起きた（この回のログは次の回で上書きしたので残っていない。誤り 0・`build cycle detected` 3件）。被覆の定義と型付けが使う基本の補題を `Release/EffectCoverDef.lean`（新、`Typing` より前）へ移し、`EffectCover.lean` から読む形にした。以後の回は次のとおりである。

| 回 | 終了 | 誤り | 壊れた宣言（近似） | 失敗したファイル | 未検査のモジュール | 主な箇所 |
|---|---|---:|---:|---:|---:|---|
| 1 | 1 | 5 | 5 | 1 | 228 | `Ty.Le` の補題（`Lemmas/Basic.lean`）。`Eff.Covers.shift` を足した |
| 2 | 1 | 20 | 10 | 1 | 217 | 逆転の補題（`Lemmas/Inversion.lean`）。結論を被覆にした |
| 3 | 1 | 8 | 6 | 3 | 132 | Fail の継続、型の代入（`TySubstMain`）、表層の検査器の `tyLe_sound` |
| 4〜6 | 1 | 4・4・18 | 4・4・2 | 2 | 111・103・98 | 呼び出しの逆転、`PresBase`、`PresMain`、呼び出しの頭（`CallHead`） |
| 7〜12 | 1 | 1〜4 | 1〜4 | 1〜2 | 118〜86 | 継続の型付けの変更（下）の追随、進行、効果の健全性、対象の伝播 |
| 13〜16 | 1 | 8・7・5・3 | 5・7・4・2 | 3・3・4・1 | 68・39・15・11 | 例、旧の継続の型付けの写し、表層の型付けと検査器の健全性 |
| 17 | 0 | 0 | 0 | 0 | 0 | Release と表層の本体が通った |
| 18〜20 | 1・1・0 | 1・2・0 | — | — | — | 例と旧の像の補題を足した後（本体の外） |

回をまたいだ一意の数は、壊れた宣言 61・ファイル 28 である（誤りの行を最終のソースの宣言へ対応付けたので近似）。未検査の数は、失敗したモジュールに依存するモジュールの数で、`l00.06b/tools/unchecked.py` で最終の import のグラフから数えた。各回の誤りは、結論を構造上の包含から被覆へ替えた補題の追随で、内容の変更が要ったのは下の「洗い出した箇所」の 4・5・6 だけだった。回 17（作業の開始から約 28 分）で既定の全入口が通ったので、α の本体を閉じる見込みは上端（6時間）の2倍に十分収まると判断し、α で進めた（依頼の 2）。

### 構造上の包含に頼っていた箇所（洗い出し）

1. **代入・正規化**: 被覆は型と行の代入（`Eff.Covers.bind`・`substAt`・`substRho`。L10.5）と正規化（`covers_norm_left`・`right`）で保たれる。型の変数の移動の補題がなかったので `Eff.Covers.shift` を足した（移動は名前と行の原子を変えない）。
2. **`handled` と C-Handle**: `handled(H)` は名前で原子を除くので、被覆とは関わらない。C-Handle の `εM ⊆ ε ∪ handled(H)`、C-Handle-Fail の前提、K-Handle の `εb ⊆ εc ∪ handled(H)` は構造上の包含のまま保った。保護本体の効果は、その前に C-Sub で被覆によって広げられる。節の添字の規則（構造上の所属で述べる）も変えていない。
3. **状態の型付けの計算と継続の関係** `StateTyE` の `Eff.Sub ε1 ε` と、K-Empty・K-Let・K-Guard の包含は構造上のまま保った。逆転で被覆が出た箇所では、新しい状態の計算を C-Eff で元の効果へ広げ直して、構造上の関係を保った（`preservationE` の各腕、`pres_op_common`、`pres_failure`）。
4. **継続の型 K-Handle・K-Handle-Fail**: 節の効果 εc が枠の下の継続の効果 ε に含まれる前提（`Eff.Sub εc ε`）と、K-Handle-Fail の `Rest ⊆ ε`・`ec ⊆ ε` は、被覆にする必要があった。`handle M with H` の型付けが C-Sub で被覆によって広がる（節の効果 ε' を上限 ε1 が覆うだけの）とき、E-Handle の後の枠は εc = ε' を ε に構造上では含めず、節の型付けの効果は継続の変数の型にも現れるので、C-Eff で広げ直せないためである。
5. **継続を通した原子の到達**（`ContTy.name_end_ix`・`ContTy.split`・`end_of_noHandler_ix`・`resume_append`）: K-Handle を越えるたびに、範囲付きの原子は、それを覆う同じ名前の原子として届く形に言明を変えた。名前は変わらないので、`BuiltinOnly`（名前で判定）と Top の `State` の到達（`name_end`）は変わらない。
6. **L30.1 の S ≠ Top の `E_OpPrim` の保存**: 呼び出しの原子 `L[r]` は計算の効果の `L[r1]`（r1 は r を覆う）に覆われ、継続を通って穴の効果の `L[r2]`（r2 は r1 を覆う）に届く。穴の効果の名前 L の原子は `L[S]` だけなので r2 = S であり、S は r を覆う。捕捉した閉じた引数は、最上位の対象の位置の値を r への所属と被覆の健全性から得る S への所属で広げる（`HasTypeVsQ.widen_covers`。L20.4 の `checked_widen_covers` と同じ葉の補題 `widen_opaque`）。範囲の変数のない項目（`nranges = 0`）の場合は以前と同じである。
7. **対象健全性**: 許可の関係は被覆で単調である（`Eff.Covers.sound`。L10.5）。原子が覆う原子として届く形の補題 `Eff.allows_of_mem_covers` を足し、`ContTy.allows_end`・`allows_end_of_prim_call`・`allows_hole_of_split`・`allows_clause_end`・`StateTyE.opPrim_clause_allows` をそれで直した。`Builtins.TargetAgreement` と `step_target_sound`・`reachable_target_sound`・`surface_target_sound` の言明は変えていない。
8. **表層**: 表層の検査器（`tyLe_sound`・`acceptEff_sound` など）は構造上の包含で受け入れ、`Eff.Sub.covers` で被覆へ移して型付けを作る。検査器の健全性は保たれ、検査器は被覆だけで型付くプログラムを受理しない（下の申し送り）。脱糖の型の保存の `E_Sub`・`B_Sub` の場合は、コアの C-Sub がそのまま閉じた。
9. **旧の継続の型付けの写し** `ContTyOld`（L30.1 の比較用）: L30.1 の変更（穴の効果）だけを比べるため、K-Handle・K-Handle-Fail の節の効果の前提を新しい `ContTy` と同じ被覆に揃えた（`ContTy.toOld`・`contTy_exists_iff_old` は言明を変えずに通った）。

## 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `Ty.Le`（`Release/Typing.lean`） | 関数の型の潜在効果を `Eff.Sub ε ε'` から `Eff.Covers ε' ε` で広げる |
| `HasTypeCQ.C_Sub`・`C_Eff`（同） | 効果の前提を `Eff.Covers ε' ε` にした |
| `ContTy.K_Handle`（`Release/Semantics.lean`） | 節の効果の前提を `Eff.Sub εc ε` から `Eff.Covers ε εc` にした。`Eff.Sub εb (εc ∪ handled)` は構造上のまま |
| `ContTy.K_Handle_Fail`（同） | `Eff.Sub Rest ε`・`Eff.Sub ec ε` を `Eff.Covers ε Rest`・`Eff.Covers ε ec` にした |
| `HasTypeQ.E_Sub`・`HasBlockQ.B_Sub`（`Surface/Typing.lean`） | 効果の前提を `Eff.Covers ε' ε` にした |
| `CallHead.HasTypeQ`（`Surface/Lemmas/Calls.lean`） | 呼び出しの頭の効果の前提を被覆にした（`apply` が C-Eff を使うため） |
| `ContTyOld`（`Release/Lemmas/ClauseIx.lean`） | 上の洗い出し 9 |
| `Atom.Covers`・`Eff.Covers` ほか（`Release/EffectCover.lean` → `Release/EffectCoverDef.lean`） | 定義と基本の補題を新しいファイルへ移した（名前と名前空間は同じ。内容は変えていない） |

逆転の補題（`Release/Lemmas/Inversion.lean` の `inv_let`・`inv_app`・`inv_ite`・`inv_match`・`inv_use`・`inv_handle`・`inv_resumeL`・`inv_resume`・`inv_meth`・`inv_builderLet`、`FailureCont.lean` の `inv_handle_failure`、`Preservation.lean` の `Ty.Le.fn_fn'`・`inv_prim_app`・`inv_op_app`、`PresBase.lean` の `store_prim_inv`、`Ty.Le.fn_left`・`fn_right`）と継続の補題（`ContTy.inv_handle`・`split`・`name_end_ix`・`resume_append`・`failure_prefix`・`split_failure`、`failure_drop`・`captureEff_state`、`pres_op_common` の `hsel`、`TargetPropagation` の `allows_hole_of_split`・`allows_clause_end`、`TargetStepExamples.inv_prim_app_eff`）の結論・前提の包含を被覆に替えた。どれも主定理ではない。

`Scope/` の採用定義、`Builtins.Assumptions`・`CoreAssumptions`・`TargetAgreement` の欄、`Release/Theorems.lean`・`Surface/Theorems.lean` は変えていない。`Interval/`・`Exchange/`・`Checked/` も変えていない。

## 置いた定理

| ファイル | 定理 |
|---|---|
| `Release/EffectCoverDef.lean`（新、既定の import に追加） | 移した定義と補題のほか、`Eff.Covers.shift`、`Eff.Covers.sub_of_noAtoms`・`sub_of_singleFail`（原子を持たない効果の被覆は構造上の包含と同じ）、`Atom.covers_fixed_fixed` |
| `Release/EffectCover.lean` | `Eff.allows_of_mem_covers`（閉じた範囲 r の原子を覆う原子が属すれば、r に属する対象を許す） |
| `Release/Lemmas/MembershipBase.lean` | `HasTypeVQ.widen_instTarget_covers`・`HasTypeVsQ.widen_covers`（呼び出しの範囲の列の各範囲を覆う S の列で具体化した引数の型への、捕捉した閉じた引数の拡大。判断 11 の専用補題） |
| `Release/CoverCompat.lean`（新、既定の import に追加） | 旧の像での同値: `Ty.LeOld`（以前の型の包含の写し）、`Ty.LatentTopAtoms`、`Ty.LeOld.le`、`Ty.le_iff_leOld`、`Eff.covers_iff_sub_old` |
| `Release/CoverExamples.lean`（新、既定の import に追加） | 下の「確かめた例」 |
| `Surface/CoverExamples.lean`（新、既定の import に追加） | 下の「確かめた例」 |

未証明の theorem は置いていない。

## 確かめた例

| ファイル | 名前 | 内容 |
|---|---|---|
| `Release/CoverExamples.lean` | `bound_covers_narrow`・`not_sub_narrow` | 上限 `{File.Write[/data/**]}` は `{File.Write[/data/a.txt]}` を被覆で含むが、構造上の包含では含まない |
| 同 | `narrowCall_typed`・`narrowCall_bound` | `File.writeTextIn[;;/data/a.txt](checked(/data/a.txt), "x")` は効果 `{File.Write[/data/a.txt]}` で型付き、C-Eff の被覆で上限 `{File.Write[/data/**]}` でも型付く |
| 同 | `progCover_wellFormed`・`progCover_wellTyped`・`progCover_effectsOk`・`progCover_assumptions` | 上限 `{File.Write[/data/**]}` の関数 `f` の本体がこの呼び出し（被覆だけで型付く）、狭い効果の関数 `g` の本体が同じ呼び出し、上限 `{File.Write[/data/**]}` の関数 `h` の本体が `g()`（被覆だけで型付く）であるプログラムが、整形式・型付き・宣言の条件・表 `ModelTargets.Examples.B` の信頼条件を満たす |
| 同 | `callF_reach`・`callF_reach_target_sound` | `f()` から一回の E-Fun で書き込みの状態へ到達し、その E-IO の事象の観測 `/data/a.txt` を `f` の上限が許す（`reachable_target_sound` を当てた） |
| 同 | `callH_reach`・`callH_reach_target_sound` | `h()` から二回の E-Fun（`h` の本体の `g()`）で書き込みの状態へ到達し、その観測 `/data/a.txt` を `h` の上限が許す（狭い効果を持つ利用者の関数を広い上限の関数から呼ぶ小例） |
| `Surface/CoverExamples.lean` | `writeE_typed`・`writeE_bound`・`writeE_narrow`・`callGE_typed`・`callGE_bound` | 表層の `File.writeTextIn["/data/a.txt"](path: path, text: "x")` を E_Sub の被覆で上限 `{File.Write["/data/**"]}` に広げる。狭い効果の関数 `g(path: path)` の呼び出しも同じ |
| 同 | `program_wellFormed`・`program_wellTyped`・`program_hasMain`・`program_target_sound` | 表層のプログラム（`f`・`g`・`h` と main）が `p.WellFormed`・`p.WellTyped B opPrim`・`HasMain {File.Write["/data/**"]}` を満たし、`surface_target_sound` が当たる。脱糖したプログラムの信頼条件は `ModelTargets.assumptions` から得た |
| 同 | 無名の `example` | `f` の本体の効果は上限に構造上の包含では含まれない（被覆だけで型付く） |

表層の例の限界: 表層の構文は検査済みの対象の値を書けないので、main から `f`・`h` へ渡す値を作るには `Scope.checkPathIn` の結果の照合が要る。この例の main は `()` であり、`program_target_sound` の結論の IO の事象には到達しない（前提が満たされることを確かめた例であり、結論は空に成り立つ）。被覆だけで型付くプログラムから到達した IO の事象の観測が上限に許されることは、コアの例 `callF_reach_target_sound`・`callH_reach_target_sound` で確かめた。表層で IO に到達する例は RV-L40 軽8 の L50.4 の範囲に残す。

既存の例（`ScopeAcceptExamples` の `#guard`、`TargetReachExamples`、`HandlerTargetExamples`、`ClauseIxExamples` ほか）は、空の効果の包含と被覆の取り出しの機械的な追随（`Eff.covers_empty`、`allows_of_mem_covers`）のほかは変えずに通った。

## 主定理の言明と前提の内容

主定理の字面は L40.6b の後と同じである（`Release/Theorems.lean`・`Surface/Theorems.lean` と主定理の宣言を変えていない）。

| 主定理 | 字面 | 変更前の前提の内容 | 変更後の前提の内容 | 旧の像での同値・包含 |
|---|---|---|---|---|
| `Release.progress` | 変更なし（`hwt : P.WellTyped B`、`hdecl`、`hb : B.CoreAssumptions P`、`StateTy P B s`） | C-Sub・C-Eff・`Ty.Le` は構造上の包含。K-Handle の節の効果と K-Handle-Fail の Rest・ec は構造上の包含で継続の効果に含まれる | 同じ前提が被覆。`P.WellTyped` と `StateTy` に入るプログラム・状態が広がり、前提が弱まる | `Eff.covers_iff_sub_old`（内側が旧の効果なら同値）、`Ty.le_iff_leOld`、`Ty.LeOld.le`・`Eff.Sub.covers`（旧の導出は新しい導出） |
| `Release.preservation` | 変更なし | 同上 | 同上。前提と結論の両方が広がる | 同上 |
| `Release.effect_soundness`・`effect_soundness_noLamNames` | 変更なし | 初期の計算の型付けと `P.WellTyped` は構造上の包含 | 被覆。型付けられる計算が広がる。空の効果を覆うのは空の効果だけなので結論の意味は変わらない | 同上 |
| `Release.step_sound` | 変更なし（`horacle` は L20.6 の形） | `progress`・`preservation` と同じ | 同上 | 同上 |
| `Release.step_target_sound`・`reachable_target_sound` | 変更なし | 状態の型付け・初期の計算の型付けは構造上の包含 | 被覆。被覆は許可の包含を与えるので結論（初期の ε・末尾の Eb が観測を許す）は同じ形で成り立つ | 同上 |
| `Surface.desugar_typed` | 変更なし | 前提の表層の型付けの E_Sub・B_Sub、結論のコアの型付けは構造上の包含 | 被覆。前提と結論の両方が広がる | 同上 |
| `Surface.surface_effect_soundness`・`surface_target_sound` | 変更なし | 同上 | 同上 | 同上 |
| `ScopeSound.scope_check_connection`・`scope_local_connection`・`scope_local_typed` | 変更なし | `acceptBody` と表層の評価・コアの型付け | `scope_local_typed` の結論の型付けが被覆の型付けになり広がる。ほかは変わらない | — |

前提の内容の変更は、停止の表の「表層の側の前提」（E_Sub・B_Sub による `p.WellTyped` の内容）と「節の添字 S と継続の型」の L40.6c の案 α の例外（C-Sub・C-Eff・`Ty.Le`、K-Handle・K-Handle-Fail の節の効果の前提、L30.1 の S ≠ Top の保存の閉じ方）の範囲である。旧の像での同値は規則の前提の水準の補題であり、型付けの関係全体の同値は示していない（RV-L40 軽10 と同じ限界）。

## 設計書

- 01-12「型付け規則」の `≤` の【決定】の後に、形式化した Release の `≤`・C-Sub・C-Eff の効果の包含を被覆で判定する【決定】を加えた（C-Handle の前提を構造上に保つ理由、旧の像での同値、例）。規則の ` ```text ` のブロック（C-Sub の `ε ⊆ ε'` など）は変えていない。
- 01-12「型の情報を付けた表層の構文と型付け」の範囲条件の箇条に、E_Sub・B_Sub の被覆と、表層の検査器が構造上の包含で受け入れることの【決定】を加えた。
- 01-12「エフェクトの名前と開始状態」の【方針】の置き場所と、「被覆と許可の関係は型付けと実行の規則からはまだ使わない」を、被覆を使う規則の列挙に直した。
- 01-12「ハンドラ」の K-Handle の【決定】（節の効果の被覆とその理由、`ContTy.split` の到達の形、S が規則の値の場合の保存を `widen_covers` で閉じること）、対象の伝播の箇条、`C_Handle_Fail`・`K_Handle_Fail` の段落、「確かめる性質」の K-Handle の箇条を直した。
- 07-04「証明する性質」: 節の添字の段落の S ≠ Top の保存の文を直し、被覆による効果の包含の【決定】（前提の内容の変更、旧の像での同値、例、型検査器との照合を Lean の外に置くこと）を加えた。
- 07-04「形式化で仮定するもの」: `Ty.Le` の被覆により、`Builtins.Assumptions` の欄の字面と量化は変えずに値の型付けを通じて意味が変わることの【決定】を加えた。
- 07-04「01-12 との対応」: 「エフェクトの名前と開始状態（構造上の包含・被覆・許可の関係）」と「ハンドラ（節の添字と枠の上の効果）」の行を直し、「初回リリース版の拡張: 効果の上限の被覆による包含」の行を加えた（Rust は未接続）。
- 見出しは足していない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 最初の全体のビルド（本線の L50.1 の分を作り直した） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0（504 ジョブ） | 14.82 秒（排他の待ち 0 秒） | [lake-build-first.log](lake-build-first.log) |
| 試行と本体の全体のビルド（20 回と、循環で止まった最初の 1 回） | 同上 | 回 1〜16・18・19 は 1、回 17・20 は 0 | 0.86〜176.63 秒 | [trial/](trial/)・[trial/counts.tsv](trial/counts.tsv) |
| 局所の単一ファイル（約8回） | `cd <wt>/formal && lake env lean -M 12288 <相対パス>` | 途中に 1 が4回（例のファイルの名前の誤りと書き換えの失敗）、最後は全て 0 | 各数秒 | 本書 |
| 作業末の全体のビルド | 排他の道具 | 0。`Build completed successfully (509 jobs)`、`sorry` の出現 0、警告 88件（最初のビルドと同数。新しいファイルと変えたファイルの警告なし） | 0.14 秒（回 20 までに組み立て済み。排他の待ち 0 秒） | [lake-build.log](lake-build.log) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l40.6c>/axioms.lean`（`#print axioms` 50件） | 0 | 0.62 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base e9daf28b63584ffb178024638b57f96cac47b4ab --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean` ほか）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base e9daf28b63584ffb178024638b57f96cac47b4ab` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.67 秒 | [work-check.log](work-check.log)（計時の出力も同じファイルの末尾にある） |

公理: 50件（新しい定理 10件、被覆へ言明を変えた補題 14件、例 13件、主定理 10件と接続定理 3件）とも標準の三公理の部分集合だけに依存する（三つ全て 48件、`propext`・`Quot.sound` 1件、`propext` だけ 1件）。`sorryAx` と独自の公理はない。`native_decide`・`maxHeartbeats` の追加はない。例の `decide` は範囲の所属と許容の小さな判定だけである。

work の `formal_build` は `scripts/check.sh` の中の `lake build` で、排他の道具を通らない。作業末の全体のビルドの直後でビルド済みであり、組み立ては起きていない。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当。L50.1 の申し送りのとおり L50.2 まで通らない）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。全体のビルドの値は並行するジョブの中で最大のプロセスの値である。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 最初の全体のビルド | 1670119424 | 1592.8 | 1.56 |
| 試行と本体の全体のビルドの最大（回 19。`Release/Typing` 以降を組み立て直した） | 3579297792 | 3413.5 | 3.33 |
| 作業末の全体のビルド（組み立て済み） | 70811648 | 67.5 | 0.07 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1526071296 | 1455.4 | 1.42 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1384333312 | 1320.2 | 1.29 |

本作業で観測した最大は 3.33 GiB（回 19 の全体のビルド）である。局所の単一ファイルは計時していない。`-M 12288` は変えていない。

## 失敗と修正

- 最初の試行の全体のビルドは、`Typing` から `EffectCover` を読んだことによるビルドの循環で止まった。定義を `EffectCoverDef.lean` へ分けて直した（上の「試行」）。そのログは次の回の同じ名前のログで上書きしたので残っていない。
- 回 1〜16 の失敗は全て計画した切り替えの追随である（上の表）。回 6 で、`handle` の式の型付けが被覆で広がるときに K-Handle の節の効果の前提が構造上では満たせないと分かり、継続の型付けの K-Handle・K-Handle-Fail を被覆にした（洗い出し 4）。
- 回 18 は表層の例の未完の証明（`SingleTy` の残り）、回 19 は旧の像の補題のファイルの名前の解決（`ε.TopAtoms` の書き方）で失敗し、直した。
- 単一ファイルの検査の失敗は、例のファイルの存在しない補題の名前（`Ty.substAtList`）、書き換えの形の不一致（`fnTy` を展開した後の形、`dataTree` の展開）、`simp` の不足で、直した。
- 設計書の書き換えを Python の標準入力の台本で当てようとして構文の誤りで止まった（ファイルは変わっていない）。台本をファイルに書いて UTF-8 で読み込んで当てた。

## ずれと申し送り

### 計画からのずれ

1. 試行は本体の切り替えをそのまま進める形になり、回 17 で本体の Release と表層が通った。試行と本体を分けて戻す区切りは置いていない（数が小さく、上端の2倍を超える見込みがなかったため。L30.1 と同じ扱い）。
2. 依頼の 3 の「C-Sub と、それが使う効果の包含」のほかに、継続の型付けの K-Handle・K-Handle-Fail の節の効果の前提も被覆にした（洗い出し 4。停止の表の「節の添字 S と継続の型」の行の継続の型の変更に当たると判断した）。K-Empty・K-Let・K-Guard と状態の型付けの計算と継続の関係は構造上のまま保った。
3. 被覆の定義を新しいファイル `Release/EffectCoverDef.lean` へ移した（名前と名前空間は同じ）。

### 取りまとめへ返す点

1. **`Builtins.Assumptions` の意味の変化**: `Ty.Le` を被覆にしたので、V-Sub で関数の値を広げる型付けが広がり、`delta_typed`・`io_typed`・`io_exists`・`release_exists` の入力と出力の値の型付けを通じて、欄の字面と量化を変えずに意味が変わる（入力が広がる欄は強まり、出力が広がる欄は弱まる）。欄の追加ではなく、L40.6b の後の推す案（README の不在中の節）の α が「関数型の効果の包含を被覆に」を含むので、例外の範囲と判断した。実例の表 3 つ（`Model`・`ModelTargets`・`ModelHttp` の `assumptions`）は証明を変えずに通った。07-04「形式化で仮定するもの」に書いた。レビューと、設計者が戻ったときの確認の一覧（README の (16)）に加えてほしい。
2. README の確認点 (9)（L30.1 の構造の等号による閉じ方を受け入れ、Release の効果の包含を構造上に保つ）は、α を採ったので前提が変わった。L30.1 の S ≠ Top の保存は判断 11 の専用補題（`HasTypeVsQ.widen_covers`）で閉じ直し、RV-L30 中1 の「判断 11 の専用補題を使っていない」は解消した。停止の表の「節の添字 S と継続の型」の行の「後の枝は Release の C-Sub と `Eff.Sub` を構造上の包含のまま保つ」は、C-Sub・C-Eff・`Ty.Le` と K-Handle・K-Handle-Fail の節の効果の前提が被覆になったことに改め、C-Handle・C-Handle-Fail と K-Handle の保護本体の効果の前提は構造上のまま保つことを後の枝の条件にするのがよい。
3. RV-L40 中1 の (a) の「脱糖が差し込む」は行っていない（α で不要になった）。L40.6b の推す案 Y の型検査器の書き換えも不要である。
4. README の確認点 (16) は α を採った結果として記録してほしい。

### L50・R20 への申し送り

5. L50.2: 型検査器の入口へ受理を組み込むときも、表層の検査器（段階 E2 の Lean の検査の関数）は効果を構造上の包含で受け入れる。Rust の型検査器が判断 5 の被覆で上限を受理するなら、段階 E2 の照合（Rust が書いた型の情報を Lean の検査の関数で検査する）は、被覆だけで受理されるプログラムを拒否する。検査の関数の `acceptEff`・`tyLe` を被覆にするか（`Surface.ScopeAccept.acceptAtom` の被覆の判定が使える）、照合の対象から外すかを決める必要がある。
6. L50.4（RV-L40 軽8）: 表層で IO に到達する例は、`Scope.checkPathIn` の結果の照合を含む表層のプログラムで作る。被覆の小例（`Surface/CoverExamples.lean` の `f`・`h`）を main から呼ぶ形にすれば兼ねられる。
7. R20: Rust の型検査器の効果の上限の受理（C-Sub・関数の型の包含に当たる箇所）を判断 5 の一原子の被覆にそろえる。Top を覆うのは Top だけ、和で覆わない。K10 でコアの型付けとの照合に入れる。
8. L50.3: `Ty.LeOld` と `ContTyOld` は旧の互換層の整理の対象である。

## 時間

| 区分 | 時刻（2026-10-28） | 所要 |
|---|---|---|
| 文書を読む | 09:15 頃〜09:23 | 約 8 分 |
| 試行（回 1〜17。本体の Release と表層が通るまで） | 09:23〜09:51 | 約 28 分 |
| 本体の残り（例・旧の像の補題・注釈、回 18〜20） | 09:51〜10:05 | 約 14 分 |
| 設計書・公理・work・本書 | 10:05〜10:20 頃 | 約 15 分 |

能動時間は約 50 分（試行 約 22 分、本体 約 28 分。読む時間を含まない）。外側の所要は約 65 分で、ビルドの待ち（回ごとに 1〜177 秒、合計 約 17 分）を含む。見込み（α で 2〜6時間）の下端より短く、上端の2倍（12時間）には近づいていない。
