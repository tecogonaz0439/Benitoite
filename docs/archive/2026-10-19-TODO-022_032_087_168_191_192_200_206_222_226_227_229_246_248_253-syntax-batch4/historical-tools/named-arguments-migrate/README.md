# 名前付き引数の旧移行道具の保管

TODO-247の移行を終えた専用道具とRust helperを、TODO-253の対応として保管した。保管した6ファイルは移動前から内容を変えていない。元のREADMEも履歴の一部であり、その中のコマンドと相対リンクは元の配置を前提とする。現役の手順と復元の条件は本書を参照する。

開始版は `b72e4bf4a2f23b26b2c96612bfa2b7f3e9f05fa7`（G6開始時のHEADおよびsan_benitoとのmerge-base）である。移動前にSHA-256を取得し、移動後の全ファイルと開始版のGitオブジェクトを照合する。環境が.git/index.lockの作成を拒否したため、git mvの代わりに通常のファイル移動を使った。Gitインデックスへの反映は取りまとめが行う。

## 元のパス・保管先・SHA-256

保管先は本書と同じディレクトリからの相対パスである。機械可読な一覧は[manifest.json](manifest.json)に置く。元のtools/とcrates/の構造を保ち、復元時はリポジトリの根へ同じ相対パスで戻す。

| 移動元・復元先（リポジトリの根から） | 保管先（本書から） | 移動前のSHA-256 |
|---|---|---|
| `tools/named-arguments-migrate/README.md` | [tools/named-arguments-migrate/README.md](tools/named-arguments-migrate/README.md) | `e58d926f2906032e2e8fc55fc43e7ccbce1cc575894bab73dcef1099744ca9b3` |
| `tools/named-arguments-migrate/extract.py` | [tools/named-arguments-migrate/extract.py](tools/named-arguments-migrate/extract.py) | `731fac23761ff480269de2f19f5eb7f5c52cd8d898ed73c50c89c0f12a697476` |
| `tools/named-arguments-migrate/migrate.py` | [tools/named-arguments-migrate/migrate.py](tools/named-arguments-migrate/migrate.py) | `abe745f37d417b3422009a6c36f60c0c2d83317b0a2a08961e4cfa8a8abf5b07` |
| `tools/named-arguments-migrate/test_migrate.py` | [tools/named-arguments-migrate/test_migrate.py](tools/named-arguments-migrate/test_migrate.py) | `fc3120d7539582762e4ef907b64a2fe297391f0a8765978091f0e25523ece852` |
| `crates/benitoite/examples/named_arguments_inventory.rs` | [crates/benitoite/examples/named_arguments_inventory.rs](crates/benitoite/examples/named_arguments_inventory.rs) | `1312f4632370bbc6b0b8b9cb0196c7edbb7c951fe99bc43e2d1f1061ac1d9169` |
| `crates/benitoite/examples/named_inventory/index.rs` | [crates/benitoite/examples/named_inventory/index.rs](crates/benitoite/examples/named_inventory/index.rs) | `7b62cbc15538bbbd0641bf9dd744cf1b1fed41bd0c4a08c17667a6c55aeef8a6` |

## 別checkoutへの復元

開始版の配置を調べる場合は、リポジトリの根から次を実行する。開始版には元のパスで同じ6ファイルが既にある。作業用checkoutへ戻すと、Cargoのexamplesの自動発見も戻るため、復元は別checkoutで行う。

```sh
git worktree add --detach /tmp/benitoite-g6-restore b72e4bf4a2f23b26b2c96612bfa2b7f3e9f05fa7
```

保管した実ファイルを別checkoutへ戻す場合は、次の手順を使う。`HISTORICAL`は本書のあるディレクトリ、`RESTORE`は復元先checkoutの根とする。改造全体がdocs/archive/へ移った後は、HISTORICALだけを移動後の場所へ替える。全ファイルのhashと復元先を確認してからコピーし、異なる内容の既存ファイルを上書きしない。

```sh
HISTORICAL=docs/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/historical-tools/named-arguments-migrate
RESTORE=/tmp/benitoite-g6-restore
python3 - "$HISTORICAL" "$RESTORE" <<'PYRESTORE'
import hashlib
import json
from pathlib import Path
import shutil
import sys

archive, root = map(Path, sys.argv[1:])
manifest = json.loads((archive / 'manifest.json').read_text())
files = []
for row in manifest['files']:
    source, target = archive / row['archived'], root / row['source']
    if hashlib.sha256(source.read_bytes()).hexdigest() != row['sha256']:
        raise SystemExit(f'archive hash mismatch: {source}')
    if target.exists() and target.read_bytes() != source.read_bytes():
        raise SystemExit(f'refusing to overwrite: {target}')
    files.append((source, target))
for source, target in files:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
print(f'restored {len(files)} files')
PYRESTORE
```

開始版への復元は、旧自己検査の成功を意味しない。開始版のparserは旧構文を拒否し、道具が必要とする `n1/joins.json` と `n1/call-candidates.json` も現在のcheckoutにはない。元のREADMEには自己検査8件中6件が失敗することを記録してあり、その期待やassertは変更していない。

旧構文で再実行するには、過去の記録から、旧構文を受理するparserとhelperのAPIが対応する版、および当時のN1入力を特定する。その版の完全IDを指定して別checkoutを作り、必要な共有source-migrateとN1入力も当時の内容へ復元する。道具のBASEは過去の改造の保管先を指すため、版ごとの元の配置も確認する。対応する旧版とN1入力は今回復元・検証しておらず、現行parserや欠けたJSONの空の代用品で成功したことにはしない。旧版を準備した後の入口は、元のREADMEのhelperビルドとinventory/自己検査である。保管先から直接実行すると相対importとリポジトリの根の計算が変わるため、元のパスへ戻して実行する。

## 現役の検査との境界

現役のsource-migrateとtry-actions-migrateはtools/に残す。UTF-8バイト位置・元hash・編集範囲・diff・再適用の契約を複製せず、migrate_selftestsはこの二つを引き続き検査する。保管したPythonはpython_syntaxのglobに含めず、専用Rust helperとindexはCargoのexamplesから外す。

内容の保全は全6ファイルのSHA-256照合で、現役からの切り離しは参照検索・policy_selftest・migrate_selftests・Cargoのexamples確認で検査する。保管先の壊れた自己検査を現役の成功件数に混ぜない。G6の検査結果は[../../g6/results.md](../../g6/results.md)に記す。
