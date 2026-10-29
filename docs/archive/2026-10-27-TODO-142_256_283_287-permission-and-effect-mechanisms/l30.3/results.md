# L30.3 の結果: 名前全体の除去の点検と、継続を通した対象の伝播（L30.2 の点検を含む）

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L30.3（plan-l10-l50「L30」の表の L30.3 の行）と、注「L30.1 の結果による付け替え」による L30.2 の点検。担当は Claude のサブエージェント |
| B_WORK | `8787b27645f1745fb77005ab164673dafdafd348`（本線、L30.1 の取り込みの後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l30.3`。git の状態は変えていない |
| 状態 | **完了**。既定の全入口のビルドが sorry なしで通る |
| 閉じた範囲 | 依頼の 1〜4。L30.2 の点検（不足なし）。`ContTy.end_of_noHandler` の対象版を、処理されない操作・捕捉の枠・解放の枠について置いた。例 3a・3b・3c の本番版を置き、3a は初期状態から節の IO の事象まで実行して観測が初期の上限に許されることを示した |
| 未完 | なし（本枝の範囲）。後の枝の範囲は「ずれと申し送り」 |
| 適用した前提の変更の行 | なし。型付け・遷移・仮定・主定理の定義を変えていない（新しい補題と例だけ） |
| 停止条件 | 該当しない。主定理の字面と前提の内容は L30.1 の後から変えていない。結論の弱化、`Builtins.Assumptions` の欄の追加、公理の追加はない |

## L30.2 の点検

| 点検の項目 | 結果 | 根拠 |
|---|---|---|
| 主定理の字面が L20.7 の後（と RV-L20-fix の表層の `hb`）と同じ | 同じ | `git diff 5a337595 8787b276 -- formal/Benitoite/Release/Theorems.lean` は空。`Surface/Theorems.lean` の差分は RV-L20-fix の `surface_effect_soundness` の `hb : B.CoreAssumptions …` だけ。本枝は両ファイルを変えていない |
| 07-04「証明する性質」の前提の記述が継続の型の変更（`K_Handle` の穴の効果）を書いている | 書いている | L30.1 が加えた【決定】の段落（節の添字 S、K-Handle の枠の上の効果を保護本体の効果 εb とし `εb ⊆ εc ∪ handled(H)`、`StateTy` が広がること、`progress`・`step_sound` の前提が弱まり `preservation` の前提と結論が広がること、旧の像での同値 `ContTy.toOld`・`ContTyOld.toNew`・`contTy_exists_iff_old`） |
| `pres_op_common` の S ≠ Top の場合が閉じている | 閉じている | `Release/Lemmas/PresMain.lean` の `preservationE` の `E_OpPrim` の腕。`ClauseIxOk` の二つの場合（`rfl` は `widen_topRanges`、規則の値は `ShapeOk.eff_cases`・`NoHandler.handled_false`・`ClauseRangeIs` の一意性から範囲の列が S の列に等しい）。sorry なしで既定ビルドを通る |
| 「被覆の健全性から R ⊆ S を導く」形が要らない | 要らない | 同じ腕は `Eff.Covers`・`Range.Covers` を使わず、穴の効果の名前 L の原子が `L[S]` だけであることから構造の等号 r = S を得る。`Covers` を使う Release の補題は `MembershipBase`（値の拡大 `checked_widen`）と `TargetSound`（許可の関係）だけで、保存の E-OpPrim の腕は読まない |

足りない記述はなかったので、L30.2 の点検による設計書の修正はない。

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Release/Lemmas/TargetPropagation.lean` | 新規。継続を通した対象の伝播の補題 12（下の表） |
| `formal/Benitoite/Release/HandlerTargetExamples.lean` | 新規。例 3a・3b・3c の本番版（定理 36、`example` 2） |
| `formal/Benitoite.lean` | 既定の import に上の二つを加えた（`Release.Lemmas.ClauseIx` の後） |
| `docs/design/01-spec/01-12-core-calculus.md` | 「ハンドラ」の箇条に、継続を通した対象の伝播の箇条を一つ加えた（K-Handle の【決定】の次） |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」に行「初回リリース版の拡張: ハンドラ（継続を通した対象の伝播）」を加えた（Rust は未接続） |

型付け・遷移・仮定の定義（`Typing.lean`・`Semantics.lean`・`Assumptions.lean`）、主定理のファイル、`Surface/`、`Scope/` の採用定義は変えていない。見出しは足していない。

## 置いた定理

