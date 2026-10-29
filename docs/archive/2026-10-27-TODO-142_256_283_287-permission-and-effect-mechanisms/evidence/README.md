# 計画が参照する根拠の保存

2026-10-27、作業 WP-01b（依頼名 P1b）。S8 と WP-01（依頼名 P1）の記録を、git の外の作業用の場所から複写した。保存した過去の出力と、現在の状態で再実行した出力を区別する。実装・証明・ビルド・テストの成功を示す記録ではない。

| 保存先 | 元の記録と用途 |
|---|---|
| [S8/lean-inventory.md](S8/lean-inventory.md)、[JSON](S8/lean-inventory.json) | 元は work/m013/scratch/S8/lean-inventory.*。保管した写しを左欄から参照する（[複写とハッシュの記録](copy-manifest.json)）。基準は `80d1eeadcc9dc386560e0e2890c6da3ef518a1c5`。306定理/75ファイルの母集団、宣言別の位置、入力ハッシュと集計の限界を保存する |
| [S8/lean-inventory.py](S8/lean-inventory.py)、同じ場所の lean-*.grep.txt | 元の生成器と各識別子の git grep の出力。コメント・文字列・宣言名を除く字句検索であり、推移的依存や破損件数を示さない。生成器が使う SA のコメント除去関数は改造の spikes/SA/inventory.py にある |
| [P1/inputs.json](P1/inputs.json)、[security-input-check.json](P1/security-input-check.json) | 元は work/m013/scratch/P1/。開始版 B0 `6124775788579e60530f55fb85570f26ef7fa900`、入力のハッシュ、S9 からの差、勧告照合の入力を確認した記録。docs/todo の項目はパスとハッシュの記録だけで、内容を複写していない |
| [P1/dry-run-summary.json](P1/dry-run-summary.json)、同じ場所の stdout/stderr | 元は work/m013/scratch/P1/。13件の指定と終了状態・所要・出力。全件終了0で、work は文書だけのため検査なし、change は advisories、release は release_stack/advisories だった |
| [P1/dry_runs.py](P1/dry_runs.py) | 当時の13件を実行する生成器。元の出力先をそのまま使わず、下の再実行器から起動する |
| [P1/counts.json](P1/counts.json)、[document-check.json](P1/document-check.json) | 当時の作業数・見積もりの算術・リンク等の静的点検。旧 ID と旧 L00 4〜8時間を使う。WP-01b の再見積もりと現在の文書の確認結果には流用しない |
| [copy-manifest.json](copy-manifest.json) | 複写元の相対パス、元バイト列の SHA-256 とパス置換後の SHA-256。63ファイルを複写した一覧である |

元記録にあるリポジトリの絶対パスを `<repo>`、ホームを `<home>` に置き換えた。元の記録の ID・日付・コマンド・出力・件数は、パスの置換を除いて保持する。複写元へ書き戻さない。現在の四文書では、過去の P1 を作業 WP-01 と表記する。

## 作り直すコマンド

リポジトリの根で次を実行する。出力先は work/m013/scratch/P1b/reproduced/ の下に固定し、ここに保存した過去の出力を上書きしない。再実行器は private や docs/todo を読まず、git の状態を変えない。棚卸しは git の読み取りと字句集計、dry-run は選択の表示だけであり、Cargo や Lean を起動しない。

```sh
python3 -B docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/evidence/reproduce.py inventory
python3 -B docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/evidence/reproduce.py dry-run
```

inventory は元の固定コミットを読むため、同じ入力と生成器なら JSON・一覧・grep の内容を再現できる。元コミットが手元にない場合は失敗として扱う。S8 の対象ファイルのハッシュを現在の入力と照合し、違いがあれば新しい母集団として区別する。L00.01 のビルドで得る破損宣言の数は、この字句集計とは別に記録する。

dry-run は元の B0 を基準に、その時点の HEAD と作業ツリーを分類する。WP-01 当時の未コミットの四文書だけという状態を復元するコマンドではない。HEAD・差分・指定が異なるため changed files の数や出力の完全一致を要求しない。WP-01b ではこの差と終了状態を新しい結果へ記す。未来の L/R の差分を分類した証拠とも扱わない。

P1/inputs.json のハッシュや当時の状態を新しく採取する場合は、同ファイルの対象のうち公開の入力を対象にして、起動時のコミット・差分とともに別の記録へ保存する。docs/todo のパスは過去のメタデータとして保持するだけとし、本作業で再読込・再照合しない。


## V10.3d の参照先の整理（2026-10-30）

上の旧配置・実行コマンドは当時の記録として保持する。現在参照する保管物は次のとおりである。機械の来歴のキーや記録済みハッシュは変更していない。

| 当時の参照先 | 保管した写し（本書からの相対リンク） |
|---|---|
| `work/m013/scratch/S8/lean-inventory.*` | [evidence/S8/lean-inventory.md](S8/lean-inventory.md) |
| `work/m013/scratch/P1/` | [evidence/P1/inputs.json](P1/inputs.json) |
