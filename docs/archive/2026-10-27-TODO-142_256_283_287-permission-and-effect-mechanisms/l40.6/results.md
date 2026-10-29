# L40.6 の結果: Scope の接続定理

2026-10-28。plan-l10-l50「L40」の表の L40.6 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l40.6`）で行った。担当は Claude のサブエージェントである。git の状態は変えていない（コミットは取りまとめが行う）。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.6（Scope の接続定理） |
| B_WORK | `e9d6624b32fd2fc7395ed5782b0bf33bc785a300`（L40.5 の取り込みの後の本線） |
| 閉じた範囲 | 依頼の 1〜7。接続定理（検査の成功値・射影と拡大が指す値・同じ R でのコアの実行）、検査済みの要求の成功値の対応（`Val.target?` の形）と `Http.checkRequestIn` への適用、表層の対象健全性、旧 Scope の IP の成否と `PathIn[R]`・`RequestIn[R]` との対応、未知と予算の停止、警告の解析との分離、01-12・07-04、L40 の段末の確認 |
| 未完 | なし（計画の行の範囲で）。文の始まりの番号とその右辺の出現の番号の一致は前提に取り、一般の補題にしていない（「ずれと申し送り」2） |
| 適用した前提の変更の行 | なし。主定理の前提と結論の内容を変えていない（`Release/`・`Checked/`・`Scope/` は一つも変えていない） |
| 停止条件 | 該当なし（下の「停止条件の点検」） |

## 接続定理と表層の対象健全性の言明と前提

### 接続定理（`Surface/ScopeSound.lean`、名前空間 `Benitoite.Surface.ScopeSound`）

共通の前提は、表の健全性 `hT : TableSound (models ok P) T`、本体の受理 `hacc : acceptBody ok T L key scope body = .ok ()`、表層の具体の評価が番号 k の文の始まりへ到達すること `hreach : ReachBlock T key env body k env'`、同じ呼び出しの式が出現の一覧の番号 k にあること `hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body` である。区間解析の結果を含まない。記録の番号の重複を仮定しない（`analyzeBody_sound` が与える一つの記録に、全称の形の `acceptBody_sound` を当てる）。

- `scope_check_connection`（検査の成功値）: 追加の前提は、右辺の評価 `RhsEval T k env' (.call …) (some v)`、規則 `T.ruleAt k = some (checkRule C run)`、`okPayload ok v = some w`。結論は、記録の状態 st・契約の順の引数 xs・値の列 vs があり、規則の実行が vs で v を返し、`∃ t, w.target? = some t ∧ t.kind = C.kind ∧ R.Mem t ∧ ∀ S, rs[0]? = some S → S.Covers R ∧ S.Mem t`（R は `(C.bound (xs.map (absArg T st))).index`、続く `Ok` の腕の成功値の事実の添字）。δ の契約は前提にしない（R への所属は規則の健全性、S への所属は被覆の健全性から得る）。
- `scope_local_connection`（射影・拡大が指す値）: 追加の前提は、契約の順の引数が `[.loc i]`、規則の `index` が引数の `argIndex`（`projectRule_index`・`widenRule_index`）、`env'[i]? = some (some v)`、`rs[0]? = some S`。結論は、記録の状態 st について `S.Covers (st.requiredIndex i)`、R が Top なら S は Top、R が Top でなければ `∃ t, v.target? = some t ∧ R.Mem t ∧ S.Mem t`。
- `scope_local_typed`: 上に加えて S ≠ Top、`B.valKind o = some kd`、`S.kind? = some kd`、検査済みの要求の値なら保持する要求の型が `valContent o` に合うこと、から `HasTypeVQ … v (.opaque o (.fixed S))`。`TargetTable` の項目のコアの入力の型は `pathInValue_inst_params`・`requestInValue_inst_params`・`widenRequestIn_inst_params`（と L40.4 の `widenPathIn_inst_params`）。
- 同じ R（小さいモデルと本番の接続）: `evalScope_core_step`（規則の実行が本番の δ `deltaRun B b ts es` なら、`EvalScope T k rs vs v` から、同じ rs のコアの `.prim b ts es rs` が E-Prim で v へ進む）、`evalScope_of_delta`（逆向き）、`scope_check_core`（引数の評価とコアの δ の値から、脱糖の項・E-Prim の遷移・成功値の R と S への所属を同時に結論する）。
- 本番の実例の表: `modelTargets_contract`（L20.7 の `Scope.checkPathIn` の δ が `pathCheck` の契約を満たす）、`modelHttp_contract`（L40.3b の `Http.checkRequestIn` の δ が `requestCheck` の契約を満たす）、`productionRules`・`productionRules_sound`（両者の δ を規則にした六つの項目。条件なしで健全）、`http_check_connection`（その表で受理した要求の検査が `Ok(w)` を返すなら `w = checkedRequest t req`、req は渡された要求、t は R と S に属する）。
- 旧 Scope との対応: `CheckedPath.hasTypeV`・`CheckedPath.hasTypeV_of_covers`・`CheckedEndpoint.hasTypeV`・`CheckedEndpoint.hasTypeV_of_covers`（旧の検査済みの値の対象は `Scope.PathIn[R]`・`Http.RequestIn[R]` を持つ）、`makePath_checkRun`・`makeEndpoint_checkRun`（旧の検査が成功する入力では、実例の表の δ は具体化した範囲 r が対象を含むときだけ `Ok`、そうでなければ `Err`）。

