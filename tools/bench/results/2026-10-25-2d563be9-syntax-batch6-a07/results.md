# 版どうしの性能比較

候補: `2d563be9d72a1baf19065b081cf51de32a0cf52a`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013584 | 0.000292 |
| functions-main-0-0 | after | 0.013090 | 0.000608 |
| functions-main-0-1 | before | 0.013769 | 0.000500 |
| functions-main-0-1 | after | 0.013266 | 0.000472 |
| functions-main-64-0 | before | 0.014828 | 0.001111 |
| functions-main-64-0 | after | 0.013413 | 0.000084 |
| functions-main-256-0 | before | 0.017295 | 0.000512 |
| functions-main-256-0 | after | 0.014955 | 0.000225 |
| functions-main-1000-0 | before | 0.032014 | 0.000412 |
| functions-main-1000-0 | after | 0.020536 | 0.000911 |
| functions-main-1000-1 | before | 0.032096 | 0.000506 |
| functions-main-1000-1 | after | 0.020475 | 0.001226 |
| functions-args-0-0 | before | 0.013947 | 0.000763 |
| functions-args-0-0 | after | 0.012885 | 0.000280 |
| functions-args-0-1 | before | 0.013772 | 0.000645 |
| functions-args-0-1 | after | 0.012976 | 0.000095 |
| functions-args-1000-0 | before | 0.049644 | 0.000833 |
| functions-args-1000-0 | after | 0.026743 | 0.000419 |
| functions-args-1000-1 | before | 0.050570 | 0.001750 |
| functions-args-1000-1 | after | 0.027310 | 0.000578 |
| functions-modules-0-0 | before | 0.014403 | 0.001360 |
| functions-modules-0-0 | after | 0.013551 | 0.000321 |
| functions-modules-0-1 | before | 0.013782 | 0.001481 |
| functions-modules-0-1 | after | 0.013112 | 0.000391 |
| functions-modules-1000-0 | before | 0.025540 | 0.000175 |
| functions-modules-1000-0 | after | 0.021011 | 0.000746 |
| functions-modules-1000-1 | before | 0.025576 | 0.000602 |
| functions-modules-1000-1 | after | 0.020925 | 0.001147 |
| existing-fib | before | 0.014352 | 0.000629 |
| existing-fib | after | 0.013452 | 0.000183 |
| existing-loop | before | 0.014391 | 0.000788 |
| existing-loop | after | 0.013661 | 0.000164 |
| existing-string | before | 0.014122 | 0.001072 |
| existing-string | after | 0.013466 | 0.000268 |
| higher-0-0 | before | 0.013541 | 0.000611 |
| higher-0-0 | after | 0.012957 | 0.000201 |
| higher-1-0 | before | 0.014534 | 0.001334 |
| higher-1-0 | after | 0.013868 | 0.000109 |
| classes-0 | before | 0.019662 | 0.000791 |
| classes-0 | after | 0.017545 | 0.001363 |
| higher-0-300 | before | 0.027502 | 0.000849 |
| higher-0-300 | after | 0.027558 | 0.001697 |
| higher-1-300 | before | 0.030265 | 0.000234 |
| higher-1-300 | after | 0.029942 | 0.001229 |
| classes-300 | before | 0.039342 | 0.000985 |
| classes-300 | after | 0.036660 | 0.000853 |
| depth-0-8 | before | 0.015379 | 0.001479 |
| depth-0-8 | after | 0.014631 | 0.000516 |
| depth-1-8 | before | 0.015592 | 0.000407 |
| depth-1-8 | after | 0.015038 | 0.000953 |
| f1-nofail-call | before | 0.014750 | 0.000489 |
| f1-nofail-call | after | 0.014001 | 0.000247 |
| f1-join-effects | before | 0.014614 | 0.001530 |
| f1-join-effects | after | 0.013752 | 0.000275 |
| control-16.3 | before | 0.013648 | 0.001097 |
| control-16.3 | after | 0.012995 | 0.000398 |
| interval-bind-64 | before | 0.014111 | 0.001238 |
| interval-bind-64 | after | 0.013427 | 0.000624 |
| interval-bind-256 | before | 0.014603 | 0.001853 |
| interval-bind-256 | after | 0.013937 | 0.000208 |
| interval-add-64 | before | 0.013998 | 0.000688 |
| interval-add-64 | after | 0.013460 | 0.000992 |
| interval-add-256 | before | 0.015523 | 0.001023 |
| interval-add-256 | after | 0.014750 | 0.000272 |
| interval-flow-64 | before | 0.014686 | 0.001070 |
| interval-flow-64 | after | 0.013938 | 0.000072 |
| interval-flow-256 | before | 0.017810 | 0.000446 |
| interval-flow-256 | after | 0.016929 | 0.000140 |
| interval-range-0 | before | 0.020905 | 0.000483 |
| interval-range-0 | after | 0.018384 | 0.001315 |
| interval-range-64 | before | 0.025279 | 0.000923 |
| interval-range-64 | after | 0.024265 | 0.000898 |
| interval-range-256 | before | 0.041415 | 0.003160 |
| interval-range-256 | after | 0.038279 | 0.001642 |
| interval-http-0 | before | 0.021622 | 0.000753 |
| interval-http-0 | after | 0.019530 | 0.001586 |
| interval-http-64 | before | 0.024675 | 0.000250 |
| interval-http-64 | after | 0.021750 | 0.000819 |
| interval-http-256 | before | 0.034417 | 0.001033 |
| interval-http-256 | after | 0.030866 | 0.001509 |
| interval-width-Integer8-64 | before | 0.015895 | 0.001461 |
| interval-width-Integer8-64 | after | 0.014400 | 0.000474 |
| interval-width-Integer8-256 | before | 0.017767 | 0.000690 |
| interval-width-Integer8-256 | after | 0.016947 | 0.001670 |
| interval-width-Integer16-64 | before | 0.014708 | 0.001099 |
| interval-width-Integer16-64 | after | 0.014059 | 0.000281 |
| interval-width-Integer16-256 | before | 0.017716 | 0.000533 |
| interval-width-Integer16-256 | after | 0.017246 | 0.000489 |
| interval-width-Integer32-64 | before | 0.016176 | 0.001157 |
| interval-width-Integer32-64 | after | 0.015381 | 0.000228 |
| interval-width-Integer32-256 | before | 0.019258 | 0.000628 |
| interval-width-Integer32-256 | after | 0.019038 | 0.002535 |
| interval-width-Integer64-64 | before | 0.016328 | 0.000472 |
| interval-width-Integer64-64 | after | 0.015871 | 0.000308 |
| interval-width-Integer64-256 | before | 0.018631 | 0.000940 |
| interval-width-Integer64-256 | after | 0.018046 | 0.001412 |
| interval-width-UnsignedInteger16-64 | before | 0.016292 | 0.001151 |
| interval-width-UnsignedInteger16-64 | after | 0.015623 | 0.001886 |
| interval-width-UnsignedInteger16-256 | before | 0.018631 | 0.000511 |
| interval-width-UnsignedInteger16-256 | after | 0.018432 | 0.001310 |
| interval-width-UnsignedInteger32-64 | before | 0.015080 | 0.001826 |
| interval-width-UnsignedInteger32-64 | after | 0.014708 | 0.000683 |
| interval-width-UnsignedInteger32-256 | before | 0.017804 | 0.000552 |
| interval-width-UnsignedInteger32-256 | after | 0.017328 | 0.000416 |
| interval-width-UnsignedInteger64-64 | before | 0.015223 | 0.001225 |
| interval-width-UnsignedInteger64-64 | after | 0.014430 | 0.000513 |
| interval-width-UnsignedInteger64-256 | before | 0.017804 | 0.001982 |
| interval-width-UnsignedInteger64-256 | after | 0.017059 | 0.000874 |
| property-seven-24-20-1000-all-ok | before | 0.040442 | 0.001238 |
| property-seven-24-20-1000-all-ok | after | 0.037965 | 0.000519 |
| property-seven-24-20-1000-always-error | before | 0.039629 | 0.003060 |
| property-seven-24-20-1000-always-error | after | 0.035720 | 0.000652 |
| property-distinct-24-20-1000-all-ok | before | 0.041529 | 0.002585 |
| property-distinct-24-20-1000-all-ok | after | 0.038283 | 0.004001 |
| property-distinct-24-20-1000-always-error | before | 0.039068 | 0.004304 |
| property-distinct-24-20-1000-always-error | after | 0.035953 | 0.000564 |
| property-zero-24-20-1000-all-ok | before | 0.043136 | 0.000599 |
| property-zero-24-20-1000-all-ok | after | 0.038899 | 0.002193 |
| property-zero-24-20-1000-always-error | before | 0.039883 | 0.002562 |
| property-zero-24-20-1000-always-error | after | 0.035553 | 0.000585 |
| property-max-24-20-1000-all-ok | before | 0.040625 | 0.001624 |
| property-max-24-20-1000-all-ok | after | 0.037311 | 0.000707 |
| property-max-24-20-1000-always-error | before | 0.039512 | 0.001860 |
| property-max-24-20-1000-always-error | after | 0.035833 | 0.000208 |
| order-string-candidates | before | 0.039073 | 0.000935 |
| order-string-candidates | after | 0.035269 | 0.000298 |
| order-string-all-ok | before | 0.039714 | 0.001577 |
| order-string-all-ok | after | 0.036041 | 0.000811 |
| order-string-always-error | before | 0.038986 | 0.001744 |
| order-string-always-error | after | 0.036012 | 0.000547 |
| order-map-candidates | before | 0.038988 | 0.001806 |
| order-map-candidates | after | 0.035986 | 0.000604 |
| order-map-all-ok | before | 0.040869 | 0.001834 |
| order-map-all-ok | after | 0.036280 | 0.000341 |
| order-map-always-error | before | 0.039762 | 0.001559 |
| order-map-always-error | after | 0.036409 | 0.001779 |
| order-record-candidates | before | 0.040010 | 0.001565 |
| order-record-candidates | after | 0.036662 | 0.001313 |
| order-record-all-ok | before | 0.040204 | 0.000911 |
| order-record-all-ok | after | 0.036637 | 0.000928 |
| order-record-always-error | before | 0.039868 | 0.001285 |
| order-record-always-error | after | 0.036150 | 0.000498 |
| build-string-builder-8-0 | before | 0.016353 | 0.000535 |
| build-string-builder-8-0 | after | 0.015725 | 0.000230 |
| build-string-builder-all-8-0 | before | 0.016434 | 0.000479 |
| build-string-builder-all-8-0 | after | 0.015709 | 0.000219 |
| build-string-concatenate-8-0 | before | 0.016426 | 0.000510 |
| build-string-concatenate-8-0 | after | 0.015938 | 0.000480 |
| build-string-join-8-0 | before | 0.017651 | 0.000819 |
| build-string-join-8-0 | after | 0.015659 | 0.000973 |
| build-list-builder-8-0 | before | 0.018034 | 0.001223 |
| build-list-builder-8-0 | after | 0.016388 | 0.000851 |
| build-list-builder-all-8-0 | before | 0.017014 | 0.000399 |
| build-list-builder-all-8-0 | after | 0.016217 | 0.000895 |
| build-list-concatenate-8-0 | before | 0.017354 | 0.000815 |
| build-list-concatenate-8-0 | after | 0.016312 | 0.000610 |
| build-list-fold-8-0 | before | 0.017602 | 0.000785 |
| build-list-fold-8-0 | after | 0.017324 | 0.001790 |
| build-bytes-builder-8-0 | before | 0.016573 | 0.000675 |
| build-bytes-builder-8-0 | after | 0.016642 | 0.002962 |
| build-bytes-builder-all-8-0 | before | 0.016820 | 0.000657 |
| build-bytes-builder-all-8-0 | after | 0.016022 | 0.001066 |
| build-bytes-concatenate-8-0 | before | 0.016577 | 0.001275 |
| build-bytes-concatenate-8-0 | after | 0.016234 | 0.000873 |
| patterns-integer-100 | before | 0.014920 | 0.000873 |
| patterns-integer-100 | after | 0.014620 | 0.000394 |
| codegen-let-100 | before | 0.017393 | 0.000541 |
| codegen-let-100 | after | 0.017154 | 0.000778 |
| bridge-shared-8 | before | 0.005883 | 0.000530 |
| bridge-shared-8 | after | 0.005491 | 0.000349 |
| external-tests-normal-1 | before | 0.019659 | 0.000684 |
| external-tests-normal-1 | after | 0.019102 | 0.001221 |
| runtime-fib-short | before | 0.018736 | 0.000430 |
| runtime-fib-short | after | 0.017961 | 0.001381 |
| runtime-loop-short | before | 0.024234 | 0.000359 |
| runtime-loop-short | after | 0.024037 | 0.001163 |
| runtime-list-short | before | 0.029862 | 0.000375 |
| runtime-list-short | after | 0.029602 | 0.000526 |
| runtime-tree-short | before | 0.018772 | 0.000540 |
| runtime-tree-short | after | 0.018356 | 0.000676 |
| runtime-eval-short | before | 0.022846 | 0.000119 |
| runtime-eval-short | after | 0.021931 | 0.000733 |
| runtime-string-short | before | 0.017374 | 0.000288 |
| runtime-string-short | after | 0.016603 | 0.000770 |
| runtime-println-short | before | 0.017755 | 0.000348 |
| runtime-println-short | after | 0.016812 | 0.000818 |
| runtime-lines-short | before | 0.017013 | 0.000732 |
| runtime-lines-short | after | 0.016818 | 0.000625 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5583e-05 | 1.083e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 4.375e-06 | 1.25e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.9458e-05 | 1.083e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.6375e-05 | 8.74e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 4.167e-06 | 2.08e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 2.0125e-05 | 8.33e-07 |
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
    "after": "2d563be9d72a1baf19065b081cf51de32a0cf52a"
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
| functions-main-64-0 | 達成 | -0.0014142089999893415 | 0.002 |
| functions-main-256-0 | 達成 | -0.002340207999992572 | 0.002 |
| functions-main-1000-0 | 達成 | -0.011477917000007665 | 0.003201366700000108 |
| functions-main-1000-1 | 達成 | -0.011621583000021474 | 0.003209637500000895 |
| functions-args-0-0 | 達成 | -0.0010626659999957155 | 0.002 |
| functions-args-0-1 | 達成 | -0.0007955830000128117 | 0.002 |
| functions-args-1000-0 | 達成 | -0.022901166999986344 | 0.004964375000000132 |
| functions-args-1000-1 | 達成 | -0.023259790999986762 | 0.005057020799998213 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | -0.004528542000031166 | 0.0025539625000021715 |
| functions-modules-1000-1 | 達成 | -0.00465083399998889 | 0.0025575750000001564 |
| existing-fib | 達成 | -0.0009000830000047699 | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0027501791999981155 |
| higher-1-300 | 判定不能 | None | 0.0030265458000002356 |
| classes-300 | 達成 | -0.0026821249999784413 | 0.003934187499999098 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 達成 | -0.0007490419999953701 | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 達成 | -0.0008809170000176891 | 0.002 |
| interval-range-0 | 達成 | -0.0025215839999930267 | 0.002090512500001296 |
| interval-range-64 | 判定不能 | None | 0.0025279124999997293 |
| interval-range-256 | 判定不能 | None | 0.004141487499998675 |
| interval-http-0 | 判定不能 | None | 0.0021622290999999904 |
| interval-http-64 | 達成 | -0.0029245410000271477 | 0.0024674708000020475 |
| interval-http-256 | 達成 | -0.0035510830000191618 | 0.003441708300002233 |
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
| property-seven-24-20-1000-all-ok | 達成 | -0.0024772509999877457 | 0.0040441958999991815 |
| property-seven-24-20-1000-always-error | 達成 | -0.003908667000018795 | 0.0039628958999998075 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0041528874999983145 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0039067541999997955 |
| property-zero-24-20-1000-all-ok | 達成 | -0.004237457999977323 | 0.004313612499998953 |
| property-zero-24-20-1000-always-error | 達成 | -0.004329666999979054 | 0.003988266700000054 |
| property-max-24-20-1000-all-ok | 達成 | -0.0033144170000127815 | 0.004062504199998785 |
| property-max-24-20-1000-always-error | 達成 | -0.003678667000031055 | 0.003951162500001715 |
| order-string-candidates | 達成 | -0.003804083000005676 | 0.003907308300000523 |
| order-string-all-ok | 達成 | -0.003672582999968199 | 0.003971366599998305 |
| order-string-always-error | 達成 | -0.0029736669999920196 | 0.0038985542000006036 |
| order-map-candidates | 達成 | -0.003001457999999957 | 0.0038987708000007616 |
| order-map-all-ok | 達成 | -0.004589417000005369 | 0.004086924999998587 |
| order-map-always-error | 達成 | -0.0033528740000008384 | 0.003976220800001329 |
| order-record-candidates | 達成 | -0.0033479170000134673 | 0.004000970800001369 |
| order-record-all-ok | 達成 | -0.0035671260000071925 | 0.004020441700001243 |
| order-record-always-error | 達成 | -0.0037180419999742753 | 0.003986845899999025 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 達成 | -0.0007256660000223292 | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 達成 | -0.0019918339999946966 | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0024233832999982496 |
| runtime-list-short | 判定不能 | None | 0.0029861624999995232 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 達成 | -0.0009151669999880596 | 0.002284637500000031 |
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
    "verify": 2.638667749999996,
    "cli": 5.664640373999987,
    "warmup": 0.6618910440000718,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.958505540999994,
    "cli": 12.227124121999907,
    "warmup": 1.3950662089998218,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3304843749999975,
    "cli": 9.364504458999988,
    "warmup": 1.307804002000097,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.37881170800000064,
    "cli": 3.658819543000021,
    "warmup": 0.36265883399991594,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09901054099998419,
    "cli": 0.2821580840000024,
    "warmup": 0.029095583000014358,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.036610042000006615,
    "cli": 0.338839207999996,
    "warmup": 0.03445641700000124,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010126625000026479,
    "cli": 0.2404679170000179,
    "warmup": 0.00958662600001503,
    "probe_warmup": 0.010132208000015908,
    "rss": 0,
    "stages": 0.04898433399995383,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04267187499999636,
    "cli": 0.3678633329999741,
    "warmup": 0.03861162499998727,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.193191832999986
  },
  "runtime": {
    "verify": 0.3376642079999783,
    "cli": 2.9458460840000384,
    "warmup": 0.3301675829999624,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
