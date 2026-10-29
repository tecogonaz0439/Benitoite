# L20.6 の結果: 事象の観測の欄（O1、一度の切り替え）

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L20.6（plan-l10-l50「L20」の表の L20.6 の行）。担当は Claude のサブエージェント |
| B_WORK | `3757cd6ec6a3795a3dfab82dfc3319c65ca70b75`（本線、L20.5 と L40.2 の取り込みの後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l20.6`。git の状態は変えていない |
| 状態 | **完了**。既定の全入口のビルドが sorry なしで通る |
| 閉じた範囲 | 依頼の 1〜6 の全て。試行の件数、`Event.io`・応答の関係・`Oracle`・E-IO・E-IOErr・E-Exit・`step`・`step_sound` の `horacle` の変更、`io_kind`・`io_typed`・`io_exists` の観測の量化、観測を捨てた欄と旧の欄の同値、`horacle` の新旧の関係、旧 Top の HTTP の追従先の小例、設計書 |
| 未完 | なし（計画の L20.6 の行の範囲）。観測と引数・範囲の対応（`io_target`）は L20.7 |
| 適用した前提の変更の行 | 停止の表の「観測についての量化」（問 18 の行 3）と「観測の欄と `Step`・`Oracle`」（問 18 の行 9） |
| 停止条件 | 該当しない。表にない前提・結論の内容の変更、結論の弱化、`Builtins.Assumptions` の欄の追加、公理の追加はない |

## 試行（最初の約9分）

plan「検査の割り当て」の「L の一度の切り替えの試行ビルド」の行に従い、`<wt>` の formal で排他の道具の `lake build`（既定の全入口、`-M 12288`）を回した。最初に基準の状態でビルドし（[trial/build-00-base.log](trial/build-00-base.log)、2.53 秒。L40.2 の分も含めて作り直し済みだった）、中心の変更（[trial/trial-central.diff](trial/trial-central.diff)）を当てた。Lake は失敗したモジュールを import する先を検査しないので、壊れた宣言を直しては全体のビルドを繰り返した（回 01〜07）。直しはすべて引数の追加か組の分解の機械的な追随であり、試行の中で `sorry` に置き換えた宣言はない。回 07 で終了 0 になり、全入口を検査したので未検査はない。

| 区分 | 宣言 | ファイル | 内容 |
|---|---:|---:|---|
| ビルドの診断から宣言へ対応付けたもの | 28 | 9 | [trial/count-from-logs.txt](trial/count-from-logs.txt)。`Release/Examples`（表・oracle・例 2）、`RangeInst`（表）、`PresMain`（`preservationE`）、`Surface/CheckExamples`（表・oracle・`result`・例）、`Progress`（`progress_io`）、`StepSound`（`step_soundE`）、`Model`（`assumptions`・例）、`BuilderExamples`（6 定理。oracle の形）、`PrimRanges`（欄の本体 4・同値 2・小例の表・`io_step`） |
| 診断の前に機械的に直した空の応答の関係の表 | 7 | 6（新規） | `Model.builtins`、`Exchange/Builtins.lean`、`Surface/FailureExamples`・`CheckCounterexamples`・`CheckTables`・`CheckToolsExamples`、`SurfaceCheck/Validation.lean` |
| 中心の変更 | 7 | 4 | `Builtins`、`Event`・`Step`・`Oracle`・`step`、`Builtins.Assumptions`、`step_sound` |
| 合計（一意） | 42 | 19 | 件数と回ごとの時間は [trial/counts.txt](trial/counts.txt)、最後の差分は [trial/trial-final.diff](trial/trial-final.diff) |

見込み: 残りは同値の補題・小例・設計書だけで、上端（2.5時間）の2倍を超える見込みはなかったので、試行の差分をそのまま本体の出発点にした（代案の並べて移す方式は使っていない）。

## 本体の結果

### 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `Builtins.ioResponse`（`Release/Typing.lean`） | 末尾に観測 `List Scope.Domain.Target` を受け取る: `PrimName → List Ty → List Eff → List Val → Outcome → List Target → Prop`。範囲の列は受け取らない（L20.5 の S2） |
| `Event.io`（`Release/Semantics.lean`） | 観測の欄 `obs : List Scope.Domain.Target` を加えた |
| `Step` の E-IO・E-IOErr・E-Exit | 暗黙の引数 `obs` を加え、前提を `B.ioResponse b ts es ws o obs`、事象を `.io b ws o obs` にした。遷移の先の状態は変えていない |
| `Oracle` | `PrimName → List Ty → List Eff → List Val → Outcome × List Target`（応答と観測の組） |
| `step` | `oracle b ts es ws` の組を分解し、観測を事象に書く |
| `Builtins.Assumptions`（`Release/Assumptions.lean`） | `io_kind`・`io_typed` は `∀ … o obs`、`io_exists` は `∃ o obs` にした。欄の数は同じ |
| 例と表 | 上の試行の表の追随（既存の IO の項目 `print`・`exit` と小例の `first`・`second` は観測を空とする。`PrimRangeExamples.builtins` の `File.writeTextIn` は最初の引数の検査済みの対象一つを観測とする） |
| `PrimRanges` の欄の本体と旧の形 | `IOTypedAt`・`IOExistsAt`・`IOTypedOld`・`IOExistsOld` が観測を量化する（範囲の量化の同値 `io_typed_iff_old` などは観測を量化したまま通る）。説明に観測を捨てた形との同値の補題の名前を書いた |

### 置いた定理（新 `Release/Lemmas/Observation.lean`。既定の import に加えた）

| 名前 | 内容 |
|---|---|
| `IOResponseNoObs`・`Builtins.ioResponseNoObs`・`liftNoObs`（定義） | 観測のない応答の関係の型、観測を捨てた関係（`∃ obs`）、旧の表の像（観測が常に空） |
| `Builtins.ioResponseNoObs_liftNoObs` | 旧の表の像では観測を捨てた関係が旧の関係そのもの |
| `Builtins.IOKindField`・`IOTypedField`・`IOExistsField`（定義）と `Builtins.Assumptions.ioKind_field`・`ioTyped_field`・`ioExists_field` | 三つの欄の本体。欄の字面と定義上同じ |
| `Builtins.IOKindNoObs`・`IOTypedNoObs`・`IOExistsNoObs`・`IOTypedOldNoObs`・`IOExistsOldNoObs`（定義） | 観測のない関係 R で読んだ旧の欄（L20.6 の前、および L20.5 の前の字面） |
| `Builtins.ioKind_iff_noObs`・`ioTyped_iff_noObs`・`ioExists_iff_noObs` | 観測を捨てた欄と旧の欄の同値 |
| `Builtins.ioFields_iff_old_of_liftNoObs` | 旧の表の像で、三つの欄が旧の関係で読んだ欄と同値 |
| `Builtins.ioTypedOld_iff_noObs`・`ioExistsOld_iff_noObs`、`Builtins.ioTyped_iff_oldNoObs`・`ioExists_iff_oldNoObs` | L20.5 の範囲の量化の同値との合成。範囲の変数のない表では、今の欄が範囲の列も観測もない欄（L20.5 の前の字面）と同値 |
| `Oracle.ofNoObs`（定義）、`horacle_noObs`・`horacle_of_noObs` | 新しい `horacle` から観測を捨てた旧の形が従う。旧の表の像では旧の形から、観測を空とする `Oracle.ofNoObs` について新しい形が従う |
| `Step.io_inv`・`Step.io_noObs` | 観測を持つ事象の遷移は処理する節のない組み込みの IO の呼び出しで、応答と観測の組は応答の関係が許すもの（L30 の対象の健全性が使える形） |
| `ObservationExamples`（`sendSig`・`builtins` ほか定義、`redirectTarget_ne_first`・`redirect_step`・`redirect_only_step`・`not_requires_first`） | 旧 Top の HTTP の小例（下の「確かめた例」） |

### 同値の補題（旧の像での同値）

| 前提の変更 | 補題 | 前提 |
|---|---|---|
| 観測についての量化（問 18 の行 3）: `io_kind`・`io_typed`・`io_exists` | `ioKind_iff_noObs`・`ioTyped_iff_noObs`・`ioExists_iff_noObs`（観測を捨てた関係で読んだ同値）、`ioFields_iff_old_of_liftNoObs`（旧の表の像） | なし（像の補題は `B.ioResponse = liftNoObs R`） |
| L20.5 の範囲の量化との合成 | `ioTyped_iff_oldNoObs`・`ioExists_iff_oldNoObs`（`io_typed_iff_old`・`io_exists_iff_old` を通す） | L20.5 と同じ（`RangeFree` と `sig_scoped`） |
| 観測の欄と `Step`・`Oracle`（問 18 の行 9）: `horacle` | `horacle_noObs`（新→旧）、`horacle_of_noObs`（旧の表の像で旧→新） | 後者は `B.ioResponse = liftNoObs R` |
| `Step` の IO の事象 | `Step.io_noObs`（観測を捨てると応答は観測を捨てた関係が許すもの）。遷移の先の状態は観測によらない（規則の字面） | なし |

旧の `Step` の型付けの全体を別に並べた形式の同値の定理は置いていない（L20.4・L20.5 と同じ扱い。`Step` の変更は三つの規則の前提と事象の欄だけである）。

### 主定理の言明と前提の内容

七つの主定理（`Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`、`Surface.desugar_typed`・`surface_effect_soundness`）のうち、字面が変わったのは `step_sound` の `horacle` だけである（`Surface/Theorems.lean` の差分はない。`Release/Theorems.lean` の差分は `horacle` と説明の文だけ）。

`step_sound` の `horacle`:

```lean
-- 変更前（B_WORK）
(horacle : ∀ b ts es ws o, B.ioResponse b ts es ws o → B.ioResponse b ts es ws (oracle b ts es ws))
-- 変更後
(horacle : ∀ b ts es ws o obs, B.ioResponse b ts es ws o obs →
  B.ioResponse b ts es ws (oracle b ts es ws).1 (oracle b ts es ws).2)
