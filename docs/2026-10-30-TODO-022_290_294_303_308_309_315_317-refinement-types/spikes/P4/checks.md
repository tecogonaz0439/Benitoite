# P4 の検査記録

コマンド本体の終了状態と `/usr/bin/time -l` の終了状態を分ける。全件で計測器は sandbox の `sysctl kern.clockrate` 制限により終了1、最大常駐量は取得できなかった。秒数は実行器が記録した壁時計の経過である。

最初の `build-head` だけは本体の終了状態を直接保存していない。ログに573 jobsの成功があり、終了コードを別に保存する方式に変更後の増分ビルドも本体の終了0だった。初期形式の `exit_code` は計測器の値を持つ場合があるので、`command_exit_code` を判定に使う。最初の記録ではそれを不明とする。

## 最終の Lean 検査

| 対象 | 本体の終了 | 経過（秒） | 最大常駐量 | ログ |
|---|---:|---:|---|---|
| p2 | 0 | 1.154 | 取得不可 | [final-p2](checks/final-p2.log) |
| logic | 0 | 0.893 | 取得不可 | [final-logic](checks/final-logic.log) |
| context | 0 | 0.726 | 取得不可 | [final-context](checks/final-context.log) |
| derivations | 0 | 0.874 | 取得不可 | [final-derivations](checks/final-derivations.log) |
| m6 | 0 | 0.719 | 取得不可 | [final-m6](checks/final-m6.log) |
| production | 0 | 0.883 | 取得不可 | [final-production](checks/final-production.log) |
| cases | 0 | 0.724 | 取得不可 | [final-cases](checks/final-cases.log) |

最終7件の実行器の経過の合計は 5.973 秒。依存順は P2 → Logic → Context → Derivations → M6 → Production → Cases。全件に `-M 12288` を指定し、600秒を上限とした。

## 全試行

失敗は途中のLeanの構文・型推論・証明の未完を含む。生のログを残し、最終の成功だけで途中の失敗を上書きしない。`p2-build` の最初の失敗はパッケージのroot指定不足であり、`-R` にP4のパスを指定して解消した。

