# 版どうしの性能比較

候補: `e1e5db59ec85e642278cdf7c4ea6b6969aa5e8f8`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013640 | 0.000357 |
| functions-main-0-0 | after | 0.013801 | 0.000227 |
| functions-main-0-1 | before | 0.013478 | 0.000634 |
| functions-main-0-1 | after | 0.013870 | 0.000236 |
| functions-main-64-0 | before | 0.013541 | 0.000212 |
| functions-main-64-0 | after | 0.014089 | 0.000150 |
| functions-main-256-0 | before | 0.015766 | 0.000521 |
| functions-main-256-0 | after | 0.015763 | 0.000407 |
| functions-main-1000-0 | before | 0.021177 | 0.000363 |
| functions-main-1000-0 | after | 0.022292 | 0.000440 |
| functions-main-1000-1 | before | 0.020586 | 0.000505 |
| functions-main-1000-1 | after | 0.021690 | 0.000211 |
| functions-args-0-0 | before | 0.013477 | 0.000629 |
| functions-args-0-0 | after | 0.013556 | 0.000144 |
| functions-args-0-1 | before | 0.013312 | 0.001062 |
| functions-args-0-1 | after | 0.013570 | 0.000096 |
| functions-args-1000-0 | before | 0.026874 | 0.000309 |
| functions-args-1000-0 | after | 0.028242 | 0.000686 |
| functions-args-1000-1 | before | 0.026988 | 0.001688 |
| functions-args-1000-1 | after | 0.028280 | 0.000290 |
| functions-modules-0-0 | before | 0.013439 | 0.000911 |
| functions-modules-0-0 | after | 0.013650 | 0.000569 |
| functions-modules-0-1 | before | 0.013346 | 0.000184 |
| functions-modules-0-1 | after | 0.014043 | 0.000615 |
| functions-modules-1000-0 | before | 0.021503 | 0.000529 |
| functions-modules-1000-0 | after | 0.022565 | 0.001313 |
| functions-modules-1000-1 | before | 0.020857 | 0.000661 |
| functions-modules-1000-1 | after | 0.021838 | 0.000225 |
| existing-fib | before | 0.013998 | 0.000536 |
| existing-fib | after | 0.014609 | 0.000491 |
| existing-loop | before | 0.014057 | 0.000304 |
| existing-loop | after | 0.014517 | 0.000758 |
| existing-string | before | 0.013906 | 0.000098 |
| existing-string | after | 0.014500 | 0.000261 |
| higher-0-0 | before | 0.013268 | 0.000306 |
| higher-0-0 | after | 0.013720 | 0.000615 |
| higher-1-0 | before | 0.014438 | 0.000338 |
| higher-1-0 | after | 0.014511 | 0.000125 |
| classes-0 | before | 0.017864 | 0.000312 |
| classes-0 | after | 0.018521 | 0.000771 |
| higher-0-300 | before | 0.028439 | 0.000591 |
| higher-0-300 | after | 0.029105 | 0.000393 |
| higher-1-300 | before | 0.030664 | 0.000337 |
| higher-1-300 | after | 0.032063 | 0.000712 |
| classes-300 | before | 0.037111 | 0.000817 |
| classes-300 | after | 0.038510 | 0.000366 |
| depth-0-8 | before | 0.014728 | 0.000339 |
| depth-0-8 | after | 0.015304 | 0.000511 |
| depth-1-8 | before | 0.015023 | 0.000529 |
| depth-1-8 | after | 0.015578 | 0.000157 |
| f1-nofail-call | before | 0.014382 | 0.000541 |
| f1-nofail-call | after | 0.014876 | 0.000214 |
| f1-join-effects | before | 0.013972 | 0.000658 |
| f1-join-effects | after | 0.014476 | 0.000507 |
| control-16.3 | before | 0.013249 | 0.001056 |
| control-16.3 | after | 0.013649 | 0.000697 |
| interval-bind-64 | before | 0.013115 | 0.000272 |
| interval-bind-64 | after | 0.013533 | 0.000374 |
| interval-bind-256 | before | 0.014110 | 0.000384 |
| interval-bind-256 | after | 0.014513 | 0.000320 |
| interval-add-64 | before | 0.013225 | 0.000084 |
| interval-add-64 | after | 0.013894 | 0.000952 |
| interval-add-256 | before | 0.014875 | 0.000443 |
| interval-add-256 | after | 0.015443 | 0.000297 |
| interval-flow-64 | before | 0.014548 | 0.002258 |
| interval-flow-64 | after | 0.014632 | 0.000819 |
| interval-flow-256 | before | 0.016746 | 0.000939 |
| interval-flow-256 | after | 0.017436 | 0.000363 |
| interval-range-0 | before | 0.018320 | 0.000205 |
| interval-range-0 | after | 0.019110 | 0.000322 |
| interval-range-64 | before | 0.022827 | 0.001181 |
| interval-range-64 | after | 0.023798 | 0.000378 |
| interval-range-256 | before | 0.035580 | 0.000639 |
| interval-range-256 | after | 0.037317 | 0.000165 |
| interval-http-0 | before | 0.018960 | 0.000573 |
| interval-http-0 | after | 0.021544 | 0.000298 |
| interval-http-64 | before | 0.022259 | 0.001217 |
| interval-http-64 | after | 0.025100 | 0.000794 |
| interval-http-256 | before | 0.029938 | 0.000939 |
| interval-http-256 | after | 0.032960 | 0.000442 |
| interval-width-Integer8-64 | before | 0.014255 | 0.000847 |
| interval-width-Integer8-64 | after | 0.014892 | 0.000473 |
| interval-width-Integer8-256 | before | 0.017509 | 0.000960 |
| interval-width-Integer8-256 | after | 0.017918 | 0.000255 |
| interval-width-Integer16-64 | before | 0.014412 | 0.000643 |
| interval-width-Integer16-64 | after | 0.015094 | 0.000262 |
| interval-width-Integer16-256 | before | 0.017279 | 0.000505 |
| interval-width-Integer16-256 | after | 0.017987 | 0.000324 |
| interval-width-Integer32-64 | before | 0.014383 | 0.000739 |
| interval-width-Integer32-64 | after | 0.014904 | 0.000185 |
| interval-width-Integer32-256 | before | 0.017304 | 0.000350 |
| interval-width-Integer32-256 | after | 0.017855 | 0.000736 |
| interval-width-Integer64-64 | before | 0.014165 | 0.000230 |
| interval-width-Integer64-64 | after | 0.014980 | 0.000744 |
| interval-width-Integer64-256 | before | 0.017024 | 0.000331 |
| interval-width-Integer64-256 | after | 0.017669 | 0.000555 |
| interval-width-UnsignedInteger16-64 | before | 0.014211 | 0.000217 |
| interval-width-UnsignedInteger16-64 | after | 0.014584 | 0.000358 |
| interval-width-UnsignedInteger16-256 | before | 0.016896 | 0.000448 |
| interval-width-UnsignedInteger16-256 | after | 0.017325 | 0.000242 |
| interval-width-UnsignedInteger32-64 | before | 0.014073 | 0.000559 |
| interval-width-UnsignedInteger32-64 | after | 0.014567 | 0.000178 |
| interval-width-UnsignedInteger32-256 | before | 0.017014 | 0.000412 |
| interval-width-UnsignedInteger32-256 | after | 0.017298 | 0.000195 |
| interval-width-UnsignedInteger64-64 | before | 0.014324 | 0.000289 |
| interval-width-UnsignedInteger64-64 | after | 0.014705 | 0.000598 |
| interval-width-UnsignedInteger64-256 | before | 0.017059 | 0.000411 |
| interval-width-UnsignedInteger64-256 | after | 0.017499 | 0.000515 |
| property-seven-24-20-1000-all-ok | before | 0.037861 | 0.000572 |
| property-seven-24-20-1000-all-ok | after | 0.039139 | 0.000825 |
| property-seven-24-20-1000-always-error | before | 0.036036 | 0.001332 |
| property-seven-24-20-1000-always-error | after | 0.037963 | 0.000810 |
| property-distinct-24-20-1000-all-ok | before | 0.036497 | 0.000512 |
| property-distinct-24-20-1000-all-ok | after | 0.038232 | 0.000723 |
| property-distinct-24-20-1000-always-error | before | 0.035403 | 0.000301 |
| property-distinct-24-20-1000-always-error | after | 0.037120 | 0.000506 |
| property-zero-24-20-1000-all-ok | before | 0.036551 | 0.000428 |
| property-zero-24-20-1000-all-ok | after | 0.038143 | 0.001168 |
| property-zero-24-20-1000-always-error | before | 0.035279 | 0.000183 |
| property-zero-24-20-1000-always-error | after | 0.037129 | 0.001120 |
| property-max-24-20-1000-all-ok | before | 0.036792 | 0.000604 |
| property-max-24-20-1000-all-ok | after | 0.038587 | 0.001854 |
| property-max-24-20-1000-always-error | before | 0.035730 | 0.001421 |
| property-max-24-20-1000-always-error | after | 0.036915 | 0.000810 |
| order-string-candidates | before | 0.035203 | 0.000513 |
| order-string-candidates | after | 0.036750 | 0.000752 |
| order-string-all-ok | before | 0.036663 | 0.000874 |
| order-string-all-ok | after | 0.037817 | 0.000629 |
| order-string-always-error | before | 0.035031 | 0.000443 |
| order-string-always-error | after | 0.036748 | 0.000311 |
| order-map-candidates | before | 0.035726 | 0.000623 |
| order-map-candidates | after | 0.037930 | 0.000622 |
| order-map-all-ok | before | 0.035694 | 0.000452 |
| order-map-all-ok | after | 0.037401 | 0.000429 |
| order-map-always-error | before | 0.035423 | 0.000442 |
| order-map-always-error | after | 0.037423 | 0.000572 |
| order-record-candidates | before | 0.036163 | 0.000339 |
| order-record-candidates | after | 0.037559 | 0.000773 |
| order-record-all-ok | before | 0.035849 | 0.000502 |
| order-record-all-ok | after | 0.037757 | 0.000902 |
| order-record-always-error | before | 0.036095 | 0.000690 |
| order-record-always-error | after | 0.037978 | 0.000981 |
| build-string-builder-8-0 | before | 0.015831 | 0.000990 |
| build-string-builder-8-0 | after | 0.016196 | 0.000268 |
| build-string-builder-all-8-0 | before | 0.016112 | 0.000206 |
| build-string-builder-all-8-0 | after | 0.016478 | 0.001007 |
| build-string-concatenate-8-0 | before | 0.016192 | 0.000489 |
| build-string-concatenate-8-0 | after | 0.016786 | 0.000648 |
| build-string-join-8-0 | before | 0.016013 | 0.000078 |
| build-string-join-8-0 | after | 0.016582 | 0.000244 |
| build-list-builder-8-0 | before | 0.015956 | 0.000422 |
| build-list-builder-8-0 | after | 0.016759 | 0.000254 |
| build-list-builder-all-8-0 | before | 0.015909 | 0.000417 |
| build-list-builder-all-8-0 | after | 0.016699 | 0.001299 |
| build-list-concatenate-8-0 | before | 0.016268 | 0.000606 |
| build-list-concatenate-8-0 | after | 0.016636 | 0.000229 |
| build-list-fold-8-0 | before | 0.016096 | 0.000265 |
| build-list-fold-8-0 | after | 0.016768 | 0.001060 |
| build-bytes-builder-8-0 | before | 0.016186 | 0.000201 |
| build-bytes-builder-8-0 | after | 0.016693 | 0.000094 |
| build-bytes-builder-all-8-0 | before | 0.016370 | 0.000738 |
| build-bytes-builder-all-8-0 | after | 0.016613 | 0.000287 |
| build-bytes-concatenate-8-0 | before | 0.016479 | 0.000353 |
| build-bytes-concatenate-8-0 | after | 0.017047 | 0.000970 |
| patterns-integer-100 | before | 0.014610 | 0.000632 |
| patterns-integer-100 | after | 0.015102 | 0.000247 |
| codegen-let-100 | before | 0.017018 | 0.000108 |
| codegen-let-100 | after | 0.017865 | 0.000292 |
| bridge-shared-8 | before | 0.004857 | 0.000165 |
| bridge-shared-8 | after | 0.004852 | 0.000363 |
| external-tests-normal-1 | before | 0.018419 | 0.000321 |
| external-tests-normal-1 | after | 0.018870 | 0.000434 |
| runtime-fib-short | before | 0.018045 | 0.000249 |
| runtime-fib-short | after | 0.018824 | 0.000672 |
| runtime-loop-short | before | 0.024061 | 0.001193 |
| runtime-loop-short | after | 0.025099 | 0.000927 |
| runtime-list-short | before | 0.029553 | 0.000824 |
| runtime-list-short | after | 0.029922 | 0.000290 |
| runtime-tree-short | before | 0.018567 | 0.000894 |
| runtime-tree-short | after | 0.018928 | 0.000101 |
| runtime-eval-short | before | 0.022446 | 0.000974 |
| runtime-eval-short | after | 0.022859 | 0.000693 |
| runtime-string-short | before | 0.017048 | 0.000392 |
| runtime-string-short | after | 0.017621 | 0.000793 |
| runtime-println-short | before | 0.017294 | 0.000338 |
| runtime-println-short | after | 0.017954 | 0.000092 |
| runtime-lines-short | before | 0.016922 | 0.000339 |
| runtime-lines-short | after | 0.017594 | 0.000585 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.825e-05 | 3.76e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.041e-06 | 2.91e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1584e-05 | 3.75e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5041e-05 | 1.042e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.167e-06 | 6.67e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.85e-05 | 1.584e-06 |
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
    "after": "e1e5db59ec85e642278cdf7c4ea6b6969aa5e8f8"
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
| functions-main-64-0 | 達成 | 0.0005483329999975695 | 0.002 |
| functions-main-256-0 | 判定不能 | None | 0.002 |
| functions-main-1000-0 | 達成 | 0.001115208000001644 | 0.0021176583999988454 |
| functions-main-1000-1 | 達成 | 0.0011043750000112595 | 0.002058562499999539 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | 0.0013682090000060043 | 0.002687408299999561 |
| functions-args-1000-1 | 判定不能 | None | 0.0026987832999992634 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0021502666000003503 |
| functions-modules-1000-1 | 達成 | 0.0009814160000019 | 0.002085666699998967 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 達成 | 0.0005942919999881724 | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002843899999999167 |
| higher-1-300 | 達成 | 0.0013990409999991016 | 0.0030663958999994634 |
| classes-300 | 達成 | 0.0013988760000103184 | 0.0037111082999999215 |
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
| interval-range-0 | 達成 | 0.0007904160000009597 | 0.002 |
| interval-range-64 | 判定不能 | None | 0.0022827332999995065 |
| interval-range-256 | 達成 | 0.0017376669999862315 | 0.0035579583000000525 |
| interval-http-0 | 退行の疑い | 0.002583708000003071 | 0.002 |
| interval-http-64 | 退行の疑い | 0.0028407500000042774 | 0.0022258874999991464 |
| interval-http-256 | 退行の疑い | 0.003021831999987512 | 0.0029937834000008934 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003786062499999332 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003603616600000237 |
| property-distinct-24-20-1000-all-ok | 達成 | 0.0017352920000064387 | 0.0036496833000001063 |
| property-distinct-24-20-1000-always-error | 達成 | 0.0017165420000111453 | 0.003540345799999045 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003655075000000352 |
| property-zero-24-20-1000-always-error | 達成 | 0.0018501670000006243 | 0.0035279166999998782 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003679216700000154 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003573033400000725 |
| order-string-candidates | 達成 | 0.0015466659999958665 | 0.0035203124999995342 |
| order-string-all-ok | 判定不能 | None | 0.0036663082999993436 |
| order-string-always-error | 達成 | 0.0017169170000101985 | 0.0035030832999993324 |
| order-map-candidates | 達成 | 0.002203457999996772 | 0.0035726417000006452 |
| order-map-all-ok | 達成 | 0.0017073750000093924 | 0.0035693999999992345 |
| order-map-always-error | 達成 | 0.0019997919999923397 | 0.003542308300001196 |
| order-record-candidates | 達成 | 0.0013955420000115737 | 0.003616320799999073 |
| order-record-all-ok | 達成 | 0.0019075000000015052 | 0.0035849124999998597 |
| order-record-always-error | 達成 | 0.0018820829999839361 | 0.00360954590000091 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 達成 | 0.000568874999999025 | 0.002 |
| build-list-builder-8-0 | 達成 | 0.000802208000010296 | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 達成 | 0.0005065000000001874 | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0024060916999999907 |
| runtime-list-short | 判定不能 | None | 0.0029553207999995835 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022446165999994608 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 達成 | 0.0006592499999982238 | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 達成 | 0.0008471249999928432 | 0.002 |
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
    "verify": 1.7314921250000026,
    "cli": 5.319318127000017,
    "warmup": 0.6006578359999963,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.9426918750000084,
    "cli": 11.97347033299998,
    "warmup": 1.384893209999973,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.293742249999994,
    "cli": 9.073910877000046,
    "warmup": 1.2579333359999794,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.38166350000000193,
    "cli": 3.5903857920000064,
    "warmup": 0.3638258759999644,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09998054100000786,
    "cli": 0.2853680829999945,
    "warmup": 0.02989416699999481,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03542237499999601,
    "cli": 0.33631962500000157,
    "warmup": 0.03499141699998631,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009546083000003591,
    "cli": 0.20632437499999412,
    "warmup": 0.00931833300001017,
    "probe_warmup": 0.008490791000014042,
    "rss": 0,
    "stages": 0.04156478900004856,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04318383399998993,
    "cli": 0.35130441600000495,
    "warmup": 0.0387329579999971,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.1898700000000133
  },
  "runtime": {
    "verify": 0.3445383330000027,
    "cli": 2.9713354160000165,
    "warmup": 0.33392812600001776,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
