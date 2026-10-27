# 版どうしの性能比較

候補: `3b275ce839a27e35e0ba47028cde8801a64011b6`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013559 | 0.000169 |
| functions-main-0-0 | after | 0.013155 | 0.000524 |
| functions-main-0-1 | before | 0.013669 | 0.001196 |
| functions-main-0-1 | after | 0.012855 | 0.000162 |
| functions-main-64-0 | before | 0.014534 | 0.002316 |
| functions-main-64-0 | after | 0.013500 | 0.000254 |
| functions-main-256-0 | before | 0.016953 | 0.001122 |
| functions-main-256-0 | after | 0.014586 | 0.000302 |
| functions-main-1000-0 | before | 0.032048 | 0.000327 |
| functions-main-1000-0 | after | 0.020448 | 0.001715 |
| functions-main-1000-1 | before | 0.031723 | 0.000130 |
| functions-main-1000-1 | after | 0.020533 | 0.002494 |
| functions-args-0-0 | before | 0.013505 | 0.000756 |
| functions-args-0-0 | after | 0.012866 | 0.000245 |
| functions-args-0-1 | before | 0.013531 | 0.000861 |
| functions-args-0-1 | after | 0.013075 | 0.000226 |
| functions-args-1000-0 | before | 0.048498 | 0.002040 |
| functions-args-1000-0 | after | 0.026404 | 0.000458 |
| functions-args-1000-1 | before | 0.048264 | 0.000904 |
| functions-args-1000-1 | after | 0.026326 | 0.000443 |
| functions-modules-0-0 | before | 0.013564 | 0.000839 |
| functions-modules-0-0 | after | 0.012963 | 0.000101 |
| functions-modules-0-1 | before | 0.013677 | 0.000492 |
| functions-modules-0-1 | after | 0.013026 | 0.000437 |
| functions-modules-1000-0 | before | 0.025284 | 0.001175 |
| functions-modules-1000-0 | after | 0.021918 | 0.001040 |
| functions-modules-1000-1 | before | 0.025342 | 0.000397 |
| functions-modules-1000-1 | after | 0.020964 | 0.000771 |
| existing-fib | before | 0.014149 | 0.000735 |
| existing-fib | after | 0.013503 | 0.000318 |
| existing-loop | before | 0.014072 | 0.001742 |
| existing-loop | after | 0.013615 | 0.000088 |
| existing-string | before | 0.014146 | 0.001025 |
| existing-string | after | 0.013467 | 0.000190 |
| higher-0-0 | before | 0.013623 | 0.000602 |
| higher-0-0 | after | 0.013050 | 0.000194 |
| higher-1-0 | before | 0.014612 | 0.000526 |
| higher-1-0 | after | 0.013751 | 0.000132 |
| classes-0 | before | 0.019508 | 0.000696 |
| classes-0 | after | 0.017715 | 0.000330 |
| higher-0-300 | before | 0.027268 | 0.000317 |
| higher-0-300 | after | 0.028296 | 0.001479 |
| higher-1-300 | before | 0.029822 | 0.000775 |
| higher-1-300 | after | 0.031142 | 0.000393 |
| classes-300 | before | 0.038777 | 0.000910 |
| classes-300 | after | 0.037206 | 0.000604 |
| depth-0-8 | before | 0.014869 | 0.001297 |
| depth-0-8 | after | 0.014291 | 0.000109 |
| depth-1-8 | before | 0.015125 | 0.001439 |
| depth-1-8 | after | 0.014480 | 0.000253 |
| f1-nofail-call | before | 0.014610 | 0.000996 |
| f1-nofail-call | after | 0.013928 | 0.000562 |
| f1-join-effects | before | 0.014673 | 0.001375 |
| f1-join-effects | after | 0.013775 | 0.000152 |
| control-16.3 | before | 0.013545 | 0.001080 |
| control-16.3 | after | 0.012783 | 0.000197 |
| interval-bind-64 | before | 0.013683 | 0.000606 |
| interval-bind-64 | after | 0.012925 | 0.000084 |
| interval-bind-256 | before | 0.014396 | 0.001693 |
| interval-bind-256 | after | 0.013704 | 0.000236 |
| interval-add-64 | before | 0.013905 | 0.000660 |
| interval-add-64 | after | 0.013066 | 0.000123 |
| interval-add-256 | before | 0.015290 | 0.000730 |
| interval-add-256 | after | 0.014641 | 0.000058 |
| interval-flow-64 | before | 0.014560 | 0.000780 |
| interval-flow-64 | after | 0.014004 | 0.000195 |
| interval-flow-256 | before | 0.017286 | 0.000735 |
| interval-flow-256 | after | 0.018149 | 0.000880 |
| interval-range-0 | before | 0.020573 | 0.000489 |
| interval-range-0 | after | 0.018304 | 0.000876 |
| interval-range-64 | before | 0.025172 | 0.000307 |
| interval-range-64 | after | 0.023558 | 0.001167 |
| interval-range-256 | before | 0.038348 | 0.001418 |
| interval-range-256 | after | 0.036654 | 0.000621 |
| interval-http-0 | before | 0.021789 | 0.000597 |
| interval-http-0 | after | 0.019337 | 0.002034 |
| interval-http-64 | before | 0.023957 | 0.000253 |
| interval-http-64 | after | 0.022223 | 0.001278 |
| interval-http-256 | before | 0.032827 | 0.000383 |
| interval-http-256 | after | 0.029903 | 0.000787 |
| interval-width-Integer8-64 | before | 0.014578 | 0.001182 |
| interval-width-Integer8-64 | after | 0.014222 | 0.000559 |
| interval-width-Integer8-256 | before | 0.017373 | 0.000702 |
| interval-width-Integer8-256 | after | 0.016949 | 0.000235 |
| interval-width-Integer16-64 | before | 0.014485 | 0.000848 |
| interval-width-Integer16-64 | after | 0.013955 | 0.000111 |
| interval-width-Integer16-256 | before | 0.017390 | 0.001252 |
| interval-width-Integer16-256 | after | 0.017203 | 0.000245 |
| interval-width-Integer32-64 | before | 0.014527 | 0.000805 |
| interval-width-Integer32-64 | after | 0.014839 | 0.000507 |
| interval-width-Integer32-256 | before | 0.017486 | 0.000618 |
| interval-width-Integer32-256 | after | 0.017005 | 0.000314 |
| interval-width-Integer64-64 | before | 0.014594 | 0.000834 |
| interval-width-Integer64-64 | after | 0.014213 | 0.000336 |
| interval-width-Integer64-256 | before | 0.017422 | 0.000510 |
| interval-width-Integer64-256 | after | 0.017437 | 0.000375 |
| interval-width-UnsignedInteger16-64 | before | 0.014305 | 0.000904 |
| interval-width-UnsignedInteger16-64 | after | 0.013939 | 0.000310 |
| interval-width-UnsignedInteger16-256 | before | 0.017409 | 0.000544 |
| interval-width-UnsignedInteger16-256 | after | 0.016890 | 0.000324 |
| interval-width-UnsignedInteger32-64 | before | 0.014352 | 0.001393 |
| interval-width-UnsignedInteger32-64 | after | 0.013866 | 0.000117 |
| interval-width-UnsignedInteger32-256 | before | 0.016845 | 0.000693 |
| interval-width-UnsignedInteger32-256 | after | 0.016859 | 0.000247 |
| interval-width-UnsignedInteger64-64 | before | 0.014293 | 0.001090 |
| interval-width-UnsignedInteger64-64 | after | 0.014118 | 0.000210 |
| interval-width-UnsignedInteger64-256 | before | 0.016984 | 0.000862 |
| interval-width-UnsignedInteger64-256 | after | 0.016818 | 0.000291 |
| property-seven-24-20-1000-all-ok | before | 0.040384 | 0.001535 |
| property-seven-24-20-1000-all-ok | after | 0.037270 | 0.000588 |
| property-seven-24-20-1000-always-error | before | 0.038812 | 0.002500 |
| property-seven-24-20-1000-always-error | after | 0.035260 | 0.000441 |
| property-distinct-24-20-1000-all-ok | before | 0.039796 | 0.001990 |
| property-distinct-24-20-1000-all-ok | after | 0.036286 | 0.000189 |
| property-distinct-24-20-1000-always-error | before | 0.039184 | 0.001827 |
| property-distinct-24-20-1000-always-error | after | 0.035491 | 0.000190 |
| property-zero-24-20-1000-all-ok | before | 0.040310 | 0.001717 |
| property-zero-24-20-1000-all-ok | after | 0.036571 | 0.000490 |
| property-zero-24-20-1000-always-error | before | 0.038937 | 0.001663 |
| property-zero-24-20-1000-always-error | after | 0.035608 | 0.000316 |
| property-max-24-20-1000-all-ok | before | 0.040205 | 0.001077 |
| property-max-24-20-1000-all-ok | after | 0.036787 | 0.000462 |
| property-max-24-20-1000-always-error | before | 0.039758 | 0.001596 |
| property-max-24-20-1000-always-error | after | 0.035561 | 0.000474 |
| order-string-candidates | before | 0.038936 | 0.001345 |
| order-string-candidates | after | 0.035487 | 0.000292 |
| order-string-all-ok | before | 0.039345 | 0.002442 |
| order-string-all-ok | after | 0.036044 | 0.000481 |
| order-string-always-error | before | 0.038561 | 0.001609 |
| order-string-always-error | after | 0.035250 | 0.000249 |
| order-map-candidates | before | 0.039167 | 0.000916 |
| order-map-candidates | after | 0.035606 | 0.000652 |
| order-map-all-ok | before | 0.039714 | 0.001341 |
| order-map-all-ok | after | 0.036181 | 0.000323 |
| order-map-always-error | before | 0.039518 | 0.001317 |
| order-map-always-error | after | 0.035640 | 0.000426 |
| order-record-candidates | before | 0.039825 | 0.001591 |
| order-record-candidates | after | 0.036012 | 0.000421 |
| order-record-all-ok | before | 0.039810 | 0.001516 |
| order-record-all-ok | after | 0.036554 | 0.000687 |
| order-record-always-error | before | 0.039613 | 0.001548 |
| order-record-always-error | after | 0.036320 | 0.000360 |
| build-string-builder-8-0 | before | 0.016310 | 0.000646 |
| build-string-builder-8-0 | after | 0.015564 | 0.000210 |
| build-string-builder-all-8-0 | before | 0.016737 | 0.000381 |
| build-string-builder-all-8-0 | after | 0.015692 | 0.000149 |
| build-string-concatenate-8-0 | before | 0.016471 | 0.000548 |
| build-string-concatenate-8-0 | after | 0.015628 | 0.000331 |
| build-string-join-8-0 | before | 0.016066 | 0.000636 |
| build-string-join-8-0 | after | 0.015410 | 0.000159 |
| build-list-builder-8-0 | before | 0.016476 | 0.000511 |
| build-list-builder-8-0 | after | 0.015820 | 0.000169 |
| build-list-builder-all-8-0 | before | 0.016488 | 0.000800 |
| build-list-builder-all-8-0 | after | 0.015972 | 0.000344 |
| build-list-concatenate-8-0 | before | 0.016734 | 0.000507 |
| build-list-concatenate-8-0 | after | 0.016218 | 0.000156 |
| build-list-fold-8-0 | before | 0.016573 | 0.000706 |
| build-list-fold-8-0 | after | 0.015818 | 0.000323 |
| build-bytes-builder-8-0 | before | 0.016599 | 0.000648 |
| build-bytes-builder-8-0 | after | 0.015813 | 0.000116 |
| build-bytes-builder-all-8-0 | before | 0.016528 | 0.000412 |
| build-bytes-builder-all-8-0 | after | 0.015857 | 0.000223 |
| build-bytes-concatenate-8-0 | before | 0.016656 | 0.000352 |
| build-bytes-concatenate-8-0 | after | 0.016255 | 0.000394 |
| patterns-integer-100 | before | 0.015123 | 0.000800 |
| patterns-integer-100 | after | 0.014088 | 0.000119 |
| codegen-let-100 | before | 0.017465 | 0.000448 |
| codegen-let-100 | after | 0.016966 | 0.000738 |
| bridge-shared-8 | before | 0.004603 | 0.000222 |
| bridge-shared-8 | after | 0.004578 | 0.000596 |
| external-tests-normal-1 | before | 0.018292 | 0.000449 |
| external-tests-normal-1 | after | 0.017739 | 0.001382 |
| runtime-fib-short | before | 0.018495 | 0.000339 |
| runtime-fib-short | after | 0.017867 | 0.001079 |
| runtime-loop-short | before | 0.024019 | 0.000556 |
| runtime-loop-short | after | 0.023578 | 0.001337 |
| runtime-list-short | before | 0.029846 | 0.001101 |
| runtime-list-short | after | 0.029366 | 0.000868 |
| runtime-tree-short | before | 0.018973 | 0.000421 |
| runtime-tree-short | after | 0.018369 | 0.001095 |
| runtime-eval-short | before | 0.022351 | 0.000202 |
| runtime-eval-short | after | 0.022060 | 0.000763 |
| runtime-string-short | before | 0.017432 | 0.000560 |
| runtime-string-short | after | 0.016909 | 0.000430 |
| runtime-println-short | before | 0.017398 | 0.000491 |
| runtime-println-short | after | 0.016809 | 0.000603 |
| runtime-lines-short | before | 0.017265 | 0.000522 |
| runtime-lines-short | after | 0.016522 | 0.000305 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.3959e-05 | 8.75e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.625e-06 | 5.41e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.7584e-05 | 1.416e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5208e-05 | 1.208e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.958e-06 | 6.66e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.8166e-05 | 2e-06 |
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
    "after": "3b275ce839a27e35e0ba47028cde8801a64011b6"
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
| functions-main-256-0 | 達成 | -0.002367332999980931 | 0.002 |
| functions-main-1000-0 | 達成 | -0.011599666999998703 | 0.0032047625000004134 |
| functions-main-1000-1 | 達成 | -0.011190583000001197 | 0.003172329100000582 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | -0.022094416000015826 | 0.004849800000000926 |
| functions-args-1000-1 | 達成 | -0.021937291000000414 | 0.004826362500000414 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | -0.00336554199999739 | 0.0025283916999995883 |
| functions-modules-1000-1 | 達成 | -0.004377958000006288 | 0.002534220800001208 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 達成 | -0.0008611659999928634 | 0.002 |
| classes-0 | 達成 | -0.001793208000009372 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002726820800000951 |
| higher-1-300 | 達成 | 0.001319291000001499 | 0.0029822249999995167 |
| classes-300 | 達成 | -0.0015709160000056954 | 0.0038776625000011226 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 達成 | -0.0007576670000020158 | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 達成 | -0.0008382910000079846 | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 達成 | -0.002268957000012506 | 0.002057316600000547 |
| interval-range-64 | 達成 | -0.0016144570000022895 | 0.002517241599998954 |
| interval-range-256 | 判定不能 | None | 0.003834804100000611 |
| interval-http-0 | 判定不能 | None | 0.0021789166999994338 |
| interval-http-64 | 達成 | -0.001733999999999014 | 0.002395674999999642 |
| interval-http-256 | 達成 | -0.0029230420000203594 | 0.0032826500000012974 |
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
| property-seven-24-20-1000-all-ok | 達成 | -0.0031137090000044054 | 0.004038391699999977 |
| property-seven-24-20-1000-always-error | 達成 | -0.003552749999997218 | 0.003881237499999202 |
| property-distinct-24-20-1000-all-ok | 達成 | -0.003510540999997147 | 0.003979645799999787 |
| property-distinct-24-20-1000-always-error | 達成 | -0.003693249999997761 | 0.003918449999999041 |
| property-zero-24-20-1000-all-ok | 達成 | -0.0037389169999926253 | 0.004030999999999097 |
| property-zero-24-20-1000-always-error | 達成 | -0.003328832999997644 | 0.0038936917000000903 |
| property-max-24-20-1000-all-ok | 達成 | -0.003418707999998105 | 0.004020520800000327 |
| property-max-24-20-1000-always-error | 達成 | -0.004196874999990996 | 0.0039757957999995595 |
| order-string-candidates | 達成 | -0.0034485000000046284 | 0.0038935500000008005 |
| order-string-all-ok | 達成 | -0.003300917000004233 | 0.003934454199999493 |
| order-string-always-error | 達成 | -0.0033103329999875086 | 0.003856070799999145 |
| order-map-candidates | 達成 | -0.003560749000001806 | 0.003916720799999496 |
| order-map-all-ok | 達成 | -0.003533208999996873 | 0.003971383399999695 |
| order-map-always-error | 達成 | -0.0038777080000045316 | 0.003951820800000405 |
| order-record-candidates | 達成 | -0.0038126669999911655 | 0.003982512499999302 |
| order-record-all-ok | 達成 | -0.0032554590000017924 | 0.003980966700000011 |
| order-record-always-error | 達成 | -0.003293126000002644 | 0.00396126670000001 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 達成 | -0.0010451659999972662 | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 達成 | -0.0007862079999938487 | 0.002 |
| build-bytes-builder-all-8-0 | 達成 | -0.0006713749999818219 | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0024018957999999203 |
| runtime-list-short | 判定不能 | None | 0.0029846415999998047 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002235050000000172 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 達成 | -0.0010351239999977224 | 0.002 |
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
    "verify": 1.8480902919999949,
    "cli": 5.594338627000042,
    "warmup": 0.6560050840000287,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.9409238749999957,
    "cli": 11.877200753999944,
    "warmup": 1.375010080999985,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.318400374999996,
    "cli": 9.218425413999967,
    "warmup": 1.2927027869999534,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3705787090000001,
    "cli": 3.560799043000003,
    "warmup": 0.3595671229999624,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09769249999999374,
    "cli": 0.2817308340000011,
    "warmup": 0.029540834000002292,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.036477292000000716,
    "cli": 0.33587254200000416,
    "warmup": 0.03447587499999827,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009925374999994574,
    "cli": 0.20427879100000723,
    "warmup": 0.009060876000006601,
    "probe_warmup": 0.007880499999998847,
    "rss": 0,
    "stages": 0.03927587499997287,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04155137499999739,
    "cli": 0.34263654200000815,
    "warmup": 0.03585333399999513,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.1799313739999917
  },
  "runtime": {
    "verify": 0.33534308400000157,
    "cli": 2.9301529579999794,
    "warmup": 0.3282267079999741,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
