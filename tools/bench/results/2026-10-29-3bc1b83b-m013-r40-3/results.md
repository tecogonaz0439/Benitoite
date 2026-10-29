# 版どうしの性能比較

候補: `3bc1b83b1b220a0234e7994aba7ad55e7d0130bb`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013565 | 0.001572 |
| functions-main-0-0 | after | 0.014127 | 0.000385 |
| functions-main-0-1 | before | 0.013296 | 0.000790 |
| functions-main-0-1 | after | 0.014130 | 0.000321 |
| functions-main-64-0 | before | 0.013968 | 0.001322 |
| functions-main-64-0 | after | 0.014298 | 0.000142 |
| functions-main-256-0 | before | 0.016228 | 0.000983 |
| functions-main-256-0 | after | 0.015821 | 0.000356 |
| functions-main-1000-0 | before | 0.020690 | 0.000266 |
| functions-main-1000-0 | after | 0.021528 | 0.001978 |
| functions-main-1000-1 | before | 0.020970 | 0.000531 |
| functions-main-1000-1 | after | 0.021649 | 0.002048 |
| functions-args-0-0 | before | 0.013437 | 0.001391 |
| functions-args-0-0 | after | 0.013716 | 0.000130 |
| functions-args-0-1 | before | 0.013352 | 0.001730 |
| functions-args-0-1 | after | 0.013750 | 0.000270 |
| functions-args-1000-0 | before | 0.026755 | 0.000413 |
| functions-args-1000-0 | after | 0.029174 | 0.001715 |
| functions-args-1000-1 | before | 0.026867 | 0.000625 |
| functions-args-1000-1 | after | 0.028741 | 0.002444 |
| functions-modules-0-0 | before | 0.013363 | 0.000778 |
| functions-modules-0-0 | after | 0.013820 | 0.000170 |
| functions-modules-0-1 | before | 0.013858 | 0.001234 |
| functions-modules-0-1 | after | 0.014248 | 0.000433 |
| functions-modules-1000-0 | before | 0.021065 | 0.000523 |
| functions-modules-1000-0 | after | 0.022359 | 0.002011 |
| functions-modules-1000-1 | before | 0.020997 | 0.000214 |
| functions-modules-1000-1 | after | 0.022146 | 0.002327 |
| existing-fib | before | 0.014448 | 0.000862 |
| existing-fib | after | 0.014608 | 0.000186 |
| existing-loop | before | 0.013996 | 0.000936 |
| existing-loop | after | 0.014572 | 0.000236 |
| existing-string | before | 0.013766 | 0.001029 |
| existing-string | after | 0.014239 | 0.000208 |
| higher-0-0 | before | 0.013702 | 0.001060 |
| higher-0-0 | after | 0.013603 | 0.000618 |
| higher-1-0 | before | 0.014391 | 0.002361 |
| higher-1-0 | after | 0.014969 | 0.000384 |
| classes-0 | before | 0.017763 | 0.000368 |
| classes-0 | after | 0.019701 | 0.001321 |
| higher-0-300 | before | 0.028191 | 0.000170 |
| higher-0-300 | after | 0.029441 | 0.001549 |
| higher-1-300 | before | 0.031020 | 0.000334 |
| higher-1-300 | after | 0.032146 | 0.000682 |
| classes-300 | before | 0.038632 | 0.000671 |
| classes-300 | after | 0.040974 | 0.000284 |
| depth-0-8 | before | 0.014746 | 0.001496 |
| depth-0-8 | after | 0.015721 | 0.000232 |
| depth-1-8 | before | 0.016045 | 0.001112 |
| depth-1-8 | after | 0.016549 | 0.000474 |
| f1-nofail-call | before | 0.015304 | 0.000913 |
| f1-nofail-call | after | 0.015248 | 0.000257 |
| f1-join-effects | before | 0.014998 | 0.001018 |
| f1-join-effects | after | 0.015109 | 0.000530 |
| control-16.3 | before | 0.013448 | 0.000752 |
| control-16.3 | after | 0.013789 | 0.000230 |
| interval-bind-64 | before | 0.013649 | 0.001746 |
| interval-bind-64 | after | 0.014209 | 0.000529 |
| interval-bind-256 | before | 0.014595 | 0.001537 |
| interval-bind-256 | after | 0.014274 | 0.000179 |
| interval-add-64 | before | 0.013635 | 0.000728 |
| interval-add-64 | after | 0.013843 | 0.000235 |
| interval-add-256 | before | 0.015010 | 0.001696 |
| interval-add-256 | after | 0.015404 | 0.000535 |
| interval-flow-64 | before | 0.014064 | 0.001519 |
| interval-flow-64 | after | 0.014856 | 0.000293 |
| interval-flow-256 | before | 0.016914 | 0.000465 |
| interval-flow-256 | after | 0.017502 | 0.000271 |
| interval-range-0 | before | 0.018348 | 0.000391 |
| interval-range-0 | after | 0.020847 | 0.001793 |
| interval-range-64 | before | 0.023025 | 0.000247 |
| interval-range-64 | after | 0.025766 | 0.001033 |
| interval-range-256 | before | 0.035729 | 0.000912 |
| interval-range-256 | after | 0.038723 | 0.000550 |
| interval-http-0 | before | 0.018646 | 0.000545 |
| interval-http-0 | after | 0.021439 | 0.002072 |
| interval-http-64 | before | 0.022312 | 0.000471 |
| interval-http-64 | after | 0.025088 | 0.001240 |
| interval-http-256 | before | 0.030099 | 0.000546 |
| interval-http-256 | after | 0.032946 | 0.000613 |
| interval-width-Integer8-64 | before | 0.014119 | 0.001417 |
| interval-width-Integer8-64 | after | 0.014716 | 0.000580 |
| interval-width-Integer8-256 | before | 0.017142 | 0.000726 |
| interval-width-Integer8-256 | after | 0.017622 | 0.000484 |
| interval-width-Integer16-64 | before | 0.014169 | 0.001311 |
| interval-width-Integer16-64 | after | 0.014376 | 0.000120 |
| interval-width-Integer16-256 | before | 0.017012 | 0.000638 |
| interval-width-Integer16-256 | after | 0.017512 | 0.000248 |
| interval-width-Integer32-64 | before | 0.013848 | 0.000867 |
| interval-width-Integer32-64 | after | 0.014443 | 0.000214 |
| interval-width-Integer32-256 | before | 0.017041 | 0.000541 |
| interval-width-Integer32-256 | after | 0.017543 | 0.000211 |
| interval-width-Integer64-64 | before | 0.014007 | 0.002021 |
| interval-width-Integer64-64 | after | 0.014507 | 0.000212 |
| interval-width-Integer64-256 | before | 0.016998 | 0.000464 |
| interval-width-Integer64-256 | after | 0.017399 | 0.000470 |
| interval-width-UnsignedInteger16-64 | before | 0.014064 | 0.001779 |
| interval-width-UnsignedInteger16-64 | after | 0.014301 | 0.000151 |
| interval-width-UnsignedInteger16-256 | before | 0.016771 | 0.000797 |
| interval-width-UnsignedInteger16-256 | after | 0.017185 | 0.000193 |
| interval-width-UnsignedInteger32-64 | before | 0.013916 | 0.001262 |
| interval-width-UnsignedInteger32-64 | after | 0.014405 | 0.000260 |
| interval-width-UnsignedInteger32-256 | before | 0.016421 | 0.000649 |
| interval-width-UnsignedInteger32-256 | after | 0.017315 | 0.000306 |
| interval-width-UnsignedInteger64-64 | before | 0.013972 | 0.001163 |
| interval-width-UnsignedInteger64-64 | after | 0.014833 | 0.000625 |
| interval-width-UnsignedInteger64-256 | before | 0.017091 | 0.000515 |
| interval-width-UnsignedInteger64-256 | after | 0.017145 | 0.000245 |
| property-seven-24-20-1000-all-ok | before | 0.037229 | 0.003136 |
| property-seven-24-20-1000-all-ok | after | 0.041383 | 0.001998 |
| property-seven-24-20-1000-always-error | before | 0.035426 | 0.004063 |
| property-seven-24-20-1000-always-error | after | 0.039971 | 0.000901 |
| property-distinct-24-20-1000-all-ok | before | 0.037410 | 0.001747 |
| property-distinct-24-20-1000-all-ok | after | 0.041493 | 0.001464 |
| property-distinct-24-20-1000-always-error | before | 0.035619 | 0.001215 |
| property-distinct-24-20-1000-always-error | after | 0.040053 | 0.000751 |
| property-zero-24-20-1000-all-ok | before | 0.037214 | 0.001363 |
| property-zero-24-20-1000-all-ok | after | 0.040594 | 0.000707 |
| property-zero-24-20-1000-always-error | before | 0.036051 | 0.001512 |
| property-zero-24-20-1000-always-error | after | 0.039477 | 0.000700 |
| property-max-24-20-1000-all-ok | before | 0.037274 | 0.001533 |
| property-max-24-20-1000-all-ok | after | 0.041345 | 0.000625 |
| property-max-24-20-1000-always-error | before | 0.037640 | 0.001948 |
| property-max-24-20-1000-always-error | after | 0.040470 | 0.001212 |
| order-string-candidates | before | 0.039703 | 0.002682 |
| order-string-candidates | after | 0.042866 | 0.001413 |
| order-string-all-ok | before | 0.040159 | 0.002118 |
| order-string-all-ok | after | 0.044441 | 0.001169 |
| order-string-always-error | before | 0.039071 | 0.003800 |
| order-string-always-error | after | 0.042747 | 0.001931 |
| order-map-candidates | before | 0.035660 | 0.002119 |
| order-map-candidates | after | 0.039785 | 0.000375 |
| order-map-all-ok | before | 0.036068 | 0.002379 |
| order-map-all-ok | after | 0.039676 | 0.000454 |
| order-map-always-error | before | 0.035841 | 0.001704 |
| order-map-always-error | after | 0.040042 | 0.000203 |
| order-record-candidates | before | 0.035661 | 0.001790 |
| order-record-candidates | after | 0.040406 | 0.000586 |
| order-record-all-ok | before | 0.036403 | 0.001774 |
| order-record-all-ok | after | 0.040439 | 0.000364 |
| order-record-always-error | before | 0.037864 | 0.001631 |
| order-record-always-error | after | 0.041056 | 0.000801 |
| build-string-builder-8-0 | before | 0.016336 | 0.000321 |
| build-string-builder-8-0 | after | 0.016620 | 0.002578 |
| build-string-builder-all-8-0 | before | 0.016079 | 0.000463 |
| build-string-builder-all-8-0 | after | 0.016738 | 0.000378 |
| build-string-concatenate-8-0 | before | 0.016072 | 0.000499 |
| build-string-concatenate-8-0 | after | 0.016433 | 0.001077 |
| build-string-join-8-0 | before | 0.016156 | 0.000573 |
| build-string-join-8-0 | after | 0.016659 | 0.000156 |
| build-list-builder-8-0 | before | 0.016233 | 0.000361 |
| build-list-builder-8-0 | after | 0.017020 | 0.000614 |
| build-list-builder-all-8-0 | before | 0.016180 | 0.000509 |
| build-list-builder-all-8-0 | after | 0.016706 | 0.000260 |
| build-list-concatenate-8-0 | before | 0.016176 | 0.000457 |
| build-list-concatenate-8-0 | after | 0.016704 | 0.000621 |
| build-list-fold-8-0 | before | 0.016164 | 0.000691 |
| build-list-fold-8-0 | after | 0.016538 | 0.000195 |
| build-bytes-builder-8-0 | before | 0.016425 | 0.000359 |
| build-bytes-builder-8-0 | after | 0.017165 | 0.000828 |
| build-bytes-builder-all-8-0 | before | 0.016432 | 0.000463 |
| build-bytes-builder-all-8-0 | after | 0.016840 | 0.001649 |
| build-bytes-concatenate-8-0 | before | 0.016550 | 0.000422 |
| build-bytes-concatenate-8-0 | after | 0.017010 | 0.000271 |
| patterns-integer-100 | before | 0.014861 | 0.001291 |
| patterns-integer-100 | after | 0.015305 | 0.000172 |
| codegen-let-100 | before | 0.017751 | 0.000421 |
| codegen-let-100 | after | 0.018295 | 0.002436 |
| bridge-shared-8 | before | 0.004966 | 0.000251 |
| bridge-shared-8 | after | 0.004953 | 0.000533 |
| external-tests-normal-1 | before | 0.018896 | 0.000306 |
| external-tests-normal-1 | after | 0.019266 | 0.001653 |
| runtime-fib-short | before | 0.018070 | 0.000521 |
| runtime-fib-short | after | 0.018904 | 0.002127 |
| runtime-loop-short | before | 0.024220 | 0.000458 |
| runtime-loop-short | after | 0.025155 | 0.001628 |
| runtime-list-short | before | 0.029445 | 0.000357 |
| runtime-list-short | after | 0.029999 | 0.000878 |
| runtime-tree-short | before | 0.018388 | 0.000468 |
| runtime-tree-short | after | 0.019072 | 0.001440 |
| runtime-eval-short | before | 0.022302 | 0.000425 |
| runtime-eval-short | after | 0.022895 | 0.001335 |
| runtime-string-short | before | 0.016782 | 0.000335 |
| runtime-string-short | after | 0.017453 | 0.001739 |
| runtime-println-short | before | 0.017516 | 0.000690 |
| runtime-println-short | after | 0.018154 | 0.000544 |
| runtime-lines-short | before | 0.017217 | 0.000375 |
| runtime-lines-short | after | 0.019364 | 0.002347 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.8208e-05 | 2.25e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.25e-06 | 7.5e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1458e-05 | 3.125e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4167e-05 | 2.125e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.208e-06 | 4.59e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7375e-05 | 2.584e-06 |
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
    "after": "3bc1b83b1b220a0234e7994aba7ad55e7d0130bb"
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
| functions-main-1000-0 | 判定不能 | None | 0.0020690250000001244 |
| functions-main-1000-1 | 判定不能 | None | 0.0020969500000006746 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | 0.0024191669999993337 | 0.002675516600000094 |
| functions-args-1000-1 | 判定不能 | None | 0.0026866624999996704 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002106454200000485 |
| functions-modules-1000-1 | 判定不能 | None | 0.002099691600000142 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 達成 | 0.0019382499999949232 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028190500000008 |
| higher-1-300 | 達成 | 0.0011259999999992942 | 0.003102020800000105 |
| classes-300 | 達成 | 0.002342792000007421 | 0.003863158299999725 |
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
| interval-range-0 | 退行の疑い | 0.002498958999993306 | 0.002 |
| interval-range-64 | 退行の疑い | 0.002740834000007908 | 0.0023025082999993175 |
| interval-range-256 | 達成 | 0.0029941250000007358 | 0.003572916699999951 |
| interval-http-0 | 退行の疑い | 0.002792583000001514 | 0.002 |
| interval-http-64 | 退行の疑い | 0.0027754999999984875 | 0.0022312333000002126 |
| interval-http-256 | 達成 | 0.0028474160000087068 | 0.0030098541999990405 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003722862499999735 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0035426375000000123 |
| property-distinct-24-20-1000-all-ok | 退行の疑い | 0.004082875000008812 | 0.003741012499999386 |
| property-distinct-24-20-1000-always-error | 退行の疑い | 0.004433668000004332 | 0.003561891600000422 |
| property-zero-24-20-1000-all-ok | 達成 | 0.00338079200000152 | 0.003721358299999622 |
| property-zero-24-20-1000-always-error | 達成 | 0.003425665999998273 | 0.0036051416999995922 |
| property-max-24-20-1000-all-ok | 退行の疑い | 0.004070915999989211 | 0.0037273959000003742 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0037640374999995175 |
| order-string-candidates | 判定不能 | None | 0.0039702915999995985 |
| order-string-all-ok | 退行の疑い | 0.004282333000006133 | 0.004015904199999909 |
| order-string-always-error | 判定不能 | None | 0.0039071375000006014 |
| order-map-candidates | 退行の疑い | 0.004124292000000196 | 0.0035660292000002872 |
| order-map-all-ok | 退行の疑い | 0.003607041999998728 | 0.003606845800000258 |
| order-map-always-error | 退行の疑い | 0.0042015009999829545 | 0.003584091600001216 |
| order-record-candidates | 退行の疑い | 0.004745625999987624 | 0.003566083300000855 |
| order-record-all-ok | 退行の疑い | 0.00403545899999358 | 0.003640345799999523 |
| order-record-always-error | 達成 | 0.0031926659999896856 | 0.0037863584000007223 |
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
| runtime-loop-short | 判定不能 | None | 0.002421950000000095 |
| runtime-list-short | 判定不能 | None | 0.002944541700000514 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022301917000007165 |
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
    "verify": 1.751602291999987,
    "cli": 5.395830623000023,
    "warmup": 0.6047529580000628,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.9743448330000035,
    "cli": 12.07247987099997,
    "warmup": 1.395578584000134,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3626788340000076,
    "cli": 9.538308041999983,
    "warmup": 1.3314567510000188,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.38690324999998893,
    "cli": 3.6471888760000297,
    "warmup": 0.36558275100003357,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.1031015410000009,
    "cli": 0.2921065419999991,
    "warmup": 0.030291082000019287,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.041030749999990235,
    "cli": 0.3541759999999954,
    "warmup": 0.03537716700000715,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010591165999997543,
    "cli": 0.21224933299998838,
    "warmup": 0.00921499999998332,
    "probe_warmup": 0.008736207999987755,
    "rss": 0,
    "stages": 0.044735500999962596,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.057735790999998926,
    "cli": 0.36414150000001655,
    "warmup": 0.03804454199999441,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.19033208599998375
  },
  "runtime": {
    "verify": 0.35400545800000316,
    "cli": 3.0091199169999925,
    "warmup": 0.3381693760000388,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-29）

九つの区分の出力の照合はすべて通った。R40.3 の変更は同梱の Skill の文・テスト・設計書だけで、検査と実行の経路は変えていない。退行の疑いの点は前回（R40.2 の後）と入れ替わったが、族は同じである（`property-*`・`order-*` は Trait を使う点で設計者が採った費用、`interval-range-*`・`interval-http-*` は既知の族で、前回も同じ幅で判定不能か退行の疑いだった）。`runtime-lines-short` は今回は退行の疑いに入らなかった。全94入力の after/before の中央値の比は 1.040（前回 1.045）。R40 の段の比は R30.4 の後 1.043 → R40.1 の後 1.048 → R40.2 の後 1.045 → R40.3 の後 1.040 で、段のうちに新しい退行の族は現れなかった。
