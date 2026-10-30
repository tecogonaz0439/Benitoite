# P3b の Lean 検査

全検査に `-M 12288` と一回600秒の上限を指定した。タイムアウトはない。`/usr/bin/time -l` は `sysctl kern.clockrate` の制限で最大常駐量を出せず、外側の終了は1となる。Leanの終了は別マーカー/子プロセスから記録した。RSSはPython `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` の補助値であり、time -lの同名欄の値ではない。

| 記録 | 対象 | Lean終了 | 外側time終了 | 経過秒 | 補助RSS MiB | 生ログ |
|---|---|---:|---:|---:|---:|---|
| P3b-checks-001 | P3b-Derivations.lean | 1 | 1 | 2.816 | 761.22 | [log](P3b-checks-001.log) |
| P3b-checks-002 | P3b-Derivations.lean | 1 | 1 | 2.776 | 762.47 | [log](P3b-checks-002.log) |
| P3b-checks-003 | P3b-Derivations.lean | 1 | 1 | 2.816 | 762.03 | [log](P3b-checks-003.log) |
| P3b-checks-004 | P3b-Derivations.lean | 1 | 1 | 2.856 | 765.66 | [log](P3b-checks-004.log) |
| P3b-checks-005 | P3b-Derivations.lean | 1 | 1 | 2.829 | 766.92 | [log](P3b-checks-005.log) |
| P3b-checks-006 | P3b-Derivations.lean | 1 | 1 | 2.886 | 768.28 | [log](P3b-checks-006.log) |
| P3b-checks-007 | P3b-Derivations.lean | 1 | 1 | 2.817 | 762.86 | [log](P3b-checks-007.log) |
| P3b-checks-008 | P3b-Derivations.lean | 1 | 1 | 2.822 | 766.31 | [log](P3b-checks-008.log) |
| P3b-checks-009 | P3b-Derivations.lean | 1 | 1 | 2.826 | 765.53 | [log](P3b-checks-009.log) |
| P3b-checks-010 | P3b-Derivations.lean | 0 | 1 | 2.769 | 763.27 | [log](P3b-checks-010.log) |
| P3b-checks-011 | P3b-Derivations.lean | 0 | 1 | 2.810 | 773.11 | [log](P3b-checks-011.log) |
| P3b-checks-012 | P3b-Derivations.lean | 1 | 1 | 2.890 | 775.41 | [log](P3b-checks-012.log) |
| P3b-checks-013 | P3b-Derivations.lean | 1 | 1 | 3.298 | 789.31 | [log](P3b-checks-013.log) |
| P3b-checks-014 | P3b-Derivations.lean | 1 | 1 | 3.364 | 793.56 | [log](P3b-checks-014.log) |
| P3b-checks-015 | P3b-Derivations.lean | 0 | 1 | 3.258 | 794.28 | [log](P3b-checks-015.log) |
| P3b-checks-016 | P3b-Derivations.lean | 1 | 1 | 3.410 | 797.22 | [log](P3b-checks-016.log) |
| P3b-checks-017 | P3b-Derivations.lean | 1 | 1 | 3.480 | 793.47 | [log](P3b-checks-017.log) |
| P3b-checks-018 | P3b-Derivations.lean | 1 | 1 | 3.479 | 794.69 | [log](P3b-checks-018.log) |
| P3b-checks-019 | P3b-Derivations.lean | 0 | 1 | 3.529 | 792.75 | [log](P3b-checks-019.log) |
| P3b-checks-020 | P3b-Derivations.lean | 0 | 1 | 3.637 | 800.00 | [log](P3b-checks-020.log) |
| P3b-checks-021-final | P3b-Derivations.lean | 0 | 1 | 3.765 | 798.92 | [log](P3b-checks-021-final.log) |
| P3b-checks-022-final | P3b-Derivations.lean | 0 | 1 | 3.730 | 802.52 | [log](P3b-checks-022-final.log) |
| P3b-checks-023-final | P3b-Derivations.lean | 0 | 1 | 3.818 | 792.33 | [log](P3b-checks-023-final.log) |
| P3b-checks-024-heartbeat200k | P3b-Heartbeat200k.lean | 0 | 1 | 3.676 | 795.45 | [log](P3b-checks-024-heartbeat200k.log) |
| P3b-check-boundary-01 | P3b-BoundaryProofs.lean | 1 | 1 | 0.771 | 745.16 | [log](P3b-check-boundary-01.log) |
| P3b-check-boundary-02 | P3b-BoundaryProofs.lean | 1 | 1 | 0.553 | 745.86 | [log](P3b-check-boundary-02.log) |
| P3b-check-boundary-03 | P3b-BoundaryProofs.lean | 0 | 1 | 0.454 | 730.59 | [log](P3b-check-boundary-03.log) |
| P3b-check-boundary-final | P3b-BoundaryProofs.lean | 0 | 1 | 0.666 | 733.77 | [log](P3b-check-boundary-final.log) |
| P3b-check-import-probe | P3b-ImportProbe.lean | 0 | 1 | 0.346 | 667.41 | [log](P3b-check-import-probe.log) |
| P3b-check-nat-01 | P3b-Nat.lean | 1 | 1 | 0.511 | 675.50 | [log](P3b-check-nat-01.log) |
| P3b-check-nat-02 | P3b-Nat.lean | 0 | 1 | 0.456 | 675.22 | [log](P3b-check-nat-02.log) |
| P3b-check-nat-03 | P3b-Nat.lean | 0 | 1 | 0.455 | 682.25 | [log](P3b-check-nat-03.log) |
| P3b-check-request-01 | P3b-RequestSnapshot.lean | 0 | 1 | 0.456 | 680.05 | [log](P3b-check-request-01.log) |
| P3b-check-request-final | P3b-RequestSnapshot.lean | 0 | 1 | 0.448 | 681.61 | [log](P3b-check-request-final.log) |

最終の一般の導出は023-final、heartbeat設定値だけを変えたコピーは024-heartbeat200k、Nat代表はnat-03、リテラル/shapeAt代表はboundary-final、Requestの独立写しはrequest-final、既存importの差の記録はimport-probeである。すべてLean本体の終了0。途中の失敗ログにあるsorryAxや構文エラーを、最終のファイルの穴と混同しない。

一般の導出の023には入力のSHA-256と、検査中に入力が変わらなかった記録がある。最終の各ファイルのハッシュとheartbeatコピーの一致、保護対象のハッシュ照合はP3b-verification.json/P3b-completion.jsonに記録する。

importの検査が示すのは、読み込まれた旧生成物と現行ソースの不一致である。Requestの代表は現行ソースから必要な型付け枝を独立に写した。Nat/literalの代表で使ったAPIの一致を、本番全ソースの再ビルドと扱わない。本番の再ビルドは未実施。
