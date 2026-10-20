# Z8の修正結果

2026-10-21。B_WORKと開始時のHEADは`270a717c670d9640d4c08f10bc400afa6e3fcef2`（`git merge-base HEAD san_benito`と一致）。比較はbefore=`c31e64b03d2810343e1779926bea4ebc958b6164`、after=`270a717c670d9640d4c08f10bc400afa6e3fcef2`へ固定した。コミットとdocs/todo/の変更は行っていない。

## 原因と修正

- 最初のshort quickを25.882秒・終了1で再現した。失敗は`codegen-irenv-empty/before`の`ir_check`。独立IRの宣言型表が空であり、両版が要求するmainのSchemeを欠いていた。計時前に宣言型を登録した。追加した実行テストでは、emptyとLet 4個が両状態とも修正前に同じ理由で失敗し、修正後に成功した。
- 共通probe decoderの例外へCase ID・状態・要求指標を加えた。検証と段別観測の両入口で、終了異常・欠測・不正JSONの退行テストを加え、修正前の失敗と修正後の成功を確認した。
- 最初の修正後のshortは66.917秒・終了0、targets --allocは196.543秒・終了1だった。追加の停止は`property-seven-24-0-0-all-ok/before`。段別観測が専用validatorのCaseを空のexpected_stdoutと比べていた。両状態の実probe出力は終了0で、検証済みCLI出力と完全に一致した。入力のvariantを段別観測へ引き継ぎ、既存validateを共用して直した。正出力の受理とmessageを壊した出力の拒否を実probeの境界で確かめた。
- 共通buildの既存テストを拡張し、short quickの独立IR・グラフ全6 Caseを対象状態ごとに計10回実行する。after専用のnodesはその指定を守る。縮小器の入力は各版の実際の機能の探りで選ぶ。旧APIを強制した途中の局所検査は、両版で型検査に拒否されたため入力選択を修正した。
- 変更はcompareのprobe・decode・validation・runner・自己検査・READMEと、plan・decisions・本記録。測定器コードは+42/-10行、テストは+44/-1行（削除はコメントの差替え）。既存assertの削除・期待値の緩和・ignoreの追加はない。

処理系の不具合は見つかっていない。設計者への仕様の相談と、beforeの指標を欠測にする扱いは不要である。目標JSON・入力のCase・閾値は変更していない。`bench-targets.json`のSHA-256は`88f5fcf22f57dcc273f4870ff0efd0b3c7fceaea4ce29a77d2c760bd8b0696ac`である。

## 作業末の検査

以下を各一度実行し、すべて終了0だった。workの前に同じ基準・名指しのdry-runを通した。Cargoコマンドは未加工のログを残すため`rtk proxy`を通した。

| コマンド | 終了 | 外側の時間 |
|---|---:|---:|
| `python3 -B tools/bench/compare/test_compare.py` | 0 | 1.280秒 |
| `python3 -B tools/bench/compare/test_scenarios.py` | 0 | 0.711秒 |
| `rustfmt --edition 2024 --check tools/bench/compare/timing_probe.rs` | 0 | 0.041秒 |
| `scripts/check.sh --level work --base 270a717c670d9640d4c08f10bc400afa6e3fcef2 --only python_syntax,migrate_selftests --dry-run` | 0 | 0.010秒 |
| `scripts/check.sh --level work --base 270a717c670d9640d4c08f10bc400afa6e3fcef2 --only python_syntax,migrate_selftests` | 0 | 9.050秒 |
| `rtk proxy cargo test -p benitoite --lib` | 0 | 89.305秒 |
| `rtk proxy cargo test -p benitoite --test verify` | 0 | 75.349秒 |
| `rtk proxy cargo clippy --all-targets` | 0 | 5.826秒 |
| `rtk proxy cargo fmt --check` | 0 | 2.310秒 |

比較器24件、シナリオ12件、lib 1252件成功・失敗0件（既存のignored 21件）、verify 3件成功。workはPython構文とsource-migrate/try-actions-migrateの自己検査各6件を通した。全体・gc-stress・全統合・formalの検査は追加していない。

途中は`test_compare.py CommonProbeCompilationTests`、`SyntaxBatch4Contracts.test_probe_failures_identify_case_state_and_metrics`、その組み合わせ、および`CommonProbeCompilationTests SyntaxBatch4Contracts`だけで退行を確認した。途中の局所テストの外側時間は未計測であり、ログ内のunittestの時間と区別する。初回の失敗と修正後の結果は`regression-before.log`・`context-before.log`・`regression-after.log`・`shrinking-before.log`・`shrinking-after.log`・`shrinking-after-fixed.log`へ残した。

