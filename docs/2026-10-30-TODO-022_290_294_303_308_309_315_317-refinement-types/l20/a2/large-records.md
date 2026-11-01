# 大きな記録

2026-11-02。RV-L20.a2 中1に従い、初回の次の二記録を `<tmp>/l20-a2-r1-large-records/` へ移した。改造内には入力と大きさ・SHA-256・集計を残す。

| 記録 | 大きさ（バイト） | SHA-256 |
|---|---:|---|
| axioms-summary.json | 308,349 | `598a7e338e80aace05d8bac1893627a553812e7b034447ab4960aa8d18c3dbe1` |
| axioms.log | 212,662 | `69b1c7b7dfa1cf62d63070f9dc0a7b7e080b7caa20902552a49fc438ebe47cfb` |

入力は [axioms.lean](axioms.lean)、実行は formal で `lake env lean -M 12288` を付けて行う。実行記録は [axioms-run.json](axioms-run.json)。集計は14モジュールの全宣言と旧五主定理・三モデル・十移送、1,820印字／1,810固有宣言。公理の和集合は propext・Quot.sound・Classical.choice のみで、未承認依存は0。これは初回の宣言に対する記録であり、r1 の後の宣言の監査は別に記す。

## r1 の再監査

出力先は同じ `<tmp>/l20-a2-r1-large-records/` とした。改造内の [r1/axioms-summary.json](r1/axioms-summary.json) は宣言ごとの配列を持たない小さい集計である。

| 記録 | 大きさ（バイト） | SHA-256 |
|---|---:|---|
| r1-axioms.log | 213,551 | `874226cb5a8d6929da972738aca589fa0bd3dd4b5b3143b8206b8685db464225` |
| r1-axioms-full-summary.json | 309,677 | `751d17aeeb8ad4121c0f3c231c99cffc4e5d196e095040728e86ccfcf00a882c` |

入力は既存の axioms.lean、実行は [r1/axioms-run.json](r1/axioms-run.json)。14モジュール・1,827印字／1,817固有宣言。新モジュールは private・生成宣言を含め61件。公理の和集合は propext・Quot.sound・Classical.choice のみで、未承認依存0。
