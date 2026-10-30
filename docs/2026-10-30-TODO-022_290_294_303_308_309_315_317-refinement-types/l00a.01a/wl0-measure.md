# W-L0 の取りまとめの実行記録（2026-10-30）

- ブランチ: m014/l00a.01（san_benito の 9506fb623d9b26750177521933b50a9f67dd0346 から）
- 準備: 既存の formal/.lake/build を退避して空にした（clean）。実行の後に退避した成果物を削除した。
- 機械: 手元（M4・32GB、macOS）。計測: sandbox の外で /usr/bin/time -l（RUSAGE_CHILDREN の最大常駐量。単位はバイト）。
- 開始: 2026-10-30T19:44:31+0900

```
/usr/bin/time -l scripts/check.sh --level work --base 9506fb623d9b26750177521933b50a9f67dd0346 --only formal_build
```

```
== plan: level work against 9506fb623d9b26750177521933b50a9f67dd0346 (changed files not classified) (partial selection: --only formal_build)
   [formal_build] because of --only (estimate: several min (cache dependent))
      command: (cd formal && lake build); reject declarations using sorry
   later: stage checks named connections; change covers full regression; release checks the candidate
== formal_build
selected checks passed
      207.52 real      1046.65 user        97.77 sys
          3577937920  maximum resident set size
                   0  average shared memory size
                   0  average unshared data size
                   0  average unshared stack size
            19730359  page reclaims
              106040  page faults
                   0  swaps
                   0  block input operations
                   0  block output operations
                   0  messages sent
                   0  messages received
                   0  signals received
               11753  voluntary context switches
             1775639  involuntary context switches
            87222811  instructions retired
            40209492  cycles elapsed
             2572720  peak memory footprint
exit 0
2026-10-30T19:47:59+0900
```
