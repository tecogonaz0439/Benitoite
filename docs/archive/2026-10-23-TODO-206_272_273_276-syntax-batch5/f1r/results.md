# F1R 性能比較の probe の互換性と欠測時の継続

2026-10-23、F1R実装担当。作業範囲と検査は、依頼で指定されたF1Rの四項目に従った。

## 基準と変更範囲

- B_WORK・HEAD: `52fc6f0a244f0f4dd8dcd4a3bf6fe7c23f5051c7`。ブランチは `mod011/F1R`。開始時の追跡対象に差分はなかった。
- `tools/bench/compare/` の `build.py`・`timing_probe.rs` で、各状態のarchiveの公開parse宣言から保留列の引数の有無を判定し、cfgで呼び出しを切り替えた。判定と元ソースのハッシュをprobeのキャッシュの鍵と `probe_api` に含めた。
- `run.py`・`features.py` で、probeのビルド結果を `capabilities.timing_probe` へ記録し、使えない状態をprobe専用の点から除外する。理由を `skipped` に残し、CLIの比較を続ける。alloc-statsのprobeだけが使えない場合も、その確保量だけを欠測として記録する。
- `test_compare.py` に比較継続の回帰テストを追加し、既存の実コンパイルテストを機能判定に追随させた。READMEにAPIの判定・除外・欠測・自己検査の契約を記した。処理系の `crates/`・言語の規則・Leanは変更していない。

## 検査と修正前の再現

コマンドはリポジトリの根から実行した。rtk経由のものも、表には実体のコマンドを書く。独立に時間を測っていない実行は未計測とする。

| コマンド・対象 | 終了状態 | 外側の時間・結果 |
|---|---:|---|
| `python3 -m unittest discover -s tools/bench/compare -p test_compare.py -k test_both_revisions_compile_through_the_common_builder`（修正前） | 1 | 未計測。旧版 `c31e64b03d2810343e1779926bea4ebc958b6164` のprobeに保留列の引数を渡すためコンパイルできず、既存テストが失敗 |
| 同じ実コンパイルテスト（修正後） | 0 | 未計測。unittest表示3.796秒。旧版と現在のHEADのprobeをビルドし、独立IR・グラフ・縮小の出力を検査 |
| B_WORKの `build.py`・`features.py`・`run.py` と追加テストを `target/bench/f1r-regression/` へ写し、`python3 -m unittest discover -s target/bench/f1r-regression -p test_compare.py -k UnavailableProbeTests` | 1 | 0.668秒。片側・両側のprobeのコンパイル失敗で、どちらも `bridge-shared-8: probe unavailable` により比較が停止 |
| `python3 -m unittest discover -s tools/bench/compare -p test_compare.py -k UnavailableProbeTests`（修正後） | 0 | 未計測。unittest表示0.862秒。片側・両側の欠測、alloc-statsだけの欠測、CLIの継続、節の保存、目標の判定不能を確認 |
| `PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'` | 0 | 2.888秒。37件すべて成功。実コンパイル・比較継続の両テストを含む |
| Pythonで `ast.parse` を `tools/bench/compare/*.py`・`scenarios/*.py` へ適用 | 0 | 0.015秒。20ファイル成功 |
| `scripts/check.sh --level work --base 52fc6f0a244f0f4dd8dcd4a3bf6fe7c23f5051c7 --dry-run` | 0 | 未計測。python_syntax・migrate_selftestsを自動選択。Rustのlib全件は選択されなかった |
| 同じ指定から `--dry-run` を外したwork本実行 | 0 | 7.962秒。Python構文検査、source-migrate自己検査6件、try-actions inventory exampleのビルド、try-actions自己検査10件が成功 |
| 下記のshort比較 | 0 | 35.037秒。全9節・66点、両状態を合わせて132点で各5標本、計660標本を取得 |
| README・本記録の相対リンク／フェンス／末尾空白、測定記録の全JSON／パス置換／道具のハッシュ／全9節、変更範囲のPython確認 | 0 | 0.022秒。すべて成功。測定時の道具のハッシュは最終のソースと一致 |
| `git diff --check` | 0 | 未計測。差分の空白の誤りなし |

追加テストの準備では、代用した外部プロセスの応答が環境取得にも適用される問題と、archiveのfixtureの不足による失敗が生じた。対象外のプロセスを本物へ通し、シナリオが読むhandlersのfixtureを追加して修正した。本体の期待値を変更せず、修正前の比較道具が本来の `probe unavailable` で失敗することを、その後に確認した。

作成時の関門では、守る契約を「外部コンパイラが失敗してもCLIの標本と全節の記録を保存し、欠測を達成扱いにしない」と定めた。既存のキャッシュテストはビルド失敗の記録までで、ランナーの継続を検査していなかった。追加テストは本物のbuild・機能判定・入力選択・照合・標本採取・reportを接続し、外部のgit・コンパイラ・実行プロセスだけを代用する。buildの呼び出しは既存のcache引数で一時領域へ向けた。テスト用の本番APIやフラグは追加していない。道具の本体は追加33行・削除4行、テストは追加91行・削除1行であり、既存テストは削除していない。

## shortの記録

D41と依頼に従い、指定のコマンドを一度実行した。他の重い処理とは同時に走らせていない。

```sh
python3 tools/bench/compare/run.py --tier short \
  --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a \
  --state after=52fc6f0a244f0f4dd8dcd4a3bf6fe7c23f5051c7 \
  --name batch5-f1
```

記録は [測定結果](../../../../tools/bench/results/2026-10-23-52fc6f0a-batch5-f1/results.md) と [HTML](../../../../tools/bench/results/2026-10-23-52fc6f0a-batch5-f1/results.html)、同じディレクトリのmanifest・verification・section・全標本に保存した。記録中の手元の絶対パスは `<repo>` に置き換えた。値・標本数・ハッシュは変更していない。

- beforeの `parser_pending` はfalse、afterはtrue。両側のprobeがビルドでき、`capabilities.timing_probe.supported` は両側でtrue、`skipped` は空である。
- 16.2〜16.9とruntimeの全9節で出力を照合し、各点の各状態で5標本を取得した。bridge-shared-8は両側で変換の各時間も5標本ずつ取得した。
- shortの判定は達成10件・判定不能56件・退行の疑い0件である。判定不能を達成として数えず、`alerts.json` に残した。全点の標本数は揃っており、欠測による停止はない。この測定だけから性能の改善や不変は断定しない。
- 開始時に存在した失敗時の未追跡記録は上書きせず、`target/bench/f1r-validation/failed-batch5-f1/` へ退避した。

## 計画からのずれと申し送り

work F1Rの節はないため、依頼本文の検査指定を用いた。workの自動分類が選んだ移行道具の自己検査とexampleビルドも実行した。shortは見込みの2〜3分より短く完了した。追加の長い測定は実施していない。

F1Rが受け持つ未解決の失敗や設計判断の保留はない。取りまとめはこの差分とshortの判定不能の記録をレビューし、受け入れを判断する。gitの変更操作・コミット・取り込み・公開操作、privateの参照、担当外の文書の編集は行っていない。
