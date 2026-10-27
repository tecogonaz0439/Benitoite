# S2 のログ出力の小例と保存記録

2026-10-24、S2R。RV-S2「軽4」に従い、gitで除外される `work/m012/scratch/s2/` の実行例と出力の確認記録をここへ写した。S2Rでは処理系を再実行していない。

## 入力と結果

| ファイル | 内容 |
|---|---|
| [file-sink.bnt](file-sink.bnt)・[file-sink.txt](file-sink.txt) | 開いたWriterを捕捉して二回書く例と出力。メッセージだけを書き、水準・位置・属性を含む既定書式の再現は確認していない |
| [json-sink.bnt](json-sink.bnt)・[json-sink.jsonl](json-sink.jsonl) | 一行一記録の独自のJSON形式の例と出力。水準・位置・属性、重複属性の順、改行と引用符、符号なし整数の最大値、有限FloatとNaNを含む |
| `file-sink.<check|run>.<stdout|stderr>`・`json-sink.<check|run>.<stdout|stderr>` | 成功した四呼び出しの生の出力。すべて空である |
| [observations.json](observations.json) | S2の引数、終了状態、外側の時間、stdout・stderr。四呼び出しとも終了0 |
| [output-verification.json](output-verification.json)・[verify-output.py](verify-output.py) | S2が出力を読み取って確認した事項とSHA-256、当時の確認用スクリプト |
| `initial-json-sink.<check|run>.<stdout|stderr>`・[observations-initial.json](observations-initial.json) | 存在しない `Float.isInfinite` を使った最初の失敗の記録。最終成功と区別して残す。失敗時の入力そのものはこの複写には含まれない |
| [run-probes.py](run-probes.py) | S2の実行補助の写し。当時の配置と出力先を前提とする |
| [copy-verification.json](copy-verification.json) | S2Rの複写元と保存先のハッシュの照合。21ファイルは元のバイト列と一致する |

## パスと再確認の範囲

元の実行は `<repo>` を作業ディレクトリとし、入力は `work/m012/scratch/s2/<例>.bnt`、実行ファイルは `target/debug/benitoite`（0.0.11）であった。`<repo>` は手元のリポジトリの根を表す。記録中の個人の絶対パスを確認したが、複写対象にはなかった。元の相対パスは位置情報と入力のハッシュの根拠として保った。

このディレクトリは当時の記録の保管先である。保存した `.bnt` は現在も元の作業用出力先を参照するため、そのままここで実行してこのディレクトリへ出力する形には変えていない。再実行する場合は、入力を別の許可された作業ディレクトリへ写して出力先もそこへ変更し、入力名に由来する位置と新しいハッシュを別に記録する。`run-probes.py` と `verify-output.py` も当時の配置を前提とするので、この保存先でそのまま再実行する入口にはしない。

S2Rの確認は、保存した入力・出力のハッシュ、四呼び出しの終了状態と生の出力、テキスト二行、JSON二行の解析と内容、属性の順と位置の照合である。既定書式の公開後の動作、正負の無限大、書き込み失敗、並行タスク、解放後の使用は確認していない。A'の公開性の変更はソースに加えていないため、A'が成功したとする入力・出力も置かない。

採用する文書例では、Writerの解放後に `File.readText` で読み戻してstdoutへ出し、既存の文書例の検査が内容も比べられる形にする。この保存記録は、その文書例の検査を実施済みとするものではない。
