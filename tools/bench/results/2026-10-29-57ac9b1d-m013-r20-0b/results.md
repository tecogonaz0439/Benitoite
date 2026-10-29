# 版どうしの性能比較

候補: `57ac9b1d7a1dc396c0beca4f3be87daa0043a14f`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.012950 | 0.000427 |
| functions-main-0-0 | after | 0.013106 | 0.000214 |
| functions-main-0-1 | before | 0.013198 | 0.000656 |
| functions-main-0-1 | after | 0.013226 | 0.000212 |
| functions-main-64-0 | before | 0.013721 | 0.000418 |
| functions-main-64-0 | after | 0.014299 | 0.000258 |
| functions-main-256-0 | before | 0.015326 | 0.001242 |
| functions-main-256-0 | after | 0.015422 | 0.000520 |
| functions-main-1000-0 | before | 0.020580 | 0.000158 |
| functions-main-1000-0 | after | 0.021550 | 0.000344 |
| functions-main-1000-1 | before | 0.020774 | 0.000381 |
| functions-main-1000-1 | after | 0.021593 | 0.001139 |
| functions-args-0-0 | before | 0.013353 | 0.000862 |
| functions-args-0-0 | after | 0.013186 | 0.000445 |
| functions-args-0-1 | before | 0.013213 | 0.000466 |
| functions-args-0-1 | after | 0.013290 | 0.000320 |
| functions-args-1000-0 | before | 0.026357 | 0.000322 |
| functions-args-1000-0 | after | 0.027549 | 0.000615 |
| functions-args-1000-1 | before | 0.027095 | 0.000953 |
| functions-args-1000-1 | after | 0.027497 | 0.000761 |
| functions-modules-0-0 | before | 0.013299 | 0.000347 |
| functions-modules-0-0 | after | 0.013361 | 0.000384 |
| functions-modules-0-1 | before | 0.013084 | 0.000718 |
| functions-modules-0-1 | after | 0.013360 | 0.000263 |
| functions-modules-1000-0 | before | 0.020494 | 0.000633 |
| functions-modules-1000-0 | after | 0.020989 | 0.000074 |
| functions-modules-1000-1 | before | 0.020774 | 0.000385 |
| functions-modules-1000-1 | after | 0.021051 | 0.000707 |
| existing-fib | before | 0.013838 | 0.000743 |
| existing-fib | after | 0.013771 | 0.000672 |
| existing-loop | before | 0.013841 | 0.000392 |
| existing-loop | after | 0.013920 | 0.000339 |
| existing-string | before | 0.013661 | 0.000304 |
| existing-string | after | 0.013927 | 0.000224 |
| higher-0-0 | before | 0.013164 | 0.000353 |
| higher-0-0 | after | 0.013171 | 0.000147 |
| higher-1-0 | before | 0.014220 | 0.000190 |
| higher-1-0 | after | 0.014362 | 0.000230 |
| classes-0 | before | 0.017837 | 0.000414 |
| classes-0 | after | 0.018278 | 0.000208 |
| higher-0-300 | before | 0.027996 | 0.000717 |
| higher-0-300 | after | 0.029003 | 0.000507 |
| higher-1-300 | before | 0.030857 | 0.000724 |
| higher-1-300 | after | 0.032001 | 0.000308 |
| classes-300 | before | 0.037014 | 0.000607 |
| classes-300 | after | 0.038346 | 0.000528 |
| depth-0-8 | before | 0.015130 | 0.000639 |
| depth-0-8 | after | 0.015172 | 0.000275 |
| depth-1-8 | before | 0.015171 | 0.000474 |
| depth-1-8 | after | 0.015451 | 0.000336 |
| f1-nofail-call | before | 0.014342 | 0.000283 |
| f1-nofail-call | after | 0.014701 | 0.000169 |
| f1-join-effects | before | 0.014254 | 0.000147 |
| f1-join-effects | after | 0.014723 | 0.000171 |
| control-16.3 | before | 0.013381 | 0.000534 |
| control-16.3 | after | 0.013628 | 0.000312 |
| interval-bind-64 | before | 0.013468 | 0.000198 |
| interval-bind-64 | after | 0.013754 | 0.000170 |
| interval-bind-256 | before | 0.013999 | 0.000559 |
| interval-bind-256 | after | 0.014282 | 0.000295 |
| interval-add-64 | before | 0.013776 | 0.000321 |
| interval-add-64 | after | 0.014077 | 0.000434 |
| interval-add-256 | before | 0.015060 | 0.000121 |
| interval-add-256 | after | 0.015148 | 0.000127 |
| interval-flow-64 | before | 0.014230 | 0.000342 |
| interval-flow-64 | after | 0.014412 | 0.000199 |
| interval-flow-256 | before | 0.017182 | 0.000431 |
| interval-flow-256 | after | 0.017316 | 0.000331 |
| interval-range-0 | before | 0.018475 | 0.000180 |
| interval-range-0 | after | 0.019183 | 0.000629 |
| interval-range-64 | before | 0.023105 | 0.001074 |
| interval-range-64 | after | 0.023618 | 0.000239 |
| interval-range-256 | before | 0.035977 | 0.001103 |
| interval-range-256 | after | 0.037114 | 0.000939 |
| interval-http-0 | before | 0.019205 | 0.000605 |
| interval-http-0 | after | 0.021660 | 0.000553 |
| interval-http-64 | before | 0.022648 | 0.001005 |
| interval-http-64 | after | 0.024801 | 0.000619 |
| interval-http-256 | before | 0.029789 | 0.000102 |
| interval-http-256 | after | 0.032753 | 0.000775 |
| interval-width-Integer8-64 | before | 0.014205 | 0.000349 |
| interval-width-Integer8-64 | after | 0.014294 | 0.000328 |
| interval-width-Integer8-256 | before | 0.016996 | 0.000696 |
| interval-width-Integer8-256 | after | 0.017206 | 0.000323 |
| interval-width-Integer16-64 | before | 0.014187 | 0.000521 |
| interval-width-Integer16-64 | after | 0.014274 | 0.000762 |
| interval-width-Integer16-256 | before | 0.016762 | 0.000126 |
| interval-width-Integer16-256 | after | 0.017310 | 0.000386 |
| interval-width-Integer32-64 | before | 0.014167 | 0.000300 |
| interval-width-Integer32-64 | after | 0.014491 | 0.000303 |
| interval-width-Integer32-256 | before | 0.016491 | 0.000187 |
| interval-width-Integer32-256 | after | 0.017183 | 0.000624 |
| interval-width-Integer64-64 | before | 0.013934 | 0.000469 |
| interval-width-Integer64-64 | after | 0.014384 | 0.000572 |
| interval-width-Integer64-256 | before | 0.016558 | 0.000280 |
| interval-width-Integer64-256 | after | 0.017014 | 0.000447 |
| interval-width-UnsignedInteger16-64 | before | 0.013848 | 0.000741 |
| interval-width-UnsignedInteger16-64 | after | 0.014084 | 0.000178 |
| interval-width-UnsignedInteger16-256 | before | 0.016608 | 0.000516 |
| interval-width-UnsignedInteger16-256 | after | 0.016895 | 0.000123 |
| interval-width-UnsignedInteger32-64 | before | 0.013883 | 0.000902 |
| interval-width-UnsignedInteger32-64 | after | 0.014647 | 0.000635 |
| interval-width-UnsignedInteger32-256 | before | 0.016528 | 0.000119 |
| interval-width-UnsignedInteger32-256 | after | 0.016858 | 0.000170 |
| interval-width-UnsignedInteger64-64 | before | 0.013937 | 0.002420 |
| interval-width-UnsignedInteger64-64 | after | 0.013976 | 0.000631 |
| interval-width-UnsignedInteger64-256 | before | 0.016856 | 0.000779 |
| interval-width-UnsignedInteger64-256 | after | 0.017192 | 0.000853 |
| property-seven-24-20-1000-all-ok | before | 0.036892 | 0.000852 |
| property-seven-24-20-1000-all-ok | after | 0.038471 | 0.000447 |
| property-seven-24-20-1000-always-error | before | 0.035774 | 0.000555 |
| property-seven-24-20-1000-always-error | after | 0.036632 | 0.000908 |
| property-distinct-24-20-1000-all-ok | before | 0.035975 | 0.000351 |
| property-distinct-24-20-1000-all-ok | after | 0.036888 | 0.000514 |
| property-distinct-24-20-1000-always-error | before | 0.035580 | 0.000755 |
| property-distinct-24-20-1000-always-error | after | 0.036438 | 0.000328 |
| property-zero-24-20-1000-all-ok | before | 0.036386 | 0.000464 |
| property-zero-24-20-1000-all-ok | after | 0.037773 | 0.000749 |
| property-zero-24-20-1000-always-error | before | 0.035325 | 0.000568 |
| property-zero-24-20-1000-always-error | after | 0.036639 | 0.000556 |
| property-max-24-20-1000-all-ok | before | 0.036732 | 0.000388 |
| property-max-24-20-1000-all-ok | after | 0.037767 | 0.000431 |
| property-max-24-20-1000-always-error | before | 0.035429 | 0.000522 |
| property-max-24-20-1000-always-error | after | 0.036667 | 0.000702 |
| order-string-candidates | before | 0.035882 | 0.000850 |
| order-string-candidates | after | 0.035993 | 0.000407 |
| order-string-all-ok | before | 0.035465 | 0.000351 |
| order-string-all-ok | after | 0.036975 | 0.000294 |
| order-string-always-error | before | 0.035086 | 0.001464 |
| order-string-always-error | after | 0.036209 | 0.000629 |
| order-map-candidates | before | 0.035848 | 0.000571 |
| order-map-candidates | after | 0.036619 | 0.000155 |
| order-map-all-ok | before | 0.035638 | 0.000404 |
| order-map-all-ok | after | 0.037021 | 0.000603 |
| order-map-always-error | before | 0.035866 | 0.000329 |
| order-map-always-error | after | 0.036759 | 0.000347 |
| order-record-candidates | before | 0.036166 | 0.000556 |
| order-record-candidates | after | 0.037424 | 0.000437 |
| order-record-all-ok | before | 0.036640 | 0.000561 |
| order-record-all-ok | after | 0.037198 | 0.000219 |
| order-record-always-error | before | 0.036468 | 0.001213 |
| order-record-always-error | after | 0.037068 | 0.000727 |
| build-string-builder-8-0 | before | 0.015882 | 0.000568 |
| build-string-builder-8-0 | after | 0.016367 | 0.001072 |
| build-string-builder-all-8-0 | before | 0.016142 | 0.001012 |
| build-string-builder-all-8-0 | after | 0.016134 | 0.000129 |
| build-string-concatenate-8-0 | before | 0.015949 | 0.000725 |
| build-string-concatenate-8-0 | after | 0.016011 | 0.000853 |
| build-string-join-8-0 | before | 0.015932 | 0.000480 |
| build-string-join-8-0 | after | 0.016203 | 0.000592 |
| build-list-builder-8-0 | before | 0.015955 | 0.000377 |
| build-list-builder-8-0 | after | 0.016433 | 0.000974 |
| build-list-builder-all-8-0 | before | 0.016050 | 0.000283 |
| build-list-builder-all-8-0 | after | 0.016180 | 0.001080 |
| build-list-concatenate-8-0 | before | 0.016045 | 0.000517 |
| build-list-concatenate-8-0 | after | 0.016195 | 0.001354 |
| build-list-fold-8-0 | before | 0.016215 | 0.000289 |
| build-list-fold-8-0 | after | 0.016349 | 0.000237 |
| build-bytes-builder-8-0 | before | 0.016011 | 0.000286 |
| build-bytes-builder-8-0 | after | 0.015909 | 0.000117 |
| build-bytes-builder-all-8-0 | before | 0.016018 | 0.000517 |
| build-bytes-builder-all-8-0 | after | 0.016406 | 0.000743 |
| build-bytes-concatenate-8-0 | before | 0.016071 | 0.000121 |
| build-bytes-concatenate-8-0 | after | 0.016355 | 0.001310 |
| patterns-integer-100 | before | 0.014499 | 0.000633 |
| patterns-integer-100 | after | 0.014390 | 0.000250 |
| codegen-let-100 | before | 0.016812 | 0.000320 |
| codegen-let-100 | after | 0.017331 | 0.000995 |
| bridge-shared-8 | before | 0.004771 | 0.000098 |
| bridge-shared-8 | after | 0.004459 | 0.000435 |
| external-tests-normal-1 | before | 0.017952 | 0.000338 |
| external-tests-normal-1 | after | 0.018043 | 0.001501 |
| runtime-fib-short | before | 0.017715 | 0.000145 |
| runtime-fib-short | after | 0.018393 | 0.000526 |
| runtime-loop-short | before | 0.023782 | 0.000291 |
| runtime-loop-short | after | 0.023913 | 0.000623 |
| runtime-list-short | before | 0.029360 | 0.001104 |
| runtime-list-short | after | 0.029877 | 0.000880 |
| runtime-tree-short | before | 0.018257 | 0.000284 |
| runtime-tree-short | after | 0.018831 | 0.000467 |
| runtime-eval-short | before | 0.021988 | 0.000427 |
| runtime-eval-short | after | 0.022335 | 0.000275 |
| runtime-string-short | before | 0.016833 | 0.000903 |
| runtime-string-short | after | 0.017449 | 0.000321 |
| runtime-println-short | before | 0.016983 | 0.000331 |
| runtime-println-short | after | 0.017695 | 0.001056 |
| runtime-lines-short | before | 0.016825 | 0.000256 |
| runtime-lines-short | after | 0.017111 | 0.000936 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.7792e-05 | 1.375e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.375e-06 | 2.5e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1292e-05 | 1.625e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4375e-05 | 1e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.417e-06 | 5.83e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7542e-05 | 1.333e-06 |
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
| functions-main-1000-0 | 達成 | 0.000969458000014356 | 0.0020580291999991117 |
| functions-main-1000-1 | 判定不能 | None | 0.0020773583000007535 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | 0.0011921239999992395 | 0.002635658399999841 |
| functions-args-1000-1 | 判定不能 | None | 0.0027094791999999757 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.00204943749999984 |
| functions-modules-1000-1 | 判定不能 | None | 0.002077445899999475 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002799625000000106 |
| higher-1-300 | 達成 | 0.0011437500000113232 | 0.0030856749999998104 |
| classes-300 | 達成 | 0.0013317909999841504 | 0.003701441700000885 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 達成 | 0.0004688750000099162 | 0.002 |
| control-16.3 | 判定不能 | None | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 判定不能 | None | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 判定不能 | None | 0.002 |
| interval-range-64 | 判定不能 | None | 0.0023104500000002306 |
| interval-range-256 | 判定不能 | None | 0.0035976584000010805 |
| interval-http-0 | 退行の疑い | 0.002454958000001284 | 0.002 |
| interval-http-64 | 達成 | 0.0021527920000181666 | 0.0022648124999989252 |
| interval-http-256 | 達成 | 0.002963626000010322 | 0.0029789082999997166 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 判定不能 | None | 0.002 |
| interval-width-Integer16-256 | 達成 | 0.000547917000005782 | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 判定不能 | None | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 達成 | 0.00032958399999927224 | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | 0.0015790819999921268 | 0.0036892334000000917 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0035773500000004788 |
| property-distinct-24-20-1000-all-ok | 達成 | 0.0009132510000000593 | 0.003597516600000006 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003558016600000258 |
| property-zero-24-20-1000-all-ok | 達成 | 0.00138645900000256 | 0.0036386415999999145 |
| property-zero-24-20-1000-always-error | 達成 | 0.0013136249999945449 | 0.0035325499999999013 |
| property-max-24-20-1000-all-ok | 達成 | 0.001034541000009881 | 0.0036732333999992765 |
| property-max-24-20-1000-always-error | 達成 | 0.0012375010000056363 | 0.003542908299999681 |
| order-string-candidates | 判定不能 | None | 0.0035881958999993916 |
| order-string-all-ok | 達成 | 0.0015098330000000715 | 0.003546479199999908 |
| order-string-always-error | 判定不能 | None | 0.003508587499999294 |
| order-map-candidates | 達成 | 0.0007715410000059819 | 0.0035847791999998437 |
| order-map-all-ok | 達成 | 0.0013829579999935504 | 0.0035638042000002202 |
| order-map-always-error | 達成 | 0.0008927079999807574 | 0.0035866042000009205 |
| order-record-candidates | 達成 | 0.0012580420000034565 | 0.0036165666000002265 |
| order-record-all-ok | 判定不能 | None | 0.0036639832999995296 |
| order-record-always-error | 判定不能 | None | 0.003646774999999991 |
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
| runtime-fib-short | 達成 | 0.0006777499999941483 | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.0023781708000001345 |
| runtime-list-short | 判定不能 | None | 0.002936012499999663 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002198808299999655 |
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
    "verify": 2.0955601249999916,
    "cli": 5.210290334000007,
    "warmup": 0.5829017039999798,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.8769584589999937,
    "cli": 11.83334750400003,
    "warmup": 1.3661757510000285,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.268501332999989,
    "cli": 8.985068666999993,
    "warmup": 1.252841958000019,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.36592079199999716,
    "cli": 3.546516126,
    "warmup": 0.357892124999978,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.09843320799998878,
    "cli": 0.2762453749999878,
    "warmup": 0.029522499999998786,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03500920800000529,
    "cli": 0.330597417000007,
    "warmup": 0.034026291999992964,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009479917000007276,
    "cli": 0.19922466600000632,
    "warmup": 0.008860292000008485,
    "probe_warmup": 0.008108415999998897,
    "rss": 0,
    "stages": 0.044714418999987515,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.041281624999996325,
    "cli": 0.3418201669999945,
    "warmup": 0.03545762499999228,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18452391599998919
  },
  "runtime": {
    "verify": 0.33590674999999237,
    "cli": 2.9238018350000203,
    "warmup": 0.32893500100001916,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
