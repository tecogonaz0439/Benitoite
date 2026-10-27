# G01 の結果

担当: 取りまとめ（Claude Code）。2026-10-27。

## 基準と状態

HEAD は `0b4979eba18082b89b7aee2c00648cf28b1551ee`（U03R の取り込み）、作業ツリーに差分はない。change の基準は計画で固定した改造の開始版 B0 `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8`（4,273 ファイルの差分）。本体の作業ツリーで実行した。

## change

```sh
scripts/check.sh --level change --base 706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8 --dry-run
/usr/bin/time -l scripts/check.sh --level change --base 706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8
```

dry-run は終了0（選択と理由は [dry-run.log](dry-run.log)）。本実行は 09:34:58 に始め 10:43:20 に終わり、終了0（`selected checks passed`）、外側の時間 4,102 秒（68分）、最大常駐量 5.93GB。出力は [change.log](change.log)（手元のパスを伏せた）。計画の仮見込み 90〜150 分の内側である。

| 単位 | 中身 | 結果 |
|---|---|---|
| fmt | `cargo fmt --all --check` | 成功 |
| lint_default・lint_heap | 既定の構成の lib・tests・examples と、heap-verify・alloc-stats の全ターゲットの clippy | 成功 |
| test_default_all | 既定の構成の workspace 全ターゲット | 3,058 件成功、失敗0、ignored 52 |
| test_heap_all | gc-mark-sweep・heap-verify の全ターゲット | 3,072 件成功、失敗0、ignored 52 |
| test_stress | gc-stress を加えた lib・tests | 1,731 件成功、失敗0、ignored 31 |
| doc_default | 文書テスト（compile_fail を含む） | 34 件成功、失敗0、ignored 1 |
| long_only | 長いテストを heap と stress の構成ごとに一括（形式化の書き出しを除く） | 2 構成で計 58 件成功、失敗0 |
| formal_build | `lake build` と sorry の拒否 | 成功（ビルド済みの成果物を使った） |
| source_rules・skill_generated・spec_tally・python_syntax・migrate_selftests・licenses・policy_selftest | 規約・生成した Skill の鮮度・仕様の対応集計・Python の構文・移行の道具の自己検査・許諾・検査方針の自己検査 | 成功 |
| advisories | cargo-deny 0.20.2、二つの manifest の `--locked` の勧告の照合 | 両対象とも照合済みで検出0件（`ALL TARGETS CHECKED: 0 advisories`）。lock の SHA-256 は照合の前後で同じ。生の出力と対象別の結果は [advisories/](advisories/)（report.json・各 stdout/stderr。手元のパスを伏せた） |

spec_examples と reference_examples は test_default_all に含まれるので選ばれていない（dry-run の `omitted`）。

## 道具の自己検査

| 検査 | コマンド | 結果 |
|---|---|---|
| T-D | `cargo build -q -p benitoite --bin benitoite --example derive_inventory && python3 -B tools/derive/test_derive.py` | 終了0、49 件成功、78 秒（[derive.log](derive.log)） |
| 比較の道具 | `python3 -B -m unittest discover -s tools/bench/compare -p 'test_*.py'` | 終了0、39 件成功、227 秒（[compare.log](compare.log)） |

check-heap.sh は計画のとおり対象外（ヒープの不変条件を変えていない）。LLM を呼ぶ評価は行っていない。

## 全体レビュー

Opus 5.5 のサブエージェントによる [RV-G](../reviews/RV-G.md) は条件付き受け入れ（重大0・中2・軽7）。対応は [RV-G-response](../reviews/RV-G-response.md)。中1・中2・軽1〜軽3 を G01R で直し、軽4〜軽6 は docs/todo へ回し、軽7 は Z01 の照合に加える。訳語は設計者が選んだ（コンポーネントハンドル（component handle）。到達記録（evaluation trace）は据え置き）。

## 申し送り

G01R は src と文書を変えるので、その work が変えた単位をやり直す。G01R の後に change をやり直さない。Z01b の release と K2 は、Z01 の後の最終の関係状態で行う。
