# 版どうしの性能比較

候補: `e458b868694d0c699ef5e4e032bbc7dc26c03bcc`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.012883 | 0.000060 |
| functions-main-0-0 | after | 0.013394 | 0.000257 |
| functions-main-0-1 | before | 0.013114 | 0.000291 |
| functions-main-0-1 | after | 0.013184 | 0.000478 |
| functions-main-64-0 | before | 0.013434 | 0.001068 |
| functions-main-64-0 | after | 0.013638 | 0.000128 |
| functions-main-256-0 | before | 0.014779 | 0.000487 |
| functions-main-256-0 | after | 0.015790 | 0.000439 |
| functions-main-1000-0 | before | 0.020306 | 0.000293 |
| functions-main-1000-0 | after | 0.020981 | 0.000345 |
| functions-main-1000-1 | before | 0.020110 | 0.000894 |
| functions-main-1000-1 | after | 0.021096 | 0.000575 |
| functions-args-0-0 | before | 0.012712 | 0.000143 |
| functions-args-0-0 | after | 0.013325 | 0.000639 |
| functions-args-0-1 | before | 0.012917 | 0.000323 |
| functions-args-0-1 | after | 0.013425 | 0.000591 |
| functions-args-1000-0 | before | 0.026395 | 0.000221 |
| functions-args-1000-0 | after | 0.028020 | 0.001666 |
| functions-args-1000-1 | before | 0.026296 | 0.000228 |
| functions-args-1000-1 | after | 0.027624 | 0.000297 |
| functions-modules-0-0 | before | 0.013324 | 0.001150 |
| functions-modules-0-0 | after | 0.013257 | 0.000153 |
| functions-modules-0-1 | before | 0.013089 | 0.000253 |
| functions-modules-0-1 | after | 0.013351 | 0.000394 |
| functions-modules-1000-0 | before | 0.020521 | 0.000490 |
| functions-modules-1000-0 | after | 0.021517 | 0.000245 |
| functions-modules-1000-1 | before | 0.020725 | 0.000525 |
| functions-modules-1000-1 | after | 0.021418 | 0.000325 |
| existing-fib | before | 0.013479 | 0.000218 |
| existing-fib | after | 0.013781 | 0.000689 |
| existing-loop | before | 0.013365 | 0.000208 |
| existing-loop | after | 0.013655 | 0.001318 |
| existing-string | before | 0.013578 | 0.000393 |
| existing-string | after | 0.013925 | 0.000725 |
| higher-0-0 | before | 0.013098 | 0.000926 |
| higher-0-0 | after | 0.013177 | 0.000200 |
| higher-1-0 | before | 0.013904 | 0.000370 |
| higher-1-0 | after | 0.014849 | 0.000483 |
| classes-0 | before | 0.017821 | 0.000509 |
| classes-0 | after | 0.017962 | 0.000275 |
| higher-0-300 | before | 0.028052 | 0.000775 |
| higher-0-300 | after | 0.029049 | 0.000393 |
| higher-1-300 | before | 0.030612 | 0.000603 |
| higher-1-300 | after | 0.031596 | 0.000684 |
| classes-300 | before | 0.036829 | 0.000548 |
| classes-300 | after | 0.038542 | 0.000473 |
| depth-0-8 | before | 0.014471 | 0.000692 |
| depth-0-8 | after | 0.014715 | 0.000225 |
| depth-1-8 | before | 0.014508 | 0.000472 |
| depth-1-8 | after | 0.015237 | 0.000236 |
| f1-nofail-call | before | 0.014041 | 0.000492 |
| f1-nofail-call | after | 0.014396 | 0.000297 |
| f1-join-effects | before | 0.013935 | 0.000330 |
| f1-join-effects | after | 0.014048 | 0.000208 |
| control-16.3 | before | 0.013051 | 0.000722 |
| control-16.3 | after | 0.013089 | 0.000460 |
| interval-bind-64 | before | 0.013172 | 0.000362 |
| interval-bind-64 | after | 0.013486 | 0.000252 |
| interval-bind-256 | before | 0.013465 | 0.000649 |
| interval-bind-256 | after | 0.013809 | 0.000103 |
| interval-add-64 | before | 0.013233 | 0.000250 |
| interval-add-64 | after | 0.013301 | 0.000176 |
| interval-add-256 | before | 0.014840 | 0.000334 |
| interval-add-256 | after | 0.014981 | 0.000903 |
| interval-flow-64 | before | 0.013976 | 0.001057 |
| interval-flow-64 | after | 0.014382 | 0.000241 |
| interval-flow-256 | before | 0.017279 | 0.001312 |
| interval-flow-256 | after | 0.017874 | 0.000538 |
| interval-range-0 | before | 0.018484 | 0.000395 |
| interval-range-0 | after | 0.019262 | 0.000268 |
| interval-range-64 | before | 0.022764 | 0.000172 |
| interval-range-64 | after | 0.023614 | 0.000785 |
| interval-range-256 | before | 0.035715 | 0.000418 |
| interval-range-256 | after | 0.036899 | 0.000490 |
| interval-http-0 | before | 0.018802 | 0.000164 |
| interval-http-0 | after | 0.020950 | 0.000759 |
| interval-http-64 | before | 0.022015 | 0.000188 |
| interval-http-64 | after | 0.024360 | 0.001455 |
| interval-http-256 | before | 0.029486 | 0.001036 |
| interval-http-256 | after | 0.032728 | 0.000354 |
| interval-width-Integer8-64 | before | 0.013961 | 0.000133 |
| interval-width-Integer8-64 | after | 0.014377 | 0.000963 |
| interval-width-Integer8-256 | before | 0.016735 | 0.000313 |
| interval-width-Integer8-256 | after | 0.017259 | 0.000688 |
| interval-width-Integer16-64 | before | 0.014090 | 0.000591 |
| interval-width-Integer16-64 | after | 0.014132 | 0.000097 |
| interval-width-Integer16-256 | before | 0.016705 | 0.000805 |
| interval-width-Integer16-256 | after | 0.017084 | 0.000086 |
| interval-width-Integer32-64 | before | 0.013674 | 0.000282 |
| interval-width-Integer32-64 | after | 0.015058 | 0.000829 |
| interval-width-Integer32-256 | before | 0.016661 | 0.000983 |
| interval-width-Integer32-256 | after | 0.017746 | 0.000623 |
| interval-width-Integer64-64 | before | 0.013697 | 0.000517 |
| interval-width-Integer64-64 | after | 0.014083 | 0.000267 |
| interval-width-Integer64-256 | before | 0.016677 | 0.000682 |
| interval-width-Integer64-256 | after | 0.017997 | 0.000725 |
| interval-width-UnsignedInteger16-64 | before | 0.013749 | 0.000644 |
| interval-width-UnsignedInteger16-64 | after | 0.014272 | 0.000180 |
| interval-width-UnsignedInteger16-256 | before | 0.016531 | 0.000223 |
| interval-width-UnsignedInteger16-256 | after | 0.016921 | 0.000321 |
| interval-width-UnsignedInteger32-64 | before | 0.013989 | 0.000648 |
| interval-width-UnsignedInteger32-64 | after | 0.013818 | 0.000244 |
| interval-width-UnsignedInteger32-256 | before | 0.016673 | 0.000705 |
| interval-width-UnsignedInteger32-256 | after | 0.016855 | 0.000303 |
| interval-width-UnsignedInteger64-64 | before | 0.013740 | 0.000096 |
| interval-width-UnsignedInteger64-64 | after | 0.014134 | 0.000629 |
| interval-width-UnsignedInteger64-256 | before | 0.016495 | 0.000298 |
| interval-width-UnsignedInteger64-256 | after | 0.016916 | 0.000234 |
| property-seven-24-20-1000-all-ok | before | 0.036779 | 0.000368 |
| property-seven-24-20-1000-all-ok | after | 0.038270 | 0.001329 |
| property-seven-24-20-1000-always-error | before | 0.035353 | 0.000549 |
| property-seven-24-20-1000-always-error | after | 0.036959 | 0.001134 |
| property-distinct-24-20-1000-all-ok | before | 0.035839 | 0.001824 |
| property-distinct-24-20-1000-all-ok | after | 0.037334 | 0.000350 |
| property-distinct-24-20-1000-always-error | before | 0.035190 | 0.000812 |
| property-distinct-24-20-1000-always-error | after | 0.036546 | 0.001897 |
| property-zero-24-20-1000-all-ok | before | 0.036921 | 0.000632 |
| property-zero-24-20-1000-all-ok | after | 0.037713 | 0.001620 |
| property-zero-24-20-1000-always-error | before | 0.035309 | 0.000726 |
| property-zero-24-20-1000-always-error | after | 0.036454 | 0.000336 |
| property-max-24-20-1000-all-ok | before | 0.036729 | 0.000261 |
| property-max-24-20-1000-all-ok | after | 0.038263 | 0.001734 |
| property-max-24-20-1000-always-error | before | 0.035476 | 0.000566 |
| property-max-24-20-1000-always-error | after | 0.037256 | 0.001490 |
| order-string-candidates | before | 0.034810 | 0.000197 |
| order-string-candidates | after | 0.036135 | 0.000350 |
| order-string-all-ok | before | 0.035720 | 0.000363 |
| order-string-all-ok | after | 0.037265 | 0.000911 |
| order-string-always-error | before | 0.035132 | 0.001117 |
| order-string-always-error | after | 0.036179 | 0.000258 |
| order-map-candidates | before | 0.035441 | 0.000534 |
| order-map-candidates | after | 0.036400 | 0.000572 |
| order-map-all-ok | before | 0.035903 | 0.000597 |
| order-map-all-ok | after | 0.037023 | 0.000790 |
| order-map-always-error | before | 0.035721 | 0.000837 |
| order-map-always-error | after | 0.037838 | 0.001103 |
| order-record-candidates | before | 0.035690 | 0.000500 |
| order-record-candidates | after | 0.037366 | 0.000789 |
| order-record-all-ok | before | 0.036310 | 0.000684 |
| order-record-all-ok | after | 0.037316 | 0.000208 |
| order-record-always-error | before | 0.035910 | 0.000425 |
| order-record-always-error | after | 0.037089 | 0.001534 |
| build-string-builder-8-0 | before | 0.015879 | 0.000681 |
| build-string-builder-8-0 | after | 0.016077 | 0.000132 |
| build-string-builder-all-8-0 | before | 0.016033 | 0.000307 |
| build-string-builder-all-8-0 | after | 0.016123 | 0.000755 |
| build-string-concatenate-8-0 | before | 0.015693 | 0.000239 |
| build-string-concatenate-8-0 | after | 0.016058 | 0.000217 |
| build-string-join-8-0 | before | 0.015720 | 0.000273 |
| build-string-join-8-0 | after | 0.016059 | 0.000339 |
| build-list-builder-8-0 | before | 0.016024 | 0.000205 |
| build-list-builder-8-0 | after | 0.016316 | 0.001172 |
| build-list-builder-all-8-0 | before | 0.015757 | 0.000171 |
| build-list-builder-all-8-0 | after | 0.015878 | 0.000758 |
| build-list-concatenate-8-0 | before | 0.015922 | 0.000212 |
| build-list-concatenate-8-0 | after | 0.016312 | 0.000779 |
| build-list-fold-8-0 | before | 0.015719 | 0.000518 |
| build-list-fold-8-0 | after | 0.016456 | 0.000874 |
| build-bytes-builder-8-0 | before | 0.015797 | 0.001129 |
| build-bytes-builder-8-0 | after | 0.016890 | 0.000798 |
| build-bytes-builder-all-8-0 | before | 0.016025 | 0.000507 |
| build-bytes-builder-all-8-0 | after | 0.016330 | 0.000248 |
| build-bytes-concatenate-8-0 | before | 0.016049 | 0.000287 |
| build-bytes-concatenate-8-0 | after | 0.016632 | 0.001610 |
| patterns-integer-100 | before | 0.014377 | 0.001104 |
| patterns-integer-100 | after | 0.014445 | 0.000190 |
| codegen-let-100 | before | 0.016802 | 0.000370 |
| codegen-let-100 | after | 0.017274 | 0.001152 |
| bridge-shared-8 | before | 0.004585 | 0.000664 |
| bridge-shared-8 | after | 0.004613 | 0.000366 |
| external-tests-normal-1 | before | 0.018650 | 0.000913 |
| external-tests-normal-1 | after | 0.018675 | 0.000615 |
| runtime-fib-short | before | 0.017871 | 0.000262 |
| runtime-fib-short | after | 0.018104 | 0.000335 |
| runtime-loop-short | before | 0.023470 | 0.000414 |
| runtime-loop-short | after | 0.023478 | 0.000173 |
| runtime-list-short | before | 0.029027 | 0.000443 |
| runtime-list-short | after | 0.029707 | 0.000300 |
| runtime-tree-short | before | 0.018291 | 0.000257 |
| runtime-tree-short | after | 0.018778 | 0.001138 |
| runtime-eval-short | before | 0.021956 | 0.000500 |
| runtime-eval-short | after | 0.022658 | 0.000213 |
| runtime-string-short | before | 0.016620 | 0.000246 |
| runtime-string-short | after | 0.017369 | 0.000767 |
| runtime-println-short | before | 0.016938 | 0.000380 |
| runtime-println-short | after | 0.017186 | 0.000185 |
| runtime-lines-short | before | 0.017291 | 0.002011 |
| runtime-lines-short | after | 0.016877 | 0.001407 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.725e-05 | 1.291e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.083e-06 | 2.09e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.0333e-05 | 1.625e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4292e-05 | 3.76e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.375e-06 | 4.17e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7708e-05 | 4.1e-08 |
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
    "after": "e458b868694d0c699ef5e4e032bbc7dc26c03bcc"
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
| functions-main-0-0 | 達成 | 0.0005106250000039836 | 0.002 |
| functions-main-0-1 | 判定不能 | None | 0.002 |
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 達成 | 0.0010111670000014783 | 0.002 |
| functions-main-1000-0 | 達成 | 0.000674540999995088 | 0.0020306000000005044 |
| functions-main-1000-1 | 判定不能 | None | 0.0020109957999991934 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0026395291000000046 |
| functions-args-1000-1 | 達成 | 0.00132762499998762 | 0.0026296000000002096 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | 0.000995416000009186 | 0.0020521416999997656 |
| functions-modules-1000-1 | 判定不能 | None | 0.0020725374999997826 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 達成 | 0.0009449169999982132 | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002805216599999483 |
| higher-1-300 | 判定不能 | None | 0.00306117500000056 |
| classes-300 | 達成 | 0.0017130420000057711 | 0.003682941699999276 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 達成 | 0.0007292500000062319 | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 達成 | 0.0007785419999919441 | 0.002 |
| interval-range-64 | 判定不能 | None | 0.0022764166999991176 |
| interval-range-256 | 達成 | 0.0011836670000064942 | 0.003571520799999917 |
| interval-http-0 | 退行の疑い | 0.002147999999991157 | 0.002 |
| interval-http-64 | 退行の疑い | 0.002344708000009632 | 0.0022015416999991546 |
| interval-http-256 | 退行の疑い | 0.003242083000003504 | 0.0029486292000001414 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 達成 | 0.0013841669999976602 | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003677875000001052 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003535337499999969 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003583933299999842 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0035190208000003055 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0036921333000009327 |
| property-zero-24-20-1000-always-error | 達成 | 0.0011449580000117976 | 0.0035309124999997723 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0036728625000009177 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0035476082999991833 |
| order-string-candidates | 達成 | 0.0013251250000081427 | 0.003480987499999344 |
| order-string-all-ok | 達成 | 0.0015453329999957077 | 0.0035720000000011966 |
| order-string-always-error | 判定不能 | None | 0.0035131708000008645 |
| order-map-candidates | 判定不能 | None | 0.00354405829999962 |
| order-map-all-ok | 判定不能 | None | 0.003590262499999142 |
| order-map-always-error | 達成 | 0.0021163330000035785 | 0.003572149999999397 |
| order-record-candidates | 達成 | 0.0016760430000033466 | 0.0035690290999994545 |
| order-record-all-ok | 達成 | 0.0010058750000041528 | 0.003631041699999571 |
| order-record-always-error | 判定不能 | None | 0.0035909708999994905 |
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
| runtime-loop-short | 判定不能 | None | 0.0023469833000007156 |
| runtime-list-short | 判定不能 | None | 0.0029027124999998935 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002195612500000266 |
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
    "verify": 1.6858004999999991,
    "cli": 5.16547216699999,
    "warmup": 0.5848688790000267,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.8786711249999968,
    "cli": 11.709610500999958,
    "warmup": 1.3673053369999764,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2579687909999961,
    "cli": 8.97303308399998,
    "warmup": 1.2559024579999942,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.362765667000005,
    "cli": 3.5295087920000014,
    "warmup": 0.35684520899997096,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09836741699999152,
    "cli": 0.27782612499999004,
    "warmup": 0.030671624999982328,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.034127124999997704,
    "cli": 0.33153262499999414,
    "warmup": 0.03405974999998307,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009451499999997282,
    "cli": 0.20272795900000062,
    "warmup": 0.008653542000004677,
    "probe_warmup": 0.008086833999996657,
    "rss": 0,
    "stages": 0.03906229500002212,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.042947166999994124,
    "cli": 0.348483250000001,
    "warmup": 0.03538900099999864,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.1801480419999848
  },
  "runtime": {
    "verify": 0.3336076249999991,
    "cli": 2.916676875999997,
    "warmup": 0.328390959000032,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
