# RV-L70.freg: 全比較の最後の照合の台本の変更の独立レビュー

2026-11-09。対象は worktree のブランチ `m014/l70.freg`（HEAD `6d160731c`）の未コミットの差分で、`crates/benitoite/tests/desugar_export/check_named.py`・`check_batch3.py`・`exchange-manifest.json` と `scripts/check/formal_interval.py` である。本書の `<repo>` は対象の worktree、`<tmp>` は会話の scratchpad、D は `<repo>/target/desugar-diff/run-23827` を表す。

読んだもの:

- 担当への依頼文 `L70.freg-claude-prompt.md`（「期待値を改めてよい条件」「止まる条件」）と担当の報告 `L70.freg-claude-report.md`、取りまとめの追加の判断 (2)〜(5)。
- 四つのファイルの差分の全部と、`check_named.py` の `run`・`run_surface`・`check_named`・`check_programs`・三つの変異の検査・`main`。
- `formal/tests/test_named_exchange.py` の `KNOWN_DESUGAR_DIFFERENCES`・`known_shape`・`known_desugar`、`formal/tests/test_range_sources.py` の `preparation_gaps`・`classified_all`、`check_failure.py` の `restViolation` の照合、`scripts/check-formal.sh` の 13〜23 行と 205〜250 行。
- Lean の診断の経路の付け方: `Surface/CheckTables.lean` の `checkPreparedProgram`（定義は `[0]`、実装は `[1]` の下に名前の一覧の番号）、`CheckTablesBase.lean` の `checkNamed`、`CheckDeclarations.lean` の `definitionDetails`（本体は `path ++ [1]`）、`CheckEntrypoints.lean` の `proofFailure`、`CheckDeclarationBase.lean` の `checkImplWith`。
- D の `named-program-mutations-report.json`・`surface-preparation-rejections.json`・`range-budget-comparison/summary.json`、報告と入力の時刻。

したこと:

- 旧（HEAD）と新の manifest を構造で比べた（`<tmp>/rv-freg/mdiff.py`）。差は報告の「改めた期待値の表」と一致し、表にない変更は `batch2Failure.restViolation`（取りまとめの変更）だけだった。
- 変異の 13 件の固定した経路が、壊した定義・実装を指すかを、D の corpus から壊す対象の位置を求めて照らした（`<tmp>/rv-freg/locate.py`。Lean を使わない）。
- `python3 -B scripts/check/test_policy.py` を実行した（32 件、終了0、32 秒）。

担当の `weaken.py`（最大常駐量 14.9 GB）は再実行していない。`lake build`・`scripts/check.sh`・`check-formal.sh`・`check_named.py` の全体・git の書き込み・サブエージェントの起動はしていない。作業木のファイルは変えていない。

## 結論

**条件付き可。重0件、中3件、軽3件、情報4件である。**

`check_named.py` の変更は照合を弱めていない。脱糖の既知の差は経路・定義の種類・形に加え「結果型を差し替えると定義の全体が一致する」ことで数え、件数を manifest で固定するので、差が増えても減っても（R10b で直っても）失敗する。全件・単独・manifest の三者の拒否の一致と、件数の算術（51,762 − 220 = 51,533 + 8 + 1）も照合に入った。報告の再利用は、時刻（入力より古い報告を拒む）と件数・入力の一覧の照合で、別の入力の報告を受け入れる経路は見当たらない。変異の 13 件の経路は全て壊した定義か実装を指す。