### 表層の対象健全性（`Surface/Theorems.lean`）

```lean
theorem surface_target_sound {p : Program} {B : Builtins} {opPrim : OpPrim} {ε : Eff}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hc : B.CoreAssumptions (desugarProgram opPrim p)) (ht : B.TargetAgreement (desugarProgram opPrim p))
    (hmain : p.HasMain ε) {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hsteps : Steps (desugarProgram opPrim p) B (.run (.app (.fnRef "main" [] []) []) [] Store.empty) s)
    (hst : Step (desugarProgram opPrim p) B s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows ε l t
```

前提は、主定理（`surface_effect_soundness`）と同じプログラムの条件（`p.WellFormed`・`p.WellTyped`・`HasMain`。上限を空に限らない）と、信頼条件 `CoreAssumptions`・`TargetAgreement` だけである。証明は `desugar_typed`（`hsig` は `hc.sig_scoped`）の結論に `Release.reachable_target_sound` を当てる。開始状態の呼び出しは main の宣言のエフェクト d.eff を `substAt 0 [] []` で読んだ効果で型付き（新しい補題 `main_typed_eff`、`Surface/Lemmas/Program.lean`）、`Eff.allows_substAt_nil` と `Eff.Allows.mono`（`d.eff ⊆ ε`）で ε の許可へ移す。構成要素（観測・許可・TA）は L30.4・L30.5 と同じ固定した定義であり、言明の引数にしない。

## 検査済みの要求の値の扱い（依頼の 2）

`Val.target?` で述べる形を採った。`CheckedModels o v` を「v が対象 t を保持し（`v.target? = some t`）、`t.kind = o.kind`、`o.bound.index` に t が属する」に、`CheckSpec.Contract` の成功値の条件を `w = .checked t` から `w.target? = some t` に直した。要求の契約を `w = checkedRequest t req` にする代案は、`CheckSpec` に成功値の形を持たせる変更が要り、パスと要求の二つの契約を別に保つことになるので採らなかった。`checkDelta`（Boundary の汎用の δ）の成功値は今も `.checked t` であり、`checkDelta_ok_mem` はその強い形のまま直接証明した。

L40.3b の申し送り 3 の対応の決定: `requestCheck.target` の `endpointOf` には `reqEndpoint reqTarget`（要求の定数の対象が endpoint のときだけその endpoint）、`ModelHttp.builtins` の `hostPat` には `hostPatOf hostPattern`（Scope の項目の動的なパターンと同じ解析と `Port.ofInt?`。`requestCheck_pattern_hostPatOf`）を渡す。`Boundary.requestValueRun` に当たる要求の射影の実行は `deltaRun (ModelHttp.builtins …) "Http.requestInValue" [] []`（`productionRules.requestValue`）とした。`Boundary` 自体は変えていない（下の申し送り 5）。

