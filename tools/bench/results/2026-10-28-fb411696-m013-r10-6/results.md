# 版どうしの性能比較

候補: `fb4116961bd7fa8a26a39858ceead9cb679fd141`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.014379 | 0.001042 |
| functions-main-0-0 | after | 0.014376 | 0.001620 |
| functions-main-0-1 | before | 0.014257 | 0.001039 |
| functions-main-0-1 | after | 0.014173 | 0.000568 |
| functions-main-64-0 | before | 0.015178 | 0.000858 |
| functions-main-64-0 | after | 0.014952 | 0.000569 |
| functions-main-256-0 | before | 0.016306 | 0.001156 |
| functions-main-256-0 | after | 0.016371 | 0.000335 |
| functions-main-1000-0 | before | 0.021678 | 0.000262 |
| functions-main-1000-0 | after | 0.021828 | 0.002049 |
| functions-main-1000-1 | before | 0.021233 | 0.000250 |
| functions-main-1000-1 | after | 0.022158 | 0.001124 |
| functions-args-0-0 | before | 0.013914 | 0.001644 |
| functions-args-0-0 | after | 0.014190 | 0.000521 |
| functions-args-0-1 | before | 0.013693 | 0.001597 |
| functions-args-0-1 | after | 0.013596 | 0.000210 |
| functions-args-1000-0 | before | 0.027036 | 0.000917 |
| functions-args-1000-0 | after | 0.028504 | 0.001926 |
| functions-args-1000-1 | before | 0.027349 | 0.000435 |
| functions-args-1000-1 | after | 0.028725 | 0.000878 |
| functions-modules-0-0 | before | 0.014023 | 0.000380 |
| functions-modules-0-0 | after | 0.014509 | 0.000773 |
| functions-modules-0-1 | before | 0.014437 | 0.001090 |
| functions-modules-0-1 | after | 0.015235 | 0.001135 |
| functions-modules-1000-0 | before | 0.021348 | 0.000262 |
| functions-modules-1000-0 | after | 0.022505 | 0.000967 |
| functions-modules-1000-1 | before | 0.021491 | 0.000474 |
| functions-modules-1000-1 | after | 0.021719 | 0.000861 |
| existing-fib | before | 0.013706 | 0.000856 |
| existing-fib | after | 0.013934 | 0.000866 |
| existing-loop | before | 0.014137 | 0.001342 |
| existing-loop | after | 0.014226 | 0.000630 |
| existing-string | before | 0.014165 | 0.000797 |
| existing-string | after | 0.014377 | 0.000496 |
| higher-0-0 | before | 0.014108 | 0.000981 |
| higher-0-0 | after | 0.014118 | 0.000568 |
| higher-1-0 | before | 0.015272 | 0.001391 |
| higher-1-0 | after | 0.015358 | 0.000137 |
| classes-0 | before | 0.018659 | 0.000212 |
| classes-0 | after | 0.019364 | 0.001621 |
| higher-0-300 | before | 0.029041 | 0.000774 |
| higher-0-300 | after | 0.030433 | 0.000772 |
| higher-1-300 | before | 0.032373 | 0.000745 |
| higher-1-300 | after | 0.032970 | 0.000519 |
| classes-300 | before | 0.038568 | 0.002026 |
| classes-300 | after | 0.039785 | 0.000550 |
| depth-0-8 | before | 0.016106 | 0.000365 |
| depth-0-8 | after | 0.016137 | 0.000220 |
| depth-1-8 | before | 0.015843 | 0.001140 |
| depth-1-8 | after | 0.016032 | 0.000722 |
| f1-nofail-call | before | 0.014665 | 0.001267 |
| f1-nofail-call | after | 0.015377 | 0.000488 |
| f1-join-effects | before | 0.014862 | 0.000366 |
| f1-join-effects | after | 0.015276 | 0.001039 |
| control-16.3 | before | 0.013814 | 0.000668 |
| control-16.3 | after | 0.013829 | 0.000112 |
| interval-bind-64 | before | 0.014210 | 0.001266 |
| interval-bind-64 | after | 0.014012 | 0.000623 |
| interval-bind-256 | before | 0.014204 | 0.000978 |
| interval-bind-256 | after | 0.014030 | 0.001014 |
| interval-add-64 | before | 0.014116 | 0.000671 |
| interval-add-64 | after | 0.013642 | 0.000648 |
| interval-add-256 | before | 0.015200 | 0.001829 |
| interval-add-256 | after | 0.015302 | 0.000429 |
| interval-flow-64 | before | 0.014933 | 0.001051 |
| interval-flow-64 | after | 0.014744 | 0.000792 |
| interval-flow-256 | before | 0.017743 | 0.000401 |
| interval-flow-256 | after | 0.018321 | 0.001430 |
| interval-range-0 | before | 0.019189 | 0.000731 |
| interval-range-0 | after | 0.019334 | 0.001232 |
| interval-range-64 | before | 0.023804 | 0.000790 |
| interval-range-64 | after | 0.024346 | 0.001320 |
| interval-range-256 | before | 0.037554 | 0.001805 |
| interval-range-256 | after | 0.038010 | 0.000918 |
| interval-http-0 | before | 0.020587 | 0.000754 |
| interval-http-0 | after | 0.020779 | 0.001631 |
| interval-http-64 | before | 0.023103 | 0.000663 |
| interval-http-64 | after | 0.024524 | 0.001555 |
| interval-http-256 | before | 0.030965 | 0.000912 |
| interval-http-256 | after | 0.031556 | 0.001342 |
| interval-width-Integer8-64 | before | 0.015364 | 0.001154 |
| interval-width-Integer8-64 | after | 0.015098 | 0.000392 |
| interval-width-Integer8-256 | before | 0.017609 | 0.000243 |
| interval-width-Integer8-256 | after | 0.017836 | 0.000302 |
| interval-width-Integer16-64 | before | 0.015235 | 0.000644 |
| interval-width-Integer16-64 | after | 0.015128 | 0.000573 |
| interval-width-Integer16-256 | before | 0.017058 | 0.000688 |
| interval-width-Integer16-256 | after | 0.017631 | 0.000450 |
| interval-width-Integer32-64 | before | 0.014293 | 0.002167 |
| interval-width-Integer32-64 | after | 0.014333 | 0.000187 |
| interval-width-Integer32-256 | before | 0.017212 | 0.000912 |
| interval-width-Integer32-256 | after | 0.017639 | 0.000402 |
| interval-width-Integer64-64 | before | 0.014531 | 0.000892 |
| interval-width-Integer64-64 | after | 0.014616 | 0.000263 |
| interval-width-Integer64-256 | before | 0.016959 | 0.000489 |
| interval-width-Integer64-256 | after | 0.017419 | 0.000115 |
| interval-width-UnsignedInteger16-64 | before | 0.014244 | 0.001739 |
| interval-width-UnsignedInteger16-64 | after | 0.014549 | 0.000715 |
| interval-width-UnsignedInteger16-256 | before | 0.017269 | 0.001217 |
| interval-width-UnsignedInteger16-256 | after | 0.017641 | 0.001134 |
| interval-width-UnsignedInteger32-64 | before | 0.015640 | 0.000487 |
| interval-width-UnsignedInteger32-64 | after | 0.016017 | 0.000708 |
| interval-width-UnsignedInteger32-256 | before | 0.018074 | 0.000739 |
| interval-width-UnsignedInteger32-256 | after | 0.018416 | 0.001645 |
| interval-width-UnsignedInteger64-64 | before | 0.015358 | 0.000514 |
| interval-width-UnsignedInteger64-64 | after | 0.015572 | 0.000432 |
| interval-width-UnsignedInteger64-256 | before | 0.018095 | 0.000965 |
| interval-width-UnsignedInteger64-256 | after | 0.018031 | 0.001721 |
| property-seven-24-20-1000-all-ok | before | 0.039088 | 0.002014 |
| property-seven-24-20-1000-all-ok | after | 0.040479 | 0.000995 |
| property-seven-24-20-1000-always-error | before | 0.037674 | 0.002165 |
| property-seven-24-20-1000-always-error | after | 0.039300 | 0.000570 |
| property-distinct-24-20-1000-all-ok | before | 0.039474 | 0.001568 |
| property-distinct-24-20-1000-all-ok | after | 0.039678 | 0.000286 |
| property-distinct-24-20-1000-always-error | before | 0.038368 | 0.003092 |
| property-distinct-24-20-1000-always-error | after | 0.039399 | 0.001540 |
| property-zero-24-20-1000-all-ok | before | 0.040049 | 0.001883 |
| property-zero-24-20-1000-all-ok | after | 0.039806 | 0.000902 |
| property-zero-24-20-1000-always-error | before | 0.039171 | 0.001302 |
| property-zero-24-20-1000-always-error | after | 0.040770 | 0.000763 |
| property-max-24-20-1000-all-ok | before | 0.037273 | 0.002627 |
| property-max-24-20-1000-all-ok | after | 0.038841 | 0.000917 |
| property-max-24-20-1000-always-error | before | 0.035530 | 0.001319 |
| property-max-24-20-1000-always-error | after | 0.036609 | 0.000596 |
| order-string-candidates | before | 0.035866 | 0.001340 |
| order-string-candidates | after | 0.035998 | 0.000672 |
| order-string-all-ok | before | 0.035914 | 0.001576 |
| order-string-all-ok | after | 0.037100 | 0.000444 |
| order-string-always-error | before | 0.035443 | 0.001228 |
| order-string-always-error | after | 0.036452 | 0.000568 |
| order-map-candidates | before | 0.035853 | 0.001575 |
| order-map-candidates | after | 0.036761 | 0.001596 |
| order-map-all-ok | before | 0.036514 | 0.001979 |
| order-map-all-ok | after | 0.036735 | 0.000280 |
| order-map-always-error | before | 0.035809 | 0.002434 |
| order-map-always-error | after | 0.036687 | 0.000602 |
| order-record-candidates | before | 0.035832 | 0.002838 |
| order-record-candidates | after | 0.037007 | 0.001007 |
| order-record-all-ok | before | 0.037091 | 0.001731 |
| order-record-all-ok | after | 0.037890 | 0.000329 |
| order-record-always-error | before | 0.036128 | 0.001398 |
| order-record-always-error | after | 0.037706 | 0.000431 |
| build-string-builder-8-0 | before | 0.016385 | 0.000325 |
| build-string-builder-8-0 | after | 0.016206 | 0.000592 |
| build-string-builder-all-8-0 | before | 0.015997 | 0.000657 |
| build-string-builder-all-8-0 | after | 0.016515 | 0.000708 |
| build-string-concatenate-8-0 | before | 0.015864 | 0.000395 |
| build-string-concatenate-8-0 | after | 0.016062 | 0.000296 |
| build-string-join-8-0 | before | 0.015846 | 0.000527 |
| build-string-join-8-0 | after | 0.015998 | 0.000515 |
| build-list-builder-8-0 | before | 0.016082 | 0.000578 |
| build-list-builder-8-0 | after | 0.016414 | 0.000138 |
| build-list-builder-all-8-0 | before | 0.016084 | 0.000571 |
| build-list-builder-all-8-0 | after | 0.016364 | 0.000477 |
| build-list-concatenate-8-0 | before | 0.016102 | 0.000617 |
| build-list-concatenate-8-0 | after | 0.016514 | 0.000651 |
| build-list-fold-8-0 | before | 0.015869 | 0.000515 |
| build-list-fold-8-0 | after | 0.016239 | 0.000351 |
| build-bytes-builder-8-0 | before | 0.016247 | 0.000466 |
| build-bytes-builder-8-0 | after | 0.016154 | 0.000385 |
| build-bytes-builder-all-8-0 | before | 0.016127 | 0.000324 |
| build-bytes-builder-all-8-0 | after | 0.016377 | 0.000217 |
| build-bytes-concatenate-8-0 | before | 0.016203 | 0.000600 |
| build-bytes-concatenate-8-0 | after | 0.016354 | 0.000272 |
| patterns-integer-100 | before | 0.014382 | 0.001325 |
| patterns-integer-100 | after | 0.014892 | 0.000253 |
| codegen-let-100 | before | 0.016920 | 0.000566 |
| codegen-let-100 | after | 0.017371 | 0.000810 |
| bridge-shared-8 | before | 0.004427 | 0.000473 |
| external-tests-normal-1 | before | 0.018403 | 0.000891 |
| external-tests-normal-1 | after | 0.018830 | 0.001600 |
| runtime-fib-short | before | 0.018421 | 0.000438 |
| runtime-fib-short | after | 0.018619 | 0.001188 |
| runtime-loop-short | before | 0.023862 | 0.001832 |
| runtime-loop-short | after | 0.024247 | 0.000981 |
| runtime-list-short | before | 0.029472 | 0.000220 |
| runtime-list-short | after | 0.029930 | 0.001170 |
| runtime-tree-short | before | 0.018557 | 0.000182 |
| runtime-tree-short | after | 0.018652 | 0.001102 |
| runtime-eval-short | before | 0.022085 | 0.000157 |
| runtime-eval-short | after | 0.022499 | 0.001428 |
| runtime-string-short | before | 0.017186 | 0.000566 |
| runtime-string-short | after | 0.017380 | 0.000425 |
| runtime-println-short | before | 0.017307 | 0.000441 |
| runtime-println-short | after | 0.017770 | 0.000344 |
| runtime-lines-short | before | 0.016906 | 0.000400 |
| runtime-lines-short | after | 0.017226 | 0.000358 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 2.0542e-05 | 2.917e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.625e-06 | 2.49e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.4208e-05 | 3.125e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| runtime_compilations | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | before | 5 | 1 | 0 |
| runtime_compilations | count | external-tests-normal-1 | after | 5 | 1 | 0 |
| component_keys | count | external-tests-normal-1 | after | 5 | 1 | 0 |