```

| 主定理 | 前提・結論 | 変更前（B_WORK） | 変更後 | 旧の像で同値であることの補題 |
|---|---|---|---|---|
| `progress` | `B.Assumptions P`、結論の `∃ l s', Step` | `io_exists` は応答の存在。IO の事象は観測を持たない | `io_exists` は応答と観測の組の存在。`Step` の IO の事象は観測を持つ（結論の遷移の事象が観測を含む） | `ioExists_iff_noObs`、`Step.io_noObs` |
| `preservation` | `B.Assumptions P`、前提の `Step` | `io_typed` は応答を量化する | `io_typed` は応答と観測を量化する。観測は状態に入らないので結論の状態の型付けは変わらない | `ioTyped_iff_noObs` |
| `effect_soundness`・`effect_soundness_noLamNames` | `B.Assumptions P`、結論の `∀ ev s', ¬ Step … (some ev) s'` | 事象は観測を持たない | 事象は観測を持つ（量化する事象の型が広がるだけで、空の効果では IO の事象がない） | `ioKind_iff_noObs` ほか上と同じ |
| `step_sound` | `horacle`、`B.Assumptions P`、結論の `Step` | 上の変更前 | 上の変更後。`oracle` が選ぶ応答と観測の組が応答の関係を満たすことを求める | `horacle_noObs`・`horacle_of_noObs` |
| `Surface.desugar_typed`・`surface_effect_soundness` | 後者の `hb` | 同上 | `hb` の内容は上の `Assumptions` と同じく変わる。前者は応答の関係を読まない | 上と同じ |

