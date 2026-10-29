# L40.5 の結果: 脱糖と同じ範囲

2026-10-28。plan-l10-l50「L40」の表の L40.5 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l40.5`）で行った。担当は Claude のサブエージェントである。git の状態は変えていない（コミットは取りまとめが行う）。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.5（脱糖と同じ範囲） |
| B_WORK | `85cdfaf67904cf08d47e17bf68330cb38fce0c45`（L40.3b の取り込みの後の本線） |
| 閉じた範囲 | 依頼の 1〜8。組み込みの呼び出しの範囲の列の脱糖と規則の `index`（本番版）、受理を被覆のままにする決定、表層の節の添字（`HasClausesQ` に保護本体の効果を渡し、規則の値を選ぶ）、計算できる規則と Release の規則の値の一致、検査器が規則の値を選ぶこと、例 3a、交換の `throw`、P5 の補題、01-12・07-04 |
| 未完 | なし（計画の行の範囲で）。接続定理は L40.6、交換形式への範囲の読み書きは L50.1 |
| 適用した前提の変更の行 | 停止の表の「表層の側の前提（`desugar_typed` の `hsig`、`p.WellTyped` の内容）」の L40.5 の分（`p.WellTyped` の節の型付け）と、「節の添字 S と継続の型」の行（表層の節の添字）。`hsig` は変えていない |
| 停止条件 | 該当なし（下の「停止条件の点検」）。`Scope/` の採用定義、`Release/`、`Interval/` は変えていない |

## 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| 新 `Surface.clauseIx B e o`（`Surface/Typing.lean`） | 表層の型検査器が節に与える添字。組み込みの操作でエフェクトの名前 l を持つなら `e.clauseRange l`（Release の規則の値）、それ以外は Top |
| `Surface.HasClausesQ`（`Surface/Typing.lean`） | 添字に保護本体の効果 `εb : Eff` を加えた。`cons` の前提 `opSig D.patternProgram B o = some sg` を `opSigAt D.patternProgram B (clauseIx B εb o) o = some sg` に替えた。`E_Handle` は本体のエフェクト `εbody` を渡す |
| 新 `Surface/ClauseIxRule.lean` | 計算できる規則 `clauseRangeIn atoms e l`（候補の原子の一覧の上で判断 11 の規則を計算）、検査器の添字 `clauseIxIn`、検査器が節の操作の型を引く関数 `clauseOpSigIn`（表を一度だけ引き、範囲の変数のない項目では規則を計算しない） |
| 検査器 `checkClausesR`・`inferClauseTypesR`・`checkClausesQ`・`inferClauseTypesQ`・`checkClauses`・`inferClauseTypes`（`Surface/Check.lean`） | 引数 `εp`（保護本体の効果）を加え、節の操作の型を `opSig` でなく `clauseOpSigIn q.D.patternProgram q.B q.atoms εp o` で引く。`handleE` の検査は本体の効果 `εbody` を渡す |
| `Exchange.fromEff`（`Exchange/Convert.lean`） | 省略可能な候補 `univ`（既定は一覧の原子の像）を加え、候補の中に一覧にない原子を効果が持てば `throw` する。判定は新しい全域の関数 `Exchange.unlistedAtom?` |
| `Exchange.fromVal` の `.prim` の腕（同） | 範囲の列が空でなければ `throw`（"primitive range instantiation is not in this exchange version"） |

構成子の引数・量化の数だけを追随したファイル: `Surface/Lemmas/CallHead.lean`（motive の引数の数）、`Surface/Lemmas/Scoped.lean`・`BuilderCapture.lean`・`BuilderNoCapture.lean`（`HasClausesQ` の添字）、`Surface/CheckComputeAtoms.lean`・`CheckComputeCases.lean`・`CheckComputeControl.lean`・`CheckComputeSound.lean`・`CheckInduction.lean`・`CheckSound.lean`・`CheckSoundControl.lean`・`CheckExamples.lean`（検査器の引数 `εp`）。`Release/` のファイルは一つも変えていない（依頼の「この変更で直す必要がある `Release/` のファイル」は 0 件）。`Benitoite.lean` の既定の import に新しい三つのモジュールを加えた。

## 置いた定理

| ファイル（名前空間） | 定理 |
|---|---|
| 新 `Surface/ClauseIxRule.lean`（`Benitoite.Surface`、9件） | `clauseRangeIn_eq`・`clauseRangeIn_eq_of_atomsIn`（候補が効果の原子を含めば計算した値は `Eff.clauseRange`）、`clauseIx_prim`、`clauseIx_ok`（表層の添字はコアの `ClauseIxOk` が許す）、`ClauseSig.of_clauseIx`、`clauseIxIn_eq`、`opSigAt_clauseIxIn`、`clauseOpSigIn_eq_opSigAt`、`clauseOpSigIn_eq`（検査器が引く操作の型は表層の規則の添字の操作の型） |
| 新 `Surface/DesugarRange.lean`（`Benitoite.Surface`、9件） | `desugar_checkRule_index`（`checkRule_index_agrees` の本番版）、`desugar_checkDelta_mem`、`HasClausesQ.cons_prim_rule`、`HasClausesQ.cons_sig_unique`、`handle_desugar_same_body_effect`、`clauseSig_iff_old_of_rangeFree`、`HasClausesQ.sel_congr_of_rangeFree`、`coreDef_rangeFree`、`desugar_rangeFree`（P5） |
| 新 `Surface/ClauseIxExamples.lean`（`Benitoite.Surface.ClauseIxExamples`） | 定理 `bodyData_atomsIn`・`ex3a_clauseIx`・`ex3a_sig`・`ex3a_checker`・`ex3a_not_top`・`rho_clauseIx`、`#guard` 6件 |
| `Exchange/Convert.lean`（`Benitoite.Exchange`） | `unlistedAtom?_eq_none`・`unlistedAtom?_complete` |
| 一般化した既存の補題 | `opSigAt_clean`（`Surface/Lemmas/Invariants.lean`。`opSig_clean` はその系）、`Check.opSigAt_atoms`（`Surface/CheckLemmas.lean`。`opSig_atoms` はその系） |
| 証明を変えた既存の定理 | `HasClausesQ.desugar`（節の添字を `ClauseSig.of_clauseIx` で渡す。保護本体の効果は任意でなく表層の `εb`）、`builderClauses_no_capture` と `BuilderNoCapture` の `handle` の場合、検査器の健全性の `clauses_nil_case`・`clauses_cons_case`・`handle_case`、`checkClauses_of_mutual`・`checkClauses_sound`、計算の補題の節と `handle` の場合、`clauseTypesAtoms` |

