# 版どうしの性能比較

候補: `a04cf45702395ea497db59b3294370cb7a6f1a38`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013409 | 0.000742 |
| functions-main-0-0 | after | 0.013510 | 0.000254 |
| functions-main-0-1 | before | 0.013578 | 0.000486 |
| functions-main-0-1 | after | 0.014342 | 0.000218 |
| functions-main-64-0 | before | 0.013799 | 0.000517 |
| functions-main-64-0 | after | 0.014363 | 0.000383 |
| functions-main-256-0 | before | 0.015095 | 0.000168 |
| functions-main-256-0 | after | 0.015467 | 0.000136 |
| functions-main-1000-0 | before | 0.020629 | 0.000888 |
| functions-main-1000-0 | after | 0.021083 | 0.000537 |
| functions-main-1000-1 | before | 0.020628 | 0.000377 |
| functions-main-1000-1 | after | 0.021352 | 0.000638 |
| functions-args-0-0 | before | 0.013306 | 0.000287 |
| functions-args-0-0 | after | 0.013667 | 0.000229 |
| functions-args-0-1 | before | 0.012963 | 0.000150 |
| functions-args-0-1 | after | 0.013551 | 0.000336 |
| functions-args-1000-0 | before | 0.026716 | 0.000794 |
| functions-args-1000-0 | after | 0.028050 | 0.000747 |
| functions-args-1000-1 | before | 0.026927 | 0.000288 |
| functions-args-1000-1 | after | 0.027973 | 0.000540 |
| functions-modules-0-0 | before | 0.013659 | 0.000625 |
| functions-modules-0-0 | after | 0.013953 | 0.000698 |
| functions-modules-0-1 | before | 0.013474 | 0.000722 |
| functions-modules-0-1 | after | 0.013837 | 0.000274 |
| functions-modules-1000-0 | before | 0.021336 | 0.000396 |
| functions-modules-1000-0 | after | 0.022200 | 0.000876 |
| functions-modules-1000-1 | before | 0.020463 | 0.001174 |
| functions-modules-1000-1 | after | 0.021793 | 0.000540 |
| existing-fib | before | 0.014343 | 0.000588 |
| existing-fib | after | 0.014518 | 0.000156 |
| existing-loop | before | 0.014117 | 0.000361 |
| existing-loop | after | 0.014245 | 0.000527 |
| existing-string | before | 0.014574 | 0.001151 |
| existing-string | after | 0.014936 | 0.000678 |
| higher-0-0 | before | 0.014061 | 0.000514 |
| higher-0-0 | after | 0.014668 | 0.000430 |
| higher-1-0 | before | 0.014792 | 0.000260 |
| higher-1-0 | after | 0.014996 | 0.000934 |
| classes-0 | before | 0.018741 | 0.001107 |
| classes-0 | after | 0.019270 | 0.000564 |
| higher-0-300 | before | 0.028519 | 0.000378 |
| higher-0-300 | after | 0.029468 | 0.001260 |
| higher-1-300 | before | 0.031516 | 0.000637 |
| higher-1-300 | after | 0.031950 | 0.001567 |
| classes-300 | before | 0.037920 | 0.000453 |
| classes-300 | after | 0.039328 | 0.000441 |
| depth-0-8 | before | 0.014739 | 0.000473 |
| depth-0-8 | after | 0.015378 | 0.000616 |
| depth-1-8 | before | 0.015051 | 0.000404 |
| depth-1-8 | after | 0.015919 | 0.001868 |
| f1-nofail-call | before | 0.014758 | 0.000581 |
| f1-nofail-call | after | 0.014938 | 0.000567 |
| f1-join-effects | before | 0.014000 | 0.000385 |
| f1-join-effects | after | 0.014461 | 0.000390 |
| control-16.3 | before | 0.013355 | 0.001053 |
| control-16.3 | after | 0.013573 | 0.000698 |
| interval-bind-64 | before | 0.013479 | 0.000756 |
| interval-bind-64 | after | 0.013682 | 0.000683 |
| interval-bind-256 | before | 0.013986 | 0.000433 |
| interval-bind-256 | after | 0.014265 | 0.004542 |
| interval-add-64 | before | 0.014411 | 0.000671 |
| interval-add-64 | after | 0.014447 | 0.000361 |
| interval-add-256 | before | 0.015674 | 0.000363 |
| interval-add-256 | after | 0.015789 | 0.000581 |
| interval-flow-64 | before | 0.014802 | 0.000128 |
| interval-flow-64 | after | 0.014812 | 0.000221 |
| interval-flow-256 | before | 0.017534 | 0.000457 |
| interval-flow-256 | after | 0.017765 | 0.000434 |
| interval-range-0 | before | 0.019195 | 0.000188 |
| interval-range-0 | after | 0.019815 | 0.000438 |
| interval-range-64 | before | 0.023482 | 0.000858 |
| interval-range-64 | after | 0.024299 | 0.000359 |
| interval-range-256 | before | 0.036545 | 0.000955 |
| interval-range-256 | after | 0.037535 | 0.000666 |
| interval-http-0 | before | 0.019311 | 0.000467 |
| interval-http-0 | after | 0.021569 | 0.000580 |
| interval-http-64 | before | 0.022739 | 0.001040 |
| interval-http-64 | after | 0.025029 | 0.000497 |
| interval-http-256 | before | 0.030375 | 0.000715 |
| interval-http-256 | after | 0.032504 | 0.000983 |
| interval-width-Integer8-64 | before | 0.014496 | 0.000283 |
| interval-width-Integer8-64 | after | 0.014760 | 0.000354 |
| interval-width-Integer8-256 | before | 0.017195 | 0.000303 |
| interval-width-Integer8-256 | after | 0.017776 | 0.000269 |
| interval-width-Integer16-64 | before | 0.014262 | 0.000416 |
| interval-width-Integer16-64 | after | 0.014760 | 0.000713 |
| interval-width-Integer16-256 | before | 0.018483 | 0.001190 |
| interval-width-Integer16-256 | after | 0.018608 | 0.001448 |
| interval-width-Integer32-64 | before | 0.014335 | 0.000269 |
| interval-width-Integer32-64 | after | 0.014769 | 0.000427 |
| interval-width-Integer32-256 | before | 0.017163 | 0.000158 |
| interval-width-Integer32-256 | after | 0.018060 | 0.000156 |
| interval-width-Integer64-64 | before | 0.014242 | 0.000268 |
| interval-width-Integer64-64 | after | 0.014526 | 0.000178 |
| interval-width-Integer64-256 | before | 0.017141 | 0.000660 |
| interval-width-Integer64-256 | after | 0.017491 | 0.000294 |
| interval-width-UnsignedInteger16-64 | before | 0.013929 | 0.000257 |
| interval-width-UnsignedInteger16-64 | after | 0.014444 | 0.000239 |
| interval-width-UnsignedInteger16-256 | before | 0.016620 | 0.000579 |
| interval-width-UnsignedInteger16-256 | after | 0.017373 | 0.000246 |
| interval-width-UnsignedInteger32-64 | before | 0.014151 | 0.000429 |
| interval-width-UnsignedInteger32-64 | after | 0.014484 | 0.000081 |
| interval-width-UnsignedInteger32-256 | before | 0.016807 | 0.000128 |
| interval-width-UnsignedInteger32-256 | after | 0.017637 | 0.000631 |
| interval-width-UnsignedInteger64-64 | before | 0.014076 | 0.000398 |
| interval-width-UnsignedInteger64-64 | after | 0.014605 | 0.001144 |
| interval-width-UnsignedInteger64-256 | before | 0.017008 | 0.000412 |
| interval-width-UnsignedInteger64-256 | after | 0.017416 | 0.000332 |
| property-seven-24-20-1000-all-ok | before | 0.037753 | 0.000624 |
| property-seven-24-20-1000-all-ok | after | 0.039257 | 0.000178 |
| property-seven-24-20-1000-always-error | before | 0.036083 | 0.000767 |
| property-seven-24-20-1000-always-error | after | 0.037133 | 0.000285 |
| property-distinct-24-20-1000-all-ok | before | 0.037046 | 0.000871 |
| property-distinct-24-20-1000-all-ok | after | 0.039185 | 0.001413 |
| property-distinct-24-20-1000-always-error | before | 0.035340 | 0.000494 |
| property-distinct-24-20-1000-always-error | after | 0.037418 | 0.000698 |
| property-zero-24-20-1000-all-ok | before | 0.036158 | 0.000617 |
| property-zero-24-20-1000-all-ok | after | 0.038080 | 0.001333 |
| property-zero-24-20-1000-always-error | before | 0.035320 | 0.000353 |
| property-zero-24-20-1000-always-error | after | 0.036749 | 0.000886 |
| property-max-24-20-1000-all-ok | before | 0.036965 | 0.000144 |
| property-max-24-20-1000-all-ok | after | 0.038727 | 0.000709 |
| property-max-24-20-1000-always-error | before | 0.035325 | 0.001427 |
| property-max-24-20-1000-always-error | after | 0.036805 | 0.000134 |
| order-string-candidates | before | 0.035086 | 0.000500 |
| order-string-candidates | after | 0.036562 | 0.001306 |
| order-string-all-ok | before | 0.035738 | 0.000229 |
| order-string-all-ok | after | 0.037784 | 0.000695 |
| order-string-always-error | before | 0.035598 | 0.000632 |
| order-string-always-error | after | 0.036915 | 0.000348 |
| order-map-candidates | before | 0.035806 | 0.000982 |
| order-map-candidates | after | 0.037787 | 0.001404 |
| order-map-all-ok | before | 0.035692 | 0.000336 |
| order-map-all-ok | after | 0.037487 | 0.001769 |
| order-map-always-error | before | 0.035389 | 0.000249 |
| order-map-always-error | after | 0.036955 | 0.001191 |
| order-record-candidates | before | 0.036143 | 0.000460 |
| order-record-candidates | after | 0.037778 | 0.001112 |
| order-record-all-ok | before | 0.036102 | 0.000342 |
| order-record-all-ok | after | 0.037835 | 0.001262 |
| order-record-always-error | before | 0.035974 | 0.000278 |
| order-record-always-error | after | 0.037843 | 0.001200 |
| build-string-builder-8-0 | before | 0.016023 | 0.000427 |
| build-string-builder-8-0 | after | 0.016506 | 0.001015 |
| build-string-builder-all-8-0 | before | 0.015661 | 0.000446 |
| build-string-builder-all-8-0 | after | 0.016333 | 0.000423 |
| build-string-concatenate-8-0 | before | 0.015702 | 0.000352 |
| build-string-concatenate-8-0 | after | 0.016286 | 0.001029 |
| build-string-join-8-0 | before | 0.015564 | 0.000641 |
| build-string-join-8-0 | after | 0.015997 | 0.000341 |
| build-list-builder-8-0 | before | 0.015991 | 0.000714 |
| build-list-builder-8-0 | after | 0.016664 | 0.000587 |
| build-list-builder-all-8-0 | before | 0.016083 | 0.000318 |
| build-list-builder-all-8-0 | after | 0.016677 | 0.000405 |
| build-list-concatenate-8-0 | before | 0.015875 | 0.000196 |
| build-list-concatenate-8-0 | after | 0.016874 | 0.000810 |
| build-list-fold-8-0 | before | 0.015900 | 0.000237 |
| build-list-fold-8-0 | after | 0.016341 | 0.000220 |
| build-bytes-builder-8-0 | before | 0.015935 | 0.000215 |
| build-bytes-builder-8-0 | after | 0.016482 | 0.000277 |
| build-bytes-builder-all-8-0 | before | 0.016263 | 0.000248 |
| build-bytes-builder-all-8-0 | after | 0.016742 | 0.001138 |
| build-bytes-concatenate-8-0 | before | 0.016313 | 0.001334 |
| build-bytes-concatenate-8-0 | after | 0.016597 | 0.000272 |
| patterns-integer-100 | before | 0.014325 | 0.000480 |
| patterns-integer-100 | after | 0.015147 | 0.000808 |
| codegen-let-100 | before | 0.017136 | 0.000413 |
| codegen-let-100 | after | 0.017754 | 0.000822 |
| bridge-shared-8 | before | 0.004707 | 0.000545 |
| bridge-shared-8 | after | 0.004359 | 0.000537 |
| external-tests-normal-1 | before | 0.018130 | 0.000569 |
| external-tests-normal-1 | after | 0.018432 | 0.000214 |
| runtime-fib-short | before | 0.017900 | 0.000325 |
| runtime-fib-short | after | 0.018810 | 0.000624 |
| runtime-loop-short | before | 0.023565 | 0.000524 |
| runtime-loop-short | after | 0.024118 | 0.000358 |
| runtime-list-short | before | 0.029453 | 0.000746 |
| runtime-list-short | after | 0.029757 | 0.000237 |
| runtime-tree-short | before | 0.018635 | 0.000802 |
| runtime-tree-short | after | 0.019678 | 0.000691 |
| runtime-eval-short | before | 0.022065 | 0.000936 |
| runtime-eval-short | after | 0.022383 | 0.000312 |
| runtime-string-short | before | 0.017092 | 0.000680 |
| runtime-string-short | after | 0.017352 | 0.000853 |
| runtime-println-short | before | 0.017270 | 0.001239 |
| runtime-println-short | after | 0.017711 | 0.000473 |
| runtime-lines-short | before | 0.016877 | 0.000686 |
| runtime-lines-short | after | 0.017148 | 0.000599 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.7125e-05 | 2.125e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 2.917e-06 | 4.17e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.975e-05 | 2.376e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.3958e-05 | 4.58e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.833e-06 | 1.24e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.675e-05 | 6.26e-07 |
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
    "after": "a04cf45702395ea497db59b3294370cb7a6f1a38"
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
| functions-main-0-1 | 達成 | 0.0007637919999865517 | 0.002 |
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 達成 | 0.00037187500001323315 | 0.002 |
| functions-main-1000-0 | 判定不能 | None | 0.002062912499999925 |
| functions-main-1000-1 | 判定不能 | None | 0.0020628291999997828 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 達成 | 0.0005879989999897361 | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.002671649999999204 |
| functions-args-1000-1 | 達成 | 0.0010464999999868496 | 0.00269265410000088 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0021336208000008127 |
| functions-modules-1000-1 | 判定不能 | None | 0.0020463208999998983 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002851925000000222 |
| higher-1-300 | 判定不能 | None | 0.0031516457999998695 |
| classes-300 | 達成 | 0.001408083000015381 | 0.0037920082999988837 |
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
| interval-range-64 | 判定不能 | None | 0.0023482207999990126 |
| interval-range-256 | 判定不能 | None | 0.0036544500000005088 |
| interval-http-0 | 退行の疑い | 0.0022585840000175494 | 0.002 |
| interval-http-64 | 退行の疑い | 0.00228966699999944 | 0.002273895799999082 |
| interval-http-256 | 達成 | 0.0021286249999974416 | 0.00303748750000068 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 達成 | 0.0005812090000034686 | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 達成 | 0.0008972090000014532 | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 達成 | 0.0005149170000038339 | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 達成 | 0.00083062500000608 | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | 0.0015038339999904338 | 0.0037753332999997725 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.00360834170000004 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003704579200000069 |
| property-distinct-24-20-1000-always-error | 達成 | 0.0020786249999957818 | 0.0035339624999991773 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0036157582999990726 |
| property-zero-24-20-1000-always-error | 達成 | 0.0014294580000040469 | 0.003531970899999237 |
| property-max-24-20-1000-all-ok | 達成 | 0.001762208999991799 | 0.0036964582999999608 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003532462500000122 |
| order-string-candidates | 判定不能 | None | 0.0035086208999999258 |
| order-string-all-ok | 達成 | 0.002045999999992887 | 0.0035738375000008205 |
| order-string-always-error | 達成 | 0.0013163749999876018 | 0.003559841700000277 |
| order-map-candidates | 判定不能 | None | 0.0035806417000003423 |
| order-map-all-ok | 判定不能 | None | 0.0035692333000000077 |
| order-map-always-error | 達成 | 0.001566249000006792 | 0.003538908400000196 |
| order-record-candidates | 達成 | 0.0016349999999931697 | 0.003614283400000318 |
| order-record-all-ok | 達成 | 0.0017332910000078527 | 0.0036101999999999636 |
| order-record-always-error | 達成 | 0.0018692909999913354 | 0.0035973834000003536 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 達成 | 0.0005469999999974107 | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0023565290999997047 |
| runtime-list-short | 判定不能 | None | 0.0029452875000004044 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002206512499999747 |
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
    "verify": 1.6977189589999995,
    "cli": 5.326492582999975,
    "warmup": 0.5968942539999915,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.9194476249999894,
    "cli": 12.09080224799996,
    "warmup": 1.3989549579999334,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2804252080000111,
    "cli": 9.057549043999998,
    "warmup": 1.25678695900001,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.36967491699999755,
    "cli": 3.5570407899999736,
    "warmup": 0.36137171000004287,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10078587499999969,
    "cli": 0.28372625000000085,
    "warmup": 0.029249748999987446,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03586316700000225,
    "cli": 0.33846825000000536,
    "warmup": 0.03407641699999431,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.00959525000000383,
    "cli": 0.2042829579999932,
    "warmup": 0.009199082999998609,
    "probe_warmup": 0.00826737500000263,
    "rss": 0,
    "stages": 0.03976516500000571,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04157958300000075,
    "cli": 0.34632725000000164,
    "warmup": 0.03570120799999188,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.184440751000011
  },
  "runtime": {
    "verify": 0.33788504199999636,
    "cli": 2.950096832,
    "warmup": 0.330978043000016,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
