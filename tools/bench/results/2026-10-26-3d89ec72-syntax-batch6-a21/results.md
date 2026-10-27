# 版どうしの性能比較

候補: `3d89ec72bcf1275f7b0dedc59f41b5313480383b`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013836 | 0.000380 |
| functions-main-0-0 | after | 0.013038 | 0.000258 |
| functions-main-0-1 | before | 0.013588 | 0.000833 |
| functions-main-0-1 | after | 0.013041 | 0.000135 |
| functions-main-64-0 | before | 0.014489 | 0.000608 |
| functions-main-64-0 | after | 0.013352 | 0.000794 |
| functions-main-256-0 | before | 0.016712 | 0.000438 |
| functions-main-256-0 | after | 0.014563 | 0.000180 |
| functions-main-1000-0 | before | 0.031581 | 0.000224 |
| functions-main-1000-0 | after | 0.020133 | 0.000878 |
| functions-main-1000-1 | before | 0.031502 | 0.001008 |
| functions-main-1000-1 | after | 0.020050 | 0.000459 |
| functions-args-0-0 | before | 0.013872 | 0.000285 |
| functions-args-0-0 | after | 0.012788 | 0.000165 |
| functions-args-0-1 | before | 0.013491 | 0.000652 |
| functions-args-0-1 | after | 0.012807 | 0.000214 |
| functions-args-1000-0 | before | 0.048572 | 0.000633 |
| functions-args-1000-0 | after | 0.026324 | 0.000384 |
| functions-args-1000-1 | before | 0.049229 | 0.001096 |
| functions-args-1000-1 | after | 0.026771 | 0.000814 |
| functions-modules-0-0 | before | 0.013847 | 0.001210 |
| functions-modules-0-0 | after | 0.012821 | 0.000185 |
| functions-modules-0-1 | before | 0.013824 | 0.000281 |
| functions-modules-0-1 | after | 0.013080 | 0.000221 |
| functions-modules-1000-0 | before | 0.025790 | 0.000403 |
| functions-modules-1000-0 | after | 0.021567 | 0.000407 |
| functions-modules-1000-1 | before | 0.025688 | 0.000631 |
| functions-modules-1000-1 | after | 0.020985 | 0.000619 |
| existing-fib | before | 0.014419 | 0.000324 |
| existing-fib | after | 0.013958 | 0.000181 |
| existing-loop | before | 0.014552 | 0.000534 |
| existing-loop | after | 0.013967 | 0.000236 |
| existing-string | before | 0.014829 | 0.000693 |
| existing-string | after | 0.013848 | 0.000237 |
| higher-0-0 | before | 0.013869 | 0.000578 |
| higher-0-0 | after | 0.013099 | 0.000272 |
| higher-1-0 | before | 0.014805 | 0.000342 |
| higher-1-0 | after | 0.014063 | 0.000311 |
| classes-0 | before | 0.019787 | 0.001135 |
| classes-0 | after | 0.017406 | 0.000284 |
| higher-0-300 | before | 0.027318 | 0.000625 |
| higher-0-300 | after | 0.028380 | 0.000798 |
| higher-1-300 | before | 0.030309 | 0.001236 |
| higher-1-300 | after | 0.031255 | 0.000942 |
| classes-300 | before | 0.038838 | 0.000450 |
| classes-300 | after | 0.037489 | 0.000396 |
| depth-0-8 | before | 0.015182 | 0.000323 |
| depth-0-8 | after | 0.014569 | 0.000331 |
| depth-1-8 | before | 0.015343 | 0.000994 |
| depth-1-8 | after | 0.014823 | 0.000416 |
| f1-nofail-call | before | 0.014828 | 0.000115 |
| f1-nofail-call | after | 0.014317 | 0.000259 |
| f1-join-effects | before | 0.014626 | 0.000840 |
| f1-join-effects | after | 0.014089 | 0.000241 |
| control-16.3 | before | 0.013781 | 0.000285 |
| control-16.3 | after | 0.013414 | 0.000659 |
| interval-bind-64 | before | 0.013982 | 0.000264 |
| interval-bind-64 | after | 0.013555 | 0.000432 |
| interval-bind-256 | before | 0.014618 | 0.000386 |
| interval-bind-256 | after | 0.013737 | 0.000237 |
| interval-add-64 | before | 0.013824 | 0.000135 |
| interval-add-64 | after | 0.013376 | 0.000883 |
| interval-add-256 | before | 0.015685 | 0.000079 |
| interval-add-256 | after | 0.014716 | 0.001000 |
| interval-flow-64 | before | 0.014797 | 0.000901 |
| interval-flow-64 | after | 0.014280 | 0.000321 |
| interval-flow-256 | before | 0.017601 | 0.000394 |
| interval-flow-256 | after | 0.017002 | 0.000398 |
| interval-range-0 | before | 0.021011 | 0.000336 |
| interval-range-0 | after | 0.018645 | 0.000250 |
| interval-range-64 | before | 0.025317 | 0.000368 |
| interval-range-64 | after | 0.023151 | 0.000567 |
| interval-range-256 | before | 0.038864 | 0.000420 |
| interval-range-256 | after | 0.035919 | 0.000331 |
| interval-http-0 | before | 0.021696 | 0.000463 |
| interval-http-0 | after | 0.019269 | 0.000417 |
| interval-http-64 | before | 0.024465 | 0.000282 |
| interval-http-64 | after | 0.022742 | 0.000354 |
| interval-http-256 | before | 0.032665 | 0.000423 |
| interval-http-256 | after | 0.029544 | 0.000239 |
| interval-width-Integer8-64 | before | 0.014678 | 0.000364 |
| interval-width-Integer8-64 | after | 0.013842 | 0.000334 |
| interval-width-Integer8-256 | before | 0.017684 | 0.000206 |
| interval-width-Integer8-256 | after | 0.017253 | 0.000354 |
| interval-width-Integer16-64 | before | 0.014711 | 0.000729 |
| interval-width-Integer16-64 | after | 0.013998 | 0.000376 |
| interval-width-Integer16-256 | before | 0.017391 | 0.000695 |
| interval-width-Integer16-256 | after | 0.016733 | 0.000531 |
| interval-width-Integer32-64 | before | 0.014748 | 0.000387 |
| interval-width-Integer32-64 | after | 0.013773 | 0.000284 |
| interval-width-Integer32-256 | before | 0.017593 | 0.000726 |
| interval-width-Integer32-256 | after | 0.016846 | 0.000251 |
| interval-width-Integer64-64 | before | 0.014813 | 0.000510 |
| interval-width-Integer64-64 | after | 0.014137 | 0.000160 |
| interval-width-Integer64-256 | before | 0.017929 | 0.000364 |
| interval-width-Integer64-256 | after | 0.017097 | 0.000722 |
| interval-width-UnsignedInteger16-64 | before | 0.014825 | 0.000636 |
| interval-width-UnsignedInteger16-64 | after | 0.013984 | 0.000526 |
| interval-width-UnsignedInteger16-256 | before | 0.017452 | 0.000393 |
| interval-width-UnsignedInteger16-256 | after | 0.016996 | 0.000476 |
| interval-width-UnsignedInteger32-64 | before | 0.014817 | 0.000204 |
| interval-width-UnsignedInteger32-64 | after | 0.014041 | 0.000251 |
| interval-width-UnsignedInteger32-256 | before | 0.017497 | 0.000181 |
| interval-width-UnsignedInteger32-256 | after | 0.016862 | 0.000419 |
| interval-width-UnsignedInteger64-64 | before | 0.014910 | 0.000199 |
| interval-width-UnsignedInteger64-64 | after | 0.014063 | 0.000285 |
| interval-width-UnsignedInteger64-256 | before | 0.017709 | 0.000284 |
| interval-width-UnsignedInteger64-256 | after | 0.017287 | 0.000775 |
| property-seven-24-20-1000-all-ok | before | 0.041460 | 0.000477 |
| property-seven-24-20-1000-all-ok | after | 0.037645 | 0.001009 |
| property-seven-24-20-1000-always-error | before | 0.039332 | 0.000803 |
| property-seven-24-20-1000-always-error | after | 0.035842 | 0.000531 |
| property-distinct-24-20-1000-all-ok | before | 0.039425 | 0.000057 |
| property-distinct-24-20-1000-all-ok | after | 0.035864 | 0.000442 |
| property-distinct-24-20-1000-always-error | before | 0.039362 | 0.000862 |
| property-distinct-24-20-1000-always-error | after | 0.035476 | 0.000633 |
| property-zero-24-20-1000-all-ok | before | 0.039893 | 0.000252 |
| property-zero-24-20-1000-all-ok | after | 0.036550 | 0.001455 |
| property-zero-24-20-1000-always-error | before | 0.039063 | 0.000537 |
| property-zero-24-20-1000-always-error | after | 0.035199 | 0.000250 |
| property-max-24-20-1000-all-ok | before | 0.040362 | 0.000534 |
| property-max-24-20-1000-all-ok | after | 0.037348 | 0.000557 |
| property-max-24-20-1000-always-error | before | 0.038774 | 0.000422 |
| property-max-24-20-1000-always-error | after | 0.035622 | 0.001228 |
| order-string-candidates | before | 0.038670 | 0.000623 |
| order-string-candidates | after | 0.035360 | 0.000477 |
| order-string-all-ok | before | 0.039332 | 0.000607 |
| order-string-all-ok | after | 0.035632 | 0.000489 |
| order-string-always-error | before | 0.038786 | 0.000339 |
| order-string-always-error | after | 0.035557 | 0.000406 |
| order-map-candidates | before | 0.039078 | 0.000512 |
| order-map-candidates | after | 0.035369 | 0.000296 |
| order-map-all-ok | before | 0.039346 | 0.000994 |
| order-map-all-ok | after | 0.035915 | 0.000569 |
| order-map-always-error | before | 0.039115 | 0.001282 |
| order-map-always-error | after | 0.035575 | 0.000437 |
| order-record-candidates | before | 0.039690 | 0.000372 |
| order-record-candidates | after | 0.036135 | 0.000448 |
| order-record-all-ok | before | 0.039639 | 0.000375 |
| order-record-all-ok | after | 0.036469 | 0.000948 |
| order-record-always-error | before | 0.039371 | 0.000244 |
| order-record-always-error | after | 0.036140 | 0.000818 |
| build-string-builder-8-0 | before | 0.016563 | 0.000651 |
| build-string-builder-8-0 | after | 0.015609 | 0.000367 |
| build-string-builder-all-8-0 | before | 0.016514 | 0.003321 |
| build-string-builder-all-8-0 | after | 0.016056 | 0.001004 |
| build-string-concatenate-8-0 | before | 0.016276 | 0.000180 |
| build-string-concatenate-8-0 | after | 0.016365 | 0.000789 |
| build-string-join-8-0 | before | 0.016486 | 0.000344 |
| build-string-join-8-0 | after | 0.015802 | 0.000292 |
| build-list-builder-8-0 | before | 0.016447 | 0.000398 |
| build-list-builder-8-0 | after | 0.015852 | 0.000103 |
| build-list-builder-all-8-0 | before | 0.016611 | 0.000356 |
| build-list-builder-all-8-0 | after | 0.015796 | 0.000403 |
| build-list-concatenate-8-0 | before | 0.016483 | 0.000371 |
| build-list-concatenate-8-0 | after | 0.015829 | 0.000708 |
| build-list-fold-8-0 | before | 0.016777 | 0.000412 |
| build-list-fold-8-0 | after | 0.015856 | 0.000305 |
| build-bytes-builder-8-0 | before | 0.016466 | 0.000720 |
| build-bytes-builder-8-0 | after | 0.015952 | 0.000296 |
| build-bytes-builder-all-8-0 | before | 0.016546 | 0.000917 |
| build-bytes-builder-all-8-0 | after | 0.015864 | 0.000086 |
| build-bytes-concatenate-8-0 | before | 0.016733 | 0.000338 |
| build-bytes-concatenate-8-0 | after | 0.015929 | 0.000197 |
| patterns-integer-100 | before | 0.014746 | 0.000794 |
| patterns-integer-100 | after | 0.014179 | 0.000386 |
| codegen-let-100 | before | 0.017128 | 0.000320 |
| codegen-let-100 | after | 0.016737 | 0.000517 |
| bridge-shared-8 | before | 0.004610 | 0.000384 |
| bridge-shared-8 | after | 0.004705 | 0.000301 |
| external-tests-normal-1 | before | 0.018348 | 0.000673 |
| external-tests-normal-1 | after | 0.017817 | 0.000835 |
| runtime-fib-short | before | 0.018328 | 0.000547 |
| runtime-fib-short | after | 0.017902 | 0.000367 |
| runtime-loop-short | before | 0.024344 | 0.000515 |
| runtime-loop-short | after | 0.023610 | 0.000338 |
| runtime-list-short | before | 0.029889 | 0.000372 |
| runtime-list-short | after | 0.029397 | 0.000366 |
| runtime-tree-short | before | 0.018730 | 0.000514 |
| runtime-tree-short | after | 0.018663 | 0.000271 |
| runtime-eval-short | before | 0.022417 | 0.001581 |
| runtime-eval-short | after | 0.021836 | 0.000540 |
| runtime-string-short | before | 0.017322 | 0.000288 |
| runtime-string-short | after | 0.016757 | 0.000286 |
| runtime-println-short | before | 0.017725 | 0.000346 |
| runtime-println-short | after | 0.016962 | 0.000728 |
| runtime-lines-short | before | 0.017186 | 0.000885 |
| runtime-lines-short | after | 0.016461 | 0.000497 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.3833e-05 | 4.17e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.958e-06 | 4.17e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.7791e-05 | 1.168e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.525e-05 | 1.625e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 2.917e-06 | 8.3e-08 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.85e-05 | 1.542e-06 |
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
    "after": "3d89ec72bcf1275f7b0dedc59f41b5313480383b"
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
| functions-main-0-0 | 達成 | -0.0007979159999962349 | 0.002 |
| functions-main-0-1 | 判定不能 | None | 0.002 |
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 達成 | -0.002149000000002843 | 0.002 |
| functions-main-1000-0 | 達成 | -0.011448541999996564 | 0.0031581041999999117 |
| functions-main-1000-1 | 達成 | -0.011452167000001623 | 0.003150225000000262 |
| functions-args-0-0 | 達成 | -0.0010843750000049113 | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | -0.02224816699998655 | 0.0048572499999991695 |
| functions-args-1000-1 | 達成 | -0.022457707000000937 | 0.004922891600000413 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 達成 | -0.000743249999999307 | 0.002 |
| functions-modules-1000-0 | 達成 | -0.004222583000000668 | 0.002578950000000191 |
| functions-modules-1000-1 | 達成 | -0.004702874999992446 | 0.0025688250000001746 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 達成 | -0.000980749999996533 | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 達成 | -0.000742208000005462 | 0.002 |
| classes-0 | 達成 | -0.0023814169999951673 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0027318375000007222 |
| higher-1-300 | 判定不能 | None | 0.00303088750000029 |
| classes-300 | 達成 | -0.0013490839999974469 | 0.0038838334000004695 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 達成 | -0.0005117919999975129 | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 達成 | -0.0008806670000041095 | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 達成 | -0.002365292000021668 | 0.0021010667000012973 |
| interval-range-64 | 達成 | -0.002166541999997662 | 0.0025317375000000197 |
| interval-range-256 | 達成 | -0.002944834000004448 | 0.0038863792000000787 |
| interval-http-0 | 達成 | -0.0024272079999860807 | 0.002169595799999513 |
| interval-http-64 | 達成 | -0.0017237919999928408 | 0.002446541699998761 |
| interval-http-256 | 達成 | -0.003120416000001569 | 0.0032664666000002287 |
| interval-width-Integer8-64 | 達成 | -0.0008361250000064047 | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 達成 | -0.0009746249999977863 | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 達成 | -0.0006768749999963575 | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 達成 | -0.0007757490000130929 | 0.002 |
| interval-width-UnsignedInteger32-256 | 達成 | -0.0006352500000019745 | 0.002 |
| interval-width-UnsignedInteger64-64 | 達成 | -0.0008470419999895284 | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | -0.0038147499999894308 | 0.004145975000000135 |
| property-seven-24-20-1000-always-error | 達成 | -0.003489541999996959 | 0.003933187500000201 |
| property-distinct-24-20-1000-all-ok | 達成 | -0.003560583999998812 | 0.003942462499999522 |
| property-distinct-24-20-1000-always-error | 達成 | -0.0038852910000031216 | 0.003936154100000522 |
| property-zero-24-20-1000-all-ok | 達成 | -0.0033427079999910347 | 0.003989270799999645 |
| property-zero-24-20-1000-always-error | 達成 | -0.0038640009999966196 | 0.003906316699999479 |
| property-max-24-20-1000-all-ok | 達成 | -0.0030146250000058217 | 0.004036245800000416 |
| property-max-24-20-1000-always-error | 達成 | -0.00315158299999041 | 0.0038773832999993377 |
| order-string-candidates | 達成 | -0.0033105830000010883 | 0.003867016600000284 |
| order-string-all-ok | 達成 | -0.0037003750000081936 | 0.003933241700001133 |
| order-string-always-error | 達成 | -0.003229708000006326 | 0.003878645800000413 |
| order-map-candidates | 達成 | -0.0037090000000006285 | 0.0039078291999999236 |
| order-map-all-ok | 達成 | -0.0034307089999856544 | 0.003934612499999446 |
| order-map-always-error | 達成 | -0.0035402919999825144 | 0.003911504199999172 |
| order-record-candidates | 達成 | -0.0035549579999951675 | 0.003969037500000639 |
| order-record-all-ok | 達成 | -0.0031702080000002297 | 0.003963899999999398 |
| order-record-always-error | 達成 | -0.0032307090000074368 | 0.0039370542000000345 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 達成 | -0.0006841260000101101 | 0.002 |
| build-list-builder-8-0 | 達成 | -0.0005952920000140693 | 0.002 |
| build-list-builder-all-8-0 | 達成 | -0.0008148330000068427 | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 達成 | -0.0009207079999953294 | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 達成 | -0.000804041999998617 | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0024344499999997995 |
| runtime-list-short | 判定不能 | None | 0.002988870800000143 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022417416999999775 |
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
    "verify": 1.8307611669999915,
    "cli": 5.596993620999996,
    "warmup": 0.6604787110000103,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.8804063329999963,
    "cli": 11.945130252000041,
    "warmup": 1.380800583000024,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.306465375000002,
    "cli": 9.215732248000009,
    "warmup": 1.290592036000021,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3651589580000092,
    "cli": 3.5536862059999947,
    "warmup": 0.36117962700004114,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09976533300000767,
    "cli": 0.2826247910000035,
    "warmup": 0.029987208000008536,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03513316700001212,
    "cli": 0.3287417090000133,
    "warmup": 0.03429433399999482,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009486125000009338,
    "cli": 0.20832237500000872,
    "warmup": 0.00890600100001393,
    "probe_warmup": 0.008421250999987251,
    "rss": 0,
    "stages": 0.03961750099999506,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04181866700000114,
    "cli": 0.3423215830000004,
    "warmup": 0.035486957999992796,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18073629200002017
  },
  "runtime": {
    "verify": 0.33542087499999695,
    "cli": 2.9265969599999835,
    "warmup": 0.32972004100000163,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