代償として、局所解析の事実は検査済みの対象の値と検査済みの要求の値を区別しない。射影の引数をコアの入力の型で型付けるには、`Scope.PathIn` のように `valContent` を持たない名前では「値が検査済みの要求の値でない」ことが要る（`scope_local_typed` の前提 hc、例 `proj_arg_typed` の前提 hv）。所属（R と S への所属）は区別によらず成り立つ。

## 変えた定義と言明を変えた既存の補題

| ファイル | 変更 |
|---|---|
| `Surface/ScopeState.lean` | `CheckedModels` を `Val.target?` で定義（`match v.target?`）、`checkedModels_iff` の結論を `v.target? = some t` に。新しい補題 `target_hasTypeV`。`checkedModels_hasTypeV`・`requiredIndex_hasTypeV` に検査済みの要求の値の前提（`valContent` と要求の型）を加え、後者の種類の前提を `v.target? = some t` で量化。`argIndex_sound`・`requiredIndex_checked` の結論を `v.target? = some t` に。`CheckSpec.Contract` の成功値の条件を `w.target? = some t` に。`checkRule_sound` は言明不変・証明を追随。`checkDelta_ok_mem` は言明不変・証明を直接の展開に。先頭の説明を直した |
| `Surface/ScopeLower.lean` | `analyzeBody_requiredIndex` の結論を `v.target? = some t` に |
| `Surface/ScopeStateExamples.lean`・`Surface/ScopeLowerExamples.lean` | 例 `check_checked`・`body1_checked` の結論を `v.target? = some t` に |
| `Surface/Lemmas/Program.lean` | 新しい補題 `main_typed_eff`（`main_typed` は不変） |
| `Surface/Theorems.lean` | 新しい定理 `surface_target_sound`（既存の二定理は不変） |
| 新 `Surface/ScopeSound.lean`・`Surface/ScopeSoundExamples.lean` | 上の定理と下の例 |
| `formal/Benitoite.lean` | 既定の import に新しい二つのモジュールを加えた |

`Release/`・`Checked/` のファイルは一つも変えていない（依頼の「この変更で直す必要がある `Release/`・`Checked/` のファイル」は 0 件）。`Scope/` の採用定義と `Interval/` も変えていない。`ScopeAccept`・`DesugarRange` の言明は変わらない（`desugar_checkDelta_mem` は `checkDelta_ok_mem` の強い形を使うので不変）。

## 確かめた例（`Surface/ScopeSoundExamples.lean`）

本番の実例の表の δ を規則にした表（`productionRules`。パスの解析は `/data/**`・`/data/a.txt` だけ、ホストのパターンは `10.0.0.0/8` だけ）で次を確かめた。

| 区分 | 名前 | 内容 |
|---|---|---|
| 前提が満たせること | `body_accepted`・`occ_check`・`occ_proj`・`proj_args`・`record7`・`rule1`・`rule7`、`#guard` 3件 | `let r = Scope.checkPathIn[/data/**]("/data/**", raw)`、`match r { Ok(p) => Scope.pathInValue[/data/**](p); … }` を受理し、出現の番号 1・7 に同じ式があり、番号 7 の記録の位置 0 の添字が `/data/**`。射影や検査の範囲を `/data/a/**` に狭めると `notCovered` |
| 接続定理の具体化 | `proj_arg_in_data`・`proj_arg_typed`・`check_ok_in_data` | 射影の文へ到達すれば引数の値は `/data/**` に属する対象を保持し、検査済みの対象の値ならコアの入力の型 `Scope.PathIn[/data/**]`（`pathInValue.inst [/data/**]` の引数）を持つ。検査の右辺の `Ok(w)` の w は `/data/**` に属する |
| 同じ R | `check_core_step` | 検査の規則の評価と同じ範囲の列 `[/data/**]` のコアの E-Prim が同じ `Ok(checked(/data/a.txt))` へ進む（L20.7 の実例の表） |
| 旧 Scope の IP の成否 | `old_ip_inside`・`old_ip_outside`・`new_ip_inside`・`new_ip_outside`・`old_ip_typed` | CIDR `10.0.0.0/8` の中の `10.1.2.3:443` は旧の検査で成功し、実例の表の要求の検査（具体化した範囲が Top でも CIDR の範囲でも）で同じ要求を保持する `Ok`。外の `192.168.0.1:443` は旧の `outsideScope` と新の `Err`。旧の検査済みの値は `Http.RequestIn[10.0.0.0/8:443]` を持つ |
| 未知と予算の停止 | `#guard` 5件・`budget_top_only` | 局所の文字列のパターンは `unknownSource`、上限 0 は `budgetExceeded` で狭い範囲を拒否し、Top だけを受理する。上限 0 では記録の必須の判定が全て Top になり、射影（番号 7）の狭い範囲を `budgetExceeded` で拒否する（リテラルのパターンの検査は局所の事実を読まないので既知のまま） |
| 警告の解析との分離 | `required_independent_of_range` | 必須の判定は区間解析の成分と予算を読まない（`Analyses.required_range_independent`）。接続定理の前提も区間解析の結果を含まない |