未証明の theorem と `sorry` はない。

## 依頼の各点の扱い

1. **脱糖と範囲**: 脱糖は表層の組み込みの名前の範囲の列をそのままコアの `.prim b ts es rs` へ書く（L40.4 の `desugar_primName`）。`desugar_checkRule_index` は、型検査器が受理した検査の呼び出し（`acceptCall` が ok、出現の規則が `checkRule C run`、記録の状態 st で抽象の結果の由来が o）について、脱糖の項の範囲の列が表層の列と同じであること、規則の `index` が `[o.bound.index]` であること（`checkRule_index_agrees`）、列の位置 0 の範囲が `o.bound.index` を覆うことを示す。L20.5 の Top の列の中間状態は、L40.4 が表層の列を写す形にした時点で脱糖の側では終わっており、本枝は規則の `index` との関係を示して閉じた。
2. **節の添字**: `HasClausesQ` が保護本体の効果 εb を受け取り、節の操作の型を `clauseIx B εb o` で具体化する。脱糖は同じ εb をコアの C-Handle の保護本体の効果 εM にする（`handle_desugar_same_body_effect`）ので、表層の添字は脱糖の後のコアの保護本体の効果の規則の値 `Eff.clauseRange` に等しい（`HasClausesQ.cons_prim_rule`）。計算できる規則 `clauseRangeIn` は、候補の原子の一覧が効果の原子を全て含むとき `Eff.clauseRange` と等しい（`clauseRangeIn_eq`）。
3. **交換**: 下の「交換の `throw`」。
4. **P5**: `desugar_rangeFree`。脱糖したプログラムの定義の引数・戻り値・エフェクトの型は範囲の変数を持たない（表層の P1 と `desugar_wellFormed` から）。脱糖が書く範囲の列は閉じた範囲の列（`List Range`）である。
5. **Release の包含**: 構造上のまま。`Release/` を変えていない。被覆による包含は表層の受理の判定だけにあり、型付けの規則に入れていない。
6. **完了の条件**: 下の「主定理の言明と前提の内容」と「検査」。
7. **設計書**: 下の「設計書」。
8. 下の「主定理の言明と前提の内容」。

