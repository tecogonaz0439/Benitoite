# M1の実装結果

2026-10-20。作業ブランチは`mod010/M1`。基準B_WORKとHEADは`ac3a434f9e6996839318cc586085a4b809f3bcbb`である。コミットは作成していない。処理系のソース、formal/、docs/todo/は変更していない。

## 変更

- 共通Caseへ状態別の期待拒否・対象状態・probeの実行口・指標・バイナリ入力を加えた。buildersのrequires/importはbuilder手法だけへ移した。
- buildersへrepeat/single-all/prepared/copy-onlyを追加した。R/2Rは同一ソースの実行引数とし、位置ごとに変えた内容と保持したsnapshotを独立期待値で照合する。
- patterns/codegen/bridge/external-testsの四族を登録した。成功する型検査の連鎖250/500/900と算術400行も加えた。全体918 Caseのうち、目標JSONの166点・55目標がCase/metricへ解決される。
- 共通probeへ脱糖・下位化・コード生成・VM実行・公開IR検査・全Let数・双方向変換を接続した。各版自身の非公開変換の抽出と呼び出しの接続を共通buildで行い、元ソースと接続のhashを記録する。外部の実行用コンパイル回数は、計時と別の統計実行で経路ごとのキー数と照合する。
- 時間・確保量・RSSを別実行にし、確保量にも標本数を確保した。時間差の比率は非正・2ms未満・IQR和以下を判定不能とする。欠測、単位の不一致、標本不足、部分的なinvariantの証拠を成功扱いしない。段と計数の標本をMarkdownと単位ごとの線形HTMLにも出す。
- READMEと現行設計07-02を更新した。目標JSONの内容と閾値は不変であり、SHA-256は`88f5fcf22f57dcc273f4870ff0efd0b3c7fceaea4ce29a77d2c760bd8b0696ac`である。

## 検査

作業末に計画のworkの指定をdry-runで確認した。選択は`python_syntax,migrate_selftests`で、終了0である。以下の作業末の検査は各一度実行した。完全な出力と外側の時間は同じディレクトリのwork/scenarios/compare/fmtのlogとjsonにも保存した。

| コマンド | 終了 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `scripts/check.sh --level work --base ac3a434f9e6996839318cc586085a4b809f3bcbb --only python_syntax,migrate_selftests` | 0 | 15.585秒 | Python構文と移行道具の自己検査各6件。 |
| `python3 -B tools/bench/compare/test_scenarios.py` | 0 | 0.814秒 | 12件成功。 |
| `python3 -B tools/bench/compare/test_compare.py` | 0 | 182.730秒 | 23件成功。共通build経由で両状態のprobeをコンパイル。 |
| `rustfmt --check --edition 2024 tools/bench/compare/timing_probe.rs` | 0 | 0.039秒 | probeのRustソースの書式。 |

処理系を変更しないM1の割り当てに従い、Rustのlib全件・clippy・全統合・GCの特殊構成・形式化の全比較は追加していない。workが指定するtry_actions_inventoryのビルドは実行した。共通buildが作ったbefore/afterのコンパイル記録とソースhashは[probe-builds.json](probe-builds.json)に保存した。quick・本測定とprobeの実行は行っていない。

途中は追加した契約だけのPythonテスト（新族2件、比較契約6件）を実行し、成功した。通常のrelease CLIによる小さい入力の正しさの確認も行った。Listの表示のimport、レコードの改行、testのJSON指定、docExampleの件数の誤りを確認し、入力生成と検証器を直した。再確認では三種類のn=0/4・snapshot4回、穴1個のdirect/indirect、patternsの小さい点、外部の通常/補助/二キー/複数入口/doc/stateful等が成功した。これらは計時標本を採取しない局所検査であり、指定点の両状態の測定を代用しない。

開始時の道具の関数を読み込み、非builder対照がbuildersを要求する誤りと、2ms未満の時間差を比率へ使う誤りを再現した。既存assertの削除、期待値の緩和、ignoreの追加はない。既存の比較器テストも作業末にすべて通った。行数の増減は、測定器のコードが+1096/-113行、テストが+136/-0行である（文書と結果記録を除く）。

## 計画の具体化と申し送り

R207に非公開変換の観測方法、R208に準備・統計・IQRと観察点の費用を記した。copy-onlyは補助関数内のnewと一括追加も含む観察点として報告し、追記のないcopyだけの時間とは呼ばない。符号付きdifference単体は負の改善量を保ち、比率の非正な増分と区別する。主定理・公理・Builtins.Assumptions・公開の言語APIは変更していない。

取りまとめはV1の後にafterの完全IDを固定し直す。quickでn=1024を含む指定点の両状態の構文・型・実行、全経路と所要時間を確認し、必要なら本測定前にR/2Rだけを一括更新する。開始版の制限を上げず、指定点が実行不能ならそのまま相談する。本測定は静かな計算機の合図の後に行う。M1では性能目標の達成を判断していない。