条件は中1〜中3の処置である。拒否と理由の固定が、programs と named の entry の水準まで揃ったのに、範囲の予算（中1）と batch3（中2）では拒否の件数・入力を固定せず、比べていたものが分類した拒否へ移っても黙って通る。範囲の予算は今、Lean で比べるケースが 0 件で、照合が実質空である。`restViolation`（中3）は理由の文が一般の文に変わったのに、変異の 13 件と違って経路を固定していない。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | `scripts/check/formal_interval.py` の `range_counts`（範囲の予算の段落） | 「比べたケースと分類した拒否の和が2」は取りまとめの判断 (3) どおりだが、拒否の件数と名前を固定する期待がない。`rangeBudgetPreparationRejected` は同じ実行の manifest に書かれ、verify はそれを読み戻すだけなので、今比べているケースが分類した原因で拒否に移っても失敗しない。programs と named の entry は判断 (5) で入力ごとに原因を固定したのと揃わない。また今回の記録は `leanComparedCases` 0・`requiredReasonComparisons` 0 で、Lean の側の理由の比較は一件も行われていない。コメントは R30 で 2 件に戻ると書くが、戻らなくても通る | 拒否の期待（ケース名 last-run-exceeded・inner-exceeded-outer-recovered と原因 `Scope.ScopeError.At`）を台本の定数か manifest に固定し、実際の拒否の集合との完全一致を要求する。R30 で比べるケースに戻ったら期待を除く、と義務（R30）をコメントと後段への義務の表に書く。Lean で比べるケースが 0 件のまま受け入れることを F-REG の記録に明記する | 読めば確定 |
| 中2 | 中 | `crates/benitoite/tests/desugar_export/check_batch3.py` の `check` | 分類した準備の拒否は、単独と全件の入口が断った入力の一致だけを照合し、どの入力をどの原因で断るかを固定しない。batch3 の六入口が今通している入力（例えば k4・m1・t3）が分類した原因で準備の段に断られるようになっても、単独と全件が揃えば黙って通る。単独と全件の原因（`causes`）の一致も見ていない。担当も報告でこの点を挙げている | profile ごとの期待の拒否（今は k3 の `scope` → `Scope.ScopeError.At` だけ）を batch3 の期待（manifest か台本の表）に置き、入力と原因の完全一致を要求する。全件の `classified["causes"]` と単独の原因の和の一致も照合する | 読めば確定 |
| 中3 | 中 | `exchange-manifest.json` の `batch2Failure.restViolation`、`check_failure.py` の 45 行 | 期待の理由が個別の文「function instantiation violates scope or NoFail」から一般の文「call signature is invalid」に変わった。この文は `CheckInfer.lean`・`CheckOpenInfer.lean` の `need path` で、呼び出しの署名の失敗一般に出る。変異の 13 件では判断 (2) で経路を固定して壊した箇所での拒否を確かめたが、ここは理由の文だけを照らすので、NoFail と Rest を壊した箇所と無関係な署名の失敗でも通る。依頼文の条件①（分類が変わらず文言だけが変わる）に当たるとしても、区別の力は落ちている | `check_failure.py` で `report['result']['error']['path']` も固定する（manifest に `restViolationPath` を足す）。値は一度実行して求め、壊した定義（`failure-nofail` の定義0）を指すことを確かめる | 読めば確定（経路の値は実行しないと分からない） |
| 軽1 | 軽 | `check_named.py` の `check_program_rejections`（`preparationRejected: True` で `continue`）、`check_special_rejections`・`check_rejections`（`if report is not None`） | 壊した入力が準備の段の分類した拒否になると、変異の照合を飛ばして通る。既存の形だが、新しい Lean では準備の拒否が増え（`refined result`・`Http.sendIn`・`Scope.ScopeError.At`）、この経路に入りやすくなった。今回の実行では入っていない（`surface-preparation-rejections.json` の 39 件に変異の一時の報告 `report.json` の単独の検査はなく、変異の報告の 6 件も全て `error` を持つ）ので、13 件は実際に照合された | 変異の対象の入力は manifest で `preparationRejected` を持たないので、`report is None` を失敗にする（`require(report is not None, ...)`）。少なくとも `check_special_rejections` と `check_rejections` の結果も変異の報告に残す | 読めば確定 |
| 軽2 | 軽 | 担当の `<tmp>/weaken/replay.py`、報告の「結論」 | 今の `check_named.py` は、そのままの形では最後まで流れていない。単独の表層の検査 1,792 入力は try1 の出力を `replay.py` で読み直しており、読み直しは報告があれば終了状態を照らさずに読み、なければ記録の文だけで拒否とする（終了2の確認がない）。結果の中身（`ok`・`singleSurfaceFailure`・未知の組込み・拒否の原因）の照合は本番の台本が行うので照合の誤りではないが、本番の `run_surface` の単独の経路と終了状態の照合は、今の manifest に対して未実行である | F-REG の記録に「単独の検査は try1 の出力の読み直しで、次の全比較が今の台本の最初の通しの実行になる」と書く。次の全比較の前に、`check-formal.sh` が残す interval の `manifests/`・`manifest-comparison.json`・`manifest.json` を除く必要がある（担当の報告のとおり `mkdir` に `exist_ok` がない）ことも同じ記録に残す | 読めば確定 |
| 軽3 | 軽 | `check_named.py` の `full_report` | 報告の再利用は時刻と件数で同じ入力を確かめるが、その報告を書いた入口の終了状態を確かめない。`check-formal.sh` の `status` は最後の非0で上書きされ、今は surfaceCheckAll の 2 で終わるので、builtinCheck の終了状態は外からも読めない。builtinCheck は `errors == []` と入力の一覧で中身を照らすので実害はない（coverageProgramDiff と全件の coverageDiff は `check_named.py` が終了0を要求して実行し直す） | 再利用の印として、`check-formal.sh` の該当の段の行（`printf` の出力）か終了状態を報告の隣に残す形は `check-formal.sh` の変更になるので、今は採らない。`full_report` のコメントに、終了状態でなく中身で判定する理由（どの欄を照らすか）を一文で足す | 読めば確定 |
| 情1 | 情報 | 変異の 13 件の固定した経路（`MUTATION_REJECTIONS`） | 経路は Lean の `checkPreparedProgram` の番号で、`[0, i, 1]` は名前の一覧の i 番目の定義の本体、`[1, i]` は i 番目の実装である。`proofFailure` は本体の経路をそのまま使うので、経路は呼び出しの位置ではなく定義の本体を指す。D の corpus で照らすと、hole-label・hole-position・hole-contract は `named_partials.bnt` の最初の `a, b` の部分適用を持つ定義4（`early`）、pipe-label・pipe-position は位置 `[1]` のパイプを持つ定義8（`main`）、method-user は最初のメソッドの定義（`Measure[String].measure`、実装0 `impl:19`）、method-dictionary は `%dict1` を持つ `class:46` の実装1（`impl:50`）、operation は演算を呼ぶ `main`（定義1）、label・position は `named-calls` の `sample`（定義3）、hole・partial は `named-static-calls` の `partial`（定義0）、inserted は `pipe`（定義1）で、全て壊した箇所を指す。同じ本体の別の原因の再検査の失敗とは区別できない（三つの hole の変異は同じ経路になる）が、Lean の診断の粒度による | なし | 読めば確定（位置は corpus で計算） |
| 情2 | 情報 | `classify_program_desugar`・`check_named` の `desugarKnownDifferences` | R10b で差が全部または一部なくなると、分類した件数が manifest の `desugarKnownDifferences.counts`（entry では欄の既定値0件）と食い違って失敗し、manifest の更新を求める。黙って通る経路はない。`known_shape` は期待の結果型が実際の結果型を基底とする篩であることと述語が欄を含むことだけを見るが、`known_program_difference` が定義の全体の一致（結果型の差し替え後）と定義の種類 `accessor` を加えて確かめ、不一致の件数と差の記録の件数の一致も要求する。篩の述語の中身は Rust の側に対応がないので照らせない | なし | 読めば確定 |
| 情3 | 情報 | `full_report` の再利用の確かめ | `check-formal.sh` の出力ディレクトリは既定で `run-$$` だが、`BENITOITE_DESUGAR_DIFF_DIR` で既存のディレクトリを指せる。その場合も入力は同じ実行で書き直されるので、入口が報告を書かずに失敗すると古い報告は入力より古くなり、時刻の照合で拒まれる。件数の照合（desugar は群ごとのプログラム数と定義数、builtin は入力の一覧と `checkedInputs`、surface は `inputs` と拒否数の和・`excludedInputs`）も加わる | なし | 読めば確定 |
| 情4 | 情報 | `check-formal.sh` の 244〜246 行（取りまとめの判断 (4)） | 全比較は surfaceCheckAll の 2 で `check_named.py` の後に止まり、`formal_interval.py` の manifest と verify に進まない。R10b と準備の分類した拒否が残る間は、全比較の終了状態だけでは既知の状態と新しい失敗を区別できず、区間の manifest は手で流す必要がある。判断 (4) で受け入れた前提として、F-REG の受け入れ条件（終了2、`check_named.py` の最後の行、手で流した manifest と verify の終了0）を記録に書くとよい | 受け入れ条件を F-REG の results.md に書く | 読めば確定 |

