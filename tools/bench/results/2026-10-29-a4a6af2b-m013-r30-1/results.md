# 版どうしの性能比較

候補: `a4a6af2b1e4899b1a72fe0328e760792833dd66e`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013596 | 0.000420 |
| functions-main-0-0 | after | 0.014058 | 0.000739 |
| functions-main-0-1 | before | 0.013941 | 0.001094 |
| functions-main-0-1 | after | 0.014037 | 0.000336 |
| functions-main-64-0 | before | 0.014128 | 0.001610 |
| functions-main-64-0 | after | 0.014387 | 0.000371 |
| functions-main-256-0 | before | 0.015505 | 0.000937 |
| functions-main-256-0 | after | 0.016211 | 0.000269 |
| functions-main-1000-0 | before | 0.021018 | 0.000431 |
| functions-main-1000-0 | after | 0.022434 | 0.002651 |
| functions-main-1000-1 | before | 0.021188 | 0.000538 |
| functions-main-1000-1 | after | 0.022022 | 0.001618 |
| functions-args-0-0 | before | 0.013972 | 0.000891 |
| functions-args-0-0 | after | 0.013970 | 0.000331 |
| functions-args-0-1 | before | 0.013439 | 0.001437 |
| functions-args-0-1 | after | 0.013863 | 0.000211 |
| functions-args-1000-0 | before | 0.027623 | 0.000662 |
| functions-args-1000-0 | after | 0.029380 | 0.001337 |
| functions-args-1000-1 | before | 0.026882 | 0.000671 |
| functions-args-1000-1 | after | 0.029516 | 0.001002 |
| functions-modules-0-0 | before | 0.013664 | 0.001430 |
| functions-modules-0-0 | after | 0.013945 | 0.000226 |
| functions-modules-0-1 | before | 0.013383 | 0.001761 |
| functions-modules-0-1 | after | 0.013871 | 0.000690 |
| functions-modules-1000-0 | before | 0.021329 | 0.000509 |
| functions-modules-1000-0 | after | 0.022021 | 0.001633 |
| functions-modules-1000-1 | before | 0.021124 | 0.000346 |
| functions-modules-1000-1 | after | 0.022242 | 0.001486 |
| existing-fib | before | 0.014136 | 0.001281 |
| existing-fib | after | 0.014181 | 0.000124 |
| existing-loop | before | 0.013860 | 0.001067 |
| existing-loop | after | 0.014141 | 0.000335 |
| existing-string | before | 0.013934 | 0.001993 |
| existing-string | after | 0.014294 | 0.000170 |
| higher-0-0 | before | 0.013726 | 0.001326 |
| higher-0-0 | after | 0.013815 | 0.000470 |
| higher-1-0 | before | 0.014434 | 0.001542 |
| higher-1-0 | after | 0.014817 | 0.000587 |
| classes-0 | before | 0.017989 | 0.000494 |
| classes-0 | after | 0.018363 | 0.000704 |
| higher-0-300 | before | 0.028423 | 0.000781 |
| higher-0-300 | after | 0.029667 | 0.001390 |
| higher-1-300 | before | 0.030910 | 0.001153 |
| higher-1-300 | after | 0.032221 | 0.000923 |
| classes-300 | before | 0.037004 | 0.002223 |
| classes-300 | after | 0.038647 | 0.000552 |
| depth-0-8 | before | 0.015075 | 0.001421 |
| depth-0-8 | after | 0.015409 | 0.000281 |
| depth-1-8 | before | 0.014980 | 0.000562 |
| depth-1-8 | after | 0.015694 | 0.000285 |
| f1-nofail-call | before | 0.014342 | 0.001488 |
| f1-nofail-call | after | 0.014613 | 0.000182 |
| f1-join-effects | before | 0.014467 | 0.000917 |
| f1-join-effects | after | 0.014864 | 0.000151 |
| control-16.3 | before | 0.013593 | 0.000951 |
| control-16.3 | after | 0.013713 | 0.000205 |
| interval-bind-64 | before | 0.013420 | 0.002023 |
| interval-bind-64 | after | 0.013900 | 0.000229 |
| interval-bind-256 | before | 0.013703 | 0.000983 |
| interval-bind-256 | after | 0.014351 | 0.001791 |
| interval-add-64 | before | 0.013353 | 0.001264 |
| interval-add-64 | after | 0.013556 | 0.000186 |
| interval-add-256 | before | 0.014925 | 0.001258 |
| interval-add-256 | after | 0.015419 | 0.000109 |
| interval-flow-64 | before | 0.014202 | 0.000908 |
| interval-flow-64 | after | 0.014776 | 0.000247 |
| interval-flow-256 | before | 0.016872 | 0.000606 |
| interval-flow-256 | after | 0.017432 | 0.001435 |
| interval-range-0 | before | 0.018636 | 0.000959 |
| interval-range-0 | after | 0.019331 | 0.001591 |
| interval-range-64 | before | 0.023308 | 0.000721 |
| interval-range-64 | after | 0.024624 | 0.001403 |
| interval-range-256 | before | 0.035432 | 0.000362 |
| interval-range-256 | after | 0.037479 | 0.000731 |
| interval-http-0 | before | 0.019289 | 0.000667 |
| interval-http-0 | after | 0.021835 | 0.001997 |
| interval-http-64 | before | 0.022041 | 0.000339 |
| interval-http-64 | after | 0.024798 | 0.000823 |
| interval-http-256 | before | 0.029809 | 0.000785 |
| interval-http-256 | after | 0.032815 | 0.000989 |
| interval-width-Integer8-64 | before | 0.014014 | 0.001999 |
| interval-width-Integer8-64 | after | 0.014471 | 0.000127 |
| interval-width-Integer8-256 | before | 0.016865 | 0.000819 |
| interval-width-Integer8-256 | after | 0.017086 | 0.000181 |
| interval-width-Integer16-64 | before | 0.013814 | 0.000877 |
| interval-width-Integer16-64 | after | 0.014660 | 0.000378 |
| interval-width-Integer16-256 | before | 0.016783 | 0.000716 |
| interval-width-Integer16-256 | after | 0.017440 | 0.000314 |
| interval-width-Integer32-64 | before | 0.014141 | 0.002136 |
| interval-width-Integer32-64 | after | 0.014440 | 0.000171 |
| interval-width-Integer32-256 | before | 0.017215 | 0.000671 |
| interval-width-Integer32-256 | after | 0.017501 | 0.000163 |
| interval-width-Integer64-64 | before | 0.014071 | 0.001097 |
| interval-width-Integer64-64 | after | 0.014123 | 0.000151 |
| interval-width-Integer64-256 | before | 0.016878 | 0.000733 |
| interval-width-Integer64-256 | after | 0.017438 | 0.000287 |
| interval-width-UnsignedInteger16-64 | before | 0.013860 | 0.001082 |
| interval-width-UnsignedInteger16-64 | after | 0.014546 | 0.000319 |
| interval-width-UnsignedInteger16-256 | before | 0.017139 | 0.000701 |
| interval-width-UnsignedInteger16-256 | after | 0.017784 | 0.000701 |
| interval-width-UnsignedInteger32-64 | before | 0.014061 | 0.000901 |
| interval-width-UnsignedInteger32-64 | after | 0.014374 | 0.000197 |
| interval-width-UnsignedInteger32-256 | before | 0.016738 | 0.000914 |
| interval-width-UnsignedInteger32-256 | after | 0.017173 | 0.000182 |
| interval-width-UnsignedInteger64-64 | before | 0.013985 | 0.000989 |
| interval-width-UnsignedInteger64-64 | after | 0.014248 | 0.000065 |
| interval-width-UnsignedInteger64-256 | before | 0.016587 | 0.000409 |
| interval-width-UnsignedInteger64-256 | after | 0.017299 | 0.000123 |
| property-seven-24-20-1000-all-ok | before | 0.037105 | 0.001236 |
| property-seven-24-20-1000-all-ok | after | 0.038825 | 0.000339 |
| property-seven-24-20-1000-always-error | before | 0.035395 | 0.000943 |
| property-seven-24-20-1000-always-error | after | 0.037178 | 0.000761 |
| property-distinct-24-20-1000-all-ok | before | 0.036263 | 0.001994 |
| property-distinct-24-20-1000-all-ok | after | 0.037810 | 0.000249 |
| property-distinct-24-20-1000-always-error | before | 0.035483 | 0.001274 |
| property-distinct-24-20-1000-always-error | after | 0.037193 | 0.000459 |
| property-zero-24-20-1000-all-ok | before | 0.036534 | 0.001960 |
| property-zero-24-20-1000-all-ok | after | 0.038334 | 0.000334 |
| property-zero-24-20-1000-always-error | before | 0.036406 | 0.001716 |
| property-zero-24-20-1000-always-error | after | 0.037670 | 0.000575 |
| property-max-24-20-1000-all-ok | before | 0.037943 | 0.001572 |
| property-max-24-20-1000-all-ok | after | 0.038542 | 0.000479 |
| property-max-24-20-1000-always-error | before | 0.036524 | 0.001798 |
| property-max-24-20-1000-always-error | after | 0.037533 | 0.000721 |
| order-string-candidates | before | 0.035245 | 0.001866 |
| order-string-candidates | after | 0.036749 | 0.000398 |
| order-string-all-ok | before | 0.035773 | 0.001986 |
| order-string-all-ok | after | 0.037451 | 0.000462 |
| order-string-always-error | before | 0.035241 | 0.001805 |
| order-string-always-error | after | 0.036880 | 0.000446 |
| order-map-candidates | before | 0.035373 | 0.001220 |
| order-map-candidates | after | 0.037295 | 0.000370 |
| order-map-all-ok | before | 0.035907 | 0.000510 |
| order-map-all-ok | after | 0.037328 | 0.000566 |
| order-map-always-error | before | 0.035385 | 0.002485 |
| order-map-always-error | after | 0.036998 | 0.000277 |
| order-record-candidates | before | 0.037166 | 0.002777 |
| order-record-candidates | after | 0.038143 | 0.000958 |
| order-record-all-ok | before | 0.036481 | 0.000939 |
| order-record-all-ok | after | 0.037976 | 0.000307 |
| order-record-always-error | before | 0.036043 | 0.001612 |
| order-record-always-error | after | 0.037985 | 0.000406 |
| build-string-builder-8-0 | before | 0.016160 | 0.000551 |
| build-string-builder-8-0 | after | 0.016584 | 0.000337 |
| build-string-builder-all-8-0 | before | 0.015910 | 0.000521 |
| build-string-builder-all-8-0 | after | 0.016406 | 0.001582 |
| build-string-concatenate-8-0 | before | 0.015868 | 0.000675 |
| build-string-concatenate-8-0 | after | 0.016361 | 0.000119 |
| build-string-join-8-0 | before | 0.015897 | 0.000671 |
| build-string-join-8-0 | after | 0.016625 | 0.000400 |
| build-list-builder-8-0 | before | 0.016146 | 0.000649 |
| build-list-builder-8-0 | after | 0.016954 | 0.000287 |
| build-list-builder-all-8-0 | before | 0.016229 | 0.000611 |
| build-list-builder-all-8-0 | after | 0.016225 | 0.000203 |
| build-list-concatenate-8-0 | before | 0.016204 | 0.000681 |
| build-list-concatenate-8-0 | after | 0.016517 | 0.000218 |
| build-list-fold-8-0 | before | 0.016081 | 0.000670 |
| build-list-fold-8-0 | after | 0.016618 | 0.000145 |
| build-bytes-builder-8-0 | before | 0.016137 | 0.000685 |
| build-bytes-builder-8-0 | after | 0.016620 | 0.000108 |
| build-bytes-builder-all-8-0 | before | 0.016583 | 0.000591 |
| build-bytes-builder-all-8-0 | after | 0.017500 | 0.000737 |
| build-bytes-concatenate-8-0 | before | 0.016704 | 0.000784 |
| build-bytes-concatenate-8-0 | after | 0.016919 | 0.000793 |
| patterns-integer-100 | before | 0.014779 | 0.000871 |
| patterns-integer-100 | after | 0.014986 | 0.000394 |
| codegen-let-100 | before | 0.017508 | 0.000636 |
| codegen-let-100 | after | 0.017834 | 0.000818 |
| bridge-shared-8 | before | 0.004885 | 0.000330 |
| bridge-shared-8 | after | 0.004805 | 0.000445 |
| external-tests-normal-1 | before | 0.018116 | 0.000299 |
| external-tests-normal-1 | after | 0.019109 | 0.001381 |
| runtime-fib-short | before | 0.018219 | 0.000560 |
| runtime-fib-short | after | 0.018580 | 0.001269 |
| runtime-loop-short | before | 0.024119 | 0.000296 |
| runtime-loop-short | after | 0.024009 | 0.001766 |
| runtime-list-short | before | 0.029558 | 0.000350 |
| runtime-list-short | after | 0.030305 | 0.000702 |
| runtime-tree-short | before | 0.018600 | 0.000343 |
| runtime-tree-short | after | 0.019214 | 0.001243 |
| runtime-eval-short | before | 0.022060 | 0.000311 |
| runtime-eval-short | after | 0.022514 | 0.000745 |
| runtime-string-short | before | 0.016947 | 0.000464 |
| runtime-string-short | after | 0.017766 | 0.000293 |
| runtime-println-short | before | 0.017379 | 0.000496 |
| runtime-println-short | after | 0.017841 | 0.002353 |
| runtime-lines-short | before | 0.016833 | 0.000389 |
| runtime-lines-short | after | 0.017518 | 0.001171 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.7792e-05 | 1.5e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.333e-06 | 3.75e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1292e-05 | 1.708e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.6125e-05 | 1.418e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.208e-06 | 1.66e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.9333e-05 | 1.001e-06 |
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
    "after": "a4a6af2b1e4899b1a72fe0328e760792833dd66e"
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
| functions-main-1000-0 | 判定不能 | None | 0.0021018042000008562 |
| functions-main-1000-1 | 判定不能 | None | 0.0021188209000001733 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0027623292000001245 |
| functions-args-1000-1 | 達成 | 0.0026330419999993637 | 0.0026882499999999255 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002132916600000101 |
| functions-modules-1000-1 | 判定不能 | None | 0.0021123666999997683 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028422584000011852 |
| higher-1-300 | 判定不能 | None | 0.003091000000000577 |
| classes-300 | 判定不能 | None | 0.003700379199999304 |
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
| interval-range-64 | 判定不能 | None | 0.0023308249999999474 |
| interval-range-256 | 達成 | 0.002046208000010097 | 0.003543229199999587 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 退行の疑い | 0.0027575000000013006 | 0.0022040791999998533 |
| interval-http-256 | 退行の疑い | 0.0030060420000097565 | 0.002980895799998962 |
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
| interval-width-UnsignedInteger64-256 | 達成 | 0.0007125829999949929 | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | 0.001719375000007517 | 0.003710533299999952 |
| property-seven-24-20-1000-always-error | 達成 | 0.001782958000006829 | 0.0035394999999994073 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0036263250000004633 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003548250000000053 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003653416699999923 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0036405583000004072 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0037942958999991564 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.0036524291000006315 |
| order-string-candidates | 判定不能 | None | 0.0035244583999997307 |
| order-string-all-ok | 判定不能 | None | 0.003577295800000968 |
| order-string-always-error | 判定不能 | None | 0.0035241208000002192 |
| order-map-candidates | 達成 | 0.001922333999999637 | 0.0035372999999992772 |
| order-map-all-ok | 達成 | 0.0014206670000049826 | 0.0035906916000001845 |
| order-map-always-error | 判定不能 | None | 0.0035384582999995473 |
| order-record-candidates | 判定不能 | None | 0.0037165540999993143 |
| order-record-all-ok | 達成 | 0.0014951250000052596 | 0.0036480874999995196 |
| order-record-always-error | 判定不能 | None | 0.003604270799999654 |
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
| runtime-loop-short | 判定不能 | None | 0.002411920800000189 |
| runtime-list-short | 判定不能 | None | 0.002955754100000263 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002205991700000709 |
| runtime-string-short | 達成 | 0.0008182910000016363 | 0.002 |
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
    "verify": 1.7660893749999929,
    "cli": 5.424098001999994,
    "warmup": 0.6021538730000202,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.9583819160000075,
    "cli": 11.985994248000026,
    "warmup": 1.3768776299999388,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3026619580000016,
    "cli": 9.105027958000008,
    "warmup": 1.261882707999959,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3857710829999945,
    "cli": 3.61722187700002,
    "warmup": 0.36275537400000246,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.1028758329999988,
    "cli": 0.28941145800000356,
    "warmup": 0.03046604200001468,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.041710792000003494,
    "cli": 0.34154841600000907,
    "warmup": 0.03490737600000671,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009961875000001896,
    "cli": 0.2094939999999923,
    "warmup": 0.009229583999996294,
    "probe_warmup": 0.008479832999995551,
    "rss": 0,
    "stages": 0.04058004100001256,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.043519250000002785,
    "cli": 0.3546764590000038,
    "warmup": 0.03630879199999981,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18925770800001374
  },
  "runtime": {
    "verify": 0.35125070899999855,
    "cli": 2.9745891679999943,
    "warmup": 0.33185562699999593,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-29）

退行の疑いは `interval-http` の二点（64・256）だけで、既知の原因（R20.0b の Http の import の費用、TODO-304。設計者が受け入れ済み）である。全94入力の after/before の中央値の比は 1.033 で、R20 の段の漂い（1.02〜1.04）の内にある。