`decide` は受理・出現・記録の小さな本体の上だけに使った（例のファイルの単一の検査は 0.56 秒、最大常駐量 約 0.8 GB）。

## Http について言うこと・言わないこと

言うこと: 実例の表の δ を規則にした表で受理した `Http.checkRequestIn` の成功値は、渡された要求を保持する検査済みの要求の値であり、その実効の endpoint は推論した範囲と型検査器の範囲に属する（`http_check_connection`）。旧 Scope の IP・CIDR の成否と実例の表の δ の成否は一致する（例）。言わないこと: 要求の中身（メソッド・パス・ヘッダ）と送った要求の一致、要求から実効の endpoint を得る処理（`reqTarget`）と URL の解析の正しさ（形式化の外側）。

## 主定理の言明と前提の内容

| 主定理 | 言明の字面 | 前提の内容 |
|---|---|---|
| `Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`step_target_sound`・`reachable_target_sound` | L40.5 の後と同じ（`Release/` を変えていない） | 変わらない |
| `Surface.desugar_typed`・`surface_effect_soundness` | 同じ（`git diff` で既存の行に変更なし） | 変わらない（表層の型付け・脱糖を変えていない） |

Release の効果の包含（C-Sub・`Eff.Sub`）は構造上のままである。被覆は受理の判定と接続定理の中だけに現れる。

## 設計書

| 文書 | 変更 |
|---|---|
| 01-12「Scope の局所解析の状態と規則の表」 | `CheckedModels` の表の行、`checkedModels_hasTypeV`・`requiredIndex_checked` の文、契約の文（`Val.target?` の形と理由）、`checkDelta_ok_mem` の文を直し、「まだ接続していない」の文を接続定理の節への参照に替えた |
| 01-12「Scope の局所解析の表層からの対応」 | `analyzeBody_requiredIndex` の行を直した |
| 01-12 新しい見出し「Scope の局所解析の接続定理」（「Scope の必須の判定の受理と拒否の理由」の後） | 【決定】と理由、定理の表、例、番号の一致を前提に取ること |
| 01-12「実行の規則」の観測の箇条 | 表層の対象健全性の一文 |
| 07-04「証明する性質」 | 表層の対象健全性と接続定理の【決定】の二段落 |
| 07-04「01-12 との対応」 | 新しい行「Scope の局所解析の接続定理」「初回リリース版の拡張: 表層の対象健全性」（どちらも Rust は未接続）。Scope の状態の行の成功値、受理の行の「示していない」、検査済みの要求の値の行の `ScopeState` の文を直した |

見出しは一つ加えた。`git grep` で「Scope の局所解析の接続定理」と、直した行名「表層の節の添字と脱糖の範囲」の参照を確かめた（01-12 の 2 か所、07-04 の行の名前を含む 4 か所。道具・テストからの参照はない）。` ```text ` のブロックは加えていない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 最初の全体のビルド（L40.5 の分を作り直した） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>`（`/usr/bin/time -l` で包む） | 0 | 57.87 秒（排他の待ち 0 秒） | [lake-build-first.log](lake-build-first.log)・[lake-build-first-time.txt](lake-build-first-time.txt) |
| モジュールのビルド 3回（単一ファイルの検査の依存を作るため） | 同上に対象のモジュールを付ける | 全て 0 | 計時なし | 一時ファイル |
| 途中の全体のビルド 1回 | 同上 | 0（`Build completed successfully (501 jobs)`、sorry 0） | 5.39 秒 | 一時ファイル |
| 局所の単一ファイル（約12回） | `cd <wt>/formal && lake env lean -M 12288 <相対パス>` | 途中は 1 が 3回（下の「失敗と修正」）、最後は全て 0 | 各 0.3〜6 秒 | 本書 |
| 作業末の全体のビルド | 同上（排他の道具） | 0。`Build completed successfully (501 jobs)`、`sorry` の出現 0、警告 89件（最初のビルドと同数。新しいファイルの警告なし） | 0.16 秒（途中のビルドの後に変更がなく、組み立ては起きていない） | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l40.6>/axioms.lean`（`#print axioms` 72件） | 0 | 0.60 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base e9d6624b32fd2fc7395ed5782b0bf33bc785a300 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean` の変更）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base e9d6624b32fd2fc7395ed5782b0bf33bc785a300` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.18 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |

