# L30.5 の結果: 到達先の対象健全性と本番の例

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L30.5（plan-l10-l50「L30」の表の L30.5 の行）。担当は Claude のサブエージェント |
| B_WORK | `fb85cf48947aad191e98b4414577452b5181e80b`（本線、L30.4 の取り込みの後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l30.5`。git の状態は変えていない |
| 状態 | **完了**。既定の全入口のビルドが sorry なしで通る |
| 閉じた範囲 | 依頼の 1〜6。到達先の言明と証明、非 Top の IO・別の対象の節（例 3a）・誤った節の規則の反例を本番の定義で置いた。Http について言うこと・言わないこと、07-04「証明する性質」と「01-12 との対応」、01-12「実行の規則」の補足、L30 の段末の確認 |
| 未完 | なし（本枝の範囲） |
| 適用した前提の変更の行 | なし。型付け・遷移・仮定・主定理の定義を変えていない（新しい定理と例だけ） |
| 停止条件 | 該当しない。主定理の字面と前提の内容は L30.4 の後から変えていない（`git diff fb85cf48 -- formal/Benitoite/Release/Theorems.lean` は import 一行と新しい定理の追加だけで、削除行はない。`Surface/`・`Scope/` の差分は空）。結論の弱化、`Builtins.Assumptions` の欄の追加、公理の追加はない |

## 到達先の定理の言明と前提

`formal/Benitoite/Release/Theorems.lean`:

```lean
theorem reachable_target_sound (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hc : B.CoreAssumptions P) (ht : B.TargetAgreement P) {m : Comp} {a : Ty} {ε : Eff}
    (hm : HasTypeC P B StoreTy.empty [] [] none m a ε) (hcl : m.ClosedNoEffVars)
    {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hsteps : Steps P B (.run m [] Store.empty) s) (hst : Step P B s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows ε l t
```

- 証明は `step_target_sound hdecl hc ht (steps_preserve hwf hwt hdecl hc hsteps (stateTyE_init_eff hwf hc hm hcl)) hst` の一行である。初期の ε を継続の末尾に固定した `StateTyE`（`stateTyE_init_eff`）を、同じ末尾を保つ保存（`steps_preserve`）で到達先へ運び、一段の定理を当てる。公開の `StateTy`（末尾の効果を存在量化する）を通さない（RV-L10「BA のもとで残る危険」(a)）。
- 構成要素は L30.4 と同じ固定した定義である: 観測は事象の観測の欄そのもの（事象の種類によらない形では `Event.obs`）、許可は `Builtins.Allows`（`Eff.Allows B.effKind`）、`TA` は `Builtins.TargetAgreement`。どれも言明の引数にしない。結論は事象の操作の名前 l を通す。
- 信頼条件の前提は `CoreAssumptions` と `TargetAgreement` だけである。ほかの前提はプログラムの条件（`P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B`。`effect_soundness` と同じ）と、初期の計算の型付けとエフェクト変数を含まない条件（`effect_soundness` の ε を空に限らない形）である。対象健全性そのもの・所属の保存・外部応答の一致を仮定へ移していない。
- L00.08b の言明の案 `ReleaseReachableTargetStatement`（`reviews/L00.08b-target-statements.md`）と比べると、案の `B.Assumptions P → TA B P` を `CoreAssumptions`・`TargetAgreement` に、案の `∃ k, effKind l = some k ∧ allows ε l k t` を `B.Allows ε l t`（κ を `effKind` で読む許可。種類の一致を定義の中に含む）に置き換えた形である。

同じファイルに、事象の種類によらない形 `reachable_target_sound_event`（`∀ t ∈ ev.obs, ∃ b ws o obs e l, ev = .io b ws o obs ∧ B.sig b = some e ∧ e.opEff = some l ∧ B.Allows ε l t`）と、全体の信頼条件のもとでの形 `reachable_target_sound_of_assumptions`（`hA.core`・`hA.target` を渡すだけ）を置いた。

## 置いた定理

| ファイル | 名前 | 内容 |
|---|---|---|
| `Release/Theorems.lean`（import に `Release.Lemmas.TargetStep` を加えた） | `reachable_target_sound`・`reachable_target_sound_event`・`reachable_target_sound_of_assumptions` | 上の言明 |
| `Release/TargetReachExamples.lean`（新規、既定の import に加えた） | 下の「例と反例」の表 | 本番の定義の例と反例 |

## 例と反例

表は L20.7 の実例 `ModelTargets.Examples.B`、プログラムは `progOf dataTree`（`P3`）。`CoreAssumptions`・`TargetAgreement` は `progOf_assumptions` から得た。どの例も一般の定理 `reachable_target_sound` を当てて示し、状態の型付けを手で組み立てていない。

| 区分 | 名前 | 内容 |
|---|---|---|
| 非 Top の IO | `ioCall_reach_target_sound` | `File.writeTextIn[;;/data/**](checked(/data/a.txt), "x")` を初期の効果 `{File.Write[/data/**]}` で型付けると、初期状態の E-IO の事象の観測 `/data/a.txt` は初期の効果の `File.Write` の原子が許す |
| 同上 | `ioCall_no_passwd` | 同じ初期状態から到達したどの `File.writeTextIn` の事象も `/etc/passwd` を観測しない（任意の到達先・任意の事象についての言明） |
| 別の対象の節（例 3a） | `handleLog_reach_target_sound` | 保護本体が `/data/**` へ書き、節が `/logs/**` へ書く `handleLog` を初期の効果 `{File.Write[/logs/**]}` で型付けると、E-Handle・E-OpPrim で到達した節の IO の事象の観測 `/logs/l.txt` は初期の効果が許す（L30.4 の `sIO_target_sound` を到達先の定理から得た） |
| 同上 | `handleLog_never_observes_data` | `handleLog` の初期状態から到達したどの `File.writeTextIn` の事象も、保護本体の対象 `/data/a.txt` を観測しない |
| 誤った節の規則: 本番の規則が許す添字 | `clauseIxOk_bodyData_iff`・`etc_not_clauseIxOk` | 保護本体の効果 `{File.Write[/data/**]}` のもとで、`File.writeTextIn` の節に本番の規則 `ClauseIxOk` が許す添字は Top と規則の値 `/data/**` だけであり、`/etc/**` を許さない |
| 同上: 誤った規則 | `WrongHandleTyped`（定義）・`wrong_of_clauseSig` | 本番の `C_Handle` と `HasTypeClausesQ.cons` の前提のうち、節の操作の型 `ClauseSig` だけを許容を問わない `∃ S, opSigAt P B S o = some sg` に替えた、一つの節の `handle` の型付け（反例のためのモデル）。保護本体の型付け、`εm ⊆ ε ∪ handled(H)`、節の本体を出力の上限 ε で型付けることは本番と同じである。本番の `ClauseSig` は誤った規則の前提を満たす（`wrong_of_clauseSig`。誤った規則は条件を外しただけ） |
| 同上: 誤った規則が認める型付け | `wrong_rule_admits` | 節 `writeTextIn(p, s) k ⇒ File.writeTextIn[;;/etc/**](p, s)`（捕捉した引数を `/etc/**` の書き込みへ渡す）を添字 `/etc/**` で型付け、`handleEtc` を初期の効果 `{File.Write[/etc/**]}` で型付ける |
| 同上: 実行 | `reach_etc`・`sEtc_step` | `handleEtc` の初期状態から E-Handle・E-OpPrim で節の IO の状態へ進み（遷移は型付けによらない）、E-IO の事象の観測は `/data/a.txt` である（表の実装は引数の対象を報告する） |
| 同上: 到達先の対象健全性が破れる | `etcBound_not_allows_data`・`wrong_rule_unsound` | `{File.Write[/etc/**]}` は `/data/a.txt` を許さない。誤った規則の型付け・到達・事象・不許可の四つを一つにまとめた |
| 同上: 本番の型付けは認めない | `handleEtc_typed_allows`・`handleEtc_rejected` | 本番の型付けで `handleEtc` をどの効果 ε で型付けても、ε は `File.Write` の名前で `/data/a.txt` を許す（到達先の定理から）。よって `{File.Write[/etc/**]}` では型付かない |

誤った節の規則の反例は、依頼の二つの読み方の両方を置いた。添字を規則の値でも Top でもないものにすると本番の規則は許さない（`etc_not_clauseIxOk`）。許容を外した規則で型付けを許すと、到達先の対象健全性が破れる（`wrong_rule_unsound`）。SK §4 の `WrongHandleRule`（節の効果を出力の上限に含めない規則）の形は、本番の `HasTypeClausesQ.cons` が節の本体を出力の上限 ε で型付けるので、本番の定義の上では作れない。L30.4 の `StateTyE.clause_allows` がその形の健全性（節の効果が許す対象を末尾の効果が許すこと）を示している。本枝の `WrongHandleTyped` もこの前提を保ち、添字の許容だけを外した。

## Http について言うこと・言わないこと

plan-l10-l50「RV-L20 の後の注」(1) により、`Http.RequestIn` の値は L40.3b で入れる。到達先の定理は表の項目を名指ししない一般の定理なので、次のとおりである。

- 言うこと: `CoreAssumptions` と `TargetAgreement` を満たす表が `Http.sendIn`（単一の対象の形 `single endpoint 0`、効果 `Http.Connect[rvar 0]`）を持つなら、初期の効果 ε で型付いた閉じたプログラムの初期状態から到達した `Http.sendIn` の E-IO・E-IOErr の事象の観測の endpoint は、ε の `Http.Connect` の原子が許す。旧 Top の形の HTTP の項目なら、観測（リダイレクトの追従先を含む）は宣言した種類（endpoint）の対象であり、ε の名前だけの（Top の）`Http.Connect` の原子が許す。
- 言わないこと: (1) 今の値 `Val.checked t` は endpoint の対象しか持たないので、検査した要求の中身（メソッド・パス・ヘッダ・本体）と送った要求の一致、`Http.checkRequestIn` が検査した要求が `Http.sendIn` に渡ることについては何も言わない。(2) 実例の表 `ModelTargets.Examples.B` は Http の項目を持たないので、Http の場合を例で確かめていない。(3) L40.3b で値の形と葉の規則を変えると `StateTyE` の内容が変わり、到達先の定理も証明し直しが要る。証明は一段の定理と保存の合成なので、一段の定理と保存が追随すれば本定理の証明は変わらない見込みである（確かめていない）。

## 設計書の変更

| ファイル | 変更 |
|---|---|
| `docs/design/07-quality/07-04-formal-semantics.md` | 「証明する性質」の一段の対象健全性の段落の「初期状態から到達した状態についての言明は、まだ置いていない」を、後述の到達先の対象健全性を指す文に直した。その次に、到達先の対象健全性の【決定】の段落を加えた（言明、前提、証明の合成、`StateTy` を通さないこと、例と反例、Http は一段と同じこと、理由）。「形式化で仮定するもの」の `io_target` の箇条の末尾を「一段の対象健全性と到達先の対象健全性を示した」に直した。「01-12 との対応」に行「初回リリース版の拡張: 到達先の対象健全性」を加えた（Rust は未接続） |
| `docs/design/01-spec/01-12-core-calculus.md` | 「実行の規則」の観測の箇条（L30.4 が加えたもの）に、到達した状態の事象の観測も初期のエフェクトの同じ名前の原子が許すこと（到達先の対象健全性）の一文を加えた |

見出しは足していない。01-12 から 07-04 へのリンクは既存の見出し「証明する性質」を指す。

## L30 の段末の確認

plan-l10-l50「義務の一覧と枝の対応表」の L30 の行と、L30 の段末の確認（plan の L30 の行）の4項目を、L30.1〜L30.5 の記録と本枝の定理で確かめた。

| 義務 | 出どころ | 閉じた枝 | 閉じた形 |
|---|---|---|---|
| 節の範囲 S を選ぶ規則 | 判断 11、L00.06b の申し送り 2、RV-PL10 軽11 | L30.1 | `opSigAt`・`Eff.ClauseRangeIs`・`Eff.clauseRange`・`ClauseIxOk`・`ClauseSig`。`HasTypeClausesQ` が保護本体の効果から添字を選び、型付けは規則の値か Top を許す。本枝の `clauseIxOk_bodyData_iff` がそれ以外を許さないことを具体の効果で確かめた |
| 継続の型と R ⊆ S | L00.06b の限界 4、L00.03 の申し送り 4 | L30.1（前倒し）・L30.3（L30.2 の点検） | K-Handle の穴の効果を保護本体の効果 εb にした。`pres_op_common` の S ≠ Top の場合は、穴の効果の名前 L の原子が `L[S]` だけであることから構造の等号で閉じ、被覆の健全性を使う形は要らなかった |
| `handled` が範囲によらず名前の原子を除く（点検と例） | RV-PL10 中3 (d) | L10.2（定義）・L30.3 | `mem_handled_of_nameTop`、例 3a の `mem_handled_write` |
| 名前全体の除去と節の IO（例 3a・3b・3c）、利用者の操作の不変 | L00.07、UB10 | L30.3 | `HandlerTargetExamples`（3a の実行、3b の転送、3c の利用者の操作。`V_Op`・`E_Op` は B0 から字面が同じ） |
| 継続を通した対象の伝播 | L00.04 の申し送り 3 | L30.3 | `TargetPropagation` の12補題（処理されない操作・捕捉の枠・解放の枠） |
| 対象健全性の言明が名前と種類を保ち、構成要素を引数にしない | RV-L00 中1・中2、問16、RV-PL10 中6 | L30.4・L30.5 | 一段の `step_target_sound` と到達先の `reachable_target_sound` は、`obs`・`allows`・`TA` を固定した定義で述べ、事象の操作の名前 l を通す。名前の反例 `Eff.allows_union_other_name`・`no_write_event_passwd`（L30.4）、本枝の `ioCall_no_passwd` |
| 節の効果が外側の上限に含まれる（`E_OpPrim`） | L00.04、SK §4 | L30.4 | `StateTyE.clause_allows`・`StateTyE.opPrim_clause_allows` |
| 初期の同じ ε、到達先の言明 | L00.04 | L30.5 | `reachable_target_sound`（`stateTyE_init_eff`・`steps_preserve`・`step_target_sound`。`StateTy` を通さない） |

段末の確認の4項目:

| 項目 | 枝 | 根拠 |
|---|---|---|
| 初期の同じ ε | L30.5 | `reachable_target_sound` の結論は初期の計算の型付けの ε を読む |
| 非 Top の IO | L20.5・L30.4・L30.5 | 閉じた非 Top の値が組み込みへ渡る `E_Prim`・`E_IO`・`E_OpPrim`（L20.5）、`ioState_target_sound`（L30.4）、`ioCall_reach_target_sound`・`ioCall_no_passwd`（本枝） |
| 別の対象の節 | L30.3・L30.5 | 例 3a の `sIO_obs_allowed`・`logsBound_not_allows_data`（L30.3）、`handleLog_reach_target_sound`・`handleLog_never_observes_data`（本枝） |
| 誤った節の規則の反例 | L30.5 | `etc_not_clauseIxOk`・`wrong_rule_unsound`・`handleEtc_rejected`（本枝） |

L30 の範囲で残る義務はない。L30 の後に残るものは「L40・L50 への申し送り」に書いた。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 最大常駐量 | 記録 |
|---|---|---|---|---|---|
| 主定理と例の依存のモジュールのビルド（例のファイルの単一検査に要る olean） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <ログ> Benitoite.Release.Theorems Benitoite.Release.TargetStepExamples` | 0（86 ジョブ、8 モジュールを作り直した） | 5.09 秒 | 849821696 バイト（810.5 MiB、0.79 GiB） | [builds/build-01-theorems.log](builds/build-01-theorems.log) |
| 全体のビルド（Lean の変更の後） | 同上（引数なし） | 0（454 ジョブ、`declaration uses 'sorry'` なし。警告 90 件は L30.4 の全体のビルドと同じで、新しいファイルの警告はない） | 6.38 秒 | 1533165568 バイト（1462.1 MiB、1.43 GiB） | [builds/build-02-full.log](builds/build-02-full.log)・[builds/build-02-full-time.txt](builds/build-02-full-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l30.5>/axioms.lean`（31 件の `#print axioms`） | 0 | 0.60 秒 | 1514029056 バイト（1443.9 MiB、1.41 GiB） | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base fb85cf48947aad191e98b4414577452b5181e80b`（先に同じ指定で `--dry-run`、終了 0） | 0 | 9.05 秒 | 1384873984 バイト（1320.7 MiB、1.29 GiB） | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt)・[work-check-dry-run.log](work-check-dry-run.log) |
| 作業末の全体のビルド | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <ログ>` | 0（454 ジョブ、sorry なし） | 0.16 秒（組み立て済み） | 69517312 バイト（66.3 MiB、0.06 GiB） | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt) |

- dry-run の選択: `spec_tally`・`spec_examples`（01-12 の変更）、`formal_build`（`formal/Benitoite.lean` ほか）。計画の見込みどおりで、三つとも通った（`spec_examples` 7 件成功）。
- 途中の単一ファイルの検査は `lake env lean -M 12288 <ファイル>` で 3 回（`Theorems.lean` 1 回、`TargetReachExamples.lean` 2 回。各 1 秒未満。計時していない）。
- 最大常駐量は macOS の `/usr/bin/time -l` の値（バイト）。一つのコマンドの子のうち最大のもので、並行しない。作業末のビルドは組み立て済みで小さい。
- 公理: 31 件のうち、`propext`・`Classical.choice`・`Quot.sound` の三つ全てに依存するもの 29 件、`propext`・`Quot.sound` だけのもの 2 件（`wrong_of_clauseSig`・`etcBound_not_allows_data`）。`sorryAx` と独自の公理はない。対象は主定理 7 件（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness`）、一段の定理 3 件（`step_target_sound` と二つの形）、到達先の定理 3 件、本枝の例と反例 18 件。`decide` は範囲の所属・名前の文字列の小さい判定だけに使った。

## 失敗と修正

いずれも単一ファイルの検査の段階で、全体のビルドの失敗はない。

1. `clauseIxOk_bodyData_iff` で、`simp` の後の等式の向きが `S = range` だった（`.symm` が不要だった）。`.symm` を外した。
2. `etcCall_inst` で、局所変数の置換 `instSubst`（引数の列を逆順に読む）が展開されず目標が残った。`simp` の補題に `instSubst` を加えた。

## ずれと申し送り

計画からのずれ:

1. ファイル: 到達先の定理は計画どおり `Release/Theorems.lean` に置いた。そのため `Theorems.lean` が `Release.Lemmas.TargetStep` を import するようになり、`Theorems` を import する `Model`・`Observation`・`LocalInvariant`・`Surface.Theorems` とその下流は `TargetStep` に推移的に依存する（循環はない。`TargetStep` の閉包は `Theorems`・`Model` を含まない）。例は新しいモジュール `Release/TargetReachExamples.lean` に置いた（計画に候補の名前がない）。
2. 前提の `P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B` はプログラムの条件で、`effect_soundness` と同じ前提である（L30.4 の申し送り 2 と同じ読み方）。レビューで確かめてほしい。

L40・L50 への申し送り:

3. L40.3b・L40.6: Http の項目は上の「Http について言うこと・言わないこと」のとおりである。L40.3b の後に、一段・到達先の定理の追随と、Http の項目を持つ実例の表での例（`Http.sendIn` の到達先の観測）が要る。
4. L40.5: 表層の節は Top の添字で型付けるので、例 3a・本枝の `handleLog` の節の添字 `/data/**` を表層から作るのは L40.5 である。表層の節の添字の規則が判断 11 の規則の値か Top だけを作ることの確かめに、`clauseIxOk_bodyData_iff` の形が使える。
5. L40.6: 表層の対象健全性（Scope の接続定理と合わせる場合）は、`reachable_target_sound` を脱糖の型の保存（`desugar_typed`）の結論に当てる形になる見込みである。初期の ε は脱糖したコアの計算の効果であり、表層の注釈の効果との関係（L40.5 の「型検査器の R と脱糖・コアの R の一致」）が要る。
6. L50.3: `TargetReachExamples` は `ModelTargets.Examples`・`HandlerTargetExamples`・`TargetStepExamples` の表と状態に依存する。実例の整理の対象に含める。
7. L50.4: 誤った規則のモデル `WrongHandleTyped` は反例のための定義で、型付けの規則ではない。全定義のレビューで、本番の `C_Handle`・`HasTypeClausesQ.cons` の前提と `ClauseSig` だけが違うことを確かめてほしい。
8. 到達先の定理は事象を伴う遷移だけを扱う。処理されない利用者の操作（`UnhandledOp`）は対象を持たず、エフェクトの健全性の `no_unhandledOp` が扱う（L30.4 の申し送り 7 と同じ）。

## 時間

| 区分 | 時刻（2026-10-28） | 所要 |
|---|---|---|
| 文書と定義を読む | 05:47 頃〜05:51 | 約 4 分 |
| 到達先の定理 | 05:51〜05:52 | 約 1 分 |
| 例と反例 | 05:52〜05:53 | 約 2 分 |
| 設計書・ビルド・公理・work | 05:53〜05:56 | 約 3 分 |
| 本書 | 05:56〜05:59 | 約 3 分 |

能動時間は約 13 分（ビルドと検査の待ち約 25 秒を除く）。外側の所要は 05:47 頃〜05:59 の約 12〜13 分（開始の時刻は概算）。見込み（0.25〜2 時間）の下端を下回り、上端の2倍（4 時間）には近づいていない。排他の道具の待ちは 3 回で 0・1・0 秒。設計者の回答待ちなし。
