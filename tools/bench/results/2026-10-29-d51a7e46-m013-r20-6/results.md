# 版どうしの性能比較

候補: `d51a7e46d36997e0d2b29a33b73a3f736c618ec1`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013778 | 0.000650 |
| functions-main-0-0 | after | 0.014281 | 0.000251 |
| functions-main-0-1 | before | 0.013636 | 0.001319 |
| functions-main-0-1 | after | 0.014130 | 0.000381 |
| functions-main-64-0 | before | 0.014096 | 0.001683 |
| functions-main-64-0 | after | 0.014339 | 0.000114 |
| functions-main-256-0 | before | 0.015411 | 0.001185 |
| functions-main-256-0 | after | 0.015968 | 0.000102 |
| functions-main-1000-0 | before | 0.020706 | 0.000238 |
| functions-main-1000-0 | after | 0.021931 | 0.001788 |
| functions-main-1000-1 | before | 0.020669 | 0.000488 |
| functions-main-1000-1 | after | 0.021768 | 0.001094 |
| functions-args-0-0 | before | 0.013157 | 0.000624 |
| functions-args-0-0 | after | 0.013588 | 0.000342 |
| functions-args-0-1 | before | 0.013351 | 0.000834 |
| functions-args-0-1 | after | 0.013698 | 0.000316 |
| functions-args-1000-0 | before | 0.027197 | 0.000549 |
| functions-args-1000-0 | after | 0.028750 | 0.000818 |
| functions-args-1000-1 | before | 0.026797 | 0.000327 |
| functions-args-1000-1 | after | 0.028568 | 0.001674 |
| functions-modules-0-0 | before | 0.013417 | 0.000417 |
| functions-modules-0-0 | after | 0.013790 | 0.000322 |
| functions-modules-0-1 | before | 0.013095 | 0.000631 |
| functions-modules-0-1 | after | 0.013783 | 0.000550 |
| functions-modules-1000-0 | before | 0.020967 | 0.000385 |
| functions-modules-1000-0 | after | 0.022136 | 0.001751 |
| functions-modules-1000-1 | before | 0.021428 | 0.000658 |
| functions-modules-1000-1 | after | 0.023225 | 0.001161 |
| existing-fib | before | 0.013839 | 0.001512 |
| existing-fib | after | 0.014102 | 0.000121 |
| existing-loop | before | 0.013948 | 0.001162 |
| existing-loop | after | 0.014368 | 0.000201 |
| existing-string | before | 0.014053 | 0.001080 |
| existing-string | after | 0.014233 | 0.000179 |
| higher-0-0 | before | 0.013522 | 0.000272 |
| higher-0-0 | after | 0.013870 | 0.000512 |
| higher-1-0 | before | 0.014524 | 0.001508 |
| higher-1-0 | after | 0.014800 | 0.000352 |
| classes-0 | before | 0.017940 | 0.000562 |
| classes-0 | after | 0.018849 | 0.000687 |
| higher-0-300 | before | 0.028233 | 0.000211 |
| higher-0-300 | after | 0.029878 | 0.001135 |
| higher-1-300 | before | 0.030798 | 0.000156 |
| higher-1-300 | after | 0.032665 | 0.001229 |
| classes-300 | before | 0.037409 | 0.001589 |
| classes-300 | after | 0.038644 | 0.000593 |
| depth-0-8 | before | 0.014739 | 0.001273 |
| depth-0-8 | after | 0.014996 | 0.000163 |
| depth-1-8 | before | 0.014926 | 0.001768 |
| depth-1-8 | after | 0.015609 | 0.000216 |
| f1-nofail-call | before | 0.014191 | 0.001547 |
| f1-nofail-call | after | 0.014546 | 0.000075 |
| f1-join-effects | before | 0.014063 | 0.001364 |
| f1-join-effects | after | 0.014644 | 0.000240 |
| control-16.3 | before | 0.013446 | 0.000695 |
| control-16.3 | after | 0.013612 | 0.000374 |
| interval-bind-64 | before | 0.013705 | 0.001364 |
| interval-bind-64 | after | 0.013653 | 0.000832 |
| interval-bind-256 | before | 0.014164 | 0.000838 |
| interval-bind-256 | after | 0.014651 | 0.003684 |
| interval-add-64 | before | 0.013210 | 0.001346 |
| interval-add-64 | after | 0.013817 | 0.000085 |
| interval-add-256 | before | 0.015224 | 0.001192 |
| interval-add-256 | after | 0.015497 | 0.000194 |
| interval-flow-64 | before | 0.013996 | 0.000765 |
| interval-flow-64 | after | 0.014740 | 0.000142 |
| interval-flow-256 | before | 0.017046 | 0.000504 |
| interval-flow-256 | after | 0.017677 | 0.000402 |
| interval-range-0 | before | 0.018641 | 0.000256 |
| interval-range-0 | after | 0.019365 | 0.001578 |
| interval-range-64 | before | 0.023368 | 0.000821 |
| interval-range-64 | after | 0.024114 | 0.001110 |
| interval-range-256 | before | 0.036269 | 0.001333 |
| interval-range-256 | after | 0.037714 | 0.000976 |
| interval-http-0 | before | 0.019065 | 0.000229 |
| interval-http-0 | after | 0.021914 | 0.001336 |
| interval-http-64 | before | 0.022204 | 0.000263 |
| interval-http-64 | after | 0.025365 | 0.001096 |
| interval-http-256 | before | 0.029765 | 0.000714 |
| interval-http-256 | after | 0.033204 | 0.000383 |
| interval-width-Integer8-64 | before | 0.014089 | 0.001759 |
| interval-width-Integer8-64 | after | 0.014703 | 0.000214 |
| interval-width-Integer8-256 | before | 0.017517 | 0.000955 |
| interval-width-Integer8-256 | after | 0.017584 | 0.000388 |
| interval-width-Integer16-64 | before | 0.014195 | 0.000323 |
| interval-width-Integer16-64 | after | 0.015139 | 0.000981 |
| interval-width-Integer16-256 | before | 0.016894 | 0.000559 |
| interval-width-Integer16-256 | after | 0.017492 | 0.000252 |
| interval-width-Integer32-64 | before | 0.014018 | 0.001243 |
| interval-width-Integer32-64 | after | 0.014430 | 0.000173 |
| interval-width-Integer32-256 | before | 0.016893 | 0.000648 |
| interval-width-Integer32-256 | after | 0.017882 | 0.000884 |
| interval-width-Integer64-64 | before | 0.013830 | 0.000909 |
| interval-width-Integer64-64 | after | 0.014457 | 0.000158 |
| interval-width-Integer64-256 | before | 0.016944 | 0.000603 |
| interval-width-Integer64-256 | after | 0.017386 | 0.000340 |
| interval-width-UnsignedInteger16-64 | before | 0.014088 | 0.000851 |
| interval-width-UnsignedInteger16-64 | after | 0.014395 | 0.000235 |
| interval-width-UnsignedInteger16-256 | before | 0.016656 | 0.000708 |
| interval-width-UnsignedInteger16-256 | after | 0.017107 | 0.000174 |
| interval-width-UnsignedInteger32-64 | before | 0.014078 | 0.001253 |
| interval-width-UnsignedInteger32-64 | after | 0.014431 | 0.000197 |
| interval-width-UnsignedInteger32-256 | before | 0.017079 | 0.000620 |
| interval-width-UnsignedInteger32-256 | after | 0.017279 | 0.000622 |
| interval-width-UnsignedInteger64-64 | before | 0.014035 | 0.001169 |
| interval-width-UnsignedInteger64-64 | after | 0.014519 | 0.000156 |
| interval-width-UnsignedInteger64-256 | before | 0.017014 | 0.000803 |
| interval-width-UnsignedInteger64-256 | after | 0.017885 | 0.000858 |
| property-seven-24-20-1000-all-ok | before | 0.037575 | 0.001975 |
| property-seven-24-20-1000-all-ok | after | 0.039332 | 0.000589 |
| property-seven-24-20-1000-always-error | before | 0.036381 | 0.001280 |
| property-seven-24-20-1000-always-error | after | 0.038089 | 0.000842 |
| property-distinct-24-20-1000-all-ok | before | 0.036338 | 0.000334 |
| property-distinct-24-20-1000-all-ok | after | 0.038020 | 0.001001 |
| property-distinct-24-20-1000-always-error | before | 0.035617 | 0.000964 |
| property-distinct-24-20-1000-always-error | after | 0.037460 | 0.000311 |
| property-zero-24-20-1000-all-ok | before | 0.036731 | 0.002111 |
| property-zero-24-20-1000-all-ok | after | 0.038393 | 0.000562 |
| property-zero-24-20-1000-always-error | before | 0.035538 | 0.001598 |
| property-zero-24-20-1000-always-error | after | 0.037356 | 0.000710 |
| property-max-24-20-1000-all-ok | before | 0.037171 | 0.002085 |
| property-max-24-20-1000-all-ok | after | 0.039020 | 0.000471 |
| property-max-24-20-1000-always-error | before | 0.035663 | 0.002157 |
| property-max-24-20-1000-always-error | after | 0.037189 | 0.000371 |
| order-string-candidates | before | 0.035784 | 0.001731 |
| order-string-candidates | after | 0.037355 | 0.000351 |
| order-string-all-ok | before | 0.036318 | 0.002325 |
| order-string-all-ok | after | 0.037597 | 0.000328 |
| order-string-always-error | before | 0.035911 | 0.002973 |
| order-string-always-error | after | 0.037352 | 0.001077 |
| order-map-candidates | before | 0.036078 | 0.001546 |
| order-map-candidates | after | 0.038098 | 0.001299 |
| order-map-all-ok | before | 0.036186 | 0.002297 |
| order-map-all-ok | after | 0.038296 | 0.000968 |
| order-map-always-error | before | 0.037758 | 0.000719 |
| order-map-always-error | after | 0.038779 | 0.000971 |
| order-record-candidates | before | 0.038994 | 0.003555 |
| order-record-candidates | after | 0.039995 | 0.001887 |
| order-record-all-ok | before | 0.037154 | 0.001927 |
| order-record-all-ok | after | 0.038227 | 0.000346 |
| order-record-always-error | before | 0.036184 | 0.002395 |
| order-record-always-error | after | 0.038152 | 0.000328 |
| build-string-builder-8-0 | before | 0.016262 | 0.000632 |
| build-string-builder-8-0 | after | 0.016520 | 0.000644 |
| build-string-builder-all-8-0 | before | 0.016127 | 0.000501 |
| build-string-builder-all-8-0 | after | 0.016969 | 0.000540 |
| build-string-concatenate-8-0 | before | 0.016553 | 0.000840 |
| build-string-concatenate-8-0 | after | 0.017040 | 0.000325 |
| build-string-join-8-0 | before | 0.016148 | 0.000542 |
| build-string-join-8-0 | after | 0.016717 | 0.000260 |
| build-list-builder-8-0 | before | 0.016370 | 0.000479 |
| build-list-builder-8-0 | after | 0.016989 | 0.000592 |
| build-list-builder-all-8-0 | before | 0.016379 | 0.000585 |
| build-list-builder-all-8-0 | after | 0.017007 | 0.000386 |
| build-list-concatenate-8-0 | before | 0.016745 | 0.000489 |
| build-list-concatenate-8-0 | after | 0.017073 | 0.001037 |
| build-list-fold-8-0 | before | 0.015992 | 0.000540 |
| build-list-fold-8-0 | after | 0.016641 | 0.000150 |
| build-bytes-builder-8-0 | before | 0.016210 | 0.000584 |
| build-bytes-builder-8-0 | after | 0.016651 | 0.000216 |
| build-bytes-builder-all-8-0 | before | 0.016405 | 0.000907 |
| build-bytes-builder-all-8-0 | after | 0.017180 | 0.000214 |
| build-bytes-concatenate-8-0 | before | 0.016716 | 0.000550 |
| build-bytes-concatenate-8-0 | after | 0.017045 | 0.001389 |
| patterns-integer-100 | before | 0.014534 | 0.001337 |
| patterns-integer-100 | after | 0.015274 | 0.000411 |
| codegen-let-100 | before | 0.017324 | 0.000688 |
| codegen-let-100 | after | 0.017975 | 0.001486 |
| bridge-shared-8 | before | 0.004827 | 0.000225 |
| bridge-shared-8 | after | 0.004962 | 0.000530 |
| external-tests-normal-1 | before | 0.018363 | 0.000570 |
| external-tests-normal-1 | after | 0.019205 | 0.001036 |
| runtime-fib-short | before | 0.018453 | 0.000336 |
| runtime-fib-short | after | 0.018897 | 0.002504 |
| runtime-loop-short | before | 0.024135 | 0.000424 |
| runtime-loop-short | after | 0.025132 | 0.001252 |
| runtime-list-short | before | 0.029672 | 0.000275 |
| runtime-list-short | after | 0.030405 | 0.000625 |
| runtime-tree-short | before | 0.018770 | 0.000424 |
| runtime-tree-short | after | 0.019308 | 0.003263 |
| runtime-eval-short | before | 0.023259 | 0.000648 |
| runtime-eval-short | after | 0.024182 | 0.000685 |
| runtime-string-short | before | 0.017079 | 0.001350 |
| runtime-string-short | after | 0.017634 | 0.000329 |
| runtime-println-short | before | 0.018287 | 0.000623 |
| runtime-println-short | after | 0.018088 | 0.001438 |
| runtime-lines-short | before | 0.016687 | 0.000516 |
| runtime-lines-short | after | 0.017602 | 0.000242 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.8417e-05 | 1.459e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.167e-06 | 2.91e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1626e-05 | 1.708e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.3625e-05 | 1.416e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.375e-06 | 4.18e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7084e-05 | 1.917e-06 |
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
    "after": "d51a7e46d36997e0d2b29a33b73a3f736c618ec1"
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
| functions-main-1000-0 | 判定不能 | None | 0.002070570799999416 |
| functions-main-1000-1 | 判定不能 | None | 0.002066879199999505 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 達成 | 0.001552832999990983 | 0.0027197291999996767 |
| functions-args-1000-1 | 判定不能 | None | 0.002679670800000622 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002096695800000248 |
| functions-modules-1000-1 | 判定不能 | None | 0.0021427583000004804 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 判定不能 | None | 0.002 |
| higher-0-300 | 達成 | 0.0016451249999960282 | 0.0028233000000000177 |
| higher-1-300 | 達成 | 0.001867501000006655 | 0.0030797665999998006 |
| classes-300 | 判定不能 | None | 0.0037408749999997327 |
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
| interval-range-64 | 判定不能 | None | 0.0023368333000007625 |
| interval-range-256 | 判定不能 | None | 0.0036268791000011904 |
| interval-http-0 | 退行の疑い | 0.002848875999987399 | 0.002 |
| interval-http-64 | 退行の疑い | 0.003160666999988848 | 0.0022204375000001164 |
| interval-http-256 | 退行の疑い | 0.003438833000004138 | 0.002976474999999823 |
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
| property-seven-24-20-1000-all-ok | 判定不能 | None | 0.0037574707999993963 |
| property-seven-24-20-1000-always-error | 判定不能 | None | 0.0036381375000004825 |
| property-distinct-24-20-1000-all-ok | 達成 | 0.0016822500000017726 | 0.003633766599999433 |
| property-distinct-24-20-1000-always-error | 達成 | 0.0018428330000119786 | 0.003561679199999901 |
| property-zero-24-20-1000-all-ok | 判定不能 | None | 0.003673091600001044 |
| property-zero-24-20-1000-always-error | 判定不能 | None | 0.0035538291999998254 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003717062499998747 |
| property-max-24-20-1000-always-error | 判定不能 | None | 0.003566320899999198 |
| order-string-candidates | 判定不能 | None | 0.003578374999999312 |
| order-string-all-ok | 判定不能 | None | 0.0036318125000008197 |
| order-string-always-error | 判定不能 | None | 0.0035910958000002326 |
| order-map-candidates | 判定不能 | None | 0.0036077750000004017 |
| order-map-all-ok | 判定不能 | None | 0.003618629200001067 |
| order-map-always-error | 判定不能 | None | 0.0037757500000012104 |
| order-record-candidates | 判定不能 | None | 0.0038993999999988207 |
| order-record-all-ok | 判定不能 | None | 0.003715425000000039 |
| order-record-always-error | 判定不能 | None | 0.0036183625000006715 |
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
| runtime-loop-short | 判定不能 | None | 0.002413462500000208 |
| runtime-list-short | 判定不能 | None | 0.002967208299999413 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0023258708000000183 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 達成 | 0.0009149169999886908 | 0.002 |
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
    "verify": 1.7415467499999977,
    "cli": 5.360240871000045,
    "warmup": 0.5991285850000168,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.953033375000004,
    "cli": 12.01231295800001,
    "warmup": 1.3793718729999824,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.308824708000003,
    "cli": 9.234177709999997,
    "warmup": 1.2788941659999864,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3818948750000004,
    "cli": 3.662098082,
    "warmup": 0.36455750000003206,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.10481337499999199,
    "cli": 0.2865073339999924,
    "warmup": 0.029680499999983567,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.04112499999999386,
    "cli": 0.3456719999999933,
    "warmup": 0.035140292000008344,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.010312750000011306,
    "cli": 0.21181779200000506,
    "warmup": 0.00946233399997709,
    "probe_warmup": 0.008428624999993417,
    "rss": 0,
    "stages": 0.041031416000038234,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.05746274999999912,
    "cli": 0.35795379199998933,
    "warmup": 0.037042874999997366,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.18783220800000322
  },
  "runtime": {
    "verify": 0.34784799999999905,
    "cli": 3.0259671660000436,
    "warmup": 0.33671249899998656,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-29、R20 の段の終わり）

退行の疑いは `interval-http` の三点だけで、既知の原因（R20.0b の Http の import の費用、TODO-304）である。全94入力の after/before の中央値の比は 1.038（R20.0a の後から 1.02〜1.04 で漂う）。

漂いの原因を切り分けた（Apple M4、release、二つの版を交互に走らせた中央値）。CLI の起動だけ（`--version`、40回）は 3.29→3.33 ms で差がほぼない。空の `main` だけのプログラムの `check`（40回）は 12.49→12.97 ms（+3.9%）、`Scope` を import するだけのプログラムは 18.75→19.57 ms（+4.4%）である。計時の探査の段別時間（空のプログラム、30回）では、読み込みと解析・再解析・名前の解決の差は 0.04 ms 以下で、型検査だけが 5.14→5.58 ms（+0.44 ms）伸びた。小さい入力の比が約 1.03 で揃うことと合わせ、漂いは入力の大きさによらない型検査の固定の費用であり、毎回検査する標準ライブラリの本体に R20 の局所の Scope 解析・番号付け・節の添字の選択が加わった分と見立てる（プロファイルで確かめていない）。標準ライブラリを毎回検査する費用は TODO-304 と同じ性質なので、この所見を TODO-304 に加える。