公理: 72件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 56件、`propext`・`Quot.sound` 7件、`propext` 8件、依存なし 1件）。`sorryAx` と独自の公理はない。対象は新しい定理と例の全て（51件）、言明か証明を変えた既存の補題と例（12件）、主定理 9件である。

work の `formal_build` は `scripts/check.sh` の中の `lake build` で、排他の道具を通らない。作業末の全体のビルドの直後でビルド済みであり、組み立ては起きていない。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。全体のビルドの値は並行するジョブの中で最大のプロセスの値である。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 最初の全体のビルド | 3577380864 | 3411.7 | 3.33 |
| 途中の全体のビルド | 1531887616 | 1460.9 | 1.43 |
| 作業末の全体のビルド（組み立てなし。排他の道具と Lake の値） | 69861376 | 66.6 | 0.07 |
| 例のファイルの単一の検査 | 833568768 | 795.0 | 0.78 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1523499008 | 1452.9 | 1.42 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1384136704 | 1320.0 | 1.29 |

本作業で観測した最大は 3.33 GiB（最初の全体のビルド。L40.5 の分の作り直し）である。作業末の全体のビルドは組み立てが起きなかったので、その値は Lean の常駐量ではない。新しいモジュールを組み立てた途中の全体のビルドの値は 1.43 GiB である。`-M 12288` は変えていない。

## 失敗と修正

- `ScopeSound.lean` の局所の検査の1回目が終了1（2件）。(1) `RhsEval.callStd` は規則を評価する範囲の列を量化する（呼び出しの範囲の列と結び付けない）ため、逆転の補題で同じ rs を得られなかった。`rhsEval_prim` の結論を「ある範囲の列 rs' で評価した」に直し、同じ rs でのコアの実行は `scope_check_core` で別に結論した。(2) `acceptBody_sound` の範囲の位置を推論に任せたため型が決まらなかった。明示した。
- `Surface/Lemmas/Program.lean` の `main_typed_eff` の試しで、効果の代入 `substAt 0 [] [] d.eff` と d.eff の包含が残った。等号でなく `Eff.allows_substAt_nil` で許可の段で移す形にした（試しの途中に一時的に `sorry` を置いた版を単一ファイルで1回検査したが、全体のビルドには入れていない。作業末のビルドに `sorry` はない）。
- `ScopeSoundExamples.lean` の1回目が終了1。`Except` と規則（関数を含む構造体）の等号は決定可能でなく `decide` が使えなかったので、`reasonOf` の `decide` と `rfl` に替えた。上限 0 の本体の拒否の番号の見込み（番号 1）が誤りで、実際は番号 7（リテラルのパターンの検査は超過しても既知）だったので、`#eval` で確かめて直した。`if_pos`・`if_neg` の非推奨の警告を `ite_eq_left`・`ite_eq_right` に替えた。

