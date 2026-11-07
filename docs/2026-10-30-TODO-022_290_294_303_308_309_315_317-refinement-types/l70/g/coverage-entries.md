# 担当 coverage-entries の記録（網羅性の表示と4入口の切替）

時刻は JST。開始 2026-11-07 07:17、終了 2026-11-07 07:27。git の状態は変えていない。`scripts/check.sh`・`check-formal.sh` は実行していない。以下の `<tmp>` は群 G の一時領域、`<scratch>` は取りまとめの作業用の一時領域を表す。

## 変えたファイル

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Release/Refinement/CoverageShow.lean`（新規） | 新しい表層の網羅性の反例 `CoverageWitness`（`Release.Refinement`）の表示。旧 `Release.CoverageShow` と同じ規則で書いた |
| `formal/Benitoite.lean` | 上のモジュールの import を1行足した |
| `formal/Benitoite/Exchange/Convert.lean` | `desugar`・`desugarAccessor` の `noncomputable` を外した（本文は同じ） |
| `formal/CoverageDiff/Main.lean` | 新しい網羅性の判定・表示へ切替。燃料の監査を初期領域の問いに揃えた。`DataTypeInfo` の構成子の欄を埋める `RawDecl.info` を足した |
| `formal/CoverageProgramDiff/Main.lean` | 新しい網羅性の判定・表示へ切替。束縛の燃料と反例を `Coverage.domainReport` から読む |
| `formal/DesugarDiff/Main.lean` | 変更なし（`Convert.desugar` が実行コードを持ったので、そのまま通る） |
| `formal/BuiltinCheck/Main.lean` | 操作の効果の範囲の位置を新しい `RangeIx` で書いた（`.rvar 0` と `.top`） |

## 足した宣言

`Benitoite.Release.Refinement` の `CoverageDisplay`・`CoverageTypeDisplay`・`CoverageWitness.characterValue`・`CoverageWitness.showCharacter`・`CoverageWitness.showWithTypes`・`showWitnessesWithTypes`・`CoverageWitness.show`・`showWitnesses`。例は `CoverageShowExamples` に置いた（旧と同じ表示の例、文字の反例を判定から取って元の分岐に照合しないことの確認、入れ子の構成子の例。入れ子の例の宣言の表 `choiceProgram` は新しい `CoverageExamples.program` が構成子を持たないので足した）。`CoverageDiff.RawDecl.info`。

## 局所検査

| コマンド | 終了 | 所要 |
|---|---|---|
| `lake env lean -M 12288` で `Exchange/Convert.lean`・`Refinement/CoverageShow.lean`・`BuiltinCheck/Main.lean`・`CoverageDiff/Main.lean`・`CoverageProgramDiff/Main.lean`（単独の Lean の順番の下） | 各0、警告0 | 各約1〜2秒 |
| 既定ビルド 1回目（07:23:05〜07:23:14、共有ロック下） | 1 | 9秒。`CoverageDiff.Main`（`DataTypeInfo` の欄の数）と `CoverageProgramDiff.Main`（`Arm` の曖昧さ）を直した。ほかの失敗は別の担当の `Exchange.CheckInput` |
| 既定ビルド 2回目（07:23:58〜07:24:01、共有ロック下） | 1 | 3秒。失敗は別の担当の `Exchange.CheckInput` だけ。`CoverageShow` と4入口の実行ファイル（`coverageDiff`・`coverageProgramDiff`・`desugarDiff`・`builtinCheck`）はリンクまで通った |

固定入力の候補（`<tmp>/fixture-candidates/`、新版。入力は書き換えていない。実行の前後で SHA-256 が一致）で各入口を一度ずつ実行した。

| 入口 | 入力 | 結果 | 終了 |
|---|---|---|---|
| `coverageDiff` | `test_range_exchange-fixtures-coverage.json`（版8、1件。SHA-256 `01f95cd9…6822`） | cases=1 matched=1 mismatched=0 fuelExhausted=0 | 0 |
| `desugarDiff` | `test_range_exchange-fixtures-corpus.json`（版16、2入力。SHA-256 `1d726bb9…f905`） | golden の programs matched=2、functions matched=14、不一致0、nonTopRanges=36 | 0 |
| `coverageProgramDiff`（参考） | `…-coverage-program.json` と `…-builtins.json` | inputs=2 matches=1 matched=1 mismatched=0 fuelExhausted=0 | 0 |
| `builtinCheck`（参考） | `…-corpus.json` と `…-builtins.json` | inputs=2、prim 6件すべて変換、要約の比較16件の不一致0、未収束0、誤り0 | 0 |

報告の JSON は `<scratch>/coverage-entries-runs/`（4ファイル計12,344バイト）に置いた。SHA-256 は coverage `56323850…3875`、desugar `c98beb8e…a1`、coverage-program `92598b38…7d19`、builtin `9a64564e…70b9`。

依存の照合: 各入口の `main` から、型と値（`partial` の実体 `_unsafe_rec` を含む）に現れる定数の閉包を辿る台本（`<scratch>/coverage-entries-deps/deps-*.lean`、入口ごとに `lake env lean -M 12288`、各約1秒、最大常駐量約1.94 GB）を実行した。閉包に現れる `Benitoite.Release` 直下（`Refinement` を除く）のモジュールは次のとおりで、すべて残す旧 Release の一覧（[retained-release.md](retained-release.md)）にある共有の定義である。旧 Surface・旧 `CoverageShow`・旧の判定（旧 `checkMatch`・旧の型付け）は現れない。

| 入口 | 閉包の定数 | 現れる旧 Release のモジュール（宣言の数） |
|---|---|---|
| `coverageDiff` | 9,252 | Atom 21、Coverage 1（`CoverageView`）、Order.* 152、Syntax 46、Types 38 |
| `coverageProgramDiff` | 9,508 | 同上 |
| `desugarDiff` | 10,428 | Atom 21、Coverage 2（`CoverageView`・`closedView`）、Order.* 152、Subst 10、Syntax 75、Types 47 |
| `builtinCheck` | 9,103 | Atom 21、BuiltinTable 69、Coverage 1、Effect 1（`Eff.empty`）、Order.* 152、Syntax 4、Types 65、Typing 1（`ErrKind`） |

出力の SHA-256 は CoverageDiff `739b8aff…adcf`、CoverageProgramDiff `4c51e747…aaba`、DesugarDiff `a3d5c77c…36d3`、BuiltinCheck `3143662f…42a2`（各約2.5〜2.9 KB）。

## 出力の JSON の欄

4入口とも欄の名前と意味を変えていない。`coverageDiff` の `fuel` の各欄（`matchChecks`・`coveringSingletons`・`coveringPrefixes`・`overlaps`・`irrefutable`）は、新しい判定の実際の手順（初期領域 `initialDomain` の問いと、初期領域で制限した候補 `InitialDomain.target`）と同じ引数で数える。篩のない型では初期領域が `.plain` なので旧と同じ呼び出しになる。`coverageProgramDiff` の束縛の `uncovered` も、束縛の判定 `irrefutableWithView` と同じ初期領域の問いの反例である。

## 止めずに進めた変更

| 理由・反例 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 規範の脱糖が実行コードを持つようになり、`Exchange.desugar`・`desugarAccessor` の `noncomputable` は不要になった。残すと `desugarDiff` がコンパイルできない | `noncomputable` を外した。本文と型は変えない | 入口側の複製 | 公開の関数の契約は変わらない |
| 新しい網羅性の判定は初期領域の問いを使い、旧の監査の呼び出し（`usefulReportWithView [t] rows [q]`）と篩付きの型で引数が異なる | 監査を `domainReport`・`domainAlternativeReport`・`InitialDomain.target` で数える。候補が初期領域に値を持たないときは、判定と同じく覆う選択肢を探さない | 旧の呼び出しのまま数える（篩付きの型で燃料切れの記録が判定とずれる） | 篩のない型では旧と同じ呼び出し・同じ件数 |

型付け・Step の規則・前段の固定署名には触れていない。

## 残りと申し送り

- `Exchange.coverageView`（`Exchange/Version.lean`）の戻り値の型は旧 `Benitoite.Release.CoverageView` のままである（`DataName → Bool` の略記で、新しい `Refinement.CoverageView` と定義上同じなので入口はそのまま渡せる）。旧 `Release.Coverage` は残す共有の定義なので削除の妨げにはならないが、`Version.lean` の担当が新しい略記へ替えてよい。
- `CoverageDiff.readTy` は旧と同じく篩付きの型（`refined`）を読まない。処理系の網羅性の書き出し（版8）が篩付きの照合の型を出すなら、読み取りを足す必要がある。`coverageProgramDiff` は `Exchange.Ty.toRelease` を使うので篩付きの型を読む。
- 旧 `formal/Benitoite/Release/CoverageShow.lean` を参照する残りは、根の `Benitoite.lean` の import、`formal/README.md` のモジュールの表、設計書 02-05 の `CoverageWitness.showWithTypes` の段落である。削除と写しの担当（L70.44・L70.45）が直す。
- `Exchange/Builtins.lean` に足してほしい公開の関数はない。`BuiltinCheck` は既存の `mkBuiltins`・`toBuiltinDataDecl`・`DataEntry.toMaterial`・`constructorDecl` と、共有の `Release.dataSummaries`・`summariesConverged`・`BoundSummary` だけを読む。
- 既定ビルドの失敗は別の担当の `Exchange.CheckInput` だけであった（2回目のビルドの時点）。
