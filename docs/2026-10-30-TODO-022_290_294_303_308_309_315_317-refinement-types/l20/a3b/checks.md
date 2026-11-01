# 実行記録

単独 Lean は全て `formal/` で `lake env lean -M 12288`。コマンドの全引数と出力の SHA-256 は各 JSON に保存する。失敗した実行も一覧から除かない。

| 記録 | 終了 | 外側の時間（秒） |
|---|---:|---:|
| [kind-initial](kind-initial.json) | 1 | 0.534 |
| [kind-local-r1](kind-local-r1.json) | 1 | 0.505 |
| [kind-local-r2](kind-local-r2.json) | 1 | 0.525 |
| [kind-local-r3](kind-local-r3.json) | 0 | 0.496 |
| [kind-substat](kind-substat.json) | 1 | 0.549 |
| [kind-substat-r1](kind-substat-r1.json) | 0 | 0.533 |
| [kind-build](kind-build.json) | 0 | 1.670 |
| [formation-comp](formation-comp.json) | 1 | 0.424 |
| [formation-comp-r1](formation-comp-r1.json) | 1 | 0.410 |
| [formation-comp-r2](formation-comp-r2.json) | 1 | 0.381 |
| [formation-comp-r3](formation-comp-r3.json) | 1 | 0.403 |
| [formation-comp-r4](formation-comp-r4.json) | 0 | 0.402 |
| [formation-readers](formation-readers.json) | 1 | 0.582 |
| [formation-readers-r1](formation-readers-r1.json) | 1 | 0.576 |
| [formation-declared](formation-declared.json) | 1 | 0.610 |
| [formation-declared-r1](formation-declared-r1.json) | 0 | 0.583 |
| [formation-dependencies](formation-dependencies.json) | 1 | 41.455 |
| [formation-public](formation-public.json) | 1 | 0.213 |
| [kind-public-build](kind-public-build.json) | 0 | 0.593 |
| [formation-public-r1](formation-public-r1.json) | 1 | 0.709 |
| [formation-public-r2](formation-public-r2.json) | 1 | 0.676 |
| [formation-public-r3](formation-public-r3.json) | 0 | 0.727 |
| [formation-annotation](formation-annotation.json) | 1 | 0.757 |
| [formation-build](formation-build.json) | 0 | 0.908 |
| [row-kinds-readers](row-kinds-readers.json) | 1 | 50.722 |
| [row-kinds-readers-r1](row-kinds-readers-r1.json) | 1 | 1.693 |
| [row-kinds-readers-r2](row-kinds-readers-r2.json) | 0 | 10.989 |
| [work-dry-run](work-dry-run.json) | 0 | 0.008 |
| [work](work.json) | 0 | 9.158 |
| [contracts-realized](contracts-realized.json) | 0 | 0.419 |
| [connections](connections.json) | 0 | 0.419 |
| [contracts](contracts.json) | 0 | 0.446 |
| [public-signatures](public-signatures.json) | 0 | 0.749 |
| [main-signatures](main-signatures.json) | 0 | 0.701 |
| [axioms](axioms.json) | 0 | 1.941 |
| [all-public-signatures](all-public-signatures.json) | 0 | 0.696 |
