# 版どうしの性能比較

候補: `bbc22ac0913910d26936f4b2e2def2204da93c4f`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013657 | 0.000152 |
| functions-main-0-0 | after | 0.013497 | 0.000589 |
| functions-main-0-1 | before | 0.013791 | 0.000993 |
| functions-main-0-1 | after | 0.013671 | 0.000444 |
| functions-main-64-0 | before | 0.014104 | 0.000921 |
| functions-main-64-0 | after | 0.013937 | 0.000157 |
| functions-main-256-0 | before | 0.015620 | 0.000485 |
| functions-main-256-0 | after | 0.015321 | 0.000069 |
| functions-main-1000-0 | before | 0.021025 | 0.000376 |
| functions-main-1000-0 | after | 0.020774 | 0.001484 |
| functions-main-1000-1 | before | 0.021085 | 0.000741 |
| functions-main-1000-1 | after | 0.021023 | 0.002502 |
| functions-args-0-0 | before | 0.013677 | 0.001220 |
| functions-args-0-0 | after | 0.013479 | 0.000084 |
| functions-args-0-1 | before | 0.013702 | 0.000404 |
| functions-args-0-1 | after | 0.013547 | 0.000286 |
| functions-args-1000-0 | before | 0.027710 | 0.000994 |
| functions-args-1000-0 | after | 0.027434 | 0.004319 |
| functions-args-1000-1 | before | 0.027150 | 0.000513 |
| functions-args-1000-1 | after | 0.027551 | 0.001828 |
| functions-modules-0-0 | before | 0.014307 | 0.000671 |
| functions-modules-0-0 | after | 0.014153 | 0.000570 |
| functions-modules-0-1 | before | 0.014400 | 0.000852 |
| functions-modules-0-1 | after | 0.014495 | 0.000183 |
| functions-modules-1000-0 | before | 0.021773 | 0.000471 |
| functions-modules-1000-0 | after | 0.021621 | 0.000879 |
| functions-modules-1000-1 | before | 0.021384 | 0.000374 |
| functions-modules-1000-1 | after | 0.021237 | 0.001501 |
| existing-fib | before | 0.014233 | 0.001132 |
| existing-fib | after | 0.013931 | 0.000131 |
| existing-loop | before | 0.014299 | 0.001475 |
| existing-loop | after | 0.014082 | 0.000138 |
| existing-string | before | 0.014191 | 0.001030 |
| existing-string | after | 0.014096 | 0.000318 |
| higher-0-0 | before | 0.013683 | 0.001252 |
| higher-0-0 | after | 0.013593 | 0.000275 |
| higher-1-0 | before | 0.014415 | 0.001909 |
| higher-1-0 | after | 0.014417 | 0.000256 |
| classes-0 | before | 0.018049 | 0.000613 |
| classes-0 | after | 0.018120 | 0.000565 |
| higher-0-300 | before | 0.028551 | 0.000236 |
| higher-0-300 | after | 0.029227 | 0.001447 |
| higher-1-300 | before | 0.031484 | 0.000837 |
| higher-1-300 | after | 0.032004 | 0.000708 |
| classes-300 | before | 0.037519 | 0.000412 |
| classes-300 | after | 0.038004 | 0.000258 |
| depth-0-8 | before | 0.014966 | 0.001213 |
| depth-0-8 | after | 0.014863 | 0.000167 |
| depth-1-8 | before | 0.015224 | 0.001771 |
| depth-1-8 | after | 0.015472 | 0.000280 |
| f1-nofail-call | before | 0.014593 | 0.001257 |
| f1-nofail-call | after | 0.014341 | 0.000091 |
| f1-join-effects | before | 0.014434 | 0.000337 |
| f1-join-effects | after | 0.014348 | 0.000148 |
| control-16.3 | before | 0.013487 | 0.002191 |
| control-16.3 | after | 0.013446 | 0.000340 |
| interval-bind-64 | before | 0.013885 | 0.000757 |
| interval-bind-64 | after | 0.013569 | 0.000176 |
| interval-bind-256 | before | 0.014261 | 0.001170 |
| interval-bind-256 | after | 0.014168 | 0.000078 |
| interval-add-64 | before | 0.013821 | 0.001118 |
| interval-add-64 | after | 0.013784 | 0.000461 |
| interval-add-256 | before | 0.015409 | 0.000399 |
| interval-add-256 | after | 0.015301 | 0.000858 |
| interval-flow-64 | before | 0.014376 | 0.000911 |
| interval-flow-64 | after | 0.014295 | 0.000356 |
| interval-flow-256 | before | 0.017223 | 0.000403 |
| interval-flow-256 | after | 0.017180 | 0.000878 |
| interval-range-0 | before | 0.019234 | 0.000540 |
| interval-range-0 | after | 0.018935 | 0.001244 |
| interval-range-64 | before | 0.023416 | 0.000169 |
| interval-range-64 | after | 0.023472 | 0.002058 |
| interval-range-256 | before | 0.037637 | 0.000890 |
| interval-range-256 | after | 0.037272 | 0.001293 |
| interval-http-0 | before | 0.019373 | 0.000386 |
| interval-http-0 | after | 0.019423 | 0.000680 |
| interval-http-64 | before | 0.022899 | 0.000473 |
| interval-http-64 | after | 0.023036 | 0.000994 |
| interval-http-256 | before | 0.030509 | 0.000206 |
| interval-http-256 | after | 0.030866 | 0.001246 |
| interval-width-Integer8-64 | before | 0.014547 | 0.000500 |
| interval-width-Integer8-64 | after | 0.014214 | 0.000410 |
| interval-width-Integer8-256 | before | 0.017637 | 0.000441 |
| interval-width-Integer8-256 | after | 0.017298 | 0.000840 |
| interval-width-Integer16-64 | before | 0.014430 | 0.001289 |
| interval-width-Integer16-64 | after | 0.014592 | 0.000141 |
| interval-width-Integer16-256 | before | 0.017288 | 0.000432 |
| interval-width-Integer16-256 | after | 0.017262 | 0.000597 |
| interval-width-Integer32-64 | before | 0.014759 | 0.001047 |
| interval-width-Integer32-64 | after | 0.014527 | 0.000463 |
| interval-width-Integer32-256 | before | 0.017677 | 0.000544 |
| interval-width-Integer32-256 | after | 0.017625 | 0.001456 |
| interval-width-Integer64-64 | before | 0.014524 | 0.001148 |
| interval-width-Integer64-64 | after | 0.014462 | 0.000173 |
| interval-width-Integer64-256 | before | 0.017434 | 0.000366 |
| interval-width-Integer64-256 | after | 0.017193 | 0.000516 |
| interval-width-UnsignedInteger16-64 | before | 0.014524 | 0.000553 |
| interval-width-UnsignedInteger16-64 | after | 0.014205 | 0.000279 |
| interval-width-UnsignedInteger16-256 | before | 0.017032 | 0.000422 |
| interval-width-UnsignedInteger16-256 | after | 0.017220 | 0.000320 |
| interval-width-UnsignedInteger32-64 | before | 0.015117 | 0.001039 |
| interval-width-UnsignedInteger32-64 | after | 0.014704 | 0.000451 |
| interval-width-UnsignedInteger32-256 | before | 0.017216 | 0.000567 |
| interval-width-UnsignedInteger32-256 | after | 0.017052 | 0.000847 |
| interval-width-UnsignedInteger64-64 | before | 0.014494 | 0.001582 |
| interval-width-UnsignedInteger64-64 | after | 0.014340 | 0.000346 |
| interval-width-UnsignedInteger64-256 | before | 0.017356 | 0.000381 |
| interval-width-UnsignedInteger64-256 | after | 0.017165 | 0.001235 |
| property-seven-24-20-1000-all-ok | before | 0.037826 | 0.001069 |
| property-seven-24-20-1000-all-ok | after | 0.038052 | 0.000437 |
| property-seven-24-20-1000-always-error | before | 0.036621 | 0.002646 |
| property-seven-24-20-1000-always-error | after | 0.036908 | 0.000648 |
| property-distinct-24-20-1000-all-ok | before | 0.036999 | 0.002363 |
| property-distinct-24-20-1000-all-ok | after | 0.037229 | 0.000625 |
| property-distinct-24-20-1000-always-error | before | 0.036298 | 0.001939 |
| property-distinct-24-20-1000-always-error | after | 0.036471 | 0.000879 |
| property-zero-24-20-1000-all-ok | before | 0.036883 | 0.001921 |
| property-zero-24-20-1000-all-ok | after | 0.036925 | 0.000748 |
| property-zero-24-20-1000-always-error | before | 0.035951 | 0.001597 |
| property-zero-24-20-1000-always-error | after | 0.036505 | 0.000566 |
| property-max-24-20-1000-all-ok | before | 0.038607 | 0.003733 |
| property-max-24-20-1000-all-ok | after | 0.038672 | 0.001293 |
| property-max-24-20-1000-always-error | before | 0.036146 | 0.001624 |
| property-max-24-20-1000-always-error | after | 0.036729 | 0.001781 |
| order-string-candidates | before | 0.036164 | 0.000182 |
| order-string-candidates | after | 0.036171 | 0.000271 |
| order-string-all-ok | before | 0.036436 | 0.001553 |
| order-string-all-ok | after | 0.036309 | 0.000471 |
| order-string-always-error | before | 0.036186 | 0.003019 |
| order-string-always-error | after | 0.036296 | 0.000369 |
| order-map-candidates | before | 0.036529 | 0.001209 |
| order-map-candidates | after | 0.036600 | 0.000292 |
| order-map-all-ok | before | 0.036448 | 0.001831 |
| order-map-all-ok | after | 0.036324 | 0.000667 |
| order-map-always-error | before | 0.036091 | 0.001576 |
| order-map-always-error | after | 0.036245 | 0.000747 |
| order-record-candidates | before | 0.036439 | 0.001988 |
| order-record-candidates | after | 0.036784 | 0.000479 |
| order-record-all-ok | before | 0.037059 | 0.003329 |
| order-record-all-ok | after | 0.037423 | 0.001435 |
| order-record-always-error | before | 0.037119 | 0.001428 |
| order-record-always-error | after | 0.037192 | 0.000486 |
| build-string-builder-8-0 | before | 0.016728 | 0.000333 |
| build-string-builder-8-0 | after | 0.016395 | 0.000794 |
| build-string-builder-all-8-0 | before | 0.016633 | 0.000582 |
| build-string-builder-all-8-0 | after | 0.016651 | 0.001185 |
| build-string-concatenate-8-0 | before | 0.016312 | 0.000191 |
| build-string-concatenate-8-0 | after | 0.016163 | 0.000531 |
| build-string-join-8-0 | before | 0.016183 | 0.000410 |
| build-string-join-8-0 | after | 0.015958 | 0.000117 |
| build-list-builder-8-0 | before | 0.016616 | 0.000624 |
| build-list-builder-8-0 | after | 0.016497 | 0.000241 |
| build-list-builder-all-8-0 | before | 0.016392 | 0.000561 |
| build-list-builder-all-8-0 | after | 0.015986 | 0.000467 |
| build-list-concatenate-8-0 | before | 0.016571 | 0.000807 |
| build-list-concatenate-8-0 | after | 0.016624 | 0.000560 |
| build-list-fold-8-0 | before | 0.017838 | 0.000965 |
| build-list-fold-8-0 | after | 0.017750 | 0.001041 |
| build-bytes-builder-8-0 | before | 0.017774 | 0.000588 |
| build-bytes-builder-8-0 | after | 0.018218 | 0.001281 |
| build-bytes-builder-all-8-0 | before | 0.018446 | 0.000382 |
| build-bytes-builder-all-8-0 | after | 0.018620 | 0.001288 |
| build-bytes-concatenate-8-0 | before | 0.018226 | 0.000255 |
| build-bytes-concatenate-8-0 | after | 0.018503 | 0.002413 |
| patterns-integer-100 | before | 0.014501 | 0.000946 |
| patterns-integer-100 | after | 0.014517 | 0.000229 |
| codegen-let-100 | before | 0.017495 | 0.000316 |
| codegen-let-100 | after | 0.016979 | 0.000561 |
| bridge-shared-8 | before | 0.004826 | 0.000380 |
| bridge-shared-8 | after | 0.004793 | 0.000395 |
| external-tests-normal-1 | before | 0.018413 | 0.000669 |
| external-tests-normal-1 | after | 0.018145 | 0.002093 |
| runtime-fib-short | before | 0.020037 | 0.001056 |
| runtime-fib-short | after | 0.019686 | 0.002482 |
| runtime-loop-short | before | 0.023917 | 0.000297 |
| runtime-loop-short | after | 0.023969 | 0.000996 |
| runtime-list-short | before | 0.029660 | 0.000400 |
| runtime-list-short | after | 0.029862 | 0.000743 |
| runtime-tree-short | before | 0.018667 | 0.000186 |
| runtime-tree-short | after | 0.018517 | 0.001495 |
| runtime-eval-short | before | 0.022291 | 0.000251 |
| runtime-eval-short | after | 0.022847 | 0.001536 |
| runtime-string-short | before | 0.016851 | 0.000515 |
| runtime-string-short | after | 0.017016 | 0.000408 |
| runtime-println-short | before | 0.017089 | 0.000585 |
| runtime-println-short | after | 0.016992 | 0.000272 |
| runtime-lines-short | before | 0.017024 | 0.000409 |
| runtime-lines-short | after | 0.016958 | 0.000174 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.7958e-05 | 8.33e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.167e-06 | 5.01e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1042e-05 | 1.251e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.6375e-05 | 1.625e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.25e-06 | 4.99e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.9334e-05 | 1.292e-06 |
| unique_nodes | count | bridge-shared-8 | after | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | after | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | after | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | after | 5 | 7 | 0 |
| runtime_compilations | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| runtime_compilations | count | external-tests-normal-1 | after | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | after | 5 | 1 | 0 |

