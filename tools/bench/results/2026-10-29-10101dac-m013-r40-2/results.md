# 版どうしの性能比較

候補: `10101dacf7de5db49229d3d585707da08c768326`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.014188 | 0.000367 |
| functions-main-0-0 | after | 0.014708 | 0.000366 |
| functions-main-0-1 | before | 0.014161 | 0.001378 |
| functions-main-0-1 | after | 0.014290 | 0.000193 |
| functions-main-64-0 | before | 0.015013 | 0.001649 |
| functions-main-64-0 | after | 0.014960 | 0.000277 |
| functions-main-256-0 | before | 0.016802 | 0.000777 |
| functions-main-256-0 | after | 0.016310 | 0.000495 |
| functions-main-1000-0 | before | 0.021302 | 0.000504 |
| functions-main-1000-0 | after | 0.022250 | 0.001329 |
| functions-main-1000-1 | before | 0.021431 | 0.000546 |
| functions-main-1000-1 | after | 0.022160 | 0.001952 |
| functions-args-0-0 | before | 0.014042 | 0.001787 |
| functions-args-0-0 | after | 0.014217 | 0.000145 |
| functions-args-0-1 | before | 0.013477 | 0.001058 |
| functions-args-0-1 | after | 0.014168 | 0.000076 |
| functions-args-1000-0 | before | 0.027482 | 0.000805 |
| functions-args-1000-0 | after | 0.029248 | 0.001323 |
| functions-args-1000-1 | before | 0.028074 | 0.001290 |
| functions-args-1000-1 | after | 0.029576 | 0.002007 |
| functions-modules-0-0 | before | 0.014097 | 0.001046 |
| functions-modules-0-0 | after | 0.014372 | 0.000348 |
| functions-modules-0-1 | before | 0.013500 | 0.001300 |
| functions-modules-0-1 | after | 0.014054 | 0.000701 |
| functions-modules-1000-0 | before | 0.021277 | 0.000550 |
| functions-modules-1000-0 | after | 0.022342 | 0.001536 |
| functions-modules-1000-1 | before | 0.021428 | 0.000165 |
| functions-modules-1000-1 | after | 0.022541 | 0.001349 |
| existing-fib | before | 0.014077 | 0.001075 |
| existing-fib | after | 0.014723 | 0.000304 |
| existing-loop | before | 0.014229 | 0.001186 |
| existing-loop | after | 0.014656 | 0.000294 |
| existing-string | before | 0.014163 | 0.001144 |
| existing-string | after | 0.014813 | 0.000345 |
| higher-0-0 | before | 0.014191 | 0.001424 |
| higher-0-0 | after | 0.014537 | 0.000161 |
| higher-1-0 | before | 0.014589 | 0.001950 |
| higher-1-0 | after | 0.015285 | 0.000363 |
| classes-0 | before | 0.018371 | 0.000639 |
| classes-0 | after | 0.020543 | 0.001247 |
| higher-0-300 | before | 0.028784 | 0.000430 |
| higher-0-300 | after | 0.030155 | 0.001349 |
| higher-1-300 | before | 0.031674 | 0.000373 |
| higher-1-300 | after | 0.032749 | 0.000231 |
| classes-300 | before | 0.039586 | 0.001361 |
| classes-300 | after | 0.042075 | 0.000939 |
| depth-0-8 | before | 0.015868 | 0.000585 |
| depth-0-8 | after | 0.017089 | 0.002821 |
| depth-1-8 | before | 0.016118 | 0.000739 |
| depth-1-8 | after | 0.016527 | 0.000203 |
| f1-nofail-call | before | 0.014480 | 0.000504 |
| f1-nofail-call | after | 0.015125 | 0.000182 |
| f1-join-effects | before | 0.014947 | 0.000910 |
| f1-join-effects | after | 0.015240 | 0.000657 |
| control-16.3 | before | 0.013912 | 0.000542 |
| control-16.3 | after | 0.014238 | 0.000213 |
| interval-bind-64 | before | 0.014284 | 0.000829 |
| interval-bind-64 | after | 0.014518 | 0.000381 |
| interval-bind-256 | before | 0.014634 | 0.001200 |
| interval-bind-256 | after | 0.015078 | 0.000337 |
| interval-add-64 | before | 0.014158 | 0.000853 |
| interval-add-64 | after | 0.014662 | 0.000247 |
| interval-add-256 | before | 0.015755 | 0.000667 |
| interval-add-256 | after | 0.015960 | 0.000433 |
| interval-flow-64 | before | 0.014910 | 0.001104 |
| interval-flow-64 | after | 0.015414 | 0.000195 |
| interval-flow-256 | before | 0.017860 | 0.000875 |
| interval-flow-256 | after | 0.019414 | 0.001065 |
| interval-range-0 | before | 0.020501 | 0.000917 |
| interval-range-0 | after | 0.023484 | 0.002627 |
| interval-range-64 | before | 0.026992 | 0.000796 |
| interval-range-64 | after | 0.028629 | 0.002892 |
| interval-range-256 | before | 0.040856 | 0.002517 |
| interval-range-256 | after | 0.043998 | 0.001115 |
| interval-http-0 | before | 0.022215 | 0.000581 |
| interval-http-0 | after | 0.025333 | 0.002046 |
| interval-http-64 | before | 0.025149 | 0.000721 |
| interval-http-64 | after | 0.027604 | 0.003340 |
| interval-http-256 | before | 0.031613 | 0.002728 |
| interval-http-256 | after | 0.034689 | 0.002925 |
| interval-width-Integer8-64 | before | 0.014875 | 0.000749 |
| interval-width-Integer8-64 | after | 0.015093 | 0.000225 |
| interval-width-Integer8-256 | before | 0.018031 | 0.000484 |
| interval-width-Integer8-256 | after | 0.018489 | 0.001086 |
| interval-width-Integer16-64 | before | 0.014909 | 0.001439 |
| interval-width-Integer16-64 | after | 0.015335 | 0.000298 |
| interval-width-Integer16-256 | before | 0.018480 | 0.000682 |
| interval-width-Integer16-256 | after | 0.018877 | 0.001030 |
| interval-width-Integer32-64 | before | 0.014940 | 0.000920 |
| interval-width-Integer32-64 | after | 0.015189 | 0.000394 |
| interval-width-Integer32-256 | before | 0.017755 | 0.000355 |
| interval-width-Integer32-256 | after | 0.018091 | 0.000616 |
| interval-width-Integer64-64 | before | 0.014786 | 0.002051 |
| interval-width-Integer64-64 | after | 0.015259 | 0.000268 |
| interval-width-Integer64-256 | before | 0.017469 | 0.000531 |
| interval-width-Integer64-256 | after | 0.018240 | 0.000617 |
| interval-width-UnsignedInteger16-64 | before | 0.014777 | 0.001179 |
| interval-width-UnsignedInteger16-64 | after | 0.015263 | 0.000215 |
| interval-width-UnsignedInteger16-256 | before | 0.017417 | 0.000642 |
| interval-width-UnsignedInteger16-256 | after | 0.018508 | 0.001047 |
| interval-width-UnsignedInteger32-64 | before | 0.015280 | 0.000750 |
| interval-width-UnsignedInteger32-64 | after | 0.015559 | 0.000771 |
| interval-width-UnsignedInteger32-256 | before | 0.018684 | 0.000747 |
| interval-width-UnsignedInteger32-256 | after | 0.018944 | 0.002260 |
| interval-width-UnsignedInteger64-64 | before | 0.015079 | 0.001579 |
| interval-width-UnsignedInteger64-64 | after | 0.015437 | 0.000336 |
| interval-width-UnsignedInteger64-256 | before | 0.017236 | 0.000724 |
| interval-width-UnsignedInteger64-256 | after | 0.017900 | 0.000605 |
| property-seven-24-20-1000-all-ok | before | 0.038195 | 0.003022 |
| property-seven-24-20-1000-all-ok | after | 0.042558 | 0.000493 |
| property-seven-24-20-1000-always-error | before | 0.036676 | 0.002540 |
| property-seven-24-20-1000-always-error | after | 0.040771 | 0.000617 |
| property-distinct-24-20-1000-all-ok | before | 0.037552 | 0.001331 |
| property-distinct-24-20-1000-all-ok | after | 0.040947 | 0.000530 |
| property-distinct-24-20-1000-always-error | before | 0.036140 | 0.002316 |
| property-distinct-24-20-1000-always-error | after | 0.040083 | 0.000383 |
| property-zero-24-20-1000-all-ok | before | 0.037874 | 0.001348 |
| property-zero-24-20-1000-all-ok | after | 0.041734 | 0.000568 |
| property-zero-24-20-1000-always-error | before | 0.036026 | 0.002084 |
| property-zero-24-20-1000-always-error | after | 0.040513 | 0.000683 |
| property-max-24-20-1000-all-ok | before | 0.038100 | 0.004154 |
| property-max-24-20-1000-all-ok | after | 0.041809 | 0.001781 |
| property-max-24-20-1000-always-error | before | 0.038873 | 0.002054 |
| property-max-24-20-1000-always-error | after | 0.043990 | 0.002587 |
| order-string-candidates | before | 0.039996 | 0.002437 |
| order-string-candidates | after | 0.044036 | 0.000395 |
| order-string-all-ok | before | 0.041193 | 0.002677 |
| order-string-all-ok | after | 0.045102 | 0.001369 |
| order-string-always-error | before | 0.040318 | 0.003030 |
| order-string-always-error | after | 0.043745 | 0.001441 |
| order-map-candidates | before | 0.036891 | 0.002334 |
| order-map-candidates | after | 0.040685 | 0.000401 |
| order-map-all-ok | before | 0.036929 | 0.001511 |
| order-map-all-ok | after | 0.040850 | 0.000206 |
| order-map-always-error | before | 0.036747 | 0.000965 |
| order-map-always-error | after | 0.040917 | 0.000695 |
| order-record-candidates | before | 0.037007 | 0.001425 |
| order-record-candidates | after | 0.041060 | 0.000493 |
| order-record-all-ok | before | 0.037166 | 0.002918 |
| order-record-all-ok | after | 0.041126 | 0.000560 |
| order-record-always-error | before | 0.037237 | 0.001956 |
| order-record-always-error | after | 0.041168 | 0.000219 |
| build-string-builder-8-0 | before | 0.017254 | 0.003981 |
| build-string-builder-8-0 | after | 0.017516 | 0.000380 |
| build-string-builder-all-8-0 | before | 0.017176 | 0.000311 |
| build-string-builder-all-8-0 | after | 0.017434 | 0.001570 |
| build-string-concatenate-8-0 | before | 0.016510 | 0.000421 |
| build-string-concatenate-8-0 | after | 0.017762 | 0.000983 |
| build-string-join-8-0 | before | 0.016472 | 0.000395 |
| build-string-join-8-0 | after | 0.017444 | 0.000830 |
| build-list-builder-8-0 | before | 0.016740 | 0.000495 |
| build-list-builder-8-0 | after | 0.017612 | 0.001067 |
| build-list-builder-all-8-0 | before | 0.018374 | 0.001183 |
| build-list-builder-all-8-0 | after | 0.020066 | 0.001521 |
| build-list-concatenate-8-0 | before | 0.019240 | 0.000598 |
| build-list-concatenate-8-0 | after | 0.019872 | 0.001709 |
| build-list-fold-8-0 | before | 0.018672 | 0.000152 |
| build-list-fold-8-0 | after | 0.019572 | 0.001567 |
| build-bytes-builder-8-0 | before | 0.018893 | 0.000389 |
| build-bytes-builder-8-0 | after | 0.019806 | 0.000478 |
| build-bytes-builder-all-8-0 | before | 0.018853 | 0.000981 |
| build-bytes-builder-all-8-0 | after | 0.019431 | 0.002703 |
| build-bytes-concatenate-8-0 | before | 0.018342 | 0.000938 |
| build-bytes-concatenate-8-0 | after | 0.019966 | 0.001859 |
| patterns-integer-100 | before | 0.014990 | 0.000730 |
| patterns-integer-100 | after | 0.015545 | 0.000403 |
| codegen-let-100 | before | 0.017921 | 0.000590 |
| codegen-let-100 | after | 0.018727 | 0.001958 |
| bridge-shared-8 | before | 0.005189 | 0.000236 |
| bridge-shared-8 | after | 0.005238 | 0.000985 |
| external-tests-normal-1 | before | 0.019246 | 0.000454 |
| external-tests-normal-1 | after | 0.019636 | 0.001773 |
| runtime-fib-short | before | 0.018989 | 0.000649 |
| runtime-fib-short | after | 0.019690 | 0.002295 |
| runtime-loop-short | before | 0.024513 | 0.000537 |
| runtime-loop-short | after | 0.025404 | 0.001569 |
| runtime-list-short | before | 0.029997 | 0.000487 |
| runtime-list-short | after | 0.030700 | 0.000416 |
| runtime-tree-short | before | 0.019410 | 0.000514 |
| runtime-tree-short | after | 0.019984 | 0.001371 |
| runtime-eval-short | before | 0.022916 | 0.000155 |
| runtime-eval-short | after | 0.023634 | 0.001887 |
| runtime-string-short | before | 0.017581 | 0.000459 |
| runtime-string-short | after | 0.018133 | 0.001743 |
| runtime-println-short | before | 0.018015 | 0.000435 |
| runtime-println-short | after | 0.018699 | 0.001158 |
| runtime-lines-short | before | 0.017211 | 0.000683 |
| runtime-lines-short | after | 0.019397 | 0.001392 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.8291e-05 | 2.333e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.25e-06 | 4.59e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 2.1541e-05 | 3.001e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.4375e-05 | 1.208e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.208e-06 | 5e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.7583e-05 | 1.708e-06 |
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
    "after": "10101dacf7de5db49229d3d585707da08c768326"
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
| functions-main-1000-0 | 判定不能 | None | 0.0021302417000001127 |
| functions-main-1000-1 | 判定不能 | None | 0.002143095899999992 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 判定不能 | None | 0.002 |
| functions-args-1000-0 | 判定不能 | None | 0.0027481749999992647 |
| functions-args-1000-1 | 判定不能 | None | 0.0028073667000001025 |
| functions-modules-0-0 | 判定不能 | None | 0.002 |
| functions-modules-0-1 | 判定不能 | None | 0.002 |
| functions-modules-1000-0 | 判定不能 | None | 0.002127724999999714 |
| functions-modules-1000-1 | 判定不能 | None | 0.002142766599999391 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 判定不能 | None | 0.002 |
| existing-string | 判定不能 | None | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 退行の疑い | 0.002172000000001617 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.0028784250000001067 |
| higher-1-300 | 達成 | 0.0010747500000150012 | 0.0031674499999994055 |
| classes-300 | 達成 | 0.002489416000003075 | 0.003958570899999359 |
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
| interval-range-0 | 判定不能 | None | 0.0020500916000003146 |
| interval-range-64 | 判定不能 | None | 0.0026991541000001007 |
| interval-range-256 | 判定不能 | None | 0.00408561250000048 |
| interval-http-0 | 退行の疑い | 0.003118708000002357 | 0.002221470899999645 |
| interval-http-64 | 判定不能 | None | 0.002514883400000656 |
| interval-http-256 | 判定不能 | None | 0.0031613334000013538 |
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
| property-seven-24-20-1000-all-ok | 退行の疑い | 0.0043635420000072145 | 0.0038194707999991808 |
| property-seven-24-20-1000-always-error | 退行の疑い | 0.004095375000005674 | 0.003667583299998967 |
| property-distinct-24-20-1000-all-ok | 達成 | 0.003394916000004855 | 0.0037552125000004824 |
| property-distinct-24-20-1000-always-error | 退行の疑い | 0.003943750000004798 | 0.0036139624999989906 |
| property-zero-24-20-1000-all-ok | 退行の疑い | 0.003860666999997875 | 0.0037873666999999503 |
| property-zero-24-20-1000-always-error | 退行の疑い | 0.004487625000010098 | 0.003602562499999351 |
| property-max-24-20-1000-all-ok | 判定不能 | None | 0.003810024999999939 |
| property-max-24-20-1000-always-error | 退行の疑い | 0.005116792000009696 | 0.0038873457999997643 |
| order-string-candidates | 退行の疑い | 0.004039625000004321 | 0.003999604099999487 |
| order-string-all-ok | 判定不能 | None | 0.0041192874999993025 |
| order-string-always-error | 判定不能 | None | 0.004031770800000345 |
| order-map-candidates | 退行の疑い | 0.0037941660000058164 | 0.0036890791999994125 |
| order-map-all-ok | 退行の疑い | 0.003920625000006339 | 0.0036928958000004286 |
| order-map-always-error | 退行の疑い | 0.004170041999998375 | 0.0036746500000006677 |
| order-record-candidates | 退行の疑い | 0.004053207999987762 | 0.0037006709000010577 |
| order-record-all-ok | 退行の疑い | 0.003959999999992192 | 0.0037165874999999463 |
| order-record-always-error | 退行の疑い | 0.003931416000000354 | 0.0037236667000001946 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 達成 | 0.0009130419999934247 | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 判定不能 | None | 0.00245129999999989 |
| runtime-list-short | 判定不能 | None | 0.002999704200000508 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.0022916250000008633 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 退行の疑い | 0.0021857910000164793 | 0.002 |
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
    "verify": 1.7295056250000016,
    "cli": 5.534128127000017,
    "warmup": 0.6193736219999693,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 3.009643957999998,
    "cli": 12.855026252000044,
    "warmup": 1.4620340429999885,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3563722079999962,
    "cli": 9.777543457000021,
    "warmup": 1.3600630389999964,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3832804160000052,
    "cli": 4.022397998999935,
    "warmup": 0.39843046000001436,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.11005083300000251,
    "cli": 0.2981467500000008,
    "warmup": 0.031137333000003764,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.04157629200000201,
    "cli": 0.3589705409999908,
    "warmup": 0.03611283299997581,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.012412042000008228,
    "cli": 0.21654912500000023,
    "warmup": 0.009510374999990745,
    "probe_warmup": 0.008740832999990289,
    "rss": 0,
    "stages": 0.04276766700002099,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.06142316599999731,
    "cli": 0.3679173339999977,
    "warmup": 0.03705804199998397,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.19474442000003478
  },
  "runtime": {
    "verify": 0.3503577500000006,
    "cli": 3.0977540400000123,
    "warmup": 0.3463598340000118,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```

## 取りまとめの確かめ（2026-10-29）

九つの区分の出力の照合はすべて通った。退行の疑いの族は R40.1 の後の比較と同じ（Trait を使う点は設計者が採った費用、`runtime-lines-short` は File が Scope を読む分と TODO-304、`interval-http-*` は既知）。R40.2 は主に報告の形と診断の変更である。実行の経路の変更は、範囲付きの File の入口が資源の停止の報告へ自分の名前を渡すことだけである（R40 の段の独立レビューの指摘で訂正）。全94入力の after/before の中央値の比は 1.045。