## 確かめる点ごとの根拠

### 1. 弱めていないか

改めた期待値の各行は、報告の表の条件に当たる。

- `surfaceCounts`: 条件②③。`check_programs` は `counts == surfaceCounts` に加え、`preparationFailure == len(rejected)` と、残りの件数の和が全検査数から拒否した入力の検査数を引いた数に等しいことを要求する。一致だったものが範囲外・失敗になれば、件数か `surfaceOutcomes` の完全一致で失敗する。
- concurrency の 7 入力・8 件: 条件①。`surfaceOutcomes` は旧の `remaining_counts` の除外をやめて完全一致で照らし、`singleSurfaceUnknownBuiltins` で未知の組込みの一覧も固定した。
- network の 9 入力・11 件と `refined result`・`Scope.ScopeError.At` の 23 入力: 条件②。単独の検査は manifest の `preparationRejected` と原因を照合し、記録のない拒否と記録した拒否の消失を両方失敗にする。全件の拒否は名前で三者一致を要求する。
- `f04_list_spread`: 条件①（q11 のまま、理由と経路が変わる）。
- 変異の 13 件: 判断 (2) の形（情1）。
- 範囲の予算と batch3 は中1・中2。`restViolation` は中3。

分類の表にない拒否は、単独では `preparation_gaps` が None になって `run_surface` が元の失敗を上げ、全件では `classify_all` が None になって `full_report` が失敗する。既知の形でない脱糖の差は `classify_program_desugar` が失敗にする。