`Builtins.Assumptions` の欄の追加、公理の追加、結論の弱化はない。

### 確かめた例（`ObservationExamples`）

小例の表は `Release.Examples.builtins` に旧 Top の `Http.send` の形の項目（引数は URL の文字列、効果は名前だけの `Http.Connect`）を加え、その応答の関係を「引数は文字列一つ、応答は `()`、観測は endpoint の種類の対象の有限列」とした表である。

- `redirect_step`: URL `https://a.example/` の呼び出しが、観測 `[a.example:443, b.example:443]`（追従先を含む）を持つ E-IO の遷移をする。
- `redirect_only_step`: 観測が追従先 `[b.example:443]` だけの遷移もある。
- `not_requires_first`: 応答の関係は、観測に最初の URL の対象と同じ一つの対象を求めない（最初の対象を含まない観測が許される）。`redirectTarget_ne_first` で二つの対象が異なることを示した。

この表が `Builtins.Assumptions` を満たすことは示していない（新版の `Model.assumptions` は L20.7）。観測が引数の種類や範囲に一致することは、応答の関係にも欄にも置いていない（L20.7 の `io_target`）。

### 設計書

- 01-12「実行の規則」: 【決定】の箇条を一つ加えた（事象の観測、応答の関係と `Oracle` の形、E-IO・E-IOErr・E-Exit が観測を記録すること、観測は状態に入らないこと、理由、欄の量化と同値）。` ```text ` の規則の並びは変えていない。
- 07-04「証明する性質」: 【決定】の段落を一つ加えた（性質 1〜3 の前提の内容の変わり方、`horacle` の字面の前後、同値の補題、停止の表の例外としての扱い、小例）。L20.5 の段落の「`step_sound` の oracle の前提も…字面を変えていない」に、観測による変更は次の段落と添えた。
- 07-04「形式化で仮定するもの」: 【決定】の段落を一つ加えた（三つの欄の観測の量化、観測に条件を置かないこと、欄を増やしていないこと）。
- 07-04「01-12 との対応」: 行「実行の規則（IO の事象の観測）」（Rust は未接続）を加えた。
- 見出しは追加・改名していない（`git grep` の確認は不要）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 試行の全体のビルド（8回） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 1（回 01〜06）、0（回 00・07） | 内側 1.50〜137.55 秒 | [trial/](trial/) |
| 本体の途中の全体のビルド（2回） | 同上 | 0 | 内側 138.91 秒（回 08、下流の大半を作り直した）、7.83 秒（回 09） | [builds/](builds/) |
| 局所の単一ファイル | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`Observation` 3回、`PrimRanges` 1回、公理の確認用の写し 1回） | 0 | 各1秒未満〜数秒（計時なし） | 本書 |
| 排他の道具を通さない部分のビルド（1回） | `cd <wt>/formal && lake build Benitoite.Release.Lemmas.PrimRanges` | 0。77 ジョブ | 数秒（計時なし） | 本書（下の「失敗と修正」） |
| 全体のビルド（作業末） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <l20.6>/lake-build.log` | 0。444 ジョブ、`Build completed successfully`。`declaration uses 'sorry'` なし。警告は `Interval/` の既存のものだけ | 1.11 秒（直前の回 09 と部分のビルドの後の差分だけ） | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 3757cd6ec6a3795a3dfab82dfc3319c65ca70b75 --dry-run` | 0。45 ファイルの変更。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean`）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 3757cd6ec6a3795a3dfab82dfc3319c65ca70b75` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 3.39 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l20.6>/axioms.lean`（43件の `#print axioms`） | 0 | 0.56 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 43件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 36、`propext`・`Quot.sound` 2、`propext` だけ 1、公理なし 4）。`sorryAx` と独自の公理はない。対象は旧の主定理 7件、言明か証明を変えた既存の宣言 16件（`preservationE`・`progress_io`・`step_soundE`・`Model.assumptions`・`PrimRanges` の 4 定理と 2 例・`BuilderExamples` の 6 定理）、新しい定理 20件である。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 本体の途中の全体のビルド（回 08。下流の大半を検査し直した。排他の道具の内側の値） | 2657632256 | 2534.5 | 2.48 |
| 全体のビルド（作業末。外側の値） | 1518436352 | 1448.1 | 1.41 |
| 公理の確かめ（`lake env lean -M 12288`、`Benitoite` 全体を読み込む） | 1509212160 | 1439.3 | 1.41 |
| work の検査全体（作業末。ビルド済みの一括の値） | 77971456 | 74.4 | 0.07 |
| work の検査全体（1回目。下の「失敗と修正」の前。`spec_examples` の cargo を含む） | 1384251392 | 1320.1 | 1.29 |

