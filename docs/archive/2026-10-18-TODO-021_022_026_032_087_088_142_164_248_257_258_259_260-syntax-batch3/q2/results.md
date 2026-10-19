# Q2 の結果

基準のコミット: `82f6f47bb3e2469f51b8affb07f9dbdef4bee27c`（開始時のHEADとsan_benito）。依頼本文をQ2の範囲とし、plan.mdのK性能・改造末の本測定、design.md第16節、R187を引き継いだ。コミット、docs/todo/、crates/、formal/の変更はしていない。本測定は実施していない。

## 作ったものとQ1からの移し替え

`tools/bench/batch3/` を削除し、下書きを確認して `tools/bench/compare/` へ移した。Q1の生成・照合・交互の標本・空main・段別の公開API補助・別実行のRSS/alloc・線形HTMLと自己検査のassertを引き継いだ。旧suiteによる短縮案の選択は、改造側のJSONが名指しする点へ置き換えた。Q1の93入力は、最終の試走manifestでも全状態の全ソースのSHA-256が一致した。

状態は任意の数の `--state 名前=リビジョン`、ビルドは完全ID・構成・rustc/Cargo・元のlockのハッシュを鍵にした共通キャッシュとした。Q1の4ビルドの元の証拠へ、保存されていた環境とlockの証拠からCargo版・lockハッシュを補い、ハッシュ照合して取り込んだ。以後の試走では `target/bench/builds/<完全ID>-default/` を使い回した。元のlockと依存の一致は保持する。

functions/constraints/shrinking/builders/runtimeの5族へ分け、機能は小さいcheckで探る。縮小は旧APIの別入力を使い、構築器のない状態は除外理由を残す。公開APIで補助をビルドできなければ段別時間を未取得とする。今回の4状態では補助はすべてビルドできた。0.0.9の169目標と256観察点は `bench-targets.json` に置いた。

short（2状態・代表62入力・5標本）、targets（JSONの点・10標本）、full（全点・10標本・全点のRSS/alloc）を実装した。quickは別の試走指定とした。shortは出力照合から15分の見込みを検査し、超過なら標本採取前に止まる。fullには確認指定を要求する。目標の式は差し引き・比・伸び・退行幅・出力の不変条件を扱い、ぶれ以下の差から比を作らない。

compare/README.md、親README、benchmarkスキル、AGENTS.mdの一行、計画の雛形、07-02を更新した。python_syntaxの実対象とdry-runの説明にcompare/scenariosも加えた。

## 検査と時間

| 検査 | 結果 | 外側の時間 |
|---|---|---:|
| `PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'` | 0、26件。決定性、全評価種別、判定不能、機能、2/4状態、キャッシュ、full確認、short超過、manifest往復、runtimeの仕事量比 | 0.92秒 |
| `PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m py_compile tools/bench/compare/*.py tools/bench/compare/scenarios/*.py` | 0。R189後のPythonも再確認 | 0.03秒 |
| 下記のquick4 | 0、101入力。Q1の93入力＋runtime 8本、CLI 670標本＋空main 670標本。目標の判定まで出力 | 86.69秒 |
| 目標なし・2状態・runtimeのみのquick | 0、8入力、CLI 32標本＋空main 32標本 | 2.072秒 |
| 目標なし・2状態のshort（runtime節→resumeで全節） | 0、62入力、CLI 565標本＋空main 565標本。15分以内 | 31.689秒 |
| 完了したquick4のruntime節の `--resume` | 0。既存節を飛ばし、標本を重複させない | runtimeの試走と同じ検証呼び出し内 |
| `scripts/check.sh --level work --base 82f6f47bb3e2469f51b8affb07f9dbdef4bee27c --only python_syntax,policy_selftest` | 同指定のdry-run後に実行。0、policy_selftest 21件。実行は一度 | 13.56秒 |
| 記録の標本数・線形SVG・目標出力・生成profile.shの `sh -n`、`git diff --check` | 0 | 1秒未満（見込みの集計と同じ呼び出し） |

Rustのテスト、scripts/check.shの全体、gc-stress、all-targetsは走らせていない。既存のassertや期待値を弱めず、ignoreも加えていない。

実行の状態と再現するコマンドは次のとおりである。ここでfinalはQ1の試走候補であり、本測定の実候補ではない。

