# L30.4 の結果: 一段の対象健全性

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L30.4（plan-l10-l50「L30」の表の L30.4 の行）。担当は Claude のサブエージェント |
| B_WORK | `df9a83396e98dc6f04fcf1b9df3e94841a8966b1`（本線、L30.3 の取り込みの後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l30.4`。git の状態は変えていない |
| 状態 | **完了**。既定の全入口のビルドが sorry なしで通る |
| 閉じた範囲 | 依頼の 1〜6。一段の言明と証明、E-IO・E-IOErr・E-Exit・解放の事象・E-OpPrim・E-Op と節の実行の場合、RV-L00 中1 の反例の補題、Http について言うこと・言わないこと、07-04「証明する性質」と「01-12 との対応」、01-12「実行の規則」の補足 |
| 未完 | なし（本枝の範囲）。到達先の言明と誤った節の規則の反例は L30.5 |
| 適用した前提の変更の行 | なし。型付け・遷移・仮定・主定理の定義を変えていない（新しい定義 `Event.obs` と、新しい定理と例だけ） |
| 停止条件 | 該当しない。主定理の字面と前提の内容は L30.3 の後から変えていない（`git diff df9a8339 -- formal/Benitoite/Release/Theorems.lean formal/Benitoite/Surface/Theorems.lean` は空）。結論の弱化、`Builtins.Assumptions` の欄の追加、公理の追加はない |

## 一段の定理の言明と前提

`formal/Benitoite/Release/Lemmas/TargetStep.lean`:

```lean
theorem step_target_sound (hdecl : P.EffectsOk B) (hc : B.CoreAssumptions P) (ht : B.TargetAgreement P)
    {Eb : Eff} {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hs : StateTyE P B Eb s) (hst : Step P B s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows Eb l t
```

plan の構成要素との対応:

| 構成要素 | この言明での形 |
|---|---|
| `obs` | `Event.obs`（新しい定義。`Event.io` の観測の欄の射影、解放の事象は `[]`）。主定理は IO の事象の観測の欄そのもの、事象の種類によらない形 `step_target_sound_event` は `ev.obs` を読む |
| `allows` | `Builtins.Allows`（L20.7。`Eff.Allows B.effKind`、L10.5 の κ を表の `effKind` にしたもの） |
| `TA` | `Builtins.TargetAgreement`（L20.7） |
| 結論の形 | `StateTyE P B Eb s` と `Step P B s (some ev) s'` から `∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows Eb l t`。事象の操作の名前 l を通す |

- `obs`・`allows`・`TA` は言明の引数ではなく、固定した定義である。
- 前提の信頼条件は `CoreAssumptions` と `TargetAgreement` だけである。ほかの前提はプログラムの宣言の条件 `P.EffectsOk B`（四主定理の `progress`・`preservation`・`effect_soundness` と同じ前提。`handled(H)` が組み込みのエフェクトの名前を利用者の宣言と取り違えないために要る）、状態の型付け `StateTyE`、遷移だけである。対象健全性そのもの・所属の保存・外部応答の一致を仮定へ移していない。
- 初期の ε を固定できる `StateTyE` で述べ、公開の `StateTy` に頼らない（RV-L10「BA のもとで残る危険」(a)）。
- 全体の信頼条件の版 `step_target_sound_of_assumptions`（`hA.core`・`hA.target` を渡すだけ）と、事象の種類によらない版 `step_target_sound_event`（`∀ t ∈ ev.obs, ∃ b ws o obs e l, ev = .io b ws o obs ∧ B.sig b = some e ∧ e.opEff = some l ∧ B.Allows Eb l t`）も置いた。

## 置いた定理

`formal/Benitoite/Release/Lemmas/TargetStep.lean`（新規、既定の import に加えた）:

| 名前 | 内容 |
|---|---|
| `Event.obs`（定義）・`Event.obs_io`・`Event.obs_release` | 事象の観測の射影。解放の事象の観測は空 |
| `Eff.allows_union_other_name` | `m ≠ l` なら `Eff.Allows κ (ε ∪ {m[ix]}) l t ↔ Eff.Allows κ ε l t`（RV-L00 中1 の反例の補題。κ は任意） |
| `step_target_sound` | 一段の対象健全性（上） |
| `step_target_sound_of_assumptions` | 全体の信頼条件のもとでの同じ定理 |
| `step_target_sound_event` | 事象の種類によらない形 |
| `StateTyE.clause_allows` | 節の型付けの反転と節自身の IO の伝播。Fail でない操作 o を処理する最も内側の枠の節 c の本体は、穴の効果 εh から決まる節の操作の型 sg と効果 `Eff.shift c.ntys 0 εc` で型付き、その効果が許す名前 l の対象は、l を処理する枠が枠の下の継続になければ Eb が許す（E-Op・E-OpPrim の両方） |
| `StateTyE.opPrim_clause_allows` | E-OpPrim の状態。捕捉された呼び出しの具体化した署名の効果が許す対象は、穴の効果 εh が許し、許す名前は署名の操作の名前 l だけ。節の本体の効果が許す対象は Eb が許す |

`formal/Benitoite/Release/TargetStepExamples.lean`（新規、既定の import に加えた。表は L20.7 の実例 `ModelTargets.Examples.B`、プログラムは `progOf dataTree`。`CoreAssumptions`・`TargetAgreement` は `progOf_assumptions` から）:

| 名前 | 内容 |
|---|---|
| `ioState_typedE`・`ioState_target_sound` | `File.writeTextIn[;;/data/**](checked(/data/a.txt), "x")` の状態を末尾 `{File.Write[/data/**]}` で型付け、E-IO の事象（`ioState_step`）に一般の定理を当てる。観測 `/data/a.txt` は `File.Write` の名前で許される（非 Top の IO） |
| `sIO_target_sound` | 例 3a の節の IO の状態（初期状態から E-Handle・E-OpPrim で到達し、保存の定理で初期の上限 `{File.Write[/logs/**]}` を末尾に持つ。L30.3 の `sIO_typed`・`sIO_step`）に一般の定理を当てる。L30.3 の `sIO_obs_allowed` を一般の定理から得た |
| `inv_prim_app_eff` | 組み込みの呼び出しの型付けの、任意の文脈での効果の反転（例の補助） |
| `s1_split`・`s1_find`・`s1_clause_allows_log` | E-Handle の後の状態 `s1` で、節の型付けの反転だけから（保存の定理を通さず）、節が書く `/logs/l.txt` が初期の上限に許される |
| `s1_captured_allows` | 同じ状態で、捕捉される呼び出しの対象 `/data/a.txt` は節の添字を選ぶ穴の効果が許し、許す名前は `File.Write` だけ |
| `readBound_allows_read_passwd`・`readBound_exists_name_allows_passwd`・`readBound_not_allows_write_passwd`・`no_write_event_passwd`・`ioState_readBound_typed`・`ioState_readBound_allows` | RV-L00 中1 の反例（下の節） |

## 場合ごとの閉じ方

| 場合 | 閉じ方 |
|---|---|
| E-IO・E-IOErr・E-Exit | 観測を持つ事象の遷移はこの三つだけである（`Step` の場合分け。L20.6 の `Step.io_inv` と同じ）。状態の型付けから呼び出しの型付けと継続の型付けを取り出し、`inv_prim_app` で引数の型付け・範囲の許容・型引数の個数・制約を得る。入力の所属は引数の型付け（V-Checked）が与え、`TargetAgreement.obs_allowed`（`io_target` と形の検査 `io_op`）で観測は具体化した署名の効果の名前 l の原子に許される。L30.3 の `ContTy.allows_end_of_prim_call` で、処理する枠のない継続を通して Eb の名前 l の原子に許される（同じ補題が許す名前を署名の名前に限る）。二つの補題の l は `opEff` で一致する |
| 解放の事象（E-Release・E-RelErr・E-EscRel・E-EscRelErr・E-ErrRel・E-ErrRelErr・E-ExitRel・E-ExitRelErr） | 観測を持たない（`Event.obs_release`）。IO の事象の形の言明では、遷移の場合分けで現れない |
| E-OpPrim・E-Op | 事象を伴わないので、一段の言明の場合分けには現れない。節の本体については `StateTyE.clause_allows` を置いた: 継続を `ContTy.split` で分け、節の型付けを `HasTypeClausesQ.find` で反転し、節の効果（閉じているので型の変数のずらしは正規化だけ）が許す対象を L30.3 の `ContTy.allows_clause_end` で Eb へ運ぶ。E-OpPrim では、捕捉された呼び出しの対象が穴の効果に許されること（`ContTy.split` の結論）も `opPrim_clause_allows` に含めた（SK §4 の規則: 節の効果は出力の上限で検査し、処理する名前を節自身の効果から差し引かない） |
| 節の実行 | 節の本体が行う IO は、E-OpPrim・E-Op の後の状態から、保存の定理（`preservationE`）で同じ Eb を末尾に持つ状態の E-IO として出る。その事象は E-IO の場合で閉じる（例 3a の `sIO_target_sound`）。保存の定理を通さない節の型付けからの伝播は `s1_clause_allows_log` で確かめた |

L30.1 の申し送り 4（節の本体へ渡る捕捉した引数は、S が規則の値なら呼び出しの範囲 R = S の型、Top なら Top の型）は、一段の言明では使わなかった。捕捉した引数を節の本体が IO へ渡す場合も、その IO は後の状態の E-IO であり、引数の型付け（V-Checked の所属）と `io_target` から閉じるためである。

## 反例の補題（RV-L00 中1）

- 一般の補題: `Eff.allows_union_other_name`。上限に別の名前 m の原子（範囲の位置は任意）を足しても、名前 l の対象の許可は変わらない。
- 本番の定義での例（`TargetStepExamples`）: 上限 `readBound = {File.Write[/data/**]} ∪ {File.Read}`（`File.Read` は Top の原子）。
  - `readBound_allows_read_passwd`: `File.Read` の名前で `/etc/passwd` を許す。
  - `readBound_exists_name_allows_passwd`: 名前を落とした形 `∃ l, B.Allows readBound l /etc/passwd` は成り立つ（L00 の言明の案の弱さ）。
  - `readBound_not_allows_write_passwd`: `File.Write` の名前では許さない。
  - `no_write_event_passwd`: 一段の定理から、`readBound` を末尾に持つどの型の付いた状態からも、観測に `/etc/passwd` を含む `File.writeTextIn` の事象の遷移はない。
  - `ioState_readBound_typed`・`ioState_readBound_allows`: 同じ上限を末尾に持つ型の付いた状態は実際にあり（空の前提ではない）、その事象の観測 `/data/a.txt` は `File.Write` の名前で許される。

## Http について言うこと・言わないこと

plan-l10-l50「RV-L20 の後の注」(1) により、`Http.RequestIn` の値は L40.3b で入れる。一段の定理は表の項目を名指ししない一般の定理なので、Http の項目については次のとおりである。

- 言うこと: `CoreAssumptions` と `TargetAgreement` を満たす表が `Http.sendIn`（単一の対象の形 `single endpoint 0`、効果 `Http.Connect[rvar 0]`）を持つなら、その E-IO・E-IOErr の事象の観測の endpoint は、Eb の `Http.Connect` の原子に許される。旧 Top の形の HTTP の項目（L20.6 の `ObservationExamples` の `Http.send` の形）なら、観測は宣言した種類（endpoint）の対象であり、Eb の名前だけの（Top の）`Http.Connect` の原子に許される。
- 言わないこと: (1) 今の値 `Val.checked t` は endpoint の対象しか持たないので、検査した要求の中身（メソッド・パス・ヘッダ・本体）と送った要求の一致、`Http.checkRequestIn` が検査した要求が `Http.sendIn` に渡ることについては何も言わない。(2) 実例の表 `ModelTargets.Examples.B` は Http の項目を持たないので、Http の場合を例で確かめていない（`TargetTable` は署名だけを置き、`Http.requestInValue` の δ はない）。(3) L40.3b で値の形と葉の規則を変えると、`StateTyE` の内容（値の型付け）が変わる。そのとき本定理は証明し直しが要る見込みである（証明は値の形を場合分けしないので、`obs_allowed` が通れば追随は小さいと見込むが、確かめていない）。

## 設計書の変更

| ファイル | 変更 |
|---|---|
| `docs/design/07-quality/07-04-formal-semantics.md` | 「証明する性質」に一段の対象健全性の【決定】の段落を加えた（言明、前提の信頼条件、構成要素、名前を通すことと反例、場合ごとの閉じ方、`StateTyE` で述べる理由、到達先の言明はまだないこと、Http について言うこと・言わないこと）。「形式化で仮定するもの」の `io_target` の箇条の末尾の「一段の対象健全性はまだ言明していない」を、示した旨に直した。「01-12 との対応」に行「初回リリース版の拡張: 一段の対象健全性」を加えた（Rust は未接続） |
| `docs/design/01-spec/01-12-core-calculus.md` | 「実行の規則」の観測の箇条の次に、`Event.obs`（解放の事象は空）、観測を持つ遷移が E-IO・E-IOErr・E-Exit だけであること、一段の対象健全性を指す箇条を一つ加えた |

見出しは足していない。01-12 から 07-04 への新しいリンクは既存の見出し「証明する性質」を指す。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 最大常駐量 | 記録 |
|---|---|---|---|---|---|
| 新しいモジュールのビルド（例のファイルの単一検査に要る olean） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <ログ> Benitoite.Release.Lemmas.TargetStep` | 0（77 ジョブ） | 0.47 秒 | 761774080 バイト（726.5 MiB、0.71 GiB） | [builds/build-01-targetstep.log](builds/build-01-targetstep.log) |
| 全体のビルド（Lean の変更の後） | 同上（引数なし） | 0（453 ジョブ、`declaration uses 'sorry'` なし。警告 90 件は B_WORK と同じで、新しいファイルの警告はない） | 1.01 秒 | 1521778688 バイト（1451.3 MiB、1.42 GiB） | [builds/build-02-full.log](builds/build-02-full.log) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l30.4>/axioms.lean`（29 件の `#print axioms`） | 0 | 0.60 秒 | 1514799104 バイト（1444.6 MiB、1.41 GiB） | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base df9a83396e98dc6f04fcf1b9df3e94841a8966b1`（先に同じ指定で `--dry-run`、終了 0） | 0 | 7.11 秒 | 1384923136 バイト（1320.8 MiB、1.29 GiB） | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt)・[work-check-dry-run.log](work-check-dry-run.log) |
| 作業末の全体のビルド | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <ログ>` | 0（453 ジョブ、sorry なし） | 0.17 秒（組み立て済み） | 70483968 バイト（67.2 MiB、0.07 GiB） | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt) |

