# 版どうしの性能比較

候補: `040b46f9abe4cbfa4a9e2715089b2a4a157211e4`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013504 | 0.000258 |
| functions-main-0-0 | after | 0.013955 | 0.000305 |
| functions-main-0-1 | before | 0.013660 | 0.000297 |
| functions-main-0-1 | after | 0.013801 | 0.001320 |
| functions-main-64-0 | before | 0.014132 | 0.001444 |
| functions-main-64-0 | after | 0.014387 | 0.000123 |
| functions-main-256-0 | before | 0.015452 | 0.000680 |
| functions-main-256-0 | after | 0.015688 | 0.000477 |
| functions-main-1000-0 | before | 0.021193 | 0.000236 |
| functions-main-1000-0 | after | 0.022232 | 0.000713 |
| functions-main-1000-1 | before | 0.020688 | 0.000570 |
| functions-main-1000-1 | after | 0.021347 | 0.000226 |
| functions-args-0-0 | before | 0.013701 | 0.000710 |
| functions-args-0-0 | after | 0.013721 | 0.000562 |
| functions-args-0-1 | before | 0.013671 | 0.000396 |
| functions-args-0-1 | after | 0.013933 | 0.000559 |
| functions-args-1000-0 | before | 0.026528 | 0.000436 |
| functions-args-1000-0 | after | 0.027809 | 0.000517 |
| functions-args-1000-1 | before | 0.026859 | 0.000738 |
| functions-args-1000-1 | after | 0.027935 | 0.000557 |
| functions-modules-0-0 | before | 0.013373 | 0.000095 |
| functions-modules-0-0 | after | 0.013714 | 0.001198 |
| functions-modules-0-1 | before | 0.013189 | 0.000411 |
| functions-modules-0-1 | after | 0.013333 | 0.000271 |
| functions-modules-1000-0 | before | 0.020889 | 0.000315 |
| functions-modules-1000-0 | after | 0.021603 | 0.000339 |
| functions-modules-1000-1 | before | 0.020968 | 0.000553 |
| functions-modules-1000-1 | after | 0.021714 | 0.000452 |
| existing-fib | before | 0.014041 | 0.000304 |
| existing-fib | after | 0.013965 | 0.000221 |
| existing-loop | before | 0.014105 | 0.000977 |
| existing-loop | after | 0.014136 | 0.000213 |
| existing-string | before | 0.013743 | 0.000288 |
| existing-string | after | 0.014391 | 0.000359 |
| higher-0-0 | before | 0.013834 | 0.001799 |
| higher-0-0 | after | 0.013596 | 0.000425 |
| higher-1-0 | before | 0.014107 | 0.000252 |
| higher-1-0 | after | 0.014360 | 0.000740 |
| classes-0 | before | 0.018246 | 0.000297 |
| classes-0 | after | 0.018419 | 0.000334 |
| higher-0-300 | before | 0.028472 | 0.000407 |
| higher-0-300 | after | 0.029310 | 0.000677 |
| higher-1-300 | before | 0.031129 | 0.000200 |
| higher-1-300 | after | 0.032289 | 0.001659 |
| classes-300 | before | 0.037392 | 0.000370 |
| classes-300 | after | 0.038612 | 0.001271 |
| depth-0-8 | before | 0.014565 | 0.000258 |
| depth-0-8 | after | 0.015034 | 0.000782 |
| depth-1-8 | before | 0.014793 | 0.000175 |
| depth-1-8 | after | 0.015220 | 0.000792 |
| f1-nofail-call | before | 0.014040 | 0.000342 |
| f1-nofail-call | after | 0.014312 | 0.000536 |
| f1-join-effects | before | 0.014483 | 0.000270 |
| f1-join-effects | after | 0.014517 | 0.000381 |
| control-16.3 | before | 0.012985 | 0.000475 |
| control-16.3 | after | 0.013500 | 0.000399 |
| interval-bind-64 | before | 0.013308 | 0.000366 |
| interval-bind-64 | after | 0.013427 | 0.000137 |
| interval-bind-256 | before | 0.014045 | 0.000870 |
| interval-bind-256 | after | 0.014017 | 0.000399 |
| interval-add-64 | before | 0.013240 | 0.000539 |
| interval-add-64 | after | 0.013515 | 0.000322 |
| interval-add-256 | before | 0.015215 | 0.000676 |
| interval-add-256 | after | 0.016287 | 0.000950 |
| interval-flow-64 | before | 0.014163 | 0.000323 |
| interval-flow-64 | after | 0.014388 | 0.000294 |
| interval-flow-256 | before | 0.016965 | 0.000242 |
| interval-flow-256 | after | 0.017187 | 0.000927 |
| interval-range-0 | before | 0.018362 | 0.000312 |
| interval-range-0 | after | 0.018906 | 0.000473 |
| interval-range-64 | before | 0.022968 | 0.000949 |
| interval-range-64 | after | 0.024080 | 0.001678 |
| interval-range-256 | before | 0.035510 | 0.000169 |
| interval-range-256 | after | 0.036950 | 0.000978 |
| interval-http-0 | before | 0.018889 | 0.000526 |
| interval-http-0 | after | 0.021642 | 0.000667 |
| interval-http-64 | before | 0.022132 | 0.000205 |
| interval-http-64 | after | 0.024510 | 0.001034 |
| interval-http-256 | before | 0.029625 | 0.000154 |
| interval-http-256 | after | 0.032323 | 0.000395 |
| interval-width-Integer8-64 | before | 0.014046 | 0.001047 |
| interval-width-Integer8-64 | after | 0.014440 | 0.000164 |
| interval-width-Integer8-256 | before | 0.016789 | 0.000307 |
| interval-width-Integer8-256 | after | 0.017306 | 0.000949 |
| interval-width-Integer16-64 | before | 0.013741 | 0.000255 |
| interval-width-Integer16-64 | after | 0.014409 | 0.000352 |
| interval-width-Integer16-256 | before | 0.016840 | 0.000361 |
| interval-width-Integer16-256 | after | 0.017707 | 0.001029 |
| interval-width-Integer32-64 | before | 0.013804 | 0.000987 |
| interval-width-Integer32-64 | after | 0.014049 | 0.000166 |
| interval-width-Integer32-256 | before | 0.017490 | 0.001087 |
| interval-width-Integer32-256 | after | 0.017840 | 0.000322 |
| interval-width-Integer64-64 | before | 0.013823 | 0.000878 |
| interval-width-Integer64-64 | after | 0.014146 | 0.000398 |
| interval-width-Integer64-256 | before | 0.016696 | 0.000486 |
| interval-width-Integer64-256 | after | 0.017273 | 0.000264 |
| interval-width-UnsignedInteger16-64 | before | 0.014176 | 0.000317 |
| interval-width-UnsignedInteger16-64 | after | 0.014240 | 0.000238 |
| interval-width-UnsignedInteger16-256 | before | 0.016883 | 0.000373 |
| interval-width-UnsignedInteger16-256 | after | 0.017264 | 0.000489 |
| interval-width-UnsignedInteger32-64 | before | 0.014300 | 0.000208 |
| interval-width-UnsignedInteger32-64 | after | 0.014468 | 0.000793 |
| interval-width-UnsignedInteger32-256 | before | 0.016881 | 0.000501 |
| interval-width-UnsignedInteger32-256 | after | 0.017187 | 0.000265 |
| interval-width-UnsignedInteger64-64 | before | 0.014127 | 0.000215 |
| interval-width-UnsignedInteger64-64 | after | 0.014404 | 0.000460 |
| interval-width-UnsignedInteger64-256 | before | 0.016719 | 0.000619 |
| interval-width-UnsignedInteger64-256 | after | 0.017208 | 0.000359 |
| property-seven-24-20-1000-all-ok | before | 0.036949 | 0.000447 |
| property-seven-24-20-1000-all-ok | after | 0.038347 | 0.000707 |
| property-seven-24-20-1000-always-error | before | 0.035377 | 0.000529 |
| property-seven-24-20-1000-always-error | after | 0.037038 | 0.000676 |
| property-distinct-24-20-1000-all-ok | before | 0.036524 | 0.000277 |
| property-distinct-24-20-1000-all-ok | after | 0.037152 | 0.000568 |
| property-distinct-24-20-1000-always-error | before | 0.036136 | 0.000571 |
| property-distinct-24-20-1000-always-error | after | 0.038093 | 0.001075 |
| property-zero-24-20-1000-all-ok | before | 0.036701 | 0.000414 |
| property-zero-24-20-1000-all-ok | after | 0.038488 | 0.000861 |
| property-zero-24-20-1000-always-error | before | 0.035816 | 0.001545 |
| property-zero-24-20-1000-always-error | after | 0.036824 | 0.000373 |
| property-max-24-20-1000-all-ok | before | 0.037294 | 0.000741 |
| property-max-24-20-1000-all-ok | after | 0.038361 | 0.000760 |
| property-max-24-20-1000-always-error | before | 0.035488 | 0.000580 |
| property-max-24-20-1000-always-error | after | 0.037187 | 0.001125 |
| order-string-candidates | before | 0.035245 | 0.000323 |
| order-string-candidates | after | 0.035807 | 0.000810 |
| order-string-all-ok | before | 0.035514 | 0.000310 |
| order-string-all-ok | after | 0.036734 | 0.000848 |
| order-string-always-error | before | 0.034694 | 0.000545 |
| order-string-always-error | after | 0.035964 | 0.000746 |
| order-map-candidates | before | 0.035341 | 0.000169 |
| order-map-candidates | after | 0.036691 | 0.000979 |
| order-map-all-ok | before | 0.036500 | 0.001424 |
| order-map-all-ok | after | 0.036761 | 0.001396 |
| order-map-always-error | before | 0.035491 | 0.000918 |
| order-map-always-error | after | 0.036363 | 0.000258 |
| order-record-candidates | before | 0.036117 | 0.000678 |
| order-record-candidates | after | 0.037138 | 0.000466 |
| order-record-all-ok | before | 0.035856 | 0.000495 |
| order-record-all-ok | after | 0.037522 | 0.000784 |
| order-record-always-error | before | 0.035642 | 0.000999 |
| order-record-always-error | after | 0.036751 | 0.000466 |
| build-string-builder-8-0 | before | 0.015855 | 0.000274 |
| build-string-builder-8-0 | after | 0.016472 | 0.000398 |
| build-string-builder-all-8-0 | before | 0.015882 | 0.000180 |
| build-string-builder-all-8-0 | after | 0.015984 | 0.000257 |
| build-string-concatenate-8-0 | before | 0.015438 | 0.000861 |
| build-string-concatenate-8-0 | after | 0.016099 | 0.001070 |
| build-string-join-8-0 | before | 0.015798 | 0.001026 |
| build-string-join-8-0 | after | 0.016054 | 0.000351 |
| build-list-builder-8-0 | before | 0.015945 | 0.000548 |
| build-list-builder-8-0 | after | 0.016588 | 0.000555 |
| build-list-builder-all-8-0 | before | 0.016201 | 0.000175 |
| build-list-builder-all-8-0 | after | 0.016667 | 0.000458 |
| build-list-concatenate-8-0 | before | 0.016144 | 0.000226 |
| build-list-concatenate-8-0 | after | 0.016843 | 0.000504 |
| build-list-fold-8-0 | before | 0.016083 | 0.000671 |
| build-list-fold-8-0 | after | 0.016211 | 0.000484 |
| build-bytes-builder-8-0 | before | 0.016245 | 0.000636 |
| build-bytes-builder-8-0 | after | 0.016247 | 0.000366 |
| build-bytes-builder-all-8-0 | before | 0.016297 | 0.000744 |
| build-bytes-builder-all-8-0 | after | 0.016603 | 0.000374 |
| build-bytes-concatenate-8-0 | before | 0.016321 | 0.000128 |
| build-bytes-concatenate-8-0 | after | 0.016842 | 0.000870 |
| patterns-integer-100 | before | 0.014665 | 0.000925 |
| patterns-integer-100 | after | 0.014575 | 0.000217 |
| codegen-let-100 | before | 0.017726 | 0.000534 |
| codegen-let-100 | after | 0.017515 | 0.000743 |
| bridge-shared-8 | before | 0.004460 | 0.000571 |
| bridge-shared-8 | after | 0.004503 | 0.000442 |
| external-tests-normal-1 | before | 0.017528 | 0.000848 |
| external-tests-normal-1 | after | 0.018243 | 0.000513 |
| runtime-fib-short | before | 0.018077 | 0.000411 |
| runtime-fib-short | after | 0.018804 | 0.000871 |
| runtime-loop-short | before | 0.023444 | 0.000678 |
| runtime-loop-short | after | 0.023849 | 0.000332 |
| runtime-list-short | before | 0.029267 | 0.000602 |
| runtime-list-short | after | 0.029668 | 0.000264 |
| runtime-tree-short | before | 0.018449 | 0.000332 |
| runtime-tree-short | after | 0.018605 | 0.000264 |
| runtime-eval-short | before | 0.021889 | 0.000158 |
| runtime-eval-short | after | 0.022278 | 0.000381 |
| runtime-string-short | before | 0.016982 | 0.000775 |
| runtime-string-short | after | 0.017252 | 0.000162 |
| runtime-println-short | before | 0.016989 | 0.000434 |
| runtime-println-short | after | 0.017334 | 0.001318 |
| runtime-lines-short | before | 0.016699 | 0.000417 |
| runtime-lines-short | after | 0.016938 | 0.000394 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.75e-05 | 1.666e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.041e-06 | 6.66e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.0541e-05 | 2.374e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5958e-05 | 3.75e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.916e-06 | 4.16e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.9166e-05 | 5.83e-07 |
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
    "after": "040b46f9abe4cbfa4a9e2715089b2a4a157211e4"
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
| functions-main-1000-0 | 達成 | 0.0010385830000103624 | 0.0021193083999989427 |
| functions-main-1000-1 | 判定不能 | None | 0.0020687874999993027 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | 0.001280459000000178 | 0.0026528458000001365 |
| functions-args-1000-1 | 判定不能 | None | 0.002685929199999748 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | 0.0007147079999896278 | 0.0020888542000008672 |
| functions-modules-1000-1 | 判定不能 | None | 0.002096804199999269 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 達成 | 0.0006481670000084705 | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002847162499999456 |
| higher-1-300 | 判定不能 | None | 0.003112866600000075 |
| classes-300 | 判定不能 | None | 0.003739245799999935 |
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
| interval-range-64 | 判定不能 | None | 0.0022967665999999555 |
| interval-range-256 | 達成 | 0.001440790999993169 | 0.0035509500000003415 |
| interval-http-0 | 退行の疑い | 0.0027533749999975043 | 0.002 |
| interval-http-64 | 退行の疑い | 0.002378084000000058 | 0.0022131916000006414 |
| interval-http-256 | 達成 | 0.002697791999992205 | 0.0029625207999998794 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 達成 | 0.0006675009999952408 | 0.002 |
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
| property-seven-24-20-1000-all-ok | 達成 | 0.0013976659999883623 | 0.00369494589999988 |
| property-seven-24-20-1000-always-error | 達成 | 0.0016608340000061617 | 0.0035377249999996255 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.0036523792000011214 |
| property-distinct-24-20-1000-always-error | 達成 | 0.0019575420000137456 | 0.0036135790999992424 |
| property-zero-24-20-1000-all-ok | 達成 | 0.0017864580000122032 | 0.0036701499999992394 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003581595899999002 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0037293874999988932 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003548766699999817 |
| order-string-candidates | 判定不能 | None | 0.003524508300000662 |
| order-string-all-ok | 達成 | 0.0012195829999939178 | 0.0035514417000001687 |
| order-string-always-error | 判定不能 | None | 0.0034693583999995782 |
| order-map-candidates | 達成 | 0.001350166999984026 | 0.0035341083000005828 |
| order-map-all-ok | 判定不能 | None | 0.0036500124999989227 |
| order-map-always-error | 判定不能 | None | 0.003549066700000481 |
| order-record-candidates | 判定不能 | None | 0.003611674999999082 |
| order-record-all-ok | 達成 | 0.0016656660000080592 | 0.0035856499999994186 |
| order-record-always-error | 判定不能 | None | 0.0035641541999993365 |
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
| runtime-loop-short | 判定不能 | None | 0.002344449999999654 |
| runtime-list-short | 判定不能 | None | 0.002926745799999253 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002188925000000097 |
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
    "verify": 1.7941133329999985,
    "cli": 5.298632292999997,
    "warmup": 0.5944938739999941,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 3.0216484580000014,
    "cli": 11.809960874999987,
    "warmup": 1.365117458000043,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.28608100000001,
    "cli": 8.984049043000013,
    "warmup": 1.2455988760000452,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.37635145899999145,
    "cli": 3.550143372000008,
    "warmup": 0.3595899600000223,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09991791699999908,
    "cli": 0.2806056659999996,
    "warmup": 0.0305435830000107,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03555441700000017,
    "cli": 0.3403650839999983,
    "warmup": 0.03449141700001235,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009208915999991518,
    "cli": 0.1997157910000027,
    "warmup": 0.008733249999991699,
    "probe_warmup": 0.008053666999998654,
    "rss": 0,
    "stages": 0.0383344169999873,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.042367124999998396,
    "cli": 0.33974270800000284,
    "warmup": 0.035156332999989104,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.178169039999986
  },
  "runtime": {
    "verify": 0.3443554159999991,
    "cli": 2.919096250000024,
    "warmup": 0.32667600100002403,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
