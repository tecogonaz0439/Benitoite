# 版どうしの性能比較

候補: `a26ed29afaeb444325da1daf362d9fe7ad12b18b`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013837 | 0.000234 |
| functions-main-0-0 | after | 0.014016 | 0.000363 |
| functions-main-0-1 | before | 0.013551 | 0.001144 |
| functions-main-0-1 | after | 0.013435 | 0.000198 |
| functions-main-64-0 | before | 0.013875 | 0.000846 |
| functions-main-64-0 | after | 0.013639 | 0.000190 |
| functions-main-256-0 | before | 0.014787 | 0.001216 |
| functions-main-256-0 | after | 0.015118 | 0.000394 |
| functions-main-1000-0 | before | 0.020725 | 0.001184 |
| functions-main-1000-0 | after | 0.021156 | 0.001575 |
| functions-main-1000-1 | before | 0.020444 | 0.000414 |
| functions-main-1000-1 | after | 0.020724 | 0.001276 |
| functions-args-0-0 | before | 0.013388 | 0.002471 |
| functions-args-0-0 | after | 0.013231 | 0.000232 |
| functions-args-0-1 | before | 0.013325 | 0.000614 |
| functions-args-0-1 | after | 0.013399 | 0.000111 |
| functions-args-1000-0 | before | 0.027351 | 0.000409 |
| functions-args-1000-0 | after | 0.028173 | 0.002127 |
| functions-args-1000-1 | before | 0.027607 | 0.000505 |
| functions-args-1000-1 | after | 0.027903 | 0.000515 |
| functions-modules-0-0 | before | 0.013342 | 0.000973 |
| functions-modules-0-0 | after | 0.013466 | 0.000456 |
| functions-modules-0-1 | before | 0.013702 | 0.000828 |
| functions-modules-0-1 | after | 0.013568 | 0.000811 |
| functions-modules-1000-0 | before | 0.021526 | 0.000713 |
| functions-modules-1000-0 | after | 0.021492 | 0.001854 |
| functions-modules-1000-1 | before | 0.021310 | 0.000549 |
| functions-modules-1000-1 | after | 0.021458 | 0.001403 |
| existing-fib | before | 0.014315 | 0.001011 |
| existing-fib | after | 0.014455 | 0.000172 |
| existing-loop | before | 0.015243 | 0.001088 |
| existing-loop | after | 0.014651 | 0.000539 |
| existing-string | before | 0.014587 | 0.000586 |
| existing-string | after | 0.014504 | 0.000772 |
| higher-0-0 | before | 0.014575 | 0.001244 |
| higher-0-0 | after | 0.014823 | 0.000357 |
| higher-1-0 | before | 0.015227 | 0.001752 |
| higher-1-0 | after | 0.015163 | 0.000389 |
| classes-0 | before | 0.018460 | 0.001379 |
| classes-0 | after | 0.018883 | 0.000997 |
| higher-0-300 | before | 0.033031 | 0.001344 |
| higher-0-300 | after | 0.032449 | 0.001182 |
| higher-1-300 | before | 0.031841 | 0.001712 |
| higher-1-300 | after | 0.032276 | 0.001199 |
| classes-300 | before | 0.038891 | 0.000963 |
| classes-300 | after | 0.039492 | 0.000580 |
| depth-0-8 | before | 0.015212 | 0.000742 |
| depth-0-8 | after | 0.015291 | 0.000076 |
| depth-1-8 | before | 0.015184 | 0.001144 |
| depth-1-8 | after | 0.015479 | 0.000345 |
| f1-nofail-call | before | 0.014410 | 0.001673 |
| f1-nofail-call | after | 0.014403 | 0.000246 |
| f1-join-effects | before | 0.014989 | 0.000841 |
| f1-join-effects | after | 0.014727 | 0.000408 |
| control-16.3 | before | 0.013367 | 0.001688 |
| control-16.3 | after | 0.013274 | 0.000136 |
| interval-bind-64 | before | 0.014061 | 0.000942 |
| interval-bind-64 | after | 0.013772 | 0.000310 |
| interval-bind-256 | before | 0.014860 | 0.001130 |
| interval-bind-256 | after | 0.014934 | 0.003618 |
| interval-add-64 | before | 0.013699 | 0.001245 |
| interval-add-64 | after | 0.013623 | 0.000546 |
| interval-add-256 | before | 0.015387 | 0.001363 |
| interval-add-256 | after | 0.015448 | 0.000318 |
| interval-flow-64 | before | 0.015026 | 0.000667 |
| interval-flow-64 | after | 0.014483 | 0.000715 |
| interval-flow-256 | before | 0.017105 | 0.000649 |
| interval-flow-256 | after | 0.017288 | 0.000135 |
| interval-range-0 | before | 0.018532 | 0.000487 |
| interval-range-0 | after | 0.018697 | 0.000765 |
| interval-range-64 | before | 0.023095 | 0.000267 |
| interval-range-64 | after | 0.024389 | 0.000696 |
| interval-range-256 | before | 0.036698 | 0.001152 |
| interval-range-256 | after | 0.036734 | 0.000197 |
| interval-http-0 | before | 0.019256 | 0.000831 |
| interval-http-0 | after | 0.019407 | 0.001503 |
| interval-http-64 | before | 0.022464 | 0.000291 |
| interval-http-64 | after | 0.022751 | 0.000916 |
| interval-http-256 | before | 0.029985 | 0.000331 |
| interval-http-256 | after | 0.030496 | 0.000482 |
| interval-width-Integer8-64 | before | 0.014395 | 0.001627 |
| interval-width-Integer8-64 | after | 0.014357 | 0.000695 |
| interval-width-Integer8-256 | before | 0.017216 | 0.000634 |
| interval-width-Integer8-256 | after | 0.017192 | 0.000148 |
| interval-width-Integer16-64 | before | 0.014565 | 0.001146 |
| interval-width-Integer16-64 | after | 0.014229 | 0.000408 |
| interval-width-Integer16-256 | before | 0.017074 | 0.002131 |
| interval-width-Integer16-256 | after | 0.017677 | 0.000969 |
| interval-width-Integer32-64 | before | 0.014011 | 0.002797 |
| interval-width-Integer32-64 | after | 0.014024 | 0.000072 |
| interval-width-Integer32-256 | before | 0.016758 | 0.000424 |
| interval-width-Integer32-256 | after | 0.017126 | 0.000197 |
| interval-width-Integer64-64 | before | 0.014350 | 0.001650 |
| interval-width-Integer64-64 | after | 0.014156 | 0.000348 |
| interval-width-Integer64-256 | before | 0.017224 | 0.001291 |
| interval-width-Integer64-256 | after | 0.017372 | 0.000659 |
| interval-width-UnsignedInteger16-64 | before | 0.015233 | 0.001051 |
| interval-width-UnsignedInteger16-64 | after | 0.015016 | 0.000775 |
| interval-width-UnsignedInteger16-256 | before | 0.017794 | 0.000317 |
| interval-width-UnsignedInteger16-256 | after | 0.018314 | 0.000899 |
| interval-width-UnsignedInteger32-64 | before | 0.014676 | 0.001586 |
| interval-width-UnsignedInteger32-64 | after | 0.014632 | 0.000647 |
| interval-width-UnsignedInteger32-256 | before | 0.017102 | 0.000430 |
| interval-width-UnsignedInteger32-256 | after | 0.017288 | 0.000719 |
| interval-width-UnsignedInteger64-64 | before | 0.015469 | 0.001754 |
| interval-width-UnsignedInteger64-64 | after | 0.015471 | 0.000623 |
| interval-width-UnsignedInteger64-256 | before | 0.017881 | 0.001366 |
| interval-width-UnsignedInteger64-256 | after | 0.017824 | 0.000437 |
| property-seven-24-20-1000-all-ok | before | 0.037849 | 0.002809 |
| property-seven-24-20-1000-all-ok | after | 0.038295 | 0.000308 |
| property-seven-24-20-1000-always-error | before | 0.036048 | 0.001206 |
| property-seven-24-20-1000-always-error | after | 0.036174 | 0.000560 |
| property-distinct-24-20-1000-all-ok | before | 0.038643 | 0.001266 |
| property-distinct-24-20-1000-all-ok | after | 0.038884 | 0.001912 |
| property-distinct-24-20-1000-always-error | before | 0.037834 | 0.001505 |
| property-distinct-24-20-1000-always-error | after | 0.037754 | 0.000792 |
| property-zero-24-20-1000-all-ok | before | 0.037068 | 0.001984 |
| property-zero-24-20-1000-all-ok | after | 0.037525 | 0.000714 |
| property-zero-24-20-1000-always-error | before | 0.036174 | 0.001015 |
| property-zero-24-20-1000-always-error | after | 0.036291 | 0.000296 |
| property-max-24-20-1000-all-ok | before | 0.037512 | 0.001302 |
| property-max-24-20-1000-all-ok | after | 0.038093 | 0.000358 |
| property-max-24-20-1000-always-error | before | 0.036394 | 0.000963 |
| property-max-24-20-1000-always-error | after | 0.036272 | 0.000204 |
| order-string-candidates | before | 0.036350 | 0.002635 |
| order-string-candidates | after | 0.038048 | 0.001616 |
| order-string-all-ok | before | 0.036641 | 0.001878 |
| order-string-all-ok | after | 0.037181 | 0.000375 |
| order-string-always-error | before | 0.037218 | 0.003266 |
| order-string-always-error | after | 0.037950 | 0.000749 |
| order-map-candidates | before | 0.037322 | 0.001210 |
| order-map-candidates | after | 0.036892 | 0.001013 |
| order-map-all-ok | before | 0.037192 | 0.001451 |
| order-map-all-ok | after | 0.036678 | 0.001159 |
| order-map-always-error | before | 0.038337 | 0.003284 |
| order-map-always-error | after | 0.037709 | 0.001032 |
| order-record-candidates | before | 0.036382 | 0.001900 |
| order-record-candidates | after | 0.036877 | 0.000884 |
| order-record-all-ok | before | 0.036920 | 0.001755 |
| order-record-all-ok | after | 0.037334 | 0.001281 |
| order-record-always-error | before | 0.038024 | 0.002671 |
| order-record-always-error | after | 0.037292 | 0.000815 |
| build-string-builder-8-0 | before | 0.015998 | 0.000457 |
| build-string-builder-8-0 | after | 0.016239 | 0.000096 |
| build-string-builder-all-8-0 | before | 0.016397 | 0.000520 |
| build-string-builder-all-8-0 | after | 0.016195 | 0.000326 |
| build-string-concatenate-8-0 | before | 0.015992 | 0.000693 |
| build-string-concatenate-8-0 | after | 0.015967 | 0.000359 |
| build-string-join-8-0 | before | 0.016150 | 0.000456 |
| build-string-join-8-0 | after | 0.016126 | 0.000915 |
| build-list-builder-8-0 | before | 0.016413 | 0.000556 |
| build-list-builder-8-0 | after | 0.016481 | 0.000407 |
| build-list-builder-all-8-0 | before | 0.016021 | 0.000881 |
| build-list-builder-all-8-0 | after | 0.015960 | 0.000405 |
| build-list-concatenate-8-0 | before | 0.016391 | 0.000305 |
| build-list-concatenate-8-0 | after | 0.016191 | 0.001510 |
| build-list-fold-8-0 | before | 0.016267 | 0.000917 |
| build-list-fold-8-0 | after | 0.016121 | 0.000569 |
| build-bytes-builder-8-0 | before | 0.016049 | 0.000607 |
| build-bytes-builder-8-0 | after | 0.016033 | 0.000071 |
| build-bytes-builder-all-8-0 | before | 0.016399 | 0.000506 |
| build-bytes-builder-all-8-0 | after | 0.016656 | 0.000320 |
| build-bytes-concatenate-8-0 | before | 0.016276 | 0.000561 |
| build-bytes-concatenate-8-0 | after | 0.016145 | 0.001149 |
| patterns-integer-100 | before | 0.015196 | 0.001213 |
| patterns-integer-100 | after | 0.015338 | 0.000723 |
| codegen-let-100 | before | 0.017717 | 0.000474 |
| codegen-let-100 | after | 0.017464 | 0.001348 |
| bridge-shared-8 | before | 0.004869 | 0.000257 |
| bridge-shared-8 | after | 0.005069 | 0.000508 |
| external-tests-normal-1 | before | 0.018635 | 0.000546 |
| external-tests-normal-1 | after | 0.018439 | 0.000759 |
| runtime-fib-short | before | 0.018178 | 0.000450 |
| runtime-fib-short | after | 0.018097 | 0.001812 |
| runtime-loop-short | before | 0.023681 | 0.000434 |
| runtime-loop-short | after | 0.023767 | 0.001930 |
| runtime-list-short | before | 0.029269 | 0.000102 |
| runtime-list-short | after | 0.029613 | 0.000516 |
| runtime-tree-short | before | 0.018512 | 0.000436 |
| runtime-tree-short | after | 0.018448 | 0.001816 |
| runtime-eval-short | before | 0.022290 | 0.000254 |
| runtime-eval-short | after | 0.022485 | 0.001377 |
| runtime-string-short | before | 0.017204 | 0.000406 |
| runtime-string-short | after | 0.017233 | 0.000832 |
| runtime-println-short | before | 0.018039 | 0.000715 |
| runtime-println-short | after | 0.018153 | 0.000599 |
| runtime-lines-short | before | 0.017015 | 0.000288 |
| runtime-lines-short | after | 0.017302 | 0.001787 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.8667e-05 | 1.208e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.292e-06 | 2.91e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1917e-05 | 9.59e-07 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.3708e-05 | 1.207e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.416e-06 | 2.92e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.6958e-05 | 1.375e-06 |
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
    "after": "a26ed29afaeb444325da1daf362d9fe7ad12b18b"
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
| functions-main-1000-0 | 判定不能 | None | 0.0020724959000006037 |
| functions-main-1000-1 | 判定不能 | None | 0.002044383400000527 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0027350875000010434 |
| functions-args-1000-1 | 判定不能 | None | 0.00276074999999878 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.0021526417000004017 |
| functions-modules-1000-1 | 判定不能 | None | 0.0021309958000003348 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0033031041000000983 |
| higher-1-300 | 判定不能 | None | 0.0031841208000003007 |
| classes-300 | 判定不能 | None | 0.003889099999999246 |
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
| interval-range-64 | 達成 | 0.001293666999998777 | 0.0023095499999996605 |
| interval-range-256 | 判定不能 | None | 0.003669775000000186 |
| interval-http-0 | 判定不能 | None | 0.002 |
| interval-http-64 | 判定不能 | None | 0.0022463999999999375 |
| interval-http-256 | 判定不能 | None | 0.002998537500000964 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003784920800001146 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0036047916000001125 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003864295799999695 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.003783445899999549 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0037067625000005936 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003617412500000228 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0037511875000006967 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003639366599999505 |
| order-string-candidates | 判定不能 | None | 0.003634995900000604 |
| order-string-all-ok | 判定不能 | None | 0.0036641083000006347 |
| order-string-always-error | 判定不能 | None | 0.0037217957999999387 |
| order-map-candidates | 判定不能 | None | 0.0037321999999988978 |
| order-map-all-ok | 判定不能 | None | 0.003719150000000582 |
| order-map-always-error | 判定不能 | None | 0.003833700000001272 |
| order-record-candidates | 判定不能 | None | 0.0036382000000003247 |
| order-record-all-ok | 判定不能 | None | 0.003691970799999922 |
| order-record-always-error | 判定不能 | None | 0.0038024375000006217 |
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
| runtime-loop-short | 判定不能 | None | 0.002368054199999392 |
| runtime-list-short | 判定不能 | None | 0.0029268749999999955 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022290165999990564 |
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
    "verify": 1.6962277909999983,
    "cli": 5.316099707000063,
    "warmup": 0.5912940840000118,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.9685665829999976,
    "cli": 12.153402710999998,
    "warmup": 1.3968954140000136,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.2999514170000026,
    "cli": 9.219552000999968,
    "warmup": 1.270532372999952,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3731092089999919,
    "cli": 3.5801084160000016,
    "warmup": 0.35871741499995835,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10017524999999239,
    "cli": 0.2929726660000256,
    "warmup": 0.02882370899999387,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.038948541999999975,
    "cli": 0.3424269169999832,
    "warmup": 0.03613612500001295,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010523083999999017,
    "cli": 0.2122747919999881,
    "warmup": 0.009463458999988461,
    "probe_warmup": 0.008794417000018484,
    "rss": 0,
    "stages": 0.042025209999962954,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04273408400000278,
    "cli": 0.3511858330000166,
    "warmup": 0.036629542000014226,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18850699899994083
  },
  "runtime": {
    "verify": 0.33922637499999553,
    "cli": 2.955642124000036,
    "warmup": 0.3306755849999803,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