### 2. 報告の再利用

情3と軽3のとおり。surfaceCheckAll を再実行する経路は、報告がないときの代替（従来どおりの実行）だけである。

### 3. 既知の差の分類

情2のとおり。各 entry（`generated-record-property` の 5 定義）も同じ分類と件数の固定を受け、`hole-order` の変異は既知の差を除いた残りが壊した一件だけであることと、既知の差の件数が manifest と一致することを要求する。

### 4. `formal_interval.py`

拒否のケースは保存した `surfaceCheck.log` を `preparation_gaps` で読み直し、要約の `preparationRejected` との一致と終了2を要求する。ケース名は正規表現で縛ってから経路に使う。分類の確かめは十分だが、件数の固定がない（中1）。

### 5. 変異の検査

情1と軽1のとおり。

### 6. 台本の品質

足したコメントは日本語で、理由（既知の差で 1 で終わる、全件の入口が長い、一般の文で原因を区別できない、など）を書いている。台本と manifest に手元の絶対パスはない。`test_policy.py` は 32 件で終了0だった。`remaining_counts` は `check_named.py` の中では使われなくなったが、`check_batch3.py` が使うので残してよい。

## 処置の確認

2026-11-09。担当の報告の「RV-L70.freg の処置」の節と、作業木の未コミットの差分（前回の四つに `check_failure.py`・`batch3/manifest.json`・`scripts/check/test_policy.py` が加わった七つのファイル）を読んだ。`python3 -B scripts/check/test_policy.py` を再び実行した（32 件、終了0、33 秒）。担当の `weaken2.py`・`weaken_budget.py` と全比較は再実行していない。作業木は変えていない。

**結論: 可。** 処置の対象の中1〜中3・軽1・軽3 は全て閉じた。軽2・情4 は取りまとめが記録と本物の実行で扱う。