試行の回 01 の内側の値は 2652078080 バイト（2529.2 MiB）である。局所の単一ファイルの検査と排他の道具を通さない部分のビルドは計時していない（値なし。0 ではない）。`-M 12288` は変えていない。

## 失敗と修正

- 試行の回 01〜06 の失敗は、上の試行の表の追随で直した（引数の追加、`Oracle` の組、`obtain ⟨o, obs, ho⟩`、`intro` の引数の数）。
- 設計書の書き換えで、Python のスクリプトが多バイト文字で `SyntaxError: Non-UTF-8 code` を出した（L20.2・L20.3・L20.5 の記録と同じ）。先頭に文字コードの宣言を置いて実行した。結果に影響しない。
- 作業末のビルドと work を一度通した後、`PrimRanges` の旧の欄の説明が観測の量化を書いていないことに気付き、説明を直して合成の補題（`ioTypedOld_iff_noObs` ほか 4 件）を加えた。このとき `PrimRanges` を排他の道具を通さずに `lake build Benitoite.Release.Lemmas.PrimRanges` で一度ビルドした（数秒。ほかのビルドとは重なっていない）。その後、排他の道具で作業末の全体のビルド・公理の確かめ・work の dry-run と本実行をやり直した（上の表は全てやり直した後の値）。1回目の作業末のビルドのログは [builds/build-09-before-last-edit.log](builds/build-09-before-last-edit.log) に残した。
- 記録のログの手元の絶対パスは `<wt>`・`<repo>`・`<home>` へ置き換えた。

