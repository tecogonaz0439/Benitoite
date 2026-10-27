# 版どうしの性能比較

候補: `dc171a72882bec1c4ac4f8a31a11b05e11c235a3`。quick=False。

quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。
入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。

| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |
|---|---|---:|---:|
| functions-main-0-0 | before | 0.013749 | 0.000443 |
| functions-main-0-0 | after | 0.012978 | 0.000549 |
| functions-main-0-1 | before | 0.013819 | 0.000460 |
| functions-main-0-1 | after | 0.013179 | 0.000422 |
| functions-main-64-0 | before | 0.014113 | 0.000326 |
| functions-main-64-0 | after | 0.013217 | 0.000885 |
| functions-main-256-0 | before | 0.017136 | 0.000557 |
| functions-main-256-0 | after | 0.015166 | 0.000370 |
| functions-main-1000-0 | before | 0.031586 | 0.000389 |
| functions-main-1000-0 | after | 0.020462 | 0.000824 |
| functions-main-1000-1 | before | 0.031673 | 0.000950 |
| functions-main-1000-1 | after | 0.020501 | 0.000744 |
| functions-args-0-0 | before | 0.013500 | 0.000615 |
| functions-args-0-0 | after | 0.012832 | 0.000151 |
| functions-args-0-1 | before | 0.013488 | 0.000426 |
| functions-args-0-1 | after | 0.012779 | 0.000142 |
| functions-args-1000-0 | before | 0.048138 | 0.000422 |
| functions-args-1000-0 | after | 0.026574 | 0.000376 |
| functions-args-1000-1 | before | 0.048378 | 0.000845 |
| functions-args-1000-1 | after | 0.026602 | 0.000275 |
| functions-modules-0-0 | before | 0.013511 | 0.000268 |
| functions-modules-0-0 | after | 0.012695 | 0.000245 |
| functions-modules-0-1 | before | 0.013515 | 0.000266 |
| functions-modules-0-1 | after | 0.012725 | 0.000384 |
| functions-modules-1000-0 | before | 0.025114 | 0.000083 |
| functions-modules-1000-0 | after | 0.020752 | 0.000166 |
| functions-modules-1000-1 | before | 0.025402 | 0.000773 |
| functions-modules-1000-1 | after | 0.020704 | 0.000323 |
| existing-fib | before | 0.013880 | 0.000334 |
| existing-fib | after | 0.013328 | 0.001009 |
| existing-loop | before | 0.014097 | 0.000401 |
| existing-loop | after | 0.013436 | 0.000224 |
| existing-string | before | 0.013973 | 0.000132 |
| existing-string | after | 0.013463 | 0.000372 |
| higher-0-0 | before | 0.013599 | 0.000499 |
| higher-0-0 | after | 0.012925 | 0.000327 |
| higher-1-0 | before | 0.014152 | 0.000195 |
| higher-1-0 | after | 0.013930 | 0.000374 |
| classes-0 | before | 0.019349 | 0.000204 |
| classes-0 | after | 0.017555 | 0.000164 |
| higher-0-300 | before | 0.027208 | 0.000553 |
| higher-0-300 | after | 0.028496 | 0.000814 |
| higher-1-300 | before | 0.029561 | 0.000342 |
| higher-1-300 | after | 0.030812 | 0.000315 |
| classes-300 | before | 0.038434 | 0.000547 |
| classes-300 | after | 0.036990 | 0.000311 |
| depth-0-8 | before | 0.014830 | 0.000305 |
| depth-0-8 | after | 0.014391 | 0.000235 |
| depth-1-8 | before | 0.015256 | 0.000656 |
| depth-1-8 | after | 0.014721 | 0.000249 |
| f1-nofail-call | before | 0.014413 | 0.000522 |
| f1-nofail-call | after | 0.013816 | 0.000197 |
| f1-join-effects | before | 0.014787 | 0.000246 |
| f1-join-effects | after | 0.013999 | 0.000642 |
| control-16.3 | before | 0.013554 | 0.000432 |
| control-16.3 | after | 0.012875 | 0.000139 |
| interval-bind-64 | before | 0.013483 | 0.000484 |
| interval-bind-64 | after | 0.013015 | 0.000433 |
| interval-bind-256 | before | 0.014259 | 0.000392 |
| interval-bind-256 | after | 0.013565 | 0.000649 |
| interval-add-64 | before | 0.013695 | 0.000172 |
| interval-add-64 | after | 0.013069 | 0.000089 |
| interval-add-256 | before | 0.015301 | 0.000421 |
| interval-add-256 | after | 0.014766 | 0.000187 |
| interval-flow-64 | before | 0.014480 | 0.000801 |
| interval-flow-64 | after | 0.013962 | 0.000284 |
| interval-flow-256 | before | 0.016934 | 0.000197 |
| interval-flow-256 | after | 0.017077 | 0.000444 |
| interval-range-0 | before | 0.020846 | 0.000971 |
| interval-range-0 | after | 0.018536 | 0.000293 |
| interval-range-64 | before | 0.024979 | 0.000459 |
| interval-range-64 | after | 0.022760 | 0.001055 |
| interval-range-256 | before | 0.037978 | 0.001019 |
| interval-range-256 | after | 0.035586 | 0.000587 |
| interval-http-0 | before | 0.021269 | 0.000331 |
| interval-http-0 | after | 0.018724 | 0.000293 |
| interval-http-64 | before | 0.023908 | 0.000541 |
| interval-http-64 | after | 0.022132 | 0.000426 |
| interval-http-256 | before | 0.031894 | 0.000405 |
| interval-http-256 | after | 0.029751 | 0.000286 |
| interval-width-Integer8-64 | before | 0.014387 | 0.000214 |
| interval-width-Integer8-64 | after | 0.013951 | 0.000406 |
| interval-width-Integer8-256 | before | 0.017458 | 0.000731 |
| interval-width-Integer8-256 | after | 0.017102 | 0.000263 |
| interval-width-Integer16-64 | before | 0.014323 | 0.000186 |
| interval-width-Integer16-64 | after | 0.013701 | 0.000284 |
| interval-width-Integer16-256 | before | 0.017309 | 0.000426 |
| interval-width-Integer16-256 | after | 0.016806 | 0.000493 |
| interval-width-Integer32-64 | before | 0.014577 | 0.000336 |
| interval-width-Integer32-64 | after | 0.014342 | 0.000658 |
| interval-width-Integer32-256 | before | 0.017388 | 0.000354 |
| interval-width-Integer32-256 | after | 0.017071 | 0.001191 |
| interval-width-Integer64-64 | before | 0.014725 | 0.000316 |
| interval-width-Integer64-64 | after | 0.014086 | 0.000263 |
| interval-width-Integer64-256 | before | 0.017267 | 0.000269 |
| interval-width-Integer64-256 | after | 0.016523 | 0.000498 |
| interval-width-UnsignedInteger16-64 | before | 0.014245 | 0.000205 |
| interval-width-UnsignedInteger16-64 | after | 0.013738 | 0.000257 |
| interval-width-UnsignedInteger16-256 | before | 0.017026 | 0.000956 |
| interval-width-UnsignedInteger16-256 | after | 0.016691 | 0.000256 |
| interval-width-UnsignedInteger32-64 | before | 0.014452 | 0.000180 |
| interval-width-UnsignedInteger32-64 | after | 0.014253 | 0.000483 |
| interval-width-UnsignedInteger32-256 | before | 0.017205 | 0.000935 |
| interval-width-UnsignedInteger32-256 | after | 0.016875 | 0.000335 |
| interval-width-UnsignedInteger64-64 | before | 0.014577 | 0.000396 |
| interval-width-UnsignedInteger64-64 | after | 0.014155 | 0.000426 |
| interval-width-UnsignedInteger64-256 | before | 0.017021 | 0.000567 |
| interval-width-UnsignedInteger64-256 | after | 0.016618 | 0.000448 |
| property-seven-24-20-1000-all-ok | before | 0.040404 | 0.000571 |
| property-seven-24-20-1000-all-ok | after | 0.037378 | 0.000649 |
| property-seven-24-20-1000-always-error | before | 0.039052 | 0.000552 |
| property-seven-24-20-1000-always-error | after | 0.036171 | 0.001084 |
| property-distinct-24-20-1000-all-ok | before | 0.039280 | 0.001824 |
| property-distinct-24-20-1000-all-ok | after | 0.036183 | 0.000634 |
| property-distinct-24-20-1000-always-error | before | 0.038814 | 0.000328 |
| property-distinct-24-20-1000-always-error | after | 0.035875 | 0.000781 |
| property-zero-24-20-1000-all-ok | before | 0.040063 | 0.000555 |
| property-zero-24-20-1000-all-ok | after | 0.037874 | 0.001183 |
| property-zero-24-20-1000-always-error | before | 0.039036 | 0.000311 |
| property-zero-24-20-1000-always-error | after | 0.035621 | 0.000462 |
| property-max-24-20-1000-all-ok | before | 0.040269 | 0.000489 |
| property-max-24-20-1000-all-ok | after | 0.037171 | 0.000334 |
| property-max-24-20-1000-always-error | before | 0.039122 | 0.001232 |
| property-max-24-20-1000-always-error | after | 0.035696 | 0.000331 |
| order-string-candidates | before | 0.038400 | 0.000347 |
| order-string-candidates | after | 0.035236 | 0.000384 |
| order-string-all-ok | before | 0.039138 | 0.000847 |
| order-string-all-ok | after | 0.035601 | 0.000457 |
| order-string-always-error | before | 0.038999 | 0.000390 |
| order-string-always-error | after | 0.035278 | 0.000477 |
| order-map-candidates | before | 0.038958 | 0.000646 |
| order-map-candidates | after | 0.035809 | 0.000329 |
| order-map-all-ok | before | 0.039296 | 0.000554 |
| order-map-all-ok | after | 0.036145 | 0.000337 |
| order-map-always-error | before | 0.039645 | 0.001101 |
| order-map-always-error | after | 0.036507 | 0.001346 |
| order-record-candidates | before | 0.039585 | 0.000752 |
| order-record-candidates | after | 0.036071 | 0.000547 |
| order-record-all-ok | before | 0.040550 | 0.000698 |
| order-record-all-ok | after | 0.036713 | 0.000568 |
| order-record-always-error | before | 0.039271 | 0.000514 |
| order-record-always-error | after | 0.036228 | 0.000726 |
| build-string-builder-8-0 | before | 0.016088 | 0.000313 |
| build-string-builder-8-0 | after | 0.015469 | 0.000496 |
| build-string-builder-all-8-0 | before | 0.016216 | 0.000171 |
| build-string-builder-all-8-0 | after | 0.015796 | 0.000552 |
| build-string-concatenate-8-0 | before | 0.016412 | 0.000450 |
| build-string-concatenate-8-0 | after | 0.015990 | 0.000394 |
| build-string-join-8-0 | before | 0.016475 | 0.000280 |
| build-string-join-8-0 | after | 0.016090 | 0.000639 |
| build-list-builder-8-0 | before | 0.016637 | 0.000436 |
| build-list-builder-8-0 | after | 0.016363 | 0.000276 |
| build-list-builder-all-8-0 | before | 0.017135 | 0.004018 |
| build-list-builder-all-8-0 | after | 0.016542 | 0.000282 |
| build-list-concatenate-8-0 | before | 0.017514 | 0.000469 |
| build-list-concatenate-8-0 | after | 0.016429 | 0.000140 |
| build-list-fold-8-0 | before | 0.016507 | 0.000309 |
| build-list-fold-8-0 | after | 0.016204 | 0.000493 |
| build-bytes-builder-8-0 | before | 0.016214 | 0.000593 |
| build-bytes-builder-8-0 | after | 0.015704 | 0.000352 |
| build-bytes-builder-all-8-0 | before | 0.016372 | 0.000226 |
| build-bytes-builder-all-8-0 | after | 0.015714 | 0.001160 |
| build-bytes-concatenate-8-0 | before | 0.016451 | 0.000353 |
| build-bytes-concatenate-8-0 | after | 0.016052 | 0.000742 |
| patterns-integer-100 | before | 0.014747 | 0.000281 |
| patterns-integer-100 | after | 0.014118 | 0.000148 |
| codegen-let-100 | before | 0.017361 | 0.000387 |
| codegen-let-100 | after | 0.016757 | 0.000089 |
| bridge-shared-8 | before | 0.004668 | 0.000247 |
| bridge-shared-8 | after | 0.004606 | 0.000445 |
| external-tests-normal-1 | before | 0.018096 | 0.000740 |
| external-tests-normal-1 | after | 0.017886 | 0.000351 |
| runtime-fib-short | before | 0.018393 | 0.000535 |
| runtime-fib-short | after | 0.017845 | 0.000673 |
| runtime-loop-short | before | 0.024143 | 0.000380 |
| runtime-loop-short | after | 0.023367 | 0.000315 |
| runtime-list-short | before | 0.029574 | 0.000156 |
| runtime-list-short | after | 0.029479 | 0.000531 |
| runtime-tree-short | before | 0.018783 | 0.000298 |
| runtime-tree-short | after | 0.018240 | 0.000277 |
| runtime-eval-short | before | 0.022499 | 0.000754 |
| runtime-eval-short | after | 0.022300 | 0.000201 |
| runtime-string-short | before | 0.017514 | 0.000295 |
| runtime-string-short | after | 0.017392 | 0.000215 |
| runtime-println-short | before | 0.017804 | 0.000342 |
| runtime-println-short | after | 0.017643 | 0.001404 |
| runtime-lines-short | before | 0.017204 | 0.000432 |
| runtime-lines-short | after | 0.016783 | 0.001204 |

