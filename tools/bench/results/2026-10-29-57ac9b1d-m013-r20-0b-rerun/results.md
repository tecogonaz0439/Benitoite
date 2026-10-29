# 版どうしの性能比較

候補: `57ac9b1d7a1dc396c0beca4f3be87daa0043a14f`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.012798 | 0.000793 |
| functions-main-0-0 | after | 0.013147 | 0.000372 |
| functions-main-0-1 | before | 0.012741 | 0.000329 |
| functions-main-0-1 | after | 0.012682 | 0.000185 |
| functions-main-64-0 | before | 0.013111 | 0.000469 |
| functions-main-64-0 | after | 0.013219 | 0.000158 |
| functions-main-256-0 | before | 0.014425 | 0.001260 |
| functions-main-256-0 | after | 0.014923 | 0.000423 |
| functions-main-1000-0 | before | 0.019945 | 0.000217 |
| functions-main-1000-0 | after | 0.020623 | 0.000673 |
| functions-main-1000-1 | before | 0.020068 | 0.000189 |
| functions-main-1000-1 | after | 0.020308 | 0.000179 |
| functions-args-0-0 | before | 0.012774 | 0.000246 |
| functions-args-0-0 | after | 0.012718 | 0.000300 |
| functions-args-0-1 | before | 0.012650 | 0.000149 |
| functions-args-0-1 | after | 0.012928 | 0.000181 |
| functions-args-1000-0 | before | 0.026264 | 0.000824 |
| functions-args-1000-0 | after | 0.026889 | 0.001046 |
| functions-args-1000-1 | before | 0.026638 | 0.000749 |
| functions-args-1000-1 | after | 0.027761 | 0.001150 |
| functions-modules-0-0 | before | 0.012836 | 0.000451 |
| functions-modules-0-0 | after | 0.013028 | 0.000269 |
| functions-modules-0-1 | before | 0.012677 | 0.000405 |
| functions-modules-0-1 | after | 0.012857 | 0.000363 |
| functions-modules-1000-0 | before | 0.020514 | 0.000432 |
| functions-modules-1000-0 | after | 0.020579 | 0.000293 |
| functions-modules-1000-1 | before | 0.020143 | 0.000251 |
| functions-modules-1000-1 | after | 0.020938 | 0.000447 |
| existing-fib | before | 0.013347 | 0.000950 |
| existing-fib | after | 0.013336 | 0.000163 |
| existing-loop | before | 0.013826 | 0.000426 |
| existing-loop | after | 0.013508 | 0.000193 |
| existing-string | before | 0.013293 | 0.000838 |
| existing-string | after | 0.013552 | 0.000204 |
| higher-0-0 | before | 0.012750 | 0.000204 |
| higher-0-0 | after | 0.012740 | 0.000226 |
| higher-1-0 | before | 0.013842 | 0.000617 |
| higher-1-0 | after | 0.013907 | 0.000152 |
| classes-0 | before | 0.017296 | 0.000089 |
| classes-0 | after | 0.017867 | 0.000749 |
| higher-0-300 | before | 0.027733 | 0.000261 |
| higher-0-300 | after | 0.028559 | 0.000559 |
| higher-1-300 | before | 0.030509 | 0.000216 |
| higher-1-300 | after | 0.031491 | 0.001580 |
| classes-300 | before | 0.036239 | 0.001708 |
| classes-300 | after | 0.037724 | 0.000935 |
| depth-0-8 | before | 0.015145 | 0.000830 |
| depth-0-8 | after | 0.015276 | 0.000618 |
| depth-1-8 | before | 0.014652 | 0.000523 |
| depth-1-8 | after | 0.014726 | 0.001283 |
| f1-nofail-call | before | 0.013764 | 0.000982 |
| f1-nofail-call | after | 0.014101 | 0.000260 |
| f1-join-effects | before | 0.013639 | 0.000679 |
| f1-join-effects | after | 0.014193 | 0.000176 |
| control-16.3 | before | 0.012704 | 0.000278 |
| control-16.3 | after | 0.013072 | 0.000357 |
| interval-bind-64 | before | 0.013075 | 0.000275 |
| interval-bind-64 | after | 0.013201 | 0.000210 |
| interval-bind-256 | before | 0.013446 | 0.000908 |
| interval-bind-256 | after | 0.013679 | 0.000577 |
| interval-add-64 | before | 0.013008 | 0.000183 |
| interval-add-64 | after | 0.013216 | 0.000146 |
| interval-add-256 | before | 0.014604 | 0.000449 |
| interval-add-256 | after | 0.014593 | 0.000202 |
| interval-flow-64 | before | 0.013606 | 0.000161 |
| interval-flow-64 | after | 0.013975 | 0.000658 |
| interval-flow-256 | before | 0.016951 | 0.000625 |
| interval-flow-256 | after | 0.017154 | 0.000128 |
| interval-range-0 | before | 0.018410 | 0.000896 |
| interval-range-0 | after | 0.018705 | 0.000157 |
| interval-range-64 | before | 0.022423 | 0.000336 |
| interval-range-64 | after | 0.023073 | 0.000695 |
| interval-range-256 | before | 0.035214 | 0.000609 |
| interval-range-256 | after | 0.036637 | 0.000611 |
| interval-http-0 | before | 0.018585 | 0.000306 |
| interval-http-0 | after | 0.020567 | 0.000551 |
| interval-http-64 | before | 0.021916 | 0.001564 |
| interval-http-64 | after | 0.024235 | 0.000917 |
| interval-http-256 | before | 0.029103 | 0.000285 |
| interval-http-256 | after | 0.031646 | 0.000342 |
| interval-width-Integer8-64 | before | 0.013741 | 0.001025 |
| interval-width-Integer8-64 | after | 0.013825 | 0.000348 |
| interval-width-Integer8-256 | before | 0.016555 | 0.000297 |
| interval-width-Integer8-256 | after | 0.016866 | 0.000203 |
| interval-width-Integer16-64 | before | 0.013626 | 0.000252 |
| interval-width-Integer16-64 | after | 0.013896 | 0.000915 |
| interval-width-Integer16-256 | before | 0.016562 | 0.000526 |
| interval-width-Integer16-256 | after | 0.017113 | 0.000818 |
| interval-width-Integer32-64 | before | 0.013593 | 0.000563 |
| interval-width-Integer32-64 | after | 0.013825 | 0.000714 |
| interval-width-Integer32-256 | before | 0.016402 | 0.000670 |
| interval-width-Integer32-256 | after | 0.016682 | 0.000211 |
| interval-width-Integer64-64 | before | 0.013668 | 0.000524 |
| interval-width-Integer64-64 | after | 0.014046 | 0.000220 |
| interval-width-Integer64-256 | before | 0.016444 | 0.000351 |
| interval-width-Integer64-256 | after | 0.016959 | 0.000606 |
| interval-width-UnsignedInteger16-64 | before | 0.013444 | 0.000334 |
| interval-width-UnsignedInteger16-64 | after | 0.014063 | 0.000160 |
| interval-width-UnsignedInteger16-256 | before | 0.016243 | 0.000431 |
| interval-width-UnsignedInteger16-256 | after | 0.016802 | 0.000940 |
| interval-width-UnsignedInteger32-64 | before | 0.013437 | 0.000323 |
| interval-width-UnsignedInteger32-64 | after | 0.013617 | 0.002058 |
| interval-width-UnsignedInteger32-256 | before | 0.016164 | 0.000502 |
| interval-width-UnsignedInteger32-256 | after | 0.016742 | 0.000246 |
| interval-width-UnsignedInteger64-64 | before | 0.013651 | 0.000874 |
| interval-width-UnsignedInteger64-64 | after | 0.013744 | 0.000183 |
| interval-width-UnsignedInteger64-256 | before | 0.016550 | 0.000891 |
| interval-width-UnsignedInteger64-256 | after | 0.017038 | 0.000615 |
| property-seven-24-20-1000-all-ok | before | 0.036414 | 0.000291 |
| property-seven-24-20-1000-all-ok | after | 0.037504 | 0.000179 |
| property-seven-24-20-1000-always-error | before | 0.035168 | 0.000913 |
| property-seven-24-20-1000-always-error | after | 0.035837 | 0.000263 |
| property-distinct-24-20-1000-all-ok | before | 0.035818 | 0.000338 |
| property-distinct-24-20-1000-all-ok | after | 0.036603 | 0.000685 |
| property-distinct-24-20-1000-always-error | before | 0.034979 | 0.000258 |
| property-distinct-24-20-1000-always-error | after | 0.036411 | 0.000818 |
| property-zero-24-20-1000-all-ok | before | 0.036122 | 0.000165 |
| property-zero-24-20-1000-all-ok | after | 0.037046 | 0.000443 |
| property-zero-24-20-1000-always-error | before | 0.034864 | 0.001301 |
| property-zero-24-20-1000-always-error | after | 0.035673 | 0.000670 |
| property-max-24-20-1000-all-ok | before | 0.036348 | 0.000407 |
| property-max-24-20-1000-all-ok | after | 0.037328 | 0.000986 |
| property-max-24-20-1000-always-error | before | 0.035613 | 0.000989 |
| property-max-24-20-1000-always-error | after | 0.036048 | 0.000416 |
| order-string-candidates | before | 0.035452 | 0.000778 |
| order-string-candidates | after | 0.037227 | 0.000881 |
| order-string-all-ok | before | 0.035565 | 0.000326 |
| order-string-all-ok | after | 0.036547 | 0.000991 |
| order-string-always-error | before | 0.034647 | 0.000995 |
| order-string-always-error | after | 0.035620 | 0.000545 |
| order-map-candidates | before | 0.035094 | 0.001803 |
| order-map-candidates | after | 0.035999 | 0.000399 |
| order-map-all-ok | before | 0.035425 | 0.000476 |
| order-map-all-ok | after | 0.036206 | 0.000560 |
| order-map-always-error | before | 0.035198 | 0.000344 |
| order-map-always-error | after | 0.036362 | 0.001120 |
| order-record-candidates | before | 0.035630 | 0.000900 |
| order-record-candidates | after | 0.036493 | 0.000743 |
| order-record-all-ok | before | 0.035730 | 0.000312 |
| order-record-all-ok | after | 0.036632 | 0.000574 |
| order-record-always-error | before | 0.035795 | 0.000298 |
| order-record-always-error | after | 0.036795 | 0.000439 |
| build-string-builder-8-0 | before | 0.016495 | 0.000621 |
| build-string-builder-8-0 | after | 0.016116 | 0.001041 |
| build-string-builder-all-8-0 | before | 0.015802 | 0.000134 |
| build-string-builder-all-8-0 | after | 0.016417 | 0.000958 |
| build-string-concatenate-8-0 | before | 0.015562 | 0.000317 |
| build-string-concatenate-8-0 | after | 0.015883 | 0.000934 |
| build-string-join-8-0 | before | 0.015626 | 0.001541 |
| build-string-join-8-0 | after | 0.015680 | 0.000086 |
| build-list-builder-8-0 | before | 0.015595 | 0.000364 |
| build-list-builder-8-0 | after | 0.016939 | 0.000626 |
| build-list-builder-all-8-0 | before | 0.015701 | 0.000256 |
| build-list-builder-all-8-0 | after | 0.016069 | 0.000260 |
| build-list-concatenate-8-0 | before | 0.015937 | 0.000466 |
| build-list-concatenate-8-0 | after | 0.016309 | 0.000286 |
| build-list-fold-8-0 | before | 0.015741 | 0.000705 |
| build-list-fold-8-0 | after | 0.016136 | 0.000626 |
| build-bytes-builder-8-0 | before | 0.015650 | 0.000905 |
| build-bytes-builder-8-0 | after | 0.015834 | 0.000120 |
| build-bytes-builder-all-8-0 | before | 0.015743 | 0.000484 |
| build-bytes-builder-all-8-0 | after | 0.016009 | 0.000089 |
| build-bytes-concatenate-8-0 | before | 0.016085 | 0.000312 |
| build-bytes-concatenate-8-0 | after | 0.016783 | 0.000535 |
| patterns-integer-100 | before | 0.014097 | 0.000683 |
| patterns-integer-100 | after | 0.014287 | 0.000060 |
| codegen-let-100 | before | 0.016667 | 0.000208 |
| codegen-let-100 | after | 0.016895 | 0.000421 |
| bridge-shared-8 | before | 0.004601 | 0.000198 |
| bridge-shared-8 | after | 0.004572 | 0.000468 |
| external-tests-normal-1 | before | 0.017982 | 0.000347 |
| external-tests-normal-1 | after | 0.017993 | 0.000349 |
| runtime-fib-short | before | 0.017622 | 0.000560 |
| runtime-fib-short | after | 0.018018 | 0.000202 |
| runtime-loop-short | before | 0.023334 | 0.000357 |
| runtime-loop-short | after | 0.023564 | 0.000809 |
| runtime-list-short | before | 0.029286 | 0.001519 |
| runtime-list-short | after | 0.029521 | 0.000471 |
| runtime-tree-short | before | 0.018635 | 0.000796 |
| runtime-tree-short | after | 0.018665 | 0.000803 |
| runtime-eval-short | before | 0.021822 | 0.000373 |
| runtime-eval-short | after | 0.022278 | 0.000434 |
| runtime-string-short | before | 0.016351 | 0.000163 |
| runtime-string-short | after | 0.016874 | 0.001457 |
| runtime-println-short | before | 0.017038 | 0.000955 |
| runtime-println-short | after | 0.016950 | 0.000202 |
| runtime-lines-short | before | 0.016543 | 0.000159 |
| runtime-lines-short | after | 0.016944 | 0.000601 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.8417e-05 | 1.334e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.417e-06 | 5e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1667e-05 | 1.751e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5083e-05 | 1.792e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.709e-06 | 8.32e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.9125e-05 | 1.999e-06 |
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
    "after": "57ac9b1d7a1dc396c0beca4f3be87daa0043a14f"
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
| functions-main-1000-0 | 判定不能 | None | 0.002 |
| functions-main-1000-1 | 判定不能 | None | 0.0020067542000001383 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0026263958000001253 |
| functions-args-1000-1 | 判定不能 | None | 0.002663766600000095 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002051399999999859 |
| functions-modules-1000-1 | 達成 | 0.0007950000000001012 | 0.002014333300000004 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 達成 | 0.0008259160000001486 | 0.0027733250000000712 |
| higher-1-300 | 判定不能 | None | 0.003050945899999924 |
| classes-300 | 判定不能 | None | 0.003623862500000108 |
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
| interval-range-64 | 判定不能 | None | 0.002242266700000073 |
| interval-range-256 | 達成 | 0.0014235000000013542 | 0.0035213750000000488 |
| interval-http-0 | 達成 | 0.001981667000002574 | 0.002 |
| interval-http-64 | 判定不能 | None | 0.002191641699999991 |
| interval-http-256 | 達成 | 0.0025426250000002426 | 0.002910345800000158 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 達成 | 0.0006191250000000537 | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | 0.001090458999996713 | 0.003641358300000164 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003516795899999892 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003581799999999902 |
| property-distinct-24-20-1000-always-error | 達成 | 0.001432083000000972 | 0.003497916699999948 |
| property-zero-24-20-1000-all-ok | 達成 | 0.0009244590000001551 | 0.003612174999999951 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0034863542000000084 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003634849999999901 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003561270800000216 |
| order-string-candidates | 達成 | 0.0017750830000018425 | 0.0035452207999998823 |
| order-string-all-ok | 判定不能 | None | 0.0035565167000001455 |
| order-string-always-error | 判定不能 | None | 0.003464712499999934 |
| order-map-candidates | 判定不能 | None | 0.0035093666999998167 |
| order-map-all-ok | 判定不能 | None | 0.0035425082999999804 |
| order-map-always-error | 判定不能 | None | 0.0035198250000000545 |
| order-record-candidates | 判定不能 | None | 0.003563033400000393 |
| order-record-all-ok | 達成 | 0.0009022080000065102 | 0.0035730166999996984 |
| order-record-always-error | 達成 | 0.0010004580000000374 | 0.0035794500000001506 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 達成 | 0.0013438339999893856 | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.002333433400000473 |
| runtime-list-short | 判定不能 | None | 0.0029286208000002035 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002182249999999897 |
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
    "verify": 1.20278175,
    "cli": 5.057814209000002,
    "warmup": 0.5687184579999958,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.80776775,
    "cli": 11.513541958999994,
    "warmup": 1.3401614520000091,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2331973330000006,
    "cli": 8.852806167000011,
    "warmup": 1.232907708999985,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.35761770800000026,
    "cli": 3.493714208,
    "warmup": 0.3501796259999921,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09587712500000034,
    "cli": 0.27300854199999947,
    "warmup": 0.029043458000010958,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03399087500000064,
    "cli": 0.3289911670000052,
    "warmup": 0.03353462600000512,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.008856791999999558,
    "cli": 0.19812187499999823,
    "warmup": 0.009076790999998252,
    "probe_warmup": 0.00781895899999796,
    "rss": 0,
    "stages": 0.04404270700000268,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.0349636250000005,
    "cli": 0.337345207999995,
    "warmup": 0.03492687399999994,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.1783600410000048
  },
  "runtime": {
    "verify": 0.32653370800000037,
    "cli": 2.891460083999995,
    "warmup": 0.3245370420000171,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