| 試行 | 本体の終了 | 計測器の終了 | 経過（秒） | 最大常駐量 | ログ |
|---|---:|---:|---:|---|---|
| build-head | 不明 | 1 | 204.009 | 取得不可 | [log](checks/build-head.log) |
| build-head-exit-fallback | 0 | 1 | 0.183 | 取得不可 | [log](checks/build-head-exit-fallback.log) |
| recheck-p3b-nat | 0 | 1 | 0.458 | 取得不可 | [log](checks/recheck-p3b-nat.log) |
| recheck-p3b-boundary | 0 | 1 | 0.455 | 取得不可 | [log](checks/recheck-p3b-boundary.log) |
| p2-build | 1 | 1 | 0.129 | 取得不可 | [log](checks/p2-build.log) |
| p2-build-root | 0 | 1 | 1.166 | 取得不可 | [log](checks/p2-build-root.log) |
| logic-01 | 1 | 1 | 0.884 | 取得不可 | [log](checks/logic-01.log) |
| logic-02 | 0 | 1 | 0.942 | 取得不可 | [log](checks/logic-02.log) |
| logic-03 | 1 | 1 | 0.892 | 取得不可 | [log](checks/logic-03.log) |
| logic-04 | 0 | 1 | 0.942 | 取得不可 | [log](checks/logic-04.log) |
| context-01 | 1 | 1 | 0.948 | 取得不可 | [log](checks/context-01.log) |
| context-02 | 1 | 1 | 0.707 | 取得不可 | [log](checks/context-02.log) |
| context-03 | 0 | 1 | 0.714 | 取得不可 | [log](checks/context-03.log) |
| context-04 | 0 | 1 | 0.730 | 取得不可 | [log](checks/context-04.log) |
| production-01 | 1 | 1 | 0.834 | 取得不可 | [log](checks/production-01.log) |
| production-02 | 1 | 1 | 0.869 | 取得不可 | [log](checks/production-02.log) |
| production-03 | 0 | 1 | 0.858 | 取得不可 | [log](checks/production-03.log) |
| derivations-01 | 1 | 1 | 0.781 | 取得不可 | [log](checks/derivations-01.log) |
| derivations-02 | 1 | 1 | 0.784 | 取得不可 | [log](checks/derivations-02.log) |
| derivations-03 | 0 | 1 | 0.834 | 取得不可 | [log](checks/derivations-03.log) |
| m6-01 | 0 | 1 | 0.780 | 取得不可 | [log](checks/m6-01.log) |
| derivations-04 | 0 | 1 | 0.834 | 取得不可 | [log](checks/derivations-04.log) |
| m6-02 | 0 | 1 | 0.669 | 取得不可 | [log](checks/m6-02.log) |
| production-04 | 1 | 1 | 0.842 | 取得不可 | [log](checks/production-04.log) |
| production-05 | 0 | 1 | 0.888 | 取得不可 | [log](checks/production-05.log) |
| context-05 | 1 | 1 | 0.770 | 取得不可 | [log](checks/context-05.log) |
| context-06 | 0 | 1 | 0.776 | 取得不可 | [log](checks/context-06.log) |
| derivations-05 | 0 | 1 | 0.837 | 取得不可 | [log](checks/derivations-05.log) |
| m6-03 | 0 | 1 | 0.717 | 取得不可 | [log](checks/m6-03.log) |
| production-06 | 0 | 1 | 0.880 | 取得不可 | [log](checks/production-06.log) |
| all-01-p2 | 0 | 1 | 1.161 | 取得不可 | [log](checks/all-01-p2.log) |
| all-01-logic | 0 | 1 | 0.932 | 取得不可 | [log](checks/all-01-logic.log) |
| all-01-context | 0 | 1 | 0.775 | 取得不可 | [log](checks/all-01-context.log) |
| all-01-derivations | 0 | 1 | 0.831 | 取得不可 | [log](checks/all-01-derivations.log) |
| all-01-m6 | 0 | 1 | 0.659 | 取得不可 | [log](checks/all-01-m6.log) |
| all-01-production | 0 | 1 | 0.838 | 取得不可 | [log](checks/all-01-production.log) |
| all-01-cases | 1 | 1 | 0.723 | 取得不可 | [log](checks/all-01-cases.log) |
| cases-02 | 0 | 1 | 0.719 | 取得不可 | [log](checks/cases-02.log) |
| derivations-06 | 0 | 1 | 0.842 | 取得不可 | [log](checks/derivations-06.log) |
| formal-head-source-match | 0 | 1 | 0.037 | 取得不可 | [log](checks/formal-head-source-match.log) |
| head-identity | 0 | 1 | 0.020 | 取得不可 | [log](checks/head-identity.log) |
| final-p2 | 0 | 1 | 1.154 | 取得不可 | [log](checks/final-p2.log) |
| final-logic | 0 | 1 | 0.893 | 取得不可 | [log](checks/final-logic.log) |
| final-context | 0 | 1 | 0.726 | 取得不可 | [log](checks/final-context.log) |
| final-derivations | 0 | 1 | 0.874 | 取得不可 | [log](checks/final-derivations.log) |
| final-m6 | 0 | 1 | 0.719 | 取得不可 | [log](checks/final-m6.log) |
| final-production | 0 | 1 | 0.883 | 取得不可 | [log](checks/final-production.log) |
| final-cases | 0 | 1 | 0.724 | 取得不可 | [log](checks/final-cases.log) |

## 再実行と点検

リポジトリの根から `python3 spikes/P4/check-all.py <記録の接頭辞>` を実行する。実行器がformalへ移動し、P4のLEAN_PATHとパッケージrootを指定して、各ファイルを依存順に再コンパイルする。本番のlake buildを再実行する台本ではない。

最終のLean7ファイルで独自のaxiom宣言・sorry・admit・native_decide・implemented_by・unsafeは0件。#print axioms の58件の出力は propext・Classical.choice・Quot.sound の範囲だけだった。P2の写しは元とバイト単位で一致した。Pythonの3台本も構文を点検した。

本番ソース等2227件について、途中の2026-10-30T08:29:00.796142+00:00から最終点検までのハッシュ比較で変更は0件。このハッシュ比較を作業開始前からの比較とはしない。本番formalとHEADの差分0の確認は formal-head-source-match のログを参照。
