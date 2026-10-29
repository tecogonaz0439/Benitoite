# 版どうしの性能比較

候補: `6b499da9bef6ae8f0a6db90122fecf46e210d0d9`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013619 | 0.000681 |
| functions-main-0-0 | after | 0.013792 | 0.000241 |
| functions-main-0-1 | before | 0.013562 | 0.000969 |
| functions-main-0-1 | after | 0.014345 | 0.000615 |
| functions-main-64-0 | before | 0.014150 | 0.002112 |
| functions-main-64-0 | after | 0.014556 | 0.000443 |
| functions-main-256-0 | before | 0.015031 | 0.001224 |
| functions-main-256-0 | after | 0.015798 | 0.000208 |
| functions-main-1000-0 | before | 0.020710 | 0.001106 |
| functions-main-1000-0 | after | 0.021737 | 0.001863 |
| functions-main-1000-1 | before | 0.020617 | 0.000420 |
| functions-main-1000-1 | after | 0.021468 | 0.002276 |
| functions-args-0-0 | before | 0.014983 | 0.001117 |
| functions-args-0-0 | after | 0.015389 | 0.000485 |
| functions-args-0-1 | before | 0.015117 | 0.001395 |
| functions-args-0-1 | after | 0.015983 | 0.001425 |
| functions-args-1000-0 | before | 0.026730 | 0.000156 |
| functions-args-1000-0 | after | 0.028597 | 0.001106 |
| functions-args-1000-1 | before | 0.026544 | 0.000316 |
| functions-args-1000-1 | after | 0.028480 | 0.001350 |
| functions-modules-0-0 | before | 0.013989 | 0.001484 |
| functions-modules-0-0 | after | 0.013546 | 0.000470 |
| functions-modules-0-1 | before | 0.013596 | 0.001393 |
| functions-modules-0-1 | after | 0.013792 | 0.000114 |
| functions-modules-1000-0 | before | 0.020970 | 0.000295 |
| functions-modules-1000-0 | after | 0.021814 | 0.001331 |
| functions-modules-1000-1 | before | 0.020934 | 0.000427 |
| functions-modules-1000-1 | after | 0.022005 | 0.001689 |
| existing-fib | before | 0.013993 | 0.000779 |
| existing-fib | after | 0.014438 | 0.000535 |
| existing-loop | before | 0.013839 | 0.001302 |
| existing-loop | after | 0.014112 | 0.000178 |
| existing-string | before | 0.014187 | 0.001047 |
| existing-string | after | 0.014483 | 0.000353 |
| higher-0-0 | before | 0.013692 | 0.000930 |
| higher-0-0 | after | 0.013784 | 0.000451 |
| higher-1-0 | before | 0.014918 | 0.002004 |
| higher-1-0 | after | 0.015252 | 0.000351 |
| classes-0 | before | 0.017800 | 0.000510 |
| classes-0 | after | 0.020406 | 0.000549 |
| higher-0-300 | before | 0.028474 | 0.000233 |
| higher-0-300 | after | 0.029618 | 0.001430 |
| higher-1-300 | before | 0.030761 | 0.000186 |
| higher-1-300 | after | 0.032132 | 0.000655 |
| classes-300 | before | 0.037667 | 0.001551 |
| classes-300 | after | 0.040536 | 0.000356 |
| depth-0-8 | before | 0.014878 | 0.000595 |
| depth-0-8 | after | 0.015651 | 0.000579 |
| depth-1-8 | before | 0.016407 | 0.000992 |
| depth-1-8 | after | 0.016511 | 0.000325 |
| f1-nofail-call | before | 0.014942 | 0.000508 |
| f1-nofail-call | after | 0.015325 | 0.001552 |
| f1-join-effects | before | 0.014855 | 0.000948 |
| f1-join-effects | after | 0.015517 | 0.000875 |
| control-16.3 | before | 0.014286 | 0.001172 |
| control-16.3 | after | 0.015017 | 0.000972 |
| interval-bind-64 | before | 0.014239 | 0.001000 |
| interval-bind-64 | after | 0.014792 | 0.001077 |
| interval-bind-256 | before | 0.014154 | 0.001236 |
| interval-bind-256 | after | 0.014249 | 0.000202 |
| interval-add-64 | before | 0.013424 | 0.001500 |
| interval-add-64 | after | 0.013900 | 0.000619 |
| interval-add-256 | before | 0.015800 | 0.000988 |
| interval-add-256 | after | 0.015606 | 0.000447 |
| interval-flow-64 | before | 0.014709 | 0.000874 |
| interval-flow-64 | after | 0.015052 | 0.000566 |
| interval-flow-256 | before | 0.017009 | 0.000815 |
| interval-flow-256 | after | 0.017810 | 0.000593 |
| interval-range-0 | before | 0.018674 | 0.000852 |
| interval-range-0 | after | 0.020879 | 0.001700 |
| interval-range-64 | before | 0.022873 | 0.000116 |
| interval-range-64 | after | 0.025502 | 0.000880 |
| interval-range-256 | before | 0.036206 | 0.001334 |
| interval-range-256 | after | 0.039366 | 0.000497 |
| interval-http-0 | before | 0.020447 | 0.000510 |
| interval-http-0 | after | 0.022902 | 0.000994 |
| interval-http-64 | before | 0.023387 | 0.001616 |
| interval-http-64 | after | 0.027974 | 0.001240 |
| interval-http-256 | before | 0.033220 | 0.000932 |
| interval-http-256 | after | 0.035953 | 0.000682 |
| interval-width-Integer8-64 | before | 0.016143 | 0.000185 |
| interval-width-Integer8-64 | after | 0.016853 | 0.000297 |
| interval-width-Integer8-256 | before | 0.018306 | 0.000226 |
| interval-width-Integer8-256 | after | 0.018725 | 0.001504 |
| interval-width-Integer16-64 | before | 0.015878 | 0.002539 |
| interval-width-Integer16-64 | after | 0.016808 | 0.000964 |
| interval-width-Integer16-256 | before | 0.019619 | 0.001249 |
| interval-width-Integer16-256 | after | 0.021197 | 0.002537 |
| interval-width-Integer32-64 | before | 0.016798 | 0.001011 |
| interval-width-Integer32-64 | after | 0.016732 | 0.000530 |
| interval-width-Integer32-256 | before | 0.019271 | 0.000544 |
| interval-width-Integer32-256 | after | 0.019942 | 0.001778 |
| interval-width-Integer64-64 | before | 0.014841 | 0.000883 |
| interval-width-Integer64-64 | after | 0.014819 | 0.000457 |
| interval-width-Integer64-256 | before | 0.016855 | 0.000613 |
| interval-width-Integer64-256 | after | 0.017422 | 0.000498 |
| interval-width-UnsignedInteger16-64 | before | 0.016153 | 0.003244 |
| interval-width-UnsignedInteger16-64 | after | 0.015962 | 0.001254 |
| interval-width-UnsignedInteger16-256 | before | 0.017859 | 0.000837 |
| interval-width-UnsignedInteger16-256 | after | 0.018231 | 0.000821 |
| interval-width-UnsignedInteger32-64 | before | 0.014966 | 0.001534 |
| interval-width-UnsignedInteger32-64 | after | 0.015233 | 0.000675 |
| interval-width-UnsignedInteger32-256 | before | 0.016886 | 0.000600 |
| interval-width-UnsignedInteger32-256 | after | 0.017463 | 0.000531 |
| interval-width-UnsignedInteger64-64 | before | 0.014465 | 0.000910 |
| interval-width-UnsignedInteger64-64 | after | 0.014894 | 0.000565 |
| interval-width-UnsignedInteger64-256 | before | 0.017489 | 0.000397 |
| interval-width-UnsignedInteger64-256 | after | 0.018068 | 0.000642 |
| property-seven-24-20-1000-all-ok | before | 0.037745 | 0.003092 |
| property-seven-24-20-1000-all-ok | after | 0.042700 | 0.001795 |
| property-seven-24-20-1000-always-error | before | 0.039800 | 0.002697 |
| property-seven-24-20-1000-always-error | after | 0.044181 | 0.001238 |
| property-distinct-24-20-1000-all-ok | before | 0.040043 | 0.004186 |
| property-distinct-24-20-1000-all-ok | after | 0.042934 | 0.001542 |
| property-distinct-24-20-1000-always-error | before | 0.036024 | 0.001827 |
| property-distinct-24-20-1000-always-error | after | 0.039882 | 0.000507 |
| property-zero-24-20-1000-all-ok | before | 0.038251 | 0.001422 |
| property-zero-24-20-1000-all-ok | after | 0.041736 | 0.000945 |
| property-zero-24-20-1000-always-error | before | 0.039602 | 0.002043 |
| property-zero-24-20-1000-always-error | after | 0.041589 | 0.002550 |
| property-max-24-20-1000-all-ok | before | 0.037129 | 0.002169 |
| property-max-24-20-1000-all-ok | after | 0.041391 | 0.000486 |
| property-max-24-20-1000-always-error | before | 0.036763 | 0.001166 |
| property-max-24-20-1000-always-error | after | 0.040494 | 0.001301 |
| order-string-candidates | before | 0.038651 | 0.002115 |
| order-string-candidates | after | 0.042830 | 0.000915 |
| order-string-all-ok | before | 0.035697 | 0.004696 |
| order-string-all-ok | after | 0.039868 | 0.002084 |
| order-string-always-error | before | 0.035411 | 0.000852 |
| order-string-always-error | after | 0.039444 | 0.000930 |
| order-map-candidates | before | 0.036109 | 0.000629 |
| order-map-candidates | after | 0.040002 | 0.000721 |
| order-map-all-ok | before | 0.035735 | 0.001208 |
| order-map-all-ok | after | 0.039774 | 0.000239 |
| order-map-always-error | before | 0.035642 | 0.001588 |
| order-map-always-error | after | 0.040272 | 0.000390 |
| order-record-candidates | before | 0.036490 | 0.002405 |
| order-record-candidates | after | 0.040428 | 0.000992 |
| order-record-all-ok | before | 0.039555 | 0.001781 |
| order-record-all-ok | after | 0.044621 | 0.002678 |
| order-record-always-error | before | 0.036580 | 0.004058 |
| order-record-always-error | after | 0.040178 | 0.002553 |
| build-string-builder-8-0 | before | 0.016317 | 0.000508 |
| build-string-builder-8-0 | after | 0.016716 | 0.000236 |
| build-string-builder-all-8-0 | before | 0.016994 | 0.000568 |
| build-string-builder-all-8-0 | after | 0.017052 | 0.000979 |
| build-string-concatenate-8-0 | before | 0.016170 | 0.000436 |
| build-string-concatenate-8-0 | after | 0.016532 | 0.000263 |
| build-string-join-8-0 | before | 0.018418 | 0.002427 |
| build-string-join-8-0 | after | 0.017688 | 0.001102 |
| build-list-builder-8-0 | before | 0.017774 | 0.003430 |
| build-list-builder-8-0 | after | 0.018325 | 0.002053 |
| build-list-builder-all-8-0 | before | 0.016750 | 0.000554 |
| build-list-builder-all-8-0 | after | 0.017417 | 0.000505 |
| build-list-concatenate-8-0 | before | 0.016831 | 0.001009 |
| build-list-concatenate-8-0 | after | 0.017437 | 0.000691 |
| build-list-fold-8-0 | before | 0.016784 | 0.001141 |
| build-list-fold-8-0 | after | 0.018939 | 0.001312 |
| build-bytes-builder-8-0 | before | 0.018090 | 0.001425 |
| build-bytes-builder-8-0 | after | 0.019306 | 0.001452 |
| build-bytes-builder-all-8-0 | before | 0.018961 | 0.000589 |
| build-bytes-builder-all-8-0 | after | 0.019233 | 0.001541 |
| build-bytes-concatenate-8-0 | before | 0.018496 | 0.000843 |
| build-bytes-concatenate-8-0 | after | 0.018295 | 0.002344 |
| patterns-integer-100 | before | 0.016911 | 0.000630 |
| patterns-integer-100 | after | 0.016900 | 0.000474 |
| codegen-let-100 | before | 0.019818 | 0.000952 |
| codegen-let-100 | after | 0.019819 | 0.001175 |
| bridge-shared-8 | before | 0.005263 | 0.000475 |
| bridge-shared-8 | after | 0.005091 | 0.000605 |
| external-tests-normal-1 | before | 0.020880 | 0.002924 |
| external-tests-normal-1 | after | 0.021108 | 0.002045 |
| runtime-fib-short | before | 0.020131 | 0.000924 |
| runtime-fib-short | after | 0.020693 | 0.002027 |
| runtime-loop-short | before | 0.024290 | 0.001189 |
| runtime-loop-short | after | 0.025843 | 0.001232 |
| runtime-list-short | before | 0.029627 | 0.001127 |
| runtime-list-short | after | 0.030779 | 0.000319 |
| runtime-tree-short | before | 0.018905 | 0.001545 |
| runtime-tree-short | after | 0.020392 | 0.001651 |
| runtime-eval-short | before | 0.023370 | 0.000617 |
| runtime-eval-short | after | 0.023990 | 0.001463 |
| runtime-string-short | before | 0.017674 | 0.000334 |
| runtime-string-short | after | 0.019120 | 0.002249 |
| runtime-println-short | before | 0.017972 | 0.000631 |
| runtime-println-short | after | 0.019502 | 0.001564 |
| runtime-lines-short | before | 0.018544 | 0.000722 |
| runtime-lines-short | after | 0.021554 | 0.001528 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.8791e-05 | 5.41e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.5e-06 | 2.09e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.2291e-05 | 7.5e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.6542e-05 | 9.58e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.917e-06 | 4.2e-08 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 2.0459e-05 | 6.66e-07 |
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
    "after": "6b499da9bef6ae8f0a6db90122fecf46e210d0d9"
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
| functions-main-1000-0 | 判定不能 | None | 0.0020709792000005224 |
| functions-main-1000-1 | 判定不能 | None | 0.0020617083000004756 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | 0.001866500999980758 | 0.0026730291000006904 |
| functions-args-1000-1 | 達成 | 0.0019363749999996571 | 0.0026543541999998867 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0020970291999987014 |
| functions-modules-1000-1 | 判定不能 | None | 0.0020933792000008113 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 退行の疑い | 0.002606250000013688 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002847412500000246 |
| higher-1-300 | 達成 | 0.0013705839999857972 | 0.003076112500001216 |
| classes-300 | 達成 | 0.0028691250000179025 | 0.0037666915999992057 |
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
| interval-range-64 | 退行の疑い | 0.0026283749999862493 | 0.0022873375000003193 |
| interval-range-256 | 達成 | 0.0031601259999973763 | 0.00362060409999998 |
| interval-http-0 | 退行の疑い | 0.002455666999992445 | 0.0020446708000008587 |
| interval-http-64 | 退行の疑い | 0.004587374999999838 | 0.002338683300000355 |
| interval-http-256 | 達成 | 0.002733832999993524 | 0.0033219625000000977 |
| interval-width-Integer8-64 | 達成 | 0.0007105419999930973 | 0.002 |
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
| property-seven-24-20-1000-all-ok | 退行の疑い | 0.004955207999998379 | 0.0037744875000001346 |
| property-seven-24-20-1000-always-error | 退行の疑い | 0.00438087500000961 | 0.0039800291999995355 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.004004279199999417 |
| property-distinct-24-20-1000-always-error | 退行の疑い | 0.0038583330000108162 | 0.003602387499999793 |
| property-zero-24-20-1000-all-ok | 達成 | 0.003485251000000744 | 0.0038250833000006423 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003960241699999756 |
| property-max-24-20-1000-all-ok | 退行の疑い | 0.004262291000017626 | 0.003712858399998709 |
| property-max-24-20-1000-always-error | 退行の疑い | 0.0037317919999821925 | 0.0036762708000011913 |
| order-string-candidates | 退行の疑い | 0.004179250000007073 | 0.0038651208000004544 |
| order-string-all-ok | 判定不能 | None | 0.003569691599999203 |
| order-string-always-error | 退行の疑い | 0.004032833000010783 | 0.0035411374999995363 |
| order-map-candidates | 退行の疑い | 0.003893124999990505 | 0.0036109042000006756 |
| order-map-all-ok | 退行の疑い | 0.004039750000004005 | 0.003573450000000378 |
| order-map-always-error | 退行の疑い | 0.004629957999995327 | 0.003564220900000237 |
| order-record-candidates | 退行の疑い | 0.003937583999999106 | 0.0036490374999999632 |
| order-record-all-ok | 退行の疑い | 0.005066249999998718 | 0.003955495799999653 |
| order-record-always-error | 判定不能 | None | 0.003657991699999741 |
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
| runtime-fib-short | 判定不能 | None | 0.0020131208000009337 |
| runtime-loop-short | 判定不能 | None | 0.002428950000000896 |
| runtime-list-short | 判定不能 | None | 0.002962716700000101 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0023369750000000523 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 退行の疑い | 0.0030092089999982363 | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 判定不能 | None | 0.002 |
| bridge-shared-8 | 判定不能 | None | 0.002 |
| external-tests-normal-1 | 判定不能 | None | 0.0020880333000008024 |

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
    "verify": 1.7664672920000015,
    "cli": 5.4321776259999695,
    "warmup": 0.6036688770000325,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 3.0681077909999885,
    "cli": 12.575560040000013,
    "warmup": 1.4388101659999109,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3416622080000025,
    "cli": 9.663734955999985,
    "warmup": 1.3594252479999938,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.38737849999999696,
    "cli": 3.8897521670000543,
    "warmup": 0.38710516599998357,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10374954200000275,
    "cli": 0.3255671250000205,
    "warmup": 0.033668874999989384,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.039980959000004646,
    "cli": 0.37974362500000325,
    "warmup": 0.03986708300001851,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010636707999992723,
    "cli": 0.2196076660000017,
    "warmup": 0.010866249999992306,
    "probe_warmup": 0.009126749999978756,
    "rss": 0,
    "stages": 0.04454720800001155,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04327516600000081,
    "cli": 0.4046038329999817,
    "warmup": 0.03746783300002221,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.2049718330000303
  },
  "runtime": {
    "verify": 0.35471112499999435,
    "cli": 3.1690965839999308,
    "warmup": 0.3512651239999798,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-29）

九つの区分の出力の照合はすべて通った。退行の疑いの族は R30.3c・R30.2c の後の比較と同じ（Trait を使う点は設計者が採った費用、`runtime-lines-short` は File が Scope を読む分と TODO-304、`interval-http-*` は既知）。`interval-http-64` の比が 1.13 から 1.20 へ上がったので、R30.2c の取り込み（`5ceb0d3d`）とこの版の CLI を交互に25回ずつ走らせて確かめた。`Http` を import するだけのプログラムの `check` は 20.65→20.80 ms、`interval-http-64` の入力は 24.54→24.81 ms で、R30.4（`Http.bnt` への `sendIn` の宣言の追加）による差は 0.15〜0.27 ms だった。比の上がりは主に before の測定のぶれである。全94入力の after/before の中央値の比は 1.043。