## 比較状態と機能

```json
{
  "commits": {
    "before": "6124775788579e60530f55fb85570f26ef7fa900",
    "after": "bbc22ac0913910d26936f4b2e2def2204da93c4f"
  },
  "features": {
    "before": {
      "shrink_steps": true,
      "builders": true,
      "timing_probe": true
    },
    "after": {
      "shrink_steps": true,
      "builders": true,
      "timing_probe": true
    }
  },
  "skipped": [],
  "unavailable_probes": {}
}
```

## 目標

| 目標 | 判定 | 値 | 上限 |
|---|---|---:|---:|
| functions-main-0-0 | 判定不能 | None | 0.002 |
| functions-main-0-1 | 判定不能 | None | 0.002 |
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 判定不能 | None | 0.002 |
| functions-main-1000-0 | 判定不能 | None | 0.002102529199999026 |
| functions-main-1000-1 | 判定不能 | None | 0.0021085040999992088 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0027710417000008647 |
| functions-args-1000-1 | 判定不能 | None | 0.002715016700000206 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0021773209000002683 |
| functions-modules-1000-1 | 判定不能 | None | 0.002138441699997884 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028551208999999748 |
| higher-1-300 | 判定不能 | None | 0.0031484457999994223 |
| classes-300 | 判定不能 | None | 0.003751929200001314 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 判定不能 | None | 0.002 |
| interval-range-64 | 判定不能 | None | 0.0023415917000022546 |
| interval-range-256 | 判定不能 | None | 0.0037637499999988223 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 判定不能 | None | 0.002289945800001192 |
| interval-http-256 | 判定不能 | None | 0.0030508666000002905 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003782570900000337 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003662137500000995 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0036998708999988143 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0036297707999978003 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0036882665999996792 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003595125000001076 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0038607291999994686 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0036145916999998917 |
| order-string-candidates | 判定不能 | None | 0.0036164250000013 |
| order-string-all-ok | 判定不能 | None | 0.003643633299998328 |
| order-string-always-error | 判定不能 | None | 0.003618558300001951 |
| order-map-candidates | 判定不能 | None | 0.003652900000000159 |
| order-map-all-ok | 判定不能 | None | 0.003644770900001504 |
| order-map-always-error | 判定不能 | None | 0.003609070899997846 |
| order-record-candidates | 判定不能 | None | 0.0036439374999986287 |
| order-record-all-ok | 判定不能 | None | 0.0037058583000003868 |
| order-record-always-error | 判定不能 | None | 0.0037119167000014388 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.0020037333000004764 |
| runtime-loop-short | 判定不能 | None | 0.002391658300001609 |
| runtime-list-short | 判定不能 | None | 0.002965983300001085 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022290749999996254 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 判定不能 | None | 0.002 |
| bridge-shared-8 | 判定不能 | None | 0.002 |
| external-tests-normal-1 | 判定不能 | None | 0.002 |

