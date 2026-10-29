# 版どうしの性能比較

候補: `d3557d46d65d70220894125e013bc111ecb0ee42`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013775 | 0.000579 |
| functions-main-0-0 | after | 0.013993 | 0.000373 |
| functions-main-0-1 | before | 0.014952 | 0.001365 |
| functions-main-0-1 | after | 0.014343 | 0.000935 |
| functions-main-64-0 | before | 0.015229 | 0.001429 |
| functions-main-64-0 | after | 0.014795 | 0.000386 |
| functions-main-256-0 | before | 0.016000 | 0.000853 |
| functions-main-256-0 | after | 0.016143 | 0.000220 |
| functions-main-1000-0 | before | 0.021007 | 0.000530 |
| functions-main-1000-0 | after | 0.023334 | 0.001792 |
| functions-main-1000-1 | before | 0.021890 | 0.001106 |
| functions-main-1000-1 | after | 0.022667 | 0.001190 |
| functions-args-0-0 | before | 0.013700 | 0.001606 |
| functions-args-0-0 | after | 0.014572 | 0.000645 |
| functions-args-0-1 | before | 0.014425 | 0.000797 |
| functions-args-0-1 | after | 0.014323 | 0.001665 |
| functions-args-1000-0 | before | 0.028303 | 0.000984 |
| functions-args-1000-0 | after | 0.029525 | 0.003438 |
| functions-args-1000-1 | before | 0.027017 | 0.000539 |
| functions-args-1000-1 | after | 0.028520 | 0.003253 |
| functions-modules-0-0 | before | 0.013331 | 0.001361 |
| functions-modules-0-0 | after | 0.013534 | 0.000124 |
| functions-modules-0-1 | before | 0.013309 | 0.000770 |
| functions-modules-0-1 | after | 0.013684 | 0.000164 |
| functions-modules-1000-0 | before | 0.020913 | 0.000338 |
| functions-modules-1000-0 | after | 0.022145 | 0.001070 |
| functions-modules-1000-1 | before | 0.020884 | 0.000345 |
| functions-modules-1000-1 | after | 0.021677 | 0.001402 |
| existing-fib | before | 0.013998 | 0.001211 |
| existing-fib | after | 0.014269 | 0.000386 |
| existing-loop | before | 0.013985 | 0.000997 |
| existing-loop | after | 0.014305 | 0.000345 |
| existing-string | before | 0.014052 | 0.000885 |
| existing-string | after | 0.014311 | 0.000259 |
| higher-0-0 | before | 0.013610 | 0.001167 |
| higher-0-0 | after | 0.013924 | 0.000466 |
| higher-1-0 | before | 0.014214 | 0.002386 |
| higher-1-0 | after | 0.014633 | 0.000417 |
| classes-0 | before | 0.018130 | 0.000673 |
| classes-0 | after | 0.018722 | 0.000745 |
| higher-0-300 | before | 0.029481 | 0.000783 |
| higher-0-300 | after | 0.031081 | 0.001464 |
| higher-1-300 | before | 0.031693 | 0.000401 |
| higher-1-300 | after | 0.032415 | 0.000762 |
| classes-300 | before | 0.037840 | 0.001246 |
| classes-300 | after | 0.038807 | 0.000655 |
| depth-0-8 | before | 0.015157 | 0.001448 |
| depth-0-8 | after | 0.015402 | 0.000498 |
| depth-1-8 | before | 0.016485 | 0.000687 |
| depth-1-8 | after | 0.016417 | 0.000396 |
| f1-nofail-call | before | 0.015045 | 0.000642 |
| f1-nofail-call | after | 0.014955 | 0.000829 |
| f1-join-effects | before | 0.014392 | 0.001684 |
| f1-join-effects | after | 0.014851 | 0.000118 |
| control-16.3 | before | 0.013579 | 0.002151 |
| control-16.3 | after | 0.014338 | 0.000653 |
| interval-bind-64 | before | 0.013412 | 0.002202 |
| interval-bind-64 | after | 0.013920 | 0.002165 |
| interval-bind-256 | before | 0.013973 | 0.001724 |
| interval-bind-256 | after | 0.014511 | 0.000285 |
| interval-add-64 | before | 0.013481 | 0.001307 |
| interval-add-64 | after | 0.013711 | 0.000366 |
| interval-add-256 | before | 0.015433 | 0.000972 |
| interval-add-256 | after | 0.015606 | 0.000263 |
| interval-flow-64 | before | 0.014662 | 0.000903 |
| interval-flow-64 | after | 0.015111 | 0.000429 |
| interval-flow-256 | before | 0.017161 | 0.000593 |
| interval-flow-256 | after | 0.017701 | 0.000175 |
| interval-range-0 | before | 0.019276 | 0.000464 |
| interval-range-0 | after | 0.019720 | 0.001090 |
| interval-range-64 | before | 0.023048 | 0.000306 |
| interval-range-64 | after | 0.024141 | 0.000798 |
| interval-range-256 | before | 0.036043 | 0.001591 |
| interval-range-256 | after | 0.036988 | 0.000516 |
| interval-http-0 | before | 0.019154 | 0.000484 |
| interval-http-0 | after | 0.021232 | 0.001496 |
| interval-http-64 | before | 0.022282 | 0.000401 |
| interval-http-64 | after | 0.024951 | 0.001187 |
| interval-http-256 | before | 0.029705 | 0.000324 |
| interval-http-256 | after | 0.033146 | 0.001038 |
| interval-width-Integer8-64 | before | 0.014090 | 0.001649 |
| interval-width-Integer8-64 | after | 0.014366 | 0.000303 |
| interval-width-Integer8-256 | before | 0.016791 | 0.000472 |
| interval-width-Integer8-256 | after | 0.017215 | 0.000263 |
| interval-width-Integer16-64 | before | 0.014241 | 0.000925 |
| interval-width-Integer16-64 | after | 0.014289 | 0.000305 |
| interval-width-Integer16-256 | before | 0.016907 | 0.000742 |
| interval-width-Integer16-256 | after | 0.017467 | 0.000253 |
| interval-width-Integer32-64 | before | 0.014442 | 0.001362 |
| interval-width-Integer32-64 | after | 0.014295 | 0.000213 |
| interval-width-Integer32-256 | before | 0.016523 | 0.000617 |
| interval-width-Integer32-256 | after | 0.017479 | 0.000519 |
| interval-width-Integer64-64 | before | 0.014030 | 0.001629 |
| interval-width-Integer64-64 | after | 0.014316 | 0.000508 |
| interval-width-Integer64-256 | before | 0.016881 | 0.000581 |
| interval-width-Integer64-256 | after | 0.017381 | 0.000178 |
| interval-width-UnsignedInteger16-64 | before | 0.014550 | 0.002276 |
| interval-width-UnsignedInteger16-64 | after | 0.014494 | 0.000426 |
| interval-width-UnsignedInteger16-256 | before | 0.016926 | 0.000764 |
| interval-width-UnsignedInteger16-256 | after | 0.017188 | 0.000182 |
| interval-width-UnsignedInteger32-64 | before | 0.013992 | 0.000887 |
| interval-width-UnsignedInteger32-64 | after | 0.014134 | 0.000176 |
| interval-width-UnsignedInteger32-256 | before | 0.016928 | 0.000504 |
| interval-width-UnsignedInteger32-256 | after | 0.017449 | 0.000643 |
| interval-width-UnsignedInteger64-64 | before | 0.013956 | 0.001493 |
| interval-width-UnsignedInteger64-64 | after | 0.014135 | 0.000324 |
| interval-width-UnsignedInteger64-256 | before | 0.016939 | 0.000601 |
| interval-width-UnsignedInteger64-256 | after | 0.017214 | 0.000145 |
| property-seven-24-20-1000-all-ok | before | 0.037395 | 0.001873 |
| property-seven-24-20-1000-all-ok | after | 0.038526 | 0.000773 |
| property-seven-24-20-1000-always-error | before | 0.035359 | 0.001279 |
| property-seven-24-20-1000-always-error | after | 0.036868 | 0.000388 |
| property-distinct-24-20-1000-all-ok | before | 0.036073 | 0.001552 |
| property-distinct-24-20-1000-all-ok | after | 0.037707 | 0.000249 |
| property-distinct-24-20-1000-always-error | before | 0.036257 | 0.000890 |
| property-distinct-24-20-1000-always-error | after | 0.037216 | 0.000460 |
| property-zero-24-20-1000-all-ok | before | 0.037137 | 0.001512 |
| property-zero-24-20-1000-all-ok | after | 0.038143 | 0.000440 |
| property-zero-24-20-1000-always-error | before | 0.036425 | 0.001332 |
| property-zero-24-20-1000-always-error | after | 0.036997 | 0.000635 |
| property-max-24-20-1000-all-ok | before | 0.036900 | 0.001318 |
| property-max-24-20-1000-all-ok | after | 0.038323 | 0.000307 |
| property-max-24-20-1000-always-error | before | 0.035572 | 0.001880 |
| property-max-24-20-1000-always-error | after | 0.037107 | 0.000130 |
| order-string-candidates | before | 0.035445 | 0.002155 |
| order-string-candidates | after | 0.036865 | 0.000575 |
| order-string-all-ok | before | 0.037113 | 0.002896 |
| order-string-all-ok | after | 0.038310 | 0.000560 |
| order-string-always-error | before | 0.036284 | 0.001536 |
| order-string-always-error | after | 0.037282 | 0.001133 |
| order-map-candidates | before | 0.036611 | 0.001803 |
| order-map-candidates | after | 0.037334 | 0.000546 |
| order-map-all-ok | before | 0.036620 | 0.001917 |
| order-map-all-ok | after | 0.037900 | 0.000969 |
| order-map-always-error | before | 0.036894 | 0.002451 |
| order-map-always-error | after | 0.037570 | 0.000990 |
| order-record-candidates | before | 0.037304 | 0.001558 |
| order-record-candidates | after | 0.037881 | 0.000398 |
| order-record-all-ok | before | 0.036841 | 0.002207 |
| order-record-all-ok | after | 0.038411 | 0.000415 |
| order-record-always-error | before | 0.036502 | 0.002983 |
| order-record-always-error | after | 0.037852 | 0.000551 |
| build-string-builder-8-0 | before | 0.016712 | 0.000682 |
| build-string-builder-8-0 | after | 0.017166 | 0.000806 |
| build-string-builder-all-8-0 | before | 0.016555 | 0.000426 |
| build-string-builder-all-8-0 | after | 0.016915 | 0.000147 |
| build-string-concatenate-8-0 | before | 0.016613 | 0.000511 |
| build-string-concatenate-8-0 | after | 0.017265 | 0.001650 |
| build-string-join-8-0 | before | 0.016604 | 0.000446 |
| build-string-join-8-0 | after | 0.016662 | 0.000363 |
| build-list-builder-8-0 | before | 0.016844 | 0.000749 |
| build-list-builder-8-0 | after | 0.017228 | 0.000690 |
| build-list-builder-all-8-0 | before | 0.016524 | 0.000572 |
| build-list-builder-all-8-0 | after | 0.016924 | 0.000248 |
| build-list-concatenate-8-0 | before | 0.016973 | 0.000621 |
| build-list-concatenate-8-0 | after | 0.017715 | 0.000967 |
| build-list-fold-8-0 | before | 0.016823 | 0.000384 |
| build-list-fold-8-0 | after | 0.017672 | 0.000644 |
| build-bytes-builder-8-0 | before | 0.017094 | 0.000362 |
| build-bytes-builder-8-0 | after | 0.017100 | 0.001736 |
| build-bytes-builder-all-8-0 | before | 0.017411 | 0.001006 |
| build-bytes-builder-all-8-0 | after | 0.017799 | 0.000813 |
| build-bytes-concatenate-8-0 | before | 0.016547 | 0.000495 |
| build-bytes-concatenate-8-0 | after | 0.017019 | 0.000222 |
| patterns-integer-100 | before | 0.014691 | 0.002156 |
| patterns-integer-100 | after | 0.014969 | 0.000443 |
| codegen-let-100 | before | 0.017508 | 0.000394 |
| codegen-let-100 | after | 0.017847 | 0.001878 |
| bridge-shared-8 | before | 0.005096 | 0.001019 |
| bridge-shared-8 | after | 0.005090 | 0.000721 |
| external-tests-normal-1 | before | 0.019025 | 0.000724 |
| external-tests-normal-1 | after | 0.018949 | 0.001998 |
| runtime-fib-short | before | 0.018733 | 0.000443 |
| runtime-fib-short | after | 0.018757 | 0.001549 |
| runtime-loop-short | before | 0.024107 | 0.000350 |
| runtime-loop-short | after | 0.025115 | 0.002008 |
| runtime-list-short | before | 0.029915 | 0.000243 |
| runtime-list-short | after | 0.030412 | 0.000527 |
| runtime-tree-short | before | 0.018613 | 0.000406 |
| runtime-tree-short | after | 0.019238 | 0.002296 |
| runtime-eval-short | before | 0.022027 | 0.000149 |
| runtime-eval-short | after | 0.022741 | 0.001943 |
| runtime-string-short | before | 0.017061 | 0.000260 |
| runtime-string-short | after | 0.017797 | 0.000601 |
| runtime-println-short | before | 0.017131 | 0.000404 |
| runtime-println-short | after | 0.017807 | 0.000901 |
| runtime-lines-short | before | 0.016745 | 0.000481 |
| runtime-lines-short | after | 0.017189 | 0.001055 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.8917e-05 | 2.041e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.334e-06 | 2.5e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.2251e-05 | 2.291e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4584e-05 | 1.501e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.209e-06 | 3.34e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.8042e-05 | 1.752e-06 |
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
    "after": "d3557d46d65d70220894125e013bc111ecb0ee42"
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
| functions-main-1000-0 | 退行の疑い | 0.0023276250000066057 | 0.0021006791999994335 |
| functions-main-1000-1 | 判定不能 | None | 0.002189020800000208 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0028302542000005816 |
| functions-args-1000-1 | 判定不能 | None | 0.0027017334000007057 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002091300000000729 |
| functions-modules-1000-1 | 判定不能 | None | 0.002088374999999587 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002948100000000409 |
| higher-1-300 | 判定不能 | None | 0.003169258300000877 |
| classes-300 | 判定不能 | None | 0.003784049999998729 |
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
| interval-range-64 | 判定不能 | None | 0.0023047957999992263 |
| interval-range-256 | 判定不能 | None | 0.003604279200000349 |
| interval-http-0 | 退行の疑い | 0.0020779999999973597 | 0.002 |
| interval-http-64 | 退行の疑い | 0.002669208000000367 | 0.0022281875000004447 |
| interval-http-256 | 退行の疑い | 0.003440458000014246 | 0.0029705249999992136 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.0037395124999989094 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0035359167000009965 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003607325000000117 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0036256541999989626 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0037137209000007946 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0036424541000002367 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0036899708000007084 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.00355715000000032 |
| order-string-candidates | 判定不能 | None | 0.003544462499999668 |
| order-string-all-ok | 判定不能 | None | 0.0037112708000009323 |
| order-string-always-error | 判定不能 | None | 0.0036283875000009402 |
| order-map-candidates | 判定不能 | None | 0.003661070799999777 |
| order-map-all-ok | 判定不能 | None | 0.0036620083000002525 |
| order-map-always-error | 判定不能 | None | 0.0036894458000006126 |
| order-record-candidates | 判定不能 | None | 0.0037303959000013266 |
| order-record-all-ok | 判定不能 | None | 0.003684100000000967 |
| order-record-always-error | 判定不能 | None | 0.0036502458000001073 |
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
| runtime-loop-short | 判定不能 | None | 0.0024106666999998087 |
| runtime-list-short | 判定不能 | None | 0.002991483399999595 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002202708299999756 |
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
    "verify": 1.7814925419999952,
    "cli": 5.472672833000033,
    "warmup": 0.6023780020000515,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 3.0322696670000084,
    "cli": 12.074481377000012,
    "warmup": 1.3843351720000356,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3257073329999969,
    "cli": 9.173905750000017,
    "warmup": 1.2628364550000413,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3873497499999985,
    "cli": 3.734549498999968,
    "warmup": 0.36963983199997585,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10188245800000573,
    "cli": 0.2889620409999907,
    "warmup": 0.02934662499995966,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.04093312499999513,
    "cli": 0.34490533400000345,
    "warmup": 0.0354970419999745,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010438208000010718,
    "cli": 0.21356366599999888,
    "warmup": 0.009843417000013233,
    "probe_warmup": 0.009289417000019284,
    "rss": 0,
    "stages": 0.042962375000001884,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04365204100000142,
    "cli": 0.3563837500000204,
    "warmup": 0.038091833000009956,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18785983199998668
  },
  "runtime": {
    "verify": 0.35416995799999995,
    "cli": 2.989508000000029,
    "warmup": 0.33426233500000535,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-29）

`functions-main-1000-0` の退行の疑い（+11%）は、同じ入力で開始版・R20.4 の取り込み（`e1e5db59`）・この版の CLI の `check` を交互に40回ずつ走らせて確かめた。中央値は開始版 20.37 ms、R20.4 21.19 ms、この版 21.22 ms で、R20.5 による差はなかった。開始版からの差は +4%（約 0.85 ms）で、R20 の段の漂いとして段末で調べる。`interval-http` の三点は既知（R20.0b の Http の import の費用）である。全94入力の after/before の中央値の比は 1.027。