## L40 の段末の確認

plan-l10-l50「義務の一覧と枝の対応表」の L40 の行を、L40.1〜L40.6・L40.3b の記録と本枝の定理で確かめた。

| 義務 | 閉じた枝 | 根拠 |
|---|---|---|
| 名前の衝突のうち述語の重複 | L40.1 | `Checked.Scope` が `Scope.Domain` の整形式性を使う |
| 旧 Scope の一般化（L00.02 の義務 7、DET-01） | L40.1・L40.6 | L40.1 の IP・CIDR の成否とホスト名だけの入力の同値。L40.6 の `PathIn[R]`・`RequestIn[R]` との対応、実例の表の δ との成否の一致、CIDR の中と外の例 |
| Scope の局所状態と規則の表、Range の成分を読まない（問14） | L40.2 | `ScopeState`、`Analyses.required_range_independent`・`stepScope_separate` |
| `apiAt` に利用者の関数が入らない（UB10） | L40.2 | `standardTable_user`（解決器の側は UB20・K10） |
| 予算と忘却（DET-08） | L40.2 | `Run.exceeded_requiredIndex` ほか。L40.6 の例で受理への影響を確かめた |
| Surface から局所解析への対応・射影の保存・`const`・番号の新規性 | L40.3 | `analyzeBody_sound`・`analyzeBody_numbered` |
| 値の所属の規則のうち検査済みの要求の値（RV-L20 中3） | L40.3b・L40.6 | L40.3b の V-CheckedRequest。L40.6 で局所解析の成功値の対応と契約を `Val.target?` で述べ、Http の項目に接続した |
| 範囲の変数の整形式性と値の所属（Surface、NS） | L40.4 | L40.4 の results（表層は検査済みの値を作らない決定） |
| 明示拡大の S を戻り値の注釈から一意に決める | L40.4 | `widenPathIn_target_unique` |
| 拒否の理由（DET-05） | L40.4（交換は L50.2） | `CoverFailure` |
| 表層の前提の変更（`hsig`・`p.WellTyped`） | L40.4・L40.5 | 各 results の同値の補題 |
| 脱糖の出力に範囲の変数がない（P5） | L40.5 | `desugar_rangeFree` |
| 型検査器の R と脱糖・コアの R の一致、検査の δ が R とパターンの両方を確かめる（同じ R） | L40.5・L40.6 | `desugar_checkRule_index`・`desugar_checkDelta_mem`。L40.6 の `evalScope_core_step`・`scope_check_core` |
| 表層と交換の中間状態（Top の列） | L40.5（交換の書き出しは L50.1） | L40.5 の results |
| Scope の接続定理、旧 Scope の IP の成否、警告との分離 | L40.6 | 本書 |

L40 の段で残るものは、交換の範囲の読み書き（L50.1）、交換の入力の検査と拒否の理由（L50.2）、互換層と実例の表の整理（L50.3）である。

## 停止条件の点検

- 旧の四主定理・`step_sound`・一段と到達先の対象健全性・表層の二定理の言明と前提は変えていない。新しい表層の対象健全性の前提は依頼のとおり（主定理と同じプログラムの条件、`CoreAssumptions`、`TargetAgreement`）である。
- `Builtins.Assumptions`・`CoreAssumptions`・`TargetAgreement` の欄、公理は変えていない。結論の弱化はない。
- `Scope/` の採用定義、`Release/`、`Checked/` は変えていない。Release の効果の包含は構造上のままである。
- 局所解析の補題（`ScopeState` の `CheckedModels`・`CheckSpec.Contract` とそれを使う 6 補題・例 2 件）の言明を変えた。主定理ではなく、依頼の 2 が求めた直しである。成功値の対応は対象の所属について同じ強さであり、値の形（`.checked` か `.checkedRequest` か）の区別を失った（上の「検査済みの要求の値の扱い」）。

## ずれと申し送り