`Release/Lemmas/TargetPropagation.lean`（許可の関係 `Eff.Allows κ` の κ は任意。対象健全性では表の `effKind` の `Builtins.Allows`）:

| 場合 | 定理 | 内容 |
|---|---|---|
| 一般 | `ContTy.allows_end` | 先頭の効果が許す名前 l の対象は、l を処理する枠が継続になければ末尾の効果も許す（`ContTy.name_end_ix` から） |
| 処理されない操作 | `ContTy.allows_end_of_noHandler` | 組み込みの操作 b0 を処理する枠がなければ、先頭の効果が許す l の対象を末尾の効果が許す |
| 同上 | `ContTy.allows_end_of_prim_call` | IO・終了の呼び出しの型付けと継続の型付けから、具体化した署名の効果が許す対象は末尾の効果が許す。許す名前は署名の操作の名前 l だけ（`l' = l`） |
| 捕捉の枠 | `ContTy.allows_hole_of_split` | 操作を処理する最も内側の枠で分けると、先頭の効果が許す対象を枠の上の効果 εh（保護本体の効果）が許す（`ContTy.split` から） |
| 同上 | `ContTy.allows_clause_end` | 節の効果 εc（⊆ 枠の下の継続の先頭の効果）が許す対象は、処理する枠がなければ枠の下の継続の末尾の効果が許す（節自身の IO が外側の上限に残る） |
| 名前全体の除去 | `mem_handled_of_nameTop` | `handled(H)` が名前 l を含めば、l のどの範囲の位置の原子も含む |
| 同上 | `Eff.mem_outer_of_not_handled`・`Eff.allows_outer_of_not_handled` | `εm ⊆ ε ∪ handled(H)` のもとで、`handled(H)` が含まない名前の原子と許す対象は、同じ範囲の位置のまま ε に残る |
| 解放の枠 | `releases_no_handle`・`NoHandler.releases_append` | `releases(K')` は `handle` の枠を含まず、積んでも処理する枠の条件は変わらない |
| 同上 | `ContTy.allows_end_release`・`ContTy.allows_end_releases` | `release` の枠、`releases(K') ++ K` を越えて対象が末尾へ届く |

## 確かめた例

`Release/HandlerTargetExamples.lean`（表は L20.7 の実例 `ModelTargets.Examples.B`。`File.Write` の操作は `File.writeTextIn` だけで、`CoreAssumptions`・`TargetAgreement` を満たす）:

- 3a（別の対象へ書く節）: `handleLog = handle File.writeTextIn[;;/data/**](checked(/data/a.txt), "x") with { writeTextIn(p, s) k ⇒ File.writeTextIn[;;/logs/**](checked(/logs/l.txt), "log") }`。
  - 節の添字は規則の値 `/data/**`（`clauseSig_data`。Top でない）、外側の上限は `{File.Write[/logs/**]}`（`handleLog_typed`）。保護本体の `File.Write[/data/**]` は `handled(H)` が名前全体で除く（`mem_handled_write`）。
  - 外側の上限は `/logs/l.txt` を許し（`logsBound_allows_log`）、`/data/a.txt` を許さない（`logsBound_not_allows_data`）。
  - 実行: 初期状態 `⟨handleLog, [], ∅⟩` を初期の効果を末尾に固定した `StateTyE` で型付け（`s0_typed`。`stateTyE_init_eff`）、E-Handle と E-OpPrim で節の IO の状態へ進み（`reach_io`）、`steps_preserve` で同じ末尾の型付けを得る（`sIO_typed`）。その状態の E-IO の事象の観測は `[/logs/l.txt]`（`sIO_step`）で、`allows_end_of_prim_call` と `TargetAgreement.obs_allowed` から初期の上限に許される（`sIO_obs_allowed`）。完了の条件「別の対象へ書く節で外側の上限にその対象が残る例」はこれである。
  - 捕捉の枠: E-Handle の後の状態で、捕捉される呼び出しの対象 `/data/a.txt` は処理する枠の穴の効果に許される（`s1_hole_allows`。`allows_hole_of_split` を使う）。
