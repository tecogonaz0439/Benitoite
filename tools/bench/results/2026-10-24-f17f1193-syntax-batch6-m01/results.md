# 版どうしの性能比較

候補: `f17f11933b981509014c841936731f114383aff6`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013821 | 0.000263 |
| functions-main-0-0 | after | 0.014028 | 0.000689 |
| functions-main-0-1 | before | 0.014499 | 0.001173 |
| functions-main-0-1 | after | 0.013979 | 0.000428 |
| functions-main-64-0 | before | 0.014504 | 0.000438 |
| functions-main-64-0 | after | 0.014459 | 0.000143 |
| functions-main-256-0 | before | 0.016974 | 0.000350 |
| functions-main-256-0 | after | 0.017425 | 0.000549 |
| functions-main-1000-0 | before | 0.031900 | 0.000153 |
| functions-main-1000-0 | after | 0.032038 | 0.000930 |
| functions-main-1000-1 | before | 0.031608 | 0.000719 |
| functions-main-1000-1 | after | 0.032089 | 0.000446 |
| functions-args-0-0 | before | 0.013516 | 0.001147 |
| functions-args-0-0 | after | 0.013703 | 0.000243 |
| functions-args-0-1 | before | 0.013699 | 0.000591 |
| functions-args-0-1 | after | 0.013691 | 0.000620 |
| functions-args-1000-0 | before | 0.049125 | 0.001254 |
| functions-args-1000-0 | after | 0.049092 | 0.001089 |
| functions-args-1000-1 | before | 0.050062 | 0.001533 |
| functions-args-1000-1 | after | 0.048820 | 0.000505 |
| functions-modules-0-0 | before | 0.013721 | 0.000694 |
| functions-modules-0-0 | after | 0.013579 | 0.000272 |
| functions-modules-0-1 | before | 0.013695 | 0.001204 |
| functions-modules-0-1 | after | 0.013507 | 0.000132 |
| functions-modules-1000-0 | before | 0.025321 | 0.000180 |
| functions-modules-1000-0 | after | 0.026042 | 0.000733 |
| functions-modules-1000-1 | before | 0.025277 | 0.000286 |
| functions-modules-1000-1 | after | 0.025860 | 0.001294 |
| existing-fib | before | 0.014570 | 0.000484 |
| existing-fib | after | 0.014511 | 0.000369 |
| existing-loop | before | 0.014543 | 0.002351 |
| existing-loop | after | 0.014391 | 0.000172 |
| existing-string | before | 0.014555 | 0.001177 |
| existing-string | after | 0.014502 | 0.000098 |
| higher-0-0 | before | 0.014138 | 0.000800 |
| higher-0-0 | after | 0.014308 | 0.000401 |
| higher-1-0 | before | 0.014783 | 0.000680 |
| higher-1-0 | after | 0.014794 | 0.000340 |
| classes-0 | before | 0.019715 | 0.000215 |
| classes-0 | after | 0.019901 | 0.000934 |
| higher-0-300 | before | 0.027377 | 0.000453 |
| higher-0-300 | after | 0.027980 | 0.001782 |
| higher-1-300 | before | 0.030138 | 0.000643 |
| higher-1-300 | after | 0.030258 | 0.001052 |
| classes-300 | before | 0.039341 | 0.000744 |
| classes-300 | after | 0.039299 | 0.000339 |
| depth-0-8 | before | 0.014905 | 0.001189 |
| depth-0-8 | after | 0.015121 | 0.000168 |
| depth-1-8 | before | 0.015420 | 0.000744 |
| depth-1-8 | after | 0.015446 | 0.000613 |
| f1-nofail-call | before | 0.015397 | 0.000573 |
| f1-nofail-call | after | 0.014738 | 0.000155 |
| f1-join-effects | before | 0.014815 | 0.000513 |
| f1-join-effects | after | 0.014987 | 0.000480 |
| control-16.3 | before | 0.013680 | 0.000928 |
| control-16.3 | after | 0.013835 | 0.000361 |
| interval-bind-64 | before | 0.014047 | 0.001010 |
| interval-bind-64 | after | 0.013961 | 0.000519 |
| interval-bind-256 | before | 0.014619 | 0.000789 |
| interval-bind-256 | after | 0.014404 | 0.000251 |
| interval-add-64 | before | 0.014200 | 0.000975 |
| interval-add-64 | after | 0.013786 | 0.000161 |
| interval-add-256 | before | 0.016000 | 0.000323 |
| interval-add-256 | after | 0.015391 | 0.000402 |
| interval-flow-64 | before | 0.014747 | 0.000994 |
| interval-flow-64 | after | 0.014720 | 0.000331 |
| interval-flow-256 | before | 0.017617 | 0.000334 |
| interval-flow-256 | after | 0.017608 | 0.001175 |
| interval-range-0 | before | 0.021207 | 0.000457 |
| interval-range-0 | after | 0.021683 | 0.000622 |
| interval-range-64 | before | 0.026094 | 0.000572 |
| interval-range-64 | after | 0.026045 | 0.001368 |
| interval-range-256 | before | 0.039159 | 0.000878 |
| interval-range-256 | after | 0.039132 | 0.000432 |
| interval-http-0 | before | 0.021691 | 0.000290 |
| interval-http-0 | after | 0.021678 | 0.001611 |
| interval-http-64 | before | 0.024265 | 0.000204 |
| interval-http-64 | after | 0.024899 | 0.001022 |
| interval-http-256 | before | 0.032954 | 0.002319 |
| interval-http-256 | after | 0.032888 | 0.000247 |
| interval-width-Integer8-64 | before | 0.014692 | 0.000865 |
| interval-width-Integer8-64 | after | 0.014692 | 0.000195 |
| interval-width-Integer8-256 | before | 0.018376 | 0.000608 |
| interval-width-Integer8-256 | after | 0.019245 | 0.001100 |
| interval-width-Integer16-64 | before | 0.015058 | 0.000898 |
| interval-width-Integer16-64 | after | 0.014754 | 0.000079 |
| interval-width-Integer16-256 | before | 0.017534 | 0.000574 |
| interval-width-Integer16-256 | after | 0.017611 | 0.000571 |
| interval-width-Integer32-64 | before | 0.014686 | 0.000762 |
| interval-width-Integer32-64 | after | 0.014728 | 0.000618 |
| interval-width-Integer32-256 | before | 0.017927 | 0.000415 |
| interval-width-Integer32-256 | after | 0.017437 | 0.000422 |
| interval-width-Integer64-64 | before | 0.014469 | 0.000664 |
| interval-width-Integer64-64 | after | 0.014632 | 0.000293 |
| interval-width-Integer64-256 | before | 0.017729 | 0.000335 |
| interval-width-Integer64-256 | after | 0.017522 | 0.000470 |
| interval-width-UnsignedInteger16-64 | before | 0.014662 | 0.000728 |
| interval-width-UnsignedInteger16-64 | after | 0.014455 | 0.000241 |
| interval-width-UnsignedInteger16-256 | before | 0.017197 | 0.001519 |
| interval-width-UnsignedInteger16-256 | after | 0.017773 | 0.001329 |
| interval-width-UnsignedInteger32-64 | before | 0.014449 | 0.001671 |
| interval-width-UnsignedInteger32-64 | after | 0.015081 | 0.000497 |
| interval-width-UnsignedInteger32-256 | before | 0.017164 | 0.000384 |
| interval-width-UnsignedInteger32-256 | after | 0.017683 | 0.000580 |
| interval-width-UnsignedInteger64-64 | before | 0.014500 | 0.001350 |
| interval-width-UnsignedInteger64-64 | after | 0.014458 | 0.000229 |
| interval-width-UnsignedInteger64-256 | before | 0.018434 | 0.001039 |
| interval-width-UnsignedInteger64-256 | after | 0.018196 | 0.001041 |
| property-seven-24-20-1000-all-ok | before | 0.041385 | 0.001566 |
| property-seven-24-20-1000-all-ok | after | 0.041073 | 0.001591 |
| property-seven-24-20-1000-always-error | before | 0.040076 | 0.002415 |
| property-seven-24-20-1000-always-error | after | 0.040132 | 0.001878 |
| property-distinct-24-20-1000-all-ok | before | 0.042936 | 0.001563 |
| property-distinct-24-20-1000-all-ok | after | 0.041059 | 0.001237 |
| property-distinct-24-20-1000-always-error | before | 0.040970 | 0.001529 |
| property-distinct-24-20-1000-always-error | after | 0.041759 | 0.001544 |
| property-zero-24-20-1000-all-ok | before | 0.049198 | 0.004913 |
| property-zero-24-20-1000-all-ok | after | 0.043580 | 0.003678 |
| property-zero-24-20-1000-always-error | before | 0.053553 | 0.009954 |
| property-zero-24-20-1000-always-error | after | 0.051950 | 0.007466 |
| property-max-24-20-1000-all-ok | before | 0.045177 | 0.002023 |
| property-max-24-20-1000-all-ok | after | 0.045206 | 0.003103 |
| property-max-24-20-1000-always-error | before | 0.039607 | 0.006740 |
| property-max-24-20-1000-always-error | after | 0.040060 | 0.001272 |
| order-string-candidates | before | 0.038971 | 0.001144 |
| order-string-candidates | after | 0.039311 | 0.000192 |
| order-string-all-ok | before | 0.039864 | 0.001686 |
| order-string-all-ok | after | 0.040028 | 0.000745 |
| order-string-always-error | before | 0.039042 | 0.001360 |
| order-string-always-error | after | 0.039566 | 0.000443 |
| order-map-candidates | before | 0.039980 | 0.001157 |
| order-map-candidates | after | 0.040049 | 0.000675 |
| order-map-all-ok | before | 0.040932 | 0.001463 |
| order-map-all-ok | after | 0.040131 | 0.000676 |
| order-map-always-error | before | 0.041398 | 0.001433 |
| order-map-always-error | after | 0.040042 | 0.001958 |
| order-record-candidates | before | 0.041193 | 0.000867 |
| order-record-candidates | after | 0.040493 | 0.000467 |
| order-record-all-ok | before | 0.040867 | 0.001142 |
| order-record-all-ok | after | 0.040497 | 0.000786 |
| order-record-always-error | before | 0.040583 | 0.001622 |
| order-record-always-error | after | 0.040430 | 0.000101 |
| build-string-builder-8-0 | before | 0.017067 | 0.000123 |
| build-string-builder-8-0 | after | 0.016854 | 0.001129 |
| build-string-builder-all-8-0 | before | 0.017060 | 0.000511 |
| build-string-builder-all-8-0 | after | 0.017039 | 0.000743 |
| build-string-concatenate-8-0 | before | 0.016816 | 0.000282 |
| build-string-concatenate-8-0 | after | 0.016908 | 0.000381 |
| build-string-join-8-0 | before | 0.016639 | 0.000260 |
| build-string-join-8-0 | after | 0.016754 | 0.001059 |
| build-list-builder-8-0 | before | 0.017035 | 0.000369 |
| build-list-builder-8-0 | after | 0.017147 | 0.000144 |
| build-list-builder-all-8-0 | before | 0.016970 | 0.000229 |
| build-list-builder-all-8-0 | after | 0.017010 | 0.001345 |
| build-list-concatenate-8-0 | before | 0.017084 | 0.000272 |
| build-list-concatenate-8-0 | after | 0.017423 | 0.001716 |
| build-list-fold-8-0 | before | 0.016968 | 0.000231 |
| build-list-fold-8-0 | after | 0.016942 | 0.000664 |
| build-bytes-builder-8-0 | before | 0.017140 | 0.000210 |
| build-bytes-builder-8-0 | after | 0.017067 | 0.000448 |
| build-bytes-builder-all-8-0 | before | 0.017102 | 0.000416 |
| build-bytes-builder-all-8-0 | after | 0.017198 | 0.001226 |
| build-bytes-concatenate-8-0 | before | 0.016909 | 0.000326 |
| build-bytes-concatenate-8-0 | after | 0.017245 | 0.000454 |
| patterns-integer-100 | before | 0.015317 | 0.000751 |
| patterns-integer-100 | after | 0.015313 | 0.000316 |
| codegen-let-100 | before | 0.017988 | 0.000325 |
| codegen-let-100 | after | 0.018241 | 0.001067 |
| bridge-shared-8 | before | 0.004872 | 0.000284 |
| bridge-shared-8 | after | 0.004688 | 0.000265 |
| external-tests-normal-1 | before | 0.019033 | 0.000773 |
| external-tests-normal-1 | after | 0.019495 | 0.001383 |
| runtime-fib-short | before | 0.019027 | 0.000440 |
| runtime-fib-short | after | 0.019261 | 0.000815 |
| runtime-loop-short | before | 0.025132 | 0.000393 |
| runtime-loop-short | after | 0.025094 | 0.001268 |
| runtime-list-short | before | 0.030599 | 0.000876 |
| runtime-list-short | after | 0.030678 | 0.000284 |
| runtime-tree-short | before | 0.019342 | 0.000455 |
| runtime-tree-short | after | 0.019526 | 0.000979 |
| runtime-eval-short | before | 0.022904 | 0.000593 |
| runtime-eval-short | after | 0.023235 | 0.000803 |
| runtime-string-short | before | 0.017751 | 0.000292 |
| runtime-string-short | after | 0.017781 | 0.001341 |
| runtime-println-short | before | 0.017895 | 0.000312 |
| runtime-println-short | after | 0.018367 | 0.002032 |
| runtime-lines-short | before | 0.017914 | 0.000164 |
| runtime-lines-short | after | 0.017793 | 0.000564 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.4125e-05 | 2.249e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.084e-06 | 2.08e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.7167e-05 | 2.708e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5917e-05 | 1.708e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.25e-06 | 8.3e-08 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.9126e-05 | 1.75e-06 |
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
    "before": "706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8",
    "after": "f17f11933b981509014c841936731f114383aff6"
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
| functions-main-1000-0 | 判定不能 | None | 0.0031899709000001056 |
| functions-main-1000-1 | 判定不能 | None | 0.003160791700000232 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.004912479200000064 |
| functions-args-1000-1 | 判定不能 | None | 0.005006208399998969 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002532112500000494 |
| functions-modules-1000-1 | 判定不能 | None | 0.0025276582999993026 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0027376666999998633 |
| higher-1-300 | 判定不能 | None | 0.0030138082999997097 |
| classes-300 | 判定不能 | None | 0.003934074999999382 |
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
| interval-range-0 | 判定不能 | None | 0.002120658299999434 |
| interval-range-64 | 判定不能 | None | 0.0026093875000000825 |
| interval-range-256 | 判定不能 | None | 0.003915891700000884 |
| interval-http-0 | 判定不能 | None | 0.002169062500000507 |
| interval-http-64 | 判定不能 | None | 0.0024264667000011286 |
| interval-http-256 | 判定不能 | None | 0.003295383300000765 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.004138541599999712 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.00400762079999879 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.004293616599998984 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.004097012500000119 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.004919791700000076 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.005355325000000733 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0045177082999998674 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003960683299999346 |
| order-string-candidates | 判定不能 | None | 0.003897104200000001 |
| order-string-all-ok | 判定不能 | None | 0.003986366699999167 |
| order-string-always-error | 判定不能 | None | 0.003904187499999523 |
| order-map-candidates | 判定不能 | None | 0.003998049999999864 |
| order-map-all-ok | 判定不能 | None | 0.004093170900000587 |
| order-map-always-error | 判定不能 | None | 0.004139837499999999 |
| order-record-candidates | 判定不能 | None | 0.00411926660000006 |
| order-record-all-ok | 判定不能 | None | 0.004086691700000244 |
| order-record-always-error | 判定不能 | None | 0.004058274999999867 |
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
| runtime-loop-short | 判定不能 | None | 0.0025131833000003215 |
| runtime-list-short | 判定不能 | None | 0.0030599124999994842 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002290395800000056 |
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
    "verify": 2.0086244590000035,
    "cli": 6.126368627000005,
    "warmup": 0.7488607890000054,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.9710643339999905,
    "cli": 12.29804070900002,
    "warmup": 1.4154477499999558,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3990906669999958,
    "cli": 10.213213541000016,
    "warmup": 1.425511333000017,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.38629000000000246,
    "cli": 3.7461629180000102,
    "warmup": 0.3733122919999943,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10369758299999887,
    "cli": 0.29466566700000385,
    "warmup": 0.030824957999996627,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03984825000000569,
    "cli": 0.3492633750000067,
    "warmup": 0.03612137499999335,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009688834000002089,
    "cli": 0.21252479200001062,
    "warmup": 0.009445334000020011,
    "probe_warmup": 0.008240833000002112,
    "rss": 0,
    "stages": 0.040700623999995855,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.0423782919999951,
    "cli": 0.3645964579999941,
    "warmup": 0.03754616599999849,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.19003816799997253
  },
  "runtime": {
    "verify": 0.34713412499999663,
    "cli": 3.072106000000005,
    "warmup": 0.34174283299996944,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
