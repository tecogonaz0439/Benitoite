# 版どうしの性能比較

候補: `5ceb0d3d752a28eaff3bab26c4d4a89bd251dee4`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013175 | 0.000266 |
| functions-main-0-0 | after | 0.014011 | 0.000836 |
| functions-main-0-1 | before | 0.013210 | 0.001142 |
| functions-main-0-1 | after | 0.014081 | 0.000388 |
| functions-main-64-0 | before | 0.013768 | 0.003387 |
| functions-main-64-0 | after | 0.014284 | 0.000279 |
| functions-main-256-0 | before | 0.015342 | 0.000773 |
| functions-main-256-0 | after | 0.015945 | 0.000516 |
| functions-main-1000-0 | before | 0.021066 | 0.000464 |
| functions-main-1000-0 | after | 0.021825 | 0.002043 |
| functions-main-1000-1 | before | 0.020744 | 0.000428 |
| functions-main-1000-1 | after | 0.022225 | 0.001592 |
| functions-args-0-0 | before | 0.013300 | 0.002410 |
| functions-args-0-0 | after | 0.013705 | 0.000192 |
| functions-args-0-1 | before | 0.013349 | 0.000981 |
| functions-args-0-1 | after | 0.013772 | 0.000145 |
| functions-args-1000-0 | before | 0.026716 | 0.000313 |
| functions-args-1000-0 | after | 0.028314 | 0.001581 |
| functions-args-1000-1 | before | 0.026694 | 0.000475 |
| functions-args-1000-1 | after | 0.027845 | 0.001456 |
| functions-modules-0-0 | before | 0.013477 | 0.000707 |
| functions-modules-0-0 | after | 0.013720 | 0.000297 |
| functions-modules-0-1 | before | 0.013321 | 0.001012 |
| functions-modules-0-1 | after | 0.013834 | 0.000047 |
| functions-modules-1000-0 | before | 0.021132 | 0.000372 |
| functions-modules-1000-0 | after | 0.022066 | 0.001286 |
| functions-modules-1000-1 | before | 0.021142 | 0.000410 |
| functions-modules-1000-1 | after | 0.021991 | 0.001131 |
| existing-fib | before | 0.013973 | 0.000940 |
| existing-fib | after | 0.014522 | 0.000332 |
| existing-loop | before | 0.013848 | 0.001064 |
| existing-loop | after | 0.014047 | 0.000065 |
| existing-string | before | 0.013735 | 0.000979 |
| existing-string | after | 0.014451 | 0.000276 |
| higher-0-0 | before | 0.013331 | 0.001331 |
| higher-0-0 | after | 0.013842 | 0.000470 |
| higher-1-0 | before | 0.014468 | 0.000702 |
| higher-1-0 | after | 0.014913 | 0.000269 |
| classes-0 | before | 0.017896 | 0.000590 |
| classes-0 | after | 0.020109 | 0.001175 |
| higher-0-300 | before | 0.028818 | 0.000418 |
| higher-0-300 | after | 0.030981 | 0.002058 |
| higher-1-300 | before | 0.030922 | 0.000429 |
| higher-1-300 | after | 0.032268 | 0.001091 |
| classes-300 | before | 0.037531 | 0.000852 |
| classes-300 | after | 0.040741 | 0.001428 |
| depth-0-8 | before | 0.015402 | 0.000854 |
| depth-0-8 | after | 0.015785 | 0.000230 |
| depth-1-8 | before | 0.015519 | 0.001268 |
| depth-1-8 | after | 0.016005 | 0.000272 |
| f1-nofail-call | before | 0.014580 | 0.001036 |
| f1-nofail-call | after | 0.015105 | 0.000467 |
| f1-join-effects | before | 0.014263 | 0.001609 |
| f1-join-effects | after | 0.014599 | 0.000139 |
| control-16.3 | before | 0.013219 | 0.001052 |
| control-16.3 | after | 0.013370 | 0.000231 |
| interval-bind-64 | before | 0.013290 | 0.000664 |
| interval-bind-64 | after | 0.013570 | 0.000104 |
| interval-bind-256 | before | 0.014018 | 0.001296 |
| interval-bind-256 | after | 0.014232 | 0.000199 |
| interval-add-64 | before | 0.013976 | 0.000965 |
| interval-add-64 | after | 0.013653 | 0.000815 |
| interval-add-256 | before | 0.014915 | 0.000767 |
| interval-add-256 | after | 0.015403 | 0.000312 |
| interval-flow-64 | before | 0.014273 | 0.001330 |
| interval-flow-64 | after | 0.014582 | 0.000189 |
| interval-flow-256 | before | 0.016932 | 0.000725 |
| interval-flow-256 | after | 0.017472 | 0.000223 |
| interval-range-0 | before | 0.019074 | 0.000530 |
| interval-range-0 | after | 0.021839 | 0.000997 |
| interval-range-64 | before | 0.022930 | 0.000388 |
| interval-range-64 | after | 0.025690 | 0.000939 |
| interval-range-256 | before | 0.035723 | 0.000435 |
| interval-range-256 | after | 0.038849 | 0.000715 |
| interval-http-0 | before | 0.019077 | 0.000606 |
| interval-http-0 | after | 0.021307 | 0.001307 |
| interval-http-64 | before | 0.022298 | 0.000434 |
| interval-http-64 | after | 0.025243 | 0.001706 |
| interval-http-256 | before | 0.029375 | 0.000261 |
| interval-http-256 | after | 0.033249 | 0.001183 |
| interval-width-Integer8-64 | before | 0.014013 | 0.001616 |
| interval-width-Integer8-64 | after | 0.014446 | 0.000137 |
| interval-width-Integer8-256 | before | 0.017158 | 0.000600 |
| interval-width-Integer8-256 | after | 0.017569 | 0.000242 |
| interval-width-Integer16-64 | before | 0.013841 | 0.001154 |
| interval-width-Integer16-64 | after | 0.014667 | 0.000424 |
| interval-width-Integer16-256 | before | 0.016786 | 0.000544 |
| interval-width-Integer16-256 | after | 0.017313 | 0.000275 |
| interval-width-Integer32-64 | before | 0.014052 | 0.001113 |
| interval-width-Integer32-64 | after | 0.014635 | 0.000298 |
| interval-width-Integer32-256 | before | 0.016711 | 0.000609 |
| interval-width-Integer32-256 | after | 0.017309 | 0.000598 |
| interval-width-Integer64-64 | before | 0.014885 | 0.001184 |
| interval-width-Integer64-64 | after | 0.015345 | 0.000108 |
| interval-width-Integer64-256 | before | 0.017824 | 0.000338 |
| interval-width-Integer64-256 | after | 0.018566 | 0.000603 |
| interval-width-UnsignedInteger16-64 | before | 0.014770 | 0.000714 |
| interval-width-UnsignedInteger16-64 | after | 0.015637 | 0.001511 |
| interval-width-UnsignedInteger16-256 | before | 0.017561 | 0.000493 |
| interval-width-UnsignedInteger16-256 | after | 0.018535 | 0.000190 |
| interval-width-UnsignedInteger32-64 | before | 0.014692 | 0.000383 |
| interval-width-UnsignedInteger32-64 | after | 0.015357 | 0.000316 |
| interval-width-UnsignedInteger32-256 | before | 0.016963 | 0.000501 |
| interval-width-UnsignedInteger32-256 | after | 0.017844 | 0.000203 |
| interval-width-UnsignedInteger64-64 | before | 0.014348 | 0.000999 |
| interval-width-UnsignedInteger64-64 | after | 0.015115 | 0.000673 |
| interval-width-UnsignedInteger64-256 | before | 0.017060 | 0.000578 |
| interval-width-UnsignedInteger64-256 | after | 0.017232 | 0.000402 |
| property-seven-24-20-1000-all-ok | before | 0.036892 | 0.002951 |
| property-seven-24-20-1000-all-ok | after | 0.041315 | 0.000435 |
| property-seven-24-20-1000-always-error | before | 0.036019 | 0.000878 |
| property-seven-24-20-1000-always-error | after | 0.040082 | 0.000956 |
| property-distinct-24-20-1000-all-ok | before | 0.035800 | 0.003446 |
| property-distinct-24-20-1000-all-ok | after | 0.040042 | 0.000986 |
| property-distinct-24-20-1000-always-error | before | 0.035382 | 0.001244 |
| property-distinct-24-20-1000-always-error | after | 0.039677 | 0.000480 |
| property-zero-24-20-1000-all-ok | before | 0.036652 | 0.000926 |
| property-zero-24-20-1000-all-ok | after | 0.040620 | 0.000675 |
| property-zero-24-20-1000-always-error | before | 0.035622 | 0.001235 |
| property-zero-24-20-1000-always-error | after | 0.039604 | 0.000334 |
| property-max-24-20-1000-all-ok | before | 0.037228 | 0.001023 |
| property-max-24-20-1000-all-ok | after | 0.040872 | 0.000798 |
| property-max-24-20-1000-always-error | before | 0.035253 | 0.002353 |
| property-max-24-20-1000-always-error | after | 0.039649 | 0.000298 |
| order-string-candidates | before | 0.035204 | 0.002040 |
| order-string-candidates | after | 0.039177 | 0.000341 |
| order-string-all-ok | before | 0.036330 | 0.001034 |
| order-string-all-ok | after | 0.040044 | 0.000704 |
| order-string-always-error | before | 0.035020 | 0.001478 |
| order-string-always-error | after | 0.039344 | 0.000350 |
| order-map-candidates | before | 0.035261 | 0.002320 |
| order-map-candidates | after | 0.039569 | 0.000635 |
| order-map-all-ok | before | 0.035560 | 0.001289 |
| order-map-all-ok | after | 0.039949 | 0.000515 |
| order-map-always-error | before | 0.036941 | 0.001422 |
| order-map-always-error | after | 0.039584 | 0.000844 |
| order-record-candidates | before | 0.035740 | 0.002015 |
| order-record-candidates | after | 0.039999 | 0.000314 |
| order-record-all-ok | before | 0.036174 | 0.001642 |
| order-record-all-ok | after | 0.040412 | 0.000311 |
| order-record-always-error | before | 0.035909 | 0.001341 |
| order-record-always-error | after | 0.040126 | 0.000597 |
| build-string-builder-8-0 | before | 0.016054 | 0.000695 |
| build-string-builder-8-0 | after | 0.016198 | 0.000292 |
| build-string-builder-all-8-0 | before | 0.016432 | 0.000219 |
| build-string-builder-all-8-0 | after | 0.016329 | 0.000176 |
| build-string-concatenate-8-0 | before | 0.015989 | 0.001052 |
| build-string-concatenate-8-0 | after | 0.016613 | 0.000371 |
| build-string-join-8-0 | before | 0.016184 | 0.000570 |
| build-string-join-8-0 | after | 0.016274 | 0.000238 |
| build-list-builder-8-0 | before | 0.016263 | 0.000188 |
| build-list-builder-8-0 | after | 0.017015 | 0.001337 |
| build-list-builder-all-8-0 | before | 0.015972 | 0.000808 |
| build-list-builder-all-8-0 | after | 0.016384 | 0.001781 |
| build-list-concatenate-8-0 | before | 0.016092 | 0.000639 |
| build-list-concatenate-8-0 | after | 0.016601 | 0.000297 |
| build-list-fold-8-0 | before | 0.016242 | 0.000577 |
| build-list-fold-8-0 | after | 0.016587 | 0.000639 |
| build-bytes-builder-8-0 | before | 0.016031 | 0.000826 |
| build-bytes-builder-8-0 | after | 0.016486 | 0.002069 |
| build-bytes-builder-all-8-0 | before | 0.016134 | 0.000850 |
| build-bytes-builder-all-8-0 | after | 0.016741 | 0.000451 |
| build-bytes-concatenate-8-0 | before | 0.016393 | 0.000730 |
| build-bytes-concatenate-8-0 | after | 0.017080 | 0.000350 |
| patterns-integer-100 | before | 0.015011 | 0.001230 |
| patterns-integer-100 | after | 0.015382 | 0.000225 |
| codegen-let-100 | before | 0.017479 | 0.000390 |
| codegen-let-100 | after | 0.017809 | 0.001191 |
| bridge-shared-8 | before | 0.005479 | 0.000321 |
| bridge-shared-8 | after | 0.005149 | 0.000394 |
| external-tests-normal-1 | before | 0.018322 | 0.002473 |
| external-tests-normal-1 | after | 0.019094 | 0.000273 |
| runtime-fib-short | before | 0.018356 | 0.000655 |
| runtime-fib-short | after | 0.018606 | 0.001001 |
| runtime-loop-short | before | 0.023975 | 0.000260 |
| runtime-loop-short | after | 0.024524 | 0.000735 |
| runtime-list-short | before | 0.029496 | 0.000412 |
| runtime-list-short | after | 0.030244 | 0.000583 |
| runtime-tree-short | before | 0.018519 | 0.000514 |
| runtime-tree-short | after | 0.018964 | 0.001325 |
| runtime-eval-short | before | 0.022020 | 0.000243 |
| runtime-eval-short | after | 0.023521 | 0.001106 |
| runtime-string-short | before | 0.017075 | 0.000157 |
| runtime-string-short | after | 0.017548 | 0.000811 |
| runtime-println-short | before | 0.017119 | 0.000619 |
| runtime-println-short | after | 0.017943 | 0.001036 |
| runtime-lines-short | before | 0.016860 | 0.000442 |
| runtime-lines-short | after | 0.019280 | 0.000777 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.8333e-05 | 1.708e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.167e-06 | 3.76e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.175e-05 | 2.124e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5459e-05 | 1.167e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.166e-06 | 4.18e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.8792e-05 | 1.542e-06 |
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
    "after": "5ceb0d3d752a28eaff3bab26c4d4a89bd251dee4"
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
| functions-main-1000-0 | 判定不能 | None | 0.002106595899999775 |
| functions-main-1000-1 | 判定不能 | None | 0.002074383299999738 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.002671649999999204 |
| functions-args-1000-1 | 判定不能 | None | 0.0026694415999998 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002113191600000164 |
| functions-modules-1000-1 | 判定不能 | None | 0.0021141833000001497 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 退行の疑い | 0.0022126670000091053 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028817791999998124 |
| higher-1-300 | 判定不能 | None | 0.0030921582999994257 |
| classes-300 | 達成 | 0.0032100410000026613 | 0.0037530625000002263 |
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
| interval-range-0 | 退行の疑い | 0.002764500000012049 | 0.002 |
| interval-range-64 | 退行の疑い | 0.0027599570000091944 | 0.002292983399999571 |
| interval-range-256 | 達成 | 0.003125999999994633 | 0.0035723000000004394 |
| interval-http-0 | 退行の疑い | 0.002229875000011816 | 0.002 |
| interval-http-64 | 退行の疑い | 0.0029450420000074473 | 0.0022297832999996106 |
| interval-http-256 | 退行の疑い | 0.0038739589999892132 | 0.002937533300000439 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-256 | 達成 | 0.0009739999999993643 | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 達成 | 0.0008807910000001584 | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 退行の疑い | 0.004422875000003046 | 0.0036891999999994598 |
| property-seven-24-20-1000-always-error | 退行の疑い | 0.004063124999987622 | 0.003601900000001024 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003579974999999536 |
| property-distinct-24-20-1000-always-error | 退行の疑い | 0.0042946249999857855 | 0.0035382375000011738 |
| property-zero-24-20-1000-all-ok | 退行の疑い | 0.003967417000012574 | 0.0036652207999992473 |
| property-zero-24-20-1000-always-error | 退行の疑い | 0.003982041000000436 | 0.003562212500000328 |
| property-max-24-20-1000-all-ok | 達成 | 0.0036438740000050984 | 0.003722833400000525 |
| property-max-24-20-1000-always-error | 退行の疑い | 0.00439612500001374 | 0.0035252665999991 |
| order-string-candidates | 退行の疑い | 0.003973082999991107 | 0.003520412500000703 |
| order-string-all-ok | 退行の疑い | 0.00371391699998469 | 0.0036330042000003006 |
| order-string-always-error | 退行の疑い | 0.004324292000006835 | 0.0035019624999989675 |
| order-map-candidates | 退行の疑い | 0.0043087090000142325 | 0.003526070799999559 |
| order-map-all-ok | 退行の疑い | 0.004388916000010568 | 0.00355597089999975 |
| order-map-always-error | 達成 | 0.0026425000000074306 | 0.003694108399999152 |
| order-record-candidates | 退行の疑い | 0.004258875000004991 | 0.0035740332999992575 |
| order-record-all-ok | 退行の疑い | 0.004238083000004167 | 0.0036174291999998332 |
| order-record-always-error | 退行の疑い | 0.004217206999996392 | 0.003590870899999743 |
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
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0023974625000008133 |
| runtime-list-short | 判定不能 | None | 0.002949616600000127 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 達成 | 0.0015016669999994292 | 0.002201954199999534 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 退行の疑い | 0.0024198749999868596 | 0.002 |
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
    "verify": 1.7145135829999987,
    "cli": 5.347103501999996,
    "warmup": 0.5944662900000566,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.972432374999997,
    "cli": 12.131540961999946,
    "warmup": 1.391405705999972,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3310735830000056,
    "cli": 9.292872374000012,
    "warmup": 1.2956057059999608,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3783849589999875,
    "cli": 3.622313083999998,
    "warmup": 0.3619554610000364,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10136329099999841,
    "cli": 0.2925040829999972,
    "warmup": 0.03012504200000876,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03733979100000795,
    "cli": 0.34419175000000735,
    "warmup": 0.03486800000000301,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010431833999987816,
    "cli": 0.2238988330000069,
    "warmup": 0.009904959000010649,
    "probe_warmup": 0.009127625000004969,
    "rss": 0,
    "stages": 0.04178537600000709,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04251237500000116,
    "cli": 0.35737666699999693,
    "warmup": 0.0366613740000048,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18756054100002473
  },
  "runtime": {
    "verify": 0.3480216670000118,
    "cli": 2.9919786260000194,
    "warmup": 0.33298953899999617,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-29）

この比較は R30.3c（`38541bcd`）と R30.2c〜R30.2e（`5ceb0d3d`）の二つの取り込みをまとめて測った。九つの区分の出力の照合はすべて通った。退行の疑いは20件で、次の三つに分かれる。

- `property-*`・`order-*`・`classes-0`・`interval-range-*`（+12〜14%、約 +1.5 ms）: Trait（型クラス）と、Trait を import する標準モジュールを使う入力である。R30.2c で `Show[ScopeError]` を Trait の側へ移し、Trait が Scope を import するようになった費用で、設計者が採った（README の R30.2c の停止の項目と RV-R30.2d の中1）。
- `runtime-lines-short`（+14.4%、16.86→19.28 ms）: R30.2 の後の +52.6%（25.60 ms）から戻った。残りは、File が Trait を除いた Scope を読む分と、R20 の段の型検査の固定の費用（TODO-304）である。
- `interval-http-*`: 既知（R20.0b の Http の import の費用、TODO-304）。

全94入力の after/before の中央値の比は 1.042。標準ライブラリの検査の結果の使い回し（TODO-304）で、これらはまとめて消える見込みである。
