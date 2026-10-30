# 検査の記録

全て `lake env lean -M 12288` で検査した。time -l 自体は sandbox の kern.clockrate 拒否で終了1になる。status ファイルに記録した Lean 子プロセスの終了を優先する。03・04は代替のメモリ計測を開始したが、まだ終了値の分離前である。01・02の最大常駐量は未取得である。

RSS は macOS の getrusage(RUSAGE_CHILDREN) のバイト値を MiB に換算した、実行コマンドの子プロセスの最大値である。初回以外の時間は monotonic clock による。途中の失敗も保存する。

| 検査 | Leanの状態 | 経過（秒） | 最大常駐量（MiB） | ログ |
|---|---|---:|---:|---|
| 01 | 失敗（Lean終了値は未分離） | 0.07 | 未取得 | [01](checks/01.log) |
| 02 | 失敗（Lean終了値は未分離） | 0.53 | 未取得 | [02](checks/02.log) |
| 03 | 失敗（Lean終了値は未分離） | 0.557 | 666.62 | [03](checks/03.log) |
| 04 | ログにLeanエラーなし（終了値未分離） | 0.713 | 676.36 | [04](checks/04.log) |
| 05 | Lean 1 | 1.153 | 710.78 | [05](checks/05.log) |
| 06 | Lean 1 | 1.377 | 694.19 | [06](checks/06.log) |
| 07 | Lean 1 | 54.259 | 2077.75 | [07](checks/07.log) |
| 08 | Lean 1 | 2.171 | 750.84 | [08](checks/08.log) |
| 09 | Lean 1 | 55.034 | 2003.41 | [09](checks/09.log) |
| 10 | Lean 1 | 10.237 | 822.52 | [10](checks/10.log) |
| 11 | Lean 1 | 1.792 | 705.14 | [11](checks/11.log) |
| 12 | Lean 0 | 2.745 | 752.66 | [12](checks/12.log) |
| 13 | Lean 1 | 2.663 | 751.55 | [13](checks/13.log) |
| 14 | Lean 1 | 2.728 | 759.31 | [14](checks/14.log) |
| 15 | Lean 1 | 2.923 | 758.31 | [15](checks/15.log) |
| 16 | Lean 1 | 2.956 | 765.73 | [16](checks/16.log) |
| 17 | Lean 1 | 2.901 | 764.66 | [17](checks/17.log) |
| 18 | Lean 1 | 3.026 | 764.53 | [18](checks/18.log) |
| 19 | Lean 0 | 2.87 | 766.97 | [19](checks/19.log) |
| 20 | Lean 1 | 3.029 | 766.72 | [20](checks/20.log) |
| 21 | Lean 0 | 2.935 | 768.80 | [21](checks/21.log) |
| 22 | Lean 1 | 3.138 | 767.58 | [22](checks/22.log) |
| 23 | Lean 0 | 3.048 | 766.70 | [23](checks/23.log) |
| 24 | Lean 0 | 3.287 | 774.45 | [24](checks/24.log) |
| 25 | Lean 1 | 0.46 | 664.84 | [25](checks/25.log) |
| 26 | Lean 0 | 0.454 | 666.59 | [26](checks/26.log) |
| 27 | Lean 1 | 3.583 | 790.59 | [27](checks/27.log) |
| 28 | Lean 0 | 3.559 | 789.14 | [28](checks/28.log) |
| 29 | Lean 0 | 3.75 | 790.06 | [29](checks/29.log) |
| 30 | Lean 1 | 3.627 | 793.48 | [30](checks/30.log) |
| 31 | Lean 1 | 3.69 | 795.95 | [31](checks/31.log) |
| 32 | Lean 0 | 3.696 | 794.28 | [32](checks/32.log) |
| final-constants-2 | Lean 0 | 0.395 | 667.91 | [final-constants-2](checks/final-constants-2.log) |
| final-constants | Lean 0 | 0.397 | 667.98 | [final-constants](checks/final-constants.log) |
| final-skeleton-2 | Lean 0 | 3.678 | 795.86 | [final-skeleton-2](checks/final-skeleton-2.log) |
| final-skeleton | Lean 0 | 3.654 | 794.20 | [final-skeleton](checks/final-skeleton.log) |

最終成果物は final-skeleton-2 と final-constants-2。いずれも Lean 終了0、警告なしである。途中の10は再帰の停止性の診断用に一時的な穴を使った試行であり、最終のソースにその穴は残していない。07・09は停止性の証明でsimpの探索を広げすぎてheartbeat上限に達した失敗で、約55秒で終了した。10分の上限に達した検査はない。