時間差が2 ms未満、非正、または両標本集合のIQRの和以下なら比率は判定不能。確保量と整数計数には2 msを適用しない。標本数不足も合格にしない。

## 別実行と未取得

段別時間は補助バイナリのload_parse・resolve・typeck。読み込みとlex/parseは公開loaderの一つの区間に含む。reparseは同じ読み込み済みバイト列の別パスであり、load_parseへ加算しない。
RSSは既存rss.pyの独立実行。alloc-statsは別targetのバイナリ。全標本・照合出力・コマンドはsection JSONに保存する。
Fail正規化の内部訪問節数・縮小器内部の生成/比較回数は未取得。shrinksとshrinkWorkは実出力から検査する。
samplyはprofile.shの別実行で取得する。未取得のプロファイルから原因を断定しない。

## 段ごとの外側時間

```json
{
  "16.2": {
    "verify": 2.116475125000022,
    "cli": 5.366293497999919,
    "warmup": 0.5970308770000372,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.8834611659999894,
    "cli": 12.027584709999985,
    "warmup": 1.3861682919999225,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2630971250000016,
    "cli": 9.110468375999915,
    "warmup": 1.2553189139999859,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.37776833400002374,
    "cli": 3.7491317909999964,
    "warmup": 0.3772543730000564,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10082141600000227,
    "cli": 0.28094012500000076,
    "warmup": 0.02948583299999541,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.038837457999989056,
    "cli": 0.33546933399998125,
    "warmup": 0.034409124999967844,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.01066433299999403,
    "cli": 0.20760158300001308,
    "warmup": 0.00919350000000918,
    "probe_warmup": 0.00849879200001169,
    "rss": 0,
    "stages": 0.040737667999991345,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.043179667000003974,
    "cli": 0.3471159580000176,
    "warmup": 0.03683216700000003,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17834862500004078
  },
  "runtime": {
    "verify": 0.34401570900001843,
    "cli": 2.966415417000036,
    "warmup": 0.332948373000022,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
