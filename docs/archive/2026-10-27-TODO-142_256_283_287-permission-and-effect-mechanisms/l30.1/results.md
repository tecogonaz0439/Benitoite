# L30.1 の結果: 節の添字を選ぶ規則（一度の切り替え）

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L30.1（plan-l10-l50「L30」の表の L30.1 の行）。担当は Claude のサブエージェント |
| B_WORK | `5a3375956712af9912c9f7f65ed1516a7fbb8fce`（本線、L20.7 の取り込みの後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l30.1`。git の状態は変えていない |
| 状態 | **完了**。既定の全入口のビルドが sorry なしで通る |
| 閉じた範囲 | 依頼の 1〜5。`opSigAt`、節の添字の規則 `Eff.clauseRange` と許す添字 `ClauseIxOk`、`HasTypeClausesQ` が保護本体の効果から添字を選ぶ形、`find`・`no_failure`・`substTy` の追随、表層の `HasClausesQ.desugar` は Top を渡す。加えて、S ≠ Top の場合の保存（`pres_op_common`）も閉じた。そのために K-Handle の穴の効果を保護本体の効果にする継続の型の変更（plan では L30.2）を本枝で行った（「ずれと申し送り」1） |
| 未完 | なし（本枝の範囲）。L30.2 の残りは「ずれと申し送り」1 |
| 適用した前提の変更の行 | 停止の表の「節の添字 S と継続の型」（問 18 の行 8、README「設計者の決定（2026-10-27、L10〜L50 の計画）」の (2)） |
| 停止条件 | 該当しないと判断した。表にない前提・結論の内容の変更、結論の弱化、`Builtins.Assumptions` の欄の追加、公理の追加はない。ただし、型付けが規則の値のほかに Top も許すこと（「ずれと申し送り」2）と、継続の型の変更の前倒し（同 1）はレビューで確かめてほしい |

## 試行（最初の30〜60分）

plan「検査の割り当て」の「L の一度の切り替えの試行ビルド」の行に従い、排他の道具で既定の全体の `lake build` を回ごとに走らせ、診断を宣言とファイルへ対応付けた。各回の件数は [trial/counts.tsv](trial/counts.tsv)、回ごとの壊れた宣言は [trial/trial-decls.tsv](trial/trial-decls.tsv)、未検査のモジュールの一覧は [trial/unchecked.txt](trial/unchecked.txt)、生のログは `trial/build-NN-*.log` にある。

- 試行 T1（回 1〜3）: `opSigAt`・規則・`ClauseSig` を置き、`HasTypeClausesQ` に選択の効果の添字を足し、C-Handle は保護本体の効果 εM を、K-Handle は穴の効果 `εc ∪ handled(H)` を渡した（継続の型は変えない）。差分は [trial/trial-T1.diff](trial/trial-T1.diff)（回 1 の時点）・[trial/trial-T1-round3.diff](trial/trial-T1-round3.diff)。
- 試行 T2（回 4〜6）: K-Handle の穴の効果を保護本体の効果 εb にし、`εb ⊆ εc ∪ handled(H)` を前提にした。差分は [trial/trial-T2-round3.diff](trial/trial-T2-round3.diff)。
- 本体（回 7〜11）: `pres_op_common` の書き直しの後の表層の追随と、新しいモジュールの検査。

| 回 | 終了 | 誤り | 壊れた宣言 | ファイル | 未検査のモジュール |
|---|---|---|---|---|---|
| 1（T1） | 1 | 13 | 6 | 4 | 201 |
| 2（T1） | 1 | 6 | 2 | 2 | 63 |
| 3（T1） | 1 | 2 | 2 | 1 | 55 |
| 4（T2） | 1 | 1 | 1 | 1 | 55 |
| 5（T2） | 1 | 2 | 2 | 1 | 43 |
| 6（T2） | 1 | 4 | 1 | 1 | 42 |
| 7〜9（本体） | 1 | 2・3・2 | 各 1 | 各 1 | 11・5・2 |
| 10・11（本体） | 0 | 0 | 0 | 0 | 0 |

回をまたいだ一意数は、壊れた宣言 17・ファイル 12 である（回 1 の時点で直した言明の追随を除く）。差分全体を宣言へ対応付けると 60 宣言・23 ファイルに及ぶ（[trial/changed-decls.tsv](trial/changed-decls.tsv)。新しいモジュール `ClauseIx.lean` と設計書を除く。挿入した新しい宣言の行の一部は直前の宣言に数えている）。大半は引数を一つ足す機械的な追随で、内容の変更は `ContTy.split`・`ContTy.inv_handle`・`pres_op_common`・`preservationE`・`HasTypeClausesQ.substTy`・`HasClausesQ.desugar` だけだった。

未検査の数は、失敗したモジュールに依存するモジュールの数で、`l00.06b/tools/unchecked.py` で数えた（閉包は今の既定の import の 299 モジュール）。

件数は小さく、枝の上端（2.5時間）の2倍を超える見込みはなかったので、試行をそのまま本体へ進めた。T1 は継続の型を変えないので、E-Handle の後の枠で、保護本体の効果 εM から選んだ添字の節を、穴の効果 `εc ∪ handled(H)` から選ぶ添字（`handled(H)` が名前 L の全ての範囲の原子を含むので Top）の節へ移せず、閉じない（`preservationE` の `E_Handle` の腕）。そのため T2 で継続の型を変えた。

## 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `opSigAt`（`Release/Typing.lean`、新） | 捕捉した組み込みの操作の型を節の添字 S の列（`List.replicate s.nranges S`）で具体化する。引数は `Ty.instTarget`、結果は `s.ret` のまま（S1 の条件により範囲の変数を持たない。計算できる形）。利用者の操作は `opSig` と同じ |
| `Eff.ClauseRangeIs`・`Eff.clauseRange`（同、新） | 判断 11 の規則。行の変数がなく、名前 L の原子がちょうど一つで閉じた範囲 r を持てば r、それ以外（複数原子・同名 Top・未確定の行変数・同名原子なし）は Top。`Eff` は原子の述語なので、規則の値は古典論理で定めた（計算できない） |
| `ClauseIxOk`（同、新） | 許す節の添字。`S = .top ∨ ∃ b s l, o = .prim b ∧ B.sig b = some s ∧ s.opEff = some l ∧ e.ClauseRangeIs l S`。規則の値と Top を許す（「ずれと申し送り」2） |
| `ClauseSig`（同、新） | 節の型付けの前提。`∃ S, ClauseIxOk B e o S ∧ opSigAt P B S o = some sg` |
| `HasTypeClausesQ`（同） | `Option Ty` の次に選択の効果（保護本体の効果）の添字 εb を足し、`cons` の前提 `opSig P B o = some sg` を `ClauseSig P B εb o sg` にした |
| `HasTypeCQ.C_Handle`（同） | 節の型付けに保護本体の効果 εm を渡す |
| `ContTy.K_Handle`（`Release/Semantics.lean`） | 穴の効果を `Eff.union εc (handled P B h)` から保護本体の効果 εb にし、前提 `Eff.Sub εb (Eff.union εc (handled P B h))` を足した。節の型付けは εb で選ぶ（問 18 の行 8、計画の決定 (2) の継続の型の変更） |

`Builtins.Assumptions`・`CoreAssumptions`・`TargetAgreement` と主定理のファイル（`Release/Theorems.lean`・`Surface/Theorems.lean`）は変えていない。`Scope/` の採用定義も変えていない。

## 置いた定理

| ファイル | 定理 |
|---|---|
| `Release/Typing.lean` | `opSigAt_top`（S = Top で `opSig`）・`opSigAt_user`・`ClauseSig.ne_fail`・`ClauseSig.of_opSig`（Top の添字はどの効果でも許す）・`ClauseSig.user` |
| `Release/Lemmas/TySubstMain.lean` | `opSigAt_scoped`・`ClauseSig.scoped`（`opSig_scoped` はこの系に書き直した）、`Eff.mem_substAt_of_noRows`・`Eff.ClauseRangeIs.substAt`・`ClauseSig.substAt`（型の代入で節の添字が保たれる） |
| `Release/ShapeOk.lean` | `Builtins.ShapeOk.eff_cases`（効果は `L[Top]` で範囲の変数 0 個か、`L[rvar 0]` で 1 個） |
| `Release/Lemmas/ContLemmas.lean` | `ContTy.split` の結論に、枠の穴の効果 εh と、枠より内側の継続が処理しない名前の原子が継続の先頭の効果から εh へ同じ範囲の位置のまま届くことを加えた。`ContTy.inv_handle` の結論は `ε = εc ∪ handled` から `Eff.Sub ε (εc ∪ handled)` と節の型付けの選択の効果 ε に変えた |
| `Release/Lemmas/Preservation.lean` | `NoHandler.handled_false`（`ContTy.end_of_noHandler_ix` の内側の議論を補題にした）。`pres_op_common` は前提 `hsg : opSig P B o = some sg`・`hsat`・`hargs`・`hle` を、`o ≠ .fail` と、選んだ節の操作の型について型付けを返す関数 `hsel` に替えた |
| `Release/Lemmas/PresMain.lean` | `preservationE` の `E_Handle`（枠の穴の効果は εm）、`E_Op`（`ClauseSig.user`）、`E_OpPrim`（S = Top は `widen_topRanges`。S が規則の値なら、呼び出しの効果の原子 `L[r]` が穴の効果に届き、その効果の名前 L の原子は `L[S]` だけなので r = S、範囲の列は S の列に等しい） |
| `Release/Lemmas/ClauseIx.lean`（新、既定の import に追加） | 規則の性質 `Eff.ClauseRangeIs.unique`・`Eff.clauseRange_of`・`clauseRange_spec`・`clauseRange_of_not`・`clauseRange_of_rho`・`clauseRange_of_two`・`clauseRange_of_none`・`clauseRange_of_top`・`ClauseIxOk.rule`・`ClauseIxOk.iff`・`ClauseIxOk.top_of_rho`。旧の像の同値（下）。例 `ClauseIxExamples`（下） |

## 同値の補題（旧の像）

旧の像は、範囲の変数を持たない表（全ての項目で `nranges = 0`）である。

| 変えた前提 | 補題（`Release/Lemmas/ClauseIx.lean`） | 内容 |
|---|---|---|
| 節の型付けの前提 `ClauseSig` | `opSigAt_eq_opSig_of_rangeFree`・`ClauseSig.iff_opSig_of_rangeFree` | 節の添字によらず `opSigAt = opSig`。前提は旧の `opSig P B o = some sg` と同値 |
| 節の型付けの選択の効果 | `HasTypeClausesQ.sel_congr_of_rangeFree` | 節の型付けは選択の効果によらない |
| K-Handle の穴の効果 | `ContTyOld`（旧の継続の型付けの写し）、`ContTyOld.toNew`・`ContTy.toOld`・`contTy_exists_iff_old` | 旧の形は新しい形である（表によらない）。旧の像では新しい形の穴の効果を広げて旧の形に戻せる。状態の型付けとストアの継続の型付けが使う形「計算の効果を含む穴の効果の継続の型付けがある」は新旧で同値 |

## 主定理の言明と前提の内容

主定理の字面は L20.7 の後と同じである（`Release/Theorems.lean`・`Surface/Theorems.lean` は変えていない）。

| 主定理 | 字面 | 変更前の前提の内容 | 変更後の前提の内容 | 旧の像での同値 |
|---|---|---|---|---|
| `progress` | 変更なし（`hwt : P.WellTyped B`、`hdecl`、`hb : B.CoreAssumptions P`、`StateTy P B s`） | 節は `opSig`（Top の添字）で型付ける。K-Handle の穴の効果は `εc ∪ handled(H)` | 節は Top か規則の値の添字で型付ける。K-Handle の穴の効果は保護本体の効果 εb ⊆ `εc ∪ handled(H)`。`StateTy` に入る状態が広がり前提が弱まる | `ClauseSig.iff_opSig_of_rangeFree`・`sel_congr_of_rangeFree`・`contTy_exists_iff_old` |
| `preservation` | 変更なし | 同上 | 同上。前提と結論の両方が広がる | 同上 |
| `effect_soundness`・`effect_soundness_noLamNames` | 変更なし | 初期の計算の型付けと `P.WellTyped` の節は Top の添字 | 節は Top か規則の値の添字（型付けられる計算が広がる） | `ClauseSig.iff_opSig_of_rangeFree`・`sel_congr_of_rangeFree` |
| `step_sound` | 変更なし（`horacle` は L20.6 の形） | `progress`・`preservation` と同じ | 同上 | 同上 |
| `desugar_typed` | 変更なし | 結論の `WellTyped` の節は Top の添字 | 結論の `WellTyped` の内容は広がるが、脱糖は Top の添字で型付ける（`HasClausesQ.desugar`。L40.5 まで） | 同上 |
| `surface_effect_soundness` | 変更なし | 同上 | 同上 | 同上 |

## 確かめた例

`ClauseIxExamples`（`Release/Lemmas/ClauseIx.lean`。L20.7 の表 `TargetTable.builtins` の `File.writeTextIn`、効果 `File.Write[rvar 0]`、引数 `PathIn[rvar 0]`）。

- 保護本体の効果 `{File.Write[/data/**]}` の規則の値は `/data/**`。`{File.Write[/data/**], File.Write[/logs/**]}`・`{File.Write[/data/**], ρ0}`・`{File.Write}`（Top）・`{File.Read[/data/**]}` の値は Top。
- `clauseSig_data`: 効果 `{File.Write[/data/**]}` のもとで、節の操作の型の引数は `[PathIn["/data/**"], String]`（Top でない添字の節の型付け）。
- `clauseSig_top`: 同じ節は Top の添字（引数 `[PathIn[Top], String]`）でも型付けられる。
- `not_clauseSig_data_rho`: 行の変数を持つ効果 `{File.Write[/data/**], ρ0}` のもとでは `/data/**` の引数の型を選べない。

S ≠ Top の節を持つプログラムの保存は、一般の `preservation` の `E_OpPrim` の腕で閉じている。別の対象へ書く節の例（L00.07 の例 3a・3b・3c の本番版）は L30.3 の範囲である。

## 設計書

- 01-12「ハンドラ」: 節の添字の【決定】を書き直した（`opSigAt`、規則、型付けが Top も許す理由）。K-Handle の穴の効果の【決定】を加えた（`ContTy.split`、S が規則の値の場合の範囲の列の一致、旧の像での同値、脱糖は Top）。「構文」の `PrimSig.Scoped` の理由の文の「Top の列で具体化」を節の添字の列に直した。「確かめる性質」の K-Handle の箇条に、形式化した Release の穴の効果を補った。
- 07-04「証明する性質」: 節の添字と継続の型の前提の変更の【決定】の段落を加え、V-Prim の段落の「`opSig` は Top の列で具体化した型」を直した。
- 07-04「01-12 との対応」: 行「初回リリース版の拡張: ハンドラ（節の添字と枠の上の効果）」を加えた（Rust は未接続）。
- 見出しは足していない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 最大常駐量 | 記録 |
|---|---|---|---|---|---|
| 試行・本体のビルド（11 回） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 回 1〜9 は 1、回 10・11 は 0 | 0.8〜155.4 秒 | 最大 3150823424 バイト（3004.8 MiB、2.93 GiB。回 3） | [trial/](trial/) |
| 作業末の全体のビルド | 同上 | 0（449 ジョブ、sorry の警告なし） | 0.14 秒（回 11 までに全て組み立て済み） | 69419008 バイト（66.2 MiB、0.06 GiB） | [lake-build.log](lake-build.log) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l30.1>/axioms.lean`（71 件の `#print axioms`） | 0 | 0.60 秒 | 1514143744 バイト（1444.0 MiB、1.41 GiB） | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work（1 回目） | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 5a3375956712af9912c9f7f65ed1516a7fbb8fce` | 0 | 9.48 秒 | 1384759296 バイト（1320.6 MiB、1.29 GiB） | [work-check-1.log](work-check-1.log)・[work-check-1-time.txt](work-check-1-time.txt) |
| work（2 回目。01-12 の修正の後） | 同上（先に同じ指定で `--dry-run`） | 0 | 4.14 秒 | 78266368 バイト（74.6 MiB、0.07 GiB） | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt)・[work-check-dry-run.log](work-check-dry-run.log) |

- dry-run の選択: `spec_tally`・`spec_examples`（01-12 の変更）、`formal_build`（`formal/Benitoite.lean` ほか）。どちらの work も三つとも通った（`spec_examples` 7 件成功）。
- 最大常駐量は macOS の `/usr/bin/time -l` の値（バイト）。一つのコマンドの子のうち最大のもので、並行しない。ビルドの回 10・11 と作業末のビルドは組み立て済みのモジュールが多く、小さい。
- 公理: 71 件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 57、`propext` だけ 10、`propext`・`Quot.sound` 2、依存なし 2）。`sorryAx` と独自の公理はない。対象は新しい定理・言明を変えた定理・証明を直した主な定理と、主定理 7 件（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness`）、範囲付きのプログラムの例 3 件（`s0_progress`・`s0_preservation`・`ioState_progress`）である。

## 失敗と修正

- 試行の回 1〜9 の失敗は全て計画した切り替えの追随である（上の表）。回 3 で T1 が継続の型を変えないままでは閉じないことを確かめ、回 4 から T2 にした。
- `ClauseIx.lean` の単一ファイルの検査で、`dif_pos` の非推奨の警告（`split` に替えた）、文字列の名前の原子の `cases` の失敗（`simp` に替えた）、表の引きの `simp` の失敗（`sig_writeTextIn : … := rfl` を置いた）を直した。
- 01-12 の修正（構文の段落の古い「Top の列」）を work の 1 回目の後に行ったので、work をやり直した（2 回目）。

## ずれと申し送り

1. **継続の型の変更の前倒し**（plan では L30.2）。S ≠ Top を選ぶ規則を入れると、E-Handle の後の枠の節の型付けを保つには K-Handle が保護本体の効果を残す必要がある（試行 T1）。停止の表の「節の添字 S と継続の型」の行は L30.1・L30.2 の両方に適用でき、依頼も本枝で閉じる場合を認めていたので、本枝で行い、`pres_op_common` の S ≠ Top の場合も閉じた。R ⊆ S は被覆の健全性（L00.03 の `hcov`）からでなく、構造の等号（穴の効果の名前 L の原子は `L[S]` だけで、呼び出しの原子 `L[r]` がそこに届くので r = S）から得た。L30.2 の行の内容（継続の型、R ⊆ S、`pres_op_common`、07-04「証明する性質」の前提）は本枝で済んだので、取りまとめが L30.2 を点検だけにするか、ほかの枝へ合わせるかを決めてほしい。被覆による節の添字（R が S に覆われる場合）を型付けで許す拡張は行っていない（判断 11 は同名の閉じた一原子の範囲そのものを S にする）。
2. **型付けは規則の値のほかに Top も許す**（`ClauseIxOk`）。判断 11 の規則は型検査器が S を一つ選ぶ規則であり、宣言的な型付けを規則の値だけにすると型の代入で保存が成り立たない。例: 行の変数 ρ を持つ多相の関数の本体の `handle` は、保護本体の効果 `{File.Write[/data/**]} ∪ ρ` から S = Top を選ぶ。ρ := {} で呼ぶと、代入の後の本体の保護本体の効果の規則の値は `/data/**` になり、Top で型付けた節（引数 `PathIn[Top]` を Top の書き込みへ渡す本体など）が規則の値の添字では型付かず、`preservation` の大域の関数の呼び出しの場合（`HasTypeCQ.substTy` を使う腕）が成り立たない（規則の字面から導いた反例。Lean では試していない）。Top も許す形は代入で保たれる（`ClauseSig.substAt`。規則の値の条件は行の変数を持たない効果にだけ成り立ち、代入で変わらない）。型検査器（L40.5）は規則の値を選ぶ。許す添字は規則の値と Top だけであり（`ClauseIxOk.iff`）、節の本体や期待される出力から S を逆算しない。
3. L30.3: 名前全体の除去と節の IO の点検は、`ContTy.split` の新しい結論（枠の穴の効果に届く原子）と `ContTy.name_end_ix` を使える。例 3a・3b・3c の本番版は `ClauseIxExamples.clauseSig_data` の節の操作の型から作れる。
4. L30.4・L30.5: `E_OpPrim` の一段の対象健全性では、節の本体へ渡る捕捉した引数は、S が規則の値なら呼び出しの範囲 R = S の型、Top なら Top の型を持つ（`preservationE` の `E_OpPrim` の腕と同じ場合分け）。
5. L40.5: 表層の `HasClausesQ.desugar` は任意の選択の効果を受け取り、Top の添字で型付ける。表層の構文と検査器に節の添字を入れるときは、表層の効果の表現で計算できる規則（Release の `Eff.clauseRange` は原子の述語の上の古典的な定義で計算できない）と、Release の規則の値との一致の補題が要る。
6. L50.3: 比較のための写し `ContTyOld` は旧の互換層の整理の対象である。
7. `pres_op_common` の言明（内部の補題）を変えた。主定理ではない。

## 時間

| 区分 | 時刻（2026-10-28） | 所要 |
|---|---|---|
| 文書を読む | 04:15 頃〜04:30 | 約 15 分 |
| 試行（T1・T2、回 1〜6） | 04:30〜04:49 | 約 19 分 |
| 本体（`pres_op_common`、表層、`ClauseIx.lean`、回 7〜11） | 04:49〜05:00 | 約 11 分 |
| 公理・設計書・work・結果の記録 | 05:00〜05:08 | 約 8 分 |

能動時間は約 53 分（試行 約 19 分、本体と記録 約 19 分、読む時間 約 15 分）。外側の所要は 04:15 頃〜05:08 の約 53 分。ビルドの待ち（回ごとに 1〜155 秒）を含む。見込み（0.25〜2.5 時間）の範囲内であり、上端の2倍には近づいていない。
