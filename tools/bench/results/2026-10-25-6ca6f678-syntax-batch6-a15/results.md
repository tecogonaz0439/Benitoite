# 版どうしの性能比較

候補: `6ca6f678e168701104d1995e6de4b9afb4be0153`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.014184 | 0.001999 |
| functions-main-0-0 | after | 0.013733 | 0.000517 |
| functions-main-0-1 | before | 0.014099 | 0.000589 |
| functions-main-0-1 | after | 0.013349 | 0.000369 |
| functions-main-64-0 | before | 0.015030 | 0.000651 |
| functions-main-64-0 | after | 0.014018 | 0.000732 |
| functions-main-256-0 | before | 0.017048 | 0.000349 |
| functions-main-256-0 | after | 0.014905 | 0.000805 |
| functions-main-1000-0 | before | 0.031904 | 0.000546 |
| functions-main-1000-0 | after | 0.021051 | 0.000700 |
| functions-main-1000-1 | before | 0.031515 | 0.000166 |
| functions-main-1000-1 | after | 0.020371 | 0.001959 |
| functions-args-0-0 | before | 0.013511 | 0.000544 |
| functions-args-0-0 | after | 0.012952 | 0.000213 |
| functions-args-0-1 | before | 0.013667 | 0.000461 |
| functions-args-0-1 | after | 0.013005 | 0.000201 |
| functions-args-1000-0 | before | 0.048509 | 0.001920 |
| functions-args-1000-0 | after | 0.026074 | 0.000450 |
| functions-args-1000-1 | before | 0.049111 | 0.001017 |
| functions-args-1000-1 | after | 0.026649 | 0.000396 |
| functions-modules-0-0 | before | 0.013994 | 0.001458 |
| functions-modules-0-0 | after | 0.013099 | 0.000494 |
| functions-modules-0-1 | before | 0.014128 | 0.000835 |
| functions-modules-0-1 | after | 0.013417 | 0.000128 |
| functions-modules-1000-0 | before | 0.025841 | 0.000632 |
| functions-modules-1000-0 | after | 0.021550 | 0.000864 |
| functions-modules-1000-1 | before | 0.025404 | 0.000353 |
| functions-modules-1000-1 | after | 0.020816 | 0.001639 |
| existing-fib | before | 0.014063 | 0.001143 |
| existing-fib | after | 0.013381 | 0.000116 |
| existing-loop | before | 0.014258 | 0.000694 |
| existing-loop | after | 0.013685 | 0.000322 |
| existing-string | before | 0.014031 | 0.001735 |
| existing-string | after | 0.013371 | 0.000059 |
| higher-0-0 | before | 0.013479 | 0.001815 |
| higher-0-0 | after | 0.013415 | 0.000464 |
| higher-1-0 | before | 0.014778 | 0.000370 |
| higher-1-0 | after | 0.014223 | 0.000059 |
| classes-0 | before | 0.019663 | 0.000526 |
| classes-0 | after | 0.017519 | 0.001366 |
| higher-0-300 | before | 0.027150 | 0.000257 |
| higher-0-300 | after | 0.028553 | 0.001392 |
| higher-1-300 | before | 0.029749 | 0.000124 |
| higher-1-300 | after | 0.031105 | 0.001677 |
| classes-300 | before | 0.039353 | 0.000579 |
| classes-300 | after | 0.037386 | 0.000201 |
| depth-0-8 | before | 0.015879 | 0.000799 |
| depth-0-8 | after | 0.015010 | 0.000162 |
| depth-1-8 | before | 0.015653 | 0.000491 |
| depth-1-8 | after | 0.015266 | 0.000446 |
| f1-nofail-call | before | 0.014571 | 0.000924 |
| f1-nofail-call | after | 0.014016 | 0.000180 |
| f1-join-effects | before | 0.014570 | 0.000782 |
| f1-join-effects | after | 0.014012 | 0.000282 |
| control-16.3 | before | 0.013535 | 0.000525 |
| control-16.3 | after | 0.012717 | 0.000123 |
| interval-bind-64 | before | 0.013633 | 0.001136 |
| interval-bind-64 | after | 0.013029 | 0.000156 |
| interval-bind-256 | before | 0.015164 | 0.000408 |
| interval-bind-256 | after | 0.013727 | 0.000303 |
| interval-add-64 | before | 0.013871 | 0.001098 |
| interval-add-64 | after | 0.013102 | 0.000663 |
| interval-add-256 | before | 0.015436 | 0.001411 |
| interval-add-256 | after | 0.014592 | 0.000091 |
| interval-flow-64 | before | 0.014580 | 0.000935 |
| interval-flow-64 | after | 0.013781 | 0.000128 |
| interval-flow-256 | before | 0.017320 | 0.000486 |
| interval-flow-256 | after | 0.016717 | 0.000177 |
| interval-range-0 | before | 0.020663 | 0.000395 |
| interval-range-0 | after | 0.018216 | 0.000881 |
| interval-range-64 | before | 0.024970 | 0.000190 |
| interval-range-64 | after | 0.023089 | 0.001184 |
| interval-range-256 | before | 0.038308 | 0.001172 |
| interval-range-256 | after | 0.037081 | 0.000361 |
| interval-http-0 | before | 0.021984 | 0.001851 |
| interval-http-0 | after | 0.019262 | 0.002744 |
| interval-http-64 | before | 0.024203 | 0.000198 |
| interval-http-64 | after | 0.022114 | 0.000985 |
| interval-http-256 | before | 0.032411 | 0.000411 |
| interval-http-256 | after | 0.029931 | 0.000692 |
| interval-width-Integer8-64 | before | 0.014459 | 0.000640 |
| interval-width-Integer8-64 | after | 0.013709 | 0.000219 |
| interval-width-Integer8-256 | before | 0.017231 | 0.000649 |
| interval-width-Integer8-256 | after | 0.016545 | 0.000217 |
| interval-width-Integer16-64 | before | 0.014685 | 0.000540 |
| interval-width-Integer16-64 | after | 0.013731 | 0.000103 |
| interval-width-Integer16-256 | before | 0.017206 | 0.000609 |
| interval-width-Integer16-256 | after | 0.016716 | 0.000161 |
| interval-width-Integer32-64 | before | 0.014520 | 0.001151 |
| interval-width-Integer32-64 | after | 0.013762 | 0.000098 |
| interval-width-Integer32-256 | before | 0.017282 | 0.001167 |
| interval-width-Integer32-256 | after | 0.016629 | 0.000153 |
| interval-width-Integer64-64 | before | 0.014629 | 0.002626 |
| interval-width-Integer64-64 | after | 0.013894 | 0.000128 |
| interval-width-Integer64-256 | before | 0.017570 | 0.000675 |
| interval-width-Integer64-256 | after | 0.016712 | 0.000367 |
| interval-width-UnsignedInteger16-64 | before | 0.014586 | 0.001330 |
| interval-width-UnsignedInteger16-64 | after | 0.013755 | 0.000186 |
| interval-width-UnsignedInteger16-256 | before | 0.017027 | 0.000543 |
| interval-width-UnsignedInteger16-256 | after | 0.016472 | 0.000206 |
| interval-width-UnsignedInteger32-64 | before | 0.014425 | 0.001360 |
| interval-width-UnsignedInteger32-64 | after | 0.013747 | 0.000261 |
| interval-width-UnsignedInteger32-256 | before | 0.017619 | 0.000728 |
| interval-width-UnsignedInteger32-256 | after | 0.016491 | 0.000238 |
| interval-width-UnsignedInteger64-64 | before | 0.014278 | 0.000831 |
| interval-width-UnsignedInteger64-64 | after | 0.013671 | 0.000047 |
| interval-width-UnsignedInteger64-256 | before | 0.017086 | 0.000645 |
| interval-width-UnsignedInteger64-256 | after | 0.016446 | 0.000329 |
| property-seven-24-20-1000-all-ok | before | 0.040266 | 0.001592 |
| property-seven-24-20-1000-all-ok | after | 0.036966 | 0.000425 |
| property-seven-24-20-1000-always-error | before | 0.038930 | 0.001139 |
| property-seven-24-20-1000-always-error | after | 0.035374 | 0.000495 |
| property-distinct-24-20-1000-all-ok | before | 0.040031 | 0.001443 |
| property-distinct-24-20-1000-all-ok | after | 0.036290 | 0.000940 |
| property-distinct-24-20-1000-always-error | before | 0.039385 | 0.001151 |
| property-distinct-24-20-1000-always-error | after | 0.035257 | 0.000504 |
| property-zero-24-20-1000-all-ok | before | 0.040097 | 0.001558 |
| property-zero-24-20-1000-all-ok | after | 0.036335 | 0.000161 |
| property-zero-24-20-1000-always-error | before | 0.038714 | 0.001281 |
| property-zero-24-20-1000-always-error | after | 0.035425 | 0.000673 |
| property-max-24-20-1000-all-ok | before | 0.040300 | 0.002000 |
| property-max-24-20-1000-all-ok | after | 0.037029 | 0.000424 |
| property-max-24-20-1000-always-error | before | 0.038858 | 0.001709 |
| property-max-24-20-1000-always-error | after | 0.035283 | 0.000496 |
| order-string-candidates | before | 0.038300 | 0.001358 |
| order-string-candidates | after | 0.035033 | 0.000642 |
| order-string-all-ok | before | 0.038996 | 0.001095 |
| order-string-all-ok | after | 0.035908 | 0.000343 |
| order-string-always-error | before | 0.038469 | 0.001978 |
| order-string-always-error | after | 0.035098 | 0.000232 |
| order-map-candidates | before | 0.039318 | 0.001025 |
| order-map-candidates | after | 0.036219 | 0.000375 |
| order-map-all-ok | before | 0.039161 | 0.001307 |
| order-map-all-ok | after | 0.035697 | 0.000246 |
| order-map-always-error | before | 0.038802 | 0.001990 |
| order-map-always-error | after | 0.035643 | 0.000276 |
| order-record-candidates | before | 0.039608 | 0.001223 |
| order-record-candidates | after | 0.035930 | 0.000253 |
| order-record-all-ok | before | 0.039527 | 0.001183 |
| order-record-all-ok | after | 0.036313 | 0.000552 |
| order-record-always-error | before | 0.039746 | 0.001027 |
| order-record-always-error | after | 0.036351 | 0.000554 |
| build-string-builder-8-0 | before | 0.016465 | 0.000579 |
| build-string-builder-8-0 | after | 0.015675 | 0.000212 |
| build-string-builder-all-8-0 | before | 0.016533 | 0.000515 |
| build-string-builder-all-8-0 | after | 0.015760 | 0.000205 |
| build-string-concatenate-8-0 | before | 0.016562 | 0.000385 |
| build-string-concatenate-8-0 | after | 0.015758 | 0.000659 |
| build-string-join-8-0 | before | 0.016326 | 0.000430 |
| build-string-join-8-0 | after | 0.015636 | 0.000183 |
| build-list-builder-8-0 | before | 0.016418 | 0.001040 |
| build-list-builder-8-0 | after | 0.015714 | 0.000259 |
| build-list-builder-all-8-0 | before | 0.016387 | 0.000950 |
| build-list-builder-all-8-0 | after | 0.015705 | 0.000074 |
| build-list-concatenate-8-0 | before | 0.016481 | 0.000656 |
| build-list-concatenate-8-0 | after | 0.015909 | 0.000080 |
| build-list-fold-8-0 | before | 0.016573 | 0.000512 |
| build-list-fold-8-0 | after | 0.015723 | 0.000114 |
| build-bytes-builder-8-0 | before | 0.016511 | 0.000601 |
| build-bytes-builder-8-0 | after | 0.015859 | 0.000148 |
| build-bytes-builder-all-8-0 | before | 0.016448 | 0.000384 |
| build-bytes-builder-all-8-0 | after | 0.015974 | 0.000187 |
| build-bytes-concatenate-8-0 | before | 0.016703 | 0.000598 |
| build-bytes-concatenate-8-0 | after | 0.016003 | 0.000292 |
| patterns-integer-100 | before | 0.015011 | 0.000780 |
| patterns-integer-100 | after | 0.014025 | 0.000313 |
| codegen-let-100 | before | 0.017118 | 0.000599 |
| codegen-let-100 | after | 0.016629 | 0.000130 |
| bridge-shared-8 | before | 0.004761 | 0.000173 |
| bridge-shared-8 | after | 0.004660 | 0.000564 |
| external-tests-normal-1 | before | 0.018498 | 0.000558 |
| external-tests-normal-1 | after | 0.017840 | 0.001338 |
| runtime-fib-short | before | 0.018295 | 0.000309 |
| runtime-fib-short | after | 0.017739 | 0.001092 |
| runtime-loop-short | before | 0.023983 | 0.000201 |
| runtime-loop-short | after | 0.023502 | 0.001332 |
| runtime-list-short | before | 0.029730 | 0.000687 |
| runtime-list-short | after | 0.029707 | 0.000803 |
| runtime-tree-short | before | 0.018796 | 0.000418 |
| runtime-tree-short | after | 0.018101 | 0.000663 |
| runtime-eval-short | before | 0.022332 | 0.000165 |
| runtime-eval-short | after | 0.022190 | 0.000918 |
| runtime-string-short | before | 0.016956 | 0.000581 |
| runtime-string-short | after | 0.016570 | 0.000129 |
| runtime-println-short | before | 0.017363 | 0.000400 |
| runtime-println-short | after | 0.016904 | 0.000614 |
| runtime-lines-short | before | 0.016994 | 0.000554 |
| runtime-lines-short | after | 0.016405 | 0.000206 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.4292e-05 | 1.125e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.708e-06 | 2.09e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8e-05 | 1.376e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5958e-05 | 8.33e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.125e-06 | 2.91e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.9124e-05 | 1.083e-06 |
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
    "before": "ac992bde2cb34d1861de3eb2943e75443a108189",
    "after": "6ca6f678e168701104d1995e6de4b9afb4be0153"
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
| functions-main-256-0 | 達成 | -0.0021432080000209908 | 0.002 |
| functions-main-1000-0 | 達成 | -0.01085337499999639 | 0.003190441699999269 |
| functions-main-1000-1 | 達成 | -0.011144625999989444 | 0.003151533399999096 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 達成 | -0.0006620430000054967 | 0.002 |
| functions-args-1000-0 | 達成 | -0.022434874999987642 | 0.004850883299999964 |
| functions-args-1000-1 | 達成 | -0.022462459000010426 | 0.004911104200000693 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | -0.004290833999988308 | 0.002584099999999978 |
| functions-modules-1000-1 | 達成 | -0.004587958999991315 | 0.002540437499999371 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 達成 | -0.0005548749999917391 | 0.002 |
| classes-0 | 達成 | -0.002144666999981837 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002714962500000695 |
| higher-1-300 | 判定不能 | None | 0.002974887499999568 |
| classes-300 | 達成 | -0.0019670419999897604 | 0.003935262499999226 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 達成 | -0.0008179160000025831 | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 達成 | -0.0014372070000092663 | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 達成 | -0.0024466669999867463 | 0.002066299999999899 |
| interval-range-64 | 達成 | -0.0018807919999943579 | 0.0024969957999999796 |
| interval-range-256 | 判定不能 | None | 0.0038308083000003993 |
| interval-http-0 | 判定不能 | None | 0.0021983999999989124 |
| interval-http-64 | 達成 | -0.0020892489999795316 | 0.0024202957999989397 |
| interval-http-256 | 達成 | -0.0024805000000185373 | 0.003241112500001009 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 達成 | -0.0009545419999881233 | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 達成 | -0.0011283329999969283 | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | -0.003300248999991595 | 0.004026604099999532 |
| property-seven-24-20-1000-always-error | 達成 | -0.003556165999995642 | 0.003893045799999584 |
| property-distinct-24-20-1000-all-ok | 達成 | -0.0037415420000144195 | 0.004003145900000504 |
| property-distinct-24-20-1000-always-error | 達成 | -0.004127667000005886 | 0.0039384584000004 |
| property-zero-24-20-1000-all-ok | 達成 | -0.003761874000005605 | 0.0040096790999996305 |
| property-zero-24-20-1000-always-error | 達成 | -0.0032886670000067397 | 0.003871412499999849 |
| property-max-24-20-1000-all-ok | 達成 | -0.0032712910000043394 | 0.004030033300000469 |
| property-max-24-20-1000-always-error | 達成 | -0.0035747499999985166 | 0.0038857541999988143 |
| order-string-candidates | 達成 | -0.003266749999994545 | 0.0038299999999992455 |
| order-string-all-ok | 達成 | -0.003088457999993466 | 0.003899599999999737 |
| order-string-always-error | 達成 | -0.0033707089999950313 | 0.003846895899999936 |
| order-map-candidates | 達成 | -0.003098874999992063 | 0.003931754100000262 |
| order-map-all-ok | 達成 | -0.003463206999995805 | 0.00391605410000011 |
| order-map-always-error | 達成 | -0.003159206999995945 | 0.003880191599999705 |
| order-record-candidates | 達成 | -0.003678041000000576 | 0.003960775000000183 |
| order-record-all-ok | 達成 | -0.003214457999987985 | 0.003952716599999917 |
| order-record-always-error | 達成 | -0.0033945830000163824 | 0.003974554200000569 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 達成 | -0.0007730410000021948 | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 達成 | -0.000690374999990695 | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 達成 | -0.0008504169999952182 | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.00239830000000012 |
| runtime-list-short | 判定不能 | None | 0.00297299170000116 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002233229200000153 |
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
    "verify": 1.8527186669999907,
    "cli": 5.643292499000026,
    "warmup": 0.6650749179999451,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.888266625,
    "cli": 11.877063999999976,
    "warmup": 1.367440078000044,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3090412909999998,
    "cli": 9.180248041000027,
    "warmup": 1.286532959999974,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.36784079199999553,
    "cli": 3.552804999999992,
    "warmup": 0.3596807510000133,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09923970900000256,
    "cli": 0.2798333749999955,
    "warmup": 0.029749124999980836,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.04380208300000277,
    "cli": 0.3305658330000085,
    "warmup": 0.03424295899999663,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.011277540999998337,
    "cli": 0.20526562499999557,
    "warmup": 0.008805625000007922,
    "probe_warmup": 0.00802554200001282,
    "rss": 0,
    "stages": 0.038707331999987105,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04833904200000916,
    "cli": 0.3449722080000015,
    "warmup": 0.03547816700000794,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.1799007920000264
  },
  "runtime": {
    "verify": 0.3376451669999909,
    "cli": 2.919133665000018,
    "warmup": 0.328937707999998,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