## 段・変換・計数の観測

| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |
|---|---|---|---|---:|---:|---:|
| bridge_to_heap | seconds | bridge-shared-8 | before | 5 | 1.3917e-05 | 1.083e-06 |
| bridge_from_heap | seconds | bridge-shared-8 | before | 5 | 3.375e-06 | 8.33e-07 |
| bridge_time | seconds | bridge-shared-8 | before | 5 | 1.8291e-05 | 2.083e-06 |
| unique_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| edges | count | bridge-shared-8 | before | 5 | 16 | 0 |
| heap_nodes | count | bridge-shared-8 | before | 5 | 9 | 0 |
| observation | count | bridge-shared-8 | before | 5 | 7 | 0 |
| bridge_to_heap | seconds | bridge-shared-8 | after | 5 | 1.5791e-05 | 6.66e-07 |
| bridge_from_heap | seconds | bridge-shared-8 | after | 5 | 3.125e-06 | 1.67e-07 |
| bridge_time | seconds | bridge-shared-8 | after | 5 | 1.8874e-05 | 1.374e-06 |
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
    "after": "dc171a72882bec1c4ac4f8a31a11b05e11c235a3"
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
| functions-main-256-0 | 達成 | -0.001970333000002711 | 0.002 |
| functions-main-1000-0 | 達成 | -0.01112491699998941 | 0.0031586416999999757 |
| functions-main-1000-1 | 達成 | -0.01117183400000954 | 0.003167266700000937 |
| functions-args-0-0 | 判定不能 | None | 0.002 |
| functions-args-0-1 | 達成 | -0.0007085000000017772 | 0.002 |
| functions-args-1000-0 | 達成 | -0.021564041999994288 | 0.004813816699999052 |
| functions-args-1000-1 | 達成 | -0.021776082999991786 | 0.004837820800000259 |
| functions-modules-0-0 | 達成 | -0.0008160419999967417 | 0.002 |
| functions-modules-0-1 | 達成 | -0.0007899169999916467 | 0.002 |
| functions-modules-1000-0 | 達成 | -0.004362041999996791 | 0.0025113916999998766 |
| functions-modules-1000-1 | 達成 | -0.004697915999997804 | 0.00254022080000027 |
| existing-fib | 判定不能 | None | 0.002 |
| existing-loop | 達成 | -0.0006617910000272786 | 0.002 |
| existing-string | 達成 | -0.0005097080000098231 | 0.002 |
| higher-0-0 | 判定不能 | None | 0.002 |
| higher-1-0 | 判定不能 | None | 0.002 |
| classes-0 | 達成 | -0.0017938739999863174 | 0.002 |
| higher-0-300 | 判定不能 | None | 0.002720808299997657 |
| higher-1-300 | 達成 | 0.0012504170000227077 | 0.002956133299997532 |
| classes-300 | 達成 | -0.0014446249999764404 | 0.0038434499999993933 |
| depth-0-8 | 判定不能 | None | 0.002 |
| depth-1-8 | 判定不能 | None | 0.002 |
| f1-nofail-call | 判定不能 | None | 0.002 |
| f1-join-effects | 判定不能 | None | 0.002 |
| control-16.3 | 達成 | -0.0006792920000009417 | 0.002 |
| interval-bind-64 | 判定不能 | None | 0.002 |
| interval-bind-256 | 判定不能 | None | 0.002 |
| interval-add-64 | 達成 | -0.0006262919999926453 | 0.002 |
| interval-add-256 | 判定不能 | None | 0.002 |
| interval-flow-64 | 判定不能 | None | 0.002 |
| interval-flow-256 | 判定不能 | None | 0.002 |
| interval-range-0 | 達成 | -0.002309583999988263 | 0.0020845833999999287 |
| interval-range-64 | 達成 | -0.0022185840000190638 | 0.0024978667000027602 |
| interval-range-256 | 達成 | -0.0023920829999894977 | 0.003797812499999509 |
| interval-http-0 | 達成 | -0.002544833000001745 | 0.002126870800000802 |
| interval-http-64 | 達成 | -0.0017763749999915035 | 0.0023908000000005813 |
| interval-http-256 | 達成 | -0.0021432489999710924 | 0.003189420799998288 |
| interval-width-Integer8-64 | 判定不能 | None | 0.002 |
| interval-width-Integer8-256 | 判定不能 | None | 0.002 |
| interval-width-Integer16-64 | 達成 | -0.0006212499999946886 | 0.002 |
| interval-width-Integer16-256 | 判定不能 | None | 0.002 |
| interval-width-Integer32-64 | 判定不能 | None | 0.002 |
| interval-width-Integer32-256 | 判定不能 | None | 0.002 |
| interval-width-Integer64-64 | 達成 | -0.000639166000013347 | 0.002 |
| interval-width-Integer64-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger16-64 | 達成 | -0.0005071660000055545 | 0.002 |
| interval-width-UnsignedInteger16-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger32-256 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-64 | 判定不能 | None | 0.002 |
| interval-width-UnsignedInteger64-256 | 判定不能 | None | 0.002 |
| property-seven-24-20-1000-all-ok | 達成 | -0.0030259579999949437 | 0.004040383299999917 |
| property-seven-24-20-1000-always-error | 達成 | -0.0028811249999876054 | 0.0039051790999991456 |
| property-distinct-24-20-1000-all-ok | 達成 | -0.0030971249999822703 | 0.00392799579999803 |
| property-distinct-24-20-1000-always-error | 達成 | -0.002938666000034118 | 0.003881412500001602 |
| property-zero-24-20-1000-all-ok | 達成 | -0.0021887930000445976 | 0.0040062834000025305 |
| property-zero-24-20-1000-always-error | 達成 | -0.003414958999968576 | 0.003903591699997833 |
| property-max-24-20-1000-all-ok | 達成 | -0.0030981660000009015 | 0.004026933299999769 |
| property-max-24-20-1000-always-error | 達成 | -0.0034265829999924335 | 0.003912237500000515 |
| order-string-candidates | 達成 | -0.0031642920000365393 | 0.0038400417000019615 |
| order-string-all-ok | 達成 | -0.003537583999985827 | 0.003913833400000045 |
| order-string-always-error | 達成 | -0.003720874999970647 | 0.0038998999999989795 |
| order-map-candidates | 達成 | -0.0031497490000162998 | 0.00389584579999962 |
| order-map-all-ok | 達成 | -0.0031508739999992486 | 0.003929608300001064 |
| order-map-always-error | 達成 | -0.0031379159999858075 | 0.003964458299998342 |
| order-record-candidates | 達成 | -0.0035139990000061516 | 0.0039584791000010005 |
| order-record-all-ok | 達成 | -0.003836709000012206 | 0.004054962500001125 |
| order-record-always-error | 達成 | -0.003043375000004289 | 0.003927091700001029 |
| build-string-builder-8-0 | 判定不能 | None | 0.002 |
| build-string-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-string-concatenate-8-0 | 判定不能 | None | 0.002 |
| build-string-join-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-8-0 | 判定不能 | None | 0.002 |
| build-list-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-list-concatenate-8-0 | 達成 | -0.001085208999995757 | 0.002 |
| build-list-fold-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-8-0 | 判定不能 | None | 0.002 |
| build-bytes-builder-all-8-0 | 判定不能 | None | 0.002 |
| build-bytes-concatenate-8-0 | 判定不能 | None | 0.002 |
| runtime-fib-short | 判定不能 | None | 0.002 |
| runtime-loop-short | 達成 | -0.0007765830000039387 | 0.002414333300001204 |
| runtime-list-short | 判定不能 | None | 0.0029573875000011188 |
| runtime-tree-short | 判定不能 | None | 0.002 |
| runtime-eval-short | 判定不能 | None | 0.002249862499999722 |
| runtime-string-short | 判定不能 | None | 0.002 |
| runtime-println-short | 判定不能 | None | 0.002 |
| runtime-lines-short | 判定不能 | None | 0.002 |
| patterns-integer-100 | 達成 | -0.0006295409999950152 | 0.002 |
| codegen-let-100 | 達成 | -0.0006037910000031843 | 0.002 |
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
    "verify": 2.278490457999993,
    "cli": 5.541840667000002,
    "warmup": 0.6571825829999796,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.3": {
    "verify": 2.9341727080000055,
    "cli": 11.757607209000014,
    "warmup": 1.3678238780000527,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.4": {
    "verify": 1.3183003339999857,
    "cli": 9.20986554200013,
    "warmup": 1.2931127099999458,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.5": {
    "verify": 0.3735118750000197,
    "cli": 3.5893293320000055,
    "warmup": 0.3611747120001212,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.6": {
    "verify": 0.1003069999999866,
    "cli": 0.27736654199998156,
    "warmup": 0.029065041999984942,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.7": {
    "verify": 0.036295207999984314,
    "cli": 0.32779412499999694,
    "warmup": 0.034208207999995466,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  },
  "16.8": {
    "verify": 0.009135500000013508,
    "cli": 0.2023745829999939,
    "warmup": 0.008806082999996079,
    "probe_warmup": 0.008388999999993985,
    "rss": 0,
    "stages": 0.03916841599996701,
    "alloc": 0,
    "external_observer": 0
  },
  "16.9": {
    "verify": 0.04069295800002237,
    "cli": 0.3397326660000033,
    "warmup": 0.03511229200000798,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0.17941462599995361
  },
  "runtime": {
    "verify": 0.335505583000014,
    "cli": 2.9423769169999616,
    "warmup": 0.32988050099993416,
    "probe_warmup": 0,
    "rss": 0,
    "stages": 0,
    "alloc": 0,
    "external_observer": 0
  }
}
```