### 計画からのずれ

1. 編集したファイルに `Surface/Lemmas/Program.lean`（`main_typed_eff`）を含む。依頼の編集してよい範囲（`Benitoite/Surface/`）の中である。
2. **文の始まりの番号とその右辺の出現の番号の一致を前提に取った**。接続定理の `hocc` と `hreach`・`hrhs` は同じ番号 k と同じ式を使う。番号の一致は区間解析と共有する先行順の数え方によるが、`ReachBlock` の全ての構成子について出現の一覧の位置を辿る補題は置いていない（見込み 1〜2時間）。例では満たせることを確かめた。レビューで確認を求める。L50.4 か K10 の前に一般の補題にするかを取りまとめが決める。
3. 表層の具体の評価 `RhsEval.callStd` は、規則を評価する範囲の列を呼び出しの範囲の列と結び付けない（L40.3 の定義）。接続定理は規則の健全性が全ての範囲について成り立つことで閉じ、同じ範囲の列でのコアの実行は `scope_check_core`・`evalScope_core_step` が結論する。L40.3 の `RhsEval` は変えていない。

### L50 への申し送り

4. L50.1・L50.2: 交換形式には検査済みの要求の値がない（L40.3b の申し送り 6 のまま）。局所解析の成功値の対応を `Val.target?` にしたので、独立入力の期待値は成功値の形を区別しない。
5. L50.3: `Boundary`（汎用の `checkDelta`、成功値は `.checked`）と `productionRules`（実例の表の δ）の二つの表の作り方が並ぶ。`Boundary.rules.checkRequest` は検査済みの要求の値を作らないので、`productionRules` に寄せるか、`Boundary` に要求の検査の実行を欄として持たせるかを整理する。`productionRules` は二つの実例の表（`ModelTargets`・`ModelHttp`）の δ を混ぜて使い、`Scope.pathInValue` の δ は実例の表にないので値を返さない。三つの実例の表の整理（L40.3b の申し送り 7）と合わせる。
6. L50.4: 接続定理の前提の番号の一致（上の 2）と、`scope_local_typed` の前提（検査済みの要求の値の内容の条件）を、定義・言明・仮定のレビューの観点にする。

### R20・R30・K10 への申し送り

7. R20: Rust の型検査器と局所解析は、文の始まりの記録の番号と、その文の右辺の呼び出しの出現の番号を同じ数え方にする（接続定理の前提）。受理した範囲の列は脱糖でそのまま組み込みの呼び出しへ書く。
8. R30: `Http.checkRequestIn` の成功値は渡された要求を保持し、`Http.requestInValue` は同じ要求を返す（`http_check_connection`、L40.3b の申し送り 8 と同じ）。ホストのパターンの解析とポートの変換は、型検査器のリテラルの読み取りと実行時の検査で同じ関数にする（`hostPatOf` と `requestCheck` の同じ解析）。
9. K10: 旧 Scope の IP・CIDR の成否と新しい検査の成否の一致（例 `old_ip_*`・`new_ip_*`）を独立入力の候補にできる。Rust は今 IPv4 の形のホストを InvalidTarget とする（L40.1 の申し送り 4）ので、R30 の後に照合する。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 07:57 ごろ（JST、依頼文を読み始めた時刻） |
| 終了 | 08:30 ごろ（本書の作成まで） |
| 外側の所要 | 約33分 |
| 能動時間 | 約30分（文書と既存の定義を読む約8分、`ScopeState` の直し約3分、接続定理と本番の表の接続約7分、表層の対象健全性約3分、例約4分、設計書と本書約5分。ビルドの待ちを除く） |
| ビルドの回数と時間 | 全体のビルド 3回（最初 57.87 秒、途中 5.39 秒、作業末 0.16 秒）、モジュールのビルド 3回、局所の単一ファイル約12回 |
| 検査 | work 1回 9.18 秒（dry-run 数秒）、公理の確かめ 1回 0.60 秒 |
| 待ち | 排他の道具の待ちは 0 秒。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.4〜3時間の範囲内。上端の2倍（6時間）を超えていない |