- 3b（捕捉した引数を転送する節）: 節が捕捉した引数（番号 2。`PathIn["/data/**"]`）と文字列を `File.writeTextIn[;;/data/**]` へ渡す。外側の上限は `{File.Write[/data/**]}`（`handleFwd_typed`）で、`/data/a.txt` を許す。
- 3c（利用者の操作）: プログラム `progReport` が `Report` の操作 `save(path: PathIn["/data/reports/**"], text: String) -> Unit` を宣言する。保護本体 `save(checked(/data/reports/2026.txt), "x")` は V-Op で `{Report}`、節 `let _ = File.writeTextIn[;;/data/reports/**](path, text) in resume k ()`。外側の上限は `{File.Write[/data/reports/**]}` だけで `Report` を含まない（`handleSave_typed`・`reportsBound_no_report`）。節の操作の型はどの節の添字でも宣言の型（`opSigAt_save`）。`save` は組み込みの表になく、`Report` は種類も組み込みの操作の一覧も持たない（`save_not_builtin`）。3c は型付けだけで、実行と `StateTy` は置いていない（`progReport` の `WellFormed` を示していない）。

利用者の操作の `V_Op`・`E_Op` は、B0（`6124775…`）からの差分がない（`git show 6124775…:formal/Benitoite/Release/Typing.lean` の `V_Op`、同 `Semantics.lean` の `E_Op` と字面が同じ）。L30.1 の節の型付けの変更は、利用者の操作では `opSigAt_user`・`ClauseSig.user` により以前の `opSig` と同じである。`handled` は L10.2 の形（範囲によらず名前の原子を除く）のままであり、型付けの内容を変えていない。

## 主定理の言明と前提の内容

本枝は主定理と、主定理が使う定義を変えていない。字面と前提の内容は L30.1 の後と同じである。

| 主定理 | 字面 | 前提の内容 |
|---|---|---|
| `Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound` | L20.7 の後と同じ（`hb : B.CoreAssumptions P`、`step_sound` の `horacle` は L20.6 の形） | L30.1 の後と同じ（節は Top か規則の値の添字、K-Handle の穴の効果は保護本体の効果） |
| `Surface.desugar_typed` | 同じ | 同じ |
| `Surface.surface_effect_soundness` | RV-L20-fix の後と同じ（`hb : B.CoreAssumptions …`） | 同じ |

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 最大常駐量 | 記録 |
|---|---|---|---|---|---|
| 最初の全体のビルド（RV-L20-fix の分の作り直し） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0（449 ジョブ） | 43.85 秒 | 1522384896 バイト（1451.9 MiB、1.42 GiB） | [builds/build-01-initial.log](builds/build-01-initial.log) |
| 新しいモジュールのビルド（例のファイルの単一検査に要る olean） | 同上に引数 `Benitoite.Release.Lemmas.TargetPropagation` | 0 | 0.36 秒 | 740884480 バイト（706.6 MiB、0.69 GiB） | [builds/build-02-propagation.log](builds/build-02-propagation.log) |
| 全体のビルド（Lean の変更の後） | 同上（引数なし） | 0（451 ジョブ） | 1.73 秒 | 1523351552 バイト（1452.8 MiB、1.42 GiB） | [builds/build-03-full.log](builds/build-03-full.log) |
| 作業末の全体のビルド | 同上 | 0（451 ジョブ、`declaration uses 'sorry'` なし。警告は最初のビルドと同じ 90 件で、新しいファイルの警告はない） | 0.15 秒（組み立て済み） | 70254592 バイト（67.0 MiB、0.07 GiB） | [lake-build.log](lake-build.log) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l30.3>/axioms.lean`（55 件の `#print axioms`） | 0 | 0.61 秒 | 1513226240 バイト（1443.1 MiB、1.41 GiB） | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 8787b27645f1745fb77005ab164673dafdafd348`（先に同じ指定で `--dry-run`） | 0 | 9.59 秒 | 1385021440 バイト（1320.9 MiB、1.29 GiB） | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt)・[work-check-dry-run.log](work-check-dry-run.log) |

