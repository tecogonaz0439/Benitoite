# R20.0a3: 計時の探査の Program 構築への追随

## 対応

`build.py` は、比較する版の archive にある `crates/benitoite/src/ir/core_ir.rs` から、公開の `Program` 宣言の本体を取り出し、公開欄 `range_signatures` の有無を調べる。欄がある版だけに `--cfg benitoite_range_signatures` を渡す。コミット ID や呼び出し側の作業ツリーでは判定しない。

判定値 `range_signatures` と宣言元のファイル全体の SHA-256 `core_ir_sha256` を `probe_api` に加えた。既存の probe のキャッシュ鍵は `probe_api` 全体を含むため、宣言元が変われば、CLI のビルドを再利用していても probe を作り直す。

`timing_probe.rs` の独立 IR の `CoreProgram` 構築では、この cfg がある場合だけ `range_signatures: Default::default()` を加える。既存の `benitoite_range_index` による `Ty::Con` の構築の分岐はそのまま使う。今回の両版で、ほかの公開 API に合わせた構築の修正は必要なかった。README の版の判定の段落にも新しい cfg と初期化の方法を追記した。

編集したソースと文書は、指定された比較器の4ファイルと、この `r20.0a3/` の中だけである。処理系のソースは変更していない。`private/`、そこを指すスキルのシンボリックリンク、`docs/todo/` は読んでいない。

## 比較器の自己検査

README の「自己検査」のコマンドを実行した。

```sh
PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'
```

**39件すべて成功、終了0**である。unittest の実行時間は89.445秒、起動を含む外側の経過時間は89.53秒であった。[ログ](selftest.log)と[実行情報](selftest-invocation.json)を保存した。

既存のキャッシュの自己検査を拡張し、欄のない `Program`、別の構造体だけが同名の欄を持つ場合、欄を持つ `Program`、欄を取り除いた `Program` を順に与えた。判定と cfg の有無、宣言元のハッシュと probe のキャッシュ鍵の変化、CLI を再利用した場合の probe の再ビルドを確認した。

両版を共通のビルド手順へ通す既存の機能検査には、通常の short の代表点 `bridge-shared-8` を加えた。quick の独立 IR・グラフの点と合わせて7点であり、従来の状態制限に従い、旧基準版で5点、開始版で5点、B_WORK で7点の計17回の機能検査が成功した。独立 IR の正常入力の受理と兄弟の枝からの参照の拒否、グラフの節数・辺数・復元した値、B_WORK のヒープ上の対象数を照合した。縮小器の段別出力と誤出力の拒否も既存の検査を通過した。[点と対象状態の一覧](probe-coverage.json)を保存した。

## 両版の probe のビルド

| 対象 | 完全なコミット ID | `range_signatures` | 新しい cfg | probe のビルドと機能検査 |
|---|---|---|---|---|
| 開始版 | `6124775788579e60530f55fb85570f26ef7fa900` | false | なし | 成功。`bridge-shared-8` を含む5点が成功 |
| B_WORK | `b1d2f30e99fb37d1a4ea02f647174528b8477c82` | true | あり | 成功。`bridge-shared-8` を含む7点が成功 |

両版とも既定構成である。開始版は既存の CLI のビルドを再利用し、probe を再ビルドした。B_WORK は CLI と probe をビルドした。自己検査は、既存の旧基準版 `c31e64b03d2810343e1779926bea4ebc958b6164` の probe と、区間解析入力の基準版 `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8` も通過した。

開始版と B_WORK の [API 判定と宣言元のハッシュ](api-detection.json)、[ビルド情報・コンパイルコマンド・probe のハッシュ](probe-builds.json)、ビルドログ（[開始版](start-build.log)、[B_WORK](B_WORK-build.log)）を保存した。保存時に、両版の probe の実ファイルの SHA-256 とビルド情報の値が一致することも確認した。

性能の標本は採取していない。自己検査のログにある `cases measured` は、外部コンパイラの失敗と欠測の扱いを確かめる検査が、外部プロセスを代用して作った記録である。実際の両版の probe は、機能検査の各点を対象状態ごとに一度ずつ実行した。

## work 検査

先に dry-run を実行し、Python の構文検査と移行器の自己検査だけが選ばれることを確認した。その後、同じ指定で本実行を行った。

```sh
/usr/bin/time -p scripts/check.sh --level work --base b1d2f30e99fb37d1a4ea02f647174528b8477c82 --dry-run
/usr/bin/time -p scripts/check.sh --level work --base b1d2f30e99fb37d1a4ea02f647174528b8477c82
```

| 実行 | 終了状態 | 外側の real | user | sys |
|---|---:|---:|---:|---:|
| dry-run | 0 | 0.19秒 | 0.05秒 | 0.20秒 |
| work 本実行 | 0 | 17.10秒 | 11.47秒 | 2.77秒 |

本実行は Python の構文検査、`source-migrate` の自己検査6件、`try_actions_inventory` のビルド、`try-actions-migrate` の自己検査10件を通過した。パイプは使わず、`scripts/check.sh` の終了状態を引き継ぐ `/usr/bin/time` の戻り値を直接記録し、記録用の起動処理からも同じ値を返した。[dry-run のログ](work-dry-run.log)・[実行情報](work-dry-run-invocation.json)、[本実行のログ](work.log)・[実行情報](work-invocation.json)を保存した。

## 作業末の確認

`git diff --check` と編集範囲の確認を実施した。ブランチは `m013/r20.0a3`、HEAD は B_WORK のままで、ステージング・コミット・ブランチの操作は行っていない。実版の archive とビルドは `target/bench/builds/` に置いた。自己検査の一時ディレクトリは各検査の終了時に削除された。

作業開始は2026年10月29日01:16 JST。所要時間は約5分であった。既存のビルドの再利用により、当初の見込み20〜40分より短く終えた。
