# M01 の結果

2026-10-24。実装担当分を完了した。最初の quick/short、独立レビュー、受け入れは計画どおり取りまとめへ渡す。

## 基準

- B_WORK: `a7a6fe88c8d9213227eecbaee22f1b086ceee236`。着手時の HEAD と一致し、ブランチは `mod012/M01`、作業ツリーに差分はなかった。
- 入力の受理確認に使った開始版 B0: `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8`。現在の版は上記 B_WORK の archive から共通の比較ビルドで作った。処理系のソースは変更していない。
- `private/` とそこを指すスキルのリンクは読んでいない。git の変更操作、docs/todo の編集、版上げ、性能の標本採取はしていない。

## 実行した検査

コマンドはリポジトリの根から実行した。実際のシェル呼び出しには `rtk proxy` を付けた。再検査と work では `/usr/bin/time -p` で外側の時間を測った。

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `python3 -B -m unittest discover -s tools/bench/compare -p 'test_*.py'` | 1。39テストを実行し、新設の実 CLI 検査で HTTP の6入力×2状態が E0321。ほかのテストは成功 | 未計測。unittest の報告は81.961秒（HEAD 用の初回ビルドを含む） |
| `PYTHONPATH=tools/bench/compare /usr/bin/time -p python3 -B -m unittest test_compare.CommonProbeCompilationTests.test_interval_inputs_check_on_base_and_current_revision test_scenarios.GeneratorTests.test_interval_check_points_and_load_controls` | 0。修正の影響を受ける2テストが成功。新系列62入力と関数数の6入力を、B0・B_WORK の双方で計136回 check し、すべて終了0・標準出力なし・診断なし | 2.92秒 |
| `/usr/bin/time -p scripts/check.sh --level work --base a7a6fe88c8d9213227eecbaee22f1b086ceee236 --only python_syntax --dry-run` | 0。計画の名指しどおり Python 道具の構文検査だけを選択。Rust の全 lib 等は選ばない | 0.01秒 |
| `/usr/bin/time -p scripts/check.sh --level work --base a7a6fe88c8d9213227eecbaee22f1b086ceee236 --only python_syntax` | 0。`selected checks passed` | 0.11秒 |
| `git diff --check` | 0。空白の問題なし | 未計測 |

初回の失敗は、生成器に `Benitoite.Network.Http` と書いたことが原因であった。公開されている `Benitoite.Unofficial.Network.Http` に直し、期待値と入力の大きさは緩めていない。修正後は影響する検査だけをやり直した。実 CLI 検査に先立つ自己検査の出力には、既存のテストが模擬プロセスで比較ランナーを通す際の測定表示も含まれるが、実際の性能測定ではない。

## 計画からのずれと申し送り

- `functions-main` の正常入力に quick の1/8/32関数、short の64/256関数を加えた。既存の0関数を空対照とし、従来の格子と拒否入力は保った。
- constraints に局所束縛、加算、比較と合流、整数七種、Range 成功、HTTP の Response/ClientRequest 構築の12系列を加えた。quick は各系列1/8/32単位と Range/HTTP の0単位、short は各系列64/256単位と Range/HTTP の0単位を使う。追加系列は quick 38点、short 26点で、全族の short は89点である。
- 同じ import の空 main を Range/HTTP の対照にした。他の新系列は既存の `control-16.3` を共有し、同じ空入力の重複採取を増やさない。HTTP の入力はレコード構築だけで、ネットワークや exit を実行しない。新たな能力判定は不要で、両状態に同じソースを渡す。
- 点の `n` は生成する反復単位数であり、AST 節点数とは呼ばない。`input_unit` と `source_bytes` に単位と UTF-8 バイト数を保存し、constraints の新系列には `control_case` も残した。解析の操作回数・補助記憶の消費は未取得のままで、0の値を追加していない。
- 入力・点の選択・出力照合を読者へ示すため、対象の Python ファイルと既存テストに加えて compare の README の表と説明を更新した。処理系・言語規則・Lean・共通計時器・目標 JSON は変更していない。作成時の関門を通し、代表点と対照の取り違え、旧版で拒否される生成入力を持ち主の境界で確かめる2テストを加えた。処理系側の差し込み口は増やしていない。テストの削除はなく、Python の入力生成器は83行追加・3行削除、テストは61行追加・1行削除である。
- 最初の quick/short は、取りまとめが取り込み後に B0/B_AFTER の完全 ID を固定して実施する。B_AFTER は未確定である。全族 short の既存の15分の事前見積もりと停止を保ち、今回の89点が上限に収まるかは、その校正で確認する。専用の計時器や新しい目標 JSON は作っていない。
- 既存の short は段別の補助実行を省くため、今回も short の段別時間は未取得である。既存 probe を使う観測で得た `load_parse`・`resolve`・`typeck` と、check 全体の CLI 時間を混同しない。性能の校正・記録の担当は取りまとめ、時期は M01 の取り込み後かつ A02 の最初の接続前である。
- 独立レビューと受け入れは取りまとめが行う。設計者の追加判断を必要とする言語規則・Lean の言明・公理の変更は発生していない。

## 取り込み後の short（取りまとめ）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8 --state after=f17f11933b981509014c841936731f114383aff6 --name syntax-batch6-m01`。終了0。標本採取の見積もりは 161.6 秒（上限 900 秒）で、15分以内に収まった。測定中は Codex を動かしていない（並行して Opus のレビューが読み取りだけを行っていた）。
- 出力の照合は全節で成功した。94 件の比較はすべて「判定不能」で、退行の疑いはない。M01 の入力はこの比較から B0 との基準線になる。
- 記録: `tools/bench/results/2026-10-24-f17f1193-syntax-batch6-m01/`（手元の絶対パスは `<repo>`・`<home>` に伏せた）。