- dry-run の選択: `spec_tally`・`spec_examples`（01-12 の変更）、`formal_build`（`formal/Benitoite.lean` ほか）。計画の見込みどおりで、三つとも通った（`spec_examples` 7 件成功）。
- 途中の単一ファイルの検査は `lake env lean -M 12288 <ファイル>` で約 12 回（各 1 秒前後。計時していない）。
- 最大常駐量は macOS の `/usr/bin/time -l` の値（バイト）。一つのコマンドの子のうち最大のもので、並行しない。作業末のビルドは組み立て済みで小さい。
- 公理: 55 件とも標準の三公理の部分集合だけに依存する（三つ全て 44、`propext`・`Quot.sound` 9、`propext` だけ 2）。`sorryAx` と独自の公理はない。対象は新しい定理 48（伝播 12、例 36）と主定理 7 件（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness`）。`decide` は範囲の所属・名前の文字列の小さい判定だけに使った。

## 失敗と修正

- 例のファイルの単一検査で、`TargetPropagation` の olean がなく止まった（排他の道具でモジュールをビルドした）。`decide` に自由変数を含む目標を渡した 2 箇所（`simp` に替えた）、`Ty.WF.canonical` の暗黙の引数、`kd` の具体化、`saveCall` の展開、`Clause.op` の展開、`Ty.shiftAt` の名前の誤り、`C_Resume` の型の推論の順（`(b := .base .unit)` を明示）を直した。どれも単一ファイルの検査の段階で、全体のビルドの失敗はない。

## ずれと申し送り

計画からのずれ:

1. 補題の置き場所: 計画の対象ファイルは `Lemmas/ContLemmas.lean`・`EffectSound.lean` だが、伝播の補題は新しいモジュール `Release/Lemmas/TargetPropagation.lean` に置いた。`allows_end_of_prim_call` が `EffectSound`（`end_of_noHandler_ix`）と `TargetSound`（`Builtins.Allows`）と `inv_prim_app` の後にあり、既存のファイルへ入れると依存の多いファイルを作り直すためである。例は `Release/HandlerTargetExamples.lean` に置いた（計画に候補の名前がない）。
2. 例の表: L00.07 の例は `File.writeTextIn` の項目を持つ表で書いた。`TargetTable.builtins`（`File.Write` の操作が四つ）でなく、仮定を満たす実例 `ModelTargets.Examples.B`（操作が一つ）を使った。名前全体の除去は「名前の全操作の節がそろう」条件を持つので、一つの節で `File.Write` を処理できる表のほうが例が小さい。
3. 3c は型付けだけで、実行していない（上の「確かめた例」）。

後の枝への申し送り:

4. L30.4: `E_IO`・`E_IOErr`・`E_Exit` の場合は、`sIO_obs_allowed` と同じ組み立て（`StateTyE` の分解、`ContTy.allows_end_of_prim_call`、`inv_prim_app`、`TargetAgreement.obs_allowed`）で一般に閉じられる見込みである。`allows_end_of_prim_call` の結論は許す名前が署名の操作の名前だけであること（`l' = l`）を含み、RV-L00 中1 の反例（別の名前の原子を上限に足しても書き込みを許さない）の補題の部品になる。解放の事象（`Event.release`）は観測を持たない。`E_OpPrim`・`E_Op` は事象を伴わないので、一段の言明は事象を伴う遷移だけで足り、節の IO は後の状態の E-IO として扱われる（3a の実行のとおり）。`Http` の項目には何も言わない（RV-L20 の後の注 (1)。L40.3b）。
5. L30.5: 3a の `s0_typed`・`sIO_typed` は、初期の ε を末尾に固定した `StateTyE` と `steps_preserve` で到達先を型付ける形の実例である。別の対象の節の本番の例は 3a を使える。誤った節の規則の反例は L30.5 の範囲である。
6. L30.4・L30.5: `allows_clause_end` は、節の型付けを反転して節の本体の効果を取り出す補題とあわせて使う。本枝の例では、節の IO は保存の定理を通した後の状態の E-IO として示し、節の型付けの反転はしていない。
7. L40.4・L40.5: 表層の節は Top の添字で型付けるので、例 3a の節の添字 `/data/**` を表層から作るのは L40.5 である。利用者の操作の宣言の範囲付きの型（3c）と E0506・E0513 は L40（Rust は UB20）。
8. L50.3: `HandlerTargetExamples` は `ModelTargets.Examples` の表とプログラムに依存する。実例の整理（L20.7 の申し送り 12）の対象に含める。

## 時間

| 区分 | 時刻（2026-10-28） | 所要 |
|---|---|---|
| 文書と定義を読む | 05:12〜05:21 | 約 9 分（最初の全体のビルドの待ち 44 秒を含む） |
| 伝播の補題 | 05:21〜05:22 | 約 2 分 |
| 例 3a・3b・3c と 3a の実行 | 05:22〜05:27 | 約 6 分 |
| 設計書・ビルド・公理・work | 05:27〜05:29 | 約 3 分 |
| 本書 | 05:29〜05:32 | 約 3 分 |

能動時間は約 19 分（ビルドの待ち約 1 分を除く）。外側の所要は 05:12〜05:32 の約 20 分（時刻は概算）。見込み（0.5〜4 時間）の下端を下回り、上端の2倍（8 時間）には近づいていない。排他の道具の待ちは 4 回とも 0 秒。設計者の回答待ちなし。