## ずれと申し送り

計画からのずれ:

1. `SurfaceCheck/Validation.lean`（formal の直下の既定の入口）を直した。依頼の編集してよい範囲は `Benitoite/` の下を挙げているが、応答の関係の引数の数が変わるので、表の `fun _ _ _ _ _ => False` に引数を一つ足さないと既定ビルドが通らない（L20.5 も同じファイルを直した）。変更はこの一字句だけである。
2. 観測は応答の関係の別の引数とした（`ioResponse b ts es ws o obs`）。応答と観測の組を一つの引数にすれば `horacle` の字面は変わらないが、観測の量化が字面から読めなくなるので採らなかった（plan「全 L 作業の停止条件」の「同じ名前を残して隠さない」）。
3. 新しいファイル `Release/Lemmas/Observation.lean` は計画に候補の名前がなかった。
4. 排他の道具を通さない部分のビルドを一度行った（上の「失敗と修正」）。

後の枝への申し送り:

5. L20.7: `io_target` は `Builtins.ioResponse b ts es ws o obs` の `obs` と引数 `ws` を結ぶ欄として置ける。範囲が要るなら、L20.5 の申し送りのとおり `io_target` の中で範囲の列を量化する（応答の関係は範囲の列を受け取らない）。旧 Top の完全性の文言（作用した対象をすべて含む）は、`ObservationExamples` の形（観測は種類の一致だけ）の表で書ける。新版の `Model.assumptions` の IO の項目は観測を与える必要がある（既存の `print`・`exit` の形は空の観測、`PrimRangeExamples.builtins` の `File.writeTextIn` は最初の引数の対象一つ）。
6. L30.4・L30.5: 一段の対象の健全性は `Step.io_inv`（観測を持つ遷移の逆転）から始められる。観測は状態に入らないので、保存の証明は観測を読まない。
7. L50.1: 交換形式は事象と観測を持たない（Release の状態・事象を書き出さない）。交換の読者に影響はない。
8. L50.3: 比較のための写し（`IOKindNoObs`・`IOTypedNoObs`・`IOExistsNoObs`・`IOTypedOldNoObs`・`IOExistsOldNoObs`・`liftNoObs`・`Oracle.ofNoObs`）は、旧の互換層の整理の対象である。

取りまとめへ:

9. 新しい欄の追加・公理の追加・結論の弱化はない。主定理の字面の変更は `step_sound` の `horacle` だけである（停止の表の問 18 の行 9）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 03:14 ごろ（JST、依頼文を読み始めた時刻） |
| 終了 | 03:40 ごろ（本書の作成まで） |
| 外側の所要 | 約26分 |
| 能動時間（試行） | 約9分（03:18〜03:27。中心の変更と追随。ビルドの待ちを含む） |
| 能動時間（本体） | 約15分（同値の補題と小例 約5分、合成の補題 約2分、設計書 約4分、本書 約4分） |
| 能動時間（読む） | 約4分 |
| ビルドの回数と時間 | 試行 8回（内側 1.50〜137.55 秒）、本体の途中 2回（138.91 秒・7.83 秒）、作業末 1回（1.11 秒）、部分のビルド 1回、局所の単一ファイル 約5回 |
| 検査 | work 2回（9.30 秒・3.39 秒、dry-run 各数秒）、公理の確かめ 2回（各 0.6 秒前後） |
| 待ち | 排他の道具の待ちは記録上なし。回答待ちなし |
| 見込みとの比較 | 見込み 0.25〜2.5時間の範囲内。上端の2倍（5時間）を超えていない |