## 最終コードの試走と本測定の見込み

追加のrunner変更で古くなった試走だけを新規にやり直した。各試走の全9節が出力照合と標本採取を完了した。過去の標本を合算せず、以下の最終試走から`--estimate-from`で見積もった。quickは本測定でも性能目標の合否判定でもない。

| 段 | 試走の外側の時間・終了 | 本測定の標本数 | ビルド再利用時の見込み | 初回ビルド込みのモデル値 |
|---|---:|---:|---:|---:|
| short | 64.716秒・0 | 5 | 114.214秒（1分54秒） | 286.663秒（4分47秒） |
| targets --alloc | 152.622秒・0 | 10 | 46414.627秒（12時間53分35秒） | 46745.032秒（12時間59分5秒） |

試走のコマンドは次のとおりである。

```sh
python3 tools/bench/compare/run.py --quick --state before=c31e64b03d2810343e1779926bea4ebc958b6164 --state after=270a717c670d9640d4c08f10bc400afa6e3fcef2 --tier short --out target/bench/z8/short
python3 tools/bench/compare/run.py --quick --state before=c31e64b03d2810343e1779926bea4ebc958b6164 --state after=270a717c670d9640d4c08f10bc400afa6e3fcef2 --tier targets --out target/bench/z8/targets --targets docs/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/bench-targets.json --alloc
python3 tools/bench/compare/run.py --state before=c31e64b03d2810343e1779926bea4ebc958b6164 --state after=270a717c670d9640d4c08f10bc400afa6e3fcef2 --tier short --estimate-from target/bench/z8/short
python3 tools/bench/compare/run.py --state before=c31e64b03d2810343e1779926bea4ebc958b6164 --state after=270a717c670d9640d4c08f10bc400afa6e3fcef2 --tier targets --targets docs/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/bench-targets.json --alloc --estimate-from target/bench/z8/targets
```

| 節 | shortの本測定の費用（秒） | targetsの本測定の費用（秒） |
|---|---:|---:|
| 16.2 | 13.210 | — |
| 16.3 | 9.617 | — |
| 16.4 | 11.577 | — |
| 16.5 | 6.031 | 38078.371 |
| runtime | 3.319 | — |
| 16.6 | 4.533 | 840.967 |
| 16.7 | 5.314 | 7300.898 |
| 16.8 | 0.262 | 8.834 |
| 16.9 | 0.353 | 125.558 |

上の節別費用にはビルドと共通の60秒の余裕を含めない。初回ビルドのモデル値は保存されたdefault 172.449秒と、targetsではalloc-stats 157.956秒も加える。最終試走はビルドを再利用した。両段のmissing_casesは空であり、targetsの確保量も試走で校正した。shortはallocを指定していない。

見込みは最大の対応するquick点から入力サイズ・反復数・標本数へ外挿する既存モデルである。プロセス起動等を含む外側時間にも仕事量比を掛けるため、構築器の入力サイズ4から1024への外挿では固定費も拡大する。targetsの大半は16.5と16.7である。12時間台という値は本測定の実時間や上限ではない。二乗・指数の伸び、予算依存の仕事量、CPUプロファイルと未取得の内部計数はこの値で確定しない。

試走のmanifest・全標本・HTML・呼び出しと、見込みJSON・検査ログ・外側時間JSONは`target/bench/z8/`へ保存した。初回成功・失敗の試走は`short-first/`・`targets-first/`、最終成功は`short/`・`targets/`である。最終試走の生成器とprobeのhashが現在のソースと一致すること、両状態の完全IDと全9節の記録を確認した。

## 計画からのずれと申し送り

R217は宣言型と失敗の識別、R218はZ8の検査と固定した状態、R219はtargetsで追加判明した専用validatorの接続と試走のやり直しである。planへZ8の検査・試走を追加した。Rustのprobeを変えたため、依頼冒頭のlib・関係する統合・clippy・fmtも作業末に補った。

取りまとめへは両試走の成功と、本測定の長い見込みを渡す。本測定の進め方と時間枠は設計者の了承を得て決める。quickの数値で目標達成を判断せず、反復数・閾値・開始版は維持した。正式な候補を更新する場合は、その完全IDで改めて試走と見込みを固定する。