## 受理を被覆にするか等号にするか

**被覆のまま**とした（推す案、L40.4 の申し送り 6）。理由は二つである。(1) 契約の範囲を必須の判定の結果より広く書くことを許す（利用者が `/data/**` の契約に `/**` や Top を書ける。L40.4 の受理の例）。(2) 等号でなくても健全である。コアの検査の δ は動的なパターンと具体化した範囲 S の両方への所属を確かめる（問24 の 6、`checkDelta`）ので、成功値は S そのものに属し（`desugar_checkDelta_mem`）、成功値の型の添字は脱糖の項の範囲の列で正しい。等号にすると、L40.4 の受理の判定と例（`/data/**` の既知の範囲を `/**`・Top で受理）を全て狭める変更になる。

## 節の添字の一致と「一意に選ぶ」

- 表層の型付けは、同じ保護本体の効果のもとで節の操作の型を一つにしか使わない（`HasClausesQ.cons_sig_unique`）。コアの型付けは同じ節を規則の値と Top の二つで型付けうる（`Release.ClauseIxExamples.clauseSig_data`・`clauseSig_top`）が、表層の規則は Top の操作の型を選ばない（例 `ex3a_not_top`）。
- 検査器は同じ規則を候補の原子の一覧 `q.atoms` の上で計算し（`clauseOpSigIn`）、検査器の健全性の証明で、一覧が本体の効果の原子を含むこと（検査器の不変条件 `εbody.AtomsIn q.atoms`）から表層の規則の操作の型に等しい（`clauseOpSigIn_eq`）。`handle_case` は検査器が計算した本体の効果をそのまま `E_Handle` の εbody にする（`Eff.Sub.refl`）。従って、検査器が受理した `handle` の節は、本体の効果の規則の値の添字で型付き、脱糖の後のコアでもその添字で型付く。
- 判断 11 の「R の S への被覆から S への所属を得る専用補題」は使っていない（L30.1 の構造の等号による閉じ方のまま。RV-L30 中1）。
- 表層の型付けの導出は、E_Sub・B_Sub で本体の効果を広げれば別の εb を選べる。「一意」は、型付けの導出の εb を固定した上での一意であり、検査器が計算する最小の εb の上での選び方が判断 11 の型検査器の選び方である。

## 交換の `throw` の変更

- `fromVal` の `.prim n ts es rs` は、`rs` が空でなければ誤りにする（RV-L20 軽5）。脱糖が範囲の列を書く組み込みの値は、この版の交換形式へ書き出さない。
- `fromEff` は、候補 `univ` の中の原子で、効果が持つのに書き出しの一覧にないものがあれば誤りにする（RV-L10 中2）。**限界**: Release の効果は原子の述語 `Atom → Bool` なので、効果の原子を列挙できず、候補の外の原子は調べられない。誤りにする判定は候補に相対的であり、候補が効果の原子を全て含むとき（`Eff.Support (· ∈ univ) e`）、成功すれば効果の原子は全て一覧にある（`unlistedAtom?_complete`）。既定の候補は一覧の原子の像であり、この版ではこの判定は何も拒否しない。理由: 交換の入口が書き出す効果は全て入力の JSON から読んだもの（`Eff.toRelease` は一覧の原子だけを持つ）か、一覧の上で計算した代入の結果であり、脱糖は新しい原子を作らず、範囲を項の範囲の列にだけ書く（これは `fromVal` が拒否する）。Lean の側で一覧の外の原子を作る経路（具体化した署名の原子など）を加える L50.1 は、その原子を候補 `univ` に渡す必要がある（下の申し送り）。依頼の「黙って落とさず throw」は、候補に相対的な形でしか実現できない。取りまとめの確認を求める。
- `checked`・`checkedRequest` の値は今の `unsupported` のままである。

## 主定理の言明と前提の内容