```sh
D=docs/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3
O=6b0568a3ddcc46b0a0e64504139ce286a27fd86a
M=f0e6c71d29cbc8704093dcf5c355469ad50c4381
S=c4310604f3982f7daab323920615945c2ba3ffef
F=b90070b60c1443b755598741399d051007c30d75
# quick4
python3 tools/bench/compare/run.py --tier targets --quick \
  --state old="$O" --state map="$M" --state solve="$S" --state final="$F" \
  --targets "$D/bench-targets.json" \
  --section 16.2 --section 16.3 --section 16.4 --section 16.5 --section runtime \
  --out target/bench/q2-accepted-quick
# 別の小さい比較
python3 tools/bench/compare/run.py --tier short --quick \
  --state before="$O" --state after="$F" --section runtime \
  --out target/bench/q2-accepted-runtime
# shortを節で分け、同じ条件で完了する
python3 tools/bench/compare/run.py --tier short \
  --state before="$O" --state after="$F" --section runtime \
  --out target/bench/q2-verified-short
python3 tools/bench/compare/run.py --tier short \
  --state before="$O" --state after="$F" --resume \
  --out target/bench/q2-verified-short
# 見込みだけ。ビルドも本測定もしない
python3 tools/bench/compare/run.py --tier targets --alloc \
  --state old="$O" --state map="$M" --state solve="$S" --state final="$F" \
  --targets "$D/bench-targets.json" --estimate-from target/bench/q2-accepted-quick
python3 tools/bench/compare/run.py --tier full --confirm-full \
  --state old="$O" --state map="$M" --state solve="$S" --state final="$F" \
  --estimate-from target/bench/q2-accepted-quick
```

試走のmanifest・全標本・Markdown・HTMLは上のtarget/以下に置き、追跡しない。quick4の最初の呼び出しは `invocation-first.json`、再開は `invocation.json` に残した。shortの最終の事前見込みは130.67秒（実時間31.689秒）だった。shortの判定内訳は {'達成': 38, '判定不能': 24} だが、今回は道具の動作検証であり、性能の結論には使わない。

## 本測定の見込み

同じ4状態、10標本、RSS/allocを全対象点で取る条件である。単位は分。節の表は照合・準備・CLI/空main・段別・別実行の合計であり、ビルドと生成・報告の余裕は後に加える。族ごとの内訳も `--estimate-from` のJSONに出る。

| 節 | targets（0.0.9） | full |
|---|---:|---:|
| 16.2 | 24.90 | 48.53 |
| 16.3 | 10.62 | 10.62 |
| 16.4 | 36.83 | 234.05 |
| 16.5 | 27.59 | 27.59 |
| runtime | — | 63.76 |
| 生成・報告の余裕 | 1.00 | 1.00 |
| ビルドを使い回す場合の計 | 100.94 | 385.54 |
| 両構成4状態の初回ビルドの見込み | 9.31 | 9.31 |
| 初回ビルドを含む全体 | 110.25 | 394.85 |

targetsは約1時間50分、fullは約6時間35分。既定構成だけがキャッシュにあるなら、この中間となる。alloc構成は未実測で、既定のビルド時間と照合の時間からの未校正の見込みである。16.2〜16.5は同系列の最大quick入力からの比例、runtimeのfib/treeはR189の仕事量比で外挿する。二乗の伸び・一操作の費用・縮小予算による仕事量の上限は予測せず、CPUプロファイルと未取得の内部計数も含めない。今回の環境はRust/Cargo 1.98.1、Python 3.9.6、macOS arm64。CPU型番はsandbox内で取得できなかった。

## 計画からのずれと申し送り

R188にR187から引き継ぐ点・段と見込みの決まり、R189にruntimeの校正を推す案として追記した。途中でmanifestのtuple/listの差による再開の不一致を直し、保存の往復と実際の再開を確認した。Cargoは呼び出し元のtoolchain/configで統一するため根で実行する。極小のruntime入力からの外挿が約78時間という過大な見込みになったためR189で直し、古くなったquick・見込み・Python検査をやり直した。shortの入力・計時経路はR189で変えていない。

後の改造では開始版と候補を任意の名前で渡し、性能に関わる改造の末はshortを使う。新しい族はcasesとshort_pointを宣言して登録し、約束する目標は改造側のJSONへ置く。fullを通常の改造に一律には割り当てない。

本測定は取りまとめ側で実候補の完全IDへfinalを置き換え、targetsと本改造のbench-targets.jsonを使う。静かな計算機の条件と見込みへの了承を得てから開始する。未取得はallocの実測、CPUプロファイル、Fail正規化の内部訪問節数、縮小器内部の生成/比較回数である。maxShrinkWorkの推奨値の確定と、design第16節の原因の分解・最終の受け入れは取りまとめに残る。目標未達・判定不能を期待値や予算の緩和で達成扱いにしない。
