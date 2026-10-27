# 版どうしの性能比較

候補: `1f1f32aeaf1c37dddb106ffcb82551bdfa5b0b90`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013880 | 0.000260 |
| functions-main-0-0 | after | 0.012964 | 0.000099 |
| functions-main-0-1 | before | 0.013915 | 0.000652 |
| functions-main-0-1 | after | 0.013071 | 0.000417 |
| functions-main-64-0 | before | 0.014326 | 0.001407 |
| functions-main-64-0 | after | 0.013806 | 0.000544 |
| functions-main-256-0 | before | 0.017161 | 0.002055 |
| functions-main-256-0 | after | 0.014825 | 0.000178 |
| functions-main-1000-0 | before | 0.031836 | 0.000243 |
| functions-main-1000-0 | after | 0.020875 | 0.000415 |
| functions-main-1000-1 | before | 0.031853 | 0.000410 |
| functions-main-1000-1 | after | 0.020348 | 0.001703 |
| functions-args-0-0 | before | 0.013570 | 0.000224 |
| functions-args-0-0 | after | 0.012896 | 0.000208 |
| functions-args-0-1 | before | 0.014201 | 0.000747 |
| functions-args-0-1 | after | 0.013077 | 0.000796 |
| functions-args-1000-0 | before | 0.048679 | 0.001025 |
| functions-args-1000-0 | after | 0.026764 | 0.001455 |
| functions-args-1000-1 | before | 0.049934 | 0.001974 |
| functions-args-1000-1 | after | 0.027334 | 0.000433 |
| functions-modules-0-0 | before | 0.014745 | 0.001238 |
| functions-modules-0-0 | after | 0.013963 | 0.000564 |
| functions-modules-0-1 | before | 0.014608 | 0.000589 |
| functions-modules-0-1 | after | 0.013591 | 0.000270 |
| functions-modules-1000-0 | before | 0.026101 | 0.000480 |
| functions-modules-1000-0 | after | 0.021154 | 0.001845 |
| functions-modules-1000-1 | before | 0.025806 | 0.000895 |
| functions-modules-1000-1 | after | 0.021837 | 0.001187 |
| existing-fib | before | 0.014795 | 0.001160 |
| existing-fib | after | 0.014201 | 0.000355 |
| existing-loop | before | 0.014670 | 0.001762 |
| existing-loop | after | 0.014284 | 0.001085 |
| existing-string | before | 0.015200 | 0.001210 |
| existing-string | after | 0.014158 | 0.000628 |
| higher-0-0 | before | 0.013938 | 0.001181 |
| higher-0-0 | after | 0.013210 | 0.000906 |
| higher-1-0 | before | 0.014840 | 0.001320 |
| higher-1-0 | after | 0.014303 | 0.000438 |
| classes-0 | before | 0.019964 | 0.000541 |
| classes-0 | after | 0.017671 | 0.000967 |
| higher-0-300 | before | 0.027714 | 0.000667 |
| higher-0-300 | after | 0.029820 | 0.000727 |
| higher-1-300 | before | 0.031498 | 0.001322 |
| higher-1-300 | after | 0.032504 | 0.000910 |
| classes-300 | before | 0.039188 | 0.001585 |
| classes-300 | after | 0.037935 | 0.001096 |
| depth-0-8 | before | 0.015920 | 0.000506 |
| depth-0-8 | after | 0.014486 | 0.000616 |
| depth-1-8 | before | 0.015709 | 0.001137 |
| depth-1-8 | after | 0.014866 | 0.000788 |
| f1-nofail-call | before | 0.015052 | 0.001655 |
| f1-nofail-call | after | 0.013960 | 0.000741 |
| f1-join-effects | before | 0.015885 | 0.000910 |
| f1-join-effects | after | 0.013947 | 0.000848 |
| control-16.3 | before | 0.014106 | 0.001682 |
| control-16.3 | after | 0.014070 | 0.000830 |
| interval-bind-64 | before | 0.014467 | 0.001200 |
| interval-bind-64 | after | 0.013755 | 0.000383 |
| interval-bind-256 | before | 0.014397 | 0.001212 |
| interval-bind-256 | after | 0.013973 | 0.000550 |
| interval-add-64 | before | 0.014420 | 0.001887 |
| interval-add-64 | after | 0.013236 | 0.000354 |
| interval-add-256 | before | 0.016879 | 0.001102 |
| interval-add-256 | after | 0.015304 | 0.000666 |
| interval-flow-64 | before | 0.014964 | 0.001410 |
| interval-flow-64 | after | 0.013844 | 0.000791 |
| interval-flow-256 | before | 0.018293 | 0.001059 |
| interval-flow-256 | after | 0.016852 | 0.000280 |
| interval-range-0 | before | 0.021766 | 0.001420 |
| interval-range-0 | after | 0.018799 | 0.002589 |
| interval-range-64 | before | 0.026691 | 0.001195 |
| interval-range-64 | after | 0.023785 | 0.001952 |
| interval-range-256 | before | 0.040227 | 0.001973 |
| interval-range-256 | after | 0.036554 | 0.000722 |
| interval-http-0 | before | 0.022365 | 0.000691 |
| interval-http-0 | after | 0.020224 | 0.001346 |
| interval-http-64 | before | 0.026448 | 0.001375 |
| interval-http-64 | after | 0.023431 | 0.001520 |
| interval-http-256 | before | 0.035132 | 0.001523 |
| interval-http-256 | after | 0.031195 | 0.001111 |
| interval-width-Integer8-64 | before | 0.015952 | 0.000844 |
| interval-width-Integer8-64 | after | 0.014493 | 0.000435 |
| interval-width-Integer8-256 | before | 0.018007 | 0.000245 |
| interval-width-Integer8-256 | after | 0.017215 | 0.000410 |
| interval-width-Integer16-64 | before | 0.014621 | 0.001662 |
| interval-width-Integer16-64 | after | 0.014310 | 0.000703 |
| interval-width-Integer16-256 | before | 0.017996 | 0.000646 |
| interval-width-Integer16-256 | after | 0.016817 | 0.000328 |
| interval-width-Integer32-64 | before | 0.014865 | 0.000716 |
| interval-width-Integer32-64 | after | 0.014161 | 0.000399 |
| interval-width-Integer32-256 | before | 0.017572 | 0.000323 |
| interval-width-Integer32-256 | after | 0.016671 | 0.000238 |
| interval-width-Integer64-64 | before | 0.014898 | 0.002404 |
| interval-width-Integer64-64 | after | 0.014064 | 0.000571 |
| interval-width-Integer64-256 | before | 0.018230 | 0.001227 |
| interval-width-Integer64-256 | after | 0.017125 | 0.000797 |
| interval-width-UnsignedInteger16-64 | before | 0.015086 | 0.000536 |
| interval-width-UnsignedInteger16-64 | after | 0.014049 | 0.000769 |
| interval-width-UnsignedInteger16-256 | before | 0.017828 | 0.001348 |
| interval-width-UnsignedInteger16-256 | after | 0.016873 | 0.000762 |
| interval-width-UnsignedInteger32-64 | before | 0.014575 | 0.001901 |
| interval-width-UnsignedInteger32-64 | after | 0.013810 | 0.000307 |
| interval-width-UnsignedInteger32-256 | before | 0.017644 | 0.001149 |
| interval-width-UnsignedInteger32-256 | after | 0.016759 | 0.000348 |
| interval-width-UnsignedInteger64-64 | before | 0.014837 | 0.000794 |
| interval-width-UnsignedInteger64-64 | after | 0.014120 | 0.000567 |
| interval-width-UnsignedInteger64-256 | before | 0.017277 | 0.000750 |
| interval-width-UnsignedInteger64-256 | after | 0.016561 | 0.000930 |
| property-seven-24-20-1000-all-ok | before | 0.040540 | 0.001157 |
| property-seven-24-20-1000-all-ok | after | 0.037889 | 0.001109 |
| property-seven-24-20-1000-always-error | before | 0.040051 | 0.003289 |
| property-seven-24-20-1000-always-error | after | 0.036325 | 0.000601 |
| property-distinct-24-20-1000-all-ok | before | 0.040972 | 0.001646 |
| property-distinct-24-20-1000-all-ok | after | 0.036576 | 0.000935 |
| property-distinct-24-20-1000-always-error | before | 0.040730 | 0.001268 |
| property-distinct-24-20-1000-always-error | after | 0.035728 | 0.000727 |
| property-zero-24-20-1000-all-ok | before | 0.040108 | 0.000989 |
| property-zero-24-20-1000-all-ok | after | 0.037976 | 0.000881 |
| property-zero-24-20-1000-always-error | before | 0.040012 | 0.001058 |
| property-zero-24-20-1000-always-error | after | 0.036099 | 0.000619 |
| property-max-24-20-1000-all-ok | before | 0.042440 | 0.001285 |
| property-max-24-20-1000-all-ok | after | 0.037241 | 0.000810 |
| property-max-24-20-1000-always-error | before | 0.040737 | 0.002167 |
| property-max-24-20-1000-always-error | after | 0.037582 | 0.000606 |
| order-string-candidates | before | 0.039392 | 0.002139 |
| order-string-candidates | after | 0.035612 | 0.000754 |
| order-string-all-ok | before | 0.041251 | 0.001993 |
| order-string-all-ok | after | 0.037818 | 0.001750 |
| order-string-always-error | before | 0.040920 | 0.002874 |
| order-string-always-error | after | 0.036404 | 0.001166 |
| order-map-candidates | before | 0.040547 | 0.001490 |
| order-map-candidates | after | 0.035681 | 0.001270 |
| order-map-all-ok | before | 0.041850 | 0.001718 |
| order-map-all-ok | after | 0.036988 | 0.000833 |
| order-map-always-error | before | 0.040224 | 0.001681 |
| order-map-always-error | after | 0.035782 | 0.000882 |
| order-record-candidates | before | 0.041866 | 0.001462 |
| order-record-candidates | after | 0.036705 | 0.001315 |
| order-record-all-ok | before | 0.040028 | 0.001886 |
| order-record-all-ok | after | 0.036252 | 0.000528 |
| order-record-always-error | before | 0.041382 | 0.001355 |
| order-record-always-error | after | 0.037928 | 0.000884 |
| build-string-builder-8-0 | before | 0.017121 | 0.001139 |
| build-string-builder-8-0 | after | 0.016201 | 0.002119 |
| build-string-builder-all-8-0 | before | 0.016841 | 0.001415 |
| build-string-builder-all-8-0 | after | 0.015899 | 0.000407 |
| build-string-concatenate-8-0 | before | 0.016894 | 0.000504 |
| build-string-concatenate-8-0 | after | 0.016238 | 0.000557 |
| build-string-join-8-0 | before | 0.016520 | 0.000816 |
| build-string-join-8-0 | after | 0.015770 | 0.000688 |
| build-list-builder-8-0 | before | 0.017126 | 0.001074 |
| build-list-builder-8-0 | after | 0.015970 | 0.000783 |
| build-list-builder-all-8-0 | before | 0.017004 | 0.000391 |
| build-list-builder-all-8-0 | after | 0.016513 | 0.001081 |
| build-list-concatenate-8-0 | before | 0.016972 | 0.000448 |
| build-list-concatenate-8-0 | after | 0.016127 | 0.000314 |
| build-list-fold-8-0 | before | 0.017440 | 0.001084 |
| build-list-fold-8-0 | after | 0.016573 | 0.000681 |
| build-bytes-builder-8-0 | before | 0.017434 | 0.000927 |
| build-bytes-builder-8-0 | after | 0.016552 | 0.001490 |
| build-bytes-builder-all-8-0 | before | 0.016576 | 0.000474 |
| build-bytes-builder-all-8-0 | after | 0.016958 | 0.001068 |
| build-bytes-concatenate-8-0 | before | 0.017107 | 0.001045 |
| build-bytes-concatenate-8-0 | after | 0.016272 | 0.000227 |
| patterns-integer-100 | before | 0.015571 | 0.001963 |
| patterns-integer-100 | after | 0.015080 | 0.001011 |
| codegen-let-100 | before | 0.017824 | 0.000357 |
| codegen-let-100 | after | 0.017359 | 0.000772 |
| bridge-shared-8 | before | 0.004782 | 0.000586 |
| bridge-shared-8 | after | 0.004898 | 0.000393 |
| external-tests-normal-1 | before | 0.018704 | 0.000886 |
| external-tests-normal-1 | after | 0.017561 | 0.001031 |
| runtime-fib-short | before | 0.018607 | 0.000552 |
| runtime-fib-short | after | 0.017879 | 0.001688 |
| runtime-loop-short | before | 0.024759 | 0.000500 |
| runtime-loop-short | after | 0.023924 | 0.000705 |
| runtime-list-short | before | 0.030099 | 0.000636 |
| runtime-list-short | after | 0.029897 | 0.000577 |
| runtime-tree-short | before | 0.019224 | 0.000600 |
| runtime-tree-short | after | 0.019191 | 0.000730 |
| runtime-eval-short | before | 0.023199 | 0.000769 |
| runtime-eval-short | after | 0.022091 | 0.001228 |
| runtime-string-short | before | 0.017830 | 0.002937 |
| runtime-string-short | after | 0.016989 | 0.000824 |
| runtime-println-short | before | 0.017870 | 0.000326 |
| runtime-println-short | after | 0.017389 | 0.000370 |
| runtime-lines-short | before | 0.018767 | 0.000970 |
| runtime-lines-short | after | 0.017988 | 0.000438 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.475e-05 | 7.08e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 4e-06 | 5.84e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.9e-05 | 9.58e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5459e-05 | 1.25e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.583e-06 | 4.58e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.8999e-05 | 3.76e-07 |
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
    "after": "1f1f32aeaf1c37dddb106ffcb82551bdfa5b0b90"
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
| functions-main-0-0 | 達成 | -0.0009167079999912175 | 0.002 |
| functions-main-0-1 | 判定不能 | None | 0.002 |
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 達成 | -0.0023360410000066167 | 0.002 |
| functions-main-1000-0 | 達成 | -0.010961250000008249 | 0.003183645900000443 |
| functions-main-1000-1 | 達成 | -0.011504542000011497 | 0.003185270900000603 |
| functions-args-0-0 | 達成 | -0.0006737499999900365 | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | -0.021915832999994223 | 0.004867941700000245 |
| functions-args-1000-1 | 達成 | -0.02259975000001191 | 0.004993412500000716 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 達成 | -0.0010173750000035398 | 0.002 |
| functions-modules-1000-0 | 達成 | -0.004946875999991107 | 0.0026100791999994046 |
| functions-modules-1000-1 | 達成 | -0.003968833999991261 | 0.0025806208999995307 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 達成 | -0.0022928329999984953 | 0.002 |
| higher-0-300 | 達成 | 0.002105667000009248 | 0.0027713915999996175 |
| higher-1-300 | 判定不能 | None | 0.0031498041999995507 |
| classes-300 | 判定不能 | None | 0.003918795799999941 |
| depth-0-8 | 達成 | -0.0014340419999996357 | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 達成 | -0.001937707999999816 | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 達成 | -0.0014412090000064381 | 0.002 |
| interval-range-0 | 判定不能 | None | 0.0021766208999991934 |
| interval-range-64 | 判定不能 | None | 0.002669137499999863 |
| interval-range-256 | 達成 | -0.0036727079999820944 | 0.004022712499998704 |
| interval-http-0 | 達成 | -0.0021406660000025113 | 0.0022364624999994475 |
| interval-http-64 | 達成 | -0.0030162920000122995 | 0.002644750000000329 |
| interval-http-256 | 達成 | -0.003936542000005261 | 0.003513183300000833 |
| interval-width-Integer8-64 | 達成 | -0.0014595840000026783 | 0.002 |
| interval-width-Integer8-256 | 達成 | -0.0007915830000086999 | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 達成 | -0.0011790830000109054 | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 達成 | -0.0009007920000101421 | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | -0.0026512510000031853 | 0.0040540042000003496 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.004005116599999781 |
| property-distinct-24-20-1000-all-ok | 達成 | -0.004396165999992263 | 0.004097237499999551 |
| property-distinct-24-20-1000-always-error | 達成 | -0.005002292000000352 | 0.004073045900000238 |
| property-zero-24-20-1000-all-ok | 達成 | -0.0021320000000031314 | 0.004010750000000485 |
| property-zero-24-20-1000-always-error | 達成 | -0.003913374999996222 | 0.004001212500000406 |
| property-max-24-20-1000-all-ok | 達成 | -0.00519825000000651 | 0.00424396250000001 |
| property-max-24-20-1000-always-error | 達成 | -0.003154748999989465 | 0.004073670799999718 |
| order-string-candidates | 達成 | -0.003779374999993479 | 0.003939170799999658 |
| order-string-all-ok | 判定不能 | None | 0.004125120800000559 |
| order-string-always-error | 達成 | -0.004515957999998932 | 0.004091983300000379 |
| order-map-candidates | 達成 | -0.004866041999989079 | 0.004054716699999972 |
| order-map-all-ok | 達成 | -0.004861915999995858 | 0.004184983300000056 |
| order-map-always-error | 達成 | -0.004441958000001023 | 0.004022358299999951 |
| order-record-candidates | 達成 | -0.005160957999990501 | 0.0041866249999998216 |
| order-record-all-ok | 達成 | -0.003775833000005946 | 0.004002766700000393 |
| order-record-always-error | 達成 | -0.003453292000017427 | 0.004138158400000691 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 達成 | -0.0008450840000051585 | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0024758582999993453 |
| runtime-list-short | 判定不能 | None | 0.0030099124999992456 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002319945800000767 |
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
    "verify": 1.8672190829999948,
    "cli": 5.7116084990000076,
    "warmup": 0.670848749000001,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.9666882500000042,
    "cli": 12.221902291999996,
    "warmup": 1.4028178810000185,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3228667919999992,
    "cli": 9.450958333999992,
    "warmup": 1.3309062480000193,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3783192920000005,
    "cli": 3.6590132080000046,
    "warmup": 0.3681359979999854,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10090516700000762,
    "cli": 0.2962290839999895,
    "warmup": 0.031024666999996953,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03871220799999264,
    "cli": 0.34058154200000956,
    "warmup": 0.0358771260000168,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009573041999999532,
    "cli": 0.20722866699999543,
    "warmup": 0.008953791999985583,
    "probe_warmup": 0.008501833000011061,
    "rss": 0,
    "stages": 0.040522874000018305,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.043332750000004694,
    "cli": 0.347517792000005,
    "warmup": 0.036374332999997705,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18698524900003122
  },
  "runtime": {
    "verify": 0.3460814999999968,
    "cli": 3.00771008199996,
    "warmup": 0.33765887399999883,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