| 主定理 | 言明の字面 | 前提の内容 | 旧の像での同値 |
|---|---|---|---|
| `Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`step_target_sound`・`reachable_target_sound` | L40.3b の後と同じ（`Release/` を変えていない） | 変わらない | — |
| `Surface.desugar_typed` | 同じ | `hsig`（`PrimSig.Scoped`）は変わらない。`p.WellTyped` は、`handle` の節を、本体の効果から選んだ規則の値の添字で具体化した操作の型（`opSigAt … (clauseIx B εbody o)`）で型付ける内容に変わった。範囲の変数を持つ組み込みの操作の節では、以前（Top の添字の `opSig`）より狭まる向き（引数が `PathIn[/data/**]` になり、Top の型を期待する本体は型付かない）。結論は同じ字面で、脱糖した節はコアの `ClauseSig`（規則の値の添字。`clauseIx_ok`）で型付く | `clauseSig_iff_old_of_rangeFree`（範囲の変数のない表では節の前提が L40.4 の後の前提 `opSig … = some sg` と同値）、`HasClausesQ.sel_congr_of_rangeFree`（範囲の変数のない表では節の型付けは保護本体の効果によらない） |
| `Surface.surface_effect_soundness` | 同じ | `p.WellTyped` の内容は上と同じ変化。`hb` は `CoreAssumptions` のまま | 同上 |

旧の表層の型付けの相互帰納を別に並べた形式の同値の定理は置いていない（L40.4・RV-L20 軽9 と同じ扱い）。旧の像では節の前提が同値で、ほかの規則は変えていないので、導出は前提の付け替えで対応する。

検査器の健全性（`checkClauses_sound`・`checkClauses_of_mutual`）は、引数 εb と前提 `εb.AtomsIn q.atoms` が増え、結論の `HasClauses` が εb を持つ。主定理ではないが、契約の内容の変更として記録する。`checkExpr_sound`・`CheckTables.checkProgram_sound` の言明は変わらない。

## 確かめた例

`Surface/ClauseIxExamples.lean`（L20.7 の `TargetTable` の表、保護本体の効果 `{File.Write["/data/**"]}`）。

- 例 3a: 表層の規則の添字が `/data/**`（`ex3a_clauseIx`）、節の操作の型の引数が `[PathIn["/data/**"], String]`（`ex3a_sig`）、検査器の計算も同じ（`ex3a_checker`、`#guard` の `clauseIxIn … = /data/**`）、Top の操作の型を選ばない（`ex3a_not_top`）。
- 計算できる規則（`#guard`）: 一原子なら範囲、二つの範囲・行の変数・同名の Top・同名なしなら Top。行の変数を持つ効果では表層の規則も Top（`rho_clauseIx`）。
- 既存の Log の例（`LogExamples.program_checked`、範囲の変数のない表の `handle` を検査器で `rfl` で確かめる例）は、上限を変えずに通る（下の「失敗と修正」）。

## 設計書

| 文書 | 変更 |
|---|---|
| 01-12「型の情報を付けた表層の構文と型付け」 | `handle` の箇条に、節を本体のエフェクトから選んだ規則の値の添字で型付ける【決定】と理由、一意性・検査器の計算・旧の像の補題を加えた |
| 01-12「ハンドラ」 | 「脱糖が作る節は Top の添字で型付ける」を、規則の値の添字で型付け、コアの保護本体の効果が同じであることに直した。Release の型付けが広いことの段落に、表層と検査器は規則の値だけを選ぶことを加えた（RV-L30 中2） |
| 01-12「Scope の必須の判定の受理と拒否の理由」（Scope の局所解析の節） | 受理を被覆にする【決定】と理由、`desugar_checkRule_index`・`desugar_checkDelta_mem` を加えた |
| 07-04「証明する性質」 | 節の添字の段落の「性質 1 の脱糖は節を Top の添字で型付ける」を、性質 1 の前提の表層の型付けの内容の変化と旧の像の補題に直した |
| 07-04「01-12 との対応」 | 新しい行「表層の節の添字と脱糖の範囲」（Rust は未接続）を加え、ハンドラの行の「脱糖が作る節は Top の添字で型付ける」を直した |

見出しは加えていない・変えていない。` ```text ` のブロックは加えていない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 最初の全体のビルド（基準。L40.3b の分を作り直した） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0 | 175.40 秒（排他の待ち 0 秒） | [lake-build-first.log](lake-build-first.log) |
| 途中の全体のビルド 10回 | 同上 | 1 が 8回、0 が 2回（下の「失敗と修正」） | 0.6〜41 秒 | 一時ファイル（保存していない） |
| モジュールのビルド（約6回。単一ファイルの検査の依存を作るため） | 同上に対象のモジュールを付ける | 1 が 1回（試しの変更の確かめ）、ほかは 0 | 各数〜十数秒 | 一時ファイル |
| 局所の単一ファイル（約15回） | `cd <wt>/formal && lake env lean -M 12288 <相対パス>` | 途中は 1、最後は全て 0 | 各 1〜16 秒 | 本書 |
| 作業末の全体のビルド | 同上（排他の道具） | 0。`Build completed successfully (499 jobs)`、`sorry` の出現 0、警告 89件（基準と同数。新しいファイルの警告なし） | 28.30 秒 | [lake-build.log](lake-build.log) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l40.5>/axioms.lean`（`#print axioms` 45件） | 0 | 0.62 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 85cdfaf67904cf08d47e17bf68330cb38fce0c45 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean` の変更）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 85cdfaf67904cf08d47e17bf68330cb38fce0c45` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.59 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |

公理: 45件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する。`sorryAx` と独自の公理はない。対象は新しい定理の全て（28件）、証明を変えた既存の定理と検査器の健全性・Log の例（8件）、主定理 9件（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`step_target_sound`・`reachable_target_sound`・`desugar_typed`・`surface_effect_soundness`）である。

work の `formal_build` は `scripts/check.sh` の中の `lake build` で、排他の道具を通らない。作業末の全体のビルドの直後でビルド済みであり、組み立ては起きていない。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。全体のビルドの値は並行するジョブの中で最大のプロセスの値である。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 最初の全体のビルド | 3560833024 | 3395.9 | 3.32 |
| 途中の全体のビルドの最大（Log の例が重くなった回） | 5205508096 | 4964.4 | 4.85 |
| Log の例の単一ファイルの試し（下の「失敗と修正」の最大） | 6023200768 | 5744.2 | 5.61 |
| 作業末の全体のビルド | 3571515392 | 3406.1 | 3.33 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1383481344 | 1319.4 | 1.29 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1522008064 | 1451.5 | 1.42 |

本作業で観測した最大は 5.61 GiB（途中の試しの単一ファイル）である。作業末の状態の最大は 3.33 GiB で、基準（3.32 GiB）と同じ程度である。`-M 12288` は変えていない。

## 失敗と修正

- 途中の全体のビルドの1〜5回目が終了1: 帰納法の motive の引数の数（`CallHead`）、計算の補題・健全性の motive の量化（`CheckComputeAtoms`・`CheckInduction`）、`BuilderNoCapture` の字下げ（注を消す置換の誤り）、`CheckSoundControl` の名前の衝突（節の本体の効果 `εb` と保護本体の効果）。順に直した。
- 6回目で `CheckSoundControl` の `change` が失敗し、**検査器の不具合**を見つけた。`checkClausesR` の引数の名前を `εb` にしたため、節の本体の効果の `let εb ← …` が引数を隠し、続く節の再帰の呼び出しが保護本体の効果でなく前の節の本体の効果を渡していた。引数の名前を `εp` に替えて直した（証明が受け付けなかったので、誤った検査器は取り込まれていない）。
- 6〜8回目で `LogExamples.program_checked`（検査器を `rfl` で評価する既存の例）が `maxHeartbeats 800000` を超えた。単一ファイルで測ると、上限を 1200000 に上げれば通るが、最大常駐量が約 3.4 GiB から 5.6 GiB に増えた。原因を絞るため、`Log` の例の写しを旧の操作の型の引き方で走らせて比べ（3.4 GiB、8.7 秒）、節の操作の型の項に保護本体の効果の計算（`clauseRangeIn`）が残ることが原因と分かった（範囲の変数のない項目で添字を使わなくても、`if` を列の中に置く形や個数で分ける列の形では重いままだった）。`clauseOpSigIn` を、範囲の変数の個数で先に分け、個数 0 では規則の計算を項に残さない形にして、上限を変えずに基準と同じ所要（3.4 GiB、8.8 秒）に戻した。試しの途中で一時的に `sorry` を置いたビルドが1回あるが、元に戻し、作業末のビルドに `sorry` はない。上限 `maxHeartbeats` は元の値（800000）のままである。
- 作業末の前のビルドで `if_false` の非推奨の警告が出たので `ite_false` に替えた。

## ずれと申し送り

### 計画からのずれ

1. **検査器（`Surface/Check*.lean`）を変えた**。計画の行の対象ファイルは `Surface/Desugar.lean`・`Surface/Lemmas/*`・`Surface/Theorems.lean` だが、依頼の 2（判断 11 の「一意に選ぶ」を型検査器の性質として示す）と表層の型付けの変更を両立させるには、検査器の節の操作の型の引き方を同じ規則にする必要があった（そうしないと検査器の健全性が範囲の変数を持つ表で成り立たない）。依頼の編集してよい範囲（`Benitoite/Surface/`）の中である。
2. **表層の型付けは規則の値だけを許す**（コアの `ClauseIxOk` のように Top を許さない）。表層の型付けは型の代入で保存を求められない（`desugar_typed` は表層の導出を直接コアへ移す）ので、L30.1 が Top を許した理由が表層にはない。範囲の変数を持つ表では `p.WellTyped` が狭まる向きの変更であり、停止の表の「表層の側の前提」の行に含めた。取りまとめの確認を求める。
3. **`fromEff` の `throw` は候補に相対的**（上の「交換の `throw` の変更」）。既定の候補ではこの版で何も拒否しない。

### L40.6 への申し送り

4. 接続定理で、脱糖したコアの `.prim` の範囲の列が型検査器の受理した列であることは `desugar_checkRule_index` の第1・第3の成分、コアの δ からの所属は `desugar_checkDelta_mem` で得る。節の添字については、`handle_desugar_same_body_effect` と `HasClausesQ.cons_prim_rule` から、コアの保護本体の効果の規則の値で節が型付く。
5. 表層の型付けは本体の効果を E_Sub・B_Sub で広げて別の添字を選べる。接続定理で「検査器が選んだ添字」を言うときは、検査器の健全性（`handle_case` が本体の効果を広げない）を通す必要がある。

### L50 への申し送り

6. L50.1: 交換形式に範囲と範囲の列を加えるとき、`fromVal` の `.prim` の範囲の列の `throw` を書き出しに置き換え、`fromEff` の候補 `univ` に、具体化した範囲の原子と署名の表の原子（Lean の側で一覧の外に作る原子）を渡す。候補が効果の原子を含むことは呼び出し側の義務であり、`unlistedAtom?_complete` の前提である。
7. L50.2・K10: 検査器の節の操作の型は `clauseOpSigIn` で引く。Rust の型検査器の節の添字の選び方（判断 11）を、候補の原子の一覧の上の `clauseRangeIn` と比べる入力（例 3a と、二つの範囲・行の変数・同名の Top の場合）が要る。

### R20 への申し送り

8. Rust の型検査器は、節を検査する前の保護本体の効果（推論した最小の効果）から添字を選ぶ。表層の型付けの導出で本体の効果を広げた場合の添字は検査器の選び方ではない（上の 5）。

## 停止条件の点検

- `Release/` の主定理の言明と前提は変えていない。表層の二つの主定理の字面は変えず、前提の内容の変更は `p.WellTyped` の節の型付けだけであり、停止の表の「表層の側の前提」と「節の添字 S と継続の型」の行に含まれる。`hsig` の内容、`Builtins.Assumptions` の欄、公理は変えていない。結論の弱化はない。
- 採用定義（`Scope/` の五つのモジュールと `Interval/BindingScope.lean`）は変えていない。Release の C-Sub と `Eff.Sub` は構造上の包含のままであり、被覆による包含を Release に入れる必要は出なかった（RV-L30 中1）。
- 検査器の健全性の言明（`checkClauses_sound`・`checkClauses_of_mutual`）に引数と前提が増えた。主定理ではなく、L40.5 で変えた検査器の契約の内容の変更として上に記録した。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 07:13 ごろ（JST、依頼文を読み始めた時刻） |
| 終了 | 07:57 ごろ（本書の作成まで） |
| 外側の所要 | 約44分 |
| 能動時間 | 約38分（文書と既存の定義を読む約12分、設計約5分、表層の型付けと脱糖約5分、検査器と健全性約8分、Log の例の所要の調べと直し約5分、交換・新しい補題と例約5分、設計書と本書約5分。ビルドの待ちを除く） |
| ビルドの回数と時間 | 全体のビルド 12回（基準 1、途中 10、作業末 1）。最長は基準の 175.40 秒。モジュールのビルド約6回、局所の単一ファイル約15回 |
| 検査 | work 1回 9.59 秒（dry-run 数秒）、公理の確かめ 1回 0.62 秒 |
| 待ち | 排他の道具の待ちは 0 秒。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.5〜3時間の範囲内。上端の2倍（6時間）を超えていない |