- dry-run の選択: `spec_tally`・`spec_examples`（01-12 の変更）、`formal_build`（`formal/Benitoite.lean` ほか）。計画の見込みどおりで、三つとも通った（`spec_examples` 7 件成功）。
- 途中の単一ファイルの検査は `lake env lean -M 12288 <ファイル>` で 6 回（各 1 秒前後。計時していない）。
- 最大常駐量は macOS の `/usr/bin/time -l` の値（バイト）。一つのコマンドの子のうち最大のもので、並行しない。作業末のビルドは組み立て済みで小さい。
- 公理: 29 件のうち、`propext`・`Classical.choice`・`Quot.sound` の三つ全てに依存するもの 25 件、公理に依存しないもの 4 件（`Event.obs_io`・`Event.obs_release`・`s1_split`・`s1_find`）。`sorryAx` と独自の公理はない。対象は新しい定理 22（補題 8、例 14）と主定理 7 件（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness`）。`decide` は名前の文字列の不一致と、範囲の所属の小さい判定だけに使った。

## 失敗と修正

いずれも単一ファイルの検査の段階で、全体のビルドの失敗はない。

1. `StateTyE.clause_allows` の存在量化の変数の型が推論できず、欄の記法が解決しなかった。変数に型を書いた。
2. `Builtins.Allows`（`abbrev`）の上で `Eff.allows_norm` による `rw` が当たらなかった。`Eff.allows_norm.mp` を項として使う形にした。
3. 例の上限 `readBound` は `Eff.union`（noncomputable）を使うので `noncomputable abbrev` にした。`Eff.single` を `singleAt` へ `rw` で書き換えられなかった（`abbrev` の下にあった）ので、型を書いた `have` で読み替えた。

## ずれと申し送り

計画からのずれ:

1. ファイル: 計画の候補 `Release/Lemmas/TargetSound.lean` は L20.7 が既に置いた（`obs_allowed`）ファイルで、L30.3 の `TargetPropagation` がそれを import する。一段の定理は両方を使うので、新しいモジュール `Release/Lemmas/TargetStep.lean` に置いた。例は `Release/TargetStepExamples.lean` に置いた（計画に候補の名前がない）。
2. `P.EffectsOk B` を前提に持つ。信頼条件ではなくプログラムの宣言の条件で、四主定理と同じ前提である。「`CoreAssumptions` と `TargetAgreement` だけを前提にする」は信頼条件について満たすと読んだ。レビューで確かめてほしい。

後の枝への申し送り:

3. L30.5: 到達先の言明は、`stateTyE_init_eff`（初期の効果 ε を末尾に固定）・`steps_preserve`（同じ Eb を保つ）・`step_target_sound` の合成で書ける（例 3a の `sIO_target_sound` がこの合成の具体例である）。言明の前提は `P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B`・`CoreAssumptions`・`TargetAgreement` と、初期の計算の型付け `HasTypeC P B StoreTy.empty [] [] none m a ε`・`m.ClosedNoEffVars` になる見込みである。誤った節の規則の反例（SK §4 の `WrongHandleRule` の本番版）は L30.5 の範囲で、本枝では置いていない。
4. L30.5・L40.6: Http の項目については上の「Http について言うこと・言わないこと」のとおりで、L40.3b の後に言明の追随と Http の項目を持つ実例の表が要る。
5. L40.3b: 値の形を変えると `TargetAgreement.obs_allowed` の単一の対象の形の場合（`canonical_opaque` の場合分け）の追随が要る。`step_target_sound` は値の形を場合分けしない。
6. L50.3: `TargetStepExamples` は `ModelTargets.Examples` と `HandlerTargetExamples` の表と状態に依存する。実例の整理の対象に含める。
7. 一段の定理は事象を伴う遷移だけを扱う。`UnhandledOp`（処理されない利用者の操作）は対象を持たないので対象健全性の対象外であり、エフェクトの健全性の `no_unhandledOp` が扱う。

## 時間

| 区分 | 時刻（2026-10-28） | 所要 |
|---|---|---|
| 文書と定義を読む | 05:33 頃〜05:39 | 約 6 分 |
| 一段の定理と節の補題 | 05:39〜05:41 | 約 2 分 |
| 例と反例 | 05:41〜05:43 | 約 2 分 |
| 設計書・ビルド・公理・work | 05:43〜05:46 | 約 3 分 |
| 本書 | 05:45〜05:47 | 約 2 分 |

能動時間は約 14 分（ビルドと検査の待ち約 10 秒を除く）。外側の所要は 05:33 頃〜05:47 の約 14 分（開始の時刻は概算）。見込み（0.75〜6 時間）の下端を下回り、上端の2倍（12 時間）には近づいていない。排他の道具の待ちは 3 回とも 0 秒。設計者の回答待ちなし。
