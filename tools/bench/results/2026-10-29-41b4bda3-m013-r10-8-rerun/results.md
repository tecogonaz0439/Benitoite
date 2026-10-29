# 版どうしの性能比較

候補: `41b4bda37b3cf2a8c3f6a3ef7232955e41d90431`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013152 | 0.000653 |
| functions-main-0-0 | after | 0.013346 | 0.002198 |
| functions-main-0-1 | before | 0.013452 | 0.000467 |
| functions-main-0-1 | after | 0.013234 | 0.000622 |
| functions-main-64-0 | before | 0.013617 | 0.001029 |
| functions-main-64-0 | after | 0.013625 | 0.001111 |
| functions-main-256-0 | before | 0.015153 | 0.000794 |
| functions-main-256-0 | after | 0.015060 | 0.000603 |
| functions-main-1000-0 | before | 0.020679 | 0.000493 |
| functions-main-1000-0 | after | 0.020639 | 0.001443 |
| functions-main-1000-1 | before | 0.020302 | 0.000431 |
| functions-main-1000-1 | after | 0.020964 | 0.000993 |
| functions-args-0-0 | before | 0.012952 | 0.000768 |
| functions-args-0-0 | after | 0.013471 | 0.000453 |
| functions-args-0-1 | before | 0.013099 | 0.001130 |
| functions-args-0-1 | after | 0.012972 | 0.000121 |
| functions-args-1000-0 | before | 0.026375 | 0.000495 |
| functions-args-1000-0 | after | 0.027718 | 0.001491 |
| functions-args-1000-1 | before | 0.026937 | 0.000977 |
| functions-args-1000-1 | after | 0.028733 | 0.001679 |
| functions-modules-0-0 | before | 0.013250 | 0.000399 |
| functions-modules-0-0 | after | 0.013058 | 0.000172 |
| functions-modules-0-1 | before | 0.013300 | 0.000882 |
| functions-modules-0-1 | after | 0.013464 | 0.000620 |
| functions-modules-1000-0 | before | 0.020559 | 0.000262 |
| functions-modules-1000-0 | after | 0.020928 | 0.002584 |
| functions-modules-1000-1 | before | 0.020850 | 0.000803 |
| functions-modules-1000-1 | after | 0.021454 | 0.000898 |
| existing-fib | before | 0.013367 | 0.000929 |
| existing-fib | after | 0.013970 | 0.000586 |
| existing-loop | before | 0.014176 | 0.001283 |
| existing-loop | after | 0.013833 | 0.000566 |
| existing-string | before | 0.014024 | 0.001006 |
| existing-string | after | 0.013718 | 0.000132 |
| higher-0-0 | before | 0.013599 | 0.000211 |
| higher-0-0 | after | 0.013974 | 0.000524 |
| higher-1-0 | before | 0.014639 | 0.001291 |
| higher-1-0 | after | 0.014374 | 0.000423 |
| classes-0 | before | 0.017784 | 0.000590 |
| classes-0 | after | 0.018204 | 0.000724 |
| higher-0-300 | before | 0.028272 | 0.000637 |
| higher-0-300 | after | 0.029602 | 0.001803 |
| higher-1-300 | before | 0.031137 | 0.000556 |
| higher-1-300 | after | 0.033012 | 0.000981 |
| classes-300 | before | 0.037420 | 0.001924 |
| classes-300 | after | 0.038674 | 0.000552 |
| depth-0-8 | before | 0.015672 | 0.001339 |
| depth-0-8 | after | 0.016141 | 0.000736 |
| depth-1-8 | before | 0.015183 | 0.001123 |
| depth-1-8 | after | 0.015829 | 0.000287 |
| f1-nofail-call | before | 0.014435 | 0.001689 |
| f1-nofail-call | after | 0.014722 | 0.000232 |
| f1-join-effects | before | 0.014181 | 0.002325 |
| f1-join-effects | after | 0.014558 | 0.000633 |
| control-16.3 | before | 0.013206 | 0.000694 |
| control-16.3 | after | 0.013211 | 0.000164 |
| interval-bind-64 | before | 0.013787 | 0.000721 |
| interval-bind-64 | after | 0.013621 | 0.000370 |
| interval-bind-256 | before | 0.014704 | 0.000959 |
| interval-bind-256 | after | 0.014416 | 0.000412 |
| interval-add-64 | before | 0.013430 | 0.001702 |
| interval-add-64 | after | 0.013521 | 0.000329 |
| interval-add-256 | before | 0.015612 | 0.001374 |
| interval-add-256 | after | 0.015357 | 0.000305 |
| interval-flow-64 | before | 0.014208 | 0.001246 |
| interval-flow-64 | after | 0.014349 | 0.000532 |
| interval-flow-256 | before | 0.017093 | 0.000477 |
| interval-flow-256 | after | 0.017470 | 0.000790 |
| interval-range-0 | before | 0.018907 | 0.000507 |
| interval-range-0 | after | 0.018901 | 0.000714 |
| interval-range-64 | before | 0.023051 | 0.000775 |
| interval-range-64 | after | 0.024093 | 0.001215 |
| interval-range-256 | before | 0.036252 | 0.000534 |
| interval-range-256 | after | 0.037246 | 0.000563 |
| interval-http-0 | before | 0.018571 | 0.000713 |
| interval-http-0 | after | 0.019409 | 0.000766 |
| interval-http-64 | before | 0.023012 | 0.001042 |
| interval-http-64 | after | 0.022972 | 0.001753 |
| interval-http-256 | before | 0.029727 | 0.000633 |
| interval-http-256 | after | 0.031133 | 0.000710 |
| interval-width-Integer8-64 | before | 0.014564 | 0.000963 |
| interval-width-Integer8-64 | after | 0.014710 | 0.000320 |
| interval-width-Integer8-256 | before | 0.016929 | 0.000604 |
| interval-width-Integer8-256 | after | 0.017486 | 0.000482 |
| interval-width-Integer16-64 | before | 0.013706 | 0.001267 |
| interval-width-Integer16-64 | after | 0.014296 | 0.000321 |
| interval-width-Integer16-256 | before | 0.016463 | 0.000667 |
| interval-width-Integer16-256 | after | 0.016851 | 0.000505 |
| interval-width-Integer32-64 | before | 0.014026 | 0.002148 |
| interval-width-Integer32-64 | after | 0.014188 | 0.000381 |
| interval-width-Integer32-256 | before | 0.017296 | 0.000491 |
| interval-width-Integer32-256 | after | 0.016735 | 0.000312 |
| interval-width-Integer64-64 | before | 0.014121 | 0.001327 |
| interval-width-Integer64-64 | after | 0.014002 | 0.000924 |
| interval-width-Integer64-256 | before | 0.018575 | 0.000455 |
| interval-width-Integer64-256 | after | 0.018910 | 0.001110 |
| interval-width-UnsignedInteger16-64 | before | 0.014003 | 0.000802 |
| interval-width-UnsignedInteger16-64 | after | 0.014591 | 0.000461 |
| interval-width-UnsignedInteger16-256 | before | 0.017302 | 0.000586 |
| interval-width-UnsignedInteger16-256 | after | 0.017883 | 0.001225 |
| interval-width-UnsignedInteger32-64 | before | 0.014750 | 0.000782 |
| interval-width-UnsignedInteger32-64 | after | 0.014225 | 0.000237 |
| interval-width-UnsignedInteger32-256 | before | 0.018557 | 0.001329 |
| interval-width-UnsignedInteger32-256 | after | 0.017038 | 0.001434 |
| interval-width-UnsignedInteger64-64 | before | 0.015891 | 0.000741 |
| interval-width-UnsignedInteger64-64 | after | 0.016988 | 0.002513 |
| interval-width-UnsignedInteger64-256 | before | 0.017661 | 0.000764 |
| interval-width-UnsignedInteger64-256 | after | 0.017783 | 0.000830 |
| property-seven-24-20-1000-all-ok | before | 0.038445 | 0.002224 |
| property-seven-24-20-1000-all-ok | after | 0.038145 | 0.002491 |
| property-seven-24-20-1000-always-error | before | 0.035415 | 0.001918 |
| property-seven-24-20-1000-always-error | after | 0.036748 | 0.000692 |
| property-distinct-24-20-1000-all-ok | before | 0.036290 | 0.001151 |
| property-distinct-24-20-1000-all-ok | after | 0.038038 | 0.000545 |
| property-distinct-24-20-1000-always-error | before | 0.035293 | 0.001315 |
| property-distinct-24-20-1000-always-error | after | 0.036720 | 0.000947 |
| property-zero-24-20-1000-all-ok | before | 0.037104 | 0.001607 |
| property-zero-24-20-1000-all-ok | after | 0.038492 | 0.000895 |
| property-zero-24-20-1000-always-error | before | 0.035959 | 0.001087 |
| property-zero-24-20-1000-always-error | after | 0.036481 | 0.000221 |
| property-max-24-20-1000-all-ok | before | 0.037143 | 0.002047 |
| property-max-24-20-1000-all-ok | after | 0.038355 | 0.001112 |
| property-max-24-20-1000-always-error | before | 0.035862 | 0.001008 |
| property-max-24-20-1000-always-error | after | 0.036731 | 0.001203 |
| order-string-candidates | before | 0.035382 | 0.001886 |
| order-string-candidates | after | 0.036357 | 0.000437 |
| order-string-all-ok | before | 0.037885 | 0.002306 |
| order-string-all-ok | after | 0.038118 | 0.001426 |
| order-string-always-error | before | 0.035812 | 0.001853 |
| order-string-always-error | after | 0.036626 | 0.000376 |
| order-map-candidates | before | 0.036060 | 0.001637 |
| order-map-candidates | after | 0.037027 | 0.001102 |
| order-map-all-ok | before | 0.036202 | 0.001467 |
| order-map-all-ok | after | 0.037869 | 0.000087 |
| order-map-always-error | before | 0.036992 | 0.003059 |
| order-map-always-error | after | 0.037566 | 0.001905 |
| order-record-candidates | before | 0.037098 | 0.001407 |
| order-record-candidates | after | 0.037555 | 0.000296 |
| order-record-all-ok | before | 0.039905 | 0.001488 |
| order-record-all-ok | after | 0.040560 | 0.002638 |
| order-record-always-error | before | 0.037130 | 0.004630 |
| order-record-always-error | after | 0.039438 | 0.001453 |
| build-string-builder-8-0 | before | 0.015999 | 0.000640 |
| build-string-builder-8-0 | after | 0.016331 | 0.000560 |
| build-string-builder-all-8-0 | before | 0.016722 | 0.000267 |
| build-string-builder-all-8-0 | after | 0.016945 | 0.000388 |
| build-string-concatenate-8-0 | before | 0.016719 | 0.000326 |
| build-string-concatenate-8-0 | after | 0.015852 | 0.000249 |
| build-string-join-8-0 | before | 0.018091 | 0.001338 |
| build-string-join-8-0 | after | 0.018158 | 0.001027 |
| build-list-builder-8-0 | before | 0.017404 | 0.000685 |
| build-list-builder-8-0 | after | 0.017798 | 0.001553 |
| build-list-builder-all-8-0 | before | 0.016705 | 0.000682 |
| build-list-builder-all-8-0 | after | 0.016806 | 0.000708 |
| build-list-concatenate-8-0 | before | 0.016601 | 0.000261 |
| build-list-concatenate-8-0 | after | 0.017385 | 0.000326 |
| build-list-fold-8-0 | before | 0.017034 | 0.000840 |
| build-list-fold-8-0 | after | 0.017330 | 0.000952 |
| build-bytes-builder-8-0 | before | 0.018762 | 0.000808 |
| build-bytes-builder-8-0 | after | 0.019241 | 0.002485 |
| build-bytes-builder-all-8-0 | before | 0.016552 | 0.000858 |
| build-bytes-builder-all-8-0 | after | 0.016594 | 0.002097 |
| build-bytes-concatenate-8-0 | before | 0.016409 | 0.000563 |
| build-bytes-concatenate-8-0 | after | 0.016754 | 0.000539 |
| patterns-integer-100 | before | 0.014877 | 0.001453 |
| patterns-integer-100 | after | 0.014479 | 0.000464 |
| codegen-let-100 | before | 0.016903 | 0.000654 |
| codegen-let-100 | after | 0.017632 | 0.001079 |
| bridge-shared-8 | before | 0.004758 | 0.000198 |
| bridge-shared-8 | after | 0.004682 | 0.000144 |
| external-tests-normal-1 | before | 0.018262 | 0.000376 |
| external-tests-normal-1 | after | 0.018545 | 0.001662 |
| runtime-fib-short | before | 0.018486 | 0.000535 |
| runtime-fib-short | after | 0.018670 | 0.001492 |
| runtime-loop-short | before | 0.024561 | 0.000837 |
| runtime-loop-short | after | 0.025450 | 0.001142 |
| runtime-list-short | before | 0.029742 | 0.000420 |
| runtime-list-short | after | 0.030472 | 0.000652 |
| runtime-tree-short | before | 0.019045 | 0.000423 |
| runtime-tree-short | after | 0.019048 | 0.000835 |
| runtime-eval-short | before | 0.022725 | 0.000758 |
| runtime-eval-short | after | 0.023368 | 0.001131 |
| runtime-string-short | before | 0.017080 | 0.000263 |
| runtime-string-short | after | 0.017491 | 0.001344 |
| runtime-println-short | before | 0.017095 | 0.000598 |
| runtime-println-short | after | 0.017663 | 0.000223 |
| runtime-lines-short | before | 0.017227 | 0.000696 |
| runtime-lines-short | after | 0.016931 | 0.000415 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.9417e-05 | 2.709e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.375e-06 | 4.59e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.2917e-05 | 3.043e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.6375e-05 | 1.042e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.333e-06 | 3.74e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.9459e-05 | 1.708e-06 |
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
    "after": "41b4bda37b3cf2a8c3f6a3ef7232955e41d90431"
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
| functions-main-1000-0 | 判定不能 | None | 0.0020678667000000317 |
| functions-main-1000-1 | 判定不能 | None | 0.0020301916999999393 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.00263751249999995 |
| functions-args-1000-1 | 判定不能 | None | 0.002693658299999946 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0020558582999999687 |
| functions-modules-1000-1 | 判定不能 | None | 0.002085008299999913 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028272249999998778 |
| higher-1-300 | 達成 | 0.0018744580000031874 | 0.003113733399999852 |
| classes-300 | 判定不能 | None | 0.003741954200000031 |
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
| interval-range-64 | 判定不能 | None | 0.002305137500000143 |
| interval-range-256 | 判定不能 | None | 0.0036252417000000037 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 判定不能 | None | 0.0023012041000001204 |
| interval-http-256 | 達成 | 0.0014060419999992746 | 0.002972725000000054 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.00384445410000005 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003541500000000042 |
| property-distinct-24-20-1000-all-ok | 達成 | 0.0017486250000011694 | 0.0036289666999998363 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0035293165999998877 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003710416700000252 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003595895899999846 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0037142709000001165 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0035861874999998378 |
| order-string-candidates | 判定不能 | None | 0.003538220800000147 |
| order-string-all-ok | 判定不能 | None | 0.0037885165999998805 |
| order-string-always-error | 判定不能 | None | 0.003581158299999743 |
| order-map-candidates | 判定不能 | None | 0.0036060167000002254 |
| order-map-all-ok | 達成 | 0.001667124999997327 | 0.003620170900000375 |
| order-map-always-error | 判定不能 | None | 0.0036991999999997915 |
| order-record-candidates | 判定不能 | None | 0.0037098374999999352 |
| order-record-all-ok | 判定不能 | None | 0.003990470900000531 |
| order-record-always-error | 判定不能 | None | 0.0037129750000005402 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 達成 | -0.0008662910000083457 | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 達成 | 0.0007834580000078972 | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0024560708000002764 |
| runtime-list-short | 判定不能 | None | 0.0029742458000001195 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022724750000001847 |
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
    "verify": 1.2172858340000001,
    "cli": 5.199183876000003,
    "warmup": 0.5783770020000008,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.847313917,
    "cli": 12.007110080000007,
    "warmup": 1.3786947559999945,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2610248749999995,
    "cli": 9.17988874999999,
    "warmup": 1.2610349990000032,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3616502079999995,
    "cli": 3.7514102500000135,
    "warmup": 0.37957433200001134,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09734670799999989,
    "cli": 0.28425491600000186,
    "warmup": 0.030460250000004407,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.037433083999999894,
    "cli": 0.3392922920000032,
    "warmup": 0.034092375999996705,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009860291000000743,
    "cli": 0.20823712499999658,
    "warmup": 0.009518082999996125,
    "probe_warmup": 0.00813183400001094,
    "rss": 0,
    "stages": 0.042706334000016,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.035592457999999993,
    "cli": 0.3490928339999968,
    "warmup": 0.03517858300000398,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18346129100000752
  },
  "runtime": {
    "verify": 0.3336315409999999,
    "cli": 2.987197917000003,
    "warmup": 0.33345433400000246,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