| 所見 | 閉じたか | 根拠 |
|---|---|---|
| 中1 範囲の予算の拒否を固定していない | 閉じた | `formal_interval.py` の定数 `EXPECTED_BUDGET_REJECTIONS`（2ケース、原因 `Scope.ScopeError.At`）と、読み直した拒否の集合（ケース名→原因）の完全一致を要求する。比べていたケースが拒否へ移っても、拒否されていたケースが比べるケースに戻っても失敗する。義務 R30 で表を空にすることもコメントにある。比べたケースが0件のまま受け入れることは、取りまとめが F-REG の記録に書く |
| 中2 batch3 の拒否を固定していない | 閉じた | `batch3/manifest.json` の k3 に `preparationRejected: {"scope": ["Scope.ScopeError.At"]}` を置いた。`check_batch3.py` は、単独の入口の拒否（入力→原因）と組の期待（欄がなければ0件）の完全一致に加え、全件の入口の `classified["causes"]` と期待の原因の和の一致も要求する。`TOOLS` は surfaceCheck を surfaceCheckAll の前に回すので、この照合の時点で単独の結果は揃っている |
| 中3 restViolation の経路 | 閉じた | `check_failure.py` が `restViolationPath` `[0, 0, 1, 0, 0]` を照合して結果にも残す。`[0, 0, 1]` が定義0の本体、続く `[0, 0]` が return の呼び出しという読み方は、`checkPreparedProgram` と `definitionDetails` の番号の付け方と合う。値は担当が実際の値を記録したもので、経路を変えた写しで失敗することを `weaken2.py` で確かめている（本書では再実行していない） |
| 軽1 変異が準備の拒否になると照合を飛ばす | 閉じた | 三つの変異の検査の全てで `require(report is not None, ...)` とし、壊した入力が準備の段の拒否になったら失敗にする |
| 軽3 再利用する報告の終了状態 | 閉じた | `full_report` のコメントに、終了状態を照らさない理由と、入口ごとに中身で判定する欄（desugarDiff・builtinCheck・surfaceCheckAll）、報告を書かずに失敗した場合の落ち方を書いた。修正案のとおりである |
| 軽2・情4 | 範囲外（取りまとめが扱う） | — |

範囲外の変更の `scripts/check/test_policy.py` は自己検査を弱めていない。

- この自己検査は、check_batch3 を check.sh の方針の中で偽の入口に対して流し、実行の順序と失敗の伝わり方を確かめるものである。
- 中2 の後、本物の batch3 の manifest は k3 の拒否を要求する。偽の k3 が成功を返し続けると自己検査は manifest と食い違って失敗するので、偽の入口を本物と同じ形に揃えた。単独は終了2と分類の表の文、全件は終了2と `preparationErrors`・`preparationFailure` 1・残りの件数0 である。
- 偽の k3 の件数は、`remaining_counts` が求める残り（surfaceChecks 5 − scope の 5 = 0）と、`classified_all` が求める末尾の照合（0, 0）に一致する。k3 の他の入口と、ほかの組の偽の入口は変わっていない。`POLICY_FAIL_PROFILE` による失敗の注入も、拒否の分岐より前に判定されるので残っている。
- 写すファイルへの `formal/tests/test_range_sources.py` の追加は、`run_surface` が分類の表を読むのに要るだけである。
- 偽の入口が拒否の経路を通ることで、自己検査は新しい分岐（`run_surface` と manifest の照合）も通すようになった。一方、分類の外の拒否を断ることは自己検査では確かめず、担当の `weaken2.py` の確かめに頼る。照合の意味の検査は自己検査の役目ではないので、弱めたことにはならない。

## 取りまとめの判断と処置

- 中1〜中3・軽1・軽3 は、実装の担当が処置し、上の「処置の確認」で閉じた（担当の報告は [../l70/freg/scripts-report.md](../l70/freg/scripts-report.md) の「RV-L70.freg の処置」）。
- 軽2（今の台本がそのままの形で最後まで流れていない、区間の manifest の出力）: 取りまとめが区間の manifest の古い出力を除いた。そのうえで、コミット `f9b022951` の台本を run-23827 に対して本物で一度流し、終了0を得た（設計者の指示。[../l70/freg/results.md](../l70/freg/results.md)）。
- 情4（全比較の受け入れの条件）: `check-formal.sh` の終了状態は変えない。L70 の F-REG の受け入れの条件と R 段への申し送りは [../l70/freg/results.md](../l70/freg/results.md) の「計画からのずれと申し送り」に書いた。
