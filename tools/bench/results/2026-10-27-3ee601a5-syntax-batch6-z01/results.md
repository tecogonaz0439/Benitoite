# 版どうしの性能比較

候補: `3ee601a55e2872fa6a8bed5920ddf7e7ba76950f`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013990 | 0.000182 |
| functions-main-0-0 | after | 0.013016 | 0.000146 |
| functions-main-0-1 | before | 0.013455 | 0.000417 |
| functions-main-0-1 | after | 0.012970 | 0.000560 |
| functions-main-64-0 | before | 0.014254 | 0.001445 |
| functions-main-64-0 | after | 0.013408 | 0.000288 |
| functions-main-256-0 | before | 0.016789 | 0.001049 |
| functions-main-256-0 | after | 0.014895 | 0.000235 |
| functions-main-1000-0 | before | 0.031760 | 0.000264 |
| functions-main-1000-0 | after | 0.020661 | 0.000996 |
| functions-main-1000-1 | before | 0.031728 | 0.000429 |
| functions-main-1000-1 | after | 0.020921 | 0.001032 |
| functions-args-0-0 | before | 0.013660 | 0.000463 |
| functions-args-0-0 | after | 0.013193 | 0.000307 |
| functions-args-0-1 | before | 0.013700 | 0.000538 |
| functions-args-0-1 | after | 0.013138 | 0.000358 |
| functions-args-1000-0 | before | 0.048989 | 0.001146 |
| functions-args-1000-0 | after | 0.026925 | 0.000360 |
| functions-args-1000-1 | before | 0.048874 | 0.000279 |
| functions-args-1000-1 | after | 0.027081 | 0.000793 |
| functions-modules-0-0 | before | 0.013741 | 0.001432 |
| functions-modules-0-0 | after | 0.013063 | 0.000263 |
| functions-modules-0-1 | before | 0.013588 | 0.000737 |
| functions-modules-0-1 | after | 0.013091 | 0.000443 |
| functions-modules-1000-0 | before | 0.025643 | 0.000587 |
| functions-modules-1000-0 | after | 0.021068 | 0.001337 |
| functions-modules-1000-1 | before | 0.025783 | 0.000573 |
| functions-modules-1000-1 | after | 0.021131 | 0.001112 |
| existing-fib | before | 0.014327 | 0.001232 |
| existing-fib | after | 0.013330 | 0.000336 |
| existing-loop | before | 0.014274 | 0.001155 |
| existing-loop | after | 0.013804 | 0.000302 |
| existing-string | before | 0.014274 | 0.001482 |
| existing-string | after | 0.014007 | 0.000134 |
| higher-0-0 | before | 0.014037 | 0.001225 |
| higher-0-0 | after | 0.013214 | 0.000556 |
| higher-1-0 | before | 0.014836 | 0.000867 |
| higher-1-0 | after | 0.013782 | 0.000606 |
| classes-0 | before | 0.019938 | 0.000354 |
| classes-0 | after | 0.017796 | 0.000352 |
| higher-0-300 | before | 0.026856 | 0.000618 |
| higher-0-300 | after | 0.028776 | 0.001731 |
| higher-1-300 | before | 0.030075 | 0.000123 |
| higher-1-300 | after | 0.031770 | 0.001393 |
| classes-300 | before | 0.039343 | 0.001092 |
| classes-300 | after | 0.037165 | 0.000583 |
| depth-0-8 | before | 0.015172 | 0.000843 |
| depth-0-8 | after | 0.014676 | 0.000368 |
| depth-1-8 | before | 0.015535 | 0.001302 |
| depth-1-8 | after | 0.014537 | 0.000180 |
| f1-nofail-call | before | 0.014781 | 0.000931 |
| f1-nofail-call | after | 0.013847 | 0.000306 |
| f1-join-effects | before | 0.014761 | 0.000854 |
| f1-join-effects | after | 0.014435 | 0.000991 |
| control-16.3 | before | 0.013720 | 0.000814 |
| control-16.3 | after | 0.013099 | 0.000305 |
| interval-bind-64 | before | 0.013860 | 0.000702 |
| interval-bind-64 | after | 0.013142 | 0.000417 |
| interval-bind-256 | before | 0.014523 | 0.001553 |
| interval-bind-256 | after | 0.013703 | 0.000285 |
| interval-add-64 | before | 0.013830 | 0.001350 |
| interval-add-64 | after | 0.013268 | 0.000213 |
| interval-add-256 | before | 0.015437 | 0.001014 |
| interval-add-256 | after | 0.015016 | 0.000365 |
| interval-flow-64 | before | 0.014755 | 0.001045 |
| interval-flow-64 | after | 0.013747 | 0.000575 |
| interval-flow-256 | before | 0.017327 | 0.000445 |
| interval-flow-256 | after | 0.016709 | 0.000311 |
| interval-range-0 | before | 0.020941 | 0.000501 |
| interval-range-0 | after | 0.018810 | 0.000938 |
| interval-range-64 | before | 0.025415 | 0.000604 |
| interval-range-64 | after | 0.023597 | 0.000802 |
| interval-range-256 | before | 0.039847 | 0.000886 |
| interval-range-256 | after | 0.036118 | 0.000653 |
| interval-http-0 | before | 0.021528 | 0.000348 |
| interval-http-0 | after | 0.019856 | 0.000931 |
| interval-http-64 | before | 0.024635 | 0.000327 |
| interval-http-64 | after | 0.022562 | 0.001208 |
| interval-http-256 | before | 0.033143 | 0.000369 |
| interval-http-256 | after | 0.031102 | 0.001343 |
| interval-width-Integer8-64 | before | 0.015066 | 0.001071 |
| interval-width-Integer8-64 | after | 0.014315 | 0.000388 |
| interval-width-Integer8-256 | before | 0.017969 | 0.000183 |
| interval-width-Integer8-256 | after | 0.017361 | 0.000675 |
| interval-width-Integer16-64 | before | 0.014826 | 0.001056 |
| interval-width-Integer16-64 | after | 0.014236 | 0.000350 |
| interval-width-Integer16-256 | before | 0.017672 | 0.000391 |
| interval-width-Integer16-256 | after | 0.017138 | 0.000616 |
| interval-width-Integer32-64 | before | 0.014887 | 0.000934 |
| interval-width-Integer32-64 | after | 0.014157 | 0.000751 |
| interval-width-Integer32-256 | before | 0.018044 | 0.000449 |
| interval-width-Integer32-256 | after | 0.017543 | 0.000366 |
| interval-width-Integer64-64 | before | 0.015178 | 0.001609 |
| interval-width-Integer64-64 | after | 0.014248 | 0.000322 |
| interval-width-Integer64-256 | before | 0.018001 | 0.000336 |
| interval-width-Integer64-256 | after | 0.017249 | 0.000670 |
| interval-width-UnsignedInteger16-64 | before | 0.014778 | 0.001122 |
| interval-width-UnsignedInteger16-64 | after | 0.014379 | 0.000229 |
| interval-width-UnsignedInteger16-256 | before | 0.017363 | 0.000281 |
| interval-width-UnsignedInteger16-256 | after | 0.016891 | 0.000484 |
| interval-width-UnsignedInteger32-64 | before | 0.015677 | 0.001092 |
| interval-width-UnsignedInteger32-64 | after | 0.015282 | 0.000958 |
| interval-width-UnsignedInteger32-256 | before | 0.017346 | 0.000775 |
| interval-width-UnsignedInteger32-256 | after | 0.016930 | 0.000624 |
| interval-width-UnsignedInteger64-64 | before | 0.014456 | 0.001240 |
| interval-width-UnsignedInteger64-64 | after | 0.013829 | 0.000362 |
| interval-width-UnsignedInteger64-256 | before | 0.017454 | 0.000446 |
| interval-width-UnsignedInteger64-256 | after | 0.016535 | 0.000418 |
| property-seven-24-20-1000-all-ok | before | 0.040506 | 0.001432 |
| property-seven-24-20-1000-all-ok | after | 0.037232 | 0.000493 |
| property-seven-24-20-1000-always-error | before | 0.039271 | 0.002556 |
| property-seven-24-20-1000-always-error | after | 0.036026 | 0.000614 |
| property-distinct-24-20-1000-all-ok | before | 0.040076 | 0.002588 |
| property-distinct-24-20-1000-all-ok | after | 0.036882 | 0.000489 |
| property-distinct-24-20-1000-always-error | before | 0.039514 | 0.001677 |
| property-distinct-24-20-1000-always-error | after | 0.036344 | 0.000243 |
| property-zero-24-20-1000-all-ok | before | 0.041830 | 0.001262 |
| property-zero-24-20-1000-all-ok | after | 0.037485 | 0.001730 |
| property-zero-24-20-1000-always-error | before | 0.039005 | 0.001571 |
| property-zero-24-20-1000-always-error | after | 0.036032 | 0.000579 |
| property-max-24-20-1000-all-ok | before | 0.040082 | 0.002428 |
| property-max-24-20-1000-all-ok | after | 0.037195 | 0.000619 |
| property-max-24-20-1000-always-error | before | 0.039563 | 0.000968 |
| property-max-24-20-1000-always-error | after | 0.035604 | 0.000567 |
| order-string-candidates | before | 0.038672 | 0.001519 |
| order-string-candidates | after | 0.035090 | 0.000212 |
| order-string-all-ok | before | 0.039579 | 0.001458 |
| order-string-all-ok | after | 0.035965 | 0.000355 |
| order-string-always-error | before | 0.038859 | 0.001267 |
| order-string-always-error | after | 0.035545 | 0.000432 |
| order-map-candidates | before | 0.039466 | 0.001512 |
| order-map-candidates | after | 0.036419 | 0.000876 |
| order-map-all-ok | before | 0.039518 | 0.001932 |
| order-map-all-ok | after | 0.035931 | 0.000403 |
| order-map-always-error | before | 0.039733 | 0.002001 |
| order-map-always-error | after | 0.035755 | 0.000277 |
| order-record-candidates | before | 0.039488 | 0.001409 |
| order-record-candidates | after | 0.036006 | 0.000451 |
| order-record-all-ok | before | 0.039815 | 0.001034 |
| order-record-all-ok | after | 0.036488 | 0.000143 |
| order-record-always-error | before | 0.039473 | 0.001872 |
| order-record-always-error | after | 0.036268 | 0.001229 |
| build-string-builder-8-0 | before | 0.016834 | 0.000623 |
| build-string-builder-8-0 | after | 0.016129 | 0.000497 |
| build-string-builder-all-8-0 | before | 0.016424 | 0.000465 |
| build-string-builder-all-8-0 | after | 0.015679 | 0.000390 |
| build-string-concatenate-8-0 | before | 0.016240 | 0.000628 |
| build-string-concatenate-8-0 | after | 0.015575 | 0.000424 |
| build-string-join-8-0 | before | 0.016736 | 0.000678 |
| build-string-join-8-0 | after | 0.015736 | 0.000205 |
| build-list-builder-8-0 | before | 0.016542 | 0.000335 |
| build-list-builder-8-0 | after | 0.015991 | 0.000283 |
| build-list-builder-all-8-0 | before | 0.016617 | 0.000323 |
| build-list-builder-all-8-0 | after | 0.015874 | 0.000312 |
| build-list-concatenate-8-0 | before | 0.016674 | 0.000632 |
| build-list-concatenate-8-0 | after | 0.016637 | 0.001164 |
| build-list-fold-8-0 | before | 0.016566 | 0.000371 |
| build-list-fold-8-0 | after | 0.015757 | 0.000755 |
| build-bytes-builder-8-0 | before | 0.016747 | 0.000514 |
| build-bytes-builder-8-0 | after | 0.015717 | 0.000293 |
| build-bytes-builder-all-8-0 | before | 0.016442 | 0.000388 |
| build-bytes-builder-all-8-0 | after | 0.016156 | 0.000673 |
| build-bytes-concatenate-8-0 | before | 0.016792 | 0.000369 |
| build-bytes-concatenate-8-0 | after | 0.016249 | 0.000246 |
| patterns-integer-100 | before | 0.015384 | 0.001078 |
| patterns-integer-100 | after | 0.014398 | 0.000405 |
| codegen-let-100 | before | 0.017309 | 0.000252 |
| codegen-let-100 | after | 0.017054 | 0.000203 |
| bridge-shared-8 | before | 0.004797 | 0.000450 |
| bridge-shared-8 | after | 0.005140 | 0.000862 |
| external-tests-normal-1 | before | 0.019182 | 0.001205 |
| external-tests-normal-1 | after | 0.019263 | 0.001843 |
| runtime-fib-short | before | 0.018621 | 0.000159 |
| runtime-fib-short | after | 0.018094 | 0.000682 |
| runtime-loop-short | before | 0.024274 | 0.000158 |
| runtime-loop-short | after | 0.023559 | 0.001444 |
| runtime-list-short | before | 0.029600 | 0.000384 |
| runtime-list-short | after | 0.029649 | 0.000759 |
| runtime-tree-short | before | 0.018958 | 0.000706 |
| runtime-tree-short | after | 0.018384 | 0.001201 |
| runtime-eval-short | before | 0.022650 | 0.000429 |
| runtime-eval-short | after | 0.021826 | 0.000548 |
| runtime-string-short | before | 0.017560 | 0.000469 |
| runtime-string-short | after | 0.016716 | 0.000326 |
| runtime-println-short | before | 0.017473 | 0.000410 |
| runtime-println-short | after | 0.017260 | 0.001634 |
| runtime-lines-short | before | 0.017630 | 0.000856 |
| runtime-lines-short | after | 0.016988 | 0.001312 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.5166e-05 | 3.33e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.792e-06 | 1.66e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.9082e-05 | 7.5e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.8125e-05 | 1.834e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.584e-06 | 5.41e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 2.1833e-05 | 2.251e-06 |
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
    "after": "3ee601a55e2872fa6a8bed5920ddf7e7ba76950f"
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
| functions-main-0-0 | 達成 | -0.0009737919999963651 | 0.002 |
| functions-main-0-1 | 判定不能 | None | 0.002 |
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 達成 | -0.0018944170000025906 | 0.002 |
| functions-main-1000-0 | 達成 | -0.011099041999997894 | 0.003175962500000651 |
| functions-main-1000-1 | 達成 | -0.010807125999988898 | 0.0031727916999997777 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | -0.022063791000022093 | 0.0048988583000010525 |
| functions-args-1000-1 | 達成 | -0.021793082000002073 | 0.004887441600000386 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 達成 | -0.004574874999988765 | 0.0025642791999999307 |
| functions-modules-1000-1 | 達成 | -0.004652250000006575 | 0.0025783375000003163 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 達成 | -0.0021420419999884643 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0026856499999993845 |
| higher-1-300 | 達成 | 0.0016949159999910535 | 0.0030075209000003157 |
| classes-300 | 達成 | -0.002178250000000048 | 0.0039342750000002985 |
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
| interval-range-0 | 達成 | -0.002130791999988446 | 0.002094074999999407 |
| interval-range-64 | 達成 | -0.0018178339999934678 | 0.002541533399998741 |
| interval-range-256 | 達成 | -0.0037288749999930815 | 0.003984695799999827 |
| interval-http-0 | 達成 | -0.0016721260000167604 | 0.0021528334000009866 |
| interval-http-64 | 達成 | -0.002073291999991511 | 0.002463495799999294 |
| interval-http-256 | 達成 | -0.002040916999987985 | 0.003314312499999517 |
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
| interval-width-UnsignedInteger64-256 | 達成 | -0.0009189990000066928 | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | -0.003273749000001658 | 0.004050604100000044 |
| property-seven-24-20-1000-always-error | 達成 | -0.00324416800000904 | 0.003927058400000761 |
| property-distinct-24-20-1000-all-ok | 達成 | -0.0031942909999997937 | 0.004007587499999943 |
| property-distinct-24-20-1000-always-error | 達成 | -0.0031696249999839665 | 0.003951366599999062 |
| property-zero-24-20-1000-all-ok | 達成 | -0.00434483399999408 | 0.004182966700000179 |
| property-zero-24-20-1000-always-error | 達成 | -0.0029731249999969123 | 0.0039004915999996115 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.004008154199999581 |
| property-max-24-20-1000-always-error | 達成 | -0.003958750000009559 | 0.00395625830000057 |
| order-string-candidates | 達成 | -0.00358170900000232 | 0.0038671917000002057 |
| order-string-all-ok | 達成 | -0.0036144159999906833 | 0.0039579207999992155 |
| order-string-always-error | 達成 | -0.0033134579999938296 | 0.0038858625000003145 |
| order-map-candidates | 達成 | -0.0030469579999987673 | 0.003946575000000507 |
| order-map-all-ok | 達成 | -0.0035876669999908017 | 0.003951849999999979 |
| order-map-always-error | 達成 | -0.003978041999985749 | 0.003973254199999588 |
| order-record-candidates | 達成 | -0.003481167000003893 | 0.003948754200000337 |
| order-record-all-ok | 達成 | -0.003327292000008697 | 0.003981533400001069 |
| order-record-always-error | 達成 | -0.0032051660000007587 | 0.003947337500000004 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 達成 | -0.0010006250000031969 | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 達成 | -0.0007429590000072039 | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 達成 | -0.0010297509999901422 | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0024274457999993618 |
| runtime-list-short | 判定不能 | None | 0.0029600333000004754 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022650124999998413 |
| runtime-string-short | 達成 | -0.0008432079999920461 | 0.002 |
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
    "verify": 1.8537326669999885,
    "cli": 5.623081541000019,
    "warmup": 0.6655716660000479,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.896683374999995,
    "cli": 12.009272834000072,
    "warmup": 1.3876471239999546,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3080722500000093,
    "cli": 9.287813706999955,
    "warmup": 1.2973223760000678,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.36564495900000793,
    "cli": 3.569474248999981,
    "warmup": 0.3577668760000279,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10145633300000156,
    "cli": 0.2863474579999945,
    "warmup": 0.029371916999991754,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.04127100000000894,
    "cli": 0.33475316699998814,
    "warmup": 0.03446970899999258,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009749999999996817,
    "cli": 0.20961262499999123,
    "warmup": 0.008935417000003554,
    "probe_warmup": 0.008796582999991642,
    "rss": 0,
    "stages": 0.041573085000010224,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.041710250000008386,
    "cli": 0.36911270800001716,
    "warmup": 0.04126308300000403,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18742683199997145
  },
  "runtime": {
    "verify": 0.3379226250000045,
    "cli": 2.9492876660000036,
    "warmup": 0.3345461649999919,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