## 比較状態と機能

```json
{
  "commits": {
    "before": "6124775788579e60530f55fb85570f26ef7fa900",
    "after": "fb4116961bd7fa8a26a39858ceead9cb679fd141"
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
      "timing_probe": false
    }
  },
  "skipped": [
    {
      "case": "bridge-shared-8",
      "state": "after",
      "reason": "missing features: timing_probe"
    }
  ],
  "unavailable_probes": {
    "after": "public API helper build failed (1); see <repo>/target/bench/builds/fb4116961bd7fa8a26a39858ceead9cb679fd141-default/build.log"
  }
}
```

## 目標

| 目標 | 判定 | 値 | 上限 |
|---|---|---:|---:|
| functions-main-0-0 | 判定不能 | None | 0.002 |
| functions-main-0-1 | 判定不能 | None | 0.002 |
| functions-main-64-0 | 判定不能 | None | 0.002 |
| functions-main-256-0 | 判定不能 | None | 0.002 |
| functions-main-1000-0 | 判定不能 | None | 0.0021677999999994316 |
| functions-main-1000-1 | 判定不能 | None | 0.0021233042000005755 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0027035582999999975 |
| functions-args-1000-1 | 達成 | 0.001375707999997644 | 0.0027348916999997645 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002134808300000657 |
| functions-modules-1000-1 | 判定不能 | None | 0.0021490917000008382 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002904133300000922 |
| higher-1-300 | 判定不能 | None | 0.0032373208999999293 |
| classes-300 | 判定不能 | None | 0.003856820800000094 |
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
| interval-range-64 | 判定不能 | None | 0.0023804042000008965 |
| interval-range-256 | 判定不能 | None | 0.003755400000000009 |
| interval-http-0 | 判定不能 | None | 0.0020587249999991287 |
| interval-http-64 | 判定不能 | None | 0.0023103374999990933 |
| interval-http-256 | 判定不能 | None | 0.003096462499999575 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.003908783300001062 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.003767354199999318 |
| property-distinct-24-20-1000-all-ok | 判定不能 | None | 0.003947416699999451 |
| property-distinct-24-20-1000-always-error | 判定不能 | None | 0.0038368125000005195 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.0040049124999995914 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.003917133299999875 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.0037272999999999005 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003552999999999429 |
| order-string-candidates | 判定不能 | None | 0.003586599999999862 |
| order-string-all-ok | 判定不能 | None | 0.003591429200000107 |
| order-string-always-error | 判定不能 | None | 0.0035443374999999835 |
| order-map-candidates | 判定不能 | None | 0.003585341700001266 |
| order-map-all-ok | 判定不能 | None | 0.00365142499999962 |
| order-map-always-error | 判定不能 | None | 0.003580891600000769 |
| order-record-candidates | 判定不能 | None | 0.0035832499999997936 |
| order-record-all-ok | 判定不能 | None | 0.003709141599999555 |
| order-record-always-error | 判定不能 | None | 0.0036128165999997465 |
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
| runtime-loop-short | 判定不能 | None | 0.0023862041999990428 |
| runtime-list-short | 判定不能 | None | 0.0029472083000001703 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022085124999989604 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 判定不能 | None | 0.002 |
| codegen-let-100 | 判定不能 | None | 0.002 |
| bridge-shared-8 | 判定不能 | None | None |
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
    "verify": 0.9741451670000032,
    "cli": 5.469896125999966,
    "warmup": 0.6092809139999105,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.243424958999995,
    "cli": 12.380655582000003,
    "warmup": 1.4126479130000007,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3286777919999935,
    "cli": 9.282037082999977,
    "warmup": 1.294891747999941,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.4039975000000027,
    "cli": 3.566161041000001,
    "warmup": 0.3611082899999616,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.08507245900000271,
    "cli": 0.28347658300000944,
    "warmup": 0.029845750000006888,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.03895462500000235,
    "cli": 0.3346616669999918,
    "warmup": 0.034436334000005786,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.006318292000003112,
    "cli": 0.10096933300000899,
    "warmup": 0.004588249999997629,
    "probe_warmup": 0.004359041999975943,
    "rss": 0,
    "stages": 0.02512187399995014,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04439479100000199,
    "cli": 0.35611858400000074,
    "warmup": 0.03749987499998042,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18397454099996935
  },
  "runtime": {
    "verify": 0.34762499999999363,
    "cli": 2.9609589570000168,
    "warmup": 0.3309438729999812,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
